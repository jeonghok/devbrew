---
type: interview-audit
payload: 2026-11-14-conductor-context-economy-brief-interview.md
created_at: 2026-11-14
session_id: 1db2fcc3-3cab-40d9-8250-d061331e0172
source: spec-distill pm-interview
---

# Conductor Context Economy — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S1(첫 요청 원문 — seed 첫 문단의 출처) + S2 「같은 뿌리 (권장)」 — 토큰 낭비와 공유 누락은 맥락이 대화·메시지에만 쌓이고 파일에 안 남는 같은 뿌리
- floor:landscape — closed — S4 「하위 agent + 실행기 칸 (권장)」 — 지형(조사 4) 처분: 하위 agent 취함 · agent 팀 · 헤드리스 기본 · herdr 류 외부 실행기 기본은 피함(실행기 칸으로만)
- floor:skepticism — closed — S8 ST1 판정 「보완」 — 파일 규약은 취하고 읽기 설계 · 행동 직후 결정 기록을 같은 첫 단추로, 되읽기 보증은 산출물 대조로
- floor:blind_spot — closed — S7 premortem 처분 — 리프레시는 품질 신호 · 일꾼 파일은 대조해 믿기 · 작은 일은 가볍게 받음, 역할은 agent 정의로 기각
- floor:open_questions — closed — S30 「이대로 넘김 (권장)」 — 열린 질문 OQ21–OQ32 를 설계로 넘김
- derived:internal_research — closed — R1 조사에서 repo_claims 첫 산출 — 조사 행위가 함의; S20 — 조사 8 레포 장치 목록(RC49–RC91)과 조사 1–10 레포 주장 처분: 「있는 것을 새 자리로」 갈아탐을 받음
- derived:걷어낼 장치와 갈아타는 길 — closed — 보고 전문 메시지 규칙(RC1)·기계 상태 표(RC7) 등 지금 장치가 새 규칙과 부딪히고, 도는 로드맵 이전·판 올림이 미정; S41 조건 붙은 규칙은 적용 조건 칸을 두고 지휘자가 시작 묶음에 골라 실음 + S36(바이트 예산 · 반증 삭제 · 맨 위 안 함 · 반례 확인 승격) · S20 · S21 · S18 · S27 (재개방 2회 — 조사 20 — 경로 조건 규칙이 격리 worktree 하위 agent 에 안 실리고 플러그인 배포 불가 · .gitignore 가 막음)
- derived:플랫폼에 있는 것과 새 파일 규약의 경계 — closed — 세션 간 메시지·agent 팀 mailbox·agent memory 가 대화 계약 일부를 이미 준다(E4·E5·E3) — 있는 것 먼저 대 외부 의존 회피; S28 지금 안(git 편지함 + 감시자) + 기성 기법(자체 세션 받은 편지함 · asyncRewake) 차용
- derived:일꾼 실행 방식과 역할 경계 집행 — closed — 하위 agent·팀원·세션·claude -p 마다 CLAUDE.md 적재·Skill·실패 노출·도구 권한이 다르다(E2·RC13) — 역할 CLAUDE.md 대 tools allowlist; S4 실행 방식 · S7 역할은 agent 정의로 기각(역할 CLAUDE.md 적재 방식은 OQ7 로 남김)
- derived:파일 글의 믿음 경계 — closed — 지금은 하위가 쓸 수 있는 파일을 판정 근거로 안 쓴다(RC5) — inbox·결과 파일 보고·해시 승인이 이 경계를 넓힌다; S7 「일꾼 파일은 대조해 믿기」
- derived:토큰 재기와 리프레시 방식 — closed — 압축은 사용자만(RC3), 하위 agent 는 자동 압축(E1), 단계마다 새 agent(RC12) — 측정원·문턱·과제 단위; S6 mod 로 측정 · 표시, S7 리프레시는 품질 신호, S12 진행 agent 교대는 기존 장치에 맡김 · 과제 = 에픽, S13 지휘 세션은 사용자가
- derived:결정론 경계(P8)와 단계표 — closed — P8 이 순서 강제 결정론을 금한다(RC2) — 무엇을 어디까지 결정론으로; S37 순서는 스크립트가 지키되 사람 승인 탈출구, 동시 수는 레포 설정(무거운 일 기본 2) — S14 를 다듬음 (재개방 1회 — 조사 18 — 순서 강제가 탈출구 락과 충돌, 동시 2 리터럴이 이식성 줄과 충돌)
- derived:팀 상태 배치와 기계 간 조정 — closed — 잠금·표지가 한 기계 파일시스템 전제(RC8), 추적/무시 파일 규칙(RC9), 병렬 권장 3 대 동시 2 상한(RC14); S35 지휘자 상태 브랜치(코드 없음 · STATUS 는 그 지휘자만 · 편지함 한 글 한 파일 · main 에 머지 안 함) + S34 코드는 기본 main · 선택으로 로드맵 취합 + S9 · S23 · S24 · S26 (재개방 1회 — 조사 13 — main 직접 커밋 금지 · 보호 권장과 S17(STATUS 를 계산해 커밋)의 자리가 충돌, 사용자가 S33 으로 다시 엶)
- derived:사람이 보는 면 — closed — 작업 목록 도구가 새 모델에서 기본으로 빠짐(E6, 이 세션 도구 목록에도 없음)·SessionStart 훅 부재(RC10); S3 STATUS 파일 + S6 「1」 mod 하나로
- derived:작은 일과 작업 방식 결합 — closed — trivia escape(RC11)와 「작은 일도 지휘자」, superpowers 필수 결합(RC6); S7 「작은 일은 가볍게」 + seed 확인 문장(superpowers 에 묶이지 않음)

## 2. Budget

- 질문 라운드: 16 · agent dispatch: 28 · coverage-mapper 1 · codex 실호출: 3 (성공 3)
- 조사 호출 17/60 (장치별: 커버리지 1 · 맹점 2 · 반론 1 · 레포 조사 3 · 만든 조사 10 · 본체 직접 3)
- 포화 판정 1: 아직 — 빈 곳 5개
- 포화 판정 2: 아직 — 빈 곳 7개
- 포화 판정 3: 아직 — 빈 곳 6개
- 포화 판정 4: 아직 — 빈 곳 4개
- 사용자 종료(@S42) — 마지막 판정 아직

## 3. Steelman 원문

#### ST1 — 「같은 뿌리 → 파일 규약 먼저」 진단의 반론 검토

**dispatch 입력** — goal: S1 · 전제: P1 토큰 낭비의 주된 원인은 맥락이 대화 · 메시지에 쌓이는 것(S2) · P2 공유 누락의 주된 원인은 맥락이 파일에 남지 않는 것(S2) · P3 파일 규약을 먼저 세우면 둘 다 준다(S2 + seed 확인) · P4 받음 확인 · 되읽기 약속이 있으면 전달된다(seed 확인) · P5 메시지는 짧게 · 자세한 것은 파일 경로로(orchestrator 도출) · 제약: S1–S7 원문 전량 · trigger: landscape 모순(P14 이미 있음 · 75KB 절차서 매번 읽음 · Cognition · MAST · 다중 agent 15배)

> ```yaml
> case_for_alternative:
>   statement: "뿌리는 «파일이 없음»이 아니다. «누가 · 언제 · 무엇을 · 얼마나 읽는가»(읽기 설계)와 «행동에 묻은 결정이 그 자리에서 글로 옮겨지지 않음»(결정 외재화)이 뿌리다. 그러니 첫 단추는 역할 · 단계별 읽기 예산과 결정 기록의 쓰기 시점이고, 파일 규약은 그 둘을 담는 그릇이다."
>   strongest: "goal 의 첫 불만은 «토큰 너무 많이 들음»이다. 이 레포에서 확인된, 매번 반복되는 고정비는 대화가 아니라 «읽는 파일»에서 나온다. 지휘자는 부를 때마다 75KB 절차서 전체를 Read 하고(RC1), 그 안에는 이 skill 안에서는 따르지 않는다고 명시한 「손으로 따르는 절차」 절까지 들어 있다. 레포 철학(P5)은 이미 «최소 인덱스만 preload, 나머지는 just-in-time» 이라고 적었는데도 그렇다(RC2). 그러니 파일이 있느냐가 아니라 읽기가 설계되었느냐가 갈린다. 공식 문서도 같은 쪽이다. CLAUDE.md 는 200줄을 넘으면 «consume more context and reduce adherence» 이고, import 로 나눠도 비용이 줄지 않는다. Chroma 는 입력이 길수록, 관련 없는 단락 하나만 끼어도 성능이 떨어진다고 쟀다. 팀 공통 CLAUDE.md · 역할 CLAUDE.md · INTENT · STATUS · HANDBOOK · inbox 를 일꾼이 시작할 때마다 읽게 하면 dispatch 마다 드는 고정비와 주의 분산이 함께 오른다. 공유 누락 쪽도 Cognition 이 짚는다. 병렬 하위끼리의 충돌은 «conflicting assumptions not prescribed upfront», 곧 아무도 글로 쓰지 않은 결정에서 나온다. 파일 칸이 있다고 그 결정이 적히지는 않는다. MAST 는 정보를 갖고도 무시하는 실패(FM-2.5)와 말한 추론과 다른 행동(FM-2.6)을 따로 분류했다. 이 둘은 받음 확인 · 되읽기로 막히지 않는다."
> case_for_current:
>   strongest: "goal 이 직접 요구하는 «적절한 순간의 리프레시»(지휘 세션과 구현 담당자 모두)는 상태가 대화 밖에 살아 있어야 성립한다. 파일 없이 리프레시하면 맥락을 통째로 잃는다. Anthropic 의 장기 실행 하니스는 «each session begins with no memory» 를 전제로 progress 파일 · feature list · git log 를 세션 시작 때 읽혀 한 세션에 기능 하나씩 끊어 가게 했다. Anthropic 다중 agent 연구 시스템은 하위의 결과를 파일시스템에 두고 가벼운 참조만 넘겨 «game of telephone» 을 줄였다. 지금 레포는 그 반대다. 하위가 판정 전체와 AC 보고 전체를 마지막 메시지에 싣게 되어 있어(RC3) 긴 보고가 고스란히 지휘자 맥락에 쌓인다. goal 의 «보고 · progress · 지휘 문서» 세 항목이 바로 이 자리다. 한 agent 가 리뷰에서 계획까지 이으면 맥락이 백만 토큰 가까이 커진다는 레포 실측(RC4)도 «대화에 쌓임»이 실제 비용원임을 보인다. 읽기 설계(just-in-time)도 파일로 쪼개 둔 것만 골라 읽을 수 있다. 그러니 파일 규약은 대안의 전제 조건이고, 먼저 세우는 순서가 맞다."
> premise_refutation:
>   hits: [P1, P2, P4]
>   why: "P1 — RC1(plugins/spec-distill/skills/epic-conductor/SKILL.md 「### 5. 지휘 순환」 Read 두 줄)이 문제다. 지휘자는 부를 때마다 conducting.md 전체(75,138 바이트, Phase 0 측정 약 3.5만 토큰)를 읽고, 그 안의 「## 손으로 따르는 절차」는 같은 SKILL 169행이 «이 skill 안에서는 따르지 않는다»고 한 절이다. https://www.anthropic.com/engineering/multi-agent-research-system 은 다중 agent 가 채팅의 약 15배 토큰을 쓰고 토큰 사용량이 성능 분산의 80%를 설명한다고 적는다. 이 둘은 토큰이 «무엇을 몇 agent 가 읽는가»에서 크게 나온다는 근거다. 그래서 «토큰 낭비의 주된 원인은 맥락이 대화 · 메시지에 쌓이는 것»의 «주된»과 충돌한다. 레포에는 토큰을 세는 코드가 없어 «주된»이라는 말 자체가 재지 않은 주장이다. 대화 누적도 원인 하나인 것은 RC4 가 지지하므로, 반증되는 것은 «주된»과 그 원인 배정이다. P2 — https://cognition.com/blog/dont-build-multi-agents 가 문제다. 병렬 하위의 충돌을 «actions … based on conflicting assumptions not prescribed upfront»로 설명하고, 과제 원문을 복사해 넘기는 것으로는 부족하다고 한다. https://arxiv.org/html/2503.13657v2 FM-2.4(정보 보유자가 나누지 않음)도 같은 쪽이다. 이 둘은 누락의 원인이 «쓰이지 않은 결정 · 나누지 않기로 한 판단»에 있다고 본다. 그러니 «공유 누락의 주된 원인은 맥락이 파일에 남지 않는 것»과 충돌한다. 저장 매체가 없어서가 아니라 글로 쓰이지 않아서다. 레포의 relay 경로는 이미 원문 · 질문 · 답을 파일로 남기고 대조까지 한다(RC5). 그러니 적어도 그 경로에서는 «파일 없음»이 원인일 수 없다. P4 — https://arxiv.org/html/2503.13657v2 가 문제다. FM-2.5(다른 agent 의 입력을 받고도 무시)와 FM-2.6(말한 추론과 다른 행동)은 받는 쪽이 읽고 되말할 수 있어도 생기는 실패다. 5.2절은 전술적 수정만으로는 «not all failure modes are eradicated»이고, 높은 신뢰성에는 «more fundamental changes to agent organization, communication protocols»가 필요하다고 결론낸다. https://code.claude.com/docs/en/memory 도 지시 파일을 «context, not enforced configuration»이라고 적는다. 그러니 «받음 확인 · 되읽기 약속이 있으면 … 실제로 전달된다»와 충돌한다. 되읽기는 읽었다는 증거일 뿐 적용했다는 증거가 아니다."
> premise_list_challenge: "빠진 전제가 넷이고 기대고 있는 전제가 둘이다. (1) 읽기 설계 전제가 없다. 누가 · 언제 · 무엇을 · 얼마나 읽는가가 목록 어디에도 없다. 그런데 매번 읽는 지휘 절차서(RC1), 자동으로 실리지 않는 역할 CLAUDE.md(OQ7), 일꾼마다 시작할 때 읽는 묶음이 토큰과 전달을 함께 정한다. 120줄 상한도 HANDBOOK 목차 하나에만 걸려 있고, 일꾼이 시작할 때 읽는 묶음 전체에는 걸려 있지 않다. (2) 측정 전제가 없다. P1 · P2 의 «주된»은 기준선 없이 정해졌다. S6 으로 측정 수단(mod)은 골랐지만, 규약보다 측정이 먼저 또는 함께 와야 한다는 전제가 목록에 없다. (3) 결정 기록의 쓰기 시점과 주체가 없다. INTENT.md 의 «결정 기록» 칸은 결정한 행동 직후 그 행동자가 써야 Cognition 이 말한 암묵적 결정을 잡는다. 과제 시작 때 한 번 만드는 파일로는 못 잡는다. (4) 캐시 경제가 없다. 새 일꾼 · 리프레시 · 시작 때 파일을 많이 읽을수록 캐시를 다시 쓴다(Manus: KV-cache 적중률이 가장 중요한 지표). S7 「리프레시는 비용 아닌 품질 신호」와 같은 방향이니 전제로 올려야 한다. 기대는 전제 — P3 는 P1 ∧ P2 의 결론이라 위 hit 를 그대로 물려받는다. 특히 «토큰이 함께 준다»는 반쪽은 읽기 설계 없이는 성립하지 않고, 오히려 늘 수 있다. P5 는 결과 파일이 지워지지 않는 자리를 전제한다. 지금 규칙은 바로 그 이유(실행 방식이 작업 폴더를 지울 수 있다) 때문에 반대로 되어 있다(RC3). 그 자리를 정하지 않으면 P5 는 성립하지 않는다. 범위 메모 — 대안은 «모든 단계가 팀을 쓴다 · 작은 일도 지휘자»(seed 확인)로 닫힌 «다중 agent 를 덜 쓰기»를 내지 않는다. 레포의 P14 · P5 는 S6 에 따라 제약으로 쓰지 않았다. «파일 원칙이 이미 있는데도 문제가 남는다»는 지형 사실로만 썼다. 같은 입력으로 다시 불린 것은 아니다(state 에 앞선 steelman 산출물이 없다)."
> recommendation: refined
> refined_takes: "파일 규약 자체는 취한다. 결과 파일로만 하는 보고(지워지지 않는 자리를 함께 정하는 조건), INTENT.md(목표 · 지시 원문 · 하지 않을 것 · 결정 기록), STATUS.md, 두 번 나온 지적의 HANDBOOK 승격, «메시지는 짧게 · 자세한 것은 경로로». 리프레시(goal 항목)의 전제 조건이고, 보고가 지휘자 맥락에 쌓이는 지금의 RC3 경로를 끊는다."
> refined_drops: "버리는 것은 넷이다. (a) «파일 없음이 단일 뿌리»라는 틀과 «파일 규약을 먼저 세우면 토큰이 준다»는 기대. 읽기 설계를 같은 첫 단추로 올린다 — 역할 · 단계별 시작 묶음에 예산 상한을 두고, 지휘 절차서는 걸음별로 쪼개 그 걸음에서만 읽고, 쓰지 않는 절(「손으로 따르는 절차」)은 읽지 않는다. (b) 받음 확인 · 되읽기를 전달의 보증으로 쓰는 것. 산출물 · 행동 대조로 바꾼다 — S7 「일꾼 파일은 대조해 믿기」와 같은 방향이다. (c) «일꾼 시작 때 팀 파일 전부 읽기»라는 암묵적 기본값. (d) 결정 기록을 과제 시작 때 한 번 쓰는 칸으로 두는 것. 결정한 행동 직후 그 행동자가 쓰게 하고, 커밋 · 단계 경계에서 확인한다."
> evidence:
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: alternative
>     claim: "agent 는 채팅보다 약 4배, 다중 agent 는 약 15배 토큰을 쓰고, 토큰 사용량 하나가 성능 분산의 80%를 설명한다. 토큰은 구조(agent 수 · 각자가 읽는 양)에서 크게 나온다."
>     touches: [P1]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: current
>     claim: "「Subagent output to a filesystem to minimize the 'game of telephone'」 — 하위는 결과를 외부 저장소에 두고 가벼운 참조만 조정자에게 넘긴다. 결과 파일 보고와 «자세한 것은 경로로»를 지지한다."
>     touches: [P3, P5]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: current
>     claim: "자세한 과제 설명이 없으면 agent 들이 일을 겹치거나 빈틈을 남기거나 필요한 정보를 못 찾는다. 과제마다 목표 · 지시 원문 · 하지 않을 것을 적는 INTENT.md 를 지지한다."
>     touches: [P2, P3]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/multi-agent-research-system"
>     supports: current
>     claim: "맥락이 200,000 토큰을 넘으면 잘리므로 리드 agent 는 계획을 Memory 에 저장해 두고, 한도에 닿으면 저장된 계획을 다시 꺼낸다. 맥락 비우기 전에 파일로 남기기를 지지한다."
>     touches: [P5]
>     decides: [OQ8]
>   - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
>     supports: alternative
>     claim: "좋은 맥락 설계는 «the smallest possible set of high-signal tokens»를 찾는 일이다. 모든 데이터를 미리 싣지 않고, 파일 경로 같은 참조만 쥐고 필요할 때 읽는 just-in-time 방식을 권한다. 읽기 설계가 핵심 축이라는 근거다."
>     touches: [P3]
>     decides: [OQ7]
>   - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
>     supports: current
>     claim: "구조화된 노트(NOTES.md)를 맥락 밖에 두어 «critical context and dependencies that would otherwise be lost across dozens of tool calls»를 지킨다. 맥락을 파일로 남기는 규약을 지지한다."
>     touches: [P2, P3]
>     decides: []
>   - url: "https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents"
>     supports: both
>     claim: "하위 agent 는 깨끗한 맥락에서 탐색하고 «often 1,000-2,000 tokens»의 압축 요약을 돌려준다. 보고를 짧게 하라는 쪽(P5)과, 짧은 요약이 넘어가는 길이 메시지라는 점을 함께 보인다."
>     touches: [P5]
>     decides: []
>   - url: "https://cognition.com/blog/dont-build-multi-agents"
>     supports: alternative
>     claim: "원칙 2 «Actions carry implicit decisions, and conflicting decisions carry bad results». 하위 둘의 행동은 «conflicting assumptions not prescribed upfront»에서 나왔다. 공유 누락은 쓰이지 않은 결정에서 생긴다."
>     touches: [P2]
>     decides: []
>   - url: "https://cognition.com/blog/dont-build-multi-agents"
>     supports: both
>     claim: "과제 원문을 복사해 넘기는 것은 충분하지 않다. 긴 과제에는 행동 · 대화 이력을 «key details, events, and decisions»로 압축하는 별도 모델을 제안하지만 «hard to get right»이고 결국 한계에 닿는다. 결정 기록 칸(current)을 지지하는 동시에, 그 칸을 언제 누가 채우는지가 어렵다는 점(alternative)을 보인다."
>     touches: [P2, P3]
>     decides: [OQ8]
>   - url: "https://arxiv.org/html/2503.13657v2"
>     supports: alternative
>     claim: "MAST 의 inter-agent misalignment 범주에는 FM-2.4 정보 보유자가 나누지 않음, FM-2.5 다른 agent 의 입력을 무시하거나 가볍게 봄, FM-2.6 말한 추론과 실제 행동의 불일치가 있다. FM-2.5 · 2.6 은 받는 쪽이 읽었어도 생긴다."
>     touches: [P2, P4]
>     decides: []
>   - url: "https://arxiv.org/html/2503.13657v2"
>     supports: both
>     claim: "5.2절 개입 사례 — 프롬프트 개선 · 구조 변경 같은 전술적 수정 뒤에도 «not all failure modes are eradicated»였다. «Achieving high reliability likely requires more fundamental changes to agent organization, communication protocols»라고 결론낸다. 통신 계약은 필요하지만 약속 하나로는 부족하다."
>     touches: [P4]
>     decides: []
>   - url: "https://www.trychroma.com/research/context-rot"
>     supports: alternative
>     claim: "«model performance consistently degrades with increasing input length». 관련 없는 단락 하나만 끼어도(«Even a single distractor») 성능이 떨어진다. 일꾼이 시작할 때 읽는 묶음의 크기와 관련성이 품질을 정한다."
>     touches: [P3]
>     decides: [OQ7, OQ8]
>   - url: "https://code.claude.com/docs/en/memory"
>     supports: alternative
>     claim: "CLAUDE.md 와 자동 메모리는 «context, not enforced configuration»이다. CLAUDE.md 는 200줄 아래가 목표이고 더 길면 «consume more context and reduce adherence»다. @import 는 맥락 비용을 줄이지 않는다. 경로 지정 규칙(paths:)과 하위 폴더 CLAUDE.md 는 맞는 파일을 다룰 때만 on demand 로 실린다. 역할 문서를 일꾼에게 닿게 하는 길과 읽는 양의 상한을 함께 정한다."
>     touches: [P3, P4]
>     decides: [OQ7]
>   - url: "https://manus.im/blog/Context-Engineering-for-AI-Agents-Lessons-from-Building-Manus"
>     supports: both
>     claim: "KV-cache 적중률이 «the single most important metric»이고 입력 대 출력은 약 100:1 이다(비용은 읽기 쪽에서 나온다 — alternative). 동시에 파일시스템을 «restorable» 압축의 외부 기억으로 쓰고, todo.md 를 다시 써서 목표를 맥락 끝에 붙잡아 둔다(current)."
>     touches: [P1, P3]
>     decides: [OQ8]
>   - url: "https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents"
>     supports: current
>     claim: "«each session begins with no memory of what came before» 를 전제로, 초기화 agent 가 progress 파일 · feature list(JSON) · init.sh 를 만든다. 새 세션은 git log · progress 파일 · feature list 를 읽고 한 세션에 기능 하나만 한다. 파일 규약이 세션 리프레시를 가능하게 하고, 과제 단위를 세션 경계로 쓰는 선례다."
>     touches: [P2, P3]
>     decides: [OQ8]
>   - url: "https://code.claude.com/docs/en/cross-session-messaging"
>     supports: both
>     claim: "세션끼리 보내는 메시지는 «plain text only»이고 «never the sender's conversation history or files»다. @ 로 파일을 적어도 아무것도 붙지 않는다. 다른 기계로는 Remote Control 연결을 거쳐 Anthropic 서버로 가고, offline 이면 다시 연결된 뒤에 닿는다. 받는 쪽에는 보낸 세션 이름이 붙고, 그 메시지로 승인 · 설정 변경을 할 수 없다. 메시지가 파일을 나르지 못하므로 자세한 것은 받는 기계에서 열 수 있는 자리(예: git 원격)에 있어야 한다."
>     touches: [P5]
>     decides: [OQ4]
> repo_claims:
>   - id: RC1
>     path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
>     anchor: "### 5. 지휘 순환 — 「Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md」 · 「`conducting.md` 의 손으로 따르는 절차는 지휘자를 부르지 않고 진행할 때의 것이다 — 이 skill 안에서는 따르지 않는다」"
>     line: 163
>     claim: "지휘자는 부를 때마다 conducting.md 전체(75,138 바이트 — R1 확인 값)와 conductor-dispatch.md 를 Read 한다. 그 안의 「## 손으로 따르는 절차」(conducting.md 90행~)는 같은 SKILL 169행이 이 skill 안에서는 따르지 않는다고 밝힌 절인데도 매번 읽힌다. 반복 고정비는 파일이 없어서가 아니라 읽기가 설계되지 않아서 생긴다."
>     touches: [P1, P3]
>     decides: []
>   - id: RC2
>     path: "docs/philosophy/devbrew-harness-philosophy.md"
>     anchor: "### P5 — Filesystem as Memory — 「최소 인덱스만 preload하고 나머지는 Glob/Read/Grep으로 just-in-time 로드한다」 · ### P14 — 「턴 종료 전 load-bearing 사실은 파일로 기록한다」"
>     line: 94
>     claim: "레포는 이미 «사실은 파일로»(P14, 91행)와 «just-in-time 로드»(P5, 94행)를 정본으로 둔다. 그런데도 RC1 처럼 절차서를 통째로 읽고 seed 의 공유 누락이 남아 있다. «파일 원칙의 부재»가 아니라 읽기 · 쓰기 실행의 틈이 문제라는 지형 사실이다. S6 에 따라 제약으로 쓰지 않고 지형으로만 쓴다."
>     touches: [P1, P2]
>     decides: []
>   - id: RC3
>     path: "plugins/spec-distill/references/conductor-dispatch.md"
>     anchor: "## 마지막 보고 — 「하위의 마지막 메시지는 아래를 모두 싣는다 — 실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다」"
>     line: 43
>     claim: "지금 하위는 판정 전체와 AC 보고 전체를 마지막 메시지에 싣는다. 보고는 파일이 아니라 지휘자 대화에 쌓인다(current 를 지지). 같은 줄이 그 이유로 «작업 폴더가 지워질 수 있다»를 든다. 결과 파일 보고(P5)는 지워지지 않는 자리를 함께 정해야 성립한다."
>     touches: [P1, P5]
>     decides: []
>   - id: RC4
>     path: "plugins/spec-distill/references/conductor-dispatch.md"
>     anchor: "## 단계마다 새 agent — 「한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다」"
>     line: 37
>     claim: "대화 누적은 레포가 실제로 겪은 비용원이다. 그래서 지금도 단계 경계마다 새 agent 를 보내 맥락을 끊는다. P1 의 «대화에 쌓임»이 원인 하나라는 것은 지지하고, 단계 경계가 이미 리프레시 단위로 쓰이고 있음을 보인다."
>     touches: [P1]
>     decides: [OQ8]
>   - id: RC5
>     path: "plugins/spec-distill/references/conductor-dispatch.md"
>     anchor: "## 사람 자리 — 「옮길 때마다 받은 원문 · 실제로 띄운 질문 · 사용자 답 · 돌려보낸 글을 … 폴더의 파일(`relay-<번호>.md`)에 남기고, 에픽이 끝나면 쓰기 권한 없는 agent 가 … 대조한다」"
>     line: 32
>     claim: "옮긴 질문의 경로에는 이미 «파일로 남기기 + 쓰기 권한 없는 agent 의 대조»가 있다. 적어도 이 경로에서 공유 누락의 원인은 «파일에 안 남음»이 아니다. 받음 확인 · 되읽기보다 산출물 대조가 레포가 이미 쓰는 전달 검증 방식이다."
>     touches: [P2, P4]
>     decides: []
>   - id: RC6
>     path: "plugins/spec-distill/references/conducting.md"
>     anchor: "### /compact 시점 — 「승인 뒤 계획 agent 를 보낸 직후처럼 끊기 좋은 자리에서 맥락이 무거우면, 기록(설계문서 절)을 커밋하고 기계 상태를 저장한 뒤 … 압축은 사용자만 한다」"
>     line: 85
>     claim: "지금 지휘 세션의 리프레시 문턱은 «끊기 좋은 자리(과제 경계) ∧ 맥락이 무거움»의 조합이다. 실행은 먼저 파일에 기록한 뒤 사용자가 한다. 리프레시 문턱 결정의 출발점이고, 리프레시 전에 파일로 남긴다는 순서(current)를 이미 담고 있다."
>     touches: [P5]
>     decides: [OQ8]
> ```
>
> 참고 경로(모두 절대경로):
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/skills/epic-conductor/SKILL.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conducting.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/plugins/spec-distill/references/conductor-dispatch.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/philosophy/devbrew-harness-philosophy.md
> - /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/conductor-context-economy/docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.md
>
> 확인하지 못한 것:
> - conducting.md 의 75,138 바이트와 약 3.5만 토큰은 R1 의 확인 값을 그대로 썼다. 이번 호출에서 다시 재지 않았다.
> - trigger 가 «단순한 통신 프로토콜로는 부족»이라고 옮긴 MAST 의 결론은 초록에는 그 문장이 없다. 본문 5.2절 · 서론의 문장으로 확인해 그 문장을 인용했다.
> - Anthropic 의 15배 수치는 이번에 원문 페이지를 직접 열어 확인했다.

**게이트-전 확인** — repo_claims: RC37 · RC38 · RC39 · RC40 · RC41 · RC42 확인 6/6 · 부착 주장: 근거 16 전부 → P1 · P2 · P3 · P4 · P5 확인 · 재검토 자격: 열림 3건(P1 · P2 · P4)

**사용자 선택** — 보완 (S8)

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-11-14) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-11-14)

## 5. 프로세스 로그

- round 1: path (a · d) — 뿌리 문제 · 작업 목록 — coverage-mapper 첫 dispatch, seed 다시 검증 셋 해소
- round 2: path (b) — 일꾼 실행 · 지휘자 간 운반 · 현황 표면 · premortem 처분
- round 3: path (b) — steelman ST1 게이트(보완)
- round 4: path (b) — 지휘자 간 길 · 역할 문서 전달 · 리프레시 단위
- round 5: path (a · b) — Task 정체 바로잡기 · 진행 agent · 지휘 세션 · 스크립트 범위
- round 6: path (b) — 갈아타기 · INTENT.md · STATUS.md · 절차서
- round 7: path (a · b) — 프레이밍 대비 바뀐 것 · INTENT 영향 · 과제 = 에픽
- round 8: path (b) — 역할 폴더 · 규칙 목차 이름, 원칙 저장
- round 9: path (b) — 팀 규칙 · 경계 장치 · 대화 수단 · 작업 방식
- round 10: path (b) — 열린 질문 목록 확정 → 포화 판정 1
- round 11: path (a · b) — 형식 결합 · git 자리(S17 재개방), 세션 기록 백업
- round 12: path (a · b) — 코드 취합 · 소통 자리 → 포화 판정 2
- round 13: path (b) — 규칙 목차 운영 · 순서 강제 · mod 감시 → 포화 판정 3
- round 14: path (a · b) — 검수 상한 · 조사 범위
- round 15: path (b) — 조건 규칙 전달(S36 일부 재개방) → 포화 판정 4
- round 16: path (b) — 마무리(사용자 종료)
- 조사 호출 표시 바로잡기 — R12–R16 의 사용자 화면에서 조사 호출을 18 로 셌으나 실제 dispatch 는 17 이다(본체 직접 3 은 상한 밖)
- 판정자 입력 추출 결함 — 포화 판정 2 에서 조사 12 블록이 블록 안 ### 소제목에서 잘려 넘어갔다. 원문은 state 에 온전했고 추출기를 고쳐 판정 3 부터 온전히 넘겼다
- 판정자 입력 전달 방식 — 조사 원문이 커서(약 155KB+) 포화 판정자에게 결정 목록 · 조사 원문 · 원장을 git 무시 작업 폴더(.claude/tmp/interview-sat/)의 파일 경로로 넘겼다(인라인 규칙에서 벗어남)

- 확인 RC1 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — 주장과 일치(43행 「경로만으로는 부족하다」)
- 확인 RC2 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P8 — 주장과 일치(84행 「순서를 강제하는 결정론은 두지 않는다」)
- 확인 RC3 — 확인 — plugins/spec-distill/references/conducting.md#/compact 시점 — 주장과 일치(85행 「압축은 사용자만 한다」)
- 확인 RC4 — 미확인 — plugins/spec-distill/references/conducting.md#파일 전체 — 매 호출 Read(epic-conductor SKILL 163–164행)와 75,138 바이트 · 116줄은 확인, 35,641 토큰 수치는 본체가 재지 못함
- 확인 RC5 — 확인 — plugins/spec-distill/references/conducting.md#5. 머지 전 확인 — 주장과 일치(59행 「답은 기계 상태에 적지 않는다」)
- 확인 RC6 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#1.5 의존 확인 — 주장과 일치(64행 superpowers 없으면 멈춤)
- 확인 RC7 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 주장과 일치(16행 원천 셋 · 표는 사본)
- 확인 RC8 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#스위트 잠금 — 주장과 일치(15행 suite-lock 경로는 로컬 파일)
- 확인 RC9 — 확인 — CLAUDE.md#런타임 상태 & 훅 — 주장과 일치(70행 git-ignored 런타임 · docs 추적 진행 기록)
- 확인 RC10 — 확인 — plugins/project-init/hooks/hooks.json#PostToolUse — 레포의 hooks.json 은 이것 하나이고 SessionStart 없음
- 확인 RC11 — 확인 — CLAUDE.md#Law 1 Trivia escape · Trivia ceremony — 주장과 일치
- 확인 RC12 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent — 주장과 일치(37행 「백만 토큰 가까이」)
- 확인 RC13 — 확인 — docs/superpowers/specs/2026-10-28-askquestion-recommendation-design.md#238행 — 주장과 일치(Skill 도구 거부), plans 1538행 rc 0 조용한 실패도 확인
- 확인 RC14 — 확인 — plugins/spec-distill/references/conducting.md#병렬 권장 수 — 주장과 일치(19행 기본값 · 상한 아님)
- 확인 RC15 — 확인 — plugins/spec-distill/references/conducting.md#5. 머지 전 확인 — RC5 와 같은 자리(59행)
- 확인 RC16 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — RC1 과 같은 자리(43행)
- 확인 RC17 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent — RC12 와 같은 자리(37행)
- 확인 RC18 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#38행 — SendMessage 로 같은 agent 를 이어 부름
- 확인 RC19 — 확인 — plugins/spec-distill/references/conducting.md#/compact 시점 — RC3 과 같은 자리(85행)
- 확인 RC20 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P14 — State Survives Compaction(90행) 실재
- 확인 RC21 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P8 — RC2 와 같은 자리(84행)
- 확인 RC22 — 확인 — docs/superpowers/interview/2026-11-13-conductor-context-economy-interview.audit.md#132행 — 98.5% · 99.0% 원문 일치
- 확인 RC23 — 확인 — CLAUDE.md#Trivia ceremony — 주장과 일치
- 확인 RC24 — 확인 — CLAUDE.md#모든 훅에 kill switch — 주장과 일치
- 확인 RC25 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#1. 자리 — 7행 기본 isolation worktree
- 확인 RC26 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent · SendMessage — 37–38행
- 확인 RC27 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — 43행
- 확인 RC28 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#5. 임시 폴더 — 11행 「도구는 거절, 셸은 됨」
- 확인 RC29 — 확인 — plugins/spec-distill/references/conducting.md#4. 돌아오기 — 49행 완료 알림
- 확인 RC30 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 17행 완료 표시 실측
- 확인 RC31 — 확인 — plugins/spec-distill/references/conducting.md#43행 — 하위 agent 자리 실측
- 확인 RC32 — 확인 — plugins/spec-distill/dependencies.md#claude-code — 19행 2.1.303 기록
- 확인 RC33 — 확인 — plugins/spec-distill/README.md#상태줄 — 175행 원문 일치
- 확인 RC34 — 확인 — plugins/spec-distill/scripts/control_plane.py#stdin_dir · cmd_statusline — 1144 · 1193행, context_window · cost · transcript_path 를 읽지 않음(grep 0건), kill switch 는 1140행
- 확인 RC35 — 확인 — plugins/spec-distill/dependencies.md#claude-code — RC32 와 같은 자리
- 확인 RC36 — 확인 — plugins · shared#토큰 필드 — cache_read_input_tokens · context_window · AUTOCOMPACT · OTEL_ grep 0건
- 확인 RC37 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#5. 지휘 순환 — 163–164행 Read 두 줄 · 169행 「이 skill 안에서는 따르지 않는다」, conducting.md 90행~ 29,992 바이트
- 확인 RC38 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#P5 · P14 — 94행 just-in-time · 90행 P14
- 확인 RC39 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 보고 — 43행
- 확인 RC40 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#단계마다 새 agent — 37행
- 확인 RC41 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#사람 자리 — 32행 relay-<번호>.md 와 쓰기 권한 없는 agent 대조
- 확인 RC42 — 확인 — plugins/spec-distill/references/conducting.md#/compact 시점 — 85행
- 확인 RC43 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 13행 git fetch · pr-refresh
- 확인 RC44 — 확인 — plugins/spec-distill/scripts/conductor_state.py#MARKER · acquire — 5행 「이 기계에서만 뜻이 있는 것」, 32행 conducting-by, 334행 O_EXCL
- 확인 RC45 — 확인 — plugins/spec-distill/references/conducting.md#1. 맞추기 — 16행 SendMessage 는 자기 하위 agent 에만
- 확인 RC46 — 확인 — plugins/spec-distill/references/conducting.md#2. 사람 몫 모으기 — 28행 relay 폴더(로컬 자원)
- 확인 RC47 — 확인 — plugins/spec-distill/references/conducting.md#3. 다음 일 고르기와 보내기 — 34행 「다른 세션을 열라는 줄을 주지 않는다」
- 확인 RC48 — 확인 — plugins/spec-distill/dependencies.md#claude-code — 19행 2.1.303 · 강도 기록
- 확인 RC49 — 미확인 — plugins/spec-distill/references/roadmap-ontology.md:3 — 앵커 «주인만 쓰고» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC50 — 미확인 — plugins/spec-distill/tests/test_roadmap_ontology.py:30 — 앵커 «리뷰 원장» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC51 — 확인 — plugins/spec-distill/scripts/conductor_state.py:51 — 앵커 «RETIRED_SECTIONS» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC52 — 미확인 — plugins/spec-distill/scripts/state_path.py:73 — 앵커 «def state_root_for_common» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC53 — 확인 — plugins/spec-distill/scripts/conductor_state.py:334 — 앵커 «O_EXCL» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC54 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:104 — 앵커 «def need_holder» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC55 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:901 — 앵커 «def c_live_agent» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC56 — 확인 — plugins/spec-distill/references/conducting.md:16 — 앵커 «사본이다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC57 — 미확인 — plugins/spec-distill/references/conducting.md:21 — 앵커 «로드맵 밖 일도 한 곳에» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC58 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:867 — 앵커 «def c_flush» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC59 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py:589 — 앵커 «read_pr_cache» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC60 — 미확인 — plugins/spec-distill/tests/test_conductor_state.py:43 — 앵커 «progress.md» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC61 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:168 — 앵커 «FILE_KINDS» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC62 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:32 — 앵커 «relay-<번호>.md» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC63 — 미확인 — plugins/spec-distill/agents/relay-checker.md:14 — 앵커 «tools: Read, Grep, Glob» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC64 — 미확인 — plugins/spec-distill/references/conducting.md:51 — 앵커 «--kind report» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC65 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:11 — 앵커 «--kind tmp» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC66 — 미확인 — plugins/spec-distill/scripts/suite_lock.py:37 — 앵커 «BUSY_RC = 75» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC67 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py:23 — 앵커 «SDD_WORKSPACE» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC68 — 확인 — plugins/spec-distill/references/conducting.md:17 — 앵커 «완료 표시는 일이 끝났다는 뜻이 아니다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC69 — 미확인 — plugins/spec-distill/scripts/roadmap_model.py:657 — 앵커 «RECORD_HEADING» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC70 — 미확인 — plugins/spec-distill/references/conducting.md:53 — 앵커 «허가 없이 바뀜» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC71 — 확인 — plugins/spec-distill/references/conducting.md:3 — 앵커 «## 지휘 순환» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC72 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py:1193 — 앵커 «def c_review_pack» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC73 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:13 — 앵커 «Spec: <설계문서» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC74 — 미확인 — plugins/spec-distill/scripts/review_intents.py:2 — 앵커 «intents.md» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC75 — 미확인 — plugins/spec-distill/scripts/merge_check.py:15 — 앵커 «하위 agent 도 쓸 수 있다» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC76 — 미확인 — plugins/spec-distill/scripts/control_plane.py:765 — 앵커 «def cache_file» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC77 — 미확인 — plugins/spec-distill/README.md:179 — 앵커 «control-plane-statusline:begin» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC78 — 미확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md:151 — 앵커 «재분해 이력» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC79 — 미확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R5.md:2 — 앵커 «type: epic-bundle» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC80 — 미확인 — plugins/spec-distill/references/epic-handoff.md:1 — 앵커 «에픽 넘김 줄» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC81 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py:35 — 앵커 «SETTINGS_FILE» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC82 — 미확인 — plugins/spec-distill/skills/pm-interview/SKILL.md:126 — 앵커 «## State location» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC83 — 미확인 — plugins/spec-distill/skills/pm-interview/references/state-file.md:79 — 앵커 «상태 파일은 지우지 않는다» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC84 — 미확인 — shared/docreview/scripts/docreview_state.py:6 — 앵커 «docreview-state.md» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC85 — 미확인 — plugins/spec-distill/scripts/ledger_marker.py:2 — 앵커 «reviewing-by» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC86 — 미확인 — plugins/spec-distill/scripts/ledger_sweep.py:15 — 앵커 «DEVBREW_SPEC_DISTILL_TTL_HOURS» 실재는 확인, 주장 내용의 구현 대조는 하지 않음
- 확인 RC87 — 확인 — plugins/spec-distill/references/conducting.md:85 — 앵커 «압축은 사용자만 한다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC88 — 확인 — plugins/spec-distill/references/conductor-dispatch.md:73 — 앵커 «CHECKPOINT» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC89 — 확인 — plugins/spec-distill/references/conducting.md:88 — 앵커 «PushNotification» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC90 — 확인 — plugins/spec-distill/references/conducting.md:28 — 앵커 «relay-<순번>.md» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC91 — 확인 — CLAUDE.md:70 — 앵커 «수명은 넷이다» 실재, 앞 라운드에서 같은 자리를 읽어 주장과 일치
- 확인 RC92 — 확인 — plugins/spec-distill/dependencies.md#python · claude-code — 14행 python 3.9.6, 19행 2.1.303, Bun · Node · Go 행 없음
- 확인 RC93 — 확인 — plugins/#monitors · asyncRewake · CLAUDE_CODE_MESSAGING · mcpServers — grep 0건
- 확인 RC94 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#S9 — 원문 일치
- 확인 RC95 — 확인 — plugins/spec-distill/dependencies.md#superpowers — 17행 7.0.0 · 알림
- 확인 RC96 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#1.5 의존 확인 — 64행
- 확인 RC97 — 확인 — plugins/spec-distill/references/conducting.md#걸음 3 부를 skill — 44행 superpowers:brainstorming
- 확인 RC98 — 미확인 — plugins/spec-distill/references/conducting.md#50행 Ruling — 앵커 실재는 R1 에서 봄, BLOCKED 멈춤 조건 대조는 하지 않음
- 확인 RC99 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#SPECS_DIR · PLANS_DIR — 21–22 · 41행
- 확인 RC100 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#dirty_lines — 154행
- 확인 RC101 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#plan_specs — 321–322행 **Spec:** 줄로 계획 · 설계 연결
- 확인 RC102 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#find_specs — 앵커 실재만
- 확인 RC103 — 확인 — plugins/spec-distill/skills/spec-review/SKILL.md#--bundle — 157행
- 확인 RC104 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py#def _folder — 70행 앵커 «def _folder» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC105 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py#SDD_WORKSPACE — 23행 앵커 «SDD_WORKSPACE» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC106 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#def spec_line_path — 307행 앵커 «def spec_line_path» 실재, 주장 내용의 구현 대조는 하지 않음 — 321–322행 plan_specs 를 R8 에서 읽어 「**Spec:** 줄만 센다」 일치
- 확인 RC107 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def branch_plans — 341행 앵커 «def branch_plans» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC108 — 미확인 — plugins/spec-distill/references/conducting.md#계획 없음 — 14행 앵커 «계획 없음» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC109 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def trailer_after — 222행 앵커 «def trailer_after» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC110 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def find_specs — 325행 앵커 «def find_specs» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC111 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def started — 726행 앵커 «def started» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC112 — 미확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#def specs_for — 115행 앵커 «def specs_for» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC113 — 미확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#startswith("### Task") — 500행 앵커 «startswith("### Task")» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC114 — 미확인 — plugins/spec-distill/scripts/check_bundle_coverage.py#보고에 AC 판정 줄이 없다 — 587행 앵커 «보고에 AC 판정 줄이 없다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC115 — 미확인 — plugins/spec-distill/scripts/conductor_state.py#def ledger_rulings — 388행 앵커 «def ledger_rulings» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC116 — 미확인 — plugins/spec-distill/scripts/control_plane.py#def _rulings — 997행 앵커 «def _rulings» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC117 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#보고에도 원장에도 판정이 없다 — 842행 앵커 «보고에도 원장에도 판정이 없다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC118 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#def c_progress — 1349행 앵커 «def c_progress» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC119 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#def dirty_lines — 154행 앵커 «def dirty_lines» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC120 — 미확인 — plugins/spec-distill/references/conducting.md#BLOCKED — 50행 앵커 «BLOCKED» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC121 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md#CHECKPOINT — 73행 앵커 «CHECKPOINT» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC122 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md#finishing-a-development-branch — 24행 앵커 «finishing-a-development-branch» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC123 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#superpowers 가 필요하다 — 64행 앵커 «superpowers 가 필요하다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC124 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#code-reviewer.md — 173행 앵커 «code-reviewer.md» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC125 — 미확인 — plugins/spec-distill/skills/spec-review/SKILL.md#*-design.md — 193행 앵커 «*-design.md» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC126 — 미확인 — plugins/spec-distill/scripts/spec_review_bundle.py#source_interview 가 없다 — 75행 앵커 «source_interview 가 없다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC127 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#def approval_of — 352행 앵커 «def approval_of» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC128 — 미확인 — plugins/spec-distill/references/roadmap-ontology.md#**Spec:** — 23행 앵커 «**Spec:**» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC129 — 미확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#superpowers 가용성 — 281행 앵커 «superpowers 가용성» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC130 — 미확인 — plugins/quality-gates/scripts/discover-spec.sh#Spec: — 4행 앵커 «Spec:» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC131 — 미확인 — plugins/plugin-audit/scripts/check-integrity.sh#.superpowers/* — 109행 앵커 «.superpowers/*» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC132 — 미확인 — plugins/spec-distill/tests/test_repo_literals.sh#docs/superpowers — 38행 앵커 «docs/superpowers» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC133 — 미확인 — plugins/spec-distill/tests/test_control_plane.sh#SDD ledger — 533행 앵커 «SDD ledger» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC134 — 미확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 19행 앵커 «| claude-code | 2.1.303» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC135 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#crossSessionInbound: accept — 1348행 앵커 «crossSessionInbound: accept» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC136 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#idle 세션의 새 턴을 여는지는 문서로 확인하지 못했다 — 1494행 앵커 «idle 세션의 새 턴을 여는지는 문서로 확인하지 못했다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC137 — 미확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#disable-model-invocation: true — 10행 앵커 «disable-model-invocation: true» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC138 — 미확인 — CLAUDE.md#GitHub Flow — 12행 앵커 «GitHub Flow» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC139 — 미확인 — docs/git-workflow/branch-strategy.md#main`에 직접 commit — 75행 앵커 «main`에 직접 commit» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC140 — 미확인 — docs/git-workflow/pr-process.md#force push — 68행 앵커 «force push» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC141 — 미확인 — CLAUDE.md#산출물과 함께 커밋한다 — 70행 앵커 «산출물과 함께 커밋한다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC142 — 미확인 — plugins/spec-distill/scripts/state_path.py#def state_root_for_common — 73행 앵커 «def state_root_for_common» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC143 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#네트워크에 나가지 않는다 — 16행 앵커 «네트워크에 나가지 않는다» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC144 — 미확인 — plugins/spec-distill/dependencies.md#| gh | — 16행 앵커 «| gh |» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC145 — 미확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 19행 앵커 «| claude-code | 2.1.303» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC146 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#input_tokens 에 스트리밍 placeholder(1)가 남고 — 351행 앵커 «input_tokens 에 스트리밍 placeholder(1)가 남고» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC147 — 미확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#ccusage 가 {session}/subagents/{agent}.jsonl 을 무시해 — 429행 앵커 «ccusage 가 {session}/subagents/{agent}.jsonl 을 무시해» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC148 — 미확인 — docs/superpowers/plans/2026-09-27-qg-public-contract-pr5.md#total_cost_usd — 855행 앵커 «total_cost_usd» 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC149 — 확인 — ~/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/skills/subagent-driven-development/references/fix-loop.md#64 · 70행 — SDD 원장은 `Task <N>: Ruling: …` 줄을 쓰고 implementer-prompt.md 142행이 Status DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT 를 정함 — devbrew 의 Ruling: · BLOCKED 읽기가 기대는 형식이 실재 [→ OQ33]
- 확인 RC150 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#plan_specs — 실행: «## Program checklist» 계획 → set(), «**Spec:** `docs/x-design.md`» 계획 → {docs/x-design.md}. **Spec:** 없는 계획은 조용히 빈 집합(조사 11 RC106 · RC107 의 입력 경로를 실행으로 확인) [RC150 → OQ33]
- 확인 RC151 — 확인 — 설치 판 · 기록 — claude --version 2.1.323, 가장 오래 남은 devbrew 세션 기록 2026-10-15, 백업 2,579개(R11) [RC151 → OQ27]
- 확인 RC152 — 미확인 — plugins/project-init/hooks/hooks.json#Bash|EnterWorktree — 6행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC153 — 미확인 — plugins/project-init/hooks/post-tool-use.py#non-blocking — 17행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC154 — 미확인 — plugins/project-init/hooks/post-tool-use.py#branch: Created from  — 55행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC155 — 미확인 — plugins/project-init/hooks/post-tool-use.py#PROTECTED_BRANCHES — 86행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC156 — 미확인 — plugins/project-init/hooks/post-tool-use.py#def _judge — 497행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC157 — 미확인 — docs/git-workflow/branch-strategy.md#^(feature|fix|docs|chore)/ — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC158 — 미확인 — docs/git-workflow/branch-strategy.md#직접 commit — 75행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC159 — 미확인 — docs/git-workflow/pr-process.md#Rebase — 47행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC160 — 미확인 — plugins/spec-distill/scripts/state_path.py#def state_root_for_common — 73행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC161 — 미확인 — plugins/spec-distill/scripts/state_path.py#def _write_ignore — 120행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC162 — 미확인 — plugins/spec-distill/references/conducting.md#하위 agent 의 자리 — 7행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC163 — 미확인 — plugins/spec-distill/references/conducting.md#cp — 43행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC164 — 미확인 — plugins/quality-gates/scripts/seal-worktree.sh#commit-tree — 62행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC165 — 미확인 — plugins/quality-gates/scripts/combine-tips.sh#commit-tree — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC166 — 미확인 — plugins/plugin-audit/scripts/audit-sandbox.sh#hash-object — 114행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC167 — 미확인 — plugins/spec-distill/scripts/roadmap_status.py#GIT_ALLOWED — 16행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC168 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md### Flow — 197행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC169 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#security-reviewer — 65행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC170 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#Max-iter decision — 223행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC171 — 미확인 — plugins/quality-gates/scripts/artifact_max_rounds.sh#max_rounds — 2행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC172 — 미확인 — plugins/quality-gates/scripts/artifact_stagnation.py#stagnant — 4행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC173 — 미확인 — shared/docreview/scripts/docreview_config.py#rereview_cap — 13행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC174 — 미확인 — plugins/spec-distill/references/conducting.md#두 번까지 — 61행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC175 — 미확인 — plugins/spec-distill/references/conducting.md#대안 갈래로 일찍 옮긴다 — 50행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC176 — 미확인 — plugins/spec-distill/scripts/merge_check.py#종료 코드 — 15행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC177 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md### 마지막 보고 — 14행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC178 — 미확인 — plugins/spec-distill/references/conductor-dispatch.md#마지막 전체 리뷰 — 72행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC179 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#spec-distill:integration-reviewer — 178행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC180 — 미확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#spec-distill:relay-checker — 197행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC181 — 미확인 — plugins/spec-distill/references/conducting.md#quality-pipeline — 78행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC182 — 미확인 — .claude-plugin/marketplace.json#./plugins/quality-gates — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC183 — 미확인 — shared/tests/test_changelog_integrity.sh#CHANGELOG — 2행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC184 — 미확인 — plugins/spec-distill/CHANGELOG.md#CLAUDE_CONFIG_DIR — 3769행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC185 — 미확인 — plugins/quality-gates/scripts/artifact_branch_guard.sh#branch_ok: false — 12행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC186 — 미확인 — plugins/spec-distill/dependencies.md#| claude-code | 2.1.303 — 19행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC187 — 미확인 — CLAUDE.md#모든 훅에 kill switch — 71행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC188 — 미확인 — CLAUDE.md#훅 공존 — 72행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC189 — 미확인 — docs/philosophy/devbrew-harness-philosophy.md#### P8 — 78행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC190 — 미확인 — plugins/spec-distill/scripts/repo_defaults.py#PARALLEL_DEFAULT = 3 — 27행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC191 — 미확인 — plugins/spec-distill/tests/test_epic_handoff.sh#흐름을 고정하지 않는다 — 60행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC192 — 미확인 — plugins/spec-distill/references/conducting.md### 지휘 순환 — 3행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC193 — 미확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md#기본은 X — 5행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC194 — 미확인 — plugins/spec-distill/tests/test_review_handoff_order.sh#기본은 X — 96행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC195 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#P8 determinism-economy — 327행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC196 — 미확인 — shared/tests/test_charter_citations.sh#헌장 — 3행 앵커 실재, 주장 내용의 구현 대조는 하지 않음
- 확인 RC197 — 확인 — ~/.claude/plugins/cache/claude-plugins-official/superpowers/7.0.2/skills/subagent-driven-development/references/fix-loop.md#20–59행 — 과제마다 고침 라운드 최대 5: 1–3 라운드는 원래 구현 일꾼을 이어 부르고, 4–5 라운드는 한 단계 강한 모델의 새 구현 일꾼, 5 라운드 재리뷰 뒤에도 남으면 차단기(breaker)로 멈춤. 라운드마다 원장에 `Task <N>: fix round <R>/5` [RC197 → OQ31]
- 확인 RC198 — 확인 — /Library/Application Support/ClaudeCode — 없음(이 기계에 macOS managed settings 없음) — 기본 가드 sec-default 는 Team · Enterprise 로그인일 때만 실리고 로그인 종류는 확인 못 함 [RC198 → OQ28]
- 확인 RC199 — 확인 — .claude/#rules — 메인 체크아웃 · 이 worktree 둘 다 .claude/rules 없음(ls)
- 확인 RC200 — 확인 — .gitignore#/.claude/* · !/.claude/agents/ — 214–220행, .claude/ 아래는 agents/ 만 추적
- 확인 RC201 — 확인 — plugins/spec-distill/dependencies.md#claude-code — 19행 2.1.303
- 확인 RC202 — 확인 — plugins/project-init/CHANGELOG.md#2.2.0 — 258행 「.claude/rules/agent-tool-permission.md 를 만들던 경로를 제거한다」
- 확인 RC203 — 확인 — docs/superpowers/interview/2026-11-14-conductor-context-economy-brief-interview.state.md#S36 — 원문 일치

- 대체됨: R4 추천 「Task 하나마다 새 일꾼」이 새로 필요한 장치 → SDD 가 이미 Task 마다 새 일꾼을 쓰고 맥락이 쌓이는 쪽은 Task 들을 돌리는 진행 agent (본체 직접 확인 — superpowers SDD SKILL)
- 대체됨: 「pstack 은 공식이 Cursor 용, Claude Code 용은 커뮤니티 포팅」(Phase 0 이름 조회) → 공식 README 가 Claude Code 설치(/plugin install pstack@cursor-plugins)를 직접 싣는다 (조사 10)
- 대체됨: 「pstack skill 은 plan · execute · research · pr」(Phase 0 이름 조회) → 라우터 poteto-mode + 플레이북 23개, 기본 계획 skill 없음 (조사 10)
- 대체됨: 「세션 기록 input_tokens 에 스트리밍 placeholder(1)가 남는다」(조사 3) → 공식 cost-tracking 문서는 중복 뺀 단계별 input · cache 는 정확하고 placeholder 는 output_tokens 라 함 (조사 14)
- 대체됨: 「ccusage 가 subagents/*.jsonl 을 무시해 과소 계수」(조사 3, 3자 출처) → 1차 ccusage #913 은 subagents/ 를 읽어 과대 계수했고 #1155 로 중복 제거 수정 (조사 14)
- 대체됨: 「bypassPermissions 지휘자의 무인 수신엔 crossSessionInbound: accept 필요」(조사 6) → 값이 없으면 세션 자기 자식 프로세스(훅 · Bash · monitor)가 자기 소켓에 넣은 글은 bypass 에서도 전달, macOS 는 프로세스 생존 또는 토큰 auth 줄 (조사 12)

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 (재리뷰 2/2 — 상한 도달) · 탐지 doc-critic-web 1명 · codex 3/3 성공 · 재비판 3/3 · 리뷰 완료 참(round_reviewed)
- 승인 게이트 도달 사유: 재리뷰 상한 · 마지막 렌더 첫 줄 「리뷰 3라운드를 마쳤다 — 열린 지적 6개 — 아직 안 고친 곳 6개가 남았다. 경고 없음.」
- 결정: 5건 전부 채택(D1.1–D1.4 · D2.5 — §8)
- 1단계 사용자 선택: 열린 fix 6건 전부 「고친다」 · 추가 라운드 「열지 않음」
- 미반영 findings: 없음. 3라운드 fix 6건은 check-intent 통과 뒤 적용했으나 다음 라운드가 없어 엔진의 적용 관측 전이다 — 마지막 수정 재검증 없음
- 2라운드 보류 4건(edit_scope_multi_anchor — 판정 안 됨): 저자가 직접 반영. §5 에 갈 부분(발신 확인 위험)은 이번 라운드 §5 허가가 없어 OQ46 으로 옮겼다
- 리뷰 뒤 사용자 말로 더함(리뷰 받지 않음): §1 Goal 한 줄 · C49 · C50 · OQ47 (S48 · S49 · S50)
- 냉독: 돌지 못함 — 첫 dispatch 에서 도구 없는 readback agent 에 본문 대신 파일 경로를 넘겨 읽지 못했고, 재dispatch 는 본문(약 4만 토큰) 인라인이 그 턴 맥락에 들지 않아 하지 못했다(degrade 원장 readback · unavailable)
- 웹: Claude doc-critic-web · codex 켜짐

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택:
  > 같은 뿌리 (권장) — 토큰 낭비와 공유 누락은 둘 다 맥락이 대화·메시지에만 쌓이고 파일에 안 남는 데서 나온다고 보고 파일 규약을 먼저 설계
- **S3** 🗣 발화:
  > 3, 터미널에서 현황 파악은 모드로 할게
- **S4** ☑ 선택:
  > 하위 agent + 실행기 칸 (권장) — 지금 방식을 기본으로 두고 단계표 칸으로 백그라운드 세션·claude -p·다른 모델·스크립트를 단계별로 고를 수 있게
- **S5** 🗣 발화:
  > 나쁘진 않은 생각인데 한개 서버에 한 세션만 있다면 어떻게 메시지 보낼건데, 더 고민이 필요해
- **S6** 🗣 발화:
  > 1, 낡은 규칙과 철학으로 지래짐작 제약은 안되는거 알지?
- **S7** ☑ 선택:
  > 리프레시는 비용 아닌 품질 신호, 일꾼 파일은 대조해 믿기, 작은 일은 가볍게 (고르지 않음: 역할은 agent 정의로)
- **S8** ☑ 선택:
  > 보완 (builder·orchestrator 추천) — ST1: 파일 규약은 취하고, 읽기 설계와 결정한 자리에서 결정 기록을 같은 첫 단추로 올리며, 되읽기 보증은 산출물 대조로 바꿈
- **S9** ☑ 선택:
  > 편지함 + 세션 안 감시자 (권장) — git 원격 편지함이 정본, 각 지휘자 세션의 감시자(monitor·훅)가 알림, 시작 훅이 밀린 글을 읽음
- **S10** 🗣 발화:
  > 1, 아니면 그 안에서 세션이 시작되는건 어려운거겠지? 그러면 읽게 되는거자나
- **S11** 🗣 발화:
  > 1, task는 어디서 말하는 task인거야?
- **S12** 🗣 발화:
  > 이부분은 뭔가 더 만들지 말고 기존에 있는거에 맡기자 새로 바닥부터 구현보다. 내가 처음 생각한 내용은 에픽을 대상으로였어
- **S13** ☑ 선택:
  > 사용자가 (지금) — 지휘자가 끊기 좋은 자리를 알리고 사용자가 /compact
- **S14** ☑ 선택:
  > 순서·숫자는 스크립트, 단계 안은 모델 (권장) — 단계표 순서·멈춤 횟수·해시 승인·동시 2개는 스크립트가 강제, 각 단계 안의 일은 모델이 판단
- **S15** 🗣 발화:
  > 1, 내가 프레이밍 단계에서 이야기한거에서 바꾼거 있어?
- **S16** 🗣 발화:
  > 1, 이러면 어떠한 영향이 있는거지?
- **S17** ☑ 선택:
  > STATUS 는 계산해 쓴 추적 파일 (권장) — 스크립트가 git·원장에서 계산해 STATUS.md 를 쓰고 커밋, machine.md 는 이 기계 캐시로 줄임
- **S18** ☑ 선택:
  > 단계표+지시서로 쪼개기 (권장) — 단계표 파일 + 걸음별 지시서로 나눠 그 걸음에서만 읽고, 쓰지 않는 손 절차(30KB)는 떼어냄
- **S19** 🗣 발화:
  > 세션간 대화방식 더 나은 방법 없는지 조사해줘봐 바닥부터 만들생각 말고
- **S20** 🗣 발화:
  > 1, 파일 구조는 어떻게 되는데
- **S21** 🗣 발화:
  > 1, superpowers같은 다른 플러그인들과의 호환은 ?
- **S22** ☑ 선택:
  > 맞다 — 영상의 과제 = devbrew 의 에픽, 과제 폴더는 에픽마다 하나
- **S23** 🗣 발화:
  > 1, 이러면 핸드북이 너무 쌓이기만 하거나 커지는건 아니지? 이부분은 항상 경계해야해 잘못 쌓인 컨텍스트가 없는거보다 최악이거든 예를 들어 이때는 맞았는데 다른 떄는 틀린거를 그 내용을 보고 근거로 그냥 진행한다던지 아님 핸드북 내용을 보고 지래짐작으로 판단하거나 확인 안해보거나 구현을 꼬으거나 등의 망가지는 현상을 많이 봤어 이거 말고도 리스팅해봐 (이거 원칙으로 저장해줘)
- **S24** ☑ 선택:
  > 레포 쪽 이름 바꿀 (권장) — 팀 규칙 목차를 MEMORY.md 가 아닌 다른 이름으로
- **S25** 🗣 발화:
  > 그리고 이렇게 가면 팀간 나눈다는게 의미가 조금 약해지지 않나?
- **S26** ☑ 선택:
  > 공통 + 팀 전용 짧은 목록 (권장) — 역할·HANDBOOK 은 공통, 팀 폴더에 출처·적용 조건이 붙은 팀 전용 규칙 몇 줄, 두 팀에서 같은 게 나오면 공통으로
- **S27** ☑ 선택:
  > 규칙마다 출처·조건·확인법, 쓰기 전 지금 확인, 반증·낡음이면 지움, 승격 전 반례 확인·상한
- **S28** ☑ 선택:
  > 지금 안 + 기성 기법 차용 (권장) — git 편지함 정본 유지, 감시자는 Claude Code 자체 세션 받은 편지함 + 쉬는 세션 깨우기 훅(asyncRewake) 기법
- **S29** ☑ 선택:
  > 모델용은 일꾼, 사람용은 사람 단계 (권장) — 모델이 부를 수 있는 skill 은 일꾼 단계에, /이름으로만 되는 것은 사람 단계로, 산출 위치는 지시서가 적음
- **S30** ☑ 선택:
  > 이대로 넘김 (권장) — OQ21–OQ32 를 brief 의 열린 질문으로 넘기고 마무리 단계로
- **S31** ☑ 선택:
  > 지금 복사해 둠 (권장) — ~/.claude/projects 의 devbrew 기록(하위 agent 포함)을 레포 밖 백업 폴더로 복사, 설정은 안 바꿈
- **S32** ☑ 선택:
  > devbrew 파일 기준 계산 (권장) — 단계 계산은 과제 폴더(INTENT.md · results/)를 읽고, superpowers 형식 읽기는 「superpowers 단계 맞춤」 하나로
- **S33** 🗣 발화:
  > 1, 데이터 브랜치 보다는 그 로드맵의 지휘자의 브랜치겠지 지금 gitflow상으로는 main에 계속 머지하고 있나? 이거를 여기에서 취합하는건 어떻게 생각해? 여러 로드맵이 동시에 돌거나 디펜던시 걸려있는 경우 많이 갈리려나? 상황을 리스팅 해보고 트레이드 오프를제시해줘
- **S34** ☑ 선택:
  > 기본 main, 선택으로 로드맵 취합 (권장) — 에픽마다 main 에 머지, 함께 나가야 하는 로드맵만 지휘자 브랜치에 취합
- **S35** ☑ 선택:
  > 지휘자 상태 브랜치 (권장) — 로드맵 지휘자마다 코드 없는 상태 전용 브랜치, STATUS 는 그 지휘자만, 편지함은 한 글 한 파일, main 에 머지하지 않음
- **S36** ☑ 선택:
  > 근거대로 바꿈 (권장) — 조건 붙은 규칙은 경로 조건 규칙(.claude/rules)으로, 목차는 바이트 예산, 합치기·나이 이관 대신 반증 삭제, 새 규칙 맨 위 안 함, 승격은 반례 확인 뒤
- **S37** ☑ 선택:
  > 강제 + 사람 승인 탈출구 (권장) — 순서는 스크립트가 지키되 사람이 승인하면 단계를 건너뛰거나 바꿈, 동시 수는 레포 설정(무거운 일 기본 2)
- **S38** ☑ 선택:
  > mod 하나가 겸함 (권장) — 타이머로 git fetch, 새 글이면 자기 세션에 새 턴, 대화형 터미널에서만
- **S39** ☑ 선택:
  > SDD 고침 루프에 맡김 (권장) — devbrew 는 따로 세지 않고 작업 방식의 상한 · 차단기를 따름, 다른 작업 방식은 그 방식의 상한을 단계표가 적음
- **S40** ☑ 선택:
  > 한 번만 더 (권장) — 경로 조건 규칙 적재 여부만 조사, 나머지 셋(상태 브랜치 이름 · P8 파급 · 이전 목록)은 설계의 열린 질문으로, 그 뒤 마무리
- **S41** ☑ 선택:
  > 시작 묶음에 골라 싣기 (권장) — 규칙마다 적용 조건(경로 · 단계 · 역할) 칸, 지휘자가 보낼 때 맞는 줄만 골라(스크립트) 시작 묶음에
- **S42** ☑ 선택:
  > 마무리 (권장) — 포화 판정 4 의 빈 곳 넷을 설계의 열린 질문으로 넘기고 분해 판단 → brief 작성으로
- **S43** ☑ 선택:
  > 고친다 — 출처 바로잡기 (권장) — 목표 출처를 S1·S3 으로, 비목표는 실행기 몸을 S4·S12 로 따로 달아 설계가 출처를 따라갈 수 있게
- **S44** ☑ 선택:
  > 고친다 — 도구 제한 열린 질문로 (권장) — 기각 줄을 「고르지 않음(열림)」으로 바꾸고, 도구 제한을 어디서 거나(허락 도구 칸·쓰기 없는 agent 정의)를 열린 질문으로 더함 — 검수 단계는 쓰기 없는 역할
- **S45** ☑ 선택:
  > 고친다 — 답 번호 풀이 기록 (권장) — 결정(STATUS 파일 + mod)은 그대로, 「3 = STATUS 파일만」을 열린 질문 줄에 적어 다시 헷갈리지 않게
- **S46** ☑ 선택:
  > 고친다 — 발신 확인 먼저 (권장) — 자동 새 턴은 유지하고 발신 확인(서명 커밋·보낸 쪽 허용 목록)을 편지함 계약의 전제로, 확인 안 된 글은 알림만
- **S47** ☑ 선택:
  > 고친다 — 칸 = agent 정의 이름 (권장) — 칸에는 쓰기 도구 없는 agent 정의 이름(역할마다 하나)을 적고 하위 agent 는 그 정의로 보낸다. 따로 띄우는 세션 실행기만 실행 옵션으로 칸을 바로 쓴다. 열린 질문의 선택지가 「칸 = 정의 이름」과 「정의만」 둘로 준다
- **S48** 🗣 발화:
  > 아니 내가 생각하는거는 데브브류의 것들이 한곳으로 모이는걸 원하는거야 이번 고침이 거기에 맏다아 있는거 같은데
- **S49** ☑ 선택:
  > 목표 + 열린 질문으로 싣기 (권장) — 말씀을 원문으로 기록하고 목표 한 줄과 「한곳이 무엇인가」 열린 질문을 더한다 — 팀 파일 규약(R1) · 이전(R5) 설계가 정한다. 인터뷰는 다시 열지 않는다
- **S50** 🗣 발화:
  > 그거랑 추가로 스크립트, 다른모델(코덱스) 이런거 다루는거도 들어가 있는거지?

## 7. 확산 원자료

- «cc-subagents» — https://code.claude.com/docs/en/sub-agents — 하위 agent 자동 압축 · CLAUDE.md 적재 · omitClaudeMd
- «cc-agent-teams» — https://code.claude.com/docs/en/agent-teams — 팀 제약(리드 고정 · 세션당 팀 하나 · 재개 불가)
- «cc-cross-session» — https://code.claude.com/docs/en/cross-session-messaging — 세션 간 메시지 동작 · 자기 자식 예외 · 보류
- «cc-memory» — https://code.claude.com/docs/en/memory — CLAUDE.md · 경로 조건 규칙 적재 시점
- «cc-worktrees» — https://code.claude.com/docs/en/worktrees — 격리 worktree 하위 agent 의 .claude/rules 미적재
- «cc-prompt-caching» — https://code.claude.com/docs/en/prompt-caching — 캐시 TTL · 압축 뒤 재작성
- «cc-statusline» — https://code.claude.com/docs/en/statusline — 상태줄 JSON 칸 · 하위 agent 미계수
- «cc-mods» — https://code.claude.com/docs/en/plugins/mods/overview — mod 표면 · 이벤트 · 무 sandbox
- «cc-issue-87303» — https://github.com/anthropics/claude-code/issues/87303 — 세션 기록 usage 반복 — message.id 로 한 번
- «anthropic-multiagent» — https://www.anthropic.com/engineering/multi-agent-research-system — 다중 agent 토큰 · 결과 파일 참조
- «anthropic-context-eng» — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — 가장 작은 고신호 토큰 · just-in-time
- «cognition» — https://cognition.ai/blog/dont-build-multi-agents — Actions carry implicit decisions
- «mast» — https://arxiv.org/abs/2503.13657v2 — 다중 agent 실패 분류 FM-2.4~2.6
- «exp-following» — https://arxiv.org/abs/2505.16067 — experience-following · 오류 증폭
- «herdr» — https://github.com/herdrdev/herdr — 터미널 pane 주입 · 화면 읽기
- «thrum» — https://github.com/thrum-team/thrum — orphan 브랜치 JSONL 메시지
- «mcp-agent-mail» — https://github.com/Dicklesworthstone/mcp_agent_mail_rust — 받음 확인 · 스레드 · 상주 서버
- «superpowers-sdd» — https://github.com/obra/superpowers — SDD 과제별 새 일꾼 · 고침 루프 5라운드
- «mattpocock» — https://github.com/mattpocock/skills — disable-model-invocation 진입 skill
- «pstack» — https://github.com/cursor/plugins/tree/main/pstack — 라우터 poteto-mode · 플레이북

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 0fbd6ae3#r1.1 · "고친다 — 출처 바로잡기 (권장)" — The goal that status and tokens stay visible in the mod cites an answer about old rules, which mentions neither tokens nor the mod. The non-goal about not building from scratch cites a request that covered only cross-session communication, not executors.
- D1.2 · r1 · adopt · 27d0b627#r1.1 · "고친다 — 도구 제한 열린 질문로 (권장)" — What a role must not do is carried only as text in the role CLAUDE.md, while the agent-definition route that could block tools is recorded as rejected. A reviewing role could then run with write tools, which goes against the repo's rule that writer and reviewer are separated by tools, not by prompts.
- D1.3 · r1 · adopt · 9b7056b0#r1.1 · "고친다 — 답 번호 풀이 기록 (권장)" — On how to show the task list, the user's answer was '3', which is 'both' in the listed order. The brief settled it as 'the STATUS file only' and recorded the platform task-list tool as rejected. The answer can be read two ways.
- D1.4 · r1 · adopt · abf668a4#r1.2 · "고친다 — 발신 확인 먼저 (권장)" — The status mod has no sandbox, yet it would pull mailbox messages from other machines over git and start a new turn in the conductor's own session. The sender check the user required (is this really from our agent) has no mechanism yet, so whoever can push to the remote can put instructions straight into the conductor session.
- D2.5 · r2 · adopt · 402da1b4#r2.1 · "고친다 — 칸 = agent 정의 이름 (권장)" — Claude Code 에는 하위 agent 를 부를 때 그 agent 의 도구를 정하는 길이 없다. 그래서 기본 일꾼(하위 agent)에게 단계표의 「허락 도구 칸」만 둬서는 실제로 아무 도구도 막지 못한다. 도구 제한을 거는 자리를 묻는 열린 질문은 「칸만」을 독립 선택지로 내놓고 있다. 칸의 값을 쓰기 도구 없는 agent 정의 이름으로 묶는 상태와, 칸을 단독으로 두는 지금 상태 중 하나를 골라야 한다.
- docreview 계수 — spec-distill-59ec298a/2026-11-14-conductor-context-economy-bri-6d19dde7c64a4272 r1: advice_new=1 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-conductor-context-economy-bri-6d19dde7c64a4272 r2: advice_new=0 · advice_repeat=1 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-conductor-context-economy-bri-6d19dde7c64a4272 r3: advice_new=0 · advice_repeat=1 · mc_preexisting_new=2
