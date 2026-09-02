#!/usr/bin/env python3
import json, os, sys, datetime
label = sys.argv[1] if len(sys.argv) > 1 else "?"
raw = sys.stdin.read()
try:
    payload = json.loads(raw) if raw.strip() else {}
except Exception:
    payload = {"_unparsed": raw[:2000]}
log = os.environ.get("SEAMPROBE_LOG", "/tmp/seamprobe.jsonl")
with open(log, "a", encoding="utf-8") as f:
    f.write(json.dumps({"label": label, "ts": datetime.datetime.now().isoformat(),
                        "payload": payload}, ensure_ascii=False) + "\n")
tok = os.environ.get("SEAMPROBE_TOKEN", "")
emit = os.environ.get("SEAMPROBE_EMIT_" + label.replace("-", "_"), "")
if emit == "stdout" and tok:
    sys.stdout.write("INJ-" + label + "-" + tok + "\n")
sys.exit(0)
