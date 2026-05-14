#!/usr/bin/env bash
# detect_codex.sh — emit YAML manifest describing Codex CLI availability.
# Spec AC1. Read-only, exit 0 always (graceful degradation).

set -u

emit_skip() {
  printf 'codex_available: false\n'
  printf 'skip_reason: %s\n' "$1"
}

# 1. Kill switch (highest priority — explicit user opt-out)
if [[ "${DEVBREW_DISABLE_QG_CODEX:-0}" == "1" ]]; then
  emit_skip 'kill_switch'
  exit 0
fi

# 2. Recursion guard: already inside a Codex sandbox
if [[ -n "${CODEX_SANDBOX:-}" || -n "${CODEX_SESSION_ID:-}" ]]; then
  emit_skip 'inside_codex_sandbox'
  exit 0
fi

# 3. Install check
CODEX_PATH="$(command -v codex 2>/dev/null || true)"
if [[ -z "$CODEX_PATH" || "$CODEX_PATH" != /* ]]; then
  emit_skip 'not_installed'
  exit 0
fi

# 4. Auth check
if [[ -z "${CODEX_API_KEY:-}" && -z "${OPENAI_API_KEY:-}" && ! -f "${HOME:-/nonexistent}/.codex/auth.json" ]]; then
  emit_skip 'auth_missing'
  exit 0
fi

# 5. Timeout binary check (required to prevent pipeline freeze on hung version probe)
TIMEOUT_BIN=$(command -v gtimeout 2>/dev/null || command -v timeout 2>/dev/null)
if [ -z "$TIMEOUT_BIN" ]; then
  cat <<YAML
codex_available: false
codex_path: ""
codex_version: ""
skip_reason: timeout_binary_missing
YAML
  exit 0
fi

# 6. Version check (known-bad regex from gstack: 0.120.0/1/2 stdin deadlock)
CODEX_VERSION="$("$TIMEOUT_BIN" 5 codex --version 2>/dev/null | head -1 || echo unknown)"
if echo "$CODEX_VERSION" | grep -Eq '(^|[^0-9.])0\.120\.(0|1|2)([^0-9.]|$)'; then
  printf 'codex_available: false\n'
  printf 'skip_reason: known_bad_version\n'
  printf 'detected_version: %s\n' "$CODEX_VERSION"
  exit 0
fi

# 7. All checks pass
printf 'codex_available: true\n'
printf 'codex_path: %s\n' "$CODEX_PATH"
printf 'codex_version: %s\n' "$CODEX_VERSION"
exit 0
