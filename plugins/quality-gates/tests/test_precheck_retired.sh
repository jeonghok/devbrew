#!/usr/bin/env bash
# A21 — pre-pipeline-check 은퇴 후, "스크립트가 낼 수 있는 결과 코드" 와
# "SKILL 이 처리하는 결과 코드" 두 집합이 같다 (둘 다 공집합).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
FAIL=0
ok() { echo "  ✓ $1"; }
no() { echo "  ✗ $1"; FAIL=1; }
SK=plugins/quality-gates/skills/quality-pipeline/SKILL.md

[[ ! -e plugins/quality-gates/scripts/pre-pipeline-check.sh ]] \
  && ok "스크립트 부재" || no "pre-pipeline-check.sh 가 남아 있다"

# 양의 짝 — SKILL 이 그 스크립트를 호출하지 않는다.
grep -q 'pre-pipeline-check' "$SK" \
  && no "SKILL.md 가 아직 pre-pipeline-check 를 부른다" \
  || ok "SKILL.md 에 호출 없음"

# 음의 짝 — 결과 코드 이름이 SKILL 에 유령으로 남아 있지 않다. 양의 짝(호출 부재)은
# 표만 남기고 호출을 지운 상태를 통과시킨다. 그 표는 아무도 채우지 않는 계약이 된다.
GHOST=0
for c in cleared_branch_mismatch cleared_stale fresh_start no_session_data active_resume; do
  if grep -q "$c" "$SK"; then echo "    유령 코드: $c"; GHOST=1; fi
done
[[ $GHOST -eq 0 ]] && ok "SKILL.md 에 유령 결과 코드 없음" || no "SKILL.md 에 유령 결과 코드가 남았다"

# 양성 대조 — setup-qg.sh 의 SID abort 계약은 그대로다 (GREEN 이 정답).
grep -q 'fails pattern guard' plugins/quality-gates/scripts/setup-qg.sh \
  && ok "양성 대조: setup-qg.sh SID 패턴 가드 생존" \
  || no "양성 대조 실패: setup-qg.sh 의 SID 가드가 사라졌다"

# branch.md 는 생산자·소비자가 그 스크립트 자신뿐이었다. 이 락 파일 자신의
# 주석·메시지는 문구상 "branch.md"를 담을 수밖에 없으므로 자기참조로 제외한다
# (CHANGELOG.md를 역사 기록으로 제외하는 것과 같은 이유).
grep -rq 'branch\.md' plugins/quality-gates --include='*.sh' --include='*.py' --include='*.md' \
  --exclude=CHANGELOG.md --exclude=test_precheck_retired.sh --exclude-dir=fixtures \
  && no "branch.md 참조가 남았다" || ok "branch.md 참조 0"

exit $FAIL
