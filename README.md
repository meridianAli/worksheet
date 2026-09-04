# Five briefing scripts

Training data: five investment-banking model builds, each written as **one
senior banker briefing an analyst out loud** — no staging, no dialogue, just
what gets said, start to finish.

Each script comes from a real task (input workbook → build spec → output
workbook) and is checked two ways:

- **Does it cover the work?** The input and output workbooks are diffed cell by
  cell. Anything the analyst could not have derived on their own has to be in
  the speech, or the test fails and names it.
- **Is it English?** Every sentence has to carry a verb. The first draft of
  these did not — chasing clipped banker speech produced strings of verbless
  fragments — so that is now linted for directly.

```sh
python3 tests/fetch_task_workbooks.py --export data/tasksexport20260904.json  # once
python3 tests/run_tests.py     # every script vs. its workbook pair
python3 tests/test_teeth.py    # negative controls - prove the test can fail
python3 tests/prose_lint.py    # every sentence carries a verb
```

## The five

| # | Script | Deal | The build | Cell changes | Enforced |
|---|---|---|---|---:|---:|
| 1 | [`2266fdca`](scripts/2266fdca.md) | Sell-side, sponsor-owned distributor | P&L, working capital, debt schedule, EBITDA bridge | 816 | 45 |
| 2 | [`b68326d5`](scripts/b68326d5.md) | Cedarbrook Social IPO | Sources & uses, pro forma balance sheet, valuation, four sensitivity grids | 329 | 57 |
| 3 | [`bb849b91`](scripts/bb849b91.md) | Four-entity Egyptian real estate | Annual cashflow statements, four entities | 2,310 | 2 |
| 4 | [`ef94a62b`](scripts/ef94a62b.md) | SBA-financed owner-user acquisition | Sources & uses, returns, three amortization tabs | 27,450 | 52 |
| 5 | [`fbe4760b`](scripts/fbe4760b.md) | Cedarbrook asset-management forecast | AUM rollforward, fee build, five-year revenue forecast | 1,198 | 24 |

**32,103 cell changes across the five, of which 180 had to be spoken.** The
rest is work an analyst does from the source file and a clear ask — a script
that recited it would be a worse script, not a better one. How that line is
drawn: [`tests/README.md`](tests/README.md).

## Reading them

- [`SCRIPTS.md`](SCRIPTS.md) — all five in one document
- [`Five-Briefing-Scripts.pdf`](Five-Briefing-Scripts.pdf) — the same, print-ready
- [`scripts/`](scripts) — one file per task; this is what the tests read

## Layout

```
scripts/          the five scripts, one per task id        <- the deliverable
SCRIPTS.md        all five, plus the summary table
Five-Briefing-Scripts.pdf

tests/            does each script cover its workbook diff, and read as English?
  run_tests.py            all five, one exit code
  test_teeth.py           negative controls
  prose_lint.py           flags sentences with no verb
  wbdiff.py               input vs output, cell by cell
  coverage.py             changes + input vocabulary + script -> covered / missed
  standard_lexicon.txt    vocabulary treated as derivable (the strictness dial)
  fetch_task_workbooks.py pulls the workbooks from the export's signed URLs
  diffs/                  cached cell-level diffs, so a run needs no re-diff
  README.md               how a change becomes a requirement, and what is not caught

data/             the task export the whole repo derives from
tools/pdf/        SCRIPTS.md -> Five-Briefing-Scripts.pdf
wb/               fetched workbooks (gitignored - re-fetch, don't commit)
```

Requires `openpyxl` for the tests; the PDF build additionally needs `markdown`,
`playwright` and a local Chromium.
