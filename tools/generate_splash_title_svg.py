#!/usr/bin/env python3
"""Generate the pure-path color king Splash wordmark.

Requires fontTools. The font is used only at generation time; the runtime SVG
contains no <text> element and therefore has no device font dependency.
"""

from __future__ import annotations

from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont


FONT_PATH = Path("/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf")
WORDMARK = "color king"
CANVAS_WIDTH = 520
CANVAS_HEIGHT = 142
FONT_SCALE = 0.048
BASELINE = 101.0
LETTER_SPACING = 2.0


def _wordmark_paths(font: TTFont) -> tuple[list[str], float]:
	glyph_set = font.getGlyphSet()
	cmap = font.getBestCmap()
	hmtx = font["hmtx"]
	commands: list[str] = []
	advance_x = 0.0
	for character in WORDMARK:
		glyph_name = cmap[ord(character)]
		glyph = glyph_set[glyph_name]
		pen = SVGPathPen(glyph_set)
		transformed_pen = TransformPen(
			pen,
			(FONT_SCALE, 0.0, 0.0, -FONT_SCALE, advance_x, BASELINE),
		)
		glyph.draw(transformed_pen)
		path = pen.getCommands()
		if path:
			commands.append(path)
		advance_x += hmtx[glyph_name][0] * FONT_SCALE + LETTER_SPACING
	return commands, advance_x - LETTER_SPACING


def _path_layer(paths: list[str], attributes: str, x_offset: float) -> str:
	return "\n".join(
		f'    <path d="{path}" transform="translate({x_offset:.3f} 0)" {attributes}/>'
		for path in paths
	)


def generate(output_path: Path) -> None:
	font = TTFont(FONT_PATH)
	paths, wordmark_width = _wordmark_paths(font)
	font.close()
	x_offset = (CANVAS_WIDTH - wordmark_width) * 0.5
	shadow = _path_layer(
		paths,
		'fill="#214A6C" stroke="#214A6C" stroke-width="11" '
		'stroke-linejoin="round" opacity="0.34" transform-origin="center"',
		x_offset,
	)
	rim = _path_layer(
		paths,
		'fill="#F0A416" stroke="#8A4C0B" stroke-width="9" '
		'stroke-linejoin="round" paint-order="stroke fill"',
		x_offset,
	)
	face = _path_layer(
		paths,
		'fill="url(#gold_face)" stroke="#FFEFA4" stroke-width="2.4" '
		'stroke-linejoin="round" paint-order="stroke fill"',
		x_offset,
	)
	highlight = _path_layer(
		paths,
		'fill="none" stroke="#FFF9D8" stroke-width="1.1" '
		'stroke-linejoin="round" opacity="0.72"',
		x_offset,
	)
	content = f'''<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="{CANVAS_WIDTH}" height="{CANVAS_HEIGHT}" viewBox="0 0 {CANVAS_WIDTH} {CANVAS_HEIGHT}">
  <defs>
    <linearGradient id="gold_face" x1="0" y1="18" x2="0" y2="112" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="#FFF18A"/>
      <stop offset="0.46" stop-color="#FFC43D"/>
      <stop offset="1" stop-color="#E98B0C"/>
    </linearGradient>
  </defs>
  <g transform="translate(0 10)">
{shadow}
  </g>
  <g>
{rim}
{face}
  </g>
  <g transform="translate(0 -1.5)">
{highlight}
  </g>
  <path d="M28 46l4.4 9.6L42 60l-9.6 4.4L28 74l-4.4-9.6L14 60l9.6-4.4L28 46Z" fill="#FFF4A8" stroke="#D88A12" stroke-width="2"/>
  <path d="M492 27l3.2 6.8L502 37l-6.8 3.2L492 47l-3.2-6.8L482 37l6.8-3.2L492 27Z" fill="#FFF4A8" stroke="#D88A12" stroke-width="2"/>
</svg>
'''
	output_path.parent.mkdir(parents=True, exist_ok=True)
	output_path.write_text(content, encoding="utf-8")


if __name__ == "__main__":
	repository_root = Path(__file__).resolve().parents[1]
	generate(repository_root / "assets" / "ui" / "splash" / "color_king_title.svg")
