#!/usr/bin/env bash
# AC8 — write_state defensive truncate when frontmatter session_id ≠ current.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$PLUGIN_DIR/hooks/spec-write-validator.py"
FIX="$PLUGIN_DIR/tests/fixtures"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

run_validator() {
    local wd=$1 sid=$2 file=$3
    cd "$wd"
    printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"%s"}' "$file" "$sid" \
        | DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" python3 "$HOOK" >/dev/null 2>&1
    return 0
}

# Case 1: stale session_id → truncate
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/new-sid12345
cat > .claude/spec-distill/new-sid12345/state.local.md <<'EOF'
---
session_id: old-sid67890
phase: 3
---
stale body content
EOF
cp "$FIX/spec-valid.md" docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "new-sid12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
if grep -q "session_id: new-sid12345" "$WORK/.claude/spec-distill/new-sid12345/state.local.md" \
    && ! grep -q "stale body content" "$WORK/.claude/spec-distill/new-sid12345/state.local.md"; then
    ok "case 1: stale session_id → truncate"
else
    no "case 1: truncate did not occur"
fi
rm -rf "$WORK"

# Case 2: matching session_id → append (no truncate)
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/same-sid12345
cat > .claude/spec-distill/same-sid12345/state.local.md <<'EOF'
---
session_id: same-sid12345
---
existing body
EOF
cp "$FIX/spec-valid.md" docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "same-sid12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
if grep -q "existing body" "$WORK/.claude/spec-distill/same-sid12345/state.local.md"; then
    ok "case 2: matching session_id → append preserves body"
else
    no "case 2: body lost"
fi
rm -rf "$WORK"

# Case 3: no frontmatter (free-form body) → append path
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/no-fm12345
echo "free-form body only" > .claude/spec-distill/no-fm12345/state.local.md
cp "$FIX/spec-valid.md" docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "no-fm12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
if grep -q "free-form body only" "$WORK/.claude/spec-distill/no-fm12345/state.local.md"; then
    ok "case 3: no frontmatter → backward compat"
else
    no "case 3: body lost"
fi
rm -rf "$WORK"

# Case 4: unreadable state file → preserve (no overwrite)
WORK=$(mktemp -d)
cd "$WORK" && git init -q
mkdir -p docs/superpowers/specs .claude/spec-distill/unread12345
printf '\x00\x01\x02 binary garbage' > .claude/spec-distill/unread12345/state.local.md
chmod 000 .claude/spec-distill/unread12345/state.local.md
cp "$FIX/spec-valid.md" docs/superpowers/specs/2026-05-19-test-spec.md
run_validator "$WORK" "unread12345" "$WORK/docs/superpowers/specs/2026-05-19-test-spec.md"
# verify file untouched (still ~26 bytes — binary garbage, not overwritten)
chmod 644 .claude/spec-distill/unread12345/state.local.md
byte_count=$(wc -c < .claude/spec-distill/unread12345/state.local.md)
if [[ "$byte_count" -lt 100 ]]; then
    ok "case 4: unreadable → preserved"
else
    no "case 4: overwrote unreadable (byte_count=$byte_count)"
fi
rm -rf "$WORK"

finish
