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

# ── 리포 전역 스캔 ───────────────────────────────────────────────────────────
# 이 락은 두 번 좁았다.
#   1차(2026-08-03): 두 러너만 열거 → `tests/spike/`의 리터럴 핀이 살아남았다.
#   2차(2026-08-04, /qg 라운드 1): "전수 스캔"이라 적어놓고 ROOT가 **한 플러그인**
#        (`plugins/quality-gates`)이었다. `plugins/spec-distill/scripts/`에 새 호출부를
#        만들면 아무 락도 보지 못했다. 게다가 `^[[:space:]]*-c ` 줄머리 앵커라
#        (a) 앞 플래그 줄에 접어 넣기 `-C "$DIR" -c '…'`
#        (b) 롱폼 `--config '…'`
#        (c) 배열 대입 `ARGS=(-c model_reasoning_effort=low)`
#        셋 다 통과했고, `|| true`는 ROOT가 틀려도 PASS를 냈다(fail-open).
#
# 그래서: 리포 루트에서 모든 플러그인의 scripts/·tests/를 보고, 플래그는 줄 어디에
# 있어도 잡고, "스캔이 실제로 코퍼스를 봤다"를 positive로 증명한다.
#
# 자기매칭을 피하는 방법: 키 이름과 플래그 패턴을 **다른 줄의 변수**로 나눈다.
# 판정은 한 줄에 둘 다 있을 때만 내려지므로, 이 파일의 패턴 정의 줄은 잡히지 않는다.
# 주석 줄은 제외한다 — 이름을 *언급*하는 것은 위반이 아니다(실행 경로가 기준).
REPO="$(cd "$ROOT/../.." && pwd)"
KEY='model_reasoning_effort'
FLAG='(^|[[:space:]]|\()(-c|--config)([[:space:]]|=)'
# codex를 **호출**하는 줄만 call site로 센다. `codex exec`를 단순히 *언급*하는 것과
# 구별해야 한다: 파서 헬퍼(`"codex exec" in line`)와 mock의 주석이 오탐으로 잡혔다.
# 명령 위치 = 줄머리이거나 공백 뒤 — 따옴표 바로 뒤(문자열 리터럴 내부)는 아니다.
INVOKE='(^|[[:space:]])codex[[:space:]]+exec[[:space:]]'

scan_roots=()
for d in "$REPO"/plugins/*/scripts "$REPO"/plugins/*/tests; do
  [[ -d "$d" ]] && scan_roots+=("$d")
done

# positive: 스캔 코퍼스에 codex 호출부가 실제로 들어 있는가.
# 이것이 없으면 "핀이 하나도 없다"와 "아무것도 스캔하지 않았다"가 구별되지 않는다.
callsites=0
if [[ "${#scan_roots[@]}" -gt 0 ]]; then
  callsites="$(grep -rlE "$INVOKE" "${scan_roots[@]}" 2>/dev/null | wc -l | tr -d ' ')"
fi
if [[ "${#scan_roots[@]}" -ge 4 && "$callsites" -ge 3 ]]; then
  note PASS "스캔 코퍼스 실재: 디렉토리 ${#scan_roots[@]}개 · codex 호출부 ${callsites}개 파일"
else
  note FAIL "스캔 코퍼스가 비었거나 너무 작다 (dirs=${#scan_roots[@]} callsites=$callsites) — 아래 결과는 무의미하다"
fi

stray=""
if [[ "${#scan_roots[@]}" -gt 0 ]]; then
  stray="$(grep -rlE "$KEY" "${scan_roots[@]}" 2>/dev/null \
           | while IFS= read -r f; do
               grep -vE '^[[:space:]]*#' "$f" | grep -E "$KEY" | grep -qE "$FLAG" && echo "$f"
             done)"
fi
if [[ -z "$stray" ]]; then
  note PASS "리포 전역: 추론 강도 실행 인자 핀 없음"
else
  note FAIL "리포 전역: 추론 강도 핀이 남아 있다 → $(echo "$stray" | tr '\n' ' ')"
fi

# ── 보안 플래그 존속 (C1 유지선) — codex 호출부 **전부**에 대해 ─────────────
# 여기도 두 러너 열거였다: spike의 `-s read-only`는 커버리지 0이었다.
# 상한만 지우고 샌드박스까지 지우면 이 sweep이 보안 컨트롤을 걷어낸 것이 된다.
missing_sandbox=""
if [[ "${#scan_roots[@]}" -gt 0 ]]; then
  missing_sandbox="$(grep -rlE "$INVOKE" "${scan_roots[@]}" 2>/dev/null \
    | while IFS= read -r f; do
        grep -vE '^[[:space:]]*#' "$f" | grep -qE "$INVOKE" || continue
        grep -qE '(^|[[:space:]])-s[[:space:]]+read-only' "$f" || echo "$f"
      done)"
fi
if [[ -z "$missing_sandbox" ]]; then
  note PASS "codex 호출부 전부가 -s read-only 샌드박스를 유지한다"
else
  note FAIL "샌드박스 없는 codex 호출부 → $(echo "$missing_sandbox" | tr '\n' ' ')"
fi

for r in run_codex_reviewer run_artifact_codex_reviewer; do
  RUN="$ROOT/scripts/$r.sh"
  if [[ ! -f "$RUN" ]]; then note FAIL "$r.sh 부재"; continue; fi
  grep -qE '(^|[[:space:]])-C ' "$RUN" \
    && note PASS "$r: -C 작업디렉토리 핀 존속" || note FAIL "$r: -C 사라짐"
  grep -qE '(^|[[:space:]])--json' "$RUN" \
    && note PASS "$r: --json 파싱 계약 존속" || note FAIL "$r: --json 사라짐"
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
