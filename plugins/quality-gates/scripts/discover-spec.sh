#!/usr/bin/env bash
# discover-spec.sh — find a project SPEC file using a priority list.
# Mirror of discover-plan.sh, re-aimed at the spec artifact (the AC truth).
#
# Output (single-line JSON to stdout):
#   {"spec_path":"<absolute-or-empty>",
#    "source":"explicit|project-local|none",
#    "reason":"<human-readable>"}
# Exit codes: 0 = found, 1 = not found, 2 = invalid input
#
# Priority:
#   1. --spec <path>                     (explicit; no fallback if missing)
#   2. ./docs/superpowers/specs/*.md     (project-local)
#
# There is NO legacy-global source: a spec is a project artifact and (unlike a
# plan) has no established global-location convention. project-local only.
#
# IMPORTANT: invoke from the repository root. The project-local source path is
# resolved against $PWD; calling from elsewhere will silently miss project-local
# specs and report "not found".
#
# Eligibility: within the project-local source, only files containing an
# "Acceptance Criteria" section header (regex '^#+ .*Acceptance Criteria') are
# eligible — the spec's AC section is exactly what qg verifies conformance
# against. A markdown file with no AC section is not a spec (mirror of
# discover-plan's "no checkbox -> not a plan"). Among eligible files, the
# most-recent mtime wins.
#
# Path-escape note: emitted JSON uses %s and assumes spec paths do not contain
# double-quote or backslash characters (holds for any sane filesystem layout).

set -euo pipefail

EXPLICIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --spec)
      if [[ $# -lt 2 ]]; then
        printf '{"spec_path":"","source":"none","reason":"--spec requires a path argument"}\n'
        exit 2
      fi
      EXPLICIT="$2"
      shift 2
      ;;
    *)
      printf '{"spec_path":"","source":"none","reason":"Unknown argument: %s"}\n' "$1"
      exit 2
      ;;
  esac
done

emit_json() {
  printf '{"spec_path":"%s","source":"%s","reason":"%s"}\n' "$1" "$2" "$3"
}

# Source 1: explicit override (highest priority; no fallback if missing)
if [[ -n "$EXPLICIT" ]]; then
  if [[ -f "$EXPLICIT" ]]; then
    emit_json "$EXPLICIT" "explicit" "Explicit --spec path"
    exit 0
  else
    emit_json "" "none" "Explicit --spec path does not exist: $EXPLICIT"
    exit 2
  fi
fi

# Portable mtime (BSD stat on macOS, GNU stat on Linux)
get_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# Pick the best spec from a directory of *.md files.
# Eligible = contains an Acceptance Criteria header. Among eligible, newest mtime.
# Echoes the chosen path on success (return 0); returns 1 if none eligible.
pick_best() {
  local dir="$1"
  [[ ! -d "$dir" ]] && return 1

  local best="" best_mtime=0
  local f m

  while IFS= read -r f; do
    [[ -z "$f" ]] && continue
    grep -qE '^#+ .*Acceptance Criteria' "$f" 2>/dev/null || continue
    m=$(get_mtime "$f")
    if [[ "$m" -gt "$best_mtime" ]]; then
      best="$f"
      best_mtime="$m"
    fi
  done < <(find "$dir" -maxdepth 1 -type f -name '*.md' 2>/dev/null)

  if [[ -n "$best" ]]; then
    printf '%s\n' "$best"
    return 0
  fi
  return 1
}

# Source 2: project-local
# Resolved against $PWD so emitted paths are absolute. Caller must cd to repo
# root before invoking; see header notes.
PROJECT_LOCAL="$PWD/docs/superpowers/specs"
if SPEC=$(pick_best "$PROJECT_LOCAL"); then
  emit_json "$SPEC" "project-local" "Found in docs/superpowers/specs/"
  exit 0
fi

emit_json "" "none" "No spec file found. Searched: docs/superpowers/specs/"
exit 1
