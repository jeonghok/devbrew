#!/usr/bin/env bash
# test_pr_understanding_builder_frontmatter.sh — AC1/AC3/AC4 grep-lock on the
# builder agent's physical de-privileging + schema. Teeth: moving/removing a
# denied tool or adding a model key turns this RED.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
AGENT="$PLUGIN_ROOT/agents/pr-understanding-builder.md"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

test -f "$AGENT" || { echo "FAIL: agent file missing at $AGENT"; exit 1; }

# Frontmatter window = between the first two '---' lines.
fm() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT"; }
FM="$(fm)"

MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$FM" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (사용자 설정 → 세션 모델)"

# AC5 (v2.11.0): 단일 무해 항목 allowlist. denylist 시대 종료.
# 왜 바뀌었나: `allowedTools`는 공식 subagent 필드가 아니라 조용히 무시됐고, 실효 표면은
# "denied 11개를 뺀 전부"였다 — 거기에 `mcp__*`가 없어 tavily·chrome-devtools 가 열려 있었다.
# 이름 기반 denylist는 원리적으로 닫히지 않는다(`Monitor` = 이름 없는 셸 + egress).
grep -qE '^tools:[[:space:]]*Read[[:space:]]*$' <<<"$FM" \
  && ok "tools: Read (단일 무해 항목 — fail-closed)" \
  || no "tools: 가 단일 무해 항목이 아님"

grep -qE '^allowedTools:' <<<"$FM" \
  && no "죽은 allowedTools 키 잔존" \
  || ok "allowedTools 없음"

grep -qE '^disallowedTools:' <<<"$FM" \
  && no "disallowedTools 잔존 (allowlist가 컨트롤 — denylist 병기 금지)" \
  || ok "disallowedTools 없음"

# 이 agent가 결코 가져선 안 되는 것들이 tools: 에 없음 (도구별 확인)
TOOLS_VAL="$(grep -m1 -E '^tools:' <<<"$FM" | sed 's/^tools:[[:space:]]*//')"
for t in Write Edit MultiEdit NotebookEdit Grep Glob Bash WebFetch WebSearch Agent Monitor ToolSearch; do
  if grep -qE "(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$TOOLS_VAL"; then
    no "tools: 에 $t 가 있다 (생성기가 스스로를 게시할 길이 열림)"
  else
    ok "tools: 에 $t 없음"
  fi
done
grep -q 'mcp__' <<<"$TOOLS_VAL" \
  && no "tools: 에 MCP grant 가 있다" \
  || ok "tools: 에 MCP 없음"

# AC3: no findings section in the persona body.
if ! grep -qiE 'findings|무엇을 고쳤' "$AGENT"; then
  ok "no findings section (AC3)"
else
  # allow the explicit 'no findings' prohibition, forbid an actual section
  if grep -qiE '^#+.*findings' "$AGENT"; then no "artifact has a findings heading (AC3)"; else ok "findings only mentioned as prohibition (AC3)"; fi
fi

# AC4: mechanism-centric schema anchors present. (Before.*After is locale-robust:
# the → arrow is multibyte, so a single-char '.' would miss it under a C locale.)
for anchor in 'In one breath' 'Before.*After' '지금 어떻게 동작하나' '계약'; do
  grep -qE "$anchor" "$AGENT" && ok "schema anchor: $anchor" || no "schema anchor missing: $anchor"
done

# --- Korean-primary style law (G3, v2.10.0) ---
grep -qF '한국어-primary' "$AGENT" \
  && ok "builder persona declares Korean-primary style law" \
  || no "Korean-primary style law missing"
# 고정 영문 스키마 헤더는 유지(회귀: 헤더 한국어화 금지).
grep -qF 'In one breath' "$AGENT" \
  && ok "fixed English schema header 'In one breath' retained" \
  || no "schema header drifted (NG3 violation)"
finish
