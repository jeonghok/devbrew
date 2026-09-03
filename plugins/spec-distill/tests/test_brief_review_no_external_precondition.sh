#!/usr/bin/env bash
# B1 — 배포 단위 밖 파일(docs/audits/…) 없이도 brief 리뷰 격리 락이 도는가.
#
# 양성 증인을 먼저 세운다: 감사 파일이 **없는** 임시 리포 루트에서 격리 락이
# 실제로 **실행되고 통과**하는가. 그다음에야 SKILL 본문에 그 경로 참조가 없음을
# 묻는다. 부재만 보는 단언은 대상을 통째로 지워도 통과한다.
#
# 격리 설치(CLAUDE_CONFIG_DIR)를 쓰지 않는 이유: 재는 것이 "플러그인이 자기 배포
# 단위 밖 파일을 실행 시점에 읽는가" 하나이고, 그 조건은 docs/audits/ 를 빼고
# 복사한 임시 루트로 정확히 재현된다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"

T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/plugins" "$T/shared"
cp -R "$REPO_ROOT/plugins/spec-distill" "$T/plugins/"
cp -R "$REPO_ROOT/shared/tests" "$T/shared/"
# 의도적으로 docs/audits/ 를 만들지 않는다 — 이것이 이 테스트의 전제다.
test ! -d "$T/docs/audits" && ok "전제: 임시 루트에 docs/audits/ 가 없다" \
  || no "전제 붕괴 — 임시 루트에 감사 디렉토리가 생겼다"

# (1) 양성 증인 — 감사 파일 없는 루트에서 격리 락이 **돌고 통과**한다.
OUT="$(cd "$T" && bash "$T/plugins/spec-distill/tests/test_brief_agents.sh" 2>&1)"; RC=$?
[ "$RC" -eq 0 ] && ok "감사 파일 없는 루트에서 test_brief_agents.sh 가 통과 (선결조건 없음)" \
  || { no "감사 파일 없는 루트에서 격리 락이 실패 (rc=$RC) — 배포 단위 밖 선결조건이 남아 있다"; printf '%s\n' "$OUT" | tail -20; }

# (2) 양성 증인 — 그 실행이 실제로 격리를 **검사했다** (빈 통과가 아니다).
grep -qF 'tools' <<<"$OUT" && ok "그 실행이 tools 표면을 실제로 검사했다" \
  || no "출력에 tools 검사 흔적이 없다 — 락이 조기 종료했을 수 있다"

# (3) 양성 증인 — 그 절이 사라졌어도 충실도 hard gate 서술은 남아 있다. 부재
# 단언보다 먼저 둔다 — 설정이 통째로 무너져도(예: SKILL 파일이 비어버려도) 부재
# 단언은 공허하게 통과하지만, 이 증인은 그때 함께 RED가 되어 조용한 통과를 막는다.
SKILL="$REPO_ROOT/plugins/spec-distill/skills/reviewing-brief/SKILL.md"
grep -qF 'hard gate' "$SKILL" \
  && ok "충실도 verdict 가 여전히 hard gate 로 서술된다 (차단력 유지)" \
  || no "hard gate 서술이 사라졌다 — 완화가 아니라 유지여야 한다"

# (4) 부재 — SKILL 본문이 실행 시점에 배포 단위 밖 경로를 읽지 않는다.
grep -qF 'docs/audits/' "$SKILL" \
  && no "reviewing-brief SKILL 이 여전히 docs/audits/ 경로를 참조한다 (N3 위반)" \
  || ok "reviewing-brief SKILL 에 배포 단위 밖 경로 참조 없음"

# (5) 근거 기록 자체는 지우지 않는다.
test -f "$REPO_ROOT/docs/audits/2026-07-27-spec-distill-zero-tool-probe.md" \
  && ok "probe 감사 문서는 근거 기록으로 남아 있다" \
  || no "감사 문서를 지웠다 — 지우는 것은 그것을 읽는 코드이지 기록이 아니다"
finish
