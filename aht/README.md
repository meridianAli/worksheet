# A reliable AHT for cost estimation

## Scope: patch-based / Motley

**The headline: patch-based cannot have its own AHT from platform data.** Not
"we haven't built it" — the data to build it does not exist. Two independent
blockers, both provable live via `patchbased_identifiability.sql`:

| Blocker | Evidence (tsip_prd, 2026-08-31) |
|---|---|
| **Attribution** — hours attach to the *project*, never a task or variety | `payable_time_revisions.task_type` populated on **0 of 9,977** sheets rows; `tsip_tasks.metadata` carries a variety marker on **0 of 8,058** sheets tasks; **0 of 53** sheets pipeline configs mention one |
| **Time coverage** — the numerator and denominator never coexist | Months with both payable hours and patch-based deliveries: **0** |

Patch-based is a **task variety inside the `sheets` project** (its counterpart is
"greenfield"), not a project, pipeline, or task field. There is no
`patch`/`motley` row in `tsip_projects`, and no sheets state contains "patch".

The only machine-readable marker is a legacy backfill of delivery ZIP filenames
onto *attempts*:

```
tsip_attempts.metadata -> 'tmp_deliveries'[] ->> 'tmp_delivery_batch'  ~  'patchbased'
   e.g. meridian_patchbased_450ct_06.14.26.zip
```

Note the `tmp_` prefix — explicitly temporary. It covers **3,050 distinct tasks
across 14 ZIPs, delivered to Meta 2026-02-09 → 2026-06-15**, and only for tasks
that were *delivered*, so it can never identify in-flight work. **Greenfield was
never backfilled at all** — the 572 greenfield tasks are known only from Slack
and a Google distribution list (Wylie Makovsky, 2026-08-20: the Meta list was
"3,000 patch-based + 572 greenfield").

And the timing is fatal on its own — sheets payable-hours data starts *after*
the patch-based delivery record ends:

| Month | Sheets payable h | Patch-based delivered |
|---|---|---|
| 2026-02 | 0 | 200 |
| 2026-04 | 0 | 1,000 |
| 2026-05 | 5 | 2,176 |
| 2026-06 | 58 | 817 |
| 2026-07 | **2,939** | 0 |
| 2026-08 | **3,755** | 0 |

The Feb–Jun patch-based work was paid and tracked off-platform (the ops "Patch
Based Claim Sheet"), so there is no labour ledger to divide.

## The best available figure: sheets, blended

Since patch-based can't be isolated, the honest substitute is the whole `sheets`
project. Over **2026-07-01 → 2026-08-31** (`sheets_aht_cost_per_task.sql`):

| | |
|---|---|
| **AHT** | **2.42 payable hours per task reaching `audit`** |
| **Fully-loaded cost** | **$406 per task** |
| Blended pay rate | $167.44/hr |
| Payable hours / contributors | 6,694.5 h · 172 people |
| Accrued cost | $1,120,895 |
| Rate coverage | 100% (no zero-fill exposure) |

Read this as **blended across task varieties, not as patch-based.** The $167.44/hr
independently matches the known "sheets reads ~$167/hr" figure from the
project-spend-tracker, which is good corroboration of the cost side.

### The denominator choice is load-bearing

`audit` is the right denominator because sheets ground truth makes "Tasks
Completed" = entered `audit` canonical for this project, and the platform revenue
query uses `audit` as the sheets passing state. The later states are
delivery-batch bottlenecked and measure cadence, not handling time — the same
hours divided by them give wildly different answers:

| Denominator | Tasks | AHT | $/task |
|---|---|---|---|
| **entered `audit`** (canonical) | 2,764 | **2.42 h** | **$406** |
| reached `complete` | 307 | 21.81 h | $3,651 |
| reached `delivery_holding` | 85 | 78.76 h | $13,187 |

### ⚠️ A resale that breaks naive per-task cost

The **2026-08-19 Google DeepMind batch** contains 1,900 tasks, of which **1,721
were already delivered to Meta** between Feb and Jun (earliest 2026-02-09). That
is existing patch-based inventory monetised a second time at ~zero marginal
labour. Any cost-per-delivered-task that divides a period's labour by a delivery
count including those tasks will misprice the batch badly. The 2026-08-27 Meta
draft (500 tasks) carries no prior-delivery marker and looks like new build.

## What would make a patch-based AHT possible

1. **Add a task-variety field** — a `variety`/`taskType` key on `tsip_tasks.metadata`
   at creation, or populate the already-existing `payable_time_revisions.task_type`.
   Cheapest fix by far, and it splits the denominator immediately. It is
   *forward-only*: it cannot recover Feb–Jun.
2. **Backfill the current in-flight sheets tasks** from the ops claim sheets, so
   the split starts from today's WIP rather than the next task created.
3. **Task-level time attribution** — the real unlock, and the same gap that caps
   every other AHT on the platform (see below).

---

# Appendix: the general definition, and why the existing numbers disagree

Everything below is project-agnostic and was derived first against chartography
(the only project with both a per-task rate card and enough delivered volume).
It is the method `sheets_aht_cost_per_task.sql` applies.

## The core problem: three different "hours", and the cost one wasn't being used

Ground truth (`projects/wintermelon/project.md`, "Payable hours", status ✅
agreed) names three non-interchangeable hour bases:

| Basis | Source | What it is |
|---|---|---|
| **clocked** | `timer_sessions.total_seconds` | raw timer, includes breaks/idle/off-task |
| **payable** | `payable_time_entries` + latest `payable_time_revisions` | the default basis, and **what we actually pay for** |
| mm_billed | vendor snapshots | multimango only |

**Every pre-existing AHT query in ClaudeContext uses `clocked`** — the platform
`throughput/avg_handling_time.sql`, `contributor-summary`, and the
finance-multimodal `aht_per_contributor`. Clocked runs **8–16% above payable**
(9.2% on chartography over the last 28 days), so all of them overstate cost-AHT.
Cost has to sit on payable, because payable is the basis money is booked on.

Two further problems with the clocked basis:

- `timer_sessions.active_project_id` is a self-reported "what am I working on
  now" flag. Ground truth flags it as unreliable for contributors who move
  between projects, and chartography drew people off MultiMango and Sheets.
  The payable ledger carries its own `project_id`, which is the attribution the
  money actually follows.
- Timer time carries **no task id**. Per-task hours cannot be measured, at all.
  Every AHT here is necessarily a *flow ratio* — hours in a window over tasks
  delivered in that window — not a per-task measurement.

## The definition

```
AHT = payable hours booked to the project in the window
      ÷ tasks first reaching the project's revenue-recognised state in the window
```

Fully loaded on purpose: the numerator includes training, calibration, rework
and QA time, because all of it is real project cost. Cost per task is the same
ratio with accrued dollars on top.

Cost is **accrued** (payable seconds × in-effect `contributor_rates`), not the
`contributor_earnings` ledger, because the ledger lags (p90 ≈ 21h) and makes
recent days read artificially cheap. Accrued reconciles to the ledger within
**±0.7%** on both live per-task projects, and rate coverage is **100%** (no
zero-fill exposure), so the dollar figure is solid.

## The 3.4x spread

`aht_definition_spread.sql`, chartography, lifetime:

| Definition | Hours basis | Denominator | AHT | $/task |
|---|---|---|---|---|
| **A. canonical (use this)** | payable | first arrival into delivery | **6.85** | **355** |
| B. A, acceptance-still-stands | payable | currently in delivery | 7.97 | 413 |
| C. A, but clocked hours | clocked | first arrival into delivery | 7.61 | 355 |
| D. contributor-summary style | clocked | reached `review` | 3.72 | 174 |
| E. touch-time proxy | payable | ever submitted | 2.37 | 123 |
| F. platform standard_dashboard tile | clocked | out of `edit_task`/`redo_task` | **NULL** | — |

Two things to note:

- **D and E are not wrong, they answer a different question.** E (2.37h) is a
  touch-time/capacity figure — hours per *attempt*, ignoring that a task takes
  multiple attempts and many never ship. Using it in a cost model understates
  cost per delivered task by **~2.9x**. This is the single easiest way to get a
  cost estimate badly wrong, and E-shaped numbers are what tend to get quoted.
- **F is silently broken on chartography.** The platform's own standard AHT tile
  keys on `from_state IN ('edit_task','redo_task')`. Chartography has neither
  state (it uses `annotate_chart`), so the denominator is 0 and the tile renders
  blank rather than erroring. Any project not using the edit/redo naming gets
  nothing from it.

## Don't quote a weekly figure

`aht_weekly_trend.sql` — hours land in the week worked; acceptances land whenever
review and delivery get to them. On a ramping project those are different weeks:

| Week | payable h | delivered | AHT that week | AHT cumulative |
|---|---|---|---|---|
| 2026-08-03 | 71 | 42 | 1.69 | 1.69 |
| 2026-08-10 | 481 | 79 | 6.09 | 4.56 |
| 2026-08-17 | 917 | 80 | 11.46 | 7.31 |
| 2026-08-24 | 1247 | 207 | 6.02 | 6.66 |

Weekly AHT spans 1.69–11.46 — a 6.8x swing driven by delivery batching, not by
contributors getting better or worse. **Quote the cumulative figure.** It is
converging (7.31 → 6.66) but chartography is four weeks old, so re-cut monthly;
treat 6.85 as current best estimate, not a settled constant.

## What this says about cost

At $52.54/hr blended and 6.85h per delivered task, chartography costs **~$355
per task against a $180/task bill rate** — roughly 2x underwater, needing AHT at
**3.43h** to break even. The margin conclusion is robust to definition choice:
B is worse ($413), and even the clocked variant C lands at $355.

**Caveat on the $180.** Contributor-side inputs are verified ($50/hr base pay
confirmed in `#task-court-internal` 2026-08-03 and `#ask-claude` 2026-08-17;
computed blended $52.54 is consistent). The **$180/task bill rate is not
verified** — its only source is the hardcoded `rate_card` CTE in
`dashboards/people/andres-pinedo/revenue-views-weekly`, which is itself a copy of
a hand-made Metabase card and carries unresolved TODOs. Ground truth does not
store rate cards (`platform/metrics.md` lists Labor Costs / Margin as 🟡 with
dashboard links still uncaptured). **Confirm the bill rate with Finance before
anyone acts on the margin number.** The AHT and cost-per-task figures do not
depend on it.

## Files

| File | Use |
|---|---|
| `patchbased_identifiability.sql` | **Start here for Motley.** Proves live why a patch-based AHT can't be produced, and will show it becoming producible if the gaps get fixed. |
| `sheets_aht_cost_per_task.sql` | The blended sheets figure — the best available proxy. Params `{{start_date}}`, `{{end_date}}` (both inclusive). |
| `aht_cost_per_task.sql` | The general per-project canonical figure. Params `{{project_id}}`, `{{start_date}}`, `{{end_date}}` (end exclusive). |
| `aht_definition_spread.sql` | Audit — what AHT comes out as under each definition in use. Run before quoting a number. |
| `aht_weekly_trend.sql` | Stability check + cumulative. Params `{{project_id}}`, `{{weeks_back}}`. |

All are read-only, run against `tsip_prd` (Metabase database id 2), exclude the
canonical internal/test domains, and bucket days in `America/New_York`.

## Suggested follow-ups

1. **Add a task-variety field to sheets tasks** — without it no patch-based
   figure is ever possible, and the gap silently widens every day.
2. **Promote this definition to ground truth** via `propose-ground-truth`, so the
   next cost estimate doesn't re-derive it or pick definition E by accident.
3. **Get the sheets per-task bill rate from Finance.** There is no sheets rate
   card in the revenue dashboard at all; the only figure anywhere is a `$665`
   *example* parameter in a platform scenario query. Cost per task ($406) is
   solid; margin cannot be stated without the real rate.
3. **Fix or scope the platform AHT tile** (`throughput/avg_handling_time.sql`) —
   it should either resolve each project's real submit states or state that it
   only supports edit/redo pipelines, instead of rendering blank.
4. **Task-level time attribution** is the real unlock. While timer sessions carry
   no task id, no AHT can be better than a flow ratio, and per-task cost variance
   stays invisible.
