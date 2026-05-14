#!/usr/bin/env bash
# AC11: SKILL.md consent marker write 실패 시 stderr 메시지 surface 검증
set -u
fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "OK: $1"; }

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# Extract fenced bash block following the unique identifier comment
SNIPPET=$(awk '/^# QG-CONSENT-MARKER-WRITE/{flag=1; next} flag && /^```bash$/{flag=2; next} flag==2 && /^```$/{exit} flag==2' "$SKILL")
[ -n "$SNIPPET" ] || fail "AC11: # QG-CONSENT-MARKER-WRITE block not found in SKILL.md"

# Force write failure: chmod 000 the target directory
TMP_HOME=$(mktemp -d)
chmod 000 "$TMP_HOME"
trap "chmod 700 '$TMP_HOME'; rm -rf '$TMP_HOME'" EXIT
ERR=$(HOME="$TMP_HOME" bash -c "$SNIPPET" 2>&1 >/dev/null || true)
echo "$ERR" | grep -qE "could not persist consent \(errno" \
  || fail "AC11: marker write failure did not surface 'could not persist consent (errno' pattern. stderr was: $ERR"
ok "AC11: marker write failure surfaces stderr message"

echo "PASS: test_consent_marker_write_failure.sh"
