#!/usr/bin/env bash
# Tests for scripts/state_path.py — state_root() helper.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/scripts/state_path.py"
WORK=$(mktemp -d -t specdistill-statepath-XXXXXX) || exit 1
# Resolve symlinks (macOS /var/folders → /private/var/folders) so that
# expected paths match Python's Path.resolve() output.
WORK=$(cd "$WORK" && pwd -P) || exit 1
trap 'rm -rf "$WORK"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Setup: a git repo with a worktree
cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo "x" > a.txt; git add a.txt; git commit -qm "init"
git worktree add -q ../wt-foo 2>/dev/null || git worktree add -q ../wt-foo HEAD

# Case 1: AC11 — called from worktree returns main repo root
got=$(cd "$WORK/wt-foo" && python3 "$HELPER" state-root)
want="$WORK/main-repo/.claude/spec-distill"
[[ "$got" == "$want" ]] \
  && ok "state-root from worktree → main repo .claude/spec-distill" \
  || no "got='$got' want='$want'"

# Case 2: AC11 — called from main repo returns main repo root
got=$(cd "$WORK/main-repo" && python3 "$HELPER" state-root)
want="$WORK/main-repo/.claude/spec-distill"
[[ "$got" == "$want" ]] \
  && ok "state-root from main repo → main repo .claude/spec-distill" \
  || no "got='$got' want='$want'"

# Case 3: AC13 — non-git directory → cwd fallback + loud stderr
mkdir -p "$WORK/non-git"
out=$(cd "$WORK/non-git" && python3 "$HELPER" state-root 2>&1 >/dev/null)
got=$(cd "$WORK/non-git" && python3 "$HELPER" state-root 2>/dev/null)
[[ "$got" == "$WORK/non-git/.claude/spec-distill" ]] \
  && echo "$out" | grep -q "state root fallback: cwd" \
  && ok "non-git → cwd fallback + loud stderr" \
  || no "got='$got' stderr='$out'"

# ── interview-state (R7 §1-2 · AC1) ─────────────────────────────────────────
IV="$WORK/iv-repo"; mkdir -p "$IV" && git -C "$IV" init -q
mkdir -p "$IV/docs/superpowers/interview"
got=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$got" "$IV/docs/superpowers/interview/2026-10-15-t-interview.state.md" "AC1: interview-state 가 작업 트리 루트 아래 상태 경로를 낸다"
assert_eq "$rc" "0" "AC1: rc 0"
for bad in T t_x 한글 "t x" "-t" "t-" ""; do
  python3 "$HELPER" interview-state --topic "$bad" --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "2" "AC1: kebab 아닌 topic '${bad}' 은 exit 2"
done
python3 "$HELPER" interview-state --topic t --date 2026-1-5 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC1: 날짜 꼴이 아니면 exit 2"
# 같은 날 seed · seed audit 와의 겹침 — 세 자리 각각
put_type() { printf -- '---\ntype: %s\n---\nbody\n' "$2" > "$1"; }
D="$IV/docs/superpowers/interview"
put_type "$D/2026-10-15-t-interview.md" interview-seed
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "AC1: brief 자리에 seed 가 있으면 exit 2"
assert_contains "$out" "type: interview-seed" "AC1: 거부 사유가 그 파일의 type 을 댄다"
got=$(python3 "$HELPER" interview-state --topic t-brief --date 2026-10-15 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$got" "$D/2026-10-15-t-brief-interview.state.md" "AC1: --topic t-brief 는 seed 와 겹치지 않는 경로를 낸다"
rm -f "$D/2026-10-15-t-interview.md"
put_type "$D/2026-10-15-t-interview.audit.md" interview-seed-audit
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC1: audit 자리에 seed audit 가 있으면 exit 2"
rm -f "$D/2026-10-15-t-interview.audit.md"
printf 'no frontmatter\n' > "$D/2026-10-15-t-interview.state.md"
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC1: 상태 자리에 type 없는 파일이 있으면 exit 2"
# AC27 — 같은 날 같은 주제의 끝난 인터뷰(brief 자리에 interview-brief) → <주제>-<HHMM> 자리 + 알림, 끝난 파일은 그대로
put_type "$D/2026-10-15-t-interview.state.md" interview-state
put_type "$D/2026-10-15-t-interview.md" interview-brief
put_type "$D/2026-10-15-t-interview.audit.md" interview-audit
sum_before="$(cat "$D"/2026-10-15-t-interview* | cksum)"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>"$WORK/err"); rc=$?
assert_eq "$rc:$out" "0:$D/2026-10-15-t-0930-interview.state.md" "AC27: 끝난 인터뷰 자리면 <주제>-<HHMM> 자리를 낸다"
assert_contains "$(cat "$WORK/err")" "같은 날 같은 주제의 인터뷰가 이미 끝났다" "AC27: 그 사실을 한 줄 알린다"
assert_eq "$(cat "$D"/2026-10-15-t-interview* | cksum)" "$sum_before" "AC27: 끝난 인터뷰의 파일은 바뀌지 않는다"
# 양의 짝 — 끝나지 않은 상태 파일만 있으면 같은 자리(이어 가기 판단은 진입 단계 몫)
rm -f "$D/2026-10-15-t-interview.md" "$D/2026-10-15-t-interview.audit.md"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$rc:$out" "0:$D/2026-10-15-t-interview.state.md" "AC27 양의 짝: 끝나지 않은 상태 파일이면 같은 자리"
# 같은 분에 또 끝난 인터뷰 → 멈춘다
put_type "$D/2026-10-15-t-interview.md" interview-brief
put_type "$D/2026-10-15-t-0930-interview.md" interview-brief
err=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "AC27: 새 자리도 끝난 인터뷰면 exit 2"
assert_contains "$err" "에도 끝난 인터뷰가 있다" "AC27: 새 자리가 끝난 인터뷰면 그 사유를 낸다"
for tm in 2360 2400 930 09a0; do
  err=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time "$tm" --cwd "$IV" 2>&1 >/dev/null); rc=$?
  assert_eq "$rc" "2" "AC27: --time '${tm}' 은 exit 2"
  assert_contains "$err" "HHMM 이 아니다" "AC27: --time '${tm}' 의 사유를 낸다"
done
rm -f "$D/2026-10-15-t-0930-interview.md"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 2359 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$rc:$out" "0:$D/2026-10-15-t-2359-interview.state.md" "AC27: --time 2359 는 통과한다(양성 대조)"
# 새 자리에 남의 파일(seed audit)이 있어도 멈춘다
put_type "$D/2026-10-15-t-0930-interview.audit.md" interview-seed-audit
err=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "AC27: 새 자리에 남의 파일이 있으면 exit 2"
assert_contains "$err" "다른 종류의 파일이 있다" "AC27: 새 자리의 남의 파일 사유를 낸다"
rm -f "$D/2026-10-15-t-0930-interview.audit.md"
# 새 자리가 작업 트리 밖으로 가는 링크이면(유효한 type 이어도) 멈춘다
put_type "$WORK/ac27-out.md" interview-state
ln -s "$WORK/ac27-out.md" "$D/2026-10-15-t-0930-interview.state.md"
err=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "AC27: 새 자리가 링크이면 exit 2"
assert_contains "$err" "링크를 거친다" "AC27: 새 자리 링크의 사유를 낸다"
rm -f "$D/2026-10-15-t-0930-interview.state.md"
rm -f "$D"/2026-10-15-t-*interview*
# git 이 아니면 --cwd 기준 + stderr 한 줄
NG="$WORK/iv-nogit"; mkdir -p "$NG"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$NG" 2>&1 >/dev/null)
got=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$NG" 2>/dev/null)
assert_eq "$got" "$NG/docs/superpowers/interview/2026-10-15-t-interview.state.md" "§1-2: git 이 아니면 --cwd 기준 경로"
assert_contains "$out" "git 저장소가 아니다" "§1-2: git 이 아니면 그 사실을 stderr 로 낸다"
# ── path-inside · 링크 거부 ───────────────────────────────────────────────
OUTD="$WORK/outside"; mkdir -p "$OUTD"
PI="$WORK/pi-repo"; mkdir -p "$PI/docs/real" && echo x > "$PI/docs/real/f.md"
python3 "$HELPER" path-inside --root "$PI" "$PI/docs/real/f.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "path-inside 양성 대조: 안쪽 일반 파일 rc 0"
ln -s "$OUTD" "$PI/docs/lnk"
out=$(python3 "$HELPER" path-inside --root "$PI" "$PI/docs/lnk/f.md" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "path-inside: 링크 성분은 rc 2"
assert_contains "$out" "링크를 거친다" "path-inside: 사유가 stderr 에 나온다"
python3 "$HELPER" path-inside --root "$PI" "$PI/docs/../../x" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "path-inside: .. 탈출은 rc 2"
python3 "$HELPER" path-inside --root "$PI" "$PI/docs/lnk/../x" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "path-inside: 링크 뒤 .. (한 단계)는 rc 2"
python3 "$HELPER" path-inside --root "$PI" "$PI/docs/lnk/../../x" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "path-inside: 링크 뒤 .. (두 단계)는 rc 2"
python3 "$HELPER" path-inside --root "$PI" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "path-inside: 경로 인자가 없으면 rc 2"
# 논리 cwd(링크로 들어온 자리 · $PWD)의 접두만 물리 경로로 읽는다 — git 이 내는 물리 루트와 맞춰 잰다.
# cwd 가 아닌 링크 접두는 풀지 않는다(그 링크가 레포 안에 심긴 것일 수 있다). 그 아래 링크는 그대로 거부.
LC="$WORK/pi-logical"; ln -s "$PI" "$LC"
rc=0; ( cd "$LC" && PWD="$LC" python3 "$HELPER" path-inside --root "$PI" "$LC/docs/real/f.md" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "0" "path-inside: 논리 cwd 접두의 경로는 물리 루트 안으로 읽힌다(양성 대조)"
rc=0; ( cd "$LC" && PWD="$LC" python3 "$HELPER" path-inside --root "$LC" "$PI/docs/real/f.md" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "0" "path-inside: 논리 cwd 표기의 루트도 물리로 읽힌다(양성 대조)"
rc=0; ( cd "$LC" && PWD="$LC" python3 "$HELPER" path-inside --root "$PI" "$LC/docs/lnk/f.md" >/dev/null 2>&1 ) || rc=$?
assert_eq "$rc" "2" "path-inside: 논리 cwd 접두라도 그 아래 링크 성분은 rc 2"
rc=0; python3 "$HELPER" path-inside --root "$PI" "$LC/docs/real/f.md" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "path-inside: cwd 가 아닌 링크 접두는 물리로 읽지 않는다(rc 2)"
# 다른 저장소의 루트를 가리키는 링크 — 그 링크로 도출한 루트에 대어도 안으로 읽지 않는다
OR="$WORK/other-root"; mkdir -p "$OR"; mkdir -p "$PI/docs/sp"; ln -s "$OR" "$PI/docs/sp/iv"
rc=0; python3 "$HELPER" path-inside --root "$OR" "$PI/docs/sp/iv/x.md" >/dev/null 2>&1 || rc=$?
assert_eq "$rc" "2" "path-inside: 다른 루트를 가리키는 레포 안 링크를 거친 경로는 그 루트 기준으로도 rc 2"
# ── payload-root · 쓰기 관문의 루트 ─────────────────────────────────────────
PRR="$WORK/pr-repo"; mkdir -p "$PRR/docs/real" "$WORK/pr-out" && git -C "$PRR" init -q
got=$(python3 "$HELPER" payload-root "$PRR/docs/real/x-interview.md" 2>/dev/null); rc=$?
assert_eq "$rc:$got" "0:$PRR" "payload-root: 저장소 안이면 git 최상위(양성 대조)"
ln -s "$WORK/pr-out" "$PRR/docs/iv"
out=$(python3 "$HELPER" payload-root "$PRR/docs/iv/x-interview.md" 2>&1 >/dev/null); rc=$?
assert_eq "$rc" "2" "payload-root: 인터뷰 폴더가 저장소 밖(git 아님) 폴더로 가는 링크면 rc 2"
assert_contains "$out" "링크를 거친다" "payload-root: 그 사유를 stderr 로 낸다"
ln -s "$WORK/pr-nowhere" "$PRR/docs/dg"
python3 "$HELPER" payload-root "$PRR/docs/dg/x-interview.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "payload-root: 인터뷰 폴더가 끊긴 링크면 rc 2"
PNG="$WORK/pr-nongit/sub"; mkdir -p "$PNG"
got=$(python3 "$HELPER" payload-root "$PNG/x-interview.md" 2>/dev/null); rc=$?
assert_eq "$rc:$got" "0:$PNG" "payload-root: 저장소가 아니면 payload 의 폴더(양성 대조)"
python3 "$HELPER" payload-root >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "payload-root: 인자가 없으면 rc 2"
LV="$WORK/iv-link"; mkdir -p "$LV/docs/superpowers" && git -C "$LV" init -q
ln -s "$OUTD" "$LV/docs/superpowers/interview"
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$LV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "interview-state: 링크된 interview 디렉토리는 rc 2"
finish
