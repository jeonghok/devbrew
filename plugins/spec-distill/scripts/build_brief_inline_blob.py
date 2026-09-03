#!/usr/bin/env python3
"""build_brief_inline_blob.py — **brief-readback 전용** payload blob.

v0.45.0에서 충실도 축이 `build_brief_bundle.py`로 갈라졌다(payload + audit §6을 조립해
`brief-critic`과 codex #2가 받는다). 이 파일은 계약이 바뀌지 않았고 소비자가 하나로
줄었다 — 냉독이 재는 것은 *하류가 실제로 받는 문서*의 읽힘이므로 payload-only가 맞다.
번들을 주면 냉독이 하류가 절대 보지 않을 것을 읽는다.

`brief-readback`은 payload를 **경로가 아니라 전문 inline**으로 받는다. 그때 frontmatter의
세 값 — `audit_file` · `name` · `created_at` — 을 `<redacted>`로 바꾼다. 셋을 잃어도
손실이 없다: 주제는 본문 H1 제목에 남아 냉독에 지장이 없고, frontmatter ↔ body 일치는
게이트의 bijection B가 기계 보장한다.

**이것은 보장이 아니라 위생 조치다** (spec §5.1.1 "층 1"). 격리는 `tools: []`라는 도구
표면으로 성립한다. redaction은 그 표면이 어떤 이유로든 무너졌을 때의 *쉬운 길*을 없애는
방어-in-depth이고, 그 밖에는 불필요하지만 프롬프트를 작게 유지하는 부수 효과가 있어
유지한다.

`audit_file`을 redact해도 `name` + `created_at`으로 `<date>-<topic>-interview.audit.md`를
**재구성**할 수 있으므로 세 값을 함께 지운다(round-1 리뷰가 적발한 경로).

§6 사용자 원문(payload의 `S1`)은 **절대 건드리지 않는다.** 본문이 audit 파일명을 언급하면
원문 보존이 이기고 **exit 3**으로 알린다 — 호출자가 degradation record를 남기고 계속한다.

exit: 0 깨끗한 redaction / 3 본문에 audit 파일명 잔존(위생 미달) / 2 usage·파일 부재·읽기 실패
     (비-UTF-8·권한). **1은 절대 내지 않는다** — 호출자 표가 0/2/3만 라우팅하므로
     표 밖 코드는 빈 blob 디스패치로 샌다.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REDACT_KEYS = ("audit_file", "name", "created_at")
REDACTED = "<redacted>"
AUDIT_SUFFIX_RE = re.compile(r"\.audit\.md\b")


def redact_frontmatter(text: str) -> str:
    """frontmatter 블록 안에서만 세 키의 값을 치환한다(body 동명 문자열은 불변).

    콜론 앞뒤 공백은 **`[ \\t]*`(같은 줄 안)** 로 한정한다. `\\s*`는 `\\n`도 삼키므로,
    값이 빈 키(`name:` / `audit_file:` 처럼 콜론 뒤에 내용이 없는 줄)에서 `(.*)$`가
    **다음 줄**을 이 줄의 값으로 잡아 그 줄 전체를 `<redacted>`로 갈아치운다 — 인접
    frontmatter 키가 통째로 사라진다(실측: `audit_file:`가 비었을 때 바로 다음 줄의
    `created_at: 2026-07-27`이 삭제됐다).

    도달 가능성이 이론적이지 않다: `check_brief.py`의 frontmatter 검증은 `type` ·
    `next_phase` · `audit_file` · `user_sourced_items`를 보고 `name`·`created_at`은
    보지 않으므로, 빈 `name:`은 구조 게이트를 통과한 뒤 여기서 조용히 한 줄을 지운
    사본이 격리 critic에게 간다.

    `brief_review_state.py`의 `parse()`/`_set_scalar()`, `_parse_degradations()`가
    같은 클래스의 버그를 이미 같은 방식으로 닫았다 — 이 파일이 남은 하나였다.
    """
    if not text.startswith("---"):
        return text
    end = text.find("\n---", 3)
    if end == -1:
        return text
    head, body = text[:end], text[end:]
    for key in REDACT_KEYS:
        head = re.sub(rf"(?m)^({re.escape(key)}[ \t]*:[ \t]*)(.*)$",
                      lambda m: m.group(1) + REDACTED, head)
    return head + body


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print("usage: build_brief_inline_blob.py <payload>", file=sys.stderr)
        return 2
    path = Path(argv[1])
    if not path.is_file():
        print(f"payload file not found: {path}", file=sys.stderr)
        return 2
    # 읽기 실패를 **문서화된** exit 2로 매핑한다. 가드가 없으면 UnicodeDecodeError가
    # 그대로 새어 Python 기본 exit 1이 되는데, 호출 SKILL의 표는 0/2/3만 라우팅하므로
    # 1은 어느 분기에도 걸리지 않는다. 그 상태에서 `BLOB`은 빈 문자열이고 `${BLOB}`이
    # 그대로 Agent() 프롬프트에 보간돼 critic이 **빈 `<brief>`** 를 리뷰하고 "왜곡 없음"을
    # 보고한다 — SKILL이 프로즈로 금지한 fail-open이 코드 경로로는 열려 있었다.
    try:
        text = path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"payload 읽기 실패 ({type(exc).__name__}): {path} — {exc}", file=sys.stderr)
        return 2
    blob = redact_frontmatter(text)
    sys.stdout.write(blob)
    if AUDIT_SUFFIX_RE.search(blob):
        print("[spec-distill v0.45.0] blob 본문에 audit 파일명이 남아 있다 — §6 원문 보존이 "
              "우선이므로 지우지 않았다. 이 블롭의 유일한 소비자는 readback이다(v0.45.0부터 "
              "critic은 build_brief_bundle.py의 번들을 받는다) — 냉독 gap 판정을 신뢰도 "
              "하향으로 읽어라 (component: readback, verification_status: degraded).",
              file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
