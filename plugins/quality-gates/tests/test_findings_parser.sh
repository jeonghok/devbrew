#!/usr/bin/env bash
# AC3 — parser fallback chain + stderr handling.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSER="$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py"
TMP="$(mktemp -d -t qg-parser-test-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

check() {
  local name="$1" stdin_file="$2" stderr_file="$3" expected_grep="$4"
  if [[ -n "$stderr_file" ]]; then
    output="$(python3 "$PARSER" --stderr-file "$stderr_file" < "$stdin_file" 2>&1)"
  else
    output="$(python3 "$PARSER" < "$stdin_file" 2>&1)"
  fi
  assert_grep "$output" "$expected_grep" "$name"
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

# Fixture 1d: fenced JSON WITHOUT trailing newline before closing backticks.
# Real LLM outputs frequently omit the trailing newline. Regression anchor
# for FENCED_JSON_RE's optional \n? before ```.
cat > "$TMP/fenced-no-trailing-nl.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\":[{\"file\":\"d.py\",\"line\":2,\"severity\":\"SUGGESTION\",\"confidence\":6,\"summary\":\"no trailing newline before fence close\",\"proposed_fix\":\"none\"}]}```"}}
EOF
check "fenced JSON (no trailing newline)" "$TMP/fenced-no-trailing-nl.jsonl" "" 'file: d.py'

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

# Fixture 6: exit-code override (timeout scenario — empty stdin, exit 124, reason override)
: > "$TMP/empty-for-timeout.jsonl"
output="$(python3 "$PARSER" \
  --meta-override-exit-code 124 \
  --meta-override-reason timeout \
  < "$TMP/empty-for-timeout.jsonl" 2>&1)"
if echo "$output" | grep -q 'reason: timeout' && echo "$output" | grep -q 'exit_code: 124' && echo "$output" | grep -q 'codex_failed: true'; then
  ok "meta override timeout"
else
  no "meta override timeout"
fi

# Fixture 7: exit-code override on success (findings present, exit 0)
cat > "$TMP/success.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\":[{\"file\":\"s.py\",\"line\":1,\"severity\":\"SUGGESTION\",\"confidence\":3,\"summary\":\"ok\",\"proposed_fix\":\"none\"}]}\n```"}}
EOF
output="$(python3 "$PARSER" \
  --meta-override-exit-code 0 \
  --meta-override-reason "" \
  < "$TMP/success.jsonl" 2>&1)"
if echo "$output" | grep -q 'codex_failed: false' && echo "$output" | grep -q 'file: s.py'; then
  ok "meta override on success (no reason set)"
else
  no "meta override on success"
fi

# Fixture 8: parser handles agent_message text containing """ safely (injection safety)
cat > "$TMP/injection-attempt.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"Here are findings: \"\"\" + __import__('os').system('echo PWNED') + \"\"\"\n```json\n{\"findings\":[{\"file\":\"i.py\",\"line\":1,\"severity\":\"SUGGESTION\",\"confidence\":1,\"summary\":\"injection attempt in text\",\"proposed_fix\":\"none\"}]}\n```"}}
EOF
output="$(python3 "$PARSER" < "$TMP/injection-attempt.jsonl" 2>&1)"
if echo "$output" | grep -q 'file: i.py' && ! echo "$output" | grep -q 'PWNED'; then
  ok "parser ignores triple-quote injection in agent_message text"
else
  no "parser reacted to injection attempt"
fi

# AC9(a) — non-list findings coerce + meta.reason
FIXTURES="$PLUGIN_ROOT/tests/fixtures"
output="$(python3 "$PARSER" < "$FIXTURES/codex_findings_dict_input.json" 2>&1)"
if echo "$output" | grep -qE "reason:[[:space:]]*schema_mismatch" && \
   echo "$output" | grep -qE "raw_findings_type:[[:space:]]*dict"; then
  ok "AC9(a): dict findings → meta.reason: schema_mismatch + raw_findings_type: dict"
else
  no "AC9(a): dict findings did not produce meta.reason: schema_mismatch or raw_findings_type: dict"
fi

output="$(python3 "$PARSER" < "$FIXTURES/codex_findings_string_input.json" 2>&1)"
if echo "$output" | grep -qE "raw_findings_type:[[:space:]]*str"; then
  ok "AC9(a): string findings → meta.raw_findings_type: str"
else
  no "AC9(a): string findings missing meta.raw_findings_type: str"
fi

# AC9(b) — last fenced block selection
output="$(python3 "$PARSER" < "$FIXTURES/codex_two_fenced_blocks.json" 2>&1)"
if echo "$output" | grep -q "real.py" && ! (echo "$output" | grep -qE "findings:[[:space:]]*\[\]"); then
  ok "AC9(b): last fenced block selected (prompt injection 차단)"
else
  no "AC9(b): parser did not pick LAST fenced block (real finding lost or first fake block selected)"
fi

# AC9(c) — AUTH_ERROR_RE extended patterns (import from actual parser module)
AC9C_PY="$TMP/check_auth_re.py"
cat > "$AC9C_PY" << PYEOF
import sys, importlib.util
scripts_dir = sys.argv[1]
pattern = sys.argv[2]
spec = importlib.util.spec_from_file_location(
    "codex_findings_to_yaml",
    scripts_dir + "/codex_findings_to_yaml.py"
)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)
print('MATCH' if mod.AUTH_ERROR_RE.search(pattern) else 'NO_MATCH')
PYEOF
ac9c_pass=true
for pattern in "401 Unauthorized" "403 Forbidden" "quota exceeded" \
               "subscription required" "credential expired"; do
  result=$(python3 "$AC9C_PY" "$PLUGIN_ROOT/scripts" "$pattern")
  if [ "$result" != "MATCH" ]; then
    no "AC9(c): AUTH_ERROR_RE missed pattern: $pattern"
    ac9c_pass=false
  fi
done
if [ "$ac9c_pass" = "true" ]; then
  ok "AC9(c): AUTH_ERROR_RE matches 5 extended patterns"
fi

# AC9(d) — stderr read error surfaced via meta.stderr_read_error
if [ "$(id -u)" -eq 0 ]; then
  echo "  SKIP: AC9(d) test requires non-root user (NG7: capability env out-of-scope)"
else
  UNREADABLE="$TMP/unreadable.txt"
  touch "$UNREADABLE"
  chmod 000 "$UNREADABLE"
  OUT=$(echo '{}' | python3 "$PARSER" --stderr-file "$UNREADABLE" 2>&1 || true)
  if echo "$OUT" | grep -qE "stderr_read_error:"; then
    ok "AC9(d): chmod 000 stderr → meta.stderr_read_error surfaced"
  else
    no "AC9(d): stderr read failure not surfaced via meta.stderr_read_error"
  fi
  chmod 600 "$UNREADABLE" 2>/dev/null || true
fi

finish
