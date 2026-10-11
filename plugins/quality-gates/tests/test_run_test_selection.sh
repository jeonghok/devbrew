#!/usr/bin/env bash
# test_run_test_selection.sh — assign · run · unrun · pending 의 행 파일 계약.
# 요구: R5 · R7 · R11 · R15 · R16 · R17 · R20 · R21 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RTS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/run-test-selection.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

REPO=""; TREE=""
mkrepo() {
  REPO=$(mktemp -d) && [ -d "$REPO" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$REPO/main" || exit 1
  git -C "$REPO/main" config user.email t@t; git -C "$REPO/main" config user.name t
  git -C "$REPO/main" config commit.gpgsign false
  mkdir -p "$REPO/main/tests"; printf 'x\n' > "$REPO/main/README"
}
shtest() {   # shtest <relpath> <exit> — 실행 비트가 있는 shell 테스트
  mkdir -p "$REPO/main/$(dirname "$1")"
  printf '#!/bin/bash\nexit %s\n' "$2" > "$REPO/main/$1"; chmod +x "$REPO/main/$1"
}
mktree() {
  ( cd "$REPO/main" && git add -A && git commit -qm t ) || { no "픽스처 커밋 실패"; return 1; }
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt" HEAD || { no "픽스처 worktree 실패"; return 1; }
  TREE="$REPO/wt"
}
rmrepo() { cd / && rm -rf "$REPO"; }
row_of() { awk -F'\t' -v u="$2" '$1 == u { print $2 "\t" $3 "\t" $4 }' "$1"; }
trailer() { tail -n 1 "$1"; }
assign() { printf '%s\n' "$@" | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null; }
arow() { awk -F'\t' -v u="$1" '$1 == u { print $2 "\t" $3 }' "$REPO/assign.tsv"; }

# ── assign ──────────────────────────────────────────────────────────────────────
# R17 — 배정 파일은 꼬리 줄(감지된 어댑터 · 행 수)로 끝난다. 생산자가 끝까지 썼다는 증거다.
case_R17_assign_writes_trailer() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  assign tests/a.sh; local rc=$?
  assert_eq "$rc" "0" "R17: assign exit 0"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=shell	rows=1" "R17: 꼬리 줄"
  rmrepo
}
# R17 — 사용 오류로 죽은 assign 은 배정 파일을 남기지 않는다(빈 파일이 「배정할 것 없음」으로 읽히지 않게).
case_R17_failed_assign_leaves_no_file() {
  mkrepo; mktree || { rmrepo; return; }
  printf 'x\n' | bash "$RTS" assign "$REPO/no-such-tree" "$REPO/assign.tsv" 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R17: 없는 트리 → exit 2"
  [ ! -e "$REPO/assign.tsv" ] && ok "R17: 배정 파일이 생기지 않았다" || no "R17: 실패한 assign 이 파일을 남겼다"
  rmrepo
}
# R17 — 실패한 assign 은 같은 경로에 있던 이전 배정 파일도 남기지 않는다(옛 파일이 이번 결과로 읽히지 않게).
case_R17_failed_assign_removes_stale_file() {
  mkrepo; mktree || { rmrepo; return; }
  printf 'stale\n' > "$REPO/assign.tsv"
  printf 'x\n' | bash "$RTS" assign "$REPO/no-such-tree" "$REPO/assign.tsv" 2>/dev/null; local rc=$?
  [ "$rc" != "0" ] && ok "R17: 실패 exit 0 아님" || no "R17: 실패했는데 exit 0"
  [ ! -e "$REPO/assign.tsv" ] && ok "R17: 이전 배정 파일이 지워졌다" || no "R17: 이전 배정 파일이 남았다"
  rmrepo
}
# R17 — 출력 경로가 디렉토리면 exit 0 으로 파일 없이 끝나지 않고 실패한다.
case_R17_output_path_is_directory_fails() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  mkdir "$REPO/assign.tsv"
  local err; err=$(printf 'tests/a.sh\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null); local rc=$?
  [ "$rc" != "0" ] && ok "R17: 디렉토리 출력 경로 → 실패" || no "R17: 디렉토리 출력 경로인데 exit 0"
  assert_contains "$err" "디렉토리" "R17: 사유를 알린다"
  rmrepo
}
# R20 — 트리 밖으로 나가는 후보(절대경로 · `..` · 밖을 가리키는 링크)는 claim 되지 않고 unclaimed 다.
case_R20_assign_refuses_units_outside_tree() {
  mkrepo; shtest tests/a.sh 0; mkdir -p "$REPO/outside/tests"; printf '#!/bin/bash\n' > "$REPO/outside/tests/x.sh"
  chmod +x "$REPO/outside/tests/x.sh"; mktree || { rmrepo; return; }
  ln -s "$REPO/outside/tests" "$TREE/tests/escape"
  assign "/etc/passwd" "../outside/tests/x.sh" "tests/escape/x.sh" tests/a.sh
  assert_eq "$(arow /etc/passwd)" "unclaimed	file" "R20: 절대경로 → unclaimed"
  assert_eq "$(arow ../outside/tests/x.sh)" "unclaimed	file" "R20: .. → unclaimed"
  assert_eq "$(arow tests/escape/x.sh)" "unclaimed	file" "R20: 밖을 가리키는 링크 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조: 트리 안 shell 테스트는 claim"
  rmrepo
}
# R20 — shell 은 tests/*.sh 이면서 실행 비트가 있을 때만 claim 한다.
case_R20_shell_scope() {
  mkrepo; shtest tests/a.sh 0; shtest scripts/b.sh 0; printf '#!/bin/bash\n' > "$REPO/main/tests/c.sh"
  mktree || { rmrepo; return; }
  assign scripts/b.sh tests/c.sh tests/a.sh
  assert_eq "$(arow scripts/b.sh)" "unclaimed	file" "R20: tests/ 밖 .sh → unclaimed"
  assert_eq "$(arow tests/c.sh)" "unclaimed	file" "R20: 실행 비트 없음 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조"
  rmrepo
}
# R21 — unittest 는 판정하지 못하는 파일을 claim 하지 않는다.
case_R21_unittest_refuses_unjudgeable_files() {
  mkrepo
  printf 'def test_bare():\n    assert False\n' > "$REPO/main/tests/test_bare.py"
  printf 'from unittest.mock import patch\nclass TestHelper:\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_plain_class.py"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_real.py"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\ndef test_bare():\n    assert False\n' > "$REPO/main/tests/test_mixed.py"
  mktree || { rmrepo; return; }
  assign tests/test_bare.py tests/test_plain_class.py tests/test_real.py tests/test_mixed.py
  assert_eq "$(arow tests/test_bare.py)" "unclaimed	file" "R21: 모듈 레벨 bare def test → unclaimed"
  assert_eq "$(arow tests/test_plain_class.py)" "unclaimed	file" "R21: TestCase 아닌 class Test → unclaimed"
  assert_eq "$(arow tests/test_mixed.py)" "unclaimed	file" "R21: TestCase + 모듈 레벨 bare def test 섞임 → unclaimed"
  assert_eq "$(arow tests/test_real.py)" "unittest	file" "R21 양성 대조: TestCase 하위클래스 → unittest"
  rmrepo
}
# R21 — go 는 *_test.go 를 패키지 unit 으로 접는다.
case_R21_go_unit_is_package() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"
  printf 'package pkg\n' > "$REPO/main/pkg/a_test.go"; printf 'package pkg\n' > "$REPO/main/pkg/b_test.go"
  mktree || { rmrepo; return; }
  assign pkg/a_test.go pkg/b_test.go pkg/a.go
  assert_eq "$(arow pkg)" "go	package" "R21: *_test.go → 패키지 unit"
  assert_eq "$(grep -c '^pkg	' "$REPO/assign.tsv")" "1" "R21: 같은 패키지는 한 행"
  assert_eq "$(arow pkg/a.go)" "unclaimed	file" "R21: *_test.go 아닌 go 파일은 claim 안 함"
  rmrepo
}
# R16 — 어느 어댑터도 못 돌리는 후보는 unclaimed 행으로 남는다(조용히 사라지지 않는다).
case_R16_unhandled_candidate_is_unclaimed() {
  mkrepo; printf 'x\n' > "$REPO/main/README"; mktree || { rmrepo; return; }
  assign spec/foo_spec.rb
  assert_eq "$(arow spec/foo_spec.rb)" "unclaimed	file" "R16: 지원하지 않는 후보 → unclaimed"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=-	rows=1" "R16: 감지 0 은 adapters=-"
  rmrepo
}
case_bulk_absorbs_residual() {
  mkrepo; printf '[package]\nname="x"\n' > "$REPO/main/Cargo.toml"; printf 'test:\n\ttrue\n' > "$REPO/main/Makefile"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'src/lib.rs\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  assert_eq "$(arow BULK)" "cargo	bulk" "잔여는 첫 bulk 러너가 흡수"
  assert_contains "$err" "미실행 러너: make" "흡수하지 않은 bulk 러너를 알린다"
  rmrepo
}

# R11 — 브랜치에 붙은 트리 · 주 작업 트리에서는 돌리지 않는다.
case_R11_run_refuses_live_tree() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$REPO/main" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R11: 브랜치에 붙은 주 작업 트리 → exit 2"
  [ ! -e "$REPO/rows.tsv" ] && ok "R11: 행 파일을 쓰지 않았다" || no "R11: 거부했는데 행 파일이 생겼다"
  git -C "$REPO/main" checkout -q --detach
  bash "$RTS" run "$REPO/main" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: detached 라도 주 작업 트리면 exit 2"
  git -C "$REPO/main" worktree add -q -b side "$REPO/attached" >/dev/null 2>&1
  bash "$RTS" run "$REPO/attached" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: 브랜치에 붙은 연결 트리 → exit 2"
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "0" "R11 양성 대조: 일회용 detached 트리는 돈다"
  rmrepo
}
# R5 — 행 파일은 그 행을 만든 트리의 커밋을 꼬리에 싣는다. 다른 트리의 행 파일에 병합하지 않는다.
case_R5_rows_carry_their_tree_commit() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  local c; c=$(git -C "$TREE" rev-parse HEAD)
  assert_eq "$(trailer "$REPO/rows.tsv")" "#qg-rows	runner=shell	commit=$c	rows=1	flaky=0" "R5: 꼬리 줄이 트리 커밋을 싣는다"
  ( cd "$REPO/main" && echo y > tests/y && git add -A && git commit -qm y )
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt2" HEAD
  bash "$RTS" run "$REPO/wt2" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R5: 다른 커밋의 트리로 같은 행 파일에 병합하면 exit 2"
  rmrepo
}
# R7 — 다시 돌린 unit 의 행은 교체된다. 같은 unit 이 두 행이 되지 않는다.
case_R7_rerun_replaces_rows() {
  mkrepo; shtest tests/ok.sh 0; shtest tests/bad.sh 1; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/ok.sh tests/bad.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/ok.sh)" "fail	1	bulk" "R7 전제: bulk red 는 모든 unit 에 찍힌다"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/ok.sh tests/bad.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/ok.sh)" "pass	0	per-unit" "R7: per-unit 행이 bulk 행을 교체"
  assert_eq "$(grep -c '^tests/ok.sh	' "$REPO/rows.tsv")" "1" "R7: 같은 unit 은 한 행"
  assert_eq "$(trailer "$REPO/rows.tsv" | cut -f4)" "rows=2" "R7: 꼬리 행 수"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/ok.sh tests/ok.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R7: 인자에 같은 unit 이 두 번 오면 exit 2"
  rmrepo
}
# R15 — flaky 재실행은 행 파일당 한 번이고, 관측하지 못한 재실행은 원래 행을 지킨다.
case_R15_flaky_rerun_once_and_keeps_unobserved() {
  mkrepo; shtest tests/bad.sh 1; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/bad.sh 2>/dev/null
  DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/bad.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/bad.sh)" "fail	1	per-unit" "R15: 관측 못 한 flaky 재실행은 원래 행을 지킨다"
  assert_eq "$(trailer "$REPO/rows.tsv" | cut -f5)" "flaky=1" "R15: 시도는 한 번으로 센다"
  bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/bad.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R15: 두 번째 flaky 재실행은 거부"
  rmrepo
}
case_R15_flaky_rerun_unobserved_exit_keeps_row() {
  mkrepo; local flag="$REPO/flag127"
  printf '#!/bin/bash\n[ -e %q ] && exec qg-no-such-command-xyz\ntouch %q\nexit 1\n' "$flag" "$flag" > "$REPO/main/tests/gone.sh"
  chmod +x "$REPO/main/tests/gone.sh"; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/gone.sh 2>/dev/null
  bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/gone.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/gone.sh)" "fail	1	per-unit" "R15: 재실행이 exit 127(관측 없음)이면 원래 행을 지킨다"
  rmrepo
}
case_R15_flaky_rerun_replaces_observed_row() {
  mkrepo; local flag="$REPO/flag"
  printf '#!/bin/bash\n[ -e %q ] && exit 0\ntouch %q\nexit 1\n' "$flag" "$flag" > "$REPO/main/tests/flip.sh"
  chmod +x "$REPO/main/tests/flip.sh"; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/flip.sh 2>/dev/null
  bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/flip.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/flip.sh)" "pass	0	flaky" "R15: 관측한 flaky 재실행은 행을 교체하고 표시한다"
  rmrepo
}
# R20 — run 에서도 같은 범위를 다시 검사한다: 트리 밖 unit 은 absent, 범위 밖 shell 은 실행하지 않는다.
case_R20_run_rechecks_scope() {
  mkrepo; shtest tests/a.sh 0; local mark="$REPO/RAN"
  printf '#!/bin/bash\ntouch %q\n' "$mark" > "$REPO/main/run.sh"; chmod +x "$REPO/main/run.sh"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" ../main/run.sh run.sh tests/a.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" ../main/run.sh | cut -f1)" "absent" "R20: 트리 밖 unit → absent"
  assert_eq "$(row_of "$REPO/rows.tsv" run.sh | cut -f1)" "unrun" "R20: 범위 밖 shell unit → unrun(실행 거부)"
  [ ! -e "$mark" ] && ok "R20: 범위 밖 스크립트가 돌지 않았다" || no "R20: 범위 밖 스크립트가 돌았다"
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh | cut -f1)" "pass" "R20 양성 대조"
  rmrepo
}
case_unrun_and_pending() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" unrun "$REPO/b.tsv" shell - tests/a.sh tests/b.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/b.tsv" tests/a.sh)" "unrun	-	skip" "unrun 은 skip 행을 쓴다"
  assert_eq "$(trailer "$REPO/b.tsv")" "#qg-rows	runner=shell	commit=-	rows=2	flaky=0" "unrun 꼬리 줄"
  bash "$RTS" unrun "$REPO/b.tsv" shell nothex tests/a.sh 2>/dev/null; assert_eq "$?" "2" "commit 은 sha 또는 - 만"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  assert_eq "$(bash "$RTS" pending "$REPO/rows.tsv" tests/a.sh tests/new.sh | tr '\n' ' ')" "tests/new.sh " \
    "pending 은 관측된 행이 없는 unit 만 낸다"
  assert_eq "$(bash "$RTS" pending "$REPO/b.tsv" tests/a.sh | tr '\n' ' ')" "tests/a.sh " "unrun 행은 관측이 아니다"
  rmrepo
}
case_truncated_rows_file_is_refused() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  sed -i.bak '$d' "$REPO/rows.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "꼬리 줄이 잘린 행 파일에 병합하지 않는다"
  rmrepo
}
for c in case_R17_assign_writes_trailer case_R17_failed_assign_leaves_no_file \
         case_R17_failed_assign_removes_stale_file case_R17_output_path_is_directory_fails \
         case_R20_assign_refuses_units_outside_tree case_R20_shell_scope \
         case_R21_unittest_refuses_unjudgeable_files case_R21_go_unit_is_package \
         case_R16_unhandled_candidate_is_unclaimed case_bulk_absorbs_residual \
         case_R11_run_refuses_live_tree case_R5_rows_carry_their_tree_commit case_R7_rerun_replaces_rows \
         case_R15_flaky_rerun_once_and_keeps_unobserved case_R15_flaky_rerun_unobserved_exit_keeps_row \
         case_R15_flaky_rerun_replaces_observed_row \
         case_R20_run_rechecks_scope case_unrun_and_pending case_truncated_rows_file_is_refused; do
  echo "== $c"; $c
done
finish
