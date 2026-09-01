# Why an outline run comes back empty — every hypothesis, tested

The defect: the outline agent is invoked with ~5,380 input tokens instead of the
healthy ~185,000, emits 1–7 output tokens, reports `status='completed'`, and the
pipeline advances the task into `decomp_review` with no outline.

Below is every explanation worth considering, with what the data says. Runs are
sheets `modal_claude_agent` runs, last 10 days, ~1,134 with token counts. An
"empty-context run" is `input_tokens < 10000` — the two populations are ~5.4k and
139k+, with nothing in between.

## Ruled out

| # | Hypothesis | Test | Verdict |
|---|---|---|---|
| 1 | Input and output workbooks are the same, so there is no diff to describe | 0 of 1,602 tasks share a file id or content hash; size ratio 1.07 failing vs 1.12 succeeding | **No** |
| 2 | The workbook is corrupt or unparseable | Both looper files load in openpyxl in 0.3 s, 20 sheets each | **No** |
| 3 | Cloned tasks lose their file wiring | Clones fail *less*: 2.3% (12/520) vs 3.4% (26/761) | **No** |
| 4 | The model or gateway returned an error | `error` is null on every run; all report `completed` | **No error is recorded** — see gap A |
| 5 | The file blob is missing | 0 failing tasks have a null `blob_path` | **No** |
| 6 | A global outage or bad deploy window | 25 separate minutes contain both a success and a failure | **No** — it is per-run, not per-window |
| 7 | Bad decomp content upstream | The looper's pair is a correct decomp: 2,831 formulas in, 12,904 out, matching the transition note | **No** |

## Supported by the data

| # | Hypothesis | Evidence |
|---|---|---|
| 8 | **Payload size** | Failure rate by combined input+output workbook size: 0.5% (<0.5 MB) → 1.7% (1–2 MB) → 6.9% (2–4 MB) → 11.7% (4–8 MB) → 13.7% (8 MB+) |
| 9 | **Concurrency** | Median 6 runs in flight when a run fails vs 4 when it succeeds (mean 11.9 vs 8.2) |
| 10 | **Size × load together** | The strongest result in this whole investigation — see below |
| 11 | **Something changed 2026-08-26** | Holding size fixed: 4 MB+ tasks were **0.0% (0 of 42)** before 08-26 and **20.3% (14 of 69)** after |

### The interaction is the finding

| | Quiet (<5 in flight) | Busy (5+ in flight) |
|---|---:|---:|
| Small (<1 MB) | 9.3% | 13.2% |
| Mid (1–4 MB) | 12.1% | 23.5% |
| **Big (4 MB+)** | **16.4%** | **38.3%** |

Both factors raise the failure rate independently and compound: 9.3% → 38.3%, a
4× spread. Big payload plus contention is a **resource-exhaustion signature** —
a memory ceiling or a timeout in the step that fetches, converts and attaches the
workbook, not a logic bug. It also explains the retry behaviour: a task near the
threshold flips on a re-run (most do recover), while one well past it fails every
time — `41fbe12c` failed 3 for 3.

Combine with #11: something on 08-26 reduced the headroom. Either the limit got
tighter, the conversion got heavier, or concurrency went up.

## Untestable from here — needs the worker code or better telemetry

| # | Hypothesis | Why it is plausible | What to check |
|---|---|---|---|
| 12 | A size or token guard silently skips the attachment | Would produce exactly the flat ~5,380-token signature | grep the attachment path in `Longitude-Labs/prime` for a size/token cap |
| 13 | Modal container OOM or timeout during workbook conversion | Fits the size × load interaction better than anything else | Modal container logs, memory limits, per-run wall time |
| 14 | `definedNames` bloat inflates the serialised payload | The one pair examined is 46% defined-name junk — 1.13 MB, larger than all 20 sheets combined, ~288k tokens per file, and **provably inert** (0 of 14,106 referenced by any formula) | Count `definedNames` across a sample of failing vs succeeding pairs — measured on one pair only |
| 15 | A retry reuses a cached, already-broken attachment | The same `attempt_id` is reused across all three regenerations of each looper | Whether the attachment is rebuilt per run |

## Gaps that made this harder than it should have been

- **Gap A — no error telemetry.** `tsip_ai_spend_events` has **zero rows for the
  last 10 days**, so gateway status codes, provider errors and cost are all
  invisible. A 400 (payload too large) or 429 would have answered this in one
  query. Whatever populates that table is not running.
- **Gap B — success is not validated.** A run that returns 4 output tokens is
  recorded `completed` and advances the task. Nothing compares output to
  expectations.
- **Gap C — 36 runs stuck in `running`** with a null `completed_at`, the oldest
  152 hours. Nothing reaps them.

## Recommended order

1. **Validate the run, not just its exit status.** Under ~50 output tokens, or no
   `task_outline` written → `failed_generating_outline`. Removes the queue
   pollution whatever the cause, and is independent of everything below.
2. **Look for the ceiling.** Modal memory/timeout on the workbook conversion step,
   and any size guard on the attachment. The size × load table says this is where
   it is.
3. **Fix the telemetry** (`tsip_ai_spend_events`). Without status codes this is
   guesswork.
4. **Strip `definedNames` before serialising.** Free 46% payload reduction on the
   one file measured, provably safe there. Verify on a sample first.
5. **Bisect 08-26** for what reduced the headroom.
