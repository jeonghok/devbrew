"""quality-gates state path helper — 이 플러그인의 state root 해석 정본.

`shared/` 아래가 **아니다.** 이것은 quality-gates **안**의 중복(census #88)을 접는
플러그인-내부 정본이다: `hooks/session-end-cleanup.py` 와 `hooks/session-start-advisor.py`
가 같은 11줄짜리 `_state_root()` 를 각자 갖고 있었고, 다른 것은 경고 메시지 안의 훅 이름
문자열 하나뿐이었다. 차이를 인자로 빼면 하나가 된다.

플러그인 **경계를 넘는** 차이는 여기서 통합하지 않는다 — spec-distill 의 state root 는
git-aware(`git rev-parse --git-common-dir`, worktree 호환)이고 이쪽은 payload cwd 상대다.
그 둘은 서로 다른 계약이라 부분 사본의 "각자 고유 본문"으로 남는다.

배치는 spec-distill 이 쓰는 이름·자리와 같은 모양이다(`state_path.py` 에
`state_root`) — 81c6e97 이 spec-distill 쪽 파일도 `scripts/` 로 옮겨 두 곳이 이미
한 자리다. plan Task 27 이 검증한 것은 이 파일의 위치가 아니라 **반환하는 `.claude/`
경로 모양** — 아래 `state_root()` 는 플러그인 레벨 접두(`.claude/quality-gates`)까지만
반환한다; `<session-id>/<file>`은 각 호출자가 붙인다(예: `hooks/session-end-cleanup.py:36`
의 `root / session_id`) — 그 조립 결과가 이미 목표 모양이다.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path


def state_root(hook_input: dict | None, hook_name: str) -> Path:
    """Resolve state root from hook stdin payload cwd; fall back loudly.

    `hook_name` 은 경고 메시지에 들어간다 — **기본값을 주지 않는다.** 지금 두 경고를
    서로 구별하는 유일한 근거가 이 이름이고, 빼먹으면 경고가 어느 훅에서 났는지가
    사라진다. 인자가 없으면 호출 시점에 `TypeError` 로 죽는 쪽이(조용히 이름 없는
    경고를 내는 것보다) 낫다. 빈 문자열이 오는 경우는 막을 수 없으므로 그때는
    자리표시자를 찍어 무엇이 빠졌는지 읽는 쪽에 알린다.
    """
    if not hook_name:
        hook_name = "<hook-name-missing>"
    cwd = hook_input.get("cwd") if hook_input else None
    if not cwd:
        print("[quality-gates] {0} payload missing 'cwd'; ".format(hook_name)
              + "falling back to process cwd",
              file=sys.stderr)
        cwd = os.getcwd()
    return Path(cwd) / ".claude" / "quality-gates"
