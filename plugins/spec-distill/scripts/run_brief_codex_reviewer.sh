#!/usr/bin/env bash
# run_brief_codex_reviewer.sh — independent codex review of an interview BRIEF.
# spec-distill Spec B §5.7 · AC6 · AC20. codex 호출은 **이 파일 1곳**이고 축은 인자다
# (축별 복제 = 플래그·샌드박스·에러 처리 중복 → 한쪽만 고치는 drift).
#
# Usage:  run_brief_codex_reviewer.sh <axis: direction|fidelity> <payload> <project_dir> <out_yaml>
#
# 계약(기존 run_spec_codex_reviewer.sh와 동일): **항상 exit 0** 이고 **항상 <out_yaml>에
# codex_findings_to_yaml.py 스키마 YAML을 쓴다.** 병합(merge_brief_review.py)이 파일 부재를
# codex_yaml_missing → fail-closed로 읽으므로, 어떤 실패 경로에서도 YAML을 남긴다.
#
# §11 ⑪ 반복 금지: CLAUDE_PLUGIN_ROOT를 fallback 없이 참조하면 set -u 하에서 훅이 env를
# 주지 않는 컨텍스트(스킬 수동 호출)에서 즉사한다. 여기서는 스크립트 위치로 유도한다.

set -euo pipefail

AXIS="${1:-}"
PAYLOAD="${2:-}"
PROJECT_DIR="${3:-}"
OUTPUT_PATH="${4:-}"

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_brief_codex_reviewer.sh <direction|fidelity> <payload> <project_dir> <out_yaml>" >&2
  exit 2
fi

# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석돼 엉뚱한 위치에 쓴다.
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$PAYLOAD" = /* ]] || PAYLOAD="$PWD/$PAYLOAD"

emit_fallback() {                      # $1 = reason
  {
    echo 'findings: []'
    echo 'meta:'
    echo '  codex_failed: true'
    echo "  reason: $1"
  } > "$OUTPUT_PATH"
  exit 0
}

case "$AXIS" in
  direction|fidelity) ;;
  *) echo "axis must be 'direction' or 'fidelity' (got: '$AXIS')" >&2; exit 2 ;;
esac

[[ -f "$PAYLOAD" ]] || emit_fallback payload_missing
[[ -n "$PROJECT_DIR" ]] || emit_fallback missing_project_dir
cd "$PROJECT_DIR" || emit_fallback project_dir_unreachable

# C7: trap 무장 *전에* scratch 대입을 가드한다 (빈 문자열 → `rm -rf ""` footgun).
SCRATCH="$(mktemp -d -t sd-brief-codex-XXXXXX)" || emit_fallback scratch_dir_uncreatable
trap 'rm -rf "$SCRATCH"' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

if ! python3 "$PLUGIN_ROOT/scripts/build_brief_codex_prompt.py" \
       --axis "$AXIS" "$PAYLOAD" > "$PROMPT_FILE"; then
  emit_fallback prompt_build_failed
fi

command -v codex >/dev/null 2>&1 || emit_fallback codex_not_installed

# 웹 검색: 사용자 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1)만 끈다. 그 밖에는
# 명시적으로 켠다 — `--search`는 TUI 전용이고 `codex exec` 경로는 이 config다.
# 검색 *횟수* 상한은 두지 않는다 (E10: 단일 exec은 이미 턴으로 경계가 있다).
WEB_ARGS=(-c 'tools.web_search=true')
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=false')
fi

EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    "${WEB_ARGS[@]}" \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

if [[ $EXIT_CODE -ne 0 ]]; then
  OVERRIDE_REASON=exit_nonzero
else
  OVERRIDE_REASON=""
fi

# set -e 하에서 이 마지막 파이프라인이 실패하면 fallback YAML 없이 죽는다 — 가드한다.
if ! python3 "$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       < "$STDOUT_FILE" > "$OUTPUT_PATH"; then
  emit_fallback yaml_conversion_failed
fi
