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
# IMPORTANT: invoke from the repository root. The project-local source path is
# resolved against $PWD; calling from elsewhere will silently miss project-local
# plans and fall through to the legacy source or "not found".
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

set -euo pipefail

EXPLICIT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan)
      if [[ $# -lt 2 ]]; then
        printf '{"plan_path":"","source":"none","reason":"--plan requires a path argument"}\n'
        exit 2
      fi
      EXPLICIT="$2"
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

# 디렉토리 탐색 조각(get_mtime · pick_newest)은 형제 discover-spec.sh 과 공유한다.
# source 는 explicit override 이후에 온다 — `--plan <path>` 만 쓰는 호출은 이 파일이
# 없어도 성립하므로, 공유 파일 부재로 그 경로까지 깨뜨리지 않는다.
# `.` 는 POSIX special builtin 이라 파일이 없으면 `if !` 안에서도 셸이 즉시 죽는다
# (bash 3.2.57 실측) — 그래서 source **전에** 읽기 가능 여부를 확인하고, 부재는
# 조용한 crash 가 아니라 계약대로의 JSON + exit 2 로 낸다.
_QG_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -r "$_QG_SCRIPTS_DIR/discover_common.sh" ]]; then
  printf '{"plan_path":"","source":"none","reason":"discover_common.sh not readable next to discover-plan.sh (%s) — plugin install incomplete"}\n' "$_QG_SCRIPTS_DIR"
  exit 2
fi
# shellcheck source=discover_common.sh
. "$_QG_SCRIPTS_DIR/discover_common.sh"

# 적격성 술어 — plan 쪽의 고유 본문. tier 1 은 미체크 항목이 남은 plan,
# tier 2 는 체크박스는 있으나 전부 체크된 plan.
# `^- [ ]` 는 `^- [[ xX]]` 의 부분집합이라 tier 1 통과 = 체크박스 보유가 성립한다.
_plan_has_unchecked() { grep -qE '^- \[ \]' "$1" 2>/dev/null; }
_plan_has_checkbox()  { grep -qE '^- \[[ xX]\]' "$1" 2>/dev/null; }

# Pick the best plan from a directory of *.md files.
# Echoes the chosen path on success (return 0); returns 1 if none eligible.
pick_best() {
  local dir="$1"
  pick_newest "$dir" _plan_has_unchecked && return 0
  pick_newest "$dir" _plan_has_checkbox
}

# Source 2: project-local
# Project-local source resolved against $PWD so emitted paths are absolute.
# Caller must cd to repo root before invoking; see header notes above.
PROJECT_LOCAL="$PWD/docs/superpowers/plans"
if PLAN=$(pick_best "$PROJECT_LOCAL"); then
  emit_json "$PLAN" "project-local" "Found in docs/superpowers/plans/"
  exit 0
fi

# Source 3: legacy global
LEGACY="$HOME/.claude/plans"
if PLAN=$(pick_best "$LEGACY"); then
  emit_json "$PLAN" "legacy-global" "Found in ~/.claude/plans (legacy)"
  exit 0
fi

emit_json "" "none" "No plan file found. Searched: docs/superpowers/plans/, ~/.claude/plans/"
exit 1
