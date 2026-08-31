# Contributor productivity & cost-to-stage — method notes

Window used throughout: **2026-07-01 → 2026-08-31**, project `sheets`,
2,726 tasks reaching `audit`. `audit` = done (confirmed by Ali, and canonical in
sheets ground truth).

## Query set

| File | Produces |
|---|---|
| `contributor_a_hours.sql` | per-contributor payable hours, break/idle, accrued cost, active days, rate |
| `contributor_b1.sql` | per-contributor stage advances + submissions |
| `contributor_b2.sql` | per-contributor tasks credited to `audit`, and redo events on those tasks |
| `contributor_b3.sql` | names, roles, stage, deactivated flag |
| `stage_work_time_by_user.sql` | per-user per-stage work time — the cost-to-stage allocation weight |
| `stage_dwell_time.sql` | calendar dwell per state (median/p90) — cycle-time decomposition |
| `rework_distribution.sql` | redo bands, first-pass yield, edit→audit cycle time by band |
| `excluded_cost_buckets.sql` | what the labour figure leaves out (seeds, internal ops, non-hourly) |

The four `contributor_*` queries are deliberately split: run as one statement they
time out server-side. Merge on `user_id` client-side.

## How cost-to-stage is derived (read before quoting it)

There is **no task-level or stage-level time in the platform.** Payable time is
project-grain. So stage cost is an **allocation model**, not a measurement:

1. For each claim in `tsip_task_claims`, take its active window
   `[claimed_at, LEAST(last_activity_at, claimed_at + 12h)]`.
2. Intersect that window with the states the task **actually occupied**, from
   `tsip_state_transitions` (LEAD-derived intervals).
3. Sum overlap per (user, state) → that user's stage mix.
4. Allocate the user's payable hours and accrued cost across states in that
   proportion.

**Do not use `tsip_task_claims.task_state_at_claim` for this.** It is a snapshot
of the state at claim time, and `review_gate` is a state tasks flicker through
(9,399 entries, ~27 total state-hours). Allocating on it puts 43% of cost in
`review_gate`, which is an artifact — those claims actually span `redo_task`.
This mistake was made and corrected; the interval-intersection above is the fix.

**Sensitivity.** The 12h cap matters. Rework's share of labour cost across caps:
2h → 46.3%, 4h → 48.5%, 12h → 52.0%, 24h → 54.2%. So "rework is roughly half the
labour bill" is robust; the exact figure is not. Quote a range.

## Headline results

Loaded cost per task reaching audit:

| Bucket | USD | /task | Note |
|---|---|---|---|
| Contributor labour (sheets, hourly) | 1,121,528 | $411 | |
| Seed acquisition (`sheets-artifact-collection`) | 144,006 | $53 | piece-rate, **different project** |
| Internal ops labour on sheets | 254 | $0 | only 5 rows — internal time is barely booked |
| Non-hourly sheets earnings | 568 | $0 | |
| **Total measured** | **1,266,356** | **$465** | |
| AI / compute | — | — | **not tracked**: `tsip_ai_spend_events` has 0 rows, all time |

Labour by pipeline phase (allocation model above):

| Phase | USD | /task | % labour |
|---|---|---|---|
| Redo (rework loop) | 583,214 | $214 | 52% |
| Edit task (build sheet) | 215,858 | $79 | 19% |
| Decomp (author outline) | 195,645 | $72 | 17% |
| Calibration / onboarding | 73,635 | $27 | 7% |
| Human review | 18,977 | $7 | 2% |
| Failure / retry states | 11,432 | $4 | 1% |
| Decomp review | 5,532 | $2 | 0.5% |
| Automated gates | 7 | $0 | ~0% |

Rework: **first-pass yield 23.7%** (657 of 2,768 tasks need no redo). 6,472 redo
events at ~$90 each. Cycle time scales directly with redos — median edit→audit is
1.0 day at 0 redos, 9.1 days at 10+.

Contributor AHT spread across the 60 rateable contributors (≥5 tasks): min 0.82h,
median 1.74h, p75 2.79h, max 21.26h — a **26x** spread.

## Caveats that must travel with these numbers

- Stage cost is an allocation, not a measurement (see above).
- The window mixes varieties: patch-based cannot be separated (see
  `patchbased_identifiability.sql`). All of this is blended.
- Seed spend and task-to-audit counts are **period ratios, not cohort-matched** —
  the seeds bought in July are not the tasks audited in July.
- AI/compute is absent, so every figure here understates true loaded cost, and
  auto-review will move cost from labour into a bucket nobody is measuring.
- No sheets bill rate exists in any system; margin figures are scenarios only.
