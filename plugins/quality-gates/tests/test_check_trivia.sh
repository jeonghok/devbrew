#!/usr/bin/env bash
# T2-1 trivia detector coverage tests (AC1-AC6).
#
# Each test creates a temporary git repo, applies a controlled diff,
# invokes check-trivia.sh, and asserts (exit_code, stdout).

set -euo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/scripts/check-trivia.sh"
PASS=0
FAIL=0

run_case() {
  local name="$1" setup_fn="$2" expected_exit="$3" expected_stdout="$4"
  local tmp; tmp="$(mktemp -d)"
  # Trap ensures tmpdir cleanup even if setup_fn or assertions exit non-zero
  # under set -euo pipefail before reaching the explicit cleanup at end of fn.
  trap 'popd >/dev/null 2>&1; rm -rf "$tmp"' RETURN
  pushd "$tmp" >/dev/null
  git init -q
  git config user.email t@t.com
  git config user.name t
  "$setup_fn"
  set +e
  # NOTE: $TRIVIA_ARGS is intentionally unquoted — word-splitting required
  # for multi-token args like "--paths a.py". Do not "fix" to "$TRIVIA_ARGS".
  local stdout; stdout="$("$SCRIPT" $TRIVIA_ARGS 2>/dev/null)"; local exit_code=$?
  set -e
  if [[ "$exit_code" == "$expected_exit" && "$stdout" == "$expected_stdout" ]]; then
    echo "PASS: $name"; PASS=$((PASS+1))
  else
    echo "FAIL: $name"
    echo "  expected: exit=$expected_exit stdout='$expected_stdout'"
    echo "  got:      exit=$exit_code stdout='$stdout'"
    FAIL=$((FAIL+1))
  fi
}

# AC1 — comment-only single file
ac1_setup() {
  printf 'def foo():\n    pass\n' > a.py
  git add a.py; git commit -qm init
  printf 'def foo():\n    # added comment\n    pass\n' > a.py
  TRIVIA_ARGS=""
}
run_case "AC1: comment-only" ac1_setup 0 "trivia: comment"

# AC2 — typo (single-token, length-diff <= 2)
ac2_setup() {
  printf 'colour = 1\n' > a.py
  git add a.py; git commit -qm init
  printf 'color = 1\n' > a.py
  TRIVIA_ARGS=""
}
run_case "AC2: typo" ac2_setup 0 "trivia: typo"

# AC3 — untracked new file (≤3 lines, all blank/comment/shebang)
ac3_setup() {
  printf 'x=1\n' > a.py
  git add a.py; git commit -qm init
  printf '#!/bin/bash\n# placeholder\n' > new.sh
  TRIVIA_ARGS=""
}
run_case "AC3: untracked-newfile" ac3_setup 0 "trivia: untracked-newfile"

# AC4 — --paths narrows scope; scope-out file ignored
ac4_setup() {
  printf 'a = 1\n' > a.py
  printf 'b = 1\n' > b.py
  git add .; git commit -qm init
  # Scope-in: trivia-eligible comment change in a.py
  printf 'a = 1\n# comment\n' > a.py
  # Scope-out: non-trivia change in b.py
  printf 'b = 99\n' > b.py
  TRIVIA_ARGS="--paths a.py"
}
run_case "AC4: --paths scoping" ac4_setup 0 "trivia: comment"

# AC5 — regression: whitespace still emits its existing kind
ac5_setup() {
  printf 'a=1\n' > a.py
  git add a.py; git commit -qm init
  printf 'a = 1\n' > a.py
  TRIVIA_ARGS=""
}
run_case "AC6a: whitespace regression" ac5_setup 0 "trivia: whitespace"

# AC6 — regression: rename still emits its existing kind
ac6_setup() {
  printf 'x=1\n' > a.py
  git add a.py; git commit -qm init
  git mv a.py b.py
  TRIVIA_ARGS=""
}
run_case "AC6b: rename regression" ac6_setup 0 "trivia: rename"

echo ""
echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]] || exit 1
