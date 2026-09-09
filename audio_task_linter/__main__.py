from __future__ import annotations

import argparse
import sys
import tempfile
from pathlib import Path

from . import __version__
from .bundle import discover
from .context import Context
from .findings import Report, Finding, WARNING, INFO
from .report import render_json, render_summary, render_text
from .rules import MODULES, catalog


def lint_dir(task_dir: Path, recalc: bool = True, work_dir: Path | None = None, overrides: dict | None = None) -> Report:
    bundle = discover(task_dir, overrides)
    work_dir = Path(work_dir or tempfile.mkdtemp(prefix="atl-"))
    ctx = Context(bundle=bundle, work_dir=work_dir, recalc=recalc)
    report = Report(task_dir=str(task_dir), bundle=bundle.to_dict())
    for mod in MODULES:
        try:
            mod.run(ctx, report)
        except Exception as e:  # keep linting other rule sets
            report.add(Finding(mod.__name__.rsplit(".", 1)[-1], WARNING, f"rule module crashed: {type(e).__name__}: {e}"))
    for err in ctx.errors:
        report.add(Finding("LOAD", WARNING, err))
    for note in ctx.notes:
        report.add(Finding("LOAD", INFO, note))
    return report


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(prog="audio_task_linter", description=__doc__)
    ap.add_argument("--version", action="version", version=__version__)
    sub = ap.add_subparsers(dest="cmd", required=True)

    l = sub.add_parser("lint", help="lint one or more task directories")
    l.add_argument("task_dirs", nargs="+", type=Path)
    l.add_argument("--json", action="store_true", help="emit JSON instead of text")
    l.add_argument("--summary", action="store_true", help="one line per task")
    l.add_argument("--no-recalc", action="store_true", help="skip LibreOffice perturbation recalculation")
    l.add_argument("--work-dir", type=Path, default=None)
    l.add_argument("--rubric", type=Path, help="override rubric file")
    l.add_argument("--gold", type=Path, help="override gold workbook")
    l.add_argument("--input", type=Path, action="append", help="override input workbook(s)")
    l.add_argument("--script", type=Path, help="override script file")
    l.add_argument("-v", "--verbose", action="store_true")

    sub.add_parser("rules", help="print the rule catalog")
    a = sub.add_parser("ai-prompts", help="print the LLM review prompt for the ai-lint rules")
    a.add_argument("task_dir", type=Path)

    args = ap.parse_args(argv)
    if args.cmd == "rules":
        for r in catalog():
            print(f"{r.id}  {r.severity:7s} {r.mode:13s} {r.title}\n        {r.description}")
        return 0
    if args.cmd == "ai-prompts":
        from .ai_prompts import build_prompt
        ctx = Context(bundle=discover(args.task_dir), work_dir=Path(tempfile.mkdtemp()), recalc=False)
        print(build_prompt(ctx))
        return 0

    overrides = {"rubric": args.rubric, "gold_workbook": args.gold, "script": args.script,
                 "input_workbooks": args.input}
    reports = []
    for d in args.task_dirs:
        if not d.is_dir():
            print(f"not a directory: {d}", file=sys.stderr)
            return 2
        reports.append(lint_dir(d, recalc=not args.no_recalc, work_dir=args.work_dir, overrides=overrides))
    if args.json:
        print(render_json(reports))
    elif args.summary:
        print(render_summary(reports))
    else:
        print("\n\n".join(render_text(r, args.verbose) for r in reports))
        if len(reports) > 1:
            print("\n" + render_summary(reports))
    return 0 if all(r.ok for r in reports) else 1


if __name__ == "__main__":
    sys.exit(main())
