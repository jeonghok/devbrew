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

# --- v0.13.0: Step B /compact proceed 게이트 (AC20/AC21/AC22) ---
has 'AskUserQuestion' "AC20: Step B proceed gate uses AskUserQuestion"
has '/compact 후 brainstorming' "AC20: option ① label (/compact 후 brainstorming)"
has '바로 brainstorming' "AC20: option ② label (바로 brainstorming)"
has 'brief만 종료' "AC20: option ③ label (brief만 종료)"
has '/compact interview brief at' "AC20: verbatim /compact command exposed"

# AC21(i) mechanical only — review layer (ii) coexistence judgment = spec-reviewer persona
cc=$(grep -cE "턴 종료|다음 턴" "$SKILL"); [[ "$cc" -ge 1 ]] \
  && note PASS "AC21(i): cross-compact stop wording present (lines=$cc)" \
  || note FAIL "AC21(i): cross-compact stop wording absent"

has 'polite[- ]?stop|narrate.*금지|silent 종료 금지' "AC22: AP2 polite-stop ban codified"

has 'state_path\.py state-root|Bash.*state|state.*Bash' "PN1: state-write-via-Bash contract"

grep -q 'drafting-spec' "$SKILL" && note FAIL "AC10: drafting-spec still referenced" || note PASS "AC10: no drafting-spec reference"

# --- v0.22.0: 커버리지 상태 스키마 + 마이그레이션 (AC1/AC5) ---
has 'coverage:' "AC1: coverage ledger in state schema"
has 'probe_count' "AC1: probe_count counter in state schema"
has 'probe_cap_override' "AC1: probe_cap_override in state schema"
has 'no_progress_streak' "AC1: orchestration.no_progress_streak in schema"
has 'blind_spot_dispatched' "AC1: orchestration.blind_spot_dispatched in schema"
has 'coverage_mapper_last_probe' "AC1: orchestration.coverage_mapper_last_probe in schema"
# AC1: 기존 필드 보존
has 'non_user_streak' "AC1: non_user_streak retained"
has 'pending_locked_decisions' "AC1: pending_locked_decisions retained"
# AC5: 마이그레이션 — 구세션 감지 + fresh seed + advisory
has 'coverage.*부재|coverage 부재|interview_round.*존재' "AC5: legacy detection (interview_round present / coverage absent)"
has 'state schema migration.*coverage|coverage/probe_count added' "AC5: migration advisory wording"
mig_block="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ grep -qi 'probe_count' <<<"$mig_block" && grep -qiE '승계 금지|라운드 수는 probe 수가 아니' <<<"$mig_block"; } \
  && note PASS "AC5: probe_count seeded fresh (not from interview_round)" \
  || note FAIL "AC5: probe_count seeded fresh (not from interview_round)"

# state 스키마 블록(첫 yaml)에서 interview_round가 능동 필드로 남지 않았는지 (V7b)
# — 마이그레이션 섹션의 언급은 허용, 스키마 선언은 금지.
schema_block="$(awk '/^State frontmatter schema:/{f=1} f&&/^```yaml/{y=1;next} y&&/^```/{exit} y' "$SKILL")"
grep -q 'interview_round' <<<"$schema_block" \
  && note FAIL "V7b: interview_round still an active schema field" \
  || note PASS "V7b: interview_round removed from active state schema"

# --- v0.22.0: 커버리지 종료 루프 + probe 백스톱 (G1/AC2/AC4/C1/C10) ---
has 'probe_budget\.py' "AC4: probe backstop calls probe_budget.py"
has 'probe_budget\.py"? check' "C10: check gate before posing a probe"
has 'probe_budget\.py"? increment' "C10: increment after posing a probe"
has 'probe_budget\.py"? raise-cap' "C1: raise-cap on '계속' escalation"
has 'floor.*(closed|전부.*closed|모두.*closed)' "G1/AC2: termination = floor all closed"
has 'Coverage Ledger' "AC2/C9: brief Coverage Ledger serialization"
has '9-section|9-섹션|9 섹션' "AC10: Step A references 9-section template"

# AskUserQuestion 및 3옵션 어휘(박제/abort/계속)는 이미 Step B 핸드오프 게이트·kill switch
# 안내에도 등장 — 전-파일 grep은 새 probe 백스톱 섹션이 없어도 satisfied돼 teeth가 없다
# (feedback_grep_lock_header_satisfiable). "## probe 백스톱" 섹션으로 스코프.
backstop_block="$(awk '/^## probe 백스톱/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
grep -qi 'AskUserQuestion' <<<"$backstop_block" \
  && note PASS "AC4: cap escalation uses AskUserQuestion (scoped to probe 백스톱)" \
  || note FAIL "AC4: cap escalation uses AskUserQuestion (scoped to probe 백스톱)"
{ grep -q '계속' <<<"$backstop_block" && grep -qi '박제' <<<"$backstop_block" && grep -qi 'abort' <<<"$backstop_block"; } \
  && note PASS "C1: 3-option escalation semantics (계속/박제/abort, scoped to probe 백스톱)" \
  || note FAIL "C1: 3-option escalation semantics (계속/박제/abort, scoped to probe 백스톱)"
# 종료 로직에 interview_round 잔존 0 (AC9/V7b)
term_block="$(awk '/^## 종료/{f=1} f&&/^## [^종]/{exit} f' "$SKILL")"
grep -q 'interview_round' <<<"$term_block" \
  && note FAIL "AC9/V7b: interview_round in termination block" \
  || note PASS "AC9/V7b: no interview_round in termination logic"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
