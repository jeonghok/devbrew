#!/usr/bin/env bash
# topic-head.sh — 선언 → 봉인 → 경계 · 끝점 → 합친 HEAD 트리를 한 번에 풀어 튜플 하나를 낸다.
#   (설계 2026-09-21 §6.2.2–§6.2.6 · §6.4.1, AC3–AC7 · AC15 · AC16)
#
#   topic-head.sh <session-id> [--topic <topic-key>]   -> key: value 13줄 + commit: N줄
#
# `--topic` 이 없으면 `resolve-topic.sh detect` 가 현재 브랜치에서 토픽 키를 찾는다.
# `--topic` 은 `qg-worktree.sh create-head --topic` 이 HEAD 축을 다시 도출할 때 쓴다.
#
# **사실만 낸다.** `status:` 를 판정 사유로 옮기는 것은 `scope_tuple.py` 다.
#
#   ok                   합친 트리가 섰다 (tree · head_commit 채워짐)
#   no-declaration       현재 브랜치에 선언이 없다 — 기존 세 모드로
#   base-unresolved      base 를 못 풀어 선언 여부를 모른다
#   declaration-invalid  선언이 깨졌다 (경로 부재 · 한 브랜치에 여러 키 · 고아 · 키의 선언이 전부 base 에 있음(--topic))
#   unbounded            선언은 있는데 경계 · 끝점을 못 셌다
#   seal-failed          워킹트리 봉인 실패 — HEAD 축을 못 세운다
#   merge-conflict       끝점 합치기가 충돌 (conflicts: 에 파일)
#   merge-failed         끝점 합치기가 충돌 아닌 이유로 실패 (conflicts: 에 stderr 첫 줄)
#
# 봉인 · 합치기 커밋은 ref · reflog 를 얻지 않는다 — git 의 prune 이 회수한다
# (tests/test_qg_objects_unreachable.sh).
#
# bash 3.2 호환: 배열 대신 공백 · 콤마 구분 문자열을 쓴다.
set -u

die() { echo "topic-head: $*" >&2; exit 2; }
usage="usage: topic-head.sh <session-id> [--topic <topic-key>]"

SID="${1:-}"; [ -n "$SID" ] || die "$usage"
KEY=""
if [ $# -eq 3 ] && [ "$2" = "--topic" ]; then
  KEY="$3"; [ -n "$KEY" ] || die "$usage"
elif [ $# -ne 1 ]; then
  die "$usage"
fi
HERE="$(cd -- "$(dirname -- "$0")" && pwd)"

# 저장소 git 훅을 끈다 — 이 프로세스와 자식(봉인 · 해석 · 합치기)의 git 이 `core.hooksPath`
# 의 훅을 돌리지 않는다. 훅 디렉토리는 추적되는 저장소 코드일 수 있고, 선언 경로 봉인은
# kill switch 와 무관하게 돈다. 이미 `GIT_CONFIG_COUNT` 가 있으면 덮지 않고 한 칸 뒤에 덧붙인다.
n="${GIT_CONFIG_COUNT:-0}"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
export "GIT_CONFIG_KEY_$n=core.hooksPath" "GIT_CONFIG_VALUE_$n=/dev/null"
export GIT_CONFIG_COUNT=$((n + 1))

BRANCHES="-"; IN_BASE="-"; BOUNDARY="-"; TIPS="-"; SEAL="-"; SEAL_ON_TOPIC="-"
TREE="-"; HEAD_COMMIT="-"; CONFLICTS="-"; NCOMMITS="-"; COMMITS=""

emit() {   # <status> <reason>
  echo "topic_key: ${KEY:--}"
  echo "status: $1"
  echo "reason: ${2:--}"
  echo "branches: $BRANCHES"
  echo "in_base: $IN_BASE"
  echo "boundary: $BOUNDARY"
  echo "tips: $TIPS"
  echo "seal: $SEAL"
  echo "seal_on_topic: $SEAL_ON_TOPIC"
  echo "tree: $TREE"
  echo "head_commit: $HEAD_COMMIT"
  echo "conflicts: $CONFLICTS"
  echo "commits: $NCOMMITS"
  [ -n "$COMMITS" ] && printf '%s\n' "$COMMITS" | sed 's/^/commit: /'
  exit 0
}
val() { printf '%s\n' "$2" | sed -n "s/^$1: //p" | head -1; }

# exit 2 는 사용 오류뿐이다. 아래 단계의 실패(하위 스크립트 비0 · 기대 키 부재)는 status 로
# 낸다 — SKILL ① 이 비0 을 「멈춘다」로 읽으므로, 일시적 git 실패가 /qg 전체를 세우지 않고
# session 으로 내려가 그 사유가 공시되게 한다.

# 1. 토픽 키
if [ -z "$KEY" ]; then
  d=$(bash "$HERE/resolve-topic.sh" detect) || emit base-unresolved "resolve-topic.sh detect failed"
  st=$(val status "$d")
  case "$st" in
    ok) KEY=$(val topic_key "$d") ;;
    no-declaration|base-unresolved|declaration-invalid) emit "$st" "$(val reason "$d")" ;;
    *) emit base-unresolved "resolve-topic.sh detect gave no status" ;;
  esac
fi

# 2. 봉인 — 워킹트리(수정 · 삭제 · untracked)가 HEAD 축 후보에 «먼저» 들어간다(§6.2.4)
SEAL=$(bash "$HERE/seal-worktree.sh" seal "$SID") || SEAL=""
[ -n "$SEAL" ] || { SEAL="-"; emit seal-failed "seal-worktree.sh failed"; }

# 3. 경계 · 끝점
r=$(bash "$HERE/resolve-topic.sh" resolve "$KEY" --seal "$SEAL") || emit unbounded "resolve-topic.sh resolve failed"
BRANCHES=$(val branches "$r"); BOUNDARY=$(val boundary "$r"); TIPS=$(val tips "$r")
SEAL_ON_TOPIC=$(val seal_on_topic "$r")
IN_BASE=$(val in_base "$r"); [ -n "$IN_BASE" ] || IN_BASE="-"
case "$(val status "$r")" in
  ok) ;;
  declaration-invalid) emit declaration-invalid "$(val reason "$r")" ;;
  no-declaration) emit declaration-invalid "$(val reason "$r")" ;;
  base-unresolved) emit unbounded "$(val reason "$r")" ;;
  *) emit unbounded "resolve-topic.sh resolve gave no status" ;;
esac
[ -n "$TIPS" ] && [ "$TIPS" != "-" ] || emit unbounded "resolve-topic.sh gave no tips"

# 4. 본 커밋 T — 봉인은 끝점이지만 토픽 커밋이 아니다(§6.2.6)
COMMITS=$(bash "$HERE/resolve-topic.sh" commits "$KEY") || { COMMITS=""; emit unbounded "resolve-topic.sh commits failed"; }
NCOMMITS=$(printf '%s\n' "$COMMITS" | grep -c .)
[ "$NCOMMITS" -gt 0 ] || COMMITS=""

# 5. 합치기 — combine-tips 는 공백-구분 인자를 받는다
c=$(bash "$HERE/combine-tips.sh" $(printf '%s' "$TIPS" | tr ',' ' ')) || emit merge-failed "combine-tips.sh failed"
case "$(val status "$c")" in
  ok)
    TREE=$(val tree "$c")
    last=$(val intermediates "$c" | tr ',' '\n' | tail -1)
    if [ -z "$last" ] || [ "$last" = "-" ]; then
      # 끝점이 하나 — 그것은 봉인이다(봉인은 새 커밋이라 어느 끝점의 조상도 아니다)
      if [ "$TIPS" != "$SEAL" ]; then
        TREE="-"; emit merge-failed "single endpoint is not the seal: $TIPS"
      fi
      HEAD_COMMIT="$SEAL"
    else
      HEAD_COMMIT="$last"
    fi
    emit ok "-" ;;
  merge-conflict)
    CONFLICTS=$(val conflicts "$c")
    emit merge-conflict "merge-tree conflict at $(val failed_at "$c")" ;;
  *)
    CONFLICTS=$(val conflicts "$c")
    emit merge-failed "combine-tips status: $(val status "$c")" ;;
esac
