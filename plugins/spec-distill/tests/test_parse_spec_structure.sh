#!/usr/bin/env bash
# Unit tests for parse_spec_structure.py library (CLI subcommand interface).
# Run: bash plugins/spec-distill/tests/test_parse_spec_structure.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/parse_spec_structure.py"
FIX="$REPO_ROOT/plugins/spec-distill/tests/fixtures"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

echo "=== frontmatter subcommand ==="

# T3-1: valid frontmatter → exit 0 + JSON에 expected keys
out=$(python3 "$SCRIPT" frontmatter "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"name": "fixture-valid"' \
  && ok "valid frontmatter parsed (name)" \
  || no "valid frontmatter parse failed (rc=$rc out=$out)"

# T3-2: missing frontmatter (design mode case) → exit 0 + empty object
out=$(python3 "$SCRIPT" frontmatter "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '{}' \
  && ok "no frontmatter returns empty object" \
  || no "no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "=== sections subcommand ==="

# T4-1: spec-valid → no missing sections
out=$(python3 "$SCRIPT" sections "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"missing": \[\]' \
  && ok "valid spec has no missing sections" \
  || no "valid spec sections check failed (rc=$rc out=$out)"

# T4-2: spec-missing-goals → missing includes "#goals"
out=$(python3 "$SCRIPT" sections "$FIX/spec-missing-goals.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '#goals' \
  && ok "spec-missing-goals reports #goals as missing" \
  || no "missing-goals detection failed (rc=$rc out=$out)"

echo ""
echo "=== locked-decisions subcommand ==="

# T5-1: spec-valid → no errors (LD1만 있고 모든 sub-field 존재)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/spec-valid.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && ok "valid spec locked_decisions has no errors" \
  || no "valid locked_decisions check failed (rc=$rc out=$out)"

# T5-2: design-no-frontmatter → no errors (locked_decisions 부재 = 미적용, design mode에서 정상)
out=$(python3 "$SCRIPT" locked-decisions "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"errors": \[\]' \
  && ok "design-mode no-frontmatter has no errors" \
  || no "design no-frontmatter case failed (rc=$rc out=$out)"

echo ""
echo "=== ambiguity subcommand ==="
BL="$REPO_ROOT/plugins/spec-distill/scripts/ambiguity-blacklist.txt"

# T6-1: spec-valid → no hits
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-valid.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && ok "valid spec has no ambiguity hits" \
  || no "valid ambiguity scan failed (rc=$rc out=$out)"

# T6-2: spec-ambiguity-line12 → hit "works correctly" on line 12
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-ambiguity-line12.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q 'works correctly' \
  && echo "$out" | grep -q '"line": 12' \
  && ok "ambiguity hit detected on line 12" \
  || no "ambiguity-line12 detection failed (rc=$rc out=$out)"

# T6-3: spec-ambiguity-escaped → no hits (~ prefix excludes)
out=$(python3 "$SCRIPT" ambiguity "$FIX/spec-ambiguity-escaped.md" "$BL" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && ok "~escape prefix excludes from scan" \
  || no "escape syntax failed (rc=$rc out=$out)"

# T6-4 (단어경계, 완화 방향): 하이픈 복합어·접두 결합 안의 부분문자열은 hit되지 않는다.
tmp_wb="$(mktemp)"
printf '# t\n\nmerge with fast-forward; the loop is inefficient by design.\n' > "$tmp_wb"
out=$(python3 "$SCRIPT" ambiguity "$tmp_wb" "$BL" 2>&1)
echo "$out" | grep -q '"hits": \[\]' \
  && ok "T6-4: 하이픈 복합어·접두 결합에서 오탐 없음" \
  || no "T6-4: 정상 기술 용어에서 발화 (out=$out)"

# T6-5 (반대 방향, 필수): 완화가 검사를 통째로 죽이지 않았다.
# 이 assert가 없으면 blacklist 매칭을 전부 제거해도 T6-4가 GREEN이다.
tmp_wp="$(mktemp)"
printf '# t\n\nthe result must be fast and the API robust.\n' > "$tmp_wp"
out=$(python3 "$SCRIPT" ambiguity "$tmp_wp" "$BL" 2>&1)
{ echo "$out" | grep -q '"phrase": "fast"' && echo "$out" | grep -q '"phrase": "robust"'; } \
  && ok "T6-5: 온전한 blacklist 단어는 계속 hit (검사가 살아 있다)" \
  || no "T6-5: 완화가 검사를 죽였다 (out=$out)"

# T6-6 (굴절형, 필수): 완화가 **접미 굴절형까지** 죽이지 않았다.
# T6-4/T6-5만으로는 이 방향이 측정되지 않는다 — 둘 다 blacklist 어간이 *단어
# 그대로* 등장하는 경우만 본다. 경계를 양쪽 다 `(?![\w-])`로 잡으면 T6-4·T6-5는
# GREEN인 채 `efficiently`/`seamlessly`/`Robustness`/`faster`가 전부 통과해
# Law 1 게이트의 검출력이 조용히 무너진다(2026-08-05 라운드 3 실측).
# 경계는 비대칭이어야 한다: 앞은 단어·하이픈 금지, 뒤는 **하이픈만** 금지.
tmp_infl="$(mktemp)"
printf '# t\n\nIt is seamlessly integrated, runs efficiently, and Robustness is faster.\n' > "$tmp_infl"
out=$(python3 "$SCRIPT" ambiguity "$tmp_infl" "$BL" 2>&1)
{ echo "$out" | grep -q '"phrase": "seamless"' \
  && echo "$out" | grep -q '"phrase": "efficient"' \
  && echo "$out" | grep -q '"phrase": "robust"' \
  && echo "$out" | grep -q '"phrase": "fast"'; } \
  && ok "T6-6: 접미 굴절형(-ly/-ness/-er)도 계속 hit" \
  || no "T6-6: 굴절형 검출이 죽었다 — 경계가 뒤쪽 단어문자까지 막고 있다 (out=$out)"
rm -f "$tmp_wb" "$tmp_wp" "$tmp_infl"

echo ""
echo "=== placeholders subcommand ==="

# T7-1: design-no-frontmatter → no hits
out=$(python3 "$SCRIPT" placeholders "$FIX/design-no-frontmatter.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"hits": \[\]' \
  && ok "clean design has no placeholder hits" \
  || no "clean design placeholder scan failed (rc=$rc out=$out)"

# T7-2: design-tbd → TBD hit
out=$(python3 "$SCRIPT" placeholders "$FIX/design-tbd.md" 2>&1)
rc=$?
[[ $rc -eq 0 ]] && echo "$out" | grep -q '"token": "TBD"' \
  && ok "TBD placeholder detected" \
  || no "TBD placeholder detection failed (rc=$rc out=$out)"
finish
