#!/usr/bin/env bash
# quality-gates 훅 표면 락 — v10.0.0 부터 훅이 하나도 없다. hooks/ 의 부재가 옛 A1·A2
# (쓰기 도구에 발화하는 PostToolUse 항목 없음)를 함의한다.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok()  { echo "  ✓ $1"; }
no()  { echo "  ✗ $1"; FAIL=1; }

[[ ! -e plugins/quality-gates/hooks ]] \
  && ok "A1/A2: quality-gates 에 hooks/ 가 없다 (훅 0개 — v10)" || no "A1/A2: hooks/ 가 되살아났다"
# 양의 짝 — 위 부재가 경로 오타나 cwd 착오로 공허하게 참이 아니다.
[[ -d plugins/quality-gates/agents ]] \
  && ok "양의 짝: plugins/quality-gates/agents 는 있다" || no "plugins/quality-gates 를 못 찾았다 — 위 부재는 공허하다"

exit $FAIL
