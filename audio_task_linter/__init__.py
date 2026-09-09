"""Linter for multimodal audio (MD/VP debrief) finance tasks.

A task bundle is: input workbook(s) (+ supporting files), the MD/VP script and
its audio recording, the gold output workbook, the rubric written against the
gold, and optionally the SOTA "Solved" output and its self-grade.

Usage:
    python -m audio_task_linter lint <task_dir> [<task_dir> ...] [--json] [--no-recalc]
    python -m audio_task_linter rules
"""

__version__ = "0.1.0"
