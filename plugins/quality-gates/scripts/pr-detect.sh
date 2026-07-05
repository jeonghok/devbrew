#!/usr/bin/env bash
# pr-detect.sh — detect PR + push state for the current (or named) branch (design §5).
# gh for PR lookup (built-in --jq, no python3), git for push state. Read-only; tolerates gh absence.
set -uo pipefail

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
[[ "${1:-}" == "--branch" ]] && branch="${2:-$branch}"

num=""; url=""; state=""
if command -v gh >/dev/null 2>&1 \
   && pr_line="$(gh pr view "$branch" --json number,url,state --jq '[.number,.url,.state]|@tsv' 2>/dev/null)" \
   && [[ -n "$pr_line" ]]; then
  IFS=$'\t' read -r num url state <<<"$pr_line"
  echo "has_pr: yes"
else
  echo "has_pr: no"
fi
echo "number: $num"
echo "url: $url"
echo "state: $state"

head="$(git rev-parse HEAD 2>/dev/null || echo "")"
# head_pushed = is HEAD present on origin/<branch> SPECIFICALLY (not just any remote ref)?
if [[ -n "$head" && -n "$branch" ]] \
   && git rev-parse -q --verify "refs/remotes/origin/$branch" >/dev/null 2>&1 \
   && git merge-base --is-ancestor "$head" "refs/remotes/origin/$branch" 2>/dev/null; then
  echo "head_pushed: yes"
else
  echo "head_pushed: no"
fi
