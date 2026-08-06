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
# Exit: 0 on success (including empty result), non-zero only on hard errors
# (e.g., not a git repo). Skill must fail-open (treat non-zero as empty).
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
  git ls-files | grep -cE "$TESTRE" || true
  exit 0
fi

# shellcheck disable=SC2086  # REVIEW_RANGE intentionally word-splits
CHANGED_ALL=$(git diff $REVIEW_RANGE --name-only 2>/dev/null || true)

# Split changed files into src vs test.
CHANGED_SRC=$(echo "$CHANGED_ALL" | grep -vE "$TESTRE" || true)
CHANGED_TESTS=$(echo "$CHANGED_ALL" | grep -E "$TESTRE" || true)

# Heuristic src→test mapping (Python, JS, TS only).
MAPPED=""
while IFS= read -r src; do
  [ -z "$src" ] && continue
  case "$src" in
    *.py)
      base=$(basename "$src" .py)
      while IFS= read -r found; do
        [ -n "$found" ] && MAPPED="${MAPPED}${found}"$'\n'
      done < <(find . -type f \( -name "test_${base}.py" -o -name "${base}_test.py" \) 2>/dev/null | sed 's|^\./||')
      ;;
    *.ts|*.tsx|*.js|*.jsx)
      base=$(basename "$src")
      base="${base%.*}"
      while IFS= read -r found; do
        [ -n "$found" ] && MAPPED="${MAPPED}${found}"$'\n'
      done < <(find . -type f \( \
          -name "${base}.test.ts"   -o -name "${base}.test.tsx" \
       -o -name "${base}.test.js"   -o -name "${base}.test.jsx" \
       -o -name "${base}.spec.ts"   -o -name "${base}.spec.tsx" \
       -o -name "${base}.spec.js"   -o -name "${base}.spec.jsx" \
        \) 2>/dev/null | sed 's|^\./||')
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
