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

# Scenario 3: scout-fallback + codex_available=true → codex-reviewer STILL dispatched
DISPATCH_FALLBACK=$(grep -A 8 "scout-fallback\|scout fallback" "$SKILL" | head -15)
echo "$DISPATCH_FALLBACK" | grep -qE "codex-reviewer" \
  || fail "Scenario 3: fallback branch drops codex-reviewer silently"
echo "$DISPATCH_FALLBACK" | grep -qE "scout fallback engaged" \
  || fail "Scenario 3: fallback engage stderr message missing"
ok "Scenario 3: scout-fallback + codex_available → codex-reviewer dispatched + visibility message"

# Scenario 4: project_dir contract in 5 SKILL.md dispatch blocks (AC1)
# Pattern P — 4 agents with explicit Agent() block (window=15)
for name in scout adversarial synthesizer test-scope-validator; do
  if ! awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+15 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL"; then
    fail "Scenario 4: Pattern-P dispatch block for $name lacks project_dir"
  fi
done

# Pattern L — security-reviewer prose header (window=30)
# Updated in v1.16.0: heading changed from **Agent D — security-reviewer**
# to *security-reviewer (`quality-gates:security-reviewer`)* inside the
# unified dispatch section.
if ! awk '
  /\*security-reviewer \(`quality-gates:security-reviewer`\)/ { found=NR }
  found && NR <= found+30 && /project_dir/ { ok=1; exit }
  END { exit !ok }
' "$SKILL"; then
  fail "Scenario 4: Pattern-L security-reviewer section lacks project_dir reference"
fi

# T3-3: codex-reviewer.md deleted — verify script invocation exists in SKILL.md instead.
if ! grep -q 'run_codex_reviewer.sh' "$SKILL"; then
  fail "Scenario 4: SKILL.md missing run_codex_reviewer.sh script invocation (T3-3)"
fi

ok "Scenario 4: all 5 agents + script invocation have project_dir/path contract (P×4 + L×1 + script×1)"

echo "PASS: test_codex_dispatch_invariant.sh (4 scenarios)"
