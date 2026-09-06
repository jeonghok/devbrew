#!/usr/bin/env python3
"""docreview_route.py — critic · codex · recritic 세 원장을 합쳐 finding 별 최종 처분을 확정한다.

결정론은 설계 §6.3 표뿐이다. 회계는 형제 `adjudication.py` 의 Ledger 에 위임한다.
서브커맨드: prepare-recritic(익명화 + degrade 판정) · finalize(재비판 반영 · 프로필 강제 · 보호/불변 ·
id/계보 · 사후 auto decide · 원장 기록).

리뷰어 산출물: 펜스 ```docreview-layer1 / ```docreview-layer2 (YAML 리스트) · ```docreview-recritic
(YAML 매핑 {verdicts, added}). 같은 이름이 여럿이면 마지막 블록.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))  # bare .parent — 배포 지점의 형제를 읽는다
from adjudication import Ledger  # noqa: E402
from docreview_anchor import classify_anchor, refs_of  # noqa: E402
from docreview_state import (  # noqa: E402
    RANK, fail, load_profile, load_state, record_findings, save_state, yaml,
)

BLOCK_RE = r"```%s[ \t]*\n(.*?)\n```"
DISPOSITIONS = tuple(sorted(RANK, key=lambda k: -RANK[k]))  # decide, ask, fix, defer, drop


def extract_block(text: str, name: str):
    ms = re.findall(BLOCK_RE % re.escape(name), text, re.S)
    if not ms:
        return None, "missing"
    try:
        return yaml.safe_load(ms[-1]), None
    except Exception:  # yaml.YAMLError 계열 전부 — 파손은 종류를 가리지 않는다
        return None, "broken"


def _refs(v):
    if v is None:
        return []
    if isinstance(v, str):
        return [x.strip() for x in re.split(r"[,\s]+", v.strip("[] ")) if x.strip()]
    if isinstance(v, list):
        return [str(x) for x in v]
    return []


def normalize(item, layer_default, prefix, idx, ledger):
    tag = "%s%d" % (prefix, idx)
    if not isinstance(item, dict):
        ledger.hold(tag, "항목 파손: not a mapping")
        return None
    anchor = str(item.get("anchor") or "").strip()
    summary = str(item.get("summary") or "").strip()
    if not anchor.startswith("#") or not summary:
        ledger.hold(tag, "항목 파손: anchor/summary 부재")
        return None
    disp = item.get("disposition")
    disp = str(disp).strip() if disp else None
    if disp is not None and disp not in RANK:
        ledger.coerced("disposition", disp, None)
        disp = None
    try:
        layer = int(item.get("layer") or layer_default)
    except (TypeError, ValueError):
        layer = layer_default
    return {
        "ref": str(item.get("ref") or tag), "layer": 1 if layer == 1 else 2,
        "category": str(item.get("category") or "other"), "anchor": anchor,
        "disposition": disp, "summary": summary,
        "edit_scope": str(item.get("edit_scope") or anchor), "blocks": _refs(item.get("blocks")),
        "supersedes": (str(item["supersedes"]) if item.get("supersedes") else None),
        "evidence": (str(item["evidence"]) if item.get("evidence") else None),
    }


def _bucket(it) -> str:
    return hashlib.sha1(("%d|%s|%s" % (it["layer"], it["category"], it["anchor"])).encode("utf-8")).hexdigest()[:8]


def _permit_covers(st, n, anchor) -> bool:
    """이 라운드에 그 앵커를 겨눈 permit 이 있었는가.

    실행 노트(R1) — `consumed` 로 걸러지지 않는다. cases.sh 의 `next_round` 헬퍼는
    begin-round 직후 observe-diff 까지 마치므로, route.finalize 가 도는 시점엔 이번
    라운드에 실제로 적용된 permit 은 이미 `consumed: True` 다(T21). `not consumed` 로
    거르면 그 라운드에 열린 «유효한 편집 창» 안에서 나온 새 finding(T11)이 매번
    엄격 존재검사를 실패해 보호 승격에 삼켜진다 — permit 이 있었다는 사실 자체가
    승격을 막아야 할 이유이고, 그 permit 이 이미 관측을 마쳤다는 사실은 무관하다.
    """
    for _d, p in st["permits"].items():
        if int(p["round"]) == n and anchor in p["apply_anchors"]:
            return True
    return False


# ── prepare-recritic ─────────────────────────────────────────────────────
def cmd_prepare(a) -> int:
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    L = Ledger()
    events = []          # finalize 가 같은 Ledger 를 재구성하기 위한 호출 기록(위치 인자만)

    def ev(name, *args):
        getattr(L, name)(*args)
        events.append([name] + list(args))

    degrade = {"critic_dead": False, "layer2_missing": False, "codex_absent": False, "codex_reason": None}
    items = []
    text = Path(a.critic).read_text(encoding="utf-8") if Path(a.critic).is_file() else ""
    l1, e1 = extract_block(text, "docreview-layer1")
    if e1 or not isinstance(l1, list):
        degrade["critic_dead"] = True
        ev("source_failed", "doc-critic", "layer1 block %s" % (e1 or "not a list"), True)
    else:
        for i, it in enumerate(l1, 1):
            n1 = normalize(it, 1, "c", i, L)
            if n1:
                items.append(("critic", n1))
        l2, e2 = extract_block(text, "docreview-layer2")
        if e2 or not isinstance(l2, list):
            if prof["layer_rubric"].get("layer2"):
                degrade["layer2_missing"] = True
                ev("uncountable", "layer2", "block %s" % (e2 or "not a list"))
        else:
            for i, it in enumerate(l2, 1):
                n2 = normalize(it, 2, "c", 100 + i, L)
                if n2:
                    items.append(("critic", n2))
    cx = None
    if a.codex and Path(a.codex).is_file():
        try:
            cx = yaml.safe_load(Path(a.codex).read_text(encoding="utf-8"))
        except Exception:
            cx = None
    meta = cx.get("meta") if isinstance(cx, dict) and isinstance(cx.get("meta"), dict) else {}
    if not isinstance(cx, dict) or meta.get("codex_failed", True):
        degrade["codex_absent"] = True
        degrade["codex_reason"] = str(meta.get("reason") or "yaml_missing_or_broken")
        ev("source_failed", "codex", degrade["codex_reason"], False)
    else:
        for i, it in enumerate(cx.get("findings") or [], 1):
            nx = normalize(it, 2, "x", i, L)
            if nx:
                items.append(("codex", nx))
    # 익명화 — 출처 순서를 복원할 수 없게 정렬한다(P9)
    items.sort(key=lambda t: (t[1]["layer"], t[1]["anchor"], t[1]["category"],
                              hashlib.sha1(t[1]["summary"].encode("utf-8")).hexdigest()))
    ref2f = {(src, it["ref"]): "f%d" % k for k, (src, it) in enumerate(items, 1)}
    pending = []
    for k, (src, it) in enumerate(items, 1):
        pub = dict(it)
        pub["f"] = "f%d" % k
        pub["blocks"] = [ref2f.get((src, r), r) for r in it["blocks"]]
        pub.pop("ref", None)
        pending.append({"f": pub["f"], "source": src, "finding": pub})
    st["pending_recritic"] = {"items": pending, "degrade": degrade, "events": events}
    save_state(a.state_dir, st, "prepare-recritic (%d items%s)" % (len(pending), ", critic dead" if degrade["critic_dead"] else ""))
    print(json.dumps({"ok": not degrade["critic_dead"], "items": [p["finding"] for p in pending],
                      "degrade": degrade}, ensure_ascii=False, indent=1))
    return 4 if degrade["critic_dead"] else 0


# ── finalize ─────────────────────────────────────────────────────────────
def _decision_view(it, doc):
    nref = None
    if doc and Path(doc).is_file():
        nref = len(refs_of(doc, it["anchor"]))
    basis = it.get("evidence")
    if not basis:
        basis = "finding 없이 바뀜" if it["category"] == "frozen_change" else "(근거 없음)"
    return {"change": it["summary"], "basis": basis, "alternatives": ["채택(적용)", "기각(원복)", "보류"],
            "impact": "%s · 인용 %s 섹션" % (it["anchor"], nref if nref is not None else "?"),
            "auto": it.get("origin") == "auto"}


def _rk(fid):  # id → (round, k) 정렬 키
    tail = fid.split("#r", 1)[1]
    r, k = tail.split(".", 1)
    return (int(r), int(k))


def cmd_finalize(a) -> int:
    st = load_state(a.state_dir)
    prof = load_profile(st["profile"])
    n = int(st["round"])
    pend = st.get("pending_recritic")
    if not pend:
        return fail("no_pending_recritic")
    L = Ledger(items="open")
    for e in pend.get("events", []):
        getattr(L, e[0])(*e[1:])
    degrade = dict(pend["degrade"])
    degrade.setdefault("recritic_dead", None)
    items = {p["f"]: dict(p["finding"], _source=p["source"]) for p in pend["items"]}

    verdicts, added = [], []
    if a.recritic_skipped:
        degrade["recritic_dead"] = "skipped"
        L.source_failed("doc-recritic", "kill switch", primary=False)
    else:
        text = Path(a.recritic).read_text(encoding="utf-8") if a.recritic and Path(a.recritic).is_file() else ""
        blk, err = extract_block(text, "docreview-recritic")
        if err or not isinstance(blk, dict):
            degrade["recritic_dead"] = err or "not a mapping"
            L.source_failed("doc-recritic", degrade["recritic_dead"], primary=False)
        else:
            verdicts = blk.get("verdicts") or []
            added = blk.get("added") or []

    same_as = []
    for v in verdicts:
        if not isinstance(v, dict):
            L.hold("recritic-verdict", "항목 파손: not a mapping")
            continue
        f = str(v.get("f") or "")
        it = items.get(f)
        if not it:
            L.hold("recritic:%s" % f, "항목 파손: unknown f")
            continue
        vd = str(v.get("verdict") or "confirm")
        to = v.get("to")
        for s in _refs(v.get("same_as")):
            same_as.append((f, s))
        if vd == "reject":
            if v.get("evidence"):
                it["_rejected"] = str(v["evidence"])
                L.reject(f, str(v["evidence"]))
            else:
                L.coerced("verdict", "reject", "confirm")
        elif vd == "raise":
            if to in RANK and (it["disposition"] is None or RANK[to] > RANK[it["disposition"]]):
                it["disposition"] = to
            elif to in RANK:
                L.coerced("disposition", to, it["disposition"])
            if v.get("layer") == 1 and it["layer"] == 2:
                it["layer"] = 1
        else:
            if it["disposition"] is None and to in RANK:
                it["disposition"] = to
    for f, it in items.items():
        if it["disposition"] is None:
            it["disposition"] = "ask"
            L.coerced("disposition", None, "ask")
    for i, ad in enumerate(added, 1):
        na = normalize(ad, 2, "a", i, L)
        if na:
            na.pop("ref", None)
            na["f"] = "a%d" % i
            na["_source"] = "recritic"
            if na["disposition"] is None:
                na["disposition"] = "ask"
                L.coerced("disposition", None, "ask")
            items[na["f"]] = na

    # same_as — union-find, 높은 처분이 남는다(전순서 max)
    parent = {f: f for f in items}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for x, y in same_as:
        if x in parent and y in parent:
            parent[find(x)] = find(y)
    groups = {}
    for f in items:
        groups.setdefault(find(f), []).append(f)
    keep_of = {}
    for _root, members in groups.items():
        live = [m for m in members if not items[m].get("_rejected")]
        if not live:
            continue
        keep = max(live, key=lambda m: (RANK[items[m]["disposition"]], m))
        for m in live:
            keep_of[m] = keep
            if m != keep:
                items[m]["_absorbed_into"] = keep
                L.absorbed(m, into=keep)

    # 프로필 · 보호 · 불변
    sections = st["snapshots"][str(n)]["sections"]
    allowed = prof["allowed_dispositions"]
    final, rejected_items = [], []
    for f, it in items.items():
        if it.get("_absorbed_into"):
            continue
        if it.get("_rejected"):
            it["state"] = "rejected"
            it["origin"] = "reviewer"
            rejected_items.append(it)
            continue
        d = it["disposition"]
        if d not in allowed:
            if d == "defer":
                new = "ask"
            else:
                higher = [x for x in allowed if RANK[x] > RANK[d]]
                new = min(higher, key=lambda x: RANK[x]) if higher else "decide"
            L.coerced("disposition", d, new)
            it["disposition"] = new
            d = new
        cls = classify_anchor(it["anchor"], sections, prof)
        it["origin"] = "reviewer"
        it["immutable"] = cls["immutable"]
        it["kind"] = "pre"
        if cls["immutable"] and d == "fix":
            it["promoted_from"] = "fix"
            it["promotion"] = "immutable"
            it["disposition"] = "decide"
            it["origin"] = "auto"
        elif cls["protected"] and d != "decide" and not _permit_covers(st, n, it["anchor"]):
            it["promoted_from"] = d
            it["promotion"] = "protected"
            it["disposition"] = "decide"
            it["origin"] = "auto"
        final.append(it)

    # 사후·이월 auto decide — 얼림 diff(post) · check-intent 거부(pre) · expired 재상승(pre)
    if a.diff and Path(a.diff).is_file():
        diff = json.loads(Path(a.diff).read_text(encoding="utf-8"))
        for c in diff.get("changed", []):
            cls = classify_anchor(c["anchor"], sections, prof)
            final.append({"f": None, "layer": 1 if cls["protected"] else 2, "category": "frozen_change",
                          "anchor": c["anchor"], "disposition": "decide",
                          "summary": "finding 없이 바뀜: %s (%s)" % (c.get("title") or c["anchor"], c["kind"]),
                          "edit_scope": c["anchor"], "blocks": [], "supersedes": None,
                          "evidence": c["evidence"], "origin": "auto", "kind": "post",
                          "prev_hash": c.get("old_hash"), "immutable": cls["immutable"], "_source": "diff"})
    prev = st["findings"]
    keep_esc = []
    for e in st.get("escalated") or []:
        if int(e["round"]) != n - 1:
            keep_esc.append(e)
            continue
        f0 = prev.get(e["finding_id"])
        if not f0:
            continue
        final.append({"f": None, "layer": f0["layer"], "category": f0["category"], "anchor": f0["anchor"],
                      "disposition": "decide", "summary": "check-intent 거부 후 상향: " + (f0.get("summary") or ""),
                      "edit_scope": f0.get("edit_scope") or f0["anchor"], "blocks": [],
                      "supersedes": e["finding_id"], "evidence": e.get("reason"), "origin": "auto",
                      "kind": "pre", "immutable": bool(f0.get("immutable")), "_source": "escalated"})
    st["escalated"] = keep_esc
    for r in st.get("reraise") or []:
        f0 = prev.get(r["finding_id"])
        if not f0:
            continue
        final.append({"f": None, "layer": f0["layer"], "category": f0["category"], "anchor": f0["anchor"],
                      "disposition": "decide", "summary": "채택 후 미적용(expired): " + (f0.get("summary") or ""),
                      "edit_scope": f0.get("edit_scope") or f0["anchor"], "blocks": [],
                      "supersedes": r["finding_id"], "evidence": r.get("reason"), "origin": "auto",
                      "kind": "pre", "immutable": bool(f0.get("immutable")), "_source": "reraise"})
    st["reraise"] = []

    # id · 계보 — 리뷰어 항목은 f 순, 사후 항목은 그 뒤
    def order(it):
        f = it.get("f") or ""
        return (0 if f else 1, int(f[1:]) if f[1:].isdigit() else 0, f[:1])
    everything = sorted(final + rejected_items, key=order)
    counters = {}
    open_prev = {}
    from docreview_state import is_open  # noqa: E402  (순환 없음 — state 는 leaf)
    for fid, pf in prev.items():
        if is_open(st, fid):
            open_prev.setdefault(pf["bucket"], []).append(fid)
    for b in open_prev:
        open_prev[b].sort(key=_rk)
    for it in everything:
        b = _bucket(it)
        k = counters.get(b, 0) + 1
        counters[b] = k
        it["bucket"] = b
        it["id"] = "%s#r%d.%d" % (b, n, k)
    bucket_conflicts = sum(1 for v in counters.values() if v > 1)

    lineage_mismatch = 0
    revived = []

    def resolve_lineage(it):
        nonlocal lineage_mismatch
        b = it["bucket"]
        lin = None
        sup = it.get("supersedes")
        if sup:
            if sup in prev:
                lin = prev[sup]["lineage"]
                q = open_prev.get(prev[sup]["bucket"])
                if q and sup in q:
                    q.remove(sup)
            else:
                lineage_mismatch += 1
                it["supersedes"] = None
        if lin is None:
            q = open_prev.get(b) or []
            if q:
                sup2 = q.pop(0)
                lin = prev[sup2]["lineage"]
                it["supersedes"] = sup2
        if lin is None:
            lin = it["id"]
            same_b = [fid for fid, pf in prev.items() if pf.get("bucket") == b]
            if same_b:
                last = max(same_b, key=_rk)
                rj = st["rejected_lineages"].get(prev[last]["lineage"])
                if rj:
                    revived.append({"id": it["id"], "rejected_lineage": prev[last]["lineage"],
                                    "why": rj.get("why"), "by": rj.get("by")})
        it["lineage"] = lin

    # 실행 노트(R1) — id/bucket 은 f 순(원본 `everything` 순서)으로 매기지만, 계보
    # 연결은 **명시 `supersedes` 를 먼저** 해소한 뒤에 자동 연결(같은 bucket 의 열린
    # 이전 finding 하나씩)을 돌린다. 익명화 정렬(anchor·category·hash) 이 f-번호를
    # 정하므로, 같은 라운드에 명시 지목 하나 + 무지목 하나가 같은 bucket 에 들어오면
    # f-번호 순서가 "무지목이 먼저" 가 될 수 있다 — 단일 패스로 처리하면 무지목 항목이
    # 큐가 아직 안 비었다고 보고 지목된 조상에 먼저 연결해 버리고(명시 지목 쪽은
    # `prev` 직접 조회라 그래도 같은 조상에 도달은 하지만), 결과적으로 둘 다 같은
    # 계보에 몰린다(T14·T15 가 기대하는 "지목된 조상은 자동 연결에서 빠진다" 위반).
    # 명시 지목을 먼저 큐에서 제거하면 무지목 항목은 그 다음 열린 항목(없으면 새
    # 계보)으로 정확히 갈린다.
    for it in everything:
        if it.get("supersedes"):
            resolve_lineage(it)
    for it in everything:
        if "lineage" not in it:
            resolve_lineage(it)
    for it in rejected_items:
        st["rejected_lineages"][it["lineage"]] = {"by": "recritic", "why": it["_rejected"], "round": n}

    f2id = {it["f"]: it["id"] for it in final if it.get("f")}
    for it in final:
        out = []
        for r in it.get("blocks") or []:
            r2 = keep_of.get(r, r)
            if r2 in f2id:
                out.append(f2id[r2])
        it["blocks"] = out
        if it["disposition"] == "decide":
            it["decision_view"] = _decision_view(it, a.doc)

    for it in final:
        L.accept(it["id"])
    record_findings(st, final + rejected_items, n)

    report = L.report()
    adv = list(report["reasons"])
    if degrade.get("codex_absent"):
        adv.insert(0, "codex 없음 — 모델 다양성 0 (%s)" % degrade.get("codex_reason"))
    if degrade.get("recritic_dead"):
        adv.append("기각 경로 0 — 오탐이 걸러지지 않았다 (doc-recritic %s)" % degrade["recritic_dead"])
    if degrade.get("layer2_missing"):
        adv.append("상세 미검증 — 층 2 블록 없음")
    if st["snapshots"][str(n)].get("headingless"):
        adv.append("앵커 불가 — 얼림·보호 부류 비활성, 모든 fix 가 문서 전체 범위")

    def pub(it):
        return {k: v for k, v in it.items() if not k.startswith("_")}
    out = {
        "ok": True, "round": n, "findings": [pub(it) for it in final],
        "by_disposition": {d: [it["id"] for it in final if it["disposition"] == d] for d in DISPOSITIONS},
        "rejected": [{"id": it["id"], "evidence": it["_rejected"]} for it in rejected_items],
        "defers": [it["id"] for it in final if it["disposition"] == "defer"],
        "bucket_conflicts": bucket_conflicts, "lineage_mismatch": lineage_mismatch, "revived": revived,
        "degrade": degrade, "advisory": adv, "blocks": L.blocks(),
    }
    for k, v in report["counts"].items():
        out["adjudication_" + k] = v
    out["adjudication_unknown_counts"] = report["unknown_counts"]
    out["adjudication_degraded"] = report["degraded"]
    out["adjudication_held_by_class"] = L.held_by_class()
    st["rounds"][str(n)]["route_report"] = {
        "degrade": degrade, "advisory": adv, "rejected": len(rejected_items),
        "bucket_conflicts": bucket_conflicts, "revived": len(revived), "lineage_mismatch": lineage_mismatch,
    }
    st["pending_recritic"] = None
    save_state(a.state_dir, st, "finalize (%d findings, %d rejected)" % (len(final), len(rejected_items)))
    print(json.dumps(out, ensure_ascii=False, indent=1))
    return 0


def build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(prog="docreview_route.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("prepare-recritic"); x.add_argument("--state-dir", required=True)
    x.add_argument("--critic", required=True); x.add_argument("--codex", default=None)
    x.set_defaults(fn=cmd_prepare)
    x = sp.add_parser("finalize"); x.add_argument("--state-dir", required=True)
    x.add_argument("--recritic", default=None); x.add_argument("--recritic-skipped", action="store_true")
    x.add_argument("--diff", default=None); x.add_argument("--doc", default=None)
    x.set_defaults(fn=cmd_finalize)
    return p


def main(argv=None) -> int:
    a = build_parser().parse_args(argv)
    try:
        return a.fn(a)
    except FileNotFoundError as e:
        return fail("state_missing", path=str(e))
    except (ValueError, RuntimeError) as e:
        return fail("unreadable", detail=str(e))


if __name__ == "__main__":
    sys.exit(main())
