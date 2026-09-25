#!/usr/bin/env bash
# guards: shared/docreview/agents/doc-critic*.md shared/docreview/agents/doc-recritic.md plugins/*/agents/doc-critic*.md plugins/*/agents/doc-recritic.md
#
# 리뷰어가 «대체안 칸 둘»(`replacement`·`if_unfixed`)을 내라는 일반 요구 — 삭제 제안 문구와
# 「빈 칸은 삭제 제안이 아니다」까지 — 는 agent 본문에 산다(AC19 · AC19″). 프로필은 그 일부만
# 되풀이하고(design-doc 의 decide 규칙 · overdesign 필드 사상) seed · generic 에는 없다. 엔진 쪽
# case 는 손으로 쓴 fixture 로 배관만 증명하므로, 본문에서 그 요구가 빠져도 엔진 스위트는 전부
# GREEN 이고 게이트 블록은 「(대체안 미작성)」으로 떨어질 수 있다.
#
# 각 단언은 그 요구가 사는 자리 안에서만 잰다 — 예시 줄은 층 1 펜스 안, 산문은 그 절·문단
# 안. 파일 전체에서 재면 다른 자리의 언급이 락을 만족시킨다. 부분 문자열 핀이라 문장 뒤에
# 붙인 부정은 못 잡는다. 사본 코퍼스는 열거가 아니라 `git ls-files` 도출이고, 개수 하한이
# 양의 짝이다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'shared/docreview/agents/doc-critic*.md' 'shared/docreview/agents/doc-recritic.md' \
                  'plugins/*/agents/doc-critic*.md' 'plugins/*/agents/doc-recritic.md'
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 1
. "$HERE/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

# section <file> <시작 ERE> <끝 ERE> — 시작 줄부터 끝 줄 «직전»까지. 끝이 없으면 파일 끝까지.
section() {
  python3 - "$1" "$2" "$3" <<'PY'
import re, sys
path, start, end = sys.argv[1:4]
lines = open(path, encoding="utf-8").read().split("\n")
out, on = [], False
for ln in lines:
    if not on and re.search(start, ln):
        on = True
    elif on and re.search(end, ln):
        break
    if on:
        out.append(ln)
print("\n".join(out))
PY
}

# ── AC19 — 탐지 리뷰어 사본 전부의 「## 출력 형식」 절 ─────────────────────────────
n=0
while IFS= read -r f; do
  n=$((n+1))
  s="$(section "$f" '^## 출력 형식' '^## ')"
  assert_contains "$s" '`replacement`(**`decide` 에는 필수**' "AC19: $f 출력 형식 — replacement 는 decide 에 필수다"
  assert_contains "$s" '`if_unfixed`(' "AC19: $f 출력 형식 — if_unfixed 칸을 정의한다"
  assert_contains "$s" '대체안 없음 — 그냥 뺀다' "AC19: $f 출력 형식 — 삭제 제안의 명시 문구가 있다"
  assert_contains "$s" '칸을 비우는 것은 삭제 제안이 **아니다**' "AC19: $f 출력 형식 — 빈 칸은 삭제 제안이 아니다"
  # 예시 줄은 층 1 펜스 안의 decide 항목에서 — 절 전체로 재면 층 2 의 fix 항목으로 옮겨도 통과한다.
  l1="$(printf '%s\n' "$s" | sed -n '/^```docreview-layer1/,/^```$/p')"
  # 항목(`- ref:` 로 시작) 단위로 가른다 — 펜스 어딘가에 세 줄이 흩어져 있는 것으로는 부족하다.
  assert_eq "$(printf '%s\n' "$l1" | python3 -c '
import re, sys
items = re.split(r"(?m)^- ref:", sys.stdin.read())[1:]
need = (r"(?m)^  disposition: decide\b", r"(?m)^  replacement: ", r"(?m)^  if_unfixed: ")
print(len(items) >= 1 and any(all(re.search(n, it) for n in need) for it in items))')" "True" \
    "AC19: $f 층 1 예시 — decide 항목 하나가 replacement·if_unfixed 줄을 함께 갖는다"
done < <(git ls-files -- 'shared/docreview/agents/doc-critic*.md' 'plugins/*/agents/doc-critic*.md')
if [ "$n" -ge 4 ]; then
  ok "AC19 양의 짝: 탐지 리뷰어 사본 ${n}개를 쟀다(정본 둘 + 플러그인 사본 둘 이상)"
else
  no "AC19 양의 짝: 탐지 리뷰어 사본이 ${n}개뿐이다 — 4개 이상이어야 위 단언이 공허하지 않다"
fi

# ── AC19″ — 재비판자 사본 전부의 `added` 규약 ──────────────────────────────────────
# 산문은 `놓친 결함이 있으면` 문단(첫 빈 줄까지) 안에서, 예시는 `## 출력 형식` 의 `added:` 블록에서.
n=0
while IFS= read -r f; do
  n=$((n+1))
  p="$(section "$f" '^놓친 결함이 있으면' '^$')"
  assert_contains "$p" '`replacement`·`if_unfixed` 도 그렇다' "AC19″: $f — added 규칙 문단이 두 칸을 싣게 한다"
  a="$(section "$f" '^## 출력 형식' '^## ' | sed -n '/^added:/,$p')"
  assert_grep "$a" '^    replacement: ' "AC19″: $f 출력 예시 — added 항목에 replacement 줄이 있다"
  assert_grep "$a" '^    if_unfixed: ' "AC19″: $f 출력 예시 — added 항목에 if_unfixed 줄이 있다"
done < <(git ls-files -- 'shared/docreview/agents/doc-recritic.md' 'plugins/*/agents/doc-recritic.md')
if [ "$n" -ge 2 ]; then
  ok "AC19″ 양의 짝: 재비판자 사본 ${n}개를 쟀다"
else
  no "AC19″ 양의 짝: 재비판자 사본이 ${n}개뿐이다 — 2개 이상이어야 한다"
fi

finish
