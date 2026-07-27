#!/usr/bin/env bash
# Spec B T8·T9·T14·T17·T21·T22·T23·T25·T28·T30 — reviewing-brief SKILL 계약 락.
# AC2(critic 경로 미제공) · AC3(readback 무스키마) · AC2b(probe 이진 분기) · AC7b(기각 금지)
# AC13(전이 표) · AC15(degradation record) · AC18(kill switch) · AC21(cost_class high + 게이트)
# AC22b(단일 호출 상한 0) · AC24(웹 예산) · AC25(G1–G5)
# 모든 블록 스코프 assert는 awk 윈도우로 걸린다 — 헤더 만족(header-satisfiable) 방지.
# Run: bash plugins/spec-distill/tests/test_reviewing_brief_skill.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
SKILL="$SD/skills/reviewing-brief/SKILL.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
# $1 = 시작 헤더 정규식 → 다음 '^### ' 직전까지
window() { awk -v pat="$1" '$0 ~ pat {inw=1; next} inw && /^#{1,3} / {exit} inw' "$SKILL"; }
has() { grep -qF -- "$2" <<<"$1"; }
# 윈도우 문자열 안의 첫 ```bash 펜스 본문만 추출 — T23의 record 확인을 코드 자체로 스코프한다
# (프롬프트/주석이 아니라 실행되는 bash 라인이 실제로 그 문자열을 담고 있는지).
fence() { awk '/^```bash$/{f=1;next} /^```$/{f=0;next} f' <<<"$1"; }
# 최소 라인수 가드 — window()가 fenced code block 안의 컬럼-0 주석에 조기 종료되면
# 안이 텅 빈 채(또는 크게 잘린 채)로 '-n' 체크만 통과하는 vacuous-window를 잡는다.
minlines() { local n; n="$(wc -l <<<"$1" | tr -d ' ')"; [[ "$n" -ge "$2" ]]; }

test -f "$SKILL" || { note FAIL "SKILL 부재: $SKILL"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$SKILL")"

# --- T17 / AC21 : cost_class high + 진입 승인 게이트 (조건 없음) --------------
grep -qE '^cost_class: high$' <<<"$FM" \
  && note PASS "T17: cost_class: high" || note FAIL "T17: cost_class가 high가 아님"
grep -qF 'AskUserQuestion' "$SKILL" \
  && note PASS "T17: 승인 게이트(AskUserQuestion) 서술 존재" || note FAIL "T17: 승인 게이트 서술 부재"
grep -qE '진입 (시 )?1회|진입 승인' "$SKILL" \
  && note PASS "T17: 진입 1회 승인 게이트 명시" || note FAIL "T17: 진입 승인 게이트 명시 부재"
# 외부 문서의 미래 결론에 조건부로 걸지 않는다 (spec §5.7 무조건 확정)
grep -qE 'sweep(의|이)? (결론|판단)에 따라|sweep 이후에 (결정|재검토)' "$SKILL" \
  && note FAIL "T17: 승인 게이트를 외부 문서 결론에 조건부로 걸었다" \
  || note PASS "T17: 승인 게이트가 무조건 확정"

# --- T14 / AC18 : 신규 kill switch --------------------------------------------
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW' "$SKILL" \
  && note PASS "T14: 신규 kill switch 실재" || note FAIL "T14: DEVBREW_DISABLE_SPEC_DISTILL_BRIEF_REVIEW 부재"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL=1' "$SKILL" \
  && note PASS "T14: 전역 kill switch 존중" || note FAIL "T14: 전역 kill switch 부재"
grep -qF 'DEVBREW_DISABLE_SPEC_DISTILL_CODEX' "$SKILL" \
  && note PASS "T14: codex kill switch 존중" || note FAIL "T14: codex kill switch 부재"
grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' "$SKILL" \
  && note PASS "T14: 웹 kill switch 존중" || note FAIL "T14: 웹 kill switch 부재"

# --- T8 / AC2 : critic dispatch 블록 안에 payload 경로가 없다 ----------------
W2A="$(window '^### 2-a\.')"
minlines "$W2A" 15 && note PASS "T8: '### 2-a. critic dispatch 블록' 윈도우 충분히 존재 (>=15줄)" \
               || note FAIL "T8: 2-a 윈도우가 비었거나 너무 짧다 (헤더 drift 또는 fence 내 컬럼-0 주석에 조기 절단 — 락이 스코프를 잃었다)"
has "$W2A" 'docs/superpowers/interview/' \
  && note FAIL "T8: critic dispatch 블록에 interview 디렉토리 경로" \
  || note PASS "T8: critic dispatch 블록에 payload 경로 부재"
has "$W2A" 'build_brief_inline_blob.py' \
  && note PASS "T8: critic 블록이 inline blob 빌더를 쓴다" || note FAIL "T8: blob 빌더 호출 부재"
has "$W2A" 'brief-critic' \
  && note PASS "T8: critic 블록이 brief-critic을 dispatch" || note FAIL "T8: brief-critic dispatch 부재"

# --- T9 / AC3 : readback dispatch 블록에 스키마 어휘가 없다 ------------------
W3A="$(window '^### 3-a\.')"
minlines "$W3A" 15 && note PASS "T9: '### 3-a. readback dispatch 블록' 윈도우 충분히 존재 (>=15줄)" \
               || note FAIL "T9: 3-a 윈도우가 비었거나 너무 짧다 (헤더 drift 또는 fence 내 컬럼-0 주석에 조기 절단 — 이 윈도우는 부재 확인 전용이라 절단되면 모든 negative assert가 vacuous하게 통과한다)"
for tok in 'category' 'severity' 'sentinel' 'JSON'; do
  has "$W3A" "$tok" && note FAIL "T9: readback 블록에 스키마 어휘 '$tok'" \
                    || note PASS "T9: readback 블록에 '$tok' 부재"
done
# AC3 — "audit을 읽지 마라" 류 금지 문구도 없다(존재 누설)
has "$W3A" 'audit' && note FAIL "AC3: readback 블록이 audit을 언급 (존재 누설)" \
                   || note PASS "AC3: readback 블록에 audit 언급 부재"

# --- T30 / AC25 : G1–G5는 SKILL에 있고 readback 블록에는 없다 ---------------
for g in G1 G2 G3 G4 G5; do
  grep -qF "$g" "$SKILL" && note PASS "T30: gap 클래스 $g 존재" || note FAIL "T30: gap 클래스 $g 누락"
done
grep -qF '전부 0건' "$SKILL" && note PASS "T30: '전부 0건이면 pass' 성공 조건" || note FAIL "T30: 성공 조건 부재"
grep -qE '세 조각|3조각' "$SKILL" && note PASS "T30: 3조각 보고 형식" || note FAIL "T30: 3조각 보고 형식 부재"
for tok in 'G1' 'gap 클래스' '미결을 확정으로'; do
  has "$W3A" "$tok" && note FAIL "T30: readback 블록에 gap 어휘 '$tok' (E13 — 기준을 알면 회피)" \
                    || note PASS "T30: readback 블록에 '$tok' 부재"
done

# --- T23 / AC2b · AC7 : probe 이진 분기 -------------------------------------
for tok in 'P1' 'P2' 'P3' 'canary' 'census' 'ZERO_TOOL_OK' 'ZERO_TOOL_UNAVAILABLE'; do
  grep -qF "$tok" "$SKILL" && note PASS "T23: probe 요소 '$tok' 열거" || note FAIL "T23: probe 요소 '$tok' 누락"
done
grep -qE 'probe (미실행|를 실행하지 않은).*진행(하지 않|을 금지)' "$SKILL" \
  && note PASS "T23: probe 미실행 시 진행 금지 서술" || note FAIL "T23: probe 미실행 금지 서술 부재"
WFAIL="$(awk '/^#### probe 실패 분기/{inw=1; next} inw && /^#{1,4} /{exit} inw' "$SKILL")"
minlines "$WFAIL" 9 && note PASS "T23: '#### probe 실패 분기' 윈도우 충분히 존재 (>=9줄)" || note FAIL "T23: 실패 분기 윈도우가 비었거나 너무 짧다 (조기 절단)"
has "$WFAIL" 'hard gate' && note FAIL "T23: 실패 분기에 'hard gate' 문구 (주장 > 보장)" \
                         || note PASS "T23: 실패 분기에 'hard gate' 문구 부재"
has "$WFAIL" 'advisory' && note PASS "T23: 실패 분기가 advisory 강등" || note FAIL "T23: advisory 강등 부재"
has "$WFAIL" 'D2' && note PASS "T23: 실패 분기가 D2 미충족 보고" || note FAIL "T23: D2 미충족 보고 부재"
WFAIL_BASH="$(fence "$WFAIL")"
has "$WFAIL_BASH" '--component critic' && note PASS "T23: 실패 분기 record — critic" || note FAIL "T23: critic record 부재 (실제 bash 호출 아님)"
has "$WFAIL_BASH" '--component readback' && note PASS "T23: 실패 분기 record — readback (2건)" \
                                  || note FAIL "T23: readback record 부재 (냉독 신뢰도 하향 신호 없음 · 실제 bash 호출 아님)"
WOK="$(awk '/^#### probe 통과 분기/{inw=1; next} inw && /^#{1,4} /{exit} inw' "$SKILL")"
# WOK에는 minlines 가드를 두지 않는다 — 자연 크기가 이미 2줄(빈 줄 + 문장 1개)이라 truncation을
# 걸러낼 여유 임계값이 존재하지 않는다(2로 잡아도 절단된 필러가 그대로 통과함, 직접 확인함).
# 이 윈도우의 유일한 assert가 POSITIVE('hard gate' 존재)이므로 truncation은 그 자체로 이미 걸린다
# (문장이 잘려나가면 'hard gate' 부재로 자연히 fail) — W3A류의 all-negative 취약점과는 다른 케이스.
has "$WOK" 'hard gate' && note PASS "T23: 통과 분기가 hard gate" || note FAIL "T23: 통과 분기에 hard gate 부재"

# --- T22 / AC15 : degradation record ----------------------------------------
grep -qF 'brief_review_degradations' "$SKILL" \
  && note PASS "T22: state 키 brief_review_degradations" || note FAIL "T22: state 키 부재"
for f in 'component' 'reason' 'affected_axis' 'verification_status'; do
  grep -qF "$f" "$SKILL" && note PASS "T22: record 필드 '$f'" || note FAIL "T22: record 필드 '$f' 누락"
done
grep -qE 'question 텍스트' "$SKILL" \
  && note PASS "T22: Step B question 텍스트 렌더 (옵션 description 아님)" || note FAIL "T22: question 텍스트 렌더 서술 부재"
grep -qE '빈 배열|비면' "$SKILL" \
  && note PASS "T22: 빈 배열도 'degrade 없음'으로 명시" || note FAIL "T22: 빈 배열 명시 부재"
grep -qF 'retried' "$SKILL" \
  && note FAIL "T22: 삭제된 'retried' 값 재도입" || note PASS "T22: 'retried' 부재"
# §5.6 실패표의 모든 행이 record를 규정한다 — escalate 행 포함
grep -qE '상한 2 초과.*record|record.*상한 2 초과|재리뷰 상한 2 초과' "$SKILL" \
  && note PASS "T22: 재리뷰 상한 초과 escalate 행도 record 규정" || note FAIL "T22: escalate 행 record 누락"

# --- T21 / AC24 : 웹 예산 (dispatch 단위) -----------------------------------
grep -qF 'web_budget.py' "$SKILL" && note PASS "T21: web_budget.py 참조" || note FAIL "T21: web_budget.py 부재"
grep -qE 'dispatch (전|이전).*check|check.*dispatch (전|이전)' "$SKILL" \
  && note PASS "T21: dispatch 전 check 서술" || note FAIL "T21: dispatch 전 check 서술 부재"
grep -qE 'dispatch (후|이후).*increment|increment.*1회' "$SKILL" \
  && note PASS "T21: dispatch 후 increment 1회 서술" || note FAIL "T21: dispatch 후 increment 서술 부재"
grep -qF 'dispatch 단위' "$SKILL" \
  && note PASS "T21: 계측 단위가 dispatch임을 명시" || note FAIL "T21: 계측 단위 명시 부재 (호출 단위 오독)"
grep -qE 'Bash.*(없|부재)' "$SKILL" \
  && note PASS "T21: 리뷰어에 Bash 부재 → orchestrator 책임 명시" || note FAIL "T21: Bash 부재 근거 서술 없음"

# --- T25 / AC7b : finding 임의 기각 금지 -----------------------------------
grep -qE '임의(로)? 기각(하지|할 수) (못|없)' "$SKILL" \
  && note PASS "T25: 저자 임의 기각 금지" || note FAIL "T25: 기각 금지 서술 부재"
grep -qE '미반영 findings.*(이유|근거).*Step B|Step B.*미반영 findings' "$SKILL" \
  && note PASS "T25: 미반영 findings를 이유와 함께 Step B로" || note FAIL "T25: 미반영 findings 이월 서술 부재"

# --- T28 / AC22b : 횟수 상한은 루프 문맥 하나에만 ----------------------------
CAP_RE='최대 [0-9]+회|[0-9]+회까지|max_[a-zA-Z_]+ *= *[0-9]'
total="$(grep -cE "$CAP_RE" "$SKILL" || true)"
W2C="$(window '^### 2-c\.')"
inloop="$(grep -cE "$CAP_RE" <<<"$W2C" || true)"
minlines "$W2C" 25 && note PASS "T28: '### 2-c. 충실도 루프 전이' 윈도우 충분히 존재 (>=25줄)" || note FAIL "T28: 2-c 윈도우가 비었거나 너무 짧다 (조기 절단)"
[[ "$total" -ge 1 ]] && note PASS "T28: 상한 표현이 실재 ($total)" || note FAIL "T28: 상한 표현이 0 — 루프 가드가 없다"
[[ "$total" == "$inloop" ]] && note PASS "T28: 상한 표현이 루프 문맥에만 ($inloop/$total)" \
  || note FAIL "T28: 루프 문맥 밖 상한 표현 $((total-inloop))건 (E10 위반)"

# --- AC13 : 전이 표 경계값 --------------------------------------------------
has "$W2C" 'brief_critic_rounds' && note PASS "AC13: 카운터 이름" || note FAIL "AC13: 카운터 이름 부재"
grep -qE '== ?2' <<<"$W2C" && note PASS "AC13: escalate 경계값 == 2" || note FAIL "AC13: 경계값 명시 부재"
has "$W2C" 'can-redispatch' && note PASS "AC13: can-redispatch 게이트 사용" || note FAIL "AC13: 게이트 호출 부재"
grep -qE '최초 리뷰.*0 유지|0 유지.*최초' <<<"$W2C" \
  && note PASS "AC13: 최초 리뷰는 카운터 0 유지" || note FAIL "AC13: 최초 리뷰 규칙 부재"
grep -qE 'fresh critic.*(필수|1회)' "$SKILL" \
  && note PASS "AC13/E8: 수정 후 fresh critic 재리뷰 1회 필수" || note FAIL "AC13/E8: fresh 재리뷰 필수 서술 부재"

# --- AC1 : 파이프라인 순서 + 진입 첫 액션 ------------------------------------
grep -qF 'check_verbatim_coverage.py' "$SKILL" \
  && note PASS "AC1: 완전성 검사 호출" || note FAIL "AC1: check_verbatim_coverage.py 부재"
grep -qE '첫 액션' "$SKILL" && note PASS "AC1: 진입 첫 액션 명시" || note FAIL "AC1: 첫 액션 명시 부재"
for code in 'exit 1' 'exit 3' 'exit 4'; do
  grep -qF "$code" "$SKILL" && note PASS "AC1/AC12: 호출자가 $code 분기" || note FAIL "AC1/AC12: $code 분기 부재"
done
# 순서: 방향성 → 충실도 → 냉독. 각 헤더 "고유 텍스트"의 실제 라인 번호로 비교한다 — 세 개의
# "## N단계" 헤더가 *존재*하기만 해도 file-order라 항상 참이 되는 tautology(헤더 텍스트를
# 무시하고 카운트만 봄)를 피한다. 세 헤더를 서로 바꿔치기해도(swap) 이 비교는 잡아낸다.
l1="$(grep -nE '^## 1단계 — 방향성' "$SKILL" | head -1 | cut -d: -f1)"
l2="$(grep -nE '^## 2단계 — 충실도' "$SKILL" | head -1 | cut -d: -f1)"
l3="$(grep -nE '^## 3단계 — 냉독' "$SKILL" | head -1 | cut -d: -f1)"
if [[ -n "$l1" ]] && [[ -n "$l2" ]] && [[ -n "$l3" ]] && [[ "$l1" -lt "$l2" ]] && [[ "$l2" -lt "$l3" ]]; then
  note PASS "AC1: 1단계(방향성) → 2단계(충실도) → 3단계(냉독) 순서"
else
  note FAIL "AC1: 단계 헤더 순서가 어긋나거나 부재함 (1단계=${l1:-없음} 2단계=${l2:-없음} 3단계=${l3:-없음})"
fi
grep -qE '^## 1단계 — 방향성' "$SKILL" && note PASS "AC1: 1단계가 방향성" || note FAIL "AC1: 1단계 헤더가 방향성이 아님"
grep -qE '^## 2단계 — 충실도' "$SKILL" && note PASS "AC1: 2단계가 충실도" || note FAIL "AC1: 2단계 헤더가 충실도가 아님"
grep -qE '^## 3단계 — 냉독' "$SKILL" && note PASS "AC1: 3단계가 냉독" || note FAIL "AC1: 3단계 헤더가 냉독이 아님"

# --- 방향성은 병합하지 않는다 (verdict 없음) --------------------------------
grep -qE '방향성(은|을)? 병합하지 않' "$SKILL" \
  && note PASS "AC6: 방향성 미병합 명시" || note FAIL "AC6: 방향성 미병합 명시 부재"
grep -qF 'merge_brief_review.py' "$SKILL" \
  && note PASS "AC7: 충실도 병합 스크립트 호출" || note FAIL "AC7: merge_brief_review.py 부재"

# --- codex 축별 2회 --------------------------------------------------------
n_codex="$(grep -cE '^[[:space:]]*bash "\$PR/scripts/run_brief_codex_reviewer\.sh" (direction|fidelity) ' "$SKILL" || true)"
[[ "$n_codex" -ge 2 ]] && note PASS "AC6: codex 축별 2회 호출 서술 ($n_codex)" || note FAIL "AC6: codex 호출이 $n_codex 건"
grep -qF 'detect_codex.sh' "$SKILL" && note PASS "AC9: detect_codex.sh 선행 확인" || note FAIL "AC9: detect_codex.sh 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
