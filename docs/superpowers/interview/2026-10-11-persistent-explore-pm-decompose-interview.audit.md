---
type: interview-audit
payload: 2026-10-11-persistent-explore-pm-decompose-interview.md
created_at: 2026-10-11
session_id: 6e137b56-45f4-43d3-88d2-7fff3ba03a0a
source: spec-distill spec-interview 5.1.1
---

# 집요한 탐색 · 인터뷰의 PM 분해 — Interview Audit

> 순수 텔레메트리 — 핸드오프 산출물은 payload 이고, 여기에는 인터뷰 진행 기록만 남는다.

## 1. Coverage Ledger

- floor:root_problem — closed — S6 — 재구성 거부: 사용자 말 전부(seed + S2–S5)를 그대로 문제정의로. 재구성 단계 자체가 제거 대상
- floor:landscape — closed — S8 — 바깥 사례 8건 전부 참고 재료(1~6 취함 · 7·8 피함)
- floor:skepticism — closed — S10(ST3 refined) · S11(ST2 refined) · S12(ST1 refined) — 의심 방향 3건 전부 steelman 판정
- floor:blind_spot — closed — S13 — 숨은 가정 7 · 실패 양식 7 전부 위험으로
- floor:open_questions — closed — S48 — 열린 질문 8개 목록 확인, 하류로
- derived:internal_research — closed — coverage-mapper 첫 dispatch 가 repo_claims RC1–RC20 산출 — C43 자동 admit; S7 — 레포 주장(RC1–RC48) 전부를 제거·수정 대상으로 받음, 포화까지 추가 조사
- derived:의도 왜곡 장치 전수: 제거·수정 — closed — S3·S4·S5 — 사용자가 작업 항목으로 지정. 파이프라인 전 단계의 의도 축소·누락 장치; S10 — 전부 대상, 모두 제거 또는 수정(그대로 남는 것 0), 기준 고정. S7 로 포화까지 추가 조사
- derived:핸드오프 충실도: brief 에서 brainstorming, 다시 spec 으로 — closed — seed 확인 문장 + RC8·RC9·RC10; S16 — 번호 단위 인계 + 대조: spec 은 brief 번호마다 반영/기각+이유, spec 리뷰가 빠진 번호를 컨트롤 플레인 생략 경고로
- derived:기존 규칙과의 정합, 그리고 앞선 결정의 재결정 — closed — RC12·RC13·RC14·RC16·RC18; S11 — 규칙 충돌은 공개 개정(cost_class high → 상시 동의+규모 고지+kill switch), Unbounded autonomy·P18 은 원안 안에서 만족. 09-22 자격·예산 재결정은 S10 기준 적용
- derived:포화 판정과 정지 조건 — closed — seed 확인 문장 + RC3 + 외부(Anthropic·arXiv 2608.15191); S15 — 기준(열린 결정을 바꾸거나 새 결정을 여는 사실 없음) + 쓰기권 없는 독립 판정자 확인, 컨트롤 플레인 공시. 안전 상한 값은 §3 로
- derived:분해 판단 기준과 조각 계약 — closed — RC11 + 외부(kiro-spec-batch·recursive-sdd·brainstorming decomposition); S25 — 로드맵(고정 번호·한 줄 의도·범위 경계·의존·상태) + 걷는 뼈대 조각 0 + 인터페이스 먼저 + 조각마다 재평가(바뀔 때만 승인). S12 재분해 경로
- derived:조각 지도와 상태의 거처·수명 — closed — seed 확인 문장 + RC15; S26 — 로드맵은 레포 안 git 추적 파일(세션·압축·기기 넘어 생존, 이력 복구). 보는 곳은 Claude Code 안(S14)
- derived:사용자 통제 표면과 게이트 배치 — closed — seed 확인 문장 + RC17·RC20; S14 — 컨트롤 플레인은 Claude Code 안(상태줄·패널). S1 — 사용자 확인은 조각마다 spec 승인. S11 — 드리프트 금지, 파일은 사용자 표면이 아님
- derived:외부 플러그인 경계 — closed — RC10 + brainstorming 원문(외부); S17·S18 — 외부(superpowers)는 건드리지 않음. devbrew 쪽(넘길 때 보내는 글·돌아온 결과 검사)만 바꾼다. S10 의 외부 장치 부분을 재결정
- derived:하류 단계의 품질 제약 — closed — RC5·RC6·RC7·RC19 + brainstorming YAGNI·Scope check(외부); S10 — 하류 장치(overdesign 사다리·yagni/shrink·재리뷰 상한·외부 YAGNI 등)도 같은 기준으로 제거·수정
- derived:생략 경고(무엇이 빠졌는지의 공시) — closed — seed 품질 증상 + RC8·RC9; S9 — 「지도에 함께」 선택 + 「구조적으로 정리가 필요」: 단계마다 빠진·압축된·미룬 것을 조각 지도와 같은 곳에 구조로
- derived:드리프트 감지: 모르는 사이의 의도 이탈 — closed — S11 + 위험 H2·F6 — 실행 중 판정이 PM 모르게 의도를 바꿈; S22·S23 — 실행 판정은 컨트롤 플레인에 보이기만, 구현 중에는 멈추지 않음(구현 단계는 건드리지 않음 S21). S11 드리프트 금지는 가시성으로 (재개방 1회 — S21–S23 이 S19 의 「어긋나면 멈춤」과 충돌) (재개방 1회 — 사용자가 R14 답을 「보이기만」으로 정정 — 구현 중 멈춤 거부)
- derived:병렬 실행의 충돌과 통합 — closed — seed 목적(병렬) — 통합 지점 미정 (신뢰도 0.45, S2 로 버리지 않음); S27 — 조각마다 worktree·브랜치, 버전류는 머지 직전, 로드맵 의존 순 머지. 머지는 기계적 충돌뿐 아니라 조각 사이 의도 회귀가 없어야 하고 오케스트레이터가 책임
- derived:범용성: devbrew 밖 레포에서도 — closed — S27 「devbrew만 생각하지 마 여기서만 사용이 아니니까」 — 버전 규칙 등 devbrew 고유 규칙에 묶이지 않는 설계; S27 — 설계는 devbrew 밖 레포에서도 동작해야 함(사용자 지시 자체가 답)
- derived:긴 실행의 실패·중단·재개 — closed — 한 세션 지휘 — 재개·compaction·실패 (신뢰도 0.45, S2 로 버리지 않음); S28 — 실패 조각과 그 의존 조각만 멈추고 나머지 계속, 세션 끊김·압축 뒤 새 지휘자가 로드맵에서 재개, 컨트롤 플레인 공시. SDD ledger 와의 연결을 설계가 다룸
- derived:개선의 검증: 품질이 실제로 올랐는가 — closed — seed 목표가 품질·의도 일치 (신뢰도 0.4, S2 로 버리지 않음); S32 — 별도 측정 없이 사용자가 쓰면서 판단
- derived:외부 흐름의 사용자 게이트 지도 — closed — mapper #2 · writing-plans plan 리뷰 대기 · finishing 머지 메뉴 · brainstorming HARD-GATE ↔ S1 spec 승인만 · S34; S36 — 외부 정지(plan 검토·실행 방식 선택·머지 메뉴)는 그대로 사용자에게. S1 의 「spec 승인만, plan·구현 쭉」을 재결정(근거 S34 외부를 어그러뜨리지 않기). 실행(SDD) 중 Ruling 은 보이기만(S22)
- derived:지휘 구조의 플랫폼 실현 가능성 — closed — mapper #2 · AskUserQuestion 은 subagent 에서 제거 · worktree 는 default branch 분기 · 중첩 3 · 동시 20; S47 — 승인된 로드맵 R0 실측(한 세션 skill 이어 부르기·작업 목록·외부 정지) → R5 지휘자가 반영. 확인된 사실: subagent 는 사용자에게 못 물음, worktree 는 default branch 분기
- derived:design doc 리뷰 정답 출처 단절과 조각의 몫 — closed — RC74·RC75 — source_interview 쓰는 쪽 0, brief 미전달; S45 — spec 리뷰 호출 시 조각 묶음·로드맵 경로를 직접 넘기고 묶음을 정답으로(외부 무수정)
- derived:상태 휘발성과 상태 저장 재설계 정합 — closed — RC37·RC60 + 메모리 D1~D4; S46 — D1~D4 흡수(인터뷰 상태 docs · 임시 폴더는 리뷰만 · 이어 하기는 로드맵 · 원장 소실 방지)
- derived:진행 중 작업 흐름과의 충돌·선후 — closed — RC71·RC72·RC73·RC77·RC81·RC85; S37·S47 — 선행 P-a(@ 브랜치 먼저) · P-b(qg ⑤·PR3·진입 이름 뒤에 qg 조각) · P-c(hook 브랜치 고아 확인)
- derived:교차 플러그인 의존 선언과 부재 시 강등 — closed — RC83 · S27 범용성; S47 — 조각 R8
- derived:공유 엔진 파급과 persona 보안 리뷰 — closed — RC6·RC56 공유 엔진 · CLAUDE.md persona 편집 = 보안 리뷰; S47 — 조각 R2a(qg 파급 + persona 보안 리뷰)
- derived:락·테스트 갱신 지도 — closed — RC35·RC36·RC18·RC78 등; S47 — R0 산출물(락 지도)
- derived:조각 사이 이음매 통합 검증과 base 이동 — closed — SDD 는 조각 사이 이음매를 못 봄 · worktree default branch 분기; S47 — R5(조각 사이 이음매·base 이동 재측정)
- derived:실행 기록 소멸 전 회수 — closed — SDD ledger 최종 리뷰 뒤 삭제; S47 — R5(SDD 기록 회수)
- derived:조각 재진입·재평가 경로 — closed — RC79 · S25 재평가; S47 — R4(재분해·재평가·재진입)
- derived:교훈 축적: 큰 작업 수행의 확인 — closed — S35; S44 — 교훈은 따로 다루지 않음(S35 의 확인 자리 성격만 남김)

## 2. Budget

- 질문 라운드: 35 · agent dispatch: 6 · coverage-mapper 2 · codex 실호출: 0 (성공 0)

(dispatch 6 = coverage-mapper 2 · blind-spot-prober 1 · steelman-builder 3. coverage-mapper 첫 dispatch 는 사용자 지시 전달(SendMessage)로 재개돼 보고를 두 번 냈다 — 새 dispatch 로 세지 않았다. 조사 장치 호출 계수(S43 상한 기준)로는 약 7회.)

## 3. Steelman 원문

#### ST1 — 분해(PM)를 인터뷰에 둔다

**dispatch 입력** — goal: S6(「내말」 = S1 + S3·S4·S5) · 전제: P1 장치가 품질 저하·의도 어긋남을 만든다(S1·S3·도출) · P2 포화 조사가 하류 품질을 올린다(S1) · P3 나누면 더 상세(S1 미확인) · P4 분해는 인터뷰가(S1) · P5 spec 승인만으로 통제 유지(S1) · P6 장치 제거·수정이 의도를 보존(S3·S4) · P7 devbrew 가 외부 장치에 개입 가능(도출) · 제약: S1–S8 원문 전량 · trigger: landscape 모순 — 하류 brainstorming·writing-plans·spec-review 에 분해 장치 실재, 바깥 사례는 계획 단계 분해

> ```yaml
> case_for_alternative:
>   statement: "분해를 판단하는 일은 하류(brainstorming·설계 단계)에 이미 있는 분해 자리에 맡기고, devbrew 는 그 분해에서 남은 조각을 추적하고 이어받도록 고친다."
>   strongest: "어디서 나눌지는 설계를 봐야 정확해진다. Shape Up 은 실제 할 일이 '일에 들어가 봐야 드러난다'고 말하고, BMAD 는 PRD 와 architecture 다음에 sharding 한다. 그래서 설계 전에 인터뷰가 조각을 정하면 상상한 경계(imagined tasks)로 자르게 되고, 조각 사이 인터페이스가 틀릴 위험이 있다. 하류에는 이미 분해 자리가 셋 있다 — brainstorming 의 sub-project 분해, writing-plans 의 Scope Check, spec-review 의 scope_creep. 여기에 인터뷰를 넷째 판정자로 더하면 '누가 나누는가'가 둘로 갈린다. devbrew 가 놓치는 것은 '남은 조각 추적'뿐이다. 이것은 finishing.md 385행 선례처럼 핸드오프 문장 하나와 조각 지도로 메울 수 있다. 그러면 조각마다 충분한 설계를 붙인다는 목적을, 설계를 아는 자리에서 이룬다."
> case_for_current:
>   strongest: "기준인 S6 은 '내 말 그대로'다. S1 의 사용자 확인 문장은 '인터뷰가 PM 역할을 맡는다 … 나누기는 인터뷰가 조각·순서·병렬 여부를 제안하고 사용자가 고치거나 승인한 뒤에만 일어난다'이다. 판단 주체를 인터뷰로 직접 지목하고 있다. S1 은 의도가 어긋나는 곳도 'brief 가 brainstorming 으로 넘어가는 이음매'이고 'spec 하나에 맞추느라 범위가 줄거나 바뀐다'고 확인했다. 하류에 분해를 두면 나누는 시점이 바로 그 이음매 뒤가 된다. 게다가 그 자리는 외부 skill 이고, 내용이 움직인다. 설치본 6.4.1 은 'brainstorm the first sub-project'이고, upstream main 은 'agree on an order, and brainstorm them one at a time'이다. 어느 쪽에도 조각 지도도, 병렬도, 남은 조각 추적도 없다. 반면 S1 이 통제가 살아 있다고 보는 조건은 '전체 조각과 순서·의존, 각 조각의 단계를 한 곳에서 본다'이다. 이렇게 하는 바깥 사례(recursive-sdd 의 Blueprint, ralph-specum 의 epic triage)는 지도를 맨 앞(진입점·Product Discovery)에 둔다. Anthropic 의 lead agent 도 처음에 분해하고, 하위 작업 설명이 흐리면 중복과 빈틈이 생긴다고 보고한다. 그 설명을 쓸 포화 조사(P2)를 쥔 쪽은 인터뷰다."
> premise_refutation:
>   hits: []
> premise_list_challenge: "결함 넷. (1) P4 에는 빠진 전제가 하나 있다. '인터뷰가 올바른 경계로 자를 만큼 구조와 인터페이스를 안다'는 것이다. Shape Up 과 BMAD 근거는 바로 여기를 겨눈다. 이 전제는 P2(포화 조사)에 기대므로, P4 는 P2 가 실현된다는 조건 위에서만 성립한다. 목록이 이 의존을 적지 않았다. (2) 하류 분해 자리와 어떻게 공존하는지에 관한 전제가 없다. brainstorming 의 분해, writing-plans Scope Check, spec-review scope_creep 은 조각마다 다시 돈다. 그것들이 조각을 다시 쪼개거나 줄이면, 그 일이 '한 곳에서 보는' 지도 밖에서 일어나 S1 의 통제 조건이 깨진다. 이 셋은 지도로 되돌아오는 신호가 되거나 고쳐져야 한다는 전제(P6·P7 의 구체화)가 필요하다. 그리고 인터뷰의 분해는 하류에서 새 경계가 드러나면 사용자 동의 아래 다시 정할 수 있어야 한다(P23, sealed decision 금지). (3) P3 은 사용자 원문이 '될듯'인 추측이다. 근거(Lost in the Middle, Anthropic 의 하위 작업 상세화)는 이를 지지하지만, 'spec 을 나누면 명세가 상세해진다'를 직접 잰 근거는 찾지 못했다. (4) trigger 의 지형 서술이 일부 틀렸다. recursive-sdd 의 Blueprint 는 'Phase A: Blueprint (Product Discovery)'로 Parent Spec 앞에 있다. 계획 단계가 아니라 발견 단계다. 덧붙임: 대안을 '분해 판단 주체 = brainstorming'으로 읽으면, S1 의 확인 문장이 이미 닫은 경로와 충돌한다. 그래서 goal 기준에서는 사용자가 다시 결정하지 않는 한 채택할 수 없다. 이 판정은 대안 중 '남은 조각 추적·이어받기' 부분만 원안에 흡수할 수 있는 재료로 다룬다."
> recommendation: refined
> refined_takes: "원안 전부를 취한다. 인터뷰가 '구현 spec 하나로 되는가'를 판단한다. 크면 조각·순서·병렬 여부를 제안하고, 사용자가 고치거나 승인한 뒤에만 하류로 나눠 넘긴다. 전체 조각, 순서·의존, 조각별 단계를 한 곳에서 보는 조각 지도를 인터뷰 산출물로 둔다(모양은 S1 대로 열어 둔다). 대안에서는 '남은 조각 추적·이어받기'와 '하류 분해 신호를 버리지 않는다'를 흡수한다."
> refined_drops: "인터뷰의 분해를 한 번에 끝나는 최종 판정으로 두는 성질을 버린다. 그 성질 탓에 하류의 세 분해 자리(brainstorming 의 sub-project/one-at-a-time, writing-plans Scope Check, spec-review scope_creep)가 조각을 다시 쪼개거나 줄이면, 그 일이 지도 밖에서 조용히 일어난다. 대신 하류의 분해 신호는 같은 지도로 돌아와 사용자 승인 뒤 다시 분해하는 경로를 탄다. 범위를 줄이는 변경이 아니다 — 재분해 경로를 더하는 것이다."
> evidence:
>   - url: "https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md"
>     supports: both
>     claim: "upstream main 의 brainstorming 은 'If this is really several independent projects, say so, agree on an order, and brainstorm them one at a time.' 한 문장으로 분해를 다룬다. 남은 프로젝트 목록·추적·병렬 언급은 없다. 설치본 6.4.1(/Users/jeonghokim/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/brainstorming/SKILL.md 203행)의 'brainstorm the first sub-project …'와 문구가 달라, 하류 분해 자리가 바뀌는 외부 텍스트임을 보인다. 설치본 214행 'YAGNI ruthlessly - remove unnecessary features'는 main 에 없다."
>     touches: [P4, P7]
>     decides: []
>   - url: "https://raw.githubusercontent.com/obra/superpowers/main/skills/writing-plans/SKILL.md"
>     supports: both
>     claim: "Scope Check: 'If the spec covers multiple independent subsystems, it should have been broken into sub-project specs during brainstorming.' — writing-plans 는 분해가 spec 앞에서 끝났다고 가정하는 사후 점검이다."
>     touches: [P4]
>     decides: []
>   - url: "https://basecamp.com/shapeup/3.4-chapter-13"
>     supports: alternative
>     claim: "'issues are discovered by getting involved in the problem … to-do lists actually grow as the team makes progress' — 앞에서 계획한 할 일(imagined)과 일하면서 발견한 할 일(discovered)을 구분한다. 다만 대상은 빌드 단계의 scope 안 할 일이다. 프로젝트 단위 분할 시점을 직접 말하지 않으므로 P4 를 반증하지 않고, 분해를 다시 정할 수 있어야 한다는 쪽만 지지한다."
>     touches: [P4]
>     decides: []
>   - url: "https://www.augmentcode.com/guides/bmad-method-ai-development"
>     supports: both
>     claim: "BMAD v6 에서 Product Manager agent 가 PRD 작성과 epics·stories 생성을 맡는다(분해 주체 = PM 역할). 파일 sharding 은 PRD·architecture 다음이다(시점 = 설계 후)."
>     touches: [P4]
>     decides: []
>   - url: "https://smithery.ai/skills/handol-park/recursive-sdd"
>     supports: current
>     claim: "Blueprint 는 'Phase A: Blueprint (Product Discovery)'로 Parent Spec 앞에 온다. Parent Spec 의 Atomic Specs Table 이 Spec ID·Status·Dependencies 를 한 곳에 두고, 상태는 PENDING → DRAFT → APPROVED → IMPLEMENTED → INTEGRATED 로 간다. trigger 의 '계획 단계 분해' 서술과 다르다."
>     touches: [P4, P5]
>     decides: []
>   - url: "https://www.claudepluginhub.com/skills/tzachbon-ralph-specum-plugins-ralph-specum-2/spec-workflow"
>     supports: current
>     claim: "큰 기능의 진입점이 epic triage 로, 의존을 인식하는 spec 들로 분해한다. epic.md(비전·spec·dependency graph)와 .epic-state.json(spec 간 진행 추적)을 두고, start 가 다음에 막히지 않은 spec 을 제안한다."
>     touches: [P4, P5]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: current
>     claim: "'the lead agent decomposes queries into subtasks' — 'Without detailed task descriptions, agents duplicate work, leave gaps, or fail to find necessary information.' 처음에 지휘하는 쪽이 분해하고, 조각 설명의 상세함이 품질을 가른다."
>     touches: [P3, P5]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/building-effective-agents"
>     supports: both
>     claim: "orchestrator-workers 에서는 'a central LLM dynamically breaks down tasks', 'subtasks aren't pre-defined, but determined by the orchestrator based on the specific input'. 분해 주체는 중앙 지휘자이고, 분해는 입력에 따라 동적이다."
>     touches: [P4, P5]
>     decides: []
>   - url: "https://arxiv.org/abs/2307.03172"
>     supports: current
>     claim: "Lost in the Middle: 긴 맥락의 가운데 정보에서 정확도가 크게 떨어지고, 입력이 길어질수록 성능이 떨어진다. 한 spec 에 일을 우겨 넣는 비용의 간접 근거다."
>     touches: [P3]
>     decides: []
>   - url: "https://claudepluginhub.com/skills/lzy-ricardo-superpowers/decomposing-requirements"
>     supports: current
>     claim: "superpowers 포크 하나가 분해를 brainstorming 밖의 별도 decomposing-requirements skill 로 빼고, 분해 문서를 macro-level map 으로 두어 sub-project 완료 때마다 갱신한다. 원문은 HTTP 410 으로 확인하지 못했고 검색 색인 요약에만 근거한다."
>     touches: [P4]
>     decides: []
> repo_claims:
>   - id: RC1
>     path: "plugins/spec-distill/skills/spec-interview/references/finishing.md"
>     anchor: "brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다"
>     line: 385
>     claim: "devbrew 는 외부 brainstorming 의 흐름 지시를 핸드오프 문장으로 덮어쓰는 선례를 이미 가진다. 대안의 '남은 조각 이어받기'와 원안의 '하류 분해 신호를 지도로 되돌리기' 둘 다 이 경로로 구현할 수 있다."
>     touches: [P7]
>     decides: []
>   - id: RC2
>     path: "plugins/spec-distill/skills/spec-interview/references/finishing.md"
>     anchor: "Skill superpowers:brainstorming <brief-path>"
>     line: 364
>     claim: "현재 종료 경로는 brief 경로 하나를 brainstorming 하나로 넘긴다(옵션 ①·② 모두). 여러 조각을 넘기는 운반 경로가 아직 없다."
>     touches: [P4]
>     decides: []
>   - id: RC3
>     path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
>     anchor: "`scope_creep` — 한 구현 계획으로 분해되지 않는 독립 하위 시스템 묶음."
>     line: 101
>     claim: "spec-review 의 scope_creep 은 묶음을 탐지하는 finding 일 뿐 분해를 수행하거나 추적하지 않는다. 처분 안내(같은 파일 109행)상 범위 변경은 decide 로 사용자에게 간다. 조각마다 다시 돌기 때문에, 지도로 되돌리지 않으면 지도 밖 재분해 지점이 된다."
>     touches: [P6]
>     decides: []
>   - id: RC4
>     path: "plugins/spec-distill/skills/spec-interview/SKILL.md"
>     anchor: "커버리지 원장의 floor 5차원**(root-problem/landscape/skepticism/blind-spot/open-questions)"
>     line: 85
>     claim: "인터뷰의 floor 다섯 차원에 분해 판단 차원이 없다. spec-interview 디렉터리를 '하위 시스템|sub-project|여러 spec|scope' 로 Grep 해서 0건이었다(Grep 은 심볼릭 링크를 건너뛰므로 하한이다). 현재 인터뷰에는 분해 판단 자리가 없고, 원안은 새 surface 를 더하는 일이다."
>     touches: [P4]
>     decides: []
> ```

**게이트-전 확인** — repo_claims 4: finishing.md 385 확인(RC10) · finishing.md 364 확인(RC68) · design-doc.md 101·109 확인(RC69) · spec-interview 분해 어휘 grep 0건 확인(RC70) · 부착 주장 10건 → P3·P4·P5·P6·P7 확인(decomposing-requirements 포크는 원문 410, 근거 약함 표시) · 재검토 자격: 재검토 사유 없음 — 확인된 전제 충돌 0건

**사용자 선택** — 보완 (S12)

#### ST2 — 긴 자율 실행(포화 조사·한 세션 지휘·plan·구현 직진·규모만 공시)

**dispatch 입력** — goal: S6(「내말」 = S1 + S3·S4·S5) · 전제: P1 장치가 품질 저하·의도 어긋남을 만든다(S1·S3·도출) · P2 포화 조사가 하류 품질을 올린다(S1) · P3 나누면 더 상세(S1 미확인) · P4 분해는 인터뷰가(S1) · P5 spec 승인만으로 통제 유지(S1) · P6 장치 제거·수정이 의도를 보존(S3·S4) · P7 devbrew 가 외부 장치에 개입 가능(도출) · 제약: S1–S8 원문 전량 · trigger: 알려진 anti-pattern — Unbounded autonomy · Subagent spray · cost_class high 승인 · P18 · 옵션 ① 턴 종료

> ```yaml
> case_for_alternative:
>   statement: "규칙 안에서 설계한다. 사용자가 이미 받기로 한 두 게이트(조각·순서·병렬 분해 승인, 조각마다 spec 승인)에 규모 견적과 지출 동의를 함께 실어 CLAUDE.md 45행의 cost_class high 「지출 전 명시적 AskUserQuestion 승인 게이트」를 새 게이트 없이 만족시킨다. 장시간 실행은 한 세션의 대화 맥락이 아니라 원장 파일(전체 조각·순서·의존·각 조각의 단계)을 이어받는 세션 이어달리기로 나눈다. 포화 조사·PM 분해·plan과 구현을 멈추지 않고 진행하는 모양은 그대로 둔다."
>   strongest: "goal(「내말 그대로 전부」)에는 S1 의 「PM 인 사용자의 결정권과 내용 검토가 유지돼야 하며 그 통제가 무너지면 실패다」가 들어 있고, S3 의 「의도를 왜곡하는 장치들 다 제거」도 들어 있다. 한 세션이 여러 조각을 끝까지 지휘하면 그 세션은 반드시 자동 압축을 겪는다. 사용자가 없애라고 한 바로 그 왜곡 장치(압축)가 지휘자 안에서 다시 생긴다. Anthropic 의 장시간 하니스는 한 세션 몰아치기에서 맥락 고갈과 「너무 이른 승리 선언」을 실패로 확인했고, 진척 파일을 이어받는 세션으로 나눠 이를 풀었다. 그리고 이미 받기로 한 승인 자리에 지출 동의를 실으면 질문이 하나도 늘지 않으면서 규칙도 지킨다(critiquing-artifacts 의 「동의 범위 = 실행 범위」 선례). 장치를 남기지 않고 규칙도 깨지 않는 길이다."
> case_for_current:
>   strongest: "같은 기준(「내말 그대로 전부」)에서 사용자는 S1 에 「크게 쓰기 전에는 규모만 알린다(사용자 확인)」, 「plan·구현은 멈추지 않고 쭉 간다(사용자 확인)」, 「조각들은 한 세션이 지휘해 끝까지」를 명시했다. 알리기만 할 자리에 지출 승인을 끼워 넣으면 사용자 말을 바꾸는 셈이다. 그것은 S6 이 거부한 「재구성」이다. 규칙과의 충돌은 대부분 겉모양이다. Subagent spray 는 「규모 자체가 아니라 선언 없음」을 금지하는데(CLAUDE.md 85행), 규모를 알리는 것이 곧 선언이다. Unbounded autonomy 는 상한·반복 감지·kill switch 가 없는 루프를 금지하는데, 원안에는 상한이 안전장치로 남아 있고 「더 조사해도 결정에 닿는 새 사실이 없으면 멈춤」은 반복 감지를 일반화한 정지 조건이다. Anthropic 도 「충분한 정보가 모이면 루프를 빠져나간다」를 정지 조건으로 쓴다. 정말로 부딪히는 것은 cost_class high 한 줄뿐이다. 이 레포는 이미 같은 종류의 규칙을 사용자의 상시 동의로 고친 선례가 둘 있다(Agent 상시 허용 85행, qg PR 코멘트 상시 동의 + kill switch, 철학 51행). 그러니 규칙을 공개적으로 고치는 것이 사용자 말을 그대로 지키는 정공법이다."
> premise_refutation:
>   hits: []
> premise_list_challenge: "전제 목록에 결함이 셋 있다. (1) P1·P6 과 「한 세션이 지휘」 사이의 긴장이 전제로 적혀 있지 않다. P1 은 압축을 왜곡 장치로 꼽는데, 오래 도는 지휘 세션은 압축을 피할 수 없다. 그래서 「지휘자의 상태(S1 의 '한 곳에서 보는' 조각·순서·의존·단계)는 대화가 아니라 파일에 산다」는 전제가 빠져 있다. 이것 없이는 P5 의 통제가 압축 한 번에 조용히 무너질 수 있다. 다만 P5 자체를 반증하는 근거는 아니다(spec 승인은 여전히 구조적 게이트다). (2) 「plan·구현은 멈추지 않는다」와 철학 P23(67행, 확정이 하류에서 반증되면 근거와 함께 사용자 동의를 받아 피벗)이 어떻게 맞물리는지 정하는 전제가 없다. 예정된 체크포인트가 없다는 것과, spec 이 반증되거나 막혔을 때도 멈추지 않는다는 것은 다른 말이다. 후자는 S1 의 「결정권 유지」와 충돌한다. Building effective agents 도 「체크포인트나 막힘에서 사람 피드백을 위해 멈춘다」를 같은 구조로 쓴다. 이 경계를 전제로 박아 두지 않으면 하류가 sealed decision 이나 무단 변경 중 하나로 떨어진다. (3) P2 는 「조사가 두꺼우면 품질이 오른다」를 무조건으로 적었다. Chroma 의 context rot 보고서는 입력이 길어질수록 단순 과제에서도 성능이 불안정해진다고 측정했다. 그러니 P2 는 「결정에 닿는 사실이 두꺼워지면」으로 한정해야 한다. S1 의 정지 조건이 이미 그 한정을 담고 있으므로 반증은 아니고 문장 정밀도 문제다. 참고로, 트리거가 든 대안 중 「단계별 사용자 체크포인트」(plan·구현 구간)와 「명시 예산 승인」(규모 고지 자리)은 S1 의 사용자 확인 항목이 이미 닫은 길이라 대안으로 내지 않았다. 그래서 대안은 「이미 있는 게이트에 싣기」라는 규칙 안 설계로 한정했다."
> recommendation: refined
> refined_takes: "원안의 모양을 전부 가져간다. 포화까지 조사하고 상한은 안전장치로만 둔다. PM 분해는 사용자 승인 뒤에만 한다. 한 지휘자가 조각을 끝까지 끌고 간다. 사용자 확인은 조각마다 spec 승인에서만 받고 plan과 구현은 멈추지 않는다. 비용은 크게 쓰기 전에 규모만 알린다. 규칙 충돌은 우회하지 않고 공개적으로 개정한다. CLAUDE.md 45행 cost_class high 조항에 「사용자 상시 동의 + 지출 전 규모 고지 + 끄는 길(kill switch)」을 승인 게이트와 같은 효력의 형태로 추가한다. 선례는 85행 Agent 상시 허용과 철학 51행 qg 상시 동의다. finishing.md 의 옵션 ②(같은 세션에서 바로 brainstorming, 385·387행의 「명시적 예외」)는 지휘자 경로의 선례로 쓴다. Unbounded autonomy 와 P18 은 개정하지 않고 원안 안에서 만족시킨다. 상한, 「새 사실 없음」 정지 술어(반복 감지), kill switch 셋을 같이 둔다. 정체되면 사람에게 묻기 전에 fresh subagent 나 다른 리뷰어를 먼저 쓴다."
> refined_drops: "지휘자의 대화 맥락을 상태의 정본으로 삼는 것을 버린다. 조각·순서·의존·단계는 원장 파일에 두고, 지휘자는 압축이나 재시작 뒤에 그 파일에서 상태를 다시 세운다. 「한 세션이 지휘한다」는 문장은 유지하되, 압축을 거치면 사라지는 상태 보관은 버린다. 또 「멈추지 않는다」를 「어떤 경우에도 묻지 않는다」로 읽는 해석을 버린다. 예정된 체크포인트는 두지 않는다. 다만 하류에서 승인된 spec 이 반증되면(P23) 그 자리에서만 사용자 동의를 받는다. 막혔는데 다른 접근도 소진된 경우(P18 의 human prompt)도 마찬가지다."
> evidence:
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: both
>     claim: "멀티에이전트는 채팅의 약 15배 토큰을 쓰고, 과제 가치가 그 비용을 정당화해야 한다. 초기 실패로 「단순 질의에 subagent 50개」와 「이미 충분한 결과가 있는데 계속」을 꼽는다. 동시에 정지 조건은 횟수가 아니라 「충분한 정보가 모이면 연구 루프를 빠져나간다」이고, 오류 지점에서 재개하는 시스템과 정기 체크포인트를 둔다. 코딩은 연구보다 진짜로 병렬화되는 과제가 적다."
>     touches: [P2]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents"
>     supports: alternative
>     claim: "장시간 작업에서 한 세션 몰아치기(one-shot)는 도중에 맥락이 고갈되고, 에이전트가 「프로젝트 전체에 너무 일찍 승리를 선언」한다. 해법은 진척 파일과 기능 목록을 이어받아 세션마다 기능 하나씩 진행하는 구조다. 세션 사이에 사람 승인 단계는 없다(사람 체크포인트 없이 자율로 이어진다)."
>     touches: [P3, P5]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/building-effective-agents"
>     supports: both
>     claim: "에이전트는 체크포인트나 막힘에서 사람 피드백을 위해 멈출 수 있고, 통제를 위해 최대 반복 수 같은 정지 조건을 두는 것이 일반적이다. 자율성은 더 높은 비용과 누적 오류를 뜻한다."
>     touches: [P5]
>     decides: []
>   - url: "https://fortune.com/2025/07/23/ai-coding-tool-replit-wiped-database-called-it-a-catastrophic-failure"
>     supports: alternative
>     claim: "Replit 에이전트가 코드·액션 동결 중에 사람 승인 없이 진행하지 말라는 지시를 어기고 운영 DB 를 지웠다. 산문 지시로 둔 승인은 장시간 자율 실행에서 지켜지지 않을 수 있다. 원안의 spec 승인처럼 구조적 게이트여야 한다."
>     touches: [P5]
>     decides: []
>   - url: "https://research.trychroma.com/context-rot"
>     supports: alternative
>     claim: "18개 모델에서 입력 토큰이 늘수록 단순 과제에서도 성능이 불안정해진다. 두꺼운 맥락이 곧 품질은 아니다. 긴 지휘 세션의 누적 맥락에도 같은 압력이 걸린다."
>     touches: [P2]
>     decides: []
> repo_claims:
>   - id: RC1
>     path: "CLAUDE.md"
>     anchor: "`high`는 지출 전 명시적 `AskUserQuestion` 승인 게이트를 invoke해야 함."
>     line: 45
>     claim: "원안의 「지출 전 승인 없이 규모만 알린다」와 글자 그대로 충돌하는 유일한 규칙이다. 원안을 그대로 실현하려면 이 조항을 개정하거나, 이미 있는 승인 게이트에 지출 동의를 실어야 한다."
>     touches: []
>     decides: []
>   - id: RC2
>     path: "CLAUDE.md"
>     anchor: "비용과 fan-out을 선언하지 않고 대규모로 퍼뜨리는 것이 anti-pattern이다 (규모 자체가 아니라 선언 없음이). **Agent(subagent) 호출 자체는 이 리포에서 상시 허용**"
>     line: 85
>     claim: "Subagent spray 는 규모가 아니라 선언 없음을 금지한다. 규모 고지가 선언이므로 원안과 충돌하지 않는다. 사용자의 상시 요청으로 기본 금지를 푼 선례이기도 하다."
>     touches: []
>     decides: []
>   - id: RC3
>     path: "CLAUDE.md"
>     anchor: "**Unbounded autonomy** — max-iter count, repeat 감지, 사용자-override kill switch 없는 루프."
>     line: 87
>     claim: "금지 대상은 세 가지 모두가 없는 루프다. 원안은 상한을 안전장치로 남기고 「새 사실 없음」 정지 술어(반복 감지)를 두므로, kill switch 만 더하면 개정 없이 만족한다."
>     touches: []
>     decides: []
>   - id: RC4
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "### P18 — Stagnation Is a Failure Mode"
>     line: 55
>     claim: "정체되면 재시도 대신 다른 접근(fresh subagent·다른 리뷰어·human prompt)을 써야 한다. 멈추지 않는 plan·구현 안에서도 정체 처리 경로는 있어야 하고, 사람에게 묻는 것은 그 선택지 중 하나다."
>     touches: []
>     decides: []
>   - id: RC5
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "### P17 — User Sovereignty … qg 의 매 실행 PR 코멘트 게시는 사용자의 상시 동의다 — 게시마다 묻지 않고, 게시만 끄는 길은 `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` 하나다"
>     line: 51
>     claim: "「상시 동의 + kill switch」가 매번 묻는 승인 게이트를 대신하는 형태로 이미 철학에 들어 있다. cost_class 조항을 같은 형태로 개정할 선례다."
>     touches: []
>     decides: []
>   - id: RC6
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "확정된 결정은 재논의 대상이 아니지만 **반증 대상이다.** … 근거를 제시하고 사용자 동의를 받아 피벗할 수 있어야 한다"
>     line: 67
>     claim: "멈추지 않는 plan·구현도 승인된 spec 이 하류에서 반증되면 사용자 동의 경로를 가져야 한다. 원안의 전제 목록에는 이 경계가 빠져 있다."
>     touches: [P5]
>     decides: []
>   - id: RC7
>     path: "plugins/spec-distill/skills/spec-interview/references/finishing.md"
>     anchor: "(사람이 유일한 운반자다 — 자동으로 이어지지 않는다)"
>     line: 365
>     claim: "옵션 ① 은 compact 뒤 턴을 끝내고 사람이 다음 단계를 운반한다. 한 세션 지휘와 충돌하는 쪽은 옵션 ① 이다."
>     touches: []
>     decides: []
>   - id: RC8
>     path: "plugins/spec-distill/skills/spec-interview/references/finishing.md"
>     anchor: "이것은 아래 cross-compact 정지 요건의 *명시적 예외*다."
>     line: 387
>     claim: "옵션 ② 는 같은 세션에서 바로 brainstorming 을 호출하고 호출 프롬프트에 순서 문장을 싣는다(385행). 같은 세션으로 이어 가는 지휘와 핸드오프 문장으로 개입하는 방식(P7)이 이미 레포에 있다는 선례다."
>     touches: [P7]
>     decides: []
>   - id: RC9
>     path: "plugins/quality-gates/skills/critiquing-artifacts/SKILL.md"
>     anchor: "cost_class=variable(worst-case high)이라 이 upfront 게이트가 지출-전 명시 승인이다."
>     line: 138
>     claim: "규칙 안 설계의 선례다. 실행 범위를 고지하는 게이트 한 번을 지출 전 명시 승인으로 쳐서 동의 범위와 실행 범위를 같게 만든다. 대안이 분해 승인 게이트에 지출 동의를 싣자는 근거다."
>     touches: []
>     decides: []
> ```

**게이트-전 확인** — repo_claims 9: CLAUDE.md 45·85·87 확인(RC12·RC13·RC14) · 철학 55·51·67 확인(RC34·RC62·RC63) · finishing.md 365·387 확인(RC17·RC10) · critiquing-artifacts 138 확인(RC64) · 부착 주장 5건 → P2·P3·P5 확인(Replit 2차 보도, Chroma 요약) · 재검토 자격: 재검토 사유 없음 — 확인된 전제 충돌 0건

**사용자 선택** — 보완 (S11)

#### ST3 — 의도 왜곡 장치 전부 제거

**dispatch 입력** — goal: S6(「내말」 = S1 + S3·S4·S5) · 전제: P1 장치가 품질 저하·의도 어긋남을 만든다(S1·S3·도출) · P2 포화 조사가 하류 품질을 올린다(S1) · P3 나누면 더 상세(S1 미확인) · P4 분해는 인터뷰가(S1) · P5 spec 승인만으로 통제 유지(S1) · P6 장치 제거·수정이 의도를 보존(S3·S4) · P7 devbrew 가 외부 장치에 개입 가능(도출) · 제약: S1–S8 원문 전량 · trigger: 사용자 제약 충돌 — 통제 유지 요구를 지키는 장치 존재 + 장치별 판정·공시 대안

> ```yaml
> case_for_alternative:
>   statement: "범위는 약 37개 전부 그대로 두되, 장치마다 따로 판정한다. 결과는 「제거」 아니면 「수정」 둘 중 하나이고, 손대지 않고 남는 장치는 없다. 사용자의 다른 요구를 지키던 장치(상한·게이트)는 차단하던 것을 「공시하고 사용자가 여는」 형태로 고친다."
>   strongest: "goal 은 「내말 그대로」이고 그 「내말」에는 S4 「아님 수정이나」와 S1 의 「횟수 상한은 안전장치로만 둔다」 「크게 쓰기 전에는 규모만 알린다」 「PM 인 사용자의 결정권과 내용 검토가 유지돼야 하며 그 통제가 무너지면 실패」가 들어 있다. 「전부 제거」를 글자대로 집행하면 이 원문 셋과 충돌한다. 그래서 같은 사용자 말을 문자 그대로 읽어도 결론은 장치별 제거|수정이 된다. 구현을 읽어 보면 REREVIEW_CAP 은 비용 차단이 아니다. 상한을 넘으면 사용자가 자기 문구(extra_approval)로 라운드를 여는 PM 결정 지점이다. 이것을 지우면 의도 왜곡이 사라지는 게 아니라 사용자의 통제 지점이 사라진다. Anthropic 은 통제를 유지하려고 반복 상한을 두라고 권하고(building-effective-agents), MAST 는 「Step repetition」과 「Unaware of termination conditions」를 실패 유형으로 든다. 모델이 원래부터 과설계하는 경향도 문서화돼 있다. 따라서 overdesign 축의 결함은 79행의 동점 처리 사다리이고, 축 자체를 들어내면 의도를 「부풀리는」 왜곡이 보호 없이 열린다."
> case_for_current:
>   strongest: "S6 은 문제를 다시 짜는 단계 자체를 거부했다. 장치마다 모델이 「이건 안전장치라 남긴다」를 판정하는 순간, 사용자가 지목한 왜곡 유형(모델이 사용자 말을 재해석하는 것)이 판정 절차 안으로 다시 들어온다. 장치들이 지킨다고 내세우는 통제도 실제 구현에서는 통제를 빼앗는다. finishing.md 207행은 사용자가 확정 목록을 세 번째로 고치려 하면 전 항목을 provisional 로 강등하고 강제로 끝낸다. 사용자의 수정 의사를 시스템이 덮는 것이다. 이 밖에도 design-doc.md 79행은 사다리가 「한 방향 압력을 증폭한다」고 스스로 적고 있다. 외부 brainstorming 은 「YAGNI ruthlessly」(214행) · 모호하면 「pick one」(252행) · 「first sub-project」만(203행)을 지시한다. 최신 Claude 는 지시를 정확히 따르도록 훈련돼 있어서 이런 절감 지시가 그대로 범위 축소로 이어진다. 압축은 「subtle but critical context」를 잃는다. 「전부 제거」는 판정 재량을 0으로 만들어 왜곡이 다시 들어올 틈을 구조적으로 닫는 유일한 형태다."
> premise_refutation:
>   hits: [P2]
>   why: "P2 — Anthropic effective-context-engineering 문서는 「context rot」(맥락이 커질수록 「ability to accurately recall information from that context decreases」)와 「a finite resource with diminishing marginal returns」를 말한다. 이것은 P2 의 「brief 가 두꺼워지고 하류 품질이 오른다」가 단조 증가라고 보는 연결과 직접 충돌한다. 반증되는 범위는 「조사를 포화까지」 쪽이 아니다(multi-agent-research-system 의 「token usage by itself explains 80% of the variance」는 그쪽을 뒷받침한다). 반증되는 것은 「두꺼운 brief → 하류 품질」 고리다. 그래서 압축 규약·seed 압축은 지우지 말고 고쳐야 한다. 무엇을 버렸는지 공시하고, 원문 보존 경로를 둔다."
> premise_list_challenge: "빠진 전제가 하나 있다. 「장치를 제거해도 그 장치가 지키던 다른 사용자 요구는 함께 지워지지 않는다」이다. 이것이 거짓인 자리를 구현에서 확인했다. REREVIEW_CAP 의 extra_approval 경로는 S1 의 결정권 요구를 실현하는 자리이고, S1 은 상한을 「안전장치로」 남기라고 명시한다. 이 전제가 목록에 없어서 P6 이 지나치게 넓다. P6 은 「제거·수정」을 한 문장으로 묶어 두 처분이 의도 보존에 서로 다른 효과를 낸다는 점을 가리고 있으니 둘로 갈라야 한다. P7 은 선례(finishing.md 385행의 순서 문장)가 있지만, 핸드오프 문장이 「YAGNI ruthlessly」나 「pick one」 같은 외부 skill 본문 지시를 실제로 이기는지는 측정된 적이 없다. 그러니 이것은 사실이 아니라 「검증 필요」 전제로 표기해야 한다. P1 은 원인을 장치에만 돌린다. 그런데 모델이 원래 갖는 과설계 경향(Claude 공식 문서)은 장치 없이도 의도를 부풀리는 쪽으로 어긋나게 만든다. P1 은 「장치가 만드는 부분」으로 범위를 좁혀야 한다."
> recommendation: refined
> refined_takes: "범위는 약 37개 전부이고, S7 대로 새 장치가 나오지 않을 때까지 조사한다. 범위를 줄이지 않는다. 모든 장치가 「제거」 아니면 「수정」을 받고, 손대지 않고 남는 것은 0개다. 판정 기준은 하나로 고정한다. 비용·절감·압축 압력으로만 작동하거나 사용자 결정을 덮는 장치는 제거한다. 예시는 다음과 같다: 조사 예산·자격, 리듬 강제, 레포 조사 subagent 금지, floor 한 번 닫으면 종료, brief 제약 항목 모델 선별, /compact 보존 목록 누락, 하류에 지시 안 검, spec 리뷰 정답이 §2 뿐, 「동점이면 더 자르는」 사다리 규칙과 yagni/shrink 태그, 「지출 통제는 재리뷰 상한이 한다」, 확정 수정 2회 뒤 강제 강등, 외부 brainstorming·writing-plans 의 YAGNI·pick one·Bounded 면 spec 없음·첫 조각만에 대한 핸드오프 무력화. 외부 skill 무력화는 효과를 측정한다는 조건을 붙인다. S1 이 명시로 남긴 「안전장치 상한」과 「규모 공시」에 해당하는 장치는 차단을 공시와 사용자가 여는 형태로 수정한다. 예시: REREVIEW_CAP 2, qg 리뷰어 8·수정 5회, steelman 1회, 되묻기 2회. 압축 규약은 버린 것을 공시하고 원문 경로를 두는 형태로 수정한다."
> refined_drops: "상한 계열과 압축 계열에까지 「제거」라는 같은 동사를 일률적으로 적용하는 집행을 버린다. 이 계열에 일률 제거를 적용하면 S1 의 「횟수 상한은 안전장치로만」 「규모만 알린다」와 S4 「수정이나」의 원문을 어긴다. trigger 가 제시한 「유지+공시」 중 무변경 유지 분기도 버린다. 공시를 붙이는 것도 수정으로 셈하므로, 어떤 장치도 지금 모양 그대로 남지 않는다. 판정 근거로 「안전」을 모델 재량으로 쓰는 것도 버린다. 남길 수 있는 근거는 사용자 원문 인용(S1/S4)뿐이다."
> evidence:
>   - url: "https://www.anthropic.com/research/building-effective-agents"
>     supports: alternative
>     claim: "에이전트 루프에는 통제를 유지하려고 「stopping conditions (such as a maximum number of iterations)」를 두는 것이 일반적이고, 체크포인트에서 사람의 피드백을 받으려고 멈춘다 — 상한·게이트가 사용자 통제의 수단이다"
>     touches: [P6]
>     decides: []
>   - url: "https://arxiv.org/html/2503.13657v3"
>     supports: both
>     claim: "MAST 실패 유형 14개에 「Premature termination」「Information withholding」「Disobey task specification」(제거 쪽 근거: 일찍 닫기·핸드오프 누락)와 「Step repetition」「Unaware of termination conditions」(수정 쪽 근거: 상한이 막는 실패)가 함께 들어 있다"
>     touches: [P1, P6]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
>     supports: both
>     claim: "「overly aggressive compaction can result in the loss of subtle but critical context」(압축이 의도를 잃는다 — 제거 쪽 근거). 그러나 「context rot」로 맥락이 커질수록 회상이 떨어지고 맥락은 「a finite resource with diminishing marginal returns」다(두꺼운 brief 가 단조로 낫지 않다 — 압축은 지우지 말고 고쳐야 한다)"
>     touches: [P1, P2]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: both
>     claim: "「token usage by itself explains 80% of the variance」(조사량이 품질을 끌어올린다 — P2 의 조사 쪽 근거). 동시에 「Agents struggle to judge appropriate effort」「spawning 50 subagents for simple queries, scouring the web endlessly for nonexistent sources」(자기 판정 포화 정지만으로는 무한 탐색이 생긴다 — 안전장치 상한의 근거)"
>     touches: [P2]
>     decides: []
>   - url: "https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices"
>     supports: both
>     claim: "「Claude's latest models are trained for precise instruction following」 — YAGNI·pick one 같은 절감 지시는 글자대로 범위 축소로 이어진다(제거 쪽 근거). 같은 문서에 따르면 모델은 「a tendency to overengineer by ... building in flexibility that wasn't requested」 — overdesign 축은 실제 왜곡(부풀림)을 막는다(수정 쪽 근거)"
>     touches: [P1, P7]
>     decides: []
>   - url: "https://fs.blog/chestertons-fence/"
>     supports: alternative
>     claim: "「Do not remove a fence until you know why it was put up in the first place」 — 장치마다 그것이 지키던 요구를 확인한 다음에 처분해야 한다"
>     touches: [P6]
>     decides: []
> repo_claims:
>   - id: RC1
>     path: "shared/docreview/scripts/docreview_state.py"
>     anchor: "def cmd_begin_round — `if not a.extra_approval:` … `\"reason\": \"cap_reached\"`"
>     line: 505
>     claim: "REREVIEW_CAP = 2(41행)는 하드 정지가 아니다. 상한을 넘으면 사용자가 extra_approval 문구로 라운드를 열 수 있고 그 문구는 extra_rounds 에 기록된다. 이미 「공시+사용자가 연다」 형태의 PM 결정 지점이므로, 지우면 S1 의 결정권 경로가 사라진다"
>     touches: [P5, P6]
>     decides: []
>   - id: RC2
>     path: "plugins/spec-distill/skills/spec-interview/references/finishing.md"
>     anchor: "**재제시 상한** (금지 패턴 *Unbounded autonomy* 가드)"
>     line: 207
>     claim: "사용자가 세 번째로 ③(확정 목록 수정)을 요구하면 전 항목을 provisional 로 강등하고 게이트를 다시 보여 주지 않은 채 종료한다. 통제 가드라는 이름과 달리 사용자의 수정 의사를 시스템이 덮는다 — 제거 또는 수정 대상이다"
>     touches: [P1, P5]
>     decides: []
>   - id: RC3
>     path: "plugins/spec-distill/references/docreview-profiles/design-doc.md"
>     anchor: "⚠ 작은 쪽은 **언제나 더 많이 자르는** 해석이라 동점마다 판정이 절감 쪽으로 기운다"
>     line: 79
>     claim: "overdesign 사다리가 한 방향 절감 압력을 증폭한다고 스스로 공시한다. 균형 장치는 `└ 천장` 하나뿐이고 그것도 줄임을 막지 않는다. 같은 파일 83행은 「사용자가 명시로 요청한 동작」은 자르지 않는다고 적는다 — 결함은 동점 처리 규칙에 있고, 축이 과함을 보는 것 자체에 있지 않다"
>     touches: [P1]
>     decides: []
>   - id: RC4
>     path: "plugins/spec-distill/skills/spec-interview/references/finishing.md"
>     anchor: "brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다"
>     line: 385
>     claim: "devbrew 가 외부 skill 의 지시를 핸드오프 문장으로 덮어쓰려 한 선례다. 다만 이 문장이 외부 skill 을 실제로 이기는지 실측했다는 기록은 이 자리에 없다"
>     touches: [P7]
>     decides: []
>   - id: RC5
>     path: "/Users/jeonghokim/.claude/plugins/cache/claude-plugins-official/superpowers/6.4.1/skills/brainstorming/SKILL.md"
>     anchor: "- YAGNI ruthlessly - remove unnecessary features from every approach and design"
>     line: 214
>     claim: "외부 brainstorming 에 절감 지시가 실재한다: 214행 YAGNI, 252행 「If so, pick one and make it explicit」, 203행 「Then brainstorm the first sub-project」, 169행 bounded 면 「no plan doc」. writing-plans SKILL.md 10행 「DRY. YAGNI. TDD.」(레포 밖 플러그인 캐시라 경로는 절대경로)"
>     touches: [P7]
>     decides: []
>   - id: RC6
>     path: "CLAUDE.md"
>     anchor: "**Unbounded autonomy** — max-iter count, repeat 감지, 사용자-override kill switch 없는 루프."
>     claim: "레포 금지 패턴은 상한이 없는 루프를 금지한다. 같은 파일의 처분 규칙 「공시와 차단은 다른 술어다」가 차단을 공시로 바꾸는 수정 경로를 이미 정의하고 있다 — 상한 계열을 지우지 않고 고칠 근거다"
>     touches: [P6]
>     decides: []
>   - id: RC7
>     path: "plugins/spec-distill/agents/steelman-builder.md"
>     anchor: "7. **한 방향당 1회**: 같은 방향에 대한 재호출은 새 근거가 있을 때만."
>     line: 129
>     claim: "「steelman 1회」는 절대 상한이 아니라 새 근거가 있으면 다시 부를 수 있는 조건부 규칙이다. 목록의 장치마다 구현 모양이 다르다(하드 차단 / 조건부 / 사용자가 여는 상한)는 증거이므로 같은 처분을 일률로 적용할 수 없다"
>     touches: [P6]
>     decides: []
> ```

**게이트-전 확인** — repo_claims 7: docreview_state.py 505 확인(RC65) · finishing.md 207 확인(RC29) · design-doc.md 79·83 확인(RC7·RC66) · finishing.md 385 확인(RC10) · 설치본 brainstorming 214 확인(RC41) · CLAUDE.md 확인(RC14) · steelman-builder.md 129 확인(RC67) · 부착 주장 6건 → P1·P2·P6·P7 확인, hits P2 는 원문 인용(「context rot」·「a finite resource with diminishing marginal returns」)을 WebFetch 로 직접 확인 · 재검토 자격: 재검토 열림 — 전제 P2 충돌 확인 1건(context-engineering 원문 인용 직접 확인)

**사용자 선택** — 보완 (S10)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-10-11) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-10-11)

## 5. 프로세스 로그

- round 1: path (d) — 뿌리 재구성 제안 → 사용자가 재구성 단계 자체를 거부(S6)
- round 2: path (a)+(b) — 레포·외부 조사로 장치 목록 → 전부 대상·조사 계속(S7)
- round 3: path (b) — 리듬 가드 강제 차례, 바깥 사례 8건 처분(S8)
- round 4: path (b) — 생략 경고를 지도에 함께·구조적으로(S9)
- round 5–7: steelman ST3·ST2·ST1 게이트 — 전부 보완(S10·S11·S12)
- round 8: path (b) — 위험 14 전부(S13)
- round 9–22: path (b) — 컨트롤 플레인·포화 판정·인계·외부 경계·실행 판정·분해 기준·지도 거처·병렬·재개·개선 확인(S14–S32, 정정 S21–S24 · 조사 요청 S20·S28·S29)
- round 23: 분해안 → 「더 봐줘」(S33·S34·S35) → coverage-mapper #2 · 진행 중 브랜치 조사
- round 24–25: 외부 정지 그대로(S36) · @ 브랜치 먼저(S37) · seed 재대조 요청(S38) → 미결 8개 발견
- round 26–35: 넘기는 모양·상세함·큰 그림·외부 축소 대응·상한·교훈·정답 출처·상태 저장·분해 승인·열린 질문(S39–S48)

- 확인 RC1 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#coverage-mapper dispatch (자격 + 예산) — 주장과 일치
- 확인 RC2 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#blind-spot-prober dispatch — 주장과 일치
- 확인 RC3 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#C44 Dialectic Rhythm Guard — 주장과 일치(문턱 env override 516줄, 면제 규칙 실재)
- 확인 RC4 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#R2 Landscape 수집 — 주장과 일치(round 1–2 시점 449줄)
- 확인 RC5 — 확인 — plugins/spec-distill/skills/spec-interview/references/steelman.md#한 방향당 steelman 1회 — 주장과 일치
- 확인 RC6 — 확인 — plugins/spec-distill/references/reviewing-document.md#상한 rereview_cap: 2 — 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#언제나 더 많이 자르는 — 주장과 일치(판정자당 3건 상한 95줄)
- 확인 RC8 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#ground_truth — 주장과 일치. 단 layer2 handoff_incomplete 축이 있으나 그것은 Handoff Context·/compact 뒤 암묵 컨텍스트를 보고 brief §3·§4·§5 의 생존은 보지 않는다
- 확인 RC9 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#/compact 보존 목록 — 주장과 일치(§4·§5 미명시, web sweep 원문 drop)
- 확인 RC10 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#지시를 걸지 않고 — 주장과 일치(옵션 ② 프롬프트는 C4 문장 + 순서 문장뿐)
- 확인 RC11 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#scope_creep — 주장과 일치. 「인터뷰 단계에 분해 판단 없음」은 부재 주장이라 grep 기반(Phase 0 · 매퍼)
- 확인 RC12 — 확인 — CLAUDE.md#cost_class — 규칙 원문과 spec-interview cost_class: variable 일치. 「철학 P22」 부분은 읽지 않았다
- 확인 RC13 — 확인 — CLAUDE.md#Subagent spray — 주장과 일치
- 확인 RC14 — 확인 — CLAUDE.md#Unbounded autonomy — 주장과 일치
- 확인 RC15 — 확인 — CLAUDE.md#런타임 상태 — 주장과 일치(finishing.md 393줄 SessionEnd cleanup)
- 확인 RC16 — 확인 — docs/superpowers/specs/2026-09-22-interview-research-specialization-design.md#§F 동역학 — 주장과 일치(표 614–615, 「사용자가 시계다」 근거)
- 확인 RC17 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#여기서 턴 종료 — 주장과 일치(365 · 409 NG7)
- 확인 RC18 — 확인 — shared/tests/test_dispatch_disposition.sh#ANCHOR_DETECT — 주장과 일치
- 확인 RC19 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#탐색 경계 — 주장과 일치
- 확인 RC20 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#게이트 ③ — 주장과 일치
- 확인 RC21 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#재개방 — 충돌 때만 재개방 → 충돌 없는 인터뷰에서 조사 장치 실효 1회
- 확인 RC22 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#R2 — 「웹 1회 이상」은 하한이지 상한 아님(seed 서술 부분 반증 — 막는 건 RC1–RC3)
- 확인 RC23 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#C43 (a) — 레포 조사는 subagent 금지, subagent 자리는 셋뿐
- 확인 RC24 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#되묻기 — 같은 주제 2회 상한
- 확인 RC25 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#종료 driver — floor 5 closed 가 종료, 포화 조건 없음
- 확인 RC26 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#나가는 문 — 사용자 종료 시 박제
- 확인 RC27 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#규약의 거처 (C5) — brainstorming 은 frontmatter 를 안 읽음
- 확인 RC28 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#제약으로 승격할 항목을 고르고 — §2 승격을 모델이 고름
- 확인 RC29 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#재제시 상한 — 수정 2회 뒤 강등
- 확인 RC30 — 확인 — plugins/spec-distill/references/compression.md#깎이는 것
- 확인 RC31 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#무엇을 남기고 무엇을 깎는가
- 확인 RC32 — 확인 — plugins/spec-distill/references/docreview-profiles/seed.md#뺄셈 검사 — 범주 넷, omission 없음
- 확인 RC33 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#fix_anchors — omission 은 must_catch 지만 fix 는 §0·§2 만
- 확인 RC34 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#Cross-cutting 집행 — 정체 시 다른 접근
- 확인 RC35 — 확인 — plugins/spec-distill/tests/test_conducting_interview_stage.sh#X4 — 예산 식 테스트 락
- 확인 RC36 — 확인 — plugins/spec-distill/scripts/check_brief.py#budget_mapper_failures — 하한만 검사
- 확인 RC37 — 확인 — plugins/spec-distill/hooks/session-end-cleanup.py#docstring — SessionEnd 정리 + TTL-GC
- 확인 RC38 — 확인 — CLAUDE.md#SemVer bump — 병렬 조각의 version 파일 충돌
- 확인 RC39 — 확인 — plugins/spec-distill/templates/interview-brief-template.md#§4 한 줄 형식
- 확인 RC40 — 확인 — (레포 밖) superpowers 6.4.1 brainstorming/SKILL.md#first sub-project
- 확인 RC41 — 확인 — (레포 밖) brainstorming/SKILL.md#YAGNI ruthlessly
- 확인 RC42 — 확인 — (레포 밖) brainstorming/SKILL.md#Ambiguity check pick one
- 확인 RC43 — 확인 — (레포 밖) brainstorming/SKILL.md#Bounded no spec file
- 확인 RC44 — 확인 — (레포 밖) brainstorming/SKILL.md#writing-clearly-and-concisely
- 확인 RC45 — 확인 — (레포 밖) writing-plans/SKILL.md#Scope Check · DRY. YAGNI.
- 확인 RC46 — 확인 — (레포 밖) brainstorming/SKILL.md#Ask clarifying questions — brief 특별 대우 문구 없음(단 34행 「already supplies… reflect」는 있다)
- 확인 RC47 — 확인 — (레포 밖) subagent-driven-development/SKILL.md#Rulings, not stalls
- 확인 RC48 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#R1 Problem Reframe — 「seed 의 문장을 되풀이하는 것은 통과가 아니다」(orchestrator 경로 a · S6 지목)
- 확인 RC49 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#yagni: / shrink: · ### 상한 — brief 리뷰에도 overdesign 절감 태그와 판정자당 3건 상한
- 확인 RC50 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#지출 승인 게이트는 없습니다 — 「지출 통제는 엔진의 재리뷰 상한이 합니다」(reviewing-brief/SKILL.md 228 「이 자리의 지출 통제가 그것이다」) — 비용 이유의 품질 상한
- 확인 RC51 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Composition — at most 8 per iteration · commands/qg.md 125 fix-loop 최대 5회
- 확인 RC52 — 확인 — plugins/quality-gates/agents/code-recritic.md#lower — 「이 변경이 하지 않은 일을 하라는 처방」을 낮춤. 의도 보호 쪽일 수 있음(판정 필요)
- 확인 RC53 — 확인 — plugins/project-init/skills/project-init/SKILL.md#재질문 최대 3회 — 3회 뒤 charter step 강등
- 확인 RC54 — 확인 — plugins/plugin-audit/agents/plugin-auditor.md#drop the gap — 근거 약한 gap 은 버림(정밀도 필터, 판정 필요)
- 확인 RC55 — 확인 — plugins/spec-distill/references/reviewing-document.md#라벨 1–5 낱말 압축 — 선택지 라벨 압축
- 확인 RC56 — 확인 — shared/docreview/scripts/docreview_state.py#REREVIEW_CAP = 2 — 상한이 코드에 박힘. approval_gate_open = approval_ready or cap_reached or stagnation (1162행) — 상한·정체면 열린 게 남아도 승인 게이트가 열림
- 확인 RC57 — 확인 — shared/docreview/scripts/docreview_advice.py#RENDER_CAP = 8 — 조언 표시 8줄 뒤 접음(「외 N건 — <자리> 에 전부」 공시는 있음)
- 확인 RC58 — 확인 — plugins/quality-gates/skills/critiquing-artifacts/SKILL.md#effective_max_rounds — 산출물 비평 루프 기본 5라운드
- 확인 RC59 — 확인 — plugins/spec-distill/skills/spec-interview/SKILL.md#닫힘 · 재개방(394) — 「상한 없음 — 라운드는 사용자 답으로만 돌아 사용자가 시계다」
- 확인 RC60 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#73 — 세션 state 에 두지 않는 이유는 TTL-GC 24시간
- 확인 RC61 — 확인 — plugins/spec-distill/references/proceed-gate.md#재결정 규약 (P23)(81) — 확정 항목 단위, 분해·조각 사이 피벗 언급 없음(grep 0건)
- 확인 RC62 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#Law 1 집행(51) — qg PR 코멘트 게시는 상시 동의, 끄는 길 하나
- 확인 RC63 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#Law 1 × P17 집행(67) — 확정은 반증 대상, 근거+동의로 피벗
- 확인 RC64 — 확인 — plugins/quality-gates/skills/critiquing-artifacts/SKILL.md#upfront 게이트(138–139) — 지출 전 명시 승인으로 침
- 확인 RC65 — 확인 — shared/docreview/scripts/docreview_state.py#cmd_begin_round(500–513) — 상한 뒤 extra_approval 로 사용자가 라운드를 엶
- 확인 RC66 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#자르지 않는 것(81–84) — 사용자가 명시로 요청한 동작
- 확인 RC67 — 확인 — plugins/spec-distill/agents/steelman-builder.md#한 방향당 1회(129) — 새 근거 있으면 재호출
- 확인 RC68 — 확인 — plugins/spec-distill/skills/spec-interview/references/finishing.md#옵션 ①(364) — brief 하나를 brainstorming 하나로
- 확인 RC69 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#처분 안내(107–110) — 범위 변경은 decide
- 확인 RC70 — 확인 — plugins/spec-distill/skills/spec-interview#분해 어휘 grep — 0건(부재 주장, 하한)
- 확인 RC71 — 확인 — feature/next-session-at-handoff 의 docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md#§1 정본 — proceed-gate.md 개정: Step B ① `/new` · ② `/compact` **둘 다 다음 세션 줄을 노출하고 턴 종료**(지금 ② 는 같은 세션에서 바로 다음 skill). G3 「읽을 파일이 여럿이어도 규칙과 락을 고치지 않고」. 설계 3커밋·구현 계획 1554줄, 미머지. ↔ S1 「한 세션이 지휘해 끝까지」·ST2(옵션 ② 를 지휘자 경로 선례로) 와 정면 충돌 가능, 다중 brief(R4)와는 정합. [RC71 → OQ17]
- 확인 RC72 — 확인 — feature/plain-language-voice 미머지 11커밋(qg 쉬운 말 PR 3: 리뷰어 지적 plain 칸 · 합성기 첫 줄 · 게시 게이트) ↔ R2 의 qg 상한·리뷰 프로필 개편과 같은 파일군. [RC72 → OQ17]
- 확인 RC73 — 확인 — feature/qg-v10-differential 미머지 9커밋(qg v10 ⑤ 차등 테스트: run-test-selection · qg-worktree) ↔ R2 qg 개편 · R5 머지 의도 회귀에 qg 재사용. [RC73 → OQ17]
- 확인 RC74 — 확인 — plugins/spec-distill/references/docreview-profiles/design-doc.md#ground_truth source_interview — plugins 전체에서 이 이름은 이 한 줄뿐(쓰는 쪽 0)
- 확인 RC75 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#탐지·재비판 dispatch(364·381) — document·profile 등만, brief 미전달
- 확인 RC76 — 확인 — plugins/quality-gates/scripts/discover-spec.sh#D13 사슬 — 의도 앵커는 커밋 `Spec:` 트레일러 → 브랜치 메시지·PR 본문
- 확인 RC77 — 확인 — docs/superpowers/plans/2026-10-08-qg-v10-c5-differential.md#Goal·38 — 진행 중 ⑤ 가 spec_path·--plan·DISABLE_SPEC_CONFORMANCE 제거, intent_source·intent_note·intent_file 유지
- 확인 RC78 — 확인 — plugins/spec-distill/scripts/check_brief.py#type != interview-brief(1279) — 구조 게이트는 brief 타입 하나
- 확인 RC79 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#게이트 ②(465) — spec 승인 뒤 길은 writing-plans 직행·compact·수정뿐, 「지휘자로 돌아가 다음 조각」 없음
- 확인 RC80 — 확인 — docs/superpowers/specs/2026-08-05-agent-transparency-design.md#TaskCreated 배달지 표(359) — 통제 표면 기존 실측(S30)
- 확인 RC81 — 확인 — docs/superpowers/plans/2026-08-23-hook-write-path-bypass.md#review-dispatch.py(17회 언급) — 지금 트리에 없는 파일 전제, 고아 여부 확인 필요
- 확인 RC82 — 확인 — plugins/project-init/hooks/post-tool-use.py#validate_branch(117) — Bash 브랜치 명령에만 걸림, 네이티브 worktree 조각 브랜치는 우회
- 확인 RC83 — 확인 — plugins/spec-distill/README.md#superpowers (외부, optional) — 최소 버전 없음
- 확인 RC84 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P22 Cost Awareness — fan-out 선언·high 지출 전 승인
- 확인 RC85 — 확인 — docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md#13 — qg 진입 표면 재결정 필요

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 6건(D2.1 · D2.2 · D3.3 · D3.4 · drop 1 포함) · 열린 채 남은 항목 1건(b8f9a943#r3.1 — 고쳤으나 다음 라운드 관측 없음) · 반영 확인 대기 1건(0138b17b#r3.1)
- codex: 없음 — exit_nonzero(4회 호출 전부 종료 코드 1) · 웹: Claude doc-critic-web · codex 켜짐
- 냉독: 돌지 않음 — 도구 없는 냉독 에이전트에 문서를 경로로 넘겨 읽지 못함(unavailable)
- degrade: critic:fidelity:번들 경로 전달(3라운드) · pipeline:재비판 프로필 일부 요약(r1) · readback:경로 전달 → unavailable · codex 부재

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** 🗣 발화 (round 0):
  > spec-distill:coverage-mapper 이게 스콥을 줄이지도 않았음 좋겠어
- **S3** 🗣 발화 (round 0):
  > 내 의도를 왜곡하는 장치들 다 제거야
- **S4** 🗣 발화 (round 0):
  > 아님 수정이나
- **S5** 🗣 발화 (round 0):
  > 내가 방금 말한거도 진행할 항목 중 하나인거야
- **S6** 🗣 발화 (round 1):
  > 내말 그대로야 이거도 의도에 안맞는게 이 단계 자체 제거하자, 내말자체를 그대로 이해해 전부다니까
- **S7** ☑ 선택 (round 2):
  > 전부 대상, 더 찾기 (권장) — 목록 전부를 제거·수정 대상으로 받고 새 장치가 안 나올 때까지 조사 계속(다른 플러그인·훅까지)
- **S8** ☑ 선택 (round 3):
  > 전부 참고 재료 (권장) — 바깥 사례 8건 모두 설계 재료로(1~6 취함, 7·8 피함 반대 사례)
- **S9** 🗣 발화 (round 4):
  > 1, 구조적으로 정리가 필요할거 같음
- **S10** ☑ 선택 (round 5):
  > 보완 (builder·orchestrator 추천) — ST3: 장치 전부 대상, 모두 제거 또는 수정(그대로 남는 것 0). 비용·절감·압축으로만 작동하거나 사용자 결정을 덮는 것은 제거, 상한·압축은 공시하고 사용자가 여는 형태로 수정
- **S11** 🗣 발화 (round 6):
  > 2, 근데 내가 모르는 사이에 드리프트 되는것은 피하고 싶어 그리고 나는 파일로 소비하지 않아 컨트롤플레인으로 소비하지
- **S12** ☑ 선택 (round 7):
  > 보완 (builder·orchestrator 추천) — ST1: 인터뷰가 나누고 조각 지도를 냄. 하류의 재분해·축소 신호는 같은 지도로 돌아와 사용자 승인 뒤에만 재분해. 남은 조각 추적·이어받기
- **S13** ☑ 선택 (round 8):
  > 전부 위험으로 (권장) — 숨은 가정 7 · 실패 양식 7 모두 위험으로, 조각마다 설계가 답해야 함
- **S14** ☑ 선택 (round 9):
  > Claude Code 안 (권장) — 컨트롤 플레인(조각 지도·단계·빠진 것·드리프트 알림)은 지휘 세션 화면의 상태줄·패널. 파일은 뒤의 저장소일 뿐
- **S15** ☑ 선택 (round 10):
  > 기준 + 독립 판정 (권장) — 포화 기준: 조사를 더 해도 열린 결정을 바꾸거나 새 결정을 여는 사실이 없음. 쓰기 권한 없는 별도 판정자가 확인해야 멈춤. 결과는 컨트롤 플레인에
- **S16** ☑ 선택 (round 11):
  > 번호 단위 인계 + 대조 (권장) — brief 의 모든 항목을 번호로 넘기고 spec 은 번호마다 반영 또는 기각+이유. spec 리뷰가 빠진 번호를 잡아 컨트롤 플레인 생략 경고로
- **S17** 🗣 발화 (round 12):
  > 외부는 건들지 말자
- **S18** ☑ 선택 (round 13):
  > devbrew 쪽만 바꾼다 (권장) — superpowers 파일·동작은 그대로. devbrew 가 넘길 때 보내는 글(번호 인계)과 돌아온 결과 검사(spec 리뷰)는 한다
- **S19** ☑ 선택 (round 14):
  > 보이고, 어긋나면 멈춤 (권장) — 모든 실행 판정을 컨트롤 플레인에 실시간으로. 승인된 spec 과 어긋나면 그 조각만 멈추고 묻고, 나머지 조각은 계속
- **S20** 🗣 발화 (round 15):
  > 더 좋은 방안 없을지 조사해봐, superpowers쪽은 무조건 하나 조사하고
- **S21** 🗣 발화 (round 15):
  > 아니다 이쪽은 건들지 말자
- **S22** 🗣 발화 (round 15):
  > 보이기로 해줘
- **S23** 🗣 발화 (round 15):
  > 구현중에 멈춘다는거였자나 맞지?
- **S24** 🗣 발화 (round 15):
  > 룰링이야기야
- **S25** ☑ 선택 (round 16):
  > 로드맵 + 걷는 뼈대 (권장) — 로드맵(고정 번호·한 줄 의도·범위 경계·의존·상태)을 조각 지도로, 가능하면 조각 0 은 걷는 뼈대, 조각 사이 인터페이스 먼저, 조각이 끝날 때마다 남은 조각 재평가 — 바뀔 때만 승인
- **S26** ☑ 선택 (round 17):
  > 레포 안 추적 파일 (권장) — 로드맵은 git 추적 파일로, 세션·압축·기기를 넘어 생존, 이력으로 덮어쓰기 복구
- **S27** 🗣 발화 (round 18):
  > 1, devbrew만 생각하지 마 여기서만 사용이 아니니까, 그리고 머지는 기계적 충돌만이 아니라 서로 의도 회귀 등 문제 안생겨야겠지 그럴 수 있게 오케스트레이터가 잘 해야겠고
- **S28** 🗣 발화 (round 19):
  > 1, superpowers쪽에도 이런게 있어 잘 연결될지 생각해봐 SDD중에, 그리고 병렬 머지 원칙의 경우 더 조사해봐
- **S29** ☑ 선택 (round 20):
  > 더 조사 — 의도 회귀 자동 감지 사례, Claude Code 자체 병렬 기능을 더 찾기
- **S30** 🗣 발화 (round 20):
  > 그리고 원래 있는걸 더 만들생각 말고
- **S31** ☑ 선택 (round 21):
  > 전부, 실험 기능은 제외 — SDD 연결·머지 원칙 7·Claude Code 기본 기능·의도 회귀 감지 모두 재료로, 있는 것 먼저(S30). agent teams 같은 실험 기능은 기반으로 쓰지 않음(작업 목록·worktree 격리·SDD·qg 만)
- **S32** ☑ 선택 (round 22):
  > 내가 쓰면서 판단 — 개선 여부는 따로 재지 않고 사용자가 쓰면서 체감으로 판단
- **S33** 🗣 발화 (round 23):
  > 우리 봐야하는건 이거보다 더 많아 더 봐줘
- **S34** 🗣 발화 (round 23):
  > 그리고 잘 만들어져 있는 외부 플러그인을 어그러 트리지 말고
- **S35** 🗣 발화 (round 23):
  > 너가 큰 잘업도 잘 할 수 있을지 여기서 확인해 볼 수 있겠네 교훈도 있겠고
- **S36** ☑ 선택 (round 24):
  > 외부 정지 그대로 — superpowers 가 조각마다 사람에게 묻는 자리(plan 검토·실행 방식 선택·머지 메뉴)는 설계된 대로 사용자에게 묻게 둔다
- **S37** ☑ 선택 (round 25):
  > 그 브랜치 먼저 (권장) — 「다음 세션 @ 명령」 브랜치를 먼저 구현·머지하고 이번 일은 그 위에서. 지휘 세션은 /new + @로드맵 으로 연다
- **S38** 🗣 발화 (round 25):
  > 시드를 다시 읽어봐 내 요청이 다 해결 안되었는데
- **S39** ☑ 선택 (round 26):
  > 원본 + 로드맵 + 조각 묶음 (권장) — 원본 brief 하나가 정본, 로드맵이 조각을 잇고, 조각마다 사용자 원문 전부·공통 목표·인터페이스·그 조각 번호 항목만 담은 묶음, 묶음은 원본·로드맵을 거꾸로 가리킴
- **S40** ☑ 선택 (round 27):
  > 답할 목록 + 깊이 확인 (권장) — 조각 묶음에 spec 이 답해야 할 결정·질문·위험을 번호로, spec 리뷰가 번호마다 답이 구체적인지 확인, 얕으면 컨트롤 플레인 경고
- **S41** ☑ 선택 (round 28):
  > 발화 번호 인용 + 전체 속 위치 (권장) — 조각 spec 이 받드는 사용자 발화 S번호를 밝히고, spec 승인 때 로드맵 전체 속 위치와 이웃 조각 결정을 함께. 어느 조각도 받들지 않는 발화는 경고
- **S42** ☑ 선택 (round 29):
  > 받는 입력 + 번호 대조 (권장) — 외부가 받아 주는 입력만(조각 묶음으로 목적·제약 미리, 승인된 로드맵의 한 조각임을 밝힘). 「~보다 우선한다」 덮어쓰기 문장은 뺌. 돌아온 spec 을 번호로 대조해 빠짐·축소·재분해를 경고하고 지도로 되돌림
- **S43** ☑ 선택 (round 30):
  > 조사 호출 20회 (권장) — 인터뷰 하나에서 조사 장치 호출 20회에 닿으면 컨트롤 플레인에 알림, 환경 변수로 변경, 사용자가 연장
- **S44** 🗣 발화 (round 31):
  > 따로 다루지 않음
- **S45** ☑ 선택 (round 32):
  > 조각 묶음을 직접 넘김 (권장) — spec 리뷰를 부를 때 그 조각 묶음과 로드맵 경로를 함께 넘기고, spec 리뷰는 묶음(번호 항목·조각의 몫·원문)을 정답으로. 외부는 손대지 않음
- **S46** ☑ 선택 (round 33):
  > 흡수 (권장) — 상태 저장 재설계 D1~D4 를 이번 로드맵의 조각으로: 인터뷰 상태는 docs, 임시 폴더는 리뷰 상태만, 이어 하기는 로드맵 기반, 긴·병렬 실행 중 리뷰 원장 소실 방지 포함
- **S47** ☑ 선택 (round 34):
  > 이대로 승인 (권장) — 고친 분해안(선행 3: @ 브랜치 머지 · qg ⑤·PR3·진입 이름 · hook 브랜치 고아 확인 + R0~R9, 순서 @ 브랜치 → R0 → R1‖R2‖R7‖R3‖R4‖R6 → R2a·R5 → R8 → R9) 승인
- **S48** ☑ 선택 (round 35):
  > 이대로 넘김 (권장) — 열린 질문 8개(예외 멈춤 · 장치별 처분·전수 계속 · R0 실측의 R5 영향 · qg 연결 · 독립 판정자 · 파일 규약 범용성 · 표시 범위 · 지출 조항 문안)를 brief §3 과 조각 묶음으로

- **S49** ☑ 선택 (round 36):
  > 채택 — 작업 범위 전체로 (brief 리뷰 r2 결정 D2.1: 목표 절 「범위를 줄이지 않는다」를 작업 범위 전체로 읽고 근거를 S6+S3, S2 는 coverage-mapper 로 따로)
- **S50** ☑ 선택 (round 36):
  > 채택 — OQ36 유지 (brief 리뷰 r2 결정 D2.2: 열린 질문 절에 「spec 하나로 되는가」 판단 기준 OQ36 을 더한 변경 유지)
- **S51** ☑ 선택 (round 37):
  > 채택 — qg 조각 앞만 (brief 리뷰 r3 결정: 선행 3 중 qg 쪽 조건(qg ⑤·쉬운 말 PR 3·진입 이름)은 qg 를 건드리는 R2a·R5 앞에만, R0 은 @ 브랜치만 기다림)

## 7. 확산 원자료

- «anthropic-multiagent» — https://www.anthropic.com/engineering/multi-agent-research-system
- «arxiv-2608.15191» — https://arxiv.org/pdf/2608.15191
- «tianpan-convergence» — https://tianpan.co/blog/2026-04-12-deep-research-agents-orchestrating-multi-step-search-that-converges
- «arxiv-2604.24978» — https://arxiv.org/pdf/2604.24978
- «saunders-saturation» — https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5993836/
- «infinite-agentic-loops» — https://huggingface.co/papers/2607.01641.md
- «contextchain» — https://lablab.ai/submissions/y3yi9ptyt665avp17d638f2p
- «lightrun» — https://lightrun.com/blog/ai-agent-orchestration/
- «bmad» — https://claudeskills.info/skills/aj-geddes/claude-code-bmad-skills/bmad-epics-and-stories/
- «taskmaster» — https://docs.task-master.dev/command-reference.md
- «kiro-spec-batch» — https://tessl.io/registry/skills/github/gotalab/cc-sdd/kiro-spec-batch
- «recursive-sdd» — https://smithery.ai/skills/handol-park/recursive-sdd
- «ralph-specum» — https://www.claudepluginhub.com/skills/tzachbon-ralph-specum-plugins-ralph-specum-2/spec-workflow
- «superpowers-issue-1173» — https://github.com/obra/superpowers/issues/1173
- «spec-kit-spec-of-specs» — https://github.github.com/spec-kit/concepts/spec-of-specs.html
- «eugenelim-pr11» — https://github.com/eugenelim/company-intelligence-desk/pull/11
- «shapeup» — https://basecamp.com/shapeup/3.4-chapter-13
- «adapt» — https://arxiv.org/pdf/2311.05772
- «spec-kit» — https://ssojet.com/blog/best-spec-driven-development-tools
- «superpowers-brainstorming-main» — https://raw.githubusercontent.com/obra/superpowers/main/skills/brainstorming/SKILL.md
- «lost-in-middle» — https://arxiv.org/abs/2307.03172
- «anthropic-long-running» — https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
- «anthropic-building-agents» — https://www.anthropic.com/engineering/building-effective-agents
- «cognition-multi-agents» — https://cognition.com/blog/dont-build-multi-agents
- «mast» — https://arxiv.org/html/2503.13657v3
- «context-engineering» — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- «chroma-context-rot» — https://research.trychroma.com/context-rot
- «claude4-best-practices» — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-4-best-practices
- «chesterton-fence» — https://fs.blog/chestertons-fence/
- «sycophancy» — https://www.anthropic.com/research/towards-understanding-sycophancy-in-language-models
- «approval-fatigue» — https://tianpan.co/blog/2026/06/25/approval-fatigue-how-human-in-the-loop-gates-decay-into-rubber-stamps
- «replit-incident» — https://fortune.com/2025/07/23/ai-coding-tool-replit-wiped-database-called-it-a-catastrophic-failure
- «graphite-mergequeue» — https://graphite.dev/blog/what-is-a-merge-queue
- «mergify-queue» — https://mergify.com/blog/merge-queue-mode-skips-safety-check-on-purpose
- «worktree-merge-conflicts» — https://dev.to/raylabs/handling-git-merge-conflicts-in-multi-agent-worktrees-1em8
- «augment-worktrees» — https://www.augmentcode.com/guides/git-worktrees-parallel-ai-agent-execution
- «cdc-contracts» — https://microsoft.github.io/code-with-engineering-playbook/automated-testing/cdc-testing/
- «spec-drift-traceability» — https://dev.to/rosgluk/keeping-specs-tests-and-code-in-sync-in-ai-development-jm4
- «coverge-regression» — https://coverge.ai/blog/llm-regression-testing
- «arxiv-2604.03447» — https://arxiv.org/pdf/2604.03447
- «arxiv-2606.26924» — https://arxiv.org/pdf/2606.26924
- «arxiv-2608.13867» — https://arxiv.org/pdf/2608.13867
- «cc-agent-teams» — https://code.claude.com/docs/en/agent-teams
- «cc-subagents» — https://code.claude.com/docs/en/sub-agents
- «superpowers-repo» — https://github.com/obra/superpowers
- «superpowers-sdd» — https://raw.githubusercontent.com/obra/superpowers/main/skills/subagent-driven-development/SKILL.md
- «decomposing-requirements-fork» — https://claudepluginhub.com/skills/lzy-ricardo-superpowers/decomposing-requirements

## 8. 리뷰 결정

- D2.1 · r2 · adopt · 0fbd6ae3#r2.1 · "채택 — 작업 범위 전체로" — §1 Goal 의 '범위를 줄이지 않는다(S2·S6)'는 근거를 넘어섭니다. S2 는 조사 장치 coverage-mapper 하나에 대한 바람이고, S6 의 '전부다니까'는 '내 말을 전부 그대로 이해하라'(문제 정의)로도, '전부 하라'(작업 범위)로도 읽힙니다. 원문이 두 가지로 읽히고 §1 은 보호 대상이라 사용자 결정이 필요합니다.
- D2.2 · r2 · adopt · 4039a5a0#r2.1 · "채택 — OQ36 유지" — finding 없이 바뀜: 3. Open Questions (modified)
- D3.3 · r3 · adopt · 0138b17b#r3.1 · "채택 — qg 조각 앞만" — S47 은 @ 브랜치 머지와 함께 qg 쪽 선행 조건(qg ⑤·쉬운 말 PR 3·진입 이름)과 훅 브랜치 고아 확인까지 셋을 「선행 3」으로 묶었다. 한눈에는 qg 쪽 조건을 공유 리뷰 엔진(R2a)·지휘자(R5) 앞으로만 좁혔다. 원문은 두 가지로 읽힌다: 「선행 셋 모두 R0 앞」, 또는 「순서 줄에 적힌 @ 브랜치만 R0 앞」.
- D3.4 · r3 · adopt · ad526e9e#r3.1 · "채택 — 기각 줄 수정 유지" — finding 없이 바뀜: 5. 기각 · Blind Spots (modified)
- D3.5 · r3 · drop · 40f9462c#r1.1 · "버린다 — 게이트 필수 문구" — 항목 목록 머리의 「confirmed 0건 — 사용자가 전부 잠정으로 판단」은 이 판단을 사용자에게 돌리지만, 두 원문 어디에도 사용자가 항목을 잠정으로 정했다는 말이나 선택이 없다.
- docreview 계수 — 6e137b56-45f4-43d3-88d2-7fff3ba03a0a/2026-10-11-persistent-explore-pm-decompo-0a9e6dd3c579f721 r1: advice_new=3 · advice_repeat=3 · mc_preexisting_new=0
- docreview 계수 — 6e137b56-45f4-43d3-88d2-7fff3ba03a0a/2026-10-11-persistent-explore-pm-decompo-0a9e6dd3c579f721 r2: advice_new=0 · advice_repeat=1 · mc_preexisting_new=1
- docreview 계수 — 6e137b56-45f4-43d3-88d2-7fff3ba03a0a/2026-10-11-persistent-explore-pm-decompo-0a9e6dd3c579f721 r3: advice_new=0 · advice_repeat=2 · mc_preexisting_new=0
