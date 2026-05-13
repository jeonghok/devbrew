#!/usr/bin/env bash
# Spike: verify codex emits fenced JSON >=2/3 times.

set -u
# Intentionally NOT `set -e` / `set -o pipefail`: the loop must continue through
# all 3 runs even if one codex invocation errors out. Failed runs are observed
# via exit-code logging + "no fenced JSON" outcome, not via shell aborting.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
PROMPT_FILE="$SCRIPT_DIR/spike_prompt.md"
OUT_DIR="$(mktemp -d -t qg-codex-spike-XXXXXX)"
trap 'rm -rf "$OUT_DIR"' EXIT

[[ -f "$PROMPT_FILE" ]] || { echo "Missing $PROMPT_FILE" >&2; exit 1; }

PROMPT="$(cat "$PROMPT_FILE")"
TIMEOUT_CMD="$(command -v gtimeout || command -v timeout)"
[[ -n "$TIMEOUT_CMD" ]] || { echo "Need gtimeout or timeout" >&2; exit 1; }
command -v python3 >/dev/null || { echo "Need python3 for JSONL parsing" >&2; exit 1; }

pass=0
total=3
first_pass_run=""  # track first passing run so we freeze the correct fixture
for i in 1 2 3; do
  echo "--- Run $i/$total ---"
  STDOUT_FILE="$OUT_DIR/run-$i.jsonl"
  STDERR_FILE="$OUT_DIR/run-$i.stderr"

  "$TIMEOUT_CMD" 600 codex exec "$PROMPT" \
    -C "$REPO_ROOT" \
    -s read-only \
    -c 'model_reasoning_effort="medium"' \
    --json \
    < /dev/null > "$STDOUT_FILE" 2>"$STDERR_FILE"

  echo "  exit: $?"
  echo "  stdout lines: $(wc -l < "$STDOUT_FILE")"
  echo "  stderr preview: $(head -1 "$STDERR_FILE")"

  # Codex 0.130.0 wraps agent_message inside item.completed events:
  #   {"type":"item.completed","item":{"type":"agent_message","text":"..."}}
  # Older shape (kept as fallback): {"type":"agent_message","text":"..."} or {"message":"..."}.
  last_msg="$(grep '"type":"agent_message"' "$STDOUT_FILE" | tail -1 \
              | python3 -c '
import sys, json
try:
    d = json.loads(sys.stdin.read())
except Exception:
    sys.exit(0)
item = d.get("item") if isinstance(d.get("item"), dict) else d
print(item.get("text", item.get("message", "")))
' 2>/dev/null || echo "")"

  # Use POSIX bracket class instead of \s — defensive against non-GNU grep.
  if echo "$last_msg" | grep -q '```json' && echo "$last_msg" | grep -qE '```[[:space:]]*$'; then
    echo "  fenced JSON detected"
    pass=$((pass + 1))
    [[ -z "$first_pass_run" ]] && first_pass_run="$i"
  else
    echo "  no fenced JSON"
    echo "  preview: $(echo "$last_msg" | head -c 200)"
  fi
done

echo ""
echo "Spike result: $pass/$total passed"
if [[ $pass -ge 2 ]]; then
  mkdir -p "$SCRIPT_DIR/fixtures"
  # Freeze the FIRST passing run (not blindly run-1), so a partial-pass scenario
  # (e.g., run-1 fails, runs 2-3 pass) still produces a valid ground-truth fixture.
  cp "$OUT_DIR/run-$first_pass_run.jsonl" "$SCRIPT_DIR/fixtures/codex_jsonl_sample.json"
  echo "Frozen run-$first_pass_run sample to $SCRIPT_DIR/fixtures/codex_jsonl_sample.json"
  exit 0
else
  echo "FAIL: spike threshold not met. Halt before Task 4." >&2
  exit 1
fi
