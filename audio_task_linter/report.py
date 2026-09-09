from __future__ import annotations

import json
from collections import defaultdict

from .findings import ERROR, WARNING, INFO
from .rules import catalog

TITLES = {r.id: r.title for r in catalog()}


def title(rule_id: str) -> str:
    return TITLES.get(rule_id, rule_id)

_ORDER = {ERROR: 0, WARNING: 1, INFO: 2}
_MARK = {ERROR: "✖", WARNING: "▲", INFO: "·"}


def render_text(report, verbose: bool = False) -> str:
    lines = [f"== {report.task_dir}"]
    b = report.bundle
    lines.append(f"   bundle: input={b.get('input_workbooks')} gold={b.get('gold_workbook')} rubric={b.get('rubric')} "
                 f"script={b.get('script')} audio={b.get('audio')} sota={b.get('sota_output')}")
    if b.get("unclassified"):
        lines.append(f"   unclassified: {b['unclassified']}")
    by_rule = defaultdict(list)
    for f in report.findings:
        by_rule[f.rule].append(f)
    for rule in sorted(by_rule, key=lambda r: (min(_ORDER[f.severity] for f in by_rule[r]), r)):
        for f in sorted(by_rule[rule], key=lambda f: _ORDER[f.severity]):
            loc = " ".join(x for x in (f.file, f.location) if x)
            lines.append(f" {_MARK[f.severity]} [{f.severity}] {title(f.rule)}{' | ' + loc if loc else ''}: {f.message}")
            if f.evidence and (verbose or f.severity != INFO):
                lines.append(f"       {f.evidence[:300]}")
    if report.skipped:
        lines.append("   skipped: " + "; ".join(f"{title(r)} ({why})" for r, why in report.skipped))
    lines.append(f"   summary: {report.count(ERROR)} errors, {report.count(WARNING)} warnings, {report.count(INFO)} info -> {'PASS' if report.ok else 'FAIL'}")
    return "\n".join(lines)


def render_json(reports) -> str:
    return json.dumps([r.to_dict() for r in reports], indent=2, default=str)


def render_summary(reports) -> str:
    rows = [("task", "errors", "warnings", "info", "result")]
    for r in reports:
        rows.append((r.task_dir, str(r.count(ERROR)), str(r.count(WARNING)), str(r.count(INFO)), "PASS" if r.ok else "FAIL"))
    w = [max(len(row[i]) for row in rows) for i in range(5)]
    return "\n".join("  ".join(c.ljust(w[i]) for i, c in enumerate(row)) for row in rows)
