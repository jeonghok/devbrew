# devbrew 하니스 철학

> **Specify before you code. Review before you ship. Compound before you forget.**
> *코드보다 명세 먼저. 배포보다 리뷰 먼저. 잊기 전에 축적.*
>
> *병목은 모델이 아니다. 스펙, 리뷰, 메모리다. devbrew의 역할은 사용자가 의식적으로 기억하지 않아도 이 세 가지가 자동으로 지켜지도록 만드는 것이다.*

이 문서는 `plugins/*` 하위의 모든 플러그인이 상속받는 철학 레이어입니다. 리포 루트의 [`CLAUDE.md`](../../CLAUDE.md)는 이 중 핵심(세 법칙 + 플러그인 형태)을 약 130줄로 압축한 사전 로드 컨텍스트 앵커이고, 이 파일은 출처·안티패턴 라이브러리·원문 인용·각 원칙의 이유까지 담은 전체 버전입니다.

**흡수된 소스:**

- **OMC** — Yeachan-Heo/oh-my-claudecode v4.11.6 (28.9k★, 20 hooks, 32 skills, 19 agents, 전용 벤치마크 suite)
- **gstack** — garrytan/gstack (23+ skills를 "virtual engineering team"으로, ETHOS.md, preamble-tier, 다중 호스트 컴파일 타겟)
- **Ouroboros** — Q00/ouroboros (14 skills, 9 agents, Pydantic 동결 seed, ambiguity/convergence 수학, event-store)
- **Compound-Engineering** — EveryInc/compound-engineering-plugin v2.65.0 (~40 skills, ~45 agents, 훅 0개, skills-over-commands 원칙) + every.to 정전 에세이들 (Klaassen: *"My AI Had Already Fixed the Code Before I Saw It"*, *"Stop Coding and Start Planning"*, *"Teach Your AI"*; Shipper + Klaassen: *"How Every Codes With Agents"*)
- **Anthropic Engineering & Research** — *Building Effective AI Agents*, *Effective Context Engineering for AI Agents*, *Claude Code: Best Practices for Agentic Coding*, *Writing Effective Tools for AI Agents*, *Effective Harnesses for Long-Running Agents*, *How We Built Our Multi-Agent Research System*, *Code Execution with MCP*, *Skill Authoring Best Practices*
- **devbrew의 기존 스탠스** — `plugins/quality-gates/` v1.4.0 (pr-review-toolkit / feature-dev / superpowers로 delegate하는 3게이트 파이프라인 — 합성(composition) > 모놀리스 원칙이 이미 내장됨)

---

## 0. The Thesis

> **AI 보조 소프트웨어 작업의 병목은 모델 능력이 아니다. 입력의 명확성, 리뷰어의 독립성, 그리고 이전 사이클의 메모리다. 좋은 하니스는 사용자가 의식하지 않아도 이 세 가지를 자동으로 훈육한다.**

이후 모든 원칙·원형·안티패턴·플러그인 형태는 이 한 문장으로 추적 가능해야 합니다. 어떤 설계 결정이 *입력의 명확성*, *리뷰어의 독립성*, *축적되는 메모리* 중 어느 하나에도 기여하지 않는다면, 아마 devbrew에 속하지 않습니다.

네 하니스 모두 이 진단에 수렴합니다. Anthropic의 엔지니어링 문서도 다른 말로 같은 이야기를 합니다:

- *"Find the smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome."* — *Effective Context Engineering*
- *"Prioritize transparency by explicitly showing the agent's planning steps."* — *Building Effective Agents*
- *"Give Claude a way to verify its work. […] Invest in making your verification rock-solid."* — *Claude Code Best Practices*
- *"Like Claude Code creating a to-do list, or your custom agent maintaining a NOTES.md file, this simple pattern allows the agent to track progress across complex tasks."* — *Effective Context Engineering*

---

## 1. The Three Laws (hierarchical; Law N overrides Law N+1 on conflict)

### Law 1 — Clarity Before Code

명세가 모호한 상태에서는 구현이 진행되지 않습니다. 명세 작성은 자신의 스킬, 자신의 게이트, 자신의 거절 동작을 가진 **일급(first-class) 단계**입니다. 플러그인이 어떤 수치적/구조적 메커니즘을 선택하든(Ouroboros의 `Ambiguity ≤ 0.2`, OMC의 `deep-interview` brownfield-aware 질문, gstack의 `/office-hours` 여섯 개의 강제 질문, CE의 `ce-brainstorm`), 하니스는 반드시 **"아직 이건 코딩 못 한다"고 말할 수 있어야 합니다.** 모델 신뢰만으로는 부족합니다. Anthropic 자체가 경고합니다: *"letting Claude jump straight to coding can produce code that solves the wrong problem."*

**따름정리:** 스펙은 지속 가능한, 리뷰 가능한 artifact(마크다운 파일, 단순 대화 기록이 아님)입니다. 다시 읽을 수 있고, diff를 볼 수 있고, 버저닝되고, 다음 사이클의 입력으로 들어갑니다.

**Trivia escape:** §2.1 / P12의 canonical statement 참조 (consolidated mention).

### Law 2 — Writer and Reviewer Must Never Share a Pass

코드를 쓴 턴은 그 코드를 승인할 수 없습니다. 이것은 heuristic이 아니라 하드 규칙입니다. OMC는 이것을 operational하게 표현합니다: *"Keep authoring and review as separate passes… Never self-approve in the same active context; use `code-reviewer` or `verifier` for the approval pass."* gstack은 `allowed-tools` frontmatter scoping으로 강제합니다 (office-hours는 물리적으로 코드를 shipping할 수 없음). CE는 25-persona 병렬 리뷰 파이프라인으로. Ouroboros는 3-stage 평가 게이트 (mechanical → semantic → consensus)로, Stage 3는 다중 모델 투표 필요. Anthropic의 *Multi-Agent Research System*이 근본 패턴을 검증합니다: 독립된 subagent들이 *"careful handoffs"*로 인지적 anchoring을 끊어서 단일 agent를 능가.

**따름정리:** 검증(verification)은 load-bearing 인프라입니다. 나중 생각이 아닙니다. 하니스는 모든 코드 작성 사이클에 (a) 증거 수집 단계, (b) 독립적인 리뷰 단계, (c) 증거 없이는 "완료" 주장 불가 규칙을 빚지고 있습니다. 이것은 이미 `plugins/quality-gates/`의 척추이며, 철학은 이것을 모든 플러그인으로 일반화합니다.

### Law 3 — Every Cycle Must Leave the System Smarter

하니스를 "compound"하게 만드는 것은 N+1번째 작업이 N번째 작업보다 엄밀히 더 쉽다는 점입니다. 메커니즘은 low-tech입니다: **리포에 있는 파일을 미래 세션이 읽는 것.** Klaassen의 정의는 명확합니다:

> *"Compounding engineering is about building systems with **memory**, where every pull request teaches the system, every bug becomes a permanent lesson, and every code review updates the defaults. AI engineering makes you faster today. Compounding engineering makes you faster tomorrow, and each day after."*

하니스는 매 사이클에 이름 붙은 compounding 단계를 제공해야 합니다 — 선택적이지 않고, nice-to-have도 아닙니다 — "우리가 배운 것 중 기본값이 되어야 할 것이 무엇인가?"를 물으며, 미래 세션이 피할 수 없이 마주칠 어딘가에 기록합니다. OMC의 `learner`+`wiki` 트리오, CE의 `ce-compound` with `AGENTS.md`/`CLAUDE.md`를 자동 편집하는 Discoverability Check, gstack의 `learnings.jsonl` — 이 세 가지가 연구할 템플릿입니다.

**따름정리 — Discoverability Check:** compounding 단계는 새 learning이 미래 세션에서 **실제로 도달 가능한지** 확인해야 합니다. 어떤 미래 agent도 읽지 않는 파일에 learning을 쓰는 것은 theater입니다. 쓰기 작업은 찾을 수 있게 해주는 인덱스(CLAUDE.md, skill description, reviewer checklist)도 함께 업데이트해야 합니다. 이 따름정리의 운영 메커니즘 — extraction gate, index triad, lifetime tags, grep-recall criterion — 은 §4.6 Compounding Skill primitive에 살아있습니다. 이 따름정리는 *규칙*을 명시하고, §4.6은 *how*를 명시합니다.

---

## 2. Principles (organized under the Three Laws)

이것들은 운영 차원의 commitment입니다. 각 항목은 이름이 붙고, 출처가 있고, 구체적 devbrew 플러그인 결정으로 번역됩니다. 각 원칙은 자신이 일차적으로 봉사하는 Law 아래에 위치합니다. 세 법칙 모두에 봉사하는 원칙은 §2.4 Cross-Cutting Commitments에 모입니다.

### 2.1 Under Law 1 — Clarity Before Code

Law 1을 직접 봉사하는 원칙들. AP1, AP5는 anti-corollary로 nested.

### P1. Specification as Artifact, Not Chat

스펙은 파일(마크다운 또는 구조화 YAML)로 존재하고, 이름이 있고, 버저닝되고, diff 가능합니다. 이를 생성하는 인터뷰는 자신만의 루프를 가진 이름 붙은 스킬입니다 ("그냥 Claude에게 물어봐" 아님). Ouroboros의 frozen-Pydantic Seed가 이 스펙트럼의 극단이고, CE의 `ce-brainstorm → requirements.md`가 부드러운 쪽, OMC의 `deep-interview` with dimensional ambiguity score가 중간입니다. devbrew는 **optional 구조 게이트가 붙은 마크다운 스펙**을 고릅니다. 자유 형식 대화는 compaction 후 사라지고 grep 불가능하기 때문입니다.

> *"Most AI coding fails at the input, not the output. The bottleneck is not AI capability — it is human clarity."* — Ouroboros README
>
> *"Before telling AI what to build, define what should be built."* — Ouroboros

### P2. The Ambiguity Gate

스펙은 명확도 임계치를 통과했거나, 아직 못 했거나 둘 중 하나입니다. 게이트는 **visible, declared, refusable**해야 합니다.

- **Baseline (모든 스펙-작성 플러그인 필수): 구조적.** 필수 섹션 (Context/Why, Goals, Non-goals, Constraints, ACs, Files to Modify, Verification Plan, Rejected Alternatives, Metadata) + "구체적인 next action 없이는 종료 불가" 조항. gstack office-hours 기반.
- **Enhancement (선택적, baseline 위에 layering):**
  - **Adversarial** (gstack office-hours Phase 5.5, OMC ralplan Planner/Architect/Critic): 계획 단계를 떠나기 전에 sub-agent가 draft를 공격. 프로덕션 코드를 shipping하는 플러그인에 강력히 권장.
  - **Numerical** (Ouroboros `Ambiguity ≤ 0.2`): LLM-scored weighted 차원, temp 0.1, 명시적 임계. 허용되지만 권장하지 않음 — §5.3에서 논증함. 수치 게이트는 scorer와 generator가 같은 모델이라 brittle함. 제2 모델 scorer가 있을 때만 사용.

거절은 실제로 작동해야 합니다. "스펙이 불명확하다"고 말한 뒤 사용자가 `/continue`로 통과할 수 있는 플러그인은 P2를 집행하지 않는 것입니다. 코드로 silent pass-through 없음.

**Roadmap absorption (C43+C44+C45+C51 — Socratic Interview Discipline):** 스펙을 생성하는 인터뷰는 Socratic 4-path routing (C43)을 따릅니다: (a) factual 질문은 `[from-code][auto-confirmed]`로 코드베이스에 대해 auto-confirm, (b) human-judgment 질문은 사용자에게 라우팅 (default path), (c) ambiguity 질문은 sub-agent를 dispatch하여 adversarial draft 생성, (d) ontological 질문은 5-type framework 사용 (C51: ESSENCE / ROOT_CAUSE / PREREQUISITES / HIDDEN_ASSUMPTIONS / EXISTING_CONTEXT). dialectic rhythm guard (C44)는 3 consecutive non-user 답변 시 다음 질문을 사용자에게 라우팅하도록 강제합니다. breadth-keeper agent (C45) — `disallowedTools: Write, Edit` — 가 옆에서 돌면서 narrow tunneling을 방지합니다.

### AP1. "PRD Theater" (OMC)

*P2의 anti-corollary. 원래 위치: 구 §3.*

자동 생성된 ACs가 일반 placeholder인 것 — *"prd.json created with criteria: Implementation is complete, Code compiles. Moving on to coding."* 하니스는 refinement를 강제하거나 진행 거부해야 함. Ralph의 메커니즘: scaffold를 생성, 모델이 refine하도록 강제, 바뀌지 않은 placeholder 표현을 theater로 감지.

### P12. Transparency of Planning

Agent는 *실행 전에 계획을 보여야* 하고, 사용자가 redirect할 수 있어야 합니다. 이는 Anthropic의 *Building Effective Agents*에서 직접 인용:

> *"Prioritize transparency by explicitly showing the agent's planning steps."*

Plan mode가 이 이유로 존재합니다. devbrew의 복잡한 작업을 하는 플러그인은 **plan-then-execute를 default로** 해야 하며, 계획은 파일에 기록되고 (단순 chat 요약이 아님) 사용자가 승인 게이트를 얻습니다. Plan mode가 정전 메커니즘이고, 플러그인은 이를 존중하고 적절한 곳에서 자체 호출해야 합니다.

**예외 — 작은 변경:** consolidate된 규칙은 아래 *Trivia escape (canonical mention)* 단락 참조.

**Roadmap absorption (C34+C60):** transparency가 확장 — (C34) plan/audit boomerang (작업을 승인한 plan이 검증을 위해 작업과 함께 돌아옴, audit이 plan-vs-code alignment 확인); (C60) scope-adaptive depth (trivia escape는 lightweight, 보통 작업은 standard, 고위험은 deep — depth는 사전에 선언되지 mid-flight에 발견되지 않음).

**Trivia escape (canonical mention; Law 1 따름정리, AP5, §4.1 escape hatch를 consolidate):** diff를 한 문장으로 묘사할 수 있다면 (Anthropic, *Claude Code Best Practices*), plan과 spec gate를 skip합니다. 자격 있는 예: typo, rename, comment-only 편집, single-file formatting. 자격 없는 예: multi-file 변경, behavior 변경, public API 건드리는 것. triviality 감지는 *invoking* skill의 책임이지 spec/plan skill의 책임이 아닙니다 (spec/plan skill은 trivia를 거부할 기회조차 받지 않음). Cross-refs: Law 1 따름정리, 아래 nested AP5, §4.1 escape hatch 참조.

### AP5. Trivia Pipeline Overhead (Anthropic)

*P12의 anti-corollary. 원래 위치: 구 §3. canonical 규칙은 위 P12 참조.*

오타 fix에 full pipeline (spec → plan → review → verify → compound) 돌리는 것은 의식을 위한 의식. 플러그인은 triviality를 감지하고 earlier phase를 skip해야 함. 이것이 Ouroboros의 가장 큰 약점 — one-liner escape hatch 없음. devbrew는 상속하지 않음.

### 2.2 Under Law 2 — Writer/Reviewer Independence

Law 2를 직접 봉사하는 원칙들. AP3, AP13, AP14가 anti-corollary로 nested. AP11은 P3 body에 흡수 (standalone 헤더 없음). P24는 R5 (2026-05-06)에서 Anthropic *Claude Code Best Practices*의 Writer/Reviewer pattern을 직접 출처로 추가됨.

### P3. Writer/Reviewer Isolation via Tool Scoping

gstack 방식: `allowed-tools` frontmatter로 역할 경계를 **프롬프트가 아닌 물리적 레벨**에서 만듦. 리뷰어 agent에는 Write/Edit 없음. 플래너 agent에는 mutation-Bash 없음. 인터뷰어에는 code-execution 없음. 이것은 역할 분리를 "프롬프트를 믿자"에서 "도구가 존재조차 하지 않는다"로 바꿉니다. OMC도 같은 아이디어를 Delegation Enforcer PreToolUse 훅으로 구현 — Task 호출을 intercept해서 agent frontmatter의 model/tool 제약을 주입.

> *"Role boundaries are enforced by disallowedTools in frontmatter. Every agent prompt starts with 'You are X. You are responsible for Y. You are NOT responsible for Z' — the negative clause prevents helpful-agent creep."* — OMC architecture

**흡수된 안티패턴 (구 AP11):** `Write` 권한을 가진 리뷰어는 리뷰어가 아니며, mutating `Bash`를 가진 플래너는 플래너가 아닙니다. default(전체 tool 접근)은 어떤 role-scoped agent에도 금지됩니다. 모든 agent 정의는 명시적 `allowedTools`와 `disallowedTools` 리스트를 가져야 합니다.

### P24. Writer/Reviewer Pattern (Fresh-Context Critique Loop)

P3가 *enforcement* (frontmatter tool-scoping)이라면, P24는 *workflow shape*입니다 — Anthropic *Claude Code Best Practices*가 명시적으로 명명한 default 패턴: Writer 세션이 draft를 만들고, **fresh context의 Reviewer 세션**이 critique하고, Writer가 피드백을 반영해서 다시 draft하는 dual-session loop. 핵심 근거는 self-bias의 비대칭 — 같은 context는 자신이 방금 쓴 코드 쪽으로 systematically 편향됨. fresh context는 그 anchor를 끊습니다.

> *"[…] multiple sessions enable quality-focused workflows. **A fresh context improves code review since Claude won't be biased toward code it just wrote.** For example, use a Writer/Reviewer pattern."* — *Claude Code Best Practices*

> *"In the evaluator-optimizer workflow, one LLM call generates a response while another provides evaluation and feedback in a loop."* — *Building Effective Agents*

운영적 함의:

- **Production code를 shipping하는 플러그인의 default workflow shape는 Writer/Reviewer 2-session loop.** 단일 agent의 draft + self-review로 종결하는 패턴은 AP3 (Self-Approval)의 일반화된 형태로 treat.
- Reviewer는 *반드시* fresh context — 같은 turn 내 reviewer skill 재invoke가 minimum baseline, 별도 agent dispatch가 정석, 별도 session이 high-stakes default. 같은 context의 self-review는 self-bias를 그대로 안고 감.
- Loop은 single iteration이 아닐 수 있음 — Writer가 Reviewer feedback을 받고 revise하고 다시 review에 보내는 반복. *Building Effective Agents*의 "evaluator-optimizer"가 정확히 그것.
- P3와 동시 적용: P3는 *무엇이* 가능하냐 (Reviewer는 `Write`/`Edit` disallow), P24는 *언제, 어떤 모양으로* 도느냐 (Writer draft → Reviewer fresh context critique → revise loop).
- P11과 구분: P11은 *cross-MODEL* (다른 vendor) 게이트 — 되돌리기 어려운 결정의 opt-in. P24는 *same-model fresh-context* 게이트 — production-ship default. 한 플러그인이 P24만, 또는 P24+P11 (high-stakes에 추가) 둘 다 instantiate 가능.

**Reference implementation:** `plugins/quality-gates/`의 3-gate 파이프라인 (writer → reviewer → runtime verifier)이 P24의 canonical instantiation. 플러그인이 P24를 instantiate함을 README *"Principles Instantiated"*에서 cite하면 future search가 모든 instantiation을 발견 (Law 3 compounding substrate).

### P4. Verification Is Infrastructure

모든 작업은 *증거*를 생산하는 검증 pass로 끝납니다. "테스트 통과"는 증거, "제 생각엔 작동해요"는 아닙니다. Anthropic은 명료합니다: *"Give Claude a way to verify its work. […] Invest in making your verification rock-solid."* devbrew는 이미 `quality-gates/`를 가지고 있습니다. 철학은 이것을 코드 shipping 모든 플러그인의 기본 기대치로 만듭니다.

세 검증 양식, 우선순위 순:

1. **Mechanical** — compile, lint, type-check, test. 저렴, 이진, non-negotiable.
2. **Semantic** — P1 스펙 대비 AC 준수를 agent가 판단. 더 비쌈. 독립 리뷰어 필요 (P3).
3. **Runtime** — 실제로 돌림 (headless browser, CLI invocation, smoke test). 앞 두 개가 놓치는 버그 class를 잡음. 이것이 오늘의 `quality-gates/` Gate 3이며, 모든 플러그인의 모델이 되어야 함.

최소 하나, 이상적으로 셋 다 없이는 "완료" 주장 불가.

**Roadmap absorption (C35 — Two-Tier Test Classification):** verification 테스트는 두 tier로 분리: (a) **gate tier** — 모든 커밋/PR에서 돌고, 저렴(< 5s)하며, 실패 시 차단. (b) **periodic tier** — 스케줄/트리거에 따라 돌고, 비쌈 (E2E ~$3.85/run, LLM-judge ~$4/run), 실패 시 surface하지만 per-commit 차단 안 함. Diff-based selection이 어느 tier가 돌지 라우팅.

### AP3. Self-Approval

*P4의 anti-corollary. 원래 위치: 구 §3.*

같은 턴이 쓰고 승인하는 것. Law 2로 엄격히 금지. 하니스는 승인을 구조적으로 독립된 pass로 route해야 함 — 다른 agent, 다른 skill, 또는 최소한 fresh context로 reviewer skill을 다시 invoke.

Anthropic *Claude Code Best Practices*가 self-bias의 비대칭을 명시적으로 articulate함: *"A fresh context improves code review since Claude won't be biased toward code it just wrote."* AP3는 그 bias가 무엇인지의 이름 — 같은 context의 reviewer는 자신이 방금 쓴 코드를 *defend*하는 default로 들어가고, fresh context는 그 anchor를 끊습니다. P24가 그 분리를 default workflow shape로 만들고, AP3는 그 분리 없는 self-pass를 거부 — 둘은 같은 axis의 positive/negative.

### P10. Taste Pluralism

CE에서 가장 훔칠 만한 아이디어는 25-persona 리뷰어 파이프라인입니다: `dhh-rails-reviewer`, `kieran-python-reviewer`, `julik-frontend-races-reviewer`, plus 기능적 리뷰어들 (`security-sentinel`, `correctness`, `testing`, `maintainability`, `api-contract`, `schema-drift-detector`). 각각은 작은 마크다운 파일, 버저닝 가능, 버그가 빠져나갔을 때 단일 커밋으로 편집 가능. devbrew의 equivalent:

- `code-review`-스타일 플러그인은 단일 리뷰어가 아니라 리뷰어 persona *라이브러리*를 가져야 함.
- 버그가 리뷰를 탈출하면, 해결책은 persona 파일 하나를 편집하고 커밋하는 것. 그 커밋이 compounding 이벤트입니다.
- Persona 파일은 일반적 역할이 아니라 *구체적 의견*을 이름으로 써야 함. "security reviewer"가 아니라 "CVE-X 때문에 길이 제한 없는 입력 파싱을 flagging하는 리뷰어". 이 구체성이 라이브러리가 성장하게 만듦.

**Roadmap absorption (C19+C24+C31+C32+C42+C63):** persona 라이브러리가 운영 측면에서 확장 — (C19) two-stage protocol (spec compliance check → code quality check, sequential, parallel 아님); (C24) baseline specialist `api-reviewer` + `performance-reviewer` always-on; (C32) extended catalog `data-migration` / `maintainability` / `red-team` 각각이 §4.4 contract에 따라 per-finding JSON emit; (C31) scope-gated dispatch — Testing + Maintainability는 ≥50 LOC에서 always-on, 나머지는 `SCOPE_*` env var로 조건부, Security + Testing에는 `[NEVER_GATE]` floor; (C42) tiered gating — eng-review는 유일한 hard gate, 모든 specialist review는 advisory; (C63) per-reviewer "What NOT to flag" 리스트로 reviewer-specific false positive 억제.

### P11. Cross-Model Adversarial at High-Stakes Moments

결정이 되돌리기 비싸면 단일 모델의 의견으로는 부족합니다. gstack의 `/codex`와 `/review` Step 5.7은 의도적으로 OpenAI Codex를 second opinion으로 끌어들임. OMC의 `ccg`는 질문을 Codex (arch/correctness/risks) + Gemini (UX/alternatives/docs) 프롬프트로 분해하고 conflict-surfacing을 명시하며 synthesize. Ouroboros의 Stage 3 consensus는 seed mutation마다 3 모델에서 2/3 majority를 요구.

devbrew의 입장: **단일 모델이 default, 다중 모델은 되돌리기 어려운 결정의 게이트.** "되돌리기 어렵다"는 것은: 프로덕션 배포, 스펙 mutation, 아키텍처 commitment, 보안-crit 코드, 스키마 마이그레이션. 다중 모델 레이어는 플러그인별 opt-in이지 강제 아님.

> *"Agreement is signal, not proof. […] AI models recommend. Users decide."* — gstack ETHOS, "User Sovereignty"
>
> *"Anti-pattern: 'Both models agree, so this must be correct.'"* — gstack ETHOS

**Roadmap absorption (C33+C52+C68):** multi-model adversarial이 운영 측면에서 확장 — (C33) always-on adversarial review (LOC나 risk signal에 조건부 아님, shipping을 gate하지 않음 — advisory only); (C52a) structural consensus trigger (7개 중 4개: SEED_MODIFICATION / ONTOLOGY_EVOLUTION / GOAL_INTERPRETATION / MANUAL_REQUEST는 multi-model concurrence 필요); (C52b) drift-aware consensus trigger (측정된 drift가 임계 초과 시 multi-model로 escalate); (C68) adversarial 4-technique framework — assumption violation, composition failure, cascade construction, abuse case. Depth-calibrated: 위험도에 따라 Quick / Standard / Deep.

### AP13. "Both Models Agree So It's Correct" (gstack)

*P11의 anti-corollary. 원래 위치: 구 §3.*

다중 모델 concordance는 signal이지 proof가 아님. 하니스는 모델들이 반대할 때 *conflict를 명시적으로 surface*해야 함 (OMC ccg 패턴), 그리고 agreement를 사용자의 최종 결정 (P17)의 bypass로 절대 treat해선 안 됨.

### AP14. Unchallenged Consensus

*P11의 anti-corollary. 원래 위치: 구 §3.*

잘못된 답으로 매끄럽게 수렴하는 루프나 consensus 메커니즘은 내장 방어가 없음. Ouroboros의 구체적 실패 모드는 ontology fixed-point convergence이지만, 패턴은 일반화됨: 여러 pass가 agree할 때 다음 pass는 "괜찮아 보여"를 default로 하고 잘못된 답이 굳음. devbrew 규칙: **정체가 아니라 *consensus*에도 최종 adversarial pass가 돈다.** 계획이 lock in되려 할 때, 여러 리뷰어가 agree할 때, 스펙이 결정화되려 할 때 — 하나의 독립 pass가 다시 공격. OMC ralplan의 필수 "steelman antithesis" before synthesis가 복제할 패턴. 이것은 AP13과 연결됨: agreement는 adversarial review로의 초대이지 그것의 bypass가 아님.

### 2.3 Under Law 3 — Compounding Memory

Law 3을 직접 봉사하는 원칙들. AP10은 P5 body에 흡수, AP17은 P14 body에 흡수 (standalone 헤더 없음).

### P5. Filesystem as Memory

상태는 context에 있는 게 아니라 파일에 있습니다. 하니스는 최소한의 인덱스만 미리 로드하고 (CLAUDE.md, 스펙, 플랜, 상태 파일), 나머지는 Glob/Read/Grep으로 on-demand 로드합니다. Anthropic:

> *"Rather than pre-processing all relevant data up front, agents built with the 'just in time' approach maintain lightweight identifiers […] and use these references to dynamically load data into context at runtime using tools. […] Claude Code is an agent that employs this hybrid model: CLAUDE.md files are naively dropped into context up front, while primitives like glob and grep allow it to navigate its environment and retrieve files just-in-time."* — *Effective Context Engineering*

devbrew는 이것을 그대로 상속합니다. 미리 로드되는 컨텍스트는 자기 자리를 벌어야 하고, 나머지는 agent가 필요할 때 발견합니다. **stale-index 없음, RAG 없음, vector store 없음.** Grep이 질의 언어입니다.

**흡수된 안티패턴 (구 AP10):** 코드베이스의 pre-baked search tree, vector store, cached embedding은 없습니다. Anthropic은 Claude Code가 이를 피한다고 명시합니다 *"effectively bypassing the issues of stale indexing and complex syntax trees."* Glob + grep + read, just-in-time, every time.

**Roadmap absorption (C66 — Linked Artifact Flow):** files-as-memory primitive이 *cross-artifact linkage*로 확장됩니다. Spec은 plan을 link하고, plan은 코드 경로를 link하고, 코드는 commit trailer (P20)로 spec을 역link합니다. 체인은 grep-traversable: 어떤 artifact든 stable ID에 대한 grep으로 전체 provenance graph를 복구할 수 있습니다.

### P14. State Survives Compaction

컨텍스트 윈도우는 compact될 것입니다. 하니스는 그럴 것이라 가정하고 그에 맞춰 설계해야 합니다. OMC의 PreCompact 훅은 compaction *전에* 상태를 `.omc/notepad.md`와 `.omc/project-memory.json`에 snapshot해서 다음 세션이 읽을 것이 있게 합니다. Anthropic은 이것을 일급 패턴으로 endorse합니다:

> *"In Claude Code, for example, we implement this by passing the message history to the model to summarize and compress the most critical details. The model preserves architectural decisions, unresolved bugs, and implementation details while discarding redundant tool outputs or messages."* — *Effective Context Engineering*

devbrew의 규칙: **다음 턴에 load-bearing한 사실은 턴이 끝나기 전에 파일에 기록되어야 한다.** Plan 파일, state 파일, 스펙 파일, 커밋 메시지, CLAUDE.md, review findings 마크다운 — 뭔가 지속적인 것. Chat-only 사실은 compaction 후 죽은 것으로 가정합니다.

**흡수된 안티패턴 (구 AP17):** 대화에만 존재하는 사실은 compaction 후 죽은 사실입니다. 다음 턴에 load-bearing한 사실은 턴이 끝나기 전에 파일에 존재해야 합니다.

### P15. The Initializer/Resumer Split for Long-Running Work

Anthropic의 *Effective Harnesses for Long-Running Agents*가 devbrew가 흡수할 패턴을 설명합니다:

> *"Initializer agent: The very first agent session uses a specialized prompt that asks the model to set up the initial environment: an init.sh script, a claude-progress.txt file that keeps a log of what agents have done, and an initial git commit that shows what files were added. Coding agent: Every subsequent session asks the model to make incremental progress, then leave structured updates."*

여러 세션에 걸쳐 작업을 실행하는 플러그인 (ralph-loop, schedule, background task)에 대해, 첫 세션의 일은 N번째 세션의 일과 *다릅니다*. 첫째는 지속 가능한 state를 bootstrap하고, 이후 모든 세션은 그 state에서 이어집니다. 이것이 `quality-gates`의 Stop-hook 상태 머신이 이미 가지고 있는 형태입니다. devbrew는 이것을 일반화합니다.

### P16. Measure, Don't Trust

하니스가 내세우는 모든 claim("3× 더 빠름", "더 많은 버그를 잡음")은 벤치마크로 뒷받침되어야 합니다. OMC는 경계할 케이스입니다: `benchmarks/harsh-critic/`, `/code-reviewer/`, `/debugger/`, `/executor/` suite를 *ground-truth JSON과 runner까지* 가지고 있지만, README의 수치 claim은 벤치마크 출력에서 인용되지 않습니다. devbrew는 인프라를 채택하고 간격을 메웁니다: 어떤 플러그인이 quantitative 개선을 claim하면 그 수치를 생산하는 `plugins/<name>/benchmarks/`를 반드시 shipping해야 합니다.

**Roadmap absorption (C9+C54):** 측정이 확장 — (C9) dimensional progress tracking (per-cycle metric: ambiguity reduction Δ, convergence Δ, defect-escape rate, stagnation event); (C54) drift measurement formula (정량 drift = `0.4·structural_drift + 0.4·semantic_drift + 0.2·behavioral_drift`, action 임계는 skill frontmatter에 선언).

### P20. Commit Trailers as Decision Audit Trail

OMC는 구조화된 커밋 trailer를 사용 — `Constraint:`, `Rejected:`, `Directive:`, `Confidence:`, `Scope-risk:`, `Not-tested:` — *why*를 git 히스토리에 encoding. 이것은 독특하게 강력하고 싸다: *why*가 git 메타데이터로 survive, forever queryable, 다음 세션 agent는 `git log --format="%B"`로 결정 컨텍스트 복구 가능. devbrew는 이것을 관례로 채택 (요구사항 아님) — 결정 히스토리를 신경 쓰는 플러그인이 사용하고, `project-init`는 리포의 git-workflow 문서에 이것을 문서화해야 함.

### 2.4 Cross-Cutting Commitments (serve all three Laws)

세 법칙 모두에 봉사하는 원칙들. AP2, AP4, AP6, AP7, AP8, AP9, AP12, AP15, AP16이 anti-corollary로 nested.

### P6. Progressive Disclosure for Skills

*L1, L2, L3 봉사:* skill 이름 + 1줄 설명이 spec 시점 인터페이스 (L1); body는 단일 contract로 독립 리뷰 가능 (L2); compounding은 preload 비용 증가 없이 skill/anti-example 추가 (L3).

스킬 이름 + 한 줄 설명만이 미리 로드되는 유일한 부분입니다. 본문은 trigger될 때 읽힙니다. References와 scripts는 invoke될 때까지 0 비용. 이것은 Anthropic의 명시적 skill-authoring best practice이고 CE가 v2.39.0에서 commands → skills로 이주한 이유입니다. devbrew는 이것을 전면 수용합니다.

**authoring에 대한 결과 (skills이지, commands가 아님):**

- **스킬 이름은 동명사** (`running-quality-gates`, `authoring-specs`, `compounding-learnings`). Anthropic의 skill-authoring best practice. 모호한 이름(`helper`, `utils`, `tools`)은 절대 안 됨.
- **Command 이름은 짧은 명령형 동사 또는 명사** (`qg`, `review`, `commit`, `plan`). 동명사가 아님. Commands는 사용자가 타이핑하는 ritual이고 typing 속도 최적화, description-triggered 매칭이 아님. CE의 `ce-plan`/`ce-work`/`ce-review`, gstack의 `/office-hours`/`/ship`이 템플릿입니다.
- **Description은 선언형** (`what + when`), 1인칭 절대 금지 (`"I can help you…"`는 금지 — agent가 초대를 파싱하게 만들기 때문, 조건을 파싱해야 함).
- **Skill 본문은 완전한 계약**입니다. 더 깊은 내용의 loader가 아님. OMC의 skill 섹션 스키마 (`<Purpose>`, `<Use_When>`, `<Do_Not_Use_When>`, `<Why_This_Exists>`, `<Steps>`, `<Good>`/`<Bad>` 예시, `<Escalation_And_Stop_Conditions>`, `<Final_Checklist>`)가 복제할 템플릿입니다.
- **반례(Anti-example)는 일급 시민.** `<Bad>` with "Why bad:"는 까다로운 판단을 다루는 모든 스킬에 포함되어야 합니다.

**Roadmap absorption (C57 — Review Mode Detection):** invocation context에 적응하는 스킬. 4 mode: `headless` (CI, no prompts, machine-readable verdict emit), `autofix` (safe fix를 inline 적용), `report-only` (findings surface, action 없음), `interactive` (decision point에서 사용자 prompt). mode는 환경/invocation flag에서 감지되고 가정하지 않음. default = 명시적 사용자 invocation 시 `interactive`.

### AP7. Vague Skill Names and Capability Descriptions (Anthropic skill best practices)

*P6의 anti-corollary. 원래 위치: 구 §3.*

*"Helper," "Utils," "I can help you…"* — 전부 금지. Skill description은 선언적, 구체적, action verb 사용이어야 함. Description은 preloaded system prompt에서 자기 자리를 벌 유일한 기회 — 낭비된 단어는 매 세션 비용.

### AP8. Technical-Identifier Pollution in Tool Responses (Anthropic writing-tools)

*P6의 anti-corollary. 원래 위치: 구 §3.*

Agent가 `name`, `caption`, `file_type`이 필요할 때 `uuid`, `mime_type`, `256px_image_url`을 반환하는 것은 signal을 crowd out. devbrew 플러그인의 tool response는 model downstream 결정을 위해 curate되지, API 완전성을 위해서가 아님.

### P7. Loops, Not One-Shots

*L1, L2, L3 봉사:* loop의 첫 단계는 spec 작성 (L1); review 단계는 구조적으로 분리 (L2); compound tail은 명명된 learning 캡처 단계 (L3).

작업은 사이클을 통해 흐릅니다. 단일 pass가 아닙니다. 단위는 "spec → plan → implement → review → verify → compound"이고, 전체 루프가 작업당 돌아갑니다. 세션당이 아닙니다. CE의 4-step `Plan → Work → Review → Compound`가 정전 이름 붙은 사이클입니다. OMC의 `autopilot` 5-phase 파이프라인(Expansion → Planning → Execution → QA → Validation → Cleanup)이 더 정교한 인스턴스이고, Ouroboros의 inner/outer 중첩 루프 with Wonder/Reflect가 가장 야심 찬 버전입니다. devbrew의 `quality-gates`는 이미 spine이 있습니다 (Gate 1 plan → Gate 2 review → Gate 3 runtime, 코드 변경 시 Gate 1로 loop back).

**devbrew가 quality-gates에 추가할 것:** tail의 명시적 `compound` 단계 — 여섯 번째 게이트든, post-pipeline 스킬이든 — 파일에 learning을 기록하는 것이 유일한 역할.

### P8. Maintain Simplicity (YAGNI, delete-over-add)

*L1, L2, L3 봉사:* 명시할 표면 감소 (L1); 리뷰어가 disagree할 것 감소 (L2); deletion은 가장 싼 compounding 동작 (L3).

Anthropic의 *Building Effective Agents* 첫 원칙이 literal합니다: *"Maintain simplicity in your agent's design."* OMC의 `AGENTS.md`는 *"Prefer deletion over addition when the same behavior can be preserved."*로 표현. gstack의 ETHOS는 "boil the lake" 원칙을 명시적 compression table과 함께 묶으며 corollary를 제시: *"The last 10% of completeness that teams used to skip? It costs seconds now."* 주의 깊게 읽으면 이들은 긴장 관계가 아닙니다 — Anthropic은 *architectural* 복잡도를 경고하고 (프레임워크, 추상 레이어, workflow로 충분한데 agent 사용), gstack은 *task-completion* 완전성을 촉구합니다 (테스트 스킵 금지, 에러 경로 스킵 금지).

devbrew의 입장: **아키텍처는 최소주의, 작업 실행은 극대주의.** 플러그인은 하나를 잘 하고, 다른 플러그인과 composition하고, 프레임워크 추상화를 피하고, 하지만 실행할 때는 철저하게 실행합니다.

> *"For many applications, optimizing single LLM calls with retrieval and in-context examples is usually enough. […] Don't hesitate to reduce abstraction layers and build with basic components as you move to production."* — Anthropic, *Building Effective Agents*
>
> *"AI-assisted coding makes the marginal cost of completeness near-zero."* — gstack ETHOS

### AP4. LOC as Success Metric

*P8의 anti-corollary. 원래 위치: 구 §3.*

Tan의 공개 claim *"600,000+ lines of production code, 10,000–20,000 lines per day"*는 정당한 비판을 받음. LOC는 활동을 측정, 결과 아님. devbrew는 코드 양을 보상하는 metric을 절대 shipping하지 않음. *ticket 닫힘, verification 통과, regression 감소, iteration 수 감소*를 보상하는 metric을 shipping.

### AP6. Framework Abstraction in Production (Anthropic)

*P8의 anti-corollary. 원래 위치: 구 §3.*

> *"Don't hesitate to reduce abstraction layers and build with basic components as you move to production."*

Claude Code primitive를 감싸는 내부 프레임워크 없음. 플러그인이 스크립트가 필요하면 스크립트를 씀 — DSL 아님, config-generating-config 아님, 클래스 계층 아님. OMC의 `run.cjs` 중앙 dispatcher가 경계 케이스 — 모든 훅이 이걸 거쳐서, Python/Rust 팀에 Node.js 의존성을 생성.

### P9. Composition Over Monolith

*L1, L2, L3 봉사:* 플러그인별 spec이 좁게 유지 (L1); 플러그인별 리뷰어 scope 누출 없음 (L2); 플러그인별 learning이 도메인에 한정 (L3).

플러그인은 하나를 잘 하고 나머지는 다른 플러그인에 위임합니다. `quality-gates`가 이미 이 모델입니다 — Gate 2가 pr-review-toolkit, feature-dev, superpowers agent들에 dispatch. 철학은 이것을 일반화합니다: **devbrew의 모든 플러그인은 marketplace의 시민이지, 자족적인 왕국이 아닙니다.** 두 플러그인이 overlap하면 둘 다 사용할 수 있는 제3 플러그인으로 refactor, 다른 곳에 존재하는 capability가 필요하면 `README.md` prerequisites에서 명시적으로 의존.

이것이 anti-OMC-monolith 이동입니다. OMC는 20 hooks + 32 skills + 19 agents를 한 플러그인으로 shipping합니다. 편의성을 사지만 모든 결합 비용을 상속하고 per-capability 채택을 불가능하게 만듭니다. devbrew는 상호 운용하는 많은 작은 플러그인을 선호합니다.

**따름정리 — delegation 관례:** 플러그인이 다른 플러그인의 agent를 `subagent_type: "other-plugin:agent-name"`으로 dispatch할 때, 그 의존성은 플러그인 README의 prerequisites 테이블에 선언됩니다 (quality-gates는 이미 이렇게 합니다). 선언되지 않은 의존성은 버그입니다.

**Roadmap absorption (C61 — 5-Dimension Overlap Detection):** 두 플러그인이 overlapping capability를 제안할 때, composition discipline은 merge/coexist/refactor 결정 전에 5-dimension check를 적용: (a) input contract, (b) output contract, (c) side-effect surface, (d) cost class, (e) failure modes. 동일한 5-tuple을 가진 두 플러그인은 둘 다 depend하는 제3 플러그인으로 refactor.

### AP12. Undeclared Plugin Dependencies

*P9의 anti-corollary. 원래 위치: 구 §3.*

`other-plugin:agent-name`을 dispatch하는 플러그인은 README prerequisites 테이블에 `other-plugin`을 선언해야 함. Silent coupling은 버그. 의존성이 없으면 플러그인은 우아하게 degrade해야 (P19), hard-fail이 아님.

### P13. Hooks for Enforcement, Skills for Capability, Agents for Personas

*L1, L2, L3 봉사:* skill 이름이 spec 시점 발견 가능 표면 (L1); agent가 역할 분리 enforce (L2); hook은 사이클을 넘어 살아남는 durable enforcement (L3).

Claude Code primitive 간 명확한 역할 분담:

- **Hooks**는 하니스의 집행(enforcement) 레이어입니다. agent가 무엇을 생각하든 상관없이 돌아갑니다. agent가 기억할 것이라 믿을 수 없는 것들에 사용: compaction 전 상태 보존 (OMC PreCompact 훅), 작업이 verified done 아니면 stop 거부 (OMC `persistent-mode.cjs`), 패턴 매칭 프롬프트 redirection (Ouroboros `keyword-detector.py`), PR shape validation, branch-name check.
- **Skills**는 capability 표면입니다. agent는 상황을 인식할 때 스킬을 invoke합니다. 재사용 가능한 절차에 사용: `authoring-specs`, `running-quality-gates`, `compounding-learnings`, `reviewing-with-personas`.
- **Agents**는 범위 제한된(scoped) 도구 접근을 가진 페르소나입니다. agent는 어떤 것에 *독립적 pass*가 필요할 때 다른 agent를 dispatch합니다. 역할 분리 (P3)에 사용: writer, reviewer, critic, verifier.
- **Commands**는 사용자 invoke ritual입니다. 드물게 사용하세요 — 선언적 trigger를 가진 skill이 보통 낫습니다. CE가 v2.39.0에서 commands로부터 이주한 이유입니다.

**훅 공존 규칙 (P9 × P13 상호작용).** devbrew는 많은 작은 플러그인을 선호하므로 (P9), 여러 플러그인이 같은 event에 훅을 설치할 수 있습니다. 하우스 규칙:

1. **훅을 네임스페이스화.** 훅 스크립트는 `plugins/<name>/hooks/` 아래 살고 `hooks/hooks.json`에서 플러그인 범위로 선언. 한 event에 자신이 유일한 훅이라고 절대 가정하지 않기.
2. **같은 event 내에서 훅은 교환 가능해야 함 (commutative).** 다른 플러그인의 훅이 먼저 돌든 나중 돌든 동일한 결과를 내야 합니다. 순서가 중요하다면 그것은 설계 버그 — 순서 민감 플러그인이 명시적으로 dispatch하는 skill로 refactor.
3. **`Stop` 훅 idempotency.** 플러그인의 `Stop` 훅이 signal tag를 읽고 (quality-gates의 `<qg-signal>`) 다음-턴 프롬프트를 주입한다면, 그 signal tag는 해당 플러그인 고유여야 하고 다른 플러그인의 signal과 충돌하지 않아야 함. `<{plugin}-signal>` 관례 사용.
4. **Mutation-free `SessionStart` 훅.** `SessionStart` 훅은 read-only 조언자입니다. state를 로드하고 status를 surface; 절대 mutate 안 함. 두 플러그인의 session-start 훅이 공존할 수 있는 유일한 방법입니다.
5. **훅 표면 선언.** 모든 플러그인의 README는 자신이 어떤 훅 event에 설치되고 어떤 signal/namespace를 소유하는지 리스트. 플러그인 간 충돌은 코드 리뷰에서 잡힐 버그.
6. **플러그인별 kill switch.** 플러그인이 설치한 모든 훅은 플러그인별 opt-out env var (`DEVBREW_DISABLE_<PLUGIN>=1` + `DEVBREW_SKIP_HOOKS=<plugin>:<hook-name>`)가 있어야 함. OMC의 `DISABLE_OMC=1` / `OMC_SKIP_HOOKS=...`이 템플릿.

### P17. User Sovereignty

*L1, L2, L3 봉사:* approval gate는 spec에 선언 (L1); 사용자가 최종 리뷰어 (L2); 사용자 승인 결정이 기록된 default가 됨 (L3).

사용자가 결정을 내리고, agent는 권고합니다. gstack의 ETHOS는 이렇게 표현: *"AI models recommend. Users decide. This is the one rule that overrides all others."* Ouroboros는 Dialectic Rhythm Guard로 encode합니다 (*"after 3 consecutive non-user answers, the next question MUST be routed to the human"*). Anthropic의 저술은 plan mode, 투명성, 명시적 승인 게이트 강조를 통해 같은 입장을 지지합니다.

devbrew의 번역: **위험한, 되돌리기 어려운, 공유 state에 영향을 주는 액션은 항상 confirmation 게이트를 거친다.** 새 액션 표면을 추가하는 플러그인은 어떤 액션이 위험한지 결정하고 `AskUserQuestion` 또는 `ExitPlanMode` 승인에 연결해야 합니다.

**Roadmap absorption (C56 — Autofix Disposition Tiers):** 리뷰어가 fixable issue를 발견하면 disposition이 4-tier로 라우팅: (a) `safe_auto` — review-fixer가 inline 적용, 사용자 prompt 없음; (b) `gated_auto` — downstream-resolver가 `AskUserQuestion` 통해 적용 (P22 cost gate 따름); (c) `manual` — 인간 결정으로 surface; (d) `advisory` — PR description으로 release, fix 시도 없음. Tier 선택은 리뷰어의 결정이고 dispatcher는 이를 honor.

### AP2. "Polite Stop" (OMC)

*P17의 anti-corollary. 원래 위치: 구 §3.*

긍정적 리뷰 후 **내러티브 요약을 narrate하는** Claude의 본능. OMC Ralph step 7: *"Treating an approved verdict as a reporting checkpoint is a polite-stop anti-pattern."* 리뷰가 통과하면 다음 액션은 `/cancel` 또는 다음 사이클이지 내러티브 recap이 아닙니다. devbrew의 플러그인은 verified-done과 next-action 사이에 보고 pause를 삽입하면 안 됨.

**구분 — polite stop vs approval gate.** §5.2는 "결정 경계에서 pause, 안쪽은 hard run"이라고 말합니다. 이것은 polite stop이 아닙니다. **Approval gate**는 결정 *전에* 사용자가 redirect할 수 있도록 하는 pause (`ExitPlanMode`, 위험한 액션에 대한 `AskUserQuestion`, spec 결정화 체크포인트). **Polite stop**은 결정이 verified done 된 *후에* 사용자가 요청하지 않은 내러티브 요약을 삽입하는 pause. Approval gate는 사용자 주권 (P17)에 기여, polite stop은 사용자의 attention budget을 낭비. 의심스러울 때: 사용자가 답해서 *redirect*할 수 있다면 approval gate. *acknowledge*만 할 수 있다면 polite stop — skip하세요.

### P18. Stagnation Is a Failure Mode, Not a Natural End

*L1, L2, L3 봉사:* 선언된 max-iter / kill-switch는 spec의 일부 (L1); detection은 진전의 verification (L2); 정체 시 lateral persona dispatch는 compound 이벤트 (L3).

같은 것을 계속 재시도하는 루프는 진전을 만드는 게 아니라 멈춘 것입니다. 네 하니스 모두 명시적 정체 감지 로직을 가집니다:

- OMC의 `ultraqa`는 같은 에러가 3번 반복되면 조기 종료.
- OMC의 `self-improve`는 plateau 감지에서 종료.
- Ouroboros는 A→B→A→B 진동과 ≥70% 반복 질문을 `stagnated`로 감지하고, lateral thinking persona로 `unstuck` 호출.
- gstack의 `/investigate` 철 법칙: *"no fixes without investigation."*

devbrew의 규칙: 모든 loop-bearing 플러그인은 circuit breaker와 함께 shipping — 최대 반복 카운트, 반복 감지 heuristic, 재시도 대신 *다른* 접근을 invoke하는 escape hatch (fresh subagent, 다른 리뷰어, human prompt).

**Roadmap absorption (C46 — Lateral Thinking Persona Recovery):** stagnation 감지 시 recovery dispatch는 persona affinity table을 사용 (결정적 first-match): HACKER → SPINNING, RESEARCHER → {NO_DRIFT, DIMINISHING_RETURNS}, SIMPLIFIER → {DIMINISHING_RETURNS, OSCILLATION}, ARCHITECT → {OSCILLATION, NO_DRIFT}, CONTRARIAN → all. 각 persona는 stagnation 패턴 특화 lateral-thinking heuristic + fresh prompt로 도착.

### AP16. Unbounded Autonomy Without Stop Conditions

*P18의 anti-corollary. 원래 위치: 구 §3.*

"멈추지 않는" 루프는 (Sisyphus framing) 토큰을 태우고 사용자가 시스템을 불신하게 만듭니다. 모든 autonomous 루프는 다음을 가져야 함: (a) max iteration 카운트, (b) wall-clock budget, (c) repeat 감지 (P18), (d) 사용자-overrideable kill switch (OMC의 `DISABLE_OMC=1`과 `cancel-qg`가 템플릿).

### P19. Graceful Degradation of External Dependencies

*L1, L2, L3 봉사:* fallback 동작이 spec에 선언 (L1); loud logging이 degradation을 reviewable로 만듦 (L2); failure-mode 노트가 compounding으로 흐름 (L3).

OMC의 `ccg`, `codex`, `gemini`, `deslop` 스킬은 모두 graceful-degradation 조항을 가집니다 — 외부 tool이 없으면 skill은 downgrade하지만 실패하지 않습니다. devbrew는 상속: **선택적 외부 tool에 의존하는 플러그인은 tool이 없을 때 (줄어든 capability와 명시적 로그로) 계속 작동해야 한다.** 하드 블록은 플러그인이 진정으로 살 수 없는 것에만 예약.

### AP15. Silent Fallback Demotion

*P19의 anti-corollary. 원래 위치: 구 §3.*

Optional 의존성이 없을 때 (`--critic=codex` with Codex CLI 미설치) 더 약한 critic으로 silent fall back 하는 것은 degradation을 숨김. devbrew 규칙 (P19 + 증거 규율의 조합): **graceful degradation은 loudly log해야 함.** 사용자는 출력만으로 의도된 reviewer가 돌았는지 fallback이 돌았는지 알 수 있어야 합니다.

### P21. Security & Supply Chain

*L1, L2, L3 봉사:* threat model이 spec에 선언 (L1); persona-files-as-code 정책이 security를 reviewable로 만듦 (L2); kill-switch + integrity field가 플러그인 업데이트 사이에 compound (L3).

플러그인은 코드이고 agent는 prompt입니다 — 둘 다 공격 표면입니다. devbrew의 최소 보안 자세:

- **State file secret hygiene.** State 파일 (`.claude/<plugin>.local.md`)은 git-ignore되지만 (P5, §4.8) 의도치 않게 공유될 수 있음 (백업, 복사, 버그 리포트 첨부). 플러그인은 state 파일에 secret (토큰, API key, 풀 PII)을 기록해선 안 됨. placeholder 참조 (`$GITHUB_TOKEN`, 경로 참조) 사용.
- **Persona 파일은 코드다.** Reviewer persona 파일은 (P10, §4.4) 버그를 잡는 load-bearing default. persona checklist를 약화(규칙 제거, 임계치 완화)하는 PR은 **보안-민감 변경**이고 test suite 수정과 같은 수준의 scrutiny 필요. `git diff`가 `plugins/*/reviewers/` 아래 파일을 건드리면 PR 템플릿이 이를 "security-relevant"로 flag.
- **Plugin-to-plugin trust.** 플러그인 A가 `plugin-b:agent-name`을 dispatch하면 A는 B의 agent 동작을 상속합니다. B가 악의적 prompt injection으로 업데이트되면 A의 사용자가 영향받음. 완화책: (a) 최소 버전이 선언된 의존성 (P9, AP12) — A가 B를 알려진 good 버전에 pin 가능. (b) `plugin.json`은 critical 의존성에 대해 optional `integrity` field (git SHA 또는 tag)를 포함해야 함. (c) 여러 플러그인이 관여할 때 supply-chain 리뷰는 `quality-gates` Gate 2의 일부.
- **Description의 prompt injection.** Skill description은 매 세션의 system prompt에 preload됩니다. 악의적 skill description은 prompt-injection payload를 담을 수 있음. plugin-to-plugin merge에서 skill description의 anomaly (이상한 instruction, role-override 시도, Unicode 트릭) 리뷰.
- **Kill switch는 보안 컨트롤이기도 함.** Per-plugin kill switch (`DEVBREW_DISABLE_<PLUGIN>=1`, P13 참조)는 사용자가 플러그인을 즉시 비활성화하게 해줌. 모든 플러그인은 autonomous 실행 중에도 kill switch를 존중해야 함. 어떤 훅도 kill switch를 inspect하고 거부해선 안 됨.

이것은 바닥(floor)이지 천장이 아닙니다. Secret/자격 증명/프로덕션 시스템을 다루는 플러그인은 더 필요합니다.

### P22. Cost Awareness

*L1, L2, L3 봉사:* cost class가 skill frontmatter에 선언 (L1); fan-out cap이 리뷰어 fan-out을 gate (L2); budget-vs-actual 데이터가 사이클 간 compound (L3).

AI 보조 workflow는 비쌀 수 있습니다. OMC의 `ccg`는 한 질문을 Codex + Gemini + Claude 호출로 분해. gstack의 `/review`는 25 specialist sub-agent로 fan-out. Ouroboros의 consensus 게이트는 3 모델 사용. 무심한 플러그인은 경고 없이 호출당 $10+를 쓸 수 있습니다. devbrew의 비용 규율:

- **Cost class를 skill frontmatter에 선언.** 모든 스킬은 worst-case 동작 기반으로 `cost_class: low | medium | high | variable` 선언. `low` = 단일 모델, bounded 반복. `medium` = multi-step 또는 multi-agent fan-out. `high` = 다중 모델 (cross-vendor) 또는 N-parallel where N ≥ 5. `variable` = 입력 크기에 따라 비용이 달라지는 스킬에 예약 (예: large file processing).
- **High-cost 스킬은 명시적 사용자 게이트 필요.** `cost_class: high` 스킬은 지출 전에 `AskUserQuestion` (또는 P17 승인 게이트 equivalent)을 invoke해야 합니다. 사용자의 승인은 행동뿐 아니라 비용에 대한 동의입니다.
- **품질 기준을 만족하는 가장 싼 tier가 default.** OMC의 `haiku/sonnet/opus` tier variant가 템플릿 (§5.4). Haiku로 돌 수 있는 reviewer persona는 Haiku에서 돌고, Sonnet/Opus로의 escalation은 명시적, default가 아님.
- **Fan-out factor 선언.** N parallel sub-agent를 dispatch하는 어떤 스킬이든 `<Use_When>` 섹션에 N (literal 또는 computed) 선언. `N ≥ 5`는 hard gate. `N ≥ 10`은 multi-model adversarial pass (P11) 또는 sub-agent에 tier enforcement 요구.
- **Budget이지 promise 아님.** Cost 숫자는 budget(천장)이지 promise(바닥)이 아님. 스킬이 `cost_class`가 시사하는 것보다 싸게 돌면 괜찮음. 클래스보다 **더** 비싸게 도는 스킬은 버그.
- **무한 루프 없음.** P18 (정체 감지)과 AP16 (unbounded autonomy)은 이미 max-iteration 카운트를 요구. P22 추가: max iteration × worst-case-per-iteration cost = 전체 스킬의 선언된 budget ceiling.

### AP9. Over-Dispatching Subagents (Anthropic multi-agent)

*P22의 anti-corollary. 원래 위치: 구 §3.*

> *"[Early agents] made errors like spawning 50 subagents for simple queries."*

다중 agent research의 4× token 비용은 breadth가 실제로 필요할 때만 가치 있음. devbrew 플러그인은 single-agent를 default로 하고 fan-out은 case-by-case로 justify해야 함.

### P23. Versioning & Deprecation

*L1, L2, L3 봉사:* version-as-contract 선언 (L1); CHANGELOG 항목이 reviewable (L2); deprecation 윈도우가 institutional memory (L3).

플러그인은 진화합니다. 철학은 호환성에 대한 공유 vocabulary가 필요합니다:

- **`.claude-plugin/plugin.json#version`에 대한 SemVer:**
  - **Major** bump (X.0.0 → Y.0.0) — 어떤 공개 표면에 대한 breaking change: command/skill/agent 제거, agent의 `allowedTools`를 capability를 제거하는 방식으로 변경, 플러그인 renaming, 의존성 버전 요구사항을 backward-incompatible하게 변경, kill-switch env var 이름 변경.
  - **Minor** bump (X.Y.0 → X.(Y+1).0) — 추가적: 새 command/skill/agent/hook, 새 optional 의존성, 새 `cost_class` enhancement, 새 persona 파일.
  - **Patch** bump (X.Y.Z → X.Y.(Z+1)) — fix: 오타, prompt 조임, anti-example 추가, hook 스크립트 버그 fix, 공개 계약을 바꾸지 않는 persona checklist 확장.
- **`plugins/<name>/`를 건드리는 모든 PR에서 bump.** 위 SemVer 규칙이 *어느* 버전 컴포넌트가 bump되는지 결정.
- **Deprecation 윈도우 — 한 minor 버전.** 공개 표면을 제거할 때 먼저 minor 버전에서 deprecated로 표시 (skill/command description에 경고 추가), 그다음 minor에서 제거. 사전 deprecation minor 없는 제거는 하우스 위반.
- **v1.0.0+ 플러그인에 CHANGELOG.md 필수.** `1.0.0`에 도달한 모든 플러그인은 플러그인 루트에 `CHANGELOG.md`를 `## [version] — YYYY-MM-DD\n### Added/Changed/Deprecated/Removed/Fixed/Security` 형식으로 shipping. `1.0.0` 미만 플러그인은 실험적으로 간주. 하우스 요구사항은 `1.0.0`부터 시작.
- **Breaking change는 CHANGELOG에 마이그레이션 노트와 함께 주석** — 변경 사실뿐 아니라 사용자가 adapt하기 위한 최소 액션.

---

## 3. Anti-Corollaries  (formerly "Named Anti-Patterns")

각 anti-pattern (AP1–AP17)은 이제 자신이 negate하는 원칙(§2) 아래에
*anti-corollary*로 nested됩니다. ID 단위 마이그레이션 매핑은 §11.1 참조.
3개 패턴 (AP10, AP11, AP17)은 부모 원칙 body에 완전 흡수되어 §11.1에
redirect로만 존재합니다.

---

## 4. Primitives the Harness Must Provide (the shape of a devbrew plugin)

위 원칙을 적용해서, `devbrew/plugins/*`의 모든 플러그인은 이 primitive들을 중심으로 구조화되어야 합니다. 모든 플러그인이 모든 primitive를 필요로 하지는 않습니다 — 플러그인 목적에 맞는 것을 고르세요 — 하지만 각 primitive는 단일 canonical shape를 가집니다.

### 4.0 Canonical Plugin Directory Structure  [Serves: L1, L2, L3]

`plugins/<name>/` 하위의 모든 플러그인은 이 레이아웃을 사용합니다. 이탈은 플러그인 README에서 justify되어야 합니다:

```
plugins/<name>/
├── .claude-plugin/
│   └── plugin.json         # REQUIRED: name, description, version; optional: author, license, repository, integrity
├── .mcp.json               # OPTIONAL: MCP server 선언
├── README.md               # REQUIRED: prerequisites, principles-instantiated, hooks-installed, kill-switches, cost_class 요약
├── CHANGELOG.md            # v1.0.0부터 REQUIRED (P23)
├── commands/               # OPTIONAL: 짧은 명령형 이름 (qg, review, commit)
│   └── <command>.md
├── skills/                 # OPTIONAL: 동명사 이름 (running-quality-gates)
│   └── <skill-name>/
│       ├── SKILL.md
│       └── references/     # OPTIONAL: 필요 시 로드되는 더 깊은 내용 (P6)
├── agents/                 # OPTIONAL: allowedTools/disallowedTools로 role-scoped (P3)
│   └── <agent>.md
├── hooks/                  # OPTIONAL: 하니스 enforcement (P13)
│   ├── hooks.json
│   └── <hook-name>.(py|sh|mjs)
├── scripts/                # OPTIONAL: skill/hook이 invoke하는 헬퍼 (추상 레이어 아님 — AP6)
├── templates/              # OPTIONAL: 플러그인이 사용자 repo에 생성하는 boilerplate
├── reviewers/              # OPTIONAL: persona 파일 (P10) — 플러그인이 review 라이브러리를 제공하는 경우
│   └── <persona-name>.md
└── benchmarks/             # README claim이 quantitative하면 REQUIRED (P16)
    ├── fixtures/
    ├── ground-truth.json
    └── run.(py|sh)
```

**이 레이아웃의 규칙:**

- 플러그인 콘텐츠를 감싸는 `src/` 디렉토리 없음. 플러그인은 디렉토리 *그 자체*. 헬퍼 코드는 `scripts/` 아래 flat 파일로 직접 살음 (AP6 — 프레임워크 추상화는 금지).
- `lib/`나 `vendor/` 없음 — 플러그인이 의존성이 필요하면 전역 설치된 tool에 shell out (P19 graceful degradation)하거나 명시적 attribution으로 단일 파일을 vendor.
- 플러그인 디렉토리 내 `.github/` 없음 — CI/CD 관심사는 devbrew 리포 루트에 있고, 플러그인별이 아님.
- `README.md`는 필수 "Principles Instantiated" 섹션을 가지고, 이 플러그인이 어떤 20+ 원칙을 embody하는지 한 줄 설명과 함께 리스트. 이것이 Law 3의 compounding substrate: 미래의 당신이 모든 플러그인 README에서 특정 원칙을 검색하면 모든 instantiation을 찾을 수 있음.

### 4.1 Spec Authoring (P1, P2)  [Serves: L1]

- 알려진 위치(제안 default: `docs/specs/YYYY-MM-DD-<topic>.md` git-tracked — 최종 관례는 §9의 open question)에 스펙 마크다운 파일을 작성하는 skill.
- Skill은 구조적 baseline 게이트를 가짐 (P2 baseline). 게이트가 충족될 때까지 종료 거부.
- Skill의 `<Steps>`는 종료 전 adversarial self-review pass를 포함 (gstack Phase 5.5 + OMC ralplan Critic) — 이것은 baseline 위의 enhancement이지만 강력 권장.
- **스펙 형식 — 필수 섹션:**
  1. **Context/Why** — 어떤 문제를 해결, 누가 요청, 원하는 결과
  2. **Goals** — bullet, 측정 가능
  3. **Non-goals / Out-of-Scope** — scope drift 방지를 위한 명시적 제외
  4. **Constraints** — 언어, deps, 파일시스템 범위, 성능 budget, 시간 budget
  5. **Acceptance Criteria** — 번호 붙음, checkable, 독립 검증 가능
  6. **Files to Modify** — 리포-상대 경로, 다단계면 phase별 그룹
  7. **Verification Plan** — 세 양식(mechanical/semantic/runtime, P4) 중 어느 것이 AC를 증명하는지
  8. **Rejected Alternatives** — 고려됐지만 진 approach들과 그 이유. 최소 한 entry 필요. "고려 없음"은 adversarial review pass가 스펙을 거절할 근거.
  9. **Metadata** — author, created date (ISO 8601), parent issue/PR 링크, spec version
- **Escape hatch:** trivia diff는 spec authoring을 우회 (§2.1 / P12 canonical mention 참조).

### 4.2 Plan Authoring (P1, P7, P12)  [Serves: L1]

- 스펙을 받아 구현 플랜 마크다운 파일을 생산하는 skill.
- 플랜은 *스펙 없이 읽힐 수 있어야* 함 (context가 상단에 재명시).
- 플랜은 번호 붙은 checkable 단계와 verification 섹션을 가짐.
- 플랜은 `ExitPlanMode`로 승인 — 사용자는 chat 요약이 아니라 파일을 읽고 게이트.

### 4.3 Writer/Executor Agents (P3, P8)  [Serves: L2]

- 코드 작성 agent는 이름 있음 (`executor`, `developer` 아님), `allowedTools` frontmatter scoping 있음, system prompt는 *"You are X. You are responsible for Y. You are NOT responsible for Z."*로 시작.
- Executor는 자기 작업을 승인하지 않음.
- Executor는 동작 보존 시 **추가보다 삭제**를 선호.
- Executor는 diff를 작게, 되돌릴 수 있게, scope 있게 유지.

### 4.4 Reviewer Agents / Persona Library (P3, P10)  [Serves: L2]

- Review는 여러 persona-named 파일로 분해 (`kieran-python-reviewer.md`, `security-sentinel.md`, `correctness-checker.md`).
- 각 persona는 작고 편집 가능한 마크다운 파일 — 버그 fix가 *persona 하나의 checklist*를 업데이트해서 라이브러리가 성장.
- Review는 **구조화된 findings**를 생산 (severity, confidence 1–10, 위치, exploit/impact, 권장 fix), dispatcher는 merge + dedupe.
- Confidence 임계치 아래 findings는 appendix로 suppress (gstack: 7+ 표시, 5–6 flag, <5 suppress).
- Critical 실패는 stack trace가 아니라 "왜 중요한가" context와 함께 surface.
- **Verdict envelope (C20).** 모든 리뷰어는 `APPROVE | REQUEST CHANGES | COMMENT` × `CRITICAL | HIGH | MEDIUM | LOW` 형식의 top-level verdict를 emit합니다. dispatcher는 most-severe 규칙으로 multi-reviewer envelope를 단일 PR-level verdict로 merge합니다.
- **Per-finding payload contract (C30).** verdict 내 개별 finding은 JSON-shape: `{severity, confidence (1-10), path, line, category, summary, fix, fingerprint, specialist}`. Sentinel: 리뷰어가 추가할 게 없으면 `NO FINDINGS`. Confidence 표시 rubric: 9-10 show, 7-8 show, 5-6 caveat, 3-4 suppress to appendix, 1-2 P0-only.

### 4.5 Verifier (P4)  [Serves: L2]

- 검증은 디스크에 기록되는 증거 artifact (로그 파일, 테스트 출력, 스크린샷) 생산.
- Verifier는 세 tier를 가짐 — mechanical, semantic, runtime — 순서대로 실행, 저렴한 실패에서 short-circuit.
- Verifier는 "에러 없이 컴파일됨"만으로 성공 추론하지 않음. Runtime이 load-bearing.

### 4.6 Compounding Skill (Law 3, P10)  [Serves: L3]

- 매 사이클 끝에 돌아가는 `compounding-learnings` (동명사, P6 따름) skill.
- Skill은 최근 작업 (git diff, review findings, fix 히스토리)을 읽고, root cause를 추출하고, canonical learnings 디렉토리 (목적지는 open question, §9 참조)에 YAML frontmatter와 함께 기록.
- **Discoverability check:** skill은 새 learning이 미래 세션에서 도달 가능한지 확인 — `AGENTS.md`/`CLAUDE.md` 참조를 통해, 또는 관련 미래 skill이 scan하는 디렉토리에 있음으로써. 도달 불가면 skill이 인덱스를 자동 편집 (CE 패턴).
- Compounding 단계는 reviewer persona 파일을 직접 업데이트할 수도 있음 (P10) — "이 버그는 `security-sentinel.md`가 입력 길이 제한을 확인하지 않아서 탈출했음. 그 확인 추가."
- **Architectural 소유자 TBD** (§9): `compounding-learnings`은 standalone 플러그인 (`plugins/compound/`), 모든 플러그인이 import하는 shared skill, 또는 `quality-gates`의 terminal gate로 살 수 있음. 이 철학은 *원칙* (Law 3)과 *primitive shape* (이 섹션)을 주장하고, *소유 결정*은 이후 planning round로 유예. 해결될 때까지 플러그인은 local `compound` 단계를 inline으로 구현할 수 있지만, 이 섹션에 명시된 primitive shape로 구조화해서 미래 refactor가 clean하게 extract할 수 있어야 함.
- **3-point extraction gate (C3).** learning이 디스크에 기록되기 전에, compounding skill은 3-point gate를 적용 — 셋 다 필요: (a) **Non-Googleable** — fresh reader가 Google로 5분 안에 찾을 수 있는가? Yes면 capture 안 함. (b) **Project-specific** — 이 코드베이스 / 이 팀 / 이 플러그인에 specific한가? No면 capture 안 함. (c) **Hard-won** — 실제 debugging이나 설계 작업이 발견에 들었는가? No면 capture 안 함.
- **Wiki/index triad (C4).** OMC의 패턴: 모든 capture된 learning은 세 artifact를 생성 — learning 자체, index entry (`AGENTS.md` / `CLAUDE.md` / wiki에), learning이 가르치는 파일에서 역방향 pointer. 이 triad가 future-find가 확실히 작동하게 만듭니다.
- **Dual-lifetime memory tags (C25).** capture된 learning은 두 lifetime 중 하나로 태깅: `task` (단기, 현재 branch merge 후 삭제) 또는 `durable` (장기, 무기한 survive). compounding skill은 writer에게 lifetime을 명시적으로 고르게 prompt하고, default로 두지 않습니다.
- **Grep-first learnings search (C69).** future 세션은 canonical learnings 디렉토리 + C4의 index에서 `grep`으로 prior learning을 발견. embedding 없음, vector store 없음, RAG 없음. Acceptance: prior learning을 찾는 future 세션이 sampled benchmark에서 recall ≥ 85%로 grep 발견.

### 4.7 Hook Layer (P13, P14, P16)  [Serves: L1, L2, L3]

- **SessionStart hook**: 파일에서 플러그인 state 로드, pipeline status advise. 절대 mutate 안 함.
- **PreCompact hook**: critical in-context state를 파일로 snapshot. 여러 턴에 걸쳐 state를 carry하는 플러그인에 non-negotiable.
- **PostToolUse hook**: drift를 신경 쓰는 플러그인 (Ouroboros drift-monitor 패턴), Write/Edit 후 spec-vs-code 정렬 확인.
- **Stop hook**: loop-bearing 플러그인에 대해 state machine 구현. `quality-gates`가 이미 하는 것 — 패턴을 일반화.
- **PreToolUse hook**: *validation*에 예약, behavior injection 아님. 위험한 command 블록. Argument를 silently rewrite하지 않기.
- 모든 hook은 debug용 kill switch (env var 또는 settings.local.md flag)가 있음. OMC의 `DISABLE_OMC=1`과 `OMC_SKIP_HOOKS=name1,name2`가 템플릿.

### 4.8 State File (P5, P14)  [Serves: L3]

- State는 `.claude/<plugin>.local.md` (YAML frontmatter가 있는 마크다운)에 살음, JSON 아님. 마크다운인 이유: 사람이 편집 가능, diff 쉬움, committed되더라도 대화 기록으로 survive.
- **Gitignore 규칙 (리포 루트 `.gitignore`에서 enforce):** `.claude/*.local.md`는 devbrew 리포 전체에 걸쳐 **반드시** git-ignore되어야 함. State 파일은 경로, secret-인접 문자열, branch 이름, PR URL을 포함할 수 있음 — 공유 의도 없음. State 파일을 생성하는 플러그인의 setup 스크립트는 gitignore 라인이 존재하는지 확인하고 없으면 추가하는 책임이 있음.
- Frontmatter는 구조화된 field (step, iteration, last-verdict 등); body는 내러티브 (무슨 일이 있었는지, 다음은 뭔지).
- State 파일은 성공적 완료 시 auto-delete, 실패 시 디버깅을 위해 보존.
- State 파일은 하니스가 존재를 가정할 수 있는 *유일한* 지속적 inter-turn 채널 (P14).

### 4.9 Compose-Plugin Dispatch (P9)  [Serves: L1, L2, L3]

- 플러그인이 다른 플러그인이 제공하는 capability가 필요하면 `subagent_type: "other-plugin:agent-name"`으로 dispatch하거나 Skill tool로 다른 플러그인의 skill을 invoke.
- 의존성은 플러그인의 README Prerequisites 테이블에 최소 요구 플러그인 버전과 함께 선언.
- 의존성이 없으면 플러그인은 우아하게 degrade (P19) loud log와 함께 (AP15).

### 4.10 Benchmark Suite (P16)  [Serves: L2]

- quantitative claim을 하는 모든 플러그인은 `plugins/<name>/benchmarks/`에 fixtures, ground-truth, scoring, runner를 shipping.
- Benchmark 출력은 리포에 체크인 (또는 생산된 버전과 함께 README에 인용). OMC는 인프라는 있지만 citation 규율이 없음. devbrew는 둘 다 목표로 함.

---

## 5. Philosophical Stance on Genuine Tensions

여기는 소스 하니스들이 서로 의견을 달리하는 지점이고, devbrew가 한쪽을 골라야 하는 곳입니다.

### 5.1 "도구를 배우지 마라" vs. "도구는 네 인터페이스다"

OMC의 태그라인은 *"Don't learn Claude Code. Just use OMC."* 표면을 숨기고 workflow를 prescribe합니다. gstack은 반대 입장을 취합니다: ETHOS.md와 compression table은 *읽히도록* 의도됨. 사용자는 철학을 internalize할 것이 기대됨. Anthropic의 skill-authoring best practice는 암묵적으로 gstack 편 — skill은 *learnable*해야 하고, description은 *self-explanatory*해야 하고, agent는 자신의 reasoning을 surface해야 함.

**devbrew의 선택:** gstack 쪽. 철학은 문서화됨, 원칙은 인용 가능, 모든 플러그인의 README는 *왜*를 설명. 하니스가 무엇을 하는지 이해하는 세련된 사용자를 원함. 블랙 박스를 원하지 않음. "zero learning curve" framing은 무언가가 깨지는 순간 자기 모순이 되는 마케팅 trap.

### 5.2 "멈추지 마라" vs. "사용자 확인을 위해 pause"

OMC의 Sisyphus 패턴은 verdict이 pass가 될 때까지 stop을 거부. gstack과 CE는 모든 주요 단계에서 명시적으로 pause하고 사용자 입력을 기다림. Ouroboros는 중간 — spec-crystallization과 ambiguity 게이트에서 pause, 실행 내부에서는 autonomous.

**devbrew의 선택:** *결정 경계*에서는 pause, bounded 결정 *안에서는* autonomous 실행. 사용자가 plan을 승인하고 (`ExitPlanMode`), 그 후 executor가 verified-done까지 보고 pause 없이 돌아감. 사용자가 PR을 승인하고, 그 후 `/qg`가 세 게이트를 사이 pause 없이 돌림. 사용자가 spec을 승인하고, 그 후 implementer가 증거가 있을 때까지 돌림. "polite stop" (AP2) 없음, 하지만 사용자 게이트 시작점 없는 unbounded autonomy도 없음 (AP16).

### 5.3 수치적 엄격함 vs. 구조적 엄격함

Ouroboros는 수치 게이트 사용 (ambiguity, convergence). OMC와 gstack은 구조 게이트 (필수 섹션, adversarial pass, 체크리스트). Anthropic의 글은 agnostic.

**devbrew의 선택:** default로 구조적, signal이 강할 때 수치적. 수치 게이트는 유혹적이지만 brittle (ambiguity를 판단하는 LLM이 ambiguous 스펙을 생성하는 같은 LLM — reproducibility ≠ correctness, Ouroboros 자신의 약점). 구조 게이트 (필수 섹션, adversarial review pass, "ACs 없이 종료 불가")는 Goodhart하기 어려움.

### 5.4 Role-scoped persona (gstack) vs. shared-pool agent (OMC)

gstack의 역할은 `allowedTools` frontmatter와 artifact 관례로 구분됨. OMC의 19 agent는 대부분 도구를 공유; 구분은 prompt와 모델 tier (haiku/sonnet/opus variant).

**devbrew의 선택:** role separation에는 hard scoping (gstack 쪽), capability-cost matching에는 tier variant (OMC 쪽). Reviewer는 물리적으로 코드를 쓸 수 없음. 하지만 "작은 reviewer"와 "큰 reviewer" variant 둘 다 존재할 수 있고, 리뷰 대상에 따라 cheaper/more-capable 모델로 routing. gstack `allowed-tools` 메커니즘이 enforcement, OMC tier 메커니즘이 optimization. 직교함.

### 5.5 "Boil the Lake"

gstack의 ETHOS는 *"AI-assisted coding makes the marginal cost of completeness near-zero… do the complete thing every time."* OMC의 AGENTS.md는 *"Prefer deletion over addition when the same behavior can be preserved… the most common failure mode is doing too much, not too little."* 반대로 읽힘.

**devbrew의 선택:** *아키텍처* 최소주의 + *task-execution* 완전성. **구축**할 때 — 프레임워크 스킵, 추상화 스킵, 투기적 일반화 스킵, unused 코드 삭제 (OMC 승). **committed task를 끝낼** 때 — 에러 경로 스킵 금지, 테스트 스킵 금지, edge case 스킵 금지, docs 업데이트 스킵 금지, CHANGELOG entry 스킵 금지 (gstack 승). 두 규칙은 다른 질문에 적용: "얼마나 많은 코드가 존재해야 하는가?" (최소주의) vs "존재하는 코드 하에, 이 task가 얼마나 철저하게 커버해야 하는가?" (완전성). P8은 이것을 *"아키텍처 단순성, 완성 극대주의"*로 encode.

### 5.6 "Zero hooks"

CE는 compound-engineering 플러그인을 **훅 0개**로 shipping — bet은 선언적 description을 가진 skill이 harness-level behavior injection보다 엄격히 낫다는 것. agent가 언제 skill이 적용되는지 추론할 수 있기 때문. OMC는 11 lifecycle event에 걸친 **훅 20개**를 shipping — bet은 어떤 동작 (persistence, 상태 보존, prompt redirection)은 agent의 판단에 맡길 수 없고 harness-level enforcement가 필요하다는 것.

**devbrew의 선택:** agent에 대한 신뢰가 불충분하고 망각 비용이 높을 때 **그리고 오직 그때** 훅이 올바른 도구. 구체적으로: PreCompact (상태 보존 — AP17), Stop (pipeline state machine — quality-gates), validation용 PreToolUse (behavior injection 아님 — P13 참조), SessionStart read-only advisor. 나머지 모든 것 — 선언적 trigger를 가진 skill 선호. 이것은 CE의 insight (훅은 coarse, skill은 precise)를 플러그인 레벨이 아니라 카테고리 레벨에서 적용. 플러그인은 훅을 설치할 수 있지만 README의 "Hooks Installed" 섹션에서 각 훅을 "왜 이것이 skill이 될 수 없는가"의 한 줄로 justify해야 함.

---

## 6. Attribution Map (every idea → where it came from)

이 map은 attribution에 대한 compounding을 가능하게 합니다: 어떤 원칙이 틀렸다고 밝혀지면 어떤 소스를 재평가해야 하는지 알 수 있음.

| Principle / Primitive | Primary source | Supporting source(s) |
|---|---|---|
| Clarity Before Code (Law 1) | Ouroboros | OMC deep-interview, gstack office-hours, CE ce-brainstorm, Anthropic plan mode |
| Writer/Reviewer Isolation (Law 2) | OMC execution_protocols | gstack allowed-tools, CE parallel review, Ouroboros 3-stage gate, Anthropic subagent pattern, Anthropic *Claude Code Best Practices* (Writer/Reviewer pattern) |
| Compounding Cycle (Law 3) | CE / Klaassen essays | OMC learner+wiki, gstack learnings.jsonl, Anthropic filesystem-as-memory |
| Ambiguity Gate (P2) | Ouroboros | OMC deep-interview dimensional scoring + C43+C44+C45+C51 (roadmap, 2026-05-06 absorption) |
| Tool Scoping (P3; AP11 absorbed) | gstack | OMC Delegation Enforcer hook |
| Verification Infrastructure (P4) | devbrew quality-gates / Anthropic | gstack /qa, OMC ultraqa, Ouroboros Stage-1 mechanical + C35 (roadmap, 2026-05-06 absorption) |
| Filesystem as Memory (P5, AP10) | Anthropic *Effective Context Engineering* | OMC .omc/, CE docs/solutions + C66 (roadmap, 2026-05-06 absorption) |
| Progressive Disclosure (P6) | Anthropic Skill Authoring Best Practices | CE skills-over-commands migration + C57 (roadmap, 2026-05-06 absorption) |
| Looping Cycles (P7) | CE Plan→Work→Review→Compound | OMC autopilot, Ouroboros inner/outer |
| Simplicity / Delete-over-Add (P8, AP6) | Anthropic *Building Effective Agents* | OMC AGENTS.md, gstack ETHOS |
| Composition over Monolith (P9) | devbrew quality-gates existing | 모든 하니스에 암묵적 + C61 (roadmap, 2026-05-06 absorption) |
| Persona Pluralism (P10) | CE review personas | OMC code-reviewer tier variants + C19+C24+C31+C32+C42+C63 (roadmap, 2026-05-06 absorption) |
| Multi-Model Adversarial (P11) | gstack /codex | OMC ccg, Ouroboros consensus + C33+C52+C68 (roadmap, 2026-05-06 absorption) |
| Transparency of Planning (P12) | Anthropic *Building Effective Agents* | Claude Code plan mode + C34+C60 (roadmap, 2026-05-06 absorption) |
| Primitive Division of Labor (P13) | Anthropic plugin docs | CE skills-over-commands, OMC hook layering |
| State Survives Compaction (P14, AP17) | Anthropic *Effective Context Engineering* | OMC PreCompact hook |
| Initializer/Resumer (P15) | Anthropic *Effective Harnesses for Long-Running Agents* | OMC ralph, devbrew quality-gates stop-hook |
| Measurement (P16) | OMC benchmarks/ 인프라 | gstack confidence gating + C9+C54 (roadmap, 2026-05-06 absorption) |
| User Sovereignty (P17) | gstack ETHOS | Anthropic plan mode, Ouroboros Dialectic Rhythm Guard + C56 (roadmap, 2026-05-06 absorption) |
| Stagnation Detection (P18) | Ouroboros stagnated/unstuck | OMC ultraqa 3-repeat rule, OMC self-improve plateau + C46 (roadmap, 2026-05-06 absorption) |
| Graceful Degradation (P19) | OMC "never block on external tools" | — |
| Commit Trailer Protocol (P20) | OMC | — |
| Security & Supply Chain (P21) | devbrew own (AP12, P10, §5.6에서 synthesize) | Anthropic *Writing Effective Tools* (간접) |
| Cost Awareness (P22) | OMC tier variants + gstack confidence gating + `ccg` decomposition | Anthropic *Multi-Agent Research System* (4× token cost 경고) |
| Versioning & Deprecation (P23) | devbrew own; plugin.json cache-key 요구사항에서 상속 | SemVer |
| Writer/Reviewer Pattern (P24) | Anthropic *Claude Code Best Practices* | Anthropic *Building Effective Agents* (evaluator-optimizer workflow) |
| Tool Scoping Enforcement (AP11) | gstack `allowed-tools` | OMC Delegation Enforcer |
| Undeclared Plugin Dependency (AP12) | devbrew quality-gates existing | — |
| PRD Theater (AP1) | OMC | — |
| Polite Stop (AP2) | OMC | — |
| Self-Approval (AP3) | Law 2 corollary | OMC execution_protocols |
| LOC as Success Metric (AP4) | gstack public backlash | — |
| Trivia Pipeline Overhead (AP5) | Anthropic Claude Code Best Practices | — |
| Framework Abstraction in Prod (AP6) | Anthropic *Building Effective Agents* | OMC `run.cjs` 경계 케이스 |
| Vague Skill Names (AP7) | Anthropic skill-authoring best practices | — |
| Technical-Identifier Pollution (AP8) | Anthropic *Writing Effective Tools for AI Agents* | — |
| Over-Dispatching Subagents (AP9) | Anthropic *Multi-Agent Research System* | OMC subagent-tracker hook |
| Stale Pre-Built Indexes (AP10) | Anthropic *Effective Context Engineering* | — |
| Both-Models-Agree (AP13) | gstack ETHOS | — |
| Unchallenged Consensus (AP14) | Ouroboros convergence weakness + OMC ralplan steelman | — |
| Silent Fallback (AP15) | OMC weakness analysis (negative lesson) | — |
| Unbounded Autonomy (AP16) | OMC Sisyphus weakness (negative lesson) | gstack/CE/Ouroboros circuit breakers |
| Chat-Only State (AP17) | Anthropic PreCompact pattern + OMC notepad | — |

---

## 7. What This Philosophy Is NOT

미래 설계 결정이 이리로 drift하지 않도록 거부를 명시적으로 진술합니다.

- **OMC clone이 아님.** devbrew는 모놀리스, "don't learn it" framing, hook-coupled Node runtime, always-on autonomy, 문서화되지 않은 CC internal에 대한 tight coupling을 거부.
- **gstack clone이 아님.** devbrew는 role marketing ("CEO, Designer, Eng Manager…"), LOC metric, 다중 호스트 컴파일 타겟 (devbrew는 Claude Code를 우선 타겟, 다른 호스트는 향후 별도 작업으로만)을 거부.
- **Ouroboros clone이 아님.** devbrew는 수치-게이트-가-유일한-메커니즘, 무거운 MCP 런타임 의존성, trivia escape hatch 없음, "stop prompting" 절대주의를 거부. devbrew는 "specify first" 테제와 event-store-as-state 아이디어를 유지.
- **CE clone이 아님.** devbrew는 skills-over-commands 입장과 compounding 규율을 채택하지만, 훅 회피를 거부 (CE는 훅 0개를 shipping — devbrew는 훅이 enforcement에 올바른 도구라고 봄, P13 참조), 그리고 11개 다른 하니스를 타겟팅하지 않음 (단일 타겟 규율).
- **"프레임워크"가 아님.** Claude Code primitive를 감싸는 DSL 없음, code-generating config 없음, 클래스 계층 없음. 플러그인의 파일이 인터페이스입니다 (AP6).
- **Sisyphus 의미의 autonomous가 아님.** 사용자가 결정 경계에서 승인. bounded 결정 안쪽에서는 하니스가 hard run. 하지만 "never stop"은 거부.

---

## 8. Tagline & North-Star Candidates

네 후보가 고려됨. 첫 번째가 채택된 태그라인.

1. ***"Specify before you code. Review before you ship. Compound before you forget."*** ← **채택됨.** 세 법칙에 1:1로 매핑되는 세 박자 명령형. 기억하기 쉽고 인용 가능, 처방적.
   (*"코드보다 명세 먼저. 배포보다 리뷰 먼저. 잊기 전에 축적."*)
2. *"The bottleneck is not the model. It's the spec, the review, and the memory. devbrew's job is to fix all three without the user having to remember to."* ← CLAUDE.md에서 태그라인 아래 secondary thesis 문장으로 사용. 처방적이라기보다 진단적.
3. *"devbrew plugins discipline the input, isolate the reviewer, and compound the memory. Everything else is negotiable."*
4. *"A good devbrew plugin knows what it's allowed to do, what it's forbidden from doing, and where its learnings go. If any of those three are missing, it isn't ready to ship."*

---

## 9. Roadmap: Open Questions for Future Rounds

이 철학이 의도적으로 침묵하는 곳. 각각은 이후 planning round의 실제 설계 선택이지 글자로 메우는 gap이 아님.

1. **devbrew ambiguity 게이트의 granularity.** 모든 플러그인이 같은 메커니즘 (구조적 baseline + optional adversarial)을 채택하나, 그것을 넘는 플러그인별 variation이 허용되나?
2. **Compound 단계 소유자.** `compounding-learnings`는 자체 플러그인 (`devbrew/compound`), `quality-gates` 내 skill, 또는 모든 플러그인이 import하는 shared skill인가? CE 모델(플러그인별 skill) vs devbrew shared-skill 모델은 실제 trade-off가 있음.
3. **Persona 라이브러리 호스팅.** devbrew가 CE persona-pluralism 패턴을 채택한다면 persona 파일은 어디에 사나? `code-review` 플러그인? 전용 `review-personas` 플러그인? 각 도메인별 플러그인 (예: `frontend-design`은 자신의 frontend reviewer shipping)?
4. **스펙 디렉토리 관례.** Ouroboros는 `~/.ouroboros/seeds/` (전역), OMC는 `.omc/plans/` (프로젝트-local), CE는 `docs/plans/` (프로젝트-local, git-tracked). devbrew의 canonical spec directory는? Git-tracked vs gitignored?
5. **Compounding 목적지.** `docs/solutions/` (CE), `docs/learnings/` (제안), `MEMORY.md` index (auto-memory 스타일), 또는 플러그인-local `<plugin>/learnings/`? Discoverability Check는 일관된 편집 목적지가 필요.
6. **다중 모델 게이트 범위.** 어떤 결정이 "되돌리기 어려운지" multi-model adversarial 레이어를 트리거하는가? 스펙 mutation (Ouroboros 답), 프로덕션 배포, main 머지, 아키텍처 commitment — 또는 당분간 첫 번째만?
7. **Stop 조건 default.** Loop-bearing 플러그인의 default 한도는 — 최대 반복, wall-clock, repeat 감지 window는? `quality-gates`는 현재 `MAX_TOTAL_ITERATIONS=5`, `MAX_GATE2_ITERATIONS=5`를 사용. 이것이 하우스 default인가?
8. **Plan-mode 통합 깊이.** 모든 devbrew 플러그인이 plan 단계에 `ExitPlanMode`를 invoke하나, 플러그인이 opt-in하나?
9. **Benchmark 문화.** 모든 플러그인이 v1.0부터 벤치마크를 shipping하나, quantitative claim을 하는 것만 하나?
10. **롤아웃 경로.** 기존 `quality-gates` 플러그인이 이 철학에 retrofit되나, 그대로 두고 새 플러그인에만 표준을 적용하나? Retrofit은 작동하는 플러그인을 흔들 위험, 두 표준 유지는 철학이 "새 것에만" 있게 되고 drift할 위험.

---

## 10. How This Doc Evolves

이 철학은 리포와 함께 버저닝됩니다. 새 원칙, 안티패턴, primitive는 ecosystem이 필요 증거를 생산할 때 추가될 수 있음. 기존 원칙은 날짜 있는 노트와 함께 *수정*될 수 있지만 silent 제거는 안 됨 — 제거는 README의 "Principles Instantiated" 섹션에서 해당 원칙을 cite하는 모든 플러그인에 대한 breaking change.

이후 planning round의 cadence:

- **Round N+1 — Primitives 명세.** §4를 구체적 파일 템플릿으로 formalize. 스펙 형식, 플랜 형식, state-file 스키마, review-finding JSON shape, commit trailer 문법 정의. §9 Q4 (스펙 디렉토리)와 Q5 (compounding 목적지) 해결.
- **Round N+2 — 플러그인 형태 exemplar.** 철학을 worked example에 적용 — 제안된 플러그인 중 하나 (spec-authoring, persona-review, 또는 compound)를 골라서 실제 타겟에 대해 철학을 테스트할 수 있도록 완전히 설계. 그 exemplar의 맥락에서 §9 Q2와 Q3 해결.
- **Round N+3 — quality-gates와 project-init의 retrofit 플랜.** 기존 플러그인이 다음 minor 버전 bump에서 철학의 어느 부분을 채택할지 결정. §9 Q10 해결.
- **Round N+4 — Compounding 단계 설계.** 단일 가장 레버리지 큰 primitive. 자신의 planning round를 받을 만함. Round N+2가 이미 하지 않았다면 §9 Q2를 아키텍처적으로 finalize.

---

## 11. Migration Table — 2026-05-06 Restructure

이 표는 2026-05-06 재구조화로 §2를 Three Laws 산하로 재편하고 로드맵 후보를 흡수한 변경의 마이그레이션 매핑을 기록합니다. Redirect는 영구 보존 (이동/흡수된 ID당 한 행).

### 11.1 Anti-Pattern Disposition (B.1)

| AP ID | Disposition | New Location |
|---|---|---|
| AP1  | Nested      | §2.1 / P2 anti-corollary |
| AP2  | Nested      | §2.4 / P17 anti-corollary |
| AP3  | Nested      | §2.2 / P4 anti-corollary |
| AP4  | Nested      | §2.4 / P8 anti-corollary |
| AP5  | Nested      | §2.1 / P12 anti-corollary (trivia-escape canonical mention) |
| AP6  | Nested      | §2.4 / P8 anti-corollary |
| AP7  | Nested      | §2.4 / P6 anti-corollary |
| AP8  | Nested      | §2.4 / P6 anti-corollary |
| AP9  | Nested      | §2.4 / P22 anti-corollary (cost frame을 P9 architectural frame보다 선택: P22가 fan-out=N gates를 이미 encode) |
| AP10 | Absorbed    | §2.3 / P5 body |
| AP11 | Absorbed    | §2.2 / P3 body |
| AP12 | Nested      | §2.4 / P9 anti-corollary |
| AP13 | Nested      | §2.2 / P11 anti-corollary |
| AP14 | Nested      | §2.2 / P11 anti-corollary |
| AP15 | Nested      | §2.4 / P19 anti-corollary |
| AP16 | Nested      | §2.4 / P18 anti-corollary |
| AP17 | Absorbed    | §2.3 / P14 body |

### 11.2 Principle Changes (B.2)

Modification types: **R** = relocated only, **E** = C# content로 expanded, **A** = body가 AP를 absorb, **N** = anti-corollary로 AP를 nest, **NEW** = R5에서 신규 추가.

| ID | Modification | New Location | Source / Notes |
|---|---|---|---|
| P1  | R                  | §2.1 Law 1          | (C49 → already covered: P14+P23) |
| P2  | E + N(AP1)         | §2.1 Law 1          | C43+C44+C45+C51 socratic discipline |
| P3  | A(AP11)            | §2.2 Law 2          | AP11 완전 흡수 |
| P4  | E + N(AP3)         | §2.2 Law 2          | C35 two-tier test classification |
| P5  | E + A(AP10)        | §2.3 Law 3          | C66 linked artifact flow + AP10 흡수 |
| P6  | E + N(AP7, AP8)    | §2.4 Cross-cutting  | C57 review mode detection |
| P7  | R                  | §2.4 Cross-cutting  | — |
| P8  | N(AP4, AP6)        | §2.4 Cross-cutting  | — |
| P9  | E + N(AP12)        | §2.4 Cross-cutting  | C61 5-dim overlap detection |
| P10 | E                  | §2.2 Law 2          | C19+C24+C31+C32+C42+C63 |
| P11 | E + N(AP13, AP14)  | §2.2 Law 2          | C33+C52a+C52b+C68 |
| P12 | E + N(AP5)         | §2.1 Law 1          | C34+C60 + trivia-escape canonical mention |
| P13 | R                  | §2.4 Cross-cutting  | — |
| P14 | A(AP17)            | §2.3 Law 3          | AP17 완전 흡수 |
| P15 | R                  | §2.3 Law 3          | — |
| P16 | E                  | §2.3 Law 3          | C9+C54 |
| P17 | E + N(AP2)         | §2.4 Cross-cutting  | C56 autofix tiers |
| P18 | E + N(AP16)        | §2.4 Cross-cutting  | C46 lateral personas (Cross-cutting, Law 3 아님 — stagnation은 progress 검증이지 compounding 아님) |
| P19 | N(AP15)            | §2.4 Cross-cutting  | — |
| P20 | R                  | §2.3 Law 3          | — |
| P21 | R                  | §2.4 Cross-cutting  | — |
| P22 | N(AP9)             | §2.4 Cross-cutting  | — |
| P23 | R                  | §2.4 Cross-cutting  | — |
| P24 | NEW (R5)           | §2.2 Law 2          | Anthropic *Claude Code Best Practices* — Writer/Reviewer pattern; fresh-context critique loop |

**P24 added 2026-05-06 R5** — Anthropic *Claude Code Best Practices*의 Writer/Reviewer pattern을 직접 출처로 신규 추가. 참고: 이전 R4 restructure에서는 roadmap 클러스터 C3+C4+C25+C69에 대해 새 P# 만들지 않고 §4.6 + Law 3 corollary로 흡수했음 (lightness meta-principle). P24는 그 클러스터와 무관하게 별개의 일급 출처에서 도착한 패턴이라 슬롯을 채움.

### 11.3 §4 Primitive Expansions

- **§4.4 Reviewer Agents**가 C20 (verdict envelope: `APPROVE / REQUEST CHANGES / COMMENT × CRITICAL / HIGH / MEDIUM / LOW`) + C30 (per-finding payload contract: `severity / confidence 1-10 / path / line / category / summary / fix / fingerprint / specialist`; sentinel `NO FINDINGS`; confidence rubric 9-10 show, 7-8 show, 5-6 caveat, 3-4 suppress, 1-2 P0-only)을 흡수.
- **§4.6 Compounding Skill**이 C3 (3-point extraction gate: non-Googleable / project-specific / hard-won — 셋 모두 필수) + C4 (wiki/index triad 패턴, OMC 출처) + C25 (dual-lifetime memory tags: 단명 `task` vs 영속 `durable`) + C69 (grep-first learnings search; embedding 없음, vector store 없음; recall ≥ 85% acceptance criterion)을 흡수. Law 3 corollary는 discoverability 메커니즘 위치를 §4.6으로 가리키도록 강화.

### 11.4 Roadmap C# Disposition (53 Go candidates)

| Bucket | Count | Items |
|---|---|---|
| 기존 P 확장으로 fold (§11.2 참조) | 23 | C9, C19, C24, C31, C32, C33, C34, C35, C42, C43, C44, C45, C46, C51, C52 (a+b), C54, C56, C57, C60, C61, C63, C66, C68 |
| §4 primitive 확장으로 fold (§11.3 참조) | 6 | C3, C4, C25, C69 → §4.6 ; C20, C30 → §4.4 |
| 기존 P / primitive에 이미 covered (doc 변경 없음) | 17 | C1→P2, C2→P3, C5→P14, C6→P4, C7→P18, C10→§4.2, C11→P13+P21, C12→P13, C14→P3+§4.3, C15→P20, C28→P9, C41→P21, C49→P14+P23, C50→P19, C55→§4.1+P1, C59→P7, C65→P14+§4.8 |
| 운영 디테일 / convention (doc 변경 없음, 원칙 레벨 아님) | 7 | C22, C27, C36, C53, C58, C64, C67 |
| **Sum** | **53** | ✓ roadmap "53 Go"와 일치 |

**Parked / Killed (본 PR scope 외 — 참조용):** C8, C16, C17, C18, C21, C23, C26, C29, C37, C38, C39, C40, C47, C62 (Park); C13, C48 (Kill).

---

## Appendix A — Direct Quotes Preserved

Load-bearing 인용, verbatim 유지해서 이후 라운드가 re-fetch 없이 cite할 수 있도록:

**Ouroboros (Korean README):**

> *"AI는 무엇이든 만들 수 있다. 어려운 건 무엇을 만들어야 하는지 아는 것이다."*
>
> *"Ouroboros는 기계가 아닌 인간을 바로잡습니다."*
>
> *"Do not build until you are clear (Ambiguity ≤ 0.2), do not stop evolving until you are stable (Similarity ≥ 0.95)."*
>
> *"When you answer 'What IS a task?' — deletable or archivable? solo or team? — you eliminate an entire class of rework. The ontological question is the most practical question."*

**OMC:**

> *"Don't learn Claude Code. Just use OMC."* [devbrew 태그라인으로 거부; framing이 trap이라는 diagnostic으로 유지]
>
> *"Keep authoring and review as separate passes… Never self-approve in the same active context."*
>
> *"A false approval costs 10-100x more than a false rejection."* — agents/critic.md
>
> *"Prefer deletion over addition when the same behavior can be preserved."* — AGENTS.md
>
> *"Could someone Google this in 5 minutes? → NO / Is this specific to THIS codebase? → YES / Did this take real debugging effort to discover? → YES."* — learner quality gate, 셋 다 true여야 함

**gstack ETHOS:**

> *"AI-assisted coding makes the marginal cost of completeness near-zero. When the complete implementation costs minutes more than the shortcut — do the complete thing. Every time."*
>
> *"AI models recommend. Users decide. This is the one rule that overrides all others."*
>
> *"Anti-pattern: 'Both models agree, so this must be correct.' (Agreement is signal, not proof.)"*
>
> *"Cognitive gearing: forcing a large language model into distinct roles to simulate a high-functioning software team's workflow."* — Epsilla writeup

**Compound-Engineering (Klaassen essays):**

> *"Compounding engineering is about building systems with memory, where every pull request teaches the system, every bug becomes a permanent lesson, and every code review updates the defaults. AI engineering makes you faster today. Compounding engineering makes you faster tomorrow, and each day after."*
>
> *"The fastest way to teach is not through code you write, but through plans you review."*
>
> *"We forgot to retry once. The system won't let us forget again."*

**Anthropic Engineering:**

> *"Maintain simplicity in your agent's design."* — *Building Effective Agents*
>
> *"Find the smallest possible set of high-signal tokens that maximize the likelihood of some desired outcome."* — *Effective Context Engineering*
>
> *"Rather than pre-processing all relevant data up front, agents built with the 'just in time' approach maintain lightweight identifiers […] and use these references to dynamically load data into context at runtime."* — *Effective Context Engineering*
>
> *"Give Claude a way to verify its work. […] Invest in making your verification rock-solid."* — *Claude Code Best Practices*
>
> *"If you could describe the diff in one sentence, skip the plan."* — *Claude Code Best Practices*
>
> *"Prioritize transparency by explicitly showing the agent's planning steps."* — *Building Effective Agents*
>
> *"Initializer agent: The very first agent session uses a specialized prompt that asks the model to set up the initial environment […] Coding agent: Every subsequent session asks the model to make incremental progress, then leave structured updates."* — *Effective Harnesses for Long-Running Agents*
>
> *"[…] multiple sessions enable quality-focused workflows. A fresh context improves code review since Claude won't be biased toward code it just wrote. For example, use a Writer/Reviewer pattern."* — *Claude Code Best Practices*
>
> *"In the evaluator-optimizer workflow, one LLM call generates a response while another provides evaluation and feedback in a loop."* — *Building Effective Agents*
