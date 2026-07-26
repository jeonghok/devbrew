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
# AC1: 라운드별 잠금 producer 제거 — pending_locked_decisions는 사라지고 user_statements가 대체
grep -q 'pending_locked_decisions' "$SKILL" \
  && note FAIL "AC1: pending_locked_decisions가 SKILL에 잔존 (라운드별 잠금 producer)" \
  || note PASS "AC1: pending_locked_decisions 제거됨"
has 'user_statements' "AC1: user_statements가 state 스키마에 존재"
# AC5: 마이그레이션 — 구세션 감지 + fresh seed + advisory
has 'coverage.*부재|coverage 부재|interview_round.*존재' "AC5: legacy detection (interview_round present / coverage absent)"
has 'state schema migration.*coverage|coverage/probe_count added' "AC5: migration advisory wording"
mig_block="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ grep -qi 'probe_count' <<<"$mig_block" && grep -qiE '승계 금지|라운드 수는 probe 수가 아니' <<<"$mig_block"; } \
  && note PASS "AC5: probe_count seeded fresh (not from interview_round)" \
  || note FAIL "AC5: probe_count seeded fresh (not from interview_round)"

# Unbounded-autonomy backstop fail-open fix: migration must persist BEFORE the first probe/
# increment — probe_budget.py's increment/raise-cap fail-closed (exit 1) when the counter
# line is absent, and never silent-create it (GC-race safety). Deferring persistence to "the
# next explicit state write" leaves probe_count off disk while the backstop is bypassed.
grep -qE '첫 probe.*먼저' <<<"$mig_block" \
  && note PASS "AC5/backstop: migration persists before first probe (scoped to In-flight state migration)" \
  || note FAIL "AC5/backstop: migration persists before first probe (scoped to In-flight state migration)"

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
has '8-section|8-섹션|8 섹션' "AC10: Step A가 8섹션 템플릿을 참조"

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
# C5 fail-open fix: 소비자가 increment의 fail-closed exit(1)를 반드시 확인해야 한다(web_budget:270
# 과 대칭). bare `increment "$STATE"`(exit 무시)면 카운터 부재 시 전진 못해 check가 영원히 통과 →
# 백스톱 무력(fail-open). teeth: 가드를 bare increment로 되돌리면 grep -F가 RED. "## probe 백스톱" 스코프.
grep -qF 'increment "$STATE" ||' <<<"$backstop_block" \
  && note PASS "C5: probe increment exit is checked (|| guard, scoped to probe 백스톱)" \
  || note FAIL "C5: probe increment exit is checked (|| guard, scoped to probe 백스톱)"
grep -qi 'increment 실패' <<<"$backstop_block" \
  && note PASS "C5: increment-fail loud advisory present (scoped to probe 백스톱)" \
  || note FAIL "C5: increment-fail loud advisory present (scoped to probe 백스톱)"
# 종료 로직에 interview_round 잔존 0 (AC9/V7b)
term_block="$(awk '/^## 종료/{f=1} f&&/^## [^종]/{exit} f' "$SKILL")"
grep -q 'interview_round' <<<"$term_block" \
  && note FAIL "AC9/V7b: interview_round in termination block" \
  || note PASS "AC9/V7b: no interview_round in termination logic"

# --- v0.22.0: teach-beat + blind-spot/coverage-mapper dispatch (AC6/AC7/AC8/AC9/C11/C12) ---

# teach-beat 섹션 (scoped — feedback_grep_lock_header_satisfiable teeth)
teach_block="$(awk '/^## teach-beat/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$teach_block" ]] && grep -qi 'teach-lite' <<<"$teach_block"; } \
  && note PASS "AC8: teach-beat section present (teach-lite)" \
  || note FAIL "AC8: teach-beat section present (teach-lite)"
grep -qE '≤1문장' <<<"$teach_block" \
  && note PASS "AC8: teach-lite size bound (<=1 sentence)" \
  || note FAIL "AC8: teach-lite size bound (<=1 sentence)"
{ grep -q 'teach-heavy' <<<"$teach_block" && grep -q '≥1' <<<"$teach_block" && grep -q 'URL' <<<"$teach_block"; } \
  && note PASS "AC8: teach-heavy needs >=1 URL" \
  || note FAIL "AC8: teach-heavy needs >=1 URL"
grep -qE '단정이 아닌 질문 형태|질문 형태' <<<"$teach_block" \
  && note PASS "C3: teach as question, not assertion" \
  || note FAIL "C3: teach as question, not assertion"
grep -qE '모델 판단|non-goal' <<<"$teach_block" \
  && note PASS "C12: firing time is model-judged, not mechanized" \
  || note FAIL "C12: firing time is model-judged, not mechanized"

# coverage-mapper dispatch (C11/AC7, scoped)
covmap_block="$(awk '/^## coverage-mapper dispatch/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$covmap_block" ]] && grep -q 'coverage-mapper' <<<"$covmap_block"; } \
  && note PASS "AC7: coverage-mapper dispatch section present" \
  || note FAIL "AC7: coverage-mapper dispatch section present"
grep -qE '연속 3 probe|no_progress' <<<"$covmap_block" \
  && note PASS "C11: coverage-mapper trigger (3 no-progress probes OR floor first transition)" \
  || note FAIL "C11: coverage-mapper trigger (3 no-progress probes OR floor first transition)"
grep -q 'coverage_mapper_last_probe' <<<"$covmap_block" \
  && note PASS "C11: redispatch bound via coverage_mapper_last_probe" \
  || note FAIL "C11: redispatch bound via coverage_mapper_last_probe"
grep -q 'advisory' <<<"$covmap_block" \
  && note PASS "C11: coverage-mapper output is advisory (orchestrator admits)" \
  || note FAIL "C11: coverage-mapper output is advisory (orchestrator admits)"

# blind-spot-prober dispatch (AC6/C8, scoped)
blindspot_block="$(awk '/^## blind-spot-prober dispatch/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$blindspot_block" ]] && grep -q 'blind-spot-prober' <<<"$blindspot_block"; } \
  && note PASS "AC6: blind-spot-prober dispatch section present" \
  || note FAIL "AC6: blind-spot-prober dispatch section present"
grep -qE 'open→in-progress' <<<"$blindspot_block" \
  && note PASS "AC6: dispatch on blind_spot floor's first open→in-progress transition" \
  || note FAIL "AC6: dispatch on blind_spot floor's first open→in-progress transition"
grep -qE 'fan-out 1|인터뷰당 1회' <<<"$blindspot_block" \
  && note PASS "C8: fan-out 1 (blind_spot_dispatched guard)" \
  || note FAIL "C8: fan-out 1 (blind_spot_dispatched guard)"
grep -q 'blind_spot_dispatched' <<<"$blindspot_block" \
  && note PASS "C8: blind_spot_dispatched guard referenced" \
  || note FAIL "C8: blind_spot_dispatched guard referenced"
grep -qE 'web 비활성|inline premortem' <<<"$blindspot_block" \
  && note PASS "C5: web-absent loud degrade to inline premortem" \
  || note FAIL "C5: web-absent loud degrade to inline premortem"

# rhythm-guard 재프레임 (AC9, scoped)
rhythm_block="$(awk '/^## C44 Dialectic Rhythm Guard/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
grep -qE '직전 N probe|N probe 동안' <<<"$rhythm_block" \
  && note PASS "AC9: rhythm-guard streak reframed to probe-based" \
  || note FAIL "AC9: rhythm-guard streak reframed to probe-based"
grep -qi 'round' <<<"$rhythm_block" \
  && note FAIL "AC9: rhythm-guard no longer references round" \
  || note PASS "AC9: rhythm-guard no longer references round"

# R3 트리거 용어 교체 + §6 OQ → §8 OQ (scoped)
r3_block="$(awk '/^### R3 — Steelman/{f=1;print;next} /^### /{f=0} /^## /{f=0} f' "$SKILL")"
grep -q 'coverage-mapper neglect' <<<"$r3_block" \
  && note PASS "R3: trigger term breadth-keeper tunneling replaced by coverage-mapper neglect" \
  || note FAIL "R3: trigger term breadth-keeper tunneling replaced by coverage-mapper neglect"
grep -q '§6 OQ' <<<"$r3_block" \
  && note FAIL "R3: stale §6 OQ reference removed (should be §8 OQ)" \
  || note PASS "R3: stale §6 OQ reference removed (should be §8 OQ)"
[[ "$(grep -c '§8 OQ' <<<"$r3_block")" -ge 2 ]] \
  && note PASS "R3: §8 OQ reference present (x2)" \
  || note FAIL "R3: §8 OQ reference present (x2)"

# C45 interview_round>=2 트리거가 제거됐는지 (AC7)
grep -q 'interview_round >= 2\|interview_round>=2' "$SKILL" \
  && note FAIL "AC7: C45 interview_round>=2 trigger still present" \
  || note PASS "AC7: interview_round>=2 dispatch trigger replaced by C11"

# breadth-keeper 용어 잔존 0 (SKILL 본문, AC7/V7a)
grep -qi 'breadth-keeper\|breadth_keeper' "$SKILL" \
  && note FAIL "V7a: breadth-keeper term remains in SKILL" \
  || note PASS "V7a: breadth-keeper term removed from SKILL"

# interview_round confinement — migration section only (SHARP, Task 9 V9)
mig_ir_count="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL" | grep -c interview_round)"
total_ir_count="$(grep -c interview_round "$SKILL")"
[[ "$mig_ir_count" -eq "$total_ir_count" ]] \
  && note PASS "V9: interview_round confined to migration section (mig=$mig_ir_count total=$total_ir_count)" \
  || note FAIL "V9: interview_round confined to migration section (mig=$mig_ir_count total=$total_ir_count)"

# --- v0.23.0: 발화 기록 producer (AC1 positive, §8.2) ---
# 전-파일 grep은 헤더-satisfiable 함정에 걸린다(섹션 제목만 남겨도 통과) → awk 블록 스코프 +
# body-unique 문구로 잠근다. mutation: 아래 yaml 블록을 지우면 RED여야 한다.
stmt_block="$(awk '/^## 사용자 발화 기록/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$stmt_block" ]] && grep -q 'user_statements' <<<"$stmt_block"; } \
  && note PASS "AC1: 사용자 발화 기록 섹션이 user_statements 스키마를 담는다" \
  || note FAIL "AC1: 사용자 발화 기록 섹션에 user_statements 스키마가 없다"
{ grep -q 'id: S<N>' <<<"$stmt_block" && grep -qE 'source: verbatim' <<<"$stmt_block"; } \
  && note PASS "AC1: 발화 레코드가 id/source 필드를 명시" \
  || note FAIL "AC1: 발화 레코드 스키마(id: S<N> / source: verbatim)가 없다"
grep -qE 'status 필드는 없습니다|앵커도 없습니다' <<<"$stmt_block" \
  && note PASS "AC1: 라운드 중 status·해답공간 앵커 부재가 명시됨" \
  || note FAIL "AC1: status/앵커 부재 명시가 없다"

# agents 3종의 Input 절이 더 이상 locked_directions를 참조하지 않는다 (spec §7 누락 보강)
for a in blind-spot-prober steelman-builder coverage-mapper; do
  grep -q 'locked_directions' "$REPO_ROOT/plugins/spec-distill/agents/$a.md" \
    && note FAIL "AC13: agents/$a.md가 locked_directions를 참조" \
    || note PASS "AC13: agents/$a.md에 locked_directions 없음"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
