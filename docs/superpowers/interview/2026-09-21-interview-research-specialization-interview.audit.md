---
type: interview-audit
payload: 2026-09-21-interview-research-specialization-interview.md
created_at: 2026-09-21
session_id: 7bc9d757-29d7-4b30-b205-200e26661f94
source: spec-distill conducting-interview v3.2.0
---

# 인터뷰의 조사 특화 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성 동의: 결핍은 소비자 부재가 아니라 셋(하한 부재 · §5 누수 · 마커 미채택) (@S7) (재개방 1회 — 전수 재측정이 닫힘 근거와 충돌: brief 11개 중 6개에 리포 인용 23건이 실재하고 15건은 하류 보존 목록 안이다)
- floor:landscape — closed — 외부 근거 처분: 충돌 셋 전부 취함 + decision-first 를 steelman trigger 로 승격, ST1 에서 kiro 일반화가 [피함]으로 전환 (@S9) (재개방 1회 — spec-kit 에 전용 조사 단계가 실재해 「베낄 레퍼런스가 없다」가 반증됨)
- floor:skepticism — closed — steelman 판정: ST1 verdict refined, 근거 부착 11/11 · 리포 주장 확인 11/12 (@S9)
- floor:blind_spot — closed — 숨은 가정 7 + 실패 양식 7 처분: H1 수용해 진단 갱신, 축 형태 재도출, 리듬 압착과 sealed decision 을 Open Questions 로 박제 (@S7)
- floor:open_questions — closed — OQ 목록 확인: A 설계 7 · B 사용자 미답 3 · C 범위 밖 2, 총 12건 그대로 확정 (@S11)
- derived:internal_research_apparatus — closed — 내부 조사 장치의 형태(대칭 이식이냐 고유 도출이냐); 외부 3종 대칭 + 전담 장치, 단 «전담»의 판별은 ST1 에서 도구 부분집합이 아니라 출력 의무로 교체됨 (@S5)
- derived:enforcement_level — closed — 강제 수준을 근거로 확정(사용자가 명시 위임); 소비자 요구에서 도출 → 차원 + 절 + 게이트, 그리고 Phase 0 메뉴에 없던 네 번째 값(하류 인계 프롬프트·보존 목록 수정) (@S5)
- derived:depth_termination — closed — 여러 겹의 종료·재개 조건; 재개 조건은 「그 항목이 닿는 결정이 아직 열려 있는가」이고 리듬 가드 압착의 대가는 계수 방식에서 지불한다 (@S10)
- derived:handoff_contract_reach — closed — 인계 형식 수정이 Phase 1 경계 안인가; 대상 자산 전부가 Phase 1 파일이고 밖인 것은 편집 불가한 소비자 플러그인뿐이라 경계 안이다 (@S5)
- derived:success_criterion_vs_postmeasure_ban — closed — 성공 확인 방법과 사후 측정 금지의 양립; 확인은 새 장치 없이 기존 §5 verdict 항목과 §3 Open Questions 로 하므로 만드는 것이 아니라 읽는 것이다 (@S8)

## 2. Budget

- 질문 라운드: 10 · agent dispatch: 9 · coverage-mapper 1 · codex 실호출: 2 (성공 2)

(agent dispatch 9 의 내역 — coverage-mapper 1 · Explore 1(orchestrator 재량, 내부 조사 장치
실측) · blind-spot-prober 1 · steelman-builder 1 · doc-critic-web 2(리뷰 라운드 1·2) ·
doc-recritic 2(리뷰 라운드 1·2) · brief-readback 1. 라운드 2 탐지의 규약-펜스 재출력은 같은
agent 를 이어 부른 것이라 새 dispatch 로 세지 않았다. codex 실호출 2 는 리뷰 라운드 1·2 의
`run_docreview_codex_reviewer.sh` 이고 둘 다 `runner_rc=0` · codex-cli 0.154.0. 인터뷰 본체의
질문 라운드 10 외에 리뷰 게이트 질문이 4회 더 있었다(라운드 1 게이트 3회 분할 + 멈출 지점 1회).)

## 3. Steelman 원문

#### ST1 — 다섯 축 전부 가산하는 방향 vs 조사 항목에 «닿는 결정»을 부착하는 방향

**dispatch 입력** — goal: S8 원문 · 전제: P1 인터뷰가 조사 책임 주체이고 내부·외부를 최대치로(S1) · P2 하류 슬롯 단정 금지(S1) · P3 네 국면 전부(S1) · P4 결핍 셋(S7) · P5 강제 수준은 소비자에서 도출(S3) · P6 경량성으로 축 삭제 금지(S4) · P7 사후 측정 금지(S1) · P8 문제공간이 밀리면 실패(S1) · P9 Phase 1 한정(S1) · P10 성공은 영향 셋(S8) · 제약: S1–S8 원문 전량 · trigger: landscape 모순(decision-first 가 가산적 다섯 축과 충돌), 보조로 복잡도 비례 예산과 spec-driven 툴의 조사 단계 부재 주장

> **case_for_alternative.statement**: 조사 장치를 한 자리 더 늘리는 대신, 모든 조사 항목이 «어느 열린 결정을 바꿀 수 있는가»를 달고 오게 만든다 — 이미 steelman 한 자리에만 있는 부착 계약(`evidence[].touches` · `repo_claims[]` path+anchor)을 나머지 조사 자리(§4 landscape · §5 premortem · 경로(a) 내부 사실)로 일반화하고, 재개 조건과 게이트 술어를 그 부착으로 잡는다.
>
> **case_for_alternative.strongest**: goal(S8)은 조사가 방향에 «영향»(바꿈·보강·지지)을 주는 것이고, 영향은 항목이 어느 결정에 닿는지가 적혀 있을 때만 판정된다 — 부착은 산출 시점에 산출자가 쓰므로 P7(사후 측정 금지)을 지키고, S8의 세 결과는 이미 리포에 있는 verdict 어휘(유지/보완/전환)와 1:1이다.
> 리포가 결핍의 정체를 실증한다: 세 agent 전부 이미 `tools: Read, Grep, Glob, WebSearch, WebFetch` 를 갖고 있어 내부 조사에 없는 것은 «능력»이 아니라 «의무»다(steelman-builder 만 `repo_claims` path+anchor 를 요구하고, blind-spot-prober 는 "(가능하면) codebase grep" 한 줄, coverage-mapper 는 앵커 요구 0). 능력이 이미 있는 자리에 네 번째 능력을 더하면, `[from-code]` 마커가 SKILL.md 한 줄에만 살고 채택 0건인 것과 똑같이 «읽는 자리 없는 네 번째 선언»이 된다(P4c 가 그 실패를 이미 측정했다).
> 성숙한 레퍼런스의 형태도 결정-키잉이다: spec-kit Phase 0 은 조사 과제를 "For each NEEDS CLARIFICATION → research task" 로 «열린 결정 하나마다» 도출하고 산출을 Decision/Rationale/Alternatives 로 적는다 — 「조사를 많이」가 아니라 「조사를 미결 결정에 묶기」가 그 툴의 구조다.
> 그리고 비용 쪽이 결정적이다: 새 floor 차원 하나는 "차원은 그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다" 때문에 종료 전 «필수 사용자 라운드 하나»를 더 만들고, 그 라운드는 조사-에 관한-조사 질문이라 P8 이 금지한 「문제공간 질문을 밀어냄」의 정확한 발현이다. 부착 일반화는 라운드를 늘리지 않는다.
>
> **case_for_current.strongest**: 같은 기준에서 **존재하지 않는 항목은 어느 결정에도 영향을 못 준다** — P4(a)의 측정(11 brief 중 5가 내부 인용 0건, 편차 0–8)은 부착 계약이 손댈 수 없는 자리다. 부착은 항목이 있다는 전제 위에서만 작동하고, 0→≥1 을 움직이는 술어는 하한뿐이다. 대안을 이 지점에 적용하면 「0건인 브리프는 부착할 항목이 없으니 공허하게 통과」가 되어, goal 기준으로 다섯 중 다섯이 그대로 남는다.
> 리포는 산문 선언이 발화하지 않음을 **두 번** 실증했다(C43 `[from-code]` 0건 · C9/C24 `repo_claims` 미채택). 즉 대안이 의지하는 「부착을 요구한다」도 산문으로 내면 세 번째 0건이 된다 — 부착이 이빨을 갖는 유일한 길이 ②③(하한 + 게이트)이고, 이것이 Law 1 의 «silent skip 불가»가 요구하는 것이다. 대안은 축을 대체하지 못하고 축의 «술어»를 고치는 제안일 뿐이다.
> ④는 논박이 없다: compaction 은 "architectural decisions" 를 남기고 "redundant tool outputs" 를 버리며, finishing.md:259 는 «web sweep 원문·steelman 중간 추론은 drop» 을 **명시적으로 지시한다**. 이름 없는 절은 버릴 축이다 — §4·§5 를 지명하지 않으면 인용(URL·path+anchor)은 구조적으로 강조에서 탈락한다.
> ①의 형태에도 prior-art 가 있고, trigger 의 보조 근거 하나는 사실이 아니다: Anthropic 대형 코드베이스 가이드는 "Some teams spin up a read-only subagent to map a subsystem and write findings to a file, then have the main agent edit with the full picture" 를 팀 패턴으로 적고, spec-kit 은 전용 조사 단계(Phase 0)에서 "Generate and dispatch research agents" 를 규정한다 — 「성숙한 spec-driven 툴에 베낄 레퍼런스가 없다」는 Kiro 한 곳만 본 결론이고, Kiro 자신도 상류(requirements)에 전용 분석 장치("Analyze Requirements … catches logical inconsistencies, ambiguities, conflicting constraints, and gaps")를 둔다.
>
> **premise_refutation** — hits: [P1]. P1 의 문장 "내부(레포) 조사와 외부(웹) 조사를 둘 다 **최대치로** 해내야 한다" 중 «최대치»를 목표로 두는 부분이 세 출처와 정면 충돌한다. (i) Anthropic multi-agent research system 은 배분을 복잡도 비례로 규정한다 — "Simple fact-finding requires just 1 agent with 3-10 tool calls, direct comparisons might need 2-4 subagents with 10-15 calls each, and complex research might use more than 10 subagents". 최대치가 아니라 규모-맞춤이 처방이고, 과대투자는 과소투자와 **나란히** 실패로 이름 붙는다. (ii) effective context engineering 은 목표를 최소-충분으로 명시한다 — "Find the smallest set of high-signal tokens that maximize the likelihood of your desired outcome" · "Every new token introduced depletes this budget by some amount". (iii) 대형 코드베이스 가이드는 «최대치»를 한쪽 실패 사면으로 적는다 — "Too much context loaded into every session degrades performance, while too little context leaves Claude to navigate blind."
> 충돌은 어휘가 아니라 하중이다: ⑤의 재개 조건이 «최대치»에서 도출되면 「한 겹 더」가 무조건 선이 되지만, 세 출처가 강제하는 도출은 「아직 열린 결정이 있을 때만 한 겹 더」다. P1 의 나머지 두 성분(인터뷰가 조사의 책임 주체 · 내부와 외부 둘 다)은 반증되지 않는다 — 반증된 것은 **수준어 하나**이고, 그 하나가 ⑤와 ②의 형태를 결정한다.
>
> **premise_list_challenge**: 셋.
> (1) **빠진 전제** — «조사 항목은 어느 결정에 닿는지를 적는다»가 P1~P10 어디에도 없다. P3 가 「결정에 안 닿는다」를 네 국면 중 하나로 세고 P10 이 성공을 세 영향으로 정의하는데, 그 둘을 잇는 전제가 없어서 다섯 축이 전부 가산적으로만 도출됐다. 이것이 trigger 가 가리킨 공백의 정확한 좌표다 — 축의 개수 문제가 아니라 전제 목록의 구멍이다.
> (2) **P5 는 ①의 «형태»를 지지하지 않는다** — P5 는 강제 수준을 「소비자가 읽으려면 무엇이 보장돼야 하나」로 도출하라 한다. 그 도출의 입력인 내부 조사 «능력»은 이미 세 agent 전부에 있다. 소비자에서 도출되는 것은 도구 목록이 아니라 출력 의무(path+anchor+닿는 결정)다. S1#10 의 «전담 장치»는 유지돼야 하지만, «전담»을 도구 부분집합(`Read, Grep, Glob`)으로 정의하면 기존 세 자리 중 둘은 계약 밖에 그대로 남고 새 파일은 로드 표면만 늘린다.
> (3) **P4(b)의 심각도가 과대다** — 옵션 ②는 "compact 없이, 전체 context 유지"라 보존 목록 자체가 없고(그래서 방향문의 「:271-277 옵션 ② 호출 프롬프트가 §0·§2·§3·§6(S1) 만 지명한다」는 부정확 — 271-277 은 절을 하나도 지명하지 않고 C4·순서 문장만 싣는다), 옵션 ①도 `<brief-path>`를 넘겨 §4·§5 는 디스크에 남는다. 즉 §5 누수는 «산출물 소실»이 아니라 «강조 소실»이다. ④는 한 줄이라 유지가 옳지만, 그것이 8건을 해소하는 축이라고 읽으면 남는 결함(하류가 그 절을 읽을 «이유»가 없음)이 가려진다 — 그 이유를 만드는 것이 부착이다.
>
> **recommendation**: refined
>
> **refined_takes**: 다섯 축의 «자리» 전부 유지. ④ 그대로(반박 0 · 한 줄 편집 · compaction 근거가 직접 뒷받침). ②③ 구조로 유지 — 산문 무발화가 리포에서 두 번 실측됐으므로(P4c) 부착을 산문으로 요구하는 것은 세 번째 0건이 되고, Law 1 의 구조 게이트만이 이빨을 준다. ① 전담 내부 장치 유지(S1#10 · read-only mapping subagent prior-art). ⑤ 유지 — 재개 자체는 이미 리포에 있으므로 새 발명이 아니라 그 트리거의 확장으로 도출된다.
>
> **refined_drops**: (i) **«최대치»를 목표로 삼는 것** — ⑤의 재개 조건을 횟수·최대치가 아니라 「그 항목이 닿는 결정이 아직 열려 있는가」로 도출한다. 진단 문장도 고쳐야 한다: 「현행 조사 장치는 전부 1회-상한」은 사실이 아니다(coverage_mapper 상한 2 · landscape 는 ≥1 하한 · 재개방 상한 없음). 정확한 결함은 **차원 재개방은 무제한인데 그 차원을 채우는 장치는 1회 하드캡이라 재개방이 빈손으로 돈다**(`blind_spot_dispatched` 재dispatch 금지)이고, 이것이 ⑤가 고칠 진짜 이음매다.
> (ii) **①의 «전담»을 도구 부분집합으로 정의하는 것** — 전담의 판별을 출력 의무(`repo_claims` path+anchor + 닿는 결정)로 바꾸고, 같은 의무를 blind-spot-prober · coverage-mapper · 경로(a) 자동확인에도 동시에 건다. 그렇지 않으면 내부 조사는 세 자리 중 한 자리만 계약된 채로 남는다.
> (iii) **②③의 술어를 「있는가 · 몇 건인가」로 두는 것** — 게이트 술어를 항목마다의 부착(∀)으로 한다. 선례가 같은 파일에 있다: `#13 — §4 항목마다 «출처키»가 있는가. **∀다**` — 개수가 아니라 항목별 필수 필드라서 P7(사후 측정 금지)을 위반하지 않는다. 그리고 6번째 **floor 키는 피한다**: `FLOOR_KEYS` ∀-루프가 fail-closed(`floor:{key} row missing`)라 기존 audit·픽스처 전량을 red 로 만든다. `derived:` 행은 같은 파서가 받되 ∀-필수가 아니므로, 「93 픽스처를 안 건드리는 하한」은 `derived:` 축에서 도출되는 것이 구조적 사실이다.

**게이트-전 확인** — repo_claims 12건 중 11 확인 · 1 미확인: 세 조사 agent 의 동일 `tools:` 줄 확인(추가 관측 — `agents/doc-critic.md` 가 이미 `Read, Grep, Glob` 만 갖는다) · 부착 계약이 `agents/steelman-builder.md` 의 규칙 5·6 과 `references/steelman.md` Step 2 한 자리에만 존재 확인 · `agents/blind-spot-prober.md` 의 「(가능하면) codebase grep」 축자 확인 · `agents/coverage-mapper.md` 출력 스키마에 앵커 요구 0 확인 · `SKILL.md` 의 `from-code` 가 플러그인 전체 유일 1건 확인(grep 1) · 재개방 「상한 없음」·prober 하드 1회·mapper 2회차 재개방 조건부·landscape 「web sweep ≥1회」 하한 전부 확인 · 「차원은 그 차원에 관한 질문에 사용자가 답한 S 를 근거로만 닫는다」 확인 · `check_brief.py` 의 `FLOOR_KEYS` ∀ fail-closed 루프와 `derived:` 를 같은 파서가 받는 분기 확인 · ∀-술어 선례 `#13` 와 집합 결속 `N2` 확인 · `finishing.md` 의 「web sweep 원문·steelman 중간 추론은 drop」 명시 확인 · 옵션 ② 라벨의 "compact 없이, 전체 context 유지" 확인(그래서 orchestrator 의 dispatch 문면이 부정확했다는 지적이 맞다) · **미확인 1** = floor 리터럴 계수(builder 495/103 vs orchestrator 486/97 vs 워크트리 전체 627/120 — 범위·regex 마다 달라 확정도 반증도 못 했다. 「숫자를 파일 밖 기대값으로 고정하지 말라」는 주의는 타당하므로 §3 OQ7 로 올렸다) · 부착 주장: evidence 11건 전부 `touches` 비어 있지 않고 각 claim 이 지목된 전제와 대응 확인(11/11) · 재검토 자격: 열림 1건(P1)

**사용자 선택** — 보완 (S9)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-22) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-09-22) — `missing_ids: []` · `not_contained: []` · `advisories: []`

게이트 실행 이력(리뷰 라운드마다 진입 게이트로 재실행):
- Step A 1차: **fail** — `landscape keys not declared in audit §7: ['강조','검증해야 할 것','게이트','소실','전담 장치']`.
  원인은 §4 안에서 `«»` 를 강조로 쓴 것이다(게이트가 §4 의 모든 `«...»` 를 출처키로 읽는다).
  강조를 「」로 바꿔 해소. 같은 함정이 리뷰 라운드 1 의 fix 적용 후에도 한 번 더 발화했다(`['일반화']`).
- Step A 2차 · 리뷰 라운드 1 진입 · 라운드 1 fix 적용 후 · 라운드 2 진입 · 라운드 2 적용 후 — 전부 pass.

## 5. 프로세스 로그

- round 1: d — 진짜 문제의 재구성(비대칭 / 소비자 부재 / 결정 미연결 / 깊이) → 소비자 부재 선택
- round 2: a+b — seed 사실 주장 둘 반증 제시(범위 밖 확정 · 산문 출하 후 무발화) + 강제 수준의 도출 규칙 → 정정 수용 · 소비자에서 도출
- round 3: b — 내부 조사 결과의 소비자 지목 → 사용자가 프레이밍을 물렀다(「제약이라는 이름으로 구현을 회피하는 성향이 너무 싫은데»). 차원 미닫힘
- round 4: b — 네 축을 하나의 구현으로 재배치한 뒤 실제 구현 범위 → 네 축 전부. 세 차원 동시 닫힘
- round 5: a — 충돌하는 외부 근거 셋의 처분 + steelman trigger 승격 → 전부 취함 + decision-first 를 trigger 로
- round 6: a — 전수 재측정(brief 11개 · 인용 23건 · 절 분포)으로 root_problem 재개방, prober 출력 처분 → 진단 좁히고 축 형태 재도출
- round 7: b — goal 원문 확정(steelman Step 1 선행 요건) + 사후 측정 금지와의 양립 → 성공은 영향 셋으로 넓혀짐
- round 8: b — ST1 steelman 게이트(4-block) → 보완
- round 9: b — 리듬 가드 압착의 대가 지불 자리 → 가드의 계수 방식
- round 10: b — Open Questions 12건 확정 → 목록 그대로

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 2 · 재리뷰 카운트 1 · 추가 라운드 0 — 승인 게이트 도달 사유: **사용자 결정**(⟨S12⟩ 「라운드 2 로 끝낸다」 — 엔진 상한(재리뷰 2)은 미도달, `cap_reached: false`) · 리뷰 완료: 예(`round_reviewed: true` 두 라운드 모두, `unreviewed_reason: null`)
- 결정: `## 8. 리뷰 결정` **17건**(D1.1~D1.7 · D2.8~D2.17, 전부 adopt) · 열린 채 남은 항목 **0건**(`open_decide: []` · `ask_open: []`) · 미반영 findings 0건
- codex: **있음** — 2회(리뷰 라운드 1·2), codex-cli 0.154.0, `runner_rc=0` · `codex_failed: false` · 웹: Claude `doc-critic-web`(프로필 `web: true` + 스위치 꺼짐) · codex 켜짐
- 냉독: gap **1건** — G3(최상위 제약 누락): ⟨C3⟩(문제공간 탐색·질문·대화가 밀리면 실패)이 제약으로는 요약에 실리지 않고 OQ22 안에서만 등장, ⟨C7⟩·⟨C14⟩ 는 이름으로만. G1·G2·G4·G5·G6 = 0건. ★ 판정은 advisory 이고 blob rc 3 으로 신뢰도 하향. 냉독이 별도로 낸 하류 가독성 관측 둘(gap 클래스 밖이지만 인계 결함의 실물): ① ⟨S2⟩~⟨S12⟩ 앵커를 brief 안에서 확인할 길이 없다(§6 은 `S1` 만, 나머지는 audit §6 — 냉독은 audit 를 받지 않는다) ② 하니스 어휘(floor 차원 · `derived:` 축 · C44 압착 · `non_user_streak +0/+1` · AP16 · 「ST1 · 부착 11/11」)가 설명 없이 쓰여 「⟨C13⟩ 의 계수 방식이 왜 C44 압착의 대가를 지불하는 것인지 이해하지 못했다」 · OQ7 의 「세 번 재서 세 값」이 불분명하다
- degrade: **3건** — `critic`/`fidelity`/`degraded`(`build_brief_bundle` rc 3, 라운드 1·2 — payload 부분에 audit 파일명 잔존, 템플릿이 요구하는 `audit_file` 필드 자체) · `readback`/`readback`/`degraded`(`build_brief_inline_blob` rc 3, 같은 원인 — 냉독 gap 판정을 신뢰도 하향으로 읽는다) · `pipeline`/`all`/`degraded`(orchestrator 가 state 를 세션 tmp 사본에서 `cp` 로 덮어써 엔진이 추가한 `brief_review_degradations` 줄이 한 번 소실됐다 — 재`init` 후 재기록했고 라운드 1 시점의 원 기록 순서는 복원 불가)

**★ 라운드 2 적용의 기계 관측 부재 (공시)** — ⟨S12⟩ 로 라운드 3 을 돌지 않으므로, 라운드 2 에서
적용한 `fix` 9 + 채택 `decide` 7 의 적용은 **다음 라운드 `finalize` 의 스냅숏 diff 관측을 받지
못했다.** permit 은 `round: 3` 으로 발급됐고 소비되지 않는다(`consumed: false`). 라운드 1 의
적용분은 라운드 2 `finalize` 가 관측했다. 이 비대칭을 조용히 통과로 바꾸지 않는다.

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (네 국면을 만든 진짜 원인):
  > "소비자가 없다 — 진짜 문제는 조사의 «산출»이 아니라 «소비»다. 외부 조사는 읽는 코드가 있어 발화하고, 내부 조사는 마커를 읽는 자리가 0이라 침묵했고, 하류는 순수 프로즈라 아무것도 읽지 않는다. 처방 순서가 뒤집힌다 — «누가 읽는가»(소비 계약)를 먼저 정하고 그 역으로 조사 장치를 정한다. 네 축 중 「전담 장치」·「여러 겹」의 형태는 계약이 선 뒤에 결정된다."

- **S3** ☑ 선택 (seed 사실 주장 반증의 처분 + 강제 수준의 도출 규칙):
  > "정정 수용 · 강제 수준은 소비자에서 도출 — seed 의 사실 주장 둘(09-05 내부 절반 누락 경위 미확인 · 외부 절반만 확정)에 대한 반증을 받아들인다. 두 번의 산문 출하(C43 마커 · C9/C24 repo_claims)가 발화하지 않은 원인은 «산문이라서»가 아니라 «읽는 자리가 없어서»다. 따라서 강제 수준을 Phase 0 의 세 값(산문 지시·하한 하나·외부와 대칭) 중에서 고르지 않고, 소비자를 먼저 정한 뒤 «그 소비자가 읽으려면 무엇이 보장돼야 하나»로 도출한다. 산문이든 게이트든 미리 배제하지 않는다."

- **S4** 🗣 발화 (소비자 지목 질문에 대한 거부):
  > "근데 나는 제약이라는 이름으로 구현을 회피하는 성향이 너무 싫은데"

- **S5** ☑ 선택 (이번 사이클이 실제로 만들 범위):
  > "네 축 전부 — 내부 조사 전담 agent 신설 + floor 차원 신설 + brief 전용 절 + 게이트 + 하류 인계(보존 목록·호출 프롬프트) 수정, 여기에 «여러 겹»의 재개 조건까지. 대칭을 완전하게 메우고, 지금 22줄을 모으고도 하류로 안 가는 §4 External Landscape 도 함께 구제한다. 대가로 로드 표면이 가장 많이 늘고 다섯 자리를 동시에 건드려 이음매 결함 여지가 커지는 것을 받아들인다."

- **S6** ☑ 선택 (충돌하는 외부 근거 셋의 처분):
  > "전부 취함 + L7 을 trigger 로 — 충돌 근거 셋(L2 복잡도 비례 예산 · L7 decision-first · L9 표준 부재)을 전부 §4 에 [취함]으로 싣고, L7 을 steelman 의심 게이트로 올린다. «조사 장치를 더한다»와 «조사를 결정에 묶는다»는 같은 방향이 아니고 네 축은 전부 가산적이기 때문이다. L2 는 「최대치」 문구의 재해석 재료로, L9 는 «베낄 표준이 없다»는 사실로 기록."

- **S7** ☑ 선택 (전수 재측정 후의 진단 갱신):
  > "진단 좁히고 ①③ 형태 재도출 — 전수 재측정(23건/6파일, §3 10 · §5 8 · §2 5)이 「소비자가 없다」를 부분 반증했으므로 진단을 세 결핍으로 좁힌다: (a) 하한 부재(11 중 5가 0건) (b) §5 누수(8건이 보존 목록 밖) (c) 마커 규약 미채택(0건). 네 축은 전부 유지하되 각 축의 «대상»을 바꾼다 — 새 절 신설 대신 §3·§5 를 살리고, floor 차원은 픽스처 93을 안 건드리는 하한 형태로, 게이트는 「했는지」가 아니라 「닿는지」를 보는 검사로. C16 sealed decision 과 C44 압착은 Open Questions 로 박제."

- **S8** 🗣 발화 (goal = 성공 기준의 확정, 선택지 ①을 고르며 넓힘):
  > "1, 비슷하지만 조금 다른게 방향을 바꿀수도 있고 기존 방향을 보강할수도 있고 기존 방향을 지지할 수도 있어 바뀐다만을 넣으면 조금 위험하네"

- **S9** ☑ 선택 (ST1 steelman verdict):
  > "보완(refined) — ST1 판정. 다섯 축의 «자리»는 전부 유지하고 셋을 버린다: (i) 「최대치」를 목표로 삼는 것 → 재개 조건을 «그 항목이 닿는 결정이 아직 열려 있는가»로 도출 (ii) «전담»을 도구 부분집합으로 정의하는 것 → 출력 의무(path+anchor+닿는 결정)로 판별하고 같은 의무를 blind-spot-prober·coverage-mapper·경로(a) 자동확인에도 동시에 건다 (iii) 게이트 술어를 «있는가·몇 건인가»로 두는 것 → 항목마다의 부착(∀)으로 하고, 6번째 floor 키 대신 derived: 축에서 하한을 도출. 진단 한 줄도 교체: 「현행 조사 장치는 전부 1회-상한」(거짓) → 「차원 재개방은 무제한인데 그 차원을 채우는 장치는 1회 하드캡이라 재개방이 빈손으로 돈다」."

- **S10** ☑ 선택 (리듬 가드 압착의 대가 지불 자리):
  > "가드의 계수 방식 — C44 rhythm-guard 압착의 대가를 가드의 «계수 방식»에서 지불한다. 부착이 밝힌 조사는 non_user_streak 를 올리지 않는다(그 probe 의 산출 항목이 «닿는 열린 결정»을 달고 있으면 +0, 없으면 +1). 면제 조건이 산출물에 적히므로 가드가 눈멀지 않고 기계 검사가 가능하며, 상한은 «열린 결정의 개수»가 자연히 준다 — 결정이 다 닫히면 조사도 멈춘다. 임계값 상향(보안-민감 범주)도, probe 내부로 숨기기도, 하드캡만 풀기도 택하지 않는다."

- **S11** ☑ 선택 (Open Questions 목록 확정):
  > "목록 그대로 확정 — 12건을 A(설계가 정할 것 7) · B(사용자 미답 3) · C(범위 밖이지만 흔들 수 있는 것 2) 으로 분류해 그대로 §3 에 박제한다. floor 5 전원 closed 가 되어 바로 brief 작성으로 간다."

- **S12** ☑ 선택 (brief 리뷰의 멈출 지점 — 라운드 1 20건 · 라운드 2 16건으로 수렴하지 않는 상태에서):
  > "라운드 2 로 끝낸다 — 재비판으로 오탐을 걸러 확정된 충실도 fix 만 적용하고, 방향 항목(c15 레포 조사가 이미 Phase 0 의 역할 · c17 이미 폐기된 auto-confirmed 범주의 실패 양식 등)은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다. 라운드 3 은 돌리지 않는다. brief 는 문제공간 산출물이니 열린 것을 넘기는 것이 제 일이다."

## 7. 확산 원자료

- «anthropic-multiagent» — https://www.anthropic.com/engineering/multi-agent-research-system — 복잡도 비례 예산 · subagent 에 줄 네 요소 · 고정 출력 스키마와 artifact 인계 · 토큰 배수 · 코딩 과제의 병렬성 한계
- «agentic-rag-ablation» — https://arxiv.org/pdf/2606.21553 — retrieval loop 1-step 축소가 단일 컴포넌트 최대 성능 하락, bounded iterations 가 비용 완화
- «prism-multihop» — https://arxiv.org/pdf/2510.14278 — single-hop 대비 multi-hop 정확도 붕괴, 초기 풀 부재 시 복구 경로 없음
- «context-engineering» — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — 최소-충분 목표 · 토큰 예산 고갈 · compaction 이 남기는 것과 버리는 것 · JIT 경량 식별자 패턴
- «claude-large-codebases» — https://claude.com/blog/how-claude-code-works-in-large-codebases-best-practices-and-where-to-start — read-only subagent 로 서브시스템 매핑 후 파일에 기록하는 팀 패턴 · 컨텍스트 과다/과소 양쪽 실패
- «spec-kit-plan» — https://github.com/github/spec-kit/blob/main/templates/commands/plan.md?plain=1 — Phase 0 Research 실재 · 열린 질문 하나마다 조사 과제 · Decision/Rationale/Alternatives 산출 형식 · research.md
- «kiro-best-practices» — https://kiro.dev/docs/specs/best-practices/ — 전용 조사 단계 부재하나 상류 요구사항에 전용 분석 장치 존재
- «analysis-paralysis-trueu» — https://trueu.ai/what-analysis-paralysis-actually-costs-you/ — AI 는 선택지를 열도록 설계됐다 · decision-first 처방
- «analysis-paralysis-minware» — https://www.minware.com/guide/anti-patterns/analysis-paralysis — 분석 마비를 anti-pattern 으로 명명
- «llm-analysis-paralysis» — https://cfo.university/library/article/llm-analysis-paralysis-southekal — LLM 이 분석 마비를 증폭시키는 경로
- «voi-analysis» — https://umbrex.com/resources/frameworks/decision-making-frameworks/value-of-information-analysis/ — 결정을 바꿀 수 있는 정보만 값이 있다
- «decision-quality-chain» — https://www.argumentree.com/blog/decision-quality-chain/ — 여섯 고리의 약한 고리가 상한을 정한다
- «no-results-not-absence» — https://tianpan.co/blog/2026/04/23/no-results-is-not-absence-agent-retrieval-negation — 검색 0건을 부재 증명으로 읽는 실패
- «goodhart-strong-weak» — https://arxiv.org/pdf/2505.23445 — 대리 지표가 목표를 대체할 때의 붕괴
- «instruction-stacking» — https://arxiv.org/abs/2608.12426 — 동시 제약 5–6 초과 시 지시 준수 비선형 붕괴
- «instruction-complexity-cliff» — https://tianpan.co/blog/2026/04/17/instruction-complexity-cliff-llm-compliance — 지시 복잡도 절벽
- «rag-knowledge-conflict» — https://arxiv.org/html/2602.08221 — 부분 일치 증거에서 parametric prior 로 회귀
- «dogfooding-limits» — https://www.koji.so/docs/product-dogfooding-guide — 팀은 사용자가 아니다
- «structure-beats-prose» — https://medium.com/@stefanvanegmond/structure-beats-prose-specs-for-coding-agents-that-actually-work-e035929b0f3d — 산문 skill 의 약한 실행 제약
- «formal-skill» — https://arxiv.org/html/2605.19604v1 — 절차 지식을 프롬프트에서 스키마로 옮기기
- «compliance-theatre» — https://www.int-comp.org/insight/the-theatre-of-compliance/ — 형식 준수가 내용 소비를 대체할 때
- «stale-citation-validator» — https://github.com/launchpad-26/buzz/issues/1459 — 인용 검증기가 존재하지 않는 줄을 통과시킴
- «claude-code-subagents» — https://code.claude.com/docs/en/sub-agents — read-only 코드베이스 탐색 agent 와 계획 전 조사 agent 기본 탑재
- «deepwiki» — https://www.aitidbits.ai/p/deepwiki — 리포 위키를 grounding 층으로, 출력이 소스 파일·행에 연결되는지가 실행가능성을 가른다
- «code-wiki» — https://medium.com/@dipakkrdas/code-wiki-llm-maintained-documentation-for-your-codebase-fc54f94bef6d — LLM 유지 코드 위키
- «mastra-context-engineering» — https://mastra.ai/articles/context-engineering — artifact 로 통신, 하류가 쓸 수 있는 것만 표면화

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 6705a285#r1.1 · "채택(적용)" — §1 Goal 이 S8 의 넓힘(바꿈·보강·지지)은 옮기면서 S1 이 성공 기준에 붙인 판별선 「모아만 놓는 조사와 갈리는 지점이다」를 빼 버려, 지지만으로도 성공이 되는 현재 문구가 수집-only 조사와 구별되지 않는다 — 보호 부류(Goal)라 사용자 결정이 필요하다.
- D1.2 · r1 · adopt · abf668a4#r1.1 · "채택(적용)" — 인계 축의 대상(=/compact 보존 목록 · 옵션 ② 호출 프롬프트)이 채널을 잘못 겨눈다 — 하류는 brief **파일 경로**를 받아 §5 를 포함한 전문을 읽을 수 있고(그래서 「§5 8건이 죽는다」는 과대 진술), 반대로 보존 목록은 사람이 복사하는 산문이라 고쳐도 도달이 강제되지 않으며 옵션 ② 경로에는 목록이 적용조차 되지 않는다 — 대상을 「brief 파일 안의 자리」로 바꿀지 결정이 필요하다.
- D1.3 · r1 · adopt · abf668a4#r1.2 · "채택(적용)" — C13(부착이 밝힌 조사는 `non_user_streak` 를 올리지 않는다)의 근거로 S10 이 든 「기계 검사가 가능하며」가 현행 리포에서 거짓이다 — streak 는 세션 state 마크다운에만 있고 게이트는 state 를 읽지 않는다는 불변식을 명시하므로, AP16 가드의 면제는 조사를 수행한 같은 모델의 자기 신고에 놓인다 — 면제를 모델 재량으로 둘지, 게이트 불변식을 깨서라도 기계화할지(=C5 와 충돌) 사용자가 정해야 한다.
- D1.4 · r1 · adopt · abf668a4#r1.3 · "채택(적용)" — C12 가 하한의 집을 `derived:` 축으로 옮겼는데 리포의 그 축은 `- derived: N/A` 한 줄로 전량 만족되고 derived 행에는 closed 요구가 없으며 admit 권한이 피검자(orchestrator)에게 있어 하한이 「영(零)으로 선언 가능」하다 — C12 를 유지하고 그 대가를 설계에 넘길 것인지, 6번째 floor 키(픽스처 대가)를 재고할 것인지 결정이 필요하다.
- D1.5 · r1 · adopt · abf668a4#r1.5 · "채택(적용)" — 확정 둘이 충돌한 채 처분이 없다 — C5 는 「조사를 했는지를 나중에 재는 장치는 만들지 않는다」이고 축 «게이트»는 brief 산출 뒤 항목마다 부착을 세는 사후 형식 검사인데, 문서는 이 충돌을 §5 위험으로만 적고 §3 OQ 로도 올리지 않았다 — 충돌 시 어느 쪽이 양보하는지 사용자가 정해야 한다.
- D1.6 · r1 · adopt · abf668a4#r1.7 · "채택(적용)" — C9 는 decision-first 를 steelman 의심 게이트로 올리는데, 그 게이트는 trigger 조건부이고 `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 이면 dispatch 자체가 생략된다 — 웹을 요구하지 않는 내부 조사의 검문소를 웹 스위치와 trigger 발화에 종속시킬 것인지, 무조건 도는 자리(라운드 규약·check_brief.py)로 옮길 것인지 사용자가 정해야 한다.
- D1.7 · r1 · adopt · abf668a4#r1.8 · "채택(적용)" — C8 은 「내부 조사 전담 agent 신설」을 확정하지만 C12 가 «전담»의 판별을 출력 의무로 바꾸고 같은 의무를 기존 세 자리에 동시에 걸기로 해 신설 파일이 더 주는 것이 남지 않는데(플랫폼은 read-only Explore subagent 를 이미 기본 탑재) — 축 «전담 장치»의 자리를 새 agent 파일로 채울지, 기존·기본 탑재 장치의 배선 + 출력 의무로 채울지 사용자가 정해야 한다.
- D2.8 · r2 · adopt · 68cb940d#r2.1 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — ⟨C8⟩(다섯 자리 동시 가산) · ⟨C3⟩(되묻기·문제공간 탐색이 밀리면 실패) · §4 의 instruction-stacking(5–6 초과 시 비선형 붕괴, 기계 검사 없는 것이 먼저 탈락)은 동시에 성립할 수 없는데 OQ6 은 「무엇을 뺄지」를 설계에 넘긴다 — 인터뷰의 기존 장치·제약을 빼는 권한을 설계에 줄 것인가, 아니면 다섯 중 무엇을 이번에 연기할지 지금 고를 것인가?
- D2.9 · r2 · adopt · 68cb940d#r2.2 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — §4 가 prior art 로 취한 spec-kit 의 전용 조사 단계는 «인터뷰/specify» 가 아니라 하류 «/plan» 안에 있고 조사 과제를 spec 의 미해결 unknown 에서 도출한다 — 조사 장치를 §3 Open Questions 에 키잉해 하류에 두는 배치를 후보로 열 것인가, 인터뷰 전담을 유지할 것인가?
- D2.10 · r2 · adopt · abf668a4#r2.1 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — 이 리포는 «레포에서 auto-confirm 한 사실» 범주를 이미 한 번 만들었다가 4건 중 3건의 전제가 틀린 것을 확인하고 범주 자체를 폐기했고, 그 실패 양식이 정확히 ⟨S9⟩ 가 고른 출력 의무(경로+앵커)로는 걸러지지 않는 「인덱스만 읽고 구현을 안 읽음」이다. 내부 조사 산출을 brief 절·게이트로 승격하기 전에 이 선례를 어떻게 처리할 것인가?
- D2.11 · r2 · adopt · abf668a4#r2.2 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — ⟨C10⟩ 의 결핍 (c)「마커 규약 미채택(0건)」은 리터럴 `[from-code][auto-confirmed]` 를 센 값인데 같은 행위가 audit §5 프로세스 로그에 `auto-confirmed:` 라는 다른 표기로 실제로 기록돼 있다 — 「미채택」인가 「표기가 갈렸을 뿐 규약은 돌고 있다」인가, 그리고 OQ4(마커 폐기/유지)의 대상을 리터럴로 둘 것인가 개념으로 둘 것인가?
- D2.12 · r2 · adopt · abf668a4#r2.3 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — ⟨C13⟩ 의 면제(부착 달면 +0)는 상한이 없어 §5 가 「AP16 가드를 직접 약화시킨다」는 이유로 기각한 임계값 상향보다 오히려 더 강한 약화인데 그 임계값은 이미 사용자가 환경변수로 올릴 수 있는 값이다 — 기각 이유를 유지할 것인가, 무한 면제 쪽이 더 강한 약화임을 받아들이고 둘을 다시 저울질할 것인가?
- D2.13 · r2 · adopt · abf668a4#r2.4 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — 레포 조사 역할은 이미 Phase 0 에 배정돼 있고 그 문장이 두 skill 에 일부러 이중으로 적혀 있다 — ⟨C4⟩ 가 Phase 0 을 얼린 채 Phase 1 에 대등한 내부 축을 세우면 레포를 읽는 자리가 둘이 되는데 어느 쪽이 무엇을 읽는지의 규칙이 없다. 이번 변경은 Phase 0 의 레포 읽기에 «더하는» 것인가, 그것을 Phase 1 로 «옮기는» 것인가?
- D2.14 · r2 · adopt · abf668a4#r2.5 · "라운드 2 로 끝낸다 — 방향 항목은 §3 Open Questions·§5 위험으로 박제해 설계가 받게 한다 (S12)" — ⟨C10⟩ 의 결핍 (a)「하한 부재 — 11 중 5가 0건」이 선 코퍼스가 `docs/superpowers/interview/` 하나뿐인데 `docs/archive/interview/` 에 brief 가 7개 더 있고 그중 하나는 리포 `file:line` 인용이 표로 들어차 있다 — 코퍼스를 18개로 다시 잡고 결핍 (a) 를 재측정할 것인가, 「현역 디렉토리만」을 측정 경계로 못 박을 것인가?
- D2.15 · r2 · adopt · 4039a5a0#r2.1 · "라운드 1 게이트에서 이미 채택·처분한 편집이다 — D1.5 의 OQ 승격 · ask 9 의 §4 라벨 반전 명시 · ask 8 의 §5 ✎ 전환 (S12)" — finding 없이 바뀜: 3. Open Questions (modified)
- D2.16 · r2 · adopt · 1b8a3e5c#r2.1 · "라운드 1 게이트에서 이미 채택·처분한 편집이다 — D1.5 의 OQ 승격 · ask 9 의 §4 라벨 반전 명시 · ask 8 의 §5 ✎ 전환 (S12)" — finding 없이 바뀜: 4. External Landscape (modified)
- D2.17 · r2 · adopt · ad526e9e#r2.1 · "라운드 1 게이트에서 이미 채택·처분한 편집이다 — D1.5 의 OQ 승격 · ask 9 의 §4 라벨 반전 명시 · ask 8 의 §5 ✎ 전환 (S12)" — finding 없이 바뀜: 5. 기각 · Blind Spots (modified)
