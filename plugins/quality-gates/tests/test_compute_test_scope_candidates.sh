#!/usr/bin/env bash
# test_compute_test_scope_candidates.sh — 후보의 바닥(이름 일치 · 바뀐 테스트 · `# guards:`)과 분모.
# 요구: R17 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts"
SUT="$SCRIPTS/compute-test-scope-candidates.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=""
mkrepo() {   # main 에 기준 커밋, feature 브랜치로 체크아웃
  R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$R" || exit 1
  git -C "$R" config user.email t@t; git -C "$R" config user.name t; git -C "$R" config commit.gpgsign false
  mkdir -p "$R/src" "$R/tests" "$R/web" "$R/lib/tests" "$R/cmd"
  echo 'x=1' > "$R/src/foo.py"; echo x > "$R/tests/test_foo.py"; echo x > "$R/web/bar.ts"; echo x > "$R/web/bar.test.ts"
  echo x > "$R/cmd/plain.go"
  { printf '#!/bin/bash\n'; printf '# %s: src/**\n' guards; printf 'exit 0\n'; } > "$R/lib/tests/test_lock.sh"
  ( cd "$R" && git add -A && git commit -qm base && git checkout -q -b feature ) || exit 1
}
rmrepo() { cd / && rm -rf "$R"; }
cands() { ( cd "$R" && bash "$SUT" "$@" ) 2>/dev/null; }

case_name_mapping_and_changed_tests() {
  mkrepo
  ( cd "$R" && echo 'x=2' > src/foo.py && git commit -qam c1 && echo y > web/bar.ts && echo n > tests/test_new.py )
  local out; out=$(cands | tr '\n' ' ')
  assert_contains "$out" "tests/test_foo.py" "커밋된 소스 변경 → 이름이 맞는 테스트"
  assert_contains "$out" "web/bar.test.ts" "미커밋 소스 변경 → 이름이 맞는 테스트"
  assert_contains "$out" "tests/test_new.py" "untracked 새 테스트도 후보"
  assert_contains "$out" "lib/tests/test_lock.sh" "guards 글롭이 바뀐 파일에 걸린 락"
  rmrepo
}
case_no_change_is_empty() {
  mkrepo
  local out rc; out=$(cands); rc=$?
  assert_eq "$rc:$out" "0:" "변경 없음 → 빈 출력 + exit 0"
  rmrepo
}
case_unsupported_language_has_no_mapping() {
  mkrepo; ( cd "$R" && echo y > cmd/plain.go )
  assert_eq "$(cands)" "" "이름 규칙이 없는 언어는 매핑하지 않는다"
  rmrepo
}
# R17 — 범위를 확정하지 못한 것은 「후보 없음」이 아니다: 기준선 미확정 · git 실패는 exit 4.
case_R17_unresolved_baseline_is_exit_4() {
  R=$(mktemp -d); git init -q -b weird "$R"; git -C "$R" config user.email t@t; git -C "$R" config user.name t
  ( cd "$R" && echo a > a && git add a && git commit -qm a && git checkout -q -b other && git branch -qD weird )
  local out rc; out=$(cands); rc=$?
  assert_eq "$rc" "4" "R17: 기준선을 못 풀면 exit 4"
  assert_eq "$out" "" "R17: stdout 은 비어 있다"
  rmrepo
}
case_R17_git_failure_is_exit_4() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py )
  printf 'garbage' > "$R/.git/index"
  local rc; cands >/dev/null; rc=$?
  assert_eq "$rc" "4" "R17: 인덱스가 깨져 git 이 실패하면 exit 4"
  rmrepo
}
case_R17_bad_topic_args_are_exit_4() {
  mkrepo
  cands --topic nope HEAD >/dev/null; assert_eq "$?" "4" "R17: 풀 수 없는 경계 → exit 4"
  cands --topic main >/dev/null; assert_eq "$?" "4" "R17: --topic 인자 모양 위반 → exit 4"
  cands --total --tree >/dev/null; assert_eq "$?" "4" "R17: --total 인자 모양 위반 → exit 4"
  rmrepo
}
case_topic_mode_reads_the_tree() {
  mkrepo
  ( cd "$R" && echo 'x=2' > src/foo.py && git commit -qam c1 )
  local tree; tree=$(git -C "$R" rev-parse 'HEAD^{tree}')
  git -C "$R" checkout -q main
  local out; out=$(cands --topic main "$tree" | tr '\n' ' ')
  assert_contains "$out" "tests/test_foo.py" "토픽: 경계..트리 변경의 이름 일치"
  assert_contains "$out" "lib/tests/test_lock.sh" "토픽: 트리 안 락의 guards 를 읽는다"
  rmrepo
}
# 분모는 후보를 포함한다(후보 ⊂ 분모). 비율을 부풀릴 수 없게 분모를 이 스크립트가 센다.
case_total_contains_every_candidate() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py && echo n > tests/test_new.py )
  local n m; n=$(cands | grep -c .); m=$(cands --total)
  [ "$m" -ge "$n" ] && [ "$n" -ge 1 ] && ok "분모 $m ≥ 후보 $n" || no "분모 $m < 후보 $n"
  assert_eq "$m" "4" "분모는 추적 테스트 3 + untracked 새 테스트 1 (untracked 를 빼면 3)"
  local tree; tree=$(git -C "$R" rev-parse 'HEAD^{tree}')
  assert_eq "$(cands --total --tree "$tree")" "3" "--total --tree 는 그 트리(커밋된 것)의 테스트 수"
  rmrepo
}
case_subdirectory_run_matches_root_run() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py && echo n > tests/test_new.py )
  local a b ta tb
  a=$(cands); b=$( cd "$R/src" && bash "$SUT" 2>/dev/null )
  assert_eq "$b" "$a" "하위 디렉토리에서 돌려도 후보가 루트와 같다"
  ta=$(cands --total); tb=$( cd "$R/src" && bash "$SUT" --total 2>/dev/null )
  assert_eq "$tb" "$ta" "하위 디렉토리에서 돌려도 분모가 루트와 같다"
  rmrepo
}
case_deleted_test_is_a_candidate() {
  mkrepo; ( cd "$R" && rm tests/test_foo.py )
  assert_contains "$(cands | tr '\n' ' ')" "tests/test_foo.py" "지운 테스트 파일도 후보다"
  rmrepo
}
case_emit_guards_only_lists_guards() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py )
  assert_eq "$(cands --emit-guards)" "lib/tests/test_lock.sh" "--emit-guards 는 guards 후보만"
  rmrepo
}

for c in case_name_mapping_and_changed_tests case_no_change_is_empty case_unsupported_language_has_no_mapping \
         case_R17_unresolved_baseline_is_exit_4 case_R17_git_failure_is_exit_4 case_R17_bad_topic_args_are_exit_4 \
         case_topic_mode_reads_the_tree case_total_contains_every_candidate case_emit_guards_only_lists_guards \
         case_subdirectory_run_matches_root_run case_deleted_test_is_a_candidate; do
  echo "== $c"; $c
done
finish
