#!/usr/bin/env bash
# guards: plugins/*/skills/*.md plugins/*/references/*.md plugins/*/agents/*.md shared/*/references/*.md shared/style/plain-language.md tools/plain-language/window_phrases.txt
#
# 질문 창 밖의 글을 가리키는 옛 문구가 모델이 읽는 글에 돌아오지 않는다(present-tradeoffs AC3).
#   부재    — 문구 목록(tools/plain-language/window_phrases.txt)의 문구마다 코퍼스의 어느 파일에도 없다.
#   양의 짝 — 옛 문구가 있던 자리마다 새 문장이 정확히 있다. 부재만 보면 그 절을 통째로 지워도 통과한다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PHRASES="tools/plain-language/window_phrases.txt"
RULE="shared/style/plain-language.md"
derive_git() {
  git -C "$ROOT" ls-files --cached --others --exclude-standard -- \
    'plugins/*/skills/*.md' 'plugins/*/references/*.md' 'plugins/*/agents/*.md' 'shared/*/references/*.md' \
    | grep -v '/tests/' | LC_ALL=C sort -u \
    | while IFS= read -r f; do [ -L "$ROOT/$f" ] || printf '%s\n' "$f"; done
  [ -L "$ROOT/$RULE" ] || printf '%s\n' "$RULE"
}
if [ "${1:-}" = "--emit-scanned" ]; then
  derive_git
  printf '%s\n' "$PHRASES"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
LIST="$(mktemp -t winph-list-XXXXXX)" || exit 1
trap 'rm -f "$LIST"' EXIT
derive_git > "$LIST"

# 코퍼스 — 도출 둘(목록 도출 · find 도출)이 같은 수를 낸다. 0 이면 공허한 통과다.
GIT_N="$(grep -c . "$LIST" || true)"
FIND_N="$(cd "$ROOT" && { find plugins shared -type f \( -path 'plugins/*/skills/*.md' -o -path 'plugins/*/references/*.md' -o -path 'plugins/*/agents/*.md' -o -path 'shared/*/references/*.md' \) ! -path '*/tests/*'; [ -f "$RULE" ] && [ ! -L "$RULE" ] && echo "$RULE"; } | sort -u | grep -c .)"
if [ "${GIT_N:-0}" -gt 0 ]; then ok "코퍼스 ${GIT_N}개(0 이 아니다)"; else no "코퍼스가 0개다 — 공허한 통과"; fi
assert_eq "$GIT_N" "$FIND_N" "코퍼스: 목록 도출과 find 도출이 같은 수를 낸다"

# 부재
[ -f "$ROOT/$PHRASES" ] && ok "문구 목록이 있다" || no "문구 목록이 없다: $PHRASES"
PH_N=0
PH_WANT=5   # 지금 목록의 문구 수 — 문구를 더하거나 빼면 이 수도 함께 고친다
while IFS= read -r phrase || [ -n "$phrase" ]; do   # 끝 개행 없는 마지막 줄도 읽는다
  phrase="$(printf '%s' "$phrase" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"   # CR · 앞뒤 공백을 턴다(measure_questions.py 와 같다)
  case "$phrase" in ''|'#'*) continue ;; esac
  PH_N=$((PH_N + 1))
  hits="$(cd "$ROOT" && while IFS= read -r f; do grep -nF -- "$phrase" "$f" | sed "s|^|${f}:|"; done < "$LIST" | cut -c1-120)"
  if [ -z "$hits" ]; then ok "부재: 「${phrase}」가 코퍼스에 없다"
  else no "부재: 「${phrase}」가 코퍼스에 있다 — $(printf '%s' "$hits" | head -3 | tr '\n' ' ')"; fi
done < "$ROOT/$PHRASES"
assert_eq "$PH_N" "$PH_WANT" "문구 목록: 읽은 문구 수가 지금 목록의 수(${PH_WANT})와 같다 — 줄면 부재 검사가 그만큼 빈다"

# 양의 짝 — 파일 · 글자(한 번 이상)
has() {   # has <파일> <글자>
  if [ ! -f "$ROOT/$1" ]; then no "양의 짝: $1 파일이 없다"; return; fi
  if grep -qF -- "$2" "$ROOT/$1"; then ok "양의 짝: $1 에 「${2}」"; else no "양의 짝: $1 에 「${2}」가 없다"; fi
}
LEFT='제안 선택지의 설명은 「얻음: <제안 이유> · 내줌:'
BODY='질문 본문은 엔진의 질문 재료가 낸 「본문」 · 「상태」 · 「덧줄」 · 「전문」 줄을 그대로 싣고'
FIN=plugins/spec-distill/skills/pm-interview/references/finishing.md
has shared/style/plain-language.md '추천이 있는 질문은 질문 창만 보고 고를 수 있게 쓴다 — 질문 위 글은 안 보일 수 있다.'
has shared/docreview/references/reviewing-document.md '질문마다 엔진의 질문 재료(`docreview_state.py ask-material`) 한 묶음을 쓴다.'
has plugins/spec-distill/references/proceed-gate.md '질문 본문에는 결정 하나, 경고 줄 하나, 「전문: <경로>」 한 줄을 둔다.'
has plugins/spec-distill/references/proceed-gate.md "$LEFT"
has "$FIN" '"신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 이 일을 어떻게 진행할까?"'
has "$FIN" '정본(`proceed-gate.md`)의 본문 규칙대로'
has "$FIN" "$LEFT"
has plugins/spec-distill/skills/pm-interview/references/saturation.md '권하는 이유는 그 선택지의 얻음에 담는다'
has plugins/spec-distill/references/redecompose.md '"다시 나눌 표의 신호 셋 — 덩어리 <n> · 파일 영역 <n> · 원문 갈래 <n>. 어떻게 할까?"'
has plugins/spec-distill/skills/spec-review/SKILL.md '그 이유는 그 선택지의 얻음에 담는다'
has plugins/spec-distill/skills/spec-review/SKILL.md "$BODY"
has plugins/spec-distill/skills/reviewing-brief/SKILL.md "$BODY"
has plugins/spec-distill/skills/request-framing/SKILL.md "$BODY"
has plugins/spec-distill/skills/request-framing/SKILL.md "$LEFT"
has plugins/quality-gates/skills/quality-pipeline/SKILL.md '전부 되올리려면 기타 칸에 「전부」'
has plugins/quality-gates/skills/quality-pipeline/SKILL.md '전문: <$RV/synth.out 의 경로>'
has plugins/quality-gates/skills/artifact-critique/SKILL.md '권하는 이유는 「실행」의 얻음에 담는다.'
finish
