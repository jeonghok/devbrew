#!/usr/bin/env bash
# AC4/AC5: SKILL.md dispatch logic invariant — proxy verification.
# Real LLM dispatch는 V7-V9 수동 검증 (LD7).
set -u
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "OK: $1"; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# Scenario 1: SKILL.md prose가 codex_available 가용 경로에서 codex-reviewer dispatch 명시?
# (proxy verification — actual LLM dispatch는 V7 수동, LD7)
# env vars (QG_MOCK_*)는 real LLM 실행에만 영향; 본 test는 SKILL.md prose만 검사.
DISPATCH_LINE=$(grep -B 2 -A 10 "codex_manifest\.codex_available == true" "$SKILL")
echo "$DISPATCH_LINE" | grep -qE "codex-reviewer" \
  || fail "Scenario 1: SKILL.md prose missing codex-reviewer dispatch when codex_available"
ok "Scenario 1: codex_available → codex-reviewer dispatched (prose check)"

# Scenario 2: codex_available=false → exactly 3-agent dispatch, NO codex-reviewer
DISPATCH_BLOCK=$(grep -B 2 -A 8 "codex_manifest.codex_available == false" "$SKILL")
echo "$DISPATCH_BLOCK" | grep -qE "phase1_agents.*\[.*code-reviewer.*silent-failure-hunter.*feature-dev:code-reviewer.*\]" \
  || fail "Scenario 2: SKILL.md does not specify 3-agent fallback for codex_available=false"
echo "$DISPATCH_BLOCK" | grep -q "codex-reviewer" \
  && fail "Scenario 2: codex-reviewer must NOT appear in unavailable branch"
ok "Scenario 2: codex_unavailable → 3-agent only (regression guard)"

echo "PASS: test_codex_dispatch_invariant.sh (2 scenarios)"
