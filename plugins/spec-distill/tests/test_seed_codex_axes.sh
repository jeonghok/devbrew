#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/* plugins/spec-distill/agents/* plugins/spec-distill/skills/framing-requests/SKILL.md shared/docreview/scripts/*
#
# seed 자리의 리뷰는 문서 리뷰 엔진이 진다 — 옛 전용 파일 넷(격리 critic · codex 러너 · codex 프롬프트
# 빌더 · 억제 체크리스트)이 없고, 그 자리를 엔진이 실제로 채운다(설계 2026-09-16-framing-intent-drift
# §5.4 · AC4 — 재설계 PR 5).
#
# 부재만 재면 디렉토리를 통째로 비워도 GREEN 이다. 그래서 엔진 배포 링크 둘과 SKILL 의 배선(codex
# 게이트 마커 · 러너 호출 · 엔진 탐지기 · 재비판기 dispatch · 처분 앵커)을 양의 짝으로 함께 잰다.
# 넷은 «삭제»다(소유자 이동이 아니다): 억제 네 범주는 seed 프로필 층 1 이 지고
# (shared/tests/test_docreview_profiles.sh), codex 프롬프트는 엔진 러너가 프로필 본문을 실어 조립한다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD_REL="plugins/spec-distill"; SD="$REPO_ROOT/$SD_REL"
SKILL_REL="$SD_REL/skills/framing-requests/SKILL.md"
GONE="agents/seed-critic.md scripts/run_seed_codex_reviewer.sh scripts/build_seed_codex_prompt.py scripts/seed-codex-suppression-checklist.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  for g in $GONE; do echo "$SD_REL/$g"; done
  echo "$SD_REL/scripts/run_docreview_codex_reviewer.sh"
  echo "$SD_REL/scripts/docreview_route.py"
  echo "$SKILL_REL"
  echo "shared/docreview/scripts/run_docreview_codex_reviewer.sh"
  echo "shared/docreview/scripts/docreview_route.py"
  exit 0
fi
. "$REPO_ROOT/shared/tests/assert.sh"

for g in $GONE; do
  if [ -e "$SD/$g" ] || [ -L "$SD/$g" ]; then no "옛 seed 파일이 남았다: $SD_REL/$g"
  else ok "옛 seed 파일 부재: $SD_REL/$g"; fi
done
left="$(find "$SD/scripts" "$SD/agents" -maxdepth 1 \( -name 'run_seed_codex*' -o -name 'build_seed_codex*' \
          -o -name 'seed-codex-*' -o -name 'seed-critic*' \) 2>/dev/null)"
[ -z "$left" ] && ok "seed 전용 codex 러너 · 빌더 · 체크리스트 · 격리 critic 0개 (이름을 바꿔 되살아나지 않았다)" \
  || no "seed 전용 파일이 남았다: $(printf '%s' "$left" | tr '\n' ' ')"

# ── 양의 짝 — 엔진이 그 자리를 채운다 ────────────────────────────────────────
resolve() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
for spec in "run_docreview_codex_reviewer.sh:shared/docreview/scripts/run_docreview_codex_reviewer.sh" \
            "docreview_route.py:shared/docreview/scripts/docreview_route.py"; do
  lnk="$SD/scripts/${spec%%:*}"; want="$REPO_ROOT/${spec#*:}"
  if [ -L "$lnk" ] && [ -f "$want" ] && [ "$(resolve "$lnk")" = "$(resolve "$want")" ]; then
    ok "엔진 배포 링크 살아 있음: $SD_REL/scripts/${spec%%:*}"
  else
    no "엔진 배포 링크가 없거나 정본을 가리키지 않는다: $SD_REL/scripts/${spec%%:*}"
  fi
done
SKILL="$REPO_ROOT/$SKILL_REL"
if [ ! -f "$SKILL" ]; then no "framing-requests SKILL.md 부재"; finish; exit; fi
grep -qE '<!--[[:space:]]*codex-gate:begin[[:space:]]+runner=run_docreview_codex_reviewer\.sh' "$SKILL" \
  && ok "framing-requests: codex 게이트 마커가 엔진 러너를 댄다" || no "framing-requests: codex 게이트 마커가 엔진 러너를 대지 않는다"
grep -qF 'bash "$SD/scripts/run_docreview_codex_reviewer.sh" "$PROFILE" "$BUNDLE"' "$SKILL" \
  && ok "framing-requests: 엔진 러너를 탐지 번들로 부른다" || no "framing-requests: 엔진 러너 호출이 없다"
grep -qF 'subagent_type: "spec-distill:doc-critic"' "$SKILL" \
  && ok "framing-requests: 탐지는 엔진 탐지기(doc-critic)" || no "framing-requests: 엔진 탐지기 dispatch 가 없다"
grep -qF 'subagent_type: "spec-distill:doc-recritic"' "$SKILL" \
  && ok "framing-requests: 재비판은 엔진 재비판기(doc-recritic)" || no "framing-requests: 엔진 재비판기 dispatch 가 없다"
grep -qF 'consumer=plugins/spec-distill/scripts/docreview_route.py' "$SKILL" \
  && ok "framing-requests: 발견의 처분 소비자가 엔진 라우터다" || no "framing-requests: 처분 앵커가 엔진 라우터를 대지 않는다"
finish
