---
type: interview-audit
payload: 2026-09-27-review-stopping-criterion-interview.md
created_at: 2026-09-27
session_id: 57c2d43f-5809-446c-869d-2e53f7862599
source: spec-distill conducting-interview v4.4.0
---

# 리뷰 멈춤 기준 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — 재구성(멈춤 기준 부재) 동의 (@S3)
- floor:landscape — closed — 외부 근거 처분(self-refine · recursive-refine · alert-fatigue · incremental-review · google-standard 취함, nitpick-filter 중립) (@S5)
- floor:skepticism — closed — ST1 verdict: refined (@S7)
- floor:blind_spot — closed — 숨은 가정 5 · 실패 양식 4 처분(ST1 흡수 5 · §5 기록 · advisory 표시 방식 결정) (@S8)
- floor:open_questions — closed — OQ9~OQ15 목록 확인 (@S11)
- derived:cost_surface — closed — 「과함」의 좌표(런타임 지출 · 사용자 개입 · 유지보수 표면 · 인터뷰 선행 검증 겹침); 개입·비수렴 층 (@S2)
- derived:preservation_boundary — closed — 잘라선 안 되는 것 vs 공시만 할 degrade; 좁은 범위 허용, 1·2 선택은 OQ4 로 (@S4)
- derived:blast_radius — closed — brief 자리 vs 공유 엔진 vs quality-gates 파급 + 락 동반 비용; spec-distill 세 자리 (@S10)
- derived:internal_research — closed — 내부(레포) 조사 축; 레포 주장 RC1~RC37 처분(수용) (@S10)

## 2. Budget

- 질문 라운드: 9 · agent dispatch: 8 · coverage-mapper 1 · codex 실호출: 2 (성공 2)

(dispatch 여덟: 인터뷰 셋(coverage-mapper 1 · steelman-builder 1 · blind-spot-prober 1) + brief 리뷰 다섯(doc-critic-web 2 · doc-recritic 2 · brief-readback 1). 리뷰 게이트 질문 호출 3회(라운드 1 · 라운드 2 · 멈출 지점). 세션 id 가 인터뷰 도중 하니스에서 바뀌어(57c2d43f → f61f026d) 리뷰 전 구간을 `DEVBREW_SPEC_DISTILL_SESSION_ID` override 로 돌렸다. steelman-builder · blind-spot-prober 에는
dispatch 뒤 도착한 사용자 발화 S6 을 SendMessage 로 보강했다 — 새 dispatch 로 세지 않았다.)

## 3. Steelman 원문

#### ST1 — 증분 리뷰(라운드 2+ 직전 수정분만) + must-catch 0건 승인

**dispatch 입력** — goal: S1 · 전제: P1 비수렴의 뿌리는 멈춤 기준 부재다(S3) · P2 라운드 1 이후 새 finding 의 다수는 직전 수정이 만든 것이다(orchestrator 도출) · P3 하류(설계 리뷰 · writing-plans)가 brief 리뷰가 놓친 결함을 다시 잡는다(S4) · P4 라운드 2+ 를 수정분으로 좁혀도 수정이 만든 결함은 잡히고 이음매 결함은 하류가 잡는다(orchestrator 도출) · P5 must-catch 0건 승인 기준이 hard gate 를 대체해도 Law 2 분리는 유지된다(orchestrator 도출) · 제약: S1–S6 원문 전량(S6 은 dispatch 뒤 보강) · trigger: 알려진 anti-pattern(수정분-only 리뷰는 이음매를 못 본다) + S4 와의 잠재 충돌(하류 설계 리뷰가 같은 엔진)

> ```yaml
> case_for_alternative:
>   statement: "라운드 2+ 에서 리뷰어는 문서 전문을 계속 읽되 finding 자격만 「직전 라운드 diff 가 도입한 결함」(수정분 자체 + 수정분과 어긋나는 미변경 문장)으로 좁힌다. 판별은 이미 있는 doc-recritic 의 `이 변경이 도입했는가` 축에 엔진 스냅숏 diff 를 실어서 한다. 하류가 다시 볼 수 없는 원문 충실도(층 2 전체)만 매 라운드 전문 대조로 두고 그것만 hard gate 로 삼는다. 방향(층 1)을 포함한 나머지는 계수·공시되는 advisory 와 §3 OQ 이월로 넘긴다."
>   strongest: "S1(덜어냄) 기준으로 원안만큼 덜어낸다. 라운드 2+ 의 비충실도 선재 finding 은 더 이상 막지도 올라오지도 않는다. 그런데 S6(좁혀 보되 다른 데 미치는 영향을 놓치지 말 것)은 원안보다 잘 지킨다. diff 만 준 리뷰는 사람이 짚은 이슈의 15–31% 만 잡고, 무너지는 쪽은 「바뀐 코드가 바뀌지 않은 주변과 어떻게 맞물리는가」 유형(21%)이다. 반면 구조화된 diff+요약은 전체 맥락보다 낫다. 그러니 읽기 범위를 줄이는 것이 아니라 자격 범위를 줄이는 것이 맞는 층위다. 새 메커니즘도 0개다. 엔진은 이미 라운드별 스냅숏을 원장에 저장하고, doc-recritic 은 이미 `<diff>` 슬롯과 「선재 결함 기각」 축을 갖고 있다. 문서 자리는 지금 diff 를 싣지 않을 뿐이다(사다리 3단 — 기존 하니스 표면). 충실도를 전문으로 남기는 이유는 이렇다. 하류 design-doc 리뷰의 ground_truth 가 「브리프 §2 확정 항목」 자체라서 §2↔§6 왜곡이 하류에서는 정답이 된다. 충실도 대조의 코퍼스는 §2 와 §6 으로 닫혀 있어 수렴하고, 레포 선례도 6→2→0 이다."
> case_for_current:
>   strongest: "P1 의 뿌리를 가장 짧은 경로로 친다. 지금 `approval_ready` 는 범주를 보지 않는다. 미적용 fix 나 열린 decide 가 하나라도 있으면 막는다. 그래서 승인 술어 하나를 「반드시 잡을 범주 0건」으로 바꾸는 것이 가장 레버리지가 크다. Google 의 리뷰 표준도 「완벽하지 않아도 전체 품질을 확실히 올리면 승인하고, 사소한 것은 Nit 로」다. 반복 수리는 두 라운드가 달성 가능한 이득의 76–95% 를 잡는다. 수정분만 보는 라운드 2+ 는 가장 싸다. fix 가 결함을 만드는 비율(평균 7%)도 그 결함이 diff 안에 몰려 있다는 뜻이다. 이음매 위험에는 방어가 이미 있다. 라운드 1 은 전문이고, 얼림 검사가 허가 밖 편집을 자동 decide 로 올리며, 하류 각 단계(설계 리뷰 r1 · writing-plans · SDD 최종 리뷰)의 첫 패스도 전문이다. 「영향 집합」을 더하면 리뷰어가 「무엇이 영향받았나」를 매번 판단해야 한다. 그 판단은 P1 이 없애려는 「더 찾을 게 있나」를 다른 이름으로 되살린다. 사용자도 이 형태를 명시로 골랐다(S5)."
> premise_refutation:
>   hits: [P2, P3, P4]
>   why: "P2 — 반증 근거는 RC5·RC7. 전제 문장은 「라운드 1 이후 새 finding 의 다수는 직전 수정이 만든 것이다」이다. 확인한 brief 사례는 하나다(research-specialization audit §8). 그 사례의 라운드 2 방향 결정 7건(D2.8–D2.14) 중 D2.9(§4 spec-kit 선례) · D2.11 · D2.14(C10) · D2.13(C4) 넷은 라운드 1 결정 D1.1–D1.7 이 겨눈 항목(Goal · 인계 축 · C13 · C12 · C5 · C9 · C8) 밖에 있다. 수정이 만든 것이 아니라 미변경 내용을 다시 샘플링한 결과다. LLM 리뷰는 같은 입력에서도 실행마다 결과가 갈린다(2502.20747). 전제의 수치 근거(r2 69 등)도 결함 수가 아니다. 한 설계문서의 라운드 2 에만 「finding 없이 바뀜」 얼림 항목이 19건 들어 있어(RC7), 그 집계는 「수정이 결함을 만들었다」를 재지 못한다. 다만 설계문서 쪽에는 라운드 1 에 추가된 절(§F · 회계)을 겨눈 라운드 2 finding 이 실제로 있다. 그래서 P2 는 설계에서는 부분 성립, brief 의 방향 범주에서는 반증이다.
>   P3 — 반증 근거는 RC2. 전제 문장은 「하류(설계 리뷰 · writing-plans)가 brief 리뷰가 놓친 결함을 다시 잡는다」이다. design-doc 프로필의 `ground_truth` 는 「인터뷰 브리프 §2 확정 항목」이고 `web: false` 다. brief §2 가 §6 원문을 왜곡·누락·발명했다면 하류는 그 §2 를 정답으로 삼아 대조한다. 따라서 충실도 결함은 하류에서 다시 잡히는 것이 아니라 오히려 집행된다. writing-plans 는 설계문서를 읽으므로 원문 §6 과는 더 멀다. 방향 결함도 하류에는 웹이 없어 외부 선례 축이 사라지고, repo 쪽(feasibility)만 남는다.
>   P4 — 반증 근거는 SWE-PRBench(arxiv 2603.26130)와 RC13. 전제 문장은 「라운드 2+ 를 수정분으로 좁혀도 수정이 만든 결함은 잡히고, 이음매 결함은 하류가 잡는다」이다. 앞 절에 대해: diff 만 준 리뷰는 human-flagged 이슈의 15–31% 만 잡는다. 붕괴의 주 기제는 「결함은 새 로직에 있지만 왜 틀렸는지는 미변경 주변을 봐야 아는」 Type2_Contextual 이다. 곧 수정이 만든 결함 중 일부는 수정분만 보면 안 잡힌다. 레포에도 같은 모양이 있다. 설계문서 D2.23 은 「처분 줄을 fail-closed 로 고치기로 했는데 §A 는 같은 실패에서 계속한다고 적어」, 결정된 수정과 다른 절 사이의 어긋남이다. 뒷 절(「하류가 잡는다」)은 위 P3 반증에 기대므로 함께 무너진다. 게다가 하류 reviewing-spec 은 같은 엔진이라, 원안대로라면 그 라운드 2+ 도 같은 이음매에 눈이 먼다."
> premise_list_challenge: "빠진 전제 넷, 잘못 묶인 전제 하나. (1) 「반드시 잡을 범주」를 누가 판정하는가가 없다. 모델의 자유 라벨이면 방향/상세 라벨이 흔들려(레포 BSP1 A4) 과소 라벨된 항목이 조용히 advisory 로 빠진다. 판정은 프로필 `layer_rubric` 의 축 소속으로 기계적으로 가르고(brief 는 층 2 축 여섯), 축이 없거나 모호하면 must-catch 로 친다(fail-closed). 엔진을 세 자리가 공유하므로 must-catch 는 엔진 상수가 아니라 프로필 필드여야 한다. (2) advisory 로 내린 finding 도 계수·공시된다는 전제가 없다. CLAUDE.md 의 처분 규약(「공시와 차단은 다른 술어」, 사람 소비자면 라벨을 붙여 보여준다)을 명시하지 않으면 advisory 는 조용한 소실이 된다. (3) 라운드 2+ 의 diff 기준점이 없다. critic 이 죽어 6~7단계를 건너뛴 라운드(reviewing-document.md 5단계)의 편집은 「직전 라운드 diff」 어디에도 들지 않는다. 기준점은 직전 라운드가 아니라 마지막 `round_reviewed: true` 라운드의 스냅숏이어야 한다. trigger 가 인용한 7단계 「알려진 한계」(얼림 검사 창)와 같은 구멍을 증분 리뷰가 새로 하나 더 만드는 셈이다. 덧붙여 그 7단계 인용은 얼림 검사의 따라잡기 범위에 관한 것이지 리뷰어의 읽기 범위에 관한 것이 아니므로 유비일 뿐 직접 근거는 아니다. (4) 「새 근거 없이 재제기하지 않는다」 규약은 현재 overdesign 축에만 있다(brief.md 「자르지 않는 것」). 증분만으로는 라운드 2+ 에서 수정분을 건드린 항목의 선재 내용이 다시 올라온다(D2.12 의 C13 이 그런 모양). (5) P4 는 「읽기 범위 축소」와 「자격 범위 축소」라는 서로 다른 두 조작을 한 문장에 묶었다. S6 이 허용하는 것은 뒤쪽뿐이다."
> recommendation: refined
> refined_takes: "원안에서 취하는 것: 멈춤 기준을 승인 술어로 두는 것(「반드시 잡을 범주 0건」이면 승인). 그 밖의 finding 을 hard gate 에서 내려 advisory 로 계수·공시하는 것. 라운드 1 은 전문 리뷰. 라운드 2+ 에서 좁히는 것. 재리뷰 상한 2 와 Law 2 분리(쓰기 권한 없는 리뷰어)는 그대로 둔다."
> refined_drops: "버리는 것: (a) 라운드 2+ 가 「직전 수정분만 읽는다」. 읽기는 전문을 유지하고, 좁히는 것은 finding 자격이다. doc-recritic 의 기존 `이 변경이 도입했는가` 축에 엔진 스냅숏 diff(기준점 = 마지막 round_reviewed 라운드)를 문서 자리에서도 실어, diff 가 도입하지 않은 비-must-catch 선재 finding 은 기각한다. 이음매(수정분과 어긋나는 미변경 문장)는 「도입됨」으로 남는다(S6). (b) OQ4 의 1안(방향+원문 왜곡). must-catch 는 2안(층 2 충실도 전체)으로 한다. 이유는 하류의 ground_truth 가 브리프 §2 라 충실도는 하류에서 다시 잡히지 않고, 코퍼스가 닫혀 있어 전문 대조가 수렴하기 때문이다. 방향은 코퍼스가 열려 있어(웹·리포) 라운드마다 새로 샘플링되므로 advisory 로 내리고 §3 OQ 로 이월한다. 사용자가 S12 에서 실제로 그렇게 처분했다. (c) 「이음매는 하류가 잡는다」는 가정. 같은 엔진을 쓰는 reviewing-spec 도 (a) 를 상속하므로 하류 그물을 얇게 만들지 않는다. (d) 재제기 금지 규약을 overdesign 축에서 전 축으로 넓힌다(한 줄 규약, 사다리 4단)."
> ```
>
> (evidence 7건 · repo_claims 13건은 원문 그대로 받았고, repo_claims 는 V1 재번호 RC24~RC36 으로 §5 에 실었다. evidence 원자료 URL 은 §7.)

**게이트-전 확인** — repo_claims: RC24~RC36 13건 전부 확인(§5 확인 줄) · 부착 주장: «swe-prbench» → P4 확인 · «google-context» → P4 확인 · «google-standard» → P1 확인 · «iter-repair» → P1 확인 · «bad-fix» → P2 확인 · «llm-determinism» → P1·P2 확인 · «non-absorbing» → P4 확인 · 재검토 자격: 열림 3건(P2 · P3 · P4)

**사용자 선택** — 보완 (S7)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-09-27) — web: enabled — 1차 fail(«» 강조 3건이 출처키로 읽힘 · §0 역참조 3건 누락) → 「」·역참조 보완 후 pass
- check_verbatim_coverage.py — exit 0 (2026-09-27)

## 5. 프로세스 로그

- round 1: path d — 「과함」의 층(OQ1) → S2 개입·비수렴, 리뷰 관련 다른 자리에서도 유사
- round 2: path d — 뿌리 재구성(OQ2) → S3 멈춤 기준 부재
- round 3: 되묻기(실패 조건) — 반드시 잡을 finding(OQ3) → S4 「1, 2의 경우 writing plan에서 한번더 보게된다」
- round 4: 외부 근거 처분(OQ5) → S5 증분+개선 승인 · 라운드 중 사용자 발화 S6(좁히되 파급 간과 금지)
- round 5: steelman 게이트 ST1 → S7 보완
- round 6: 숨은 가정·실패 양식 처분(OQ6) → S8 advisory 는 Step B 한 목록
- round 7: 되묻기(실패 조건, OQ7) → S9 한 화면 초과면 과함 — 이후 연속 되묻기 없이 진행
- round 8: path b — 적용 범위(OQ8) + 레포 주장 수용 → S10 spec-distill 세 자리
- round 9: OQ 목록 확인 → S11 그대로 넘김
- D6 검증 의무 미발동 — seed 없이 호출(인자 = rough request)이라 «다시 검증할 것» 문단이 없다
- 정정 — round 1 사용자 출력에서 orchestrator 가 bundle rc 3 을 「구조적 거짓 경보」로 단정했다가 RC13 미확인으로 정정. round 2 의 r1 55 · r2 69 해석은 ST1(RC30)이 반증.

- 확인 RC1 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#절차 — 라운드당 탐지·codex·재비판 각 1 + 마지막 냉독 1, 주장과 일치
- 확인 RC2 — 확인 — plugins/spec-distill/references/reviewing-document.md#상한 — rereview_cap 2, 주장과 일치
- 확인 RC3 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#입력 — 매 펜스 머리 반복, 주장과 일치
- 확인 RC4 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#direction — 리포·웹으로 방향 반증, 주장과 일치
- 확인 RC5 — 확인 — plugins/spec-distill/skills/conducting-interview/SKILL.md#V1 검문소 — 주장과 일치
- 확인 RC6 — 확인 — plugins/spec-distill/skills/reviewing-spec/SKILL.md#Read reviewing-document.md — 엔진 공유, 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/CHANGELOG.md#cost_class high → medium — 지출 게이트 제거(사용자 결정), 주장과 일치
- 확인 RC8 — 확인 — plugins/spec-distill/skills/conducting-interview/references/finishing.md#Step A.5 — Law 2 분리 리뷰, 주장과 일치
- 확인 RC9 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#자르지 않는 것 — 보존 경계 선언, 주장과 일치
- 확인 RC10 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#게이트 — 4개씩 연속 호출 + hard gate, 주장과 일치
- 확인 RC11 — 확인 — plugins/spec-distill/tests/test_reviewing_brief_residue.sh#guards — codex-gate 마커 절단, 참조 테스트 34파일, 주장과 일치
- 확인 RC12 — 확인 — docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.audit.md#S12 — 라운드1 20건·라운드2 16건 비수렴, 최근 4회 전부 상한 또는 수동 종료, 주장과 일치
- 확인 RC13 — 미확인 — plugins/spec-distill/scripts/build_brief_bundle.py#REDACT_KEYS — rc 3 이 최근 6회 중 3회 기록됐으나 빌더가 audit_file 키를 가려 원인을 확정하지 못했다
- 확인 RC14 — 확인 — docs/superpowers/interview/*.audit.md#brief 리뷰 — 최근 4건 기록 종료 사유, 주장과 일치
- 확인 RC15 — 확인 — docs/superpowers/specs/*-design.md#리뷰 결정 — 라운드별 D 줄 수는 맞다(해석은 RC30 이 반증)
- 확인 RC16 — 확인 — plugins/spec-distill/skills/reviewing-spec/SKILL.md#description — brief 하류에 설계 리뷰 · writing-plans, 주장과 일치
- 확인 RC17 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#ground_truth — 하류 정답=brief §2, web: false, 주장과 일치
- 확인 RC18 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#omission — 전수 대조 범주, 주장과 일치
- 확인 RC19 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#수정 권한 — 라운드 사이 audit §6 append, 주장과 일치
- 확인 RC20 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#수정 권한 — §2 ↔ user_sourced_items 같은 write, 주장과 일치
- 확인 RC21 — 확인 — plugins/spec-distill/references/reviewing-document.md#7단계 — 얼림 검사 따라잡기 한계, 주장과 일치
- 확인 RC22 — 확인 — plugins/spec-distill/skills/reviewing-spec/SKILL.md#Read reviewing-document.md — RC6 과 같은 사실, 주장과 일치
- 확인 RC23 — 확인 — plugins/spec-distill/agents/steelman-builder.md#의심 trigger 가 없는 방향 — 인터뷰 방향 검증은 trigger 조건부, 주장과 일치
- 확인 RC24 — 확인 — shared/docreview/scripts/docreview_state.py#approval_ready — 범주 무관 차단, 주장과 일치
- 확인 RC25 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#ground_truth — 하류 정답=brief §2, 주장과 일치
- 확인 RC26 — 확인 — plugins/spec-distill/agents/doc-recritic.md#이 변경이 도입했는가 — 축 실재, reviewing-brief 문서 자리는 diff 미탑재, 주장과 일치
- 확인 RC27 — 확인 — plugins/spec-distill/references/reviewing-document.md#7단계 — 라운드별 스냅숏 원장 저장, 주장과 일치
- 확인 RC28 — 확인 — docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.audit.md#D2.9 — D2.9·D2.11·D2.13·D2.14 가 r1 결정 대상 밖, 주장과 일치
- 확인 RC29 — 확인 — docs/superpowers/interview/2026-09-21-interview-research-specialization-interview.audit.md#S12 — 충실도 적용·방향 이월 처분, 주장과 일치
- 확인 RC30 — 확인 — docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#D2.21 — r2 집계에 얼림 19건 혼입, 주장과 일치
- 확인 RC31 — 확인 — docs/superpowers/interview/2026-09-21-interview-research-burden-interview.audit.md#멈출 조건에 대한 관측 — 6→2→0 수렴, 주장과 일치
- 확인 RC32 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#게이트 — 충실도·방향 둘 다 hard gate, 주장과 일치
- 확인 RC33 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#자르지 않는 것 — 재논쟁 금지 규약은 overdesign 축에만, 주장과 일치
- 확인 RC34 — 확인 — plugins/spec-distill/references/reviewing-document.md#5단계 — critic 사망 시 6~7단계 건너뜀, 주장과 일치
- 확인 RC35 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#layer2 — 충실도 여섯 축 열거, 주장과 일치
- 확인 RC36 — 확인 — docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#D2.23 — r2 이음매 finding 실재, 주장과 일치
- 확인 RC37 — 확인 — plugins/quality-gates/scripts/docreview_state.py#symlink — shared/docreview/scripts 가 quality-gates 에도 배포, 주장과 일치

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 2 · 재리뷰 카운트 1 · 추가 라운드 0 — 승인 게이트 도달 사유: **사용자 결정**(⟨S17⟩ 「라운드 2 로 끝냄」 — 상한 미도달, `cap_reached: false`, `approval_ready: false`) · 리뷰 완료: 예(`round_reviewed: true`, `unreviewed_reason: null`)
- 결정: `## 8. 리뷰 결정` 4건(D1.1 · D1.2 · D2.3 · D2.4, 전부 adopt) · 열린 채 남은 항목 0건(`open_decide: []` · `asks_open: []`) · **라운드 2 적용분 엔진 미관측** — fix 1(0138b17b#r2.1) · 채택 2(abf668a4#r2.1 · #r2.2, permit `round: 3` 미소비). 라운드 1 적용분(fix 6 · 채택 2)은 라운드 2 finalize 가 관측. finding: 라운드 1 탐지 9 + codex 2 = 11(재비판 기각 1 · same_as 2) → 라운드 2 탐지 4 + codex 1 + 재비판 추가 1 = 6(기각 1 · same_as 1). 라운드 2 신규 둘은 라운드 1 수정이 만든 이음매(D11 ↔ §3 OQ9)
- codex: 있음 — 2회(라운드 1·2), `runner_rc=0` · 웹: Claude `doc-critic-web`(프로필 `web: true` + 스위치 꺼짐) · codex 켜짐
- 냉독: gap 0건(G1~G6 엄격 판정) — advisory 가독성 메모 7(층/축 미정의 · RC/ST 외부 참조 · §6 에 S1 만 · D5/D7 원문과 ✎ 보완의 유효 문장 판별 · D7 「재제기 금지 전 축」 vs OQ11 · C4 writing plan ↔ design doc 리뷰 연결 · 「다섯 자리」 미열거) — 신뢰도 하향(inline blob rc 3 · 사본 dispatch)
- degrade: 6건 — critic/fidelity/degraded ×2(bundle rc 3, 라운드 1·2 — §5 레포 주장이 다른 인터뷰의 `*.audit.md` 경로를 인용해 위생 regex 가 발화, OQ14 의 원인 후보) · pipeline/all/degraded ×2(라운드 1·2 재비판 dispatch 입력을 orchestrator 가 압축 — 절차 이탈) · readback/readback/degraded ×2(inline blob rc 3 · 냉독 입력을 사본으로 dispatch). 엔진 채널(`fin.json` advisory · blocks · 렌더 첫 줄)은 없음

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택 (「과함」이 느껴지는 층 — 복수 선택 + 자유 입력):
  > "개입·비수렴 (권장) — 리뷰와 관련된 부분들에서 유사하게 발생"
- **S3** ☑ 선택 (비수렴의 뿌리):
  > "멈춤 기준 부재 (권장) — 리뷰가 문서가 충분한가가 아니라 더 찾을 게 있나를 묻는다 → 정지 조건 설계"
- **S4** 🗣 발화 (멈춤 기준 뒤에도 반드시 잡을 finding — 되묻기에 대한 자유 입력):
  > "1, 2의 경우 writing plan에서 한번더 보게된다"
- **S5** ☑ 선택 (외부 선례 처분):
  > "증분+개선 승인 (권장) — 라운드 1 전체 리뷰, 라운드 2+ 직전 수정분만, 승인 기준=반드시 잡을 범주 0건, 나머지 advisory"
- **S6** 🗣 발화 (라운드 4 진행 중 사용자가 보낸 메시지):
  > "좁혀서 보되 거기에 매몰되어서 다른거에 영향을 관과해선 안되니 조심해"
- **S7** ☑ 선택 (ST1 steelman 게이트):
  > "보완 (builder·orchestrator 추천) — 전문 읽기 유지, finding 자격만 diff 도입분+이음매로, must-catch=층2 충실도 전체(프로필 필드), 방향은 advisory+§3 이월, 재제기 금지 전 축"
- **S8** ☑ 선택 (advisory 표시 방식):
  > "묶어서 한 줄씩 (권장) — advisory 는 게이트 질문이 아니라 Step B 에 한 목록(축·한 줄 요지)으로 1회 표시, brief §3/§5 에 박제"
- **S9** ☑ 선택 (묶음 목록의 과함 기준 — 되묻기):
  > "한 화면 초과 (권장) — 묶음 목록이 ~10줄 넘으면 과함, 상한 장치는 설계가 정한다"
- **S10** ☑ 선택 (적용 범위 + 레포 주장 수용):
  > "spec-distill 세 자리 (권장) — 엔진 장치 + brief·design doc·seed 프로필 값, qg 는 필드 없이 현행 유지(회귀 확인 필요), 레포 확인 사실 RC1~RC37 을 근거로 수용"
- **S11** ☑ 선택 (Open Questions 확인):
  > "그대로 넘김 (권장) — OQ9~OQ15 를 brief §3 Open Questions 로 설계에 넘긴다"
- **S12** ☑ 선택 (brief 리뷰 라운드 1 게이트 — D1.1 abf668a4#r1.1):
  > "채택 — 프로필이 축을 지목 — must-catch = 프로필이 명시한 축 집합(층 번호 무관), brief=층2 여섯 축, seed=층1 충실도 네 축, design doc 은 OQ9 에서 정한다"
- **S13** ☑ 선택 (brief 리뷰 라운드 1 게이트 — D1.2 abf668a4#r1.2):
  > "채택 — 자격은 advisory 축만 — diff 자격 좁히기는 방향·overdesign 축에만, must-catch 축은 매 라운드 전문 대조 자격 유지"
- **S14** ☑ 선택 (brief 리뷰 라운드 2 게이트 — D2.3 abf668a4#r2.1):
  > "채택 — §3 OQ 로 넘김(A) — design doc·seed 자리의 advisory 박제처를 §3 OQ 로"
- **S15** ☑ 선택 (brief 리뷰 라운드 2 게이트 — D2.4 abf668a4#r2.2):
  > "채택 — 위험+OQ 기록(A) — must-catch 축 재샘플링 가정을 §5 위험과 §3 OQ 로"
- **S16** ☑ 선택 (brief 리뷰 라운드 2 게이트 — ask 9b7056b0#r2.1):
  > "좁힘 — design doc 만 (권장) — §3 OQ9 를 design doc 한 자리로"
- **S17** ☑ 선택 (brief 리뷰의 멈출 지점 — 라운드 1 11건 · 라운드 2 5건):
  > "라운드 2 로 끝냄 (권장) — 라운드 3 을 돌리지 않고 냉독 → Step B, 라운드 2 적용분(fix 1·채택 2)은 엔진 미관측으로 공시, 남은 것은 설계가 받음"

## 7. 확산 원자료

- «self-refine» — https://www.emergentmind.com/topics/iterative-self-refinement — 이득 1–2 라운드 집중, 정지 규칙
- «recursive-refine» — https://arxiv.org/pdf/2607.22653 — 근사 수렴은 일찍, 불필요한 반복은 회귀
- «alert-fatigue» — https://dev.to/pyor/alert-fatigue-comes-for-code-review-16kj — 잡음이 리뷰어를 재훈련
- «incremental-review» — https://dev.to/pockit_tools/ai-code-review-in-your-cicd-pipeline-automating-pr-reviews-test-generation-and-bug-detection-56j4 — 직전 리뷰 이후 변경분만
- «nitpick-filter» — https://codeant.ai/blogs/prevent-ai-code-review-overload — 게시 전 2차 필터
- «google-standard» — https://google.github.io/eng-practices/review/reviewer/standard.html — 확실히 개선되면 승인
- «swe-prbench» — https://arxiv.org/abs/2603.26130 — diff-only 15–31%, 구조화 diff+요약 우위
- «google-context» — https://google.github.io/eng-practices/review/reviewer/looking-for.html — 파일 전체 맥락
- «iter-repair» — https://arxiv.org/html/2604.10508v1 — 두 라운드가 이득의 76–95%
- «bad-fix» — https://insights.cermacademy.com/6-software-defect-origins-and-removal-methods-c-capers-jones-technologyrisk/ — bad-fix injection 약 7%
- «llm-determinism» — https://arxiv.org/html/2502.20747 — 반복 실행 출력 변동
- «non-absorbing» — https://arxiv.org/html/2607.24604 — 반복 수정에서 정답 상실
- «multiagent-failure» — https://latenteval.ai/analysis/multi-agent-failure-modes — 산문 검사 vs 출처 검사
- «error-propagation» — https://arxiv.org/pdf/2509.25370 — 앞 단계 오류 전파
- «rts-review» — https://fileadmin.cs.lth.se/cs/Personal/Emelie_Engstrom/Papers/IST_syst_review_regr_test.pdf — unsafe 선택의 검출 손실(검색 요약 근거, 원문 미열람)
- «google-static» — https://cacm.acm.org/research/lessons-from-building-static-analysis-tools-at-google/ — effective false positive(검색 요약 근거)
- «capture-recapture» — https://ieeexplore.ieee.org/document/852741/ — 잔존 결함 추정에 복수 inspector 필요(검색 요약 근거)

## 8. 리뷰 결정

- D1.1 · r1 · adopt · abf668a4#r1.1 · "채택 — 프로필이 축을 지목" — D7·D10 을 합치면 「층 1 = 방향 = advisory, 층 2 = 충실도 = must-catch」라는 규칙을 세 자리에 똑같이 적용하게 된다. 그런데 이 대응은 brief 프로필에서만 맞는다. seed 는 충실도 축이 층 1 에 있고 층 2 가 비어 있으며, design doc 은 층 1 이 brief 와의 정합이다. 선택지는 둘이다: 규칙을 「층 번호」가 아니라 「프로필이 must-catch 로 지목한 축」으로 세우는 것, 아니면 현행대로 층 번호로 가르는 것.
- D1.2 · r1 · adopt · abf668a4#r1.2 · "채택 — 자격은 advisory 축만" — D7 안에서 두 결정이 부딪친다. 하나는 「finding 자격 = diff 가 도입한 것 + 이음매」이고, 다른 하나는 「must-catch = 층 2 충실도 전체(omission 포함)」와 「충실도는 brief 에서 반드시 잡는다」이다. 라운드 1 의 단일 판정자가 놓친 선재 omission·distortion 은 라운드 2 이상에서 자격이 없어 영구히 못 잡힌다. 선택지는 둘이다: must-catch 축은 자격 좁히기에서 빼는 것, 아니면 자격 좁히기를 전 축에 거는 것.
- D2.3 · r2 · adopt · abf668a4#r2.1 · "채택 — §3 OQ 로 넘김(A)" — D8의 박제처(「brief §3/§5」)는 brief 자리에만 있다. 그런데 D10은 같은 장치를 design doc과 seed 두 자리에도 적용하므로, 그 두 자리에서 advisory가 어디에 남는지가 비어 있다. 이 공백을 §3의 열린 질문으로 넘길지(A), D8을 brief 전용으로 명시할지(B)를 정해야 한다.
- D2.4 · r2 · adopt · abf668a4#r2.2 · "채택 — 위험+OQ 기록(A)" — D12 이후 diff 자격 좁히기는 게이트를 막지 않는 advisory 축에만 걸리고, 게이트를 막는 must-catch 축은 매 라운드 전문을 다시 대조받는다. 그래서 이 brief가 스스로 취한 비수렴 기제(재샘플링)가 멈춤을 정하는 바로 그 축에서 그대로 살아 있다. 이 가정을 위험과 열린 질문으로 적을지(A), 현행처럼 기록 없이 둘지(B)를 정해야 한다.
