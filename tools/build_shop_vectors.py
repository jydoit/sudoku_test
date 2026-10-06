#!/usr/bin/env python3
"""Trace the ImageGen shop references to pure SVG paths (vtracer 0.6.15)."""

from pathlib import Path
import re

from PIL import Image
import vtracer


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    for currency in ("coins", "diamonds"):
        source = ROOT / "docs/icon_sources" / f"shop_{currency}_imagegen.png"
        target = ROOT / "assets/ui/shop" / f"{currency}_pile.svg"
        target.parent.mkdir(parents=True, exist_ok=True)
        vtracer.convert_image_to_svg_py(
            str(source), str(target), colormode="color", hierarchical="stacked",
            mode="spline", filter_speckle=8, color_precision=5,
            layer_difference=24, corner_threshold=60, length_threshold=6.0,
            max_iterations=10, splice_threshold=45, path_precision=2,
        )
        # Tighten the vector viewport only; keep the generated artwork unchanged.
        bounds = Image.open(source).convert("RGBA").getchannel("A").getbbox()
        left, top, right, bottom = bounds
        pad = 24
        width, height = right - left + pad * 2, bottom - top + pad * 2
        svg = target.read_text()
        svg = re.sub(
            r'<svg\b[^>]*>',
            f'<svg xmlns="http://www.w3.org/2000/svg" width="512" '
            f'height="{round(512 * height / width)}" '
            f'viewBox="{left-pad} {top-pad} {width} {height}">', svg, count=1,
        )
        assert "<image" not in svg and "base64" not in svg
        target.write_text(svg)
        print(f"{target.relative_to(ROOT)}: {len(svg.encode()):,} bytes, {svg.count('<path')} paths")


if __name__ == "__main__":
    main()
