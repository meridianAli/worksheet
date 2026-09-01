# What's actually in the sheets decomp review queue

Live queue re-pulled **2026-09-01 ~21:40 UTC**: **178 tasks** (the 173 from the
earlier snapshot plus an hour of inflow). Per-task verdicts:
[`decomp_review_triage.csv`](decomp_review_triage.csv).

## Two findings before the triage

### 1. Nobody is reviewing these. Three staff are hand-pushing them through.

The pipeline defines `decomp_review` with an `APPROVE` action
(→ `generating_prompt`) and a `REQUEST_CHANGES` action (→ `needs_decomp`).
Counting every transition out of the state, for the life of the project:

| Event | Count | First | Last |
|---|---:|---|---|
| `ADMIN_OVERRIDE` | 5,186 | 2026-06-08 | 2026-08-31 |
| `FIELDS_WRITE` | 4,058 | 2026-06-08 | 2026-07-16 |
| `ADMIN_EDIT_ATTEMPT` | 384 | 2026-06-09 | 2026-08-31 |
| `ADMIN_REASSIGN` | 78 | 2026-06-10 | 2026-08-27 |
| `FORCE_CLAIM` | 56 | 2026-06-13 | 2026-08-10 |
| `ADMIN_ARCHIVE` | 13 | 2026-06-11 | 2026-06-25 |
| **`APPROVE`** | **1** | 2026-06-26 | 2026-06-26 |
| `REQUEST_CHANGES` | **0** | — | — |

The state's own review actions have fired **once, ever**. The reviewer-form path
(`FIELDS_WRITE`) stopped on 2026-07-16. Since then it is 100% admin override, by
three people:

| Actor | → `generating_prompt` | → `generating_outline` | → `needs_decomp` | → cancelled |
|---|---:|---:|---:|---:|
| leo@meridian.ai | 779 | 93 | 15 | 8 |
| jeanette@meridian.ai | 202 | 0 | 0 | 0 |
| rishi@meridian.ai | 34 | 6 | 0 | 0 |

The cause is in the pipeline config: `states.decomp_review.meta.pool.enabled` is
**`false`**. The pool is switched off, so no contributor holding `can_review` can
claim one of these. The 178 tasks all have `pooled_at` set and none is assigned —
they are queued to a pool nobody can pull from. Every task that has moved in the
last ten weeks moved because a staff member clicked through the admin console.

**This is the thing to fix.** Whatever the triage below says, at current inflow
(~180/day) it is three people manually clearing a stage that was designed to be a
contributor pool.

### 2. Outline generation is failing silently, and the rate is climbing fast

`generating_outline` is supposed to write a `task_outline` field. On a growing
share of tasks it writes the workbook and the transition note and **omits the
outline**, then advances to `decomp_review` anyway — no `failed_generating_outline`,
no error. (That failure state does work: it fired 64 times in the last 14 days.
These tasks did not take it.) All 34 affected tasks in the live queue have an
uploaded workbook and a transition description. Only the outline is missing.

Share of arrivals into `decomp_review` with no outline, by ET day:

| Day | Arrivals | No outline | % |
|---|---:|---:|---:|
| 2026-08-11 → 08-19 | 353 | 0 | 0.0% |
| 2026-08-20 | 27 | 1 | 3.7% |
| 2026-08-25 | 128 | 2 | 1.6% |
| 2026-08-26 | 145 | 5 | 3.4% |
| 2026-08-27 | 125 | 13 | 10.4% |
| 2026-08-28 | 137 | 23 | 16.8% |
| 2026-08-29 | 131 | 12 | 9.2% |
| 2026-08-30 | 176 | 20 | 11.4% |
| 2026-08-31 | 177 | 24 | 13.6% |
| 2026-09-01 (partial) | 90 | 20 | **22.2%** |

Clean until 08-20, then a climb to 22% of today's arrivals. It is not simply
volume: 08-27 took *fewer* tasks than 08-26 at three times the failure rate. The
climb starts the day pipeline versions 50–53 shipped (08-26 21:56 → 08-27 20:28),
which is a lead worth checking, **not a conclusion** — task rows are migrated to
the newest version, so the version stamp on a task can't be used to attribute
this and I could not confirm it from the data.

## The triage

Bucketed on signals measured against what actually gets approved. Over the last
30 days, 2,393 reviews resolved to `generating_prompt` and 102 were bounced to
`generating_outline`; **76 of those 102 bounces (75%) had no outline**, against 14
of 2,393 approvals (0.6%). Missing outline *is* the send-back rule already in use,
so bucket A applies the rule the admins are applying by hand.

| Bucket | Tasks | What's wrong | Action |
|---|---:|---|---|
| **A1 — no outline** | **32** | Generator wrote the workbook and transition note, no outline. Nothing to review. | Send back to `generating_outline` |
| **A2 — no outline, looping** | **2** | Same, but already regenerated 3× and still empty. | Escalate to engineering — another bounce won't fix it |
| **B — thin outline** | 5 | Outline below the 1st percentile of approved decomps (2,241 chars) | Read before approving |
| **C — truncated outline** | 3 | Outline stops mid-sentence — generator cut off | Read before approving |
| **D — thin transition note** | 3 | Transition note under 18 chars (approved p01) | Read before approving |
| **E — normal** | 133 | Nothing measurable wrong | Approve-shaped |

**34 of 178 (19%) should go back.** The historical bounce rate is 3.9%
(102 of 2,643), so the queue in front of the reviewers right now is roughly five
times worse than normal — consistent with finding 2.

Worst individual cases:

- `c4ed90cb-4e82-408b-82fa-f52a782f72d3` — 46-char "outline" reading in full
  `- Input (earlier) = N-4` / `- Output (later) = N-3`. That's a version stamp,
  not a decomposition, on a task whose diff touches 2,828 unique formulas.
- `9f656c96-9ce4-44ad-b96a-18b953565b82` — 17,233 chars, ends mid-list
  (`…De Novo Total Project Cost, IY E-NCI,`). Long outlines get truncated too, so
  length alone won't catch this class.
- `4c77fbdb-8d12-4a84-b0db-a219bf7fe2a5`, `41fbe12c-7c20-463d-96e8-4ae8700d1c0d` —
  three trips through `generating_outline` → `decomp_review`, still no outline.

## What this analysis does not cover

I read the **decomposition metadata** — outline text, transition description,
formula counts, state history. I did **not** open the workbooks themselves. The
input/output XLSX pairs are in `tsip_files` and are where a substantive "is this
decomp correct?" judgement would have to come from — whether the stated outline
matches what the workbook diff actually does, whether the transition is
reversible, whether the task is the right difficulty. Nothing in the platform
scores that today:

- `tsip_check_results`, `tsip_findings`, `tsip_audits` and
  `tsip_task_claude_feedback_runs` hold **zero rows** for every task in this queue.
  No automated check runs at this stage.
- `contributor_complexity`, `computed_complexity`, `task_designation` and
  `requires_decomp` are populated on thousands of other sheets attempts but are
  **empty on all 178** of these.

So "what's wrong with them" is answerable today only at the structural level
above. Say the word and I'll pull a sample of the workbook pairs and read the
diffs directly.

## Suggested order of operations

1. **Turn the pool back on** (`states.decomp_review.meta.pool.enabled: true`) or
   decide out loud that decomp review is a staff job — three people at 180/day is
   not a plan either way.
2. **Fix the silent outline failure.** A generator run that produces no
   `task_outline` should land in `failed_generating_outline`, not
   `decomp_review`. That alone removes 19% of the current queue before a human
   sees it.
3. **Bounce the 34 in bucket A** (32 regenerate, 2 to engineering).
4. **Read the 11 in buckets B–D** before approving.
5. Then consider a real content check at this stage — there is no automated
   signal on decomp quality at all right now.

## Files

| File | Use |
|---|---|
| `decomp_review_triage.csv` | Per-task bucket, the signals behind it, and the recommended action. |
| `live_decomp_fields.csv` | Raw decomp fields per live task (outline, transition note, formula count, clone flag). |
| `live_decomp_fields.sql` | The query behind it — re-run for a current queue. |
