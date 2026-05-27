#!/usr/bin/env bash
# v2.0.0 /cancel-qg, /qg --reset, /qg --gc fixture verification (AC17, V10).
#
# Approach (spec V10 lock):
#   (1) Run the documented behavior directly via fixture shell — verify effect.
#   (2) Static-grep the command markdown file — verify it documents the same.
# Two stages decoupled so command-file drift triggers stage-2 failure.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
cd "$TMP"

# ============== /cancel-qg ==============
echo "--- /cancel-qg behavior fixture ---"
SID="test-sid-deadbeef"
mkdir -p ".claude/quality-gates/$SID"
echo '---' > ".claude/quality-gates/$SID/pipeline.md"

# Mimic command behavior (SID guard + rm -rf).
if [[ -z "$SID" || ! "$SID" =~ ^[A-Za-z0-9_-]{8,}$ ]]; then
  echo "FAIL: SID guard rejected valid SID"; exit 1
fi
rm -rf -- ".claude/quality-gates/$SID"
test ! -d ".claude/quality-gates/$SID" || { echo "FAIL: folder still exists"; exit 1; }
echo "PASS /cancel-qg (behavior)"

echo "--- /cancel-qg command-file static check ---"
grep -q 'rm -rf' "$ROOT/quality-gates/commands/cancel-qg.md" || { echo "FAIL: cancel-qg.md missing rm -rf"; exit 1; }
grep -qiE 'cancel|cleared|removed' "$ROOT/quality-gates/commands/cancel-qg.md" || { echo "FAIL: cancel-qg.md missing cancel/cleared/removed token"; exit 1; }
echo "PASS /cancel-qg (command-file documents behavior)"

# ============== /qg --reset (legacy v1.5.0 flat file sweep) ==============
echo "--- /qg --reset behavior fixture ---"
touch .claude/quality-gates.local.md
touch .claude/quality-gates-session.local.md
touch .claude/quality-gates-branch.local.md
touch .claude/qg-diff-cache.txt
touch .claude/qg-code-paths.tmp

rm -f .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp

for f in quality-gates.local.md quality-gates-session.local.md quality-gates-branch.local.md qg-diff-cache.txt qg-code-paths.tmp; do
  test ! -f ".claude/$f" || { echo "FAIL: legacy $f still present"; exit 1; }
done
echo "PASS /qg --reset (behavior)"

echo "--- /qg --reset command-file static check ---"
grep -q 'rm -f' "$ROOT/quality-gates/commands/qg.md" || { echo "FAIL: qg.md missing rm -f"; exit 1; }
grep -qE 'quality-gates(\.|-session|-branch)' "$ROOT/quality-gates/commands/qg.md" || { echo "FAIL: qg.md missing legacy file references"; exit 1; }
echo "PASS /qg --reset (command-file documents behavior)"

# ============== /qg --gc (TTL sweep) ==============
echo "--- /qg --gc TTL fixture ---"
mkdir -p ".claude/quality-gates/old-sid-deadbeef"
touch -t 200001010000 ".claude/quality-gates/old-sid-deadbeef/pipeline.md"

# Run real production script (per spec: qg-gc.py is the production tool, no mock).
# Note: HOME-relative CLAUDE_CODE_SESSION_ID may not be set; pass --session-id to
# avoid the GC treating our test folder as the active session.
python3 "$ROOT/quality-gates/scripts/qg-gc.py" --session-id "current-sid-not-this-one" 2>/dev/null || true

if [[ -d ".claude/quality-gates/old-sid-deadbeef" ]]; then
  echo "FAIL: qg-gc.py did not remove stale folder"
  exit 1
fi
echo "PASS /qg --gc (behavior)"

echo "--- /qg --gc command-file static check ---"
grep -q 'qg-gc.py' "$ROOT/quality-gates/commands/qg.md" || { echo "FAIL: qg.md missing qg-gc.py reference"; exit 1; }
echo "PASS /qg --gc (command-file documents behavior)"

echo "All cancel-qg / reset / gc checks pass."
