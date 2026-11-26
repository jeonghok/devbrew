#!/usr/bin/env python3
"""spec-review 진입 검사 — 은퇴 스위치 공시.

stdout 에 JSON 한 줄을 낸다: {"advisories": [str]}. 정상 실행은 항상 rc 0 이고 리뷰는 늘
진행된다. 소비자는 `skills/spec-review/SKILL.md` 의 `review-entry` 펜스이고, 펜스가 스키마를
검사해 어긋나거나 rc≠0 이면 끔으로 친다.
"""
from __future__ import annotations

import json
import os
import sys

#: 자동 리뷰를 끄던 토큰. 리뷰 기능은 남아 있으므로 대체 스위치를 댄다.
REVIEW_TOKENS = ("spec-distill:Stop", "spec-distill:review-dispatch")
#: 구조 검사·리마인더를 끄던 토큰. 끄던 대상이 삭제돼 등가물이 없다 — 대체재를 대지 않는다.
GONE_TOKENS = ("spec-distill:validator", "spec-distill:PostToolUse",
               "spec-distill:reminder", "spec-distill:UserPromptSubmit")
#: 독립 환경변수 스위치. 옛 소비자가 `== "1"` 로 읽었으므로 여기서도 그렇게 읽는다.
AUTOREVIEW_VAR = "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW"

ALTERNATIVES = (
    "설계문서 리뷰를 끄려면 /spec-distill:spec-review 를 부르지 않는다. "
    "플러그인 전체는 Claude Code 의 플러그인 끄기(/plugin · claude plugin disable · 설정의 enabledPlugins)."
)


def retired_advisories() -> list[str]:
    """설정된 은퇴 스위치마다 사용자의 토큰을 되읽는 문장.

    `kill_switch_active` 를 쓰지 않는 이유: bool 만 내므로 어느 토큰이 설정됐는지 이름을 댈 수
    없다. 매칭은 그 함수와 같은 규칙(콤마 분리 · 양끝 공백 제거 · 전체 토큰)이다.
    """
    raw = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    tokens = {t.strip() for t in raw.split(",") if t.strip()}
    out: list[str] = []
    review_hit = [t for t in REVIEW_TOKENS if t in tokens]
    if review_hit:
        out.append(
            f"[spec-distill] DEVBREW_SKIP_HOOKS 의 {', '.join(review_hit)} 는 더 이상 리뷰를 "
            f"막지 않는다 — 가리키던 훅이 삭제됐다. 이번 리뷰는 진행된다. {ALTERNATIVES}"
        )
    gone_hit = [t for t in GONE_TOKENS if t in tokens]
    if gone_hit:
        out.append(
            f"[spec-distill] DEVBREW_SKIP_HOOKS 의 {', '.join(gone_hit)} 는 대상이 삭제돼 "
            f"아무것도 끄지 않는다."
        )
    if os.environ.get(AUTOREVIEW_VAR) == "1":
        out.append(
            f"[spec-distill] {AUTOREVIEW_VAR}=1 은 읽는 곳이 없어 아무것도 끄지 않는다. "
            f"{ALTERNATIVES}"
        )
    return out


def evaluate() -> dict:
    return {"advisories": retired_advisories()}


def main() -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8")  # type: ignore[union-attr]
    except (AttributeError, OSError, ValueError):
        pass
    print(json.dumps(evaluate(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
