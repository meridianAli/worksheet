# sheets — needs_sota_eval pull

`needs_sota_eval_tasks.csv` is every `sheets` task whose current `tsip_tasks.status`
is `needs_sota_eval`, as of 2026-09-02 ~19:55 UTC (250 tasks). Produced by
`needs_sota_eval_tasks.sql` against Metabase database 2 (`tsip_prd`).

Columns: task id, task created_at, when it entered `needs_sota_eval` (latest
transition into the state), hours in state, the state/event it came from, how
many times it has entered the state, project version, pool priority, creator
and task-owner email, and clone provenance from `metadata`.

What the pull shows:

- All 250 entered via `generating_rubric → needs_sota_eval` on event
  `INITIAL_RUBRIC_GENERATED`, each for the first time, all on project version 53.
- Creator is `system@tsip.ai` on every row; no task owner or assignee.
- 65 were cloned from `sheets-artifact-collection`; 185 have no clone metadata.
- Arrivals are two batches: 132 on 2026-09-01 23:29–00:22 UTC and 118 on
  2026-09-02 18:12–18:49 UTC.
- Historically the state exits to `initial_task_review` (2,144), `cancelled`
  (639), `edit_task` (468) and `needs_decomp` (3); 2,910 self-loops.

`needs_sota_eval` is not yet defined in the sheets ground truth
(`projects/sheets/project.md`, last verified 2026-07-22, predates the state).
