"""R*** rubric structure and wording checks (rubric text only; no workbook needed)."""
from __future__ import annotations

import re
from collections import Counter

from ..findings import Finding, RuleInfo, ERROR, WARNING, INFO
from ..numbers import find_cell_refs, find_excel_functions, find_numbers, is_tolerance_number
from ..rubric import REQUIRED_SECTIONS, NEGATIVE_SECTIONS

RULES = [
    RuleInfo("R001", "No cell/row/column refs in criteria", ERROR, "deterministic", ("rubric",),
             "Criteria must key on tab + row label + column header, never on A1 coordinates (D42, cell Y26, row 12, column F). The solver's layout is not the gold's."),
    RuleInfo("R002", "Every criterion ends in a question mark", ERROR, "deterministic", ("rubric",),
             "The judge answers each criterion Yes/No; a trailing qualifying statement is not gradable."),
    RuleInfo("R003", "Every criterion has points", ERROR, "deterministic", ("rubric",),
             "Rubric gen or a contributor edit sometimes drops the points."),
    RuleInfo("R004", "Pitfalls negative, others positive, none zero", ERROR, "deterministic", ("rubric",),
             "Pitfalls are negative; Output Validation / Perturbation / Presentation / Model Integration are positive."),
    RuleInfo("R005", "Points within 1-10 (pitfalls -1 to -10)", WARNING, "deterministic", ("rubric",),
             "|points| between 1 and 10 for every section; pitfalls carry the negative sign."),
    RuleInfo("R006", "All 4 sections present and non-empty", ERROR, "deterministic", ("rubric",),
             "Output Validation, Perturbation, Presentation and Pitfalls each have at least one criterion; no declared section is empty."),
    RuleInfo("R007", "Enough criteria (10 total, 5 OV, 3 perturbation)", WARNING, "deterministic", ("rubric",),
             "At least 10 criteria in total; Output Validation and Perturbation carry the bulk."),
    RuleInfo("R008", "No duplicate criteria", ERROR, "deterministic", ("rubric",),
             "Same text twice (after whitespace/case normalisation) double-counts points."),
    RuleInfo("R009", "Perturbations are 'from A to B, does Y hit Z'", ERROR, "deterministic", ("rubric",),
             "'If <input> on <tab> is changed from A to B, does <output> update to Z (±tol)?' with a numeric from, to and target."),
    RuleInfo("R010", "Exactly one tolerance per numeric target", WARNING, "deterministic", ("rubric",),
             "Every value check states a tolerance (±2% numbers, ±0.05 multiples, ±0.5pp percentages); stating it twice widens the band."),
    RuleInfo("R011", "One expected value per criterion (no stacking)", WARNING, "deterministic", ("rubric",),
             "Several independent expected values in one question zero multiple points on one miss (allowed in Presentation and Pitfalls)."),
    RuleInfo("R012", "No vague words without a tab/line anchor", WARNING, "deterministic", ("rubric",),
             "'correct', 'consistent', 'appropriate', 'properly' without a tab / line-item anchor is not gradable."),
    RuleInfo("R013", "No relative tolerance on a zero target", WARNING, "deterministic", ("rubric",),
             "'within ±2% of 0' is a zero-width band; use an absolute tolerance."),
    RuleInfo("R014", "No Excel function names in criteria", WARNING, "deterministic", ("rubric",),
             "Criteria grade results, not the construction (SUMIFS vs SUMPRODUCT)."),
    RuleInfo("R016", "Pitfalls include the error-value scan", WARNING, "deterministic", ("rubric",),
             "Pitfalls should include the standard #REF!/#DIV/0!/#VALUE! scan."),
]

VAGUE = re.compile(r"\b(correct(ly)?|consistent(ly)?|appropriate(ly)?|proper(ly)?|reasonabl[ey]|clean(ed)? up|accurate(ly)?|sensible|as expected|matches? expectations?)\b", re.I)
ANCHOR = re.compile(r"\b(sheet|tab|row|line|section|column|schedule|table|header|label)\b|\b[A-Z][a-z]+ [A-Z][a-z]+\b", 0)
STACK_JOIN = re.compile(r"\b(and|as well as|plus|also|both)\b", re.I)
EXPECTED_CLAUSE = re.compile(r"\b(?:equal(?:s|ing)?(?:\s+to)?|update[sd]?\s+to|change[sd]?\s+to|become[s]?|remain[s]?(?:\s+at)?|stay[s]?(?:\s+at)?|read[s]?|return[s]?|show(?:s|ing)?)\s+"
                             r"(?:a\s+|an\s+|the\s+)?(?:approximately\s+|about\s+|roughly\s+|exactly\s+)?[\$\(\-]?\d", re.I)
ENUM_CLAUSE = re.compile(r",\s*(?:and\s+)?(?:a|an)\s+[A-Z][\w %/&-]{2,40}?\s+of\s+[\$\(\-]?\d", re.I)


def run(ctx, report):
    r = ctx.rubric
    if r is None:
        for rule in RULES:
            report.skip(rule.id, "no rubric found")
        return
    f = ctx.rel(ctx.bundle.rubric)
    crits = r.all()
    if not crits:
        report.add(Finding("R006", ERROR, "Rubric parsed to zero criteria; check the file format.", file=f))
        return

    # R001 cell refs
    for c in crits:
        refs = find_cell_refs(c.text)
        if refs:
            report.add(Finding("R001", ERROR, f"Criterion references cells/rows/columns: {', '.join(refs)}",
                               file=f, location=c.id, evidence=c.text))
    # R002 question mark
    for c in crits:
        if not c.text.rstrip().rstrip("*_ ").endswith("?"):
            report.add(Finding("R002", ERROR, "Criterion does not end with a question mark.", file=f, location=c.id, evidence=c.text))
    # R003/R004/R005 points
    for c in crits:
        if c.points is None:
            report.add(Finding("R003", ERROR, "Criterion has no point value.", file=f, location=c.id, evidence=c.text))
            continue
        neg_section = c.section in NEGATIVE_SECTIONS
        if neg_section and c.points > 0:
            report.add(Finding("R004", ERROR, f"Pitfall carries positive points ({c.points:+g}).", file=f, location=c.id, evidence=c.text))
        if not neg_section and c.points < 0 and c.section != "(unsectioned)":
            report.add(Finding("R004", ERROR, f"Non-pitfall criterion carries negative points ({c.points:+g}).", file=f, location=c.id, evidence=c.text))
        if c.points == 0:
            report.add(Finding("R004", ERROR, "Criterion carries zero points.", file=f, location=c.id, evidence=c.text))
        cap = ctx.max_pitfall_points if neg_section else ctx.max_points
        if abs(c.points) > cap:
            report.add(Finding("R005", WARNING, f"|points| = {abs(c.points):g} exceeds the cap of {cap:g} for {c.section}.", file=f, location=c.id))
        elif 0 < abs(c.points) < 1:
            report.add(Finding("R005", WARNING, f"|points| = {abs(c.points):g} is below 1.", file=f, location=c.id))
    # R006 sections
    names = {s.name for s in r.sections}
    for req in REQUIRED_SECTIONS:
        if req not in names:
            report.add(Finding("R006", ERROR, f"Missing section: {req}.", file=f))
    for s in r.sections:
        if s.declared and not s.criteria:
            report.add(Finding("R006", ERROR, f"Section '{s.name}' is declared but has no criteria.", file=f))
    if "(unsectioned)" in names:
        report.add(Finding("R006", WARNING, f"{len(r.by_section('(unsectioned)'))} criteria are not under a recognised section header.", file=f))
    # R007 count
    if len(crits) < ctx.min_criteria:
        report.add(Finding("R007", WARNING, f"Only {len(crits)} criteria; expected at least {ctx.min_criteria}.", file=f))
    ov, pt = len(r.by_section("Output Validation")), len(r.by_section("Perturbation"))
    if ov and ov < 5:
        report.add(Finding("R007", WARNING, f"Only {ov} Output Validation criteria.", file=f))
    if pt and pt < 3:
        report.add(Finding("R007", WARNING, f"Only {pt} Perturbation criteria; perturbation density is the strongest discriminator.", file=f))
    # R008 duplicates
    norm = Counter(re.sub(r"\W+", " ", c.text.lower()).strip() for c in crits)
    for c in crits:
        key = re.sub(r"\W+", " ", c.text.lower()).strip()
        if norm[key] > 1:
            report.add(Finding("R008", ERROR, f"Duplicate criterion text (appears {norm[key]}x).", file=f, location=c.id, evidence=c.text))
            norm[key] = 0  # report once
    # R009 perturbation shape
    for c in r.by_section("Perturbation"):
        p = c.parse_perturbation()
        if p is None:
            report.add(Finding("R009", ERROR, "Perturbation criterion does not follow 'If <input> is changed from A to B, does <output> update to Z?'.",
                               file=f, location=c.id, evidence=c.text))
            continue
        if p["from_num"] is None:
            report.add(Finding("R009", WARNING, "Perturbation does not state the baseline ('from') value; the judge cannot confirm the starting state.", file=f, location=c.id, evidence=c.text))
        if p["to_num"] is None:
            report.add(Finding("R009", ERROR, "Perturbation has no numeric 'to' value.", file=f, location=c.id, evidence=c.text))
        if p["from_is_date"] and p["to_is_date"] and p["from"].strip().lower() == p["to"].strip().lower():
            report.add(Finding("R009", ERROR, "Perturbation 'from' and 'to' dates are identical.", file=f, location=c.id, evidence=c.text))
        if p["target_num"] is None and not re.search(r"\b(yes|no|true|false|blank|zero|empty|switch|change|unchanged|stay|remain|formula|from .* to)\b", p["target"] or "", re.I):
            report.add(Finding("R009", ERROR, "Perturbation has no numeric expected result.", file=f, location=c.id, evidence=c.text))
        if p["from_num"] and p["to_num"] and p["from_num"].unit != "date" and p["to_num"].unit != "date" and p["from_num"].value == p["to_num"].value:
            report.add(Finding("R009", ERROR, "Perturbation 'from' and 'to' values are identical.", file=f, location=c.id, evidence=c.text))
    # R010 / R013 tolerances
    for c in crits:
        if c.section in ("Presentation", "Pitfalls"):
            continue
        tols = c.tolerances()
        nums = [n for n in c.numbers() if not _is_tolerance_number(n, c.text)]
        if c.section == "Perturbation":
            p = c.parse_perturbation()
            targets = [p["target_num"]] if p and p["target_num"] else nums[-1:]
        else:
            targets = nums
        has_numeric_target = bool(targets)
        if has_numeric_target and not tols:
            if not re.search(r"\bexactly\b|\bequal to 0\b|\bis 0\b|\bzero\b|\bblank\b|\bempty\b|\bTRUE\b|\bFALSE\b|\bequal 1\b|\bor 1\b", c.text):
                report.add(Finding("R010", WARNING, "Numeric target with no tolerance stated.", file=f, location=c.id, evidence=c.text))
        if len(tols) > 1 and c.section != "Perturbation":
            report.add(Finding("R010", WARNING, f"Tolerance stated {len(tols)} times ({', '.join(t['raw'] for t in tols)}); the band compounds.", file=f, location=c.id, evidence=c.text))
        if len(tols) > 1 and c.section == "Perturbation":
            # one tolerance is legitimate per numeric quantity; two on the same target is the compounding case
            if len(set(t["raw"] for t in tols)) < len(tols):
                report.add(Finding("R010", WARNING, "Same tolerance stated twice; the band compounds.", file=f, location=c.id, evidence=c.text))
        for t in tols:
            if t["kind"] == "relative" and targets and any(tn.value == 0 for tn in targets if tn):
                report.add(Finding("R013", WARNING, "Relative tolerance on a zero target is a zero-width band; use an absolute tolerance.", file=f, location=c.id, evidence=c.text))
    # R011 stacking: several independent expected values in one question.
    # Counted as "expected-value clauses": '<verb> [approximately] <number>' and enumerations like 'a Loan Amount of $0'.
    for c in crits:
        if c.section in ("Presentation", "Pitfalls"):
            continue
        qmarks = re.sub(r"#NAME\?", "", c.text).count("?")
        text = c.text
        if c.section == "Perturbation":
            text = re.sub(r"\bchanged\s+from\s+\S+\s+to\s+\S+", "changed", text, flags=re.I)   # the input move is not a target
            text = re.sub(r"\b(update|change|move)s?\s+from\s+\S+\s+to\s+", r"\1 to ", text, flags=re.I)  # 'from X to Y' before/after is one target
        clauses = len(EXPECTED_CLAUSE.findall(text)) + len(ENUM_CLAUSE.findall(text))
        if qmarks > 1 or clauses >= 2:
            report.add(Finding("R011", WARNING, f"Possible stacking: {qmarks} question mark(s), {clauses} expected-value clauses in one criterion.", file=f, location=c.id, evidence=c.text))
    # R012 vague
    for c in crits:
        if VAGUE.search(c.text) and not ANCHOR.search(c.text):
            report.add(Finding("R012", WARNING, f"Vague term '{VAGUE.search(c.text).group(0)}' with no tab/line-item anchor.", file=f, location=c.id, evidence=c.text))
    # R014 excel functions
    for c in crits:
        fns = find_excel_functions(c.text)
        if fns:
            report.add(Finding("R014", WARNING, f"Criterion names Excel functions: {', '.join(fns)}.", file=f, location=c.id, evidence=c.text))
    # R016 error pitfall
    if r.section("Pitfalls") and not any(re.search(r"#REF|#DIV|#VALUE|error values?", c.text, re.I) for c in r.by_section("Pitfalls")):
        report.add(Finding("R016", WARNING, "Pitfalls section has no error-value (#REF!/#DIV/0!/#VALUE!) check.", file=f))


def _is_tolerance_number(n, text: str) -> bool:
    return is_tolerance_number(n, text)
