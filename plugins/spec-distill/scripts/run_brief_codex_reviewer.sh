#!/usr/bin/env bash
# run_brief_codex_reviewer.sh — independent codex review of an interview BRIEF.
# spec-distill Spec B §5.7 · AC6 · AC20. codex 호출은 **이 파일 1곳**이고 축은 인자다
# (축별 복제 = 플래그·샌드박스·에러 처리 중복 → 한쪽만 고치는 drift).
#
# Usage:  run_brief_codex_reviewer.sh <axis: direction|fidelity> <payload> <project_dir> <out_yaml>
#
# 계약: 정상·실패 어느 경로에서도 **exit 0** 이고 **<out_yaml>에 codex_findings_to_yaml.py
# 스키마 YAML을 쓴다.** 병합(merge_brief_review.py)이 파일 부재를 codex_yaml_missing →
# fail-closed로 읽으므로, 어떤 실패 경로에서도 YAML을 남긴다.
#
# **예외 하나 — exit 3**: out_yaml 자체를 쓸 수 없으면(디렉토리 부재·권한·RO 마운트) YAML을
# 남길 수 없다. 그때는 stderr에 loud하게 알리고 exit 3으로 죽는다. 호출자는 3을 보면
# **out_yaml을 지워야 한다** — 직전 라운드 산출물이 남아 있으면 그것이 이번 라운드의
# codex 판정으로 읽힌다(rc를 안 잡으면 정확히 그 사고가 난다).
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

write_failclosed() {                   # $1 = reason — 리다이렉트 실패를 삼키지 않는다
  {
    echo 'findings: []'
    echo 'meta:'
    echo '  codex_failed: true'
    echo "  reason: $1"
  } > "$OUTPUT_PATH" || {
    echo "[spec-distill] fail-closed YAML 기록 실패: $OUTPUT_PATH ($1)" >&2
    return 1
  }
}

emit_fallback() {                      # $1 = reason
  write_failclosed "$1" || exit 3
  exit 0
}

# **선-기록(seed).** OUTPUT_PATH를 여기서 fail-closed 산출물로 덮어쓴 뒤, 성공 경로가
# 마지막에 진짜 결과로 덮어쓰게 한다. 선-기록이 없으면 아래 조기 exit들과 SIGKILL·OOM이
# OUTPUT_PATH를 **손대지 않은 채** 끝나므로 직전 라운드의 YAML이 그대로 남고, 호출 SKILL이
# 러너의 exit code를 잡지 않으므로 merge가 그 stale clean YAML을 이번 라운드의 codex
# 판정으로 읽는다(codex_degraded: false → approved, 흔적 0). SKILL이 "라운드마다
# 덮어씁니다"라고 보장한 속성은 이 한 줄이 있어야 실제로 성립한다.
seed_failclosed() { write_failclosed "runner_incomplete" || exit 3; }
seed_failclosed

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

# 추론 강도(`model_reasoning_effort`)는 **핀하지 않는다.** 사용자 codex 설정이 지배한다.
# 하니스가 여기서 "medium"을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다 — 하니스는 능력을
# 억제하지 않는다. 바닥값이 필요하다는 판단이 서면 그때 명시적으로 문서화해서 넣는다.
#
# 웹 검색: 사용자 kill switch(DEVBREW_SPEC_DISTILL_DISABLE_WEB=1)만 끈다. 그 밖에는
# 명시적으로 켠다 — `--search`는 TUI 전용이고 `codex exec` 경로는 이 config다.
# 검색 *횟수* 상한은 두지 않는다 (E10: 단일 exec은 이미 턴으로 경계가 있다).
#
# `web_search="live"`: `tools.web_search=true` 단독은 codex 기본 모드(`cached`) —
# V1 probe(2026-08-09, 3번째 호출·컨트롤러 승인) 실측: 도구만 켜면 실제 존재하는
# llvm/llvm-project 커밋을 돌려주지만 12일 지연된 인덱스였다(진짜 검색이지만
# stale). `live`를 추가하자 같은 조회가 독립 측정한 timestamp와 일치하는 오늘
# HEAD를 돌려줬다. 이 checklist는 현재 prior-art 대조를 요구하므로 `live`가 필수다.
WEB_ARGS=(-c 'tools.web_search=true' -c 'web_search="live"')
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  WEB_ARGS=(-c 'tools.web_search=false' -c 'web_search="disabled"')
fi

EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    "${WEB_ARGS[@]}" \
    --json \
    < "$PROMPT_FILE" \
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
