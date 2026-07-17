#!/usr/bin/env bash
# artifact_change_signal.sh — §6 step 6b PRE-COMMIT change signal (AC7), also
# used at E2b to establish the HEAD-tracked+clean precondition.
# MUST run BEFORE the round commit: after commit the working tree is clean and
# `changed:` would always report 'false' (the round-2 block bug this fix closes).
# Emits two independent lines:
#   tracked: true|false -- is <path> tracked in the git index right now?
#     (`git ls-files --error-unmatch -- <path>`, run quietly: exit 0 = tracked,
#     nonzero = untracked.) `git diff --quiet HEAD` is BLIND to an untracked
#     path (it has no HEAD blob to diff against) and silently reports
#     changed:false for it -- so E2b reads `tracked:` first and rejects an
#     untracked target instead of misreading it as "clean" and proceeding.
#   changed: true|false -- `git diff --quiet HEAD -- <path>` exit 0 = no diff
#     (unchanged), 1 = changed. E2b enforces tracked:true (+ changed:false)
#     before the loop starts, so by step 6b the target is guaranteed
#     HEAD-tracked and `changed:` reliably reflects a tracked modification.
# Exit 0 always.
set -u
path="${1:-}"
if [ -z "$path" ]; then
  echo "tracked: false"
  echo "changed: false"
  echo "reason: missing_arg"
  exit 0
fi
if git ls-files --error-unmatch -- "$path" >/dev/null 2>&1; then
  echo "tracked: true"
else
  echo "tracked: false"
fi
if git diff --quiet HEAD -- "$path" 2>/dev/null; then
  echo "changed: false"
else
  echo "changed: true"
fi
exit 0
