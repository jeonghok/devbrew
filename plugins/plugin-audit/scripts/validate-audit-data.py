#!/usr/bin/env python3
"""validate-audit-data.py — 감사 데이터·산출물 검증 (design §16).

파이프라인은 자기를 회계할 수 없다 (§9.1) → 검증을 파이프라인 밖에 둔다. RED면 렌더링/커밋 금지.

--data: 렌더링 *전*. consent 3필드 · fanout 내부 정합(fanout_declared==consent.fanout) ·
        배정 D/OQ(meta.assigned_d/assigned_oq, 런타임 값) 완결성 · pending 잔존 0 ·
        codex 병합(B7) · cross-model 증발 · NOQ 원소 스키마 · gate-E→NOQ 회수.
--artifacts: 렌더링 *후*. 실제 파일을 본다 (골든 픽스처는 실물을 안 본다).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

VALID_VERDICT = {"confirmed", "withdrawn", "reclassified", "unverified"}


def validate_data(data: dict) -> list:
    errs: list[str] = []
    meta = data.get("meta", {})

    # 배정 D/OQ 세트는 project-init 전용 상수가 아니라 이 데이터셋의 런타임 값
    # (seed/target에서 도출) — plugin-audit 소비자마다 다를 수 있다.
    assigned_d = meta.get("assigned_d", [])
    assigned_oq = meta.get("assigned_oq", [])

    # consent 3필드
    consent = meta.get("consent", {})
    if not consent.get("approved") is True:
        errs.append("meta.consent.approved != true")
    if not consent.get("at"):
        errs.append("meta.consent.at 없음")
    if meta.get("fanout_declared") != consent.get("fanout"):
        errs.append(f"fanout_declared({meta.get('fanout_declared')}) != consent.fanout({consent.get('fanout')})")

    # D/OQ 완결성 (row 16 이빨 — backfill 안 하면 여기서 RED)
    d_ids = {x.get("id") for x in data.get("d_verdicts", [])}
    for did in assigned_d:
        if did not in d_ids:
            errs.append(f"배정 D {did}이 d_verdicts에 없다 (backfill 필요 — §6 post-1 step 2)")
    oq_ids = {x.get("id") for x in data.get("oq_answers", [])}
    for oid in assigned_oq:
        if oid not in oq_ids:
            errs.append(f"배정 OQ {oid}이 oq_answers에 없다 (backfill 필요)")
    for x in data.get("d_verdicts", []):
        if x.get("verdict") not in VALID_VERDICT:
            errs.append(f"{x.get('id')}/{x.get('source')} verdict 무효: {x.get('verdict')}")

    # claude-source 완결성 (SF2 — LD4 dead-axis masking backstop, /qg 2026-07-20):
    # 위 완결성 루프는 any-source 존재만, B7(아래)은 codex-source 존재만 강제한다. 대칭인
    # claude-source 검사가 없어, assemble backfill이 회귀해 dead Claude 축이 codex 답변에
    # 가려지면(codex만 있고 claude 부재) 두 검사 모두 통과해 validate가 GREEN이 된다 — dead 축은
    # 리포트에서 unverified로 드러나야 한다(§9.1). backfill이 매 배정 D/OQ에 claude 판정을
    # 보장하므로 이 검사는 무조건(codex.ran 무관)이며 정상 데이터엔 거짓 RED가 없다. 이 validator가
    # "producer를 회계"하려 존재하는데(docstring §9.1) 이 한 곳만 producer에 의존하던 비대칭을 닫는다.
    for did in assigned_d:
        if not any(x.get("id") == did and x.get("source") == "claude" for x in data.get("d_verdicts", [])):
            errs.append(f"배정 D {did}의 claude 판정 부재 (dead-axis masking — LD4, backfill 회귀)")
    for oid in assigned_oq:
        if not any(x.get("id") == oid and x.get("source") == "claude" for x in data.get("oq_answers", [])):
            errs.append(f"배정 OQ {oid}의 claude 답변 부재 (dead-axis masking — LD4)")

    # codex 병합 (B7): codex.ran이면 codex source 판정이 D·OQ에 있어야
    if meta.get("codex", {}).get("ran") is True:
        for did in assigned_d:
            if not any(x.get("id") == did and x.get("source") == "codex" for x in data.get("d_verdicts", [])):
                errs.append(f"codex.ran=true인데 {did}의 codex 판정 없음 (B7 — LD4 참칭)")
        for oid in assigned_oq:
            if not any(x.get("id") == oid and x.get("source") == "codex" for x in data.get("oq_answers", [])):
                errs.append(f"codex.ran=true인데 {oid}의 codex 답변 없음 (B7)")

    findings = data.get("findings", [])

    # steelman pending 잔존 0
    for f in findings:
        if f.get("steelman_condition") == "pending":
            errs.append(f"{f.get('id')}: steelman_condition=pending 잔존 (post-1 2b 미해소)")

    # NOQ 원소 스키마 (§9.7)
    for q in data.get("new_open_questions", []):
        if not q.get("why_not_gap"):
            errs.append(f"{q.get('id')}: why_not_gap 없음 (NOQ 필수)")
        if not q.get("source"):
            errs.append(f"{q.get('id')}: source 없음")
        ax = q.get("axis")
        # bool은 int의 subclass라 isinstance(ax, int)면 True/False가 1/0으로 새어든다 —
        # type(ax) is int로 bool을 거부한다 (codex final-review).
        if not (type(ax) is int and 1 <= ax <= 6):
            errs.append(f"{q.get('id')}: axis 1–6 아님 ({ax})")

    # gate-E → NOQ 회수 (row 8 이빨). scope-out NOQ는 **구조화 마커 reason_code로 식별**한다
    # (assemble-audit-data.py의 producer 계약). 지역화 산문 "범위 밖" 부분문자열은 legacy
    # 하위호환으로만 함께 받는다 — producer 문자열이 바뀌어도 거짓 RED가 나지 않도록.
    # identity 기반: 각 gate-E refuted finding **id**마다 대응하는 scope-out NOQ(같은 id)가
    # 있어야 한다. count 비교만 하면 무관/중복 scope-out NOQ가 특정 finding의 누락을 가려
    # 거짓 GREEN이 된다 (codex fix-review). NOQ.id는 producer(assemble)가 finding.id로 만든다.
    gate_e_ids = {f.get("id") for f in findings if f.get("status") == "refuted"
                  and (f.get("refutation") or {}).get("gate") == "E"}  # null refutation 크래시 가드 (:99와 대칭)
    scope_noq_ids = {q.get("id") for q in data.get("new_open_questions", [])
                     if q.get("reason_code") == "gate_e_scope_out"
                     or "범위 밖" in (q.get("why_not_gap") or "")}
    missing_scope = gate_e_ids - scope_noq_ids
    if missing_scope:
        errs.append(f"gate-E refuted {sorted(missing_scope)}의 scope-out NOQ 부재 "
                    f"(gate-E → NOQ 회수 미배선 — §9.7 🔴, 조용한 증발)")

    # cross-model 증발: dedup은 같은 source 안에서만
    by_id = {f.get("id"): f for f in findings}
    for f in findings:
        r = f.get("refutation") or {}
        if r.get("stage") == "dedup":
            tid = r.get("target_id")
            if not tid or tid not in by_id:
                errs.append(f"{f.get('id')}: dedup target_id 부재/무효 (구조화 필드)")
            elif by_id[tid].get("source") != f.get("source"):
                errs.append(f"{f.get('id')}: cross-source dedup (배선 버그 — LD4 산출물 증발)")

    # oq_ref enum
    for f in findings:
        ref = f.get("oq_ref")
        if ref is not None and ref not in assigned_oq:
            errs.append(f"{f.get('id')}: oq_ref enum 위반 ({ref})")

    return errs


def validate_artifacts(data: dict, repo_root: Path, report_path: Path) -> list:
    errs: list[str] = []
    readme = repo_root / "docs" / "audits" / "README.md"
    if not readme.is_file() or report_path.name not in readme.read_text(encoding="utf-8"):
        errs.append("docs/audits/README.md가 리포트를 링크하지 않음")
    claude_md = repo_root / "CLAUDE.md"
    if not claude_md.is_file() or "docs/audits/" not in claude_md.read_text(encoding="utf-8"):
        errs.append("CLAUDE.md에 docs/audits/ 포인터 없음")
    if data.get("degraded"):
        head = "\n".join(report_path.read_text(encoding="utf-8").splitlines()[:20])
        if "⚠" not in head and "degraded" not in head.lower():
            errs.append("degraded 비었지 않은데 리포트 첫 20줄에 배너 없음 (AC-3)")
    return errs


def main() -> int:
    # 참고: `mode` positional의 choices=["--data","--artifacts"]는 argparse가 "--"로 시작하는
    # 토큰을 positional 매칭 전에 옵션-형태("O")로 선분류해 절대 채워지지 않는다 (실측 확인).
    # 그래서 --data/--artifacts를 mutually-exclusive 옵션으로 정의한다 — CLI 표면(§16)은 동일.
    ap = argparse.ArgumentParser()
    group = ap.add_mutually_exclusive_group(required=True)
    group.add_argument("--data", type=Path)
    group.add_argument("--artifacts", type=Path)
    ap.add_argument("--repo-root", type=Path, default=Path("."))
    ap.add_argument("--report", type=Path, default=None)
    args = ap.parse_args()

    if args.data is not None:
        mode = "--data"
        data = json.loads(args.data.read_text(encoding="utf-8"))
        errs = validate_data(data)
    else:
        mode = "--artifacts"
        data = json.loads(args.artifacts.read_text(encoding="utf-8"))
        errs = validate_artifacts(data, args.repo_root, args.report or args.artifacts)

    if errs:
        print(f"[validate-audit-data] RED ({mode}) — {len(errs)}건", file=sys.stderr)
        for e in errs:
            print(f"  ✗ {e}", file=sys.stderr)
        return 1
    print(f"[validate-audit-data] GREEN ({mode})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
