#!/usr/bin/env python3
from __future__ import annotations

import html
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "PRODUCT_REQUIREMENTS.md"
TARGET = ROOT / "docs" / "PRODUCT_REQUIREMENTS.html"


def inline(text: str) -> str:
    escaped = html.escape(text)
    escaped = re.sub(r"`([^`]+)`", r"<code>\1</code>", escaped)
    escaped = re.sub(
        r"!\[([^\]]*)\]\(([^)]+)\)",
        lambda m: f'<figure><img src="{html.escape(m.group(2), quote=True)}" alt="{html.escape(m.group(1), quote=True)}"><figcaption>{html.escape(m.group(1))}</figcaption></figure>',
        escaped,
    )
    escaped = re.sub(
        r"\[([^\]]+)\]\(([^)]+)\)",
        lambda m: f'<a href="{html.escape(m.group(2), quote=True)}">{m.group(1)}</a>',
        escaped,
    )
    return escaped


def render_table(lines: list[str]) -> str:
    rows = []
    for line in lines:
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        rows.append(cells)
    if len(rows) < 2:
        return "".join(f"<p>{inline(line)}</p>" for line in lines)
    header = rows[0]
    body = rows[2:]
    out = ["<div class=\"table-wrap\"><table><thead><tr>"]
    out.extend(f"<th>{inline(cell)}</th>" for cell in header)
    out.append("</tr></thead><tbody>")
    for row in body:
        out.append("<tr>")
        out.extend(f"<td>{inline(cell)}</td>" for cell in row)
        out.append("</tr>")
    out.append("</tbody></table></div>")
    return "".join(out)


def convert(markdown: str) -> str:
    out: list[str] = []
    lines = markdown.splitlines()
    i = 0
    in_ul = False
    in_ol = False
    in_code = False
    code_lang = ""
    code_lines: list[str] = []

    def close_lists() -> None:
        nonlocal in_ul, in_ol
        if in_ul:
            out.append("</ul>")
            in_ul = False
        if in_ol:
            out.append("</ol>")
            in_ol = False

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        if stripped.startswith("```"):
            if in_code:
                out.append(f'<pre><code class="language-{html.escape(code_lang)}">{html.escape(chr(10).join(code_lines))}</code></pre>')
                in_code = False
                code_lang = ""
                code_lines = []
            else:
                close_lists()
                in_code = True
                code_lang = stripped[3:].strip()
            i += 1
            continue

        if in_code:
            code_lines.append(line)
            i += 1
            continue

        if not stripped:
            close_lists()
            i += 1
            continue

        if stripped.startswith("|") and i + 1 < len(lines) and re.match(r"^\s*\|?\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)+\|?\s*$", lines[i + 1]):
            close_lists()
            table_lines = [line, lines[i + 1]]
            i += 2
            while i < len(lines) and lines[i].strip().startswith("|"):
                table_lines.append(lines[i])
                i += 1
            out.append(render_table(table_lines))
            continue

        heading = re.match(r"^(#{1,6})\s+(.+)$", stripped)
        if heading:
            close_lists()
            level = len(heading.group(1))
            out.append(f"<h{level}>{inline(heading.group(2))}</h{level}>")
            i += 1
            continue

        ordered = re.match(r"^(\d+)\.\s+(.+)$", stripped)
        if ordered:
            if in_ul:
                out.append("</ul>")
                in_ul = False
            if not in_ol:
                out.append("<ol>")
                in_ol = True
            out.append(f"<li>{inline(ordered.group(2))}</li>")
            i += 1
            continue

        if stripped.startswith("- "):
            if in_ol:
                out.append("</ol>")
                in_ol = False
            if not in_ul:
                out.append("<ul>")
                in_ul = True
            out.append(f"<li>{inline(stripped[2:])}</li>")
            i += 1
            continue

        close_lists()
        if stripped.startswith("!["):
            out.append(inline(stripped))
            i += 1
            continue
        out.append(f"<p>{inline(stripped)}</p>")
        i += 1

    close_lists()
    return "\n".join(out)


def main() -> None:
    body = convert(SOURCE.read_text(encoding="utf-8"))
    TARGET.write_text(
        f"""<!doctype html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>color king 产品需求文档</title>
<style>
:root {{
  --ink: #26334A;
  --muted: #64748B;
  --line: #DDE6EF;
  --soft: #F6FAFE;
  --blue: #3E8DFF;
  --cream: #FFF8ED;
}}
* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  background: linear-gradient(180deg, #F3F8FD 0%, #FFFFFF 260px);
  color: var(--ink);
  font-family: -apple-system, BlinkMacSystemFont, "Noto Sans SC", "PingFang SC", Arial, sans-serif;
  font-size: 18px;
  line-height: 1.75;
}}
.page {{ max-width: 1180px; margin: 0 auto; padding: 40px 28px 90px; }}
.hero {{
  padding: 36px 40px;
  border-radius: 28px;
  color: white;
  background: linear-gradient(145deg, #3E8DFF 0%, #7CD2FF 82%);
  box-shadow: 0 20px 54px rgba(52, 124, 217, .22);
}}
.hero h1 {{ margin: 0; color: white; border: 0; padding: 0; font-size: 46px; }}
.hero p {{ margin: 10px 0 0; color: #F4FBFF; }}
.content {{
  margin-top: 28px;
  background: white;
  border: 2px solid var(--line);
  border-radius: 28px;
  padding: 34px 40px;
  box-shadow: 0 16px 48px rgba(38, 51, 74, .08);
}}
h1, h2, h3, h4, h5, h6 {{ line-height: 1.28; letter-spacing: 0; }}
h1 {{ font-size: 42px; margin: 0 0 20px; padding-bottom: 18px; border-bottom: 2px solid var(--line); }}
h2 {{ font-size: 34px; margin: 48px 0 18px; padding-top: 8px; border-top: 2px solid #EEF3F8; }}
h3 {{ font-size: 26px; margin: 34px 0 14px; }}
h4 {{ font-size: 22px; margin: 28px 0 10px; }}
p {{ margin: 12px 0; }}
ul, ol {{ padding-left: 26px; margin: 12px 0 18px; }}
li {{ margin: 6px 0; }}
code {{
  background: #EEF5FF;
  color: #1E5FBF;
  border-radius: 6px;
  padding: 2px 6px;
  font-size: .92em;
}}
pre {{
  overflow: auto;
  background: #1F2937;
  color: #F8FAFC;
  padding: 18px;
  border-radius: 16px;
}}
pre code {{ background: transparent; color: inherit; padding: 0; }}
a {{ color: #2563EB; }}
.table-wrap {{ overflow: auto; margin: 18px 0 24px; border: 1px solid var(--line); border-radius: 16px; }}
table {{ width: 100%; border-collapse: collapse; min-width: 720px; }}
th, td {{ padding: 12px 14px; border-bottom: 1px solid var(--line); vertical-align: top; text-align: left; }}
th {{ background: #F4F8FC; font-weight: 800; }}
tr:last-child td {{ border-bottom: 0; }}
figure {{
  margin: 22px 0 34px;
  padding: 18px;
  border: 2px solid var(--line);
  border-radius: 24px;
  background: var(--soft);
  overflow: auto;
}}
figure img {{
  display: block;
  width: auto;
  height: auto;
  max-width: none;
  background: white;
  border-radius: 12px;
}}
figcaption {{
  margin-top: 10px;
  color: var(--muted);
  font-size: 15px;
  font-weight: 700;
}}
@media (max-width: 760px) {{
  .page {{ padding: 18px 10px 60px; }}
  .hero, .content {{ padding: 24px 18px; border-radius: 22px; }}
  .hero h1 {{ font-size: 34px; }}
  h1 {{ font-size: 32px; }}
  h2 {{ font-size: 27px; }}
  h3 {{ font-size: 22px; }}
}}
</style>
</head>
<body>
<div class="page">
  <header class="hero">
    <h1>color king 产品需求文档</h1>
    <p>由 <code>docs/PRODUCT_REQUIREMENTS.md</code> 生成，图片按原尺寸展示；如果屏幕放不下，请在图片框内横向滚动查看。</p>
  </header>
  <main class="content">
{body}
  </main>
</div>
</body>
</html>
""",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
