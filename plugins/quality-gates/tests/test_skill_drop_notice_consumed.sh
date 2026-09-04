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

# 지시부 — d0/d3 가 아래에서 다시 쓴다. 여기서 먼저 뽑는 이유는 b1/c 도
# «지시부에만» unique 해야 하기 때문이다(수정 라운드 1, F5). `window`
# 전체로 찾으면 "Why the key is the marker" 근거 단락(:583-ff)의 decoy
# 인용 — `... was not matched by a` `dropped as malformed` `key` — 가
# b1/c 를 만족시킨다: 지시부(556-571줄)를 통째로 지워도 이 decoy 인용이
# 살아남아 b1·c 가 **GREEN 으로 남았다** (Task 15 μ12 실측 — b1 은
# 코디네이터가 지목, c 는 같은 원인으로 여기서 함께 닫는다).
directive="$(awk '/\*\*Not-clean notice override/,/Why this clause exists/' "$SKILL" | sed '$d')"
dlines="$(printf '%s' "$directive" | wc -l | tr -d ' ')"

if printf '%s' "$directive" | grep -q 'dropped as malformed'; then
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

# d3 — 소비자가 그 마커를 **판정 키로** 쓴다.
#
# 코퍼스를 step 4.5 창 전체가 아니라 «지시부»로 좁히는 것은 선택이 아니라
# 성립 조건이다. 마커는 아래 「Why this clause exists」 근거 단락에도 인용문으로
# 등장한다 — 창 전체를 보면 판정 키를 인스턴스 리터럴로 되돌려도 그 인용문이
# 검사를 만족시켜 GREEN 이다 〔실측: 되돌림 변이에서 11/11 통과〕. 헤더가 문구를
# 만족시키면 body 를 삭제해도 GREEN 인 것과 같은 함정이고, 판정은 지시부에
# unique 해야 한다. `$directive`/`$dlines` 는 위 (b) 에서 이미 계산했다
# (b1·c 도 같은 이유로 같은 변수를 쓴다, F5) — 다시 도출하지 않는다.
if [ "${dlines:-0}" -ge 10 ]; then
  ok "d0 — 오버라이드 지시부 ${dlines}줄 확보 (앵커 유효)"
else
  no "d0 — 지시부를 못 찾았다(${dlines}줄) — 앵커가 깨졌다, 아래 판정 무의미"
fi
if printf '%s' "$directive" | grep -qF "$MARKER"; then
  ok "d3 — step 4.5 지시부가 공유 마커를 판정 키로 쓴다"
else
  no "d3 — 지시부가 인스턴스 리터럴에만 키잉한다 (열거 = fail-open)"
fi

# d3b — decoy 배제. 근거 단락의 인용문이 지시부 **밖**이어야 d3 가 의미를 갖는다.
#       음의 검사에는 양의 짝이 필요하다: 인용문이 파일에서 사라지면 「밖」은
#       공허하게 참이 되므로, 그 인용문이 실재하는지를 먼저 잰다.
if grep -qF 'whose own text reads' "$SKILL"; then
  ok "d3b① 근거 단락의 마커 인용문이 파일에 실재 (배제 검사의 양성 짝)"
else
  no "d3b① 근거 단락이 사라졌다 — 배제 검사가 공허해진다"
fi
if printf '%s' "$directive" | grep -qF 'whose own text reads'; then
  no "d3b② 지시부가 근거 단락을 삼켰다 — d3 가 인용문으로 만족될 수 있다"
else
  ok "d3b② 근거 단락의 인용문은 지시부 밖이다"
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
