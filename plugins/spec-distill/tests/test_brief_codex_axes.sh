#!/usr/bin/env bash
# guards: plugins/spec-distill/scripts/* plugins/spec-distill/skills/reviewing-brief/SKILL.md shared/docreview/scripts/*
#
# brief 자리의 codex 축과 병합은 문서 리뷰 엔진이 진다 — 옛 전용 스크립트 다섯(병합기 ·
# codex 프롬프트 빌더 · codex 러너 · 축별 체크리스트 둘)이 없고, 그 자리를 엔진이 실제로
# 채운다.
#
# 부재 판정만으로는 `plugins/spec-distill/scripts/` 를 통째로 비워도 GREEN 이다. 그래서 같은
# 디렉토리의 엔진 배포 링크 둘(codex 러너 · 라우터)과 skill 의 배선(codex 게이트 마커 · 러너
# 호출 · 처분 앵커)을 양의 짝으로 함께 잰다 — 디렉토리가 비거나 skill 이 옛 파이프라인으로
# 돌아가면 이쪽이 RED 다.
#
# 다섯 이름은 «삭제»다(소유자 이동이 아니다): codex 프롬프트는 엔진 러너의 인라인 빌더가
# 프로필(`references/docreview-profiles/brief.md`) 본문을 실어 조립하고 — 옛 체크리스트의
# 내용은 그 본문이 진다(shared/tests/test_docreview_profiles.sh) — 병합·라우팅은
# `docreview_route.py` 가 한다. 같은 이름이 다른 뜻으로 돌아오면 이 락을 먼저 고친다.
#
# Run: bash plugins/spec-distill/tests/test_brief_codex_axes.sh
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD_REL="plugins/spec-distill"
SD="$REPO_ROOT/$SD_REL"
SKILL_REL="$SD_REL/skills/reviewing-brief/SKILL.md"
ENGINE_RUNNER_REL="shared/docreview/scripts/run_docreview_codex_reviewer.sh"
ENGINE_ROUTE_REL="shared/docreview/scripts/docreview_route.py"
GONE="merge_brief_review.py build_brief_codex_prompt.py run_brief_codex_reviewer.sh brief-codex-fidelity-checklist.md brief-codex-direction-checklist.md"

if [ "${1:-}" = "--emit-scanned" ]; then
  for g in $GONE; do echo "$SD_REL/scripts/$g"; done
  echo "$SD_REL/scripts/run_docreview_codex_reviewer.sh"
  echo "$SD_REL/scripts/docreview_route.py"
  echo "$SKILL_REL"
  echo "$ENGINE_RUNNER_REL"
  echo "$ENGINE_ROUTE_REL"
  exit 0
fi

. "$REPO_ROOT/shared/tests/assert.sh"

# ── 부재 ─────────────────────────────────────────────────────────────────────
for g in $GONE; do
  if [ -e "$SD/scripts/$g" ] || [ -L "$SD/scripts/$g" ]; then
    no "옛 파일이 남았다: $SD_REL/scripts/$g"
  else
    ok "옛 파일 부재: $SD_REL/scripts/$g"
  fi
done
# 이름을 바꿔 되살아나는 것도 막는다 — 전용 스크립트는 이름이 아니라 모양으로 찾는다.
priv="$(find "$SD/scripts" -maxdepth 1 \( -name 'run_brief_codex*' -o -name 'build_brief_codex*' \
          -o -name 'brief-codex-*' -o -name 'merge_brief*' \) 2>/dev/null)"
if [ -z "$priv" ]; then
  ok "brief 전용 codex 러너·빌더·체크리스트·병합기 0개"
else
  no "brief 전용 스크립트가 남았다: $(printf '%s' "$priv" | tr '\n' ' ')"
fi

# ── 양의 짝 — 엔진이 그 자리를 실제로 채운다 ────────────────────────────────
realpath_of() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
for pair in "run_docreview_codex_reviewer.sh|$ENGINE_RUNNER_REL" "docreview_route.py|$ENGINE_ROUTE_REL"; do
  name="${pair%%|*}"; canon="${pair#*|}"
  link="$SD/scripts/$name"
  if [ -L "$link" ] && [ -f "$REPO_ROOT/$canon" ] \
     && [ "$(realpath_of "$link")" = "$(realpath_of "$REPO_ROOT/$canon")" ]; then
    ok "엔진 배포 링크: $SD_REL/scripts/$name → $canon"
  else
    no "엔진 배포 링크가 없거나 정본을 가리키지 않는다: $SD_REL/scripts/$name (기대 → $canon)"
  fi
done

SKILL="$REPO_ROOT/$SKILL_REL"
if [ -f "$SKILL" ]; then
  grep -qE '<!--[[:space:]]*codex-gate:begin[[:space:]]+runner=run_docreview_codex_reviewer\.sh' "$SKILL" \
    && ok "reviewing-brief: codex 게이트 마커가 엔진 러너를 댄다" \
    || no "reviewing-brief: codex 게이트 마커가 엔진 러너를 대지 않는다"
  grep -qF 'bash "$SD/scripts/run_docreview_codex_reviewer.sh"' "$SKILL" \
    && ok "reviewing-brief: 엔진 러너를 배포 경로로 부른다" \
    || no "reviewing-brief: 엔진 러너 호출이 없다"
  grep -qF 'consumer=plugins/spec-distill/scripts/docreview_route.py' "$SKILL" \
    && ok "reviewing-brief: 발견의 처분 소비자가 엔진 라우터다" \
    || no "reviewing-brief: 처분 앵커가 엔진 라우터를 대지 않는다"
else
  no "reviewing-brief SKILL.md 부재: $SKILL_REL"
fi

finish
