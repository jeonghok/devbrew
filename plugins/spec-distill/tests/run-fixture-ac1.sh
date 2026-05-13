#!/usr/bin/env bash
# AC1 verification — drafting-spec Mode A가 interview-transcript-bbda.md fixture를
# 받아 spec.md frontmatter `locked_decisions:`에 정확히 3개 (LD1/LD2/LD3) 생성하는지 검증.
#
# 이 스크립트는 *contract-level fixture replay* — LLM 호출 없이 fixture의 expected
# output을 직접 parse + assert. LLM 호출은 V12 (E2E manual replay)에서만.
#
# Mock/stub 전략 (round 3 advisory #3 — plan 단계에서 명시):
# 본 스크립트는 Mode A의 *실제 dispatch 없이* fixture에 명시된 expected output
# (Expected drafting-spec Mode A output 섹션)을 contract로 검증. Mode A 실제 동작은
# V12에서 한 번만 manual replay로 verify.

set -e -o pipefail

FIXTURE="plugins/spec-distill/tests/fixtures/interview-transcript-bbda.md"

# Step 1: fixture 존재 + pending_locked_decisions 정확히 3개 entry 보유 검증
test -f "$FIXTURE"

# Extract pending_locked_decisions list from fixture's state.local.md excerpt
# (block lives inside a fenced ```yaml code block; use closing fence as end delimiter)
COUNT=$(sed -n '/^pending_locked_decisions:/,/^```$/p' "$FIXTURE" \
        | grep -cE "^[[:space:]]*-[[:space:]]*id:[[:space:]]*LD")
if [ "$COUNT" -ne 3 ]; then
  echo "FAIL: expected 3 LDs in fixture pending_locked_decisions, got $COUNT" >&2
  exit 1
fi

# Step 2: source_path 검증 — b/b/d 만 (a는 LD 없음)
PATHS=$(sed -n '/^pending_locked_decisions:/,/^```$/p' "$FIXTURE" \
        | grep -E "^[[:space:]]*source_path:" \
        | awk -F: '{gsub(/[[:space:]]/, "", $2); print $2}' \
        | sort | tr -d '\n')
if [ "$PATHS" != "bbd" ]; then
  echo "FAIL: expected source_path sequence 'bbd', got '$PATHS'" >&2
  exit 1
fi

# Step 3: round 4 (path a)가 LD를 생성하지 않았는지 확인 — fixture 본문 grep
if grep -qE "^### Round 4.*locked=true" "$FIXTURE"; then
  echo "FAIL: round 4 (path a) should be locked=false but fixture marks locked=true" >&2
  exit 1
fi

echo "OK: AC1 fixture contract verified (3 LDs, b/b/d paths)"
