#!/usr/bin/env python3
"""post-1 결정론 조립 — 엔진 §6 런북을 코드로. Workflow return + codex side-input + meta → audit-data.json."""
import argparse, json, sys
from pathlib import Path


def load(p):
    return json.loads(Path(p).read_text(encoding="utf-8"))


def ev_keys(f):
    return {(e.get("file"), e.get("line")) for e in f.get("evidence", [])}


def assemble(wf, codex_side, meta, assigned, repo_root, do_grounding):
    findings = [dict(f) for f in wf["findings"]]
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

    # (3) unverified backfill (dead/incomplete axis — assigned에 있으나 부재)
    have_d = {v["id"] for v in d_verdicts}
    for did in assigned.get("assigned_d", []):
        if did not in have_d:
            d_verdicts.append({"id": did, "verdict": "unverified",
                               "reason": "axis incomplete — backfilled", "source": "claude"})
    have_oq = {v["id"] for v in oq_answers}
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

    # (5) gate-E refuted → NOQ 변환
    for f in findings:
        if f.get("status") == "refuted" and (f.get("refutation") or {}).get("gate") == "E":
            noq.append({"id": f["id"], "axis": f.get("axis"),
                        "observation": f.get("title", ""), "why_not_gap": "scope-out (gate E)",
                        "source": f.get("source", "claude")})

    # (7) grounding (Task 14) — --no-grounding이면 annotate-only skip
    if do_grounding:
        ground = _load_grounding()
        for f in findings:
            if f.get("status") in ("reported", None):
                ground(f, repo_root)   # sets grounding_verified, may discard/line-correct

    # (6) meta 부착 + 최상위 degraded
    degraded = list(wf.get("degraded_events", [])) + list(meta.get("pre1_degraded", []))
    out_meta = {k: meta[k] for k in ("date", "fanout_declared", "consent", "codex", "target", "seed_provided") if k in meta}
    out_meta["assigned_d"] = assigned.get("assigned_d", [])
    out_meta["assigned_oq"] = assigned.get("assigned_oq", [])
    return {"meta": out_meta, "findings": findings, "d_verdicts": d_verdicts,
            "oq_answers": oq_answers, "new_open_questions": noq,
            "axis_failures": wf.get("axis_failures", []), "degraded": degraded}


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
