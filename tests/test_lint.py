import pytest

from audio_task_linter import recalc
from audio_task_linter.__main__ import lint_dir
from fixtures import build_bundle


def rule_ids(report, severity=None):
    return {f.rule for f in report.findings if severity is None or f.severity == severity}


def test_good_bundle_passes(tmp_path):
    root = build_bundle(tmp_path / "good", good=True)
    rep = lint_dir(root, recalc=True, work_dir=tmp_path / "work")
    assert rep.ok, [f.__dict__ for f in rep.findings if f.severity == "error"]
    assert rule_ids(rep, "warning") == set()


def test_bad_bundle_flags_every_planted_defect(tmp_path):
    root = build_bundle(tmp_path / "bad", good=False, hints=True)
    rep = lint_dir(root, recalc=recalc.engine() is not None, work_dir=tmp_path / "work")
    assert not rep.ok
    errors = rule_ids(rep, "error")
    expected_errors = {"R001", "R002", "R003", "R004", "R006", "R008", "R009", "S004", "G005", "I001"}
    assert expected_errors <= errors, expected_errors - errors
    warnings = rule_ids(rep, "warning")
    expected_warnings = {"R005", "R010", "R011", "R012", "R013", "R014", "I002"}
    assert expected_warnings <= warnings, expected_warnings - warnings


@pytest.mark.skipif(recalc.engine() is None, reason="no recalculation engine (libreoffice-calc or `formulas`)")
def test_perturbations_are_recalculated(tmp_path):
    root = build_bundle(tmp_path / "bad", good=False, hints=True)
    rep = lint_dir(root, recalc=True, work_dir=tmp_path / "work")
    p001_errors = [f for f in rep.findings if f.rule == "P001" and f.severity == "error"]
    # P-1 wrong target, P-2 no-op perturbation, P-4 wrong target
    assert {f.location for f in p001_errors} == {"PT-1", "PT-2", "PT-4"}
    assert any(f.rule == "P002" and f.location == "PT-5" for f in rep.findings)


def test_missing_pieces_reported(tmp_path):
    root = tmp_path / "empty"
    root.mkdir()
    (root / "rubric.md").write_text("Output Validation\n- Does X equal 5 (+/-2%)? +3\n")
    rep = lint_dir(root, recalc=False, work_dir=tmp_path / "work")
    x001 = [f for f in rep.findings if f.rule == "X001" and f.severity == "error"]
    assert x001 and "audio recording" in x001[0].message and "gold output workbook" in x001[0].message
    assert any(f.rule == "S001" for f in rep.findings)


def test_json_output_roundtrip(tmp_path):
    root = build_bundle(tmp_path / "good", good=True)
    rep = lint_dir(root, recalc=False, work_dir=tmp_path / "work")
    d = rep.to_dict()
    assert d["summary"]["error"] == 0
    assert d["bundle"]["gold_workbook"] == "Meridian-abc123-gold-output.xlsx"
