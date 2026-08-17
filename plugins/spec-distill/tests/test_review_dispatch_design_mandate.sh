#!/usr/bin/env bash
# AC2 + AC12 for Stop hook review-dispatch.py — design-mode mandate body.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-mandate-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Build a main repo so state_path helper resolves to it
cd "$WORK"
git init -q main-repo
cd main-repo
git config user.email t@t.t; git config user.name t
echo s > s.txt; git add s.txt; git commit -qm s
SID=case-mandate
SDIR="$WORK/main-repo/.claude/spec-distill/$SID"
mkdir -p "$SDIR"
cat > "$SDIR/state.local.md" <<EOF
---
session_id: $SID
---

pending_review:
  path: /Users/foo/docs/superpowers/specs/2026-05-17-x-design.md
  mode: design
  worktree_path: /Users/foo/.claude/worktrees/test-wt
  triggered_at: 2026-05-17T00:00:00Z
EOF

out=$(cd "$WORK/main-repo" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" python3 "$HOOK" </dev/null 2>/dev/null)
rc=$?

# AC2 — Stop hook dual-target schema: long mandate in .reason, short trace in .systemMessage.
echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && ok "AC2: mandate (.reason) contains 'reviewing-spec' + 'terminal handoff' phrases" \
  || no "AC2 failed. out='$out'"

# AC12 — worktree_path carried forward in .reason body
echo "$out" | jq -e '.reason | contains("worktree_path: /Users/foo/.claude/worktrees/test-wt")' >/dev/null \
  && ok "AC12: mandate (.reason) carries worktree_path forward" \
  || no "AC12 failed. out='$out'"

# Mode signal — design mode mandate should carry mode marker in .reason
echo "$out" | jq -e '.reason | contains("mode: design")' >/dev/null \
  && ok "design mode marker present in mandate body" \
  || no "design mode marker missing. out='$out'"

# pending_review cleared after fire
[[ -f "$SDIR/state.local.md" ]] \
  && ! grep -q '^pending_review:' "$SDIR/state.local.md" \
  && grep -q '^last_dispatched_at:' "$SDIR/state.local.md" \
  && ok "state rewritten: pending_review cleared, last_dispatched_at set" \
  || no "state not rewritten cleanly"
finish
