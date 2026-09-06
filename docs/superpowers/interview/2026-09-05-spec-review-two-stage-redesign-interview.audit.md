---
type: interview-seed-audit
seed: 2026-09-05-spec-review-two-stage-redesign-interview.md
---

# Audit — spec review 2단계 재설계 (Phase 0)

## 1. 원문

### 라운드 0 — `/request-framing` 인자 (2026-09-05)

spec-distill의 spec review 파이프라인과 spec-reviewer persona를 재설계해줘 request frame-interview-brainstorming-writeplan-구현으로 이어지는 큰그림에서 spec리뷰가 해야하는 역할에 맞게 하고 있는지 봐야 해
스펙 리뷰어가 근본적 해결 제안(다만 혼자결정 해선 절대안됨), 논리적으로 내용을 보는거 큰그림 관점의 리뷰(devbrew 내 플러그인 중 그런게 있음 이러한 리뷰 방식도 통일되면 좋을듯함)
그리고 리뷰어 발견이후 고치는거도 잘 고민해서 고쳤으면 함 바로바로 고치는게 아니라, 스킬에 언급하면 되려나 그리고 writing-plans가 도출·관측할 일은 그쪽으로 넘겨야함 스펙은 스펙의 역할에 충실하게 가야함
리뷰는 두 단계로 구성해. 먼저 사용자 목표와 문제 정의, 전체 범위, 핵심 아키텍처, 컴포넌트 관계와 데이터 흐름, 주요 trade-off, 구현 가능성 등이 하나의 그림으로 정합한지 검토해. 그다음 누락·모호성·Acceptance Criteria·검증·handoff 등 상세 완결성을 확인해. 세부 항목이 완전해도 전체 방향이 잘못됐으면 승인하지 않아야 한다.(이 방식은 내 의견이고 더 좋은 방안이나 형태가 있으면 제안해줘 반드시)
Reviewer finding을 반영하면서 목표·범위·제약·Non-goal·아키텍처·trade-off·Acceptance Criteria가 바뀌거나 새로운 요구사항이 추가된다면, 수정 전에 변경 내용과 근거·대안·영향을 사용자에게 보고하고 결정받아. 모델들이 임의로 정한 사항이나 reviewer 사이에 합의되지 않은 방향도 같은 방식으로 처리해. 모델끼리 억지로 합의시키지 말고 최종 방향의 소유자인 사용자에게 올려.
단순한 수정 → 재리뷰 반복으로 회귀가 발생하지 않도록 방안을 수립해

### 라운드 1 답 — 사용자 원문 (2026-09-05)

1. 둘다 맞는데 이번에 근본부터 재구성하여 shared로 공통되는 부분은 통합관리하고 특화 지점에서 분화되면 좋겠어
2. 2 다만 인터뷰에서 근거를 더 모아보자
3. 1
4. 3
5. 2, 라운드 마다
6. 1
7. 이거는 superpowers의 spec과 plan에 대해서 더 이해해야겠다 그뒤에 결정하자
8. 포함, 둘다인데 구조를 만드는건 좋은데 너무 무거운 하니스는 버그나거나 억제가 심해지거나 다른 방향으로 동작하더라고 그건 지양

### 라운드 2 답 — 사용자 원문 (2026-09-05)

9 2, 리뷰 후 라운드마다 자동 커밋하는 자율 루프 이거 마음에 들지 않아, 근본적으로 다시 구성하고 기존 구현에 끌려다니지 말자 design doc · brief ·  artifact · doc 을 리뷰하는 관점에서 통합되는 부분이 있다고 생각해, 물론 특화되는 부분은 반드시 특화 시켜야겠지
10 이거는 아니야
11 재리뷰 상한 5회, codex 병렬 co-review, 문서 발견용 Stop 훅, /compact proceed 게이트

### 라운드 3 답 — 사용자 원문 (2026-09-05)

아니다 이거도 같이 수정하자 그리고 자동 커밋 자율 루프 뿐만 아니라 다른것도 전부 포함해서 끌려가지 말고 완전 새로 구현이야 가장 적합한 형태로

### 게이트 라운드 1 답 — 사용자 (2026-09-05)

proceed 게이트: 「수정 필요」. Q10 해석: 「self-review 는 범위 밖」(확정). 추가 지시: 「워크트리 새로 만들어서 거기에서 진행하자 관련 자료도 옮기고」

### 게이트 라운드 2 답 — 사용자 (2026-09-05)

Q11 넷과 라운드 3 「전부」: 「넷은 그대로 둔다」. proceed 게이트: 「/compact 후 /interview <seed 전문>」(옵션 ①). 승인 시점 degrade 공시: 원장 부재(Phase 0 no-state) · 냉독 sonnet 대체(Fable 안전장치 오탐 2회) · critic 1차 출력 파손 후 재시도 · codex 정상 2/2 · 마지막 소폭 수정 4건 재검증 없음.

## 2. 라운드 기록

### 라운드 1 — 레포 읽기 결과와 질문 (2026-09-05)

읽은 것: `plugins/spec-distill/agents/spec-reviewer.md` · `skills/reviewing-spec/SKILL.md` · `references/proceed-gate.md` · `agents/brief-direction-reviewer.md` · `plugins/quality-gates/agents/artifact-critic.md`·`artifact-adversarial.md`·`skills/critiquing-artifacts/SKILL.md` · superpowers `brainstorming`·`writing-plans` SKILL · `docs/superpowers/specs/2026-09-02-adjudication-topology-design.md`(#138) · 메모리 `project_adjudication_topology_handoff`·`spec-reviewer-status-line-parse-fragility`.

관측:
- spec-reviewer 의 design-mode 체크리스트 7종(placeholder·ambiguity·scope_creep·approaches_comparison·isolation·testing·handoff_incomplete)은 전부 사용자가 말한 「2단계(상세 완결성)」다. 「1단계(하나의 그림으로 정합한가)」 카테고리는 없다. verdict `needs_interview` 만이 방향 문제에 가장 가깝고 정의는 「사용자 의도가 약하게 표현됨」.
- needs_revise 라우팅은 「메인 agent 가 design.md 직접 수정 후 재dispatch」 — 즉시 수정. P23 재결정 규약(v0.52 근처 추가)은 인터뷰 확정 항목을 겨냥한 finding 만 「조용히 덮어쓰지 않고 기록해 다음 라운드로」이고 사용자 결정은 Phase 5 게이트까지 미뤄진다.
- Claude·codex 두 verdict 는 merge_review.py 가 결정론 병합(combined_verdict, overturn advisory). 불일치가 사용자에게 「결정」으로 올라가는 경로 없음.
- 회귀 방지 장치는 stagnation(같은 issue 반복)과 cap 5 뿐. 「수정이 새 결함을 만들었다」를 잡는 장치 없음(메모리에 그 실측 여러 건).
- 「질문을 사용자에게 올리는 리뷰어」의 선례는 brief-direction-reviewer(finding 마다 question 필수, verdict 없음, C4). 논리·가정·근거를 보는 rubric 선례는 quality-gates artifact-critic(logic/assumption/completeness/evidence/ambiguity/actionability/structure) + artifact-adversarial(confirm/downgrade/reject).
- writing-plans 가 소유하는 것: 파일 구조·태스크 분해·인터페이스 시그니처·테스트 코드·커밋 단위. spec-reviewer 의 `isolation`·`testing`·handoff 의 「Deferred to plan」이 그 경계에 걸쳐 있다.

질문 Q1~Q8 은 세션 메시지 본문과 동일.

### 라운드 2 — 라운드 1 답의 해석과 남은 질문

- Q1 → 참조는 brief-direction-reviewer 와 artifact-critic/adversarial 둘 다. 방향은 「근본부터 재구성, 공통은 shared 로 통합관리, 특화 지점에서 분화」.
- Q2 → 별개 리뷰어 분리(②)를 후보로 두되 인터뷰에서 근거를 더 모은 뒤 확정.
- Q3 → 1단계(방향) 실패는 사용자에게 직행. 저자 자동 수정 없음.
- Q4 → 리뷰어 표시와 메인 세션 판단 둘 다, 하나라도 표시면 올린다.
- Q5 → 방향 불일치만 사용자에게, 상세 불일치는 둘 다 유지. 시점은 라운드마다.
- Q6 → 막을 것은 「수정이 새 결함을 만든다」.
- Q7 → 미결. superpowers spec/plan 경계 이해 후 결정 — 인터뷰로 이월.
- Q8 → brief 리뷰·brainstorming self-review 포함. 산문+구조 둘 다이되 무거운 하니스 지양(버그·억제·엉뚱한 동작이 실측 이유).

### 라운드 3 — 범위 확정

- Q9/Q12 → 네 자리(design doc · brief · artifact · doc) 전부. quality-gates critique 의 자동 커밋 자율 루프를 포함해 기존 구현 어느 것에도 끌려가지 않고 완전히 새로, 가장 적합한 형태로 만든다.
- Q10 → brainstorming 의 self-review 는 범위 밖.
- Q11 → 유지: 재리뷰 상한 5회 · codex 병렬 co-review · 문서 발견용 Stop 훅 · `/compact` proceed 게이트.

### 압축 2차 — 억제 지적 반영 (2026-09-05, 워크트리 `document-review-redesign`)

적용: 「등」두 자리 복원 · 「계약으로」삭제 · 「열거가 아니라 축으로」삭제 · 두 층을 「내 안」문단으로 이동하고 「내가 정한 것」에는 처리 규칙만 · 진단 문단을 사용자 원문의 문제 지목 넷으로 축소(리포 관측 「스크립트가 합의시킨다」「재리뷰 지적 다수가 수정 결함」은 삭제, 인터뷰가 확인) · 기존 구현 사례 셋 삭제하고 자동 커밋 루프만 이름 · 자리 셋 + 관점 넷으로 정정(「일반 doc 리뷰」자리 삭제) · spec/plan 후보 셋 삭제 · 「첫 층에서만」→「방향에 관한 것만」 · 「통일이 따라온다」근거 삭제.
유지: self-review 범위 밖(사용자 확정) · 무거운 하니스 문장은 사용자 원문 어휘로 교체.
codex 1번(self-review 가 라운드 3 답과 배치)은 codex 가 라운드 3 답의 대상을 Q12 가 아니라 Q10 으로 오독한 것 — 사용자 확정으로 종결.

### 검증 2라운드 후 소폭 수정 (2026-09-05)

critic 재시도 지적 반영: 「대상은 셋」→「지금 보이는 자리는 셋」+ 네 종류↔세 자리 대응 미정 명시 · 「`shared/`」→「shared 로」 · 「리뷰어 셋」→「리뷰어들」 · 「집행은」→「결정 게이트는」. 이 네 수정은 재검증 없이 게이트에 올림(공시). Q11 넷과 라운드 3 「전부」의 관계는 사용자에게 질문.
codex 2라운드 4건 중 셋은 사용자 선택(Q4=③·Q5=②·Q6=①)이라 유지 — codex 번들에 질문 문면이 없어 근거를 못 본 것. critic 1차 출력 파손(도구 호출 흉내) → 재시도로 대체.

## 3. 긴 초안

### 무엇을 맡기는가

devbrew 에서 **문서를 리뷰하는 자리 넷** — brainstorming 이 낸 design doc(`reviewing-spec` + `spec-reviewer`), 인터뷰가 낸 brief(`reviewing-brief` + brief-critic · brief-direction-reviewer · brief-readback), 비-코드 산출물(`quality-gates` 의 `/qg critique` — artifact-critic · artifact-adversarial · 자동 커밋 루프), 그리고 일반 doc — 을 「문서를 리뷰한다」는 하나의 관점에서 **근본부터 다시 설계**한다. 공통되는 것은 `shared/` 에 계약으로 두어 통합 관리하고, 자리마다 특화되는 것은 반드시 특화한다. 기존 구현의 모양(체크리스트 7종, 결정론 병합기, 라운드별 자동 커밋 루프, 라우팅 표)에 끌려가지 않는다. 가장 적합한 형태로 완전히 새로 만든다.

### 왜 지금인가 — 관측된 결함

1. **리뷰의 내용이 한 층뿐이다.** spec-reviewer 의 카테고리 전부(placeholder·ambiguity·scope_creep·approaches_comparison·isolation·testing·handoff)가 「상세 완결성」이다. 「사용자 목표·문제 정의·범위·아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성이 하나의 그림으로 정합한가」를 보는 층이 없다. 세부가 완전하면 방향이 틀려도 approved 가 나온다.
2. **발견 즉시 저자가 고친다.** needs_revise 라우팅이 「메인 세션이 design.md 직접 수정 후 재dispatch」다. 목표·범위·제약·Non-goal·아키텍처·trade-off·AC 가 바뀌거나 새 요구가 들어와도 사용자 결정 없이 문서가 바뀐다. 재결정 규약은 인터뷰 확정 항목만 기록해 두고, 사용자에게 올라가는 시점은 마지막 게이트다.
3. **리뷰어 불일치를 기계가 합의시킨다.** Claude 와 codex 의 verdict 를 merge_review 가 결정론으로 병합한다. 모델 사이에 합의되지 않은 방향이 advisory 한 줄로 흡수되고 최종 방향의 소유자인 사용자에게 「결정」으로 오지 않는다.
4. **수정이 만드는 새 결함을 못 본다.** 장치는 「같은 issue 반복」감지와 상한 5회뿐. 실측으로 재리뷰 지적의 다수가 직전 수정 자체의 결함이었던 사이클이 여럿 있다.
5. **파이프라인 관계에서 spec 의 역할이 흐리다.** writing-plans 가 도출·관측할 것(파일 구조·인터페이스·테스트 코드·태스크)이 spec 리뷰 요구에 섞여 있다. spec 은 spec 의 역할에 충실해야 한다.

### 사용자가 정한 방향

- 리뷰는 두 층이다. **1층**: 목표·문제 정의·범위·핵심 아키텍처·컴포넌트 관계·데이터 흐름·주요 trade-off·구현 가능성이 하나의 그림으로 정합한가. **2층**: 누락·모호성·AC·검증·handoff 의 상세 완결성. 2층이 완전해도 1층이 틀리면 승인하지 않는다. (사용자 자신의 안이며 더 나은 형태가 있으면 반드시 제안하라고 했다.)
- **1층 실패는 사용자에게 직행**한다. 저자가 자동으로 고치지 않는다.
- 리뷰어는 **근본적 해결을 제안**하되 **혼자 결정하지 않는다**.
- finding 을 반영하다가 목표·범위·제약·Non-goal·아키텍처·trade-off·AC 가 바뀌거나 새 요구가 추가되면 **수정 전에** 변경 내용·근거·대안·영향을 보고하고 사용자가 결정한다. 모델이 임의로 정한 것, 리뷰어 사이에 합의 안 된 방향도 같다. 모델끼리 억지로 합의시키지 않는다.
- 「바로 고칠 것」과 「올릴 것」의 분류는 **리뷰어 표시와 수정하는 세션의 판단 둘 다**를 쓰고, **하나라도** 올리라고 하면 올린다.
- 리뷰어 불일치는 **1층(방향) 불일치만** 사용자에게, 2층 불일치는 둘 다 유지. 올리는 시점은 **라운드마다**.
- 막을 회귀는 **「수정이 새 결함을 만든다」**.
- 참조 선례 둘 다 인정: brief-direction-reviewer(finding 마다 사용자 질문 필수, verdict 없음) · artifact-critic + artifact-adversarial(논리 rubric + confirm/downgrade/reject). 하지만 이번엔 참조하되 끌려가지 않는다.
- 형태 후보: 1층과 2층을 **별개 리뷰어**로 분리하고 1층 리뷰어는 verdict 없이 질문만 낸다(brief 파이프라인의 축 분리와 같은 모양이라 통일이 자연히 따라온다). **인터뷰에서 근거를 더 모은 뒤 확정.**
- 집행은 **산문과 구조 둘 다**. 다만 **무거운 하니스는 지양** — 실측상 버그가 나거나 억제가 심해지거나 엉뚱한 방향으로 동작했다.

### 유지하는 것

재리뷰 상한 5회 · codex 병렬 co-review · 문서 발견용 Stop 훅 · `/compact` proceed 게이트.

### 범위 밖

superpowers brainstorming 의 자체 self-review 단계.

### 인터뷰로 넘기는 것

- spec 과 plan 의 경계 — superpowers 의 spec 과 plan 이 각각 무엇을 소유하는지 이해한 뒤 결정. 후보: 파일 목록, 자동 검증 명령, 컴포넌트의 단위 테스트 가능성.
- 두 층의 형태 확정(한 리뷰어 순차 / 별개 리뷰어 / 라벨+라우팅).
- 「수정이 새 결함을 만든다」를 잡는 장치의 형태(예: 라운드 간 diff 를 리뷰어에게, 확정 항목 원장).
- 네 자리에서 무엇이 공통이고 무엇이 특화인지의 도출 — 열거가 아니라 축으로.
- 네 자리 중 반드시 특화해야 하는 것들이 무엇인지 — 사용자는 「반드시」라고 했다.


## 4. 압축에서 떨어뜨린 것

- 결함 5건의 파일·심볼 위치(spec-reviewer 카테고리 표, reviewing-spec 라우팅 표, merge_review 병합 규칙, cap·stagnation 절) — 인터뷰가 레포를 읽으면 안다.
- 질문 라운드의 선택지 번호와 기각된 선택지(Q1~Q12 의 다른 옵션) — 결정만 남기고 과정은 뺐다.
- Law 2 도구 allowlist·kill switch·cost_class·처분 한 줄 — CLAUDE.md 상시 규칙.
- 참조 선례의 agent 파일명·rubric 항목 열거 — 이름만 남기고 내용은 인터뷰가 읽는다.
- 「인터뷰에서 정해야 할 것」의 후보 예시 일부(diff 전달, 확정 항목 원장) — 하류가 정할 실행 세부.

