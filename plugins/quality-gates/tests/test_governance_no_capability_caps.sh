#!/usr/bin/env bash
# AC8a–AC8d — 규약 정렬(S4): CLAUDE.md · philosophy · plugin-authoring.md에서 능력
# 상한(N≥5 하드 게이트 · 기본값 편향 · wall-clock budget · single-file trivia 제약)이
# 사라졌고, 그 자리를 대체하는 재평가-가능 원칙과 agent model:inherit 규약이 들어섰고,
# cost_class: high 승인 게이트(P17 load-bearing)는 그대로 존속하는지 검증한다.
#
# 왜 이 락이 필요한가: 이 sweep의 앞선 태스크들은 코드/프롬프트에서 능력 억제를
# 제거했지만, 그 억제를 정당화하던 "규약"(CLAUDE.md·철학 문서)이 남아 있으면 다음
# 저자가 같은 억제를 "규약을 따른 것"이라며 재도입한다 — 이 락은 규약 쪽을 잠근다.
# 실제 사례: 이 sweep 중 한 agent 프롬프트가 "순차 호출(병렬·투기적 금지, C5/AP9)"을
# 근거로 삼아 철학 문서의 AP9를 인용했다.
#
# 범위 밖 (기록이므로 무변경): CHANGELOG · docs/handoff/** · docs/superpowers/**
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT" || exit 1
PASS=0; FAIL=0
pass() { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ FAIL: $1"; }

CLAUDE_MD="CLAUDE.md"
PHIL="docs/philosophy/devbrew-harness-philosophy.md"
AUTHORING="docs/plugin-authoring.md"

# --- AC8a: 숫자 임계 · 기본값 편향 · wall-clock 부재, 승인 게이트는 존속 ---
# N-접두 형태("N ≥ 5"/"N≥5")만 찾으면 맹점이 생긴다 — philosophy AP9 스텁은 접두
# 없이 bare "≥5"로 같은 임계를 적었었고, 원래 sweep의 판별 질의(N-접두 전용)가
# 이걸 놓쳤다(fix round 1). ≥/>= 뒤에 5가 바로 오는 형태를 접두 유무와 무관하게
# 잡는다 — "N ≥ 5"·"N≥5"·bare "≥5"·"≥ 5"·">=5"·">= 5" 전부 이 한 패턴에 포함된다.
# 오탐 점검(둘 다 무매치 확인됨): CLAUDE.md의 `<PLUGIN>=1` 킬스위치 placeholder
# ("PLUGIN>" 다음 "=1" — 5가 아니라 1이라 애초에 후보 밖), philosophy의
# "re-review cap 5"·"Phase 5"·"5-ritual gate"(비교 연산자 없이 숫자만 등장).
if grep -qE '(≥|>=)[[:space:]]*5' "$CLAUDE_MD" "$PHIL"; then
  fail "AC8a: fan-out 하드 게이트 임계(≥5, N-접두 여부 무관)가 CLAUDE.md/philosophy에 잔존한다"
else
  pass "AC8a: fan-out 하드 게이트 임계(≥5, N-접두 여부 무관) 없음"
fi

# 위 assert는 **글리프**만 막는다 — 숫자와 언어 차원은 열려 있었다. 산문형
# 'fan-out이 5 이상이면 … 금지'와 임계값 4가 둘 다 GREEN이었다(mutation M6/M6b).
# 리터럴 값을 쫓는 대신 **개념**을 잠근다: fan-out을 숫자 임계에 묶는 문장 자체.
# 오탐 점검: 두 파일의 현재 fan-out 언급(CLAUDE.md:68, philosophy:63·96)에는
# 임계 숫자가 없다 — philosophy:63의 'fan-out N'은 *선언* 요구이지 임계가 아니다.
if grep -hE 'fan-out|팬아웃' "$CLAUDE_MD" "$PHIL" \
     | grep -E '[0-9]' \
     | grep -qE '이상|초과|넘으|부터|≥|>=|이면'; then
  fail "AC8a: fan-out을 숫자 임계에 묶는 문장이 잔존한다 (값·표기를 바꿔도 같은 억제다)"
else
  pass "AC8a: fan-out을 숫자 임계에 묶는 문장 없음 (개념 단위 잠금)"
fi

# 두 particle 변형(를/가) 모두 커버 — CLAUDE.md는 "single-agent를 default로",
# philosophy AP9 앵커는 "single-agent가 default다"로 다르게 적혀 있었다.
if grep -qE 'single-agent(를|가) default' "$CLAUDE_MD" "$PHIL"; then
  fail "AC8a: 'single-agent ... default' 기본값 편향 문구가 잔존한다"
else
  pass "AC8a: 기본값-편향(single-agent default) 문구 없음"
fi

if grep -qE 'wall-clock' "$CLAUDE_MD"; then
  fail "AC8a: CLAUDE.md에 wall-clock budget 문구가 잔존한다 (spec-distill v0.17.0이 이미 폐기한 것을 규약이 요구 중)"
else
  pass "AC8a: CLAUDE.md에 wall-clock 문구 없음"
fi

# cost_class: high 승인 게이트는 양방향으로 존속을 증명한다.
# CLAUDE.md 본문은 `cost_class`와 `high`를 별개 backtick span으로 적어 리터럴
# "cost_class: high" 문자열이 존재하지 않는다 — 그래서 게이트 절 자체의 고유 문구를
# 직접 앵커한다. philosophy는 실제로 `cost_class: high` 리터럴을 갖고 있으므로 함께 확인.
if grep -qF '지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함' "$CLAUDE_MD"; then
  pass "AC8a: CLAUDE.md의 cost_class high 승인 게이트 절 존속"
else
  fail "AC8a: CLAUDE.md의 cost_class high 승인 게이트 절이 사라졌다 — P17 사용자-주권 컨트롤 소실"
fi
if grep -qF 'cost_class: high' "$PHIL"; then
  pass "AC8a: philosophy의 cost_class: high 리터럴 존속"
else
  fail "AC8a: philosophy의 cost_class: high 승인 게이트 리터럴이 사라졌다"
fi

# --- AC8b: philosophy :20 — Three Laws 집행은 불변, 개별 임계치는 재평가 대상 ---
# 부분 문자열 assert는 **자기 부정문에도 만족된다**: '재평가 대상'은
# '재평가 대상이 **아니다**' 안에 그대로 들어 있어, 정반대 정책으로 바꿔도 GREEN이었다
# (2026-08-04 /qg 라운드 1, pr-test-analyzer mutation M7). 문장 전체를 앵커하고
# 부정형을 따로 막는다 — 긍정 assert 하나로는 의미를 잴 수 없다.
if grep -qF '재평가 대상이다' "$PHIL"; then
  pass "AC8b: 임계치·예산·상한이 재평가 대상임을 명시하는 문장 실재"
else
  fail "AC8b: philosophy에 '재평가 대상이다' 문장이 없다 — sweep 자체가 규칙 위반으로 읽힌다"
fi
if grep -qE '재평가 대상이[[:space:]]*아니' "$PHIL"; then
  fail "AC8b: '재평가 대상이 아니다'로 정책이 뒤집혔다 — 긍정 assert만으로는 못 잡는 반전이다"
else
  pass "AC8b: 재평가 가능성을 부정하는 문구 없음"
fi
if grep -qF '모델 성능이 향상돼도 이 메커니즘은 불변이다' "$PHIL"; then
  fail "AC8b: philosophy :20 원문(전면 불변 선언)이 아직 남아 있다"
else
  pass "AC8b: philosophy :20 원문(전면 불변 선언) 제거됨"
fi

# --- AC8c: P12 trivia escape에서 single-file 제약 제거 (섹션 윈도우로 스코프) ---
# 전역 grep은 문서 다른 절의 우연한 "single-file" 언급에도 만족될 수 있다 — P12
# 섹션(다음 ## 또는 ### 헤딩 전까지)으로 잘라서 그 안에서만 확인한다.
p12="$(awk '/^### P12/{f=1;next} /^(## |### )/{f=0} f' "$PHIL")"
if [ -z "$p12" ]; then
  fail "AC8c: philosophy에서 ### P12 섹션을 찾지 못했다"
elif grep -qF 'single-file' <<<"$p12"; then
  fail "AC8c: P12 섹션에 single-file 제약이 잔존한다 (multi-file trivia diff가 여전히 게이트에 걸린다)"
else
  pass "AC8c: P12 섹션에 single-file 제약 없음"
fi

# --- AC8d: docs/plugin-authoring.md에 agent model: inherit 규약 신설 ---
# 예전 정규식('model:.*`inherit`')은 토큰이 근처에 있다는 것만 증명했다 — **처방과
# 금지를 구별하지 못한다**. "`inherit`을 쓰지 말고 리터럴 티어를 박아라"로 바꿔도
# GREEN이었다(mutation M8). 처방 문장 전체를 앵커하고, 금지 어법을 따로 막는다.
if grep -qF '**agent `model:`은 `inherit`.**' "$AUTHORING"; then
  pass "AC8d: plugin-authoring.md에 agent model: inherit **처방** 존재"
else
  fail "AC8d: agent model: inherit 처방 문장이 없다 — 신규 플러그인이 리터럴 티어 핀을 복제할 수 있다"
fi
if grep -nE 'inherit' "$AUTHORING" | grep -qE '쓰지[[:space:]]*(마|말)|금지|말고[[:space:]]*리터럴'; then
  fail "AC8d: inherit을 **금지**하는 어법이 있다 — 규약이 뒤집혔다"
else
  pass "AC8d: inherit을 금지하는 어법 없음"
fi

echo; echo "Total: $((PASS+FAIL)) | Pass: $PASS | Fail: $FAIL"
[ "$FAIL" -eq 0 ]
