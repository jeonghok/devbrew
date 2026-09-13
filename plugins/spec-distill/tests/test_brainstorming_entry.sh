#!/usr/bin/env bash
# AC9 — /interview 없이 들어온 세션(brainstorming 직접 진입)의 상태 폴더도 SessionEnd 가 치운다.
# 지우는 대상은 payload 의 sid 다 — env 의 sid(`CLAUDE_CODE_SESSION_ID`, 지금 도는 세션)가 아니다.
#   (i)  env 에 다른 세션의 sid 가 있어도 payload sid 의 폴더만 지우고 env sid 의 폴더는 남긴다.
#   (ii) env 가 비었어도(/interview 없이 들어온 세션은 하니스 payload 의 session_id 밖에 없다)
#        payload sid 로 지운다.
set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
END="$PLUGIN_DIR/hooks/session-end-cleanup.py"

WORK=$(mktemp -d)
[[ -n "$WORK" && -d "$WORK" ]] || { echo "[FAIL] mktemp 가 빈 경로를 냈다"; exit 1; }
trap 'rm -rf "$WORK"' EXIT
cd "$WORK"
git init -q

SID="brainstorm-12345678"
ENV_SID="envsession-87654321"
STATE_DIR="$WORK/.claude/spec-distill/$SID"
ENV_DIR="$WORK/.claude/spec-distill/$ENV_SID"
mkdir -p "$STATE_DIR" "$ENV_DIR"
echo "x" > "$STATE_DIR/docreview-state.md"
echo "y" > "$ENV_DIR/docreview-state.md"

# (i) payload sid 가 이긴다. cwd 가 $WORK 라 같은 훅이 기동하는 TTL-GC 도 이 임시 리포의
# 상태 루트만 돈다(두 폴더 다 방금 만들어 TTL 안이다).
printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WORK" \
    | env -u DEVBREW_SPEC_DISTILL_SESSION_ID CLAUDE_CODE_SESSION_ID="$ENV_SID" python3 "$END" >/dev/null 2>&1
if [[ ! -d "$STATE_DIR" && -f "$ENV_DIR/docreview-state.md" ]]; then
  echo "[PASS] case i: payload sid 폴더만 지웠다 — env sid($ENV_SID) 폴더는 남았다"
else
  echo "[FAIL] case i: payload 폴더 존재=$([[ -d "$STATE_DIR" ]] && echo y || echo n) env 폴더 존재=$([[ -d "$ENV_DIR" ]] && echo y || echo n)"
  exit 1
fi

# (ii) env 가 비었을 때 — payload sid 로 지운다.
mkdir -p "$STATE_DIR"
echo "x" > "$STATE_DIR/docreview-state.md"
printf '{"session_id":"%s","cwd":"%s"}' "$SID" "$WORK" \
    | env -u DEVBREW_SPEC_DISTILL_SESSION_ID -u CLAUDE_CODE_SESSION_ID python3 "$END" >/dev/null 2>&1

[[ ! -d "$STATE_DIR" ]] \
    && echo "[PASS] case ii: SessionEnd cleanup removed folder" \
    || { echo "[FAIL] case ii: folder still exists"; exit 1; }

echo "PASSED: 2 cases sequential"
