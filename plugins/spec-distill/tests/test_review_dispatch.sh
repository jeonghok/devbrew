#!/usr/bin/env bash
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-dispatch-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

setup_state() {
  local sid="$1"; shift
  local body="${1:-}"
  mkdir -p "$WORK/.claude/spec-distill/$sid"
  printf '%s' "$body" > "$WORK/.claude/spec-distill/$sid/state.local.md"
}

run_hook() {
  local sid="$1"
  cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null
}

# Case 11: AC11 — pending_review present → systemMessage emit
setup_state "test-11" "---
session_id: test-11
---

pending_review:
  path: /tmp/some-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-11")
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"systemMessage"' \
  && echo "$out" | grep -q 'MANDATORY' \
  && echo "$out" | grep -q '/tmp/some-spec.md' \
  && echo "$out" | grep -q 'reviewing-spec' \
  && note PASS "AC11: pending_review triggers systemMessage with required tokens" \
  || note FAIL "AC11 failed (rc=$rc out=$out)"

# Case 12: AC12 — no pending_review → silent exit 0
setup_state "test-12" "---
session_id: test-12
---
"
out=$(run_hook "test-12")
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && note PASS "AC12: no pending_review silent" \
  || note FAIL "AC12 failed (rc=$rc out=$out)"

# Case 13: AC13 — dispatch removes pending_review + sets last_dispatched_at;
# second call within TTL is silent.
setup_state "test-13" "---
session_id: test-13
---

pending_review:
  path: /tmp/p.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out1=$(run_hook "test-13")
rc1=$?
out2=$(run_hook "test-13")
rc2=$?
[[ $rc1 -eq 0 ]] && [[ $rc2 -eq 0 ]] && [[ -z "$out2" ]] \
  && ! grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-13/state.local.md" \
  && grep -q '^last_dispatched_at:' "$WORK/.claude/spec-distill/test-13/state.local.md" \
  && note PASS "AC13: dispatch consumes block; re-fire within TTL silent" \
  || note FAIL "AC13 failed (rc1=$rc1 rc2=$rc2 out2=$out2)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
