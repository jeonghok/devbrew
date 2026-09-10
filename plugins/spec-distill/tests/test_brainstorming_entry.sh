#!/usr/bin/env bash
# AC9 — /interview 없이 들어온 세션(brainstorming 직접 진입)의 상태 폴더도 SessionEnd 가 치운다.
# sid 는 payload 에서만 온다 — 두 env 를 지우는 것이 이 케이스의 요지다(/interview 없이
# 들어온 세션은 하니스 payload 의 session_id 밖에 없다).
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
END="$PLUGIN_DIR/hooks/session-end-cleanup.py"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q

SID="brainstorm-12345678"
STATE_DIR="$WORK/.claude/spec-distill/$SID"
mkdir -p "$STATE_DIR"
echo "x" > "$STATE_DIR/docreview-state.md"

# (i) Setup — reviewing-spec 이 엔진 상태를 쓰는 세션 상태 디렉토리가 있다.
[[ -f "$STATE_DIR/docreview-state.md" ]] \
    && echo "[PASS] case i: session state dir present (sid=$SID)" \
    || { echo "[FAIL] case i: setup failed"; exit 1; }

# (ii) Cleanup — SessionEnd 훅이 payload 의 sid 로 그 폴더를 지운다. cwd 가 $WORK 라
# 같은 훅이 기동하는 TTL-GC 도 이 임시 리포의 상태 루트만 돈다.
printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WORK" \
    | env -u DEVBREW_SPEC_DISTILL_SESSION_ID -u CLAUDE_CODE_SESSION_ID python3 "$END" >/dev/null 2>&1

[[ ! -d "$STATE_DIR" ]] \
    && echo "[PASS] case ii: SessionEnd cleanup removed folder" \
    || { echo "[FAIL] case ii: folder still exists"; exit 1; }

echo "PASSED: 2 cases sequential"
