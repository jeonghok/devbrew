#!/usr/bin/env bash
# cancel-qg-core.sh — pipeline state cleanup helper (single-session).
#
# Shared between commands/cancel-qg.md and tests/test_cancel_qg.sh so both
# exercise IDENTICAL code paths. The SID pattern guard `[A-Za-z0-9_-]{8,}`
# is critical: a missing/empty session-id would cause `rm -rf
# .claude/quality-gates/` (with trailing slash) to wipe ALL sibling
# sessions. See spec §5.8 TQ-2.

set -euo pipefail

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

# If pipeline.md records a worktree_path (from `/qg branch <name>`), remove
# the worktree first to avoid leaking it. Honors DEVBREW_QG_KEEP_WORKTREE
# the same way session-end-cleanup.py does. This mirrors session-end-
# cleanup.py logic so /cancel-qg has symmetric semantics.
if [[ -f "$target_dir/pipeline.md" ]]; then
  worktree_path=$(awk -F'"' '/^worktree_path:/ { print $2; exit }' "$target_dir/pipeline.md" 2>/dev/null)
  if [[ -n "$worktree_path" && -d "$worktree_path" && "${DEVBREW_QG_KEEP_WORKTREE:-}" != "1" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -x "$script_dir/qg-worktree.sh" ]]; then
      "$script_dir/qg-worktree.sh" remove "$worktree_path" 2>&1 \
        | sed 's/^/cancel-qg-core: worktree: /' >&2 || \
        echo "cancel-qg-core: worktree removal failed (continuing with state-folder cleanup)" >&2
    fi
  fi
fi

if [[ -d "$target_dir" ]]; then
  rm -rf -- "$target_dir"
  echo "cancel-qg-core: removed $target_dir"
else
  echo "cancel-qg-core: no state at $target_dir (no-op)"
fi
