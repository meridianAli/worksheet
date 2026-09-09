import json, sys, subprocess
def q(sql, db=2):
    body = json.dumps({"database": db, "type": "native", "native": {"query": sql}})
    out = subprocess.run(["curl", "-sS", "-X", "POST", "https://data.tsip.ai/api/dataset", "-H", "Content-Type: application/json", "-d", body], capture_output=True, text=True, timeout=300).stdout
    r = json.loads(out)
    if r.get("status") == "failed" or "error" in r: print("ERR", str(r.get("error"))[:500], file=sys.stderr); return [], []
    cols = [c["name"] for c in r["data"]["cols"]]; return cols, r["data"]["rows"]
if __name__ == "__main__":
    cols, rows = q(sys.argv[1])
    for r in rows: print(dict(zip(cols, r)))
