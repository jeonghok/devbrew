# Model Override Experiment Result

**Date:** 2026-04-29
**Branch:** feature/qg-cost-reduction
**Plan reference:** `~/.claude/plans/qg-melodic-fiddle.md` §B "사전 검증"; `~/.claude/plans/2026-04-29-qg-cost-reduction-impl.md` Task 1.

> **사후 정정 (2026-08-03, 하니스 능력 억제 제거 sweep).** 아래 **측정 결과는 여전히 유효하다** —
> Task 도구의 `model` 파라미터가 `model: inherit` frontmatter를 실제로 override한다는 것은
> 두 방향 실행으로 확인된 사실이다. **폐기된 것은 그 결과를 어디에 쓸지에 대한 "Implication for
> SKILL.md dispatch" 절의 권고다.** 그 절이 권장한 *"`model: "sonnet"`으로 override하는 Phase 1
> dispatch 표를 그대로 구현한다"* 는 이후 금지됐다: `inherit` 에이전트를 비용 이유로 하위 tier에
> 고정하는 것이 곧 이 sweep이 제거한 하니스 능력 억제이기 때문이다. 실측 근거는 설계 §1.1 —
> `model: sonnet` 핀이 opus 세션에서 리뷰어를 sonnet으로 만들어 **리뷰어가 writer보다 약한 상태를
> 매 dispatch 재현**했다.
>
> **현재 규약**: 리포 내 모든 agent frontmatter는 `model: inherit`이다. dispatch 시점의 `model` 인자는
> 오케스트레이터의 재량이되, 출력이 게이트 판정·측정에 들어가는 agent 에는 넘기지 않는다 —
> 재량은 프로브·생성기에 한한다(`docs/plugin-authoring.md`, 2026-09-04). 타 플러그인이 *자기* frontmatter에 하드코딩한
> `model:` 핀을 wrapper로 우회하지 않는다는 아래의 판단은 **그대로 유효하다** — 그것은 상류 저자의
> 선택을 존중하는 것이지 능력을 깎는 것이 아니다.
>
> **이 문서의 현재 지위**: 리포 어디서도 참조하지 않는 **고아 기록**이고(2026-08-03 전수 확인),
> 등장하는 모델(Opus 4.7 / Sonnet 4.6)은 모두 교체됐다. 삭제하지 않는 이유는 override 의미론
> probe의 **방법**이 재사용 가능하기 때문이다(문서 말미 Caveat의 재실행 지시). 상세는
> `docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md`.

## Test

Dispatched `pr-review-toolkit:silent-failure-hunter` (frontmatter `model: inherit`) twice via the Task tool from a session whose parent harness model is Opus 4.7:

1. **With explicit `model: "sonnet"` override** — agent prompted to self-identify its model.
2. **Without `model` parameter** — same self-identification prompt.

The agent's identity claim is the proxy signal: the model that handles the dispatch reads its own system prompt and reports back.

## Result

| Run | `model` parameter | Self-reported model |
|---|---|---|
| 1 | `"sonnet"` | **Sonnet 4.6** ("my system prompt identifies me as claude-sonnet-4-6") |
| 2 | (omitted) | **Opus 4.7** ("my system prompt states I am powered by the model named Opus 4.7 (1M context)") |

Override worked: **YES**.

## Implication for SKILL.md dispatch

For cross-plugin agents with `model: inherit` frontmatter — i.e. all of `pr-review-toolkit:silent-failure-hunter`, `type-design-analyzer`, `pr-test-analyzer`, `comment-analyzer`, and `superpowers:code-reviewer` — Task tool `model: "sonnet"` cleanly overrides to Sonnet. The Phase 1 dispatch table in the design plan (§B) can be implemented as written.

For cross-plugin agents with hardcoded `model: opus` (i.e. `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:code-simplifier`) we do **not** override per user direction — upstream's hardcoded model is respected.

For cross-plugin agents with hardcoded `model: sonnet` (i.e. `feature-dev:code-architect`, `feature-dev:code-explorer`, `feature-dev:code-reviewer`) we likewise do not override.

## Caveat

The self-identification check is heuristic — models can in principle hallucinate identity. This result is consistent with two independent runs in opposite directions and matches Anthropic's documented Task-tool override semantics, so we treat it as a reliable confirmation. If a future Claude Code version changes override semantics, re-run this probe.
