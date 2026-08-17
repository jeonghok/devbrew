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
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

CLAUDE_MD="CLAUDE.md"
PHIL="docs/philosophy/devbrew-harness-philosophy.md"
AUTHORING="docs/plugin-authoring.md"

# 규약 문서 집합은 **도출**한다 — 세 변수 하드코딩은 네 번째 문서가 생기는 순간
# fail-open이다(mutation m07: 같은 한글 cap 문장을 plugin-authoring.md에 옮기자 통과).
GOV_DOCS=("$CLAUDE_MD")
while IFS= read -r f; do [[ -n "$f" ]] && GOV_DOCS+=("$f"); done \
  < <(ls docs/philosophy/*.md docs/plugin-authoring.md 2>/dev/null)
if [[ "${#GOV_DOCS[@]}" -ge 3 ]]; then
  ok "코퍼스 도출: 규약 문서 ${#GOV_DOCS[@]}개 (하드코딩 아님)"
else
  no "코퍼스 도출 실패 — 규약 문서를 ${#GOV_DOCS[@]}개만 찾았다 (아래 판정 무의미)"
fi

# **인용부까지 본다** (2026-08-05 /qg 라운드 2, adversarial N2가 지목한 구조적 근본):
# sweep의 완료 oracle이 정의 지점(`CLAUDE.md`·`docs/philosophy/`)만 스캔하고
# `plugins/`를 보지 않았다. 그래서 규칙을 정의부에서 지우고 "완료"를 선언했는데
# **인용부 6곳이 그 규칙을 현존 백스톱으로 계속 인용**하고 있었다 — 삭제 전보다 나쁘다
# (삭제 전엔 최소한 참이었다). 규칙의 제거는 정의부만 봐서는 인증할 수 없다.
# CHANGELOG·tests·fixtures는 이력/코퍼스이므로 제외한다(과거 기록은 고쳐 쓰지 않는다).
CITE_FILES=()
while IFS= read -r f; do [[ -n "$f" ]] && CITE_FILES+=("$f"); done < <(
  find plugins -name '*.md' -not -path '*/tests/*' -not -name 'CHANGELOG.md' 2>/dev/null)
if [[ "${#CITE_FILES[@]}" -ge 20 ]]; then
  ok "인용부 코퍼스 실재: plugins/ 산문 ${#CITE_FILES[@]}개 파일"
else
  no "인용부 코퍼스가 ${#CITE_FILES[@]}개뿐 — 경로가 깨졌다 (아래 인용 판정 무의미)"
fi

# --- AC8a: 숫자 임계 · 기본값 편향 · wall-clock 부재, 승인 게이트는 존속 ---
# N-접두 형태("N ≥ 5"/"N≥5")만 찾으면 맹점이 생긴다 — philosophy AP9 스텁은 접두
# 없이 bare "≥5"로 같은 임계를 적었었고, 원래 sweep의 판별 질의(N-접두 전용)가
# 이걸 놓쳤다(fix round 1). ≥/>= 뒤에 5가 바로 오는 형태를 접두 유무와 무관하게
# 잡는다 — "N ≥ 5"·"N≥5"·bare "≥5"·"≥ 5"·">=5"·">= 5" 전부 이 한 패턴에 포함된다.
# 오탐 점검(둘 다 무매치 확인됨): CLAUDE.md의 `<PLUGIN>=1` 킬스위치 placeholder
# ("PLUGIN>" 다음 "=1" — 5가 아니라 1이라 애초에 후보 밖), philosophy의
# "re-review cap 5"·"Phase 5"·"5-ritual gate"(비교 연산자 없이 숫자만 등장).
if grep -qE '(≥|>=)[[:space:]]*5' "${GOV_DOCS[@]}"; then
  no "AC8a: fan-out 하드 게이트 임계(≥5, N-접두 여부 무관)가 규약 문서에 잔존한다"
else
  ok "AC8a: fan-out 하드 게이트 임계(≥5, N-접두 여부 무관) 없음"
fi

# 위 assert는 **글리프**만 막는다 — 숫자와 언어 차원은 열려 있었다. 산문형
# 'fan-out이 5 이상이면 … 금지'와 임계값 4가 둘 다 GREEN이었다(mutation M6/M6b).
# 리터럴 값을 쫓는 대신 **개념**을 잠근다: fan-out을 숫자 임계에 묶는 문장 자체.
# 오탐 점검: 두 파일의 현재 fan-out 언급(CLAUDE.md:68, philosophy:63·96)에는
# 임계 숫자가 없다 — philosophy:63의 'fan-out N'은 *선언* 요구이지 임계가 아니다.
# 개념·표기·언어 세 축을 모두 접는다. 2026-08-05 mutation이 8종 중 2종만 잡힘을
# 실측했다 — 통과한 것들: 한글 수사("다섯을 넘으면" — 아라비아 숫자 없음),
# 개념 별칭("동시 subagent 수가 5 이상", "병렬 agent 3개를 초과"), 영어
# ("when fan-out exceeds 4"), 어미("팬아웃은 4개까지만 허용").
# 열거는 언제나 fail-open이므로 완전할 수 없지만, **값 하나만 바꾸면 통과**하던
# 상태에서 **개념을 다른 이름으로 부르고 다른 언어로 써야 통과**하는 상태로 올린다.
CAP_SUBJECT='fan-out|팬아웃|subagent[[:space:]]*(수|개수|count)|동시[[:space:]]*(실행|dispatch)|병렬[[:space:]]*(agent|에이전트)|parallel[[:space:]]+agents?|concurrent[[:space:]]+subagents?'
CAP_QUANT='[0-9]|하나|둘|셋|넷|다섯|여섯|일곱|여덟|아홉|열|한[[:space:]]*개|두[[:space:]]*개|세[[:space:]]*개|네[[:space:]]*개|다섯[[:space:]]*개'
CAP_COMPARE='이상|초과|넘으|넘는|부터|까지만|이하|미만|≥|>=|이면|exceeds?|more[[:space:]]+than|at[[:space:]]+most|no[[:space:]]+more[[:space:]]+than|maximum|max[[:space:]]+of|limit'
if grep -hE "$CAP_SUBJECT" "${GOV_DOCS[@]}" \
     | grep -E "$CAP_QUANT" \
     | grep -qE "$CAP_COMPARE"; then
  no "AC8a: fan-out(및 개념 별칭)을 수량 임계에 묶는 문장이 잔존한다 — 값·표기·언어를 바꿔도 같은 억제다"
else
  ok "AC8a: fan-out 개념을 수량 임계에 묶는 문장 없음 (별칭·한글수사·영어 포함)"
fi

# 두 particle 변형(를/가) 모두 커버 — CLAUDE.md는 "single-agent를 default로",
# philosophy AP9 앵커는 "single-agent가 default다"로 다르게 적혀 있었다.
if grep -qE 'single-agent(를|가) default' "${GOV_DOCS[@]}"; then
  no "AC8a: 'single-agent ... default' 기본값 편향 문구가 잔존한다"
else
  ok "AC8a: 기본값-편향(single-agent default) 문구 없음"
fi

# wall-clock은 CLAUDE.md만 봤다 — philosophy에 같은 요구를 다시 쓰면 통과했다
# (mutation m08 생존). 규약 문서 전체로 넓힌다.
if grep -qE 'wall-clock' "${GOV_DOCS[@]}"; then
  no "AC8a: 규약 문서에 wall-clock budget 문구가 잔존한다 (spec-distill v0.17.0이 이미 폐기한 것을 규약이 요구 중)"
else
  ok "AC8a: 규약 문서에 wall-clock 문구 없음"
fi

# ── AC8e: 삭제된 규칙을 **현존 백스톱으로 인용**하는 곳이 없다 ────────────────
# 규칙을 정의부에서 지우고 완료를 선언해도, 그 규칙이 인용부에서 계속 논거로
# 쓰이면 제거는 완료된 것이 아니다 — 오히려 삭제 전보다 나쁘다(삭제 전엔 참이었다).
# 실제로 `fan-out ≥5` 게이트 인용 4곳과 `single-file` trivia 제약 집행 2곳이
# sweep "완료" 이후에도 살아 있었고, 그중 둘은 *존재하지 않는 백스톱을 근거로
# 억제한다*고 주장했다 (2026-08-05 /qg 라운드 2).
#
# 식별자 grep으로는 못 찾는다: `AP9` 로 검색하면 `agents/` 에서 0건이 나오는데
# 그 줄은 `devbrew N≥5 게이트` 라고 적혀 있다. **개념 별칭으로** 훑는다.
# 자기 자신(이 락)과 이력(CHANGELOG)·테스트는 코퍼스에서 제외돼 있다.
cite_hits=""
if [[ "${#CITE_FILES[@]}" -gt 0 ]]; then
  cite_hits="$(grep -nE '(fan-out|팬아웃|N)[[:space:]]*(≥|>=)[[:space:]]*5|N≥5|single-file formatting|단일 파일 formatting|단일 파일 내 단일' "${CITE_FILES[@]}" 2>/dev/null \
    | grep -vE '제거|removed|no longer exists|더는|파일 수와 무관|파일 수는' || true)"
fi
if [[ -z "$cite_hits" ]]; then
  ok "AC8e: plugins/ 산문에 삭제된 규칙의 현존-백스톱 인용 없음"
else
  no "AC8e: 삭제된 규칙을 현존 백스톱으로 인용하는 곳이 남았다"
  printf '      %s\n' $(printf '%s\n' "$cite_hits" | cut -d: -f1 | sort -u)
fi

# cost_class: high 승인 게이트는 양방향으로 존속을 증명한다.
# CLAUDE.md 본문은 `cost_class`와 `high`를 별개 backtick span으로 적어 리터럴
# "cost_class: high" 문자열이 존재하지 않는다 — 그래서 게이트 절 자체의 고유 문구를
# 직접 앵커한다. philosophy는 실제로 `cost_class: high` 리터럴을 갖고 있으므로 함께 확인.
if grep -qF '지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함' "$CLAUDE_MD"; then
  ok "AC8a: CLAUDE.md의 cost_class high 승인 게이트 절 존속"
else
  no "AC8a: CLAUDE.md의 cost_class high 승인 게이트 절이 사라졌다 — P17 사용자-주권 컨트롤 소실"
fi
if grep -qF 'cost_class: high' "$PHIL"; then
  ok "AC8a: philosophy의 cost_class: high 리터럴 존속"
else
  no "AC8a: philosophy의 cost_class: high 승인 게이트 리터럴이 사라졌다"
fi

# --- AC8b: philosophy :20 — Three Laws 집행은 불변, 개별 임계치는 재평가 대상 ---
# 부분 문자열 assert는 **자기 부정문에도 만족된다**: '재평가 대상'은
# '재평가 대상이 **아니다**' 안에 그대로 들어 있어, 정반대 정책으로 바꿔도 GREEN이었다
# (2026-08-04 /qg 라운드 1, pr-test-analyzer mutation M7). 문장 전체를 앵커하고
# 부정형을 따로 막는다 — 긍정 assert 하나로는 의미를 잴 수 없다.
if grep -qF '재평가 대상이다' "$PHIL"; then
  ok "AC8b: 임계치·예산·상한이 재평가 대상임을 명시하는 문장 실재"
else
  no "AC8b: philosophy에 '재평가 대상이다' 문장이 없다 — sweep 자체가 규칙 위반으로 읽힌다"
fi
if grep -qE '재평가 대상이[[:space:]]*아니' "$PHIL"; then
  no "AC8b: '재평가 대상이 아니다'로 정책이 뒤집혔다 — 긍정 assert만으로는 못 잡는 반전이다"
else
  ok "AC8b: 재평가 가능성을 부정하는 문구 없음"
fi
if grep -qF '모델 성능이 향상돼도 이 메커니즘은 불변이다' "$PHIL"; then
  no "AC8b: philosophy :20 원문(전면 불변 선언)이 아직 남아 있다"
else
  ok "AC8b: philosophy :20 원문(전면 불변 선언) 제거됨"
fi

# --- AC8c: P12 trivia escape에서 single-file 제약 제거 (섹션 윈도우로 스코프) ---
# 전역 grep은 문서 다른 절의 우연한 "single-file" 언급에도 만족될 수 있다 — P12
# 섹션(다음 ## 또는 ### 헤딩 전까지)으로 잘라서 그 안에서만 확인한다.
p12="$(awk '/^### P12/{f=1;next} /^(## |### )/{f=0} f' "$PHIL")"
if [ -z "$p12" ]; then
  no "AC8c: philosophy에서 ### P12 섹션을 찾지 못했다"
elif grep -qF 'single-file' <<<"$p12"; then
  no "AC8c: P12 섹션에 single-file 제약이 잔존한다 (multi-file trivia diff가 여전히 게이트에 걸린다)"
else
  ok "AC8c: P12 섹션에 single-file 제약 없음"
fi

# --- AC8d: docs/plugin-authoring.md에 agent model: inherit 규약 신설 ---
# 예전 정규식('model:.*`inherit`')은 토큰이 근처에 있다는 것만 증명했다 — **처방과
# 금지를 구별하지 못한다**. "`inherit`을 쓰지 말고 리터럴 티어를 박아라"로 바꿔도
# GREEN이었다(mutation M8). 처방 문장 전체를 앵커하고, 금지 어법을 따로 막는다.
if grep -qF '**agent `model:`은 `inherit`.**' "$AUTHORING"; then
  ok "AC8d: plugin-authoring.md에 agent model: inherit **처방** 존재"
else
  no "AC8d: agent model: inherit 처방 문장이 없다 — 신규 플러그인이 리터럴 티어 핀을 복제할 수 있다"
fi
if grep -nE 'inherit' "$AUTHORING" | grep -qE '쓰지[[:space:]]*(마|말)|금지|말고[[:space:]]*리터럴'; then
  no "AC8d: inherit을 **금지**하는 어법이 있다 — 규약이 뒤집혔다"
else
  ok "AC8d: inherit을 금지하는 어법 없음"
fi
finish
