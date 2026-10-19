#!/usr/bin/env bash
# review-diff.sh — 모든 범위 모드의 리뷰 diff 를 한 자리에서 만든다(AC23).
#
# Usage: review-diff.sh --dir <dir> --iter <N> --mode session|branch|paths|topic|range
#                       [--globs <glob>...] [--scope-file <file>]
#
#   session  resolve-baseline.sh 의 merge_base 대비 작업 트리(추적 diff ∪ 무시되지 않는 untracked)
#   branch   merge_base..HEAD
#   paths    session 집합 중 --globs(git pathspec)에 맞는 것
#   topic    --scope-file(topic-scope.txt)의 boundary..tree
#   range    --scope-file(range-scope.txt)의 start..end — 이 파일의 start · end 만 읽는다
#
# 쓰는 파일(<dir> 안 임시 폴더에 쓴 뒤 mv):
#   review-i<N>.names      거르기 전 경로 전부(한 줄에 하나)
#   review-i<N>.full.diff  거르기 전 diff
#   review-i<N>.diff       문서 경로를 뺀 diff — 리뷰어가 받는 것
#   review-i<N>.doc-paths  doc_paths.py select 출력(어느 경로를 왜 뺐고 남겼는지)
#   review-i<N>.self-state 건너뛴 untracked qg 상태 경로(한 줄에 하나, 없으면 빈 파일)
#
# stdout 10줄: mode · base · head · degraded · files · filtered_files · excluded · kept_model ·
# doc_paths_source · self_state. session · branch · paths 의 기준선이 degraded 면 다섯 파일을
# 비워 두고 degraded: yes · files: - · self_state: - 로 rc 0. git 실패 rc 4, 사용 오류 rc 2.
#
# qg 자기 산출물(아래 「qg 산출물 문법」 하나에 맞는 `.claude/quality-gates/…` 경로)은 session ·
# paths 의 untracked 목록에서만 건너뛰고(앞 반복의 산출물이 다음 반복의 변경으로 세어지지 않게) 그 수와
# 경로를 공시한다. 문법에 맞지 않는 untracked 파일, 추적되는 변경, 커밋된 변경은 그 폴더 아래여도
# 리뷰한다 — 그 자리에 둔 코드가 리뷰를 피하지 못하게.
# diff 는 사용자 git 설정(외부 diff · textconv · 접두 · rename · pathspec 환경 변수)에 기대지 않는다.
# 읽기 전용 git 만 쓴다.
set -u
# 이 값들은 pathspec 해석을 바꾼다 — GIT_LITERAL_PATHSPECS=1 이면 제외 pathspec 이 글자 그대로 읽혀
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
cd "$top" || gitfail "리포 최상위로 옮기지 못했다: $top"

OUT_NAMES="$DIR/review-i$ITER.names"
OUT_FULL="$DIR/review-i$ITER.full.diff"
OUT_DIFF="$DIR/review-i$ITER.diff"
OUT_DOC="$DIR/review-i$ITER.doc-paths"
OUT_SELF="$DIR/review-i$ITER.self-state"
# 앞 실행의 결과가 이번 실패 뒤에 남아 읽히지 않게 먼저 지운다.
rm -f -- "$OUT_NAMES" "$OUT_FULL" "$OUT_DIFF" "$OUT_DOC" "$OUT_SELF" || die "앞 실행의 출력 파일을 지우지 못했다: $DIR"
T="$(mktemp -d "$DIR/.review-diff.XXXXXX")" || die "임시 폴더를 만들지 못했다: $DIR"

GITD=(git -c core.quotePath=false diff --no-color --no-ext-diff --no-textconv --no-renames
      --src-prefix=a/ --dst-prefix=b/)
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

emit() {   # <base> <head> <degraded> <files> <filtered> <excluded> <kept> <source> <self_state>
  printf 'mode: %s\nbase: %s\nhead: %s\ndegraded: %s\nfiles: %s\nfiltered_files: %s\nexcluded: %s\nkept_model: %s\ndoc_paths_source: %s\nself_state: %s\n' \
    "$MODE" "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9"
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
      : > "$T/names"; : > "$T/full.diff"; : > "$T/doc-paths"; : > "$T/self-state"; : > "$T/diff"
      publish
      if [ "$MODE" = branch ]; then
        h="$(git rev-parse --verify --quiet HEAD 2>/dev/null)" || h="-"
        [ -n "$h" ] || h="-"
      else
        h=worktree
      fi
      emit - "$h" yes - - - - - -
      exit 0
    fi
    BASE="$mb"
    if [ "$MODE" = branch ]; then
      HEAD_LABEL="$(git rev-parse --verify HEAD 2>/dev/null)" || gitfail "HEAD 를 풀지 못했다"
      REV=("$BASE" "$HEAD_LABEL")
    else
      HEAD_LABEL=worktree; WORKTREE=1
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
# untracked 경로가 이 문법에 맞을 때만 qg 자기 상태로 보고 건너뛴다(self_state 로 공시). 대상 리포가
# `.claude/quality-gates` 를 무시하지 않아도 앞 반복의 산출물이 다음 반복의 변경으로 세어지지 않게.
# 맞지 않는 것 — 폴더 바로 아래 파일, 세션 폴더의 모르는 이름, 코드 파일 — 은 모두 리뷰한다.
# 출처:
#   세션 id   setup-qg.sh 의 SID 가드 ^[A-Za-z0-9_-]{8,}$, 예약 이름 worktrees · baseline-cache 는 세션 아님
#   이름      references/state-file-format.md 「같은 폴더의 다른 파일」 + result.md,
#             SKILL.md 의 $RD/ 쓰기(range-scope.txt · extra-iterations.md), 이 스크립트의 review-i<N>.*,
#             임시 이름(setup-qg.sh result.md.tmp.<pid> · e2e-state.sh <지문>.tmp · resolve-range.sh
#             .resolve-range.XXXXXX · 이 스크립트가 끊겨 남긴 .review-diff.XXXXXX/ 안의 임시 이름)
#   하위 폴더 qg-worktree.sh 의 worktrees/(base|head)-<sid 앞 8자> — git worktree 라 ls-files 가 폴더
#             한 줄(끝 /)로만 내고 안을 열지 않는다. 그 안이 낱 파일로 보이면(worktree 가 아니면) 리뷰한다.
#   테스트    test_review_diff.sh 가 state-file-format.md 의 목록 전부를 이 문법이 받는지 잰다.
QG_SID='[A-Za-z0-9_-]{8,}'
QG_NAMES='result\.md|intent\.md|excluded\.md|differential\.yaml|differential-not-counted\.md|verdict\.out'
QG_NAMES="$QG_NAMES"'|topic-scope\.txt|range-scope\.txt|extra-iterations\.md'
QG_NAMES="$QG_NAMES"'|comment-head\.md|comment\.md|publish\.out|publish\.err'
QG_NAMES="$QG_NAMES"'|e2e-record\.md|e2e-flip\.md|e2e-evidence\.tsv|e2e-cmd\.txt|e2e-gate\.txt'
QG_NAMES="$QG_NAMES"'|e2e-before\.txt|e2e-after\.txt|e2e-app\.pgid|e2e-app\.log'
QG_NAMES="$QG_NAMES"'|review-i[1-9][0-9]*\.(names|full\.diff|diff|doc-paths|self-state)'
QG_NAMES="$QG_NAMES"'|result\.md\.tmp\.[0-9]+|e2e-(before|after)\.txt\.tmp|\.resolve-range\.[A-Za-z0-9]{6}'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/(tracked|untracked|filtered)\.z'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/(names|full\.diff|diff|doc-paths|self-state)'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/settings(-local)?-(base|head)'
QG_STATE_RE="^\\.claude/quality-gates/(($QG_SID)/($QG_NAMES)|worktrees/(base|head)-[A-Za-z0-9_-]{8}/)\$"
is_qg_state() {   # <path>
  [[ "$1" =~ $QG_STATE_RE ]] || return 1
  case "$1" in
    .claude/quality-gates/worktrees/base-*/|.claude/quality-gates/worktrees/head-*/) return 0 ;;
    .claude/quality-gates/worktrees/*|.claude/quality-gates/baseline-cache/*) return 1 ;;
  esac
  return 0
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
fi

NAMES=(); UNTR=(); SELF=()
while IFS= read -r -d '' f; do NAMES+=("$f"); done < "$T/tracked.z"
while IFS= read -r -d '' f; do
  if [ -n "$T_REL" ]; then
    case "$f" in "$T_REL"/*) continue ;; esac
  fi
  if is_qg_state "$f"; then SELF+=("$f"); else UNTR+=("$f"); fi
done < "$T/untracked.z"
{
  for f in ${NAMES[@]+"${NAMES[@]}"} ${UNTR[@]+"${UNTR[@]}"}; do printf '%s\n' "$f"; done
} > "$T/names" || gitfail "경로 목록을 쓰지 못했다"
{
  for f in ${SELF[@]+"${SELF[@]}"}; do printf '%s\n' "$f"; done
} > "$T/self-state" || gitfail "상태 경로 목록을 쓰지 못했다"
FILES=$(( ${#NAMES[@]} + ${#UNTR[@]} ))

add_untracked() {   # <out> <path> — untracked 파일 하나를 /dev/null 대비 diff 로 덧붙인다
  [ -d "$2" ] && return 0   # 안에 든 다른 리포(경로 끝 /)는 diff 를 만들 수 없다 — names 에만 남는다
  "${GITD_NOINDEX[@]}" -- /dev/null "$2" >> "$1"
  local rc=$?
  [ "$rc" -le 1 ] || gitfail "untracked 파일의 diff 가 실패했다(rc $rc): $2"
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

is_excluded() {   # <path>
  local x
  for x in ${EXCL[@]+"${EXCL[@]}"}; do [ "$x" = "$1" ] && return 0; done
  return 1
}

# ── 걸러진 diff ────────────────────────────────────────────────────────────
XS=()
for x in ${EXCL[@]+"${EXCL[@]}"}; do XS+=(":(exclude,literal)$x"); done
"${GITD[@]}" "${REV[@]}" -- "${PS[@]}" ${XS[@]+"${XS[@]}"} > "$T/diff" \
  || gitfail "걸러진 git diff 가 실패했다: ${REV[*]}"
"${GITD[@]}" --name-only -z "${REV[@]}" -- "${PS[@]}" ${XS[@]+"${XS[@]}"} > "$T/filtered.z" \
  || gitfail "걸러진 git diff --name-only 가 실패했다: ${REV[*]}"
FILTERED=$(tr -cd '\000' < "$T/filtered.z" | wc -c | tr -d ' ')
for f in ${UNTR[@]+"${UNTR[@]}"}; do
  is_excluded "$f" && continue
  FILTERED=$((FILTERED + 1))
  add_untracked "$T/diff" "$f"
done

publish
emit "$BASE" "$HEAD_LABEL" no "$FILES" "$FILTERED" "${excluded:--}" "${kept:--}" "${dp_source:--}" "${#SELF[@]}"
exit 0
