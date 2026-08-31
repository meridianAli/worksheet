# Staged ground-truth additions for `projects/sheets/project.md`

**Status: NOT yet submitted.** Intended for `propose-ground-truth`, which needs a
whole-file write to `projects/sheets/project.md`. That was not possible from the
session that drafted this: the ClaudeContext repo could not be cloned (no git
credentials), `add_repo` refused it (`cross-tier adds are not supported in v1` —
the session was scoped to `meridianAli`), and raw/API fetches returned 404/403.
Retyping ~30KB of SOT from context into a repo that auto-merges on open, with no
review window, risked silently clobbering the file — so the blocks were staged
here instead.

**To land it:** run `/propose-ground-truth` from a session with ClaudeContext
access and paste the three blocks below into the named sections, then add the
changelog line. Verify the claims first with `patchbased_identifiability.sql` and
`sheets_aht_cost_per_task.sql` in this directory — all figures below came from
those two queries against `tsip_prd` on 2026-08-31.

---

## Block 1 → under `## Definitions`

### Task variety: patch-based vs greenfield 🟡
Sheets tasks come in two varieties, used constantly by ops and in customer
distribution lists but **not modelled anywhere in the platform**: **patch-based**
(the contributor makes targeted edits to an existing workbook) and **greenfield**
(built from scratch). The Meta distribution list was 3,000 patch-based + 572
greenfield.
- **Not:** a project, a pipeline state, a task field, or a task-set kind. There is
  no `patch`/`motley` row in `tsip_projects`; no sheets pipeline state contains
  "patch"; `tsip_tasks.metadata` carries no variety marker.
- **Not:** recoverable for greenfield at all — greenfield has **no** marker in the
  database. Its counts are known only from ops spreadsheets and Slack.
- **Logic (the only marker that exists, and it is legacy):**
  `tsip_attempts.metadata -> 'tmp_deliveries'[] ->> 'tmp_delivery_batch' ~* 'patchbased'`
  — a backfill of delivery ZIP filenames (e.g.
  `meridian_patchbased_450ct_06.14.26.zip`) onto attempts. Note the `tmp_` prefix:
  explicitly temporary. It covers 3,050 distinct tasks across 14 ZIPs delivered to
  Meta 2026-02-09 → 2026-06-15, and **only tasks that were delivered**, so it can
  never identify in-flight work.
- **"Motley"** is the codename for the workstream on the patch-based pipeline
  (Slack `#motley-patch-based-pipeline`), not a separate project or pipeline.

### Cost-grounded AHT (sheets) 🟡
Fully-loaded handling time and cost per task:
`payable hours booked to sheets in the window ÷ tasks first entering audit in the
window`. Fully loaded on purpose — training, calibration, rework and QA are all
real project cost. Cost is the same ratio with accrued dollars on top.
- **Not:** per patch-based or per greenfield — see the variety definition above.
  This is always a **blended** figure across varieties.
- **Not:** on the `clocked` basis. Hours must be **payable**
  (`payable_time_entries` + latest `payable_time_revisions`, day-allocated via
  `payable_time_revision_segments`); clocked runs ~7% above payable on sheets.
- **Not:** denominated on `complete` or `delivery_holding`. Those are
  delivery-batch bottlenecked and measure cadence, not handling time — the same
  hours over `complete` give 21.81 h/task and over `delivery_holding` 78.76 h/task,
  vs 2.42 on entered-audit. `audit` is already this project's canonical
  "Tasks Completed" and the passing state the platform revenue query uses.
- **Not:** costed from the `contributor_earnings` ledger, which lags p90 ≈ 21h and
  makes recent days read cheap. Use accrued (payable seconds × in-effect
  `contributor_rates`); it reconciles to the ledger within ±0.7%.
- **Logic:** `aht/sheets_aht_cost_per_task.sql` (params `start_date`, `end_date`,
  both inclusive ET dates). Current values are time-dependent — fetch live.

## Block 2 → under `## Conventions & pitfalls`

- **A patch-based (or greenfield) AHT cannot be produced from platform data.** Two
  independent blockers. *(1) Attribution:* hours attach to the **project**, never
  a task or variety — `timer_sessions.active_project_id` and
  `payable_time_revisions.project_id` are both project-grain, and
  `payable_time_revisions.task_type`, the one column that could carry it, is
  populated on **0 of 9,977** sheets rows. The two varieties ran concurrently with
  the same contributors, so their hours are commingled and unsplittable even in
  principle. *(2) Time coverage:* the patch-based marker covers deliveries
  2026-02-09 → 2026-06-15 while sheets payable-hours data effectively begins
  2026-07 (Feb 0h, Apr 0h, May 5h, Jun 58h, Jul 2,939h, Aug 3,755h) — **zero**
  months carry both. The Feb–Jun work was paid off-platform via the ops claim
  sheet. Verify with `aht/patchbased_identifiability.sql`; fixing this needs a
  task-variety field going forward (it cannot be recovered retrospectively).
- **Every pre-existing AHT query on the platform uses the `clocked` basis** — the
  Prompt Tasker AHT panel (Q2029), the platform `throughput/avg_handling_time.sql`,
  and the per-project contributor dashboards all read
  `timer_sessions.total_seconds`. That is the wrong numerator for any cost
  question; use payable. Related: the platform standard-dashboard AHT tile keys on
  `from_state IN ('edit_task','redo_task')`, so it works on sheets but returns an
  empty denominator (and renders blank, not an error) on projects without those
  states.
- **Re-delivered inventory breaks per-task cost.** The 2026-08-19 Google DeepMind
  batch holds 1,900 tasks of which **1,721 were already delivered to Meta** in
  Feb–Jun — existing patch-based inventory monetised a second time at ~zero
  marginal labour. Never divide a period's labour by a delivery count that
  includes resold tasks.

## Block 3 → `## Changelog`

```
- 2026-08-31 — Added the patch-based/greenfield task-variety definition and the cost-grounded AHT definition (payable basis, entered-audit denominator), plus three pitfalls: a variety-specific AHT is not derivable from platform data (hours are project-grain, `payable_time_revisions.task_type` 0/9,977 populated, and the patch-based delivery marker and the payable-hours record share zero months); every existing AHT query uses the clocked basis; and re-delivered inventory breaks per-task cost. All figures verified against tsip_prd. (ali@meridian.ai via Claude)
```
