#!/usr/bin/env bash
# AC2 / AC10a — security-reviewer persona structural conformance.
# Verifies the persona file declares the canonical finding YAML schema
# from adversarial.md:22-30 and the forced-findings prohibition rule.
set -eu
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERSONA="$REPO_ROOT/plugins/quality-gates/agents/security-reviewer.md"

set +e
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
[ -f "$PERSONA" ] || { no "persona 파일 부재: $PERSONA"; finish; exit; }

# Section extractors — lock placement, not just presence. A rule moved out of
# its section makes the window empty → the grep RED. (AC5: section-scoped, not
# a global keyword count.)
inputs_to_hunt() {
  awk '/^## Inputs/{f=1; next} /^## Hunt categories/{f=0} f' "$PERSONA"
}
antiflag_section() {
  awk '/^## What you do NOT flag/{f=1; next} /^## /{f=0} f' "$PERSONA"
}

# Frontmatter required keys
assert_count_ge "grep -c '^name: security-reviewer$' '$PERSONA'" 1 "frontmatter name"
assert_count_ge "grep -c '^cost_class: medium$' '$PERSONA'" 1 "frontmatter cost_class medium"
assert_count_ge "grep -c '^model: inherit$' '$PERSONA'" 1 "frontmatter model inherit"
assert_count_ge "grep -c '^tools: Read, Grep, Glob$' '$PERSONA'" 1 "frontmatter tools: allowlist (fail-closed)"
assert_file_absent "$PERSONA" '^allowedTools:' "죽은 allowedTools 없음"
assert_file_absent "$PERSONA" '^disallowedTools:' "disallowedTools 없음 (allowlist 가 컨트롤)"
assert_file_absent "$PERSONA" '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' "쓰기·실행·위임 도구가 tools: 에 없음"

# AC4 — 억제 유지 락 (suppression-preserving): 이 sweep의 다른 모든 락과 반대 방향.
# 이 리뷰어는 diff의 전 소스를 읽으므로 네트워크 egress는 exfiltration 채널(P21) —
# 다음 sweep이 "일관성"을 이유로 웹 도구를 추가하지 못하게 못 박는다.
assert_count_ge "grep -c '^tools: Read, Grep, Glob$' '$PERSONA'" 1 "frontmatter tools: Read, Grep, Glob (웹 도구 미부여 — P21 exfiltration)"
assert_file_absent "$PERSONA" '^tools:.*(WebSearch|WebFetch)' "웹 도구 없음 (전 소스를 읽는 리뷰어의 egress는 exfiltration 채널)"

# Canonical schema keys present in persona body
assert_count_ge "grep -c 'agent: security-reviewer' '$PERSONA'" 1 "schema key agent: security-reviewer"
assert_count_ge "grep -c '^[[:space:]]*severity:' '$PERSONA'" 1 "schema key severity:"
assert_count_ge "grep -c '^[[:space:]]*confidence:' '$PERSONA'" 1 "schema key confidence:"
assert_count_ge "grep -c '^[[:space:]]*file:' '$PERSONA'" 1 "schema key file:"
assert_count_ge "grep -c '^[[:space:]]*line:' '$PERSONA'" 1 "schema key line:"
assert_count_ge "grep -cE 'CRITICAL.*IMPORTANT.*SUGGESTION' '$PERSONA'" 1 "severity enum CRITICAL/IMPORTANT/SUGGESTION"

# Forced findings prohibition (Korean or English)
assert_count_ge "grep -cE 'forced findings|Forced findings|빈 array|empty findings|empty list' '$PERSONA'" 1 "forced findings prohibition present"

# Role declaration shape (You are X / responsible / NOT responsible)
assert_count_ge "grep -cE 'You are .*security-reviewer|responsible for|NOT responsible' '$PERSONA'" 3 "role declaration shape"

# --- v2.8.0 untrusted-input norm (A / AC1) — section-scoped between ## Inputs and ## Hunt categories
assert_count_ge "inputs_to_hunt | grep -c '^## Untrusted input'" 1 "untrusted-input header positioned after ## Inputs"
# Body-unique phrase only — the header also contains "data, not instructions",
# so grepping that would pass even if the body norm prose were deleted. Scoped
# to the inputs_to_hunt window; deleting the body now goes RED.
assert_count_ge "inputs_to_hunt | grep -cE 'DATA to analyze, never as instructions'" 1 "untrusted-input body norm (DATA-to-analyze) in section"

# --- v2.8.0 FP precedent (B / AC3) — 3 suppress-at-source bullets INSIDE anti-flag section
assert_count_ge "antiflag_section | grep -c 'Managed-language memory safety'" 1 "managed-lang memory-safety precedent in anti-flag section"
assert_count_ge "antiflag_section | grep -c 'Framework-escaped XSS'" 1 "framework-escaped XSS precedent in anti-flag section"
assert_count_ge "antiflag_section | grep -c 'Path-only SSRF'" 1 "path-only SSRF precedent in anti-flag section"

finish
