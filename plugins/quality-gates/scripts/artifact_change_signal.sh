#!/usr/bin/env bash
# artifact_change_signal.sh — §6 step 6b PRE-COMMIT change signal (AC7).
# MUST run BEFORE the round commit: after commit the working tree is clean and
# this would always report 'false' (the round-2 block bug this fix closes).
# `git diff --quiet HEAD -- <path>` exit 0 = no diff (unchanged), 1 = changed.
# The target is HEAD-tracked+clean at loop entry (E2b), so an edit -> tracked
# modification -> reliably reported. Exit 0 always.
set -u
path="${1:-}"
if [ -z "$path" ]; then
  echo "changed: false"
  echo "reason: missing_arg"
  exit 0
fi
if git diff --quiet HEAD -- "$path" 2>/dev/null; then
  echo "changed: false"
else
  echo "changed: true"
fi
exit 0
