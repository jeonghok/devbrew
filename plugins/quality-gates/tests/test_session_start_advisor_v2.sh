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

# ============== V8 split (Medium): per-session vs flat-legacy fixtures ==============
# V8a: per-session fixture ONLY (.claude/quality-gates/<sid>/pipeline.md).
# V8b: flat-legacy fixture ONLY (.claude/quality-gates.local.md).
# Each runs independently so a regression in either branch is identifiable.

NO_SIG_KEY="consecutive_no""_signal"

run_advisor() {
  local fixture_root="$1"
  local stderr_log="$2"
  local stdout_log="$3"
  local sid="${4:-$(uuidgen 2>/dev/null || echo test-session-newsid)}"
  echo "{\"session_id\":\"$sid\",\"cwd\":\"$fixture_root\"}" \
    | python3 "$ADVISOR" >"$stdout_log" 2>"$stderr_log"
}

# ---------------- V8a: per-session fixture only ----------------
echo "--- V8a: per-session legacy fixture ---"
V8A_TMP="$(mktemp -d)"
trap 'rm -rf "$V8A_TMP"' EXIT
SID_A="legacy-test-sid-deadbeef"
mkdir -p "$V8A_TMP/.claude/quality-gates/$SID_A"
sed "s/__NO_SIG__/${NO_SIG_KEY}/" > "$V8A_TMP/.claude/quality-gates/$SID_A/pipeline.md" <<'INNER'
---
session_id: legacy-test-sid-deadbeef
current_gate: 2
__NO_SIG__: 2
gate2_iteration: 3
max_gate2_iterations: 5
status: gate2_running
---
INNER

STDERR_LOG_A="$V8A_TMP/stderr.log"
STDOUT_LOG_A="$V8A_TMP/stdout.log"
run_advisor "$V8A_TMP" "$STDERR_LOG_A" "$STDOUT_LOG_A" "$SID_A"

if ! grep -q '/cancel-qg' "$STDERR_LOG_A" 2>/dev/null && ! grep -q '/cancel-qg' "$STDOUT_LOG_A" 2>/dev/null; then
  echo "FAIL V8a: per-session legacy advisory missing /cancel-qg directive"
  echo "--- stderr ---"; cat "$STDERR_LOG_A"
  exit 1
fi
echo "PASS: V8a"

# ---------------- V8b: flat-legacy fixture only ----------------
echo "--- V8b: flat-legacy fixture (no per-session state) ---"
V8B_TMP="$(mktemp -d)"
trap 'rm -rf "$V8A_TMP" "$V8B_TMP"' EXIT
touch "$V8B_TMP/.claude/quality-gates.local.md" 2>/dev/null \
  || { mkdir -p "$V8B_TMP/.claude" && touch "$V8B_TMP/.claude/quality-gates.local.md"; }

STDERR_LOG_B="$V8B_TMP/stderr.log"
STDOUT_LOG_B="$V8B_TMP/stdout.log"
# Note: empty per-session state for the flat case (no SID_B dir created).
run_advisor "$V8B_TMP" "$STDERR_LOG_B" "$STDOUT_LOG_B"

if ! grep -q '/qg --reset\|/cancel-qg' "$STDERR_LOG_B" 2>/dev/null \
   && ! grep -q '/qg --reset\|/cancel-qg' "$STDOUT_LOG_B" 2>/dev/null; then
  echo "FAIL V8b: flat-legacy advisory missing /qg --reset or /cancel-qg directive"
  echo "--- stderr ---"; cat "$STDERR_LOG_B"
  exit 1
fi
echo "PASS: V8b"

echo "All tests pass."
