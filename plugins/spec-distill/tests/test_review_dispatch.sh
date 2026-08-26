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

FIXTURE="$REPO_ROOT/plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md"

# dispatch 의 연료는 **git 이 보는 dirty 스코프 문서**다. 상태 파일의 블록이 아니다.
seed_doc() {  # $1 = WORK 기준 상대 경로
  mkdir -p "$WORK/$(dirname "$1")"
  cp "$FIXTURE" "$WORK/$1"
}
# 앞 케이스의 문서를 커밋해 발견에서 뺀다. 발견은 세션이 아니라 git 을 보므로,
# 남겨 두면 앞 케이스의 문서가 뒤 케이스의 emit 을 오염시킨다 — 케이스마다 세션
# id 는 다르지만 리포는 하나다.
retire_docs() { ( cd "$WORK" && git add -A -- docs && git commit -q -m retire ) >/dev/null 2>&1; }

# Case 11: AC11 — 발견된 dirty 스코프 문서 → decision:block emit
REL11="docs/superpowers/specs/2026-05-16-ac11-design.md"
retire_docs; seed_doc "$REL11"
setup_state "test-011" "---
session_id: test-011
---
"
out=$(run_hook "test-011")
rc=$?
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("MANDATORY")' >/dev/null \
  && echo "$out" | jq -e --arg p "$WORK/$REL11" '.reason | contains($p)' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("reviewing-spec")' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("terminal handoff")' >/dev/null \
  && echo "$out" | jq -e '.systemMessage | startswith("[spec-distill]")' >/dev/null \
  && ok "AC11: 발견된 문서가 decision:block reason+systemMessage 를 낸다 (절대경로·terminal handoff 포함)" \
  || no "AC11 failed (rc=$rc out=$out)"

# Case 12: AC12 — dirty 스코프 문서가 없으면 침묵한다 (exit 0)
retire_docs
setup_state "test-012" "---
session_id: test-012
---
"
out=$(run_hook "test-012")
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] && ok "AC12: 후보 없음 → 침묵" \
  || no "AC12 failed (rc=$rc out=$out)"

# Case 13: AC13 — dispatch 는 문서를 in-flight 로 찍고 last_dispatched_at 을 세운다.
# 같은 문서에 대한 두 번째 발화는 침묵한다(둘 중 어느 가드가 먼저 걸리든 성질은 하나:
# 한 번 강제한 리뷰를 같은 턴 뒤에 또 강제하지 않는다).
REL13="docs/superpowers/specs/2026-05-16-ac13-design.md"
retire_docs; seed_doc "$REL13"
setup_state "test-013" "---
session_id: test-013
---
"
out1=$(run_hook "test-013")
rc1=$?
out2=$(run_hook "test-013")
rc2=$?
sf13="$WORK/.claude/spec-distill/test-013/state.local.md"
[[ $rc1 -eq 0 ]] && [[ $rc2 -eq 0 ]] \
  && echo "$out1" | jq -e '.decision == "block"' >/dev/null \
  && [[ -z "$out2" ]] \
  && grep -qE "^  $REL13: 20[0-9][0-9]-" "$sf13" \
  && grep -q '^last_dispatched_at:' "$sf13" \
  && ok "AC13: dispatch → in-flight 표시 + last_dispatched_at; 재발화는 침묵" \
  || no "AC13 failed (rc1=$rc1 rc2=$rc2 out1=$out1 out2=$out2)"

# Case 14 (T-1): Stop hook kill switch via DEVBREW_SKIP_HOOKS=spec-distill:Stop
# **후보를 반드시 깔아 둔다.** kill switch 없이도 조용한 상태에서 "조용하다"를 재면
# 아무것도 재지 않는 것과 같다 — 그 vacuity 의 양성 대조가 바로 위 Case 11 이다.
# 상태 파일이 그대로인 것(발견 커서·in-flight 미기록)이 훅이 정말 안 돌았다는 증거다.
REL14="docs/superpowers/specs/2026-05-16-ac14-design.md"
retire_docs; seed_doc "$REL14"
setup_state "test-014" "---
session_id: test-014
---
"
before14=$(cat "$WORK/.claude/spec-distill/test-014/state.local.md")
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-014 \
  DEVBREW_SKIP_HOOKS="spec-distill:Stop" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && [[ "$before14" == "$(cat "$WORK/.claude/spec-distill/test-014/state.local.md")" ]] \
  && ok "AC14 (T-1): kill switch spec-distill:Stop suppresses emit + preserves state" \
  || no "AC14 failed (rc=$rc out=$out)"

# Case 15 (T-1): kill switch via DEVBREW_SKIP_HOOKS=spec-distill:review-dispatch (alias)
REL15="docs/superpowers/specs/2026-05-16-ac15-design.md"
retire_docs; seed_doc "$REL15"
setup_state "test-015" "---
session_id: test-015
---
"
before15=$(cat "$WORK/.claude/spec-distill/test-015/state.local.md")
out=$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=test-015 \
  DEVBREW_SKIP_HOOKS="spec-distill:review-dispatch" \
  bash -c "echo '{}' | python3 '$HOOK'" 2>/dev/null)
rc=$?
[[ $rc -eq 0 ]] && [[ -z "$out" ]] \
  && [[ "$before15" == "$(cat "$WORK/.claude/spec-distill/test-015/state.local.md")" ]] \
  && ok "AC15 (T-1): kill switch :review-dispatch alias suppresses emit" \
  || no "AC15 failed (rc=$rc out=$out)"

# Case 16: dispatch 1회차 — attempts=1 기록, armed_paths는 **안 씀** (T10 계열).
# 완료 기록은 verdict 시점 mark-reviewed의 몫이다(§5.2).
REL16="docs/superpowers/specs/2026-01-01-x-design.md"
retire_docs; seed_doc "$REL16"
setup_state "test-016" "---
session_id: test-016
---
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
REL17="docs/superpowers/specs/2026-01-01-cap-design.md"
retire_docs; seed_doc "$REL17"
setup_state "test-017" "---
session_id: test-017
---

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

# Case 18: 스코프 밖 dirty 문서는 dispatch 되지 않는다.
# 방향이 뒤집혔다. 연료가 상태 파일이던 시절엔 스코프 밖 경로도 pending 에 적히면
# dispatch 됐다(키가 없어 attempts 만 추적 못 했다). 지금 dispatch 대상은 발견에서
# 오고 발견의 in-scope 술어는 `canonical_key(path) is not None` 이므로, 스코프 밖
# 문서는 후보 집합에 **들어오지도 않는다**. 이 케이스가 공허하지 않은 것은 바로 위
# Case 16·17 이 같은 하니스에서 in-scope 문서의 dispatch 를 보이기 때문이다.
retire_docs
mkdir -p "$WORK/docs/notes"
cp "$FIXTURE" "$WORK/docs/notes/out-of-scope-design.md"
setup_state "test-018" "---
session_id: test-018
---
"
out=$(run_hook "test-018")
sf18="$WORK/.claude/spec-distill/test-018/state.local.md"
[[ -z "$out" ]] \
  && ! grep -q '^dispatch_attempts:' "$sf18" \
  && ok "스코프 밖 dirty 문서 → 무-dispatch, attempts 미기록" \
  || no "out-of-scope 문서가 dispatch 됐다 (out='$out')"
finish
