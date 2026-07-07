#!/usr/bin/env bash
# test_pr_understanding_builder_frontmatter.sh — AC1/AC3/AC4 grep-lock on the
# builder agent's physical de-privileging + schema. Teeth: moving/removing a
# denied tool or the model line turns this RED.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
AGENT="$PLUGIN_ROOT/agents/pr-understanding-builder.md"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

test -f "$AGENT" || { echo "FAIL: agent file missing at $AGENT"; exit 1; }

# Frontmatter window = between the first two '---' lines.
fm() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$AGENT"; }
FM="$(fm)"

grep -qE '^model:[[:space:]]*opus[[:space:]]*$' <<<"$FM" \
  && pass "model: opus pinned" || fail "model: opus not pinned"

grep -qE '^allowedTools:[[:space:]]*\[\][[:space:]]*$' <<<"$FM" \
  && pass "allowedTools: [] (zero FS tools)" || fail "allowedTools not empty"

for t in Write Edit MultiEdit NotebookEdit Read Grep Glob Bash WebFetch WebSearch Agent; do
  if grep -qE "^[[:space:]]*-[[:space:]]*$t[[:space:]]*$" <<<"$FM"; then
    pass "disallowedTools denies $t"
  else
    fail "disallowedTools MISSING $t (builder could reach files)"
  fi
done

# AC3: no findings section in the persona body.
if ! grep -qiE 'findings|무엇을 고쳤' "$AGENT"; then
  pass "no findings section (AC3)"
else
  # allow the explicit 'no findings' prohibition, forbid an actual section
  if grep -qiE '^#+.*findings' "$AGENT"; then fail "artifact has a findings heading (AC3)"; else pass "findings only mentioned as prohibition (AC3)"; fi
fi

# AC4: mechanism-centric schema anchors present. (Before.*After is locale-robust:
# the → arrow is multibyte, so a single-char '.' would miss it under a C locale.)
for anchor in 'In one breath' 'Before.*After' '지금 어떻게 동작하나' '계약'; do
  grep -qE "$anchor" "$AGENT" && pass "schema anchor: $anchor" || fail "schema anchor missing: $anchor"
done

# --- Korean-primary style law (G3, v2.10.0) ---
grep -qF '한국어-primary' "$AGENT" \
  && pass "builder persona declares Korean-primary style law" \
  || fail "Korean-primary style law missing"
# 고정 영문 스키마 헤더는 유지(회귀: 헤더 한국어화 금지).
grep -qF 'In one breath' "$AGENT" \
  && pass "fixed English schema header 'In one breath' retained" \
  || fail "schema header drifted (NG3 violation)"

echo "builder-frontmatter: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
