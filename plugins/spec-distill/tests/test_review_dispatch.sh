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
setup_state "test-011" "---
session_id: test-011
---

pending_review:
  path: /tmp/some-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-011")
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
setup_state "test-012" "---
session_id: test-012
---
"
out=$(run_hook "test-012")
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && note PASS "AC12: no pending_review silent" \
  || note FAIL "AC12 failed (rc=$rc out=$out)"

# Case 13: AC13 — dispatch removes pending_review + sets last_dispatched_at;
# second call within TTL is silent.
setup_state "test-013" "---
session_id: test-013
---

pending_review:
  path: /tmp/p.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out1=$(run_hook "test-013")
rc1=$?
out2=$(run_hook "test-013")
rc2=$?
[[ $rc1 -eq 0 ]] && [[ $rc2 -eq 0 ]] && [[ -z "$out2" ]] \
  && ! grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-013/state.local.md" \
  && grep -q '^last_dispatched_at:' "$WORK/.claude/spec-distill/test-013/state.local.md" \
  && note PASS "AC13: dispatch consumes block; re-fire within TTL silent" \
  || note FAIL "AC13 failed (rc1=$rc1 rc2=$rc2 out2=$out2)"

# Case 14 (T-1): Stop hook kill switch via DEVBREW_SKIP_HOOKS=spec-distill:Stop
setup_state "test-014" "---
session_id: test-014
---

pending_review:
  path: /tmp/k.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-014 \
  DEVBREW_SKIP_HOOKS="spec-distill:Stop" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-014/state.local.md" \
  && note PASS "AC14 (T-1): kill switch spec-distill:Stop suppresses emit + preserves state" \
  || note FAIL "AC14 failed (rc=$rc out=$out)"

# Case 15 (T-1): kill switch via DEVBREW_SKIP_HOOKS=spec-distill:review-dispatch (alias)
setup_state "test-015" "---
session_id: test-015
---

pending_review:
  path: /tmp/k2.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-015 \
  DEVBREW_SKIP_HOOKS="spec-distill:review-dispatch" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-015/state.local.md" \
  && note PASS "AC15 (T-1): kill switch :review-dispatch alias suppresses emit" \
  || note FAIL "AC15 failed (rc=$rc out=$out)"

# Case 16 (AC3/AC3b): pending이 suppressed면 dispatch 안 함 + strip +
# last_dispatched_at 불변 (suppress는 dispatch가 아니므로 TTL 시계를 시작 안 함).
setup_state "test-016" "---
session_id: test-016
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-x-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

last_dispatched_at: 2020-01-01T00:00:00Z

suppressed_paths:
  - docs/superpowers/specs/2026-01-01-x-design.md
"
out=$(run_hook "test-016")
rc=$?
sf16="$WORK/.claude/spec-distill/test-016/state.local.md"
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && ! grep -q '^pending_review:' "$sf16" \
  && grep -q '^suppressed_paths:' "$sf16" \
  && grep -q '^last_dispatched_at: 2020-01-01T00:00:00Z$' "$sf16" \
  && note PASS "AC3/AC3b: suppressed pending → no dispatch + strip + last_dispatched_at 불변" \
  || note FAIL "AC3/AC3b failed (rc=$rc out='$out')"

# Case 17 (AC5): suppressed_paths에 다른 키만 있으면 in-scope pending은 정상 dispatch.
setup_state "test-017" "---
session_id: test-017
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-y-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

suppressed_paths:
  - docs/superpowers/specs/2026-01-01-other-design.md
"
out=$(run_hook "test-017")
rc=$?
sf17="$WORK/.claude/spec-distill/test-017/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^pending_review:' "$sf17" \
  && grep -q '^last_dispatched_at:' "$sf17" \
  && note PASS "AC5: non-suppressed in-scope pending → 정상 dispatch (회귀)" \
  || note FAIL "AC5 failed (rc=$rc out='$out')"


# Case 18 (AC3): 같은 문서 락 엔트리 신선 + pending → no-op + pending 보존.
NOW18=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
setup_state "test-018" "---
session_id: test-018
---

pending_review:
  path: docs/superpowers/specs/2026-07-01-lk-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-lk-design.md
    since: $NOW18
"
out=$(run_hook "test-018")
rc=$?
sf18="$WORK/.claude/spec-distill/test-018/state.local.md"
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$sf18" \
  && note PASS "AC3: fresh same-doc lock → no-op + pending 보존" \
  || note FAIL "AC3 failed (rc=$rc out='$out')"

# Case 19 (AC16): 다른 문서만 락 엔트리 신선, 이 문서 pending → 정상 dispatch(억제 안 됨).
NOW19=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
setup_state "test-019" "---
session_id: test-019
---

pending_review:
  path: docs/superpowers/specs/2026-07-01-thisdoc-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-otherdoc-design.md
    since: $NOW19
"
out=$(run_hook "test-019")
rc=$?
sf19="$WORK/.claude/spec-distill/test-019/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^pending_review:' "$sf19" \
  && note PASS "AC16: 다른 문서 락 신선 → 이 문서 정상 dispatch(비억제)" \
  || note FAIL "AC16 failed (rc=$rc out='$out')"

# Case 20 (AC4): 같은 문서 락 엔트리 stale(과거) + pending → dispatch + strip(fail-safe).
setup_state "test-020" "---
session_id: test-020
---

pending_review:
  path: docs/superpowers/specs/2026-07-01-stale-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

review_in_progress:
  - path: docs/superpowers/specs/2026-07-01-stale-design.md
    since: 2020-01-01T00:00:00Z
"
out=$(run_hook "test-020")
rc=$?
sf20="$WORK/.claude/spec-distill/test-020/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^pending_review:' "$sf20" \
  && note PASS "AC4: stale 락 → dispatch + strip(fail-safe = 강제)" \
  || note FAIL "AC4 failed (rc=$rc out='$out')"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
