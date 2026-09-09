import pytest

from audio_task_linter.numbers import find_cell_refs, find_numbers, find_tolerances, find_excel_functions, within


@pytest.mark.parametrize("text,expected", [
    ("Does cell D42 on the Model sheet equal 5?", ["D42", "cell D42"]),
    ("Is Y26 blue and AB5 bold?", ["Y26", "AB5"]),
    ("Does row 12 sum to zero?", ["row 12"]),
    ("Is column F formatted as a percentage?", ["column F"]),
    ("Does the range B4:D7 hold the case assumptions?", ["B4:D7"]),
])
def test_cell_refs_detected(text, expected):
    assert find_cell_refs(text) == expected


@pytest.mark.parametrize("text", [
    "Does Total Revenue for Q3 2023 through Q4 2028 equal $16,164.7?",
    "Does FY25 EBITDA equal 4.33x interest (within +/-2%)?",
    "Is the orange hex code #EB8521 used for the line chart?",
    "Does the SOFR curve start in H1 2024?",
    "Does 2028 IRR equal 10.8% (within +/-0.5 percentage points)?",
])
def test_cell_refs_no_false_positives(text):
    assert find_cell_refs(text) == []


def test_numbers_skip_tolerances_years_and_quarters():
    t = "If Case Number on the Inputs sheet is changed from 1 to 3, does Consolidated EBITDA for 2028 update to $1,174.9 (within +/-2%)?"
    vals = [n.value for n in find_numbers(t)]
    assert vals == [1, 3, 1174.9]


def test_negative_parenthesised_and_percent():
    nums = find_numbers("do Cash Taxes for 2028 update to ($535.3) and IRR to 14.8% (within +/-0.5 percentage points)?")
    assert [n.value for n in nums] == [-535.3, 14.8]
    assert nums[1].is_percent


def test_tolerances():
    tols = find_tolerances("equal 8 (+/-2%) and 1.39x (within +/- 0.05) and 10.8% (within +/-0.5 percentage points)")
    assert [t["kind"] for t in tols] == ["relative", "absolute", "absolute_pp"]
    assert [t["value"] for t in tols] == [2.0, 0.05, 0.5]


def test_within():
    assert within(1000, 1010, {"kind": "relative", "value": 2})
    assert not within(1000, 1030, {"kind": "relative", "value": 2})
    assert within(0.108, 0.11, {"kind": "absolute", "value": 0.005})
    assert not within(0.1, 0, {"kind": "relative", "value": 2})


def test_excel_functions():
    assert find_excel_functions("Does the lookup use an XLOOKUP against the SOFR tab?") == ["XLOOKUP"]
    assert find_excel_functions("Does the sum of revenue equal 5?") == []
