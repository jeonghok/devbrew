#!/usr/bin/env bash
# spec-distill — 인터뷰 월클락 제거 회귀 락 (v0.17.0).
# Run: bash plugins/spec-distill/tests/test_no_wall_clock.sh
# 월클락 토큰이 라이브 surface(2 SKILL + README)로 되살아나지 않음을 보장.
# CHANGELOG는 history 보존이라 스캔 제외(과거 Removed 엔트리가 정당하게 "wall-clock" 언급).
# Exits 0 on pass, 1 on fail.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"

# 라이브 surface — 월클락 토큰이 0이어야 하는 파일 (CHANGELOG 제외).
SURFACES=(
  "$PLUGIN_ROOT/skills/conducting-interview/SKILL.md"
  "$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"
  "$PLUGIN_ROOT/README.md"
)

# 금지 토큰 (재도입 방지).
TOKENS=(
  "wall_clock_started_at"
  "DEVBREW_SPEC_DISTILL_TIMEOUT_MIN"
  "wall-clock"
)

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

echo "=== interview wall-clock removal regression lock ==="

for surface in "${SURFACES[@]}"; do
  rel="${surface#"$REPO_ROOT"/}"
  if [[ ! -f "$surface" ]]; then
    no "surface missing: $rel"
    continue
  fi
  for tok in "${TOKENS[@]}"; do
    if grep -qiF -- "$tok" "$surface"; then
      no "$rel still contains token '$tok'"
    else
      ok "$rel free of '$tok'"
    fi
  done
done
finish
