#!/usr/bin/env python3
"""Run the workbook audit over a downloaded corpus and test the bloat theory.

Applies to every task what was measured by hand on one pair: how much of each
workbook is the <definedNames> block, whether any formula actually references
those names, sheet and formula counts, and -- if the agent-output blobs were
fetched -- what the agent actually returned on a failing run.

    python3 analyze_workbooks.py --manifest workbook_manifest.csv --blobs ./blobs \
        --out workbook_audit.csv

Reads the xlsx as a zip, so it needs no openpyxl and never evaluates a formula.
The question it answers: do failing tasks carry more defined-name bloat than
succeeding ones, or was that one workbook a coincidence?
"""
import argparse, csv, json, pathlib, re, statistics, zipfile

def probe(path):
    """Structural stats for one xlsx, without opening it as a spreadsheet."""
    out = dict(ok=False)
    try:
        z = zipfile.ZipFile(path)
        wbx = z.read('xl/workbook.xml').decode('utf-8', 'replace')
    except Exception as e:
        out['error'] = f'{type(e).__name__}: {e}'
        return out
    m = re.search(r'<definedNames>.*</definedNames>', wbx, re.S)
    dn_bytes = len(m.group(0)) if m else 0
    names = re.findall(r'<definedName[^>]*name="([^"]*)"', wbx)
    sheet_xml = [n for n in z.namelist()
                 if n.startswith('xl/worksheets/') and n.endswith('.xml')]
    sheet_bytes = sum(z.getinfo(n).file_size for n in sheet_xml)
    formulas = 0
    referenced = set()
    nameset = {n for n in names if not n.startswith('_xlnm.')}
    for n in sheet_xml:
        x = z.read(n).decode('utf-8', 'replace')
        formulas += len(re.findall(r'<f[ >]', x))
        # Only real formula bodies: <f .../> is a shared-formula stub with no
        # text, and a greedy/dotall match across one would swallow raw sheet XML
        # and make tag names look like defined-name uses.
        for f in re.findall(r'<f(?![^>]*/>)[^>]*>([^<]*)</f>', x):
            # Drop quoted sheet references first: 'Nov18 BS'!D42 would otherwise
            # look like a use of a defined name called BS. That false positive is
            # exactly what made the hand count read 1 instead of 0.
            f = re.sub(r"'[^']*'!", '', f)
            for tok in set(re.findall(r"[A-Za-z_\\][A-Za-z0-9_.\\]*", f)):
                if tok in nameset:
                    referenced.add(tok)
    total = sum(i.file_size for i in z.infolist())
    out.update(ok=True, uncompressed=total, sheets=len(sheet_xml),
               sheet_bytes=sheet_bytes, formulas=formulas,
               defined_names=len(names), defined_name_bytes=dn_bytes,
               pct_defined_names=round(100.0 * dn_bytes / total, 1) if total else 0,
               names_referenced_by_a_formula=len(referenced),
               dead_ref_names=sum(1 for t in re.findall(
                   r'<definedName[^>]*>(.*?)</definedName>', wbx, re.S) if '#REF' in t))
    return out

def agent_answer(p):
    """Pull the agent's raw outline out of a fetched data-compass output blob."""
    try:
        d = json.loads(pathlib.Path(p).read_text())
    except Exception:
        return None
    rows = d.get('rows') or d.get('data') or []
    hdr = d.get('headers') or []
    if not rows or 'task_outline_og' not in hdr:
        return None
    r0 = rows[0]
    val = dict(zip(hdr, r0)).get('task_outline_og') if isinstance(r0, list) else r0.get('task_outline_og')
    return val

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--manifest', default='workbook_manifest.csv')
    ap.add_argument('--blobs', default='./blobs')
    ap.add_argument('--out', default='workbook_audit.csv')
    a = ap.parse_args()

    blobs = pathlib.Path(a.blobs)
    rows_out = []
    for r in csv.DictReader(open(a.manifest)):
        t = r['task_id']
        d = blobs / t
        rec = dict(task_id=t, has_outline=r['has_outline'],
                   empty_context=r.get('empty_context', ''),
                   input_tokens=r.get('input_tokens', ''),
                   output_tokens=r.get('output_tokens', ''))
        for side in ('input', 'output'):
            f = d / f'{side}.xlsx'
            if not f.exists():
                rec[f'{side}_missing'] = 1
                continue
            for k, v in probe(f).items():
                rec[f'{side}_{k}'] = v
        ans = agent_answer(d / 'agent_output.json')
        if ans is not None:
            rec['agent_outline_len'] = len(ans)
            rec['agent_outline_head'] = ans[:200].replace('\n', ' ')
        rows_out.append(rec)

    if not rows_out:
        print('nothing to analyse -- fetch the files first'); return
    cols = sorted({k for r in rows_out for k in r})
    with open(a.out, 'w', newline='') as fh:
        w = csv.DictWriter(fh, fieldnames=cols); w.writeheader(); w.writerows(rows_out)

    # The comparison the whole exercise is for.
    def med(sel, key):
        v = [float(r[key]) for r in rows_out if r.get(key) not in (None, '')
             and str(r['has_outline']).lower() == sel]
        return round(statistics.median(v), 1) if v else None
    print(f"wrote {a.out} ({len(rows_out)} tasks)\n")
    print(f"{'metric':34} {'failed':>12} {'succeeded':>12}")
    for key in ('input_pct_defined_names', 'input_defined_names', 'input_uncompressed',
                'input_formulas', 'input_sheets', 'agent_outline_len'):
        print(f"  {key:32} {str(med('false', key)):>12} {str(med('true', key)):>12}")
    ref = [r for r in rows_out if str(r.get('input_names_referenced_by_a_formula', '0')) not in ('0', '')]
    print(f"\nworkbooks where a formula references a defined name: {len(ref)} of {len(rows_out)}")
    print("(if that stays ~0, stripping <definedNames> before serialising is safe)")

if __name__ == '__main__':
    main()
