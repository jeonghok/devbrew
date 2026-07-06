#!/usr/bin/env bash
# test_gh_identity.sh — gh-identity.sh resolves login + numeric id and is
# FAIL-CLOSED (empty id) when gh is unauth or absent. PATH-stubbed, no network.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
IDENTITY="$PLUGIN_ROOT/scripts/gh-identity.sh"
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  → PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }
test -f "$IDENTITY" || { echo "FAIL: gh-identity.sh missing at $IDENTITY"; exit 1; }

# (i) gh emits login<TAB>id → parsed into login/id.
d=$(mktemp -d)
cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
# stub: authenticated user
printf 'octocat\t583231\n'
EOF
chmod +x "$d/gh"
out=$(PATH="$d:/usr/bin:/bin" bash "$IDENTITY" 2>/dev/null)
if printf '%s' "$out" | grep -q '^login: octocat$' \
   && printf '%s' "$out" | grep -q '^id: 583231$'; then
  pass "gh present+authed → login + numeric id"
else
  fail "authed identity not parsed (got: $out)"
fi
rm -rf "$d"

# (ii) gh present but unauth (exit 1) → id empty (fail-closed).
d=$(mktemp -d)
cat > "$d/gh" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
chmod +x "$d/gh"
out=$(PATH="$d:/usr/bin:/bin" bash "$IDENTITY" 2>/dev/null)
if printf '%s\n' "$out" | grep -qE '^id:[[:space:]]*$'; then
  pass "gh unauth (exit 1) → id empty (fail-closed)"
else
  fail "unauth did not fail-closed (got: $out)"
fi
rm -rf "$d"

# (iii) gh absent from PATH (bash/coreutils present, no gh) → id empty (fail-closed).
d=$(mktemp -d)
out=$(PATH="$d:/usr/bin:/bin" bash "$IDENTITY" 2>/dev/null)
if printf '%s\n' "$out" | grep -qE '^id:[[:space:]]*$'; then
  pass "gh absent → id empty (fail-closed)"
else
  fail "gh-absent did not fail-closed (got: $out)"
fi
rm -rf "$d"

echo "gh-identity: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
