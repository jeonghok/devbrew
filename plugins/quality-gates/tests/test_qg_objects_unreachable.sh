#!/usr/bin/env bash
# test_qg_objects_unreachable.sh — qg 가 만드는 커밋(봉인 · 재봉인 · 합치기 중간 · 합친 HEAD)은
# ref · reflog 를 얻지 않는다 → git 의 prune 이 회수한다 (계획 R-AN).
# 도달 가능해지는 순간 그 커밋과 그것이 담은 트리 · blob 은 영영 회수되지 않는다.
#
# 각 케이스는 mktemp 아래 일회용 git 리포를 세운다 — 실제 리포에서 fixture git 실행 금지.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
TH="$PLUGIN_ROOT/scripts/topic-head.sh"
WT="$PLUGIN_ROOT/scripts/qg-worktree.sh"
SEALER="$PLUGIN_ROOT/scripts/seal-worktree.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

KEY='docs/x-design.md#pr1'
SID='sessgc123456'
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

new_topic_repo() {   # 형제 둘 + 미커밋 변경. CWD = 리포, 현재 = topicB
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; mkdir -p docs; echo d > docs/x-design.md; git add -A; git commit -qm r0
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; echo a > a.txt; git add a.txt; git commit -qm "a1

Spec: $KEY"
  git checkout -q -b topicB "$R"; echo b > b.txt; git add b.txt; git commit -qm "b1

Spec: $KEY"
  echo dirty > wip.txt
}

qg_commits() {   # 이 리포에서 qg 저자가 쓴 커밋 전부 — 도달 여부와 무관하게
  git cat-file --batch-all-objects --batch-check='%(objectname) %(objecttype)' \
    | awk '$2=="commit"{print $1}' \
    | while read -r c; do
        git cat-file -p "$c" | grep -q '^author qg seal <qg-seal@devbrew\.local> ' && echo "$c"
      done
}
unreachable_commits() { git fsck --unreachable --no-progress 2>/dev/null | awk '$1=="unreachable" && $2=="commit"{print $3}'; }

case_topic_run_leaves_no_reachable_qg_commit() {
  new_topic_repo
  local out H h; out=$(bash "$TH" "$SID"); H=$(field head_commit "$out")
  h=$(bash "$WT" create-head "$H" "$SID" --topic "$KEY") || { no "create-head --topic 실패"; cleanup; return; }
  # 양의 짝 — 살아 있는 HEAD 축 워크트리는 그 커밋을 붙잡는다(도달성 검사가 이빨을 가진다)
  assert_not_grep "$(unreachable_commits)" "^$H\$" "살아 있는 워크트리의 HEAD 커밋은 도달 가능하다(양의 짝)"
  bash "$WT" remove "$h" >/dev/null 2>&1
  local qg un c bad=0 refd=0
  qg=$(qg_commits); un=$(unreachable_commits)
  assert_eq "$([ "$(printf '%s\n' "$qg" | grep -c .)" -ge 2 ] && echo enough)" "enough" "qg 커밋이 둘 이상 생겼다(봉인 · 합치기 — 공허하지 않다)"
  for c in $qg; do
    printf '%s\n' "$un" | grep -qx "$c" || bad=$((bad+1))
    [ -z "$(git for-each-ref --contains "$c")" ] || refd=$((refd+1))
  done
  assert_eq "$bad" "0" "remove 뒤 qg 커밋 전부가 fsck --unreachable 에 잡힌다(reflog 포함)"
  assert_eq "$refd" "0" "어떤 ref 도 qg 커밋을 담지 않는다"
  cleanup
}

case_session_run_leaves_no_reachable_qg_commit() {
  new_topic_repo
  local S h; S=$(bash "$SEALER" seal "$SID")
  h=$(bash "$WT" create-head "$S" "$SID") || { no "create-head 실패"; cleanup; return; }
  bash "$WT" remove "$h" >/dev/null 2>&1
  local qg un c bad=0
  qg=$(qg_commits); un=$(unreachable_commits)
  assert_eq "$([ "$(printf '%s\n' "$qg" | grep -c .)" -ge 1 ] && echo some)" "some" "봉인 커밋이 생겼다"
  for c in $qg; do printf '%s\n' "$un" | grep -qx "$c" || bad=$((bad+1)); done
  assert_eq "$bad" "0" "session 경로도 봉인 · 재봉인 커밋이 전부 도달 불가"
  cleanup
}

for c in case_topic_run_leaves_no_reachable_qg_commit case_session_run_leaves_no_reachable_qg_commit; do
  echo "== $c"; $c
done
finish
