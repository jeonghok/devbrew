#!/usr/bin/env bash
# guards: plugins/spec-distill/hooks/review-dispatch.py
#
# 훅의 차단 결정 두 자리가 자기 처분을 원장 어휘로 밝히는지 검사한다.
#
# 채널은 `reason` 이다. `systemMessage` 는 모델 컨텍스트에 도달하지 않는다
# (카나리 14개 중 0개). `reason` 은 차단 결정에 딸릴 때 7/7 도달한다.
#
# Task 11 수정 라운드 2 — `reasons()` 직접 호출 대신 공유 렌더러
# `disposition_lines()` 를 쓴다. 원인: L2 소비 락(test_adjudication_consumed.sh)
# 이 `reasons()` 는 held·unknown·sources_failed·coerced(gate=True) 넷만
# 내고 accepted/rejected/absorbed/suppressed 는 침묵한다는 것을 잡았다 —
# 오늘 이 훅이 hold() 만 불러 우연히 안 드러났을 뿐, 이 훅에 reject() 하나만
# 늘어도 조용히 새는 구조였다.
#
# 이 라운드에서 소스 텍스트 검사(`reasons\(\)` grep)의 한계도 드러났다:
# 구현이 바뀐 뒤에도 «이 파일 자신의 설명 주석»이 우연히 그 문자열을 담고
# 있어 단언이 계속 GREEN 이었다(호출이 아니라 이름의 존재만 잰 값싼 검사의
# 정체). 그래서 구조 검사에 더해 훅을 **실제로 실행**해 JSON 출력을 보는
# 절을 둔다 — 이것만이 "정말 disposition_lines() 가 불려 reason 에 실렸다"
# 를 증명한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"

BODY="$(cat "$HOOK")"

assert_grep "$BODY" 'from adjudication import Ledger' \
  "훅이 원장을 import 한다 (㉮ 에 들어온다 — L1 의 대상이 된다)"
assert_grep "$BODY" 'from render_disposition import disposition_lines' \
  "훅이 공유 렌더러를 import 한다 (키 이름을 손으로 다시 적지 않는다)"

# 차단 결정 자리마다 처분 호출이 있는지. 자리 «수»에서 출발한다 —
# 하나를 배선하고 다른 하나를 잊는 것이 이 검사가 막는 것이다.
nblock="$(printf '%s\n' "$BODY" | grep -c '"decision": "block"')"
ndisp="$(printf '%s\n' "$BODY" | grep -cE '\.(hold|reject|source_failed|uncountable)\(')"
note "차단 결정 $nblock 자리 · 처분 호출 $ndisp 건"
if [ "${nblock:-0}" -gt 0 ] 2>/dev/null; then
  ok "차단 결정 $nblock 자리 (0 이 아니다)"
else
  no "차단 결정이 0 이다 — grep 이 깨졌거나 분기가 사라졌다. 이 검사가 공허하다"
fi
if [ "${ndisp:-0}" -ge "${nblock:-0}" ] 2>/dev/null; then
  ok "처분 호출 $ndisp >= 차단 자리 $nblock"
else
  no "차단 자리 $nblock 중 $((nblock - ndisp)) 곳이 처분을 안 부른다"
fi

# 렌더러가 실제로 «호출» 형태로 나타나는지 (이름만 있는 주석과 구별하려는
# 최소 방어 — 진짜 증거는 아래 실행 절).
assert_grep "$BODY" 'disposition_lines\(' \
  "훅이 disposition_lines() 를 호출 형태로 쓴다"

# ── 실행 절 — 진짜 decision:"block" 을 발생시켜 JSON 출력을 확인한다 ──────
# T5-2(dispatch 강제) 경로: 정상 문서 하나를 발견시키면 이 경로를 탄다.
WORK=$(mktemp -d -t revdispdisp-XXXXXX) || exit 1
WORK=$(cd "$WORK" && pwd -P) || exit 1
trap 'rm -rf "$WORK"' EXIT
( cd "$WORK" && git init -q && git config user.email t@t.t && git config user.name t \
  && git commit -q --allow-empty -m seed ) >/dev/null
REL="docs/superpowers/specs/2026-05-17-disp-design.md"
mkdir -p "$WORK/$(dirname "$REL")"
cp "$REPO_ROOT/plugins/spec-distill/tests/fixtures/2026-05-17-test-design.md" "$WORK/$REL"
mkdir -p "$WORK/.claude/spec-distill/disp-probe-sid"
cat > "$WORK/.claude/spec-distill/disp-probe-sid/state.local.md" <<'EOF'
---
session_id: disp-probe-sid
---
EOF
OUT="$(cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID=disp-probe-sid \
  python3 "$HOOK" </dev/null 2>/dev/null)"

REASON="$(printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("reason",""))' 2>/dev/null)"
SYSMSG="$(printf '%s' "$OUT" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("systemMessage",""))' 2>/dev/null)"

assert_grep "$REASON" 'MANDATORY' \
  "실제 block 의 reason 이 지시문을 담는다"
assert_grep "$REASON" '\*\*처분:\*\*' \
  "실제 block 의 reason 에 처분 줄이 실제로 실린다"
assert_grep "$REASON" '\*\*배관 손실:\*\*' \
  "실제 block 의 reason 에 배관 손실 줄이 실제로 실린다"
assert_not_grep "$SYSMSG" '\*\*처분:\*\*' \
  "systemMessage 에는 처분 줄이 안 실린다 (사람 채널·모델 채널을 계속 분리한다)"

# 배치 — 지시문이 처분 줄보다 «먼저» 나온다. 앞뒤가 바뀌면 지시가 처분
# 텍스트에 묻혀 다음 턴 강제력이 떨어진다(오케스트레이터 지적).
MANDATORY_POS="$(printf '%s' "$REASON" | grep -bo 'MANDATORY' | head -1 | cut -d: -f1)"
DISP_POS="$(printf '%s' "$REASON" | grep -bo '\*\*처분:\*\*' | head -1 | cut -d: -f1)"
if [ -n "${MANDATORY_POS:-}" ] && [ -n "${DISP_POS:-}" ] \
   && [ "$MANDATORY_POS" -lt "$DISP_POS" ] 2>/dev/null; then
  ok "배치 — MANDATORY 지시문이 처분 줄보다 앞에 온다"
else
  no "배치 위반 — MANDATORY(${MANDATORY_POS:-?}) 가 처분 줄(${DISP_POS:-?}) 보다 앞이 아니다"
fi

finish
