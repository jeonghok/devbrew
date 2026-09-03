#!/usr/bin/env bash
# MU12 — 감사 축 3 이 「지시가 수신자에게 도달하는가」를 묻는가.
#
# AXES 는 audit-workflow.js 의 export 없는 모듈 지역 const 라 import 할 수 없다
# (그 파일이 export 하는 것은 meta 하나뿐). 락 하나를 위해 공개 표면을 넓히는
# 대신 소스 텍스트를 축 3 객체 창으로 잡는다.
#
# 창은 `n: 3,` 부터 `n: 4,` 앞까지 — 파일 전역으로 읽으면 다른 축에 적힌 문구로도
# 만족되고, 새로 더한 줄만으로 읽으면 그 줄이 사라졌을 때 공허참이다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
WF="$REPO_ROOT/plugins/plugin-audit/scripts/audit-workflow.js"
. "$REPO_ROOT/shared/tests/assert.sh"
test -f "$WF" || { echo "FAIL: audit-workflow.js missing at $WF"; exit 1; }

AX3="$(awk '/^[[:space:]]*n: 3,/{f=1} f{print} f&&/^[[:space:]]*n: 4,/{exit}' "$WF")"

# (1) 양성 증인 — 창이 실재한다.
[ -n "$AX3" ] && ok "축 3 창이 실재한다 (앵커 유효)" \
  || no "축 3 창이 비었다 — 앵커가 죽었다. 아래 단언이 공허참이 된다"

# (2) 양성 증인 — 그 창이 축 3 의 원래 질문을 **여전히** 담는다.
#     더하는 것이지 대체하는 것이 아니다.
grep -qF '무엇을 막는가' <<<"$AX3" \
  && ok "축 3 의 원래 질문 보존" \
  || no "축 3 의 원래 질문이 사라졌다 — 추가가 아니라 대체를 했다"
grep -qF 'kill switch' <<<"$AX3" \
  && ok "축 3 의 kill switch 항목 보존" \
  || no "축 3 의 kill switch 항목이 사라졌다"

# (3) 새 질문 — 채널.
grep -qF 'systemMessage' <<<"$AX3" \
  && ok "축 3 이 사람 채널을 이름으로 묻는다" \
  || no "축 3 이 systemMessage 를 사람 채널로 지목하지 않는다"

# (4) 새 질문 — 값 전달의 도착 확인.
grep -qF '도착했는지 확인하는 자리' <<<"$AX3" \
  && ok "축 3 이 값 전달의 도착 확인을 묻는다" \
  || no "축 3 이 도착 확인 자리를 묻지 않는다"

# (5) 축을 만들지 않았다 — AXES 원소는 여섯 그대로.
NAX="$(grep -cE '^[[:space:]]*n: [0-9]+,' "$WF")"
[ "$NAX" -eq 6 ] && ok "AXES 원소 6 유지 (축을 만들지 않았다)" \
  || no "AXES 원소가 ${NAX}개 — 축을 추가·삭제했다. 이 작업은 질문만 더한다"
finish
