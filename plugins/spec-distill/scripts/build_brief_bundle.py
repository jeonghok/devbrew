#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""build_brief_bundle.py — 충실도 축의 두 리뷰어가 공유하는 번들 (payload + audit §6).

형제 `build_seed_inline_blob.py`의 **구조**를 이식한다(명시 경로 → 라벨 붙은 조립 →
stdout). 조립 로직이 두 소비자에 각각 따로 있으면 한쪽만 고쳐질 때 두 리뷰어가 다른
재료를 보는 drift가 생긴다.

**이식하는 것은 구조이지 그 파일의 실패 정책이 아니다.** 형제는 원문 절을 못 찾으면
stderr로 경고하고 그대로 조립한다(fail-open). 여기서는 **rc 2 · 무디스패치**다 —
원문 없이 충실도를 물으면 "왜곡 없음"이 나온다.

**audit 경로를 유추하지 않는다**(형제가 명시적으로 거부한 것). 재료를 어디서 가져올지의
유추는 실패했을 때 조용하고, 잘못된 재료로 리뷰를 태우는 것이 없는 것보다 나쁘다.
게이트의 `resolve_audit()`이 stem을 유도하는 것과 층이 다르다 — 그것은 찾는 것이 아니라
payload가 어느 audit을 자기 것이라 부를지 고르지 못하게 거절하는 것이다.

라벨 토큰은 **마크다운 헤딩이 아니다.** 헤딩이면 payload 자신의 절 헤딩들과 같은
네임스페이스에 들어가 "몇 번째 ##인가"가 다시 문제가 된다. 그리고 실린 audit §6의
**절 헤딩은 벗긴다** — 안 벗기면 payload의 같은 헤딩과 바이트 동일해져, 라벨을 붙여도
"§6을 보라"는 지시가 먼저 나오는 쪽(S1 하나)에 걸린다.

exit: 0 정상 / 2 payload·audit 부재·읽기 실패·audit §6 없음(무디스패치) /
3 번들 payload 부분에 audit 파일명 잔존(위생 미달 — 호출자가 degrade 기록 후 계속)
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

REDACT_KEYS = ("audit_file", "name", "created_at")
SECTION6_RE = re.compile(r"(?m)^##\s+6\.\s+사용자 원문[^\n]*$")
NEXT_SECTION_RE = re.compile(r"(?m)^##\s+\d+\.")
AUDIT_NAME_RE = re.compile(r"\S*\.audit\.md\b")


def redact_frontmatter(text: str) -> str:
    for k in REDACT_KEYS:
        text = re.sub(rf"(?m)^({k}\s*:\s*)[^\n]*$", r"\1<redacted>", text, count=1)
    return text


def audit_verbatim(audit_text: str):
    """audit §6의 **항목만** 반환한다 (절 헤딩 제외). 절이 없으면 None."""
    m = SECTION6_RE.search(audit_text)
    if not m:
        return None
    rest = audit_text[m.end():]
    nxt = NEXT_SECTION_RE.search(rest)
    return (rest[: nxt.start()] if nxt else rest).strip()


def assemble(payload_text: str, verbatim: str) -> str:
    return (f"<<<PAYLOAD>>>\n{redact_frontmatter(payload_text).strip()}\n\n"
            f"<<<AUDIT-VERBATIM>>>\n{verbatim}\n")


def main() -> int:
    p = argparse.ArgumentParser(prog="build_brief_bundle.py")
    p.add_argument("payload_file")
    p.add_argument("audit_file")
    args = p.parse_args()
    paths = {"payload_file": pathlib.Path(args.payload_file),
             "audit_file": pathlib.Path(args.audit_file)}
    for label, path in paths.items():
        if not path.is_file():
            print(f"{label} not found: {path}", file=sys.stderr)
            return 2
    try:
        payload_text = paths["payload_file"].read_text(encoding="utf-8")
        audit_text = paths["audit_file"].read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(f"읽기 실패: {exc}", file=sys.stderr)
        return 2
    verbatim = audit_verbatim(audit_text)
    if verbatim is None:
        print(f"{paths['audit_file']} 에 `## 6. 사용자 원문` 절이 없다 — "
              "원문 없이 충실도를 물으면 「왜곡 없음」이 나온다. 조립하지 않는다.",
              file=sys.stderr)
        return 2
    redacted_payload = redact_frontmatter(payload_text)
    sys.stdout.write(assemble(payload_text, verbatim))
    # 위생 스캔은 **payload 부분에만** 건다. 번들이 audit 내용을 의도적으로 싣게 됐으므로
    # 전체를 스캔하면 정상 동작이 매번 exit 3을 낸다.
    if AUDIT_NAME_RE.search(redacted_payload):
        print("[spec-distill] 번들 payload 부분에 audit 파일명이 남아 있다 — "
              "원문 보존이 우선이라 지우지 않는다(호출자가 degrade 기록).", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main())
