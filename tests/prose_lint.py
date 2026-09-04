#!/usr/bin/env python3
"""Flag sentences that are not sentences.

The first draft of these scripts failed for a reason no coverage test could
catch: chasing clipped speech produced verbless fragments - "Working capital.
365-day basis." - which read as broken English. This lints for that directly.

A sentence is flagged when it runs four words or longer and contains no verb
from a broad list of the verbs these briefings actually use. Advisory, not
pass/fail: a short interjection is fine, and the list is not a parser. Read
what it flags and judge.

  python3 tests/prose_lint.py            # all scripts
  python3 tests/prose_lint.py scripts/2266fdca.md
"""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

VERBS = set('''
is are was were be been being am
has have had having
do does did doing done
will would shall should can could may might must
go goes going went come comes coming
build builds building built run runs running ran
use uses using used need needs needed want wants wanted
link links linking linked keep keeps keeping kept
make makes making made take takes taking took
put puts putting add adds adding added show shows showing showed
give gives giving gave get gets getting got
pull pulls pulling pulled drive drives driving drove driven
set sets setting start starts starting started
tie ties tying tied foot foots footing footed
calculate calculates calculating calculated derive derives deriving derived
populate populates populating populated complete completes completing completed
compute computes computing computed aggregate aggregates aggregating aggregated
carry carries carrying carried leave leaves leaving left
apply applies applying applied respect respects respecting respected
label labels labelling labelled labeling labeled
hardcode hardcodes hardcoding hardcoded type types typing typed
walk walks walking walked step steps stepping stepped
sit sits sitting sat sat stay stays staying stayed
know knows knowing knew think thinks thinking thought
want wants ask asks asking asked tell tells telling told
say says saying said read reads reading
skip skips skipping skipped miss misses missing missed
find finds finding found check checks checking checked
mean means meaning meant look looks looking looked
turn turns turning turned open opens opening opened
close closes closing closed repay repays repaying repaid
amortize amortizes amortizing amortized flag flags flagging flagged
convert converts converting converted mirror mirrors mirroring mirrored
source sources sourcing sourced summarize summarizes summarizing summarized
let lets letting flatter flatters flattering flattered
enter enters entering entered park parks parking parked
hold holds holding held cover covers covering covered
fill fills filling filled catch catches catching caught
settle settles settling settled
'''.split())
CONTRACTED = re.compile(r"\w+'(s|re|ll|ve|d|m|t)\b")


def sentences(text):
    text = re.sub(r'\s+', ' ', text)
    for s in re.split(r'(?<=[.!?])\s+', text):
        s = s.strip()
        if s:
            yield s


def flagged(path):
    out = []
    for s in sentences(open(path).read()):
        words = re.findall(r"[A-Za-z']+", s.lower())
        if len(words) < 4:
            continue
        if any(w in VERBS for w in words) or CONTRACTED.search(s.lower()):
            continue
        out.append(s)
    return out


def main():
    paths = sys.argv[1:] or sorted(glob.glob(os.path.join(ROOT, 'scripts', '*.md')))
    total = 0
    for p in paths:
        bad = flagged(p)
        total += len(bad)
        print(f"{os.path.basename(p):16s} {len(bad)} possible fragment(s)")
        for s in bad:
            print(f"    {s[:100]}")
    print()
    print('clean - every sentence carries a verb' if not total
          else f'{total} to look at (advisory - some may be fine)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
