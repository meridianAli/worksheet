"""K*** rules: consume the TSIP sheets-scanner validation JSON (scan_<field>_<n>.json) exported alongside a task,
so workbook hygiene is checked even when the workbook binaries are not available locally."""
from __future__ import annotations

import json
import re

from ..findings import Finding, RuleInfo, ERROR, WARNING, INFO

RULES = [
    RuleInfo("K001", "Scanner: no external links / broken references / name errors", ERROR, "deterministic", (),
             "From the platform scanner output for input and gold workbooks."),
    RuleInfo("K002", "Scanner: no hidden sheets, comments, images, broken named ranges", WARNING, "deterministic", (),
             "From the platform scanner output; broken named ranges are dead definitions left over from a decomposition."),
    RuleInfo("K003", "Scanner: pre-linked blanks and hardcode share", WARNING, "deterministic", (),
             "Pre-linked blank cells in the INPUT telegraph the layout (illogical build); a high hardcode ratio in the GOLD means a typed-in build."),
    RuleInfo("K004", "Scanner: author provenance and identifying names", WARNING, "deterministic", (),
             "llmAuthorCheck.matchedTool / onlineAuthorCheck.matchedSource, plus creator / lastModifiedBy names that must be scrubbed before delivery."),
]

_PLACEHOLDER_AUTHORS = re.compile(r"^(?:|user|author|admin|owner|microsoft office user|excel|analyst|meridian.*|openpyxl|unknown)$", re.I)


def run(ctx, report):
    scans = sorted(ctx.bundle.root.glob("scan_*.json"))
    if not scans:
        for r in RULES:
            report.skip(r.id, "no scanner output in bundle")
        return
    for p in scans:
        role = "input" if "markup" in p.name or "input" in p.name else ("gold" if "golden" in p.name or "output" in p.name else "supporting")
        f = ctx.rel(p)
        try:
            d = json.loads(p.read_text())
        except json.JSONDecodeError:
            report.add(Finding("K001", WARNING, "Scanner JSON unreadable.", file=f))
            continue
        cnt = lambda k: d.get(k + "Count", len(d.get(k) or []) if isinstance(d.get(k), list) else 0)
        if cnt("externalLinks"):
            report.add(Finding("K001", ERROR, f"{role}: {cnt('externalLinks')} external link(s).", file=f, evidence=str(d.get("externalLinks"))[:200]))
        if cnt("cellsWithBrokenReferences"):
            report.add(Finding("K001", ERROR, f"{role}: {cnt('cellsWithBrokenReferences')} cell(s) with broken references.", file=f, evidence=str(d.get("cellsWithBrokenReferences"))[:200]))
        if cnt("nameErrors"):
            report.add(Finding("K001", ERROR if role == "gold" else WARNING, f"{role}: {cnt('nameErrors')} #NAME? error(s).", file=f, evidence=str(d.get("nameErrors"))[:200]))
        if d.get("hiddenSheets"):
            report.add(Finding("K002", WARNING, f"{role}: hidden sheets {d['hiddenSheets']}", file=f))
        if cnt("cellsWithComments"):
            report.add(Finding("K002", WARNING, f"{role}: {cnt('cellsWithComments')} cell comment(s).", file=f, evidence=str(d.get("cellsWithComments"))[:200]))
        if d.get("sheetsWithImages"):
            report.add(Finding("K002", WARNING, f"{role}: embedded images on {d['sheetsWithImages']}", file=f))
        if cnt("brokenNamedRanges"):
            names = sorted({x.get("name") for x in d.get("brokenNamedRanges") or [] if isinstance(x, dict)})
            report.add(Finding("K002", WARNING, f"{role}: {cnt('brokenNamedRanges')} broken named range(s): {', '.join(names[:8])}", file=f))
        pl = cnt("cellsWithPreLinkedBlanks")
        if pl:
            sev = WARNING if role == "input" else INFO
            report.add(Finding("K003", sev, f"{role}: {pl} pre-linked blank cell(s)" + (" — formulas already pointing at not-yet-built cells (illogical build signal)." if role == "input" else "."),
                               file=f, evidence=", ".join(x.get("cell", "") for x in (d.get("cellsWithPreLinkedBlanks") or [])[:8] if isinstance(x, dict))))
        hs = d.get("hardcodedNumberStats") or {}
        if hs.get("totalNumberCells"):
            ratio = hs.get("ratio", hs.get("hardcodedCount", 0) / max(1, hs["totalNumberCells"]))
            if role == "gold" and ratio > 0.6:
                report.add(Finding("K003", WARNING, f"gold: {ratio:.0%} of numeric cells are hardcodes ({hs.get('hardcodedCount')}/{hs.get('totalNumberCells')}).", file=f))
            else:
                report.add(Finding("K003", INFO, f"{role}: hardcode ratio {ratio:.0%} ({hs.get('hardcodedCount')}/{hs.get('totalNumberCells')}).", file=f))
        llm = d.get("llmAuthorCheck") or {}
        online = d.get("onlineAuthorCheck") or {}
        if llm.get("matchedTool"):
            report.add(Finding("K004", WARNING, f"{role}: authoring tool detected: {llm['matchedTool']}", file=f))
        if online.get("matchedSource"):
            report.add(Finding("K004", WARNING, f"{role}: online template source detected: {online['matchedSource']}", file=f))
        people = {v for k in ("creator", "lastModifiedBy", "manager", "company") for v in (llm.get(k), online.get(k)) if v and not _PLACEHOLDER_AUTHORS.match(str(v))}
        if people:
            report.add(Finding("K004", WARNING, f"{role}: document properties carry a name that must be scrubbed before delivery: {', '.join(sorted(people))}", file=f))
