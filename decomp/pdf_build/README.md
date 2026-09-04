# Building the scenarios PDF

Turns [`../BANKER_SCENARIOS.md`](../BANKER_SCENARIOS.md) into a self-contained,
print-ready PDF — no network dependency, fonts inlined.

```sh
python3 fonts.py     # -> fonts-inline.css  (IBM Plex latin subsets as base64 woff2)
python3 mkprint.py   # -> banker-scenarios-print.html  (standalone + print stylesheet)
node    mkpdf.mjs    # -> ../Banker-Scenarios.pdf
```

Requires Chromium at `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`, the
globally installed `playwright`, and `pip install markdown`. `fonts.py` is a copy
of the one in `../../aht/pdf_build/`.

`mkprint.py` beyond the markdown conversion:

- drops the `---` rules; each scene heading carries its own `break-before: page`,
  so one scene is one page and the six-page PDF stays navigable
- styles a wholly-italic paragraph as a stage direction rather than prose
- repeats `<thead>` across pages and keeps table rows and list items whole
