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
  echo "  PASS: meta override timeout"; pass=$((pass + 1))
else
  echo "  FAIL: meta override timeout"
  echo "$output" | sed 's/^/      /'
  fail=$((fail + 1))
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
  echo "  PASS: meta override on success (no reason set)"; pass=$((pass + 1))
else
  echo "  FAIL: meta override on success"
  echo "$output" | sed 's/^/      /'
  fail=$((fail + 1))
fi

# Fixture 8: parser handles agent_message text containing """ safely (injection safety)
cat > "$TMP/injection-attempt.jsonl" <<'EOF'
{"type":"item.completed","item":{"type":"agent_message","text":"Here are findings: \"\"\" + __import__('os').system('echo PWNED') + \"\"\"\n```json\n{\"findings\":[{\"file\":\"i.py\",\"line\":1,\"severity\":\"SUGGESTION\",\"confidence\":1,\"summary\":\"injection attempt in text\",\"proposed_fix\":\"none\"}]}\n```"}}
EOF
output="$(python3 "$PARSER" < "$TMP/injection-attempt.jsonl" 2>&1)"
if echo "$output" | grep -q 'file: i.py' && ! echo "$output" | grep -q 'PWNED'; then
  echo "  PASS: parser ignores triple-quote injection in agent_message text"; pass=$((pass + 1))
else
  echo "  FAIL: parser reacted to injection attempt"
  echo "$output" | sed 's/^/      /'
  fail=$((fail + 1))
fi

# AC9(a) — non-list findings coerce + meta.reason
FIXTURES="$PLUGIN_ROOT/tests/fixtures"
output="$(python3 "$PARSER" < "$FIXTURES/codex_findings_dict_input.json" 2>&1)"
if echo "$output" | grep -qE "reason:[[:space:]]*schema_mismatch" && \
   echo "$output" | grep -qE "raw_findings_type:[[:space:]]*dict"; then
  echo "  PASS: AC9(a): dict findings → meta.reason: schema_mismatch + raw_findings_type: dict"
  pass=$((pass + 1))
else
  echo "  FAIL: AC9(a): dict findings did not produce meta.reason: schema_mismatch or raw_findings_type: dict"
  echo "$output" | sed 's/^/      /'
  fail=$((fail + 1))
fi

output="$(python3 "$PARSER" < "$FIXTURES/codex_findings_string_input.json" 2>&1)"
if echo "$output" | grep -qE "raw_findings_type:[[:space:]]*str"; then
  echo "  PASS: AC9(a): string findings → meta.raw_findings_type: str"
  pass=$((pass + 1))
else
  echo "  FAIL: AC9(a): string findings missing meta.raw_findings_type: str"
  echo "$output" | sed 's/^/      /'
  fail=$((fail + 1))
fi

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
