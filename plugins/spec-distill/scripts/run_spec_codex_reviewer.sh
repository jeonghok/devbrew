#!/usr/bin/env bash
# run_spec_codex_reviewer.sh — independent codex review of a DESIGN DOC.
# spec-distill design §6 #3. Unlike qg's run_codex_reviewer.sh, this NEVER
# performs script-internal spec/AC auto-discovery (C3: the reviewed doc lives
# under docs/superpowers/specs/, so AC auto-injection would feed the doc its
# own content — a circular footgun). Grep-checked absence: this file must never
# reference the qg spec-lookup helper by name.
#
# Usage:  run_spec_codex_reviewer.sh <doc_path> <project_dir> <output_yaml_path>
#
# Emits YAML (codex_findings_to_yaml.py schema) to <output_yaml_path>.
# Sandbox: codex exec -s read-only (Layer 3) — codex cannot write the tree.

set -euo pipefail

DOC_PATH="${1:-}"
PROJECT_DIR="${2:-}"
OUTPUT_PATH="${3:-}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "usage: run_spec_codex_reviewer.sh <doc_path> <project_dir> <output_yaml_path>" >&2
  exit 2
fi

# Absolutize relative DOC_PATH/OUTPUT_PATH against the invocation cwd BEFORE
# any `cd "$PROJECT_DIR"` below — otherwise a relative path silently resolves
# against project_dir instead (wrong-location write / spurious prompt_build_failed).
[[ "$OUTPUT_PATH" = /* ]] || OUTPUT_PATH="$PWD/$OUTPUT_PATH"
[[ "$DOC_PATH" = /* ]] || DOC_PATH="$PWD/$DOC_PATH"

if [[ -z "$PROJECT_DIR" ]]; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: missing_project_dir' >> "$OUTPUT_PATH"
  exit 0
fi
cd "$PROJECT_DIR" || {
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: project_dir_unreachable' >> "$OUTPUT_PATH"
  exit 0
}

# C7: guard scratch-dir assignment BEFORE any trap arms (cd "" repo-delete footgun).
SCRATCH="$(mktemp -d -t sd-codex-rev-XXXXXX)" || {
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: scratch_dir_uncreatable' >> "$OUTPUT_PATH"
  exit 0
}
trap 'rm -rf "$SCRATCH"' EXIT
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# Build the design-doc prompt (path-only input — no spec/AC auto-discovery, C3).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_spec_codex_prompt.py" \
       "$DOC_PATH" > "$PROMPT_FILE"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: prompt_build_failed' >> "$OUTPUT_PATH"
  exit 0
fi

# Canonical codex invocation (load-bearing flags preserved):
#   -s read-only  : Layer 3 sandbox (writes blocked)   | --json : JSONL stream
#   -C            : working-dir pin                     | </dev/null : stdin detach
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

# Guarded like the build_spec_codex_prompt.py call above: under `set -e` this
# final pipeline is otherwise unguarded — a python3/write failure here would
# abort the script non-zero with NO fallback YAML, breaking the
# always-exit-0/always-writes-YAML contract.
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py" \
       --stderr-file "$STDERR_FILE" \
       --meta-override-exit-code "$EXIT_CODE" \
       --meta-override-reason "$OVERRIDE_REASON" \
       < "$STDOUT_FILE" > "$OUTPUT_PATH"; then
  echo 'findings: []' > "$OUTPUT_PATH"
  echo 'meta:' >> "$OUTPUT_PATH"; echo '  codex_failed: true' >> "$OUTPUT_PATH"
  echo '  reason: yaml_conversion_failed' >> "$OUTPUT_PATH"
  exit 0
fi
