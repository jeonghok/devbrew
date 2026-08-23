#!/usr/bin/env bash
# A20·A22 — 기본 scope 정의가 git 에서 오고, 판정-불가 degrade 분기가 살아 있다.
#
# NOTE (R22): 원래 브리프의 다섯 번째 검사(리포 전체 files.md 살아있는 참조 0건)는
# 이 락에 포함하지 않는다 — 그 검사는 자기 자신의 본문에 있는 'files.md' 리터럴
# (check #2의 grep 대상 + 실패 메시지)을 스스로 매치해 통과할 수 없고, 리포 전체
# 스윕(다른 9개 참조 정리)은 다음 task의 소유이기 때문이다. 이 락은 이 task가
# 실제로 소유하는 네 가지 — SKILL.md 의 $resolved_scope_file_count 정의 — 만
# 검사한다.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md

# 양의 짝 — $resolved_scope_file_count 정의가 git 을 근거로 든다.
DEF="$(awk '/resolved_scope_file_count. = the file count/,/do not re-measure/' "$SK")"
[[ -n "$DEF" ]] || { no "정의 단락을 찾지 못했다 (앵커 이동)"; exit 1; }
grep -qF 'check-review-scope.sh' <<<"$DEF" \
  && ok "A22: 정의가 check-review-scope.sh 를 근거로 든다" \
  || no "A22: 정의가 git 산출 신호를 근거로 들지 않는다"

# 음의 짝 — 그 정의가 files.md 를 근거로 들지 않는다. 양의 짝은 두 근거를 함께
# 적은 문서를 통과시킨다(추가는 통과, 삭제만 잡힌다).
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
