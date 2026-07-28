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
# $1 = 시작 헤더 정규식, $2 = 종료 판단 헤딩 정규식 → fence-aware: ``` 펜스 안에서는 종료
# 조건을 무시한다(펜스 안의 컬럼-0 bash 주석이 헤딩처럼 보여 조기 종료시키는 것을 막는다 —
# 그 상태에서도 '-n'/존재 체크만으로는 잘린 윈도우가 통과해버려 안의 negative assert가
# 전부 vacuous하게 PASS한다, 특히 W3A처럼 assert가 전부 negative인 윈도우에서 치명적).
scoped_window() {
  awk -v pat="$1" -v endpat="$2" '
    $0 ~ pat {inw=1; next}
    inw && /^```/ {fence=!fence}
    inw && !fence && $0 ~ endpat {exit}
    inw
  ' "$SKILL"
}
# $1 = 시작 헤더 정규식 → 다음 '^### ' 직전까지(fence-aware, 위 참고)
window() { scoped_window "$1" '^#{1,3} '; }
has() { grep -qF -- "$2" <<<"$1"; }
# 윈도우 문자열 안의 ```bash 펜스 본문 중 "실행되는" 라인만 추출(컬럼-0/들여쓰기 bash 주석은
# 버린다 — 주석 처리해서 실행되지 않는 줄이 grep에는 그대로 잡히는 것을 막는다). 펜스가
# 여러 개면 전부 이어붙인다(첫 번째만이 아니다) — 지금 쓰이는 윈도우엔 항상 하나뿐이라
# 실제 영향은 없지만, "첫 펜스만"이라고 쓰면 코드가 하는 일과 다른 거짓 주석이 된다.
fence() { awk '/^```bash$/{f=1;next} /^```$/{f=0;next} f && $0 !~ /^[[:space:]]*#/' <<<"$1"; }
# $1 = 분기를 여는 `if` 라인 정규식, $2 = 대상 텍스트 → 그 분기의 **본문**만 낸다(여는 if와
# **같은 들여쓰기**의 else/fi 직전까지). 종료를 들여쓰기로 판정하는 이유: 중첩 if의 else/fi에서
# 조기 종료하면 본문이 잘려 안의 positive assert가 거짓 RED를 낸다(2-c는 can==0 분기 안에
# codex 가용성 if가 중첩돼 있어 실재하는 조건이다). 분기가 아예 없으면 빈 출력 → 안의
# positive assert가 자연히 RED다(분기 존재까지 이 helper 하나가 함께 커버한다).
# 패턴은 `-v`가 아니라 ENVIRON으로 넘긴다 — `awk -v`는 대입값의 escape sequence를 처리해서
# `\[\[`가 `[[`로 뭉개진다(실측: `\[\[ "\$gate_rc"` 패턴이 그 자리에서 아무것도 매치하지
# 못했다). 이 파일의 scoped_window()가 `-v`로 무사한 것은 그 패턴들이 `\.`밖에 안 써서
# 뭉개져도 `.`이 같은 자리를 매치하기 때문이고, 여기 패턴에는 그 우연이 없다.
branch_body() {
  BB_PAT="$1" awk '
    !inb && $0 ~ ENVIRON["BB_PAT"] { match($0, /^[[:space:]]*/); ind = substr($0, 1, RLENGTH); inb = 1; next }
    inb && $0 ~ "^" ind "(else|fi)[[:space:]]*$" { exit }
    inb
  ' <<<"$2"
}
# 최소 라인수 가드 — fence-comment로 인한 조기 종료는 이제 scoped_window() 자체가 막는다
# (그게 이 가드가 났던 원래 이유였다). 이건 그 자리를 대신하는 backstop이 아니라 *부차적인*
# defense-in-depth: 펜스와 무관한 이유로 섹션이 크게 깎여나가는 미래의 편집 사고를 잡는다.
minlines() { local n; n="$(wc -l <<<"$1" | tr -d ' ')"; [[ "$n" -ge "$2" ]]; }

test -f "$SKILL" || { note FAIL "SKILL 부재: $SKILL"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

FM="$(awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$SKILL")"

# --- T17 / AC21 : cost_class high + 진입 승인 게이트 (조건 없음) --------------
grep -qE '^cost_class: high$' <<<"$FM" \
  && note PASS "T17: cost_class: high" || note FAIL "T17: cost_class가 high가 아님"
# 앵커: 실제 호출 라인(`AskUserQuestion({`). 순수 substring은 "AskUserQuestion으로 승인을
# 받습니다" 같은 산문 한 줄로 satisfiable하다 — 게이트는 서술이 아니라 호출이다.
grep -qE '^[[:space:]]*AskUserQuestion\(\{' "$SKILL" \
  && note PASS "T17: 승인 게이트(AskUserQuestion 호출 라인) 실재" || note FAIL "T17: 승인 게이트 호출 라인 부재 (산문 mention은 게이트가 아니다)"
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

# --- 윈도우 전제조건 : 코드 펜스 균형 ----------------------------------------
# scoped_window()의 fence 토글은 문서의 ``` 마커가 짝을 이룬다는 전제 위에서만 성립한다.
# 마커가 홀수면 토글이 뒤집힌 채로 남아 종료 헤딩이 전부 무시되고 윈도우가 EOF까지
# 흘러넘친다(실측: W2A 25줄 → 160줄, 즉 EOF까지). 그 상태에서 negative assert는 오히려 강해지지만
# (fail-closed), positive·containment assert는 **다른 섹션의 텍스트**로 충족되어 조용히
# green이 된다 — 실측 2건: (1) 2-a의 blob 빌더 호출을 지우고 2-a 펜스를 하나 깨뜨리면
# T8이 green으로 되돌아갔고(펜스가 멀쩡하면 정상 RED), (2) '## 3단계' 서문에 상한 문장을
# 넣고 2-c 펜스를 깨뜨리면 T28이 green으로 되돌아갔다(펜스가 멀쩡하면 정상 RED).
# 펜스 마커가 하나 빠지는 것은 위장이 아니라 흔한 편집 사고다 — 어떤 리터럴도 보존하지
# 않으므로 이 태스크의 위협 모델(선의의 저자가 저지르는 사고) 안에 있다.
n_fence="$(grep -c '^```' "$SKILL" || true)"
if [[ "$n_fence" -gt 0 ]] && [[ "$((n_fence % 2))" -eq 0 ]]; then
  note PASS "펜스 균형: 코드 펜스 마커 ${n_fence}개 — 짝수(균형), 윈도우 스코프 유효"
else
  note FAIL "펜스 불균형: 코드 펜스 마커 ${n_fence}개 — 홀수(닫히지 않은 코드 펜스). scoped_window()가 종료 헤딩을 무시하고 윈도우가 EOF까지 흘러넘쳐, 모든 블록 스코프 락이 다른 섹션 텍스트로 충족 가능해진다"
fi

# --- T8 / AC2 : critic dispatch 블록 안에 payload 경로가 없다 ----------------
W2A="$(window '^### 2-a\.')"
minlines "$W2A" 15 && note PASS "T8: '### 2-a. critic dispatch 블록' 윈도우 충분히 존재 (>=15줄)" \
               || note FAIL "T8: 2-a 윈도우가 비었거나 너무 짧다 (헤더 drift 또는 예상 밖 조기 절단 — 락이 스코프를 잃었다. fence-comment 절단은 scoped_window()가 이미 막으므로 이 가드는 부차적 defense-in-depth)"
has "$W2A" 'docs/superpowers/interview/' \
  && note FAIL "T8: critic dispatch 블록에 interview 디렉토리 경로" \
  || note PASS "T8: critic dispatch 블록에 payload 경로 부재"
# 아래 두 assert는 **실행 라인 앵커**다. 순수 substring(`has`)은 같은 문구를 품은 산문
# 한 줄로 satisfiable하고, 이 파일의 fence()는 `#` 주석만 거른다 — 실측된 데코이 클래스다
# (bash 펜스 안 산문 / javascript 펜스 안 산문 둘 다). CR-3 assert가 이미 쓰는 관용구를 따른다.
grep -qE '^[[:space:]]*BLOB="\$\(python3 "\$PR/scripts/build_brief_inline_blob\.py" ' <<<"$W2A" \
  && note PASS "T8: critic 블록이 inline blob 빌더를 실행 라인으로 호출 (줄-시작 앵커)" || note FAIL "T8: blob 빌더 호출 라인 부재 (같은 문구의 산문으로는 만족되지 않는다)"
grep -qE '^[[:space:]]*subagent_type: "spec-distill:brief-critic"' <<<"$W2A" \
  && note PASS "T8: critic 블록이 brief-critic을 dispatch 라인으로 지목 (줄-시작 앵커)" || note FAIL "T8: brief-critic dispatch 라인 부재"

# --- T9 / AC3 : readback dispatch 블록에 스키마 어휘가 없다 ------------------
W3A="$(window '^### 3-a\.')"
minlines "$W3A" 15 && note PASS "T9: '### 3-a. readback dispatch 블록' 윈도우 충분히 존재 (>=15줄)" \
               || note FAIL "T9: 3-a 윈도우가 비었거나 너무 짧다 (헤더 drift 또는 예상 밖 조기 절단 — 이 윈도우는 부재 확인 전용이라 절단되면 모든 negative assert가 vacuous하게 통과한다. fence-comment 절단은 scoped_window()가 이미 막으므로 이 가드는 부차적 defense-in-depth)"
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
WFAIL="$(scoped_window '^#### probe 실패 분기' '^#{1,4} ')"
minlines "$WFAIL" 9 && note PASS "T23: '#### probe 실패 분기' 윈도우 충분히 존재 (>=9줄)" || note FAIL "T23: 실패 분기 윈도우가 비었거나 너무 짧다 (예상 밖 조기 절단 — 부차적 defense-in-depth, 주 방어는 scoped_window())"
has "$WFAIL" 'hard gate' && note FAIL "T23: 실패 분기에 'hard gate' 문구 (주장 > 보장)" \
                         || note PASS "T23: 실패 분기에 'hard gate' 문구 부재"
has "$WFAIL" 'advisory' && note PASS "T23: 실패 분기가 advisory 강등" || note FAIL "T23: advisory 강등 부재"
has "$WFAIL" 'D2' && note PASS "T23: 실패 분기가 D2 미충족 보고" || note FAIL "T23: D2 미충족 보고 부재"
WFAIL_BASH="$(fence "$WFAIL")"
# 실행 라인 앵커. 이전 계약은 substring이었고, 두 호출 라인을 같은 문구를 실은 산문
# ("이 분기에서는 --component critic 으로 record를 남깁니다")으로 바꿔도 88/88 green이었다 —
# 실측. fence()가 거르는 것은 `#` 주석뿐이라 펜스 안 산문은 그대로 통과한다.
DEGRADE_RE='^[[:space:]]*\$BRS degrade-append "\$STATE" --component '
grep -qE "${DEGRADE_RE}critic" <<<"$WFAIL_BASH" && note PASS "T23: 실패 분기 record — critic (실행 라인, 줄-시작 앵커)" || note FAIL "T23: critic record 호출 라인 부재 (산문으로는 만족되지 않는다)"
grep -qE "${DEGRADE_RE}readback" <<<"$WFAIL_BASH" && note PASS "T23: 실패 분기 record — readback (2건, 실행 라인)" \
                                  || note FAIL "T23: readback record 호출 라인 부재 (냉독 신뢰도 하향 신호 없음)"
WOK="$(scoped_window '^#### probe 통과 분기' '^#{1,4} ')"
# WOK에는 minlines 가드를 두지 않는다 — 자연 크기가 이미 2줄(빈 줄 + 문장 1개)이라 truncation을
# 걸러낼 여유 임계값이 존재하지 않는다(2로 잡아도 절단된 필러가 그대로 통과함, 직접 확인함).
# 이 윈도우의 유일한 assert가 POSITIVE('hard gate' 존재)이므로 truncation은 그 자체로 이미 걸린다
# (문장이 잘려나가면 'hard gate' 부재로 자연히 fail). W3A처럼 assert가 전부 negative인 윈도우는
# 절단이 곧 vacuous PASS였지만, 그건 지금 살아있는 취약점이 아니다: 펜스 안 컬럼-0 헤딩 모양의
# 절단은 scoped_window()가 구조적으로 막고, 남은 하나(펜스 불균형으로 인한 EOF 흘러넘침)는 위의
# 펜스 균형 assert가 잡는다. 여기 minlines를 두지 않는 근거는 여전히 '자연 크기 2줄'뿐이다.
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
grep -qE '^[[:space:]]*python3 "\$PR/scripts/web_budget\.py" (check|increment) ' "$SKILL" \
  && note PASS "T21: web_budget.py check/increment 실행 라인 실재 (줄-시작 앵커)" || note FAIL "T21: web_budget.py 호출 라인 부재 (산문 참조만으로는 예산이 집계되지 않는다)"
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
# 2-c 펜스의 **실행 라인**(fence()가 `#` 주석을 버린다). 아래 AC13·CR-3 assert가 공유한다 —
# 실행 라인 앵커를 걸 대상이 여기 하나뿐이라 정의를 한 곳에 모은다.
W2C_BASH="$(fence "$W2C")"
CR3_CAN_RE='^[[:space:]]*python3 "\$PR/scripts/brief_review_state\.py" can-redispatch '
inloop="$(grep -cE "$CAP_RE" <<<"$W2C" || true)"
minlines "$W2C" 25 && note PASS "T28: '### 2-c. 충실도 루프 전이' 윈도우 충분히 존재 (>=25줄)" || note FAIL "T28: 2-c 윈도우가 비었거나 너무 짧다 (예상 밖 조기 절단 — 부차적 defense-in-depth, 주 방어는 scoped_window())"
[[ "$total" -ge 1 ]] && note PASS "T28: 상한 표현이 실재 ($total)" || note FAIL "T28: 상한 표현이 0 — 루프 가드가 없다"
[[ "$total" == "$inloop" ]] && note PASS "T28: 상한 표현이 루프 문맥에만 ($inloop/$total)" \
  || note FAIL "T28: 루프 문맥 밖 상한 표현 $((total-inloop))건 (E10 위반)"

# --- AC13 : 전이 표 경계값 --------------------------------------------------
has "$W2C" 'brief_critic_rounds' && note PASS "AC13: 카운터 이름" || note FAIL "AC13: 카운터 이름 부재"
grep -qE '== ?2' <<<"$W2C" && note PASS "AC13: escalate 경계값 == 2" || note FAIL "AC13: 경계값 명시 부재"
grep -qE "$CR3_CAN_RE" <<<"$W2C_BASH" && note PASS "AC13: can-redispatch 게이트 호출 라인 실재 (줄-시작 앵커)" || note FAIL "AC13: 게이트 호출 라인 부재 (산문 언급은 게이트가 아니다)"
grep -qE '최초 리뷰.*0 유지|0 유지.*최초' <<<"$W2C" \
  && note PASS "AC13: 최초 리뷰는 카운터 0 유지" || note FAIL "AC13: 최초 리뷰 규칙 부재"
grep -qE 'fresh critic.*(필수|1회)' "$SKILL" \
  && note PASS "AC13/E8: 수정 후 fresh critic 재리뷰 1회 필수" || note FAIL "AC13/E8: fresh 재리뷰 필수 서술 부재"

# --- CR-3 : 수정 후 재검증 — 구조 게이트 + codex #2가 **수정된 바이트**를 본다 ---
# 이전 계약은 fresh critic 재리뷰만 요구했다. codex #2와 check_brief.py 구조 게이트는
# 둘 다 수정 루프 **이전**에만 돌았으므로 (a) codex가 수정 전 바이트만 보고 낸 판정으로
# 합집합이 계산되고(두 버전의 문서에서 계산한 합집합은 합집합의 보장을 잃는다),
# (b) 충실도 수정이 만든 frontmatter·섹션 구조 회귀가 Law 1 게이트를 통과한 것으로
# 보고됐다. 아래 assert는 전부 **실행되는 fence 라인**(fence()가 주석을 버린다)에
# 걸린다 — 산문 한 줄로 만족되지 않게 하기 위해서다.
# ⚠️ 모든 패턴은 **줄 시작 앵커**다(`^[[:space:]]*<명령>`). fence()가 걸러주는 것은
#    `#` 주석뿐이라, 같은 문구를 품은 *산문 한 줄*이 펜스 안에 들어와도 substring
#    검사(`has`)는 통과한다 — 실측으로 확인한 decoy다("이 시점에 python3 … 를 반드시
#    재실행합니다."). 앵커를 걸면 그 줄은 명령으로 시작하지 않아 red가 된다.
#    들여쓰기는 `*`(0회 이상)로 받는다 — `+`(1회 이상)를 쓰면 호출이 그대로 살아 있는데
#    컬럼 0으로 dedent만 해도 red가 난다(실측된 false-red). 펜스 경계와 명령 앵커가
#    락을 정직하게 만드는 것이지 들여쓰기가 아니다.
CR3_GATE_RE='^[[:space:]]*python3 "\$PR/scripts/check_brief\.py" gate '
CR3_CODEX_RE='^[[:space:]]*bash "\$PR/scripts/run_brief_codex_reviewer\.sh" fidelity '
CR3_MERGE_RE='^[[:space:]]*python3 "\$PR/scripts/merge_brief_review\.py"'
grep -qE "$CR3_GATE_RE" <<<"$W2C_BASH" \
  && note PASS "CR-3: 2-c가 payload 수정 후 check_brief.py gate를 재실행(실행 라인, 줄-시작 앵커)" \
  || note FAIL "CR-3: 2-c에 check_brief.py gate 재실행 호출 부재 — 충실도 수정이 만든 구조 회귀가 통과한다"
# 분기의 *존재*가 아니라 분기 **본문의 정지 동작**을 요구한다. 이전 계약은 `if`가 있기만
# 하면 PASS였고, shipping은 `exit_reason=` 변수 하나를 대입한 뒤 그대로 흘러내려
# check_verbatim_coverage → can-redispatch → bump-critic-round → 재dispatch를 전부 실행했다
# (`grep -rn exit_reason`이 리포 전체에서 그 대입 한 줄만 반환 = 읽는 곳 0곳). 서술은
# "차단"인데 실행은 통과였다 — 락이 증명한 것은 분기의 모양뿐이었다.
GATE_BRANCH="$(branch_body '^[[:space:]]*if \[\[ "\$gate_rc" -ne 0 \]\]' "$W2C_BASH")"
grep -qE '^[[:space:]]*(exit|return) [1-9]' <<<"$GATE_BRANCH" \
  && note PASS "CR-3: 구조 게이트 실패 분기 **본문**에 실제 정지 동작(exit/return non-zero) 실재" \
  || note FAIL "CR-3: 구조 게이트 실패 분기가 차단하지 않는다 — 분기가 없거나 본문에 정지 동작이 없다(변수만 대입하고 흘러내리면 재리뷰·재병합이 그대로 실행된다)"
grep -qE "$CR3_CODEX_RE" <<<"$W2C_BASH" \
  && note PASS "CR-3: 2-c가 codex #2를 수정된 바이트에 재실행(실행 라인, 줄-시작 앵커)" \
  || note FAIL "CR-3: 2-c에 codex #2 재실행 호출 부재 — 합집합이 서로 다른 두 버전에서 계산된다"
grep -qE "$CR3_MERGE_RE" <<<"$W2C_BASH" \
  && note PASS "CR-3: 2-c가 재리뷰 결과를 재병합(실행 라인, 줄-시작 앵커)" \
  || note FAIL "CR-3: 2-c에 재병합 호출 부재 — 재리뷰 결과가 verdict로 수렴하지 않는다"

# --- CR-3 순서/배치 락 : "수정된 바이트를 본다"는 *순서*에 대한 진술이다 -----------
# 존재만 잠그면 codex 재실행을 구조 게이트 **앞**으로 옮기고 can==0 분기 **밖**으로 빼도
# 88/88 green이었다(실측). 아래는 2-c 펜스의 실행 라인 인덱스로 상대 순서를 본다.
# 한계는 정직하게 적는다: 직선 bash 블록의 텍스트 순서는 실행 순서지만, 텍스트만으로
# *실행 시점*을 증명할 수는 없다. 그래서 두 조각으로 나눠 건다 — (a) 상대 순서,
# (b) can==0 분기 **본문 안에 있는가**. 둘이 함께 걸리면 "게이트 앞으로 이동"과
# "분기 밖으로 이동" 두 mutation이 모두 red다. 편집(2-a 재dispatch)이 재실행보다 앞선다는
# 것은 그 편집이 펜스 안의 실행 라인이 아니라 주석 한 줄(`# ... fresh critic 재dispatch`)이라
# 텍스트로 잠글 대상이 없다 — 대신 can-redispatch 게이트가 그 자리의 앵커 역할을 한다.
line_of() { grep -nE "$1" <<<"$W2C_BASH" | head -1 | cut -d: -f1; }
i_gate="$(line_of "$CR3_GATE_RE")"; i_can="$(line_of "$CR3_CAN_RE")"
i_codex="$(line_of "$CR3_CODEX_RE")"; i_merge="$(line_of "$CR3_MERGE_RE")"
if [[ -n "$i_gate" && -n "$i_can" && -n "$i_codex" && -n "$i_merge" ]] \
   && [[ "$i_gate" -lt "$i_can" ]] && [[ "$i_can" -lt "$i_codex" ]] && [[ "$i_codex" -lt "$i_merge" ]]; then
  note PASS "CR-3: 2-c 순서 — 구조 게이트 → can-redispatch → codex 재실행 → 재병합"
else
  note FAIL "CR-3: 2-c 순서 위반 (gate=${i_gate:-없음} can=${i_can:-없음} codex=${i_codex:-없음} merge=${i_merge:-없음}) — 재실행이 게이트보다 앞서면 '수정된 바이트를 본다'가 거짓이 된다"
fi
CAN_BRANCH="$(branch_body '^[[:space:]]*if \[\[ "\$can" -eq 0 \]\]' "$W2C_BASH")"
grep -qE "$CR3_CODEX_RE" <<<"$CAN_BRANCH" \
  && note PASS "CR-3: codex 재실행이 can==0 분기 **본문 안**에 있다 (escalate 라운드에는 돌지 않는다)" \
  || note FAIL "CR-3: codex 재실행이 can==0 분기 본문 밖 — 재dispatch가 없는 라운드에도 codex가 돈다"
grep -qE "$CR3_MERGE_RE" <<<"$CAN_BRANCH" \
  && note PASS "CR-3: 재병합이 can==0 분기 **본문 안**에 있다" \
  || note FAIL "CR-3: 재병합이 can==0 분기 본문 밖 — 재리뷰 없는 라운드의 stale 산출을 다시 병합한다"
# 자기 서술과 shipping의 정합 — "항상 최종 문서를 본다"는 주장이 문서에 있다면
# 그것을 참으로 만드는 재실행 호출이 루프 윈도우에 실재해야 한다.
if grep -qE 'codex #2는 \*\*항상 최종 문서' "$SKILL"; then
  grep -qE "$CR3_CODEX_RE" <<<"$W2C_BASH" \
    && note PASS "CR-3: '항상 최종 문서' 주장이 2-c 재실행 호출로 뒷받침됨" \
    || note FAIL "CR-3: '항상 최종 문서'를 주장하면서 2-c에 codex 재실행이 없다 (주장 > shipping)"
else
  note PASS "CR-3: '항상 최종 문서' 주장이 문서에 없음 (주장-shipping 불일치 없음)"
fi

# --- AC1 : 파이프라인 순서 + 진입 첫 액션 ------------------------------------
grep -qE '^[[:space:]]*python3 "\$PR/scripts/check_verbatim_coverage\.py" "\$PAYLOAD" "\$STATE"' "$SKILL" \
  && note PASS "AC1: 완전성 검사 실행 라인 실재 (줄-시작 앵커)" || note FAIL "AC1: check_verbatim_coverage.py 호출 라인 부재 (산문 참조는 검사를 돌리지 않는다)"
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
grep -qE "$CR3_MERGE_RE" "$SKILL" \
  && note PASS "AC7: 충실도 병합 스크립트 호출 라인 실재 (줄-시작 앵커)" || note FAIL "AC7: merge_brief_review.py 호출 라인 부재"

# --- codex 축별 호출 : **축마다** 센다 --------------------------------------
# 이전 계약은 두 축을 하나의 alternation으로 세고 하한 2를 요구했다. 호출이 정확히 2개였을
# 때는 충분했지만 CR-3가 충실도 재실행을 더해 3개가 되자 **방향성 호출을 통째로 지워도
# 하한 2가 충족되어 전 스위트가 green이었다**(실측). 방향성 축의 유일한 별-모델(cross-family)
# co-reviewer가 락 하나 깨지 않고 사라질 수 있었다는 뜻이다. 축별로 나눠 센다:
# 방향성 ≥ 1(1-c), 충실도 ≥ 2(2-b 최초 + 2-c 재실행). 들여쓰기는 `*`로 받는다 —
# 호출들이 codex 가용성 `if` 안으로 들어가면서 들여써졌고, 앵커의 근거는 들여쓰기가 아니라
# "줄이 `bash <러너>`라는 명령으로 시작한다"는 사실이다.
CODEX_CALL_RE='^[[:space:]]*bash "\$PR/scripts/run_brief_codex_reviewer\.sh"'
n_codex_dir="$(grep -cE "${CODEX_CALL_RE} direction " "$SKILL" || true)"
n_codex_fid="$(grep -cE "${CODEX_CALL_RE} fidelity " "$SKILL" || true)"
[[ "$n_codex_dir" -ge 1 ]] && note PASS "AC6: 방향성 축 codex 호출 실재 (${n_codex_dir}건, 1-c)" \
  || note FAIL "AC6: 방향성 축 codex 호출이 ${n_codex_dir}건 — 이 축의 유일한 별-모델 co-reviewer가 없다"
[[ "$n_codex_fid" -ge 2 ]] && note PASS "AC6: 충실도 축 codex 호출 실재 (${n_codex_fid}건, 2-b 최초 + 2-c 재실행)" \
  || note FAIL "AC6: 충실도 축 codex 호출이 ${n_codex_fid}건 — 최초 리뷰나 수정-바이트 재실행 중 하나가 없다"
grep -qE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*="\$\(bash "\$PR/scripts/detect_codex\.sh"' "$SKILL" \
  && note PASS "AC9: detect_codex.sh 선행 확인이 실행 라인 (줄-시작 앵커)" || note FAIL "AC9: detect_codex.sh 호출 라인 부재 — 가용성 판정 없이 러너를 부른다"

# --- AC18/AC9 : codex 호출 지점이 **전부** 가용성 게이트 안에 있다 ------------
# kill switch(DEVBREW_DISABLE_SPEC_DISTILL_CODEX=1)는 detect_codex.sh를 거쳐 $codex_avail로만
# 전달된다 — 러너는 이 변수를 보지 않는다(run_spec_codex_reviewer.sh와 같은 호출자-게이트
# 규약). 게이트 밖 호출이 하나라도 있으면 (a) cost_class: high skill에서 사용자의 명시적
# opt-out이 무시된 채 외부 모델에 지출이 나가고, (b) 1-c가 남기는 affected_axis: all record가
# 거짓이 된다("codex가 양 축에서 없었다"고 적는데 실제로는 충실도를 봤다).
# 게이트된 호출 수 == 전체 호출 수를 요구한다 — "게이트가 어딘가에 하나 있다"로는
# 어느 호출이 그 밖에 있는지 구분하지 못한다.
CODEX_GUARD_RE='^[[:space:]]*if \[\[ "\$\{?codex_avail(:-)?\}?" == "true" \]\]'
n_codex_calls=$((n_codex_dir + n_codex_fid))
n_codex_guarded=0
for _w in "$(fence "$(window '^### 1-c\.')")" "$(fence "$(window '^### 2-b\.')")" "$W2C_BASH"; do
  _body="$(branch_body "$CODEX_GUARD_RE" "$_w")"
  _c="$(grep -cE "$CODEX_CALL_RE" <<<"$_body" || true)"
  n_codex_guarded=$((n_codex_guarded + _c))
done
[[ "$n_codex_calls" -gt 0 ]] && [[ "$n_codex_guarded" -eq "$n_codex_calls" ]] \
  && note PASS "AC18: codex 호출 ${n_codex_calls}개가 전부 \$codex_avail 게이트 본문 안" \
  || note FAIL "AC18: codex 호출 ${n_codex_calls}개 중 ${n_codex_guarded}개만 게이트 안 — kill switch가 우회되고 affected_axis: all record가 거짓이 된다"

# --- AC15 : 축별 codex 런타임 실패 degrade record (1-c 방향성 / 2-b 충실도) ---
# 각 축의 러너가 살아있었는데 이번 라운드에 실패한 경우(pre-flight 부재와 다른 케이스)의
# record를 자기 섹션 윈도우(fence-aware)로 스코프해서 확인한다 — 'component: codex'는
# 1-c에 pre-flight-skip record(affected_axis: all)도 있어 단독으로는 구분 못 하므로,
# 이 라운드가 추가한 사실인 'affected_axis: direction/fidelity'와의 co-occurrence로 좁힌다.
W1C="$(window '^### 1-c\.')"
{ has "$W1C" 'component: codex' && grep -qE 'affected_axis: direction' <<<"$W1C"; } \
  && note PASS "AC15: 1-c 방향성 축 codex 런타임 실패 record 명시" \
  || note FAIL "AC15: 1-c 방향성 축 codex 런타임 실패 record 부재"
W2B="$(window '^### 2-b\.')"
{ has "$W2B" 'component: codex' && grep -qE 'affected_axis: fidelity' <<<"$W2B"; } \
  && note PASS "AC15: 2-b 충실도 축 codex 런타임 실패 record 명시" \
  || note FAIL "AC15: 2-b 충실도 축 codex 런타임 실패 record 부재"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
