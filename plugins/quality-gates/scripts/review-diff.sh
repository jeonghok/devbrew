#!/usr/bin/env bash
# review-diff.sh — 모든 범위 모드의 리뷰 diff 를 한 자리에서 만든다(AC23).
#
# Usage: review-diff.sh --dir <dir> --iter <N> --mode session|branch|paths|topic|range
#                       [--globs <glob>...] [--scope-file <file>]
#
#   session  resolve-baseline.sh 의 merge_base 대비 작업 트리(추적 diff ∪ 무시되지 않는 untracked).
#            추적 안 되는 중첩 리포(ls-files 가 폴더 한 줄로 낸다)는 그 리포의 ls-files -co 로 안의 파일을
#            펼쳐 리뷰한다(paths 도 같다). 폴더를 가리키는 링크는 펼치지 않고 링크로 diff 한다.
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
# 비워 두고 degraded: yes · files: - · self_state: - 로 rc 0. 추적 안 되는 중첩 리포의 목록을 못 읽으면
# 그 폴더 줄만 names 에 남기고 나머지는 그대로 쓴 뒤 degraded: yes(files 등은 수 그대로) · stderr 에 그 폴더로
# rc 0 — 세었는데 리뷰하지 않은 경로를 조용히 두지 않는다. git 실패 rc 4, 사용 오류 rc 2.
#
# qg 자기 산출물(이 실행의 --dir 바로 아래에서 아래 「qg 산출물 문법」 하나에 맞는 경로와 이 리포에
# 등록된 qg 일회용 worktree)은 session · paths 의 untracked 목록에서만 건너뛰고(앞 반복의 산출물이 다음
# 반복의 변경으로 세어지지 않게) 그 수와 경로를 공시한다. 다른 세션 폴더의 파일, 문법에 맞지 않는
# untracked 파일, 추적되는 변경, 커밋된 변경은 그 폴더 아래여도 리뷰한다 — 그 자리에 둔 코드가 리뷰를
# 피하지 못하게. --dir 가 리포 밖이면 아무것도 건너뛰지 않는다(self_state: 0 — stderr 에 그 이유).
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
#             git worktree 라 ls-files 가 폴더 한 줄(끝 /)로만 낸다. `git worktree list` 에 같은 물리
#             경로로 등록된 것만 건너뛰고, 등록되지 않은 같은 이름 폴더(안에 든 다른 리포)는 리뷰한다.
#   테스트    test_review_diff.sh 가 state-file-format.md 의 목록 전부를 이 문법이 받는지 잰다.
QG_NAMES='result\.md|intent\.md|excluded\.md|differential\.yaml|differential-not-counted\.md|verdict\.out'
QG_NAMES="$QG_NAMES"'|topic-scope\.txt|range-scope\.txt|review-tree\.txt|extra-iterations\.md'
QG_NAMES="$QG_NAMES"'|comment-head\.md|comment\.md|publish\.out|publish\.err'
QG_NAMES="$QG_NAMES"'|e2e-record\.md|e2e-flip\.md|e2e-evidence\.tsv|e2e-cmd\.txt|e2e-gate\.txt'
QG_NAMES="$QG_NAMES"'|e2e-before\.txt|e2e-after\.txt|e2e-app\.pgid|e2e-app\.log'
QG_NAMES="$QG_NAMES"'|review-i[1-9][0-9]*\.(names|full\.diff|diff|doc-paths|self-state)'
QG_NAMES="$QG_NAMES"'|result\.md\.tmp\.[0-9]+|e2e-(before|after)\.txt\.tmp|\.resolve-range\.[A-Za-z0-9]{6}'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/(tracked|untracked|filtered)\.z'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/(names|full\.diff|diff|doc-paths|self-state)'
QG_NAMES="$QG_NAMES"'|\.review-diff\.[A-Za-z0-9]{6}/settings(-local)?-(base|head)'
QG_NAMES_RE="^($QG_NAMES)\$"
QG_WT_RE='^\.claude/quality-gates/worktrees/(base|head)-[A-Za-z0-9_-]{8}/$'
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
  [[ "$1" =~ $QG_WT_RE ]] && is_registered_wt "$1" && return 0
  return 1
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

NAMES=(); UNTR=(); SELF=(); NESTED_BAD=(); NESTED_N=0
# 추적 안 되는 중첩 리포 — 바깥 ls-files 는 그 폴더를 한 줄(끝 /)로만 낸다. 그 리포의 ls-files -co 로 안의
# 파일을 펼쳐 리포 최상위 기준 경로(<폴더>/<파일>)로 UNTR 에 더한다(그 안의 중첩 리포도 같은 길, 깊이 16 까지).
# 목록을 못 읽으면(git 실패 · 그 폴더가 리포 최상위가 아님 · 깊이 초과) 폴더 줄을 NESTED_BAD 에 남기고
# 실행 전체가 degraded: yes 다. 링크는 폴더를 가리켜도 펼치지 않는다 — 링크 자체가 리뷰 대상이다.
# 등록된 qg worktree 는 이 함수 전에 is_qg_state 가 건너뛴다. core.fsmonitor 를 꺼 중첩 리포 설정이 명령을
# 돌리지 못하게 한다.
add_untr_entry() {   # <리포 기준 경로> <깊이>
  local p="$1" d n want got f
  if [ ! -d "$p" ] || [ -L "${p%/}" ]; then
    { [ -e "$p" ] || [ -L "${p%/}" ]; } && UNTR+=("${p%/}")   # 목록 뒤 사라진 파일은 리뷰할 글이 없다
    return 0
  fi
  d="${p%/}"
  if [ "$2" -ge 16 ]; then NESTED_BAD+=("$d/"); return 0; fi
  NESTED_N=$((NESTED_N + 1)); n="$T/nested-$NESTED_N.z"
  want="$(cd "$d" 2>/dev/null && pwd -P)" || want=""
  got="$(git -c core.fsmonitor=false -C "$d" rev-parse --show-toplevel 2>/dev/null)" || got=""
  [ -n "$got" ] && got="$(cd "$got" 2>/dev/null && pwd -P)" || got=""
  if [ -z "$want" ] || [ "$got" != "$want" ] \
    || ! git -c core.fsmonitor=false -C "$d" ls-files -co --exclude-standard -z > "$n" 2>/dev/null; then
    NESTED_BAD+=("$d/"); return 0
  fi
  while IFS= read -r -d '' f; do add_untr_entry "$d/$f" $(( $2 + 1 )); done < "$n"
}
while IFS= read -r -d '' f; do NAMES+=("$f"); done < "$T/tracked.z"
while IFS= read -r -d '' f; do
  if [ -n "$T_REL" ]; then
    case "$f" in "$T_REL"/*) continue ;; esac
  fi
  if is_qg_state "$f"; then SELF+=("$f"); else add_untr_entry "$f" 0; fi
done < "$T/untracked.z"
{
  for f in ${NAMES[@]+"${NAMES[@]}"} ${UNTR[@]+"${UNTR[@]}"} ${NESTED_BAD[@]+"${NESTED_BAD[@]}"}; do
    printf '%s\n' "$f"
  done
} > "$T/names" || gitfail "경로 목록을 쓰지 못했다"
{
  for f in ${SELF[@]+"${SELF[@]}"}; do printf '%s\n' "$f"; done
} > "$T/self-state" || gitfail "상태 경로 목록을 쓰지 못했다"
FILES=$(( ${#NAMES[@]} + ${#UNTR[@]} + ${#NESTED_BAD[@]} ))

add_untracked() {   # <out> <path> — untracked 파일 하나를 /dev/null 대비 diff 로 덧붙인다
  local rc
  if [ -L "$2" ] && [ -d "$2" ]; then add_dir_link "$1" "$2"; return; fi
  "${GITD_NOINDEX[@]}" -- /dev/null "$2" >> "$1"
  rc=$?
  [ "$rc" -le 1 ] || gitfail "untracked 파일의 diff 가 실패했다(rc $rc): $2"
}

# 폴더를 가리키는 링크 — git diff --no-index 는 그 인자를 폴더로 읽는다. 링크 대상 글자를 담은 보통 파일을
# 같은 상대 경로로 리포 밖처럼 보이는 임시 폴더에 두고(GIT_CEILING_DIRECTORIES — 경로가 받은 그대로 찍힌다)
# diff 한 뒤 mode 줄만 120000 으로 고친다.
add_dir_link() {   # <out> <path>
  local sl="$T/dirlink" rc
  rm -rf -- "$sl" && mkdir -p -- "$sl" || gitfail "링크 diff 임시 폴더를 만들지 못했다: $sl"
  case "$2" in */*) mkdir -p -- "$sl/${2%/*}" || gitfail "링크 diff 임시 폴더를 만들지 못했다: $2" ;; esac
  readlink -n -- "$2" > "$sl/$2" || gitfail "링크를 읽지 못했다: $2"
  ( cd "$sl" && GIT_CEILING_DIRECTORIES="$T" "${GITD_NOINDEX[@]}" -- /dev/null "$2" ) > "$T/dirlink.patch"
  rc=$?
  [ "$rc" -eq 1 ] || gitfail "링크의 diff 가 실패했다(rc $rc): $2"
  [ "$(sed -n 2p "$T/dirlink.patch")" = "new file mode 100644" ] \
    || gitfail "링크의 diff 모양이 예상과 다르다: $2"
  sed '2s/^new file mode 100644$/new file mode 120000/' "$T/dirlink.patch" >> "$1" \
    || gitfail "링크의 diff 를 쓰지 못했다: $2"
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

deg_out=no
for x in ${NESTED_BAD[@]+"${NESTED_BAD[@]}"}; do
  deg_out=yes
  echo "review-diff: 추적 안 되는 중첩 리포의 파일 목록을 읽지 못해 그 안의 파일을 리뷰 diff 에 싣지 못했다" \
    "— 이 실행은 degraded 다(clean 이 아니다): $x" >&2
done

publish
emit "$BASE" "$HEAD_LABEL" "$deg_out" "$FILES" "$FILTERED" "${excluded:--}" "${kept:--}" "${dp_source:--}" "${#SELF[@]}"
exit 0
