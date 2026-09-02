/**
 * Sheets · Pipeline Queue — dashboards-as-code definition.
 *
 * Target location in Longitude-Labs/ClaudeContext:
 *   dashboards/people/ali/sheets-pipeline-queue/setup.ts   (+ models/*.sql)
 *
 * STATUS: skeleton authored outside ClaudeContext. The SQL in models/ is tested
 * against tsip_prd (Metabase db 2). The helper calls below follow the
 * tsip-platform:dashboard skill (ensureManagedCollection, nativeModel,
 * nativeCard, dashcards with click_behavior) but MUST be aligned to
 * dashboards/_template/setup.ts and dashboards/README.md in a session that
 * has the ClaudeContext repo checked out. Anything marked ALIGN is a place
 * where the template's exact signature or option name may differ.
 */

// ALIGN: import path / names from dashboards/_template/setup.ts
import {
  ensureManagedCollection,
  nativeModel,
  nativeCard,
  upsertDashboard,
} from '../../../_lib/metabase';

// ---------------------------------------------------------------------------
// Collection constants (skill step 4)
// ---------------------------------------------------------------------------
const AREA = 'personal' as const;
const PERSON = 'ali';                    // ali@meridian.ai → local-part slug
const PROJECT = 'sheets';                // informational for personal dashboards
const DASHBOARD_NAME = 'Sheets · Pipeline Queue';
const DATABASE_ID = 2;                   // tsip_prd

// Task link. ALIGN: confirm the route from dashboards/README.md or an existing
// ground-truth dashboard (e.g. https://app.tsip.ai/tasks/{{task_id}}).
const TASK_URL = 'https://app.tsip.ai/tasks/{{task_id}}';

// ---------------------------------------------------------------------------
// Dashboard filters (one parameter each; every table and bar maps to them)
// ---------------------------------------------------------------------------
// Template tags used in the SQL: {{stage}}, {{decomper}}, {{entered_from}},
// {{entered_to}}, {{source_file}}. All are wrapped in [[ ]] so they are optional.
const PARAMETERS = [
  { id: 'stage',        name: 'Stage',         slug: 'stage',        type: 'string/=',  sectionId: 'string' },
  { id: 'decomper',     name: 'Decomper',      slug: 'decomper',     type: 'string/=',  sectionId: 'string' },
  { id: 'entered_from', name: 'Entered from',  slug: 'entered_from', type: 'date/single', sectionId: 'date' },
  { id: 'entered_to',   name: 'Entered to',    slug: 'entered_to',   type: 'date/single', sectionId: 'date' },
  { id: 'source_file',  name: 'Source file',   slug: 'source_file',  type: 'string/contains', sectionId: 'string' },
] as const;

// The Stage dropdown's value list should come from models/stage_list.sql
// (populated states only). ALIGN: `values_source_type: 'card'` +
// `values_source_config: { card_id: <stage_list card id>, value_field: status }`.

// Maps every template tag of a native card to the dashboard parameter of the
// same name. Cards that do not declare a tag simply get fewer mappings.
function mappingsFor(cardId: number, tags: string[]) {
  return tags.map((tag) => ({
    parameter_id: tag,
    card_id: cardId,
    target: ['variable', ['template-tag', tag]],
  }));
}
const TABLE_TAGS = ['stage', 'decomper', 'entered_from', 'entered_to', 'source_file'];

// ---------------------------------------------------------------------------
// Families / tabs
// ---------------------------------------------------------------------------
type Family = {
  tab: string;          // tab title
  key: string;          // model suffix: tab_<key>.sql, kpi_<key>.sql
  states: string[];     // pipeline states shown on this tab
  kpis: { col: string; label: string }[];       // columns of kpi_<key>.sql → scalar tiles
  columns: string[];    // display order for the table (left → right)
  redStates?: boolean;  // colour failed_* states red (all tabs)
  extraBar?: { model: string; title: string };  // optional extra chart on the tab
};

const FAMILIES: Family[] = [
  {
    tab: 'Decomp', key: 'decomp',
    states: ['needs_decomp','decomp_complexity_check','generating_outline','failed_generating_outline','decomp_review'],
    kpis: [
      { col: 'in_family', label: 'In family' },
      { col: 'no_outline', label: 'No outline' },
      { col: 'empty_context_runs_today_pct', label: 'Empty-context runs today %' },
      { col: 'workbooks_over_4mb', label: 'Workbooks over 4 MB' },
      { col: 'waiting_over_2_days', label: 'Waiting > 2 days' },
    ],
    columns: [
      'task','status','days_in_state','visits','decomper_email','unique_formulas',
      'outline_quality','recommended_action',
      'has_outline','outline_chars','bullets','summary_bullets','transition_chars',
      'empty_context_runs','agent_runs','last_run_in_tokens','last_run_out_tokens','last_run_status',
      'last_compass_step','last_compass_error','over_4mb','input_kb','output_kb','identical_pair',
      'outline_generations','admin_overrides','claim_holder','claimed_at','expires_at',
      'source_file','clone_of','task_created_at','last_event','last_event_by','last_event_at','entered_state_at','task_id',
    ],
  },
  {
    tab: 'Prompt & Rubric', key: 'prompt_rubric',
    states: ['generating_prompt','failed_generating_prompt','generating_rubric','failed_generating_rubric','regenerating_rubric'],
    kpis: [
      { col: 'in_family', label: 'In family' },
      { col: 'failed_prompt', label: 'Failed prompt' },
      { col: 'failed_rubric', label: 'Failed rubric' },
      { col: 'regen_loops_2_plus', label: 'Regen loops ≥ 2' },
      { col: 'median_minutes_in_state', label: 'Median minutes in state' },
    ],
    columns: [
      'task','status','minutes_in_state','visits','decomper_email',
      'prompt_present','prompt_chars','prompt_tries','rubric_generations','regen_loops','generation_failures',
      'last_feedback_score','last_feedback_status','last_feedback_at','feedback_runs',
      'last_compass_step','last_compass_action','last_compass_error','last_compass_error_at','retries_by_override',
      'outline_chars','unique_formulas','input_kb','output_kb','source_file','clone_of',
      'task_created_at','last_event','last_event_by','last_event_at','days_in_state','entered_state_at','task_id',
    ],
  },
  {
    tab: 'SOTA gate', key: 'sota',
    states: ['needs_sota_eval'],
    kpis: [
      { col: 'waiting_on_sota', label: 'Waiting on SOTA' },
      { col: 'scored_not_released', label: 'Scored, not released' },
      { col: 'expected_too_easy_pct', label: 'Expected too-easy %' },
      { col: 'median_wait_days', label: 'Median wait (days)' },
      { col: 'oldest_wait_days', label: 'Oldest wait (days)' },
    ],
    columns: [
      'task','status','days_waiting','visits','decomper_email',
      'sota_bucket','decomper_too_easy_pct','decomper_scored_n','predicted_release',
      'prompt_chars','outline_chars','bullets','unique_formulas','formulas_band','outline_band',
      'siblings_scored','siblings_too_easy','source_file','input_kb','output_kb','clone_of',
      'task_created_at','last_event','last_event_by','last_event_at','entered_state_at','task_id',
    ],
  },
  {
    tab: 'Review & Eval', key: 'review_eval',
    states: ['review_gate','failed_review_gate','rubric_eval','initial_rubric_eval','failed_rubric_eval',
             'failed_initial_rubric_eval','task_review','initial_task_review','failed_task_review',
             'failed_initial_task_review','beginner_task_review','review_eval_hallucination','redo_task','edit_task','one_off_edit'],
    kpis: [
      { col: 'in_family', label: 'In family' },
      { col: 'in_failed_review_state', label: 'failed_* review states' },
      { col: 'redo_task', label: 'redo_task' },
      { col: 'hallucination_queue', label: 'Hallucination queue' },
      { col: 'active_claims', label: 'Active claims' },
      { col: 'median_feedback_score', label: 'Median feedback score' },
    ],
    columns: [
      'task','status','days_in_state','visits','decomper_email',
      'sota_bucket','contributor_complexity','computed_complexity','task_designation',
      'last_feedback_score','last_feedback_status','last_feedback_at','feedback_runs',
      'open_major_findings','open_minor_findings','resolved_findings',
      'halluc_request_present','halluc_review_present','beginner_review_present','workbook_diff_present',
      'redo_count','review_loops','admin_overrides',
      'claim_holder','claimed_at','expires_at','assigned_to','pooled_at','timeout_at',
      'source_file','source_kb','unique_formulas','outline_chars','clone_of',
      'task_created_at','last_event','came_from','last_event_by','last_event_at','entered_state_at','task_id',
    ],
  },
  {
    tab: 'Calibration', key: 'calibration',
    states: ['calibration_available','calibration_grading','calibration_graded','calibration_manual_review'],
    kpis: [
      { col: 'in_family', label: 'In family' },
      { col: 'graded', label: 'Graded' },
      { col: 'failed_once', label: 'Failed once' },
      { col: 'manual_review', label: 'Manual review' },
      { col: 'available_to_claim', label: 'Available to claim' },
    ],
    columns: [
      'task','status','days_in_state','visits',
      'contributor_complexity','computed_complexity','requires_decomp','calibration_failed_once',
      'audit_status','audit_score','audit_purpose','graded_at',
      'claim_holder','claimed_at','expires_at','assigned_to','subject_user','calibration_item',
      'clone_of','source_file','unique_formulas','task_created_at','last_event','last_event_by','last_event_at','entered_state_at','task_id',
    ],
  },
  {
    tab: 'Delivery & Terminal', key: 'terminal',
    states: ['audit','delivery_holding','delivery_ready','complete','cancelled'],
    kpis: [
      { col: 'in_audit', label: 'audit' },
      { col: 'delivery_holding', label: 'delivery_holding' },
      { col: 'delivery_ready', label: 'delivery_ready' },
      { col: 'complete', label: 'complete' },
      { col: 'cancelled_30d', label: 'Cancelled (30 d)' },
      { col: 'cancelled_from_sota_30d', label: 'Cancelled from SOTA (30 d)' },
      { col: 'median_audit_score_30d', label: 'Median audit score (30 d)' },
    ],
    columns: [
      'task','status','days_since','decomper_email',
      'sota_bucket','audit_status','audit_score','auditor','audit_submitted_at','audit_purpose',
      'open_major_findings','open_minor_findings','last_feedback_score','last_feedback_status',
      'opus_max_reward','gemini_avg_reward','gemini_max_reward','opus_runs','workbook_diff_present',
      'delivery_jobs','delivery_status','task_status_at_delivery','delivered_at',
      'cancelled_from','cancelled_by','claim_holder','claim_expires_at',
      'contributor_complexity','computed_complexity','task_designation',
      'source_file','unique_formulas','clone_of','task_created_at','last_event','last_event_by','last_event_at','entered_state_at','visits','task_id',
    ],
    extraBar: { model: 'tab_terminal_cancelled_from', title: 'Cancelled by previous state (last 30 days)' },
  },
];

// Colour rules applied through visualization_settings.table.column_formatting
// (ALIGN: exact shape of Metabase column formatting rules in the template).
const FORMATTING = {
  redFailedState:   { columns: ['status'], operator: 'starts-with', value: 'failed_', color: '#C23B3B' },
  quality: [
    { columns: ['outline_quality'], operator: '=', value: 'no outline', color: '#C23B3B' },
    { columns: ['outline_quality'], operator: '=', value: 'thin',       color: '#B37A00' },
    { columns: ['outline_quality'], operator: '=', value: 'noisy',      color: '#B37A00' },
    { columns: ['outline_quality'], operator: '=', value: 'ok',         color: '#2E7D4F' },
  ],
  sota: [
    { columns: ['sota_bucket'], operator: '=', value: 'Foundational', color: '#C23B3B' },
    { columns: ['sota_bucket'], operator: '=', value: 'Intermediate', color: '#B37A00' },
    { columns: ['sota_bucket'], operator: '=', value: 'Challenging',  color: '#2E7D4F' },
    { columns: ['sota_bucket'], operator: '=', value: 'Difficult',    color: '#2E7D4F' },
  ],
  scores: [
    { columns: ['last_feedback_score'], operator: '<', value: 2.5, color: '#C23B3B' },
    { columns: ['audit_score'],         operator: '<', value: 3,   color: '#C23B3B' },
    { columns: ['decomper_too_easy_pct'], operator: '>=', value: 50, color: '#C23B3B' },
  ],
  days: [
    { columns: ['days_in_state','days_waiting'], operator: '>', value: 5, color: '#C23B3B' },
    { columns: ['days_in_state','days_waiting'], operator: '>', value: 2, color: '#B37A00' },
  ],
  overSize: { columns: ['over_4mb'], operator: '=', value: true, color: '#C23B3B' },
};

async function main() {
  const collection = await ensureManagedCollection({ area: AREA, person: PERSON, project: PROJECT, name: DASHBOARD_NAME });

  // ---- models -------------------------------------------------------------
  const model = async (name: string) =>
    nativeModel({ collection, database: DATABASE_ID, name, sqlFile: `${__dirname}/models/${name}.sql` });

  const stageList      = await model('stage_list');
  const decomperPriors = await model('decomper_priors');
  const byState        = await model('overview_by_state');
  const byFamily       = await model('overview_by_family');
  const daysInState    = await model('overview_days_in_state');
  const arrivals       = await model('overview_arrivals_daily');
  const kpiOverview    = await model('kpi_overview');

  // ---- tabs & dashcards ------------------------------------------------------
  const tabs: { id: number; name: string }[] = [];
  const dashcards: any[] = [];
  let tabId = 1;
  let cardRow = 0;

  // Tab 1 · Overview
  tabs.push({ id: tabId, name: 'Overview' });
  {
    const kpiCols = ['live_tasks','in_pipeline','blocked_in_failed_state','waiting_on_sota','entered_stage_today_et'];
    kpiCols.forEach((col, i) => dashcards.push({
      dashboard_tab_id: tabId, row: 0, col: i * 4, size_x: 4, size_y: 3,
      card_id: kpiOverview.id,
      visualization_settings: {
        'scalar.field': col,
        // KPIs open the state bar below (crossfilter-free) — ALIGN: linkType 'question'
        click_behavior: { type: 'link', linkType: 'question', targetId: byState.id },
      },
      parameter_mappings: [],
    }));
    dashcards.push({
      dashboard_tab_id: tabId, row: 3, col: 0, size_x: 12, size_y: 12,
      card_id: byState.id,
      visualization_settings: {
        'graph.dimensions': ['status'], 'graph.metrics': ['live_tasks'],
        'graph.colors_by': 'family',            // ALIGN: series colouring option
        // Clicking a bar sets the Stage filter → every tab's table follows.
        click_behavior: {
          type: 'crossfilter',
          parameterMapping: { stage: { id: 'stage', source: { type: 'column', id: 'status', name: 'status' }, target: { type: 'parameter', id: 'stage' } } },
        },
      },
      parameter_mappings: mappingsFor(byState.id, ['stage']),
    });
    dashcards.push({
      dashboard_tab_id: tabId, row: 3, col: 12, size_x: 12, size_y: 6, card_id: byFamily.id,
      visualization_settings: { 'graph.dimensions': ['family'], 'graph.metrics': ['live_tasks'],
        click_behavior: { type: 'link', linkType: 'question', targetId: byState.id } },
      parameter_mappings: [],
    });
    dashcards.push({
      dashboard_tab_id: tabId, row: 9, col: 12, size_x: 12, size_y: 6, card_id: daysInState.id,
      visualization_settings: { 'graph.dimensions': ['status'], 'graph.metrics': ['median_days_in_state'],
        click_behavior: { type: 'crossfilter',
          parameterMapping: { stage: { id: 'stage', source: { type: 'column', id: 'status', name: 'status' }, target: { type: 'parameter', id: 'stage' } } } } },
      parameter_mappings: [],
    });
    dashcards.push({
      dashboard_tab_id: tabId, row: 15, col: 0, size_x: 24, size_y: 6, card_id: arrivals.id,
      visualization_settings: { 'graph.dimensions': ['day_et'],
        'graph.metrics': ['into_decomp_review','into_needs_sota_eval','into_delivery_ready','into_cancelled'],
        click_behavior: { type: 'link', linkType: 'question', targetId: arrivals.id } },
      parameter_mappings: [],
    });
  }

  // Tabs 2-7 · one per family
  for (const fam of FAMILIES) {
    tabId += 1;
    tabs.push({ id: tabId, name: fam.tab });
    const table = await model(`tab_${fam.key}`);
    const kpi   = await model(`kpi_${fam.key}`);
    const tileW = Math.floor(24 / fam.kpis.length);

    fam.kpis.forEach((k, i) => dashcards.push({
      dashboard_tab_id: tabId, row: 0, col: i * tileW, size_x: tileW, size_y: 3, card_id: kpi.id,
      visualization_settings: {
        'scalar.field': k.col, 'card.title': k.label,
        // KPI → the table below on the same tab (its Stage filter narrows it).
        click_behavior: { type: 'link', linkType: 'question', targetId: table.id },
      },
      parameter_mappings: [],
    }));

    let row = 3;
    if (fam.extraBar) {
      const bar = await model(fam.extraBar.model);
      dashcards.push({
        dashboard_tab_id: tabId, row, col: 0, size_x: 24, size_y: 5, card_id: bar.id,
        visualization_settings: { 'card.title': fam.extraBar.title,
          'graph.dimensions': ['cancelled_from'], 'graph.metrics': ['cancelled_30d'],
          click_behavior: { type: 'link', linkType: 'question', targetId: table.id } },
        parameter_mappings: [],
      });
      row += 5;
    }

    dashcards.push({
      dashboard_tab_id: tabId, row, col: 0, size_x: 24, size_y: 14, card_id: table.id,
      visualization_settings: {
        'card.title': `${fam.tab} queue`,
        'table.columns': fam.columns.map((name) => ({ name, enabled: true })),
        'table.column_formatting': [
          FORMATTING.redFailedState, ...FORMATTING.quality, ...FORMATTING.sota, ...FORMATTING.scores, ...FORMATTING.days, FORMATTING.overSize,
        ],
        // Row click → the task in the app.
        click_behavior: { type: 'link', linkType: 'url', linkTemplate: TASK_URL },
      },
      parameter_mappings: mappingsFor(table.id, TABLE_TAGS),
    });
  }

  await upsertDashboard({
    collection,
    name: DASHBOARD_NAME,
    description: 'Every non-archived sheets task, one tab per stage family, columns chosen for that stage. Filters: Stage, Decomper, Entered stage, Source file.',
    parameters: PARAMETERS.map((p) => ({ ...p })),
    tabs,
    dashcards,
    // ALIGN: Stage dropdown values from stageList (values_source_type 'card').
    stageValuesCardId: stageList.id,
    _unused: [decomperPriors.id],   // exposed as a model for ad-hoc use; not a tile
  });
}

main().catch((e) => { console.error(e); process.exit(1); });
