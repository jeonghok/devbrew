#!/usr/bin/env bash
# v1.32.3 MED-3: read-frontmatter.py helper 5-case unit test.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HELPER="$ROOT/quality-gates/scripts/read-frontmatter.py"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

fail=0
run_case() {
  local name="$1" fixture="$2" key="$3" expected="$4"
  local fixture_file="$TMP/$name.md"
  printf '%s\n' "$fixture" > "$fixture_file"
  local actual
  actual="$(python3 "$HELPER" "$fixture_file" "$key" 2>/dev/null)"
  if [[ "$actual" == "$expected" ]]; then
    echo "  PASS $name"
  else
    echo "  FAIL $name: expected [$expected] got [$actual]"
    fail=$((fail + 1))
  fi
}

echo "--- T-RF-quoted ---"
run_case "T-RF-quoted" '---
key: "value"
---' "key" "value"

echo "--- T-RF-unquoted ---"
run_case "T-RF-unquoted" '---
key: value
---' "key" "value"

echo "--- T-RF-missing ---"
run_case "T-RF-missing" '---
other: foo
---' "key" ""

echo "--- T-RF-embedded-quote ---"
# Fixture에 literal \" 시퀀스 — escape-aware regex가 val"ue로 해석.
run_case "T-RF-embedded-quote" '---
key: "val\"ue"
---' "key" 'val"ue'

echo "--- T-RF-embedded-backslash ---"
# Fixture에 literal \\ 시퀀스 — single backslash로 해석.
run_case "T-RF-embedded-backslash" '---
key: "a\\b"
---' "key" 'a\b'

if [[ "$fail" -eq 0 ]]; then
  echo "All tests pass."
  exit 0
else
  echo "$fail test(s) failed."
  exit 1
fi
