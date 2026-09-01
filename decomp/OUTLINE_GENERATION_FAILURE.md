# Why the two looping tasks never get an outline

`4c77fbdb-8d12-4a84-b0db-a219bf7fe2a5` and `41fbe12c-7c20-463d-96e8-4ae8700d1c0d`
were bounced back to `generating_outline` twice each by leo and came back empty
both times. They are not stuck — they are being regenerated correctly, and the
generator is returning nothing each time.

## The finding

**The workbook never reaches the model.** The outline generator is a Modal-hosted
Claude workbook agent, logged in `tsip_model_run_progress` as
`job_type='modal_claude_agent'`. Every run on these two tasks:

| Task | Run at | Status | Input tokens | Output tokens |
|---|---|---|---:|---:|
| 4c77fbdb | 08-31 13:18:17 | completed | 5,383 | **4** |
| 4c77fbdb | 08-31 14:20:01 | completed | 5,375 | **7** |
| 4c77fbdb | 08-31 14:24:06 | completed | 5,381 | **1** |
| 41fbe12c | 08-31 13:48:23 | completed | 5,381 | **1** |
| 41fbe12c | 08-31 14:18:17 | completed | 5,377 | **1** |
| 41fbe12c | 08-31 14:23:58 | completed | 5,382 | **5** |

A healthy run on this project has a **median input of 185,417 tokens and 6,542
output tokens**. These six ran on ~5,380 input tokens — the bare prompt
scaffolding, with no workbook in context — and emitted one to seven tokens.

Then each run reported **`status='completed'`**, the pipeline fired
`SUBMIT_TASK_OUTLINE`, and the task advanced to `decomp_review` with no outline.
That is the whole failure: an empty run is indistinguishable from a good one
downstream.

The input-token counts are pinned in a 5,375–5,434 band across every failure on
the project. There is nothing between that band and the healthy population's
139k+ — two clean clusters, no middle.

## It is not the workbooks

Worth ruling out explicitly, because size correlates and would mislead: failing
tasks do have bigger workbooks (median 1,530 KB vs 457 KB) and denser diffs
(median 2,642 unique formulas vs 943). That correlation is real but it is **not
the cause** — the largest successful workbook (11,001 KB) is bigger than the
largest failing one (8,313 KB).

The decisive test is that **the same file succeeds on other tasks**:

| Workbook file | Task | Input tokens | Outline? |
|---|---|---:|---|
| `5ed50fbd…` | 41fbe12c (looper) | 5,381 | ✗ |
| `5ed50fbd…` | d042ba0e | 273,343 | ✓ |
| `cc30e1dc…` | 4c77fbdb (looper) | 5,383 | ✗ |
| `cc30e1dc…` | e2ff2d2f | 441,150 | ✓ |
| `cc30e1dc…` | e9bae2c6 | 139,735 | ✓ |

`41fbe12c`'s run at 13:48 loaded 5,381 tokens of that file. Three minutes later
`d042ba0e` loaded 273,343 tokens of *the same file* and produced a good outline.
Same file, same day, minutes apart. The file parses, the model works — the
attachment is being dropped on the way into the run.

`41fbe12c`'s workbook is 466 KB, **below** the median size of a successful task,
which kills the size theory on its own.

## It started on 2026-08-26 and is getting worse

Share of sheets agent runs launched with an empty context:

| Day (ET) | Runs | Empty context | % |
|---|---:|---:|---:|
| 2026-08-25 | 91 | 0 | 0.0% |
| 2026-08-26 | 149 | 7 | 4.7% |
| 2026-08-27 | 119 | 13 | 10.9% |
| 2026-08-28 | 141 | 30 | 21.3% |
| 2026-08-29 | 136 | 19 | 14.0% |
| 2026-08-30 | 196 | 36 | 18.4% |
| 2026-08-31 | 176 | 39 | 22.2% |
| 2026-09-01 | 126 | 37 | **29.4%** |

Clean on 08-25, 29% today. This tracks the missing-outline rate in
`DECOMP_REVIEW_TRIAGE.md` almost exactly, which is expected — it is the same
defect measured one step upstream. **Something shipped on 2026-08-26 that
intermittently drops the workbook attachment.** That is the thing to bisect.

## A second, smaller failure mode

Not every missing outline is the empty-context bug. Of the agent runs behind
no-outline tasks in the last 7 days:

| Mode | Runs | Tasks | Median input | Median output |
|---|---:|---:|---:|---:|
| **A — no workbook in context** | 82 | 54 | 5,388 | 4 |
| **B — workbook loaded, outline still not saved** | 7 | 7 | 693,435 | 12,762 |

Mode B is a different bug: the agent read the workbook and wrote ~12,762 tokens
of output, and the outline still did not land on the attempt. That is a
persistence or parse-of-response failure, not an input failure. It is ~12% of
the volume; worth a separate look once mode A is fixed.

Also of note, **36 agent runs are stuck in `status='running'`** with a null
`completed_at`, the oldest 152 hours (6+ days) old. All of them are in the
empty-context band. Nothing reaps them.

## What to do

1. **Bisect the 08-26 deploy** for whatever changed how the workbook file is
   attached to the `modal_claude_agent` invocation. Every artefact you need is
   in `tsip_model_run_progress`: the failing runs are exactly
   `job_type='modal_claude_agent' AND input_tokens < 10000`.
2. **Fail loudly.** A run that returns under ~50 output tokens, or that never
   writes `task_outline`, must land the task in `failed_generating_outline`
   (which exists and works — it fired 64 times in 14 days) instead of
   `SUBMIT_TASK_OUTLINE` into review. This alone stops the queue pollution
   regardless of the root cause.
3. **Reap the stuck `running` rows** — 36 of them, up to six days old.
4. **Don't re-bounce these two.** Regeneration reproduces the failure exactly;
   leo has already paid for that three times. They need the fix, then a rerun.

## Files

| File | Use |
|---|---|
| `outline_generator_failure.sql` | The daily empty-context trend, plus the same-file-succeeds-elsewhere proof to re-run on any failing task. |
