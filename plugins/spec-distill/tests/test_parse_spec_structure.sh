#!/usr/bin/env bash
# Unit tests for parse_spec_structure.py library (CLI subcommand interface).
# Run: bash plugins/spec-distill/tests/test_parse_spec_structure.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/parse_spec_structure.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

pass=0
fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

echo "=== frontmatter subcommand ==="

# T3-1: valid frontmatter → exit 0 + JSON에 expected keys
out=$(python3 "$SCRIPT" frontmatter "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"name": "fixture-valid"' \
  && note PASS "valid frontmatter parsed (name)" \
  || note FAIL "valid frontmatter parse failed (rc=$rc out=$out)"

# T3-2: missing frontmatter (design mode case) → exit 0 + empty object
out=$(python3 "$SCRIPT" frontmatter "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '{}' \
  && note PASS "no frontmatter returns empty object" \
  || note FAIL "no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "=== sections subcommand ==="

# T4-1: spec-valid → no missing sections
out=$(python3 "$SCRIPT" sections "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"missing": \[\]' \
  && note PASS "valid spec has no missing sections" \
  || note FAIL "valid spec sections check failed (rc=$rc out=$out)"

# T4-2: spec-missing-goals → missing includes "#goals"
out=$(python3 "$SCRIPT" sections "$FIX/spec-missing-goals.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '#goals' \
  && note PASS "spec-missing-goals reports #goals as missing" \
  || note FAIL "missing-goals detection failed (rc=$rc out=$out)"

echo ""
echo "=== locked-decisions subcommand ==="

# T5-1: spec-valid → no errors (LD1만 있고 모든 sub-field 존재)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && note PASS "valid spec locked_decisions has no errors" \
  || note FAIL "valid locked_decisions check failed (rc=$rc out=$out)"

# T5-2: design-no-frontmatter → no errors (locked_decisions 부재 = 미적용, design mode에서 정상)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && note PASS "design-mode no-frontmatter has no errors" \
  || note FAIL "design no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "=== ambiguity subcommand ==="
BL="$REPO_ROOT/plugins/spec-distill/scripts/ambiguity-blacklist.txt"

# T6-1: spec-valid → no hits
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-valid.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "valid spec has no ambiguity hits" \
  || note FAIL "valid ambiguity scan failed (rc=$rc out=$out)"

# T6-2: spec-ambiguity-line12 → hit "works correctly" on line 12
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-ambiguity-line12.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q 'works correctly' \
  && echo "$out" | grep -q '"line": 12' \
  && note PASS "ambiguity hit detected on line 12" \
  || note FAIL "ambiguity-line12 detection failed (rc=$rc out=$out)"

# T6-3: spec-ambiguity-escaped → no hits (~ prefix excludes)
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-ambiguity-escaped.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "~escape prefix excludes from scan" \
  || note FAIL "escape syntax failed (rc=$rc out=$out)"

# T6-4 (단어경계, 완화 방향): 하이픈 복합어·접두 결합 안의 부분문자열은 hit되지 않는다.
tmp_wb="$(mktemp)"
printf '# t\n\nmerge with fast-forward; the loop is inefficient by design.\n' > "$tmp_wb"
out=$(python3 "$SCRIPT" ambiguity "$tmp_wb" "$BL" 2>&1)
echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "T6-4: 하이픈 복합어·접두 결합에서 오탐 없음" \
  || note FAIL "T6-4: 정상 기술 용어에서 발화 (out=$out)"

# T6-5 (반대 방향, 필수): 완화가 검사를 통째로 죽이지 않았다.
# 이 assert가 없으면 blacklist 매칭을 전부 제거해도 T6-4가 GREEN이다.
tmp_wp="$(mktemp)"
printf '# t\n\nthe result must be fast and the API robust.\n' > "$tmp_wp"
out=$(python3 "$SCRIPT" ambiguity "$tmp_wp" "$BL" 2>&1)
{ echo "$out" | grep -q '"phrase": "fast"' && echo "$out" | grep -q '"phrase": "robust"'; } \
  && note PASS "T6-5: 온전한 blacklist 단어는 계속 hit (검사가 살아 있다)" \
  || note FAIL "T6-5: 완화가 검사를 죽였다 (out=$out)"
rm -f "$tmp_wb" "$tmp_wp"

echo ""
echo "=== placeholders subcommand ==="

# T7-1: design-no-frontmatter → no hits
out=$(python3 "$SCRIPT" placeholders "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && note PASS "clean design has no placeholder hits" \
  || note FAIL "clean design placeholder scan failed (rc=$rc out=$out)"

# T7-2: design-tbd → TBD hit
out=$(python3 "$SCRIPT" placeholders "$FIX/design-tbd.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"token": "TBD"' \
  && note PASS "TBD placeholder detected" \
  || note FAIL "TBD placeholder detection failed (rc=$rc out=$out)"

echo ""
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
