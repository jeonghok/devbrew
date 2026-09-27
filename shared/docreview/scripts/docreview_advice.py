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
