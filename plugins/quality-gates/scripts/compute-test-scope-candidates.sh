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
  RB_OUT=$("$SCRIPT_DIR/resolve-baseline.sh" 2>/dev/null || true)
  RB_DEGRADED=$(printf '%s\n' "$RB_OUT" | awk '$1 == "degraded:" { print $2 }')
  RB_MERGE_BASE=$(printf '%s\n' "$RB_OUT" | awk '$1 == "merge_base:" { print $2 }')
  if [ "$RB_DEGRADED" = "no" ] && [ -n "$RB_MERGE_BASE" ] && [ "$RB_MERGE_BASE" != "-" ]; then
    REVIEW_RANGE="$RB_MERGE_BASE..HEAD"
  fi
fi

TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|\.test\.|\.spec\.|(^|/)tests?/'

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
