#!/usr/bin/env bash
# T12/AC12 — v2.11.0 metadata: version bump + CHANGELOG + README principles + mode docs.
set -u
ROOT="plugins/quality-gates"
PASS=0; FAIL=0
ok() { PASS=$((PASS+1)); echo "  PASS: $1"; }
no() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

grep -qE '"version":[[:space:]]*"2\.11\.[0-9]+"' "$ROOT/.claude-plugin/plugin.json" && ok "plugin.json 2.11.x" || no "plugin.json not 2.11.x"
grep -qE '^## \[2\.11\.0\]' "$ROOT/CHANGELOG.md" && ok "CHANGELOG [2.11.0]" || no "CHANGELOG missing [2.11.0]"
grep -qF 'critiquing-artifacts' "$ROOT/CHANGELOG.md" && ok "CHANGELOG mentions new skill" || no "CHANGELOG omits skill"
# README principles: the mode instantiates Law 1/2/3 for artifact critique
grep -qF 'critique' "$ROOT/README.md" && ok "README documents critique mode" || no "README omits critique"
grep -qiE 'artifact-critic|critiquing-artifacts' "$ROOT/README.md" && ok "README names new component" || no "README omits component"
# version-pin regression: publish-docs test must not stale-red on 2.11.x
grep -qE '2\.10\.\[0-9\]\+|2\.10\.x' "$ROOT/tests/test_qg_publish_docs.sh" && no "publish-docs still pins 2.10 (will stale-red)" || ok "publish-docs version pin relaxed off 2.10"

echo ""; echo "Total: $((PASS+FAIL)), PASS=$PASS, FAIL=$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
