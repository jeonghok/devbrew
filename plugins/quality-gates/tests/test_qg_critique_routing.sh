#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md
# AC6 — 명령 층이 없고, 파이프라인에 문서 비평 인자가 오면 새 이름을 안내하고 실행하지 않는다.
set -u
[ "${1:-}" = "--emit-scanned" ] && { printf '%s\n' plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md; exit 0; }
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
assert_eq "$(ls "$ROOT/plugins/quality-gates/commands" 2>/dev/null | wc -l | tr -d ' ')" "0" "commands/ 층이 없다"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
( cd "$T" && git init -q . && git commit -q --allow-empty -m init )
out="$(cd "$T" && CLAUDE_CODE_SESSION_ID=session-routing-1 bash "$ROOT/plugins/quality-gates/scripts/setup-qg.sh" critique docs/x.md 2>&1)"; rc=$?
assert_eq "$rc" "2" "critique 인자: exit 2(실행하지 않는다)"
assert_contains "$out" "/quality-gates:artifact-critique" "critique 인자: 새 이름을 안내한다"
assert_eq "$(find "$T/.claude" -type f 2>/dev/null | wc -l | tr -d ' ')" "0" "critique 인자: 아무것도 쓰지 않는다"
# 실제 호출 모양(SKILL P2: `setup-qg.sh --ensure $ARGUMENTS`) — critique 는 첫 인자가 아니다.
T2="$(mktemp -d)"; trap 'rm -rf "$T" "$T2"' EXIT
( cd "$T2" && git init -q . && git commit -q --allow-empty -m init )
out2="$(cd "$T2" && CLAUDE_CODE_SESSION_ID=session-routing-2 bash "$ROOT/plugins/quality-gates/scripts/setup-qg.sh" --ensure critique docs/x.md 2>&1)"; rc2=$?
assert_eq "$rc2" "2" "--ensure critique: exit 2(P2 의 실제 모양)"
assert_contains "$out2" "/quality-gates:artifact-critique" "--ensure critique: 새 이름을 안내한다"
assert_eq "$(find "$T2/.claude" -type f 2>/dev/null | wc -l | tr -d ' ')" "0" "--ensure critique: 아무것도 쓰지 않는다"
SK="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
assert_contains "$(cat "$SK")" '## 진입 단계' "quality-pipeline 은 진입 단계 절을 가진다"
assert_contains "$(cat "$SK")" 'setup-qg.sh" --ensure $ARGUMENTS' "인자 확인은 본문 P2 가 한다(사전 검사 줄이 아니다)"
# 자연어 문서 비평 요청은 setup 이 아니라 P2 앞의 본문 지시(P1b)가 새 이름으로 안내한다.
SKB="$(cat "$SK")"
P1B="$(printf '%s\n' "$SKB" | awk '/^\*\*P1b — /{f=1} /^\*\*P2 — /{f=0} f')"
assert_contains "$P1B" "/quality-gates:artifact-critique" "P1b: P2 앞 지시가 새 이름을 안내한다"
assert_contains "$P1B" "setup 도 돌리지 않은 채 멈춘다" "P1b: 안내 뒤 setup 을 돌리지 않는다"
assert_contains "$P1B" "코드 변경을 검증해 달라는 요청에는 적용하지 않는다" "P1b: 코드 요청은 P2 로 간다(음의 짝)"
for args in "branch critique" "--paths critique" "--paths a/* critique" "range critique" "--ensure critique"; do
  out="$(cd "$T" && bash "$ROOT/plugins/quality-gates/scripts/setup-qg.sh" --session-id "crit-$$-x1" $args 2>&1)"; rc=$?
  assert_eq "$rc" "2" "critique 위치 무관($args): exit 2"
  assert_contains "$out" "/quality-gates:artifact-critique" "critique 위치 무관($args): 새 이름 안내"
done
out="$(cd "$T" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$ROOT/plugins/quality-gates/scripts/setup-qg.sh" critique 2>&1)"; rc=$?
assert_eq "$rc" "1" "kill switch 가 critique 안내보다 먼저다(첫 인자)"
assert_contains "$out" "DEVBREW_QUALITY_GATES_DISABLE" "kill switch 메시지가 나온다(첫 인자)"
out="$(cd "$T" && DEVBREW_QUALITY_GATES_DISABLE=1 bash "$ROOT/plugins/quality-gates/scripts/setup-qg.sh" --ensure critique 2>&1)"; rc2=$?
assert_eq "$rc2" "$rc" "kill switch 결과는 critique 위치와 무관하다"
assert_contains "$out" "DEVBREW_QUALITY_GATES_DISABLE" "kill switch 메시지가 나온다(--ensure 뒤)"
p1b=$(grep -n '^\*\*P1b — ' "$SK" | cut -d: -f1); p2=$(grep -n '^\*\*P2 — ' "$SK" | cut -d: -f1)
assert_grep "$p1b" '^[0-9]+$' "P1b 줄을 찾았다(양성 짝)"
[ "$p1b" -lt "$p2" ] && ok "P1b 가 P2 보다 앞이다" || no "P1b 가 P2 보다 뒤다 — 문서 비평 요청이 setup 을 먼저 돌린다"
finish
