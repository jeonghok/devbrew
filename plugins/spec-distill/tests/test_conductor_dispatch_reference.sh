#!/usr/bin/env bash
# R5 계획 3 — 하위에게 보내는 글(`references/conductor-dispatch.md`): AC21 의 항목 · 두 부분 반환(AC45) · 처분 줄 ·
# 미리 받은 답과 돌려보낼 자리의 구분(결정 H) · 단계마다 새 agent(결정 I). 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
F="$ROOT/plugins/spec-distill/references/conductor-dispatch.md"
[ -f "$F" ] && ok "conductor-dispatch.md 가 있다" || { no "conductor-dispatch.md 가 없다"; finish; exit $?; }
TXT="$(cat "$F")"
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^## /{exit} f' "$F"; }
for h in '## 늘 싣는 것' '## 사람 자리' '## 단계마다 새 agent' '## 마지막 보고' '## 틀'; do
  assert_eq "$(grep -cxF -- "$h" "$F" || true)" "1" "절 머리 「${h}」 가 정확히 하나"
done
once() {  # once <절> <문장>
  assert_eq "$(sec "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "${1}: 「${2}」 정확히 한 번"
}
for lit in '그 에픽 worktree 의 절대경로' '고른 흐름과 그 이유' '단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지' \
           '`TMPDIR`' '공유 임시 폴더의 glob 삭제' '`git stash`' '다른 worktree 의 git 조작' '`Spec: <설계문서 레포 상대경로>`' \
           'HEAD 를 뒤로 옮기지 않는다' 'pathspec'; do
  once '## 늘 싣는 것' "$lit"
done
assert_eq "$(grep -cxF -- '**처분** — consumer=orchestrator · fail-closed · disclosure=하위가 돌려보낸 사람 자리 원문(쉬운 배경 뒤 늘 첨부) · 판정 목록 · AC 보고를 빠짐없이 사용자에게 보인다' "$F" || true)" "1" "처분 줄이 설계 §4 글자 그대로 한 줄"
for lit in '「브랜치 그대로 두기」(3번)' 'Push 와 PR 은 지휘자가 구현 대조 뒤에 한다' '구현 agent 를 보낼 때만' \
           '계획 agent 에게는 싣지 않는다' '(a) 사람에게 보일 쉬운 요약' '(b) skill 이 낸 문면 원문' '내부 기호는 괄호에만' \
           '수 · 순서 · 라벨 · 「(권장)」' '「지휘자 의견:」 한 줄' '원문은 늘 붙인다' '사용자 답은 글자 그대로 같은 agent 에 돌려준다' \
           '쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다' '그 자리만 지휘자가 직접 돌리는 길로 되돌리고'; do
  once '## 사람 자리' "$lit"
done
for lit in '계획 agent' '구현 agent 는 새로 보낸다' '커밋된 계획 경로 · 설계문서 경로' '리뷰 엔진의 문서별 상태 경로'; do
  assert_contains "$(sec '## 단계마다 새 agent')" "$lit" "단계마다 새 agent: $lit"
done
once '## 단계마다 새 agent' '같은 agent 를 이어 부른다(`SendMessage`)'
once '## 단계마다 새 agent' '실행 방식 답은 계획 agent 에 돌려주지 않고 새 구현 agent 의 미리 받은 답으로 싣는다'
once '## 단계마다 새 agent' '계획만 고치고 커밋한 뒤 다시 멈춘다 — 실행 skill 로 넘어가지 않는다'
for lit in '판정 전체' 'AC 보고 내용 전체' '경로만으로는 부족하다' '잠긴 스위트 대조' '경합으로 보고'; do
  once '## 마지막 보고' "$lit"
done
TPL="$(sec '## 틀')"
for lit in '### 계획 agent' '### 구현 agent' '### 이어 부르기'; do
  assert_contains "$TPL" "$lit" "틀: $lit"
done
assert_contains "$TPL" 'check_bundle_coverage.py --plan' "계획 틀: --plan 대조"
assert_not_contains "$TXT" 'CLAUDE_PLUGIN_ROOT' "플러그인 루트 토큰을 쓰지 않는다(<SD> 자리표)"
# 부재 락 — 옛 결정(실행 방식 고정 · Push 후 PR · 계획 검토 무대기)
bad="$(printf '%s\n' "$TXT" | grep -nE 'Push 후 PR|푸시 후 PR|계획 검토는 기다리지 않|언제나 subagent|항상 subagent' || true)"
assert_eq "$bad" "" "옛 결정 문면이 없다"
for lit in 'Push 후 PR 을 고른다' '계획 검토는 기다리지 않는다' '실행 방식은 언제나 subagent-driven'; do
  [ -n "$(printf '%s\n' "$lit" | grep -nE 'Push 후 PR|푸시 후 PR|계획 검토는 기다리지 않|언제나 subagent|항상 subagent' || true)" ] \
    && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
finish
