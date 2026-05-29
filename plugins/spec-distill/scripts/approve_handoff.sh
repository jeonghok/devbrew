#!/usr/bin/env bash
# spec-distill v0.11.0 — proceed-gate handoff finalizer.
# No marker, no packet, no named-status: the next-step recommendation now lives
# in reviewing-spec Phase 5's AskUserQuestion proceed gate (a hook cannot raise
# an AskUserQuestion; the skill can). This script only:
#   (1) validates spec_path exists in the working tree (LD4 — fixes dangling-path bug),
#   (2) emits a NON-BLOCKING advisory if the spec is uncommitted/dirty (LD6/AC5),
#   (3) cleans up the per-session state directory (AC6).
# Idempotent by statelessness: re-running on a clean tree / already-removed
# session dir is a no-op.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — spec exists (committed or dirty-with-advisory); session dir cleaned
#   1 — spec_path missing from working tree, or arg/charset error (no cleanup)
set -uo pipefail

# ─── Kill switch (CLAUDE.md "kill switch는 보안 컨트롤") ───
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
    echo "[spec-distill] approve_handoff: DEVBREW_DISABLE_SPEC_DISTILL=1 — skip (state preserved)" >&2
    exit 0
fi

# ─── Arg validation ───
session_id="${1:?usage: approve_handoff.sh <session_id> <spec_path>}"
spec_path="${2:?usage: approve_handoff.sh <session_id> <spec_path>}"

# ─── session_id charset guard (defense in depth — state_path.SESSION_PATTERN equivalent) ───
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

# ─── spec_path working-tree existence guard (LD4 — MUST precede ALL git queries) ───
# `git rev-parse HEAD -- "$spec_path"` succeeds whenever HEAD exists, regardless
# of whether spec_path is present on disk. A dangling worktree path (tracked in
# git HEAD but removed from the working tree) would otherwise slip through and
# the handoff would run against a non-existent file. The -f guard closes that
# exact bug (spec-reviewer g7b4d2a9). No cleanup on this path — stale judgement
# is deferred to reviewing-spec (state preserved).
if [[ ! -f "$spec_path" ]]; then
    echo "[spec-distill] approve_handoff: spec_path '$spec_path' not found in working tree — no handoff, session state preserved." >&2
    echo "[spec-distill] stale/dangling 경로일 수 있음 (예: 삭제된 worktree). reviewing-spec에서 current_spec 재선택 또는 세션 리셋 필요." >&2
    exit 1
fi

# ─── Resolve main repo (uses git-common-dir like state_path.py) ───
git_common_dir=$(git rev-parse --git-common-dir 2>/dev/null || echo ".git")
if [[ ! "$git_common_dir" = /* ]]; then
    git_common_dir="$(pwd)/$git_common_dir"
fi
main_repo="$(dirname "$git_common_dir")"

# ─── Committed check — ADVISORY only (non-blocking, LD6/AC5) ───
# spec은 사용자 소유 (2026-05-27 LD4 계승). 미커밋이어도 차단하지 않음 —
# writing-plans는 working-tree content를 읽으므로 미커밋 spec도 안전.
# ls-files: explicit exit-code handling (fail-closed) — corrupt repo / smudge-filter
# crash exits non-zero with empty stdout, which silently passed as "clean" in the
# prior `[[ -n "$(...)" ]]` form. Any non-zero exit OR non-empty output → advisory.
ls_out=$(git ls-files --others --exclude-standard -- "$spec_path" 2>/dev/null); ls_rc=$?
if ! git diff --quiet -- "$spec_path" 2>/dev/null \
   || ! git diff --quiet --cached -- "$spec_path" 2>/dev/null \
   || [[ $ls_rc -ne 0 || -n "$ls_out" ]]; then
    {
        echo "[spec-distill] approve_handoff: spec '$spec_path' 미커밋/dirty (advisory — 진행은 계속)."
        echo "기록을 위해 commit 권장:"
        echo "  git add -- \"$spec_path\""
        echo "  git commit -m \"spec: \$(basename \"$spec_path\" .md) (locked)\""
    } >&2
fi

# ─── Session directory cleanup (AC6) ───
rm -rf -- "$main_repo/.claude/spec-distill/$session_id/" 2>/dev/null || \
    echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2

echo "spec-distill v0.11.0 handoff finalized (session: $session_id). 다음 단계는 reviewing-spec proceed 게이트 선택대로 진행."
