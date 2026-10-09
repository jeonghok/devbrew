#!/usr/bin/env bash
# guards: shared/docreview/scripts/*.py shared/tests/fixtures/docreview/**
#
# 골든 락 — `cmd_finalize` 의 **실제 산출물**(`fin.json` + 그 결과 `docreview-state.md`)이
# 고정값과 바이트로 같은가. 대표 케이스 셋을 `capture_finalize_golden.sh` 로 다시 떠서
# committed `golden/` 과 `diff` 한다.
# `gate` JSON · `gate --render` 도 고정한다 — must_catch 가 없는 프로필의 finalize 보고서와 게이트 렌더가
# 변경 전과 바이트 동일하다(설계 2026-09-27-review-stopping-criterion AC3). 케이스는 must_catch 를 뺀 사본
# 프로필로 돈다(`nofield_profiles.sh`) — 원장의 `profile:` 줄은 캡처가 정본 경로로 되돌린다.
#
# ── 왜 케이스 스위트로는 부족한가 ─────────────────────────────────────────
# 케이스 스위트의 단언이 **읽지 않는** 출력 필드(`by_disposition`·`defers`·`advisory`·
# `blocks`·`adjudication_*`)의 회귀는 그 스위트가 원리적으로 못 본다. 실측: `_build_report`
# 의 `"defers"` 한 줄을 지우면 골든 세 파일이 전부 깨지는데 그 세 케이스의 단언은 0 fail 이다
# (`test_docreview_route.sh` 전체로는 1건 RED 가 나지만 그것은 골든 밖 케이스 T08 이다).
#
# ── 왜 이 파일이 따로 있는가 ──────────────────────────────────────────────
# 골든을 **사람이 기억해서 돌리는 스크립트**로만 두면 락이 아니다. 리뷰가 골든 6파일과
# 캡처 스크립트를 통째로 지우고 전체 스위트를 돌렸더니 **전부 GREEN** 이었다 — 어떤 락도
# 그것을 안 읽고 있었다. 이 파일이 그 배선이고, 아래 «코퍼스 하한»이 같은 삭제를 다시
# 잡는다(부재 락은 코퍼스를 통째로 지우면 공허하게 통과한다 — 하한이 그 짝이다).
#
# ── `--emit-scanned` 의 분담 ──────────────────────────────────────────────
# 이 락이 `golden/**` 과 `capture_finalize_golden.sh` 를 **실제로 읽는** 유일한 락이다.
# 형제 `test_docreview_mutations.sh` 는 그 일곱을 한 번도 안 읽으므로 자기 emit 에서 뺐다
# (선언 ⊃ 실제 = 「선택은 되는데 아무것도 안 본다」). 둘을 합쳐야 선언과 실제가 맞는다.
if [ "${1:-}" = "--emit-scanned" ]; then
  git ls-files -- 'shared/docreview/scripts/*.py'
  bash "$(dirname "$0")/docreview_fixture_corpus.sh"
  # 도출기가 형제들을 위해 빼 둔 일곱 — 이 락만 실제로 읽으므로 이 락만 더한다.
  git ls-files -- 'shared/tests/fixtures/docreview/golden/*' \
                  'shared/tests/fixtures/docreview/capture_finalize_golden.sh'
  exit 0
fi
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
FX="$REPO_ROOT/shared/tests/fixtures/docreview"
GOLDEN="$FX/golden"
CAPTURE="$FX/capture_finalize_golden.sh"
CASES="case_T11_permit_keeps_disposition case_T22_reraise_appears_in_next_round case_T05_T06_reject case_plain_render_nothing_left case_plain_render_fix_and_decide"
export PYTHONDONTWRITEBYTECODE=1

OUT="$(mktemp -d -t docreview-golden-XXXXXX)" || exit 1
trap 'rm -rf "$OUT"' EXIT

# ── 코퍼스 하한 — 「지우면 조용히 통과」를 막는다 ──────────────────────────
if [ ! -f "$CAPTURE" ]; then
  no "캡처 스크립트가 없다: $CAPTURE (골든을 뜰 수단이 사라졌다)"
  finish; exit
fi
ok "캡처 스크립트 실재"

n_golden=0
for f in "$GOLDEN"/*.fin.json "$GOLDEN"/*.state.md "$GOLDEN"/*.gate.json "$GOLDEN"/*.gate.txt; do
  [ -f "$f" ] && n_golden=$((n_golden+1))
done
if [ "$n_golden" -lt 20 ]; then
  no "골든 파일이 ${n_golden}개 — 케이스 다섯 × 산출물 넷(fin.json · state.md · gate.json · gate.txt)이면 20개여야 한다. 하한 미달이면 이 락은 공허하다"
  finish; exit
fi
ok "골든 코퍼스 ${n_golden}개 (하한 20 충족 — 공허하지 않다)"

# ── 이식성 — 이 체크아웃의 절대경로가 골든에 남으면 다른 클론에서 구조적 RED ──
if grep -q -- "$REPO_ROOT" "$GOLDEN"/*.state.md "$GOLDEN"/*.fin.json "$GOLDEN"/*.gate.json "$GOLDEN"/*.gate.txt 2>/dev/null; then
  no "골든에 이 체크아웃의 절대경로가 남아 있다 — 캡처의 정규화가 죽었다 (다른 클론·CI 에서 항상 RED 가 된다)"
else
  ok "골든에 이 체크아웃의 절대경로 없음"
fi
# 위 부재 검사의 **양의 짝** — placeholder 가 실제로 있어야 한다. 없으면 부재 검사는
# 「정규화가 돈다」가 아니라 「그 줄 자체가 사라졌다」에도 통과한다.
assert_file_grep "$GOLDEN/case_T05_T06_reject.state.md" '<REPO_ROOT>/' \
  "정규화 placeholder 가 골든에 실재 (부재 검사의 양의 짝)"

# ── 재캡처 + 바이트 동치 ──────────────────────────────────────────────────
bash "$CAPTURE" "$OUT" >/dev/null 2>&1
cap_rc=$?
assert_eq "$cap_rc" "0" "재캡처 실행 성공 (rc=0)"

for c in $CASES; do
  for k in fin.json state.md gate.json gate.txt; do
    g="$GOLDEN/$c.$k"; a="$OUT/$c.$k"
    if [ ! -f "$g" ]; then no "골든 없음: $c.$k"; continue; fi
    if [ ! -f "$a" ]; then no "재캡처 산출 없음: $c.$k (캡처가 이 케이스를 못 잡았다)"; continue; fi
    if diff -q "$g" "$a" >/dev/null 2>&1; then
      ok "골든 동치: $c.$k"
    else
      no "골든 불일치: $c.$k — finalize 산출물이 바뀌었다. 의도한 변경이면 $CAPTURE 를 인자 없이 돌려 갱신하라"
      diff "$g" "$a" | head -30
    fi
  done
done

finish
