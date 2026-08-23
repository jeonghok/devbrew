#!/usr/bin/env bash
# A20·A22 — 기본 scope 정의가 git 에서 오고, 판정-불가 degrade 분기가 살아 있다.
#
# NOTE: 원래 브리프의 다섯 번째 검사(리포 전체 files.md 살아있는 참조 0건)는
# 이 락에 포함하지 않는다 — 그 검사는 자기 자신의 본문에 있는 'files.md' 리터럴
# (check #2의 grep 대상 + 실패 메시지)을 스스로 매치해 통과할 수 없고, 리포 전체
# 스윕(다른 참조 정리)은 별도 task의 소유이기 때문이다.
#
# NOTE: check #1 은 원래 "정의가 check-review-scope.sh 를 근거로
# 든다"였다 — 그런데 그 자체가 CRITICAL 결함이었다. $resolved_scope_file_count 를
# check-review-scope.sh 의 산출값(예: $branch_ahead_count)으로 정의하면, 그 값과
# 정직-verdict floor 가 비교하는 $changes_exist(같은 스크립트가 emit)가 항상 같은
# 소스에서 나와 서로 disagree 할 수 없게 되고, session(default)·branch 모드에서
# floor 의 첫 분기(`resolved_scope_file_count == 0 AND changes_exist == yes`)가
# 영원히 도달 불가능해진다 — floor 가 무력화된다. 수정: $resolved_scope_file_count
# 는 오케스트레이터가 step 1 에서 실제로 resolve·review 한 집합의 크기이지,
# check-review-scope.sh 의 산출값이 아니다. check #1 을 그 정의로 교체하고, 원래
# 결함이었던 등식("정의가 $branch_ahead_count 로 정의된다")의 재발을 잡는 새 음의
# 검사(check #1b)를 추가한다.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md

# 앵커는 내용으로 찾는다 — 재작성된 단락의 시작 문구가 바뀌었으므로 awk 시작
# 패턴도 그 문구를 따라간다. 대상을 못 찾으면 즉시, 크게 실패한다(무음 통과 금지).
DEF="$(awk '/resolved_scope_file_count. = the size of the file set/,/do not re-measure/' "$SK")"
[[ -n "$DEF" ]] || { no "정의 단락을 찾지 못했다 (앵커 이동)"; exit 1; }

# 양의 짝 — 정의가 "오케스트레이터가 실제로 resolve·review 한 집합의 크기"라고
# 말한다(=check-review-scope.sh 의 산출값이 아니다).
grep -qF 'the size of the file set you actually resolved' <<<"$DEF" \
  && ok "A22: 정의가 실제로 resolve·review 한 집합의 크기라고 말한다" \
  || no "A22: 정의가 더 이상 resolve 된 집합의 크기를 claim하지 않는다"

# 음의 짝 — 그 정의가 $branch_ahead_count 로 등식화되지 않는다. floor 를
# 무력화시킨 원래 결함은 정확히 이 등식이었다: $resolved_scope_file_count =
# $branch_ahead_count. 위 양의 짝은 "resolve 한 집합" 문구가 남아 있으면서
# $branch_ahead_count 등식이 다시 추가된 문서도 통과시킨다(추가는 위 체크를 안
# 건드리므로) — 그래서 별도 체크가 필요하다.
grep -qF '$branch_ahead_count' <<<"$DEF" \
  && no "A22: 정의가 다시 \$branch_ahead_count 로 등식화됐다 (floor 무력화 재발)" \
  || ok "A22: 정의가 \$branch_ahead_count 와 등식화되지 않는다"

# 음의 짝 — 그 정의가 files.md 를 근거로 들지 않는다.
grep -qF 'files.md' <<<"$DEF" \
  && no "A22: 정의가 아직 files.md 를 근거로 든다" \
  || ok "A22: 정의에 files.md 없음"

# degrade 분기 보존 — 판정 불가를 조용히 0으로 취급하지 않는다.
grep -qF 'do NOT silently treat it as 0' <<<"$DEF" \
  && ok "A22: 판정-불가 degrade 분기 생존" \
  || no "A22: degrade 분기가 사라졌다"

# 정직-verdict floor 자체는 이 작업이 건드리지 않는다 (양성 대조 — GREEN 이 정답).
grep -qF 'NOT certified clean' "$SK" \
  && ok "양성 대조: 정직-verdict floor 문구 생존" \
  || no "양성 대조 실패: floor 문구가 사라졌다"

exit $FAIL
