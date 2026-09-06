---
type: interview-audit
payload: 2026-09-06-document-review-redesign-interview.md
created_at: 2026-09-06
session_id: b19db3df-cae2-4390-a610-ca3641e03595
source: spec-distill conducting-interview v0.53.1
---

# 문서 리뷰 재설계 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.
> 이 인터뷰의 입력은 Phase 0 seed `2026-09-05-spec-review-two-stage-redesign-interview.md` 이고 그 Phase 0 의 원문·라운드 기록은 같은 디렉토리의 `...interview.audit.md` 에 있다.

## 1. Coverage Ledger

- floor:root_problem — closed — R1 S2 사용자 선택 ①: 리뷰 산출물이 verdict 라 finding 수신자가 없어 전부 저자-수정 한 갈래로 흐른다. 재구성: 문서 리뷰의 산출물을 수신자가 붙은 결정 목록으로 바꾸는 것이 진짜 문제
- floor:landscape — closed — R2 web sweep 4회 + steelman·prober 가 가져온 것 — PaperJury(처분 3종·frozen claim spine·anchor-bounded edit) · Nine Judges(판정자 상관, 독립표 ~2) · iterative-refinement 정리(1회 이후 회귀 증가, 선택적 편집, 별모델 피드백) · Azure ADR(append-only·superseded·confidence) · Adversarial Review · Two Calls · Selection Bottleneck · Conventional Comments · Yes-if · Looping Is Not Reliability · inspection · automation bias
- floor:skepticism — closed — ST1(두 층 별개 리뷰어·1층 질문만) switched — S3 사용자 ① 전환. 의심 trigger 가 걸린 방향은 ST1 하나였고 사용자가 R9 에서 추가 의심 방향 없음(S10)
- floor:blind_spot — closed — BSP1 숨은 가정 8·실패 양식 8 을 R3 에 표면화, 사용자가 A8(어휘 공통/허용값 자리별)·A6(앵커 묶기+얼림) 위에서 S4·S5 결정. 나머지는 payload §5 위험으로 이월
- floor:open_questions — closed — S10 ① OQ1~OQ7 박제(물리 배치·후광 대응·락 이관·seed 자리 계약·결정 기록 위치·헤딩 없는 문서 앵커·codex 어휘 계약)
- derived:finding-taxonomy-routing — closed — verdict 대신 finding 종류×수신처 대응표, shared 1순위 후보; S4 ① 다섯 값 decide/fix/defer/ask/drop, 어휘 공통·자리별 허용값, decide 열림→승인 불가
- derived:target-typology-site-mapping — closed — design doc·brief·artifact·doc + 네 번째 자리(seed 리뷰)와 자리의 대응; S6 ① 엔진 하나 + 프로필 넷, doc=/qg critique generic 프로필, seed 자리 범위 안·배선 마지막
- derived:finding-identity-regression — closed — 회귀 탐지엔 라운드 간 finding 정체성 필요(artifact-critic 만 round-stable anchor); S5 ③ 앵커 묶기+얼림+헤딩 diff 자동 decide, 정체성=supersedes 지목+오케스트레이터 대조
- derived:independence-premise-and-model-diversity — closed — M2 오케스트레이터 재비판의 전제 오염(T1)+codex 단독 재비판 사망(T2); S8 ① 재비판은 올리기만, codex 갈리면 높은 쪽, 부재는 공시하되 막지 않음
- derived:shared-extraction-boundary — closed — 회계는 전부 .py 경유, 설치본에서 타 플러그인 스크립트 도달 불가; 개념 경계는 S6 으로 확정(shared=처분 어휘·라우팅·앵커/얼림·정체성·codex 호출·degrade 공시 / 프로필=정답 출처·허용값·순서·목적지), 물리 배치는 OQ1
- derived:spec-plan-boundary — closed — seed 명시 항목; S7 ① 스펙은 검증 가능성까지·plan 은 검증 절차부터, 스펙 안 plan 소유물은 defer, testing 카테고리 폐기
- derived:escalation-economy — closed — 라운드마다 escalate × 상한 5 × M3; S9 ① decide 는 결정 단위로 묶어 라운드마다, ask·defer 는 승인 게이트에서 한 번
- derived:migration-rollback-path — (미admit) coverage-mapper 제안 8 중 하나, OQ3 로 박제

## 2. Budget

- 질문 라운드: 9 (+ 방향성 재결정 1 + 사용자 추가 발화 2) · agent dispatch: 인터뷰 3 (coverage-mapper 1 · steelman-builder 1 · blind-spot-prober 1) + brief 리뷰 5 (direction 1 · critic 3 · readback 1) = 8 · web sweep: 직접 4 + WebFetch 4 · codex 실호출: 4 (방향성 1 · 충실도 3) — 전부 성공(codex_failed: false)

## 3. Steelman 원문

#### ST1 — 두 층을 별개 리뷰어로 나누고 1층은 질문만 내는 형태 vs 리뷰어 하나 + finding 단위 처분

> **의심 방향** — "리뷰를 두 층으로 나눈다: 1층은 사용자 목표·문제정의·범위·핵심 아키텍처·컴포넌트 관계·데이터 흐름·trade-off·구현 가능성이 하나의 그림으로 정합한지, 2층은 누락·모호성·AC·검증·handoff 등 상세 완결성. 후보 형태: 두 층을 별개 리뷰어(subagent)로 나누고, 1층 리뷰어는 verdict 없이 질문만 낸다. 2층은 verdict 를 낸다. 세부가 완전해도 방향이 틀렸으면 승인하지 않는다."
> **trigger** — (1) PaperJury 는 finding 을 층이 아니라 처분으로 라우팅 (2) Nine Judges: 판정자 상관 (3) 사용자 경량 제약 (4) 근본 원인=수신자 부재.
>
> **alternative_statement:** 리뷰어를 층으로 쪼개지 말고, 리뷰어 하나가 finding 마다 «처분»(user-decision / author-fix / plan-defer / drop)을 붙이고 오케스트레이터가 라우팅만 한다 — «방향이 틀렸다»는 별도 층이 아니라 `user-decision(blocking)` 이라는 처분값 하나이며, 그 값이 하나라도 남아 있으면 세부가 완전해도 승인되지 않는다.
>
> **strongest_case:**
> 1. 사용자가 이미 못 박은 근본 원인은 «finding 의 수신자가 없다»이다. 그 병에 맞는 약은 수신자 필드이지 리뷰어 분할이 아니다. 현재 `spec-reviewer` issue 스키마는 `category/target_section/severity/message` 뿐이고 «누가 받나»가 없다(plugins/spec-distill/agents/spec-reviewer.md:160) — 층을 둘로 나눠도 이 결손은 그대로 남는다. 반대로 레포 선례 둘은 이미 «처분값»으로 갈린다: brief-direction-reviewer 는 finding 마다 `question`(수신자=사용자, verdict 없음), artifact-critic 은 `proposed_fix`(수신자=저자). 둘의 차이는 층이 아니라 필드 하나다.
> 2. PaperJury 는 리뷰어 2~4명이 각각 «whole-paper inspection» 을 하고, 분리는 리뷰어가 아니라 라우팅에서 일어난다 — contestability 로 «minor → polish path / contestable major → due-process trial» 을 나누고 종착을 invalid-drop / valid-fixable / author-required 셋으로 둔다. «issue validity does not imply machine editability» 가 정확히 «세부가 완전해도 방향이 틀리면 승인 불가»를 처분값으로 표현한 것이다(라우팅 정확도 0.913, 3.08 라운드 수렴). 핵심 결론은 «load-bearing safety and completion logic should reside in deterministic orchestration rather than model discretion» — 리뷰어를 더 두는 것이 아니라 오케스트레이터가 라우팅을 쥔다.
> 3. 리뷰어 하나를 더 두는 것이 독립 판정을 더하지 않는다. Nine Judges: 9명이 실질 ~2표, «the best single judge matches or outperforms the full panel». Adversarial Review: 리뷰 역할 2개가 5-agent MARS 를 이긴다(87% vs 82%). Two Calls Beat Five Agents: 2-call 이 5-agent 파이프라인보다 정확하고 토큰 7.4× 절감. 1층/2층 리뷰어가 같은 Claude 이면 «층 분할»은 독립성이 아니라 dispatch·파싱·처분 회계 지점 하나를 더 추가할 뿐이고, 이는 사용자 제약(무거운 하니스 지양)과 이미 결정된 M4(재비판 subagent 가능하면 제거)·T4(12자리에 회계가 없다)에 정면으로 걸린다.
> 4. 실무 선례도 같은 축이다. Conventional Comments 는 리뷰어 한 명이 comment 마다 `(blocking)/(non-blocking)` 을 붙여 «누가 무엇을 해야 승인되나»를 표현하고, Squarespace 의 «Yes, if» 는 approve/reject verdict 를 버리고 «what it would take to approve it» 을 finding 단위로 적게 바꿔 저자가 막히지 않게 했다 — verdict 를 처분으로 대체한 것이지 리뷰어를 늘린 것이 아니다.
>
> **evidence:**
> - https://arxiv.org/abs/2606.16322 — PaperJury: 리뷰어는 whole-paper inspection, 분리는 contestability-based routing 에서. 종착은 invalid-drop / valid-fixable / author-required 셋. «issue validity does not imply machine editability». 안전·완료 로직은 model discretion 이 아닌 deterministic orchestration 에.
> - https://arxiv.org/html/2606.16322 — 리뷰어 수 [2,4] 기본 3, 각자 전체를 읽음(층 분할 아님). 라우팅 정확도 0.913, ESVR 0.025, 수렴 3.08±0.67 라운드. frozen claim spine 제거 시 ESVR 0.029→0.112 — 방향(claim-level commitment) 보호는 리뷰어가 아니라 spine+guard 로.
> - https://arxiv.org/abs/2605.29800 — Nine Judges, Two Effective Votes: LLM 판정자 9명의 실질 독립 표는 ~2, «the best single judge matches or outperforms the full panel», 병목은 «correlated judges, not the aggregation algorithm».
> - https://arxiv.org/html/2608.18167 — Adversarial Review: 리뷰 역할 2개(R,C)가 4개 리뷰 역할의 MARS 를 이김(87% vs 82%). 산출물을 freeze 한 채 review text 만 교환하고 그 다음 편집.
> - https://arxiv.org/html/2607.26922v1 — Two Calls Beat Five Agents: 2-call 이 5-agent 파이프라인보다 정확(+4.2%p)하고 토큰 7.4× 적음. JSON 강제 출력이 정확도를 45%까지 붕괴(plaintext 82%).
> - https://arxiv.org/html/2603.20324v1 — Selection Bottleneck: 다양성의 이득은 selector 품질에 종속. «selector design may offer larger quality gains than generator improvement».
> - https://conventionalcomments.org/ — comment 마다 label + decoration(blocking/non-blocking/if-minor).
> - https://engineering.squarespace.com/blog/2019/the-power-of-yes-if — approve/reject verdict 를 «what it would take to approve it» 으로 대체.
> - https://arxiv.org/pdf/2210.00443 — ReAct: 처분(actionable 여부)이 comment 속성이지 리뷰어 속성이 아니라는 전제.
>
> **weakness_of_current:** 원안의 «1층은 verdict 없이 질문만» 은 사실 처분값 `user-decision` 을 리뷰어 단위로 상수화한 것이다 — 그 리뷰어가 낸 것은 전부 사용자 결정, 2층이 낸 것은 전부 저자 수정. 그러면 (a) 1층이 «AC 가 목표와 안 맞는다»(상세이지만 방향 문제) 같은 교차 finding 을 낼 때 어느 층의 산출물로 세느냐가 즉시 모호해지고, (b) 두 리뷰어가 같은 Claude 라 Nine Judges 대로 독립 판정이 아니며, (c) dispatch 자리·sentinel 파싱·처분 회계 앵커·M2 오케스트레이터 재비판 지점이 하나씩 더 늘어 사용자 자신의 «무거운 하니스 지양» 과 M4 에 걸린다. 원안이 진짜로 지키려는 불변식 — «세부가 완전해도 방향이 틀리면 승인 불가» — 은 «`user-decision(blocking)` 처분이 하나라도 열려 있으면 approved 불가» 라는 라우터 규칙 한 줄로 동일하게 얻어지고, 이쪽은 PaperJury 가 말한 대로 model discretion 이 아니라 deterministic orchestration 에 놓인다. 원안이 그래도 유리한 지점 하나: 리뷰어 하나가 세부에 터널링해 방향을 놓칠 위험 — 그러나 이는 «방향 finding 을 먼저, 세부는 그 다음» 이라는 출력 순서 제약(PaperJury 의 whole-paper inspection)으로 같은 리뷰어 안에서 다룰 수 있고, 별도 subagent 가 필요한 이유는 되지 않는다.
>
> **confidence:** 0.72
>
> **게이트 판정(R2, S3)** — 사용자 ① 전환 → verdict: switched.

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-06, 1회차) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-06, missing 0 · not_contained 0)
- check_brief.py gate — pass (2026-09-06, 2회차 — 방향성 재결정 반영 후; 1차 시도는 frontmatter 미치환으로 bijection B red → 수정 후 pass) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-06, 2회차, S11 포함)
- check_brief.py gate — pass (2026-09-06, 3회차~6회차: 충실도 수정 R1·S12·S13·충실도 수정 R2·상한 후 편집 뒤 각각 재실행, 전부 pass) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-06, 3회차~6회차, S12·S13 포함, missing 0 · not_contained 0)
- check_brief.py gate — pass (2026-09-06, 7회차 — 확정 반영 후, confirmed 29·sentinel 제거) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-06, 7회차, S14 포함)

## 5. 프로세스 로그

- round 0: seed 수신 — Phase 0 interview-seed 전문을 S1 로. state 초기화(coverage/orchestration 스키마).
- round 1: (d) ontological ROOT_CAUSE — 옵션 ①verdict 산출물 ②상세만 보는 persona ③수정 세션 제동 없음 ④spec 정의 부재 ⑤복수/기타. 추천 ①. 답 ①(S2). auto-confirmed: superpowers spec/plan 소유 경계 · 세 자리 현재 모양 표 · 판정 지형 M1~M4 존재.
- round 2 prep: (a) web sweep 4회 + WebFetch 4 · coverage-mapper #1(episode 0, 제안 8 → admit 6, 2개 합침, migration 은 OQ) · steelman-builder ST1 dispatch. non_user_streak 1.
- round 2: (b) judgment — ST1 verbatim 제시 후 P17 게이트 ①전환 ②방어 ③보류 ④기타. 추천 ①. 답 ①(S3) → switched. landscape closed.
- round 3: (b) judgment — 처분 집합 ①다섯 값 ②셋 ③두 축의 곱 ④기타. blind-spot-prober BSP1 도착 → 답 전에 표면화(A1·A8·F1·F2·A5/F3·A6/F4·F7·F8). 판단 변화: A1→seed 이중 처분 유지, A8→어휘 공통/허용값 자리별, A6→회귀 장치 후보=앵커 묶기+얼림, F2 약화(Deferred to plan 소절 실재). 답 ①(S4).
- round 4: (b) judgment — 회귀 장치 ①리뷰어 눈만 ②범위만 묶기 ③앵커+얼림+자동 decide ④커밋 기준선 핀 ⑤기타. 추천 ③. 답 ③(S5). blind_spot closed.
- round 5: (b) judgment — 대상↔자리 ①엔진1+프로필4 ②프로필3(seed 제외) ③자리3 유지+스크립트만 공통 ④기타. auto-confirmed: framing-requests 의 seed-critic/seed-readback = 네 번째 자리, /qg critique 대상 정의에 doc 포함. 답 ①(S6). shared 개념 경계 closed, 물리 배치는 OQ1.
- round 6: (b) judgment — spec/plan 경계 ①검증가능성/검증절차 ②현행 ③금지+fix ④기타. 답 ①(S7).
- round 7: (b) judgment — 오케스트레이터 재비판 권한 ①올리기만 ②올리기+명시적 기각 ③재비판 없음(M2 뒤집음) ④기타. 답 ①(S8).
- round 8: (b) judgment — escalation 경제 ①결정 단위 묶음+처분별 시점 ②전부 라운드마다 ③decide 모아서(재결정) ④기타. 답 ①(S9).
- round 9: (b) judgment — OQ1~OQ7 박제 + skepticism 마감 ①그대로 ②추가/삭제 ③의심 방향 하나 더. 답 ①(S10). floor 5 closed → finishing.
- degrade(인터뷰 단계): 없음 — 세 dispatch 모두 정상 반환, web 활성.

### blind-spot premortem 원문 (BSP1, round 3)

#### BSP1 — blind-spot-prober 출력 (verbatim, R3)

hidden_assumptions:
- A1 "처분은 finding 의 속성 — 리뷰어가 '누가 받을지'를 정확히 판정할 수 있다." 위험: 처분=결함 원인이 어느 층에 있나에 대한 판단인데 저자·사용자만 아는 맥락에 의존. Fagan inspection 이 발견과 처리를 분리한 이유. 방향 결함이 저자수정으로 오라벨 → 근본원인이 라벨만 바꿔 재생산; 반대로 사용자결정 과라벨은 M3 충돌. 근거: https://en.wikipedia.org/wiki/Software_inspection · https://userweb.cs.txstate.edu/~rp31/slidesSQ/03-Inspections&Cleanroom.pdf
- A2 "사용자 결정 처분 열림→승인 불가가 사람 결정의 질을 보장." 위험: 보장하는 건 클릭 사실뿐. 오케스트레이터가 요약·추천을 붙이면 automation bias(82%→45%), 라운드마다 escalate 쌓이면 클릭으로 gate 여는 법을 학습. 근거: https://hdsr.mitpress.mit.edu/pub/nrcn4h7d/release/2 · https://www.techtarget.com/it-strategy/feature/Human-in-the-loop-shouldnt-rubber-stamp-decisions · https://hackernoon.com/the-oversight-fatigue-problem-why-hitl-breaks-down-at-scale-and-what-comes-after
- A3 "codex 별모델 co-review 가 독립성을 맡는다." 위험: (1) codex 재비판은 외부 계정 상태의 함수(handoff §2), 종속을 설계로 못 박음(T2). (2) 별가족도 같은 문서·프롬프트·프레이밍이면 공유전제로 상관 증가 — "model-family diversity does not ensure independence". 근거: https://arxiv.org/html/2607.24604 · https://arxiv.org/pdf/2508.06709 · https://orq.ai/blog/llm-juries-in-practice
- A4 "방향/상세 구분이 리뷰어 출력에서 안정적으로 갈린다." 위험: 같은 문장이 고치면 무엇이 바뀌나에 따라 방향/상세. 두 리뷰어가 라벨 자체에서 불일치하면 규칙 미정의; '하나라도 올리면 올림'이 메우지만 escalate 수가 보수적 쪽에 수렴. 처분 어휘 커지면 drift 표면 커짐(merge_review.py:42·223 off-vocab fail-closed). 근거: https://arxiv.org/pdf/2606.04223 · https://link.springer.com/article/10.1007/s10515-026-00638-5
- A5 "finding 이 라운드를 넘어 같은 finding 으로 인식된다." 위험: 현재 id=(category,target_section) 해시(merge_review.py:361·374) — 기각된 finding 이 다른 이름으로 부활, 새 회귀 finding 이 옛 id 에 흡수돼 소실. 회귀 장치는 정체성 문제를 먼저 풀어야. 근거: https://arxiv.org/html/2607.24604 ("stale evidence resurrects bugs")
- A6 "회귀 원인은 즉흥 수정이라는 행위이고 수신자를 나누면 준다." 위험: 회귀는 정답 상태가 non-absorbing 이라 다음 revision 이 지우는 데서 옴(82%→67.3%, 16% 궤적 정답 소실). 라우팅은 revision 의 출처를 바꾸지 횟수·범위를 안 줄임. 처방: last-known-good 핀 + 수정 범위 제한(Keep/Patch/Escalate 타입 계약) + 근거 신선도. 근거: https://arxiv.org/html/2607.24604 · https://docs.aws.amazon.com/prescriptive-guidance/latest/agentic-ai-patterns/evaluator-reflect-refine-loop-patterns.html
- A7 "강제 합의 금지면 sycophancy 를 피한다." 위험: 합쳐지는 지점(오케스트레이터)에서 결정은 한 번 남; consensus collapse 는 접는 주체가 누구든 발생. M1+M2 로 오케스트레이터가 반대의견이 가장 조용히 사라지는 자리. '둘 다 유지된 것을 어느 쪽으로 라우팅하나' 미정의. 근거: https://arxiv.org/html/2509.05396v1 · https://arxiv.org/pdf/2605.00914
- A8 "네 자리가 같은 문제를 공유하므로 하나의 공통 설계로 덮인다." 위험: 저자가 다르다(spec=사용자+brainstorming, brief=인터뷰 세션, seed=framing, qg=임의). readback 류는 충실도 리뷰라 처분이 원리적으로 '사용자 결정' 하나뿐 — 처분 집합이 공통이라는 전제가 깨짐; 처분 집합이야말로 자리마다 다를 수 있음. 근거: https://docs.plannotator.ai/compare/prd-vs-technical-specification-vs-implementation-plan

failure_modes:
- F1 처분 인플레이션 — 불확실하면 '사용자 결정' default, 라운드마다 5~10건 클릭, 결정 질 0 수렴. trigger: 산문 기준 + 가장 안전한 라벨 + 라운드마다 escalate. 근거: uptimelabs incident-escalation · johal.in alert-fatigue · hackernoon oversight-fatigue
- F2 plan 이월이 결함 매립지 — writing-plans(superpowers, 범위 밖) 가 이월을 읽을 계약이 없어 소실; spec approved 인데 미결 안고 구현. trigger: spec/plan 경계 미결인 채 '이월' 값 먼저 확정; reviewing-spec→writing-plans 는 호출만, payload 채널 없음(SKILL.md:151, 209-226). 근거: https://arxiv.org/html/2606.27045 · https://github.com/github/spec-kit/blob/main/spec-driven.md
- F3 처분 부활/흡수 — 기각 finding 이 다른 카테고리로 재등장, 새 회귀가 옛 id 로 충돌해 '처리됨' 흡수. trigger: (category,target_section) 해시 원장 재사용 또는 자유텍스트 key.
- F4 정답 파괴 회귀가 라우팅을 통과 — fix 3건 고치는 한 revision 이 approved 급 섹션(Non-goals·AC) 을 건드려 방향을 바꾸는데 어떤 finding 에도 속하지 않아 처분 없음. trigger: 회귀 장치 부재 + 수정 범위 finding 단위 제한 부재.
- F5 오케스트레이터 재비판이 '둘 다 유지'를 한쪽으로 접음 — 저자에게 넘길 때 하나의 지시로 접혀 반대의견 소실(T1). trigger: M1+M2 + 버린 것 계수 회계 부재(T4). 근거: https://arxiv.org/html/2509.05396v1 · https://arxiv.org/pdf/2604.07667
- F6 codex 부재 시 독립성 0 이 설계상 정상 — 단일 Claude 리뷰어 + 같은 가족 재비판만 남고 degrade 공시는 나가나 M3 로 줄어든 사람만 읽음. trigger: blocks() 가 '보조 손실은 공시하되 막지 않음'(adjudication.py:124-129) 을 그대로 두면 독립성 0 이 gate 를 안 막음. 근거: https://arxiv.org/html/2607.24604 · https://towardsdatascience.com/the-llm-judge-that-kept-agreeing-with-itself/
- F7 두 층을 출력 순서로 구현하면 상세가 큰 그림을 오염 — 한 패스에서 후광 판정(상세 나쁨→방향 나쁨), overcorrection 과 결합해 방향 escalate 가 상세 노이즈로 촉발. trigger: 순서는 출력의 순서지 판단의 독립이 아님. 근거: springer s10515-026-00638-5 · https://arxiv.org/html/2508.12358v1
- F8 '완전 새로'가 기존 락의 트리거를 지움 — 재리뷰 상한 5·issue_history·stagnation(raised_count>=3 AND dismissed_by_user==0) 이 merge_review.py + 8개 파생 위치 cross-file 락(test_rereview_cap_consistency.sh:21-25). 처분 모델로 대체하면 dismissed_by_user 의미가 옮겨가 stagnation 이 조용히 inconclusive. trigger: '완전 새로' + '상한 5 유지' 동시 요구 — 상한은 유지되나 카운터가 무엇을 세는지 바뀜.

confidence: 0.72 — A1·A6·A5 강함(외부+리포 코드), A8·F7 약함(추론). 방향 바꾸라는 것이 아니라 '회귀 탐지 장치'와 '처분 집합 값'이 확정 방향보다 먼저 답해져야 할 가능성. 결정은 사용자.


### 방향성 라운드 원문 (Claude brief-direction-reviewer, 2026-09-06)

### 방향성 리뷰 — Claude brief-direction-reviewer (verbatim 요지, 2026-09-06)

- D1 — overturn: brief 가 「재논증 대상 아님」으로 딛고 선 M2·M4 는 사용자가 2026-09-02 인터뷰에서 이미 뒤집었다 — D7 과 §5 「재비판 subagent 유지 기각」은 뒤집힌 결정 위에 서 있다. evidence: 2026-09-02-adjudication-topology-interview.md:159 (C3 confirmed: ①③ 유지 + 「1차 재비판을 오케스트레이터가」「재비판 서브에이전트 제거」 뒤집음, 축을 「프레이밍을 보느냐」로), audit:163-164 (S5 「(C) 부분 전환」), interview:180-181 (탐지만 옮기고 처분은 그대로), specs/2026-09-02-…-design.md:383-384 (#138 이 C3 역할 재배치·C5 역할 축을 OQ11~OQ19 미해소로 다음 사이클로 미룸), 이 brief :113,122,158,189, Phase 0 audit :52 (09-02 interview brief 미독), 08-27 handoff 에 superseded 표기 없음. question: M2·M4 에 대해 어느 것이 현행인가 — 08-27 M2·M4 인가 09-02 C3 인가?
- D2 — overturn: 「셋 다 올리기만」+ 재비판 subagent 제거는 리뷰어 오탐을 기각할 기계 경로를 0 으로 만든다 — 오탐 fix 는 사용자 눈 없이 저자가 적용. evidence: artifact-adversarial.md:20-26 (오탐 게이트 load-bearing), critiquing-artifacts SKILL:186-193,220-222, brief :29,84,154, adjudication.py:53-55 (reject 술어의 생산자 소실), PaperJury invalid-drop 은 기계(due-process trial)가 낸다. question: 오탐 기각은 누가 어디서 — (a) 사용자만 (b) 독립 재비판자가 근거 인용으로 reject(Ledger 계수) (c) 저자 이의 → 자동 decide?
- D3 — overturn: 「codex 와 갈리면 높은 쪽」「상향만」은 다섯 값에 전순서가 있어야 성립하는데 D3 는 두 축을 접은 것이라 fix/defer, ask/defer 에 높낮이가 없다. evidence: brief :179,:84,:154; Conventional Comments 는 label 과 decoration 을 분리; brief :196 자기 위험. question: 순서 있는 값 하나(전순서 명시)인가, receiver×blocking 두 필드(단조 규칙은 blocking 과 author→user 승격에만)인가?
- D4 — overturn: 얼림 키가 「finding 없던 섹션」인데 C2 가 보호하는 것은 내용 부류 — AC 섹션에 fix 하나면 녹아 저자가 AC 를 바꾸는 경로가 열린다. evidence: brief :19,:69,:156; PaperJury frozen spine 은 claim-level; spec-kit analyze 는 constitution 을 non-negotiable. question: 얼림 키 — (a) finding 없음 (b) C2 보호 부류(항상 decide) (c) 합집합?
- D5 — overturn: 완결성 finding 의 수정은 새 헤딩 추가인데 앵커는 기존 섹션이라 요구된 섹션을 만드는 순간 자동 decide. evidence: spec-reviewer.md:64,87,93 (handoff_incomplete 섹션 부재), artifact-critic.md:41, brief :69,:167; PaperJury anchor 도 신규 삽입을 명시 허용 안 함. question: 앵커를 기존 헤딩으로 둘지 finding 이 선언한 편집 범위(insert-after)로 둘지?
- D6 — overturn: §5 가 LKG 핀을 자율 커밋 루프와 묶어 기각했지만 seed 가 폐기한 것은 자율 커밋뿐이고 헤딩 diff 는 기준선 없이 정의되지 않는다. evidence: brief :188,:213; Looping Is Not Reliability 의 핀은 원장(해시); critiquing-artifacts :78-87,248-256 현행 기준선=HEAD clean+라운드 커밋; OQ 에 기준선 위치 없음. question: 기준선 — (a) 세션 state 스냅샷+해시 (b) 마지막 커밋 (c) 라운드 진입 강제 커밋? §5 문장을 「자율 커밋 기각, LKG 핀 채택」으로?
- D7 — overturn: D6(testing 폐기·Files to Modify/Verification Plan=plan 의 일)는 CLAUDE.md Law 1 필수 섹션 목록과 superpowers brainstorming 의 testing 커버 요구와 충돌 — Law 1 문면을 같이 바꿔야. evidence: CLAUDE.md Law 1; brainstorming SKILL:186; writing-plans:10,145; brief :148 vs :79; parse_spec_structure.py:29-30, spec-template.md:57,63. question: Law 1 목록을 함께 개정하는가, 아니면 testing 을 「검증 전략 부재」로 재정의하고 절차·명령만 defer?
- D8 — overturn: brief·seed 프로필 허용값을 decide·drop 으로 제한하면 충실도 왜곡 하나하나가 사용자 결정 — 현행은 저자가 닫힌 권한 안에서 고치고 fresh critic 재검; M3 충돌; decide 인플레이션 최대 공급원. evidence: brief :156; reviewing-brief SKILL:135-146,331-333,429; handoff :136-140; brief :191. question: 「정답이 사용자 원문」에서 도출되는 것은 fix 금지인가 fix 앵커를 §2/§0 으로 묶고 §6 불변인가?
- D9 — overturn: T2 가 요구한 「재비판 제거 가능/불가 판별 기준」이 brief 에 없다 — D2+D7+codex 부재=독립 판정 0 을 공시로만; 리포 기록은 2차 판정자 단독 적발 사례 반복; 09-02 OQ13(독립 병렬 앙상블) 미검토; Nine Judges 의 과업은 점수 판정이지 인용 근거 기각 2차 패스가 아님. evidence: handoff :166-176; 09-02 interview :219-221; archive 사례; adjudication.py:124-133 blocks(); seam handoff :330-336 T5. question: codex 부재 라운드에 — (a) 공시만 (b) fix 자동 적용 않고 decide/ask 승격(blocks 재정의) (c) 별가족 없을 때 Claude 재비판 subagent 되살리는 판별 기준? D2 의 「하나」는 OQ13 검토 후인가?
- D10 — overturn: 사용자 문제는 「바로바로 고쳐서 잘 고민 못 함」인데 D4 는 어디를 고치는지만 제한, 고치기 전에 무엇을 할지 없음 — Adversarial Review 의 propose-before-apply 미흡수. evidence: brief :215,:118; Adversarial Review inner loop=review text only; Looping RevisionAction Keep|Patch|Escalate; reviewing-spec SKILL:152,227 현행 직접 수정. question: fix 에 「적용 전 제안」 단계(패치 의도 → 앵커·보호 부류 판정 → 적용)를 둘 것인가?

우선순위: D1. Sources: PaperJury abs/html, Nine Judges, Looping Is Not Reliability, Adversarial Review, Conventional Comments, Google eng-practices comments, spec-kit analyze, Let Me Speak Freely (arXiv 2408.02442).

#### codex 방향성 co-review (3건, codex_failed: false)

- codex 1 — high — D4 의 헤딩 단위 얼림만으로는 허용 섹션 내부의 결정 변경을 보호하지 못한다(예: NFC→NFKC 같은 설계 결정이 설명 수정과 같은 문단에). 대안: 보호할 결정·주장 + 적용 전 patch 검사(PaperJury §3.4). 질문: 회귀 방지 기준을 헤딩 경계에서 보호 결정과 적용 전 검사로 바꾸겠는가? → 사용자 D3·G1 로 채택
- codex 2 — high — D7 의 상향 전용 재비판은 객관적으로 반증된 fix 를 편집 전에 종결할 경로를 제거(현행 artifact-adversarial reject + synthesize 제외 소실). 대안: PaperJury invalid-drop, Google pushback 절차. 질문: 오탐 fix 는 편집 전 재검증으로 drop 가능하게 D7 을 완화하겠는가? → 사용자 B2 로 채택
- codex 3 — medium — D3·D8 이 질문과 승인 차단을 결합해 수정의 전제인 확인 질문까지 게이트로 늦춘다. 대안: Conventional Comments 의 question/blocking 분리, spec-kit clarify. 질문: fix 의 전제인 ask 는 수정 전에 확인하고 비차단 질문만 게이트에 모으겠는가? → 사용자 K1 로 채택

#### 사용자 결정 대응표 (S11 「전부 추천대로」)

A1 09-02 C3 현행 · B2 독립 재비판자 reject(회계 계수) · C1 전순서 decide>ask>fix>defer>drop · D3 얼림 키 합집합 · E2 finding 이 편집 범위 선언 · F1 세션 state 스냅샷+해시 기준선 · G1 적용 전 제안 · H2 testing 재정의·Law 1 불변 · I2 brief/seed 프로필 fix 허용하되 앵커를 §0/§2 로 묶고 §6 은 불변, decide 는 원문 자체가 모호할 때만 · J1 codex 부재 공시만(A1 전제) · K1 fix 전제 ask 는 라운드 묶음에 비차단

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

- 방향성: Claude 10건(D1~D10) / codex 3건 — 겹침 3(얼림 키 · 적용 전 제안 · 오탐 기각) — 사용자 재결정 11건(A~K, S11 「전부 추천대로」). 반영: D2·D6·D7 재서술, D10~D16 추가, §5 기각 5건 추가(원래/재결정/근거), §3 OQ8~OQ10 추가. 미반영 findings: 없음(전부 반영 또는 OQ 로 박제 — Claude D9 의 「병렬 N명」 반론은 OQ8)
- 충실도 기록(게이트 아님): round 1 needs_revise — critic 6건(provenance_mislabel high · evidence_unsupported high · omission · distortion 3) / codex 4건(omission high · provenance_mislabel · authority_syntax · evidence_unsupported high) — 회계 accepted 6 · 소실 0 · degrade 없음. 반영: D10~D16 chosen, C3·C8·D4 복원, D12 에 S5 재결정 명시, §3 OQ 재결정 표기, Non-goal 문구, §5 자율 루프 문구, 대응표 I2 보완. 부분 반영: S11 원문이 진술 내용을 안 담는다는 지적 — S11 본문은 §6 append-only 라 못 고치고 §2 ✎ 로 출처를 명시(Step B 상신). 재라운드 1/2 진입
- 충실도 기록 round 2(재리뷰 1/2, S12 이전 문서): needs_revise — critic 5건(evidence_unsupported high 1 · medium 2 · insertion · omission) / codex 2건(omission D2 두 층 내용 · evidence_unsupported S11). 반영: 채택 선택지 원문을 §2 ✎ 로 기록(§6 append-only 라 S11 아래엔 못 둠), D7→S8 원문 복원·재비판자 기각은 D10 으로, C9(선례 참고)·C10(두 층 내용) 복원, Non-goal 괄호절 제거, §7 에 C9 반영. 이 사이 사용자 S12·S13(재리뷰 상한 2 통일 + 필요시 제안 가능) 반영(D17). 재라운드 2/2 진입
- 충실도 기록 round 3(재리뷰 2/2 = 상한, S12·S13 포함 문서): needs_revise — critic 7건(evidence_unsupported high 1 · medium 1 · distortion · omission 2 · insertion 2) / codex 1건(D17 evidence S12+S13). **상한 도달 → forced escalate.** 마지막 리뷰 이후 편집(재리뷰 없음, Step B 공시): C3 「큰 그림 관점에서 … 저자가 고치지 않고」 복원 · C7·D4 statement 에 뒤집힘 표시 · D6→S7 / D18(S11) 분리 · D17→S12 / D19(S13) 분리 · §0·§5 도출 문장 ✎ 표기 · §3 OQ9·OQ10 출처를 ✎ 도출로 정정 · D7 주어 보정. 미해결(사용자 판정): D17 의 「리뷰 한도」가 재리뷰 횟수인지 총 리뷰 횟수인지
- 냉독: gap 2건 (G3 — C4 「리뷰어 표시+수정 세션 판단, 올리기만」 요약 부재 / G6 — D4 가 뒤집힌 내용을 싣고 있어 현행 혼동). 가독성(클래스 밖): M1~M4·T1·ST1·09-02 C3·회계·배선 식별자 미해설 → §0 에 ✎ 용어 한 줄, D4 에 「현행은 D12」 표시(마지막 리뷰 이후 편집)
- Step B: ① 확정하고 /compact 후 brainstorming (S14). D17 해석 = 재리뷰 상한 2회 확인. 29항목 전부 confirmed, sentinel 삭제
- degrade: critic:fidelity:degraded — 재리뷰 상한 2 도달, 미해결 findings 잔존(critic 7·codex 1); 상한 후 편집 9건 재리뷰 없음; D17 해석은 사용자 판정. 그 외 없음(codex 4/4 성공, direction 정상, readback 정상, verbatim_coverage 전 회차 exit 0)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

(`S1` 은 payload §6 에 있다 — Phase 0 seed 전문.)

- **S2** ☑ 선택 (① 근본 원인):
  > "1 — ① 산출물이 verdict 다: finding 의 수신자가 없어서 전부 저자 수정 한 갈래로 흐른다"
- **S3** ☑ 선택 (ST1 steelman 게이트):
  > "1 — ① 전환: 리뷰어 하나 + finding 단위 처분 + 오케스트레이터 라우팅. 두 층은 persona 의 검토·출력 순서로"
- **S4** ☑ 선택 (처분 집합):
  > "1 — ① 다섯 값 decide/fix/defer/ask/drop, 어휘는 공통·자리별로 낼 수 있는 값을 제한"
- **S5** ☑ 선택 (회귀 장치):
  > "3 — ③ 앵커 묶기 + 얼림 + 얼린 섹션 변경은 자동 decide, 결정론은 헤딩 diff 한 곳"
- **S6** ☑ 선택 (대상↔자리 대응):
  > "1 — ① 엔진 하나 + 프로필 넷, doc 은 /qg critique 프로필, seed 자리는 범위 안(프로필 정의, 배선은 마지막)"
- **S7** ☑ 선택 (spec/plan 경계):
  > "1 — ① 스펙은 검증 가능성까지, plan 은 검증 절차부터. 스펙 안의 plan 소유물은 defer 로 옮김, testing 카테고리 폐기"
- **S8** ☑ 선택 (오케스트레이터 재비판 권한):
  > "1 — ① 올리기만: 처분 상향·추가만 가능, 하향·삭제 불가. codex 와 갈리면 높은 쪽. codex 부재는 게이트 첫 줄 공시"
- **S9** ☑ 선택 (escalation 경제):
  > "1 — ① decide 는 결정 단위로 묶어 라운드마다, ask·defer 는 승인 게이트에서 한 번"
- **S10** ☑ 선택 (Open Questions 박제):
  > "1 — ① 이대로 박제하고 종료: OQ 일곱 개, skepticism 은 ST1 로 마감"
- **S11** 🗣 발화 (방향성 리뷰 A~K 재결정 — 추천 대응표는 §5 「사용자 결정 대응표」):
  > "전부 추천대로"
- **S12** 🗣 발화 (충실도 재리뷰 진행 중 사용자가 추가한 결정 — seed C7 의 「재리뷰 상한 5회」를 뒤집음):
  > "한가지 더 넣고 싶은건 리뷰 한도 2번으로 통일하자"
- **S13** 🗣 발화 (S12 의 단서 — 상한 도달 후 추가 라운드는 제안 가능):
  > "물론 반드시 필요한 경우는 제안할 수 있긴 하게 하고"
- **S14** ☑ 선택 (proceed 게이트 — 확정 + D17 해석 확인):
  > "확정하고 /compact 후 brainstorming (권장) — D17 의 뜻: 재리뷰 상한 2회 (권장)"

## 7. 확산 원자료

- «paperjury» — https://arxiv.org/abs/2606.16322 — PaperJury: 처분 3종 라우팅, frozen claim spine, anchor-bounded edit, deterministic orchestration
- «nine-judges» — https://arxiv.org/abs/2605.29800 — Nine Judges, Two Effective Votes: 판정자 상관, 독립표 ~2
- «looping-not-reliability» — https://arxiv.org/html/2607.24604 — Looping Is Not Reliability: non-absorbing 정답 상태, 정답 후 revision 16% 소실, Keep/Patch/Escalate 타입 계약, verifier 상관 모델링
- «iterative-refinement» — https://www.emergentmind.com/topics/iterative-refinement-with-self-feedback — 반복 정제 연구 정리: 1회 이후 회귀, 선택적 편집, 별모델 피드백
- «adversarial-review» — https://arxiv.org/html/2608.18167 — Adversarial Review: 역할 둘이 다섯 에이전트를 이김, 산출물 freeze 후 리뷰 텍스트만 교환
- «two-calls» — https://arxiv.org/html/2607.26922v1 — Two Calls Beat Five Agents: JSON 강제 출력의 정확도 붕괴
- «selection-bottleneck» — https://arxiv.org/html/2603.20324v1 — When Agents Disagree: selector 설계 우선
- «conventional-comments» — https://conventionalcomments.org/ — blocking/non-blocking 장식
- «yes-if» — https://engineering.squarespace.com/blog/2019/the-power-of-yes-if — verdict 를 조건부 처분으로
- «azure-adr» — https://learn.microsoft.com/en-ca/azure/well-architected/architect-role/architecture-decision-record — ADR append-only·superseded·confidence
- «software-inspection» — https://en.wikipedia.org/wiki/Software_inspection — 발견과 처리의 분리
- «automation-bias» — https://hdsr.mitpress.mit.edu/pub/nrcn4h7d/release/2 — 사람이 AI 추천을 승인하는 자리에서의 정확도 하락
