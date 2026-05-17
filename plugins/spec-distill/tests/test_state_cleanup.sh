#!/usr/bin/env bash
# Tests for cleanup_stale_states() — V9 of design v1.0.0.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HELPER="$REPO_ROOT/plugins/spec-distill/hooks/state_path.py"
WORK=$(mktemp -d -t specdistill-cleanup-XXXXXX)
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

ROOT="$WORK/state"
mkdir -p "$ROOT/fresh" "$ROOT/stale-pending" "$ROOT/stale-file"
NOW=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
T_25H=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(hours=25)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
T_8D=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(days=8)).strftime("%Y-%m-%dT%H:%M:%SZ"))')

# fresh — should be untouched
cat > "$ROOT/fresh/state.local.md" <<EOF
---
session_id: fresh
---

pending_review:
  path: /tmp/x.md
  mode: design
  triggered_at: $NOW
EOF

# stale-pending — 25h old pending_review → block purged, file kept
cat > "$ROOT/stale-pending/state.local.md" <<EOF
---
session_id: stale-pending
---

pending_review:
  path: /tmp/y.md
  mode: design
  worktree_path: /tmp/wt-stale
  triggered_at: $T_25H
EOF

# stale-file — only last_dispatched_at, 8d old → file deleted
cat > "$ROOT/stale-file/state.local.md" <<EOF
---
session_id: stale-file
---
last_dispatched_at: $T_8D
EOF

python3 "$HELPER" cleanup "$ROOT" 2>/dev/null

# Case 1: fresh untouched
grep -q '^pending_review:' "$ROOT/fresh/state.local.md" \
  && note PASS "fresh pending_review preserved" \
  || note FAIL "fresh pending_review was purged"

# Case 2: stale-pending block purged but file kept
[[ -f "$ROOT/stale-pending/state.local.md" ]] \
  && ! grep -q '^pending_review:' "$ROOT/stale-pending/state.local.md" \
  && note PASS "stale pending_review purged, file kept" \
  || note FAIL "stale-pending not handled correctly"

# Case 3: stale-file deleted
[[ ! -f "$ROOT/stale-file/state.local.md" ]] \
  && note PASS "stale file (>7d, no pending_review) deleted" \
  || note FAIL "stale file not deleted"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
