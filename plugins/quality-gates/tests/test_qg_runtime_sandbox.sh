#!/usr/bin/env bash
# Unit tests for qg-worktree.sh create-sandbox subcommand.
# Validates: working-tree reflection, byte-faithful copy (binary/mode/symlink),
# git-ignored exclusion (operational safety), deletion honoring, kill switch.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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

[ -d "$SANDBOX" ] && ok "sandbox dir created" || no "no sandbox: '$SANDBOX'"
[ -n "$BASE" ] && ok "baseline SHA emitted" || no "no baseline SHA"

# uncommitted modification reflected
grep -q "MODIFIED" "$SANDBOX/tracked.txt" 2>/dev/null \
  && ok "uncommitted modification reflected" || no "modification missing"
# untracked-not-ignored new file reflected
[ -f "$SANDBOX/src/newfix.js" ] && ok "untracked-not-ignored copied" \
  || no "newfix.js missing"
# git-ignored prod .env NOT copied (operational safety, §6.3c / AC5)
[ ! -f "$SANDBOX/.env" ] && ok "git-ignored .env NOT copied" \
  || no "prod .env leaked into sandbox"
# git-ignored node_modules NOT copied
[ ! -e "$SANDBOX/node_modules" ] && ok "git-ignored node_modules NOT copied" \
  || no "node_modules leaked"
# baseline B is a real commit and working tree is clean against it
( cd "$SANDBOX" && git cat-file -e "$BASE^{commit}" 2>/dev/null ) \
  && ok "baseline B is a commit" || no "B not a commit"
clean=$(cd "$SANDBOX" && git status --porcelain 2>/dev/null)
[ -z "$clean" ] && ok "sandbox clean at baseline B" || no "sandbox dirty after seal: $clean"
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
if cmp -s "$REPO/blob.bin" "$SANDBOX/blob.bin"; then ok "binary byte-identical"; else no "binary differs"; fi
# exec bit preserved
[ -x "$SANDBOX/src_app.js" ] && ok "mode (chmod +x) preserved" || no "exec bit lost"
# symlink preserved as a symlink
[ -L "$SANDBOX/link_to_tracked" ] && ok "symlink preserved as symlink" \
  || no "symlink not preserved"
rm -rf "$REPO"

echo "[create-sandbox: deletion honored]"
REPO=$(mk_repo)
rm "$REPO/src/mod.js"   # delete a tracked file in the working tree
OUT=$(cd "$REPO" && "$WT" create-sandbox "deletion01234567" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ ! -f "$SANDBOX/src/mod.js" ] && ok "tracked deletion honored in sandbox" \
  || no "deleted file survived in sandbox"
rm -rf "$REPO"

echo "[create-sandbox: staged-but-uncommitted reflected in baseline]"
REPO=$(mk_repo)
printf 'STAGED CONTENT\n' > "$REPO/staged.txt"
( cd "$REPO" && git add staged.txt )   # staged in index, NOT committed
OUT=$(cd "$REPO" && "$WT" create-sandbox "staged0123456789" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
BASE=$(printf '%s\n' "$OUT" | sed -n '2p')
[ -f "$SANDBOX/staged.txt" ] && ok "staged file copied into sandbox" || no "staged file missing"
# the sealed baseline B must contain the staged file (so guard diffs are faithful)
( cd "$SANDBOX" && git cat-file -e "$BASE:staged.txt" 2>/dev/null ) \
  && ok "staged file present in baseline B" || no "staged file not in baseline B"
rm -rf "$REPO"

echo "[create-sandbox: kill switch]"
REPO=$(mk_repo)
( cd "$REPO" && DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1 "$WT" create-sandbox "kill01234567" 2>/dev/null )
rc=$?
[ "$rc" -eq 3 ] && ok "kill switch → exit 3" || no "kill switch exit was $rc (want 3)"
rm -rf "$REPO"
finish
