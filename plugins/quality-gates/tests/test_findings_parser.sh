#!/usr/bin/env bash
# AC3 — parser fallback chain + stderr handling.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSER="$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py"
TMP="$(mktemp -d -t qg-parser-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0

check() {
  local name="$1" stdin_file="$2" stderr_file="$3" expected_grep="$4"
  if [[ -n "$stderr_file" ]]; then
    output="$(python3 "$PARSER" --stderr-file "$stderr_file" < "$stdin_file" 2>&1)"
  else
    output="$(python3 "$PARSER" < "$stdin_file" 2>&1)"
  fi
  if echo "$output" | grep -q "$expected_grep"; then
    echo "  PASS: $name"; pass=$((pass + 1))
  else
    echo "  FAIL: $name"; echo "    expected grep: $expected_grep"
    echo "$output" | sed 's/^/      /'
    fail=$((fail + 1))
  fi
}

# Fixture 1: fenced JSON in nested item.completed → agent_message (Codex 0.130+ shape, Stage 1 success)
cat > "$TMP/fenced.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"Here are findings:\n```json\n{\"findings\":[{\"file\":\"a.py\",\"line\":3,\"severity\":\"IMPORTANT\",\"confidence\":9,\"summary\":\"index access without bounds check\",\"proposed_fix\":\"catch IndexError\"}]}\n```"}}
EOF
check "fenced JSON (nested) Stage 1" "$TMP/fenced.jsonl" "" 'file: a.py'

# Fixture 1b: legacy top-level agent_message shape (must still be supported)
cat > "$TMP/fenced-legacy.jsonl" <<'EOF'
{"type":"agent_message","text":"```json\n{\"findings\":[{\"file\":\"a-legacy.py\",\"line\":1,\"severity\":\"SUGGESTION\",\"confidence\":5,\"summary\":\"legacy shape\",\"proposed_fix\":\"none\"}]}\n```"}
EOF
check "fenced JSON (legacy top-level) Stage 1" "$TMP/fenced-legacy.jsonl" "" 'file: a-legacy.py'

# Fixture 1c: real on-the-wire fixture from Task 0 spike (regression anchor for codex schema drift)
check "real codex sample (Task 0 fixture)" "$PLUGIN_ROOT/tests/spike/fixtures/codex_jsonl_sample.json" "" 'agent: codex-reviewer'

# Fixture 2: raw JSON inside nested item.completed (Stage 2 success — no fence)
cat > "$TMP/raw.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"{\"findings\":[{\"file\":\"b.py\",\"line\":5,\"severity\":\"IMPORTANT\",\"confidence\":7,\"summary\":\"null check missing\",\"proposed_fix\":\"add if b is None guard\"}]}"}}
EOF
check "raw JSON Stage 2" "$TMP/raw.jsonl" "" 'file: b.py'

# Fixture 3: malformed bytes (Stage 3 fallback)
printf '\x00\x01\x02notjson\xff' > "$TMP/bad.bin"
check "malformed Stage 3" "$TMP/bad.bin" "" 'reason: malformed_json'

# Fixture 4: missing agent_message
cat > "$TMP/missing.jsonl" <<'EOF'
{"type":"thought","text":"thinking"}
{"type":"tool_call","name":"read"}
EOF
check "missing agent_message" "$TMP/missing.jsonl" "" 'reason: missing_result'

# Fixture 5: auth error in stderr
: > "$TMP/empty.jsonl"
cat > "$TMP/auth-err.txt" <<'EOF'
Error: authentication failed: invalid API key
EOF
check "auth error in stderr" "$TMP/empty.jsonl" "$TMP/auth-err.txt" 'reason: auth_error_in_stderr'

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
