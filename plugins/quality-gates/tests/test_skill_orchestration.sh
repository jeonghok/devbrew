#!/usr/bin/env bash
# v1.32.1 SKILL.md orchestration verification (static grep approach).
#
# Wraps spec verification steps:
#   V2b: decision-question anchors + option labels (one pass — lowered-findings gate only)
#
# V2a (Review gate → Runtime gate first-mention line order) was REMOVED in
# PR4b: 한 파이프라인에는 별도 dispatch 지점으로서의 "Runtime gate" 가 없다 —
# 순서 비교 자체가 무의미해졌다(대상 소멸). Protocol-shape coverage for the
# surviving skeleton lives in tests/harness/test_skill_orchestration_behavior.sh
# and tests/test_one_pipeline_surface.sh.
#
# V7 was REMOVED in v1.32.1 (C6 atomicity, spec §5.1/§5.6.9): the
# `grep -c '\bPASS\b'` token never appeared in SKILL.md, so V7's
# negative-assertion path was unreachable (tautological PASS). Replaced
# by tests/harness/test_skill_orchestration_behavior.sh, which asserts
# the orchestration protocol-shape (dispatch ordering, proximity, and
# fan-out membership) without any unreachable code paths.
#
# Exit 0 if all pass; non-zero with diagnostic on first failure.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
S="$ROOT/quality-gates/skills/quality-pipeline/SKILL.md"

if [[ ! -f "$S" ]]; then
  echo "FAIL: SKILL.md not found at $S"
  exit 1
fi

# ============== V2b: Context anchors + option labels (AC6/7) ==============
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
# 한 실행은 한 번 지난다 — 고치기 반복의 결정 질문(`qg 반복 N: <ask-line>`)은 없고, 남은 결정 질문은
# 낮춘 지적 게이트 하나다. 앵커는 글자 그대로 찾는다(index) — 꺾쇠를 정규식으로 읽지 않는다.
# Prose mentions and meta-comments outside `question:` lines are allowed.
lowered_q=$(awk '/^[[:space:]]*question:/ && index($0, "재비판이 심각도를 낮춘 지적 <n>개 가운데") { c++ } END { print c+0 }' "$S")
if [[ "$lowered_q" -ne 1 ]]; then
  echo "FAIL V2b uniqueness: lowered-findings question appears in $lowered_q question: lines (expected 1)"
  exit 1
fi
iter_q=$(awk '/^[[:space:]]*question:/ && index($0, "qg 반복 N: <ask-line>") { c++ } END { print c+0 }' "$S")
if [[ "$iter_q" -ne 0 ]]; then
  echo "FAIL V2b: iteration-gate question 'qg 반복 N: <ask-line>' still appears in $iter_q question: lines (expected 0)"
  exit 1
fi
echo "PASS V2b (lowered-findings question: 1 · iteration-gate question: 0)"
assert_file_absent "$S" 'label: "(고치고 다시 돌기|지금 판정으로 끝내기|한 번 더 돌기)"' "iteration-gate options are gone (위 양성 짝)"

# V7 removed in v1.32.1 (see header). Runtime NEEDS_RESOLUTION decision
# context (P21 / 'Runtime verifier needs') was removed in PR4b along with
# the decision tool it anchored (대상 소멸). Protocol-shape coverage moved to
# tests/harness/test_skill_orchestration_behavior.sh.

finish
