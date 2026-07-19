#!/usr/bin/env bash
# T3/AC17 — single-target path canonicalization + symlink/.. escape reject.
set -u
SCRIPT="plugins/quality-gates/scripts/artifact_path_auth.py"
PASS=0; FAIL=0
verdict() { python3 "$SCRIPT" "$1" "$2" | sed -n 's/^auth: //p'; }

root="$(mktemp -d)"; mkdir -p "$root/docs"; echo x > "$root/docs/a.md"
outside="$(mktemp -d)"; echo secret > "$outside/passwd"

# 정상 내부 파일 -> ok
[ "$(verdict "$root" "docs/a.md")" = "ok" ] && { PASS=$((PASS+1)); echo "  PASS: inside file ok"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: inside file should be ok"; }
# ../ traversal -> reject
[ "$(verdict "$root" "../$(basename "$outside")/passwd")" = "reject" ] && { PASS=$((PASS+1)); echo "  PASS: .. traversal reject"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: .. traversal should reject"; }
# symlink escape -> reject
ln -s "$outside/passwd" "$root/docs/link.md"
[ "$(verdict "$root" "docs/link.md")" = "reject" ] && { PASS=$((PASS+1)); echo "  PASS: symlink escape reject"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: symlink escape should reject"; }

# CX3-2: an IN-TREE symlink alias must ALSO be rejected (not just escaping ones). git
# tracks the LINK (blob = target string) while reviewers/editor follow it to a DIFFERENT
# real file, splitting classification + commit (raw alias) from review + edit (canonical)
# -- an in-tree symlink to a code file would be critiqued as non-code and its edit left
# uncommitted. A critique target must be a real regular file. Mutation proof: dropping
# the `cand != normpath(abs_target)` reject makes this in-tree symlink read as auth: ok.
echo "code" > "$root/docs/real.py"
ln -s "real.py" "$root/docs/inlink.md"
r_inlink="$(python3 "$SCRIPT" "$root" "docs/inlink.md")"
[ "$(echo "$r_inlink" | sed -n 's/^auth: //p')" = "reject" ] && echo "$r_inlink" | grep -q "reason: symlink_target" \
  && { PASS=$((PASS+1)); echo "  PASS: in-tree symlink alias reject (CX3-2 scope-split)"; } \
  || { FAIL=$((FAIL+1)); echo "  ✗ FAIL: in-tree symlink should reject as symlink_target ($r_inlink)"; }

rm -rf "$root" "$outside"
echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
