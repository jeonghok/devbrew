#!/usr/bin/env bash
# spec-interview 는 사용자가 직접 부르는 진입 skill 이다(`/spec-distill:spec-interview`).
# AC1: frontmatter 에 user-invocable: 줄이 없다(메뉴에 보인다) / AC2: 기존 frontmatter 3키 보존 /
# AC3: 옛 command 파일 부재 + spec-review re-entry 참조 보존.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$PLUGIN_DIR/skills/spec-interview/SKILL.md"
REVIEW="$PLUGIN_DIR/skills/spec-review/SKILL.md"
SD="$PLUGIN_DIR"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# AC1 — frontmatter 블록 안에 user-invocable: 줄이 없다 (메뉴 노출).
# frontmatter 한정: 첫 '---'…두 번째 '---' 블록만 추출 후 검사. 양성 짝으로 그 블록에서
# name: 줄을 읽었는지 먼저 본다 — 추출이 비면 부재 검사는 공허하게 통과한다.
# 파이프 대신 command-sub+herestring으로 set -uo pipefail SIGPIPE 오탐 회피.
frontmatter="$(awk '/^---$/{c++} c==1' "$SKILL")"
grep -q '^name: spec-interview$' <<<"$frontmatter" \
    && ok "AC1(양성): frontmatter 블록을 읽었다" \
    || no "AC1(양성): frontmatter 블록에서 name: 을 못 읽었다 — 아래 부재 검사가 공허하다"
grep -q '^user-invocable:' <<<"$frontmatter" \
    && no "AC1: frontmatter 에 user-invocable: 줄이 남았다 — 메뉴에서 숨는다" \
    || ok "AC1: frontmatter 에 user-invocable: 줄이 없다 (사용자 호출 가능)"

# AC2 — 기존 frontmatter 키 보존 (의미 변경 없음)
grep -q '^name: spec-interview$' "$SKILL" \
    && ok "AC2: name preserved" \
    || no "AC2: name field broken"
grep -q '^description:' "$SKILL" \
    && ok "AC2: description preserved" \
    || no "AC2: description field broken"
grep -q '^cost_class: variable$' "$SKILL" \
    && ok "AC2: cost_class: variable (v0.12.0)" \
    || no "AC2: cost_class not variable"

# AC3 — 옛 command 는 alias 없이 사라졌고, spec-review 의 re-entry 참조는 산다
[ ! -e "$SD/commands/inter""view.md" ] \
    && ok "AC3: 옛 interview 명령 파일 부재 (skill 이 진입을 흡수)" \
    || no "AC3: 옛 interview 명령 파일이 남아 있다"
grep -q 'spec-interview' "$REVIEW" \
    && ok "AC3: spec-review re-entry reference preserved" \
    || no "AC3: spec-review re-entry reference MISSING"
finish
