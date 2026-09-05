# -*- coding: utf-8 -*-
"""면제 사유의 «실질» 판정 — L1(`check_wiring`)·L3(`check_slots`) 공용.

설계 §8: C6 ⑴ 대응물이 원리적으로 없음 · ⑵ 측정된 이유(기존에 기록된 설계
이유 포함). 두 등록부(`EXEMPT`·`EXEMPT_SLOTS`)가 같은 요구를 지므로 판정도
하나여야 한다 — Task 11b Step 4b 가 이미 한 번, 같은 요구가 두 자리에서 다른
엄격도로 걸린 것을 고쳤다(`terminal_uncited` 는 빈 문자열만 아니면 통과했다).
같은 술어를 두 파일에 베껴 두면 다음 조임이 한쪽에만 닿는다.

**이 검사가 막는 것은 「사유를 안 적는 것」이지 「틀린 사유」가 아니다.**
분량은 실질의 대리지표일 뿐 — 40자짜리 헛소리는 여전히 통과한다. 사유의
참·거짓은 사람이 읽어야 하고, 이 술어는 읽을 것이 있는지만 보장한다.
"""
import re

# 조건 «번호»를 요구한다. 리터럴 `"C6"` 두 글자면 만족하던 이전 규율은
# 사유를 `"C6"` 한 문자열로 바꿔도 통과했다(최종 리뷰 A/m1).
_C6_RE = re.compile(r'C6\((?:1|2)\)')

# 조건 번호를 뺀 나머지의 최소 길이. 「어느 조건인가」만으로는 «왜 그 조건에
# 해당하는가»가 없고, 그 「왜」가 면제의 실질 전부다.
MIN_BODY = 40


def cited(value):
    """사유가 C6 조건 번호와 최소 분량을 함께 갖는가."""
    s = str(value)
    if not _C6_RE.search(s):
        return False
    return len(_C6_RE.sub("", s).strip()) >= MIN_BODY


def uncited(mapping):
    """`{키: 사유}` 에서 실질을 갖추지 못한 키들 — 호출자가 RED 로 만든다."""
    return [k for k, v in mapping.items() if not cited(v)]
