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

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

for f in "$BUILDER" "$RUNNER" "$CL_DIR" "$CL_FID"; do
  test -f "$f" && ok "존재: $(basename "$f")" || no "부재: $f"
done
test -f "$BUILDER" || { echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; exit 1; }

# --- 마커가 body-unique 한 줄로 존재해야 T11이 성립한다 ---------------------
MK_DIR='AXIS-MARKER: brief-direction-axis-only'
MK_FID='AXIS-MARKER: brief-fidelity-axis-only'
[[ "$(grep -cF "$MK_DIR" "$CL_DIR")" == "1" ]] && ok "direction 체크리스트에 마커 1회" \
  || no "direction 마커가 없거나 중복"
[[ "$(grep -cF "$MK_FID" "$CL_FID")" == "1" ]] && ok "fidelity 체크리스트에 마커 1회" \
  || no "fidelity 마커가 없거나 중복"
grep -qF "$MK_FID" "$CL_DIR" && no "direction 파일에 타 축 마커 오염" || ok "direction 파일에 타 축 마커 없음"
grep -qF "$MK_DIR" "$CL_FID" && no "fidelity 파일에 타 축 마커 오염" || ok "fidelity 파일에 타 축 마커 없음"

# --- T11 / AC6 : 축별 출력이 자기 마커만 담는다 (대칭) ----------------------
out_dir="$(python3 "$BUILDER" --axis direction "$PAYLOAD" 2>/dev/null)" || out_dir=""
out_fid="$(python3 "$BUILDER" --axis fidelity "$PAYLOAD" 2>/dev/null)" || out_fid=""
grep -qF "$MK_DIR" <<<"$out_dir" && ok "T11: --axis direction 출력이 direction 마커 포함" \
  || no "T11: direction 출력에 자기 마커 없음"
grep -qF "$MK_FID" <<<"$out_dir" && no "T11: direction 출력에 fidelity 마커 누출" \
  || ok "T11: direction 출력에 타 축 마커 미포함"
grep -qF "$MK_FID" <<<"$out_fid" && ok "T11: --axis fidelity 출력이 fidelity 마커 포함" \
  || no "T11: fidelity 출력에 자기 마커 없음"
grep -qF "$MK_DIR" <<<"$out_fid" && no "T11: fidelity 출력에 direction 마커 누출" \
  || ok "T11: fidelity 출력에 타 축 마커 미포함"

# payload 본문이 실제로 실렸는가 (빈 프롬프트를 통과시키지 않는다)
grep -qF "브리프에 리뷰를 붙이고 싶다" <<<"$out_dir" && ok "T11: payload 본문이 프롬프트에 실림" \
  || no "T11: payload 본문이 프롬프트에 없다"

# 축 인자 검증 (열거 밖은 거부)
python3 "$BUILDER" --axis both "$PAYLOAD" >/dev/null 2>&1 \
  && no "닫힌 열거 밖 --axis 가 통과" || ok "닫힌 열거 밖 --axis 거부"
python3 "$BUILDER" "$PAYLOAD" >/dev/null 2>&1 \
  && no "--axis 없이 통과" || ok "--axis 필수"

# severity 어휘가 merge 경로와 일치해야 한다 (vocab drift가 병합을 깬다)
for sev in block high medium; do
  grep -qF "$sev" <<<"$out_fid" && ok "fidelity 프롬프트에 severity '$sev'" \
    || no "fidelity 프롬프트에 severity '$sev' 없음 (merge vocab drift)"
done

# --- T16 / AC20 : 모듈 경계 ------------------------------------------------
n_runner="$(find "$SD/scripts" -maxdepth 1 -name 'run_brief_codex*' | wc -l | tr -d ' ')"
[[ "$n_runner" == "1" ]] && ok "T16: brief codex runner 1개" || no "T16: runner가 $n_runner 개"
n_builder="$(find "$SD/scripts" -maxdepth 1 -name 'build_brief_codex_prompt*' | wc -l | tr -d ' ')"
[[ "$n_builder" == "1" ]] && ok "T16: 빌더 1개" || no "T16: 빌더가 $n_builder 개"
n_cl="$(find "$SD/scripts" -maxdepth 1 -name 'brief-codex-*-checklist.md' | wc -l | tr -d ' ')"
[[ "$n_cl" == "2" ]] && ok "T16: 체크리스트 데이터 2개" || no "T16: 체크리스트가 $n_cl 개"
test -d "$SD/prompts" && no "T16: prompts/ 디렉토리 존재 (canonical 트리 위반)" \
  || ok "T16: prompts/ 디렉토리 부재"

# 신규 파일 어디에도 spec 빌더 참조가 없다 (AC 주입 오염원)
hits=0
for f in "$BUILDER" "$RUNNER" "$CL_DIR" "$CL_FID"; do
  grep -q "build_spec_codex_prompt" "$f" && hits=$((hits+1))
done
[[ "$hits" == "0" ]] && ok "T16: build_spec_codex_prompt 미참조" || no "T16: spec 빌더를 $hits 곳에서 참조"

# runner의 CLAUDE_PLUGIN_ROOT fallback (§11 ⑪ — 기존 스크립트 결함 미반복)
grep -q 'CLAUDE_PLUGIN_ROOT:-' "$RUNNER" \
  && ok "T16: runner에 CLAUDE_PLUGIN_ROOT fallback" || no "T16: fallback 없음 (set -u에서 즉사)"
grep -qE '^set -euo pipefail' "$RUNNER" \
  && ok "T16: runner set -euo pipefail" || no "T16: runner에 set -euo pipefail 없음"

# B1: 추론 강도를 하니스가 핀하지 않는다 — 사용자 codex 설정이 지배한다.
# `-c model_reasoning_effort=...`를 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고,
# 그 하향은 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다.
# 주석의 언급(핀하지 *않는다*는 설명)과 실제 인자를 구분해야 하므로 **실행 인자 라인**만 본다:
# `-c ...` 로 시작하는(선행 공백 허용) 줄 — 주석은 `#`로 시작해 이 앵커에 걸리지 않는다.
grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUNNER" \
  && no "B1: runner가 model_reasoning_effort를 인자로 핀 — 사용자 설정을 하향 억제한다" \
  || ok "B1: runner가 추론 강도를 핀하지 않는다 (사용자 codex 설정이 지배)"

# env 없이도 죽지 않고 항상 YAML을 쓴다 (codex 부재 환경에서 확인)
tmpout="$(mktemp)" || exit 1
( unset CLAUDE_PLUGIN_ROOT; PATH=/usr/bin:/bin bash "$RUNNER" fidelity "$PAYLOAD" "$REPO_ROOT" "$tmpout" >/dev/null 2>&1 )
rc=$?
[[ "$rc" == "0" ]] && ok "T16: codex 부재/env 부재에도 exit 0" || no "T16: runner가 exit $rc"
grep -q '^findings:' "$tmpout" && ok "T16: 항상 YAML을 쓴다" || no "T16: YAML 미작성 (병합이 파일 부재를 본다)"
rm -f "$tmpout"

# 잘못된 축은 runner도 거부한다
tmpout2="$(mktemp)" || exit 1
bash "$RUNNER" both "$PAYLOAD" "$REPO_ROOT" "$tmpout2" >/dev/null 2>&1 \
  && no "runner가 닫힌 열거 밖 축을 통과" || ok "runner가 닫힌 열거 밖 축 거부"
rm -f "$tmpout2"

# E10: 신규 데이터/코드에 단일 호출 상한 표현이 없다
for f in "$CL_DIR" "$CL_FID" "$BUILDER"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$f"; then
    no "E10: $(basename "$f")에 단일 호출 상한 표현"
  else
    ok "E10: $(basename "$f")에 상한 표현 없음"
  fi
done

# === /qg iter-1 IMPORTANT : stale YAML이 이번 라운드 판정으로 읽히지 않는다 ====
# 결함: OUTPUT_PATH를 선-truncate하지 않아 조기 exit(잘못된 axis·인자 부족)·SIGKILL·
# 쓰기 실패 시 **직전 라운드의 YAML이 그대로 남았다**. 호출 SKILL은 러너의 exit code를
# 잡지 않으므로, merge는 남아 있던 clean YAML을 이번 라운드의 codex 판정으로 읽고
# `codex_degraded: false` → approved를 낸다(흔적 0). SKILL이 "라운드마다 덮어씁니다"로
# 보장한다고 적은 바로 그 속성이 파일 잔존으로 무력화돼 있었다.
STALE="$(mktemp)" || exit 1
write_stale() { printf '%s\n' 'findings: []' 'meta:' '  codex_failed: false' > "$STALE"; }

write_stale
bash "$RUNNER" WRONGAXIS "$FX/brief-verbatim-ok.md" "$REPO_ROOT" "$STALE" >/dev/null 2>&1
grep -q 'codex_failed: false' "$STALE" \
  && no "STALE: 잘못된 axis 조기 exit 후 이전 라운드 clean YAML 잔존 — 이번 라운드 판정으로 읽힌다" \
  || ok "STALE: 조기 exit이 이전 라운드 산출물을 남기지 않음"

write_stale
bash "$RUNNER" fidelity "$FX/nonexistent-payload.md" "$REPO_ROOT" "$STALE" >/dev/null 2>&1
grep -q 'codex_failed: true' "$STALE" \
  && ok "STALE: payload 부재 → codex_failed: true로 덮어씀" \
  || no "STALE: payload 부재인데 codex_failed: true가 아니다 — stale이 살아남았다"

write_stale
bash "$RUNNER" fidelity "$FX/brief-verbatim-ok.md" "" "$STALE" >/dev/null 2>&1
grep -q 'codex_failed: false' "$STALE" \
  && no "STALE: project_dir 부재 경로에서 clean YAML이 잔존" \
  || ok "STALE: project_dir 부재 경로도 stale을 남기지 않음"

# mutation: 선-기록(seed_failclosed)을 제거하면 위 (1)이 다시 통과해야 한다.
#
# 러너는 형제 `runner_common.sh` 를 **자기 위치 기준**(`${BASH_SOURCE[0]}` 의 디렉토리)으로
# source 한다(Task 20). 그래서 다른 디렉토리로 옮긴 사본에는 그 형제도 함께 놓아야 한다 —
# 놓지 않으면 사본이 로드 가드에 걸려 **조기 degrade** 하고, 아래 mutation 은 변이가 아니라
# **위치** 때문에 실패한다(도달 불가). 그 상태의 판정은 이빨의 증거가 아니다.
MUTDIR="$(mktemp -d -t sd-brief-mut-XXXXXX)" || exit 1
cp "$SD/scripts/runner_common.sh" "$MUTDIR/runner_common.sh"
MUT="$MUTDIR/run_brief_codex_reviewer_mut.sh"
mutres="$(python3 - "$RUNNER" "$MUT" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
out = "\n".join(l for l in t.splitlines() if not l.strip().startswith("seed_failclosed"))
open(dst, "w", encoding="utf-8").write(out + "\n")
print("MUTATED" if out.strip() != t.strip() else "UNCHANGED")
PY
)"
if [[ "$mutres" == "MUTATED" ]]; then
  write_stale
  bash "$MUT" WRONGAXIS "$FX/brief-verbatim-ok.md" "$REPO_ROOT" "$STALE" >/dev/null 2>&1
  grep -q 'codex_failed: false' "$STALE" \
    && ok "STALE mutation: seed 제거 → stale이 다시 살아남음 (락에 이빨 있음)" \
    || no "STALE mutation: seed를 없애도 stale이 안 남는다 — 이 락은 다른 이유로 통과한다"
else
  no "STALE mutation: seed 호출 라인을 못 찾았다 ($mutres) — 락이 vacuous하다"
fi
rm -f "$STALE"; rm -rf "$MUTDIR"

# === F1 (2026-08-17 fix round 1) : --emit-keys design 배선 락 ===============
# codex_findings_to_yaml.py 정본화(Task 17) 이전에는 spec-distill의 emit keyset이
# 사본에 하드코딩돼 있어 호출자 배선을 잃을 방법이 없었다. 지금은 호출자 인자
# (`--emit-keys design`)이므로 이 러너에서 빠지면 category/target_section이
# 조용히 사라진다 — merge_brief_review.py가 merge_review.CODEX_DISPLAY_KEYS를
# 재사용해 그 필드를 읽는데, 필드가 없으면 codex findings가 원장에서 통째로
# 버려지면서도 codex_failed는 false로 남는다(실행되지 못한 검사가 통과한 검사로
# 기록된다). run_spec_codex_reviewer.sh 쪽엔 이미 대칭 assertion이 있다
# (test_run_spec_codex_reviewer.sh) — 여기 없던 것을 대칭으로 건다.
F1TMP="$(mktemp -d -t sd-brief-f1-XXXXXX)" || exit 1
mkdir -p "$F1TMP/codexbin"
cat > "$F1TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"ambiguity\", \"target_section\": \"#2-goals\", \"severity\": \"high\"}]}\n```"}}
JSONL
exit 0
SH
chmod +x "$F1TMP/codexbin/codex"
# 아래 identity/mutation 사본이 F1TMP 로 옮겨가므로 형제 정본도 같이 옮긴다
# (러너가 자기 위치 기준으로 source 한다 — Task 20).
cp "$SD/scripts/runner_common.sh" "$F1TMP/runner_common.sh"

# CLAUDE_PLUGIN_ROOT 를 **명시로** 넘긴다 — 형제 락
# test_run_spec_codex_reviewer.sh:62 이 이미 그렇게 한다. 러너는
# `${CLAUDE_PLUGIN_ROOT:-$(dirname "${BASH_SOURCE[0]}")/..}` 로 유도하므로,
# ① 넘기지 않으면 호출 환경이 우연히 갖고 있는 값에 이 락의 판정이 좌우되고
# ② 아래 mutation 사본은 temp dir 에 있어 유도가 엉뚱한 곳을 가리킨다
# (2026-08-17 fix round 2, R2-5·R2-6 — 이 두 줄이 없어서 mutation 이
# `prompt_build_failed` 로 조기 종료하며 **플래그 줄에 도달조차 못 했다**).
F1ENV=(CLAUDE_PLUGIN_ROOT="$SD" PATH="$F1TMP/codexbin:/usr/bin:/bin")

F1OUT="$F1TMP/out.yaml"
env "${F1ENV[@]}" bash "$RUNNER" fidelity "$PAYLOAD" "$REPO_ROOT" "$F1OUT" >/dev/null 2>&1
grep -q 'category: ambiguity' "$F1OUT" \
  && ok "F1: brief runner가 --emit-keys design을 배선해 category가 출력에 실린다" \
  || no "F1: brief runner 출력에 category가 없다 — --emit-keys design 배선 유실"

# --- 계측기 검사: identity 사본(플래그 그대로, 위치만 이동) ------------------
# mutation 이 "이빨 있음"을 주장하려면 **변이만이** category 를 죽였어야 한다.
# 위치 이동 자체가 죽이면 그 주장은 거짓이다. identity 사본을 같은 자리에서
# 같은 방식으로 돌려 그것을 먼저 배제한다 (R2-5: 이 통제가 없어서 락이
# 도달조차 못 한 실행을 "이빨 있음"으로 보고했다).
F1ID="$F1TMP/run_brief_codex_reviewer_identity.sh"
cp "$RUNNER" "$F1ID"
F1OUTID="$F1TMP/out_identity.yaml"
env "${F1ENV[@]}" bash "$F1ID" fidelity "$PAYLOAD" "$REPO_ROOT" "$F1OUTID" >/dev/null 2>&1
grep -q 'category: ambiguity' "$F1OUTID" \
  && ok "F1 계측기: identity 사본(위치만 이동)은 여전히 category 를 낸다 — 아래 변이가 플래그 줄에 도달한다" \
  || no "F1 계측기: identity 사본이 이미 category 를 못 낸다 — 아래 mutation 은 변이가 아니라 위치 때문에 실패한다(도달 불가)"

# mutation: --emit-keys design 인자 줄을 지운 사본으로 같은 것을 돌리면 위
# assertion이 다시 RED가 나야 한다(락에 이빨이 있다는 증거 — F1 완료 조건 3).
F1MUT="$F1TMP/run_brief_codex_reviewer_mut.sh"
f1mutres="$(python3 - "$RUNNER" "$F1MUT" <<'PY'
import sys
src, dst = sys.argv[1], sys.argv[2]
t = open(src, encoding="utf-8").read()
out = "\n".join(l for l in t.splitlines() if l.strip() != "--emit-keys design \\")
open(dst, "w", encoding="utf-8").write(out + "\n")
print("MUTATED" if out.strip() != t.strip() else "UNCHANGED")
PY
)"
if [[ "$f1mutres" == "MUTATED" ]]; then
  F1OUT2="$F1TMP/out2.yaml"
  env "${F1ENV[@]}" bash "$F1MUT" fidelity "$PAYLOAD" "$REPO_ROOT" "$F1OUT2" >/dev/null 2>&1
  # 원인 확정 먼저: 변이본이 실제로 codex 를 태우고 변환까지 갔는가. degrade
  # 사유(prompt_build_failed 등)로 조기 종료했다면 category 부재는 플래그와
  # 무관하고, 그것을 "이빨 있음"으로 읽으면 거짓 원인 보고다 (R2-6).
  #
  # 〔2026-08-17 fix round 3, R3-1〕 이 판별자는 **두 방향으로 fail-open** 이었다.
  # ① 맨 `grep -qE … "$F1OUT2"`: 변이본이 구문 파손돼 출력 파일 자체가 안 생기면
  #    grep 이 비-0 으로 끝나 `else` 즉 **PASS 분기**로 갔다 — 그리고 그 상태에서
  #    아래 category 판정도 "이빨 있음"을 내서 40/40 GREEN 이 나왔다(실측).
  #    `shared/tests/assert.sh` 가 그 이빨을 이미 갖고 있다: `assert_file_absent`
  #    (와 `assert_file_grep`)는 *"파일 부재는 fail-closed — `no()` 로 센다"* 다.
  #    `"$(cat …)"` 로 텍스트 변형에 넘기는 우회는 정확히 저 결함이므로 쓰지 않는다.
  # ② 사유 열거가 **하드코딩**이었다. 목록의 `extract_failed` 는 이 러너가 내지
  #    **않는** 이름이었고, 러너가 실제로 내는 여섯(`runner_incomplete` ·
  #    `payload_missing` · `missing_project_dir` · `project_dir_unreachable` ·
  #    `scratch_dir_uncreatable` · `codex_not_installed`)이 빠져 있었다 — 그래서
  #    `reason: codex_not_installed` 로 degrade 한 변이본도 "원인 확정" PASS 였다.
  #    열거는 공간·시간 양쪽으로 fail-open 이므로 **러너에서 도출**한다: 이 러너의
  #    degrade 사유는 전부 `write_failclosed` 한 곳을 지나므로 그 호출부 두 형태
  #    (`emit_fallback <reason>` · `write_failclosed "<reason>"`)가 코퍼스다.
  F1REASONS="$(
    { grep -oE 'emit_fallback[[:space:]]+[a-z_]+' "$RUNNER" \
        | sed -E 's/^emit_fallback[[:space:]]+//'
      grep -oE 'write_failclosed[[:space:]]+"[a-z_]+"' "$RUNNER" \
        | sed -E 's/^write_failclosed[[:space:]]+"//; s/"$//'
    } | sort -u)"
  n_f1reasons="$(printf '%s\n' "$F1REASONS" | grep -c . || true)"
  if [[ "$n_f1reasons" -lt 1 ]]; then
    # 도출이 0건이면 아래 ∄ 판정이 vacuous 하다 — 빈 열거는 어떤 degrade 도 못 잡는다.
    no "F1 mutation: 러너에서 degrade 사유를 한 건도 도출하지 못했다 — 원인-확정 판별자가 vacuous 하다"
  else
    assert_file_absent "$F1OUT2" \
      "^[[:space:]]*reason: ($(printf '%s' "$F1REASONS" | tr '\n' '|'))"'$' \
      "F1 mutation: 변이본이 조기 degrade 없이 변환까지 도달했다 (원인 확정 — 러너에서 도출한 사유 ${n_f1reasons}종 대조)"
  fi
  assert_file_absent "$F1OUT2" 'category: ambiguity' \
    "F1 mutation: --emit-keys design 제거 → category 소실 재현 (락에 이빨 있음)"
else
  no "F1 mutation: --emit-keys design 줄을 못 찾았다 ($f1mutres) — 락이 vacuous하다"
fi
rm -rf "$F1TMP"

finish
