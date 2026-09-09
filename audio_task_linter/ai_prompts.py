"""Emit the LLM review prompt for the ai-lint rules (S007-S010) with the task's own text inlined."""
from __future__ import annotations

from .bundle import read_text

TEMPLATE = """You are QC-reviewing one multimodal audio finance task. Answer ONLY the checks below, as JSON:
{{"S007": [...], "S008": [...], "S009": [...], "S010": [...]}} where each list holds findings
{{"criterion_id" or "instruction": str, "verdict": str, "evidence": str, "fix": str}}.

S007 Rubric <-> script anchoring. For EVERY criterion decide Explicit / Inferrable / Anchored: could a competent
analyst who only heard the script (and saw the input workbook tabs listed below) know they must produce exactly this
tab, line item, label, format or mechanic? Anchored = unfair; propose loosen / add-to-script / delete.
S008 Script <-> gold fidelity. Instructions the gold does not implement, and gold sections the script never cues.
S009 Coverage. Deliverables the script asks for that no criterion tests (upstream items and other years are fine).
S010 PII. Real private companies or people in script, rubric or tab names.

INPUT WORKBOOK TABS: {input_tabs}
GOLD WORKBOOK TABS: {gold_tabs}

=== SCRIPT ===
{script}

=== RUBRIC ===
{rubric}
"""


def build_prompt(ctx) -> str:
    return TEMPLATE.format(
        input_tabs=", ".join(t for w in ctx.inputs for t in w.sheets) or "(none)",
        gold_tabs=", ".join(ctx.gold.sheets) if ctx.gold else "(none)",
        script=ctx.script.strip() or "(missing)",
        rubric=read_text(ctx.bundle.rubric).strip() if ctx.bundle.rubric else "(missing)",
    )
