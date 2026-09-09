# Audio task linter

A programmatic QC suite for the **multimodal audio finance tasks** (MD/VP client-debrief → completed workbook).
Point it at an exported task bundle and it checks the rubric, the gold workbook, the input workbook, the script
and the recording against the rules we already apply by hand in review (delivery checks, the Audio Deliverable
Reviewer Rubric, the `tsip-task-qc` skill, and the cross-cutting findings from the September audio-task sweep).

```
pip install -r requirements.txt            # openpyxl; optional: formulas, mutagen
python -m audio_task_linter lint <task_dir> [<task_dir> ...]   # text report, exit 1 on any error
python -m audio_task_linter lint <task_dir> --json             # machine-readable
python -m audio_task_linter lint tasks/* --summary             # one line per task
python -m audio_task_linter rules                              # rule catalog
python -m audio_task_linter ai-prompts <task_dir>              # LLM prompt for the non-deterministic rules
```

A task directory is whatever the export-center zip unpacks to. Files are classified by name
(`*input*`, `*gold*`/`*output*`, `*rubric*`, `*script*`/`*prompt*`/`*transcript*`, `*Solved*`, `*self-grade*`,
audio by extension); override with `--rubric`, `--gold`, `--input`, `--script` when the names are unhelpful.
Rubrics may be markdown / plain text (`Section` header, one `- Question? +N` per line) or JSON.

Perturbation checks (`P001`/`P002`) edit a copy of the gold and recalculate it. LibreOffice Calc is used when
`soffice` is on PATH (`apt-get install libreoffice-calc`, about 1 s per perturbation); otherwise the pure-Python
`formulas` package is used; with neither installed those rules are skipped and say so. A gold saved by a
library rather than Excel has no cached values; the linter recalculates it first and notes that it did.

## What the linter is for

Three tiers, by how the check runs:

1. **Deterministic** — pure code over the files. These run every time and gate delivery.
2. **AI-lint** — needs a language model reading the script against the rubric/gold (anchoring, coverage,
   fidelity, PII). The linter emits a ready-to-run prompt with the task's own text inlined (`ai-prompts`);
   wiring that to an LLM call is the next step.
3. **Manual** — a human must listen (AI-voice check). The linter lists these as reminders.

Severity: `error` blocks (exit code 1), `warning` needs a reviewer decision, `info` is context.

## Rule catalog

| Severity | Mode | Check | What it catches |
|---|---|---|---|
| error | deterministic | All 5 bundle pieces present | Input workbook, gold workbook, rubric, script and audio recording are all present. |
| error | deterministic | Input workbook differs from gold | Gold must differ from the input (hash + cell diff); a byte-identical pair means the wrong file shipped. |
| error | deterministic | Audio is a real, decodable recording | Supported extension, non-trivial size, and (when mutagen is installed) a decodable duration. |
| error | deterministic | No cell/row/column refs in criteria | Criteria must key on tab + row label + column header, never on A1 coordinates (D42, cell Y26, row 12, column F). The solver's layout is not the gold's. |
| error | deterministic | Every criterion ends in a question mark | The judge answers each criterion Yes/No; a trailing qualifying statement is not gradable. |
| error | deterministic | Every criterion has points | Rubric gen or a contributor edit sometimes drops the points. |
| error | deterministic | Pitfalls negative, others positive, none zero | Pitfalls are negative; Output Validation / Perturbation / Presentation / Model Integration are positive. |
| warning | deterministic | Points within 1-10 (pitfalls -1 to -10) | |points| between 1 and 10 for every section; pitfalls carry the negative sign. |
| error | deterministic | All 4 sections present and non-empty | Output Validation, Perturbation, Presentation and Pitfalls each have at least one criterion; no declared section is empty. |
| warning | deterministic | Enough criteria (10 total, 5 OV, 3 perturbation) | At least 10 criteria in total; Output Validation and Perturbation carry the bulk. |
| error | deterministic | No duplicate criteria | Same text twice (after whitespace/case normalisation) double-counts points. |
| error | deterministic | Perturbations are 'from A to B, does Y hit Z' | 'If <input> on <tab> is changed from A to B, does <output> update to Z (±tol)?' with a numeric from, to and target. |
| warning | deterministic | Exactly one tolerance per numeric target | Every value check states a tolerance (±2% numbers, ±0.05 multiples, ±0.5pp percentages); stating it twice widens the band. |
| warning | deterministic | One expected value per criterion (no stacking) | Several independent expected values in one question zero multiple points on one miss (allowed in Presentation and Pitfalls). |
| warning | deterministic | No vague words without a tab/line anchor | 'correct', 'consistent', 'appropriate', 'properly' without a tab / line-item anchor is not gradable. |
| warning | deterministic | No relative tolerance on a zero target | 'within ±2% of 0' is a zero-width band; use an absolute tolerance. |
| warning | deterministic | No Excel function names in criteria | Criteria grade results, not the construction (SUMIFS vs SUMPRODUCT). |
| warning | deterministic | Pitfalls include the error-value scan | Pitfalls should include the standard #REF!/#DIV/0!/#VALUE! scan. |
| error | deterministic | Script exists and is substantive | The script is the primary carrier of instructions; it must exist and be more than a one-liner. |
| warning | deterministic | Script gives no cell coordinates | More than a few exact row/column references turn the debrief into a read-out of cell edits. |
| warning | deterministic | Script names no Excel functions | An MD says 'look it up off the curve', not 'use an XLOOKUP'. |
| warning | deterministic | Graded tabs exist and were known to the analyst | A tab the rubric grades on must exist in the gold, and must be in the input workbook or named in the script; otherwise the criterion anchors on a layout nobody was told. |
| warning | deterministic | Script's headline instructions have a criterion | If the script insists on formulas-not-hardcodes, a circ switch, a check row, cases flexing off Base, etc., at least one criterion should test it. |
| warning | deterministic | Script doesn't say the target values aloud | Output-validation target values should not be spoken in the script (the analyst would then be transcribing, not modelling). |
| warning | ai-lint | AI: every criterion inferable from the script | LLM pass: classify every criterion Explicit / Inferrable / Anchored against the script + input; Anchored criteria are unfair. |
| warning | ai-lint | AI: script and gold agree both ways | LLM pass: every instruction maps to a change in the gold and every gold change traces back to the script. |
| warning | ai-lint | AI: every deliverable in the script is tested | LLM pass: list the deliverables the script asks for and report which have no criterion. |
| error | ai-lint | AI: no PII or private company names | LLM pass over script, rubric and workbook text for real private companies or people. |
| error | deterministic | Gold has no #REF!/#DIV/0!/#VALUE! cells | #REF!, #DIV/0!, #VALUE!, #N/A, #NAME?, #NUM! in any cell (defined-name errors excluded). |
| error | deterministic | Gold has no links to other workbooks | Links to other files break when the workbook ships alone. |
| warning | deterministic | Gold has no hidden sheets or comments | Hidden sheets and cell comments leak authoring notes or hide answer machinery. |
| warning | deterministic | Gold's new cells are formulas, not typed | Cells that are new or changed vs the input should mostly be formulas; a high hardcode share means the build is typed in. |
| error | deterministic | Every OV target found in gold on a formula cell | Each numeric target must be found (within its tolerance, any display-unit scaling) in a gold cell that is a formula. |
| warning | deterministic | OV target isn't a typed value or in 3+ cells | Target found only in literal cells, or in 3+ cells, means the rubric grades an input or a pasted value. |
| error | deterministic | Perturbation 'from' value exists as an input in gold | The 'from' value must sit in a literal (input) cell on the named tab whose row label matches the criterion. |
| error | deterministic | Perturbation recalculated on gold hits target | Apply the change to a copy of the gold, recalculate with LibreOffice, and confirm the named output lands on the target within tolerance. |
| warning | deterministic | Perturbation actually moves the output | If the output is unchanged by the perturbation the criterion is non-discriminating (the gold itself would pass it hardcoded). |
| error | deterministic | No rubric target typed into the input | An output-validation or perturbation target sitting as a literal in the input is an answer hint. |
| error | deterministic | No input hardcode equal to a gold formula result | Cells that are literals in the input but formulas in the gold, with equal values, are hardcoded dependencies of the unbuilt work. |
| warning | deterministic | Input lacks tabs the script asks to build | Tabs the script asks the analyst to build (Transaction, Output, Returns, Debt schedule, ...) must not already exist in the input. |
| error | deterministic | Constants inside formulas are spoken or in input | A numeric constant typed into a formula (=F5*8.5, =B4+0.05) must be spoken in the script or already present as a value in the input workbook; otherwise it is an untraceable assumption. Constants that do exist as an assumption cell should be linked, not retyped. |
| error | deterministic | No vendor formulas, #REF! names, or images | Ported from the sheets delivery scanner: Bloomberg/CapIQ/FactSet/RTD calls cannot evaluate off-terminal; #REF! inside formulas and defined names are dead links; embedded images are usually screenshots of source data. |
| warning | deterministic | No emails, phones or company names in text | Emails, phone numbers, and company-like names (Acme Holdings LLC) in cells, tab names, script or rubric. Scrubbed placeholders (Meridian, Project <codename>) are allowed. Author names in document properties are not checked. |
| error | deterministic | Script isn't a duplicate of another task's | The script/prompt must not repeat another task's (exact or near-duplicate) within the same lint run or a supplied known-prompts file. |
| error | deterministic | Scanner: no external links, broken refs, #NAME? | From the platform scanner output for input and gold workbooks. |
| warning | deterministic | Scanner: no hidden sheets, comments, images, dead names | From the platform scanner output; broken named ranges are dead definitions left over from a decomposition. |
| warning | deterministic | Scanner: gold hardcode ratio under 60% | A high hardcode ratio in the GOLD means a typed-in build (input ratio reported as info). |

## Design notes on the checks that matter most

- **Cell references (R001).** Coordinate anchoring was the #1 cross-cutting defect in the last audio sweep
  (7 of 10 tasks). The regex catches `D42`, `$AB$5`, `Y26:Z30`, `cell D42`, `row 12`, `column F`, while
  letting `Q3 2023`, `FY25`, `H1`, `#EB8521` through. Criteria should key on tab + row label + column header.
- **Gold must score 100% (G005/G006/G007/P001).** Every Output Validation target is located in the gold within
  its tolerance, allowing for display-unit scaling ($ vs $000s vs $mm, 10.8% vs 0.108). It must land on a
  formula cell, not a literal, in the column whose header carries the year the criterion names. Perturbations
  are actually applied: the input cell is found by value + row label, changed, the book recalculated, and the
  named output checked against the target. `P002` flags a perturbation whose output does not move at all
  (the non-discriminating criteria pattern).
- **Hidden hardcodes in formulas (G008).** Every numeric literal typed inside a gold formula (`=F5*8.5`,
  `=B4+0.05`) is extracted, ignoring cell refs, sheet names, strings and index arguments (VLOOKUP column,
  ROUND digits, CHOOSE index). Each constant must be traceable: spoken in the script (digits or words,
  "twenty-one percent", "four hundred", "thirteen and a half") or already a value in the input workbook.
  Untraceable constants are errors when repeated, warnings when single; traceable ones that also sit in an
  assumption cell get an info nudge to link rather than retype.
- **Sheets scanner ports (G009).** Data-vendor formulas (BDP/BDH/CIQ/FDS/RTD), `#REF!` inside formulas and
  defined names, embedded images.
- **Sheets scanner ports, provenance tier (V001–V005).** Author provenance (writing application from
  docProps, default tab names, AI-tool mentions, unstyled cells), found-online markers (template vendors, URLs,
  copyright), identifying info (document creator, emails, phones, company-like names in cells, tabs, script
  and rubric, with finance phrases like Working Capital allow-listed), task metadata completeness when a
  metadata file ships, and duplicate prompts across every task in the run or a `--known-prompts` set.
- **Illogical build (I001–I003).** Rubric targets found as literals in the input, cells that are literal in
  the input but formulas in the gold with the same value, downstream tabs already present, straight from the illogical-build QC reference.
- **Tolerances (R010/R013).** Every numeric target carries exactly one band; a relative band around 0 is
  zero-width; two bands on one criterion compound.
- **Headline instruction untested (S005).** "Formulas, not typed numbers", the circ switch, check rows and
  cases flexing off Base are the most-repeated lines in scripts and were untested in 5 of 10 tasks.
- **Tab names (S004).** A tab the rubric grades on must exist in the gold and be either already in the input
  or named in the script; otherwise the criterion grades a layout nobody was told.

## Roadmap / open items

- Wire `ai-prompts` output to a model call and parse its JSON back into findings (S007–S010).
- Grade the SOTA "Solved" workbook against the rubric with the same engine, and diff against its self-grade
  to separate model-fault from task-fault.
- PII / private-company scan: pattern list plus LLM pass over script, rubric, tab names and labels.
- Presentation checks in code: font colour on hardcodes, number formats on % rows, truncated labels
  (column width vs rendered text length).
- Audio: speech-to-text alignment of recording vs script (word-error rate) once a transcription backend is
  available; AI-voice classifier.
- Point-weighting sanity beyond the current spread heuristic.

## Development

```
pip install -r requirements.txt pytest formulas
python -m pytest -q tests
python tests/fixtures.py fixture_task   # builds a passing bundle and a bundle with ~20 planted defects
python -m audio_task_linter lint fixture_task/good fixture_task/bad
```
