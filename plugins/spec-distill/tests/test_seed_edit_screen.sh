#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/seed_edit_screen.py
#
# seed_edit_screen.py 를 실행으로 잰다 — 저자 편집 승인 화면의 기계 쪽.
#   · 화면은 바뀐 문장만 보인다 — 꼴 넷(문장으로 가르지 못함 · 바뀐 문장 없음 · 문단 나눔도 바뀜 · 바뀐 문장만)
#   · 권장은 저자가 댄 지적 전부에 사용자의 고치는 쪽 처분이 원장에 있고 앞 화면에서 대지 않았을 때만 붙는다
#   · 질문 묶음은 한 질문에 덩어리 넷까지 · 권장이 앞 · 덩어리 하나짜리 질문은 전체가 하나일 때만
#   · 미리 보기 · 화면 조립은 읽기만 한다. 쓴 지적 목록에 더하기는 번호 전수 대조 뒤에만 쓴다
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "plugins/spec-distill/scripts/seed_edit_screen.py"; exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
S="$ROOT/plugins/spec-distill/scripts"
X="$S/seed_edit_screen.py"
TMP="$(mktemp -d -t sd-seed-screen-XXXXXX)" || exit 1
trap 'rm -rf "$TMP"' EXIT
test -f "$X" || { no "부재: $X"; finish; exit; }

mk() {   # mk <이름> <기준 글> <지금 글> — 글은 printf %b 로 푼다. $TMP/<이름>/{base.md,seed.md,hunks.json,state/}
  mkdir -p "$TMP/$1/state"
  printf '%b' "$2" > "$TMP/$1/base.md"; printf '%b' "$3" > "$TMP/$1/seed.md"
  python3 "$S/seed_edit_diff.py" hunks "$TMP/$1/base.md" "$TMP/$1/seed.md" > "$TMP/$1/hunks.json"
}
scr() {  # scr <이름> [--final] → 화면 JSON 을 $TMP/<이름>/screen.json 에, rc 는 화면 조립의 rc
  local n="$1"; shift
  python3 "$X" screen --hunks "$TMP/$n/hunks.json" --reasons "$TMP/$n/state/hunk-reasons.txt" --state-dir "$TMP/$n/state" "$@" > "$TMP/$n/screen.json"
}
# j <이름> <식> — 화면 JSON(d)에 식을 매겨 낸다. 식은 이 파일에 적힌 고정 글자뿐이다(test_seed_edit_diff.sh 의 j 와 같은 꼴).
j() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(eval(sys.argv[2]))' "$TMP/$1/screen.json" "$2"; }
sums() {   # sums <폴더> → 화면 · 미리 보기 출력 파일을 뺀 모든 파일의 경로와 sha256
  python3 -c 'import hashlib, os, sys
for r, _, fs in sorted(os.walk(sys.argv[1])):
    for f in sorted(fs):
        if f not in ("screen.json", "preview.json"):
            p = os.path.join(r, f)
            print(p, hashlib.sha256(open(p, "rb").read()).hexdigest())' "$1"
}

# ── AC1 — 바뀐 문장만 ─────────────────────────────────────────────────────────
mk one '가. 나. 다.\n' '가. 나 고침. 다.\n'
before="$(sums "$TMP/one")"
scr one; rc=$?
assert_eq "$rc" "0" "AC1: 화면 조립 rc 0"
assert_eq "$(sums "$TMP/one")" "$before" "AC8: 화면 조립은 seed · 기준 사본 · 공시 기록(.shown) · 덩어리 JSON 을 바꾸지 않는다"
assert_eq "$(j one '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"], d["hunks"][0]["kept"])')" \
  "(4, ['나.'], ['나 고침.'], 2)" "AC1: 한 문장만 바뀌면 뺀 문장 하나 · 더한 문장 하나 · 그대로 둘"
T1="$(j one 'd["text"]')"
assert_eq "$(j one 'd["text"].split("\n")[0]')" "저자 편집 1곳 — 달라진 문장만 보입니다" "AC1: 화면 글 첫 줄"
assert_contains "$T1" "1) 기준 1행 → 현재 1행 · 뺀 문장 1개 · 더한 문장 1개 · 그대로 2문장" "AC1: 그대로인 문장은 수로만 나온다"
assert_contains "$T1" "   뺀 문장: 나." "AC1: 뺀 문장 줄"
assert_contains "$T1" "   더한 문장: 나 고침." "AC1: 더한 문장 줄"
assert_not_contains "$T1" "가." "AC1: 그대로인 문장의 글자는 화면에 없다"
assert_not_contains "$T1" "   - " "AC1: 줄 전체 꼴이 붙지 않는다"
mk add1 '가. 나.\n' '가. 나. 다.\n'; scr add1
assert_eq "$(j add1 '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(4, [], ['다.'])" "AC1: 문장 하나만 더하면 그 문장 하나만"
assert_not_contains "$(j add1 'd["text"]')" "   + " "AC1: 문장만 더한 덩어리에 줄 전체 꼴이 붙지 않는다"
mk del1 '가. 나. 다.\n' '가. 다.\n'; scr del1
assert_eq "$(j del1 '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(4, ['나.'], [])" "AC1: 문장 하나만 빼면 그 문장 하나만"
mk padd '가.\n\n나.\n' '가.\n\n새 문단. 둘째.\n\n나.\n'; scr padd
assert_eq "$(j padd '(d["hunks"][0]["shape"], d["hunks"][0]["added_sentences"], d["text"].count("새 문단."), "   + " in d["text"])')" \
  "(4, ['새 문단.', '둘째.'], 1, False)" "AC1: 빈 줄과 함께 통째로 더한 문단은 문장이 한 번만 나오고 줄 전체 꼴이 없다"
mk pdel '가.\n\n지울 문단.\n\n나.\n' '가.\n\n나.\n'; scr pdel
assert_eq "$(j pdel '(d["hunks"][0]["shape"], d["hunks"][0]["removed_sentences"], d["text"].count("지울 문단."), "   - " in d["text"])')" \
  "(4, ['지울 문단.'], 1, False)" "AC1: 빈 줄과 함께 통째로 지운 문단도 같다"

# ── AC2 — 불변식 · 자리 옮김 · 문단 나눔도 바뀐 꼴 ──────────────────────────────
inv() {   # inv <이름> → 덩어리마다 기준 쪽에서 뺀 문장을, 지금 쪽에서 더한 문장을 지운 열이 순서까지 같으면 ok
  python3 - "$S" "$TMP/$1/hunks.json" "$TMP/$1/screen.json" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import seed_edit_screen as m
from seed_provenance import norm
hs = json.load(open(sys.argv[2], encoding="utf-8"))["hunks"]
vs = json.load(open(sys.argv[3], encoding="utf-8"))["hunks"]
bad = []
for h, v in zip(hs, vs):
    b = [norm(u) for l in h["removed"] for u in m.line_units(l)]
    s = [norm(u) for l in h["added"] for u in m.line_units(l)]
    kb = [k for i, k in enumerate(b) if i not in set(v["removed_idx"])]
    ks = [k for i, k in enumerate(s) if i not in set(v["added_idx"])]
    if kb != ks or len(kb) != v["kept"]:
        bad.append(h["id"])
print("ok" if hs and len(hs) == len(vs) and not bad else "bad %s" % bad)
PY
}
while IFS='|' read -r name base seed shapes; do
  mk "$name" "$base" "$seed"; scr "$name"
  assert_eq "$(inv "$name")" "ok" "AC2 불변식: $name"
  assert_eq "$(j "$name" '[h["shape"] for h in d["hunks"]]')" "$shapes" "AC2 꼴: $name"
done <<'EOF'
ins|가. 나.\n|가. 새. 나.\n|[4]
del|가. 새. 나.\n|가. 나.\n|[4]
rep|가. 나.\n|가. 나 고침.\n|[4]
multi|가.\n나.\n다.\n|가 고침.\n나 고침.\n다.\n|[4]
marked|가. (사용자 확인) 나.\n|가. (사용자 확인) 나 고침.\n|[4]
merge|가. 나.\n다. 라.\n|가. 나 고침. 다. 라.\n|[3]
reorder|가. 나.\n|나. 가.\n|[4]
swap|가. 나.\n\n다. 라.\n|가. 라.\n\n다. 나.\n|[4, 4]
blank|가. 나.\n다.\n|가. 나 고침.\n\n다.\n|[3]
space|가  나. 다.\n|가 나. 다 고침.\n|[3]
dup|가. 가. 나.\n|가. 나. 가.\n|[4]
nopunct|제목 줄\n- 목록 하나\n|제목 줄\n- 목록 둘\n|[4]
delfirst|가. 나. 다.\n|나. 다.\n|[4]
insfirst|나. 다.\n|가. 나. 다.\n|[4]
paddend|가.\n\n나.\n|가.\n\n나.\n\n새 문단.\n|[4]
repl|가.\n\n옛 문단.\n\n나.\n|가.\n\n새 문단.\n\n나.\n|[4]
chgpdel|가. 나.\n\n지울 문단.\n|가. 나 고침.\n|[4]
replblank|가.\n옛 문단.\n\n나.\n|가.\n새 문단.\n나.\n|[3]
gap|가.  나. 다.\n|가. 나. 다 고침.\n|[3]
tail|가. 나. \n|가. 나 고침.\n|[4]
tailkept|가. \n나.\n|가.\n나 고침.\n|[3]
wsline|가. 나.\n  \n다.\n|가. 나 고침.\n\n다.\n|[3]
EOF
for name in delfirst insfirst paddend repl chgpdel; do
  assert_eq "$(j "$name" '("   - " in d["text"], "   + " in d["text"], "문단 나눔" in d["text"])')" "(False, False, False)" "AC1: 문장 · 문단을 더하거나 빼거나 통째로 바꾼 것만으로 설명되면 줄 전체 꼴이 붙지 않는다 — $name"
done
TB="$(j replblank 'd["text"]')"
assert_contains "$TB" "   더한 문장: 새 문단." "AC2: 문단을 통째로 바꾸면서 빈 줄을 따로 지운 덩어리도 바뀐 문장을 보인다"
assert_contains "$TB" "   문단 나눔 · 공백도 바뀜" "AC2: 문단을 통째로 바꾸면서 한쪽에서만 맞닿은 빈 줄을 지우면 그 사실 한 줄"
assert_contains "$TB" "   - 옛 문단." "AC2: 그 덩어리는 줄 전체 꼴이 함께 보인다(사라진 빈 줄이 드러난다)"
TG="$(j gap 'd["text"]')"
assert_contains "$TG" "   문단 나눔 · 공백도 바뀜" "AC2: 그대로인 문장 사이의 공백만 바뀐 것도 문장 변경과 함께면 그 사실 한 줄"
assert_contains "$TG" "   - 가.  나. 다." "AC2: 그 덩어리는 줄 전체 꼴(기준 쪽 — 공백 둘)이 함께 보인다"
assert_eq "$(j marked '(d["hunks"][0]["kept"], d["hunks"][0]["removed_sentences"])')" "(1, ['나.'])" "AC2: «(사용자 확인)» 이 붙은 문장은 표시째 한 단위로 그대로다"
TM="$(j merge 'd["text"]')"
assert_contains "$TM" "   뺀 문장: 나." "AC2: 문단을 합친 덩어리도 바뀐 문장을 보인다"
assert_contains "$TM" "   문단 나눔 · 공백도 바뀜" "AC2: 문장 변경과 문단 합치기가 섞이면 그 사실 한 줄"
assert_contains "$TM" "   - 가. 나." "AC2: 그 덩어리는 줄 전체 꼴(기준 쪽)이 함께 보인다"
assert_contains "$TM" "   + 가. 나 고침. 다. 라." "AC2: 그 덩어리는 줄 전체 꼴(지금 쪽)이 함께 보인다"
assert_contains "$(j blank 'd["text"]')" "   문단 나눔 · 공백도 바뀜" "AC2: 빈 줄을 따로 넣은 덩어리"
assert_contains "$(j space 'd["text"]')" "   문단 나눔 · 공백도 바뀜" "AC2: 그대로인 문장의 공백이 바뀐 덩어리"
TR="$(j reorder 'd["text"]')"
assert_contains "$TR" "   뺀 문장(자리 옮김): 나." "AC2: 순서만 바뀐 문장은 뺀 쪽에 「자리 옮김」"
assert_contains "$TR" "   더한 문장(자리 옮김): 나." "AC2: 순서만 바뀐 문장은 더한 쪽에도 「자리 옮김」"
assert_eq "$(j swap '[(h["removed_sentences"], h["removed_moved"], h["added_sentences"], h["added_moved"]) for h in d["hunks"]]')" \
  "[(['나.'], [True], ['라.'], [True]), (['라.'], [True], ['나.'], [True])]" "AC2: 두 문단 사이에서 맞바꾼 문장은 두 덩어리에 걸쳐 「자리 옮김」 이 붙는다"
assert_not_contains "$(j rep 'd["text"]')" "자리 옮김" "AC2: 고친 문장에는 「자리 옮김」 이 붙지 않는다"
assert_eq "$(j dup '(sum(d["hunks"][0]["removed_moved"]), sum(d["hunks"][0]["added_moved"]))')" "(1, 1)" "Review Focus: 같은 문장이 여럿이어도 「자리 옮김」 은 하나씩만 짝짓는다"
assert_eq "$(j nopunct '(d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(['- 목록 하나'], ['- 목록 둘'])" "Review Focus: 문장 끝 부호가 없는 줄은 줄 하나가 한 단위다"

# ── AC3 — 바뀐 문장 없는 덩어리 · 불변식이 어긋난 덩어리 · 표시만 바뀐 편집 ─────────
while IFS='|' read -r name base seed; do
  mk "$name" "$base" "$seed"; scr "$name"
  assert_eq "$(j "$name" '[(h["shape"], h["removed_sentences"], h["added_sentences"]) for h in d["hunks"]]')" "[(2, [], [])]" "AC3 바뀐 문장 없음: $name"
  assert_contains "$(j "$name" 'd["text"]')" "   바뀐 문장 없음 — 줄 전체를 보인다" "AC3 안내 줄: $name"
  assert_not_contains "$(j "$name" 'd["text"]')" "문단 나눔 · 공백도 바뀜" "AC3 다른 안내는 붙지 않는다: $name"
done <<'EOF'
ws|가.  나.\n|가. 나.\n
blankonly|가.\n나.\n|가.\n\n나.\n
mergeonly|가.\n나.\n|가. 나.\n
splitonly|가. 나.\n|가.\n나.\n
EOF
assert_contains "$(j ws 'd["text"]')" "   - 가.  나." "AC3: 공백만 바뀐 덩어리는 줄 전체(기준 쪽)를 보인다"
assert_contains "$(j ws 'd["text"]')" "   + 가. 나." "AC3: 공백만 바뀐 덩어리는 줄 전체(지금 쪽)를 보인다"
python3 - "$S" "$TMP/one/hunks.json" "$TMP/one/state/hunk-reasons.txt" "$TMP/one/state" > "$TMP/sh1.txt" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import seed_edit_screen as m
m.sentence_diff = lambda base_keys, seed_keys: ([], [])   # 바뀐 문장을 놓친 차이 — 불변식이 어긋난다
out = m.build_screen(json.load(open(sys.argv[2], encoding="utf-8")), sys.argv[3], sys.argv[4])
print(out["hunks"][0]["shape"])
print(out["text"])
PY
SH1="$(cat "$TMP/sh1.txt")"
assert_eq "$(head -n 1 "$TMP/sh1.txt")" "1" "AC3: 불변식이 어긋나면 꼴 1"
assert_contains "$SH1" "   문장으로 가르지 못함 — 줄 전체를 보인다" "AC3: 불변식이 어긋난 덩어리의 안내 줄"
assert_contains "$SH1" "   - 가. 나. 다." "AC3: 불변식이 어긋난 덩어리는 줄 전체(기준 쪽)"
assert_contains "$SH1" "   + 가. 나 고침. 다." "AC3: 불변식이 어긋난 덩어리는 줄 전체(지금 쪽)"
assert_not_contains "$SH1" "뺀 문장" "AC3: 불변식이 어긋난 덩어리는 문장 줄을 내지 않는다"
mk markon '가. 나.\n' '가. (사용자 확인) 나.\n'; scr markon
assert_eq "$(j markon '(d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(['가.'], ['가. (사용자 확인)'])" "AC3: 표시만 붙인 편집은 표시 없는 문장을 빼고 표시 붙은 문장을 더한 것으로 보인다"
mk markoff '가. (사용자 확인) 나.\n' '가. 나.\n'; scr markoff
assert_eq "$(j markoff '(d["hunks"][0]["removed_sentences"], d["hunks"][0]["added_sentences"])')" "(['가. (사용자 확인)'], ['가.'])" "AC3: 표시만 뗀 편집은 그 반대로 보인다"

# ── AC8 — 미리 보기 ──────────────────────────────────────────────────────────
mkdir -p "$TMP/pv"; printf '가. 나.\n\n다.\n' > "$TMP/pv/base.md"; printf '가. 나 고침.\n\n다 고침.\n' > "$TMP/pv/seed.md"
before="$(sums "$TMP/pv")"
python3 "$X" preview "$TMP/pv/base.md" "$TMP/pv/seed.md" > "$TMP/pv/preview.json"; rc=$?
assert_eq "$rc" "0" "AC8: 미리 보기 rc 0"
assert_eq "$(sums "$TMP/pv")" "$before" "AC8: 미리 보기는 seed · 기준 사본을 바꾸지 않고 공시 기록(.shown)도 남기지 않는다"
python3 "$S/seed_edit_diff.py" hunks "$TMP/pv/base.md" "$TMP/pv/seed.md" > "$TMP/pv/hunks.json"
assert_eq "$(python3 -c 'import json,sys
a = json.load(open(sys.argv[1], encoding="utf-8")); b = json.load(open(sys.argv[2], encoding="utf-8"))
print(a == b, [h["id"] for h in a["hunks"]], len(a["seed_sha256"]))' "$TMP/pv/preview.json" "$TMP/pv/hunks.json")" "True [1, 2] 64" "AC8: 미리 보기의 덩어리 번호 · 판본이 같은 seed 의 hunks 와 같다"
python3 "$X" preview "$TMP/pv/none.md" "$TMP/pv/seed.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "3" "AC8: 기준 사본이 없으면 미리 보기 rc 3"
mk same '가. 나.\n' '가. 나.\n'; scr same
assert_eq "$(j same '(d["text"], d["hunks"], d["questions"])')" "('저자 편집 없음', [], [])" "덩어리가 0 이면 화면 글은 「저자 편집 없음」 한 줄이다"

finish
