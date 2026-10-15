#!/usr/bin/env bash
# spec-distill — 훅 부재 회귀 락: SessionStart anchor 제거(v0.16.0) · 설치되는 훅 없음(6.0.0, R7 AC10).
# Run: bash plugins/spec-distill/tests/test_hooks.sh
# session-anchor.sh 와 hooks/ 가 실수로 되살아나지 않음을 보장. Exits 0 on pass, 1 on fail.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
ANCHOR="$PLUGIN_ROOT/hooks/session-anchor.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

echo "=== SessionStart anchor removal regression lock ==="

# 1. hooks.json 이 없거나, 있으면 SessionStart 키가 없다(그리고 유효 JSON 이다).
if [[ ! -e "$HOOKS_JSON" ]]; then
  ok "hooks.json 이 없다 — SessionStart 훅도 없다"
elif python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); sys.exit(1 if "SessionStart" in d.get("hooks", {}) else 0)' "$HOOKS_JSON"; then
  ok "hooks.json has no SessionStart key"
else
  no "hooks.json still registers a SessionStart hook (or is invalid JSON)"
fi

# 2. The session-anchor.sh hook file must NOT exist.
if [[ ! -e "$ANCHOR" ]]; then
  ok "hooks/session-anchor.sh does not exist"
else
  no "hooks/session-anchor.sh still exists"
fi

# ── R7 §3-1 · AC10 — 설치되는 훅이 없다 ────────────────────────────────────
[[ ! -e "$PLUGIN_ROOT/hooks" ]] && ok "AC10: hooks/ 가 없다 — 설치되는 훅이 없다" || no "AC10: hooks/ 가 남아 있다"
[[ ! -e "$PLUGIN_ROOT/scripts/spec-distill-gc.py" ]] && ok "AC10: spec-distill-gc.py 가 없다" || no "AC10: spec-distill-gc.py 가 남아 있다"
# 지운 이름은 조각으로 잇는다 — test_review_hook_removed.py 가 hook_common 에서 빠진 이름의 리터럴을 리포 전체에서 금지한다.
grep -qE '^def fire_and_forget_g[c]' "$PLUGIN_ROOT/scripts/hook_common.py" \
  && no "AC10: hook_common 에 GC 기동이 남았다" || ok "AC10: hook_common 에 GC 기동이 없다"
grep -qE '^def _yaml_scalar' "$PLUGIN_ROOT/scripts/hook_common.py" \
  && ok "AC10 양의 짝: hook_common 이 남은 소비자의 _yaml_scalar 를 갖는다" || no "AC10 양의 짝: _yaml_scalar 가 사라졌다"
finish
