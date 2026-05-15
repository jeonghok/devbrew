#!/usr/bin/env python3
"""spec-distill Stop hook — review dispatch enforcer.

Reads state.local.md for the current session. If `pending_review:` block
is present AND last_dispatched_at is empty or older than the redispatch TTL,
emits stdout `{"systemMessage": "..."}` to mandate next-turn dispatch of
reviewing-spec skill against the recorded spec path.

After emit, rewrites state.local.md: pending_review block removed, `last_dispatched_at`
set to now.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:Stop  (or :review-dispatch)
- DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=<int>  (default 30; self-ref cycle guard)
"""
from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Optional


PENDING_RE = re.compile(
    r"^pending_review:\n  path:\s*(?P<path>[^\n]+)\n  mode:\s*(?P<mode>[^\n]+)\n  triggered_at:\s*(?P<triggered>[^\n]+)\n",
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
    return Path(".claude/spec-distill") / session_id / "state.local.md"


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
    path.write_text(body, encoding="utf-8")


def main() -> int:
    if kill_switch_active():
        return 0
    session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")
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
    msg = (
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출. "
        f"spec path: {spec_path}. mode: {mode}. "
        "다른 작업을 시작하기 전 reviewer agent dispatch."
    )
    print(json.dumps({"systemMessage": msg}), flush=True)
    try:
        rewrite_state(state_path, body, now)
    except OSError as e:
        print(f"[spec-distill] state rewrite failed (non-fatal): {e}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
