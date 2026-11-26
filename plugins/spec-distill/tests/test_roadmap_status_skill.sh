#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/roadmap-status/SKILL.md
# roadmap-status 인자 거절 문장 락. 정적 락이다 — 모델이 이 글을 따르는지는 tests/evals/roadmap-status-arg-reject 가 손으로 잰다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_roadmap_status_skill.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: roadmap-status 글 하나
  echo "plugins/spec-distill/skills/roadmap-status/SKILL.md"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
SK="$SD/skills/roadmap-status/SKILL.md"
REL="plugins/spec-distill/skills/roadmap-status/SKILL.md"
EVAL="plugins/spec-distill/tests/evals/roadmap-status-arg-reject"

# 「### N. 지도 내기」 절만 뽑아 한 줄로 편다(줄을 갈라도 같은 문장).
SEC="$(awk '/^### [0-9.]+ 지도 내기$/{f=1;next} f&&/^##+ /{exit} f' "$SK" 2>/dev/null | tr '\n' ' ' | tr -s ' ')"

case "$SEC" in
  *'$ARGUMENTS'*) ok "계측기: 「지도 내기」 절을 뽑았고 거기에 \$ARGUMENTS 가 있다" ;;
  *) no "계측기: ${REL} 에서 「지도 내기」 절을 못 뽑았다(또는 \$ARGUMENTS 가 없다) — 아래 단언이 공허하다. 손 검사: ${EVAL}" ;;
esac
case "$SEC" in
  *'셸에 넘기지 않'*) ok "인자 거절 문장: 「셸에 넘기지 않」 이 「지도 내기」 절 안에 있다" ;;
  *) no "인자 거절 문장: ${REL} 의 「지도 내기」 절에 「셸에 넘기지 않」 이 없다 — 인자 검증 문장이 지워졌거나 절 밖으로 옮겨졌다. 손 검사: ${EVAL}" ;;
esac

finish
