#!/usr/bin/env bash
# V5 / AC4 / AC12 / C10 — probe_budget.py 백스톱: check가 cap에서 gate,
# increment는 cap을 이유로는 절대 gate하지 않고 전진하지만(gating 아님) state가
# unreadable/absent/malformed(카운터 라인 부재 포함)면 check와 동일하게 fail-closed(exit 1).
# raise-cap이 effective_cap을 올린다. mutation-testable(teeth).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/probe_budget.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC12(a): probe_count == effective_cap → check non-zero (gate). gate 제거 시 RED.
python3 "$SCRIPT" check "$FX/state-probe-at-cap.md" >/dev/null 2>&1 \
  && note FAIL "AC12(a): probe_count=cap should block (check exit 1)" \
  || note PASS "AC12(a): probe_count=cap blocks (check exit 1)"

# within budget → exit 0
python3 "$SCRIPT" check "$FX/state-probe-within.md" >/dev/null 2>&1 \
  && note PASS "check within budget → exit 0" \
  || note FAIL "check within budget should pass"

# AC12(b): at-cap 픽스처 복사본에 raise-cap → override 지속 → check exit 0. raise-cap 로직 제거 시 RED.
tmp="$(mktemp)"; cp "$FX/state-probe-at-cap.md" "$tmp"
python3 "$SCRIPT" raise-cap "$tmp" >/dev/null 2>&1
grep -qE '^probe_cap_override: 12\b' "$tmp" \
  && note PASS "AC12(b): raise-cap set probe_cap_override to 12 (base_cap)" \
  || note FAIL "AC12(b): raise-cap did not persist probe_cap_override"
python3 "$SCRIPT" check "$tmp" >/dev/null 2>&1 \
  && note PASS "AC12(b): after raise-cap, effective_cap synthesized → check exit 0" \
  || note FAIL "AC12(b): raise-cap should lift effective_cap past probe_count"
rm -f "$tmp"

# well-formed state → increment succeeds (gating은 check 담당 — C10 원자성) + 카운터 전진.
tmp2="$(mktemp)"; printf -- '---\nprobe_count: 0\nprobe_cap_override: 0\n---\n' > "$tmp2"
python3 "$SCRIPT" increment "$tmp2" >/dev/null 2>&1 \
  && note PASS "increment on well-formed state returns exit 0 (never cap-gates — C10)" \
  || note FAIL "increment on well-formed state should exit 0"
grep -qE '^probe_count: 1\b' "$tmp2" \
  && note PASS "increment advanced probe_count to 1" \
  || note FAIL "increment did not advance probe_count"
rm -f "$tmp2"

# increment at/over cap도 (well-formed state라면) exit 0 (오직 check만 cap-gate — 원자성 분리 증명).
tmp3="$(mktemp)"; cp "$FX/state-probe-at-cap.md" "$tmp3"
python3 "$SCRIPT" increment "$tmp3" >/dev/null 2>&1 \
  && note PASS "increment at cap still exits 0 (gating is check-only, C10)" \
  || note FAIL "increment must not gate even at cap"
rm -f "$tmp3"

# increment fails closed when the probe_count counter line is absent (no silent create —
# this is exactly the legacy in-flight-migration hazard: a resumed pre-0.22.0 session that
# hasn't yet persisted the migrated schema has no probe_count line on disk).
tmp6="$(mktemp)"; printf -- '---\nphase: 1\n---\n' > "$tmp6"
python3 "$SCRIPT" increment "$tmp6" >/dev/null 2>&1 \
  && note FAIL "increment with absent probe_count should fail closed" \
  || note PASS "increment with absent probe_count fails closed (exit 1)"
rm -f "$tmp6"

# env override: DEVBREW_SPEC_DISTILL_PROBE_CAP가 base_cap을 올린다.
tmp4="$(mktemp)"; printf -- '---\nprobe_count: 12\nprobe_cap_override: 0\n---\n' > "$tmp4"
DEVBREW_SPEC_DISTILL_PROBE_CAP=20 python3 "$SCRIPT" check "$tmp4" >/dev/null 2>&1 \
  && note PASS "env DEVBREW_SPEC_DISTILL_PROBE_CAP=20 → probe_count 12 within budget" \
  || note FAIL "env cap override not honored"
rm -f "$tmp4"

# malformed probe_count → fail closed (silent-0 금지).
tmp5="$(mktemp)"; printf -- '---\nprobe_count: abc\nprobe_cap_override: 0\n---\n' > "$tmp5"
python3 "$SCRIPT" check "$tmp5" >/dev/null 2>&1 \
  && note FAIL "malformed probe_count should fail closed" \
  || note PASS "malformed probe_count fails closed (exit 1)"
rm -f "$tmp5"

# missing state file → fail closed.
python3 "$SCRIPT" check "$FX/__no_such_state__.md" >/dev/null 2>&1 \
  && note FAIL "missing state should fail closed" \
  || note PASS "missing state fails closed (exit 1)"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
