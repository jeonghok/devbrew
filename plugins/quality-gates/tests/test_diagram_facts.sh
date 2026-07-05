#!/usr/bin/env bash
# test_diagram_facts.sh — coverage for scripts/diagram-facts.sh (design §6, AC5).
# Each case runs in a throwaway mktemp git repo (live tree untouched, fail-closed).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/diagram-facts.sh"
PASS=0; FAIL=0; REPO=""
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

mk_repo() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  mkdir -p src
  printf 'def base(): pass\n' > src/db.py           # neighbor, unchanged
  printf 'x=1\n' > src/other.py
  git add -A; git commit -qm base
  git checkout -q -b feature
  # a changed file that adds an import of the unchanged neighbor src/db.py
  printf 'from src.db import base\n\ndef handler(): return base()\n' > src/api.py
  git add -A; git commit -qm work
}

case_nodes_include_neighbor() {
  mk_repo
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qxF "src/api.py" \
     && printf '%s' "$out" | grep -qxF "src/db.py"; then
    pass "nodes include changed file AND unchanged imported neighbor"
  else
    fail "nodes (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

case_edges_added_import() {
  mk_repo
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qF "src/api.py -> src/db.py"; then
    pass "edge captured for added import"
  else
    fail "edges (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

case_excludes_vendored() {
  mk_repo
  mkdir -p node_modules/lib
  printf 'export const z=1\n' > node_modules/lib/z.js
  printf "import x from 'node_modules/lib/z.js'\n" >> src/api.py
  git commit -qam more
  local out; out=$(bash "$SCRIPT" --base main)
  if ! printf '%s' "$out" | grep -q "node_modules"; then
    pass "node_modules neighbor excluded"
  else
    fail "vendored not excluded (got: $out)"
  fi
  cd / && rm -rf "$REPO"
}

case_nodes_include_neighbor
case_edges_added_import
case_excludes_vendored
echo "diagram-facts: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
