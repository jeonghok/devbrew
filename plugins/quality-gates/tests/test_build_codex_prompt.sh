#!/usr/bin/env bash
# test_build_codex_prompt.sh — AC9: codex 프롬프트가 다른 리뷰어와 같은 의도 출처와 기준 블록을 싣는다.
#
# 의도 파일이 일반 파일이 아니면(/dev/null — 의도 없음 · DISABLE_SPEC_CONFORMANCE) 빈 <intent> 로
# 가야 하고 오류가 아니어야 한다 — 오류면 codex 리뷰가 prompt_build_failed 로 조용히 빠진다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
BUILD="$PLUGIN_ROOT/scripts/build_codex_prompt.py"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
printf 'diff --git a b\n+added line\n' > "$T/diff"
printf '## 커밋 메시지\n- abc123 캐시 무효화만 고친다\n' > "$T/intent"
CRIT_LINE="$(sed -n '/^- /{p;q;}' "$PLUGIN_ROOT/references/review-criteria.md")"
[ -n "$CRIT_LINE" ] && ok "전제: 기준 블록의 첫 항목 줄을 읽었다" || no "전제: references/review-criteria.md 에 항목 줄이 없다"

# 1 — 의도 없음(/dev/null) → exit 0, 빈 <intent>, 기준 블록은 그대로
out="$(python3 "$BUILD" "$T/diff" /dev/null 2>/dev/null)"; rc=$?
assert_eq "$rc" "0" "의도 없음(/dev/null) → exit 0"
assert_contains "$out" '+added line' "diff 가 실린다"
assert_contains "$out" '<intent>' "intent 블록이 있다"
assert_not_contains "$out" '캐시 무효화만' "의도 없음이면 의도 본문이 없다"
assert_contains "$out" "$CRIT_LINE" "기준 블록이 실린다 — 다른 리뷰어와 같은 글자"

# 2 — 의도 파일 → 본문이 실린다
out2="$(python3 "$BUILD" "$T/diff" "$T/intent" 2>/dev/null)"; rc2=$?
assert_eq "$rc2" "0" "의도 파일 → exit 0"
assert_contains "$out2" '캐시 무효화만 고친다' "의도 본문이 실린다"
assert_not_contains "$out2" '"confidence"' "출력 스키마에 confidence 가 없다"

# 3 — diff 부재 → exit 2
python3 "$BUILD" /nonexistent-qg-diff-xyz "$T/intent" >/dev/null 2>&1
assert_eq "$?" "2" "diff 부재 → exit 2"

# 4 — 기준 블록 부재 → exit 2 (빈 기준으로 조용히 돌지 않는다)
mkdir -p "$T/root/scripts"
cp "$BUILD" "$PLUGIN_ROOT/scripts/codex_prompt_common.py" "$T/root/scripts/"
cp -L "$PLUGIN_ROOT/scripts/prompt-preamble.md" "$T/root/scripts/"
python3 "$T/root/scripts/build_codex_prompt.py" "$T/diff" "$T/intent" >/dev/null 2>&1
assert_eq "$?" "2" "기준 블록이 없으면 exit 2"

finish
