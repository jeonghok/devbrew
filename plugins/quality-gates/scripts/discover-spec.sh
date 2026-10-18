#!/usr/bin/env bash
# discover-spec.sh — 리뷰 기준의 의도 출처를 정한다(D13 사슬).
#
#   1. 범위 안 커밋의 `Spec:` 트레일러가 가리키는 설계문서 전부(커밋 순서 — 오래된 것 먼저,
#      같은 경로는 한 번, 한 커밋의 `Spec:` 줄이 여럿이면 전부)
#   2. 없으면 범위 안 커밋 메시지 + 열린 PR 본문(읽기 전용 `gh pr view` — 범위 모드에서는 안 읽는다)
#
# 범위: `--range <시작> <끝>` 이면 `<시작>..<끝>` 이고 설계문서는 <끝> 커밋의 트리에서 읽는다
# (작업 트리와 무관 — 보통 파일 blob 만, 링크 · 없음은 거부). 아니면 `--base`(없으면 merge-base)
# 부터 HEAD 까지이고 설계문서는 HEAD 에서 읽는다.
#
# 파일 mtime 은 읽지 않는다. gh 는 읽기만 한다 — 쓰기는 게시 sink 하나의 일이다.
#
# 사용 (리포 루트에서):
#   discover-spec.sh --intent-out <file> [--base <sha> | --range <start> <end>]
#
# stdout 한 줄 JSON:
#   {"intent_source": "spec-trailer|commits+pr|commits",
#    "intent_note": "''|gh 없음|열린 PR 없음|gh 오류|spec 경로 거부 <k>개|범위 모드 — PR 본문 안 읽음",
#    "intent_file": "<abs>", "specs": ["<의도에 실은 설계문서의 리포 상대 경로>", ...]}
# 의도 본문은 <file> 에 쓴다 — 설계문서가 하나면 그 내용 그대로, 둘 이상이면 문서마다
# `<!-- qg-spec <k>/<N>: <경로> -->` 줄 뒤 내용, 그 뒤 빈 줄.
#
# exit: 0 정상 · 2 잘못된 호출 · 3 <file> 에 쓸 수 없음.
set -u

OUT=""
BASE=""
R_START=""
R_END=""
RANGE_MODE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --intent-out) [ $# -ge 2 ] || { echo "discover-spec.sh: --intent-out 에 경로가 필요하다" >&2; exit 2; }
                  OUT="$2"; shift 2 ;;
    --base)       [ $# -ge 2 ] || { echo "discover-spec.sh: --base 에 sha 가 필요하다" >&2; exit 2; }
                  BASE="$2"; shift 2 ;;
    --range)      [ $# -ge 3 ] || { echo "discover-spec.sh: --range 에 시작 · 끝 커밋 둘이 필요하다" >&2; exit 2; }
                  R_START="$2"; R_END="$3"; RANGE_MODE=1; shift 3 ;;
    *) echo "discover-spec.sh: 알 수 없는 인자: $1" >&2; exit 2 ;;
  esac
done
[ -n "$OUT" ] || { echo "discover-spec.sh: --intent-out 은 필수다" >&2; exit 2; }
if [ -n "$RANGE_MODE" ]; then
  [ -z "$BASE" ] || { echo "discover-spec.sh: --base 와 --range 는 함께 쓸 수 없다" >&2; exit 2; }
  for c in "$R_START" "$R_END"; do
    case "$c" in ''|-*) echo "discover-spec.sh: --range 의 커밋 모양이 아니다: $c" >&2; exit 2 ;; esac
    git rev-parse -q --verify "$c^{commit}" >/dev/null 2>&1 \
      || { echo "discover-spec.sh: --range 의 커밋을 풀 수 없다: $c" >&2; exit 2; }
  done
fi
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
: > "$OUT" 2>/dev/null || { echo "discover-spec.sh: 의도 파일에 쓸 수 없다: $OUT" >&2; exit 3; }

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -n "$RANGE_MODE" ]; then
  RANGE="$R_START..$R_END"
else
  if [ -z "$BASE" ]; then
    BASE="$(bash "$HERE/resolve-baseline.sh" 2>/dev/null | sed -n 's/^merge_base: //p')"
    [ "$BASE" = "-" ] && BASE=""
  fi
  if [ -n "$BASE" ]; then RANGE="$BASE..HEAD"; else RANGE="-1"; fi
fi

SPECS=()
emit() {  # emit <intent_source> <intent_note> — specs 는 전역 SPECS(실은 순서)
  python3 -I -X utf8 -c 'import json, sys; print(json.dumps({"intent_source": sys.argv[1], "intent_note": sys.argv[2], "intent_file": sys.argv[3], "specs": sys.argv[4:]}, ensure_ascii=False))' \
    "$1" "$2" "$OUT" ${SPECS[@]+"${SPECS[@]}"}
}

# ── 1. Spec: 트레일러 (범위 안 전부, 오래된 커밋부터) ─────────────────
# `%B` + `^Spec: ` 는 resolve-topic.sh 와 같은 추출 계열이다.
top="$(git rev-parse --show-toplevel 2>/dev/null)"
root=""
[ -n "$top" ] && root="$(python3 -I -X utf8 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$top")"
WORK="$(mktemp -d)" || { echo "discover-spec.sh: 임시 폴더를 만들 수 없다" >&2; exit 3; }
trap 'rm -rf "$WORK"' EXIT
TAB="$(printf '\t')"
nrej=0
n=0
# take <rel> <읽기 명령…> — 같은 rel 은 처음 것만 싣는다. 읽기에 실패하면 거부로 센다.
take() {
  local rel="$1" s
  shift
  if [ "${#SPECS[@]}" -gt 0 ]; then
    for s in "${SPECS[@]}"; do [ "$s" = "$rel" ] && return 0; done
  fi
  if "$@" > "$WORK/$n" 2>/dev/null; then
    SPECS+=("$rel"); n=$((n + 1))
  else
    nrej=$((nrej + 1))
  fi
}
git log --reverse --format='%H' $RANGE 2>/dev/null > "$WORK/commits"
while IFS= read -r h; do
  git log -1 --format='%B' "$h" | grep -E '^Spec: ' | sed -E 's/^Spec: //' > "$WORK/trailers"
  while IFS= read -r v; do
    v="${v%%#*}"
    [ -n "$v" ] || continue
    # 트레일러는 커밋 메시지에서 온 비신뢰 입력이다 — 의도 파일은 리뷰어와 외부 codex 로 나가므로
    # 절대 경로 · `..` 성분 · 리포 밖으로 풀리는 심볼릭 링크는 읽지 않고 거부를 센다.
    # 거부는 그 트레일러만 버리고 다음 트레일러로 간다.
    case "/$v/" in
      //*|*/../*) nrej=$((nrej + 1)); continue ;;
    esac
    [ -n "$top" ] || continue
    if [ -n "$RANGE_MODE" ]; then
      while :; do case "$v" in ./*) v="${v#./}" ;; *) break ;; esac; done
      case "/$v/" in
        */.git/*) nrej=$((nrej + 1)); continue ;;
      esac
      # <끝> 트리의 보통 파일 blob(100644 · 100755)만 읽는다 — 링크(120000) · 디렉토리 · 없음은 거부.
      ent=""
      IFS= read -r -d '' ent < <(git -C "$top" ls-tree -z "$R_END" -- "$v" 2>/dev/null)
      mode="${ent%% *}"
      epath="${ent#*"$TAB"}"
      if [ -z "$ent" ] || [ "$epath" != "$v" ] || { [ "$mode" != "100644" ] && [ "$mode" != "100755" ]; }; then
        nrej=$((nrej + 1)); continue
      fi
      take "$v" git -C "$top" show "$R_END:$v"
      continue
    fi
    [ -f "$top/$v" ] || continue
    real="$(python3 -I -X utf8 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$top/$v")"
    case "$real" in
      "$root"/*) ;;
      *) nrej=$((nrej + 1)); continue ;;
    esac
    [ -f "$real" ] || continue
    rel="${real#"$root"/}"
    # `.git/` 는 추적 검사가 이미 막지만(HEAD 트리에 없다) 깊이 방어로 따로 거부한다.
    case "$rel" in
      .git|.git/*) nrej=$((nrej + 1)); continue ;;
    esac
    # 추적된 파일만, 객체 저장소에서 읽는다 — git-ignored(.env 등)·미추적 파일은 거부하고,
    # 확인과 읽기 사이의 바꿔치기(TOCTOU)도 없다.
    take "$rel" git -C "$root" show "HEAD:$rel"
  done < "$WORK/trailers"
done < "$WORK/commits"

reject=""
[ "$nrej" -gt 0 ] && reject="spec 경로 거부 ${nrej}개"
if [ "$n" -gt 0 ]; then
  if [ "$n" -eq 1 ]; then
    cat "$WORK/0" > "$OUT"
  else
    : > "$OUT"
    k=0
    while [ "$k" -lt "$n" ]; do
      {
        printf '<!-- qg-spec %d/%d: %s -->\n' "$((k + 1))" "$n" "${SPECS[$k]}"
        cat "$WORK/$k"
        [ -z "$(tail -c 1 "$WORK/$k")" ] || echo
        echo
      } >> "$OUT"
      k=$((k + 1))
    done
  fi
  emit "spec-trailer" "$reject"
  exit 0
fi

# ── 2. 커밋 메시지 + 열린 PR 본문 ─────────────────────────────────────
{
  echo "## 커밋 메시지"
  git log --format='- %h %s%n%w(0,2,2)%b' $RANGE 2>/dev/null
} > "$OUT"

# 범위 모드는 열린 PR 이 없는 범위다 — gh 를 부르지 않고 그 사실을 싣는다.
if [ -n "$RANGE_MODE" ]; then
  emit "commits" "${reject:+$reject · }범위 모드 — PR 본문 안 읽음"
  exit 0
fi

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
  emit "commits+pr" "$reject"
else
  emit "commits" "${reject:-$note}"
fi
exit 0
