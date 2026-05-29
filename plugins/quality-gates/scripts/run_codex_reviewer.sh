#!/usr/bin/env bash
# run_codex_reviewer.sh — independent codex review subprocess (T3-3 refactor).
# Replaces agent dispatch (agents/codex-reviewer.md) with a script invocation.
# Layer 1 isolation (was: frontmatter disallowedTools) is now provided by
# SKILL.md narrow Bash allowlist (this script path only).
# Layer 2 (narrow Bash allowlist on script-internal commands) and Layer 3
# (codex exec -s read-only OS-level sandbox) are preserved.
#
# Usage:
#   run_codex_reviewer.sh <diff_path> <project_dir> <output_yaml_path>
#
# Optional env:
#   PLAN_SUMMARY_FILE — path to YAML file with an optional plan summary
#                       (omit for empty plan context; Gate 1 verifier removed
#                       in v2.0.0, so callers normally leave this unset).
#
# Emits: YAML to <output_yaml_path>. Schema:
#   agent: codex-reviewer
#   findings: [...]
#   meta:
#     codex_failed: bool
#     exit_code: int
#     reason: str
#
# Sandbox guarantees: codex exec -s read-only (Layer 3) — codex subprocess
# cannot write to the working tree even though the script invokes it.

set -euo pipefail

DIFF_PATH="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [[ -z "$PROJECT_DIR" ]]; then
  echo '{"codex_failed": true, "reason": "missing_project_dir"}' > "$OUTPUT_PATH"
  exit 0
fi
cd "$PROJECT_DIR" || {
  echo '{"codex_failed": true, "reason": "project_dir_unreachable"}' > "$OUTPUT_PATH"
  exit 0
}

SCRATCH="$(mktemp -d -t qg-codex-rev-XXXXXX)"
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# Build prompt (plan summary from caller-passed file, or empty).
PLAN_SUMMARY="${PLAN_SUMMARY_FILE:-/dev/null}"
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py" \
       "$DIFF_PATH" "$PLAN_SUMMARY" > "$PROMPT_FILE"; then
  echo '{"codex_failed": true, "reason": "prompt_build_failed"}' > "$OUTPUT_PATH"
  exit 0
fi

# Canonical codex invocation (spec §4.3 — load-bearing flags preserved):
#   -s read-only     : Layer 3 sandbox (file-system writes blocked)
#   -C "$PROJECT_DIR": working directory pin (single pipeline coordinate)
#   --json           : JSONL stream output
#   < /dev/null      : detach stdin (prevents stdin deadlock on some codex versions)
# Direct codex invocation — no per-call timeout (hang risk accepted; backstops:
# Bash tool timeout, DEVBREW_DISABLE_QG_CODEX=1, /cancel-qg). Layer 3 sandbox
# (-s read-only) preserved. `|| EXIT_CODE=$?` keeps capture safe under set -e.
EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
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

python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py" \
    --stderr-file "$STDERR_FILE" \
    --meta-override-exit-code "$EXIT_CODE" \
    --meta-override-reason "$OVERRIDE_REASON" \
    < "$STDOUT_FILE" > "$OUTPUT_PATH"
