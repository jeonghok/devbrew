#!/usr/bin/env bash
# AC1 구조적 보증 — `plugins/*/agents/*.md` **전부**가 `model: inherit`이다.
#
# 왜 별도 스윕인가 (2026-08-04 /qg 라운드 1, pr-test-analyzer 적발):
# 모델 티어는 플러그인마다 손으로 열거한 per-agent 테스트로만 지켜지고 있었다.
# 그 결과 `plugins/plugin-audit/agents/`의 3개 agent(`plugin-auditor`,
# `audit-refuter`, `smoke-probe`)는 **모델 커버리지가 0**이었다 — 거기에
# `model: sonnet`을 박아도 리포의 어떤 테스트도 빨개지지 않았다. 열거는 공간에도
# 시간에도 fail-open이다: 내일 추가될 플러그인의 agent를 오늘 열거할 수 없다.
# 이 리포가 `tools:`를 denylist가 아니라 allowlist로 쓰는 것과 같은 논리다.
#
# 왜 `inherit`인가: 하니스가 리터럴 티어를 박으면 사용자가 고른 세션 모델을
# 하니스가 덮어쓴다. 리뷰어가 writer보다 약해지는 구성이 실제로 존재했고,
# 그것이 harness-capability-suppression-sweep의 출발점이었다.
#
# 범위 밖: 외부(비-devbrew) 플러그인의 하드코딩 핀은 존중한다 — 이 스윕은
# 이 리포가 소유한 `plugins/` 아래만 본다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

shopt -s nullglob
agents=(plugins/*/agents/*.md)
shopt -u nullglob

# ── 스캔이 실제로 무언가를 봤는가 (vacuous-pass 방지) ────────────────────────
# 이것이 없으면 glob이 아무것도 매치하지 않을 때 아래 루프가 0회 돌고 전부 통과한다
# — "핀이 하나도 없다"와 "아무것도 스캔하지 않았다"가 구별되지 않는 fail-open이다.
# 같은 라운드에서 `test_codex_runner_no_effort_pin.sh`가 정확히 이 방식으로
# 존재하지 않는 경로에 PASS를 냈다.
if [ "${#agents[@]}" -ge 10 ]; then
  ok "0 — 스윕이 agent ${#agents[@]}개를 실제로 열었다 (vacuous pass 아님)"
else
  no "0 — 스윕이 본 agent가 ${#agents[@]}개뿐 — glob이 깨졌거나 리포 구조가 바뀌었다"
  finish; exit
fi

missing=(); pinned=(); dup=()
for f in "${agents[@]}"; do
  n="$(grep -cE '^model:[[:space:]]' "$f" 2>/dev/null || true)"
  case "$n" in
    0) missing+=("$f") ;;
    1) grep -qE '^model:[[:space:]]+inherit[[:space:]]*$' "$f" || pinned+=("$f: $(grep -m1 -E '^model:[[:space:]]' "$f")") ;;
    *) dup+=("$f (${n}회)") ;;   # YAML은 마지막 값으로 resolve, grep -m1은 첫 값을 본다
  esac
done

[ "${#missing[@]}" -eq 0 ] && ok "1 — 'model:' 줄이 없는 agent 0개" || {
  no "1 — 'model:' 줄이 없는 agent ${#missing[@]}개"; printf '      %s\n' "${missing[@]}"; }
[ "${#pinned[@]}" -eq 0 ] && ok "2 — 리터럴 티어 핀 0개 (전부 inherit)" || {
  no "2 — 리터럴 티어 핀 ${#pinned[@]}개"; printf '      %s\n' "${pinned[@]}"; }
[ "${#dup[@]}" -eq 0 ] && ok "3 — 'model:' 키 중복 선언 0개" || {
  no "3 — 'model:' 키 중복 ${#dup[@]}개"; printf '      %s\n' "${dup[@]}"; }
finish
