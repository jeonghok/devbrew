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
  local left; left=$(find .claude -name 'seal-*' 2>/dev/null | grep -c .)
  assert_eq "$left" "0" "봉인 후 임시 인덱스 파일이 남지 않는다"
  cleanup
}

# ★ 양성 대조 — 인덱스 자리가 git-ignored 가 아니면 **죽어야** 한다(fail-closed).
#    이 케이스가 없으면 위의 부재 단언들은 「그냥 통과」할 수 있다.
case_fails_closed_when_not_ignored() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  local out rc
  out=$(bash "$SEAL" seal "$SID" 2>&1); rc=$?
  assert_eq "$rc" "2" "인덱스 자리가 ignored 가 아니면 exit 2"
  assert_grep "$out" 'git-ignored'    "사유가 메시지에 있다"
  cleanup
}

# ★ fix round 1 IMPORTANT-2 — .gitignore 가 인덱스 리터럴은 덮지만 그 `.lock`
#   형제는 덮지 않는 자리. check-ignore 이른 가드는 `$rel`(인덱스 자체)만 보므로
#   통과하고, `add -A` 는 자신이 방금 잠근 `.lock` 을 미추적 파일로 주워 트리에
#   넣는다 — 그 결과를 권위 있는 가드가 잡아야 한다(위치가 아니라 결과).
#   스크립트는 건드리지 않고 fixture 로만 그 틈을 재현한다.
case_lock_leak_dies_closed() {
  local sid_short="deadbeef"    # "${SID:0:8}" 과 반드시 일치해야 같은 rel 을 가리킨다
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  printf '.claude/quality-gates/seal-%s.index\n' "$sid_short" > .gitignore   # .lock 형제는 안 덮는다
  echo tracked > a.txt
  git add -A; git commit -qm base
  echo "uncommitted" >> a.txt          # add -A 가 할 일이 있어야 인덱스를 쓰고 락을 잡는다

  local out rc
  out=$(bash "$SEAL" seal "$SID" 2>&1); rc=$?
  assert_eq "$rc" "2" ".lock 형제만 새는 자리에서도 exit 2 (fail-closed)"
  assert_grep "$out" 'AC14' "사유가 AC14 를 인용한다"
  cleanup
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
         case_index_file_cleaned_up case_fails_closed_when_not_ignored \
         case_lock_leak_dies_closed case_usage; do
  echo "== $c"; $c
done
finish
