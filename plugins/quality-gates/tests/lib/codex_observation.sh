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
obs_setup() {
  OBS_SCRATCH="$1"
  mkdir -p "$OBS_SCRATCH/bin"
  cp "$OBS_REPO/plugins/quality-gates/tests/mocks/capture-codex/codex" "$OBS_SCRATCH/bin/codex"
  chmod +x "$OBS_SCRATCH/bin/codex"
  # timeout/gtimeout이 없으면 detect가 timeout_binary_missing으로 막고 spike는 죽는다.
  cp "$OBS_REPO/plugins/quality-gates/tests/mocks/bin-stubs/"* "$OBS_SCRATCH/bin/" 2>/dev/null || true
  OBS_MOCKBIN="$OBS_SCRATCH/bin"
  # sentinel은 **입력 파일**에 심는다. 빌더가 그것을 프롬프트에 치환하므로,
  # sentinel이 stdin에 있으면 프롬프트가 stdin으로 갔다는 뜻이고 argv에 있으면
  # argv로 샜다는 뜻이다. 프롬프트 전문 대조보다 강하다 — `$(cat f)`가 후행 개행을
  # 삭제해도 sentinel은 온전하다.
  OBS_SENTINEL='CODEX_OBS_SENTINEL_7f3a9c2b'
}

# $1 = 후보 파일 경로, $2 = capture 디렉토리. 성공하면 0.
# **fail-closed**: 표에 없는 후보는 비-0을 내고 호출자가 RED로 만든다. 열거이지만
# 방향이 반대다 — 잊으면 조용히 skip되는 게 아니라 검사가 깨진다.
obs_invoke() {
  local cand="$1" capture="$2"
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
