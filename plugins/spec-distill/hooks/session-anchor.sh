#!/usr/bin/env bash
# spec-distill SessionStart hook — read-only advisor (P14 mutate X).
# Emits anchor message if previous session state exists.

set -u

# Kill switches
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
  exit 0
fi
if [[ "${DEVBREW_SKIP_HOOKS:-}" == *"spec-distill:SessionStart"* ]]; then
  exit 0
fi

state_dir=".claude/spec-distill"

# Check if state directory exists with active sessions
if [[ -d "$state_dir" ]]; then
  active_sessions=$(find "$state_dir" -mindepth 2 -maxdepth 2 -name "state.local.md" 2>/dev/null | head -3)
  if [[ -n "$active_sessions" ]]; then
    cat <<EOF
<spec-distill-anchor>
이전 인터뷰 세션이 있습니다. 다음 위치에 state 파일이 보존돼 있습니다:
$active_sessions

\`/interview resume\`로 재진입하거나, 새 세션은 \`/interview\` 그대로 시작.
(이 anchor는 read-only advisory — state는 자동 mutate되지 않습니다.)
</spec-distill-anchor>
EOF
  fi
fi

exit 0
