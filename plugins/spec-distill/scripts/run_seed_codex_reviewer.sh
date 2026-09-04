#!/usr/bin/env bash
# run_seed_codex_reviewer.sh — independent codex SUPPRESSION review of an
# interview-seed DRAFT (Phase 0, request-framing). Not code, not a brief, not a
# design doc — the third of this shape (형제: run_brief_codex_reviewer.sh ·
# run_spec_codex_reviewer.sh). codex 호출은 이 파일 1곳이고 축은 인자다.
#
# **처분** — consumer=orchestrator · fail-open · disclosure=framing_degradations
#
# fail-open 인 이유: 이 축엔 병합기가 없다("병합기가 없고 판정도 없습니다") —
# framing-requests/SKILL.md 의 codex-gate 블록 자신이 `$CODEX_YAML`을 유일하게
# 읽어 `codex_status`를 echo 하고 격리 critic의 findings와 나란히 보여준다(consumer
# 는 그 블록을 실행하는 오케스트레이터). codex가 죽어도 격리 critic이 남는다 —
# 원장이 살아 있으면 `framing_degradations`에 공시할 뿐 이 축을 막지 않는다.
#
# Usage:  run_seed_codex_reviewer.sh <axis: suppression> <payload> <project_dir> <out_yaml>
#
# 계약(형제와 동일 — census #24·#125): 정상·실패 어느 경로에서도 exit 0 이고
# <out_yaml>에 codex_findings_to_yaml.py 스키마 YAML을 쓴다 — 소비자가 파일 부재를
# fail-closed로 읽으므로, 어떤 실패 경로에서도 YAML을 남긴다.
#
# **예외 하나 — exit 3**: out_yaml 자체를 쓸 수 없으면(디렉토리 부재·권한·RO 마운트)
# YAML을 남길 수 없다. 그때는 stderr에 loud하게 알리고 exit 3으로 죽는다. 호출자는
# 3을 보면 **out_yaml을 지워야 한다** — 직전 라운드 산출물이 남아 있으면 그것이 이번
# 라운드의 codex 판정으로 읽힌다.
#
# axis는 지금 "suppression" 하나뿐이지만 인자로 받는다 — 형제와 같은 관용구를
# 유지해, 축이 늘어도 이 파일의 흐름은 그대로 두고 case 분기와 checklist 파일 하나만
# 추가하면 되게 한다. **주의**: 이 "축"은 checklist 내부의 네 항목(근거 없는 제약 ·
# 예시 오인 · 조기 폐쇄 · 에이전트 추론)과 다른 개념이다 — 저 넷은 한 axis 값
# ("suppression") 안에서 함께 검사되는 항목이지, case 분기가 아니다(§7.2 — AXES 라는
# 이름이 이 플러그인에 세 곳 있고 뜻이 다르다는 경고 그대로).
#
# **웹 검색은 켜지 않는다 — 형제와의 의도적 차이.** 억제 checklist 네 항목은 초안을
# 원문 · 레포 CLAUDE.md 하나와만 대조한다 — direction/spec 리뷰와 달리 외부 prior-art
# 대조가 필요 없다. 그래서 DEVBREW_SPEC_DISTILL_DISABLE_WEB 을 여기서 확인하지
# 않는다 — 끌 것이 애초에 없다(AC21 표에는 "off"로 등재).
#
# kill switch: DEVBREW_SPEC_DISTILL_DISABLE_CODEX 는 여기서 보지 않는다 — 게이트는
# **호출자** 책임이다(형제와 같은 규약). 이 파일을 새 자리에서 부르는 쪽은 그 자리에
# 게이트를 함께 세워야 한다.

set -euo pipefail

AXIS="${1:-}"
PAYLOAD="${2:-}"
PROJECT_DIR="${3:-}"
OUTPUT_PATH="${4:-}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_seed_codex_reviewer.sh <suppression> <payload> <project_dir> <out_yaml>" >&2
  exit 2
fi

# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석돼 엉뚱한 위치에 쓴다(형제와 같은 이유).
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$PAYLOAD" = /* ]] || PAYLOAD="$PWD/$PAYLOAD"

# `write_failclosed` · `_degrade_if_empty` 는 형제 러너와 공유하는 정본이다(census
# #24·#125, `shared/codex/runner_common.sh`). 정본은 경로를 인자로 받는다.
#
# source를 가드한다 — `set -e` 아래에서 source가 실패하면 아래 seed_failclosed에
# 닿기 전에 죽어 OUTPUT_PATH가 손도 안 닿은 채 직전 라운드 YAML이 그대로 남는다.
# shellcheck source=/dev/null
_RUNNER_COMMON="$(dirname -- "${BASH_SOURCE[0]}")/runner_common.sh"
# `[ -r ]` + `bash -n`을 source 앞에 둔다 — 파일 부재는 bash 3.2.57이 `.`(POSIX
# special builtin)에서 `if !` 밖에서도 셸을 즉시 종료시키고, 문법이 깨진 파일은
# source하는 순간 rc=2로 죽는다. 둘 다 평범한 if로는 못 잡아 미리 갈라 확인한다.
if [ -r "$_RUNNER_COMMON" ] && bash -n "$_RUNNER_COMMON" 2>/dev/null \
   && . "$_RUNNER_COMMON"; then
  :
else
  printf 'findings: []\nmeta:\n  codex_failed: true\n  reason: runner_common_unloadable\n  exit_code: 0\n' \
    > "$OUTPUT_PATH" 2>/dev/null || {
      echo "[spec-distill] runner_common.sh 로드 실패 + 산출물 기록 실패 — 호출자는 stale 을 지워야 한다" >&2
      exit 3
    }
  echo "[spec-distill] runner_common.sh 를 로드할 수 없다 — degrade 기록 후 종료(공유 정본 미배포)" >&2
  exit 0
fi

emit_fallback() {                      # $1 = reason
  write_failclosed "$OUTPUT_PATH" "$1" || exit 3
  exit 0
}

# 선-기록(seed) — OUTPUT_PATH를 여기서 fail-closed 산출물로 먼저 덮어쓴다. 없으면
# 아래 조기 exit들이나 SIGKILL/OOM이 OUTPUT_PATH를 손대지 않은 채 끝나 직전 라운드의
# 양성 YAML이 그대로 이번 판정으로 읽힌다(형제와 같은 이유).
seed_failclosed() { write_failclosed "$OUTPUT_PATH" "runner_incomplete" || exit 3; }
seed_failclosed

case "$AXIS" in
  suppression) ;;
  *) echo "axis must be 'suppression' (got: '$AXIS')" >&2; exit 2 ;;
esac

[[ -f "$PAYLOAD" ]] || emit_fallback payload_missing
[[ -n "$PROJECT_DIR" ]] || emit_fallback missing_project_dir
cd "$PROJECT_DIR" || emit_fallback project_dir_unreachable

# C7: trap 무장 *전에* scratch 대입을 가드한다(빈 문자열 → `rm -rf ""` footgun).
SCRATCH="$(mktemp -d -t sd-seed-codex-XXXXXX)" || emit_fallback scratch_dir_uncreatable

# 종단 빈-출력 backstop — seed_failclosed()가 진입 시 stale은 이미 치우지만, 아래
# 종단 추출(codex_findings_to_yaml.py) 호출의 `> "$OUTPUT_PATH"` 리다이렉트가 그
# seed까지 다시 비운다. 추출기가 exit 0인데 아무것도 안 쓰면 그 실패를 잡는 `if !`가
# 발동하지 않아 0바이트 산출물이 남는다 — 형제와 동일한 최종 backstop을 둔다.
trap 'rm -rf "$SCRATCH"; _degrade_if_empty "$OUTPUT_PATH" aborted_before_completion' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

if ! python3 "$PLUGIN_ROOT/scripts/build_seed_codex_prompt.py" \
       --axis "$AXIS" "$PAYLOAD" > "$PROMPT_FILE"; then
  emit_fallback prompt_build_failed
fi

command -v codex >/dev/null 2>&1 || emit_fallback codex_not_installed

# 추론 강도(`model_reasoning_effort`)는 핀하지 않는다 — 형제와 같은 이유. 사용자
# codex 설정이 지배한다; 하니스가 임의로 하향시키면 이 co-reviewer의 존재 이유
# (별-모델 적발력)를 정확히 깎는다.
#
# 웹은 항상 끈다(헤더 참고) — 억제 축은 원문·CLAUDE.md 대조뿐이라 prior-art 검색이
# 필요 없다. 값은 리터럴이다 — kill switch로 완화할 대상이 애초에 없다.
WEB_ARGS=(-c 'tools.web_search=false' -c 'web_search="disabled"')

EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    "${WEB_ARGS[@]}" \
    --json \
    < "$PROMPT_FILE" \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

# override_reason 유도 + codex_findings_to_yaml.py 호출은 정본화됐다
# (`codex_extract_or_fallback`, runner_common.sh) — 형제 run_brief_codex_reviewer.sh 와
# 이 tail 을 바이트-동일하게 썼을 때 test_no_new_duplication.sh 의 20줄 창에 걸려서
# 여기로 올라갔다(Task 14). set -e 하에서 이 호출이 실패하면 fallback YAML 없이
# 죽으므로 가드한다.
codex_extract_or_fallback "$STDOUT_FILE" "$STDERR_FILE" "$EXIT_CODE" "$OUTPUT_PATH" \
    design "$PLUGIN_ROOT" || emit_fallback yaml_conversion_failed
