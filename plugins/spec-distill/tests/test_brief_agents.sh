#!/usr/bin/env bash
# Spec B T7 (+ T21의 Bash 부재 절) — 신규 3 에이전트 도구·모델 표면 락.
# AC4(쓰기·실행·위임 도구 0) · AC5(model: inherit) · AC2b(probe 판정과 tools: 정합)
# Run: bash plugins/spec-distill/tests/test_brief_agents.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
AUDIT="$REPO_ROOT/docs/audits/2026-07-27-spec-distill-zero-tool-probe.md"
ISOLATED=("brief-critic" "brief-readback")
ALL=("brief-critic" "brief-readback" "brief-direction-reviewer")

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }
fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

# probe 판정을 읽는다 — 없으면 fail-closed (구현 진행 금지 신호)
test -f "$AUDIT" || { note FAIL "probe 감사 문서 부재: $AUDIT (AC2b — probe 미실행)"; \
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1; }
VERDICT="$(grep -m1 '^\*\*분기 판정:\*\*' "$AUDIT" | sed 's/^\*\*분기 판정:\*\*[[:space:]]*//' | tr -d '[:space:]')"
case "$VERDICT" in
  ZERO_TOOL_OK|ZERO_TOOL_UNAVAILABLE) note PASS "probe 판정 인식: $VERDICT" ;;
  *) note FAIL "probe 판정을 읽을 수 없다 (값: '$VERDICT')"; \
     echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1 ;;
esac

for a in "${ALL[@]}"; do
  f="$SD/agents/$a.md"
  test -f "$f" || { note FAIL "에이전트 파일 부재: $a.md"; continue; }
  FM="$(fm_of "$f")"

  # AC5 — model: inherit (리터럴 핀 금지, E10 선제 적용)
  grep -qE '^model: inherit$' <<<"$FM" \
    && note PASS "$a: model: inherit" || note FAIL "$a: model이 inherit이 아님 (E10 위반)"

  # AC4 — 쓰기·실행·위임 물리적 부재
  # tools: 값을 정규화(대괄호 제거 → comma split → trim)한 뒤 토큰 단위 정확 일치로 비교한다.
  # 이전의 raw-line grep(`^tools:.*(:|,)?[[:space:]]*${t}([[:space:],]|$)`)은 YAML
  # flow-sequence 형태(`tools: [Read, Write]`)에서 토큰 뒤에 `]`가 오면 경계 문자로 인식하지
  # 못해 탐지를 피해가는 gap이 있었다(review round 1 적발, `tools: [Read, Write]`가
  # false PASS). 정규화 + exact-element 비교는 대괄호 유무·토큰 위치(첫/중간/끝)·공백과
  # 무관하게 동작하고, `WriteFile` 같은 상위 문자열에 `Write`가 우연히 포함되는 substring
  # collision도 배제한다(줄 단위 완전 일치이므로).
  tools_line="$(grep -E '^tools:' <<<"$FM" | head -1)"
  tools_val="${tools_line#tools:}"
  tools_val="${tools_val//[/}"
  tools_val="${tools_val//]/}"
  tools_norm="$(tr ',' '\n' <<<"$tools_val" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$')"
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor Task; do
    if grep -qxF "$t" <<<"$tools_norm"; then
      note FAIL "$a: tools:에 $t 가 있다 (Law 2 위반)"
    else
      note PASS "$a: tools:에 $t 없음"
    fi
  done
  grep -qE '^tools:.*mcp__' <<<"$FM" && note FAIL "$a: tools:에 MCP grant" || note PASS "$a: MCP 없음"

  # 죽은 필드 금지 (allowedTools는 비공식 — 조용히 무시된다)
  grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
    && note FAIL "$a: allowedTools/denylist 잔존" || note PASS "$a: allowedTools·disallowedTools 없음"

  # bare `tools:` 금지 — YAML null = "키 미지정"으로 읽혀 조용한 fail-open이 된다
  grep -qE '^tools:[[:space:]]*$' <<<"$FM" \
    && note FAIL "$a: bare 'tools:' (YAML null → 전체 허용 fail-open 위험)" \
    || note PASS "$a: bare 'tools:' 아님"

  grep -qE '^cost_class: (low|medium|high|variable)$' <<<"$FM" \
    && note PASS "$a: cost_class 선언" || note FAIL "$a: cost_class 없음"
done

# probe 판정에 따른 격리 에이전트의 tools: 정합
for a in "${ISOLATED[@]}"; do
  FM="$(fm_of "$SD/agents/$a.md")"
  if [[ "$VERDICT" == "ZERO_TOOL_OK" ]]; then
    grep -qE '^tools: \[\]$' <<<"$FM" \
      && note PASS "$a: tools: [] (probe 통과 분기)" || note FAIL "$a: probe 통과인데 tools: [] 가 아님"
  else
    grep -qE '^tools: Read$' <<<"$FM" \
      && note PASS "$a: tools: Read (probe 실패 분기 — inert)" || note FAIL "$a: probe 실패인데 tools: Read 가 아님"
  fi
done

# 방향성 리뷰어는 분기 무관 — 웹·repo 도구 둘 다, Bash는 없다 (T21)
FM="$(fm_of "$SD/agents/brief-direction-reviewer.md")"
grep -qE '^tools: Read, Grep, Glob, WebSearch, WebFetch$' <<<"$FM" \
  && note PASS "direction-reviewer: tools 정확 일치" || note FAIL "direction-reviewer: tools 표면이 다름"
for t in WebSearch WebFetch; do
  grep -qE "^tools:.*${t}" <<<"$FM" && note PASS "direction-reviewer: $t 보유 (E10 — 둘 다)" \
    || note FAIL "direction-reviewer: $t 없음 (외부 근거 축 축소)"
done

# 역할 프롬프트가 X / NOT Z를 명시한다 (CLAUDE.md 컴포넌트 격리 규약)
grep -q "NOT" "$SD/agents/brief-critic.md" && note PASS "brief-critic: NOT 책임 명시" || note FAIL "brief-critic: NOT 절 없음"
grep -q "NOT" "$SD/agents/brief-readback.md" && note PASS "brief-readback: NOT 책임 명시" || note FAIL "brief-readback: NOT 절 없음"

# AC3 — readback 프롬프트에 출력 스키마 어휘와 '금지 문구'가 둘 다 없다
RB="$SD/agents/brief-readback.md"
for tok in "category" "severity" "sentinel" "JSON"; do
  grep -qF "$tok" "$RB" && note FAIL "AC3: readback에 스키마 어휘 '$tok'" || note PASS "AC3: readback에 '$tok' 없음"
done
for tok in "audit" "readback 기준" "red-flag"; do
  grep -qiF "$tok" "$RB" && note FAIL "AC3: readback에 '$tok' 언급 (존재 누설)" || note PASS "AC3: readback에 '$tok' 없음"
done
for tok in "G1" "gap 클래스" "미결을 확정으로"; do
  grep -qF "$tok" "$RB" && note FAIL "AC25: readback에 gap 클래스 어휘 '$tok'" || note PASS "AC25: readback에 '$tok' 없음"
done

# critic 프롬프트는 category 6종 전부를 명시한다 (spec §5.3 최소 필수)
CR="$SD/agents/brief-critic.md"
for cat in distortion omission insertion provenance_mislabel authority_syntax evidence_unsupported; do
  grep -qF "$cat" "$CR" && note PASS "critic: category '$cat' 명시" || note FAIL "critic: category '$cat' 누락"
done
# critic 프롬프트에 payload 경로/디렉토리가 실리지 않는다 (AC2의 정적 절)
grep -qF "docs/superpowers/interview/" "$CR" \
  && note FAIL "AC2: critic 프롬프트에 interview 디렉토리 문자열" || note PASS "AC2: critic에 interview 디렉토리 없음"
grep -qF "docs/superpowers/interview/" "$RB" \
  && note FAIL "AC3: readback 프롬프트에 interview 디렉토리 문자열" || note PASS "AC3: readback에 interview 디렉토리 없음"

# E10 — 신규 에이전트에 단일 호출 상한 표현 없음 (T28의 agent 절)
for a in "${ALL[@]}"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$SD/agents/$a.md"; then
    note FAIL "E10: ${a}에 단일 호출 상한 표현"
  else
    note PASS "E10: ${a}에 상한 표현 없음"
  fi
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
