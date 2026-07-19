#!/usr/bin/env python3
"""AC-6 frozen-fixture 추출기 — 1회용.

baseline `docs/audits/2026-07-15-project-init-audit-data.json`(진리원천)을 읽어
generalized `assemble-audit-data.py`가 소비하는 4개 입력(workflow-return · codex-side ·
meta · assigned)으로 되쪼갠다. baseline이 codex D/OQ/NOQ의 유일 소스이므로 codex 필드는
자기참조(passthrough는 tautological) — 이 추출기가 만드는 fixture는 test_ac6_regression.py의
**조립 변환 재현** 검증에만 쓰인다. baseline 자체(golden truth)는 건드리지 않는다.

Run once, commit the 4 generated JSONs (frozen — baseline이 바뀌지 않는 한 재실행 불필요).
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[5]  # fixtures→tests→scripts→plugin-audit→plugins→repo
BASELINE = ROOT / "docs/audits/2026-07-15-project-init-audit-data.json"
OUT_DIR = Path(__file__).resolve().parent


def load_baseline():
    return json.loads(BASELINE.read_text(encoding="utf-8"))


def split_by_source(rows, source):
    return [dict(r) for r in rows if r.get("source") == source]


def build():
    base = load_baseline()

    # --- ac6_workflow_return.json ---
    findings = []
    for f in base["findings"]:
        f = dict(f)
        f.pop("cross_model_confirmed", None)
        findings.append(f)
    workflow_return = {
        "findings": findings,
        "d_verdicts": split_by_source(base["d_verdicts"], "claude"),
        "oq_answers": split_by_source(base["oq_answers"], "claude"),
        "new_open_questions": split_by_source(base["new_open_questions"], "claude"),
        "axis_failures": base.get("axis_failures", []),
        "degraded_events": [],
    }

    # --- ac6_codex_side.json ---
    codex_side = {
        "d_verdicts": split_by_source(base["d_verdicts"], "codex"),
        "oq_answers": split_by_source(base["oq_answers"], "codex"),
        "new_open_questions": split_by_source(base["new_open_questions"], "codex"),
    }

    # --- ac6_meta.json ---
    base_meta = base["meta"]
    meta = dict(base_meta)
    meta["target"] = "project-init"
    meta["seed_provided"] = True
    meta["consent"] = {**base_meta["consent"], "fanout": base_meta["fanout_declared"]}

    # --- ac6_assigned.json ---
    # ⚠ derive from baseline's ACTUAL d_verdict/oq ids (do not assume D1-D5/OQ1-OQ6) —
    # this run had no backfill (all assigned present), so assigned must equal exactly
    # the ids that already appear, or backfill will falsely fire and inject `unverified`
    # rows that never existed in the baseline.
    assigned_d = sorted({v["id"] for v in base["d_verdicts"]},
                         key=lambda s: int(s[1:]) if s[1:].isdigit() else s)
    assigned_oq = sorted({v["id"] for v in base["oq_answers"]},
                          key=lambda s: int(s[2:]) if s[2:].isdigit() else s)
    assigned = {"assigned_d": assigned_d, "assigned_oq": assigned_oq}

    (OUT_DIR / "ac6_workflow_return.json").write_text(
        json.dumps(workflow_return, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT_DIR / "ac6_codex_side.json").write_text(
        json.dumps(codex_side, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT_DIR / "ac6_meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUT_DIR / "ac6_assigned.json").write_text(
        json.dumps(assigned, ensure_ascii=False, indent=2), encoding="utf-8")

    print("assigned_d:", assigned_d)
    print("assigned_oq:", assigned_oq)
    print("wrote:", OUT_DIR)


if __name__ == "__main__":
    build()
