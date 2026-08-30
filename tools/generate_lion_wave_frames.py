#!/usr/bin/env python3
"""Build a stable, high-cadence result-lion wave from an ImageGen sheet.

The generated 4x4 sheet contains useful poses but restarts its motion at each
row and recenters the whole character as the arm extends.  This tool selects a
monotonic set of authored poses, registers every pose by the belly centroid,
adds one optical-flow midpoint between adjacent poses, and saves the resulting
13 fixed-registration raster sources for the body/arm layer generator.
"""

from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np
from PIL import Image

from process_lion_sprite_sheet import _largest_connected_sprite, _transparent_cell


CANVAS_SIZE = 400
SHEET_COLUMNS = 4
SHEET_ROWS = 4
CELL_OVERLAP = 72
BELLY_TARGET = (215, 255)
# These poses advance continuously from the raised paw to the fully extended
# paw.  The omitted cells restart a previous pose at an ImageGen row boundary.
SELECTED_SHEET_FRAMES = (0, 5, 6, 8, 10, 7, 11)


def _belly_centroid(sprite: Image.Image) -> tuple[float, float]:
    rgba = np.asarray(sprite, dtype=np.uint8)
    rgb = rgba[:, :, :3]
    belly = (
        (rgb[:, :, 0] > 245)
        & (rgb[:, :, 1] > 195)
        & (rgb[:, :, 1] < 235)
        & (rgb[:, :, 2] > 130)
        & (rgb[:, :, 2] < 195)
        & (rgba[:, :, 3] > 0)
    ).astype(np.uint8)
    component_count, _, stats, centroids = cv2.connectedComponentsWithStats(
        belly,
        8,
    )
    candidates: list[tuple[int, int]] = []
    for component in range(1, component_count):
        area = int(stats[component, cv2.CC_STAT_AREA])
        if area > 1000:
            candidates.append((area, component))
    if not candidates:
        raise ValueError("Could not find the lion belly registration marker")
    _, component = max(candidates)
    return float(centroids[component, 0]), float(centroids[component, 1])


def _normalized_sheet_frame(sheet: Image.Image, frame_index: int) -> Image.Image:
    row = frame_index // SHEET_COLUMNS
    column = frame_index % SHEET_COLUMNS
    left = round(column * sheet.width / SHEET_COLUMNS)
    top = round(row * sheet.height / SHEET_ROWS)
    right = round((column + 1) * sheet.width / SHEET_COLUMNS)
    bottom = round((row + 1) * sheet.height / SHEET_ROWS)
    expanded = (
        max(0, left - CELL_OVERLAP),
        max(0, top - CELL_OVERLAP),
        min(sheet.width, right + CELL_OVERLAP),
        min(sheet.height, bottom + CELL_OVERLAP),
    )
    sprite = _largest_connected_sprite(_transparent_cell(sheet.crop(expanded)))
    belly_x, belly_y = _belly_centroid(sprite)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(
        sprite,
        (
            round(BELLY_TARGET[0] - belly_x),
            round(BELLY_TARGET[1] - belly_y),
        ),
    )
    return canvas


def _motion_signal(bgra: np.ndarray) -> np.ndarray:
    alpha = bgra[:, :, 3:4].astype(np.float32) / 255.0
    composite = bgra[:, :, :3] * alpha + 255.0 * (1.0 - alpha)
    return cv2.cvtColor(composite.astype(np.uint8), cv2.COLOR_BGR2GRAY)


def _optical_flow_midpoint(first: Image.Image, second: Image.Image) -> Image.Image:
    first_bgra = cv2.cvtColor(np.asarray(first), cv2.COLOR_RGBA2BGRA)
    second_bgra = cv2.cvtColor(np.asarray(second), cv2.COLOR_RGBA2BGRA)
    first_gray = _motion_signal(first_bgra)
    second_gray = _motion_signal(second_bgra)

    flow_engine = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    flow_engine.setUseSpatialPropagation(True)
    forward = flow_engine.calc(first_gray, second_gray, None)
    backward = flow_engine.calc(second_gray, first_gray, None)

    height, width = first_gray.shape
    grid_x, grid_y = np.meshgrid(
        np.arange(width, dtype=np.float32),
        np.arange(height, dtype=np.float32),
    )
    half = np.float32(0.5)
    warped_first = cv2.remap(
        first_bgra,
        (grid_x + half * backward[:, :, 0]).astype(np.float32),
        (grid_y + half * backward[:, :, 1]).astype(np.float32),
        cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    )
    warped_second = cv2.remap(
        second_bgra,
        (grid_x + half * forward[:, :, 0]).astype(np.float32),
        (grid_y + half * forward[:, :, 1]).astype(np.float32),
        cv2.INTER_CUBIC,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=(0, 0, 0, 0),
    )
    midpoint_bgra = np.clip(
        warped_first.astype(np.float32) * 0.5
        + warped_second.astype(np.float32) * 0.5,
        0,
        255,
    ).astype(np.uint8)
    return Image.fromarray(
        cv2.cvtColor(midpoint_bgra, cv2.COLOR_BGRA2RGBA),
        "RGBA",
    )


def generate(sheet_path: Path, source_dir: Path) -> None:
    sheet = Image.open(sheet_path).convert("RGB")
    authored = [
        _normalized_sheet_frame(sheet, frame_index)
        for frame_index in SELECTED_SHEET_FRAMES
    ]
    frames: list[Image.Image] = []
    for index, frame in enumerate(authored):
        frames.append(frame)
        if index + 1 < len(authored):
            frames.append(_optical_flow_midpoint(frame, authored[index + 1]))

    source_dir.mkdir(parents=True, exist_ok=True)
    for frame_index, frame in enumerate(frames):
        basename = f"lion_king_center_wave_{frame_index:02d}"
        frame.save(source_dir / f"{basename}_source.png")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sheet", type=Path)
    parser.add_argument("source_dir", type=Path)
    args = parser.parse_args()
    generate(args.sheet, args.source_dir)


if __name__ == "__main__":
    main()
