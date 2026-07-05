#!/usr/bin/env bash
# diagram-facts.sh — deterministic diagram grounding (design §6).
# nodes = changed files + imported neighbors (repo-root-relative only).
# edges = added import lines resolved to a repo file.
# Pure git + grep; no semantic understanding. Emits key/value + list blocks.
#
# Usage: diagram-facts.sh [--base <ref>] [--nodes]
#   --nodes : print only the resolved neighbor node paths (one per line), for
#             build-pr-context.sh signature extraction.
set -euo pipefail

base_ref="origin/main"; nodes_only=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) base_ref="$2"; shift 2;;
    --nodes) nodes_only=1; shift;;
    *) shift;;
  esac
done
git rev-parse --verify -q "$base_ref" >/dev/null 2>&1 || base_ref="main"
base="$(git merge-base "$base_ref" HEAD 2>/dev/null || echo "")"
[[ -n "$base" ]] || { echo "degraded: yes"; exit 0; }

changed="$(git diff --name-only --diff-filter=ACM "$base"..HEAD)"

# Extract the imported MODULE token from one added import line. Priority order
# (greedy `.*(from|import)` would grab the wrong keyword on `from M import N`):
#   1) quoted path (JS/TS: import x from 'M' / require('M') / import 'M')
#   2) python  from M import ...   → M
#   3) python  import M            → M
extract_import() {
  local line="$1" tok=""
  tok="$(printf '%s' "$line" | sed -nE "s/.*['\"]([A-Za-z0-9_./@-]+)['\"].*/\1/p" | head -1)"
  [[ -n "$tok" ]] && { printf '%s\n' "$tok"; return; }
  tok="$(printf '%s' "$line" | sed -nE "s/^\+?[[:space:]]*from[[:space:]]+([A-Za-z0-9_.]+).*/\1/p" | head -1)"
  [[ -n "$tok" ]] && { printf '%s\n' "$tok"; return; }
  printf '%s' "$line" | sed -nE "s/^\+?[[:space:]]*import[[:space:]]+([A-Za-z0-9_.]+).*/\1/p" | head -1
}

# Resolve an import token to a repo-relative file, or empty if not in-repo.
resolve() {
  local from="$1" tok="$2" cand
  tok="${tok#./}"   # python dotted → a/b/c.py via ${tok//.//}; js relative via dirname
  for cand in "${tok}.py" "${tok//.//}.py" "${tok}.ts" "${tok}.js" \
              "$(dirname "$from")/${tok}.ts" "$(dirname "$from")/${tok}.js" \
              "$(dirname "$from")/${tok}.py" "$tok"; do
    cand="${cand#./}"
    case "$cand" in node_modules/*|vendor/*|/*) continue;; esac
    if [[ -f "$cand" ]] && git ls-files --error-unmatch "$cand" >/dev/null 2>&1; then
      printf '%s\n' "$cand"; return 0
    fi
  done
  return 1
}

edges=""; neighbors=""
while IFS= read -r f; do
  [[ -n "$f" ]] || continue
  # added import lines in this file's diff (leading '+', not '+++')
  while IFS= read -r imp; do
    tok="$(extract_import "$imp")"
    [[ -n "$tok" ]] || continue
    dst="$(resolve "$f" "$tok" || true)"
    [[ -n "$dst" ]] || continue
    edges+="$f -> $dst"$'\n'
    neighbors+="$dst"$'\n'
  done < <(git diff "$base"..HEAD -- "$f" | grep -E '^\+' | grep -vE '^\+\+\+' \
            | grep -E '(^\+[[:space:]]*(import|from)|require\()')
done <<< "$changed"

nodes="$(printf '%s\n%s' "$changed" "$neighbors" | grep -v '^$' | sort -u)"

if [[ "$nodes_only" -eq 1 ]]; then
  printf '%s\n' "$neighbors" | grep -v '^$' | sort -u
  exit 0
fi

echo "nodes:"; printf '%s\n' "$nodes"
echo "edges:"; printf '%s' "$edges" | grep -v '^$' | sort -u || true
echo "degraded: no"
