---
type: interview-audit
payload: 2026-08-02-comprehension-debt-plugin-interview.md
created_at: 2026-08-02
session_id: a1797a3f-270e-402b-a47f-1eaaacf55d38
source: spec-distill conducting-interview v0.24.4
---

# 이해부채 관리 플러그인 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S13: 속도 불일치 — 사용자가 이해하는 속도 < 작업이 진행되는 속도, 그리고 subagent 간 대화가 표면에 안 나옴. 필요한 것은 설명의 양이 아니라 빠른 현황 파악. (S2의 미공유 진단 위에 속도 축이 얹힘)
- floor:landscape — closed — sweep1 4건(plainlanguage.gov / Intent Preview·Plan Summary / progressive disclosure·alert fatigue / common ground·Hidden Profile) + sweep2 3건(comprehension debt Osmani·O'Reilly / subagent black-box Codex V2·Copilot Mission Control / 처방 3종 narrated actions·comprehension checkpoint·ADR at decision time). sweep2는 S9의 "외부에서 검색해서 용어를 확인하라" 지시로 실행.
- floor:skepticism — closed — ST1 verdict=defended(부분). grep 구조검사는 사용자가 명시 기각(S6 "너무 강한 억제 하네스"), "단일 위치 규칙으로 축소" 처방은 S14/S15로 기각(초반 방향이 더 가깝다). alert-fatigue 경고는 형식 층위 요건으로 생존.
- floor:blind_spot — closed — premortem 4건을 사용자에게 표면화 완료: (1) 설명량↑=이해↑ 인과 논박 (2) 결정론 없는 지침의 조용한 drift + devbrew 자체 전례 (3) rubber-stamp / 가짜 감독 (4) 해결책이 문제를 재생산. S13이 (3)의 전제(결핍=contestability)를 해소 — 결핍의 정체는 파악 속도.
- floor:open_questions — closed — OQ1~OQ6 박제. OQ1(결정론적 집행 기각 후 대안 부재)이 최대 구멍이며 premortem #2가 이를 직접 겨냥.
- derived: N/A

## 2. Budget

- probe_count: 8 / cap 12
- web_sweep_count: 0 / 4 (sweep 2회 실행 후 각각 reset)
- web_search_count: 7 / 8

## 3. Steelman 원문

#### ST1 — 원장을 만들지 말고 "첫 등장 시 1줄 정의 + 출처 태그" 단일 위치 규칙으로 축소하고, 자기신고가 아니라 훅 grep 구조검사로 확인하라

> ```yaml
> alternative_statement: "5개 '의미 순간'마다 의무 설명 + 인지부채 원장을 새로 만들지 않는다. 진단된 실제 문제(Hidden Profile: 대화창에 없던 용어·사실이 갑자기 등장)만 정확히 겨냥해, '새 용어·새 사실·다른 에이전트발 주장이 대화창에 처음(first occurrence) 등장하는 그 지점에서 출처 태그(어느 subagent/파일에서 왔는지)와 1줄 정의를 인라인으로 붙인다'는 단일 위치 규칙을 채택하고, 이를 이미 존재하는 P17 AskUserQuestion 결정 게이트 위에 얹는다. 이행 여부는 자기-원장이 아니라, 그 게이트의 옵션 텍스트에 등장하는 고유명사가 지금까지의 가시적 transcript에 선행 등장했는지를 훅이 grep으로 확인하는 구조적 사실로 검사한다."
> strongest_case: "Hidden Profile은 '설명 총량 부족'이 아니라 'grounding 실패 지점의 위치' 문제다 — 새 정보가 상대의 acknowledge 없이 assert되는 지점만 고치면 되지 5개 카테고리 전부에 발화 의무를 걸 필요가 없다(grounding-gap 문헌). '정의 on first use'는 이미 업계 표준 기술문서 컨벤션이라 신규 장치 없이 즉시 적용 가능하다. 자기 자신이 '설명함'을 기록하는 원장은 Law 2/AP3 self-approval과 동형이지만, '옵션에 나온 용어가 transcript에 먼저 나왔는가'는 외부에서 mechanically grep 가능한 사실이라 자기신고가 불필요하다 — 이 리포의 기존 Coverage Ledger(interview_coverage_driven)가 성공한 이유도 정확히 이것(객관적/이진적 사실만 추적)이었고, 원안은 그 성공 조건을 충족하지 못하는 '주관적 상태(이해됐는가)'를 같은 방식으로 추적하려 한다."
> evidence:
>   - url: "https://arxiv.org/pdf/2311.09144"
>     claim: "'Grounding Gaps in Language Model Generations' — LM 출력이 상대의 인지 여부와 무관하게 새 정보를 assert하는 특정 지점에서 grounding gap이 발생함을 실증. 전면적 설명 의무가 아니라 그 지점(신규 정보 삽입 순간)만 겨냥하는 개입이 문헌의 처방과 일치."
>   - url: "https://arxiv.org/pdf/2602.21337"
>     claim: "'A Benchmark to Assess Common Ground in Human-AI Collaboration' — human-AI 협업의 common ground 결손이 측정 가능한(벤치마크 가능한) 특정 실패 유형으로 분해됨을 보임. '전부 설명'이라는 총량 규제가 아니라 실패 유형별 targeted fix가 연구 방향임을 뒷받침."
>   - url: "https://draft.dev/learn/technical-writer-style-guides"
>     claim: "'define on first use(정의는 첫 등장에서만)'가 이미 성숙한 업계 표준 기술문서 컨벤션으로 존재하며, 신규 원장·추적 장치 없이 위치 규칙 하나로 시행됨을 확인."
> weakness_of_current: "원안은 (a) 실제 진단된 문제(정보 비대칭이 생기는 특정 지점)와 (b) 가정된 해법(5개 고정 카테고리에서의 설명 총량 증가 + 그 이행을 자가기록)을 혼동한다. (b)는 landscape 문헌이 경고하는 alert fatigue를 유발해 정작 필요한 신규 정보가 boilerplate '설명함' 기록 속에 묻힐 위험이 있고, 그 기록 주체가 설명 주체와 동일해 Law 2/AP3가 이미 금지한 self-approval과 형태가 같으며, '결정론 게이트는 보안/정확성에만' '하니스를 무겁게 만들어 능력 제한 금지'라는 사용자 자신의 상시 원칙과도 정면 충돌한다."
> confidence: 0.78
> ```
>
> ### 요청하신 세 갈래에 대한 보충 설명
>
> **1) 양·빈도를 늘리지 않고 Hidden Profile만 겨냥하는 대안이 존재하는가.**
> 존재합니다. `arXiv:2311.09144`(Grounding Gaps in Language Model Generations)와 `arXiv:2602.21337`(common ground 벤치마크)은 정보 비대칭이 대화 전체가 아니라 "새 정보가 상대의 인지 확인 없이 투입되는 특정 순간"에서 생긴다는 것을 실증합니다. 즉 개입 지점은 5개의 넓은 카테고리(결정 직전/판정 직후/에이전트 결과/능력 저하/착수·종료)가 아니라 **"이 용어·사실이 transcript에 처음 등장하는가"라는 단일 조건**이면 충분합니다. 이 조건이 참일 때만 1줄 정의+출처를 인라인으로 붙이면, 이미 그라운딩된 용어에 대한 반복 설명(=양 증가)은 아예 발생하지 않습니다.
>
> **2) 원장 없이 같은 결과를 얻는 기성 패턴이 실제로 존재하는가.**
> `draft.dev` 기술문서 스타일가이드 서베이가 확인하듯 "정의는 첫 등장에서만(define on first use)"은 acronym/jargon 관리의 업계 표준이며, 이를 시행하는 데 별도 추적 원장이 필요하지 않습니다 — 필요한 것은 "이 용어가 문서/대화 앞부분에 나왔는가"라는 **위치 검사** 뿐입니다. 이 리포 안에도 정확히 같은 형태의 선례가 있습니다: `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md`의 Coverage Ledger는 "5개 floor 차원이 논의됐는가"라는 **이진적·구조적 사실**만 추적해서 성공했습니다(MERGED #107). 반면 이번 원안의 "인지부채 원장"은 "설명이 됐는가"를 넘어 암묵적으로 "이해됐는가"까지 원장이 보증하는 형태로 흘러가기 쉬운데, 그건 애초에 grep 가능한 사실이 아니라서 이 선례의 성공 조건 밖에 있습니다.
>
> **3) 원장이 정말 필요한 좁은 조건.**
> 다음 조건이 모두 성립할 때만 원장급 장치가 정당화됩니다 — (i) 결정이 **되돌리기 어렵고**(irreversible) P17 게이트를 통과하며, (ii) 그 근거가 **여러 subagent/여러 compact 경계를 넘나들어** 사용자가 그 출처를 재구성하기 어렵고, (iii) 원장이 "설명했다"는 자기주장이 아니라 **"이 게이트 옵션에 등장한 고유명사가 transcript에 선행 등장했다"는 grep 가능한 산출물**만 기록하는 경우. 이 세 조건을 좁게 만족하는 범위(P17 게이트 한정, self-report 아닌 구조적 검사)로 축소하면, 이는 사실상 이미 존재하는 Law 2/R6 runtime-verifier 패턴("주장이 아니라 산출물을 외부에서 확인")의 재사용이지 새로운 카테고리의 원장이 아닙니다.

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-08-04, 최종) — failures 0 / payload 본문 174줄 (예산 137·트립와이어 150 초과 advisory 1건, 차단 아님). 리뷰 중 총 8회 실행, 1회 red(§4 uncited landscape) → 수정 후 green
- check_brief.py gate — pass (2026-08-03) — 1회차 통과, failures 0 / advisories 0 / payload 본문 103줄
- check_verbatim_coverage.py — exit 0 (2026-08-03) — 3회 실행: ①exit 3(검사 불가, 상태 복구 시 flow-mapping 축약으로 파싱 실패) → 블록 형식으로 수정 → ②exit 1(not_contained: S1 — 복구 과정에서 작은따옴표 누락) → 원문 정렬 → ③exit 0(missing 0 / not_contained 0)

## 5. 프로세스 로그

- round 0: path (a) — 리포 지형 실측. 플러그인 4 / 명령 7 / 스킬 7 / 에이전트 17 / hook 파일 22. "인지부채" 문자열 0회 등장.
- round 1: path (b) — 설명 매체 질문. 사용자 선택: 대화창 실시간 발화(S1). teach-heavy(in-repo prior art 인용).
- round 2: path (b) — 설명 밀도 질문(L1~L4 실측 표 제시). 사용자가 선택지 자체를 재구성 요구(S2) — 명령 단위 기각, 시멘틱 순간으로. "훅 발화" 용어 미설명을 사용자가 지적(이번 주제의 실물 사례).
- round 3: path (b) — 필수 순간 묶음 선택. A+B+C 선택 + M4 탐지 방법 질의 + UX 관점 재도출 요구 + 플러그인 배치 구상(S3). mid-turn으로 S4·S5 수신(배치는 주 컨텍스트 아님).
- round 4: path (c)+(b) — steelman-builder 순차 dispatch(ST1) → R3 skepticism 게이트. 사용자가 grep 구조검사 명시 기각 + 문제 정체 재정의(S6). 이어 모델의 2차 재정의도 기각(S7·S8).
- round 5: path (b)+(a) — 문제 정체 4겹 확인(S9, 전부 선택) + "외부 검색으로 용어 확인" 지시 → landscape 재개방·sweep2 실행. 사용자가 원장 집착 지적(S10·S11), 용어를 이해부채로 확정(S12).
- round 5': path (c) — blind-spot-prober dispatch(fan-out 1, C8). premortem 4건 표면화.
- round 6: path (b) — 결핍의 정체 질문("설명 부재냐 개입 곤란이냐") → 사용자가 제3의 답(S13: 속도 불일치). 이어 초반 방향 복귀 지시(S14·S15).
- round 7: path (b) — 모델이 제시한 "성공 기준 교체"를 사용자가 기각(S16). 정정된 7행 표를 사용자가 수용(S17).
- round 8: path (b) — 적용 범위 질문. 사용자가 산출물 형태를 확정(S18: 플러그인을 만드는 것이 목표) + 배치 확정(S19: project-init 확장).
- round 9: path (b) — 스코프 정련(큰 범위·devbrew 대상) + 새 제약 2건(억제 금지·토큰 비용) + brief 작성 방식 설명 요구(S20).

### 사건 기록 — 상태 파일 조용한 소실 (2026-08-03)

세션 정리 훅이 `.claude/spec-distill/a1797a3f-.../state.local.md`를 삭제. payload는 `docs/` 하위라 생존.
상태(원장 + 발화 20건 + 예산 카운터)는 대화 컨텍스트로부터 전량 재구성했고, 사용자에게 사실대로 보고함.
★ 이 사건 자체가 이번 설계 주제의 실물 사례 — 조용한 소실을 사용자가 알 방법이 구조적으로 없었음.
기존 메모리 `project_spec_distill_state_storage_redesign`의 TTL-GC silent delete와 동일 계열 결함.

### brief 리뷰 라운드 (reviewing-brief, v0.24.0)

- 방향성: Claude 10건 / codex 7건 — 6개 결정 클러스터로 묶어 사용자에게 상신, **사용자 재결정 4건**
  ([A] 대화창=표시·파일=정본 / [B] C15 유지 + 빠짐없음 정의 확장 / [C] S6의 grep 기각 철회 / [D] 수단 비교 필수).
  나머지 2 클러스터(E: subagent 표면화·플랫폼 차집합, F: 배치·재귀 경계)는 OQ2·OQ6·OQ7·OQ8로 이월.
- 충실도 기록(게이트 아님, 마지막 관측 verdict만 기재): **needs_revise** — critic 15+14 / codex 11+6+6.
  라운드 0: fidelity_verdict=needs_revise (critic 15, codex 11, 합집합 26) → 근본 원인 = §6에 선택지
  라벨만 기록하고 질문·설명문을 누락 → S22~S26(선택지 전문) append로 해소 + 제약 12건 교정 + C24·C25 신설.
  라운드 1: codex 6 → 수정(C4·C14·C23 복원, S27 최초 요청 append, C26~C30 신설) → codex 6 → 수정
  (C7·C8·C10·C20·C30) → fresh critic 14(high 2) → **high 2건만 수정하고 루프 의도 정지**.
  미반영 12 medium은 Step B 상신. 재리뷰 카운터 1/2 (상한 미도달, 의도적 조기 정지).
- 냉독: G1~G5 형식 gap 0건. 대신 **문서 자체 결함 4건**을 별도로 보고 —
  ① "7개 의미 순간"의 근거 표가 문서에 부재(수치만 반복) ② 기각된 라벨 M4를 OQ9가 그대로 사용
  ③ 원장 스코프 미정리(C6·C7·C24·C25·OQ3이 상충) ④ OQ 번호 순서 뒤섞임. **4건 전부 수정**
  (7행 표 삽입 / 라벨 제거 / OQ10 신설 / 순서 정렬).
  ★ compounding 후보 — **G6: 문서가 자기 안에서 검증 불가능한 수치·라벨을 사용**. 기존 5 클래스 밖.
- degrade: (아래 §degrade 원장 참조 — 6건)
- 격리: zero-tool probe **ZERO_TOOL_OK** (docs/audits/2026-07-27-...:121). 단 세션 에이전트 목록은
  brief-critic·brief-readback을 "All tools"로 표시해 상충 — agent 파일 실측은 `tools: []`.
  `codex_isolated: false`.

### degrade 원장 (Step B 게이트에 전량 상신)

1. pipeline/all — 격리 표시 상충(파일 `tools: []` vs 세션 목록 "All tools"). probe 판정을 따르되 보고.
2. critic/fidelity — codex 충실도가 라운드마다 서로 다른 결함을 냄(11→6→6). 수렴 미확인.
3. pipeline/all — payload 본문 174줄, check_brief 예산 137 / 트립와이어 150 초과(차단 아님).
4. critic/fidelity — critic 라운드2 프롬프트의 §4를 압축 전달(토큰 비용 C21). 충실도 축은 전문 전달.
5. critic/fidelity — 충실도 루프를 라운드1에서 의도 정지. high 2건만 수정, 12 medium 미반영 상신.
6. readback/readback — 냉독 프롬프트도 §2·§4·§6를 압축 전달. 그 결과 냉독이 "S앵커 실제 내용을 볼 수
   없었다"고 보고 — §2·§6 관련 gap 판정은 그만큼 낮게 읽을 것.

## 6. Step B 결과

- 사용자 선택: **① 확정하고 /compact 후 brainstorming**
- 확정 18건 / 잠정 유지 12건 (리뷰어 미해결 findings 대상 항목)
- sentinel 제거 완료, 게이트·원문대조 재실행 모두 green
- 미반영 findings 12건(medium)은 사용자에게 이유와 함께 상신했고, 사용자가 이 상태로 진행을 선택
