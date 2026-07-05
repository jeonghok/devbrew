---
name: project-init-git-strategy-faithfulness
type: interview-brief
created_at: 2026-07-05
session_id: bcccf21f-e46e-4fda-9596-61f585860349
source: spec-distill conducting-interview v0.18.0
next_phase: superpowers:brainstorming
locked_directions:
  - id: LD1
    statement: "목표 = enforcement 충실성 수정(hook은 프로젝트가 선택하지 않은 전략을 단정 금지). 범위=project-init hook+템플릿. F4/F5 신규 결정론 강제는 devbrew lightness 기준으로 default defer."
    source_path: b
    steelman: n/a
    defense: ""
  - id: LD2
    statement: "F1 폴백 = loud-advisory fail-open. 전략 미선언(branch-strategy.md 부재/regex-less) 시 패턴 검증 안 함, GitHub-Flow silent 디폴트 대신 discoverable 한 줄 안내."
    source_path: b
    steelman: n/a
    defense: ""
  - id: LD3
    statement: "advisory hook을 유지하고 F1/F2/F3 편향만 수정(제거·축소 아님). advisory 성격은 정직하게 인정."
    source_path: b
    steelman: defended
    defense: "agentic 루프에서 systemMessage는 human이 무시하는 noise가 아니라 Claude context로 돌아가 LLM이 self-correct하는 피드백 신호 — steelman의 dev.to '무시되는 경고' anti-pattern 논거(human 전제)가 약화됨. project-init 헌장(v1.6.0)이 이 hook을 git-workflow enforcement substrate로 확립. 단, 진짜 강제는 서버측이라는 steelman의 유효한 지점은 이미 shared/pr-process.md 'Server-Side Enforcement' 섹션이 인정하고 있음."
  - id: LD4
    statement: "F2 = 교정 제안을 활성 패턴에서 파생. regex의 허용 prefix 집합(feature|fix|release|hotfix 등)을 추출해 제시, feature/ 하드코딩 제거. Git Flow hotfix에 feature/ 오제안 버그 종료."
    source_path: b
    steelman: n/a
    defense: ""
  - id: LD5
    statement: "F3 = doc-only. trunk-based 템플릿의 kill-switch-우회 안내 제거, hook이 non-blocking advisory임을 명확화(release/*는 경고만, 차단 안 됨 → bypass 불필요)."
    source_path: b
    steelman: n/a
    defense: ""
  - id: LD6
    statement: "실행 제약: 구현은 신규 git worktree에서 진행(사용자 명시 지시). brainstorming→writing-plans 흐름이 worktree를 먼저 생성."
    source_path: b
    steelman: n/a
    defense: ""
---

# project-init git-strategy faithfulness — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

**(d) ontological — ROOT_CAUSE로 도출.** 받은 요청("project-init이 GitHub flow로 치우쳐지는 것 같다")의 진짜 문제는 "플러그인이 GitHub Flow만 지원한다"가 **아니다** — command 계층은 3전략(GitHub Flow / Git Flow / Trunk-based)을 동등하게 제시하고 각 전략이 자기 브랜치 regex를 담아 hook이 런타임에 읽어 적응한다. 진짜 root cause는:

> **enforcement hook(`post-tool-use.py`)이 프로젝트가 *선택하지 않은* 전략(GitHub Flow)을 여러 지점에서 silent하게 단정한다** — 즉 "치우침"은 전략 지원의 부재가 아니라 **enforcement 계층의 전략-불충실(unfaithfulness)**이다.

진짜 goal = enforcement가 선택된 전략에 충실해지도록 국소 편향 3곳을 수정하되, ceremony(신규 결정론 강제)를 증식시키지 않는다.

## 2. Locked Directions

(frontmatter locked_directions와 1:1. 재논쟁 금지.)

- **LD1** — 목표 = enforcement 충실성 수정. 범위 = project-init hook + 템플릿. F4(merge-전략 런타임 강제)·F5(base-branch 규율 강제) 신규 결정론 강제는 devbrew lightness 기준으로 default defer(→ §6 OQ1).
- **LD2** — F1 폴백 = **loud-advisory fail-open**. 전략 미선언 시 패턴 검증을 하지 않고 한 줄 discoverable 안내만 출력. GitHub-Flow형 silent 디폴트(`DEFAULT_BRANCH_PATTERN`) 제거.
- **LD3** — advisory hook 유지 + F1/F2/F3 편향만 수정(steelman "축소/제거" 방어). advisory 성격은 정직하게 유지.
- **LD4** — F2 = 교정 제안을 **활성 패턴에서 파생**(허용 prefix 집합 제시, `feature/` 하드코딩 제거).
- **LD5** — F3 = **doc-only**. trunk-based 템플릿 kill-switch-우회 안내 제거 + non-blocking advisory 명확화.
- **LD6** — 실행 제약: **신규 git worktree**에서 구현.

### 감사로 확정된 편향 지점 (근거: `plugins/project-init/hooks/post-tool-use.py`)

- **F1** (`post-tool-use.py:19`) — `DEFAULT_BRANCH_PATTERN = ^(feature|fix)/[a-z0-9][a-z0-9.-]*$`. 폴백이 GitHub-Flow형 → 전략 미선언 시 Git Flow의 `release/*`·`hotfix/*`를 거부. **→ LD2로 fail-open 전환.**
- **F2** (`post-tool-use.py:102-105`) — `validate_branch` 교정 제안이 활성 전략과 무관하게 항상 `feature/{name}`. Git Flow hotfix 오타에도 `feature/` 제안. **→ LD4로 패턴-파생.**
- **F3** (`templates/trunk-based/branch-strategy.md` Pattern B) — trunk regex가 `release/*`를 (의도적으로) 배제하는데, 템플릿이 이를 우회하려 `DEVBREW_DISABLE_PROJECT_INIT=1`로 **hook 전체를 끄라**고 안내(커밋 검증까지 함께 꺼짐). 그러나 hook은 non-blocking이라 release/* 생성은 경고만 뜰 뿐 차단되지 않음 → bypass 자체가 불필요. **→ LD5로 doc-only 명확화.**

## 3. External Landscape

- **Config-driven 브랜치명 검증이 표준 패턴** — hook/CI가 config의 패턴으로 검증하고 mismatch 시 fail. 우리 플러그인도 이미 `get_branch_pattern`으로 `branch-strategy.md`의 regex를 읽음(편향은 폴백·제안에 국한). — https://www.git-tower.com/git-hooks/branch-naming , https://itnext.io/using-git-hooks-to-enforce-branch-naming-policy-ffd81fa01e5e — [취함] — 우리 설계가 이미 표준을 따름을 확인, 폴백·제안만 충실화하면 됨.
- **Advisory/monitoring hook은 fail-open, security hook만 fail-closed** — 그리고 **설정 부재 시 특정 의견으로 silent 디폴트하는 것 자체가 명명된 anti-pattern**. — https://authzed.com/blog/fail-open , https://github.com/openclaw/openclaw/issues/5052 — [취함] — F1 폴백을 fail-open(LD2)으로 잡는 직접 근거. 현재 폴백은 "fail-toward-GitHub-Flow"라는 anti-pattern.
- **실제 load-bearing 브랜치명 강제는 서버측(GitHub rulesets/branch protection)** — client-side hook은 convenience 계층. — https://code.claude.com/docs/en/hooks (PostToolUse "No decision control") , https://dev.to/piyushgaikwaad/branch-protection-rules-vs-rulesets-the-right-way-to-protect-your-git-repos-305m — [중립] — hook이 진짜 게이트가 될 수 없음을 확인하되(§4 steelman), 이미 `shared/pr-process.md`가 이 사실을 정직하게 문서화하고 있어 신규 작업 아님.

## 4. Skepticism Log

- **대안 (steelman-builder verbatim)**: "project-init 브랜치명 검증 hook의 GitHub-Flow 편향 버그를 고쳐서 유지하지 말고, 이 hook을 축소·제거하라 — PostToolUse는 구조적으로 이미 실행된 git 명령을 막을 수 없어 규칙이 정말 중요하면 PreToolUse deny나 CI/서버측으로 올려야 하고, 그 정도로 중요하지 않다면 이미 AGENTS.md/branch-strategy.md에 있는 산문 규칙 + 모델 신뢰로 충분하다; 지금처럼 '집행력 없는 advisory 스크립트'를 정교하게 다듬는 것은 순수 ceremony 비용만 남긴다." — 근거: https://code.claude.com/docs/en/hooks (PostToolUse=No decision control) , https://dev.to/thawkin3/eslint-warnings-are-an-anti-pattern-33np (non-blocking 경고=anti-pattern) , https://dev.to/piyushgaikwaad/branch-protection-rules-vs-rulesets-the-right-way-to-protect-your-git-repos-305m (서버측이 진짜 강제) , https://joseparreogarcia.substack.com/p/claude-code-hooks-explained-the-missing (hooks=guaranteed 행동용) — **verdict: defended**.

  **방어 근거(LD3)**: (1) agentic 루프에서 `systemMessage`는 human이 무시하는 noise가 아니라 Claude context로 되돌아가 LLM이 self-correct하는 피드백 신호 — dev.to anti-pattern 논거의 *human 전제*가 우리 대상(agent)과 불일치. (2) project-init 헌장이 이 hook을 enforcement substrate로 확립. (3) steelman의 유효 지점("진짜 강제=서버측")은 이미 `shared/pr-process.md` "Server-Side Enforcement" 섹션이 정직하게 인정 — 제거가 아니라 "advisory로서 편향만 제거"를 지지.

## 5. Tried & Discarded

- **전면 하드닝(F4 merge-전략 런타임 강제 + F5 base-branch 규율 강제 추가)** → 버림: 신규 결정론 가드 증식은 devbrew "harness lightness — trust the model"(결정론은 security/정확성 게이트에만) 원칙과 충돌. 브랜치명·merge-전략은 non-load-bearing convention. (round 1에서 사용자가 Option "충실성 수정 중심" 선택으로 배제.)
- **설계 재검토 우선(3전략 지원 자체 재고)** → 버림: 감사 결과 편향이 hook에 국소화됐고 3전략 지원 설계 자체는 건전(각 전략이 자기 regex 인코딩). 구조적 재설계 불필요. (round 1에서 배제.)
- **hook 축소/제거(§4 steelman)** → 버림: R3 게이트에서 defended(위 방어 근거). agentic advisory는 무시되는 noise가 아니라 LLM이 반응하는 신호.

## 6. Open Questions

("유추 금지" — 해답공간으로 이월.)

- **OQ1**: F4(merge-전략 런타임 강제) & F5(base-branch 규율 강제)는 lightness 기준으로 **명시적 defer**(LD1). in-scope 아님 — 작업으로 유추하지 말 것. 후속 사이클이 lightness bar를 통과시킬 때만 재검토.
- **OQ2**: F1이 fail-open이 되면 `DEFAULT_BRANCH_PATTERN`은 미선언 경로에서 dead code — brainstorming이 완전 삭제 vs 잔여 용도를 판정.
- **OQ3**: F1 loud-advisory 메시지가 기존 `shared/pr-process.md` "Server-Side Enforcement" 안내를 cross-reference할지 — minor UX, brainstorming으로 이월.
- **OQ4 (검증 제약, 유추 아님)**: `post-tool-use.py`는 **현재 테스트 전무**(`smoke.sh`·`test_docs_lint.py`는 `docs-lint.py`만 커버). F1/F2 코드 수정은 신규 `test_post_tool_use.py` 하니스를 처음부터 구축해야 하며, 이는 Verification Plan의 load-bearing 항목.

## 7. Concrete Next Action

superpowers 가용 → 이 brief를 context로 `superpowers:brainstorming` 호출 → `docs/superpowers/specs/...-design.md` 산출 → spec-distill:spec-reviewer 검증(Law 2) → writing-plans. **LD6에 따라 구현은 신규 git worktree에서** — brainstorming/writing-plans 흐름이 worktree를 먼저 생성한다(`superpowers:using-git-worktrees`). 대상 파일: `plugins/project-init/hooks/post-tool-use.py`(F1/F2), `plugins/project-init/templates/trunk-based/branch-strategy.md`(F3), 신규 `plugins/project-init/hooks/tests/test_post_tool_use.py`(OQ4), `plugin.json` SemVer bump(minor — enforcement surface 변경) + CHANGELOG.
