#!/usr/bin/env bash
# quality-gates 훅 표면 락 — 쓰기 도구에 발화하는 PostToolUse 항목이 없다 (설계 A1·A2).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok()  { echo "  ✓ $1"; }
no()  { echo "  ✗ $1"; FAIL=1; }

if python3 - <<'PY'
import json, sys
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
p = "plugins/quality-gates/hooks/hooks.json"
entries = json.load(open(p, encoding="utf-8"))["hooks"].get("PostToolUse", [])
bad = []
for e in entries:
    m = e.get("matcher")
    # 키 부재와 빈 문자열은 둘 다 "전체 도구 발화" 다 (실측, Claude Code 2.1.239).
    if not m:
        bad.append(("<matcher 부재 또는 빈 문자열>", e))
        continue
    if WRITE_TOOLS & set(x.strip() for x in m.split("|")):
        bad.append((m, e))
if bad:
    for m, e in bad:
        print(f"BAD matcher={m!r} entry={e}", file=sys.stderr)
    sys.exit(1)
# A2 (v7.0.0): PostToolUse 항목은 **하나도 없다** — `gh pr create` 자동 트리거 훅을 제거했고
# 다른 PostToolUse 훅은 없다. 위 A1 은 리스트가 비면 공허참이라, 이 검사가 그 양성 짝이다
# (항목을 하나라도 되살리면 RED).
if entries:
    print(f"PostToolUse 항목이 되살아났다: {entries}", file=sys.stderr)
    sys.exit(1)
PY
then ok "A1/A2: quality-gates 에 PostToolUse 훅 없음"; else no "A1/A2 위반"; fi

# 음의 짝 — 삭제된 훅 파일이 실제로 없다. 양의 짝(matcher 검사)은 hooks.json 만 보므로
# 파일이 남아 있어도 통과한다. 이 검사를 지우면 그 사실이 안 보인다.
[[ ! -e plugins/quality-gates/hooks/post-tool-use-session-tracker.py ]] \
  && ok "A3: session-tracker 부재" || no "A3: session-tracker 가 남아 있다"
[[ ! -e plugins/quality-gates/hooks/post-tool-use.py ]] \
  && ok "A4: pr-create 자동 트리거 훅 부재 (v7.0.0)" || no "A4: post-tool-use.py 가 남아 있다"

exit $FAIL
