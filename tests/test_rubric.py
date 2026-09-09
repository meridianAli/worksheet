import json

from audio_task_linter.rubric import parse_text, parse_json

TEXT = """Output Validation
- Does Total Revenue for 2028 equal $16,164.7 (within +/-2%)?+3
- Does Net Debt for 2028 equal $147.0 (within +/-2%)? +5
- Is Equity Distributions exactly 0 for 2028 (and every year)? [+5]

Perturbation
- If Case Number on the Inputs sheet is changed from 1 (Base Case) to 3 (Bear Case), does Consolidated EBITDA on the Output sheet for 2028 update to $1,174.9 (within +/-2%)?+5

Presentation
- Are the revenue growth rate % and ebitda margin % line charts dotted lines? \\[+6\\]

Pitfalls
- Are there any error values (#REF!, #DIV/0!, #VALUE!, #NAME?, #N/A, #NUM!) on the Output sheet?-10
- Is any data or label text truncated on the Transaction sheet? -7
"""


def test_parse_text_sections_and_points():
    r = parse_text(TEXT)
    assert [s.name for s in r.sections] == ["Output Validation", "Perturbation", "Presentation", "Pitfalls"]
    ov = r.by_section("Output Validation")
    assert [c.points for c in ov] == [3, 5, 5]
    assert all(c.text.endswith("?") for c in r.all())
    assert [c.points for c in r.by_section("Pitfalls")] == [-10, -7]
    assert r.by_section("Presentation")[0].points == 6


def test_perturbation_parse():
    r = parse_text(TEXT)
    p = r.by_section("Perturbation")[0].parse_perturbation()
    assert p["from_num"].value == 1 and p["to_num"].value == 3
    assert p["target_num"].value == 1174.9
    assert "Inputs" in p["input"] and "Output sheet" in p["output"]
    assert p["tolerances"][0]["kind"] == "relative"


def test_sheet_names():
    r = parse_text(TEXT)
    assert r.by_section("Perturbation")[0].sheet_names() == ["Inputs", "Output"]
    assert r.by_section("Pitfalls")[1].sheet_names() == ["Transaction"]


def test_parse_json_shapes():
    obj = {"sections": [
        {"name": "output_validation", "criteria": [{"id": "ov1", "text": "Does X equal 5 (+/-2%)?", "points": 3}]},
        {"name": "pitfalls", "criteria": [{"id": "pf1", "criterion": "Any #REF! errors?", "score": -5}]},
    ]}
    r = parse_json(obj)
    assert [s.name for s in r.sections] == ["Output Validation", "Pitfalls"]
    assert r.all()[0].id == "ov1" and r.all()[0].points == 3
    assert r.all()[1].points == -5
    flat = parse_json([{"section": "Perturbation", "text": "If A is changed from 1 to 2, does B update to 3 (+/-2%)?", "points": 5}])
    assert flat.by_section("Perturbation")[0].points == 5
