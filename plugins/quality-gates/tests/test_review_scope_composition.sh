#!/usr/bin/env bash
# test_review_scope_composition.sh — AC11 · spec §2: v10 리뷰어 구성.
#
# 기본 셋(code-reviewer · security-reviewer · codex) + 조건부 넷(pr-test-analyzer ·
# silent-failure-hunter · type-design-analyzer · comment-analyzer) + 재비판(code-recritic).
# `scout.py` · `feature-dev:code-architect` 는 qg 어디에서도 dispatch 되지 않는다(AC11).
# body-unique 문구를 요구한다(헤더-satisfiable 함정 회피). 선택 정확성은 게이트하지 않는다.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SKILL="$ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"
QG="$ROOT/plugins/quality-gates"
. "$ROOT/shared/tests/assert.sh"

# Step 3 창 — 구성 표와 dispatch 가 사는 자리
S3="$(awk '/^### Step 3 — reviewers/{f=1;next} f&&/^### /{exit} f' "$SKILL")"
[ -n "$S3" ] && ok "Step 3 창을 찾았다" || { no "Step 3 창이 없다 — 아래가 공허하다"; finish; exit; }

for row in '| 정확성 | `pr-review-toolkit:code-reviewer` | 항상 |' \
           '| 보안 | `quality-gates:security-reviewer` | 항상 |' \
           '| 다른 모델 계열 | codex 러너 | 항상 시도 |' \
           '| 재비판 | `quality-gates:code-recritic` | 항상(탐지 0건이어도) — Step 3.5 |'; do
  assert_contains "$S3" "$row" "구성 표 행: $row"
done
for a in pr-test-analyzer silent-failure-hunter type-design-analyzer comment-analyzer; do
  assert_grep "$S3" "^\| [^|]+ \| \`pr-review-toolkit:$a\` \| [^|]{12,} \|$" "조건부 행 — $a 가 신호 규칙을 갖는다"
done
assert_contains "$S3" '> [quality-gates] iter N — 선택:' "transparency 줄"
assert_contains "$S3" 'unavailable (<plugin> 미설치) — degraded coverage' "미설치 degrade 는 loud"
assert_not_grep "$S3" '^[[:space:]]*model:' "외부 dispatch 에 model: override 가 없다"

# AC11 — 옛 구성의 부재(플러그인 표면 전체). 양의 짝은 위 표 행이다.
hits="$(grep -rlE 'scout\.py|feature-dev:code-architect' "$QG/skills" "$QG/commands" "$QG/agents" "$QG/scripts" "$QG/references" 2>/dev/null)"
assert_eq "$hits" "" "scout.py · feature-dev:code-architect 를 부르는 표면이 없다 (AC11)"
[ -e "$QG/scripts/scout.py" ] && no "scripts/scout.py 가 남아 있다" || ok "scripts/scout.py 부재"
assert_not_grep "$(cat "$SKILL")" 'depth|quick-depth|scout' "줄 수 depth 안내가 없다"
for tok in '0-100' '0–100' '/100' 'code-simplifier' 'security-auditor' 'secret-masking'; do
  assert_not_grep "$(cat "$SKILL")" "$tok" "non-goal 토큰 부재: $tok"
done
finish
