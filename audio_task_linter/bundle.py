"""Discover and classify the files that make up one audio task bundle."""
from __future__ import annotations

import json
import re
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

AUDIO_EXT = {".m4a", ".mp3", ".wav", ".aac", ".ogg", ".flac", ".mp4", ".wma", ".webm"}
SHEET_EXT = {".xlsx", ".xlsm", ".xlsb", ".xls", ".csv"}
DOC_EXT = {".docx", ".doc", ".pdf", ".pptx", ".txt", ".md"}
RUBRIC_EXT = {".json", ".md", ".txt", ".docx"}

# Ordered most-specific first.
_ROLE_PATTERNS = [
    ("sota_selfgrade", re.compile(r"self[\s_-]?grade|selfgrade|self[\s_-]?assess|evaluations?\.json|sota[\s_-]?grade", re.I)),
    ("sota_output", re.compile(r"solved|sota|analyst[\s_-]?output|model[\s_-]?output|candidate", re.I)),
    ("rubric", re.compile(r"rubric|criteria", re.I)),
    ("script", re.compile(r"script|transcript|prompt|call[\s_-]?notes|debrief", re.I)),
    ("gold", re.compile(r"gold(en)?|answer|output|solution|final|vf\b", re.I)),
    ("input", re.compile(r"input|start|wip|skeleton|initial|base\b", re.I)),
]


@dataclass
class Bundle:
    root: Path
    input_workbooks: list = field(default_factory=list)
    supporting_files: list = field(default_factory=list)
    gold_workbook: Optional[Path] = None
    rubric: Optional[Path] = None
    script: Optional[Path] = None
    audio: list = field(default_factory=list)
    sota_output: Optional[Path] = None
    sota_selfgrade: Optional[Path] = None
    unclassified: list = field(default_factory=list)
    manifest: Optional[dict] = None    # remote file listing exported from the platform

    def remote_fields(self) -> set:
        return {f.get('field_id') for f in (self.manifest or {}).get('files', [])}

    def to_dict(self) -> dict:
        def s(p):
            return str(p.relative_to(self.root)) if p else None
        return {
            "root": str(self.root),
            "input_workbooks": [s(p) for p in self.input_workbooks],
            "supporting_files": [s(p) for p in self.supporting_files],
            "gold_workbook": s(self.gold_workbook),
            "rubric": s(self.rubric),
            "script": s(self.script),
            "audio": [s(p) for p in self.audio],
            "sota_output": s(self.sota_output),
            "sota_selfgrade": s(self.sota_selfgrade),
            "unclassified": [s(p) for p in self.unclassified],
            "remote_only": sorted(self.remote_fields()) if self.manifest else None,
        }


def _role(name: str) -> Optional[str]:
    for role, rx in _ROLE_PATTERNS:
        if rx.search(name):
            return role
    return None


def discover(root: Path, overrides: Optional[dict] = None) -> Bundle:
    root = Path(root)
    b = Bundle(root=root)
    overrides = overrides or {}
    files = sorted(p for p in root.rglob("*") if p.is_file() and not p.name.startswith(("~$", ".")))
    for p in files:
        ext = p.suffix.lower()
        stem = p.stem
        if p.name == "manifest.json":
            try:
                b.manifest = json.loads(p.read_text())
            except (json.JSONDecodeError, OSError):
                pass
            continue
        if stem.startswith("scan_") and ext == ".json":
            continue
        role = _role(stem)
        if ext in AUDIO_EXT:
            b.audio.append(p)
        elif ext in SHEET_EXT:
            if role == "sota_output":
                b.sota_output = b.sota_output or p
            elif role == "gold":
                if b.gold_workbook is None:
                    b.gold_workbook = p
                else:
                    b.unclassified.append(p)
            elif role == "input" or role is None:
                if role is None and b.input_workbooks:
                    b.supporting_files.append(p)
                else:
                    b.input_workbooks.append(p)
            else:
                b.supporting_files.append(p)
        elif ext == ".json":
            if role == "sota_selfgrade":
                b.sota_selfgrade = p
            elif role == "rubric" or (role is None and b.rubric is None and _looks_like_rubric(p)):
                b.rubric = p
            else:
                b.unclassified.append(p)
        elif ext in {".md", ".txt", ".docx", ".doc", ".pdf"}:
            if role == "rubric" and b.rubric is None:
                b.rubric = p
            elif role == "script" and b.script is None:
                b.script = p
            elif role == "sota_selfgrade":
                b.sota_selfgrade = p
            elif role is None and ext in {".md", ".txt"} and b.rubric is None and _looks_like_rubric(p):
                b.rubric = p
            elif role is None and ext in {".md", ".txt", ".docx"} and b.script is None:
                b.script = p
            else:
                b.supporting_files.append(p)
        elif ext in {".pptx"}:
            b.supporting_files.append(p)
        else:
            b.unclassified.append(p)
    # a lone workbook with no role words: treat as input if no gold
    for key, val in overrides.items():
        if val is None:
            continue
        val = Path(val) if not isinstance(val, list) else [Path(v) for v in val]
        setattr(b, key, val)
    return b


def _looks_like_rubric(p: Path) -> bool:
    try:
        head = p.read_text(encoding="utf-8", errors="replace")[:4000]
    except OSError:
        return False
    return bool(re.search(r"output validation|perturbation|pitfalls|presentation", head, re.I)) and head.count("?") >= 3


def read_text(path: Optional[Path]) -> str:
    """Read script/rubric text from .txt/.md/.json/.docx."""
    if path is None:
        return ""
    if path.suffix.lower() == ".docx":
        return _docx_text(path)
    return path.read_text(encoding="utf-8", errors="replace")


def _docx_text(path: Path) -> str:
    import zipfile
    from xml.etree import ElementTree as ET
    try:
        with zipfile.ZipFile(path) as z:
            xml = z.read("word/document.xml")
    except (zipfile.BadZipFile, KeyError):
        return ""
    ns = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
    root = ET.fromstring(xml)
    paras = []
    for p in root.iter("{%s}p" % ns["w"]):
        paras.append("".join(t.text or "" for t in p.iter("{%s}t" % ns["w"])))
    return "\n".join(paras)
