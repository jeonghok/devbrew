#!/usr/bin/env bash
# AC4 — agent file must enumerate all 15 C8 conversation reference patterns.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# 영어 8개
for pat in "as discussed" "as we agreed" "we talked about" "the user mentioned" \
           "you mentioned" "as mentioned before" "per our discussion" "earlier in this session"; do
  grep -qF "$pat" "$AGENT" \
    && note PASS "AC4: EN pattern '$pat' present" \
    || note FAIL "AC4 EN pattern '$pat' missing"
done

# 한국어 7개
for pat in "위에서 논의한" "위에서 언급한" "방금 결정한" "아까 결정한" \
           "이전에 말했듯이" "언급하셨던" "말씀하신"; do
  grep -qF "$pat" "$AGENT" \
    && note PASS "AC4: KO pattern '$pat' present" \
    || note FAIL "AC4 KO pattern '$pat' missing"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail (expected 15 patterns)"
[[ $fail -eq 0 ]]
