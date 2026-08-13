#!/usr/bin/env bash
# AC12 — 게이트 연결을 **실행 관측**으로 판정한다.
#
# 실행 관측(test_codex_invocation_contract.sh)은 러너 안의 argv·stdin만 본다.
# 호출자 책임인 detect·kill switch가 러너 **앞에** 실제로 연결됐는지는 말해주지
# 않는다 — kill switch는 P21 보안 컨트롤이라 그 공백을 남기면 "껐다고 믿게만" 만든다.
#
# 여기서는 SKILL의 마킹된 게이트 블록을 잘라내 4개 시나리오로 **실행하고**,
# codex mock이 실제로 몇 번 불렸는지 센다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OBS_REPO="$ROOT"
. "$ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"

pass=0; fail=0
ok() { pass=$((pass+1)); echo "  ✓ $1"; }
no() { fail=$((fail+1)); echo "  ✗ $1"; }

SCRATCH="$(mktemp -d -t qg-gate-XXXXXX)" || exit 1
trap 'rm -rf "$SCRATCH"' EXIT
obs_setup "$SCRATCH"

# ── 양방향 ratchet: 게이트가 **없는** 러너의 원장 ────────────────────────────
# 이것은 carve-out이 아니라 ratchet이다. 새 러너가 게이트 없이 들어오면 RED이고
# (미등재), 등재된 항목에 게이트가 생기면 stale로 RED다 — 목록은 줄어들기만 한다.
# 설계 §10 미해결 1·2가 여기 그대로 서 있고, 테스트 출력에 매번 보인다.
UNGATED_run_codex_reviewer_sh='quality-pipeline/SKILL.md 이 산문 게이트 — 이 사이클 범위 밖 (설계 §10 미해결 1)'
UNGATED_run_artifact_codex_reviewer_sh='critiquing-artifacts/SKILL.md 이 산문 게이트 — 이 사이클 범위 밖 (설계 §10 미해결 1)'
UNGATED_test_codex_json_extraction_sh='수동 spike — 어떤 SKILL도 부르지 않는다'
ungated_key() { printf 'UNGATED_%s' "$(printf '%s' "$1" | tr '.-' '__')"; }

# ── 마킹된 게이트 블록 수집 ──────────────────────────────────────────────────
# 마커는 저자 통제 문자열이지만, 지우면 그 러너가 "게이트 없음"이 되어 위 ratchet에
# 걸린다 — 자기제외가 불가능하다.
declare -a GATED_RUNNER=() GATED_SKILL=()
while IFS= read -r sk; do
  [ -f "$sk" ] || continue
  while IFS= read -r r; do
    [ -n "$r" ] || continue
    GATED_RUNNER+=("$r"); GATED_SKILL+=("$sk")
  done < <(grep -oE '<!--[[:space:]]*codex-gate:begin[[:space:]]+runner=[A-Za-z0-9_.-]+' "$sk" \
           | sed -E 's/.*runner=//')
done < <(find "$ROOT"/plugins/*/skills -name SKILL.md 2>/dev/null | sort)

if [ "${#GATED_RUNNER[@]}" -ge 3 ]; then
  ok "마킹된 게이트 ${#GATED_RUNNER[@]}곳 수집 (vacuous 아님)"
else
  no "마킹된 게이트가 ${#GATED_RUNNER[@]}곳뿐 — 계측기 붕괴, 아래 판정 무의미"
fi

# ── 후보 러너마다: 게이트가 있거나, 원장에 있거나 ────────────────────────────
while IFS= read -r cand; do
  [ -n "$cand" ] || continue
  base="$(basename "$cand")"
  gated=""
  for i in "${!GATED_RUNNER[@]}"; do
    [ "${GATED_RUNNER[$i]}" = "$base" ] && gated="${GATED_SKILL[$i]}"
  done
  key="$(ungated_key "$base")"
  listed="$(eval "printf '%s' \"\${$key:-}\"")"

  if [ -n "$gated" ] && [ -n "$listed" ]; then
    no "$base: 게이트가 생겼는데 UNGATED 원장에 아직 등재돼 있다 (stale — 원장에서 지울 것)"
  elif [ -z "$gated" ] && [ -z "$listed" ]; then
    no "$base: 게이트도 없고 UNGATED 원장에도 없다 — 새 러너는 게이트를 갖거나 사유와 함께 등재돼야 한다"
  elif [ -z "$gated" ]; then
    ok "$base: 게이트 없음 — 원장 등재됨 ($listed)"
  else
    ok "$base: 마킹된 게이트 보유 (${gated#"$ROOT/"})"
  fi
done < <(codex_candidates)

# ── PATH 전제 검증 ────────────────────────────────────────────────────────────
# "미설치이길 바란다"가 아니라 "그 PATH에서 codex가 실제로 무엇으로 해석되는지
# 확인했다"여야 한다. 이 머신은 시스템에 진짜 codex가 설치돼 있다(/opt/homebrew/bin
# 등). `PATH="$mock:$PATH"`처럼 mock을 앞에 붙이고 원래 $PATH를 뒤에 이어붙이면,
# "미설치"를 흉내내려 mock에서 codex만 뺀 시나리오도 뒤의 진짜 $PATH로 새서 실제
# codex를 찾는다 — 러너가 그 실제 codex를 부르고, 관측 장치(CODEX_CAPTURE_DIR)는
# 외부 프로세스를 모르므로 캡처가 0건이다. "부재를 검출했다"와 "호출을 못 봤다"가
# 우연히 같은 값(0)이 되어 구별 불가능해지고, 테스트가 돌 때마다 의도치 않은 실제
# 외부 프로세스가 실행된다. 그래서 각 시나리오는 PATH를 **진짜 $PATH를 이어붙이지
# 않고 명시적으로만** 구성하고(리포 선례: test_codex_copies_agree.sh의 probe_out()),
# 게이트를 부르기 **전에** 그 PATH에서 `codex`가 무엇으로 해석되는지 확인한다.
# 기대와 다르면 그 시나리오를 RED로 만들고 — 전제가 깨진 채로 실행을 강행하면
# 어느 codex든 실제로 실행될 수 있으므로 — 게이트 자체를 부르지 않는다.
codex_premise_ok() {   # $1=PATH 문자열, $2=기대 디렉토리("" 면 "해석되면 안 됨")
  local test_path="$1" expect_dir="$2" resolved
  resolved="$(PATH="$test_path" command -v codex 2>/dev/null || true)"
  if [ -z "$expect_dir" ]; then
    [ -z "$resolved" ]
  else
    case "$resolved" in "$expect_dir"/*) return 0 ;; *) return 1 ;; esac
  fi
}
codex_resolved_desc() {   # 진단용 — 위와 같은 PATH에서 실제 해석 경로(또는 부재)
  PATH="$1" command -v codex 2>/dev/null || echo "<해석 안 됨>"
}

# ── 마킹된 게이트를 4개 시나리오로 실행한다 ──────────────────────────────────
# 블록이 요구하는 변수는 하니스가 전부 공급한다 — 어느 이름을 쓰는지는 블록 자유다.
run_gate() {   # $1=SKILL, $2=runner basename, $3=capture, $4=gate_path(전제 검증 통과), $5..=env KEY=VAL
  local sk="$1" runner="$2" cap="$3" gate_path="$4"; shift 4
  local plugin_root; plugin_root="$(cd "$(dirname "$sk")/../.." && pwd)"
  local w; w="$(mktemp -d "$SCRATCH/gate-XXXXXX")"
  # 러너 basename은 파일명 문자셋([A-Za-z0-9_.-]+)만 허용되지만(수집 단계),
  # `.`은 awk ERE에서 임의의 한 글자다 — 이스케이프 없이 그대로 넣으면 접두부가
  # 비슷한 러너가 나중에 추가될 때 다른 블록을 잘못 자를 수 있다.
  local runner_re; runner_re="$(printf '%s' "$runner" | sed 's/\./\\./g')"
  # 마커 사이의 bash fence 하나를 잘라낸다.
  awk -v r="$runner_re" '
    $0 ~ ("codex-gate:begin[[:space:]]+runner=" r) {ing=1; next}
    /codex-gate:end/ {ing=0}
    ing && /^```bash$/ {inb=1; next}
    ing && inb && /^```$/ {inb=0; next}
    ing && inb {print}
  ' "$sk" > "$w/gate.sh"
  [ -s "$w/gate.sh" ] || { echo "0"; return; }
  printf '%s\n%s\n' "$OBS_SENTINEL" "관측 입력" > "$w/input.md"
  mkdir -p "$cap"
  ( cd "$ROOT"
    env "$@" PATH="$gate_path" CODEX_CAPTURE_DIR="$cap" \
        CLAUDE_PLUGIN_ROOT="$plugin_root" PR="$plugin_root" PA="$plugin_root" SD="$plugin_root" \
        AXIS_FILE="$w/input.md" PAYLOAD="$w/input.md" spec_path="$w/input.md" \
        CODEX_JSON="$w/out.json" CODEX_YAML="$w/out.yaml" CODEX_DIR_YAML="$w/out.yaml" \
        HOME="$SCRATCH/home" CODEX_API_KEY=t \
        bash "$w/gate.sh" ) >/dev/null 2>"$cap.stderr" || true
  obs_call_count "$cap"
}

# 전제를 검증하고, 통과하면 게이트를 실행해 호출 수를 낸다. 실패하면 게이트를
# **부르지 않고** 실패로 보고한다("PREMISE_FAIL:<해석된 경로>"를 emit) — 전제가
# 깨진 채로 실행을 강행하지 않는다(안전 + 의미: 무엇을 셌는지 모르는 카운트는
# 카운트가 아니다).
run_scenario() {   # $1=SKILL $2=runner $3=capture $4=gate_path $5=기대디렉토리("" 이면 부재) $6..=env
  local sk="$1" runner="$2" cap="$3" gate_path="$4" expect_dir="$5"; shift 5
  if ! codex_premise_ok "$gate_path" "$expect_dir"; then
    printf 'PREMISE_FAIL:%s\n' "$(codex_resolved_desc "$gate_path")"
    return
  fi
  run_gate "$sk" "$runner" "$cap" "$gate_path" "$@"
}

mkdir -p "$SCRATCH/home"
# bash/awk/sed/grep/python3/mktemp 등 게이트·러너가 쓰는 coreutils가 여기 있다
# (리포 선례: test_codex_copies_agree.sh의 probe_out()과 동일 계열). homebrew 등
# 사용자 설치 경로는 명시적으로 제외한다 — 그게 이 라운드가 막는 leak 경로다.
BASE_SUFFIX="/usr/bin:/bin"

for i in "${!GATED_RUNNER[@]}"; do
  r="${GATED_RUNNER[$i]}"; sk="${GATED_SKILL[$i]}"
  label="$(basename "$(dirname "$sk")")"
  plugin="$(basename "$(cd "$(dirname "$sk")/../.." && pwd)")"
  case "$plugin" in
    quality-gates) sw=DEVBREW_DISABLE_QG_CODEX ;;
    spec-distill)  sw=DEVBREW_DISABLE_SPEC_DISTILL_CODEX ;;
    plugin-audit)  sw=DEVBREW_DISABLE_PLUGIN_AUDIT_CODEX ;;
    *) no "$label: 알 수 없는 플러그인 $plugin — kill switch 변수를 특정할 수 없다"; continue ;;
  esac

  n="$(run_scenario "$sk" "$r" "$SCRATCH/g-$label-avail" "$OBS_MOCKBIN:$BASE_SUFFIX" "$OBS_MOCKBIN" "IGNORE=1")"
  case "$n" in
    1) ok "$label: 가용 → codex 1회" ;;
    PREMISE_FAIL:*) no "$label: 가용 전제 실패 — PATH에서 codex가 mock으로 해석되지 않는다 (실제: ${n#PREMISE_FAIL:})" ;;
    *) no "$label: 가용 → codex ${n}회 (기대 1)" ;;
  esac

  n="$(run_scenario "$sk" "$r" "$SCRATCH/g-$label-kill" "$OBS_MOCKBIN:$BASE_SUFFIX" "$OBS_MOCKBIN" "$sw=1")"
  case "$n" in
    0) ok "$label: kill switch → codex 0회 (P21 집행 확인)" ;;
    PREMISE_FAIL:*) no "$label: kill switch 전제 실패 — PATH에서 codex가 mock으로 해석되지 않는다 (실제: ${n#PREMISE_FAIL:})" ;;
    *) no "$label: kill switch → codex ${n}회 — 스위치가 우회된다" ;;
  esac

  # 미설치: mock 디렉토리에 codex를 두지 않는다(bin-stubs의 gtimeout/timeout만).
  # PATH는 이 디렉토리 + $BASE_SUFFIX로 **명시적으로만** 구성한다 — 진짜 $PATH를
  # 이어붙이지 않는다. 그래야 위 전제 검증이 실제로 뭔가를 막는다는 것이 의미 있다.
  NOTINST_BIN="$SCRATCH/notinst-$label-bin"; mkdir -p "$NOTINST_BIN"
  cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$NOTINST_BIN/" 2>/dev/null || true
  n="$(run_scenario "$sk" "$r" "$SCRATCH/g-$label-noinst" "$NOTINST_BIN:$BASE_SUFFIX" "" "IGNORE=1")"
  case "$n" in
    0) ok "$label: 미설치 → codex 0회" ;;
    PREMISE_FAIL:*) no "$label: 미설치 전제 실패 — PATH에서 codex가 여전히 해석된다 (실제: ${n#PREMISE_FAIL:}) — 전제 누출" ;;
    *) no "$label: 미설치 → codex ${n}회" ;;
  esac

  # 버전 바닥 미달 — **계측 가능한** below-floor mock 을 쓴다 (C1, /qg 2026-08-13).
  # 예전에는 `mocks/below-floor/codex` 를 썼는데 그 mock 은 CODEX_CAPTURE_DIR 에
  # 아무것도 쓰지 않는다. 그래서 아래 `0` 기대값은 "게이트가 막았다" 와 "게이트가
  # 발화했는데 실행된 바이너리가 캡처를 안 한다" 를 구별하지 못했다 — 죽은 계측기의
  # 값과 기대값이 같았다. 캡처하는 쌍둥이를 쓰면 발화 시 call-0 이 남아 `0` 이
  # 비로소 무언가를 주장한다. (공유 자산을 고치지 않는 이유는 그 mock 헤더 참조.)
  FLOOR_BIN="$SCRATCH/floor-$label-bin"; mkdir -p "$FLOOR_BIN"
  cp "$ROOT/plugins/quality-gates/tests/mocks/below-floor-capturing/codex" "$FLOOR_BIN/codex"
  cp "$ROOT/plugins/quality-gates/tests/mocks/bin-stubs/"* "$FLOOR_BIN/" 2>/dev/null || true
  chmod +x "$FLOOR_BIN/codex"
  n="$(run_scenario "$sk" "$r" "$SCRATCH/g-$label-floor" "$FLOOR_BIN:$BASE_SUFFIX" "$FLOOR_BIN" "IGNORE=1")"
  case "$n" in
    0) ok "$label: 버전 바닥 미달 → codex 0회" ;;
    PREMISE_FAIL:*) no "$label: 버전 바닥 전제 실패 — PATH에서 codex가 mock으로 해석되지 않는다 (실제: ${n#PREMISE_FAIL:})" ;;
    *) no "$label: 바닥 미달 → codex ${n}회" ;;
  esac
done

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
