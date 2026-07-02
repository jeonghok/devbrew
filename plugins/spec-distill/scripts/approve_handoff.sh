#!/usr/bin/env bash
# spec-distill v0.15.0 — proceed-gate handoff finalizer.
# 다음-단계 추천은 reviewing-spec Phase 5의 AskUserQuestion proceed 게이트가 담당
# (hook은 AskUserQuestion을 못 띄움; skill은 띄움). 이 스크립트는 순서대로:
#   (1) kill switch + arg/charset guard,
#   (2) approved spec를 suppressed_paths에 기록 + same-key pending strip
#       (suppress_state.py add — canonical_key 기반, 파일 존재 불필요). v0.15.0:
#       이 기록을 working-tree 존재검사 *앞*에 둬서 상대경로·서브디렉토리 cwd·
#       dangling 어떤 경우에도 누락되지 않게 한다(같은-턴 재dispatch 순서 버그 fix).
#   (3) spec_path working-tree 부재 시 NON-BLOCKING stale/dangling advisory (exit 아님),
#   (4) 미커밋/dirty 시 NON-BLOCKING advisory.
# Idempotent by set-membership: 재호출은 키를 최대 1회 추가.
#
# Usage: approve_handoff.sh <session_id> <spec_path>
# Exit codes:
#   0 — approved spec suppressed (committed, dirty, OR missing-with-advisory)
#   1 — arg/charset error ONLY (session_id empty/invalid/<8, or missing args)
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

# ─── Suppress approved doc + strip its same-key pending (v0.15.0, AC1) ───
# MUST precede the working-tree existence check: canonical_key 기반이라 파일이
# 없어도 기록되고, 이 "먼저 기록"이 v0.14.0의 순서 버그(`-f` 조기 exit → suppress
# 누락 → 같은 턴 Stop 재dispatch)를 닫는다. 정규화·strip·add는 suppress_state.py가
# 단일 소스(C4/AC17) — 이 스크립트는 specs prefix 리터럴을 포함하지 않는다.
# 최종 메시지는 suppress 성공 여부에 따라 달라진다(qg codex C1 — 모순 금지).
suppress_cli="$(dirname "$0")/suppress_state.py"
if [[ -f "$suppress_cli" ]]; then
    if python3 "$suppress_cli" add "$session_id" "$spec_path"; then
        suppress_msg="approved spec suppressed for this session."
    else
        suppress_msg="approve recorded; suppression FAILED (advisory above) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능."
        echo "[spec-distill] approve_handoff: suppress 기록 실패 (non-fatal, out-of-scope 경로 등) — 같은 문서 재편집 시 재arm 가능. /spec-distill:cancel-review로 수동 억제 가능." >&2
    fi
else
    suppress_msg="suppression skipped (suppress_state.py 없음) — 세션 dir는 SessionEnd/GC가 정리."
    echo "[spec-distill] approve_handoff: suppress_state.py 없음 (non-fatal) — 세션 dir는 SessionEnd/GC가 정리." >&2
fi

# ─── Clear this doc's review-in-progress lock entry (v0.18.0, AC6) ───
# approve는 리뷰 완료 신호 → 그 문서 락 엔트리 제거(approve/cancel 대칭). raw
# $spec_path를 넘기고 canonical_key 정규화는 review_lock에 위임(specs prefix 리터럴
# 미포함 — test_no_prefix_slice 계약 유지). 다른 문서 엔트리는 불변(multi-key).
lock_cli="$(dirname "$0")/review_lock.py"
if [[ -f "$lock_cli" ]]; then
    python3 "$lock_cli" clear "$session_id" "$spec_path" \
      || echo "[spec-distill] approve_handoff: review-lock clear 실패 (non-fatal)" >&2
fi

# ─── spec_path advisory checks (NON-BLOCKING — suppress는 이미 위에서 기록됨) ───
# v0.15.0: `[[ -f ]]`는 early-exit이 아니라 advisory. dangling worktree 경로
# (git HEAD엔 tracked, working-tree엔 부재)는 예전엔 suppress 기록 *전에* exit 1로
# 빠졌다 — 그게 버그. 이제는 사용자에게 stale state만 알린다.
if [[ -f "$spec_path" ]]; then
    # Committed check — ADVISORY only (non-blocking, LD6/AC5). spec은 사용자 소유.
    # 미커밋이어도 차단 안 함 — writing-plans는 working-tree content를 읽음.
    # ls-files: explicit exit-code handling (fail-closed) — corrupt repo / smudge
    # crash가 비-zero+빈 stdout으로 나오면 dirty로 advisory.
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
else
    echo "[spec-distill] approve_handoff: spec_path '$spec_path' working-tree에 없음 (advisory — suppress는 기록됨, 진행 계속)." >&2
    echo "[spec-distill] stale/dangling 경로일 수 있음 (예: 삭제된 worktree). reviewing-spec에서 current_spec 재선택 또는 세션 리셋 권장." >&2
fi

echo "spec-distill v0.15.0 handoff finalized (session: $session_id). $suppress_msg 다음 단계는 reviewing-spec proceed 게이트 선택대로 진행."
