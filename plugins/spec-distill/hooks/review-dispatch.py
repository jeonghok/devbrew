#!/usr/bin/env python3
"""spec-distill Stop hook — review dispatch enforcer (v0.5.0).

Reads state.local.md for the current session. If `pending_review:` block
is present AND last_dispatched_at is empty or older than the redispatch TTL,
emits stdout `{"decision":"block","reason":"...","systemMessage":"..."}` —
the `decision:"block"` forces Claude Code to continue immediately (no user
input wait), and `reason` is shown to Claude as a system message so the next
turn first action becomes the reviewing-spec skill call.

Ordering guarantee (AC7.1): `rewrite_state()` must complete (with fsync) BEFORE
the JSON is printed. Reverse ordering races with a second Stop fire and
produces a block storm. On rewrite OSError, the hook exits `{}` 0 (no block)
to preserve the race-free TTL guard (AC7.2) — the L4b UserPromptSubmit
reminder picks up the missed dispatch on the next user prompt.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:Stop  (or :review-dispatch)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; self-ref cycle guard)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
SCRIPTS_DIR = SCRIPT_DIR.parent / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))
from state_path import state_root as _state_root, resolve_session_id  # noqa: E402

GC_SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "spec-distill-gc.py"


PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>[^\n]+)\n  mode:\s*(?P<mode>[^\n]+)\n"
    r"(?:  worktree_path:\s*(?P<wt>[^\n]+)\n)?"
    r"  triggered_at:\s*(?P<triggered>[^\n]+)\n",
    re.MULTILINE,
)
LAST_DISPATCHED_RE = re.compile(r"^last_dispatched_at:\s*(.+)$", re.MULTILINE)


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    skip_tokens = {p.strip() for p in skip.split(",") if p.strip()}
    for token in ("spec-distill:Stop", "spec-distill:review-dispatch"):
        if token in skip_tokens:
            return True
    return False


def state_file_for(session_id: str) -> Path:
    return _state_root() / session_id / "state.local.md"


def parse_iso(s: str) -> Optional[datetime]:
    s = s.strip()
    if not s or s.lower() == "null":
        return None
    try:
        return datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except ValueError:
        return None


def rewrite_state(path: Path, body: str, now: datetime) -> None:
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    # AC7.1: explicit flush + fsync for OS-level durability before any emit.
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        result = subprocess.run(
            ["python3", str(GC_SCRIPT)],
            timeout=5, check=False, capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(
                f"[spec-distill] GC exited rc={result.returncode}: {result.stderr.strip()}",
                file=sys.stderr,
            )
    except (subprocess.TimeoutExpired, OSError) as exc:
        print(
            f"[spec-distill] gc fire-and-forget failed (non-fatal): {exc}",
            file=sys.stderr,
        )
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        payload = {}
    except OSError as exc:
        print(f"[spec-distill] stdin read error: {exc}", file=sys.stderr)
        payload = {}
    session_id = resolve_session_id(payload)
    if session_id is None:
        return 0
    state_path = state_file_for(session_id)
    if not state_path.exists():
        return 0
    try:
        body = state_path.read_text(encoding="utf-8")
    except OSError as e:
        print(f"[spec-distill] state read failed (non-fatal): {e}", file=sys.stderr)
        return 0
    m = PENDING_RE.search(body)
    if not m:
        return 0  # no pending dispatch
    # A2 (v0.15.0): honor suppressed_paths — approve/cancel된 문서는 절대 재dispatch
    # 안 함(Law 2 트리거/억제 대칭 복원 — Stop이 이제 두 신호를 모두 읽음). suppressed면
    # stale pending을 strip하되 last_dispatched_at은 건드리지 않는다 — suppress는
    # dispatch가 아니므로 TTL 시계를 시작하면 안 됨(cancel-review --reset 직후 정당한
    # pending이 TTL window 동안 막히는 재발 window 방지). fail-safe 방향은 "리뷰가
    # 일어나는 쪽": 이 블록의 어떤 예외(suppress_state import 실패 포함)도 정상
    # dispatch로 귀결(과리뷰가 under-review보다 안전 — Law 1).
    try:
        import suppress_state  # scripts/ deferred import, fails-open (AC4)  # pyright: ignore[reportMissingImports]
        if suppress_state.is_suppressed(state_path, m.group("path").strip()):
            stripped = suppress_state.strip_pending(body).rstrip() + "\n"
            with open(state_path, "w", encoding="utf-8") as f:
                f.write(stripped)
                f.flush()
                os.fsync(f.fileno())
            return 0  # suppressed → no dispatch, no emit, last_dispatched_at 불변
    except Exception as exc:  # noqa: BLE001 — fail-open to dispatch (Law 1, NEW-001)
        print(
            f"[spec-distill] suppress check failed (non-fatal, dispatching): {exc}",
            file=sys.stderr,
        )
    # Document-keyed review lock (v0.18.0): 이 문서의 리뷰가 in-flight(신선 엔트리)면
    # 재-arm된 pending은 subagent 경계 Stop 오발 — no-op하고 pending을 보존한다.
    # fail-safe = 강제: 엔트리 부재/stale/파싱·import 예외 중 하나라도면 정상 dispatch로
    # 진행(Law 1, over-review > under-review). 다른 문서의 신선 엔트리는 pending_key로
    # 조회하므로 이 문서를 억제하지 않는다(AC16).
    try:
        import review_lock  # scripts/ deferred import, fails-open (AC4)  # pyright: ignore[reportMissingImports]
        try:
            lock_ttl = int(os.environ.get("DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC", "1800"))
        except ValueError:
            lock_ttl = 1800
        pending_key = review_lock.canonical_key(m.group("path").strip())
        if pending_key is not None and review_lock.is_review_active(
            body, pending_key, datetime.now(timezone.utc), lock_ttl
        ):
            return 0  # review in progress for this doc → no dispatch, pending preserved
    except Exception as exc:  # noqa: BLE001 — fail-open to dispatch (Law 1)
        print(
            f"[spec-distill] review-lock check failed (non-fatal, dispatching): {exc}",
            file=sys.stderr,
        )
    # TTL guard against self-ref cycle
    try:
        ttl_sec = int(os.environ.get("DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC", "30"))
    except ValueError:
        ttl_sec = 30
    now = datetime.now(timezone.utc)
    ld = LAST_DISPATCHED_RE.search(body)
    if ld:
        last = parse_iso(ld.group(1))
        if last and (now - last) < timedelta(seconds=ttl_sec):
            return 0  # within guard window
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    wt = (m.group("wt") or "").strip()
    msg_lines = [
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        msg_lines.append(f"worktree_path: {wt}.")
    msg_lines.append(
        "호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류."
    )
    msg = " ".join(msg_lines)
    # AC7.1: rewrite BEFORE emit. AC7.2: rewrite-fail → no emit (block storm guard).
    try:
        rewrite_state(state_path, body, now)
    except OSError as e:
        print(
            f"[spec-distill] state rewrite failed (non-fatal, dispatch suppressed): {e}",
            file=sys.stderr,
        )
        return 0  # empty stdout, no decision:block — L4b reminder picks up on next prompt
    print(json.dumps({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn",
    }), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
