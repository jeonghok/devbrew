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
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

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
#    구별되지 않는다. 실측 근거: 문서 리뷰 엔진(`docreview_route.py`)은 codex·doc-recritic
#    실패를 `primary=False` 로 기록하고 그 라운드를 막지 않는다 — `shared/tests/fixtures/
#    docreview/cases.sh` 의 `case_T40_codex_absent_first_line`(codex 없음 → blocks
#    False) · `case_T43_recritic_dead`(recritic 부재 → blocks False)가 그것을 계약으로
#    못 박는다.
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

note "── 억제(D4) — reject 와 다른 칸이다"
OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_ROOT/shared/tests/fixtures/adjudication/probe_suppressed.py" "$REPO_ROOT")"
assert_contains "$OUT" "suppressed=1"   "suppressed() 가 자기 칸에 센다"
assert_contains "$OUT" "rejected=0"     "억제는 기각에 섞이지 않는다 (D4)"
assert_contains "$OUT" "blocks=False"   "규칙 억제는 차단이 아니다"
assert_contains "$OUT" "degraded=False" "규칙 억제는 degrade 가 아니다 — 규칙이 정한 결과다"

note "── held_by_class — 접두별 분류"
OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_ROOT/shared/tests/fixtures/adjudication/probe_held_class.py" "$REPO_ROOT")"
assert_contains "$OUT" "부재=1" "held_by_class: 판정자 부재"
assert_contains "$OUT" "파손=2" "held_by_class: 항목 파손"
assert_contains "$OUT" "기타=1" "held_by_class: 미지 접두는 «기타» 로 — 조용히 사라지지 않는다 (U4)"
assert_contains "$OUT" "합=4"   "held_by_class 의 합 == held 총계. 어느 항목도 분류에서 빠지지 않는다"

note "── 5. blocks() 의 세 조건을 «가르는» 공개 accessor (PR3)"

# 왜 이것이 필요한가: 소비자(qg)가 셋을 **다른 사유**로 렌더한다 — 앞 둘은
# `findings-lost`(항목을 잃었다), 셋째는 `angle-absent`(아무도 그 축을 안 봤다).
# `blocks()` 하나만 공개하면 그 구별이 소비자 쪽에서 복원 불가능하다.

out="$(run 'from adjudication import Ledger
L = Ledger(items="open"); L.hold("x", "판정자 부재")
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks())')"
assert_eq "$out" "True False True" "hold 는 items_unaccounted 만 올린다"

out="$(run 'from adjudication import Ledger
L = Ledger(items="open"); L.uncountable("issues", "셀 수 없음")
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks())')"
assert_eq "$out" "True False True" "uncountable 도 items_unaccounted 쪽이다"

# ★ 이 PR 이 사는 이유가 이 한 줄이다 — 주 판정자가 죽었을 때 items_unaccounted 가
#   **거짓**이어야 소비자가 그 실행을 「항목을 잃었다」가 아니라 「아무도 안 봤다」로
#   렌더할 수 있다. 여기가 True 로 돌아오면 PR2 의 접힘이 그대로 남은 것이다.
out="$(run 'from adjudication import Ledger
L = Ledger(items="open"); L.source_failed("reviewer", "죽음", primary=True)
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks())')"
assert_eq "$out" "False True True" "주 source 실패는 primary_source_failed 만 올린다"

# 양성 대조 — 보조 실패는 어느 쪽도 올리지 않는다(공시만 한다).
out="$(run 'from adjudication import Ledger
L = Ledger(items="open"); L.source_failed("codex", "미설치", primary=False)
print(L.items_unaccounted(), L.primary_source_failed(), L.blocks(), L.report()["degraded"])')"
assert_eq "$out" "False False False True" \
  "보조 실패는 두 accessor 다 거짓이고 blocks 도 아니다 — degraded 만 참 (헌장)"

# 동치 — `blocks()` 를 다시 쓴 뒤에도 값이 같다. 네 조합 전수.
out="$(run 'from adjudication import Ledger
def mk(h, u, p):
    L = Ledger(items="open")
    if h: L.hold("x", "판정자 부재")
    if u: L.uncountable("i", "미상")
    if p: L.source_failed("r", "죽음", primary=True)
    return L
bad = [(h,u,p) for h in (0,1) for u in (0,1) for p in (0,1)
       if mk(h,u,p).blocks() != (mk(h,u,p).items_unaccounted()
                                 or mk(h,u,p).primary_source_failed())]
print("MISMATCH:%d" % len(bad))')"
assert_eq "$out" "MISMATCH:0" "blocks() == items_unaccounted() or primary_source_failed() (8조합 전수)"

finish
