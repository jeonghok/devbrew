#!/usr/bin/env bash
# Unit tests for qg-worktree.sh create-sandbox subcommand.
# Validates: working-tree reflection, byte-faithful copy (binary/mode/symlink),
# git-ignored exclusion (operational safety), deletion honoring, kill switch.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }

# --- Build a realistic repo with committed + uncommitted + ignored state ---
mk_repo() {
  local r; r=$(mktemp -d)
  (cd "$r" && git init -q -b main && git config user.email t@t && git config user.name t)
  # committed tracked files
  printf 'orig\n' > "$r/tracked.txt"
  printf 'console.log(1)\n' > "$r/src_app.js"
  mkdir -p "$r/src"
  printf 'v1\n' > "$r/src/mod.js"
  printf 'node_modules/\n.env\n' > "$r/.gitignore"
  (cd "$r" && git add -A && git commit -q -m init)
  # uncommitted modification to a tracked file
  printf 'orig\nMODIFIED\n' > "$r/tracked.txt"
  # new untracked-but-not-ignored file (code under review)
  printf 'NEW SOURCE\n' > "$r/src/newfix.js"
  # git-ignored prod secret — MUST NOT be copied into the sandbox
  printf 'DB_URL=postgres://prod/secret\n' > "$r/.env"
  mkdir -p "$r/node_modules/x" && printf 'dep\n' > "$r/node_modules/x/i.js"
  echo "$r"
}

echo "[create-sandbox: reflection + exclusion]"
REPO=$(mk_repo)
SID="sandbox01234567"
OUT=$(cd "$REPO" && "$WT" create-sandbox "$SID" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
BASE=$(printf '%s\n' "$OUT" | sed -n '2p')

[ -d "$SANDBOX" ] && pass "sandbox dir created" || fail "no sandbox: '$SANDBOX'"
[ -n "$BASE" ] && pass "baseline SHA emitted" || fail "no baseline SHA"

# uncommitted modification reflected
grep -q "MODIFIED" "$SANDBOX/tracked.txt" 2>/dev/null \
  && pass "uncommitted modification reflected" || fail "modification missing"
# untracked-not-ignored new file reflected
[ -f "$SANDBOX/src/newfix.js" ] && pass "untracked-not-ignored copied" \
  || fail "newfix.js missing"
# git-ignored prod .env NOT copied (operational safety, §6.3c / AC5)
[ ! -f "$SANDBOX/.env" ] && pass "git-ignored .env NOT copied" \
  || fail "prod .env leaked into sandbox"
# git-ignored node_modules NOT copied
[ ! -e "$SANDBOX/node_modules" ] && pass "git-ignored node_modules NOT copied" \
  || fail "node_modules leaked"
# baseline B is a real commit and working tree is clean against it
( cd "$SANDBOX" && git cat-file -e "$BASE^{commit}" 2>/dev/null ) \
  && pass "baseline B is a commit" || fail "B not a commit"
clean=$(cd "$SANDBOX" && git status --porcelain 2>/dev/null)
[ -z "$clean" ] && pass "sandbox clean at baseline B" || fail "sandbox dirty after seal: $clean"
rm -rf "$REPO"

echo "[create-sandbox: byte-faithful binary / mode / symlink]"
REPO=$(mk_repo)
# binary change
printf '\x00\x01\x02BIN\xff' > "$REPO/blob.bin"
# mode change on a tracked file (chmod +x)
chmod +x "$REPO/src_app.js"
# new symlink (untracked-not-ignored)
ln -s tracked.txt "$REPO/link_to_tracked"
OUT=$(cd "$REPO" && "$WT" create-sandbox "fidelity01234567" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
# binary content identical
if cmp -s "$REPO/blob.bin" "$SANDBOX/blob.bin"; then pass "binary byte-identical"; else fail "binary differs"; fi
# exec bit preserved
[ -x "$SANDBOX/src_app.js" ] && pass "mode (chmod +x) preserved" || fail "exec bit lost"
# symlink preserved as a symlink
[ -L "$SANDBOX/link_to_tracked" ] && pass "symlink preserved as symlink" \
  || fail "symlink not preserved"
rm -rf "$REPO"

echo "[create-sandbox: deletion honored]"
REPO=$(mk_repo)
rm "$REPO/src/mod.js"   # delete a tracked file in the working tree
OUT=$(cd "$REPO" && "$WT" create-sandbox "deletion01234567" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ ! -f "$SANDBOX/src/mod.js" ] && pass "tracked deletion honored in sandbox" \
  || fail "deleted file survived in sandbox"
rm -rf "$REPO"

echo "[create-sandbox: kill switch]"
REPO=$(mk_repo)
( cd "$REPO" && DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1 "$WT" create-sandbox "kill01234567" 2>/dev/null )
rc=$?
[ "$rc" -eq 3 ] && pass "kill switch → exit 3" || fail "kill switch exit was $rc (want 3)"
rm -rf "$REPO"

echo
echo "Result: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
