#!/usr/bin/env python3
"""build_seed_inline_blob.py — seed 리뷰 번들을 조립한다.

문서 리뷰 엔진의 seed 자리(`request-framing` 의 `## 검증`)가 탐지 리뷰어 · codex 러너 · 재비판자에게
넘기는 문서가 이 파일의 출력이다. 엔진의 `--doc`(스냅숏 · 얼림 검사 대상)은 seed 파일 자신이고,
리뷰어가 **읽는** 것은 이 번들이다.

재료 여섯 — seed 본문 · audit `## 1. 원문` · audit `## 2. 질문 전체` · audit `## seed 에서 덜어 낸 것`
(저자가 쓴 표) · audit `## 6. 리뷰 결정` · 레포 CLAUDE.md. `## 2` 가 없으면 「1번」 같은 짧은 답이 무엇을 확인한 것인지 복원할 수 없다.

소비자별로 갈린다(`--for`):
  detect   (기본) 탐지 리뷰어 · codex — 여섯 재료 전부.
  recritic 재비판자 — `## 6` 대신 그 절의 사용자 문구만 뽑은 목록. 판정 이력(결정 id · 라운드 ·
           채택/기각 · finding id · 요약)이 가면 엔진이 5단계 익명화로 지운 프레이밍이 재비판자에게
           되돌아간다(엔진 절차서 6단계 — 입력은 문서 · items · 프로필, 그 밖에는 아무것도).

`## 1. 원문` 이 없거나 비었으면 조립하지 않는다(rc 2) — 대조할 원문 없이 억제를 물으면 「억제 없음」이
공허하게 나온다. `## 2` · `## 6` 이 없거나 `## 2` 가 비었으면 `[spec-distill]` 경고를 내고 「(없음)」으로
조립한다(첫 라운드의 `## 6` 은 비어 있는 것이 정상이다).

레포 CLAUDE.md 가 없으면 그 절을 「레포 CLAUDE.md 없음」 한 줄로 채운다(있는데 파일이 아니면 rc 2 — 끊긴 링크 ·
폴더는 없는 것이 아니다).

재료는 **명시적 파일 경로**로만 받는다 — seed frontmatter 의 `audit_file:` 을 따라가는 자동 유추는
하지 않는다. 유추가 실패했을 때의 침묵이 잘못된 재료로 리뷰를 태우는 것보다 나쁘다.

세 verbatim 절(`UNTRUSTED_VERBATIM_SECTIONS`)의 경계와 중복은 `seed_review_log.section_body` ·
`duplicate_headings` 한 곳이 정한다 — 이 파일이 자기 정규식으로 절을 다시 자르면 audit 템플릿
제목이 아닌 임의의 `## ` 줄에서 잘리거나(truncation), 비신뢰 본문 안에 심긴 가짜 제목 줄이 진짜
절을 가릴 수 있다(hijacking). `duplicate_headings` 가 하나라도 잡거나 템플릿 제목 순서가 어긋나면
(`heading_structure`) 조립하지 않는다 — 어느 occurrence 가 진짜인지 이 코드가 골라 버리면 그 선택 자체가
공격 표면이 된다.

Usage: build_seed_inline_blob.py <seed_file> <audit_file> <claude_md_file> [--for detect|recritic] [--no-absent-warning]

`--no-absent-warning` 은 「레포 CLAUDE.md 가 없다」 stderr 경고만 끈다 — 한 라운드가 이 스크립트를 두 번 부르므로
(탐지 · 재비판) 둘째 호출에만 붙여 경고가 라운드에 한 번만 나가게 한다. 번들 본문의 「레포 CLAUDE.md 없음」 한 줄과
그 밖의 모든 stderr 는 그대로다.
"""
from __future__ import annotations

import argparse
import os
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
from seed_review_log import (AuditAmbiguous, duplicate_headings, heading_structure,  # noqa: E402
                             read_audit_text, require_unambiguous, section_body, separator_lines,
                             separator_message, user_quotes)

# 리뷰어에게 비신뢰 verbatim 으로 알릴 audit 자리 — seed 프로필 `## 처분 안내` 가 이 셋을 이름으로
# 가리킨다(shared/tests/test_docreview_profiles.sh 가 이 튜플에서 도출해 대조한다). assemble() 은
# 이 튜플을 **읽어서** 헤딩 문구와 `section_body` 조회 키를 만든다 — 같은 문자열을 따로 다시
# 타이핑하면 넷째 자리가 생기거나 헤딩이 바뀌어도 락이 조용히 통과한다.
UNTRUSTED_VERBATIM_SECTIONS = ("## 1. 원문", "## 2. 질문 전체", "## 6. 리뷰 결정")

# 저자가 쓴 표라 위 튜플(비신뢰 verbatim)에는 넣지 않는다 — 두 소비자 모두에게 싣는다.
CUT_TABLE_SECTION = "## seed 에서 덜어 낸 것"

FRONTMATTER_RE = re.compile(r"\A---\n.*?\n---\n", re.S)

# 비신뢰 절 본문 안에서 CommonMark 가 실제 헤딩으로 렌더할 줄(들여쓰기 0–3칸 + ATX `#`) — 리뷰어가
# 읽는 번들에서 위조 절 제목처럼 보일 수 있다. 절 경계 자체는 이 정규식이 끊지 않는다(그건
# seed_review_log.section_body 가 audit 템플릿 제목으로만 막는다) — 여기서는 stderr 경고만 내고
# 본문 바이트는 그대로 둔다(비신뢰 원문 보존이 우선). 판정 자체는 `section6.HEADING_SHAPED_RE` —
# 같은 패턴을 여기서 다시 정의하지 않는다(§6-단일화 락).

# audit 템플릿이 `## 2. 질문 전체` 안에서 라운드마다 쓰는 고정 제목(`interview-seed-audit-template.md`
# 의 `### 라운드 <n>`) — 사용자 문구가 아니라 호스트가 매 라운드 똑같이 쓰는 스캐폴드라 위 경고에서
# 뺀다 — 이 줄까지 매번 경고하면 정상 seed 마다 늘 시끄러워 신호를 잃는다. 그 밖의 heading-모양
# 줄(예: 사용자 답 뒤에 붙은 `# 다른 제목`)은 여전히 걸린다.
ROUND_SCAFFOLD_RE = re.compile(r'^### 라운드 \d+$')

# audit `## 1. 원문` 안에서 받은 글마다 호스트가 쓰는 구분 줄의 머리 — 위 `### 라운드 <n>` 과 같은 이유로 경고에서
# 뺀다(정상 기록 파일마다 받은 글마다 경고하면 신호를 잃는다). Task 5 의 락이 audit 템플릿의 구분 줄 머리와
# 이 패턴을 맞춰 본다 — 글자를 바꾸면 그 락이 함께 RED.
RECEIVED_SEPARATOR_RE = re.compile(r"^### 받은 글 — \S")

# CLAUDE.md 가 없는 레포의 번들이 그 절에 싣는 한 줄.
CLAUDE_MD_ABSENT = "레포 CLAUDE.md 없음"


def seed_body(text: str) -> str:
    """frontmatter 를 뺀 seed 본문 — 리뷰 대상은 사람이 읽는 메시지다(check_seed.py 의 body_of 와 같은 이유)."""
    return FRONTMATTER_RE.sub("", text, count=1)


def _or_none(s: str | None) -> str:
    s = (s or "").strip()
    return s if s else "(없음)"


def _heading_line_no(text: str, heading: str) -> int | None:
    """`heading` 과 줄 전체가 같은 첫 줄의 1-based 줄 번호(`section_body` 와 같은 매치 규칙)."""
    for i, line in enumerate(text.split("\n")):
        if line.strip() == heading:
            return i + 1
    return None


def heading_shaped_warnings(audit_text: str, heading: str, body: str) -> list[int]:
    """`heading` 절 본문 안에서 heading-모양(`section6.HEADING_SHAPED_RE`)으로 보이는 줄의 audit 파일
    절대 줄 번호. `## 2. 질문 전체` 의 `### 라운드 <n>` 스캐폴드와 `## 1. 원문` 의 받은 글 구분 줄은 뺀다. 절이 없으면 빈 목록."""
    start = _heading_line_no(audit_text, heading)
    if start is None:
        return []
    exempt_round_scaffold = heading == "## 2. 질문 전체"
    exempt_received_separator = heading == "## 1. 원문"
    out = []
    for i, line in enumerate(body.split("\n")):
        if not section6.HEADING_SHAPED_RE.match(line):
            continue
        if exempt_round_scaffold and ROUND_SCAFFOLD_RE.match(line.strip()):
            continue
        if exempt_received_separator and RECEIVED_SEPARATOR_RE.match(line.strip()):
            continue
        out.append(start + 1 + i)
    return out


def assemble(seed_text: str, audit_text: str, claude_md_text: str | None, consumer: str = "detect") -> str:
    sec_raw, sec_questions, sec_decisions = UNTRUSTED_VERBATIM_SECTIONS
    parts = [
        "## 초안 (interview-seed 본문)\n\n" + seed_body(seed_text).strip(),
        f"## 사용자 원문 (audit `{sec_raw}`)\n\n" + _or_none(section_body(audit_text, sec_raw)),
        f"## 질문 전체 (audit `{sec_questions}`)\n\n" + _or_none(section_body(audit_text, sec_questions)),
    ]
    parts.append(f"## 덜어 낸 것 (audit `{CUT_TABLE_SECTION}` — 저자가 쓴 표)\n\n"
                 + _or_none(section_body(audit_text, CUT_TABLE_SECTION)))
    if consumer == "recritic":
        qs = user_quotes(audit_text)
        parts.append(f"## 사용자 결정 문구 (audit `{sec_decisions}` 에서 사용자 문구만)\n\n"
                     + ("\n".join('- "%s"' % q for q in qs) if qs else "(없음)"))
    else:
        parts.append(f"## 리뷰 결정 (audit `{sec_decisions}`)\n\n"
                     + _or_none(section_body(audit_text, sec_decisions)))
    parts.append("## 레포 CLAUDE.md\n\n"
                 + (CLAUDE_MD_ABSENT if claude_md_text is None else claude_md_text.strip()))
    return "\n\n".join(parts) + "\n"


def main() -> int:
    p = argparse.ArgumentParser(prog="build_seed_inline_blob.py")
    p.add_argument("seed_file")
    p.add_argument("audit_file")
    p.add_argument("claude_md_file")
    p.add_argument("--for", dest="consumer", choices=("detect", "recritic"), default="detect")
    p.add_argument("--no-absent-warning", dest="no_absent_warning", action="store_true")
    args = p.parse_args()

    paths = {
        "seed_file": pathlib.Path(args.seed_file),
        "audit_file": pathlib.Path(args.audit_file),
        "claude_md_file": pathlib.Path(args.claude_md_file),
    }
    claude_md_absent = False
    for label, path in paths.items():
        if label == "claude_md_file":
            try:
                os.lstat(path)
            except (FileNotFoundError, NotADirectoryError):
                missing = True
            except OSError as e:  # 권한 거부 같은 것은 없는 것이 아니다 — 멈춘다.
                print(f"{label} not found: {path} ({type(e).__name__}: {e.strerror})", file=sys.stderr)
                return 2
            else:
                missing = False
        else:
            missing = False
        if label == "claude_md_file" and missing:
            # 없는 것은 계속한다. 있는데 파일이 아닌 것(끊긴 링크 · 폴더)은 아래 검사가 그대로 멈춘다.
            claude_md_absent = True
            if not args.no_absent_warning:
                print(f"[spec-distill] 경고: 레포 CLAUDE.md 가 없다({path}) — 번들의 그 절을 "
                      f"「{CLAUDE_MD_ABSENT}」 한 줄로 채워 조립한다", file=sys.stderr)
            continue
        if not path.is_file():
            print(f"{label} not found: {path}", file=sys.stderr)
            return 2

    seed_text = paths["seed_file"].read_text(encoding="utf-8", errors="replace")
    audit_text = read_audit_text(paths["audit_file"], "replace")
    claude_md_text = (None if claude_md_absent
                      else paths["claude_md_file"].read_text(encoding="utf-8", errors="replace"))

    sep = separator_lines(audit_text)
    if sep:
        for ln in separator_message(sep).split("\n"):
            print("[build_seed_inline_blob] " + ln, file=sys.stderr)
        print(f"[spec-distill] {paths['audit_file']} 의 줄 구분을 하나로 정할 수 없다. 번들을 조립하지 않는다.",
              file=sys.stderr)
        return 2
    dups = duplicate_headings(audit_text)
    if dups:
        for heading, nums in dups:
            print(f"[spec-distill] {paths['audit_file']} 의 `{heading}` 가 {len(nums)}번(줄 "
                  f"{', '.join(str(n) for n in nums)}) 나온다 — 어느 줄이 그 절의 진짜 경계인지 "
                  "정해지지 않는다. 번들을 조립하지 않는다.", file=sys.stderr)
        return 2
    for problem in heading_structure(audit_text):
        print(f"[spec-distill] {paths['audit_file']} 의 템플릿 제목 순서가 어긋난다({problem}) — 어느 줄이 "
              "그 절의 진짜 경계인지 정해지지 않는다. 번들을 조립하지 않는다.", file=sys.stderr)
    if heading_structure(audit_text):
        return 2
    try:
        require_unambiguous(audit_text, UNTRUSTED_VERBATIM_SECTIONS[2])
    except AuditAmbiguous as e:  # `## 6` 에 기록 모양이 아닌 줄 — 리뷰어에게 «리뷰 결정» 으로 싣지 않는다
        print(str(e), file=sys.stderr)
        print(f"[spec-distill] {paths['audit_file']} 의 `## 6` 을 판단할 수 없다. 번들을 조립하지 않는다.", file=sys.stderr)
        return 2

    sec_raw, sec_questions, _ = UNTRUSTED_VERBATIM_SECTIONS
    raw = section_body(audit_text, sec_raw)
    if not (raw or "").strip():
        print(f"[spec-distill] {paths['audit_file']} 의 `{sec_raw}` 절이 "
              f"{'없다' if raw is None else '비었다'} — 대조할 원문 없이 억제를 물으면 「억제 없음」이 공허하게 "
              "나온다. 번들을 조립하지 않는다.", file=sys.stderr)
        return 2
    for heading in UNTRUSTED_VERBATIM_SECTIONS:
        body = section_body(audit_text, heading)
        if body is None:
            print(f"[spec-distill] 경고: {paths['audit_file']} 에 `{heading}` 절이 없다 — 「(없음)」으로 조립한다",
                  file=sys.stderr)
            continue
        if heading == sec_questions and not body.strip():
            print(f"[spec-distill] 경고: {paths['audit_file']} 의 `{heading}` 절이 비었다 — 확인 질문 기록 없이 "
                  "조립한다", file=sys.stderr)
        lns = heading_shaped_warnings(audit_text, heading, body)
        if lns:
            print(f"[spec-distill] 경고: {paths['audit_file']} 의 `{heading}` 절 안에 heading-모양 "
                  f"줄이 있다(줄 {', '.join(str(n) for n in lns)}) — 리뷰어가 번들에서 이 줄을 "
                  "헤딩으로 볼 수 있다(비신뢰 본문이라 지우지 않는다).", file=sys.stderr)

    if section_body(audit_text, CUT_TABLE_SECTION) is None:
        print(f"[spec-distill] 경고: {paths['audit_file']} 에 `{CUT_TABLE_SECTION}` 절이 없다 — 「(없음)」으로 조립한다",
              file=sys.stderr)

    try:
        blob = assemble(seed_text, audit_text, claude_md_text, args.consumer)
    except AuditAmbiguous as e:  # `## 6` 제목이 비신뢰 원문 안에 심긴 경우 — 사용자 결정 문구를 뽑지 않는다
        print(f"[spec-distill] {paths['audit_file']} 의 절 경계를 하나로 정할 수 없다({e}). 번들을 조립하지 않는다.",
              file=sys.stderr)
        return 2
    sys.stdout.write(blob)
    return 0


if __name__ == "__main__":
    sys.exit(main())
