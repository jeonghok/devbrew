#!/usr/bin/env python3
"""build_seed_inline_blob.py — seed 리뷰 번들을 조립한다.

문서 리뷰 엔진의 seed 자리(`framing-requests` 의 `## 검증`)가 탐지 리뷰어 · codex 러너 · 재비판자에게
넘기는 문서가 이 파일의 출력이다. 엔진의 `--doc`(스냅숏 · 얼림 검사 대상)은 seed 파일 자신이고,
리뷰어가 **읽는** 것은 이 번들이다.

재료 다섯 — seed 본문 · audit `## 1. 원문` · audit `## 2. 질문 전체` · audit `## 6. 리뷰 결정` ·
레포 CLAUDE.md. `## 2` 가 없으면 「1번」 같은 짧은 답이 무엇을 확인한 것인지 복원할 수 없다.

소비자별로 갈린다(`--for`):
  detect   (기본) 탐지 리뷰어 · codex — 다섯 재료 전부.
  recritic 재비판자 — `## 6` 대신 그 절의 사용자 문구만 뽑은 목록. 판정 이력(결정 id · 라운드 ·
           채택/기각 · finding id · 요약)이 가면 엔진이 5단계 익명화로 지운 프레이밍이 재비판자에게
           되돌아간다(엔진 절차서 6단계 — 입력은 문서 · items · 프로필, 그 밖에는 아무것도).

재료는 **명시적 파일 경로**로만 받는다 — seed frontmatter 의 `audit_file:` 을 따라가는 자동 유추는
하지 않는다. 유추가 실패했을 때의 침묵이 잘못된 재료로 리뷰를 태우는 것보다 나쁘다.

Usage: build_seed_inline_blob.py <seed_file> <audit_file> <claude_md_file> [--for detect|recritic]
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

from seed_review_log import section_body, user_quotes

# 리뷰어에게 비신뢰 verbatim 으로 알릴 audit 자리 — seed 프로필 `## 처분 안내` 가 이 셋을 이름으로
# 가리킨다(shared/tests/test_docreview_profiles.sh 가 이 튜플에서 도출해 대조한다).
UNTRUSTED_VERBATIM_SECTIONS = ("## 1. 원문", "## 2. 질문 전체", "## 6. 리뷰 결정")

# check_seed.py 의 frontmatter/원문-절 정규식과 같은 앵커를 쓴다 — 같은 파일을 seed 게이트는
# 통과시키는데 이 조립기는 다르게 읽는 drift 를 막는다. `## 2` · `## 6` 은 게이트가 보지 않는
# 절이라 헤딩 줄 일치(`section_body`)로 자른다.
FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.S)
RAW_TEXT_SECTION_RE = re.compile(r'^##\s*1\.\s*원문\s*$(.*?)(?=^##\s|\Z)', re.M | re.S)


def seed_body(text: str) -> str:
    """frontmatter 를 뺀 seed 본문 — 리뷰 대상은 사람이 읽는 메시지다(check_seed.py 의 body_of 와 같은 이유)."""
    return FRONTMATTER_RE.sub("", text, count=1)


def raw_statements(audit_text: str) -> str:
    m = RAW_TEXT_SECTION_RE.search(audit_text)
    return m.group(1).strip() if m else ""


def _or_none(s: str | None) -> str:
    s = (s or "").strip()
    return s if s else "(없음)"


def assemble(seed_text: str, audit_text: str, claude_md_text: str, consumer: str = "detect") -> str:
    parts = [
        "## 초안 (interview-seed 본문)\n\n" + seed_body(seed_text).strip(),
        "## 사용자 원문 (audit `## 1. 원문`)\n\n" + raw_statements(audit_text),
        "## 질문 전체 (audit `## 2. 질문 전체`)\n\n" + _or_none(section_body(audit_text, "## 2. 질문 전체")),
    ]
    if consumer == "recritic":
        qs = user_quotes(audit_text)
        parts.append("## 사용자 결정 문구 (audit `## 6. 리뷰 결정` 에서 사용자 문구만)\n\n"
                     + ("\n".join('- "%s"' % q for q in qs) if qs else "(없음)"))
    else:
        parts.append("## 리뷰 결정 (audit `## 6. 리뷰 결정`)\n\n"
                     + _or_none(section_body(audit_text, "## 6. 리뷰 결정")))
    parts.append("## 레포 CLAUDE.md\n\n" + claude_md_text.strip())
    return "\n\n".join(parts) + "\n"


def main() -> int:
    p = argparse.ArgumentParser(prog="build_seed_inline_blob.py")
    p.add_argument("seed_file")
    p.add_argument("audit_file")
    p.add_argument("claude_md_file")
    p.add_argument("--for", dest="consumer", choices=("detect", "recritic"), default="detect")
    args = p.parse_args()

    paths = {
        "seed_file": pathlib.Path(args.seed_file),
        "audit_file": pathlib.Path(args.audit_file),
        "claude_md_file": pathlib.Path(args.claude_md_file),
    }
    for label, path in paths.items():
        if not path.is_file():
            print(f"{label} not found: {path}", file=sys.stderr)
            return 2

    seed_text = paths["seed_file"].read_text(encoding="utf-8", errors="replace")
    audit_text = paths["audit_file"].read_text(encoding="utf-8", errors="replace")
    claude_md_text = paths["claude_md_file"].read_text(encoding="utf-8", errors="replace")

    if not raw_statements(audit_text):
        print(f"경고: {paths['audit_file']} 에서 `## 1. 원문` 절을 찾지 못했다 "
              "(비었거나 헤딩이 다르다) — 사용자 원문 없이 조립한다", file=sys.stderr)
    for heading in ("## 2. 질문 전체", "## 6. 리뷰 결정"):
        if section_body(audit_text, heading) is None:
            print(f"경고: {paths['audit_file']} 에 `{heading}` 절이 없다 — 「(없음)」으로 조립한다",
                  file=sys.stderr)

    sys.stdout.write(assemble(seed_text, audit_text, claude_md_text, args.consumer))
    return 0


if __name__ == "__main__":
    sys.exit(main())
