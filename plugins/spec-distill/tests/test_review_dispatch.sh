#!/usr/bin/env bash
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-dispatch-XXXXXX)
# Resolve symlinks (macOS /var → /private/var) so Path.resolve() output matches.
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT

# T-5: exercise the git-aware state_root path (whole point of state_path.py).
# Without git init, state_root() falls back to cwd-relative — which masks the
# primary code path.
( cd "$WORK" && git init -q && git config user.email t@t.t \
  && git config user.name t && git commit -q --allow-empty -m seed )

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
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("MANDATORY")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("/tmp/some-spec.md")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && note PASS "AC11: pending_review triggers decision:block reason+systemMessage with required tokens (incl. terminal handoff)" \
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

# Case 14 (T-1): Stop hook kill switch via DEVBREW_SKIP_HOOKS=spec-distill:Stop
setup_state "test-14" "---
session_id: test-14
---

pending_review:
  path: /tmp/k.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-14 \
  DEVBREW_SKIP_HOOKS="spec-distill:Stop" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-14/state.local.md" \
  && note PASS "AC14 (T-1): kill switch spec-distill:Stop suppresses emit + preserves state" \
  || note FAIL "AC14 failed (rc=$rc out=$out)"

# Case 15 (T-1): kill switch via DEVBREW_SKIP_HOOKS=spec-distill:review-dispatch (alias)
setup_state "test-15" "---
session_id: test-15
---

pending_review:
  path: /tmp/k2.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-15 \
  DEVBREW_SKIP_HOOKS="spec-distill:review-dispatch" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-15/state.local.md" \
  && note PASS "AC15 (T-1): kill switch :review-dispatch alias suppresses emit" \
  || note FAIL "AC15 failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
