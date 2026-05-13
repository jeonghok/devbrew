#!/usr/bin/env bash
# AC5 — verify each failure mock produces correct meta in parser output.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PARSER="$PLUGIN_ROOT/scripts/codex_findings_to_yaml.py"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t qg-fail-inject-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0

check_meta() {
  local name="$1"; local mock="$2"; local expected_reason="$3"
  local stdout_file="$TMP/$name.stdout"; local stderr_file="$TMP/$name.stderr"
  bash "$mock" > "$stdout_file" 2>"$stderr_file" || true
  output="$(python3 "$PARSER" --stderr-file "$stderr_file" < "$stdout_file")"

  if [[ "$expected_reason" == "(none)" ]]; then
    if echo "$output" | grep -q 'codex_failed: false' && echo "$output" | grep -q 'agent: codex-reviewer'; then
      echo "  PASS: $name (parsed findings, no failure)"
      pass=$((pass + 1))
    else
      echo "  FAIL: $name"
      echo "$output" | sed 's/^/    /'
      fail=$((fail + 1))
    fi
  else
    if echo "$output" | grep -q "reason: $expected_reason"; then
      echo "  PASS: $name -> $expected_reason"
      pass=$((pass + 1))
    else
      echo "  FAIL: $name (expected reason: $expected_reason)"
      echo "$output" | sed 's/^/    /'
      fail=$((fail + 1))
    fi
  fi
}

chmod +x "$MOCKS"/mock-codex-*.sh

# 1. exit ≠ 0 (no stdout → parser sees empty → missing_result)
check_meta "exit-1" "$MOCKS/mock-codex-exit1.sh" "missing_result"

# 2. malformed JSON
check_meta "bad-json" "$MOCKS/mock-codex-bad-json.sh" "malformed_json"

# 3. no agent_message
check_meta "no-agent-message" "$MOCKS/mock-codex-no-agent-message.sh" "missing_result"

# 4. valid JSON without fence
check_meta "valid-json-no-fence" "$MOCKS/mock-codex-valid-json-no-fence.sh" "(none)"

# 5. auth error in stderr
check_meta "auth-stderr" "$MOCKS/mock-codex-auth-stderr.sh" "auth_error_in_stderr"

# (Timeout case 6 is integration-only — agent body's exit-code 124 branch
#  handles it via --meta-override-reason timeout, tested in Task 3 fixture 6.)

echo ""
echo "Total: $((pass + fail)), pass: $pass, fail: $fail"
[[ $fail -eq 0 ]] || exit 1
