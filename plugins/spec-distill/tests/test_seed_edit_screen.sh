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
shown() {   # shown <이름> → 화면 글에 덩어리마다 머리줄이 한 번 있고, 그 덩어리의 뺀 · 더한 문장 줄이 JSON 목록과(자리 옮김 꼴까지 순서대로)
            #               같고, 꼴 4 가 아니면 줄 전체가 덩어리의 줄과 같으면 ok
  python3 - "$S" "$TMP/$1/hunks.json" "$TMP/$1/screen.json" <<'PY'
import json, sys
sys.path.insert(0, sys.argv[1])
import seed_edit_diff
hs = json.load(open(sys.argv[2], encoding="utf-8"))["hunks"]
d = json.load(open(sys.argv[3], encoding="utf-8"))
vs, lines = d["hunks"], d["text"].split("\n")
IND = "   "
bad = []
for k, (h, v) in enumerate(zip(hs, vs), 1):
    head = "%d) 기준 %s → 현재 %s · %s" % (k, seed_edit_diff._span(*h["base"]), seed_edit_diff._span(*h["seed"]), v["summary"])
    at = [i for i, x in enumerate(lines) if x == head]
    if len(at) != 1:
        bad.append((k, "머리줄 %d개" % len(at)))
        continue
    block = []
    for x in lines[at[0] + 1:]:
        if not x:
            break
        block.append(x)
    want_rem = [(IND + ("뺀 문장(자리 옮김): " if m else "뺀 문장: ") + s) for s, m in zip(v["removed_sentences"], v["removed_moved"])]
    want_add = [(IND + ("더한 문장(자리 옮김): " if m else "더한 문장: ") + s) for s, m in zip(v["added_sentences"], v["added_moved"])]
    if len(want_rem) != len(v["removed_sentences"]) or len(want_add) != len(v["added_sentences"]):
        bad.append((k, "자리 옮김 칸 수"))
    if [x for x in block if x.startswith(IND + "뺀 문장")] != want_rem:
        bad.append((k, "뺀 문장"))
    if [x for x in block if x.startswith(IND + "더한 문장")] != want_add:
        bad.append((k, "더한 문장"))
    whole = [x for x in block if x.startswith(IND + "- ") or x.startswith(IND + "+ ")]
    want_whole = [] if v["shape"] == 4 else [IND + "- " + x for x in h["removed"]] + [IND + "+ " + x for x in h["added"]]
    if whole != want_whole:
        bad.append((k, "줄 전체"))
heads = [x for x in lines if x[:1].isdigit() and ") 기준 " in x]
if len(heads) != len(hs):
    bad.append(("머리줄 수", len(heads)))
print("ok" if hs and len(hs) == len(vs) and not bad else "bad %s" % bad)
PY
}
while IFS='|' read -r name base seed shapes; do
  mk "$name" "$base" "$seed"; scr "$name"
  assert_eq "$(inv "$name")" "ok" "AC2 불변식: $name"
  assert_eq "$(shown "$name")" "ok" "AC1 · AC2 화면 글: 덩어리마다 머리줄 · 뺀 문장 · 더한 문장 · 줄 전체가 모두 실린다 — $name"
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
gaphead|X. 가.\n|Y.   가.\n|[3]
delgap|가.   나.\n|나.\n|[4]
EOF
assert_eq "$(shown padd)" "ok" "AC1 화면 글: 통째로 더한 문단의 더한 문장이 모두 실린다 — padd"
for name in delfirst insfirst paddend repl chgpdel delgap; do
  assert_eq "$(j "$name" '("   - " in d["text"], "   + " in d["text"], "문단 나눔" in d["text"])')" "(False, False, False)" "AC1: 문장 · 문단을 더하거나 빼거나 통째로 바꾼 것만으로 설명되면 줄 전체 꼴이 붙지 않는다 — $name"
done
TB="$(j replblank 'd["text"]')"
assert_contains "$TB" "   더한 문장: 새 문단." "AC2: 문단을 통째로 바꾸면서 빈 줄을 따로 지운 덩어리도 바뀐 문장을 보인다"
assert_contains "$TB" "   문단 나눔 · 공백도 바뀜" "AC2: 문단을 통째로 바꾸면서 한쪽에서만 맞닿은 빈 줄을 지우면 그 사실 한 줄"
assert_contains "$TB" "   - 옛 문단." "AC2: 그 덩어리는 줄 전체 꼴이 함께 보인다(사라진 빈 줄이 드러난다)"
TG="$(j gap 'd["text"]')"
assert_contains "$TG" "   문단 나눔 · 공백도 바뀜" "AC2: 그대로인 문장 사이의 공백만 바뀐 것도 문장 변경과 함께면 그 사실 한 줄"
assert_contains "$TG" "   - 가.  나. 다." "AC2: 그 덩어리는 줄 전체 꼴(기준 쪽 — 공백 둘)이 함께 보인다"
TH="$(j gaphead 'd["text"]')"
assert_contains "$TH" "   문단 나눔 · 공백도 바뀜" "AC2: 줄 첫 문장을 바꾸면서 그 뒤 그대로인 문장 앞 공백을 바꾼 것도 그 사실 한 줄"
assert_contains "$TH" "   + Y.   가." "AC2: 그 덩어리는 줄 전체 꼴(지금 쪽 — 공백 셋)이 함께 보인다"
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
mk dup2 '가. 가. 나.\n\n다.\n' '나.\n\n다. 가.\n'; scr dup2
assert_eq "$(j dup2 '[h["removed_moved"] for h in d["hunks"]]')" "[[True, False], []]" "Review Focus: 더한 문장 하나는 뺀 문장 하나와만 짝이 된다 — 남은 같은 글자의 뺀 문장에는 「자리 옮김」 이 붙지 않는다"
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

# ── 원장 fixture — fix 셋(적용 · 처분 전 · 적용하지 않음) · decide 둘(채택 · 거부) · ask 하나(답함) ──
L="$TMP/L"; mkdir -p "$L/state"
printf -- '---\ntype: interview-seed\n---\n\n로그인이 가끔 실패한다.\n' > "$L/s.md"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$L/s.audit.md"
python3 "$S/docreview_state.py" init --state-dir "$L/state" --doc "$L/s.md" --profile "$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md" >/dev/null
python3 "$S/docreview_state.py" begin-round --state-dir "$L/state" >/dev/null
{ printf '```docreview-layer1\n'
  while read -r cat disp summ; do
    printf -- '- ref: c_%s\n  category: %s\n  anchor: "#__doc__"\n  disposition: %s\n  summary: "%s"\n' "$summ" "$cat" "$disp" "$summ"
  done <<'EOF'
premature_closure fix SCR_FIX_APPLY
premature_closure fix SCR_FIX_PENDING
omission fix SCR_FIX_DROP
inference_as_decision decide SCR_DEC_ADOPT
inference_as_decision decide SCR_DEC_REJECT
unfounded_addition ask SCR_ASK
EOF
  printf '```\n```docreview-layer2\n[]\n```\n'; } > "$L/critic.txt"
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$L/state" --critic "$L/critic.txt" > "$L/prep.json"
python3 "$S/docreview_route.py" finalize --state-dir "$L/state" --recritic-skipped --doc "$L/s.md" > "$L/fin.json"
idof() { python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")==sys.argv[2]][0])' "$L/fin.json" "$1"; }
FA="$(idof SCR_FIX_APPLY)"; FP="$(idof SCR_FIX_PENDING)"; FD="$(idof SCR_FIX_DROP)"; DA="$(idof SCR_DEC_ADOPT)"; DR="$(idof SCR_DEC_REJECT)"; AK="$(idof SCR_ASK)"
python3 "$S/docreview_anchor.py" check-intent "$FA" --intent '#__doc__' --state-dir "$L/state" >/dev/null
python3 "$S/docreview_state.py" fix --state-dir "$L/state" --id "$FD" --event drop --reason="적용하지 않음" --log-file "$L/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" decide --state-dir "$L/state" --id "$DA" --choice adopt --quote="채택" --log-file "$L/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" decide --state-dir "$L/state" --id "$DR" --choice reject --quote="기각" --log-file "$L/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" ask --state-dir "$L/state" --id "$AK" --answered >/dev/null
python3 - "$S" "$L/state" "$FA" "$FP" "$FD" "$DA" "$DR" "$AK" > "$L/pre.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
fa, fp, fd, da, dr, ak = sys.argv[3:9]
last = {i: e["choice"] for e in st["decision_log"] for i in e["finding_ids"]}
print(st["fixes"][fa]["state"], st["fixes"][fp]["state"], st["fixes"][fd]["state"], last[da], last[dr], st["asks"][ak]["answered"])
PY
assert_eq "$(cat "$L/pre.txt")" "intent_passed pending dropped adopt reject True" "전제: 원장 fixture — 적용한 fix · 처분 전 fix · 적용하지 않은 fix · 채택한 decide · 거부한 decide · 답한 ask"
mk2() {   # mk2 <이름> → 덩어리 둘인 화면 + 원장 사본
  mk "$1" '가.\n\n나.\n\n다.\n' '가 고침.\n\n나.\n\n다 고침.\n'
  cp -R "$L/state/." "$TMP/$1/state/"
}
ver() { python3 -c 'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["seed_sha256"])' "$TMP/$1/hunks.json"; }
why() {   # why <이름> <줄…> → 판본이 맞는 이유 파일. 줄은 printf %b 로 푼다(\t 가 탭)
  local n="$1" l; shift
  { printf 'seed_sha256 %s\n' "$(ver "$n")"; for l in "$@"; do printf '%b\n' "$l"; done; } > "$TMP/$n/state/hunk-reasons.txt"
}
rec() { j "$1" '[h["recommend"] for h in d["hunks"]]'; }
force() {   # force <상태 폴더> <지적 id> <칸> <값> — 엔진의 읽기 · 쓰기로 원장의 한 칸을 바꾼다(decides 의 state · kind, findings 의 summary)
  python3 - "$S" "$1" "$2" "$3" "$4" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
st["decides" if sys.argv[4] in ("state", "kind") else "findings"][sys.argv[3]][sys.argv[4]] = sys.argv[5].replace("\\n", "\n")
ds.save_state(sys.argv[2], st)
PY
}

# ── AC4 — 확인된 덩어리에만 권장 ────────────────────────────────────────────────
mk2 fixok; why fixok "1\t$FA"
before="$(sums "$TMP/fixok/state")"
scr fixok
assert_eq "$(sums "$TMP/fixok/state")" "$before" "AC8: 화면 조립은 원장 자리(원장 · 이유 파일)를 바꾸지 않는다"
assert_eq "$(rec fixok)" "[True, False]" "AC4: 사용자가 적용을 고른 fix 를 댄 덩어리만 권장이다(쓴 지적 목록 파일 없음 — 첫 화면)"
TF="$(j fixok 'd["text"]')"
assert_contains "$TF" "   고친 이유(저자가 댐): 지적 「SCR_FIX_APPLY」(${FA}) — 사용자가 「적용」 으로 처분" "AC4: 지적의 한 줄 요약 · id · 처분이 보인다"
assert_contains "$TF" "   고친 이유(저자가 댐): 대응하는 지적 없음 — 저자가 스스로 고침" "AC4: 이유 파일에 없는 덩어리는 대응하는 지적 없음"
assert_eq "$(j fixok 'd["text"].split("\n")[1]')" "(권장) 은 저자가 댄 지적을 사용자가 적용하기로 했다는 뜻입니다 — 편집이 그 지적에 맞는지는 아래 문장으로 직접 보세요" "AC4: 권장이 붙은 화면은 첫머리에 권장의 뜻 한 줄"
mk2 decok; why decok "2\t$DA"; scr decok
assert_eq "$(rec decok)" "[False, True]" "AC4: 사용자가 채택한 decide 를 댄 덩어리도 권장이다"
assert_contains "$(j decok 'd["text"]')" "   고친 이유(저자가 댐): 지적 「SCR_DEC_ADOPT」(${DA}) — 사용자가 채택" "AC4: 채택한 decide 의 이유 줄"
force "$TMP/decok/state" "$DA" state expired; scr decok
assert_eq "$(rec decok)" "[False, True]" "AC4: 결정 항목은 상태 칸이 아니라 고른 쪽으로 가른다(채택 뒤 상태가 expired 여도 권장)"
scr fixok --final
assert_eq "$(rec fixok)" "[False, False]" "AC4: 확정 직전 화면으로 조립하면 같은 입력에서도 권장이 없다"
assert_contains "$(j fixok 'd["text"]')" "지적 「SCR_FIX_APPLY」(${FA}) — 사용자가 「적용」 으로 처분" "AC4: 확정 직전 화면에도 고친 이유 줄은 그대로 보인다"
assert_not_contains "$(j fixok 'd["text"]')" "(권장)" "AC4: 확정 직전 화면 글에는 권장의 뜻 줄도 없다"

# ── AC5 — 권장이 붙지 않는 경우 ─────────────────────────────────────────────────
norec() {   # norec <이름> <라벨> <이유 줄…> — 그 이유로 조립하면 어느 덩어리에도 권장이 없다
  local n="$1" label="$2"; shift 2
  mk2 "$n"; why "$n" "$@"; scr "$n"
  assert_eq "$(rec "$n")" "[False, False]" "AC5: ${label}"
}
norec mixed "「없음」 이 섞인 덩어리" "1\t$FA,없음"
norec unknown "원장에 없는 id" "1\tdeadbeef#r9.9"
assert_contains "$(j unknown 'd["text"]')" "   고친 이유(저자가 댐): 저자가 댄 지적 deadbeef#r9.9 은 원장에서 확인되지 않는다" "AC5: 원장에서 확인되지 않은 id 가 화면에 보인다"
norec dropped "사용자가 적용하지 않기로 한 fix" "1\t$FD"
norec pending "처분 전인 fix" "1\t$FP"
norec partial "댄 지적 가운데 하나가 확인되지 않음" "1\t$FA,$FP"
norec ask "ask 의 답에 따른 편집" "1\t$AK"
assert_contains "$(j ask 'd["text"]')" "지적 「SCR_ASK」(${AK}) — 사용자가 답한 열린 질문" "AC5: ask 의 답에 따른 편집은 이유로만 보인다"
norec rejected "사용자가 거부한 decide" "1\t$DR"
for stt in adopted applied; do
  force "$TMP/rejected/state" "$DR" state "$stt"; scr rejected
  assert_eq "$(rec rejected)" "[False, False]" "AC5: 거부한 decide 는 원장 상태 칸이 ${stt} 여도 권장이 없다"
done
mk2 postkind; why postkind "1\t$DA"; scr postkind
assert_eq "$(rec postkind)" "[True, False]" "AC5 양의 짝: 채택한 decide 는 권장이다"
force "$TMP/postkind/state" "$DA" kind post; scr postkind
assert_eq "$(rec postkind)" "[False, False]" "AC5: 「현재 변경 유지」 로 채택한 항목(kind post)은 고치라는 처분이 아니라 권장이 없다"
mk2 used; why used "1\t$FA"; printf '%s\n' "$FA" > "$TMP/used/state/hunk-used-findings.txt"; scr used
assert_eq "$(rec used)" "[False, False]" "AC5: 쓴 지적 목록에 든 지적"
assert_contains "$(j used 'd["text"]')" "지적 「SCR_FIX_APPLY」(${FA}) — 앞 화면에서 이미 댄 지적" "AC5: 이미 쓴 지적이라는 사실이 화면에 보인다"
mk2 usedbad; why usedbad "1\t$FA"; printf '\377\376' > "$TMP/usedbad/state/hunk-used-findings.txt"; scr usedbad
assert_eq "$(rec usedbad)" "[False, False]" "AC5: 쓴 지적 목록 파일을 읽지 못한 경우(깨짐)"
assert_contains "$(j usedbad 'd["text"]')" "쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다" "AC5: 목록을 읽지 못한 사실이 화면에 보인다"
mk2 usedlink; why usedlink "1\t$FA"; ln -s "$TMP/usedlink/nowhere" "$TMP/usedlink/state/hunk-used-findings.txt"; scr usedlink
[ -L "$TMP/usedlink/state/hunk-used-findings.txt" ] && [ ! -e "$TMP/usedlink/state/hunk-used-findings.txt" ] && ok "전제: 쓴 지적 목록이 가리키는 곳 없는 링크다" || no "전제: 쓴 지적 목록이 가리키는 곳 없는 링크가 아니다"
assert_eq "$(rec usedlink)" "[False, False]" "AC5: 쓴 지적 목록이 가리키는 곳 없는 링크면 권장이 없다(빈 목록으로 읽지 않는다)"
assert_contains "$(j usedlink 'd["text"]')" "쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다" "AC5: 링크인 목록을 읽지 못한 사실이 화면에 보인다"

# ── AC6 — 이유 파일 · 원장이 없거나 어긋날 때 ────────────────────────────────────
mk2 noreason; scr noreason; rc=$?
assert_eq "$rc $(rec noreason)" "0 [False, False]" "AC6: 이유 파일이 없어도 화면이 나온다 — 전부 권장 없음"
mk noledger '가.\n\n나.\n\n다.\n' '가 고침.\n\n나.\n\n다 고침.\n'; why noledger "1\t$FA"; scr noledger; rc=$?
assert_eq "$rc $(rec noledger)" "0 [False, False]" "AC6: 원장이 없어도 화면이 나온다 — 전부 권장 없음"
assert_contains "$(j noledger 'd["text"]')" "리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다" "AC6: 원장을 읽지 못한 사실이 화면에 보인다"
mk2 badledger; why badledger "1\t$FA"; printf 'x' >> "$TMP/badledger/state/docreview-state.md"; scr badledger; rc=$?
assert_eq "$rc $(rec badledger)" "0 [False, False]" "AC6: 깨진 원장도 같다"
assert_contains "$(j badledger 'd["text"]')" "리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다" "AC6: 깨진 원장을 읽지 못한 사실이 보인다"
mk2 stale; printf 'seed_sha256 0000\n1\t%s\n' "$FA" > "$TMP/stale/state/hunk-reasons.txt"; scr stale
assert_eq "$(rec stale)" "[False, False]" "AC6: 이유 파일 첫 줄의 판본이 다르면 이유를 하나도 쓰지 않는다"
assert_contains "$(j stale 'd["text"]')" "이유 파일이 이 공시의 것이 아니다" "AC6: 판본이 다른 사실이 화면에 보인다"
assert_not_contains "$(j stale 'd["text"]')" "SCR_FIX_APPLY" "AC6: 판본이 다른 이유 파일의 지적은 화면에 실리지 않는다"
mk2 nohead; printf '1\t%s\n' "$FA" > "$TMP/nohead/state/hunk-reasons.txt"; scr nohead
assert_eq "$(rec nohead)" "[False, False]" "AC6: 이유 파일에 판본 줄이 없으면 이유를 하나도 쓰지 않는다"
assert_contains "$(j nohead 'd["text"]')" "이유 파일이 이 공시의 것이 아니다" "AC6: 판본 줄이 없는 사실이 화면에 보인다"
mk2 dupok; why dupok "1\t$FA" "1\t$DA"; scr dupok
assert_eq "$(rec dupok)" "[True, False]" "AC6: 같은 덩어리 번호가 여러 줄이면 지적을 합친다(둘 다 확인됨이면 권장)"
assert_contains "$(j dupok 'd["text"]')" "SCR_DEC_ADOPT" "AC6: 합친 지적이 모두 이유 줄에 보인다"
mk2 dupnone; why dupnone "1\t$FA" "1\t없음"; scr dupnone
assert_eq "$(rec dupnone)" "[False, False]" "AC6: 여러 줄 가운데 한 줄이라도 「없음」 이면 권장이 없다"
mk2 badlines; why badlines "1\t$FA" "9\t$FA" "엉뚱한 줄" "x\t$FA"; scr badlines
assert_eq "$(rec badlines)" "[True, False]" "AC6: 없는 덩어리 번호의 줄과 꼴이 아닌 줄은 버리고 나머지는 읽는다"
assert_contains "$(j badlines 'd["text"]')" "이유 파일에서 읽지 못한 줄 3개" "AC6: 버린 줄 수가 화면에 보인다"
mk2 crlf; printf 'seed_sha256 %s\r\n1\t%s\r\n2 %s\r\n' "$(ver crlf)" "$FA" "$DA" > "$TMP/crlf/state/hunk-reasons.txt"; scr crlf
assert_eq "$(rec crlf)" "[True, False]" "Review Focus: 줄 끝이 CRLF 여도 읽고, 탭 대신 공백을 쓴 줄은 버린다(권장 쪽으로 기울지 않는다)"
assert_contains "$(j crlf 'd["text"]')" "이유 파일에서 읽지 못한 줄 1개" "Review Focus: 탭이 없는 줄은 읽지 못한 줄로 센다"
mk2 longsum; why longsum "1\t$FA"; force "$TMP/longsum/state" "$FA" summary '첫 줄\n둘째 줄'; scr longsum
assert_contains "$(j longsum 'd["text"]')" "   고친 이유(저자가 댐): 지적 「첫 줄 둘째 줄」(${FA})" "Review Focus: 여러 줄 요약은 한 줄로 이어 화면 구조를 깨지 않는다"

# ── AC5 · AC6 — 읽지 못한 사실은 댄 지적이 없어도 늘 보인다 ─────────────────────────
mk noids '가.\n\n나.\n' '가 고침.\n\n나.\n'; scr noids
assert_contains "$(j noids 'd["text"]')" "리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다" "AC6: 이유 파일 없음 + 원장 없음 — 원장을 읽지 못한 사실이 화면 글에 보인다"
assert_contains "$(j noids 'd["notices"]')" "리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다" "AC6: 같은 사실이 알림 목록에도 있다"
mk2 usedbad2; printf '\377\376' > "$TMP/usedbad2/state/hunk-used-findings.txt"; scr usedbad2
assert_contains "$(j usedbad2 'd["text"]')" "쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다" "AC5: 이유 파일 없음 + 쓴 지적 목록 깨짐 — 읽지 못한 사실이 화면 글에 보인다"
assert_contains "$(j usedbad2 'd["notices"]')" "쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다" "AC5: 같은 사실이 알림 목록에도 있다"

# ── 이유는 한 줄로 잇고, 화면 글은 조각마다 한 줄 ──────────────────────────────────
rlines() { j "$1" 'len([x for x in d["text"].split("\n") if x.startswith("   고친 이유(저자가 댐): ")])'; }
mk2 twofind; why twofind "1\t$FA,$DA" "2\t$FA,없음"; scr twofind
assert_eq "$(j twofind 'd["hunks"][0]["reason"]')" "지적 「SCR_FIX_APPLY」(${FA}) — 사용자가 「적용」 으로 처분 · 지적 「SCR_DEC_ADOPT」(${DA}) — 사용자가 채택" "reason: 지적 둘을 댄 덩어리의 reason 은 줄바꿈 없이 ' · ' 로 이은 한 줄이다"
assert_eq "$(j twofind 'd["hunks"][1]["reason"]')" "지적 「SCR_FIX_APPLY」(${FA}) — 사용자가 「적용」 으로 처분 · 대응하는 지적 없음 — 저자가 스스로 고침" "reason: 지적 + 「없음」 도 줄바꿈 없이 ' · ' 로 이은 한 줄이다"
assert_eq "$(rlines twofind)" "4" "reason: 화면 글에는 조각마다 이유 줄이 하나씩 있다(둘 + 둘)"
mk2 dotsum; why dotsum "1\t$FA"; force "$TMP/dotsum/state" "$FA" summary '앞 · 뒤'; scr dotsum
assert_eq "$(rlines dotsum)" "2" "reason: 요약 글에 ' · ' 가 들어 있어도 이유 줄을 더 쪼개지 않는다(지적 조각 하나 + 다음 덩어리의 지적 없음 하나)"
assert_contains "$(j dotsum 'd["text"]')" "   고친 이유(저자가 댐): 지적 「앞 · 뒤」(${FA}) — 사용자가 「적용」 으로 처분" "reason: 요약 글의 ' · ' 는 한 줄 안에 그대로 있다"

# ── 재결정한 decide — 그 지적의 «마지막» 선택으로 가른다 ─────────────────────────────
choices() {   # choices <상태 폴더> <지적 id> → 그 지적을 낸 decision_log 항목의 choice 들
  python3 - "$S" "$1" "$2" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
print([e["choice"] for e in st["decision_log"] if sys.argv[3] in e["finding_ids"]], [bool(e.get("supersedes")) for e in st["decision_log"] if sys.argv[3] in e["finding_ids"]])
PY
}
redecide() {   # redecide <이름> <지적 id> <고른 쪽> — 그 지적을 다시 열고(상태 open) 엔진으로 다시 결정한다
  force "$TMP/$1/state" "$2" state open
  cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$TMP/$1/audit.md"
  python3 "$S/docreview_state.py" decide --state-dir "$TMP/$1/state" --id "$2" --choice "$3" --quote="다시 결정" --log-file "$TMP/$1/audit.md" >/dev/null
}
mk2 redecA; why redecA "1\t$DA"; redecide redecA "$DA" reject
assert_eq "$(choices "$TMP/redecA/state" "$DA")" "['adopt', 'reject'] [False, True]" "전제: 재결정 fixture — 채택한 뒤 거부한 decide 는 항목 둘이고 뒤가 앞을 잇는다"
scr redecA
assert_eq "$(rec redecA)" "[False, False]" "재결정: 채택한 뒤 거부한 decide 를 댄 덩어리는 권장이 없다(마지막 선택이 거부)"
assert_contains "$(j redecA 'd["text"]')" "저자가 댄 지적 ${DA} 은 원장에서 확인되지 않는다" "재결정: 그 지적은 원장에서 확인되지 않는다고 보인다"
mk2 redecB; why redecB "2\t$DR"; redecide redecB "$DR" adopt
assert_eq "$(choices "$TMP/redecB/state" "$DR")" "['reject', 'adopt'] [False, True]" "전제: 재결정 fixture — 거부한 뒤 채택한 decide 는 항목 둘이고 뒤가 앞을 잇는다"
scr redecB
assert_eq "$(rec redecB)" "[False, True]" "재결정: 거부한 뒤 채택한 decide 를 댄 덩어리는 권장이다(마지막 선택이 채택)"
# ── 채택 → 만료 → 다시 올라온 후속 — 그 계보의 «마지막» 결정이 채택이고 그 결정이 댄 id 를 낼 때만 ──────
# 원장은 엔진으로 만든다: 라운드 1 채택 → 라운드 2 편집 없음(만료) → 후속 항목이 같은 계보로 다시 올라온다.
LS="$TMP/LS"; mkdir -p "$LS/state"
printf -- '---\ntype: interview-seed\n---\n\n로그인이 가끔 실패한다.\n' > "$LS/s.md"
cp "$ROOT/plugins/spec-distill/templates/interview-seed-audit-template.md" "$LS/s.audit.md"
python3 "$S/docreview_state.py" init --state-dir "$LS/state" --doc "$LS/s.md" --profile "$ROOT/plugins/spec-distill/references/docreview-profiles/seed.md" >/dev/null
python3 "$S/docreview_state.py" begin-round --state-dir "$LS/state" >/dev/null
printf '```docreview-layer1\n- ref: c1\n  category: inference_as_decision\n  anchor: "#__doc__"\n  disposition: decide\n  summary: "SCR_DEC_LINEAGE"\n```\n```docreview-layer2\n[]\n```\n' > "$LS/state/critic.txt"
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$LS/state" --critic "$LS/state/critic.txt" > "$LS/prep1.json"
python3 "$S/docreview_route.py" finalize --state-dir "$LS/state" --recritic-skipped --doc "$LS/s.md" > "$LS/fin1.json"
SA="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("summary")=="SCR_DEC_LINEAGE"][0])' "$LS/fin1.json")"
python3 "$S/docreview_state.py" decide --state-dir "$LS/state" --id "$SA" --choice adopt --quote="채택" --log-file "$LS/s.audit.md" >/dev/null
python3 "$S/docreview_state.py" begin-round --state-dir "$LS/state" >/dev/null
python3 "$S/docreview_state.py" observe-diff --state-dir "$LS/state" > "$LS/obs2.json"
printf '```docreview-layer1\n[]\n```\n```docreview-layer2\n[]\n```\n' > "$LS/state/critic.txt"
python3 "$S/docreview_route.py" prepare-recritic --state-dir "$LS/state" --critic "$LS/state/critic.txt" > "$LS/prep2.json"
python3 "$S/docreview_route.py" finalize --state-dir "$LS/state" --recritic-skipped --doc "$LS/s.md" > "$LS/fin2.json"
SB="$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print([f["id"] for f in d["findings"] if f.get("lineage")==sys.argv[2]][0])' "$LS/fin2.json" "$SA")"
cp -R "$LS/state" "$LS/state-open"
python3 "$S/docreview_state.py" decide --state-dir "$LS/state" --id "$SB" --choice reject --quote="거부" --log-file "$LS/s.audit.md" >/dev/null
lineage_log() {   # lineage_log <상태 폴더> → (후속이 원래 id 와 다르고 계보가 같은가, 결정 기록의 (낸 id, 고른 쪽) 열)
  python3 - "$S" "$1" "$SA" "$SB" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import docreview_state as ds
st = ds.load_state(sys.argv[2])
a, b = sys.argv[3], sys.argv[4]
print(a != b and st["findings"][b]["lineage"] == st["findings"][a]["lineage"],
      [(["A" if i == a else "B" if i == b else i for i in e["finding_ids"]], e["choice"]) for e in st["decision_log"]])
PY
}
assert_eq "$(lineage_log "$LS/state")" "True [(['A'], 'adopt'), (['B'], 'reject')]" "전제: 계보 fixture — 채택한 지적이 만료돼 같은 계보의 후속으로 다시 올라왔고, 사용자가 그 후속을 거부했다"
mklin() {   # mklin <이름> <상태 폴더> → 덩어리 둘인 화면 + 그 원장 사본
  mk "$1" '가.\n\n나.\n\n다.\n' '가 고침.\n\n나.\n\n다 고침.\n'
  cp -R "$2/." "$TMP/$1/state/"
}
mklin linopen "$LS/state-open"; why linopen "1\t$SA"; scr linopen
assert_eq "$(rec linopen)" "[True, False]" "계보 양의 짝: 만료된 채택의 후속에 아직 결정이 없으면 원래 id 를 댄 덩어리는 권장이다(계보의 마지막 결정이 그 id 의 채택)"
mklin linrej "$LS/state"; why linrej "1\t$SA"; scr linrej
assert_eq "$(rec linrej)" "[False, False]" "계보: 채택 → 만료 → 다시 올라온 후속을 사용자가 거부하면 원래 id 를 대도 권장이 없다"
assert_contains "$(j linrej 'd["text"]')" "저자가 댄 지적 ${SA} 은 원장에서 확인되지 않는다" "계보: 그 원래 id 는 원장에서 확인되지 않는다고 보인다"
assert_not_contains "$(j linrej 'd["text"]')" "사용자가 채택" "계보: 거부된 계보의 원래 id 에 「사용자가 채택」 을 붙이지 않는다"
cp -R "$LS/state-open" "$LS/state-adoptB"
python3 "$S/docreview_state.py" decide --state-dir "$LS/state-adoptB" --id "$SB" --choice adopt --quote="다시 채택" --log-file "$LS/s.audit.md" >/dev/null
assert_eq "$(lineage_log "$LS/state-adoptB")" "True [(['A'], 'adopt'), (['B'], 'adopt')]" "전제: 계보 fixture — 다시 올라온 후속을 사용자가 채택했다"
mklin linadA "$LS/state-adoptB"; why linadA "1\t$SA" "2\t$SB"; scr linadA
assert_eq "$(rec linadA)" "[False, True]" "계보: 계보의 마지막 채택이 후속을 내면 후속 id 를 댄 덩어리만 권장이다 — 원래 id 는 그 결정이 내지 않는다"
# ── AC7 — 질문 묶음 ─────────────────────────────────────────────────────────
mkn() {   # mkn <이름> <n> → 덩어리 n 개(문단마다 하나) + 원장 사본
  mkdir -p "$TMP/$1/state"
  python3 -c 'import sys
n = int(sys.argv[3])
open(sys.argv[1], "w", encoding="utf-8").write("".join("문단 %d.\n\n" % i for i in range(1, n + 1)))
open(sys.argv[2], "w", encoding="utf-8").write("".join("문단 %d 고침.\n\n" % i for i in range(1, n + 1)))' "$TMP/$1/base.md" "$TMP/$1/seed.md" "$2"
  python3 "$S/seed_edit_diff.py" hunks "$TMP/$1/base.md" "$TMP/$1/seed.md" > "$TMP/$1/hunks.json"
  cp -R "$L/state/." "$TMP/$1/state/"
}
qs() { j "$1" '[(q["multi"], q["hunk_ids"]) for q in d["questions"]]'; }
mkn q1 1; scr q1
assert_eq "$(j q1 '[(q["multi"], q["question"], [o["label"] for o in q["options"]]) for q in d["questions"]]')" \
  "[(False, '저자 편집 1곳을 그대로 둘까요?', ['그대로 둔다', '되돌린다'])]" "AC7: 덩어리 하나면 단일 선택이다"
SUM1='뺀 문장 1개 · 더한 문장 1개 · 그대로 0문장'
KEEP_GIVE='내줌: 틀린 편집도 남는다'
REVERT='얻음: 기준 사본의 글로 돌아간다 · 내줌: 편집이 고친 것도 사라진다 — 지적을 고친 편집이면 그 지적은 안 고친 채 남는다'
assert_eq "$(j q1 '[o["description"] for o in d["questions"][0]["options"]]')" \
  "['얻음: 편집이 남는다(${SUM1} · 고친 이유(저자가 댐): 대응하는 지적 없음 — 저자가 스스로 고침) · ${KEEP_GIVE}', '${REVERT}']" \
  "설명: 권장 없는 하나 고르기 — 이유 줄이 「대응하는 지적 없음」 이면 그대로 다 싣는다(기준 길이 안)"
why q1 "1\t$FA"; scr q1
assert_eq "$(j q1 '[o["label"] for o in d["questions"][0]["options"]]')" "['그대로 둔다 (권장)', '되돌린다']" "AC7: 확인된 덩어리 하나면 「그대로 둔다 (권장)」 이 첫 자리다"
assert_eq "$(j q1 'd["questions"][0]["options"][0]["description"]')" \
  "얻음: 편집이 남는다(${SUM1} · 고친 이유(저자가 댐): 지적 「SCR_FIX_APPLY」(${FA}) …) · ${KEEP_GIVE}" \
  "설명: 「그대로 둔다」 는 얻음에 덩어리 요약(그대로)과 고친 이유(권장의 근거 — 넘치는 끝은 「…」)를 싣고 내줌 한 구절을 단다"
assert_eq "$(j q1 'd["questions"][0]["options"][1]["description"]')" "$REVERT" \
  "설명: 「되돌린다」 는 얻음 · 내줌 한 줄이다 — 내줌은 라운드 사이 · 확정 직전 두 화면에서 모두 참이다"
assert_eq "$(j q1 '[len(o["description"]) <= 110 for o in d["questions"][0]["options"]]')" "[True, True]" \
  "설명: 기본 기준 길이(110자) 안이다"
cp -R "$TMP/q1" "$TMP/q1w"
DEVBREW_DOCREVIEW_ASK_WIDTH=100 scr q1w
assert_eq "$(j q1w 'len(d["questions"][0]["options"][0]["description"])')" "100" \
  "설명: 기준 길이는 엔진과 같은 환경 값(DEVBREW_DOCREVIEW_ASK_WIDTH)에서 읽는다 — 100 이면 이유 줄을 100자에 맞춰 줄인다"
DEVBREW_DOCREVIEW_ASK_WIDTH=abc scr q1w 2>"$TMP/q1w.err"; rc=$?
assert_eq "$rc $(grep -c 'DEVBREW_DOCREVIEW_ASK_WIDTH' "$TMP/q1w.err")" "2 1" "설명: 기준 길이 환경 값이 잘못되면 rc 2 와 사유 한 줄(공시 펜스는 줄 전체 꼴 · 권장 없음으로 떨어진다)"
cp -R "$TMP/q1" "$TMP/q1long"
force "$TMP/q1long/state" "$FA" summary "$(python3 -c 'print("긴" * 137)')"
scr q1long
assert_eq "$(j q1long '(len(d["questions"][0]["options"][0]["description"]) <= 110, d["questions"][0]["options"][0]["description"].endswith("…) · " + "내줌: 틀린 편집도 남는다"), d["hunks"][0]["recommend"])')" \
  "(True, True, True)" "설명: 지적 요약이 137자여도 설명은 기준 길이 안이고 이유 줄의 끝만 「…」 로 잘린다(권장은 그대로)"
assert_contains "$(j q1long 'd["text"]')" "$(python3 -c 'print("긴" * 137)')" "설명: 잘린 이유 줄의 전문은 화면 글에 그대로 있다"
mkn q1x 1; why q1x '1\tx) · 내줌: 없음 · (y'; scr q1x
assert_eq "$(j q1x 'd["questions"][0]["options"][0]["description"]')" \
  "얻음: 편집이 남는다(${SUM1} · 고친 이유(저자가 댐): 저자가 댄 지적 x) · 내줌 : 없음 · (y 은 원장에서 …) · ${KEEP_GIVE}" \
  "설명: 원장에 없는 지적 id 가 표지 글자(내줌:)를 담아도 설명의 「 · 내줌: 」 은 하나다 — 이유 줄은 「원장에서 확인되지 않는다」"
assert_eq "$(j q1x '(d["questions"][0]["options"][0]["description"].startswith("얻음: "), d["questions"][0]["options"][0]["description"].count(" · 내줌: "), d["questions"][0]["options"][0]["description"].count("얻음:"))')" \
  "(True, 1, 1)" "설명: 어떤 이유 글이 와도 머리 「얻음: 」 하나 · 「 · 내줌: 」 하나다"
mkn q2 2; scr q2
assert_eq "$(qs q2)" "[(True, [1, 2])]" "AC7: 덩어리 둘이면 여러 개 고르기 질문 하나에 둘 다 든다"
mkn q3 3; scr q3
assert_eq "$(qs q3)" "[(True, [1, 2, 3])]" "AC7: 덩어리 셋이면 여러 개 고르기 질문 하나에 셋 다 든다"
mkn q4 4; scr q4
assert_eq "$(qs q4)" "[(True, [1, 2, 3, 4])]" "AC7: 덩어리 넷이면 질문 하나"
assert_eq "$(j q4 '(d["questions"][0]["question"], [o["label"] for o in d["questions"][0]["options"]])')" \
  "('그대로 둘 곳을 고르세요. 고르지 않은 곳은 되돌립니다. 전부 되돌리려면 기타 칸에 적어 주세요.', ['1번 그대로 둔다', '2번 그대로 둔다', '3번 그대로 둔다', '4번 그대로 둔다'])" "AC7: 여러 개 고르기 질문의 글과 선택지 — 선택지는 덩어리뿐이다"
mkn q5 5; scr q5
assert_eq "$(qs q5)" "[(True, [1, 2, 3]), (True, [4, 5])]" "AC7: 다섯이면 3+2"
mkn q9 9; scr q9
assert_eq "$(qs q9)" "[(True, [1, 2, 3, 4]), (True, [5, 6, 7]), (True, [8, 9])]" "AC7: 아홉이면 4+3+2"
assert_eq "$(shown q9)" "ok" "AC1 · AC2 화면 글: 덩어리 아홉이 모두 실린다 — q9"
why q5 "3\t$FA" "5\t$DA"; scr q5
assert_eq "$(j q5 '[[o["label"] for o in q["options"]] for q in d["questions"]]')" \
  "[['3번 그대로 둔다 (권장)', '1번 그대로 둔다', '2번 그대로 둔다'], ['5번 그대로 둔다 (권장)', '4번 그대로 둔다']]" "AC7: 번호 순으로 나눈 뒤 질문 안에서만 권장을 앞에 둔다"
assert_eq "$(qs q5)" "[(True, [1, 2, 3]), (True, [4, 5])]" "AC7: 권장이 있어도 한 질문의 덩어리 번호는 이어져 있다"
assert_eq "$(j q5 '[o["description"] for o in d["questions"][1]["options"]][0]')" \
  "얻음: 편집이 남는다(${SUM1} · 고친 이유(저자가 댐): 지적 「SCR_DEC_ADOPT」(${DA}) …) · ${KEEP_GIVE}" \
  "설명: 여러 개 고르기의 선택지도 얻음에 덩어리 요약과 고친 이유를 싣는다"
assert_eq "$(j q5 'max(len(o["description"]) for q in d["questions"] for o in q["options"])') $(j q9 'max(len(o["description"]) for q in d["questions"] for o in q["options"])')" \
  "110 98" "설명: 여러 개 고르기 선택지(넷까지)마다 기준 길이 안이다 — 권장 있는 q5 · 권장 없는 q9"
form_bad() {   # form_bad <이름> → 「얻음:」 으로 시작하고 「 · 내줌: 」 이 한 번인 꼴이 아닌 설명 수
  j "$1" 'sum(1 for q in d["questions"] for o in q["options"] if not (o["description"].startswith("얻음: ") and o["description"].count(" · 내줌: ") == 1))'
}
assert_eq "$(form_bad q5) $(form_bad q9) $(form_bad q1)" "0 0 0" "설명: 권장이 있든 없든 모든 선택지 설명이 「얻음: … · 내줌: …」 꼴이다(q5 · q9 · q1)"
cp -R "$TMP/q5" "$TMP/q5f"; scr q5f --final
assert_eq "$(form_bad q5f) $(j q5f 'any(h["recommend"] for h in d["hunks"])')" "0 False" "설명: 확정 직전 화면(권장 없음)도 같은 꼴이다"
python3 - "$S" > "$TMP/sizes.txt" <<'PY'
import sys
sys.path.insert(0, sys.argv[1])
import seed_edit_screen as m
bad = [n for n in range(2, 41) if sum(m.split_sizes(n)) != n or not all(2 <= s <= 4 for s in m.split_sizes(n))]
print(m.split_sizes(1), m.split_sizes(13), bad)
PY
assert_eq "$(cat "$TMP/sizes.txt")" "[1] [4, 4, 3, 2] []" "Review Focus: 덩어리가 많아도(2–40) 나뉜 질문마다 둘에서 넷이고 합이 맞는다"

# ── AC10 — 쓴 지적 목록에 더하기 ─────────────────────────────────────────────────
mu() {   # mu <이름> <ids> [덩어리 JSON 파일 이름] → rc. stdout 은 $TMP/<이름>/mu.out, stderr 는 $TMP/<이름>/mu.err
  python3 "$X" mark-used --hunks "$TMP/$1/${3:-hunks.json}" --reasons "$TMP/$1/state/hunk-reasons.txt" --state-dir "$TMP/$1/state" --ids "$2" >"$TMP/$1/mu.out" 2>"$TMP/$1/mu.err"
}
U="hunk-used-findings.txt"
mk2 mu1; why mu1 "1\t$FA,$DA" "2\t$FA,없음"
mu mu1 "1,2"; rc=$?
assert_eq "$rc" "0" "AC10: 목록에 더하기 rc 0"
assert_eq "$(cat "$TMP/mu1/state/$U")" "$(printf '%s\n%s' "$FA" "$DA")" "AC10: 그 화면의 이유 파일이 댄 지적 id 를 모두 더한다(같은 id 는 한 번)"
assert_eq "$(cat "$TMP/mu1/mu.out")" "{\"added\": [\"${FA}\", \"${DA}\"], \"skipped\": null}" "AC10: 더한 id 를 stdout JSON 으로 알린다"
mu mu1 "1,2"
assert_eq "$(cat "$TMP/mu1/state/$U")" "$(printf '%s\n%s' "$FA" "$DA")" "AC10: 다시 돌려도 이미 있는 id 를 두 번 적지 않는다"
assert_eq "$(cat "$TMP/mu1/mu.out")" '{"added": [], "skipped": null}' "AC10: 이미 있는 id 뿐이면 stdout JSON 의 added 가 비었다"
scr mu1
assert_eq "$(rec mu1)" "[False, False]" "AC10: 더한 뒤 다시 공시한 화면에서는 그 지적에 권장이 붙지 않는다"
mk2 mu2; mu mu2 "1,2"; rc=$?
[ "$rc" = 0 ] && [ ! -e "$TMP/mu2/state/$U" ] && ok "AC10: 이유 파일이 없으면 아무것도 더하지 않고 성공한다" || no "AC10: 이유 파일이 없는데 rc ${rc} 이거나 목록이 생겼다"
assert_eq "$(cat "$TMP/mu2/mu.out")" '{"added": [], "skipped": "no_reasons"}' "AC10: 이유 파일이 없어 건너뛴 사실을 stdout JSON 으로 알린다"
mk2 mu3; printf 'seed_sha256 0000\n1\t%s\n' "$FA" > "$TMP/mu3/state/hunk-reasons.txt"; mu mu3 "1,2"; rc=$?
[ "$rc" = 0 ] && [ ! -e "$TMP/mu3/state/$U" ] && ok "AC10: 판본이 다른 이유 파일이면 아무것도 더하지 않고 성공한다" || no "AC10: 판본이 다른데 rc ${rc} 이거나 목록이 생겼다"
assert_eq "$(cat "$TMP/mu3/mu.out")" '{"added": [], "skipped": "stale_reasons"}' "AC10: 판본이 다른 이유 파일이라 건너뛴 사실을 stdout JSON 으로 알린다"
mk2 mu4; why mu4 "1\t$FA"
for ids in "1" "1,2,3" "1,1,2" ""; do
  mu mu4 "$ids"; rc=$?
  [ "$rc" = 2 ] && [ ! -e "$TMP/mu4/state/$U" ] && ok "AC10: 번호가 덩어리 전부와 같지 않으면(${ids:-빈 값}) 쓰지 않고 rc 2" || no "AC10: 번호 「${ids}」 에 rc ${rc} 이거나 목록이 생겼다"
done
assert_contains "$(cat "$TMP/mu4/mu.err")" "처분 목록의 번호가 이 화면의 덩어리와 다르다" "AC10: 번호가 다른 사유를 알린다"
mk2 mu5; why mu5 "1\t$FA"
printf '가 고침.\n\n나.\n\n다 또 고침.\n' > "$TMP/mu5/seed2.md"
python3 "$S/seed_edit_diff.py" hunks "$TMP/mu5/base.md" "$TMP/mu5/seed2.md" > "$TMP/mu5/hunks-final.json"
mu mu5 "1,2" hunks-final.json; rc=$?
[ "$rc" = 0 ] && [ ! -e "$TMP/mu5/state/$U" ] && ok "AC10: 넘겨받은 덩어리 JSON 의 판본과 견준다(다른 화면의 JSON 이면 더하지 않는다)" || no "AC10: 다른 판본의 JSON 인데 rc ${rc} 이거나 목록이 생겼다"
mu mu5 "1,2"
assert_eq "$(cat "$TMP/mu5/state/$U" 2>/dev/null)" "$FA" "AC10 양의 짝: 그 화면의 JSON 이면 더한다"
mk2 mu6; why mu6 "1\t$FA"; printf '\377\376' > "$TMP/mu6/state/$U"; cp "$TMP/mu6/state/$U" "$TMP/mu6/used.before"
mu mu6 "1,2"; rc=$?
assert_eq "$rc $(cmp -s "$TMP/mu6/state/$U" "$TMP/mu6/used.before" && echo same)" "2 same" "AC10: 목록을 읽지 못하면 더하지 않고 rc 2 — 파일은 그대로다"
mk2 mu7; why mu7 "1\t$FA"; printf '앞 지적 가\n앞 지적 나\n' > "$TMP/mu7/state/$U"
mu mu7 "1,2"; rc=$?
assert_eq "$rc $(cat "$TMP/mu7/state/$U")" "$(printf '0 앞 지적 가\n앞 지적 나\n%s' "$FA")" "AC10: 이미 든 목록의 끝에 더한다 — 앞의 줄은 순서 그대로 남고 새 id 가 그 뒤에 온다"

finish
