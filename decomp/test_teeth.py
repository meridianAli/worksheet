#!/usr/bin/env python3
"""Negative controls: prove the test fails when a script loses something.

A coverage test that passes everything is worthless. Each case below breaks one
script in a way a careless rewrite plausibly would, and asserts the audit
catches it.
"""
import glob, os, re, subprocess, sys, tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
CASES = [
    ('2266fdca', 'drop a spoken hardcode',
     lambda s: re.sub(r'4\.4, 3\.9, 4\.2, 4\.3,\s+4\.5, 4\.7', '4.4, 3.9, 4.2, 4.3', s)),
    ('2266fdca', 'drop a named deliverable',
     lambda s: re.sub(r'Postal Charges,\s+', '', s)),
    ('b68326d5', 'narrow a stated range',
     lambda s: s.replace('$34.00 to $42.00', '$36.00 to $40.00')),
    ('bb849b91', 'drop the parked memo figure',
     lambda s: s.replace('park a 60,000,000 memo figure in AU40', 'park a memo figure in AU40')),
    ('ef94a62b', 'drop one schedule column',
     lambda s: re.sub(r'Balloon\s+payment\.\s+', '', s)),
    ('fbe4760b', 'drop a new tab',
     lambda s: s.replace('Revenue_Forecast', 'that other tab')
                .replace('revenue forecast infrastructure', 'that work')),
    ('b68326d5', 'shorten a grid axis',
     lambda s: s.replace('160 to 200 by 10', '160 to 190 by 10')),
]


def run(task, script_path):
    wbs = glob.glob(os.path.join(HERE, 'wb', f'{task}_user_*.xlsx'))
    return subprocess.run(
        [sys.executable, os.path.join(HERE, 'coverage.py'),
         '--diff', os.path.join(HERE, 'diffs', f'{task}.json.gz'),
         '--input', wbs[0], '--script', script_path, '--quiet'],
        capture_output=True, text=True)


def main():
    bad = 0
    for task, name, mutate in CASES:
        orig = open(os.path.join(HERE, 'scripts', f'{task}.md')).read()
        broken = mutate(orig)
        if broken == orig:
            print(f'  ERROR  {task}: mutation "{name}" did not change the script')
            bad += 1
            continue
        with tempfile.NamedTemporaryFile('w', suffix='.md', delete=False) as f:
            f.write(broken)
            path = f.name
        r = run(task, path)
        os.unlink(path)
        ok = r.returncode != 0
        print(f'  {"caught " if ok else "MISSED "} {task}  {name}')
        if not ok:
            bad += 1
    print()
    if bad:
        print(f'FAIL - {bad} mutation(s) slipped through; the test is too loose')
        return 1
    print(f'PASS - all {len(CASES)} mutations caught')
    return 0


if __name__ == '__main__':
    sys.exit(main())
