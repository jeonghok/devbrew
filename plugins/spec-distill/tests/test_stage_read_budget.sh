#!/usr/bin/env bash
# guards: plugins/spec-distill/skills/intent-sync/SKILL.md plugins/spec-distill/skills/context-build/SKILL.md plugins/spec-distill/skills/context-build/references/finishing.md plugins/spec-distill/skills/roadmap-draft/*
# AC37 — 가른 뒤 각 단계가 읽는 글의 줄 수가 가르기 전에 읽던 양보다 늘지 않는다(방향 기준).
# 기준 줄 수는 가르기 전 트리에서 잰 값이다(계획 1 과제 1): 의도 쪽 진입 skill 본문 1523 · 인터뷰 진입 skill 본문 617 + 끝맺음 절차 970 = 1587.
# 앞뒤를 같은 묶음으로 잰다 — 인터뷰의 다른 reference 는 앞뒤 모두 세지 않는다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_stage_read_budget.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$ROOT/plugins/spec-distill"
if [ "${1:-}" = "--emit-scanned" ]; then   # 읽는 파일: 두 단계의 본문 + 끝맺음 절차 + 로드맵 잡기 추적 파일 전부
  printf '%s\n' plugins/spec-distill/skills/intent-sync/SKILL.md plugins/spec-distill/skills/context-build/SKILL.md plugins/spec-distill/skills/context-build/references/finishing.md
  git -C "$ROOT" ls-files -- 'plugins/spec-distill/skills/roadmap-draft/*'
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
BASE_INTENT=1523
BASE_INTERVIEW=1587
lines() {   # lines <spec-distill 아래 경로...> → 줄 수 합(파일이 없으면 빈 값 — 아래 단언이 실패한다)
  local f n=0 c
  for f in "$@"; do
    [ -f "$SD/$f" ] || { printf ''; return; }
    c="$(wc -l < "$SD/$f" | tr -d ' ')"; n=$((n + c))
  done
  printf '%s' "$n"
}
le() {   # le <잰 값> <기준> <라벨>
  case "$1" in ''|*[!0-9]*) no "$3: 잴 수 없다(파일 없음)"; return ;; esac
  [ "$1" -gt 0 ] || { no "$3: 0 줄 — 잰 묶음이 비었다"; return; }
  [ "$1" -le "$2" ] && ok "$3: $1 ≤ $2" || no "$3: $1 > $2"
}
le "$(lines skills/intent-sync/SKILL.md)" "$BASE_INTENT" "AC37: 의도 싱크 본문"
le "$(lines skills/context-build/SKILL.md skills/context-build/references/finishing.md)" "$BASE_INTERVIEW" "AC37: 컨텍스트 쌓기 본문 + 끝맺음 절차"
RD="$(git -C "$ROOT" ls-files 'plugins/spec-distill/skills/roadmap-draft/*' | sed 's#^plugins/spec-distill/##')"
[ -n "$RD" ] && ok "AC37: 로드맵 잡기 추적 파일 $(printf '%s\n' "$RD" | grep -c .)개" || no "AC37: 로드맵 잡기 추적 파일이 없다 — 아래 단언이 공허하다"
# shellcheck disable=SC2086
le "$(lines $RD)" "$BASE_INTERVIEW" "AC37: 로드맵 잡기 파일 전부"
finish
