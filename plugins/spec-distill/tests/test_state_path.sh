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
# 양성 대조 — 세 자리에 제 종류가 있으면 통과
put_type "$D/2026-10-15-t-interview.state.md" interview-state
put_type "$D/2026-10-15-t-interview.md" interview-brief
put_type "$D/2026-10-15-t-interview.audit.md" interview-audit
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "0" "AC1 양성 대조: 세 자리가 제 종류면 rc 0"
# git 이 아니면 --cwd 기준 + stderr 한 줄
NG="$WORK/iv-nogit"; mkdir -p "$NG"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$NG" 2>&1 >/dev/null)
got=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --cwd "$NG" 2>/dev/null)
assert_eq "$got" "$NG/docs/superpowers/interview/2026-10-15-t-interview.state.md" "§1-2: git 이 아니면 --cwd 기준 경로"
assert_contains "$out" "git 저장소가 아니다" "§1-2: git 이 아니면 그 사실을 stderr 로 낸다"
finish
