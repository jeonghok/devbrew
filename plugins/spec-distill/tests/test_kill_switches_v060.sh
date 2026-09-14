#!/usr/bin/env bash
# AC10 — v0.6.0 kill switch matrix across new hooks/scripts.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# Setup tmp env
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p .claude/spec-distill/kill-test-12345
echo "x" > .claude/spec-distill/kill-test-12345/state.local.md

# Case 1: global DEVBREW_SPEC_DISTILL_DISABLE=1 blocks SessionEnd
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ -d .claude/spec-distill/kill-test-12345 ]] \
    && ok "case 1: global kill switch blocks SessionEnd" \
    || no "case 1: SessionEnd fired despite kill switch"

# Case 2: global kill switch blocks GC
mkdir -p .claude/spec-distill/old-12345678
echo "x" > .claude/spec-distill/old-12345678/state.local.md
past=$(($(date +%s) - 90000))
touch -d "@$past" .claude/spec-distill/old-12345678/state.local.md 2>/dev/null \
    || python3 -c "import os; os.utime('.claude/spec-distill/old-12345678/state.local.md', ($past, $past))"
# 폴더 자신의 mtime 도 늙힌다 — GC 나이는 폴더 자신과 그 아래 모든 항목의 최신 mtime 이다(3.1.0). 늙히지
# 않으면 방금 만든 폴더의 mtime 이 kill switch 와 무관하게 폴더를 살려 이 칸이 공허해진다.
python3 -c "import os; os.utime('.claude/spec-distill/old-12345678', ($past, $past))"
env DEVBREW_SPEC_DISTILL_DISABLE=1 python3 "$PLUGIN_DIR/scripts/spec-distill-gc.py" >/dev/null
[[ -d .claude/spec-distill/old-12345678 ]] \
    && ok "case 2: global kill switch blocks GC" \
    || no "case 2: GC fired despite kill switch"

# Case 3: granular DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ -d .claude/spec-distill/kill-test-12345 ]] \
    && ok "case 3: granular kill switch blocks SessionEnd" \
    || no "case 3: SessionEnd fired despite granular"

# Case 4: CSV multi-kill DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd,other:event
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SKIP_HOOKS="spec-distill:SessionEnd,quality-gates:Stop" \
        python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ -d .claude/spec-distill/kill-test-12345 ]] \
    && ok "case 4: CSV granular kill blocks correct hook" \
    || no "case 4: CSV granular failed"

# Case 5: DEVBREW_SKIP_HOOKS=quality-gates:SessionEnd does NOT affect spec-distill
printf '{"session_id":"kill-test-12345","cwd":"%s"}' "$WORK" \
    | env DEVBREW_SKIP_HOOKS="quality-gates:SessionEnd" \
        python3 "$PLUGIN_DIR/hooks/session-end-cleanup.py" >/dev/null
[[ ! -d .claude/spec-distill/kill-test-12345 ]] \
    && ok "case 5: cross-plugin kill switch ignored" \
    || no "case 5: cross-plugin kill switch leaked"

# Re-create folder for next case
mkdir -p .claude/spec-distill/kill-test-12345
echo "x" > .claude/spec-distill/kill-test-12345/state.local.md

# Case 6: TTL override DEVBREW_SPEC_DISTILL_TTL_HOURS
mkdir -p .claude/spec-distill/ttl-12345678
echo "x" > .claude/spec-distill/ttl-12345678/state.local.md
past=$(($(date +%s) - 7200))  # 2h old
python3 -c "import os; os.utime('.claude/spec-distill/ttl-12345678/state.local.md', ($past, $past))"
python3 -c "import os; os.utime('.claude/spec-distill/ttl-12345678', ($past, $past))"   # 폴더 자신도(3.1.0)
env DEVBREW_SPEC_DISTILL_TTL_HOURS=1 python3 "$PLUGIN_DIR/scripts/spec-distill-gc.py" >/dev/null
[[ ! -d .claude/spec-distill/ttl-12345678 ]] \
    && ok "case 6: TTL override removes 2h-old folder" \
    || no "case 6: TTL override failed"

rm -rf "$WORK"

finish
