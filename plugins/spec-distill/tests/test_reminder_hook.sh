#!/usr/bin/env bash
# AC3 / AC4 / AC8 for pending-review-reminder.py.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/pending-review-reminder.py"
WORK=$(mktemp -d -t specdistill-reminder-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo s > s.txt; git add s.txt; git commit -qm s
SID=case-reminder
SDIR="$WORK/main-repo/.claude/spec-distill/$SID"
mkdir -p "$SDIR"

write_state() {
  local last_dispatched="$1"
  cat > "$SDIR/state.local.md" <<EOF
---
session_id: $SID
---

pending_review:
  path: /docs/superpowers/specs/x-design.md
  mode: design
  worktree_path: /Users/foo/.claude/worktrees/wt
  triggered_at: 2026-05-17T00:00:00Z

last_dispatched_at: $last_dispatched
EOF
}

run_hook() {
  local extra_env="${1:-}"
  cd "$WORK/main-repo" && env -i HOME="$HOME" PATH="$PATH" \
    DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" $extra_env \
    bash -c "echo '{\"user_prompt\":\"hi\"}' | python3 '$HOOK'" 2>&1
}

# AC3: last_dispatched_at within TTL (now-10s) → silent skip
RECENT=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=10)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$RECENT"
out=$(run_hook)
[[ -z "$out" || "$out" == "" ]] \
  && note PASS "AC3: reminder silent within TTL" \
  || note FAIL "AC3 unexpected output: '$out'"

# AC4: last_dispatched_at older than TTL (now-60s) → re-emit
OLD=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$OLD"
out=$(run_hook)
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && note PASS "AC4: reminder re-emits past TTL with full mandate body (dual-target)" \
  || note FAIL "AC4 failed. out='$out'"

# AC4b (T-4): after re-emit, last_dispatched_at must be updated to a recent
# timestamp (anti-spam guard — without this update, AC3 would silently regress).
new_ts=$(grep -E '^last_dispatched_at:' "$SDIR/state.local.md" | awk '{print $2}')
[[ -n "$new_ts" ]] && [[ "$new_ts" != "$OLD" ]] \
  && note PASS "AC4b (T-4): last_dispatched_at updated after emit (anti-spam guard live)" \
  || note FAIL "AC4b failed — last_dispatched_at unchanged after emit: '$new_ts' vs OLD='$OLD'"

# --- review lock 게이트 (AC5) 헬퍼: pending + review_in_progress 엔트리 동시 기록 ---
write_state_with_lock() {
  local last_dispatched="$1"; local lock_since="$2"
  cat > "$SDIR/state.local.md" <<EOF
---
session_id: $SID
---

pending_review:
  path: /docs/superpowers/specs/x-design.md
  mode: design
  worktree_path: /Users/foo/.claude/worktrees/wt
  triggered_at: 2026-05-17T00:00:00Z

last_dispatched_at: $last_dispatched

review_in_progress:
  - path: docs/superpowers/specs/x-design.md
    since: $lock_since
EOF
}

# AC5a: 같은 문서 락 신선 → TTL 만료여도 재-emit 안 함(mid-review 재-nag 방지).
OLD5=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
NOW5=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state_with_lock "$OLD5" "$NOW5"
out=$(run_hook)
[[ -z "$out" ]] \
  && note PASS "AC5a: fresh same-doc lock → reminder 재-emit 안 함(TTL 만료여도)" \
  || note FAIL "AC5a unexpected output: '$out'"

# AC5b: 락 엔트리 stale → 정상 재-emit(fail-safe = 강제).
write_state_with_lock "$OLD5" "2020-01-01T00:00:00Z"
out=$(run_hook)
echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("reviewing-spec")' >/dev/null \
  && note PASS "AC5b: stale lock → reminder 재-emit(fail-safe)" \
  || note FAIL "AC5b failed. out='$out'"

# AC8: kill switch via DEVBREW_SKIP_HOOKS
out=$(run_hook "DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit")
[[ -z "$out" ]] \
  && note PASS "AC8: kill switch (UserPromptSubmit) suppresses emit" \
  || note FAIL "AC8 (UserPromptSubmit) unexpected output: '$out'"

out=$(run_hook "DEVBREW_DISABLE_SPEC_DISTILL=1")
[[ -z "$out" ]] \
  && note PASS "AC8: kill switch (DISABLE_SPEC_DISTILL) suppresses emit" \
  || note FAIL "AC8 (DISABLE) unexpected output: '$out'"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
