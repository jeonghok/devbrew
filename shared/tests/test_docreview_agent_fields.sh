#!/usr/bin/env bash
# guards: shared/docreview/agents/doc-critic*.md shared/docreview/agents/doc-recritic.md plugins/*/agents/doc-critic*.md plugins/*/agents/doc-recritic.md
#
# 리뷰어가 «대체안 칸 둘»(`replacement`·`if_unfixed`)을 내라는 요구는 agent 본문에만 있다(AC19 ·
# AC19″). 엔진 쪽 case 는 손으로 쓴 fixture 로 배관만 증명하므로, 본문에서 그 요구가 빠지면
# 엔진 스위트는 전부 GREEN 인 채로 게이트의 모든 블록이 「(대체안 미작성)」이 된다.
#
# 각 단언은 그 요구가 사는 «절 안»에서만 잰다 — 파일 전체에서 재면 다른 절의 언급이 락을
# 만족시킨다. 사본 코퍼스는 열거가 아니라 `git ls-files` 도출이고, 개수 하한이 양의 짝이다.
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
  assert_grep "$s" '^  replacement: ' "AC19: $f 출력 형식 예시 — 항목에 replacement 줄이 있다"
  assert_grep "$s" '^  if_unfixed: ' "AC19: $f 출력 형식 예시 — 항목에 if_unfixed 줄이 있다"
done < <(git ls-files -- 'shared/docreview/agents/doc-critic*.md' 'plugins/*/agents/doc-critic*.md')
if [ "$n" -ge 4 ]; then
  ok "AC19 양의 짝: 탐지 리뷰어 사본 ${n}개를 쟀다(정본 둘 + 플러그인 사본 둘 이상)"
else
  no "AC19 양의 짝: 탐지 리뷰어 사본이 ${n}개뿐이다 — 4개 이상이어야 위 단언이 공허하지 않다"
fi

# ── AC19″ — 재비판자 사본 전부의 `added` 규약 ──────────────────────────────────────
# `놓친 결함이 있으면` 부터 파일 끝까지 — 그 산문과 출력 예시의 `added:` 블록이 함께 든다.
n=0
while IFS= read -r f; do
  n=$((n+1))
  s="$(section "$f" '^놓친 결함이 있으면' '(?!)')"   # 끝 패턴 `(?!)` 는 결코 맞지 않는다 — 파일 끝까지
  assert_contains "$s" '`replacement`·`if_unfixed` 도 그렇다' "AC19″: $f — added 에도 두 칸을 싣게 한다"
  a="$(printf '%s\n' "$s" | sed -n '/^added:/,$p')"
  assert_grep "$a" '^    replacement: ' "AC19″: $f 출력 예시 — added 항목에 replacement 줄이 있다"
  assert_grep "$a" '^    if_unfixed: ' "AC19″: $f 출력 예시 — added 항목에 if_unfixed 줄이 있다"
done < <(git ls-files -- 'shared/docreview/agents/doc-recritic.md' 'plugins/*/agents/doc-recritic.md')
if [ "$n" -ge 2 ]; then
  ok "AC19″ 양의 짝: 재비판자 사본 ${n}개를 쟀다"
else
  no "AC19″ 양의 짝: 재비판자 사본이 ${n}개뿐이다 — 2개 이상이어야 한다"
fi

finish
