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
if grep -qE 'N ≥ 5|N≥5' "$CLAUDE_MD" "$PHIL"; then
  fail "AC8a: 'N ≥ 5' fan-out 하드 게이트 문구가 CLAUDE.md/philosophy에 잔존한다"
else
  pass "AC8a: 'N ≥ 5' fan-out 하드 게이트 문구 없음"
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
if grep -qE '재평가 대상' "$PHIL"; then
  pass "AC8b: 임계치·예산·상한이 재평가 대상임을 명시하는 문구 실재"
else
  fail "AC8b: philosophy에 '재평가 대상' 문구가 없다 — sweep 자체가 규칙 위반으로 읽힌다"
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
if grep -qE 'model:.*`inherit`' "$AUTHORING"; then
  pass "AC8d: plugin-authoring.md에 agent model: inherit 규약 존재"
else
  fail "AC8d: plugin-authoring.md에 agent model: inherit 규약이 없다 — 신규 플러그인이 리터럴 티어 핀을 복제할 수 있다"
fi

echo; echo "Total: $((PASS+FAIL)) | Pass: $PASS | Fail: $FAIL"
[ "$FAIL" -eq 0 ]
