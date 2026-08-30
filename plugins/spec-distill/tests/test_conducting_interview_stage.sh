#!/usr/bin/env bash
# AC3/AC7/AC8/AC13 + R1-R5 + PN1/PN3 — conducting-interview problem-space stage contract.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"
CMD="$REPO_ROOT/plugins/spec-distill/commands/interview.md"
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
# 이 게이트를 전-파일 grep으로 잠그면 이빨이 0이다. `finishing.md` 안에서만도
# 'AskUserQuestion'이 B-0 프로즈 안내·B-2 헤더·게이트-아님 가드 안내·실제 호출까지
# 다섯 곳에 등장한다(Task 6 실측 — 옛 probe 상한 절이 근거였던 이전 사례는 그 절 삭제로
# 함께 없어졌다). 옵션 라벨 4종은 B-3의 bullet 제목이 verbatim 반복하므로 각각 2~3회
# 등장한다. 실측: B-2의 AskUserQuestion({…}) 블록을 통째로 지워도 5건 전부 GREEN이었다.
# → "#### B-2" 블록으로 스코프한다.
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
has 'no_progress_streak' "AC1: orchestration.no_progress_streak in schema"
has 'blind_spot_dispatched' "AC1: orchestration.blind_spot_dispatched in schema"
# v0.38.0: probe 카운터를 지우면서 coverage-mapper 재dispatch 바운드가 함께 사라지지
# 않게 «에피소드» 단위로 이식한다. 재는 것은 **두 디스크 값의 비교**가 유지되는가다 —
# 값 하나(streak)를 저장하면 streak 3 에서 dispatch(저장 3) → 4 → `3 != 4` → 재dispatch
# → 5 → … 로 레벨-트리거 무한 재dispatch 가 되살아난다(현행 바운드가 명시적으로 막는 것).
has 'stall_episode' "C11(v0.38.0): orchestration.stall_episode in schema"
has 'coverage_mapper_dispatched_episode' "C11(v0.38.0): orchestration.coverage_mapper_dispatched_episode in schema"
# AC1: 기존 필드 보존
has 'non_user_streak' "AC1: non_user_streak retained"
# AC1: 라운드별 잠금 producer 제거 — pending_locked_decisions는 사라지고 user_statements가 대체
grep -q 'pending_locked_decisions' "${CI_ALL[@]}" \
  && no "AC1: pending_locked_decisions가 SKILL에 잔존 (라운드별 잠금 producer)" \
  || ok "AC1: pending_locked_decisions 제거됨"
has 'user_statements' "AC1: user_statements가 state 스키마에 존재"
# AC5: 마이그레이션 — 구세션 감지 + fresh seed + advisory
has 'coverage.*부재|coverage 부재|interview_round.*존재' "AC5: legacy detection (interview_round present / coverage absent)"
has 'state schema migration.*coverage' "AC5: migration advisory wording"
mig_block="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
# v0.38.0(R-I): migration 절도 orchestration 열거를 담고 있다 — 필드 교체를 소유한
# 태스크가 그 필드의 모든 자리를 책임진다. Task 6(probe 스윕)이 옛 단일 필드 리터럴을
# 이 파일에서 지우면서, 그 리터럴로 부재를 확인하던 이 assertion도 함께 다시 써야 했다
# (그 리터럴 자체가 probe 계열 별칭 oracle에 걸린다 — 남기면 잔존 락이 이 파일을 영구히
# residue로 본다). 음의 grep 대신 **정확히 일치**하는 전체 열거 리터럴을 요구한다 —
# 에피소드 필드 둘로 정확히 끝나는 열거만 통과하므로 옛 필드가 끼어들거나(추가) 대체돼도
# (치환) 이 리터럴과 달라져 RED다. 부분 토큰 공존이 아니라 **열거 전체의 동일성**이 이빨이다.
{ grep -qF '`orchestration`: `{focused_dimension: null, no_progress_streak: 0, blind_spot_dispatched: false, stall_episode: 0, coverage_mapper_dispatched_episode: null}`' <<<"$mig_block"; } \
  && ok "AC5(v0.38.0): migration 절의 orchestration 열거가 정확히 에피소드 필드 둘로 끝난다 (구 단일 필드 없음)" \
  || no "AC5(v0.38.0): migration 절의 orchestration 열거가 정확히 에피소드 필드 둘로 끝난다 (구 단일 필드 없음)"

# Unbounded-autonomy backstop fail-open fix: migration must persist BEFORE the first probe.
# Deferring persistence to "the next explicit state write" leaves coverage/orchestration
# fields off disk while the coverage-mapper redispatch bound (episode-field comparison,
# scoped assertion below) reads them.
grep -qE '첫 probe.*먼저' <<<"$mig_block" \
  && ok "AC5/backstop: migration persists before first probe (scoped to In-flight state migration)" \
  || no "AC5/backstop: migration persists before first probe (scoped to In-flight state migration)"

# state 스키마 블록(첫 yaml)에서 interview_round가 능동 필드로 남지 않았는지 (V7b)
# — 마이그레이션 섹션의 언급은 허용, 스키마 선언은 금지.
schema_block="$(awk '/^State frontmatter schema:/{f=1} f&&/^```yaml/{y=1;next} y&&/^```/{exit} y' "$SKILL")"
grep -q 'interview_round' <<<"$schema_block" \
  && no "V7b: interview_round still an active schema field" \
  || ok "V7b: interview_round removed from active state schema"

# --- v0.22.0: 커버리지 종료 루프 (G1/AC2) ---
has 'floor.*(closed|전부.*closed|모두.*closed)' "G1/AC2: termination = floor all closed"
has 'Coverage Ledger' "AC2/C9: brief Coverage Ledger serialization"
has '8-section|8-섹션|8 섹션' "AC10: Step A가 8섹션 템플릿을 참조"

# v0.38.0: probe cap 이 사라지면 그 escalation 의 3옵션도 함께 사라진다. 새 탈출구는
# 발동 조건만 다르고(카운터 → 사용자 발화) 존재해야 하는 것은 같다.
#
# **awk 윈도우로 스코프한다** — `박제` 어휘가 이 파일의 다른 절(Step B 게이트 안내 ·
# kill switch)에도 선재하므로 전-파일 grep 은 이 경로가 통째로 사라져도 satisfied 되어
# teeth 가 0 이다(feedback_grep_lock_header_satisfiable). 옛 probe 상한 escalation
# 절은 Task 6 이 지워 더는 존재하지 않으므로 선재 목록에서 뺐다 — 지운 절을 계속
# 인용하면 거짓 인용이 된다(같은 이유로 이 스위트 자신이 그 절을 스코프하던 변수·단언도
# 함께 지웠다).
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
# RED가 된다(실측). exit_block 자체가 이미 "## 종료" 하나로 좁혀져 있어
# 트리거 어휘가 무관한 절과 섞일 위험은 없다.
#
# ── 이 단언이 재지 «못하는» 것 (실측, 두 방향) ──────────────────────────────
# 관계 결속으로 닫은 것은 "리터럴이 서로 다른 문장·단락에 흩어진" 축이다. **같은 문장 안에
# 다섯 리터럴이 모이면 의미는 보지 않는다.** 두 방향 모두 실측으로 GREEN 이다:
#
#   · **반사실** — 다섯(트리거·`evidence`·`사용자-승인 박제`·`§3 Open Questions`·이관 동사)을
#     한 문장에 묶되 내용은 무관하게: "사용자가 언제든 종료를 요청하면 evidence 에 사용자-승인
#     박제 라고 적고, 남은 예산 항목은 payload §3 Open Questions 위에 잠깐 이월해 뒀다가
#     나중에 지운다." → GREEN. 이 문장은 floor 를 이월하지 않는다.
#   · **부정형** — 실제 문장을 그대로 두고 동사만 뒤집기: "…§3 Open Questions 로 **이월하지
#     않는다**. 박제 표식은 원장에 **남기지 않는다**." → GREEN. 이관 동사 검사가 `이월` 을
#     부분일치로 보므로 `이월하지 않는다` 도 만족시킨다.
#
# 즉 이 단언이 보장하는 것은 **다섯 리터럴이 그 관계로 배치돼 있다**까지이고, 그 배치가
# 서술하는 «행위»가 실제로 미충족 floor 를 §3 로 옮기는 것인지는 보장하지 않는다. 더
# 닫으려면 문장의 주어-목적어 관계를 파싱해야 하는데 그것은 셸 grep 락의 계약 밖이다.
# 일반화하지 않고 이 두 모양으로 특정해 남긴다.
{ [[ -n "$mech_para" ]] \
  && grep -qE '사용자.*종료를 요청|사용자가 언제든 종료' <<<"$exit_block" \
  && grep -q 'evidence' <<<"$mech_para" \
  && grep -q '사용자-승인 박제' <<<"$mech_para" \
  && grep -qE '§3 Open Questions|## 3\. Open Questions|payload[^.]*Open Questions' <<<"$dest_sentence" \
  && grep -qE '이월|옮긴다|옮긴|넘긴다' <<<"$dest_sentence"; } \
  && ok "C1(v0.38.0): floor 탈출구 — 사용자 발화 → 미충족 floor 를 사용자-승인 박제 (트리거는 절 전체, 처분·행선지·이관동사는 단락·문장으로 결속, scoped to 종료)" \
  || no "C1(v0.38.0): floor 탈출구 — 사용자 발화 → 미충족 floor 를 사용자-승인 박제 (트리거는 절 전체, 처분·행선지·이관동사는 단락·문장으로 결속, scoped to 종료)"
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
#
# Task 6(R-J 이월): 위 code_spans는 **절 전체**에서 backtick 스팬을 모으므로 «관계가 어느
# 스팬에든 존재하는가»만 본다 — 그 스팬이 **실제 판정문인지**는 안 본다. 실증(reviewer
# 재현): 진짜 조건식을 `AND`→`OR`로 defang하고, 절 안 다른 곳(예: 반례 설명 문단)에 옛
# AND 문구를 backtick 예시로 남겨두면 이 절이 이미 반례 설명 문단을 갖고 있어 그 미끼가
# 자연스럽게 생기고, 스위트 전체가 GREEN이 된다(M12). 그래서 검사 대상을 **판정문이 사는
# 단락**(직전 줄이 `**redispatch 바운드`로 시작하는 문단, 빈 줄 경계)으로 먼저 좁히고,
# 그 문단 안의 backtick 스팬에서만 관계를 찾는다 — 절 전체의 다른 문단에 있는 스팬은
# 후보에서 아예 빠진다.
#
# **이 앵커의 대가(fix round 1, 리뷰 Minor 3)**: `^\*\*redispatch 바운드`는 위치
# 의존적이다 — 그 문단 **맨 앞**에 `**redispatch 바운드`가 와야 한다. 의미를 안 바꾸는
# 편집(예: 그 문단 앞에 안내 문장 한 줄을 새로 끼워 넣는 것)도 그 문단을 더는 이
# 리터럴로 시작하지 않게 만들면 `judgment_para`가 비어 거짓 RED가 난다(실측 확인 —
# `**redispatch 바운드(...)**: 재dispatch 조건은` 앞에 무해한 한 줄을 넣자 이 assert가
# 즉시 RED). 이전 태스크(Task 4)와 같은 교훈이다 — **의미를 결속하고 레이아웃엔
# 관대해야** 하는데, 이 앵커는 그 문단의 **첫 줄 위치**라는 레이아웃에 결속돼 있다.
# 지금은 이 문단이 그렇게 편집될 계획이 없어 위험을 감수하지만, 이 문단을 다시 만지는
# 사람은 이 앵커가 「문단 시작」을 본다는 것을 알아야 한다.
judgment_para="$(awk -v RS='' '/^\*\*redispatch 바운드/' <<<"$covmap_block")"
code_spans="$(awk 'BEGIN{RS="`"} NR%2==0{gsub(/\n/," "); print}' <<<"$judgment_para")"
{ grep -qE 'no_progress_streak[[:space:]]*>=[[:space:]]*3[[:space:]]+AND[[:space:]]+coverage_mapper_dispatched_episode[[:space:]]*!=[[:space:]]*stall_episode' <<<"$code_spans" \
  || grep -qE 'coverage_mapper_dispatched_episode[[:space:]]*!=[[:space:]]*stall_episode[[:space:]]+AND[[:space:]]+no_progress_streak[[:space:]]*>=[[:space:]]*3' <<<"$code_spans"; } \
  && ok "C11(v0.38.0): 재dispatch 바운드가 «임계값 AND 에피소드 비교» 관계 전체 (판정문 단락에 앵커, rewrap-tolerant)" \
  || no "C11(v0.38.0): 재dispatch 바운드가 «임계값 AND 에피소드 비교» 관계 전체 (판정문 단락에 앵커, rewrap-tolerant)"
# 조건 2 의 «유한성 근거» — 이것이 없으면 그 조건이 «바운드 밖»인지 «바운드 불필요»인지
# 구별되지 않는다. 지금까지 어디에도 없었다.
grep -qE 'floor 다섯 차원으로 고정|상한이 5' <<<"$covmap_block" \
  && ok "C11(v0.38.0): 조건 2 의 유한성 근거 명시" \
  || no "C11(v0.38.0): 조건 2 의 유한성 근거 명시"
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

# --- Task 7 (R-L): §6 최초 요청 원문(S1) 보존 — 요구 산문에 기계 단언을 붙인다 ---
# 컨트롤러 진단(task-7-context.md §②): Task 7 브리프 Step 1은 "이건 요구다"라는 산문
# 한 문단만 finishing.md에 추가하고, 그 실재를 재는 단언은 어디에도 추가하지 않는다.
# 그대로 두면 다음 편집이 이 문단을 지워도 아무것도 red가 되지 않는다 — 브리프가 스스로
# 진단한 상태가 그대로 유지된다. Task 4/5가 겪은 실패(요구되는 토큰을 각각
# `grep -q A && grep -q B`로 독립 검사 → 절 어디에 흩어져 있어도 만족)를 피하려면
# **토큰 공존이 아니라 문장 단위 exact 리터럴**을 걸어야 한다: 부분 삭제·재배치가 그
# 리터럴 중 하나를 반드시 깨뜨리므로, 개별 grep으로는 나올 수 없는 관계(같은 문장 안의
# S1/$ARGUMENTS/§6, 같은 문장 안의 빈 인자/S1 미생성/S2 유지)가 결속된다. rewrap(줄바꿈
# 위치 이동)에는 관대해야 하므로 개행을 공백으로 접고 연속 공백(list-item 들여쓰기가
# 만드는 것 포함)을 하나로 줄인 뒤 비교한다 — 레이아웃이 아니라 단어 순서만 본다.
#
# 자기검증(가짜 본문 시도, task-7-report.md에 기록): 요구 토큰들을 절 여기저기에 흩어
# 놓은 본문(Task4/5 실패 재현)은 아래 네 리터럴 중 어느 것도 만들지 못해 전부 실패한다
# — 결속이 실제로 걸려 있다는 뜻이다. 반대로, 이 네 리터럴을 부정 문맥으로 감싼 본문
# ("...은 폐기되었다", "...따르지 마세요")은 grep -qF로는 걸러지지 않는다 — 이건 이
# 파일의 다른 모든 리터럴 락(예: 'AskUserQuestion(', '확정하고 /compact 후
# brainstorming')이 공유하는 한계이지 이 단언만의 결함이 아니다. 부정 어휘 블랙리스트로
# 막는 것은 whack-a-mole이므로(대상만 바뀌며 재발) 시도하지 않는다 — 의미 차원의 적대적
# 재작성은 이 리포에서 Law 1 구조 게이트가 아니라 별도의 adversarial/codex 리뷰가 잡는다.
stepa_block="$(awk '/^### Step A — brief 작성/{f=1;print;next} /^### /{f=0} f' "$FIN")"
stepa_flat="$(tr '\n' ' ' <<<"$stepa_block" | tr -s ' ')"

grep -qF '**최초 요청 원문은 `S1`이다.**' <<<"$stepa_flat" \
  && ok "R-L: S1 = 최초 요청 원문 정의 (Step A 스코프, exact literal)" \
  || no "R-L: 'S1 = 최초 요청 원문' 정의 문장이 Step A 에 없다"

grep -qF '`$ARGUMENTS`(사용자가 `/interview`에 함께 넘긴 rough request)를 `user_statements`의 첫 항목과 **같은 형식**으로 §6 맨 앞에 넣습니다' <<<"$stepa_flat" \
  && ok "R-L: \$ARGUMENTS → S1 형식 → §6 배치 지시 (한 문장 결속)" \
  || no "R-L: \$ARGUMENTS 를 §6 맨 앞에 S1 형식으로 넣으라는 지시가 한 문장으로 없다"

grep -qF '비어 있으면(인자 없이 호출) `S1`을 만들지 않고 `S2`부터 시작하지 않습니다' <<<"$stepa_flat" \
  && ok "R-L: 빈 \$ARGUMENTS 시 S1 미생성 + S2 번호 유지 규칙 (한 문장 결속)" \
  || no "R-L: 빈 인자 규칙(S1 미생성·S2부터 시작 안 함)이 한 문장으로 없다"

grep -qF '원문 보존은 **관례가 아니라 요구**입니다' <<<"$stepa_flat" \
  && ok "R-L: 원문 보존이 관례가 아니라 요구라는 선언" \
  || no "R-L: 원문 보존 = 관례 아닌 요구 선언이 없다"

# --- Task 7 fix round 1 (R-M): S1 예약과 user_statements 번호 공식의 교차-파일 정합 ---
# 리뷰가 잡은 모순: finishing.md는 최초 요청 원문을 S1로 예약하지만, SKILL.md:146의
# id 공식은 그 예약을 모른 채 항상 `N = user_statements.length + 1`을 썼다. 원문이 있는
# (보통) 케이스에서 이러면 payload §6에 S1 앵커가 두 번 나와 `check_verbatim_coverage.py`의
# 앵커 중복 검사(:223-228, StructuralViolation)가 red를 내거나, 중복을 피해 앵커를
# 옮기면 state의 S1(첫 실제 답변)과 payload의 S1(원문)이 서로 다른 텍스트로 비교되는
# id-matching 루프(:287-322)에서 not_contained가 뜬다 — 둘 다 오늘은 통과하는 게이트가
# 깨지는 결과다. 고친 공식: 원문이 있으면 오프셋 +1(user_statements 번호가 S2부터
# 시작).
#
# fix round 2: 재리뷰가 `SKILL.md:146`의 `+ 1 + (...)`를 `+ 1 - (...)`로 딱 한 글자
# 바꿔 스위트를 93/93 GREEN인 채로 통과시켰다 — N이 원문 있을 때 0(무효 `S0`)이 되는
# 부호 반전인데도, 조건절 안의 단어("최초 요청 원문 있으면 1, 없으면 0")는 그대로라
# round 1의 리터럴이 못 잡았다. round 2는 조건절 바로 앞의 `+`까지 리터럴에 넣어 그
# 부호 반전을 잡았지만, 그래도 **부분 문자열 검사**였다 — round 3에서 재리뷰가 세
# 우회를 더 찾았다: ①`+ (...)` 뒤에 `) - 1`을 **덧붙이면** 잠근 부분 문자열은 그대로
# 남은 채 식 전체 값이 바뀐다, ②잠근 부분 **밖**에 있는 base term
# `user_statements.length`를 `confirmed.length`로 바꿔도 무관하다, ③finishing.md의
# "더해" 뒤에 "다시 1을 뺀 뒤"를 끼워 넣어도 잠근 리터럴은 그 안에 여전히 prefix로
# 들어있다. 셋 다 같은 메커니즘이다: **부분 문자열 존재 검사는 그 주위에 무엇을
# 덧붙여도 살아남는다.** 공식의 의미는 표현식 전체에 있지 조각 하나에 있지 않다.
#
# 이 단언이 주장하는 것(한 문장): SKILL.md의 id 공식 주석과 finishing.md의 대응
# 절이 각각 정본(base term·양쪽 연산자·조건절 두 분기·식의 시작과 끝)과 **처음부터
# 끝까지 정확히 일치**해야 한다 — 무엇을 지우든 뒤집든 옆에 덧붙이든 그 일치가 깨진다.
# 그 문장이 이름 붙이는 요소를 전부 셌다: base term(`user_statements.length`) ·
# 연산자1(`+`, length와 1을 잇는다) · 상수(`1`) · 연산자2(`+`, 조건절을 잇는다) ·
# 여는 괄호 · 조건절 분기A(`최초 요청 원문 있으면 1`) · 분기B(`없으면 0`) · 닫는
# 괄호 · 식의 시작(`# N =`)과 끝(마지막 `)`) — finishing.md 쪽은 연산자가 동사
# ("더해")이고 분기 둘은 같고 식의 끝은 "합의합니다"(그 다음 오는 `(`가 화살표 밖의
# 부연 설명을 여는 괄호라 경계로 쓴다).
#
# **부분 문자열이 아니라 전체 일치**로 건다: 그 줄/절을 정확히 뽑아 공백만 정규화한
# 뒤 정본 문자열과 `==`로 비교한다. 이러면 위 세 우회 전부와 부호 반전·조건절 반전이
# 전부 잡힌다 — 어디를 지우든 뒤집든 옆에 붙이든 전체 문자열이 달라진다. **공식에는
# 의미보존 관용을 안 준다**(코디네이터 판단, round 3): 공식의 정확한 텍스트가 계약이고
# 재작성은 조용히 통과가 아니라 눈에 띄어 재승인받아야 한다 — 리라이트 관용은 공식을
# 감싸는 **산문**에만 남는다(rewrap·문단 순서 교체·yaml 블록 위치 이동은 여전히 green).
# fix round 4: round 3 의 「전체 표현식 일치」는 스코프 안의 **첫 매치 하나만** 뽑아
# 비교했다(`grep … | head -1`, prefix-strip 둘 다 첫 출현을 취한다). 그래서 정본 텍스트를
# 진짜 규칙 **앞자리에** 심어두고 뒤의 진짜를 고치면 추출기가 미끼를 읽고 두 파일 모두
# GREEN 을 유지한다. round 4 는 그것을 「스코프 안에 정확히 한 번」으로 답했다 — 여전히
# **∃ 질문**이었고, 그 스코프를 **헤딩에서** 뽑았다.
#
# fix round 5: 그 스코프가 뚫렸다. 진짜 헤딩을 매치 밖으로 **개명**해 그 아래에 뒤집힌
# 규칙을 두고 원래 헤딩 이름으로 미끼 섹션을 심으면, awk 윈도우가 **날조된 본문**을 읽어
# 93/93 GREEN 이 된다. 네 라운드가 한 뿌리를 공유한다: **단언이 ∃ 를 묻고, 어디를 볼지를
# 피검자가 정한다.** 헤딩은 재는 대상 안의 텍스트일 뿐이라, 피검자가 쥔 것은 피검자가
# 위조한다. 그래서 층을 하나 더 올리지 않고 **질문을 바꾼다**:
#
#  · 영역을 헤딩이 아니라 **파일 전체**로 잡는다 — 경계가 피검자의 텍스트에서 나오지 않는다.
#  · 그 안에서 **이 규칙을 진술한다면 반드시 지니는 내용 표지**로 자리를 고른다(의도적으로
#    느슨하게). SKILL.md: `user_statements.length`(base term) · `id: S<N>`(레코드 앵커) ·
#    `최초 요청 원문`(오프셋 조건) 중 **하나라도** 가진 줄. finishing.md: `최초 요청 원문
#    (있|없)으면` 스팬(분기 어휘 어느 쪽이 앞에 와도 걸리도록) + `번호 공식과 합의` 스팬.
#  · 그 자리 **전부**(∀)가 정본과 공백 정규화 후 처음부터 끝까지 일치해야 한다. 「하나가
#    일치한다」가 아니다. 개수의 상·하한(정확히 1)을 같은 술어에 함께 건다 — 0 은 진공
#    통과를 막는 하한이고, 2 는 「두 번 진술된 규칙은 자기 자신과 어긋날 수 있다」를
#    결함으로 센다.
#
# 이러면 round 4 의 우회가 자기 전제 위에서 죽는다: 날조된 미끼도 표지를 가지고, 개명된
# 헤딩 아래의 뒤집힌 진짜도 표지를 가진다 → 자리 2 곳, 그중 하나가 정본과 불일치 → RED.
# 헤딩 게임이 무의미해지는 이유는 헤딩이 더는 하중을 받지 않기 때문이다.
#
# 표지의 비용은 재고 골랐다(오늘 이 두 파일에서): SKILL.md 세 표지의 **합집합 = 1 줄**
# (공식 그 줄), finishing.md 앵커 = 1 스팬 · `번호 공식과 합의` = 1 스팬. 규칙 진술이
# 아닌 정당한 줄은 하나도 걸리지 않는다. 한 단계 더 넓힌 `최초 요청 원문`(단독)은
# finishing.md 의 「최초 요청 원문은 `S1`이다」까지 잡아 **너무 넓다** — 그래서 분기
# 어휘까지 붙여 **내용으로** 좁혔다(헤딩으로 좁히지 않았다).
#
# **공시 — 이 단언이 못 잡는 것** (전부 실측한 것만 적는다):
#  (a) 정본을 그대로 둔 채 **표지를 피해** 그것을 부정하는 문장을 뒤에 덧붙이는 것
#      (「정정: 실제로는 오프셋을 적용하지 않는다」) — GREEN 이다. 부정문이 앵커 어휘를
#      다시 쓰면 자리가 2 가 돼 RED 이므로 이 축은 **부분 커버리지**다.
#  (b) 더 나쁜 쪽: 진짜 자리의 규칙을 **표지 없는 다른 말로** 뒤집어 쓰고(「이 예약을
#      반영하지 않고 언제나 `S1`부터 시작합니다」) 정본 사본을 미끼로 심는 것 — 표지를
#      가진 자리가 미끼 하나뿐이라 자리 1 · 정본 일치로 **GREEN 이다**. SKILL.md 에서
#      실측했고, finishing.md 에서는 미끼가 **문단 통째의 정본 사본**일 때 GREEN 이다
#      (미끼가 부분 사본이면 아래 R-M 세 번째의 존재 검사가 부수적으로 잡는다 — 이
#      단언이 잡는 게 아니다). 내용으로 자리를 고르는 검사는 그 내용을 하나도 공유하지
#      않는 재진술을 원리상 볼 수 없다 — 이 접근의 경계이지, 층을 더 올려 없앨 수 있는
#      결함이 아니다. (a) 와 (b) 는 같은 계열이다: 이 파일이 규칙을 두 번 말하고 그
#      둘이 서로 어긋나는데 어긋난 쪽이 표지를 안 쓰는 경우.
#  (c) 파일 전체를 영역으로 삼는 것은 **이 두 단언뿐**이다. 바로 아래 R-M 세 번째와 위의
#      R-L 4 종은 여전히 `stepa_flat`(헤딩 파생 스코프) 위의 **존재 검사**다 — 실측:
#      진짜 Step A 절을 통째로 복사해 원래 헤딩 이름의 미끼 섹션으로 심고 진짜를 개명해
#      규칙을 뒤집으면, round 4 의 테스트 파일에서 **93/93 GREEN**(R-L 4 종 포함 전부
#      통과)이다. 헤딩 위조 앞에서 그들은 이빨이 없고, 이 라운드의 두 단언만 그것을 잡는다.
# 부정 어휘 블랙리스트는 만들지 않는다: 대상만 옮겨 재발하는 whack-a-mole 이고(내일 쓰일
# 부정 표현은 오늘 열거할 수 없다 — denylist 의 시간 fail-open), 이 파일에 이미 있는
# 정당한 부정문(「…승격시키지 않습니다」)을 오탐한다. 의미 차원의 적대적 재작성은 grep
# 락이 아니라 adversarial/codex 리뷰가 잡는 층이다. 여기서는 **막지 않고 드러낸다**.
#
# 추출: SKILL.md 는 파일 전체에서 표지 합집합에 걸린 **줄**을 세고, 각 줄의 첫 `#` 뒤를
# 공백 정규화해 정본과 비교한다. finishing.md 는 파일 전체를 한 줄로 접고(rewrap 관용 —
# 앵커 문구 한가운데를 가르는 줄바꿈도 통과해야 한다) 앵커 스팬을 **전부 순회**하며 각
# 스팬에서 다음 `(` 직전까지를 정본과 비교한다. 둘 다 공백만 trim/squeeze 하고 그 외엔
# 손대지 않는다. **공식에는 의미보존 관용을 안 준다**(코디네이터 판단, round 3 · round 5
# 유지) — 리라이트 관용은 공식을 감싸는 **산문**에만 남는다(rewrap · 문장 순서 교체 ·
# yaml 예시 블록 위치 이동은 여전히 green).
skill_rule_marks='user_statements\.length|id: S<N>|최초 요청 원문'
skill_formula_canon='N = user_statements.length + 1 + (최초 요청 원문 있으면 1, 없으면 0 — finishing.md S1 예약과 합의)'
skill_rule_lines="$(grep -E "$skill_rule_marks" "$SKILL")"
skill_rule_n=0; skill_rule_bad=0; skill_rule_got=''
while IFS= read -r _ln; do
  [ -n "$_ln" ] || continue
  skill_rule_n=$((skill_rule_n + 1))
  _b="${_ln#*#}"
  _b="$(printf '%s' "$_b" | tr -s ' ' | sed -e 's/^ *//' -e 's/ *$//')"
  if [ "$_b" != "$skill_formula_canon" ]; then
    skill_rule_bad=$((skill_rule_bad + 1)); skill_rule_got="$_b"
  fi
done <<< "$skill_rule_lines"
{ [ "$skill_rule_n" -eq 1 ] && [ "$skill_rule_bad" -eq 0 ]; } \
  && ok "R-M: SKILL.md 파일 전체에서 번호 규칙 표지를 가진 자리가 1곳 + 그 전부가 정본과 일치" \
  || no "R-M: SKILL.md 번호 규칙이 «파일 전체 1곳 + 전부 정본 일치»를 깬다 (자리=$skill_rule_n 불일치=$skill_rule_bad got: [$skill_rule_got])"

fin_flat="$(tr '\n' ' ' < "$FIN" | tr -s ' ')"
fin_rule_re='최초 요청 원문 (있|없)으면'
fin_formula_canon='최초 요청 원문 있으면 1, 없으면 0 을 더해 SKILL.md `사용자 발화 기록`의 번호 공식과 합의합니다'
fin_rule_n=0; fin_rule_bad=0; fin_rule_got=''
_rest="$fin_flat"
while :; do
  _hit="$(printf '%s' "$_rest" | grep -oE "$fin_rule_re" | head -1)"
  [ -n "$_hit" ] || break
  _rest="${_rest#*"$_hit"}"
  fin_rule_n=$((fin_rule_n + 1))
  _c="$_hit${_rest%%(*}"
  _c="$(printf '%s' "$_c" | sed -e 's/[[:space:]]*$//')"
  if [ "$_c" != "$fin_formula_canon" ]; then
    fin_rule_bad=$((fin_rule_bad + 1)); fin_rule_got="$_c"
  fi
done
fin_xref_n="$(printf '%s' "$fin_flat" | grep -oF '번호 공식과 합의' | grep -c .)"
{ [ "$fin_rule_n" -eq 1 ] && [ "$fin_rule_bad" -eq 0 ] && [ "$fin_xref_n" -eq 1 ]; } \
  && ok "R-M: finishing.md 파일 전체에서 오프셋 규칙 표지를 가진 자리가 1곳 + 그 전부가 정본과 일치" \
  || no "R-M: finishing.md 오프셋 규칙이 «파일 전체 1곳 + 전부 정본 일치»를 깬다 (자리=$fin_rule_n 불일치=$fin_rule_bad 교차참조=$fin_xref_n got: [$fin_rule_got])"

grep -qF '`S1`이 아니라 `S2`부터 시작합니다' <<<"$stepa_flat" \
  && ok "R-M: 원문 있으면 user_statements id가 S1이 아니라 S2부터 시작한다는 명시 (한 문장 결속)" \
  || no "R-M: 원문 있음 케이스의 S2 시작 규칙이 finishing.md에 한 문장으로 명시되지 않았다"

# --- v0.41.0: R1 재정의 (5 통과 의례 절 스코프 — 헤더-satisfiable 회피) ---
rites_block="$(awk '/^## 5 통과 의례/{f=1;print;next} /^## /{f=0} f' "$SKILL")"

# CHANGELOG 가 「명칭 변경이 아니라 R&R 이동이다」라고 말하는 실체(«seed 가 가리키는 작업
# 뒤의 진짜 문제» · «seed 의 문장을 되풀이하는 것은 통과가 아니다»)는 라벨(`Problem
# Reframe`) 하나만 검사해서는 무방비다 — 라벨이 있고 통과 기준 산문이 rites_block 안 다른
# 곳에 있어도(심지어 없어도) 만족된다. 그래서 세 사실을 **R1 표 행 하나**(물리적으로 한
# 줄)에서 함께 요구한다 — 관계는 "같은 행".
r1_row="$(grep -E '^\|[[:space:]]*R1[[:space:]]*\|' "$SKILL")"
{ [[ -n "$r1_row" ]] \
    && grep -qF 'Problem Reframe' <<<"$r1_row" \
    && grep -qF '작업 뒤의 진짜 문제' <<<"$r1_row" \
    && grep -qF '되풀이하는 것은 통과가 아니다' <<<"$r1_row"; } \
  && ok "R1(v0.41.0): 라벨 + R&R 이동 실체(작업 뒤의 진짜 문제 / seed 반복 불허)가 R1 행 하나에 결속" \
  || no "R1(v0.41.0): R1 행에 라벨과 R&R 이동 실체가 함께 있지 않다"

# --- v0.41.0: 탐색 경계 (### R2 절 스코프 — rites_block 보다 좁다: R1/R3 텍스트로부터
# 오는 우연한 co-occurrence 를 배제) ---
# 경계 — framing 의 탐색은 사용자에게 물어서 메우고, 바깥을 보는 것은 interview 의 R&R
# 이다. 이 문장이 없으면 두 단계의 질문이 어느 쪽 것인지 실행 시점에 판정 불가다.
#
# 이 단언이 묶는 것은 **한 문장 안의 관계**다 — `request-framing` 이라는 주어와 `웹`
# 부정이 **같은 문장**에 함께 있어야 한다. `framing` 존재와 `웹...보지 않` 존재를 절
# 전체에서 각각 독립으로만 요구하면, 경계 문단이 통째로 지워지고 절 안의 무관한 다른
# 문장이 `framing`과 `웹...보지 않`을 따로 공급해도 만족된다 — `### R2` 는 interview
# 자신의 웹 kill switch 가 문서화되는 자리라 그런 문장이 자연스럽게 존재한다. 절 스코프를
# `### R2 — 웹 Landscape`(rites_block 전체가 아니라)로 좁히는 것만으로는 이 결속이 안
# 생긴다 — 절이 좁아도 그 안의 다른 문장이 여전히 두 사실을 따로 공급할 수 있기 때문이다.
#
# 관계를 세우려면 셋이 함께 있어야 한다. ① 절 스코프(위). ② 개행을 공백으로 접어 rewrap
# 에 관대하다 — grep 은 줄 단위 매칭이라 rewrap 된 상태에서 물리 줄 경계가 관계를 가를 수
# 있다. ③ `request-framing` 에서 부정 어간 `보지 않`까지 이어지는 두 홉을 **모두**
# `[^.]`(마침표 제외)로 묶는다 — `.` 는 마침표도 매치하므로 한쪽 홉이라도 `.`를 쓰면 그
# 홉이 문장 경계를 넘어 다른 문장의 토큰과 결합할 수 있다. 어미 변화(보지 않는다/보지
# 않고/보지 않으며)는 어간 매치로 흡수한다.
r2_block="$(awk '/^### R2 — 웹 Landscape/{f=1;print;next} /^### /{f=0} /^## /{f=0} f' "$SKILL")"
r2_flat="$(tr '\n' ' ' <<<"$r2_block" | tr -s ' ')"
grep -qE 'request-framing[^.]{0,60}웹[^.]{0,20}보지 않' <<<"$r2_flat" \
  && ok "R2(v0.41.0): 탐색 경계 명시 (request-framing…웹…보지 않, 한 문장 결속, rewrap-tolerant)" \
  || no "R2(v0.41.0): 탐색 경계 명시 (request-framing…웹…보지 않, 한 문장 결속, rewrap-tolerant)"

# --- v0.41.0: seed 입력 규약 (scoped — 헤더-satisfiable 회피 + rewrap 관용) ---
seed_block="$(awk '/^## seed 를 입력으로 받았을 때/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
seed_flat="$(tr '\n' ' ' <<<"$seed_block" | tr -s ' ')"
# 리터럴은 finishing.md 의 S1 규약("<$ARGUMENTS 원문 그대로>", frontmatter 포함)과 같은
# 값을 요구한다 — "seed 본문 전체"라는 표현은 frontmatter 제외로 읽힐 수 있어 규약과 갈린다.
{ [[ -n "$seed_block" ]] && grep -qF '§6 `S1` 은 `$ARGUMENTS` 원문 그대로다' <<<"$seed_flat"; } \
  && ok "v0.41.0: seed 본문이 §6 S1 이 된다 (finishing.md S1 규약과 같은 값)" \
  || no "v0.41.0: seed 본문 = §6 S1 규약이 없다"
grep -qF 'type: interview-seed' <<<"$seed_flat" \
  && ok "v0.41.0: seed frontmatter 태그(type: interview-seed) 인식" \
  || no "v0.41.0: type: interview-seed 인식 규약이 없다"
grep -qE '새 발화가 *이긴다' <<<"$seed_flat" \
  && ok "v0.41.0: seed 확정을 뒤집는 새 발화가 우선 (P23)" \
  || no "v0.41.0: 새 발화 우선 규칙이 없다"

# §5·기각·원래.*재결정.*근거 를 절 전체에서 각각 독립으로 요구하면, 다섯 토큰이 서로
# 무관한 문장에 흩어져 있어도, 심지어 규칙이 부정형으로 뒤집혀(「…남기지 않는다」) 있어도
# 만족된다 — 다섯 토큰이 여전히 다 있기 때문이다. 그래서 여섯 요소(§5·기각·원래·재결정·
# 근거·긍정 동사 `남긴다`)를 **하나의 연속 구간**으로 묶는다. `남긴다`(현재형)를 마지막에
# 요구해 극성을 고정한다 — 부정형 `남기지 않는다`의 어간은 `남기지`로 철자가 달라(긴다
# vs 기지) 오탐하지 않는다.
grep -qE '§5[^.]{0,20}기각[^.]{0,20}원래[^.]{0,20}재결정[^.]{0,20}근거[^.]{0,25}남긴다' <<<"$seed_flat" \
  && ok "v0.41.0: 뒤집힘 기록이 §5 기각에 원래/재결정/근거로 남는다 (한 구간 결속, 긍정 극성)" \
  || no "v0.41.0: 뒤집힘 기록 위치·형태가 한 구간으로 결속되지 않았다"
grep -qF '조용히 덮어쓰지 않는다' <<<"$seed_flat" \
  && ok "v0.41.0: 조용한 덮어쓰기 금지 명시" \
  || no "v0.41.0: 조용한 덮어쓰기 금지 명시가 없다"
grep -qE '차단.{0,4}않는다|막지 않는다' <<<"$seed_flat" \
  && ok "v0.41.0: seed 아닌 입력도 받되 차단하지 않음 명시 (SKILL 쪽)" \
  || no "v0.41.0: seed 아닌 입력 비차단 명시가 없다 (SKILL 쪽)"

# --- v0.41.0: commands/interview.md — trivia 포인터 전환 + Step 2.5 비차단 조언 ---
grep -qE 'references/trivia-escape\.md' "$CMD" \
  && ok "v0.41.0: /interview 가 trivia-escape.md 정본을 가리킨다" \
  || no "v0.41.0: /interview 에 trivia-escape.md 포인터가 없다"
# 정본과의 분기 방지 — request-framing.md 의 동형 검사(test_request_framing_command.sh)와
# 대칭이다. 5패턴 본문이 이 파일에 다시 복제되면 정본이 바뀌어도 이 사본은 안 바뀐다.
cmd_pattern_dup="$(grep -cE '^[0-9]\. \*\*(Typo|주석-only|formatting|단일 식별자|<10 토큰)' "$CMD")"
[[ "$cmd_pattern_dup" -eq 0 ]] \
  && ok "v0.41.0: /interview 에 5패턴 본문이 복제되지 않았다 (정본만)" \
  || no "v0.41.0: /interview 에 5패턴 본문이 복제돼 있다 (${cmd_pattern_dup}줄) — 정본과 갈라진다"
step2_block="$(awk '/^## Step 2: /{f=1;print;next} /^## /{f=0} f' "$CMD")"
step2_flat="$(tr '\n' ' ' <<<"$step2_block" | tr -s ' ')"
step25_block="$(awk '/^## Step 2\.5/{f=1;print;next} /^## /{f=0} f' "$CMD")"
step25_flat="$(tr '\n' ' ' <<<"$step25_block" | tr -s ' ')"
{ [[ -n "$step25_block" ]] && grep -qF '막지 않는다' <<<"$step25_flat"; } \
  && ok "v0.41.0: Step 2.5 조언이 명시적으로 비차단 선언" \
  || no "v0.41.0: Step 2.5 에 비차단 선언이 없다"

# 양성 검사(Step 2 블록에 정지 문구가 실재하는가)와 부재 검사(Step 2.5 가 그 문구를
# 재사용하지 않는가)가 **같은 리터럴을 각자 손으로 다시 쓰면**, 그 둘을 묶는 것이
# 없어진다 — Step 2 의 문구가 바뀌었을 때 저자가 (양성 검사가 시키는 대로) 양성 검사
# 쪽 리터럴만 고치고 부재 검사 쪽은 그대로 두면, 스위트는 다시 green 이 되고 부재 검사는
# 이제 파일 어디에도 없는 옛 문구를 겨누는 죽은 키가 된다 — 정확히 이 가드가 막으려던
# 실패가, 이 가드의 실패 메시지가 권하는 그 수정 경로를 통해 되살아난다. 그래서 리터럴을
# **변수 하나**로 못박고 양쪽 grep 이 그 변수를 그대로 쓴다 — 값이 하나뿐이면 한쪽만
# 고치고 다른 쪽을 그대로 둘 방법이 없다. 이 가드가 잡는 것은 **이 한 문구**뿐이다 —
# 다른 표현의 차단 문장은 이 가드를 넘어간다(어휘를 열거해 일반화하지 않는다).
#
# 다른 절반 — 「막지 않는다」는 Step 2.5 가 조용하다는 것만으로는 성립하지 않는다. Step 3
# dispatch 줄이 **실재해야** 흐름이 실제로 이어진다(부재 검사만으로는 이 절반을 못 잡는다).
step2_stop_phrase='인터뷰를 시작하지 않습니다'
grep -qF "$step2_stop_phrase" <<<"$step2_flat" \
  && ok "v0.41.0: Step 2 의 정지 문구가 Step 2 블록에 실재한다 (아래 가드의 리터럴이 살아있음)" \
  || no "v0.41.0: Step 2 블록에서 정지 문구를 찾지 못했다 — 아래 Step 2.5 가드가 죽은 키를 겨눈다"
grep -qF "$step2_stop_phrase" <<<"$step25_flat" \
  && no "v0.41.0: Step 2.5 가 Step 2 자신의 정지 문구를 재사용한다 — 비차단 산문과 모순" \
  || ok "v0.41.0: Step 2.5 에 Step 2 의 정지 문구가 없다 (Step 3 로 흐름 지속)"
grep -qF 'Skill conducting-interview' "$CMD" \
  && ok "v0.41.0: Step 3 dispatch 줄이 실재한다 (흐름이 실제로 이어짐)" \
  || no "v0.41.0: Step 3 dispatch 줄이 없다 — «막지 않는다» 의 흐름-도달 절반이 무방비"
grep -qF 'request-framing' <<<"$step25_flat" \
  && ok "v0.41.0: Step 2.5 가 /request-framing 을 안내" \
  || no "v0.41.0: Step 2.5 안내문에 /request-framing 언급이 없다"

# --- U2-T6: 원문 거처 (finishing.md) ---------------------------------------
# 이 규칙에는 §N 도 절 제목도 개명 식별자도 없어 도출 ①–④ 가 못 잡는다.
# 그래서 락이 유일한 발견 경로다. 양성 짝을 함께 둔다 — 부재 검사만으로 된 락은
# 대상 파일을 통째로 지워도 통과한다.
grep -qF 'user_statements' "$FIN" \
  && ok "U2-T6(양성): finishing.md 를 실제로 읽었다" \
  || no "U2-T6(양성): 코퍼스를 못 읽었다 — 아래 둘은 공허하다"
# "audit §6" 만으로는 body-unique 하지 않다 — 이 절 아래 게이트-집행 서술 문장도
# 독립적으로 "audit §6"를 담고 있어서, 이 지시 문장만 지워도 그 다른 문장이 이 grep을
# 계속 만족시킨다(실측: 이 지시 문장을 통째로 지우고 돌려봤더니 이 단언이 조용히 계속
# green이었다). 그래서 이 문장에서만 나는 복합 리터럴로 좁힌다.
grep -qF '전량은 **audit §6**에' "$FIN" \
  && ok "U2-T6: 원문의 거처가 audit §6 으로 지시된다" \
  || no "U2-T6: finishing.md 가 원문을 audit §6 에 두라고 지시하지 않는다"
grep -qE '발화 전부를 payload §6|전부를 payload §6 에' "$FIN" \
  && no "U2-T6: 「전부를 payload §6 에」 옛 지시 잔존" \
  || ok "U2-T6: 옛 거처 지시 제거됨"

finish
