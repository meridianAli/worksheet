from __future__ import annotations

from dataclasses import dataclass, field, asdict
from typing import Optional

ERROR = "error"
WARNING = "warning"
INFO = "info"
SEVERITIES = (ERROR, WARNING, INFO)


@dataclass
class Finding:
    rule: str
    severity: str
    message: str
    file: Optional[str] = None
    location: Optional[str] = None      # e.g. "Perturbation #3" or "Model!D42"
    evidence: Optional[str] = None

    def to_dict(self) -> dict:
        from .report import title
        d = {k: v for k, v in asdict(self).items() if v is not None}
        d["check"] = title(self.rule)
        return d


@dataclass
class RuleInfo:
    id: str
    title: str
    severity: str
    mode: str          # "deterministic" | "ai-lint" | "manual"
    needs: tuple = ()  # bundle pieces required: rubric, gold, input, script, audio, sota
    description: str = ""


@dataclass
class Report:
    task_dir: str
    findings: list = field(default_factory=list)
    skipped: list = field(default_factory=list)   # (rule_id, reason)
    bundle: dict = field(default_factory=dict)

    def add(self, f: Finding) -> None:
        self.findings.append(f)

    def skip(self, rule_id: str, reason: str) -> None:
        self.skipped.append((rule_id, reason))

    def count(self, severity: str) -> int:
        return sum(1 for f in self.findings if f.severity == severity)

    @property
    def ok(self) -> bool:
        return self.count(ERROR) == 0

    def to_dict(self) -> dict:
        return {
            "task_dir": self.task_dir,
            "bundle": self.bundle,
            "summary": {s: self.count(s) for s in SEVERITIES},
            "findings": [f.to_dict() for f in self.findings],
            "skipped": [{"rule": r, "check": __import__("audio_task_linter.report", fromlist=["title"]).title(r), "reason": why} for r, why in self.skipped],
        }
