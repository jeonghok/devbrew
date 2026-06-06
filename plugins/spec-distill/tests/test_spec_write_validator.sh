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

# Helper: simulate PostToolUse stdin payload, optional env vars (stderr merged for legacy callers)
run_hook() {
  local fpath="$1"
  local extra_env="${2:-}"
  local payload
  payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fpath")
  cd "$WORK" && env -i HOME="$HOME" PATH="$PATH" $extra_env bash -c \
    "echo '$payload' | python3 '$HOOK'" 2>&1
}

# Helper: same but captures stdout only (for jq advisory-branch assertions)
run_hook_stdout() {
  local fpath="$1"
  local extra_env="${2:-}"
  local payload
  payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$fpath")
  cd "$WORK" && env -i HOME="$HOME" PATH="$PATH" $extra_env bash -c \
    "echo '$payload' | python3 '$HOOK'" 2>/dev/null
}

# Helper: read pending_review block from state.local.md (if any)
state_pending() {
  local f="$WORK/.claude/spec-distill/$1/state.local.md"
  [[ -f "$f" ]] && grep -E '^pending_review:' "$f"
}

# Case 1: AC1 — valid spec → exit 0 + state write + dual-target advisory emit
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-test1-spec.md"
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-test1-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac01")
rc=$?
[[ $rc -eq 0 ]] && state_pending "test-ac01" >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("structural OK")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && note PASS "AC1: valid spec exits 0 + pending_review recorded + dual-target advisory emit" \
  || note FAIL "AC1 failed (rc=$rc out=$out)"

# Case 2: AC2 — missing Goals → exit 2 + stderr matches
cp "$FIX/spec-missing-goals.md" "$WORK/docs/superpowers/specs/2026-05-16-test2-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test2-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac02")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:.*#goals" \
  && [[ ! -f "$WORK/.claude/spec-distill/test-ac02/state.local.md" ]] \
  && note PASS "AC2: missing Goals → exit 2 + matching stderr + no state" \
  || note FAIL "AC2 failed (rc=$rc out=$out)"

# Case 3: AC3 — ambiguity hit on line 12
cp "$FIX/spec-ambiguity-line12.md" "$WORK/docs/superpowers/specs/2026-05-16-test3-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test3-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac03")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q "ambiguity hit:" \
  && echo "$out" | grep -q "line 12" \
  && echo "$out" | grep -q "works correctly" \
  && note PASS "AC3: ambiguity hit at line 12 detected" \
  || note FAIL "AC3 failed (rc=$rc out=$out)"

# Case 4: AC4 — ~escape allowed → exit 0
cp "$FIX/spec-ambiguity-escaped.md" "$WORK/docs/superpowers/specs/2026-05-16-test4-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test4-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac04")
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

# Case 6: AC6 — design.md no-frontmatter → exit 0 + mode: design + design advisory in additionalContext
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-test-design.md"
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-test-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac06")
rc=$?
[[ $rc -eq 0 ]] && grep -q 'mode: design' "$WORK/.claude/spec-distill/test-ac06/state.local.md" \
  && echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("design structural OK")' >/dev/null \
  && note PASS "AC6: design.md no-frontmatter exits 0 + mode: design + design advisory" \
  || note FAIL "AC6 failed (rc=$rc out=$out)"

# Case 7: AC7 — design.md with TBD → exit 2 + placeholder hit
cp "$FIX/design-tbd.md" "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac07")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q 'placeholder hit:' \
  && echo "$out" | grep -q 'TBD' \
  && note PASS "AC7: design.md TBD detected" \
  || note FAIL "AC7 failed (rc=$rc out=$out)"

# Case 8: AC8 — DEVBREW_DISABLE_SPEC_DISTILL=1 silent
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-test8-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test8-spec.md" "DEVBREW_DISABLE_SPEC_DISTILL=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac08")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-ac08/state.local.md" ]] \
  && note PASS "AC8: DEVBREW_DISABLE_SPEC_DISTILL=1 silent" \
  || note FAIL "AC8 failed (rc=$rc out=$out)"

# Case 9: AC9 — DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1: Layer 1 runs, no state write
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-test9-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test9-spec.md" "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac09")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-ac09/state.local.md" ]] \
  && note PASS "AC9: SKIP_AUTOREVIEW skips Layer 2" \
  || note FAIL "AC9 failed (rc=$rc out=$out)"

# Case 10: AC10 — DESIGN_MODE_DISABLE skips design.md
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md" "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac10")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-ac10/state.local.md" ]] \
  && note PASS "AC10: DESIGN_MODE_DISABLE skips design.md silently" \
  || note FAIL "AC10 failed (rc=$rc out=$out)"

# Case 11: I1 regression — write twice, verify exactly one pending_review block
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-idem-spec.md"
run_hook "$WORK/docs/superpowers/specs/2026-05-16-idem-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-idem" > /dev/null
run_hook "$WORK/docs/superpowers/specs/2026-05-16-idem-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-idem" > /dev/null
pending_count=$(grep -c '^pending_review:' "$WORK/.claude/spec-distill/test-idem/state.local.md")
triggered_count=$(grep -c '^  triggered_at:' "$WORK/.claude/spec-distill/test-idem/state.local.md")
[[ "$pending_count" == "1" ]] && [[ "$triggered_count" == "1" ]] \
  && note PASS "I1: state file remains idempotent on re-write" \
  || note FAIL "I1: state file has $pending_count pending_review and $triggered_count triggered_at (expected 1 each)"

# Case 12: AC9/AC18 — suppressed doc → arm skip + suppress advisory가 normal advisory 교체
mkdir -p "$WORK/docs/superpowers/specs" "$WORK/.claude/spec-distill/test-supp"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-supp-spec.md"
cat > "$WORK/.claude/spec-distill/test-supp/state.local.md" <<EOF
---
session_id: test-supp
---

suppressed_paths:
  - docs/superpowers/specs/2026-05-16-supp-spec.md
EOF
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-supp-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-supp")
rc=$?
sf="$WORK/.claude/spec-distill/test-supp/state.local.md"
if [[ $rc -eq 0 ]] \
  && ! grep -qE '^pending_review:' "$sf" \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("suppressed")' >/dev/null \
  && ! echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("Reviewer will be dispatched")' >/dev/null; then
  note PASS "AC9/AC18: suppressed doc → arm skip + suppress advisory (no normal advisory)"
else
  note FAIL "AC9/AC18 failed (rc=$rc out=$out)"
fi

# Case 13: AC10 — suppressed doc도 Layer 1 실행 (구조 실패 → exit 2)
cp "$FIX/spec-missing-goals.md" "$WORK/docs/superpowers/specs/2026-05-16-supp2-spec.md"
mkdir -p "$WORK/.claude/spec-distill/test-supp2"
cat > "$WORK/.claude/spec-distill/test-supp2/state.local.md" <<EOF
---
session_id: test-supp2
---

suppressed_paths:
  - docs/superpowers/specs/2026-05-16-supp2-spec.md
EOF
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-supp2-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-supp2")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:" \
  && note PASS "AC10: suppressed doc still subject to Layer 1 (exit 2)" \
  || note FAIL "AC10 failed (rc=$rc out=$out)"

# Case 14: AC11 — 다른 비-suppressed 문서 write_state가 suppressed_paths 보존
mkdir -p "$WORK/.claude/spec-distill/test-pres"
cat > "$WORK/.claude/spec-distill/test-pres/state.local.md" <<EOF
---
session_id: test-pres
---

suppressed_paths:
  - docs/superpowers/specs/2026-05-16-docA-design.md
EOF
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md"
run_hook "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-pres" >/dev/null
sf="$WORK/.claude/spec-distill/test-pres/state.local.md"
if grep -q "  - docs/superpowers/specs/2026-05-16-docA-design.md" "$sf" \
   && grep -qE '^pending_review:' "$sf"; then
  note PASS "AC11: suppressed_paths preserved across other-doc write_state"
else
  note FAIL "AC11 failed ($(cat "$sf"))"
fi

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
