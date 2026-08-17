#!/usr/bin/env bash
# AC6 회귀 가드 — conducting-interview는 내부 전용 스킬(user-invocable: false).
# AC1: user-invocable: false 존재 / AC2: 기존 frontmatter 3키 보존 /
# AC3: command dispatch + reviewing-spec re-entry 프로그램 호출 경로 보존.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$PLUGIN_DIR/skills/conducting-interview/SKILL.md"
CMD="$PLUGIN_DIR/commands/interview.md"
REVIEW="$PLUGIN_DIR/skills/reviewing-spec/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# AC1 — user-invocable: false가 frontmatter 블록 안에 존재 (메뉴 은닉).
# frontmatter 한정: 첫 '---'…두 번째 '---' 블록만 추출 후 검사. 본문(markdown)에
# 우연히 같은 문자열이 있어도 통과하지 않도록 (menu-visibility를 실제 제어하는
# 위치에 키가 있을 때만 PASS). 파이프 대신 command-sub+herestring으로
# set -uo pipefail SIGPIPE 오탐 회피.
frontmatter="$(awk '/^---$/{c++} c==1' "$SKILL")"
grep -q '^user-invocable: false$' <<<"$frontmatter" \
    && ok "AC1: user-invocable: false present (frontmatter-scoped)" \
    || no "AC1: user-invocable: false MISSING from frontmatter"

# AC2 — 기존 frontmatter 키 보존 (의미 변경 없음)
grep -q '^name: conducting-interview$' "$SKILL" \
    && ok "AC2: name preserved" \
    || no "AC2: name field broken"
grep -q '^description:' "$SKILL" \
    && ok "AC2: description preserved" \
    || no "AC2: description field broken"
grep -q '^cost_class: variable$' "$SKILL" \
    && ok "AC2: cost_class: variable (v0.12.0)" \
    || no "AC2: cost_class not variable"

# AC3 — 프로그램 호출 경로 보존 (메뉴만 숨고 dispatch는 살아있음)
grep -q 'Skill conducting-interview' "$CMD" \
    && ok "AC3: command dispatch line preserved" \
    || no "AC3: command dispatch line MISSING"
grep -q 'conducting-interview' "$REVIEW" \
    && ok "AC3: reviewing-spec re-entry reference preserved" \
    || no "AC3: reviewing-spec re-entry reference MISSING"
finish
