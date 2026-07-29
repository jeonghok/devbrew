#!/usr/bin/env bash
# V5 / AC7 / AC8 — web_budget.py enforces sweep<=4, session<=8; kill switch = ok.
# F1 — parser tolerates the SKILL-prescribed inline-comment counter format.
# F2 — increment/reset-sweep subcommands actually advance/zero the state counters.
# F9-C — missing/malformed state fails closed (never silent-0).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/web_budget.py"
FX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# within budget → exit 0
python3 "$SCRIPT" check "$FX/state-web-within.md" >/dev/null 2>&1 \
  && note PASS "AC7: sweep=4/session=8 within budget (exit 0)" \
  || note FAIL "AC7: within-budget should pass"

# sweep over cap → exit 1
python3 "$SCRIPT" check "$FX/state-web-over-sweep.md" >/dev/null 2>&1 \
  && note FAIL "AC7: sweep=5 should be rejected" \
  || note PASS "AC7: sweep=5 > 4 rejected (exit 1)"

# session over cap → exit 1
python3 "$SCRIPT" check "$FX/state-web-over-session.md" >/dev/null 2>&1 \
  && note FAIL "AC7: session=9 should be rejected" \
  || note PASS "AC7: session=9 > 8 rejected (exit 1)"

# B2: a pre-dispatch gate must evaluate the PROSPECTIVE count. The plain check
# rejects only `> CAP`, so at `count == CAP` it passes → caller dispatches →
# increment lands on CAP+1: one dispatch past the stated cap (reproduced).
# The two assertions are deliberately paired on the SAME fixture: the plain
# check must still pass (the historical contract is untouched) while the
# prospective one must reject. A single assertion on either alone cannot tell
# "the flag works" from "the fixture is over/under budget for both".
python3 "$SCRIPT" check "$FX/state-web-within.md" >/dev/null 2>&1 \
  && note PASS "B2: sweep=4/session=8 plain check → exit 0 (기존 계약 불변)" \
  || note FAIL "B2: plain check의 기존 경계 동작이 바뀌었다"
python3 "$SCRIPT" check --prospective "$FX/state-web-within.md" >/dev/null 2>&1 \
  && note FAIL "B2: --prospective가 cap 도달 상태를 통과 — dispatch 1회가 상한을 넘는다" \
  || note PASS "B2: --prospective가 cap 도달 상태를 거부 (exit 1)"
# 한 칸 아래에서는 통과해야 한다 — 아니면 "무엇이든 거부"라 이빨이 없다.
tmp_p="$(mktemp)"; printf -- '---\nweb_sweep_count: 3\nweb_search_count: 7\n---\n' > "$tmp_p"
python3 "$SCRIPT" check --prospective "$tmp_p" >/dev/null 2>&1 \
  && note PASS "B2: --prospective가 cap-1 상태는 통과 (무조건 거부가 아님)" \
  || note FAIL "B2: --prospective가 예산 내에서도 거부한다"
rm -f "$tmp_p"
# 플래그는 check 전용 — increment는 bump-then-check라 prospective가 이중 계상이 된다.
python3 "$SCRIPT" increment --prospective "$FX/state-web-within.md" >/dev/null 2>&1 \
  && note FAIL "B2: increment가 --prospective를 받아들였다 (이중 계상)" \
  || note PASS "B2: --prospective는 check 전용 (increment는 거부)"

# AC8: kill switch forces ok even when over budget (graceful degradation)
DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 python3 "$SCRIPT" check "$FX/state-web-over-sweep.md" >/dev/null 2>&1 \
  && note PASS "AC8: DEVBREW_SPEC_DISTILL_DISABLE_WEB=1 → exit 0 (web disabled)" \
  || note FAIL "AC8: kill switch should short-circuit to ok"

# F1: SKILL-prescribed counter format carries an inline comment. The parser must
# still read it — otherwise over-cap counts silently read as 0 (fail-open).
python3 "$SCRIPT" check "$FX/state-web-commented-overcap.md" >/dev/null 2>&1 \
  && note FAIL "F1: over-cap counters in inline-comment format should be rejected" \
  || note PASS "F1: commented-format over-cap rejected (parser tolerates inline comment)"

# F1: a counter present but non-numeric must fail closed, not default to 0.
tmp_mal="$(mktemp)"; printf -- '---\nweb_sweep_count: abc\nweb_search_count: 0\n---\n' > "$tmp_mal"
python3 "$SCRIPT" check "$tmp_mal" >/dev/null 2>&1 \
  && note FAIL "F1: malformed counter should fail closed" \
  || note PASS "F1: malformed counter fails closed (exit 1)"
rm -f "$tmp_mal"

# F9-C: missing state file → fail closed (the web call must block, not proceed).
python3 "$SCRIPT" check "$FX/__does-not-exist__.md" >/dev/null 2>&1 \
  && note FAIL "F9-C: missing state file should fail closed" \
  || note PASS "F9-C: missing state file fails closed (exit 1)"

# F2: increment bumps both counters and preserves the inline comment.
tmp_inc="$(mktemp)"
printf -- '---\nweb_sweep_count: 0                   # sweep ≤4\nweb_search_count: 0                  # session ≤8\n---\nbody\n' > "$tmp_inc"
python3 "$SCRIPT" increment "$tmp_inc" >/dev/null 2>&1 \
  && note PASS "F2: increment within budget returns ok (exit 0)" \
  || note FAIL "F2: increment within budget should return ok"
{ grep -qE '^web_sweep_count: 1\b' "$tmp_inc" && grep -qE '^web_search_count: 1\b' "$tmp_inc" \
  && grep -q 'sweep ≤4' "$tmp_inc"; } \
  && note PASS "F2: increment advanced both counters to 1 and kept inline comment" \
  || note FAIL "F2: increment did not advance counters / dropped comment"
rm -f "$tmp_inc"

# F2: increment-then-check blocks the call that pushes sweep over cap (4→5).
tmp_cap="$(mktemp)"; printf -- '---\nweb_sweep_count: 4\nweb_search_count: 0\n---\n' > "$tmp_cap"
python3 "$SCRIPT" increment "$tmp_cap" >/dev/null 2>&1 \
  && note FAIL "F2: incrementing sweep 4→5 (over cap) should block" \
  || note PASS "F2: increment sweep 4→5 over cap blocks (exit 1)"
grep -qE '^web_sweep_count: 5\b' "$tmp_cap" \
  && note PASS "F2: counter persisted at 5 after over-cap increment" \
  || note FAIL "F2: over-cap increment did not persist counter"
rm -f "$tmp_cap"

# F2: increment fails closed when the counter line is absent (no silent create).
tmp_abs="$(mktemp)"; printf -- '---\nphase: 1\n---\n' > "$tmp_abs"
python3 "$SCRIPT" increment "$tmp_abs" >/dev/null 2>&1 \
  && note FAIL "F2: increment with absent counter should fail closed" \
  || note PASS "F2: increment with absent counter fails closed (exit 1)"
rm -f "$tmp_abs"

# F2: reset-sweep zeroes sweep, preserves session counter + comment.
tmp_rst="$(mktemp)"
printf -- '---\nweb_sweep_count: 4                   # c\nweb_search_count: 7\n---\n' > "$tmp_rst"
python3 "$SCRIPT" reset-sweep "$tmp_rst" >/dev/null 2>&1 \
  && note PASS "F2: reset-sweep returns ok" || note FAIL "F2: reset-sweep should return ok"
{ grep -qE '^web_sweep_count: 0\b' "$tmp_rst" && grep -qE '^web_search_count: 7\b' "$tmp_rst"; } \
  && note PASS "F2: reset-sweep zeroed sweep, kept session=7" \
  || note FAIL "F2: reset-sweep wrong result"
rm -f "$tmp_rst"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
