#!/usr/bin/env bash
# pr-create.sh — kill-switch/dry-run-enforcing wrapper for the PR-create sink
# (git push + gh pr create), so the create path is a DETERMINISTIC guard, not
# SKILL prose (AC9/AC10 — parity with comment-upsert.py). --dry-run OR
# DEVBREW_QG_DISABLE_PUBLISH=1 → echo intent, perform NO push/create.
set -uo pipefail
dry=0; base=""; head=""; body=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) dry=1; shift;;
    --base) base="$2"; shift 2;;
    --head) head="$2"; shift 2;;
    --body-file) body="$2"; shift 2;;
    *) shift;;
  esac
done
if [[ "${DEVBREW_QG_DISABLE_PUBLISH:-}" == "1" || "$dry" -eq 1 ]]; then
  why="dry-run"; [[ "${DEVBREW_QG_DISABLE_PUBLISH:-}" == "1" ]] && why="publish disabled"
  echo "action: create ($why — network suppressed)"
  exit 0
fi
git push origin "HEAD:$head"
gh pr create --base "$base" --head "$head" --body-file "$body"
echo "action: created"
