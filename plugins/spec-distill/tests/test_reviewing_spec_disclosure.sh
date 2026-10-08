#!/usr/bin/env bash
# spec-review 껍데기가 **자기 kill switch 와 degrade 채널을 공시하는가.**
#
# ── 왜 이 파일이 생겼는가 (T7) ───────────────────────────────────────────────
# 옛 `test_reviewing_spec_codex_merge.sh` 는 삭제된 verdict 파이프라인의 배선을 쟀고
# T7 이 그 파일을 지웠다. 그런데 그 파일의 12 단언 중 **넷은 껍데기 위에서 아직
# 통과하고 있었다** — 대상이 사라진 것이 아니라 대상이 껍데기로 옮겨간 것들이다.
# 그중 셋은 이 리포에서 다른 어떤 락도 재지 않았다. 삭제가 그 커버리지를 조용히
# 없애지 않도록 여기로 옮긴다.
#
#   · `DEVBREW_SPEC_DISTILL_DISABLE_CODEX` 가 이 skill 표면에 **문서화**돼 있는가
#   · 전역 `DEVBREW_SPEC_DISTILL_DISABLE` 도 함께 이름 대는가
#   · degrade 채널을 이름으로 대는가
#
# **집행과 공시는 다른 축이다.** codex 스위치의 *집행*은
# `plugins/quality-gates/tests/test_codex_gate_observation.sh` 가 실행 관측으로 잰다
# (마킹된 게이트 블록을 잘라 돌리고 `<sw>=1` 에서 codex 호출 0회를 확인한다) — 그
# 락이 옛 판정 「`detect_codex.sh` 가 배선됐다」까지 훨씬 강하게 승계하므로 여기서
# 다시 재지 않는다. 하지만 그 실행 관측은 **fence 안**만 본다: fence 밖 산문을 통째로
# 지워도 GREEN 이다. 사용자가 스위치의 존재를 아는 경로가 그 산문이므로(P21 —
# 끌 수 있다는 사실이 공시되지 않으면 없는 것과 같다) 공시 축을 여기서 잡는다.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/spec-review/SKILL.md"

. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

[[ -f "$SKILL" ]] && ok "대상 실재 — ${SKILL#"$REPO_ROOT/"}" \
                  || { no "대상 부재 — ${SKILL#"$REPO_ROOT/"}"; finish; exit; }

# ── (1) kill switch 공시 ────────────────────────────────────────────────────
# 창은 codex 게이트 fence **바깥**이다: `<!-- codex-gate:end -->` 부터 다음 `## ` 까지.
# fence 안을 코퍼스에 넣으면 실행 관측 락이 이미 재는 것을 두 번 재고, 정작 이 락이
# 잡으려는 실패(산문만 사라짐)를 fence 의 리터럴이 혼자 만족시킨다.
KS="$(awk '/codex-gate:end/{f=1; next} f && /^## /{f=0} f' "$SKILL")"
if [[ -z "$KS" ]]; then
  no "kill switch 창이 비었다 — 구조 앵커 파손 (조용한 통과 금지)"
else
  ok "kill switch 창 추출 ($(printf '%s\n' "$KS" | wc -l | tr -d ' ')줄, fence 밖)"
  printf '%s' "$KS" | grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1' \
    && ok "codex-only kill switch 가 이 skill 표면에 공시된다" \
    || no "codex-only kill switch 공시 소실 — 사용자가 끌 수 있다는 사실을 알 경로가 없다 (P21)"
  printf '%s' "$KS" | grep -qF 'DEVBREW_SPEC_DISTILL_DISABLE=1' \
    && ok "전역 kill switch 도 함께 이름 대어진다" \
    || no "전역 kill switch 가 이 skill 표면에 없다"
  # 「언제 읽는가」까지 적혀야 공시가 행동을 바꾼다 — 캐시된 값으로 게이트하면
  # 세션 중 끈 사용자의 opt-out 이 그 세션 내내 무시된다.
  printf '%s' "$KS" | grep -qF '캐시하지 않' \
    && ok "스위치를 dispatch 직전에 확인하고 캐시하지 않는다는 계약이 적혀 있다" \
    || no "스위치 확인 시점 계약(캐시 금지)이 사라졌다"
fi

# ── (2) degrade 채널 공시 ───────────────────────────────────────────────────
DG="$(awk '/^## degrade 채널/{f=1; print; next} f && /^## /{f=0} f' "$SKILL")"
if [[ -z "$DG" ]]; then
  no "'## degrade 채널' 절이 없다 — 이 skill 이 무엇을 공시하는지 말하지 않는다"
else
  ok "degrade 채널 절 추출 ($(printf '%s\n' "$DG" | wc -l | tr -d ' ')줄)"
  for ch in 'advisory[]' 'blocks' 'gate --render'; do
    printf '%s' "$DG" | grep -qF "$ch" \
      && ok "degrade 채널 '$ch' 를 이름으로 댄다" \
      || no "degrade 채널 '$ch' 가 절에서 사라졌다"
  done
  # 「codex 가 없었다」가 실제로 그 채널을 타는지 — 모델 다양성 손실은 공시 대상이다.
  printf '%s' "$DG" | grep -qF 'codex 부재' \
    && ok "codex 부재가 degrade 사유로 그 채널에 실린다고 적혀 있다" \
    || no "codex 부재가 degrade 채널에 실린다는 서술이 없다 — 모델 다양성 손실이 조용해진다"
fi
finish
