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
