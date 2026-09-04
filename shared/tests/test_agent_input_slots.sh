#!/usr/bin/env bash
# guards: plugins/*/agents/*.md plugins/*/skills/**/*.md plugins/*/commands/*.md
#
# `commands/*.md` — 단일 `*` 다(`**` 아님). 이 파일들은 전부 flat(`commands/<name>.md`,
# 하위 디렉터리 없음)이고, `# guards:` 를 소비하는 bash `case` 패턴은 리터럴
# `/` 를 요구한다 — `commands/**/*.md` 는 flat 경로를 «구조적으로» 못 맞춘다
# (`**` 가 인접한 `/` 두 개를 강제하지만 candidate 에 그만큼의 `/` 가 없다).
# 반면 `*` 는 bash case 에서 이미 `/` 를 넘으므로(test_skill_reference_pointers.sh
# 의 기존 관례와 동일) flat·중첩 양쪽을 다 잡는다. `check_slots.dispatch_pairs()`
# 자신은 파이썬 `**` 글롭(zero-or-more 디렉터리)이라 flat 을 이미 잘 읽는다 —
# 어긋나는 쪽은 이 bash 선언뿐이다.
#
# agent 가 «선언한» 입력과 dispatch 가 «전달하는» 것이 맞는지, 그리고 선언된
# 종류가 금지 어휘가 아닌지 검사한다.
#
# 모집단은 agent 정의 집합(∀)이다. dispatch 표기 열거에서 출발하면 표기를
# 하나 놓칠 때마다 그만큼 조용해진다.
#
# (b) 의 구멍을 밝힌다: 선언값 판정이라 저자가 kind 를 거짓으로 적으면
# 빠져나간다. 변수명 휴리스틱이 보조 축이지만 이름과 kind 를 «함께» 속이면
# 통과한다. 이 락은 그 구멍을 없앴다고 주장하지 않는다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스
# 도출은 run_slots.py 안에 산다(판정기가 파이썬) — 같은 러너를 `--emit-scanned`
# 모드로 부른다.
if [ "${1:-}" = "--emit-scanned" ]; then
  PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_slots.py" \
    "$REPO_ROOT" --emit-scanned
  exit 0
fi

TMPD="$(mktemp -d -t slots-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_slots.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_match=0"           "일치하는 선언·전달을 통과시킨다"
assert_contains "$OUT" "fx_undeclared=1"      "선언 없는 태그의 전달을 잡는다"
assert_contains "$OUT" "fx_undelivered=1"     "필수 선언의 미전달을 잡는다"
assert_contains "$OUT" "fx_forbidden=1"       "금지 종류를 잡는다"
assert_contains "$OUT" "fx_suspectvar=1"      "이름은 판정인데 kind 가 무해한 슬롯을 잡는다 (b 의 보조 축)"

note "── 모집단 (㉰)"
nag="$(printf '%s\n' "$OUT" | sed -n 's/^agents=//p')"
if [ "${nag:-0}" -gt 0 ] 2>/dev/null; then
  ok "agent 정의 $nag 개"
else
  no "agent 도출이 0 이다 — 락이 vacuous 하다"
fi

note "── 선언 부재"
nodecl="$(printf '%s\n' "$OUT" | sed -n 's/^no_declaration=//p')"
assert_eq "$nodecl" "0" "모든 agent 가 input_slots 를 선언한다"

note "── 일치와 종류 — 먼저 이 축이 무언가를 재는지 밝힌다"
ndecl="$(printf '%s\n' "$OUT" | sed -n 's/^declared=//p')"
if [ "${ndecl:-0}" -gt 0 ] 2>/dev/null; then
  ok "슬롯을 선언한 agent $ndecl 개 — (a)/(b) 축이 겨눌 대상이 있다"
else
  no "슬롯을 선언한 agent 가 0 이다 — 아래 (a)/(b) 단언은 오늘 «아무것도 재지 않는다». 통과해도 증거가 아니다"
fi
nprob="$(printf '%s\n' "$OUT" | sed -n 's/^problems_other=//p')"
assert_eq "$nprob" "0" "선언 ↔ 전달 일치, 금지 종류 없음 (선언한 $ndecl 개 위에서)"
printf '%s\n' "$OUT" | sed -n 's/^  PROBLEM //p' | while IFS= read -r l; do
  note "      $l"
done

note "── 면제"
unc="$(printf '%s\n' "$OUT" | sed -n 's/^exempt_uncited=//p')"
nex="$(printf '%s\n' "$OUT" | sed -n 's/^exempt_total=//p')"
assert_eq "$unc" "0" "C6 인용 없는 면제 항목 0"
note "      면제 목록 크기: $nex  ← M8 이 이 수의 증가를 본다"

finish
