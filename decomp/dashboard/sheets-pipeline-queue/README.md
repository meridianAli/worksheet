# Sheets · Pipeline Queue — Metabase dashboard as code

Every non-archived `sheets` task, one dashboard tab per stage family, and on
each tab the columns that matter for that stage (outline quality in Decomp,
prompt / rubric generation state in Prompt & Rubric, SOTA prior in SOTA gate,
feedback / findings / claims in Review & Eval, audit / rewards / delivery in
Delivery & Terminal). A dashboard-level **Stage** filter narrows every tab to
one state; the Overview bar is the rebuilt "Sheets: tasks by pipeline state
(live)" card and clicking a bar sets that filter.

Mockup of the finished dashboard: `mockup.html` (open locally, or the published
artifact linked in the PR). Tabs and the Stage filter work in the mockup.

## Files

| Path | Purpose |
|---|---|
| `setup.ts` | Dashboard definition (collection, models, tabs, tiles, filters, click-through). **Skeleton** — see "Applying in ClaudeContext". |
| `models/stage_list.sql` | Populated live states with family and count; feeds the Stage dropdown. |
| `models/decomper_priors.sql` | Per-decomper too-easy rate (60 d). Standalone model, also inlined in `tab_sota` / `kpi_sota`. |
| `models/overview_by_state.sql` | Overview bar (honours Stage). |
| `models/overview_by_family.sql` | Overview bar by family. |
| `models/overview_days_in_state.sql` | Median / oldest days in current state by state. |
| `models/overview_arrivals_daily.sql` | Arrivals per ET day into decomp_review, needs_sota_eval, delivery_ready, cancelled (14 d). |
| `models/kpi_*.sql` | One single-row model per tab; each column is a KPI tile. |
| `models/tab_*.sql` | One table per tab (`decomp`, `prompt_rubric`, `sota`, `review_eval`, `calibration`, `terminal`). |
| `models/tab_terminal_cancelled_from.sql` | Bar on the terminal tab: cancelled in 30 d by previous state. |

All `tab_*` models take the same optional template tags, every one wrapped in
`[[ ]]` so an unset filter drops the clause:

```
{{stage}}        b.status = …            (Category, values from stage_list)
{{decomper}}     b.decomper_email = …    (Category)
{{entered_from}} b.entered_state_at >= … (Date)
{{entered_to}}   b.entered_state_at <= … (Date)
{{source_file}}  b.source_file ILIKE '%…%' (Text)
```

## Column sources (verified on tsip_prd, 2 Sep 2026)

- **State, entered-at, visits, last event**: `tsip_tasks.status` + `tsip_state_transitions`
  (last transition with `to_state = status`; falls back to `tsip_tasks.updated_at`
  for tasks that predate transition logging, shown with `visits = 0`).
- **Decomper**: actor (`triggered_by` → `tsip_users`) of the last `SUBMIT_DECOMP` transition.
- **Outline, transition description, unique formulas**: latest attempt whose
  metadata has `task_outline`. `uploaded_workbooks` holds only `fileId`; the
  source file name comes from `tsip_files.filename`.
- **Input / output workbook pair**: latest attempt's `messages` content items
  with `_annotations.field_id` = `input_workbook` / `output_workbook` →
  `tsip_files.size`. Over 4 MB = input + output.
- **Prompt**: `messages` content item with `field_id = 'prompt'`, its `text`.
- **Rubric**: not stored on the attempt. Presence is counted from the
  `INITIAL_RUBRIC_GENERATED` / `RUBRIC_REGENERATED` transition events; the
  eval outcome comes from `tsip_task_claude_feedback_runs`. **Open item**:
  confirm where rubric text lives (`platform/schema.md`) and add it if useful.
- **Outline agent runs**: `tsip_model_run_progress`, `job_type = 'modal_claude_agent'`;
  `input_tokens < 10000` = the agent read no workbook ("empty context").
- **Compass step errors**: `tsip_data_compass_runs` with `failed_count > 0`; the
  task id is `substring(workflow_id from 9 for 36)` (workflow ids look like
  `compass-<task uuid>-<run uuid>-child`). Templates seen for sheets:
  `system:tsip-sheets-task-outline`, `system:tsip-sheets-generate-prompt`,
  `system:tsip-sheets-initial-generate-rubric`, `system:tsip-sheets-review-gate`,
  `system:tsip-sheets-regular-task-review`.
- **SOTA bucket**: latest attempt metadata `sota_bucket` (written by the external sweep).
- **Review evidence**: `tsip_task_claude_feedback_runs` (score 1-5), `tsip_findings`
  (unresolved, by severity), attempt metadata `eval_hallucination_request`,
  `eval_hallucination_review`, `beginner_review`, `contributor_complexity`,
  `computed_complexity`, `task_designation`. Attempt metadata is merged across
  the task's attempts, latest value per key.
- **Claims**: `tsip_task_claims` with `status = 'active'`.
- **Audit / delivery / rewards**: `tsip_audits` (`audit_type = 'task_pipeline'`),
  `tsip_delivery_job_tasks`, attempt metadata `opus_max_reward`, `gemini_*_reward`,
  `number_of_opus_runs`, `workbook_diff`.
- **Calibration**: attempt metadata `contributor_complexity`, `computed_complexity`,
  `requires_decomp`, `calibration_failed_once`. `calibration_task_items` has
  **no rows for sheets** (only video-sc items exist), so `calibration_item` and
  `subject_user` are empty today; the columns are kept for when they appear.
  Calibration tasks are clones with no `uploaded_workbooks`, so `source_file`
  is empty on that tab too.

### Decomp tab rules

`outline_quality`: `no outline` · `thin` (< 3,000 chars) · `noisy` (summary
lines such as `Introduction:`, `New tab`, `Modified tabs`, `(heavy)`,
`input_workbook_url`, `Final output`) · `ok` · `running` · `not yet decomped`.

`recommended_action`: HOLD when no outline and the workbook pair is over 4 MB
or the agent has already read nothing 3+ times; REGENERATE once when no
outline and the file is small; OVERRIDE → decomp_review when a
failed_generating_outline task already has an outline; REVIEW when thin;
APPROVE (with "strip N summary lines" when noisy).

### SOTA gate prior

`decomper_too_easy_pct` = share of the decomper's SOTA-scored tasks, decomp
submitted in the last 60 days, bucketed Foundational or Intermediate. On 2 Sep
2026 this gives wangche2532 23.1 % (n = 156) and infinitearbitrage 13.2 %
(n = 151). `decomp/sota_priors.md` (earlier analysis) quoted 85.7 % / 87.5 %
on n = 28 / 16; that cohort could not be reproduced from the current data
(the Foundational counts match, the Challenging / Difficult counts do not), so
the dashboard uses the reproducible 60-day definition and states it in the
column description.

## Known limits

- Metabase returns at most 2,000 rows per table. The Delivery & Terminal tab
  holds ~6,100 live tasks (audit alone 2,171), so without a filter it shows the
  2,000 most recently entered. Use the Stage and Entered-stage filters there.
  KPI tiles are separate models and are never truncated.
- Live counts move fast (needs_sota_eval went 250 → 129 during authoring). The
  overview bar and every tab query the same base, so they agree at any instant.
- Query time on tsip_prd (2 Sep 2026): each table ≤ 4 s, KPI models ≤ 2 s.

## Applying in ClaudeContext

This folder was authored and tested outside the ClaudeContext repo (that repo
cannot be attached to this session). In a session started on
`Longitude-Labs/ClaudeContext`:

1. Read `dashboards/README.md` and `dashboards/_template/setup.ts`.
2. Copy this folder to `dashboards/people/ali/sheets-pipeline-queue/`.
3. Align `setup.ts` to the template: helper import path and signatures,
   parameter / tab / dashcard shapes, the Stage dropdown's value source
   (`stage_list`), column formatting rule shape, and the task URL route
   (`TASK_URL`). Every place that may differ is marked `ALIGN`.
4. Run the skill's ground-truth conflict check against
   `dashboards/ground-truth/sheets/` (state names, "live" = non-archived,
   decomper definition).
5. Open the PR (auto-merges), wait for `dashboards-deploy.yml`, return the
   dashboard URL.

Post-deploy checks: Stage = `decomp_review` on the Decomp tab matches the
Overview bar; clicking a bar sets the filter; a row click opens the task;
KPI tiles match the table counts on each tab.
