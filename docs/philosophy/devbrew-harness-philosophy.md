# devbrew 하니스 철학

> *병목은 모델이 아니다 — 스펙, 리뷰, 메모리다. 하니스는 사용자가 의식하지 않아도 이 셋을 자동으로 훈육한다.*

이 문서는 `plugins/*`가 상속하는 철학 레이어의 essence다. 원칙 카탈로그가 아니라 **Three Laws를 코드로 집행하는 구조 메커니즘의 지도** — 각 원칙은 자신을 실제로 집행하는 파일을 가리킨다. 재진술이 아니라 포인터다. 리포 루트 [`CLAUDE.md`](../../CLAUDE.md)가 세 법칙 + 플러그인 형태를 사전 로드하고, 이 파일은 그 아래 구조 메커니즘을 코드 cross-ref로 묶는다.

## The Three Laws

세 법칙이 모든 플러그인을 지배한다. 계층적이다 — 충돌 시 **Law N이 Law N+1을 override** (명확성 먼저, 독립성 둘째, compounding 셋째).

**Law 1 — Clarity Before Code.** 명세가 모호한 상태에서는 구현이 진행되지 않는다. 명세 작성은 자신의 스킬·게이트·거절 동작을 가진 일급(first-class) 단계다. 코드를 shipping하는 모든 플러그인은 "아직 이건 코딩 못 한다"고 말할 수 있는 **실제 거절 메커니즘** — 최소한 필수 섹션(Context/Why·Goals·Non-goals·Constraints·Acceptance Criteria·Files to Modify·Verification Plan·Rejected Alternatives·Metadata)을 silent하게 skip할 수 없는 구조적 게이트 — 을 가져야 한다. 모델 신뢰만으로는 부족하다.

**Law 2 — Writer and Reviewer Must Never Share a Pass.** 코드를 쓴 턴은 그 코드를 승인할 수 없다. 이것은 heuristic이 아니라 하드 규칙이다. 분리는 프롬프트가 아니라 물리적이어야 한다 — `allowed-tools`/`disallowed-tools` frontmatter로 리뷰어가 `Write`/`Edit`을 literally 하지 못하게 만든다. 쓰기 권한이 있는 리뷰어는 리뷰어가 아니고, 검증은 나중 생각이 아니라 load-bearing 인프라다.
*R6 scoped exception (qg v2.2.0):* 실제 서비스를 실행해야 하는 executor(`runtime-verifier`)는 `Write`를 갖되, 분리는 도구 deny가 아니라 **orchestrator가 immutable baseline 대비 `git diff`로 product 변경을 잡아 verdict를 ≤FAIL로 강제 + 무커밋 + 샌드박스 폐기**하는 구조 가드로 보장된다 — verifier 주장과 독립적인 구조이므로 self-approval이 구조적으로 불가능하다.

**Law 3 — Every Cycle Must Leave the System Smarter.** N+1번째 작업이 N번째보다 엄밀히 더 쉬워야 한다. 메커니즘은 low-tech다 — 리포에 있는 파일을 미래 세션이 읽는 것. Compounding은 선택적 wrap-up이 아니라 discoverability check가 붙은 이름 붙은 단계다: 사이클이 learning을 생산하면 하니스는 파일로 capture하고, 미래 agent가 그것에 실제로 도달 가능한지 확인한다 — 위험하면 인덱스(`CLAUDE.md`/`AGENTS.md`)를 자동 편집한다. 아무 미래 agent도 읽지 않는 파일에 쓰는 것은 theater다.

## Structural Mechanisms

KEEP-12 — Three Laws를 코드로 집행하는 load-bearing 원칙. 각 엔트리는 prose 재진술이 아니라 집행 파일을 가리킨다. Three Laws의 집행 자체는 모델 성능과 무관하게 불변이다. 다만 개별 임계치·예산·상한은 재평가 대상이다 — 모델이 강해지면 결정론이 사던 것의 값이 달라지기 때문이다(P8).

### P2 — The Ambiguity Gate
**Law 1 집행.** 명세는 명확도 임계를 통과했거나 아직 못 했거나 둘 중 하나이고, 게이트는 visible·declared·refusable해야 한다. Load-bearing: 게이트가 silent pass-through를 허용하는 순간 Law 1이 prose로 전락한다 — 수치 스코어링은 scorer=generator라 brittle하므로 구조적 baseline이 default이고 adversarial self-review가 enhancement다.
코드: `plugins/spec-distill/scripts/check_brief.py` (5-ritual gate) · `plugins/spec-distill/skills/conducting-interview/SKILL.md`

### P3 — Writer/Reviewer Isolation via Tool Scoping
**Law 2 집행.** 역할 경계를 프롬프트가 아니라 frontmatter로 만든다 — 리뷰어 agent에는 `Write`/`Edit`이 없고 플래너에는 mutation-Bash가 없다. Load-bearing: "프롬프트를 믿자"에서 "도구가 존재조차 하지 않는다"로 바꾼다 — default-everything(전체 tool 접근) agent는 P3 위반이다.
코드: `plugins/spec-distill/agents/spec-reviewer.md` · `plugins/quality-gates/agents/security-reviewer.md`

### P4 — Verification Is Infrastructure
**Law 2 집행.** 모든 작업은 *증거*를 생산하는 검증 pass로 끝난다: mechanical(compile/lint/test) → semantic(AC 준수, 독립 리뷰어) → runtime(실제로 돌림), 저렴한 실패에서 short-circuit. Load-bearing: "컴파일됨"은 증거가 아니다 — runtime tier가 앞 두 tier가 놓치는 버그 class를 잡는다.
코드: `plugins/quality-gates/agents/runtime-verifier.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`

### P10 — Taste Pluralism
**Law 2 × Law 3 집행.** 단일 리뷰어가 아니라 persona *라이브러리* — 각각 작고 버저닝 가능하며 *구체적 의견*을 이름으로 쓴 마크다운. Load-bearing: 버그가 리뷰를 탈출하면 fix는 코드 패치가 아니라 그 버그를 잡았어야 할 persona 파일 편집이고, 그 커밋이 compounding 이벤트(Law 3)다.
코드: `plugins/quality-gates/agents/` (persona 파일군)

### P11 — Cross-Model Adversarial at High-Stakes Moments
**Law 2 집행.** 되돌리기 어려운 결정(프로덕션 배포·스펙 mutation·보안-crit·스키마 마이그레이션)엔 단일 모델 의견이 부족 — cross-vendor second opinion을 게이트로. Load-bearing: Claude-only 리뷰가 반복적으로 놓친 보안 fail-open을 codex(read-only=leak-proof) 모델 다양성이 적발했다 — 단일 모델은 default, 다중 모델은 opt-in 게이트.
코드: `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `plugins/quality-gates/agents/adversarial.md`

### P12 — Transparency of Planning
**Law 1 집행.** Agent는 실행 전에 계획을 보이고 사용자가 redirect할 수 있어야 하며, 계획은 chat 요약이 아니라 파일에 기록된다. Load-bearing: 한 문장으로 묘사 가능한 trivia diff(typo·rename·comment-only formatting — 파일 수와 무관하게)만 게이트를 우회하고, behavior·public-API 변경은 자격이 없다 — triviality 판정은 invoking skill의 책임이다.
코드: `plugins/spec-distill/commands/interview.md` (trivia escape) · CLAUDE.md Trivia escape

### P13 — Hooks for Enforcement, Skills for Capability, Agents for Personas
**Cross-cutting (L1·L2·L3) 집행.** hook=집행 레이어, skill=capability 표면, agent=scoped persona의 명확한 역할 분담 + 훅 공존 규칙(namespace·commutativity·mutation-free `SessionStart`·per-plugin kill switch). Load-bearing: 같은 event에 여러 플러그인 훅이 공존하려면 signal tag namespace(`<{plugin}-signal>`)와 순서 무관성이 구조적으로 필요하다.
코드: `plugins/*/hooks/hooks.json`

### P17 — User Sovereignty
**Law 1 집행.** 위험한·되돌리기 어려운·공유 state에 영향을 주는 액션은 항상 confirmation 게이트를 거친다 — agent는 권고하고 사용자가 결정한다. Load-bearing: 게이트를 skip한 narrate-only 종료는 polite-stop(AP2)이다 — approval gate는 사용자가 *redirect* 가능해야 하고 단순 *acknowledge*가 아니다.
코드: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` Phase 5 (`AskUserQuestion` proceed gate)

### P18 — Stagnation Is a Failure Mode
**Cross-cutting (L1·L2·L3) 집행.** 같은 것을 계속 재시도하는 루프는 진전이 아니라 멈춘 것 — max-iteration cap + repeat 감지 + escape hatch와 함께 shipping. Load-bearing: 정체 시 재시도 대신 *다른* 접근(fresh subagent·다른 리뷰어·human prompt)을 invoke해야 하고, 카운트가 없는 루프는 토큰을 태우며 신뢰를 깎는다.
코드: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (re-review cap 5) · qg Review fix-loop

### P21 — Security & Supply Chain
**Cross-cutting (L1·L2·L3) 집행.** 플러그인=코드, agent=prompt, 둘 다 공격 표면이다 — state secret hygiene, integrity-pin된 plugin-to-plugin trust, description prompt-injection 리뷰가 floor. Load-bearing: kill switch는 보안 컨트롤이라 어떤 훅도 inspect해서 거부할 수 없고, persona 파일을 약화(규칙 제거·임계 완화)하는 PR은 test-suite 편집과 같은 scrutiny의 보안-민감 변경이다.
코드: `plugins/quality-gates/scripts/comment-upsert.py` (untrusted-input) · hooks kill switch · persona=보안-민감

### P22 — Cost Awareness
**Cross-cutting (L1·L2·L3) 집행.** 모든 스킬은 worst-case 기반으로 `cost_class: low|medium|high|variable`를 frontmatter에 선언하고, fan-out N을 `<Use_When>`에 명시한다. Load-bearing: `cost_class: high`는 지출 전 `AskUserQuestion` 승인 게이트가 필수이고(비용에 대한 동의), 클래스보다 비싸게 도는 스킬은 버그다.
코드: `plugins/quality-gates/skills/quality-pipeline/SKILL.md` frontmatter `cost_class`

### P23 — Decisions Stay Refutable
**Law 1 × P17 집행.** 확정된 결정은 재논의 대상이 아니지만 **반증 대상이다.** 앞 단계가 못 박은 것이 뒤 단계에서 틀린 것으로 드러나면, 그 단계는 근거를 제시하고 사용자 동의를 받아 피벗할 수 있어야 한다 — 임의 변경은 금지, 보고 후 재결정은 허용. Load-bearing: **오류를 가장 잘 볼 수 있는 자리는 그 오류를 만든 자리가 아니라 하류다** — 확정을 영구 봉인하면 볼 수 있는 자리와 고칠 수 있는 자리가 분리되고, 이른 단계의 오차가 하류 전 구간에 증폭된 채 아무도 말할 길이 없어진다. 재발견 금지는 반증 금지가 아니다. *anti-corollary:* 앞 단계의 확정이 하류에서 반증돼도 피벗 경로가 없는 것.

### AP3 — Self-Approval (the #1 anti-pattern)
**Law 2 집행.** 같은 턴이 쓰고 승인하는 것 — Law 2로 엄격히 금지되고 P3 tool-deny로 구조적으로 집행된다. Load-bearing: fresh context가 self-bias anchor를 끊는다 — 같은 context의 reviewer는 자신이 방금 쓴 코드를 *defend*하는 default로 들어가므로, 승인은 다른 agent/다른 skill/최소한 fresh context reviewer로 route해야 한다.
코드: `plugins/spec-distill/agents/spec-reviewer.md` (Write/Edit deny로 self-approval 구조 차단)

## Load-bearing Meta-Rules

CLAUDE.md에 부재하거나 미묘해서 이 essence에서만 완전히 생존하는 두 규칙.

### P8 — Determinism Economy (Maintain Simplicity)
아키텍처는 최소주의, 작업 실행은 극대주의다. 단순성은 코드 양뿐 아니라 *결정론적 메커니즘의 양*에도 적용된다 — 훅·스크립트·강제 규칙 같은 결정론 장치는 모델 신뢰가 불충분하고 오류 비용이 높을 때, 즉 load-bearing일 때만 정당하다. 두 방향으로 대칭이다:

- (제거 방향) 편의·라우팅·NL-의도처럼 구조적 escape hatch가 이미 있는 영역엔 결정론 가드를 쌓지 말고 모델을 신뢰한다.
- (부과 방향) 결정론은 보안/정확성 게이트(fail-closed)라는 load-bearing 지점에만 정확히 부과한다.

예: qg v2.6.0의 self-honest verdict floor는 "검토 안 한 scope를 clean이라 부르지 않기"라는 정확성 보장 한 점에만 결정론을 걸고(kill 불가) 그 위의 redirect 제안·scope routing은 모델 신뢰(kill 가능)로 둔다.

### P14 — State Survives Compaction
컨텍스트 윈도우는 compact될 것이다 — 하니스는 그럴 것이라 가정하고 설계한다. 규칙: **턴 종료 전 load-bearing 사실은 파일로 기록한다 — 대화에만 있는 사실은 compaction 후 사망한다.** Plan 파일·state 파일·스펙 파일·커밋 메시지·`CLAUDE.md`·review findings 마크다운 등 지속적인 것에 기록한다. 이 규칙은 CLAUDE.md에 부재하므로 이 essence가 정본이고, 플러그인 README 3곳 인용의 anchor target이다.

## Anti-Pattern Anchors

인용되는 anti-pattern/규칙의 stub 앵커 — 정본은 CLAUDE.md Forbidden Patterns / Filesystem-as-Memory이고, 여기서는 cross-ref resolve만 보장한다.

### AP2 → CLAUDE.md Forbidden Patterns
Polite Stop — verified-done 후 사용자가 요청하지 않은 내러티브 요약을 삽입하는 것. 사용자가 redirect 가능한 approval gate(P17)와 구분된다.

### AP5 → CLAUDE.md Forbidden Patterns
Trivia ceremony — 한 문장 diff에 full pipeline을 실행하는 것 (P12 trivia escape의 anti-corollary).

### AP9 → CLAUDE.md Forbidden Patterns
Subagent spray — 선언 없는 fan-out. 규모 자체가 아니라 선언 없음이 anti-pattern이다 (P22).

### AP16 → CLAUDE.md Forbidden Patterns
Unbounded autonomy — max-iter 카운트·repeat 감지·사용자-override kill switch 없는 루프 (P18의 anti-corollary).

### AP18 → CLAUDE.md Forbidden Patterns
Self-narrating artifact — 모델이 읽고 행동하는 산출물(생성 템플릿·룰 파일·프롬프트)이 자기 출처·배경·존재 정당화를 담는 것. 토큰 낭비(P22)이자 의미 왜곡 — 읽는 쪽의 초점이 "무엇을 해야 하나"에서 "이게 왜 있나"로 옮겨가고 정당화가 지시로 오독된다 (P8 최소주의의 산출물 방향).

### P5 → CLAUDE.md / Filesystem-as-Memory
상태는 context가 아니라 파일에 산다 — 최소 인덱스만 preload하고 나머지는 Glob/Read/Grep으로 just-in-time 로드한다. stale-index·vector store·RAG 없음. 규칙 정본은 CLAUDE.md.
