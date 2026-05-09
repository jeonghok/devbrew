#!/usr/bin/env bash
# spec-distill UserPromptSubmit hook
# Emits a <spec-distill-signal> tag when the user prompt looks like a build/make/create request.
# Strictly advisory — does not block.

set -u

# Kill switches (devbrew convention)
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
  exit 0
fi
if [[ "${DEVBREW_SKIP_HOOKS:-}" == *"spec-distill:UserPromptSubmit"* ]]; then
  exit 0
fi

# Read prompt from stdin (Claude Code passes JSON event payload via stdin)
payload=$(cat 2>/dev/null || echo "")
prompt=$(echo "$payload" | grep -oE '"user_prompt"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"user_prompt"[[:space:]]*:[[:space:]]*"\(.*\)"$/\1/' || echo "")

# Fallback: treat whole stdin as prompt if JSON parse failed
if [[ -z "$prompt" ]]; then
  prompt="$payload"
fi

# Skip if already an explicit /interview call
if [[ "$prompt" =~ ^/interview ]]; then
  exit 0
fi

# Detect build/make/create keywords (Korean + English)
keywords_pattern='build|make|create|implement|design|구축|만들|생성|구현|디자인'

# Detect short prompts (< 20 words) — heuristic for "vague request"
word_count=$(echo "$prompt" | wc -w | tr -d ' ')

if echo "$prompt" | grep -qiE "$keywords_pattern" && [[ "$word_count" -lt 20 ]]; then
  cat <<EOF
<spec-distill-signal>
이 요청은 spec 작성 인터뷰가 필요해 보입니다 (build/make/create 키워드 + 짧은 prompt).
명시적으로 \`/interview\`를 호출하면 4-block Korean Socratic 인터뷰로 모호함을 줄일 수 있습니다.
(이 신호는 advisory — 강제하지 않습니다. 무시하고 진행해도 됩니다.)
</spec-distill-signal>
EOF
fi

exit 0
