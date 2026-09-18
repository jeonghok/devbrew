#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/framing-requests/SKILL.md
#
# framing-requests SKILL 의 **계약** 락 — 설계 2026-09-16-framing-intent-drift 의 AC 중 SKILL 문면과
# 배선으로 재는 것(AC1 · AC3b · AC3d · AC4 · AC6 · AC12 · AC13 배선).
#
# 판정 방식 — 절(`## `) · 하위절(`### `) 창은 코드 펜스를 인식한다(펜스 안 `#` 줄이 창을 자르지
# 않게). 명령의 존재는 bash 펜스 안 **실행 줄**(주석 제외)로 잰다 — 산문 한 줄로 만족되지 않게.
# 부재 단언마다 같은 자리의 양의 짝을 둔다 — 절이 통째로 사라지면 부재는 공허하게 참이다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SK="$ROOT/plugins/spec-distill/skills/framing-requests/SKILL.md"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"; exit 0
fi
. "$ROOT/shared/tests/assert.sh"
test -f "$SK" || { no "부재: $SK"; finish; exit; }

win() {   # win <file> <시작 헤딩 정규식> <끝 헤딩 정규식> → 시작 헤딩 다음 줄부터 끝 헤딩 앞까지(펜스 인식)
  H="$2" E="$3" awk '
    /^```/ { inf = !inf }
    !s && !inf && $0 ~ ENVIRON["H"] { s = 1; next }
    s && !inf && $0 ~ ENVIRON["E"] { exit }
    s { print }' "$1"
}
section()    { win "$1" "$2" '^## '; }
subsection() { win "$1" "$2" '^##+ '; }
bash_lines() { printf '%s\n' "$1" | awk '/^```bash[[:space:]]*$/ {b=1; next} b && /^```/ {b=0; next} b && !/^[[:space:]]*#/ {print}'; }
js_lines()   { printf '%s\n' "$1" | awk '/^```javascript[[:space:]]*$/ {j=1; next} j && /^```/ {j=0; next} j {print}'; }

# ── AC1 — 확산의 자기보고 블록이 확인 질문으로 ────────────────────────────────
EXP="$(section "$SK" '^## 확산$')"
[ -n "$EXP" ] && ok "절 추출: ## 확산 (vacuous 아님)" || no "절 추출: ## 확산 이 비었다 — 아래 판정은 무의미하다"
assert_not_contains "$(cat "$SK")" "원문과 다른 점" "AC1: «원문과 다른 점» 자기보고 블록이 파일 어디에도 없다"
assert_contains "$EXP" "세 블록" "AC1 양의 짝: 라운드 보고는 세 블록이다"
CQ="$(subsection "$SK" '^### 확인 질문')"
JS="$(js_lines "$CQ")"
[ -n "$JS" ] && ok "절 추출: ### 확인 질문의 javascript 펜스" || no "절 추출: ### 확인 질문에 javascript 펜스가 없다"
assert_contains "$JS" "multiSelect: true" "AC1: 확인 질문은 여럿을 고르는 질문이다"
for w in "내가 물은 것" "당신이 답한 것" "내가 읽은 것"; do
  assert_contains "$JS" "$w" "AC1: 선택지 설명에 «${w}» 가 있다(질문 문구 · 원문 · 풀이)"
done
assert_contains "$JS" "고르지 않은 것은 미확인으로 남습니다" "AC1: 질문 문구가 양의 선택을 밝힌다"
assert_contains "$CQ" "고른 풀이만 확인이다" "AC1: 확인은 양의 선택이다(D1.1)"
assert_contains "$CQ" "## 2. 질문 전체" "확인 결과를 audit ## 2 에 남긴다"
assert_contains "$CQ" "맞다 / 아니다" "AC1: 풀이가 하나면 단일 선택으로 묻는다"
assert_contains "$CQ" "압축 전에" "AC1: 압축 전에 묻지 않은 풀이를 한 번 더 확인한다"
assert_contains "$CQ" "선택지가 하나만 남는 질문은 만들지 않는다" "AC1: 넷씩 나누다 하나 남는 질문을 만들지 않는다"
assert_contains "$CQ" "다음 호출로 간다" "AC1: 합쳐 넷을 넘는 확인 질문은 다음 호출로 넘어간다"
assert_not_contains "$(cat "$SK")" "굳던" "AP2: self-narrating history 문구가 SKILL 에 없다"
CONV="$(win "$SK" '^### 확정 표시와' '^##')"
assert_contains "$CONV" "글자 그대로" "D4.43: 압축이 문장을 고치면 표시는 따라가지 않는다"
assert_not_contains "$CONV" "seed-critic" "확정 표시 절이 지워질 격리 critic 을 가리키지 않는다"

# ── AC4 — 검증 절이 엔진으로 ─────────────────────────────────────────────────
assert_not_grep "$(cat "$SK")" 'seed-critic|run_seed_codex_reviewer|build_seed_codex_prompt|seed-codex-suppression' \
  "AC4: 옛 억제 파이프라인 이름이 SKILL 에 0건"
VER="$(section "$SK" '^## 검증$')"
[ -n "$VER" ] && ok "절 추출: ## 검증 (vacuous 아님)" || no "절 추출: ## 검증 이 비었다 — 아래 판정은 무의미하다"
anchors="$(printf '%s\n' "$VER" | grep -E '^[[:space:]]*// \*\*처분\*\* —' || true)"
assert_contains "$anchors" "consumer=plugins/spec-distill/scripts/docreview_route.py · fail-closed" "AC4: 탐지 dispatch 의 처분 소비자는 엔진 라우터 · fail-closed"
assert_contains "$anchors" "consumer=plugins/spec-distill/scripts/docreview_route.py · fail-open" "AC4: 재비판 dispatch 의 처분 소비자는 엔진 라우터 · fail-open(재비판 부재는 공시하고 막지 않는다)"
assert_eq "$(printf '%s\n' "$anchors" | grep -c 'consumer=plugins/spec-distill/scripts/docreview_route.py' || true)" "2" "AC4: 엔진 라우터를 소비자로 대는 dispatch 가 정확히 둘(탐지 · 재비판)"
assert_contains "$VER" 'subagent_type: "spec-distill:seed-readback"' "냉독은 엔진 밖 그대로(양의 짝)"
assert_contains "$VER" '재비판의 `<document>` = `$BUNDLE_RC` 의 **내용**' "재비판자는 판정 이력 없는 번들을 받는다(D4.44)"
assert_contains "$(bash_lines "$VER")" 'build_seed_inline_blob.py" "$SEED_ABS" "$AUDIT_ABS" CLAUDE.md --for recritic' "번들 펜스가 재비판용 갈래를 조립한다(실행 줄)"
assert_contains "$(bash_lines "$VER")" 'seed_review_log.py" append-verbatim' "엔진 산출물을 audit ## 4 에 옮긴다(실행 줄)"
finish
