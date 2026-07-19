#!/usr/bin/env python3
"""Seed markdown 파서 — 추출만, 판정 없음 (판정 스캔은 check-no-verdict-injection)."""
import json, re, sys
from pathlib import Path

AXIS_RE = re.compile(r"축\s*(\d+)")
CLUE_RE = re.compile(r"-\s*(D\d+)\s*\(축\s*(\d+)\)\s*:\s*(.*?)\s*—\s*(.+?):(\d+)\s*$")
OQ_RE = re.compile(r"-\s*(OQ\d+)\s*:\s*(?:축\s*(\d+)\s*—\s*)?(.+?)\s*$")


def parse(text):
    out = {"target": None, "extra_scope": [], "open_questions": [], "candidate_clues": []}
    m = re.search(r"^target:\s*(.+?)\s*$", text, re.M)
    if m:
        out["target"] = m.group(1)
    section = None
    for line in text.splitlines():
        h = line.strip()
        if h.startswith("## "):
            section = h[3:].strip()
            continue
        if section and section.startswith("추가 scope") and h.startswith("- "):
            out["extra_scope"].append(h[2:].strip())
        elif section and section.startswith("Open Questions"):
            mm = OQ_RE.match(h)
            if mm:
                out["open_questions"].append({
                    "id": mm.group(1),
                    "axis": int(mm.group(2)) if mm.group(2) else None,
                    "question": mm.group(3),
                })
        elif section and section.startswith("후보 단서"):
            mm = CLUE_RE.match(h)
            if mm:
                out["candidate_clues"].append({
                    "id": mm.group(1), "axis": int(mm.group(2)),
                    "claim": mm.group(3), "file": mm.group(4), "line": int(mm.group(5)),
                })
    return {k: v for k, v in out.items() if v not in (None, [])} or {}


def main(argv):
    if not argv:
        print("[parse-seed] usage: parse-seed.py <seed_path>", file=sys.stderr)
        return 2
    path = Path(argv[0])
    if not path.exists():
        print(f"[parse-seed] seed 파일 없음: {path} — fresh 6축 discovery로 진행", file=sys.stderr)
        print("{}")
        return 0
    obj = parse(path.read_text(encoding="utf-8"))
    print(json.dumps(obj, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
