#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# seed `@경로` 핸드오프 — framing 게이트(`/new`·`/compact` → `/interview @<seed 경로>`) ·
# 공유 계약의 권장/차선 핸드오프 · `/interview` Step 1.5 · 옛 호출 모양 부재 · 이름 가드 공백 거부.
#
# 정본 `references/proceed-gate.md` 에 대한 단언은 **정본 자체**를 대상으로 한다 — 채택자
# presence 코퍼스에 정본을 넣는 것이 아니다(그 코퍼스 규칙은 test_proceed_gate_adopters.sh 에 있다).
# 부재 단언에는 코퍼스를 실제로 읽었다는 양성 짝이 붙는다.
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
SK="$SD/skills/framing-requests/SKILL.md"
CANON="$SD/references/proceed-gate.md"
CMD="$SD/commands/interview.md"
RF="$SD/commands/request-framing.md"
README="$SD/README.md"
. "$ROOT/shared/tests/assert.sh"

# 부재 코퍼스: CHANGELOG 와 tests/ 를 뺀 이 플러그인의 문서 전부(추적 + 미추적).
CORPUS=()
while IFS= read -r f; do
  [ -n "$f" ] && CORPUS+=("$ROOT/$f")
done < <(cd "$ROOT" && git ls-files --cached --others --exclude-standard -- 'plugins/spec-distill/*.md' \
  | grep -vE '^plugins/spec-distill/(CHANGELOG\.md$|tests/)')

if [ "${1:-}" = "--emit-scanned" ]; then
  for f in "${CORPUS[@]+"${CORPUS[@]}"}"; do printf '%s\n' "${f#"$ROOT"/}"; done
  exit 0
fi

# 헤딩 블록: 시작 ERE 줄부터 다음 멈춤 ERE 줄 전까지.
block() { awk -v s="$1" -v e="$2" '$0 ~ s {f=1; print; next} f && $0 ~ e {f=0} f' "$3"; }
flat()  { tr '\n' ' ' | tr -s ' '; }

# ── /interview Step 1.5 와 「풀린 입력」 ───────────────────────────────────
l15="$(grep -n '^## Step 1[.]5' "$CMD" | head -1 | cut -d: -f1)"
l2="$(grep -n '^## Step 2: ' "$CMD" | head -1 | cut -d: -f1)"
if [ -n "$l15" ] && [ -n "$l2" ] && [ "$l15" -lt "$l2" ]; then
  ok "AC5: Step 1.5 가 Step 2 보다 앞에 있다 (${l15} < ${l2})"
else
  no "AC5: Step 1.5 가 Step 2 보다 앞에 있지 않다 (Step 1.5=${l15:-없음} Step 2=${l2:-없음})"
fi
s15="$(block '^## Step 1[.]5' '^## ' "$CMD" | flat)"
[ -n "$s15" ] && ok "AC5(양성): Step 1.5 블록을 읽었다" || no "AC5(양성): Step 1.5 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$s15" '`@` 로 시작하는 **공백 없는 한 토큰**일 때만' "AC5: 발동 조건 — 한 토큰 @"
assert_contains "$s15" '**절대경로로** Read 도구에 넘긴다' "AC5: 동작 — Read"
assert_contains "$s15" '줄번호·탭 접두를 뗀 **파일 원문 전체(frontmatter 포함)**' "AC5: 풀린 입력 = frontmatter 포함 파일 전문"
assert_contains "$s15" '「풀린 입력」의 출처는 이 Read 결과다' "§3: 첨부가 따로 와도 출처는 Read 결과"
assert_contains "$s15" '를 읽지 못했다(<관측한 사유>) — seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.' "AC5: 부재 문구"
assert_contains "$s15" '아래 문구를 내고 멈춘다. **인터뷰를 시작하지 않는다.**' "AC5: 정지 지시"
assert_contains "$s15" '발동하지 않았으면 「풀린 입력」은' "§3: 미발동이면 받은 입력 그대로"
s2="$(block '^## Step 2: ' '^## ' "$CMD" | flat)"
s25="$(block '^## Step 2[.]5' '^## ' "$CMD" | flat)"
s3="$(block '^## Step 3' '^## ' "$CMD")"
sa="$(block '^## Arguments' '^## ' "$CMD" | flat)"
assert_contains "$s2" '「풀린 입력」을 대조' "§3: Step 2 trivia 대조 대상 = 풀린 입력"
assert_contains "$s25" '「풀린 입력」의 frontmatter 에 `type: interview-seed`' "§3: Step 2.5 seed 판별 대상 = 풀린 입력"
assert_contains "$s3" 'Skill conducting-interview <풀린 입력>' "§3: Step 3 인자 = 풀린 입력"
assert_not_contains "$s3" 'Skill conducting-interview $ARGUMENTS' "§3: Step 3 가 치환된 원 인자를 넘기지 않는다"
assert_contains "$sa" '「풀린 입력」 — Step 1.5 의 결과' "§3: Arguments 절이 풀린 입력을 가리킨다"

finish
