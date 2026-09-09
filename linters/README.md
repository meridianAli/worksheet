# Zach-linter regression set (20 clear + 5 known-critical)

Purpose: a fixed set of Sheets tasks whose Zach-linter verdict is already known, so a
fresh local install of the linter package can be validated against expected output
before it is pointed at the 824-task backlog.

## Where the ground truth comes from

`list_of_qualifying_tasks___60__sota__2026-09-09T15_21_00Z.csv` (the qualifying-tasks
list, sota <= 0.60) carries a `Status` column holding the verdict from the linter runs
that have already happened:

| Status              | rows |
|---------------------|------|
| CLEAR               | 184  |
| CLEAR_MINOR_ONLY    | 1    |
| HOLD_CRITICAL       | 105  |
| T2_UNDER_AUDIT      | 160  |
| not yet run (`-`/empty) | 699 |

Only the first four groups have been through the linters. This set is drawn from
CLEAR and HOLD_CRITICAL.

## Selection

- `expect_clear` (20): `Status = CLEAR`, `review_score >= 4` (Opus-5 review), TSIP
  status `audit`. Picked evenly across the sota_score range (0.00 -> 0.60) so the set
  spans easy-for-SOTA through hard tasks rather than clustering.
- `expect_hold_critical` (5): `Status = HOLD_CRITICAL`, `review_score >= 4`, TSIP
  status `one_off_edit`. Negative controls — a run that returns these as clear means
  the critical checks are not firing.

Every task id was re-checked against `tsip_prd.analytics_tasks_latest` on 2026-09-09:
all 25 exist and still hold the status recorded here.

## How to read a run

- 20/20 `expect_clear` come back with no critical findings, and 5/5
  `expect_hold_critical` come back with at least one critical finding -> the setup
  reproduces the known output.
- A clear task flagged critical, or a critical task coming back clear, means the
  package, the model routing, or the task export differs from the run that produced
  these verdicts.

Note: the three AI judges make runs non-deterministic on wording and on minor/warning
findings. Compare on the critical-flag verdict, not on exact finding text.
