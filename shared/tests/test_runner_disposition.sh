#!/usr/bin/env bash
# guards: plugins/*/scripts/*codex*.sh
#
# 외부 모델 판정자(codex 러너)가 자기 처분을 밝히는지 검사한다.
#
# 모집단은 신설하지 않는다 — 리포에 도출기가 이미 있고 standing assertion 에
# 묶여 있다. 그 도구를 «고치지 않고» 출력에 /scripts/ 후처리만 건다.
#
# 이 축은 약하다. `disclosure=` 리터럴이 파일에 있다는 것이 그 채널이 실제로
# 읽힌다는 증거는 아니다 — 값이 저자 손에 있는 한 이 축에서 그 이상은 나오지
# 않는다. 없앴다고 주장하지 않고 어디로 옮겼는지 밝힌다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

EXTRACT="$REPO_ROOT/plugins/quality-gates/tests/lib/extract_codex_invocations.py"
if [ ! -f "$EXTRACT" ]; then
  no "도출기 부재: $EXTRACT — 모집단을 계산할 수 없다"
  finish; exit
fi

TMPD="$(mktemp -d -t rundisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$EXTRACT" "$REPO_ROOT/plugins" > "$TMPD/all.txt" 2>&1
grep '/scripts/' "$TMPD/all.txt" > "$TMPD/runners.txt" || true

# `--emit-scanned` — test_guards_coverage_bidirectional.sh 가 읽는다. 코퍼스는
# 위에서 이미 만든 runners.txt(도출기 + /scripts/ 후처리, ㉯) 다 — 다시
# 도출하지 않고 같은 파일을 그대로 낸다. 절대경로 → repo-relative 변환만
# 한다(선언 글롭이 repo-relative 라 매칭시키려면 필요) — 이것은 재도출이
# 아니라 서식 변환이다.
if [ "${1:-}" = "--emit-scanned" ]; then
  while IFS= read -r abs; do
    [ -n "$abs" ] || continue
    printf '%s\n' "${abs#"$REPO_ROOT"/}"
  done < "$TMPD/runners.txt"
  exit 0
fi

n_all="$(wc -l < "$TMPD/all.txt" | tr -d ' ')"
n_run="$(wc -l < "$TMPD/runners.txt" | tr -d ' ')"
note "도출기 출력 $n_all → /scripts/ 후처리 후 $n_run"

# 0 은 통과가 아니라 실패다.
if [ "${n_run:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉯ 도출 $n_run 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉯ 도출이 0 이다 — 도출기 출력이나 후처리가 깨졌다. 이 락의 모든 단언이 공허하다"
fi

# 후처리가 실제로 무언가를 걸러냈는지 — 안 걸러내면 후처리가 죽은 것이다.
if [ "${n_all:-0}" -gt "${n_run:-0}" ] 2>/dev/null; then
  ok "/scripts/ 후처리가 $((n_all - n_run)) 개를 걸러냈다 (spike/ 등)"
else
  no "후처리가 아무것도 안 걸러냈다 — 도출기 출력이 바뀌었거나 필터가 죽었다"
fi

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  # 도출기는 «절대» 경로를 낸다(`"$REPO_ROOT/plugins"` 로 호출하므로).
  # `$REPO_ROOT/` 를 다시 붙이면 전부 「파일 없음」으로 떨어져 아래 세 축이
  # 통째로 안 돈다 — 시끄러운 RED 가 조용한 vacuous 로 바뀐다.
  f="$rel"
  base="$(basename "$rel")"
  if [ ! -f "$f" ]; then no "$base: 도출된 경로가 실재하지 않는다"; continue; fi

  # **파일 본문이 아니라 «앵커 줄»에서 찾는다.** 본문 전체를 보면 산문이
  # 검사를 만족시킨다 — 실측: 여섯 중 셋이 에러 메시지와 설명 주석에
  # `fail-closed` 를 담고 있어 그 축이 «선언과 무관하게» 통과했다. 그러면
  # 나중에 진짜 선언을 넣었다 지워도 그 셋은 계속 초록이다(이빨 0).
  anchor="$(grep -F '**처분**' "$f" || true)"
  if [ -n "$anchor" ]; then
    ok "$base: 처분 앵커가 있다"
  else
    no "$base: 처분 앵커(\`**처분** — …\`)가 없다 — 아래 세 축은 빈 줄을 검사한다"
  fi
  assert_grep "$anchor" 'consumer=' \
    "$base: 앵커가 consumer= 를 밝힌다 (누가 이 판정을 읽는가)"
  assert_grep "$anchor" 'fail-(open|closed)' \
    "$base: 앵커가 fail-open/fail-closed 를 밝힌다 (죽었을 때 어느 쪽으로 기우는가)"
  assert_grep "$anchor" 'disclosure=' \
    "$base: 앵커가 disclosure= 를 밝힌다 (어느 채널로 드러나는가)"
done < "$TMPD/runners.txt"

finish
