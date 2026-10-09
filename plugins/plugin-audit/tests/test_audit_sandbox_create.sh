#!/usr/bin/env bash
# Unit tests for audit-sandbox.sh create-sandbox subcommand.
# Validates: working-tree reflection, byte-faithful copy (binary/mode/symlink),
# git-ignored exclusion (operational safety), deletion honoring, kill switch.
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/audit-sandbox.sh"
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

NEW_SW=DEVBREW_PLUGIN_AUDIT_DISABLE_RUNTIME_SANDBOX
OLD_SW=DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX
ERRF=$(mktemp)

# kill_case <label> <env assignments...> — exit 3, 아무것도 만들지 않음, stderr 정확히 한 줄.
kill_case() {
  local label="$1"; shift
  local r; r=$(mk_repo)
  ( cd "$r" && env -u "$NEW_SW" -u "$OLD_SW" "$@" "$WT" create-sandbox "kill01234567" >/dev/null 2>"$ERRF" )
  local rc=$?
  [ "$rc" -eq 3 ] && ok "$label → exit 3" || no "$label exit was $rc (want 3)"
  [ ! -e "$r/.claude/plugin-audit" ] && ok "$label → 샌드박스 네임스페이스를 만들지 않는다" \
    || no "$label 인데 $r/.claude/plugin-audit 가 생겼다"
  local wts; wts=$(cd "$r" && git worktree list | wc -l | tr -d ' ')
  assert_eq "$wts" "1" "$label → 워크트리를 더하지 않는다"
  local lines; lines=$(wc -l < "$ERRF" | tr -d ' ')
  assert_eq "$lines" "1" "$label → stderr 는 정확히 한 줄"
  rm -rf "$r"
}

echo "[create-sandbox: kill switch — 새 이름]"
kill_case "새 이름 $NEW_SW=1" "$NEW_SW=1"
assert_contains "$(cat "$ERRF")" "$NEW_SW=1" "새 이름 → stderr 가 새 이름을 밝힌다"
assert_not_contains "$(cat "$ERRF")" "$OLD_SW" "새 이름 → stderr 에 옛 이름이 없다"

echo "[create-sandbox: kill switch — 옛 이름 별칭 (0.11.1)]"
kill_case "옛 이름 $OLD_SW=1" "$OLD_SW=1"
assert_contains "$(cat "$ERRF")" "$OLD_SW=1" "옛 이름 → stderr 가 옛 이름을 밝힌다"
assert_contains "$(cat "$ERRF")" "renamed to $NEW_SW" "옛 이름 → stderr 가 새 이름으로의 개명을 알린다"

echo "[create-sandbox: kill switch — 값 전체 일치만 (양의 짝)]"
# 스위치가 없거나 값이 정확히 1 이 아니면 샌드박스가 선다 — 위 exit 3 이 「무엇이든 막는다」가
# 아니라는 증거.
for assign in "" "$OLD_SW=0" "$OLD_SW=true" "$OLD_SW=11" "$NEW_SW=0"; do
  REPO=$(mk_repo)
  if [ -n "$assign" ]; then
    OUT=$(cd "$REPO" && env -u "$NEW_SW" -u "$OLD_SW" "$assign" "$WT" create-sandbox "pos0123456789" 2>/dev/null); rc=$?
  else
    OUT=$(cd "$REPO" && env -u "$NEW_SW" -u "$OLD_SW" "$WT" create-sandbox "pos0123456789" 2>/dev/null); rc=$?
  fi
  SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
  [ "$rc" -eq 0 ] && [ -n "$SANDBOX" ] && [ -d "$SANDBOX" ] \
    && ok "스위치 '${assign:-없음}' → 샌드박스 생성 (rc 0)" \
    || no "스위치 '${assign:-없음}' → rc=$rc sandbox='$SANDBOX' (샌드박스가 서야 한다)"
  rm -rf "$REPO"
done
rm -f "$ERRF"

echo "[remove: namespace guard]"
REPO=$(mk_repo)
OUT=$(cd "$REPO" && "$WT" create-sandbox "remove012345678" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
mkdir -p "$REPO/outside-ns" && : > "$REPO/outside-ns/keep"
(cd "$REPO" && "$WT" remove "$REPO/outside-ns" 2>/dev/null) \
  && no "remove 가 네임스페이스 밖 대상에 rc 0" || ok "remove 는 네임스페이스 밖을 거부한다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/plugin-audit/worktrees/../../../outside-ns" 2>/dev/null) \
  && no "remove 가 .. 우회 경로에 rc 0" || ok "remove 는 .. 로 네임스페이스를 벗어난 경로도 거부한다"
[ -f "$REPO/outside-ns/keep" ] && ok "거부된 대상이 그대로다" || no "거부된 대상이 사라졌다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/plugin-audit/worktrees/missing-12345678") \
  && ok "없는 대상의 remove 는 성공한다 (멱등)" || no "없는 대상에서 실패했다"
[ -d "$SANDBOX" ] || no "remove 양의 짝의 전제 — 샌드박스가 없다: '$SANDBOX'"
(cd "$REPO" && "$WT" remove "$SANDBOX") && [ ! -d "$SANDBOX" ] \
  && ok "remove 는 네임스페이스 안의 샌드박스를 지운다 (양의 짝)" || no "샌드박스가 남았다"
rm -rf "$REPO"
finish
