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
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

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

# 코퍼스는 **플러그인 전체**다. `scripts`+`tests` 두 디렉토리만 볼 때
# `skills/`·`hooks/`·`agents/`에 심은 핀은 통과했고(mutation m13·m14 생존), 그런데도
# 아래 PASS 문구는 "리포 전역"이라고 주장했다 — 스캔 범위보다 넓은 주장은 거짓이다.
#
# 범위를 넓힌 뒤에도 plugin-audit 커버리지는 **0이었다**: 그 호출부가 산문이었고
# 마크다운 인라인 코드는 `codex` 앞에 백틱이 오므로 아래 INVOKE 정규식이 못 봤다.
# 정규식을 백틱까지 넓히는 것은 해법이 아니다(:37이 의도적으로 배제한 문자열 리터럴이
# 오탐으로 들어온다). 근본 해법은 **산문을 스크립트로 바꾸는 것**이었고, 그것을
# `plugin-audit/scripts/run_audit_codex_reviewer.sh`가 했다 — 이 주석이 참이 된
# 근거가 그 파일이다. 스캔이 여전히 못 보는 형태(마크다운 인라인 · 바이너리 간접)는
# 열린 갭이며 판정은 `test_codex_invocation_contract.sh`의 실행 관측이 한다.
scan_roots=()
for d in "$REPO"/plugins/*/; do
  [[ -d "$d" ]] && scan_roots+=("$d")
done

# positive: 스캔 코퍼스에 codex 호출부가 실제로 들어 있는가.
# 이것이 없으면 "핀이 하나도 없다"와 "아무것도 스캔하지 않았다"가 구별되지 않는다.
callsites=0
if [[ "${#scan_roots[@]}" -gt 0 ]]; then
  callsites="$(grep -rlE "$INVOKE" "${scan_roots[@]}" 2>/dev/null | wc -l | tr -d ' ')"
fi
if [[ "${#scan_roots[@]}" -ge 4 && "$callsites" -ge 3 ]]; then
  ok "스캔 코퍼스 실재: 디렉토리 ${#scan_roots[@]}개 · codex 호출부 ${callsites}개 파일"
else
  no "스캔 코퍼스가 비었거나 너무 작다 (dirs=${#scan_roots[@]} callsites=$callsites) — 아래 결과는 무의미하다"
fi

stray=""
if [[ "${#scan_roots[@]}" -gt 0 ]]; then
  stray="$(grep -rlE "$KEY" "${scan_roots[@]}" 2>/dev/null \
           | while IFS= read -r f; do
               grep -vE '^[[:space:]]*#' "$f" | grep -E "$KEY" | grep -qE "$FLAG" && echo "$f"
             done)"
fi
if [[ -z "$stray" ]]; then
  ok "리포 전역: 추론 강도 실행 인자 핀 없음"
else
  no "리포 전역: 추론 강도 핀이 남아 있다 → $(echo "$stray" | tr '\n' ' ')"
fi

# ── 보안 플래그 존속 (C1 유지선) — codex 호출부 **전부**에 대해 ─────────────
# 여기도 두 러너 열거였다: spike의 `-s read-only`는 커버리지 0이었다.
# 상한만 지우고 샌드박스까지 지우면 이 sweep이 보안 컨트롤을 걷어낸 것이 된다.
#
# **주석에 만족되면 안 된다** (2026-08-05 /qg 라운드 2, mutation m12로 3명이 독립
# 확인). 예전 판정은 원본 파일에 대한 `grep -q -- '-s read-only'` 였다. 세 러너 전부
# 헤더 주석에 `codex exec -s read-only` 를 설명으로 적어놨으므로 **실제 invocation의
# 플래그를 삭제해도 영구 GREEN**이었다 — 그 상태에서 codex는 사용자의 워킹트리에
# 샌드박스 없이 붙는다. 위 61행(상한 스캔)은 이미 주석을 걷어내고 있었는데,
# 정작 보안 플래그 판정만 원본으로 되돌아갔다. 같은 파일 안의 비대칭이었다.
# 백스톱도 없었다: `test_sandbox_enforced.sh`는 이제 존재하지 않는
# `agents/codex-reviewer.md`를 겨냥하고, `test_codex_reviewer_frontmatter.sh`는
# 같은 주석에 만족된다(둘 다 base에서도 red).
#
# 이제 **invocation 블록만 잘라내서**(줄 끝 `\` 연속을 따라가며) 주석 제거 후 판정한다.
# $1=file — 호출의 연속 줄(줄 끝 `\`)만 잘라내고 줄머리 주석을 걷어서 출력.
# 주의: 이 함수 정의 줄에 인라인 주석으로 호출 문자열을 적으면 안 된다. 주석 제거가
# `^\s*#` 앵커라 **인라인 주석은 걷히지 않고**, 이 파일이 스스로 스캔 대상이 되어
# 자기를 위반으로 신고한다 (2026-08-05에 실제로 밟았다 — 내가 고치던 결함과 같은 종류).
_invocation_block() {
  awk '/(^|[[:space:]])codex[[:space:]]+exec([[:space:]]|$)/{inv=1}
       inv{print; if ($0 !~ /\\[[:space:]]*$/) inv=0}' "$1" \
    | grep -vE '^[[:space:]]*#'
}
missing_sandbox=""
sandbox_seen=0
if [[ "${#scan_roots[@]}" -gt 0 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] || continue
    grep -vE '^[[:space:]]*#' "$f" | grep -qE "$INVOKE" || continue
    sandbox_seen=$((sandbox_seen+1))
    _invocation_block "$f" | grep -qE '(^|[[:space:]])-s[[:space:]]+read-only' \
      || missing_sandbox="$missing_sandbox $f"
  done < <(grep -rlE "$INVOKE" "${scan_roots[@]}" 2>/dev/null)
fi
# 스캔이 실제로 호출부를 봤는가 — 없으면 "위반 0"과 "아무것도 안 봄"이 구별되지 않는다.
if [[ "$sandbox_seen" -ge 3 ]]; then
  ok "샌드박스 스캔이 실제 codex 호출부 ${sandbox_seen}곳을 열었다 (vacuous 아님)"
else
  no "샌드박스 스캔이 본 호출부가 ${sandbox_seen}곳뿐 — 경로가 깨졌다(아래 판정 무의미)"
fi
if [[ -z "${missing_sandbox// /}" ]]; then
  ok "codex invocation 전부가 -s read-only 샌드박스를 유지한다 (주석 제외 후 판정)"
else
  no "샌드박스 없는 codex invocation →$missing_sandbox"
fi

# `-C`/`--json`도 같은 이유로 invocation 블록에서 잰다 — 주석에 이름만 있어도 통과하면
# 파싱 계약과 작업디렉토리 핀 역시 조용히 사라질 수 있다.
for r in run_codex_reviewer run_artifact_codex_reviewer; do
  RUN="$ROOT/scripts/$r.sh"
  if [[ ! -f "$RUN" ]]; then no "$r.sh 부재"; continue; fi
  _invocation_block "$RUN" | grep -qE '(^|[[:space:]])-C[[:space:]]' \
    && ok "$r: -C 작업디렉토리 핀 존속 (invocation)" || no "$r: -C 사라짐"
  _invocation_block "$RUN" | grep -qE '(^|[[:space:]])--json' \
    && ok "$r: --json 파싱 계약 존속 (invocation)" || no "$r: --json 사라짐"
done
finish
