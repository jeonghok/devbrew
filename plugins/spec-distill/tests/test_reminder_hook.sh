#!/usr/bin/env bash
# AC3 / AC4 / AC8 for pending-review-reminder.py.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/pending-review-reminder.py"
WORK=$(mktemp -d -t specdistill-reminder-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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
  && ok "AC3: reminder silent within TTL" \
  || no "AC3 unexpected output: '$out'"

# AC4: last_dispatched_at older than TTL (now-60s) → re-emit
OLD=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$OLD"
out=$(run_hook)
echo "$out" | jq -e '.hookSpecificOutput.hookEventName == "UserPromptSubmit"' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && ok "AC4: reminder re-emits past TTL with full mandate body (dual-target)" \
  || no "AC4 failed. out='$out'"

# AC4b (T-4): after re-emit, last_dispatched_at must be updated to a recent
# timestamp (anti-spam guard — without this update, AC3 would silently regress).
new_ts=$(grep -E '^last_dispatched_at:' "$SDIR/state.local.md" | awk '{print $2}')
[[ -n "$new_ts" ]] && [[ "$new_ts" != "$OLD" ]] \
  && ok "AC4b (T-4): last_dispatched_at updated after emit (anti-spam guard live)" \
  || no "AC4b failed — last_dispatched_at unchanged after emit: '$new_ts' vs OLD='$OLD'"

# v0.25.0: reminder는 재-nag일 뿐 리뷰의 완료가 아니다 — 원장(armed_paths)을 쓰지 않는다.
OLD6=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$OLD6"
run_hook >/dev/null
! grep -q '^armed_paths:' "$SDIR/state.local.md" \
  && ok "reminder는 armed_paths를 기록하지 않는다 (재-nag ≠ 리뷰 완료)" \
  || no "reminder가 원장을 기록했다: $(cat "$SDIR/state.local.md")"

# AC8: kill switch via DEVBREW_SKIP_HOOKS
out=$(run_hook "DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit")
[[ -z "$out" ]] \
  && ok "AC8: kill switch (UserPromptSubmit) suppresses emit" \
  || no "AC8 (UserPromptSubmit) unexpected output: '$out'"

out=$(run_hook "DEVBREW_SPEC_DISTILL_DISABLE=1")
[[ -z "$out" ]] \
  && ok "AC8: kill switch (SPEC_DISTILL_DISABLE) suppresses emit" \
  || no "AC8 (DISABLE) unexpected output: '$out'"
finish
