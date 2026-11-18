#!/usr/bin/env bash
# guards: plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/references/docreview-profiles/design-doc.md
#
# brief 프로필과 설계문서 프로필이 첫 칸의 사용자 줄과 모델 줄을 갈라 읽으라고 «이름 짓는가».
# 재는 것은 문구의 실재다 — 리뷰어가 실제로 그렇게 읽는지는 못 잰다.
# 본문 단언은 층 2 절에서만, ground_truth 단언은 profile-check 가 낸 값에서만 찾는다
# (머리가 본문 단언을 만족시키지 못하게). 아래 변이 검사가 그 이빨을 잰다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'plugins/spec-distill/references/docreview-profiles/brief.md' \
                  'plugins/spec-distill/references/docreview-profiles/design-doc.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SCRIPTS="$ROOT/plugins/spec-distill/scripts"
PROF="$ROOT/plugins/spec-distill/references/docreview-profiles"
T="$(mktemp -d "${TMPDIR:-/tmp}/rsprof.XXXXXX")" || exit 1
trap 'rm -rf "$T"' EXIT

cat > "$T/check.py" <<'PY'
import json, os, re, subprocess, sys, shutil, tempfile
from importlib import import_module

SCRIPTS, BRIEF, DESIGN = sys.argv[1], sys.argv[2], sys.argv[3]
sys.path.insert(0, SCRIPTS)
raw_source = import_module("raw_source")


def rd(p):
    with open(p, encoding="utf-8") as fh:
        return fh.read()


def gt_of(path):
    out = subprocess.run([sys.executable, os.path.join(SCRIPTS, "docreview_state.py"),
                          "profile-check", path], capture_output=True, text=True)
    return json.loads(out.stdout)["ground_truth"]


def l2_of(text):
    m = re.search(r"^## 층 2.*?(?=^## |\Z)", text, re.S | re.M)
    return m.group(0) if m else ""


def body_of(text):
    return text.split("\n---\n", 1)[1] if "\n---\n" in text else text


GT = [
    ("gt_two_sources", ["`## 6. 사용자 원문` 의 사용자 줄", "`<<<RAW-SOURCE>>>` 뒤 블록의 사용자 줄"]),
    ("gt_model_lines", ["질문 문구 · 선택지 · 풀이 줄 · 구분 줄은 모델이나 저자가 쓴 줄이라 읽되 정답이 아니다"]),
    ("gt_unloadable", ["「원자료를 그대로 싣지 못함」 이면 첫 칸은 모델이 줄인 글이라 정답이 아니고"]),
    ("gt_lost", ["「원자료를 찾지 못함」 이면 견줄 원자료가 없어 첫 칸(seed 전문)에 견주되, "
                 "모델이 줄인 글에 견줬다는 것을 리뷰 앞 글과 기록에 밝힌다"]),
    ("gt_decision_scope", ["(리뷰 결정 문구는 정한 사실과 뜻까지만 정답이다)"]),
]
L2 = [
    ("body_separator", ["원문 절에서 `### ` 로 시작하는 줄은 저자가 쓴 구분 줄이라 읽되 사용자의 말이 아니다"]),
    ("body_label", ["「라벨」 표시가 붙은 답은 사용자가 고른 모델 문장이다", "☑ 로 표시된 답"]),
    ("body_typed_twice", ["글자는 원문 절이 정본이고"]),
    ("body_omission_block", ["`<<<RAW-SOURCE>>>` 뒤 블록이 있으면 그 사용자 줄도 끝까지 훑는다"]),
    ("body_decision_quote", ["낱말을 사용자의 글자로 인용하지 않는다"]),
    ("body_citation", ["`S1(질문 전체 절 — 라운드 <n> 의 «당신이 답한 것»)`"]),
]
PROTECT = "Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다."
DESIGN_LINE = ("**사용자 원문 절의 첫 칸을 읽는 법** — 정답 출처 파일(brief · 에픽 묶음)의 사용자 원문 절 첫 칸(`S1`)에 실린 "
               "질문 문구 · 선택지 · 풀이 줄 · 구분 줄(`### ` 로 시작하는 줄)은 모델이나 저자가 쓴 줄이라 읽되 사용자의 말이 아니고, "
               "첫 칸의 라벨이 「모델이 줄인 글」 을 말하면 그 칸은 사용자의 글자가 아니라 줄인 글이다.")


def profile_fails(b, d):
    bt, dt = rd(b), rd(d)
    gt, l2 = gt_of(b), l2_of(bt)
    bad = []
    for name, phrases in GT:
        if not all(p in gt for p in phrases):
            bad.append(name)
    frag = re.findall("「(원자료[^」]*)」", gt)
    want = (raw_source.LABEL_RAW, raw_source.LABEL_UNLOADABLE, raw_source.LABEL_LOST)
    if not (len(frag) == 3 and all(f in w for f, w in zip(frag, want))):
        bad.append("gt_labels_match_module")
    for name, phrases in L2:
        if not all(p in l2 for p in phrases):
            bad.append(name)
    rel = [ln for ln in bt.split("\n") if ln.startswith("**층 1 판정 관계** —")]
    if not (len(rel) == 1 and "첫 칸에 실린 모델 줄은 정답이 아니다" in rel[0]):
        bad.append("layer1_one_line")
    if PROTECT not in body_of(bt):
        bad.append("protect_line")
    if DESIGN_LINE not in dt:
        bad.append("design_sentence")
    return bad


def mutate(text, old, new, after=None):
    start = text.index(after) if after else 0
    i = text.index(old, start)
    return text[:i] + new + text[i + len(old):]


work = tempfile.mkdtemp(prefix="rsmut.")
try:
    base = profile_fails(BRIEF, DESIGN)
    print(("OK" if not base else "NO") + " 실제 두 프로필: 실패 항목 " + (",".join(base) or "없음"))
    brief_t, design_t = rd(BRIEF), rd(DESIGN)
    # (이름, 대상, 옛, 새, after 표지) — 첫 출현만 바꾼다. 대상: b | d
    muts = []
    for name, phrases in GT:
        muts.append((name + " 삭제", name, "b", phrases[0], "", None))
    muts.append(("gt_model_lines 반전", "gt_model_lines", "b",
                 "모델이나 저자가 쓴 줄이라 읽되 정답이 아니다", "모델이나 저자가 쓴 줄이라 읽고 정답이다", None))
    muts.append(("gt_labels 라벨 한쪽만 바뀜", "gt_labels_match_module", "b",
                 "「원자료를 찾지 못함」", "「원자료를 못 찾음」", None))
    for name, phrases in L2:
        muts.append((name + " 삭제", name, "b", phrases[0], "", "## 층 2"))
    muts.append(("body_label ☑ 문구 삭제", "body_label", "b", "☑ 로 표시된 답", "", "## 층 2"))
    muts.append(("body_decision_quote 반전", "body_decision_quote", "b",
                 "사용자의 글자로 인용하지 않는다", "사용자의 글자로 인용한다", "## 층 2"))
    muts.append(("layer1 문구 삭제", "layer1_one_line", "b",
                 " — 첫 칸에 실린 모델 줄은 정답이 아니다", "", None))
    muts.append(("protect_line 삭제", "protect_line", "b", PROTECT, "", None))
    muts.append(("design 줄 삭제", "design_sentence", "d", DESIGN_LINE, "", None))
    muts.append(("design 줄인 글이다 반전", "design_sentence", "d", "줄인 글이다.", "사용자의 글자다.", None))
    for label, want, tgt, old, new, after in muts:
        bp, dp = os.path.join(work, "b.md"), os.path.join(work, "d.md")
        with open(bp, "w", encoding="utf-8") as fh:
            fh.write(mutate(brief_t, old, new, after) if tgt == "b" else brief_t)
        with open(dp, "w", encoding="utf-8") as fh:
            fh.write(mutate(design_t, old, new, after) if tgt == "d" else design_t)
        got = profile_fails(bp, dp)
        print(("OK" if want in got else "NO") + " 변이 [" + label + "] -> " + want + " 실패 (실제: " + ",".join(got) + ")")
    # 층 1 판정 관계 줄을 더하는 변이 — 한 줄이어야 한다
    rel = [ln for ln in brief_t.split("\n") if ln.startswith("**층 1 판정 관계** —")][0]
    bp, dp = os.path.join(work, "b.md"), os.path.join(work, "d.md")
    with open(bp, "w", encoding="utf-8") as fh:
        fh.write(brief_t.replace(rel, rel + "\n\n" + rel, 1))
    shutil.copy(DESIGN, dp)
    got = profile_fails(bp, dp)
    print(("OK" if "layer1_one_line" in got else "NO") + " 변이 [판정 관계 줄 중복 추가] -> layer1_one_line 실패")
    # 머리만 만족: 본문에서 지우고 ground_truth 에만 넣는다 — 본문 단언은 실패해야 하고 gt 단언은 영향이 없다
    ph = "글자는 원문 절이 정본이고, "
    mb = mutate(brief_t, ph, "", "## 층 2").replace("정답이다(리뷰 결정", ph + "정답이다(리뷰 결정", 1)
    with open(bp, "w", encoding="utf-8") as fh:
        fh.write(mb)
    got = profile_fails(bp, DESIGN)
    print(("OK" if got == ["body_typed_twice"] else "NO") + " 변이 [머리에만 문구를 남김] -> body_typed_twice 만 실패 (실제: " + ",".join(got) + ")")
finally:
    shutil.rmtree(work, ignore_errors=True)
PY

python3 "$T/check.py" "$SCRIPTS" "$PROF/brief.md" "$PROF/design-doc.md" > "$T/out.txt" 2>"$T/err.txt"
rc=$?
[ "$rc" -eq 0 ] && ok "검사기가 끝까지 돌았다" || { no "검사기 rc=$rc: $(head -c 400 "$T/err.txt")"; }
n="$(wc -l < "$T/out.txt" | tr -d ' ')"
[ "${n:-0}" -ge 20 ] && ok "양의 짝: 검사 줄 ${n}개를 읽었다 (공허하지 않다)" || no "검사 줄이 ${n}개뿐이다 — 공허하다"
while IFS= read -r line; do
  case "$line" in
    OK*) ok "${line#OK }" ;;
    *)   no "${line#NO }" ;;
  esac
done < "$T/out.txt"

finish
