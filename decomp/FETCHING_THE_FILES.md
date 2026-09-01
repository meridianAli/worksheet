# Getting the workbooks out — what runs where

**Metabase cannot fetch the files.** It is a SQL interface to Postgres; the
workbooks live in blob storage and Postgres has no path to them. There is no
Metabase feature that downloads a workbook, so "run it in Metabase" is not a
thing that can work, however the query is written.

**This session cannot fetch them either.** The agent proxy allows `data.tsip.ai`
(Metabase) and a handful of SaaS APIs. The TSIP backend that serves files is
blocked:

```
app.tsip.ai   -> CONNECT tunnel failed, 502
api.tsip.ai   -> CONNECT tunnel failed, 502
```

And `tsip_files.public_url` is null on all 3,278 workbooks — only `blob_path`
storage keys, with no host.

So the split is: **Metabase produces the work list, a script with credentials
does the fetching and the analysis.**

## 1. The manifest — done, and it runs in Metabase

`workbook_manifest.sql` → `workbook_manifest.csv`, already run: **1,281 tasks**
over 14 days, **38 of them failures**, every row carrying

- `has_outline` — the label to compare against
- `input_file_id` / `output_file_id`, their sizes and `blob_path`s
- `input_tokens` / `output_tokens` and the `empty_context` flag
- **`agent_output_blob_path`** — populated on all 1,281 rows. This is the
  `data-compass` blob whose headers include `task_outline_og`: **the agent's raw
  response.** Reading one failing row's blob answers the whole question directly,
  instead of inferring from token counts.

## 2. Fetch — `fetch_workbooks.py`

```bash
export TSIP_API=https://<backend-host>
export TSIP_TOKEN=<bearer token>
python3 fetch_workbooks.py --manifest workbook_manifest.csv --out ./blobs --only-failures
```

Uses `GET /api/files/<fileId>?taskId=<taskId>` — confirmed working in the request
logs (200, ~20–30 ms). Concurrent, resumable, skips what is already on disk.
Add `--blob-cmd 'gsutil cp gs://<bucket>/{path} {dest}'` (or the `aws`/`az`
equivalent) to also pull the agent-output blobs; without it they are skipped.

Start with `--only-failures` — 38 tasks, 76 files.

## 3. Analyse — `analyze_workbooks.py`

```bash
python3 analyze_workbooks.py --manifest workbook_manifest.csv --blobs ./blobs --out workbook_audit.csv
```

Applies to the whole corpus what was measured by hand on one pair, and prints the
failed-vs-succeeded comparison that settles the bloat theory. Reads each xlsx as a
zip — no openpyxl, no formula evaluation.

**It is validated against the two known files.** Every number it produces matches
the hand analysis:

| | Input `049-N-1` | Output `049-N-0` |
|---|---:|---:|
| sheets | 20 | 20 |
| formulas | 2,831 | 12,904 |
| defined names | 14,106 | 14,106 |
| defined-name bytes | 1,153,427 | 1,153,427 |
| % of workbook | 45.9% | 35.2% |
| names referenced by a formula | **0** | **0** |
| names resolving to `#REF!` | 388 | 388 |

Getting that last row to a true 0 took two fixes worth knowing about, because
both inflate the count in the obvious naive version: quoted sheet references
(`'Nov18 BS'!D42` looks like a use of a name `BS`) and shared-formula stubs
(`<f t="shared" si="0"/>`, where a dotall match swallows raw XML and the tag name
`f` collides with a defined name actually called `f`).

## What the results would settle

- **`input_pct_defined_names`, failed vs succeeded.** If failing tasks carry
  materially more bloat, the size-guard theory holds. If the medians match, the
  one 46%-junk workbook was a coincidence and the theory dies.
- **`names_referenced_by_a_formula` across the corpus.** If it stays ~0, stripping
  `<definedNames>` before serialising is safe to ship as a rule, not just on one
  file.
- **`agent_outline_head` on the 38 failures.** The agent's own words. Every
  conclusion in `OUTLINE_GENERATION_FAILURE.md` is inference from token counts
  and durations; this is the primary source.
