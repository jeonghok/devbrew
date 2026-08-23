#!/usr/bin/env python3
"""훅 이벤트 payload 덤프 — 발화 범위 측정용.

로그 경로는 HOOKPROBE_LOG 로 준다. 없으면 stdout 으로만 낸다.
사용법은 MEASUREMENT.md 참조.
"""
import json
import os
import pathlib
import sys

ev = sys.argv[1] if len(sys.argv) > 1 else "?"
try:
    payload = json.load(sys.stdin)
except Exception as exc:  # noqa: BLE001 — 프로브다. 어떤 payload 도 기록한다.
    payload = {"_read_error": str(exc)}
rec = json.dumps({"event": ev, "payload": payload}, ensure_ascii=False)

log = os.environ.get("HOOKPROBE_LOG")
if log:
    with pathlib.Path(log).open("a", encoding="utf-8") as f:
        f.write(rec + "\n")
else:
    print(rec, file=sys.stderr)
print(json.dumps({}))
