#!/usr/bin/env bash
# guards: shared/docreview/agents/*.md
#
# 두 리뷰어 agent 의 frontmatter 계약 — 도구 표면(AC16, allowlist 단독) · recritic 슬롯 셋(AC9) ·
# model 키 부재(main 규약) · 두 agent 의 kind 어휘(대칭) · sentinel 펜스 이름·순서.
set -u
if [ "${1:-}" = "--emit-scanned" ]; then git ls-files -- 'shared/docreview/agents/*.md'; exit 0; fi
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"
export PYTHONDONTWRITEBYTECODE=1
A="$REPO_ROOT/shared/docreview/agents"
# eval() 안전 근거는 두 가지다: ① 여기서 eval 되는 문자열은 이 파일 안에 저자가 직접
# 적은 리터럴 파이썬 식뿐이다(호출부마다 하드코딩, 파일 내용·CLI 인자에서 식 자체가
# 오지 않는다) ② 비신뢰 데이터(파일 원문 `t`)는 그 식 「안에서」 값으로만 다뤄지고,
# 필드 접근(`["tools"]` 등) 전에 반드시 `yaml.safe_load(...)` 를 거친다 — 원문 자체를
# 실행하지 않는다. 형제 test_docreview_profiles.sh:32 도 같은 두 근거로 안전하지만
# 구조는 다르다: 그쪽은 **이미 파싱된** 데이터(`json.load` 의 결과 `d`)에 대해 eval
# 하고, 여기는 원시 텍스트 `t` 에 대해 `yaml.safe_load(...)` 호출 자체를 eval 되는 식
# 「안에」 넣어 돈다. 「형제와 같은 관용구」는 안전 근거가 아니다 — 같은 취약을 공유한다는
# 뜻일 수도 있다. 안전 근거는 위 ①·② 뿐이다.
fm() { python3 -c 'import sys,yaml; t=open(sys.argv[1],encoding="utf-8").read(); print(eval(sys.argv[2]))' "$1" "$2"; }
for a in doc-critic doc-recritic; do
  f="$A/$a.md"
  assert_eq "$(fm "$f" 'yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["tools"]')" "Read, Grep, Glob" "$a: tools = Read, Grep, Glob (Write/Edit/Bash 없음, AC16)"
  assert_not_grep "$(sed -n '/^---$/,/^---$/p' "$f")" '^model:' "$a: frontmatter 에 model 키 없음(main 규약)"
  # disallowedTools 는 tools: allowlist 와 나란히 있어도 금지다 — 그 키의 존재 자체가
  # 나중에 allowlist 를 지우고 denylist 만 남기는 경로를 연다(CLAUDE.md 컴포넌트 격리:
  # denylist 단독은 공간·시간 양쪽으로 fail-open). 양의 짝은 같은 루프의 "name 일치" —
  # frontmatter 가 실제로 파싱됐고 기대 이름을 담고 있음을 그 단언이 요구한다.
  assert_not_grep "$(sed -n '/^---$/,/^---$/p' "$f")" '^disallowedTools:' "$a: frontmatter 에 disallowedTools 키 없음(allowlist 단독 원칙)"
  assert_grep "$(sed -n '/^---$/,/^---$/p' "$f")" '^name: '"$a"'$' "$a: name 일치"
done
# recritic 슬롯 정확히 셋 (AC9)
SL="$(fm "$A/doc-recritic.md" '[s["tag"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]]')"
assert_eq "$SL" "['document', 'findings', 'profile']" "doc-recritic: 입력 슬롯 정확히 셋 — dispatch 사유·이력·출처 라벨 슬롯 없음 (AC9)"
KINDS="$(fm "$A/doc-recritic.md" 'sorted(set(s["kind"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]))')"
assert_eq "$KINDS" "['artifact', 'repo_context']" "doc-recritic: kind 는 artifact·repo_context 만 (prior_verdict·orchestrator_framing 없음)"
# critic 은 문서·프로필·(선택)이력 셋
CS="$(fm "$A/doc-critic.md" '[s["tag"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]]')"
assert_eq "$CS" "['document', 'profile', 'prior_finding_ids']" "doc-critic: 문서·프로필·이력(선택) 슬롯"
# critic 의 kind 어휘도 recritic 과 같은 강도로 잰다(대칭) — 이전에는 태그만 봐서
# prior_finding_ids 의 kind 가 어휘 밖 값으로 바뀌어도 조용했다.
CS_KINDS="$(fm "$A/doc-critic.md" 'sorted(set(s["kind"] for s in yaml.safe_load(t[4:t.find(chr(10)+"---"+chr(10),4)])["input_slots"]))')"
assert_eq "$CS_KINDS" "['artifact', 'repo_context', 'same_origin_history']" "doc-critic: kind 는 artifact·repo_context·same_origin_history 만 (recritic 과 대칭)"

# sentinel 펜스 이름·순서 — 라우터가 파싱할 블록의 존재 계약만 잰다(깊은 YAML 스키마
# 검증은 호출자가 생기는 PR 2·4 의 일 — 지금 얹으면 모양만 재게 된다).
assert_grep "$(cat "$A/doc-critic.md")" '^```docreview-layer1$' "doc-critic: sentinel docreview-layer1 존재"
assert_grep "$(cat "$A/doc-critic.md")" '^```docreview-layer2$' "doc-critic: sentinel docreview-layer2 존재"
CRIT_L1="$(grep -n '^```docreview-layer1$' "$A/doc-critic.md" | head -1 | cut -d: -f1)"
CRIT_L2="$(grep -n '^```docreview-layer2$' "$A/doc-critic.md" | head -1 | cut -d: -f1)"
if [ -n "${CRIT_L1:-}" ] && [ -n "${CRIT_L2:-}" ] && [ "$CRIT_L1" -lt "$CRIT_L2" ] 2>/dev/null; then
  ok "doc-critic: docreview-layer1 이 docreview-layer2 보다 먼저 나온다 (절차 계약 — 층 1 을 먼저 검토해 낸다)"
else
  no "doc-critic: docreview-layer1 이 docreview-layer2 보다 먼저 나오지 않는다 (L1=${CRIT_L1:-없음} L2=${CRIT_L2:-없음})"
fi
assert_grep "$(cat "$A/doc-recritic.md")" '^```docreview-recritic$' "doc-recritic: sentinel docreview-recritic 존재"
finish
