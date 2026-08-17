#!/usr/bin/env bash
# AC4 — agent file must enumerate all 15 C8 conversation reference patterns.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

# 영어 8개
for pat in "as discussed" "as we agreed" "we talked about" "the user mentioned" \
           "you mentioned" "as mentioned before" "per our discussion" "earlier in this session"; do
  grep -qF "$pat" "$AGENT" \
    && ok "AC4: EN pattern '$pat' present" \
    || no "AC4 EN pattern '$pat' missing"
done

# 한국어 7개
for pat in "위에서 논의한" "위에서 언급한" "방금 결정한" "아까 결정한" \
           "이전에 말했듯이" "언급하셨던" "말씀하신"; do
  grep -qF "$pat" "$AGENT" \
    && ok "AC4: KO pattern '$pat' present" \
    || no "AC4 KO pattern '$pat' missing"
done
finish
