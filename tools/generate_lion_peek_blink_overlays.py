#!/usr/bin/env python3
"""Generate eye-only peek blink overlays on fixed registered lion poses.

The authored wink frames also change the paws and body height. Swapping those
full frames makes the lion appear to crouch while blinking. This generator
aligns each authored wink to its matching open-eye pose, keeps only a feathered
eye patch, and traces that patch on the original 400 x 400 registration canvas.
Runtime renders the overlay above an unchanged open-eye body frame.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
import vtracer

from process_lion_sprite_sheet import (
    OUTPUT_CANVAS_SIZE,
    _frame_destination,
    _largest_connected_sprite,
    _transparent_cell,
)


@dataclass(frozen=True)
class BlinkSpec:
    direction: str
    open_frame: int
    wink_frame: int
    wink_shift: tuple[int, int]
    eye_ellipse: tuple[int, int, int, int]


SPECS = [
    BlinkSpec("bottom", 6, 7, (0, -24), (232, 236, 276, 284)),
    BlinkSpec("left", 7, 6, (-12, -15), (104, 164, 142, 207)),
    BlinkSpec("right", 6, 7, (0, 0), (309, 158, 345, 201)),
]


def _normalized_contact_frame(sheet: Image.Image, frame_index: int, direction: str) -> Image.Image:
    columns = 4
    rows = 4
    row, column = divmod(frame_index, columns)
    top = round(row * sheet.height / rows)
    bottom = round((row + 1) * sheet.height / rows)
    left = round(column * sheet.width / columns)
    right = round((column + 1) * sheet.width / columns)
    cell_edge = min(sheet.width / columns, sheet.height / rows)
    overlap = max(18, round(cell_edge * 0.09))
    expanded_box = (
        max(0, left - overlap),
        max(0, top - overlap),
        min(sheet.width, right + overlap),
        min(sheet.height, bottom + overlap),
    )
    sprite = _largest_connected_sprite(_transparent_cell(sheet.crop(expanded_box)))
    normalized = Image.new(
        "RGBA",
        (OUTPUT_CANVAS_SIZE, OUTPUT_CANVAS_SIZE),
        (0, 0, 0, 0),
    )
    normalized.alpha_composite(
        sprite,
        _frame_destination(direction, sprite, frame_index, contact_frame_count=11),
    )
    return normalized


def _blink_overlay(sheet: Image.Image, spec: BlinkSpec) -> Image.Image:
    # Build both frames through the same normalization path used by the runtime
    # assets. The open frame is intentionally evaluated even though it is not
    # composited, so invalid source changes fail generation before export.
    open_frame = _normalized_contact_frame(sheet, spec.open_frame, spec.direction)
    wink_frame = _normalized_contact_frame(sheet, spec.wink_frame, spec.direction)
    if open_frame.getbbox() is None or wink_frame.getbbox() is None:
        raise ValueError(f"Missing registered peek pose for {spec.direction}")

    aligned_wink = Image.new("RGBA", open_frame.size, (0, 0, 0, 0))
    aligned_wink.alpha_composite(wink_frame, spec.wink_shift)

    mask = Image.new("L", open_frame.size, 0)
    ImageDraw.Draw(mask).ellipse(spec.eye_ellipse, fill=255)
    mask = mask.filter(ImageFilter.GaussianBlur(2.0))

    overlay = np.asarray(aligned_wink, dtype=np.uint8).copy()
    overlay[:, :, 3] = (
        overlay[:, :, 3].astype(np.uint16)
        * np.asarray(mask, dtype=np.uint16)
        // 255
    ).astype(np.uint8)
    return Image.fromarray(overlay, "RGBA")


def _trace_svg(image: Image.Image) -> str:
    return vtracer.convert_pixels_to_svg(
        list(image.get_flattened_data()),
        image.size,
        colormode="color",
        hierarchical="stacked",
        mode="spline",
        filter_speckle=3,
        color_precision=6,
        layer_difference=8,
        corner_threshold=58,
        length_threshold=3.0,
        max_iterations=10,
        splice_threshold=45,
        path_precision=3,
    )


def build(root: Path) -> None:
    output_dir = root / "assets" / "ui"
    for spec in SPECS:
        sheet_path = (
            root
            / "docs"
            / "animation_sources"
            / f"lion_{spec.direction}_peek_jump_sheet.png"
        )
        sheet = Image.open(sheet_path).convert("RGB")
        overlay = _blink_overlay(sheet, spec)
        output_path = output_dir / f"lion_{spec.direction}_peek_blink.svg"
        output_path.write_text(_trace_svg(overlay), encoding="utf-8")


if __name__ == "__main__":
    build(Path(__file__).resolve().parents[1])
