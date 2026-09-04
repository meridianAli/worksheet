# Testing a spoken script against the workbooks

Five scripts, five task exports. The question this answers is not "does the
script mention cell F43" — it's **"reading only this script, with the input
workbook open, would you have made this change?"**

```sh
python3 tests/fetch_task_workbooks.py --export data/tasksexport20260904.json   # once
python3 tests/run_tests.py            # diff + audit all five
python3 tests/run_tests.py --rebuild  # re-diff the workbooks first (slow: ~20 min)
python3 tests/test_teeth.py           # negative controls - prove the test can fail
```

## How a change becomes a requirement

 `wbdiff.py` walks the input against the output and emits every changed cell,
classified. `coverage.py` then sorts those changes into three buckets. Only the
first two are enforced.

| Tier | What it is | Why the senior has to say it |
|---|---|---|
| `MUST_SAY_VALUE` | a typed number that appears nowhere in the input workbook, a literal written as a formula (`=60000000`), or a value typed into an otherwise formula-driven row | The analyst cannot derive it and cannot read it off the source file. It is a decision, and decisions come from the person briefing. |
| `MUST_SAY_RANGE` | a grid axis built by stepping off an anchor (`=G80+2`), tested on **both** its step and its extent | "$34.00 to $42.00 in $2.00 increments" is exactly what a senior says. Narrow the range or shorten the axis and the test fails. |
| `MUST_NAME` | a label, header or tab name in the output that appears nowhere in the input and is not standard finance vocabulary | New vocabulary. A tab name is matched **exactly** — "Revenue_Forecast" is not covered by having said "forecast" somewhere. |
| `DERIVABLE` *(not enforced)* | everything else: formulas, labels already visible in the input, and anything in [`standard_lexicon.txt`](standard_lexicon.txt) | No senior reads out 400 rows of an amortization schedule, or tells an analyst a P&L needs a gross profit row. Demanding it would make the scripts worse. |

That last row is the point of the whole design. Of 32,103 cell changes across
the five tasks, **180 are enforced** — the rest is work an analyst does from the
source file and a named ask.

## The two calls this makes on your behalf

**What counts as standard.** [`standard_lexicon.txt`](standard_lexicon.txt) is a
plain word list, checked in and auditable, of vocabulary the test agrees to stop
checking (`gross profit`, `days sales outstanding`, `beginning balance`, …).
Anything not on it and not in the input workbook must be spoken. Adding to that
file weakens the test; that is the intended dial, and it should be turned
deliberately.

**What counts as saying it.** A senior paraphrases. So a label is covered when
the script contains every instruction-carrying word in it, not the exact string:
"Offset — that's when extra principal happens" covers the header
`Offset (when extra principal happens)`. Numbers match sign-insensitively and in
either percent form (`1.1%` covers a cell holding `0.011`), spelled-out small
numbers count (`zero` covers `0`), and a stated range covers its interior, so
"160 to 200 by 10" covers the 170 and 190 nobody says out loud.

## Proving it can fail

A coverage test that passes everything is worthless, so `test_teeth.py` breaks
each script the way a careless rewrite would — drops a spoken hardcode, drops a
named deliverable, drops a schedule column, drops a tab, narrows a stated price
range, shortens a grid axis — and asserts the audit catches it. All seven are
caught. Three of them were *not* caught when first written, which is how the
tab-name and grid-extent rules got tightened.

## What this does not catch

- **Identifier versus prose.** Speech cannot distinguish the tab
  `Revenue_Forecast` from the phrase "revenue forecast". If a script happens to
  use the words nearby, a dropped tab name can pass.
- **Ordering and dependency.** The test checks that things were said, not that
  the sequence makes sense to build from.
- **Whether it sounds like a banker.** Entirely a human read. The test only
  guarantees the script is *complete*, never that it is *natural* — and the two
  pull against each other, which is why coverage is worth automating and voice
  is not.
- **Formatting rules** (fonts, fills, colors) are carried in the scripts but sit
  in the derivable bucket: the differ records format changes, and they are not
  currently enforced.

## Files

| | |
|---|---|
| `fetch_task_workbooks.py` | pulls the ten workbooks out of the export's signed URLs into `wb/` |
|  `wbdiff.py` | input vs output, cell by cell → `diffs/<task>.json.gz` |
| `coverage.py` | changes + input vocabulary + script → covered / missed |
| `run_tests.py` | all five, one exit code |
| `test_teeth.py` | negative controls |
| `standard_lexicon.txt` | vocabulary the test treats as derivable |
|  `../scripts/<task>.md` | the spoken script under test |
