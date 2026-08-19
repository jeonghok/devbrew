#!/usr/bin/env bash
# Spec B T15·T18·T29·T31(문서) — 메타데이터 · 훅 무증가 · 결정론 체크 열거표 · 정규화 계약.
# AC19(메타데이터) · AC22a(훅 0 추가) · AC22c(이빨 없는 체크 0 + 전수 열거) · AC11(N1–N5 순서·NFC)
# Run: bash plugins/spec-distill/tests/test_brief_review_meta.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
PJ="$SD/.claude-plugin/plugin.json"
CL="$SD/CHANGELOG.md"
RM="$SD/README.md"
HOOKS="$SD/hooks"
SPEC="$REPO_ROOT/docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
section() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^## / {exit} inw' "$2"; }

# --- T15 / AC19 : 메타데이터 (minor floor, patch unpin) ---------------------
# 정확한-minor pin(`0\.25\.[0-9]+`)은 "이 버전 이후 shipping" 의도를 표현하지 못하고
# "정확히 이 minor"만 표현한다 — 다음 minor bump마다 stale-red가 된다(Task 14 실증,
# qg 쪽 floor 관용구 test_qg_publish_docs.sh·test_artifact_metadata.sh와 동형화).
# floor로 전환: 0.26 이상이면 통과, 그 아래면 실패.
grep -qE '"version": "0\.(2[6-9]|[3-9][0-9])\.[0-9]+"' "$PJ" \
  && ok "T15: plugin.json >= 0.26.x" || no "T15: plugin.json이 0.26 floor 미만"
grep -qE '^## \[0\.24\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CL" \
  && ok "T15: CHANGELOG [0.24.0] + ISO 날짜" || no "T15: CHANGELOG [0.24.0] 누락/비-ISO"
# append-only 누산 — 과거 엔트리 pin은 절대 빼지 않는다.
# 정규식(`0\.20\.0`)과 사람이 읽을 라벨(`0.20.0`)을 분리한다 — 하나로 쓰면 실패 메시지에
# 이스케이프된 정규식이 그대로 찍혀("[0\.20\.0]가 사라졌다") 읽는 사람이 CHANGELOG에서
# 그 문자열을 찾다 헤맨다.
for v in '0.20.0' '0.22.0' '0.23.0'; do
  v_re="${v//./\\.}"
  grep -qE "^## \[$v_re\]" "$CL" && ok "T15: CHANGELOG 과거 엔트리 [$v] 보존" \
                                 || no "T15: 과거 엔트리 [$v]가 사라졌다 (append-only 위반)"
done
PRIN="$(section '^## Principles Instantiated' "$RM")"
# 두 섹션 캡처를 이어붙일 때는 **구분자를 명시**한다. `"$A$(f B)"`는 A의 마지막 줄과 B의
# 첫 줄을 한 줄로 붙여, 경계에 걸친 유령 매치를 만들 수 있다(오늘 안전한 이유는 Flow
# 섹션의 첫 줄이 마침 빈 줄이라서일 뿐 — 그 우연이 사라지면 조용히 성립이 바뀐다).
RM_SCAN="$(printf '%s\n%s\n' "$PRIN" "$(section '^## Flow' "$RM")")"
for kw in 'brief-critic' 'brief-direction-reviewer' 'brief-readback' 'reviewing-brief'; do
  grep -qF "$kw" <<<"$RM_SCAN" \
    && ok "T15: README에 신규 컴포넌트 '$kw'" || no "T15: README에 '$kw' 부재"
done
KS="$(section '^## Kill switches' "$RM")"
grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW' <<<"$KS" \
  && ok "T15: README Kill switches에 신규 스위치" || no "T15: 신규 kill switch 미문서화"
grep -qF 'Law 2' <<<"$PRIN" && ok "T15: Principles Instantiated에 Law 2" || no "T15: Law 2 항목 부재"

# --- C4 : Flow **다이어그램**이 리뷰 단계를 통과한다 -------------------------
# 위 T15 스윕은 `$PRIN$(section Flow)` 전체에서 컴포넌트 이름을 찾으므로, 다이어그램에서
# 리뷰 단계를 통째로 지워도 아래 v0.24.0 산문 한 문단이 같은 이름들을 실어 계속 green이다
# (헤더 만족과 같은 클래스). 그래서 **펜스 안의 다이어그램만** 따로 지목한다 — 이 파일이
# `## Flow (v0.24.0)`으로 버전을 주장하는 이상, 그 버전의 경로가 그림에 있어야 한다.
FLOW="$(section '^## Flow' "$RM")"
DIAGRAM="$(awk '/^```/{f=!f; next} f' <<<"$FLOW")"
minlines_ok() { [[ "$(wc -l <<<"$1" | tr -d ' ')" -ge "$2" ]]; }
minlines_ok "$DIAGRAM" 10 \
  && ok "C4: Flow 다이어그램 펜스 실재 (>=10줄)" \
  || no "C4: Flow 다이어그램을 못 찾았다 (펜스 불균형 또는 삭제) — 아래 assert가 vacuous해진다"
grep -qF 'reviewing-brief' <<<"$DIAGRAM" \
  && ok "C4: 다이어그램이 reviewing-brief 단계를 그린다" \
  || no "C4: 다이어그램에 리뷰 단계가 없다 — brief가 Step B로 직행하는 옛 경로를 그리고 있다"
# 순서: brief 산출 → 리뷰 → Step B 게이트. 존재만 잠그면 리뷰 단계를 게이트 **뒤**로
# 옮겨도 통과한다(리뷰는 게이트 전에 끝나야 산출물 4종이 게이트에 실린다).
i_brief="$(grep -nF 'interview brief' <<<"$DIAGRAM" | head -1 | cut -d: -f1)"
i_rev="$(grep -nF 'reviewing-brief' <<<"$DIAGRAM" | head -1 | cut -d: -f1)"
i_gate="$(grep -nF 'Step B proceed 게이트' <<<"$DIAGRAM" | head -1 | cut -d: -f1)"
if [[ -n "$i_brief" && -n "$i_rev" && -n "$i_gate" ]] \
   && [[ "$i_brief" -lt "$i_rev" ]] && [[ "$i_rev" -lt "$i_gate" ]]; then
  ok "C4: 다이어그램 순서 — brief 산출 → 분리 리뷰 → Step B 게이트"
else
  no "C4: 다이어그램 순서 위반 (brief=${i_brief:-없음} review=${i_rev:-없음} gate=${i_gate:-없음})"
fi
# 고아 리스트 번호 금지 — 이 섹션은 버전 노트 문단들만 있고 붙을 리스트가 없다.
ORPHAN="$(grep -nE '^[0-9]+\.[0-9]*\.? ' <<<"$FLOW" || true)"
[[ -z "$ORPHAN" ]] \
  && ok "C4: Flow 섹션에 고아 리스트 번호 없음" \
  || no "C4: Flow 섹션에 붙을 리스트가 없는 번호 항목: ${ORPHAN}"
# codex kill switch가 brief 파이프라인까지 문서화됐는가 (design-doc 경로만 적혀 있었다)
KS_CODEX="$(grep -F 'DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1' <<<"$KS" | head -1)"
{ grep -qF 'reviewing-brief' <<<"$KS_CODEX" && grep -qE '3곳|세 곳' <<<"$KS_CODEX"; } \
  && ok "C4: codex kill switch가 brief 파이프라인 호출 지점까지 문서화" \
  || no "C4: codex kill switch가 design-doc 경로만 말한다 — brief 3개 호출 지점이 미문서화"

# --- T18 / AC22a : 훅 집합 고정 열거 + 'brief' 문자열 0건 --------------------
EXPECTED="hooks.json pending-review-reminder.py review-dispatch.py session-end-cleanup.py spec-write-validator.py"
ACTUAL="$(cd "$HOOKS" && ls -1 | sort | tr '\n' ' ' | sed 's/ $//')"
EXPECTED_SORTED="$(tr ' ' '\n' <<<"$EXPECTED" | sort | tr '\n' ' ' | sed 's/ $//')"
[[ "$ACTUAL" == "$EXPECTED_SORTED" ]] \
  && ok "T18: hooks/ 집합이 고정 열거와 정확히 일치 (5개)" \
  || no "T18: hooks/ 집합 불일치 — 기대[$EXPECTED_SORTED] 실제[$ACTUAL]"
n_brief="$(grep -cF 'brief' "$HOOKS/hooks.json" || true)"
[[ "$n_brief" == "0" ]] && ok "T18: hooks.json에 'brief' 문자열 0건" \
                        || no "T18: hooks.json에 'brief' ${n_brief}건 (훅 표면 확장)"

# --- T29 / AC22c : 결정론 체크 전수 열거표 ----------------------------------
# 윈도우 종료는 진입과 같은 레벨(###)뿐 아니라 상위 레벨(##)에서도 exit해야 한다.
# `/^## /`만 걸면 형제 `### 6.4`를 못 잡고 넘어가 표가 §6.4까지 흡수 — 오늘은 §6.3이
# §6 마지막 하위섹션이라 우연히 무해했을 뿐, 문서 구조가 바뀌면 열거 누락도 조용히
# green이 된다(round-2 리뷰가 지적한 shape (c)). `/^### /`만으로 바꾸면 반대로
# `## 7.` 같은 상위 헤더를 못 잡아 EOF까지 흘러가므로, 두 레벨 모두에서 exit한다.
# 가드는 **양쪽 분기 모두** note를 부른다. `test -f … || no` 형태만 두면 파일이
# 있는 정상 경로에서 note가 한 번도 안 불려, 출력되는 Total이 어느 분기를 탔느냐에 따라
# 달라진다(총계가 조건부면 "몇 개가 돌았나"를 신뢰할 수 없다).
test -f "$SPEC" && ok "T29: spec 문서 실재" || no "T29: spec 문서 부재: $SPEC"
T63="$(awk '/^### 6\.3/{inw=1; next} inw && /^#{2,3} /{exit} inw' "$SPEC")"
[[ -n "$T63" ]] && ok "T29: spec §6.3 열거표 실재" || no "T29: §6.3 표 부재"
for chk in 'check_verbatim_coverage' 'zero-tool probe' 'merge_brief_review' 'T-lock'; do
  grep -qF "$chk" <<<"$T63" && ok "T29: 열거표에 '$chk'" || no "T29: 열거표에 '$chk' 누락"
done
grep -qF '누가' <<<"$T63" && ok "T29: '누가 쓰는가' 열 존재" || no "T29: '누가 쓰는가' 열 부재"
# 삭제된 어휘-검출 체크를 요구하지 않는다 (round-4가 잡은 dangling)
grep -qE '어휘 검출|오염 검출|contamination' <<<"$T63" \
  && no "T29: 삭제된 검출 메커니즘을 열거표가 요구" || ok "T29: 삭제된 검출 요구 부재"
# 신규 결정론 체크가 표에 빠지지 않았는가 — 구현된 스크립트 목록과 대조
for s in check_verbatim_coverage merge_brief_review; do
  test -f "$SD/scripts/$s.py" \
    && ok "T29: ${s}.py 실재" \
    || no "T29: ${s}.py 부재 (Task 순서 이상)"
done

# --- C5 : §6.3 열거 **완전성** 기계 (design doc은 이 사이클에서 read-only) ----
# 표 스스로 "기계는 표의 존재와 열거 완전성(신규 결정론 체크 전부가 표에 있는지)만 본다"고
# 적어놓았지만, 위 리터럴 4개 존재 확인에는 그 기계가 없었다 — 표에 없는 결정론 체크를
# 잡을 수단이 0이었다. 아래가 실제 열거 대조다.
#
# 판정 대상 = 파이프라인이 **게이트 결정이나 degrade 강등에 쓰는** 결정론 체크.
DET_CHECKS="check_brief.py check_verbatim_coverage zero-tool merge_brief_review T-lock build_brief_inline_blob brief_review_state"
# 아래 둘은 shipping에 실재하지만 §6.3 표에 **행이 없다**. design doc 수정은 사람 몫이라
# (이 사이클에서 문서는 read-only) 여기에 이름을 박아 gap을 greppable·강제 가능하게 만든다:
#   - build_brief_inline_blob.py : 본문 audit 파일명 잔존 → exit 3 (호출자가 degrade 기록)
#   - brief_review_state.py      : 닫힌 열거 검증 + rounds clamp + can-redispatch 게이트.
#     특히 can-redispatch의 통과 조건은 `brief_critic_rounds`이고 그 값을 **orchestrator
#     자신이 쓴다** — 표가 존재하는 이유인 "검사 대상이 통과 조건을 직접 쓴다" 범주다.
#     사람이 표에 행을 추가할 때 이빨 등급도 함께 판정해야 한다(기계가 못 하는 부분).
DESIGN_GAP="build_brief_inline_blob brief_review_state"
missing=""
for chk in $DET_CHECKS; do
  grep -qF "$chk" <<<"$T63" || missing="${missing}${missing:+ }${chk}"
done
if [[ "$missing" == "$DESIGN_GAP" ]]; then
  ok "C5: §6.3 미기재 체크가 선언된 gap 목록과 정확히 일치 (${DESIGN_GAP}) — 사람 amendment 대기"
elif [[ -z "$missing" ]]; then
  no "C5: 표가 전부 채워졌다 — DESIGN_GAP 선언을 비우고 이 분기를 제거하라(waiver가 stale)"
else
  no "C5: §6.3 열거 gap이 선언과 다르다 — 미기재[${missing}] 선언[${DESIGN_GAP}]. 새 결정론 체크가 표 없이 들어왔거나 표에서 행이 사라졌다"
fi

# --- T31(문서) / AC11 : 정규화 순서·NFC 계약이 spec에 명시 -------------------
# T63과 같은 이유로 진입·종료 레벨을 맞춘다 — `/^### /`만으로는 §5.5가 §5의 마지막
# 하위섹션이 되는 순간 `## 6.`을 못 잡고 넘어간다.
S55="$(awk '/^### 5\.5/{inw=1; next} inw && /^#{2,3} /{exit} inw' "$SPEC")"
grep -qF 'N1 → N2 → N3 → N4 → N5' <<<"$S55" \
  && ok "T31: 고정 순서 N1 → N5 명시" || no "T31: 고정 순서 명시 부재"
grep -qE 'N3보다 N1이 (반드시 )?먼저' <<<"$S55" \
  && ok "T31: 'N3보다 N1이 먼저' 근거 명시" || no "T31: 순서 근거 부재"
grep -qE 'NFC' <<<"$S55" && ok "T31: N5가 NFC" || no "T31: NFC 명시 부재"
grep -qE '전각/반각(은|을)? \*\*접지 않는다\*\*|접지 않는다' <<<"$S55" \
  && ok "T31: 폭-접기를 주장하지 않음" || no "T31: 폭-접기 주장 잔존"
grep -qF 'NFKC' <<<"$S55" && ok "T31: NFKC 미채택 근거 존재" || no "T31: NFKC 미채택 근거 부재"
# 구현이 문서와 일치하는가 (문서만 고치고 코드를 안 고치는 비대칭 방지)
grep -qF 'unicodedata.normalize("NFC"' "$SD/scripts/check_verbatim_coverage.py" \
  && ok "T31: 구현이 NFC를 쓴다" || no "T31: 구현이 NFC가 아니다 (문서-코드 drift)"

# --- E10 : 신규 결정론 체크가 이빨 없는 의례를 도입하지 않았는가 -------------
# skills/reviewing-brief/SKILL.md:359는 이 패턴을 이름으로 지목해 "넣지 않는다"고
# 기각하는 서술이다 — 원래 assertion(단일 grep)은 그 문장 자체와 매치해 항상 FAIL하는
# 오탐이었다(문서가 안티패턴을 *기술*하는 것과 실제로 *도입*하는 것을 구분 못 함).
# 같은 줄에 부정 문맥이 있으면 서술로 보고 제외한다 — 단 "않습니다"는 제외 목록에
# 넣지 않는다: 그건 일반 한국어 부정 종결어미일 뿐 안티패턴을 "기각한다"는 표지가
# 아니다("리뷰 라운드 기록이 존재하지 않습니다"처럼 정확히 그 안티패턴을 실행하는
# 에러 메시지에도 등장한다 — round-2 리뷰가 잡은 false negative). 관행 자체를
# 부정하는 어구(넣지 않/도입하지 않)만 남긴다 — 검사 대상 자신이 그 어구까지 함께
# 조작하지 않는 한 통과 조건을 못 바꾼다는 뜻은 아니다(§6.3의 T-lock 계열과 같은
# 한계). 분류 정확성은 V8(사람) 몫 — 기계는 열거만 본다.
E10_HITS="$(grep -rnE '리뷰 라운드 기록이 (있는가|존재)' "$SD/scripts" "$SD/skills" 2>/dev/null \
  | grep -vE '넣지 않|도입하지 않')"
[[ -z "$E10_HITS" ]] \
  && ok "AC22c: 이빨 없는 기록 검사 부재(서술 언급 제외)" \
  || no "AC22c: 이빨 없는 '리뷰 라운드 기록' 검사가 도입됐다: ${E10_HITS}"
finish
