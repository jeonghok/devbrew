#!/usr/bin/env python3
"""render-audit-report.py — audit-data.json → 마크다운 (design §11·§16).

렌더러는 신규 load-bearing 코드다: 정렬은 순회가 아니라 4단 비교자이고 두 키 모두 비-사전순
서수다 (순진한 문자열 비교가 CRITICAL<HIGH, L<M<S로 조용히 뒤집는다). fix_cost에 산문이 섞이면
비교자가 NaN을 낸다 → 첫 글자만 본다. AC-4: 6축 전멸이면 리포트를 안 만든다 (빈 감사는 감사가 아니다).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SEV_RANK = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
COST_RANK = {"S": 0, "M": 1, "L": 2}


def cost_key(fix_cost) -> int:
    """산문이 섞여도(예: 'M — 훅 20줄') 첫 유효 글자로 서수를 뽑는다 (NaN 방지, §9.2)."""
    if not isinstance(fix_cost, str):
        return 99
    for ch in fix_cost.strip():
        if ch in COST_RANK:
            return COST_RANK[ch]
    return 99


def sort_key(f: dict):
    return (SEV_RANK.get(f.get("severity"), 99), cost_key(f.get("fix_cost")),
            0 if f.get("reference_gap") not in (None, "none") else 1, f.get("id", ""))


def deep_label(f: dict) -> str:
    dv = f.get("deep_verified")
    if dv is True:
        return " (심층검증 통과)"
    if dv is False:
        return " (심층검증 미실시 — 상한 초과)"
    return ""   # null → 무라벨


def render(data: dict) -> str | None:
    meta = data.get("meta", {})
    findings = [f for f in data.get("findings", []) if f.get("status") == "reported"]
    axis_failures = data.get("axis_failures", [])
    degraded = data.get("degraded", [])

    if len(axis_failures) >= 6:
        return None  # AC-4(a): 빈 감사는 감사가 아니다

    lines = ["# project-init 읽기전용 감사 — " + meta.get("date", "")]
    banners = []
    if axis_failures:
        banners.append(f"⚠ **{6 - len(axis_failures)}/6 축 완주** — {len(axis_failures)}개 축 감사 실패")
    if not meta.get("codex", {}).get("ran"):
        banners.append("⚠ **codex 독립 감사 미실행** — LD4 모델 다양성 결손")
    if degraded:
        banners.append(f"⚠ **degraded {len(degraded)}건** — 아래 결손 목록 참조")
    if not findings:
        banners.append("⚠ **발견 0건** — 이것이 *깨끗함*인지 *감사 실패*인지 축 완주 수와 journal로 확인하라")
    lines += banners + [""]

    findings.sort(key=sort_key)
    lines.append("## 발견")
    for f in findings:
        badge = " ⚑ 두 모델 독립 확인" if f.get("cross_model_confirmed") else ""
        lines.append(f"### [{f.get('severity')}] {f.get('title')} ({f.get('id')}){badge}{deep_label(f)}")
        for ev in f.get("evidence", []):
            lines.append(f"- `{ev.get('file')}:{ev.get('line')}` — {ev.get('quote')}")
        lines.append(f"- 피해: {f.get('user_harm')}")
        lines.append(f"- 권고: {f.get('recommendation')}")
        lines.append(f"- 반대근거: {f.get('counter_argument')}")
        if f.get("reference_gap") not in (None, "none"):
            lines.append(f"- 레퍼런스 격차: {f.get('reference_gap')}")
        lines.append("")

    noqs = data.get("new_open_questions", [])
    if noqs:
        lines.append("## 열린 질문 (NOQ — 갭은 아니나 조용히 버리지 않는다)")
        for q in noqs:
            lines.append(f"- **{q.get('id')}** (축{q.get('axis')}): {q.get('observation')} "
                         f"— *왜 갭이 아닌가*: {q.get('why_not_gap')}")
        lines.append("")

    if degraded:
        lines.append("## 결손 (degraded)")
        for x in degraded:
            lines.append(f"- {x.get('what')} — {x.get('why')}")
        lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("json", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--readme", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.json.read_text(encoding="utf-8"))
    md = render(data)
    if md is None:
        print("[render] 6축 전멸 — 리포트를 만들지 않는다 (AC-4a). 실패 보고 후 중단.", file=sys.stderr)
        return 1
    args.out.write_text(md, encoding="utf-8")
    # docs/audits/README.md 인덱스에 항목 추가 (Law 3 discoverability)
    entry = f"- [{args.out.stem}]({args.out.name}) — {data.get('meta', {}).get('date', '')}\n"
    if args.readme.is_file():
        prev = args.readme.read_text(encoding="utf-8")
        if args.out.name not in prev:
            args.readme.write_text(prev + entry, encoding="utf-8")
    else:
        args.readme.write_text("# 감사 인덱스\n\n" + entry, encoding="utf-8")
    print(f"[render] {args.out} ({len(md.splitlines())} 줄)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
