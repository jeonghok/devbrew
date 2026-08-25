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
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

tmp="$(mktemp -d -t qg-dropnotice-XXXXXX)" || exit 1
trap 'rc=$?; rm -rf "$tmp"; exit $rc' EXIT

# ── (a) 생산자 — 두 출처 모두에서 공지가 stdout에 나온다 ──────────────────────
cat > "$tmp/adv.yaml" <<'Y'
verdicts: []
new_findings:
  - severity: CRITICAL
    summary: "no file key"
Y
printf 'findings: []\n' > "$tmp/empty.yaml"
printf 'findings:\n  - "CRITICAL: bare string finding"\n' > "$tmp/str.yaml"

out_a="$(python3 "$SCRIPT" --adversarial "$tmp/adv.yaml" --findings "$tmp/empty.yaml" 2>/dev/null)"
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
window="$(awk '/Step 4.5 — Surface findings/,/^5\. \*\*Decision tool/' "$SKILL")"
wlines="$(printf '%s' "$window" | wc -l | tr -d ' ')"
if [ "${wlines:-0}" -ge 20 ]; then
  ok "b0 — step 4.5 섹션 윈도우 ${wlines}줄 확보 (앵커 유효)"
else
  no "b0 — step 4.5 섹션을 못 찾았다(${wlines}줄) — 앵커가 깨졌다, 아래 판정 무의미"
fi
if printf '%s' "$window" | grep -q 'dropped as malformed'; then
  ok "b1 — step 4.5가 drop 공지 문구를 소비한다"
else
  no "b1 — step 4.5가 drop 공지를 읽지 않는다 (생산자만 고친 반쪽 수정)"
fi
if printf '%s' "$window" | grep -q 'not clean'; then
  ok "b2 — drop이 있으면 bare clean을 금지하는 지시가 있다"
else
  no "b2 — drop이 있어도 clean을 찍을 수 있다"
fi

# ── (c) 생산자 문구와 소비자 문구가 **같은 문자열**인가 ───────────────────────
# 둘을 따로 고정하면 한쪽 문구만 바꿔도 양쪽 다 GREEN인 채로 seam이 다시 열린다.
producer_phrase="$(printf '%s' "$out_b" | grep -o 'dropped as malformed' | head -1)"
if [ -n "$producer_phrase" ] && printf '%s' "$window" | grep -qF "$producer_phrase"; then
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

# d3 — 소비자가 그 마커를 판정 키로 쓴다.
if printf '%s' "$window" | grep -qF "$MARKER"; then
  ok "d3 — step 4.5 가 공유 마커를 판정 키로 쓴다"
else
  no "d3 — step 4.5 가 인스턴스 리터럴에만 키잉한다 (열거 = fail-open)"
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
if [ -n "$marker_emitted" ] && printf '%s' "$window" | grep -qF "$marker_emitted"; then
  ok "d5 — 생산자 마커와 소비자 마커가 바이트 동일하다"
else
  no "d5 — 마커 불일치 (emitted='${marker_emitted:-<none>}')"
fi
finish
