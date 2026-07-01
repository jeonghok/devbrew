#!/usr/bin/env python3
"""spec-distill UserPromptSubmit hook — pending review reminder.

If state.local.md still has a pending_review block AND last_dispatched_at is
older than TTL (default 30s), re-emit the Stop hook's mandate so the next-turn
agent doesn't silently drop the dispatch.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit  (or :reminder)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; shared with Stop hook)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

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
    tokens = {p.strip() for p in skip.split(",") if p.strip()}
    return bool(tokens & {
        "spec-distill:UserPromptSubmit",
        "spec-distill:reminder",
    })


def parse_iso(s: str):
    try:
        return datetime.strptime(s.strip(), "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
    except (ValueError, AttributeError):
        return None


def main() -> int:
    if kill_switch_active():
        return 0
    # Best-effort GC FIRST (matches review-dispatch.py ordering) — fire-and-forget
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
    # Read stdin (UserPromptSubmit payload) for session_id resolution
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
    state_file = _state_root() / session_id / "state.local.md"
    if not state_file.exists():
        return 0
    try:
        body = state_file.read_text(encoding="utf-8")
    except OSError as e:
        print(f"[spec-distill] reminder state read failed (non-fatal): {e}", file=sys.stderr)
        return 0
    m = PENDING_RE.search(body)
    if not m:
        return 0
    # Document-keyed review lock (v0.18.0) — Stop 훅과 동일 게이트(AC5): 이 문서의
    # 리뷰가 in-flight(신선 엔트리)면 재-nag하지 않는다. fail-safe = 강제(어떤 예외도
    # 정상 재-emit으로 fall-through).
    try:
        import review_lock  # pyright: ignore[reportMissingImports]
        try:
            lock_ttl = int(os.environ.get("DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC", "1800"))
        except ValueError:
            lock_ttl = 1800
        pending_key = review_lock.canonical_key(m.group("path").strip())
        if pending_key is not None and review_lock.is_review_active(
            body, pending_key, datetime.now(timezone.utc), lock_ttl
        ):
            return 0
    except Exception as exc:  # noqa: BLE001 — fail-open to re-emit (Law 1)
        print(
            f"[spec-distill] review-lock check failed (non-fatal, reminding): {exc}",
            file=sys.stderr,
        )
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
