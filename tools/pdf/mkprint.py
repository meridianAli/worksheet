"""Turn OUTLINES.md into a standalone, print-ready HTML page.

  python3 fonts.py     # -> fonts-inline.css (IBM Plex latin subsets, base64 woff2)
  python3 mkprint.py   # -> outlines-print.html
  node    mkpdf.mjs    # -> ../../Five-Briefing-Outlines.pdf
"""
import re, pathlib, markdown

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
SRC = ROOT / "OUTLINES.md"
OUT = pathlib.Path(__file__).resolve().parent / "outlines-print.html"
FONTS = pathlib.Path(__file__).resolve().parent / "fonts-inline.css"

body = markdown.markdown(SRC.read_text(), extensions=["tables", "sane_lists"])

# The `---` rules only separate scenes; the scene headings carry the page breaks.
body = body.replace("<hr />", "")
# A paragraph that is wholly italic is a stage direction, not prose.
body = re.sub(r'<p><em>(.*?)</em></p>', r'<p class="direction">\1</p>', body, flags=re.S)
# First h2 needs no page break before it; the rest each open a page.
body = body.replace("<h2>", '<h2 class="scene">', 1).replace("<h2>", '<h2 class="scene brk">')

css = FONTS.read_text() + """
:root{
  --ink:#12181f; --muted:#5b6b7a; --rule:#d6dee6; --accent:#8a4b2a; --wash:#f5f2ee;
}
@page{ size:Letter; margin:14mm 12mm 16mm 12mm; }
html{ -webkit-print-color-adjust:exact; print-color-adjust:exact; }
body{
  font-family:"IBM Plex Sans",system-ui,sans-serif; font-size:9.8pt; line-height:1.52;
  color:var(--ink); background:#fff; margin:0;
}
h1{
  font-family:"IBM Plex Sans Condensed","IBM Plex Sans",sans-serif; font-weight:700;
  font-size:20pt; line-height:1.15; letter-spacing:-.01em; margin:0 0 .35em;
}
h1 + p{ color:var(--muted); }
h3{
  font-family:"IBM Plex Sans Condensed","IBM Plex Sans",sans-serif; font-weight:600;
  font-size:10.5pt; margin:1.1em 0 .35em; color:var(--ink);
  break-after:avoid; break-inside:avoid;
}
h2.scene{
  font-family:"IBM Plex Sans Condensed","IBM Plex Sans",sans-serif; font-weight:600;
  font-size:13pt; line-height:1.25; margin:0 0 .2em; padding:0 0 .35em;
  border-bottom:1.5pt solid var(--accent); color:var(--accent);
  break-after:avoid; break-inside:avoid;
}
h2.brk{ break-before:page; margin-top:0; }
p{ margin:0 0 .62em; orphans:2; widows:2; }
p.direction{
  color:var(--muted); font-style:italic; font-size:9.2pt;
  margin:.5em 0 1em; padding-left:.7em; border-left:2pt solid var(--rule);
  break-inside:avoid; break-after:avoid;
}
strong{ font-weight:600; }
ul{ margin:.1em 0 .8em; padding-left:1.15em; }
li{ margin:0 0 .22em; break-inside:avoid; }
code{
  font-family:"IBM Plex Mono",ui-monospace,monospace; font-size:8.6pt;
  background:var(--wash); padding:.06em .3em; border-radius:2px; white-space:nowrap;
}
table{ border-collapse:collapse; width:100%; font-size:8.4pt; margin:.5em 0 1.1em; }
thead{ display:table-header-group; }
th,td{ text-align:left; vertical-align:top; padding:.3em .5em; border-bottom:.5pt solid var(--rule); }
th{
  font-family:"IBM Plex Sans Condensed","IBM Plex Sans",sans-serif; font-weight:600;
  background:var(--wash); border-bottom:1pt solid var(--muted); white-space:nowrap;
}
td code{ background:none; padding:0; }
tr{ break-inside:avoid; }
"""

OUT.write_text(
    "<!doctype html><html lang=\"en\"><head><meta charset=\"utf-8\">"
    "<title>Five briefing outlines</title><style>" + css + "</style></head><body>"
    + body + "</body></html>"
)
print(OUT.name, OUT.stat().st_size, "bytes")
