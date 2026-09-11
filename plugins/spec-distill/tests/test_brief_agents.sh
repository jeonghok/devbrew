#!/usr/bin/env bash
# Spec B T7 (+ T21의 Bash 부재 절) — 브리핑 자리 agent 도구·모델 표면 락.
# AC4(쓰기·실행·위임 도구 0) · AC5(model 키 부재) · N5(격리 집합 등식 L —
# tools: [] 스캔 집합 == 리터럴 이름 넷)
#
# PR3 Task 4 재조준(2026-09-10): 옛 brief-critic·brief-direction-reviewer 는
# 삭제됐다 — 그 둘이 지던 fidelity·direction 축은 공유 문서 리뷰 엔진의
# doc-critic·doc-recritic(엔진 **사본**, plugins/spec-distill/agents/)이 대신한다.
# 이 락이 재는 것은 그 사본의 tools 표면이다 — 정본(shared/docreview/agents/)의
# frontmatter 계약은 shared/tests/test_docreview_agents.sh 가, 사본이 정본과
# 바이트 단위로 같은지는 shared/tests/test_copy_of_contract.sh 가 각각 잰다.
# 여기서는 사본 파일 자체를 다시 열어 재므로, 위 두 락이 죽거나 copy-of 예외가
# 오용돼도 이 자리가 마지막 방어선이다.
#
# 옛 두 agent 의 프롬프트 본문(카테고리 체크리스트·ground-truth sentinel 계약 등)을
# merge_brief_review.py·build_brief_bundle.py·brief-codex-fidelity-checklist.md 와
# 대조하던 옛 PRODUCER/F3/F14/F15 블록은 대상 파일(brief-critic.md·
# brief-direction-reviewer.md)이 사라져 전부 제거했다 — doc-critic 은 도메인
# 무관 범용 프롬프트라 그 자리에 같은 형태로 옮길 대상이 없다(검토 대상 문서의
# 실제 원문 축은 이제 profile(`references/docreview-profiles/brief.md`)의
# `ground_truth` 필드가 진다 — task-4-report.md 의 concerns 참조).
# Run: bash plugins/spec-distill/tests/test_brief_agents.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
ALL=("doc-critic" "doc-critic-web" "doc-recritic" "brief-readback")

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"
fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

for a in "${ALL[@]}"; do
  f="$SD/agents/$a.md"
  test -f "$f" || { no "에이전트 파일 부재: $a.md"; continue; }
  FM="$(fm_of "$f")"

  # AC5 — model 키 부재 (리터럴 핀도 inherit 도 하니스가 티어를 정하는 값)
  MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
  grep -qE "$MODEL_KEY" <<<"$FM" \
    && no "$a: frontmatter 에 model 키가 있다" || ok "$a: model 키 없음"

  # AC4 — 쓰기·실행·위임 물리적 부재
  # tools: 값을 정규화한 뒤 토큰 단위 정확 일치(대소문자 무시)로 비교한다.
  # 정규화 파이프라인(round 1→2 누적):
  #   1) `tools:` 접두어 제거
  #   2) 트레일링 `# ...` 코멘트 절단 — split 이전에 잘라내므로 주석 안의 문자열은
  #      아예 토큰 후보에 들어오지 않는다(주석에 금지어를 적어도 오탐하지 않음 — round 2 probe)
  #   3) `[`/`]` 제거 (flow-sequence 대괄호)
  #   4) 콤마로 split
  #   5) 각 요소: 앞뒤 공백/탭 trim → 앞뒤 `"`/`'` 1겹 제거 → 다시 trim (quoted element 대응)
  #   6) 전부 소문자로 casefold — fail-closed: `write`도 잡아야 한다. 레지스트리가 소문자
  #      토큰을 실제로 resolve하는지는 이 락의 책임이 아니다. 이 방향이 정당한 allowlist
  #      (Read/Grep/Glob/WebSearch/WebFetch)와 금지 목록 사이에 대소문자 무시 충돌을 만들지
  #      않음을 확인했다 — 두 집합의 이름이 애초에 겹치지 않는다.
  #   7) 빈 줄 제거
  # 이전(raw-line grep) 방식은 bracket-form에서 경계 문자(`]`)를 인식 못 해 뚫렸다(round 1).
  # round 2 리뷰가 이 정규화-비교 자체도 quote·trailing comment·case에 아직 blind함을
  # 추가 적발해(quoted `["Write", Read]`, 코멘트 `Read, Write  # note`, 대소문자
  # `[read, write]`가 전부 회피) 5·6단계를 더했다. `WriteFile` 같은 상위 문자열에 `Write`가
  # 우연히 포함되는 substring collision은 여전히 배제된다(줄 단위 완전 일치이므로).
  #
  # YAML block-sequence(`tools:` 단독 헤더 줄 + 다음 줄부터 `- Read`/`- Write` 나열)는 이
  # 루프가 직접 파싱하지 **않는다** — 의도적 결정이다. 이 레포의 모든 agent frontmatter
  # 관례가 단일 줄 inline 선언(`tools: []` / `tools: Read` / `tools: Read, Grep, ...`)이고
  # block-sequence를 쓰는 기존 파일이 하나도 없다. block-sequence를 쓰면 헤더 줄이
  # `tools:`만 있고 값이 없는 형태가 되므로, 아래 bare-`tools:` guard가 그 줄 자체를
  # YAML null(fail-open 위험)로 fail-closed 처리해 잡는다 — AC4 루프에 별도 YAML
  # block-sequence 파서를 추가하지 않고 이 guard 하나로 충분하다고 판단했다(round 2).
  tools_line="$(grep -E '^tools:' <<<"$FM" | head -1)"
  tools_val="${tools_line#tools:}"
  tools_val="${tools_val%%#*}"
  tools_val="${tools_val//[/}"
  tools_val="${tools_val//]/}"
  tools_norm="$(tr ',' '\n' <<<"$tools_val" \
    | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
          -e 's/^"//' -e 's/"$//' -e "s/^'//" -e "s/'\$//" \
          -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' \
    | tr '[:upper:]' '[:lower:]' \
    | grep -v '^$')"
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor Task; do
    t_lc="$(tr '[:upper:]' '[:lower:]' <<<"$t")"
    if grep -qxF "$t_lc" <<<"$tools_norm"; then
      no "$a: tools:에 $t 가 있다 (Law 2 위반, 대소문자 무시)"
    else
      ok "$a: tools:에 $t 없음"
    fi
  done
  grep -qE '^tools:.*mcp__' <<<"$FM" && no "$a: tools:에 MCP grant" || ok "$a: MCP 없음"

  # 죽은 필드 금지 (allowedTools는 비공식 — 조용히 무시된다)
  grep -qE '^(allowedTools|disallowedTools):' <<<"$FM" \
    && no "$a: allowedTools/denylist 잔존" || ok "$a: allowedTools·disallowedTools 없음"

  # bare `tools:` 금지 — YAML null = "키 미지정"으로 읽혀 조용한 fail-open이 된다.
  # 이 guard는 YAML block-sequence 헤더 줄(`tools:`만 있고 값이 다음 줄부터 `- Read`로
  # 이어지는 형태)도 겸해서 잡는다 — 위 AC4 정규화 파이프라인의 의도적 scope 결정 참조.
  grep -qE '^tools:[[:space:]]*$' <<<"$FM" \
    && no "$a: bare 'tools:' (YAML null → 전체 허용 fail-open 위험; block-sequence 헤더도 이 경로로 잡힌다)" \
    || ok "$a: bare 'tools:' 아님"

  grep -qE '^cost_class: (low|medium|high|variable)$' <<<"$FM" \
    && ok "$a: cost_class 선언" || no "$a: cost_class 없음"
done

# --- L : 격리 집합 등식 (N5) ------------------------------------------------
# 스캔한 집합 == 리터럴 이름 목록. **선택자를 술어와 같은 값으로 두지 않는다**:
# 대상을 `tools: []` 에서 도출하면 `tools: Read` 로 넓히는 변이가 대상 집합을
# 벗어나 락이 공허참으로 통과한다(∀x∈{x:P(x)}. P(x)).
#
# 우변이 리터럴이므로 세 방향이 전부 잡힌다:
#   하나를 넓힘   → 좌변이 셋으로 줄어 ≠  → RED
#   다섯째 추가   → 좌변이 다섯으로 늘어 ≠ → RED
#   넷을 동시에   → 좌변이 공집합 ≠        → RED
# 세 번째가 잡히므로 "각 원소가 tools: [] 이다" 는 별도 락이 **논리적으로
# 잉여**다 — 등식이 그것을 함의한다. 잉여를 필요하다고 적으면 다음 저자가
# 등식 쪽을 지운다.
#
# 표기 변형은 형제 락 test_seed_agents.sh:131 을 물려받아 `[]` 와 `[ ]` 를
# 둘 다 빈 리스트로 읽는다.
# v0.57.0 depth-auditor 편입 — 짝 목록만 인라인으로 받고 파일을 열지 않는 다섯째
# 격리 에이전트다(도구 표면 0). 리터럴이라 넣지 않으면 좌변이 다섯으로 늘어 RED 다.
# T4: brief-critic 삭제 — 리터럴에서 뺀다(넷 → 지금은 이 넷으로 준다). 그 파일의
# 부재 자체는 아래 N 블록이 별도로, 양의 짝(M)과 함께 잰다.
EXPECTED_ISOLATED="brief-readback
depth-auditor
seed-critic
seed-readback"

scan_zero_tool_agents() {
  # $1 = agents 디렉토리. 빈 리스트를 선언한 파일의 basename(확장자 제거)을
  # 정렬해서 낸다.
  local dir="$1" f base fm tl
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    base="$(basename "$f" .md)"
    fm="$(awk 'NR==1&&/^---/{f=1;next} f&&/^---/{exit} f' "$f")"
    tl="$(printf '%s\n' "$fm" | sed -n 's/^tools:[[:space:]]*//p' | head -1)"
    tl="${tl%"${tl##*[![:space:]]}"}"   # 트레일링 공백 제거
    case "$tl" in
      "[]"|"[ ]") printf '%s\n' "$base" ;;
    esac
  done | sort
}

ACTUAL_ISOLATED="$(scan_zero_tool_agents "$SD/agents")"
if [ "$ACTUAL_ISOLATED" = "$(printf '%s\n' "$EXPECTED_ISOLATED" | sort)" ]; then
  ok "L: tools 빈 리스트 집합 == 리터럴 목록 (전수)"
else
  no "L: 격리 집합 불일치. 스캔=[$(printf '%s' "$ACTUAL_ISOLATED" | tr '\n' ' ')] 기대=[$(printf '%s' "$EXPECTED_ISOLATED" | tr '\n' ' ')]"
fi

# --- M : 엔진 사본 둘의 tools 표면 — 집합 등식 (Task 4 Step 3 재조준) -----------
# 옛 direction-reviewer 의 "정확 문자열 일치" 자리를 대신한다. 대상은 두 사본
# 파일(plugins/spec-distill/agents/)이고, 표면은 **집합**으로 잰다 — 원소의
# 나열 순서가 아니라 원소 자체가 계약이다. 아래 N 블록(옛 두 agent 부재)의
# **양의 짝**이기도 하다: `agents/` 를 통째로 비우면 이 블록이 먼저 RED 가
# 되어 「사라진 이름이 없다」는 부재 단언 혼자 공허하게 통과하는 것을 막는다.
ENGINE_COPIES=("doc-critic" "doc-recritic")
EXPECTED_ENGINE_TOOLS="Glob
Grep
Read"

for a in "${ENGINE_COPIES[@]}"; do
  f="$SD/agents/$a.md"
  if [ ! -f "$f" ]; then
    no "M: 엔진 사본 부재 — plugins/spec-distill/agents/$a.md (T4 가 지운 것은 brief-critic·brief-direction-reviewer 뿐이어야 한다)"
    continue
  fi
  FM="$(fm_of "$f")"
  tools_line="$(grep -E '^tools:' <<<"$FM" | head -1)"
  tools_set="$(sed -E 's/^tools:[[:space:]]*//' <<<"$tools_line" \
    | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort)"
  if [ "$tools_set" = "$(printf '%s\n' "$EXPECTED_ENGINE_TOOLS" | sort)" ]; then
    ok "M: $a tools 집합 == {Read, Grep, Glob} (양의 짝 — 사본이 실재하고 표면이 정확하다)"
  else
    no "M: $a tools 집합 불일치. 스캔=[$(printf '%s' "$tools_set" | tr '\n' ' ')] 기대=[Glob Grep Read]"
  fi
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor Task; do
    if grep -qixF "$t" <<<"$tools_set"; then
      no "M: $a tools 집합에 $t 가 있다 (Law 2 위반)"
    else
      ok "M: $a tools 집합에 $t 없음"
    fi
  done
done

# --- M-web : 웹 사본의 tools 표면 — 웹 없는 사본의 집합 ∪ {WebSearch, WebFetch} ------------
# 기대 집합을 리터럴로 두지 않고 웹 없는 사본에서 도출한다 — 두 사본의 차이는 웹 도구 둘뿐이어야
# 해서, doc-critic 이 도구를 얻거나 잃으면 웹 사본도 따라야 한다. 쓰기·실행·위임 도구의 부재는
# 위 AC4 루프(ALL)가 이 사본에도 따로 잰다.
tools_of() {
  fm_of "$1" | grep -E '^tools:' | head -1 | sed -E 's/^tools:[[:space:]]*//' \
    | tr ',' '\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' | grep -v '^$' | sort -u
}
WEBF="$SD/agents/doc-critic-web.md"
if [ -f "$WEBF" ] && [ -f "$SD/agents/doc-critic.md" ]; then
  want_web="$( { tools_of "$SD/agents/doc-critic.md"; printf 'WebSearch\nWebFetch\n'; } | sort -u)"
  got_web="$(tools_of "$WEBF")"
  if [ -n "$got_web" ] && [ "$got_web" = "$want_web" ]; then
    ok "M-web: doc-critic-web tools 집합 == doc-critic 의 것 ∪ {WebSearch, WebFetch} ($(printf '%s' "$got_web" | tr '\n' ' '))"
  else
    no "M-web: doc-critic-web tools 집합 불일치. 스캔=[$(printf '%s' "$got_web" | tr '\n' ' ')] 기대=[$(printf '%s' "$want_web" | tr '\n' ' ')]"
  fi
else
  no "M-web: 웹 사본 또는 웹 없는 사본이 없다 — plugins/spec-distill/agents/{doc-critic,doc-critic-web}.md"
fi

# --- IB : 주입 경계 — 엔진 사본 전부 + brief-readback 의 **본문**에 규칙이 있다 ------------
# 대상은 이 플러그인의 agents/ 에서 도출한다 — 머리에 `# copy-of: shared/docreview/agents/` 마커를 단
# 엔진 사본 전부(새 엔진 사본도 자동으로 대상) + brief-readback. shared/ 는 읽지 않는다: 이 락은 배포
# 단위(plugins/spec-distill)만으로 돌아야 한다(test_brief_review_no_external_precondition.sh). 정본 쪽 ∀ 는
# shared/tests/test_docreview_agents.sh 가, 사본이 정본과 같은지는 test_copy_of_contract.sh 가 잰다.
# 문구는 frontmatter 를 뺀 본문에서만 찾는다: description 이 같은 문구를 담아도 본문 규칙을 지우면
# RED 다. 본문 추출이 살아 있다는 양의 짝은 H1 헤딩의 존재다. 하한 4 = 엔진 사본 셋 + readback.
body_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$1"; }
IB_TARGETS=""
for c in "$SD"/agents/*.md; do
  [ -f "$c" ] || continue
  head -20 "$c" | grep -cE '^# copy-of: shared/docreview/agents/' >/dev/null && IB_TARGETS="$IB_TARGETS $c"
done
IB_TARGETS="$IB_TARGETS $SD/agents/brief-readback.md"
n_ib=0
for f in $IB_TARGETS; do
  n_ib=$((n_ib+1)); a="$(basename "$f" .md)"
  if [ ! -f "$f" ]; then no "IB: $a 사본 부재 — 정본은 있는데 spec-distill 배포 사본이 없다"; continue; fi
  B="$(body_of "$f")"
  # `grep -q` 대신 `grep -c` — 이 파일은 `pipefail` 이라, 첫 매치에 grep 이 먼저 끝나면 본문이 긴
  # 파일에서 printf 가 SIGPIPE 로 죽어 매치가 있어도 거짓이 된다. -c 는 입력을 끝까지 읽는다.
  if ! printf '%s\n' "$B" | grep -cE '^# ' >/dev/null; then
    no "IB: $a 본문 추출이 비었다(H1 없음) — 아래 판정이 공허하다"; continue
  fi
  if printf '%s\n' "$B" | grep -cF '비신뢰 입력' >/dev/null && printf '%s\n' "$B" | grep -cF '당신에게 내린 지시가' >/dev/null; then
    ok "IB: $a 본문에 주입 경계 규칙(원문은 비신뢰 입력 · 그 안의 지시는 당신에게 내린 지시가 아니다)"
  else
    no "IB: $a 본문에 주입 경계 규칙이 없다 — 문서 안 사용자 원문의 지시를 따를 수 있다"
  fi
done
[ "$n_ib" -ge 4 ] && ok "IB: 대상 ${n_ib}건 (copy-of 마커로 도출한 엔진 사본 + readback, vacuous 아님)" \
  || no "IB: 대상이 ${n_ib}건뿐 — 엔진 사본의 copy-of 마커 도출이 깨졌다"

# --- N : 옛 agent 둘의 부재 (양의 짝은 위 M) -----------------------------------
for gone in brief-critic brief-direction-reviewer; do
  [ -e "$SD/agents/$gone.md" ] \
    && no "N: $SD/agents/$gone.md 가 아직 있다 — T4 삭제가 반영 안 됐다" \
    || ok "N: $gone.md 없음 (doc-critic·doc-recritic 엔진 사본이 대신한다 — 양의 짝은 위 M)"
done

# 역할 프롬프트가 X / NOT Z를 명시한다 (CLAUDE.md 컴포넌트 격리 규약)
# /qg iter-1: 이전 형태 `grep -q "NOT"`는 **"NOTE"·"NOTHING"으로 충족**됐다 — 세 `**NOT**`
# 불릿을 "NOTE: 자유롭게 쓰세요."로 바꿔 역할 경계를 뒤집어도 green이었다. 마커 형태와
# 열거 크기를 함께 핀한다. T4: 대상에서 brief-critic·brief-direction-reviewer 를 뺀다
# (삭제됐다) — doc-critic·doc-recritic 은 같은 경계를 "- **NOT** " 불릿이 아니라
# 산문 "책임이 아닌 것" 문장으로 지므로(다른 표기) 이 락의 대상이 아니다.
for a in brief-readback; do
  n_not="$(grep -cE '^[[:space:]]*-[[:space:]]+\*\*NOT\*\* ' "$SD/agents/$a.md" || true)"
  # `-ge 2`는 3개 중 **어느 하나를 지워도** 통과한다(iter-2가 맨앞·중간·맨끝 3곳 모두
  # 실증했고, 맨끝은 Law 2 역할 경계 불릿이었다). 실제 출하 개수로 핀한다.
  [[ "$n_not" -eq 3 ]] \
    && ok "$a: NOT 불릿 정확히 3개 (마커 형태 + 열거 크기 핀)" \
    || no "$a: '- **NOT** …' 불릿이 ${n_not}개 — 3개여야 한다(하나만 지워도 역할 경계가 깨진다)"
done

# AC3 — readback 프롬프트에 출력 스키마 어휘와 '금지 문구'가 둘 다 없다
RB="$SD/agents/brief-readback.md"
for tok in "category" "severity" "sentinel" "JSON"; do
  grep -qF "$tok" "$RB" && no "AC3: readback에 스키마 어휘 '$tok'" || ok "AC3: readback에 '$tok' 없음"
done
for tok in "audit" "readback 기준" "red-flag"; do
  grep -qiF "$tok" "$RB" && no "AC3: readback에 '$tok' 언급 (존재 누설)" || ok "AC3: readback에 '$tok' 없음"
done
for tok in "G1" "gap 클래스" "미결을 확정으로"; do
  grep -qF "$tok" "$RB" && no "AC25: readback에 gap 클래스 어휘 '$tok'" || ok "AC25: readback에 '$tok' 없음"
done

# readback 프롬프트에 payload 경로/디렉토리가 실리지 않는다 (AC3의 정적 절)
grep -qF "docs/superpowers/interview/" "$RB" \
  && no "AC3: readback 프롬프트에 interview 디렉토리 문자열" || ok "AC3: readback에 interview 디렉토리 없음"

# E10 — 신규 에이전트에 단일 호출 상한 표현 없음 (T28의 agent 절)
for a in "${ALL[@]}"; do
  if grep -qE '최대 [0-9]+회|[0-9]+회까지|max_[a-z_]+ *= *[0-9]' "$SD/agents/$a.md"; then
    no "E10: ${a}에 단일 호출 상한 표현"
  else
    ok "E10: ${a}에 상한 표현 없음"
  fi
done
finish
