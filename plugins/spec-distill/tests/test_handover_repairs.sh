#!/usr/bin/env bash
# guards: plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/scripts/workflow_superpowers.py plugins/spec-distill/skills/roadmap-draft/* plugins/spec-distill/skills/context-build/references/finishing.md plugins/spec-distill/scripts/build_brief_bundle.py plugins/spec-distill/skills/reviewing-brief/SKILL.md plugins/spec-distill/skills/context-build/SKILL.md plugins/spec-distill/references/docreview-profiles/brief.md plugins/spec-distill/agents/coverage-mapper.md
# 넘겨받은 수리의 글 — 에픽 넘김 줄 라벨과 낡은 문장 · 로드맵 잡기의 멈춤 갈래와 이미 커밋된 로드맵 · 구조 멈춤의 고칠 자리 ·
# 종료 2 목록 · 정보 여섯 칸의 자리 · 결과물 리뷰 기준 다섯 문장 · 범위 조사 agent 의 데이터 문장.
# 정적 락이다 — 모델이 이 글을 실제로 따르는지는 재지 못한다. 여섯 칸 절만 구조 게이트를 실제로 돌린다.
# 글자 확인은 뜻을 싣는 가장 짧은 낱말을 문다(docs/testing.md 「글을 무는 확인」).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_handover_repairs.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
FILES=(
  plugins/spec-distill/references/epic-handoff.md
  plugins/spec-distill/scripts/workflow_superpowers.py
  plugins/spec-distill/skills/roadmap-draft/SKILL.md
  plugins/spec-distill/skills/roadmap-draft/references/pr-merge.md
  plugins/spec-distill/skills/context-build/references/finishing.md
  plugins/spec-distill/scripts/build_brief_bundle.py
  plugins/spec-distill/skills/reviewing-brief/SKILL.md
  plugins/spec-distill/skills/context-build/SKILL.md
  plugins/spec-distill/references/docreview-profiles/brief.md
  plugins/spec-distill/agents/coverage-mapper.md
)
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "${FILES[@]}"
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1

has()   { [ -s "$ROOT/$1" ] || { no "$3 — 파일이 없거나 비었다 ($1)"; return; }
          grep -qF -- "$2" "$ROOT/$1" && ok "$3" || no "$3 — 없다: «$2» ($1)"; }
lacks() { [ -s "$ROOT/$1" ] || { no "$3 — 파일이 없거나 비었다 — 부재 단언이 공허하다 ($1)"; return; }
          grep -qF -- "$2" "$ROOT/$1" && no "$3 — 남아 있다: «$2» ($1)" || ok "$3"; }
count() { grep -oF -- "$2" "$ROOT/$1" 2>/dev/null | wc -l | tr -d ' '; }

# ── 과제 2 — 에픽 넘김 줄 라벨 · 낡은 문장 (AC33) ─────────────────────────────────
EH=plugins/spec-distill/references/epic-handoff.md
WS=plugins/spec-distill/scripts/workflow_superpowers.py
lacks "$EH" '사용자 선호:' "AC33: 에픽 넘김 줄 파일에 「사용자 선호:」 라벨이 없다"
lacks "$WS" '사용자 선호:' "AC33: 자리 문장을 내는 스크립트에 「사용자 선호:」 라벨이 없다"
assert_eq "$(count "$EH" '설계문서를 쓰는 크기다')" "2" \
  "AC33(양의 짝): 라벨을 뗀 크기 문장이 넘김 줄 둘(옛 형식 · team 형식)에 남았다"
assert_eq "$(count "$EH" '질문을 건너뛰어도 설계문서를 쓰고')" "2" \
  "AC33(양의 짝): 크기 문장의 행동 절(질문을 건너뛰어도 설계문서)이 넘김 줄 둘에 남았다"
assert_eq "$(count "$EH" 'spec-review 를 거친다')" "2" \
  "AC33(양의 짝): 크기 문장의 행동 절(spec-review 를 거친다)이 넘김 줄 둘에 남았다"
has "$WS" '설계문서는 기본 자리 대신' "AC33(양의 짝): 설계문서 자리 문장이 라벨 없이 남았다"
has "$WS" '계획은 기본 자리 대신' "AC33(양의 짝): 계획 자리 문장이 라벨 없이 남았다"
lacks "$EH" '과 같은 모양이고' "AC33: 머리 문단의 낡은 문장(brief 흐름의 다음 세션 줄과 같은 모양)이 없다"
has "$EH" 'brief-handoff.md' "AC33(양의 짝): 머리 문단이 지금의 brief 넘김 파일을 가리킨다"
has "$EH" '지시 절을 가리키고' "AC33(양의 짝): 머리 문단이 그 파일의 지시 절을 가리킨다"

# ── 과제 4 — 로드맵 잡기 진입의 §7 값 멈춤 갈래 ─────────────────────────────────────
RD=plugins/spec-distill/skills/roadmap-draft/SKILL.md
has "$RD" '로드맵 경로나 자리면 결과물 쪽 결함' \
  "§7 값의 꼴: 진입 STOP 이 결과물 쪽 결함 갈래로 간다"
has "$RD" '분해됨 줄의 로드맵 경로나 자리면 결과물 쪽 결함이다 — 위험 줄 번호와 같이' \
  "§7 값의 꼴(양의 짝): 같은 길 둘 갈래를 위험 줄 번호와 함께 가리킨다"

finish
