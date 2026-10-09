#!/usr/bin/env bash
# test_synthesize_findings.sh — 합성기의 결정론 후처리 (V2 · V3 · V8 · AC4 · AC5 · K-4).
#
# 표는 Sev · Path:Line · Summary · Source 넷이다. confidence 는 읽지 않는다 — 오탐 거르기는
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
  'No findings\.' 'a\.py:10'

run_case "표 머리 — confidence 칸이 없다" \
  'verdicts: []' \
  '- {agent: r, file: a.py, line: 1, severity: IMPORTANT, confidence: 2, summary: s, proposed_fix: f}' \
  '\| Sev \| Path:Line \| Summary \| Source \|' '\| Conf \||suppressed|[0-9] \* \|'

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
  '1 finding\(s\) dropped as malformed .*verdict: not-certified .*reason: findings-lost' 'verdict: clean' --emit-verdict

run_case "빈 결과 — No findings 와 0 개수" \
  'verdicts: []
added: []' \
  '[]' \
  'No findings\. blocking: 0 optional: 0' ''

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

echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
