#!/usr/bin/env bash
# AC3/AC7/AC8/AC13 + R1-R5 + PN1/PN3 — conducting-interview problem-space stage contract.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"
# Task 32(무게 감축): `## 종료` 절차 전문이 references/finishing.md 로 분리됐다. 이 스위트의
# 전-파일 검사(존재·**부재** 양쪽)가 보는 범위는 614줄 중 396줄로 줄었다 — 부재 락은 코퍼스가
# 줄어도 RED 가 되지 않고 **조용히 약해진다**(Task 31 이 정확히 이 방식으로 P21 스캔을 잃었다).
# 그래서 스킬의 표면을 **열거가 아니라 도출**해 한 덩어리로 다룬다: 새 참조 파일이 생겨도
# 자동으로 대상이 된다. 섹션 윈도우(B-0…B-3·종료)는 그 섹션이 실제로 사는 $FIN 에서 뜬다.
FIN_DIR="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/references"
FIN="$FIN_DIR/finishing.md"
CI_FILES=("$SKILL")
while IFS= read -r _f; do [ -n "$_f" ] && CI_FILES+=("$_f"); done < <(ls "$FIN_DIR"/*.md 2>/dev/null)
# Task 33: 두 skill 이 **공유**하는 절차(proceed 게이트 공통 계약)는 어느 skill 밑도 아닌
# 플러그인 레벨 `plugins/spec-distill/references/*.md` 로 갔다. 그 자리는 이 스킬의 표면
# 이면서(포인터로 가리키고 Read 하므로) 위 두 글롭 어디에도 안 든다.
#
# 두 배열을 나눈다:
#  - `CI_FILES`  = 이 skill **자신의** 표면. **존재(presence)** 검사는 여기서만 재야 한다 —
#    공유 계약 파일까지 넣으면 "이 skill 이 자기 어휘를 잃었다"를 공유 파일이 대신 만족시킨다
#    (§4 거울 클래스: 포인터/공유 파일이 presence 락을 header-satisfiable 하게 만든다).
#  - `CI_ALL`    = 자신의 표면 + 공유 계약. **부재(absence)** 검사는 여기서 재야 한다 —
#    금지 토큰이 공유 파일로 새 들어오는 것을 놓치면 락이 조용히 약해진다.
PLUGIN_REF_DIR="$REPO_ROOT/plugins/spec-distill/references"
CI_ALL=("${CI_FILES[@]}")
n_plugin_ref=0
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  CI_ALL+=("$_f"); n_plugin_ref=$((n_plugin_ref + 1))
done < <(ls "$PLUGIN_REF_DIR"/*.md 2>/dev/null)
ci_cat_all() { cat "${CI_ALL[@]}"; }

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/presence_corpus.sh"

# vacuity: 도출이 SKILL.md 하나만 남기면 이 스위트의 부재 락은 분할 이전 범위로 조용히
# 되돌아가면서 GREEN 을 찍는다. '참조 파일 0건'을 '문제 없음'으로 읽지 않는다.
[[ "${#CI_FILES[@]}" -ge 2 ]] \
  && ok "코퍼스: conducting-interview 표면 ${#CI_FILES[@]}개 파일 도출 (vacuous 아님)" \
  || no "코퍼스: references/*.md 를 0건 도출했다 — 전-파일 검사 범위가 조용히 좁아졌다"
[[ -f "$FIN" ]] && ok "코퍼스: references/finishing.md 실재" || no "코퍼스: references/finishing.md 부재"

# presence 코퍼스 소유 규칙 — 공용 단언(`shared/tests/presence_corpus.sh`).
# 이 계약을 재는 스캔은 전부 같은 규칙을 지고, 그래서 사본이 아니라 한 벌이다
# (감사문서 「공유 참조 파일」 절 · 정본 「앵커는 각 skill 에」 절).
assert_presence_corpus_skill_owned "CI_FILES" "${CI_FILES[@]}"
# 플러그인 레벨 도출. 0 자체는 정당한 상태지만, 디렉터리가 **있는데** 0이면 글롭이 깨진
# 것이다 — CI_ALL 이 CI_FILES 로 조용히 축소되고 아래 부재 검사가 그만큼 약해진다.
if [[ -d "$PLUGIN_REF_DIR" ]]; then
  [[ "$n_plugin_ref" -ge 1 ]] \
    && ok "코퍼스: 플러그인 레벨 references/*.md ${n_plugin_ref}건 도출 (부재 검사 범위)" \
    || no "코퍼스: $PLUGIN_REF_DIR 는 있는데 도출이 0건 — 부재 검사 범위가 조용히 좁아졌다"
fi

# 존재·부재 검사는 **스킬 표면 전체**를 본다 (분할 전 단일 파일과 같은 의미).
has() { grep -qiE "$1" "${CI_FILES[@]}" && ok "$2" || no "$2"; }
# 여러 파일을 합친 스트림 — `grep -c` 는 파일마다 한 줄을 내므로 합산에는 쓸 수 없다.
ci_cat() { cat "${CI_FILES[@]}"; }

grep -q '^cost_class: variable$' "$SKILL" && ok "cost_class: variable" || no "cost_class not variable"

has 'R1.*Reframe' "R1 Reframe ritual"
has 'R2.*Landscape' "R2 Landscape ritual"
has 'R3.*Skepticism' "R3 Skepticism ritual"
has 'R4.*시행착오|R4.*Tried' "R4 Tried-&-Discarded ritual"
has 'R5.*Open Question|R5.*OQ' "R5 Open-Questions ritual"

has 'check_brief\.py gate' "termination gate calls check_brief.py gate"
has '차단|block|종료.*금지|finalize.*안' "gate is blocking on failure"

has 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' "web kill switch documented (AC8)"
has 'steelman.*생략|web 비활성.*steelman' "F8: R3 web-absent loud degradation (AC8 symmetry)"

has 'steelman-builder' "steelman-builder dispatch"
has 'verbatim|약화.*금지|편집.*금지' "steelman verbatim pass-through (AC5)"

has 'docs/superpowers/interview/' "brief written under docs/superpowers/interview/ (C8)"
has 'interview-brief-template' "uses brief template"

has 'optional|선택' "brainstorming invoke is optional"
# AC13: superpowers 부재 시 graceful degradation (CLAUDE.md 필수 항목).
# 전-파일 grep은 이빨이 0이었다 — 이 패턴은 B-1 본문(:425)과 B-4 가드 산문(:502) **두 줄**에
# 매치돼서, B-1 블록을 통째로 지워도 B-4 줄이 남아 green이었다(header-satisfiable). 그래서
# B-0/B-2/B-3에 이미 쓰는 awk 윈도우 방식으로 **그 블록 안에서만** 찾고, 헤더가 아니라
# 본문에만 있는 문구(`crash·spec-mode fallback`)를 함께 요구한다.
b1_block="$(awk '/^#### B-1/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
{ printf '%s' "$b1_block" | grep -qE 'superpowers.*(부재|없).*advisory|advisory.*superpowers' \
    && printf '%s' "$b1_block" | grep -qF 'crash·spec-mode fallback'; } \
  && ok "AC13: superpowers-absent loud advisory (B-1 블록 스코프)" \
  || no "AC13: B-1 블록 안에 graceful-degradation 지시가 없다"

# --- v0.23.0: 확정 확인을 흡수한 단일 proceed 게이트 (AC2/AC3) ---
# 이 게이트를 전-파일 grep으로 잠그면 이빨이 0이다. 'AskUserQuestion'은 probe 백스톱 C1
# escalation에도 등장하고(이 스위트가 아래 :~176 주석에서 이미 지적한 함정 — 거기선
# backstop_block으로 스코프해 해결했다), 옵션 라벨 4종은 B-3의 bullet 제목이 verbatim
# 반복하므로 각각 2~3회 등장한다. 실측: B-2의 AskUserQuestion({…}) 블록을 통째로 지워도
# 5건 전부 GREEN이었다. → "#### B-2" 블록으로 스코프한다.
# 라벨은 grep -qE가 아니라 **grep -qF**로 잡는다: 한국어 조사와 마크다운 백틱이 정규식
# 경계를 조용히 깨뜨린 전례가 이 파일 안에 이미 있다(아래 강등 프로즈 락 주석 참조).
# 헤더-satisfiable 회피: B-2 헤더에 `AskUserQuestion`이 있으므로 여는 괄호까지 요구한다.
b2_block="$(awk '/^#### B-2/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
{ [[ -n "$b2_block" ]] && grep -qF 'AskUserQuestion(' <<<"$b2_block"; } \
  && ok "AC20: Step B proceed 게이트가 AskUserQuestion 호출 (B-2 스코프)" \
  || no "AC20: B-2 블록에 AskUserQuestion( 호출이 없다"
grep -qF '확정하고 /compact 후 brainstorming' <<<"$b2_block" \
  && ok "AC2: 옵션 ① 라벨 (확정 + /compact, B-2 스코프)" \
  || no "AC2: 옵션 ① 라벨이 B-2 게이트에 없다"
grep -qF '확정하고 바로 brainstorming' <<<"$b2_block" \
  && ok "AC2: 옵션 ② 라벨 (확정 + 즉시, B-2 스코프)" \
  || no "AC2: 옵션 ② 라벨이 B-2 게이트에 없다"
grep -qF '확정 목록 수정' <<<"$b2_block" \
  && ok "AC2: 옵션 ③ 라벨 (재제시, B-2 스코프)" \
  || no "AC2: 옵션 ③ 라벨이 B-2 게이트에 없다"
grep -qF 'brief만 종료' <<<"$b2_block" \
  && ok "AC20: 옵션 ④ 라벨 (terminal, B-2 스코프)" \
  || no "AC20: 옵션 ④ 라벨이 B-2 게이트에 없다"
# 이건 전-파일로 둔다 — SKILL 전체에서 1회뿐이라 이미 이빨이 있다.
has '/compact interview brief at' "AC20: verbatim /compact 명령 노출"

# AC2: 재제시 상한 + 초과 시 강등 + 고정 advisory 문자열 (Unbounded-autonomy 가드)
b0_block="$(awk '/^#### B-0/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
{ [[ -n "$b0_block" ]] && grep -q 'confirm_repost_count' <<<"$b0_block"; } \
  && ok "AC2: 재제시 카운터가 state에 기록됨 (프로즈 self-tracking 아님)" \
  || no "AC2: confirm_repost_count가 B-0 블록에 없다"
grep -qF '[spec-distill] 확정 확인 재제시 상한(2회) 초과 — 전 항목 provisional 강등' <<<"$b0_block" \
  && ok "AC2: 상한 초과 고정 advisory 문자열 (verbatim)" \
  || no "AC2: 상한 초과 advisory 문자열이 정확히 일치하지 않는다"
# 이 assert는 위 advisory 고정 문자열이 아니라 **강등 프로즈**를 잠근다. 원래 패턴
# ('전부 provisional|전 항목 .*provisional')은 프로즈(백틱·조사 때문에 불일치)가 아니라
# advisory 문자열에만 매치돼 바로 위 grep -qF에 포섭됐다 — 프로즈만 지워도 GREEN인 가짜 이빨.
# 아래 두 구절은 advisory 문자열에 등장하지 않는 body-unique 문구다: 강등 *동작*과 *방향 근거*.
# teeth: 프로즈만 삭제 → 이 assert만 RED / advisory만 삭제 → 위 assert만 RED (서로 독립).
{ grep -qF '전 항목을 `provisional`로 강등' <<<"$b0_block" \
  && grep -qF '확정이 덜 되는 쪽이 안전한 방향' <<<"$b0_block"; } \
  && ok "AC2: 상한 초과 시 덜-잠그는 쪽으로 강등 (프로즈 — advisory와 독립)" \
  || no "AC2: 강등 프로즈(전 항목 provisional 강등 + 덜 되는 쪽이 안전)가 없다"
grep -qE '제외한 것도|제외 항목' <<<"$b0_block" \
  && ok "AC2: 확정 후보에서 제외한 항목도 함께 제시 (누락 검출 가능)" \
  || no "AC2: 제외 항목 제시 요구가 없다"

# AC3: C4 재결정 프로토콜이 **양쪽 경로**의 호출 프롬프트에 실린다
b3_block="$(awk '/^#### B-3/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
# B-3 전체에서 count>=2를 세면 "①에 두 문장, ②에 0"도 통과한다 — AC3의 계약은 개수가 아니라
# **경로별 존재**다. 각 옵션 bullet을 자기 윈도우로 잘라 양쪽에 각각 >=1을 요구한다.
b3_opt1="$(awk '/^- \*\*① /{f=1} /^- \*\*② /{f=0} f' <<<"$b3_block")"
b3_opt2="$(awk '/^- \*\*② /{f=1} /^- \*\*③ /{f=0} f' <<<"$b3_block")"
c4_1=$(grep -cF '보고 후 재결정' <<<"$b3_opt1")
c4_2=$(grep -cF '보고 후 재결정' <<<"$b3_opt2")
{ [[ "$c4_1" -ge 1 ]] && [[ "$c4_2" -ge 1 ]]; } \
  && ok "AC3: C4 프로토콜이 ①/② 각 경로에 실림 (①=$c4_1 ②=$c4_2)" \
  || no "AC3: C4 프로토콜이 양쪽 경로에 있지 않다 (①=$c4_1 ②=$c4_2)"
grep -qE '임의 변경.*금지' <<<"$b3_block" \
  && ok "AC3: 임의 변경 금지 절반이 명시됨" || no "AC3: 임의 변경 금지가 없다"

# C5: 규약은 brief가 아니라 호출 프롬프트에 산다
grep -qE '호출 프롬프트|invocation prompt' <<<"$b3_block" \
  && ok "C5: 규약의 거처가 호출 프롬프트로 명시됨" \
  || no "C5: 규약이 brief에 실리지 않는다는 명시가 없다"

# AC21(i) mechanical only — review layer (ii) coexistence judgment = spec-reviewer persona
cc=$(ci_cat | grep -cE "턴 종료|다음 턴"); [[ "$cc" -ge 1 ]] \
  && ok "AC21(i): cross-compact stop wording present (lines=$cc)" \
  || no "AC21(i): cross-compact stop wording absent"

has 'polite[- ]?stop|narrate.*금지|silent 종료 금지' "AC22: AP2 polite-stop ban codified"

has 'state_path\.py state-root|Bash.*state|state.*Bash' "PN1: state-write-via-Bash contract"

grep -q 'drafting-spec' "${CI_ALL[@]}" && no "AC10: drafting-spec still referenced" || ok "AC10: no drafting-spec reference"

# --- v0.22.0: 커버리지 상태 스키마 + 마이그레이션 (AC1/AC5) ---
has 'coverage:' "AC1: coverage ledger in state schema"
has 'probe_count' "AC1: probe_count counter in state schema"
has 'probe_cap_override' "AC1: probe_cap_override in state schema"
has 'no_progress_streak' "AC1: orchestration.no_progress_streak in schema"
has 'blind_spot_dispatched' "AC1: orchestration.blind_spot_dispatched in schema"
# v0.37.0: probe 카운터를 지우면서 coverage-mapper 재dispatch 바운드가 함께 사라지지
# 않게 «에피소드» 단위로 이식한다. 재는 것은 **두 디스크 값의 비교**가 유지되는가다 —
# 값 하나(streak)를 저장하면 streak 3 에서 dispatch(저장 3) → 4 → `3 != 4` → 재dispatch
# → 5 → … 로 레벨-트리거 무한 재dispatch 가 되살아난다(현행 바운드가 명시적으로 막는 것).
has 'stall_episode' "C11(v0.37.0): orchestration.stall_episode in schema"
has 'coverage_mapper_dispatched_episode' "C11(v0.37.0): orchestration.coverage_mapper_dispatched_episode in schema"
# AC1: 기존 필드 보존
has 'non_user_streak' "AC1: non_user_streak retained"
# AC1: 라운드별 잠금 producer 제거 — pending_locked_decisions는 사라지고 user_statements가 대체
grep -q 'pending_locked_decisions' "${CI_ALL[@]}" \
  && no "AC1: pending_locked_decisions가 SKILL에 잔존 (라운드별 잠금 producer)" \
  || ok "AC1: pending_locked_decisions 제거됨"
has 'user_statements' "AC1: user_statements가 state 스키마에 존재"
# AC5: 마이그레이션 — 구세션 감지 + fresh seed + advisory
has 'coverage.*부재|coverage 부재|interview_round.*존재' "AC5: legacy detection (interview_round present / coverage absent)"
has 'state schema migration.*coverage|coverage/probe_count added' "AC5: migration advisory wording"
mig_block="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ grep -qi 'probe_count' <<<"$mig_block" && grep -qiE '승계 금지|라운드 수는 probe 수가 아니' <<<"$mig_block"; } \
  && ok "AC5: probe_count seeded fresh (not from interview_round)" \
  || no "AC5: probe_count seeded fresh (not from interview_round)"
# v0.37.0(R-I): migration 절도 orchestration 열거를 담고 있다 — 필드 교체를 소유한
# 태스크가 그 필드의 모든 자리를 책임진다. 음의 단언만 쓰지 않는다: `! grep -q
# 'coverage_mapper_last_probe'` 단독은 mig_block 이 통째로 사라져도 통과한다(부재 락은
# 대상을 지우면 항상 만족된다). 양의 두 grep 이 그 공허참을 막는다.
{ grep -q 'stall_episode' <<<"$mig_block" \
  && grep -q 'coverage_mapper_dispatched_episode' <<<"$mig_block" \
  && ! grep -q 'coverage_mapper_last_probe' <<<"$mig_block"; } \
  && ok "AC5(v0.37.0): migration 절의 orchestration 열거가 에피소드 필드 둘 (구 필드 없음)" \
  || no "AC5(v0.37.0): migration 절의 orchestration 열거가 에피소드 필드 둘 (구 필드 없음)"

# Unbounded-autonomy backstop fail-open fix: migration must persist BEFORE the first probe/
# increment — probe_budget.py's increment/raise-cap fail-closed (exit 1) when the counter
# line is absent, and never silent-create it (GC-race safety). Deferring persistence to "the
# next explicit state write" leaves probe_count off disk while the backstop is bypassed.
grep -qE '첫 probe.*먼저' <<<"$mig_block" \
  && ok "AC5/backstop: migration persists before first probe (scoped to In-flight state migration)" \
  || no "AC5/backstop: migration persists before first probe (scoped to In-flight state migration)"

# state 스키마 블록(첫 yaml)에서 interview_round가 능동 필드로 남지 않았는지 (V7b)
# — 마이그레이션 섹션의 언급은 허용, 스키마 선언은 금지.
schema_block="$(awk '/^State frontmatter schema:/{f=1} f&&/^```yaml/{y=1;next} y&&/^```/{exit} y' "$SKILL")"
grep -q 'interview_round' <<<"$schema_block" \
  && no "V7b: interview_round still an active schema field" \
  || ok "V7b: interview_round removed from active state schema"

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
  && ok "AC4: cap escalation uses AskUserQuestion (scoped to probe 백스톱)" \
  || no "AC4: cap escalation uses AskUserQuestion (scoped to probe 백스톱)"
{ grep -q '계속' <<<"$backstop_block" && grep -qi '박제' <<<"$backstop_block" && grep -qi 'abort' <<<"$backstop_block"; } \
  && ok "C1: 3-option escalation semantics (계속/박제/abort, scoped to probe 백스톱)" \
  || no "C1: 3-option escalation semantics (계속/박제/abort, scoped to probe 백스톱)"
# C5 fail-open fix: 소비자가 increment의 fail-closed exit(1)를 반드시 확인해야 한다(web_budget:270
# 과 대칭). bare `increment "$STATE"`(exit 무시)면 카운터 부재 시 전진 못해 check가 영원히 통과 →
# 백스톱 무력(fail-open). teeth: 가드를 bare increment로 되돌리면 grep -F가 RED. "## probe 백스톱" 스코프.
grep -qF 'increment "$STATE" ||' <<<"$backstop_block" \
  && ok "C5: probe increment exit is checked (|| guard, scoped to probe 백스톱)" \
  || no "C5: probe increment exit is checked (|| guard, scoped to probe 백스톱)"
grep -qi 'increment 실패' <<<"$backstop_block" \
  && ok "C5: increment-fail loud advisory present (scoped to probe 백스톱)" \
  || no "C5: increment-fail loud advisory present (scoped to probe 백스톱)"

# v0.37.0: probe cap 이 사라지면 그 escalation 의 3옵션도 함께 사라진다. 새 탈출구는
# 발동 조건만 다르고(카운터 → 사용자 발화) 존재해야 하는 것은 같다.
#
# **awk 윈도우로 스코프한다** — `박제` 어휘가 이 파일의 다른 절(probe 백스톱 · Step B 게이트
# 안내 · kill switch)에도 선재하므로 전-파일 grep 은 이 경로가 통째로 사라져도 satisfied 되어
# teeth 가 0 이다(feedback_grep_lock_header_satisfiable, 같은 파일의 backstop_block 이 같은
# 이유로 스코프됐다).
#
# **토큰 공존이 아니라 관계를 건다** (context §③ — Task4 의 coverage-mapper 락이 같은 형태로
# 거짓 GREEN 을 냈다: 세 토큰을 각각 독립 grep 하면, 처분(evidence 리터럴)·행선지(§3 이월
# 문장)를 지우고 산문만 남겨도 트리거·`박제`·`floor` 잔여 토큰이 흩어져 만족된다 — 실측,
# "사용자가 언제든 종료를 요청할 수 있고 floor 는 박제된다" 한 줄로 충분하다). 그래서 «단락»
# (빈 줄 경계) 하나로 더 좁힌다: `사용자-승인 박제` 리터럴과 `Open Questions` 행선지가 **같은
# 단락**에 있는 레코드만 추출하고, 그 단락 안에서 발동조건(사용자 발화)·`evidence`·박제
# 리터럴·행선지가 전부 있는지를 요구한다. 처분·행선지 문장이 지워지면 그 단락 자체가
# 더는 `사용자-승인 박제`+`Open Questions` 를 함께 갖지 않으므로 추출이 비고, 이하 grep 은
# 빈 문자열에 대해 전부 실패한다(M5b 가 이 경로를 잰다).
#
# **fix round 1**: 위 관계만으로는 "…§3 Open Questions 얘기는 다음에 한다" 처럼 행선지
# 리터럴만 인용하고 실제로 옮기지 않는 적대적 한 문장에 뚫린다(reviewer 재현) — `이월`류
# 이관 동사 없이 리터럴만 나열해도 «단락 하나» 조건은 만족되기 때문이다. 그래서 행선지를
# «단락» 이 아니라 **그 리터럴을 담은 문장 하나**(마침표 경계, 개행은 접어 문장이 줄바꿈에
# 끊기지 않게 한다)로 더 좁히고, 그 **같은 문장 안에서** 이관 동사(이월/옮기다/넘기다)를
# 요구한다 — 리터럴과 동사가 다른 문장에 따로 있으면(예: 딴 문단의 "…이월한다"가 무관한
# 문맥) 문장 경계가 그 결속을 끊는다.
exit_block="$(awk '/^## 종료 — brief 작성/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
mech_para="$(awk -v RS='' '/사용자-승인 박제/ && /Open Questions/' <<<"$exit_block")"
mech_flat="$(tr '\n' ' ' <<<"$mech_para")"
dest_sentence="$(grep -oE '[^.]*Open Questions[^.]*\.' <<<"$mech_flat" | head -1)"
# 트리거는 `mech_para`(처분·행선지가 사는 단락)가 아니라 `exit_block`(절 전체)에 건다 — 트리거
# 문장을 그 단락 안에 강제하면 "트리거를 별도 단락으로 뗀다" 같은 의미 보존 리라이트가 거짓
# RED가 된다(fix round1에서 실측). exit_block 자체가 이미 "## 종료" 하나로 좁혀져 있어
# 트리거 어휘가 무관한 절과 섞일 위험은 없다.
{ [[ -n "$mech_para" ]] \
  && grep -qE '사용자.*종료를 요청|사용자가 언제든 종료' <<<"$exit_block" \
  && grep -q 'evidence' <<<"$mech_para" \
  && grep -q '사용자-승인 박제' <<<"$mech_para" \
  && grep -qE '§3 Open Questions|## 3\. Open Questions|payload[^.]*Open Questions' <<<"$dest_sentence" \
  && grep -qE '이월|옮긴다|옮긴|넘긴다' <<<"$dest_sentence"; } \
  && ok "C1(v0.37.0): floor 탈출구 — 사용자 발화 → 미충족 floor 를 사용자-승인 박제 (트리거는 절 전체, 처분·행선지·이관동사는 단락·문장으로 결속, scoped to 종료)" \
  || no "C1(v0.37.0): floor 탈출구 — 사용자 발화 → 미충족 floor 를 사용자-승인 박제 (트리거는 절 전체, 처분·행선지·이관동사는 단락·문장으로 결속, scoped to 종료)"
# 종료 로직에 interview_round 잔존 0 (AC9/V7b)
term_block="$(awk '/^## 종료/{f=1} f&&/^## [^종]/{exit} f' "$FIN")"
grep -q 'interview_round' <<<"$term_block" \
  && no "AC9/V7b: interview_round in termination block" \
  || ok "AC9/V7b: no interview_round in termination logic"

# --- v0.22.0: teach-beat + blind-spot/coverage-mapper dispatch (AC6/AC7/AC8/AC9/C11/C12) ---

# teach-beat 섹션 (scoped — feedback_grep_lock_header_satisfiable teeth)
teach_block="$(awk '/^## teach-beat/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$teach_block" ]] && grep -qi 'teach-lite' <<<"$teach_block"; } \
  && ok "AC8: teach-beat section present (teach-lite)" \
  || no "AC8: teach-beat section present (teach-lite)"
grep -qE '≤1문장' <<<"$teach_block" \
  && ok "AC8: teach-lite size bound (<=1 sentence)" \
  || no "AC8: teach-lite size bound (<=1 sentence)"
{ grep -q 'teach-heavy' <<<"$teach_block" && grep -q '≥1' <<<"$teach_block" && grep -q 'URL' <<<"$teach_block"; } \
  && ok "AC8: teach-heavy needs >=1 URL" \
  || no "AC8: teach-heavy needs >=1 URL"
grep -qE '단정이 아닌 질문 형태|질문 형태' <<<"$teach_block" \
  && ok "C3: teach as question, not assertion" \
  || no "C3: teach as question, not assertion"
grep -qE '모델 판단|non-goal' <<<"$teach_block" \
  && ok "C12: firing time is model-judged, not mechanized" \
  || no "C12: firing time is model-judged, not mechanized"

# coverage-mapper dispatch (C11/AC7, scoped)
covmap_block="$(awk '/^## coverage-mapper dispatch/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$covmap_block" ]] && grep -q 'coverage-mapper' <<<"$covmap_block"; } \
  && ok "AC7: coverage-mapper dispatch section present" \
  || no "AC7: coverage-mapper dispatch section present"
grep -qE '연속 3 probe|no_progress' <<<"$covmap_block" \
  && ok "C11: coverage-mapper trigger (3 no-progress probes OR floor first transition)" \
  || no "C11: coverage-mapper trigger (3 no-progress probes OR floor first transition)"
# 스코프가 필수다 — `stall_episode` 는 State schema 절에도 등장하므로 전-파일 grep 은
# 이 절이 통째로 사라져도 satisfied 된다(feedback_grep_lock_header_satisfiable).
# 토큰 co-occurrence(각각 grep -q)는 이빨이 없다 — 이 절 본문은 두 필드 이름을 두 번
# 이상 언급하고(대입문 · 설명문) `!=`도 무관한 예시("3 != 4")에 따로 등장해, 조건식을
# 지워도(mutation M1) 흩어진 잔여 토큰만으로 satisfied된다(실측, fix round 1 이전 실패
# 모드). **같은 줄에서 `!=`로 이어지는지**만 보는 것도 부족하다 — AND -> OR 재배치는
# `!=` 페어를 그대로 두고 논리 접속사만 바꾸므로 밀도 게이트(연속 3 probe)가 사라지는데도
# `!=` 페어 단독 검사는 통과시킨다(fix round 1 Important 1, reviewer 재현). 그래서
# **관계 전체**(임계값 `no_progress_streak >= 3` · 논리 접속사 `AND` · 비교 `!=` 페어)를
# 하나의 정규식으로 묶는다.
#
# 동시에 줄바꿈에는 관대해야 한다(fix round 1 Minor 1) — 조건식은 backtick 인라인 코드
# 스팬 하나 안에 있고, 그 안에서 줄이 바뀌어도(rewrap) 의미는 그대로다. 그래서 절 본문을
# 줄 단위로 grep하지 않고 backtick 페어로 구획을 나눠 **각 코드 스팬 안의 개행만** 공백으로
# 접는다(그 스팬 밖 줄바꿈은 건드리지 않는다) — 조임(관계 전체)과 관대함(레이아웃)을
# 맞바꾸지 않는다.
code_spans="$(awk 'BEGIN{RS="`"} NR%2==0{gsub(/\n/," "); print}' <<<"$covmap_block")"
{ grep -qE 'no_progress_streak[[:space:]]*>=[[:space:]]*3[[:space:]]+AND[[:space:]]+coverage_mapper_dispatched_episode[[:space:]]*!=[[:space:]]*stall_episode' <<<"$code_spans" \
  || grep -qE 'coverage_mapper_dispatched_episode[[:space:]]*!=[[:space:]]*stall_episode[[:space:]]+AND[[:space:]]+no_progress_streak[[:space:]]*>=[[:space:]]*3' <<<"$code_spans"; } \
  && ok "C11(v0.37.0): 재dispatch 바운드가 «임계값 AND 에피소드 비교» 관계 전체 (scoped, rewrap-tolerant)" \
  || no "C11(v0.37.0): 재dispatch 바운드가 «임계값 AND 에피소드 비교» 관계 전체 (scoped, rewrap-tolerant)"
# 조건 2 의 «유한성 근거» — 이것이 없으면 그 조건이 «바운드 밖»인지 «바운드 불필요»인지
# 구별되지 않는다. 지금까지 어디에도 없었다.
grep -qE 'floor 다섯 차원으로 고정|상한이 5' <<<"$covmap_block" \
  && ok "C11(v0.37.0): 조건 2 의 유한성 근거 명시" \
  || no "C11(v0.37.0): 조건 2 의 유한성 근거 명시"
grep -q 'advisory' <<<"$covmap_block" \
  && ok "C11: coverage-mapper output is advisory (orchestrator admits)" \
  || no "C11: coverage-mapper output is advisory (orchestrator admits)"

# blind-spot-prober dispatch (AC6/C8, scoped)
blindspot_block="$(awk '/^## blind-spot-prober dispatch/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$blindspot_block" ]] && grep -q 'blind-spot-prober' <<<"$blindspot_block"; } \
  && ok "AC6: blind-spot-prober dispatch section present" \
  || no "AC6: blind-spot-prober dispatch section present"
grep -qE 'open→in-progress' <<<"$blindspot_block" \
  && ok "AC6: dispatch on blind_spot floor's first open→in-progress transition" \
  || no "AC6: dispatch on blind_spot floor's first open→in-progress transition"
grep -qE 'fan-out 1|인터뷰당 1회' <<<"$blindspot_block" \
  && ok "C8: fan-out 1 (blind_spot_dispatched guard)" \
  || no "C8: fan-out 1 (blind_spot_dispatched guard)"
grep -q 'blind_spot_dispatched' <<<"$blindspot_block" \
  && ok "C8: blind_spot_dispatched guard referenced" \
  || no "C8: blind_spot_dispatched guard referenced"
grep -qE 'web 비활성|inline premortem' <<<"$blindspot_block" \
  && ok "C5: web-absent loud degrade to inline premortem" \
  || no "C5: web-absent loud degrade to inline premortem"

# rhythm-guard 재프레임 (AC9, scoped)
rhythm_block="$(awk '/^## C44 Dialectic Rhythm Guard/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
grep -qE '직전 N probe|N probe 동안' <<<"$rhythm_block" \
  && ok "AC9: rhythm-guard streak reframed to probe-based" \
  || no "AC9: rhythm-guard streak reframed to probe-based"
grep -qi 'round' <<<"$rhythm_block" \
  && no "AC9: rhythm-guard no longer references round" \
  || ok "AC9: rhythm-guard no longer references round"

# R3 트리거 용어 교체 + OQ 좌표 (scoped)
# v0.23.0: payload가 9섹션 → 8섹션(§0–§7)이 되면서 OQ 좌표가 §8 → §3으로 이동했다.
# 락도 새 좌표를 겨눈다 — 부정은 은퇴 좌표 §8(및 v0.22.0의 §6)을, 긍정은 §3을 잡는다.
r3_block="$(awk '/^### R3 — Steelman/{f=1;print;next} /^### /{f=0} /^## /{f=0} f' "$SKILL")"
grep -q 'coverage-mapper neglect' <<<"$r3_block" \
  && ok "R3: trigger term breadth-keeper tunneling replaced by coverage-mapper neglect" \
  || no "R3: trigger term breadth-keeper tunneling replaced by coverage-mapper neglect"
grep -qE '§[68] OQ' <<<"$r3_block" \
  && no "R3: 은퇴 OQ 좌표(§6/§8) 잔존 (should be §3 OQ)" \
  || ok "R3: 은퇴 OQ 좌표(§6/§8) 제거됨 (should be §3 OQ)"
[[ "$(grep -c '§3 OQ' <<<"$r3_block")" -ge 2 ]] \
  && ok "R3: §3 OQ reference present (x2)" \
  || no "R3: §3 OQ reference present (x2)"

# E10 (오케스트레이터 미러) — R3 dispatch 지시에 병렬·투기적 금지 문구 부재.
# steelman-builder.md 에이전트 persona에서 삭제한 것과 같은 억제가 이 SKILL의 dispatch
# 지시문에도 있었다(C5/AP9 인용 둘 다 근거 없음 — fix round 1). 전-파일 grep은 잘못이다:
# :122 'teach-beat 최대 1회'와 :438 '2회까지'가 이 SKILL에 legitimately 남아있으므로
# "$r3_block"(위에서 정의한 R3 섹션 윈도우)으로 스코프한다.
grep -qE '병렬.{0,8}금지|투기적.{0,8}금지' <<<"$r3_block" \
  && no "E10: R3 dispatch에 병렬·투기적 금지 문구 잔존 (scoped to R3)" \
  || ok "E10: R3 dispatch에 병렬 금지 문구 없음 (scoped to R3)"

# C45 interview_round>=2 트리거가 제거됐는지 (AC7)
grep -q 'interview_round >= 2\|interview_round>=2' "${CI_ALL[@]}" \
  && no "AC7: C45 interview_round>=2 trigger still present" \
  || ok "AC7: interview_round>=2 dispatch trigger replaced by C11"

# v0.23.0: 은퇴한 payload 좌표(§8/§9) 잔존 0 — 새 payload는 §0–§7 8섹션뿐이다.
# §8/§9로 보내는 지시는 존재하지 않는 섹션을 만들어 게이트를 RED로 만든다(부분 sweep 방지 락).
# `§8.2`처럼 뒤에 `.`나 숫자가 오는 것은 설계 문서 §-참조라 제외한다.
# 〔주의〕 CI_ALL 에는 플러그인 레벨 공유 계약(proceed-gate.md)이 들어 있고, 그 파일은
# **다른 문서의** 절 번호를 인용할 수 있다 — 이 검사는 그것을 payload 좌표와 구별하지
# 못한다(실측: 감사문서 `§8` 인용 하나로 발화). 거짓 RED 지만 시끄러우므로 안전하다.
# 공유 계약에서는 절을 번호가 아니라 **제목**으로 인용하는 것이 회피책이다.
retired_secs="$(grep -nE '§[89]([^.0-9]|$)' "${CI_ALL[@]}" || true)"
[[ -z "$retired_secs" ]] \
  && ok "V11: 은퇴 payload 좌표(§8/§9) 잔존 0" \
  || { no "V11: 은퇴 payload 좌표(§8/§9)가 SKILL에 잔존:"; printf '%s\n' "$retired_secs"; }

# breadth-keeper 용어 잔존 0 (SKILL 본문, AC7/V7a)
grep -qi 'breadth-keeper\|breadth_keeper' "${CI_ALL[@]}" \
  && no "V7a: breadth-keeper term remains in SKILL" \
  || ok "V7a: breadth-keeper term removed from SKILL"

# interview_round confinement — migration section only (SHARP, Task 9 V9)
mig_ir_count="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL" | grep -c interview_round)"
total_ir_count="$(ci_cat_all | grep -c interview_round)"
[[ "$mig_ir_count" -eq "$total_ir_count" ]] \
  && ok "V9: interview_round confined to migration section (mig=$mig_ir_count total=$total_ir_count)" \
  || no "V9: interview_round confined to migration section (mig=$mig_ir_count total=$total_ir_count)"

# --- v0.23.0: 발화 기록 producer (AC1 positive, §8.2) ---
# 전-파일 grep은 헤더-satisfiable 함정에 걸린다(섹션 제목만 남겨도 통과) → awk 블록 스코프 +
# body-unique 문구로 잠근다. mutation: 아래 yaml 블록을 지우면 RED여야 한다.
stmt_block="$(awk '/^## 사용자 발화 기록/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$stmt_block" ]] && grep -q 'user_statements' <<<"$stmt_block"; } \
  && ok "AC1: 사용자 발화 기록 섹션이 user_statements 스키마를 담는다" \
  || no "AC1: 사용자 발화 기록 섹션에 user_statements 스키마가 없다"
{ grep -q 'id: S<N>' <<<"$stmt_block" && grep -qE 'source: verbatim' <<<"$stmt_block"; } \
  && ok "AC1: 발화 레코드가 id/source 필드를 명시" \
  || no "AC1: 발화 레코드 스키마(id: S<N> / source: verbatim)가 없다"
grep -qE 'status 필드는 없습니다|앵커도 없습니다' <<<"$stmt_block" \
  && ok "AC1: 라운드 중 status·해답공간 앵커 부재가 명시됨" \
  || no "AC1: status/앵커 부재 명시가 없다"

# agents 3종의 Input 절이 더 이상 locked_directions를 참조하지 않는다 (spec §7 누락 보강)
for a in blind-spot-prober steelman-builder coverage-mapper; do
  grep -q 'locked_directions' "$REPO_ROOT/plugins/spec-distill/agents/$a.md" \
    && no "AC13: agents/$a.md가 locked_directions를 참조" \
    || ok "AC13: agents/$a.md에 locked_directions 없음"
done
finish
