#!/usr/bin/env bash
# resolve-range.sh — 범위 인자(range <시작>[..<끝>])를 시작 · 끝 커밋 둘로 얼린다.
#
# Usage: resolve-range.sh --out <file> [--] <setup-qg.sh 와 같은 인자 낱말들…>
#
#   낱말 중 `range` 가 없으면 <file> 을 지우고 stdout `range: none`, rc 0.
#   있으면 그 다음 낱말(<spec>)을 풀어 <file> 에 아래 11줄(이 순서)을 쓰고 같은 내용을
#   stdout 에 낸다. status 가 ok 면 rc 0, 그 밖이면 rc 3. 사용 오류는 rc 2.
#
#     mode: range
#     status: ok|bad-spec|start-unresolved|end-unresolved|not-ancestor|empty
#     reason: <한 줄 쉬운 말 | ->
#     spec: <받은 값 그대로>
#     start: <전체 커밋 id | ->
#     end: <전체 커밋 id | ->
#     end_from: given|origin/HEAD|-
#     end_ref: <refs/remotes/origin/… | ->
#     commits: <start..end 커밋 수 | ->
#     files: <start..end 바뀐 파일 수 | ->
#     head_is_end: yes|no|-
#
# <끝> 을 생략하면 origin/HEAD 가 가리키는 ref 만 쓴다 — 다른 이름으로 대신하지 않는다.
# 범위는 실행 시작에 한 번 얼린다. 뒤에 fetch 로 ref 가 움직여도 이 파일의 end 는 그대로이고,
# 소비자(qg-worktree.sh create-head --range 등)는 이 파일의 start · end 만 쓴다.
# 읽기 전용 git 만 쓴다.

set -u

die() { echo "resolve-range: $*" >&2; exit 2; }
usage="usage: resolve-range.sh --out <file> [--] <words…>"

out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --out)
      [[ $# -ge 2 && -n "$2" ]] || die "$usage"
      out="$2"; shift 2 ;;
    --) shift; break ;;
    *) break ;;
  esac
done
[[ -n "$out" ]] || die "$usage"

# 낱말 중 첫 `range` 와 그 다음 낱말
found=0 spec=""
while [[ $# -gt 0 ]]; do
  if [[ "$1" == "range" ]]; then
    found=1
    [[ $# -ge 2 ]] || die "range 뒤에 시작 커밋이 없다(range <시작>[..<끝>])"
    spec="$2"
    break
  fi
  shift
done

if [[ "$found" -eq 0 ]]; then
  rm -f -- "$out" || die "앞 실행의 출력 파일을 지우지 못했다: $out"
  echo "range: none"
  exit 0
fi

git rev-parse --git-dir >/dev/null 2>&1 || die "git 리포 안에서 돌려야 한다"
out_dir=$(dirname -- "$out")
case "$out_dir" in /*) ;; *) out_dir="./$out_dir" ;; esac
[[ -d "$out_dir" ]] || die "출력 폴더가 없다: $out_dir"
# 앞 실행의 결과가 이번 실패 뒤에 남아 읽히지 않게 먼저 지운다.
rm -f -- "$out" || die "앞 실행의 출력 파일을 지우지 못했다: $out"

status="ok" reason="-" start="-" end="-" end_from="-" end_ref="-"
commits="-" files="-" head_is_end="-"

commit_of() {   # <이름> → 전체 커밋 id (못 풀면 빈 값 · rc 1)
  git rev-parse --verify --quiet --end-of-options "$1^{commit}" 2>/dev/null
}

# 모양 검사 — 첫 `..` 에서 나눈다.
s_part="" e_part="" has_end=0
case "$spec" in
  *..*) s_part="${spec%%..*}"; e_part="${spec#*..}"; has_end=1 ;;
  *)    s_part="$spec" ;;
esac
spec_has_ctrl=0
case "$spec" in *[[:cntrl:]]*) spec_has_ctrl=1 ;; esac
if [[ "$spec_has_ctrl" -eq 1 ]] \
   || [[ "$spec" == *...* ]] \
   || [[ -z "$s_part" ]] \
   || [[ "$has_end" -eq 1 && -z "$e_part" ]] \
   || [[ "$s_part" == -* ]] \
   || [[ "$e_part" == -* ]]; then
  status="bad-spec"
  reason="범위 모양이 아니다 — range <시작> 또는 range <시작>..<끝> 으로 적는다(... 이나 - 로 시작하는 값은 받지 않는다)"
fi

if [[ "$status" == "ok" ]]; then
  if start=$(commit_of "$s_part") && [[ -n "$start" ]]; then :; else
    start="-"; status="start-unresolved"
    reason="시작을 커밋으로 풀지 못했다 — 커밋 id 나 브랜치 이름을 확인한다"
  fi
fi

if [[ "$status" == "ok" ]]; then
  if [[ "$has_end" -eq 1 ]]; then
    if end=$(commit_of "$e_part") && [[ -n "$end" ]]; then
      end_from="given"
    else
      end="-"; status="end-unresolved"
      reason="끝을 커밋으로 풀지 못했다 — 커밋 id 나 브랜치 이름을 확인한다"
    fi
  else
    oh_ref=$(git symbolic-ref --quiet refs/remotes/origin/HEAD 2>/dev/null) || oh_ref=""
    oh_end=""
    if [[ -n "$oh_ref" ]]; then
      oh_end=$(commit_of "$oh_ref") || oh_end=""
    fi
    if [[ -n "$oh_end" ]]; then
      end="$oh_end"; end_from="origin/HEAD"; end_ref="$oh_ref"
    else
      status="end-unresolved"
      reason="origin/HEAD 가 가리키는 기본 브랜치를 찾지 못했다 — git remote set-head origin --auto 를 돌리거나 끝 커밋을 적는다(range <시작>..<끝>)"
    fi
  fi
fi

if [[ "$status" == "ok" ]]; then
  if ! git merge-base --is-ancestor "$start" "$end" 2>/dev/null; then
    status="not-ancestor"
    reason="시작이 끝의 조상이 아니다 — 시작에서 끝으로 이어지는 커밋 범위가 아니다"
  elif [[ "$start" == "$end" ]]; then
    status="empty"
    reason="시작과 끝이 같은 커밋이다 — 리뷰할 변경이 없다"
  else
    git diff --quiet "$start" "$end" -- 2>/dev/null
    d_rc=$?
    if [[ "$d_rc" -eq 0 ]]; then
      status="empty"
      reason="시작과 끝 사이에 바뀐 파일이 없다 — 리뷰할 변경이 없다"
    elif [[ "$d_rc" -ne 1 ]]; then
      die "git diff 가 실패했다(rc $d_rc): $start $end"
    fi
  fi
fi

if [[ "$status" == "ok" ]]; then
  commits=$(git rev-list --count "$start..$end" 2>/dev/null) \
    || die "커밋 수를 세지 못했다: $start..$end"
  files=$(git diff --name-only -z "$start" "$end" -- 2>/dev/null | tr -cd '\000' | wc -c | tr -d ' ')
  [[ "$files" =~ ^[0-9]+$ ]] || die "바뀐 파일 수를 세지 못했다: $start..$end"
  head_now=$(commit_of HEAD) || head_now=""
  if [[ -n "$head_now" && "$head_now" == "$end" ]]; then head_is_end="yes"; else head_is_end="no"; fi
fi

# spec 은 받은 값 그대로 — 다만 제어 문자(줄바꿈 등)는 11줄 모양을 깨므로 ? 로 바꿔 적는다.
spec_line="$spec"
if [[ "$spec_has_ctrl" -eq 1 ]]; then
  spec_line=$(printf '%s' "$spec" | LC_ALL=C tr '[:cntrl:]' '?')
fi

tmp=$(mktemp "$out_dir/.resolve-range.XXXXXX") || die "임시 파일을 만들지 못했다: $out_dir"
{
  printf 'mode: range\n'
  printf 'status: %s\n' "$status"
  printf 'reason: %s\n' "$reason"
  printf 'spec: %s\n' "$spec_line"
  printf 'start: %s\n' "$start"
  printf 'end: %s\n' "$end"
  printf 'end_from: %s\n' "$end_from"
  printf 'end_ref: %s\n' "$end_ref"
  printf 'commits: %s\n' "$commits"
  printf 'files: %s\n' "$files"
  printf 'head_is_end: %s\n' "$head_is_end"
} > "$tmp" || { rm -f -- "$tmp"; die "범위 파일을 쓰지 못했다: $tmp"; }
mv -f -- "$tmp" "$out" || { rm -f -- "$tmp"; die "범위 파일을 옮기지 못했다: $out"; }
cat -- "$out"

[[ "$status" == "ok" ]] && exit 0
exit 3
