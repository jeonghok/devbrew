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
# Task 11b(무게 감축 재시도): 같은 이유로 `## seed 를 입력으로 받았을 때`와
# `## In-flight state migration`도 references/로 분리됐다(둘 다 finishing.md보다 조건성이
# 강하거나 같은 conditional-load 후보). 섹션 윈도우는 이제 SKILL이 아니라 이 두 파일에서 뜬다.
SEED_REF="$FIN_DIR/seed-input.md"
MIG_REF="$FIN_DIR/state-migration.md"
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

# AC21(i) mechanical only — review layer (ii) 공존 판단은 design 자리 리뷰어(doc-critic
# + design-doc 프로필)의 몫이고 이 기계적 축의 대상이 아니다
cc=$(ci_cat | grep -cE "턴 종료|다음 턴"); [[ "$cc" -ge 1 ]] \
  && ok "AC21(i): cross-compact stop wording present (lines=$cc)" \
  || no "AC21(i): cross-compact stop wording absent"

has 'polite[- ]?stop|narrate.*금지|silent 종료 금지' "AC22: AP2 polite-stop ban codified"

has 'state_path\.py state-root|Bash.*state|state.*Bash' "PN1: state-write-via-Bash contract"

grep -q 'drafting-spec' "${CI_ALL[@]}" && no "AC10: drafting-spec still referenced" || ok "AC10: no drafting-spec reference"

# --- v0.22.0: 커버리지 상태 스키마 + 마이그레이션 (AC1/AC5) ---
has 'coverage:' "AC1: coverage ledger in state schema"
has 'blind_spot_dispatched' "AC1: orchestration.blind_spot_dispatched in schema"
# v0.57.0: 정체 트리거(streak·에피소드) 전량 제거 — coverage-mapper dispatch 는 R1 필수 1회 +
# 재개방 시 최대 1회로 바뀌어 «두 디스크 값 비교» 바운드 자체가 불필요해졌다. 부재로 반전한다.
for tok in no_progress_streak stall_episode coverage_mapper_dispatched_episode; do
  grep -q "$tok" "${CI_ALL[@]}" && no "AC5/C4: $tok 잔존 (정체 트리거 제거)" || ok "AC5/C4: $tok 제거됨"
done
has 'coverage_mapper_dispatches' "C4: orchestration.coverage_mapper_dispatches in schema"
has 'reopen_log' "AC5: reopen_log in schema"
has 'reopened' "AC5: reopened in schema"
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
# Task 11b: 절 전문이 SKILL에서 $MIG_REF 로 옮겨졌다(조건부 로드) — 윈도우도 거기서 뜬다.
mig_block="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$MIG_REF")"
# v0.57.0: migration 절도 orchestration 열거를 담고 있다 — 필드 교체를 소유한 태스크가 그
# 필드의 모든 자리를 책임진다. 음의 grep 대신 **정확히 일치**하는 전체 열거 리터럴을 요구한다 —
# `coverage_mapper_dispatches` 하나로 정확히 끝나는 열거만 통과하므로 정체 트리거 필드가
# 끼어들거나 대체돼도 이 리터럴과 달라져 RED다. 부분 토큰 공존이 아니라 **열거 전체의 동일성**이 이빨이다.
{ grep -qF '`orchestration`: `{focused_dimension: null, blind_spot_dispatched: false, coverage_mapper_dispatches: 0}`' <<<"$mig_block"; } \
  && ok "AC5(v0.57.0): migration 절의 orchestration 열거가 정확히 coverage_mapper_dispatches 로 끝난다 (정체 트리거 필드 없음)" \
  || no "AC5(v0.57.0): migration 절의 orchestration 열거가 정확히 coverage_mapper_dispatches 로 끝난다 (정체 트리거 필드 없음)"
# v0.57.0 C2: 발동 조건이 «구조 통째 부재» 면 **실제 업그레이드 경로가 통째로 빠진다** —
# 직전 릴리스 세션은 `coverage`·`orchestration` 을 이미 갖고 이 릴리스가 더한 세 키
# (`reopened`·`reopen_log`·`coverage_mapper_dispatches`)만 없어서 어느 조건에도 안 걸린 채
# 그 키를 읽는 코드로 들어간다. spec §2.4 는 «부재 키는 기본값으로 추가» 다. 조건의 «단위»를
# 잰다 — 위 열거 락은 무엇을 채우는지만 보고 언제 발동하는지는 안 본다.
{ [[ -n "$mig_block" ]] && grep -qF '판정은 **키 단위**다' <<<"$mig_block"; } \
  && ok "AC5/C2: migration 발동 판정이 «키 단위»다 (구조 부재로 좁히지 않는다)" \
  || no "AC5/C2: migration 발동 판정이 키 단위가 아니다 — 직전 릴리스 세션이 어느 조건에도 안 걸린다"
# 리터럴은 **body-unique** 여야 한다. «부재 키만» 은 이 절에 두 번 나와서(총칙 + orchestration
# 적용례) 한쪽을 지워도 다른 쪽이 grep 을 계속 만족시킨다 — 실측으로 확인하고 총칙 문장에서만
# 나는 리터럴로 좁혔다.
grep -qF '이미 있는 값은 손대지 않는다' <<<"$mig_block" \
  && ok "AC5/C2: 이미 있는 값은 두고 부재 키만 채운다 (진행 중 인터뷰의 닫힘을 안 되돌린다)" \
  || no "AC5/C2: 부분 보충 총칙이 없다 — 있는 값을 덮어쓸 수 있다"
# 조건을 넓히면 «구세션 전용» 이던 `user_statements` 초기화가 직전 릴리스 세션까지 삼킬 수
# 있다. 그건 마이그레이션이 아니라 §6 원문·깊이 측정 근거의 손실이다. 범위 한정을 못 박는다.
grep -qE '구세션에 한해|구세션에만' <<<"$mig_block" \
  && ok "AC5/C2: user_statements 초기화가 구세션으로 한정된다" \
  || no "AC5/C2: user_statements 초기화 범위가 한정되지 않았다 — 넓힌 조건이 발화 레코드를 지운다"
mig_ptr="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$mig_ptr" ]] && grep -qF '어떤 키든 부재' <<<"$mig_ptr"; } \
  && ok "AC5/C2: SKILL 의 조건부 로드 조건도 «어떤 키든 부재» 다 (참조와 포인터가 같은 조건)" \
  || no "AC5/C2: SKILL 포인터의 로드 조건이 참조 파일의 조건보다 좁다 — 파일을 아예 안 읽는다"

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

# --- v0.57.0 §1 라운드 규약 (블록 스코프 — 4-block·teach-beat 대체) ---------------------
# 스코프 안의 예시 fenced block 이 `## R<n>`(depth_pairs 계약이 요구하는 실제 헤딩 리터럴)을
# 담고 있어 — 단순 "다음 `## ` 헤딩에서 닫는다" idiom 이 예시 자체를 다음 섹션 시작으로
# 오판한다(fence 미인식). 그래서 이 스코프만 ``` 토글로 fence 안쪽을 닫힘-판정에서 뺀다.
round_block="$(awk '/^```/{c=!c} /^## 라운드 규약/{f=1;print;next} !c && /^## /{f=0} f' "$SKILL")"
round_flat="$(tr '\n' ' ' <<<"$round_block" | tr -s ' ')"
{ [[ -n "$round_block" ]] && grep -qF '### 직전 답에서 — S<k>' <<<"$round_block"; } \
  && ok "AC1: 라운드 규약 절 + «### 직전 답에서 — S<k>» 블록 형식" || no "AC1: 라운드 규약 절/블록 형식 부재"
for key in '- 함의:' '- 상충:' '- 확인한 사실:' '- 위험:'; do
  grep -qF -- "$key" <<<"$round_block" && ok "AC1: 네 줄 키 $key" || no "AC1: 네 줄 키 $key 부재"
done
grep -qF '## R<n>' <<<"$round_block" && ok "AC1: state 본문 헤딩 ## R<n> (depth_pairs 계약)" || no "AC1: ## R<n> 헤딩 부재"
grep -qF 'Q1 은 생략할 수 없다' <<<"$round_flat" && ok "AC1: «Q1 은 생략할 수 없다»" || no "AC1: Q1 불가생략 문장 부재"
grep -qF 'R1 은 S1 을 되비춘다' <<<"$round_flat" && ok "AC1: «R1 은 S1 을 되비춘다»" || no "AC1: R1/S1 문장 부재"
grep -qE '넷 다 «없음»[^.]{0,60}되묻기|전부 «없음»[^.]{0,60}되묻기' <<<"$round_flat" && ok "AC1: 전부 «없음» → Q1 되묻기 (G1 이행 규칙)" || no "AC1: 전부-없음 규칙 부재"
# 실측(round 산문): «/interview» 와 «R2 부터» 사이 간격이 101자 — 원안 {0,80} 은 이 정확한
# 산문(브리프가 지정한 리터럴 그대로, 임의로 줄이지 않음)에 대해 너무 좁아 자기모순이었다.
# 120으로 넓혀 현재 문장 + 사소한 리라이트 여유를 함께 잡는다(부재 판정용이 아니라 「한
# 문장 안의 관계」결속이 목적이므로 상한 자체를 없애지 않는다 — 무관한 문장까지 걸리는
# vacuous 매치를 막는 것이 이 축의 역할이다).
grep -qE '인자 없이[^.]{0,40}/interview[^.]{0,120}R2 부터' <<<"$round_flat" && ok "AC1: 비-seed 경로의 R1 예외" || no "AC1: 비-seed R1 규약 부재"
q_js="$(awk '/^## 라운드 규약/{f=1} f&&/^```javascript/{j=1;next} j&&/^```/{exit} j' "$SKILL")"
[[ "$(grep -c 'header:' <<<"$q_js")" -eq 2 ]] && grep -q 'AskUserQuestion(' <<<"$q_js" \
  && ok "AC2: AskUserQuestion 한 번에 질문 둘(header 2개)" || no "AC2: AskUserQuestion 질문 수가 2가 아니다"
grep -qF '(권장)' <<<"$q_js" && ok "AC2: 첫 선택지가 추천 (권장)" || no "AC2: 추천 선택지 부재"
grep -qF '고르면 무엇이 달라지는가' <<<"$round_flat" && ok "AC2: description = 고르면 무엇이 달라지는가" || no "AC2: description 규칙 부재"
grep -qE 'Q1 의 선택지는 둘|«맞다» / «모르겠다»' <<<"$round_flat" && ok "AC2: Q1 선택지 둘(맞다/모르겠다), 수정은 기타" || no "AC2: Q1 선택지 규칙 부재"
grep -qF 'provisional_on' <<<"$round_flat" && ok "AC2: Q2 의 provisional_on 규칙" || no "AC2: provisional_on 부재"
reask_block="$(awk '/^## 되묻기로 바뀌는 조건/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$reask_block" ]] && grep -q '이유' <<<"$reask_block" && grep -q '사례' <<<"$reask_block" && grep -q '실패 조건' <<<"$reask_block"; } \
  && ok "C1: 되묻기 세 축(이유·사례·실패 조건)" || no "C1: 되묻기 절/세 축 부재"
grep -qE '추측[^.]{0,20}첫 선택지' <<<"$(tr '\n' ' ' <<<"$reask_block")" && ok "C1: 인터뷰어 추측이 첫 선택지" || no "C1: 추측-첫-선택지 규칙 부재"
# 제거 (G7·AC1·AC14) — 존재 검사가 아니라 부재 검사이므로 CI_ALL 전체
for tok in 'teach-lite' 'teach-heavy' 'teach-beat' 'general-purpose'; do
  grep -qF -- "$tok" "${CI_ALL[@]}" && no "G7: «${tok}» 잔존" || ok "G7: «${tok}» 제거됨"
done
# `4-block`·`막힌 결정` 은 **라운드 규약**의 어휘로서 제거됐다(AC1: «직전 답에서» 블록 + 질문 둘).
# 그런데 **R3 steelman 게이트**가 자기 제시 형식으로 같은 두 낱말을 쓴다(`references/steelman.md`
# Step 3) — 다른 물건이 같은 어휘를 쓴다. 어휘가 같다고 한쪽을 지우면 다른 쪽 설계를 지우는
# 것이므로, 부재는 «전 코퍼스»가 아니라 «steelman.md 를 뺀 전 코퍼스»에서 요구한다.
# 예외는 **하나**이고, 그 예외가 vacuous 하지 않은지(그 파일이 실제로 그 어휘를 갖는지)를
# 함께 잰다 — 그러지 않으면 steelman.md 가 어휘를 잃어도 이 예외가 조용히 남아 범위만 줄인다.
g7_exempt="$FIN_DIR/steelman.md"
g7_scoped=()
for _f in "${CI_ALL[@]}"; do [[ "$_f" == "$g7_exempt" ]] || g7_scoped+=("$_f"); done
[[ "${#g7_scoped[@]}" -eq $(( ${#CI_ALL[@]} - 1 )) ]] \
  && ok "G7: 예외가 정확히 references/steelman.md 하나 (${#g7_scoped[@]}/${#CI_ALL[@]})" \
  || no "G7: steelman.md 예외가 코퍼스에서 도출되지 않았다 (${#g7_scoped[@]}/${#CI_ALL[@]}) — 범위가 어긋났다"
for tok in '4-block' '막힌 결정'; do
  grep -qF -- "$tok" "${g7_scoped[@]}" \
    && no "G7: «${tok}» 잔존 (steelman.md 밖)" || ok "G7: «${tok}» 제거됨 (steelman.md 밖)"
  grep -qF -- "$tok" "$g7_exempt" \
    && ok "G7 양성 대조: «${tok}» 이 steelman.md 에 실재 (예외가 vacuous 아님)" \
    || no "G7 양성 대조: steelman.md 에 «${tok}» 이 없다 — 예외가 아무것도 면제하지 않으면서 범위만 줄인다"
done
[[ "$(wc -l < "$SKILL")" -lt 408 ]] && ok "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") < 408 (순감)" || no "G7: SKILL.md 줄 수 $(wc -l < "$SKILL") ≥ 408"

# coverage-mapper dispatch (상한 2, AC7, scoped)
covmap_block="$(awk '/^## coverage-mapper dispatch/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
{ [[ -n "$covmap_block" ]] && grep -q 'coverage-mapper' <<<"$covmap_block"; } \
  && ok "AC7: coverage-mapper dispatch section present" \
  || no "AC7: coverage-mapper dispatch section present"
# v0.57.0: 정체 트리거(연속 3 probe · 에피소드 비교)를 R1 필수 1회 + 재개방 시 최대 1회로
# 교체했다. 관계는 절 본문(줄바꿈 관용을 위해 flatten)에서 잡는다 — 헤더-satisfiable 회피는
# 위 presence 체크가 이미 담당하므로 여기서는 각 규칙의 body-unique 문구를 요구한다.
covmap_flat="$(tr '\n' ' ' <<<"$covmap_block" | tr -s ' ')"
grep -qE 'R1[^.]{0,30}첫 질문 전[^.]{0,20}필수 1회' <<<"$covmap_flat" \
  && ok "C4: R1 첫 질문 전 필수 1회" || no "C4: R1 필수 dispatch 규칙 부재"
grep -qE '재개방[^.]{0,20}최대 1회' <<<"$covmap_flat" \
  && ok "C4: 재개방 시 최대 1회" || no "C4: 재개방 dispatch 규칙 부재"
{ grep -qE '상한[^.]{0,6}2' <<<"$covmap_flat" && grep -qF 'coverage_mapper_dispatches' <<<"$covmap_block"; } \
  && ok "C4: 상한 2 + 카운터" || no "C4: 상한 2/카운터 부재"
grep -qE 'coverage-mapper 0 \(unavailable' <<<"$covmap_block" \
  && ok "C4: unavailable sentinel 규약" || no "C4: unavailable sentinel 부재"
grep -q 'advisory' <<<"$covmap_block" \
  && ok "C11: coverage-mapper output is advisory (orchestrator admits)" \
  || no "C11: coverage-mapper output is advisory (orchestrator admits)"

# 닫힘 · 재개방 (AC1/AC5/G2/C3, scoped) — 새 절. 헤더-satisfiable 회피는 presence 체크가,
# rewrap 관용은 flatten 이 담당한다.
close_block="$(awk '/^## 닫힘 · 재개방/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
close_flat="$(tr '\n' ' ' <<<"$close_block" | tr -s ' ')"
{ [[ -n "$close_block" ]] && grep -qE '사용자가 답한 S[^.]{0,10}뒤에만 닫' <<<"$close_flat"; } \
  && ok "AC1/G2: «차원은 사용자가 답한 S 뒤에만 닫는다»" || no "AC1/G2: 닫힘 규칙 부재"
grep -qE '횟수[^.]{0,30}닫힘 근거가 아니' <<<"$close_flat" \
  && ok "G2: 이벤트 횟수는 닫힘 근거 아님" || no "G2: 횟수-비근거 문장 부재"
grep -qF 'closed → open' <<<"$close_block" \
  && ok "AC5: closed → open 전이" || no "AC5: closed → open 부재"
grep -qF '→ <차원> 재개방' <<<"$close_block" \
  && ok "AC5: 상충 줄에 → 재개방" || no "AC5: 상충-재개방 표기 부재"
grep -qE '다시 닫힐 때[^.]{0,20}새 S|새 S[^.]{0,20}인용' <<<"$close_flat" \
  && ok "AC5: 재개방 후 닫힘은 새 S" || no "AC5: 새-S 규칙 부재"
grep -qE '상한[^.]{0,10}없|무상한' <<<"$close_flat" \
  && ok "C3: 재개방 무상한" || no "C3: 무상한 문장 부재"
for dim in root_problem landscape skepticism blind_spot open_questions; do
  grep -q "$dim" <<<"$close_block" && ok "§2.1: $dim 의 닫힘 발화 규약" || no "§2.1: $dim 닫힘 발화 규약 부재"
done

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
# R3 절차 분리: R3 절차 전문이 references/steelman.md 로 갔다(설계 §6.2). r3_block 은 그 파일에서
# 뜬다. 파일 첫 헤딩이 `### R3 — Steelman` 이고 그 뒤로 `##`/`###` 헤딩이 없어야 블록이 파일
# 끝까지 간다(AC23) — 중간 헤딩 하나가 아래 부재 락 셋을 공허하게 만든다.
STEELMAN="$FIN_DIR/steelman.md"
[[ -f "$STEELMAN" ]] && ok "코퍼스: references/steelman.md 실재 (AC4)" || no "코퍼스: references/steelman.md 부재 (AC4)"
r3_block="$(awk '/^### R3 — Steelman/{f=1;print;next} /^### /{f=0} /^## /{f=0} f' "$STEELMAN")"
[[ "$(printf '%s\n' "$r3_block" | grep -c .)" -ge 40 ]] \
  && ok "R3: r3_block 이 40줄 이상 (공허 아님)" || no "R3: r3_block 이 비었거나 잘렸다 — 첫 헤딩 또는 중간 ##/### 헤딩을 보라 (AC23)"
[[ "$(awk 'NR>1 && /^##(#)? /' "$STEELMAN" | grep -c .)" -eq 0 ]] \
  && ok "AC23: steelman.md 에 첫 줄 뒤 ##/### 헤딩 없음" || no "AC23: steelman.md 중간에 ##/### 헤딩 — r3_block 이 거기서 끊긴다"
grep -q '^### R3 — Steelman' "$SKILL" && ok "R3: SKILL.md 에 R3 헤딩 유지" || no "R3: SKILL.md 의 R3 헤딩 소실"
grep -q 'references/steelman.md' "$SKILL" && ok "AC4: SKILL.md 가 steelman.md 를 가리킨다" || no "AC4: SKILL.md 포인터 부재"
# C18 — neglect trigger 부재(반전) + 양성 짝(trigger 3값 · 검토 · 보류 · 새 어휘)
grep -q 'coverage-mapper neglect' <<<"$r3_block" \
  && no "C18: R3 trigger 에 coverage-mapper neglect 잔존" || ok "C18: R3 trigger 에 neglect 없음 (AC5)"
for t in 'landscape 모순' 'anti-pattern' '제약과의 충돌'; do
  grep -q "$t" <<<"$r3_block" && ok "R3 trigger 문구 존재: $t" || no "R3 trigger 문구 부재: $t (AC5)"
done
grep -q '검토 — steelman 0건' <<<"$r3_block" && ok "R3: 0건 검토 항목 형식 존재 (C8)" || no "R3: 검토 항목 형식 부재"
grep -q '보류 —' <<<"$r3_block" && ok "R3: 보류 항목 형식 존재 (AC19)" || no "R3: 보류 항목 형식 부재"
# AC6 어휘 — **맨 토큰 grep 은 부분 문자열에 먹힌다.** 실측(리뷰 라운드 3): `kept` 는
# s**kept**icism 다섯 자리에 걸려서, 진짜 verdict 자리 셋(`유지(kept)`·`verdict: kept`·
# `kept/switched`)을 전부 죽여도 `grep -c kept` 가 5 를 내고 스위트가 GREEN 이었다. 같은 결함이
# `refined`(스키마 키 `refined_drops`)와 `전환`(「게이트로 전환한다」 — 다른 뜻)에도 약하게 있다.
# 한국어에는 단어 경계가 없어 `\b` 로는 못 막는다 — **한↔영 짝 리터럴**로 못 박는다. 이 형태는
# 덤으로 매핑까지 잠근다(옛 루프는 여덟 토큰의 «공존»만 봤지 어느 한국어가 어느 영어인지는 안 봤다).
for pair in '유지(kept)' '보완(refined)' '전환(switched)' '보류(deferred)'; do
  grep -qF "$pair" <<<"$r3_block" && ok "R3 어휘 짝: $pair" || no "R3 어휘 짝 부재: $pair (AC6)"
done
# 고정 순서는 Step 3 게이트에 살고 위 짝은 Step 4 기록 형식에 산다 — 서로 다른 자리라 독립이다.
grep -qF '유지 / 보완 / 전환 / 보류' <<<"$r3_block" \
  && ok "AC6: 게이트 선택지 고정 순서 (유지 / 보완 / 전환 / 보류)" \
  || no "AC6: 게이트 선택지 고정 순서 부재"
# 추천 표시 (steelman-goal-fit C11 재결정) — 코퍼스는 질문 줄 하나다. 표시 규칙의 조건·라벨·금지가 그 한
# 줄에 함께 있어야 하고, 추천 답안이나 Step 2.5 로 흩어지면 RED. 출처 라벨이 걸린 리터럴은 조건과 라벨을
# 한 문자열로 묶어 잰다 — 라벨만 재면 두 출처의 라벨을 맞바꾸거나 조건을 지워도 통과한다. 질문 규칙은 steelman.md 에서
# **한 물리 줄**이어야 한다 — 줄바꿈하면 뒷부분이 코퍼스에서 빠져 RED.
# 한계 — 존재 락(아래 리터럴들)은 그 문자열이 정해진 자리에 있는지만 본다: 리터럴이 끝난 뒤에 덧붙인 부정
# (예: 「… 이 아니라 …」), 리터럴 밖의 변경, 동의어로 바꿔 쓴 규칙은 못 잡는다. 부재 락은 R3 블록 안의 괄호형
# `(Recommended)`·`(권장)` 두 리터럴만 본다. 어느 락도 모델이 실제로 라벨을 그렇게 붙이는지는 재지 않는다.
steelman_q="$(grep -m1 '^- \*\*질문\*\*' <<<"$r3_block")"
for lit in \
  '**고정 순서** 유지 / 보완 / 전환 / 보류 — 추천을 첫 자리로 옮기지 않는다' \
  'builder 가 추천한 선택지 라벨 뒤에 `(builder 추천)`' \
  'orchestrator 판정 선택지 라벨 뒤에 `(orchestrator 추천)`' \
  '두 추천이 다른 선택지면 각각 붙고, 같은 선택지면 `(builder·orchestrator 추천)` 하나만 붙인다' \
  'builder 추천이 switched 이고 Step 2.5 가 `재검토 사유 없음` 이면 전환 라벨은 `(builder 추천 · 전제 충돌 없음)`' \
  '`(Recommended)`·`(권장)` 접미사는 붙이지 않는다' \
  'builder 의 kept / refined / switched 는 유지 / 보완 / 전환이다'; do
  grep -qF "$lit" <<<"$steelman_q" && ok "R3 추천 표시 질문 줄: $lit" \
    || no "R3 추천 표시 질문 줄에 없음 (질문 줄이 한 물리 줄인지도 보라): $lit"
done
# 금지 문장을 양성 리터럴로만 재면 R3 블록의 다른 자리에 허용 문장이 새로 들어와도 통과한다. 금지 문장을
# 도려낸 나머지에서 부재를 잰다 — 도려내지 않으면 금지 문장 자신이 두 접미사를 담고 있어 늘 RED 다.
ban='`(Recommended)`·`(권장)` 접미사는 붙이지 않는다'
r3_minus_ban="${r3_block//"$ban"/}"
grep -qE '\(Recommended\)|\(권장\)' <<<"$r3_minus_ban" \
  && no "R3 추천 표시: 금지 문장 밖에 기본 추천 접미사가 있다" || ok "R3 추천 표시: 기본 추천 접미사는 금지 문장에만 있다"
# 표시가 가리킬 선택지가 정해지려면 orchestrator 줄이 판정 하나로 시작해야 하고, 보류는 그 판정에
# 들지 않는다(C15).
grep -qF '「orchestrator: <판정> — <이유>」(판정은 유지 / 보완 / 전환 중 하나 — 보류는 사람만 고른다)' <<<"$r3_block" \
  && ok "R3 추천 표시: orchestrator 줄 형식 (보류 제외)" || no "R3 추천 표시: orchestrator 줄 형식 「판정 — 이유」(보류 제외) 부재"
# Step 2.5 충돌 0 항목의 두 규칙 — orchestrator 판정의 유지·보완 제한, builder 전환 옆 라벨 — 은 게이트 전환
# 라벨의 봉쇄가 기대는 전제다. 코퍼스는 그 항목 하나를 한 줄로 이어 붙인 것이다. 항목으로 좁히면 문장을 충돌
# ≥1 항목으로 옮기거나 항목의 조건(충돌 0 ↔ ≥1)을 뒤집을 때 RED 가 나고, 이어 붙이면 줄바꿈 너머의 조건
# (「builder 추천이」 / 「switched 면」)까지 한 리터럴에 담긴다.
c0_block="$(awk '/^- 충돌 0/{f=1;print;next} f&&/^- /{f=0} f' <<<"$r3_block")"
c0_flat="$(tr '\n' ' ' <<<"$c0_block" | tr -s ' ')"
[[ -n "$c0_block" ]] && ok "R3 추천 표시: Step 2.5 충돌 0 항목 실재" || no "R3 추천 표시: Step 2.5 의 '- 충돌 0' 항목을 못 찾았다"
for lit in \
  '단 「추천 답안」의 orchestrator 줄은 유지 또는 보완 중 하나이고' \
  'builder 추천이 switched 면 그 옆에 `[전제 충돌 없음]` 라벨을 붙인다'; do
  grep -qF "$lit" <<<"$c0_flat" && ok "R3 추천 표시 충돌 0 항목: $lit" || no "R3 추천 표시 충돌 0 항목에 없음: $lit"
done
grep -qE 'defended|방어' <<<"$r3_block" && no "AC6: 옛 어휘 defended/방어 잔존" || ok "AC6: 옛 어휘 부재"
# 5의례 표(`| R3 |` 행)는 r3_block 밖이다 — 그 블록은 이제 steelman.md 에서 뜨고, 표는 SKILL.md
# 의 다른 절에 산다. 그래서 위 어휘 락이 닿지 않고, 그 자리가 조용히 옛 2값(`방어 또는 전환`)으로
# 남았다. 요약 표는 독자가 절차 본문보다 **먼저** 믿는 자리라 따로 잠근다. 코퍼스는 $SKILL 전체.
grep -q '방어 또는 전환' "$SKILL" \
  && no "AC6: SKILL.md 에 옛 게이트 어휘 '방어 또는 전환' 잔존 (5의례 표 R3 행)" \
  || ok "AC6: SKILL.md 에 옛 게이트 어휘 '방어 또는 전환' 부재"
# 양성 짝 — 부재 단언 혼자면 표 행을 통째로 지워도 통과한다(부재는 대상이 없을 때 가장 잘 통과한다).
ritual_r3="$(grep -m1 '^| R3 |' "$SKILL")"
{ [[ -n "$ritual_r3" ]] \
    && grep -qF '유지 / 보완 / 전환 / 보류' <<<"$ritual_r3" \
    && grep -qF '검토 — steelman 0건' <<<"$ritual_r3"; } \
  && ok "AC6: 5의례 표 R3 행이 4값 게이트 + steelman 0건 경로를 담는다 (부재락의 양성 짝)" \
  || no "AC6: 5의례 표 R3 행이 없거나 새 어휘(유지/보완/전환/보류 · 검토 — steelman 0건)를 담지 않는다"
for w in '재검토 열림' '재검토 사유 없음' '사용자 override'; do
  grep -q "$w" <<<"$r3_block" && ok "AC22: $w" || no "AC22: $w 부재"
done
grep -q 'touches' <<<"$r3_block" && ok "AC20: touches 확인 문구" || no "AC20: touches 부재"
# AC20 — 옛 락은 `grep -q '부착 M/N\|부착 M'` 였다. 첫 가지가 둘째의 **부분집합**이라 이빨은
# 전부 둘째에 있었고, 그 둘째는 라벨이 광고하는 «형식 문자열 넷»이 아니라 `:46` 의 **정의 문장**
# 하나가 만족시켰다(실측: 형식 문자열 4건을 다 지워도 GREEN). 두 주장을 쪼갠다.
[[ "$(grep -c '부착 M/N' <<<"$r3_block")" -ge 4 ]] \
  && ok "AC20: §5 기록 형식 4종이 '부착 M/N' 을 갖는다 (형식)" \
  || no "AC20: '부착 M/N' 형식 문자열이 4건 미만 (형식)"
grep -qF '확인을 통과한 부착' <<<"$r3_block" \
  && ok "AC20: M 의 정의 — 확인을 통과한 부착만 센다 (정의)" \
  || no "AC20: M 이 무엇을 세는지 규정하는 문장 부재 (정의)"
# ── web kill switch 가 dispatch 를 **구조적으로** 막는가 (보안 컨트롤).
# `steelman-builder` 는 WebSearch/WebFetch 를 갖고 자기 스위치를 읽지 않는다 — 차단 책임은
# orchestrator 단독이다. 앞선 판본은 `if … echo … fi` 뒤에 `Agent({…})` 를 **조건 밖 별도
# 펜스**로 두어, 문자 그대로 읽으면 「생략」을 출력하고도 그대로 dispatch 했다(egress 가 게이트
# 밖). 산문 한 줄은 다음 편집자가 지우면 그만이라 **순서 관계**로 잠근다: if < else < Agent < fi.
kw_if=$(grep -n 'DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0' "$STEELMAN" | head -1 | cut -d: -f1)
kw_else=$(awk -v s="${kw_if:-0}" 'NR>s && /^[[:space:]]*else[[:space:]]*$/{print NR; exit}' "$STEELMAN")
kw_ag=$(grep -n 'Agent({' "$STEELMAN" | head -1 | cut -d: -f1)
kw_fi=$(awk -v s="${kw_if:-0}" 'NR>s && /^[[:space:]]*fi[[:space:]]*$/{print NR; exit}' "$STEELMAN")
{ [[ -n "$kw_if" && -n "$kw_else" && -n "$kw_ag" && -n "$kw_fi" ]] \
    && [[ "$kw_if" -lt "$kw_else" ]] && [[ "$kw_else" -lt "$kw_ag" ]] && [[ "$kw_ag" -lt "$kw_fi" ]]; } \
  && ok "AC8: steelman dispatch 가 kill switch 의 else 가지 안 (if=$kw_if else=$kw_else Agent=$kw_ag fi=$kw_fi)" \
  || no "AC8: steelman dispatch 가 kill switch 게이트 «밖» — 스위치가 켜져도 web egress dispatch 가 나간다 (if=$kw_if else=$kw_else Agent=$kw_ag fi=$kw_fi)"
grep -qE '§[68] OQ' <<<"$r3_block" \
  && no "R3: 은퇴 OQ 좌표(§6/§8) 잔존 (should be §3 OQ)" \
  || ok "R3: 은퇴 OQ 좌표(§6/§8) 제거됨 (should be §3 OQ)"
[[ "$(grep -c '§3 OQ' <<<"$r3_block")" -ge 2 ]] \
  && ok "R3: §3 OQ reference present (x2)" \
  || no "R3: §3 OQ reference present (x2)"

# E10 (오케스트레이터 미러) — R3 dispatch 지시에 병렬·투기적 금지 문구 부재.
# steelman-builder.md 페르소나에서 지운 것과 같은 억제가 R3 dispatch 지시문에도 있었다
# (C5/AP9 인용 둘 다 근거 없음 — fix round 1). 스코프가 전-파일이 아닌 이유는 코퍼스가
# 바뀌어도 그대로다: 이 skill 표면에는 legitimate 한 횟수 제한 문구가 남아 있어 전-파일
# grep 은 그것에 걸린다 — v0.57.0 이 teach-beat 절을 지웠지만 `재개방 시 최대 1회`(SKILL.md)·
# `2회까지`(finishing.md)가 그 자리를 잇는다(문구만 바뀌고 근거는 그대로다). 지금
# "$r3_block" 은 SKILL.md 의 섹션 윈도우가 아니라 **references/steelman.md 전문**이다 —
# 재는 대상은 같고(그 절차의 dispatch 지시), 사는 파일만 옮겨갔다.
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
# Task 11b: 절 전문이 $MIG_REF 로 옮겨갔으므로 그 파일 전체가 이제 "migration section"이다
# (파일이 그 헤딩 하나로 시작해 끝까지가 그 절이므로 awk 윈도우는 그대로 유효하다).
mig_ir_count="$(awk '/^## In-flight state migration/{f=1;print;next} /^## /{f=0} f' "$MIG_REF" | grep -c interview_round)"
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
# Task 11b: 절 전문이 $SEED_REF 로 옮겨갔다 — 윈도우도 거기서 뜬다.
seed_block="$(awk '/^## seed 를 입력으로 받았을 때/{f=1;print;next} /^## /{f=0} f' "$SEED_REF")"
seed_flat="$(tr '\n' ' ' <<<"$seed_block" | tr -s ' ')"
# 리터럴은 finishing.md 의 S1 규약("<$ARGUMENTS 원문 그대로>", frontmatter 포함)과 같은
# 값을 요구한다 — "seed 본문 전체"라는 표현은 frontmatter 제외로 읽힐 수 있어 규약과 갈린다.
{ [[ -n "$seed_block" ]] && grep -qF '§6 `S1` 은 `$ARGUMENTS` 원문 그대로다' <<<"$seed_flat"; } \
  && ok "v0.41.0: seed 본문이 §6 S1 이 된다 (finishing.md S1 규약과 같은 값)" \
  || no "v0.41.0: seed 본문 = §6 S1 규약이 없다"
grep -qF '다시 검증할 것' <<<"$seed_flat" \
  && ok "AC11: seed 의 «다시 검증할 것» 문단을 R1/coverage-mapper 입력으로" \
  || no "AC11: seed 재검증 문단 소비 부재"
# 위 단언의 코퍼스는 seed 참조 «산문» 뿐이라 dispatch 를 못 본다 — 실제 호출이 seed 를
# 하나도 안 싣고 `<ledger_state>` 와 `<web_disabled>` 만 넘겨도 계속 green 이었다
# (spec §4.1·AC11 위반). 첫 dispatch 는 R1 «전에» 돌고 그때 원장은 floor 다섯 줄뿐이라,
# seed 가 없으면 이 agent 는 「이 주제가 요구하는 차원」을 제안하라는 과업의 **주제 자체를
# 못 본다**. dispatch 펜스를 직접 코퍼스로 삼는다.
mapper_fence="$(awk '/subagent_type: "spec-distill:coverage-mapper"/{f=1} f{print} f&&/\}\)/{exit}' "$SKILL")"
[[ -n "$mapper_fence" ]] \
  && ok "AC11(양성대조): coverage-mapper dispatch 펜스를 찾았다 (아래 단언이 실재한다)" \
  || no "AC11(양성대조): dispatch 펜스를 못 찾았다 — 아래 단언이 공허하다"
grep -qF '<reverify>' <<<"$mapper_fence" \
  && ok "AC11: coverage-mapper dispatch 가 «다시 검증할 것» 문단을 실제로 싣는다" \
  || no "AC11: dispatch 가 재검증 문단을 안 싣는다 — 산문만 그렇다고 말하고 있다"
grep -qF '<seed>' <<<"$mapper_fence" \
  && ok "AC11: coverage-mapper dispatch 가 seed 원문을 실제로 싣는다" \
  || no "AC11: dispatch 가 seed 를 안 싣는다 — 주제 없이 주제-도출 차원을 요구한다"
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

# --- v0.57.0 Step A.7 깊이 측정 (finishing.md, 블록 스코프) --------------------
a7_block="$(awk '/^### Step A\.7/{f=1;print;next} /^### /{f=0} f' "$FIN")"
a7_flat="$(tr '\n' ' ' <<<"$a7_block" | tr -s ' ')"
# 「산문이 파일명을 언급하는 것」과 「실제로 호출하는 것」은 다른 사실이다. 아래 둘을
# `grep -qF '<파일명>' <<<"$a7_block"` 로 재던 동안 락은 **이빨이 없었다**: A.7 안에서
# `depth_pairs.py` 는 호출 줄과 산문에, `depth_record.py` 는 호출 줄·산문·처분 줄에 나와서,
# **호출 두 줄을 통째로 지워도 스위트가 196/196 GREEN 이었다**(실측). 그래서 코퍼스를
# **bash 펜스 안**으로 좁히고 `python3 … <스크립트>` 라는 호출 «형태» 에 건다 — 산문은
# 그 형태를 만족시킬 수 없다(줄 머리가 `python3` 인 산문은 없다).
a7_bash="$(awk '/^```bash/{f=1;next} f&&/^```/{f=0;next} f' <<<"$a7_block")"
[[ -n "$a7_bash" ]] \
  && ok "A.7(양성대조): 절 안에서 bash 펜스를 추출했다 (아래 호출 단언이 실재한다)" \
  || no "A.7(양성대조): bash 펜스를 못 뽑았다 — 아래 호출 단언이 공허하다"
{ [[ -n "$a7_block" ]] && grep -qE '^[[:space:]]*python3 .*depth_pairs\.py' <<<"$a7_bash"; } \
  && ok "A.7: 깊이 측정 절이 있고 bash 펜스에서 depth_pairs.py 를 «호출»한다" \
  || no "A.7: 절 부재 또는 depth_pairs.py 호출 줄 없음 (산문 언급은 호출이 아니다)"
grep -qF 'spec-distill:depth-auditor' <<<"$a7_block" && ok "A.7: depth-auditor dispatch" || no "A.7: depth-auditor dispatch 없음"
grep -qF 'consumer=plugins/spec-distill/scripts/depth_record.py' <<<"$a7_block" && ok "A.7: 처분 줄이 depth_record.py 를 소비자로" || no "A.7: 처분 줄 부재"
grep -qE '^[[:space:]]*python3 .*depth_record\.py' <<<"$a7_bash" \
  && ok "A.7: bash 펜스에서 depth_record.py 를 «호출»한다" \
  || no "A.7: depth_record.py 호출 줄 없음 (산문·처분 줄 언급은 호출이 아니다)"
grep -qE 'pairs_rc[^.]{0,40}3[^.]{0,60}측정 불가' <<<"$a7_flat" && ok "A.7: rc 3 → «측정 불가» 기록" || no "A.7: rc 3 처분 없음"
grep -qE '기록한다[^.]{0,20}막지 않는다|막지 않는다' <<<"$a7_flat" && ok "A.7: «기록한다, 막지 않는다» (C5)" || no "A.7: 비게이트 선언 없음"
grep -qE '표본[^.]{0,10}0[^.]{0,30}(띄우지 않는다|호출 안 함|호출하지 않는다)' <<<"$a7_flat" && ok "A.7: 표본 0 이면 라벨 질문 없음" || no "A.7: 표본 0 처분 없음"
grep -qF '미라벨' <<<"$a7_block" && grep -qF 'unavailable' <<<"$a7_block" && ok "A.7: 미라벨·unavailable 어휘" || no "A.7: 미라벨/unavailable 어휘 부재"
grep -qE 'heredoc' <<<"$a7_block" && grep -qE '리다이렉트' <<<"$a7_block" && ok "A.7: raw 저장은 파일 리다이렉트(heredoc 금지)" || no "A.7: raw 저장 방식 미명시"
grep -q '파고들었다' <<<"$a7_block" && grep -q '안 팠다' <<<"$a7_block" && grep -q '판단불가' <<<"$a7_block" && ok "A.7: 사람 라벨 선택지 셋" || no "A.7: 사람 라벨 선택지 부재"
grep -qF 'min(4' <<<"$a7_block" && ok "A.7: 질문 수 min(4, 적격)" || no "A.7: 표본 상한 규칙 부재"
# B-2 게이트 텍스트에 깊이 요약과 advisories 슬롯
b2_block="$(awk '/^#### B-2/{f=1;print;next} /^#### /{f=0} f' "$FIN")"
grep -qF '깊이:' <<<"$b2_block" && ok "B-2: question 에 깊이 요약 슬롯" || no "B-2: 깊이 요약 슬롯 부재"
grep -qF 'coverage-mapper 0' <<<"$b2_block" && ok "B-2: coverage-mapper unavailable advisory 가 게이트 텍스트에" || no "B-2: mapper advisory 슬롯 부재"
# Step A 4 항: 직렬화 규칙 (S앵커·재개방 접미)
stepa4="$(awk '/^4\. \*\*Coverage Ledger 직렬화/{f=1} f&&/^5\. /{exit} f' "$FIN")"
grep -qE 'S<N>|S\d\+|S 앵커' <<<"$stepa4" && grep -qF '재개방' <<<"$stepa4" && ok "Step A 4: 직렬화가 S앵커·재개방 접미를 요구" || no "Step A 4: 직렬화 규칙에 S앵커/재개방 부재"
grep -qF 'coverage-mapper <k>' <<<"$stepa4" && ok "Step A 4: §2 coverage-mapper <k> 직렬화" || no "Step A 4: coverage-mapper <k> 부재"
# audit 템플릿
TPL="$REPO_ROOT/plugins/spec-distill/templates/interview-audit-template.md"
# `depth_record.py` 는 stdout 으로 **네 줄**을 내고 finishing.md Step A.7 이 그 넷을 §2 에
# 그대로 붙이라고 지시한다. 락이 셋만 세는 동안 `- 판정자 조건:` 줄은 템플릿에서 지워도
# 스위트가 GREEN 이었다(실측) — 그 줄은 spec §3.4 의 판정자 투입 조건이 사람에게 도달하는
# 유일한 자리다. 넷 다 데이터 불릿으로 실재하는지 센다.
depth_rows=0
for key in '깊이 측정(형식)' '깊이 측정(auditor)' '깊이 측정(사람)' '판정자 조건:'; do
  grep -qE "^- .*$(printf '%s' "$key" | sed 's/[][\.*^$(){}?+|/]/\\&/g')" "$TPL" \
    && depth_rows=$((depth_rows + 1))
done
[[ "$depth_rows" -eq 4 ]] \
  && ok "AC10: audit 템플릿 §2 깊이 네 줄 (형식·auditor·사람·판정자 조건) 이 전부 데이터 불릿" \
  || no "AC10: 템플릿 §2 깊이 줄이 4 가 아니라 $depth_rows — depth_record.py 의 네 줄과 어긋난다"
grep -qF '(재개방' "$TPL" && ok "AC10: 템플릿 §1 재개방 접미 예시" || no "AC10: 재개방 접미 예시 부재"
# 템플릿의 mapper 계수는 **데이터 줄**(불릿)에 있어야 하되 **숫자로 미리 채워선 안 된다**.
# 두 요구는 R18 과 충돌했다: R18 은 「산문이 판정을 지지 않게」 데이터 줄에 실제 숫자를
# 요구했는데, 그러면 출하 템플릿이 게이트의 통과값(`coverage-mapper 1`)을 나눠 주게 되어
# dispatch 0 회 턴이 그대로 옮겨 적으면 게이트가 조용히 통과한다. 해소: 출하본에는 `<k>`
# 를 두고, R18 이 막던 것은 **숫자를 치환한 합성 사본**에 대해 `check_brief.py` 의 실물
# `budget_mapper_failures` 로 잰다 — `tests/test_audit_template_gate_shape.py`.
# 여기서는 그 파일이 겨누는 대상(데이터 불릿)이 실재하는지만 값싸게 확인한다.
grep -qE '^- .*coverage-mapper <k>' "$TPL" \
  && ok "AC10: 템플릿 §2 데이터 줄의 mapper 계수가 placeholder (통과값 미배포)" \
  || no "AC10: 템플릿 §2 mapper 계수가 «<k>» 가 아니다 — 통과값을 미리 채웠거나 줄이 사라졌다"
grep -qE 'path \(a\|b\|c\|d\)' "$TPL" && no "AC10: 템플릿 §5 에 경로 (c) 잔존" || ok "AC10: 템플릿 §5 경로 (c) 제거"

# --- v0.57.0 C43: 선언한 경로 수 == 실제 표 행 수 (블록 스코프) ------------------------
# 왜 이 락이 생겼나: Task 10 이 경로 (c) 를 지우면서 표 행과 꼬리 문장은 고쳤지만 헤딩
# `## C43 4-path routing` 과 산문 «다음 4 경로 중» 의 숫자를 남겼다. 표에는 셋뿐인데 모델이
# 읽는 지시는 넷을 분류하라고 시키는 상태가 릴리스까지 살아남았다 — README(«3-path Socratic
# routing»)와 CHANGELOG(«경로 (c) … 제거»)가 이미 셋이라고 적고 있어 **우리 문서 둘이 이
# 파일과 모순**됐는데도 어떤 락도 그 축을 재지 않았다. 리뷰가 아니라 락이 잡았어야 할 것이다.
#
# 리터럴 3 을 핀하지 않는다 — 그러면 경로가 정당하게 늘 때 이 락은 「고칠 것」이 아니라
# 「거스를 것」이 되고, 다음 사람이 숫자만 맞춰 통과시키는 길이 열린다. 대신 **파일 안의 두
# 수를 서로 지배시킨다**: 선언한 수(헤딩·산문)가 실제 표 행 수와 같아야 한다. 어느 쪽을
# 건드려도 짝이 어긋나면 RED 다(행 삭제·행 추가·숫자 변경 세 방향 전부).
c43_block="$(awk '/^## C43 /{f=1;print;next} /^## /{f=0} f' "$SKILL")"
c43_rows="$(grep -cE '^\| \([a-z]\) \*\*' <<<"$c43_block" || true)"
c43_head_n="$(sed -n 's/^## C43 \([0-9][0-9]*\)-path.*/\1/p' <<<"$c43_block" | head -1)"
c43_prose_n="$(sed -n 's/.*다음 \([0-9][0-9]*\) 경로 중.*/\1/p' <<<"$c43_block" | head -1)"
# 양성 대조 — 넷 중 하나라도 추출에 실패하면 아래 «같다» 비교가 공허해진다(빈 문자열끼리
# 같다고 통과할 수 있다). 앵커가 바뀌어 절을 못 뜨는 경우도 여기서 잡힌다.
{ [[ -n "$c43_block" ]] && [[ "${c43_rows:-0}" -ge 1 ]] \
  && [[ -n "$c43_head_n" ]] && [[ -n "$c43_prose_n" ]]; } \
  && ok "C43(양성대조): 절·표 행 ${c43_rows}개·헤딩 수·산문 수를 전부 추출 (아래 비교가 공허하지 않다)" \
  || no "C43(양성대조): 추출 실패 — rows=${c43_rows:-∅} head=${c43_head_n:-∅} prose=${c43_prose_n:-∅} (절을 못 떴거나 앵커가 바뀌었다)"
[[ "$c43_head_n" == "$c43_rows" ]] \
  && ok "C43: 헤딩이 선언한 경로 수 $c43_head_n == 표 행 수 $c43_rows" \
  || no "C43: 헤딩 «${c43_head_n:-∅}-path» 가 표 행 수 ${c43_rows:-∅} 와 다르다 — 모델이 없는 경로를 분류한다"
[[ "$c43_prose_n" == "$c43_rows" ]] \
  && ok "C43: 산문이 선언한 경로 수 $c43_prose_n == 표 행 수 $c43_rows" \
  || no "C43: 산문 «다음 ${c43_prose_n:-∅} 경로 중» 이 표 행 수 ${c43_rows:-∅} 와 다르다"

# 위 락의 코퍼스는 `SKILL.md` 뿐이라 **README 를 못 본다**. 그래서 README 안에서 87줄 떨어진
# 두 줄이 «4-path» 와 «3-path» 로 서로 모순한 채 릴리스까지 갔다 — 사용자가 가장 먼저 읽는
# 파일이다. 코퍼스를 넓힌다: `<n>-path` 를 적는 **모든** 우리 문서가 표 행 수와 같아야 한다.
# 파일을 열거하지 않고 grep 으로 도출하므로 새 문서가 같은 표기를 쓰면 자동으로 들어온다.
README="$REPO_ROOT/plugins/spec-distill/README.md"
path_claims="$(grep -ohE '[0-9]+-path' "$SKILL" "$README" | sort -u)"
[[ -n "$path_claims" ]] \
  && ok "C43(양성대조): «<n>-path» 표기를 찾았다 ($(tr '\n' ' ' <<<"$path_claims")) — 아래 단언이 실재한다" \
  || no "C43(양성대조): 어느 문서에도 «<n>-path» 표기가 없다 — 아래 단언이 공허하다"
[[ "$(wc -l <<<"$path_claims" | tr -d ' ')" == "1" && "$path_claims" == "${c43_rows}-path" ]] \
  && ok "C43: SKILL·README 의 «<n>-path» 표기가 하나뿐이고 표 행 수 $c43_rows 와 같다" \
  || { no "C43: «<n>-path» 표기가 여럿이거나 표 행 수 ${c43_rows} 와 다르다 — 문서끼리 모순한다"; \
       printf '    발견: %s\n' "$(tr '\n' ' ' <<<"$path_claims")"; }

# C51 5-type 라벨 강제는 이 릴리스가 없앴다(SKILL 본문·README 정의 불릿 모두 제거). 그런데
# 5 의례 요약표의 R1 행이 «(d) ontological 5-type» 으로 그 죽은 규칙을 계속 인용했다 —
# 독자가 본문보다 먼저 믿는 자리다. 코퍼스 전수로 막되, **«제거됐다»고 적은 줄은 위반이
# 아니다** — 그것은 죽은 규칙의 인용이 아니라 죽었다는 기록이다(README 의 v0.57.0 변경 설명).
# 그래서 단순 부재 검사가 아니라 «5-type 을 적은 모든 줄은 제거 표시를 함께 갖는다» 로 쓴다:
# 살아 있는 요구로 읽히는 인용만 RED 다. 부재 검사로 두면 정정 노트가 자기 락에 걸린다.
c51_live="$(grep -rn '5-type' "$SKILL" "$README" "$FIN" 2>/dev/null \
  | grep -vE '제거|폐기|없앴|삭제' || true)"
[[ -z "$c51_live" ]] \
  && ok "C51: «5-type» 을 살아 있는 요구로 인용하는 줄 0건 (SKILL·README·finishing 전수)" \
  || { no "C51: 삭제된 «5-type» 라벨 규칙이 살아 있는 요구처럼 인용된다 (요약표가 본문과 모순)"; \
       printf '    %s\n' "$c51_live"; }
# 양성 대조 — 위 단언은 «없으면 통과»라, 코퍼스를 못 읽어도(경로 오타·파일 이동) 조용히
# green 이다. 세 파일이 실재하고 읽히는지 먼저 못 박는다.
{ [[ -s "$SKILL" ]] && [[ -s "$README" ]] && [[ -s "$FIN" ]]; } \
  && ok "C51(양성대조): 코퍼스 세 파일을 실제로 읽었다 (위 부재 단언이 공허하지 않다)" \
  || no "C51(양성대조): 코퍼스 파일 중 비었거나 없는 것이 있다 — 위 단언이 공허하다"

# kill switch 는 보안 컨트롤이고 README 의 스위치 목록이 그 문서화된 등재부다. AC12 가
# SKILL 자신의 목록만 요구해서, 새 스위치가 SKILL·템플릿·CHANGELOG 에는 있는데 README
# 등재부에만 빠져도 어떤 락도 발화하지 않았다. 등재부를 «도출»로 채운다 — 리포가 아는
# 모든 `DEVBREW_SPEC_DISTILL_*` 스위치 이름이 README 목록에 있어야 한다.
ks_list="$(awk '/^### 스위치 목록/{f=1;next} /^### /{f=0} f' "$README")"
switches="$(grep -rhoE 'DEVBREW_SPEC_DISTILL_[A-Z_]*DISABLE[A-Z_]*' \
  "$REPO_ROOT/plugins/spec-distill/skills" "$REPO_ROOT/plugins/spec-distill/templates" \
  2>/dev/null | sort -u)"
[[ -n "$ks_list" && -n "$switches" ]] \
  && ok "C6(양성대조): README 스위치 목록과 코드의 스위치 이름을 둘 다 추출했다" \
  || no "C6(양성대조): 목록 또는 스위치 이름 추출 실패 — 아래 단언이 공허하다"
ks_missing=""
while IFS= read -r sw; do
  [[ -z "$sw" ]] && continue
  grep -qF "$sw" <<<"$ks_list" || ks_missing="$ks_missing $sw"
done <<<"$switches"
[[ -z "$ks_missing" ]] \
  && ok "C6: 코드가 읽는 모든 DEVBREW_SPEC_DISTILL_*DISABLE* 이 README 등재부에 있다" \
  || no "C6: README 스위치 목록에 없는 kill switch:$ks_missing — 등재부가 보안 컨트롤을 감춘다"

finish
