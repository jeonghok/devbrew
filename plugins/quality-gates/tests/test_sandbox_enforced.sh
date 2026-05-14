#!/usr/bin/env bash
# AC4 — every codex exec invocation in codex-reviewer.md has -s read-only,
# -C "$<var>", and --json.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENT="$PLUGIN_ROOT/agents/codex-reviewer.md"
EXTRACTOR="$SCRIPT_DIR/lib/extract_codex_invocations.py"

[[ -f "$AGENT" ]] || { echo "FAIL: $AGENT missing"; exit 1; }
[[ -f "$EXTRACTOR" ]] || { echo "FAIL: $EXTRACTOR missing"; exit 1; }

invocations="$(python3 "$EXTRACTOR" "$AGENT")"
if [[ -z "$invocations" ]]; then
  echo "FAIL: no codex invocations found in $AGENT"
  exit 1
fi

offenders="$(echo "$invocations" | grep -v -E '(-s|--sandbox)[[:space:]]+read-only' || true)"
if [[ -n "$offenders" ]]; then
  echo "FAIL: codex invocations missing -s read-only:"
  echo "$offenders" | sed 's/^/  /'
  exit 1
fi

no_repo_root="$(echo "$invocations" | grep -v -E -- '-C[[:space:]]+\"\$' || true)"
if [[ -n "$no_repo_root" ]]; then
  echo "FAIL: codex invocations missing -C \"\$<var>\":"
  echo "$no_repo_root" | sed 's/^/  /'
  exit 1
fi

no_json="$(echo "$invocations" | grep -v -E -- '--json' || true)"
if [[ -n "$no_json" ]]; then
  echo "FAIL: codex invocations missing --json:"
  echo "$no_json" | sed 's/^/  /'
  exit 1
fi

echo "PASS: all $(echo "$invocations" | wc -l) codex invocations are sandboxed/pinned/json."
exit 0
