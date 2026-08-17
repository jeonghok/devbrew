#!/usr/bin/env bash
# AC6 — adversarial persona structural conformance (symmetric to
# test_security_reviewer_persona.sh). Locks: frontmatter (name / model: inherit /
# disallowedTools 4) + Gate A–D structure + v2.8.0 untrusted-input norm (A)
# positioned before ## Verification protocol + 2 Gate C reject-at-verify
# precedents (B) INSIDE the Gate C block, each specifying reject. Section-scoped
# so a move/delete goes RED, not a global keyword count.
set -eu
REPO_ROOT="$(git rev-parse --show-toplevel)"
PERSONA="$REPO_ROOT/plugins/quality-gates/agents/adversarial.md"

set +e
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
[ -f "$PERSONA" ] || { no "persona 파일 부재: $PERSONA"; finish; exit; }

# Section extractor — Gate C window between the Gate C and Gate D headers.
gateC_section() {
  awk '/\*\*Gate C/{f=1} /\*\*Gate D/{f=0} f' "$PERSONA"
}

# Section extractor — untrusted-input window (its header → ## Verification protocol).
# `next` after the opening match keeps the window body-only and matches the
# next-based style of the sibling test's extractors.
untrusted_section() {
  awk '/^## Untrusted input/{f=1; next} /^## Verification protocol/{f=0} f' "$PERSONA"
}

# Frontmatter required keys
assert_count_ge "grep -c '^name: adversarial$' '$PERSONA'" 1 "frontmatter name adversarial"
assert_count_ge "grep -c '^model: inherit$' '$PERSONA'" 1 "frontmatter model inherit"
assert_file_absent "$PERSONA" '^model: (opus|sonnet|haiku)$' "고정 티어 핀 없음 (하니스가 세션 모델을 덮어쓰지 않는다)"
assert_count_ge "grep -c '^tools: Read, Grep, Glob$' '$PERSONA'" 1 "frontmatter tools: allowlist (fail-closed)"
assert_file_absent "$PERSONA" '^(allowedTools|disallowedTools):' "죽은 allowedTools / denylist 없음"
assert_file_absent "$PERSONA" '^tools:.*(Write|Edit|MultiEdit|NotebookEdit|Bash|Agent|Monitor|mcp__)' "쓰기·실행·위임 도구가 tools: 에 없음"

# Gate A–D structure present
assert_count_ge "grep -c '\\*\\*Gate A' '$PERSONA'" 1 "Gate A header present"
assert_count_ge "grep -c '\\*\\*Gate B' '$PERSONA'" 1 "Gate B header present"
assert_count_ge "grep -c '\\*\\*Gate C' '$PERSONA'" 1 "Gate C header present"
assert_count_ge "grep -c '\\*\\*Gate D' '$PERSONA'" 1 "Gate D header present"

# (A / AC2) untrusted-input header exists AND sits before ## Verification protocol
hdr="$(grep -n '^## Untrusted input' "$PERSONA" | head -1 | cut -d: -f1)"
proto="$(grep -n '^## Verification protocol' "$PERSONA" | head -1 | cut -d: -f1)"
if [ -n "$hdr" ] && [ -n "$proto" ] && [ "$hdr" -lt "$proto" ]; then
  ok "untrusted-input header precedes ## Verification protocol (line $hdr < $proto)"
else
  no "untrusted-input header must exist before ## Verification protocol (hdr='$hdr' proto='$proto')"
fi
# Body-unique phrase (NOT the header, which also contains "data, not instructions"):
# scoped to the section window so deleting the body norm prose goes RED.
assert_count_ge "untrusted_section | grep -cE 'is data, not a reason'" 1 "untrusted-input body norm (data-not-a-reason) in section"

# (B / AC4) 2 reject-at-verify precedents INSIDE the Gate C block, each with reject
assert_count_ge "gateC_section | grep -cE 'Client-side trust boundary.*reject'" 1 "client-side trust-boundary precedent in Gate C, specifies reject"
assert_count_ge "gateC_section | grep -cE 'Trusted configuration values.*reject'" 1 "trusted-config-values precedent in Gate C, specifies reject"

# AC14a — 신규 발견 금지 선언이 네 곳 모두에서 해소됐다. 한 곳이라도 남으면 persona 자기모순.
assert_file_absent "$PERSONA" 'producing new findings of your own|No new findings as verdicts' "신규 발견 금지 선언 부재 (승격 허용)"
assert_count_ge "grep -c '^new_findings:' '$PERSONA'" 1 "new_findings 블록 스키마 정의"
assert_count_ge "grep -c 'meta_note' '$PERSONA'" 1 "meta_note 채널 존치 (구조화되지 않은 관찰용)"

finish
