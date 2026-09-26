#!/usr/bin/env bash
# 생산자와 소비자를 **한 락에서 함께** 잰다.
#
# 2026-08-05 /qg 라운드 2가 드러낸 반쪽 수정: `synthesize_findings.py`의 render()가
# drop 공지를 내도록 고쳤고 그 락(`test_synthesize_promoted_findings.sh` 10/10b)도
# GREEN이었는데, **유일한 소비자인 SKILL은 그 줄을 읽지 않았다**. step 4.5가 counts
# line과 `No high-confidence findings…` 두 줄만 보고 분기했으므로, 버려진 CRITICAL
# 주장 위에 게이트가 `clean`을 찍었다. 스크립트만 재는 락은 이 seam을 볼 수 없다.
#
# 그래서 (a) 스크립트가 그 문구를 실제로 낸다 (b) SKILL이 그 문구를 소비하는 분기를
# 갖는다 (c) 두 문구가 같은 문자열이다 — 셋을 같이 건다. 하나만 어긋나도 RED다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
QG="$ROOT/plugins/quality-gates"
SKILL="$QG/skills/quality-pipeline/SKILL.md"
SCRIPT="$QG/scripts/synthesize_findings.py"
PLUGIN_ROOT="$QG"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
. "$(dirname "$0")/lib/recritic_fixture.sh"

tmp="$(mktemp -d -t qg-dropnotice-XXXXXX)" || exit 1
trap 'rc=$?; rm -rf "$tmp"; exit $rc' EXIT

# ── (a) 생산자 — 두 출처 모두에서 공지가 stdout에 나온다 ──────────────────────
# R-AD — 재비판 경로(recritic_bridge.to_adjudication_doc)는 added 항목의 file 이
# 없으면 「미지」로 채워 넘긴다(옛 --adversarial 문서처럼 file 없는 항목을 그대로
# malformed 로 떨어뜨리지 않는다). bridge 가 채우지 않는 필수 필드는 summary 뿐이라
# 그것이 없는 항목으로 같은 성질(승격 경로의 malformed 드롭)을 잰다.
mkdir -p "$tmp/a1"
printf '[]\n' > "$tmp/a1/findings.yaml"
rf_prep "$tmp/a1"
rf_reply "$tmp/a1" 'verdicts: []
added:
  - file: x.py
    severity: CRITICAL'
printf 'findings: []\n' > "$tmp/empty.yaml"
printf 'findings:\n  - "CRITICAL: bare string finding"\n' > "$tmp/str.yaml"

out_a="$(rf_synth "$tmp/a1" 2>/dev/null)"
out_b="$(python3 "$SCRIPT" --findings "$tmp/str.yaml" 2>/dev/null)"

if printf '%s' "$out_a" | grep -q 'dropped as malformed'; then
  ok "a1 — 승격 경로의 소실이 stdout 공지로 나온다"
else
  no "a1 — 승격 경로의 소실이 stdout에 없다"; printf '%s\n' "$out_a" | sed 's/^/      /'
fi
if printf '%s' "$out_b" | grep -q 'dropped as malformed'; then
  ok "a2 — primary 리뷰어 경로의 소실도 같은 공지로 나온다"
else
  no "a2 — primary 경로의 소실이 stdout에 없다"; printf '%s\n' "$out_b" | sed 's/^/      /'
fi

# ── (b) 소비자 — step 4.5에 그 문구를 읽는 분기가 있고 bare clean을 금지한다 ──
# 섹션 윈도우로 좁힌다: 파일 아무 데나 단어가 있으면 통과하는 락은 이빨이 없다
# (헤더-satisfiable 함정 — 이 리포에서 이미 두 번 밟았다).
window="$(awk '/Step 4.5 — Surface the verdict/,/^5\. \*\*Decision tool/' "$SKILL")"
wlines="$(printf '%s' "$window" | wc -l | tr -d ' ')"
if [ "${wlines:-0}" -ge 20 ]; then
  ok "b0 — step 4.5 섹션 윈도우 ${wlines}줄 확보 (앵커 유효)"
else
  no "b0 — step 4.5 섹션을 못 찾았다(${wlines}줄) — 앵커가 깨졌다, 아래 판정 무의미"
fi

# 지시부 — R-AA (Task8 (g)) 로 「Not-clean notice override」·「Why this clause
# exists」 두 문단은 삭제됐다 — 그 자리를 이제 새 Step 4.5 body 의 세 번째
# bullet 항목(「본 보고서의 `판정 degrade` 줄은 **그대로 보인다** … `dropped as
# malformed` 줄도 같다.」)이 진다: 마커는 더 이상 판정 키가 아니라 그대로
# 노출만 하라는 지시다(판정은 `verdict:` 줄이 정한다). d0/d3 가 아래에서
# 다시 쓴다. 여기서 먼저 뽑는 이유는 b1/c 도 «지시부에만» unique 해야 하기
# 때문이다(수정 라운드 1, F5 의 규율 그대로 승계).
directive="$(awk '/본 보고서의 `판정 degrade`/,/dropped as malformed`/' "$SKILL")"
dlines="$(printf '%s' "$directive" | wc -l | tr -d ' ')"

# d0 — 앵커 유효성(양의 짝). 새 지시부는 3줄짜리 bullet 하나다 — 옛 다문단
# 지시부(>=10줄)와 길이가 다르므로 하한도 그에 맞춰 내린다. 앵커가 깨지면
# (예: bullet 문구가 또 바뀌면) `$directive` 가 비거나 짧아져 여기서 먼저
# 드러난다 — b1·c·d3 가 "생산자만 고쳤다"·"문구 불일치" 같은 «틀린 원인»을
# 대신 찍기 전에.
if [ "${dlines:-0}" -ge 2 ]; then
  ok "d0 — 새 지시부 ${dlines}줄 확보 (앵커 유효)"
else
  no "d0 — 지시부를 못 찾았다(${dlines}줄) — 앵커가 깨졌다, 아래 b1·c·d3 판정 무의미"
fi

if printf '%s' "$directive" | grep -q 'dropped as malformed'; then
  ok "b1 — step 4.5가 drop 공지 문구를 소비한다"
else
  no "b1 — step 4.5가 drop 공지를 읽지 않는다 (생산자만 고친 반쪽 수정)"
fi
# R-AA — bare `clean`을 문면으로 금지하던 옛 override는 없다. 새 설계는
# 판정 자체를 `verdict:` 줄에 맡기고, SKILL은 그 판정이 not-clean일 때
# 뜨는 마커(`clean이 아니다`)를 그대로 보이라고만 지시한다 — 그래서
# window에서 찾는 리터럴도 같이 바뀐다.
if printf '%s' "$window" | grep -qF 'clean이 아니다'; then
  ok "b2 — drop이 있으면 clean이 아니라는 마커를 그대로 보이라는 지시가 있다"
else
  no "b2 — drop이 있어도 clean이 아니라는 표시 없이 넘어갈 수 있다"
fi

# ── (c) 생산자 문구와 소비자 문구가 **같은 문자열**인가 ───────────────────────
# 둘을 따로 고정하면 한쪽 문구만 바꿔도 양쪽 다 GREEN인 채로 seam이 다시 열린다.
# b1 과 같은 이유로 `$directive` 로 좁힌다 — `$window` 였으면 위 decoy 인용이
# 이 검사도 만족시킨다.
producer_phrase="$(printf '%s' "$out_b" | grep -o 'dropped as malformed' | head -1)"
if [ -n "$producer_phrase" ] && printf '%s' "$directive" | grep -qF "$producer_phrase"; then
  ok "c — 생산자가 내는 문구와 소비자가 찾는 문구가 동일하다"
else
  no "c — 생산자/소비자 문구 불일치 (producer='${producer_phrase:-<none>}')"
fi

# ── (d) 판정 키가 «인스턴스 리터럴»이 아니라 «공유 마커»인가 ────────────────
# (a)~(c) 는 통지가 하나뿐이라는 전제 위에 서 있다. 통지가 둘이 되는 순간 그
# 전제는 열거가 되고, 열거는 시간에 대해 fail-open 이다 — 두 번째 통지
# (`판정 degrade`, 주 입력 사망)는 `dropped as malformed` 키에 걸리지 않아
# 같은 반쪽 수정이 대상만 바꿔 재발했다. 그래서 두 통지가 **공유하는 마커**를
# 판정 키로 쓰는지를 여기서 잰다.
MARKER='**이 실행은 clean이 아니다**'

# d1 — 두 번째 통지(주 입력 사망)가 그 마커를 실제로 단다.
out_c="$(python3 "$SCRIPT" --findings "$tmp/never-created.yaml" 2>/dev/null)"
if printf '%s' "$out_c" | grep -qF "$MARKER"; then
  ok "d1 — degrade 통지가 공유 마커를 단다"
else
  no "d1 — degrade 통지에 공유 마커가 없다"; printf '%s\n' "$out_c" | sed 's/^/      /'
fi

# d2 — 첫 통지도 **같은** 마커를 단다. 이것이 없으면 «공유»가 성립하지 않고
#      마커 키잉은 두 번째 통지만 잡는 또 하나의 열거가 된다.
if printf '%s' "$out_b" | grep -qF "$MARKER"; then
  ok "d2 — drop 통지도 같은 마커를 단다 (마커가 실제로 공유된다)"
else
  no "d2 — 두 통지가 마커를 공유하지 않는다 — 마커 키잉이 성립하지 않는다"
fi

# d3 — 소비자가 그 마커를 **그대로 노출**하라고 지시한다(R-AA — 더는 판정
# 키가 아니다: 판정은 합성기의 `verdict:` 줄이 정하고, 이 bullet은 그 판정이
# not-clean일 때 뜨는 마커를 감추지 말라는 표시 지시일 뿐이다).
#
# 코퍼스를 step 4.5 창 전체가 아니라 «지시부»로 좁히는 것은 선택이 아니라
# 성립 조건이다 — 헤더가 문구를 만족시키면 body를 삭제해도 GREEN인 것과
# 같은 함정이고, 판정은 지시부에 unique해야 한다. `$directive`/`$dlines` 는
# 위 (b) 에서 이미 계산했고 그 앵커 유효성(d0)도 그 자리에서 이미
# 보고했다(수정 라운드 2, m4 — 진단 순서를 계산 순서와 맞춘다) — 다시
# 도출하지도, 다시 보고하지도 않는다.
if printf '%s' "$directive" | grep -qF "$MARKER"; then
  ok "d3 — step 4.5 지시부가 공유 마커를 그대로 보이라고 지시한다"
else
  no "d3 — 지시부가 마커를 노출하지 않는다"
fi

# d4 — 양성 짝. 통지가 없는 정상 clean 실행에는 마커가 **없어야** 한다.
#      이걸 안 재면 「항상 not-clean」으로 만들어도 d1~d3 가 통과한다.
out_clean="$(python3 "$SCRIPT" --findings "$tmp/empty.yaml" 2>/dev/null)"
if printf '%s' "$out_clean" | grep -qF "$MARKER"; then
  no "d4 — 정상 clean 출력에 마커가 있다 — 마커가 아무 때나 켜지면 판정 키가 아니다"
  printf '%s\n' "$out_clean" | sed 's/^/      /'
else
  ok "d4 — 정상 clean 출력에는 마커가 없다 (양성 짝)"
fi

# d5 — 생산자가 내는 마커와 소비자가 찾는 마커가 **같은 바이트**인가.
#      (c) 와 같은 논거: 둘을 따로 고정하면 한쪽만 바꿔도 양쪽 GREEN 인 채로
#      seam 이 다시 열린다.
marker_emitted="$(printf '%s' "$out_c" | grep -oF "$MARKER" | head -1)"
if [ -n "$marker_emitted" ] && printf '%s' "$directive" | grep -qF "$marker_emitted"; then
  ok "d5 — 생산자 마커와 소비자 마커가 바이트 동일하다"
else
  no "d5 — 마커 불일치 (emitted='${marker_emitted:-<none>}')"
fi
finish
