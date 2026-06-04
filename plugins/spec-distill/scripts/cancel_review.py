#!/usr/bin/env python3
"""spec-distill /spec-distill:cancel-review — 사용자 주권(P17) 취소·억제 경로 (v0.14.0).

현재(또는 지정) design 문서의 pending_review를 취소하고 그 문서를 세션 동안
재arm에서 억제한다. --reset으로 재활성화. 정규화·strip·suppress는 모두
suppress_state(단일 소스)에 위임 — 이 파일은 인자 해석 + 정책만.

Usage (commands/cancel-review.md가 호출):
  python3 cancel_review.py                # 현재 pending 취소 + 억제
  python3 cancel_review.py <path>         # <path> 억제 (pending이 같은 문서면 함께 취소)
  python3 cancel_review.py --reset <path> # 억제 해제

Kill switch: DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op (AC6).
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(SCRIPT_DIR))
sys.path.insert(0, str(HOOKS_DIR))
import suppress_state  # noqa: E402 # pyright: ignore[reportMissingImports]
from state_path import resolve_session_id  # noqa: E402 # pyright: ignore[reportMissingImports]


def _advise(msg: str) -> None:
    print(f"[spec-distill] cancel-review: {msg}", file=sys.stderr)


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        _advise("DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op (state 보존)")
        return 0

    args = [a for a in argv[1:] if a and a.strip()]
    reset = bool(args) and args[0] == "--reset"
    if reset:
        if len(args) < 2:
            _advise("--reset 는 <path> 인자가 필요합니다.")
            return 2
        target = args[1]          # 항상 str (위 가드가 부재를 차단)
    elif args:
        target = args[0]
    else:
        target = ""               # 인자 없음 sentinel (args 필터가 빈 문자열 제거)

    sid = resolve_session_id()
    if sid is None:
        # resolve_session_id가 이미 loud stderr. 상태 변경 없음(AC7).
        return 1
    sf = suppress_state.state_file_for(sid)

    if reset:
        key = suppress_state.canonical_key(target)
        if key is None:
            _advise(f"'{target}' 스코프 밖({suppress_state.PREFIX} 없음) — no-op (AC8)")
            return 1
        suppress_state.remove(sf, target)
        _advise(f"re-enabled: {key} (suppressed_paths에서 제거, 재리뷰 재개).")
        return 0

    if target:
        key = suppress_state.canonical_key(target)
        if key is None:
            _advise(f"'{target}' 스코프 밖({suppress_state.PREFIX} 없음) — no-op (AC8)")
            return 1
        suppress_state.suppress_path(sf, target)  # 같은-키 pending만 strip(AC19)
        _advise(f"suppressed {key} this session. 재리뷰: --reset {key}")
        return 0

    # 인자 없음 → 현재 pending 취소
    body = ""
    if sf.exists():
        try:
            body = sf.read_text(encoding="utf-8")
        except (OSError, UnicodeDecodeError) as exc:
            _advise(f"state 읽기 실패 — 보존: {exc}")
            return 1
    pend = suppress_state.pending_path(body)
    if pend is None:
        _advise(
            "취소할 pending_review 없음 + <path> 미지정 — nothing to do. "
            "특정 문서 사전 억제는 /spec-distill:cancel-review <path> (AC3)."
        )
        return 0
    suppress_state.suppress_path(sf, pend)
    key = suppress_state.canonical_key(pend) or pend
    _advise(f"cancelled pending review + suppressed {key} this session. 재리뷰: --reset {key}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
