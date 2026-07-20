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

    target = meta.get("target", "plugin")
    lines = [f"# {target} 읽기전용 감사 — " + meta.get("date", "")]
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

    oq_answers = data.get("oq_answers", [])
    if oq_answers:
        lines.append("## 배정된 열린 질문 (OQ)")
        by_id: dict[str, list[dict]] = {}
        for a in oq_answers:
            by_id.setdefault(a.get("id"), []).append(a)
        for oq_id in sorted(by_id.keys()):
            lines.append(f"### {oq_id}")
            for a in sorted(by_id[oq_id], key=lambda a: a.get("source") or ""):
                lines.append(f"- 출처: {a.get('source')}")
                # WB4: 구조로 분기한다 (id 아님). OQ id는 seed-derived라 어떤 id든 붙을 수 있고,
                # 2026-07-15 baseline은 OQ1~OQ4에 left/right evidence를 달았다 — `oq_id=="OQ1"`
                # 하드코딩은 OQ2~4의 증거를 조용히 드롭했다. left/right evidence 키가 있으면 좌/우
                # 대칭으로, 없으면 `답:` 산문 형태로 렌더한다.
                if "left_evidence" in a or "right_evidence" in a:
                    # §9.5: 좌/우 대칭 — 빈 쪽도 0건으로 명시(숨기지 않는다)
                    for side_label, side_key in (("좌", "left_evidence"), ("우", "right_evidence")):
                        side_ev = a.get(side_key) or []
                        if not side_ev:
                            lines.append(f"  - {side_label}: 0건")
                        else:
                            lines.append(f"  - {side_label}:")
                            for e in side_ev:
                                lines.append(f"    - `{e.get('file')}:{e.get('line')}` — {e.get('claim')}: {e.get('quote')}")
                    if a.get("steelman_condition"):
                        lines.append(f"  - 스틸맨 조건: {a.get('steelman_condition')}")
                else:
                    lines.append(f"  - 답: {a.get('answer')}")
                    for e in a.get("evidence") or []:
                        lines.append(f"    - `{e.get('file')}:{e.get('line')}` — {e.get('quote')}")
                lines.append(f"  - 근거: {a.get('reason')}")
            ref_ids = [f.get("id") for f in findings if f.get("oq_ref") == oq_id]
            if ref_ids:
                lines.append(f"- 이 질문과 관련된 발견: {', '.join(ref_ids)}")
            lines.append("")

    d_verdicts = data.get("d_verdicts", [])
    if d_verdicts:
        lines.append("## 후보 단서 판정")
        by_d: dict[str, list[dict]] = {}
        for d in d_verdicts:
            by_d.setdefault(d.get("id", ""), []).append(d)
        for d_id in sorted(by_d.keys()):
            lines.append(f"### {d_id}")
            # §9.3: 두 판정이 엇갈려도 해소하지 않고 나란히 드러낸다 — 각 source를 독립 렌더링.
            for d in sorted(by_d[d_id], key=lambda d: d.get("source") or ""):
                lines.append(f"- 출처: {d.get('source')} — 판정: {d.get('verdict')}")
                lines.append(f"  - 근거: {d.get('reason')}")
                if d.get("impact"):
                    lines.append(f"  - 영향: {d.get('impact')}")
                if d.get("fix"):
                    lines.append(f"  - 수정: {d.get('fix')}")
                if d.get("why_unverifiable"):
                    lines.append(f"  - 불가사유: {d.get('why_unverifiable')}")
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
            # assemble-audit-data.py가 {what,why}로 정규화하지만, 평문 문자열 degraded
            # (pre-0/pre-1 게이트 방출 형태)에도 방어적으로 대응한다 — .get() 크래시 금지.
            if isinstance(x, dict):
                lines.append(f"- {x.get('what')} — {x.get('why')}")
            else:
                lines.append(f"- {x}")
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
