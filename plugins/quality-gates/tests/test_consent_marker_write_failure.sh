#!/usr/bin/env bash
# AC11: SKILL.md consent marker write 실패 시 stderr 메시지 surface 검증
set -u
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

REPO_ROOT="$(git rev-parse --show-toplevel)"
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# Extract fenced bash block following the unique identifier comment
SNIPPET=$(awk '/^# QG-CONSENT-MARKER-WRITE/{flag=1; next} flag && /^```bash$/{flag=2; next} flag==2 && /^```$/{exit} flag==2' "$SKILL")
# 가드 — $SNIPPET 이 비면 아래 bash -c "$SNIPPET" 가 빈 입력 위에서 돌아 연쇄
# 허위 실패를 낸다(Task 14 Step 3 즉시 종료형 케이스). exit 없이는 다음 판정이
# 무의미해지므로 finish + exit 로 여기서 끝낸다.
[ -n "$SNIPPET" ] || { no "AC11: # QG-CONSENT-MARKER-WRITE block not found in SKILL.md"; finish; exit; }

# Force write failure: chmod 000 the target directory
TMP_HOME=$(mktemp -d)
chmod 000 "$TMP_HOME"
trap "chmod 700 '$TMP_HOME'; rm -rf '$TMP_HOME'" EXIT
ERR=$(HOME="$TMP_HOME" bash -c "$SNIPPET" 2>&1 >/dev/null || true)
if echo "$ERR" | grep -qE "could not persist consent \(errno"; then
  ok "AC11: marker write failure surfaces stderr message"
else
  no "AC11: marker write failure did not surface 'could not persist consent (errno' pattern. stderr was: $ERR"
fi

finish
