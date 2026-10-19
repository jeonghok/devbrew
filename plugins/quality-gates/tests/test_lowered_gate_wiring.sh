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
  assert_contains "$S4" '표에 없는 번호면 rc 2 다(`모르는 낮춘 지적 번호:`)' "Step 4: 모르는 번호는 rc 2 로 멈춘다"
}

case_step45_gate() {
  note "Step 4.5 — 낮춘 지적 게이트"
  assert_contains "$S45" 'You do not choose or edit it (V1).' "전제: Step 4.5 창이 비지 않았다"
  assert_contains "$S45" '`$RV/synth.out` 의 `lowered:` 값 n 이 1 이상이면' "게이트: lowered: 를 읽는다"
  assert_contains "$S45" '반복마다, 판정이 clean 이어도, 범위 모드에서도' "게이트: 반복마다 · clean 이어도 · 범위 모드에서도"
  assert_contains "$S45" '`lowered: 0` 이면 게이트 없이 라우팅으로 간다' "게이트: 0 이면 묻지 않는다"
  assert_contains "$S45" 'header: "낮춘 지적",' "게이트: header"
  assert_contains "$S45" 'multiSelect: true }] })' "게이트: 여러 개를 고른다"
  assert_contains "$S45" 'n ≤ 3: 지적마다 {label: "<파일 이름>:<줄> (L<k>)"' "게이트: 3개 이하면 지적마다 선택지"
  assert_contains "$S45" 'n ≥ 4: {label: "전부 되올린다"' "게이트: 4개 이상이면 전부 되올린다"
  assert_contains "$S45" '{label: "그대로 둔다", description: "낮춘 대로 둔다."}' "게이트: 그대로 둔다"
  assert_contains "$S45" '일부만이면 「기타」에 번호(예: L1, L3)' "게이트: 일부는 기타 칸 번호"
  assert_contains "$S45" 'Step 4 의 「되올려 다시 합성하기」를 돌려 `$RV/synth.out` 을 덮는다' "게이트: 고르면 다시 합성한다"
  assert_contains "$S45" '새 출력에는 이 게이트를 다시 띄우지 않는다' "게이트: 다시 합성한 출력에 게이트를 또 띄우지 않는다(되풀이 없음)"
  assert_contains "$S45" '한 번만 다시 묻는다 — 두 번째도 없으면 그대로 둔다' "게이트: 기타 칸 재질문은 한 번뿐이다"
  # 순서 — 표면화(차등 요약) 뒤 · 라우팅 앞
  local diffsum gate route
  diffsum=$(line_of "$S45" '**차등 요약 (판정 줄 옆).**')
  gate=$(line_of "$S45" '**낮춘 지적 게이트 (표면화 뒤 · 라우팅 앞).**')
  route=$(line_of "$S45" '그다음(N < CAP')
  if [ "$diffsum" -gt 0 ] && [ "$gate" -gt "$diffsum" ] && [ "$route" -gt "$gate" ]; then
    ok "게이트: 표면화 뒤 · 라우팅 앞에 있다 ($diffsum < $gate < $route)"
  else
    no "게이트: 표면화 뒤 · 라우팅 앞이 아니다 (차등 요약 $diffsum · 게이트 $gate · 라우팅 $route)"
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
  a=$(line_of "$out" '## 지적'); b=$(line_of "$out" '## 낮춘 지적'); c=$(line_of "$out" '## 제외 패치')
  if [ "$a" -gt 0 ] && [ "$b" -gt "$a" ] && [ "$c" -gt "$b" ]; then
    ok "기록: ## 지적 다음 · ## 제외 패치 앞 ($a < $b < $c)"
  else
    no "기록: 절 순서가 틀렸다 (지적 $a · 낮춘 지적 $b · 제외 패치 $c)"
  fi
  assert_not_contains "$(printf '%s\n' "$out" | sed -n '/^## 지적$/,/^## 낮춘 지적$/p')" '| L1 |' "기록: ## 지적 절이 낮춘 지적 표를 끌고 오지 않는다"

  out=$(run_record "$syn_back" "$ROOT/rd-back")
  assert_contains "$out" '| L1 | src/a.py:41 | IMPORTANT | 캐시 키를 검증하지 않는다 | (사용자가 되올림) 의도 출처는 캐시 무효화만 요구한다 |' "기록: 되올린 행은 이유 칸 머리에 표시가 남는다"

  out=$(run_record "$syn_none" "$ROOT/rd-none")
  assert_contains "$out" '## 지적' "양의 짝: 낮춘 것이 없어도 기록은 돈다"
  assert_not_contains "$out" '## 낮춘 지적' "기록: 낮춘 것이 없으면 절을 쓰지 않는다"
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
  a=$(line_of "$fmt" '## 지적'); b=$(line_of "$fmt" '## 낮춘 지적'); c=$(line_of "$fmt" '## 제외 패치')
  if [ "$a" -gt 0 ] && [ "$b" -gt "$a" ] && [ "$c" -gt "$b" ]; then
    ok "형식: ## 낮춘 지적 이 ## 지적 다음 · ## 제외 패치 앞 ($a < $b < $c)"
  else
    no "형식: ## 낮춘 지적 자리가 틀렸다 (지적 $a · 낮춘 지적 $b · 제외 패치 $c)"
  fi
  assert_contains "$fmt" '사용자가 되올린 행은 이유 칸 머리에 (사용자가 되올림)' "형식: 되올린 행 표시"
  assert_file_grep "$SF" '`## 낮춘 지적` 은 마지막 합성 출력에 「낮춘 지적」 표가 있을 때만 쓴다\.' "생명주기: 있을 때만 쓴다"
}

case_step4
case_step45_gate
case_record_fence
case_persona
case_state_format
finish
