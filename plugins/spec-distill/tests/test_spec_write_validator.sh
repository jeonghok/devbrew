#!/usr/bin/env bash
# AC1-AC10 cases for PostToolUse hook spec-write-validator.py
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/spec-write-validator.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
WORK=$(mktemp -d -t specdistill-validator-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

# Helper: simulate PostToolUse stdin payload, optional env vars
run_hook() {
  local fpath="$1"
  local extra_env="${2:-}"
  local payload
  payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fpath")
  cd "$WORK" && env -i HOME="$HOME" PATH="$PATH" $extra_env bash -c \
    "echo '$payload' | python3 '$HOOK'" 2>&1
}

# Helper: read pending_review block from state.local.md (if any)
state_pending() {
  local f="$WORK/.claude/spec-distill/$1/state.local.md"
  [[ -f "$f" ]] && grep -E '^pending_review:' "$f"
}

# Case 1: AC1 — valid spec → exit 0 + state write
cp "$FIX/spec-valid.md" "$WORK/spec.md"
out=$(run_hook "$WORK/spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-1")
rc=$?
[[ $rc -eq 0 ]] && state_pending "test-1" >/dev/null \
  && note PASS "AC1: valid spec exits 0 + pending_review recorded" \
  || note FAIL "AC1 failed (rc=$rc out=$out)"

# Case 2: AC2 — missing Goals → exit 2 + stderr matches
cp "$FIX/spec-missing-goals.md" "$WORK/spec2.md"
out=$(run_hook "$WORK/spec2.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-2")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:.*#goals" \
  && [[ ! -f "$WORK/.claude/spec-distill/test-2/state.local.md" ]] \
  && note PASS "AC2: missing Goals → exit 2 + matching stderr + no state" \
  || note FAIL "AC2 failed (rc=$rc out=$out)"

# Case 3: AC3 — ambiguity hit on line 12
cp "$FIX/spec-ambiguity-line12.md" "$WORK/spec3.md"
out=$(run_hook "$WORK/spec3.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-3")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q "ambiguity hit:" \
  && echo "$out" | grep -q "line 12" \
  && echo "$out" | grep -q "works correctly" \
  && note PASS "AC3: ambiguity hit at line 12 detected" \
  || note FAIL "AC3 failed (rc=$rc out=$out)"

# Case 4: AC4 — ~escape allowed → exit 0
cp "$FIX/spec-ambiguity-escaped.md" "$WORK/spec4.md"
out=$(run_hook "$WORK/spec4.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-4")
rc=$?
[[ $rc -eq 0 ]] && note PASS "AC4: ~escape prefix passes" \
  || note FAIL "AC4 failed (rc=$rc out=$out)"

# Case 5: AC5 — out-of-scope path → silent exit 0
echo "# unrelated" > "$WORK/README.md"
payload='{"tool_name":"Write","tool_input":{"file_path":"'"$WORK/README.md"'"}}'
out=$(echo "$payload" | python3 "$HOOK" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && note PASS "AC5: out-of-scope path silent exit 0" \
  || note FAIL "AC5 failed (rc=$rc out=$out)"

# Case 6: AC6 — design.md no-frontmatter → exit 0 + mode: design
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-test-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-6")
rc=$?
[[ $rc -eq 0 ]] && grep -q 'mode: design' "$WORK/.claude/spec-distill/test-6/state.local.md" \
  && note PASS "AC6: design.md no-frontmatter exits 0 + mode: design" \
  || note FAIL "AC6 failed (rc=$rc out=$out)"

# Case 7: AC7 — design.md with TBD → exit 2 + placeholder hit
cp "$FIX/design-tbd.md" "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-7")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q 'placeholder hit:' \
  && echo "$out" | grep -q 'TBD' \
  && note PASS "AC7: design.md TBD detected" \
  || note FAIL "AC7 failed (rc=$rc out=$out)"

# Case 8: AC8 — DEVBREW_DISABLE_SPEC_DISTILL=1 silent
cp "$FIX/spec-valid.md" "$WORK/spec8.md"
out=$(run_hook "$WORK/spec8.md" "DEVBREW_DISABLE_SPEC_DISTILL=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-8")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-8/state.local.md" ]] \
  && note PASS "AC8: DEVBREW_DISABLE_SPEC_DISTILL=1 silent" \
  || note FAIL "AC8 failed (rc=$rc out=$out)"

# Case 9: AC9 — DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1: Layer 1 runs, no state write
cp "$FIX/spec-valid.md" "$WORK/spec9.md"
out=$(run_hook "$WORK/spec9.md" "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-9")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-9/state.local.md" ]] \
  && note PASS "AC9: SKIP_AUTOREVIEW skips Layer 2" \
  || note FAIL "AC9 failed (rc=$rc out=$out)"

# Case 10: AC10 — DESIGN_MODE_DISABLE skips design.md
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md" "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-10")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-10/state.local.md" ]] \
  && note PASS "AC10: DESIGN_MODE_DISABLE skips design.md silently" \
  || note FAIL "AC10 failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
