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
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root, cleanup_stale_states  # noqa: E402


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
    # Consume stdin (UserPromptSubmit payload), but we don't actually need it
    try:
        sys.stdin.read()
    except Exception:
        pass
    session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")
    state_file = _state_root() / session_id / "state.local.md"
    if not state_file.exists():
        return 0
    try:
        body = state_file.read_text(encoding="utf-8")
    except OSError as e:
        print(f"[spec-distill] reminder state read failed (non-fatal): {e}", file=sys.stderr)
        return 0
    # Best-effort cleanup
    try:
        cleanup_stale_states(_state_root())
    except (OSError, PermissionError):
        pass
    # Re-read after cleanup (block may have been purged)
    try:
        body = state_file.read_text(encoding="utf-8")
    except OSError:
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
    parts = [
        "REMINDER (UserPromptSubmit): pending_review still active — reviewing-spec skill 호출 필요.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        parts.append(f"worktree_path: {wt}.")
    parts.append("호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류.")
    print(json.dumps({"systemMessage": " ".join(parts)}), flush=True)
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
