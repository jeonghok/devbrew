---
type: interview-audit
payload: 2026-09-05-steelman-goal-fit-interview.md
created_at: 2026-09-05
session_id: 1f5a8290-7b4b-454d-b493-438037a5123f
source: spec-distill conducting-interview v0.53.1
---

# steelman 목표 적합 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.
> 이 파일은 Phase 0(framing-requests)의 audit 을 이어받았다 — 그 세 절은 §7 뒤에 A·B·C 로 헤딩 이름만 바꿔 그대로 있다(본문 무변경).

## 1. Coverage Ledger

- floor:root_problem — closed — R1 확정 (round 1, S2): 본질=①기준 부재+②역할 편향, ③어휘는 파생. 문제정의·goal 은 transcript R1 참조
- floor:landscape — closed — R2 web sweep 4회 (round 2): Schweiger 1986 DI>DA / CFAR double crux / Khan 2024 debate>consultancy / Nemeth 2001 DA bolstering. 사용자에게 표로 제시, 취함·중립·경고 처분
- floor:skepticism — closed — ST1 게이트 (round 3, S4): 보완 — P0 명시 · dispatch payload 에 goal 리터럴 · 대안 케이스 먼저. premise_refutation hits=[] (반증 없음). repo_claims 7/7 orchestrator 사전 확인. 기계 어휘엔 defended 로 적고 보완은 산문
- floor:blind_spot — closed — prober 1회 (HA6·FM6). round 5 표면화: S7 HA1 수용(표본 9건은 정당한 재검토 사유) · S8 FM3 → premise_refutation 뒤로(seed 재결정) · FM1/FM4/FM5 orchestrator 정함(취함·버림 구절 / 제약 원문 인용 / 확인 결과 ST 블록+반증 라벨). 잔여 HA2·3·4·6·FM6 → §5 위험·§3 OQ
- floor:open_questions — closed — S13 (round 6): OQ 6건 이대로 박제 — 프레임 공유·sycophancy / 전제 도출 오류율 / 순서 효과 외삽 / 결과를 치는 반증의 흡수 / sentinel 형식주의 / 스니펫 확인 5건
- derived:premise_contract — closed — 핵심 전제의 추출·확정·전달 계약 + 전제 부착 자칭 검증 + 전제에 닿지 않는 근거의 처분 회계 (mapper #2+#6 병합); S3 도출+게이트 노출 / S5 양성 hits 만 orchestrator 게이트 전 확인 / S6 비부착 근거 = 노출+audit 보존+§5 계수, 회계상 흡수
- derived:evidence_citation — closed — builder 리포 주장 인용 형식 · N1a URL 거처 · 게이트 전 확인의 실체 (mapper #3); S10: 경로+앵커(심볼·헤딩·원문 인용) 필수, 줄번호 보조 — seed file:line 재결정(근거 cb0b4dd). 확인 결과는 audit §3 ST 블록 내 주장별, 반증은 4-block 라벨(round 5 정함)
- derived:recommend_vs_p17 — closed — builder 추천 ↔ P17 · prober 역할 경계 · confidence<0.4 규칙 대체 (mapper #4); S12: 추천은 4-block 추천 답안 블록에 orchestrator 의견과 나란히, 선택지 순서 유지/보완/전환/보류 고정, 첫 자리 승격 없음. confidence 필드 폐지(orchestrator 정함, recommendation=유지 가 대체)
- derived:skepticism_closure — closed — 트리거 축소 후 R3 미발동 인터뷰에서 skepticism floor 를 무엇으로 닫는가 (mapper #5 · prober FM2); S9: 기록 sentinel — §5 에 검토한 방향 N·전제 목록·trigger 후보와 기각 이유를 적은 항목으로 닫고 check_brief 가 인식
- derived:verdict_machine_vocab — closed — 4값 기계 대응 · 결합 락 표면 (mapper #1); S11: 전면 개명 kept/refined/switched/deferred (사용자, orchestrator 추천 ① 기각). orchestrator 정함: 옛 토큰 defended 는 one-minor deprecation 별칭(CLAUDE.md 규칙), 과거 brief 원장은 이관 안 함(시점 기록). refined 항목엔 취함:/버림: 필수

## 2. Budget

- 인터뷰: 질문 라운드 6 · agent dispatch 3 (coverage-mapper 1 · steelman-builder 1 · blind-spot-prober 1) · codex 실호출 0 · 웹 검색(orchestrator 직접) 4 · AskUserQuestion 6회(질문 12개)
- brief 리뷰: agent dispatch 5 (direction 1 · critic 3 · readback 1) · codex 실호출 4 (direction 1 · fidelity 3, 전부 성공)
- Phase 0: codex 실호출 2 (성공 2) · agent dispatch 3 (seed-critic 1 · seed-readback 2 — 1회 API 안전장치 오탐으로 재시도)

## 3. Steelman 원문

#### ST1 — 단일 builder 가 원안·대안 양쪽 케이스를 쓰는 설계에 대한 steelman (trigger: landscape 모순 — Khan 2024 · Nemeth 2001). 새 계약 예행: 전제 P1~P4 + 제약 요지 명시 전달, 양쪽 케이스, premise_refutation, recommendation

**dispatch 입력 요지** — 의심 방향「단일 builder 가 원안·대안 양쪽 최강 케이스를 같은 기준으로 쓰고 첫 필드에 전제 반증 여부를 답한 뒤 유지/보완/전환 추천」. trigger = landscape 모순(Khan et al. 2024 debate>consultancy · Nemeth 2001 assigned DA→bolstering). 핵심 전제 P1(결함=기준 부재+역할 편향) · P2(같은 기준의 대칭) · P3(열쇠=전제 충돌만) · P4(게이트는 사용자). 제약 요지: 범위 셋·새 agent 없음·상한·티어링 없음·Law 2·불만은 오염과 흔들림·R1 답.

**builder 출력 (verbatim)**:

> premise_refutation:
>   hits: []
>   why: >
>     두 trigger 논문은 P1~P4 어느 문장과도 직접 충돌하지 않는다. 오히려 둘 다 **현 설계**(대안 전담 옹호자)를 겨눈다.
>     Khan et al. 의 열세 조건 "consultancy" 는 정의상 「a single expert model (the consultant) is assigned a specific
>     answer and aims to persuade the judge」— 이것이 현 steelman-builder 의 정확한 모양이다(대안이라는 한 편에 배정된
>     단일 설득자). 논문은 「Across all protocols, human judges struggle when using incorrect consultants」라고 쓰고,
>     한 모델이 양쪽을 순차로 쓰는 조건은 실험하지 않았다 — 그러므로 「단일 저자 양쪽」에 대해선 침묵이지 반증이 아니다.
>     Nemeth 2001 의 cognitive bolstering 은 **역할로 배정된 반대자(DA)** 가 청자에게 낳는 효과다 — 이는 P1(b) 「역할
>     편향」을 뒷받침하는 근거이지 P1 을 반박하는 근거가 아니다.
>     단 하나 P3 는 «반증»이 아니라 «경고»에 닿는다: Nemeth 의 부수 발견 「armed with the belief that they have considered
>     alternatives … people may become even more convinced … more rigid」는, 「핵심 전제와 직접 충돌하지 않는 근거는
>     원안 강화에 쓴다」는 P3 의 기본 경로가 구조적으로 bolstering 채널이 될 수 있음을 말한다. 이것은 P3 를 무너뜨리지
>     않는다(P3 는 사용자가 「흔들림」을 막기 위해 택한 비용 있는 선택이다) — 하지만 그 비용을 상쇄하는 장치가 있어야
>     하고, 새 계약의 `premise_list_challenge` 필드가 그 장치의 절반이다(나머지 절반은 아래 recommendation).
>
> premise_list_challenge: >
>   빠진 전제 하나. **P0 — builder 는 방향을 형성한 인터뷰 턴과 분리된 컨텍스트여야 한다.** "Who Flips?"(arXiv
>   2606.16011)는 자기-생성 반론보다 교차-출처 반론이 답 뒤집기를 최대 23.6pp 더 유발한다고 보고한다 — 즉 도전의 힘은
>   «누가 양쪽을 쓰는가»보다 «도전자가 결론 형성자와 같은 컨텍스트인가»에서 더 크게 갈린다. 현 R3 는 dispatch 로 이를
>   이미 충족하지만 P1~P4 어디에도 명시돼 있지 않아, 재설계가 「단일 builder 가 양쪽을 쓴다」를 「orchestrator 가 인라인으로
>   양쪽을 쓴다」로 축약하는 경로를 막지 못한다. 또 P2 의 「같은 기준」은 **기준(사용자 goal)이 dispatch payload 에 명시적으로
>   실려야** 성립한다 — builder 가 방향 문장에서 goal 을 역추론하면 대칭은 형식만 남는다(현 dispatch 프롬프트는 goal 을
>   싣지 않는다, 아래 repo_claims).
>
> case_for_current: >
>   사용자 goal(오염과 흔들림 제거)에 대해: 원안은 Khan 의 열세 조건(한 편에 배정된 consultant)에서 벗어나면서 fan-out 을
>   1 로 유지한다. 판정자는 blind non-expert 가 아니라 **문제의 전문가인 사용자**이므로 Khan 식 두 옹호자 대칭 토론이
>   주는 이득(judge 의 정보 비대칭 보정, 교차 반박, 인용 검증)의 전제가 여기엔 없다. "Cost of Consensus"(arXiv 2605.00914)
>   는 구조화된 역할 없는 동종 모델 다중 토론이 「2.1–3.4× more tokens … for equal or lower accuracy」였고 실패 기제가
>   sycophantic conformity(최대 85.5% 모달 채택)라고 보고한다 — 같은 모델 사본 둘을 양편에 세우면 «오염»(서로의 argument 에
>   끌려감)이 오히려 늘 수 있다. 한 저자가 같은 기준으로 양쪽을 쓰는 것은 Lord·Lepper·Preston 1984 의 consider-the-opposite
>   (단일 판단자가 반대 가능성을 스스로 생성)가 「be fair and unbiased」 지시보다 교정 효과가 컸다는 발견과 같은 구조다.
>
> case_for_alternative:
>   statement: "builder 를 같은 goal 기준을 받은 두 대칭 옹호자(원안 편·대안 편)로 나누고, 판정·추천은 제3자(orchestrator 또는 사용자)만 한다."
>   strongest: >
>     Khan et al. 에서 인간 판정자의 이득 10pp(78%→88%)는 **독립된 두 옹호자**에서 나왔고, 논문은 한 모델이 양쪽을 쓰는 조건을
>     검증하지 않았다 — 원안은 검증되지 않은 외삽 위에 서 있다. "Who Flips?" 는 단일 출처가 만든 반론이 교차 출처 반론보다
>     체계적으로 약함을 보인다(최대 23.6pp) — 한 저자가 먼저 승자를 정하고 패자의 케이스를 약하게 쓰는 motivated reasoning 을
>     막을 구조적 장치가 원안엔 없다(같은 저자가 `premise_refutation`·양쪽 케이스·`recommendation` 을 모두 쓴다). Schweiger·
>     Sandberg·Ragan 1986 의 dialectical inquiry(별도 집단이 counterplan 작성)는 DA 보다 「quality of assumptions brought to the
>     surface」에서 우세했다 — 전제를 드러내는 일이 이 재설계의 목적(`premise_refutation`)이라면 문헌이 우세를 보고한 형태는
>     두 집단이다.
>
> evidence:
>   - url: "https://arxiv.org/html/2402.06782"
>     supports: both
>     claim: >
>       본문 확인. 인간 judge 정확도 debate 88% / consultancy 78% / naive 60%, LLM judge 75.6% / 54% / 48%.
>       consultancy = 「a single expert model … assigned a specific answer」, 「the judge a priori does not know if a consultant
>       is arguing the correct or incorrect answer」, 「human judges struggle when using incorrect consultants」. debater 는 같은
>       모델 사본 self-play. 한 모델이 양쪽을 쓰는 조건은 없음. judge 는 원문 접근 불가(정보 비대칭), 인용 검증 도구 사용.
>     touches: [P1, P2]
>   - url: "https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.58"
>     supports: both
>     claim: >
>       초록(검색 스니펫으로 확인, 원문은 403). 「devil's advocate appeared to foster thinking that was primarily aimed at cognitive
>       bolstering of the initial viewpoint rather than stimulate divergent thought」; authentic dissent 가 (a) original thoughts
>       비율 (b) considering the opposite position (c) direct attitude change 에서 우세; 「armed with the belief that they have
>       considered alternatives … people may become even more convinced … more rigid」. 역할 배정 DA(=현 설계)에 불리, P3 의
>       기본 경로에 경고.
>     touches: [P1, P3]
>   - url: "https://arxiv.org/abs/2606.16011"
>     supports: alternative
>     claim: >
>       초록 확인. 「self-attribution consistently increases flip rates (mean 7.1pp, up to 18.7pp)」; 교차 모델 반론 pooling 이
>       「amplifies answer flips by up to 23.6pp over self-generated challenges」. 도전자와 결론 형성자의 컨텍스트 분리가 도전
>       강도를 좌우 — 빠진 전제 P0 의 근거.
>     touches: [P2]
>   - url: "https://arxiv.org/abs/2605.00914"
>     supports: current
>     claim: >
>       초록 확인. 7–8B 급에서 「debate consumes 2.1-3.4× more tokens … than self-correction for equal or lower accuracy」; 실패
>       기제 = sycophantic conformity(최대 85.5% 모달 채택), contextual fragility(최대 70%), consensus collapse(oracle gap 최대
>       32.3pp). 구조화된 역할 없는 동종 다중 에이전트가 «오염»을 늘린다는 직접 근거. (소형 모델 결과라 외삽 주의.)
>     touches: [P2]
>   - url: "https://journals.aom.org/doi/10.5465/255859"
>     supports: alternative
>     claim: >
>       초록(검색 스니펫, 원문 403). DI·DA 모두 consensus 보다 추천·가정 품질 우세; 「dialectical inquiry was also more effective
>       than devil's advocacy with respect to the quality of assumptions brought to the surface」. DI 는 counterplan 을 별도로
>       구성하는 형식.
>     touches: [P1, P2]
>   - url: "https://doi.org/10.5465/ambpp.1988.4979642"
>     supports: current
>     claim: >
>       초록(검색 스니펫). 종단 연구에서 DI·DA 모두 consensus 보다 결정 품질 우세했으나 「no differences between dialectical
>       inquiry and devil's advocacy groups」 — 두 집단 형식의 우세는 연구 간 불안정.
>     touches: [P2]
>   - url: "https://sms.onlinelibrary.wiley.com/doi/abs/10.1002/smj.4250100309"
>     supports: current
>     claim: >
>       Schwenk 1989 메타분석(검색 스니펫, 원문 403). 견고한 결론은 「구조화된 갈등 > 무갈등(consensus/expert)」이며 DA 대 DI 의
>       차이는 그보다 약함 — 문헌은 한 저자 대 두 저자를 강하게 판별하지 않는다.
>     touches: [P2]
>   - url: "https://www.semanticscholar.org/paper/Considering-the-opposite:-a-corrective-strategy-for-Lord-Lepper/e71bbae72f8ad78e97c54f5ec88c9af2c70759f2"
>     supports: current
>     claim: >
>       Lord·Lepper·Preston 1984(초록, 검색 스니펫). 단일 판단자에게 반대 가능성을 스스로 생성하게 하는 consider-the-opposite 가
>       「be as fair and unbiased as possible」 지시보다 교정 효과가 컸다 — 한 컨텍스트가 양쪽을 쓰는 형식이 편향 교정 장치로
>       작동한 선례.
>     touches: [P2]
>
> repo_claims:
>   - path: "plugins/spec-distill/agents/steelman-builder.md"
>     anchor: "## You are / are not — 「You ARE: 대안의 강한 옹호자」 / 「You are NOT: … 원안의 옹호자」"
>     claim: "현 페르소나가 Khan 의 consultancy(한 편에 배정된 단일 설득자)·Nemeth 의 역할 배정 DA 와 동형이라는 P1(b) 의 리포 내 실체."
>   - path: "plugins/spec-distill/skills/conducting-interview/SKILL.md"
>     anchor: "### R3 — Steelman 의심 게이트 (P17) — dispatch prompt 「대안의 강한 케이스를 웹근거와 함께.」"
>     claim: "dispatch payload 에 사용자 goal(판정 기준)이 실리지 않는다 — P2 의 「같은 기준」이 성립하려면 이 자리에 기준이 실려야 한다(premise_list_challenge 의 P2 보강)."
>   - path: "plugins/spec-distill/skills/conducting-interview/SKILL.md"
>     anchor: "### R3 — 「**게이트**(P17): 사용자가 (방어 → 원안 유지 / 전환 → 대안 채택, 원안은 R4로 / 보류 → §3 OQ)」"
>     claim: "방어/전환/보류 3분 어휘가 게이트에 박혀 있어 「보완」을 추가하면 이 문장과 §5 verdict 매핑을 함께 바꿔야 한다."
>   - path: "plugins/spec-distill/scripts/check_brief.py"
>     anchor: "VALID_VERDICTS = (\"defended\", \"switched\", \"deferred\")"
>     claim: "verdict 어휘가 3값으로 고정 — 「보완」 verdict 를 신설하든 `defended` 에 흡수하든 결정이 필요하다."
>   - path: "plugins/spec-distill/scripts/check_brief.py"
>     anchor: "PN4 주석 — 「Whether the steelman is a genuine counter-argument is not」 (checked)"
>     claim: "판정기는 형식만 재고 논증의 진위·대칭성은 재지 않는다 — 대칭성 담보는 페르소나·계약 층에서만 가능하고 락으로는 못 잡는다는 한계를 재설계가 알고 있어야 한다."
>   - path: "plugins/spec-distill/agents/blind-spot-prober.md"
>     anchor: "「대안 옹호자(그건 steelman-builder — R6 분리)」 / 「premortem, not steelman: 대안을 옹호하지 않는다(그건 steelman-builder)」"
>     claim: "builder 의 역할 정의가 바뀌면 이 교차 참조 두 곳이 낡는다(삭제 스윕은 개념 별칭으로)."
>   - path: "CLAUDE.md"
>     anchor: "## Forbidden Patterns — **Subagent spray** — 「규모 자체가 아니라 선언 없음이」"
>     claim: "대안(builder 2명)은 리포 원칙상 금지가 아니라 선언·비용 정당화 대상 — 대안을 막는 것은 사용자의 범위 제약이지 CLAUDE.md 가 아니다."
>
> recommendation: 보완
> recommendation_why: >
>   두 trigger 논문은 원안이 아니라 현 설계(한 편 배정 옹호자)를 겨누므로 원안의 축(P1·P2·P4)은 유지하되, (1) 빠진 전제 P0 —
>   builder 는 방향 형성 턴과 분리된 dispatch 로 남는다 — 를 명시하고, (2) dispatch payload 에 사용자 goal 기준을 리터럴로 실어
>   대칭을 형식이 아니라 실질로 만들고, (3) P3 의 bolstering 위험(Nemeth)에 대해 `premise_list_challenge` 를 필수 필드로 유지하며
>   builder 가 대안 케이스를 원안 케이스보다 **먼저** 쓰게 하여(consider-the-opposite 순서) 「none → 원안 강화」가 기본값으로
>   미끄러지지 않게 한다. 대안(두 옹호자) 신뢰도 0.35 — Khan 의 이득 조건(blind judge·교차 반박·인용 검증)이 R3 에 없고, 동종
>   모델 다중 토론의 오염 근거가 사용자 불만의 핵심(오염)을 정면으로 친다.

**orchestrator 게이트-전 확인** — repo_claims 7건 전부 사실: ① steelman-builder.md 「You ARE: 대안의 강한 옹호자」 ② SKILL.md R3 dispatch prompt 에 goal 부재 ③ SKILL.md R3 게이트 3분 어휘 ④ check_brief.py `VALID_VERDICTS` 3값 ⑤ check_brief.py PN4 주석 「Whether the steelman is a genuine counter-argument is not」 ⑥ blind-spot-prober.md 교차 참조 2곳 ⑦ CLAUDE.md Subagent spray. 웹 근거 8건 중 3건은 builder 가 원문 확인, 5건은 검색 스니펫 초록(출판사 403) — orchestrator 재확인 안 함.
**사용자 판정**: 보완(3건 전부 수용) ⟨S4⟩ — 기계 어휘 부재로 payload §5 는 `defended`.

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-05) — web: enabled — {"pass": true, "failures": [], "advisories": []}
- check_verbatim_coverage.py — exit 0 (2026-09-05) — missing_ids 0 · not_contained 0 (S1 payload + S2~S13 audit vs state 원장 13건)
- reviewing-brief 진입/수정 라운드마다 check_brief.py gate 재실행 — 전부 pass (2026-09-05, 4회) · check_verbatim_coverage.py 재실행 exit 0 (3회)

## 5. 프로세스 로그

- round 1: path (d) ESSENCE — R1 문제 본질. teach-heavy(첫 전이, Kahneman *Noise* decision hygiene). 선택지 ①기준 부재 ②역할 편향 ③기록 어휘 → 사용자 「1과 2 둘다임 3은 파생」(S2). coverage-mapper dispatch(조건 2) → 6 derived 제안, 5 admit(#2+#6 병합). orchestrator 가 mapper 리포 사실 3건 검증(neglect 존재 락 · cb0b4dd · N1a).
- round 2: path (a)+(b) — web sweep 4회(매회 kill switch 확인). landscape 표 제시. 전제 확정 주체 질문 → ① 도출+게이트 노출(S3). ST1 dispatch(새 계약 예행).
- round 3: path (b) — ST1 verbatim 제시, repo_claims 7/7 게이트-전 확인. 판정 보완(S4). 공시: VALID_VERDICTS 에 보완 부재.
- round 4: path (b) — 부착 검증 주체 ① 양성만(S5) · 비부착 처분 ① 흡수(S6). blind-spot-prober dispatch(1회).
- round 5: path (b) — prober 결과 표(hidden 6 · failure 6). orchestrator 검증: 8-30 표본 재독(HA1 사실) · 9-02 adjudication 앵커링 기각 항목 · 9-02 seam ST1. 묻지 않고 정함 3(취함/버림 · 원문 인용 · 확인 결과 기록). Q1 표본 ①(S7) · Q2 순서 ②(S8) · Q3 종료 ①(S9).
- round 6: path (b) — 인용 형식 ①(S10) · 기계 토큰 ②전면 개명(S11, orchestrator 추천 기각) · 추천 노출 ①(S12) · OQ 박제(S13). 묻지 않고 정함: confidence 폐지 · deprecation 별칭.
- 종료: floor 5/5 · derived 5/5 closed → Step A. seed 파일은 같은 경로의 brief 로 대체(seed 전문은 payload §6 S1).
- 재결정(P23) 2건: seed 「첫 필드」→뒤로(S8) · seed 「file:line」→앵커(S10). payload §5 기각에 원래/재결정/근거.
- degrade: 없음 — 이 단계의 dispatch 3건 모두 정상 반환, web 활성, kill switch 미설정. (Phase 0 의 degrade 4건은 아래 B 절 검증 라운드에 있다.)

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

- 방향성: Claude 7건(D1~D7) / codex 5건 — 사용자 재결정 (Step B 에서 판정, 아래 Step B 기록)
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): needs_revise — critic 1건 / codex 1건 — 재라운드 2/2 (상한 도달 → Step B forced escalate)
  - round 1: critic 10 / codex 11 → needs_revise. 수정: C17 출처 분리 · S1 누락 항목 5건 추가(C21~C25) · ✎ 5건을 「미확정 제안」으로 강등 · §0 격상 3곳 교정 · C1/C3/C5/C6 문구 · §5 8/8 수치 제거
  - round 2(재리뷰 1): critic 1(§0 「왜」 두 실패 유형 중 하나 누락) / codex 0 → needs_revise. 수정: §0 문장을 S1 원문대로
  - round 3(재리뷰 2): critic 1(§5 기각 대안 3항목이 ⟨S3⟩⟨S5⟩⟨S7⟩ 원문에 없는 대안 문구 인용) / codex 1(전 항목 provisional·「confirmed 0건」 sentinel 이 원문 무근거) → needs_revise, cap. §5 3항목은 ✎ orchestrator 선택지로 출처 교정(리뷰되지 않은 수정). codex 지적은 Step A 계약(Step B 확정 전 sentinel 필수)과 충돌하는 지적이라 문서 변경 없이 Step B 로 이월
  - 처분 원장: accepted 21+1+2 / held 0 / unknown 0 / coerced 0
- 냉독: gap 3건 (G3 ×2 — C6·C19 요약 부재 / G6 ×1 — §0 「확정(잠정)」 vs frontmatter 「confirmed 0건」 관계 불명). blob rc=3 → 신뢰도 하향. 용어 불투명 지적(4-block·R1/R3·Step B·prober FM·bijection A·흡수/degrade)은 gap 클래스 밖 — 다음 단계 참고
- degrade: critic:fidelity:degraded(bundle rc=3, §6 S1 seed frontmatter 의 audit 파일명 잔존) · critic:fidelity:degraded(재리뷰 상한 2 도달, finding 1 잔존, 수정 미리뷰) · readback:readback:degraded(blob rc=3) · codex 방향성/충실도 모두 ok(codex_failed: false), skip 없음 · fallback 파일 비어 있음(원장 기록 전부 성공)
- 비용: 에이전트 dispatch 5(direction 1 · critic 3 · readback 1) · codex 실호출 4(direction 1 · fidelity 3, 전부 성공) — 상한(5+4) 도달
- Step B (2026-09-05): 사용자 ① 「확정하고 /compact 후 brainstorming」(S14). C1~C25 confirmed, sentinel 삭제, 게이트 재실행. 방향성 12항목·미확정 제안 ⓐ~ⓔ 는 그대로 brainstorming 으로 이월(사용자 재결정 0건). confirm_repost_count 0.
- brainstorming 진입 (2026-09-06): 재결정 2건 — S15 (C23 요지→원문 인용, 근거 check_slots.py 금지 kind·면제 baseline) · S16 (0건 게이트 기록 항목 요구, C26 신설). §5 기각 2건 추가. 게이트·완전성 재실행.
- brainstorming 설계 (2026-09-06): §1~§3 승인, 구조 선택 S17. design doc 작성 → spec 리뷰 라운드 1: Claude needs_revise(block 1·high 4·medium 3) / codex needs_revise(high 3·medium 1), 병합 needs_revise, 처분 보류 0. 사용자 S18: 수정 후 재리뷰 1회 더 · ST1 이관은 refined. 라운드 1 지적 10건 전부 수용, design doc 수정.
- spec 리뷰 라운드 2 (2026-09-06, D4 마지막): Claude needs_revise(high 2·medium 5; 라운드 1 8건 닫힘) / codex needs_revise(high 1·medium 3), 병합 needs_revise, 처분 보류 0. 11건 전부 수용해 design doc 수정. 수정은 재리뷰 없이 Human Gate 로(S18).

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

(`S1` 은 payload §6 에 있다 — Phase 0 interview-seed 전문. 아래는 S2 이상 전량, append-only.)

- **S2** 🗣 발화 (R1 문제의 본질 — ①기준 부재 ②역할 편향 ③기록 어휘 중) — round 1:
  > "1과 2 둘다임 3은 파생으로 보임"

- **S3** ☑ 선택 (핵심 전제 목록의 확정 주체·시점) — round 2:
  > "① 도출 + 게이트 노출 — orchestrator 가 R1 문제정의·goal·사용자 발화에서 핵심 전제를 도출해 넘기고 게이트 4-block 에 목록을 그대로 노출. 별도 확인 라운드 없음. builder 의 「목록이 틀렸다」 권한이 2차 안전판"

- **S4** ☑ 선택 (ST1 판정 — 단일 builder 양쪽 케이스) — round 3:
  > "보완 — 원안 유지 + builder 제안 3건 수용: P0(분리된 dispatch 컨텍스트) 명시 · dispatch payload 에 goal 리터럴 · 대안 케이스를 원안보다 먼저 쓰는 순서"

- **S5** ☑ 선택 (전제 부착 주장의 검증 주체) — round 4:
  > "① 양성만 orchestrator 확인 — hits 가 비어 있지 않은 주장만 repo_claims 사전 확인과 같은 게이트-전 단계에서 전제 문장과 근거를 대조. 음성은 확인 안 함"

- **S6** ☑ 선택 (비부착 근거의 처분·회계) — round 4:
  > "① 노출+보존+계수 = 흡수 — 4-block 에 라벨 붙여 보이고, audit §3 ST<N> 에 전문 보존, payload §5 에 「근거 N 중 부착 M」 계수. 회계는 흡수, degrade 아님"

- **S7** ☑ 선택 (8-30 표본 논문 9건이 그대로 오는 것) — round 5:
  > "① 괜찮다 — 8-30 표본의 논문 9건처럼 전제를 정면으로 치는 근거는 걸러질 대상이 아니라 정당한 재검토 사유. 불만의 실체는 이분법 기록·제약 무지·무관 근거이고 이 설계가 그것을 잡는다"

- **S8** ☑ 선택 (premise_refutation 의 위치) — round 5:
  > "② 문단 뒤로 — builder 출력 순서를 대안 케이스 → 원안 케이스 → 전제 반증 판정 → 추천 으로. seed 「첫 필드」의 재결정(근거: 9-02 adjudication 인터뷰의 선행 판정 앵커링 실측)"

- **S9** ☑ 선택 (trigger 없는 인터뷰의 skepticism 종료) — round 5:
  > "① 기록 sentinel — 의심 trigger 없는 인터뷰는 §5 에 검토한 방향 N·전제 목록·trigger 후보와 기각 이유를 적은 항목으로 skepticism 을 닫고 check_brief 가 그 형식을 인식"

- **S10** ☑ 선택 (리포 주장 인용 형식) — round 6:
  > "① 경로+앵커 필수, 줄번호 보조 — 심볼·헤딩·원문 인용 중 하나. seed file:line 의 재결정"

- **S11** ☑ 선택 (보완의 기계 어휘) — round 6:
  > "② 전면 개명 — VALID_VERDICTS 를 kept/refined/switched/deferred 로 토큰까지 개명. 픽스처·과거 brief 원장 이관 필요(orchestrator 추천 ① refined 추가만 은 기각)"

- **S12** ☑ 선택 (builder 추천의 게이트 노출) — round 6:
  > "① 나란히 표시, 선택지 순서 고정 — 추천 답안 블록에 builder 추천과 orchestrator 의견을 나란히, 선택지는 항상 유지/보완/전환/보류 순, Recommended 라벨로 첫 자리에 안 올림"

- **S13** ☑ 선택 (Open Questions 6건 박제) — round 6:
  > "이대로 박제 — Open Questions 6건 전부 §3 으로, 유추로 닫지 않는다"

- **S14** ☑ 선택 (Step B proceed 게이트) — 종료:
  > "확정하고 /compact 후 brainstorming (권장) — C1~C25 전부 confirmed. 방향성 12항목은 현행 유지(뒤집는 것 없음)"

- **S15** ☑ 선택 (brainstorming 진입 재결정 — C23 제약 전달 형태) — 2026-09-06:
  > "원문 인용 (Recommended) — dispatch 시 builder 에 넘기는 제약은 state 의 user_statements 원문 인용으로 한다 (C23 「요지」 재결정)"

- **S16** ☑ 선택 (brainstorming 진입 재결정 — 0건 게이트) — 2026-09-06:
  > "요구 (Recommended) — steelman 0건 인터뷰는 §5 기록 항목(검토한 방향 N·전제 목록·trigger 후보와 기각 이유)이 필수, 없으면 check_brief RED"

- **S17** ☑ 선택 (brainstorming 구조 선택) — 2026-09-06:
  > "모듈 분리 (Recommended) — R3 절차 전문은 skills/conducting-interview/references/steelman.md, §5 skepticism 검사는 scripts/skepticism.py"

- **S18** ☑ 선택 (spec 리뷰 라운드 1 마무리 + ST1 이관 값) — 2026-09-06:
  > "수정 후 재리뷰 1회 더 (권장) · ST1 이관은 실질 판정으로 (권장) — 이 브랜치 ST1 은 verdict: refined, 과거 brief 의 기계 토큰 2줄은 산문을 읽고 kept/refined 를 골라 적는다"

## 7. 확산 원자료

- «schweiger-1986» — https://journals.aom.org/doi/10.5465/255859 — Schweiger·Sandberg·Ragan 1986, AMJ. DI·DA > consensus, DI > DA (quality of assumptions). 초록(검색 스니펫).
- «schwenk-1989» — https://sms.onlinelibrary.wiley.com/doi/abs/10.1002/smj.4250100309 — Schwenk 1989 메타분석. 구조화된 갈등 > 무갈등, DA-DI 차이 약함. 초록(스니펫). 종단 연구 https://doi.org/10.5465/ambpp.1988.4979642 (DI-DA 무차이) 도 이 키.
- «double-crux» — https://www.lesswrong.com/w/double-crux — CFAR Double Crux. crux 정의, 「crux 탐색은 못 박히지 않은 마술」.
- «khan-2024» — https://arxiv.org/abs/2402.06782 — Khan et al. 2024. debate 88% / consultancy 78% / naive 60%. builder 가 HTML 본문 확인.
- «nemeth-2001» — https://onlinelibrary.wiley.com/doi/abs/10.1002/ejsp.58 — Nemeth·Brown·Rogers 2001. assigned DA → cognitive bolstering. 초록(스니펫, 원문 403).
- «who-flips-2026» — https://arxiv.org/abs/2606.16011 — 자기-생성 vs 교차-출처 반론, flip rate 차 최대 23.6pp. 초록 확인.
- «cost-of-consensus-2026» — https://arxiv.org/abs/2605.00914 — 동종 다중 토론 2.1–3.4× 토큰, sycophantic conformity. 초록 확인(7–8B 급).
- «lord-1984» — https://www.semanticscholar.org/paper/Considering-the-opposite:-a-corrective-strategy-for-Lord-Lepper/e71bbae72f8ad78e97c54f5ec88c9af2c70759f2 — Lord·Lepper·Preston 1984 consider-the-opposite. 초록(스니펫).
- «sycophancy-2023» — https://arxiv.org/abs/2310.13548 — Sharma et al., Towards Understanding Sycophancy in Language Models. prober 인용.
- «self-correct-2023» — https://arxiv.org/abs/2310.01798 — Huang et al., LLMs Cannot Self-Correct Reasoning Yet. prober 인용.
- «compromise-effect» — https://www.columbia.edu/~on2110/Papers/Alternative_Models_for_Capturing_the_Compromise_Effect.pdf — compromise effect 모델. 보조 https://onlinelibrary.wiley.com/doi/full/10.1002/mar.21720. prober 인용.
- «goodhart-multiagent-2026» — https://arxiv.org/abs/2606.07805 — Beyond Goodhart's Law: compliance in multi-agent systems. prober 인용.
- 기타(payload 미인용): Dewar Assumption-Based Planning https://catdir.loc.gov/catdir/samples/cam033/2002073460.pdf · red-teaming scope https://judithcurry.com/2017/07/03/what-is-red-teaming/ · Mechanical Enforcement for LLM Governance https://arxiv.org/pdf/2605.14744 · Kahneman·Sibony·Sunstein *Noise* https://en.wikipedia.org/wiki/Noise:_A_Flaw_in_Human_Judgment (round 1 teach-heavy) · Schulz-Hardt et al. https://www.sciencedirect.com/science/article/abs/pii/S0749597802000018.

---

# Phase 0 기록 (framing-requests) — 이어받은 원문

## A. Phase 0 — 원문 (framing-requests, append-only 원문 절)

### 라운드 0 — `/spec-distill:framing-requests` 인자 (2026-09-05)

> 워크트리를 생성하고 거기에서 작업 시작하자 pec-distill의 steelman 흐름을 개선해줘. 현재 방식은 대안을 억지로 강하게 만들고 관련성이 약한 외부 컨텍스트까지 가져와 기존 결정을 필요 이상으로 흔든다. Steelman의 목 적을 ‘원안 뒤집기’가 아니라 ‘사용자 목표에 가장 적합한 방향 찾기’로 재정의해. 새로운 근거가 기존 방향의 핵심 전제와 직접 충돌할 때만 재검토하고, 그렇지 않으면 원안을 강화하거나 경계를 다듬도록 해. 원안과 대안을 동일한 기준으로 비교해 유지·보완·전환 중 최선의 결론을 내리며, 약하거나 무관한 반론이 확정된 방향을 다시 열지 못하게 해.

### 라운드 1 질문 (orchestrator → 사용자, 2026-09-05) — 답의 지시 대상

> Q1. **범위** — ⓐ steelman-builder 페르소나만 ⓑ ⓐ + conducting-interview 의 R3 게이트(trigger·선택지·판정 어휘) + check_brief.py ⓒ ⓑ + brief-direction-reviewer 의 `overturn` 프레이밍까지. 추천 ⓑ.
> Q2. **핵심 전제의 출처** — ⓐ R1 에서 재구성한 문제정의·goal(payload §0·§1) ⓑ 사용자가 그 라운드까지 말한 제약 전부 ⓒ dispatch 시점에 orchestrator 가 명시해 builder 에 넘긴다. 추천 ⓐ+ⓒ.
> Q3. **판정 어휘** — `defended / switched / deferred` 에 보완(`refined`)을 넷째 값으로 추가할까, 보완을 `defended` 의 하위로 둘까. 추천 전자(넷째 값 추가).
> Q4. **양측 케이스** — builder 가 원안의 최강 케이스도 함께 써서 같은 기준(사용자 goal)으로 비교한 뒤 유지/보완/전환 추천까지 내게 할까, 비교표만 내고 추천은 안 하게 할까. 추천: 추천까지 내되 「확정된 방향에 대한 반증인가」를 첫 필드로 명시.
> Q5. **약한 반론 봉쇄 기준** — ⓐ 각 근거가 어느 핵심 전제에 부딪히는지 명시하지 못하면 재검토 사유가 아니다 ⓑ confidence 임계(0.4)를 올린다 ⓒ 둘 다. 추천 ⓐ.
> Q6. **실물 표본** — steelman 이 필요 이상으로 흔들었다고 느낀 인터뷰가 어느 것인가. 08-30 brief-restructure ST1(arxiv 9건)이 그 사례인가.
> Q7. **외부 컨텍스트** — 개수 제한은 리포 규범과 충돌. 「각 evidence 는 부딪히는 전제를 명시」(Q5-ⓐ)로 충분한가, 출처 종류 선호(특정 논문보다 확립된 패턴·문서 우선)도 있는가.

### 라운드 1 답 (2026-09-05) — Q1~Q7 순

> b, 추천으로, 추천으로, 추천으로, a, 좋은 사례야 더 찾을 수 있다면 찾아봐 git에도 자료가 있을거야 다만 잘 찾아 너무 비용 많이 들지 않게, 직접 고민해줘 /
> 추가로 전체 그림을 봤을 때 더 개선사항이 있거나 내가 말한게 좋은 방향이 아니라면 이야기해줘

### 라운드 2 질문 (orchestrator → 사용자, 2026-09-05) — 답의 지시 대상

> 표본 8건 보고(실질 전환 3 · 보완 3 · 유지 1 · 불명 1; builder 사실 오류·사용자 제약 미인지 2건) 와 orchestrator 의견(Sealed decision 경계 · 전제 목록을 원안 쪽이 쥐는 위험 · 추가 개선 둘 · brief-direction-reviewer 는 범위 밖 · skepticism 차원 닫힘 조건 미확정) 뒤에:
> Q8. 추가 개선 둘(builder 리포 주장의 file:line + orchestrator 게이트 전 검증 단계 · R3 trigger 에서 coverage-mapper neglect 제외)을 이번 범위에 넣는가. 추천: 둘 다.
> Q9. 「확정된 방향」= 사용자가 인터뷰에서 실제로 답한 것(user_statements)과 seed 의 내용으로 두고, 다시 열 수 있는 유일한 열쇠를 「핵심 전제와의 직접 충돌」로 하는가. 추천: 예(종료 게이트 confirmed 로 두면 인터뷰 중 봉쇄가 작동하지 않음).
> Q10. builder 에게 「전제 목록 자체가 틀렸다」는 발견을 허용하는가. 추천: 예.

### 라운드 2 답 (2026-09-05) — Q8~Q10 순

> ok, 예, 예

### 게이트 1차 (2026-09-05) — 4옵션 proceed 게이트, degrade 4건 공시

> 사용자 선택: ③ 수정 필요 (Recommended)

### 라운드 3 질문·답 (2026-09-05)

> Q11. steelman-builder 에 핵심 전제 외에 「사용자가 그때까지 말한 제약의 요지」도 함께 넘길까 (Q2 에서 ⓑ 는 미선택이었으나 표본 1건의 원인이 제약 미인지). 옵션: 넘긴다(추천) / 넘기지 않는다 / 인터뷰가 정한다.
> 답: 넘긴다 (Recommended)

## B. Phase 0 — 라운드 기록

### 라운드 1 — 레포 읽기 결과 (2026-09-05)

- steelman 이 사는 자리 셋: `plugins/spec-distill/agents/steelman-builder.md`(persona: "대안의 강한 옹호자 · 원안의 옹호자 아님", confidence<0.4 면 "원안 defend 합리적" 명시) · `skills/conducting-interview/SKILL.md` R3(trigger 4종 → dispatch → verbatim 제시 → 사용자 게이트 방어/전환/보류 → §5 `verdict: defended|switched|deferred`) · `scripts/check_brief.py`(`VALID_VERDICTS`, bijection A `ST<N>`).
- 형제 장치: `agents/brief-direction-reviewer.md`(reviewing-brief 의 방향 축, 출력 필드가 `overturn:`) · seed 입력 시 P23 재결정 규약(SKILL.md 「seed 를 입력으로 받았을 때」).
- 리포 실측: 과거 brief 7건의 steelman 판정 = switched 6 · defended 2. 2026-08-30 brief-restructure ST1 은 arxiv 9건 인용·confidence 0.78 로 switched 됐고, 사용자가 같은 자리에서 "1차 출처의 경우도 너무 specific한 논문 자료를 가져오는 경우가 많더라고" 라고 적었다. 같은 ST1 에서 builder 가 사용자 발화 S3 로 이미 닫힌 경로를 대안에 포함해 orchestrator 가 걸러냈다(builder 는 사용자 제약을 모른 채 돌았다).
- 락: `tests/test_steelman_builder_scope.sh` 가 tools allowlist · `model: inherit` · verbatim/약화금지 문구 · 횟수 상한 부재 · 병렬금지 문구 부재를 잠근다.
- 원장: state 파일 없음(`ledger_rc=1`, `no-state-in-phase-0`) → degrade 는 게이트 텍스트로만.

### 라운드 2 — 사례 표본 (리포 audit 7건 + `git log --grep=steelman`, 2026-09-05)

| 사례 | 판정 | 실제 결과 모양 | 표본이 보여주는 것 |
|---|---|---|---|
| 08-16 weight-reduction ST1 | defended | 대안이 든 위험 4건을 "설계 제약으로 이월" | 실질은 **보완**인데 어휘가 없어 defended 로 기록. 또 builder 가 아니라 orchestrator 가 직접 저술(공유 전제 degrade 자기 신고) |
| 08-16 weight-reduction ST2 | switched | 전역 규약 대신 사본 제거 | 실측(거짓 설명이 10회 bump 통과)에 근거한 전환 |
| 08-22 request-framing ST1 | defended | 대안의 핵심 사실 주장("원형 보존 이미 강제됨")이 orchestrator 사후 검증에서 **반증** | builder 의 리포 사실이 틀렸고, 검증은 계약 밖 ad-hoc 이었다. evidence 10건(MAST·Cognition·DORA·Fowler…)은 일반론 |
| 08-22 subagent-adjudication ST1 | switched | 저자 검증 4건 전부 참 | 정당한 전환 |
| 08-30 brief-restructure ST1 | switched | 대안 채택하되 티어링 명시 기각, 진짜 메커니즘은 OQ1 로 | 실질은 **부분 채택(보완)**. arxiv 9건, 사용자 "너무 specific한 논문". builder 가 S3 로 닫힌 경로를 제안(사용자 제약 미인지) |
| 09-02 adjudication-topology ST1 | switched | 결정 축 교체(측정값 근거) | 정당한 전환 |
| 09-02 seam ST1 | switched (0.62) | "B 먼저 → A 는 재측정 뒤" — 원안 일부 + 대안 일부. builder 가 스스로 반대 근거(Metz) 제출 | 실질은 **보완**. evidence URL 은 payload 전파 금지 자진 신고 |

집계: 8건 중 판정상 switched 6 · defended 2. 실질로 다시 세면 전환 3 · 보완 3 · 유지 1 · 판정 불명 1(07-26 구형식). 즉 **중간 판정의 부재가 표본의 3/8 을 양극단으로 밀어 넣었다.** builder 가 사실을 틀리거나 사용자 제약을 모른 사례 2/8.

Q7 자기 결정: 개수 상한·출처 티어링 둘 다 쓰지 않는다(리포 규범 + 08-30 사용자 명시 기각). 대신 evidence 항목마다 「어느 전제에 부딪히는가」를 필수로 하고, 어떤 전제에도 닿지 않는 근거는 게이트 제시에서 빼고 audit 에만 남긴다.

### 검증 라운드 (2026-09-05)

- 원장: state 파일 없음(`no-state-in-phase-0`) → degrade 기록은 게이트 텍스트로만.
- **codex 억제 축 1차** (`codex_status: ok`, findings 10): 다수가 「질문 본문이 없어 답 `b`·`추천으로`·`a` 가 무엇을 골랐는지 특정 불가」. 원인 = 번들이 audit `## 1. 원문` 만 싣는데 orchestrator 질문이 §1 에 없었음 → 질문 전문을 §1 에 추가하고 재조립.
- **codex 억제 축 2차** (`codex_status: ok`, findings 6): ① `(+ 그 락)` 은 Q1-ⓑ 에 없는 범위 추가 ② `— 후속` 은 사용자 결정 아님 ③ 「사용자 제약 요지와 함께」·기준의 「·제약」은 Q2-ⓑ(미선택)·Q4(goal 만) 를 넘는 추가 ④ 「audit 에만 남긴다」는 미결정 구현 ⑤ 「개수 상한·티어링 안 씀, 티어링 기각」은 Q7 답 「직접 고민해줘」를 사용자 입장으로 귀속 ⑥ 「confidence 기준 배제」는 Q5-ⓐ 선택이 ⓑ 비채택일 뿐 전면 배제 아님.
- `check_seed.py gate` → rc 0.
- 냉독 1차: Fable 5.1 API 안전장치 오탐(`reasoning_extraction`)으로 에이전트 즉시 종료 → 모델 opus 로 재시도.
- 격리 critic 에 넘긴 `${BLOB}` 의 CLAUDE.md 부분은 전문이 아니라 요지로 줄였다(초안·원문 부분은 동일). codex 와 「같은 번들」 주장은 이 점에서 부분적으로만 참 — 게이트 텍스트에 공시.

- **격리 critic** (seed-critic, findings 8): 화자 귀속 6곳(orchestrator 진단·Q7 위임 판단이 사용자 1인칭 확정으로) · 「audit 에만」은 CLAUDE.md 「사람 소비자면 라벨 붙여 노출」과 역방향 · confidence 「폐기」는 Q5-ⓐ 를 넘음 · 「제약 요지 전달」은 미선택 Q2-ⓑ 의 재유입 · 「후속」 약속 없음 · 「결정은 사용자」는 기존 사실.
- **냉독** (seed-readback, opus): 이해 일치. 공백 6 — 방어→유지 개명 여부·보류의 신분 / 전제 부착 판정 주체 / audit-only 항목의 회계 신분 / 외부 근거 비용 축 / seed 자체가 R3 문턱을 높이는 재귀 / skepticism 닫힘(seed 가 이미 미결 표시).
- **2차 압축** (게이트 ③ 이후): 화자 3분리(사용자가 본 문제 / orchestrator 진단·사용자 동의 / 사용자 확정 / orchestrator 위임 판단) · `(+ 그 락)`·`— 후속`·`audit 에만`·confidence 폐기 삭제 · 보류=게이트 전용·방어→유지 개명 명시 · 비용 아님 명시 · 재귀 문턱 명시 · 「인터뷰가 정할 것」 절 신설(처분·부착 판정 주체·skepticism 닫힘). Q11 답으로 제약 요지 전달을 사용자 확정으로 복원.
- 2차 압축 후 억제·냉독 리뷰는 **재실행하지 않았다** — 변경이 삭제·귀속 교정·미결 표시였고 새 주장 추가는 Q11 한 줄뿐. 게이트 텍스트에 공시.

## C. Phase 0 — 긴 초안

(압축 전 전문. seed 로 나가는 것은 이것을 깎은 것뿐이다.)

### 의도

spec-distill 인터뷰의 R3(의심 게이트)에서 steelman 이 하는 일을 바꾼다. 지금은 「대안의 최강 케이스를 만들어 원안을 흔든다」이고, 바꾸려는 것은 「사용자 goal 을 기준으로 원안과 대안을 같은 저울에 올려 유지·보완·전환·보류 중 하나를 고른다」이다. 목적은 원안 뒤집기가 아니라 사용자 목표에 가장 적합한 방향 찾기다.

### 진단 (표본 8건, 리포 audit)

- 기록된 판정은 switched 6 · defended 2 이지만 실질은 전환 3 · 보완 3 · 유지 1 · 불명 1. 중간 판정(보완)이 없어 3/8 이 양극단으로 기록됐다 (08-16 ST1 은 위험을 설계 제약으로 이월하고도 defended, 08-30 ST1 은 티어링 기각·메커니즘 OQ 이월인데 switched, 09-02 seam ST1 은 「B 먼저 A 는 재측정 뒤」인데 switched).
- builder 가 리포 사실을 틀리거나(08-22 request-framing: "원형 보존 이미 강제됨" 이 반증) 사용자가 이미 닫은 경로를 제안(08-30: S3 로 닫힌 audit_file 동반 전달)한 사례 2/8. 두 경우 모두 orchestrator 가 계약 밖에서 임의로 사후 검증해 잡았다.
- 관련성 약한 외부 근거: 08-30 arxiv 9건(사용자 "1차 출처도 너무 specific한 논문"), 08-22 request-framing 10건(MAST·Cognition·DORA·Fowler 등 일반론).
- 편향은 산문이 아니라 스키마에 있다: builder 출력이 `alternative_statement / strongest_case / weakness_of_current` 로 한쪽만 담고, 페르소나가 "원안의 옹호자 아님" 이며, 게이트 선택지가 방어/전환/보류, `VALID_VERDICTS = (defended, switched, deferred)`.

### 사용자가 확정한 방향

1. 범위: `agents/steelman-builder.md` + `skills/conducting-interview/SKILL.md` R3 + `scripts/check_brief.py`(+ 락 테스트 동기화). brief 리뷰 단계의 `brief-direction-reviewer`(`overturn:` 프레이밍)는 이번 범위 밖 — 후속으로만 기록.
2. 재검토 열쇠는 하나: 새 근거가 원안의 **핵심 전제**와 직접 충돌할 때만. 그 외 근거는 원안을 강화하거나 경계를 다듬는 데 쓴다. 핵심 전제의 출처는 R1 이 재구성한 문제정의·goal(payload §0·§1)이고, dispatch 시점에 orchestrator 가 사용자 제약 요지와 함께 builder 입력으로 명시해 넘긴다.
3. builder 는 원안과 대안 **양쪽**의 최강 케이스를 같은 기준(사용자 goal·제약)으로 쓰고, 첫 필드에 「이것이 확정 방향의 핵심 전제에 대한 반증인가」를 답한 뒤 유지/보완/전환 추천을 낸다. 결정은 사용자(P17).
4. builder 에게 **전제 목록 자체가 틀렸다**는 발견을 허용한다. 09-02 adjudication 처럼 결정 축 자체를 바꾼 사례가 있고, 이것을 막으면 전제 목록이 원안 저자의 상상력을 물려받아 요청의 취지가 confirmation bias 로 뒤집힌다.
5. 판정 어휘: 유지(`defended`) / 보완(`refined`, 신설) / 전환(`switched`) / 보류(`deferred`). check_brief.py 의 허용 집합과 과거 brief 호환에 손댄다.
6. 약한·무관한 반론 봉쇄의 기준: evidence 항목마다 「어느 핵심 전제에 부딪히는가」를 필수로 명시. 닿는 전제가 없는 근거는 게이트 제시에서 빼고 audit 에만 남긴다. 개수 상한과 출처 티어링은 쓰지 않는다(리포 규범: 횟수 상한 제거, 락이 상한 문구를 RED 로 잡음; 08-30 에서 사용자가 티어링 명시 기각). confidence 수치 임계는 builder 자기 채점이라 기준으로 삼지 않는다.
7. 「확정된 방향」= 사용자가 인터뷰에서 실제로 답한 것(user_statements)과 seed 의 내용. 종료 게이트의 confirmed 가 아니다(그러면 인터뷰 중 봉쇄가 작동하지 않음).
8. 추가 개선 둘 포함: (a) builder 의 리포 주장에 `file:line` 을 요구하고 orchestrator 가 게이트 **전에** 확인하는 단계를 R3 에 명문화(웹 근거는 못 검증하지만 리포 근거는 할 수 있다). (b) R3 trigger 4종에서 `coverage-mapper neglect` 제외 — 커버리지 공백은 전제 충돌이 아니라 probe 질문으로 간다.

### 경계와 주의

- 봉쇄는 Sealed decision(P23 anti-corollary)이 되면 안 된다. 열쇠는 「확정됐으니까」가 아니라 「핵심 전제 충돌」만. 재발견 금지 ≠ 반증 금지.
- 「원안 옹호」로 기울면 steelman 이 존재하는 이유(P11 cross-model adversarial, AP14 confirmation bias)를 잃는다. 대칭이 핵심이다: 같은 기준, 양쪽 케이스.
- 페르소나 파일은 보안-민감 코드(CLAUDE.md). 규칙 제거·임계 완화로 읽히는 변경은 그렇게 리뷰된다. 기존 락 `tests/test_steelman_builder_scope.sh`(tools allowlist · model inherit · verbatim/약화금지 문구 · 상한 부재 · 병렬금지 부재)는 유지돼야 한다.
- 한 방향당 1회, 새 근거 없으면 재steelman 금지(AP16)는 유지.
- skepticism floor 차원이 「의심 trigger 없음」일 때 어떻게 닫히는지, trigger 를 억지로 만들어 차원을 닫는 압력이 있는지는 이 라운드에서 확정 못 함 — 인터뷰가 확인.
- web 부재 시 수동 게이트로의 graceful degradation 은 그대로.

### 과정 (audit 에만)

워크트리 `feature+steelman-goal-fit`. 라운드 2회, 질문 10개. 웹 미사용. 사례 조사 비용 = audit 7건 grep + git log 1회.
