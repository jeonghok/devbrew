#!/usr/bin/env bash
# A1 — 리포의 **어떤** 플러그인도 쓰기 도구에 발화하는 PostToolUse 훅을 갖지 않는다.
# 대상은 하드코딩이 아니라 glob 으로 도출한다 — 네 번째 플러그인이 같은 결함을
# 들고 와도 RED 여야 한다.
#
# 이 락은 음의 락(“위반 0건”)이라 코퍼스가 비면 공허하게 통과한다. 그래서 양의 짝을
# 넷 붙인다: 정의역이 비지 않았다(`assert paths`), 정의역이 줄지 않았다
# (`assert scanned >= 3`), 면제가 실제로 무언가를 면제하고 있다(양성 대조 3),
# 그리고 이 fix 가 남겨야 할 것들이 살아 있다(양성 대조 1·2).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }

# 면제 경로의 **단일 정의** — 아래 python 블록과 양성 대조 3 이 같은 값을 쓴다.
# 둘로 나눠 적으면 한쪽만 고쳐도 조용히 통과하는 drift 가 생긴다.
EXEMPT_FIXTURE="shared/tests/fixtures/hookprobe/hooks/hooks.json"

if python3 - "$EXEMPT_FIXTURE" <<'PY'
import glob, json, sys
WRITE_TOOLS = {"Write", "Edit", "MultiEdit", "NotebookEdit"}
# 커밋된 프로브 픽스처는 matcher 없는 PostToolUse 항목을 **의도적으로** 갖고 있다
# (2026-08-22 헤드리스 실측용). 면제이며, 그 이유가 여기 적혀 있어야 면제다.
EXEMPT = {sys.argv[1]}
paths = sorted(set(glob.glob("plugins/*/hooks/hooks.json")
                   + glob.glob("shared/**/hooks/hooks.json", recursive=True)))
assert paths, "hooks.json 을 하나도 찾지 못했다 — glob 이 깨졌다 (계측기 고장)"
bad, scanned = [], 0
for p in paths:
    if p in EXEMPT:
        continue
    scanned += 1
    for e in json.load(open(p, encoding="utf-8"))["hooks"].get("PostToolUse", []):
        m = e.get("matcher")
        # 키 부재와 빈 문자열은 둘 다 "전체 도구 발화" 다 (실측, Claude Code 2.1.239).
        if not m:
            bad.append((p, "<matcher 부재 또는 빈 문자열>"))
        elif WRITE_TOOLS & {x.strip() for x in m.split("|")}:
            bad.append((p, m))
assert scanned >= 3, f"검사한 파일이 {scanned}개뿐이다 — 정의역이 좁아졌다"
for p, m in bad:
    print(f"BAD {p} matcher={m!r}", file=sys.stderr)
sys.exit(1 if bad else 0)
PY
then ok "A1: 리포 전수 — 쓰기-도구 matcher 를 가진 PostToolUse 훅 0개"
else no "A1: 위반 발견 (위 BAD 줄 참조) 또는 정의역이 무너졌다"
fi

# 양성 대조 1 — Bash matcher 는 살아 있다 (GREEN 이 정답, A2).
N_BASH=$(grep -l '"matcher": "Bash"' plugins/*/hooks/hooks.json 2>/dev/null | wc -l | tr -d ' ')
[[ "$N_BASH" -ge 2 ]] && ok "양성 대조: Bash matcher 훅 ${N_BASH}개 생존" \
                      || no "양성 대조 실패: Bash matcher 훅이 ${N_BASH}개뿐"

# 양성 대조 2 — 기록물에 남은 이름은 위반이 아니다 (GREEN 이 정답).
grep -q 'spec-write-validator' plugins/spec-distill/CHANGELOG.md \
  && ok "양성 대조: CHANGELOG 의 은퇴 기록 생존" \
  || no "양성 대조 실패: CHANGELOG 에서 은퇴 기록이 사라졌다 (Law 3 substrate 파괴)"

# 양성 대조 3 — 면제가 실제로 무언가를 면제하고 있다.
# `EXEMPT` 는 픽스처가 matcher 없는 PostToolUse 항목을 갖고 있기 **때문에** 존재한다.
# 픽스처가 모양을 바꾸면 면제는 아무것도 보호하지 않게 되고, 이 락의 정의역은 조용히
# 줄어든다 — 그 사실을 말해줄 곳이 여기 말고 없다.
if python3 - "$EXEMPT_FIXTURE" <<'PY'
import json, sys
entries = json.load(open(sys.argv[1], encoding="utf-8"))["hooks"].get("PostToolUse", [])
if not any(not e.get("matcher") for e in entries):
    print(f"면제 픽스처 {sys.argv[1]} 에 matcher 없는 PostToolUse 항목이 없다", file=sys.stderr)
    sys.exit(1)
PY
then ok "양성 대조: 면제 픽스처가 여전히 matcher-less PostToolUse 를 갖는다"
else no "양성 대조 실패: 면제가 보호하는 대상이 사라졌다 — EXEMPT 를 지우거나 픽스처를 되돌려라"
fi

exit $FAIL
