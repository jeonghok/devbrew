#!/usr/bin/env bash
# guards: shared/adjudication/**
#
# 처분 회계 모듈의 **행동**을 고정한다.
#
# 왜 메서드 존재 검사로 부족한가: 일곱 메서드가 전부 있어도 `absorbed` 가
# degraded 를 올리면 흡수가 소실로 세어져 신호가 희석된다. 그래서 여기서는
# 각 메서드의 **부작용**(counts 의 어느 칸이 오르는가 · degraded 가 오르는가 ·
# blocks 가 오르는가)을 직접 관측한다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/adjudication/adjudication.py"
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
MOD="$HERE/../adjudication"

run() {   # run <python-body>  → stdout
  PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="$MOD" python3 -c "$1"
}

# ── 1. 일곱 메서드가 counts 의 올바른 칸을 올린다
out="$(run '
from adjudication import Ledger
L = Ledger()
L.accept("a"); L.reject("b", "근거"); L.hold("c", "판정불가")
L.absorbed("d", into="a"); L.coerced("f", 5, 0)
L.source_failed("codex", "한도", primary=False); L.uncountable("issues", "리스트 미생성")
c = L.report()["counts"]
print(c["accepted"], c["rejected"], c["held"], c["absorbed"], c["coerced"], c["sources_failed"])
')"
assert_eq "$out" "1 1 1 1 1 1" "일곱 메서드가 각자 칸을 하나씩 올린다"

# ── 2. 흡수는 degraded 가 아니다 / 보류는 degraded 다  (양성 대조 쌍)
out="$(run 'from adjudication import Ledger
L = Ledger(); L.absorbed("x", into="y"); print(L.report()["degraded"])')"
assert_eq "$out" "False" "absorbed 는 degraded 를 올리지 않는다"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.hold("x", "왜"); print(L.report()["degraded"])')"
assert_eq "$out" "True" "hold 는 degraded 를 올린다 (양성 대조)"

# ── 3. 강제는 gate 여부로 갈린다
out="$(run 'from adjudication import Ledger
L = Ledger(); L.coerced("raised_count", 5, 0, gate=False); print(L.report()["degraded"])')"
assert_eq "$out" "False" "coerced(gate=False) 는 degraded 가 아니다"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.coerced("raised_count", 5, 0, gate=True); print(L.report()["degraded"])')"
assert_eq "$out" "True" "coerced(gate=True) 는 degraded 다"

# ── 4. 원리적 미상은 unknown_counts 로 가고 정수 칸엔 안 들어간다
out="$(run 'from adjudication import Ledger
L = Ledger(); L.uncountable("issues", "리스트 미생성")
r = L.report(); print(r["unknown_counts"], sum(r["counts"][k] for k in
  ("accepted","rejected","held","absorbed","coerced")))')"
assert_eq "$out" "['issues'] 0" "uncountable 은 unknown_counts 로 가고 정수 칸은 0"

# ── 5. blocks() 는 §9.1 의 «조건부» 규칙이다 — 무조건이 아니다
out="$(run 'from adjudication import Ledger
L = Ledger(); L.hold("x", "왜"); print(L.blocks())')"
assert_eq "$out" "True" "held > 0 이면 blocks"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.uncountable("x", "왜"); print(L.blocks())')"
assert_eq "$out" "True" "unknown_counts 가 비지 않으면 blocks"
out="$(run 'from adjudication import Ledger
L = Ledger(); L.source_failed("claude", "파싱불가", primary=True); print(L.blocks())')"
assert_eq "$out" "True" "주(主) source_failed 면 blocks"

#    양성 대조 (a) — 셋 다 아니면 blocks 아님
out="$(run 'from adjudication import Ledger
L = Ledger(); L.accept("a"); L.reject("b","근거"); L.absorbed("c", into="a")
print(L.blocks())')"
assert_eq "$out" "False" "양성대조(a): 소실도 미상도 주-실패도 없으면 blocks 아님"

#    양성 대조 (b) — 보조 source 실패는 degraded 이되 blocks 아님.
#    이 단언이 없으면 이 테스트는 «철회된 보편 규칙»(degraded 면 언제나 blocks)과
#    구별되지 않는다. 실측 근거: merge_review.py:461-465 는 codex(보조) 실패에도
#    combined = claude_verdict = approved 를 내고, test_merge_review.py:130-135(AC10)·
#    :144-148 · :154-158 이 그것을 계약으로 못 박았다.
out="$(run 'from adjudication import Ledger
L = Ledger(); L.source_failed("codex", "한도 소진", primary=False)
print(L.report()["degraded"], L.blocks())')"
assert_eq "$out" "True False" "양성대조(b): 보조 source 실패는 degraded 이되 blocks 아님"

#    혼합 대조 — 주+보조가 «같은 원장에» 함께 들어온 경우. 이것이 없으면
#    `any`→`all` 한 단어 변이가 14개 단언을 전부 GREEN 으로 남긴다: 원소 하나짜리
#    리스트에서 두 함수는 구별되지 않는다. 그리고 claude(주)+codex(보조) 동시 실패가
#    이 모듈이 존재하는 바로 그 경우다.
out="$(run 'from adjudication import Ledger
L = Ledger()
L.source_failed("codex", "한도 소진", primary=False)
L.source_failed("claude", "파싱 불가", primary=True)
print(L.blocks())')"
assert_eq "$out" "True" "혼합 source_failed — 보조가 섞여도 주가 있으면 blocks (any→all 변이 계측기)"

out="$(run 'from adjudication import Ledger
L = Ledger()
L.coerced("a", 1, 2, gate=False)
L.coerced("b", 3, 4, gate=True)
print(L.report()["degraded"])')"
assert_eq "$out" "True" "혼합 coerced — 비-gate 가 섞여도 gate 가 있으면 degraded (any→all 변이 계측기)"

# ── 6. surfaced() 의 방향
out="$(run 'from adjudication import Ledger
L = Ledger(items="open"); L.hold("h", "왜"); L.uncountable("u", "왜")
print(len(L.surfaced()), sorted(x["label"] for x in L.surfaced()))')"
assert_eq "$out" "2 ['held', 'uncountable']" "items=open 은 미판정 항목을 라벨과 함께 낸다"
out="$(run 'from adjudication import Ledger
L = Ledger(items="closed"); L.hold("h", "왜"); L.uncountable("u", "왜")
print(len(L.surfaced()))')"
assert_eq "$out" "0" "items=closed 는 미판정 항목을 제외한다"

# ── 7. items 는 닫힌 어휘다
out="$(run 'from adjudication import Ledger
try:
    Ledger(items="sideways"); print("NO_RAISE")
except ValueError:
    print("RAISED")')"
assert_eq "$out" "RAISED" "items 에 세 번째 값을 주면 ValueError"

finish
