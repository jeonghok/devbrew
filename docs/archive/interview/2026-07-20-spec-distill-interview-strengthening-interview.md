---
name: spec-distill-interview-strengthening
type: interview-brief
created_at: 2026-07-20
session_id: acd7a521-8c8a-47a7-b83c-357fdd2cdde8
source: spec-distill conducting-interview v0.21.0
next_phase: superpowers:brainstorming
# locked_directions — (b)/(d) 명시 응답 + steelman 통과 방향. brainstorming 기정사실.
# 의심(R3) triggered 방향은 steelman ∈ {defended, switched-to-this} 여야 하며,
# Skepticism Log(§4)에 대응 항목이 있어야 한다. un-challenged 의심 방향은 금지.
locked_directions:
  - id: LD1
    statement: "인터뷰를 '커버리지-구동 하이브리드'로 재구성 — 결정론은 '반드시 열어야 할 미지 차원' 커버리지 계약만 강제, probe 종류/순서/깊이는 모델이 CTA 툴킷에서 적응 선택. 라운드 카운터 제거."
    source_path: b
    steelman: n/a
  - id: LD2
    statement: "teach/reveal-unknown 구현 = cross-cutting teach-beat(모든 probe가 질문 전 '근거+질문' 형태로 prior-art/trade-off 제시, 단정 금지 — 편향-주입 회피) + 커버리지 계약의 전용 blind-spot/premortem 슬롯 1개(적대적 subagent+웹으로 숨은 전제/실패양식 강제 노출)."
    source_path: b
    steelman: n/a
  - id: LD3
    statement: "집요함 ≡ 신호 기반 깊이 + 커버리지 계약(길고 무거운 인터뷰 ≠ 집요함). teach-beat는 모든 probe가 아니라 조건부(사용자 지식 갭 신호 시)로 발화해 fatigue 회피."
    source_path: b
    steelman: defended
    defense: "R3 steelman(respondent fatigue/satisficing + YAGNI over-specification)을 '집요함=길이'라는 등식 폐기로 흡수 — 집요함을 '신호 기반 조건부 깊이 + 커버리지 계약'으로 재정의하면 steelman이 옹호하는 '가볍고 적응적'과 오히려 상보한다. 남은 fatigue 리스크(teach-beat 빈도)는 조건부 발화로 봉쇄."
  - id: LD4
    statement: "커버리지 계약 = 하이브리드(LD1 재귀). 고정 보편 floor(root-problem/landscape/skepticism/blind-spot/open-questions)만 결정론 강제 + 주제-도출 차원을 인터뷰가 스스로 도출하고 커버 근거를 brief에 기록."
    source_path: b
    steelman: n/a
  - id: LD5
    statement: "재구성 범위 = 중간. conducting-interview SKILL.md 프로즈 + check_brief.py(floor 5개 + 주제-도출 차원 근거 존재 검증) + 상태 스키마(interview_round → 커버리지 상태). 훅/에이전트 전면 재설계는 이월."
    source_path: b
    steelman: n/a
---

# spec-distill 인터뷰 강화 — Interview Brief (meta-prompt for brainstorming)

> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7대로 brainstorming
> 해답공간으로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다.

## 1. Reframed Problem

**(d) ontological 도출 유형: ROOT_CAUSE + HIDDEN_ASSUMPTIONS.**

받은 요청("인터뷰가 더 집요해지고, 미지·모호를 드러내 가르치고, 외부 탐색을 더 적극적으로, 라운드 기반을 유연한 아키텍처로")을 한 문장으로 재구성하면:

> **진짜 문제는 "인터뷰가 덜 집요하다"가 아니라, 인터뷰의 집요함·깊이·차원이 전부 *고정된 라운드 체크리스트*에 묶여 있다는 것이다.** 이 단일 근본원인이 세 증상을 동시에 낳는다 — (1) 주제와 무관하게 같은 5개 박스를 밟아 "기계적"으로 느껴지고, (2) 사용자가 모르는 미지(주제-특수 차원)를 열 자리가 없어 못 가르치며, (3) 외부 탐색도 라운드에 종속돼 소극적이다.

**진짜 goal:** 인터뷰가 전문 CTA practitioner처럼 elicit하게 만들기 — 즉 *무엇이 아직 안 열렸는지*를 추적하며 주제에 맞는 probe를 적응적으로 선택하고, 열 때마다 사용자에게 근거를 제시해 가르치되, 결정론은 "반드시 열려야 할 최소 미지 차원(floor)"에만 남긴다. 집요함은 인터뷰 *길이*가 아니라 *커버리지 미충족 시 종료 불가*라는 구조로 구현한다.

**숨은 가정 반증:** 원 요청은 "더 집요 + 더 유연"이 무충돌 병립한다고 가정했으나, 현재 결정론 라운드 구조에서 이 둘은 서로 당긴다(집요함을 라운드/게이트로 늘리면 유연·비기계성이 죽는다). 해소는 "집요함의 구현체를 라운드 수 → 커버리지 계약으로 옮기기"다.

## 2. Locked Directions

(확정·검증된 방향. frontmatter locked_directions와 1:1. 재논쟁 금지.)

- **LD1** — 아키텍처: **커버리지-구동 하이브리드.** 결정론은 "반드시 열어야 할 미지 차원" 커버리지 계약만 강제하고, probe 종류/순서/깊이는 모델이 CTA 툴킷(CDM 반복 pass, ACTA knowledge audit/simulation)에서 상황 적응적으로 선택. `interview_round` 카운터는 제거하고 "미충족 커버리지"가 종료를 통제한다.
- **LD2** — teach/reveal 구현: **cross-cutting teach-beat + 전용 blind-spot 슬롯.** 모든 probe는 질문 *전에* "근거+질문" 형태의 teach beat(사용자가 모를 prior-art·trade-off를 출처와 함께, 단정 아닌 질문으로 — 편향-주입 회피, [[feedback_shared_premise_blinds_reviewers]]). 더해 커버리지 계약에 blind-spot/premortem 슬롯 1개(적대적 subagent+웹으로 숨은 전제·실패양식 강제 노출 = unknown-unknown 메커니즘, 체크리스트 아님).
- **LD3** — 집요함의 정의: **신호 기반 깊이 + 커버리지 계약** (길고 무거운 인터뷰 ≠ 집요함). teach-beat는 *모든* probe가 아니라 사용자 지식 갭이 감지될 때만 조건부 발화 → respondent fatigue 회피. (§4 steelman에 대한 방어의 산물.)
- **LD4** — 커버리지 계약 구조: **하이브리드(LD1 재귀).** 고정 보편 floor(root-problem / landscape / skepticism / blind-spot / open-questions) = 결정론 강제 + 그 위 주제-도출 차원(인터뷰가 "이 주제엔 X·Y도 열어야 한다"를 스스로 도출하고 커버 근거를 brief에 남김). teach-beat는 도출 차원 개방 시 갭 감지되면 발화.
- **LD5** — 재구성 범위: **중간.** `conducting-interview` SKILL.md 프로즈 재작성 + `check_brief.py` 게이트(floor 5개 + "주제-도출 차원 근거 섹션 존재" 검증) + 상태 스키마(`interview_round` → 커버리지 상태). 훅/에이전트(`rhythm-guard`, `breadth-keeper` 등) 전면 재설계는 brainstorming/planning으로 이월.

## 3. External Landscape

(prior-art / 경쟁 / 기존 해결책. 각 항목 출처 URL 필수 + [취함|피함|중립] + 이유.)

- **Critical Decision Method (CDM)** — Hoffman/Crandall/Klein. 하나의 결정적 사건을 *여러 pass로 반복 훑으며* probe 질문으로 tacit 의사결정을 unpack. — https://journals.sagepub.com/doi/10.1518/001872098779480442 — **[취함]** — "반복 pass + probe"가 LD1의 "신호 기반 적응적 깊이"의 직접 원형.
- **Applied Cognitive Task Analysis (ACTA)** — Militello & Hutton 1998. 고정 라운드가 아니라 *도구 상자*(task diagram → 지형 그리기 → knowledge audit/simulation 차원을 *도출*), 93% cognitive-content relevance. — https://apps.dtic.mil/sti/tr/pdf/ADA335225.pdf — **[취함]** — LD4의 "고정 floor + 주제-도출 차원" 하이브리드의 근거. "먼저 지형, 그다음 차원 도출"이 커버리지 계약 설계 패턴.
- **CTA overview (Brown/Power/Gore 2025)** — semi-structured, context-eliciting elicitation. — https://journals.sagepub.com/doi/10.1177/10944281241271216 — **[중립]** — 방법론적 프레이밍 참고; 구현 세부는 brainstorming에서.
- **Respondent fatigue / satisficing 문헌** — 장문 인터뷰가 데이터 품질을 저하(satisficing 20–40%, 15–20분 후 하락). — https://www.sciencedirect.com/science/article/abs/pii/S0304387822001341 , https://methods.sagepub.com/ency/edvol/encyclopedia-of-survey-research-methods/chpt/respondent-fatigue — **[피함]** — "집요함=길이"를 폐기하고(§5) teach-beat 조건부화(LD3)의 근거.
- **YAGNI / over-specification (요구공학)** — 무거운 선제적 명세는 analysis paralysis·낭비. — https://softwarepatternslexicon.com/patterns-go/17/3/ — **[피함]** — LD5 범위를 "중간"으로 묶고 훅/에이전트 선취 고정을 이월한 근거.

## 4. Skepticism Log

(의심 triggered 방향별: steelman-builder 대안 요지(verbatim) + 웹근거 URL + verdict. 약화·편집 금지.)

- **대안 statement (verbatim):** "인터뷰를 grill(더 집요하게)·더 무거운 강제 pass·cross-cutting teach-beat로 확장하지 말고, 현재 구조(AP16 1회 steelman, web budget cap, rhythm guard)를 그대로 유지하거나 오히려 더 가볍고 적응적으로(질문 수를 줄이고 신호 기반으로만 깊이 파는 방향으로) 만들어야 한다 — '더 집요한 인터뷰'는 응답 품질을 개선하지 않고 저하시키며, 소프트웨어 요구공학에서 무거운 up-front elicitation은 이미 반증된 패턴이다." — https://www.sciencedirect.com/science/article/abs/pii/S0304387822001341 , https://people.ucsc.edu/~aspearot/survey_fatigue.pdf , https://softwarepatternslexicon.com/patterns-go/17/3/ — **verdict: defended**
  **방어 이유:** 대안의 핵심 무기는 "집요함 = 길고 무거운 인터뷰"라는 등식이다. 이 등식을 폐기하고(§5) 집요함을 "신호 기반 조건부 깊이 + 커버리지 미충족 시 종료 불가"로 재정의하면(LD3), 원안은 대안이 옹호하는 "가볍고 적응적"과 충돌하지 않고 상보한다 — 라운드 카운터 제거(LD1)와 teach-beat 조건부 발화(LD3)가 fatigue 경로를 실제로 *줄인다*. 대안이 겨눈 "결정론 게이트 남발"도 LD4/LD5가 결정론을 최소 floor로 국한해 회피. 즉 steelman은 원안을 뒤집지 않고 원안을 *더 정확히 재정의*하게 만들었다.

## 5. Tried & Discarded

(시행착오: 시도 → 버린 이유. 다운스트림 재탐색 차단.)

- **시도:** "집요함 = 더 길고 무거운 강제 인터뷰" — 모든 probe에 teach-beat + 다수의 강제 pass를 무조건 추가. → **버린 이유:** respondent fatigue/satisficing(15–20분 후 품질 하락, 장문 satisficing 20–40%) + YAGNI over-specification. 무거워질수록 사용자가 "괜찮아 보이는" 답을 *더 빨리* 내놓아 정확도가 되레 하락. 대체 = 신호 기반 조건부 깊이(LD3).
- **시도:** 커버리지 계약 = 고정 확장 체크리스트(5 의례 + blind-spot + non-goal = ~7개, 주제 무관 동일). → **버린 이유:** "기계적" 느낌의 근원(고정 박스)을 박스 수만 늘려 재도입. 대체 = 하이브리드(고정 floor + 주제-도출, LD4).
- **시도:** 재구성 범위 = 최소(SKILL.md 프로즈만). → **버린 이유:** 게이트/상태를 안 바꾸면 커버리지-구동이 문서상으로만 존재하고 집행 안 됨("말뿐 유연성"). 대체 = 중간 범위(LD5).

## 6. Open Questions

(미해결 명시. "유추 금지" — 해답공간으로 이월.)

- **OQ1 (게이트 검증 형태):** `check_brief.py`가 "주제-도출 차원이 실제로 커버됐는지"를 어떻게 결정론적으로 검증하나? 동적 차원 자체는 미리 알 수 없으므로 — 후보: brief에 `## Derived Coverage` 섹션 + 각 도출 차원의 근거 한 줄 존재를 검사(내용이 아닌 *형식·존재* 검증). 세부는 brainstorming.
- **OQ2 (teach-beat 갭 감지 신호):** "사용자 지식 갭"을 어떤 신호로 감지해 teach-beat를 조건부 발화하나? (예: 사용자가 landscape에 없는 방향을 제시 / 알려진 anti-pattern 근접 / 명시적 "모르겠음"). 휴리스틱 vs 명시 트리거 — 실측 필요.
- **OQ3 (상태 스키마 마이그레이션):** `interview_round` → 커버리지 상태 전환 시 in-flight 세션 backward-compat(현행 C10 in-flight migration 패턴 재사용?). 데이터 형태(커버리지 상태 = 열림/미열림 차원 목록 + 근거)의 구체 스키마.
- **OQ4 (기존 에이전트 역할 재정의):** `rhythm-guard`(라운드 기반 — 커버리지 모델에서 무엇으로 대체?), `breadth-keeper`(주제-도출 차원과 역할 중복 가능성) — 유지/재정의/폐기? LD5가 "이월"로 미뤘으므로 brainstorming/planning이 실측으로 결정.
- **OQ5 (blind-spot 슬롯의 fan-out 비용):** 전용 blind-spot pass가 적대적 subagent+웹을 매 인터뷰 강제 → cost_class·fan-out(devbrew N≥5 게이트) 영향. 항상 강제 vs 신호 조건부?

## 7. Concrete Next Action

superpowers 있으면: 이 brief를 context로 `superpowers:brainstorming`을 호출해 해답공간을 설계 → `docs/superpowers/specs/...-design.md` 산출 → `spec-distill:spec-reviewer`(Law 2 분리 reviewer) 검증 → `superpowers:writing-plans`. LD1–LD5는 기정사실(재논쟁 금지); brainstorming은 §6 Open Questions 5개를 해소하는 데 집중한다. superpowers 없으면: 이 brief가 완결 산출물 — 직접 다음 작업 입력으로 사용.
