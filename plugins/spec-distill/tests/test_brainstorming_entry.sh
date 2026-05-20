#!/usr/bin/env bash
# AC9 — brainstorming entry (no /interview): hook fires + cleanup works.
# strict sequential: (i) → (ii) → (iii).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WRITE="$PLUGIN_DIR/hooks/spec-write-validator.py"
END="$PLUGIN_DIR/hooks/session-end-cleanup.py"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q
mkdir -p docs/superpowers/specs

SID="brainstorm-12345678"
SPEC="$WORK/docs/superpowers/specs/2026-05-19-test-design.md"
echo "design body" > "$SPEC"

# (i) Setup — PostToolUse hook writes state.local.md
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"%s"}' "$SPEC" "$SID" \
    | env -u DEVBREW_SPEC_DISTILL_SESSION_ID -u CLAUDE_CODE_SESSION_ID python3 "$WRITE" >/dev/null 2>&1

STATE="$WORK/.claude/spec-distill/$SID/state.local.md"
[[ -f "$STATE" ]] || { echo "[FAIL] case i: state not created"; exit 1; }
grep -q "session_id: $SID" "$STATE" \
    && echo "[PASS] case i: state.local.md created with session_id=$SID" \
    || { echo "[FAIL] case i: session_id frontmatter wrong"; exit 1; }

# (ii) Assertion — no "default" literal anywhere in state
! grep -q 'default' "$STATE" \
    && echo "[PASS] case ii: 'default' literal absent from state" \
    || { echo "[FAIL] case ii: 'default' literal present"; exit 1; }

# (iii) Cleanup verification — SessionEnd hook removes folder
printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WORK" \
    | python3 "$END" >/dev/null 2>&1

[[ ! -d "$WORK/.claude/spec-distill/$SID" ]] \
    && echo "[PASS] case iii: SessionEnd cleanup removed folder" \
    || { echo "[FAIL] case iii: folder still exists"; exit 1; }

echo "PASSED: 3 cases sequential"
