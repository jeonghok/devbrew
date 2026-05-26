#!/usr/bin/env bash
# spec-distill v0.9.0 — AC11 atomic approve handoff (script-ified from prose).
# Usage: approve_handoff.sh <session_id> <spec_path>
set -euo pipefail

# Kill switch — CLAUDE.md "kill switch는 보안 컨트롤"
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
    echo "[spec-distill] approve_handoff: DEVBREW_DISABLE_SPEC_DISTILL=1 — skip (state preserved)" >&2
    exit 0
fi

session_id="${1:?usage: approve_handoff.sh <session_id> <spec_path>}"
spec_path="${2:?usage: approve_handoff.sh <session_id> <spec_path>}"

# session_id charset guard (defense in depth — state_path.SESSION_PATTERN equivalent)
cleanup_skipped=0
case "$session_id" in
    ''|*[!A-Za-z0-9_-]*)
        echo "[spec-distill] approve_handoff: cleanup skipped — invalid session_id '${session_id:-<empty>}'" >&2
        cleanup_skipped=1
        ;;
    *)
        # also enforce min length 8 to match SESSION_PATTERN
        if [[ ${#session_id} -lt 8 ]]; then
            echo "[spec-distill] approve_handoff: cleanup skipped — session_id length < 8" >&2
            cleanup_skipped=1
        fi
        ;;
esac

# Step 1: commit
git add -- "$spec_path"
if ! git commit -m "spec: $(basename "${spec_path%-spec.md}" | sed 's/^[0-9-]*//') (v1.0.0, spec-distill v0.9.0)"; then
    echo "[spec-distill] commit failed — state preserved, 사용자 수동 개입 필요" >&2
    exit 1
fi

# Step 2: handoff packet (v0.9.0)
cat <<EOF

===== spec-distill handoff packet =====
Spec lock 완료: $spec_path

[1] /compact 명령 (지금 복사-실행):

  /compact spec at $spec_path 보존. 그 spec 본문(특히 Handoff Context, Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화/기각된 대안/중간 추론 drop. 다음 단계는 "Skill superpowers:writing-plans $spec_path" 호출.

[2] /compact 후 첫 메시지 (자동 진행되면 생략):

  Skill superpowers:writing-plans $spec_path

========================================
EOF

# Step 3: state cleanup (charset-guarded, race-tolerant)
if [[ "$cleanup_skipped" == "0" ]]; then
    rm -rf -- ".claude/spec-distill/$session_id/" 2>/dev/null || \
        echo "[spec-distill] cleanup rm failed (non-fatal) — SessionEnd hook will retry" >&2
fi

# Step 4: termination notice
echo "spec-distill v0.9.0 종료."
