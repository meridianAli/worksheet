# Five banker monologues

Training data: five investment-banking model builds, each written as **one
senior banker briefing an analyst out loud** — no staging, no dialogue, just
what gets said.

Each monologue is derived from a real task (input workbook → build spec →
output workbook) and is **tested against the workbooks themselves**, not against
the spec text. If a script omits something the analyst could not have worked out
on their own, the test fails and names it.

```sh
python3 tests/fetch_task_workbooks.py --export data/tasksexport20260904.json  # once
python3 tests/run_tests.py     # every script vs. its workbook pair
python3 tests/test_teeth.py    # negative controls - prove the test can fail
```

## The five

| # | Script | Deal | The build | Cell changes | Enforced |
|---|---|---|---|---:|---:|
| 1 | [`2266fdca`](scripts/2266fdca.md) | Sell-side, sponsor-owned distributor | P&L, working capital, debt schedule, EBITDA bridge | 816 | 45 |
| 2 | [`b68326d5`](scripts/b68326d5.md) | Cedarbrook Social IPO | Sources & uses, pro forma balance sheet, valuation, four sensitivity grids | 329 | 56 |
| 3 | [`bb849b91`](scripts/bb849b91.md) | Four-entity Egyptian real estate | Annual cashflow statements, four entities | 2,310 | 2 |
| 4 | [`ef94a62b`](scripts/ef94a62b.md) | SBA-financed owner-user acquisition | Sources & uses, returns, three amortization tabs | 27,450 | 52 |
| 5 | [`fbe4760b`](scripts/fbe4760b.md) | Cedarbrook asset-management forecast | AUM rollforward, fee build, five-year revenue forecast | 1,198 | 24 |

**32,103 cell changes across the five, of which 180 had to be spoken.** The rest
is work an analyst does from the source file and a clear ask — and a script that
recited it would be a worse script, not a better one. How that line is drawn:
[`tests/README.md`](tests/README.md).

## Reading them

- [`MONOLOGUES.md`](MONOLOGUES.md) — all five in one document
- [`Five-Monologues.pdf`](Five-Monologues.pdf) — the same, print-ready, one scene per page
- [`scripts/`](scripts) — one file per script; this is what the tests read

## Layout

```
scripts/          the five monologues, one per task id     <- the deliverable
MONOLOGUES.md     all five, plus the summary table
Five-Monologues.pdf

tests/            does each script cover its workbook diff?
  run_tests.py            all five, one exit code
  test_teeth.py           negative controls
  wbdiff.py               input vs output, cell by cell
  coverage.py             changes + input vocabulary + script -> covered / missed
  standard_lexicon.txt    vocabulary treated as derivable (the strictness dial)
  fetch_task_workbooks.py pulls the workbooks from the export's signed URLs
  diffs/                  cached cell-level diffs, so a run needs no re-diff
  README.md               how a change becomes a requirement, and what is not caught

data/             the task export the whole repo derives from
tools/pdf/        MONOLOGUES.md -> Five-Monologues.pdf
wb/               fetched workbooks (gitignored - re-fetch, don't commit)
```

Requires `openpyxl` for the tests; the PDF build additionally needs `markdown`,
`playwright` and a local Chromium.
