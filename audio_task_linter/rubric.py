"""Parse a task rubric from markdown/plain text or JSON into sections of criteria."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from .numbers import find_numbers, find_tolerances, Num

CANONICAL_SECTIONS = {
    "output validation": "Output Validation",
    "output_validation": "Output Validation",
    "outputs": "Output Validation",
    "perturbation": "Perturbation",
    "perturbations": "Perturbation",
    "presentation": "Presentation",
    "formatting": "Presentation",
    "pitfalls": "Pitfalls",
    "pitfall": "Pitfalls",
    "model integration": "Model Integration",
    "model_integration": "Model Integration",
    "formula correctness": "Formula Correctness",
    "formula_correctness": "Formula Correctness",
    "logic": "Formula Correctness",
}
REQUIRED_SECTIONS = ("Output Validation", "Perturbation", "Presentation", "Pitfalls")
DECK_REQUIRED_SECTIONS = ("Presentation", "Pitfalls")
NEGATIVE_SECTIONS = ("Pitfalls",)
EITHER_SIGN_SECTIONS = ("Model Integration",)

# trailing points: "?+3", "? +5", "[+6]", "(-10)", "+5 pts", "— 5 points"
POINTS_RE = re.compile(
    r"(?:[\s–—:]*)(?:\[|\()?\s*(?P<pts>[+\-−]?\s?\d+(?:\.\d+)?)\s*(?:pts?|points?)?\s*(?:\]|\))?\s*$"
)
BULLET_RE = re.compile(r"^\s*(?:[-*•◦▪]|\d+[.)]|[a-z][.)]|\(?[ivx]+\))\s+", re.IGNORECASE)
HEADER_RE = re.compile(r"^\s*(?:#{1,6}\s*)?(?:\d+[.)]\s*)?(?:\*\*)?\s*(?P<name>[A-Za-z][A-Za-z /_&-]{2,40}?)\s*(?:\*\*)?\s*:?\s*(?:[(\[–—-]?\s*\d+\s*(?:pts?|points?)\)?\]?)?\s*$")

PERTURB_RE = re.compile(
    r"^\s*(?:if|when|with|after|once)\s+(?:only\s+)?(?P<input>.+?)\s+(?:is\s+|are\s+|were\s+|gets\s+)?(?P<verb>changed|switched|set|moved|updated|toggled|flipped|increased|decreased|raised|lowered|reduced|cut|doubled|halved|zeroed|removed)"
    r"(?:\s+(?:from\s+(?P<from>.+?)\s+)?(?:to|by)\s+(?P<to>.+?))?\s*,\s*(?:does|do|is|are|will|would)\s+(?P<output>.+?)\s+"
    r"(?:update|change|become|equal|move|flow|recalculate|result|go|shift|switch|now\s+equal|remain|stay|hold|still\s+equal|still\s+show|show|read|return|increase|decrease|rise|fall|drop|grow|decline)\w*"
    r"(?:\s+\w+ly)?(?:\s+(?:at|to|as|by|from\s+.+?\s+to))?(?:\s+(?:approximately|about|roughly|around|~))?\s+(?P<target>.+?)\??\s*$",
    re.IGNORECASE | re.DOTALL,
)
SHEET_REF_RE = re.compile(
    r"(?:on|in|of)\s+the\s+[\"'“]?(?P<name>[A-Z][\w &/\-\.]{0,40}?)[\"'”]?\s+(?:sheet|tab|worksheet)\b"
    r"|[\"'“](?P<qname>[^\"'”]{1,40})[\"'”]\s+(?:sheet|tab)\b"
    r"|\b(?P<name2>[A-Z][\w&/\-\.]{1,30})\s+(?:sheet|tab)\b",
)


@dataclass
class Criterion:
    id: str
    section: str
    text: str
    points: Optional[float]
    index: int                  # 1-based within section
    raw: str = ""

    @property
    def question(self) -> str:
        return self.text

    def numbers(self) -> list[Num]:
        return find_numbers(self.text)

    def tolerances(self) -> list[dict]:
        return find_tolerances(self.text)

    def sheet_names(self) -> list[str]:
        names = []
        for m in SHEET_REF_RE.finditer(self.text):
            n = m.group("name") or m.group("qname") or m.group("name2")
            if n and n.lower() not in ("the", "this", "that", "same", "new", "each", "every", "a", "an", "output", "input", "model", "inputs", "outputs"):
                names.append(n.strip())
            elif n and n.lower() in ("output", "input", "model", "inputs", "outputs", "new"):
                # "Output sheet" / "Inputs sheet" are real tab names in these tasks
                names.append(n.strip())
        seen, out = set(), []
        for n in names:
            if n.lower() not in seen:
                seen.add(n.lower())
                out.append(n)
        return out

    def parse_perturbation(self) -> Optional[dict]:
        m = PERTURB_RE.match(self.text.strip())
        if not m:
            return None
        d = {k: (v.strip() if v else None) for k, v in m.groupdict().items()}
        from .numbers import date_spans
        d["from_is_date"] = bool(d["from"] and date_spans(d["from"]))
        d["to_is_date"] = bool(d["to"] and date_spans(d["to"]))
        d["from_num"] = _first_num(d["from"]) if d["from"] else None
        d["to_num"] = _first_num(d["to"]) if d["to"] else None
        if d["to_num"] is None and (d.get("verb") or "").lower() in ("doubled", "halved", "zeroed", "removed"):
            d["to"] = d["verb"]
            d["to_num"] = Num({"doubled": 2.0, "halved": 0.5}.get(d["verb"].lower(), 0.0), d["verb"], "factor")
        if d["to_is_date"]:
            d["to_num"] = Num(0.0, d["to"], "date")
        if d["from_is_date"]:
            d["from_num"] = Num(0.0, d["from"], "date")
        d["target_num"] = _first_num(d["target"])
        d["tolerances"] = find_tolerances(self.text)
        return d


def _first_num(s: Optional[str]) -> Optional[Num]:
    if not s:
        return None
    nums = find_numbers(s)
    return nums[0] if nums else None


@dataclass
class Section:
    name: str
    criteria: list = field(default_factory=list)
    declared: bool = True   # header present in the source


@dataclass
class Rubric:
    sections: list = field(default_factory=list)
    source: str = ""
    fmt: str = "text"

    def all(self) -> list[Criterion]:
        return [c for s in self.sections for c in s.criteria]

    def section(self, name: str) -> Optional[Section]:
        for s in self.sections:
            if s.name == name:
                return s
        return None

    def by_section(self, name: str) -> list[Criterion]:
        s = self.section(name)
        return s.criteria if s else []

    @property
    def total_points(self) -> float:
        return sum(c.points for c in self.all() if c.points is not None and c.points > 0)


def canonical_section(name: str) -> Optional[str]:
    key = re.sub(r"[^a-z_ ]", "", name.strip().lower()).strip()
    key = re.sub(r"\s+", " ", key)
    if key in CANONICAL_SECTIONS:
        return CANONICAL_SECTIONS[key]
    for k, v in CANONICAL_SECTIONS.items():
        if key.startswith(k) or k.startswith(key) and len(key) >= 5:
            return v
    return None


def split_points(line: str) -> tuple[str, Optional[float]]:
    line = line.replace("\\[", "[").replace("\\]", "]").replace("\\(", "(").replace("\\)", ")")
    m = POINTS_RE.search(line)
    if not m:
        return line.strip(), None
    body = line[: m.start()].rstrip()
    pts_txt = m.group("pts").replace(" ", "").replace("−", "-")
    # Guard: don't eat a number that is part of the sentence (e.g. "... equal 0?"). Require the
    # body to end the question, or the points to carry a sign / brackets / pts word.
    signed = pts_txt[0] in "+-"
    bracketed = "[" in m.group(0) or "(" in m.group(0)
    worded = bool(re.search(r"pts?|points?", m.group(0)))
    if not (signed or bracketed or worded):
        return line.strip(), None
    if not signed and not worded and not body.rstrip().endswith("?"):
        return line.strip(), None
    if not body.endswith("?") and not (bracketed or worded):
        # "+3" glued to the sentence without a question mark before it: still accept
        pass
    return body.strip(), float(pts_txt)


def parse_text(text: str) -> Rubric:
    rubric = Rubric(fmt="text")
    current: Optional[Section] = None
    lines = text.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.strip()
        i += 1
        if not line:
            continue
        # section header?
        if "?" not in line and (not BULLET_RE.match(line) or canonical_section(re.sub(r"^\s*\d+[.)]\s*", "", line))):
            hm = HEADER_RE.match(line)
            if hm:
                canon = canonical_section(hm.group("name")) or hm.group("name").strip().strip("*#: ")
                current = Section(name=canon)
                rubric.sections.append(current)
                continue
        # criterion line (bullet or question). Allow continuation lines until a '?' or points appear.
        body = BULLET_RE.sub("", line)
        while ("?" not in body and i < len(lines) and lines[i].strip()
               and not BULLET_RE.match(lines[i]) and not HEADER_RE.match(lines[i].strip())):
            body += " " + lines[i].strip()
            i += 1
        # points may sit on the following line alone, e.g. "+5"
        if i < len(lines) and re.fullmatch(r"\s*(?:\[|\()?[+\-−]?\s?\d+(?:\.\d+)?\s*(?:pts?|points?)?(?:\]|\))?\s*", lines[i]):
            body += " " + lines[i].strip()
            i += 1
        text_, pts = split_points(body)
        text_ = re.sub(r"\\([#!*_\[\]()$])", r"\1", text_)
        if not text_:
            continue
        if current is None:
            current = Section(name="(unsectioned)", declared=False)
            rubric.sections.append(current)
        idx = len(current.criteria) + 1
        current.criteria.append(Criterion(
            id=f"{_abbr(current.name)}-{idx}", section=current.name, text=text_, points=pts, index=idx, raw=raw))
    return rubric


_ABBR = {"Output Validation": "OV", "Perturbation": "PT", "Presentation": "PR", "Pitfalls": "PF",
         "Model Integration": "MI", "Formula Correctness": "FC", "(unsectioned)": "UN"}


def _abbr(name: str) -> str:
    if name in _ABBR:
        return _ABBR[name]
    return "".join(w[0] for w in re.findall(r"[A-Za-z]+", name)).upper() or "X"


def parse_json(obj) -> Rubric:
    rubric = Rubric(fmt="json")
    sections: dict[str, Section] = {}

    def sec(name: str) -> Section:
        canon = canonical_section(name) or name
        if canon not in sections:
            sections[canon] = Section(name=canon)
            rubric.sections.append(sections[canon])
        return sections[canon]

    def add(section_name: str, item, fallback_id=None):
        s = sec(section_name)
        if isinstance(item, str):
            text_, pts = split_points(item)
            cid = fallback_id
        else:
            text_ = (item.get("text") or item.get("criterion") or item.get("description")
                     or item.get("question") or item.get("name") or "")
            pts = item.get("points", item.get("score", item.get("weight", item.get("value"))))
            if pts is None:
                text_, pts = split_points(text_)
            else:
                try:
                    pts = float(pts)
                except (TypeError, ValueError):
                    pts = None
            cid = item.get("id") or item.get("criterion_id") or fallback_id
        idx = len(s.criteria) + 1
        text_ = BULLET_RE.sub("", text_.strip())
        s.criteria.append(Criterion(id=str(cid or f"{_abbr(s.name)}-{idx}"), section=s.name,
                                    text=text_, points=pts, index=idx, raw=json.dumps(item)))

    if isinstance(obj, dict) and "sections" in obj:
        obj = obj["sections"]
    if isinstance(obj, dict) and "criteria" in obj and isinstance(obj["criteria"], list):
        for it in obj["criteria"]:
            add(it.get("section") or it.get("category") or "(unsectioned)", it)
    elif isinstance(obj, dict):
        for name, items in obj.items():
            if isinstance(items, list):
                for it in items:
                    add(name, it)
            elif isinstance(items, dict) and "criteria" in items:
                for it in items["criteria"]:
                    add(name, it)
    elif isinstance(obj, list):
        for entry in obj:
            if isinstance(entry, dict) and ("criteria" in entry or "items" in entry):
                name = entry.get("name") or entry.get("section") or entry.get("title") or "(unsectioned)"
                for it in entry.get("criteria") or entry.get("items") or []:
                    add(name, it)
            elif isinstance(entry, dict):
                add(entry.get("section") or entry.get("category") or "(unsectioned)", entry)
            else:
                add("(unsectioned)", entry)
    return rubric


def load_rubric(path: Path) -> Rubric:
    text = Path(path).read_text(encoding="utf-8", errors="replace")
    stripped = text.lstrip()
    if path.suffix.lower() == ".json" or stripped[:1] in "[{":
        try:
            rubric = parse_json(json.loads(text))
            rubric.source = str(path)
            return rubric
        except json.JSONDecodeError:
            pass
    rubric = parse_text(text)
    rubric.source = str(path)
    return rubric
