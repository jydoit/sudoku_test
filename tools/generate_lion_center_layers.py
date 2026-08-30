#!/usr/bin/env python3
"""Build a stable lion body plus arm-only result-wave frames.

The authored source frames contain a complete lion in every pose. Switching those
textures redraws the face and body and creates a visible flash. This tool extracts
the moving left arm into a behind-the-body layer and reconstructs one fixed body
from pixels that are not covered by the arm in the other poses.
"""

from __future__ import annotations

from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image
import vtracer


FRAME_COUNT = 13
CANVAS_SIZE = (400, 400)
SHOULDER = np.array([171.0, 219.0])
ARM_RADIUS = 27.0


def _source_path(root: Path, index: int) -> Path:
	return root / "docs" / "animation_sources" / f"lion_king_center_wave_{index:02d}_source.png"


def _arm_mask(frame: np.ndarray) -> np.ndarray:
	height, width = frame.shape[:2]
	yy, xx = np.indices((height, width))
	alpha = frame[:, :, 3]
	eligible = (
		(alpha > 40)
		& (xx < 175)
		& (yy > 145)
		& (yy < 250)
	)
	if not np.any(eligible):
		raise ValueError("Unable to locate the waving paw")

	left_edge = int(xx[eligible].min())
	paw_band = eligible & (xx <= left_edge + 18)
	paw = np.array([left_edge + 15.0, float(np.median(yy[paw_band]))])
	arm_vector = SHOULDER - paw
	arm_length_squared = float(arm_vector @ arm_vector)
	progress = np.clip(
		((xx - paw[0]) * arm_vector[0] + (yy - paw[1]) * arm_vector[1])
		/ arm_length_squared,
		0.0,
		1.0,
	)
	distance_x = xx - (paw[0] + progress * arm_vector[0])
	distance_y = yy - (paw[1] + progress * arm_vector[1])
	capsule = distance_x * distance_x + distance_y * distance_y <= ARM_RADIUS * ARM_RADIUS
	return (
		(alpha > 0)
		& (xx < 188)
		& (yy > 132)
		& (yy < 266)
		& capsule
	)


def _keep_largest_alpha_component(frame: np.ndarray) -> np.ndarray:
	"""Drop isolated antialias specks introduced while reconstructing the body."""
	alpha_mask = frame[:, :, 3] > 0
	height, width = alpha_mask.shape
	visited = np.zeros_like(alpha_mask)
	largest: list[tuple[int, int]] = []

	for start_y, start_x in zip(*np.nonzero(alpha_mask & ~visited)):
		if visited[start_y, start_x]:
			continue
		component: list[tuple[int, int]] = []
		queue = deque([(int(start_y), int(start_x))])
		visited[start_y, start_x] = True
		while queue:
			y, x = queue.popleft()
			component.append((y, x))
			for next_y, next_x in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
				if (
					0 <= next_y < height
					and 0 <= next_x < width
					and alpha_mask[next_y, next_x]
					and not visited[next_y, next_x]
				):
					visited[next_y, next_x] = True
					queue.append((next_y, next_x))
		if len(component) > len(largest):
			largest = component

	keep = np.zeros_like(alpha_mask)
	for y, x in largest:
		keep[y, x] = True
	result = frame.copy()
	result[~keep] = 0
	return result


def _trace_svg(frame: np.ndarray) -> str:
	image = Image.fromarray(frame)
	if hasattr(vtracer, "convert_pixels_to_svg"):
		return vtracer.convert_pixels_to_svg(
			list(image.get_flattened_data()),
			image.size,
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
	config = vtracer.Config(
		clustering="color-cluster",
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
	return vtracer.convert_pixels(image.tobytes(), image.width, image.height, config)


def _flatten_registered_svgs(arm_svg: str, body_svg: str) -> str:
	paths = [
		line
		for layer in (arm_svg, body_svg)
		for line in layer.splitlines()
		if line.startswith("<path ")
	]
	return "\n".join([
		'<?xml version="1.0" encoding="UTF-8"?>',
		'<!-- Generated from the exact registered arm and body vector paths. -->',
		'<svg version="1.1" xmlns="http://www.w3.org/2000/svg" width="400" height="400">',
		*paths,
		"</svg>",
		"",
	])


def build_layers(root: Path) -> None:
	frames = [
		np.array(Image.open(_source_path(root, index)).convert("RGBA"))
		for index in range(FRAME_COUNT)
	]
	for index, frame in enumerate(frames):
		if (frame.shape[1], frame.shape[0]) != CANVAS_SIZE:
			raise ValueError(f"Frame {index:02d} must be 400 x 400")

	arm_masks = [_arm_mask(frame) for frame in frames]
	arm_union = np.logical_or.reduce(arm_masks)

	# Keep frame 00 byte-for-byte outside the moving-arm area. Inside it, fill
	# from the earliest pose where that pixel is not covered by the moving arm.
	body = frames[0].copy()
	body[arm_union] = 0
	for frame, mask in zip(frames, arm_masks):
		candidate = arm_union & ~mask & (frame[:, :, 3] > body[:, :, 3])
		body[candidate] = frame[candidate]
	body = _keep_largest_alpha_component(body)

	output_dir = root / "assets" / "ui"
	output_dir.mkdir(parents=True, exist_ok=True)
	body_svg = _trace_svg(body)
	(output_dir / "lion_king_center_body.svg").write_text(body_svg, encoding="utf-8")

	arm_svgs: list[str] = []
	for index, (frame, mask) in enumerate(zip(frames, arm_masks)):
		arm = np.zeros_like(frame)
		arm[mask] = frame[mask]
		arm_svg = _trace_svg(arm)
		arm_svgs.append(arm_svg)
		(output_dir / f"lion_king_center_arm_{index:02d}.svg").write_text(
			arm_svg,
			encoding="utf-8",
		)

	# The landing hand-off uses the same registered body and fully extended arm
	# as the first arrival frame. Keeping it as a single opaque SVG avoids a
	# one-frame overlap while ownership moves to the layered centre lion.
	(output_dir / "lion_king_center_landing.svg").write_text(
		_flatten_registered_svgs(arm_svgs[-1], body_svg),
		encoding="utf-8",
	)

if __name__ == "__main__":
	build_layers(Path(__file__).resolve().parents[1])
