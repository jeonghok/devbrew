#!/usr/bin/env python3
"""build_brief_inline_blob.py — critic·readback에 inline될 payload blob (Spec B AC2/AC3).

`brief-critic`과 `brief-readback`은 payload를 **경로가 아니라 전문 inline**으로 받는다.
그때 frontmatter의 세 값 — `audit_file` · `name` · `created_at` — 을 `<redacted>`로
바꾼다. 셋을 잃어도 손실이 없다: 충실도 판정은 body §2 ↔ §6 대조이고 frontmatter ↔ body
일치는 게이트의 bijection B가 기계 보장하며, 주제는 본문 H1 제목에 남아 readback의 냉독에도
지장이 없다.

**이것은 보장이 아니라 위생 조치다** (spec §5.1.1 "층 1"). 격리는 도구 표면(zero-tool)으로
성립하거나 성립하지 않는다. redaction은 실패 분기에서 *쉬운 길*을 없애는 것이고, 통과
분기에서는 불필요하지만 프롬프트를 작게 유지하려 유지한다.

`audit_file`을 redact해도 `name` + `created_at`으로 `<date>-<topic>-interview.audit.md`를
**재구성**할 수 있으므로 세 값을 함께 지운다(round-1 리뷰가 적발한 경로).

§6 사용자 원문은 **절대 건드리지 않는다.** 본문이 audit 파일명을 언급하면 원문 보존이
이기고 **exit 3**으로 알린다 — 호출자가 degradation record를 남기고 계속한다.

exit: 0 깨끗한 redaction / 3 본문에 audit 파일명 잔존(위생 미달) / 2 usage·파일 부재
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REDACT_KEYS = ("audit_file", "name", "created_at")
REDACTED = "<redacted>"
AUDIT_SUFFIX_RE = re.compile(r"\.audit\.md\b")


def redact_frontmatter(text: str) -> str:
    """frontmatter 블록 안에서만 세 키의 값을 치환한다(body 동명 문자열은 불변)."""
    if not text.startswith("---"):
        return text
    end = text.find("\n---", 3)
    if end == -1:
        return text
    head, body = text[:end], text[end:]
    for key in REDACT_KEYS:
        head = re.sub(rf"(?m)^({re.escape(key)}\s*:\s*)(.*)$",
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
    text = path.read_text(encoding="utf-8")
    blob = redact_frontmatter(text)
    sys.stdout.write(blob)
    if AUDIT_SUFFIX_RE.search(blob):
        print("[spec-distill v0.24.0] blob 본문에 audit 파일명이 남아 있다 — §6 원문 보존이 "
              "우선이므로 지우지 않았다. 격리 위생 미달을 degradation record로 남겨라 "
              "(component: critic, verification_status: degraded).", file=sys.stderr)
        return 3
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
