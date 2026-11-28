#!/usr/bin/env bash
# guards: plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/agents/code-recritic.md plugins/quality-gates/scripts/synthesize_findings.py
# test_lowered_gate_wiring.sh — 재비판이 낮춘 지적이 보이고 게이트에서 되올려진다(AC26).
#
# 문면 락은 각 사실이 적힌 절 창 안에서 잰다(제목이 대신 만족시키지 못하게). 이음매는 실제
# 합성기 출력을 SKILL 의 기록 블록에 넣어 돌려 본다 — 합성기가 내는 글자와 SKILL 이 찾는 글자가 같은지.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' \
  plugins/quality-gates/skills/quality-pipeline/SKILL.md \
  plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md \
  plugins/quality-gates/agents/code-recritic.md \
  plugins/quality-gates/scripts/synthesize_findings.py; exit 0; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
SK="${SK:-$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md}"
SF="${SF:-$PLUGIN_ROOT/skills/quality-pipeline/references/state-file-format.md}"
RC="${RC:-$PLUGIN_ROOT/agents/code-recritic.md}"
export PYTHONDONTWRITEBYTECODE=1

ROOT=$(mktemp -d)
trap 'rm -rf "$ROOT"' EXIT

# 창 — 시작 제목 줄부터 끝 제목 줄 앞까지(둘 다 줄 전체 일치).
window() { awk -v s="$2" -v e="$3" '$0==s{on=1} on&&$0==e{exit} on{print}' "$1"; }
# 창 안에서 글자가 처음 나오는 줄 번호(없으면 0).
line_of() { printf '%s\n' "$1" | grep -nF -- "$2" | head -1 | cut -d: -f1 | grep . || echo 0; }

S4="$(window "$SK" '### Step 4 — synthesis (after the differential test)' '### Step 4.5 — Surface the verdict')"
S45="$(window "$SK" '### Step 4.5 — Surface the verdict' '## Differential test')"

case_step4() {
  note "Step 4 — 되올려 다시 합성하기"
  assert_contains "$S4" '> "$RV/synth.out"' "전제: Step 4 창이 합성 펜스를 담는다"
  assert_contains "$S4" '**되올려 다시 합성하기.**' "Step 4: 다시 합성하기 문단이 있다"
  assert_contains "$S4" '`mv "$RV/synth.out" "$RV/synth-before-restore.out"`' "Step 4: 앞 출력을 옮겨 둔다"
  assert_contains "$S4" '`--restore-lowered <번호들>` 을 더한다' "Step 4: 합성기에 --restore-lowered 를 싣는다"
  assert_contains "$S4" '(예: `--restore-lowered L1,L3`), 전부면 `all` 이다' "Step 4: 번호 꼴과 all"
  assert_contains "$S4" '표에 없는 번호면 rc 2 다(`모르는 낮춘 지적 번호:`)' "Step 4: 모르는 번호는 rc 2 다"
  # final-review M2 — 잘못 친 번호 하나로 리뷰가 끝난 실행 전체가 멈추지 않는다
  assert_not_contains "$S4" '— 위 rc 규칙대로 보고하고 멈춘다.' "Step 4: 모르는 번호의 rc 2 로 실행을 멈추던 옛 문장이 없다"
  assert_contains "$S4" '그래도 rc 2 면 멈추지 않는다: `mv "$RV/synth-before-restore.out" "$RV/synth.out"` 으로 앞 출력을 되돌리고' \
    "Step 4: 다시 합성이 rc 2 면 앞 출력을 되돌린다(옛 문장 부재의 양성 짝)"
  assert_contains "$S4" '`> [quality-gates] 되올리기를 적용하지 못했다(합성기 rc 2 — <stderr 첫 줄>) — 낮춘 대로 둔 앞 판정으로 간다.`' \
    "Step 4: 되돌렸다고 공시한다"
}

case_step45_gate() {
  note "Step 4.5 — 낮춘 지적 게이트"
  assert_contains "$S45" 'You do not choose or edit it (V1).' "전제: Step 4.5 창이 비지 않았다"
  # 걸음 문장은 뜻 낱말로 잰다(문장 전체를 박지 않는다). 질문 · 선택지 설명의 전문은 재지 않는다.
  assert_contains "$S45" '`lowered:` 값 n 이 1 이상이면' "게이트: lowered: 를 읽는다"
  assert_contains "$S45" '범위 모드에서도' "게이트: clean 이어도 · 범위 모드에서도 뜬다"
  assert_not_contains "$S45" '반복마다' "게이트: 반복마다 뜬다는 옛 문구가 없다(한 실행은 한 번 지난다 — 위 양성 짝)"
  assert_contains "$S45" '`lowered: 0` 이면 게이트 없이' "게이트: 0 이면 묻지 않는다"
  assert_contains "$S45" 'header: "낮춘 지적",' "게이트: header"
  # 묶음(셋씩)마다 지적을 여러 개 고른다 — 「전부」는 선택지가 아니라 기타 칸의 글이다.
  assert_contains "$S45" 'multiSelect: true }] })' "게이트: 묶음마다 여러 개를 고를 수 있다"
  assert_not_contains "$S45" 'multiSelect: <n ≤ 3: true · n ≥ 4: false> }] })' "게이트: n 에 따라 선택 방식이 갈리던 옛 꼴이 없다"
  assert_not_contains "$S45" '{label: "전부 되올린다"' "게이트: 「전부 되올린다」 선택지가 없다"
  assert_contains "$S45" '셋씩 묶어' "게이트: 넷 이상이면 셋씩 나눠 묻는다"
  assert_contains "$S45" '한 호출에 넷까지' "게이트: 묶음 질문은 한 호출에 넷까지"
  assert_contains "$S45" '{label: "그대로 둔다", description: "이 묶음의 지적을 낮춘 대로 둔다."}' "게이트: 그대로 둔다"
  assert_contains "$S45" '기타 칸에 「전부」' "게이트: 넷 이상이면 본문에 「전부」 안내"
  assert_contains "$S45" '전문: <$RV/synth.out 의 경로>' "게이트: 질문 본문이 전문 자리를 싣는다"
  assert_contains "$S45" 'question: "재비판이 심각도를 낮춘 지적 <n>개 가운데 <이 묶음의 번호들 — 예: L1 · L2 · L3>.' "게이트: 질문 본문이 이 묶음의 번호를 싣는다"
  assert_not_contains "$S45" '(위 「낮춘 지적」 절)' "게이트: 질문 창 밖의 절을 가리키지 않는다(위 양성 짝)"
  assert_contains "$S45" '다시 합성하지 않고' "게이트: 아무것도 고르지 않으면 다시 합성하지 않고 「그다음」"
  assert_contains "$S45" '`all` 로 되올리고' "게이트: 「전부」는 낮춘 지적 전체다(전부 → all)"
  assert_contains "$S45" '질문 하나로 다시 묻는다' "게이트: 「전부」와 다른 답이 부딪히면 다시 묻는다"
  assert_contains "$S45" '셋이고 추천을 달지 않는다' "게이트: 다시 묻는 질문의 선택지 셋 · 추천 없음"
  assert_not_contains "$S45" '「그대로 둔다」를 함께 골랐어도 고른 지적이 이긴다) → 고른 `L<k>` 들(「전부 되올린다」면' "게이트: 전부 되올린다와 그대로 둔다를 함께 고른 경우를 다루는 옛 문장이 없다"
  assert_not_contains "$S45" '일부만이면 「기타」에 번호(예: L1, L3)' "게이트: n ≥ 4 의 기타 칸 번호 안내(옛 꼴)가 없다"
  assert_contains "$S45" '고른 지적이 이긴다' "게이트: 고른 지적이 「그대로 둔다」를 이긴다(위 옛 문장 부재의 양성 짝)"
  assert_contains "$S45" '「되올려 다시 합성하기」를 돌려' "게이트: 고르면 다시 합성한다"
  assert_contains "$S45" '다시 띄우지 않는다' "게이트: 다시 합성한 출력에 게이트를 또 띄우지 않는다(되풀이 없음)"
  assert_contains "$S45" '한 번만 다시 묻는다 — 두 번째도' "게이트: 기타 칸 재질문은 한 번뿐이다"
  assert_contains "$S45" '펜스로 맞춘다' "게이트: 기타 칸 글을 펜스로 맞춘다(M2)"
  assert_contains "$S45" '`lowered-pick: all` 이면' "게이트: 펜스가 all 을 내면 all 로 되올린다"
  assert_contains "$S45" '한 번만 다시 묻는다(두 번째도' "게이트: 표에 없는 번호의 재질문도 한 번뿐이다"
  assert_contains "$S45" '`> [quality-gates] 표에 없는 번호라 되올리지 않았다(<번호들>) — 낮춘 대로 둔다.`' "게이트: 되올리지 않았다고 알리는 줄이 남는다"
  # 순서 — 표면화(차등 요약) 뒤 · 「그다음」 앞 · 고칠 목록 앞
  local diffsum gate route fix
  diffsum=$(line_of "$S45" '**차등 요약 (판정 줄 옆).**')
  gate=$(line_of "$S45" '**낮춘 지적 게이트 (표면화 뒤 · 고칠 목록 앞).**')
  route=$(line_of "$S45" '그다음: 판정이 무엇이든')
  fix=$(line_of "$S45" '**고칠 목록.**')
  if [ "$diffsum" -gt 0 ] && [ "$gate" -gt "$diffsum" ] && [ "$route" -gt "$gate" ] && [ "$fix" -gt "$route" ]; then
    ok "게이트: 표면화 뒤 · 「그다음」 · 고칠 목록 앞에 있다 ($diffsum < $gate < $route < $fix)"
  else
    no "게이트: 표면화 뒤 · 「그다음」 · 고칠 목록 앞이 아니다 (차등 요약 $diffsum · 게이트 $gate · 그다음 $route · 고칠 목록 $fix)"
  fi
  # 음의 락과 양의 짝 — 게이트는 한 자리뿐이다(Fix-loop 쪽에 겹쳐 생기지 않는다)
  assert_eq "$(grep -cF 'header: "낮춘 지적",' "$SK")" "1" "게이트: SKILL 전체에서 한 자리뿐이다"
}

# 실제 합성기 출력 — 낮춘 것 하나(L1) · 없는 것
make_synth() {
  local d="$ROOT/$1"; mkdir -p "$d"
  printf '%s\n' '- {agent: security-reviewer, file: src/a.py, line: 41, severity: IMPORTANT, summary: 캐시 키를 검증하지 않는다, proposed_fix: 키를 검증한다}' > "$d/findings.yaml"
  rf_prep "$d" >/dev/null
  rf_reply "$d" "$2"
  shift 2
  rf_synth "$d" "$@" > "$d/synth.out" 2>"$d/err"
  echo "$d/synth.out"
}

# SKILL 의 기록 블록(`{ … } >> "$RD/result.md"`)을 뽑아 RD · SYN 을 주고 돌린다.
record_block() {
  awk '/^\{$/{on=1} on{print} on&&/^\} >> "\$RD\/result\.md"$/{exit}' "$SK"
}
run_record() {   # run_record <SYN> <RD>
  local blk; blk="$(record_block)"
  mkdir -p "$2"; printf 'verdict: clean\n판정 줄\n' > "$2/verdict.out"
  RD="$2" SYN="$1" bash -c "$blk" 2>/dev/null
  cat "$2/result.md"
}

case_record_fence() {
  note "Final verdict 기록 — ## 낮춘 지적 복사"
  local syn_low syn_none syn_back out blk
  syn_low=$(make_synth low 'verdicts:
  - {f: f1, verdict: lower, evidence: "의도 출처는 캐시 무효화만 요구한다"}')
  syn_none=$(make_synth none 'verdicts:
  - {f: f1, verdict: confirm}')
  syn_back=$(make_synth back 'verdicts:
  - {f: f1, verdict: lower, evidence: "의도 출처는 캐시 무효화만 요구한다"}' --restore-lowered L1)
  assert_grep "$(cat "$syn_low")" '^lowered: 1$' "이음매: 합성기가 게이트가 읽는 lowered: 줄을 낸다"
  assert_grep "$(cat "$syn_none")" '^lowered: 0$' "이음매: 낮춘 것이 없으면 lowered: 0"
  blk="$(record_block)"
  assert_contains "$blk" "printf '\\n## 지적\\n\\n'" "전제: 기록 블록을 뽑았다"
  assert_contains "$blk" "grep -q '^| 번호 | 위치 | 원래 심각도 |' \"\$SYN\"; then printf '\\n## 낮춘 지적\\n\\n'" "기록: 낮춘 지적 표가 있을 때만 절을 쓴다"

  out=$(run_record "$syn_low" "$ROOT/rd-low")
  assert_contains "$out" '## 낮춘 지적' "기록: 낮춘 지적이 있으면 절이 생긴다"
  assert_contains "$out" '| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 검증하지 않는다 | 의도 출처는 캐시 무효화만 요구한다 |' "기록: 표 행을 그대로 옮긴다"
  local a b c
  a=$(line_of "$out" '## 지적'); b=$(line_of "$out" '## 낮춘 지적'); c=$(line_of "$out" '## 고칠 목록')
  if [ "$a" -gt 0 ] && [ "$b" -gt "$a" ] && [ "$c" -gt "$b" ]; then
    ok "기록: ## 지적 다음 · ## 고칠 목록 앞 ($a < $b < $c)"
  else
    no "기록: 절 순서가 틀렸다 (지적 $a · 낮춘 지적 $b · 고칠 목록 $c)"
  fi
  assert_not_contains "$(printf '%s\n' "$out" | sed -n '/^## 지적$/,/^## 낮춘 지적$/p')" '| L1 |' "기록: ## 지적 절이 낮춘 지적 표를 끌고 오지 않는다"

  out=$(run_record "$syn_back" "$ROOT/rd-back")
  assert_contains "$out" '| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 검증하지 않는다 | (사용자가 되올림) 의도 출처는 캐시 무효화만 요구한다 |' "기록: 되올린 행은 이유 칸 머리에 표시가 남는다"

  out=$(run_record "$syn_none" "$ROOT/rd-none")
  assert_contains "$out" '## 지적' "양의 짝: 낮춘 것이 없어도 기록은 돈다"
  assert_not_contains "$out" '## 낮춘 지적' "기록: 낮춘 것이 없으면 절을 쓰지 않는다"
}

# final-review M2 — 기타 칸 번호 확인 펜스를 실제 합성기 출력(L1 하나)으로 돌린다
case_pick_fence() {
  note "Step 4.5 — 기타 칸 번호 확인 펜스"
  local fence syn out
  fence="$(printf '%s\n' "$S45" | awk '/^```bash$/{f=1;b="";next} f&&/^```$/{if(b ~ /lowered-pick:/) {printf "%s", b; exit}; f=0; next} f{b=b $0 "\n"}')"
  [ -n "$fence" ] && ok "확인 펜스를 뽑았다" || { no "Step 4.5 에 lowered-pick: 펜스가 없다"; return; }
  syn=$(make_synth pick 'verdicts:
  - {f: f1, verdict: lower, evidence: "의도 출처는 캐시 무효화만 요구한다"}')
  pick() {   # pick <번호들>
    printf '%s\n' "$fence" | LC_ALL=C sed -e "s|<Step 3.5 의 절대 경로>|${syn%/synth.out}|" -e "s|<기타 칸에서 읽은 L 번호들 — 쉼표로, 예: L1,L3 · 「전부」와 같은 뜻이면 all>|$1|" > "$ROOT/pick.sh"
    grep -q '^PICK=.<' "$ROOT/pick.sh" && echo "자리표가 채워지지 않았다(펜스의 PICK 자리 글자가 바뀌었다)"
    bash "$ROOT/pick.sh" 2>&1
  }
  out=$(pick L1);    assert_eq "$out" "lowered-pick: ok" "표에 있는 번호(L1)는 통과"
  out=$(pick L1,L7); assert_eq "$out" "lowered-pick: bad L7 (표의 번호: L1)" "표에 없는 번호(L7)를 이름으로 낸다"
  out=$(pick L2);    assert_eq "$out" "lowered-pick: bad L2 (표의 번호: L1)" "표에 없는 번호만이면 bad"
  out=$(pick L11);   assert_eq "$out" "lowered-pick: bad L11 (표의 번호: L1)" "앞자리가 같은 번호(L11)를 L1 로 읽지 않는다"
  out=$(pick 1);     assert_eq "$out" "lowered-pick: bad 1 (표의 번호: L1)" "L 없는 번호(1)는 표의 L1 의 일부로 읽지 않는다(낱말 단위로 맞춘다)"
  # 「전부」 · all — 표의 번호와 맞추지 않고 전체로 넘긴다. 섞은 글은 받지 않는다.
  out=$(pick '전부');    assert_eq "$out" "lowered-pick: all" "펜스: 「전부」를 받는다"
  out=$(pick 'all');     assert_eq "$out" "lowered-pick: all" "펜스: all 을 받는다"
  out=$(pick 'L1,전부'); assert_contains "$out" "lowered-pick: bad" "펜스: 번호와 「전부」를 섞은 글은 받지 않는다"
  out=$(pick 'L1,all');  assert_contains "$out" "lowered-pick: bad" "펜스: 번호와 all 을 섞은 글도 받지 않는다"
  out=$(pick '전부다');  assert_contains "$out" "lowered-pick: bad" "펜스: 「전부」로 시작할 뿐인 글은 전체로 읽지 않는다"
}

case_persona() {
  note "code-recritic — lower 의 evidence 가 사용자에게 보인다"
  local body lower same sent
  body="$(tr '\n' ' ' < "$RC")"
  assert_contains "$body" 'lower 의 `evidence` 는 사용자에게 보고서 「낮춘 지적」 절로 그대로 보이고 사용자가 되올릴지 고른다 — 무엇을 왜 낮췄는지 인용과 함께 처음 보는 사람이 읽을 한 문장으로 쓴다.' "persona: 낮춘 지적 문장"
  lower=$(grep -nF -- '- **lower** —' "$RC" | head -1 | cut -d: -f1)
  sent=$(grep -nF -- '사용자에게 보고서 「낮춘 지적」 절로' "$RC" | head -1 | cut -d: -f1)
  same=$(grep -nF -- '- 같은 결함이 둘 이상이면' "$RC" | head -1 | cut -d: -f1)
  if [ -n "$lower" ] && [ -n "$sent" ] && [ -n "$same" ] && [ "$sent" -gt "$lower" ] && [ "$same" -gt "$sent" ]; then
    ok "persona: 문장이 lower 항목 안에 있다 ($lower < $sent < $same)"
  else
    no "persona: 문장이 lower 항목 안에 없다 (lower ${lower:-0} · 문장 ${sent:-0} · 다음 항목 ${same:-0})"
  fi
}

case_state_format() {
  note "state-file-format — ## 낮춘 지적"
  local fmt a b c
  fmt="$(awk '/^```markdown$/{on=1;next} on&&/^```$/{exit} on{print}' "$SF")"
  a=$(line_of "$fmt" '## 지적'); b=$(line_of "$fmt" '## 낮춘 지적'); c=$(line_of "$fmt" '## 고칠 목록')
  if [ "$a" -gt 0 ] && [ "$b" -gt "$a" ] && [ "$c" -gt "$b" ]; then
    ok "형식: ## 낮춘 지적 이 ## 지적 다음 · ## 고칠 목록 앞 ($a < $b < $c)"
  else
    no "형식: ## 낮춘 지적 자리가 틀렸다 (지적 $a · 낮춘 지적 $b · 고칠 목록 $c)"
  fi
  # 한 번 지나는 실행 — 반복 · 다시 돌기 · 제외 패치 낱말이 없고(부재), 고칠 목록 절이 형식 블록에 한 번 선다(양의 짝).
  local tok n
  for tok in 'iteration' 'Retry' 'excluded.md' 'extra-iterations.md' '제외 패치' '추가 반복'; do
    n=$(grep -cF -- "$tok" "$SF"); assert_eq "$n" "0" "state-file-format 에 '$tok' 이 없다"
  done
  assert_eq "$(printf '%s\n' "$fmt" | grep -cxF '## 고칠 목록')" "1" "형식 블록에 '## 고칠 목록' 이 한 번 선다"
  assert_eq "$(printf '%s\n' "$fmt" | grep -cxF '<Step 4.5 의 고칠 목록 — `### 막는 지적` · `### 제안` · `### 차등 회귀` 세 절, 빈 절은 (없음)>')" "1" \
    "형식 블록의 고칠 목록 자리가 SKILL Step 4.5 의 세 절 이름을 줄 전체로 한 번 싣는다"
  assert_contains "$fmt" '사용자가 되올린 행은 이유 칸 머리에 (사용자가 되올림)' "형식: 되올린 행 표시"
  assert_file_grep "$SF" '`## 낮춘 지적` 은 마지막 합성 출력에 「낮춘 지적」 표가 있을 때만 쓴다\.' "생명주기: 있을 때만 쓴다"
}

case_step4
case_step45_gate
case_record_fence
case_pick_fence
case_persona
case_state_format
finish
