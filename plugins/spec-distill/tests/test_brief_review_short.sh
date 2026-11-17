#!/usr/bin/env bash
# brief_review_state.py short — 질문의 경고 줄에 이을 brief 리뷰 경고의 짧은 줄.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_brief_review_short.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
SD="$ROOT/plugins/spec-distill"
BRS="$SD/scripts/brief_review_state.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

st="$T/state.md"; empty="$T/empty.md"; fb="$T/fallback.txt"
printf -- '---\nname: t\n---\n' > "$st"; cp "$st" "$empty"
python3 "$BRS" init "$st" >/dev/null
python3 "$BRS" init "$empty" >/dev/null
ap() { python3 "$BRS" degrade-append "$st" --component "$1" --reason r --axis "$2" --status "$3" >/dev/null; }
ap codex suppression skipped; ap codex suppression skipped; ap readback readback unavailable
printf '첫 경고\n\n둘째 경고\n' > "$fb"

assert_eq "$(python3 "$BRS" short "$st" --fallback-file "$fb")" \
  "brief 리뷰 경고 5개: codex 건너뜀 ×2 · 냉독 못 돎 · 기록 못 한 경고 2" "short: 이름 · ×k · 두 번째 채널의 줄 수"
assert_eq "$(python3 "$BRS" short "$st")" \
  "brief 리뷰 경고 3개: codex 건너뜀 ×2 · 냉독 못 돎" "short: 두 번째 채널 없이도 낸다"
assert_eq "$(python3 "$BRS" short "$st" --fallback-file "$T/없는파일")" \
  "brief 리뷰 경고 3개: codex 건너뜀 ×2 · 냉독 못 돎" "short: 두 번째 채널 파일이 없으면 0줄"
assert_eq "$(python3 "$BRS" short "$empty")" "" "short: 기록이 없으면 빈 출력"
: > "$T/blank.txt"
assert_eq "$(python3 "$BRS" short "$empty" --fallback-file "$T/blank.txt")" "" "short: 두 번째 채널도 비면 빈 출력"
assert_eq "$(python3 "$BRS" short "$empty" --fallback-file "$fb")" \
  "brief 리뷰 경고 2개: 기록 못 한 경고 2" "short: 원장이 비어도 두 번째 채널만 있으면 낸다"
python3 "$BRS" short "$T/없는상태.md" >/dev/null 2>&1; assert_eq "$?" "1" "short: 원장을 못 읽으면 rc 1"
assert_contains "$(python3 "$BRS" short "$T/없는상태.md")" '"ok": false' "short: 못 읽으면 get 과 같은 실패 JSON"
finish
