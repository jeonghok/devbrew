#!/usr/bin/env bash
# guards: shared/docreview/references/reviewing-document.md plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/framing-requests/SKILL.md plugins/spec-distill/skills/conducting-interview/references/finishing.md shared/docreview/scripts/docreview_state.py
#
# 설계 2026-09-27-review-stopping-criterion AC11 — 절차서와 진입 자리의 문면이 참고(advisory) 목록의 한 번 표시 ·
# 박제 절차를 싣고, 그 문면이 부르는 `advice` 서브커맨드의 플래그가 실재한다(`advice --help` 로 도출 — 손 목록 없음).
# 자리별 필수 플래그: 절차서(계약) · reviewing-spec = render · sink · log-file / finishing(brief Step B) = render ·
# log-file / framing-requests(seed) = log-file. reviewing-brief 는 부르지 않는다(brief 의 한 번 표시는 Step B 한 곳).
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  echo "shared/docreview/references/reviewing-document.md"
  echo "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
  echo "plugins/spec-distill/skills/reviewing-brief/SKILL.md"
  echo "plugins/spec-distill/skills/framing-requests/SKILL.md"
  echo "plugins/spec-distill/skills/conducting-interview/references/finishing.md"
  echo "shared/docreview/scripts/docreview_state.py"
  exit 0
fi
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
HELP="$(python3 "$REPO_ROOT/plugins/spec-distill/scripts/docreview_state.py" advice --help 2>&1)"
assert_contains "$HELP" "--render" "전제: advice 서브커맨드가 실재한다(--help)"
CALL_RE='docreview_state\.py"? advice( |$)'
check_site() {   # check_site <파일> <필수 플래그…>
  local f="$1"; shift
  local calls flag
  calls="$(grep -E "$CALL_RE" "$REPO_ROOT/$f")"
  if [ -z "$calls" ]; then no "$f: advice 호출 줄이 없다"; return; fi
  ok "$f: advice 호출 줄 $(printf '%s\n' "$calls" | grep -c .)개"
  for flag in $(printf '%s\n' "$calls" | grep -oE -- '--[a-z][a-z-]*' | sort -u); do
    if printf '%s\n' "$HELP" | grep -qE -- "(^|[[ ])${flag}([] ,=]|$)"; then ok "$f: ${flag} 는 advice 가 받는다"
    else no "$f: ${flag} 는 advice --help 에 없다"; fi
  done
  for flag in "$@"; do
    if printf '%s\n' "$calls" | grep -qE -- "${flag}( |$)"; then ok "$f: ${flag} 호출이 있다"; else no "$f: ${flag} 호출이 없다"; fi
  done
}
check_site shared/docreview/references/reviewing-document.md --render --sink --log-file
check_site plugins/spec-distill/skills/reviewing-spec/SKILL.md --render --sink --log-file
check_site plugins/spec-distill/skills/conducting-interview/references/finishing.md --render --log-file
check_site plugins/spec-distill/skills/framing-requests/SKILL.md --log-file
RB="$(cat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md")"
assert_not_grep "$RB" "$CALL_RE" "reviewing-brief: advice 를 부르지 않는다 — brief 의 한 번 표시는 호출자 Step B 한 곳"
assert_contains "$RB" "참고(advisory) 목록은 이 skill 이 보이지 않는다" "reviewing-brief: 참고 목록은 Step B 가 보인다고 말한다"
RS="$(cat "$REPO_ROOT/plugins/spec-distill/skills/reviewing-spec/SKILL.md")"
assert_contains "$RS" "1단계가 있었으면 그것이 진행 쪽으로 닫힌 뒤" "reviewing-spec: 표시 시점이 1단계가 진행 쪽으로 닫힌 뒤 · 2단계 앞이다"
assert_contains "$RS" "「추가 라운드 1회 열기」를 고른 흐름에서는 돌리지 않는다" "reviewing-spec: 추가 라운드를 열면 표시가 미뤄진다"
FIN="$(cat "$REPO_ROOT/plugins/spec-distill/skills/conducting-interview/references/finishing.md")"
assert_contains "$FIN" "사용자가 고를 것이 있는가" "finishing: §3 / §5 를 가르는 판단 문면이 있다"
assert_contains "$FIN" 'check_brief.py" gate "$PAYLOAD"' "finishing: 박제 뒤 구조 게이트를 다시 돈다"
assert_not_contains "$FIN" "층 1(방향성) 결정은 라운드 게이트에서 이미 사용자가 판정했습니다" "finishing: B-2 의 낡은 문장(방향이 라운드 게이트에 온다)이 없다"
RD="$(cat "$REPO_ROOT/shared/docreview/references/reviewing-document.md")"
assert_contains "$RD" "끝에서 한 번" "절차서: 참고 목록은 끝에서 한 번이다"
finish
