#!/usr/bin/env bash
# test_qg_publish_docs.sh — AC15: version bump + honesty framing + kill-switch inventory.
# plugin.json version은 ≥2.10 minor(publish 표면 shipped 불변식; patch·minor 모두 unpin,
# floor만 핀)로 assert — devbrew의 "플러그인 건드리는 모든 PR은 patch-bump" 규칙 때문에
# 리터럴 2.10.0 pin은 다음 minor bump마다 stale-red. floor(>=2.10)는 v2.10.0 feature가
# 여전히 shipped임을 뜻하는 invariant라 pin 유지.
# CHANGELOG [2.10.0] 엔트리는 append-only 기록이라 리터럴 pin이 correct.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

grep -qE '"version":[[:space:]]*"2\.(1[0-9]|[2-9][0-9])\.[0-9]+"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  && pass "plugin.json version >=2.10 minor (publish surface shipped)" || fail "plugin.json below 2.10 (publish surface reverted?)"
grep -qE '^## \[2\.10\.0\]' "$PLUGIN_ROOT/CHANGELOG.md" \
  && pass "CHANGELOG has [2.10.0]" || fail "CHANGELOG missing [2.10.0]"
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
