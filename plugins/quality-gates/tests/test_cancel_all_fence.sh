#!/usr/bin/env bash
# guards: plugins/quality-gates/commands/cancel-qg.md
# `/cancel-qg --all` 의 삭제 펜스(commands/cancel-qg.md 「## `--all`」 절 3단계)를 문서에서 잘라
# 임시 저장소에서 실제로 돌린다. 저장소가 `.claude` 나 `.claude/quality-gates` 를 링크로 커밋해도
# 그 너머(저장소 밖)를 지우지 않고 거부 토큰을 내야 한다. 정상 루트는 지운다(양성 짝).
# 심는 링크 · 희생 디렉토리는 전부 이 테스트의 임시 디렉토리 `P` 안이고, 펜스를 돌리기 전에 링크가
# `P` 안으로 풀리는지 확인한다.
set -u
# 위 `# guards:` 선언의 짝 — 이 테스트가 읽는 파일은 명령 문서 하나다.
[ "${1:-}" = "--emit-scanned" ] && { echo "plugins/quality-gates/commands/cancel-qg.md"; exit 0; }
HERE="$(cd "$(dirname "$0")" && pwd)"
CMD="$HERE/../commands/cancel-qg.md"
pass=0; fail=0
ok() { echo "  ✓ $1"; pass=$((pass + 1)); }
no() { echo "  ✗ $1"; fail=$((fail + 1)); }

P="$(mktemp -d -t qg-cancel-all-XXXXXX)" || exit 1
[ -n "$P" ] && [ -d "$P" ] || { echo "mktemp 실패"; exit 1; }
case "$P" in /private/var/*|/var/*|/tmp/*|/private/tmp/*) ;; *) echo "예상 밖 임시 경로: $P"; exit 1 ;; esac
trap 'rm -rf "$P"' EXIT
PR="$(cd "$P" && pwd -P)"

# 「## `--all`」 절 안에서 `REMOVED_ALL` 을 담은 ```! 펜스의 본문만 뜬다(들여쓰기 제거).
FENCE="$P/fence.sh"
awk '
  /^## `--all`/ { sec = 1; next }
  sec && /^## / { sec = 0 }
  sec && /^[[:space:]]*```!/ { inb = 1; buf = ""; next }
  sec && inb && /^[[:space:]]*```/ { inb = 0; if (buf ~ /REMOVED_ALL/) { printf "%s", buf; exit } ; next }
  sec && inb { sub(/^   /, ""); buf = buf $0 "\n" }
' "$CMD" > "$FENCE"
if grep -q 'REMOVED_ALL' "$FENCE" && grep -q 'rm -rf' "$FENCE"; then
  ok "추출: --all 삭제 펜스를 떴다"
else
  no "추출: --all 삭제 펜스를 못 떴다 — 아래 판정은 무의미하다"; cat "$FENCE"
fi
run_fence() { ( cd "$1" && bash "$FENCE" ) 2>&1; }
inside() { case "$(cd "$1" 2>/dev/null && pwd -P)" in "$PR"/*) return 0 ;; *) echo "링크가 P 밖으로 풀린다: $1"; exit 1 ;; esac; }

# 1) 정상 루트 — 지운다(양성 짝)
mkdir -p "$P/r1/.claude/quality-gates/sess00000001"
out="$(run_fence "$P/r1")"
[[ "$out" == *REMOVED_ALL* && ! -e "$P/r1/.claude/quality-gates" ]] \
  && ok "정상 루트: 지웠다 (REMOVED_ALL)" || no "정상 루트: 안 지웠다 — out=[$out]"

# 2) `.claude` 자신이 링크 — 그 너머의 진짜 quality-gates 를 지우면 안 된다
mkdir -p "$P/victim2/quality-gates/keep" "$P/r2"
echo precious > "$P/victim2/quality-gates/keep/file.txt"
ln -s ../victim2 "$P/r2/.claude"
inside "$P/r2/.claude"
out="$(run_fence "$P/r2")"
[[ -f "$P/victim2/quality-gates/keep/file.txt" ]] \
  && ok ".claude 링크: 링크 너머를 지우지 않았다" || no ".claude 링크: 링크 너머의 quality-gates 를 지웠다 — out=[$out]"
[[ "$out" == *REFUSED* ]] && ok ".claude 링크: 거부 토큰" || no ".claude 링크: 거부 토큰이 없다 — out=[$out]"

# 3) `.claude/quality-gates` 자신이 링크 — 너머를 지우면 안 된다
mkdir -p "$P/victim3/keep" "$P/r3/.claude"
echo precious > "$P/victim3/keep/file.txt"
ln -s ../../victim3 "$P/r3/.claude/quality-gates"
inside "$P/r3/.claude/quality-gates"
out="$(run_fence "$P/r3")"
[[ -f "$P/victim3/keep/file.txt" ]] \
  && ok "루트 링크: 링크 너머를 지우지 않았다" || no "루트 링크: 링크 너머를 지웠다 — out=[$out]"
[[ "$out" == *REFUSED* ]] && ok "루트 링크: 거부 토큰" || no "루트 링크: 거부 토큰이 없다 — out=[$out]"

# 4) 루트가 없다 — 지울 것 없음
mkdir -p "$P/r4"
out="$(run_fence "$P/r4")"
[[ "$out" == *NOTHING_TO_DELETE* ]] && ok "루트 없음: NOTHING_TO_DELETE" || no "루트 없음: out=[$out]"

echo ""
echo "Total: $((pass + fail)) | Pass: $pass | Fail: $fail"
[ "$fail" -eq 0 ]
