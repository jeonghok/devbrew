#!/usr/bin/env bash
# AC1 · AC2 · AC16 — 활성 문서가 `allowedTools`를 로드베어링으로 주장하지 못하게 한다.
#
# 왜 이 락이 필요한가: 이 리포는 존재하지 않는 필드를 "실제 키"로 명명하고
# 3중 격리의 "Layer 1(불가결)"으로 규정한 산문을 v1.11.1부터 shipping해 왔다
# (quality-gates/README.md:30). 그 산문이 있는 한 다음 저자가 같은 버그를 재도입한다.
#
# 범위 밖 (기록이므로 무변경): CHANGELOG · docs/handoff/** · docs/superpowers/**
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

# AC16 경로 화이트리스트 — 활성 문서만.
FILES=(CLAUDE.md docs/plugin-authoring.md)
while IFS= read -r f; do FILES+=("$f"); done < <(ls plugins/*/README.md 2>/dev/null)
while IFS= read -r f; do FILES+=("$f"); done < <(find plugins/*/skills -name 'SKILL.md' 2>/dev/null)

# --- AC16-1: `allowedTools` 리터럴 0건 ---
# \b 필수: naive grep은 `disallowedTools`의 부분문자열에 매칭돼 이미 clean한 파일에 false-positive.
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  if grep -qE '\ballowedTools\b' "$f"; then
    fail "AC16: $f 가 여전히 allowedTools 를 언급한다 ($(grep -nE '\ballowedTools\b' "$f" | head -1 | cut -c1-80))"
  else
    pass "AC16: $f — allowedTools 없음"
  fi
done

# --- AC16-2: 로드베어링 주장 리터럴 0건 ---
for lit in '실제 키' 'Layer 1 없이' '네트워크 tool 0개' 'tool 0개'; do
  hits="$(grep -rlF "$lit" "${FILES[@]}" 2>/dev/null || true)"
  if [ -n "$hits" ]; then
    fail "AC16: 금지 리터럴 '$lit' 잔존 → $hits"
  else
    pass "AC16: 금지 리터럴 '$lit' 없음"
  fi
done

# --- AC1: CLAUDE.md 가 agent 격리로 kebab 을 지목하지 않는다 ---
if grep -nE '`allowed-tools`[[:space:]]*/[[:space:]]*`disallowed-tools`' CLAUDE.md | grep -q .; then
  fail "AC1: CLAUDE.md 가 여전히 agent 격리 메커니즘으로 kebab allowed-tools/disallowed-tools 를 지목"
else
  pass "AC1: CLAUDE.md 에 kebab agent-격리 서술 없음"
fi

# --- AC2: CLAUDE.md 가 allowlist 규범을 명시한다 (body-unique 문구) ---
# 헤더-satisfiable 함정 회피: 헤더가 아니라 본문에만 있는 문구를 요구한다.
grep -qF 'denylist는 시간에 대해 fail-open' CLAUDE.md \
  && pass "AC2: denylist 시간-fail-open 근거 명시" \
  || fail "AC2: CLAUDE.md 에 'denylist는 시간에 대해 fail-open' 근거가 없다"
grep -qE '`tools:`[^`]*allowlist' CLAUDE.md \
  && pass "AC2: tools: allowlist 규범 명시" \
  || fail "AC2: CLAUDE.md 가 tools: allowlist 를 요구하지 않는다"

echo; echo "law2-prose: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
