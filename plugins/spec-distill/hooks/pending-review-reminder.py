#!/usr/bin/env python3
"""spec-distill UserPromptSubmit hook — pending review reminder.

If state.local.md still has a pending_review block AND last_dispatched_at is
older than TTL (default 30s), re-emit the Stop hook's mandate so the next-turn
agent doesn't silently drop the dispatch.

Kill switches:
- DEVBREW_SPEC_DISTILL_DISABLE=1
- DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit  (or :reminder)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; shared with Stop hook)
"""
from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import resolve_session_id  # noqa: E402
from kill_switch_active import kill_switch_active  # noqa: E402
# 형제 훅(review-dispatch.py)과 공유하는 조각 — 같은 플러그인 안이라 import 하나로
# 중복이 소멸한다(설계 §6.1③). 사본이 아니다.
from hook_common import (  # noqa: E402
    LAST_DISPATCHED_RE,
    PENDING_RE,
    configure_utf8_streams,
    fire_and_forget_gc,
    parse_iso,
    state_file_for,
)

# stdin 을 읽기 **전에** 표준 스트림을 UTF-8 로 고정한다. 위 import 들은 stdin 을
# 건드리지 않으므로 이 자리가 여전히 "첫 문장"이다 (근거는 hook_common 쪽 docstring).
configure_utf8_streams()


def main() -> int:
    if kill_switch_active("spec-distill", "reminder", "UserPromptSubmit"):
        return 0
    # Best-effort GC FIRST (matches review-dispatch.py ordering) — fire-and-forget
    fire_and_forget_gc()
    # Read stdin (UserPromptSubmit payload) for session_id resolution
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, UnicodeDecodeError):
        # review-dispatch.py 와 동일 — 형제 소비자 정렬.
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] stdin read error: {exc}", file=sys.stderr)
        payload = {}
    session_id = resolve_session_id(payload)
    if session_id is None:
        return 0
    state_file = state_file_for(session_id)
    if not state_file.exists():
        return 0
    try:
        body = state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as e:
        # review-dispatch.py 와 같은 이유 — UnicodeDecodeError 는 ValueError 하위다.
        # 이 훅은 L4b backstop 이라, 좁게 잡으면 Stop 과 이 훅이 같은 입력에 함께 죽는다.
        # 그리고 같은 이유로 조용히 넘어가서도 안 된다 — backstop 이 primary 와 똑같이
        # 소리 없이 실패하면 이중화의 의미가 없다. additionalContext 로 모델에 알린다.
        print(f"[spec-distill] reminder state read failed (non-fatal): {e}", file=sys.stderr)
        print(json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "UserPromptSubmit",
                "additionalContext": (
                    f"[spec-distill] arm-once:reminder-unreadable — state.local.md 판독 불가로 "
                    f"자동 리뷰 알림이 중단됐다 "
                    f"({state_file}). 파일을 복구하거나 reviewing-spec 을 직접 호출하라."
                ),
            },
        }), flush=True)
        return 0
    m = PENDING_RE.search(body)
    if not m:
        return 0
    try:
        ttl = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    except ValueError:
        ttl = 30
    now = datetime.now(timezone.utc)
    ld = LAST_DISPATCHED_RE.search(body)
    if ld:
        last = parse_iso(ld.group(1))
        if last and (now - last) < timedelta(seconds=ttl):
            return 0
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    wt = (m.group("wt") or "").strip()
    # G1 — review-dispatch 와 같은 게이트. 원장이 완료라고 말하는 문서는 stale pending 이
    # 남아 있어도 nag 하지 않는다. 두 소비자가 pending 만 보고 각자 판단하면 한쪽만 고친
    # 수정이 다른 쪽에 남는다(이 리포가 반복해서 겪은 실패 모드).
    # 여기서는 strip 하지 않는다 — 이 훅은 조언자이지 상태 소유자가 아니다.
    # Stop 훅이 정리를 맡고, 이 훅은 조용해지기만 한다.
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]  # SCRIPTS_DIR already on sys.path
        # 이미 손에 든 `body` 로 판정한다 — `is_armed()` 는 파일을 다시 읽는데,
        # 그 두 번째 read 가 실패하면 False 로 degrade 해 게이트를 통과시키고,
        # 훅은 이어서 **첫 번째 스냅샷**(`body`)으로 rewrite_state 를 돌려
        # 그 사이 바뀐 파일을 옛 내용으로 덮는다(TOCTOU). 순수 함수로 읽으면
        # 창 자체가 없다.
        _key = arm_ledger.canonical_key(spec_path)
        if _key is not None and _key in arm_ledger.armed_keys(body):
            print(
                f"[spec-distill] reminder: '{spec_path}'는 원장에 기록된 문서 — "
                "nag 생략 (arm-once).",
                file=sys.stderr,
            )
            return 0
    except Exception as exc:  # noqa: BLE001 — loud degradation
        print(
            f"[spec-distill] reminder 원장 조회 실패 (non-fatal, nag 계속): {exc}",
            file=sys.stderr,
        )
    parts = [
        "REMINDER (UserPromptSubmit): pending_review still active — reviewing-spec skill 호출 필요.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        parts.append(f"worktree_path: {wt}.")
    parts.append("호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류.")
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": " ".join(parts),
        },
        "systemMessage": "[spec-distill] pending review reminder re-dispatched",
    }), flush=True)
    # Update last_dispatched_at so we don't spam
    new_body = LAST_DISPATCHED_RE.sub(
        f"last_dispatched_at: {now.strftime('%Y-%m-%dT%H:%M:%SZ')}", body,
    )
    if new_body == body:
        new_body = body.rstrip() + f"\nlast_dispatched_at: {now.strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    try:
        state_file.write_text(new_body, encoding="utf-8")
    except OSError as e:
        print(f"[spec-distill] reminder state rewrite failed (non-fatal): {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
