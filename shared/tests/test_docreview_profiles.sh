#!/usr/bin/env bash
# guards: plugins/*/references/docreview-profiles/*.md shared/docreview/scripts/docreview_state.py
#
# 프로필 넷의 frontmatter 가 열 필드 스키마를 지키고, 스키마를 깨는 변이가 진입 실패(rc 2)인지 잰다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'plugins/*/references/docreview-profiles/*.md'
  echo "shared/docreview/scripts/docreview_state.py"; exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
export PYTHONDONTWRITEBYTECODE=1
TMPD="$(mktemp -d -t docreview-prof-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT
n=0
for p in "$REPO_ROOT"/plugins/*/references/docreview-profiles/*.md; do
  n=$((n+1))
  if python3 "$SCRIPTS/docreview_state.py" profile-check "$p" > "$TMPD/out.json" 2>"$TMPD/err"; then
    ok "profile-check 통과: ${p#"$REPO_ROOT"/}"
  else
    no "profile-check 실패: ${p#"$REPO_ROOT"/} — $(cat "$TMPD/err")"
  fi
done
assert_eq "$n" "4" "프로필은 정확히 넷(design-doc·brief·seed·generic)"
# 정본 값 몇 개
DD="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/design-doc.md"
BR="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/brief.md"
SE="$REPO_ROOT/plugins/spec-distill/references/docreview-profiles/seed.md"
GE="$REPO_ROOT/plugins/quality-gates/references/docreview-profiles/generic.md"
chk() { python3 "$SCRIPTS/docreview_state.py" profile-check "$1" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1]))' "$2"; }
assert_eq "$(chk "$DD" '"defer" in d["allowed_dispositions"]')" "True"  "design-doc 만 defer 허용 (design-doc)"
assert_eq "$(chk "$BR" '"defer" in d["allowed_dispositions"]')" "False" "brief 는 defer 불허"
assert_eq "$(chk "$SE" '"defer" in d["allowed_dispositions"]')" "False" "seed 는 defer 불허"
assert_eq "$(chk "$GE" '"defer" in d["allowed_dispositions"]')" "False" "generic 은 defer 불허"
assert_eq "$(chk "$BR" 'len(d["immutable"])>0')" "True"  "brief 의 immutable 이 비어 있지 않다(§6)"
assert_eq "$(chk "$BR" 'd["web"]')" "True"  "brief 만 web true"
assert_eq "$(chk "$SE" 'd["layer_rubric"]["layer2"]')" "[]" "seed 는 층 2 를 비운다"
assert_eq "$(chk "$GE" 'd["decision_log"]["kind"]')" "state" "generic 의 결정 기록은 state"
# 변이 — 스키마를 깨면 rc 2 (양성 대조: 위에서 같은 파일이 통과했다)
sed '/^web:/d' "$DD" > "$TMPD/m1.md"
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/m1.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "변이: 필드 하나(web) 누락 → rc 2"
sed 's/^detectors: 1$/detectors: 2/' "$DD" > "$TMPD/m2.md"
grep -q '^detectors: 2$' "$TMPD/m2.md" || no "변이 m2 가 적용되지 않았다"
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/m2.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "변이: detectors 2 → rc 2 (이 판본의 허용값은 1 뿐)"
awk '{print} /^detectors: 1$/{print "extra_field: 1"}' "$DD" > "$TMPD/m3.md"   # macOS sed 는 치환문 `\n` 불가 → awk
grep -q '^extra_field:' "$TMPD/m3.md" || no "변이 m3 가 적용되지 않았다"
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/m3.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "변이: 열한 번째 필드 → rc 2"
sed 's/^allowed_dispositions: .*/allowed_dispositions: [decide, ask, fix, defer, drop]/; s/^defer_target: .*/defer_target: {kind: none}/' "$BR" > "$TMPD/m4.md"
python3 "$SCRIPTS/docreview_state.py" profile-check "$TMPD/m4.md" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "변이: defer 허용인데 defer_target none → rc 2 (목적지 없는 defer 는 침묵 삭제)"
finish
