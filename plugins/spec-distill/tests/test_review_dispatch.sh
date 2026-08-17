#!/usr/bin/env bash
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
WORK=$(mktemp -d -t specdistill-dispatch-XXXXXX) || exit 1
# Resolve symlinks (macOS /var → /private/var) so Path.resolve() output matches.
WORK=$(cd "$WORK" && pwd -P) || exit 1
trap 'rm -rf "$WORK"' EXIT

# T-5: exercise the git-aware state_root path (whole point of state_path.py).
# Without git init, state_root() falls back to cwd-relative — which masks the
# primary code path.
( cd "$WORK" && git init -q && git config user.email t@t.t \
  && git config user.name t && git commit -q --allow-empty -m seed )

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

setup_state() {
  local sid="$1"; shift
  local body="${1:-}"
  mkdir -p "$WORK/.claude/spec-distill/$sid"
  printf '%s' "$body" > "$WORK/.claude/spec-distill/$sid/state.local.md"
}

run_hook() {
  local sid="$1"
  cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID="$sid" \
    bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null
}

# Case 11: AC11 — pending_review present → systemMessage emit
setup_state "test-011" "---
session_id: test-011
---

pending_review:
  path: /tmp/some-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-011")
rc=$?
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("MANDATORY")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("/tmp/some-spec.md")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && ok "AC11: pending_review triggers decision:block reason+systemMessage with required tokens (incl. terminal handoff)" \
  || no "AC11 failed (rc=$rc out=$out)"

# Case 12: AC12 — no pending_review → silent exit 0
setup_state "test-012" "---
session_id: test-012
---
"
out=$(run_hook "test-012")
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && ok "AC12: no pending_review silent" \
  || no "AC12 failed (rc=$rc out=$out)"

# Case 13: AC13 — dispatch removes pending_review + sets last_dispatched_at;
# second call within TTL is silent.
setup_state "test-013" "---
session_id: test-013
---

pending_review:
  path: /tmp/p.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out1=$(run_hook "test-013")
rc1=$?
out2=$(run_hook "test-013")
rc2=$?
[[ $rc1 -eq 0 ]] && [[ $rc2 -eq 0 ]] && [[ -z "$out2" ]] \
  && ! grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-013/state.local.md" \
  && grep -q '^last_dispatched_at:' "$WORK/.claude/spec-distill/test-013/state.local.md" \
  && ok "AC13: dispatch consumes block; re-fire within TTL silent" \
  || no "AC13 failed (rc1=$rc1 rc2=$rc2 out2=$out2)"

# Case 14 (T-1): Stop hook kill switch via DEVBREW_SKIP_HOOKS=spec-distill:Stop
setup_state "test-014" "---
session_id: test-014
---

pending_review:
  path: /tmp/k.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-014 \
  DEVBREW_SKIP_HOOKS="spec-distill:Stop" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-014/state.local.md" \
  && ok "AC14 (T-1): kill switch spec-distill:Stop suppresses emit + preserves state" \
  || no "AC14 failed (rc=$rc out=$out)"

# Case 15 (T-1): kill switch via DEVBREW_SKIP_HOOKS=spec-distill:review-dispatch (alias)
setup_state "test-015" "---
session_id: test-015
---

pending_review:
  path: /tmp/k2.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-015 \
  DEVBREW_SKIP_HOOKS="spec-distill:review-dispatch" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && grep -q '^pending_review:' "$WORK/.claude/spec-distill/test-015/state.local.md" \
  && ok "AC15 (T-1): kill switch :review-dispatch alias suppresses emit" \
  || no "AC15 failed (rc=$rc out=$out)"

# Case 16: dispatch 1회차 — attempts=1 기록, armed_paths는 **안 씀** (T10 계열).
# 완료 기록은 verdict 시점 mark-reviewed의 몫이다(§5.2).
setup_state "test-016" "---
session_id: test-016
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-x-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-016")
rc=$?
sf16="$WORK/.claude/spec-distill/test-016/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^armed_paths:' "$sf16" \
  && grep -q '^  docs/superpowers/specs/2026-01-01-x-design.md: 1$' "$sf16" \
  && ok "§5.2: dispatch 1회차 → attempts=1, armed_paths 미기록" \
  || no "dispatch 1회차 실패 (rc=$rc out='$out' state=$(cat "$sf16"))"

# Case 17: G6 상한 — attempts가 이미 2면 이번 dispatch가 3회차. emit에 상한 advisory가
# 붙고 armed_paths에 키가 생긴다. "4회차가 억제된다"가 아니라 3회차가 마지막 자동
# dispatch이고 그 emit이 상한을 알리는 vehicle이다(§5.2 상태기계).
setup_state "test-017" "---
session_id: test-017
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-cap-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

dispatch_attempts:
  docs/superpowers/specs/2026-01-01-cap-design.md: 2
"
out=$(run_hook "test-017")
rc=$?
sf17="$WORK/.claude/spec-distill/test-017/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("3회 시도")' >/dev/null \
  && grep -q '^  - docs/superpowers/specs/2026-01-01-cap-design.md$' "$sf17" \
  && grep -q '^  docs/superpowers/specs/2026-01-01-cap-design.md: 3$' "$sf17" \
  && ok "G6: 3회차 emit에 상한 advisory + armed_paths 기록" \
  || no "G6 상한 실패 (rc=$rc out='$out' state=$(cat "$sf17"))"

# Case 18: 스코프 밖 pending(정규화 키 없음)은 attempts를 추적하지 않고도 정상 dispatch.
setup_state "test-018" "---
session_id: test-018
---

pending_review:
  path: /tmp/out-of-scope-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-018")
sf18="$WORK/.claude/spec-distill/test-018/state.local.md"
echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^dispatch_attempts:' "$sf18" \
  && ok "스코프 밖 pending → 정상 dispatch, attempts 미추적" \
  || no "out-of-scope dispatch 실패 (out='$out')"
finish
