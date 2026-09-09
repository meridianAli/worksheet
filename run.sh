#!/usr/bin/env bash
# Usage: ./run.sh ids.txt [out_dir]
# Exports the tasks from the platform, lints them, and writes lint_report.txt + lint_results.json in out_dir.
set -euo pipefail
cd "$(dirname "$0")"
IDS="${1:?usage: ./run.sh ids.txt [out_dir]}"; OUT="${2:-tasks}"
python3 tools/export_tsip_tasks.py "$IDS" "$OUT"
python3 -m audio_task_linter lint "$OUT"/* > "$OUT/lint_report.txt" || true
python3 -m audio_task_linter lint "$OUT"/* --json > "$OUT/lint_results.json" || true
python3 -m audio_task_linter lint "$OUT"/* --summary | sed "s#$OUT/##"
echo; echo "Full report: $OUT/lint_report.txt   JSON: $OUT/lint_results.json"
