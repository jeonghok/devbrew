#!/usr/bin/env python3
"""build_seed_inline_blob.py — assembles the seed-suppression review bundle.

`agents/seed-critic.md` (Claude 쪽 억제 비평자)는 "the draft, the user's raw
statements, and the repo CLAUDE.md inline, bundled as a single
`<draft>${BLOB}</draft>` block"을 받는다고 스스로 문서화한다. 이 파일이 그
`${BLOB}`(바깥 `<draft>` 태그는 제외 — 그건 호출자가 감싼다)을 조립하는 유일한
코드다. `run_seed_codex_reviewer.sh`의 codex 쪽 리뷰도 같은 세 재료를 봐야
공정하므로, 이 파일이 만드는 번들을 `run_seed_codex_reviewer.sh <axis> <payload>
...`의 `<payload>`로 그대로 쓸 수 있다 — 조립 로직이 두 소비자(Claude 격리
critic · codex)에 각각 따로 있으면 한쪽만 고쳐질 때 두 리뷰어가 다른 재료를 보는
drift 가 생긴다.

세 재료는 **명시적 파일 경로**로만 받는다(argv 인라인 금지 — 형제 프롬프트
빌더들과 같은 injection-안전 관용구). 자동 유추(예: seed frontmatter 의
`audit_file:` 필드를 따라가기)는 하지 않는다 — 유추가 실패했을 때의 침묵이
호출자가 잘못된 재료로 리뷰를 태우는 것보다 나쁘다.

Usage: build_seed_inline_blob.py <seed_file> <audit_file> <claude_md_file>
Stdout: 조립된 번들(초안 + 사용자 원문 + CLAUDE.md).
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

# check_seed.py 의 frontmatter/원문-절 정규식과 같은 앵커를 쓴다(같은 파일에 대해
# 다른 정규식을 쓰면 그 파일을 seed 게이트는 통과시키는데 이 조립기는 다르게
# 읽는 drift 가 생긴다). 이 파일이 그 정규식들을 재사용(import)하지 않고 다시
# 적는 이유: check_seed.py 의 그것들은 `gate()` 함수 안에 인라인돼 있어 이름 붙은
# import 대상이 아니고, 이 스크립트가 재는 것(존재 검사)과 여기서 하는 것(내용
# 추출)은 다른 연산이다 — 강제로 공유 함수를 만들면 그 함수 하나가 두 다른 계약
# (게이트 통과/거부 · 내용 있는 그대로 추출)을 동시에 지게 된다.
FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.S)
RAW_TEXT_SECTION_RE = re.compile(r'^##\s*1\.\s*원문\s*$(.*?)(?=^##\s|\Z)', re.M | re.S)


def seed_body(text: str) -> str:
    """frontmatter 를 뺀 seed 본문. 첫 턴에 실제로 붙여넣는 것이 본문이므로
    리뷰 대상도 본문이어야 한다(check_seed.py 의 body_of() 와 같은 이유)."""
    return FRONTMATTER_RE.sub("", text, count=1)


def raw_statements(audit_text: str) -> str:
    """audit 파일의 `## 1. 원문` 절 본문. 없으면 빈 문자열을 낸다 — 호출자가
    아래 main() 에서 그 빈 문자열을 loud 하게 알린다(조용한 결측 금지)."""
    m = RAW_TEXT_SECTION_RE.search(audit_text)
    return m.group(1).strip() if m else ""


def assemble(seed_text: str, audit_text: str, claude_md_text: str) -> str:
    return (
        "## 초안 (interview-seed 본문)\n\n"
        f"{seed_body(seed_text).strip()}\n\n"
        "## 사용자 원문 (audit `## 1. 원문`)\n\n"
        f"{raw_statements(audit_text)}\n\n"
        "## 레포 CLAUDE.md\n\n"
        f"{claude_md_text.strip()}\n"
    )


def main() -> int:
    p = argparse.ArgumentParser(prog="build_seed_inline_blob.py")
    p.add_argument("seed_file")
    p.add_argument("audit_file")
    p.add_argument("claude_md_file")
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

    sys.stdout.write(assemble(seed_text, audit_text, claude_md_text))
    return 0


if __name__ == "__main__":
    sys.exit(main())
