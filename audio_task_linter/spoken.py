"""Numbers as they appear in a spoken script: digits ("21%", "$400") and words ("twenty-one percent")."""
from __future__ import annotations

import re

from .numbers import find_numbers

_UNITS = {"zero": 0, "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8,
          "nine": 9, "ten": 10, "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
          "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19, "a": 1, "an": 1}
_TENS = {"twenty": 20, "thirty": 30, "forty": 40, "fifty": 50, "sixty": 60, "seventy": 70, "eighty": 80, "ninety": 90}
_SCALES = {"hundred": 100, "thousand": 1_000, "million": 1_000_000, "billion": 1_000_000_000}
_FRACTIONS = {"half": 0.5, "quarter": 0.25, "third": 1 / 3}
_WORD = re.compile(r"[a-z]+|\d+(?:\.\d+)?|[,.;:()]", re.I)
_NUMBER_WORDS = set(_UNITS) | set(_TENS) | set(_SCALES) | {"and", "point", "hundred"} | set(_FRACTIONS)


def words_to_numbers(text: str) -> list[float]:
    """Extract spoken numbers: 'twenty-one percent' -> 21, 'four hundred' -> 400, 'thirteen and a half' -> 13.5,
    'five point two five' -> 5.25, 'a hundred and ten basis points' -> 110."""
    tokens = _WORD.findall(text.replace("-", " ").lower())
    out, i = [], 0
    while i < len(tokens):
        if tokens[i] not in _NUMBER_WORDS or tokens[i] in ("and", "a", "an", "point"):
            i += 1
            continue
        total, current, j, seen = 0.0, 0.0, i, False
        decimals = None
        while j < len(tokens):
            w = tokens[j]
            if decimals is not None:
                if w in _UNITS and w not in ("a", "an"):
                    decimals.append(str(_UNITS[w]))
                    j += 1
                    continue
                break
            if w in _UNITS and w not in ("a", "an"):
                current += _UNITS[w]; seen = True
            elif w in _TENS:
                current += _TENS[w]; seen = True
            elif w == "hundred":
                current = (current or 1) * 100; seen = True
            elif w in _SCALES:
                total += (current or 1) * _SCALES[w]; current = 0; seen = True
            elif w == "and":
                if j + 2 < len(tokens) and tokens[j + 1] in ("a", "an") and tokens[j + 2] in _FRACTIONS:
                    current += _FRACTIONS[tokens[j + 2]]; j += 3; seen = True
                    continue
                if not seen or current == 0 or current % 100 != 0:
                    break  # "five and six percent" are two numbers; only "hundred and ten" continues
            elif w == "point":
                if not seen:
                    break
                decimals = []
            elif w in ("a", "an"):
                if j + 1 < len(tokens) and (tokens[j + 1] in _SCALES or tokens[j + 1] == "hundred"):
                    current = 1
                else:
                    break
            else:
                break
            j += 1
        if seen:
            val = total + current
            if decimals:
                val += float("0." + "".join(decimals))
            out.append(val)
        i = max(j, i + 1)
    return out


def spoken_values(text: str) -> set[float]:
    """Every value a formula constant could legitimately have been taken from the script, with unit variants
    (5 -> 5, 0.05; 400 -> 400, 400000, 0.4). Rounded to 6 decimals."""
    vals = set()
    for v in [n.value for n in find_numbers(text, skip_tolerances=False)] + words_to_numbers(text):
        for x in (v, v / 100.0, 1 + v / 100.0, 1 - v / 100.0, v * 1000, v * 1_000_000, v / 1000.0, v / 10_000.0, -v):
            vals.add(round(x, 6))
    return vals
