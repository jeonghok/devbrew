#!/usr/bin/env bash
# V2 — Hook smoke test (deterministic, no human eyeballing).
# Runs the docs-lint hook against every fixture and asserts expected stdout pattern.
#
# Portable across macOS bash 3.2 (no associative arrays) and modern bash/zsh —
# uses parallel arrays + index lookup instead of `declare -A`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
FIX="$ROOT/plugins/project-init/hooks/tests/fixtures"
HOOK="$ROOT/plugins/project-init/hooks/docs-lint.py"

# Parallel arrays: FIXTURES[i] -> EXPECTS[i].
# EXPECT value "{}" means stdout must equal exactly "{}";
# any other value is a substring to grep for.
FIXTURES=(
  valid
  oversized
  strong_oversized
  missing_toc
  bare_fence
  broken_link
  drifted
  proper_pointer
  dangling_pointer
  charter_complete
  charter_missing_subsection
  charter_placeholder_residue
  charter_doc_target
)
EXPECTS=(
  "{}"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "systemMessage"
  "{}"
  "{}"
  "{}"
  "systemMessage"
  "systemMessage"
  "systemMessage"
)
# TARGETS[i] — relative path within the fixture dir to lint. Empty string keeps
# the legacy AGENTS.md→CLAUDE.md autodetect; non-empty overrides it (charter
# detail docs live at docs/project/*.md).
TARGETS=(
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  ""
  "docs/project/charter.md"
)

fails=0
for i in "${!FIXTURES[@]}"; do
  d="${FIXTURES[$i]}"
  expected="${EXPECTS[$i]}"
  trel="${TARGETS[$i]}"
  if [ -n "$trel" ]; then
    target="$FIX/$d/$trel"
  else
    target="$FIX/$d/AGENTS.md"
    [ -f "$target" ] || target="$FIX/$d/CLAUDE.md"
  fi
  payload="{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$target\"}}"
  out=$(CLAUDE_PROJECT_DIR="$FIX/$d" python3 "$HOOK" <<< "$payload")
  if [ "$expected" = "{}" ]; then
    if [ "$out" != "{}" ]; then
      echo "FAIL: $d expected {} got: $out"
      fails=$((fails+1))
    fi
  else
    if ! echo "$out" | grep -q "$expected"; then
      echo "FAIL: $d expected '$expected' got: $out"
      fails=$((fails+1))
    fi
  fi
done

if [ $fails -gt 0 ]; then
  echo "V2 FAIL: $fails fixture(s) mismatched"
  exit 1
fi
echo "V2 PASS"
