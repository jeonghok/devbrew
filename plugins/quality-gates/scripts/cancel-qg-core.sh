#!/usr/bin/env bash
# cancel-qg-core.sh — pipeline state cleanup helper (single-session).
#
# Shared between commands/cancel-qg.md and tests/test_cancel_qg.sh so both
# exercise IDENTICAL code paths. The SID pattern guard `[A-Za-z0-9_-]{8,}`
# is critical: a missing/empty session-id would cause `rm -rf
# .claude/quality-gates/` (with trailing slash) to wipe ALL sibling
# sessions. See spec §5.8 TQ-2.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

session_id=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --session-id)
      if [[ -z "${2:-}" ]]; then
        echo "cancel-qg-core: --session-id requires an argument" >&2
        exit 2
      fi
      session_id="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: cancel-qg-core.sh [--session-id <id>]"
      echo "  Removes .claude/quality-gates/<id>/ for the named session."
      echo "  If --session-id is omitted, falls back to CLAUDE_CODE_SESSION_ID."
      exit 0
      ;;
    *)
      echo "cancel-qg-core: unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ -z "$session_id" ]]; then
  session_id="${CLAUDE_CODE_SESSION_ID:-}"
fi
if [[ -z "$session_id" ]]; then
  echo "cancel-qg-core: no --session-id and CLAUDE_CODE_SESSION_ID unset" >&2
  exit 1
fi
if ! [[ "$session_id" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  echo "cancel-qg-core: session ID '$session_id' fails pattern guard ([A-Za-z0-9_-]{8,})" >&2
  exit 1
fi

target_dir=".claude/quality-gates/$session_id"

# Read worktree_path once before any cleanup so we know whether to honor
# DEVBREW_QUALITY_GATES_KEEP_WORKTREE. If the env var is set, BOTH the worktree AND
# the state folder are preserved as a unit — removing pipeline.md would
# orphan worktree_path (session-end-cleanup.py discovers worktrees by
# reading the same file).
worktree_path=""
if [[ -f "$target_dir/pipeline.md" ]]; then
  worktree_path=$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$target_dir/pipeline.md" worktree_path 2>/dev/null)
fi

if [[ -n "$worktree_path" && "${DEVBREW_QUALITY_GATES_KEEP_WORKTREE:-}" == "1" ]]; then
  echo "cancel-qg-core: DEVBREW_QUALITY_GATES_KEEP_WORKTREE=1 — preserving worktree at $worktree_path AND state folder $target_dir." >&2
  echo "cancel-qg-core: NOTE: pipeline.md retained so session-end-cleanup.py / future /cancel-qg can still rediscover the worktree." >&2
  exit 0
fi

# Honor worktree-aware cleanup: remove the worktree first (symmetric with
# session-end-cleanup.py). Only fires when KEEP_WORKTREE is not 1.
if [[ -n "$worktree_path" && -d "$worktree_path" ]]; then
  if [[ -x "$SCRIPT_DIR/qg-worktree.sh" ]]; then
    # MED-4: sed pipe 제거. set -euo pipefail 활성 상태이므로
    # `var=$(failing_cmd)` 시 즉시 exit 위험. if/else로 exit code 명시 캡처.
    # qg-worktree.sh 출력 계약 보존: stdout+stderr 병합 스트림을 prefix-emit.
    if worktree_output="$("$SCRIPT_DIR/qg-worktree.sh" remove "$worktree_path" 2>&1)"; then
      worktree_rc=0
    else
      worktree_rc=$?
    fi
    if [[ -n "$worktree_output" ]]; then
      while IFS= read -r line; do
        printf 'cancel-qg-core: worktree: %s\n' "$line" >&2
      done <<< "$worktree_output"
    fi
    if [[ "$worktree_rc" -ne 0 ]]; then
      echo "cancel-qg-core: qg-worktree.sh remove exit code $worktree_rc (continuing with state-folder cleanup)" >&2
    fi
  else
    # MED-1: missing vs not-executable 구별 + 사용자 직접 실행 명령 명시.
    if [[ ! -e "$SCRIPT_DIR/qg-worktree.sh" ]]; then
      echo "cancel-qg-core: qg-worktree.sh MISSING at $SCRIPT_DIR/" >&2
    else
      mode="$(stat -f %Lp "$SCRIPT_DIR/qg-worktree.sh" 2>/dev/null || stat -c %a "$SCRIPT_DIR/qg-worktree.sh" 2>/dev/null)"
      echo "cancel-qg-core: qg-worktree.sh EXISTS but not executable at $SCRIPT_DIR/qg-worktree.sh (mode: $mode)" >&2
    fi
    echo "cancel-qg-core: orphan worktree at $worktree_path — clean manually with:" >&2
    echo "  git worktree remove --force \"$worktree_path\"" >&2
  fi
fi

if [[ -d "$target_dir" ]]; then
  rm -rf -- "$target_dir"
  echo "cancel-qg-core: removed $target_dir"
else
  echo "cancel-qg-core: no state at $target_dir (no-op)"
fi
