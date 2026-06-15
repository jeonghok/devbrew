#!/usr/bin/env bash
# AC1 (v0.15.0) — approve_handoff.sh: in-scope spec_path가 working-tree에 없어도
# suppress를 기록하고 exit 0 + stale advisory를 낸다. (v0.14.0의 `-f` early-exit
# 순서 버그를 닫음 — suppress가 `-f` 검사 *앞*에서 수행되므로 dangling/absent에도
# 누락되지 않는다.) canonical_key는 파일 존재가 불필요.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$PLUGIN_DIR/scripts/approve_handoff.sh"
fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

KEY="docs/superpowers/specs/2026-01-01-test-spec.md"

setup_repo() {
    local wd=$1
    mkdir -p "$wd/docs/superpowers/specs"
    cd "$wd"
    git init -q && git config user.email t@x.invalid && git config user.name t
    echo "# test" > "$wd/$KEY"
    git add . && git commit -q -m init
    mkdir -p "$wd/.claude/spec-distill/test-sid12"
}

# state에 이 문서의 pending_review 블록을 심는다 — same-key strip 단언용.
seed_pending() {
    local wd=$1 spec=$2
    cat > "$wd/.claude/spec-distill/test-sid12/state.local.md" <<EOF
---
session_id: test-sid12
---

pending_review:
  path: $spec
  mode: design
  worktree_path: $wd
  triggered_at: 2026-01-01T00:00:00Z
EOF
}

# ── AC1a: spec_path가 한 번도 존재한 적 없음 (working-tree·git 모두 부재) ──
WORK=$(mktemp -d); setup_repo "$WORK"; ERR="$WORK/err"
spec_abs="$WORK/docs/superpowers/specs/NONEXISTENT-design.md"
seed_pending "$WORK" "$spec_abs"
bash "$SCRIPT" "test-sid12" "$spec_abs" >/dev/null 2>"$ERR"; rc=$?
sf="$WORK/.claude/spec-distill/test-sid12/state.local.md"
if [[ $rc -eq 0 ]] \
   && grep -q "\[spec-distill\]" "$ERR" \
   && grep -qi "없음\|stale\|dangling" "$ERR" \
   && grep -q "^suppressed_paths:" "$sf" \
   && grep -q "  - docs/superpowers/specs/NONEXISTENT-design.md" "$sf" \
   && ! grep -qE '^pending_review:' "$sf"; then
    note PASS "AC1a: absent spec_path → exit 0 + suppress 기록 + pending strip + advisory"
else
    note FAIL "AC1a: rc=$rc (expected 0), suppress=$(grep -q '^suppressed_paths:' "$sf" && echo y || echo n), pending_stripped=$(grep -qE '^pending_review:' "$sf" && echo n || echo y)"
fi
rm -rf "$WORK"

# ── AC1b: dangling — git HEAD에 tracked, working-tree에서 제거 ──
WORK=$(mktemp -d); setup_repo "$WORK"; ERR="$WORK/err"
spec_abs="$WORK/$KEY"
seed_pending "$WORK" "$spec_abs"
rm -f "$WORK/$KEY"   # tracked-but-removed → dangling
bash "$SCRIPT" "test-sid12" "$spec_abs" >/dev/null 2>"$ERR"; rc=$?
sf="$WORK/.claude/spec-distill/test-sid12/state.local.md"
sess="$WORK/.claude/spec-distill/test-sid12"
if [[ $rc -eq 0 && -d "$sess" ]] \
   && grep -q "\[spec-distill\]" "$ERR" \
   && grep -q "^suppressed_paths:" "$sf" \
   && grep -q "  - $KEY" "$sf" \
   && ! grep -qE '^pending_review:' "$sf"; then
    note PASS "AC1b: dangling (HEAD-tracked, worktree-absent) → exit 0 + suppress + strip + dir 보존"
else
    note FAIL "AC1b: rc=$rc (expected 0), suppress=$(grep -q '^suppressed_paths:' "$sf" && echo y || echo n)"
fi
rm -rf "$WORK"

if [[ "$fail" -gt 0 ]]; then echo "FAILED: $fail case(s)"; exit 1; fi
echo "PASSED: 2 cases"
