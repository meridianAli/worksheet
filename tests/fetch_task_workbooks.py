#!/usr/bin/env python3
"""Pull the input/output workbook pair for each exported task into ./wb.

The export carries pre-signed blob URLs, so this needs no credentials - but the
signatures expire. If a fetch 403s, re-export the tasks to get fresh URLs.

  python3 tests/fetch_task_workbooks.py --export data/tasksexport20260904.json
"""
import argparse, json, os, re, urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--export', required=True)
    ap.add_argument('--out', default=os.path.join(ROOT, 'wb'))
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    for task in json.load(open(a.export)):
        tid = task['id'][:8]
        for msg in task['messages']:
            for c in msg['content']:
                if c['type'] != 'document':
                    continue
                url = c['source']['url']
                name = re.sub(r'\?.*$', '', url).rsplit('/', 1)[-1]
                dest = os.path.join(a.out, f"{tid}_{msg['role']}_{name}")
                if os.path.exists(dest):
                    print('have', os.path.basename(dest)); continue
                with urllib.request.urlopen(url, timeout=300) as r, open(dest, 'wb') as f:
                    f.write(r.read())
                print('got ', os.path.basename(dest), os.path.getsize(dest))


if __name__ == '__main__':
    main()
