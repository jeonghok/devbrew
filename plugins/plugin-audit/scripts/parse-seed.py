#!/usr/bin/env python3
"""Seed markdown 파서 — 추출만, 판정 없음 (판정 스캔은 check-no-verdict-injection)."""
import json, re, sys
from pathlib import Path

AXIS_RE = re.compile(r"축\s*(\d+)")
CLUE_RE = re.compile(r"-\s*(D\d+)\s*\(축\s*(\d+)\)\s*:\s*(.*?)\s*—\s*(.+?):(\d+)\s*$")
OQ_RE = re.compile(r"-\s*(OQ\d+)\s*:\s*(?:축\s*(\d+)\s*—\s*)?(.+?)\s*$")


def parse(text):
    """(추출결과 dict, warnings list) 반환. warnings = 인식된 섹션 안에서 형식에 안 맞아 **드롭된**
    불릿들 — seed는 감사에서 가장 표적화된 입력이라, 조용히 버리면 사용자의 단서가 흔적 없이 증발한다
    (CONTRACT rule 11을 입력에 적용, SF1 /qg 2026-07-20). main이 이 warnings를 loud하게 stderr로 낸다."""
    out = {"target": None, "extra_scope": [], "open_questions": [], "candidate_clues": []}
    warnings = []
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
        elif section and section.startswith("Open Questions") and h.startswith("- "):
            mm = OQ_RE.match(h)
            if mm:
                out["open_questions"].append({
                    "id": mm.group(1),
                    "axis": int(mm.group(2)) if mm.group(2) else None,
                    "question": mm.group(3),
                })
            else:  # 형식 불일치 불릿 — 드롭 사실을 기록 (조용한 증발 금지)
                warnings.append(("Open Questions", h))
        elif section and section.startswith("후보 단서") and h.startswith("- "):
            mm = CLUE_RE.match(h)
            if mm:
                out["candidate_clues"].append({
                    "id": mm.group(1), "axis": int(mm.group(2)),
                    "claim": mm.group(3), "file": mm.group(4), "line": int(mm.group(5)),
                })
            else:
                warnings.append(("후보 단서", h))
    return {k: v for k, v in out.items() if v not in (None, [])} or {}, warnings


def main(argv):
    if not argv:
        print("[parse-seed] usage: parse-seed.py <seed_path>", file=sys.stderr)
        return 2
    path = Path(argv[0])
    if not path.exists():
        print(f"[parse-seed] seed 파일 없음: {path} — fresh 6축 discovery로 진행", file=sys.stderr)
        print("{}")
        return 0
    text = path.read_text(encoding="utf-8")
    obj, warnings = parse(text)
    for section, dropped in warnings:
        print(f"[parse-seed] ⚠ '{section}' 섹션 불릿 파싱 실패 — 드롭됨: {dropped}", file=sys.stderr)
    if not obj and text.strip():
        # 비어있지 않은 seed가 아무것도 파싱 안 됨 → absent-seed의 {}와 구별되는 진단 (SF1).
        print("[parse-seed] ⚠ seed 파일이 비어있지 않으나 인식된 항목이 0개 — 섹션 헤더/불릿 형식 확인 "
              "(후보 단서: `- D1 (축1): claim — file:line`, OQ: `- OQ1: 축N — question`). fresh discovery로 진행.",
              file=sys.stderr)
    print(json.dumps(obj, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
