#!/usr/bin/env bash
# test_differential_trees.sh — 차등 테스트의 일회용 트리와 실행 안 메모(qg-worktree.sh).
# 요구: R6 · R12 · R23 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WT="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/qg-worktree.sh"
SEAL="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/seal-worktree.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=""
mkrepo() {
  R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
  R=$(cd "$R" && pwd -P)
  git init -q -b main "$R/repo" || exit 1
  git -C "$R/repo" config user.email t@t; git -C "$R/repo" config user.name t; git -C "$R/repo" config commit.gpgsign false
  printf '.claude/\n' > "$R/repo/.gitignore"; echo 1 > "$R/repo/a"
  ( cd "$R/repo" && git add -A && git commit -qm base ) || exit 1
}
rmrepo() { cd / && rm -rf "$R"; }

# R6 — 메모는 검사 대상 트리 밖에 생기고, 표지가 있는 디렉토리만 지운다.
case_R6_memo_lives_outside_the_tree() {
  mkrepo
  local m; m=$(bash "$WT" memo-init "$R/repo" 2>/dev/null)
  [ -n "$m" ] && [ -f "$m/.qg-memo" ] && ok "R6: 메모를 만들고 표지를 둔다" || no "R6: 메모 생성 실패 ($m)"
  case "$m/" in "$R/repo"/*) no "R6: 메모가 트리 안이다" ;; *) ok "R6: 메모는 트리 밖" ;; esac
  bash "$WT" memo-drop "$m"; assert_eq "$?" "0" "R6: memo-drop exit 0"
  [ ! -e "$m" ] && ok "R6: 실행이 끝나면 메모가 사라진다" || no "R6: 메모가 남았다"
  bash "$WT" memo-drop "$m"; assert_eq "$?" "0" "R6: 없는 메모 drop 은 멱등"
  rmrepo
}
case_R6_memo_inside_the_tree_is_refused() {
  mkrepo; mkdir -p "$R/repo/tmp"
  local out rc; out=$(TMPDIR="$R/repo/tmp" bash "$WT" memo-init "$R/repo" 2>/dev/null); rc=$?
  assert_eq "$rc" "2" "R6: TMPDIR 이 트리 안이면 exit 2"
  assert_eq "$(ls -A "$R/repo/tmp")" "" "R6: 거부하면서 만든 디렉토리를 남기지 않는다"
  rmrepo
}
case_R6_memo_drop_refuses_unmarked_dir() {
  mkrepo; mkdir -p "$R/precious"; echo keep > "$R/precious/f"
  bash "$WT" memo-drop "$R/precious" 2>/dev/null; assert_eq "$?" "2" "R6: 표지 없는 디렉토리는 거부"
  [ -f "$R/precious/f" ] && ok "R6: 거부된 디렉토리가 살아 있다" || no "R6: 표지 없는 디렉토리를 지웠다"
  rmrepo
}
# R12 — HEAD 축을 기준선 커밋으로 만들 수 없다(봉인과 트리가 다르면 거부).
case_R12_head_axis_refuses_the_baseline_sha() {
  mkrepo; local base; base=$(git -C "$R/repo" rev-parse HEAD)
  echo 2 > "$R/repo/a"
  ( cd "$R/repo" && bash "$WT" create-head "$base" "sess12345678" ) >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "R12: 기준선 sha 로 HEAD 축을 만들면 거부"
  local sealed; sealed=$( cd "$R/repo" && bash "$SEAL" seal "sess12345678" 2>/dev/null )
  local wt; wt=$( cd "$R/repo" && bash "$WT" create-head "$sealed" "sess12345678" 2>/dev/null ); rc=$?
  assert_eq "$rc" "0" "R12 양성 대조: 지금 봉인으로는 만든다"
  ( cd "$R/repo" && bash "$WT" remove "$wt" ) >/dev/null 2>&1
  rmrepo
}
# R23 — 앞 실행이 남긴 일회용 트리(추적되지 않은 산출물이 있어도)는 다음 실행이 지우고 다시 만든다.
case_R23_stale_tree_is_replaced() {
  mkrepo; local base; base=$(git -C "$R/repo" rev-parse HEAD)
  local wt; wt=$( cd "$R/repo" && bash "$WT" create-baseline "$base" "sess12345678" 2>/dev/null )
  echo junk > "$wt/untracked-output"; echo changed > "$wt/a"
  local wt2 rc; wt2=$( cd "$R/repo" && bash "$WT" create-baseline "$base" "sess12345678" 2>/dev/null ); rc=$?
  assert_eq "$rc" "0" "R23: 남은 트리가 있어도 다시 만든다"
  assert_eq "$wt2" "$wt" "R23: 같은 자리"
  [ ! -e "$wt2/untracked-output" ] && [ "$(cat "$wt2/a")" = "1" ] && ok "R23: 새 트리는 깨끗하다" || no "R23: 앞 실행의 흔적이 남았다"
  ( cd "$R/repo" && bash "$WT" remove "$wt2" ) >/dev/null 2>&1
  [ ! -e "$wt2" ] && ok "R23: remove 가 트리를 지운다" || no "R23: remove 뒤에 트리가 남았다"
  rmrepo
}
case_R23_remove_refuses_outside_namespace() {
  mkrepo; mkdir -p "$R/repo/outside"
  ( cd "$R/repo" && bash "$WT" remove "$R/repo/outside" ) >/dev/null 2>&1; assert_eq "$?" "2" "R23: 이름공간 밖 remove 는 거부"
  [ -d "$R/repo/outside" ] && ok "R23: 거부된 대상이 살아 있다" || no "R23: 이름공간 밖을 지웠다"
  rmrepo
}

# D9 — 리뷰 대상 리포가 커밋한 `.claude` 심볼릭 링크가 리포 밖을 가리켜도 강제 삭제는 리포 밖에서 일어나지 않는다.
case_R23_symlinked_namespace_is_refused() {
  mkrepo; local base; base=$(git -C "$R/repo" rev-parse HEAD)
  mkdir -p "$R/outside/quality-gates/worktrees/base-sess1234"
  echo keep > "$R/outside/quality-gates/worktrees/base-sess1234/f"
  ln -s "$R/outside" "$R/repo/.claude"
  ( cd "$R/repo" && bash "$WT" create-baseline "$base" "sess12345678" ) >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "D9: .claude 가 리포 밖을 가리키면 거부"
  [ -f "$R/outside/quality-gates/worktrees/base-sess1234/f" ] && ok "D9: 리포 밖 디렉토리가 그대로다" || no "D9: 리포 밖을 지웠다"
  rmrepo
}

for c in case_R6_memo_lives_outside_the_tree case_R6_memo_inside_the_tree_is_refused \
         case_R6_memo_drop_refuses_unmarked_dir case_R12_head_axis_refuses_the_baseline_sha \
         case_R23_stale_tree_is_replaced case_R23_remove_refuses_outside_namespace \
         case_R23_symlinked_namespace_is_refused; do
  echo "== $c"; $c
done
finish
