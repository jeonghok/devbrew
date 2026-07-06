#!/usr/bin/env bash
# pr-create.sh — kill-switch/dry-run-enforcing wrapper for the PR-create sink
# (git push + gh pr create), so the create path is a DETERMINISTIC guard, not
# SKILL prose (AC9/AC10 — parity with comment-upsert.py). --dry-run OR
# DEVBREW_QG_DISABLE_PUBLISH=1 → echo intent, perform NO push/create.
set -euo pipefail
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
# Defense-in-depth: verify gh is present AND authenticated BEFORE any push, so a
# missing/unauth gh degrades to artifact-only WITHOUT leaving an orphan pushed
# branch. The SKILL Preflight (`gh auth status`) also checks this upstream; this
# in-sink guard makes the deterministic wrapper self-contained (its design goal).
if ! command -v gh >/dev/null 2>&1 || ! gh auth status >/dev/null 2>&1; then
  echo "action: create-skipped (gh unavailable/unauth — artifact-only)"
  exit 1
fi
# Fail CLOSED with a LITERAL gate line (never gate on exit code — a pipe can
# swallow it, v2.7.0 lesson). "action: created" is emitted ONLY after BOTH the
# push and the create succeed; either failure emits "action: create-failed" and
# a non-zero exit, so the orchestrator can never read a failed publish as done.
if ! git push origin "HEAD:$head"; then
  echo "action: create-failed (git push failed)"
  exit 1
fi
if ! gh pr create --base "$base" --head "$head" --body-file "$body"; then
  echo "action: create-failed (gh pr create failed)"
  exit 1
fi
echo "action: created"
