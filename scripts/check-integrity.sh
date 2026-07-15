#!/bin/bash
# check-integrity.sh — AC-1b backstop. Per-file SHA-256 manifest.
#
# Law 2's second line of defence. Tool denial (no Bash/Write/Edit on the auditor
# agents) is the first; this manifest exists for the case where that understanding
# is wrong. It answers exactly one question: did anything on disk change?
#
# Usage:  check-integrity.sh <ld5|harness|global> <out_path>
#
# Three scopes, and the difference between them is load-bearing (design §5.5):
#
#   ld5     LD5 corpus, ignored files INCLUDED. The D4 contamination
#           (plugins/project-init/.claude/...) is itself git-ignored — catching that
#           class is the whole reason this backstop exists. Valid at any time, because
#           every audit artifact lands outside LD5.
#
#   harness LD5 밖이지만 Law 2가 의존하는 파일: .claude/agents/*.md persona 3개 + scripts/*.
#           감사 도중 tamper되면 그 게이트의 GREEN이 무의미하다. AFTER #2가 이걸 본다.
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
case "$MODE" in
  ld5|harness|global) ;;
  *) echo "usage: check-integrity.sh <ld5|harness|global> <out_path>" >&2; exit 2 ;;
esac
if [ -z "$OUT" ]; then
  echo "usage: check-integrity.sh <ld5|harness|global> <out_path>" >&2
  exit 2
fi

# mktemp must not fail silently: an empty TMP laundered into a trap is how a repo
# gets deleted (repo lesson). Abort before the trap is armed.
TMP="$(mktemp -d)" || exit 1
trap 'rm -rf "$TMP"' EXIT

# The line is not "is it git-ignored" — it is "does a machine generate it, or does it hold
# content" (design §5.5).
#
# MACHINE: excluded from ld5 AND global. macOS writes .DS_Store just for opening a directory,
# and stock CPython writes __pycache__ on import. Asking "did an agent hide something here"
# is meaningless — there is no content — while leaving them in guarantees that a normal run
# goes RED and the audit is voided for a change nobody made.
is_machine_generated() {
  case "$1" in
    .DS_Store|*/.DS_Store)                       return 0 ;;
    *.pyc|*/__pycache__/*)                       return 0 ;;
    .pytest_cache/*|*/.pytest_cache/*)           return 0 ;;
  esac
  return 1
}

# CONTENT: excluded from global only, KEPT inside LD5. plugins/project-init/**/.claude/... is
# the D4 contamination — real files with real content — and catching that class is the reason
# this backstop exists at all.
is_foreign_state() {
  case "$1" in
    .claude/*|*/.claude/*)                       return 0 ;;
    .superpowers/*|*/.superpowers/*)             return 0 ;;
    .understand-anything/*|*/.understand-anything/*) return 0 ;;
    # 공유 다중-플러그인 파일: global에서만 제외 (형제 항목 편집이 AFTER#1을 오탐시킨다).
    # 감사자는 이 파일을 쓸 수 없고(Law 2), D3 drift는 §5.4a staleness sweep이 잡는다.
    .claude-plugin/marketplace.json)             return 0 ;;
  esac
  return 1
}

NAMES="$TMP/names.z"
: > "$NAMES"

# -z output is written straight to a file. Capturing it with $(...) drops the NUL
# bytes under macOS /bin/bash 3.2, which destroys the framing and makes the read
# loop run zero times — silently (repo lesson).
case "$MODE" in
  # marketplace.json is EXCLUDED from the integrity snapshot (design §5.5): it is a shared
  # file holding every plugin's entry, so a concurrent edit to a SIBLING plugin's entry would
  # false-RED a perfectly good audit. D3 (marketplace description drift) is caught by the
  # staleness sweep reading the file, not by hashing it. Gap-scope ≠ integrity-scope: the
  # auditor still READS marketplace.json; the backstop just doesn't hash it.
  ld5)     set -- plugins/project-init docs/git-workflow ;;
  # The harness's own load-bearing files. Neither of the other two scopes covers them: global
  # excludes .claude/ wholesale (as "another plugin's runtime state" — but the only tracked
  # things under .claude/ here are our three personas), and they sit outside LD5. So the very
  # files Law 2 rests on had no tamper detection at all while the audit ran.
  harness) set -- .claude/agents scripts ;;
  global)  set -- . ;;
esac
git ls-files -z --                            "$@" >> "$NAMES"
git ls-files -z --others --exclude-standard -- "$@" >> "$NAMES"
git ls-files -z --others --ignored --exclude-standard -- "$@" >> "$NAMES"

while IFS= read -r -d '' f; do
  [ -f "$f" ] || continue
  is_machine_generated "$f" && continue                       # excluded from every scope
  [ "$MODE" = "global" ] && is_foreign_state "$f" && continue # excluded from global only
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
