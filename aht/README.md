# A reliable AHT for cost estimation

**TL;DR** — There was no single trustworthy AHT to find. Six definitions are
already in use across our dashboards and they disagree by **3.4x** on the same
project, same window. Worse, all of them use the wrong hours basis for a cost
question. This directory defines one cost-grounded AHT, the SQL to compute it,
and an audit query to catch the wrong ones.

Headline number, chartography, launch (2026-08-03) to 2026-08-31:

| | |
|---|---|
| **AHT** | **6.85 payable hours per delivered task** |
| **Fully-loaded cost** | **$355 per delivered task** |
| Blended contributor rate | $52.54/hr |
| Breakeven AHT at the $180/task bill rate | 3.43 hours |

Verified live against `tsip_prd` on 2026-08-31.

---

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

## Scope

Only `chartography` currently supports a reliable AHT:

- **multimango** — 131,457 payable hours / 28d, but billed **hourly** ($23/hr),
  so AHT does not drive its margin; `paid_per_billed_hour` is the right metric.
- **finance-multimodal** — 676.8 payable hours / 28d but only **10 delivered
  tasks** (13 lifetime `complete`). Computes to 67.68h and $9,289/task; the
  denominator is far too thin to be meaningful. Revisit once completions
  accumulate.
- **multi-hop-reasoning** — has a $1,440/task rate card but is **dormant**: zero
  state transitions in 60 days.

## Files

| File | Use |
|---|---|
| `aht_cost_per_task.sql` | The canonical figure. Params `{{project_id}}`, `{{start_date}}`, `{{end_date}}` (end exclusive). |
| `aht_definition_spread.sql` | Audit — what AHT comes out as under each definition in use. Run before quoting a number. |
| `aht_weekly_trend.sql` | Stability check + cumulative. Params `{{project_id}}`, `{{weeks_back}}`. |

All are read-only, run against `tsip_prd` (Metabase database id 2), exclude the
canonical internal/test domains, and bucket days in `America/New_York`.

## Suggested follow-ups

1. **Confirm the $180/task bill rate with Finance** — the margin call rests on it.
2. **Promote this definition to ground truth** via `propose-ground-truth`, so the
   next cost estimate doesn't re-derive it or pick definition E by accident.
3. **Fix or scope the platform AHT tile** (`throughput/avg_handling_time.sql`) —
   it should either resolve each project's real submit states or state that it
   only supports edit/redo pipelines, instead of rendering blank.
4. **Task-level time attribution** is the real unlock. While timer sessions carry
   no task id, no AHT can be better than a flow ratio, and per-task cost variance
   stays invisible.
