#!/usr/bin/env bash
# compute-test-scope-candidates.sh — emit a newline-separated, de-duplicated,
# sorted list of test-file paths that are in-scope for the current diff.
#
# Inputs:
#   $PWD            — must be a git working tree
#   (no env vars)   — review range is computed identically to SKILL.md Review gate Step 0
#
# Output (stdout):
#   Zero or more lines, one path per line. Paths are repo-relative.
#   Empty stdout means "no candidates" (skill should silently skip Step 2.5).
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

# Review range — identical formula to the Review gate Step 0 (SKILL.md §"Step 0").
REVIEW_RANGE=""
if [ -z "$(git diff --name-only 2>/dev/null)" ] \
   && git rev-parse --verify --quiet main >/dev/null \
   && [ -n "$(git log --oneline main..HEAD 2>/dev/null)" ]; then
  REVIEW_RANGE="main...HEAD"
fi

TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|\.test\.|\.spec\.|(^|/)tests?/'

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
