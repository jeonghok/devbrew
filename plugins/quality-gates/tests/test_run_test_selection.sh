#!/usr/bin/env bash
# test_run_test_selection.sh — assign · run · unrun · pending 의 행 파일 계약.
# 요구: R5 · R7 · R11 · R15 · R16 · R17 · R20 · R21 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
#       지원 파일 배정(support) — docs/superpowers/specs/2026-11-24-qg-planted-text-suite-lock-design.md §5 · AC19
#       unittest 불러 보기 · 관문 · 0개 실행 — 같은 설계 §5 · AC20 · AC28
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
  mkrepo; shtest tests/a.sh 0; shtest scripts/b.sh 0; printf '#!/bin/bash\n' > "$REPO/main/tests/test_c.sh"
  mktree || { rmrepo; return; }
  assign scripts/b.sh tests/test_c.sh tests/a.sh
  assert_eq "$(arow scripts/b.sh)" "unclaimed	file" "R20: tests/ 밖 .sh → unclaimed"
  assert_eq "$(arow tests/test_c.sh)" "unclaimed	file" "R20: 실행 비트 없음 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조"
  rmrepo
}
# R21 · AC20 — unittest 는 불러 보아 판정하지 못하는 파일을 claim 하지 않는다(모듈 수준 def test 는 글자로 먼저 거른다).
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
  mkdir -p "$REPO/main/pkg/tests"
  printf '#!/bin/bash\ntouch %q\n' "$REPO/RAN11" > "$REPO/main/pkg/tests/m.sh"; chmod +x "$REPO/main/pkg/tests/m.sh"
  git -C "$REPO/main" checkout -q --detach
  bash "$RTS" run "$REPO/main" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: detached 라도 주 작업 트리면 exit 2"
  # 하위 디렉토리로 넘겨도 같다 — git-dir 이 절대·상대로 갈려 문자열 비교를 빠져나가던 입력.
  ( cd "$REPO/main" && git add -A && git commit -qm m ) >/dev/null 2>&1
  git -C "$REPO/main" checkout -q --detach
  bash "$RTS" run "$REPO/main/pkg" shell bulk "$REPO/rows.tsv" tests/m.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: detached 주 작업 트리의 하위 디렉토리 → exit 2"
  [ ! -e "$REPO/RAN11" ] && ok "R11: 하위 디렉토리로도 저장소 코드가 돌지 않았다" || no "R11: 하위 디렉토리 우회로 주 작업 트리에서 코드가 돌았다"
  [ ! -e "$REPO/rows.tsv" ] || no "R11: 거부했는데 행 파일이 생겼다"
  git -C "$REPO/main" worktree add -q -b side "$REPO/attached" >/dev/null 2>&1
  bash "$RTS" run "$REPO/attached" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: 브랜치에 붙은 연결 트리 → exit 2"
  bash "$RTS" run "$TREE/tests" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: 일회용 트리의 하위 디렉토리도 최상위가 아니면 exit 2"
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
# 꼬리 줄의 rows= 가 실제 행 수와 다르면 거부한다.
case_rows_count_mismatch_is_refused() {
  mkrepo; shtest tests/a.sh 0; shtest tests/b.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh tests/b.sh 2>/dev/null
  sed -i.bak '1d' "$REPO/rows.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "꼬리 줄 rows= 가 실제 행 수와 다르면 병합하지 않는다"
  rmrepo
}
# 꼬리 값이 비었거나 범위 밖이면 거부한다 — rows=0 + 빈 runner 로 러너·커밋 대조를 건너뛰지 못한다.
case_trailer_values_are_validated() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  local c rc; c=$(git -C "$TREE" rev-parse HEAD)
  printf '#qg-rows\trunner=\tcommit=\trows=0\tflaky=0\n' > "$REPO/e1.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/e1.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "빈 runner= 는 거부"
  printf '#qg-rows\trunner=shell\tcommit=\trows=0\tflaky=0\n' > "$REPO/e2.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/e2.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "빈 commit= 는 거부"
  printf '#qg-rows\trunner=shell\tcommit=%s\trows=0\tflaky=2\n' "$c" > "$REPO/e3.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/e3.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "flaky= 가 0·1 이 아니면 거부"
  printf '#qg-rows\trunner=shell\tcommit=%s\trows=0\tflaky=\n' "$c" > "$REPO/e4.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/e4.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "빈 flaky= 는 거부"
  rmrepo
}
# ── 지원 파일(§5 · AC19) ──────────────────────────────────────────────────────────
# 흡수 러너가 없을 때, 맡지 않은 파일 가운데 이름이 테스트 꼴이 아니고 경로에 tests · test 폴더가 있는 것은 같은 입력에서
# 러너가 맡은 파일이 그 길 위 폴더(파일이 든 폴더 .. 가장 가까운 tests · test 폴더)에 바로 들어 있으면 support 다.
case_support_row_when_folder_claimed() {
  mkrepo; shtest tests/a.sh 0; shtest tests/fixtures/test_f.sh 0
  printf 'x\n' > "$REPO/main/tests/data.tsv"; printf 'x\n' > "$REPO/main/tests/fixtures/x.tsv"
  printf 'x\n' > "$REPO/main/tests/helper.sh"
  mktree || { rmrepo; return; }
  assign tests/data.tsv tests/fixtures/x.tsv tests/helper.sh tests/a.sh
  assert_eq "$(arow tests/data.tsv)" "support	file" "support_row_when_folder_claimed: 같은 폴더에 맡은 테스트가 있는 데이터 파일 → support"
  assert_eq "$(arow tests/fixtures/x.tsv)" "support	file" "support_row_when_folder_claimed: 위 테스트 폴더(tests/)에 맡은 테스트가 있으면 → support"
  assert_eq "$(arow tests/helper.sh)" "support	file" "support_row_when_folder_claimed: 실행 비트 없는 도우미 셸 → support"
  assert_eq "$(arow tests/a.sh)" "shell	file" "support_row_when_folder_claimed: 그 폴더의 테스트는 지금처럼 러너가 맡는다"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=shell	rows=4" "support_row_when_folder_claimed: support 행도 꼬리의 행 수에 든다"
  rmrepo
}
case_unclaimed_when_folder_has_no_claimed_test() {
  mkrepo; shtest tests/a.sh 0; shtest tests/sub/test_s.sh 0
  printf 'x\n' > "$REPO/main/tests/data.tsv"; mkdir -p "$REPO/main/lib/test"; printf 'x\n' > "$REPO/main/lib/test/d.json"
  mktree || { rmrepo; return; }
  assign tests/data.tsv tests/sub/test_s.sh lib/test/d.json
  assert_eq "$(arow tests/data.tsv)" "unclaimed	file" "unclaimed_when_folder_has_no_claimed_test: 맡은 테스트가 하위 폴더에만 있으면 → unclaimed"
  assert_eq "$(arow lib/test/d.json)" "unclaimed	file" "unclaimed_when_folder_has_no_claimed_test: test/ 폴더에 맡은 테스트가 없으면 → unclaimed"
  assert_eq "$(arow tests/sub/test_s.sh)" "shell	file" "unclaimed_when_folder_has_no_claimed_test: 양성 대조 — 하위 폴더의 테스트는 맡는다"
  assign tests/data.tsv
  assert_eq "$(arow tests/data.tsv)" "unclaimed	file" "unclaimed_when_folder_has_no_claimed_test: 폴더의 테스트(tests/a.sh)가 같은 입력에 없으면 → unclaimed"
  rmrepo
}
# 길 위 폴더 가운데 경로 성분에 spike · fixtures 가 든 폴더는 보지 않는다(tools/suite/run-all.sh 의 제외와 같은 규칙).
# 성분 전체가 맞을 때만 뺀다 — spikes/ 는 그대로 본다.
case_support_skips_spike_fixtures_folders() {
  mkrepo; shtest tests/spike/test_sp.sh 0; shtest tests/fixtures/test_f.sh 0; shtest tests/spikes/test_s.sh 0
  printf 'x\n' > "$REPO/main/tests/spike/spike_prompt.md"; printf 'x\n' > "$REPO/main/tests/fixtures/x.tsv"
  printf 'x\n' > "$REPO/main/tests/spikes/notes.md"
  shtest tests/fixtures/e2e-app/base/tests/test_store.sh 0
  printf 'x\n' > "$REPO/main/tests/fixtures/e2e-app/base/tests/store.json"
  shtest tests/a.sh 0
  mktree || { rmrepo; return; }
  assign tests/spike/spike_prompt.md tests/spike/test_sp.sh tests/fixtures/x.tsv tests/fixtures/test_f.sh \
    tests/spikes/notes.md tests/spikes/test_s.sh \
    tests/fixtures/e2e-app/base/tests/store.json tests/fixtures/e2e-app/base/tests/test_store.sh
  assert_eq "$(arow tests/spike/spike_prompt.md)" "unclaimed	file" "support_skips_spike_fixtures_folders: 맡은 테스트가 tests/spike/ 에만 있으면 → unclaimed"
  assert_eq "$(arow tests/fixtures/x.tsv)" "unclaimed	file" "support_skips_spike_fixtures_folders: 맡은 테스트가 tests/fixtures/ 에만 있으면 → unclaimed"
  assert_eq "$(arow tests/spikes/notes.md)" "support	file" "support_skips_spike_fixtures_folders: 성분 이름 일부(tests/spikes/)는 그대로 본다 → support"
  assert_eq "$(arow tests/spike/test_sp.sh)" "shell	file" "support_skips_spike_fixtures_folders: 양성 대조 — spike 폴더의 테스트 자신은 지금처럼 맡는다"
  assert_eq "$(arow tests/fixtures/e2e-app/base/tests/store.json)" "unclaimed	file" "support_skips_spike_fixtures_folders: 가장 가까운 테스트 폴더 위쪽에 fixtures 가 들면(fixture 앱) → unclaimed"
  assert_eq "$(arow tests/fixtures/e2e-app/base/tests/test_store.sh)" "shell	file" "support_skips_spike_fixtures_folders: 양성 대조 — fixture 앱의 테스트 자신은 지금처럼 맡는다"
  assign tests/spike/spike_prompt.md tests/fixtures/x.tsv tests/a.sh
  assert_eq "$(arow tests/spike/spike_prompt.md)" "support	file" "support_skips_spike_fixtures_folders: tests/ 에 바로 맡은 테스트가 있으면 → support"
  assert_eq "$(arow tests/fixtures/x.tsv)" "support	file" "support_skips_spike_fixtures_folders: fixtures 도 tests/ 에 바로 맡은 테스트가 있으면 → support"
  rmrepo
}
case_test_named_unclaimed_stays() {
  mkrepo; shtest plugins/x/tests/test_ok.sh 0
  printf '#!/bin/bash\n' > "$REPO/main/plugins/x/tests/test_y.sh"
  mktree || { rmrepo; return; }
  assign plugins/x/tests/test_y.sh plugins/x/tests/test_ok.sh
  assert_eq "$(arow plugins/x/tests/test_y.sh)" "unclaimed	file" "test_named_unclaimed_stays: 이름이 테스트 꼴인데 맡는 러너가 없으면 → unclaimed(지원 파일 아님)"
  assert_eq "$(arow plugins/x/tests/test_ok.sh)" "shell	file" "test_named_unclaimed_stays: 양성 대조 — 같은 폴더의 맡은 테스트"
  rmrepo
}
# 바뀐 도우미를 쓰는 테스트가 이름 맞추기로 닿지 않아도 후보의 바닥 → 배정을 거쳐 그 테스트가 행에 있다.
case_helper_reached_only_by_folder() {
  mkrepo; local M="$REPO/main"
  printf 'helper_ok() { return 0; }\n' > "$M/tests/lib.sh"
  printf '#!/bin/bash\n. "$(dirname "$0")/lib.sh"\nhelper_ok\n' > "$M/tests/test_uses.sh"; chmod +x "$M/tests/test_uses.sh"
  ( cd "$M" && git add -A && git commit -qm base && git update-ref refs/remotes/origin/main main \
    && git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main && git checkout -q -b feature \
    && printf 'helper_ok() { return 1; }\n' > tests/lib.sh && git commit -qam helper ) || { no "픽스처 실패"; rmrepo; return; }
  local cands; cands=$( cd "$M" && bash "$(dirname "$RTS")/compute-test-scope-candidates.sh" 2>/dev/null )
  git -C "$M" worktree add -q --detach "$REPO/wt" HEAD || { no "픽스처 worktree 실패"; rmrepo; return; }
  TREE="$REPO/wt"
  printf '%s\n' "$cands" | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null
  assert_eq "$(arow tests/test_uses.sh)" "shell	file" "helper_reached_only_by_folder: 이름이 맞지 않는 테스트도 폴더로 닿아 배정 행이 있다"
  assert_eq "$(arow tests/lib.sh)" "support	file" "helper_reached_only_by_folder: 바뀐 도우미는 support 행이다(silent-drop 이 아니다)"
  rmrepo
}
case_bulk_absorber_unchanged() {
  mkrepo; shtest tests/a.sh 0; printf 'x\n' > "$REPO/main/tests/data.tsv"; printf 'test:\n\ttrue\n' > "$REPO/main/Makefile"
  mktree || { rmrepo; return; }
  assign tests/data.tsv tests/a.sh
  assert_eq "$(arow BULK)" "make	bulk" "bulk_absorber_unchanged: 흡수 러너가 있으면 지원 파일도 지금처럼 전체 실행을 부른다"
  assert_eq "$(arow tests/data.tsv)" "" "bulk_absorber_unchanged: 흡수 러너가 있으면 지원 파일의 행이 따로 없다"
  assert_eq "$(awk -F'\t' '$2 == "support"' "$REPO/assign.tsv")" "" "bulk_absorber_unchanged: support 행이 없다"
  rmrepo
}
case_scope_empty_unchanged() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  printf '' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null; local rc=$?
  assert_eq "$rc" "0" "scope_empty_unchanged: 후보 0 → exit 0"
  assert_eq "$(cat "$REPO/assign.tsv")" "#qg-assign	adapters=shell	rows=0" "scope_empty_unchanged: 돌릴 단위 0 이면 꼬리 줄만(지금과 같다)"
  rmrepo
}

# ── unittest 불러 보기(§5 · AC20 · AC28) ─────────────────────────────────────────────
# mark_on_import <파일> <표지> — 불러올 때 표지 파일을 만드는 진짜 TestCase 테스트(불러 보기가 돌았는지 잰다).
mark_on_import() {
  mkdir -p "$REPO/main/$(dirname "$1")"
  printf 'open(%s, "w").close()\nimport unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\n' "'$2'" > "$REPO/main/$1"
}
case_claims_indirect_testcase() {
  mkrepo; local M="$REPO/main/tests"
  printf 'import unittest\nclass _Base(unittest.TestCase):\n    pass\nclass TestA(_Base):\n    def test_x(self):\n        pass\n' > "$M/test_same_file.py"
  printf 'import unittest\nclass Fix(unittest.TestCase):\n    def helper(self):\n        return 1\n' > "$M/base_fixture.py"
  printf 'from base_fixture import Fix\nclass CrossRepo(Fix):\n    def test_y(self):\n        pass\n' > "$M/test_other_module.py"
  mktree || { rmrepo; return; }
  assign tests/test_same_file.py tests/test_other_module.py
  assert_eq "$(arow tests/test_same_file.py)" "unittest	file" "claims_indirect_testcase: 같은 파일의 부모를 거쳐 TestCase 를 물려받으면 맡는다"
  assert_eq "$(arow tests/test_other_module.py)" "unittest	file" "claims_indirect_testcase: 다른 모듈의 부모를 거쳐 물려받는 Test 아닌 이름 클래스도 맡는다"
  rmrepo
}
case_refuses_plain_test_class() {
  mkrepo
  printf 'import unittest\nclass TestReal(unittest.TestCase):\n    def test_x(self):\n        pass\nclass TestFoo:\n    def test_y(self):\n        pass\n' > "$REPO/main/tests/test_side.py"
  mktree || { rmrepo; return; }
  assign tests/test_side.py
  assert_eq "$(arow tests/test_side.py)" "unclaimed	file" "refuses_plain_test_class: TestCase 클래스 옆 class TestFoo: → unclaimed"
  rmrepo
}
case_refuses_object_parent_nontest_name() {
  mkrepo
  printf 'import unittest\nclass TestReal(unittest.TestCase):\n    def test_x(self):\n        pass\nclass CrossRepo(object):\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_obj.py"
  mktree || { rmrepo; return; }
  assign tests/test_obj.py
  assert_eq "$(arow tests/test_obj.py)" "unclaimed	file" "refuses_object_parent_nontest_name: 부모가 object 인 CrossRepo 에 test 메서드 → unclaimed"
  rmrepo
}
case_refuses_mixin_with_test_method() {
  mkrepo
  printf 'import unittest\nclass Shared:\n    def test_shared(self):\n        pass\nclass TestA(Shared, unittest.TestCase):\n    pass\n' > "$REPO/main/tests/test_mixin.py"
  mktree || { rmrepo; return; }
  assign tests/test_mixin.py
  assert_eq "$(arow tests/test_mixin.py)" "unclaimed	file" "refuses_mixin_with_test_method: test 메서드를 가진 믹스인을 정의한 파일 → unclaimed"
  rmrepo
}
case_refuses_unimportable() {
  mkrepo
  printf 'import qg_no_such_module_xyz\nimport unittest\nclass TestA(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_broken.py"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'tests/test_broken.py\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  assert_eq "$(arow tests/test_broken.py)" "unclaimed	file" "refuses_unimportable: 불러오지 못하는 파일 → unclaimed"
  assert_contains "$err" "unittest 맡지 않음: tests/test_broken.py" "refuses_unimportable: 맡지 않은 까닭을 알린다"
  rmrepo
}
case_module_level_def_test_refused() {
  mkrepo; local mk="$REPO/MARK_BARE"
  printf 'open(%s, "w").close()\nimport unittest\nclass TestA(unittest.TestCase):\n    def test_x(self):\n        pass\ndef test_bare():\n    pass\n' "'$mk'" > "$REPO/main/tests/test_bare_mark.py"
  mktree || { rmrepo; return; }
  assign tests/test_bare_mark.py
  assert_eq "$(arow tests/test_bare_mark.py)" "unclaimed	file" "module_level_def_test_refused: 모듈 수준 def test 가 있으면 지금처럼 맡지 않는다"
  [ ! -e "$mk" ] && ok "module_level_def_test_refused: 글자로 거른 파일은 불러 보지 않는다" || no "module_level_def_test_refused: 모듈 수준 def test 파일을 불러 봤다"
  rmrepo
}
case_imported_testclient_ignored() {
  mkrepo; local M="$REPO/main/tests"
  printf 'class TestClient:\n    def test_get(self):\n        return 1\n' > "$M/webstub.py"
  printf 'import unittest\nfrom webstub import TestClient\nclass TestApi(unittest.TestCase):\n    def test_x(self):\n        self.assertEqual(TestClient().test_get(), 1)\n' > "$M/test_api.py"
  mktree || { rmrepo; return; }
  assign tests/test_api.py
  assert_eq "$(arow tests/test_api.py)" "unittest	file" "imported_testclient_ignored: 가져온 TestClient(TestCase 아님)는 보지 않는다"
  rmrepo
}
case_probe_ignores_module_stdout_and_exit() {
  mkrepo; local M="$REPO/main/tests"
  printf 'import unittest\nprint("tests/test_print.py\\tclaim")\nclass TestReal(unittest.TestCase):\n    def test_x(self):\n        pass\nclass TestFoo:\n    def test_y(self):\n        pass\n' > "$M/test_print.py"
  printf 'import sys\nimport unittest\nclass TestA(unittest.TestCase):\n    def test_x(self):\n        pass\nsys.exit(0)\n' > "$M/test_exit.py"
  printf 'import unittest\nclass TestB(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$M/test_after.py"
  mktree || { rmrepo; return; }
  local out; out=$(printf 'tests/test_print.py\ntests/test_exit.py\ntests/test_after.py\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null)
  assert_eq "$out" "" "probe_ignores_module_stdout_and_exit: 모듈이 찍은 글은 assign 의 표준 출력에 나오지 않는다"
  assert_eq "$(arow tests/test_print.py)" "unclaimed	file" "probe_ignores_module_stdout_and_exit: 판정 꼴 글을 찍는 모듈도 판정은 파일로만 — unclaimed"
  assert_eq "$(arow tests/test_exit.py)" "unclaimed	file" "probe_ignores_module_stdout_and_exit: 불러오다 sys.exit(0) 하는 모듈 → unclaimed"
  assert_eq "$(arow tests/test_after.py)" "unittest	file" "probe_ignores_module_stdout_and_exit: 같은 폴더의 다음 파일은 그대로 판정된다(양성 대조)"
  rmrepo
}
case_kill_switch_no_probe() {
  mkrepo; local mk="$REPO/MARK_KS"; mark_on_import tests/test_k.py "$mk"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'tests/test_k.py\n' | DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  [ ! -e "$mk" ] && ok "kill_switch_no_probe: kill switch 가 켜지면 테스트 모듈을 불러 보지 않는다" || no "kill_switch_no_probe: kill switch 인데 모듈이 돌았다"
  assert_eq "$(arow tests/test_k.py)" "unclaimed	file" "kill_switch_no_probe: unittest 가 맡지 않는다"
  assert_contains "$err" "DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 로 꺼져 있다" "kill_switch_no_probe: 사유를 알린다"
  assign tests/test_k.py
  [ -e "$mk" ] && ok "kill_switch_no_probe: 양성 대조 — 켜지 않으면 불러 본다(표지가 생긴다)" || no "kill_switch_no_probe: 양성 대조인데 표지가 없다"
  assert_eq "$(arow tests/test_k.py)" "unittest	file" "kill_switch_no_probe: 양성 대조 — 맡는다"
  rmrepo
}
case_setup_failure_no_probe() {
  mkrepo; local mk="$REPO/MARK_SETUP"; mark_on_import tests/test_s.py "$mk"
  printf '!!!not-a-requirement\n' > "$REPO/main/requirements.txt"; printf '.venv/\n' > "$REPO/main/.gitignore"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'tests/test_s.py\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  [ ! -e "$mk" ] && ok "setup_failure_no_probe: 준비가 실패하면 불러 보지 않는다" || no "setup_failure_no_probe: 준비가 실패했는데 모듈이 돌았다"
  assert_contains "$err" "setup 실패" "setup_failure_no_probe: 사유를 알린다"
  assert_eq "$(arow tests/test_s.py)" "unclaimed	file" "setup_failure_no_probe: unittest 가 맡지 않는다"
  rmrepo
}
case_env_dir_not_ignored_no_probe() {
  mkrepo; local mk="$REPO/MARK_ENV"; mark_on_import tests/test_e.py "$mk"
  printf 'six\n' > "$REPO/main/requirements.txt"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'tests/test_e.py\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  [ ! -e "$mk" ] && ok "env_dir_not_ignored_no_probe: 환경 폴더를 무시하지 않는 트리는 불러 보지 않는다" || no "env_dir_not_ignored_no_probe: 모듈이 돌았다"
  [ ! -e "$TREE/.venv" ] && ok "env_dir_not_ignored_no_probe: 준비도 하지 않았다(.venv 없음)" || no "env_dir_not_ignored_no_probe: .venv 가 생겼다"
  assert_contains "$err" "gitignore 하지 않는다" "env_dir_not_ignored_no_probe: 사유를 알린다"
  assert_eq "$(arow tests/test_e.py)" "unclaimed	file" "env_dir_not_ignored_no_probe: unittest 가 맡지 않는다"
  rmrepo
}
case_attached_tree_no_probe() {
  mkrepo; local mk="$REPO/MARK_ATT"; mark_on_import tests/test_t.py "$mk"
  ( cd "$REPO/main" && git add -A && git commit -qm t ) || { no "픽스처 커밋 실패"; rmrepo; return; }
  git -C "$REPO/main" worktree add -q -b side "$REPO/attached" >/dev/null 2>&1 || { no "픽스처 worktree 실패"; rmrepo; return; }
  local t err
  for t in "$REPO/main" "$REPO/attached"; do
    err=$(printf 'tests/test_t.py\n' | bash "$RTS" assign "$t" "$REPO/assign.tsv" 2>&1 >/dev/null)
    assert_eq "$(arow tests/test_t.py)" "unclaimed	file" "attached_tree_no_probe: 일회용 트리가 아니면 unittest 가 맡지 않는다 ($(basename "$t"))"
    assert_contains "$err" "run-test-selection: unittest 판정 안 함 — 일회용 트리가 아니다 (in $t)" "attached_tree_no_probe: 사유를 알린다 ($(basename "$t"))"
  done
  git -C "$REPO/main" checkout -q --detach
  printf 'tests/test_t.py\n' | bash "$RTS" assign "$REPO/main" "$REPO/assign.tsv" 2>/dev/null
  assert_eq "$(arow tests/test_t.py)" "unclaimed	file" "attached_tree_no_probe: detached 여도 주 작업 트리면 맡지 않는다"
  [ ! -e "$mk" ] && ok "attached_tree_no_probe: 그 트리의 테스트 모듈 코드가 돌지 않았다" || no "attached_tree_no_probe: 붙은 트리에서 모듈이 돌았다"
  rmrepo
}
# zero_axes <python3 심 폴더|-> — 테스트 0개인 맡는 파일(점 이름 꼴 · discover 꼴)을 기준선 · HEAD 두 트리에서 돌려 행 상태를 낸다.
zero_axes() {
  mkrepo; local M="$REPO/main" shim=$1
  mkdir -p "$M/pkg/tests"; : > "$M/pkg/__init__.py"; : > "$M/pkg/tests/__init__.py"
  printf 'import unittest\n' > "$M/tests/test_none.py"; printf 'import unittest\n' > "$M/pkg/tests/test_none2.py"
  ( cd "$M" && git add -A && git commit -qm base ) || { no "픽스처 커밋 실패"; return 1; }
  printf '# head\n' >> "$M/tests/test_none.py"; printf '# head\n' >> "$M/pkg/tests/test_none2.py"
  mktree || return 1
  git -C "$M" worktree add -q --detach "$REPO/base" HEAD~1 || { no "기준선 worktree 실패"; return 1; }
  local P=$PATH; [ "$shim" != - ] && P="$shim:$PATH"
  printf 'tests/test_none.py\npkg/tests/test_none2.py\n' | PATH=$P bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null
  PATH=$P bash "$RTS" run "$REPO/base" unittest per-unit "$REPO/b.tsv" tests/test_none.py pkg/tests/test_none2.py 2>/dev/null
  PATH=$P bash "$RTS" run "$TREE" unittest per-unit "$REPO/h.tsv" tests/test_none.py pkg/tests/test_none2.py 2>/dev/null
  ZA="$(arow tests/test_none.py)|$(arow pkg/tests/test_none2.py)|$(row_of "$REPO/b.tsv" tests/test_none.py | cut -f1,2)|$(row_of "$REPO/b.tsv" pkg/tests/test_none2.py | cut -f1,2)|$(row_of "$REPO/h.tsv" tests/test_none.py | cut -f1,2)|$(row_of "$REPO/h.tsv" pkg/tests/test_none2.py | cut -f1,2)"
}
ZERO_WANT="unittest	file|unittest	file|error	5|error	5|error	5|error	5"
case_zero_tests_is_error_both_axes() {
  ZA=""; zero_axes - || { rmrepo; return; }
  assert_eq "$ZA" "$ZERO_WANT" "zero_tests_is_error_both_axes: 테스트 0개 실행은 기준선 · HEAD 두 축에서 error(종료 5) — 점 이름 · discover 두 꼴 ($(python3 --version 2>&1))"
  rmrepo
}
# pick_python <low|high> — 3.12 보다 낮은 · 3.12 이상인 파이썬 실행 파일 경로를 하나 낸다(없으면 빈 값).
pick_python() {
  local c v
  for c in /usr/bin/python3 python3.9 python3.10 python3.11 python3.12 python3.13 python3.14 \
           "$(uv python find 3.12 2>/dev/null)" "$(uv python find 3.9 2>/dev/null)"; do
    [ -n "$c" ] || continue
    c=$(command -v "$c" 2>/dev/null) || continue
    v=$("$c" -c 'import sys; print(sys.version_info >= (3, 12))' 2>/dev/null) || continue
    case "$1:$v" in low:False|high:True) printf '%s\n' "$c"; return 0 ;; esac
  done
  return 1
}
zero_with() {   # zero_with <low|high>
  local py shim
  py=$(pick_python "$1") || { no "zero_tests_low_python: 이 기계에 $1 판 파이썬이 없다 — 이 케이스를 돌지 못했다(통과로 세지 않는다)"; return; }
  shim=$(mktemp -d) && [ -d "$shim" ] || { no "심 폴더 mktemp 실패"; return; }
  printf '#!/bin/bash\nexec %q "$@"\n' "$py" > "$shim/python3"; chmod +x "$shim/python3"
  local v; v=$(PATH="$shim:$PATH" python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
  ok "zero_tests_low_python: 심의 python3 는 $v ($1)"
  ZA=""; zero_axes "$shim" || { rmrepo; rm -rf "$shim"; return; }
  assert_eq "$ZA" "$ZERO_WANT" "zero_tests_low_python: 파이썬 $v 에서도 테스트 0개 실행은 두 축에서 같은 error"
  rmrepo; rm -rf "$shim"
}
case_zero_tests_low_python() { zero_with low; zero_with high; }
# P16 — 지원 파일의 support / unclaimed 는 불러 보기가 정한 최종 맡음으로 가른다.
case_support_after_probe() {
  mkrepo; local M="$REPO/main/tests"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$M/test_real.py"
  printf 'class TestHelper:\n    def test_x(self):\n        pass\n' > "$M/test_plain.py"
  mkdir -p "$REPO/main/other/tests"; cp "$M/test_plain.py" "$REPO/main/other/tests/test_plain.py"
  printf '{}\n' > "$M/data.json"; printf '{}\n' > "$REPO/main/other/tests/data.json"
  mktree || { rmrepo; return; }
  assign tests/data.json tests/test_real.py other/tests/data.json other/tests/test_plain.py
  assert_eq "$(arow tests/test_real.py)" "unittest	file" "support_after_probe: 불러 보기가 형제 테스트를 맡는다"
  assert_eq "$(arow tests/data.json)" "support	file" "support_after_probe: 그 뒤 같은 폴더의 지원 파일이 support"
  assert_eq "$(arow other/tests/test_plain.py)" "unclaimed	file" "support_after_probe: 불러 보기가 거절한 테스트"
  assert_eq "$(arow other/tests/data.json)" "unclaimed	file" "support_after_probe: 형제를 맡지 않으면 지원 파일은 unclaimed"
  rmrepo
}
# AC20 — 이 레포에서 지금 거절되던 여섯 파일은 일회용 트리에서 `uv run python` 으로 불러 보면 맡겨진다.
case_six_repo_files_claimed() {
  local ROOT C W six f rows err
  ROOT=$(cd "$SCRIPT_DIR/../../.." && pwd)
  command -v uv >/dev/null 2>&1 || { no "six_repo_files_claimed: uv 가 없어 돌지 못했다(통과로 세지 않는다)"; return; }
  C=$(mktemp -d) && [ -d "$C" ] || { no "mktemp 실패"; return; }
  git clone -q --shared --no-checkout "$ROOT" "$C/clone" 2>/dev/null \
    && git -C "$C/clone" worktree add -q --detach "$C/wt" "$(git -C "$ROOT" rev-parse HEAD)" 2>/dev/null \
    || { no "six_repo_files_claimed: 일회용 트리를 만들지 못했다"; rm -rf "$C"; return; }
  six="plugins/quality-gates/tests/test_other_teams.py plugins/spec-distill/tests/test_brief_review_state.py
plugins/spec-distill/tests/test_conductor_cross.py plugins/spec-distill/tests/test_conductor_status.py
plugins/spec-distill/tests/test_leader_seat.py plugins/spec-distill/tests/test_roadmap_draft_entry.py"
  err=$(printf '%s\n' $six | bash "$RTS" assign "$C/wt" "$C/assign.tsv" 2>&1 >/dev/null)
  for f in $six; do
    rows=$(awk -F'\t' -v u="$f" '$1 == u { print $2 "\t" $3 }' "$C/assign.tsv" 2>/dev/null)
    assert_eq "$rows" "unittest	file" "six_repo_files_claimed: $f → unittest file"
  done
  if printf '%s\n' "$err" | grep -qE 'setup 실패|러너 실행 불가|일회용 트리가 아니다'; then
    printf '    배정 stderr(관문에서 멈췄다):\n'; printf '%s\n' "$err" | tail -5 | sed 's/^/      /'
  fi
  rm -rf "$C"
}

# 실행 줄은 `-m unittest` 와 같은 경로 꼴이다 — sys.path[0] 이 '' 가 아니라 그때의 작업 폴더 절대경로라, setUp 에서
# 작업 폴더를 옮긴 뒤 최상위 모듈을 늦게 불러도 찾는다.
case_run_chdir_lazy_import() {
  mkrepo; local M="$REPO/main"
  printf 'V = 1\n' > "$M/toplib.py"; : > "$M/tests/__init__.py"
  printf 'import importlib, os, tempfile, unittest\nclass T(unittest.TestCase):\n    def setUp(self):\n        self.old = os.getcwd()\n        os.chdir(tempfile.mkdtemp())\n    def tearDown(self):\n        os.chdir(self.old)\n    def test_x(self):\n        self.assertEqual(importlib.import_module("toplib").V, 1)\n' > "$M/tests/test_chdir.py"
  mkdir -p "$M/flat"
  printf 'import importlib, os, tempfile, unittest\nclass T(unittest.TestCase):\n    def setUp(self):\n        self.old = os.getcwd()\n        os.chdir(tempfile.mkdtemp())\n    def tearDown(self):\n        os.chdir(self.old)\n    def test_x(self):\n        self.assertEqual(importlib.import_module("toplib").V, 1)\n' > "$M/flat/test_chdir2.py"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" unittest per-unit "$REPO/rows.tsv" tests/test_chdir.py 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/test_chdir.py | cut -f1,2)" "pass	0" "run_chdir_lazy_import: 작업 폴더를 옮긴 뒤 최상위 모듈을 늦게 불러도 통과(점 이름 꼴 — -m unittest 와 같은 sys.path[0])"
  bash "$RTS" run "$TREE" unittest per-unit "$REPO/rows.tsv" flat/test_chdir2.py 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" flat/test_chdir2.py | cut -f1,2)" "pass	0" "run_chdir_lazy_import: discover 꼴도 같다"
  rmrepo
}
# 불러 보기 판정은 파일마다 결과 줄이 정확히 하나일 때만 읽는다. 모듈이 불러 보기의 쓰기 함수를 __main__ 에서 찾아
# 부르거나, 열린 결과 파일을 찾아 claim 줄을 더 써도 맡겨지지 않는다.
case_probe_refuses_forged_line() {
  mkrepo; local M="$REPO/main/tests"
  printf 'import unittest\ntry:\n    import __main__\n    __main__.put("tests/test_forge_main.py", "claim")\nexcept Exception:\n    pass\nclass TestFoo:\n    def test_y(self):\n        pass\n' > "$M/test_forge_main.py"
  printf 'import gc, io, unittest\nfor o in gc.get_objects():\n    if isinstance(o, io.TextIOWrapper) and ".qg-probe" in str(getattr(o, "name", "")) and not o.closed:\n        o.write("tests/test_forge_file.py\\tclaim\\n"); o.flush()\nclass TestFoo:\n    def test_y(self):\n        pass\n' > "$M/test_forge_file.py"
  printf 'import unittest\nclass TestOk(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$M/test_ok.py"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'tests/test_forge_main.py\ntests/test_forge_file.py\ntests/test_ok.py\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  assert_eq "$(arow tests/test_forge_main.py)" "unclaimed	file" "probe_refuses_forged_line: __main__ 의 쓰기 함수를 불러 claim 을 심어도 맡지 않는다"
  assert_eq "$(arow tests/test_forge_file.py)" "unclaimed	file" "probe_refuses_forged_line: 결과 파일에 claim 줄을 더 써도 맡지 않는다(줄이 둘)"
  assert_contains "$err" "unittest 맡지 않음: tests/test_forge_file.py — 판정 줄이 2개" "probe_refuses_forged_line: 줄이 여럿이면 그 사실을 알린다"
  assert_eq "$(arow tests/test_ok.py)" "unittest	file" "probe_refuses_forged_line: 양성 대조 — 같은 폴더의 진짜 테스트는 맡는다"
  rmrepo
}
# 배정 파일을 상대 경로로 넘기고 트리 밖에서 불러도 불러 보기 결과 파일은 같은 파일이다 — 맡는 테스트가 맡겨진다.
case_probe_relative_assign_path() {
  mkrepo
  printf 'import unittest\nclass TestOk(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_ok.py"
  mktree || { rmrepo; return; }
  mkdir -p "$REPO/out"
  ( cd "$REPO/out" && printf 'tests/test_ok.py\n' | bash "$RTS" assign "$TREE" assign.tsv 2>/dev/null )
  assert_eq "$(awk -F'\t' '$1 == "tests/test_ok.py" { print $2 "\t" $3 }' "$REPO/out/assign.tsv")" "unittest	file" \
    "probe_relative_assign_path: 상대 경로 배정 파일에서도 unittest 가 맡는다"
  assert_eq "$(ls -A "$TREE" | grep -c '^\.qg-probe\.')" "0" "probe_relative_assign_path: 트리 안에 불러 보기 결과 파일이 남지 않는다"
  assert_eq "$(ls -A "$REPO/out" | grep -c '^\.qg-probe\.')" "0" "probe_relative_assign_path: 배정 폴더에도 남지 않는다"
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
         case_R20_run_rechecks_scope case_unrun_and_pending case_truncated_rows_file_is_refused \
         case_rows_count_mismatch_is_refused case_trailer_values_are_validated \
         case_support_row_when_folder_claimed case_unclaimed_when_folder_has_no_claimed_test \
         case_support_skips_spike_fixtures_folders case_test_named_unclaimed_stays case_helper_reached_only_by_folder case_bulk_absorber_unchanged \
         case_scope_empty_unchanged \
         case_claims_indirect_testcase case_refuses_plain_test_class case_refuses_object_parent_nontest_name \
         case_refuses_mixin_with_test_method case_refuses_unimportable case_module_level_def_test_refused \
         case_imported_testclient_ignored case_probe_ignores_module_stdout_and_exit case_kill_switch_no_probe \
         case_setup_failure_no_probe case_env_dir_not_ignored_no_probe case_attached_tree_no_probe \
         case_zero_tests_is_error_both_axes case_zero_tests_low_python case_support_after_probe \
         case_six_repo_files_claimed case_run_chdir_lazy_import case_probe_refuses_forged_line case_probe_relative_assign_path; do
  echo "== $c"; $c
done
finish
