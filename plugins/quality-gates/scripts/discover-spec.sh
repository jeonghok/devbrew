#!/usr/bin/env bash
# discover-spec.sh — 리뷰 기준의 의도 출처를 정한다(D13 사슬).
#
#   1. HEAD 쪽 커밋의 `Spec:` 트레일러가 가리키는 spec 파일
#   2. 없으면 브랜치 커밋 메시지(base..HEAD) + 열린 PR 본문(읽기 전용 `gh pr view`)
#
# 파일 mtime 은 읽지 않는다. gh 는 읽기만 한다 — 쓰기는 게시 sink 하나의 일이다.
#
# 사용 (리포 루트에서):
#   discover-spec.sh --intent-out <file> [--base <sha>]
#
# stdout 한 줄 JSON:
#   {"spec_path": "<abs|''>", "intent_source": "spec-trailer|commits+pr|commits",
#    "intent_note": "''|gh 없음|열린 PR 없음|gh 오류", "intent_file": "<abs>"}
# `spec_path` 는 `spec-trailer` 일 때만 값이 있다(차등 테스트의 test-scope-validator 입력).
# 의도 본문은 <file> 에 쓴다.
#
# exit: 0 정상 · 2 잘못된 호출 · 3 <file> 에 쓸 수 없음.
set -u

OUT=""
BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --intent-out) [ $# -ge 2 ] || { echo "discover-spec.sh: --intent-out 에 경로가 필요하다" >&2; exit 2; }
                  OUT="$2"; shift 2 ;;
    --base)       [ $# -ge 2 ] || { echo "discover-spec.sh: --base 에 sha 가 필요하다" >&2; exit 2; }
                  BASE="$2"; shift 2 ;;
    *) echo "discover-spec.sh: 알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || { echo "discover-spec.sh: --intent-out 은 필수다" >&2; exit 2; }
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
: > "$OUT" 2>/dev/null || { echo "discover-spec.sh: 의도 파일에 쓸 수 없다: $OUT" >&2; exit 3; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "$BASE" ]; then
  BASE="$(bash "$HERE/resolve-baseline.sh" 2>/dev/null | sed -n 's/^merge_base: //p')"
  [ "$BASE" = "-" ] && BASE=""
fi
if [ -n "$BASE" ]; then RANGE="$BASE..HEAD"; else RANGE="-1"; fi

emit() {  # emit <spec_path> <intent_source> <intent_note>
  python3 -c 'import json, sys; print(json.dumps({"spec_path": sys.argv[1], "intent_source": sys.argv[2], "intent_note": sys.argv[3], "intent_file": sys.argv[4]}, ensure_ascii=False))' \
    "$1" "$2" "$3" "$OUT"
}

# ── 1. Spec: 트레일러 (새 커밋부터) ───────────────────────────────────
# `%B` + `^Spec: ` 는 resolve-topic.sh 와 같은 추출 계열이다.
top="$(git rev-parse --show-toplevel 2>/dev/null)"
for h in $(git log --format='%H' $RANGE 2>/dev/null); do
  v="$(git log -1 --format='%B' "$h" | grep -E '^Spec: ' | tail -1 | sed -E 's/^Spec: //')"
  v="${v%%#*}"
  [ -n "$v" ] || continue
  if [ -n "$top" ] && [ -f "$top/$v" ]; then
    cat "$top/$v" > "$OUT"
    emit "$top/$v" "spec-trailer" ""
    exit 0
  fi
  break
done

# ── 2. 커밋 메시지 + 열린 PR 본문 ─────────────────────────────────────
{
  echo "## 커밋 메시지"
  git log --format='- %h %s%n%w(0,2,2)%b' $RANGE 2>/dev/null
} > "$OUT"

# gh 는 `pr view` 하나만 부른다. 실패는 그 출력으로만 가른다 — 「PR 없음」 문구면 열린 PR 없음,
# 그 밖(미인증 · 원격 없음 · 네트워크)은 전부 gh 오류다. 종료 코드의 뜻은 판정에 쓰지 않는다.
note=""
if ! command -v gh >/dev/null 2>&1; then
  note="gh 없음"
else
  pr_err="$(mktemp)"
  state="$(gh pr view --json state -q .state 2>"$pr_err")"; prc=$?
  if [ "$prc" -ne 0 ]; then
    if grep -qi 'no pull requests found' "$pr_err"; then note="열린 PR 없음"; else note="gh 오류"; fi
  elif [ "$state" != "OPEN" ]; then
    note="열린 PR 없음"
  elif ! pr="$(gh pr view --json body -q .body 2>/dev/null)"; then
    note="gh 오류"
  fi
  rm -f "$pr_err"
fi
if [ -z "$note" ]; then
  { echo; echo "## PR 본문"; printf '%s\n' "$pr"; } >> "$OUT"
  emit "" "commits+pr" ""
else
  emit "" "commits" "$note"
fi
exit 0
