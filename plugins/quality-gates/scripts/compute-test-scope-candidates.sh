#!/usr/bin/env bash
# compute-test-scope-candidates.sh — emit a newline-separated, de-duplicated,
# sorted list of test-file paths that are in-scope for the current diff.
#
# Usage:
#   compute-test-scope-candidates.sh            → in-scope test-file candidates
#   compute-test-scope-candidates.sh --total    → repo-wide test-file COUNT (분모 M, AC37)
#
# Inputs:
#   $PWD            — must be a git working tree
#   (no env vars)   — the review range is derived here, from git alone. The Review
#                     gate's own scope resolution (SKILL.md "Review gate" step 1) is
#                     model-owned and may differ; this script does not read it.
#
# Output (stdout):
#   Default: zero or more lines, one path per line. Paths are repo-relative.
#            Empty stdout means "no candidates" (skill should silently skip Step 2.5).
#   --total: a single integer line.
#
# Exit: 0 = success (including a genuinely empty result — no candidates)
#       1 = not a git repository
#       4 = **the review range could not be diffed.** This is NOT "no candidates".
#           빈 stdout 을 "이 diff 는 테스트를 건드리지 않는다" 로 읽으면 안 된다 —
#           호출자는 이것을 `gap`/`verification: degraded` 사유로 기록해야 한다.
#
# **fail-open 지시 철회 (/qg iter-7 iteration 2, security-reviewer).** 앞 판본은
# *"Skill must fail-open (treat non-zero as empty)"* 라고 적었다. 그 한 줄이 이
# 스크립트의 **유일한 reader-facing 계약**이었으므로, 같은 라운드에 `|| true` 를 걷어내고
# exit 4 를 도입한 수정을 **문서가 그대로 무력화**하고 있었다 — 시끄러운 실패를 조용한
# "후보 없음" 으로 되읽으라는 지시였고, 그것이 정확히 그 수정이 닫으려던 F11 이다.
# 코드를 고치고 계약을 안 고치면 고친 것이 아니다.
#
# Read-only. Never creates/modifies/deletes files.

set -u

# Confirm git context.
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "compute-test-scope-candidates: not a git repository" >&2
  exit 1
fi

# Review range — baseline은 resolve-baseline.sh가 소유 (C2 수정: `main` 하드코딩 +
# merge-base 부재를 제거). 워킹트리가 깨끗할 때만 브랜치 범위를 본다 (기존 동작 유지).
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REVIEW_RANGE=""
if [ -z "$(git diff --name-only 2>/dev/null)" ]; then
  # /qg iter-6 E10 (§6.7 F6): `|| true` 는 소유자 부재·실패를 **빈 출력**으로 바꾼다.
  # 그러면 `RB_DEGRADED` 도 비어 아래 조건이 거짓이 되고, `REVIEW_RANGE=""` 로 조용히
  # 빈 후보 목록이 나온다 — 형제 `check-review-scope.sh` 는 같은 자리에서
  # `|| emit_degraded` 로 fail-closed 다. 여기서도 **원인을 loud 하게** 알린다:
  # 후보 목록은 구조적 힌트라 verdict 를 직접 막지 않지만, "영향 테스트 0개" 가
  # "영향이 없다" 로 읽히면 R2 의 선택 근거가 통째로 거짓이 된다.
  if ! RB_OUT=$("$SCRIPT_DIR/resolve-baseline.sh" 2>/dev/null); then
    echo "compute-test-scope-candidates: resolve-baseline.sh 실행 실패 — 브랜치 범위를 확정하지 못해 워킹트리 diff 만 봅니다 (후보가 과소집계될 수 있음)" >&2
    RB_OUT=""
  fi
  RB_DEGRADED=$(printf '%s\n' "$RB_OUT" | awk '$1 == "degraded:" { print $2 }')
  RB_MERGE_BASE=$(printf '%s\n' "$RB_OUT" | awk '$1 == "merge_base:" { print $2 }')
  if [ "$RB_DEGRADED" = "no" ] && [ -n "$RB_MERGE_BASE" ] && [ "$RB_MERGE_BASE" != "-" ]; then
    REVIEW_RANGE="$RB_MERGE_BASE..HEAD"
  else
    # /qg iter-7 (H4): 위 `if !` 분기는 **스크립트 부재에만** 발화한다 —
    # `resolve-baseline.sh` 는 자기 :37 에 적힌 대로 **언제나 exit 0** 이고 실패를
    # `degraded: yes` 로 표현하기 때문이다. 그래서 훨씬 흔한 경우(정상 실행 +
    # degraded)가 else 없이 조용히 통과해, 이 블록의 전제(워킹트리가 깨끗함) 아래
    # `REVIEW_RANGE=""` 가 되어 **브랜치 전체가 후보 0건**이 됐다. 두 원인이 바이트
    # 동일한 출력을 내는데 하나만 loud 였다. 이제 둘 다 loud 다.
    echo "compute-test-scope-candidates: baseline 미확정 (degraded='${RB_DEGRADED:-?}' merge_base='${RB_MERGE_BASE:-?}') — 브랜치 범위를 쓰지 못해 워킹트리 diff 만 봅니다. 워킹트리가 깨끗하면 후보는 0건이 되며, 그것은 '영향이 없다'가 아니라 '범위를 확정하지 못했다'입니다" >&2
  fi
fi

# /qg iter-6 D1: `test_*.py` 가 빠져 있었다. 아래 매퍼는 명시적으로
# `find -name "test_${base}.py"` 를 하므로 **분자에는 들어가는데 분모에는 안 들어가는**
# 파일이 생겼다 — 실측(레포에 `mod.py` + 루트 `test_mod.py`): 후보 N=1, `--total` M=0.
# SKILL 은 `영향 테스트 N개 선택 (전체 M개 중)` 의 분모를 **비율을 부풀릴 수 없게 하려고**
# 이 스크립트에서 강제로 가져온다. 분모가 분자보다 작아지면 그 보증이 통째로 무너진다.
# 조용한 형태(부분 과소집계로 비율이 좋아 보이는 것)가 `전체 0개 중` 보다 나쁘다.
TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|(^|/)test_[^/]*\.py$|\.test\.|\.spec\.|(^|/)tests?/'

# --total: 리포 전체 테스트 파일 수를 emit (계획 산문의 분모 M — AC37).
# 후보 산출과 **같은 TESTRE**를 전 트리에 적용한다. 분모가 모델 자기보고이면
# 과선택이 심해질수록 분모도 같이 부풀려 비율이 정상으로 보인다.
if [ "${1:-}" = "--total" ]; then
  # M8: quotePath 기본 true 는 비-ASCII 경로를 인용·8진 이스케이프해 TESTRE 를
  # 못 만족시킨다 — 분자(위 git diff)와 **같은 설정**이어야 N>M 이 안 생긴다.
  git -c core.quotePath=false ls-files | grep -cE "$TESTRE" || true
  exit 0
fi

# 1차 데이터 취득. **`|| true` 를 쓰지 않는다 (/qg iter-7, F11).** 앞 버전은 위 :38-43
# 주석이 그 패턴을 iter-6 E10 (§6.7 F6) 으로 닫았다고 적어 놓고 **형제 호출에서만**
# 고쳤고, 정작 후보 전량이 나오는 이 줄에는 그대로 남아 있었다. loose object 손상·부분
# 클론·중단된 fetch 로 git 이 exit 128 을 내면 stdout 은 비고 exit 0 이 되어,
# `resolve-baseline.sh` 가 `degraded: no` 를 낸 그대로 **"건강한 baseline + 영향 테스트
# 0건" = "이 diff 는 테스트를 건드리지 않는다"** 가 된다.
# `core.quotePath=false` 는 M8 — 기본값 true 는 비-ASCII 경로를 8진 이스케이프해서
# 분자·분모 양쪽에서 동시에 탈락시킨다(Korean-primary 레포에 현실적인 입력이다).
# shellcheck disable=SC2086  # REVIEW_RANGE intentionally word-splits
# stderr 를 stdout 으로 접지 **않는다** — 접으면 성공 실행에서 git 이 내는 advice·warning
# 이 파일명 스트림에 섞여 존재하지 않는 "변경된 소스" 가 후보로 들어간다. 진단은 stderr
# 로 흘려보내고(사용자가 그대로 본다) 여기서는 **종료 상태만** 본다.
CTS_ERR=$(mktemp) || { echo "compute-test-scope-candidates: mktemp 실패" >&2; exit 4; }
if ! CHANGED_ALL=$(git -c core.quotePath=false diff $REVIEW_RANGE --name-only 2>"$CTS_ERR"); then
  echo "compute-test-scope-candidates: git diff 실패 (range='${REVIEW_RANGE:-워킹트리}') — 후보를 산출할 수 없습니다. 아래는 git 의 stderr 입니다:" >&2
  cat "$CTS_ERR" >&2
  rm -f "$CTS_ERR"
  exit 4
fi
if [ -s "$CTS_ERR" ]; then
  echo "compute-test-scope-candidates: git 경고 (후보 목록에는 포함되지 않음):" >&2
  cat "$CTS_ERR" >&2
fi
rm -f "$CTS_ERR"

# Split changed files into src vs test.
CHANGED_SRC=$(echo "$CHANGED_ALL" | grep -vE "$TESTRE" || true)
CHANGED_TESTS=$(echo "$CHANGED_ALL" | grep -E "$TESTRE" || true)

# Heuristic src→test mapping (Python, JS, TS only).
MAPPED=""
while IFS= read -r src; do
  [ -z "$src" ] && continue
  case "$src" in
    *.py)
      base=$(basename -- "$src" .py)
      while IFS= read -r found; do
        [ -n "$found" ] && MAPPED="${MAPPED}${found}"$'\n'
      done < <(find . -path ./.claude/quality-gates/worktrees -prune -o -type f \( -name "test_${base}.py" -o -name "${base}_test.py" \) -print 2>/dev/null | sed 's|^\./||')
      ;;
    *.ts|*.tsx|*.js|*.jsx)
      base=$(basename -- "$src")
      base="${base%.*}"
      while IFS= read -r found; do
        [ -n "$found" ] && MAPPED="${MAPPED}${found}"$'\n'
      done < <(find . -path ./.claude/quality-gates/worktrees -prune -o -type f \( \
          -name "${base}.test.ts"   -o -name "${base}.test.tsx" \
       -o -name "${base}.test.js"   -o -name "${base}.test.jsx" \
       -o -name "${base}.spec.ts"   -o -name "${base}.spec.tsx" \
       -o -name "${base}.spec.js"   -o -name "${base}.spec.jsx" \
        \) -print 2>/dev/null | sed 's|^\./||')
      ;;
    # Other languages: no heuristic; only CHANGED_TESTS counts (handled below).
  esac
done <<< "$CHANGED_SRC"

# Union, strip leading ./, sort -u, drop empty lines.
{
  echo "$MAPPED"
  echo "$CHANGED_TESTS"
} | sed 's|^\./||' | sort -u | grep -v '^[[:space:]]*$' || true

exit 0
