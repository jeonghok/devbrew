#!/usr/bin/env bash
# AC3 — handoff_incomplete fires when TL;DR / Implicit / Deferred 중 하나라도 비어있음.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# AC3: 3 sub-section labels referenced in agent
for label in "TL;DR" "Implicit context" "Deferred to plan"; do
  grep -qF "$label" "$AGENT" \
    && ok "AC3: sub-section '$label' referenced in agent" \
    || no "AC3 sub-section '$label' not in agent"
done

# AC3: empty-subsection 검출 로직 명시
grep -qE '비어.*있|empty|미작성' "$AGENT" \
  && ok "AC3: empty-subsection detection language present" \
  || no "AC3 empty-subsection detection missing"
finish
