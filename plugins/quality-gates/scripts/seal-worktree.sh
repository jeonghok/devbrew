#!/usr/bin/env bash
# seal-worktree.sh — 워킹트리(수정 · 삭제 · untracked 반영)를 **워크트리 생성 없이**
#   커밋 하나로 봉인한다. (설계 2026-09-21 §6.4.1, AC14)
#
#   seal <session-id>   -> 봉인 커밋 SHA 한 줄 (stdout)
#
# `create-sandbox` 를 대체한다. 그것은 워크트리를 만들고 파일을 한 벌 복사한 뒤
# 커밋했다 — 여기서는 **임시 인덱스**로 같은 트리를 만든다. 워크트리도, 복사도 없다.
#
# **요건은 「리포 밖」이 아니라 「git 이 무시하는 자리」다.** 인덱스를 추적 대상 자리에
# 두면 `.qg-seal-index` 와 그 `.lock` 이 봉인 트리에 들어간다(설계 §7-I 의 실측 결함).
# 그래서 가드가 둘이다 — 봉인 «전» check-ignore, 봉인 «후» 트리 검사. 뒤의 것이
# 권위다: 위치가 아니라 결과를 잰다.
set -u

die() { echo "seal-worktree: $*" >&2; exit 2; }

[ "${1:-}" = "seal" ] || die "usage: seal-worktree.sh seal <session-id>"
sid="${2:-}"
sid_short="${sid:0:8}"
[ -n "$sid_short" ] || die "empty session-id"

main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"

rel=".claude/quality-gates/seal-${sid_short}.index"
SEAL_INDEX="$main_root/$rel"
mkdir -p "$main_root/.claude/quality-gates" || die "cannot create .claude/quality-gates"

# 이른 가드 — 친절한 사유를 준다. 「git add -A」 가 이 자리를 집으면 AC14 가 깨진다.
git -C "$main_root" check-ignore -q "$rel" 2>/dev/null \
  || die "seal index path is not git-ignored: $rel — that path would be sealed into the tree (AC14). Add it to .gitignore."

rm -f "$SEAL_INDEX" "$SEAL_INDEX.lock"
trap 'rm -f "$SEAL_INDEX" "$SEAL_INDEX.lock"' EXIT

# `export` 가 load-bearing 이다 — 그냥 대입하면 아래 git 들이 **실제 인덱스**를 쓴다.
# 서브셸로 감싸 이 스크립트의 나머지 환경에 새지 않게 한다.
B=$(
  export GIT_INDEX_FILE="$SEAL_INDEX"
  cd "$main_root" || exit 1
  git read-tree HEAD || exit 1
  git add -A || exit 1
  TREE=$(git write-tree) || exit 1
  git -c user.email=qg-seal@devbrew.local \
      -c user.name='qg seal' \
      -c commit.gpgsign=false \
      commit-tree "$TREE" -p HEAD -m "qg: sealed" || exit 1
) || die "seal failed"
[ -n "$B" ] || die "seal produced no commit"

# 권위 있는 가드 — **결과**를 잰다. index 자체와 그 .lock 형제 둘 다 대상이다
# (git 이 add -A 자신의 락 파일을 그 add -A 로 줍는 관측이 이 작업에서 나왔다 —
# 설계 §7-I 는 인덱스 자체가 봉인 트리에 들어간다는 것만 기록하고 .lock 은 안 담는다).
if git -C "$main_root" ls-tree -r --name-only "$B" | grep -qE "seal-${sid_short}\.index(\.lock)?$"; then
  die "sealed tree contains the temp index or its lock ($rel) — AC14 violation"
fi

printf '%s\n' "$B"
