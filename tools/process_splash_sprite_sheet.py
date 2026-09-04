#!/usr/bin/env python3
"""Split the ImageGen splash master and remove its baked checkerboard.

The generated master and transparent raster sources are kept under
docs/animation_sources for reproducibility. Runtime frames preserve the
authored 4 x 4 registration and are traced to pure-path SVG assets.
"""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
	from PIL import Image


GRID_SIZE = 4
FRAME_CANVAS = 320
RUNTIME_FRAME_COUNT = 13
# ImageGen kept the board geometry stable but offset each storyboard column by
# a repeatable amount. Register all four columns on the same x = 160 centre.
COLUMN_REGISTRATION_X = (-13, 1, 0, 15)

# The storyboard shows one blue stair tetromino and two L triominoes below the
# board.  The completed board must contain each footprint inside its same-color
# region (translation and quarter-turn rotation are allowed).  Frame 11/12 in
# the generated master dropped the pink L's third cell, so those two terminal
# frames receive a deterministic vector correction after tracing.
INCOMING_PIECE_FOOTPRINTS = {
	"blue": frozenset(((0, 0), (0, 1), (1, 1), (1, 2))),
	"teal": frozenset(((0, 0), (1, 0), (1, 1))),
	"pink": frozenset(((0, 0), (1, 0), (1, 1))),
}
TERMINAL_REGION_CELLS = {
	"blue": frozenset(((0, 0), (0, 1), (0, 2), (0, 3), (1, 1), (1, 2))),
	"teal": frozenset(((4, 3), (4, 4), (5, 3))),
	"pink": frozenset(((4, 5), (5, 4), (5, 5))),
}
TERMINAL_PINK_L_PATCHES = {
	11: (
		'<g id="terminal-pink-l-footprint" data-terminal-cells="4,5 5,4 5,5">'
		'<path d="M222 181H254V215H222Z" fill="#E35790"/>'
		'<path d="M225 182H252Q254 182 254 184V213H223V185Q223 183 225 182Z" fill="#FB5B95"/>'
		'<path d="M226 183H251V185H226Z" fill="#F86BA4"/>'
		'</g>'
	),
	12: (
		'<g id="terminal-pink-l-footprint" data-terminal-cells="4,5 5,4 5,5">'
		'<path d="M222 184H254V218H222Z" fill="#E35790"/>'
		'<path d="M225 185H252Q254 185 254 187V216H223V188Q223 186 225 185Z" fill="#FB5B97"/>'
		'<path d="M226 186H251V188H226Z" fill="#F679AC"/>'
		'</g>'
	),
}


def _quarter_turn(shape: frozenset[tuple[int, int]]) -> frozenset[tuple[int, int]]:
	turned = {(column, -row) for row, column in shape}
	min_row = min(row for row, _column in turned)
	min_column = min(column for _row, column in turned)
	return frozenset((row - min_row, column - min_column) for row, column in turned)


def _region_contains_footprint(
	region: frozenset[tuple[int, int]],
	footprint: frozenset[tuple[int, int]],
) -> bool:
	orientation = footprint
	for _quarter_turn_index in range(4):
		for region_row, region_column in region:
			for piece_row, piece_column in orientation:
				offset_row = region_row - piece_row
				offset_column = region_column - piece_column
				translated = {
					(row + offset_row, column + offset_column)
					for row, column in orientation
				}
				if translated <= region:
					return True
		orientation = _quarter_turn(orientation)
	return False


def _validate_terminal_piece_geometry() -> None:
	for color, footprint in INCOMING_PIECE_FOOTPRINTS.items():
		if not _region_contains_footprint(TERMINAL_REGION_CELLS[color], footprint):
			raise ValueError(f"terminal {color} region no longer contains its incoming piece")


def _preserve_terminal_piece_footprint(svg_source: str, frame_index: int) -> str:
	patch = TERMINAL_PINK_L_PATCHES.get(frame_index)
	if patch is None:
		return svg_source
	return svg_source.replace("</svg>", f"{patch}\n</svg>")


def _remove_connected_checkerboard(image: Image.Image) -> Image.Image:
	import cv2
	import numpy as np
	from PIL import Image

	rgb = np.asarray(image.convert("RGB"), dtype=np.uint8)
	channel_range = rgb.max(axis=2).astype(np.int16) - rgb.min(axis=2).astype(np.int16)
	neutral_bright = (channel_range <= 8) & (rgb.min(axis=2) >= 228)
	component_count, labels = cv2.connectedComponents(neutral_bright.astype(np.uint8), 8)
	edge_labels = np.unique(np.concatenate((labels[0], labels[-1], labels[:, 0], labels[:, -1])))
	background = np.zeros(labels.shape, dtype=bool)
	for label in edge_labels:
		if 0 < label < component_count:
			background |= labels == label

	# Slightly expand only into near-white neutral pixels so the checkerboard's
	# antialiased tile seams disappear without punching holes in the enclosed tray.
	near_background = (channel_range <= 12) & (rgb.min(axis=2) >= 218)
	background_u8 = background.astype(np.uint8)
	for _ in range(3):
		expanded = cv2.dilate(background_u8, np.ones((3, 3), np.uint8), iterations=1) > 0
		background_u8 = (background | (expanded & near_background)).astype(np.uint8)
		background = background_u8 > 0

	alpha = np.where(background, 0, 255).astype(np.uint8)
	rgba = np.dstack((rgb, alpha))
	return Image.fromarray(rgba)


def _trace_svg(frame: Image.Image) -> str:
	import vtracer

	if hasattr(vtracer, "convert_pixels_to_svg"):
		return vtracer.convert_pixels_to_svg(
			list(frame.get_flattened_data()),
			frame.size,
			colormode="color",
			hierarchical="stacked",
			mode="spline",
			filter_speckle=4,
			color_precision=6,
			layer_difference=12,
			corner_threshold=58,
			length_threshold=4.0,
			max_iterations=10,
			splice_threshold=45,
			path_precision=3,
		)
	config = vtracer.Config(
		clustering="color-cluster",
		hierarchical="stacked",
		mode="spline",
		filter_speckle=4,
		color_precision=6,
		layer_difference=12,
		corner_threshold=58,
		length_threshold=4.0,
		max_iterations=10,
		splice_threshold=45,
		path_precision=3,
	)
	return vtracer.convert_pixels(frame.tobytes(), frame.width, frame.height, config)


def _clean_panel_bleed(frame: Image.Image, frame_index: int) -> Image.Image:
	"""Remove content leaked across a storyboard cell boundary by ImageGen."""
	if frame_index != 11:
		return frame
	import numpy as np
	from PIL import Image

	pixels = np.asarray(frame).copy()
	# Frame 11 is the completed-board sparkle beat. The master leaked the prior
	# panel's shadow into its top edge and the next panel's lion into its bottom.
	# Both strips sit outside the completed board and are safe to clear.
	pixels[:24, :, :] = 0
	pixels[272:, :, :] = 0
	return Image.fromarray(pixels)


def process(master_path: Path, source_dir: Path, vector_dir: Path) -> None:
	from PIL import Image

	_validate_terminal_piece_geometry()
	master = Image.open(master_path).convert("RGB")
	source_dir.mkdir(parents=True, exist_ok=True)
	vector_dir.mkdir(parents=True, exist_ok=True)
	# Frames 13-15 redraw already placed pieces and cannot be part of a
	# continuous assembly. The runtime finishes on frame 12 and overlays its
	# canonical crown, mascot and wordmark independently.
	for frame_index in range(RUNTIME_FRAME_COUNT):
		row, column = divmod(frame_index, GRID_SIZE)
		left = round(column * master.width / GRID_SIZE)
		top = round(row * master.height / GRID_SIZE)
		right = round((column + 1) * master.width / GRID_SIZE)
		bottom = round((row + 1) * master.height / GRID_SIZE)
		cell = master.crop((left, top, right, bottom)).resize((314, 314), Image.Resampling.LANCZOS)
		transparent = _remove_connected_checkerboard(cell)
		canvas = Image.new("RGBA", (FRAME_CANVAS, FRAME_CANVAS), (0, 0, 0, 0))
		canvas.alpha_composite(transparent, (3 + COLUMN_REGISTRATION_X[column], 3))
		canvas = _clean_panel_bleed(canvas, frame_index)
		basename = f"splash_assembly_{frame_index:02d}"
		canvas.save(source_dir / f"{basename}_source.png", optimize=True)
		svg_source = _preserve_terminal_piece_footprint(_trace_svg(canvas), frame_index)
		(vector_dir / f"{basename}.svg").write_text(svg_source, encoding="utf-8")


if __name__ == "__main__":
	root = Path(__file__).resolve().parents[1]
	process(
		root / "docs" / "animation_sources" / "splash" / "splash_assembly_keyframes_master.png",
		root / "docs" / "animation_sources" / "splash" / "frames",
		root / "assets" / "ui" / "splash",
	)
