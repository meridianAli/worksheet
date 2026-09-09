"""Rule registry. Each rule module exposes RULES (list[RuleInfo]) and run(ctx, report)."""
from __future__ import annotations

from . import rubric_rules, gold_rules, script_rules, bundle_rules

MODULES = (bundle_rules, rubric_rules, script_rules, gold_rules)


def catalog():
    out = []
    for m in MODULES:
        out.extend(m.RULES)
    return out
