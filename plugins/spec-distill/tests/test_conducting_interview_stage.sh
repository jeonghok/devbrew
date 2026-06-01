#!/usr/bin/env bash
# AC3/AC7/AC8/AC13 + R1-R5 + PN1/PN3 — conducting-interview problem-space stage contract.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
has() { grep -qiE "$1" "$SKILL" && note PASS "$2" || note FAIL "$2"; }

grep -q '^cost_class: variable$' "$SKILL" && note PASS "cost_class: variable" || note FAIL "cost_class not variable"

has 'R1.*Reframe' "R1 Reframe ritual"
has 'R2.*Landscape' "R2 Landscape ritual"
has 'R3.*Skepticism' "R3 Skepticism ritual"
has 'R4.*시행착오|R4.*Tried' "R4 Tried-&-Discarded ritual"
has 'R5.*Open Question|R5.*OQ' "R5 Open-Questions ritual"

has 'check_brief\.py gate' "termination gate calls check_brief.py gate"
has '차단|block|종료.*금지|finalize.*안' "gate is blocking on failure"

has 'web_budget\.py' "web bound calls web_budget.py"
has 'web_budget\.py"? increment' "F2: web call increments counters before checking"
has 'web_budget\.py"? reset-sweep' "F2: sweep boundary calls reset-sweep"
has 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' "web kill switch documented (AC8)"
has 'web_sweep_count' "PN3: web_sweep_count counter in state"
has 'web_search_count' "PN3: web_search_count counter in state"
has 'steelman.*생략|web 비활성.*steelman' "F8: R3 web-absent loud degradation (AC8 symmetry)"

has 'steelman-builder' "steelman-builder dispatch"
has 'verbatim|약화.*금지|편집.*금지' "steelman verbatim pass-through (AC5)"

has 'docs/superpowers/interview/' "brief written under docs/superpowers/interview/ (C8)"
has 'interview-brief-template' "uses brief template"

has 'optional|선택' "brainstorming invoke is optional"
has 'superpowers.*(부재|없).*advisory|advisory.*superpowers' "AC13: superpowers-absent loud advisory"

has 'state_path\.py state-root|Bash.*state|state.*Bash' "PN1: state-write-via-Bash contract"

grep -q 'drafting-spec' "$SKILL" && note FAIL "AC10: drafting-spec still referenced" || note PASS "AC10: no drafting-spec reference"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
