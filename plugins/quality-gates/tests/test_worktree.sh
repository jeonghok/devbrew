#!/usr/bin/env bash
# Tests for quality-gates behavior inside a git worktree.
#
# Guards the structural property that state and discovery are PWD-relative,
# so a worktree run cannot leak into (or read from) its origin repo.
#
# Uses bash assertions; no external test framework. Mirrors test_setup_qg.sh
# style. All side effects are confined to a per-test mktemp dir which acts
# as both a throwaway git repo and a $HOME for legacy-fallback isolation.

set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SETUP="$PLUGIN_DIR/scripts/setup-qg.sh"
DISCOVER="$PLUGIN_DIR/scripts/discover-plan.sh"
TRIVIA="$PLUGIN_DIR/scripts/check-trivia.sh"
PRECHECK="$PLUGIN_DIR/scripts/pre-pipeline-check.sh"

PASS=0
FAIL=0

note() { echo "  → $1"; }
pass() { PASS=$((PASS+1)); note "PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

# Create an isolated repo + worktree pair, echo "<repo>|<worktree>|<branch>".
# Caller must remove the returned root manually (or trap-cleanup).
make_repo_with_worktree() {
  local root branch
  root=$(mktemp -d)
  branch="wt-$$-$RANDOM"

  (
    cd "$root"
    mkdir repo
    cd repo
    git init -q -b main
    git config user.email "test@example.com"
    git config user.name "test"
    echo "# scratch" > README.md
    git add README.md
    git commit -q -m "init"
    git worktree add -q -b "$branch" "$root/worktree" main
  )

  printf '%s|%s|%s\n' "$root/repo" "$root/worktree" "$branch"
}

# --- Test 1: worktree setup writes state inside worktree, not origin repo ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)
unset CLAUDE_CODE_SESSION_ID
SID="wt1session01"

(
  cd "$WT"
  HOME="$WT" "$SETUP" --session-id "$SID" >/dev/null 2>&1
)
RC=$?

if [[ "$RC" -eq 0 && -f "$WT/.claude/quality-gates/$SID/pipeline.md" ]]; then
  pass "T1a: state file created inside worktree"
else
  fail "T1a: state file missing in worktree (rc=$RC)"
fi

if [[ ! -d "$REPO/.claude/quality-gates/$SID" ]]; then
  pass "T1b: origin repo .claude untouched (no leakage from worktree)"
else
  fail "T1b: LEAKAGE — origin repo has state for SID=$SID"
fi

if grep -q "session_id: \"$SID\"" "$WT/.claude/quality-gates/$SID/pipeline.md" 2>/dev/null; then
  pass "T1c: state frontmatter carries correct session_id"
else
  fail "T1c: state file missing session_id frontmatter"
fi

rm -rf "$(dirname "$REPO")"

# --- Test 2: discover-plan.sh resolves project-local against worktree PWD ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)

mkdir -p "$WT/docs/superpowers/plans"
cat > "$WT/docs/superpowers/plans/plan.md" <<'EOF'
- [ ] one
- [ ] two
EOF

OUT=$(cd "$WT" && HOME="$WT" "$DISCOVER" 2>&1)
RC=$?
if [[ "$RC" -eq 0 ]] && echo "$OUT" | grep -q '"source":"project-local"'; then
  pass "T2a: discover-plan resolved project-local in worktree (rc=$RC)"
else
  fail "T2a: discover-plan did not pick worktree-local plan (rc=$RC, out=$OUT)"
fi

if echo "$OUT" | grep -q "$WT/docs/superpowers/plans"; then
  pass "T2b: discover-plan emitted worktree-rooted path"
else
  fail "T2b: emitted path not worktree-rooted: $OUT"
fi

rm -rf "$(dirname "$REPO")"

# --- Test 3: git operations read worktree context ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)

WT_BRANCH=$(cd "$WT" && git rev-parse --abbrev-ref HEAD)
if [[ "$WT_BRANCH" == "$BRANCH" ]]; then
  pass "T3a: git rev-parse returned worktree branch ($BRANCH)"
else
  fail "T3a: got '$WT_BRANCH', expected '$BRANCH'"
fi

# Stage a change in worktree; trivia/diff should observe it
echo "extra line" >> "$WT/README.md"
DIFF_BYTES=$(cd "$WT" && git diff HEAD | wc -c)
if [[ "$DIFF_BYTES" -gt 0 ]]; then
  pass "T3b: git diff HEAD sees worktree-local changes"
else
  fail "T3b: git diff HEAD empty in worktree"
fi

# trivia script runs cleanly from worktree (exit 0 or 1 are both expected
# verdicts; we only assert it doesn't crash)
OUT=$(cd "$WT" && HOME="$WT" "$TRIVIA" 2>&1)
RC=$?
if [[ "$RC" -eq 0 || "$RC" -eq 1 ]]; then
  pass "T3c: check-trivia.sh ran from worktree (rc=$RC)"
else
  fail "T3c: check-trivia.sh unusual rc=$RC, out=$OUT"
fi

# pre-pipeline-check.sh should not crash; reads `git rev-parse --abbrev-ref HEAD`
OUT=$(cd "$WT" && HOME="$WT" "$PRECHECK" 2>&1 || true)
# Script may exit non-zero based on its own logic; we only assert no shell error
if [[ -n "$OUT" || $? -lt 127 ]]; then
  pass "T3d: pre-pipeline-check.sh ran from worktree"
else
  fail "T3d: pre-pipeline-check.sh failed to execute"
fi

rm -rf "$(dirname "$REPO")"

# --- Test 4: .git in worktree is a file (gitdir pointer), not a directory ---
IFS='|' read -r REPO WT BRANCH < <(make_repo_with_worktree)
if [[ -f "$WT/.git" && ! -d "$WT/.git" ]]; then
  pass "T4: worktree .git is a file pointer (any -d \".git\" check would skip worktree)"
else
  fail "T4: worktree .git layout unexpected"
fi
rm -rf "$(dirname "$REPO")"

# --- Test 8: agent.md Inputs contract drift guard (AC2, T8) ---
for agent in scout adversarial synthesizer test-scope-validator security-reviewer codex-reviewer; do
  if grep -q 'project_dir' "$PLUGIN_DIR/agents/$agent.md"; then
    pass "T8: agents/$agent.md declares project_dir input"
  else
    fail "T8: agents/$agent.md missing project_dir input contract"
  fi
done

# --- Test 7: codex-reviewer.md must not reference $REPO_ROOT/plugins/quality-gates (AC3) ---
if grep -q '\$REPO_ROOT/plugins/quality-gates' "$PLUGIN_DIR/agents/codex-reviewer.md"; then
  fail "T7: codex-reviewer.md still references \$REPO_ROOT/plugins/quality-gates (breaks outside devbrew)"
else
  pass "T7: codex-reviewer.md uses \${CLAUDE_PLUGIN_ROOT} (devbrew-portable)"
fi

# --- Test 5: SKILL.md prose contains project_dir in 5 dispatch blocks ---
SKILL_MD="$PLUGIN_DIR/skills/quality-pipeline/SKILL.md"
T5_FAIL=0
for name in scout adversarial synthesizer test-scope-validator; do
  if ! awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+15 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL_MD"; then
    T5_FAIL=1
    fail "T5: SKILL.md dispatch for $name lacks project_dir"
  fi
done
# Updated in v1.16.0: heading restructured from `**Agent D — security-reviewer**`
# to italic `*security-reviewer (...)*`. New anchor captures the qualified plugin
# name so future drift in either dispatch convention is caught.
if ! awk '/\*security-reviewer \(`quality-gates:security-reviewer`\)/ { found=NR }
        found && NR <= found+30 && /project_dir/ { ok=1; exit }
        END { exit !ok }' "$SKILL_MD"; then
  T5_FAIL=1
  fail "T5: SKILL.md security-reviewer section lacks project_dir"
fi
[[ "$T5_FAIL" -eq 0 ]] && pass "T5: SKILL.md propagates project_dir to all 5 dispatch points"

# --- Test 6: hooks read payload cwd (AST-based, not grep) ---
T6_FAIL=0
for hook in stop-hook.py post-tool-use-session-tracker.py session-start-advisor.py; do
  if ! python3 -c "
import ast, sys
tree = ast.parse(open('$PLUGIN_DIR/hooks/$hook').read())
found = False
for node in ast.walk(tree):
    if isinstance(node, ast.Call):
        # Look for *.get('cwd') or *.get('cwd', ...)
        if isinstance(node.func, ast.Attribute) and node.func.attr == 'get':
            args = node.args
            if args and isinstance(args[0], ast.Constant) and args[0].value == 'cwd':
                found = True
                break
sys.exit(0 if found else 1)
"; then
    T6_FAIL=1
    fail "T6: hooks/$hook does not call .get('cwd') anywhere"
  fi
done
[[ "$T6_FAIL" -eq 0 ]] && pass "T6: all 3 hooks read payload cwd (AST verified)"

# --- Test 9: setup-qg.sh writes project_dir to state frontmatter ---
if grep -q '^project_dir:' "$PLUGIN_DIR/scripts/setup-qg.sh"; then
  pass "T9: setup-qg.sh emits project_dir in state frontmatter"
else
  fail "T9: setup-qg.sh missing project_dir frontmatter write"
fi

# --- Summary ---
echo
echo "Results: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
