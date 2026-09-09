"""G*** gold-workbook checks, I*** illogical-build checks, P*** perturbation-on-gold checks."""
from __future__ import annotations

import re
from pathlib import Path

from ..findings import Finding, RuleInfo, ERROR, WARNING, INFO
from ..numbers import within, is_tolerance_number
from ..workbook import label_score, load_workbook
from .. import recalc as recalc_mod

RULES = [
    RuleInfo("G001", "Gold has no error values", ERROR, "deterministic", ("gold",),
             "#REF!, #DIV/0!, #VALUE!, #N/A, #NAME?, #NUM! in any cell (defined-name errors excluded)."),
    RuleInfo("G002", "Gold has no external links", ERROR, "deterministic", ("gold",),
             "Links to other files break when the workbook ships alone."),
    RuleInfo("G003", "Gold hygiene: hidden sheets, comments", WARNING, "deterministic", ("gold",),
             "Hidden sheets and cell comments leak authoring notes or hide answer machinery."),
    RuleInfo("G004", "Gold is formula-driven", WARNING, "deterministic", ("gold", "input"),
             "Cells that are new or changed vs the input should mostly be formulas; a high hardcode share means the build is typed in."),
    RuleInfo("G005", "Output-validation targets reproduce in the gold", ERROR, "deterministic", ("rubric", "gold"),
             "Each numeric target must be found (within its tolerance, any display-unit scaling) in a gold cell that is a formula."),
    RuleInfo("G006", "Output-validation target is not a hardcode", WARNING, "deterministic", ("rubric", "gold"),
             "Target found only in literal cells, or in 3+ cells, means the rubric grades an input or a pasted value."),
    RuleInfo("G007", "Perturbation baseline exists in the gold", ERROR, "deterministic", ("rubric", "gold"),
             "The 'from' value must sit in a literal (input) cell on the named tab whose row label matches the criterion."),
    RuleInfo("P001", "Perturbation reproduces on the gold", ERROR, "deterministic", ("rubric", "gold"),
             "Apply the change to a copy of the gold, recalculate with LibreOffice, and confirm the named output lands on the target within tolerance."),
    RuleInfo("P002", "Perturbation actually moves the output", WARNING, "deterministic", ("rubric", "gold"),
             "If the output is unchanged by the perturbation the criterion is non-discriminating (the gold itself would pass it hardcoded)."),
    RuleInfo("I001", "Input holds no rubric targets (illogical build)", ERROR, "deterministic", ("rubric", "input"),
             "An output-validation or perturbation target sitting as a literal in the input is an answer hint."),
    RuleInfo("I002", "Input holds no pre-computed gold values", ERROR, "deterministic", ("input", "gold"),
             "Cells that are literals in the input but formulas in the gold, with equal values, are hardcoded dependencies of the unbuilt work."),
    RuleInfo("I003", "Input has no downstream tabs", WARNING, "deterministic", ("input", "gold", "script"),
             "Tabs the script asks the analyst to build (Transaction, Output, Returns, Debt schedule, ...) must not already exist in the input."),
    RuleInfo("I004", "Input has no pre-linked blanks", WARNING, "deterministic", ("input",),
             "Formulas in the input that evaluate to 0/blank because they point at not-yet-built cells telegraph the layout."),
]

DOWNSTREAM_TAB_WORDS = ("output", "transaction", "returns", "debt", "sweep", "waterfall", "covenant", "liquidity",
                        "dcf", "valuation", "sensitivit", "lbo", "sources", "uses", "warrant", "check")


def run(ctx, report):
    gold = ctx.gold
    if gold is None:
        for rule in RULES:
            report.skip(rule.id, "no gold workbook (or not .xlsx)")
        return
    gf = ctx.rel(gold.path)
    inputs = ctx.inputs
    r = ctx.rubric

    # G001 errors
    errs = gold.error_cells()
    if errs:
        report.add(Finding("G001", ERROR, f"{len(errs)} error-value cells in the gold.", file=gf,
                           evidence=", ".join(f"{c.ref}={c.value}" for c in errs[:15])))
    # G002 external links
    if gold.external_links:
        report.add(Finding("G002", ERROR, f"Gold has {len(gold.external_links)} external link(s).", file=gf,
                           evidence="; ".join(str(x) for x in gold.external_links[:5])))
    for c in gold.formula_cells():
        if c.formula and re.search(r"\[[^\]]+\.xls[xmb]?\]", c.formula):
            report.add(Finding("G002", ERROR, "Formula references an external workbook.", file=gf, location=c.ref, evidence=c.formula[:120]))
            break
    # G003 hygiene
    if gold.hidden_sheets:
        report.add(Finding("G003", WARNING, f"Hidden sheets: {', '.join(gold.hidden_sheets)}", file=gf))
    if gold.comments:
        report.add(Finding("G003", WARNING, f"{len(gold.comments)} cell comments (first: {', '.join(gold.comments[:5])}).", file=gf))
    # G004 formula share of new/changed cells
    if inputs:
        inp = inputs[0]
        new_cells = [c for k, c in gold.cells.items() if c.is_number or c.is_formula]
        changed = [c for c in new_cells if k_changed(inp, c)]
        num_changed = [c for c in changed if c.is_number or c.is_formula]
        if len(num_changed) >= 20:
            hard = sum(1 for c in num_changed if c.is_number and not c.is_formula)
            share = hard / len(num_changed)
            if share > 0.6:
                report.add(Finding("G004", WARNING, f"{share:.0%} of the {len(num_changed)} new/changed numeric cells in the gold are hardcodes.", file=gf))
            else:
                report.add(Finding("G004", INFO, f"{hard} of {len(num_changed)} new/changed numeric cells are hardcodes ({share:.0%}).", file=gf))
    # I003 downstream tabs in input
    script = ctx.script.lower()
    for inp in inputs:
        for tab in inp.sheets:
            tl = tab.lower()
            if any(w in tl for w in DOWNSTREAM_TAB_WORDS) and tab in gold.sheets:
                # is the tab something the script asks to build? (mentioned as build/create/add)
                if re.search(r"(build|create|add|put together|set up|make)\W{1,40}[^.]{0,60}" + re.escape(tl.split()[0]), script):
                    n_in = sum(1 for k in inp.cells if k[0] == tab)
                    if n_in > 10:
                        report.add(Finding("I003", WARNING, f"Input already contains a populated '{tab}' tab ({n_in} cells) that the script asks the analyst to build.", file=ctx.rel(inp.path)))
    # I004 pre-linked blanks
    for inp in inputs:
        blanks = [c for c in inp.formula_cells() if c.value in (0, None, "") and c.formula and re.search(r"[A-Za-z_]+!|'[^']+'!", c.formula or "")]
        if len(blanks) >= 5:
            report.add(Finding("I004", WARNING, f"{len(blanks)} cross-sheet formulas in the input evaluate to 0/blank (pre-linked blanks).", file=ctx.rel(inp.path),
                               evidence=", ".join(c.ref for c in blanks[:10])))
    # I002 literal-in-input == formula-in-gold
    for inp in inputs:
        hints = []
        for k, ic in inp.cells.items():
            if not (ic.is_number and not ic.is_formula):
                continue
            gc = gold.cells.get(k)
            if gc and gc.is_formula and gc.is_number and abs(float(ic.value)) > 1e-9 and within(float(gc.value), float(ic.value), {"kind": "relative", "value": 0.05}):
                hints.append((ic, gc))
        if hints:
            sev = ERROR if len(hints) >= 3 else WARNING
            report.add(Finding("I002", sev, f"{len(hints)} cell(s) are literals in the input but formulas in the gold with the same value (hardcoded dependencies of the unbuilt work).",
                               file=ctx.rel(inp.path), evidence="; ".join(f"{a.ref}={a.value} vs gold {b.formula[:40]}" for a, b in hints[:8])))

    if r is None:
        for rid in ("G005", "G006", "G007", "P001", "P002", "I001"):
            report.skip(rid, "no rubric")
        return
    rf = ctx.rel(ctx.bundle.rubric)

    # G005 / G006 / I001: output validation targets
    for c in r.by_section("Output Validation"):
        nums = [n for n in c.numbers() if not _is_tol(n, c.text)]
        if not nums:
            continue
        tols = c.tolerances()
        tol = tols[0] if tols else None
        target = nums[-1]
        sheets = c.sheet_names()
        sheet = _resolve_sheet(gold, sheets)
        hits = gold.find_value(target, tol, sheet=sheet)
        if not hits and sheet:
            hits = gold.find_value(target, tol)
        hits = filter_by_period(hits, c.text, gold)
        if not hits:
            if target.value == 0 or re.search(r"\b(exactly|zero|blank|empty)\b", c.text, re.I):
                zero_hits = [x for x in gold.numeric_cells() if abs(float(x.value)) <= 0.005]
                if zero_hits:
                    continue
            report.add(Finding("G005", ERROR, f"Target {target.raw.strip()} not found anywhere in the gold" + (f" (searched tab '{sheet}' then all)" if sheet else "") + ".",
                               file=rf, location=c.id, evidence=c.text))
            continue
        ranked = sorted(hits, key=lambda h: -label_score(c.text, gold.label_for(h[0]), gold.header_for(h[0])))
        best, scale = ranked[0]
        formula_hits = [h for h in hits if h[0].is_formula]
        if not formula_hits:
            report.add(Finding("G006", WARNING, f"Target {target.raw.strip()} only appears as a hardcoded literal in the gold ({', '.join(h[0].ref for h in hits[:5])}); the criterion grades an input, not an output.",
                               file=rf, location=c.id, evidence=c.text))
        elif len(hits) >= 3 and abs(target.value) >= 1:
            report.add(Finding("G006", INFO, f"Target {target.raw.strip()} matches {len(hits)} gold cells ({', '.join(h[0].ref for h in hits[:6])}); check the criterion names the row uniquely.",
                               file=rf, location=c.id))
        if label_score(c.text, gold.label_for(best), gold.header_for(best)) == 0 and abs(target.value) >= 1:
            report.add(Finding("G005", INFO, f"Target {target.raw.strip()} found at {best.ref} (row label '{gold.label_for(best)}') but no words of the criterion match that label; confirm the right cell.",
                               file=rf, location=c.id))
        # I001 in inputs
        for inp in inputs:
            ihits = [h for h in inp.find_value(target, tol) if not h[0].is_formula]
            if ihits and abs(target.value) >= 1:
                report.add(Finding("I001", ERROR, f"Output-validation target {target.raw.strip()} already sits as a literal in the input ({', '.join(h[0].ref for h in ihits[:5])}) — answer hint / tests an input.",
                                   file=ctx.rel(inp.path), location=c.id, evidence=c.text))

    # G007 / P001 / P002 / I001: perturbations
    perts = r.by_section("Perturbation")
    lo_ok = ctx.recalc and recalc_mod.soffice_path() is not None
    if perts and ctx.recalc and not lo_ok:
        report.skip("P001", "LibreOffice not available for recalculation")
        report.skip("P002", "LibreOffice not available for recalculation")
    for c in perts:
        p = c.parse_perturbation()
        if not p or not p["to_num"]:
            continue
        # baseline
        in_sheet = _resolve_sheet(gold, _sheet_from(p["input"]) or c.sheet_names()[:1])
        from_n = p["from_num"]
        candidates = []
        if from_n is not None:
            for cell, scale in gold.find_value(from_n, {"kind": "relative", "value": 0.01}, sheet=in_sheet):
                if cell.is_formula:
                    continue
                candidates.append((label_score(p["input"], gold.label_for(cell), gold.header_for(cell)), cell, scale))
            candidates.sort(key=lambda t: -t[0])
        if from_n is not None and not candidates:
            report.add(Finding("G007", ERROR, f"Baseline value {from_n.raw.strip()} for '{p['input']}' not found as a literal" + (f" on tab '{in_sheet}'" if in_sheet else "") + " in the gold.",
                               file=rf, location=c.id, evidence=c.text))
            continue
        if from_n is None:
            report.skip("P001", f"{c.id}: no baseline value to locate the input cell")
            continue
        score, cell, scale = candidates[0]
        if score == 0 and len(candidates) > 1:
            report.add(Finding("G007", WARNING, f"{len(candidates)} literal cells equal {from_n.raw.strip()} and none has a row label matching '{p['input']}'; using {cell.ref} ('{gold.label_for(cell)}').",
                               file=rf, location=c.id))
        # I001 for perturbation target
        tgt = p["target_num"]
        tol = p["tolerances"][-1] if p["tolerances"] else None
        if tgt is not None:
            for inp in inputs:
                ihits = [h for h in inp.find_value(tgt, tol) if not h[0].is_formula]
                if ihits and abs(tgt.value) >= 1:
                    report.add(Finding("I001", ERROR, f"Perturbation target {tgt.raw.strip()} already sits as a literal in the input ({', '.join(h[0].ref for h in ihits[:5])}).",
                                       file=ctx.rel(inp.path), location=c.id, evidence=c.text))
        if tgt is None or not lo_ok:
            continue
        # apply and recalc
        new_val = p["to_num"].value * scale
        if p["to_num"].is_percent and scale == 1.0 and from_n.is_percent and isinstance(cell.value, (int, float)) and abs(cell.value) < 1.5 and abs(from_n.value) >= 1:
            new_val = p["to_num"].value / 100.0
        try:
            out = recalc_mod.perturb_and_recalc(gold.path, {(cell.sheet, cell.coord): new_val}, Path(ctx.work_dir) / c.id)
            pw = load_workbook(out)
        except Exception as e:
            report.add(Finding("P001", WARNING, f"Could not recalculate perturbation: {e}", file=rf, location=c.id))
            continue
        out_sheet = _resolve_sheet(gold, _sheet_from(p["output"]) or [s for s in c.sheet_names() if s.lower() != (in_sheet or "").lower()][:1])
        hits = pw.find_value(tgt, tol, sheet=out_sheet)
        if not hits and out_sheet:
            hits = pw.find_value(tgt, tol)
        hits = [h for h in hits if h[0].is_formula]
        hits = filter_by_period(hits, p["output"] + " " + (p["target"] or ""), pw)
        if not hits:
            near = _nearest_by_label(pw, gold, p["output"], out_sheet)
            report.add(Finding("P001", ERROR, f"After setting {cell.ref} {cell.value!r} → {new_val!r} and recalculating, no formula cell equals {tgt.raw.strip()}" + (f" (±{tol['raw']})" if tol else "") + ".",
                               file=rf, location=c.id, evidence=near or c.text))
            continue
        ranked = sorted(hits, key=lambda h: -label_score(p["output"], pw.label_for(h[0]), pw.header_for(h[0])))
        hit, _ = ranked[0]
        base = gold.cells.get((hit.sheet, hit.coord))
        if base and base.is_number and within(float(base.value), float(hit.value), {"kind": "relative", "value": 0.0001}):
            report.add(Finding("P002", WARNING, f"{hit.ref} equals the target {tgt.raw.strip()} both before and after the perturbation; the criterion does not discriminate.",
                               file=rf, location=c.id, evidence=c.text))
        else:
            report.add(Finding("P001", INFO, f"OK: {cell.ref} {cell.value!r} → {new_val!r} moves {hit.ref} ('{pw.label_for(hit)}') from {base.value if base else '?'} to {hit.value} (target {tgt.raw.strip()}).",
                               file=rf, location=c.id))


def k_changed(inp, gc):
    ic = inp.cells.get((gc.sheet, gc.coord))
    if ic is None:
        return True
    return ic.value != gc.value or ic.formula != gc.formula


def _is_tol(n, text):
    return is_tolerance_number(n, text)


_PERIOD_RE = re.compile(r"\b(?:(?:Q[1-4]|H[12])\s*)?(?:FY|CY)?\s?((?:19|20)\d{2})(?:E|A|P)?\b", re.I)


def filter_by_period(hits, text, wb):
    """Keep hits whose column header carries the year the criterion names (if any header does)."""
    years = set(_PERIOD_RE.findall(text or ""))
    if not years or not hits:
        return hits
    matched = [h for h in hits if any(y in (wb.header_for(h[0]) or "") for y in years)]
    any_headers = any(wb.header_for(h[0]) for h in hits)
    return matched if (matched or any_headers) else hits


def _sheet_from(phrase):
    if not phrase:
        return []
    m = re.search(r"(?:on|in)\s+the\s+[\"'“]?([A-Za-z][\w &/\-\.]{0,40}?)[\"'”]?\s+(?:sheet|tab)", phrase)
    return [m.group(1).strip()] if m else []


def _resolve_sheet(wb, names):
    if not names:
        return None
    lower = wb.sheet_names_lower()
    for n in names:
        if n.lower() in lower:
            return lower[n.lower()]
        for k, v in lower.items():
            if n.lower() in k or k in n.lower():
                return v
    return None


def _nearest_by_label(pw, gold, phrase, sheet):
    best = None
    for c in pw.formula_cells():
        if sheet and c.sheet != sheet:
            continue
        if not c.is_number:
            continue
        s = label_score(phrase, pw.label_for(c), pw.header_for(c))
        if s > 0 and (best is None or s > best[0]):
            best = (s, c)
    if best:
        c = best[1]
        g = gold.cells.get((c.sheet, c.coord))
        return f"closest label match {c.ref} ('{pw.label_for(c)}' / {pw.header_for(c)}) = {c.value} after perturbation (gold {g.value if g else '?'})"
    return None


# ---------------------------------------------------------------------------------------------
# G008: hidden hardcodes inside gold formulas
# ---------------------------------------------------------------------------------------------
from ..spoken import spoken_values  # noqa: E402

RULES.append(RuleInfo("G008", "No hidden hardcodes inside gold formulas", ERROR, "deterministic", ("gold", "input", "script"),
                      "A numeric constant typed into a formula (=F5*8.5, =B4+0.05) must be spoken in the script or already present as a "
                      "value in the input workbook; otherwise it is an untraceable assumption. Constants that do exist as an assumption "
                      "cell should be linked, not retyped."))

_TRIVIAL_CONSTANTS = {0, 1, 2, 3, 4, 10, 12, 100, 1000, 10000, 100000, 1000000, 360, 365, 0.5, -1}
_STRING_LIT = re.compile(r'"[^"]*"')
_SHEET_REF = re.compile(r"'[^']+'!|[A-Za-z_][\w\.]*!")
_CELL_TOKEN = re.compile(r"\$?[A-Z]{1,3}\$?\d{1,7}(?::\$?[A-Z]{1,3}\$?\d{1,7})?")
_FUNC_NAME = re.compile(r"[A-Z][A-Z0-9\._]*\s*\(")
_NUM_IN_FORMULA = re.compile(r"(?<![A-Za-z0-9_\.])(\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)(%?)")
# argument positions that are indices/flags, not economics: VLOOKUP col, MATCH type, ROUND digits, CHOOSE index, OFFSET/INDEX offsets
_INDEX_FUNCS = ("VLOOKUP", "HLOOKUP", "MATCH", "ROUND", "ROUNDUP", "ROUNDDOWN", "CHOOSE", "INDEX", "OFFSET", "MROUND",
                "SMALL", "LARGE", "EOMONTH", "EDATE", "TEXT", "LEFT", "RIGHT", "MID", "IFERROR", "RANK", "QUARTILE", "PERCENTILE")


def formula_constants(formula: str) -> list[float]:
    """Numeric literals typed into a formula, excluding cell refs, sheet names, strings and index arguments."""
    f = _STRING_LIT.sub('""', formula)
    f = _SHEET_REF.sub("", f)
    f = _CELL_TOKEN.sub("REF", f)
    # blank out arguments of index-style functions (crude: everything inside their parentheses that is a bare integer)
    for fn in _INDEX_FUNCS:
        for m in re.finditer(fn + r"\s*\(", f):
            depth, k = 0, m.end() - 1
            while k < len(f):
                if f[k] == "(":
                    depth += 1
                elif f[k] == ")":
                    depth -= 1
                    if depth == 0:
                        break
                k += 1
            inner = f[m.end():k]
            inner = re.sub(r"(?<![A-Za-z0-9_\.])\d+(?![\.\d])", "IDX", inner)
            f = f[:m.end()] + inner + f[k:]
    out = []
    for m in _NUM_IN_FORMULA.finditer(f):
        v = float(m.group(1))
        if m.group(2) == "%":
            v /= 100.0
        if v in _TRIVIAL_CONSTANTS:
            continue
        # exponents like ^(1/4) and /4 style period conversions are trivial
        out.append(v)
    return out


def run_hidden_hardcodes(ctx, report):
    gold = ctx.gold
    if gold is None:
        report.skip("G008", "no gold workbook")
        return
    inputs = ctx.inputs
    inp = inputs[0] if inputs else None
    spoken = spoken_values(ctx.script) if ctx.script else set()
    input_values = set()
    for w in inputs:
        for c in w.numeric_cells():
            v = float(c.value)
            for x in (v, -v, v * 100, v / 100.0):
                input_values.add(round(x, 6))
    gold_literals = {}
    for c in gold.literal_numbers():
        gold_literals.setdefault(round(float(c.value), 6), []).append(c.ref)

    by_const: dict = {}
    for c in gold.formula_cells():
        if not c.formula:
            continue
        if inp is not None and not k_changed(inp, c):
            continue  # inherited from the input untouched: not this task's build
        for v in formula_constants(c.formula):
            key = round(v, 6)
            by_const.setdefault(key, []).append(c)

    for key, cells in sorted(by_const.items(), key=lambda kv: -len(kv[1])):
        in_script = key in spoken or round(-key, 6) in spoken
        in_input = key in input_values
        sample = ", ".join(f"{c.ref} {c.formula[:50]}" for c in cells[:4])
        if in_script or in_input:
            linkable = gold_literals.get(key) or gold_literals.get(round(key * 100, 6)) or gold_literals.get(round(key / 100, 6))
            if linkable and len(cells) >= 1:
                src = "spoken in the script" if in_script else "present in the input"
                report.add(Finding("G008", INFO, f"Constant {key:g} is typed into {len(cells)} formula(s) but also sits as a value at {', '.join(linkable[:3])}; link to the cell instead of retyping ({src}).",
                                   file=ctx.rel(gold.path), evidence=sample))
            continue
        sev = ERROR if len(cells) >= 2 else WARNING
        report.add(Finding("G008", sev, f"Hidden hardcode {key:g} in {len(cells)} formula cell(s): not spoken in the script and not in the input workbook.",
                           file=ctx.rel(gold.path), evidence=sample))


_orig_run = run


def run(ctx, report):  # noqa: F811
    _orig_run(ctx, report)
    run_hidden_hardcodes(ctx, report)


# ---------------------------------------------------------------------------------------------
# G009: sheets-pipeline scanner checks ported over (broken refs, named ranges, data-vendor formulas, images)
# ---------------------------------------------------------------------------------------------
RULES.append(RuleInfo("G009", "No data-vendor formulas, broken refs, broken named ranges or embedded images", ERROR, "deterministic", ("gold",),
                      "Ported from the sheets delivery scanner: Bloomberg/CapIQ/FactSet/RTD calls cannot evaluate off-terminal; #REF! inside "
                      "formulas and defined names are dead links; embedded images are usually screenshots of source data."))

_VENDOR_FN = re.compile(r"\b(BDP|BDH|BDS|BQL|BLP|CIQ|CIQRANGE|FDS|FDSB|RTD|CAPIQ|GETQUOTE|STOCKHISTORY|WDS)\s*\(", re.I)


def run_scanner_checks(ctx, report):
    gold = ctx.gold
    if gold is None:
        report.skip("G009", "no gold workbook")
        return
    gf = ctx.rel(gold.path)
    vendor = [c for c in gold.formula_cells() if c.formula and _VENDOR_FN.search(c.formula)]
    if vendor:
        report.add(Finding("G009", ERROR, f"{len(vendor)} data-vendor formula(s) in the gold.", file=gf,
                           evidence=", ".join(f"{c.ref} {c.formula[:40]}" for c in vendor[:5])))
    broken = [c for c in gold.formula_cells() if c.formula and "#REF!" in c.formula]
    if broken:
        report.add(Finding("G009", ERROR, f"{len(broken)} formula(s) contain #REF! (broken references).", file=gf,
                           evidence=", ".join(f"{c.ref} {c.formula[:40]}" for c in broken[:5])))
    bad_names = [n for n, t in gold.defined_names.items() if t and "#REF!" in str(t)]
    if bad_names:
        report.add(Finding("G009", WARNING, f"{len(bad_names)} broken named range(s): {', '.join(bad_names[:6])}", file=gf))
    if gold.images:
        report.add(Finding("G009", WARNING, f"Embedded images on: {', '.join(gold.images)}", file=gf))


_orig_run2 = run


def run(ctx, report):  # noqa: F811
    _orig_run2(ctx, report)
    run_scanner_checks(ctx, report)
