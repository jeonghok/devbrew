#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py plugins/*/references/docreview-profiles/*.md
#
# `load_profile()` 은 최상위 키만 여분 키를 검사하고 `layer_rubric` 자신의 키는
# 열거하지 않았다(Park P1 — 확인된 익스플로잇). codex 러너의 `_block_span("layer_rubric", …)`
# 은 블록으로 옳게 좁히지만 그 블록 안에서 `_flow_list` 가 다시 무제한 last-match 를 하므로,
# `layer_rubric` 밑에 더 깊이 들여쓴 셋째 키(블록 스칼라)의 미끼 `layer1`/`layer2` 가
# 조용히 이긴다 — rc 0, 가드 미발동. 이 락은 `layer_rubric` 의 허용 키를 {layer1, layer2}
# 로 닫는 게이트를 고정한다.
#
# 넷: ① 셋째 키(foo, 블록 스칼라 미끼) 거부(음) ② layer1·layer2 만 있는 정상 프로필은
# 통과(양성 짝 — 이게 없으면 「전부 거부」로 구현해도 ①이 통과한다) ③ 실사용 프로필
# 넷(design-doc·brief·seed·generic)이 전부 통과(배포 회귀 방지) ④(컨트롤러 결의) 함수
# 단위 검증만으로는 codex 러너 앞에 게이트가 실제로 서는지 증명하지 않으므로,
# `docreview_state.py init`(reviewing-document.md 「선결」의 라운드 진입 실경로)도 같은
# 익스플로잇 프로필을 거부하는지 잰다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/scripts/docreview_state.py"
  git ls-files -- 'plugins/*/references/docreview-profiles/*.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
export PYTHONDONTWRITEBYTECODE=1
TMPD="$(mktemp -d -t docreview-profschema-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

DD="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"

# 익스플로잇 픽스처: layer_rubric 밑에 layer1·layer2 다음 셋째 키(foo, 블록 스칼라
# 미끼)를 심는다 — 브리프의 결함 재현 YAML 그대로.
awk '
  { print }
  /^  layer2:/ && !done {
    print "  foo: |"
    print "    layer1: [decoy_recursive_layer1]"
    print "    layer2: [decoy_recursive_layer2]"
    done = 1
  }
' "$DD" > "$TMPD/exploit.md"
grep -q '^  foo: |$' "$TMPD/exploit.md" || no "exploit fixture 가 적용되지 않았다(전제조건 실패)"

# ① 음 — 셋째 키가 있으면 profile-check 가 거부한다(rc 2, 최상위 여분 키 검사와 같은 rc).
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/exploit.md" >"$TMPD/out1.json" 2>"$TMPD/err1"
rc=$?
assert_eq "$rc" "2" "익스플로잇: layer_rubric.foo 셋째 키 → profile-check rc 2"
assert_file_grep "$TMPD/err1" 'layer_rubric' "익스플로잇: 오류 문면이 layer_rubric 을 언급한다"

# ② 양(positive pair) — layer1·layer2 만 있는 정상 프로필은 그대로 통과한다.
# 이 짝이 없으면 「layer_rubric 전부 거부」로 구현해도 ①이 통과해 버린다.
if python3 "$SCRIPTS/docreview_state.py" profile-check "$DD" >"$TMPD/out2.json" 2>"$TMPD/err2"; then
  ok "양성 짝: layer1·layer2 만 있는 design-doc 프로필은 통과한다"
else
  no "양성 짝: design-doc 프로필이 거부됐다 — $(cat "$TMPD/err2")"
fi

# ③ 실사용 프로필 넷이 전부 통과한다(이 변경이 배포된 프로필을 깨지 않는다는 회귀 방지).
n=0
for p in "$REPO_ROOT"/plugins/*/references/docreview-profiles/*.md; do
  n=$((n+1))
  if python3 "$SCRIPTS/docreview_state.py" profile-check "$p" >/dev/null 2>"$TMPD/err3"; then
    ok "배포 프로필 통과: ${p#"$REPO_ROOT"/}"
  else
    no "배포 프로필 거부됨: ${p#"$REPO_ROOT"/} — $(cat "$TMPD/err3")"
  fi
done
assert_eq "$n" "4" "배포 프로필은 정확히 넷(design-doc·brief·seed·generic)"

# ④ (컨트롤러 결의) 라운드 진입 실경로 — `docreview_state.py init` 이 reviewing-document.md
# 「선결(1단계 앞, 매 라운드)」에 적힌 그대로다: `init --state-dir D --doc <doc> --profile
# <profile>`. 이 경로가 같은 익스플로잇 프로필을 거부하지 못하면, load_profile() 을 닫아도
# codex 러너 앞에 실제 게이트가 서지 않는다(함수 단위 단언만으로는 증명이 안 된다).
STATED="$TMPD/state-dir"
mkdir -p "$STATED"
DOCFAKE="$TMPD/fake-doc.md"
printf '# 가짜 문서\n' > "$DOCFAKE"
python3 "$SCRIPTS/docreview_state.py" init --state-dir "$STATED" --doc "$DOCFAKE" \
  --profile "$TMPD/exploit.md" >"$TMPD/out4.json" 2>"$TMPD/err4"
rc=$?
assert_eq "$rc" "1" "라운드 진입(init): 익스플로잇 프로필 거부 rc 1"
assert_file_grep "$TMPD/err4" 'layer_rubric' "라운드 진입(init): 오류 문면이 layer_rubric 을 언급한다"
if [ -f "$STATED/docreview-state.md" ]; then
  no "라운드 진입(init): 거부됐는데 상태 파일이 생겼다"
else
  ok "라운드 진입(init): 거부되어 상태 파일이 생기지 않았다"
fi

# ⑤ (Task 3c R37) 중복 키. PyYAML 기본은 같은 키가 두 번 나오면 나중 값으로 조용히 덮고,
# codex 러너의 stdlib 파서는 모양이 다른 중복(`[a]` 뒤 `- b`)에서 앞의 flow 값을 읽었다
# (실측: 게이트 rc 0 · layer1 = ['marker_block_last'] — 러너 층 1 = 원래 여덟). 판정 지점을
# 게이트 하나로 둔다: 중복 키가 있으면 진입에서 멈춘다. 모양이 다른 중복 둘(중첩·최상위) +
# 같은 모양 중복 둘(web · ground_truth).
python3 - "$DD" "$TMPD" <<'PY'
import re, sys
src, d = sys.argv[1:3]
t = open(src, encoding="utf-8").read()
cases = {
    "layer1": (r"^(  layer1: \[[^\]]*\])$", r"\1\n  layer1:\n    - marker_block_last"),
    "allowed_dispositions": (r"^(allowed_dispositions: \[[^\]]*\])$",
                             r"\1\nallowed_dispositions:\n  - decide\n  - ask"),
    "web": (r"^(web: false)$", r"\1\nweb: true"),
    "ground_truth": (r"^(ground_truth: .*)$", r'\1\nground_truth: "marker_gt_second"'),
}
for key, (pat, rep) in cases.items():
    n, c = re.subn(pat, rep, t, count=1, flags=re.M)
    assert c == 1, key
    open("%s/dup-%s.md" % (d, key), "w", encoding="utf-8").write(n)
PY
for key in layer1 allowed_dispositions web ground_truth; do
  python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/dup-$key.md" >/dev/null 2>"$TMPD/dup-$key.err"
  rc=$?
  assert_eq "$rc" "2" "중복 키($key) → profile-check rc 2"
  assert_file_grep "$TMPD/dup-$key.err" "duplicate_key:$key" "중복 키($key) → 사유가 duplicate_key:$key 다"
done
# 양의 짝 — 서로 다른 매핑의 같은 이름은 중복이 아니다. design-doc 은 `heading:` 을
# decision_log 와 defer_target 두 매핑에 갖는다(전제를 먼저 잰다 — 없으면 이 짝은 공허하다).
n_heading="$(sed -n '2,/^---$/p' "$DD" | grep -c 'heading:')"
[ "$n_heading" -ge 2 ] && ok "전제: design-doc frontmatter 에 heading: 이 두 매핑에 있다(${n_heading})" \
  || no "전제: design-doc frontmatter 의 heading: 이 ${n_heading} 개뿐 — 양의 짝이 공허하다"
if python3 "$SCRIPTS/docreview_state.py" profile-check "$DD" >/dev/null 2>"$TMPD/err5"; then
  ok "양성 짝: 다른 매핑의 같은 키 이름(heading)은 중복으로 거절되지 않는다"
else
  no "양성 짝: design-doc 이 거절됐다 — $(cat "$TMPD/err5")"
fi

# ⑥ (Task 3c R34) 본문 — 탐지·재비판 agent 와 codex 러너가 함께 읽는 루브릭. 공백뿐이면
# 러너가 `profile_body_empty` 로 fail-closed 하고 게이트도 같은 판정을 낸다. 양의 짝은 ③
# (본문이 있는 배포 프로필 넷 통과).
python3 - "$DD" "$TMPD/body-empty.md" <<'PY'
import sys
t = open(sys.argv[1], encoding="utf-8").read()
end = t.find("\n---\n", 4)
open(sys.argv[2], "w", encoding="utf-8").write(t[:end + 5] + "\n  \n")
PY
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/body-empty.md" >/dev/null 2>"$TMPD/err6"
rc=$?
assert_eq "$rc" "2" "빈 본문(공백뿐) → profile-check rc 2"
assert_file_grep "$TMPD/err6" 'profile_body_empty' "빈 본문 → 사유가 profile_body_empty 다"

# ⑦ (Task 3c R43) 층 항목의 타입 — 러너는 문자열 목록이 아니면 멈춘다. 게이트도 같은 판정을 낸다
# (`_str_list`). 양의 짝은 ③(배포 프로필 넷의 문자열 층 목록 통과).
for lk in layer1 layer2; do
  python3 - "$DD" "$TMPD/l-$lk.md" "$lk" <<'PY'
import re, sys
src, dst, lk = sys.argv[1:4]
t = open(src, encoding="utf-8").read()
n, c = re.subn(r"^(  %s: )\[[^\]]*\]$" % lk, r"\g<1>[1]", t, count=1, flags=re.M)
assert c == 1, lk
open(dst, "w", encoding="utf-8").write(n)
PY
  python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/l-$lk.md" >/dev/null 2>"$TMPD/err7-$lk"
  rc=$?
  assert_eq "$rc" "2" "층 항목이 문자열이 아님($lk: [1]) → profile-check rc 2"
  assert_file_grep "$TMPD/err7-$lk" "field_not_str_list:layer_rubric.$lk" \
    "층 항목이 문자열이 아님($lk) → 사유가 field_not_str_list:layer_rubric.$lk 다"
done

# ⑧ (Task 3c 재리뷰 2 Minor 1) 층 범주명은 정규식이 아니다 — 게이트가 컴파일하지 않는다. `"c++"` 를
# 게이트만 `bad_regex` 로 거절하고 러너는 받던 반대 방향 발산이었다(러너 쪽 셀은
# test_docreview_codex.sh 의 l1-regexy). 양의 짝: 정규식 필드(fix_anchors)는 여전히 컴파일한다 —
# 층에서 푼 검사가 정규식 필드까지 번지면 거기서 RED.
python3 - "$DD" "$TMPD/l1-regexy.md" "$TMPD/fa-badre.md" <<'PY'
import re, sys
src, d1, d2 = sys.argv[1:4]
t = open(src, encoding="utf-8").read()
n, c = re.subn(r"^(  layer1: \[)", lambda m: m.group(1) + '"c++", "(", ', t, count=1, flags=re.M)
assert c == 1, "layer1"
open(d1, "w", encoding="utf-8").write(n)
n, c = re.subn(r'^fix_anchors: \["\*"\]$', 'fix_anchors: ["("]', t, count=1, flags=re.M)
assert c == 1, "fix_anchors"
open(d2, "w", encoding="utf-8").write(n)
PY
if python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/l1-regexy.md" >"$TMPD/out8.json" 2>"$TMPD/err8"; then
  ok "층 범주명에 정규식 메타(c++ · 여는 괄호) → profile-check 가 받는다(컴파일하지 않는다)"
else
  no "층 범주명에 정규식 메타 → profile-check 가 거절했다 — $(cat "$TMPD/err8")"
fi
assert_eq "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["layer_rubric"]["layer1"][:2])' "$TMPD/out8.json" 2>/dev/null)" \
  "['c++', '(']" "층 범주명: 받은 값이 문자열 그대로다"
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/fa-badre.md" >/dev/null 2>"$TMPD/err8b"
rc=$?
assert_eq "$rc" "2" "양의 짝: 정규식 필드 fix_anchors 에 못 여는 괄호 → profile-check rc 2"
assert_file_grep "$TMPD/err8b" 'bad_regex:fix_anchors' "양의 짝: 사유가 bad_regex:fix_anchors 다"

# ── category 사람말 사상 커버리지 (AC19') ──────────────────────────────────
# 렌더는 프로필별이 아니라 «엔진 하나»다. 그래서 사상 코퍼스는 네 프로필의 층 1·2 축
# 전부 + 엔진이 직접 만드는 category(frozen_change 등)다. 두 프로필로 좁히면 가장 흔한
# 항목(얼림 검사가 잡은 변경)이 상시 advisory 경로가 된다.
#
# 방향은 ∀ 다: 도출한 이름 «전부»가 사상에 있어야 한다. 여분 사상은 무해하다 — 방향은
# ∀(도출 → 사상)만 잰다.
note "── category 사람말 사상 — 코퍼스는 열거가 아니라 프로필에서 도출한다"
MISSING="$(python3 - "$REPO_ROOT" <<'PY'
import pathlib, sys, yaml
root = pathlib.Path(sys.argv[1])
sys.path.insert(0, str(root / "plugins" / "spec-distill" / "scripts"))
from docreview_state import category_gloss
names = set()
profs = sorted(root.glob("plugins/*/references/docreview-profiles/*.md"))
for p in profs:
    fm = p.read_text(encoding="utf-8").split("---")[1]
    lr = yaml.safe_load(fm)["layer_rubric"]
    names |= set(lr.get("layer1") or []) | set(lr.get("layer2") or [])
# 엔진이 직접 만드는 category — docreview_route.py 가 손으로 짓는 자리에서 온다.
names |= {"frozen_change", "other"}
print(len(profs), len(names))
for n in sorted(names):
    if category_gloss(n) is None:
        print("MISSING", n)
PY
)"
head_line="$(printf '%s\n' "$MISSING" | head -1)"
n_prof_seen="$(printf '%s' "$head_line" | cut -d' ' -f1)"
n_names="$(printf '%s' "$head_line" | cut -d' ' -f2)"
if [ "${n_prof_seen:-0}" -ge 4 ] && [ "${n_names:-0}" -ge 25 ]; then
  ok "사상: 프로필 ${n_prof_seen}개에서 category ${n_names}개를 도출했다 (양의 짝 — 아래 판정이 공허하지 않다)"
else
  no "사상: 프로필 ${n_prof_seen}개 · category ${n_names}개 — 도출이 무너졌다. 아래 판정이 공허하다"
fi
miss="$(printf '%s\n' "$MISSING" | grep -c '^MISSING ' || true)"
if [ "${miss:-0}" -eq 0 ]; then
  ok "사상: 도출한 category 전부에 사람말이 있다"
else
  no "사상: 사람말 없는 category ${miss}개 — $(printf '%s\n' "$MISSING" | sed -n 's/^MISSING //p' | tr '\n' ' ')"
fi

finish
