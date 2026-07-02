#!/usr/bin/env bash
# approve_handoff.sh thin-finalizer contract (v0.11.0): no marker, no packet,
# no named-status. AC3 (clean → exit 0, no marker), AC5 (dirty → exit 0 + advisory),
# AC12 (suppress recorded + dir preserved), AC7 (kill switch).
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

TMPDIR_TESTRUN=$(mktemp -d); trap 'rm -rf "$TMPDIR_TESTRUN"' EXIT
OUT="$TMPDIR_TESTRUN/out"; ERR="$TMPDIR_TESTRUN/err"

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q && git config user.email test@x.invalid && git config user.name test
    echo "# test" > "$wd/docs/superpowers/specs/2026-01-01-test-spec.md"
    git add . && git commit -q -m init
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
    echo state > "$wd/.claude/spec-distill/test-sid12/state.local.md"
}
markers_dir() { echo "$1/.claude/spec-distill/.markers"; }

# ── Case 1 (AC3): clean HEAD spec → exit 0, NO marker dir, NO packet/STATUS text ──
WORK=$(mktemp -d); setup_repo "$WORK"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>"$ERR"; rc=$?
md=$(markers_dir "$WORK")
if [[ $rc -eq 0 && ! -d "$md" ]] && ! grep -q "handoff packet" "$OUT" && ! grep -q "STATUS=" "$OUT" "$ERR"; then
    note PASS "case 1 (AC3): clean → exit 0, no marker dir, no packet"
else
    note FAIL "case 1: rc=$rc, no_marker_dir=$([[ ! -d $md ]] && echo y || echo n), no_packet=$(grep -q 'handoff packet' "$OUT" && echo n || echo y)"
fi
rm -rf "$WORK"

# ── Case 2 (AC5 FLIP): dirty spec → exit 0 + non-blocking advisory ──
WORK=$(mktemp -d); setup_repo "$WORK"
echo "uncommitted mod" >> "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >"$OUT" 2>"$ERR"; rc=$?
ok=1
grep -q "\[spec-distill\]" "$ERR" || ok=0
grep -q "git add -- " "$ERR" || ok=0
grep -q "git commit -m " "$ERR" || ok=0
if [[ $rc -eq 0 && "$ok" -eq 1 ]]; then
    note PASS "case 2 (AC5): dirty → exit 0 + advisory (non-blocking)"
else
    note FAIL "case 2: rc=$rc (expected 0), advisory_ok=$ok"
fi
rm -rf "$WORK"

# ── Case 3 (AC12 idempotency): clean re-call → exit 0, suppressed_paths 1 entry ──
WORK=$(mktemp -d); setup_repo "$WORK"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1
bash "$SCRIPT" "test-sid12" "$spec" >"$OUT" 2>&1; rc=$?
sf="$WORK/.claude/spec-distill/test-sid12/state.local.md"
cnt=$(grep -c "  - docs/superpowers/specs/2026-01-01-test-spec.md" "$sf" 2>/dev/null || echo 0)
if [[ $rc -eq 0 && "$cnt" == "1" ]]; then
    note PASS "case 3 (AC12): idempotent re-call → exactly 1 suppressed entry"
else
    note FAIL "case 3: rc=$rc cnt=$cnt"
fi
rm -rf "$WORK"

# ── Case 4 (AC12): approve → suppressed_paths 기록 + pending strip + dir 보존 ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
cat > "$sess/state.local.md" <<EOF
---
session_id: test-sid12
---

pending_review:
  path: $spec
  mode: spec
  worktree_path: $WORK
  triggered_at: 2026-01-01T00:00:00Z
EOF
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1; rc=$?
key="docs/superpowers/specs/2026-01-01-test-spec.md"
if [[ $rc -eq 0 && -d "$sess" ]] \
   && grep -q "^suppressed_paths:" "$sess/state.local.md" \
   && grep -q "  - $key" "$sess/state.local.md" \
   && ! grep -qE '^pending_review:' "$sess/state.local.md"; then
    note PASS "case 4 (AC12): suppress recorded + pending stripped + dir preserved"
else
    note FAIL "case 4 (AC12): rc=$rc dir=$([[ -d $sess ]] && echo y || echo n)"
fi
rm -rf "$WORK"

# ── Case 4b (AC6): approve → review_in_progress 그 문서 엔트리 clear ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
spec="$WORK/docs/superpowers/specs/2026-01-01-test-spec.md"
key="docs/superpowers/specs/2026-01-01-test-spec.md"
otherkey="docs/superpowers/specs/2026-01-01-other-design.md"
NOWLK=$(python3 -c 'from datetime import datetime,timezone; print(datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"))')
cat > "$sess/state.local.md" <<EOF
---
session_id: test-sid12
---

pending_review:
  path: $spec
  mode: design
  triggered_at: 2026-01-01T00:00:00Z

review_in_progress:
  - path: $key
    since: $NOWLK
  - path: $otherkey
    since: $NOWLK
EOF
bash "$SCRIPT" "test-sid12" "$spec" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 ]] \
   && ! grep -q "  - path: $key\$" "$sess/state.local.md" \
   && grep -q "  - path: $otherkey\$" "$sess/state.local.md"; then
    note PASS "case 4b (AC6): approve clears THIS doc lock entry, preserves other"
else
    note FAIL "case 4b (AC6): rc=$rc"
fi
rm -rf "$WORK"

# ── Case 4c (AC12): dead main_repo 블록 부재 (스크립트 소스 grep) ──
if ! grep -qE 'main_repo=|git_common_dir=' "$SCRIPT"; then
    note PASS "case 4c (AC12): dead main_repo/git_common_dir 블록 제거됨"
else
    note FAIL "case 4c (AC12): dead 블록 잔존"
fi

# ── Case 5: charset reject → exit 1 ──
WORK=$(mktemp -d); setup_repo "$WORK"
bash "$SCRIPT" "../bad" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>"$ERR"; rc=$?
[[ $rc -ne 0 ]] && grep -q "aborting" "$ERR" \
    && note PASS "case 5: charset reject → exit 1" \
    || note FAIL "case 5: rc=$rc"
rm -rf "$WORK"

# ── Case 6: empty args → exit 1 ──
bash "$SCRIPT" "" "anything" >/dev/null 2>&1; [[ $? -ne 0 ]] && note PASS "case 6a: empty sid rejected" || note FAIL "case 6a"
bash "$SCRIPT" "test-sid12" "" >/dev/null 2>&1; [[ $? -ne 0 ]] && note PASS "case 6b: empty path rejected" || note FAIL "case 6b"

# ── Case 7 (AC7): kill switch → exit 0, session dir PRESERVED (no side effects) ──
WORK=$(mktemp -d); setup_repo "$WORK"
sess="$WORK/.claude/spec-distill/test-sid12"
DEVBREW_DISABLE_SPEC_DISTILL=1 bash "$SCRIPT" "test-sid12" "$WORK/docs/superpowers/specs/2026-01-01-test-spec.md" >/dev/null 2>&1; rc=$?
if [[ $rc -eq 0 && -d "$sess" ]]; then
    note PASS "case 7 (AC7): kill switch → exit 0, session dir preserved"
else
    note FAIL "case 7: rc=$rc, sess_preserved=$([[ -d $sess ]] && echo y || echo n)"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail case(s)"; exit 1; fi
echo "PASSED: 9 cases"
