#!/usr/bin/env bash
# V4/AC6 — steelman-builder is read-only (Law 2 frontmatter scoping) + web-capable.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

test -f "$AGENT" && note PASS "agent file exists" || { note FAIL "agent file missing"; echo "Total: 1 | Pass: 0 | Fail: 1"; exit 1; }

# Extract frontmatter block (first ---...second ---)
fm="$(awk '/^---$/{c++} c==1' "$AGENT")"

# AC6: disallowedTools includes all four write tools
for tool in Write Edit MultiEdit NotebookEdit; do
  grep -qE "^\s*-\s*$tool\b" <<<"$fm" \
    && note PASS "AC6: disallowedTools includes $tool" \
    || note FAIL "AC6: disallowedTools MISSING $tool"
done

# allowedTools includes web research surfaces
for tool in WebSearch WebFetch; do
  grep -qE "^\s*-\s*$tool\b" <<<"$fm" \
    && note PASS "allowedTools includes $tool" \
    || note FAIL "allowedTools MISSING $tool"
done

# name + verbatim-output contract present
grep -q '^name: steelman-builder$' <<<"$fm" \
  && note PASS "name: steelman-builder" || note FAIL "name field broken"
grep -qiE 'verbatim|약화.*금지|편집.*금지' "$AGENT" \
  && note PASS "AC5: verbatim/no-weakening output contract present" \
  || note FAIL "AC5: verbatim output contract missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
