#!/usr/bin/env bash
# AC1-AC10 cases for PostToolUse hook spec-write-validator.py
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/spec-write-validator.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
WORK=$(mktemp -d -t specdistill-validator-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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
  && ok "AC1: valid spec exits 0 + pending_review recorded + dual-target advisory emit" \
  || no "AC1 failed (rc=$rc out=$out)"

# Case 2: AC2 — missing Goals → exit 2 + stderr matches
cp "$FIX/spec-missing-goals.md" "$WORK/docs/superpowers/specs/2026-05-16-test2-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test2-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac02")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:.*#goals" \
  && [[ ! -f "$WORK/.claude/spec-distill/test-ac02/state.local.md" ]] \
  && ok "AC2: missing Goals → exit 2 + matching stderr + no state" \
  || no "AC2 failed (rc=$rc out=$out)"

# Case 3: AC3 — ambiguity hit on line 12
cp "$FIX/spec-ambiguity-line12.md" "$WORK/docs/superpowers/specs/2026-05-16-test3-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test3-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac03")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q "ambiguity hit:" \
  && echo "$out" | grep -q "line 12" \
  && echo "$out" | grep -q "works correctly" \
  && ok "AC3: ambiguity hit at line 12 detected" \
  || no "AC3 failed (rc=$rc out=$out)"

# Case 4: AC4 — ~escape allowed → exit 0
cp "$FIX/spec-ambiguity-escaped.md" "$WORK/docs/superpowers/specs/2026-05-16-test4-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test4-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac04")
rc=$?
[[ $rc -eq 0 ]] && ok "AC4: ~escape prefix passes" \
  || no "AC4 failed (rc=$rc out=$out)"

# Case 5: AC5 — out-of-scope path → silent exit 0
echo "# unrelated" > "$WORK/README.md"
payload='{"tool_name":"Write","tool_input":{"file_path":"'"$WORK/README.md"'"}}'
out=$(echo "$payload" | python3 "$HOOK" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && ok "AC5: out-of-scope path silent exit 0" \
  || no "AC5 failed (rc=$rc out=$out)"

# Case 6: AC6 — design.md no-frontmatter → exit 0 + mode: design + design advisory in additionalContext
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-test-design.md"
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-test-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac06")
rc=$?
[[ $rc -eq 0 ]] && grep -q 'mode: design' "$WORK/.claude/spec-distill/test-ac06/state.local.md" \
  && echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "PostToolUse"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("design structural OK")' >/dev/null \
  && ok "AC6: design.md no-frontmatter exits 0 + mode: design + design advisory" \
  || no "AC6 failed (rc=$rc out=$out)"

# Case 7: AC7 — design.md with TBD → exit 2 + placeholder hit
cp "$FIX/design-tbd.md" "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test-tbd-design.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac07")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -q 'placeholder hit:' \
  && echo "$out" | grep -q 'TBD' \
  && ok "AC7: design.md TBD detected" \
  || no "AC7 failed (rc=$rc out=$out)"

# Case 8: AC8 — DEVBREW_DISABLE_SPEC_DISTILL=1 silent
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-test8-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test8-spec.md" "DEVBREW_DISABLE_SPEC_DISTILL=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac08")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-ac08/state.local.md" ]] \
  && ok "AC8: DEVBREW_DISABLE_SPEC_DISTILL=1 silent" \
  || no "AC8 failed (rc=$rc out=$out)"

# Case 9: AC9 — DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1: Layer 1 runs, no state write
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-test9-spec.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-test9-spec.md" "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac09")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-ac09/state.local.md" ]] \
  && ok "AC9: SKIP_AUTOREVIEW skips Layer 2" \
  || no "AC9 failed (rc=$rc out=$out)"

# Case 10: AC10 — DESIGN_MODE_DISABLE skips design.md
cp "$FIX/design-no-frontmatter.md" "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md"
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-skip-design.md" "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1 DEVBREW_SPEC_DISTILL_SESSION_ID=test-ac10")
rc=$?
[[ $rc -eq 0 ]] && [[ ! -f "$WORK/.claude/spec-distill/test-ac10/state.local.md" ]] \
  && ok "AC10: DESIGN_MODE_DISABLE skips design.md silently" \
  || no "AC10 failed (rc=$rc out=$out)"

# Case 11: I1 regression — write twice, verify exactly one pending_review block
mkdir -p "$WORK/docs/superpowers/specs"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-idem-spec.md"
run_hook "$WORK/docs/superpowers/specs/2026-05-16-idem-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-idem" > /dev/null
run_hook "$WORK/docs/superpowers/specs/2026-05-16-idem-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-idem" > /dev/null
pending_count=$(grep -c '^pending_review:' "$WORK/.claude/spec-distill/test-idem/state.local.md")
triggered_count=$(grep -c '^  triggered_at:' "$WORK/.claude/spec-distill/test-idem/state.local.md")
[[ "$pending_count" == "1" ]] && [[ "$triggered_count" == "1" ]] \
  && ok "I1: state file remains idempotent on re-write" \
  || no "I1: state file has $pending_count pending_review and $triggered_count triggered_at (expected 1 each)"

# Case 12: arm-once — 원장에 있는 문서 → arm skip + skip advisory가 normal advisory를 교체
mkdir -p "$WORK/docs/superpowers/specs" "$WORK/.claude/spec-distill/test-armed"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-armed-spec.md"
cat > "$WORK/.claude/spec-distill/test-armed/state.local.md" <<EOF
---
session_id: test-armed
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-armed-spec.md
EOF
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-armed-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-armed")
rc=$?
sf="$WORK/.claude/spec-distill/test-armed/state.local.md"
if [[ $rc -eq 0 ]] \
  && ! grep -qE '^pending_review:' "$sf" \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("arm skipped")' >/dev/null \
  && ! echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("Reviewer will be dispatched")' >/dev/null; then
  ok "arm-once: armed doc → arm skip + skip advisory (no normal advisory)"
else
  no "arm-once armed-doc case failed (rc=$rc out=$out)"
fi

# Case 12b: skip 사유 3종 구분 — 원장에 있고 attempts가 남아 있으면 'capped'(G6 상한),
# 없으면 'reviewed'. 둘 다 armed_paths에 있지만 사용자가 취해야 할 행동이 다르다.
mkdir -p "$WORK/.claude/spec-distill/test-capped"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-capped-spec.md"
cat > "$WORK/.claude/spec-distill/test-capped/state.local.md" <<EOF
---
session_id: test-capped
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-capped-spec.md

dispatch_attempts:
  docs/superpowers/specs/2026-05-16-capped-spec.md: 3
EOF
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-capped-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-capped")
echo "$out" | jq -e '.systemMessage | contains("capped")' >/dev/null \
  && ok "arm-once: G6 상한 도달은 'capped'로 구분 표시" \
  || no "capped advisory 구분 실패 (out=$out)"

# Case 13: 원장에 있는 문서도 Layer 1은 그대로 실행 (구조 실패 → exit 2) — G2
cp "$FIX/spec-missing-goals.md" "$WORK/docs/superpowers/specs/2026-05-16-armed2-spec.md"
mkdir -p "$WORK/.claude/spec-distill/test-armed2"
cat > "$WORK/.claude/spec-distill/test-armed2/state.local.md" <<EOF
---
session_id: test-armed2
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-armed2-spec.md
EOF
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-armed2-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-armed2")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:" \
  && ok "G2: armed doc still subject to Layer 1 (exit 2)" \
  || no "G2 failed (rc=$rc out=$out)"

# Case 14: 다른 비-armed 문서의 write_state가 armed_paths를 보존 (multi-key)
mkdir -p "$WORK/.claude/spec-distill/test-pres"
cat > "$WORK/.claude/spec-distill/test-pres/state.local.md" <<EOF
---
session_id: test-pres
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-docA-design.md
EOF
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md"
run_hook "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-pres" >/dev/null
sf="$WORK/.claude/spec-distill/test-pres/state.local.md"
if grep -q "  - docs/superpowers/specs/2026-05-16-docA-design.md" "$sf" \
   && grep -qE '^pending_review:' "$sf"; then
  ok "multi-key: armed_paths preserved across other-doc write_state"
else
  no "multi-key preservation failed ($(cat "$sf"))"
fi
finish
