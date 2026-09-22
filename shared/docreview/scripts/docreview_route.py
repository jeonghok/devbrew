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
    RANK, LedgerCorrupt, _decide_choices_for, _is_reraise_successor, category_gloss, choice_label, fail,
    load_profile, load_state, observe_ledger, pending_mismatch, record_findings, round_diff, save_state, yaml,
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
        # 갈래 2 의 칸 둘. 여기 없으면 리뷰어가 무엇을 적든 «조용히» 버려진다 —
        # 이 dict 는 입력을 갱신하는 것이 아니라 처음부터 새로 짓는다.
        "replacement": (str(item["replacement"]) if item.get("replacement") else None),
        "if_unfixed": (str(item["if_unfixed"]) if item.get("if_unfixed") else None),
    }


def _bucket(it) -> str:
    return hashlib.sha1(("%d|%s|%s" % (it["layer"], it["category"], it["anchor"])).encode("utf-8")).hexdigest()[:8]


def _permit_covers(st, n, anchor) -> bool:
    """이 라운드에 그 앵커를 겨눈 permit 이 있었는가.

    실행 노트(R1) — `consumed` 로 걸러지지 않는다. `finalize` 는 분류 전에 이번 라운드
    관측(`docreview_state.observe_ledger`)을 마치므로, 분류가 도는 시점엔 이번
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
def _round_staleness(st, path, predates):
    """이 리뷰어 산출물 파일이 이번 라운드의 것이 아닐 사유 — 이번 라운드 것이면 None.

    codex · critic 두 산출물이 같은 규칙을 쓴다(사유 이름 `predates` 만 다르다). 산출물 경로는 세션과
    문서의 순수 함수라 같은 문서의 라운드마다 같은 파일이고, 직전 라운드의 산출물과 이번 라운드의 것은
    내용(스키마·마커)으로 못 가른다. 판별자는 시점이다: `begin-round` 가 남긴 라운드 시작 표식보다 먼저
    쓰인 파일은 직전 라운드 것이다. codex 쪽은 진입 중화가 불가능한 권한 조합(상태 디렉토리와 그 파일이
    둘 다 쓰기 불가, 상태 파일은 쓰기 가능)에서도 1단계가 통과하므로 그 조합의 집행이 여기 하나고,
    critic 쪽은 탐지를 dispatch 하지 못한 라운드(프로필 판독 실패 등)에 직전 라운드의 탐지 출력이 같은
    자리에 남을 수 있다. 표식이 없거나 정수가 아니면 판별할 수 없어 그 사유를 내고, 표식과 같은 시각도
    앞뒤를 가를 수 없으므로 `predates` 쪽으로 닫는다.
    """
    started = ((st.get("rounds") or {}).get(str(st.get("round"))) or {}).get("started_mtime_ns")
    if started is None:
        return "round_start_unrecorded"
    if isinstance(started, bool) or not isinstance(started, int):
        return "round_start_unreadable"
    if path.stat().st_mtime_ns <= started:
        return predates
    return None


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
    critic = Path(a.critic)
    critic_why = None    # critic 사망 사유 — None 이면 층 1 블록의 판정에 맡긴다
    text = ""
    if critic.is_file():
        # 라운드 시작 표식보다 먼저(또는 같은 시각에) 쓰인 critic 출력은 직전 라운드 것이다 — 탐지를 dispatch
        # 하지 못한 라운드에 같은 자리에 남은 출력을 이번 라운드의 탐지로 섭취하지 않는다(codex 와 같은 판별).
        # 표식 부재 · 비정수(`round_start_unrecorded` · `round_start_unreadable`)는 critic 을 닫지 않는다(R69) —
        # 다만 시점을 판별하지 못했다는 사실은 codex 경로와 독립으로 `degrade.critic_freshness_unknown` 에 이름을
        # 남기고 `finalize` 가 advisory 로 공시한다(차단 아님). 그 키는 이 경우에만 생긴다.
        critic_stale = _round_staleness(st, critic, "critic_predates_round")
        if critic_stale == "critic_predates_round":
            critic_why = "critic_predates_round"
        else:
            if critic_stale:
                degrade["critic_freshness_unknown"] = critic_stale
            try:
                text = critic.read_text(encoding="utf-8")
            except UnicodeDecodeError:
                # 깨진 critic 출력 — 설계 §9 의 sentinel 깨짐과 같은 판정(critic 사망 → 재dispatch 1회 → 「미검증」)
                critic_why = "undecodable"
    l1, e1 = extract_block(text, "docreview-layer1")
    critic_why = critic_why or e1
    if critic_why or not isinstance(l1, list):
        degrade["critic_dead"] = True
        ev("source_failed", "doc-critic", "layer1 block %s" % (critic_why or "not a list"), True)
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
    cx, stale = None, None
    if a.codex and Path(a.codex).is_file():
        stale = _round_staleness(st, Path(a.codex), "codex_predates_round")
        if stale is None:
            try:
                cx = yaml.safe_load(Path(a.codex).read_text(encoding="utf-8"))
            except Exception:
                cx = None
    meta = cx.get("meta") if isinstance(cx, dict) and isinstance(cx.get("meta"), dict) else {}
    if stale or not isinstance(cx, dict) or meta.get("codex_failed", True):
        degrade["codex_absent"] = True
        degrade["codex_reason"] = stale or str(meta.get("reason") or "yaml_missing_or_broken")
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
    st["pending_recritic"] = {"round": int(st["round"]), "items": pending, "degrade": degrade, "events": events}  # round — docreview_state.pending_mismatch
    save_state(a.state_dir, st, "prepare-recritic (%d items%s)" % (len(pending), ", critic dead" if degrade["critic_dead"] else ""))
    print(json.dumps({"ok": not degrade["critic_dead"], "items": [p["finding"] for p in pending],
                      "degrade": degrade}, ensure_ascii=False, indent=1))
    return 4 if degrade["critic_dead"] else 0


# ── finalize ─────────────────────────────────────────────────────────────
def _decision_view(it, doc, st):
    # [Task 4 fix round 1 — 리뷰 I1 정정] 이 함수는 `_remap_blocks` 를 거쳐
    # `cmd_finalize` 가 `record_findings` 를 부르기 «전에» 불린다 — 이 라운드의
    # 어떤 id 도 아직 `st["decides"]` 에 없다(그래서 `decide_choices(st, it["id"])`
    # 처럼 원장을 조회하는 래퍼는 여기서 못 쓴다, 전부 빈 리스트가 된다). 그러나
    # **원장을 몰라도 되는 두 사실**을 이미 다른 데서 안다: ① 이 id 는 몇 줄 뒤
    # `record_findings` 가 무조건 "open" 으로 적는다(§`record_findings`) — 상태를
    # «지어내는» 게 아니라 곧 쓰일 값을 앞당겨 아는 것이다. ② 승계 여부
    # (`_is_reraise_successor`)는 전방 포인터가 **바로 앞 줄**
    # (`_resolve_ids_and_lineage`, 이 함수 호출 직전)에서 이미 원본 레코드에
    # 찍히므로 지금 계산 가능하다 — 대상은 이 id 자신이 아니라 그 id 를 가리키는
    # «다른» 레코드라서 이 id 가 원장에 없어도 무관하다. 그래서 원장 래퍼가 아니라
    # 순수 함수 `_decide_choices_for` 를 직접 쓴다 — 선택지 로직은 여전히
    # `docreview_state.py` 한 곳뿐이고(`decide_choices`·`_rg_decide`·`_rg_expired`
    # 와 같은 원본), 이 자리가 `decide_choices` 를 재구현하지 않는다.
    choices = _decide_choices_for("open", _is_reraise_successor(st, it["id"]))
    nref = None
    if doc and Path(doc).is_file():
        nref = len(refs_of(doc, it["anchor"]))
    basis = it.get("evidence")
    if not basis:
        basis = "finding 없이 바뀜" if it["category"] == "frozen_change" else "(근거 없음)"
    # [갈래 2] `change` 를 «내지 않는다» — 그 값은 it["summary"] 였고 헤더가 이미 그
    # 문자열을 낸다(동어반복). 대신 두 칸을 낸다. **부재를 summary 로 메우지 않는다**:
    # 메우면 「리뷰어가 안 적었다」는 사실이 필드가 비어 있지 않다는 이유로 관측되지
    # 않는다. 그리고 두 부재 리터럴은 서로 다르다 — 침묵(`(대체안 미작성)`)과 판정
    # (`대체안 없음 — 그냥 뺀다`, 리뷰어가 그 문자열을 실제로 냈을 때만)은 다른
    # 사실이다. 같은 글자를 내면 아무도 제안하지 않은 삭제가 제안으로 전달된다.
    # 「영향」 → 「자리」: anchor + 인용수는 영향이 아니라 위치다. category 의 사람말을
    # `인용` **앞**에 넣는다 — `cases.sh` 가 `인용 1 섹션` 을 부분 문자열로 잰다
    # (T35), 사람말을 뒤로 옮기면 그 단언이 깨진다. 사상 없는 category 는 원래
    # 이름을 그대로 싣고 `category_unglossed` 로 그 사실을 공시한다(조용히 빈칸으로
    # 두지 않는다 — `category_gloss` 의 계약).
    gloss = category_gloss(it["category"])
    return {"if_unfixed": it.get("if_unfixed") or "(리뷰어가 안 적음)",
            "replacement": it.get("replacement") or "(대체안 미작성)",
            "basis": basis,
            "alternatives": [choice_label(c, it.get("kind")) for c in choices],
            "impact": "%s (%s) · 인용 %s 섹션" % (it["anchor"], gloss or it["category"],
                                                nref if nref is not None else "?"),
            "category_unglossed": None if gloss else it["category"],
            "auto": it.get("origin") == "auto"}


def _rk(fid):  # id → (round, k) 정렬 키
    tail = fid.split("#r", 1)[1]
    r, k = tail.split(".", 1)
    return (int(r), int(k))


def _read_recritic(a, degrade, L):
    """재비판 산출물에서 (verdicts, added) 를 꺼낸다.

    죽었으면(kill switch · 블록 부재/파손) 사유를 `degrade["recritic_dead"]` 에 남기고
    빈 쌍을 낸다 — 호출부는 그 뒤로도 같은 경로를 그대로 걷는다(기각 0건이 될 뿐이고,
    그 사실 자체는 `_build_report` 의 advisory 가 공시한다).
    """
    if a.recritic_skipped:
        degrade["recritic_dead"] = "skipped"
        L.source_failed("doc-recritic", "kill switch", primary=False)
        return [], []
    text = Path(a.recritic).read_text(encoding="utf-8") if a.recritic and Path(a.recritic).is_file() else ""
    blk, err = extract_block(text, "docreview-recritic")
    if err or not isinstance(blk, dict):
        degrade["recritic_dead"] = err or "not a mapping"
        L.source_failed("doc-recritic", degrade["recritic_dead"], primary=False)
        return [], []
    return blk.get("verdicts") or [], blk.get("added") or []


def _apply_recritic(items, verdicts, added, L):
    """재비판 verdict 를 `items` 에 제자리 반영하고 same_as 병합 지시 목록을 낸다.

    세 단계의 순서가 계약이다 — verdict 반영 → 미판정 처분 강제(ask) → `added` 편입.
    강제를 verdict 뒤에 두는 것은 verdict 가 처분을 채울 기회를 다 준 뒤여야 하기
    때문이고, `added` 를 마지막에 두는 것은 재비판이 자기 추가분을 판정 대상으로
    삼지 않기 때문이다(그래서 새 항목은 verdict 루프를 지나지 않는다).
    """
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
            if vd != "confirm":
                # 어휘 밖 값을 조용히 confirm 으로 흘리지 않는다 — 형제 normalize() 가
                # 처분(disp not in RANK)에 대해 하는 것과 같은 계약(CLAUDE.md
                # 「판정기가 항목을 버리면 센다」).
                L.coerced("verdict", vd, "confirm")
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
    return same_as


def _absorb_same_as(items, same_as, L):
    """same_as — union-find, 높은 처분이 남는다(전순서 max).

    그룹마다 생존자 하나만 남기고 나머지는 `_absorbed_into` 로 표시한다. 낸 값
    `keep_of` 는 흡수된 f 를 생존 f 로 보내는 맵이고, `blocks` 재매핑이 그것을 쓴다.
    """
    parent = {f: f for f in items}

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for x, y in same_as:
        if x in parent and y in parent:
            parent[find(x)] = find(y)
        else:
            # `x`(재비판 verdict 의 `f`)는 위(`if not it: L.hold(...); continue`)에서
            # 이미 items 키로 검증됐고 items 항목은 삭제 경로가 없으므로(추가만 되는
            # `added` 루프뿐) `x not in parent` 는 이 시점에 도달 불가 — 실제로
            # 도달하는 갈래는 `y`(same_as 타겟)가 허상인 경우 하나뿐이다. 그래도
            # 가드 모양이 바뀌어도 조용히 소실되지 않도록 두 변을 독립으로 세서
            # 각각 accounts — 「값이 하나 대체됐다」와「값이 둘 대체됐다」는 다른
            # 사실이라 뭉개지 않는다.
            # hold 가 아니라 coerced 를 고른 이유 — hold 는 "판정하지 못했다, 사람이
            # 봐야 한다"는 뜻인데(Ledger.hold 의 unknown-f 용례), 이건 그게 아니다:
            # 병합 지시 자체가 허상을 가리켰을 뿐 `x` 항목은 이미 정상 처분으로
            # 처리가 끝났다. "병합하라"를 "병합하지 않는다"(None)로 대체한
            # coerced 이고, 형제는 어휘 밖 verdict 를 confirm 으로 대체한 위쪽의
            # `L.coerced("verdict", vd, "confirm")`(Task 7)다. 다음 소비자가 셀
            # 결론 — coerced 건수는 "이 라운드 재비판이 존재하지 않는 항목을
            # 겨눴다"는 뜻일 뿐 그 지목이 병합 없이 무시된 것으로 이미 처리가
            # 끝났다는 뜻이다(hold 처럼 사람의 추가 판단을 기다리는 게 아니다).
            if x not in parent:
                L.coerced("same_as", x, None)
            if y not in parent:
                L.coerced("same_as", y, None)
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
    return keep_of


def _classify_items(items, st, prof, sections, n, L):
    """프로필 허용 처분 강제 · 앵커 분류(보호·불변) · 승격.

    흡수된 항목은 버리고 기각된 항목은 따로 모은다 — (final, rejected_items).
    """
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
    return final, rejected_items


def _auto_decides(a, diff, st, prof, sections, n, L):
    """사후·이월 auto decide — 얼림 diff(post) · check-intent 거부(pre) · expired 재상승(pre).

    `diff` 는 `cmd_finalize` 가 원장의 라운드별 스냅숏으로 계산한 얼림 diff(`docreview_state.round_diff`)다 — 라운드
    1 에는 직전 스냅숏이 없어 None 이고 사후 항목이 없다. `a` 는 인자 묶음 그대로다.
    `st["escalated"]` 은 아직 자기 차례가 아닌 예약만 남기고, `st["reraise"]` 는 비운다.
    낸 값은 (새 항목들, 미소비 재상승 예약 수, 미소비 escalated 예약 수).

    이 함수에 `items` 가 없다는 것이 설계다 — 재상승 후속이 same_as 흡수 · 재비판
    reject · 처분 강제를 지나지 않는다는 불변식이 여기서는 스코프로 보장된다(분해
    전에는 「이 줄이 그 셋보다 아래에 있다」는 위치로만 보장됐다). `L` 은 escalated
    dedup 흡수 하나만 쓴다(F-2 재리뷰 Ruling 21) — `items` 파이프라인을 통째로 넘기지
    않으므로 위 불변식은 그대로다.
    """
    extra = []
    if diff is not None:
        for c in diff.get("changed", []):
            cls = classify_anchor(c["anchor"], sections, prof)
            extra.append({"f": None, "layer": 1 if cls["protected"] else 2, "category": "frozen_change",
                          "anchor": c["anchor"], "disposition": "decide",
                          "summary": "finding 없이 바뀜: %s (%s)" % (c.get("title") or c["anchor"], c["kind"]),
                          "edit_scope": c["anchor"], "blocks": [], "supersedes": None,
                          "evidence": c["evidence"], "origin": "auto", "kind": "post",
                          "prev_hash": c.get("old_hash"), "immutable": cls["immutable"], "_source": "diff"})
    prev = st["findings"]
    keep_esc = []
    esc_seen = {}   # finding_id → 이긴 예약의 라운드(먼저 온 것 — Ruling 22, 최신이 아니다)
    esc_unconsumed = 0
    # Task 2 — 형제 재상승(AC21)과 대칭으로 맞춘다. 이전엔 `!= n - 1`(정확히 직전
    # 라운드의 예약만 소비)이라 `finalize` 가 이 루프 전에 조기 반환한 라운드가 하나라도
    # 끼면 그 예약의 라운드 번호가 영원히 어긋나 소비도 계수도 안 됐다(escalated 예약
    # 자체는 사라지지 않았지만 — keep_esc 가 보존한다 — 다음 라운드에도 다시 `!= n-1`
    # 검사에 걸려 영원히 kept 로만 남았다). `>= n` 은 「이번 라운드 이후에 생긴 예약만
    # 보류」로 바꿔 그 앞의 예약을 전부 소비 대상으로 삼는다.
    for e in st.get("escalated") or []:
        if int(e["round"]) >= n:
            keep_esc.append(e)   # 이번 라운드 이후에 생긴 예약 — 아직 자기 차례가 아니다
            continue
        fid = e["finding_id"]
        f0 = prev.get(fid)
        if not f0:
            esc_unconsumed += 1   # 대상 finding 부재 — 버리지 않고 센다(공시는 게이트가, 재상승과 같은 규칙)
            continue
        # F-3 재리뷰(Ruling 20) — 형제 재상승(:533, `if not d0 or d0.get("state") != "expired"`)
        # 과 같은 모양. `f0` 존재만으로는 이 fix 가 «지금도» escalated 상태인지 모른다 —
        # 예약이 만들어진 뒤 사용자가 drop 하거나(cmd_fix event=drop, 상태 검사 없이
        # 무조건 대입) intent-pass 로 재시도했을 수 있다(둘 다 `st["fixes"][fid]["state"]`
        # 를 escalated 밖으로 옮긴다). 누적(`>= n`)이 이 창을 1 라운드에서 무한대로
        # 넓혔으므로, 지금 상태가 여전히 "escalated" 인 예약만 후속을 낸다 — 아니면
        # 사용자가 이미 다른 처분을 내린 것이고 그 처분이 의무를 진다(형제와 같은 이유,
        # 버려지는 새 항목이 없다).
        fx0 = st["fixes"].get(fid)
        if not fx0 or fx0.get("state") != "escalated":
            continue
        if fid in esc_seen:
            # 한 계보에 라운드당 후속 하나(재상승 dedup, cmd_observe_diff 와 같은 규칙).
            # 흡수이지 소실이 아니다 — `esc_seen` 에 먼저 들어간 예약이 바로 아래서
            # 이미 후속을 만들었다. F-2 재리뷰(Ruling 21) — CLAUDE.md 「흡수(dedup)…
            # 계수하되 그 자체로 degrade 는 아니다」를 그대로 따라 `L.absorbed` 로
            # 센다(면제가 아니다). 승자는 항상 먼저 온 예약이다 — `st["escalated"]` 는
            # append-only 라 리스트 순서가 곧 escalate 된 순서이므로, 라운드가 다른
            # 사유 둘이 충돌해도 **먼저** 온 사유가 남는다(최신이 아니다) — 행동
            # 변경 없음, `case_escalated_dedup` 이 이 사실을 단언으로 못 박는다.
            L.absorbed("escalated:%s#r%d" % (fid, int(e["round"])),
                      into="escalated:%s#r%d" % (fid, esc_seen[fid]))
            continue
        esc_seen[fid] = int(e["round"])
        extra.append({"f": None, "layer": f0["layer"], "category": f0["category"], "anchor": f0["anchor"],
                      "disposition": "decide", "summary": "check-intent 거부 후 상향: " + (f0.get("summary") or ""),
                      "edit_scope": f0.get("edit_scope") or f0["anchor"], "blocks": [],
                      "supersedes": fid, "evidence": e.get("reason"), "origin": "auto",
                      "kind": "pre", "immutable": bool(f0.get("immutable")), "_source": "escalated"})
    st["escalated"] = keep_esc
    reraise_unconsumed = 0
    for r in st.get("reraise") or []:
        f0 = prev.get(r["finding_id"])
        if not f0:
            reraise_unconsumed += 1   # 대상 finding 부재 — 버리지 않고 센다(공시는 게이트가)
            continue
        d0 = st["decides"].get(r["finding_id"])
        # `not d0` 와 `state != "expired"` 는 다른 사실이다 — 후자(재결정됨)만 게이트가
        # 공시할 값이 있다. `not d0` 는 `f0`(위에서 확인)는 있는데 그 decides 레코드가
        # 없는 경우인데, `st["decides"]` 항목은 지워지는 코드 경로가 없으므로(설계는
        # 여섯 상태로 닫혀 있고 전이만 한다 — open + 대입되는 다섯(adopted·rejected·
        # held·applied·expired), 설계 §6.4) `f0` 가 있으면 `d0` 도 항상 있다 — 지금은
        # 도달 불가라 계수하지 않는다. 도달 가능해지면(예: 항목 삭제 경로가 생기면)
        # `reraise_unconsumed` 와는 다른 카운터로 새로 공시해야 한다 — 「대상 자체가
        # 없다」와 「대상은 있는데 이미 재결정됐다」를 같은 숫자로 뭉개면 안 된다.
        if not d0 or d0.get("state") != "expired":
            continue          # 사용자가 이미 재결정했다 — 의무는 그 결정이 진다
        # 후속은 원본의 «성격»을 물려받는다. `pre`(아직 안 한 편집)와 `post`(이미
        # 일어난 변경의 원복 의무)는 permit 의 종류가 다르고, `post` 만 해시 대조를
        # 한다 — 하드코딩하면 원복 의무가 「앵커가 닿기만 하면 통과」로 강등된다
        # (설계 §6.4 알려진 한계 (b)).
        # [fix round 1 — 리뷰 M3] `d0.get("kind")` 에 `or "pre"` fallback 을 안
        # 붙인다 — d0 는 위 가드(`if not d0 …`)를 지났으므로 이미 존재하고,
        # `st["decides"]` 레코드를 만드는 유일한 자리(`record_findings`,
        # docreview_state.py)가 `"kind": it.get("kind") or "pre"` 로 «기록 시점에»
        # 이미 강제해 `d0.get("kind")` 는 항상 truthy 다 — 도달 불가능한 자리에
        # 조용한 기본값을 또 놓으면 CLAUDE.md 「강제는 계수하되 소실이 아니다」를
        # 어기는 uncounted coercion 이 된다.
        extra.append({"f": None, "layer": f0["layer"], "category": f0["category"], "anchor": f0["anchor"],
                      "disposition": "decide", "summary": "채택 후 미적용(expired): " + (f0.get("summary") or ""),
                      "edit_scope": f0.get("edit_scope") or f0["anchor"], "blocks": [],
                      "supersedes": r["finding_id"], "evidence": r.get("reason"), "origin": "auto",
                      "kind": d0.get("kind"), "prev_hash": d0.get("prev_hash"),
                      "immutable": bool(f0.get("immutable")), "_source": "reraise"})
    st["reraise"] = []
    return extra, reraise_unconsumed, esc_unconsumed


def _order_key(it):   # 리뷰어 항목은 f 순, 사후 항목은 그 뒤
    f = it.get("f") or ""
    return (0 if f else 1, int(f[1:]) if f[1:].isdigit() else 0, f[:1])


def _resolve_ids_and_lineage(st, final, rejected_items, n):
    """id·bucket 부여 → 전방 포인터 → 계보 2패스 해소 → 기각 계보 기록.

    낸 값은 (bucket_conflicts, lineage_mismatch, revived) — 셋 다 보고서가 공시한다.
    """
    prev = st["findings"]
    everything = sorted(final + rejected_items, key=_order_key)
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
    # 전방 포인터(설계 §6.4) — 후속의 최종 id 가 확정된 뒤에만 쓸 수 있다. 쓰는 곳은
    # 여기 하나뿐이고, 대상이 지금 expired 인 경우로 이미 좁혀져 있다(위 가드).
    for it in everything:
        if it.get("_source") != "reraise":
            continue
        d0 = st["decides"].get(it.get("supersedes"))
        if d0 is not None and d0.get("state") == "expired":
            d0["superseded_by"] = it["id"]
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
    return bucket_conflicts, lineage_mismatch, revived


def _remap_blocks(final, keep_of, doc, st):
    """`blocks` 의 f-참조를 흡수 생존자(keep_of)를 거쳐 최종 id 로 바꾸고, decide 에 결정 뷰를 단다.

    `st` 는 `_decision_view` 가 `_is_reraise_successor` 를 계산하는 데만 쓴다(원장에
    아직 없는 이 라운드 id 자신은 안 본다 — 위 `_decision_view` 헤더)."""
    f2id = {it["f"]: it["id"] for it in final if it.get("f")}
    for it in final:
        out = []
        for r in it.get("blocks") or []:
            r2 = keep_of.get(r, r)
            if r2 in f2id:
                out.append(f2id[r2])
        it["blocks"] = out
        if it["disposition"] == "decide":
            it["decision_view"] = _decision_view(it, doc, st)


def _pub(it):
    return {k: v for k, v in it.items() if not k.startswith("_")}


def _build_report(L, st, n, final, rejected_items, degrade, stats):
    """출력 JSON 을 조립하고 같은 요약을 `st["rounds"][n]["route_report"]` 에 남긴다.

    `stats` 는 앞 단계가 낸 계수 다섯(bucket_conflicts · lineage_mismatch · revived ·
    reraise_unconsumed · escalated_unconsumed)이다. 키 순서는 골든(`shared/tests/fixtures/
    docreview/golden/`)이 바이트로 고정하므로 재배열하지 않는다.
    """
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
    if degrade.get("critic_freshness_unknown"):
        adv.append("critic 시점 판별 불가 (%s)" % degrade["critic_freshness_unknown"])
    out = {
        "ok": True, "round": n, "findings": [_pub(it) for it in final],
        "by_disposition": {d: [it["id"] for it in final if it["disposition"] == d] for d in DISPOSITIONS},
        "rejected": [{"id": it["id"], "evidence": it["_rejected"]} for it in rejected_items],
        "defers": [it["id"] for it in final if it["disposition"] == "defer"],
        "bucket_conflicts": stats["bucket_conflicts"], "lineage_mismatch": stats["lineage_mismatch"],
        "revived": stats["revived"], "degrade": degrade, "advisory": adv, "blocks": L.blocks(),
        "reraise_unconsumed": stats["reraise_unconsumed"],
        "escalated_unconsumed": stats["escalated_unconsumed"],
    }
    # 키를 «이름으로» 편다 — `render_disposition.disposition_report()` 의 같은
    # 결정과 같은 이유다(그 파일 :66-68): `report["counts"]` 를 `.items()` 로
    # 통째로 넘기면 카운트 이름이 이 파일에 문자열로 한 번도 안 나타나서,
    # 어휘가 늘어도 이 소비자는 조용하다 — `tools/adjudication/check_consumed.py`
    # 가 막으려는 바로 그 침묵이다(L2, 리터럴 첨자·튜플 원소만 소비로 센다).
    for k in ("accepted", "rejected", "held", "absorbed", "coerced",
              "sources_failed", "suppressed"):
        out["adjudication_" + k] = report["counts"][k]
    out["adjudication_unknown_counts"] = report["unknown_counts"]
    out["adjudication_degraded"] = report["degraded"]
    out["adjudication_held_by_class"] = L.held_by_class()
    st["rounds"][str(n)]["route_report"] = {
        "degrade": degrade, "advisory": adv, "rejected": len(rejected_items),
        "bucket_conflicts": stats["bucket_conflicts"], "revived": len(stats["revived"]),
        "lineage_mismatch": stats["lineage_mismatch"],
        "reraise_unconsumed": stats["reraise_unconsumed"],
        "escalated_unconsumed": stats["escalated_unconsumed"],
    }
    return out


def cmd_finalize(a) -> int:
    """재비판 반영 → 흡수 → 분류 → 사후/이월 → id·계보 → blocks → 보고서.

    각 걸음은 위 모듈 함수 하나이고, 걸음 사이의 값은 인자와 반환값으로만 오간다
    (`nonlocal` 은 `_resolve_ids_and_lineage` 안의 계보 해소 하나뿐 — 분해 전과 같다).
    """
    st = load_state(a.state_dir)
    n = int(st["round"])
    why = pending_mismatch(st, n)
    if why:
        # 이번 라운드의 준비가 없거나 · 다른 라운드 것이거나 · 어느 라운드 것인지 모른다 — 소비하지
        # 않는다. rc 만 내고 끝나면 준비가 없는 라운드의 게이트가 정상으로 열리므로, 실패를 이 라운드
        # 자리에 남겨 게이트가 「미검증」(`finalize_incomplete`)으로 알게 한다. 같은 라운드의 finalize
        # 가 나중에 성공하면 아래에서 치운다.
        r = st["rounds"].setdefault(str(n), {"open_lineages": [], "progress": 0, "route_report": None})
        r["finalize_failed"] = why
        save_state(a.state_dir, st, "finalize 거부 (%s)" % why)
        return fail(why, round=n)
    prof = load_profile(st["profile"])
    # 라운드 ≥ 2 — permit · fix 적용 관측과 얼림 diff 는 원장의 라운드별 스냅숏으로 엔진이 계산한다(오케스트레이터가
    # 쓰는 diff 파일이 없다). 관측이 먼저다: 관측이 연 재상승 예약을 아래 `_auto_decides` 가 같은 호출에서 소비하고,
    # 얼림 diff 의 면제 집합은 소비된 permit 도 센다(`exempt_scopes`). 관측을 건너뛴 지난 라운드의 permit 도 여기서
    # 따라잡는다. 스냅숏 부재 · 파손 permit 은 준비(`pending_recritic`)를 치우기 **전에** rc ≠ 0 이다 — 원장을 쓰지
    # 않으므로 준비가 남고, 게이트가 「미검증」(`finalize_incomplete`)으로 연다. 라운드 1 에는 직전이 없다.
    diff, obs = None, None
    if n >= 2:
        try:
            obs = observe_ledger(st, prof, n)
            diff = round_diff(st, prof, n)
        except LedgerCorrupt as e:
            return fail(e.reason, **e.extra)
    pend = st["pending_recritic"]
    L = Ledger(items="open")
    for e in pend.get("events", []):
        getattr(L, e[0])(*e[1:])
    degrade = dict(pend["degrade"])
    degrade.setdefault("recritic_dead", None)
    items = {p["f"]: dict(p["finding"], _source=p["source"]) for p in pend["items"]}
    sections = st["snapshots"][str(n)]["sections"]

    verdicts, added = _read_recritic(a, degrade, L)
    same_as = _apply_recritic(items, verdicts, added, L)
    keep_of = _absorb_same_as(items, same_as, L)
    final, rejected_items = _classify_items(items, st, prof, sections, n, L)
    extra, reraise_unconsumed, escalated_unconsumed = _auto_decides(a, diff, st, prof, sections, n, L)
    final.extend(extra)
    bucket_conflicts, lineage_mismatch, revived = _resolve_ids_and_lineage(st, final, rejected_items, n)
    _remap_blocks(final, keep_of, a.doc, st)

    for it in final:
        L.accept(it["id"])
    record_findings(st, final + rejected_items, n)
    out = _build_report(L, st, n, final, rejected_items, degrade,
                        {"bucket_conflicts": bucket_conflicts, "lineage_mismatch": lineage_mismatch,
                         "revived": revived, "reraise_unconsumed": reraise_unconsumed,
                         "escalated_unconsumed": escalated_unconsumed})
    st["pending_recritic"] = None
    st["rounds"][str(n)].pop("finalize_failed", None)   # 같은 라운드의 앞선 거부 표지 — 이 성공이 대신한다
    log = "finalize (%d findings, %d rejected)" % (len(final), len(rejected_items))
    if obs and obs["observed"]:   # 이 finalize 가 관측을 새로 했다(observe-diff 를 먼저 돌지 않은 라운드 · 따라잡기)
        log += " · observe applied=%d expired=%d" % (len(obs["applied"]), len(obs["expired"]))
    save_state(a.state_dir, st, log)
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
    x.add_argument("--doc", default=None)
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
