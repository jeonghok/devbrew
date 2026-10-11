#!/usr/bin/env bash
# test_removed_plan_arg.sh — `--plan` 은 제거 안내 한 줄을 내고 끝난다(AC25). ① 이 지운 `--pr-url` 과 같은 길로 간다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
trap 'cd / && rm -rf "$R"' EXIT
git init -q -b main "$R" && git -C "$R" config user.email t@t && git -C "$R" config user.name t
( cd "$R" && echo x > a && git add a && git -c commit.gpgsign=false commit -qm a ) || exit 1

run_setup() {   # run_setup <args…> → "<rc>|<stdout+stderr>"
  local out rc
  out=$(cd "$R" && env -u DEVBREW_QUALITY_GATES_DISABLE CLAUDE_CODE_SESSION_ID=abcdefgh1234 bash "$SETUP" "$@" 2>&1); rc=$?
  printf '%s|%s' "$rc" "$out"
}

plan=$(run_setup --plan docs/x.md)
pr=$(run_setup --pr-url https://example.invalid/pr/1)
assert_eq "${plan%%|*}" "${pr%%|*}" "AC25: --plan 의 종료 코드가 제거된 --pr-url 과 같다"
assert_contains "${plan#*|}" "--plan" "AC25: 안내가 --plan 을 이름으로 말한다"
assert_not_contains "${plan#*|}" "Plan file:" "AC25: --plan 값을 쓰지 않는다"
assert_not_contains "${plan#*|}" "계획 파일" "AC25: --plan 값을 쓰지 않는다(한국어 배너 줄도 없다)"
assert_not_contains "${plan#*|}" "docs/x.md" "AC25: --plan 의 값이 출력 어디에도 없다"
assert_eq "$(printf '%s\n' "${plan#*|}" | grep -c -- '--plan')" "1" "AC25: 안내는 한 줄이다"
hint=$(sed -n 's/^argument-hint: //p' "$PLUGIN_ROOT/commands/qg.md")
[ -n "$hint" ] && ok "qg.md 에 argument-hint 줄이 있다" || no "qg.md argument-hint 줄을 찾지 못했다"
assert_not_contains "$hint" "--plan" "AC25: qg.md argument-hint 에 --plan 이 없다"
finish
