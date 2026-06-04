#!/usr/bin/env python3
"""spec-distill suppression state — per-doc auto-review muting의 단일 소스 (v0.14.0).

두 리뷰 gap을 하나의 session-scoped `suppressed_paths` 집합으로 닫는다:
  (A) approve 후 같은 design 문서 재편집 → 재arm
  (B) 사용자 중단 요청 후에도 재arm
취소(cancel_review.py) + 완료(approve_handoff.sh)가 같은 집합에 기록하고,
PostToolUse validator가 arm 직전 조회한다.

정규화·pending strip·suppress가 이 파일에만 존재한다(C4/AC17) — bash 호출자와
cancel_review·validator는 raw 경로를 넘기고 정규화를 위임한다.

Python API: canonical_key, pending_path, suppressed_keys, strip_pending,
            state_file_for, is_suppressed, add, remove, suppress_path
CLI (bash 호출자): python3 suppress_state.py {add|remove|is-suppressed} <sid> <raw_path>
  - add: suppress_path (키 add + 같은-키 pending strip). 멱등.
  - remove: 억제 해제. 멱등.
  - is-suppressed: exit 0(suppressed) / 1(아님).

Kill switch (CLI defense-in-depth — API 호출자는 상위에서 이미 검사):
  DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(HOOKS_DIR))
from state_path import state_root, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]

PREFIX = "docs/superpowers/specs/"

PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)
SUPPRESSED_RE = re.compile(r"^suppressed_paths:\n((?:  - [^\n]+\n)*)", re.MULTILINE)


def canonical_key(raw_path: str) -> str | None:
    """경로에서 PREFIX 이후 substring. 스코프 밖이면 None.

    worktree·절대·상대 경로 무관하게 같은 문서가 같은 키로 매핑(C4).
    정규화는 이 함수에만 존재 — 다른 파일은 raw 경로 위임(AC17).
    """
    if not raw_path:
        return None
    idx = raw_path.find(PREFIX)
    if idx < 0:
        return None
    return raw_path[idx:]


def pending_path(body: str) -> str | None:
    """state body의 pending_review.path 값(저장된 그대로). 없으면 None."""
    m = PENDING_RE.search(body)
    if not m:
        return None
    for line in m.group(0).splitlines():
        ls = line.strip()
        if ls.startswith("path:"):
            return ls[len("path:"):].strip()
    return None


def suppressed_keys(body: str) -> list[str]:
    """state body의 suppressed_paths 항목(정규화 키들)."""
    m = SUPPRESSED_RE.search(body)
    if not m:
        return []
    keys: list[str] = []
    for line in m.group(1).splitlines():
        ls = line.strip()
        if ls.startswith("- "):
            keys.append(ls[2:].strip())
    return keys


def strip_pending(body: str) -> str:
    """pending_review 블록 제거. suppressed_paths(0-indent 헤더)는 보존(C3).

    validator의 write_state가 import해 inline re.sub 중복을 제거한다.
    """
    return PENDING_RE.sub("", body)


def _strip_suppressed(body: str) -> str:
    return SUPPRESSED_RE.sub("", body)


def _render_suppressed(keys: list[str]) -> str:
    return "suppressed_paths:\n" + "".join(f"  - {k}\n" for k in keys)


def state_file_for(sid: str) -> Path:
    """sid → state.local.md 경로 단일 해석(호출자 중복 제거).

    state_path.state_root()를 래핑 — 저장소 위치 변경(NG5 redesign) 시
    이 한 곳만 갱신하면 되는 single update point.
    """
    return state_root() / sid / "state.local.md"


def _read_or_init(state_file: Path) -> str:
    if state_file.exists():
        try:
            return state_file.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            print(
                f"[spec-distill] suppress_state: state unreadable, re-init: {exc}",
                file=sys.stderr,
            )
    sid = state_file.parent.name
    return f"---\nsession_id: {sid}\n---\n\n"


def _commit(state_file: Path, body: str, keys: list[str]) -> None:
    body = _strip_suppressed(body).rstrip()
    if keys:
        body = body + "\n\n" + _render_suppressed(keys).rstrip()
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(body + "\n", encoding="utf-8")


def is_suppressed(state_file: Path, raw_path: str) -> bool:
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return False
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return False
    return key in suppressed_keys(body)


def add(state_file: Path, raw_path: str) -> None:
    """정규화 키를 suppressed_paths에 멱등 추가. 파일 부재 시 생성.

    pending_review는 건드리지 않는다(strip은 suppress_path/호출자가 결정).
    """
    key = canonical_key(raw_path)
    if key is None:
        return
    body = _read_or_init(state_file)
    keys = suppressed_keys(body)
    if key not in keys:
        keys.append(key)
    _commit(state_file, body, keys)


def remove(state_file: Path, raw_path: str) -> None:
    """정규화 키를 suppressed_paths에서 멱등 제거(재리뷰 재개)."""
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return
    keys = suppressed_keys(body)
    if key not in keys:
        return
    keys.remove(key)
    _commit(state_file, body, keys)


def suppress_path(state_file: Path, raw_path: str) -> bool:
    """키 add + pending이 *같은 키*일 때만 strip(다른 문서 pending 보존 — AC19).

    CLI `add`(approve_handoff) + cancel_review의 explicit-path/현재-pending이 공유.
    스코프 밖 경로면 False(호출자가 advisory).
    """
    key = canonical_key(raw_path)
    if key is None:
        return False
    add(state_file, raw_path)
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        return True
    pend = pending_path(body)
    if pend is not None and canonical_key(pend) == key:
        state_file.write_text(strip_pending(body).rstrip() + "\n", encoding="utf-8")
    return True


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        print(
            "[spec-distill] suppress_state: DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op",
            file=sys.stderr,
        )
        return 0
    if len(argv) < 4:
        print(
            "usage: suppress_state.py {add|remove|is-suppressed} <sid> <raw_path>",
            file=sys.stderr,
        )
        return 2
    cmd, sid, raw_path = argv[1], argv[2], argv[3]
    if not SESSION_PATTERN.match(sid):
        trunc = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] suppress_state: session_id rejected: '{trunc}'",
            file=sys.stderr,
        )
        return 2
    sf = state_file_for(sid)
    if cmd == "add":
        if not suppress_path(sf, raw_path):
            print(
                f"[spec-distill] suppress_state: '{raw_path}' out of scope "
                f"(no {PREFIX}) — no-op",
                file=sys.stderr,
            )
            return 1
        return 0
    if cmd == "remove":
        if canonical_key(raw_path) is None:
            print(
                f"[spec-distill] suppress_state: '{raw_path}' out of scope — no-op",
                file=sys.stderr,
            )
            return 1
        remove(sf, raw_path)
        return 0
    if cmd == "is-suppressed":
        return 0 if is_suppressed(sf, raw_path) else 1
    print(f"[spec-distill] suppress_state: unknown subcommand '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
