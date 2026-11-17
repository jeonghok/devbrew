#!/usr/bin/env python3
"""원자료(framing 기록 파일)를 찾고 판결 한 줄을 낸다.

CLI
    raw_source.py locate --seed <seed 경로>
    raw_source.py locate --interview <brief 또는 상태 파일 경로>
둘 중 하나만 준다. 하위 명령 구조라 다른 명령은 하위 명령으로 더한다.

판결 줄 — stdout 마지막 줄이다(다른 줄은 stdout 에 내지 않는다)
    raw-source: FOUND <framing 기록 파일 경로>
    raw-source: NO-FRAMING
    raw-source: LOST <사유>
종료 코드: FOUND · NO-FRAMING 0, LOST 3, 인자 오류 · 상태 파일을 읽지 못함 2(stderr `[raw_source] …`).

찾는 길: seed 이름 끝의 `.md` 를 `.audit.md` 로 바꾼 파일이다. 받은 글자에서 도출하고 링크를 풀지 않으며, seed 머리의
`audit_file:` 은 읽지 않는다. `--interview` 는 상태 파일 `seed:` 값(작업 트리 루트 기준 상대 경로)에서 같은 길로 간다.

옆 생성기(`team_write._framing_from_state`)와 다른 한 갈래: `seed:` 가 `없음` 인데 `## 풀린 입력` 이 seed 인 인터뷰를
옆 생성기는 framing 없는 인터뷰로 읽고 이 모듈은 찾지 못함으로 읽는다 — 그쪽은 옮겨 적을 기록 파일이 없다는 것만 알면
되고, 이쪽은 첫 입력이 모델이 줄인 글이라는 것까지 알아야 한다.
"""
from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import frontmatter_scalars, worktree_root  # noqa: E402

AUDIT_TYPE = "interview-seed-audit"
SEED_TYPE = "interview-seed"
SEED_NONE = "없음"
INPUT_HEADING = "## 풀린 입력"

R_SEED_MISSING = "seed 파일이 없다 — {seed}"
R_SEED_NOT_MD = "seed 파일 이름이 .md 로 끝나지 않아 framing 기록 파일의 자리를 정하지 못한다 — {seed}"
R_AUDIT_MISSING = "seed 옆에 framing 기록 파일이 없다 — {audit}"
R_AUDIT_TYPE = "framing 기록 파일 머리의 type 이 interview-seed-audit 이 아니다 — {audit} (type: {kind})"
R_SEED_UNRECORDED = ("seed 로 시작했는데 상태 파일에 seed 경로가 기록되지 않았다 — 붙여 넣은 seed 이거나 링크 · "
                     "작업 트리 밖 · 이름 꼴이 다른 seed 다")

_FENCE_RE = re.compile(r"~{4,}")


class StateUnreadable(ValueError):
    """상태 파일을 읽지 못했다(인자 오류와 같은 종료 코드 2)."""


@dataclass(frozen=True)
class Verdict:
    kind: str
    audit: "str | None"
    reason: "str | None"


def _found(audit: str) -> Verdict:
    return Verdict("FOUND", audit, None)


def _lost(reason: str) -> Verdict:
    return Verdict("LOST", None, " ".join(reason.split("\n")))


def _chain(seed: str, base: "Path | None") -> Verdict:
    """seed 문자열에서 넷을 잰다. 파일 검사는 base 기준, 보고하는 글자는 seed 그대로다."""
    def at(s: str) -> Path:
        return Path(s) if base is None else base / s

    if not at(seed).is_file():
        return _lost(R_SEED_MISSING.format(seed=seed))
    if not seed.endswith(".md"):
        return _lost(R_SEED_NOT_MD.format(seed=seed))
    audit = seed[:-3] + ".audit.md"
    if not at(audit).is_file():
        return _lost(R_AUDIT_MISSING.format(audit=audit))
    fm = frontmatter_scalars(at(audit))
    kind = "읽지 못함" if fm is None else fm.get("type") or "없음"
    if kind != AUDIT_TYPE:
        return _lost(R_AUDIT_TYPE.format(audit=audit, kind=kind))
    return _found(audit)


def locate_from_seed(seed: str) -> Verdict:
    return _chain(seed, None)


def _solved_input_is_seed(text: str) -> bool:
    """frontmatter 뒤 첫 `## 풀린 입력` 줄 다음 첫 비지 않은 줄이 물결표 펜스이고, 그 안 첫 줄이 `---` 인 머리가 type: interview-seed."""
    lines = text.split("\n")
    i = 0
    if lines and lines[0] == "---":
        i = 1
        while i < len(lines) and lines[i].strip() != "---":
            i += 1
        i += 1
    while i < len(lines) and lines[i] != INPUT_HEADING:
        i += 1
    i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines) or not _FENCE_RE.fullmatch(lines[i].strip()):
        return False
    i += 1
    if i >= len(lines) or lines[i].strip() != "---":
        return False
    for line in lines[i + 1:]:
        if line.strip() == "---":
            break
        if ":" in line and not line.startswith((" ", "\t", "#", "-")):
            key, val = line.split(":", 1)
            if key.strip() == "type":
                return val.strip().strip('"').strip("'") == SEED_TYPE
    return False


def locate_from_interview(path: str) -> Verdict:
    if path.endswith(".audit.md") or not path.endswith(".md"):
        raise ValueError("--interview 는 brief 또는 상태 파일(.md, .audit.md 아님)을 받는다 — %s" % path)
    state = Path(path if path.endswith(".state.md") else path[:-3] + ".state.md")
    if not state.is_file():
        return Verdict("NO-FRAMING", None, None)
    fm = frontmatter_scalars(state)
    if fm is None:
        raise StateUnreadable("상태 파일을 읽지 못했다 — %s" % state)
    seed = fm.get("seed", "")
    if seed and seed != SEED_NONE:
        return _chain(seed, worktree_root(str(state.parent))[0])
    try:
        text = state.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        raise StateUnreadable("상태 파일을 읽지 못했다 — %s" % state)
    if _solved_input_is_seed(text):
        return _lost(R_SEED_UNRECORDED)
    return Verdict("NO-FRAMING", None, None)


def verdict_line(v: Verdict) -> str:
    if v.kind == "FOUND":
        return "raw-source: FOUND %s" % v.audit
    if v.kind == "LOST":
        return "raw-source: LOST %s" % v.reason
    return "raw-source: NO-FRAMING"


def main(argv: "list[str] | None" = None) -> int:
    ap = argparse.ArgumentParser(prog="raw_source.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    loc = sub.add_parser("locate")
    grp = loc.add_mutually_exclusive_group(required=True)
    grp.add_argument("--seed")
    grp.add_argument("--interview")
    try:
        a = ap.parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code not in (0, None) else 0
    try:
        v = locate_from_seed(a.seed) if a.seed is not None else locate_from_interview(a.interview)
    except ValueError as exc:
        print("[raw_source] %s" % exc, file=sys.stderr)
        return 2
    print(verdict_line(v))
    return 3 if v.kind == "LOST" else 0


if __name__ == "__main__":
    sys.exit(main())
