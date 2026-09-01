# Tasks in decomp review

Snapshot taken **2026-09-01 ~20:15 UTC** against `tsip_prd` (Metabase database id 2).

## Answer

**173 live tasks are in decomp review, all on `sheets`.** Full list:
[`decomp_review_queue.csv`](decomp_review_queue.csv) (259 rows — 173 live, 86 archived).

| Project | State | Tasks | Live | Archived |
|---|---|---|---:|---:|
| `sheets` | `decomp_review` | 186 | **173** | 13 |
| `advanced-workbook-project` | `pending_decomp_review` | 71 | 0 | 71 |
| `legacy-archive-advanced-workbook` | `pending_decomp_review` | 2 | 0 | 2 |

Only `sheets` has a live decomp-review queue. The other two projects are dead —
every row in them is archived, frozen since 2026-06-08 and 2026-05-22.

## Two states share the name

There is no single "decomp review" field to filter on. The name appears as two
different states depending on the project's pipeline, and a query that matches
only one of them silently misses the other:

- `decomp_review` — sheets
- `pending_decomp_review` — advanced-workbook-project, legacy-archive-advanced-workbook

`sheets` also *used* to have a `pending_decomp_review` state (1,164 historical
transitions into it) but no task sits in it today, so its current pipeline is
the `decomp_review` one. Both names are matched in the queue query.

## What the 173 actually are

Not a backlog — a normal working queue, roughly one day of inflow:

- Every one arrived from `generating_outline`, moved by the system
  (`triggered_by` is the all-zeros service UUID, no human user).
- Every one is pooled (`pooled_at` set) and **none is assigned or claimed** —
  this state is a pool reviewers pull from, so an empty `assigned_to` column is
  expected, not a sign of unstaffed work.
- Oldest has been waiting **1.2 days**; median **0.8 days**. Nothing is stale.

Inflow and turnover over the last week (`decomp_review_flow.sql`, ET days):

| Day | Entered | Exited | Median dwell | → `generating_prompt` | → back to `generating_outline` | Cancelled |
|---|---:|---:|---:|---:|---:|---:|
| 2026-08-25 | 62 | 62 | 44.1 h | 60 | 1 | 0 |
| 2026-08-26 | 145 | 145 | 24.4 h | 132 | 5 | 1 |
| 2026-08-27 | 125 | 125 | 11.1 h | 92 | 13 | 3 |
| 2026-08-28 | 137 | 137 | 68.0 h | 102 | 34 | 0 |
| 2026-08-29 | 131 | 131 | 44.9 h | 112 | 19 | 0 |
| 2026-08-30 | 176 | 176 | 18.9 h | 151 | 21 | 4 |
| 2026-08-31 | 177 | 89 | 1.8 h | 78 | 6 | 0 |
| 2026-09-01 | 85 | 0 | — | 0 | 0 | 0 |

The 173 open ones are exactly the unexited remainder of 08-31 (88) plus all of
09-01 so far (85). Roughly **85% of reviewed decomps advance** to
`generating_prompt`; ~10% go back to `generating_outline` for rework.

**Don't read a trend into median dwell.** It swings 1.8–68 h day to day on
reviewer availability, not on decomp quality — the same batching effect
documented for AHT in `../aht/README.md`.

## Files

| File | Use |
|---|---|
| `decomp_review_queue.sql` | The list. Matches both state names, flags archived rather than dropping it, and takes entry time from the transition log (not `tasks.updated_at`, which any unrelated write bumps). |
| `decomp_review_queue.csv` | Its output at the snapshot time above. Re-run the SQL for a live figure — this queue turns over in about a day. |
| `decomp_review_flow.sql` | Inflow, dwell and exit destinations by day. Run this before calling any queue depth good or bad. |
