#!/usr/bin/env python3
"""원자료 테스트 도우미 — framing 기록 · seed · 결과물 셋을 둔 임시 git 레포를 짓는다.

    make_repo(tmp, *, raw1=RAW1, raw2=RAW2, decisions=DECISIONS, mode="recorded", s1_line=...) -> dict
    raw_source_fixture.py make <폴더> [--mode M]      # 경로를 `키=값` 한 줄씩 낸다(셸 테스트용)

mode: recorded(상태 파일 `seed:` 에 seed 경로) · no-framing(`seed: 없음`) · pasted(`seed: 없음` + `## 풀린 입력` 에 seed 전문)
· lost(recorded 인데 기록 파일을 지운다). 돌려주는 키: repo · brief · audit · state · seed · framing(절대경로).
"""
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from pathlib import Path

FIXTURES = Path(__file__).resolve().parent / "fixtures"
SRC = "brief-closing-saturation"
IV = "docs/iv"
SEED_REL = IV + "/t-seed-interview.md"
FRAMING_REL = IV + "/t-seed-interview.audit.md"
BRIEF_REL = IV + "/t-brief-interview.md"
MODES = ("recorded", "no-framing", "pasted", "lost")

RAW1 = "\n".join([
    "### 받은 글 — 직접 친 글 · 사용자 · 2026-11-18",
    "원문절표지 — 리뷰어가 줄인 글이 아니라 내가 쓴 말을 읽게 해 달라.",
    "",
    "## 배경",
    "",
    "지난주에 이렇게 돌려 봤다:",
    "",
    "```sh",
    "make check TARGET=all",
    "```",
    "",
    "끝.",
])

RAW2 = "\n".join([
    "### 라운드 1",
    "",
    "- 물은 것: 어느 쪽부터 고칠까요?",
    "  - 선택지: 읽는 쪽 / 쓰는 쪽",
    "  - 당신이 답한 것 (라벨): 읽는 쪽",
    "- 확인 질문: 라운드 1 의 풀이",
    "  - 내가 읽은 것: 「읽는 쪽부터 고친다」 — 고름",
])

DECISIONS = "\n".join([
    '- D1.1 · r1 · accept · F1 · "그 문장은 빼 주세요" — 덜어 낼 문장',
    '- 답 · r1 · F2 · "범위는 이대로" — 막지 않는 질문의 답',
])

SEED_TEXT = "\n".join([
    "---",
    "type: interview-seed",
    "audit_file: t-seed-interview.audit.md",
    "---",
    "",
    "# 테스트 seed",
    "",
    "seed전문표지 — 모델이 줄인 요청 한 문단.",
    "",
])


def audit_text(raw1: str = RAW1, raw2: str = RAW2, decisions: "str | None" = DECISIONS) -> str:
    """framing 기록 글 — 일곱 제목. `decisions` 가 None 이면 `## 6. 리뷰 결정` 절을 두지 않는다(옛 기록)."""
    parts = [
        "---\ntype: interview-seed-audit\npayload: t-seed-interview.md\ncreated_at: 2026-11-18\n---\n",
        "# 테스트 — Interview Seed Audit\n",
        "## 1. 원문\n\n" + raw1 + "\n",
        "## 2. 질문 전체\n\n" + raw2 + "\n",
        "## 3. 긴 초안\n\n긴 초안 한 줄.\n",
        "## seed 에서 덜어 낸 것\n\n없음\n",
        "## 4. 비평과 냉독\n",
        "## 5. degrade\n\n없음\n",
    ]
    if decisions is not None:
        parts.append("## 6. 리뷰 결정\n\n" + decisions + ("\n" if decisions else ""))
    return "\n".join(parts)


def _sub(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise AssertionError("픽스처의 글이 바뀌었다 — %r 가 %d번" % (old, text.count(old)))
    return text.replace(old, new)


def _read(name: str) -> str:
    return (FIXTURES / name).read_text(encoding="utf-8")


def _put(root: Path, rel: str, text: str) -> Path:
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(text, encoding="utf-8")
    return p


S1_OLD = '- **S1** 🗣 최초 요청:\n  > "대시보드가 너무 느려요."\n'


def _git(repo: Path, *args: str) -> None:
    subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.invalid", "-c", "commit.gpgsign=false",
                    "-c", "core.hooksPath=/dev/null"] + list(args),
                   cwd=str(repo), check=True, capture_output=True)


def make_repo(tmp, *, raw1: str = RAW1, raw2: str = RAW2, decisions: str = DECISIONS, mode: str = "recorded",
              s1_line: str = "- **S1** 🗣 최초 요청:") -> dict:
    if mode not in MODES:
        raise ValueError("mode 는 %s 가운데 하나다 — %s" % (" · ".join(MODES), mode))
    repo = Path(os.path.realpath(str(tmp)))
    repo.mkdir(parents=True, exist_ok=True)
    _git(repo, "init", "-q")
    seed = _put(repo, SEED_REL, SEED_TEXT)
    framing = _put(repo, FRAMING_REL, audit_text(raw1, raw2, decisions))

    brief_text = _sub(_read(SRC + ".md"), "audit_file: %s.audit.md" % SRC, "audit_file: t-brief-interview.audit.md")
    brief_text = _sub(brief_text, S1_OLD, s1_line + "\n")
    audit = _sub(_read(SRC + ".audit.md"), "payload: %s.md" % SRC, "payload: t-brief-interview.md")
    audit = _sub(audit, S1_OLD, "")
    state = _read(SRC + ".state.md")
    if mode in ("recorded", "lost"):
        state = _sub(state, "\nseed: 없음\n", "\nseed: %s\n" % SEED_REL)
    if mode != "no-framing":
        state = state.rstrip("\n") + "\n\n## 풀린 입력\n\n~~~~\n" + SEED_TEXT.rstrip("\n") + "\n~~~~\n"
    brief = _put(repo, BRIEF_REL, brief_text)
    audit_p = _put(repo, IV + "/t-brief-interview.audit.md", audit)
    state_p = _put(repo, IV + "/t-brief-interview.state.md", state)
    if mode == "lost":
        framing.unlink()
    _git(repo, "add", "docs")
    _git(repo, "commit", "-q", "-m", "fixture")
    return {"repo": str(repo), "brief": str(brief), "audit": str(audit_p), "state": str(state_p),
            "seed": str(seed), "framing": str(framing)}


def main(argv: "list[str] | None" = None) -> int:
    ap = argparse.ArgumentParser(prog="raw_source_fixture.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    mk = sub.add_parser("make")
    mk.add_argument("folder")
    mk.add_argument("--mode", default="recorded", choices=MODES)
    a = ap.parse_args(argv)
    for key, val in make_repo(a.folder, mode=a.mode).items():
        print("%s=%s" % (key, val))
    return 0


if __name__ == "__main__":
    sys.exit(main())
