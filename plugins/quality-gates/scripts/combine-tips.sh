#!/usr/bin/env bash
# combine-tips.sh — 끝점들을 순차 `git merge-tree --write-tree` 로 합쳐 트리 하나를 낸다.
#   (설계 2026-09-21 §6.2.4, AC6·AC7)
#
#   combine-tips.sh <tip1> [<tip2> ...]   -> key: value 6줄
#
# **워크트리를 만들지 않는다.** octopus 를 쓰지 않는 이유는 둘이다(설계 §14):
# `git merge-tree` 는 두 갈래만 받으므로 octopus 는 실제 워크트리를 되살리고,
# octopus 는 한 파일에서 충돌하면 전체를 중단해 **어느 구성원 때문인지 안 알려준다**.
# 순차는 실패한 단계가 곧 그 구성원이라 `failed_at:` 에 귀속이 실린다.
#
# 순차의 대가는 `commit-tree` 중간 커밋이 unreachable 로 남는 것이다 — `intermediates:`
# 로 넘긴다. **이 출력의 소비자는 아직 없다.** GC 가 이것을 받는 것은 계획일 뿐이고
# (`qg-gc.py`/`gc_common.py` 는 git object 를 다루지 않는다 — TTL 로 세션 디렉토리만
# 지운다), 리포에 `git prune`/`fsck --unreachable`/`gc --prune` 호출도 0 개다.
#
# **인자는 공백-구분이다.** `resolve-topic.sh` 의 `tips:` 는 콤마-구분으로 낸다 — 호출부가
# 변환한다(`tr ',' ' '`).
#
# **사실만 낸다** — `not-certified` 같은 판정 어휘는 이 층에 없다.
#
# **알려진 한계** — 충돌 파일 경로에 탭이나 개행이 들어 있으면 스테이지 줄 파싱이
# 어긋난다. 공백은 안전하다(탭 구분이다). git 이 그런 경로를 따옴표로 감싸므로
# 소실이 아니라 표기 문제다.
#
# **종료 코드가 갈리는 뜻이 다르다** — `git merge-tree --write-tree` 의 rc 1 은 충돌
# (stdout 에 트리 OID·스테이지 줄) 이고, 그 밖의 비0(예: rc 128 = unrelated histories,
# stderr 에 `fatal: …`)은 충돌이 아니라 다른 실패다. 전자는 `status: merge-conflict` +
# `conflicts:` 에 충돌 파일 목록, 후자는 `status: merge-failed` + `conflicts:` 에 stderr
# 첫 줄을 싣는다 — 방향(fail-closed)은 같지만 진단을 버리지 않는다.
set -u

die() { echo "combine-tips: $*" >&2; exit 2; }

TREE="-"; STATUS="ok"; STEPS=0; INTERMEDIATES=""; CONFLICTS="-"; FAILED_AT="-"

emit() {
  echo "tree: $TREE"
  echo "status: $STATUS"
  echo "steps: $STEPS"
  echo "intermediates: ${INTERMEDIATES:--}"
  echo "conflicts: $CONFLICTS"
  echo "failed_at: $FAILED_AT"
  exit 0
}

[ $# -ge 1 ] || { STATUS="bad-input"; emit; }
for t in "$@"; do
  git rev-parse --verify --quiet "$t^{commit}" >/dev/null 2>&1 \
    || { STATUS="bad-input"; FAILED_AT="$t"; TREE="-"; emit; }
done

acc="$1"; shift
TREE=$(git rev-parse "$acc^{tree}" 2>/dev/null) || die "cannot read tree of $acc"

ERRFILE=$(mktemp 2>/dev/null) || die "mktemp failed"
trap 'rm -f "$ERRFILE"' EXIT

for tip in "$@"; do
  # 〔실측 6〕충돌 정보는 **stdout** 에 있고 stderr 는 0바이트다(rc 1). 1줄이 트리 OID,
  # 그다음이 `<mode> <oid> <stage>\t<path>` 스테이지 줄이다. 다른 실패(예: unrelated
  # histories 는 rc 128)는 stderr 에 `fatal: …` 을 낸다 — 버리지 않고 파일로 잡는다.
  out=$(git merge-tree --write-tree "$acc" "$tip" 2>"$ERRFILE"); rc=$?
  STEPS=$((STEPS+1))
  if [ "$rc" -ne 0 ]; then
    FAILED_AT="$tip"
    TREE="-"
    if [ "$rc" -eq 1 ]; then
      STATUS="merge-conflict"
      CONFLICTS=$(printf '%s\n' "$out" \
        | awk -F'\t' 'NF==2 && $1 ~ /^[0-7]{6} [0-9a-f]+ [123]$/ { print $2 }' \
        | sort -u | paste -sd, -)
      [ -n "$CONFLICTS" ] || CONFLICTS="-"
    else
      STATUS="merge-failed"
      CONFLICTS=$(head -1 "$ERRFILE" 2>/dev/null)
      [ -n "$CONFLICTS" ] || CONFLICTS="-"
    fi
    emit
  fi
  tree=$(printf '%s\n' "$out" | head -1)
  case "$tree" in
    [0-9a-f]*) ;;
    *) die "merge-tree gave no tree OID: $(printf '%s' "$out" | head -c 120)" ;;
  esac
  acc=$(git -c user.email=qg-seal@devbrew.local \
            -c user.name='qg seal' \
            -c commit.gpgsign=false \
            commit-tree "$tree" -p "$acc" -p "$tip" -m "qg: combine step $STEPS") \
    || die "commit-tree failed at step $STEPS"
  INTERMEDIATES="${INTERMEDIATES:+$INTERMEDIATES,}$acc"
  TREE="$tree"
done

emit
