#!/usr/bin/env python3
"""Run the coverage test for every task: diff the workbooks, audit the script.

  python3 run_tests.py                # all five
  python3 run_tests.py --task 2266fdca
  python3 run_tests.py --rebuild      # re-diff the workbooks first (slow)

Exit code 0 only if every enforced requirement in every task is covered.
"""
import argparse, glob, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TASKS = ['2266fdca', 'b68326d5', 'bb849b91', 'ef94a62b', 'fbe4760b']
DIFFS = os.path.join(HERE, 'diffs')


def wb(task, role):
    hits = glob.glob(os.path.join(HERE, 'wb', f'{task}_{role}_*.xlsx'))
    if not hits:
        sys.exit(f'missing workbook for {task} ({role}) - run fetch_task_workbooks.py')
    return hits[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--task', action='append')
    ap.add_argument('--rebuild', action='store_true')
    ap.add_argument('--quiet', action='store_true')
    a = ap.parse_args()
    os.makedirs(DIFFS, exist_ok=True)
    tasks = a.task or TASKS
    failed = []
    for t in tasks:
        dj = os.path.join(DIFFS, f'{t}.json.gz')
        if a.rebuild or not os.path.exists(dj):
            subprocess.run([sys.executable, os.path.join(HERE, 'wbdiff.py'),
                            '--in', wb(t, 'user'), '--out', wb(t, 'assistant'),
                            '--json', dj], check=True)
        cmd = [sys.executable, os.path.join(HERE, 'coverage.py'), '--diff', dj,
               '--input', wb(t, 'user'),
               '--script', os.path.join(HERE, 'scripts', f'{t}.md')]
        if a.quiet:
            cmd.append('--quiet')
        if subprocess.run(cmd).returncode:
            failed.append(t)
    print()
    if failed:
        print(f'FAIL - uncovered requirements in: {", ".join(failed)}')
        return 1
    print(f'PASS - {len(tasks)} scripts, every enforced requirement covered')
    return 0


if __name__ == '__main__':
    sys.exit(main())
