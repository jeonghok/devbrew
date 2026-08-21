#!/usr/bin/env bash
# Spec B AC1 지원 (V1 보완) — conducting-interview → reviewing-brief 진입 + Step B 실기.
# 기존 종료 조건·Step A 게이트·B-2 4옵션 구조가 **불변**임을 함께 잠근다(회귀 방지).
# Fix round 2: fence-aware scoping — Task 7(test_reviewing_brief_skill.sh)의 scoped_window()/
# fence() 관용구를 재사용한다. 느슨한(anywhere-in-window) substring 체크만으로는 "펜스 밖 프로즈
# mention"·"주석 처리된 데코이 펜스"·"펜스 안이지만 무관한 첫 줄"로 satisfiable하다는 것이
# fix round 1 리뷰에서 mutation으로 실증됐다(NB1/NB2). load-bearing lock은 반드시 실제 펜스
# 내부 콘텐츠(전체-라인 주석 제외)를 지목해야 한다.
# Run: bash plugins/spec-distill/tests/test_brief_review_entry.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
CI="$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/SKILL.md"
# Task 32(무게 감축): Step A.5 · Step B 전문이 references/finishing.md 로 분리됐다. 이 스위트의
# 윈도우 앵커(`### Step A.5` · `#### B-2`)와 전-파일 검사는 **어느 파일에 그 섹션이 있는지**를
# 알면 안 된다 — 알면 다음 분할 때 또 깨진다. 그래서 스킬 표면을 도출해 하나의 스트림으로 다룬다.
# (부재 검사에서 특히 중요하다: 코퍼스가 줄어도 부재 락은 RED 가 아니라 **조용히 약해진다**.)
CI_DIR="$(dirname -- "$CI")"
CI_FILES=("$CI")
while IFS= read -r _f; do [ -n "$_f" ] && CI_FILES+=("$_f"); done < <(ls "$CI_DIR"/references/*.md 2>/dev/null)
ci_cat() { cat "${CI_FILES[@]}"; }

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# $1 = 시작 헤더 정규식, $2 = 종료 판단 헤딩 정규식 → fence-aware(Task 7 scoped_window() 재사용):
# ``` 펜스 안에서는 종료 조건을 무시한다(펜스 안의 컬럼-0 텍스트가 헤딩처럼 보여 조기
# 종료시키는 것을 막는다 — 잘린 윈도우 안에서는 이후의 모든 스코프 락이 vacuous하게든
# 다른 섹션 텍스트로든 무너질 수 있다). 펜스 마커는 들여쓰기를 허용한다(fix round 3 —
# 불릿 리스트 아래 중첩된 펜스, 이 SKILL 자체에 실재하는 관용구, 마커 자체가 들여써진다.
# 아래 FENCE_MARKER_RE가 fence()/펜스-균형 전제조건과 동일 패턴이어야 셋이 드리프트하지 않는다).
FENCE_MARKER_RE='^[[:space:]]*```'
# 패턴은 `-v`가 아니라 ENVIRON으로 넘긴다 — `awk -v`는 대입값의 escape sequence를 처리한다
# (`\[`·`\$`·`\t`가 뭉개진다). 지금 패턴이 `\.`뿐이라 우연히 무해할 뿐이고, 대괄호나 `$`가
# 든 패턴이 들어오면 조용히 아무것도 매치하지 않아 윈도우가 비고 그 안의 assert가 전부
# vacuous해진다. 아래 fence()도 같은 이유로 함께 옮긴다.
scoped_window() {
  SW_PAT="$1" SW_END="$2" SW_FRE="$FENCE_MARKER_RE" awk '
    $0 ~ ENVIRON["SW_PAT"] {inw=1; next}
    inw && $0 ~ ENVIRON["SW_FRE"] {fence=!fence}
    inw && !fence && $0 ~ ENVIRON["SW_END"] {exit}
    inw
  ' "${CI_FILES[@]}"
}
window() { scoped_window "$1" '^#{3,4} '; }

# 윈도우 문자열 안에서 특정 태그의 펜스 내부만 추출(Task 7 fence() 관용구를 태그 파라미터로
# 일반화 — 이 SKILL은 ```bash·```javascript·bare ``` 세 종류를 다 쓴다). 전체-라인 주석은
# 버린다(주석 처리해 실행되지 않는 줄이 grep에는 그대로 잡히는 것을 막는다). $2="" 이면
# bare ``` 펜스(태그 없음)를 지목한다 — bare 펜스의 열기/닫기 마커가 둘 다 리터럴 "```"이므로
# 상태(infence)로 열기/닫기를 구분한다(리터럴 매칭만으로는 앞선 다른 펜스의 닫기 마커를
# 열기로 오인한다). 마커 자체의 들여쓰기를 허용(위 FENCE_MARKER_RE와 동일 접두 — fix round 3
# NB: 불릿 아래 중첩된 펜스가 false RED를 냈었다). 태그 매칭은 흔한 별칭을 허용한다(js/javascript
# — fix round 3: 리네임만으로 무관 펜스가 되어 락 전체가 무력화되는 false RED를 막는다). 단
# 다른 언어 펜스(예 ```bash)는 여전히 매칭되지 않는다.
fence() {
  local tag="$2" tag_re
  case "$tag" in
    javascript|js) tag_re='(javascript|js)' ;;
    *) tag_re="$tag" ;;
  esac
  FN_TAG="$tag_re" FN_FRE="$FENCE_MARKER_RE" awk '
    BEGIN { tag_re = ENVIRON["FN_TAG"]; fre = ENVIRON["FN_FRE"] }
    !infence && $0 ~ fre tag_re "[[:space:]]*$" { infence=1; want=1; next }
    !infence && $0 ~ fre                        { infence=1; want=0; next }
    infence && $0 ~ fre "[[:space:]]*$"          { infence=0; want=0; next }
    infence && want && $0 !~ /^[[:space:]]*#/ { print }
  ' <<<"$1"
}

# 한 줄에서 문자열 리터럴 **밖**의 첫 "//" 부터를 잘라낸다(트레일링 라인-코멘트 제거).
# 따옴표 *안의* 내용은 절대 건드리지 않는다 — 이 파일의 fence()가 전체-라인 "#" 주석을
# 거르는 것과 같은 구분을 트레일링 "//"까지 확장한 것이다.
#
# 이전 판은 경계를 **줄의 마지막 따옴표**로 잡았고, 그게 이 함수를 no-op으로 만드는
# 입력 클래스를 남겼다: 트레일링 코멘트 자체가 따옴표 쌍을 품으면
# (`// TODO: "degrade" 필드는 아직 안 나름`) 마지막 따옴표가 코멘트 *안*이라 rest에 "//"가
# 없고 아무것도 잘리지 않는다 — 실측으로 그 입력을 넣었더니 줄이 그대로 되돌아왔고, 그
# 상태에서 실제 렌더를 지워도 AC15 배치 assert가 green으로 남았다. JS 코멘트 안에 필드
# 이름을 따옴표로 인용하는 것은 평범한 저자 습관이라 이 사이클의 위협 모델(선의의 저자가
# 저지르는 사고) 안에 있다.
#
# 그래서 **왼쪽에서 오른쪽으로** 훑으며 문자열 상태를 토글한다. 여는 따옴표 문자를 기억해
# 같은 문자로만 닫고(", ', ` 세 종류 — 이 SKILL은 셋을 다 쓴다), 문자열 안의 백슬래시
# 이스케이프(\" 포함)는 다음 한 글자를 통째로 건너뛴다. 문자열 밖에서 처음 만난 마커가
# 코멘트의 시작이다. URL의 "https://"는 문자열 안이라 자연히 안전하다.
#
# 마커는 인자다($2, default "//"). 이 SKILL은 JS 펜스의 "//"와 bare 펜스 invocation
# 라인의 "#" 두 종류를 쓰는데, **같은 스캐너**가 둘을 처리해야 한다 — 두 번째 스트리퍼를
# 따로 쓰면 위 문단이 기록한 no-op 결함(따옴표 상태를 안 보는 판)을 한 쪽에서 되풀이한다.
# 마커는 `-v`가 아니라 ENVIRON으로 넘긴다(이 파일 다른 곳과 같은 이유: `-v`는 대입값의
# escape sequence를 처리한다).
strip_trailing_linecomment() {
  local mark="//"
  [[ $# -ge 2 ]] && mark="$2"
  STLC_MARK="$mark" awk '
    BEGIN { mark = ENVIRON["STLC_MARK"]; mlen = length(mark) }
    { line = $0; n = length(line); q = ""; out = line
      for (i = 1; i <= n; i++) {
        c = substr(line, i, 1)
        if (q != "") {
          if (c == "\\") { i++; continue }
          if (c == q) { q = "" }
          continue
        }
        if (c == "\"" || c == "'"'"'" || c == "`") { q = c; continue }
        if (substr(line, i, mlen) == mark) {
          out = substr(line, 1, i-1); sub(/[[:space:]]+$/, "", out); break
        }
      }
      print out
    }
  ' <<<"$1"
}

test -f "$CI" || { no "SKILL 부재"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }
# '참조 파일 0건'을 '문제 없음'으로 읽지 않는다 — 도출이 깨지면 아래 전-파일 검사가 분할
# 이전 범위로 조용히 되돌아간다.
[[ "${#CI_FILES[@]}" -ge 2 ]] \
  && ok "코퍼스: conducting-interview 표면 ${#CI_FILES[@]}개 파일 도출 (vacuous 아님)" \
  || no "코퍼스: references/*.md 를 0건 도출했다 — 검사 범위가 조용히 좁아졌다"

# --- 윈도우 전제조건 : 코드 펜스 균형 (Task 7 관용구 재사용) -----------------
# scoped_window()/fence()의 상태 토글은 문서의 ``` 마커가 짝을 이룬다는 전제 위에서만 성립한다.
# 마커가 홀수면 토글이 뒤집힌 채로 남아 윈도우가 EOF까지 흘러넘치거나 fence()가 엉뚱한
# 구간을 "펜스 안"으로 오인한다. 카운트는 위 FENCE_MARKER_RE와 **문자 그대로 동일한 패턴**을
# 써야 한다 — 다른 패턴을 쓰면(예: 들여쓰기 불허) 들여쓰인 마커 쌍이 이 카운트에서만 안 보여서
# "균형"이라고 오판하면서 fence()/scoped_window()는 그 마커를 실제로 인식(또는 오인식)하는
# drift가 생긴다(fix round 3 NB: 정확히 이 drift로 인덱테이션된 펜스가 false RED를 내면서도
# 이 전제조건은 계속 PASS를 냈다). 이 전제조건은 **전역**(윈도우 스코프 아님) — 무관한 섹션의
# 마커 하나가 빠져도 트립된다(Task 7과 동일한 의도적 coarse-ness: 위장이 아니라 흔한 편집
# 사고를 잡는 게 목적이라 스코프를 좁히지 않는다).
n_fence="$(ci_cat | grep -cE "$FENCE_MARKER_RE" || true)"
if [[ "$n_fence" -gt 0 ]] && [[ "$((n_fence % 2))" -eq 0 ]]; then
  ok "펜스 균형: 코드 펜스 마커 ${n_fence}개 — 짝수(균형), 윈도우/펜스 스코프 유효"
else
  no "펜스 불균형: 코드 펜스 마커 ${n_fence}개 — scoped_window()/fence()가 스코프를 잃는다"
fi

# --- 진입 블록 -------------------------------------------------------------
grep -qE '^### Step A\.5' "${CI_FILES[@]}" && ok "Step A.5 헤더 존재" || no "Step A.5 헤더 부재"
WA5="$(window '^### Step A\.5')"
grep -qF 'reviewing-brief' <<<"$WA5" && ok "A.5가 reviewing-brief를 지목 (느슨한 substring, defense-in-depth)" || no "A.5에 reviewing-brief 부재"
# 위 substring 체크는 프로즈 한 줄만으로도, 또는 펜스 밖 아무 데나 같은 리터럴을 흘려놔도
# satisfiable하다 — fix round 1 리뷰가 mutation으로 실증(invocation 라인을 지우고 "위 형식
# 참고용" 데코이로 치환해도, 또는 "이전 형식 참고" 펜스를 따로 추가해도 계속 PASS). load-bearing
# lock은 (a) 실제 invocation directive가 사는 bare ``` 펜스 내부(주석 제외)를 지목하고,
# (b) 그 안의 라인이 $PAYLOAD·$CODEX_DIR_YAML·$CODEX_FID_YAML 세 핸드오프 변수를 실제로
# 실어 나르는지까지 확인한다 — "Skill spec-distill:reviewing-brief"라는 문자열만 있고 세
# 변수를 나르지 않는 장식용 데코이 라인(예: "위 형식 참고용" 주석)은 이 조건에서 걸러진다.
# anchor는 들여쓰기·"- " 불릿을 허용한다(무해한 리포맷이 col-0 강제로 false-fail하지 않게 —
# 펜스 경계가 lock을 정직하게 만드는 것이지 column 0이 아니다).
INVOKE_FENCE="$(fence "$WA5" "")"
grep -qE '^[[:space:]]*-?[[:space:]]*Skill spec-distill:reviewing-brief\b' <<<"$INVOKE_FENCE" \
  && ok "A.5 bare 펜스 안에 invocation 라인 실재 (load-bearing)" \
  || no "A.5 bare 펜스 안에 invocation 라인 부재 (펜스 밖 mention·데코이 펜스로는 만족 안 됨)"
INVOKE_LINE="$(grep -E '^[[:space:]]*-?[[:space:]]*Skill spec-distill:reviewing-brief\b' <<<"$INVOKE_FENCE" | head -1)"
# 트레일링 "#" 코멘트는 **인자가 아니다.** 이전 판은 라인 전체에서 세 변수를 찾았고,
# shipping은 그 셋을 `#` 뒤에만 실어 놓았다("… reviewing-brief   # 인자: $PAYLOAD, …") —
# 즉 이 락은 호출 인자가 아니라 **주석**을 보호하면서 green이었다(실측). callee는 이 세 값을
# 스스로 정의하지 않는다고 명시하므로, 주석에만 있으면 호출은 인자 없이 나간다.
# fence()가 전체-라인 주석만 거르는 것과 같은 구분을 트레일링 "#"까지 확장한다 —
# 같은 따옴표-상태 스캐너를 마커만 바꿔 재사용한다(두 번째 스트리퍼를 쓰지 않는다).
INVOKE_CODE="$(strip_trailing_linecomment "$INVOKE_LINE" '#')"
for handoff_var in '$PAYLOAD' '$CODEX_DIR_YAML' '$CODEX_FID_YAML'; do
  grep -qF "$handoff_var" <<<"$INVOKE_CODE" \
    && ok "invocation 라인이 ${handoff_var} 전달 (트레일링 # 코멘트 제외하고 검사)" \
    || no "invocation 라인(코멘트 제외)에 ${handoff_var} 부재 — 주석에만 적혀 있으면 호출은 인자 없이 나간다"
done
grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW' <<<"$WA5" \
  && ok "A.5에 kill switch 경로" || no "A.5에 kill switch 경로 부재"
# 한 블록만 추가 — A.5가 파이프라인 절차를 복제하면 두 곳 drift가 생긴다
n5="$(wc -l <<<"$WA5" | tr -d ' ')"
[[ "$n5" -le 30 ]] && ok "A.5가 한 블록 규모 (${n5} 줄 ≤ 30)" || no "A.5가 ${n5} 줄 — 파이프라인을 복제했다"
for tok in 'brief-critic' 'merge_brief_review' 'check_verbatim_coverage' 'G1'; do
  grep -qF "$tok" <<<"$WA5" && no "A.5가 파이프라인 내부('$tok')를 복제" || ok "A.5에 '$tok' 없음 (복제 아님)"
done

# --- 핸드오프 변수 3종 (Task 7 cross-task obligation) -----------------------
# reviewing-brief SKILL.md 상태 섹션은 $PAYLOAD·$CODEX_DIR_YAML·$CODEX_FID_YAML을
# "호출자가 진입 시점에 이미 쥐고 넘기는 값"이라 주장한다 — conducting-interview가
# 실제로 이 세 값을 세우지 않으면 그 주장은 overclaim이 된다(V1 cross-task 요건).
for var in 'PAYLOAD=' 'CODEX_DIR_YAML=' 'CODEX_FID_YAML='; do
  grep -qF "$var" <<<"$WA5" && ok "A.5가 ${var%=} 값을 확립" || no "A.5에 ${var%=} 확립 부재"
done
grep -qE 'state_path\.py.*state-root' <<<"$WA5" \
  && ok "A.5가 파이프라인과 같은 state-root 리졸버 사용" || no "A.5의 ROOT 도출이 리졸버와 불일치"
grep -qE 'state_path\.py.*session-id' <<<"$WA5" \
  && ok "A.5가 파이프라인과 같은 harness_sid 리졸버 사용" || no "A.5의 harness_sid 도출이 리졸버와 불일치"

# --- Step A 게이트·종료 조건 불변 (회귀 락) ---------------------------------
grep -qF 'check_brief.py' "${CI_FILES[@]}" && ok "Step A 게이트 보존" || no "check_brief.py 게이트가 사라졌다"
grep -qF 'floor 5차원' "${CI_FILES[@]}" && ok "종료 driver(floor 5) 보존" || no "종료 driver 서술 손실"
grep -qF '# confirmed 0건 — 사용자가 전부 잠정으로 판단' "${CI_FILES[@]}" \
  && ok "confirmed 0건 sentinel 보존" || no "sentinel 문구 손실"

# --- Step B 실기 (4 산출물 + degrade) ---------------------------------------
WB2="$(window '^#### B-2')"
[[ -n "$WB2" ]] && ok "B-2 윈도우 존재" || no "B-2 윈도우 부재"
grep -qF 'AskUserQuestion' <<<"$WB2" && ok "B-2 게이트 보존" || no "B-2 게이트 손실"
n_opt="$(grep -cE '^\s*\{label:' <<<"$WB2" || true)"
[[ "$n_opt" == "4" ]] && ok "B-2 4옵션 구조 불변 (${n_opt})" || no "B-2 옵션이 ${n_opt} 개 (구조 변경)"
for tok in '방향성' 'readback' 'gap' 'degrade'; do
  grep -qF "$tok" <<<"$WB2" && ok "B-2 question에 '$tok' 실림 (느슨한 substring, defense-in-depth)" || no "B-2에 '$tok' 부재"
done
grep -qE 'question 텍스트|question 본문' "${CI_FILES[@]}" \
  && ok "degrade가 question 텍스트에 렌더 (프로즈 서술, defense-in-depth)" || no "렌더 위치(question 텍스트) 명시 부재"
# 위 두 체크는 어휘(prose가 "degrade"·"question 텍스트"를 언급하는지)만 본다 — §5.6/AC15가
# 요구하는 실제 property는 *배치*(옵션 description이 아니라 question: 문자열 그 자체)다.
# fix round 1 리뷰가 mutation으로 실증: 펜스 앞에 "question: 필드는 ... degrade record를
# 담습니다" 같은 프로즈 aside를 얹으면(이 SKILL 자체가 coverage:/orchestration: 필드를 프로즈로
# 설명하는 기존 관용구를 모방) 위 체크들이 계속 PASS — 그 aside는 펜스 밖에 있을 뿐이다.
# load-bearing lock은 실제 AskUserQuestion 호출이 사는 ```javascript 펜스 내부만 지목하고,
# 그 안에 question: 라인이 정확히 1개인지(중복 키로 가려질 수 없게)까지 확인한다.
QFENCE="$(fence "$WB2" "javascript")"
n_qline="$(grep -cE '^[[:space:]]*question:' <<<"$QFENCE" || true)"
[[ "$n_qline" == "1" ]] \
  && ok "B-2 AskUserQuestion 펜스 안에 question: 라인 정확히 1개 (load-bearing)" \
  || no "B-2 AskUserQuestion 펜스 안 question: 라인이 ${n_qline}개 (중복 키로 가려질 위험)"
QLINE="$(grep -E '^[[:space:]]*question:' <<<"$QFENCE" | head -1)"
# 트레일링 "//" 코멘트는 문자열 리터럴 밖이라 실제 렌더가 아니다(fix round 3 Decoy 2) — 이를
# 잘라낸 뒤에 검사해야 "죽은 // TODO 코멘트에 degrade가 적혀있을 뿐 실제 문자열엔 없다"는
# 케이스를 놓치지 않는다. 반대로 진짜 렌더가 문자열 안에 있으면 트레일링 "//" 코멘트가
# 나중에 붙어도(무해한 편집) false-fail 없이 계속 PASS다.
QLINE_CODE="$(strip_trailing_linecomment "$QLINE")"
grep -qF 'degrade' <<<"$QLINE_CODE" \
  && ok "B-2 question: 라인이 degrade record를 직접 실음 (placement, load-bearing; 트레일링 // 코멘트 제외하고 검사)" \
  || no "B-2 question: 라인(트레일링 // 코멘트 제외)에 degrade 부재 — 렌더가 description 등 다른 곳으로 이동했거나 죽은 // 코멘트일 수 있다"
grep -qE 'degrade 없음' "${CI_FILES[@]}" && ok "빈 배열도 명시" || no "빈 배열 명시 부재"

# --- P21 canonical 토큰 (checker와 producer가 같은 집합) --------------------
grep -qF '<REDACTED' "${CI_FILES[@]}" && ok "P21 canonical 토큰 명시" || no "P21 canonical 토큰 부재"

# --- cross-compact / polite stop 가드 불변 ----------------------------------
grep -qE '턴 종료|다음 턴' "${CI_FILES[@]}" && ok "cross-compact 가드 보존" || no "cross-compact 가드 손실"
grep -qF 'polite stop' "${CI_FILES[@]}" && ok "AP2 가드 보존" || no "AP2 가드 손실"
finish
