#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md plugins/*/skills/*/references/*.md
#
# 모든 `plugins/*/skills/*/SKILL.md` 가 `references/<file>.md` 형태로 가리키는
# 경로가 실제로 존재하는가(정방향) — 그리고 그 역방향: 모든 git-tracked
# `references/*.md` 가 어떤 SKILL.md 로부터든 가리켜지는가(고아 없음).
#
# 왜 필요한가 (Task 31, 무게 감축): quality-pipeline SKILL.md 의 `## Runtime gate`
# 절차를 조건부 로드를 위해 `references/runtime-gate.md` 로 쪼갰다. 이 분리가
# 만드는 새 fail-open을 지금까지 아무 테스트도 안 지킨다 — 나중에 그 참조 파일이
# 삭제되거나 이름이 바뀌면 SKILL.md 는 존재하지 않는 파일을 가리키게 되고,
# Runtime 게이트를 실제로 돌 때 모델이 Read 할 대상이 없어 절차 전문이 조용히
# 사라진다. 정적 문자열이 어딘가에 있다는 것과 그 문자열이 **가리키는 파일이
# 실재한다**는 것은 다른 사실이다 — 이 락은 후자만 잰다.
#
# 왜 역방향도 필요한가 (Task 31 fix round 1, F6): 정방향만 재면 **고아**
# (아무 SKILL.md 도 안 가리키는 references/*.md)는 안 잡힌다 — 이 branch 의
# 근본 요청("중복된 공통 부분이 stale 되지 않게 통합 관리")이 정확히 막으려는
# 회귀는, 나중에 누군가 references/*.md 절차를 SKILL.md 본문으로 되접으면서
# 참조 파일 삭제를 잊는 것이다. 그러면 죽은 산문 복제본이 모든 설치본에
# 영구히 실리고, 20줄 중복 락(별건 태스크)의 코퍼스는 `plugins/**` 라서 두
# 사본 다 "정당하게 있다"로 보여 그 락도 못 잡는다.
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
# 실제로 훑는 두 코퍼스(git 추적 SKILL.md 전부 + git 추적 references/*.md 전부)를
# 낸다 — 정방향만 읽던 시절과 달리 이제 이 락은 후자도 실제로 읽으므로(F6),
# 선언(guards: 두 글롭)과 실측이 여기서 같이 맞아야 한다.
CORPUS="$(git ls-files -- 'plugins/*/skills/*/SKILL.md')"
REF_CORPUS="$(git ls-files -- 'plugins/*/skills/*/references/*.md')"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  printf '%s\n' "$REF_CORPUS"
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

# ── 역방향(F6): SKILL.md 가 안 가리키는 references/*.md — 고아 ────────────
#
# 이 락의 REF_RE 는 매치된 문자열에서 "references/" 이전 접두(경로·
# ${CLAUDE_PLUGIN_ROOT} 등)를 전부 버리므로, 정방향에서 모든 포인터는 이미
# **그 포인터를 담은 SKILL.md 자신의 디렉터리 기준** `references/<name>.md`
# 로만 해석된다(위 68-79행). 역방향도 같은 해석을 대칭으로 적용한다 — 어떤
# references/*.md 파일이 자기 소유 SKILL.md(같은 skills/<skill>/ 디렉터리) 의
# 포인터 목록 안에 있는가.
#
# 코퍼스 자체가 0 이면(추출 실패든 정말 없든) 아래 대조가 공허해지므로,
# 정방향과 같은 규율로 무조건 loud FAIL 한다 — "역방향 검사 자체가 vacuous
# 하다"를 "고아 없음"으로 읽지 않는다.
ref_corpus_n=0
while IFS= read -r f; do
  [ -n "$f" ] && ref_corpus_n=$((ref_corpus_n + 1))
done < <(printf '%s\n' "$REF_CORPUS")
if [ "$ref_corpus_n" -lt 1 ]; then
  no "orphan: git ls-files 가 references/*.md 를 0개 도출했다 — 역방향 검사 자체가 vacuous 하다"
  finish
  exit $?
fi
ok "orphan: references/*.md 코퍼스 ${ref_corpus_n}개 도출 (vacuous 아님)"

ref_checked=0
orphans=0
while IFS= read -r reffile; do
  [ -n "$reffile" ] || continue
  ref_checked=$((ref_checked + 1))
  skill_dir="${reffile%/references/*}"
  owner_skill="$skill_dir/SKILL.md"
  want="references/$(basename -- "$reffile")"
  if [ -f "$owner_skill" ] && grep -oE -- "$REF_RE" "$owner_skill" | grep -qxF -- "$want"; then
    ok "orphan: $reffile ← $owner_skill 에서 가리킴"
  else
    no "orphan: $reffile 를 가리키는 SKILL.md 포인터가 없다 (기대: $owner_skill 안의 '$want')"
    orphans=$((orphans + 1))
  fi
done < <(printf '%s\n' "$REF_CORPUS")

if [ "$ref_checked" -eq 0 ]; then
  no "orphan: 코퍼스 ${ref_corpus_n}개 references/*.md 전체에서 0개를 확인했다 — 루프가 실패했다"
else
  assert_eq "$orphans" "0" "orphan: references 파일 ${ref_checked}건 중 미참조(고아) ${orphans}건"
fi

finish
