#!/usr/bin/env bash
# AC1/AC11/AC12 for PostToolUse hook design-mode + worktree state path.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/spec-write-validator.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"
WORK=$(mktemp -d -t specdistill-design-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Build a main repo + worktree to exercise AC11
cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo seed > seed.txt; git add seed.txt; git commit -qm seed
mkdir -p docs/superpowers/specs
git worktree add -q ../wt-foo HEAD

# Helper: emit a hook payload + run hook from a given cwd
run_hook() {
  local cwd="$1" path="$2" extra_env="${3:-}"
  local payload
  payload=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s"}}' "$path")
  cd "$cwd" && env -i HOME="$HOME" PATH="$PATH" $extra_env bash -c \
    "echo '$payload' | python3 '$HOOK'" 2>&1
}

# Case 1: AC1 + AC11 — valid design.md write from worktree → state in MAIN repo only
DEST="$WORK/main-repo/docs/superpowers/specs/2026-05-17-test-design.md"
cp "$FIX/2026-05-17-test-design.md" "$DEST"
out=$(run_hook "$WORK/wt-foo" "$DEST" "DEVBREW_SPEC_DISTILL_SESSION_ID=case-001")
rc=$?
MAIN_STATE="$WORK/main-repo/.claude/spec-distill/case-001/state.local.md"
WT_STATE="$WORK/wt-foo/.claude/spec-distill/case-001/state.local.md"
[[ $rc -eq 0 ]] && [[ -f "$MAIN_STATE" ]] && [[ ! -f "$WT_STATE" ]] \
  && grep -q '^pending_review:' "$MAIN_STATE" \
  && grep -q 'mode: design' "$MAIN_STATE" \
  && ok "AC1+AC11: design.md write from worktree → state in main repo only" \
  || no "AC1+AC11 failed (rc=$rc, main_exists=$([[ -f $MAIN_STATE ]] && echo y || echo n), wt_exists=$([[ -f $WT_STATE ]] && echo y || echo n))"

# Case 2: AC12 — pending_review block contains worktree_path
grep -q "^  worktree_path:.*wt-foo" "$MAIN_STATE" \
  && ok "AC12: pending_review block contains worktree_path field" \
  || no "AC12: worktree_path field missing (state: $(cat $MAIN_STATE 2>/dev/null))"

# Case 3: regression — spec-mode (existing v0.3.0) still writes state in main repo too
DEST2="$WORK/main-repo/docs/superpowers/specs/2026-05-17-test-spec.md"
if [[ -f "$FIX/spec-valid.md" ]]; then
  cp "$FIX/spec-valid.md" "$DEST2"
  out=$(run_hook "$WORK/wt-foo" "$DEST2" "DEVBREW_SPEC_DISTILL_SESSION_ID=case-003")
  rc=$?
  MAIN_STATE2="$WORK/main-repo/.claude/spec-distill/case-003/state.local.md"
  [[ $rc -eq 0 ]] && [[ -f "$MAIN_STATE2" ]] \
    && grep -q 'mode: spec' "$MAIN_STATE2" \
    && ok "regression: spec-mode write also routes to main repo .claude" \
    || no "spec-mode regression failed (rc=$rc)"
else
  ok "regression skipped (spec-valid.md fixture absent)"
fi
finish
