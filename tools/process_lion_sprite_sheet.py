#!/usr/bin/env python3
"""Split an ImageGen lion sprite sheet and trace transparent SVG frames.

Image generators sometimes render the transparency checker into the bitmap.
This tool removes only bright, near-neutral pixels connected to a cell edge, so
the enclosed white eye highlights stay intact, then passes the RGBA pixels to
VTracer.  Every SVG keeps the same cell-sized viewBox for stable frame-to-frame
alignment in Godot.
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image
import vtracer


OUTPUT_CANVAS_SIZE = 400
OUTPUT_PADDING = 24
CONTACT_FRAME_COUNT = 11


def _transparent_cell(cell: Image.Image) -> Image.Image:
    rgb = np.asarray(cell.convert("RGB"), dtype=np.uint8)
    high = rgb.max(axis=2)
    low = rgb.min(axis=2)
    background_candidate = (high - low <= 18) & (low >= 218)

    height, width = background_candidate.shape
    exterior = np.zeros((height, width), dtype=bool)
    queue: deque[tuple[int, int]] = deque()

    def seed(x: int, y: int) -> None:
        if background_candidate[y, x] and not exterior[y, x]:
            exterior[y, x] = True
            queue.append((x, y))

    for x in range(width):
        seed(x, 0)
        seed(x, height - 1)
    for y in range(height):
        seed(0, y)
        seed(width - 1, y)

    while queue:
        x, y = queue.popleft()
        for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (
                0 <= next_x < width
                and 0 <= next_y < height
                and background_candidate[next_y, next_x]
                and not exterior[next_y, next_x]
            ):
                exterior[next_y, next_x] = True
                queue.append((next_x, next_y))

    rgba = np.empty((height, width, 4), dtype=np.uint8)
    rgba[:, :, :3] = rgb
    rgba[:, :, 3] = np.where(exterior, 0, 255).astype(np.uint8)
    return Image.fromarray(rgba, "RGBA")


def _largest_connected_sprite(cell: Image.Image) -> Image.Image:
    rgba = np.asarray(cell, dtype=np.uint8).copy()
    opaque = rgba[:, :, 3] > 0
    height, width = opaque.shape
    visited = np.zeros((height, width), dtype=bool)
    largest: list[tuple[int, int]] = []

    for start_y in range(height):
        for start_x in range(width):
            if not opaque[start_y, start_x] or visited[start_y, start_x]:
                continue
            component: list[tuple[int, int]] = []
            queue: deque[tuple[int, int]] = deque([(start_x, start_y)])
            visited[start_y, start_x] = True
            while queue:
                x, y = queue.popleft()
                component.append((x, y))
                for next_x, next_y in (
                    (x - 1, y - 1), (x, y - 1), (x + 1, y - 1),
                    (x - 1, y),                     (x + 1, y),
                    (x - 1, y + 1), (x, y + 1), (x + 1, y + 1),
                ):
                    if (
                        0 <= next_x < width
                        and 0 <= next_y < height
                        and opaque[next_y, next_x]
                        and not visited[next_y, next_x]
                    ):
                        visited[next_y, next_x] = True
                        queue.append((next_x, next_y))
            if len(component) > len(largest):
                largest = component

    keep = np.zeros((height, width), dtype=bool)
    for x, y in largest:
        keep[y, x] = True
    rgba[:, :, 3] = np.where(keep, rgba[:, :, 3], 0)
    sprite = Image.fromarray(rgba, "RGBA")
    bounds = sprite.getbbox()
    if bounds is None:
        raise ValueError("No sprite pixels remained after background removal")
    return sprite.crop(bounds)


def _frame_destination(
    direction: str,
    sprite: Image.Image,
    frame_index: int,
    contact_frame_count: int,
) -> tuple[int, int]:
    if frame_index >= contact_frame_count:
        return (
            (OUTPUT_CANVAS_SIZE - sprite.width) // 2,
            (OUTPUT_CANVAS_SIZE - sprite.height) // 2,
        )
    if direction == "left":
        return (OUTPUT_PADDING, (OUTPUT_CANVAS_SIZE - sprite.height) // 2)
    if direction == "right":
        return (
            OUTPUT_CANVAS_SIZE - OUTPUT_PADDING - sprite.width,
            (OUTPUT_CANVAS_SIZE - sprite.height) // 2,
        )
    return (
        (OUTPUT_CANVAS_SIZE - sprite.width) // 2,
        OUTPUT_CANVAS_SIZE - OUTPUT_PADDING - sprite.height,
    )


def process(
    source: Path,
    output_dir: Path,
    columns: int,
    rows: int,
    direction: str,
    prefix: str,
    contact_frame_count: int = CONTACT_FRAME_COUNT,
) -> None:
    sheet = Image.open(source).convert("RGB")
    output_dir.mkdir(parents=True, exist_ok=True)
    temporary_dir = output_dir / f".{prefix}_rasters"
    temporary_dir.mkdir(exist_ok=True)
    cell_edge = min(sheet.width / columns, sheet.height / rows)
    contact_overlap = max(18, round(cell_edge * 0.09))
    # Airborne poses often let a crown or raised paw cross the nominal cell
    # boundary. They get a generous overlap; the smaller edge-contact poses keep
    # a tight crop so a larger character in the next row cannot win component
    # selection.
    airborne_overlap = max(32, round(cell_edge * 0.28))

    frame_index = 0
    for row in range(rows):
        top = round(row * sheet.height / rows)
        bottom = round((row + 1) * sheet.height / rows)
        for column in range(columns):
            left = round(column * sheet.width / columns)
            right = round((column + 1) * sheet.width / columns)
            overlap = airborne_overlap if frame_index >= contact_frame_count else contact_overlap
            expanded_box = (
                max(0, left - overlap),
                max(0, top - overlap),
                min(sheet.width, right + overlap),
                min(sheet.height, bottom + overlap),
            )
            cell = _transparent_cell(sheet.crop(expanded_box))
            sprite = _largest_connected_sprite(cell)
            normalized = Image.new(
                "RGBA",
                (OUTPUT_CANVAS_SIZE, OUTPUT_CANVAS_SIZE),
                (0, 0, 0, 0),
            )
            destination_x, destination_y = _frame_destination(
                direction,
                sprite,
                frame_index,
                contact_frame_count,
            )
            normalized.alpha_composite(sprite, (destination_x, destination_y))
            raster_path = temporary_dir / f"{prefix}_{frame_index:02d}.png"
            vector_path = output_dir / f"{prefix}_{frame_index:02d}.svg"
            normalized.save(raster_path)
            svg = vtracer.convert_pixels_to_svg(
                list(normalized.get_flattened_data()),
                normalized.size,
                colormode="color",
                hierarchical="stacked",
                mode="spline",
                filter_speckle=5,
                color_precision=6,
                layer_difference=12,
                corner_threshold=58,
                length_threshold=4.0,
                max_iterations=10,
                splice_threshold=45,
                path_precision=3,
            )
            vector_path.write_text(svg, encoding="utf-8")
            frame_index += 1

    for raster_path in temporary_dir.glob("*.png"):
        raster_path.unlink()
    temporary_dir.rmdir()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=2)
    parser.add_argument(
        "--direction",
        choices=("left", "right", "bottom"),
        default="bottom",
    )
    parser.add_argument("--prefix", default="lion_bottom_entry")
    parser.add_argument(
        "--contact-frame-count",
        type=int,
        default=CONTACT_FRAME_COUNT,
        help="Number of leading frames anchored to the selected screen edge; use 0 for an airborne-only sheet.",
    )
    args = parser.parse_args()
    process(
        args.source,
        args.output_dir,
        args.columns,
        args.rows,
        args.direction,
        args.prefix,
        args.contact_frame_count,
    )


if __name__ == "__main__":
    main()
