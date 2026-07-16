#!/usr/bin/env bash
# artifact_commit.sh — §7 commit-scope: atomic single-path commit (C5/AC9/AC19).
# ONE command: `git commit --only -- <path>` (NO prior `git add`, NO `-A`).
# --only commits the working-tree version of <path> and nothing else, so
# unrelated pre-existing staged changes are never swept in (C5), and with no
# add/commit two-step there is no partial "add-ok, commit-failed" state (true
# atomicity). Run in project_dir.
set -u
path="${1:-}"
msg="${2:-}"
if [ -z "$path" ] || [ -z "$msg" ]; then
  echo "error: missing_args" >&2
  exit 1
fi
# Defensive no-op guard (step 6b already gates this in the SKILL).
if git diff --quiet HEAD -- "$path" 2>/dev/null; then
  echo "no_op: true"
  exit 0
fi
if out="$(git commit --only -m "$msg" -- "$path" 2>&1)"; then
  echo "committed_sha: $(git rev-parse HEAD)"
  exit 0
else
  echo "error: commit_failed" >&2
  printf '%s\n' "$out" >&2
  exit 1
fi
