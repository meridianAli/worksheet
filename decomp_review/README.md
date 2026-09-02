# Sheets decomp review queue — live pull

Snapshot taken **2026-09-02 14:10 UTC** from `tsip_prd` (Metabase database id 2)
via `decomp_review_queue.sql`. Read-only; re-run the SQL for a fresh pull.

## Which queue this is

"Decomp review" resolves to two different states on the platform:

| Project | State | Tasks in it now |
|---|---|---|
| **`sheets`** | **`decomp_review`** | **112 (99 unarchived)** ← this pull |
| `advanced-workbook-project` | `pending_decomp_review` | 71 |

This pull is the `sheets` one — the exact state-name match, and the project the
rest of this repo works on. Swap the two literals in the SQL for the other queue.

## The snapshot

| | |
|---|---|
| Live tasks in `decomp_review` | **99** (13 more are archived) |
| Median time in state | **13.7 h** |
| Mean / max | 10.9 h / 16.2 h |
| Sitting > 12 h | **58 of 99** |
| Entered the state more than once | **48 of 99** (max 5 times) |
| Attempts per task | median 4, range 3–7 |

Three things are uniform across all 99 rows and are the real story:

- **Every task arrived from `generating_outline`** — nothing is entering this
  review from anywhere else.
- **Every transition was triggered by `00000000-0000-0000-0000-000000000000`**,
  i.e. the system, not a person. The queue is machine-fed.
- **`assigned_user_id` is NULL on all 99, and `timeout_at` on all 99.** Nothing
  is claimed and nothing will time out on its own, which is consistent with a
  median dwell of 13.7 h and a 16.2 h ceiling: the backlog isn't being worked,
  it's accumulating since roughly 2026-09-01 22:00 UTC.

Also note **48 of 99 have been through `decomp_review` before** — that is rework
re-entering the same gate, not first-pass volume, so a raw queue depth of 99
overstates how much new work is waiting.

## Files

| File | Use |
|---|---|
| `decomp_review_queue.sql` | The pull. One row per task currently in `decomp_review`, with dwell time, entry count, attempt count and assignment state. |
