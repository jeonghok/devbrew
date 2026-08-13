#!/usr/bin/env bash
# codex_observation.sh — 실행 관측 공유 하니스. `source`해서 쓴다.
#
# 설계 §4.3. 이 파일이 소유하는 것:
#   (1) 후보 수집 — 무엇을 실행할지
#   (2) 후보별 인자 주입 — 러너마다 필요한 인자가 다르다
#   (3) 캡처 판독 — NUL 구분 argv를 줄로
#
# **커버리지를 주장하지 않는다.** 스캔이 못 보는 형태(마크다운 인라인 · 바이너리
# 간접)는 열린 갭이며 설계 §10에 기록돼 있다. 여기서 하는 일은 vacuity를 막는 것뿐:
# 후보가 0이면 RED, 찾고도 안 돌린 것이 있으면 RED.

OBS_REPO="${OBS_REPO:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# codex를 **호출**하는 줄의 정규식. 명령 위치 = 줄머리이거나 공백 뒤 — 따옴표
# 바로 뒤(문자열 리터럴 내부)는 아니다. `test_codex_runner_no_effort_pin.sh:38`과
# 같은 앵커를 쓴다 (DRY: 두 파일이 다른 앵커를 쓰면 커버리지가 조용히 갈라진다).
OBS_INVOKE='(^|[[:space:]])codex[[:space:]]+exec[[:space:]]'

# ── (1) 후보 수집 ────────────────────────────────────────────────────────────
# **비-주석** 줄에 호출이 있는 파일만. 주석에만 있는 파일(검사 스크립트·문서)은
# 실행 대상이 아니다 — 실측: 이 필터가 test_sandbox_enforced.sh를 정확히 걸러낸다.
codex_candidates() {
  local f
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    grep -vE '^[[:space:]]*#' "$f" | grep -qE "$OBS_INVOKE" && printf '%s\n' "$f"
  done < <(grep -rlE "$OBS_INVOKE" "$OBS_REPO"/plugins/ 2>/dev/null) | sort
}

# ── (2) 관측 환경 ────────────────────────────────────────────────────────────
# $1 = scratch 디렉토리. OBS_SENTINEL / OBS_MOCKBIN을 세팅한다.
#
# **fail-closed (Important 3, Fix round 2).** cp/chmod가 실패해도 예전엔 조용히
# 진행했다 — OBS_MOCKBIN이 codex 없는 디렉토리를 가리키면 `PATH="$OBS_MOCKBIN:$PATH"`
# 의 탐색이 그 디렉토리를 그냥 지나쳐 이 머신에 실재하는 real codex(예:
# /opt/homebrew/bin/codex)로 조용히 폴백한다 — 관측이 아니라 실제 과금 호출이
# 나간다. 호출자(4개 소비자)가 obs_setup의 반환값을 확인하지 않을 수도 있으므로,
# 여기서 loud하게 return 1하는 것과 **별개로** obs_invoke() 자신도 실행 직전에
# 한 번 더 확인한다(아래) — 방어선을 실행 지점에 둔다. 안전은 그 obs_invoke
# 가드가 담당하고, 여기 return 1은 어디까지나 진단용이다.
#
# **두 변수를 먼저 세팅한다 (Fix round 3, Important 1).** 두 실패 분기(cp 실패 ·
# 최종 실행권한 확인 실패)가 서로 다른 사후상태를 남기면 — 한쪽은 두 변수가
# unset인 채로 return하면 `set -u` 소비자(예: test_codex_gate_observation.sh가
# $OBS_MOCKBIN으로 자기 PATH를 짓는 지점)가 "unbound variable"로 죽어, 원래
# 냈어야 할 깨끗한 진단("전제 실패 — PATH에서 codex가 mock으로 해석되지 않는다")
# 보다 못한 진단을 낸다(실측: 13pass/6fail 깨끗한 메시지 → 7pass/12fail
# unbound-variable). 안전은 바뀌지 않는다 — obs_invoke가 실행 직전에 독립적으로
# 재확인하므로 값이 아직 유효하지 않아도 real codex로 새지 않는다. 이건 실패
# 시에도 **일관된 사후상태**를 보장해 진단 legibility만 고치는 것이다.
obs_setup() {
  OBS_SCRATCH="$1"
  OBS_MOCKBIN="$OBS_SCRATCH/bin"
  # sentinel은 **입력 파일**에 심는다. 빌더가 그것을 프롬프트에 치환하므로,
  # sentinel이 stdin에 있으면 프롬프트가 stdin으로 갔다는 뜻이고 argv에 있으면
  # argv로 샜다는 뜻이다. 프롬프트 전문 대조보다 강하다 — `$(cat f)`가 후행 개행을
  # 삭제해도 sentinel은 온전하다.
  OBS_SENTINEL='CODEX_OBS_SENTINEL_7f3a9c2b'
  mkdir -p "$OBS_SCRATCH/bin"
  cp "$OBS_REPO/plugins/quality-gates/tests/mocks/capture-codex/codex" "$OBS_SCRATCH/bin/codex" || {
    echo "obs_setup: mock codex 복사 실패 — 계속하면 PATH가 real codex로 조용히 폴백한다" >&2
    return 1
  }
  chmod +x "$OBS_SCRATCH/bin/codex"
  # timeout/gtimeout이 없으면 detect가 timeout_binary_missing으로 막고 spike는 죽는다.
  cp "$OBS_REPO/plugins/quality-gates/tests/mocks/bin-stubs/"* "$OBS_SCRATCH/bin/" 2>/dev/null || true
  [ -x "$OBS_MOCKBIN/codex" ] || {
    echo "obs_setup: mock codex가 최종적으로 실행 가능한 상태가 아니다($OBS_MOCKBIN/codex) — real codex 폴백 위험" >&2
    return 1
  }
}

# $1 = 후보 파일 경로, $2 = capture 디렉토리. 성공하면 0.
# **fail-closed**: 표에 없는 후보는 비-0을 내고 호출자가 RED로 만든다. 열거이지만
# 방향이 반대다 — 잊으면 조용히 skip되는 게 아니라 검사가 깨진다.
obs_invoke() {
  local cand="$1" capture="$2"
  # obs_setup이 loud하게 실패해도(위) 호출자가 그 반환값을 확인하지 않을 수 있다.
  # 여기서 실행 직전에 한 번 더 막는다 — 이 확인이 없으면 mock이 없는 PATH가
  # 조용히 real codex로 폴백해 실제 과금 호출이 나간다(Important 3, Fix round 2).
  if [ ! -x "${OBS_MOCKBIN:-}/codex" ]; then
    echo "obs_invoke: mock codex가 없다(OBS_MOCKBIN=${OBS_MOCKBIN:-<unset>}) — real codex 폴백을 막기 위해 호출을 거부한다" >&2
    return 96
  fi
  local base; base="$(basename "$cand")"
  local work; work="$(mktemp -d "$OBS_SCRATCH/work-XXXXXX")"
  local input="$work/input.md" out="$work/out.yaml"
  printf 'devbrew observation input\n%s\n필요 없는 본문 한 줄.\n' "$OBS_SENTINEL" > "$input"

  local qg="$OBS_REPO/plugins/quality-gates" sd="$OBS_REPO/plugins/spec-distill"
  local pa="$OBS_REPO/plugins/plugin-audit"
  local rc=0
  case "$base" in
    run_codex_reviewer.sh)
      printf 'diff --git a/x b/x\n+%s\n' "$OBS_SENTINEL" > "$input"
      PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$capture" CLAUDE_PLUGIN_ROOT="$qg" \
        bash "$cand" "$input" "$OBS_REPO" "$out" >/dev/null 2>&1 || rc=$?
      ;;
    run_artifact_codex_reviewer.sh)
      PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$capture" CLAUDE_PLUGIN_ROOT="$qg" \
        bash "$cand" "$input" "$OBS_REPO" "$out" >/dev/null 2>&1 || rc=$?
      ;;
    run_spec_codex_reviewer.sh)
      PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$capture" CLAUDE_PLUGIN_ROOT="$sd" \
        bash "$cand" "$input" "$OBS_REPO" "$out" >/dev/null 2>&1 || rc=$?
      ;;
    run_brief_codex_reviewer.sh)
      PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$capture" CLAUDE_PLUGIN_ROOT="$sd" \
        bash "$cand" direction "$input" "$OBS_REPO" "$out" >/dev/null 2>&1 || rc=$?
      ;;
    run_audit_codex_reviewer.sh)
      PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$capture" CLAUDE_PLUGIN_ROOT="$pa" \
        bash "$cand" "$input" "$OBS_REPO" "$work/out.json" >/dev/null 2>&1 || rc=$?
      ;;
    test_codex_json_extraction.sh)
      # ⚠ 이 spike는 성공 시 **리포에 fixture를 쓴다**(`:73-76`,
      # fixtures/codex_jsonl_sample.json). mock 아래에서 그냥 돌리면 실제 fixture를
      # mock 출력으로 덮어쓴다 — 테스트가 리포를 변형하는 것은 허용되지 않는다.
      # SCRIPT_DIR이 $0에서 오므로 **scratch 사본을 실행**하면 fixture 쓰기가
      # scratch로 간다. cwd는 리포 안이어야 `git rev-parse --show-toplevel`이 산다.
      mkdir -p "$work/spike"
      cp "$cand" "$work/spike/"
      cp "$(dirname "$cand")/spike_prompt.md" "$work/spike/" 2>/dev/null || true
      printf '\n%s\n' "$OBS_SENTINEL" >> "$work/spike/spike_prompt.md"
      ( cd "$OBS_REPO" && PATH="$OBS_MOCKBIN:$PATH" CODEX_CAPTURE_DIR="$capture" \
          bash "$work/spike/$base" ) >/dev/null 2>&1 || rc=$?
      ;;
    *)
      echo "obs_invoke: 인자 표에 없는 후보 — $cand" >&2
      return 90
      ;;
  esac
  return 0   # 러너 계약은 항상 exit 0이고, 관측은 종료 코드가 아니라 캡처로 한다.
}

# obs_invoke의 `case "$base" in ... esac`가 "무엇이 후보로 존재해야 하는가"의
# 유일한 권한 있는 목록이다. 여기서 같은 이름들을 다시 나열하면 목록이 둘이 되고,
# 둘이 갈라지는 순간 커버리지 검사 자체가 무의미해진다(devbrew 열거 금지 제약).
# 그래서 나열하지 않고 `declare -f`로 obs_invoke의 소스를 되읽어 case 라벨을
# 뽑는다 — 표가 바뀌면(러너 추가·개명) 이 함수도 같은 커밋 안에서 자동으로
# 따라간다.
#
# **핵심 불변식: 이 함수는 조용히 덜 걷을 수 없다.** 라벨 한 줄이 구체 파일명
# 으로 분해 안 되면(compound `a|b)`는 분해해서 지원하지만, glob·따옴표·변수
# 경유·기타 미상 형태는 분해 불가) 더 적은 집합을 반환하는 대신 비-0으로
# 실패한다 — 호출자가 그 실패를 명시적으로 RED로 만들어야 한다(아래
# test_codex_invocation_contract.sh 참고). 라벨 추출 자체는 나열이 아니라
# case 문법의 구조적 불변식에 의존한다: `case ... in` 직후 첫 줄과 각 `;;`
# 종료 다음 첫 줄은 문법상 항상 다음 arm의 패턴이다(바디가 거기 올 수 없다).
# `esac`가 뒤에 명령이 더 있으면 `esac;`로 세미콜론이 붙어 나오는 것도 흡수한다.
obs_known_candidates() {
  local src label_lines label alt names="" bad=0

  src="$(declare -f obs_invoke)"

  label_lines="$(printf '%s\n' "$src" | awk '
    /case "\$base" in/ { incase=1; expect=1; next }
    incase && /^[[:space:]]*esac;?[[:space:]]*$/ { incase=0; next }
    incase && expect { print; expect=0; next }
    incase && /^[[:space:]]*;;[[:space:]]*$/ { expect=1 }
  ')"

  if [ -z "$label_lines" ]; then
    echo "obs_known_candidates: case 표에서 라벨 줄을 하나도 못 찾았다 — 추출기가 case 문법과 어긋났다" >&2
    return 91
  fi

  while IFS= read -r label; do
    [ -n "$label" ] || continue
    label="$(printf '%s' "$label" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//; s/\)$//')"

    # `*` — 의도된 fail-closed 캐치올(obs_invoke의 표에 없는 후보를 막는 방향).
    # 정규식이 우연히 못 맞혀서 빠지는 게 아니라, 여기서 이름으로 콕 집어 제외한다.
    [ "$label" = "*" ] && continue

    # compound 라벨(`a.sh|b.sh)`)은 지원한다 — `|`로 나눠 각 alternative를
    # 구체 파일명 문자셋([A-Za-z0-9_.-])인지 검사한다. 하나라도 그 문자셋을
    # 벗어나면(글롭 메타문자·따옴표·`$`변수·공백 등) 이 라벨 전체를 미상 형태로
    # 보고 시끄럽게 실패한다 — 그 alternative만 조용히 빼고 나머지로 계속하지 않는다.
    while IFS= read -r alt; do
      alt="$(printf '%s' "$alt" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')"
      case "$alt" in
        ''|*[!A-Za-z0-9_.-]*)
          echo "obs_known_candidates: 라벨 '$alt'를 구체 파일명으로 분해할 수 없다(글롭·따옴표·변수 경유·기타 미상 형태) — 원본 라벨: '$label'" >&2
          bad=1
          ;;
        *)
          names="$names
$alt"
          ;;
      esac
    done <<EOF_ALT
$(printf '%s' "$label" | tr '|' '\n')
EOF_ALT
  done <<EOF_LABELS
$label_lines
EOF_LABELS

  [ "$bad" -eq 0 ] || return 92
  printf '%s\n' "$names" | grep -v '^$' | sort -u
}

# ── (3) 캡처 판독 ────────────────────────────────────────────────────────────
# $1 = call 디렉토리. argv를 줄 단위로 emit (인자에 개행이 있으면 그 줄만 깨지는데,
# 우리가 재는 것은 플래그와 sentinel 부재라 영향이 없다).
obs_argv() {
  local a
  while IFS= read -r -d '' a; do printf '%s\n' "$a"; done < "$1/argv"
}

# $1 = capture 디렉토리 → 기록된 호출 수
obs_call_count() {
  local n=0 d
  for d in "$1"/call-*; do [ -d "$d" ] && n=$((n + 1)); done
  printf '%s\n' "$n"
}
