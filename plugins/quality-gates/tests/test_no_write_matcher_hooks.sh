#!/usr/bin/env bash
# quality-gates 훅 표면 락 — v10.0.0 부터 훅이 하나도 없다. hooks/ 와 plugin.json "hooks" 키의 부재가 옛 A1·A2
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

# 훅은 plugin.json 에 인라인(`"hooks"` 키)으로도 선언된다 — hooks/ 부재만으로는 그 길을 못 본다.
PJ=plugins/quality-gates/.claude-plugin/plugin.json
pj="$(python3 -c 'import json, sys
d = json.load(open(sys.argv[1], encoding="utf-8"))
print("name=" + str(d.get("name")) + " hooks=" + ("yes" if "hooks" in d else "no"))' "$PJ" 2>/dev/null || echo unreadable)"
[[ "$pj" == *"hooks=no"* ]] \
  && ok "A1/A2: plugin.json 에 \"hooks\" 키가 없다 (인라인 훅 0개)" || no "A1/A2: plugin.json 에 \"hooks\" 키가 있거나 읽지 못했다 ($pj)"
# 양의 짝 — 위 부재가 파싱 실패나 다른 파일을 읽어서 공허하게 참이 아니다.
[[ "$pj" == "name=quality-gates "* ]] \
  && ok "양의 짝: plugin.json 을 읽었고 name 이 quality-gates 다" || no "plugin.json 을 읽지 못했다 — 위 부재는 공허하다 ($pj)"

exit $FAIL
