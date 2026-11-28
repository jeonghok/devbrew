#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*/SKILL.md plugins/quality-gates/agents/artifact-adversarial.md
# AC2 — 문서 비평 skill 의 adversarial 도구 서술이 실제 tools: 와 맞다.
set -u
# test_guards_coverage_bidirectional.sh 가 읽는다 — 이 락이 여는 파일(리포 상대)을 낸다.
if [ "${1:-}" = "--emit-scanned" ]; then
  cd "$(dirname "$0")/../../.." || exit 1
  ls plugins/quality-gates/skills/*/SKILL.md
  printf '%s\n' plugins/quality-gates/agents/artifact-adversarial.md
  exit 0
fi
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SK="$(ls "$ROOT"/plugins/quality-gates/skills/*/SKILL.md | xargs grep -l 'artifact-adversarial' | head -1)"
tools="$(sed -n 's/^tools: //p' "$ROOT/plugins/quality-gates/agents/artifact-adversarial.md")"
assert_eq "$tools" "Read, Grep, Glob" "artifact-adversarial 의 tools 는 읽기 셋뿐이다(전제)"
# R2a 계획 3 Task 12(미룸): 옛 음성 검사(`egress 도구를 가지므로` 고정 문구 부재)는 그 한 문구만 봤다 — 다른 말로
# 쓴 거짓 서술은 통과했다. 지금은 SKILL 이 인용한 `tools: …` 를 실제 tools 줄과 대조한다(인용이 실제와 다르면 RED).
assert_contains "$(cat "$SK")" "\`tools: ${tools}\`" "egress 문장이 adversarial 의 실제 tools 줄을 그대로 인용한다"
bad_quotes="$(grep -oE '`tools: [^`]*`' "$SK" | grep -vxF "\`tools: ${tools}\`")"
assert_eq "$bad_quotes" "" "SKILL 이 인용한 tools 줄 가운데 실제 tools 줄과 다른 것이 없다(음성 — 위 양성 단언이 짝)"
assert_contains "$(cat "$SK")" "adversarial 은 egress 도구가 없다" "고친 문장이 실제 tools 를 말한다(양성 짝)"
# E2c 는 경로 문자열을 고정한다(inode 아님 — E2c 의 TOCTOU 한계 절) — 「그 파일로 고정」은 그보다 큰 약속이다.
assert_file_absent "$SK" '그 파일로 고정' "egress 문장은 경로를 고정한다고 말한다(미룸)"
assert_contains "$(cat "$SK")" "E2c 가 인가한 그 경로로 읽게" "egress 문장 양성 짝(그 경로로)"
finish
