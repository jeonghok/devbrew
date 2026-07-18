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

# ============== V9 (AC10, v2.11.0): 스캐너가 죽은 allowedTools 를 경고 ==============
echo "--- V9: AC10 frontmatter 스캐너 ---"
run_scan() {  # run_scan <frontmatter 본문> ; stderr 를 stdout 으로
  local fm="$1" tmp
  tmp="$(mktemp -d)" || return 1
  [ -n "$tmp" ] && [ -d "$tmp" ] || return 1
  mkdir -p "$tmp/plugins/probe/agents"
  printf -- '---\nname: probe\n%s\n---\n\nbody\n' "$fm" > "$tmp/plugins/probe/agents/probe.md"
  printf '{"session_id":"v9","cwd":"%s"}' "$tmp" | python3 "$ADVISOR" 2>&1
  rm -rf "$tmp"
}

out="$(run_scan 'allowedTools:
  - Read')"
if grep -q 'allowedTools' <<<"$out"; then
  echo "PASS: V9a — 죽은 allowedTools 를 경고"
else
  echo "FAIL: V9a — allowedTools 가 경고되지 않음 (조용히 무시되는 필드가 조용히 통과)"; exit 1
fi

out="$(run_scan 'allowed-tools:
  - Read')"
grep -q 'allowed-tools' <<<"$out" \
  && echo "PASS: V9b — kebab allowed-tools 계속 경고" \
  || { echo "FAIL: V9b — kebab 경고가 회귀"; exit 1; }

# 스캐너가 camelCase 를 '올바른 컨벤션'으로 가르치던 문구는 사라져야 한다.
out="$(run_scan 'allowedTools:
  - Read')"
if grep -qE 'camelCase.*올바른|올바른.*camelCase' <<<"$out"; then
  echo "FAIL: V9c — 스캐너가 여전히 camelCase 를 올바른 컨벤션으로 가르친다"; exit 1
fi
echo "PASS: V9c — camelCase 권고 문구 제거됨"

# kill switch 는 보안 컨트롤 — 반드시 살아있어야 한다.
tmp_ks="$(mktemp -d)" || exit 1
[ -n "$tmp_ks" ] && [ -d "$tmp_ks" ] || exit 1
mkdir -p "$tmp_ks/plugins/probe/agents"
printf -- '---\nname: probe\nallowedTools:\n  - Read\n---\n\nbody\n' > "$tmp_ks/plugins/probe/agents/probe.md"
out="$(printf '{"session_id":"v9","cwd":"%s"}' "$tmp_ks" \
       | DEVBREW_SKIP_HOOKS=quality-gates:session-start-advisor:frontmatter-scan python3 "$ADVISOR" 2>&1)"
rm -rf "$tmp_ks"
if grep -q 'allowedTools' <<<"$out"; then
  echo "FAIL: V9d — kill switch 가 스캔을 막지 못했다"; exit 1
fi
echo "PASS: V9d — kill switch 여전히 동작"

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

# ---------------- V8c: LEGACY_V1_KEYS regression (Medium 5.6.5) ----------------
# All three legacy tokens (status:, current_gate:, consecutive_no_signal:)
# must trigger the legacy-v1 advisory. Use fixture-based testing because the
# source-grep evasion (string concat in LEGACY_V1_KEYS) means a source-text
# check would always pass even if behavior regressed. See spec §5.6.5.
echo "--- V8c: LEGACY_V1_KEYS regression ---"
V8C_BASE="$(mktemp -d)"
trap 'rm -rf "$V8A_TMP" "$V8B_TMP" "$V8C_BASE"' EXIT
NO_SIG_KEY="consecutive_no""_signal"
V8C_FAIL=0
for token_label in "status" "current_gate" "${NO_SIG_KEY}"; do
  V8C_TMP="$(mktemp -d -p "$V8C_BASE")"
  SID_C="legacy-regression-${token_label//_/-}-sid"
  mkdir -p "$V8C_TMP/.claude/quality-gates/$SID_C"
  cat > "$V8C_TMP/.claude/quality-gates/$SID_C/pipeline.md" <<EOF
---
session_id: $SID_C
$token_label: some-value
---
EOF
  STDERR_LOG_C="$V8C_TMP/stderr.log"
  STDOUT_LOG_C="$V8C_TMP/stdout.log"
  run_advisor "$V8C_TMP" "$STDERR_LOG_C" "$STDOUT_LOG_C" "$SID_C"
  if grep -q '/cancel-qg\|legacy\|Legacy' "$STDERR_LOG_C" 2>/dev/null; then
    echo "  → PASS LEGACY_V1_KEYS triggers for '$token_label'"
  else
    echo "  ✗ FAIL LEGACY_V1_KEYS missed '$token_label' (stderr: $(cat "$STDERR_LOG_C"))"
    V8C_FAIL=$((V8C_FAIL + 1))
  fi
done
[[ "$V8C_FAIL" -eq 0 ]] && echo "PASS: V8c" || { echo "V8c failed $V8C_FAIL token(s)"; exit 1; }

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

# ============== V8d (source-text): AC17 unsplit-literal absence ==============
# Asserts the two compound legacy keys appear ONLY in their string-concat
# forms inside LEGACY_V1_KEYS, and the unsplit literals do not appear
# anywhere else in the advisor source (including comments, docstrings,
# or other constants). This is the source-text half of AC17 that V8c's
# behavioral check cannot verify. Defends against ruff/black auto-fix
# merging the concat strings back into single literals (which would pass
# V8c silently since runtime behavior is byte-equivalent).
echo "--- V8d: AC17 source-text unsplit-literal absence ---"
# Must contain both split forms exactly once each.
if ! grep -qF '"current" + "_gate:"' "$ADVISOR"; then
  echo "FAIL V8d: split form of current_gate: missing from LEGACY_V1_KEYS"
  exit 1
fi
if ! grep -qF '"consecutive_no" + "_signal:"' "$ADVISOR"; then
  echo "FAIL V8d: split form of consecutive_no_signal: missing from LEGACY_V1_KEYS"
  exit 1
fi
# Must NOT contain the unsplit literals anywhere. grep returns 0 if found,
# 1 if not found. We want NOT found (exit 1).
if grep -qE 'current_gate:|consecutive_no_signal:' "$ADVISOR"; then
  echo "FAIL V8d: unsplit legacy token leaked into advisor source"
  grep -nE 'current_gate:|consecutive_no_signal:' "$ADVISOR"
  exit 1
fi
echo "PASS: V8d"

echo "All tests pass."
