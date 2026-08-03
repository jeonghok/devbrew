#!/usr/bin/env bash
# test_qg_publish_docs.sh — AC15: version bump + honesty framing + kill-switch inventory.
# plugin.json version은 ≥2.10 minor(publish 표면 shipped 불변식; patch·minor 모두 unpin,
# floor만 핀)로 assert — devbrew의 "플러그인 건드리는 모든 PR은 patch-bump" 규칙 때문에
# 리터럴 pin은 다음 minor bump마다 stale-red. floor(>=2.10)는 v2.10.0 feature가 여전히
# shipped임을 뜻하는 invariant라 pin 유지.
# CHANGELOG 는 append-only anchor([2.10.0])와 **plugin.json 의 현재 버전 엔트리** 둘 다 존재를
# assert — 현재-버전 엔트리는 리터럴이 아니라 plugin.json 에서 minor 를 읽어 버전-무관하게 검사한다
# (버전 bump 하고 CHANGELOG 섹션 잊음 regress 를 잡되 다음 bump 에 stale 되지 않음; SUG-2, iter-1 리뷰).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

# floor는 minor(>=2.10) invariant다 — 리터럴 major "2" 로 짠 원래 regex는 v3.0.0
# major bump(비관련 기능인 Runtime 게이트 재설계)에서 stale-red 됐다. major 도
# unpin — 2.10+든 3.x+ 든 publish 표면이 shipped 라는 사실은 안 바뀐다.
grep -qE '"version":[[:space:]]*"([3-9]|[1-9][0-9]+)\.[0-9]+\.[0-9]+"|"version":[[:space:]]*"2\.(1[0-9]|[2-9][0-9])\.[0-9]+"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  && pass "plugin.json version >=2.10 minor (publish surface shipped)" || fail "plugin.json below 2.10 (publish surface reverted?)"
grep -qE '^## \[2\.10\.0\]' "$PLUGIN_ROOT/CHANGELOG.md" \
  && pass "CHANGELOG has [2.10.0]" || fail "CHANGELOG missing [2.10.0]"
CUR_MINOR="$(grep -oE '"version":[[:space:]]*"[0-9]+\.[0-9]+' "$PLUGIN_ROOT/.claude-plugin/plugin.json" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
grep -qE "^## \[${CUR_MINOR//./\\.}\.[0-9]+\]" "$PLUGIN_ROOT/CHANGELOG.md" \
  && pass "CHANGELOG has entry for current minor [$CUR_MINOR.x]" || fail "CHANGELOG missing entry for plugin.json current minor $CUR_MINOR (버전 bump 하고 CHANGELOG 섹션 잊음?)"
README="$PLUGIN_ROOT/README.md"
awk '/^### Kill switches/{f=1;next} f&&/^## /{f=0} f' "$README" | grep -qF 'DEVBREW_QG_DISABLE_PUBLISH' \
  && pass "README kill-switch inventory lists DEVBREW_QG_DISABLE_PUBLISH" || fail "kill switch not inventoried"
grep -qiE 'deterministic envelope|model-authored|모델 저술' "$PLUGIN_ROOT/README.md" \
  && pass "README honesty framing present" || fail "honesty framing missing"
grep -qF '/qg-publish' "$PLUGIN_ROOT/commands/qg.md" \
  && pass "qg.md cross-refs /qg-publish" || fail "no /qg-publish cross-ref"

# NG5 reconciliation: command-layer opt-in offer는 있으나 자동 실행 아님.
grep -qF 'command-layer opt-in offer' "$README" \
  && pass "README reconciles NG5 to command-layer opt-in offer" \
  || fail "README NG5 reconciliation phrase missing"
grep -qF 'command-layer opt-in offer' "$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md" \
  && pass "publish SKILL reconciles NG5" || fail "publish SKILL NG5 phrase missing"
# 유지 불변식: '세 번째 게이트' 부정 + gh 게이트 부재는 남아 있어야.
grep -qF '세 번째 게이트가 아니다' "$README" \
  && pass "README keeps 'not a third gate'" || fail "third-gate framing lost"

echo "qg-publish-docs: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
