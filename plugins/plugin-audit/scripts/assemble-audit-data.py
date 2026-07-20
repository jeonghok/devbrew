#!/usr/bin/env python3
"""post-1 결정론 조립 — 엔진 §6 런북을 코드로. Workflow return + codex side-input + meta → audit-data.json."""
import argparse, json, sys
from pathlib import Path


def load(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def _sanitize_finding(f):
    """codex findings는 schema 미검증으로 findings에 병합된다(audit-workflow.js) → evidence/refutation
    원소가 비정상형(비-dict evidence·list file/line·정수 quote·비-dict refutation)일 수 있고, 그대로 두면
    ev_keys(unhashable set-key/.get())·gate-E(.get())·grounding·validate·render 어디서든 크래시한다.
    **ingestion에서 한 번** 정규형으로 강등하면 downstream 소비자 전부가 malformed 입력에서 안전해진다
    (근본 봉쇄 — 소비자마다 개별 가드하는 whack-a-mole 대신, codex re-verify round-2). claude findings는
    이미 AXIS_SCHEMA로 정형이라 이 정규화가 no-op이다."""
    g = dict(f)
    ev = []
    for e in (g.get("evidence") or []):
        if not isinstance(e, dict):
            continue   # 비-dict evidence 원소 드롭
        ne = dict(e)
        ne["file"] = e.get("file") if isinstance(e.get("file"), str) else ""
        ne["quote"] = e.get("quote") if isinstance(e.get("quote"), str) else ""
        ne["line"] = e.get("line") if (isinstance(e.get("line"), int) and not isinstance(e.get("line"), bool)) else None
        ev.append(ne)
    g["evidence"] = ev
    if "refutation" in g and not isinstance(g.get("refutation"), dict):
        g["refutation"] = None   # 비-dict refutation → None (gate-E 안전 + validate가 refuted+None을 malformed RED)
    return g


def ev_keys(f):
    # 대표(첫) evidence만 — cross_model_confirmed는 "같은 file:line을 독립적으로
    # 지목"(§9.2)한다는 뜻이고, 이는 finding의 주 근거(evidence[0])를 가리킨다.
    # 전체 evidence 배열의 합집합으로 넓히면 finding이 부수적으로 인용한 배경
    # 파일이 우연히 겹치는 것까지 "교차확인"으로 오판한다 (2026-07-15 baseline
    # 재현에서 실측: A1-2/A3-1/A6-1/CX-1/CX-5가 전체-합집합 기준으로는 false
    # positive였다 — AC-6).
    ev = f.get("evidence") or []
    if not ev:
        return set()
    e = ev[0]
    return {(e.get("file"), e.get("line"))}


def assemble(wf, codex_side, meta, assigned, repo_root, do_grounding):
    findings = [_sanitize_finding(f) for f in wf["findings"]]   # codex-source malformed 입력 근본 봉쇄
    d_verdicts = list(wf.get("d_verdicts", []))
    oq_answers = list(wf.get("oq_answers", []))
    noq = list(wf.get("new_open_questions", []))
    # workflow return의 claude-source 기본값 stamp (source 미부착 시)
    for v in d_verdicts + oq_answers + noq:
        v.setdefault("source", "claude")

    # (2) codex side-channel merge (blind-symmetry §9.3)
    for v in codex_side.get("d_verdicts", []):
        d_verdicts.append({**v, "source": "codex"})
    for v in codex_side.get("oq_answers", []):
        oq_answers.append({**v, "source": "codex"})
    for v in codex_side.get("new_open_questions", []):
        noq.append({**v, "source": "codex"})

    # (3) unverified backfill (dead/incomplete axis — assigned에 있으나 *Claude* 판정 부재).
    # have_d/have_oq는 codex merge(2) *후*의 전체 목록(any-source)이 아니라 **claude source만**
    # 봐야 한다: codex가 답한 축이라도 Claude가 죽었으면 'axis incomplete' 정직성 backfill이
    # 떠야 한다. any-source로 보면 codex 답변이 죽은 Claude 축을 조용히 가린다 (LD4 정직성 갭).
    have_d = {v["id"] for v in d_verdicts if v.get("source") == "claude"}
    for did in assigned.get("assigned_d", []):
        if did not in have_d:
            d_verdicts.append({"id": did, "verdict": "unverified",
                               "reason": "axis incomplete — backfilled", "source": "claude"})
    have_oq = {v["id"] for v in oq_answers if v.get("source") == "claude"}
    for oid in assigned.get("assigned_oq", []):
        if oid not in have_oq:
            # steelman_condition enum(a|b|c|d|none|pending)을 침범하지 않음 — reason으로만 unverified 표시
            oq_answers.append({"id": oid, "answer": None,
                               "reason": "axis incomplete — backfilled (unverified)", "source": "claude"})

    # (4) cross_model_confirmed (claude∪codex file:line 교집합)
    claude_ev, codex_ev = set(), set()
    for f in findings:
        (claude_ev if f.get("source") == "claude" else codex_ev).update(ev_keys(f))
    other = {"claude": codex_ev, "codex": claude_ev}
    for f in findings:
        f["cross_model_confirmed"] = bool(ev_keys(f) & other.get(f.get("source"), set()))

    # (5) gate-E refuted → NOQ 변환. consumer(validate-audit-data.py)와의 계약:
    # scope-out NOQ는 **구조화 마커 `reason_code: "gate_e_scope_out"`**로 식별한다 (지역화 산문
    # "범위 밖" 부분문자열 매칭에 의존하지 않음 — producer 문자열이 바뀌면 조용히 거짓 RED가
    # 나던 버그). axis는 validate가 `isinstance(int) and 1<=x<=6`을 요구하므로 정수로 강제한다
    # ("3" 같은 문자열 axis가 두 번째 거짓 RED 경로였다).
    for f in findings:
        if f.get("status") == "refuted" and (f.get("refutation") or {}).get("gate") == "E":
            ax = f.get("axis")
            # canonical 1–6 문자열만 정수로 강제한다. 3.9(float)/True(bool)/"10" 같은 값은
            # 그대로 두어 validate가 무효 axis로 보고하게 한다 (silent 의미 변경 금지, codex).
            if isinstance(ax, str) and ax.strip() in {"1", "2", "3", "4", "5", "6"}:
                ax = int(ax.strip())
            noq.append({"id": f["id"], "axis": ax,
                        "observation": f.get("title", ""),
                        "why_not_gap": "scope-out (gate E) — 범위 밖",
                        "reason_code": "gate_e_scope_out",
                        "source": f.get("source", "claude")})

    # (7) grounding (Task 14) — --no-grounding이면 annotate-only skip
    if do_grounding:
        ground = _load_grounding()
        for f in findings:
            if f.get("status") in ("reported", None):
                ground(f, repo_root)   # sets grounding_verified, may discard/line-correct

    # (6) meta 부착 + 최상위 degraded. grounding이 finding에 붙인 degraded_events
    # (citation_absent/discarded · citation_unreadable · line_drift)를 최상위 degraded[]로
    # 승격한다 — 폐기된 finding이 정직성 배너에 흔적을 남겨야 한다 (AC-3, 조용한 증발 금지).
    # renderer가 기대하는 {what, why} 모양으로 정규화한다 — pre-0/pre-1 게이트
    # (check-plugin-structure.sh 등)는 degraded를 **평문 문자열**로 방출하므로, 문자열을
    # {what, why}로 감싸지 않으면 render-audit-report.py가 x.get('what')에서 크래시한다.
    raw_degraded = list(wf.get("degraded_events", [])) + list(meta.get("pre1_degraded", []))
    degraded = [d if isinstance(d, dict) else {"what": str(d), "why": "pre-0/pre-1 degrade"}
                for d in raw_degraded]
    for f in findings:
        for gev in f.get("degraded_events", []):
            degraded.append(_grounding_degraded_note(gev))
    out_meta = {k: meta[k] for k in ("date", "fanout_declared", "consent", "codex", "target", "seed_provided") if k in meta}
    out_meta["assigned_d"] = assigned.get("assigned_d", [])
    out_meta["assigned_oq"] = assigned.get("assigned_oq", [])
    return {"meta": out_meta, "findings": findings, "d_verdicts": d_verdicts,
            "oq_answers": oq_answers, "new_open_questions": noq,
            "axis_failures": wf.get("axis_failures", []), "degraded": degraded}


def _grounding_degraded_note(gev):
    """grounding이 finding에 남긴 degraded_event({id,kind,...})를 renderer가 기대하는
    최상위 {what, why} 모양으로 변환한다 (AC-3 정직성 배너)."""
    fid, kind = gev.get("id"), gev.get("kind")
    if kind == "citation_absent":
        return {"what": f"{fid} 폐기 — 인용이 파일에 부재",
                "why": f"grounding citation_absent ({gev.get('file')})"}
    if kind == "citation_unreadable":
        return {"what": f"{fid} — 인용 파일 판독 불가",
                "why": f"grounding citation_unreadable ({gev.get('file')})"}
    if kind == "line_drift":
        return {"what": f"{fid} — 인용 줄 보정",
                "why": f"grounding line_drift {gev.get('from')}→{gev.get('to')}"}
    return {"what": f"{fid} — grounding {kind}", "why": "grounding degraded"}


def _load_grounding():
    import importlib.util
    p = Path(__file__).resolve().parent / "check-grounding.py"
    spec = importlib.util.spec_from_file_location("check_grounding", p)
    if spec is None or spec.loader is None:
        raise RuntimeError("check-grounding.py not loadable")
    mod = importlib.util.module_from_spec(spec); spec.loader.exec_module(mod)
    return mod.ground_finding


def main(argv):
    ap = argparse.ArgumentParser()
    for f in ("workflow-return", "codex-side", "meta", "assigned", "out"):
        ap.add_argument(f"--{f}", required=True)
    ap.add_argument("--repo-root", default=".")
    ap.add_argument("--no-grounding", action="store_true")
    a = ap.parse_args(argv)
    data = assemble(load(a.workflow_return), load(a.codex_side), load(a.meta),
                    load(a.assigned), Path(a.repo_root), not a.no_grounding)
    Path(a.out).write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
