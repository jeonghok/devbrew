#!/usr/bin/env bash
# Unit tests for qg-worktree.sh — the subcommand surface and `remove`.
# (create-baseline · create-head 의 동작은 test_runtime_contract_invariance.sh 가 잰다.)
set -u

PLUGIN_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WT="$PLUGIN_DIR/scripts/qg-worktree.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

new_repo() {   # 커밋 하나짜리 일회용 리포 — 경로를 낸다
  local r; r=$(mktemp -d)
  (cd "$r" && git init -q -b main && git config user.email t@t && \
    git config user.name t && git commit -q --allow-empty -m init)
  printf '%s' "$r"
}

# --- surface: branch 모드 하위명령은 없다 (v10) ---
echo "[surface]"
REPO=$(new_repo)
for sub in sanitize validate-branch create; do
  err=$(cd "$REPO" && "$WT" "$sub" x y 2>&1 >/dev/null); rc=$?
  if [ "$rc" -eq 2 ] && printf '%s' "$err" | grep -q "unknown subcommand: $sub"; then
    ok "'$sub' 는 unknown subcommand 로 거부된다"
  else
    no "'$sub' 가 아직 동작한다 (rc=$rc err=$err)"
  fi
done
# 양의 짝 — 남는 하위명령은 그대로 동작한다
base_sha=$(cd "$REPO" && git rev-parse HEAD)
WTPATH=$(cd "$REPO" && "$WT" create-baseline "$base_sha" "surface1234567" 2>/dev/null)
[ -d "$WTPATH" ] && ok "create-baseline 은 그대로 동작한다" || no "create-baseline 이 깨졌다: '$WTPATH'"
rm -rf "$REPO"

# --- remove ---
echo "[remove]"
REPO=$(new_repo)
base_sha=$(cd "$REPO" && git rev-parse HEAD)
WTPATH=$(cd "$REPO" && "$WT" create-baseline "$base_sha" "remove-test12345" 2>/dev/null)
[ -d "$WTPATH" ] || { no "create-baseline precondition"; }

(cd "$REPO" && "$WT" remove "$WTPATH") \
  && [ ! -d "$WTPATH" ] && ok "remove deletes dir" \
  || no "remove failed or dir remains"

# Remove a nonexistent path → exit 0 (best-effort)
(cd "$REPO" && "$WT" remove "$REPO/.claude/quality-gates/worktrees/missing-12345678") \
  && ok "remove missing is noop" || no "remove missing errored"

# Refuse outside-namespace paths (safety)
(cd "$REPO" && "$WT" remove "/tmp" 2>/dev/null) \
  && no "removed outside namespace" || ok "outside namespace refused"

rm -rf "$REPO"
finish
