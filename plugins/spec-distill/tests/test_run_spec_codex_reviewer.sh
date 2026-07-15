#!/usr/bin/env bash
# AC5 (no discover-spec.sh) + AC6 (C7 mktemp guard) + OQ2 (medium effort)
# + one behavioral integration through a mock codex on PATH.
set -u -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
RUN="$PLUGIN_ROOT/scripts/run_spec_codex_reviewer.sh"
MOCKS="$SCRIPT_DIR/mocks"
TMP="$(mktemp -d -t sd-run-codex-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

pass=0; fail=0
note() { if [[ "$1" == PASS ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# --- Structural greps (AC5/AC6/OQ2) ---
grep -q 'discover-spec' "$RUN" \
  && note FAIL "AC5: discover-spec.sh referenced (C3 circular-injection risk)" \
  || note PASS "AC5: no discover-spec.sh call"

# C7: the scratch-dir assignment line must be guarded before any trap arms.
grep -qE 'SCRATCH=.*mktemp.*\|\|' "$RUN" \
  && note PASS "AC6: mktemp SCRATCH assignment has '||' guard" \
  || note FAIL "AC6: mktemp SCRATCH assignment not guarded (C7 footgun)"

grep -qE 'model_reasoning_effort.*medium' "$RUN" \
  && note PASS "OQ2: model_reasoning_effort=medium" || note FAIL "OQ2: effort not medium"
grep -qE '\-s read-only' "$RUN" \
  && note PASS "Law2: -s read-only sandbox flag" || note FAIL "-s read-only missing"

# --- Behavioral: mock codex on PATH produces parsed YAML at out path ---
DOC="$TMP/x-design.md"; printf '# X\n\n## 2. Goals\nrobust.\n' > "$DOC"
mkdir -p "$TMP/codexbin"
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
# ignore all args; emit one valid agent_message with findings
cat <<'JSONL'
{"type":"item.completed","item":{"type":"agent_message","text":"```json\n{\"findings\": [{\"category\": \"ambiguity\", \"target_section\": \"#2-goals\", \"severity\": \"high\"}]}\n```"}}
JSONL
exit 0
SH
chmod +x "$TMP/codexbin/codex"
OUT="$TMP/out.yaml"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT"
rc=$?
[[ $rc -eq 0 ]] && note PASS "exit 0" || note FAIL "exit $rc (expected 0)"
grep -q 'category: ambiguity' "$OUT" && note PASS "parsed finding written to out" || note FAIL "out yaml missing finding"
grep -q 'codex_failed: false' "$OUT" && note PASS "codex_failed false on success" || note FAIL "codex_failed not false"

# Behavioral: codex exit≠0 → degrade meta (not crash)
cat > "$TMP/codexbin/codex" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$TMP/codexbin/codex"
OUT2="$TMP/out2.yaml"
CLAUDE_PLUGIN_ROOT="$PLUGIN_ROOT" PATH="$TMP/codexbin:/usr/bin:/bin" \
  bash "$RUN" "$DOC" "$PLUGIN_ROOT" "$OUT2" || true
grep -q 'codex_failed: true' "$OUT2" && note PASS "codex exit1 → codex_failed true" || note FAIL "exit1 not marked failed"

echo; echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"; [[ $fail -eq 0 ]]
