#!/usr/bin/env bash
# project-init 훅 표면 락 — 쓰기 도구에 발화하는 PostToolUse 항목이 없다 (설계 A1·A2).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok()  { echo "  ✓ $1"; }
no()  { echo "  ✗ $1"; FAIL=1; }

if python3 - <<'PY'
import json, sys
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
p = "plugins/project-init/hooks/hooks.json"
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
# 양성 대조: Bash matcher 는 위반이 아니다 — 하나는 남아 있어야 한다 (A2).
if not any(e.get("matcher") == "Bash" for e in entries):
    print("Bash matcher 항목이 사라졌다 — 양성 대조 실패", file=sys.stderr)
    sys.exit(1)
PY
then ok "A1/A2: project-init PostToolUse 에 쓰기-도구 matcher 없음 + Bash 항목 생존"; else no "A1/A2 위반"; fi

# 음의 짝 — 삭제된 훅 파일이 실제로 없다. 양의 짝(matcher 검사)은 hooks.json 만 보므로
# 파일이 남아 있어도 통과한다. 이 검사를 지우면 그 사실이 안 보인다.
[[ ! -e plugins/project-init/hooks/docs-lint.py ]] \
  && ok "A3: docs-lint.py 부재" || no "A3: docs-lint.py 가 남아 있다"

exit $FAIL
