"""docreview_advice.py — must-catch 축과 참고(advisory) 축을 가르는 순수 함수 (leaf 모듈).

라우터(`docreview_route.py`)의 두 걸음 표지 · 병합 생존자의 축 소속 · 관측 계수와, 원장의 `advice` 서브커맨드
(`docreview_state.py` 의 `cmd_advice`)가 쓰는 렌더 · 박제 행 · 계수 줄을 담는다. 파일 I/O 도 형제 import 도
없다 — 항목 dict · 프로필 dict · 스냅숏 dict 만 받는다. `adjudication` 을 import 하지 않는다: 강제 계수는 호출자가
넘긴 원장(`L`)에 적는다.

advisory 축 = (`layer_rubric.layer1` ∪ `layer2`) − `must_catch`. 그 밖(rubric 밖 category · `other` ·
`frozen_change`)과 엔진 자동 생성 항목(`_source` ∈ diff · reraise · escalated)은 전부 must-catch 다. 프로필이
`must_catch` 를 지목하지 않으면 advisory 축은 공집합이고 라우팅은 현행과 같다.
"""
from __future__ import annotations

ENGINE_SOURCES = frozenset(("diff", "reraise", "escalated"))
ROUTE_ADVICE = "advice"


def has_must_catch(prof) -> bool:
    return prof.get("must_catch") is not None


def advisory_axes(prof) -> frozenset:
    mc = prof.get("must_catch")
    if mc is None:
        return frozenset()
    lr = prof["layer_rubric"]
    return (frozenset(lr["layer1"]) | frozenset(lr["layer2"])) - frozenset(mc)


def is_advisory(it, axes) -> bool:
    """advisory 축 소속인가 — 엔진 자동 생성 항목은 category 와 무관하게 아니다(재상승 · 상향 후속은 원본의
    category 를 물려받으므로 category 로는 못 가른다). same_as 병합 생존자는 기각되지 않은 구성원
    (`_member_categories`) 전부가 advisory 일 때만 advisory 다."""
    if it.get("_source") in ENGINE_SOURCES:
        return False
    cats = it.get("_member_categories") or [it["category"]]
    return all(c in axes for c in cats)


def member_categories(items, live) -> list:
    """병합 그룹의 기각되지 않은 구성원 category — 생존자의 축 소속 판정 재료(`_absorb_same_as` 가 남긴다)."""
    return sorted({items[m]["category"] for m in live})


def advice_ids(final) -> list:
    return [it["id"] for it in final if it.get("route") == ROUTE_ADVICE]


def route_step1(final, axes) -> None:
    """1 걸음 — `_classify_items` 의 처분 강제 · 보호 헤딩 승격 뒤. 축과 처분만 보면 정해지는 것:
    advisory 축의 `decide`(보호 헤딩 승격분 포함 — 승격된 항목의 처분은 이미 `decide` 다)와 `blocks` 없는
    `ask`. `blocks` 가 있는 `ask` 는 대상의 적용 경로를 알아야 해서 2 걸음(`route_step2`)이 정한다."""
    for it in final:
        d = it["disposition"]
        if is_advisory(it, axes) and (d == "decide" or (d == "ask" and not it.get("blocks"))):
            it["route"] = ROUTE_ADVICE


def route_step2(final, keep_of, axes, n, L) -> None:
    """2 걸음 — `_resolve_ids_and_lineage` 뒤 · `_remap_blocks` 직전. 계보를 알아야 정해지는 것.

    ① 라운드 n ≥ 2 에서 새 계보(`lineage == id` — 계보 연결 · 재상승 후속이 아님)로 나온 advisory `fix` → advice.
       계보를 잇는 fix 는 fixes 에 남아 막는다(라운드 1 에서 온 미적용 의무).
    ② `blocks` 가 있는 `ask` — 판정은 축이 아니라 대상의 적용 경로다(`_judge_blocking_ask`)."""
    if n >= 2:
        for it in final:
            if it["disposition"] == "fix" and is_advisory(it, axes) and it.get("lineage") == it.get("id"):
                it["route"] = ROUTE_ADVICE
    by_f = {it["f"]: it for it in final if it.get("f")}
    for it in final:
        if it["disposition"] == "ask" and it.get("blocks"):
            _judge_blocking_ask(it, by_f, keep_of, axes, L)


def _judge_blocking_ask(it, by_f, keep_of, axes, L) -> None:
    """advice 가 아닌 대상이 하나라도 있으면 asks 에 남는다(축 무관 — 답 전까지 그 fix 는 held). advisory ask 는
    대상이 전부 advice 거나 찾을 수 없으면 advice 다. asks 에 남는 ask 의 `blocks` 중 advice 대상 ref 는 조용히
    버리지 않고 `coerced("blocks", ref, None)` 로 센다 — 없는 ref 는 현행대로 `_remap_blocks` 가 거른다."""
    targets = [by_f.get(keep_of.get(r, r)) for r in it["blocks"]]
    live = [t for t in targets if t is not None]
    if is_advisory(it, axes) and all(t.get("route") == ROUTE_ADVICE for t in live):
        it["route"] = ROUTE_ADVICE
    else:
        kept = []
        for r, t in zip(it["blocks"], targets):
            if t is not None and t.get("route") == ROUTE_ADVICE:
                L.coerced("blocks", r, None)
            else:
                kept.append(r)
        it["blocks"] = kept


def _subtree(snap, anchor) -> dict:
    """앵커 절과 그 하위 절(`parents` 로 도출)의 {앵커: 해시}. 스냅숏 해시는 다음 헤딩(레벨 무관)에서 끊기므로
    자기 절만 보면 상위 앵커의 finding 이 하위 절 변경에도 선재로 세어진다."""
    return {s["anchor"]: s["hash"] for s in snap.get("sections") or []
            if s["anchor"] == anchor or anchor in (s.get("parents") or [])}


def mc_preexisting_new(final, snapshots, n, axes) -> int:
    """라운드 n ≥ 2 에서 must-catch 로 분류된 리뷰어 finding 중 새 계보(`lineage == id`)이고 앵커 절과 그 하위 절
    전부의 해시가 스냅숏 n−1 과 n 에서 같은 것의 수. 동작을 바꾸지 않는 관측값이다 — 전문 재대조에서 재샘플링이
    잦아든다는 가정(RC31)을 다음 사이클이 센다. drop · 엔진 자동 생성 · advisory 는 세지 않는다."""
    if n < 2:
        return 0
    prev, cur = (snapshots or {}).get(str(n - 1)), (snapshots or {}).get(str(n))
    if not prev or not cur:
        return 0
    count = 0
    for it in final:
        if (it.get("route") != ROUTE_ADVICE and it.get("_source") not in ENGINE_SOURCES
                and not is_advisory(it, axes) and it["disposition"] != "drop"
                and it.get("lineage") == it.get("id")):
            before, after = _subtree(prev, it["anchor"]), _subtree(cur, it["anchor"])
            if after and before == after:
                count += 1
    return count
