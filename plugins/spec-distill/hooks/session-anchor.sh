#!/usr/bin/env bash
# spec-distill SessionStart hook — read-only advisor (P14 mutate X).
# Emits structured JSON {"systemMessage": "..."} if previous session state exists
# (matches quality-gates Python hook output protocol).

set -u
set -o pipefail

# Kill switches (colon-anchored)
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
  exit 0
fi
case ":${DEVBREW_SKIP_HOOKS:-}:" in
  *":spec-distill:SessionStart:"*) exit 0 ;;
esac

state_dir="${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill"

if [[ ! -d "$state_dir" ]]; then
  exit 0
fi

# Distinguish "no sessions" from "permission denied" (loud-logging requirement)
if [[ ! -r "$state_dir" ]]; then
  echo "[spec-distill:session-anchor] warn: state directory exists but is not readable: $state_dir" >&2
  exit 0
fi

# Find session state files (depth 2 = .claude/spec-distill/<session-id>/state.local.md)
active_sessions=$(find "$state_dir" -mindepth 2 -maxdepth 2 -name "state.local.md" 2>/dev/null | head -3 || true)

if [[ -z "$active_sessions" ]]; then
  exit 0
fi

# Build advisory message (collapse newlines to spaces — JSON-string safety)
sessions_inline=$(printf '%s' "$active_sessions" | tr '\n' ' ' | sed 's/ $//')
msg="이전 인터뷰 세션이 있습니다. \`/interview resume\`로 재진입하거나, 새 세션은 \`/interview\` 그대로 시작. State 파일: $sessions_inline"

if command -v jq >/dev/null 2>&1; then
  jq -n --arg m "$msg" '{systemMessage: $m}'
else
  escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
  printf '{"systemMessage":"%s"}\n' "$escaped"
fi

exit 0
