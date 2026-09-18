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

세 verbatim 절(`UNTRUSTED_VERBATIM_SECTIONS`)의 경계와 중복은 `seed_review_log.section_body` ·
`duplicate_headings` 한 곳이 정한다(fix round 1) — 이 파일이 자기 정규식으로 절을 다시 자르면
audit 템플릿 제목이 아닌 임의의 `## ` 줄에서 잘리거나(truncation), 비신뢰 본문 안에 심긴 가짜
제목 줄이 진짜 절을 가릴 수 있다(hijacking, Important #1b/#1c). `duplicate_headings` 가 하나라도
잡으면 조립하지 않는다 — 어느 occurrence 가 진짜인지 이 코드가 골라 버리면 그 선택 자체가
공격 표면이 된다.

Usage: build_seed_inline_blob.py <seed_file> <audit_file> <claude_md_file> [--for detect|recritic]
"""
from __future__ import annotations

import argparse
import pathlib
import re
import sys

# 제목-모양 판정(heading-shaped line)은 이 파일이 계산하지 않는다 — `scripts/section6.py`
# 한 곳이다(§6-단일화 락, test_check_brief.sh). 헤딩 마커를 소비하는 정규식이 section6.py
# 밖에 있으면 그 락이 재발(소비자마다 다른 §6 계산)로 읽어 red 를 낸다.
_SCRIPTS_DIR = str(pathlib.Path(__file__).resolve().parent)
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)
import section6  # noqa: E402
from seed_review_log import duplicate_headings, section_body, user_quotes  # noqa: E402

# 리뷰어에게 비신뢰 verbatim 으로 알릴 audit 자리 — seed 프로필 `## 처분 안내` 가 이 셋을 이름으로
# 가리킨다(shared/tests/test_docreview_profiles.sh 가 이 튜플에서 도출해 대조한다). assemble() 은
# 이 튜플을 **읽어서** 헤딩 문구와 `section_body` 조회 키를 만든다 — 같은 문자열을 따로 다시
# 타이핑하지 않는다(fix round 1 Important #2 — 넷째 자리가 생기거나 헤딩이 바뀌어도 락이 조용히
# 통과하던 결함).
UNTRUSTED_VERBATIM_SECTIONS = ("## 1. 원문", "## 2. 질문 전체", "## 6. 리뷰 결정")

FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.S)

# 비신뢰 절 본문 안에서 CommonMark 가 실제 헤딩으로 렌더할 줄(들여쓰기 0–3칸 + ATX `#`) — 리뷰어가
# 읽는 번들에서 위조 절 제목처럼 보일 수 있다(fix round 1 Important #1a). 절 경계 자체는 이 정규식이
# 끊지 않는다(그건 seed_review_log.section_body 가 audit 템플릿 제목으로만 막는다) — 여기서는
# stderr 경고만 내고 본문 바이트는 그대로 둔다(비신뢰 원문 보존이 우선). 판정 자체는
# `section6.HEADING_SHAPED_RE` — 같은 패턴을 여기서 다시 정의하지 않는다(§6-단일화 락).

# audit 템플릿이 `## 2. 질문 전체` 안에서 라운드마다 쓰는 고정 제목(`interview-seed-audit-template.md`
# 의 `### 라운드 <n>`) — 사용자 문구가 아니라 호스트가 매 라운드 똑같이 쓰는 스캐폴드라 위 경고에서
# 뺀다(fix round 1 controller ruling — 이 줄까지 매번 경고하면 정상 seed 마다 늘 시끄러워 신호를
# 잃는다). 그 밖의 heading-모양 줄(예: 사용자 답 뒤에 붙은 `# 다른 제목`)은 여전히 걸린다.
ROUND_SCAFFOLD_RE = re.compile(r'^### 라운드 \d+$')


def seed_body(text: str) -> str:
    """frontmatter 를 뺀 seed 본문 — 리뷰 대상은 사람이 읽는 메시지다(check_seed.py 의 body_of 와 같은 이유)."""
    return FRONTMATTER_RE.sub("", text, count=1)


def _or_none(s: str | None) -> str:
    s = (s or "").strip()
    return s if s else "(없음)"


def _heading_line_no(text: str, heading: str) -> int | None:
    """`heading` 과 줄 전체가 같은 첫 줄의 1-based 줄 번호(`section_body` 와 같은 매치 규칙)."""
    for i, line in enumerate(text.splitlines()):
        if line.strip() == heading:
            return i + 1
    return None


def heading_shaped_warnings(audit_text: str, heading: str, body: str) -> list[int]:
    """`heading` 절 본문 안에서 heading-모양(`section6.HEADING_SHAPED_RE`)으로 보이는 줄의 audit 파일
    절대 줄 번호. `## 2. 질문 전체` 의 `### 라운드 <n>` 스캐폴드는 뺀다. 절이 없으면 빈 목록."""
    start = _heading_line_no(audit_text, heading)
    if start is None:
        return []
    exempt_round_scaffold = heading == "## 2. 질문 전체"
    out = []
    for i, line in enumerate(body.splitlines()):
        if not section6.HEADING_SHAPED_RE.match(line):
            continue
        if exempt_round_scaffold and ROUND_SCAFFOLD_RE.match(line.strip()):
            continue
        out.append(start + 1 + i)
    return out


def assemble(seed_text: str, audit_text: str, claude_md_text: str, consumer: str = "detect") -> str:
    sec_raw, sec_questions, sec_decisions = UNTRUSTED_VERBATIM_SECTIONS
    parts = [
        "## 초안 (interview-seed 본문)\n\n" + seed_body(seed_text).strip(),
        f"## 사용자 원문 (audit `{sec_raw}`)\n\n" + _or_none(section_body(audit_text, sec_raw)),
        f"## 질문 전체 (audit `{sec_questions}`)\n\n" + _or_none(section_body(audit_text, sec_questions)),
    ]
    if consumer == "recritic":
        qs = user_quotes(audit_text)
        parts.append(f"## 사용자 결정 문구 (audit `{sec_decisions}` 에서 사용자 문구만)\n\n"
                     + ("\n".join('- "%s"' % q for q in qs) if qs else "(없음)"))
    else:
        parts.append(f"## 리뷰 결정 (audit `{sec_decisions}`)\n\n"
                     + _or_none(section_body(audit_text, sec_decisions)))
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

    dups = duplicate_headings(audit_text)
    if dups:
        for heading, nums in dups:
            print(f"[spec-distill] {paths['audit_file']} 의 `{heading}` 가 {len(nums)}번(줄 "
                  f"{', '.join(str(n) for n in nums)}) 나온다 — 어느 줄이 그 절의 진짜 경계인지 "
                  "정해지지 않는다. 번들을 조립하지 않는다.", file=sys.stderr)
        return 2

    for heading in UNTRUSTED_VERBATIM_SECTIONS:
        body = section_body(audit_text, heading)
        if body is None:
            print(f"경고: {paths['audit_file']} 에 `{heading}` 절이 없다 — 「(없음)」으로 조립한다",
                  file=sys.stderr)
            continue
        lns = heading_shaped_warnings(audit_text, heading, body)
        if lns:
            print(f"[spec-distill] 경고: {paths['audit_file']} 의 `{heading}` 절 안에 heading-모양 "
                  f"줄이 있다(줄 {', '.join(str(n) for n in lns)}) — 리뷰어가 번들에서 이 줄을 "
                  "헤딩으로 볼 수 있다(비신뢰 본문이라 지우지 않는다).", file=sys.stderr)

    sys.stdout.write(assemble(seed_text, audit_text, claude_md_text, args.consumer))
    return 0


if __name__ == "__main__":
    sys.exit(main())
