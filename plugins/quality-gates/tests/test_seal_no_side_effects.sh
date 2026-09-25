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

# ★ AC14 의 핵심 — 실측 결함의 회귀 락. **지금은 늘 참이다** — 인덱스가 `.git` 안에만
# 사는 정상 경로에서는 봉인 트리에 이 이름이 들어올 길이 구조적으로 없다. 이 락이
# 실제로 발동하는 형태(gitdir 자체가 워킹트리 하위로 reachable 해진 경우)는
# `case_authoritative_guard_dies_when_index_reachable` 가 갖는다.
case_no_index_in_tree() {
  mk_repo
  echo "x" >> a.txt
  local B; B=$(bash "$SEAL" seal "$SID")
  assert_grep "$B" '^[0-9a-f]{40}$' "봉인 커밋이 40자 hex 다(전제 확인)"
  local names; names=$(git ls-tree -r --name-only "$B")
  assert_grep "$names" '^a\.txt$' "봉인 트리가 비어 있지 않다(전제 확인)"
  assert_not_grep "$names" "(qg-)?seal-${SID:0:8}[^/]*\.index" "봉인 트리에 임시 인덱스 파일이 없다"
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
  local trace; trace=$(mktemp) || exit 1
  local B; B=$(bash -x "$SEAL" seal "$SID" 2>"$trace")
  assert_grep "$B" '^[0-9a-f]{40}$' "봉인 커밋이 40자 hex 다(전제 확인)"
  # 양의 관측 — 사후 find 는 인덱스가 .git 안에만 살아서 구조적으로 항상 0 이다(그것만
  # 으로는 인덱스가 애초에 만들어지긴 했는지 못 잰다). xtrace 로 실행 «중» 실제로
  # qg-seal 이름의 인덱스를 GIT_INDEX_FILE 로 썼다는 것을 직접 본다.
  assert_grep "$(cat "$trace")" "GIT_INDEX_FILE=.*qg-seal-${SID:0:8}\." "실행 중 qg-seal 인덱스를 실제로 썼다(양의 관측)"
  rm -f "$trace"
  local left; left=$(find "$(git rev-parse --git-dir)" -name 'qg-seal-*' 2>/dev/null | grep -c .)
  assert_eq "$left" "0" "봉인 후 임시 인덱스 파일이 남지 않는다"
  cleanup
}

# 흔한 사용자 리포 — .claude/ 를 무시하지 않는다(.claude/settings.json 을 커밋한다).
# 봉인은 성공해야 하고, 봉인 트리에 임시 인덱스가 없어야 한다(AC14).
case_seal_succeeds_when_claude_dir_not_ignored() {
  local R; R=$(mktemp -d) || exit 1; cd "$R" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  mkdir -p .claude; echo '{}' > .claude/settings.json
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0001xyz") || rc=$?
  assert_eq "$rc" "0" "무시 설정이 없어도 봉인이 성공한다"
  local names; names=$(git ls-tree -r --name-only "$B" 2>/dev/null)
  assert_not_grep "$names" '(qg-)?seal-sess0001[^/]*\.index' "봉인 트리에 임시 인덱스(와 .lock)가 없다"
  assert_grep     "$names" '^\.claude/settings\.json$' "추적 파일은 그대로 봉인된다(양의 짝)"
  assert_eq "$(git show "$B:a.txt")" "changed" "워킹트리 수정이 봉인에 반영된다"
  cd / && rm -rf "$R"
}

# .claude/ 를 무시하지 않는 리포에서 qg 의 상태 · 중첩 워크트리가 봉인에 들어가면
# create-head 의 재봉인 대조가 거짓으로 죽는다(중첩 워크트리가 embedded repo 로 잡힌다).
# — check-ignore 가 "무시 안 됨" 을 답하는 갈래(pathspec exclude) 전용.
case_seal_excludes_qg_namespace() {
  local R; R=$(mktemp -d) || exit 1; cd "$R" || exit 1
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

# ★ Fix round 1 IMPORTANT-2 — check-ignore 가 "무시됨" 을 답하는 갈래(plain add -A) 전용
# 양의 짝. devbrew 스타일 .gitignore(mk_repo 의 /.claude/*)가 이미 있는 흔한 리포에서도
# 중첩 워크트리 · 세션 상태가 봉인에 들어가지 않아야 한다 — 위 case 의 "무시 안 됨"
# 갈래와 짝을 이룬다. 이게 없으면 그 갈래는 실측되지 않는다.
case_seal_excludes_qg_namespace_when_ignored() {
  mk_repo
  mkdir -p .claude/quality-gates/sess0004; echo state > .claude/quality-gates/sess0004/pipeline.md
  git worktree add -q --detach .claude/quality-gates/worktrees/base-sess0004 HEAD
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0004xyz") || rc=$?
  assert_eq "$rc" "0" "네임스페이스가 .gitignore 로 이미 덮여 있어도 봉인이 성공한다"
  local names; names=$(git ls-tree -r --name-only "$B" 2>/dev/null)
  assert_not_grep "$names" '^\.claude/quality-gates/' "이미 무시된 네임스페이스도 봉인 트리에 없다"
  assert_eq "$(git show "$B:a.txt")" "changed" "리뷰 대상 변경은 봉인된다(양의 짝)"
  git worktree remove --force .claude/quality-gates/worktrees/base-sess0004 >/dev/null 2>&1
  cleanup
}

# ★ Fix round 1 IMPORTANT-2 — "무시 안 됨" 갈래는 pathspec exclude 라 그 자리 «안»을
# 읽지도 않는다. 옛 add -A + rm --cached 방식은 add 단계에서 그 파일을 읽으려다 죽을 수
# 있었다(리뷰 지적) — 봉인은 그 파일의 가독성과 무관하게 성공해야 한다.
case_seal_succeeds_with_unreadable_file_in_namespace() {
  local R; R=$(mktemp -d) || exit 1; cd "$R" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  mkdir -p .claude/quality-gates/sess0005
  echo secret > .claude/quality-gates/sess0005/secret.txt
  chmod 000 .claude/quality-gates/sess0005/secret.txt
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0005xyz") || rc=$?
  chmod 644 .claude/quality-gates/sess0005/secret.txt   # cleanup(rm -rf) 전 권한 복원
  assert_eq "$rc" "0" "네임스페이스 아래 읽기 불가(chmod 000) 파일이 있어도 봉인이 성공한다"
  local names; names=$(git ls-tree -r --name-only "$B" 2>/dev/null)
  assert_not_grep "$names" '^\.claude/quality-gates/' "네임스페이스는 봉인 트리에 없다"
  cd / && rm -rf "$R"
}

# ★ Fix round 1 IMPORTANT-2 — read-tree HEAD 가 이미 넣어 둔 HEAD 추적 항목은 pathspec
# exclude 가 건드리지 않는다. 옛 add -A + rm --cached 방식은 origin(HEAD 추적 vs 워킹트리
# 변경)을 안 가리고 그 네임스페이스 아래 항목이면 무조건 지웠다(리뷰 지적).
case_seal_preserves_head_tracked_file_in_namespace() {
  local R; R=$(mktemp -d) || exit 1; cd "$R" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  mkdir -p .claude/quality-gates
  echo keepme > .claude/quality-gates/keepme.txt
  echo tracked > a.txt
  git add -A; git commit -qm base    # keepme.txt 가 HEAD 에 이미 커밋돼 있다(.gitignore 없음)
  echo changed > a.txt
  local B rc=0; B=$(bash "$SEAL" seal "sess0006xyz") || rc=$?
  assert_eq "$rc" "0" "봉인이 성공한다"
  assert_eq "$(git show "$B:.claude/quality-gates/keepme.txt" 2>/dev/null)" "keepme" \
    "HEAD 에 이미 커밋된 네임스페이스 파일은 봉인에서 지워지지 않는다"
  cd / && rm -rf "$R"
}

# ★ Fix round 1 IMPORTANT-1 — 권위 있는 post-seal 가드가 실제로 발동하는 형태.
# 인덱스 자리를 워킹트리 안에서 reachable 하게 만드는 유일하게 검증된 방법은 gitdir
# 자체를 워킹트리 하위의 평범한 디렉터리로 옮기는 것(--separate-git-dir)이다 — 그러면
# `--git-path` 가 그 디렉터리 밑을 가리키고, 이름이 `.git` 이 아니므로 git 의 내장
# 스킵을 안 받아 `add -A`(어느 갈래든)가 그 안의 임시 인덱스까지 walk 해서 줍는다.
# 이것이 AC14 실측 결함을 재현하는, 위 case_no_index_in_tree/case_seal_succeeds_…
# 가 «못» 재현하는 유일한 픽스처다.
case_authoritative_guard_dies_when_index_reachable() {
  local R; R=$(mktemp -d) || exit 1; cd "$R" || exit 1
  git init -q --separate-git-dir="$R/gd" .
  git config user.email t@t.test; git config user.name tester
  echo tracked > a.txt; git add -A; git commit -qm base
  echo changed > a.txt
  local out rc=0; out=$(bash "$SEAL" seal "sess0003xyz" 2>&1) || rc=$?
  assert_eq "$rc" "2" "인덱스가 워킹트리에서 reachable 하면 권위 있는 가드가 exit 2 로 죽는다"
  assert_grep "$out" 'sealed tree contains the temp index' "권위 있는(봉인 후) 가드 메시지가 뜬다"
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
         case_seal_excludes_qg_namespace case_seal_excludes_qg_namespace_when_ignored \
         case_seal_succeeds_with_unreadable_file_in_namespace \
         case_seal_preserves_head_tracked_file_in_namespace \
         case_authoritative_guard_dies_when_index_reachable case_usage; do
  echo "== $c"; $c
done
finish
