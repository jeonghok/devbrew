#!/usr/bin/env bash
# spec-distill v0.10.0 — idempotent handoff state machine.
# Removes git commit responsibility (LD4): spec is user-owned.
# Writes named-status marker (LD3 Ouroboros instantiation) for compact-induction
# Stop hook to detect handoff-pending state.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — handoff packet emitted (status: emitted | already_done)
#   1 — dirty_blocked (uncommitted/dirty spec) or arg error
set -uo pipefail

# ─── Named-status constants (Ouroboros handoff_contract.py pattern) ───
readonly HANDOFF_STATUS_ALREADY_DONE="already_handed_off"
readonly HANDOFF_STATUS_DIRTY_BLOCKED="dirty_blocked"
readonly HANDOFF_STATUS_EMITTED="emitted"

# ─── Kill switch (CLAUDE.md "kill switch는 보안 컨트롤") ───
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
    echo "[spec-distill] approve_handoff: DEVBREW_DISABLE_SPEC_DISTILL=1 — skip (state preserved)" >&2
    exit 0
fi

# ─── Arg validation ───
session_id="${1:?usage: approve_handoff.sh <session_id> <spec_path>}"
spec_path="${2:?usage: approve_handoff.sh <session_id> <spec_path>}"

# ─── session_id charset guard (defense in depth — state_path.SESSION_PATTERN equivalent) ───
# v0.10.0 (post-Gate-2 review): warn-and-continue replaced with fail-fast.
# Earlier shape set cleanup_skipped=1 but allowed unvalidated session_id to be
# interpolated into marker_file path (line 50). The marker write path didn't
# exist before v0.10.0 — adding it expanded the blast radius of the bypass.
# cleanup_skipped variable retained for backward symmetry but is now always 0.
cleanup_skipped=0
case "$session_id" in
    ''|*[!A-Za-z0-9_-]*)
        echo "[spec-distill] approve_handoff: invalid session_id '${session_id:-<empty>}' — aborting" >&2
        exit 1
        ;;
    *)
        if [[ ${#session_id} -lt 8 ]]; then
            echo "[spec-distill] approve_handoff: session_id length < 8 — aborting" >&2
            exit 1
        fi
        ;;
esac

# ─── Resolve marker directory (uses git-common-dir like state_path.py) ───
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
if [[ ! "$git_common_dir" = /* ]]; then
    git_common_dir="$(pwd)/$git_common_dir"
fi
main_repo="$(dirname "$git_common_dir")"
markers_dir="$main_repo/.claude/spec-distill/.markers"
marker_file="$markers_dir/${session_id}.emitted"

# ─── State machine: determine current handoff status ───
# Priority: existing marker → already_done. Else: check working tree.
if [[ -f "$marker_file" ]]; then
    current_status="$HANDOFF_STATUS_ALREADY_DONE"
else
    # No marker yet — check spec is in HEAD and working tree is clean.
    if ! git rev-parse HEAD -- "$spec_path" >/dev/null 2>&1; then
        # HEAD missing (empty repo) — untracked spec is caught by the ls-files check below
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    elif ! git diff --quiet -- "$spec_path" 2>/dev/null; then
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    elif ! git diff --quiet --cached -- "$spec_path" 2>/dev/null; then
        current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
    else
        # ls-files check: explicit exit-code handling — corrupt repo / smudge-filter
        # crash exits non-zero with empty stdout, which silently passed as "clean"
        # in the prior `[[ -n "$(...)" ]]` form. Fail-closed: any non-zero exit OR
        # non-empty output → dirty_blocked.
        ls_out=$(git ls-files --others --exclude-standard -- "$spec_path" 2>/dev/null)
        ls_rc=$?
        if [[ $ls_rc -ne 0 || -n "$ls_out" ]]; then
            current_status="$HANDOFF_STATUS_DIRTY_BLOCKED"
        else
            current_status="$HANDOFF_STATUS_EMITTED"
        fi
    fi
fi

# ─── Branch: dirty_blocked → loud advisory + exit 1 (AC2) ───
if [[ "$current_status" == "$HANDOFF_STATUS_DIRTY_BLOCKED" ]]; then
    short_status=$(git status --short -- "$spec_path" 2>/dev/null || echo "??  $spec_path")
    {
        echo "[spec-distill] approve_handoff: $HANDOFF_STATUS_DIRTY_BLOCKED — spec working tree not clean."
        echo "git status --short -- \"$spec_path\":"
        echo "$short_status"
        echo
        echo "사용자 수동 commit 필요. 다음 명령 copy-paste:"
        echo "  git add -- \"$spec_path\""
        echo "  git commit -m \"spec: \$(basename \"$spec_path\" .md) (locked)\""
        echo
        echo "commit 후 approve_handoff.sh 재호출."
    } >&2
    exit 1
fi

# ─── Marker write (emitted path only — already_done preserves existing) ───
mkdir -p "$markers_dir" || {
    echo "[spec-distill] approve_handoff: failed to create markers dir '$markers_dir'" >&2
    exit 1
}
if [[ "$current_status" == "$HANDOFF_STATUS_EMITTED" ]]; then
    # First emit — write fresh marker.
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    cat > "$marker_file" <<MARKER
STATUS=$HANDOFF_STATUS_ALREADY_DONE
TIMESTAMP=$timestamp
FIRE_COUNT=0
SPEC_PATH=$spec_path
MARKER
fi
# else: HANDOFF_STATUS_ALREADY_DONE — preserve TIMESTAMP and FIRE_COUNT (AC3).

# ─── Handoff packet emit (re-emit on every call — idempotent) ───
cat <<EOF

===== spec-distill handoff packet =====
Spec lock 완료: $spec_path

[1] /compact 명령 (지금 복사-실행):

  /compact spec at $spec_path 보존. 그 spec 본문(특히 Handoff Context, Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화/기각된 대안/중간 추론 drop. 다음 단계는 "Skill superpowers:writing-plans $spec_path" 호출.

[2] /compact 후 첫 메시지 (자동 진행되면 생략):

  Skill superpowers:writing-plans $spec_path

========================================
EOF

# ─── Session directory cleanup (only on first emit; already_done preserves nothing extra) ───
if [[ "$current_status" == "$HANDOFF_STATUS_EMITTED" && "$cleanup_skipped" == "0" ]]; then
    rm -rf -- "$main_repo/.claude/spec-distill/$session_id/" 2>/dev/null || \
        echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2
fi

echo "spec-distill v0.10.0 종료 (status: $current_status)."
