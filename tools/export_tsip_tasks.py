"""Export per-task bundle text from tsip_prd via Metabase: prompt, rubric JSON, file manifest, scanner validation.

Usage: python tools/export_tsip_tasks.py ids.txt [out_dir]   (ids.txt: comma-separated, quoted task UUIDs)
Requires the Metabase API key to be attached by the environment (proxy-injected); nothing is stored here."""
import json, sys, os
from pathlib import Path
sys.path.insert(0, os.path.dirname(__file__))
from metabase import q

ids = [x.strip().strip("'") for x in open(sys.argv[1]).read().split(",")]
out_root = Path(sys.argv[2] if len(sys.argv) > 2 else "tasks"); out_root.mkdir(exist_ok=True)
idlist = ",".join(f"'{i}'" for i in ids)
# latest attempt per task (by created_at) with messages
cols, rows = q(f"""
select a.task_id::text, a.id::text attempt_id, a.created_at::text, a.submitted_at::text, a.messages::text, t.status
from tsip_attempts a join tsip_tasks t on t.id=a.task_id
where a.task_id in ({idlist})
order by a.task_id, a.created_at desc""")
seen = set(); latest = {}
for r in rows:
    d = dict(zip(cols, r))
    if d["task_id"] not in seen:
        seen.add(d["task_id"]); latest[d["task_id"]] = d
cols, frows = q(f"""
select a.task_id::text, af.attempt_id::text, af.field_id, af.ordinal, f.id::text file_id, f.filename, f.size, f.content_type,
       f.metadata::text meta, f.scan_data::text scan, f.uploaded_at::text
from tsip_attempt_files af join tsip_files f on f.id=af.file_id join tsip_attempts a on a.id=af.attempt_id
where a.task_id in ({idlist})""")
files_by_attempt = {}
for r in frows:
    d = dict(zip(cols, r)); files_by_attempt.setdefault(d["attempt_id"], []).append(d)

summary = []
for tid in ids:
    d = latest.get(tid)
    td = out_root / tid; td.mkdir(exist_ok=True)
    if not d:
        summary.append((tid, "NO ATTEMPTS")); continue
    msgs = json.loads(d["messages"])
    prompt, rubric = "", None
    for m in msgs:
        ann = m.get("_annotations") or {}
        if "rubric" in ann: rubric = ann["rubric"]
        for c in m.get("content", []):
            a = c.get("_annotations") or {}
            if c.get("type") == "text" and a.get("field_id") == "prompt": prompt = c.get("text", "")
            if "rubric" in a: rubric = a["rubric"]
    (td / "prompt.txt").write_text(prompt)
    if rubric is not None: (td / "rubric.json").write_text(json.dumps(rubric, indent=1))
    manifest = []
    for f in files_by_attempt.get(d["attempt_id"], []):
        manifest.append({k: f[k] for k in ("field_id", "ordinal", "file_id", "filename", "size", "content_type", "uploaded_at")})
        val = None
        if f["scan"]: val = json.loads(f["scan"])
        elif f["meta"]:
            mm = json.loads(f["meta"]); val = (mm.get("workbook") or {}).get("validation") or mm.get("validation")
        if val:
            (td / f"scan_{f['field_id']}_{f['ordinal']}.json").write_text(json.dumps(val, indent=1))
    (td / "manifest.json").write_text(json.dumps({"task_id": tid, "attempt_id": d["attempt_id"], "status": d["status"],
                                                 "attempt_created_at": d["created_at"], "files": manifest}, indent=1))
    summary.append((tid, d["status"], len(manifest), "rubric" if rubric else "NO RUBRIC", len(prompt)))
for s in summary: print(*s)
