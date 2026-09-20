#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_edit_diff.py
#
# seed_edit_diff.py 를 실행으로 잰다 — 저자 편집 공시(설계 §5.5 변경 D)의 기계 쪽.
#   · 기준 사본은 «공시될 때까지» 산다 — init 은 덮어쓰지 않고 교체는 accept 하나뿐(AC6b)
#   · 덩어리 셋(바꿈 · 끼움 · 지움) 태그 · id 순서 무관 되돌리기 · 지움의 스플라이스 ·
#     render 전체 문자열(머리줄 + 모든 -/+ 줄)까지 검증한다
#   · revert · accept 는 «공시된 판본」에 묶인다 — hunks 뒤 seed 가 또 바뀌면 rc 4(설계 §5.5-2)
#   · seed·기준 사본이 UTF-8 이 아니면 traceback 없이 rc 2
#   · 기준 사본 부재는 rc 3
#   · revert 표지 — 같은 공시에서 같은 되돌리기는 다시 하지 않고(already), 다른 되돌리기는 rc 4
#   · 변이: init 의 AC6b 보호를 지우면 재-init 뒤 편집이 실제로 사라진다(hunks 0) — 단언에 이빨이
#     있다. 니들이 없으면(소스가 바뀌면) fail-closed 로 RED
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/seed_edit_diff.py"; exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
X="$ROOT/plugins/spec-distill/scripts/seed_edit_diff.py"
TMP="$(mktemp -d -t sd-seed-diff-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT
test -f "$X" || { no "부재: $X"; finish; exit; }
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$1" "$2"; }
sha() { python3 -c 'import sys,hashlib; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$1"; }

B="$TMP/base.md"; S="$TMP/seed.md"
printf 'A 첫 줄\nB 둘째 줄\nC 셋째 줄\nD 넷째 줄\n' > "$S"

# ── init 은 없을 때만 뜬다 ────────────────────────────────────────────────────
python3 "$X" init "$B" "$S"; rc=$?
assert_eq "$rc" "0" "init rc 0"
assert_eq "$(cat "$B")" "$(cat "$S")" "init: 기준 사본 = seed"
python3 "$X" hunks "$B" "$S" > "$TMP/h0.json"
assert_eq "$(j "$TMP/h0.json" 'd["empty"], len(d["hunks"])')" "(True, 0)" "편집 전: 덩어리 0"

# ── 편집 셋 → 덩어리 셋 ───────────────────────────────────────────────────────
printf 'A 첫 줄\nB 둘째 줄을 고쳤다\nC 셋째 줄\nNEW 끼운 줄\n' > "$S"   # B 바꿈 · D 자리에 NEW(바꿈)
python3 "$X" hunks "$B" "$S" > "$TMP/h1.json"
assert_eq "$(j "$TMP/h1.json" 'len(d["hunks"])')" "2" "바꿈 두 자리 → 덩어리 둘"
assert_eq "$(j "$TMP/h1.json" '[h["removed"] for h in d["hunks"]]')" "[['B 둘째 줄'], ['D 넷째 줄']]" "덩어리의 지운 줄"
assert_eq "$(j "$TMP/h1.json" '[h["added"] for h in d["hunks"]]')" "[['B 둘째 줄을 고쳤다'], ['NEW 끼운 줄']]" "덩어리의 더한 줄"
assert_contains "$(j "$TMP/h1.json" 'd["hunks"][0]["render"]')" "덩어리 1 — 기준 2행 → 현재 2행" "render 머리줄"

# ── AC6b — 편집 뒤 init 을 다시 불러도 기준 사본은 그대로 ───────────────────
python3 "$X" init "$B" "$S"
python3 "$X" hunks "$B" "$S" > "$TMP/h2.json"
assert_eq "$(j "$TMP/h2.json" 'len(d["hunks"])')" "2" "AC6b: init 재호출이 기준 사본을 갈아치우지 않는다 — 편집이 diff 에 남는다"

# ── revert — 고른 덩어리만 ────────────────────────────────────────────────────
python3 "$X" revert "$B" "$S" --ids 2 > /dev/null; rc=$?
assert_eq "$rc" "0" "revert rc 0"
assert_eq "$(sed -n 4p "$S")" "D 넷째 줄" "revert: 덩어리 2 만 기준 쪽으로 돌아왔다"
assert_eq "$(sed -n 2p "$S")" "B 둘째 줄을 고쳤다" "revert: 덩어리 1 은 그대로"
python3 "$X" hunks "$B" "$S" > "$TMP/h3.json"
assert_eq "$(j "$TMP/h3.json" 'len(d["hunks"])')" "1" "revert 뒤 덩어리 하나 남음"
python3 "$X" revert "$B" "$S" --ids 9 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "revert: 없는 덩어리 번호는 rc 2"

# ── 끼움만 ───────────────────────────────────────────────────────────────────
cp "$B" "$TMP/b2.md"; printf 'A 첫 줄\nB 둘째 줄\nZ 새 줄\nC 셋째 줄\nD 넷째 줄\n' > "$TMP/s2.md"
python3 "$X" hunks "$TMP/b2.md" "$TMP/s2.md" > "$TMP/h4.json"
assert_eq "$(j "$TMP/h4.json" '[h["tag"] for h in d["hunks"]]')" "['insert']" "끼움만 → insert 덩어리 하나"
assert_contains "$(j "$TMP/h4.json" 'd["hunks"][0]["render"]')" "기준 3행 앞(없음)" "insert 의 기준 범위 표기"

# ── 바꿈(길이 바뀜) · 끼움 · 지움 세 덩어리 — 태그 · id 순서 무관 되돌리기 ·
#    지움 덩어리의 스플라이스 · render 전체 문자열 ────────────────────────────
printf 'A 첫 줄\nB 둘째 줄\nC 셋째 줄\nD 넷째 줄\nE 다섯째 줄\nF 여섯째 줄\nG 일곱째 줄\n' > "$TMP/base3.md"
printf 'A 첫 줄\nB-1 바뀐 줄 하나\nB-2 바뀐 줄 둘\nC 셋째 줄\nD 넷째 줄\nZ 끼운 줄\nE 다섯째 줄\nG 일곱째 줄\n' > "$TMP/seed3.md"
python3 "$X" hunks "$TMP/base3.md" "$TMP/seed3.md" > "$TMP/h7.json"
assert_eq "$(j "$TMP/h7.json" '[h["tag"] for h in d["hunks"]]')" "['replace', 'insert', 'delete']" "세 덩어리: 태그 순서 — 바꿈 · 끼움 · 지움"
EXPECTED_RENDER=$'덩어리 1 — 기준 2행 → 현재 2–3행\n- B 둘째 줄\n+ B-1 바뀐 줄 하나\n+ B-2 바뀐 줄 둘'
assert_eq "$(j "$TMP/h7.json" 'd["hunks"][0]["render"]')" "$EXPECTED_RENDER" "세 덩어리: render 전체 문자열 — 덩어리 1(바꿈, 길이 바뀜)"

cp "$TMP/base3.md" "$TMP/base3b.md"; cp "$TMP/seed3.md" "$TMP/seed3b.md"
python3 "$X" hunks "$TMP/base3b.md" "$TMP/seed3b.md" > /dev/null   # 독립 사본 — 자신만의 공시 판본을 세운다

python3 "$X" revert "$TMP/base3.md" "$TMP/seed3.md" --ids 1,3 > /dev/null; rc=$?
assert_eq "$rc" "0" "세 덩어리: revert --ids 1,3 rc 0"
EXPECTED3=$'A 첫 줄\nB 둘째 줄\nC 셋째 줄\nD 넷째 줄\nZ 끼운 줄\nE 다섯째 줄\nF 여섯째 줄\nG 일곱째 줄'
assert_eq "$(cat "$TMP/seed3.md")" "$EXPECTED3" "세 덩어리: revert --ids 1,3 결과 — 바꿈은 되돌고 끼움은 남고 지움은 스플라이스된다"
assert_eq "$(sed -n 7p "$TMP/seed3.md")" "F 여섯째 줄" "지움 덩어리의 되돌리기 — 기준 줄이 다시 스플라이스된다"

python3 "$X" revert "$TMP/base3b.md" "$TMP/seed3b.md" --ids 3,1 > /dev/null; rc=$?
assert_eq "$rc" "0" "세 덩어리: revert --ids 3,1 rc 0"
assert_eq "$(cat "$TMP/seed3b.md")" "$(cat "$TMP/seed3.md")" "세 덩어리: id 순서를 바꿔도(3,1) 결과가 같다"

# ── accept — 교체 뒤 덩어리 0 ────────────────────────────────────────────────
python3 "$X" accept "$B" "$S"; rc=$?
assert_eq "$rc" "0" "accept rc 0"
python3 "$X" hunks "$B" "$S" > "$TMP/h5.json"
assert_eq "$(j "$TMP/h5.json" 'd["empty"]')" "True" "accept 뒤: 저자 편집 없음"

# ── 부재 ─────────────────────────────────────────────────────────────────────
python3 "$X" hunks "$TMP/none.md" "$S" > "$TMP/h6.json"; rc=$?
assert_eq "$rc" "3" "기준 사본 부재 → rc 3"
assert_eq "$(j "$TMP/h6.json" 'd["base_present"]')" "False" "기준 사본 부재를 JSON 으로도 밝힌다"
python3 "$X" hunks "$B" "$TMP/none.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "seed 부재 → rc 2"
cp "$S" "$TMP/rv.md"; RV_SHA="$(sha "$TMP/rv.md")"
python3 "$X" revert "$TMP/none-base.md" "$TMP/rv.md" --ids 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "3" "revert: 기준 사본 부재 → rc 3"
assert_eq "$(sha "$TMP/rv.md")" "$RV_SHA" "revert rc3: seed 바이트가 그대로다"
# 빈 경로 인자 — 「## 상태」 가 값을 못 세운 셸에서 부르면 이 모양이다. 문서화된 rc 밖(트레이스백 rc 1)으로 새지 않는다.
for cmd in init hunks accept; do
  EMPTY_OUT="$(python3 "$X" "$cmd" "" "$S" 2>&1)"; rc=$?
  assert_eq "$rc" "2" "$cmd: 빈 기준 사본 경로 → rc 2"
  assert_not_contains "$EMPTY_OUT" "Traceback" "$cmd: 빈 경로에 트레이스백을 내지 않는다"
done
python3 "$X" revert "" "$S" --ids 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "revert: 빈 기준 사본 경로 → rc 2"

# ── UTF-8 아닌 seed → rc 2(traceback 없이) ───────────────────────────────────
printf '\xff\xfe bad bytes' > "$TMP/bad.md"
BAD_OUT="$(python3 "$X" hunks "$B" "$TMP/bad.md" 2>&1)"; rc=$?
assert_eq "$rc" "2" "UTF-8 아닌 seed → rc 2"
assert_not_contains "$BAD_OUT" "Traceback" "UTF-8 오류: traceback 없이 rc 2"

# ── 판본 묶기 — hunks 뒤에 seed 가 바뀌면 revert · accept 는 rc 4(설계 §5.5-2) ──
VB="$TMP/vbase.md"; VS="$TMP/vseed.md"
printf 'P 첫 줄\nQ 둘째 줄\nR 셋째 줄\n' > "$VS"
python3 "$X" init "$VB" "$VS" > /dev/null
printf 'P 첫 줄\nQ 둘째 줄을 고쳤다\nR 셋째 줄\n' > "$VS"
python3 "$X" hunks "$VB" "$VS" > "$TMP/hv1.json"
assert_eq "$(j "$TMP/hv1.json" 'd["seed_sha256"]')" "$(sha "$VS")" "hunks JSON 의 seed_sha256 = 파일 sha256"

VB2="$TMP/vbase2.md"; VS2="$TMP/vseed2.md"
printf 'X\n' > "$VS2"
python3 "$X" init "$VB2" "$VS2" > /dev/null
printf 'Y\n' > "$VS2"
python3 "$X" accept "$VB2" "$VS2" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "accept: hunks 로 보인 적 없는 판본은 rc 4"
assert_eq "$(cat "$VB2")" "X" "accept rc4: 기준 사본은 그대로 X"

BEFORE_BASE_SHA="$(sha "$VB")"
printf 'P 첫 줄\nQ 또 고쳤다\nR 셋째 줄\n' > "$VS"
python3 "$X" accept "$VB" "$VS" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "accept: 공시(hunks) 뒤 seed 가 또 바뀌면 rc 4"
assert_eq "$(sha "$VB")" "$BEFORE_BASE_SHA" "accept rc4: 기준 사본 바이트가 그대로다"

python3 "$X" hunks "$VB" "$VS" > "$TMP/hv2.json"
printf 'P 첫 줄\nQ 또 고쳤다\nR 넷째 줄로 또 바뀜\n' > "$VS"
EXPECT_SEED_SHA="$(sha "$VS")"
python3 "$X" revert "$VB" "$VS" --ids 1 >/dev/null 2>&1; rc=$?
assert_eq "$rc" "4" "revert: 공시(hunks) 뒤 seed 가 또 바뀌면 rc 4"
assert_eq "$(sha "$VS")" "$EXPECT_SEED_SHA" "revert rc4: seed 바이트가 그대로다"
python3 "$X" hunks "$VB" "$VS" > /dev/null
python3 "$X" revert "$VB" "$VS" --ids abc >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "revert: 정수가 아닌 --ids → rc 2(공시된 판본이어도)"
assert_eq "$(sha "$VS")" "$EXPECT_SEED_SHA" "revert rc2(--ids abc): seed 바이트가 그대로다"

VB3="$TMP/vbase3.md"; VS3="$TMP/vseed3.md"
printf 'M 첫 줄\nN 둘째 줄\n' > "$VS3"
python3 "$X" init "$VB3" "$VS3" > /dev/null
printf 'M 첫 줄\nN 둘째 줄을 고쳤다\n' > "$VS3"
python3 "$X" hunks "$VB3" "$VS3" > /dev/null
python3 "$X" revert "$VB3" "$VS3" --ids 1 > /dev/null; rc=$?
assert_eq "$rc" "0" "행복경로: hunks 뒤 revert rc 0"
python3 "$X" accept "$VB3" "$VS3" > /dev/null; rc=$?
assert_eq "$rc" "0" "행복경로: revert 뒤(재공시 없이) accept rc 0 — revert 가 스스로 다시 공시한다"
python3 "$X" hunks "$VB3" "$VS3" > "$TMP/hv3.json"
assert_eq "$(j "$TMP/hv3.json" 'd["empty"]')" "True" "행복경로: accept 뒤 hunks 는 비었다"

# ── revert 표지 — 되돌린 뒤 덩어리 번호가 다시 매겨지므로 같은 --ids 를 다시 적용하지 않는다 ──
RB="$TMP/rbase.md"; RS="$TMP/rseed.md"
printf 'a\nB0\nc\nd\ne\nf\nG0\nh\n' > "$RS"; python3 "$X" init "$RB" "$RS" > /dev/null
printf 'a\nB1\nc\nd\ne\nf\nG1\nh\n' > "$RS"
python3 "$X" hunks "$RB" "$RS" > /dev/null
python3 "$X" revert "$RB" "$RS" --ids 1 > /dev/null; rc=$?
assert_eq "$rc" "0" "표지: 첫 revert rc 0"
[ -s "$RB.reverted" ] && ok "표지: revert 가 <base>.reverted 를 남긴다" || no "표지: revert 뒤 표지가 없다"
AFTER1="$(sha "$RS")"
python3 "$X" revert "$RB" "$RS" --ids 1 > "$TMP/r2.json"; rc=$?
assert_eq "$rc" "0" "표지: 같은 번호 · 같은 판본의 revert 는 rc 0"
assert_eq "$(j "$TMP/r2.json" 'd.get("already")')" "True" "표지: 이미 되돌렸다고 밝힌다"
assert_eq "$(sha "$RS")" "$AFTER1" "표지: 다시 불러도 seed 가 그대로다 — 번호가 다시 매겨진 덩어리(G1)를 되돌리지 않는다"
assert_contains "$(cat "$RS")" "G1" "표지: 남기기로 한 덩어리가 산다"
python3 "$X" revert "$RB" "$RS" --ids 2 >/dev/null 2>"$TMP/r3.err"; rc=$?
assert_eq "$rc" "4" "표지: 이 공시에서 다른 번호를 또 되돌리려 하면 rc 4"
assert_contains "$(cat "$TMP/r3.err")" "[spec-distill]" "표지: rc 4 를 표준 접두사로 알린다"
python3 "$X" hunks "$RB" "$RS" > /dev/null
[ ! -e "$RB.reverted" ] && ok "표지: 새 공시(hunks)가 표지를 지운다" || no "표지: 새 공시 뒤에도 표지가 남았다"
python3 "$X" revert "$RB" "$RS" --ids 1 > /dev/null; rc=$?
assert_eq "$rc" "0" "표지 양의 짝: 새 공시 뒤에는 그 공시의 번호로 되돌릴 수 있다"
python3 "$X" accept "$RB" "$RS" > /dev/null
[ ! -e "$RB.reverted" ] && ok "표지: accept 가 표지를 지운다" || no "표지: accept 뒤에도 표지가 남았다"

# ── 변이 — init 의 AC6b 보호(base.exists 검사)를 지우면 재-init 뒤 편집이
#    실제로 사라진다 ─────────────────────────────────────────────────────────
MUT_STATUS="$(python3 - "$X" "$TMP/mut.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = "if base.exists():"
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "if False:", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
)"
assert_eq "$MUT_STATUS" "MUTATED" "변이: 니들이 소스에 있다 — 없으면 이 변이는 fail-closed 로 실패한다"

MB="$TMP/mb.md"; MS="$TMP/ms.md"
printf 'p 첫 줄\nq 둘째 줄\n' > "$MS"
python3 "$TMP/mut.py" init "$MB" "$MS" > /dev/null
printf 'p 첫 줄\nq 둘째 줄을 고쳤다\n' > "$MS"
python3 "$TMP/mut.py" init "$MB" "$MS" > /dev/null
python3 "$X" hunks "$MB" "$MS" > "$TMP/hmut.json"
assert_eq "$(j "$TMP/hmut.json" 'd["empty"]')" "True" "변이: init 보호를 지우면 재-init 뒤 편집이 사라진다(hunks 0) — AC6b 단언에 이빨이 있다"

finish
