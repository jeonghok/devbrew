#!/usr/bin/env bash
# guards: shared/style/plain-language.md plugins/*/skills/*/SKILL.md shared/tests/plain_language_block.py
#
# 「사람에게 쓰는 글」 블록 동일성 — 대상은 두 글롭에서 도출한다(목록을 손으로 적지 않는다).
# 새 SKILL.md · 명령 파일이 블록 없이 들어오면 RED 다. 판정은 plain_language_block.py 가 한다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
derive_git() {
  git -C "$ROOT" ls-files --cached --others --exclude-standard -- \
    'plugins/*/skills/*/SKILL.md' 'plugins/*/commands/*.md' | LC_ALL=C sort -u
}
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' shared/style/plain-language.md shared/tests/plain_language_block.py
  derive_git
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
LIST="$(mktemp -t plb-list-XXXXXX)" || exit 1
RES="$(mktemp -t plb-res-XXXXXX)" || { rm -f "$LIST"; exit 1; }
trap 'rm -f "$LIST" "$RES"' EXIT
derive_git > "$LIST"
# 양의 짝 — git 도출과 find 도출이 같은 수를 낸다(집합이 아니라 수를 비교한다 — git 이 조용히 0 을 내는 경우를 막는다).
FIND_N="$(cd "$ROOT" && find plugins -path '*/skills/*/SKILL.md' -o -path 'plugins/*/commands/*.md' | grep -c .)"
GIT_N="$(grep -c . "$LIST" || true)"
assert_eq "$GIT_N" "$FIND_N" "대상 도출: git 과 find 가 같은 수를 낸다"
# 정본의 예외 문장 — 부른 skill(예: superpowers brainstorming)이 메시지 모양을 정한 대화에서는 그 skill, 이 블록은 낱말에만.
assert_file_grep "$ROOT/shared/style/plain-language.md" '부른 skill 이 메시지 모양을 정한 대화\(예: brainstorming\)에서는 그 skill 을 따르고, 이 블록은 낱말에만 적용한다\.' "정본: 부른 skill 이 메시지 모양을 정한 대화의 예외 문장"
CANON="$(cat "$ROOT/shared/style/plain-language.md")"
NEW='- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일. 할 일은 기본 하나다 — 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다. 할 일이 없으면 없다고 쓴다. 커밋·PR 본문에는 이 순서를 적용하지 않는다.'
assert_eq "$(grep -cxF -- "$NEW" "$ROOT/shared/style/plain-language.md")" "1" "AC1: 정본 순서 줄이 새 문장 그대로(양)"
assert_not_contains "$CANON" '맨 끝에 사용자가 할 일 하나.' "AC1: 정본에 옛 「할 일 하나」 가 없다(음)"
assert_contains "$CANON" '확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.' "N13: 없음과 확인 못 함을 가른다(양)"
# 모든 skill 본문에 옛 꼬리 「끝에 할 일 하나)」 가 없다(음) — 목록은 글롭으로 도출하고, 양의 짝으로 find 수와 같은지 본다.
SK_N=0
SK_HIT=0
for sk in "$ROOT"/plugins/*/skills/*/SKILL.md; do
  [ -f "$sk" ] || continue
  SK_N=$((SK_N + 1))
  if grep -qF -- '끝에 할 일 하나)' "$sk"; then SK_HIT=$((SK_HIT + 1)); fi
done
SK_FIND="$(cd "$ROOT" && find plugins -path '*/skills/*/SKILL.md' | grep -c .)"
assert_eq "$SK_N" "$SK_FIND" "R9: SKILL.md 글롭 도출 수가 find 수와 같다(양의 짝)"
assert_eq "$SK_HIT" "0" "R9: 어떤 SKILL.md 에도 옛 꼬리 「끝에 할 일 하나)」 가 없다(음)"
assert_file_grep "$ROOT/plugins/spec-distill/skills/spec-review/SKILL.md" '끝에 할 일\(기본 하나 — 여럿이거나 병렬이면 밝힌다\)' "R9: spec-review 계획 세션 넘김 줄이 새 꼬리를 쓴다(양)"
python3 "$ROOT/shared/tests/plain_language_block.py" "$ROOT" "$LIST" > "$RES" 2>&1
rc=$?
assert_eq "$rc" "0" "판정 모듈이 rc 0 으로 끝났다"
while IFS= read -r line; do
  case "$line" in
    "ok "*) ok "${line#ok }" ;;
    "no "*) no "${line#no }" ;;
    *) no "판정 모듈이 알 수 없는 줄을 냈다: $line" ;;
  esac
done < "$RES"
finish
