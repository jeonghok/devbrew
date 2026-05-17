#!/usr/bin/env bash
# spec-distill UserPromptSubmit hook
# Emits structured JSON {"systemMessage": "..."} when the user prompt looks like
# a vague build/make/create request — Claude Code surfaces this to the user
# (matches quality-gates Python hook output protocol).
# Strictly advisory — does not block.

set -u
set -o pipefail

# Kill switches (CSV — canonical per quality-gates v1.6.x)
if [[ "${DEVBREW_DISABLE_SPEC_DISTILL:-}" == "1" ]]; then
  exit 0
fi
if [[ -n "${DEVBREW_SKIP_HOOKS:-}" ]]; then
  IFS=',' read -ra _skip_tokens <<< "$DEVBREW_SKIP_HOOKS"
  for _tok in "${_skip_tokens[@]}"; do
    case "${_tok// /}" in
      spec-distill:UserPromptSubmit) exit 0 ;;
    esac
  done
  unset _skip_tokens _tok
fi

# Read JSON payload from stdin
payload=$(cat 2>/dev/null || true)

# Parse user_prompt with jq (preferred) — graceful regex fallback if jq missing
prompt=""
if command -v jq >/dev/null 2>&1; then
  prompt=$(printf '%s' "$payload" | jq -r '.user_prompt // empty' 2>/dev/null) || {
    echo "[spec-distill:interview-trigger] warn: jq parse failed; advisory suppressed" >&2
    exit 0
  }
else
  echo "[spec-distill:interview-trigger] warn: jq not found; using regex fallback (may misparse JSON with embedded quotes or newlines)" >&2
  prompt=$(printf '%s' "$payload" \
           | grep -oE '"user_prompt"[[:space:]]*:[[:space:]]*"[^"]*"' 2>/dev/null \
           | sed 's/.*"user_prompt"[[:space:]]*:[[:space:]]*"\(.*\)"$/\1/' 2>/dev/null) || prompt=""
fi

# No extractable prompt → silent (advisory hook should not fire on parse failure)
if [[ -z "$prompt" ]]; then
  exit 0
fi

# Skip if already an explicit /interview call (re-entrancy guard)
if [[ "$prompt" =~ ^/interview ]]; then
  exit 0
fi

# Detect build/make/create keywords (Korean + English)
keywords_pattern='build|make|create|implement|design|구축|만들|생성|구현|디자인'

# Detect short prompts (< 20 wc-words — calibrated for vague request heuristic)
word_count=$(printf '%s' "$prompt" | wc -w | tr -d ' ')

if printf '%s' "$prompt" | grep -qiE "$keywords_pattern" && [[ "$word_count" -lt 20 ]]; then
  msg="이 요청은 spec 작성 인터뷰가 필요해 보입니다 (build/make/create 키워드 + 짧은 prompt). 명시적으로 \`/interview\`를 호출하면 4-block Korean Socratic 인터뷰로 모호함을 줄일 수 있습니다. (이 신호는 advisory — 강제하지 않습니다.)"

  if command -v jq >/dev/null 2>&1; then
    jq -n --arg m "$msg" '{systemMessage: $m}'
  else
    # Manual JSON-escape fallback for environments without jq
    escaped=$(printf '%s' "$msg" | sed 's/\\/\\\\/g; s/"/\\"/g' | tr '\n' ' ')
    printf '{"systemMessage":"%s"}\n' "$escaped"
  fi
fi

exit 0
