---
name: devbrew-context-slimming
type: interview-brief
created_at: 2026-07-08
session_id: d64b0c53-0e3c-46a0-b84d-3051519831e5
source: spec-distill conducting-interview v0.19.0
next_phase: superpowers:brainstorming
# locked_directions — (b)/(d) 명시 응답 + steelman 통과 방향. brainstorming 기정사실.
locked_directions:
  - id: LD1
    statement: "감량 타깃 우선순위: B(가드레일·철학 레이어) + C(런타임 컨텍스트 주입량) 우선, A(역사 docs)는 공격적 청소 곁다리."
    source_path: b
    steelman: n/a
  - id: LD2
    statement: "원칙: '진짜 필요한 것(load-bearing)만 남긴다' — over-built 스캐폴딩 제거, 보안/정확성 게이트는 보존."
    source_path: b
    steelman: n/a
  - id: LD3
    statement: "감량 후 project-init 플러그인을 새로 실행해 스캐폴딩(git-workflow/charter/AGENTS·CLAUDE 포인터)을 재생성한다."
    source_path: b
    steelman: n/a
  - id: LD4
    statement: "재정의: '프로젝트를 특별하게 만드는 것만 남긴다' — 현대 모델+하네스 기본 수행/generic best-practice 커버분은 제거, devbrew 차별적 핵심(Three Laws의 구조적 instantiation)만 보존."
    source_path: b
    steelman: n/a
  - id: LD5
    statement: "제거 기준①: 코드를 읽으면 당연히 알 수 있는 것(grep/Read로 발견 가능한 사실의 재진술)은 문서/지시문에서 제거 — 모델이 코드를 읽을 것을 신뢰."
    source_path: b
    steelman: n/a
  - id: LD6
    statement: "제거 기준②: 컨텍스트/구현 방향을 과하게 제약하는(over-prescriptive) 내용 제거 — 구현 방해. 단 구조적 보안/정확성 집행은 '제약' 아님, 별개."
    source_path: b
    steelman: n/a
  - id: LD7
    statement: "제거 기준③: 외부 레퍼런스 링크 제거 — ../reference corpus 포인터·철학 doc 외부 인용 apparatus 등. 문서를 self-contained·경량화."
    source_path: b
    steelman: n/a
  - id: LD8
    statement: "경계 정의: '특별함=구조적 load-bearing'. strip은 prose/docs/refs/history/런타임컨텍스트 한정, 구조적 보안·정확성 게이트(Law 1·2 집행, 결정론 fail-closed)는 보존."
    source_path: b
    steelman: defended
    defense: "steelman이 제시한 category error(context-rot은 모델 컨텍스트 토큰을 측정할 뿐, 하니스-레벨 집행은 애초에 모델 컨텍스트에 진입 안 함 → '프롬프트 감량'과 '집행 제거'는 독립 변수)를 수락. 구조 게이트 strip은 Law 1·2가 막으려는 self-approval/fail-open을 하니스에 재도입하므로 방어."
  - id: LD9
    statement: "multi-agent fan-out: 보안-critical model-diversity(codex 등, fail-open 반복 적발 이력)는 load-bearing 보존, 순수 중복/편의 fan-out만 strip 후보 — 케이스별 판단."
    source_path: b
    steelman: n/a
---

# devbrew Context Slimming — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

*(d) ontological — ESSENCE 로 도출.*

받은 요청("모델·하네스가 발전했으니 과한 내용·컨텍스트를 덜어낸다")의 진짜 문제는
**"현대 모델+하네스가 이미 기본으로 수행하거나 코드·generic best-practice가 이미 커버하는 스캐폴딩·재진술 prose·역사 축적이, devbrew의 차별적 핵심(Three Laws의 구조적 집행)을 파묻고 런타임 컨텍스트를 rot시키며 구현을 과-제약(over-prescription)한다"**는 것이다.

**진짜 goal**: devbrew를 그 *구조적 핵심으로 환원(reduce-to-essence)* 한다 — "특별함 = 구조적 load-bearing"만 남기고 나머지(역사 docs, 재진술 prose, 코드로 자명한 것, 과-제약 지시문, 외부 레퍼런스 apparatus, 잉여 런타임 컨텍스트)는 걷어내되, **보안/정확성 집행 계층은 category error를 피해 보존**한다. 감량 후 project-init 재실행으로 스캐폴딩을 lean baseline에서 재생성한다.

## 2. Locked Directions

(확정·검증된 방향. frontmatter locked_directions와 1:1. 재논쟁 금지.)

- **LD1**: 감량 타깃 = B(가드레일·철학) + C(런타임 컨텍스트) 우선, A(역사 docs)는 공격적 청소 곁다리.
- **LD2**: "진짜 필요한(load-bearing) 것만 남긴다" — over-built 제거, 보안/정확성 게이트 보존.
- **LD3**: 감량 후 project-init 새로 실행 → 스캐폴딩(git-workflow/charter/AGENTS·CLAUDE 포인터) 재생성.
- **LD4**: "프로젝트를 특별하게 만드는 것만 남긴다" = Three Laws의 구조적 instantiation만 보존.
- **LD5**: 코드를 읽으면 자명한 재진술은 제거(모델이 코드를 읽을 것을 신뢰).
- **LD6**: over-prescriptive 제약 prose 제거(구현 방해). 구조적 집행은 별개(제약 아님).
- **LD7**: 외부 레퍼런스 링크(../reference 포인터·철학 doc 외부 인용) 제거 → self-contained 경량화.
- **LD8**: 경계 정의 "특별함=구조적 load-bearing" — strip은 prose/docs/refs/history/컨텍스트 한정, 구조 게이트 보존. *(steelman defended)*
- **LD9**: multi-agent는 보안-critical(codex model-diversity 등) 보존, 순수 중복만 strip 후보.

## 3. External Landscape

(prior-art / 경쟁 / 기존 해결책. 각 항목 출처 URL 필수.)

- Harness Engineering 2026 — "프로덕션 하네스는 더하기만 할 수 없다, obsolete complexity를 삭제하는 능력이 스킬" — https://www.epsilla.com/blogs/harness-engineering-evolution-prompt-context-autonomous-agents — [취함] — strip 방향(감량=역량)의 직접 근거.
- Anthropic Context Engineering (2025-09) — 컨텍스트는 "optimal set of tokens" 큐레이션이지 최대화가 아님 — https://howaiworks.ai/blog/anthropic-context-engineering-for-agents — [취함] — C(런타임 컨텍스트 절감)의 원리.
- Chroma Context Rot — 18개 frontier 모델(Claude 4 포함) 전부 토큰↑→열화, coding agent가 누적 컨텍스트로 최악 — https://www.trychroma.com/research/context-rot — [취함] — 잉여 런타임 컨텍스트가 실측 손해임을 뒷받침.
- Self-Correction Bench — LLM은 자기 출력 오류는 못 잡고 외부 입력이면 잡음(self-correction blind spot) — https://arxiv.org/pdf/2507.02778 — [취함] — Law 2 writer==reviewer 금지(=보존 대상)의 실증.
- OWASP Prompt Injection Prevention — guardrail은 defense-in-depth 한 계층, prompt injection은 architectural(모델 개선으로 안 없어짐) — https://cheatsheetseries.owasp.org/cheatsheets/LLM_Prompt_Injection_Prevention_Cheat_Sheet.html — [취함] — 결정론 보안 게이트 보존의 근거.

## 4. Skepticism Log

(의심 triggered 방향 + steelman 대안(verbatim) + 웹근거 URL + verdict.)

- 대안(verbatim): "구조적·load-bearing 게이트(writer/reviewer 물리 분리 Law 2, security-reviewer, 결정론적 fail-closed 셸 게이트)는 모델 성능이 아무리 향상되어도 절대 strip 대상이 아니다. context-rot은 모델 컨텍스트 윈도우의 토큰을 측정할 뿐 하니스-레벨 강제(check-review-scope.sh, allowedTools frontmatter)는 애초에 모델 컨텍스트에 들어가지 않는다 — '프롬프트 감량'과 '집행 계층 제거'는 독립 변수이며 동일시는 category error다." — https://arxiv.org/pdf/2603.12123 — verdict: defended

## 5. Tried & Discarded

(시행착오: 시도 → 버린 이유.)

- 시도: "모델·하네스가 발전했으니 구조적 게이트(Law 2 물리 분리·security-reviewer·결정론 fail-closed·spec 5-ritual)까지 자율 신뢰로 공격적 strip, '특별함'을 미적 표면으로 확장" → 버린 이유: category error(context-rot=모델 토큰 측정 ≠ 하니스 집행 계층) + self-correction blind spot(자기 출력 자가검증 실패) + OWASP defense-in-depth(prompt injection은 architectural). 구조 게이트 strip은 Law 1·2가 정확히 막으려는 self-approval/fail-open을 하니스 설계에 재도입함. → LD8로 경계 재확정.

## 6. Open Questions

(미해결 명시. "유추 금지" — 해답공간으로 이월.)

- OQ1: 철학 doc(devbrew-harness-philosophy.md 938줄 + roadmap 367줄)을 **재작성 vs 트림** — 24 원칙/14 anti-pattern 중 어느 것이 "generic best-practice 재진술"(strip)이고 어느 것이 devbrew-고유 구조 집행(keep)인지 케이스별 분류가 필요. brainstorming에서 keep/strip 라인 확정.
- OQ2: 역사 docs(plans 63,956줄 + specs 14,988줄 = ~79k줄, 마크다운의 85%) 처리 방식 — **완전 삭제 vs orphan 아카이브 브랜치/태그 이동 vs 별도 저장소**. git history 보존과 repo 경량화의 트레이드오프.
- OQ3: multi-agent fan-out 케이스별 판정 — codex/security-reviewer/adversarial/runtime-verifier는 보존 유력(보안-critical), breadth-keeper/steelman-builder/pr-understanding-builder/test-scope-validator는 "load-bearing인가 편의 스캐폴딩인가" 개별 심사 필요.
- OQ4: project-init 재실행 범위 — CLAUDE.md/AGENTS.md/charter를 어디까지 regenerate하고 기존 축적분을 어디까지 discard하는가. 재생성물이 lean baseline인지 확인.
- OQ5: 런타임 컨텍스트 절감(C)의 구체 타깃 — SKILL.md verbose 지시문·agent 프롬프트 장황함·CLAUDE.md 참조 등 실제 per-session 토큰 프로파일이 필요(추정 금지). "무엇이 매 세션 로드되는가"를 측정 후 절감.
- OQ6: 감량 자체를 devbrew의 자기 규율(spec→review→compound)로 진행하는가 — 이 작업은 persona/게이트를 건드릴 수 있어 Law 2 보안 리뷰 대상. 감량 PR도 plugin.json bump + /qg 파이프라인을 거치는지.

## 7. Concrete Next Action

superpowers 가용 → 이 brief를 context로 `superpowers:brainstorming` 호출 → `docs/superpowers/specs/…-design.md` 산출 → `spec-distill:spec-reviewer` 검증(Law 2) → `superpowers:writing-plans` → 사용자 지정 **울트라코드(ultracode) 다중 에이전트 구현**. 감량 대상이 보안 persona·게이트를 포함하므로(OQ6) 구현 PR은 plugin.json SemVer bump + /qg 파이프라인 통과가 전제.
