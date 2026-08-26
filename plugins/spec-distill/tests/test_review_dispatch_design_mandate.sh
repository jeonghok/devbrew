#!/usr/bin/env bash
# AC2 + AC12 for Stop hook review-dispatch.py — design-mode mandate body.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-mandate-XXXXXX) || exit 1
# symlink 해소(macOS /var → /private/var). 발견은 `git rev-parse --show-toplevel` 로
# 얻은 루트를 조인해 절대경로를 내므로, 여기서 풀지 않으면 기대 경로와 문자열이 어긋난다.
WORK=$(cd "$WORK" && pwd -P) || exit 1
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
EOF

# dispatch 대상은 발견에서 온다 — dirty·untracked 스코프 문서를 실제로 만든다.
REL="docs/superpowers/specs/2026-05-17-x-design.md"
mkdir -p "$WORK/main-repo/$(dirname "$REL")"
cp "$REPO_ROOT/plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md" \
   "$WORK/main-repo/$REL"

out=$(cd "$WORK/main-repo" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$SID" python3 "$HOOK" </dev/null 2>/dev/null)
rc=$?

# AC2 — Stop hook dual-target schema: long mandate in .reason, short trace in .systemMessage.
echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && ok "AC2: mandate (.reason) contains 'reviewing-spec' + 'terminal handoff' phrases" \
  || no "AC2 failed. out='$out'"

# AC12 — mandate 는 문서가 **어느 체크아웃에** 있는지를 말한다.
# 예전에는 별도 `worktree_path:` 줄이 그 일을 했고 그 값의 출처는 pending 을 쓰던
# PostToolUse 훅의 cwd 였다. 지금 발견이 내는 spec path 가 절대경로라 같은 사실을
# 스스로 말한다 — 그래서 재는 대상은 줄의 존재가 아니라 **경로가 이 리포를 가리키는가**다.
echo "$out" | jq -e --arg p "$WORK/main-repo/$REL" '.reason | contains("spec path: " + $p)' >/dev/null \
  && ok "AC12: mandate (.reason) 가 이 체크아웃의 절대경로를 싣는다" \
  || no "AC12 failed. out='$out'"

# Mode signal — design mode mandate should carry mode marker in .reason
echo "$out" | jq -e '.reason | contains("mode: design")' >/dev/null \
  && ok "design mode marker present in mandate body" \
  || no "design mode marker missing. out='$out'"

# state rewritten: in-flight 표시 + last_dispatched_at
[[ -f "$SDIR/state.local.md" ]] \
  && grep -qE "^  $REL: 20[0-9][0-9]-" "$SDIR/state.local.md" \
  && grep -q '^last_dispatched_at:' "$SDIR/state.local.md" \
  && ok "state rewritten: in-flight 표시 기록, last_dispatched_at set" \
  || no "state not rewritten cleanly"
finish
