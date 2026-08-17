#!/usr/bin/env bash
# test_build_pr_context.sh — coverage for scripts/build-pr-context.sh (design §4).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/build-pr-context.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
REPO=""

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
    ok "blob includes changed content + commit subject + branch"
  else
    no "blob content (got head: $(printf '%s' "$out" | head -20))"
  fi
  cd / && rm -rf "$REPO"
}

case_blob_has_neighbor_signature() {
  mk_repo
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qF "def base()"; then
    ok "neighbor signature (unchanged db.py def) surfaced"
  else
    no "neighbor signature missing"
  fi
  cd / && rm -rf "$REPO"
}

case_deterministic() {
  mk_repo
  local a b; a=$(bash "$SCRIPT" --base main); b=$(bash "$SCRIPT" --base main)
  if [[ "$a" == "$b" ]]; then ok "byte-identical across runs"; else no "non-deterministic"; fi
  cd / && rm -rf "$REPO"
}

case_rename_modify_in_corpus() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  printf 'line1\nline2\nline3\nline4\nline5\nline6\n' > orig.py
  git add -A; git commit -qm base
  git checkout -q -b feature
  git mv orig.py renamed.py
  printf 'MARKER_RENAME_MOD\n' >> renamed.py
  git add -A; git commit -qm "rename and modify"
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qF "MARKER_RENAME_MOD"; then
    ok "renamed+modified file content present in blob (corpus completeness)"
  else
    no "rename+modify content dropped from blob (got: $(printf '%s' "$out" | head -30))"
  fi
  cd / && rm -rf "$REPO"
}

case_binary_skipped() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main; echo seed > seed.txt; git add -A; git commit -qm base
  git checkout -q -b feature
  printf '\x00\x01\x02\x03binary\x00stuff' > blob.bin
  git add -A; git commit -qm "add binary"
  local out; out=$(bash "$SCRIPT" --base main)
  if printf '%s' "$out" | grep -qF "(binary omitted)"; then
    ok "binary file labeled (binary omitted), no garbage in blob"
  else
    no "binary handling (got head: $(printf '%s' "$out" | head -20))"
  fi
  cd / && rm -rf "$REPO"
}

case_history_flag_includes_intermediate_secret() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main; echo base > f.txt; git add -A; git commit -qm base
  git checkout -q -b feature
  printf 'k=ghp_intermediateAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' >> f.txt
  git commit -qam "add secret (intermediate)"
  echo base > f.txt; git commit -qam "remove secret"   # gone from final file
  local plain hist
  plain=$(bash "$SCRIPT" --base main); hist=$(bash "$SCRIPT" --base main --history)
  if ! printf '%s' "$plain" | grep -q "ghp_intermediate" && printf '%s' "$hist" | grep -q "ghp_intermediate"; then
    ok "--history surfaces intermediate-commit content the default blob omits"
  else no "history flag (plain-has=$(printf '%s' "$plain"|grep -c ghp_intermediate) hist-has=$(printf '%s' "$hist"|grep -c ghp_intermediate))"; fi
  cd / && rm -rf "$REPO"
}
case_no_merge_base_degrades() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q; git config user.email t@t.test; git config user.name tester
  git checkout -q -b main; echo a > a.txt; git add -A; git commit -qm a
  git checkout -q --orphan feature; git rm -rf . >/dev/null 2>&1 || true
  echo b > b.txt; git add -A; git commit -qm b
  local out rc; out=$(bash "$SCRIPT" --base main 2>&1); rc=$?
  if [[ "$rc" -eq 0 ]] && printf '%s' "$out" | grep -qi 'degraded'; then
    ok "no merge-base → graceful degrade (exit 0)"
  else no "no-merge-base (rc=$rc)"; fi
  cd / && rm -rf "$REPO"
}

case_blob_has_content
case_blob_has_neighbor_signature
case_deterministic
case_rename_modify_in_corpus
case_binary_skipped
case_history_flag_includes_intermediate_secret
case_no_merge_base_degrades
finish
