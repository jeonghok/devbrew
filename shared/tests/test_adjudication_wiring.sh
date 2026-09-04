#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py tools/adjudication/check_wiring.py shared/tests/fixtures/adjudication/run_wiring_scan.py shared/tests/fixtures/adjudication/run_wiring_probe.py
#
# 수정 라운드 1 (F6) — 판정기 자신(`tools/adjudication/check_wiring.py`)이
# 이 락의 `# guards:` 에 없었다. 27개 선언 전수 확인 결과 `tools/adjudication/`
# 는 «어떤» 락에도 없었다 — 판정기를 약화시켜도 그 사실을 잡는 락이
# 선택되지 않는다는 뜻이다. 도출은 열거가 아니라 import: 이 락이 실행하는
# `fixtures/adjudication/run_wiring_scan.py`·`run_wiring_probe.py` 둘 다
# `from check_wiring import ...` 를 쓴다 — 그래서 이 판정기가 여기 산다.
#
# 수정 라운드 2 (I1) — F6 은 `check_wiring.py`(락이 import 하는 대상) 만 덮고
# 그것을 «부르는» `run_wiring_scan.py`/`run_wiring_probe.py` 자신은 안
# 덮었다. F4 의 실제 결함이 `check_slots.py` 가 아니라 `run_slots.py` 의
# print 루프에 있었던 것과 같은 자리 — 러너 스크립트 자체가 무방비였다.
# 이 두 파일을 그 러너를 실제로 실행하는 이 락 하나에 편입한다(다른 락은
# 이 러너를 안 부르므로 여기가 유일한 소비자).
#
# 버리는 분기가 자기 처분을 부르는지 검사한다.
#
# 대상은 «파일의 모든 for 문»이다. 「처분 호출이 있는 함수」로 좁히면 전혀
# 배선되지 않은 버리기가 영원히 안 보인다 — 모집단이 피검자 손에 들어간다.
#
# 컴프리헨션은 요구 대상이 아니다(표현식에 문장을 못 넣는다). 대신 개수를
# baseline 으로 못 박는다 — 버리기를 그 형태로 옮기는 우회가 조용하지 않게.
#
# 이 락은 처분의 «유무»를 재고 «종류」는 재지 않는다. reject 를 accept 로
# 바꾸면 통과한다 — 종류의 정합은 처분 행렬 테스트
# (quality-gates/tests/test_synthesize_disposition.sh) 가 잰다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t adjwire-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

# 모집단(㉮) 계산을 먼저 한다 — probe 절보다 앞이다. `--emit-scanned` 가
# probe(판정기 자기 검증용 fixture, 실제 코퍼스와 무관)까지 돌 필요가 없게
# 하기 위해서다. `$SCAN` 은 여기서 «한 번» 계산되고, emit 경로와 본 검사
# 경로가 이 같은 변수를 그대로 재사용한다 — 두 번 계산하면 낸 것과 읽은
# 것이 갈린다.
PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_wiring_scan.py" \
  "$REPO_ROOT" > "$TMPD/scan.txt" 2>&1
SCAN="$(cat "$TMPD/scan.txt")"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 진단
# note 를 찍기 «전에» 끊는다 — 안 그러면 그 노이즈 줄까지 "스캔된 경로"로
# 오인돼 커버리지 판정이 오염된다.
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$SCAN" | sed -n 's/^  CONSUMER //p'
  printf '%s\n' "tools/adjudication/check_wiring.py"
  printf '%s\n' "shared/tests/fixtures/adjudication/run_wiring_scan.py"
  printf '%s\n' "shared/tests/fixtures/adjudication/run_wiring_probe.py"
  exit 0
fi

note "── 판정기 자체 (fixture) — 락이 죽었나와 판정기가 죽었나를 가른다"
PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_wiring_probe.py" \
  "$REPO_ROOT" > "$TMPD/probe.txt" 2>&1
PROBE="$(cat "$TMPD/probe.txt")"
assert_contains "$PROBE" "bad=1"      "무방비 continue 를 잡는다"
assert_contains "$PROBE" "good=0"     "같은 분기의 처분 호출을 통과시킨다"
assert_contains "$PROBE" "farguard=1" "다른 분기의 처분 호출로 만족되지 않는다 (fail-open 회귀)"
assert_contains "$PROBE" "nested_if=1" \
  "바깥 분기의 처분 호출로 만족되지 않는다 — 안쪽을 «길이»가 아니라 포함 관계로 고른다"
assert_contains "$PROBE" "nested_loop_rows=1" \
  "중첩 루프 안의 한 문장을 한 번만 센다 (이중 계상 회귀 — M8 의 면제 크기를 부풀린다)"
assert_contains "$PROBE" "except_guard=0" \
  "같은 except 본문의 처분 호출을 통과시킨다 — 분기 컨테이너는 If 뿐 아니라 Try/except 다"
assert_contains "$PROBE" "while_boundary_rows=0" \
  "while 안의 버리는 분기를 바깥 for 의 인구로 잘못 귀속하지 않는다 (while 경계 회귀)"

note "── 모집단 도출 (㉮) — 두 경로를 따로 기록한다"
note "$SCAN"

n_union="$(printf '%s\n' "$SCAN"  | sed -n 's/^union=//p')"

# 0 은 통과가 아니라 실패다 — 도출이 깨지면 이 락 전체가 vacuous 해진다.
if [ "${n_union:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉮ 도출 $n_union 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉮ 도출이 0 이다 — glob 이나 앵커 스캔이 깨졌다. 이 락의 모든 단언이 공허하다"
fi
# 개수만 비교하면 대리지표다 — 한 파일이 import 에서 빠지고 «무관한» 다른
# 파일이 anchor 에 들어오면 개수는 같아 그대로 통과한다(이 브랜치가 계속
# 잡아낸 결함 모양). 집합으로 비교한다. `_missing_from A B` = A 의 원소 중
# B 에 없는 것들, 줄 단위(공백 항목은 버린다).
_missing_from() {
  comm -23 <(printf '%s\n' "$1" | sed '/^$/d' | sort -u) \
           <(printf '%s\n' "$2" | sed '/^$/d' | sort -u)
}

IMPORT_LIST="$(printf '%s\n' "$SCAN" | sed -n 's/^  IMPORT //p')"
ANCHOR_LIST="$(printf '%s\n' "$SCAN" | sed -n 's/^  ANCHOR //p')"
TERMINAL_LIST="$(printf '%s\n' "$SCAN" | sed -n 's/^  TERMINAL //p')"

# 단언 1 — ANCHOR ⊆ IMPORT, 예외 없음. dispatch 자리가 「이 파일이
# 회계한다」고 consumer= 로 선언했는데 그 파일이 원장을 import 조차 안 하면
# 그건 거짓 선언이다.
anchor_orphans="$(_missing_from "$ANCHOR_LIST" "$IMPORT_LIST")"
if [ -z "$anchor_orphans" ]; then
  ok "ANCHOR ⊆ IMPORT — consumer= 로 불린 파일은 전부 실제로 원장을 import 한다"
else
  no "ANCHOR ⊆ IMPORT 위반 — consumer= 로 불렸으나 import 하지 않는(거짓 선언) 경로가 있다"
  printf '%s\n' "$anchor_orphans" | while IFS= read -r l; do
    note "      거짓 선언: $l"
  done
fi

# 단언 2 — (IMPORT \ ANCHOR) ⊆ TERMINAL_CONSUMERS. import 하는데 앵커가
# 없는 파일은 전부 check_wiring.TERMINAL_CONSUMERS 에 사유와 함께 등재돼
# 있어야 한다 — 등재되지 않은 것은 「왜 앵커가 없는지 아무도 설명하지
# 않은 소비자」다.
import_minus_anchor="$(_missing_from "$IMPORT_LIST" "$ANCHOR_LIST")"
unlisted_terminal="$(_missing_from "$import_minus_anchor" "$TERMINAL_LIST")"
if [ -z "$unlisted_terminal" ]; then
  ok "(IMPORT \\ ANCHOR) ⊆ TERMINAL_CONSUMERS — 앵커 없는 import 전부가 종단 소비자로 등재돼 있다"
else
  no "(IMPORT \\ ANCHOR) ⊆ TERMINAL_CONSUMERS 위반 — 앵커도 없고 종단 소비자로도 등재 안 된 경로가 있다"
  printf '%s\n' "$unlisted_terminal" | while IFS= read -r l; do
    note "      미등재: $l"
  done
fi

note "── TERMINAL_CONSUMERS — 각 항목이 사유를 갖는다"
term_uncited="$(printf '%s\n' "$SCAN" | sed -n 's/^terminal_uncited=//p')"
term_n="$(printf '%s\n' "$SCAN" | sed -n 's/^terminal_total=//p')"
assert_eq "$term_uncited" "0" "사유 없는 TERMINAL_CONSUMERS 항목 0 (사유 없는 등재는 그냥 구멍이다)"
note "      TERMINAL_CONSUMERS 크기: $term_n"

note "── 배선 — 미배선 자리 0"
unwired="$(printf '%s\n' "$SCAN" | sed -n 's/^unwired=//p')"
assert_eq "$unwired" "0" "버리는 분기 전부가 같은 분기에 처분 호출을 갖는다"
printf '%s\n' "$SCAN" | sed -n 's/^  UNWIRED //p' | while IFS= read -r l; do
  note "      미배선: $l"
done

note "── 면제 — 각 항목이 C6 조건을 인용한다"
uncited="$(printf '%s\n' "$SCAN" | sed -n 's/^exempt_uncited=//p')"
exempt_n="$(printf '%s\n' "$SCAN" | sed -n 's/^exempt_total=//p')"
assert_eq "$uncited" "0" "C6 인용 없는 면제 항목 0 (인용 없는 면제는 그냥 구멍이다)"
note "      면제 목록 크기: $exempt_n  ← M8 이 이 수의 증가를 본다"

note "── 면제 키의 신선도 — 낡은 (경로, 줄번호) 가 다른 버리는 분기를 조용히 가리는가"
exempt_stale="$(printf '%s\n' "$SCAN" | sed -n 's/^exempt_stale=//p')"
assert_eq "$exempt_stale" "0" "모든 면제 키가 현재 트리에서 실제 버리는 분기를 가리킨다 (Task 11b 가 실증한 drift 구멍)"
printf '%s\n' "$SCAN" | sed -n 's/^  STALE_EXEMPT //p' | while IFS= read -r l; do
  note "      낡은 면제: $l"
done

note "── 컴프리헨션 회귀 축 — 요구가 아니라 baseline"
comp="$(printf '%s\n' "$SCAN" | sed -n 's/^comprehensions=//p')"
COMP_BASELINE=33   # Task 1 F5 census 28 + Task 10 이 1 늘림(29) — merge_review.py
                   # `merged["report"]["counts"]`를 만드는 `{k: 0 for k in
                   # _MERGED_COUNT_KEYS}`. 항목을 버리는 자리가 아니라 값 0
                   # 으로 카운터를 초기화하는 자리라 처분 호출이 필요 없다.
                   # Task 11 이 4 늘림(29→33) — `Ledger` import 로 ㉮ 에 처음
                   # 들어온 review-dispatch.py 자신의 컴프리헨션 넷: `raw.split`
                   # 토큰 집합·필터(:145-146, DEVBREW_SKIP_HOOKS 파싱)와 회전
                   # 커서 계산·선택(:270-271, select_keys 의 라운드로빈). 넷 다
                   # 설정 파싱·목록 회전이지 처분 대상을 버리는 자리가 아니다
                   # (코드 확인 완료).
if [ "${comp:-0}" -le "$COMP_BASELINE" ] 2>/dev/null; then
  ok "컴프리헨션 내포 $comp <= baseline $COMP_BASELINE"
else
  no "컴프리헨션 내포가 $comp 로 늘었다 (baseline $COMP_BASELINE) — 버리기가 for 문 밖으로 옮겨갔을 수 있다. 늘린 커밋이 이유를 적고 baseline 을 올려라"
fi

finish
