"""Ports of the remaining sheets delivery-scanner checks: author provenance, identifying info / PII,
task metadata, and (cross-task, applied in __main__) duplicate prompts."""
from __future__ import annotations

import json
import re
import zipfile
from pathlib import Path
from xml.etree import ElementTree as ET

from ..findings import Finding, RuleInfo, ERROR, WARNING, INFO

RULES = [
    RuleInfo("V003", "No emails, phones or company names in text", WARNING, "deterministic", ("gold", "input", "script", "rubric"),
             "Emails, phone numbers, and company-like names (Acme Holdings LLC) in cells, tab names, script or rubric. Scrubbed placeholders (Meridian, Project <codename>) are allowed. Author names in document properties are not checked."),
    RuleInfo("V005", "Script isn't a duplicate of another task's", ERROR, "deterministic", ("script",),
             "The script/prompt must not repeat another task's (exact or near-duplicate) within the same lint run or a supplied known-prompts file."),
]

_LLM_APPS = re.compile(r"openpyxl|xlsxwriter|pandas|python|google sheets|apache poi|closedxml|npoi|sheetjs|exceljs", re.I)
_AI_WORDS = re.compile(r"\b(chatgpt|gpt-?[45]|claude|copilot|gemini|openai|anthropic|as an ai|language model)\b", re.I)
_VENDORS = re.compile(r"macabacus|wall ?street ?prep|wsp\b|corporate finance institute|breaking into wall street|biws|asimplemodel|a simple model|efinancialmodels|eloquens|investopedia|mergers ?& ?inquisitions|downloaded from|free template", re.I)
_URL = re.compile(r"https?://|www\.[a-z0-9-]+\.[a-z]{2,}", re.I)
_COPYRIGHT = re.compile(r"©|\(c\)\s*20\d\d|copyright|all rights reserved", re.I)
_EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
_PHONE = re.compile(r"(?<!\d)(?:\+?1[\s.-]?)?\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}(?!\d)")
_COMPANY = re.compile(r"\b([A-Z][A-Za-z&'\.]+(?:\s+[A-Z][A-Za-z&'\.]+){0,3})\s+(Inc\.?|LLC|L\.L\.C\.|Ltd\.?|Limited|Corp\.?|Corporation|Co\.|Holdings|Partners|LP|L\.P\.|PLC|GmbH|S\.A\.|N\.V\.|AG|Bank|Capital|Group|Ventures|Industries|Enterprises|Technologies|Pharmaceuticals|Therapeutics)\b")
_ALLOW_TERMS = [
    r"meridian", r"project\s+[a-z]+", r"blackstone", r"sofr", r"libor", r"acme", r"newco", r"holdco", r"opco", r"bidco", r"topco",
    r"midco", r"target", r"sponsor", r"lender", r"company", r"the company",
    r"(?:net\s+)?working capital", r"(?:total|net|equity|debt|share|invested|paid[- ]in|regulatory|tier ?1|human)\s+capital",
    r"(?:weighted average )?cost of capital", r"return on capital",
    r"capital (?:expenditures?|structure|lease|markets?|gains?|call|reserve|ratio|base)", r"peer group", r"consolidated group",
    r"(?:bank|term|revolving) (?:debt|loan)", r"(?:the )?bank(?: debt| loan| balance)?", r"(?:base|bull|bear|management|downside|upside) case",
    r"holding company", r"operating company", r"limited partners?", r"general partners?", r"senior (?:notes|debt|secured)",
]
_ALLOW = re.compile(r"\b(" + "|".join(_ALLOW_TERMS) + r")\b", re.I)
_SSN = re.compile(r"(?<!\d)\d{3}-\d{2}-\d{4}(?!\d)")


def _docprops(path: Path) -> dict:
    out = {}
    try:
        with zipfile.ZipFile(path) as z:
            for name, tags in (("docProps/core.xml", ("creator", "lastModifiedBy", "title", "description")),
                               ("docProps/app.xml", ("Application", "Company", "Manager"))):
                if name in z.namelist():
                    root = ET.fromstring(z.read(name))
                    for el in root.iter():
                        tag = el.tag.split("}")[-1]
                        if tag in tags and el.text and el.text.strip():
                            out[tag] = el.text.strip()
    except (zipfile.BadZipFile, ET.ParseError, OSError):
        pass
    return out


def _text_cells(wb):
    for c in wb.cells.values():
        if isinstance(c.value, str) and not c.is_formula and c.value.strip():
            yield c


def run(ctx, report):
    books = [(w, ctx.rel(w.path)) for w in ([ctx.gold] if ctx.gold else []) + ctx.inputs]
    if not books:
        for rid in ("V003",):
            report.skip(rid, "no workbook")
    for wb, f in books:
        props = _docprops(wb.path)
        # V003 identifying info in workbook
        ident = []  # document-property author names are intentionally not reported
        names = set()
        for c in list(_text_cells(wb)) + [type("T", (), {"value": s, "ref": f"tab '{s}'"})() for s in wb.sheets]:
            v = c.value
            if _EMAIL.search(v) or _PHONE.search(v) or _SSN.search(v):
                ident.append(f"{c.ref} '{v[:40]}'")
            for m in _COMPANY.finditer(v):
                if not _ALLOW.search(m.group(0)):
                    names.add(m.group(0))
        if ident:
            report.add(Finding("V003", WARNING, f"Identifying info in workbook: {'; '.join(ident[:5])}", file=f))
        if names:
            report.add(Finding("V003", WARNING, f"Company-like names in workbook text (confirm public or scrubbed): {', '.join(sorted(names)[:8])}", file=f))
    # V003 in script and rubric text
    for label, text, f in (("script", ctx.script, ctx.rel(ctx.bundle.script) if ctx.bundle.script else None),
                           ("rubric", _rubric_text(ctx), ctx.rel(ctx.bundle.rubric) if ctx.bundle.rubric else None)):
        if not text:
            continue
        names = sorted({m.group(0) for m in _COMPANY.finditer(text) if not _ALLOW.search(m.group(0))})
        pii = _EMAIL.findall(text) + _PHONE.findall(text) + _SSN.findall(text)
        if pii:
            report.add(Finding("V003", ERROR, f"PII pattern in {label}: {', '.join(pii[:3])}", file=f))
        if names:
            report.add(Finding("V003", WARNING, f"Company-like names in {label} (confirm public or scrubbed): {', '.join(names[:8])}", file=f))


def _rubric_text(ctx) -> str:
    from ..bundle import read_text
    return read_text(ctx.bundle.rubric) if ctx.bundle.rubric else ""


def _formatting_share(path: Path):
    try:
        import openpyxl
        wb = openpyxl.load_workbook(path)
    except Exception:
        return None
    n = styled = 0
    for ws in wb.worksheets:
        for row in ws.iter_rows():
            for c in row:
                if c.value is None:
                    continue
                n += 1
                if (c.number_format and c.number_format != "General") or c.font.bold or (c.font.color is not None and getattr(c.font.color, "rgb", None) not in (None, "FF000000")) or c.fill.fgColor.rgb not in (None, "00000000"):
                    styled += 1
                if n > 20000:
                    return styled / n
    return styled / n if n else None


def _find_metadata(root: Path):
    for p in sorted(root.rglob("*")):
        if p.suffix.lower() == ".json" and re.search(r"task|meta", p.stem, re.I):
            try:
                d = json.loads(p.read_text())
                if isinstance(d, dict) and any(_get_ci(d, k) is not None or k in json.dumps(d).lower() for k in ("industry", "category")):
                    return p, d
            except (json.JSONDecodeError, OSError):
                pass
        if p.suffix.lower() == ".csv" and re.search(r"task|meta", p.stem, re.I):
            import csv
            try:
                rows = list(csv.DictReader(p.open()))
                if rows and any("industry" in k.lower() for k in rows[0]):
                    return p, rows[0]
            except OSError:
                pass
    return None


def _get_ci(d: dict, key: str):
    for k, v in d.items():
        if k.lower().replace("_", "").replace(" ", "") == key:
            return v if v not in ("", None) else None
    if isinstance(d.get("metadata"), dict):
        return _get_ci(d["metadata"], key)
    return None


# ---- cross-task: duplicate prompts -----------------------------------------------------------
def normalize_prompt(text: str) -> str:
    return re.sub(r"\W+", " ", text.lower()).strip()


def shingles(text: str, k: int = 8) -> set:
    w = normalize_prompt(text).split()
    return {" ".join(w[i:i + k]) for i in range(max(1, len(w) - k + 1))}


def check_duplicate_prompts(reports, scripts: dict, known: dict | None = None, threshold: float = 0.8):
    """scripts: {task_dir: script_text}; known: {label: script_text} from --known-prompts."""
    items = list(scripts.items()) + list((known or {}).items())
    sh = {k: shingles(v) for k, v in items if v and len(v.split()) >= 60}  # short platform prompts are boilerplate by design
    for rep in reports:
        mine = sh.get(rep.task_dir)
        if not mine:
            continue
        for other, s in sh.items():
            if other == rep.task_dir or not s:
                continue
            j = len(mine & s) / max(1, len(mine | s))
            if j >= threshold:
                sev = ERROR if j >= 0.98 else WARNING
                rep.add(Finding("V005", sev, f"Script is a {'verbatim' if j >= 0.98 else 'near'} duplicate ({j:.0%} shingle overlap) of {other}.",
                                file=rep.bundle.get("script")))
