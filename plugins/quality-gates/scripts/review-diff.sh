#!/usr/bin/env bash
# review-diff.sh — 모든 범위 모드의 리뷰 diff 를 한 자리에서 만든다(AC23).
#
# Usage: review-diff.sh --dir <dir> --iter <N> --mode session|branch|paths|topic|range
#                       [--globs <glob>...] [--scope-file <file>]
#
#   session  resolve-baseline.sh 의 merge_base 대비 작업 트리(추적 diff ∪ 무시되지 않는 untracked).
#            추적 안 되는 중첩 레포(ls-files 가 폴더 한 줄로 낸다)는 리뷰하지 않는다 — 그 안에서 git 을
#            돌리지도 파일을 읽지도 않고 폴더 줄만 names 에 남긴 채, 폴더마다 이스케이프한 이름으로 stderr 에
#            크게 알리고 degraded: yes 를 낸다(리뷰하지 못한 항목 — 인증을 막는다). 폴더를 가리키는 링크는 링크
#            자체로 diff 한다. session · paths 의
#            diff 는 --ignore-submodules=dirty 로 하위 모듈(gitlink) 폴더 안에서 git 을 돌리지 않는다.
#   branch   merge_base..HEAD
#   paths    session 집합 중 --globs(git pathspec)에 맞는 것
#   topic    --scope-file(topic-scope.txt)의 boundary..tree
#   range    --scope-file(range-scope.txt)의 start..end — 이 파일의 start · end 만 읽는다
#   모든 모드 기준(merge_base · boundary · start)의 .gitmodules 에 선언되지 않은 새 · 바뀐 gitlink(mode 160000)는
#            리뷰하지 않았다고 따로 알리고 degraded: yes 를 낸다(그 안의 글은 diff 에 없다)
#
# 쓰는 파일(<dir> 안 임시 폴더에 쓴 뒤 mv):
#   review-i<N>.names      거르기 전 경로 전부(한 줄에 하나)
#   review-i<N>.full.diff  거르기 전 diff
#   review-i<N>.diff       문서 경로를 뺀 diff — 리뷰어가 받는 것(남길 경로를 하나씩 적어 만든다)
#   review-i<N>.doc-paths  doc_paths.py select 출력(어느 경로를 왜 뺐고 남겼는지) — 폴더 이름이라 빼지 않은 경로는
#                          reviewed<TAB><경로> 줄, excluded: 는 뺀 뒤 수
#   review-i<N>.self-state 건너뛴 untracked qg 상태 경로(한 줄에 하나, 없으면 빈 파일)
#
# stdout 11줄: mode · base · head · degraded · degraded_reason · files · filtered_files · excluded ·
# kept_model · doc_paths_source · self_state. session · branch · paths 의 기준선이 degraded 면 다섯 파일을
# 비워 두고 degraded: yes · degraded_reason: <resolve-baseline.sh 의 사유> · files: - · self_state: - 로 rc 0
# (사유가 no-default-branch 면 stderr 에 고치는 법 한 줄). 그 밖에는 degraded_reason: - 다. 리뷰하지 못한 항목(중첩 레포 · 선언되지 않은
# gitlink · 이전 qg 실행이 남긴 worktree · 이름 대조에서 제외도 리뷰도 되지 않은 바뀐 경로 · git 이 바이너리로 보아
# 「Binary files … differ」 한 줄로만 diff 에 든 경로)이 있으면 다섯
# 파일은 그대로 쓰고 degraded: yes(files 등은 수 그대로)로 rc 0 — 기준선 degraded 와는
# files 가 수인지로 갈린다. git 실패 rc 4, 사용 오류 rc 2.
# 다른 바뀐 경로의 폴더 이름(x 와 x/…)인 문서 경로는 빼지 않고 리뷰한다(stderr 한 줄 · excluded 에 세지 않는다).
#
# qg 자기 산출물(이 실행의 --dir 바로 아래에서 아래 「qg 산출물 문법」 하나에 맞는 경로와 이 리포에
# 등록된 이 세션의 qg 일회용 worktree)은 session · paths 의 untracked 목록에서만 건너뛰고(앞 반복의 산출물이 다음
# 반복의 변경으로 세어지지 않게) 그 수와 경로를 공시한다. 다른 세션 폴더의 파일, 문법에 맞지 않는
# untracked 파일, 추적되는 변경, 커밋된 변경은 그 폴더 아래여도 리뷰한다 — 그 자리에 둔 코드가 리뷰를
# 피하지 못하게. --dir 가 리포 밖이면 아무것도 건너뛰지 않는다(self_state: 0 — stderr 에 그 이유).
# diff 는 사용자 git 설정(외부 diff · textconv · 접두 · rename · pathspec 환경 변수)에 기대지 않는다.
# 읽기 전용 git 만 쓴다.
set -u
# 이 값들은 pathspec 해석을 바꾼다 — GIT_LITERAL_PATHSPECS=1 이면 남길 경로의 :(literal) 이 글자 그대로 읽혀
# 걸러진 diff 가 조용히 빈다.
unset GIT_LITERAL_PATHSPECS GIT_GLOB_PATHSPECS GIT_NOGLOB_PATHSPECS GIT_ICASE_PATHSPECS

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TAB=$(printf '\t')
T=""

cleanup() { [ -n "$T" ] && rm -rf -- "$T"; }
trap cleanup EXIT

die() { echo "review-diff: $*" >&2; exit 2; }
gitfail() { echo "review-diff: $*" >&2; exit 4; }

usage="usage: review-diff.sh --dir <dir> --iter <N> --mode session|branch|paths|topic|range [--globs <glob>...] [--scope-file <file>]"

DIR="" ITER="" MODE="" SCOPE="" have_globs=0
GLOBS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir|--iter|--mode|--scope-file)
      [ $# -ge 2 ] && [ -n "$2" ] || die "$1 에 값이 없다 — $usage"
      case "$1" in
        --dir) DIR="$2" ;;
        --iter) ITER="$2" ;;
        --mode) MODE="$2" ;;
        --scope-file) SCOPE="$2" ;;
      esac
      shift 2 ;;
    --globs)
      have_globs=1; shift
      while [ $# -gt 0 ]; do
        case "$1" in --*) break ;; esac
        GLOBS+=("$1"); shift
      done ;;
    *) die "알 수 없는 인자: $1 — $usage" ;;
  esac
done

[ -n "$DIR" ] || die "--dir 가 없다 — $usage"
[ -d "$DIR" ] || die "출력 폴더가 없다: $DIR"
case "$ITER" in ''|0*|*[!0-9]*) die "--iter 는 1 이상의 정수다: ${ITER:-(없음)}" ;; esac
case "$MODE" in
  session|branch|paths|topic|range) ;;
  *) die "--mode 는 session|branch|paths|topic|range 중 하나다: ${MODE:-(없음)}" ;;
esac
if [ "$MODE" = paths ]; then
  [ "${#GLOBS[@]}" -gt 0 ] || die "paths 모드는 --globs 가 하나 이상 필요하다"
else
  [ "$have_globs" -eq 0 ] || die "--globs 는 paths 모드에서만 쓴다"
fi
case "$MODE" in
  topic|range)
    [ -n "$SCOPE" ] || die "$MODE 모드는 --scope-file 이 필요하다"
    [ -f "$SCOPE" ] && [ -r "$SCOPE" ] || die "범위 파일을 읽을 수 없다: $SCOPE" ;;
  *) [ -z "$SCOPE" ] || die "--scope-file 은 topic · range 모드에서만 쓴다" ;;
esac

# 상대 경로는 부른 자리 기준 — 리포 최상위로 옮기기 전에 절대 경로로 굳힌다.
DIR="$(cd "$DIR" && pwd -P)" || die "출력 폴더로 들어가지 못했다: $DIR"
if [ -n "$SCOPE" ]; then
  case "$SCOPE" in /*) ;; *) SCOPE="$PWD/$SCOPE" ;; esac
fi

top="$(git rev-parse --show-toplevel 2>/dev/null)" && [ -n "$top" ] || die "git 리포 안에서 돌려야 한다"
# DIR 과 같은 물리 경로로 굳힌다 — 한쪽만 링크를 풀면 리포 안 세션 폴더가 리포 밖으로 읽힌다.
top="$(cd "$top" && pwd -P)" && [ -n "$top" ] || gitfail "리포 최상위로 옮기지 못했다: $top"
cd "$top" || gitfail "리포 최상위로 옮기지 못했다: $top"

OUT_NAMES="$DIR/review-i$ITER.names"
OUT_FULL="$DIR/review-i$ITER.full.diff"
OUT_DIFF="$DIR/review-i$ITER.diff"
OUT_DOC="$DIR/review-i$ITER.doc-paths"
OUT_SELF="$DIR/review-i$ITER.self-state"
# 앞 실행의 결과가 이번 실패 뒤에 남아 읽히지 않게 먼저 지운다.
rm -f -- "$OUT_NAMES" "$OUT_FULL" "$OUT_DIFF" "$OUT_DOC" "$OUT_SELF" || die "앞 실행의 출력 파일을 지우지 못했다: $DIR"
T="$(mktemp -d "$DIR/.review-diff.XXXXXX")" || die "임시 폴더를 만들지 못했다: $DIR"

# --submodule=short — 사용자 설정 diff.submodule=diff · log 가 gitlink 폴더 안에서 자식 git 을 띄워 그 폴더의
# 설정(diff.external · textconv)을 돌리지 못하게 하위 모듈은 늘 「Subproject commit」 줄로만 낸다.
# --ignore-submodules=none — 작업 트리 .gitmodules 의 submodule.<이름>.ignore(리뷰하는 변경이 더할 수 있다)나
# 사용자 설정 diff.ignoreSubmodules 가 gitlink 를 diff 에서 숨기지 못하게 한다. session · paths 는 뒤에
# --ignore-submodules=dirty 를 덧붙인다(뒤 플래그가 이긴다).
# --text 를 붙이지 않는다 — 진짜 바이너리(이미지 · 폰트)의 원본 바이트가 리뷰어 입력에 들어가지 않게. 대신
# git 이 바이너리로 본 파일(.gitattributes 의 `-diff` · `binary`, 앞 8KB 의 NUL 바이트 — 「Binary files … differ」
# 한 줄로만 diff 에 든다)은 같은 플래그의 --numstat 으로 이름을 모아 리뷰하지 않았다고 알린다(say_binary).
# 걸러진 diff 의 git diff 한 번에 넘기는 남길 경로 수 · 글자 수 상한(인자 길이 상한 ARG_MAX 아래로).
KEEP_BATCH_N=500
KEEP_BATCH_CHARS=65536
GITD=(git -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv --no-renames --submodule=short
      --ignore-submodules=none --src-prefix=a/ --dst-prefix=b/)
GITD_NOINDEX=(git -c core.quotePath=false diff --no-index --no-color --no-ext-diff --no-textconv
              --src-prefix=a/ --dst-prefix=b/)

publish() {   # 임시 파일 다섯을 제자리로
  mv -f -- "$T/names" "$OUT_NAMES" \
    && mv -f -- "$T/full.diff" "$OUT_FULL" \
    && mv -f -- "$T/doc-paths" "$OUT_DOC" \
    && mv -f -- "$T/self-state" "$OUT_SELF" \
    && mv -f -- "$T/diff" "$OUT_DIFF" \
    || gitfail "결과 파일을 옮기지 못했다: $DIR"
}

emit() {   # <base> <head> <degraded> <degraded_reason> <files> <filtered> <excluded> <kept> <source> <self_state>
  printf 'mode: %s\nbase: %s\nhead: %s\ndegraded: %s\ndegraded_reason: %s\nfiles: %s\nfiltered_files: %s\nexcluded: %s\nkept_model: %s\ndoc_paths_source: %s\nself_state: %s\n' \
    "$MODE" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}"
}

scope_val() {   # <key> — 범위 파일에서 그 키의 첫 값
  sed -n "s/^$1: //p" "$SCOPE" | head -n 1
}

check_rev() {   # <key> <value> — 모양 검사 뒤 트리로 풀리는지
  case "$2" in
    ''|-|-*) die "범위 파일의 $1 값이 쓸 수 없다: ${2:-(없음)} ($SCOPE)" ;;
  esac
  git rev-parse --verify --quiet --end-of-options "$2^{tree}" >/dev/null 2>&1 \
    || gitfail "범위 파일의 $1 을 커밋 · 트리로 풀지 못했다: $2"
}

BASE="" HEAD_LABEL="" REV=() WORKTREE=0
case "$MODE" in
  session|branch|paths)
    rb="$(bash "$HERE/resolve-baseline.sh")" || gitfail "resolve-baseline.sh 가 실패했다"
    deg="$(printf '%s\n' "$rb" | sed -n 's/^degraded: //p')"
    mb="$(printf '%s\n' "$rb" | sed -n 's/^merge_base: //p')"
    if [ "$deg" != no ] || [ -z "$mb" ] || [ "$mb" = - ]; then
      why="$(printf '%s\n' "$rb" | sed -n 's/^degraded_reason: //p')"
      [ -n "$why" ] || why=-
      [ "$why" = no-default-branch ] \
        && echo "review-diff: 기본 브랜치를 찾지 못해 리뷰 범위를 정하지 못했다 — git remote set-head origin --auto 로 고친다" >&2
      : > "$T/names"; : > "$T/full.diff"; : > "$T/doc-paths"; : > "$T/self-state"; : > "$T/diff"
      publish
      if [ "$MODE" = branch ]; then
        h="$(git rev-parse --verify --quiet HEAD 2>/dev/null)" || h="-"
        [ -n "$h" ] || h="-"
      else
        h=worktree
      fi
      emit - "$h" yes "$why" - - - - - -
      exit 0
    fi
    BASE="$mb"
    if [ "$MODE" = branch ]; then
      HEAD_LABEL="$(git rev-parse --verify HEAD 2>/dev/null)" || gitfail "HEAD 를 풀지 못했다"
      REV=("$BASE" "$HEAD_LABEL")
    else
      HEAD_LABEL=worktree; WORKTREE=1
      # 작업 트리 쪽 diff 는 하위 모듈의 더러움을 재려고 그 폴더 안에서 git 을 띄운다 — 그 레포의 설정
      # (core.fsmonitor 등)이 명령을 돌린다. 더러움은 보지 않고 gitlink 커밋 변경만 본다.
      GITD+=(--ignore-submodules=dirty)
      REV=("$BASE")
    fi ;;
  topic)
    BASE="$(scope_val boundary)"; HEAD_LABEL="$(scope_val tree)"
    check_rev boundary "$BASE"; check_rev tree "$HEAD_LABEL"
    REV=("$BASE" "$HEAD_LABEL") ;;
  range)
    BASE="$(scope_val start)"; HEAD_LABEL="$(scope_val end)"
    check_rev start "$BASE"; check_rev end "$HEAD_LABEL"
    REV=("$BASE" "$HEAD_LABEL") ;;
esac

# 리뷰 경로 — paths 면 glob, 그 밖은 리포 전체. 추적 · 커밋된 변경은 어느 폴더든 리뷰한다.
if [ "${#GLOBS[@]}" -gt 0 ]; then PS=("${GLOBS[@]}"); else PS=(.); fi
# ── qg 산출물 문법 (허용 목록 하나 — 여기만 고친다) ──────────────────────────────
# untracked 경로가 이 실행의 세션 폴더(--dir, 리포 기준 상대 경로 DIR_REL) 바로 아래의 이 이름일 때만
# qg 자기 상태로 보고 건너뛴다(self_state 로 공시). 대상 리포가 `.claude/quality-gates` 를 무시하지
# 않아도 앞 반복의 산출물이 다음 반복의 변경으로 세어지지 않게. 다른 세션 폴더의 같은 이름, 폴더 바로
# 아래 파일, 세션 폴더의 모르는 이름, 코드 파일은 모두 리뷰한다 — qg 소비자는 이 실행의 --dir 만
# 읽으므로 다른 폴더에 둔 「산출물 이름」 파일은 상태가 아니라 리뷰를 피하려는 파일일 수 있다.
# --dir 가 리포 밖이면(DIR_REL 없음) 아무것도 건너뛰지 않는다 — self_state: 0, stderr 에 이유 한 줄.
# 출처:
#   이름      references/state-file-format.md 「같은 폴더의 다른 파일」 + result.md,
#             SKILL.md 의 $RD/ 쓰기(range-scope.txt · review-tree.txt · extra-iterations.md), 이 스크립트의 review-i<N>.*,
#             임시 이름(setup-qg.sh result.md.tmp.<pid> · e2e-state.sh <지문>.tmp · resolve-range.sh
#             .resolve-range.XXXXXX · 이 스크립트가 끊겨 남긴 .review-diff.XXXXXX/ 안의 임시 이름)
#   하위 폴더 qg-worktree.sh 의 <리포 최상위>/.claude/quality-gates/worktrees/(base|head)-<sid 앞 8자> —
#             git worktree 라 ls-files 가 폴더 한 줄(끝 /)로만 낸다. 8자가 이 실행의 세션 폴더(--dir)
#             이름의 앞 8자(SID8 — 영숫자 · _ · - 여덟 자가 아니면 건너뛰기 없음)와 같고 `git worktree list`
#             에 같은 물리 경로로 등록된 것만 건너뛴다. 다른 세션 접미의 등록된 트리는 리뷰하지 않고 이전 qg
#             실행이 남긴 트리로 알린다(say_stale_wt · degraded: yes). 등록되지 않은 같은 이름 폴더(안에 든
#             다른 레포)는 중첩 레포로 크게 알린다.
#   테스트    test_review_diff.sh 가 state-file-format.md 의 목록 전부를 이 문법이 받는지 잰다.
QG_NAMES='result\.md|intent\.md|excluded\.md|differential\.yaml|differential-not-counted\.md|verdict\.out'
QG_NAMES="$QG_NAMES"'|topic-scope\.txt|range-scope\.txt|review-tree\.txt|extra-iterations\.md'
QG_NAMES="$QG_NAMES"'|comment-head\.md|comment\.md|publish\.out|publish\.err'
QG_NAMES="$QG_NAMES"'|e2e-record\.md|e2e-flip\.md|e2e-evidence\.tsv|e2e-cmd\.txt|e2e-gate\.txt'
QG_NAMES="$QG_NAMES"'|e2e-before\.txt|e2e-after\.txt|e2e-app\.pgid|e2e-app\.log'
QG_NAMES="$QG_NAMES"'|review-i[1-9][0-9]*\.(names|full\.diff|diff|doc-paths|self-state)'
QG_NAMES="$QG_NAMES"'|result\.md\.tmp\.[0-9]+|e2e-(before|after)\.txt\.tmp|\.resolve-range\.[A-Za-z0-9]{6}'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/(tracked|untracked|filtered|raw|gitmodules|all|excl|excl2|prefix|keep|roots|seen|files|missing|untr|ukeep|numstat|bin|reviewed|mother|mbin)\.z'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/(names|full\.diff|diff|doc-paths|doc-paths\.new|self-state)'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/link\.(tmp|patch|out)'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/settings(-local)?-(base|head)'
QG_NAMES_RE="^($QG_NAMES)\$"
# qg 일회용 트리 이름 꼴 전부(qg-worktree.sh 는 sid 앞 1~8자를 쓴다)와 이 세션의 것.
QG_WT_ANY_RE='^\.claude/quality-gates/worktrees/(base|head)-[A-Za-z0-9_-]{1,8}/$'
QG_WT_RE=""
SID8="${DIR##*/}"; SID8="${SID8:0:8}"
case "$SID8" in
  ????????)
    case "$SID8" in
      *[!ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-]*) ;;
      *) QG_WT_RE='^\.claude/quality-gates/worktrees/(base|head)-'"$SID8"'/$' ;;
    esac ;;
esac
DIR_REL=""
case "$DIR" in "$top"/?*) DIR_REL="${DIR#"$top"/}" ;; esac
WT_REG=() wt_loaded=0
is_registered_wt() {   # <리포 기준 폴더 경로/> — 이 리포에 등록된 worktree 와 물리 경로가 같은가
  local want line p x
  want="$(cd "$top/${1%/}" 2>/dev/null && pwd -P)" || return 1
  if [ "$wt_loaded" -eq 0 ]; then
    wt_loaded=1
    while IFS= read -r line; do
      case "$line" in
        "worktree "*) p="$(cd "${line#worktree }" 2>/dev/null && pwd -P)" && WT_REG+=("$p") ;;
      esac
    done < <(git worktree list --porcelain 2>/dev/null)
  fi
  for x in ${WT_REG[@]+"${WT_REG[@]}"}; do [ "$x" = "$want" ] && return 0; done
  return 1
}
is_qg_state() {   # <path>
  [ -n "$DIR_REL" ] || return 1
  case "$1" in
    "$DIR_REL"/*) [[ "${1#"$DIR_REL"/}" =~ $QG_NAMES_RE ]] && return 0 ;;
  esac
  [ -n "$QG_WT_RE" ] && [[ "$1" =~ $QG_WT_RE ]] && is_registered_wt "$1" && return 0
  return 1
}
is_stale_wt() {   # <path> — 건너뛰지 않은(다른 세션 · --dir 가 리포 밖) 등록된 qg 일회용 트리인가
  [[ "$1" =~ $QG_WT_ANY_RE ]] && is_registered_wt "$1"
}
# 이 실행의 임시 폴더는 변경도 상태도 아니다 — 세지 않는다.
T_REL=""
case "$T" in "$top"/*) T_REL="${T#"$top"/}" ;; esac

# ── 거르기 전 경로 ──────────────────────────────────────────────────────────
"${GITD[@]}" --name-only -z "${REV[@]}" -- "${PS[@]}" > "$T/tracked.z" \
  || gitfail "git diff --name-only 가 실패했다: ${REV[*]}"
: > "$T/untracked.z"
if [ "$WORKTREE" -eq 1 ]; then
  git ls-files --others --exclude-standard -z -- "${PS[@]}" > "$T/untracked.z" \
    || gitfail "git ls-files --others 가 실패했다"
  [ -n "$DIR_REL" ] || echo "review-diff: 출력 폴더(--dir)가 리포 밖이라 qg 산출물을 건너뛰지 않는다 —" \
    "추적되지 않은 파일을 모두 리뷰한다(self_state 0): $DIR" >&2
fi

NAMES=(); UNTR=(); SELF=(); NESTED=(); STALE_WT=()
# 추적 안 되는 중첩 레포 — 바깥 ls-files 는 그 폴더를 한 줄(끝 /)로만 낸다. 그 안은 다른 레포가 정한 글이라
# 리뷰하지 않는다(그 안에서 git 을 돌리지도 파일을 읽지도 않는다). 폴더 줄을 names 에 남기고 폴더마다
# stderr 에 크게 알리고 degraded: yes 를 낸다(say_unreviewed). 끝 / 는 git 이 내는 표시라 파일 시스템을
# 따라가지 않고 가른다.
# 링크는 폴더를 가리켜도 끝 / 가 없다 — 링크 자체를 diff 한다(add_dir_link).
# 이 세션의 등록된 qg worktree 는 이 갈래 전에 is_qg_state 가 건너뛰고, 건너뛰지 않은 등록된 qg worktree 는
# 중첩 레포와 따로 STALE_WT 로 모아 리뷰하지 않고 알린다(say_stale_wt).
while IFS= read -r -d '' f; do NAMES+=("$f"); done < "$T/tracked.z"
while IFS= read -r -d '' f; do
  if [ -n "$T_REL" ]; then
    case "$f" in "$T_REL"/*) continue ;; esac
  fi
  if is_qg_state "$f"; then
    SELF+=("$f")
  elif is_stale_wt "$f"; then
    STALE_WT+=("$f")
  else
    case "$f" in */) NESTED+=("$f") ;; *) UNTR+=("$f") ;; esac
  fi
done < "$T/untracked.z"
{
  for f in ${NAMES[@]+"${NAMES[@]}"} ${UNTR[@]+"${UNTR[@]}"} ${NESTED[@]+"${NESTED[@]}"} \
           ${STALE_WT[@]+"${STALE_WT[@]}"}; do
    printf '%s\n' "$f"
  done
} > "$T/names" || gitfail "경로 목록을 쓰지 못했다"
{
  for f in ${SELF[@]+"${SELF[@]}"}; do printf '%s\n' "$f"; done
} > "$T/self-state" || gitfail "상태 경로 목록을 쓰지 못했다"
FILES=$(( ${#NAMES[@]} + ${#UNTR[@]} + ${#NESTED[@]} + ${#STALE_WT[@]} ))

# 레포가 정한 이름을 한 줄로 찍는다 — printf %q 로 이스케이프하고 백틱은 하나도 남기지 않는다(SKILL 이 이름을
# 코드 스팬에 싣는데 백틱이 그 스팬을 닫지 못하게). %q 가 제어 문자 때문에 $'...' 꼴을 내면 그 안의 백틱을
# \x60 으로, 보통 꼴인데 백틱이 있으면 $'...' 꼴로 다시 쓴다(\ → \\ · ' → \' · ` → \x60).
esc_name() {   # <이름>
  local q
  q="$(printf '%q' "$1")"
  case "$q" in *'`'*) ;; *) printf '%s' "$q"; return 0 ;; esac
  case "$q" in
    "\$'"*) q="$(printf '%s' "$q" | LC_ALL=C sed 's/`/\\x60/g')" ;;
    *) q="\$'$(printf '%s' "$1" | LC_ALL=C sed -e 's/\\/\\\\/g' -e "s/'/\\\\'/g" -e 's/`/\\x60/g')'" ;;
  esac
  printf '%s' "$q"
}

add_untracked() {   # <out> <path> — untracked 파일 하나를 /dev/null 대비 diff 로 덧붙인다
  local rc
  if [ -L "$2" ] && [ -d "$2" ]; then add_dir_link "$1" "$2"; return; fi
  "${GITD_NOINDEX[@]}" -- /dev/null "$2" >> "$1"
  rc=$?
  [ "$rc" -le 1 ] || gitfail "untracked 파일의 diff 가 실패했다(rc $rc): $(esc_name "$2")"
}

# 폴더를 가리키는 링크 — git diff --no-index 는 그 인자를 폴더로 읽는다(그리고 rc 1 로 조용히 끝난다).
# 링크 대상 글자만 고정 이름 link.tmp 에 쓰고 리포를 찾지 않는 cwd($T — GIT_CEILING_DIRECTORIES)에서 diff 한
# 뒤, 머리의 고정 이름을 바깥 ls-files 가 내는 실제 이름(따옴표 규칙 그대로)으로, mode 를 120000 으로 바꾼다.
# 리포가 정한 이름으로 폴더 · 파일을 만들지 않는다.
add_dir_link() {   # <out> <path>
  local q qa qb tab="" rc nl
  nl=$'\n'
  case "/$2/" in */../*|*/./*|//*) gitfail "링크 이름이 리포 안 상대 경로가 아니다: $(esc_name "$2")" ;; esac
  q="$(git -c core.quotePath=false ls-files --others --exclude-standard -- ":(literal)$2")" \
    || gitfail "링크 이름을 읽지 못했다: $(esc_name "$2")"
  case "$q" in ''|*"$nl"*) gitfail "링크 이름을 하나로 풀지 못했다: $(esc_name "$2")" ;; esac
  readlink -n -- "$2" > "$T/link.tmp" || gitfail "링크를 읽지 못했다: $(esc_name "$2")"
  ( cd "$T" && GIT_CEILING_DIRECTORIES="$DIR" "${GITD_NOINDEX[@]}" -- /dev/null link.tmp ) > "$T/link.patch"
  rc=$?
  [ "$rc" -eq 1 ] || gitfail "링크의 diff 가 실패했다(rc $rc): $(esc_name "$2")"
  case "$2" in *' '*) tab="$TAB" ;; esac   # git 은 공백 든 이름의 +++ 줄 끝에 TAB 을 붙인다
  case "$q" in '"'*) qa="\"a/${q#\"}"; qb="\"b/${q#\"}" ;; *) qa="a/$q"; qb="b/$q" ;; esac
  link_patch "$qa" "$qb" "$tab" < "$T/link.patch" > "$T/link.out" \
    || gitfail "링크의 diff 모양이 예상과 다르다: $(esc_name "$2")"
  cat -- "$T/link.out" >> "$1" || gitfail "링크의 diff 를 쓰지 못했다: $(esc_name "$2")"
}

link_patch() {   # <a 이름> <b 이름> <+++ 줄 끝> — stdin 의 link.tmp diff 머리를 실제 이름으로 바꾼다
  local n=0 line
  while IFS= read -r line || [ -n "$line" ]; do
    n=$((n + 1))
    case "$n" in
      1) [ "$line" = "diff --git a/link.tmp b/link.tmp" ] || return 1; line="diff --git $1 $2" ;;
      2) [ "$line" = "new file mode 100644" ] || return 1; line="new file mode 120000" ;;
      3) case "$line" in "index 0000000.."*) ;; *) return 1 ;; esac ;;
      4) [ "$line" = "--- /dev/null" ] || return 1 ;;
      5) [ "$line" = "+++ b/link.tmp" ] || return 1; line="+++ $2$3" ;;
    esac
    printf '%s\n' "$line"
  done
  [ "$n" -ge 6 ]
}

# ── 거르기 전 diff ─────────────────────────────────────────────────────────
"${GITD[@]}" "${REV[@]}" -- "${PS[@]}" > "$T/full.diff" \
  || gitfail "git diff 가 실패했다: ${REV[*]}"
for f in ${UNTR[@]+"${UNTR[@]}"}; do add_untracked "$T/full.diff" "$f"; done

# ── 설정 비교 두 쪽 ────────────────────────────────────────────────────────
# settings.json 과 settings.local.json 둘 다. 작업 트리 쪽 파일을 git 이 무시하면(추적 안 됨) 그 파일은
# 이 변경의 일부가 아니다 — 기준 쪽과 같은 글로 본다(개인 설정이 늘 「바뀜」으로 읽혀 기본 목록으로
# 돌아가지 않게).
show_settings() {   # <rev> <path> <out> — 그 트리에 파일이 없으면 out 을 만들지 않는다
  if git cat-file -e "$1:$2" 2>/dev/null; then
    git show "$1:$2" > "$3" || gitfail "git show 가 실패했다: $1:$2"
  fi
}
SARGS=()
for pair in "settings:.claude/settings.json" "settings-local:.claude/settings.local.json"; do
  tag="${pair%%:*}"; sp="${pair#*:}"
  show_settings "$BASE" "$sp" "$T/$tag-base"
  if [ "$WORKTREE" -eq 1 ]; then
    if git check-ignore -q -- "$sp" 2>/dev/null; then
      sh_path="$T/$tag-base"
    else
      sh_path="$top/$sp"
    fi
  else
    show_settings "$HEAD_LABEL" "$sp" "$T/$tag-head"
    sh_path="$T/$tag-head"
  fi
  SARGS+=("--$tag-base" "$T/$tag-base" "--$tag-head" "$sh_path")
done

python3 -X utf8 "$HERE/doc_paths.py" select --names "$T/names" "${SARGS[@]}" > "$T/doc-paths"
dp_rc=$?
[ "$dp_rc" -eq 0 ] || gitfail "doc_paths.py 가 실패했다(rc $dp_rc)"

EXCL=()
while IFS= read -r line; do
  case "$line" in "exclude$TAB"*) EXCL+=("${line:8}") ;; esac
done < "$T/doc-paths"
excluded="$(sed -n 's/^excluded: //p' "$T/doc-paths")"
kept="$(sed -n 's/^kept_model: //p' "$T/doc-paths")"
dp_source="$(sed -n 's/^doc_paths_source: //p' "$T/doc-paths")"

# 리뷰하지 않은 항목을 크게 알린다 — 이름은 레포가 정한 글이라 %q 로 이스케이프한다(줄바꿈 · 제어 문자가
# 줄을 위조하지 못하게). 하나라도 있으면 degraded: yes — 이 값은 Step 1c 의 stdout 으로 같은 턴의
# 오케스트레이터에 가고(레포 안 표지를 나중에 다시 읽지 않는다), Step 1c 가 판정 입력 error-axis 로 싣는다.
UNREVIEWED=0
say_unreviewed() {   # <경로> — 추적 안 되는 중첩 레포
  UNREVIEWED=$((UNREVIEWED + 1))
  printf 'review-diff: 추적 안 되는 중첩 레포 %s 는 리뷰하지 않았다 — 그 레포 설정을 믿지 않고는 안을 안전하게 읽을 수 없다. .gitignore 에 넣거나 레포 밖으로 옮긴 뒤 다시 돌려라\n' \
    "$(esc_name "$1")" >&2
}
say_unreviewed_gitlink() {   # <경로> — 기준의 .gitmodules 에 선언되지 않은 새 · 바뀐 gitlink
  UNREVIEWED=$((UNREVIEWED + 1))
  printf 'review-diff: 기준의 .gitmodules 에 선언되지 않은 gitlink %s 는 리뷰하지 않았다 — diff 에는 커밋 줄만 있다. 그 안의 변경은 따로 리뷰하고, 하위 모듈로 들일 것이 아니면 git rm --cached 로 빼라\n' \
    "$(esc_name "$1")" >&2
}
say_stale_wt() {   # <경로> — 건너뛰지 않은 등록된 qg 일회용 트리. 지우는 명령에 그대로 쓰게 절대 경로로 낸다.
  local q
  UNREVIEWED=$((UNREVIEWED + 1))
  q="$(esc_name "$top/${1%/}")"
  printf 'review-diff: 이전 qg 실행이 남긴 worktree %s 는 리뷰하지 않았다 — 다른 qg 실행이 쓰고 있지 않으면 git worktree remove --force %s 로 지운 뒤 다시 돌려라\n' \
    "$q" "$q" >&2
}
say_missing() {   # <경로> — 이름 대조에서 제외도 리뷰도 되지 않은 바뀐 경로
  UNREVIEWED=$((UNREVIEWED + 1))
  printf 'review-diff: 바뀐 경로 %s 가 리뷰 diff 에 들지 못해 리뷰하지 않았다\n' "$(esc_name "$1")" >&2
}
say_binary() {   # <경로> — git 이 바이너리로 보아 「Binary files … differ」 한 줄로만 리뷰 diff 에 든 경로
  UNREVIEWED=$((UNREVIEWED + 1))
  printf 'review-diff: 바뀐 경로 %s 는 바이너리로 보여(.gitattributes 의 -diff · binary 이거나 NUL 바이트) 리뷰 diff 에 내용이 없어 리뷰하지 않았다\n' \
    "$(esc_name "$1")" >&2
}

# NUL 목록 다루기(경로는 바이트 그대로 비교한다).
#   dirs <all.z> <excl.z>   excl 가운데 all 의 다른 경로의 폴더 이름(x 와 x/…)인 것
#   minus <a.z> <b.z>…      a 의 순서대로 b 들 어느 것에도 없는 것
#   roots <keep.z> <all.z>  keep 가운데 keep 안의 다른 경로가 all 의 폴더 이름으로 덮지 않는 것 — :(literal) x 는
#                           x/… 도 잡으므로 x 아래 경로를 따로 넘기면 다른 묶음에서 두 번 나온다
#   docpaths <doc-paths> <drop.z> <수>  doc-paths 를 줄 단위로 옮겨 쓰며 drop 의 exclude<TAB> 줄을 reviewed<TAB> 로,
#                           <수> 가 숫자면 excluded: 줄을 그 수로 바꾼다
#   binary <numstat.z>      --numstat -z --no-renames 기록 가운데 「-<TAB>-」(git 이 바이너리로 본 파일)의 경로.
#                           모양이 다른 기록이 있으면 rc 3
NUL_PY='import sys
def rd(p):
    with open(p, "rb") as f:
        return [x for x in f.read().split(b"\0") if x]
out = sys.stdout.buffer
op = sys.argv[1]
if op == "dirs":
    dirs = set()
    for p in rd(sys.argv[2]):
        i = p.find(b"/")
        while i > 0:
            dirs.add(p[:i])
            i = p.find(b"/", i + 1)
    for x in rd(sys.argv[3]):
        if x in dirs:
            out.write(x + b"\0")
elif op == "roots":
    dirs = set()
    for p in rd(sys.argv[3]):
        i = p.find(b"/")
        while i > 0:
            dirs.add(p[:i])
            i = p.find(b"/", i + 1)
    keep = rd(sys.argv[2])
    cover = set(k for k in keep if k in dirs)
    for k in keep:
        i = k.find(b"/")
        hit = False
        while i > 0 and not hit:
            hit = k[:i] in cover
            i = k.find(b"/", i + 1)
        if not hit:
            out.write(k + b"\0")
elif op == "docpaths":
    drop = set(rd(sys.argv[3]))
    n = sys.argv[4]
    with open(sys.argv[2], "rb") as f:
        lines = f.read().split(b"\n")
    for i, ln in enumerate(lines):
        if ln.startswith(b"excluded: ") and n.isdigit():
            lines[i] = b"excluded: " + n.encode("ascii")
        elif ln.startswith(b"exclude\t") and ln[8:] in drop:
            lines[i] = b"reviewed\t" + ln[8:]
    out.write(b"\n".join(lines))
elif op == "binary":
    for r in rd(sys.argv[2]):
        parts = r.split(b"\t", 2)
        if len(parts) != 3 or not parts[2]:
            sys.exit(3)
        if parts[0] == b"-" and parts[1] == b"-":
            out.write(parts[2] + b"\0")
elif op == "minus":
    skip = set()
    for p in sys.argv[3:]:
        skip.update(rd(p))
    for x in rd(sys.argv[2]):
        if x not in skip:
            out.write(x + b"\0")
else:
    sys.exit(2)
'
nul_list() {   # <op> <파일>…
  python3 -I -c "$NUL_PY" "$@"
}
put_z() {   # <out> <경로>… — NUL 목록으로 쓴다
  local out="$1"; shift
  if [ "$#" -eq 0 ]; then : > "$out"; else printf '%s\0' "$@" > "$out"; fi
}

# ── 걸러진 diff ────────────────────────────────────────────────────────────
# 제외를 pathspec 으로 빼지 않는다 — 제외 pathspec 은 그 이름 아래 경로까지 뺀다(파일 x 를 지우고 x/a.py 를
# 더하면 x/a.py 가 조용히 빠진다). 남길 tracked 경로 KEEP 을 :(literal) 로 하나씩 적어 git diff 에 넘긴다 —
# 인자 길이 상한을 넘지 않게 KEEP_BATCH_N 개 · KEEP_BATCH_CHARS 글자씩 나눠 부르고 순서대로 잇는다(파일마다
# diff 머리가 따로라 이어도 같은 diff 다). KEEP 이 비면 git diff 를 부르지 않는다(경로 없는 git diff 는 전체 diff 다).
# 다른 바뀐 경로의 폴더 이름(x 와 x/…)인 제외 경로는 제외 목록에서 빼고(리뷰한다) stderr 에 한 줄로 알리고,
# review-i<N>.doc-paths 의 그 줄을 reviewed<TAB><경로> 로, excluded: 를 뺀 뒤 수로 고쳐 쓴다.
put_z "$T/all.z" ${NAMES[@]+"${NAMES[@]}"} ${UNTR[@]+"${UNTR[@]}"} ${NESTED[@]+"${NESTED[@]}"} \
  ${STALE_WT[@]+"${STALE_WT[@]}"} || gitfail "경로 목록을 쓰지 못했다"
put_z "$T/excl.z" ${EXCL[@]+"${EXCL[@]}"} || gitfail "제외 목록을 쓰지 못했다"
nul_list dirs "$T/all.z" "$T/excl.z" > "$T/prefix.z" || gitfail "제외 경로의 폴더 이름 대조가 실패했다"
DROP=()
while IFS= read -r -d '' x; do DROP+=("$x"); done < "$T/prefix.z"
if [ "${#DROP[@]}" -gt 0 ]; then
  nul_list minus "$T/excl.z" "$T/prefix.z" > "$T/excl2.z" && mv -f -- "$T/excl2.z" "$T/excl.z" \
    || gitfail "제외 목록을 고쳐 쓰지 못했다"
  EXCL=()
  while IFS= read -r -d '' x; do EXCL+=("$x"); done < "$T/excl.z"
  for x in "${DROP[@]}"; do
    printf 'review-diff: %s 는 다른 바뀐 경로의 폴더 이름이기도 해서 문서 경로로 빼지 않고 리뷰한다\n' \
      "$(esc_name "$x")" >&2
  done
  case "$excluded" in ''|*[!0-9]*) ;; *) excluded=${#EXCL[@]} ;; esac
  nul_list docpaths "$T/doc-paths" "$T/prefix.z" "$excluded" > "$T/doc-paths.new" \
    && mv -f -- "$T/doc-paths.new" "$T/doc-paths" || gitfail "문서 경로 결정을 고쳐 쓰지 못했다"
fi
nul_list minus "$T/tracked.z" "$T/excl.z" > "$T/keep.z" || gitfail "남길 경로를 가리지 못했다"
nul_list roots "$T/keep.z" "$T/all.z" > "$T/roots.z" || gitfail "남길 경로의 폴더 이름 대조가 실패했다"
: > "$T/diff"; : > "$T/filtered.z"; : > "$T/numstat.z"; : > "$T/bin.z"
diff_batch() {   # KB 묶음 하나를 걸러진 diff 와 이름 목록 · numstat 에 덧붙인다
  "${GITD[@]}" "${REV[@]}" -- "${KB[@]}" >> "$T/diff" \
    || gitfail "걸러진 git diff 가 실패했다: ${REV[*]}"
  "${GITD[@]}" --name-only -z "${REV[@]}" -- "${KB[@]}" >> "$T/filtered.z" \
    || gitfail "걸러진 git diff --name-only 가 실패했다: ${REV[*]}"
  # --diff-filter=d — 지운 파일은 숨길 새 내용이 없다(diff 에 deleted file 로 보인다).
  "${GITD[@]}" --numstat -z --diff-filter=d "${REV[@]}" -- "${KB[@]}" >> "$T/numstat.z" \
    || gitfail "걸러진 git diff --numstat 이 실패했다: ${REV[*]}"
}
is_binary_untracked() {   # <path> — git 이 이 untracked 파일을 바이너리로 보는가(add_untracked 와 같은 플래그)
  local ns rc
  [ -L "$1" ] && [ -d "$1" ] && return 1   # 폴더 링크는 링크 대상 글자를 diff 한다(add_dir_link)
  ns="$("${GITD_NOINDEX[@]}" --numstat -- /dev/null "$1")"
  rc=$?
  [ "$rc" -le 1 ] || gitfail "untracked 파일의 numstat 이 실패했다(rc $rc): $(esc_name "$1")"
  case "$ns" in "-$TAB-$TAB"*) return 0 ;; esac
  return 1
}
KB=(); kb_chars=0
while IFS= read -r -d '' x; do
  x=":(literal)$x"
  if [ "${#KB[@]}" -gt 0 ] \
     && { [ "${#KB[@]}" -ge "$KEEP_BATCH_N" ] || [ $((kb_chars + ${#x} + 1)) -gt "$KEEP_BATCH_CHARS" ]; }; then
    diff_batch; KB=(); kb_chars=0
  fi
  KB+=("$x"); kb_chars=$((kb_chars + ${#x} + 1))
done < "$T/roots.z"
[ "${#KB[@]}" -gt 0 ] && diff_batch
FILTERED=$(tr -cd '\000' < "$T/filtered.z" | wc -c | tr -d ' ')
cp -- "$T/filtered.z" "$T/seen.z" || gitfail "리뷰한 경로 목록을 쓰지 못했다"
put_z "$T/untr.z" ${UNTR[@]+"${UNTR[@]}"} || gitfail "경로 목록을 쓰지 못했다"
nul_list minus "$T/untr.z" "$T/excl.z" > "$T/ukeep.z" || gitfail "남길 untracked 경로를 가리지 못했다"
while IFS= read -r -d '' f; do
  FILTERED=$((FILTERED + 1))
  add_untracked "$T/diff" "$f"
  printf '%s\0' "$f" >> "$T/seen.z" || gitfail "리뷰한 경로 목록을 쓰지 못했다"
  if is_binary_untracked "$f"; then
    printf '%s\0' "$f" >> "$T/bin.z" || gitfail "바이너리 경로 목록을 쓰지 못했다"
  fi
done < "$T/ukeep.z"
nul_list binary "$T/numstat.z" >> "$T/bin.z" || gitfail "numstat 에서 바이너리 경로를 가리지 못했다"

# 이름 대조 — (tracked + untracked 파일) − 제외 − 리뷰한 경로(걸러진 이름 + 리뷰한 untracked − 바이너리로 본
# 경로) 가 비어야 한다. 남는 경로마다 크게 알리고 degraded: yes — 바이너리로 본 경로는 say_binary, 그 밖은
# say_missing. 중첩 레포 · 등록된 qg 트리는 아래에서 따로 알린다.
put_z "$T/files.z" ${NAMES[@]+"${NAMES[@]}"} ${UNTR[@]+"${UNTR[@]}"} || gitfail "경로 목록을 쓰지 못했다"
nul_list minus "$T/seen.z" "$T/bin.z" > "$T/reviewed.z" || gitfail "리뷰한 경로를 가리지 못했다"
nul_list minus "$T/files.z" "$T/excl.z" "$T/reviewed.z" > "$T/missing.z" || gitfail "이름 대조가 실패했다"
nul_list minus "$T/missing.z" "$T/bin.z" > "$T/mother.z" || gitfail "이름 대조가 실패했다"
nul_list minus "$T/missing.z" "$T/mother.z" > "$T/mbin.z" || gitfail "이름 대조가 실패했다"
while IFS= read -r -d '' x; do say_missing "$x"; done < "$T/mother.z"
while IFS= read -r -d '' x; do say_binary "$x"; done < "$T/mbin.z"

for x in ${NESTED[@]+"${NESTED[@]}"}; do say_unreviewed "$x"; done
for x in ${STALE_WT[@]+"${STALE_WT[@]}"}; do say_stale_wt "$x"; done

# gitlink — 그 안은 diff 에 없다(커밋 줄 하나뿐). 스테이지 · 커밋한 중첩 레포, 토픽 봉인(git add -A)이 만든
# gitlink 가 그렇다. 모든 모드에서 기준(merge_base · boundary · start)의 .gitmodules 에 선언되지 않았고 이
# 범위에서 새로 생기거나 바뀐 gitlink 를 따로 알린다(say_unreviewed_gitlink · degraded: yes). 선언된 하위 모듈의 커밋 변경은
# 알리지 않는다. 같은 REV · 경로로 세는 --raw 라 session · paths 는 작업 트리 쪽을 본다.
"${GITD[@]}" --raw -z "${REV[@]}" -- "${PS[@]}" > "$T/raw.z" \
  || gitfail "git diff --raw 가 실패했다: ${REV[*]}"
: > "$T/gitmodules.z"
if git cat-file -e "$BASE:.gitmodules" 2>/dev/null; then
  # 못 읽으면(모양이 깨진 .gitmodules 등) 선언 없음으로 본다 — 더 많이 알리는 쪽이다.
  git config -z --blob "$BASE:.gitmodules" --get-regexp '^submodule\..*\.path$' > "$T/gitmodules.z" 2>/dev/null \
    || : > "$T/gitmodules.z"
fi
DECL=()
while IFS= read -r -d '' rec; do DECL+=("${rec#*$'\n'}"); done < "$T/gitmodules.z"
while IFS= read -r -d '' meta && IFS= read -r -d '' gp; do
  read -r _ nm _ <<< "$meta"
  [ "$nm" = 160000 ] || continue
  declared=0
  for x in ${DECL[@]+"${DECL[@]}"}; do [ "$x" = "$gp" ] && declared=1; done
  [ "$declared" -eq 1 ] || say_unreviewed_gitlink "$gp"
done < "$T/raw.z"

publish
deg_out=no; [ "$UNREVIEWED" -gt 0 ] && deg_out=yes
emit "$BASE" "$HEAD_LABEL" "$deg_out" - "$FILES" "$FILTERED" "${excluded:--}" "${kept:--}" "${dp_source:--}" "${#SELF[@]}"
exit 0
