#!/usr/bin/env bash
# compute-test-scope-candidates.sh — 차등 테스트 후보의 바닥(R17). 오케스트레이터는 여기에 더하기만 한다.
#
#   compute-test-scope-candidates.sh                          변경 = 기준선(merge_base) 대비 작업트리 + 무시되지 않는 untracked
#   compute-test-scope-candidates.sh --topic <boundary> <tree>  변경 = <boundary>..<tree> (토픽 스코프)
#   compute-test-scope-candidates.sh --emit-guards            `# guards:` 선언이 변경에 걸린 테스트만
#   compute-test-scope-candidates.sh --total [--tree <tree>]  테스트 파일 수 (계획 줄의 분모)
#
# 후보 = 바뀐 테스트 파일 ∪ 바뀐 소스와 이름이 맞는 테스트(test_<b>.py · <b>_test.py · <b>.test|spec.[jt]sx?)
#        ∪ 머리 30줄의 `# guards: <글롭>...` 이 바뀐 파일에 걸리는 tests/ 아래 .sh.
# 출력: 리포 상대 경로 한 줄에 하나, 정렬·중복 제거. 빈 출력은 「후보가 없다」이다.
# Exit: 0 = 성공 · 1 = git 리포 아님 · 4 = 범위나 분모를 확정하지 못했다(빈 결과가 아니다 — R17).
set -u

die4() { echo "compute-test-scope-candidates: $*" >&2; exit 4; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "compute-test-scope-candidates: not a git repository" >&2; exit 1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|(^|/)test_[^/]*\.py$|\.test\.|\.spec\.|(^|/)tests?/'
GIT=(git -c core.quotePath=false)

if [ "${1:-}" = "--total" ]; then
  if [ "$#" -eq 1 ]; then
    # 분자(후보)가 untracked 를 포함하므로 분모도 포함한다 — 후보 ⊂ 분모.
    names=$("${GIT[@]}" ls-files) || die4 "ls-files 실패 — 분모를 셀 수 없다"
    others=$("${GIT[@]}" ls-files --others --exclude-standard) || die4 "ls-files --others 실패 — 분모를 셀 수 없다"
    names=$(printf '%s\n%s\n' "$names" "$others" | sed '/^$/d' | sort -u)
  elif [ "$#" -eq 3 ] && [ "$2" = "--tree" ] && [ -n "$3" ]; then
    "${GIT[@]}" rev-parse --verify --quiet "$3^{tree}" >/dev/null 2>&1 || die4 "--tree 값을 트리로 풀 수 없다('$3')"
    names=$("${GIT[@]}" ls-tree -r --full-tree --name-only "$3") || die4 "ls-tree 실패 (--tree $3) — 분모를 셀 수 없다"
  else
    die4 "인자 모양이 '--total' 또는 '--total --tree <tree>' 가 아니다(받은 것: $*)"
  fi
  printf '%s\n' "$names" | grep -cE "$TESTRE" || true
  exit 0
fi

mode=worktree; emit_guards=0
case "${1:-}" in
  "") ;;
  --emit-guards) [ "$#" -eq 1 ] || die4 "--emit-guards 는 인자를 받지 않는다"; emit_guards=1 ;;
  --topic)
    [ "$#" -eq 3 ] || die4 "usage: --topic <boundary> <tree>"
    mode=topic; boundary=$2; tree=$3
    "${GIT[@]}" rev-parse --verify --quiet "$boundary^{commit}" >/dev/null 2>&1 || die4 "경계를 커밋으로 풀 수 없다('$boundary')"
    "${GIT[@]}" rev-parse --verify --quiet "$tree^{tree}" >/dev/null 2>&1 || die4 "트리로 풀 수 없다('$tree')"
    ;;
  *) die4 "알 수 없는 인자: $1" ;;
esac

if [ "$mode" = worktree ]; then
  rb=$("$SCRIPT_DIR/resolve-baseline.sh" 2>/dev/null) || die4 "resolve-baseline.sh 를 실행하지 못했다"
  degraded=$(printf '%s\n' "$rb" | awk '$1 == "degraded:" { print $2 }')
  mb=$(printf '%s\n' "$rb" | awk '$1 == "merge_base:" { print $2 }')
  [ "$degraded" = no ] && [ -n "$mb" ] && [ "$mb" != "-" ] \
    || die4 "기준선 미확정(degraded='${degraded:-?}' merge_base='${mb:-?}') — 범위를 확정하지 못했다"
  changed=$("${GIT[@]}" diff --name-only "$mb") || die4 "git diff 실패 ($mb..작업트리)"
  untracked=$("${GIT[@]}" ls-files --others --exclude-standard) || die4 "ls-files --others 실패"
  tracked=$("${GIT[@]}" ls-files) || die4 "ls-files 실패"
  changed=$(printf '%s\n%s\n' "$changed" "$untracked")
  universe=$(printf '%s\n%s\n' "$tracked" "$untracked")
  read_head() { head -30 -- "$1" 2>/dev/null; }
else
  changed=$("${GIT[@]}" diff --name-only "$boundary" "$tree") || die4 "git diff 실패 ($boundary..$tree)"
  universe=$("${GIT[@]}" ls-tree -r --full-tree --name-only "$tree") || die4 "ls-tree 실패 ($tree)"
  read_head() { "${GIT[@]}" show "$tree:$1" 2>/dev/null | head -30; }
fi
changed=$(printf '%s\n' "$changed" | sed '/^$/d' | sort -u)
universe=$(printf '%s\n' "$universe" | sed '/^$/d' | sort -u)

# 이름 일치 — 바뀐 소스의 이름으로 찾을 테스트 파일 이름 목록을 만들고 universe 를 한 번 훑는다.
wanted=$(printf '%s\n' "$changed" | grep -vE "$TESTRE" | awk '
  { n = split($0, p, "/"); f = p[n] }
  f ~ /\.py$/ { b = f; sub(/\.py$/, "", b); print "test_" b ".py"; print b "_test.py"; next }
  f ~ /\.(ts|tsx|js|jsx)$/ { b = f; sub(/\.[^.]*$/, "", b)
    split("test spec", k, " "); split("ts tsx js jsx", e, " ")
    for (i = 1; i <= 2; i++) for (j = 1; j <= 4; j++) print b "." k[i] "." e[j] }')
mapped=""
if [ -n "$wanted" ]; then
  mapped=$(printf '%s\n' "$universe" | awk 'NR == FNR { w[$0] = 1; next } { n = split($0, p, "/"); if (p[n] in w) print }' \
    <(printf '%s\n' "$wanted") -)
fi
changed_tests=$(printf '%s\n' "$changed" | grep -E "$TESTRE" || true)

# `# guards:` — 확장자와 무관하게 선언 글롭이 바뀐 파일에 걸리면 그 락을 후보에 넣는다.
guarded=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  decl=$(read_head "$tf" | sed -n 's/^[[:space:]]*#[[:space:]]*guards:[[:space:]]*//p' | sed 's/[[:space:]]*$//' | head -1)
  [ -z "$decl" ] && continue
  read -r -a globs <<< "$decl"
  hit=0
  for g in "${globs[@]}"; do
    while IFS= read -r ch; do
      [ -z "$ch" ] && continue
      # shellcheck disable=SC2254
      case "$ch" in $g) hit=1; break 2 ;; esac
    done <<< "$changed"
  done
  [ "$hit" -eq 1 ] && guarded="$guarded$tf"$'\n'
done < <(printf '%s\n' "$universe" | grep -E '\.sh$' | grep -E '(^|/)tests?/' || true)

if [ "$emit_guards" -eq 1 ]; then
  printf '%s' "$guarded" | sed '/^[[:space:]]*$/d' | sort -u
  exit 0
fi
printf '%s\n%s\n%s\n' "$mapped" "$changed_tests" "$guarded" | sed '/^[[:space:]]*$/d' | sort -u
exit 0
