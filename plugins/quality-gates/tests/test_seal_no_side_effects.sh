#!/usr/bin/env bash
# test_seal_no_side_effects.sh — scripts/seal-worktree.sh (설계 §6.4.1, AC14).
#
# 회귀 락의 핵심은 **봉인 트리에 임시 인덱스 파일이 없다** 이다 — 설계의 실측이
# 정확히 그 결함(인덱스를 리포 안 추적 자리에 두면 봉인 트리에 들어간다)을 잡았다.
# 위치가 아니라 **결과**를 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SEAL="$PLUGIN_ROOT/scripts/seal-worktree.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

SID="deadbeefcafebabe"
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

mk_repo() {   # .gitignore 가 /.claude/* 를 덮는 정상 리포
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  printf '/.claude/*\n' > .gitignore
  echo tracked > a.txt
  echo doomed  > b.txt
  git add -A; git commit -qm base
}

case_seal_content() {
  mk_repo
  echo "uncommitted" >> a.txt          # 수정
  rm -f b.txt                          # 삭제
  echo "new" > c.txt                   # untracked (ignored 아님)
  mkdir -p .claude/quality-gates
  echo "ignored" > .claude/quality-gates/junk

  local B; B=$(bash "$SEAL" seal "$SID")
  if [ -z "$B" ]; then no "봉인 커밋이 안 나왔다"; cleanup; return; fi
  local names; names=$(git ls-tree -r --name-only "$B")

  assert_grep "$names" '^c\.txt$'        "untracked 파일이 봉인 트리에 든다"
  assert_not_grep "$names" '^b\.txt$'    "삭제가 봉인 트리에 반영된다"
  assert_not_grep "$names" '^\.claude/'  "git-ignored 자리는 봉인 트리에 없다"
  assert_grep "$(git show "$B:a.txt")" 'uncommitted' "미커밋 수정이 봉인 트리에 든다"
  cleanup
}

# ★ AC14 의 핵심 — 실측 결함의 회귀 락
case_no_index_in_tree() {
  mk_repo
  echo "x" >> a.txt
  local B; B=$(bash "$SEAL" seal "$SID")
  assert_grep "$B" '^[0-9a-f]{40}$' "봉인 커밋이 40자 hex 다(전제 확인)"
  local names; names=$(git ls-tree -r --name-only "$B")
  assert_grep "$names" '^a\.txt$' "봉인 트리가 비어 있지 않다(전제 확인)"
  assert_not_grep "$names" 'seal-.*\.index' "봉인 트리에 임시 인덱스 파일이 없다"
  assert_not_grep "$names" '\.lock$'        "봉인 트리에 인덱스 lock 파일이 없다"
  cleanup
}

case_no_side_effects() {
  mk_repo
  echo "x" >> a.txt; echo "y" > d.txt
  local head_before status_before wt_before
  head_before=$(git rev-parse HEAD)
  status_before=$(git status --porcelain | sort)
  wt_before=$(git worktree list | wc -l | tr -d ' ')

  local B; B=$(bash "$SEAL" seal "$SID")
  assert_grep "$B" '^[0-9a-f]{40}$' "봉인 커밋이 40자 hex 다(전제 확인)"

  # ★ fix round 1 IMPORTANT-1 — $B 가 비었을 때 `$B^{tree}` 는 `^{tree}` 로 깨져
  # `git rev-parse` 가 exit 128 에 빈 stdout 을 낸다. 그러면 두 변 다 "" 거나 한쪽만
  # 채워져 "differs" 로 판정되어 **거짓 통과**한다. 그래서 각 tree OID 를 직접
  # `--verify --quiet` 로 읽어 40-hex 인지 먼저 확인하고, 실제 비교는 그 위에서만 한다.
  local seal_tree head_tree
  seal_tree=$(git rev-parse --verify --quiet "$B^{tree}" 2>/dev/null) || seal_tree=""
  head_tree=$(git rev-parse --verify --quiet "HEAD^{tree}" 2>/dev/null) || head_tree=""
  assert_grep "$seal_tree" '^[0-9a-f]{40}$' "봉인 트리 OID 를 읽을 수 있다(전제 확인)"
  if [ -n "$seal_tree" ] && [ -n "$head_tree" ] && [ "$seal_tree" != "$head_tree" ]; then
    ok "봉인 트리가 HEAD 트리와 다르다(미커밋 변경이 들어갔다)"
  else
    no "봉인 트리가 HEAD 트리와 다르다 (seal_tree='$seal_tree' head_tree='$head_tree')"
  fi

  assert_eq "$(git rev-parse HEAD)" "$head_before" "HEAD 불변"
  assert_eq "$(git status --porcelain | sort)" "$status_before" "인덱스·워킹트리 불변"
  assert_eq "$(git worktree list | wc -l | tr -d ' ')" "$wt_before" "추가 워크트리 0"
  cleanup
}

case_index_file_cleaned_up() {
  mk_repo
  echo "x" >> a.txt
  local B; B=$(bash "$SEAL" seal "$SID")
  assert_grep "$B" '^[0-9a-f]{40}$' "봉인 커밋이 40자 hex 다(전제 확인)"
  local left; left=$(find "$(git rev-parse --git-dir)" -name 'qg-seal-*' 2>/dev/null | grep -c .)
  assert_eq "$left" "0" "봉인 후 임시 인덱스 파일이 남지 않는다"
  cleanup
}

# 흔한 사용자 리포 — .claude/ 를 무시하지 않는다(.claude/settings.json 을 커밋한다).
# 봉인은 성공해야 하고, 봉인 트리에 임시 인덱스가 없어야 한다(AC14).
case_seal_succeeds_when_claude_dir_not_ignored() {
  local R; R=$(mktemp -d); cd "$R" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  mkdir -p .claude; echo '{}' > .claude/settings.json
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0001xyz") || rc=$?
  assert_eq "$rc" "0" "무시 설정이 없어도 봉인이 성공한다"
  local names; names=$(git ls-tree -r --name-only "$B" 2>/dev/null)
  assert_not_grep "$names" 'seal-.*\.index' "봉인 트리에 임시 인덱스(와 .lock)가 없다"
  assert_grep     "$names" '^\.claude/settings\.json$' "추적 파일은 그대로 봉인된다(양의 짝)"
  assert_eq "$(git show "$B:a.txt")" "changed" "워킹트리 수정이 봉인에 반영된다"
  cd / && rm -rf "$R"
}

# .claude/ 를 무시하지 않는 리포에서 qg 의 상태 · 중첩 워크트리가 봉인에 들어가면
# create-head 의 재봉인 대조가 거짓으로 죽는다(중첩 워크트리가 embedded repo 로 잡힌다).
case_seal_excludes_qg_namespace() {
  local R; R=$(mktemp -d); cd "$R" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  mkdir -p .claude/quality-gates/sess0002; echo state > .claude/quality-gates/sess0002/pipeline.md
  git worktree add -q --detach .claude/quality-gates/worktrees/base-sess0002 HEAD
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0002xyz") || rc=$?
  assert_eq "$rc" "0" "qg 상태가 워킹트리에 있어도 봉인이 성공한다"
  local names; names=$(git ls-tree -r --name-only "$B" 2>/dev/null)
  assert_not_grep "$names" '^\.claude/quality-gates/' "qg 네임스페이스는 봉인되지 않는다"
  assert_eq "$(git show "$B:a.txt")" "changed" "리뷰 대상 변경은 봉인된다(양의 짝)"
  git worktree remove --force .claude/quality-gates/worktrees/base-sess0002 >/dev/null 2>&1
  cd / && rm -rf "$R"
}

case_usage() {
  mk_repo
  local rc; bash "$SEAL" 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "인자 없이 부르면 exit 2"
  bash "$SEAL" seal "" 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "빈 session-id 는 exit 2"
  cleanup
}

for c in case_seal_content case_no_index_in_tree case_no_side_effects \
         case_index_file_cleaned_up case_seal_succeeds_when_claude_dir_not_ignored \
         case_seal_excludes_qg_namespace case_usage; do
  echo "== $c"; $c
done
finish
