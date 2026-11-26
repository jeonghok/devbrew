#!/usr/bin/env bash
# test_compute_test_scope_candidates.sh — 후보의 바닥(이름 일치 · 바뀐 테스트 · `# guards:`)과 분모.
# 요구: R17 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
#       지원 파일(테스트 폴더의 테스트 아닌 파일)의 길 위 폴더 — docs/superpowers/specs/2026-11-24-qg-planted-text-suite-lock-design.md §5 · AC19
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts"
SUT="$SCRIPTS/compute-test-scope-candidates.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=""
mkrepo() {   # mkrepo [<함수>] — main 에 기준 커밋(origin/HEAD → origin/main 도 거기), feature 브랜치로 체크아웃.
             #   <함수> 는 기준 커밋 앞에 $R 안에서 더 둘 파일을 만든다.
  R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$R" || exit 1
  git -C "$R" config user.email t@t; git -C "$R" config user.name t; git -C "$R" config commit.gpgsign false
  mkdir -p "$R/src" "$R/tests" "$R/web" "$R/lib/tests" "$R/cmd"
  echo 'x=1' > "$R/src/foo.py"; echo x > "$R/tests/test_foo.py"; echo x > "$R/web/bar.ts"; echo x > "$R/web/bar.test.ts"
  echo x > "$R/cmd/plain.go"
  { printf '#!/bin/bash\n'; printf '# %s: src/**\n' guards; printf 'exit 0\n'; } > "$R/lib/tests/test_lock.sh"
  [ -n "${1:-}" ] && ( cd "$R" && "$1" )
  ( cd "$R" && git add -A && git commit -qm base \
    && git update-ref refs/remotes/origin/main main \
    && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main \
    && git checkout -q -b feature ) || exit 1
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
  local out rc err; out=$(cands); rc=$?
  assert_eq "$rc" "4" "R17: 기준선을 못 풀면 exit 4"
  assert_eq "$out" "" "R17: stdout 은 비어 있다"
  err=$( (cd "$R" && bash "$SUT") 2>&1 >/dev/null )
  assert_contains "$err" "compute-test-scope-candidates: 기본 브랜치를 찾지 못했다 — origin/HEAD 가 없거나 가리키는 브랜치가 없다. git remote set-head origin --auto 로 고친다" \
    "R17: 기본 브랜치가 없으면 고치는 법을 자기 이름으로 stderr 에 낸다"
  assert_contains "$err" "사유='no-default-branch'" "R17: exit 4 줄이 사유를 싣는다"
  rmrepo
}
case_default_branch_found_no_guidance() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py )
  local err rc; err=$( (cd "$R" && bash "$SUT") 2>&1 >/dev/null ); rc=$?
  assert_eq "$rc" "0" "origin/HEAD 가 있으면 exit 0"
  assert_not_contains "$err" "set-head" "origin/HEAD 가 있으면 기본 브랜치 안내가 없다(부재 짝)"
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

# 지원 파일 — 테스트 폴더 아래 이름이 테스트 꼴이 아닌 파일(§5 · AC19). 길 위 폴더 = 그 파일이 든 폴더부터 가장 가까운
# tests · test 폴더까지(둘 다 포함). 그 폴더들에 바로 든 테스트 꼴 파일만 더하고 하위 폴더로 내려가지 않는다.
support_layout() {
  local q=plugins/quality-gates/tests f
  mkdir -p "$q/fixtures/e2e-app/base/tests" "$q/spike" "$q/mocks" shared/tests/fixtures shared/tests/sub
  for f in "$q/fixtures/x.tsv" "$q/fixtures/test_a.sh" "$q/fixtures/q_test.go" "$q/fixtures/w.spec.js" \
           "$q/fixtures/testing.sh" "$q/fixtures/latest_test" "$q/test_b.py" "$q/helper.sh" "$q/e2e-scenarios.md" \
           "$q/spike/test_codex_json_extraction.sh" "$q/fixtures/e2e-app/base/tests/test_store.sh" "$q/mocks/mock-x.sh" \
           shared/tests/fixtures/ask-sites.tsv shared/tests/fixtures/test_f.sh shared/tests/test_s.sh \
           shared/tests/sub/test_z.sh; do
    echo x > "$f"
  done
}
has() { printf '%s\n' "$1" | grep -qxF -- "$2"; }
want() {   # want <후보> <경로> <메시지>
  has "$1" "$2" && ok "$3" || no "$3 — 후보에 '$2' 가 없다"
}
lack() {   # lack <후보> <경로> <메시지>
  has "$1" "$2" && no "$3 — 후보에 '$2' 가 들었다" || ok "$3"
}
case_support_expands_path_dirs() {
  mkrepo support_layout
  local q=plugins/quality-gates/tests out
  ( cd "$R" && echo y > "$q/fixtures/x.tsv" )
  out=$(cands)
  want "$out" "$q/fixtures/x.tsv" "support_expands_path_dirs: 바뀐 지원 파일 자신은 지금처럼 후보다"
  want "$out" "$q/fixtures/test_a.sh" "support_expands_path_dirs: 지원 파일이 든 폴더의 테스트(test_ 로 시작)"
  want "$out" "$q/fixtures/q_test.go" "support_expands_path_dirs: 같은 폴더의 _test.<확장자> 꼴"
  want "$out" "$q/fixtures/w.spec.js" "support_expands_path_dirs: 같은 폴더의 .spec.<확장자> 꼴"
  want "$out" "$q/test_b.py" "support_expands_path_dirs: 위로 올라간 테스트 폴더(tests/)에 바로 든 테스트"
  lack "$out" "$q/spike/test_codex_json_extraction.sh" "support_expands_path_dirs: 다른 하위 폴더(tests/spike/)의 테스트는 들지 않는다(AC19)"
  lack "$out" "$q/fixtures/e2e-app/base/tests/test_store.sh" "support_expands_path_dirs: 지원 파일 폴더의 하위 폴더(fixture 앱)로 내려가지 않는다(AC19)"
  lack "$out" "$q/mocks/mock-x.sh" "support_expands_path_dirs: 다른 하위 폴더의 테스트 아닌 파일은 들지 않는다"
  lack "$out" "$q/helper.sh" "support_expands_path_dirs: 길 위 폴더의 테스트 꼴이 아닌 파일은 더하지 않는다"
  lack "$out" "$q/fixtures/testing.sh" "support_expands_path_dirs: test_ 로 시작하지 않는 testing.sh 는 테스트 꼴이 아니다"
  lack "$out" "$q/fixtures/latest_test" "support_expands_path_dirs: 확장자 없는 _test 는 테스트 꼴이 아니다"
  lack "$out" "shared/tests/test_s.sh" "support_expands_path_dirs: 다른 테스트 폴더의 테스트는 들지 않는다"
  rmrepo
}
case_support_in_tests_root() {
  mkrepo support_layout
  local q=plugins/quality-gates/tests out
  ( cd "$R" && echo y > "$q/e2e-scenarios.md" )
  out=$(cands)
  want "$out" "$q/test_b.py" "support_in_tests_root: tests/ 바로 든 테스트를 더한다"
  lack "$out" "$q/fixtures/test_a.sh" "support_in_tests_root: 하위 폴더(tests/fixtures/)의 테스트는 들지 않는다"
  lack "$out" "$q/spike/test_codex_json_extraction.sh" "support_in_tests_root: tests/spike/ 의 테스트는 들지 않는다"
  rmrepo
}
case_shared_tests_fixture() {
  mkrepo support_layout
  local out
  ( cd "$R" && echo y > shared/tests/fixtures/ask-sites.tsv )
  out=$(cands)
  want "$out" "shared/tests/fixtures/test_f.sh" "shared_tests_fixture: shared/tests/fixtures/ 바로 든 테스트"
  want "$out" "shared/tests/test_s.sh" "shared_tests_fixture: shared/tests/ 바로 든 테스트"
  lack "$out" "shared/tests/sub/test_z.sh" "shared_tests_fixture: 다른 하위 폴더(shared/tests/sub/)의 테스트는 들지 않는다"
  lack "$out" "plugins/quality-gates/tests/test_b.py" "shared_tests_fixture: 다른 플러그인의 테스트 폴더는 들지 않는다"
  rmrepo
}
case_topic_mode_same() {
  mkrepo support_layout
  local q=plugins/quality-gates/tests a b tree
  ( cd "$R" && echo y > "$q/fixtures/x.tsv" && git commit -qam c1 )
  a=$(cands)
  tree=$(git -C "$R" rev-parse 'HEAD^{tree}')
  git -C "$R" checkout -q main
  b=$(cands --topic main "$tree")
  want "$b" "$q/fixtures/test_a.sh" "topic_mode_same: 토픽 모드도 지원 파일의 길 위 폴더 테스트를 더한다"
  lack "$b" "$q/spike/test_codex_json_extraction.sh" "topic_mode_same: 토픽 모드도 하위 폴더로 내려가지 않는다"
  assert_eq "$b" "$a" "topic_mode_same: 같은 변경이면 토픽 모드와 작업 트리 모드의 후보가 같다"
  rmrepo
}

for c in case_name_mapping_and_changed_tests case_no_change_is_empty case_unsupported_language_has_no_mapping \
         case_R17_unresolved_baseline_is_exit_4 case_default_branch_found_no_guidance case_R17_git_failure_is_exit_4 case_R17_bad_topic_args_are_exit_4 \
         case_topic_mode_reads_the_tree case_total_contains_every_candidate case_emit_guards_only_lists_guards \
         case_subdirectory_run_matches_root_run case_deleted_test_is_a_candidate \
         case_support_expands_path_dirs case_support_in_tests_root case_shared_tests_fixture case_topic_mode_same; do
  echo "== $c"; $c
done
finish
