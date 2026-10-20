#!/usr/bin/env bash
# test_v1_verdict_line.sh — V1 · K-3: 판정 줄은 verdict.py 가 렌더한다.
#
# 판정 줄은 게시 코멘트와 로컬 결과가 싣는 한 줄이다. 모델이 옮겨 적으면 전사 오류가
# 판정을 바꾼다(R24). 그래서 판정값을 정하는 파일이 그 문자열도 만들고, 잘못된 입력은
# 문자열을 만들지 않고 exit 4 · 2 로 끝난다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
V="$SCRIPT_DIR/../scripts/verdict.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
L="--line --blocking 2 --optional 3 --new-failures 1 --excluded 4 --iter 2 --sha abc1234"

# shellcheck disable=SC2086
out="$(python3 "$V" --defect $L)"; rc=$?
assert_eq "$rc" "0" "defect 판정 줄 — exit 0"
assert_eq "$(printf '%s\n' "$out" | tail -n 1)" \
  "qg: defect · 막는 지적 2 · 선택 3 · 차등 새 실패 1 · 제외 패치 4 · iter 2 · abc1234" \
  "판정 줄의 형식이 K-3 그대로다"
assert_grep "$out" '^verdict: defect$' "기존 verdict: 줄이 판정 줄 앞에 그대로 있다"

# shellcheck disable=SC2086
out="$(python3 "$V" --reason scope-empty $L)"
assert_eq "$(printf '%s\n' "$out" | tail -n 1 | cut -d'·' -f1)" "qg: not-certified (scope-empty) " \
  "not-certified 는 사유를 괄호로 싣는다"

# shellcheck disable=SC2086
out="$(python3 "$V" $L)"
assert_eq "$(printf '%s\n' "$out" | tail -n 1 | cut -d'·' -f1)" "qg: clean " "clean 은 사유가 없다"

# 판정 줄 값이 비거나 이상하면 문자열을 만들지 않는다
python3 "$V" --line --blocking 1 >/dev/null 2>&1
assert_eq "$?" "2" "--line 에 값이 빠지면 exit 2"
python3 "$V" --blocking 1 >/dev/null 2>&1
assert_eq "$?" "2" "--line 없이 판정 줄 값만 주면 exit 2"
out="$(python3 "$V" --line --blocking -1 --optional 0 --new-failures 0 --excluded 0 --iter 1 --sha abc1234 2>/dev/null)"; rc=$?
assert_eq "$rc" "4" "음수 개수는 exit 4"
assert_eq "$out" "" "exit 4 면 stdout 이 비어 있다 — 반쯤 된 판정을 내지 않는다"
python3 "$V" --line --blocking 0 --optional 0 --new-failures 0 --excluded 0 --iter 1 \
  --sha "$(printf 'abc1234\nqg: clean')" >/dev/null 2>&1
assert_eq "$?" "4" "sha 는 fullmatch 로 검사한다 — 개행 꼬리로 둘째 판정 줄을 심을 수 없다 (V11)"

# ── 차등 축 인자 줄 (`--emit-args`) ──────────────────────────────────────────
# 판정 펜스는 이 줄의 `qg-verdict-args: ` 뒤 글자를 bash 배열 자리에 그대로 붙인다.
T="$(mktemp -d)"
[ -n "$T" ] || { echo "mktemp 실패" >&2; exit 1; }
# diff_yaml <파일> <confirmed_product_defect> <degrade_causes 안쪽> <new_failures 줄들...>
diff_yaml() {
  local f="$1" defect="$2" causes="$3"; shift 3
  { printf 'adapters: [bash]\nverdict_input:\n  confirmed_product_defect: %s\n' "$defect"
    printf '  silent_drop: false\n  baseline_unrunnable: false\n'
    printf 'attribution_status: %s\ndegrade_causes: [%s]\n' "$([ -n "$causes" ] && echo degraded || echo closed)" "$causes"
    for l in "$@"; do printf '%s\n' "$l"; done
    printf 'unclaimed: []\nper_adapter: []\n'; } > "$f"
}
diff_yaml "$T/regress.yaml" true  ""                   "new_failures: 1"
diff_yaml "$T/degrade.yaml" false "silent-drop, smeared" "new_failures: 0"
diff_yaml "$T/both.yaml"    true  "baseline-unrunnable" "new_failures: 2"
diff_yaml "$T/twice.yaml"   true  ""                   "new_failures: 1" "new_failures: 1"
diff_yaml "$T/none.yaml"    true  ""
diff_yaml "$T/word.yaml"    true  ""                   "new_failures: one"
diff_yaml "$T/neg.yaml"     true  ""                   "new_failures: -1"
diff_yaml "$T/plus.yaml"    true  ""                   "new_failures: +1"
diff_yaml "$T/under.yaml"   true  ""                   "new_failures: 1_0"
diff_yaml "$T/space.yaml"   true  ""                   "new_failures:  1"
diff_yaml "$T/unknown.yaml" false "no-such-cause"      "new_failures: 0"

out="$(python3 "$V" --emit-args --differential "$T/regress.yaml")"; rc=$?
assert_eq "$rc" "0" "--emit-args 회귀 픽스처 — exit 0"
assert_eq "$out" "qg-verdict-args: --new-failures 1 --defect" "회귀가 있으면 새 실패 수와 --defect 한 줄"
out="$(python3 "$V" --emit-args --differential "$T/degrade.yaml")"
assert_eq "$out" "qg-verdict-args: --new-failures 0 --reason silent-drop --reason granularity-smear" \
  "degrade 원인은 판정 어휘의 --reason 으로, REASONS 순서로"
out="$(python3 "$V" --emit-args --differential "$T/both.yaml" --reason kill-switch --reason kill-switch)"
assert_eq "$out" "qg-verdict-args: --new-failures 2 --defect --reason kill-switch --reason baseline-unrunnable" \
  "주어진 사유와 차등 사유를 합치되 중복 없이 REASONS 순서로"
out="$(python3 "$V" --emit-args --reason kill-switch)"; rc=$?
assert_eq "$rc" "0" "--emit-args --reason kill-switch — exit 0"
assert_eq "$out" "qg-verdict-args: --new-failures 0 --reason kill-switch" "차등을 안 돌렸으면 새 실패 0 과 주어진 사유"
out="$(python3 "$V" --emit-args --reason merge-conflict --reason kill-switch)"
assert_eq "$out" "qg-verdict-args: --new-failures 0 --reason kill-switch --reason merge-conflict" \
  "사유는 준 순서가 아니라 REASONS 순서로"
out="$(python3 "$V" --emit-args)"
assert_eq "$out" "qg-verdict-args: --new-failures 0" "사유도 차등도 없으면 새 실패 0 만"
raw="$(python3 "$V" --emit-args --differential "$T/regress.yaml"; printf x)"
assert_eq "$raw" "$(printf 'qg-verdict-args: --new-failures 1 --defect\nx')" "줄은 개행 하나로 끝나고 그 밖에 아무것도 없다"

for bad in "$L" "--prior $T/regress.yaml" "$L --e2e pass" "--review-blocked" "--angle-absent" "--defect"; do
  # shellcheck disable=SC2086
  out="$(python3 "$V" --emit-args $bad 2>/dev/null)"; rc=$?
  assert_eq "$rc" "2" "--emit-args 는 $bad 와 함께 쓰지 않는다 — exit 2"
  assert_eq "$out" "" "exit 2 면 stdout 이 비어 있다 ($bad)"
done
for f in twice none word neg plus under space unknown; do
  out="$(python3 "$V" --emit-args --differential "$T/$f.yaml" 2>/dev/null)"; rc=$?
  assert_eq "$rc" "4" "--emit-args 차등 산출물 이상($f) — exit 4"
  assert_eq "$out" "" "exit 4 면 stdout 이 비어 있다 ($f)"
done
out="$(python3 "$V" --emit-args --reason no-such-reason 2>/dev/null)"; rc=$?
assert_eq "$rc" "4" "열거 밖 사유는 exit 4"
assert_eq "$out" "" "열거 밖 사유면 줄을 내지 않는다"

# 배열 자리에 글자 그대로 붙여도 같은 낱말이 되려면 모든 낱말이 따옴표 없이 안전해야 한다.
bad_tok=""; n_tok=0
for f in regress degrade both; do
  line="$(python3 "$V" --emit-args --differential "$T/$f.yaml" --reason kill-switch)"
  for tok in ${line#qg-verdict-args: }; do
    n_tok=$((n_tok+1))
    printf '%s' "$tok" | grep -Eq '^[A-Za-z0-9-]+$' || bad_tok="$bad_tok $tok"
  done
done
assert_eq "$n_tok" "20" "낱말 검사가 세 줄의 낱말 20개를 모두 봤다 (비어서 통과하지 않는다)"
reasons_unsafe="$(python3 -I -c 'import re, sys; sys.path.insert(0, sys.argv[1]); import verdict
print(" ".join(r for r in verdict.REASONS if not re.fullmatch(r"[a-z0-9-]+", r)))' "$SCRIPT_DIR/../scripts")"
assert_eq "$bad_tok" "" "인자 줄의 낱말은 모두 따옴표가 필요 없는 글자다"
assert_eq "$reasons_unsafe" "" "REASONS 의 모든 사유가 따옴표 없이 쓸 수 있는 낱말이다"

# 왕복 — 낸 인자를 판정 줄 호출에 붙인 결과가 지금 경로(--differential 직접)와 같다.
for f in regress degrade both; do
  line="$(python3 "$V" --emit-args --differential "$T/$f.yaml")"
  read -r -a D_ARGS <<< "${line#qg-verdict-args: }"
  k="$(sed -n 's/^new_failures: //p' "$T/$f.yaml")"
  via="$(python3 "$V" ${D_ARGS[@]+"${D_ARGS[@]}"} --line --blocking 0 --optional 0 --excluded 0 --iter 1 --sha abc1234 --e2e '안 함')"; rc=$?
  assert_eq "$rc" "0" "왕복($f) — 인자 줄 경로 exit 0"
  direct="$(python3 "$V" --differential "$T/$f.yaml" --line --blocking 0 --optional 0 --new-failures "$k" \
    --excluded 0 --iter 1 --sha abc1234 --e2e '안 함')"
  assert_eq "$via" "$direct" "왕복($f) — 판정 출력과 판정 줄이 --differential 직접 경로와 같다"
done
rm -rf "$T"

finish
