#!/usr/bin/env bash
# AC7 (T1) — review-lock session-id split 의 결정론적 훅-레벨 repro.
# mis-keyed(interview UUID) 락 → 훅이 못 봄 → dispatch(block); correctly-keyed
# (harness sid) 락 → 훅이 봄 → no-op(빈 stdout). 두 assert 공존.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
LOCK="$REPO_ROOT/plugins/spec-distill/scripts/review_lock.py"
WORK=$(mktemp -d -t specdistill-locksid-XXXXXX) || exit 1
WORK=$(cd "$WORK" && pwd -P) || exit 1   # macOS /var → /private/var 정규화 (Path.resolve 일치)
trap 'rm -rf "$WORK"' EXIT

# git-aware state_root 경로를 실제로 태움 (fallback 마스킹 방지).
( cd "$WORK" && git init -q && git config user.email t@t.t \
  && git config user.name t && git commit -q --allow-empty -m seed )

HSID="hsid-aaaaaaaa"        # harness sid (훅이 payload/env 로 해석)
IUUID="iuuid-bbbbbbbb"      # interview UUID (버그: 스킬이 락을 여기에 걺)
DOC="docs/superpowers/specs/2026-07-05-locksid-design.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# harness-sid state 에 pending_review(doc) 시드 (last_dispatched 없음 → TTL 무관).
seed_pending() {
  mkdir -p "$WORK/.claude/spec-distill/$HSID"
  printf -- '---\nsession_id: %s\n---\n\npending_review:\n  path: %s\n  mode: design\n  triggered_at: 2026-05-16T10:00:00Z\n' \
    "$HSID" "$DOC" > "$WORK/.claude/spec-distill/$HSID/state.local.md"
}

run_hook() {
  cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID="$HSID" \
    bash -c "printf '%s' '{\"session_id\":\"$HSID\"}' | python3 '$HOOK'" 2>/dev/null
}

# ── RED-repro: 락을 interview UUID 에 걸면 harness-sid 파일엔 없어 훅이 dispatch ──
seed_pending
( cd "$WORK" && python3 "$LOCK" set "$IUUID" "$DOC" )   # 버그 시나리오: 잘못된 sid
out=$(run_hook)
echo "$out" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && note PASS "AC7-repro: mis-keyed(interview UUID) lock → hook dispatches (block present)" \
  || note FAIL "AC7-repro: expected block with interview-UUID lock (out='$out')"

# ── GREEN: 락을 harness sid 에 걸면 훅이 보고 no-op(빈 stdout) ──
seed_pending                                            # dispatch 가 pending 소비했으니 재시드
( cd "$WORK" && python3 "$LOCK" set "$HSID" "$DOC" )    # fix 시나리오: 올바른 sid
out=$(run_hook)
[[ -z "$out" ]] \
  && note PASS "AC7-fix: harness-sid lock → hook no-op (empty stdout)" \
  || note FAIL "AC7-fix: expected empty stdout with harness-sid lock (out='$out')"

echo
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
