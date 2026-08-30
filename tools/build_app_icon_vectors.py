#!/usr/bin/env python3
"""Build the color king app-icon SVG layers from the approved visual reference."""

from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_REFERENCE = ROOT / "docs" / "icon_sources" / "app_icon_reference.png"
# Keep the crown inside Android's centered safe circle. The lion uses a
# separate transform so its original bottom crop stays hidden by the launcher
# mask while its complete face and raised paw remain visible.
ADAPTIVE_CROWN_TRANSFORM = "translate(333 221) scale(0.546)"
ADAPTIVE_LION_TRANSFORM = "translate(261 169) scale(0.7)"


SVG_DEFS = """  <defs>
    <linearGradient id="sky" x1="90" y1="0" x2="1164" y2="1254" gradientUnits="userSpaceOnUse">
      <stop stop-color="#0667D9"/>
      <stop offset="0.22" stop-color="#1398EF"/>
      <stop offset="0.52" stop-color="#39B0EE"/>
      <stop offset="0.78" stop-color="#168EEA"/>
      <stop offset="1" stop-color="#0758CA"/>
    </linearGradient>
    <radialGradient id="warmHalo" cx="0" cy="0" r="1" gradientTransform="translate(627 418) rotate(90) scale(720 720)" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF2C5" stop-opacity="0.98"/>
      <stop offset="0.25" stop-color="#FFE9AA" stop-opacity="0.84"/>
      <stop offset="0.48" stop-color="#E9E6C4" stop-opacity="0.54"/>
      <stop offset="0.73" stop-color="#B9E1F1" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#B9E1F1" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="centerBloom" cx="0" cy="0" r="1" gradientTransform="translate(627 396) rotate(90) scale(365 430)" gradientUnits="userSpaceOnUse">
      <stop stop-color="#FFF7D9" stop-opacity="0.76"/>
      <stop offset="0.58" stop-color="#FFF0BF" stop-opacity="0.26"/>
      <stop offset="1" stop-color="#FFF0BF" stop-opacity="0"/>
    </radialGradient>
    <radialGradient id="sparkleGlow">
      <stop stop-color="#FFF5C9" stop-opacity="0.62"/>
      <stop offset="0.45" stop-color="#FFF3C2" stop-opacity="0.25"/>
      <stop offset="1" stop-color="#FFF3C2" stop-opacity="0"/>
    </radialGradient>
  </defs>"""


BACKGROUND_BODY = """  <rect width="1254" height="1254" fill="url(#sky)"/>
  <rect width="1254" height="1254" fill="url(#warmHalo)"/>
  <g fill="#FFF4C8" opacity="0.045">
    <path d="M617 420L570-650H684L637 420Z"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(20 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(40 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(60 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(80 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(100 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(120 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(140 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(160 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(180 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(200 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(220 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(240 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(260 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(280 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(300 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(320 627 420)"/>
    <path d="M617 420L570-650H684L637 420Z" transform="rotate(340 627 420)"/>
  </g>
  <rect width="1254" height="1254" fill="url(#centerBloom)"/>
  <g fill="url(#sparkleGlow)">
    <circle cx="1000" cy="152" r="58"/>
    <circle cx="137" cy="683" r="58"/>
    <circle cx="869" cy="971" r="58"/>
  </g>
  <g fill="#FFF9E7" stroke="#FFE6A7" stroke-width="3">
    <path d="M1000 110C1007 137 1015 145 1042 152C1015 159 1007 167 1000 194C993 167 985 159 958 152C985 145 993 137 1000 110Z"/>
    <path d="M137 641C144 668 152 676 179 683C152 690 144 698 137 725C130 698 122 690 95 683C122 676 130 668 137 641Z"/>
    <path d="M869 929C876 956 884 964 911 971C884 978 876 986 869 1013C862 986 854 978 827 971C854 964 862 956 869 929Z"/>
  </g>"""


MONOCHROME_SVG = f"""<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" width="432" height="432" viewBox="0 0 1254 1254">
  <title>color king adaptive monochrome icon</title>
  <g transform="{ADAPTIVE_CROWN_TRANSFORM}" fill="none" stroke="#000" stroke-linecap="round" stroke-linejoin="round">
    <path stroke-width="42" d="M318 287L522 421L646 274L769 421L974 287L886 786H398L318 287Z"/>
    <circle stroke-width="36" cx="318" cy="287" r="57"/>
    <circle stroke-width="36" cx="646" cy="252" r="57"/>
    <circle stroke-width="36" cx="974" cy="287" r="57"/>
    <path stroke-width="25" d="M354 542H637V649H526V704H402M648 542H916M648 542V649H762V704H886M402 704H526V658H762V704H886"/>
  </g>
  <g transform="{ADAPTIVE_LION_TRANSFORM}">
    <g fill="none" stroke="#000" stroke-linecap="round" stroke-linejoin="round">
    <path stroke-width="43" d="M35 1254C26 1178 31 1090 70 1008C107 932 173 875 243 861C253 821 290 796 330 804C363 777 414 795 434 831C478 815 529 844 541 890C568 901 584 919 593 943"/>
    <path stroke-width="38" d="M83 1117C83 997 172 909 301 909C429 909 523 1004 523 1128C523 1181 505 1224 480 1254"/>
    <path stroke-width="44" d="M590 1184C631 1104 650 1024 658 938C662 892 682 849 714 845C754 841 778 881 769 925C749 1021 708 1133 650 1218"/>
    <path stroke-width="26" d="M690 874C708 858 735 861 750 878"/>
    <path stroke-width="27" d="M284 1093C319 1080 354 1084 381 1104"/>
    <path stroke-width="23" d="M329 1140C327 1185 387 1197 416 1161"/>
    </g>
    <g fill="#000">
    <ellipse cx="274" cy="1048" rx="33" ry="42"/>
    <ellipse cx="462" cy="1008" rx="34" ry="43"/>
    <path d="M341 1106C362 1087 395 1085 420 1103C407 1127 367 1130 341 1106Z"/>
    <ellipse cx="697" cy="883" rx="17" ry="20"/>
    <ellipse cx="731" cy="879" rx="12" ry="17"/>
    <ellipse cx="748" cy="908" rx="12" ry="17" transform="rotate(20 748 908)"/>
    <ellipse cx="677" cy="908" rx="12" ry="17" transform="rotate(-20 677 908)"/>
    </g>
  </g>
</svg>
"""


def run(command: list[str]) -> None:
    subprocess.run(command, cwd=ROOT, check=True)


def svg_body(svg_text: str) -> str:
    svg_index = svg_text.index("<svg")
    body_start = svg_text.index(">", svg_index) + 1
    body_end = svg_text.rindex("</svg>")
    return svg_text[body_start:body_end].strip()


def wrap_svg(title: str, width: int, defs: str, body: str) -> str:
    return (
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{width}" viewBox="0 0 1254 1254">\n'
        f'  <title>{title}</title>\n'
        f'{defs}\n{body}\n'
        '</svg>\n'
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--reference", type=Path, default=DEFAULT_REFERENCE)
    parser.add_argument("--vtracer", type=Path, default=Path(os.environ.get("VTRACER_BIN", "vtracer")))
    args = parser.parse_args()

    if not args.reference.is_file():
        raise SystemExit(f"reference image is missing: {args.reference}")

    with tempfile.TemporaryDirectory(prefix="color-king-icon-") as temporary_directory:
        temporary = Path(temporary_directory)
        extracted_png = temporary / "foreground.png"
        crown_png = temporary / "crown.png"
        lion_png = temporary / "lion.png"
        traced_svg = temporary / "foreground.svg"
        crown_svg = temporary / "crown.svg"
        lion_svg = temporary / "lion.svg"

        run([
            "swift",
            str(ROOT / "tools" / "extract_app_icon_foreground.swift"),
            str(args.reference),
            str(extracted_png),
            str(crown_png),
            str(lion_png),
        ])
        for source_png, output_svg in (
            (extracted_png, traced_svg),
            (crown_png, crown_svg),
            (lion_png, lion_svg),
        ):
            run([
                str(args.vtracer),
                str(source_png),
                str(output_svg),
                "--preset", "photo",
                "--mode", "spline",
                "--filter-speckle", "2",
                "--color-precision", "8",
                "--gradient-step", "2",
                "--simplify", "0.55",
                "--path-precision", "2",
                "--optimize", "1",
            ])

        foreground_body = svg_body(traced_svg.read_text(encoding="utf-8"))
        crown_body = svg_body(crown_svg.read_text(encoding="utf-8"))
        lion_body = svg_body(lion_svg.read_text(encoding="utf-8"))

    foreground_svg = wrap_svg(
        "color king adaptive icon foreground",
        432,
        "",
        (
            f'  <g transform="{ADAPTIVE_CROWN_TRANSFORM}">\n'
            f'{crown_body}\n'
            '  </g>\n'
            f'  <g transform="{ADAPTIVE_LION_TRANSFORM}">\n'
            f'{lion_body}\n'
            '  </g>'
        ),
    )
    background_svg = wrap_svg(
        "color king adaptive icon background",
        432,
        SVG_DEFS,
        BACKGROUND_BODY,
    )
    composite_svg = wrap_svg(
        "color king app icon",
        1024,
        SVG_DEFS,
        f"{BACKGROUND_BODY}\n{foreground_body}",
    )

    (ROOT / "assets" / "icon_foreground.svg").write_text(foreground_svg, encoding="utf-8")
    (ROOT / "assets" / "icon_background.svg").write_text(background_svg, encoding="utf-8")
    (ROOT / "assets" / "icon.svg").write_text(composite_svg, encoding="utf-8")
    (ROOT / "assets" / "icon_monochrome.svg").write_text(MONOCHROME_SVG, encoding="utf-8")

    print(f"foreground paths: {foreground_body.count('<path')}")
    print("wrote assets/icon.svg and adaptive icon layers")


if __name__ == "__main__":
    main()
