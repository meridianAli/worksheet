# Building the PDF

Turns `../august_aht_working_paper.html` (authored for the artifact wrapper, so it has
no `<!doctype>`/`<head>`) into a self-contained, print-ready PDF.

```sh
python3 fonts.py     # -> fonts-inline.css  (IBM Plex latin subsets as base64 woff2)
python3 mkprint.py   # -> aug-working-paper-print.html  (standalone + print stylesheet)
node    mkpdf.mjs    # -> August-AHT-Working-Paper.pdf
```

Run from a directory holding a copy of `august_aht_working_paper.html` named
`aug-working-paper.html`. Requires Chromium at
`/opt/pw-browsers/chromium-1194/chrome-linux/chrome` and the globally installed
`playwright` package.

What `mkprint.py` does beyond wrapping:

- inlines the webfaces so the PDF has no network dependency
- pins the light palette (the dark-mode block is disabled for print)
- unwinds `.scroll{overflow-x:auto}` and shrinks `table.dense` so the 12-column
  roster fits the Letter content box instead of being clipped
- repeats `<thead>` on every page and keeps table rows, list items and figures
  whole across page breaks
