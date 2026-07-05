#!/usr/bin/env bash
# pr-detect.sh — detect PR + push state for the current (or named) branch (design §5).
# gh for PR lookup, git for push state. Read-only; tolerates gh absence/failure.
set -uo pipefail

branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")"
[[ "${1:-}" == "--branch" ]] && branch="$2"

num=""; url=""; state=""
if command -v gh >/dev/null 2>&1 \
   && pr_json="$(gh pr view "$branch" --json number,url,state 2>/dev/null)" \
   && [[ -n "$pr_json" ]]; then
  read -r num url state < <(printf '%s' "$pr_json" | python3 -c \
    'import sys,json;d=json.load(sys.stdin);print(d.get("number",""),d.get("url",""),d.get("state",""))')
  echo "has_pr: yes"
else
  echo "has_pr: no"
fi
echo "number: $num"
echo "url: $url"
echo "state: $state"

head="$(git rev-parse HEAD 2>/dev/null || echo "")"
if [[ -n "$head" ]] && git ls-remote --exit-code origin >/dev/null 2>&1 \
   && [[ -n "$(git branch -r --contains "$head" 2>/dev/null)" ]]; then
  echo "head_pushed: yes"
else
  echo "head_pushed: no"
fi
