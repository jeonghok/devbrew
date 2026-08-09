#!/usr/bin/env bash
# run_artifact_codex_reviewer.sh — independent codex artifact-review subprocess.
# Mirrors run_codex_reviewer.sh: build prompt (file-path only) -> codex exec -
# -s read-only --json < "$PROMPT" (stdin) -> extract fenced findings YAML. Any failure
# writes a `codex_failed: true` degrade meta to OUT (graceful, C7). No writes to
# the working tree (Layer-3 read-only sandbox).
#
# Usage: run_artifact_codex_reviewer.sh <artifact_path> <project_dir> <output_yaml_path>
set -u

ARTIFACT="${1:-}"
PROJECT_DIR="${2:-}"
OUT="${3:-}"

emit_fail() { # <reason>
  { printf 'codex_failed: true\n'; printf 'reason: %s\n' "$1"; } > "${OUT:-/dev/stdout}"
}

# ── stale 재사용 봉쇄 (Task 20b) ─────────────────────────────────────────────
# 형제 러너(run_codex_reviewer.sh)가 가진 계약이 이 러너에는 백포트되지 않았다.
# 아래의 명시적 emit_fail 분기들은 각자 자기 실패를 정확히 기록하지만, 그 분기
# *자체*에 도달하지 못하고 죽는 경로(예: `CLAUDE_PLUGIN_ROOT` 미설정으로 인한
# `set -u` abort — 30번째 줄의 가드 없는 참조)는 아무것도 잡지 못했다. 그 경로에서는
# 이전 라운드의 YAML이 **양성 `codex_failed: false` 표식과 함께 그대로** 남아
# 이번 라운드의 clean 판정으로 읽혔다(2026-08-09/10 컨트롤러 재현, exit 1 —
# indeterminate ≠ clean 위반. 부재가 아니라 stale이 이번 결과로 제시되는 형태).
# 종료 코드로 판정하지 않는다: 이 스크립트의 계약은 "항상 exit 0 + 항상 YAML"이고,
# bash 3.2.57은 `set -u` abort 시 EXIT 트랩에 `$?`를 0으로 넘긴다. 신호는
# 산출물뿐이다. 그래서 시작 시 truncate하고, 비어 있으면 degrade로 채운다.
[ -n "$OUT" ] && : > "$OUT"
_degrade_if_empty() {
  [ -n "$OUT" ] && [ ! -s "$OUT" ] || return 0
  emit_fail "aborted_before_completion"
  echo "[quality-gates] codex 아티팩트 리뷰가 완료 전에 중단됨 — degrade 기록(stale 재사용 방지)" >&2
}
trap '_degrade_if_empty' EXIT

if [ -z "$PROJECT_DIR" ] || [ -z "$OUT" ]; then
  emit_fail "missing_args"
  exit 0
fi
cd "$PROJECT_DIR" 2>/dev/null || { emit_fail "project_dir_unreachable"; exit 0; }

SCRATCH="$(mktemp -d -t qg-art-codex-XXXXXX)" || { emit_fail "scratch_uncreatable"; exit 0; }
PROMPT="$SCRATCH/prompt.md"
JSONL="$SCRATCH/codex.jsonl"
ERR="$SCRATCH/codex.stderr"

if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_artifact_codex_prompt.py" "$ARTIFACT" > "$PROMPT" 2>"$ERR"; then
  emit_fail "prompt_build_failed"
  exit 0
fi

# 추론 강도는 핀하지 않는다 — 사용자 codex 설정이 지배한다. 하니스가 medium을 박으면
# high/xhigh 사용자가 조용히 하향되고, 그 하향이 별-모델 적발력을 정확히 깎는다.
# 샌드박스(-s read-only)·작업디렉토리 핀(-C)·파싱 계약(--json)은 load-bearing이라 유지.
#
# 웹 posture를 **명시한다.** 미지정은 codex 기본값(`web_search = "cached"`)에 맡기는
# 것이라 "이 호출부는 웹을 쓰지 않는다"가 어디에도 적혀 있지 않게 된다. 산출물 비평은
# 외부 근거가 필요 없고, 외부 조회가 결과를 비결정적으로 만든다. kill switch가 없는
# 이유: 이미 OFF라 끌 것이 없다(죽은 스위치를 만들지 않는다, AC21).
EXIT_CODE=0
codex exec - \
    -C "$PROJECT_DIR" \
    -s read-only \
    -c 'tools.web_search=false' \
    -c 'web_search="disabled"' \
    --json \
    < "$PROMPT" \
    > "$JSONL" \
    2>"$ERR" || EXIT_CODE=$?

REASON=""
[ "$EXIT_CODE" -ne 0 ] && REASON=exit_nonzero

if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/extract_codex_artifact_yaml.py" \
    --meta-override-exit-code "$EXIT_CODE" \
    --meta-override-reason "$REASON" \
    < "$JSONL" > "$OUT" || [ ! -s "$OUT" ]; then
  # F-D: the terminal extract was the one step not guarded like the prompt build
  # (line 30). extract_codex_artifact_yaml.py normally exits 0 with either findings
  # or `codex_failed: true`, but an UNHANDLED crash (python3 unavailable, plugin-root
  # issue) truncates OUT to empty via `> "$OUT"`, which the SKILL would read as
  # codex-succeeded-with-no-findings -> a silently dropped reviewer (no C7 degrade,
  # no sources_failed++). Force codex_failed so the loss is loud + counted.
  emit_fail "extract_failed"
fi
exit 0
