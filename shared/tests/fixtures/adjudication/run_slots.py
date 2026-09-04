import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "tools" / "adjudication"))
import check_slots  # noqa: E402

if len(sys.argv) > 2 and sys.argv[2] == "--emit-scanned":
    for p in check_slots.scanned_paths(str(root)):
        print(p)
    sys.exit(0)

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
for name in ("match", "undeclared", "undelivered", "forbidden", "suspectvar"):
    probs = check_slots.check(str(FX / ("slots_%s" % name)))
    print("fx_%s=%d" % (name, len(probs)))

# 펜스 하나에 subagent_type 둘(`fx:a`·`fx:b`) — 조용한 첫-매치 귀속 대신 세어서
# 드러내는지의 판정기 자체 검증(수정 라운드 1).
print("fx_multiagent=%d" % len(check_slots.multi_agent_fences(str(FX / "slots_multiagent"))))

defs = check_slots.agents(str(root))
print("agents=%d" % len(defs))
probs = check_slots.check(str(root))
kinds = Counter(p[0] for p in probs)
print("no_declaration=%d" % kinds.get("no_declaration", 0))
# (a)/(b) 축이 «실제로 겨눈» 모집단. 선언이 0이면 그 두 축은 오늘 아무것도
# 재지 않는다 — 그 사실이 `problems_other=0` 뒤에 숨으면 안 된다.
print("declared=%d" % len([1 for v in defs.values() if v["slots"] is not None]))
print("problems_other=%d" % (len(probs) - kinds.get("no_declaration", 0)))
for p in probs:
    if p[0] != "no_declaration":
        print("  PROBLEM %s %s @ %s %s" % p)
print("exempt_total=%d" % len(check_slots.EXEMPT_SLOTS))
print("exempt_uncited=%d" % len(check_slots.uncited_exemptions()))

# 펜스 하나에 subagent_type 이 둘 이상이면 `_harvest()` 가 어느 쪽에도 태그를
# 귀속하지 않는다(조용한 오귀속 방지) — 그 사실 자체를 셀 수 있게 낸다(수정
# 라운드 1, 코디네이터 판정 ⒞). 0 이면 침묵이 아니라 "0 이라고 쟀다"는 뜻이다.
multi = check_slots.multi_agent_fences(str(root))
print("multi_agent_fences=%d" % len(multi))
for (rel, line, count) in multi:
    print("  MULTI_AGENT_FENCE %s:%d agents=%d" % (rel, line, count))
