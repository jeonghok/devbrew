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
  # 도출기는 넘겨받은 root 인자의 형태를 그대로 돌려준다(`str(Path(root).rglob(...))`).
  # 위에서 `$REPO_ROOT/plugins`(절대경로)로 호출했으므로 `$rel`은 이미 절대경로다 —
  # 여기서 $REPO_ROOT 를 다시 붙이면 존재하지 않는 이중 경로가 되어 «파일 없음»으로
  # 오분류되고 세 처분 단언까지 못 간다(실측: 2026-09-03, 6×path-not-found ≠ 18×disposition-fail).
  f="$rel"
  base="$(basename "$rel")"
  if [ ! -f "$f" ]; then no "$base: 도출된 경로가 실재하지 않는다"; continue; fi
  body="$(cat "$f")"
  assert_grep "$body" 'consumer=' \
    "$base: consumer= 를 밝힌다 (누가 이 판정을 읽는가)"
  assert_grep "$body" 'fail-(open|closed)' \
    "$base: fail-open/fail-closed 를 밝힌다 (죽었을 때 어느 쪽으로 기우는가)"
  assert_grep "$body" 'disclosure=' \
    "$base: disclosure= 를 밝힌다 (어느 채널로 드러나는가)"
done < "$TMPD/runners.txt"

finish
