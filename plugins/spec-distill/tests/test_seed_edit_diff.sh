#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_edit_diff.py
#
# seed_edit_diff.py 를 실행으로 잰다 — 저자 편집 공시(설계 §5.5 변경 D)의 기계 쪽.
#   · 기준 사본은 «공시될 때까지» 산다 — init 은 덮어쓰지 않고 교체는 accept 하나뿐(AC6b)
#   · 덩어리 셋(바꿈 · 끼움 · 지움)을 따로 낸다 · 골라서 되돌린다 · 기준 사본 부재는 rc 3
#   · 변이: init 이 덮어쓰게 바꾸면 AC6b 단언이 RED
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

# ── 끼움만 · 지움만 ───────────────────────────────────────────────────────────
cp "$B" "$TMP/b2.md"; printf 'A 첫 줄\nB 둘째 줄\nZ 새 줄\nC 셋째 줄\nD 넷째 줄\n' > "$TMP/s2.md"
python3 "$X" hunks "$TMP/b2.md" "$TMP/s2.md" > "$TMP/h4.json"
assert_eq "$(j "$TMP/h4.json" '[h["tag"] for h in d["hunks"]]')" "['insert']" "끼움만 → insert 덩어리 하나"
assert_contains "$(j "$TMP/h4.json" 'd["hunks"][0]["render"]')" "기준 3행 앞(없음)" "insert 의 기준 범위 표기"

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

# ── 변이 — init 이 덮어쓰면 AC6b 가 RED 여야 한다 ─────────────────────────────
python3 - "$X" "$TMP/mut.py" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
needle = "if base.exists():"
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(needle, "if False:", 1))
print("MUTATED" if needle in t else "UNCHANGED")
PY
printf 'x\n' > "$TMP/mb.md"; printf 'y\n' > "$TMP/ms.md"
python3 "$TMP/mut.py" init "$TMP/mb.md" "$TMP/ms.md"
[ "$(cat "$TMP/mb.md")" = "y" ] \
  && ok "변이: init 의 존재 검사를 지우면 기준 사본이 갈아치워진다 — AC6b 단언에 이빨이 있다" \
  || no "변이: 검사를 지워도 기준 사본이 안 바뀐다 — AC6b 단언은 다른 이유로 통과한다"
finish
