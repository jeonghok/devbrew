#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py
#
# 버리는 분기가 자기 처분을 부르는지 검사한다.
#
# 대상은 «파일의 모든 for 문»이다. 「처분 호출이 있는 함수」로 좁히면 전혀
# 배선되지 않은 버리기가 영원히 안 보인다 — 모집단이 피검자 손에 들어간다.
#
# 컴프리헨션은 요구 대상이 아니다(표현식에 문장을 못 넣는다). 대신 개수를
# baseline 으로 못 박는다 — 버리기를 그 형태로 옮기는 우회가 조용하지 않게.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t adjwire-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

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
PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_wiring_scan.py" \
  "$REPO_ROOT" > "$TMPD/scan.txt" 2>&1
SCAN="$(cat "$TMPD/scan.txt")"
note "$SCAN"

n_union="$(printf '%s\n' "$SCAN"  | sed -n 's/^union=//p')"
n_import="$(printf '%s\n' "$SCAN" | sed -n 's/^import=//p')"
n_anchor="$(printf '%s\n' "$SCAN" | sed -n 's/^anchor=//p')"

# 0 은 통과가 아니라 실패다 — 도출이 깨지면 이 락 전체가 vacuous 해진다.
if [ "${n_union:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉮ 도출 $n_union 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉮ 도출이 0 이다 — glob 이나 앵커 스캔이 깨졌다. 이 락의 모든 단언이 공허하다"
fi
assert_eq "$n_import" "$n_anchor" "㉮ 의 두 경로(import·앵커)가 같은 수를 낸다 — 갈리면 회귀 신호다"

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
