#!/usr/bin/env bash
# AC12 — 게이트 연결을 **실행 관측**으로 판정한다.
#
# 실행 관측(test_codex_invocation_contract.sh)은 러너 안의 argv·stdin만 본다.
# 호출자 책임인 detect·kill switch가 러너 **앞에** 실제로 연결됐는지는 말해주지
# 않는다 — kill switch는 P21 보안 컨트롤이라 그 공백을 남기면 "껐다고 믿게만" 만든다.
#
# 여기서는 SKILL의 마킹된 게이트 블록을 잘라내 아래 시나리오들로 **실행하고**,
# codex mock이 실제로 몇 번 불렸는지 센다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
OBS_REPO="$ROOT"
. "$ROOT/plugins/quality-gates/tests/lib/codex_observation.sh"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

SCRATCH="$(mktemp -d -t qg-gate-XXXXXX)" || exit 1
# F5(Task 15 fix round 1)의 "감지기 부재" 시나리오가 실제 배포 지점의 detect_codex.sh
# 심볼릭 링크를 잠깐 지웠다 되살린다. **`mv`로 다른 디렉토리에 옮기지 않는다** — 이
# 심볼릭 링크는 **상대** 링크(`../../../shared/codex/detect_codex.sh`)라, mv로
# 옮기면 새 위치 기준으로 재해석되어 dangling이 되고, 그 dangling 링크를 백업으로
# 쓰면 `-e` 검사가 항상 거짓이라 원복 분기를 못 타 원본이 통째로 유실된다(실측:
# 이 라운드에서 실제로 겪음 — SCRATCH가 지워지며 두 배포 지점이 사라졌다가 `ln -s`로
# 즉시 재생성해 복구했다). 그래서 target 문자열만 `readlink`로 뽑아 두고 `rm -f` +
# `ln -sf`로 복원한다 — 파일 이동이 아니라 지우고-다시-만들기라 상대 경로 문제가
# 없다. 정상 종료든 조기 종료든 원복이 보장돼야 하므로, EXIT trap이 "지워진 채로
# 남았으면"(_ACTIVE_DETECTOR_TARGET이 비지 않았으면) 되살리고 나서 SCRATCH를 지운다.
# 정상 경로에서는 루프 안에서 이미 되살려 이 trap은 no-op이다.
_ACTIVE_DETECTOR_ORIG=""
_ACTIVE_DETECTOR_TARGET=""
restore_active_detector() {
  # N5(round 2): 파괴는 무조건, 복원은 조건부였던 결함의 짝 — `ln -sf` 실패를
  # 조용히 삼키면 복원 시도가 있었다는 사실만으로 안전하다고 오판하게 된다.
  # 실패하면 `no()` 로 소리 낸다(이 함수는 EXIT trap 에서도 불리므로 실패 시점의
  # `$label` 을 그대로 참조 — bash 함수는 호출부의 전역 변수를 그대로 본다).
  if [ -n "$_ACTIVE_DETECTOR_TARGET" ]; then
    if ln -sf "$_ACTIVE_DETECTOR_TARGET" "$_ACTIVE_DETECTOR_ORIG"; then
      _ACTIVE_DETECTOR_TARGET=""
    else
      no "${label:-detector}: 배포 지점 복원 실패 — $_ACTIVE_DETECTOR_ORIG 를 $_ACTIVE_DETECTOR_TARGET 로 못 되살렸다"
      _ACTIVE_DETECTOR_TARGET=""
    fi
  fi
}
trap 'restore_active_detector; rm -rf "$SCRATCH"' EXIT
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

# ── 마킹된 게이트를 아래 시나리오들(가용·kill switch·미설치·버전 바닥 미달·감지기
# 부재 — 목록은 아래 루프 본문이 정의하며 여기서 개수를 세지 않는다: N4, 개수
# 리터럴은 시나리오가 늘 때마다 이 자리에서 또 stale 해진다)로 실행한다 ───────────
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
  plugin_root_dir="$(cd "$(dirname "$sk")/../.." && pwd)"
  plugin="$(basename "$plugin_root_dir")"
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

  # 감지기 부재(F5, Task 15 fix round 1 도입) — Step 9 loud-failure 수정의 보안 관련
  # 절반이 실행 관측 없이 남아 있었다. detect_codex.sh 심볼릭 링크가 dangling 이
  # 되면(예: 배포가 target 없이 나가면) 게이트 스크립트 자체가 안 돈다 — 그 상태에서도
  # codex 를 부르면 안 된다. PATH 는 "가용" 시나리오와 동일하게 codex 가 정상
  # 해석되도록 둔다 — PATH 문제가 아니라 감지기 부재 자체가 codex 호출을 막는지를
  # 격리해서 잰다. 세 fence 전부 dangling 링크로 실측 완료 — 셋 다
  # `skip_reason=detector_not_runnable` 을 올바르게 만든다(구현자가 추론만 했던
  # `reviewing-brief` 포함). 다만 `reviewing-brief` 는 else 분기가 `:`(no-op) 라
  # **변수는 올바르게 설정되지만 아무것도 출력하지 않는다** — 그 사용자 가시 구분은
  # 하류 프로즈 advisory 에 실려 있지 이 fence 자체에는 없다(아래 case 참조).
  #
  # round 2 수정(N3): 호출 **횟수만** 세면 이 축이 무엇도 재지 못한다 — 감지기가
  # 없으면 codex_avail 이 빈 문자열이라 세 fence 모두 `if [[ "$codex_avail" == "true"
  # ]]` 로 codex 를 안 부르므로, `skip_reason="detector_not_runnable"` 세 줄을 통째로
  # 지워도 호출 수는 그대로 0 이다(호출-수 axis 는 "codex 미설치"·"kill switch" 등
  # 다른 모든 스킵 경로와 값이 같아 구별 불가). `run_gate` 가 이미 stderr 를
  # `"$cap.stderr"` 로 캡처하므로, stderr 에 skip_reason 값을 echo 하는
  # auditing-plugins·reviewing-spec 두 fence 는 그 캡처를 직접 grep 해 진짜 이빨을
  # 만든다. reviewing-brief 는 else 가 no-op 이라 stderr 에 아무것도 안 남는다 — 그
  # 축은 이 러너로는 **관측 불가**다(가짜 락을 남기지 않는다, 아래 case 의 정직한
  # 문구 참조). mutation 증명: 세 fence 의 `skip_reason="detector_not_runnable"` 줄을
  # 지우면 auditing-plugins·reviewing-spec 두 시나리오는 RED 가 되고(stderr 가
  # `${skip_reason:-unknown}` 의 fallback 인 "unknown" 을 내 grep 이 실패한다),
  # reviewing-brief 시나리오는 GREEN 그대로다(원래도 이 fence 로는 관측 불가라는
  # 주장과 일치 — 아래 report 의 "N3 mutation 증명" 절 참조).
  _ACTIVE_DETECTOR_ORIG="$plugin_root_dir/scripts/detect_codex.sh"
  # N5(round 2): 파괴(`rm -f`) 앞에 링크 여부를 확인한다. `readlink` 는 대상이
  # 심볼릭 링크가 아니면 빈 출력 + rc=1을 내는데, 이 스크립트는 `-e` 없이
  # `set -u -o pipefail` 뿐이라 그 실패를 무시하고 진행한다 — 확인 없이 진행하면
  # `_ACTIVE_DETECTOR_TARGET` 이 빈 문자열로 잡히고, 그 뒤 `rm -f` 는 **실파일**을
  # 지운다. 복원 가드(`[ -n "$_ACTIVE_DETECTOR_TARGET" ]`)는 빈 문자열에 대해
  # 거짓이라 복원 분기를 안 타 원본이 통째로 유실된다 — 이번 라운드가 만든
  # 사고(round 1 의 mv-dangling 사고)의 방향만 바꾼 재현이다. 그래서 파괴를
  # **아예 시작하지 않는다**: 심볼릭 링크가 아니면 이 플러그인의 감지기-부재
  # 시나리오만 건너뛴다(다른 시나리오들은 이 블록 앞에서 이미 돌았다 — 순서상
  # 영향 없음).
  if [ ! -L "$_ACTIVE_DETECTOR_ORIG" ]; then
    no "$label: 배포 지점이 심볼릭 링크가 아니다 — 파괴적 시나리오를 건너뛴다"
    continue
  fi
  _ACTIVE_DETECTOR_TARGET="$(readlink "$_ACTIVE_DETECTOR_ORIG")"
  rm -f "$_ACTIVE_DETECTOR_ORIG"
  NODETECT_CAP="$SCRATCH/g-$label-nodetect"
  n="$(run_scenario "$sk" "$r" "$NODETECT_CAP" "$OBS_MOCKBIN:$BASE_SUFFIX" "$OBS_MOCKBIN" "IGNORE=1")"
  restore_active_detector
  case "$n" in
    0)
      case "$label" in
        auditing-plugins|reviewing-spec)
          if grep -q 'detector_not_runnable' "$NODETECT_CAP.stderr" 2>/dev/null; then
            ok "$label: 감지기 부재 → codex 0회 + stderr에 detector_not_runnable (loud-failure 확인)"
          else
            no "$label: 감지기 부재 → codex 0회지만 stderr에 detector_not_runnable 없음 — loud-failure 미확인"
          fi
          ;;
        *)
          ok "$label: 감지기 부재 → codex 0회 (안전 확인) — 이 fence 는 else 가 no-op 이라 detector_not_runnable 표시 자체는 관측 불가(사용자 가시성은 하류 프로즈 advisory 에 의존, N3)"
          ;;
      esac
      ;;
    PREMISE_FAIL:*) no "$label: 감지기 부재 전제 실패 — PATH에서 codex가 mock으로 해석되지 않는다 (실제: ${n#PREMISE_FAIL:})" ;;
    *) no "$label: 감지기 부재 → codex ${n}회 — 게이트가 codex 호출을 막지 못한다" ;;
  esac
done
finish
