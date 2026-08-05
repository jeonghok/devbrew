#!/usr/bin/env bash
# run_artifact_codex_reviewer.sh — independent codex artifact-review subprocess.
# Mirrors run_codex_reviewer.sh: build prompt (file-path only) -> codex exec
# -s read-only --json < /dev/null -> extract fenced findings YAML. Any failure
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
EXIT_CODE=0
codex exec "$(cat "$PROMPT")" \
    -C "$PROJECT_DIR" \
    -s read-only \
    --json \
    < /dev/null \
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
