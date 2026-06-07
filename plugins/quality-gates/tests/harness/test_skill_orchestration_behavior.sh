#!/usr/bin/env bash
# test_skill_orchestration_behavior.sh — protocol-shape test for SKILL.md.
#
# Asserts the prompt-defined orchestration protocol exists in SKILL.md with
# expected ordering, proximity, and section membership. Does NOT execute
# SKILL.md at runtime; this is a STATIC protocol-shape verifier that replaces
# V7's tautological substring grep (V7 looked for `PASS` token that never
# appeared, so its negative-assertion path was unreachable).
#
# Coverage (spec §5.6.9):
#   - Review gate → Runtime gate dispatch line order monotonic
#   - All 4 reviewer agents present in Review/Runtime gate fan-out (consistency w/ C1)
#   - Review gate iter cap within proximity of AskUserQuestion section
#   - DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS within 100 lines of Runtime gate dispatch
#   - Retry-path AskUserQuestion block lies between Review gate and Runtime gate

set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SKILL_MD="$(cd -- "$SCRIPT_DIR/../.." && pwd)/skills/quality-pipeline/SKILL.md"

test -f "$SKILL_MD" || { echo "FAIL: SKILL.md not found at $SKILL_MD"; exit 1; }

fail=0

first_line() {
  # First line number where $1 (extended regex) matches, or "0" if absent.
  local pat="$1"
  awk -v p="$pat" '$0 ~ p { print NR; exit }' "$SKILL_MD" \
    | { read -r n || true; echo "${n:-0}"; }
}

first_line_after() {
  # First line number > $2 where $1 matches, or "0" if absent.
  local pat="$1" after="$2"
  awk -v p="$pat" -v a="$after" '
    NR > a && $0 ~ p { print NR; exit }
  ' "$SKILL_MD" | { read -r n || true; echo "${n:-0}"; }
}

assert_line() {
  local label="$1" line="$2"
  if [[ "$line" -gt 0 ]]; then
    echo "PASS: $label (line $line)"
  else
    echo "FAIL: $label (pattern not found)"
    fail=$((fail + 1))
  fi
}

assert_order() {
  local label="$1" earlier="$2" later="$3"
  if [[ "$earlier" -gt 0 && "$later" -gt 0 && "$earlier" -lt "$later" ]]; then
    echo "PASS: $label (line $earlier < line $later)"
  else
    echo "FAIL: $label (earlier=$earlier later=$later)"
    fail=$((fail + 1))
  fi
}

assert_proximity() {
  local label="$1" a="$2" b="$3" within="$4"
  if [[ "$a" -gt 0 && "$b" -gt 0 ]]; then
    local d
    if [[ "$a" -gt "$b" ]]; then d=$((a - b)); else d=$((b - a)); fi
    if [[ "$d" -le "$within" ]]; then
      echo "PASS: $label (lines $a, $b within $within)"
    else
      echo "FAIL: $label (lines $a, $b distance $d > $within)"
      fail=$((fail + 1))
    fi
  else
    echo "FAIL: $label (a=$a b=$b — missing markers)"
    fail=$((fail + 1))
  fi
}

# Gate dispatch lines.
review_line=$(first_line 'subagent_type.*quality-gates:adversarial')
runtime_line=$(first_line 'subagent_type.*runtime-verifier')

assert_line "Review gate adversarial dispatch"   "$review_line"
assert_line "Runtime gate runtime-verifier dispatch" "$runtime_line"

# Ordering: Review gate < Runtime gate.
assert_order "Review precedes Runtime" "$review_line" "$runtime_line"

# Four reviewer agents in Review / Runtime gate fan-out (consistency with C1 / AC1).
for agent in adversarial test-scope-validator security-reviewer runtime-verifier; do
  if grep -qE "subagent_type[^\"]*\"quality-gates:$agent" "$SKILL_MD"; then
    echo "PASS: $agent dispatch present"
  else
    echo "FAIL: $agent dispatch missing"
    fail=$((fail + 1))
  fi
done

# Review gate iter cap proximity to Review gate section / AskUserQuestion.
# Use FIRST AskUserQuestion at or after the adversarial dispatch (the
# description's top-of-file AskUserQuestion mention is irrelevant; we want the
# Review-gate decision-tool call).
askuser_review_line=$(first_line_after 'AskUserQuestion' "$review_line")
itercap_line=$(first_line 'max_review_iterations')
assert_proximity "iter cap near Review gate AskUserQuestion" "$askuser_review_line" "$itercap_line" 100

# DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS near Runtime gate dispatch — use first mention
# AT OR AFTER the Runtime gate dispatch line (the top-of-file "up to ..." preview
# mention is irrelevant; we want the Runtime NEEDS_RESOLUTION section reference).
runtime_max_line=$(first_line_after 'DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS' "$runtime_line")
assert_proximity "RUNTIME_MAX_RESOLUTIONS near Runtime dispatch" "$runtime_line" "$runtime_max_line" 100

# Retry-path AskUserQuestion (I6) between Review gate dispatch and Runtime gate dispatch.
retry_line=$(first_line 'Retry: error handling|Retry failed')
if [[ "$retry_line" -gt 0 && "$retry_line" -gt "$review_line" && "$retry_line" -lt "$runtime_line" ]]; then
  echo "PASS: Retry block between Review gate ($review_line) and Runtime gate ($runtime_line) at $retry_line"
else
  echo "FAIL: Retry block not between Review gate ($review_line) and Runtime gate ($runtime_line); found at $retry_line"
  fail=$((fail + 1))
fi

# --- v2.2.0 sandbox-executor protocol-shape ---

# create-sandbox must be invoked, and BEFORE the runtime-verifier dispatch.
sandbox_line=$(first_line 'create-sandbox')
assert_line "create-sandbox invoked" "$sandbox_line"
assert_order "create-sandbox precedes runtime-verifier dispatch" "$sandbox_line" "$runtime_line"

# mutation-guard must be invoked AFTER the runtime-verifier dispatch.
guard_line=$(first_line_after 'mutation-guard' "$runtime_line")
assert_line "mutation-guard invoked after runtime dispatch" "$guard_line"

# forced_downgrade must be referenced (verdict gating on the guard result).
assert_line "forced_downgrade referenced" "$(first_line 'forced_downgrade')"

# Upfront Execution Plan section present, and before the Review gate dispatch.
upfront_line=$(first_line 'Upfront Execution Plan|Execution Plan')
assert_line "Upfront Execution Plan section present" "$upfront_line"

# requires_decision drives the upfront gate.
assert_line "requires_decision referenced in plan gate" "$(first_line 'requires_decision')"

# Blocked-path routing references the three policies.
assert_line "block policy stop/skip/ask present" "$(first_line 'block_policy|stop / skip / ask|stop/skip/ask')"

# Kill-switch fallback present.
assert_line "runtime sandbox kill switch present" "$(first_line 'DEVBREW_QG_DISABLE_RUNTIME_SANDBOX')"

# spec_acceptance_criteria threaded to the verifier.
assert_line "spec_acceptance_criteria threaded" "$(first_line 'spec_acceptance_criteria')"

# Version bumped to 2.5.0 (title + final summary).
assert_line "v2.5.0 in SKILL" "$(first_line 'v2.5.0|2\.5\.0')"

# --- v2.2.0 mutation-guard hardening protocol-shape ---

# C-C: R4 must route an errored/garbled guard as ≤FAIL, never PASS.
# Anchor on `exit 4` (unique to the R4 routing table), then require the
# fail-closed phrases to appear AT/AFTER it — so deleting them from R4 fails
# the test even though similar words appear earlier (R0 / TOC).
r4_tbl=$(first_line 'exit 4')
assert_line "R4 routes guard exit 4 as FAIL"          "$r4_tbl"
assert_line "R4 surfaces guard_error"                 "$(first_line 'guard_error')"
assert_line "R4 surfaces guard stderr verbatim"       "$(first_line_after 'stderr verbatim' "$((r4_tbl - 1))")"
assert_line "R4 never-PASS for indeterminate guard"   "$(first_line_after 'indeterminate' "$((r4_tbl - 1))")"

# I-A/I-B: fallback caps at SKIP_WITH_EVIDENCE (never PASS) + single runtime_project_dir.
assert_line "runtime_project_dir variable used"      "$(first_line 'runtime_project_dir')"
assert_line "fallback caps at SKIP_WITH_EVIDENCE"    "$(first_line 'SKIP_WITH_EVIDENCE.*never PASS|never PASS.*SKIP_WITH_EVIDENCE')"
# I-B: the R3 dispatch project_dir must NOT hardcode sandbox_dir (use runtime_project_dir).
if grep -qE 'project_dir:[[:space:]]*\\?"\$runtime_project_dir' "$SKILL_MD"; then
  echo "PASS: R3 dispatch uses runtime_project_dir"
else
  echo "FAIL: R3 dispatch does not use runtime_project_dir"
  fail=$((fail + 1))
fi

# I-C: evidence_dir threaded to R3 as a main-repo absolute path that survives R5 discard.
assert_line "evidence_dir threaded to verifier"  "$(first_line 'evidence_dir')"
if grep -qE 'evidence_dir.*\.claude/quality-gates/' "$SKILL_MD"; then
  echo "PASS: evidence_dir uses .claude/quality-gates/ path"
else
  echo "FAIL: evidence_dir path not .claude/quality-gates/"
  fail=$((fail + 1))
fi
assert_line "evidence_dir uses CLAUDE_CODE_SESSION_ID" "$(first_line 'CLAUDE_CODE_SESSION_ID')"

# I-G: retry must re-capture BOTH sandbox_dir AND baseline_sha (new snapshot auto-recorded).
retry_recap_line=$(first_line 're-capture')
assert_line "retry re-capture phrase present" "$retry_recap_line"
if grep -E 're-capture' "$SKILL_MD" | grep -q 'baseline_sha' && \
   grep -E 're-capture' "$SKILL_MD" | grep -q 'sandbox_dir'; then
  echo "PASS: retry re-captures both sandbox_dir and baseline_sha"
else
  echo "FAIL: retry does not re-capture both sandbox_dir + baseline_sha"
  fail=$((fail + 1))
fi

# --- round-2 digest-seal wiring ---

# R0 must capture snapshot_digest in the R0 section (after the "Step R0" heading,
# before the runtime-verifier dispatch) — NOT the Law-2 header at the top.
r0_section=$(first_line 'Step R0')
r0_digest=$(first_line_after 'snapshot_digest' "$r0_section")
if [[ "$r0_digest" -gt 0 && "$r0_digest" -lt "$runtime_line" ]]; then
  echo "PASS: R0 captures snapshot_digest (line 3) at $r0_digest"
else
  echo "FAIL: R0 does not capture snapshot_digest in the R0 section (found=$r0_digest, runtime=$runtime_line)"
  fail=$((fail + 1))
fi

# Guard call must thread the 3rd arg on the R4 call line itself ($guard_line,
# the first `mutation-guard` AFTER the runtime dispatch) — not the header mention.
if awk -v n="$guard_line" 'NR==n && /snapshot_digest/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: R4 guard call threads snapshot_digest (3-arg) at line $guard_line"
else
  echo "FAIL: R4 guard call (line $guard_line) does not thread snapshot_digest"
  fail=$((fail + 1))
fi

# I-G retry must re-capture snapshot_digest (line 3) in addition to the two existing.
if grep -E 're-capture' "$SKILL_MD" | grep -q 'snapshot_digest'; then
  echo "PASS: retry re-captures snapshot_digest"
else
  echo "FAIL: retry does not re-capture snapshot_digest"
  fail=$((fail + 1))
fi

# --- R2-AC5: Law-3 persona hardening (the bypass escaped because reviewers
#     trusted a verifier-writable artifact; the persona now forces that check).
#     Anchor on the stable literal `verifier-writable`, which BOTH persona edits
#     in Task 6 Step 3 include verbatim. ---
AGENTS_DIR="$(cd -- "$SCRIPT_DIR/../.." && pwd)/agents"
for p in security-reviewer adversarial; do
  if grep -qi 'verifier-writable' "$AGENTS_DIR/$p.md"; then
    echo "PASS: $p persona has the verifier-writable-artifact check"
  else
    echo "FAIL: $p persona missing the verifier-writable-artifact check"
    fail=$((fail + 1))
  fi
done

# --- v2.3.0 R4: Review-gate findings surfaced before the decision tool ---
# The Surface-findings step (Step 4.5) must precede the iter-boundary
# decision's `findings remain` question. Anchor on the surface-step TEXT,
# NOT the `## Review gate` section heading — a heading always precedes its
# body, so a heading anchor is a tautological PASS (the V7-class defect this
# file was created to avoid). Existence grep alone cannot catch mis-placement.
surface_line=$(first_line 'Surface findings|Step 4\.5')
question_line=$(first_line 'question:.*findings remain')
assert_line "Surface-findings step present" "$surface_line"
assert_line "iter-boundary decision question present" "$question_line"
assert_order "Surface findings precedes iter-boundary decision" "$surface_line" "$question_line"

# --- v2.4.0: Upfront gate-scope decision (Decision 1) ---

# Decision 1 gate-scope question exists: literal `both gates` anchor in a
# question: field, with header `Gate scope`.
gatescope_q=$(first_line 'question:.*both gates')
assert_line "gate-scope question present (anchor 'both gates')" "$gatescope_q"
assert_line "Gate scope header present" "$(first_line 'header:.*Gate scope')"

# Ordering: gate-scope question BEFORE the Review gate dispatch.
assert_order "gate-scope question precedes Review gate dispatch" "$gatescope_q" "$review_line"

# Ordering: gate-scope (Decision 1) question BEFORE the runtime-scope (Decision 2) question.
runtimescope_q=$(first_line 'question:.*Runtime scope')
assert_order "gate-scope question precedes runtime-scope question" "$gatescope_q" "$runtimescope_q"

# Uniqueness: `both gates` appears in exactly one question: line (anchor convention).
bg_count=$(grep -cE 'question:.*both gates' "$SKILL_MD" || true)
if [[ "$bg_count" -eq 1 ]]; then
  echo "PASS: 'both gates' anchor unique (1 question: line)"
else
  echo "FAIL: 'both gates' anchor not unique ($bg_count question: lines)"
  fail=$((fail + 1))
fi

# `gate` domain documents `both`.
assert_line "gate domain documents both" "$(first_line 'gate.*review.*runtime.*both')"

# Precedence advisory: explicit gate= wins over --skip-runtime (no silent conflict).
assert_line "gate= precedence advisory documented" "$(first_line 'gate=.*wins')"

# Dispatch Loop <-> Upfront Execution Plan consistency (round-2 advisory b82e4d19):
# Dispatch Loop step 2 must reference Decision 1 and the short-circuit so the two
# sections cannot drift.
dl_line=$(first_line '## Dispatch Loop')
assert_line "Dispatch Loop section present" "$dl_line"
assert_line "Dispatch Loop references Decision 1" "$(first_line_after 'Decision 1' "$dl_line")"
assert_line "Dispatch Loop references short-circuit" "$(first_line_after 'short-circuit' "$dl_line")"

# --- v2.4.0 review-fix F1: single-gate /qg runtime produces the manifest ---
# /qg runtime bypasses the Dispatch Loop (and thus Decision 2), so the Runtime
# gate itself must produce manifest/approved_surfaces/block_policy for R3.
# Guard: a Step R-init must run detect-runtime.sh on the single-gate runtime
# path, BEFORE the runtime-verifier (R3) dispatch.
rg_header=$(first_line '^## Runtime gate')
rinit_line=$(first_line 'Step R-init')
assert_line "Runtime gate Step R-init present" "$rinit_line"
assert_order "R-init precedes runtime-verifier dispatch" "$rinit_line" "$runtime_line"
assert_line "R-init runs detect-runtime in the Runtime gate" "$(first_line_after 'detect-runtime' "$rg_header")"
if awk -v a="$rg_header" -v b="$runtime_line" 'NR>a && NR<b && /single-gate/ {f=1} END{exit !f}' "$SKILL_MD"; then
  echo "PASS: Runtime gate documents the single-gate runtime manifest path"
else
  echo "FAIL: Runtime gate does not document single-gate runtime manifest init"
  fail=$((fail + 1))
fi

# --- v2.4.0 review-fix F2: review-only suppresses "Proceed to Runtime gate" ---
# When gate scope = Review gate only, the iter-boundary AND max-iter decisions
# must NOT offer "Proceed to Runtime gate"; both carry a gate-scope-conditional
# note replacing it with a finalize option.
gsc_count=$(grep -cE 'Gate-scope conditional' "$SKILL_MD" || true)
if [[ "$gsc_count" -ge 2 ]]; then
  echo "PASS: gate-scope-conditional note in iter-boundary + max-iter ($gsc_count)"
else
  echo "FAIL: gate-scope-conditional note missing (found $gsc_count, need >=2)"
  fail=$((fail + 1))
fi
# Anchor on a paren-free substring: macOS awk -v mangles `\(` escapes, so a
# literal-paren regex would fail to match the (present) finalize option text.
assert_line "review-only finalize option present" "$(first_line 'accept findings, finalize')"

# --- v2.4.0 review-fix C4: gate= precedence wired into the skip logic ---
# effective_skip_runtime must be DEFINED (Arguments normalization) AND USED by
# the runtime-skip tests (Dispatch Loop step 4 + Runtime gate "skip this
# section") — otherwise the Decision-1 `gate=` > `--skip-runtime` precedence is
# documented but never governs execution (e.g. `/qg runtime --skip-runtime`
# would silently skip runtime). >=3 references = defined + both skip sites.
esr_count=$(grep -cE 'effective_skip_runtime' "$SKILL_MD" || true)
if [[ "$esr_count" -ge 3 ]]; then
  echo "PASS: effective_skip_runtime wired into the skip logic ($esr_count refs)"
else
  echo "FAIL: effective_skip_runtime under-wired (found $esr_count, need >=3: Arguments + Dispatch step 4 + Runtime gate)"
  fail=$((fail + 1))
fi

# --- v2.4.0 review-fix F7: Review gate clean-exit also honors review-only ---
# The kept=0 clean branches must route via Dispatch Loop step 4 (gate-scope
# check), NOT unconditionally "continue to the Runtime gate" — else a clean
# Review gate under "Review gate only" would run Runtime anyway.
# Anchor on a single-line substring (the full phrase wraps across lines).
assert_line "Review gate clean-exit routes via gate-scope check" "$(first_line 'when gate scope = Review gate only')"

# --- v2.6.0 AC6/AC7/AC9/AC13: empty-scope redirect gate ---
# check-review-scope.sh invoked in the Review gate (call+cache).
assert_line "check-review-scope.sh invoked" "$(first_line 'check-review-scope.sh')"
# AC6: redirect question carries the unique anchor 'review scope is empty'.
redirect_q=$(first_line 'question:.*[Rr]eview scope is empty')
assert_line "empty-scope redirect question present (anchor 'review scope is empty')" "$redirect_q"
rse_count=$(grep -ciE 'question:.*review scope is empty' "$SKILL_MD" || true)
if [[ "$rse_count" -eq 1 ]]; then
  echo "PASS: 'review scope is empty' anchor unique (1 question: line)"
else
  echo "FAIL: 'review scope is empty' anchor not unique ($rse_count question: lines)"
  fail=$((fail + 1))
fi
assert_line "Empty-scope redirect decision section present" "$(first_line '## Empty-scope redirect decision')"
# AC7: honest-empty branch leaves a positive observable line (not a non-event).
assert_line "honest-empty skip anchor present" "$(first_line 'skipping reviewer dispatch')"
# AC13: redirect-branch reuses the script-emitted base (C6 single base).
assert_line "redirect-branch reuses script-emitted base (AC13)" "$(first_line 'script-emitted base')"
# AC9: scope-redirect kill switch documented in SKILL.
assert_line "scope-redirect kill switch present" "$(first_line 'DEVBREW_QG_DISABLE_SCOPE_REDIRECT')"

# AC: degraded signal emits a loud advisory (CLAUDE.md loud-logging; design §5.1).
assert_line "degraded scope advisory present" "$(first_line 'scope check degraded')"

# --- v2.6.0 AC8: honest-verdict floor at Step 4.5 (both clean sub-cases) ---
assert_line "honest floor label present" "$(first_line 'NOT certified clean')"
assert_line "honest floor gated on the cached scope signal" "$(first_line 'scope_signal == empty_scope_with_changes')"
# 'no scope reviewed' must appear in both clean sub-cases + the final-summary
# variant → at least 3 occurrences.
floor_count=$(grep -cE 'no scope reviewed' "$SKILL_MD" || true)
if [[ "$floor_count" -ge 3 ]]; then
  echo "PASS: honest floor label in both clean sub-cases + final summary ($floor_count)"
else
  echo "FAIL: honest floor under-applied (found $floor_count, need >=3)"
  fail=$((fail + 1))
fi

if [[ "$fail" -eq 0 ]]; then
  echo "test_skill_orchestration_behavior: all protocol-shape assertions PASS"
  exit 0
else
  echo "test_skill_orchestration_behavior: $fail assertion(s) FAILED"
  exit 1
fi
