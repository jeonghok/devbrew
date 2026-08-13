#!/usr/bin/env bash
# test_qg_publish_command.sh — command frontmatter: dispatches the skill, holds no gh.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg-publish.md"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

AT="$(awk '/^allowed-tools:/{print; exit}' "$CMD")"
grep -q 'Skill' <<<"$AT" && pass "command allows Skill dispatch" || fail "no Skill in allowed-tools"
if ! grep -qiE 'gh |gh\(|gh pr|gh api' <<<"$AT"; then pass "command holds no gh"; else fail "gh leaked into command"; fi
grep -qiE 'publishing-pr-understanding' "$CMD" && pass "invokes publish skill" || fail "does not invoke publish skill"
grep -qiE 'dry-run' "$CMD" && pass "documents --dry-run" || fail "no --dry-run mention"
echo "qg-publish-command: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
