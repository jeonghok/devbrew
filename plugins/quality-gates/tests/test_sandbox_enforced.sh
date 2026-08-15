#!/usr/bin/env bash
# 샌드박스 존속 — codex 호출부 **전부**가 `-s read-only`로 실행되는가.
#
# 옛 판정은 v1.32.0에 삭제된 `agents/codex-reviewer.md`를 겨냥해 **영구 RED**였고,
# 같은 디렉토리의 `test_codex_reviewer_frontmatter.sh:9`는 그 파일이 **없어야**
# PASS라고 요구하므로 두 테스트는 동시에 통과할 수 없었다.
#
# 과녁을 옮긴다: 문자열이 아니라 **실행된 argv**를 본다. 헤더 주석에 만족되는
# 판정은 무의미하다 — 세 러너 전부 주석에 `codex exec -s read-only`를 설명으로
# 적어놨으므로 실제 플래그를 삭제해도 GREEN이었고, 그 상태에서 codex는 사용자의
# 워킹트리에 샌드박스 없이 붙는다.
#
# `-s read-only`는 Law 2 codex 격리의 유일한 기둥이다. 인자화·완화 금지.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OBS_REPO="$ROOT"
. "$ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

# $1 = 후보 파일. backslash 연속줄을 하나의 논리줄로 합친 뒤, **비주석** 줄 중
# 실제 `codex exec` 호출을 담은 논리줄만 emit한다.
#
# 왜 필요한가: 파일 전체에 대고 `-s[[:space:]]+"?\$` 같은 grep을 그냥 돌리면
# bash의 파일-테스트 연산자 `-s`(예: `[[ -s "$OUTPUT_PATH" ]]`)가 codex의
# 샌드박스 플래그 `-s`와 텍스트로 구별되지 않는다 — 실측: 6개 후보 중 4개가
# 파일 어딘가에 `-s "$..."` 형태의 무관한 bash 테스트 연산자를 갖고 있어,
# 전체-파일 grep은 리터럴 `-s read-only`를 쓰는 러너까지 "변수" 오탐으로
# 잡았다. 아래에서 실제 codex 호출 논리줄만 골라 그 줄에서만 판정한다.
codex_invoke_line() {
  awk '
    {
      if (cont) { sub(/^[ \t]*/, ""); buf = buf " " $0 } else { buf = $0 }
      if (buf ~ /\\$/) { sub(/\\[ \t]*$/, "", buf); cont = 1 }
      else { print buf; buf = ""; cont = 0 }
    }
    END { if (buf != "") print buf }
  ' "$1" | grep -vE '^[[:space:]]*#' \
          | grep -E '(^|[[:space:]])codex[[:space:]]+exec[[:space:]]'
}

SCRATCH="$(mktemp -d -t qg-sandbox-XXXXXX)" || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
obs_setup "$SCRATCH"

candidates="$(codex_candidates)"
n_cand=0
[ -n "$candidates" ] && n_cand="$(printf '%s\n' "$candidates" | wc -l | tr -d ' ')"

# ── 두 수집기의 합치 (standing assertion) ───────────────────────────────────
# `extract_codex_invocations.py`(파이썬)와 `codex_candidates()`(위, bash — 같은
# 앵커 OBS_INVOKE를 쓴다)는 서로 독립적으로 "codex exec" 호출 후보를 찾는다.
# 둘이 같은 앵커를 쓴다는 설계 주장은 여태 1회성 수동 diff로만 확인됐다 — 그런
# 불변식은 언제든 조용히 깨질 수 있다. 여기서 고정한다: 매 실행마다 같은 root
# (plugins/)를 넘겨 두 수집기를 다시 돌리고 결과 집합을 직접 비교한다. 갈라지면
# 이번 실행에서 바로 RED — 다음 사람이 다시 수동으로 diff를 떠야 알아채는 게
# 아니라.
PY_EXTRACTOR="$ROOT/plugins/quality-gates/tests/lib/extract_codex_invocations.py"
py_candidates="$(python3 "$PY_EXTRACTOR" "$ROOT/plugins" 2>/dev/null | sort)"
sh_candidates_sorted="$(printf '%s\n' "$candidates" | grep -v '^$' | sort)"
if [ -n "$py_candidates" ] && [ "$py_candidates" = "$sh_candidates_sorted" ]; then
  ok "두 수집기(extract_codex_invocations.py · codex_candidates)가 같은 후보 집합을 낸다 (${n_cand}곳)"
else
  no "두 수집기가 갈라졌다 — python:[$(printf '%s' "$py_candidates" | tr '\n' ' ')] vs bash:[$(printf '%s' "$sh_candidates_sorted" | tr '\n' ' ')]"
fi

# ── 커버리지 — obs_invoke의 case 표에서 도출한다 ────────────────────────────
# count threshold(`seen >= 5`)는 후보가 6곳인 이 트리에서 정확히 하나가 조용히
# 사라져도 통과한다 — 그 형태의 결함은 `test_codex_invocation_contract.sh`를
# 고치며 이미 한 번 발견·수정됐다(설계 동일 이력). 여기서 재발시키지 않는다:
# 표를 다시 나열하지 않고(나열이 둘이면 갈라지는 순간 검사가 무의미해진다)
# `obs_known_candidates()`로 obs_invoke의 case 표에서 도출한 뒤 **집합**을
# 비교한다 — 개수가 아니라 부분관계라 "A가 빠지고 B가 채워지는" 치환도 잡는다.
#
# `obs_known_candidates()`는 라벨을 구체 파일명으로 분해 못 하면 더 적은
# 집합을 조용히 내는 대신 비-0으로 실패한다. `x="$(f)"`는 다음 줄에서
# `$?`를 잡지 않으면 그 실패가 command substitution에 먹혀 사라진다 — 그래서
# 대입과 같은 줄에서 `; known_rc=$?`로 즉시 잡는다.
known="$(obs_known_candidates)"; known_rc=$?
n_known=0
if [ "$known_rc" -ne 0 ]; then
  no "obs_known_candidates 파싱 실패(exit=${known_rc}) — case 표에 구체 파일명으로 분해 못 한 라벨이 있다. 아래 커버리지 판정은 건너뛴다"
  known=""
else
  [ -n "$known" ] && n_known="$(printf '%s\n' "$known" | wc -l | tr -d ' ')"
fi

if [ "$known_rc" -eq 0 ]; then
  if [ "$n_known" -ge 1 ] && [ "$n_cand" -ge "$n_known" ]; then
    ok "후보 스캔 실재: codex 호출부 ${n_cand}곳 (obs_invoke 표 ${n_known}곳) — vacuous 아님"
  else
    no "후보가 ${n_cand}곳뿐(표는 ${n_known}곳) — 계측기 붕괴. 아래 판정은 무의미하다"
  fi
fi

scanned_names=""
if [ -n "$candidates" ]; then
  scanned_names="$(printf '%s\n' "$candidates" | xargs -n1 basename 2>/dev/null | sort -u)"
fi
if [ "$known_rc" -eq 0 ]; then
  missing_known=0
  while IFS= read -r k; do
    [ -n "$k" ] || continue
    if ! printf '%s\n' "$scanned_names" | grep -qxF "$k"; then
      missing_known=$((missing_known + 1))
      no "obs_invoke 표의 '$k'가 스캔 결과에 없다 — 후보가 조용히 빠졌다(치환 포함)"
    fi
  done <<EOF_KNOWN
$known
EOF_KNOWN
  [ "$missing_known" -eq 0 ] && ok "obs_invoke 표의 알려진 후보 ${n_known}곳이 스캔 결과에서 전부 발견됨"
fi

# ── 후보마다 실행 관측: -s read-only가 실제 argv에 있는가 ──────────────────
while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  name="$(basename "$cand")"
  cap="$SCRATCH/cap-$name"; mkdir -p "$cap"
  obs_invoke "$cand" "$cap" || { no "$name: 실행할 방법이 없다 (인자 표 부재)"; continue; }
  [ "$(obs_call_count "$cap")" -ge 1 ] || { no "$name: 호출이 관측되지 않았다"; continue; }
  argv="$(obs_argv "$cap/call-0")"
  if printf '%s\n' "$argv" | grep -qx -- '-s' \
     && [ "$(printf '%s\n' "$argv" | grep -A1 -x -- '-s' | tail -1)" = "read-only" ]; then
    ok "$name: -s read-only (실행된 argv)"
  else
    no "$name: 샌드박스 없이 codex를 실행한다 — 사용자 워킹트리가 노출된다"
  fi
  # 인자화 금지: 값이 변수 확장이 아니라 리터럴 `read-only`여야 한다. 위 비교가
  # 이미 리터럴을 요구하지만, 호출자가 값을 넘길 수 있는 형태인지도 본다.
  # 파일 전체가 아니라 실제 호출 논리줄(codex_invoke_line)에서만 본다 —
  # 이유는 위 함수 정의 옆 주석 참고.
  #
  # 세 갈래로 나눈다 — **indeterminate ≠ clean**. `codex_invoke_line`이 빈
  # 문자열을 내면(향후 후보가 backslash 연속줄이 아닌 형태 — heredoc, 배열
  # 경유 인자, 함수 래핑 — 로 codex를 부르게 되면 실제로 일어난다) 아래
  # grep은 매치 없이 비-0을 내고, 두 갈래짜리 if였다면 그게 조용히 else(=
  # "리터럴, 안전")로 떨어졌다 — "못 봤다"가 "안전하다"로 흡수되는 것. 이
  # 정적 검사는 인자화 위협의 **유일한 방어선**이다: 위 argv 관측은 이걸 못
  # 잡는다 — `-s "${QG_SANDBOX:-read-only}"`처럼 기본값 있는 변수는
  # `QG_SANDBOX`가 unset인 테스트 환경에서 실제 argv가 `-s read-only`로
  # resolve돼 리터럴과 구별 안 간다. 그러니 이 한 줄이 조용히 매치 실패하면
  # 백스톱이 없다.
  inv_line="$(codex_invoke_line "$cand")"
  if [ -z "$inv_line" ]; then
    no "$name: codex_invoke_line이 호출 논리줄을 찾지 못했다 — 인자화 여부를 판정할 수 없다 (indeterminate, clean 아님)"
  elif printf '%s\n' "$inv_line" | grep -nE '(-s|--sandbox)[[:space:]]+"?\$' >/dev/null 2>&1; then
    no "$name: 샌드박스 값이 변수다 — 호출자가 완화할 수 있다"
  else
    ok "$name: 샌드박스 값이 리터럴 (호출자 인자화 불가)"
  fi
done <<EOF
$candidates
EOF

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
