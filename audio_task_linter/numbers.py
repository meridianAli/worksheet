"""Parsing numbers, tolerances and cell references out of rubric prose."""
from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Optional

# $16,164.7  ($535.3)  4.0%  1.39x  4.33x  0  -12.5  2,928.8
_NUM = r"\(?-?\$?\s?\d{1,3}(?:,\d{3})*(?:\.\d+)?|\(?-?\$?\s?\d+(?:\.\d+)?"
NUMBER_RE = re.compile(
    rf"(?<![A-Za-z0-9_.#])(?P<neg_open>\()?(?P<sign>-)?\$?\s?(?P<num>\d{{1,3}}(?:,\d{{3}})+(?:\.\d+)?|\d+(?:\.\d+)?)"
    rf"(?P<suffix>%|\s?percentage points|\s?percent(?!age)|x|X|\s?pp|\s?bps|\s?bn|\s?mm|\s?m|\s?k)?(?P<neg_close>\))?"
)

TOLERANCE_RE = re.compile(
    r"(?:within|of|to|by)?\s*(?:\+/-|\+-|±|\+ ?/ ?-|plus or minus)\s*"
    r"(?P<val>\d+(?:\.\d+)?)\s*(?P<unit>percentage points?|percent|%|pp|bps|x)?",
    re.IGNORECASE,
)
# "within 2%" without the +/-
TOLERANCE_WITHIN_RE = re.compile(
    r"within\s+(?P<val>\d+(?:\.\d+)?)\s*(?P<unit>percentage points?|percent|%|pp|bps|x)?(?![\w%])(?!\s*of\s+\d)",
    re.IGNORECASE,
)

# A1-style references: D42, $D$42, AB5, Y26:Z30. Quarter/half/FY labels excluded.
CELL_REF_RE = re.compile(
    r"(?<![A-Za-z0-9_#$/])(?:\$?[A-Z]{1,3}\$?\d{1,6})(?::\$?[A-Z]{1,3}\$?\d{1,6})?(?![A-Za-z0-9_])"
)
_CELL_REF_FALSE_POSITIVES = re.compile(r"^(?:Q[1-4]|H[12]|FY\d{2,4}|CY\d{2,4})$")
# "cell D42", "cells D42:D50", "row 12", "column D", "col F"
CELL_WORD_RE = re.compile(r"\b(?:cells?)\s+\$?[A-Z]{1,3}\$?\d{1,6}\b", re.IGNORECASE)
ROW_COL_RE = re.compile(r"\b(?:[Rr]ows?\s+\d{1,6}\b|[Cc]olumns?\s+\$?[A-Z]{1,3}\b(?![a-z])|[Cc]ol\.?\s+\$?[A-Z]{1,3}\b(?![a-z]))")

EXCEL_FUNCTIONS = (
    "SUMIFS", "SUMIF", "VLOOKUP", "HLOOKUP", "XLOOKUP", "INDEX", "MATCH", "OFFSET", "IFERROR",
    "SUMPRODUCT", "AVERAGEIFS", "AVERAGEIF", "COUNTIFS", "COUNTIF", "INDIRECT", "CHOOSE", "EOMONTH",
    "EDATE", "PMT", "IPMT", "PPMT", "XNPV", "XIRR", "MIRR", "CONCATENATE", "TEXTJOIN", "ROUNDUP",
    "ROUNDDOWN", "MROUND", "TRANSPOSE", "FILTER", "UNIQUE", "SEQUENCE", "LET", "LAMBDA", "IFS",
    "SWITCH", "AGGREGATE", "SUBTOTAL", "YEARFRAC", "DATEDIF", "NETWORKDAYS", "WORKDAY",
)
EXCEL_FUNC_RE = re.compile(r"\b(" + "|".join(EXCEL_FUNCTIONS) + r")\b(?:\s*\()?")
EXCEL_FUNC_PROSE_RE = re.compile(
    r"\b(?:use|using|with|via|through|an?)\s+(?:an?\s+)?(" + "|".join(EXCEL_FUNCTIONS) + r"|SUM|IF|MAX|MIN|AND|OR)\b"
)

ERROR_VALUES = ("#REF!", "#DIV/0!", "#VALUE!", "#N/A", "#NAME?", "#NUM!", "#NULL!", "#SPILL!", "#CALC!")


@dataclass
class Num:
    value: float
    raw: str
    unit: str = ""      # "%", "x", "pp", "bps", ""
    start: int = 0
    end: int = 0

    @property
    def is_percent(self) -> bool:
        return self.unit == "%"


def parse_number(token: str) -> Optional[Num]:
    m = NUMBER_RE.search(token)
    if not m:
        return None
    return _num_from_match(m)


def _num_from_match(m: re.Match) -> Num:
    val = float(m.group("num").replace(",", ""))
    neg = bool(m.group("sign")) or (bool(m.group("neg_open")) and bool(m.group("neg_close")))
    if neg:
        val = -val
    suffix = (m.group("suffix") or "").strip().lower()
    unit = {"%": "%", "percent": "%", "x": "x", "percentage points": "pp", "pp": "pp", "bps": "bps"}.get(suffix, "")
    return Num(val, m.group(0), unit, m.start(), m.end())


_TOL_PREFIX_RE = re.compile(r"(?:\+\s?/\s?-?|±|\+-|-/\+|plus or minus|within)\s*$", re.IGNORECASE)


def is_tolerance_number(n: "Num", text: str) -> bool:
    """True when the number is the magnitude of a tolerance band (preceded by +/-, ±, 'within')."""
    return bool(_TOL_PREFIX_RE.search(text[max(0, n.start - 16):n.start]))


def find_numbers(text: str, skip_tolerances: bool = True) -> list[Num]:
    """All numeric tokens in text, skipping years (1990-2100), quarter labels and tolerance magnitudes."""
    out = []
    for m in NUMBER_RE.finditer(text):
        n = _num_from_match(m)
        raw = n.raw.strip()
        if skip_tolerances and is_tolerance_number(n, text):
            continue
        # skip years and things like "Q3 2023", "2028", "September 30, 2023"
        if n.unit == "" and 1900 <= abs(n.value) <= 2100 and re.fullmatch(r"\d{4}", raw):
            pre = text[max(0, m.start() - 12):m.start()]
            post = text[m.end():m.end() + 8]
            if re.search(r"(?:\bin|\bfor|\bby|\bof|\bthrough|\bto|FY|CY|Q[1-4]|H[12]|\bexit|\byear|\b(?:jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\.?\s*\d{0,2},?)\s*$", pre, re.I) \
                    or re.match(r"\s*(?:E|A|P|exit|EBITDA|revenue|through|to|-|–)", post, re.I) or re.search(r"(?:19|20)\d{2}\D{1,12}$", pre):
                continue
        # skip ordinal-ish tokens directly after Q/H/FY
        pre = text[max(0, m.start() - 2):m.start()]
        if re.search(r"(?:Q|H|FY|CY)$", pre, re.IGNORECASE):
            continue
        out.append(n)
    return out


def find_tolerances(text: str) -> list[dict]:
    """Every tolerance band stated in the text. Returns dicts {value, unit, kind}."""
    found = []
    spans = []
    for m in TOLERANCE_RE.finditer(text):
        found.append(_tol_from_match(m))
        spans.append(m.span())
    for m in TOLERANCE_WITHIN_RE.finditer(text):
        if any(s <= m.start() < e for s, e in spans):
            continue
        found.append(_tol_from_match(m))
    return found


def _tol_from_match(m: re.Match) -> dict:
    unit = (m.group("unit") or "").lower()
    val = float(m.group("val"))
    if unit in ("%", "percent"):
        kind = "relative"
    elif unit.startswith("percentage") or unit == "pp":
        kind = "absolute_pp"
    elif unit == "bps":
        kind, val = "absolute_pp", val / 100.0
    else:
        kind = "absolute"
    return {"value": val, "unit": unit, "kind": kind, "raw": m.group(0).strip()}


def find_cell_refs(text: str) -> list[str]:
    refs = []
    for m in CELL_REF_RE.finditer(text):
        tok = m.group(0)
        head = tok.split(":")[0].replace("$", "")
        if _CELL_REF_FALSE_POSITIVES.match(head):
            # keep obvious cell-ish ones like "B12" only when preceded by the word cell
            continue
        refs.append(tok)
    for m in CELL_WORD_RE.finditer(text):
        refs.append(m.group(0))
    for m in ROW_COL_RE.finditer(text):
        refs.append(m.group(0))
    # de-dupe preserving order
    seen, out = set(), []
    for r in refs:
        if r.lower() not in seen:
            seen.add(r.lower())
            out.append(r)
    return out


def find_excel_functions(text: str) -> list[str]:
    hits = [m.group(1) for m in EXCEL_FUNC_RE.finditer(text)]
    hits += [m.group(1) for m in EXCEL_FUNC_PROSE_RE.finditer(text)]
    seen, out = set(), []
    for h in hits:
        if h not in seen:
            seen.add(h)
            out.append(h)
    return out


def within(observed: float, target: float, tol: Optional[dict]) -> bool:
    if tol is None:
        tol = {"kind": "relative", "value": 2.0}
    if tol["kind"] == "relative":
        if target == 0:
            return abs(observed) <= 0.005
        return abs(observed - target) <= abs(target) * tol["value"] / 100.0
    return abs(observed - target) <= tol["value"]
