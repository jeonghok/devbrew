#!/usr/bin/env bash
# test_build_pr_context.sh — coverage for scripts/build-pr-context.sh (design §4).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/build-pr-context.sh"
PASS=0; FAIL=0; REPO=""
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

mk_repo() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  printf 'def base(): pass\n' > db.py; git add -A; git commit -qm base
  git checkout -q -b feature
  printf 'from db import base\n\ndef handler():\n    return base()\n' > api.py
  git add -A; git commit -qm "add api handler"
}

case_blob_has_content() {
  mk_repo
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qF "def handler():" \
     && printf '%s' "$out" | grep -qF "add api handler" \
     && printf '%s' "$out" | grep -qF "branch: feature"; then
    pass "blob includes changed content + commit subject + branch"
  else
    fail "blob content (got head: $(printf '%s' "$out" | head -20))"
  fi
  cd / && rm -rf "$REPO"
}

case_blob_has_neighbor_signature() {
  mk_repo
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qF "def base()"; then
    pass "neighbor signature (unchanged db.py def) surfaced"
  else
    fail "neighbor signature missing"
  fi
  cd / && rm -rf "$REPO"
}

case_deterministic() {
  mk_repo
  local a b; a=$(bash "$SCRIPT" --base main); b=$(bash "$SCRIPT" --base main)
  if [[ "$a" == "$b" ]]; then pass "byte-identical across runs"; else fail "non-deterministic"; fi
  cd / && rm -rf "$REPO"
}

case_blob_has_content
case_blob_has_neighbor_signature
case_deterministic
echo "build-pr-context: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
