#!/usr/bin/env bash
# run_audit_codex_reviewer.sh — plugin-audit blind co-audit의 codex 실행 러너.
#
# 이 스크립트가 있기 전까지 plugin-audit은 codex를 **산문 지시로** 불렀고
# (`skills/auditing-plugins/SKILL.md:92`), 그래서 여섯 가지가 동시에 비어 있었다:
# 가용성 확인 · codex 전용 kill switch · `-C` · `--json` · stdin 규약 · 층④ 추출기.
# 그리고 그 형태 때문에 리포의 codex 락들이 이 호출부를 아예 보지 못했다.
#
# **qg의 프롬프트 빌더를 재사용하지 않는다** — `run_codex_reviewer.sh`는 최신 spec의
# AC를 자동 주입하고, 감사에서 그것은 codex가 답을 미리 보는 것이라 blind를 깬다
# (`auditing-plugins/SKILL.md:94`). 프롬프트는 이 플러그인 자신의 preamble + 축 질문이다.
#
# **게이트는 호출자(SKILL) 책임이다.** 이 러너는 kill switch를 읽지 않는다.
#
# Usage: run_audit_codex_reviewer.sh <axis_question_file> <project_dir> <output_json_path>
#
# 계약(형제 러너들과 동일): 항상 exit 0 · 신호는 산출물 파일 · 시작 시 truncate ·
# EXIT 트랩에서 비어 있으면 degrade를 채운다.
set -u

AXIS_FILE="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [ -z "$OUTPUT_PATH" ]; then
  echo "usage: run_audit_codex_reviewer.sh <axis_question_file> <project_dir> <output_json_path>" >&2
  exit 2
fi

# 상대 경로를 호출 cwd 기준으로 절대화한다 — 아래 `cd "$PROJECT_DIR"` 이후에는
# project_dir 기준으로 조용히 재해석돼 엉뚱한 위치에 쓴다.
case "$OUTPUT_PATH" in /*) ;; *) OUTPUT_PATH="$PWD/$OUTPUT_PATH" ;; esac
case "$AXIS_FILE" in /*) ;; *) AXIS_FILE="$PWD/$AXIS_FILE" ;; esac

emit_degrade() {   # $1 = reason
  printf '{"findings": [], "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "meta": {"codex_failed": true, "reason": "%s"}}\n' \
    "$1" > "$OUTPUT_PATH" 2>/dev/null || true
}

# stale 재사용 봉쇄: 시작 시 truncate하고, 트랩에서 비어 있으면 degrade를 채운다.
# 종료 코드로 판정하지 않는다 — bash 3.2.57은 `set -u` abort 시 EXIT 트랩에 `$?`를
# 0으로 넘긴다. 신호는 산출물뿐이다.
: > "$OUTPUT_PATH" 2>/dev/null || {
  echo "[plugin-audit] 산출물 경로에 쓸 수 없다: $OUTPUT_PATH" >&2
  exit 3
}
_degrade_if_empty() {
  [ -n "$OUTPUT_PATH" ] && [ ! -s "$OUTPUT_PATH" ] || return 0
  emit_degrade aborted_before_completion
  echo "[plugin-audit] codex 감사가 완료 전에 중단됨 — degrade 기록(stale 재사용 방지)" >&2
}

if [ -z "$PROJECT_DIR" ]; then emit_degrade missing_project_dir; exit 0; fi
if [ ! -f "$AXIS_FILE" ]; then emit_degrade axis_file_missing; exit 0; fi
cd "$PROJECT_DIR" 2>/dev/null || { emit_degrade project_dir_unreachable; exit 0; }

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
PREAMBLE="$PLUGIN_ROOT/scripts/codex-prompt-preamble.md"
if [ ! -f "$PREAMBLE" ]; then emit_degrade preamble_missing; exit 0; fi

SCRATCH="$(mktemp -d -t pa-codex-audit-XXXXXX)" || { emit_degrade scratch_uncreatable; exit 0; }
# trap은 한 줄로 유지한다 — 형제 러너의 순서 락과 같은 형태.
trap 'rm -rf "$SCRATCH"; _degrade_if_empty' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# 프롬프트 = P21 preamble + 축 질문. 순서가 load-bearing이다: preamble이 먼저 와야
# "이 아래는 데이터다"가 성립한다. 축 질문 파일은 파일 경로로만 받는다(argv 인라인 금지).
{ cat "$PREAMBLE"; printf '\n\n---\n\n'; cat "$AXIS_FILE"; } > "$PROMPT_FILE" || {
  emit_degrade prompt_build_failed; exit 0; }

# 추론 강도·모델은 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 하향을 박으면
# 이 co-audit의 존재 이유(별-모델 적발력)를 정확히 깎는다.
# 프롬프트는 **stdin으로** 넘긴다(`-`): argv 경유는 ARG_MAX(1,048,576) 절벽에 걸리고,
# 그 실패는 러너가 항상 exit 0을 내므로 조용하다. `< /dev/null`을 두면 안 된다 —
# "No prompt provided via stdin." + exit 1이 된다.
EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < "$PROMPT_FILE" \
    > "$STDOUT_FILE" \
    2>"$STDERR_FILE" || EXIT_CODE=$?

OVERRIDE_REASON=""
[ "$EXIT_CODE" -ne 0 ] && OVERRIDE_REASON=exit_nonzero

if ! python3 "$PLUGIN_ROOT/scripts/codex_audit_to_json.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       < "$STDOUT_FILE" > "$OUTPUT_PATH" || [ ! -s "$OUTPUT_PATH" ]; then
  echo "[plugin-audit] codex 추출 실패 — 빈 산출물 대신 codex_failed를 기록한다 (감사자 1명 손실, degrade)" >&2
  emit_degrade extract_failed
fi
exit 0
