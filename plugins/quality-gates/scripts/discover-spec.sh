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

# 디렉토리 탐색 조각(get_mtime · pick_newest)은 형제 discover-plan.sh 과 공유한다.
# source 는 explicit override 이후에 온다 — `--spec <path>` 만 쓰는 호출은 이 파일이
# 없어도 성립하므로, 공유 파일 부재로 그 경로까지 깨뜨리지 않는다.
# `.` 는 POSIX special builtin 이라 파일이 없으면 `if !` 안에서도 셸이 즉시 죽는다
# (bash 3.2.57 실측) — 그래서 source **전에** 읽기 가능 여부를 확인하고, 부재는
# 조용한 crash 가 아니라 계약대로의 JSON + exit 2 로 낸다.
_QG_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -r "$_QG_SCRIPTS_DIR/discover_common.sh" ]]; then
  printf '{"spec_path":"","source":"none","reason":"discover_common.sh not readable next to discover-spec.sh (%s) — plugin install incomplete"}\n' "$_QG_SCRIPTS_DIR"
  exit 2
fi
# shellcheck source=discover_common.sh
. "$_QG_SCRIPTS_DIR/discover_common.sh"

# 적격성 술어 — spec 쪽의 고유 본문. Acceptance Criteria 헤더가 spec 의 정의다.
_spec_has_ac() { grep -qE '^#+ .*Acceptance Criteria' "$1" 2>/dev/null; }

# Pick the best spec from a directory of *.md files.
# Eligible = contains an Acceptance Criteria header. Among eligible, newest mtime.
# Echoes the chosen path on success (return 0); returns 1 if none eligible.
pick_best() {
  pick_newest "$1" _spec_has_ac
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
