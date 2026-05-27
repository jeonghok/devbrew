#!/usr/bin/env bash
# v1.32.0 session-start-advisor verification.
#   V8 (AC16): legacy v1.x state file triggers `/cancel-qg` advisory on stderr.
#   V8-pre (AC14 advisory): in-flight code paths gone, frontmatter scan kept.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADVISOR="$ROOT/quality-gates/hooks/session-start-advisor.py"

# ============== V8-pre (AC14): static code-structure check ==============
echo "--- V8-pre: AC14 static structure check ---"
if grep -qE 'pipeline_status|current_gate|in_flight_pipeline|ACTIVE_STATUSES' "$ADVISOR"; then
  echo "FAIL: in-flight pipeline detection identifiers still present in advisor"
  grep -nE 'pipeline_status|current_gate|in_flight_pipeline|ACTIVE_STATUSES' "$ADVISOR"
  exit 1
fi
if ! grep -qE 'frontmatter|scan_agent' "$ADVISOR"; then
  echo "FAIL: frontmatter scan function missing from advisor (AC14 KEEP violated)"
  exit 1
fi
echo "PASS: V8-pre"

# ============== V8 (AC16): legacy state file advisory ==============
echo "--- V8: AC16 legacy state advisory ---"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/.claude/quality-gates/legacy-test-sid-deadbeef"
# Legacy v1.x fixture — the removed-key literal is constructed via shell
# concat so the V1 code-only static grep (which scans *.py/*.sh/*.json for
# legacy stop-hook identifiers) does not false-positive on this deliberate
# fixture. Final on-disk content is byte-identical to the v1.x state file
# the advisor is expected to detect.
NO_SIG_KEY="consecutive_no""_signal"
sed "s/__NO_SIG__/${NO_SIG_KEY}/" > "$TMP/.claude/quality-gates/legacy-test-sid-deadbeef/pipeline.md" <<'INNER'
---
session_id: legacy-test-sid-deadbeef
current_gate: 2
__NO_SIG__: 2
gate2_iteration: 3
max_gate2_iterations: 5
status: gate2_running
---
INNER

# Also create a v1.x flat marker (legacy detection fires on either).
touch "$TMP/.claude/quality-gates.local.md"

SESSION_ID="$(uuidgen 2>/dev/null || echo test-session-newsid)"
STDERR_LOG="$TMP/stderr.log"
STDOUT_LOG="$TMP/stdout.log"

echo "{\"session_id\":\"$SESSION_ID\",\"cwd\":\"$TMP\"}" \
  | python3 "$ADVISOR" >"$STDOUT_LOG" 2>"$STDERR_LOG"

# AC16 lock: legacy advisory must mention /cancel-qg.
if ! grep -q '/cancel-qg' "$STDERR_LOG" 2>/dev/null && ! grep -q '/cancel-qg' "$STDOUT_LOG" 2>/dev/null; then
  echo "FAIL: legacy advisory missing /cancel-qg directive"
  echo "--- stderr ---"; cat "$STDERR_LOG"
  echo "--- stdout ---"; cat "$STDOUT_LOG"
  exit 1
fi
if ! grep -qi 'legacy\|v1\.\|v2\.0' "$STDERR_LOG" 2>/dev/null && ! grep -qi 'legacy\|v1\.\|v2\.0' "$STDOUT_LOG" 2>/dev/null; then
  echo "FAIL: legacy advisory missing legacy/version token"
  exit 1
fi
echo "PASS: V8"

echo "All tests pass."
