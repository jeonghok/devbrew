#!/bin/bash
# check-integrity.sh — AC-1b backstop. Per-file SHA-256 manifest.
#
# Law 2's second line of defence. Tool denial (no Bash/Write/Edit on the auditor
# agents) is the first; this manifest exists for the case where that understanding
# is wrong. It answers exactly one question: did anything on disk change?
#
# Usage:  check-integrity.sh <ld5|global> <out_path>
#
# Two scopes, and the difference between them is load-bearing (design §5.5):
#
#   ld5     LD5 corpus, ignored files INCLUDED. The D4 contamination
#           (plugins/project-init/.claude/...) is itself git-ignored — catching that
#           class is the whole reason this backstop exists. Valid at any time, because
#           every audit artifact lands outside LD5.
#
#   global  Whole repo, ignored files included MINUS the volatile list below. Only
#           valid at AFTER #1, when zero legitimate deltas exist. Without the volatile
#           exclusions a normal run goes RED: macOS writes .DS_Store just for opening a
#           directory, and sibling plugins write runtime state into .claude/ while the
#           audit is running (76 ignored files measured in this repo).
#
# git status --porcelain is NOT used: it collapses an ignored directory to a single
# line (!! .pytest_cache/) and so cannot see content changes inside it.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)" || exit 1
cd "$REPO_ROOT" || exit 1

MODE="${1:-}"
OUT="${2:-}"
if [ "$MODE" != "ld5" ] && [ "$MODE" != "global" ]; then
  echo "usage: check-integrity.sh <ld5|global> <out_path>" >&2
  exit 2
fi
if [ -z "$OUT" ]; then
  echo "usage: check-integrity.sh <ld5|global> <out_path>" >&2
  exit 2
fi

# mktemp must not fail silently: an empty TMP laundered into a trap is how a repo
# gets deleted (repo lesson). Abort before the trap is armed.
TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# Volatile paths — excluded from the GLOBAL snapshot only, never from LD5.
is_volatile() {
  case "$1" in
    .DS_Store|*/.DS_Store)                       return 0 ;;
    .pytest_cache/*|*/.pytest_cache/*)           return 0 ;;
    .claude/*|*/.claude/*)                       return 0 ;;
    .superpowers/*|*/.superpowers/*)             return 0 ;;
    .understand-anything/*|*/.understand-anything/*) return 0 ;;
    *.pyc|*/__pycache__/*)                       return 0 ;;
  esac
  return 1
}

NAMES="$TMP/names.z"
: > "$NAMES"

# -z output is written straight to a file. Capturing it with $(...) drops the NUL
# bytes under macOS /bin/bash 3.2, which destroys the framing and makes the read
# loop run zero times — silently (repo lesson).
if [ "$MODE" = "ld5" ]; then
  set -- plugins/project-init docs/git-workflow .claude-plugin/marketplace.json
else
  set -- .
fi
git ls-files -z --                            "$@" >> "$NAMES"
git ls-files -z --others --exclude-standard -- "$@" >> "$NAMES"
git ls-files -z --others --ignored --exclude-standard -- "$@" >> "$NAMES"

while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  if [ "$MODE" = "global" ] && is_volatile "$f"; then
    continue
  fi
  shasum -a 256 "$f"
done < "$NAMES" | LC_ALL=C sort -u > "$OUT"

COUNT=$(wc -l < "$OUT" | tr -d ' ')

# An empty manifest would compare equal to any other empty manifest — a backstop
# that passes by being blind. Fail loudly instead.
if [ "$COUNT" -eq 0 ]; then
  echo "[check-integrity] FATAL: manifest is empty (mode=$MODE) — enumeration produced nothing." >&2
  exit 1
fi

echo "[check-integrity] mode=$MODE files=$COUNT -> $OUT" >&2
