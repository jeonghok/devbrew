---
name: qg-scope-capture
type: interview-brief
created_at: 2026-06-07
session_id: d204cabb-f734-493a-999f-2bc72a3edf09
source: spec-distill conducting-interview v0.14.0
next_phase: superpowers:brainstorming
locked_directions:
  - id: LD1
    statement: "근본 문제: qg verdict가 실제 resolved scope를 정직히 반영 못 함 — 의도 scope ≠ resolved scope의 silent 발산, 증상은 커밋 후 빈 세션 false-clean."
    source_path: d
    steelman: n/a
  - id: LD2
    statement: "Review 해법=synthesis: session 기본값 유지 + scope 투명성/확인 + '변경 있는데 resolved scope=0'만 좁게 surface. 강제 branch-default·generic 결정론 가드 폐기."
    source_path: b
    steelman: defended
    defense: "steelman의 lightness 논거(강제 branch-default=fast-feedback UX 파괴, generic 결정론 가드=옥죄기) 수용해 heavy form 폐기. 단 '변경 있는데 resolved scope=0'은 graceful no-op이 아니라 silent 발산이므로 좁게 방어(P8 load-bearing)."
  - id: LD3
    statement: "Runtime 축=transparency 대칭 확장: 비대칭(항상 full-project)은 본질로 유지, '무엇을·어떻게(surface/boot/env) 검증하나'를 실행 전 가시·확인. diff-scope 강제 안 함."
    source_path: b
    steelman: n/a
  - id: LD4
    statement: "north-star=자기-정직한 verdict(correctness end). qg는 실제 검토한 만큼만 confident하게 말한다. transparency/control=수단, lightness=제약."
    source_path: d
    steelman: n/a
---

# qg scope-capture — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

**(d) ontological — ROOT_CAUSE + ESSENCE로 도출.**

받은 요청("qg 실행 시 리뷰·runtime이 잡는 scope를 탐색하고 목적·UX에 맞게 개선")을 재구성하면:

> **한 문장 문제정의:** qg의 verdict(clean/문제있음)는 *사용자가 검토받았다고 믿는 scope*가 아니라
> *qg가 내부적으로 resolve한 scope*를 반영하는데, 이 둘이 silent하게 발산할 수 있어 — 가장 날카롭게는
> 커밋 후 빈 세션에서 "clean"이 나오는 false-clean으로 — verdict의 정직성이 깨진다.

**진짜 goal(north-star, LD4):** qg가 **실제로 검토한 만큼만 confident하게 말하게** 만드는 것. 검토하지
않은 것을 clean이라 하지 않고, 무엇을(Review: 파일/브랜치/코드, Runtime: surface/boot/env) 검토했는지
정직히 드러내며, scope가 사용자 의도와 어긋날 때 사용자가 redirect할 수 있게 한다. transparency·control은
이 goal을 달성하는 *수단*이고, devbrew harness-lightness(저마찰 happy-path)는 넘지 말아야 할 *제약*이다.

**핵심 통찰(steelman이 드러낸 구분선):** "변경 없음 → clean"(idempotent graceful no-op, 정상)과
"변경은 있는데 resolved scope=0 → clean"(의도 scope ≠ resolved scope의 silent 발산, false-clean)은
다르다. 전자는 두지만 후자만 정직성 문제다. 이 구분이 작업 전체의 칼날이다.

## 2. Locked Directions

(확정·검증된 방향. frontmatter `locked_directions`와 1:1. 재논쟁 금지.)

- **LD1 (근본 문제 / source_path: d)**: qg verdict가 실제 resolved scope를 정직히 반영 못 함 — 의도
  scope ≠ resolved scope의 silent 발산이 근본, 커밋 후 빈 세션 false-clean이 가장 날카로운 증상.
  *(사용자 round-1 선택: "기본 scope 모델 불일치")*
- **LD2 (Review 해법 / source_path: b, steelman: defended)**: synthesis. **유지** = session
  기본값(fast-feedback UX), v2.5.0 scope 투명성 한 줄, `/qg branch`·`--paths` escape hatch, 모델 신뢰.
  **폐기** = 강제 branch-default, generic empty-scope 결정론 가드(옥죄기). **도입** = scope 투명성/확인
  강화 + "변경 있는데 resolved scope=0"만 좁게 surface(hard block 아니라 redirect 가능한 게이트).
  load-bearing = "resolved scope 비었는데 confident clean 금지". *(round-2 P17 게이트 → 부분 방어)*
- **LD3 (Runtime 축 / source_path: b)**: transparency 대칭 확장. Review↔Runtime scope 비대칭(Runtime은
  항상 full-project)은 **본질**(앱 부팅엔 변경분이 아니라 전체 앱이 필요)이라 유지하되, Runtime이
  *무엇을*(full-project이고 Review scope와 다르다는 사실 포함) *어떻게*(어떤 surface/boot command/env)
  검증할지 실행 전 가시·확인 가능하게. runtime을 diff-scope로 강제하지 않음. *(round-3 선택)*
- **LD4 (north-star / source_path: d)**: 자기-정직한 verdict가 end. correctness 우선 — transparency·control은
  수단, lightness는 제약. P8 determinism-economy가 load-bearing으로 인정하는 유일한 지점("검토 안 한 걸
  clean이라 하지 않기")에만 결정론 허용. *(round-4 선택: "자기-정직한 verdict")*

## 3. External Landscape

(prior-art / 경쟁 / 기존 해결책. 각 항목 출처 URL 필수 + [취함|피함|중립] + 이유.)

- **업계 기본 리뷰 scope = merge-base diff vs base 브랜치(PR/브랜치 변경분).** CodeRabbit은 default 브랜치 타깃 PR을 리뷰하고, Codex/Claude /code-review는 tip-to-tip이 아니라 merge-base로 *내 변경분만* 잡는다. https://docs.coderabbit.ai/configuration/auto-review · https://codex.danielvaughan.com/2026/03/30/codex-cli-review-command-code-review-workflows/ · https://code.claude.com/docs/en/code-review — **[중립]** — "사용자 멘탈모델이 보통 브랜치/PR 변경분"이라는 근거로 *취함*(투명성 문구·redirect 방향 설정), 단 qg 기본값을 강제 branch로 바꾸는 데는 *피함*(LD2: fast-feedback UX 파괴).
- **empty-diff/no-changes false-pass = 인정된 anti-pattern.** "시스템이 할 일이 있다고 판단했으면 '한 일 없음'이 완료로 카운트되면 안 된다" — explicit scope + vacuous-success 방지가 정석. https://dev.to/gitautoai/zero-changes-passed-our-quality-gate-3h43 · https://dev.to/mumtaz2029/what-are-quality-gates-in-cicd-and-why-nobody-reads-is-not-a-gate-4a51 — **[취함]** — false-clean(변경 있는데 scope=0)을 load-bearing correctness 문제로 보는 LD1·LD4의 직접 근거.

## 4. Skepticism Log

(의심 triggered 방향: steelman-builder 대안 요지(verbatim) + 웹근거 URL + verdict. 약화·편집 금지 — AC5.)

**의심 방향(triggered):** "qg의 scope-capture를 재설계해야 한다 — session 기본값을 branch/PR-diff로 바꾸고
empty-scope false-clean에 결정론적 correctness floor를 추가." **trigger:** 이 repo의 알려진 anti-pattern(결정론을
convenience/routing에 쌓는 '옥죄기'로 폐기된 history; 4층 session-scope 가드 폐기; empty-scope 'Option 1'
결정론 가드 deferred) + P8 determinism-economy.

- **steelman-builder 대안(verbatim, conf 0.78) — verdict: defended(부분 방어/synthesis):** "qg의 session-scope 기본값을 branch/PR-diff로 바꾸거나 empty-scope 결정론 가드를 추가하는 재설계는 하지 말아야 한다 — v2.5.0의 scope 투명성 한 줄 + `/qg branch` 명시 escape hatch + 모델 신뢰로 이미 충분하고, 기본값을 무겁게 바꾸면 개발 중 fast-feedback을 파괴하며, empty-scope pass는 load-bearing correctness 구멍이 아니라 구조적으로 올바른 graceful no-op이다." 웹근거: https://dev.to/brianmello/ai-code-review-in-2026-how-the-tools-actually-differ-a-builders-field-guide-4chi · https://www.infoq.com/articles/pipeline-quality-gates/ · https://dev.to/tutunak/why-idempotence-matters-in-cicd-pipeline-build-steps-4ka · https://www.ux-bulletin.com/default-effect-in-ux/ · https://github.com/anthropics/claude-code/issues/60113

**근거 요지:** ① 개발 중 리뷰는 '방금 한 작업'에 좁게 scope되는 게 가치(branch-diff는 "feedback after
context-switch"가 약점) ② 너무 엄격한 게이트 → 개발자 좌절·반발(rebel) ③ idempotent CI에서 no-op은
정상 상태, empty scope=clean은 semantically 올바름 ④ 무거운 기본값은 인지부하↑·friction↑·채택률↓
⑤ 강제 worktree isolation default는 "daily use painful" 실사례.

**verdict 근거:** *부분 방어(synthesis)*. steelman의 lightness 논거(강제 branch-default, generic 결정론 가드)는
*수용*해 해법의 heavy form을 폐기(→ §5). 그러나 steelman이 "empty-scope pass = graceful no-op"으로 묶은
지점에서 "변경 있는데 resolved scope=0"(silent 발산)을 분리해, 그 좁은 케이스의 정직성 문제(LD1)는 *방어*하고
lock. 즉 문제(LD1·LD4)는 defended, 해법의 heavy form은 switched-away.

## 5. Tried & Discarded

(시행착오: 시도 → 버린 이유. 다운스트림 재탐색 차단.)

- **강제 branch/PR-diff 기본값 전환** → 버림. steelman 근거 ①④⑤: 개발 중 fast-feedback(좁은 '방금 한
  작업' scope)을 파괴하고, 무거운 기본값(worktree/branch 컨텍스트)이 매번 인지부하·friction을 키워
  채택률을 떨어뜨림. session 기본값 유지(LD2).
- **generic empty-scope 결정론 가드(전면 hard block)** → 버림. 이 repo에서 '옥죄기'로 이미 폐기된
  패턴(harness-lightness) + steelman 근거 ②③: 엄격 게이트는 반발/우회를 부르고, '변경 없음 → clean'은
  올바른 idempotent no-op이라 전면 차단은 과잉. "변경 있는데 scope=0"만 좁게 surface하는 redirect 가능
  게이트로 대체(LD2).
- **Runtime을 변경 diff-scope로 강제(Review와 scope 통일)** → 버림. 앱 부팅엔 변경분이 아니라 전체 앱이
  필요 — 비대칭은 본질이지 버그가 아님. 대신 transparency 대칭만 적용(LD3).

## 6. Open Questions

(미해결 명시. "유추 금지" — 해답공간(brainstorming)으로 이월.)

- **OQ1 (자기-정직 verdict의 구체 메커니즘):** "변경 있는데 resolved scope=0"을 어떻게 *결정론적으로*
  탐지하나? (예: resolved scope 파일 수 vs 브랜치/working-tree diff 비어있지 않음 비교) — 그리고 탐지 시
  무엇을 띄우나(v2.5.0 투명성 한 줄 확장 / redirect 제시하는 AskUserQuestion 게이트 / advisory)? hard block은
  배제(LD2)지만 정확한 surface 형태는 미정.
- **OQ2 (lightness 경계):** 위 surface가 happy-path zero-click를 깨지 않으려면 — "scope=0 & 변경 존재"
  *그 케이스에서만* 발화하고 정상 케이스(scope>0, 또는 진짜 변경 없음)는 침묵해야 한다. 이 조건을
  false-positive 없이 깔끔히 표현하는 트리거 설계는?
- **OQ3 (Runtime transparency surface 위치):** Runtime이 "무엇을·어떻게 검증하나"를 실행 전 드러내는
  지점은 기존 Upfront Execution Plan(Decision 2)/manifest echo를 확장? 새 surface? Review의 투명성 문구와
  대칭 형태/어휘는?
- **OQ4 (Review↔Runtime 비대칭의 명시화):** "Runtime은 Review scope를 무시하고 full-project로 돈다"는
  사실 자체를 사용자에게 어떻게 정직히 알릴 것인가 — 이게 LD3 transparency의 핵심 콘텐츠.
- **OQ5 (변경 규모/버전):** 이 개선이 v2.x 안의 transparency-behavior 패치/마이너로 수렴하는가, 아니면
  새 surface(예: Decision-3급)가 필요한가? 새 P# 추가는 default 배제(devbrew 설계 lightness) — 기존 P8에
  흡수가 1순위.

## 7. Concrete Next Action

superpowers 있음 → 이 brief를 context로 `superpowers:brainstorming` 호출 →
`docs/superpowers/specs/...-design.md` 산출 → Law-2 reviewer(spec-distill:reviewing-spec) 검증 →
writing-plans. brainstorming은 §6 Open Questions(특히 OQ1 메커니즘·OQ2 트리거)를 해답공간에서 풀고,
§2 Locked Directions는 기정사실로 받는다.

superpowers 없음 → 이 brief가 완결 산출물 — qg scope-capture 개선의 다음 작업 입력으로 직접 사용.
