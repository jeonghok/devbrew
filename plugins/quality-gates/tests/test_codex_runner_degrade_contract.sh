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
#   좁힌 이유는 "확장이 커서"가 아니라, 확장을 시도해 실측한 결과 5개 러너 중
#   최소 2개가 이미 이 계약을 어기고 있었기 때문이다(2026-08-09 사전 조사,
#   태스크 20 범위 밖 발견 — 여기서 고치지 않는다):
#     - run_artifact_codex_reviewer.sh: 시작 시 truncate + EXIT 트랩이 없다.
#       `CLAUDE_PLUGIN_ROOT` 미설정(`set -u` abort)으로 중단시키면 이전 run의
#       stale YAML이 **그대로** 남는다(체크 5의 대응 검사가 이 러너에서는 RED).
#     - run_brief_codex_reviewer.sh: 종단 추출이 python3 종료 코드만 보고
#       `[ ! -s "$OUTPUT_PATH" ]`를 확인하지 않는다. 추출기가 exit 0 + 빈 출력을
#       내면(이 헤더가 경고하는 바로 그 실패 형태) 0바이트 산출물이 그대로
#       남는다(체크 4의 대응 검사가 이 러너에서는 RED).
#   이 두 결함은 태스크 20의 파일 스코프(테스트 3개, 러너 스크립트 제외)
#   밖이라 여기서 fix하지 않는다 — 새 테스트를 커밋해 즉시 RED로 만들면
#   "이 태스크의 산출물은 GREEN"이라는 계약과 충돌하고, 프로덕션 코드를
#   조용히 고치면 커밋 스코프(3개 파일)를 벗어난다. 검사 0(러너 도출 +
#   vacuity floor)만 전 러너에 적용하고, 나머지 행동 검사 1~7은 좁게 남긴다 —
#   조용히 좁히지 않고 이 주석으로 남긴다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

tmp="$(mktemp -d -t qg-degrade-XXXXXX)" || exit 1
trap 'rc=$?; rm -rf "$tmp"; exit $rc' EXIT
mkdir -p "$tmp/root/scripts" "$tmp/bin"

# 실제 러너가 필요로 하는 형제들은 진짜를 쓰고, 추출기만 실패하는 스텁으로 바꾼다.
for f in build_codex_prompt.py discover-spec.sh; do
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

echo ""
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
