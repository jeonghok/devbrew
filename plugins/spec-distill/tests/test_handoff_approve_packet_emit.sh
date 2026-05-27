#!/usr/bin/env bash
# AC5 — approve_handoff.sh stdout includes the full Handoff packet (6 sub-assertions).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/approve_handoff.sh"

# Spec file must exist and be committed for v0.10.0 approve_handoff.sh to emit packet
# (LD4: commit responsibility removed from script). Use 12-char hex session_id for charset guard.
TEST_SID="aaaa11112222"
TEST_SPEC="docs/superpowers/specs/2026-05-26-FAKE-design.md"

# Set up an ephemeral git repo so `git add` + `git commit` succeed and Step 2 stdout fires.
# (The script's Step 2 emit runs after Step 1's commit; with set -e a missing path aborts
# before stdout, so we mint a real committable spec file.)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/$(dirname "$TEST_SPEC")"
cd "$WORK"
git init -q
git config user.email test@x.invalid
git config user.name test
echo "# init" > README.md
git add README.md && git commit -q -m init
echo "# fake spec" > "$TEST_SPEC"
# v0.10.0: spec must be committed (clean HEAD) for approve_handoff.sh to emit packet.
# Previously v0.9.0 expected the script itself to commit.
git add "$TEST_SPEC" && git commit -q -m "spec: lock"

# Capture stdout (script exits 0 with idempotent emit; stdout is what we test).
out=$(bash "$SCRIPT" "$TEST_SID" "$TEST_SPEC" 2>/dev/null || true)

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC5(a): divider opening
echo "$out" | grep -qF "===== spec-distill handoff packet =====" \
  && note PASS "AC5(a): opening divider present" \
  || note FAIL "AC5(a) opening divider missing"

# AC5(b): /compact line with preserve directive
echo "$out" | grep -E '^\s*/compact .*'"$TEST_SPEC"'.*Handoff Context.*Acceptance Criteria.*Files to Modify' >/dev/null \
  && note PASS "AC5(b): /compact preserve directive includes section names" \
  || note FAIL "AC5(b) /compact preserve directive incomplete"

# AC5(c): drop directive
echo "$out" | grep -E '/compact .*(drop|버리|기각)' >/dev/null \
  && note PASS "AC5(c): /compact drop directive present" \
  || note FAIL "AC5(c) /compact drop directive missing"

# AC5(d): next-step instruction embed inside /compact line
echo "$out" | grep -E '/compact .*Skill superpowers:writing-plans '"$TEST_SPEC" >/dev/null \
  && note PASS "AC5(d): next-step embed inside /compact" \
  || note FAIL "AC5(d) next-step not embedded in /compact"

# AC5(e): [2] safety net line (separate from /compact)
echo "$out" | grep -E '^\s*Skill superpowers:writing-plans '"$TEST_SPEC"'\s*$' >/dev/null \
  && note PASS "AC5(e): [2] standalone Skill writing-plans line" \
  || note FAIL "AC5(e) [2] standalone safety net line missing"

# AC5(f): closing divider (8+ '=' chars)
echo "$out" | grep -qE '^={8,}\s*$' \
  && note PASS "AC5(f): closing divider present" \
  || note FAIL "AC5(f) closing divider missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
