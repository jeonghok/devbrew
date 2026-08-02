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
#   SPEC_AC_FILE — explicit path to a file containing the spec's Acceptance
#                  Criteria section (escape hatch; normally unset). When unset,
#                  the spec is resolved script-internally via discover-spec.sh
#                  and its AC section is extracted. When no spec exists, the
#                  <spec_context> slot is left empty (v2.0.0 behavior).
#   DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 — force the no-spec path even when a
#                  spec exists (empty <spec_context>; loud log emitted).
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

SCRATCH="$(mktemp -d -t qg-codex-rev-XXXXXX)" || {
  echo '{"codex_failed": true, "reason": "scratch_dir_uncreatable"}' > "$OUTPUT_PATH"
  exit 0
}
PROMPT_FILE="$SCRATCH/prompt.md"
STDOUT_FILE="$SCRATCH/codex.jsonl"
STDERR_FILE="$SCRATCH/codex.stderr"

# --- Spec AC resolution (v2.1.0: codex review is spec-aware) ----------------
# The spec is the AC truth. Inject only the spec's Acceptance Criteria SECTION
# (not the whole spec — prompt-bloat mitigation, spec R3) into <spec_context>.
# Resolution is script-internal: invocation parity with discover-plan.sh means
# the SKILL allowed-tools list is NOT touched. Graceful + LOUD on every branch.
SPEC_AC="/dev/null"
if [[ "${DEVBREW_QG_DISABLE_SPEC_CONFORMANCE:-}" == "1" ]]; then
  echo "[quality-gates] codex spec context: DISABLED via DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 — empty <spec_context>." >&2
elif [[ -n "${SPEC_AC_FILE:-}" && -f "${SPEC_AC_FILE}" ]]; then
  SPEC_AC="$SPEC_AC_FILE"
  echo "[quality-gates] codex spec context: using explicit SPEC_AC_FILE=$SPEC_AC_FILE" >&2
else
  SPEC_JSON="$(bash "${CLAUDE_PLUGIN_ROOT}/scripts/discover-spec.sh" 2>/dev/null || true)"
  if [[ -z "$SPEC_JSON" ]]; then
    echo "[quality-gates] codex spec context: discover-spec.sh produced no output (script missing or crashed? check CLAUDE_PLUGIN_ROOT) — empty <spec_context>." >&2
  else
    SPEC_PATH="$(printf '%s' "$SPEC_JSON" | sed -n 's/.*"spec_path":"\([^"]*\)".*/\1/p')"
    if [[ -n "$SPEC_PATH" && -f "$SPEC_PATH" ]]; then
      # Extract only the spec's Acceptance Criteria SECTION: start at the AC
      # header (ANY depth — matches discover-spec.sh's ^#+ eligibility), record
      # its depth, and stop at the next header of the SAME-OR-SHALLOWER depth.
      # Deeper subsections (e.g. #### under a ### AC) stay in; sibling/parent
      # sections do not bleed in. A real '# '-style header is required, so a
      # prose line merely containing the phrase does not start extraction.
      awk '/^#+ /{h=$0;sub(/[^#].*/,"",h);d=length(h);if(!inac&&$0~/[Aa]cceptance [Cc]riteria/){inac=1;acd=d;print;next}if(inac&&d<=acd)exit} inac' "$SPEC_PATH" > "$SCRATCH/spec_ac.md"
      if [[ -s "$SCRATCH/spec_ac.md" ]]; then
        SPEC_AC="$SCRATCH/spec_ac.md"
        echo "[quality-gates] codex spec context: injected Acceptance Criteria from $SPEC_PATH" >&2
      else
        echo "[quality-gates] codex spec context: AC section empty after extraction from $SPEC_PATH — empty <spec_context>." >&2
      fi
    else
      echo "[quality-gates] codex spec context: no project spec found (searched docs/superpowers/specs/) — empty <spec_context>, v2.0.0 behavior." >&2
    fi
  fi
fi

# Build prompt (spec AC from resolution above, or empty when /dev/null).
if ! python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py" \
       "$DIFF_PATH" "$SPEC_AC" > "$PROMPT_FILE"; then
  echo '{"codex_failed": true, "reason": "prompt_build_failed"}' > "$OUTPUT_PATH"
  exit 0
fi

# Canonical codex invocation (spec §4.3 — load-bearing flags preserved):
#   -s read-only     : Layer 3 sandbox (file-system writes blocked)
#   -C "$PROJECT_DIR": working directory pin (single pipeline coordinate)
#   --json           : JSONL stream output
#   < /dev/null      : detach stdin (prevents stdin deadlock on some codex versions)
#
# 추론 강도(`model_reasoning_effort`)는 핀하지 않는다 — 사용자 codex 설정이 지배한다.
# 하니스가 "medium"을 박으면 high/xhigh로 설정한 사용자가 조용히 하향되고, 그 하향은
# 이 co-reviewer의 유일한 존재 이유(별-모델 적발력)를 정확히 깎는다. 바닥값이
# 필요하다는 판단이 서면 그때 명시적으로 문서화해서 넣는다.
# (`run_brief_codex_reviewer.sh`가 이미 쓰던 계약을 전파한 것이다.)
#
# Direct codex invocation — no per-call timeout (hang risk accepted; backstops:
# Bash tool timeout, DEVBREW_DISABLE_QG_CODEX=1, /cancel-qg). Layer 3 sandbox
# (-s read-only) preserved. `|| EXIT_CODE=$?` keeps capture safe under set -e.
EXIT_CODE=0
codex exec "$(cat "$PROMPT_FILE")" \
    -C "$PROJECT_DIR" \
    -s read-only \
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
