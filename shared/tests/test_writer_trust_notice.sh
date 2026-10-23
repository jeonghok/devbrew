#!/usr/bin/env bash
# guards: shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/cases.sh shared/tests/fixtures/docreview/design-sample.md plugins/spec-distill/README.md plugins/quality-gates/README.md plugins/spec-distill/skills/request-framing/* plugins/spec-distill/skills/reviewing-brief/* plugins/spec-distill/skills/spec-review/*
# 쓰는 세션을 믿는 한계의 공시 — 리뷰 결과 머리 한 줄과 README 「한계」 절이 같은 문장이다.
#  · 게이트 렌더의 셋째 줄이 엔진 상수 WRITER_TRUST_NOTICE 이고, 둘째 줄은 그대로 재리뷰 줄이다(양의 짝).
#    행 묶음은 공시 뒤에 온다 — 공시가 행으로 읽히지 않는다.
#  · `gate` JSON 에 같은 글이 `writer_trust_notice` 로 있다.
#  · spec-distill README `## 한계` 절의 첫 줄이 같은 문장이다(엔진 상수에서 읽어 비교). 상태 폴더 링크(P21) ·
#    원장 정리 뿌리(P14) 한계 불릿은 그 절에 있고 `### Principles 흡수` 에는 없다.
#  · 인용마다 다는 「출처 미확인」 라벨은 엔진 출력 · 진입 skill 셋 어디에도 없다.
#  · quality-gates README `## 한계` 에 「선택 N」 칸 한 줄이 있다.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then
  cd "$(dirname "$0")/../.." || exit 1
  printf '%s\n' shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/cases.sh \
    shared/tests/fixtures/docreview/design-sample.md plugins/spec-distill/README.md plugins/quality-gates/README.md
  git ls-files -- plugins/spec-distill/skills/request-framing plugins/spec-distill/skills/reviewing-brief plugins/spec-distill/skills/spec-review
  exit 0
fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
SCRIPTS="${SCRIPTS:-$REPO_ROOT/plugins/spec-distill/scripts}"
. "$HERE/fixtures/docreview/cases.sh"
SD_README="$REPO_ROOT/plugins/spec-distill/README.md"
QG_README="$REPO_ROOT/plugins/quality-gates/README.md"
LABEL='출처 미확인'
EXPECTED='리뷰 기록과 그 안의 사용자 말은 이 대화가 직접 쓴다 — 기록을 리뷰 명령 밖에서 고치면 확인값이 안 맞는 경우만 잡히고, 확인값까지 맞춰 그럴듯하게 고친 것은 잡히지 않는다'

section() { awk -v h="$2" '$0 == h {on=1; print; next} on && /^## /{exit} on' "$1"; }
subsection() { awk -v h="$2" '$0 == h {on=1; print; next} on && /^#/{exit} on' "$1"; }

NOTICE="$(python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import docreview_state as m; print(m.WRITER_TRUST_NOTICE)' "$SCRIPTS" 2>/dev/null)"
assert_eq "$NOTICE" "$EXPECTED" "엔진 상수 WRITER_TRUST_NOTICE 가 설계 문장 그대로다"

for w in 원장 엔진 요약값; do
  assert_not_contains "$NOTICE" "$w" "엔진 상수: 「${w}」 가 없다 — 쉬운 말이다"
done

# ── 게이트 렌더 — 셋째 줄 · 둘째 줄 · 행 묶음 자리 ─────────────────────────────
d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"
out="$(py docreview_state.py gate --state-dir "$d" --render)"
assert_eq "$(printf '%s\n' "$out" | sed -n 3p)" "$EXPECTED" "렌더(빈 라운드): 셋째 줄이 공시 문장이다"
case "$(printf '%s\n' "$out" | sed -n 2p)" in "재리뷰 "*) ok "렌더(빈 라운드): 둘째 줄은 그대로 재리뷰 줄이다" ;;
  *) no "렌더(빈 라운드): 둘째 줄이 재리뷰 줄이 아니다 — $(printf '%s\n' "$out" | sed -n 2p)" ;; esac
assert_eq "$(printf '%s\n' "$out" | grep -cxF "$EXPECTED")" "1" "렌더(빈 라운드): 공시 줄은 한 번만 나온다"
assert_not_contains "$out" "$LABEL" "렌더(빈 라운드): 인용 라벨 「${LABEL}」 이 없다"
js="$(py docreview_state.py gate --state-dir "$d")"
jn="$(printf '%s' "$js" | python3 -I -c 'import json, sys; print(json.load(sys.stdin).get("writer_trust_notice", ""))')"
assert_eq "$jn" "$EXPECTED" "gate JSON: writer_trust_notice 가 공시 문장이다"
assert_not_contains "$js" "$LABEL" "gate JSON: 인용 라벨 「${LABEL}」 이 없다"
rm -rf "$d"

d="$(r1 "$PROF_SD/design-doc.md" "$FX/design-sample.md")"; seed_findings "$d" "[$F_DEC]"
out="$(py docreview_state.py gate --state-dir "$d" --render)"
assert_eq "$(printf '%s\n' "$out" | sed -n 3p)" "$EXPECTED" "렌더(열린 결정): 셋째 줄이 공시 문장이다"
case "$(printf '%s\n' "$out" | sed -n 2p)" in "재리뷰 "*) ok "렌더(열린 결정): 둘째 줄은 그대로 재리뷰 줄이다" ;;
  *) no "렌더(열린 결정): 둘째 줄이 재리뷰 줄이 아니다" ;; esac
assert_eq "$(printf '%s\n' "$out" | sed -n 4p)" "정할 것 1개" "렌더(열린 결정): 행 묶음 제목은 공시 바로 다음 줄이다"
assert_not_contains "$out" "$LABEL" "렌더(열린 결정): 인용 라벨 「${LABEL}」 이 없다"
rm -rf "$d"

# 게이트 행 표는 공시와 무관하다 — 행 수가 그대로다
nrows="$(py docreview_state.py gate-rows | python3 -I -c 'import json, sys; print(len(json.load(sys.stdin)))')"
assert_eq "$nrows" "10" "gate-rows: 행 수가 10 그대로다"

# ── 진입 skill 셋 — 인용 라벨이 없다 ───────────────────────────────────────────
for s in request-framing reviewing-brief spec-review; do
  sd="$REPO_ROOT/plugins/spec-distill/skills/$s"
  if [ -f "$sd/SKILL.md" ]; then ok "진입 skill 실재: $s"; else no "진입 skill 이 없다: $s — 아래 부재 단언이 공허하다"; fi
  hit="$(grep -rlF -- "$LABEL" "$sd" 2>/dev/null || true)"
  assert_eq "$hit" "" "진입 skill $s: 인용 라벨 「${LABEL}」 이 없다"
done

# 공시 문장은 진입 skill 셋 어디에도 옮겨 적히지 않는다(렌더 셋째 줄이 유일한 자리)
for s in request-framing reviewing-brief spec-review; do
  hit="$(grep -rlF -- "$NOTICE" "$REPO_ROOT/plugins/spec-distill/skills/$s" 2>/dev/null || true)"
  assert_eq "$hit" "" "진입 skill $s: 공시 문장이 없다"
done

# ── spec-distill README `## 한계` ─────────────────────────────────────────────
lim="$(section "$SD_README" '## 한계')"
[ -n "$lim" ] && ok "spec-distill README 에 ## 한계 절이 있다" || no "spec-distill README 에 ## 한계 절이 없다"
first="$(printf '%s\n' "$lim" | sed 1d | grep -m1 -v '^[[:space:]]*$')"
if [ -n "$NOTICE" ] && [ "$first" = "$NOTICE" ]; then
  ok "README ## 한계: 절의 첫 줄이 엔진 상수와 같은 문장이다"
else
  no "README ## 한계: 절의 첫 줄이 엔진 상수와 다르다 — 두 글이 어긋났거나 공시가 첫 줄이 아니다 — 첫 줄: $first"
fi
order="$(grep -nE '^## (끄는 법|한계|Prerequisites)$' "$SD_README" | sed 's/^[0-9]*:## //' | tr '\n' '|')"
assert_eq "$order" "끄는 법|한계|Prerequisites|" "README: ## 한계 는 ## 끄는 법 다음 · ## Prerequisites 앞이다"
assert_contains "$lim" '샌드박스를 쓰는 사용자는 리뷰 기록 폴더(상태 폴더의 `.docreview/`) 쓰기를 막을 수 있다 — 막아도 리뷰 명령은 같은 폴더를 쓰므로 리뷰 명령도 함께 막힌다' \
  "README ## 한계: 샌드박스 안내 줄"
assert_contains "$lim" '`--quote-file` · `log-decision --quote` · `decide --quote`' "README ## 한계: 인용 출처 줄"
assert_contains "$lim" '`declare-related` · `log-decision` 이 표지 확인 없이 불리거나 리뷰 명령을 거치지 않고 리뷰 기록을 쓰는 길도 위 공시로 다룬다 — 리뷰 명령은 그런 쓰기를 거부하지 않는다' \
  "README ## 한계: 엔진 밖 원장 쓰기 줄"
P21='- **한계 — 상태 폴더 쓰기의 링크 (P21)** — 펜스의 상태 폴더 쓰기는 writer(`scripts/nofollow_write.py`)를 거쳐 링크를 따라가지 않는다. 다만 Write 도구로 쓰는 상태 폴더 파일(`said-*.txt` · `readback.txt` · `note-<id>.txt` · `critic*.txt` · `recritic.txt`)은 writer 로 감싸지 못하고, writer 는 마지막 경로 성분만 지키며, 실행 중 다시 심는 링크는 지키지 않는다. 러너의 `write_failclosed` · `_degrade_if_empty` 는 첫 쓰기 뒤라 그대로다.'
P14='- **한계 — 원장 정리의 뿌리 (P14)** — request-framing 의 원장 정리와 지휘자는 지금 작업 폴더 레포의 뿌리를 쓴다 — 다른 레포의 문서를 리뷰하는 동안에는 지금 작업 폴더 레포의 원장이 그때 정리되지 않는다.'
absorb="$(subsection "$SD_README" '### Principles 흡수')"
[ -n "$absorb" ] && ok "README: ### Principles 흡수 절이 있다" || no "README: ### Principles 흡수 절이 없다 — 아래 부재 단언이 공허하다"
H21='**한계 — 상태 폴더 쓰기의 링크 (P21)**'
H14='**한계 — 원장 정리의 뿌리 (P14)**'
for pair in "P21|$H21|$P21" "P14|$H14|$P14"; do
  tag="${pair%%|*}"; rest="${pair#*|}"; head="${rest%%|*}"; line="${rest#*|}"
  if printf '%s\n' "$lim" | grep -qxF -- "$line"; then ok "README ## 한계: $tag 한계 불릿이 글 그대로 있다"
  else no "README ## 한계: $tag 한계 불릿이 없거나 글이 바뀌었다"; fi
  assert_not_contains "$absorb" "$head" "README ### Principles 흡수: $tag 한계 불릿이 남지 않았다"
done
assert_contains "$absorb" '한계는 `## 한계` 절' "README ### Principles 흡수: 한계 절을 가리키는 한 줄"

# ── quality-gates README `## 한계` ─────────────────────────────────────────────
qlim="$(section "$QG_README" '## 한계')"
assert_contains "$qlim" '판정 줄의 「선택 N」 칸은 합성기가 낸 인자를 묶지 않고 옮긴다 — 같은 세션이 낮춰 적을 수 있다. 판정값(통과 · 막음)은 이 칸에 기대지 않는다' \
  "qg README ## 한계: 「선택 N」 칸 줄"

finish
