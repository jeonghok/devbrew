#!/usr/bin/env bash
# capture_finalize_golden.sh — `cmd_finalize` 의 실제 산출물(있는 그대로의 `fin.json` 과
# 그 결과 `docreview-state.md`)을 대표 케이스 셋에서 그대로 뽑아 golden/ 에 고정한다.
#
# 왜 assert 통과/실패 줄이 아니라 이 둘인가 — `test_docreview_route.sh` 가 이미 이
# 케이스 셋을 매번 돌리고 그 assert 줄을 이미 찍는다(assert.sh 의 ok() 는 성공 시
# 고정 메시지만 찍는다). 통과/실패 줄만 고정한 골든은 그 출력의 부분집합이라 —
# route.sh 가 잡는 회귀는 이 골든도 항상 잡고, route.sh 가 못 잡는 회귀는 이 골든도
# 못 잡는다(리뷰 실측: `diff` 가 완전히 일치). AC26 이 필요한 것은 어떤 assert 도
# 안 읽는 필드(`by_disposition`·`rejected`·`defers`·`degrade`·`advisory`·`blocks`·
# `adjudication_*`)까지 분해가 안 건드렸다는 증거다 — 그건 `finalize` 의 실제 JSON
# 출력과 그 결과 state 파일 자체를 고정해야만 잡힌다.
#
# 왜 이 스크립트가 따로 있나 — cases.sh 의 각 케이스는 끝에 `rm -rf "$d" ...` 로
# 자기 임시 디렉토리를 지운다(cases.sh 헤더의 계약). 케이스 «몸통» 을 고치면(다른
# 시퀀스를 걷게 만들면) 이 골든은 route.sh 가 도는 것과 다른 것을 재게 된다 — 그래서
# 케이스는 원본 그대로 두고, 지우기 직전의 산출물만 가로챈다: `rm` 을 이 스크립트의
# 함수 스코프에서만 shadow 해 상태 디렉토리(그 안에 `docreview-state.md` 가 있는
# 인자)를 알아보고 실제 삭제 «전에» 복사한 뒤 진짜 `rm` 을 그대로 부른다.
#
# 사용: shared/tests/fixtures/docreview/capture_finalize_golden.sh [출력 디렉토리]
#       (기본 출력 = 이 파일과 같은 디렉토리의 golden/). 판정하는 락은 형제
#       `shared/tests/test_docreview_golden.sh` 다 — 그것이 이 스크립트를 임시
#       디렉토리로 돌려 committed golden 과 diff 한다. 골든을 갱신할 때만 인자 없이
#       직접 부른다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$HERE/../../../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
OUT="${1:-$HERE/golden}"
export PYTHONDONTWRITEBYTECODE=1
mkdir -p "$OUT"
. "$REPO_ROOT/shared/tests/assert.sh"
. "$HERE/cases.sh"

# ── 절대경로 정규화 ────────────────────────────────────────────────────────
# `docreview-state.md` 의 `doc:`·`profile:` 두 줄은 이 체크아웃의 `$REPO_ROOT` 를
# 그대로 담는다. 정규화하지 않으면 골든은 **다른 클론·워크트리·CI 에서 구조적으로
# RED** 다 — 그것도 언제나, 그 두 줄에서만. 그러면 첫 실패가 「회귀」가 아니라
# 「환경이 다름」이라 다음 사람이 락을 끄게 된다.
#
# `sed` 가 아니라 python 리터럴 치환인 이유 — 경로에 `|`·`&`·`/` 가 들어오면 sed 는
# 구분자/치환 메타문자로 조용히 오작동한다. 인코딩도 명시한다(non-UTF-8 locale 에서
# fail-open 하지 않게).
GOLDEN_PLACEHOLDER='<REPO_ROOT>'
# 라운드 시작 표식(`started_mtime_ns`)은 실행마다 다른 파일시스템 시각이다 — 같은 이유로
# 자리표로 바꾼다. 줄 자체는 남기므로 표식이 사라지면 골든이 여전히 RED 다.
norm_copy() {   # norm_copy <src> <dst> — REPO_ROOT 절대경로·라운드 시작 표식을 안정 placeholder 로
  python3 -c 'import io, re, sys
src, dst, root, ph = sys.argv[1:5]
t = io.open(src, encoding="utf-8").read().replace(root + "/", ph + "/")
t = re.sub(r"(?m)^(\s*started_mtime_ns: )[0-9]+$", r"\g<1><MTIME_NS>", t)
io.open(dst, "w", encoding="utf-8").write(t)' \
    "$1" "$2" "$REPO_ROOT" "$GOLDEN_PLACEHOLDER"
}

# capture_and_run <case-fn> — `rm` 을 이 함수 호출 동안만 재정의해 케이스가 스스로
# 지우기 직전에 fin.json·docreview-state.md 를 가로챈다. 케이스는 매번 상태 디렉토리
# 하나(+ 부수적인 임시 파일들)를 `rm -rf` 하나로 지우므로, 인자 중 디렉토리이고
# `docreview-state.md` 를 담은 것만 상태 디렉토리로 식별한다.
capture_and_run() {
  local casefn="$1"
  rm() {
    local arg
    for arg in "$@"; do
      case "$arg" in -*) continue ;; esac
      if [ -d "$arg" ] && [ -f "$arg/docreview-state.md" ]; then
        [ -f "$arg/fin.json" ] && norm_copy "$arg/fin.json" "$OUT/$casefn.fin.json"
        norm_copy "$arg/docreview-state.md" "$OUT/$casefn.state.md"
      fi
    done
    command rm "$@"
  }
  "$casefn" >/dev/null 2>&1
  unset -f rm
}

for c in case_T11_permit_keeps_disposition case_T22_reraise_appears_in_next_round case_T05_T06_reject; do
  capture_and_run "$c"
done
echo "captured: $(ls "$OUT"/*.fin.json "$OUT"/*.state.md 2>/dev/null | wc -l | tr -d ' ') files -> $OUT"
