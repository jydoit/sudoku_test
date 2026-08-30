#!/usr/bin/env python3
"""Split the ImageGen splash master and remove its baked checkerboard.

The generated master and transparent raster sources are kept under
docs/animation_sources for reproducibility. Runtime frames preserve the
authored 4 x 4 registration and are traced to pure-path SVG assets.
"""

from __future__ import annotations

from pathlib import Path

import cv2
import numpy as np
from PIL import Image
import vtracer


GRID_SIZE = 4
FRAME_CANVAS = 320
# ImageGen kept the board geometry stable but offset each storyboard column by
# a repeatable amount. Register all four columns on the same x = 160 centre.
COLUMN_REGISTRATION_X = (-13, 1, 0, 15)


def _remove_connected_checkerboard(image: Image.Image) -> Image.Image:
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
	pixels = np.asarray(frame).copy()
	# Frame 11 is the completed-board sparkle beat. The master leaked the prior
	# panel's shadow into its top edge and the next panel's lion into its bottom.
	# Both strips sit outside the completed board and are safe to clear.
	pixels[:24, :, :] = 0
	pixels[272:, :, :] = 0
	return Image.fromarray(pixels)


def process(master_path: Path, source_dir: Path, vector_dir: Path) -> None:
	master = Image.open(master_path).convert("RGB")
	source_dir.mkdir(parents=True, exist_ok=True)
	vector_dir.mkdir(parents=True, exist_ok=True)
	stable_final_board: Image.Image | None = None
	for frame_index in range(GRID_SIZE * GRID_SIZE):
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
		if frame_index == 14:
			stable_final_board = canvas.copy()
		elif frame_index == 15 and stable_final_board is not None:
			# ImageGen cropped the mascot at the last storyboard boundary. Keep the
			# final board stable; runtime composes the canonical vector mascot above it.
			canvas = stable_final_board.copy()
		basename = f"splash_assembly_{frame_index:02d}"
		canvas.save(source_dir / f"{basename}_source.png", optimize=True)
		(vector_dir / f"{basename}.svg").write_text(_trace_svg(canvas), encoding="utf-8")


if __name__ == "__main__":
	root = Path(__file__).resolve().parents[1]
	process(
		root / "docs" / "animation_sources" / "splash" / "splash_assembly_keyframes_master.png",
		root / "docs" / "animation_sources" / "splash" / "frames",
		root / "assets" / "ui" / "splash",
	)
