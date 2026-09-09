"""S*** script/prompt checks and rubric<->script cross-checks."""
from __future__ import annotations

import re

from ..findings import Finding, RuleInfo, ERROR, WARNING, INFO
from ..numbers import find_cell_refs, find_excel_functions

RULES = [
    RuleInfo("S001", "Script present and substantive", ERROR, "deterministic", ("script",),
             "The script is the primary carrier of instructions; it must exist and be more than a one-liner."),
    RuleInfo("S002", "Script does not dictate cell coordinates", WARNING, "deterministic", ("script",),
             "More than a few exact row/column references turn the debrief into a read-out of cell edits."),
    RuleInfo("S003", "Script does not name Excel functions", WARNING, "deterministic", ("script",),
             "An MD says 'look it up off the curve', not 'use an XLOOKUP'."),
    RuleInfo("S004", "Rubric tab names are known to the analyst", WARNING, "deterministic", ("rubric", "script", "gold"),
             "A tab the rubric grades on must exist in the gold, and must be in the input workbook or named in the script; otherwise the criterion anchors on a layout nobody was told."),
    RuleInfo("S005", "Headline instructions are tested", WARNING, "deterministic", ("rubric", "script"),
             "If the script insists on formulas-not-hardcodes, a circ switch, a check row, cases flexing off Base, etc., at least one criterion should test it."),
    RuleInfo("S006", "Script does not leak rubric targets", WARNING, "deterministic", ("rubric", "script"),
             "Output-validation target values should not be spoken in the script (the analyst would then be transcribing, not modelling)."),
    RuleInfo("S007", "Rubric ↔ script anchoring (inferability)", WARNING, "ai-lint", ("rubric", "script", "input"),
             "LLM pass: classify every criterion Explicit / Inferrable / Anchored against the script + input; Anchored criteria are unfair."),
    RuleInfo("S008", "Script ↔ gold fidelity", WARNING, "ai-lint", ("script", "gold", "input"),
             "LLM pass: every instruction maps to a change in the gold and every gold change traces back to the script."),
    RuleInfo("S009", "Rubric coverage of script instructions", WARNING, "ai-lint", ("rubric", "script"),
             "LLM pass: list the deliverables the script asks for and report which have no criterion."),
    RuleInfo("S010", "No PII / private company names", ERROR, "ai-lint", ("script", "rubric", "gold", "input"),
             "LLM pass over script, rubric and workbook text for real private companies or people."),
]

HEADLINES = [
    ("formulas, not hardcodes", re.compile(r"(formula|formulaic|don'?t (just )?(type|hard-?code)|no hard-?cod|not hard-?cod|hard-?coded? (numbers|values))", re.I),
     re.compile(r"(formula|hard-?cod|typed|literal|linked|dynamic)", re.I)),
    ("circularity switch", re.compile(r"circ(ularity)? (switch|toggle|breaker)", re.I), re.compile(r"circ", re.I)),
    ("check / tie-out rows", re.compile(r"(check row|tie[- ]?out|checks? (that|which) (equal|sum)|balance check)", re.I), re.compile(r"(check|tie[- ]?out)", re.I)),
    ("cases flex off Base", re.compile(r"(flex|drive|link|key)\w* .{0,30}(off|from|to) (the )?base", re.I), re.compile(r"(case|scenario)", re.I)),
    ("cash sweep", re.compile(r"\bsweep\b", re.I), re.compile(r"sweep", re.I)),
    ("sensitivity table", re.compile(r"sensitivit", re.I), re.compile(r"sensitivit", re.I)),
    ("IRR / MOIC returns", re.compile(r"\b(irr|moic)\b", re.I), re.compile(r"\b(irr|moic)\b", re.I)),
    ("covenant / liquidity output", re.compile(r"(covenant|liquidity)", re.I), re.compile(r"(covenant|liquidity)", re.I)),
]


def run(ctx, report):
    s = ctx.script
    r = ctx.rubric
    sf = ctx.rel(ctx.bundle.script) if ctx.bundle.script else None
    if not s.strip():
        report.add(Finding("S001", ERROR, "No script / prompt text found in the bundle."))
        for rule in RULES[1:]:
            report.skip(rule.id, "no script")
        return
    wc = len(re.findall(r"[A-Za-z0-9$%']+", s))
    has_audio = bool(ctx.bundle.audio) or "audio_recording" in ctx.bundle.remote_fields()
    if wc < 120 and has_audio:
        report.add(Finding("S001", INFO, f"Only the {wc}-word platform prompt is available as text; the instructions live in the recording, so script-based checks (S002-S006, G008) run on the prompt only. Supply a transcript as script.txt for full coverage.", file=sf))
    elif wc < 120:
        report.add(Finding("S001", WARNING, f"Script is only {wc} words; a debrief that dictates a build is usually several hundred.", file=sf))
    # S002
    refs = find_cell_refs(s)
    if len(refs) > 3:
        report.add(Finding("S002", WARNING, f"Script contains {len(refs)} cell/row/column references: {', '.join(refs[:8])}", file=sf))
    elif refs:
        report.add(Finding("S002", INFO, f"Script contains cell/row/column references: {', '.join(refs)}", file=sf))
    # S003
    fns = find_excel_functions(s)
    if fns:
        report.add(Finding("S003", WARNING, f"Script names Excel functions: {', '.join(fns)}", file=sf))
    if r is None:
        for rid in ("S004", "S005", "S006", "S007", "S009"):
            report.skip(rid, "no rubric")
        return
    # S004 tab names
    gold = ctx.gold
    if not ctx.inputs:
        report.skip("S004", "input workbook not available locally; cannot tell which tabs the analyst already had")
    input_tabs = {t.lower() for w in ctx.inputs for t in w.sheets}
    gold_tabs = {t.lower(): t for t in gold.sheets} if gold else {}
    seen = set()
    for c in r.all():
        for name in c.sheet_names():
            key = name.lower()
            if key in seen:
                continue
            seen.add(key)
            if gold and key not in gold_tabs and not any(key in t or t in key for t in gold_tabs):
                report.add(Finding("S004", ERROR, f"Rubric refers to a '{name}' sheet that does not exist in the gold workbook (gold tabs: {', '.join(gold.sheets)}).",
                                   file=ctx.rel(ctx.bundle.rubric), location=c.id))
                continue
            in_input = key in input_tabs or any(key in t or t in key for t in input_tabs)
            in_script = re.search(r"\b" + re.escape(name) + r"\b", s, re.I) is not None
            if ctx.inputs and not in_input and not in_script:
                report.add(Finding("S004", WARNING, f"Rubric grades on a '{name}' tab that is new in the gold and never named in the script; the analyst cannot know to create it under that name. Key the criterion on the line item instead.",
                                   file=ctx.rel(ctx.bundle.rubric), location=c.id))
    # S005 headline instructions
    rubric_text = " ".join(c.text for c in r.all())
    for label, in_script, in_rubric in HEADLINES:
        if in_script.search(s) and not in_rubric.search(rubric_text):
            sev = WARNING if label in ("formulas, not hardcodes", "circularity switch", "check / tie-out rows", "cases flex off Base") else INFO
            if label == "formulas, not hardcodes" and r.by_section("Perturbation"):
                sev = INFO  # perturbations test dynamism indirectly
            report.add(Finding("S005", sev, f"Script insists on '{label}' but no criterion tests it.", file=ctx.rel(ctx.bundle.rubric)))
    # S006 leaked targets
    script_nums = {round(n.value, 1) for n in _nums(s)}
    for c in r.by_section("Output Validation"):
        for n in c.numbers():
            if abs(n.value) >= 10 and round(n.value, 1) in script_nums and not _tolerance_like(n):
                report.add(Finding("S006", WARNING, f"Output-validation target {n.raw.strip()} is spoken verbatim in the script; the criterion may be testing an input, not an output.",
                                   file=ctx.rel(ctx.bundle.rubric), location=c.id, evidence=c.text))
                break
    # AI-lint placeholders
    for rid in ("S007", "S008", "S009", "S010"):
        report.skip(rid, "ai-lint rule; run `python -m audio_task_linter ai-prompts <task_dir>` to emit the review prompt")


def _nums(text):
    from ..numbers import find_numbers
    return find_numbers(text)


def _tolerance_like(n):
    return n.unit in ("%", "pp") and abs(n.value) <= 5
