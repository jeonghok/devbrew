#!/usr/bin/env bash
# test_synthesize_findings.sh — 합성기의 결정론 후처리 (V2 · V3 · V8 · AC4 · AC5 · K-4).
#
# 표는 심각도 · 위치 · 내용 · 낸 곳 넷이다. confidence 는 읽지 않는다 — 오탐 거르기는
# 재비판의 관문 A 가 하고, 판정은 살아남은 CRITICAL·IMPORTANT 수(`blocking:`)가 정한다.
set -euo pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SCRIPT="$PLUGIN_ROOT/scripts/synthesize_findings.py"
. "$SCRIPT_DIR/lib/recritic_fixture.sh"
export PYTHONDONTWRITEBYTECODE=1
PASS=0; FAIL=0

# run_case <이름> <재비판 블록> <findings YAML> <있어야 할 ERE> <없어야 할 ERE> [합성기 인자...]
run_case() {
  local name="$1" reply="$2" findings_yaml="$3" expected_grep="$4" expected_neg="$5"; shift 5
  local tmp; tmp="$(mktemp -d)"
  echo "$findings_yaml" > "$tmp/findings.yaml"
  rf_prep "$tmp"
  rf_reply "$tmp" "$reply"
  local out; out=$(rf_synth "$tmp" "$@" 2>/dev/null)
  local out_flat; out_flat=$(echo "$out" | tr '\n' ' ')
  local ok=1
  if [[ -n "$expected_grep" ]] && ! echo "$out_flat" | grep -qE "$expected_grep"; then ok=0; fi
  if [[ -n "$expected_neg" ]] && echo "$out_flat" | grep -qE "$expected_neg"; then ok=0; fi
  if [[ "$ok" -eq 1 ]]; then
    echo "PASS: $name"; PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    echo "    expected_grep='$expected_grep' expected_neg='$expected_neg'"
    echo "    got:"; echo "$out" | sed 's/^/      /'
    FAIL=$((FAIL+1))
  fi
  rm -rf "$tmp"
}

run_case "dedup+merge — 같은 좌표·severity 는 한 행, source 를 합친다" \
  'verdicts: []' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: IMPORTANT, summary: x, proposed_fix: y}
- {agent: silent-failure-hunter, file: a.py, line: 10, severity: IMPORTANT, summary: x, proposed_fix: y}' \
  '\| IMPORTANT \| a\.py:10 \| x \| code-reviewer, silent-failure-hunter \|' ''

run_case "reject — 근거 있는 기각은 표에서 빠진다" \
  'verdicts:
  - {f: f1, verdict: reject, evidence: x}' \
  '- {agent: code-reviewer, file: a.py, line: 10, severity: CRITICAL, summary: bug, proposed_fix: fix}' \
  '리뷰를 합쳤다 — 지적 없음\.' 'a\.py:10'

run_case "표 머리 — confidence 칸이 없다" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, confidence: 2, summary: s, proposed_fix: f}' \
  '\| 심각도 \| 위치 \| 내용 \| 낸 곳 \|' '\| Conf \||\| Sev \||suppressed|[0-9] \* \|'

run_case "confidence 가 낮아도 억제하지 않는다 — 막는 지적은 막는 지적이다" \
  'verdicts: []' \
  '- {agent: r, file: low.py, line: 1, severity: IMPORTANT, confidence: 1, summary: low, proposed_fix: f}' \
  'blocking: 1 .*\| IMPORTANT \| low\.py:1 \|' ''

run_case "K-4 — blocking · optional 줄" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: CRITICAL, summary: c, proposed_fix: f}
- {agent: r, file: b.py, line: 1, severity: IMPORTANT, summary: i, proposed_fix: f}
- {agent: r, file: c.py, line: 1, severity: SUGGESTION, summary: s, proposed_fix: f}' \
  'blocking: 2 optional: 1' ''

run_case "정렬 — CRITICAL · IMPORTANT · SUGGESTION 순" \
  'verdicts: []' \
  '- {agent: r, file: s.py, line: 1, severity: SUGGESTION, summary: s, proposed_fix: f}
- {agent: r, file: c.py, line: 1, severity: CRITICAL, summary: c, proposed_fix: f}
- {agent: r, file: i.py, line: 1, severity: IMPORTANT, summary: i, proposed_fix: f}' \
  'c\.py:1 .* i\.py:1 .* s\.py:1 \|' ''

run_case "AC4 — SUGGESTION 만 남으면 clean" \
  'verdicts:
  - {f: f1, verdict: confirm}' \
  '- {agent: r, file: a.py, line: 1, severity: SUGGESTION, summary: s, proposed_fix: f}' \
  'verdict: clean' 'verdict: defect' --emit-verdict

run_case "AC5 — IMPORTANT 1건이면 defect" \
  'verdicts:
  - {f: f1, verdict: confirm}' \
  '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: s, proposed_fix: f}' \
  'verdict: defect' 'verdict: clean' --emit-verdict

run_case "V8 — severity 결측은 IMPORTANT 로 막는다(낙관값 금지)" \
  'verdicts:
  - {f: f1, verdict: confirm}' \
  '- {agent: r, file: a.py, line: 1, summary: s, proposed_fix: f}' \
  'blocking: 1 .*verdict: defect' 'verdict: clean' --emit-verdict

run_case "V3 — 매핑 아닌 finding 은 버리되 세고 막는다" \
  'verdicts: []' \
  '- "CRITICAL: bare string"' \
  '1개 지적을 버렸다 — 형식이 깨졌다\(dropped as malformed — .*verdict: not-certified .*reason: findings-lost' 'verdict: clean' --emit-verdict

run_case "빈 결과 — 「지적 없음」 첫 줄과 0 개수" \
  'verdicts: []
added: []' \
  '[]' \
  '^리뷰를 합쳤다 — 지적 없음\. ## 리뷰 지적 \(합친 결과\) .*blocking: 0 optional: 0' 'No findings'

# V2 — 읽을 수 없는 입력은 clean 이 아니다(주 입력 사망 → angle-absent)
tmp="$(mktemp -d)"
printf '[]\n' > "$tmp/findings.yaml"; rf_prep "$tmp"
rf_reply "$tmp" 'verdicts: []'
out=$(python3 "$SCRIPT" --findings "$tmp/없는.yaml" --recritic "$tmp/reply.txt" --recritic-map "$tmp/map.json" --emit-verdict 2>/dev/null) || true
if echo "$out" | grep -q '^verdict: not-certified$' && ! echo "$out" | grep -q '^verdict: clean$'; then
  echo "PASS: V2 — 경로가 주어졌는데 못 읽는 findings 는 clean 이 아니다"; PASS=$((PASS+1))
else
  echo "FAIL: V2 — 경로가 주어졌는데 못 읽는 findings 는 clean 이 아니다"; echo "$out" | sed 's/^/      /'; FAIL=$((FAIL+1))
fi
rm -rf "$tmp"

# ── 리뷰 축 인자 줄 (`--verdict-args`) ───────────────────────────────────────
# 판정 펜스는 마지막 줄의 `qg-verdict-args: ` 뒤 글자를 bash 배열 자리에 그대로 붙인다.
VERDICT="$PLUGIN_ROOT/scripts/verdict.py"
check() {  # check <이름> <실제> <기대>
  if [[ "$2" == "$3" ]]; then echo "PASS: $1"; PASS=$((PASS+1))
  else echo "FAIL: $1"; echo "    expected: $3"; echo "    actual:   $2"; FAIL=$((FAIL+1)); fi
}
# va_prep <findings YAML> <재비판 블록> — $VT 에 픽스처를 만든다
va_prep() {
  VT="$(mktemp -d)"; [[ -n "$VT" ]] || { echo "mktemp 실패" >&2; exit 1; }
  printf '%s\n' "$1" > "$VT/findings.yaml"; rf_prep "$VT"; rf_reply "$VT" "$2"
}
IMP1='- {agent: r, file: a.py, line: 1, severity: IMPORTANT, summary: s, proposed_fix: f}'
SUG1='- {agent: r, file: a.py, line: 1, severity: SUGGESTION, summary: s, proposed_fix: f}'
REGRESS_DIFF='adapters: [bash]
verdict_input:
  confirmed_product_defect: true
  silent_drop: true
  baseline_unrunnable: false
attribution_status: degraded
degrade_causes: [silent-drop]
new_failures: 1
unclaimed: []
per_adapter: []'

va_prep "$IMP1" 'verdicts:
  - {f: f1, verdict: confirm}'
rf_synth "$VT" --emit-verdict --verdict-args > "$VT/with.out" 2>/dev/null || true
rf_synth "$VT" --emit-verdict > "$VT/without.out" 2>/dev/null || true
check "--verdict-args — 막는 지적 하나면 마지막 줄이 리뷰 축 인자 줄" \
  "$(tail -n 1 "$VT/with.out")" "qg-verdict-args: --blocking 1 --optional 0 --defect"
check "--verdict-args — 인자 줄은 개행으로 끝난다" "$(tail -c 1 "$VT/with.out" | od -An -c | tr -d ' ')" '\n'
sed '$d' "$VT/with.out" > "$VT/with-minus-last.out"
if cmp -s "$VT/with-minus-last.out" "$VT/without.out" && [[ -s "$VT/without.out" ]]; then
  echo "PASS: --verdict-args 없이 낸 출력은 인자 줄을 뺀 출력과 바이트로 같다"; PASS=$((PASS+1))
else
  echo "FAIL: --verdict-args 없이 낸 출력은 인자 줄을 뺀 출력과 바이트로 같다"
  diff "$VT/with-minus-last.out" "$VT/without.out" | sed 's/^/      /' || true; FAIL=$((FAIL+1))
fi
check "--verdict-args 없이는 인자 줄이 없다" "$(grep -c '^qg-verdict-args:' "$VT/without.out" || true)" "0"
rc=0; out=$(rf_synth "$VT" --verdict-args 2>/dev/null) || rc=$?
check "--verdict-args 만 주면 사용법 오류(rc 2)" "$rc" "2"
check "--verdict-args 사용법 오류면 stdout 이 비어 있다" "$out" ""
rc=0; out=$(rf_synth "$VT" --emit-verdict --verdict-args --reason no-such-reason 2>/dev/null) || rc=$?
check "--verdict-args 와 열거 밖 사유 — exit 4" "$rc" "4"
check "--verdict-args 와 열거 밖 사유 — stdout 이 비어 있다" "$out" ""
out=$(rf_synth "$VT" --emit-verdict --verdict-args --reason kill-switch --reason merge-conflict --reason kill-switch 2>/dev/null) || true
check "--verdict-args — 주어진 사유를 중복 없이 REASONS 순서로" "$(printf '%s\n' "$out" | tail -n 1)" \
  "qg-verdict-args: --blocking 1 --optional 0 --defect --reason kill-switch --reason merge-conflict"
rm -rf "$VT"

va_prep "$SUG1" 'verdicts:
  - {f: f1, verdict: confirm}'
printf '%s\n' "$REGRESS_DIFF" > "$VT/diff.yaml"
out=$(rf_synth "$VT" --emit-verdict --verdict-args --differential "$VT/diff.yaml" 2>/dev/null) || true
check "--differential 을 함께 줘도 인자 줄은 리뷰 축만(새 실패 · 차등 결함 · 차등 사유 없음)" \
  "$(printf '%s\n' "$out" | tail -n 1)" "qg-verdict-args: --blocking 0 --optional 1"
# 리뷰 줄 + 차등 줄을 verdict.py 에 붙이면 합성기가 낸 판정과 같다 — 판정 펜스가 쓸 길이다.
r_line="$(printf '%s\n' "$out" | tail -n 1)"
d_line="$(python3 "$VERDICT" --emit-args --differential "$VT/diff.yaml")" || true
read -r -a R_ARGS <<< "${r_line#qg-verdict-args: }"
read -r -a D_ARGS <<< "${d_line#qg-verdict-args: }"
joined="$(python3 "$VERDICT" ${R_ARGS[@]+"${R_ARGS[@]}"} ${D_ARGS[@]+"${D_ARGS[@]}"} \
  --line --excluded 0 --iter 1 --sha abc1234)" || true
check "리뷰 줄 + 차등 줄로 다시 낸 판정이 합성기의 판정과 같다" \
  "$(printf '%s\n' "$joined" | grep -E '^(verdict|reason|reasons): ' || true)" \
  "$(printf '%s\n' "$out" | grep -E '^(verdict|reason|reasons): ' || true)"
check "그 판정 줄이 리뷰 축 수와 차등 새 실패를 싣는다" "$(printf '%s\n' "$joined" | tail -n 1)" \
  "qg: defect · 막는 지적 0 · 선택 1 · 차등 새 실패 1 · 제외 패치 0 · iter 1 · abc1234"
rm -rf "$VT"

va_prep '- "CRITICAL: bare string"' 'verdicts: []'
out=$(rf_synth "$VT" --emit-verdict --verdict-args 2>/dev/null) || true
check "--verdict-args — 버린 지적이 있으면 --review-blocked" \
  "$(printf '%s\n' "$out" | tail -n 1)" "qg-verdict-args: --blocking 0 --optional 0 --review-blocked"
rm -rf "$VT"

va_prep '[]' 'verdicts: []'
out=$(python3 "$SCRIPT" --findings "$VT/없는.yaml" --recritic "$VT/reply.txt" --recritic-map "$VT/map.json" \
  --emit-verdict --verdict-args 2>/dev/null) || true
check "--verdict-args — 주 입력을 못 읽으면 --angle-absent 를 싣는다" \
  "$(printf '%s\n' "$out" | tail -n 1 | grep -c -- ' --angle-absent' || true)" "1"
rm -rf "$VT"

# test_verdict_args_after_restore — 「낮춘 지적」 게이트에서 되올려 다시 합성하면 인자 줄의
# --blocking 이 되올린 수를 반영한다(최종 판정은 되올린 뒤의 막는 지적 수를 쓴다).
va_prep "$IMP1" 'verdicts:
  - {f: f1, verdict: lower, evidence: "의도 출처는 이것을 요구하지 않는다"}'
before=$(rf_synth "$VT" --emit-verdict --verdict-args 2>/dev/null | tail -n 1) || true
after=$(rf_synth "$VT" --emit-verdict --verdict-args --restore-lowered L1 2>/dev/null | tail -n 1) || true
check "test_verdict_args_after_restore — 낮춘 뒤에는 막는 지적 0" "$before" "qg-verdict-args: --blocking 0 --optional 1"
check "test_verdict_args_after_restore — 되올리면 --blocking 이 되올린 수를 반영한다" \
  "$after" "qg-verdict-args: --blocking 1 --optional 0 --defect"
rm -rf "$VT"

echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
