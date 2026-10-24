# devbrew 하니스 철학

> *병목은 모델이 아니다 — 스펙, 리뷰, 메모리다. 하니스는 사용자가 의식하지 않아도 이 셋을 자동으로 훈육한다.*

이 문서는 `plugins/*`가 상속하는 철학 레이어의 essence다. 원칙 카탈로그가 아니라 **Three Laws를 코드로 집행하는 구조 메커니즘의 지도** — 각 원칙은 자신을 실제로 집행하는 파일을 가리킨다. 재진술이 아니라 포인터다. 리포 루트 [`CLAUDE.md`](../../CLAUDE.md)가 세 법칙 + 플러그인 형태를 사전 로드하고, 이 파일은 그 아래 구조 메커니즘을 코드 cross-ref로 묶는다.

## The Three Laws

세 법칙이 모든 플러그인을 지배한다. 계층적이다 — 충돌 시 **Law N이 Law N+1을 override** (명확성 먼저, 독립성 둘째, compounding 셋째).

**Law 1 — Clarity Before Code.** 명세가 모호한 상태에서는 구현이 진행되지 않는다. 명세 작성은 자신의 스킬·게이트·거절 동작을 가진 일급(first-class) 단계다. 코드를 shipping하는 모든 플러그인은 "아직 이건 코딩 못 한다"고 말할 수 있는 **실제 거절 메커니즘** — 최소한 필수 섹션(Context/Why·Goals·Non-goals·Constraints·Acceptance Criteria·Files to Modify·Verification Plan·Rejected Alternatives·Metadata)을 silent하게 skip할 수 없게 하는 것 — 을 가져야 한다. 지금 막는 자리: 인터뷰 brief 는 `check_brief.py` 가 구조로 막는다. 설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다. 모델 신뢰만으로는 부족하다.

**Law 2 — Writer and Reviewer Must Never Share a Pass.** 코드를 쓴 턴은 그 코드를 승인할 수 없다. 이것은 heuristic이 아니라 하드 규칙이고, 분리는 프롬프트가 아니라 도구 표면으로 한다(P3).

**Law 3 — Every Cycle Must Leave the System Smarter.** N+1번째 작업이 N번째보다 엄밀히 더 쉬워야 한다. 메커니즘은 low-tech다 — 리포에 있는 파일을 미래 세션이 읽는 것. 미래 세션에는 메모리 없는 레포 · 다른 레포도 들므로 교훈은 그 동작을 내는 skill · reference · 스크립트 · 락을 고쳐 남긴다. 아무 미래 agent도 읽지 않는 파일에 쓰는 것은 theater다.

## Structural Mechanisms

KEEP-12 — Three Laws를 코드로 집행하는 load-bearing 원칙. 각 엔트리는 prose 재진술이 아니라 집행 파일을 가리킨다. Three Laws의 집행 자체는 모델 성능과 무관하게 불변이다. 다만 개별 임계치·예산·상한은 재평가 대상이다 — 모델이 강해지면 결정론이 사던 것의 값이 달라지기 때문이다(P8).

### P2 — The Ambiguity Gate
**Law 1 집행.** 명세는 명확도 임계를 통과했거나 아직 못 했거나 둘 중 하나이고, 게이트는 visible·declared·refusable해야 한다. Load-bearing: 게이트가 silent pass-through를 허용하는 순간 Law 1이 prose로 전락한다 — 수치 스코어링은 scorer=generator라 brittle하므로 구조적 baseline이 default이고 adversarial self-review가 enhancement다.
코드: `plugins/spec-distill/scripts/check_brief.py` (5-ritual gate) · `plugins/spec-distill/skills/pm-interview/SKILL.md`

### P3 — Writer/Reviewer Isolation via Tool Scoping
**Law 2 집행.** 역할 경계를 프롬프트가 아니라 frontmatter로 만든다 — 리뷰어 agent에는 `Write`/`Edit`이 없고 플래너에는 mutation-Bash가 없다. Load-bearing: "프롬프트를 믿자"에서 "도구가 존재조차 하지 않는다"로 바꾼다 — default-everything(전체 tool 접근) agent는 P3 위반이다.
코드: `shared/docreview/agents/doc-critic.md` · `plugins/quality-gates/agents/security-reviewer.md`
문서 리뷰 자리 셋(design doc · brief · seed)을 통일하는 엔진은 `shared/docreview/` — qg 의 `generic` 프로필은 엔진 테스트만 읽는다.

### P4 — Verification Is Infrastructure
**Law 2 집행.** 모든 작업은 *증거*를 생산하는 검증 pass로 끝난다: mechanical(compile/lint/test) → semantic(AC 준수, 독립 리뷰어) → runtime(실제로 돌림), 저렴한 실패에서 short-circuit. Load-bearing: "컴파일됨"은 증거가 아니다 — runtime tier가 앞 두 tier가 놓치는 버그 class를 잡는다. qg 는 runtime tier 를 사람이 승인하면 e2e 걷기로 확인한다 — 걷지 않은 실행은 판정 줄의 e2e 칸이 그 사실을 보인다(오케스트레이터의 판정은 판정안이고 reviewer 는 감독하는 사람이다 — Law 2 해석).
코드(mechanical · semantic · runtime): `plugins/quality-gates/scripts/run-test-selection.sh` · `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `plugins/quality-gates/references/e2e.md`

### P10 — Taste Pluralism
**Law 2 × Law 3 집행.** 단일 리뷰어가 아니라 persona *라이브러리* — 각각 작고 버저닝 가능하며 *구체적 의견*을 이름으로 쓴 마크다운. Load-bearing: 버그가 리뷰를 탈출하면 기본 해결책은 그 버그를 잡았어야 할 persona 파일 편집이다 — 코드만 패치하지 않는다. 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다. 그 커밋이 compounding 이벤트(Law 3)다.
코드: `plugins/quality-gates/agents/` (persona 파일군)

### P11 — Cross-Model Adversarial at High-Stakes Moments
**Law 2 집행.** 되돌리기 어려운 결정(프로덕션 배포·스펙 mutation·보안-crit·스키마 마이그레이션)엔 단일 모델 의견이 부족 — cross-vendor second opinion을 게이트로. Load-bearing: 단일 모델 리뷰는 같은 전제를 공유해 같은 자리를 놓친다 — codex(read-only)는 감지되면 늘 함께 돌고, 끄는 길은 각 플러그인의 kill switch 다.
코드: `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `plugins/quality-gates/agents/code-recritic.md` · `plugins/quality-gates/references/recritic-code-profile.md`

### P12 — Transparency of Planning
**Law 1 집행.** Agent는 실행 전에 계획을 보이고 사용자가 redirect할 수 있어야 하며, 계획은 chat 요약이 아니라 파일에 기록된다. 기본은 설계 → 계획 → 구현이다. 중간 크기 일은 이유를 밝히고 가벼운 꼴(PR 본문의 계획 · 짧은 brief)을 고를 수 있다. 가벼운 꼴도 필수 섹션이 다루는 것을 짧게 덮고, 다루지 않는 섹션은 「해당 없음 — 이유」로 적는다. Load-bearing: 한 문장으로 묘사 가능한 trivia diff(typo·rename·comment-only formatting — 파일 수와 무관하게)만 게이트를 우회하고, behavior·public-API 변경은 자격이 없다 — triviality 판정과 「중간 크기」 판정은 invoking skill의 책임이다.
코드: `plugins/spec-distill/references/trivia-escape.md` · CLAUDE.md Law 1

### P13 — Hooks for Enforcement, Skills for Capability, Agents for Personas
**Cross-cutting (L1·L2·L3) 집행.** hook=사건에 붙는 관찰 · 알림, skill=capability 표면, agent=scoped persona의 명확한 역할 분담 + 훅 공존 규칙(commutativity·mutation-free `SessionStart`·per-plugin kill switch). 진입 skill 의 사전 검사(`!`)가 kill switch 를 모델 판단 밖에서 집행한다. Load-bearing: 같은 event에 여러 플러그인 훅이 공존하려면 순서 무관성이 구조적으로 필요하다.
코드: `plugins/project-init/hooks/hooks.json` · `shared/entry/entry_preflight.py`

### P17 — User Sovereignty
**Law 1 집행.** 위험한·되돌리기 어려운·공유 state에 영향을 주는 액션은 항상 confirmation 게이트를 거친다 — agent는 권고하고 사용자가 결정한다. Load-bearing: 게이트를 skip한 narrate-only 종료는 polite-stop(AP2)이다 — approval gate는 사용자가 *redirect* 가능해야 하고 단순 *acknowledge*가 아니다. qg 의 매 실행 PR 코멘트 게시는 사용자의 상시 동의다 — 게시마다 묻지 않고, 게시만 끄는 길은 `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 하나다(전역 `DEVBREW_QUALITY_GATES_DISABLE=1` 은 전부를 끈다).
코드: `plugins/spec-distill/skills/spec-review/SKILL.md` 의 `## 게이트` 절 (`AskUserQuestion` proceed gate) · `plugins/quality-gates/scripts/publish-comment.sh` (상시 동의 게시 — kill switch 가 sink 안에서 끈다)

### P18 — Stagnation Is a Failure Mode
**Cross-cutting (L1·L2·L3) 집행.** 같은 것을 계속 재시도하는 루프는 진전이 아니라 멈춘 것 — max-iteration cap + repeat 감지 + escape hatch와 함께 shipping. Load-bearing: 정체 시 재시도 대신 *다른* 접근(fresh subagent·다른 리뷰어·human prompt)을 invoke해야 하고, 카운트가 없는 루프는 토큰을 태우며 신뢰를 깎는다.
코드: `shared/docreview/references/reviewing-document.md` (재리뷰 상한 — 값의 정본 한 줄) · `shared/docreview/scripts/docreview_state.py` 의 `gate_summary`(stagnation 술어) · qg fix-loop 의 반복 상한(`plugins/quality-gates/skills/quality-pipeline/SKILL.md`)

### P21 — Security & Supply Chain
**Cross-cutting (L1·L2·L3) 집행.** 플러그인=코드, agent=prompt, 둘 다 공격 표면이다 — state secret hygiene, integrity-pin된 plugin-to-plugin trust, description prompt-injection 리뷰가 floor. Load-bearing: kill switch는 보안 컨트롤이라 어떤 훅도 inspect해서 거부할 수 없고, persona 파일을 약화(규칙 제거·임계 완화)하는 PR은 test-suite 편집과 같은 scrutiny의 보안-민감 변경이다.
코드: `plugins/quality-gates/scripts/publish-comment.sh` (게시 sink — kill switch · secret-scan · 비신뢰 입력) · hooks kill switch · persona=보안-민감

### P22 — Cost Awareness
**Cross-cutting (L1·L2·L3) 집행.** 모든 스킬은 worst-case 기반으로 `cost_class: low|medium|high|variable`를 frontmatter에 선언하고, fan-out N을 `<Use_When>`에 명시한다. Load-bearing: `cost_class: high`는 지출 전 `AskUserQuestion` 승인 게이트가 필수이고(비용에 대한 동의), 클래스보다 비싸게 도는 스킬은 버그다.
코드: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` frontmatter `cost_class`

### P23 — Decisions Stay Refutable
**Law 1 × P17 집행.** 확정된 결정은 재논의 대상이 아니지만 **반증 대상이다.** 앞 단계가 못 박은 것이 뒤 단계에서 틀린 것으로 드러나면, 그 단계는 근거를 제시하고 사용자 동의를 받아 피벗할 수 있어야 한다 — 임의 변경은 금지, 보고 후 재결정은 허용. Load-bearing: **오류를 가장 잘 볼 수 있는 자리는 그 오류를 만든 자리가 아니라 하류다** — 확정을 영구 봉인하면 볼 수 있는 자리와 고칠 수 있는 자리가 분리되고, 이른 단계의 오차가 하류 전 구간에 증폭된 채 아무도 말할 길이 없어진다. 재발견 금지는 반증 금지가 아니다. 설계마다 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 표면과 이음매 담당을 적어 하류의 오류가 돌아갈 길을 둔다.
코드: `plugins/spec-distill/references/proceed-gate.md` 「재결정 규약」 절 · `plugins/spec-distill/skills/spec-review/SKILL.md` · `plugins/spec-distill/references/epic-handoff.md` (설계의 「상류 · 하류 연계」 절)

### AP3 — Self-Approval (the #1 anti-pattern)
**Law 2 집행.** 같은 턴이 쓰고 승인하는 것 — Law 2로 엄격히 금지되고 P3 tool-deny로 구조적으로 집행된다. Load-bearing: fresh context가 self-bias anchor를 끊는다 — 같은 context의 reviewer는 자신이 방금 쓴 코드를 *defend*하는 default로 들어가므로, 승인은 다른 agent/다른 skill/최소한 fresh context reviewer로 route해야 한다.
코드: `shared/docreview/agents/doc-critic.md` (`tools:` allowlist에 Write/Edit이 없어 self-approval 구조 차단)

## Load-bearing Meta-Rules

CLAUDE.md에 부재하거나 미묘해서 이 essence에서만 완전히 생존하는 규칙.

### P8 — Determinism Economy (Maintain Simplicity)
아키텍처는 최소주의, 작업 실행은 극대주의다. 단순성은 코드 양뿐 아니라 *결정론적 메커니즘의 양*에도 적용된다 — 훅·스크립트·강제 규칙 같은 결정론 장치는 모델 신뢰가 불충분하고 오류 비용이 높을 때, 즉 load-bearing일 때만 정당하다. 두 방향으로 대칭이다:

- (제거 방향) 편의·라우팅·NL-의도처럼 구조적 escape hatch가 이미 있는 영역엔 결정론 가드를 쌓지 말고 모델을 신뢰한다.
- (부과 방향) 결정론은 보안/정확성 게이트(fail-closed)라는 load-bearing 지점에만 정확히 부과한다.

- (흐름) 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓴다 — 정석 흐름(brainstorming → 계획 → 구현)의 의도는 지키되 순서를 강제하는 결정론은 두지 않는다.
- (재사용) 새로 만든 것은 유지할 표면이 되므로 레포 안 · 밖에 있는 것을 먼저 검토하고, 외부 것은 사용자가 검토한 뒤에 쓴다(P17).
- (이식성) 레포 전용 값을 박는 것은 이 레포에서만 맞는 결정론이라 다른 레포에서 조용히 틀린다 — 도출하거나 레포마다 정하게 한다.

예: qg 의 판정 floor 는 「검토하지 않은 범위를 clean 이라 부르지 않는다」는 정확성 한 점에만 결정론을 걸고(kill 불가), 무엇을 리뷰할지 고르는 일은 모델 신뢰로 둔다.

### P14 — State Survives Compaction
컨텍스트 윈도우는 compact될 것이다 — 하니스는 그럴 것이라 가정하고 설계한다. 규칙: **턴 종료 전 load-bearing 사실은 파일로 기록한다 — 대화에만 있는 사실은 compaction 후 사망한다.** Plan 파일·state 파일·스펙 파일·커밋 메시지·`CLAUDE.md`·review findings 마크다운 등 지속적인 것에 기록한다. 이 규칙은 CLAUDE.md에 부재하므로 이 essence가 정본이다.

### P5 — Filesystem as Memory
상태는 context가 아니라 파일에 산다 — 최소 인덱스만 preload하고 나머지는 Glob/Read/Grep으로 just-in-time 로드한다. stale-index·vector store·RAG 없음. 상태가 얽히면 객체 · 링크 · 속성 · 주인을 명시해 진입점 하나에서 따라가게 하되(주인이 하나라야 끝이 정본), 작은 일에는 이 구조를 만들지 않는다. state 자리는 CLAUDE.md §런타임 상태 & 훅. 에픽의 머지됨은 지휘자가 PR 을 열 때 기계 상태에 적은 PR 번호로 판정한다 — 그 PR 이 기본 브랜치로 머지됐을 때만 머지됨이다. 번호가 없는 에픽만 브랜치 이름과 이력으로 알아보고, 그 추정의 틈(같은 이름의 옛 브랜치 · 늦게 들어온 문서)은 공시한다.
코드: `plugins/spec-distill/references/roadmap-ontology.md` · `plugins/spec-distill/scripts/roadmap_status.py`

## Anti-Pattern Anchors

인용되는 anti-pattern의 stub 앵커 — 정본은 CLAUDE.md Forbidden Patterns이고, 여기서는 cross-ref resolve만 보장한다.

### AP2 → CLAUDE.md Forbidden Patterns
Polite Stop — verified-done 후 사용자가 요청하지 않은 내러티브 요약을 삽입하는 것. 사용자가 redirect 가능한 approval gate(P17)와 구분된다.

### AP5 → CLAUDE.md Forbidden Patterns
Trivia ceremony — 한 문장 diff에 full pipeline을 실행하는 것 (P12 trivia escape의 anti-corollary).

### AP9 → CLAUDE.md Forbidden Patterns
Subagent spray — 선언 없는 fan-out. 규모 자체가 아니라 선언 없음이 anti-pattern이다 (P22).

### AP16 → CLAUDE.md Forbidden Patterns
Unbounded autonomy — max-iter 카운트·repeat 감지·사용자-override kill switch 없는 루프 (P18의 anti-corollary).
