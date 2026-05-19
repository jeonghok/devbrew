#!/usr/bin/env python3
"""spec-distill PostToolUse hook — Layer 1 structural validator.

- Reads PostToolUse JSON payload from stdin.
- Filters: tool must be Write/Edit/MultiEdit on `*spec*.md` (spec mode) or
  `*design.md` (design mode). Out-of-scope paths exit 0 silently.
- spec mode: 11 sections + frontmatter + locked_decisions + ambiguity scan.
- design mode: ambiguity + placeholder scan only.
- On pass: writes `pending_review:` block to .claude/spec-distill/<session>/state.local.md.
- On fail: exit 2 + stderr; stdout `{"decision": "block", "reason": "..."}` for safety.

Kill switches:
- DEVBREW_DISABLE_SPEC_DISTILL=1
- DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse  (or :validator)
- DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1  (Layer 1 only; skip state write)
- DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1  (skip design.md)
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional


SCRIPT_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(SCRIPT_DIR))
from state_path import state_root as _state_root  # noqa: E402
PARSE_LIB = SCRIPT_DIR.parent / "scripts" / "parse_spec_structure.py"
BLACKLIST = SCRIPT_DIR.parent / "scripts" / "ambiguity-blacklist.txt"

PATH_PREFIX = "docs/superpowers/specs/"


def kill_switch_active() -> bool:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        return True
    skip = os.environ.get("DEVBREW_SKIP_HOOKS", "")
    skip_tokens = {p.strip() for p in skip.split(",") if p.strip()}
    for token in ("spec-distill:PostToolUse", "spec-distill:validator"):
        if token in skip_tokens:
            return True
    return False


def resolve_mode(file_path: str) -> Optional[str]:
    """Return 'spec', 'design', or None (not in scope)."""
    if PATH_PREFIX not in file_path:
        return None
    if file_path.endswith("-spec.md"):
        return "spec"
    if file_path.endswith("-design.md"):
        if os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1":
            return None
        return "design"
    return None


def call_parser(sub: str, *args: str) -> dict:
    try:
        cp = subprocess.run(
            ["python3", str(PARSE_LIB), sub, *args],
            capture_output=True, text=True, check=False,
            timeout=10,
        )
    except (FileNotFoundError, OSError, subprocess.TimeoutExpired) as exc:
        return {"_error": f"parser failure: {exc}"}
    if cp.returncode != 0:
        return {"_error": cp.stderr.strip() or f"parser rc={cp.returncode}"}
    try:
        return json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        return {"_error": f"parser bad json: {e}"}


LEGACY_ADVISORY_MARKER = ".legacy-advisory-emitted-v060"


def _legacy_advisory_check(state_root_path: Path) -> None:
    """AC14 — emit one-shot advisory if `.claude/spec-distill/default/` exists."""
    legacy = state_root_path / "default"
    marker = state_root_path / LEGACY_ADVISORY_MARKER
    if not legacy.exists() or marker.exists():
        return
    try:
        state_root_path.mkdir(parents=True, exist_ok=True)
        marker.write_text("")
        print(
            "[spec-distill] v0.6.0 detected: .claude/spec-distill/default/ "
            "legacy folder, manual cleanup recommended (no auto-delete to "
            "preserve in-flight work — see CHANGELOG [0.6.0]).",
            file=sys.stderr,
        )
    except OSError as exc:
        print(
            f"[spec-distill] legacy advisory marker write failed: {exc}",
            file=sys.stderr,
        )


def write_state(session_id: str, path: str, mode: str, worktree_path: str) -> None:
    state_dir = _state_root() / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    _legacy_advisory_check(_state_root())
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  worktree_path: {worktree_path}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    if not state_file.exists():
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return
    # File exists — detect stale session_id (AC8 defensive truncate)
    try:
        body = state_file.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError) as exc:
        print(
            f"[spec-distill] state.local.md unreadable — preserving for debug: {exc}",
            file=sys.stderr,
        )
        return
    fm_match = re.search(r"^session_id:\s*([^\n]+)$", body, flags=re.MULTILINE)
    if fm_match and fm_match.group(1).strip() != session_id:
        old = fm_match.group(1).strip()
        print(
            f"[spec-distill] stale state detected (old sid={old[:32]}, "
            f"current={session_id[:32]}) — truncating",
            file=sys.stderr,
        )
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )
        return
    # Matching session_id (or no frontmatter — backward compat per AC8 case iii)
    # — strip pending_review block and append fresh
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    state_file.write_text(body.rstrip() + "\n\n" + block, encoding="utf-8")


def emit_block(reasons: list[str]) -> None:
    print(
        json.dumps({"decision": "block", "reason": "\n".join(reasons)}),
        flush=True,
    )
    for r in reasons:
        print(f"[spec-distill] {r}", file=sys.stderr)


def main() -> int:
    if kill_switch_active():
        return 0
    try:
        payload = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # graceful degradation; not our payload
    tool_name = payload.get("tool_name", "")
    if tool_name not in ("Write", "Edit", "MultiEdit"):
        return 0
    file_path = payload.get("tool_input", {}).get("file_path", "")
    mode = resolve_mode(file_path)
    if mode is None:
        return 0  # out of scope

    # Layer 1 mechanical checks
    reasons: list[str] = []
    if mode == "spec":
        fm = call_parser("frontmatter", file_path)
        if not fm or "name" not in fm:
            reasons.append("spec mode: missing or invalid frontmatter")
        ld = call_parser("locked-decisions", file_path)
        if ld.get("errors"):
            reasons.append("locked_decisions errors: " + "; ".join(ld["errors"]))
        secs = call_parser("sections", file_path)
        missing = secs.get("missing", [])
        if missing:
            reasons.append(f"missing sections: {missing}")

    amb = call_parser("ambiguity", file_path, str(BLACKLIST))
    for hit in amb.get("hits", []):
        reasons.append(
            f"ambiguity hit: line {hit['line']} \"{hit['phrase']}\""
        )

    if mode == "design":
        ph = call_parser("placeholders", file_path)
        for hit in ph.get("hits", []):
            reasons.append(
                f"placeholder hit: {hit['token']} at line {hit['line']}"
            )

    if reasons:
        emit_block(reasons)
        return 2

    # Pass → write state (unless Layer 2 disabled)
    if os.environ.get("DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW") != "1":
        from state_path import resolve_session_id
        session_id = resolve_session_id(payload)
        if session_id is not None:
            try:
                write_state(session_id, file_path, mode, os.getcwd())
            except (PermissionError, OSError) as exc:
                print(f"[spec-distill] state write failed (non-fatal): {exc}", file=sys.stderr)

    # Advisory output (v0.5.0 dual-target: additionalContext for Claude + systemMessage trace).
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": (
                    f"[spec-distill] {mode} structural OK. "
                    "Reviewer will be dispatched at turn end "
                    "(Stop hook will mandate reviewing-spec skill invocation)."
                ),
            },
            "systemMessage": f"[spec-distill] {mode} OK · reviewer dispatch pending",
        }),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
