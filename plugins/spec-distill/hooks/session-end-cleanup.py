#!/usr/bin/env python3
"""SessionEnd hook: 끝나는 세션의 상태 폴더 정리 + TTL-GC 기동.

순서가 계약이다:
  ① kill switch — 켜져 있으면 아무것도 하지 않는다(GC 포함). 어떤 훅도 자기 kill switch
     존중을 거부할 수 없다.
  ② 끝나는 세션의 `.claude/spec-distill/<sid>/` 삭제. 루트는 payload `cwd` 의 git-aware
     state_root(worktree compat — qg 의 cwd-relative 패턴과 다르다, spec §C9). 그 루트가
     심볼릭 링크를 거쳐 제자리 밖으로 풀리면(`state_root_escapes`) 지우지 않고 소리를 낸다.
  ③ `finally` 에서 TTL-GC 한 번. ② 가 payload 문제로 일찍 끝나거나 예외로 죽어도 돈다.
     GC 의 루트는 **프로세스 cwd** 의 state_root 다(GC 스크립트가 스스로 풀고, 같은 판정으로
     거부한다 — 그 stderr 는 `fire_and_forget_gc` 가 옮긴다).
     `fire_and_forget_gc` 는 동기(timeout 5초)라, 훅 timeout 을 넘기면 잃는 것은 맨 뒤의
     GC 뿐이다 — ② 는 이미 끝났고 GC 는 다음 SessionEnd 가 다시 돈다.

Kill switches (CLAUDE.md "kill switch는 보안 컨트롤"):
  DEVBREW_SPEC_DISTILL_DISABLE=1                       - 전부 끈다
  DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd           - 이 훅 전체(② + ③)
  DEVBREW_SKIP_HOOKS=spec-distill:session-end-cleanup  - 같은 훅을 훅명으로 지목
  DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc      - ③ 의 GC 만(GC 스크립트가 스스로 검사)
"""
from __future__ import annotations

import json
import os
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent / "scripts"))
from state_path import state_root, state_root_escapes, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]
from gc_common import safe_rmtree  # noqa: E402 # pyright: ignore[reportMissingImports]
from hook_common import fire_and_forget_gc  # noqa: E402 # pyright: ignore[reportMissingImports]
from kill_switch_active import kill_switch_active  # noqa: E402


def cleanup_ending_session() -> None:
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return
    except OSError as exc:
        print(f"[spec-distill] session-end-cleanup: stdin read error: {exc}", file=sys.stderr)
        return
    # SessionEnd targets the ending session (from payload), NOT the current
    # session (from CLAUDE_CODE_SESSION_ID env). Use payload directly — do not
    # use resolve_session_id which has env precedence.
    session_id = payload.get("session_id", "")
    if not session_id or not SESSION_PATTERN.match(session_id):
        return
    cwd = payload.get("cwd")
    if not cwd:
        print(
            "[spec-distill] session-end-cleanup: payload missing 'cwd', "
            "falling back to process cwd",
            file=sys.stderr,
        )
        cwd = os.getcwd()
    root = state_root(cwd)
    if state_root_escapes(root):
        print(
            f"[spec-distill] 세션 정리 거부 — state root '{root}' 가 심볼릭 링크를 거쳐 "
            f"'{os.path.realpath(root)}' 로 풀린다. 저장소 밖을 지울 수 있어 건너뛴다.",
            file=sys.stderr,
        )
        return
    folder = root / session_id
    # `SESSION_PATTERN` 이 위에서 이미 charset 으로 걸렀지만 삭제는 두 겹으로 막는다 —
    # 그 패턴이 완화되는 편집이 곧바로 root 밖 삭제로 이어지지 않도록.
    safe_rmtree(folder, root)


def main() -> int:
    if kill_switch_active("spec-distill", "session-end-cleanup", "SessionEnd"):
        return 0
    try:
        cleanup_ending_session()
    finally:
        fire_and_forget_gc()
    return 0


if __name__ == "__main__":
    sys.exit(main())
