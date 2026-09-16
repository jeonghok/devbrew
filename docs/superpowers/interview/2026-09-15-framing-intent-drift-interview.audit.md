---
type: interview-audit
payload: 2026-09-15-framing-intent-drift-interview.md
created_at: 2026-09-15
session_id: 06580f24-7f82-4c2d-a23b-11bba4c9e24c
source: spec-distill conducting-interview v3.1.0
---

# Framing 의도 이탈 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 동의: Phase 0 seed 를 에이전트가 혼자 쓰고 고쳐(번역 · 추론 혼입 · 사용자 없는 리뷰 반영) 사용자는 의도에서 멀어진 완성본을 끝에서 받는다, goal 은 S2 원문 (@S5)
- floor:landscape — closed — 외부 근거 처분: 압축·새 세션 인계 유지 · 사용자 없는 반복 수정은 표류 · 문서 형성 도중 사용자 참여를 취함, 번호 답 anchoring 은 거부 (@S4)
- floor:skepticism — closed — ST1 steelman 판정 보완(refined) (@S8)
- floor:blind_spot — closed — premortem 처분: 핵심 반례(확인 표시 세탁)는 9/5 사례에서 반증, 나머지 H1~H6 · F1~F6 은 payload §5 위험으로 기록 (@S6)
- floor:open_questions — closed — OQ1~OQ6 목록 확인 (@S10)
- derived:phase0_phase1_boundary — closed — Phase 1 은 이미 라운드당 질문 하나라 Phase 0 도 대화형이면 새 세션 사이에 같은 모양 대화 둘; Phase 0 은 맡길 일을 사용자 말로 확정, 조사·반론·원인 후보는 Phase 1 (@S7)
- derived:convergence_signal — closed — 짧은 왕복일 때 압축 전환을 누가 판단하나 → S8 이 짧은 왕복을 기각해 seed 완료·의도 일치 신호로 좁힘; 불일치는 다음 단계로 넘어간 뒤 드러남 (@S9)
- derived:seed_co_authoring — closed — 사용자가 seed 형성에 끼는 지점; 풀이 문장 확인 · 리뷰 지적 처분 · 사용자 편집 단계, 매 문장 공동 작성 기각 — orchestrator 가 ST1 게이트 답으로 닫음 (@S8)

## 2. Budget

- 질문 라운드: 9 · agent dispatch: 4 · coverage-mapper 1 · codex 실호출: 0 (성공 0)

## 3. Steelman 원문

#### ST1 — 사용자 공동 작성 방향 → 보완(리뷰어 유지 · 처분은 사용자 · 사용자 편집 복원)

**dispatch 입력** — goal: S2 · 전제: P1 의도 이탈의 주원인은 사용자 확인을 거치지 않고 seed 에 들어가는 문장(에이전트 번역·추론·리뷰 반영 수정)이다(S3,S5,S6) · P2 압축해서 새 세션으로 넘기는 구조 자체는 옳다(S4) · P3 번호 답 형식 자체는 문제가 아니고 그것을 에이전트 문장으로 풀어 굳히는 번역이 문제다(S3,S4) · P4 사용자 없는 에이전트 리뷰→수정 루프는 의도를 지키기보다 표류시킨다(S3,S4) · P5 문장 형성 도중 사용자 확인이 이탈을 줄인다 — 9/5 확인 두 건은 의도대로였다(S1,S4,S6) · P6 억제 리뷰어가 잡는 결함(추론을 사용자 결정처럼 씀)은 사용자가 직접 보면 잡을 수 있다(orchestrator 도출) · 제약: S1–S6 원문 전량 · trigger: 원 설계 근거와 충돌(2026-08-23 §1.3·§2.2 묶음=빈약함 체감, 억제 리뷰=뺄셈 검사) · 알려진 anti-pattern(확인 피로·rubber-stamp·무거운 하니스) · Law 2 작성/검토 분리 약화 가능성 · blind-spot premortem 경고(리뷰어 제거 시 표류 탐지기 소실 · 긴 세션 가정 고착 · Phase 0/1 같은 모양 · 빈약함 체감 소실 · 게이트 착시). 전제는 S6 뒤 P1·P5 를 갱신한 판본.

```yaml
case_for_alternative:
  statement: "원문 운반 + 사용자 처분 리뷰. 묶음 질문, 격리 리뷰어(seed-critic·codex), 냉독은 그대로 둔다. seed 본문에는 사용자 원문과, 그 답이 가리킨 질문·선택지 문구만 그대로 싣는다. 에이전트가 쓴 문장은 «다시 검증할 것» 문단에만 둔다. 리뷰어 지적은 저자가 반영하지 않는다. 설계 §2.4 에 있었으나 구현에서 빠진 «사용자 편집» 단계를 되살려, 그 자리에서 사용자가 지적을 한 번에 처분한다."
  strongest: "goal 은 seed 와 사용자 의도가 맞는 것이다. S3·S5 가 짚은 원인 셋(번역, 추론, 사용자 없는 반영)은 모두 에이전트가 쓴 문장이다. 대안은 그 문장을 본문에서 빼서 원인을 뿌리에서 끊는다. 짧은 왕복 공동 작성도 결국 에이전트가 문장을 쓰고 사용자가 승인하는 모양이다. 모델과 함께 쓰면 쓴 내용뿐 아니라 쓰는 사람의 견해도 모델 쪽으로 움직였고(Jakesch 2023), 제시된 조언은 의도와 무관하게 닻으로 작동하며 설명을 붙여도 틀린 조언 수용이 줄지 않았다(PMC11056364). 공동 작성은 사용자를 바로 그 자리에 세운다. 9/5 기록에서 «추론을 사용자 결정처럼 쓴 문장» 16건을 찾은 것은 모두 리뷰어였다. 사용자는 리뷰어 지적 7건이 공시된 v3 를 승인했고, 이탈은 그 뒤에야 체감했다. 그래서 대안은 실제로 결함을 찾아낸 기록이 있는 유일한 장치인 리뷰어를 남기고, 처분 권한만 사용자에게 옮긴다. 사용자 조각을 그대로 이어 붙인 단일 지시가 원 지시 성능의 95.1% 를 회복했다(Laban 2025 Concat). 번역 없이도 인계가 성립한다는 뜻이다."
case_for_current:
  strongest: "의도를 판정할 수 있는 사람은 사용자뿐이다. 이탈은 완성본이 끝에서 한 덩어리로 도착하는 자리에서 났다(S5). 그 자리에 리뷰어 산출을 얹어도 소용이 없었다. 9/5 에 사용자는 지적 7건이 공시된 상태에서 ① 을 골랐다. 기록에서 사용자 판단이 실제로 작동한 곳은 좁고 구체적인 질문 앞이었다. 라운드 2 에서 사용자는 «권장방식이 뭔지 알려줘 … 트레이드오프를» 이라며 에이전트의 프레이밍을 되돌렸다. codex r1 과 critic r2 #10 이 정반대로 판정한 워크트리 문장은 라운드 4 의 사용자 확인으로만 풀렸고, 그 확인이 실제 의도였다(S6). 저자 단독 반영은 라운드마다 새 결함을 낳았다(v2 에 13건, v3 에 7건). 사용자 피드백 없이 모델이 스스로 고치면 오히려 나빠질 수 있다는 결과(Huang 2023)와 같은 구조다. 짧은 답(«2»·«후자»·«a»)은 누군가 풀어야 쓸 수 있고, 그 풀이를 검증할 수 있는 것은 사용자뿐이다. 그래서 문장을 만드는 도중에 확인해야 한다. superpowers brainstorming(한 메시지에 질문 하나, 절마다 «맞는지» 확인)과 Spec Kit /clarify(답을 곧바로 spec 에 반영)도 같은 결론이다."
premise_refutation:
  hits: [P6]
  why: "P6 는 «억제 리뷰어가 잡는 결함은 사용자가 직접 보면 잡을 수 있다» 이다. 이것이 리뷰어를 걷어내도 된다는 근거인데, 세 근거와 충돌한다. (a) repo: 2026-09-05-interview-depth-redesign-interview.audit.md 「### 4.11 seed-critic r3 (초안 v3) — 7건, 미반영(게이트 텍스트에 공시)」. 7건 중 3건이 축4(추론을 결정처럼 쓴 문장)다. 사용자는 이 목록을 게이트에서 직접 보고도 ① 을 골랐다(라운드 5 주석 «critic r3 1번은 미해결로 남음»). 이탈은 그 뒤 S2 에서 체감됐다. 같은 audit 의 지적 36건 중 추론·결정 뒤바뀜 계열 16건도 모두 리뷰어가 냈다. 사용자가 스스로 짚은 사례는 기록에 없다. (b) PMC11056364: 조언은 사전 판단과 무관하게, 의도치 않게 닻으로 작동한다. 설명을 붙여도 틀린 조언에 대한 의존이 유의하게 줄지 않았다. 에이전트 문장을 보는 것만으로 그 오류를 잡는다는 가정과 정면으로 충돌한다. (c) arXiv 2509.08514: 표시된 AI 오류를 고치도록 요구하자 참여가 줄고 틀린 제안 수용이 늘었다. 이는 원안의 기제, 즉 사용자에게 에이전트 문장을 확인·수정하게 하는 방식 그 자체다."
premise_list_challenge: "(1) P5 는 근거와 시점이 어긋난다. S6 의 두 확인은 9/5 audit 「### 라운드 4 — proceed 게이트 1차 답변」에 있는 복수 선택 해석 확인이다. 문장 형성 도중이 아니라 파이프라인 끝에서, 에이전트가 제시한 해석을 고른 것이다. 이 근거가 뒷받침하는 것은 «좁은 해석 하나를 명시적으로 묻는 것이 맞았다» 까지다. «형성 도중» 이라는 시점은 뒷받침하지 않는다. (2) P4 는 탐지와 반영을 한 문장에 묶는다. 기록상 표류를 만든 쪽은 저자 단독 반영이다(v1→v2 반영 뒤 v2 에 새 지적 13건, v3 에 7건). 리뷰어는 뺄셈만 하고 tools: [] 라서 문장을 쓰지 않는다. S3 원문도 «리뷰→수정이 나 없이» 다. P4 로는 탐지를 버릴 근거가 서지 않는다. (3) 빠진 전제: 설계 §2.4 의 3단계 «사용자 편집 — 사용자가 본문을 직접 고친다» 가 SKILL 에 구현되지 않았다(plugins/spec-distill 전체 grep 0건). 지금의 «사용자 없이» 는 설계 선택이 아니라 구현 누락일 수 있다. 그렇다면 그 단계를 되살리는 것이 최소 변경이다. (4) 빠진 전제: Phase 0 저자 자신도 긴 같은-세션 대화 안에 있다. Laban 은 이른 해답 시도를 저하 원인으로 짚는다. 짧은 왕복으로 라운드마다 문장을 세우면 저자가 매 라운드 해답을 시도하는 모양이 된다. 이 비용을 다루는 전제가 없다. (5) 빠진 전제: §1.3 의 «빈약함 체감» 산출물과 Phase 0/1 모양 구분을 어떻게 처분할지가 전제에 없다. goal 은 무게가 아니라 의도 일치다(S2 «과하다 보다»). 따라서 이 둘이 의도 일치에 닿는지를 전제로 적어야 버릴지 정할 수 있다. (6) Law 2: 리뷰어를 걷어내면, 에이전트가 넣은 문장(이음말·풀이)을 저자 아닌 누군가가 검사하는 장치는 사용자뿐이다. 그 사용자 검사 경로가 바로 P6 이고, 위에서 반증됐다."
recommendation: refined
refined_takes: "리뷰어 지적을 저자 혼자 반영하지 않는다. 모든 지적은 사용자 앞에서 처분한다. 짧은 답을 에이전트 문장으로 굳히지 않는다. 사용자 원문과 그 답이 가리킨 질문·선택지 문구를 함께 싣는다. 사용자는 풀어 쓴 문장만 그 자리에서 확인하고, 확인된 것만 «(사용자 확인)» 을 달고 본문에 남긴다. 에이전트 추론은 본문에서 빼 이미 있는 «다시 검증할 것 —» 문단으로만 보낸다. 설계 §2.4 의 «사용자 편집» 단계를 되살려 게이트 앞에 둔다."
refined_drops: "리뷰어 제거는 버린다. seed-critic·codex 는 판정자가 아니라 탐지기로 남고, 산출은 저자가 아니라 사용자에게 간다. 모든 문장을 짧은 왕복으로 함께 쓰고 매 문장 확인하는 방식도 버린다. 확인은 원문이 아닌 문장에만 한다. 묶음 질문을 한 번에 질문 하나로 바꾸는 것도 버린다. §1.3 을 보존하고 Phase 1 과 같은 모양이 되는 것을 막기 위해서다. 사용자 없이 도는 저자 단독 다라운드 수정 루프도 버린다."
evidence:
  - url: "https://arxiv.org/html/2505.06120v1"
    supports: both
    claim: "Concat(사용자 조각을 이어 붙인 단일 지시)은 Full 성능의 평균 95.1% 다. 다중턴 저하는 모델이 너무 이르게 최종 해답을 시도하고 거기에 과하게 의존하는 데서 온다. 권고는 지금까지 말한 것을 합쳐 새 대화에서 시작하라는 것이다."
    touches: [P2]
  - url: "https://arxiv.org/abs/2602.07338"
    supports: both
    claim: "다중턴 저하의 근본 원인은 사용자 기대와 모델 해석 사이의 의도 정렬 격차다. 모호한 입력을 명시적 지시로 바꿔 쓰는 Mediator 가 저하를 크게 줄였다. 에이전트 바꿔 쓰기가 성능을 돕는다는 결과지만, 정답 지시가 있는 벤치마크에서의 결과다."
    touches: [P3]
  - url: "https://arxiv.org/abs/2302.00560"
    supports: alternative
    claim: "특정 견해를 띤 언어모델과 함께 쓰면 글에 드러난 견해와 사후 태도 조사가 모두 모델 쪽으로 움직였다. 과제에 시간을 적게 쓴 사용자일수록 더 영향을 받았다."
    touches: [P5]
  - url: "https://pmc.ncbi.nlm.nih.gov/articles/PMC11056364/"
    supports: alternative
    claim: "조언은 사전 판단과 무관하게, 의도치 않게 닻으로 작동한다. 설명을 제공해도 틀린 조언에 대한 의존이 유의하게 줄지 않았다."
    touches: [P6]
  - url: "https://arxiv.org/abs/2509.08514"
    supports: alternative
    claim: "2,784명 실험에서, 표시된 AI 오류를 고치도록 요구하자 참여가 줄고 틀린 제안 수용이 늘었다."
    touches: [P6]
  - url: "https://arxiv.org/pdf/2310.01798"
    supports: current
    claim: "외부 피드백 없이 모델 스스로 교정하면 추론이 개선되지 않고 때로 나빠진다."
    touches: [P4]
  - url: "https://arxiv.org/pdf/2303.17651"
    supports: alternative
    claim: "같은 모델이 생성·피드백·개선을 반복하는 Self-Refine 은 과제 평균 약 20% 향상을 냈다. 사용자 없는 리뷰→수정 루프가 반드시 표류하지는 않는다는 반례지만, 품질을 잴 수 있는 과제에서의 결과다."
    touches: [P4]
  - url: "https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md"
    supports: current
    claim: "한 메시지에 질문 하나만 하고, 설계를 절 단위로 제시하며 절마다 «맞는지» 묻는다. 작성된 spec 은 사용자가 검토·승인한 뒤에만 진행한다."
    touches: [P5]
  - url: "https://github.com/github/spec-kit"
    supports: current
    claim: "/speckit.clarify 는 미명세 지점을 순차 질문으로 좁히고, 답을 spec 에 곧바로 반영한다. 문서를 형성하는 도중에 사용자가 참여하는 선례다."
    touches: [P5]
repo_claims:
  - path: "docs/superpowers/specs/2026-08-23-request-framing-design.md"
    anchor: "### 2.4 검증과 확정 — «3. **사용자 편집** — 사용자가 본문을 직접 고친다. 자기 도메인 지식으로 바꿔야 할 곳이 반드시 있다.»"
    line: 124
    claim: "원 설계는 억제 리뷰와 냉독 뒤, 게이트 앞에 사용자가 본문을 직접 고치는 단계를 두었다."
    touches: [P4]
  - path: "plugins/spec-distill/skills/framing-requests/SKILL.md"
    anchor: "## 확정 — proceed 게이트 — «③ | 수정 필요 — 압축을 다시 깎고 이 게이트로 돌아옵니다»"
    line: 602
    claim: "구현에는 «사용자 편집» 단계가 없다(plugins/spec-distill 전체에서 «사용자 편집|직접 고친» grep 0건). 수정은 ③ 을 거쳐 저자 에이전트에게 돌아간다. 설계에서 구현으로 넘어오며 빠진 것이다."
    touches: [P4]
  - path: "plugins/spec-distill/skills/framing-requests/SKILL.md"
    anchor: "### 확정 표시와 «다시 검증할 것»"
    line: 34
    claim: "에이전트 추론을 본문 밖으로 분리하는 채널이 이미 있다. 확정 표시는 «(사용자 확인)» 하나이고, 추론·외부 항목은 «다시 검증할 것 —» 문단에 모은다. 대안의 «추론은 그 문단에만» 은 새 장치가 아니라 이 채널을 엄격히 적용하는 것이다."
    touches: [P1]
  - path: "docs/superpowers/specs/2026-08-23-request-framing-design.md"
    anchor: "### 1.3 두 산출물 — «질문이 한꺼번에 쏟아질 때 사용자가 자기 입력이 얼마나 빈약했는지 체감하는 것 자체가 산출물이다»"
    line: 60
    claim: "묶음 질문은 seed 와 별개로 이름 붙은 산출물이다. 원안의 짧은 왕복이 이것을 유지하는지 전제 목록에 적혀 있지 않다."
    touches: []
  - path: "plugins/spec-distill/skills/conducting-interview/SKILL.md"
    anchor: "## 라운드 규약 — 지금 이해 · 다음 결정 · 질문 하나"
    line: 77
    claim: "Phase 1 은 이미 라운드마다 질문 하나다. Phase 0 이 짧은 왕복으로 바뀌면 두 단계가 같은 모양이 된다."
    touches: []
  - path: "plugins/spec-distill/agents/seed-critic.md"
    anchor: "tools: [] / «4. **사용자 결정처럼 표현된 에이전트 추론** — 누가 정했는지가 뒤바뀐 문장.»"
    line: 36
    claim: "리뷰어는 도구가 없고 뺄셈만 한다. 문장을 쓰는 것은 저자 쪽 반영이다. 탐지와 반영은 다른 행위자다."
    touches: [P4, P6]
  - path: "docs/superpowers/interview/2026-09-05-interview-depth-redesign-interview.audit.md"
    anchor: "### 4.5 초안 v1 → v2 반영 / ### 4.7 seed-critic r2 (초안 v2) / ### 4.9 초안 v2 → v3 반영"
    line: 236
    claim: "저자 혼자 critic r1 6건과 codex r2 4건(+1건 부분)을 반영했다. 그 v2 에서 새 지적 13건이 나왔고, 13건을 반영한 v3 에서 다시 7건이 나왔다. 저자 단독 반영이 라운드마다 새 결함을 만들었다."
    touches: [P4, P1]
  - path: "docs/superpowers/interview/2026-09-05-interview-depth-redesign-interview.audit.md"
    anchor: "### 4.11 seed-critic r3 (초안 v3) — 7건, 미반영(게이트 텍스트에 공시) + 라운드 5 주석 «critic r3 1번은 미해결로 남음»"
    line: 270
    claim: "사용자는 추론 계열 지적이 공시된 v3 를 직접 보고 승인했다(① 선택). 36건 지적 중 추론·결정 뒤바뀜 계열 16건은 모두 리뷰어가 냈다."
    touches: [P6]
  - path: "docs/superpowers/interview/2026-09-05-interview-depth-redesign-interview.audit.md"
    anchor: "### 4.1 codex r1 — «대가는 알고 받아들였다 … 는 사용자 원문 «세션에 워크트리가 고정되지는 않게»와 반대» / 4.7 #10 «(codex r1·r2 와 반대 방향의 판정)»"
    line: 209
    claim: "두 리뷰어가 같은 문장을 정반대로 판정했다. codex r1 은 라운드 2·3 원문이 빠진 결함 번들 위에서 돌았다. 이 문장은 라운드 4 의 사용자 확인(«B 는 세션 고정 대가를 알고 고른 것»)으로만 풀렸고, S6 은 그것이 의도였다고 한다. 리뷰어끼리의 불일치는 사용자만 풀 수 있었다."
    touches: [P5, P4]
  - path: "docs/superpowers/interview/2026-09-05-interview-depth-redesign-interview.audit.md"
    anchor: "### 라운드 4 — proceed 게이트 1차 답변 (원문) — «해석 확인(복수 선택): …»"
    line: 64
    claim: "S6 의 두 확인은 형성 도중이 아니라 게이트에서, 에이전트가 제시한 해석을 복수 선택한 것이다. P5 의 근거는 시점이 아니라 «좁은 해석 하나를 묻는 형태» 를 뒷받침한다."
    touches: [P5]
  - path: "docs/superpowers/interview/2026-09-05-interview-depth-redesign-interview.audit.md"
    anchor: "### 라운드 2 — 사용자 답변 (원문) — «두번째는 권장방식이 뭔지 나에게 알려줘 모든 선택지를 바로 결정말고 트레이드오프를»"
    line: 54
    claim: "질문 라운드 안에서 사용자는 에이전트의 프레이밍을 스스로 되돌렸다. 형성 중에 사용자가 노출되면 교정이 실제로 일어난다."
    touches: [P5]
  - path: "docs/superpowers/interview/2026-09-06-interview-depth-redesign-interview.md"
    anchor: "✎ **S1 의 출처** — ««(사용자 확인)» 표시가 붙지 않은 문장(예: C20)은 Phase 0 이 사용자 발화를 옮겨 적은 것이지 사용자가 그 문장 그대로 말한 것은 아닐 수 있다»"
    line: 338
    claim: "인터뷰는 seed 전문을 사용자 출처로 다룬다. 그래서 확인 표시 없이 에이전트가 옮겨 적은 문장도 하류에서 사용자 발화 지위를 얻는다. 표류가 전달되는 경로다."
    touches: [P1]
```

**게이트-전 확인** — repo_claims: design 2026-08-23 §2.4 «3. 사용자 편집»(:122-123) 확인 · SKILL.md:602 ③ + grep «사용자 편집|직접 고친» 0건 확인 · SKILL.md:34 확인 · design :60 §1.3 확인 · conducting-interview SKILL.md:77 확인 · agents/seed-critic.md:14 `tools: []` · :36 축4 확인 · audit §4.5→4.7(13)→4.11(7) 확인 · audit §4.11 + :70 공시 후 ① 승인 확인(주장 안의 «36건 중 16건» 계수는 미확인 — orchestrator 가 세지 않음) · audit :209 · :255 · :203 확인 · audit :64 확인 · audit :54 확인 · 09-06 brief :338 확인 → 리포 주장 12 중 확인 12 · 부착 주장: #1→P2 · #2→P3 · #3→P5 · #4→P6 · #5→P6 · #6→P4 · #7→P4 · #8→P5 · #9→P5 전부 확인(claim 과 전제 문장 대조, URL 은 orchestrator 가 열지 않음) → 근거 9 중 부착 9 · 재검토 자격: 열림 3건(P6 — audit §4.11 · PMC11056364 · 2509.08514)

**사용자 선택** — 보완 (S8). builder refined 와 orchestrator 판정 모두 보완. «티키타카=질문 하나 형식»이면 기타에 적으라는 공시에 사용자 메모 없음.

## 4. 게이트 실행 기록

- check_brief.py gate — fail (2026-09-15) — web: enabled — «landscape keys not declared in audit §7: ['사용자 편집']» (§4 Kiro 항목의 겹낫표가 출처키로 파싱됨) → 겹낫표 제거
- check_brief.py gate — pass (2026-09-15) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-15)
- check_brief.py gate — pass (2026-09-15) — 리뷰 라운드 3 결정 반영 뒤 최종본 · check_verbatim_coverage.py — exit 0 (S1~S26)

## 5. 프로세스 로그

- round 0: path (a) — `framing-requests` SKILL(669줄) · `request-framing` command · 실제 seed 4건 크기 · 2026-09-05 seed 2건과 audit · 원 설계 2026-08-23 §1.2~§2.3 읽음. non_user_streak 1.
- coverage-mapper 1/2 (R1 전): 제안 4(Phase 0/1 경계 · 선행 결정 이력 · 수렴 신호 · seed 공동작성), admit 3. 선행 결정 이력은 skepticism 의 steelman trigger(기존 사용자 선호와 충돌)로 흡수. neglect_flag false.
- round 1: path (d) — 과한 자리(복수) → S2. «과함»이 아니라 의도↔seed 불일치로 root 재구성 신호.
- round 2: path (b) 되묻기(S2 근거 없는 단정) — 새는 지점 → S3. 병렬 landscape sweep(general-purpose, web).
- 정정(R2): orchestrator 와 coverage-mapper 가 9/5 «framing-requests 이쪽이 더 좋은거 같아»를 묶음 선호로 읽었으나, 9/5 critic r3(해당 audit :272)이 지시 대상 모호로 지적했고 미확인 채 seed 에 실린 것을 확인 → 정정. skepticism 흡수 근거(선행 선호) 약화.
- round 3: path (b) — landscape 처분 → S4. landscape closed.
- round 4: path (d) — root 재구성 동의 → S5. root_problem closed. 되묻기 생략(재구성이 S2~S4 선택으로만 조립 · S4 «번호 답도 괜찮다»). 병렬 blind-spot-prober 1/1.
- premortem 게이트-전 확인: 9/5 audit :64 · :266 · seed :15 · :23 확인. seed-input.md :3-4 · :13-15 출처=사용자 확인, :15-17 status provisional · :12 무표시 문장 미확인 → H2 일부 반증.
- 순서 결정: steelman 을 premortem 처분 뒤로 미룸 — premortem 이 P1 · P5 를 겨눠 방향이 바뀔 수 있고 steelman 은 방향당 1회.
- round 5: path (b) — premortem 핵심 반례(9/5 확인 두 건이 실제 의도였나) → S6. blind_spot closed. P1 · P5 갱신.
- round 6: path (d) — Phase 0 의 자리 → S7. derived:phase0_phase1_boundary closed. 병렬 steelman-builder ST1.
- round 7: steelman 게이트 ST1(고정 순서 유지/보완/전환/보류) → S8 보완. skepticism closed. derived:seed_co_authoring 을 S8 로 닫음(orchestrator 판단, 사용자 번복 가능 공시).
- round 8: path (b) — 불일치를 알아챈 시점 → S9. derived:convergence_signal closed.
- round 9: path (b) — OQ1~OQ6 확인 → S10. open_questions closed.
- web kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB` — coverage-mapper · landscape · prober · steelman dispatch 직전마다 확인, 전부 미설정.
- 공시: 세 에이전트가 가져온 외부 URL 을 orchestrator 는 직접 열지 않았다. landscape 에이전트는 BMAD 원문과 «리뷰어 불일치를 사람에게 올려라» 권고의 원문을 열지 못했다고 밝혔다. «번호 답이 뉘앙스를 잃는다»를 직접 잰 LLM 연구는 찾지 못했다.

#### blind-spot-prober 출력 요지 (payload §5 위험의 원자료)

- H1 사용자가 루프에 있으면 에이전트 말이 사용자 말로 굳지 않는다 — 반례로 9/5 audit :64 복수선택 확인 → seed :15 · :23 «(사용자 확인)», audit :266. 선택맹 https://www.science.org/doi/10.1126/science.1111709 · 공동 작성 영향 https://dl.acm.org/doi/10.1145/3544548.3581196
- H2 Phase 0 저작 방식만 바꾸면 닫힌다 — seed-input.md :3-17 가 seed 전문을 사용자 출처로
- H3 prior art 가 문장 단위 공동작성을 지지한다 — https://github.com/github/spec-kit · https://kiro.dev/blog/introducing-kiro/ · https://github.com/obra/superpowers/blob/main/skills/brainstorming/SKILL.md
- H4 의도는 고정 과녁 — https://www.decisionresearch.org/book-collection/the-construction-of-preference
- H5 티키타카가 과함을 줄인다 — 9/5 audit :154 첫 사이클 respondent fatigue · https://aclanthology.org/2024.findings-eacl.84.pdf · https://arxiv.org/html/2602.01405v1 · https://tianpan.co/blog/2026/06/25/approval-fatigue-how-human-in-the-loop-gates-decay-into-rubber-stamps
- H6 묶음은 버려도 되는 부산물 — 원 설계 :60-61 · :90-91
- F1 확인 표시 세탁 → P23 재결정 동기 소실 — seed-input.md :18-21
- F2 같은 세션 즉시 다듬기의 sycophancy 증폭 — https://arxiv.org/abs/2310.13548
- F3 «사용자 있으니 리뷰어 과함»으로 표류 탐지기 제거 — https://tianpan.co/blog/2026/04/15/human-in-the-loop-rubber-stamp · https://arxiv.org/abs/2310.01798
- F4 긴 같은-세션 대화에서 초반 가정 고착 — https://arxiv.org/abs/2505.06120
- F5 Phase 0/1 같은 모양 + 확인 표시로 재검증 감소 — 9/5 audit :36-37
- F6 게이트 «맞다» 감각 착시 — 선호 구성 · 공동 작성 영향 (위 H4 · H1 URL)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

(순수 텔레메트리 — **기록이며 게이트 통과 조건이 아니다.** `reviewing-brief` 가 Step B 로 돌아가기 전에
한 줄씩 채운다. 라운드의 결정 자체는 엔진이 이 파일 끝의 `## 8. 리뷰 결정` 에 append-only 로 쓴다 — 그
절은 손으로 만들지 않는다(없으면 엔진이 만든다). 리뷰 생략 방지는 Step B 게이트의 degrade 전파가 담당한다.)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0(사용자가 «열지 않음») — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예(round_reviewed 참) — 단 라운드 3 결정 채택 3건 · fix 3건의 적용은 다음 라운드 diff 가 없어 엔진이 관측하지 않았다(재리뷰 미관측)
- 결정: `## 8. 리뷰 결정` 14건(채택 13 · 사용자 기각 1 — D3.13, 에이전트 추천과 반대) · 열린 채 남은 항목 0건 · 라운드 1 결정 D1.2 는 전제 일부 반증으로 라운드 2 D2.8 에 재결정(P23)
- codex: 있음 — 실호출 3 · 성공 3(라운드별 지적 2 · 0 · 1) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: gap 4건 (G3 ×2 — C12 부담 제약 · C5 누락 / G6 ×2 — §0 «다음» 과 §7 설계 대상 불일치 · frontmatter sentinel 문구와 그 아래 주석의 반대 읽힘) · 모르는 용어: ST1 · P6 · 부착 9/9 · R3(§5 첫 줄)
- degrade: critic:fidelity degraded — 라운드 2 번들 조립 blob_rc=3(9/5 audit 경로 인용, 라운드 3 에서 해소) · 라운드 3 편집 재리뷰 미관측(상한 · 추가 라운드 미개설)
- Step B: ① «확정하고 /compact 후 brainstorming» (2026-09-15) — C1~C15 confirmed, sentinel 줄과 그 설명 주석 삭제

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 + 🗣 기타 (R1 — 과하다고 느낀 자리):
  > [선택] 초안 뒤 검증·게이트 / [기타] 과하다 보다, 내의도 보다 seed간 의도가 안맞음 내가 원하지 않는 방향으로 가는듯함
- **S3** ☑ 선택 (R2 — 원하지 않는 방향이 된 순간):
  > 리뷰→수정이 나 없이 돈 것 (권장), 짧은 답이 남의 말로 굳음, 에이전트 추론이 seed에 실림 — «seed 는 괜찮았고 하류가 틀었다»는 고르지 않음
- **S4** ☑ 선택 (R3 — 외부 근거 처분):
  > 번호 답도 괜찮다 — landscape ①②③ 취함, ④(번호 답=형식적 승인) 거부
- **S5** ☑ 선택 (R4 — 문제 재구성 동의):
  > 맞다 (권장) — root 재구성 동의, goal = S2 원문
- **S6** ☑ 선택 (R5 — 9/5 확인 두 해석이 실제 의도였나):
  > 둘 다 의도가 맞았다 (권장) — 9/5 확인 두 해석(늘어도 돼=4범주 전부 · a=한 브랜치 분석→설계→구현)은 실제 의도
- **S7** ☑ 선택 (R6 — Phase 0 의 자리):
  > 맡길 일을 내 말로 확정 (권장) — Phase 0 은 맡길 일을 사용자 말로 확정, 조사·반론·원인 후보는 Phase 1
- **S8** ☑ 선택 (R7 — steelman 게이트 ST1):
  > 보완 (builder·orchestrator 추천) — ST1 verdict refined. «티키타카=질문 하나 형식» 기타 메모 없음
- **S9** ☑ 선택 (R8 — 불일치를 알아챈 시점):
  > 다음 단계로 넘어간 뒤 (권장) — seed 불일치를 알아챈 시점
- **S10** ☑ 선택 (R9 — 열린 질문 목록 확인):
  > 이대로 (권장) — OQ1~OQ6 목록 확인
- **S11** ☑ 선택 (R3 — S4 가 답한 질문의 문구, 리뷰 라운드 1 뒤 보강 기록):
  > [S4 가 가리키는 R3 질문 문구] ① 압축해서 새 세션으로 넘기는 것은 옳다(Laban: 합치면 95.1%) — 문제는 누가 그 요약을 쓰느냐 ② 사용자 없이 에이전트끼리 반복 수정하면 표류한다(생성형 과제 76~89%) ③ 문서가 만들어지는 '중간'에 사용자를 넣는다(Spec Kit·Kiro·superpowers) ④ 권장안 번호로만 답하면 형식적 승인이 된다 — 사용자 자신의 말로 확인받아야 한다 / 선택: 번호 답도 괜찮다(④ 거부, ①②③ 취함)
- **S12** ☑ 선택 (R7 — S8 이 고른 선택지의 문구, 리뷰 라운드 1 뒤 보강 기록):
  > [S8 이 가리키는 ST1 게이트 선택지 문구] 보완 = 리뷰어는 탐지기로 남기고, 지적 처분은 사용자 앞에서 합니다. 짧은 답은 원문과 질문 문구를 함께 싣고, 풀어 쓴 문장만 확인받습니다. 에이전트 추론은 '다시 검증할 것' 문단으로만 보내고, 빠졌던 '사용자 편집' 단계를 되살립니다. 묶음 질문은 유지합니다.
- **S13** ☑ 선택 (brief 리뷰 라운드 1 — 결정 D1.1):
  > 채택 (권장) — [결정 abf668a4#r1.1] 새 방향의 '지적 처분은 사용자 앞에서'는 9/5식 게이트 공시와 달라야 한다(예: 항목별로 처분하지 않으면 진행할 수 없는 식) — 이 차이를 brief 방향에 넣는다. 선택지 문구: §0·§2에 '사용자 앞 처분은 공시만으로는 부족하다(9/5가 그 경로로 샜다)'를 적고, §2 ✎의 '확인 없이 실렸다'를 사실대로 고친다. 처분 방식(항목별 처분 강제 등)은 예시로만 두고 설계에 맡긴다
- **S14** ☑ 선택 (brief 리뷰 라운드 1 — 결정 D1.2):
  > 채택 — 좁힘 (권장) — [결정 abf668a4#r1.2] '지적 처분을 사용자 앞으로'를 새 단계로 설계하지 않고, 이미 있는 계약(세 리뷰어의 원문 출력은 사용자에게 직접 간다, orchestrator는 판정하지 않는다, 수정 경로는 게이트 ③뿐)을 저자가 비켜 가지 못하게 하는 일로 좁힌다
- **S15** ☑ 선택 (brief 리뷰 라운드 1 — 결정 D1.3):
  > 채택 (권장) — [결정 abf668a4#r1.3] 도중 확인을 새로 더하기 전에, 이미 있는 매 라운드 '원문과 다른 점' 블록이 9/5 오독을 왜 못 잡았는지를 설계 입력으로 넣는다. 선택지 문구: §2에 이 기존 블록과 그것이 못 잡은 사실을 적고, 설계가 대체·강화·유지 중 하나를 고르게 한다
- **S16** ☑ 선택 (brief 리뷰 라운드 1 — 결정 D1.4):
  > 채택 (권장) — [결정 b73addba#r1.1] §4의 Spec Kit 항목을 'Q→A 원문 기록만 취하고, 본문을 풀이 확인 없이 고치는 부분과 질문 하나 형식은 피한다'로 좁힌다
- **S17** ☑ 선택 (brief 리뷰 라운드 1 — 결정 D1.5):
  > 채택 — 제약으로 (권장) — [결정 f4aceed8#r1.1] 초안 뒤 검증·게이트는 사용자가 과하다고 고른 곳(S2)이다. 선택지 문구: §0·§2에 '이 자리는 사용자가 과하다고 고른 곳(S2)'임을 적고, 사용자 편집·처분이 그 자리의 부담을 늘리는지를 설계가 따져야 할 제약으로 올린다
- **S18** ☑ 선택 (brief 리뷰 라운드 2 — 결정 402da1b4#r2.1):
  > 채택 (권장) — [결정 402da1b4#r2.1] 설계가 현행 판본(3.1.0)에서 이 누수가 재현되는지부터 확인하게 하고, OQ6의 겨냥을 '리뷰어 제안 범위'에서 '저자의 라벨 선택과 리뷰어 제안 양쪽'으로 옮긴다. 선택지 문구: §3에 '현행 3.1.0에서 재현 확인'을 설계의 첫 입력으로 올리고, OQ6을 '추론이 머리말을 달고 남는 통로(저자 라벨 선택 + 리뷰어 접두 제안)'로 고친다. §2 ✎의 '리뷰어 제안에서 생겼다'도 사실대로 고친다
- **S19** ☑ 선택 (brief 리뷰 라운드 2 — 결정 5d052b11#r2.1):
  > 채택 — 좁힘 (권장) — [결정 5d052b11#r2.1] §1 Non-goal에서 '매 문장 확인'만 남기고(S12 '풀어 쓴 문장만'), '짧은 왕복으로 함께 쓰기'는 기각된 게 아니라 열려 있다고 적는다 — ST1에서 거부한 '유지' 선택지는 '짧게 주고받으며 함께 쓰기'와 '리뷰어 제거'가 한 묶음이었다
- **S20** ☑ 선택 (brief 리뷰 라운드 2 — 결정 abf668a4#r2.1):
  > 채택 — 넓힘 (권장) — [결정 abf668a4#r2.1] 라운드 1 결정 abf668a4#r1.2 의 전제 일부('수정 경로는 게이트 ③뿐인 이미 있는 계약')는 SKILL에 없는 문장이라 반증됐다. C10이 '저자가 계약을 비켜 가지 못하게'에서 '③ 안에서도 지적을 저자 혼자 반영하지 않고 항목별로 사용자가 처분한다'로 넓어지고, 틀린 전제를 지운다. 라운드 1 결정을 이 답으로 재결정한 것으로 기록한다
- **S21** ☑ 선택 (brief 리뷰 라운드 2 — 결정 abf668a4#r2.2):
  > PR 5 위에서 설계 (권장) — [결정 abf668a4#r2.2] 이 brief는 docreview 재설계 PR 5(seed 자리를 공유 리뷰 엔진으로)의 입력이 된다. 엔진의 항목별 사용자 결정을 그대로 쓰고, 바꿀 곳은 seed 프로필의 '저자가 혼자 적용하는 fix' 범위다. 설계 대상이 framing-requests SKILL에서 PR 5 배선 + seed 프로필로 바뀐다
- **S22** ☑ 선택 (brief 리뷰 라운드 2 — 결정 abf668a4#r2.3):
  > 채택 (권장) — [결정 abf668a4#r2.3] C11의 전제를 고친다 — 9/5 audit에 '원문과 다른 점' 블록 기록은 0건이고, 오독은 저자의 '해석(확인 대상)' 목록에 올라 사용자에게 보였으나 응답 없이 지나갔다. 선택지 문구: C11이 '형성 도중의 공시(해석 확인 목록)도 공시 뒤 무응답으로 샜다, 저자 자기보고 블록은 저자가 옳다고 믿는 오독을 실을 수 없다'로 바뀌고, C9와 'PR 5 위에서(항목별 결정 없이는 진행 불가)'의 근거가 된다
- **S23** ☑ 선택 (brief 리뷰 라운드 3 — 결정 a6484ced#r3.1):
  > 채택 — 역할 유지 (권장) — [결정 a6484ced#r3.1] §1 Non-goal '리뷰어 제거 — 기각'은 seed-critic 파일이 아니라 탐지 역할(격리 critic · 다른 모델 계열 리뷰 · 냉독)을 유지한다는 뜻이다. 선택지 문구: §1이 '탐지 역할 제거 — 기각'으로 바뀌고, PR 5가 파일을 엔진 탐지기로 바꾸는 것은 이 Non-goal과 부딪치지 않게 된다
- **S24** ☑ 선택 (brief 리뷰 라운드 3 — 결정 eb353eb4#r3.1):
  > 채택 — 틀을 뺌 (권장) — [결정 eb353eb4#r3.1] C10의 '새 단계가 아니라' 틀을 뺀다. 선택지 문구: C10은 '저자가 지적을 혼자 반영하는 경로를 닫는다(게이트 전·③ 뒤 모두 항목별 사용자 처분)'만 남고, 새 단계를 둘지는 설계가 부담 제약(C12) 안에서 정한다
- **S25** ☑ 선택 (brief 리뷰 라운드 3 — 결정 f4aceed8#r3.1):
  > 기각 — 개수로 충분 — [결정 f4aceed8#r3.1] PR 5 엔진에서 탐지기가 drop으로 매긴 지적과 재비판자가 reject한 지적을 개수로만 공시하는 지금 방식을 받아들인다. 선택지 문구: 엔진이 걸러낸 지적은 개수만 보여 주는 지금 방식을 받아들인다. 사용자 부담은 덜하지만 에이전트끼리 처분하는 경로가 하나 남는다
- **S26** ☑ 선택 (brief 리뷰 라운드 3 — 결정 f4aceed8#r3.2):
  > 채택 — 수단은 설계로 (권장) — [결정 f4aceed8#r3.2] C13은 'PR 5 위에서'만 남기고 'seed 프로필의 fix 범위를 바꾼다'는 수단을 뺀다. 헤딩 없는 seed에서 저자 단독 반영을 어떻게 막을지는 세 수단(fix를 허용 처분에서 빼면 ask로 떨어짐 · seed에 헤딩을 주면 '양식으로 만들지 않는다' 계약과 부딪침 · 저자 준수는 9/5에 실패)과 각 문제를 담은 열린 질문으로 설계에 넘긴다

## 7. 확산 원자료

(orchestrator 는 아래 URL 을 직접 열지 않았다 — landscape · prober · steelman 에이전트가 가져온 출처다.)

- «laban-2025» — https://arxiv.org/abs/2505.06120 — 다중턴 −39% · Concat 95.1% · 요약 후 새 대화 권고
- «multiagent-drift-2025» — https://arxiv.org/abs/2502.19559 — 다중 에이전트 논의의 생성형 과제 표류 76–89%
- «debate-sycophancy-2025» — https://arxiv.org/abs/2509.05396 — 토론에서 동의 편향으로 뒤집힘
- «iterative-distortion-2025» — https://arxiv.org/abs/2502.20258 — 반복 재생성 왜곡 누적
- «cognition-multiagent» — https://cognition.com/blog/dont-build-multi-agents — «Actions carry implicit decisions»
- «rewrite-intent-2025» — https://arxiv.org/abs/2503.16789 — 1회 재작성 의도 보존(사람 평가)
- «mediator-2026» — https://arxiv.org/abs/2602.07338 — 의도 정렬 격차 · Mediator 바꿔 쓰기
- «speckit-clarify» — https://raw.githubusercontent.com/github/spec-kit/main/templates/commands/clarify.md — 질문 하나씩 · 답마다 spec 반영
- «kiro-requirements» — https://kiro.dev/docs/specs/feature-specs/requirements-first/ — requirements 직접 반복 수정 후 확인
- «claude-plan-mode» — https://code.claude.com/docs/en/permission-modes — 끝 승인 + 본문 직접 편집
- «superpowers-brainstorming» — https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md — 절마다 맞는지 확인
- «anthropic-effective-agents» — https://www.anthropic.com/engineering/building-effective-agents — 체크포인트 사람 피드백 · 평가자는 명확한 기준 필요
- «anchoring-2026» — https://arxiv.org/abs/2603.11821 — AI 권장안 anchoring
- «pmc-anchoring» — https://pmc.ncbi.nlm.nih.gov/articles/PMC11056364/ — 조언 anchoring, 설명해도 안 줄어듦
- «ai-error-correction-2025» — https://arxiv.org/abs/2509.08514 — AI 오류 교정 요구 시 틀린 제안 수용 증가
- «jakesch-2023» — https://arxiv.org/abs/2302.00560 — 공동 작성이 견해를 모델 쪽으로
- «huang-2023» — https://arxiv.org/abs/2310.01798 — 외부 피드백 없는 자기 교정의 한계
- «self-refine-2023» — https://arxiv.org/pdf/2303.17651 — Self-Refine 약 20% 향상
- «johansson-2005» — https://www.science.org/doi/10.1126/science.1111709 — 선택맹
- «construction-of-preference» — https://www.decisionresearch.org/book-collection/the-construction-of-preference — 선호 구성
- «approval-fatigue» — https://tianpan.co/blog/2026/06/25/approval-fatigue-how-human-in-the-loop-gates-decay-into-rubber-stamps — 승인 피로
- (payload 미사용, 기록만) BMAD PRD elicit — https://www.skills.sh/bmad-code-org/bmad-method/bmad-prd — 검색 결과로만 확인, 원문 미열람
- (payload 미사용, 기록만) Spec Kit issue #1147 — https://github.com/github/spec-kit/issues/1147 — 권장안만 보이고 질문 사라짐
- (payload 미사용, 기록만) LLM 상호작용 유래 개발자 편향 — https://arxiv.org/abs/2601.08045
- (payload 미사용, 기록만) AI 제안의 동질화 — https://arxiv.org/abs/2409.11360
- (payload 미사용, 기록만) 다중 에이전트 논의 핵심 사실 소실 — https://arxiv.org/abs/2606.03032

## 8. 리뷰 결정

- D1.1 · r1 · adopt · abf668a4#r1.1 · "채택 (권장)" — brief 가 C3 의 실례로 든 9/5 오독은 저자 단독 반영으로 샌 것이 아니다. 탐지되고 게이트에 공시된 뒤 사용자가 승인한 경로로 샜다. C7 의 «사용자 앞 처분» 이 9/5 의 게이트 공시와 무엇이 달라야 하는지를 방향에 넣을지 결정해야 한다(예: 항목별 처분 없이는 진행 불가).
- D1.2 · r1 · adopt · abf668a4#r1.2 · "채택 — 좁힘 (권장)" — 리포에는 이미 «리뷰 raw 출력은 사용자에게 직접, orchestrator 는 판정하지 않음, 수정 경로는 게이트 ③ 뿐» 이라는 계약이 적혀 있다. C7 의 «지적 처분을 사용자 앞으로 옮긴다» 를 새 단계로 설계할지, 저자가 이 계약을 비켜 지적을 먼저 반영한 경로를 닫는 일로 좁힐지 결정해야 한다.
- D1.3 · r1 · adopt · abf668a4#r1.3 · "채택 (권장)" — 형성 도중에 이해의 어긋남을 사용자에게 보이는 장치(매 라운드 «원문과 다른 점» 블록)는 이미 구현돼 있지만 9/5 오독을 잡지 못했다. C4·C7 이 도중 확인을 새로 더하기 전에, 이 블록이 왜 못 잡았는지를 설계 입력으로 삼을지 결정해야 한다(대체 · 강화 · 유지).
- D1.4 · r1 · adopt · b73addba#r1.1 · "채택 (권장)" — C4 의 «문서 도중 사용자 참여» 근거로 [취함] 한 Spec Kit /clarify 는 질문을 하나씩 묻고, 답마다 에이전트가 풀이 확인 없이 spec 본문을 고친다. 이는 C3 의 누수 모양이자 C7 이 기각한 질문 하나 형식이다. [취함] 의 범위를 C7 둘째 변경과 맞는 Q→A 원문 기록으로 좁힐지 결정해야 한다.
- D1.5 · r1 · adopt · f4aceed8#r1.1 · "채택 — 제약으로 (권장)" — 사용자가 R1 에서 «과하다고 느낀 자리» 로 고른 곳은 «초안 뒤 검증·게이트» 다. C7 은 바로 그 자리에 사용자 단계 둘(지적 처분, 게이트 앞 사용자 편집)을 더한다. 이 부담 증가를 받아들일지 결정해야 한다.
- D2.6 · r2 · adopt · 402da1b4#r2.1 · "채택 (권장)" — brief 의 구체 사례는 전부 0.57.0(2026-09-07) 이전 판본으로 만든 9/5 seed 다. C7 셋째 변경의 통로(«다시 검증할 것 —» 문단)는 그 뒤에 들어왔고, «Phase 0 관찰» 라벨은 리뷰어보다 저자가 먼저 썼다. 설계가 현행 판본(3.1.0)에서 누수가 재현되는지를 먼저 확인하게 할지, 그리고 OQ6 의 겨냥을 seed-critic 의 제안 범위에서 저자의 라벨 선택으로 옮길지?
- D2.7 · r2 · adopt · 5d052b11#r2.1 · "채택 — 좁힘 (권장)" — §1 Non-goal 「매 문장을 짧은 왕복으로 함께 쓰고 매 문장 확인하는 것 — ST1 에서 기각」은 원문 S1 「티키타카 하면서 만드는」의 한 가지 읽기(문장 단위 공동 작성)를 닫는다. 그런데 그 기각은 원문에 기록돼 있지 않다. 이 Non-goal 을 유지할지, «매 문장 확인»만 남기고 «짧은 왕복 공동 작성»은 열어 둘지?
- D2.8 · r2 · adopt · abf668a4#r2.1 · "채택 — 넓힘 (권장)" — C10 이 좁힌 범위(저자가 raw 직행·③ 계약을 비켜 가지 못하게)로는 brief 가 든 9/5 누수 셋 중 둘을 막지 못한다. 대표 오독은 계약을 지킨 경로로 샜고, 머리말 둘은 사용자가 ③ 을 고른 뒤 저자 혼자 반영했다. ③ 안에서 지적을 반영하는 방식(항목별 처분)까지 범위로 넓힐지, C10 을 유지하고 그 차이를 C9 에 맡길지?
- D2.9 · r2 · adopt · abf668a4#r2.2 · "PR 5 위에서 설계 (권장)" — C7(지적 처분은 사용자 앞에서)과 C10(기존 raw 직행·게이트 ③ 계약 고수)이 이미 확정된 docreview 재설계와 부딪힌다. 그 재설계의 D5·PR 5 는 seed-critic·codex 러너를 지우고 엔진으로 바꾸며, seed 프로필의 fix 는 사용자 없이 저자가 적용한다. 이 brief 가 PR 5 를 대체·수정하는가, 아니면 PR 5 위에서 설계하는가?
- D2.10 · r2 · adopt · abf668a4#r2.3 · "채택 (권장)" — C11 은 «원문과 다른 점» 블록이 왜 못 잡았는지를 설계 입력으로 삼으라고 한다. 그러나 9/5 audit 에는 그 블록의 기록이 없어 분석할 대상이 없다. 실제로 오독은 저자 자신의 «해석(확인 대상)» 목록에 실려 사용자에게 보였고, 무응답으로 지나갔다. C11 의 전제를 이 사실로 고칠지? 고치면 형성 도중의 공시도 9/5 게이트와 같은 «공시 뒤 무응답» 경로였다는, C9 쪽 근거가 된다.
- D3.11 · r3 · adopt · a6484ced#r3.1 · "채택 — 역할 유지 (권장)" — §1 Non-goal 은 «seed-critic 제거»를 기각된 것으로 파일 이름까지 적었다. 그런데 C13 이 올라탄 PR 5 는 바로 그 `seed-critic` 과 seed codex 러너를 지우고 엔진 탐지기로 바꾼다. Non-goal 이 «탐지 역할 유지»인지 «seed-critic 파일 유지»인지 사용자가 정해야 한다
- D3.12 · r3 · adopt · eb353eb4#r3.1 · "채택 — 틀을 뺌 (권장)" — C10 의 «새 단계가 아니라»는 S14(라운드 1)의 틀인데, S14 는 S20 이 «이 답으로 재결정»했다. 이 틀이 S20 뒤에도 남는지는 원문만으로 갈리지 않는다 — 그 근거였던 «이미 있는 계약» 전제가 일부 반증됐다. 남는다면 C13 엔진의 항목별 결정(라운드 게이트)과 C12 의 부담 제약을 어떻게 읽을지도 달라진다. «새 단계 아님»을 유지할지 사용자가 정해야 한다
- D3.13 · r3 · reject · f4aceed8#r3.1 · "기각 — 개수로 충분" — PR 5 엔진을 그대로 쓰면(C13) 일부 지적이 사용자 앞에 오기 전에 처분된다. 탐지기가 매긴 처분, 재비판자의 reject, same_as 흡수, 처분 강제가 그것이고, 사용자에게는 개수만 공시된다. C7 의 «리뷰어는 탐지기로 남고 지적 처분은 사용자 앞에서»와 C9 의 «공시만으로는 부족하다»가 drop·reject 항목까지 덮는지 사용자가 정해야 한다
- D3.14 · r3 · adopt · f4aceed8#r3.2 · "채택 — 수단은 설계로 (권장)" — C13 이 고른 수단(seed 프로필의 fix 범위를 좁힌다)은 seed 에서는 저자 단독 반영을 막지 못한다. seed 가 헤딩 없는 산문이라 엔진이 얼림·보호 부류를 끄기 때문이다. 수단을 fix 범위에서 옮길지(허용 처분에서 fix 를 뺀다 · seed 에 헤딩을 준다 · 저자의 준수에 맡긴다) 사용자가 정해야 한다
