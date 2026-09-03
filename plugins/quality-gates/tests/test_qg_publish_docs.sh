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
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# floor는 minor(>=2.10) invariant다 — 리터럴 major "2" 로 짠 원래 regex는 v3.0.0
# major bump(비관련 기능인 Runtime 게이트 재설계)에서 stale-red 됐다. major 도
# unpin — 2.10+든 3.x+ 든 publish 표면이 shipped 라는 사실은 안 바뀐다.
grep -qE '"version":[[:space:]]*"([3-9]|[1-9][0-9]+)\.[0-9]+\.[0-9]+"|"version":[[:space:]]*"2\.(1[0-9]|[2-9][0-9])\.[0-9]+"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" \
  && ok "plugin.json version >=2.10 minor (publish surface shipped)" || no "plugin.json below 2.10 (publish surface reverted?)"
grep -qE '^## \[2\.10\.0\]' "$PLUGIN_ROOT/CHANGELOG.md" \
  && ok "CHANGELOG has [2.10.0]" || no "CHANGELOG missing [2.10.0]"
CUR_MINOR="$(grep -oE '"version":[[:space:]]*"[0-9]+\.[0-9]+' "$PLUGIN_ROOT/.claude-plugin/plugin.json" | grep -oE '[0-9]+\.[0-9]+' | head -1)"
grep -qE "^## \[${CUR_MINOR//./\\.}\.[0-9]+\]" "$PLUGIN_ROOT/CHANGELOG.md" \
  && ok "CHANGELOG has entry for current minor [$CUR_MINOR.x]" || no "CHANGELOG missing entry for plugin.json current minor $CUR_MINOR (버전 bump 하고 CHANGELOG 섹션 잊음?)"
README="$PLUGIN_ROOT/README.md"
awk '/^### Kill switches/{f=1;next} f&&/^## /{f=0} f' "$README" | grep -qF 'DEVBREW_QUALITY_GATES_DISABLE_PUBLISH' \
  && ok "README kill-switch inventory lists DEVBREW_QUALITY_GATES_DISABLE_PUBLISH" || no "kill switch not inventoried"
grep -qiE 'deterministic envelope|model-authored|모델 저술' "$PLUGIN_ROOT/README.md" \
  && ok "README honesty framing present" || no "honesty framing missing"
grep -qF '/qg-publish' "$PLUGIN_ROOT/commands/qg.md" \
  && ok "qg.md cross-refs /qg-publish" || no "no /qg-publish cross-ref"

# NG5 reconciliation (v6.0.0): 자동 offer 는 철회됐고 발행 경로는 명시 실행 하나다.
# 양성 증인 먼저 — 살아남은 경로가 실제로 문서화돼 있는가.
grep -qF '/qg-publish' "$README" \
  && ok "README documents the explicit publish path" || no "README lost the /qg-publish path"
grep -qF '/qg-publish' "$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md" \
  && ok "publish SKILL documents the explicit publish path" || no "publish SKILL lost the /qg-publish path"
# 그다음 부재 — 철회된 자동 offer 서술이 남아 있지 않은가.
grep -qF 'command-layer opt-in offer' "$README" \
  && no "README still describes the withdrawn command-layer offer" || ok "README free of the withdrawn offer"
grep -qF 'command-layer opt-in offer' "$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md" \
  && no "publish SKILL still describes the withdrawn command-layer offer" || ok "publish SKILL free of the withdrawn offer"
# 유지 불변식: '세 번째 게이트' 부정 + gh 게이트 부재는 남아 있어야.
grep -qF '세 번째 게이트가 아니다' "$README" \
  && ok "README keeps 'not a third gate'" || no "third-gate framing lost"
finish
