#!/usr/bin/env bash
# spec-distill v0.11.0 — proceed-gate handoff finalizer.
# No marker, no packet, no named-status: the next-step recommendation now lives
# in reviewing-spec Phase 5's AskUserQuestion proceed gate (a hook cannot raise
# an AskUserQuestion; the skill can). This script only:
#   (1) validates spec_path exists in the working tree (LD4 — fixes dangling-path bug),
#   (2) emits a NON-BLOCKING advisory if the spec is uncommitted/dirty (LD6/AC5),
#   (3) records the approved spec into suppressed_paths + strips its pending
#       (v0.14.0 — replaces dir rm; dir cleanup deferred to SessionEnd/TTL-GC).
# Idempotent by set-membership (AC4/AC12): re-running adds the key at most once.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — spec exists (committed or dirty-with-advisory); approved spec suppressed (dir preserved)
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

# ─── Suppress approved doc + strip its pending (v0.14.0, AC12) — replaces rm -rf ───
# approved 문서를 suppressed_paths에 기록 → 같은 문서 재편집 시 재arm 차단(증상 A).
# 정규화 + same-key pending strip + add는 suppress_state.py가 단일 소스로 수행(C4).
# 세션 dir는 더 이상 여기서 삭제하지 않는다 — "승인됨" 기억을 세션 동안 보존해야
# 재발을 막는다. dir cleanup은 SessionEnd hook / TTL-GC가 담당(AC15).
suppress_cli="$(dirname "$0")/suppress_state.py"
# 최종 메시지는 suppress 성공 여부에 따라 달라진다 — 실패 시 "suppressed" 주장 금지
# (stderr advisory와 stdout 성공문이 모순되지 않도록; qg codex C1).
if [[ -f "$suppress_cli" ]]; then
    if python3 "$suppress_cli" add "$session_id" "$spec_path"; then
        suppress_msg="approved spec suppressed for this session."
    else
        suppress_msg="approve recorded; suppression FAILED (advisory above) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능."
        echo "[spec-distill] approve_handoff: suppress 기록 실패 (non-fatal) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능." >&2
    fi
else
    suppress_msg="suppression skipped (suppress_state.py 없음) — 세션 dir는 SessionEnd/GC가 정리."
    echo "[spec-distill] approve_handoff: suppress_state.py 없음 (non-fatal) — 세션 dir는 SessionEnd/GC가 정리." >&2
fi

echo "spec-distill v0.14.0 handoff finalized (session: $session_id). $suppress_msg 다음 단계는 reviewing-spec proceed 게이트 선택대로 진행."
