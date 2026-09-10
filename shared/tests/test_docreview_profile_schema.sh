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

finish
