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
PARSE_LIB = SCRIPT_DIR.parent / "scripts" / "parse_spec_structure.py"
BLACKLIST = SCRIPT_DIR.parent / "scripts" / "ambiguity-blacklist.txt"

# Path-suffix patterns. spec\d* allows numbered variants used in tests
# (spec.md, spec2.md, ...). design suffix matches *design.md.
SPEC_SUFFIX_RE = re.compile(r"spec\d*\.md$", re.IGNORECASE)
DESIGN_SUFFIX_RE = re.compile(r"design\.md$", re.IGNORECASE)


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
    """Return 'spec', 'design', or None (not in scope).

    Design takes precedence over spec when both match (e.g. `spec-design.md`
    is design mode).
    """
    if DESIGN_SUFFIX_RE.search(file_path):
        if os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1":
            return None
        return "design"
    if SPEC_SUFFIX_RE.search(file_path):
        return "spec"
    return None


def call_parser(sub: str, *args: str) -> dict:
    cp = subprocess.run(
        ["python3", str(PARSE_LIB), sub, *args],
        capture_output=True, text=True, check=False,
    )
    if cp.returncode != 0:
        return {"_error": cp.stderr.strip() or f"parser rc={cp.returncode}"}
    try:
        return json.loads(cp.stdout)
    except json.JSONDecodeError as e:
        return {"_error": f"parser bad json: {e}"}


def write_state(session_id: str, path: str, mode: str) -> None:
    state_dir = Path(".claude/spec-distill") / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    block = (
        "pending_review:\n"
        f"  path: {path}\n"
        f"  mode: {mode}\n"
        f"  triggered_at: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}\n"
    )
    if state_file.exists():
        body = state_file.read_text(encoding="utf-8")
        # Remove existing pending_review: block (deterministic re-write)
        body = re.sub(r"^pending_review:\n(?:  .*\n)*", "", body, flags=re.MULTILINE)
        state_file.write_text(body.rstrip() + "\n" + block, encoding="utf-8")
    else:
        state_file.write_text(
            f"---\nsession_id: {session_id}\n---\n\n{block}", encoding="utf-8"
        )


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
        session_id = os.environ.get("DEVBREW_SPEC_DISTILL_SESSION_ID", "default")
        write_state(session_id, file_path, mode)

    # Advisory systemMessage
    print(
        json.dumps({
            "systemMessage": (
                f"[spec-distill] {mode} structural OK. "
                "Reviewer will be dispatched at turn end."
            )
        }),
        flush=True,
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
