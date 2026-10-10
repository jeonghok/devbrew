#!/usr/bin/env python3
"""render-audit-report.py — audit-data.json → 마크다운 (design §11·§16).

렌더러는 신규 load-bearing 코드다: 정렬은 순회가 아니라 4단 비교자이고 두 키 모두 비-사전순
서수다 — fix_cost 문자(S/M/L)는 알파벳순(L<M<S)이 실제 순위(S<M<L)를 조용히 뒤집는다.
severity(CRITICAL/IMPORTANT/SUGGESTION, Task 28 어휘통일)는 알파벳순이 우연히 순위와
일치하지만(C<I<S) SEV_RANK로 명시한다 — 어휘가 다시 바뀌면 이 우연은 보장되지 않는다.
fix_cost에 산문이 섞이면 비교자가 NaN을 낸다 → 첫 글자만 본다. AC-4: 6축 전멸이면 리포트를
안 만든다 (빈 감사는 감사가 아니다).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Task 28: quality-gates와 동일한 3-vocab로 통일 (CRITICAL/IMPORTANT/SUGGESTION).
# plugin-audit의 옛 HIGH→IMPORTANT, MEDIUM/LOW→SUGGESTION (§15.1 mapping) — verdict를
# 게이트하지 않는 정렬 전용 순위이므로 4→3 축약이 차단 동작을 바꾸지 않는다.
# sort_key의 .get(..., 99)는 미지 severity(예: 옛 데이터의 HIGH/MEDIUM/LOW)를 맨 뒤로
# 정렬한다 — 크래시하지 않고 뒤로 밀릴 뿐이므로 허용한다.
SEV_RANK = {"CRITICAL": 0, "IMPORTANT": 1, "SUGGESTION": 2}
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


_SEV_KO = (("CRITICAL", "심각"), ("IMPORTANT", "중요"), ("SUGGESTION", "제안"))


def status_line(findings: list) -> str:
    """제목 다음 줄 — 스크립트가 센 상태 문장. 0 인 등급은 빼고, 세 등급 밖(옛 HIGH 등)은 「기타」로 센다."""
    if not findings:
        return "감사를 마쳤다 — 보고된 발견 없음."
    parts = []
    rest = len(findings)
    for key, ko in _SEV_KO:
        n = 0
        for f in findings:
            if f.get("severity") == key:
                n += 1
        rest -= n
        if n:
            parts.append("%s %d" % (ko, n))
    if rest:
        parts.append("기타 %d" % rest)
    return "감사를 마쳤다 — 발견 %d개(%s)." % (len(findings), " · ".join(parts))


def val(x) -> str:
    """빈 칸은 None 대신 「(없음)」으로 쓴다."""
    return "(없음)" if x is None else str(x)


def where(ev: dict) -> str:
    """근거 위치 — 없는 칸을 None 으로 찍지 않는다."""
    file, line = ev.get("file"), ev.get("line")
    if file is None or file == "":
        return "(위치 없음)"
    if line is None:
        return "`%s`" % file
    return "`%s:%s`" % (file, line)


def ev_text(ev: dict, with_claim: bool = False) -> str:
    """근거 한 줄 — 위치, 그리고 있으면 주장과 인용. 없는 칸은 찍지 않는다."""
    body = ""
    if with_claim and ev.get("claim"):
        body = "%s: " % ev.get("claim")
    if ev.get("quote") is not None:
        body += str(ev.get("quote"))
    return where(ev) + (" — " + body if body else "")


def render(data: dict) -> str | None:
    meta = data.get("meta", {})
    findings = [f for f in data.get("findings", []) if f.get("status") == "reported"]
    axis_failures = data.get("axis_failures", [])
    degraded = data.get("degraded", [])

    if len(axis_failures) >= 6:
        return None  # AC-4(a): 빈 감사는 감사가 아니다

    target = meta.get("target", "plugin")
    lines = [f"# {target} 읽기전용 감사 — " + meta.get("date", "")]
    lines.append(status_line(findings))
    banners = []
    if axis_failures:
        banners.append(f"⚠ **축 {6 - len(axis_failures)}/6 완주** — {len(axis_failures)}개 축은 감사하지 못했다")
    # §4.1 truth table 세 상태. 옛 코드는 `not ran`만 보아 "돌았으나 실패"를
    # "미실행"과 같은 배너로 뭉갰다 — 사용자가 조치할 대상이 다르다(설치 vs 재실행).
    _cx = meta.get("codex", {})
    if not _cx.get("ran"):
        banners.append("⚠ **codex 독립 감사를 돌리지 않았다** — 다른 모델의 확인이 없다(LD4 모델 다양성 결손)")
    elif _cx.get("failed"):
        banners.append("⚠ **codex 독립 감사가 돌았지만 결과를 믿을 수 없다** — 다른 모델의 확인이 없다"
                       "(LD4 모델 다양성 결손, degraded)")
    for d in (_cx.get("dropped") or []):
        banners.append(f"⚠ **codex {d.get('collection')} {d.get('count')}건을 버렸다** — "
                       f"형식이 맞지 않았다({d.get('reason')})")
    if degraded:
        banners.append(f"⚠ **빠지거나 약해진 검사 {len(degraded)}건**(degraded) — 아래 「결손」 목록에 있다")
    if not findings:
        banners.append("⚠ **발견 0건** — 문제가 없어서인지 감사가 실패해서인지는 축 완주 수와 기록(journal)으로 확인하라")
    lines += banners + [""]

    findings.sort(key=sort_key)
    lines.append("## 발견")
    for f in findings:
        badge = " ⚑ 두 모델 독립 확인" if f.get("cross_model_confirmed") else ""
        plain = f.get("plain")
        if isinstance(plain, str) and plain.strip():
            head = f"{' '.join(plain.split())} ({f.get('title')} · {f.get('id')})"
        else:
            head = f"{f.get('title')} ({f.get('id')})"
        lines.append(f"### [{f.get('severity')}] {head}{badge}{deep_label(f)}")
        for ev in f.get("evidence", []):
            lines.append(f"- {ev_text(ev)}")
        lines.append(f"- 피해: {val(f.get('user_harm'))}")
        lines.append(f"- 권고: {val(f.get('recommendation'))}")
        lines.append(f"- 반대근거: {val(f.get('counter_argument'))}")
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
                            lines.append(f"  - {side_label}: 이 쪽을 받치는 근거는 보고되지 않았다(0건)")
                        else:
                            lines.append(f"  - {side_label}:")
                            for e in side_ev:
                                lines.append(f"    - {ev_text(e, with_claim=True)}")
                    if a.get("steelman_condition"):
                        lines.append(f"  - 스틸맨 조건: {a.get('steelman_condition')}")
                else:
                    lines.append(f"  - 답: {val(a.get('answer'))}")
                    for e in a.get("evidence") or []:
                        lines.append(f"    - {ev_text(e)}")
                lines.append(f"  - 근거: {val(a.get('reason'))}")
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
                lines.append(f"  - 근거: {val(d.get('reason'))}")
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
    args = ap.parse_args()
    data = json.loads(args.json.read_text(encoding="utf-8"))
    md = render(data)
    if md is None:
        print("[render] 6축 전멸 — 리포트를 만들지 않는다 (AC-4a). 실패 보고 후 중단.", file=sys.stderr)
        return 1
    args.out.write_text(md, encoding="utf-8")
    print(f"[render] {args.out} ({len(md.splitlines())} 줄)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
