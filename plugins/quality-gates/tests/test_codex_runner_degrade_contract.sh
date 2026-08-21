#!/usr/bin/env bash
# codex 러너의 degrade 계약: 추출이 실패해도 **소비 가능한 산출물**을 남긴다.
#
# 왜 행동 테스트인가: grep으로 "가드 문자열이 있다"를 재면, 가드를 남겨둔 채
# 무력화하는 변형(조건 반전, 리다이렉트 순서 변경)에 GREEN이 난다. 여기서 재는
# 것은 문자열이 아니라 **파일이 0바이트가 아니고 실패가 표시돼 있는가**이다.
#
# 봉쇄하는 실패: `> "$OUTPUT_PATH"`는 python3가 crash하기 *전에* 이미 파일을 비운다.
# 가드가 없으면 0바이트 산출물이 남고, 소비자에게 그것은 "codex 성공, 발견 없음"
# 으로 읽힌다 — 리뷰어 하나가 조용히 사라진다(2026-08-04 /qg 라운드 1 적발).
#
# ★ 러너 목록은 **도출**한다(태스크 20, AC23) — 아래 "0 — 러너 도출" 참고.
#   하드코딩된 run_codex_reviewer.sh 하나로는 형제 러너(run_artifact_/run_spec_/
#   run_brief_/run_audit_codex_reviewer.sh)에 같은 degrade 계약이 있는지 아무것도
#   재지 못했다 — 실제로 이 계약은 러너마다 따로 백포트됐고, 백포트를 잊은
#   러너가 조용히 남을 수 있다.
#
# ★ 범위 판단 — 아래 1~7번 행동 검사는 **run_codex_reviewer.sh 전용으로 남긴다.**
#   조용히 좁힌 것이 아니라 의도적 결정이다 — 이 검사들은 이 러너의 프롬프트
#   빌드 실패·추출 실패·완료 전 중단·usage 인자 검증 등 세부 분기까지 깊게 잰다.
#   나머지 4개 러너에 같은 깊이의 1~7번을 그대로 복제하면 각 러너의 서로 다른
#   소비자 스키마(YAML 중첩 vs 최상위 vs JSON)·의존 스크립트를 억지로 맞추게 돼
#   유지비만 크고, 태스크 20b가 실제로 필요로 한 것은 그게 아니었다.
#
#   대신 아래 "계약 핵심 3개 — 5 러너 전부" 섹션이 다음 핵심 성질 3개만 **도출된
#   5개 러너 전부**에 반복한다(나머지 4개 검사는 이 러너 전용으로 계속 남는다):
#     - 산출물이 0바이트가 아니다 (실패해도 무언가 쓴다)
#     - 실패 시 codex_failed: true 양성 표식이 있다
#     - stale 미재사용 — 실행 전에 있던 내용이 실패 후 살아남지 않는다
#
# ★ 태스크 20b (2026-08-09/10): 태스크 20이 사전 조사(위 이력)로 찾아 범위 밖에
#   남겨뒀던 아래 두 shipping 결함을, 이 파일의 3-핵심-확대 섹션이 먼저 RED로
#   확인한 뒤 러너 스크립트 쪽에서 닫았다:
#     - run_artifact_codex_reviewer.sh: 시작 시 truncate·빈-출력 degrade·EXIT
#       트랩이 셋 다 없었다. `CLAUDE_PLUGIN_ROOT` 미설정(`set -u` abort) 등으로
#       완료 전 중단되면 이전 라운드의 YAML — **양성 `codex_failed: false`
#       포함** — 이 그대로 남아 이번 라운드의 clean 판정으로 읽혔다(컨트롤러
#       재현, indeterminate ≠ clean 위반. 부재가 아니라 stale이 이번 결과로
#       제시되는, 더 나쁜 형태).
#     - run_brief_codex_reviewer.sh: 진입 시 `seed_failclosed()`가 stale은 이미
#       치우지만, 종단 추출(`codex_findings_to_yaml.py`)이 exit 0 + 빈 출력을
#       내면 그 seed까지 `> "$OUTPUT_PATH"`가 다시 비운다 — EXIT 트랩은 있었으나
#       빈-출력 가드가 없어 0바이트 산출물이 그대로 남았다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

tmp="$(mktemp -d -t qg-degrade-XXXXXX)" || exit 1
trap 'rc=$?; rm -rf "$tmp"; exit $rc' EXIT
mkdir -p "$tmp/root/scripts" "$tmp/bin"

# 실제 러너가 필요로 하는 형제들은 진짜를 쓰고, 추출기만 실패하는 스텁으로 바꾼다.
# `discover-spec.sh` 이 source 하는 `discover_common.sh` 도 형제다 — 빠지면 러너가
# 조용히 빈 <spec_context> 로 degrade 해, 이 테스트가 재는 경로가 바뀌면서도 GREEN 이
# 유지된다(실측: spec 해석이 `plugin install incomplete` 로 떨어짐).
# `codex_prompt_common.py` 는 빌더의 **형제 import** 다(stdout 가드 + P21 로더 정본의
# 사본) — 빠지면 빌더가 ImportError 로 죽고, 그 죽음도 degrade 로 읽혀 이 테스트가
# 재려던 경로(추출기 실패)와 **다른 이유**로 GREEN 이 된다.
for f in build_codex_prompt.py codex_prompt_common.py discover-spec.sh discover_common.sh prompt-preamble.md; do
  [ -f "$QG/scripts/$f" ] && cp "$QG/scripts/$f" "$tmp/root/scripts/"
done
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(1)\n' > "$tmp/root/scripts/codex_findings_to_yaml.py"
chmod +x "$tmp/root/scripts/codex_findings_to_yaml.py"
# codex 자체는 스텁 — 이 테스트는 네트워크·모델을 쓰지 않는다.
printf '#!/bin/sh\nprintf "%%s\\n" "{\\"type\\":\\"agent_message\\",\\"text\\":\\"none\\"}"\nexit 0\n' > "$tmp/bin/codex"
chmod +x "$tmp/bin/codex"
printf 'diff --git a/x b/x\n' > "$tmp/tiny.diff"

out="$tmp/out.yaml"
PATH="$tmp/bin:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/root" \
  bash "$QG/scripts/run_codex_reviewer.sh" "$tmp/tiny.diff" "$ROOT" "$out" >/dev/null 2>"$tmp/err.txt"

if [ -s "$out" ]; then
  ok "1 — 추출 실패 시 산출물이 0바이트가 아니다"
else
  no "1 — 추출 실패 시 산출물이 0바이트가 아니다 (size=$(wc -c < "$out" 2>/dev/null || echo MISSING))"
fi
if grep -q 'codex_failed: *true' "$out" 2>/dev/null; then
  ok "2 — 실패가 codex_failed로 표시된다 (성공+발견0으로 읽히지 않는다)"
else
  no "2 — 실패가 codex_failed로 표시된다"; sed 's/^/      /' "$out" 2>/dev/null
fi
# stderr가 **비어있지 않다**로는 아무것도 재지 못한다: 이 러너는 모든 분기에서
# `[quality-gates] codex spec context: …` 한 줄을 stderr에 쓰므로 `[ -s err.txt ]`는
# 반증 불가능한 assert였고, degrade echo를 통째로 지워도 GREEN이었다
# (2026-08-05 /qg 라운드 2, mutation 확인). degrade **고유** 문구를 찾는다.
if grep -q '추출 실패' "$tmp/err.txt" 2>/dev/null; then
  ok "3 — degrade가 stderr에 loud하게 남는다 (degrade 고유 문구)"
else
  no "3 — degrade가 stderr에 loud하게 남는다 (degrade 고유 문구)"; sed 's/^/      /' "$tmp/err.txt" 2>/dev/null
fi

# ── 두 번째 실패 형태: 추출기가 exit 0 하면서 아무것도 쓰지 않는 경우 ──────────
# 위 케이스(exit 1)만으로는 `-s` 빈-파일 검사에 이빨이 없다: `if ! cmd || [ ! -s ]`
# 에서 cmd가 실패하면 `!`가 이미 참이라 `-s` 절은 평가조차 되지 않는다. `-s`가
# 유일하게 중요해지는 입력은 **exit 0 + 빈 출력**이다(부분 쓰기, 파이프 실패).
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' > "$tmp/root/scripts/codex_findings_to_yaml.py"
chmod +x "$tmp/root/scripts/codex_findings_to_yaml.py"
out2="$tmp/out2.yaml"
PATH="$tmp/bin:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/root" \
  bash "$QG/scripts/run_codex_reviewer.sh" "$tmp/tiny.diff" "$ROOT" "$out2" >/dev/null 2>&1
if [ -s "$out2" ] && grep -q 'codex_failed: *true' "$out2" 2>/dev/null; then
  ok "4 — 추출기가 exit 0 + 빈 출력이어도 codex_failed로 표시된다"
else
  no "4 — 추출기가 exit 0 + 빈 출력이어도 codex_failed로 표시된다 (size=$(wc -c < "$out2" 2>/dev/null || echo MISSING))"
fi

# ── 5/6: 완료 전 중단 — stale 재사용 봉쇄 ────────────────────────────────────
# 쌍둥이 `run_spec_codex_reviewer.sh`가 spec-distill 0.24.14에서 받은 봉쇄가 이
# 러너에는 백포트되지 않아, SIGTERM/`set -u` abort/OOM/Bash-tool timeout 어느
# 경로로 죽어도 **이전 iteration의 YAML이 그대로 남았다**. 오케스트레이터는 그것을
# 이번 라운드의 codex 판정으로 읽는다 — stale이 clean이면 진짜 결함이 clean 인증을
# 받고, 발견을 담고 있으면 이미 고친 결함을 다시 쫓는다 (2026-08-05 /qg 라운드 2).
#
# 트리거는 `CLAUDE_PLUGIN_ROOT` 미설정(`set -u` 위반) — 실제로 밟은 조건이다.
# **종료 코드로 재지 않는다**: 계약이 "항상 산출물"이고, bash 3.2.57은 `set -u`
# abort 시 EXIT 트랩에 `$?`를 0으로 넘긴다. 신호는 산출물뿐이다.
stale="$tmp/stale.yaml"
cat > "$stale" <<'Y'
findings:
  - {file: OLD_RUN.py, line: 1, severity: CRITICAL, summary: "STALE_FROM_PREVIOUS_RUN", confidence: 9, agent: codex-reviewer}
meta:
  codex_failed: false
Y
( unset CLAUDE_PLUGIN_ROOT
  PATH="$tmp/bin:$PATH" bash "$QG/scripts/run_codex_reviewer.sh" "$tmp/tiny.diff" "$ROOT" "$stale" ) >/dev/null 2>&1
if grep -q 'STALE_FROM_PREVIOUS_RUN' "$stale" 2>/dev/null; then
  no "5 — 이전 run의 stale 산출물이 이번 결과로 재사용된다"
else
  ok "5 — 중단 시 stale 산출물이 재사용되지 않는다"
fi
if [ -s "$stale" ] && grep -q 'codex_failed: *true' "$stale" 2>/dev/null; then
  ok "6 — 완료 전 중단이 codex_failed로 표시된다 (부재도, 성공도 아님)"
else
  no "6 — 완료 전 중단이 codex_failed로 표시된다 (size=$(wc -c < "$stale" 2>/dev/null || echo MISSING))"
fi

# ── 7: OUTPUT_PATH 누락이 조용히 지나가지 않는다 ─────────────────────────────
# 쌍둥이는 usage + exit 2인데 이 러너는 검증이 없어, `$3`가 비면 모든
# `> "$OUTPUT_PATH"`가 실패하고 아무것도 쓰지 않은 채 죽었다 — 헤더가 약속한
# "항상 산출물" 계약을 자기가 깬다.
usage_out="$(PATH="$tmp/bin:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/root" \
  bash "$QG/scripts/run_codex_reviewer.sh" "$tmp/tiny.diff" "$ROOT" 2>&1)"
usage_rc=$?
if [ "$usage_rc" -ne 0 ] && printf '%s' "$usage_out" | grep -q 'usage'; then
  ok "7 — OUTPUT_PATH 누락 시 usage + 비-0 종료 (조용한 실패 아님)"
else
  no "7 — OUTPUT_PATH 누락 시 usage + 비-0 종료 (rc=$usage_rc out=$usage_out)"
fi

# ── 0: 러너 목록을 도출한다 (태스크 20, AC23) ────────────────────────────────
# 위 1~7번은 run_codex_reviewer.sh 하드코딩 1개만 잰다. 이 검사는 그것으로
# "다른 4개 러너에도 같은 계약이 있는가"를 재지 못한다는 사실 자체를 vacuity로
# 봉쇄한다 — 후보 수집기(codex_observation.sh)가 실제로 5개 이상을 찾아내는지
# 만 확인한다(파일 상단 범위 판단 참고 — 5개 각각에 1~7을 반복하지는 않는다).
OBS_REPO="$ROOT"
. "$ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"
runners="$(codex_candidates | grep '/scripts/run_.*codex.*\.sh$' || true)"
runner_n="$(printf '%s\n' "$runners" | grep -c . || true)"
if [ "$runner_n" -ge 5 ]; then
  ok "0 — 러너 도출 ${runner_n}개 (vacuous 아님)"
else
  no "0 — 러너가 ${runner_n}개뿐 — 도출 기준이 깨졌다"
  printf '%s\n' "$runners" | sed 's/^/      /'
fi

# ══ 계약 핵심 3개 — 5 러너 전부 (태스크 20b) ═══════════════════════════════
# 위 1~7번은 run_codex_reviewer.sh 하나만 깊게 잰다. 여기서는 같은 3개 핵심
# 성질(0바이트 아님 · codex_failed:true · stale 미재사용)을 도출된 5개 러너
# 전부에 반복한다. 러너마다 두 시나리오로 잰다:
#   - "빈-시작": OUTPUT_PATH를 빈 파일로 시작 → 0바이트·양성표식 검사에 이빨.
#   - "stale-시작": OUTPUT_PATH에 이전 라운드의 "성공" YAML/JSON을 미리 심고
#     시작 → stale-미재사용 검사에 이빨(양성표식 검사도 겸함).
# 트리거는 러너마다 다르다 — 형제마다 CLAUDE_PLUGIN_ROOT 처리가 다르기
# 때문이다 (그대로 흉내내면 안 되는 이유는 이 파일 헤더 및 task-20b-brief.md
# 참고): run_codex_reviewer.sh/run_artifact_codex_reviewer.sh/
# run_spec_codex_reviewer.sh는 `${CLAUDE_PLUGIN_ROOT}`를 가드 없이 참조하므로
# 환경에서 지우면 `set -u`가 스크립트를 완료 전에 죽인다(실제로 컨트롤러가 밟은
# 조건). run_brief_codex_reviewer.sh/run_audit_codex_reviewer.sh는 fallback
# (`${CLAUDE_PLUGIN_ROOT:-...}`)이 있어 env-unset이 통하지 않는다 — 대신 그
# 러너의 **종단 추출기**를 exit 0 + 빈 stdout 스텁으로 바꿔치기한 fake
# CLAUDE_PLUGIN_ROOT에서 실행해 같은 실패 형태(추출이 "성공"했다고 exit하면서
# 아무것도 쓰지 않음)를 재현한다. codex 자체는 항상 스텁(과금·네트워크 없음).
mkdir -p "$tmp/bin5"
printf '#!/bin/sh\nprintf "%%s\\n" "{\\"type\\":\\"agent_message\\",\\"text\\":\\"none\\"}"\nexit 0\n' > "$tmp/bin5/codex"
chmod +x "$tmp/bin5/codex"

POS_MARKER_RE='"?codex_failed"?[[:space:]]*:[[:space:]]*true'
# $1=라벨 $2=산출물 경로 $3=stale marker 문자열(빈 문자열이면 그 검사는 skip —
# "빈-시작" 시나리오에는 재사용될 stale이 애초에 없어 검사 자체가 무의미하다)
assert_degrade3() {
  local label="$1" out="$2" stale_marker="$3"
  if [ -s "$out" ]; then
    ok "$label: 산출물이 0바이트가 아니다"
  else
    no "$label: 산출물이 0바이트가 아니다 (size=$(wc -c < "$out" 2>/dev/null || echo MISSING))"
  fi
  if grep -qE "$POS_MARKER_RE" "$out" 2>/dev/null; then
    ok "$label: 실패가 codex_failed:true로 표시된다"
  else
    no "$label: 실패가 codex_failed:true로 표시된다"; sed 's/^/      /' "$out" 2>/dev/null
  fi
  if [ -n "$stale_marker" ]; then
    if grep -qF "$stale_marker" "$out" 2>/dev/null; then
      no "$label: stale 산출물이 재사용된다 ($stale_marker 잔존)"
    else
      ok "$label: stale 산출물이 재사용되지 않는다"
    fi
  fi
}

SD="$ROOT/plugins/spec-distill"
PA="$ROOT/plugins/plugin-audit"

# --- A) run_codex_reviewer.sh — 위 5/6이 이미 만든 $stale를 그대로 재사용
#     (같은 시나리오를 두 번 돌리지 않는다) ---
assert_degrade3 "5러너 A(run_codex_reviewer.sh, stale-시작)" "$stale" "STALE_FROM_PREVIOUS_RUN"

# --- B) run_artifact_codex_reviewer.sh ---
printf '아티팩트 fixture\n' > "$tmp/artifact-fix.md"
b_empty="$tmp/degrade3-b-empty.yaml"; : > "$b_empty"
( unset CLAUDE_PLUGIN_ROOT
  PATH="$tmp/bin5:$PATH" bash "$QG/scripts/run_artifact_codex_reviewer.sh" "$tmp/artifact-fix.md" "$ROOT" "$b_empty" ) >/dev/null 2>&1
assert_degrade3 "5러너 B(run_artifact_codex_reviewer.sh, 빈-시작)" "$b_empty" ""

b_stale="$tmp/degrade3-b-stale.yaml"
printf '%s\n' 'agent: codex-reviewer' 'findings:' '  - {summary: "STALE_MARKER_B"}' 'meta:' '  codex_failed: false' > "$b_stale"
( unset CLAUDE_PLUGIN_ROOT
  PATH="$tmp/bin5:$PATH" bash "$QG/scripts/run_artifact_codex_reviewer.sh" "$tmp/artifact-fix.md" "$ROOT" "$b_stale" ) >/dev/null 2>&1
assert_degrade3 "5러너 B(run_artifact_codex_reviewer.sh, stale-시작)" "$b_stale" "STALE_MARKER_B"

# --- C) run_spec_codex_reviewer.sh (이미 준수 — 회귀 방지) ---
printf '# design doc fixture\n' > "$tmp/doc-fix.md"
c_empty="$tmp/degrade3-c-empty.yaml"; : > "$c_empty"
( unset CLAUDE_PLUGIN_ROOT
  PATH="$tmp/bin5:$PATH" bash "$SD/scripts/run_spec_codex_reviewer.sh" "$tmp/doc-fix.md" "$ROOT" "$c_empty" ) >/dev/null 2>&1
assert_degrade3 "5러너 C(run_spec_codex_reviewer.sh, 빈-시작)" "$c_empty" ""

c_stale="$tmp/degrade3-c-stale.yaml"
printf '%s\n' 'findings:' '  - {file: OLD.py, line: 1, category: x, target_section: y, severity: CRITICAL, summary: "STALE_MARKER_C"}' 'meta:' '  codex_failed: false' > "$c_stale"
( unset CLAUDE_PLUGIN_ROOT
  PATH="$tmp/bin5:$PATH" bash "$SD/scripts/run_spec_codex_reviewer.sh" "$tmp/doc-fix.md" "$ROOT" "$c_stale" ) >/dev/null 2>&1
assert_degrade3 "5러너 C(run_spec_codex_reviewer.sh, stale-시작)" "$c_stale" "STALE_MARKER_C"

# --- D) run_brief_codex_reviewer.sh — CLAUDE_PLUGIN_ROOT에 fallback이 있어
#     env-unset 트리거가 안 통한다. 종단 추출기를 exit0+빈출력 스텁으로 바꾼
#     fake root로 재현한다(실제 결함 형태 그대로: seed_failclosed가 stale은
#     지우지만 이 마지막 단계가 그 seed를 다시 비운다). ---
mkdir -p "$tmp/rootD/scripts"
cp "$SD/scripts/build_brief_codex_prompt.py" "$tmp/rootD/scripts/"
cp "$SD/scripts/codex_prompt_common.py" "$tmp/rootD/scripts/"   # 빌더의 형제 import
cp "$SD/scripts/brief-codex-direction-checklist.md" "$tmp/rootD/scripts/"
cp "$SD/scripts/brief-codex-fidelity-checklist.md" "$tmp/rootD/scripts/"
cp "$SD/scripts/prompt-preamble.md" "$tmp/rootD/scripts/"
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' > "$tmp/rootD/scripts/codex_findings_to_yaml.py"
chmod +x "$tmp/rootD/scripts/codex_findings_to_yaml.py"
printf '브리프 fixture\n사용자 원문 예시\n' > "$tmp/payload-fix.md"

d_empty="$tmp/degrade3-d-empty.yaml"; : > "$d_empty"
PATH="$tmp/bin5:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/rootD" \
  bash "$SD/scripts/run_brief_codex_reviewer.sh" fidelity "$tmp/payload-fix.md" "$ROOT" "$d_empty" >/dev/null 2>&1
assert_degrade3 "5러너 D(run_brief_codex_reviewer.sh, 빈-시작)" "$d_empty" ""

d_stale="$tmp/degrade3-d-stale.yaml"
printf '%s\n' 'findings:' '  - {summary: "STALE_MARKER_D"}' 'meta:' '  codex_failed: false' > "$d_stale"
PATH="$tmp/bin5:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/rootD" \
  bash "$SD/scripts/run_brief_codex_reviewer.sh" fidelity "$tmp/payload-fix.md" "$ROOT" "$d_stale" >/dev/null 2>&1
assert_degrade3 "5러너 D(run_brief_codex_reviewer.sh, stale-시작)" "$d_stale" "STALE_MARKER_D"

# --- E) run_audit_codex_reviewer.sh (이미 준수 — 회귀 방지, JSON 소비자) ---
mkdir -p "$tmp/rootE/scripts"
cp "$PA/scripts/codex-prompt-preamble.md" "$tmp/rootE/scripts/"
cp "$PA/scripts/prompt-preamble.md" "$tmp/rootE/scripts/"
printf '#!/usr/bin/env python3\nimport sys\nsys.exit(0)\n' > "$tmp/rootE/scripts/codex_audit_to_json.py"
chmod +x "$tmp/rootE/scripts/codex_audit_to_json.py"
printf '# axis question fixture\n' > "$tmp/axis-fix.md"

e_empty="$tmp/degrade3-e-empty.json"; : > "$e_empty"
PATH="$tmp/bin5:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/rootE" \
  bash "$PA/scripts/run_audit_codex_reviewer.sh" "$tmp/axis-fix.md" "$ROOT" "$e_empty" >/dev/null 2>&1
assert_degrade3 "5러너 E(run_audit_codex_reviewer.sh, 빈-시작)" "$e_empty" ""

e_stale="$tmp/degrade3-e-stale.json"
printf '{"findings": [{"summary": "STALE_MARKER_E"}], "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "meta": {"codex_failed": false}}\n' > "$e_stale"
PATH="$tmp/bin5:$PATH" CLAUDE_PLUGIN_ROOT="$tmp/rootE" \
  bash "$PA/scripts/run_audit_codex_reviewer.sh" "$tmp/axis-fix.md" "$ROOT" "$e_stale" >/dev/null 2>&1
assert_degrade3 "5러너 E(run_audit_codex_reviewer.sh, stale-시작)" "$e_stale" "STALE_MARKER_E"
finish
