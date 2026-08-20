#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md
#
# 모든 `plugins/*/skills/*/SKILL.md` 가 `references/<file>.md` 형태로 가리키는
# 경로가 실제로 존재하는가.
#
# 왜 필요한가 (Task 31, 무게 감축): quality-pipeline SKILL.md 의 `## Runtime gate`
# 절차를 조건부 로드를 위해 `references/runtime-gate.md` 로 쪼갰다. 이 분리가
# 만드는 새 fail-open을 지금까지 아무 테스트도 안 지킨다 — 나중에 그 참조 파일이
# 삭제되거나 이름이 바뀌면 SKILL.md 는 존재하지 않는 파일을 가리키게 되고,
# Runtime 게이트를 실제로 돌 때 모델이 Read 할 대상이 없어 절차 전문이 조용히
# 사라진다. 정적 문자열이 어딘가에 있다는 것과 그 문자열이 **가리키는 파일이
# 실재한다**는 것은 다른 사실이다 — 이 락은 후자만 잰다.
#
# 대상은 열거가 아니라 git 이 추적하는 SKILL.md 전부에서 **도출**한다 — 새
# 스킬이나 새 참조 파일이 생겨도 자동으로 대상이 된다. 포인터는 마크다운 링크
# (`[text](references/x.md#anchor)`) · 백틱 코드 스팬(`` `references/x.md` ``) ·
# 코드블록 안의 전체 경로(`.../skills/<skill>/references/x.md`) ·
# `${CLAUDE_PLUGIN_ROOT}/.../references/x.md` 설치-경로 표기까지 전부 같은 정규식
# `references/[A-Za-z0-9_./-]+\.md` 로 잡는다 — 문자 클래스가 `` ` ``·`)`·`#`·공백을
# 포함하지 않으므로 그 문자들에서 자연히 끊긴다. 매치된 접미사를 그 SKILL.md 가
# 있는 디렉터리 기준 **상대경로**로 재해석해 존재를 검사한다(설치본 접두사가
# 붙어 있어도 마지막 `references/...` 접미사만 취하므로 무관하다).
#
# `0 checked / 0 missing` 은 "소실 없음"이 아니라 "추출이 아무것도 못 봤다"다 —
# 코퍼스가 비어있지 않은데 포인터를 하나도 못 찾으면 이 락 자체가 무의미해지므로
# 큰 소리로 FAIL 한다(정규식이 조용히 깨지는 것과 "정말 포인터가 없다"를 구별
# 못 하면, 이 락은 늘 GREEN인 이빨 없는 락이 된다).
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

REF_RE='references/[A-Za-z0-9_./-]+\.md'

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 이 락이
# 실제로 훑은 코퍼스(git 추적 SKILL.md 전부)를 낸다.
CORPUS="$(git ls-files -- 'plugins/*/skills/*/SKILL.md')"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  exit 0
fi

corpus_n=0
while IFS= read -r f; do
  [ -n "$f" ] && corpus_n=$((corpus_n + 1))
done < <(printf '%s\n' "$CORPUS")
if [ "$corpus_n" -lt 1 ]; then
  no "pointer: git ls-files 가 SKILL.md 를 0개 도출했다 — 이 검사 자체가 vacuous 하다"
  finish
  exit $?
fi
ok "pointer: SKILL.md 코퍼스 ${corpus_n}개 도출 (vacuous 아님)"

checked=0
missing=0

while IFS= read -r skill_md; do
  [ -n "$skill_md" ] || continue
  skill_dir="$(dirname -- "$skill_md")"
  while IFS= read -r ref; do
    [ -n "$ref" ] || continue
    checked=$((checked + 1))
    target="$skill_dir/$ref"
    if [ -f "$target" ]; then
      ok "pointer: $skill_md → $ref (존재: $target)"
    else
      no "pointer: $skill_md → $ref 를 가리키지만 그 경로에 파일이 없다 ($target)"
      missing=$((missing + 1))
    fi
  done < <(grep -oE -- "$REF_RE" "$skill_md" | sort -u)
done < <(printf '%s\n' "$CORPUS")

if [ "$checked" -eq 0 ]; then
  no "pointer: 코퍼스 ${corpus_n}개 SKILL.md 전체에서 references/*.md 포인터를 0개 발견 — 추출이 실패했다 (0 checked/0 missing 은 '없음'이 아니라 '안 봤다')"
else
  assert_eq "$missing" "0" "pointer: 대조 ${checked}건 / 소실 ${missing}건"
fi

finish
