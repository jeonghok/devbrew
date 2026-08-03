#!/usr/bin/env bash
# codex 러너 능력 상한 부재 락 — 두 러너(`run_codex_reviewer.sh` ·
# `run_artifact_codex_reviewer.sh`)가 `model_reasoning_effort`를 실행 인자로 핀하지
# 않으면서, load-bearing 플래그(`-s read-only` 샌드박스 · `-C` 작업디렉토리 핀 ·
# `--json` 파싱 계약)는 그대로 유지하는지 확인한다.
#
# 왜 양방향인가: 상한만 지우고 샌드박스까지 함께 지우면 이 sweep이 보안 컨트롤을
# 걷어낸 것이 된다(C1 유지선). 두 방향을 같이 재야 "상한만" 사라졌음이 증명된다.
# `-c` 인자 줄에만 앵커한다 — 주석·문서가 이름을 언급하는 것은 위반이 아니다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# ── 전수 스캔 (열거가 아니라) ────────────────────────────────────────────────
# 이 락은 원래 아래 for 루프로 **두 러너만 열거**했고, 그래서
# `tests/spike/test_codex_json_extraction.sh`의 리터럴 핀이 통째로 살아남았다
# (2026-08-03 Task 13 적발). 열거는 공간에 fail-open이다 — 목록에 없는 파일은
# 영원히 안 보이고, 내일 추가될 호출부는 오늘 열거할 수 없다. 이 리포가
# `tools:` allowlist vs denylist에 쓴 논리와 같은 실패다.
#
# `-c` 인자 줄에만 앵커하므로 이 파일 자신의 grep 패턴 문자열은 잡히지 않는다
# (그 줄들은 `grep -qE ...`로 시작한다).
stray="$(grep -rlE '^[[:space:]]*-c .*model_reasoning_effort' "$ROOT" 2>/dev/null || true)"
if [[ -z "$stray" ]]; then
  note PASS "전수: 플러그인 어디에도 추론 강도 실행 인자 핀 없음"
else
  note FAIL "전수: 추론 강도 핀이 남아 있다 → $(echo "$stray" | tr '\n' ' ')"
fi

for r in run_codex_reviewer run_artifact_codex_reviewer; do
  RUN="$ROOT/scripts/$r.sh"
  if [[ ! -f "$RUN" ]]; then note FAIL "$r.sh 부재"; continue; fi
  grep -qE '^[[:space:]]*-c .*model_reasoning_effort' "$RUN" \
    && note FAIL "$r: 추론 강도가 실행 인자로 핀됨 — 사용자 codex 설정을 하향 억제한다" \
    || note PASS "$r: 추론 강도 미핀 (사용자 codex 설정이 지배)"
  grep -qE '^[[:space:]]*-s read-only' "$RUN" \
    && note PASS "$r: -s read-only 샌드박스 존속" || note FAIL "$r: -s read-only 사라짐"
  grep -qE '^[[:space:]]*-C ' "$RUN" \
    && note PASS "$r: -C 작업디렉토리 핀 존속" || note FAIL "$r: -C 사라짐"
  grep -qE '^[[:space:]]*--json' "$RUN" \
    && note PASS "$r: --json 파싱 계약 존속" || note FAIL "$r: --json 사라짐"
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
