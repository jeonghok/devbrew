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

# 최종 리뷰 K4b — `declared=N` 은 «선언한» 수이지 축 (a)가 «잰» 수가 아니다.
# dispatch 자리가 Workflow JS(`agent(prompt, {agentType})`)나 skill frontmatter
# 의 `context: fork` 에 있는 agent 는 `.md` dispatch 코퍼스에 «구조적으로»
# 안 보인다 — 그 agent 에서는 선언과 전달을 대조할 대상이 애초에 없다.
# 셀 수 없으면 셀 수 없음을 낸다(리포 규약: 침묵과 0 은 다른 사실이다).
pairs, _m = check_slots.dispatch_pairs(str(root))
unmeasured = sorted(k for k in defs if not pairs.get(k))
print("measured=%d" % (len(defs) - len(unmeasured)))
print("unmeasured=%d" % len(unmeasured))
for k in unmeasured:
    print("  UNMEASURED %s (%s)" % (k, defs[k]["path"]))
print("problems_other=%d" % (len(probs) - kinds.get("no_declaration", 0)))
# Task 15 수정 라운드 1 (F4) — no_declaration 도 이름을 댄다. 예전엔 이 루프가
# no_declaration 을 걸러내 개수(`no_declaration=N`)만 오르고 어느 agent 인지
# 아무 데도 안 남았다(check_slots.py:142 의 problem 튜플엔 이미 `info["path"]`
# 가 실려 있었다 — 흘리는 쪽은 이 print 루프였다). 다른 축과 같은 "PROBLEM"
# 형식으로 낸다.
for p in probs:
    print("  PROBLEM %s %s @ %s %s" % p)
print("exempt_total=%d" % len(check_slots.EXEMPT_SLOTS))
print("exempt_baseline=%d" % check_slots.EXEMPT_SLOTS_BASELINE)
print("exempt_uncited=%d" % len(check_slots.uncited_exemptions()))

# 펜스 하나에 subagent_type 이 둘 이상이면 `_harvest()` 가 어느 쪽에도 태그를
# 귀속하지 않는다(조용한 오귀속 방지) — 그 사실 자체를 셀 수 있게 낸다(수정
# 라운드 1, 코디네이터 판정 ⒞). 0 이면 침묵이 아니라 "0 이라고 쟀다"는 뜻이다.
multi = check_slots.multi_agent_fences(str(root))
print("multi_agent_fences=%d" % len(multi))
for (rel, line, count) in multi:
    print("  MULTI_AGENT_FENCE %s:%d agents=%d" % (rel, line, count))
