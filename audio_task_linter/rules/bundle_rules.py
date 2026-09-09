"""X*** bundle completeness and A*** audio checks."""
from __future__ import annotations

import re

from ..findings import Finding, RuleInfo, ERROR, WARNING, INFO

RULES = [
    RuleInfo("X001", "All 5 bundle pieces present", ERROR, "deterministic", (),
             "Input workbook, gold workbook, rubric, script and audio recording are all present."),
    RuleInfo("X002", "Input workbook differs from gold", ERROR, "deterministic", ("input", "gold"),
             "Gold must differ from the input (hash + cell diff); a byte-identical pair means the wrong file shipped."),
             "File names should follow the scrubbed convention (e.g. Meridian-<id>-input) with no private company or person names."),
             "If the script mentions a SOFR curve, source data, deck or PDF, a matching supporting file must be in the bundle."),
    RuleInfo("A001", "Audio is a real, decodable recording", ERROR, "deterministic", ("audio",),
             "Supported extension, non-trivial size, and (when mutagen is installed) a decodable duration."),
             "Speech runs ~110-200 words/min; a recording far outside that for the script's word count is truncated, padded or the wrong file."),
             "Listen to the first 20 seconds. No deterministic check; flagged for the reviewer."),
]



def run(ctx, report):
    b = ctx.bundle
    remote = b.remote_fields()
    missing, remote_only = [], []
    for present, label, field in ((b.input_workbooks, "input workbook", "markup_workbook"), (b.gold_workbook, "gold output workbook", "golden_output_workbook"),
                                  (b.rubric, "rubric", "rubric"), (b.script, "script / prompt", "prompt"), (b.audio, "audio recording", "audio_recording")):
        if present:
            continue
        (remote_only if field in remote else missing).append(label)
    if missing:
        report.add(Finding("X001", ERROR, "Bundle is missing: " + ", ".join(missing),
                           evidence="classified: " + ", ".join(f"{k}={v}" for k, v in b.to_dict().items() if v)))
    if remote_only:
        report.add(Finding("X001", INFO, "Present on the platform but not downloaded (binary checks skipped): " + ", ".join(remote_only)))
    if not b.sota_output:
        report.add(Finding("X001", INFO, "No SOTA 'Solved' output in bundle; model-fault vs task-fault review will be skipped."))

    # X002
    if b.input_workbooks and b.gold_workbook and ctx.gold:
        for inp in ctx.inputs:
            if inp.sha256 == ctx.gold.sha256:
                report.add(Finding("X002", ERROR, "Input workbook is byte-identical to the gold workbook.",
                                   file=ctx.rel(inp.path)))
                continue
            same = sum(1 for k, c in inp.cells.items() if k in ctx.gold.cells and ctx.gold.cells[k].value == c.value and ctx.gold.cells[k].formula == c.formula)
            total = max(len(inp.cells), len(ctx.gold.cells), 1)
            diff = 1 - same / total
            if diff < 0.005:
                report.add(Finding("X002", ERROR, f"Input and gold differ in only {diff:.2%} of populated cells; the task has almost no work in it.",
                                   file=ctx.rel(inp.path)))
            elif diff < 0.03:
                report.add(Finding("X002", WARNING, f"Input and gold differ in only {diff:.2%} of populated cells.", file=ctx.rel(inp.path)))

    # A001
    for a in b.audio:
        size = a.stat().st_size
        if size < 50_000:
            report.add(Finding("A001", ERROR, f"Audio file is only {size} bytes; not a usable recording.", file=ctx.rel(a)))
            continue
        dur = _duration(a)
        if dur is None:
            report.add(Finding("A001", INFO, "Could not read audio duration (install `mutagen` for duration checks).", file=ctx.rel(a)))
        elif dur < 45:
            report.add(Finding("A001", ERROR, f"Audio is {dur:.0f}s long; too short to carry an MD/VP debrief.", file=ctx.rel(a)))


def _duration(path):
    try:
        import mutagen  # type: ignore
    except ImportError:
        return None
    try:
        f = mutagen.File(path)
        return float(f.info.length) if f and f.info else None
    except Exception:
        return None
