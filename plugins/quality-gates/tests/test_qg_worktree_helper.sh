#!/usr/bin/env bash
# Unit tests for qg-worktree.sh — the subcommand surface and `remove`.
# (create-baseline · create-head 의 동작은 test_runtime_contract_invariance.sh 가 잰다.)
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

new_repo() {   # 커밋 하나짜리 일회용 리포 — 경로를 낸다
  local r; r=$(mktemp -d)
  [ -n "$r" ] && [ -d "$r" ] || { echo "mktemp 실패" >&2; exit 1; }
  (cd "$r" && git init -q -b main && git config user.email t@t && \
    git config user.name t && git commit -q --allow-empty -m init && \
    { [ "${1:-}" = ignore ] && printf '.claude/\n' > .gitignore && git add .gitignore && git commit -q -m ign; true; })
  printf '%s' "$r"
}

mk_repo() {   # 부모 셸에서 검사한다 — $(new_repo) 안의 exit 는 서브셸만 끝낸다
  REPO=$(new_repo "$@")
  [ -n "$REPO" ] && [ -d "$REPO" ] || { echo "임시 리포를 만들지 못했다" >&2; exit 1; }
}

# --- surface: branch 모드와 샌드박스 하위명령은 없다 (v10) ---
echo "[surface]"
mk_repo
for sub in sanitize validate-branch create create-sandbox mutation-guard; do
  err=$(cd "$REPO" && "$WT" "$sub" x y 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q "unknown subcommand: $sub"; then
    ok "'$sub' 는 unknown subcommand 로 거부된다"
  else
    no "'$sub' 가 아직 동작한다 (rc=$rc err=$err)"
  fi
done
# 양의 짝 — 남는 하위명령은 그대로 동작한다
base_sha=$(cd "$REPO" && git rev-parse HEAD)
WTPATH=$(cd "$REPO" && "$WT" create-baseline "$base_sha" "surface1234567" 2>/dev/null)
[ -d "$WTPATH" ] && ok "create-baseline 은 그대로 동작한다" || no "create-baseline 이 깨졌다: '$WTPATH'"
rm -rf "$REPO"

# --- remove ---
echo "[remove]"
mk_repo
base_sha=$(cd "$REPO" && git rev-parse HEAD)
WTPATH=$(cd "$REPO" && "$WT" create-baseline "$base_sha" "remove-test12345" 2>/dev/null)
[ -d "$WTPATH" ] || { no "create-baseline precondition"; }

(cd "$REPO" && "$WT" remove "$WTPATH") \
  && [ ! -d "$WTPATH" ] && ok "remove deletes dir" \
  || no "remove failed or dir remains"

# Remove a nonexistent path → exit 0 (best-effort)
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-base-missing1") \
  && ok "remove missing is noop" || no "remove missing errored"

# Refuse outside-namespace paths (safety)
(cd "$REPO" && "$WT" remove "/tmp" 2>/dev/null) \
  && no "removed outside namespace" || ok "outside namespace refused"

rm -rf "$REPO"

# --- 새 자리 · 자기 것만 지운다 (AC11 · AC12 · AC13 · AC15) ---
head_rel() { printf '.claude/worktrees/qg-%s-%s' "$1" "${2:0:8}"; }

echo "[new_location]"
for mode in plain ignore; do
  mk_repo "$mode"; TOP=$(cd "$REPO" && pwd -P); sha=$(cd "$REPO" && git rev-parse HEAD)
  b=$(cd "$REPO" && "$WT" create-baseline "$sha" "newloc1234567" 2>/dev/null)
  (cd "$REPO" && git commit -q --allow-empty -m second); sha2=$(cd "$REPO" && git rev-parse HEAD)
  printf 'mode: range\nstatus: ok\nstart: %s\nend: %s\n' "$sha" "$sha2" > "$REPO/range.txt"
  h=$(cd "$REPO" && "$WT" create-head "$sha2" "newloc1234567" --range "$REPO/range.txt" 2>/dev/null)
  assert_eq "$h" "$TOP/.claude/worktrees/qg-head-newloc12" "[$mode] head 경로가 새 자리다"
  assert_eq "$b" "$TOP/.claude/worktrees/qg-base-newloc12" "[$mode] baseline 경로가 새 자리다"
  [ ! -e "$REPO/.claude/quality-gates/worktrees" ] && ok "[$mode] 옛 자리는 생기지 않는다" || no "[$mode] 옛 자리가 생겼다"
  # linked worktree 안에서 부르면 그 worktree 꼭대기 아래다
  (cd "$REPO" && git worktree add -q --detach "$REPO/lnk" "$sha")
  LTOP=$(cd "$REPO/lnk" && pwd -P)
  lb=$(cd "$REPO/lnk" && "$WT" create-baseline "$sha" "newloc1234567" 2>/dev/null)
  assert_eq "$lb" "$LTOP/.claude/worktrees/qg-base-newloc12" "[$mode] linked worktree 안이면 그 꼭대기 아래다"
  rm -rf "$REPO"
done

echo "[keep_others]"
for mode in plain ignore; do
  mk_repo "$mode"; TOP=$(cd "$REPO" && pwd -P); sha=$(cd "$REPO" && git rev-parse HEAD)
  mkdir -p "$REPO/.claude/worktrees"
  (cd "$REPO" && git worktree add -q -b feat-x "$REPO/.claude/worktrees/feat-x" "$sha" && \
    git worktree add -q --detach "$REPO/.claude/worktrees/other" "$sha")
  echo mine > "$REPO/.claude/worktrees/feat-x/untracked.txt"
  b=$(cd "$REPO" && "$WT" create-baseline "$sha" "keepoth1234567" 2>/dev/null)
  b2=$(cd "$REPO" && "$WT" create-baseline "$sha" "keepoth1234567" 2>/dev/null)
  [ -d "$b" ] && [ "$b" = "$b2" ] && ok "[$mode] 양성 대조: 자기 사본은 (다시) 생긴다" || no "[$mode] 자기 사본이 안 생겼다 ($b / $b2)"
  (cd "$REPO" && "$WT" remove "$b")
  [ ! -e "$b" ] && ok "[$mode] 양성 대조: 자기 사본은 지워진다" || no "[$mode] 자기 사본이 남았다"
  [ -f "$REPO/.claude/worktrees/feat-x/untracked.txt" ] && ok "[$mode] 브랜치를 쥔 남의 worktree 가 그대로다" || no "[$mode] feat-x 를 건드렸다"
  [ -d "$REPO/.claude/worktrees/other" ] && ok "[$mode] 이름이 다른 detached worktree 가 그대로다" || no "[$mode] other 를 지웠다"
  rm -rf "$REPO"
done

echo "[branch_holding_same_name_stops]"
mk_repo; TOP=$(cd "$REPO" && pwd -P); sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q -b mine "$REPO/.claude/worktrees/qg-base-brhold12" "$sha")
echo keep > "$REPO/.claude/worktrees/qg-base-brhold12/f"
(cd "$REPO" && "$WT" create-baseline "$sha" "brhold12" >/dev/null 2>&1); assert_eq "$?" "2" "브랜치를 쥔 같은 이름이면 만들기 rc 2"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-base-brhold12" >/dev/null 2>&1); assert_eq "$?" "2" "브랜치를 쥔 같은 이름이면 remove rc 2"
[ -f "$REPO/.claude/worktrees/qg-base-brhold12/f" ] && ok "그 worktree 가 그대로다" || no "브랜치를 쥔 worktree 를 지웠다"
rm -rf "$REPO"

# 목록을 읽지 못하는 git — `worktree list` 만 실패하고 나머지는 진짜 git 으로 넘긴다.
mk_list_fail_git() {   # → 그 git 이 든 폴더 경로
  local d real; d=$(mktemp -d); real=$(command -v git)
  [ -n "$d" ] && [ -d "$d" ] && [ -n "$real" ] || { echo "가짜 git 을 만들지 못했다" >&2; exit 1; }
  printf '#!/bin/sh\nif [ "$1" = worktree ] && [ "$2" = list ]; then echo "fatal: 가짜 — 목록을 읽지 못함" >&2; exit 128; fi\nexec "%s" "$@"\n' "$real" > "$d/git"
  chmod +x "$d/git"
  printf '%s' "$d"
}
echo "[worktree_list_unreadable_stops]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q -b mine2 "$REPO/.claude/worktrees/qg-base-wtlist12" "$sha")
echo keep > "$REPO/.claude/worktrees/qg-base-wtlist12/f"
SHIM_DIR=$(mk_list_fail_git)
err=$(cd "$REPO" && PATH="$SHIM_DIR:$PATH" "$WT" remove "$REPO/.claude/worktrees/qg-base-wtlist12" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "등록된 worktree 목록을 읽지 못하면 remove 는 지우지 않고 rc 2"
assert_contains "$err" "등록된 worktree 목록을 읽지 못했다" "remove 가 목록을 읽지 못한 사유를 알린다"
err=$(cd "$REPO" && PATH="$SHIM_DIR:$PATH" "$WT" create-baseline "$sha" "wtlist12" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "등록된 worktree 목록을 읽지 못하면 만들기도 앞 사본을 지우지 않고 rc 2"
assert_contains "$err" "등록된 worktree 목록을 읽지 못했다" "만들기가 목록을 읽지 못한 사유를 알린다"
[ -f "$REPO/.claude/worktrees/qg-base-wtlist12/f" ] && ok "목록을 읽지 못했을 때 그 worktree 가 그대로다" || no "목록을 읽지 못했는데 worktree 를 지웠다"
rm -rf "$REPO" "$SHIM_DIR"

echo "[recover_same_name]"
mk_repo; TOP=$(cd "$REPO" && pwd -P); sha=$(cd "$REPO" && git rev-parse HEAD)
OUT=$(mktemp -d); [ -n "$OUT" ] && [ -d "$OUT" ] || exit 1
echo precious > "$OUT/p.txt"
mkdir -p "$REPO/.claude/worktrees"
ln -s "$OUT" "$REPO/.claude/worktrees/qg-base-recov123"
w=$(cd "$REPO" && "$WT" create-baseline "$sha" "recov123" 2>/dev/null)
[ -f "$OUT/p.txt" ] && ok "링크만 지우고 밖의 폴더는 그대로다" || no "링크 대상 안을 지웠다"
[ -d "$w" ] && [ ! -L "$w" ] && ok "새 사본이 생겼다" || no "링크 자리에 새 사본이 없다"
(cd "$REPO" && "$WT" remove "$w")
ln -s "$OUT" "$REPO/.claude/worktrees/qg-head-recov123"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-head-recov123"); assert_eq "$?" "0" "remove 는 링크를 받아 링크만 지운다"
[ ! -L "$REPO/.claude/worktrees/qg-head-recov123" ] && [ -f "$OUT/p.txt" ] && ok "remove 뒤 링크만 사라지고 대상은 산다" || no "remove 가 링크 대상을 건드렸다"
# 등록이 풀린 같은 이름 폴더
mkdir -p "$REPO/.claude/worktrees/qg-base-recov123"; echo junk > "$REPO/.claude/worktrees/qg-base-recov123/junk"
w=$(cd "$REPO" && "$WT" create-baseline "$sha" "recov123" 2>/dev/null)
[ -d "$w" ] && [ ! -e "$w/junk" ] && ok "등록 풀린 같은 이름 폴더는 지우고 다시 만든다" || no "등록 풀린 폴더 복구 실패"
# 브랜치를 쥐지 않은 같은 이름 worktree
echo junk > "$w/junk2"
w2=$(cd "$REPO" && "$WT" create-baseline "$sha" "recov123" 2>/dev/null)
[ -d "$w2" ] && [ ! -e "$w2/junk2" ] && ok "브랜치 없는 같은 이름 worktree 는 지우고 다시 만든다" || no "detached 같은 이름 복구 실패"
rm -rf "$REPO" "$OUT"

echo "[link_to_registered_user_worktree]"
for kind in branch detached; do
  mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
  mkdir -p "$REPO/.claude/worktrees"
  if [ "$kind" = branch ]; then
    (cd "$REPO" && git worktree add -q -b userbr "$REPO/.claude/worktrees/userwt" "$sha")
  else
    (cd "$REPO" && git worktree add -q --detach "$REPO/.claude/worktrees/userwt" "$sha")
  fi
  echo mine > "$REPO/.claude/worktrees/userwt/mine.txt"
  ln -s "$REPO/.claude/worktrees/userwt" "$REPO/.claude/worktrees/qg-base-ulnk0123"
  w=$(cd "$REPO" && "$WT" create-baseline "$sha" "ulnk0123" 2>/dev/null); rc=$?
  [ "$rc" -eq 0 ] && [ -d "$w" ] && [ ! -L "$w" ] && ok "[$kind] 링크 자리에 새 사본이 생겼다" || no "[$kind] 링크 자리 rc=$rc"
  [ -f "$REPO/.claude/worktrees/userwt/mine.txt" ] && ok "[$kind] 만들기 뒤 사용자 worktree 파일이 그대로다" || no "[$kind] 만들기가 링크 대상 worktree 를 지웠다"
  (cd "$REPO" && git worktree list --porcelain | grep -q "^worktree .*/userwt$") && ok "[$kind] 사용자 worktree 등록이 그대로다" || no "[$kind] 사용자 worktree 등록이 풀렸다"
  [ "$kind" != branch ] || { (cd "$REPO" && git rev-parse --verify -q userbr >/dev/null) && ok "[branch] 브랜치가 그대로다" || no "[branch] 브랜치가 사라졌다"; }
  ln -s "$REPO/.claude/worktrees/userwt" "$REPO/.claude/worktrees/qg-head-ulnk0123"
  (cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-head-ulnk0123" >/dev/null 2>&1); assert_eq "$?" "0" "[$kind] remove 는 링크를 받는다"
  [ ! -L "$REPO/.claude/worktrees/qg-head-ulnk0123" ] && ok "[$kind] remove 가 링크를 지웠다" || no "[$kind] 링크가 남았다"
  [ -f "$REPO/.claude/worktrees/userwt/mine.txt" ] && ok "[$kind] remove 뒤 사용자 worktree 파일이 그대로다" || no "[$kind] remove 가 링크 대상 worktree 를 지웠다"
  (cd "$REPO" && git worktree list --porcelain | grep -q "^worktree .*/userwt$") && ok "[$kind] remove 뒤 등록이 그대로다" || no "[$kind] remove 뒤 등록이 풀렸다"
  [ "$kind" != branch ] || { (cd "$REPO" && git rev-parse --verify -q userbr >/dev/null) && ok "[branch] remove 뒤 브랜치가 그대로다" || no "[branch] remove 뒤 브랜치가 사라졌다"; }
  rm -rf "$REPO"
done

echo "[escape_refused]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
OUT=$(mktemp -d); [ -n "$OUT" ] && [ -d "$OUT" ] || exit 1
mkdir -p "$REPO/.claude"; ln -s "$OUT" "$REPO/.claude/worktrees"
(cd "$REPO" && "$WT" create-baseline "$sha" "escape12" >/dev/null 2>&1); assert_eq "$?" "2" ".claude/worktrees 가 밖을 가리키면 rc 2"
[ -z "$(ls -A "$OUT")" ] && ok "밖에 아무것도 만들지 않았다" || no "밖에 만들었다"
rm -rf "$REPO" "$OUT"

echo "[old_location_not_handled]"
mk_repo; TOP=$(cd "$REPO" && pwd -P); sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/quality-gates/worktrees"
(cd "$REPO" && git worktree add -q --detach "$REPO/.claude/quality-gates/worktrees/base-oldloc12" "$sha" && \
  git worktree add -q --detach "$REPO/.claude/quality-gates/worktrees/base-zzzzzzzz" "$sha")
w=$(cd "$REPO" && "$WT" create-baseline "$sha" "oldloc1234" 2>/dev/null)
[ -d "$w" ] && ok "새 사본이 생겼다" || no "새 사본이 없다"
[ -d "$REPO/.claude/quality-gates/worktrees/base-oldloc12" ] && ok "만들기가 옛 자리의 같은 세션 사본을 지우지 않는다" || no "만들기가 옛 자리 사본을 지웠다"
[ -d "$REPO/.claude/quality-gates/worktrees/base-zzzzzzzz" ] && ok "옛 자리의 다른 세션 사본은 그대로다" || no "다른 세션의 옛 사본을 지웠다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/quality-gates/worktrees/base-zzzzzzzz" >/dev/null 2>&1); assert_eq "$?" "2" "remove <옛 자리 경로> 는 거부한다"
[ -d "$REPO/.claude/quality-gates/worktrees/base-zzzzzzzz" ] && ok "remove 가 거부한 옛 자리 사본은 그대로다" || no "거부했는데 옛 자리 사본이 사라졌다"
rm -rf "$REPO"

echo "[remove_scope]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q --detach "$REPO/.claude/worktrees/feat-x" "$sha")
for t in "$REPO/.claude/worktrees/feat-x" "$REPO/.claude/worktrees" "$REPO/.claude/worktrees/qg-base-x/.." \
         "$REPO/.claude/worktrees/qg-base-toolong12" "$REPO/.claude/worktrees/qg-other-abc" "$REPO/.claude/quality-gates/worktrees/feat-x" \
         "$REPO/.claude/worktrees/qg-base-" "$REPO/../qg-base-abc"; do
  (cd "$REPO" && "$WT" remove "$t" >/dev/null 2>&1); assert_eq "$?" "2" "범위 밖은 rc 2: ${t#$REPO}"
done
[ -d "$REPO/.claude/worktrees/feat-x" ] && ok "feat-x 가 그대로다" || no "feat-x 를 지웠다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-base-missing1"); assert_eq "$?" "0" "없는 자기 이름은 rc 0"
rm -rf "$REPO"

echo "[own_paths]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q --detach "$REPO/.claude/worktrees/qg-head-ownp1234" "$sha")
out=$(cd "$REPO" && "$WT" own-paths "ownp12345678"); assert_eq "$?" "0" "own-paths rc 0"
assert_eq "$out" ".claude/worktrees/qg-head-ownp1234" "등록된 사본 하나만 낸다"
(cd "$REPO" && "$WT" create-baseline "$sha" "ownp12345678" >/dev/null 2>&1)
out=$(cd "$REPO" && "$WT" own-paths "ownp12345678")
assert_eq "$out" ".claude/worktrees/qg-base-ownp1234
.claude/worktrees/qg-head-ownp1234" "사본 둘이면 두 줄"
mkdir -p "$REPO/.claude/worktrees/qg-base-unregis1"
out=$(cd "$REPO" && "$WT" own-paths "unregis1"); assert_eq "$out" "" "등록 안 된 폴더는 내지 않는다"
(cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-base-ownp1234" && "$WT" remove "$REPO/.claude/worktrees/qg-head-ownp1234")
out=$(cd "$REPO" && "$WT" own-paths "ownp12345678"); assert_eq "$out" "" "지운 뒤 빈 출력"
(cd "$REPO" && "$WT" own-paths "a b" >/dev/null 2>&1); assert_eq "$?" "2" "나쁜 session id 는 rc 2"
(cd "$REPO" && "$WT" own-paths "" >/dev/null 2>&1); assert_eq "$?" "2" "빈 session id 는 rc 2"
(cd "$REPO" && "$WT" own-paths >/dev/null 2>&1); assert_eq "$?" "2" "인자 없으면 rc 2"
rm -rf "$REPO"

echo "[case_variant_branch_holder]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q -b userbr "$REPO/.claude/worktrees/QG-Base-casev123" "$sha")
echo keep > "$REPO/.claude/worktrees/QG-Base-casev123/f"
if [ -d "$REPO/.claude/worktrees/qg-base-casev123" ]; then
  (cd "$REPO" && "$WT" remove "$REPO/.claude/worktrees/qg-base-casev123" >/dev/null 2>&1); assert_eq "$?" "2" "대소문자만 다른 브랜치 worktree 는 remove rc 2"
  (cd "$REPO" && "$WT" create-baseline "$sha" "casev123" >/dev/null 2>&1); assert_eq "$?" "2" "대소문자만 다른 브랜치 worktree 는 만들기 rc 2"
  [ -f "$REPO/.claude/worktrees/QG-Base-casev123/f" ] && ok "그 worktree 가 그대로다" || no "대소문자만 다른 사용자 worktree 를 지웠다"
else
  echo "  SKIP: 대소문자를 구분하는 파일시스템이라 이 모양을 만들 수 없다 (case_variant_branch_holder 를 재지 못함)"
fi
rm -rf "$REPO"

echo "[own_paths_branch_holder]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q -b userbr2 "$REPO/.claude/worktrees/qg-base-ownbr123" "$sha")
out=$(cd "$REPO" && "$WT" own-paths "ownbr123"); assert_eq "$out" "" "브랜치를 쥔 같은 이름은 자기 사본으로 내지 않는다"
rm -rf "$REPO"
echo "[own_paths_case_variant_and_alias]"
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q --detach "$REPO/.claude/worktrees/QG-Base-ownc1234" "$sha")
if [ -d "$REPO/.claude/worktrees/qg-base-ownc1234" ]; then
  out=$(cd "$REPO" && "$WT" own-paths "ownc1234"); assert_eq "$out" "" "대소문자만 다른 detached 사용자 worktree 는 own-paths 에 없다"
else
  echo "  SKIP: 대소문자를 구분하는 파일시스템이라 이 모양을 만들 수 없다 (own_paths_case_variant 를 재지 못함)"
fi
rm -rf "$REPO"
# 별칭 경로(링크 낀 경로)로 등록한 정확한 이름의 사본은 자기 것으로 센다
mk_repo; sha=$(cd "$REPO" && git rev-parse HEAD)
ALIAS_DIR=$(mktemp -d); [ -n "$ALIAS_DIR" ] && [ -d "$ALIAS_DIR" ] || exit 1
ln -s "$REPO" "$ALIAS_DIR/alias"
mkdir -p "$REPO/.claude/worktrees"
(cd "$REPO" && git worktree add -q --detach "$ALIAS_DIR/alias/.claude/worktrees/qg-head-alias123" "$sha")
out=$(cd "$REPO" && "$WT" own-paths "alias123"); assert_eq "$out" ".claude/worktrees/qg-head-alias123" "별칭 경로로 등록한 정확한 이름의 사본도 낸다"
rm -rf "$REPO" "$ALIAS_DIR"

finish
