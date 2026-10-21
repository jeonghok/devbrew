#!/usr/bin/env bash
# resolve-baseline.sh — 공유 baseline resolution (design 2026-08-01 §5.2 R-init, AC4).
# 기준 브랜치는 `refs/remotes/origin/HEAD` 가 가리키는 ref 하나다 — 다른 후보로 대신하지 않는다.
# + merge-base + shallow/detached 감지.
#
# Output (stdout, 항상 7줄 — 소비자는 **키로** 파싱한다, 줄 번호가 아니라):
#   base:            <display short-name | ->    사람에게 보여줄 이름(전체 이름에서 refs/remotes/origin/ 을 벗긴 것)
#   base_ref:        <git-usable ref | ->        존재가 확인된 전체 ref (refs/remotes/origin/<base>)
#   merge_base:      <full sha | ->              git merge-base <base_ref> HEAD
#   degraded:        yes|no                      yes면 위 3키는 전부 '-'
#   degraded_reason: -|no-default-branch|not-a-repo|no-head|detached|shallow|merge-base
#                                                degraded: no 면 '-'
#   same_as_head:    yes|no|-                    merge_base 가 HEAD 와 동일한가
#   ahead:           <N | ->                     merge_base..HEAD 커밋 수
#
# no-default-branch 면 stderr 에 고치는 법 한 줄(`[resolve-baseline] …`)을 낸다.
#
# `same_as_head` / `ahead` 는 **차등 실행 가능성**을 실어 나른다 — `degraded` 와 별개
# 키인 이유가 load-bearing 이다. merge_base == HEAD 는 두 가지로 생긴다:
#
#   (1) 정상 — 기본 브랜치 위에서 커밋 없이 워킹트리만 고친 상태. Review 게이트의
#       changes-exist floor 는 이 상태를 **정상으로 봐야 한다** (worktree_dirty 로
#       변경을 잡는다). 여기서 degrade 하면 floor 가 통째로 꺼진다.
#   (2) 변조 — base ref(`refs/remotes/origin/HEAD` 와 그것이 가리키는 ref)는 **공유
#       common gitdir** 에 있고, `run` 이 실행하는 저장소 코드가 호스트 권한으로
#       `git update-ref` 를 할 수 있다. base 를 HEAD 로 옮기면 기준선 트리가 리뷰 대상
#       코드 자체가 되어 모든 진짜 회귀가 (fail,fail)=PRE_EXISTING 으로 접힌다.
#
# 두 경우를 여기서 구분할 방법은 없다 — 그래서 **판정하지 않고 사실만 emit** 한다.
# 소비자가 자기 축에서 결정한다: Runtime 게이트는 `same_as_head: yes` 를 "차등 증거
# 생성 불가" 로 읽어 PASS 를 막고, Review 게이트의 changes-exist floor 는 이 키를
# 읽지 않아 (1) 에서 동작이 변하지 않는다.
#
# `ahead` 는 **부분 변조**용 disclosure 다. base 를 HEAD 로가 아니라 브랜치 중간
# 커밋으로 옮기면 `same_as_head` 는 no 이고 기준선 트리는 여전히 만들어진다 —
# 그 창을 닫는 결정론 수단은 이 스크립트에 없다(신뢰 채널이 없다). 대신 커밋 수를
# 노출해 61커밋 브랜치가 `ahead: 1` 로 보고되는 것을 사람이 보게 한다.
#
# Exit: 항상 0 (degraded: yes가 fail-open 상태를 실어 나른다). 인자 없음. read-only.
set -u

emit_degraded() {   # <degraded_reason>
  echo "base: -"
  echo "base_ref: -"
  echo "merge_base: -"
  echo "degraded: yes"
  echo "degraded_reason: $1"
  echo "same_as_head: -"
  echo "ahead: -"
  exit 0
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit_degraded not-a-repo
git rev-parse --verify --quiet HEAD  >/dev/null 2>&1 || emit_degraded no-head
# detached HEAD → 비교할 브랜치 컨텍스트 없음 → degraded.
git symbolic-ref --quiet HEAD        >/dev/null 2>&1 || emit_degraded detached
# shallow clone → 잘린 히스토리 → merge-base가 grafted boundary로 조용히 resolve될 수 있음.
[[ "$(git rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]] && emit_degraded shallow

# `symbolic-ref` 는 **대상의 존재를 검증하지 않는다** — 기본 브랜치 개명 뒤 남는 dangling
# `origin/HEAD` 도 여기서 성공한다. 가리키는 ref 가 실제로 있을 때만 받아들인다.
# 짧은 이름은 `--short` 가 아니라 전체 이름에서 접두를 벗겨 얻는다.
full=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null) || full=""
base=""
case "$full" in
  refs/remotes/origin/?*) base="${full#refs/remotes/origin/}" ;;
esac
if [[ -z "$base" ]] || ! git rev-parse --verify --quiet "$full^{commit}" >/dev/null 2>&1; then
  echo "[resolve-baseline] 기본 브랜치를 찾지 못했다 — origin/HEAD 가 없거나 가리키는 브랜치가 없다. git remote set-head origin --auto 로 고친다" >&2
  emit_degraded no-default-branch
fi
# 짧은 이름(origin/<base>)은 같은 이름의 로컬 브랜치가 먼저 풀리므로 전체 이름을 낸다.
base_ref="$full"

merge_base=$(git merge-base "$full" HEAD 2>/dev/null) || emit_degraded merge-base
[[ -n "$merge_base" ]] || emit_degraded merge-base

head_sha=$(git rev-parse HEAD 2>/dev/null) || emit_degraded no-head
if [[ "$merge_base" == "$head_sha" ]]; then same_as_head=yes; else same_as_head=no; fi

# 실패를 0 으로 접지 않는다 — `ahead: 0` 은 "커밋 없음"이라는 **주장**이고, 질의
# 실패는 주장할 근거가 없는 상태다. 둘을 같은 값으로 내면 소비자가 구분할 수 없다.
ahead=$(git rev-list --count "$merge_base..HEAD" 2>/dev/null) || ahead="-"
[[ -n "$ahead" ]] || ahead="-"

echo "base: $base"
echo "base_ref: $base_ref"
echo "merge_base: $merge_base"
echo "degraded: no"
echo "degraded_reason: -"
echo "same_as_head: $same_as_head"
echo "ahead: $ahead"
exit 0
