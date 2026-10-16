#!/usr/bin/env python3
"""spec-distill `scripts/` 가 함께 쓰는 조각.

**사본이 아니다** — 같은 플러그인 안이므로 import 하나로 중복이 소멸한다. 배포 경로는
`${CLAUDE_PLUGIN_ROOT}/scripts/` 다. `copy-of` 마커도 사본 동일성 검사도 붙지 않는다 —
지킬 두 번째 파일이 없다.

소비자: 훅이 없어진 뒤(6.0.0) 남은 소비자는 `brief_review_state.py` 하나다 — `_yaml_scalar` 을
쓴다(census #45의 spec-distill 부분).

**담지 않는 것** — `kill_switch_active`(`shared/killswitch/` 정본의 형제 사본에서
온다. 여기로 다시 가져오면 정본이 둘이 된다) · `resolve_session_id` / `state_root`
(`state_path.py` 소유).
"""
from __future__ import annotations

import json


# `_yaml_scalar` 가 인용해야 하는 문자 — **두 축**이다. 이 두 상수는
# `shared/codex/codex_findings_to_yaml.py` 와 같은 값이어야 한다(정본과 이 소비자가
# 다른 인용 규칙을 쓰면 census #45 가 닫은 drift 가 되살아난다).
#
# _YAML_UNSAFE_ANYWHERE — 문자열 어디에 있어도 위험: 매핑 구분자 `:` · 주석 `#` ·
#   인용부호 · 개행 · flow collection 지시자 `[]{}`.
# _YAML_UNSAFE_FIRST — **첫 글자일 때만** 위험: block sequence `-` · complex key
#   `?` · tag `!` · anchor/alias `&`/`*` · directive `%` · block scalar `|`/`>` ·
#   flow 구분자 `,` · YAML 이 예약한 `@`/backtick.
#
# 두 집합은 상상이 아니라 전수 측정으로 얻었다(2026-08-19, PyYAML 6.0.3): 첫 글자를
# 0x20–0x7E 전부로 돌려 `k: <값>` 을 파싱했을 때 깨진 첫 글자는
# ` !"#%&'*,-:>?@[]`{|}` 였다. 그 중 ANYWHERE 와 앞뒤 공백 검사(`s.strip() != s`)
# 가 이미 덮는 것을 뺀 잔여가 FIRST 다. 합집합(문자 멤버십)만으로는 `- ` 로 시작하는
# 값이 ScannerError 로 죽는 잔여 구멍이 남아 있었다 — 위치 축이 별도로 필요하다.
_YAML_UNSAFE_ANYWHERE = ":#\"'\n[]{}"
_YAML_UNSAFE_FIRST = "!%&*,->?@|`"


def _yaml_scalar(v) -> str:
    """값 하나를 YAML 인라인 스칼라로. 필요할 때만 인용한다.

    spec-distill 안에 세 벌이 있었고 셋 다 달랐다 — 빈 문자열 가드(`merge_review` 에만
    없었다) · escape 문자 집합(`[]{}` 가 `brief_review_state` 에만 있었다) · 숫자와
    None 처리(`brief_review_state` 는 float 도 None 도 다루지 않았다). **합집합**을
    쓴다: 더 인용하는 것은 파싱 결과를 바꾸지 않고, 덜 인용하는 것만 바꾼다.

    합집합이 실제로 고치는 것(실측):
      - 빈 문자열이 따옴표 없이 나가면 YAML 은 그것을 null 로 읽는다(`merge_review`).
      - `[` 로 시작하고 `:` 를 안 가진 advisory 문구가 인용 없이 나가면 YAML flow
        sequence 로 읽힌다. 두 merge 스크립트의 advisory 리터럴 중 **5건**이 이
        모양이었다(예: "[spec-distill …] review indeterminate …").
      - None 이 `brief_review_state` 에서 `None` 이라는 문자열로 나갔다(도달 경로는
        없다 — 서브커맨드 인자가 전부 required 라 항상 str 이다).

    2026-08-19 추가: 세 사본의 합집합은 **문자 멤버십** 축만 갖고 있어서 위치 축의
    잔여 구멍이 남아 있었다 — `- dash` 처럼 block sequence 지시자로 시작하는 값이
    인용 없이 나가 ScannerError 를 냈다(실측). `_YAML_UNSAFE_FIRST` 가 그 축이고,
    정본(`shared/codex/codex_findings_to_yaml.py`)과 **같은 값**을 쓴다.

    ensure_ascii=False: 이 리포는 Korean-primary 이고 advisory 는 한국어다 —
    \\uXXXX 로 escape 하면 사람이 읽는 게이트가 판독 불가가 된다. 산출 파일은 UTF-8.
    정본(`shared/codex/codex_findings_to_yaml.py`)도 **같다** — 인용 여부(위 두
    상수)도 표기(ensure_ascii)도 같다. 2026-08-19 이전에는 정본만 기본값(True)이라
    한국어가 \\uXXXX 로 나갔고, 인용 술어를 넓히면서 그 노출이 늘어 함께 맞췄다.
    """
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return str(v)
    if v is None:
        return "null"
    s = str(v)
    if (s == ""
            or any(c in s for c in _YAML_UNSAFE_ANYWHERE)
            or s[:1] in _YAML_UNSAFE_FIRST
            or s.strip() != s):
        return json.dumps(s, ensure_ascii=False)
    return s
