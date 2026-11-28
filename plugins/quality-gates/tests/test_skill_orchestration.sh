#!/usr/bin/env bash
# SKILL.md orchestration verification (static grep approach).
#
# Wraps spec verification steps:
#   V2b: decision-question anchors + option labels (one pass — lowered-findings gate only)
#
# Protocol-shape coverage (dispatch ordering, proximity, fan-out membership) lives in
# tests/harness/test_skill_orchestration_behavior.sh and tests/test_one_pipeline_surface.sh.
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
assert_file_absent "$S" 'label: "(고치고 다시 돌기|지금 판정으로 끝내기|한 번 더 돌기)"' "iteration-gate options are gone (양성 짝: 위 V2b 의 낮춘 지적 질문 1개)"

finish
