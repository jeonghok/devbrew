#!/usr/bin/env bash
# v1.32.3 MED-4 test: cancel-qg-core.sh가 qg-worktree.sh 실패 시
# 정확한 exit code 메시지를 stderr에 출력하는지 검증.
# 비정상 종료 시에도 stub이 원본을 덮어쓰지 않도록 trap EXIT으로 복원.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS="$ROOT/quality-gates/scripts"
FIXTURE="$ROOT/quality-gates/tests/fixtures/qg-worktree-fail-stub.sh"
ORIGINAL="$SCRIPTS/qg-worktree.sh"
BACKUP="$SCRIPTS/qg-worktree.sh.med4-backup"

# Backup + install stub
mv "$ORIGINAL" "$BACKUP"
trap 'mv -f "$BACKUP" "$ORIGINAL" 2>/dev/null || true' EXIT
cp "$FIXTURE" "$ORIGINAL"
chmod +x "$ORIGINAL"

# Sandbox: tempdir에 SID 폴더 + pipeline.md 만들고 호출.
SANDBOX="$(mktemp -d)"
SID="med4-test-sid-deadbeef"
mkdir -p "$SANDBOX/.claude/quality-gates/$SID"
mkdir -p "$SANDBOX/fake-worktree-path"
cat > "$SANDBOX/.claude/quality-gates/$SID/pipeline.md" <<EOF
---
session_id: "$SID"
started_at: "2026-05-28T00:00:00Z"
worktree_path: "$SANDBOX/fake-worktree-path"
---
EOF

cd "$SANDBOX"

# cancel-qg-core 호출, stderr capture.
stderr_capture="$SANDBOX/stderr.log"
bash "$SCRIPTS/cancel-qg-core.sh" --session-id "$SID" 2>"$stderr_capture" || true

# 검증: stub의 메시지 + exit code 라인이 stderr에 prefix-emit됐는지.
fail=0
if grep -q 'cancel-qg-core: worktree: stub: simulated worktree removal failure' "$stderr_capture"; then
  echo "PASS: stub failure message prefix-emitted"
else
  echo "FAIL: stub message not prefixed properly"; echo "--- stderr ---"; cat "$stderr_capture"
  fail=$((fail + 1))
fi
if grep -q 'cancel-qg-core: qg-worktree.sh remove exit code 1' "$stderr_capture"; then
  echo "PASS: exit code 1 explicitly logged"
else
  echo "FAIL: exit code line missing"
  fail=$((fail + 1))
fi
# sed 의존 0건 (소스 정적 검증, advisory level).
# Comment 라인의 'sed' 단어 멘션은 제외 (실제 명령 호출만 카운트).
sed_count="$(grep -v '^[[:space:]]*#' "$SCRIPTS/cancel-qg-core.sh" | grep -c '\bsed\b' || true)"
if [[ "$sed_count" -eq 0 ]]; then
  echo "PASS: zero sed command invocation in cancel-qg-core.sh"
else
  echo "FAIL: $sed_count sed invocation(s) remain in cancel-qg-core.sh"
  fail=$((fail + 1))
fi

rm -rf "$SANDBOX"

if [[ "$fail" -eq 0 ]]; then
  echo "All tests pass."
  exit 0
else
  echo "$fail test(s) failed."
  exit 1
fi
