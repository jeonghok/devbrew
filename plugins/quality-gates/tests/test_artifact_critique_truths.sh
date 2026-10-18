#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/*/SKILL.md plugins/quality-gates/README.md plugins/quality-gates/agents/artifact-adversarial.md
# AC2 — 문서 비평 skill 의 adversarial 도구 서술이 실제 tools: 와 맞고, README 에 지운 게이트 인용이 없다.
set -u
# test_guards_coverage_bidirectional.sh 가 읽는다 — 이 락이 여는 파일(리포 상대)을 낸다.
if [ "${1:-}" = "--emit-scanned" ]; then
  cd "$(dirname "$0")/../../.." || exit 1
  ls plugins/quality-gates/skills/*/SKILL.md
  printf '%s\n' plugins/quality-gates/README.md plugins/quality-gates/agents/artifact-adversarial.md
  exit 0
fi
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SK="$(ls "$ROOT"/plugins/quality-gates/skills/*/SKILL.md | xargs grep -l 'artifact-adversarial' | head -1)"
tools="$(sed -n 's/^tools: //p' "$ROOT/plugins/quality-gates/agents/artifact-adversarial.md")"
assert_eq "$tools" "Read, Grep, Glob" "artifact-adversarial 의 tools 는 읽기 셋뿐이다(전제)"
assert_not_contains "$(cat "$SK")" "egress 도구를 가지므로" "adversarial 이 egress 도구를 가진다는 거짓 문장이 없다"
assert_contains "$(cat "$SK")" "adversarial 은 egress 도구가 없다" "고친 문장이 실제 tools 를 말한다(양성 짝)"
assert_not_contains "$(cat "$ROOT/plugins/quality-gates/README.md")" "hard-review" "README 에 지운 게이트(authoring-time hard-review) 인용이 없다"
assert_contains "$(cat "$ROOT/plugins/quality-gates/README.md")" "iteration 마다 찍는 선택·제외·실패 공시 줄" "README 가 지금 있는 공시 줄을 말한다(양성 짝)"
finish
