from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .bundle import Bundle, read_text
from .rubric import Rubric, load_rubric
from .workbook import Workbook, load_workbook


@dataclass
class Context:
    bundle: Bundle
    work_dir: Path
    recalc: bool = True
    max_points: float = 5.0
    max_pitfall_points: float = 10.0
    min_criteria: int = 10
    _rubric: Optional[Rubric] = None
    _gold: Optional[Workbook] = None
    _inputs: Optional[list] = None
    _script: Optional[str] = None
    errors: list = field(default_factory=list)
    notes: list = field(default_factory=list)

    @property
    def rubric(self) -> Optional[Rubric]:
        if self._rubric is None and self.bundle.rubric:
            try:
                self._rubric = load_rubric(self.bundle.rubric)
            except Exception as e:  # pragma: no cover
                self.errors.append(f"rubric: {e}")
        return self._rubric

    @property
    def gold(self) -> Optional[Workbook]:
        if self._gold is None and self.bundle.gold_workbook and self.bundle.gold_workbook.suffix.lower() in (".xlsx", ".xlsm"):
            try:
                self._gold = load_workbook(self.bundle.gold_workbook)
            except Exception as e:
                self.errors.append(f"gold workbook: {e}")
                return None
            self._gold = self._ensure_cached_values(self._gold)
        return self._gold

    def _ensure_cached_values(self, wb: Workbook) -> Workbook:
        """A workbook saved by a library (not Excel) carries formulas but no cached values; recalc it."""
        formulas = [c for c in wb.formula_cells()]
        if not formulas or any(c.value is not None for c in formulas):
            return wb
        from . import recalc
        if not recalc.engine():
            self.errors.append("gold workbook has formulas without cached values and no recalc engine is available; value checks will be blind")
            return wb
        try:
            out = recalc.perturb_and_recalc(wb.path, {}, Path(self.work_dir) / "gold_recalc")
            fresh = load_workbook(out)
            fresh.path = wb.path
            fresh.sha256 = wb.sha256
            self.notes.append("gold workbook had no cached values (not saved by Excel); values were recalculated")
            return fresh
        except Exception as e:
            self.errors.append(f"gold recalculation failed: {e}")
            return wb

    @property
    def inputs(self) -> list:
        if self._inputs is None:
            self._inputs = []
            for p in self.bundle.input_workbooks:
                if p.suffix.lower() in (".xlsx", ".xlsm"):
                    try:
                        self._inputs.append(load_workbook(p))
                    except Exception as e:
                        self.errors.append(f"input workbook {p.name}: {e}")
        return self._inputs

    @property
    def script(self) -> str:
        if self._script is None:
            self._script = read_text(self.bundle.script) if self.bundle.script else ""
        return self._script

    def rel(self, p) -> str:
        try:
            return str(Path(p).relative_to(self.bundle.root))
        except Exception:
            return str(p)
