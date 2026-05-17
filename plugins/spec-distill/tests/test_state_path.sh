#!/usr/bin/env bash
# Tests for hooks/state_path.py — state_root() helper.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/hooks/state_path.py"
WORK=$(mktemp -d -t specdistill-statepath-XXXXXX)
# Resolve symlinks (macOS /var/folders → /private/var/folders) so that
# expected paths match Python's Path.resolve() output.
WORK=$(cd "$WORK" && pwd -P)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

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
  && note PASS "state-root from worktree → main repo .claude/spec-distill" \
  || note FAIL "got='$got' want='$want'"

# Case 2: AC11 — called from main repo returns main repo root
got=$(cd "$WORK/main-repo" && python3 "$HELPER" state-root)
want="$WORK/main-repo/.claude/spec-distill"
[[ "$got" == "$want" ]] \
  && note PASS "state-root from main repo → main repo .claude/spec-distill" \
  || note FAIL "got='$got' want='$want'"

# Case 3: AC13 — non-git directory → cwd fallback + loud stderr
mkdir -p "$WORK/non-git"
out=$(cd "$WORK/non-git" && python3 "$HELPER" state-root 2>&1 >/dev/null)
got=$(cd "$WORK/non-git" && python3 "$HELPER" state-root 2>/dev/null)
[[ "$got" == "$WORK/non-git/.claude/spec-distill" ]] \
  && echo "$out" | grep -q "state root fallback: cwd" \
  && note PASS "non-git → cwd fallback + loud stderr" \
  || note FAIL "got='$got' stderr='$out'"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
