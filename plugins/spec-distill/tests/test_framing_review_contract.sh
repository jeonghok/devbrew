#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/seed_review_log.py shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py
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
  for f in plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/templates/interview-seed-audit-template.md \
           plugins/spec-distill/references/docreview-profiles/seed.md plugins/spec-distill/scripts/seed_review_log.py \
           shared/docreview/scripts/docreview_state.py shared/docreview/scripts/docreview_route.py shared/docreview/scripts/docreview_anchor.py; do
    echo "$f"
  done
  exit 0
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
assert_contains "$(bash_lines "$VER")" 'append-verbatim "$AUDIT_ABS" --section "## 4. 비평과 냉독" --title "냉독 (seed-readback)"' "냉독도 audit ## 4 에 인용 블록으로 옮긴다(실행 줄 — Edit 로 옮기면 제목 모양 줄이 절 경계로 읽힌다)"

# ── AC3b · AC3d · AC12 — 게이트 규칙 ──────────────────────────────────────────
GATE="$(subsection "$SK" '^### 게이트')"
[ -n "$GATE" ] && ok "절 추출: ### 게이트 (vacuous 아님)" || no "절 추출: ### 게이트 가 비었다 — 아래 판정은 무의미하다"
assert_contains "$GATE" "사용자가 처분하기 전에는 seed 파일을 편집하지 않는다" "AC3b: 처분 전 편집 금지가 단계로 있다"
assert_contains "$GATE" "읽기는 막지 않는다" "AC3b: 술어는 편집이지 읽기가 아니다(D4.40)"
assert_contains "$GATE" '`fix` 도 적용 전에 묻는다' "AC3b: fix 도 적용 전 사용자 확인"
GB0="$(bash_lines "$GATE")"
assert_contains "$GB0" 'q="$(python3 "$SD/scripts/seed_review_log.py" one-line "$STATE_DIR/said-<id>.txt")" || q_rc=$?' "처분 펜스: 사용자 문구를 항목별 파일에서 먼저 받고 rc 를 잡는다(실행 줄)"
assert_contains "$GB0" '--event drop --reason="$q" --log-file "$AUDIT_ABS"' "D18: fix 거부는 사용자 문구로 엔진이 기록한다(실행 줄)"
assert_contains "$GB0" '--choice "$EVENT" --quote="$q" --log-file "$AUDIT_ABS"' "decide 도 같은 꼴로 사용자 문구를 싣는다(실행 줄)"
assert_contains "$GATE" '`ask_open` 개수를 처분과 무관하게 싣는다' "AC3d: ask_open 개수 공시"
# 사용자 문구 · 리뷰어 요약을 셸 인자에 리터럴로 싣지 않는다 — 큰따옴표 안의 백틱 · $( ) 는 셸이 실행한다.
assert_not_grep "$(grep -vE 'degrade-append|framing_degradations' "$SK")" '--(quote|note|reason|extra-approval)[ =]"<' "사용자 문구 · 리뷰어 요약을 큰따옴표 자리표로 셸 인자에 싣는 곳이 SKILL 에 0건(degrade 원장의 하니스 사유 제외)"
assert_not_grep "$(cat "$SK")" '\$STATE_DIR/(said|note)\.txt' "고정 이름 문구 파일(said.txt · note.txt)이 SKILL 에 0건 — 문구 파일은 항목을 이름에 담는다"
assert_contains "$GATE" '--quote-file "$STATE_DIR/said-<id>.txt"' "양의 짝: 게이트의 사용자 문구는 항목별 파일로 넘긴다"
assert_contains "$VER" '--extra-approval="$q"' "추가 라운드 승인도 파일에서 받은 문구로 넘긴다"
assert_contains "$GATE" '**Write' "양의 짝: 문구 파일은 Write 도구로 쓴다(셸로 쓰지 않는다)"
# check-intent 는 결과를 스스로 원장에 적는다 — 뒤따르는 fix 호출은 이중 기록이다.
assert_contains "$GATE" "check-intent <id> --intent '#__doc__'" "fix 적용은 check-intent 를 부른다(양의 짝)"
assert_not_contains "$GATE" '--event intent-pass' "check-intent 뒤에 intent-pass 를 따로 적지 않는다"
assert_not_contains "$GATE" '--event escalate' "check-intent 뒤에 escalate 를 따로 적지 않는다"

# ── 막는 문장 — 라운드 게이트 · 저자 편집 · 확정 직전의 차단 규칙(AC3b · AC3d · AC6) ─────
# 줄바꿈으로 감싼 문장을 잇고 여러 칸 공백을 하나로 접어 잰다. 각 문장을 지운 사본에서 이 함수가
# 그 이름으로 실패하는지 아래에서 본다 — 통과만으로는 이빨을 판별할 수 없다.
blocking_fails() {   # blocking_fails <SKILL 경로> → 빠진 차단 문장 이름을 한 줄씩
  local g d f
  g="$(subsection "$1" '^### 게이트' | tr '\n' ' ' | tr -s ' ')"
  d="$(subsection "$1" '^### 저자 편집 공시' | tr '\n' ' ' | tr -s ' ')"
  f="$(section "$1" '^## 확정 — proceed 게이트$' | tr '\n' ' ' | tr -s ' ')"
  printf '%s' "$g" | grep -qF '하나라도 0 이 아니면 라운드 게이트를 띄운다' || echo "gate_open_rule"
  printf '%s' "$g" | grep -qF '`round_gate_needed` 가 거짓이어도' || echo "gate_engine_override"
  printf '%s' "$d" | grep -qF '덩어리마다 질문 하나' || echo "hunk_question"
  printf '%s' "$d" | grep -qF '처분 없이는 다음 단계로 가지 않는다' || echo "hunk_blocks"
  printf '%s' "$f" | grep -qF '하나라도 막히면 게이트를 띄우지 않습니다' || echo "final_blocks"
}
bf="$(blocking_fails "$SK")"
[ -z "$bf" ] && ok "차단 문장 다섯이 제자리에 있다(게이트 열기 · 엔진 무시 · 덩어리 질문 · 덩어리 차단 · 확정 차단)" \
  || no "차단 문장 빠짐: $(printf '%s' "$bf" | tr '\n' ' ')"
TMPB="$(mktemp -d -t sd-framing-block-XXXXXX)" || exit 1
for pair in "gate_open_rule|하나라도 0 이 아니면 라운드 게이트를 띄운다" "gate_engine_override|가 거짓이어도" \
            "hunk_question|덩어리마다 질문 하나" "hunk_blocks|처분 없이는 다음 단계로 가지 않는다" \
            "final_blocks|하나라도 막히면 게이트를 띄우지 않습니다"; do
  name="${pair%%|*}"; phrase="${pair#*|}"
  PH="$phrase" python3 -c '
import os, sys
t = open(sys.argv[1], encoding="utf-8").read()
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(os.environ["PH"], "X", 1))
sys.exit(0 if os.environ["PH"] in t else 3)
' "$SK" "$TMPB/sk-$name.md" || { no "변이 $name: 치환 대상을 못 찾았다 — 이 변이는 아무것도 재지 않았다"; continue; }
  blocking_fails "$TMPB/sk-$name.md" | grep -qx "$name" \
    && ok "변이 $name: 그 문장을 지우면 '$name' 로 실패한다(이빨 있음)" \
    || no "변이 $name: 지워도 '$name' 가 안 나온다 — 그 단언은 다른 이유로 통과한다"
done
rm -rf "$TMPB"
GB="$(bash_lines "$GATE")"
assert_contains "$GB" '"ask_open"' "AC3d: 요약 펜스가 ask_open 을 센다(실행 줄)"
assert_contains "$GB" '"unapplied_fix"' "AC3b: 요약 펜스가 unapplied_fix 를 센다(엔진이 fix 로 라운드 게이트를 열지 않는다)"
assert_contains "$GB" 'seed_review_log.py" check-drops' "AC12: 라운드 게이트 뒤 문구 없는 drop 검사(실행 줄)"

# ── AC6 · AC6b — 저자 편집 공시 ──────────────────────────────────────────────
DISC="$(subsection "$SK" '^### 저자 편집 공시')"
[ -n "$DISC" ] && ok "절 추출: ### 저자 편집 공시" || no "절 추출: ### 저자 편집 공시 가 비었다"
DB="$(bash_lines "$DISC")"
assert_contains "$DB" 'seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS"' "AC6: 공시 펜스가 기준 사본 diff 를 낸다(실행 줄)"
assert_contains "$DISC" "저자 편집 없음" "AC6: 빈 diff 를 침묵과 구분한다"
assert_contains "$DISC" "권장 표시를 달지 않는다" "D15: 덩어리 처분에 저자 권장이 없다"
ln_rev="$(printf '%s\n' "$DB" | grep -n 'seed_edit_diff.py" revert' | head -1 | cut -d: -f1)"
ln_log="$(printf '%s\n' "$DB" | grep -n 'seed_review_log.py" log' | head -1 | cut -d: -f1)"
ln_acc="$(printf '%s\n' "$DB" | grep -n 'seed_edit_diff.py" accept' | head -1 | cut -d: -f1)"
if [ -n "$ln_rev" ] && [ -n "$ln_log" ] && [ -n "$ln_acc" ] && [ "$ln_rev" -lt "$ln_log" ] && [ "$ln_log" -lt "$ln_acc" ]; then
  ok "AC6b: 되돌리기 → 기록 → 기준 사본 교체 순서(교체는 맨 끝)"
else
  no "AC6b: revert($ln_rev) · log($ln_log) · accept($ln_acc) 순서가 아니다 — 공시 전 교체는 그 사이 편집을 지운다"
fi
# ── T10-b — revert · accept 의 rc 4(공시 뒤 seed 재변경) 처리 규약 ────────────
assert_contains "$DISC" "위 공시 펜스를 다시 돌려 다시 처분받습니다" "T10-b: rc 4 는 기준 사본을 바꾸지 않고 공시를 다시 돈다"
assert_contains "$DISC" "처분 하나에 한 번만" "T10-b: revert 는 처분마다 한 번만 — --ids 를 쉼표로 모아 한 번에"
assert_contains "$DISC" "부르면 매번 «공시됨»으로 기록" "T10-b: hunks 는 사용자에게 보일 자리에서만 부른다"
assert_contains "$DISC" "rc 4" "fix1 고정: 리터럴 rc 4 가 문구에 있다(rc 3 으로 바뀌면 RED)"
FIN="$(section "$SK" '^## 확정 — proceed 게이트$')"
[ -n "$FIN" ] && ok "절 추출: ## 확정" || no "절 추출: ## 확정 이 비었다"
FB="$(bash_lines "$FIN")"
assert_contains "$FB" 'seed_edit_diff.py" hunks "$SEED_BASE" "$SEED_ABS"' "AC6: 확정 게이트 직전에도 공시 펜스(실행 줄)"
assert_contains "$FB" 'seed_review_log.py" check-drops' "AC12: 확정 게이트 직전 문구 없는 drop 검사(실행 줄)"

# ── AC13 — 표시 검사 배선 ─────────────────────────────────────────────────────
AFTER="$(subsection "$SK" '^### seed 를 쓴 직후')"
assert_contains "$(bash_lines "$AFTER")" 'seed_provenance.py" marks "$SEED_ABS" "$AUDIT_ABS" --fix' "AC13: seed 를 쓴 직후 근거 없는 표시를 뗀다(실행 줄)"
assert_contains "$(bash_lines "$AFTER")" 'seed_edit_diff.py" init "$SEED_BASE" "$SEED_ABS"' "AC6b: 기준 사본은 seed 를 쓴 직후 처음 뜬다(실행 줄)"
assert_contains "$FB" 'seed_provenance.py" marks "$SEED_ABS" "$AUDIT_ABS"' "AC13: 확정 게이트 직전 표시 검사(실행 줄)"
assert_not_contains "$(printf '%s\n' "$FB" | grep 'seed_provenance.py" marks')" '--fix' "확정 직전 검사는 떼지 않는다 — 떼는 것도 편집이라 공시를 거친다"

# ── 차가운 실행 — 게이트 요약 펜스와 drop 검사 펜스 ──────────────────────────
export PYTHONDONTWRITEBYTECODE=1
T="$(mktemp -d -t sd-framing-contract-XXXXXX)" || exit 1
trap 'rm -rf "$T"' EXIT
S="$ROOT/plugins/spec-distill/scripts"
nth_bash_with() {   # nth_bash_with <텍스트> <고정 문자열> → 그 문자열을 담은 첫 bash 펜스
  printf '%s\n' "$1" | awk -v pat="$2" '/^```bash[[:space:]]*$/ {b=1; buf=""; next}
    b && /^```/ {b=0; if (!done && index(buf, pat)) {printf "%s", buf; done=1}; next}
    b {buf = buf $0 "\n"}'
}
nth_bash_with "$GATE" '"unapplied_fix"' > "$T/summary.sh"
nth_bash_with "$GATE" 'check-drops' > "$T/drops.sh"
printf -- '---\ntype: interview-seed\n---\n\n로그인이 가끔 실패한다.\n' > "$T/s.md"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/s.audit.md"
D="$T/state"; mkdir -p "$D"
python3 "$S/docreview_state.py" init --state-dir "$D" --doc "$T/s.md" --profile "$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md" >/dev/null
python3 "$S/docreview_anchor.py" snapshot "$T/s.md" > "$D/snap.json"
python3 "$S/docreview_state.py" begin-round --state-dir "$D" --snapshot "$D/snap.json" >/dev/null
cat > "$D/critic.txt" <<'EOF'
```docreview-layer1
- ref: c1
  category: premature_closure
  anchor: "#__doc__"
  disposition: fix
  summary: "CT_FIX"
- ref: c2
  category: unfounded_addition
  anchor: "#__doc__"
  disposition: ask
  summary: "CT_ASK"
```
```docreview-layer2
[]
```
EOF
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$D" --critic "$D/critic.txt" > "$D/prep.json"
python3 "$S/docreview_route.py" finalize --state-dir "$D" --recritic-skipped --doc "$T/s.md" > "$D/fin.json"
cold() { env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" STATE_DIR="$D" AUDIT_ABS="$T/s.audit.md" bash "$1" 2>"$1.err"; }
coldx() {   # coldx <펜스 파일> <VAR=값 …> — 차가운 셸에서 펜스를 돌리고 stderr 는 <펜스 파일>.err 로
  f="$1"; shift
  env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" "$@" bash "$f" 2>"$f.err"
}
sum_out="$(cold "$T/summary.sh")"
assert_contains "$sum_out" "unapplied_fix=1" "AC3b 실행: 엔진이 라운드 게이트를 열지 않는 fix 를 호스트 요약이 센다"
assert_contains "$sum_out" "ask_open=1" "AC3d 실행: 아무것도 막지 않는 ask 를 호스트 요약이 센다"
assert_contains "$sum_out" "round_gate_needed=False" "전제: 이 라운드에 엔진은 라운드 게이트를 열지 않는다(호스트 게이트가 필요한 이유)"
FIX_ID="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")=="CT_FIX"][0])' "$D/fin.json")"
python3 "$S/docreview_state.py" fix --state-dir "$D" --id "$FIX_ID" --event drop --log-file "$T/s.audit.md" >/dev/null
assert_contains "$(cold "$T/drops.sh")" "drops_rc=1" "AC12 실행: 문구 없이 누른 drop 이면 검사 펜스가 막는다"
python3 "$S/seed_review_log.py" log "$T/s.audit.md" --kind 거부 --round 1 --target "$FIX_ID" --quote "CT_USER_REFUSE" --note "다시 물어 받은 문구" >/dev/null
assert_contains "$(cold "$T/drops.sh")" "drops_rc=0" "AC12 양성 대조: 사용자 문구를 채우면 통과한다"

# ── 답 기록 펜스 — 기록이 먼저, 성공했을 때만 ask 를 닫는다 ─────────────────────
ASK_ID="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")=="CT_ASK"][0])' "$D/fin.json")"
nth_bash_with "$GATE" 'kind 답' | sed -e 's/<n>/1/g' -e "s/<id>/$ASK_ID/g" > "$T/answer.sh"
[ -s "$T/answer.sh" ] && ok "추출: 답 기록 펜스" || no "추출: 답 기록 펜스가 비었다 — 아래 판정은 무의미하다"
n_ans() { grep -c '^- 답 · ' "$T/s.audit.md" || true; }
a0="$(n_ans)"
SAID_ASK="$D/said-$ASK_ID.txt"; NOTE_ASK="$D/note-$ASK_ID.txt"
rm -f "$SAID_ASK" "$NOTE_ASK"
assert_contains "$(cold "$T/answer.sh")" "ans_rc=2" "답 펜스: 문구 파일이 없으면 기록이 실패한다(rc 2)"
assert_contains "$(cold "$T/summary.sh")" "ask_open=1" "답 펜스: 기록이 실패하면 ask 를 닫지 않는다"
assert_eq "$(n_ans)" "$a0" "답 펜스: 실패한 기록은 audit 에 줄을 남기지 않는다"
printf 'ANSWER_LINE_ONE\n`touch %s/PWNED`\n' "$T" > "$SAID_ASK"; printf 'ASK 요약 $(touch %s/PWNED2)\n' "$T" > "$NOTE_ASK"
assert_contains "$(cold "$T/answer.sh")" "ans_rc=0" "답 펜스: 문구 파일이 있으면 기록하고 ask 를 닫는다"
assert_contains "$(cold "$T/summary.sh")" "ask_open=0" "답 펜스: 기록이 성공한 뒤에만 ask 가 닫혔다"
assert_eq "$(n_ans)" "$((a0 + 1))" "답 펜스: audit ## 6 에 답 줄이 정확히 하나 늘었다"
assert_contains "$(grep '^- 답 · ' "$T/s.audit.md" | tail -1)" 'ANSWER_LINE_ONE `touch' "답 펜스: 여러 줄 문구가 한 줄로 이어져 기록된다"
[ ! -e "$T/PWNED" ] && [ ! -e "$T/PWNED2" ] && ok "답 펜스: 문구 · 요약 안의 백틱 · \$( ) 가 실행되지 않았다" \
  || no "답 펜스: 문구 파일의 명령이 셸에서 실행됐다"
[ ! -e "$SAID_ASK" ] && [ ! -e "$NOTE_ASK" ] && ok "답 펜스: 기록이 성공하면 문구 파일을 지운다" || no "답 펜스: 성공한 뒤에도 문구 파일이 남았다 — 다음에 Write 를 빠뜨리면 재사용된다"
assert_contains "$(cold "$T/answer.sh")" "ans_rc=2" "답 펜스: Write 없이 다시 돌리면 지난 문구를 쓰지 않고 막힌다(재사용 없음)"
assert_eq "$(n_ans)" "$((a0 + 1))" "답 펜스: 재사용 시도가 줄을 남기지 않았다"

# ── 처분 펜스(drop · decide) — 문구 파일에서 먼저 받고, 없으면 누르지 않는다 ─────
D2="$T/state2"; mkdir -p "$D2"; cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/s2.audit.md"
python3 "$S/docreview_state.py" init --state-dir "$D2" --doc "$T/s.md" --profile "$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md" >/dev/null
python3 "$S/docreview_anchor.py" snapshot "$T/s.md" > "$D2/snap.json"
python3 "$S/docreview_state.py" begin-round --state-dir "$D2" --snapshot "$D2/snap.json" >/dev/null
cat > "$D2/critic.txt" <<'EOF'
```docreview-layer1
- ref: c1
  category: premature_closure
  anchor: "#__doc__"
  disposition: fix
  summary: "CT2_FIX"
- ref: c2
  category: inference_as_decision
  anchor: "#__doc__"
  disposition: decide
  summary: "CT2_DEC"
```
```docreview-layer2
[]
```
EOF
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$D2" --critic "$D2/critic.txt" > "$D2/prep.json"
python3 "$S/docreview_route.py" finalize --state-dir "$D2" --recritic-skipped --doc "$T/s.md" > "$D2/fin.json"
id2() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")==sys.argv[2]][0])' "$D2/fin.json" "$1"; }
FIX2="$(id2 CT2_FIX)"; DEC2="$(id2 CT2_DEC)"
disp_engine() {   # disp_engine <id> <EVENT> → 자리표를 채운 처분 펜스
  nth_bash_with "$GATE" 'one-line "$STATE_DIR/said-<id>.txt"' | sed -e "s/<id>/$1/g" -e "s/<drop | adopt | reject | hold>/$2/"
}
cold2() { coldx "$1" STATE_DIR="$D2" AUDIT_ABS="$T/s2.audit.md"; }
dropped2() { python3 "$S/docreview_state.py" gate --state-dir "$D2" | python3 -c 'import json,sys; print(" ".join(json.load(sys.stdin)["dropped"]))'; }
disp_engine "$FIX2" drop > "$T/drop.sh"
[ -s "$T/drop.sh" ] && ok "추출: 처분 펜스" || no "추출: 처분 펜스가 비었다 — 아래 판정은 무의미하다"
assert_contains "$(cold2 "$T/drop.sh")" "q_rc=2" "처분 펜스(drop): 문구 파일이 없으면 누르지 않는다(rc 2)"
assert_not_contains "$(dropped2)" "$FIX2" "처분 펜스(drop): 문구 없이는 엔진에 drop 이 들어가지 않았다"
printf -- '-적용하지 않음 `touch %s/PWNED3`\n' "$T" > "$D2/said-$FIX2.txt"
assert_contains "$(cold2 "$T/drop.sh")" "q_rc=0" "처분 펜스(drop): 문구 파일이 있으면 누른다"
assert_contains "$(dropped2)" "$FIX2" "처분 펜스(drop): 엔진이 drop 을 셌다"
assert_eq "$(python3 "$S/seed_review_log.py" check-drops "$T/s2.audit.md" <(python3 "$S/docreview_state.py" gate --state-dir "$D2") >/dev/null 2>&1; echo $?)" "0" "처분 펜스(drop): 그 drop 은 문구 있는 drop 이다(AC12 통과)"
assert_contains "$(grep -F "$FIX2" "$T/s2.audit.md")" '"-적용하지 않음 `touch' "처분 펜스(drop): '-' 로 시작하는 문구도 그대로 실린다(= 꼴)"
[ ! -e "$T/PWNED3" ] && ok "처분 펜스(drop): 문구 안의 백틱이 실행되지 않았다" || no "처분 펜스(drop): 문구 파일의 명령이 셸에서 실행됐다"
[ ! -e "$D2/said-$FIX2.txt" ] && ok "처분 펜스(drop): 성공하면 문구 파일을 지운다" || no "처분 펜스(drop): 성공한 뒤에도 문구 파일이 남았다"
disp_engine "$DEC2" adopt > "$T/decide.sh"
printf '채택 (권장)\n' > "$D2/said-$DEC2.txt"
assert_contains "$(cold2 "$T/decide.sh")" "q_rc=0" "처분 펜스(decide): 문구와 함께 결정을 적는다"
assert_contains "$(grep -F "$DEC2" "$T/s2.audit.md")" '· adopt ·' "처분 펜스(decide): audit ## 6 에 채택 줄이 섰다"
assert_contains "$(grep -F "$DEC2" "$T/s2.audit.md")" '"채택 (권장)"' "처분 펜스(decide): 사용자 문구가 줄에 실렸다"

# ── T10-d — 확정 직전 공시가 기준 사본 부재를 «저자 편집 없음»으로 내지 않는다 ─
mkdir -p "$T/final2"
printf -- '---\ntype: interview-seed\n---\n\nFINAL_SEED_LINE.\n' > "$T/final2/seed.md"
nth_bash_with "$FIN" 'hunks-final.json' > "$T/final_disc.sh"
cold3() { env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" STATE_DIR="$T/final2" SEED_BASE="$T/final2/missing-baseline.md" SEED_ABS="$T/final2/seed.md" bash "$1" 2>"$1.err"; }
fd_out="$(cold3 "$T/final_disc.sh")"
assert_not_contains "$fd_out" "저자 편집 없음" "T10-d: 확정 직전 공시가 기준 사본 부재를 «저자 편집 없음»으로 내지 않는다"
assert_contains "$(cat "$T/final_disc.sh.err")" "기준 사본이 없다" "T10-d: 확정 직전 공시가 기준 사본 부재를 알린다"

# ── 확정 직전 표시 검사가 rc1 목록을 삼키지 않는다 ───────────────────────────
nth_bash_with "$FIN" 'seed_provenance.py' > "$T/marks_final.sh"
mkdir -p "$T/marksA/state"
cat > "$T/marksA/a.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

나는 클라이언트 쪽 경합을 의심하는데 확신은 없다.

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「세션 스토어 개편은 이번에 하지 않는다 — 다음 분기에 따로 한다.」 — 고름
  - 내가 읽은 것: 「경합이 원인이다.」 — 고르지 않음
EOF
printf -- '---\ntype: interview-seed\n---\n\n경합이 원인이다. (사용자 확인)\n' > "$T/marksA/seed.md"
coldm() { env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" STATE_DIR="$T/marksA/state" SEED_ABS="$T/marksA/seed.md" AUDIT_ABS="$T/marksA/a.audit.md" bash "$1" 2>"$1.err"; }
outA="$(coldm "$T/marks_final.sh")"
assert_contains "$outA" "경합이 원인이다." "fix1(a): rc1 의 근거 없는 표시 목록이 stdout 에 그대로 남는다(더 이상 /dev/null 로 안 간다)"
assert_contains "$outA" "marks_rc=1" "fix1(a): marks_rc 도 같은 출력에 함께 보인다"

mkdir -p "$T/marksB/state"
cat > "$T/marksB/a.audit.md" <<'EOF'
---
type: interview-seed-audit
---

## 1. 원문

사용자가 이렇게 말했다:
## 2. 질문 전체
을 확인해 달라고 했다.

## 2. 질문 전체

### 라운드 1

- 확인 질문: 라운드 1
  - 내가 읽은 것: 「무엇이든」 — 고름
EOF
printf -- '---\ntype: interview-seed\n---\n\n문장 하나. (사용자 확인)\n' > "$T/marksB/seed.md"
cp "$T/marksB/seed.md" "$T/marksB/seed.before"
coldm2() { env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" STATE_DIR="$T/marksB/state" SEED_ABS="$T/marksB/seed.md" AUDIT_ABS="$T/marksB/a.audit.md" bash "$1" 2>"$1.err"; }
coldm2 "$T/marks_final.sh" >/dev/null
assert_contains "$(cat "$T/marks_final.sh.err")" "표시 검사 불가" "fix1(b): 제목이 중복된(못 믿는) audit 은 «표시 검사 불가» 로 막는다(rc2 ≠ 위반)"
assert_eq "$(cmp -s "$T/marksB/seed.md" "$T/marksB/seed.before" && echo same)" "same" "fix1(b): 검사 1 은 검사만 — seed 의 sha 가 그대로다"

# ── revert 실패면 log · accept 를 돌리지 않는다(기준 사본 보존) ────────────────
mkdir -p "$T/revert1"
printf 'line one\n' > "$T/revert1/base.md"
printf 'line one changed\n' > "$T/revert1/seed.md"
python3 "$S/seed_edit_diff.py" hunks "$T/revert1/base.md" "$T/revert1/seed.md" >/dev/null
cp "$T/revert1/base.md" "$T/revert1/base.before"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/revert1/a.audit.md"
n6_before="$(grep -c '^- 편집' "$T/revert1/a.audit.md" || true)"
nth_bash_with "$DISC" 'seed_edit_diff.py" revert' | sed \
  -e 's/<덩어리마다 한 줄 — 번호:처분>/99:되돌린다/' \
  -e 's/<n>/1/' > "$T/revert_fence.sh"
printf 'QUOTE_99\n' > "$T/revert1/said-hunk-99.txt"
coldr() { env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 SD="$ROOT/plugins/spec-distill" STATE_DIR="$T/revert1" SEED_BASE="$T/revert1/base.md" SEED_ABS="$T/revert1/seed.md" AUDIT_ABS="$T/revert1/a.audit.md" bash "$1" 2>"$1.err"; }
outR="$(coldr "$T/revert_fence.sh")"
n6_after="$(grep -c '^- 편집' "$T/revert1/a.audit.md" || true)"
assert_contains "$outR" "rev_rc=2" "fix2: 없는 덩어리 번호(--ids 99) 는 revert rc 2 로 막힌다"
assert_eq "$(cmp -s "$T/revert1/base.md" "$T/revert1/base.before" && echo same)" "same" "fix2: revert 실패면 기준 사본(accept)이 바뀌지 않는다"
assert_eq "$n6_after" "$n6_before" "fix2: revert 실패면 log 도 돌지 않는다 — audit ## 6 에 편집 줄이 늘지 않는다"

# ── 공시 펜스 둘 — 기준 사본이 있을 때(AC6 의 양의 짝) ──────────────────────────
# T10-d 는 기준 사본 부재만 잰다. 여기서는 같은 두 펜스(라운드 게이트 앞 · 확정 직전)를 기준 사본이
# 있는 채로 돌려, 편집이 없으면 «저자 편집 없음» 을, 있으면 덩어리를 내는지 본다.
nth_bash_with "$DISC" 'hunks.json' > "$T/round_disc.sh"
[ -s "$T/round_disc.sh" ] && ok "추출: 라운드 게이트 앞 공시 펜스" || no "추출: 라운드 게이트 앞 공시 펜스가 비었다"
for fence in round_disc final_disc; do
  mkdir -p "$T/d-$fence"
  printf 'SAME 줄 하나\nSAME 줄 둘\n' > "$T/d-$fence/seed.md"; cp "$T/d-$fence/seed.md" "$T/d-$fence/base.md"
  printf 'OLD_DISCLOSURE_QUOTE\n' > "$T/d-$fence/said-hunk-1.txt"
  outE="$(coldx "$T/$fence.sh" STATE_DIR="$T/d-$fence" SEED_BASE="$T/d-$fence/base.md" SEED_ABS="$T/d-$fence/seed.md")"
  [ ! -e "$T/d-$fence/said-hunk-1.txt" ] && ok "$fence: 공시할 때 지난 공시의 덩어리 문구 파일을 지운다" \
    || no "$fence: 지난 공시의 덩어리 문구 파일이 남았다 — 번호가 다시 매겨진 덩어리에 그 문구가 쓰인다"
  assert_contains "$outE" "저자 편집 없음" "$fence: 기준 사본 = seed 면 «저자 편집 없음» 을 낸다"
  [ -s "$T/d-$fence/base.md.shown" ] && ok "$fence: 공시가 보인 판본을 못박았다(.shown)" || no "$fence: .shown 이 없다 — 이 공시 뒤의 revert · accept 가 rc 4 로 막힌다"
  printf 'SAME 줄 하나\nEDITED_BY_AUTHOR 줄 둘\n' > "$T/d-$fence/seed.md"
  outH="$(coldx "$T/$fence.sh" STATE_DIR="$T/d-$fence" SEED_BASE="$T/d-$fence/base.md" SEED_ABS="$T/d-$fence/seed.md")"
  assert_contains "$outH" "덩어리 1 — 기준" "$fence: 편집이 있으면 덩어리 머리줄을 낸다"
  assert_contains "$outH" "+ EDITED_BY_AUTHOR 줄 둘" "$fence: 편집된 줄을 줄임 없이 낸다"
  assert_not_contains "$outH" "저자 편집 없음" "$fence: 편집이 있는데 «저자 편집 없음» 을 내지 않는다"
done

# ── 처분 펜스 — 성공 경로(되돌리기 → 기록 → 교체) · 기록 실패 · 부분 실패 뒤 재실행 ──────────
disp_fence() {   # disp_fence <PAIRS(줄바꿈은 \n 으로)> → 자리표를 채운 처분 펜스를 stdout 으로
  nth_bash_with "$DISC" 'seed_edit_diff.py" revert' | PAIRS_IN="$1" python3 -c '
import os, sys
t = sys.stdin.read()
t = t.replace("<덩어리마다 한 줄 — 번호:처분>", os.environ["PAIRS_IN"].replace("\\n", "\n"), 1)
sys.stdout.write(t.replace("<n>", "1"))
'
}
setup_disp() {   # setup_disp <디렉토리> → base · seed(한 줄 편집) · audit 을 만들고 편집을 공시한다
  mkdir -p "$1"
  printf 'KEEP 줄\nBASE_LINE 줄\n' > "$1/base.md"; printf 'KEEP 줄\nAUTHOR_EDIT 줄\n' > "$1/seed.md"
  cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$1/a.audit.md"
  python3 "$S/seed_edit_diff.py" hunks "$1/base.md" "$1/seed.md" >/dev/null
}
coldd() { coldx "$1" STATE_DIR="$2" SEED_BASE="$2/base.md" SEED_ABS="$2/seed.md" AUDIT_ABS="$2/a.audit.md"; }
n_edit() { grep -c '^- 편집 · ' "$1/a.audit.md" || true; }
# (a) 되돌린다 — seed 가 기준으로 돌아오고, 기록 한 줄 뒤 기준 사본이 seed 와 같아진다
setup_disp "$T/dispA"; printf 'QUOTE_REVERT\n' > "$T/dispA/said-hunk-1.txt"
disp_fence '1:되돌린다' > "$T/dispA.sh"
outA="$(coldd "$T/dispA.sh" "$T/dispA")"
assert_contains "$outA" "pre_rc=0 rev_rc=0 log_rc=0" "처분 (a): 되돌리기 · 기록이 성공한다"
assert_contains "$outA" "accept_rc=0" "처분 (a): 기록 뒤 기준 사본을 교체한다"
assert_eq "$(grep -c '^- 편집 · r1 · 덩어리 1 · 되돌린다 · "QUOTE_REVERT" —$' "$T/dispA/a.audit.md")" "1" "처분 (a): audit ## 6 에 편집 줄이 정확히 하나"
assert_eq "$(cat "$T/dispA/seed.md")" "$(printf 'KEEP 줄\nBASE_LINE 줄')" "처분 (a): 되돌린 덩어리가 seed 에서 기준으로 돌아왔다"
assert_eq "$(cmp -s "$T/dispA/base.md" "$T/dispA/seed.md" && echo same)" "same" "처분 (a): 교체 뒤 기준 사본 = seed"
[ ! -e "$T/dispA/said-hunk-1.txt" ] && ok "처분 (a): 교체까지 끝나면 덩어리 문구 파일을 지운다" || no "처분 (a): 끝난 뒤에도 덩어리 문구 파일이 남았다"
# (b) 그대로 둔다 — 되돌릴 번호가 없으면 revert 없이 편집된 seed 가 새 기준이 된다
setup_disp "$T/dispB"; printf 'QUOTE_KEEP\n' > "$T/dispB/said-hunk-1.txt"
disp_fence '1:그대로 둔다' > "$T/dispB.sh"
outB="$(coldd "$T/dispB.sh" "$T/dispB")"
assert_contains "$outB" "accept_rc=0" "처분 (b): 그대로 두면 기록 뒤 교체한다"
assert_eq "$(cat "$T/dispB/base.md")" "$(printf 'KEEP 줄\nAUTHOR_EDIT 줄')" "처분 (b): 편집된 seed 가 새 기준 사본이 됐다"
assert_eq "$(grep -c '^- 편집 · r1 · 덩어리 1 · 그대로 둔다 · "QUOTE_KEEP" —$' "$T/dispB/a.audit.md")" "1" "처분 (b): 편집 줄이 정확히 하나"
# (c) 문구 파일 없음 — 아무것도 바꾸지 않는다(되돌리기 전에 멈춘다)
setup_disp "$T/dispC"; cp "$T/dispC/base.md" "$T/dispC/base.before"; cp "$T/dispC/seed.md" "$T/dispC/seed.before"
disp_fence '1:되돌린다' > "$T/dispC.sh"
outC="$(coldd "$T/dispC.sh" "$T/dispC")"
assert_contains "$outC" "pre_rc=2" "처분 (c): 문구 파일이 없으면 시작 전에 멈춘다"
assert_not_contains "$outC" "accept_rc=" "처분 (c): accept 를 부르지 않는다"
assert_eq "$(cmp -s "$T/dispC/seed.md" "$T/dispC/seed.before" && cmp -s "$T/dispC/base.md" "$T/dispC/base.before" && echo same)" "same" "처분 (c): seed 도 기준 사본도 그대로다(되돌리기 전에 멈췄다)"
assert_eq "$(n_edit "$T/dispC")" "0" "처분 (c): 편집 줄을 남기지 않는다"
# (d) 두 덩어리 — 첫 기록이 실패하면(뒤 기록은 성공해도) 교체하지 않고, 원인을 고쳐 통째로 다시 돌리면
#     남기기로 한 덩어리가 산다. 실패가 마지막이 아니어야 반복문 꼬리(`|| log_rc=$?`)의 이빨이 보인다.
mkdir -p "$T/dispD"
printf 'L1\nBASE_2\nL3\nL4\nL5\nL6\nBASE_7\nL8\n' > "$T/dispD/base.md"
printf 'L1\nEDIT_2\nL3\nL4\nL5\nL6\nEDIT_7\nL8\n' > "$T/dispD/seed.md"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/dispD/a.audit.md"
python3 "$S/seed_edit_diff.py" hunks "$T/dispD/base.md" "$T/dispD/seed.md" > "$T/dispD/h.json"
assert_eq "$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["hunks"]))' "$T/dispD/h.json")" "2" "처분 (d) 전제: 덩어리 둘"
cp "$T/dispD/base.md" "$T/dispD/base.before"
printf '   \n' > "$T/dispD/said-hunk-1.txt"; printf 'QUOTE_D2\n' > "$T/dispD/said-hunk-2.txt"
disp_fence '1:되돌린다\n2:그대로 둔다' > "$T/dispD.sh"
outD1="$(coldd "$T/dispD.sh" "$T/dispD")"
assert_contains "$outD1" "log_rc=2" "처분 (d): 첫 덩어리의 기록이 실패하면 뒤 기록이 성공해도 log_rc 가 남는다(공백뿐인 문구)"
assert_not_contains "$outD1" "accept_rc=" "처분 (d): 기록이 하나라도 실패하면 교체하지 않는다"
assert_eq "$(cmp -s "$T/dispD/base.md" "$T/dispD/base.before" && echo same)" "same" "처분 (d): 기준 사본이 그대로다"
assert_contains "$(cat "$T/dispD.sh.err")" "said-hunk-1.txt" "처분 (d): 실패한 기록이 어느 덩어리 파일인지 댄다"
printf 'QUOTE_D1\n' > "$T/dispD/said-hunk-1.txt"
outD2="$(coldd "$T/dispD.sh" "$T/dispD")"
assert_contains "$outD2" "accept_rc=0" "처분 (d): 원인을 고쳐 통째로 다시 돌리면 끝난다"
assert_contains "$(cat "$T/dispD/seed.md")" "EDIT_7" "처분 (d): 다시 돌려도 남기기로 한 덩어리가 산다(번호가 다시 매겨진 덩어리를 되돌리지 않는다)"
assert_contains "$(cat "$T/dispD/seed.md")" "BASE_2" "처분 (d): 되돌린 덩어리는 되돌린 채다"
assert_eq "$(n_edit "$T/dispD")" "3" "처분 (d): 다시 돈 만큼 편집 줄이 겹친다(먼저 성공한 하나 + 다시 돈 둘) — 겹칠지언정 사라지지 않는다"
assert_eq "$(cmp -s "$T/dispD/base.md" "$T/dispD/seed.md" && echo same)" "same" "처분 (d): 교체 뒤 기준 사본 = seed"
# (e) 재사용 없음 — 끝난 처분 뒤 새 공시에 Write 없이 돌리면 지난 문구를 쓰지 않는다
printf 'L1\nBASE_2\nL3\nL4\nL5\nL6\nEDIT_7_AGAIN\nL8\n' > "$T/dispD/seed.md"
python3 "$S/seed_edit_diff.py" hunks "$T/dispD/base.md" "$T/dispD/seed.md" >/dev/null
outE2="$(coldd "$T/dispD.sh" "$T/dispD")"
assert_contains "$outE2" "pre_rc=2" "처분 (e): Write 없이 다시 돌리면 지난 문구를 쓰지 않고 멈춘다"
assert_eq "$(n_edit "$T/dispD")" "3" "처분 (e): 재사용 시도가 줄을 남기지 않았다"
# (f) 같은 라운드의 두 공시 — 덩어리 번호가 공시마다 1 부터 다시 시작하니 글자가 같아진다. 두 처분은 두 줄이어야 한다.
setup_disp "$T/dispF"; printf 'QUOTE_SAME\n' > "$T/dispF/said-hunk-1.txt"
disp_fence '1:그대로 둔다' > "$T/dispF.sh"
outF1="$(coldd "$T/dispF.sh" "$T/dispF")"
assert_contains "$outF1" "accept_rc=0" "처분 (f) 전제: 첫 공시의 처분이 끝난다"
printf 'KEEP 줄\nAUTHOR_EDIT 줄\nSECOND_EDIT 줄\n' > "$T/dispF/seed.md"
python3 "$S/seed_edit_diff.py" hunks "$T/dispF/base.md" "$T/dispF/seed.md" >/dev/null
printf 'QUOTE_SAME\n' > "$T/dispF/said-hunk-1.txt"
outF2="$(coldd "$T/dispF.sh" "$T/dispF")"
assert_contains "$outF2" "accept_rc=0" "처분 (f): 둘째 공시의 처분도 끝난다"
assert_eq "$(grep -c '^- 편집 · r1 · 덩어리 1 · 그대로 둔다 · "QUOTE_SAME" —$' "$T/dispF/a.audit.md")" "2" "처분 (f): 같은 라운드 두 공시의 처분은 글자가 같아도 두 줄로 남는다"

# ── 확정 직전 검사 셋 — 엔진 자리가 사라졌거나(세션 정리) 라운드가 시작되지 않았을 때 ──
nth_bash_with "$FIN" 'gate-final.json' > "$T/final_drops.sh"
[ -s "$T/final_drops.sh" ] && ok "추출: 확정 직전 drop 검사 펜스" || no "추출: 확정 직전 drop 검사 펜스가 비었다 — 아래 판정은 무의미하다"
mkdir -p "$T/gc"
cp "$T/marksA/a.audit.md" "$T/gc/a.audit.md"
printf -- '---\ntype: interview-seed\n---\n\n세션 스토어 개편은 이번에 하지 않는다 — 다음 분기에 따로 한다. (사용자 확인)\n' > "$T/gc/seed.md"
# (i) 검사 1 · 2 — 없는 엔진 자리 디렉토리를 리다이렉트 실패로 오진하지 않는다
out_i1="$(coldx "$T/marks_final.sh" STATE_DIR="$T/gc/gone1" SEED_ABS="$T/gc/seed.md" AUDIT_ABS="$T/gc/a.audit.md")"
assert_contains "$out_i1" "marks_rc=0" "I2 검사 1: 엔진 자리가 사라져도 표시 검사는 실제 결과(근거 있는 표시 → 0)를 낸다"
assert_not_contains "$(cat "$T/marks_final.sh.err")" "근거 없는" "I2 검사 1: 빈 목록으로 «근거 없는 표시» 를 내지 않는다"
[ -d "$T/gc/gone1" ] && ok "I2 검사 1: 사라진 엔진 자리를 다시 만든다" || no "I2 검사 1: 사라진 엔진 자리를 다시 만들지 않았다"
coldx "$T/final_disc.sh" STATE_DIR="$T/gc/gone2" SEED_BASE="$T/gc/gone2/seed-baseline.md" SEED_ABS="$T/gc/seed.md" >/dev/null
assert_contains "$(cat "$T/final_disc.sh.err")" "기준 사본이 없다" "I2 검사 2: 엔진 자리가 사라지면 기준 사본 부재(rc 3) 경로로 간다"
assert_not_contains "$(cat "$T/final_disc.sh.err")" "(rc 1)" "I2 검사 2: 리다이렉트 실패(rc 1)로 오진하지 않는다"
# (ii) 엔진 원장 없음 + audit ## 6 에 drop 줄 없음 — 라운드가 시작되지 않은 세션
mkdir -p "$T/nl/state"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/nl/a.audit.md"
out_ii="$(coldx "$T/final_drops.sh" STATE_DIR="$T/nl/state" AUDIT_ABS="$T/nl/a.audit.md")"
assert_contains "$out_ii" "final_drops_rc=0" "I1 검사 3: 라운드가 시작되지 않은 세션도 확정 게이트에 닿는다"
assert_contains "$(cat "$T/final_drops.sh.err")" "엔진 원장 없음" "I1 검사 3: 엔진 원장 없이 audit ## 6 으로 대조했다고 밝힌다"
# (iii) 엔진 원장 없음(세션 정리로 자리째 걷힘) + 문구가 빈 엔진 drop 줄
mkdir -p "$T/gcd"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$T/gcd/a.audit.md"
printf -- '- D1.1 · r1 · drop · ffff0001#r1.1 · "" — GC_DROP 요약\n' >> "$T/gcd/a.audit.md"
out_iii="$(coldx "$T/final_drops.sh" STATE_DIR="$T/gcd/gone" AUDIT_ABS="$T/gcd/a.audit.md")"
assert_contains "$out_iii" "final_drops_rc=1" "I1 검사 3: 엔진 원장이 걷혀도 audit 에 기록된 문구 없는 drop 은 막는다"
python3 "$S/seed_review_log.py" log "$T/gcd/a.audit.md" --kind 거부 --round 1 --target "ffff0001#r1.1" --quote "GC_USER_REFUSE" --note "다시 물어 받은 문구" >/dev/null
assert_contains "$(coldx "$T/final_drops.sh" STATE_DIR="$T/gcd/gone" AUDIT_ABS="$T/gcd/a.audit.md")" "final_drops_rc=0" "I1 검사 3 양성 대조: 같은 항목에 거부 줄을 채우면 통과한다"
# (iv) UTF-8 이 아닌 audit — 엔진 원장은 있다. drop 검사는 «검사 불가»(rc 2)지 «거부 줄을 적어라» 가 아니다
printf '## 6. 리뷰 결정\n\n- \377\376 깨진 줄\n' > "$T/bad.audit.md"
out_iv="$(coldx "$T/final_drops.sh" STATE_DIR="$D" AUDIT_ABS="$T/bad.audit.md")"
assert_contains "$out_iv" "final_drops_rc=2" "I3 검사 3: audit 을 못 읽으면 rc 2 가 그대로 온다(1 로 눌리지 않는다)"
assert_contains "$(cat "$T/final_drops.sh.err")" "drop 검사 불가" "I3 검사 3: «검사 불가» 로 알린다"
assert_not_contains "$(cat "$T/final_drops.sh.err")" "거부 줄을 적은" "I3 검사 3: 거부 줄로 풀라는 지시를 내지 않는다"
assert_not_contains "$(cat "$T/final_drops.sh.err")" "Traceback" "check-drops 가 UTF-8 이 아닌 audit 에 트레이스백을 내지 않는다"
assert_contains "$(coldx "$T/drops.sh" STATE_DIR="$D" AUDIT_ABS="$T/bad.audit.md")" "drops_rc=2" "I3 라운드 게이트: audit 을 못 읽으면 drops_rc 2(1 로 눌리지 않는다)"
assert_not_contains "$(cat "$T/drops.sh.err")" "거부 줄을 적은" "I3 라운드 게이트: 거부 줄로 풀라는 지시를 내지 않는다"
# 엔진 자리 변수가 비었다 — 검사 1 은 한 줄로 알리고 실제 결과를, 검사 2 · 3 은 «검사 불가»
out_e1="$(coldx "$T/marks_final.sh" STATE_DIR= SEED_ABS="$T/gc/seed.md" AUDIT_ABS="$T/gc/a.audit.md")"
assert_contains "$out_e1" "marks_rc=0" "빈 STATE_DIR: 검사 1 은 실제 표시 결과를 낸다"
assert_contains "$(cat "$T/marks_final.sh.err")" "리뷰 엔진 자리 없음" "빈 STATE_DIR: 검사 1 이 한 줄로 알린다"
coldx "$T/final_disc.sh" STATE_DIR= SEED_BASE= SEED_ABS="$T/gc/seed.md" >/dev/null
assert_contains "$(cat "$T/final_disc.sh.err")" "검사 불가" "빈 STATE_DIR: 검사 2 는 «검사 불가»"
assert_contains "$(coldx "$T/final_drops.sh" STATE_DIR= AUDIT_ABS="$T/nl/a.audit.md")" "final_drops_rc=2" "빈 STATE_DIR: 검사 3 은 «검사 불가»(rc 2)"

# ── 템플릿 절 제목 중복의 출구 · 검사 2 뒤 되돌림 · 풀이 한 문장 ────────────────
BUN="$(subsection "$SK" '^### 번들')"
assert_contains "$BUN" "그 줄만 인용 표시로 감싼다" "I4: 중복 제목으로 막힌 번들의 출구 — 「멈춘다 / 감싼다」 를 묻는다"
assert_contains "$BUN" "append-only 의 유일한 예외" "I4: 감싸기는 ## 1 append-only 의 유일한 예외다"
assert_contains "$BUN" '`### codex` 펜스가 낸 `[spec-distill]` 줄도 같습니다' "codex 를 건너뛴 사유(엔진은 모른다)를 게이트 텍스트에 싣는다"
assert_contains "$FIN" "템플릿 절 제목 중복 절차" "I4: 확정 검사 1 의 rc 2 가 그 출구를 가리킨다"
assert_contains "$FIN" "「되돌린다」를 받으면 검사 1 부터" "검사 2 에서 되돌리면 검사 1 부터 다시 돈다"
assert_contains "$CQ" "풀이는 한 문장으로 쓴다" "여러 문장 풀이는 문장마다 표시한다(대조는 문장 단위)"

finish
