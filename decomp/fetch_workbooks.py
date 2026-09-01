#!/usr/bin/env python3
"""Download the workbooks and agent-output blobs listed in workbook_manifest.csv.

This cannot run from a Claude Code web session: the proxy there reaches only
data.tsip.ai (Metabase), and Metabase is a SQL layer over Postgres that cannot
serve blobs. Run it from somewhere with normal network access and credentials.

Workbooks come from the tsip backend file API, which the request logs show as
    GET /api/files/<fileId>?taskId=<taskId>      -> 200
Agent output blobs are object-storage paths (the `data-compass/...` prefix) and
need either a signed-URL endpoint or direct bucket access; pass --blob-cmd for
whatever your environment uses (gsutil/aws/az).

Usage
  export TSIP_API=https://<backend-host>
  export TSIP_TOKEN=<bearer token>
  python3 fetch_workbooks.py --manifest workbook_manifest.csv --out ./blobs
  python3 fetch_workbooks.py --manifest workbook_manifest.csv --out ./blobs \
      --only-failures --blob-cmd 'gsutil cp gs://<bucket>/{path} {dest}'

Re-running skips files already on disk, so it is safe to interrupt.
"""
import argparse, concurrent.futures as cf, csv, os, pathlib, shlex, subprocess, sys, urllib.request

def fetch_file(api, token, file_id, task_id, dest):
    if dest.exists() and dest.stat().st_size > 0:
        return 'skip', file_id
    url = f"{api.rstrip('/')}/api/files/{file_id}?taskId={task_id}"
    req = urllib.request.Request(url, headers={'Authorization': f'Bearer {token}'})
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            data = r.read()
    except Exception as e:
        return f'ERROR {type(e).__name__}: {e}', file_id
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return f'ok {len(data):,}B', file_id

def fetch_blob(cmd_tpl, path, dest):
    if dest.exists() and dest.stat().st_size > 0:
        return 'skip', path
    dest.parent.mkdir(parents=True, exist_ok=True)
    cmd = cmd_tpl.format(path=path, dest=str(dest))
    p = subprocess.run(shlex.split(cmd), capture_output=True, text=True)
    return ('ok' if p.returncode == 0 else f'ERROR {p.stderr.strip()[:120]}'), path

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manifest', default='workbook_manifest.csv')
    ap.add_argument('--out', default='./blobs')
    ap.add_argument('--only-failures', action='store_true',
                    help='fetch only rows where the outline generation failed')
    ap.add_argument('--limit', type=int, default=0, help='cap rows (0 = all)')
    ap.add_argument('--workers', type=int, default=6)
    ap.add_argument('--blob-cmd', default='',
                    help="shell template for agent-output blobs, e.g. "
                         "'gsutil cp gs://BUCKET/{path} {dest}'. Omit to skip them.")
    a = ap.parse_args()

    api, token = os.environ.get('TSIP_API'), os.environ.get('TSIP_TOKEN')
    if not api or not token:
        sys.exit('set TSIP_API and TSIP_TOKEN')

    rows = list(csv.DictReader(open(a.manifest)))
    if a.only_failures:
        rows = [r for r in rows if r['has_outline'].lower() == 'false']
    if a.limit:
        rows = rows[:a.limit]
    out = pathlib.Path(a.out)
    print(f"{len(rows)} tasks -> {out}")

    jobs = []
    for r in rows:
        t = r['task_id']
        for side in ('input', 'output'):
            fid = r[f'{side}_file_id']
            if fid:
                jobs.append(('file', fid, t, out / t / f'{side}.xlsx'))
        if a.blob_cmd and r.get('agent_output_blob_path'):
            jobs.append(('blob', r['agent_output_blob_path'], t, out / t / 'agent_output.json'))

    done = ok = err = 0
    with cf.ThreadPoolExecutor(a.workers) as ex:
        futs = {}
        for kind, ident, task, dest in jobs:
            if kind == 'file':
                futs[ex.submit(fetch_file, api, token, ident, task, dest)] = ident
            else:
                futs[ex.submit(fetch_blob, a.blob_cmd, ident, dest)] = ident
        for f in cf.as_completed(futs):
            status, ident = f.result()
            done += 1
            if status.startswith('ERROR'):
                err += 1
                print(f"  [{done}/{len(jobs)}] {ident} {status}", file=sys.stderr)
            else:
                ok += 1
            if done % 50 == 0:
                print(f"  {done}/{len(jobs)}  ok={ok} err={err}")
    print(f"done: {ok} ok, {err} errors, into {out}")

if __name__ == '__main__':
    main()
