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
# 순차의 대가는 `commit-tree` 중간 커밋이 unreachable 로 남는 것이고, 그것은 기존
# `qg-gc.py` 경로가 받는다 — `intermediates:` 로 넘긴다.
#
# **사실만 낸다** — `not-certified` 같은 판정 어휘는 이 층에 없다.
#
# **알려진 한계** — 충돌 파일 경로에 탭이나 개행이 들어 있으면 스테이지 줄 파싱이
# 어긋난다. 공백은 안전하다(탭 구분이다). git 이 그런 경로를 따옴표로 감싸므로
# 소실이 아니라 표기 문제다.
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

for tip in "$@"; do
  # 〔실측 6〕충돌 정보는 **stdout** 에 있고 stderr 는 0바이트다. 1줄이 트리 OID,
  # 그다음이 `<mode> <oid> <stage>\t<path>` 스테이지 줄이다. 그래서 stdout 만 잡는다.
  out=$(git merge-tree --write-tree "$acc" "$tip" 2>/dev/null); rc=$?
  STEPS=$((STEPS+1))
  if [ "$rc" -ne 0 ]; then
    STATUS="merge-conflict"
    FAILED_AT="$tip"
    TREE="-"
    CONFLICTS=$(printf '%s\n' "$out" \
      | awk -F'\t' 'NF==2 && $1 ~ /^[0-7]{6} [0-9a-f]+ [123]$/ { print $2 }' \
      | sort -u | paste -sd, -)
    [ -n "$CONFLICTS" ] || CONFLICTS="-"
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
