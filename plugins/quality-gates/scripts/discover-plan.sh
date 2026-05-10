#!/usr/bin/env bash
# discover-plan.sh — find a plan file using priority list.
# Output (single-line JSON to stdout):
#   {"plan_path":"<absolute-or-empty>",
#    "source":"explicit|project-local|legacy-global|none",
#    "reason":"<human-readable>"}
# Exit codes: 0 = found, 1 = not found, 2 = invalid input
#
# Priority:
#   1. --plan <path>                    (explicit; no fallback if missing)
#   2. ./docs/superpowers/plans/*.md    (project-local)
#   3. $HOME/.claude/plans/*.md         (legacy global)
#
# Within a chosen source: prefer files with at least one '- [ ]' (unchecked
# checkbox), tiebroken by most-recent mtime; else fall back to most-recent
# file that has at least one checkbox of any kind. Files with zero
# checkboxes are not eligible (a non-plan markdown file should never be
# verified as a plan).
#
# Path-escape note: emitted JSON uses %s and assumes plan paths do not
# contain double-quote or backslash characters. This holds for every plan
# produced by superpowers:writing-plans and any sane filesystem layout.

set -u

EXPLICIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      EXPLICIT="${2:-}"
      shift 2
      ;;
    *)
      printf '{"plan_path":"","source":"none","reason":"Unknown argument: %s"}\n' "$1"
      exit 2
      ;;
  esac
done

emit_json() {
  printf '{"plan_path":"%s","source":"%s","reason":"%s"}\n' "$1" "$2" "$3"
}

# Source 1: explicit override (highest priority; no fallback if missing)
if [[ -n "$EXPLICIT" ]]; then
  if [[ -f "$EXPLICIT" ]]; then
    emit_json "$EXPLICIT" "explicit" "Explicit --plan path"
    exit 0
  else
    emit_json "" "none" "Explicit --plan path does not exist: $EXPLICIT"
    exit 2
  fi
fi

# Portable mtime (BSD stat on macOS, GNU stat on Linux)
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Pick the best plan from a directory of *.md files.
# Echoes the chosen path on success (return 0); returns 1 if none eligible.
pick_best() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return 1

  local best_unchecked="" best_unchecked_mtime=0
  local best_checked="" best_checked_mtime=0
  local f cb_total cb_unchecked m

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    cb_total=$(grep -cE '^- \[[ xX]\]' "$f" 2>/dev/null || true)
    [[ -z "$cb_total" || "$cb_total" -eq 0 ]] && continue
    cb_unchecked=$(grep -cE '^- \[ \]' "$f" 2>/dev/null || true)
    m=$(get_mtime "$f")

    if [[ -n "$cb_unchecked" && "$cb_unchecked" -gt 0 ]]; then
      if [[ "$m" -gt "$best_unchecked_mtime" ]]; then
        best_unchecked="$f"
        best_unchecked_mtime="$m"
      fi
    else
      if [[ "$m" -gt "$best_checked_mtime" ]]; then
        best_checked="$f"
        best_checked_mtime="$m"
      fi
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

  if [[ -n "$best_unchecked" ]]; then
    printf '%s\n' "$best_unchecked"
    return 0
  fi
  if [[ -n "$best_checked" ]]; then
    printf '%s\n' "$best_checked"
    return 0
  fi
  return 1
}

# Source 2: project-local
PROJECT_LOCAL="docs/superpowers/plans"
if PLAN=$(pick_best "$PROJECT_LOCAL"); then
  emit_json "$PLAN" "project-local" "Found in $PROJECT_LOCAL"
  exit 0
fi

# Source 3: legacy global
LEGACY="$HOME/.claude/plans"
if PLAN=$(pick_best "$LEGACY"); then
  emit_json "$PLAN" "legacy-global" "Found in ~/.claude/plans (legacy)"
  exit 0
fi

emit_json "" "none" "No plan file found. Searched: $PROJECT_LOCAL, ~/.claude/plans"
exit 1
