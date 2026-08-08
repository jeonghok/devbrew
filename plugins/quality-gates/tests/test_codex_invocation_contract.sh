#!/usr/bin/env bash
# AC11 — codex 호출 계약을 **실행 관측**으로 판정한다.
#
# 정적 grep으로는 잡을 수 없다: 셸이 `codex exec`를 쓸 수 있는 형태를 열거할 수 없고
# (`$(cat`·`$(<`·변수 경유·간접 바이너리), 열거 자체가 "열거 금지"와 충돌하며,
# 앵커를 `$PROMPT_FILE` 같은 변수 이름에 묶으면 피검자가 그 이름을 통제한다.
# 그래서 mock `codex`를 PATH 앞에 얹고 러너를 실제로 태워 argv·stdin을 관측한다.
#
# **이 테스트는 커버리지를 주장하지 않는다.** 스캔이 못 보는 호출 형태는 열린 갭이다
# (설계 §10 미해결 2). 여기서 막는 것은 vacuity뿐: 후보 0 → RED, 찾고도 안 돌림 → RED.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OBS_REPO="$ROOT"
. "$ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

SCRATCH="$(mktemp -d -t qg-obs-XXXXXX)" || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
obs_setup "$SCRATCH"

# ── 후보 수집 ────────────────────────────────────────────────────────────────
candidates="$(codex_candidates)"
n_cand=0
[ -n "$candidates" ] && n_cand="$(printf '%s\n' "$candidates" | wc -l | tr -d ' ')"

# obs_invoke의 case 표 — "무엇이 후보로 존재해야 하는가"의 유일한 권한 있는
# 목록. 여기서 다시 나열하지 않고 obs_known_candidates()로 그 표에서 도출한다
# (devbrew 열거 금지 제약 — 목록이 둘이면 갈라지는 순간 이 검사가 무의미해진다).
known="$(obs_known_candidates)"
n_known=0
[ -n "$known" ] && n_known="$(printf '%s\n' "$known" | wc -l | tr -d ' ')"

# positive: 스캔이 실제로 코퍼스를 봤는가. 이것이 없으면 "위반 0"과 "아무것도 안 봄"이
# 구별되지 않는다 (test_codex_runner_no_effort_pin.sh:50-60과 같은 형태). 문턱은
# obs_invoke 표에서 도출한 n_known을 쓴다 — 하드코딩 상수를 표와 별도로 유지하지
# 않는다(표가 자라면 이 문턱도 같은 커밋 안에서 자동으로 따라간다).
if [ "$n_known" -ge 1 ] && [ "$n_cand" -ge "$n_known" ]; then
  ok "후보 스캔 실재: codex 호출부 ${n_cand}곳 (obs_invoke 표 ${n_known}곳)"
else
  no "후보가 ${n_cand}곳뿐(표는 ${n_known}곳) — 계측기 붕괴. 아래 판정은 무의미하다"
fi

# 커버리지 ratchet — 양방향의 나머지 절반. obs_invoke의 `*)` fail-closed(표에
# 없는 이름이 스캔에 나타나면 return 90 → 호출자가 RED)는 이미 한쪽 방향을
# 막는다. 이 루프는 반대 방향을 막는다: 표에는 있는 이름이 스캔 결과에서
# 조용히 빠지는 것. 개수 문턱만으로는 "A가 빠지고 B가 채워져 수가 유지되는"
# 치환을 못 잡는다 — 개수가 아니라 집합의 부분관계를 재야 한다.
scanned_names=""
if [ -n "$candidates" ]; then
  scanned_names="$(printf '%s\n' "$candidates" | xargs -n1 basename 2>/dev/null | sort -u)"
fi
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

# ── 후보마다 실행 관측 ───────────────────────────────────────────────────────
observed_total=0
while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  name="$(basename "$cand")"
  cap="$SCRATCH/cap-$name"
  mkdir -p "$cap"
  if ! obs_invoke "$cand" "$cap"; then
    # 찾고도 안 돌린 것 = 조용한 드롭 금지. 인자 표에 없는 새 러너가 여기서 잡힌다.
    no "$name: 후보인데 실행할 방법이 없다 (obs_invoke 인자 표에 부재)"
    continue
  fi
  calls="$(obs_call_count "$cap")"
  if [ "$calls" -lt 1 ]; then
    no "$name: 실행했으나 codex 호출이 관측되지 않았다 (calls=0)"
    continue
  fi
  observed_total=$((observed_total + calls))

  d="$cap/call-0"
  argv="$(obs_argv "$d")"

  printf '%s\n' "$argv" | grep -qx -- '-' \
    && ok "$name: argv에 \`-\` (stdin 규약)" \
    || no "$name: argv에 \`-\`가 없다 — 프롬프트가 stdin으로 가지 않는다"

  printf '%s\n' "$argv" | grep -qx -- '--json' \
    && ok "$name: --json 파싱 계약" || no "$name: --json 부재"

  if printf '%s\n' "$argv" | grep -qx -- '-s' \
     && [ "$(printf '%s\n' "$argv" | grep -A1 -x -- '-s' | tail -1)" = "read-only" ]; then
    ok "$name: -s read-only 샌드박스 (invocation 실측 — 주석은 실행되지 않는다)"
  else
    no "$name: -s read-only가 실제 invocation에 없다"
  fi

  printf '%s\n' "$argv" | grep -qx -- '-C' \
    && ok "$name: -C 작업디렉토리 핀" || no "$name: -C 부재"

  # 프롬프트 바이트가 argv를 지나는가. **부분 문자열 포함**으로 판정한다 —
  # `$(cat f)`는 셸이 후행 개행을 삭제하므로 완전 일치 비교는 누출을 놓친다.
  if grep -qa "$OBS_SENTINEL" "$d/argv"; then
    no "$name: 프롬프트 바이트가 argv를 지난다 (ARG_MAX 절벽 + 조용한 실패)"
  else
    ok "$name: argv에 프롬프트 바이트 부재"
  fi

  # 양성 표식: stdin이 실제로 프롬프트를 실어 날랐는가. 이것이 없으면 argv가 비어
  # 있기만 해도 통과하는 vacuous 검사가 된다.
  if [ -s "$d/stdin" ] && grep -qa "$OBS_SENTINEL" "$d/stdin"; then
    ok "$name: stdin에 프롬프트 바이트 존재 ($(wc -c < "$d/stdin" | tr -d ' ')바이트)"
  else
    no "$name: stdin에 프롬프트가 없다 (size=$(wc -c < "$d/stdin" 2>/dev/null || echo MISSING))"
  fi
done <<EOF
$candidates
EOF

if [ "$observed_total" -ge 1 ]; then
  ok "관측된 codex 호출 총 ${observed_total}건 (계측기 생존)"
else
  no "관측된 호출이 0건 — 계측기가 붕괴했다"
fi

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
