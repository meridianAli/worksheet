# Audio task linter — quick start

Lints TSIP audio (MD/VP debrief) and PowerPoint-markup tasks against the review rules.
One-off setup, then one command per batch.

## Setup (once)

    pip install -r requirements.txt
    # optional but recommended, enables live perturbation recalculation when workbooks are local:
    pip install formulas          # or: apt-get install libreoffice-calc

Python 3.10+.

## Run on task IDs straight from the platform

1. Put the task IDs in a file, one per line, or comma-separated with quotes:

       'de89d6fd-9896-4d6f-a3f3-e9ece50a20ef','f9c03a9e-3a31-4c72-aff0-4ef7860447a4'

2. Export the prompt, rubric, file manifest and scanner results for each task
   (needs network access to data.tsip.ai with a Metabase key attached, as in the Claude environment;
   otherwise skip to "Run on a local folder"):

       python tools/export_tsip_tasks.py ids.txt tasks/

3. Lint them:

       python -m audio_task_linter lint tasks/*            # full report
       python -m audio_task_linter lint tasks/* --summary  # one line per task
       python -m audio_task_linter lint tasks/* --json     # machine-readable

   Or use the wrapper that does steps 2 and 3 together and writes a report file:

       ./run.sh ids.txt

## Run on a local folder (export-center zip)

Unzip a task into a folder so it contains the input workbook, gold workbook, rubric (.json or .md),
script/prompt (.txt/.docx) and recording. Then:

    python -m audio_task_linter lint <folder>

With the workbooks present the linter also checks that the gold reproduces every rubric target,
recalculates every perturbation, and scans the input for answer hints.

## Reading the output

    ✖ [error]   blocks delivery
    ▲ [warning] needs a reviewer look
    · [info]    context only

Each line shows the check name, the criterion ID it applies to, the message, and the evidence text.
Exit code is 1 if any task has an error, so it works in a script.

## Rule catalog

    python -m audio_task_linter rules

Full descriptions are in README.md. To change the points cap, edit `max_points` in
audio_task_linter/context.py (currently 10).
