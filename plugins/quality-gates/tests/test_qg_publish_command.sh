#!/usr/bin/env bash
# test_qg_publish_command.sh — command frontmatter: dispatches the skill, holds no gh.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
CMD="$PLUGIN_ROOT/commands/qg-publish.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
test -f "$CMD" || { echo "FAIL: command missing at $CMD"; exit 1; }

AT="$(awk '/^allowed-tools:/{print; exit}' "$CMD")"
grep -q 'Skill' <<<"$AT" && ok "command allows Skill dispatch" || no "no Skill in allowed-tools"
if ! grep -qiE 'gh |gh\(|gh pr|gh api' <<<"$AT"; then ok "command holds no gh"; else no "gh leaked into command"; fi
grep -qiE 'publishing-pr-understanding' "$CMD" && ok "invokes publish skill" || no "does not invoke publish skill"
grep -qiE 'dry-run' "$CMD" && ok "documents --dry-run" || no "no --dry-run mention"
finish
