#!/usr/bin/env bash
# begin-round 가 원장에 적힌 문서에서 라운드 스냅숏을 직접 만든다 (AC25).
#   · 엔진 스냅숏 = 같은 문서의 `docreview_anchor.py snapshot` 에서 원장에 싣는 칸 (울타리 절 line_hashes · 불변 절 item_marks)
#   · 헤딩 없는 seed · 스냅숏 인자 거부 · 문서를 못 읽으면 원장 불변 · begin-round 뒤 편집은 다음 라운드 diff
#   · 불변 절의 「새 항목만 추가」 판정 · 호출자 문면에 스냅숏 인자가 남지 않음
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SD="$ROOT/plugins/spec-distill"
DS="$SD/scripts/docreview_state.py"
ANCHOR="$SD/scripts/docreview_anchor.py"
T="$(mktemp -d -t sd-begin-round-snap-XXXXXX)" || exit 1
T="$(cd "$T" && pwd -P)" || exit 1
trap 'rm -rf "$T"' EXIT
OLD_FLAG="--snap""shot"

# 불변 절(원칙)과 결정 기록 · 미룸 절을 가진 프로필 — 설계문서 프로필에 불변 패턴 하나만 더한다
PROF="$T/profile.md"
sed 's/^immutable: \[\]$/immutable: ["^원칙$"]/' "$SD/references/docreview-profiles/design-doc.md" > "$PROF"
SEED_PROF="$SD/references/docreview-profiles/seed.md"

write_doc() {   # write_doc <경로> <원칙 끝에 더할 줄(빈 값이면 없음)> <배경 본문>
  {
    printf -- '---\ntitle: 표본\n---\n# 설계\n\n## 원칙\n\n원칙 묶음:\n- P1 하나\n- P2 둘\n'
    [ -n "$2" ] && printf '%s\n' "$2"
    printf '\n## 배경\n\n%s\n\n## 결정 기록\n\n- D1 첫 결정\n메모 줄\n\n### Deferred to plan\n\n- 미룸 하나\n' "$3"
  } > "$1"
}

new_ledger() {   # new_ledger <폴더> <문서> <프로필>
  mkdir -p "$1"
  python3 "$DS" init --state-dir "$1" --doc "$2" --profile "$3" >/dev/null
}

begin() {   # begin <폴더> [인자…] → BR_RC · BR_ERR
  local d="$1"; shift
  BR_ERR="$(python3 "$DS" begin-round --state-dir "$d" "$@" 2>&1 >/dev/null)"; BR_RC=$?
}

ledger_snap() {   # ledger_snap <폴더> <라운드> → 정렬한 JSON
  python3 - "$SD/scripts" "$1" "$2" <<'PY'   # 원장 판독에 pyyaml(사용자 site) — -I 를 쓰지 않는다
import json, sys
sys.path.insert(0, sys.argv[1])
import docreview_state as S
st = S.load_state(sys.argv[2])
print(json.dumps((st.get("snapshots") or {}).get(sys.argv[3]), ensure_ascii=False, sort_keys=True))
PY
}

expected_snap() {   # expected_snap <문서> <울타리 앵커,…> <불변 앵커,…> → 앵커 스냅숏에서 원장에 싣는 칸만
  python3 "$ANCHOR" snapshot "$1" | python3 -I -c '
import json, sys
fence = set(filter(None, sys.argv[1].split(",")))
imm = set(filter(None, sys.argv[2].split(",")))
snap = json.load(sys.stdin)
secs = []
for s in snap["sections"]:
    row = {k: s.get(k) for k in ("anchor", "title", "level", "hash", "parents")}
    if s["anchor"] in fence:
        row["line_hashes"] = s["line_hashes"]
        if s["anchor"] in imm:
            row["item_marks"] = s["item_marks"]
    secs.append(row)
print(json.dumps({"headingless": bool(snap.get("headingless")), "sections": secs}, ensure_ascii=False, sort_keys=True))
' "$2" "$3"
}

round_diff() {   # round_diff <폴더> <라운드> → {"changed": [앵커…], "exempt": {앵커: 범위}}
  python3 - "$SD/scripts" "$1" "$2" <<'PY'   # 원장 판독에 pyyaml(사용자 site) — -I 를 쓰지 않는다
import json, sys
sys.path.insert(0, sys.argv[1])
import docreview_state as S
st = S.load_state(sys.argv[2])
prof = S.load_profile(st["profile"])
d = S.round_diff(st, prof, int(sys.argv[3]))
print(json.dumps({"changed": sorted(x["anchor"] for x in d["changed"]),
                  "exempt": {x["anchor"]: x.get("scope") for x in d["exempt_applied"]}}, ensure_ascii=False, sort_keys=True))
PY
}

FENCE="#원칙,#결정-기록,#deferred-to-plan"
IMM="#원칙"

note "== test_engine_snapshot_equals_anchor_snapshot"
D1="$T/eq"; DOC1="$T/eq.md"
write_doc "$DOC1" "" "본문."
new_ledger "$D1" "$DOC1" "$PROF"
begin "$D1"
assert_eq "$BR_RC" "0" "begin-round 는 스냅숏 인자 없이 rc 0"
exp="$(expected_snap "$DOC1" "$FENCE" "$IMM")"
got="$(ledger_snap "$D1" 1)"
assert_eq "$got" "$exp" "원장의 라운드 1 스냅숏 == 앵커 스냅숏에서 원장에 싣는 칸"
marks="$(python3 "$ANCHOR" snapshot "$DOC1" | python3 -I -c 'import json,sys;print(next(s["item_marks"] for s in json.load(sys.stdin)["sections"] if s["anchor"]=="#원칙"))')"
case "$marks" in *0*1*|*1*0*) ok "불변 절 item_marks 가 0 과 1 을 둘 다 갖는다 ($marks) — 비교가 공허하지 않다" ;;
  *) no "불변 절 item_marks 가 한쪽 값뿐이다 ($marks)" ;; esac
assert_contains "$got" '"item_marks"' "원장 스냅숏에 item_marks 칸이 있다"
assert_contains "$got" '"line_hashes"' "원장 스냅숏에 line_hashes 칸이 있다"
n_lh="$(printf '%s' "$got" | python3 -I -c 'import json,sys;print(sum("line_hashes" in s for s in json.load(sys.stdin)["sections"]))')"
assert_eq "$n_lh" "3" "line_hashes 는 울타리 절 셋에만"

note "== test_seed_headingless"
D2="$T/seed"; DOC2="$T/seed.md"
printf 'alpha 첫 줄\nbeta 둘째 줄\n' > "$DOC2"
new_ledger "$D2" "$DOC2" "$SEED_PROF"
begin "$D2"
assert_eq "$BR_RC" "0" "헤딩 없는 seed 도 rc 0"
got="$(ledger_snap "$D2" 1)"
assert_eq "$got" "$(expected_snap "$DOC2" "" "")" "seed 스냅숏 == 앵커 스냅숏(머리 없음 표지 포함)"
shape="$(printf '%s' "$got" | python3 -I -c 'import json,sys;s=json.load(sys.stdin);print(s["headingless"], [x["anchor"] for x in s["sections"]])')"
assert_eq "$shape" "True ['#__doc__']" "머리 없음 표지와 문서 전체 절 하나"

note "== test_snapshot_flag_is_refused"
D3="$T/flag"; DOC3="$T/flag.md"
write_doc "$DOC3" "" "본문."
new_ledger "$D3" "$DOC3" "$PROF"
python3 "$ANCHOR" snapshot "$DOC3" > "$T/flag.json"
cp "$D3/docreview-state.md" "$T/flag.before"
begin "$D3" "$OLD_FLAG" "$T/flag.json"
assert_eq "$BR_RC" "2" "스냅숏 인자는 rc 2"
assert_contains "$BR_ERR" "unrecognized arguments: $OLD_FLAG" "argparse 의 모르는 인자"
if cmp -s "$D3/docreview-state.md" "$T/flag.before"; then ok "거부된 호출은 원장을 바꾸지 않는다(round 그대로)"; else no "거부된 호출이 원장을 바꿨다"; fi
begin "$D3"
assert_eq "$BR_RC" "0" "양의 짝: 같은 원장에서 인자 없이 rc 0"

note "== test_begin_round_doc_missing_keeps_ledger"
for kind in missing link not_utf8; do
  D4="$T/miss-$kind"; DOC4="$T/miss-$kind.md"
  write_doc "$DOC4" "" "본문."
  new_ledger "$D4" "$DOC4" "$PROF"
  begin "$D4"   # 라운드 1 은 정상 — 원장에 쓸 것이 있다
  cp "$D4/docreview-state.md" "$T/miss-$kind.before"
  case "$kind" in
    missing) rm -f "$DOC4" ;;
    link) mv "$DOC4" "$T/miss-$kind.real.md"; ln -s "$T/miss-$kind.real.md" "$DOC4" ;;
    not_utf8) printf '# 제목\n\n\377\376 깨진 글자\n' > "$DOC4" ;;
  esac
  begin "$D4"
  assert_eq "$BR_RC" "2" "$kind: 문서를 못 읽으면 rc 2"
  assert_contains "$BR_ERR" '"reason": "doc_unreadable"' "$kind: 사유 doc_unreadable"
  assert_contains "$BR_ERR" "$DOC4" "$kind: 사유에 원장의 문서 경로"
  if cmp -s "$D4/docreview-state.md" "$T/miss-$kind.before"; then ok "$kind: 원장 바이트 불변"; else no "$kind: 원장이 바뀌었다"; fi
done

note "== test_edit_after_begin_round_shows_next_round"
D5="$T/edit"; DOC5="$T/edit.md"
write_doc "$DOC5" "" "본문."
new_ledger "$D5" "$DOC5" "$PROF"
begin "$D5"
h1="$(python3 "$ANCHOR" snapshot "$DOC5" | python3 -I -c 'import json,sys;print(next(s["hash"] for s in json.load(sys.stdin)["sections"] if s["anchor"]=="#배경"))')"
write_doc "$DOC5" "" "고친 본문."
got1="$(ledger_snap "$D5" 1)"
assert_contains "$got1" "\"hash\": \"$h1\"" "라운드 1 스냅숏은 begin-round 시점의 문서다"
begin "$D5"
assert_eq "$BR_RC" "0" "라운드 2 시작"
rd="$(round_diff "$D5" 2)"
assert_contains "$rd" '"changed": ["#배경"]' "begin-round 뒤 편집이 라운드 2 의 얼림 diff 에 바뀐 절로 보인다"

note "== test_item_marks_carried"
D6="$T/items"; DOC6="$T/items.md"
write_doc "$DOC6" "" "본문."
new_ledger "$D6" "$DOC6" "$PROF"
begin "$D6"
m1="$(ledger_snap "$D6" 1 | python3 -I -c 'import json,sys;print(next(s["item_marks"] for s in json.load(sys.stdin)["sections"] if s["anchor"]=="#원칙"))')"
write_doc "$DOC6" "- P3 셋" "본문."
begin "$D6"
assert_eq "$BR_RC" "0" "불변 절에 항목 하나를 더한 문서로 라운드 2 시작"
m2="$(ledger_snap "$D6" 2 | python3 -I -c 'import json,sys;print(next(s.get("item_marks","") for s in json.load(sys.stdin)["sections"] if s["anchor"]=="#원칙"))')"
assert_eq "$m2" "${m1}1" "라운드 2 의 item_marks 는 라운드 1 표시에 항목 표시 하나를 더한 것"
assert_eq "$(ledger_snap "$D6" 2)" "$(expected_snap "$DOC6" "$FENCE" "$IMM")" "라운드 2 스냅숏도 앵커 스냅숏의 칸과 같다"
rd="$(round_diff "$D6" 2)"
assert_contains "$rd" '"#원칙": "append-only"' "「새 항목만 추가」로 읽힌다"
assert_not_contains "$rd" '"changed": ["#원칙"' "얼림 위반으로 막히지 않는다"
# 양의 짝 — 항목이 아닌 줄을 더하면 같은 판정이 바뀜으로 본다
write_doc "$DOC6" "- P3 셋
설명 줄" "본문."
sed -i.bak 's/^- P1 하나$/- P1 고침/' "$DOC6"
begin "$D6"
rd="$(round_diff "$D6" 3)"
assert_contains "$rd" '"changed": ["#원칙"]' "양의 짝: 앞 항목을 고치면 불변 절 바뀜"

note "== 호출자 문면 — begin-round 호출에 스냅숏 인자가 없다"
LOCK_OUT="$(cd "$ROOT" && git ls-files -z plugins shared | python3 -I -c '
import os, re, sys
flag = sys.argv[1]
names = [n for n in sys.stdin.read().split("\0") if n]
corpus, bad = [], []
for n in names:
    if os.path.basename(n) == "CHANGELOG.md" or os.path.islink(n) or not os.path.isfile(n):
        continue
    try:
        text = open(n, encoding="utf-8").read()
    except (UnicodeDecodeError, OSError):
        continue
    if "begin-round" not in text:
        continue
    corpus.append(n)
    for i, line in enumerate(re.sub(r"\\\n", " ", text).split("\n"), 1):
        if "begin-round" in line and flag in line[line.index("begin-round"):]:
            bad.append("%s: %s" % (n, line.strip()[:160]))
print("CORPUS", len(corpus))
for n in corpus:
    print("FILE", n)
for b in bad:
    print("BAD", b)
' "$OLD_FLAG")"
n_bad="$(printf '%s\n' "$LOCK_OUT" | grep -c '^BAD ')"
assert_eq "$n_bad" "0" "음의 락: begin-round 호출 뒤에 스냅숏 인자가 붙은 줄 0"
[ "$n_bad" = 0 ] || printf '%s\n' "$LOCK_OUT" | grep '^BAD ' | head -20
for f in plugins/spec-distill/tests/test_framing_review_contract.sh plugins/spec-distill/tests/test_ledger_wiring.sh \
  plugins/spec-distill/tests/test_reviewing_brief_residue.sh plugins/spec-distill/tests/test_reviewing_spec_residue.sh \
  plugins/spec-distill/tests/test_seed_review_log.sh plugins/spec-distill/tests/test_seed_review_profile.sh \
  plugins/spec-distill/tests/test_state_storage_e2e.sh plugins/spec-distill/tests/test_state_dir_writes.sh \
  plugins/spec-distill/tests/test_ledger_root.sh shared/tests/fixtures/docreview/cases.sh \
  shared/tests/fixtures/docreview/cases_advice.sh shared/tests/test_docreview_gate_visibility.sh \
  shared/docreview/references/reviewing-document.md; do
  if printf '%s\n' "$LOCK_OUT" | grep -qxF "FILE $f"; then ok "양의 짝: 코퍼스에 $f (begin-round 를 부른다)"; else no "양의 짝: 코퍼스에 $f 가 없다"; fi
done
n_cases="$(grep -c 'docreview_state\.py"\{0,1\} begin-round' "$ROOT/shared/tests/fixtures/docreview/cases.sh")"
if [ "$n_cases" -ge 74 ]; then ok "양의 짝: cases.sh 의 begin-round 호출 줄 ${n_cases}개(하한 74)"; else no "cases.sh 의 begin-round 호출 줄이 ${n_cases}개로 줄었다"; fi

RD="$ROOT/shared/docreview/references/reviewing-document.md"
assert_grep "$(cat "$RD")" 'begin-round --state-dir D' "절차서 1단계에 begin-round --state-dir"
assert_not_grep "$(cat "$RD")" '> *snap\.json' "절차서에 스냅숏 파일을 쓰는 줄이 없다"
for f in "$RD" "$SD/skills/reviewing-brief/SKILL.md" "$SD/skills/spec-review/SKILL.md"; do
  body="$(tr '\n' ' ' < "$f")"
  assert_not_contains "$body" "문서를 보지 않으므로" "${f#$ROOT/}: 「문서를 보지 않으므로」가 없다"
  assert_contains "$body" '`begin-round` 는 원장에 적힌 문서만 읽으므로' "${f#$ROOT/}: 새 문장이 있다"
done

finish
