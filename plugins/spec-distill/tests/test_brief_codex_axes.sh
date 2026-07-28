#!/usr/bin/env bash
# Spec B T11·T16 — codex 축 분리 + 모듈 경계.
# AC6(축별 2회, 한 축만) · AC20(runner 1 · 빌더 1 · 체크리스트 데이터 2 · spec 빌더 미참조)
# Run: bash plugins/spec-distill/tests/test_brief_codex_axes.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
BUILDER="$SD/scripts/build_brief_codex_prompt.py"
RUNNER="$SD/scripts/run_brief_codex_reviewer.sh"
CL_DIR="$SD/scripts/brief-codex-direction-checklist.md"
CL_FID="$SD/scripts/brief-codex-fidelity-checklist.md"
FX="$SD/tests/fixtures"
PAYLOAD="$FX/brief-verbatim-ok.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

for f in "$BUILDER" "$RUNNER" "$CL_DIR" "$CL_FID"; do
  test -f "$f" && note PASS "존재: $(basename "$f")" || note FAIL "부재: $f"
done
test -f "$BUILDER" || { echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1; }

# --- 마커가 body-unique 한 줄로 존재해야 T11이 성립한다 ---------------------
MK_DIR='AXIS-MARKER: brief-direction-axis-only'
MK_FID='AXIS-MARKER: brief-fidelity-axis-only'
[[ "$(grep -cF "$MK_DIR" "$CL_DIR")" == "1" ]] && note PASS "direction 체크리스트에 마커 1회" \
  || note FAIL "direction 마커가 없거나 중복"
[[ "$(grep -cF "$MK_FID" "$CL_FID")" == "1" ]] && note PASS "fidelity 체크리스트에 마커 1회" \
  || note FAIL "fidelity 마커가 없거나 중복"
grep -qF "$MK_FID" "$CL_DIR" && note FAIL "direction 파일에 타 축 마커 오염" || note PASS "direction 파일에 타 축 마커 없음"
grep -qF "$MK_DIR" "$CL_FID" && note FAIL "fidelity 파일에 타 축 마커 오염" || note PASS "fidelity 파일에 타 축 마커 없음"

# --- T11 / AC6 : 축별 출력이 자기 마커만 담는다 (대칭) ----------------------
out_dir="$(python3 "$BUILDER" --axis direction "$PAYLOAD" 2>/dev/null)" || out_dir=""
out_fid="$(python3 "$BUILDER" --axis fidelity "$PAYLOAD" 2>/dev/null)" || out_fid=""
grep -qF "$MK_DIR" <<<"$out_dir" && note PASS "T11: --axis direction 출력이 direction 마커 포함" \
  || note FAIL "T11: direction 출력에 자기 마커 없음"
grep -qF "$MK_FID" <<<"$out_dir" && note FAIL "T11: direction 출력에 fidelity 마커 누출" \
  || note PASS "T11: direction 출력에 타 축 마커 미포함"
grep -qF "$MK_FID" <<<"$out_fid" && note PASS "T11: --axis fidelity 출력이 fidelity 마커 포함" \
  || note FAIL "T11: fidelity 출력에 자기 마커 없음"
grep -qF "$MK_DIR" <<<"$out_fid" && note FAIL "T11: fidelity 출력에 direction 마커 누출" \
  || note PASS "T11: fidelity 출력에 타 축 마커 미포함"

# payload 본문이 실제로 실렸는가 (빈 프롬프트를 통과시키지 않는다)
grep -qF "브리프에 리뷰를 붙이고 싶다" <<<"$out_dir" && note PASS "T11: payload 본문이 프롬프트에 실림" \
  || note FAIL "T11: payload 본문이 프롬프트에 없다"

# 축 인자 검증 (열거 밖은 거부)
python3 "$BUILDER" --axis both "$PAYLOAD" >/dev/null 2>&1 \
  && note FAIL "닫힌 열거 밖 --axis 가 통과" || note PASS "닫힌 열거 밖 --axis 거부"
python3 "$BUILDER" "$PAYLOAD" >/dev/null 2>&1 \
  && note FAIL "--axis 없이 통과" || note PASS "--axis 필수"

# severity 어휘가 merge 경로와 일치해야 한다 (vocab drift가 병합을 깬다)
for sev in block high medium; do
  grep -qF "$sev" <<<"$out_fid" && note PASS "fidelity 프롬프트에 severity '$sev'" \
    || note FAIL "fidelity 프롬프트에 severity '$sev' 없음 (merge vocab drift)"
done

# --- T16 / AC20 : 모듈 경계 ------------------------------------------------
n_runner="$(find "$SD/scripts" -maxdepth 1 -name 'run_brief_codex*' | wc -l | tr -d ' ')"
[[ "$n_runner" == "1" ]] && note PASS "T16: brief codex runner 1개" || note FAIL "T16: runner가 $n_runner 개"
n_builder="$(find "$SD/scripts" -maxdepth 1 -name 'build_brief_codex_prompt*' | wc -l | tr -d ' ')"
[[ "$n_builder" == "1" ]] && note PASS "T16: 빌더 1개" || note FAIL "T16: 빌더가 $n_builder 개"
n_cl="$(find "$SD/scripts" -maxdepth 1 -name 'brief-codex-*-checklist.md' | wc -l | tr -d ' ')"
[[ "$n_cl" == "2" ]] && note PASS "T16: 체크리스트 데이터 2개" || note FAIL "T16: 체크리스트가 $n_cl 개"
test -d "$SD/prompts" && note FAIL "T16: prompts/ 디렉토리 존재 (canonical 트리 위반)" \
  || note PASS "T16: prompts/ 디렉토리 부재"

# 신규 파일 어디에도 spec 빌더 참조가 없다 (AC 주입 오염원)
hits=0
for f in "$BUILDER" "$RUNNER" "$CL_DIR" "$CL_FID"; do
  grep -q "build_spec_codex_prompt" "$f" && hits=$((hits+1))
done
[[ "$hits" == "0" ]] && note PASS "T16: build_spec_codex_prompt 미참조" || note FAIL "T16: spec 빌더를 $hits 곳에서 참조"

# runner의 CLAUDE_PLUGIN_ROOT fallback (§11 ⑪ — 기존 스크립트 결함 미반복)
grep -q 'CLAUDE_PLUGIN_ROOT:-' "$RUNNER" \
  && note PASS "T16: runner에 CLAUDE_PLUGIN_ROOT fallback" || note FAIL "T16: fallback 없음 (set -u에서 즉사)"
grep -qE '^set -euo pipefail' "$RUNNER" \
  && note PASS "T16: runner set -euo pipefail" || note FAIL "T16: runner에 set -euo pipefail 없음"

# B1: 추론 강도를 하니스가 핀하지 않는다 — 사용자 codex 설정이 지배한다.
# `-c model_reasoning_effort=...`를 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고,
# 그 하향은 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
# 주석의 언급(핀하지 *않는다*는 설명)과 실제 인자를 구분해야 하므로 **실행 인자 라인**만 본다:
# `-c ...` 로 시작하는(선행 공백 허용) 줄 — 주석은 `#`로 시작해 이 앵커에 걸리지 않는다.
grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUNNER" \
  && note FAIL "B1: runner가 model_reasoning_effort를 인자로 핀 — 사용자 설정을 하향 억제한다" \
  || note PASS "B1: runner가 추론 강도를 핀하지 않는다 (사용자 codex 설정이 지배)"

# env 없이도 죽지 않고 항상 YAML을 쓴다 (codex 부재 환경에서 확인)
tmpout="$(mktemp)" || exit 1
( unset CLAUDE_PLUGIN_ROOT; PATH=/usr/bin:/bin bash "$RUNNER" fidelity "$PAYLOAD" "$REPO_ROOT" "$tmpout" >/dev/null 2>&1 )
rc=$?
[[ "$rc" == "0" ]] && note PASS "T16: codex 부재/env 부재에도 exit 0" || note FAIL "T16: runner가 exit $rc"
grep -q '^findings:' "$tmpout" && note PASS "T16: 항상 YAML을 쓴다" || note FAIL "T16: YAML 미작성 (병합이 파일 부재를 본다)"
rm -f "$tmpout"

# 잘못된 축은 runner도 거부한다
tmpout2="$(mktemp)" || exit 1
bash "$RUNNER" both "$PAYLOAD" "$REPO_ROOT" "$tmpout2" >/dev/null 2>&1 \
  && note FAIL "runner가 닫힌 열거 밖 축을 통과" || note PASS "runner가 닫힌 열거 밖 축 거부"
rm -f "$tmpout2"

# E10: 신규 데이터/코드에 단일 호출 상한 표현이 없다
for f in "$CL_DIR" "$CL_FID" "$BUILDER"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$f"; then
    note FAIL "E10: $(basename "$f")에 단일 호출 상한 표현"
  else
    note PASS "E10: $(basename "$f")에 상한 표현 없음"
  fi
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ "$fail" -eq 0 ]]
