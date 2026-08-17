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
finish
