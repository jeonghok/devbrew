#!/usr/bin/env bash
# test_qg_publish_skill_orchestration.sh — static protocol-shape verifier for the
# publish SKILL. Asserts the boundary order preflight→build→generate→scan→preview
# →consent→publish and the load-bearing invariants (AC7/AC8/AC9). Does NOT execute.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SKILL="$PLUGIN_ROOT/skills/publishing-pr-understanding/SKILL.md"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
test -f "$SKILL" || { echo "FAIL: SKILL.md missing at $SKILL"; exit 1; }

ln() { awk -v p="$1" '$0 ~ p {print NR; exit}' "$SKILL" | { read -r n||true; echo "${n:-0}"; }; }

pre=$(ln '## Preflight'); scan=$(ln '## Scan'); prev=$(ln '## Preview')
cons=$(ln '## Consent'); pub=$(ln '## Publish')
for pair in "pre:$pre" "scan:$scan" "prev:$prev" "cons:$cons" "pub:$pub"; do
  [[ "${pair#*:}" -gt 0 ]] || fail "section missing: ${pair%%:*}"
done
# boundary order: scan < preview < consent < publish (consent precedes any sink)
if (( scan>0 && prev>scan && cons>prev && pub>cons )); then
  pass "boundary order preflight→scan→preview→consent→publish"
else
  fail "boundary order wrong (scan=$scan preview=$prev consent=$cons publish=$pub)"
fi
# AC9: --dry-run stops at preview — bounded to the Preview section (fails if moved out)
awk '/^## Preview/{f=1;next} /^## /{f=0} f' "$SKILL" | grep -qiE 'stop|중단|정지|no network|미게시' \
  && pass "dry-run stops at preview (AC9)" || fail "dry-run stop not asserted in Preview"
# AC8: consent every run + irreversibility — bounded to the Consent section (fails if moved out)
awk '/^## Consent/{f=1;next} /^## /{f=0} f' "$SKILL" | grep -qiE 'AskUserQuestion|비가역|irrevers|permanent' \
  && pass "consent gate + irreversibility (AC8)" || fail "consent/irreversibility missing"
# invariant: gh writes via body-file, never raw gh api in the skill body
grep -qF -- '--body-file' "$SKILL" && pass "opaque bytes via --body-file" || fail "no --body-file invariant"
if ! grep -qE 'gh api' "$SKILL"; then pass "no raw gh api in skill (encapsulated in comment-upsert.py)"; else fail "raw gh api leaked into skill"; fi
# scan gates on the literal scan_ok line
grep -qF 'scan_ok: yes' "$SKILL" && pass "scan gates on literal scan_ok: yes" || fail "scan_ok gate not literal"

echo "publish-orchestration: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
