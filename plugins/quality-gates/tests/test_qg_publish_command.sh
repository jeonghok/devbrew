#!/usr/bin/env bash
# test_qg_publish_command.sh — command body: dispatches the skill, holds no gh.
#
# 2026-08-22: `allowed-tools:` frontmatter key removed repo-wide from commands —
# 헤드리스 실측 5변형(`Read`만 선언해도 Bash 실행됨)이 그 선언은 아무것도 집행하지
# 않음을 확정했다(CLAUDE.md 참고). 이 파일이 재던 두 단언(Skill 존재·gh 부재)의
# 대상을 그 죽은 선언에서 명령 **본문**으로 옮긴다 — 본문은 실제로 읽히고 실행된다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg-publish.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

# (1) command body actually invokes the skill via the Skill(...) call form.
# 아래 (3)의 'publishing-pr-understanding' 언급 검사보다 더 강하다 — (3)은 그
# 이름이 산문 어디에든 나오면 통과하지만, 이 검사는 실제 호출 표기까지 요구한다.
# (3)이 통과해도 이건 실패할 수 있으므로 중복이 아니다.
grep -qF 'Skill("quality-gates:publishing-pr-understanding")' "$CMD" \
  && ok "command body invokes Skill(quality-gates:publishing-pr-understanding)" \
  || no "no Skill(...) call form found in command body"

# (2) command body holds no direct gh invocation. word-바운더리 + 호출-모양
# 매칭(공백 또는 '(' 뒤따름)이라 "through"/"right" 같은 영단어 부분문자열이나 이
# 파일 자체의 고지문("`gh`를 직접 호출하지 않는다" — 백틱이 뒤따름, 공백/괄호
# 아님)에 오탐하지 않는다.
if grep -qiE '\bgh[[:space:](]' "$CMD"; then
  no "gh leaked into command body"
else
  ok "command body holds no gh"
fi

grep -qiE 'publishing-pr-understanding' "$CMD" && ok "invokes publish skill" || no "does not invoke publish skill"
grep -qiE 'dry-run' "$CMD" && ok "documents --dry-run" || no "no --dry-run mention"
finish
