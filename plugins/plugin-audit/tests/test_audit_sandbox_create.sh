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

# ---------------------------------------------------------------------------
# 사본 자리 — <top>/.claude/worktrees/audit-rt-<sid8> (사용자 · 지휘자 worktree 와 같은 폴더를 쓴다)
# ---------------------------------------------------------------------------
phys() { (cd "$1" && pwd -P); }
# 임시 저장소가 정말 만들어졌는지 — 빈 값이면 `cd ""` 가 지금 디렉터리를 가리키므로 부모 셸에서 검사한다.
# 호출은 $(...) 안이 아니라 부모 셸에서 한다 — 부분 셸의 exit 는 스크립트를 멈추지 못한다. 결과는 REPO · OUTSIDE.
mk_repo_checked() {
  REPO=$(mk_repo)
  [ -n "$REPO" ] && [ -d "$REPO/.git" ] || { echo "mk_repo 실패: '$REPO'" >&2; exit 2; }
}
mk_outside_checked() {
  OUTSIDE=$(mktemp -d)
  [ -n "$OUTSIDE" ] && [ -d "$OUTSIDE" ] || { echo "mktemp 실패: '$OUTSIDE'" >&2; exit 2; }
}

echo "[사본 자리: 본 체크아웃과 linked worktree 둘 다 <top>/.claude/worktrees/audit-rt-<sid8>]"
mk_repo_checked
OUT=$(cd "$REPO" && "$WT" create-sandbox "place0123456789" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
assert_eq "$SANDBOX" "$(phys "$REPO")/.claude/worktrees/audit-rt-place012" "본 체크아웃 → 새 자리"
[ -d "$REPO/.claude/plugin-audit" ] && no "옛 자리 폴더가 생겼다" || ok "옛 자리 폴더를 만들지 않는다"
(cd "$REPO" && git worktree add -q -b linked-br "$REPO/linked-wt" >/dev/null 2>&1)
OUT=$(cd "$REPO/linked-wt" && "$WT" create-sandbox "place0123456789" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
assert_eq "$SANDBOX" "$(phys "$REPO/linked-wt")/.claude/worktrees/audit-rt-place012" "linked worktree → 그 안의 새 자리"
rm -rf "$REPO"

echo "[사본 자리: 다른 worktree 는 그대로 (AC12) · 같은 이름 재실행은 다시 만든다]"
mk_repo_checked
(cd "$REPO" && git branch feat-x && git worktree add -q "$REPO/.claude/worktrees/feat-x" feat-x >/dev/null 2>&1)
(cd "$REPO" && git worktree add -q --detach "$REPO/.claude/worktrees/user-detached" HEAD >/dev/null 2>&1)
printf 'keep\n' > "$REPO/.claude/worktrees/feat-x/mine.txt"
(cd "$REPO" && "$WT" create-sandbox "again0123456789" >/dev/null 2>&1)
printf 'stale\n' > "$REPO/.claude/worktrees/audit-rt-again012/stale.txt"
OUT=$(cd "$REPO" && "$WT" create-sandbox "again0123456789" 2>/dev/null); rc=$?
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ "$rc" -eq 0 ] && [ -d "$SANDBOX" ] && [ ! -e "$SANDBOX/stale.txt" ] \
  && ok "같은 이름 재실행 → 앞 사본을 지우고 다시 만든다" || no "재실행 rc=$rc"
[ -f "$REPO/.claude/worktrees/feat-x/mine.txt" ] && ok "브랜치 worktree feat-x 보존" || no "feat-x 가 사라졌다"
[ -d "$REPO/.claude/worktrees/user-detached" ] && ok "detached 사용자 worktree 보존" || no "user-detached 가 사라졌다"
(cd "$REPO" && git worktree list | grep -q 'feat-x') && ok "feat-x 등록 유지" || no "feat-x 등록이 풀렸다"
rm -rf "$REPO"

echo "[사본 자리: 같은 이름 브랜치 worktree 면 멈춘다 · 등록 풀린 폴더는 다시 만든다]"
mk_repo_checked
(cd "$REPO" && git branch audit-rt-brnch012 && git worktree add -q "$REPO/.claude/worktrees/audit-rt-brnch012" audit-rt-brnch012 >/dev/null 2>&1)
printf 'mine\n' > "$REPO/.claude/worktrees/audit-rt-brnch012/mine.txt"
(cd "$REPO" && "$WT" create-sandbox "brnch0123456789" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "브랜치를 쥔 같은 이름 → die (rc 2)"
[ -f "$REPO/.claude/worktrees/audit-rt-brnch012/mine.txt" ] && ok "브랜치 worktree 는 지워지지 않는다" || no "브랜치 worktree 가 지워졌다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/audit-rt-brnch012" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "remove 도 브랜치를 쥔 worktree 는 거부 (rc 2)"
[ -f "$REPO/.claude/worktrees/audit-rt-brnch012/mine.txt" ] && ok "remove 후에도 그대로" || no "remove 가 브랜치 worktree 를 지웠다"
rm -rf "$REPO"
mk_repo_checked
mkdir -p "$REPO/.claude/worktrees/audit-rt-orphan01" && printf 'x\n' > "$REPO/.claude/worktrees/audit-rt-orphan01/junk"
OUT=$(cd "$REPO" && "$WT" create-sandbox "orphan0123456789" 2>/dev/null); rc=$?
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ "$rc" -eq 0 ] && [ -d "$SANDBOX" ] && [ ! -e "$SANDBOX/junk" ] \
  && ok "등록 풀린 폴더 → 지우고 다시 만든다" || no "등록 풀린 폴더 rc=$rc"
rm -rf "$REPO"

echo "[사본 자리: 링크는 링크만 지운다]"
mk_repo_checked
mkdir -p "$REPO/.claude/worktrees" "$REPO/elsewhere" && printf 'precious\n' > "$REPO/elsewhere/keep"
ln -s "$REPO/elsewhere" "$REPO/.claude/worktrees/audit-rt-linkx012"
OUT=$(cd "$REPO" && "$WT" create-sandbox "linkx0123456789" 2>/dev/null); rc=$?
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ "$rc" -eq 0 ] && [ -d "$SANDBOX" ] && [ ! -L "$SANDBOX" ] && ok "링크를 치우고 사본을 만든다" || no "링크 자리 rc=$rc"
[ -f "$REPO/elsewhere/keep" ] && ok "링크 대상 내용은 그대로" || no "링크 너머가 지워졌다"
ln -s "$REPO/elsewhere" "$REPO/.claude/worktrees/audit-rt-linkr012"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/audit-rt-linkr012" >/dev/null 2>&1)
[ ! -L "$REPO/.claude/worktrees/audit-rt-linkr012" ] && [ -f "$REPO/elsewhere/keep" ] \
  && ok "remove 는 링크만 지운다" || no "remove 가 링크 너머를 건드렸거나 링크가 남았다"
rm -rf "$REPO"

echo "[사본 자리: 대소문자만 다른 항목은 자기 것이 아니다]"
mk_repo_checked
mkdir -p "$REPO/.claude/worktrees/AUDIT-RT-case0123" && printf 'user\n' > "$REPO/.claude/worktrees/AUDIT-RT-case0123/mine.txt"
if [ -e "$REPO/.claude/worktrees/audit-rt-case0123" ]; then   # 대소문자를 구분하지 않는 파일시스템에서만 의미가 있다
  (cd "$REPO" && "$WT" create-sandbox "case0123456789" >/dev/null 2>&1); rc=$?
  assert_eq "$rc" "2" "대소문자만 다른 사용자 폴더 → die"
  [ -f "$REPO/.claude/worktrees/AUDIT-RT-case0123/mine.txt" ] && ok "그 폴더는 지워지지 않는다" || no "대소문자만 다른 폴더가 지워졌다"
  (cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/audit-rt-case0123" >/dev/null 2>&1); rc=$?
  assert_eq "$rc" "2" "remove 도 거부"
  [ -f "$REPO/.claude/worktrees/AUDIT-RT-case0123/mine.txt" ] && ok "remove 후에도 그대로" || no "remove 가 대소문자 다른 폴더를 지웠다"
else
  ok "대소문자를 구분하는 파일시스템 — 해당 없음"
fi
rm -rf "$REPO"

echo "[사본 자리: .claude/worktrees 가 리포 밖을 가리키면 만들지 않는다 (AC13)]"
mk_repo_checked; mk_outside_checked
mkdir -p "$REPO/.claude" && ln -s "$OUTSIDE" "$REPO/.claude/worktrees"
(cd "$REPO" && "$WT" create-sandbox "outsd0123456789" >/dev/null 2>"$OUTSIDE.err"); rc=$?
assert_eq "$rc" "2" "밖을 가리키는 .claude/worktrees → die"
[ -z "$(ls -A "$OUTSIDE")" ] && ok "밖에는 아무것도 만들지 않았다" || no "밖에 만들었다: $(ls -A "$OUTSIDE")"
assert_contains "$(cat "$OUTSIDE.err")" "리포 밖" "사유가 리포 밖임을 밝힌다"
rm -rf "$REPO" "$OUTSIDE.err"
mk_repo_checked
ln -s "$OUTSIDE" "$REPO/.claude"   # .claude 자체가 밖을 가리키는 링크
(cd "$REPO" && "$WT" create-sandbox "outsd0123456789" >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "밖을 가리키는 .claude → die"
[ -z "$(ls -A "$OUTSIDE")" ] && ok "밖에는 아무것도 없다" || no "밖에 만들었다"
rm -rf "$REPO" "$OUTSIDE"

echo "[옛 자리: 같은 세션 이름만 치운다 (AC15) · 부모가 밖으로 풀리면 지우지 않는다]"
mk_repo_checked
OLD="$REPO/.claude/plugin-audit/worktrees"
mkdir -p "$OLD/rt-oldsess1" "$OLD/rt-other123" && printf 'x\n' > "$OLD/rt-oldsess1/f" && printf 'y\n' > "$OLD/rt-other123/f"
(cd "$REPO" && "$WT" create-sandbox "oldsess1abcdefgh" >/dev/null 2>&1); rc=$?
[ "$rc" -eq 0 ] && [ ! -e "$OLD/rt-oldsess1" ] && ok "옛 자리의 같은 세션 이름을 치웠다" || no "옛 같은 이름 rc=$rc"
[ -f "$OLD/rt-other123/f" ] && ok "옛 자리의 다른 세션 사본은 그대로" || no "다른 세션의 옛 사본이 지워졌다"
(cd "$REPO" && "$WT" remove "$OLD/rt-other123" >/dev/null 2>&1) && [ ! -e "$OLD/rt-other123" ] \
  && ok "remove 는 옛 자리 경로도 받는다" || no "remove <옛 경로> 실패"
rm -rf "$REPO"
for linkpoint in plugin-audit worktrees; do
  mk_repo_checked; mk_outside_checked
  if [ "$linkpoint" = "plugin-audit" ]; then
    mkdir -p "$OUTSIDE/worktrees/rt-lnk00001" && printf 'v\n' > "$OUTSIDE/worktrees/rt-lnk00001/f"
    mkdir -p "$REPO/.claude" && ln -s "$OUTSIDE" "$REPO/.claude/plugin-audit"
  else
    mkdir -p "$OUTSIDE/rt-lnk00001" && printf 'v\n' > "$OUTSIDE/rt-lnk00001/f"
    mkdir -p "$REPO/.claude/plugin-audit" && ln -s "$OUTSIDE" "$REPO/.claude/plugin-audit/worktrees"
  fi
  (cd "$REPO" && "$WT" create-sandbox "lnk00001abcdefgh" >/dev/null 2>&1); rc=$?
  assert_eq "$rc" "2" "옛 자리 부모($linkpoint)가 링크 → die"
  [ -f "$(find "$OUTSIDE" -name f | head -1)" ] && ok "링크 너머($linkpoint)는 그대로" || no "링크 너머($linkpoint)가 지워졌다"
  rm -rf "$REPO" "$OUTSIDE"
done

echo "[test_copy_skips_audit_trees: 다른 세션 사본 · 옛 자리는 빼고 같은 폴더의 다른 worktree 는 복사 (AC14)]"
mk_repo_checked   # .claude 를 무시하지 않는 저장소
(cd "$REPO" && git worktree add -q --detach "$REPO/.claude/worktrees/audit-rt-zzzzzzzz" HEAD >/dev/null 2>&1)
(cd "$REPO" && git branch feat-x && git worktree add -q "$REPO/.claude/worktrees/feat-x" feat-x >/dev/null 2>&1)
printf 'fx\n' > "$REPO/.claude/worktrees/feat-x/note.txt"
mkdir -p "$REPO/.claude/plugin-audit/worktrees/rt-yyyyyyyy" && printf 'old\n' > "$REPO/.claude/plugin-audit/worktrees/rt-yyyyyyyy/f.txt"
OUT=$(cd "$REPO" && "$WT" create-sandbox "copy01234567" 2>/dev/null); rc=$?
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
[ "$rc" -eq 0 ] && [ -d "$SANDBOX" ] || no "create-sandbox 실패 rc=$rc"
[ ! -e "$SANDBOX/.claude/worktrees/audit-rt-zzzzzzzz" ] && ok "다른 세션의 audit-rt-* 는 사본 안에 없다" || no "다른 세션 사본이 복사됐다"
[ ! -e "$SANDBOX/.claude/plugin-audit/worktrees" ] && ok "옛 .claude/plugin-audit/worktrees/* 는 사본 안에 없다" || no "옛 자리가 복사됐다"
[ -f "$SANDBOX/.claude/worktrees/feat-x/note.txt" ] && ok "같은 폴더의 feat-x 는 지금처럼 복사된다" || no "feat-x 가 새로 빠졌다"
[ -d "$REPO/.claude/worktrees/audit-rt-zzzzzzzz" ] && ok "다른 세션 사본은 원래 자리에 그대로" || no "다른 세션 사본이 지워졌다"
rm -rf "$REPO"

echo "[remove: namespace guard]"
REPO=$(mk_repo)
OUT=$(cd "$REPO" && "$WT" create-sandbox "remove012345678" 2>/dev/null)
SANDBOX=$(printf '%s\n' "$OUT" | sed -n '1p')
mkdir -p "$REPO/outside-ns" && : > "$REPO/outside-ns/keep"
(cd "$REPO" && "$WT" remove "$REPO/outside-ns" 2>/dev/null) \
  && no "remove 가 네임스페이스 밖 대상에 rc 0" || ok "remove 는 네임스페이스 밖을 거부한다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/../../../outside-ns" 2>/dev/null) \
  && no "remove 가 .. 우회 경로에 rc 0" || ok "remove 는 .. 로 네임스페이스를 벗어난 경로도 거부한다"
[ -f "$REPO/outside-ns/keep" ] && ok "거부된 대상이 그대로다" || no "거부된 대상이 사라졌다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/audit-rt-nosuch12") \
  && ok "없는 대상의 remove 는 성공한다 (멱등)" || no "없는 대상에서 실패했다"
[ -d "$SANDBOX" ] || no "remove 양의 짝의 전제 — 샌드박스가 없다: '$SANDBOX'"
(cd "$REPO" && "$WT" remove "$SANDBOX") && [ ! -d "$SANDBOX" ] \
  && ok "remove 는 네임스페이스 안의 샌드박스를 지운다 (양의 짝)" || no "샌드박스가 남았다"
rm -rf "$REPO"
finish
