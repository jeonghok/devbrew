---
type: interview-audit
payload: 2026-11-14-framing-interview-constraint-audit-brief-interview.md
created_at: 2026-11-14
session_id: ee276545-0999-4e89-aeab-9cec39e6c504
source: spec-distill pm-interview
---

# 앞단(framing · 인터뷰)을 새 코어에 맞추기 — Interview Audit

> 순수 텔레메트리 — 다음 stage가 읽는 핸드오프 산출물은 payload이고, 여기에는 이 인터뷰가 어떻게 진행됐는지의 프로세스 기록만 남는다(D1).
> payload frontmatter의 `audit_file`이 이 파일을 가리키며, 게이트는 두 파일을 함께 검사한다.

## 1. Coverage Ledger

- floor:root_problem — closed — S1 「이 일의 목적은 request-framing 과 인터뷰가 새 코어와 맞지 않는 부분을 개선하고 강화하고 낡은 부분을 고치는 것이다. (사용자 확인)」 · S4 「새 코어에 맞추기 (권장)」
- floor:landscape — closed — S6 「공식 쪽으로 옮길 후보로 본다」 — 공식 문서 대조(조사 3 · 5)의 처분
- floor:skepticism — closed — ST1 S11 「공식을 따라가 」 · ST2 S12 「공식대로 가고 기존 판올림도 다시 다 검토해봐 」 · ST3 S13 「유지」 — steelman 판정 셋
- floor:blind_spot — closed — S19 「원자료의 비밀값 (권장), 질문 · 선택지의 의역 (권장), 한 일에 너무 많이 실림」 — 숨은 가정 · 실패 양식(조사 10)의 처분
- floor:open_questions — closed — S25 「이대로 싣는다 (권장)」 — 설계로 넘길 열린 질문 목록(OQ25–OQ35)의 확인 · S29 「이대로 싣는다 (권장)」 — 더해진 둘(OQ36 · OQ37)의 확인 · S30 「포화로 보고 종료 (권장)」 — 새로 열린 결정(OQ38)을 열린 질문에 더하는 것의 확인 (재개방 1회 — R11 — 확인 범위(OQ25–OQ35) 밖에서 열린 결정 OQ36 · OQ37 이 더해졌다)
- derived:internal_research — closed — 조사 1 · 2 가 repo_claims 를 냈다 — 레포 주장의 처분 S 로 닫는다; S24 「그대로 싣고 미확인은 표시 (권장)」 — 레포 주장 156건의 처분
- derived:원자료_정본_사슬 — closed — S1 이 seed 전문이고 brief 리뷰 정답이 그 §6 이라 원자료 파일을 정본으로 올리면 seed 문법 · 출처 분류기 · 리뷰 프로필 · 묶음 생성기가 한 사슬로 바뀐다 (조사 1); S5 「사본이 없다 (권장), 원자료는 글자 그대로 (권장), 로드맵 없는 일도 같은 자리, 3 시작이 framing일수도 있고 아닐수도 있긴함 」
- derived:역할과_이름 — closed — 이름 바꾸기의 대상(어느 단계가 의도 싱크인가)과 파급 — 호출 이름 · 설정 키 · 머리 키 · 접미사 · 옛 기록 · 진입 표면 락 (조사 1 · 2, 옆 세션이 전한 사용자 말); S2 · S8 · S17 「컨텍스트 쌓기 (권장)」
- derived:옆_로드맵_경계와_순서 — closed — 예약 파일 겹침 · 머지 순서 · 승인 전 설계문서가 잣대라는 것 · 그 문서가 이 일 몫으로 적은 것 (조사 1 의 제안 둘을 합침 · 조사 2); S3 · S16 「그대로 이 일이 맡는다 (권장)」
- derived:게이트와_락 — closed — 작은 일의 가벼운 길은 구조 게이트 통과 조건을 바꾸고, 앞단 글 줄이기는 글자를 단언하는 테스트에 닿는다 (조사 1 의 제안 둘을 합침); S20 「사람에게 보이고 통과 (권장)」
- derived:표준_대조_범위 — closed — 공식 자료는 참고 — 저술 가이드 · 철학 문서에서 의도한 차이와 낡음을 가른다 (조사 1); S6 · S9 · S10 · S11 · S12 · S13 · S14 · S15 · S18 「판은 두고 올림 단위를 푼다 (권장)」
- derived:승인_화면 — closed — 사용자가 직접 개선을 요구한 seed 리뷰의 덩어리 처분 화면 (조사 1); S21 「문단 전체가 두 번 나온다 (권장), 어느 지적 때문인지 안 보인다 (권장), 덩어리마다 질문이 따로다, 추천이 없다」

## 2. Budget

- 질문 라운드: 12 · agent dispatch: 44 · coverage-mapper 1 · codex 실호출: 0 (성공 0)
- 조사 호출 13/60 (장치별: 커버리지 1 · 맹점 1 · 반론 3 · 레포 조사 6 · 만든 조사 2 · 본체 직접 7)
- 포화 판정 1: 아직 — 빈 곳 4개
- 포화 판정 2: 아직 — 빈 곳 5개
- 포화 판정 3: 아직 — 빈 곳 8개
- 포화 판정 3: 사용자 판단 포화(@S30) — 반복 빈 곳

## 생성 기록

- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F2.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F3.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F4.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F5.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F6.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/F7.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/P1.md
- docs/superpowers/roadmaps/2026-11-14-framing-interview-constraint-audit-brief/roadmap.md

## 3. Steelman 원문

#### ST1 — agent 머리말의 model 키를 허용하는 방향의 반론 검토

**dispatch 입력** — goal: S4 · 전제: P1 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 — 철학 문서를 두고 한 말(S1) · P2 공식 자료는 따라야 할 기준이 아니라 참고 내용이다(S1) · P3 공식과 다른 자리는 공식 쪽으로 옮길 후보로 본다(S6) · P4 「가능하면 추가보다는 푸는 쪽으로 가고」(S1) · P5 저술 가이드는 표준에 맞추는 방향과 새 코어에 맞추는 방향을 함께 적용해 고친다(S1) · P6 공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다(orchestrator 도출) · 제약: S1–S10 원문 전량 · trigger: 기존 사용자 제약과의 충돌(2026-09-06 실측을 근거로 승인한 금지 규칙)

> case_for_alternative:
>   statement: >-
>     agent frontmatter 의 `model` 키 금지를 그대로 둔다 — agent 마다 티어를 달리해야 하면 사용자 소유 설정값을 dispatch 인자로 넘기는, 지금 있는 길(`review_model` 꼴)을 쓴다.
>   strongest: >-
>     goal(S4)의 네 축(넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름) 가운데 이 키를 요구하는 축이 없다. 키를 열면 부재를 단언하는 락 파일 최소 12개와 qg README · qg 공시 줄 · 저술 가이드가 이 일에 얹혀, 네 축이 같은 무게로 가야 할 일에 다섯째 짐이 생긴다.
>     지금 상태는 「공식과 다른 장치」가 아니다. 공식 문서의 기본값이 키 없음이고(`model` 은 필수가 아니며 생략하면 공식 순서대로 고른다), devbrew agent 20개는 이미 공식 그대로다. 옮길 대상이 산출물에는 없고 저술 정책에만 있다.
>     키 없음은 CLI 판이 바뀌어도 뜻이 같은 유일한 설정이다. 공식 환경변수 표에 따르면 2.1.251 앞에서는 환경변수가 정의의 `model` 을 이겼고 뒤에서는 정의가 이긴다. 키가 없으면 두 시기 모두 「사용자 환경변수 → 세션 모델」이다.
>     사용자 레버 하나(`CLAUDE_CODE_SUBAGENT_MODEL`)가 20개 전부에 닿고, qg 가 매 반복 찍는 「리뷰어 모델」 공시 줄이 참으로 남는다. agent 별 티어는 이미 우선순위 1번 자리(dispatch 인자)에서 사용자 설정값 `review_model` 로 준다 — 정의에 값을 박지 않고도 된다.
>     정의에 박은 값의 실패 사례가 upstream 에 쌓여 있다: 플러그인 agent 의 `model` 이 frontmatter 파싱 실패 때 오류 없이 빠진다는 열린 보고, 별칭이 Vertex 에서 옛 모델로 풀린다는 보고, 플러그인이 실은 agent 의 한 칸을 설치 사용자가 바꾸려면 파일을 통째로 복사해야 한다는 요청(비활동으로 닫힘).
>     사용자는 이 주제에서 두 번(2026-09-06 · 2026-10-17) 고정을 푸는 쪽으로 결정했다.
> case_for_current:
>   strongest: >-
>     키 금지는 이 레포가 진 무게다 — 절대 금지 한 줄, 부재 락 최소 12개 파일, 변이 락 하나, plugin-dev 검증기가 `model` 없는 agent 에서 죽는 것을 감싸는 plugin-audit 분기. 금지를 풀면 저술 가이드 22행의 실측 이력 문장(판 · 날짜 · 설계문서 경로)이 사라지고(글 줄이기), 새 코어가 역할마다 값싼 티어를 정의 한 줄로 실을 수 있다(가벼운 길). 공식 문서가 subagent 의 쓸모로 드는 것이 바로 「더 빠르고 싼 모델로 일을 보내 비용을 줄인다」다.
>     공식 문서는 `model` 을 플러그인 agent 지원 필드로 싣고, 예시 플러그인의 `security-reviewer` agent 에 `model: sonnet` 을 쓴다. 공식 플러그인도 고정한다(pr-review-toolkit `code-reviewer` 는 `model: opus`, feature-dev `code-explorer` 는 `model: sonnet`). 금지 · 비권장 문구는 없다.
>     절대 금지는 레포 자신의 꼴과 어긋난다. 철학 P8 은 규칙을 「기본은 X, 일의 모양이 다르면 판단하고 이유를 적는다」로 쓰라 하고 결정론은 보안 · 정확성 게이트에만 두라 한다. 티어 선택은 그 게이트가 아니다. 2026-10-08 사용자 지시 「리뷰는 opus」는 이 규칙을 재결정으로 넘어야 했다 — 절대형이 사용자 자신의 요구와 이미 한 번 부딪혔다.
>     사용자가 잃는 것은 되돌릴 수 있다. `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 이 정의의 `model` 을 무시하게 하고(공식 문서 · 레포 실측 F4), dispatch 인자는 여전히 정의보다 앞선다. 이 레포는 제3자 설치를 확인된 사실로 두지 않으므로 agent 정의를 쓰는 사람과 환경변수를 정하는 사람이 같다 — 정의의 키도 사용자의 선택이고 git 으로 되돌린다. 환경변수 하나는 20개를 한 값으로만 묶지만 키는 agent 마다 다르게 준다.
>     S10 에서 사용자는 「적으면 환경변수로 정한 기본 모델을 덮는다」는 결과를 읽고 골랐다.
> premise_refutation:
>   hits: [P6]
>   why: >-
>     P6 「공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다」 —
>     (1) https://code.claude.com/docs/en/env-vars 의 `CLAUDE_CODE_SUBAGENT_MODEL` 행: 「Two sources take precedence over it: a model Claude passes when it spawns the agent, and a `model` field in the agent's definition, including `inherit`.」 https://code.claude.com/docs/en/sub-agents 「Choose a model」의 순서도 같다(정의의 `model` 이 2번, 환경변수가 3번). 지금 장치가 주던 것은 「환경변수 하나가 devbrew agent 20개 전부에 닿는다」인데, 키를 든 agent 에는 그 환경변수가 닿지 않는다. 레포 실측 F2(docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md 「A. 측정 여섯」)가 `inherit` 에 대해 같은 결과를 CLI 2.1.261 에서 쟀다.
>     (2) plugins/quality-gates/skills/quality-pipeline/SKILL.md 의 공시 줄 `echo "> [quality-gates] 리뷰어 모델: ${CLAUDE_CODE_SUBAGENT_MODEL:-세션 모델}…"` 은 환경변수만 보고 값을 낸다. 키를 든 리뷰어가 생기면 이 줄은 실제와 다른 모델을 알린다 — 사용자에게 주던 정확한 공시가 유지되지 않는다.
>     (3) 되찾는 길 `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` 은 전부 아니면 전무다: 공식 문서 「While `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is on, Claude Code ignores the `model` field in subagent definitions, and Claude can't pass a model when it starts a subagent.」 dispatch 인자 길(`review_model`)까지 함께 막는다. 레포 README 는 이 변수를 권하지 않는다.
>     범위: 키를 «허용»만 하고 어느 agent 도 쓰지 않는 동안에는 P6 이 참이다. 충돌은 키를 실제로 든 agent 부터 생긴다.
> premise_list_challenge: >-
>   (1) P6 은 orchestrator 가 도출한 전제인데, S10 선택지 설명이 이미 그 반대(「적으면 사용자가 환경변수로 정한 하위 agent 기본 모델을 덮는다」)를 사용자에게 알렸다. 이 항목에서 P6 은 사용자가 믿고 고른 전제가 아니라 알고 넘은 전제다 — 위 hit 는 새 사실이 아니라 이미 알린 사실의 원문 확인이다.
>   (2) 빠진 전제 셋. (가) 이 주제의 가장 최근 사용자 결정 — 2026-10-17 「qg 리뷰어 모델 opus 고정 → 세션 모델을 따르게(사용자 결정)」. 키 허용이 판정에 들어가는 agent 에도 미치는지 묻지 않았다. (나) CLAUDE.md 상시 원칙 「레포 전용 값 금지. 경로 · 테스트 명령 · 브랜치 · 모델 같은 값은 도출하거나 레포마다 정하게 한다」 — 리터럴 티어를 플러그인 agent 에 적는 것과 바로 닿고, 허용하려면 이 줄과 맞춰야 한다. (다) 2026-09-06 수용 근거 「하향을 하니스가 아니라 사용자가 고르고 되돌릴 수 있다」.
>   (3) P3 의 분류가 이 항목에는 헐겁다. S9 항목(최상위 `cost_class` · `integrity`)은 산출물이 공식 밖 자리에 있었다. 여기는 산출물이 공식 기본값 그대로이고 저술 정책만 공식보다 좁다 — 「공식과 다른 자리」보다 「공식보다 좁게 쓰는 자리」다.
>   (4) goal(S4)의 네 축에 `model` 키가 없다. 이 방향은 goal 이 아니라 S6 갈래에서 나왔고, goal 만으로 재면 양쪽 다 약하게 닿는다.
>   (5) 규칙 22행의 앞 절 「리터럴 티어는 세션의 모델 선택을 덮어쓰고」는 2026-09-06 측정 여섯에 없다 — 그 표는 키 없음과 `inherit` 만 쟀다. 리터럴 티어 대 환경변수는 공식 문서 서술에만 기대고, 2.1.303 이후 재실측은 없다(이 dispatch 는 읽기 전용이라 재지 않았다).
>   (6) 대안이 S10 의 고르지 않은 첫 선택지와 겹친다. OQ10 이 바로 그 재검토라 냈다. 같은 입력을 다시 받은 것은 아니다.
> recommendation: refined
> refined_takes: >-
>   금지를 푼다는 것. 규칙을 「기본은 `model` 키를 두지 않는다. 일의 모양이 다르면 둘 수 있고, 둘 때는 그 agent 가 사용자의 `CLAUDE_CODE_SUBAGENT_MODEL` 을 덮는다는 사실과 이유를 그 플러그인 README 에 적는다」 꼴로 다시 쓴다 — 사용자가 2026-10-17 에 정한 고치는 꼴(「언제나 X」 → 「기본은 X, … 무엇을 왜 골랐는지 적는다」)과 같다. 22행의 실측 이력 서술(판 · 날짜 · 설계문서 경로)은 걷어낸다. `model` 이 공식 지원 필드라는 사실을 가이드에 그대로 둔다. 절대 부재 단언은 「키가 있으면 공시가 있다」 쪽으로 바꾸되 락의 꼴은 설계가 정한다.
> refined_drops: >-
>   기본값 없는 전면 허용(「공식처럼」 정책 없이 여는 것). 지금 agent 20개에 키를 더하는 것 — plugin-dev 검증기를 통과시키려는 `inherit` 일괄 추가 포함(환경변수를 다시 막는다, F2). 판정에 들어가는 qg 리뷰어 둘의 티어를 이 일에서 다시 고정하는 것(2026-10-17 사용자 결정은 사용자가 따로 뒤집을 때까지 그대로). 부재 락을 대체 없이 지우는 것. qg 공시 줄이 환경변수만 보는 채로 키 든 리뷰어를 부르는 것.
> evidence:
>   - url: "https://code.claude.com/docs/en/sub-agents"
>     supports: both
>     claim: >-
>       「Choose a model」 원문 — 「By default, a subagent you define runs on the same model as the conversation that starts it.」 순서는 1. per-invocation `model` parameter 2. 「The `model` field in the subagent's definition, including `inherit`」 3. `CLAUDE_CODE_SUBAGENT_MODEL` 4. main conversation's model. frontmatter 표의 `model` 행은 Required 「No」, 「When you omit it, Claude Code picks the model in the subagent model order」. FORCE: 「While `CLAUDE_CODE_SUBAGENT_MODEL_FORCE` is on, Claude Code ignores the `model` field in subagent definitions, and Claude can't pass a model when it starts a subagent.」(v2.1.257 이상). 쓸모: 「Control costs by routing tasks to faster, lower-cost models like Haiku」. 플러그인 agent 의 `model` 을 금지 · 비권장하는 문구는 없다. 페이지 116,580자 가운데 앞 10만 자만 읽었다.
>     touches: [P6, P3]
>     decides: [OQ10]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     version: {used: "2.1.303 (plugins/*/dependencies.md 의 claude-code 행)", latest: "확인 못 함 — 이 dispatch 에서 다시 재지 않았다"}
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/env-vars"
>     supports: alternative
>     claim: >-
>       `CLAUDE_CODE_SUBAGENT_MODEL` 행 원문 — 「The default model for subagents, agent team teammates, and workflow agents that aren't assigned a model another way. … Two sources take precedence over it: a model Claude passes when it spawns the agent, and a `model` field in the agent's definition, including `inherit`. … Setting it to `inherit` is the same as leaving it unset. Before v2.1.251, this variable overrode both the per-invocation model and the definition's `model` field」. 정의에 키가 있으면 사용자 환경변수가 그 agent 에 닿지 않고, 그 우선순위 자체가 2.1.251 에서 뒤집혔다. 키가 없으면 두 시기 모두 환경변수 → 세션 모델이다.
>     touches: [P6]
>     decides: [OQ10]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/components"
>     supports: current
>     claim: >-
>       「Frontmatter fields in plugin agents」 원문 — 「Supported fields: `name`, `description`, `model`, `effort`, `maxTurns`, …」, 「Ignored fields: `permissionMode`, `hooks`, `mcpServers`, and `initialPrompt`」. 같은 페이지의 예시 플러그인 agent `security-reviewer` 는 frontmatter 에 `model: sonnet` 을 쓴다. `model` 을 권하거나 말리는 문장은 없다.
>     touches: [P3]
>     decides: [OQ10]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/pr-review-toolkit/agents/code-reviewer.md"
>     supports: current
>     claim: >-
>       공식 플러그인 pr-review-toolkit 의 `code-reviewer` agent 는 frontmatter 에 `model: opus` 를 둔다(`tools` 키는 없다). WebFetch 의 요약 모델을 거친 값이다.
>     touches: [P3]
>     decides: [OQ10]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/feature-dev/agents/code-explorer.md"
>     supports: current
>     claim: >-
>       공식 플러그인 feature-dev 의 `code-explorer` agent 는 frontmatter 에 `model: sonnet` 을 둔다. WebFetch 의 요약 모델을 거친 값이다.
>     touches: [P3]
>     decides: [OQ10]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://github.com/anthropics/claude-code/issues/79866"
>     supports: alternative
>     claim: >-
>       「Configure a subagent's model and effort from settings, without forking its prompt (plugin-shipped agents)」 — 2026-07-21 열림, 2026-09-17 비활동으로 닫힘(not planned, 메인테이너 답 없음). 원문: 「the only supported way to change one field of a subagent you did not author is to copy its entire markdown file — prompt body and all — into `.claude/agents/`.」 agent 별 설정 맵은 없다. 플러그인 정의에 박힌 값을 설치 사용자가 agent 하나만 골라 바꾸는 길은 파일 복사뿐이다(모델은 환경변수 · dispatch 인자로도 닿지만 환경변수는 정의의 키에 진다).
>     touches: [P6]
>     decides: [OQ10]
>     source_kind: secondary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://github.com/anthropics/claude-code/issues/89723"
>     supports: alternative
>     claim: >-
>       「Plugin subagents: `model:` frontmatter in a plugin's agents/*.md is ignored」 — 2026-08-26 열림, 지금 열려 있음, 메인테이너 답 없음. 커뮤니티 댓글의 측정(CLI 2.1.263 · 2.1.296): frontmatter 가 YAML 로 파싱되지 않으면(따옴표 없는 description 안의 「: 」) 플러그인 로더가 블록 전체를 버리고 agent 는 오류 없이 부모 모델로 돈다. 정의의 `model` 은 적혀 있어도 조용히 안 먹을 수 있다.
>     touches: []
>     decides: [OQ10]
>     source_kind: secondary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://github.com/anthropics/claude-code/issues/36242"
>     supports: alternative
>     claim: >-
>       「Vertex/Bedrock subagents silently downgraded to older models (not fully fixed)」 — 2026-03-19 열림, CLI 2.1.76, 비활동으로 닫힘. Vertex 에서 sonnet 하위 agent 가 부모와 다른 옛 판으로 풀린다는 보고. 별칭으로 적은 티어는 제공자에 따라 다른 모델이 된다. 오래된 판의 보고이고 지금 판에서 다시 확인하지 않았다.
>     touches: []
>     decides: [OQ10]
>     source_kind: secondary
>     checked_at: "2026-11-14"
>     certainty: uncertain
> repo_claims:
>   - id: RC1
>     path: "docs/plugin-authoring.md"
>     anchor: "**agent frontmatter 에 `model` 키를 두지 않는다.**"
>     line: 22
>     claim: >-
>       규칙은 예외 없는 금지이고 근거를 P8 위반으로 적는다. 규칙 문장 안에 실측 판(CLI 2.1.261) · 날짜(2026-09-06) · 설계문서 경로가 들어 있다. 하위 bullet(23행)은 dispatch 인자를 오케스트레이터 재량으로 두되 게이트 판정 · 측정에 들어가는 agent 에는 넘기지 않게 한다.
>     touches: [P4, P5]
>     decides: [OQ10]
>   - id: RC2
>     path: "docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md"
>     anchor: "A. 측정 여섯"
>     line: 43
>     claim: >-
>       CLI 2.1.261 실측: 키 없는 agent 는 환경변수 → 세션 모델(F1), `model: inherit` 는 환경변수를 무효화(F2), `_FORCE=1` 은 `inherit` 까지 덮는다(F4). 프로브는 `probe-nomodel` 과 `probe-inherit` 둘뿐이라 리터럴 티어 대 환경변수는 이 표에 없다. dispatch 인자 대 환경변수(U1)와 FORCE 의 범위(U2)는 미실측으로 적혀 있다. 사용자는 「환경변수를 켠 세션에서 리뷰어가 writer 보다 약해진다」는 트레이드오프를 수용했다.
>     touches: [P6]
>     decides: [OQ10]
>   - id: RC3
>     path: "plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh"
>     anchor: "예외는 없다 — qg 리뷰 agent 도 키가 없다(R2a 사용자 결정 「세션 모델을 따른다」)"
>     line: 8
>     claim: >-
>       스윕은 `plugins/*/agents/*.md` 의 frontmatter 에 `model` 키가 하나라도 있으면 RED 이고, qg README 의 문장 「모델을 고정하지 않는다 — `CLAUDE_CODE_SUBAGENT_MODEL` 이 있으면 그 값, 없으면 세션 모델을 따른다.」의 실재도 단언한다. 키를 허용하면 이 락은 규칙과 모순된다.
>     touches: [P6]
>     decides: [OQ10]
>   - id: RC4
>     path: "plugins/quality-gates/tests/test_agent_model_mutation.sh"
>     anchor: "pairs=("
>     line: 24
>     claim: >-
>       변이 락이 스윕과 per-agent 락 8개 파일(security_reviewer_persona · code_recritic_frontmatter · artifact_critic_frontmatter · artifact_adversarial_frontmatter · blind_spot_prober_frontmatter · coverage_mapper_frontmatter · steelman_builder_scope · brief_agents)이 키 삽입에 RED 임을 증명한다. 여기에 규약 문장 락(`test_governance_no_capability_caps.sh` 의 AC8d — `NEW_RULE` 리터럴)과 `shared/tests/test_docreview_agents.sh`(「frontmatter 에 model 키 없음(main 규약)」)를 더하면 키 부재를 단언하는 락 파일이 최소 12개다. 키 허용은 이들을 뒤집거나 지우는 일을 낳는다.
>     touches: [P4]
>     decides: [OQ10]
>   - id: RC5
>     path: "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
>     anchor: "echo \"> [quality-gates] 리뷰어 모델: ${CLAUDE_CODE_SUBAGENT_MODEL:-세션 모델}"
>     line: 372
>     claim: >-
>       qg 가 매 반복 찍는 리뷰어 모델 공시 줄은 환경변수만 보고 값을 낸다. 리뷰어 정의에 `model` 키가 생기면 이 줄은 실제와 다른 모델을 알린다. 이 줄의 문면은 `plugins/quality-gates/tests/test_skill_run_contract.sh` 215행이 글자 그대로 고정한다.
>     touches: [P6]
>     decides: [OQ10]
>   - id: RC6
>     path: "plugins/quality-gates/README.md"
>     anchor: "**Choosing a cheaper tier for devbrew subagents is the user's call, not the plugin's.**"
>     line: 141
>     claim: >-
>       README 가 사용자에게 「티어를 고르는 것은 플러그인이 아니라 사용자」라고 약속하고 `~/.claude/settings.json` 의 `env` 예시를 준다. `_FORCE=1` 은 존재만 적고 권하지 않는다고 적는다.
>     touches: [P6]
>     decides: [OQ10]
>   - id: RC7
>     path: "docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md"
>     anchor: "K1. 리뷰는 opus 다."
>     line: 102
>     claim: >-
>       2026-10-08 사용자 지시 「리뷰는 opus」로 qg 소유 리뷰 agent 둘을 `model: opus` 로 고정했다. 같은 문서 재결정 표의 R3 행이 「qg agent 에 모델 키 없음(agent-model-unpin)」 → 「qg 소유 리뷰 agent 는 `model: opus`」로 적는다 — 절대 금지 규칙이 사용자 요구로 한 번 넘어졌다.
>     touches: []
>     decides: [OQ10]
>   - id: RC8
>     path: "docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md"
>     anchor: "리뷰어 모델 opus 고정 둘"
>     line: 107
>     claim: >-
>       2026-10-17 처분 「제거 — 세션 모델을 따른다(사용자 결정, `flexibility-audit.md`)」. qg CHANGELOG 14.1.0(2026-10-19) 「리뷰어 모델 고정(`model: opus`)을 풀어 `CLAUDE_CODE_SUBAGENT_MODEL`, 없으면 세션 모델을 따른다.」로 실렸다. 이 주제의 가장 최근 사용자 결정이고 전제 목록에 없다.
>     touches: []
>     decides: [OQ10]
>   - id: RC9
>     path: "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md"
>     anchor: "고치는 꼴: 「언제나 X」 를 「기본은 X, 일의 모양이 다르면 모델이 판단해 고르고 무엇을 왜 골랐는지 적는다」 로."
>     line: 5
>     claim: >-
>       사용자가 정한 고치는 꼴이고, 9행의 사용자 원문 「넷 모두 기본값 + 모델 판단으로: … qg 리뷰어 모델 opus 고정 …」이 모델 고정을 그 꼴의 대상으로 든다. 절대 금지를 「기본은 키 없음」으로 바꾸는 것은 이 꼴과 같다.
>     touches: [P4]
>     decides: [OQ10]
>   - id: RC10
>     path: "CLAUDE.md"
>     anchor: "**레포 전용 값 금지.** 경로 · 테스트 명령 · 브랜치 · 모델 같은 값은 도출하거나 레포마다 정하게 한다(철학 P8)."
>     line: 31
>     claim: >-
>       상시 원칙이 「모델」을 박지 말아야 할 값으로 이름 붙여 든다. 플러그인 agent 정의에 리터럴 티어를 적는 것은 이 줄과 바로 닿는다. `plugins/spec-distill/tests/test_conducting_reference.sh` 395–397행은 `review_model: opus` · `review_model: sonnet` · 「haiku 로 부른다」를 금지 리터럴의 양성 대조로 쓴다.
>     touches: []
>     decides: [OQ10]
>   - id: RC11
>     path: "plugins/spec-distill/skills/epic-conductor/SKILL.md"
>     anchor: "모델 칸은 해결자 `repo_defaults.py get review_model --roadmap <로드맵>` 의 값이 이 dispatch 의 모델 칸이 받는 이름일 때만 그 값을 준다."
>     line: 173
>     claim: >-
>       agent 하나에만 다른 티어를 주는 길이 이미 있다 — 사용자가 레포 설정에 적은 `review_model` 을 통합 리뷰어 dispatch 의 `model` 인자로 넘기고, 값이 없으면 인자를 빼 세션 모델로 가며 그 사실을 알린다. 정의에 값을 박지 않고 공식 순서의 1번 자리를 쓴다.
>     touches: [P6]
>     decides: [OQ10]
>   - id: RC12
>     path: "plugins/plugin-audit/scripts/check-plugin-structure.sh"
>     anchor: "has_model_key()"
>     line: 63
>     claim: >-
>       plugin-dev 의 `validate-agent.sh` 가 `model` 키 없는 agent 에서 ❌ 줄 없이 rc=1 로 죽어, devbrew 는 그 경우를 집계 한 줄로 묶는 분기를 따로 진다. 키 금지가 낳은 유지 비용이다. 규칙만 풀고 agent 가 키를 들지 않으면 이 분기는 그대로 남는다.
>     touches: [P4]
>     decides: [OQ10]
>   - id: RC13
>     path: "plugins/quality-gates/agents/security-reviewer.md"
>     anchor: "frontmatter (model 키 없음)"
>     claim: >-
>       `plugins/*/agents/*.md` 20개(Glob) 어디에도 frontmatter `model` 줄이 없다(Grep `^model:` 0건 — Grep · Glob 은 심볼릭 링크를 건너뛰므로 20 은 하한이다). 산출물은 공식 기본값(키 생략) 그대로다.
>     touches: [P3]
>     decides: [OQ10]
>   - id: RC14
>     path: "CLAUDE.md"
>     anchor: "이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다."
>     line: 49
>     claim: >-
>       레포 규칙이 제3자 설치를 아직 확인되지 않은 조건으로 다룬다. agent 정의를 쓰는 사람과 환경변수를 정하는 사람이 같다는 원안 쪽 논거의 근거이고, 그 조건이 깨지면 논거도 함께 깨진다. 줄번호는 다시 재지 않은 보조 값이다.
>     touches: []
>     decides: [OQ10]
> # 확인 못 함: (1) 2.1.303 이후 판에서 해석 순서 재실측(읽기 전용 dispatch). (2) 공식 changelog 의 2.1.251 · 2.1.325 항목 원문 — env-vars 행의 「Before v2.1.251」 문장으로만 확인. (3) 옆 세션의 팀 파일 규약 설계문서(이 worktree 에 없음) — 새 코어가 역할별 티어를 요구하는지는 읽지 못했다.
> # 읽은 자리(절대 경로): /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/plugin-authoring.md · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/tests/test_agent_model_mutation.sh · /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md (조사 3 · 5 · 6)

**게이트-전 확인** — repo_claims: RC80–RC93 확인 14/14 · 부착 주장: sub-agents 순서 → P6 · P3 확인 · env-vars → P6 확인 · components → P3 확인 · pr-review-toolkit → P3 확인 · feature-dev → P3 확인 · issue 79866 → P6 확인 못 함(세지 않음) · 재검토 자격: 열림 3건(P6)

**사용자 선택** — 유지 (S11) — 「공식을 따라가 」 를 유지로 읽었다(본체의 읽기)

#### ST2 — plugin.json 필수 키와 판 올림 규칙을 완화하는 방향의 반론 검토

**dispatch 입력** — goal: S4 · 전제: P1 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 — 철학 문서를 두고 한 말(S1) · P2 공식 자료는 따라야 할 기준이 아니라 참고 내용이다(S1) · P3 공식과 다른 자리는 공식 쪽으로 옮길 후보로 본다(S6) · P4 「가능하면 추가보다는 푸는 쪽으로 가고」(S1) · P5 저술 가이드는 표준에 맞추는 방향과 새 코어에 맞추는 방향을 함께 적용해 고친다(S1) · P6 공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다(orchestrator 도출) · 제약: S1–S10 원문 전량 · trigger: 기존 사용자 제약과의 충돌(PR 마다 판 올림 · CHANGELOG · major 올림 규칙)

> ```yaml
> case_for_alternative:
>   statement: >-
>     `version` 은 명시 SemVer 로 남기고(CHANGELOG 판 헤딩 · 호출 이름 변경 시 major 올림도 그대로), 완화는 두 곳에만 건다 —
>     규칙 문면에서 「로더가 요구하는 키는 `name` 하나」 와 「devbrew 가 쓰는 키(`version` · `description`)」 를 가르고,
>     판 올림은 「플러그인을 건드리는 모든 PR」 에서 「설치본 동작에 닿는 변경」 으로 좁힌다(닿지 않으면 이유를 적고 건너뛴다).
>   strongest: >-
>     devbrew 에서 판 번호는 캐시 키만이 아니라 «순서가 있는 값»으로 읽힌다. 지휘자는 `plugin.json` 의 `version` 이 비면
>     기계 상태를 쓰지 못하고 멈추고(「플러그인 판이 비어 있다」), 더 새 판이 쓴 기계 상태를 옛 판이 읽지 못하게 막고,
>     설치본이 레포 사본보다 옛 판인지 알리며, spec-distill 은 quality-gates 의 최소 판(14.6.0)을 그 값에서 잰다(RC3–RC6).
>     커밋 SHA 는 순서가 없어 이 넷을 대신하지 못한다.
>     이 일 자체가 호출 이름 둘을 바꾸고(S2 · S8) 레포 규칙은 그 깨짐 신호를 major 올림으로 낸다(RC2) — `version` 을 비우면
>     goal 의 「이름」 갈래가 신호를 실을 자리를 잃는다.
>     「공식 쪽」도 한 겹이 아니다. `name` 하나는 로더의 바닥이고, 공식 검증기는 `version` · `description` · `author` 가 없으면
>     경고하며(`--strict` 는 실패), Anthropic 자신의 플러그인은 넷을 다 적고, 공식 의존 장치(semver 범위 →
>     `<plugin-name>--v<version>` 태그)는 명시 판을 전제한다. 공식 문서는 「판을 올리거나 비우거나」 를 둘 다 정식 선택지로 적는다 —
>     지금의 필수 셋과 판 올림은 이미 공식 안에 있고, devbrew 고유인 것은 「필수」 라는 낱말과 「PR 마다」 라는 단위뿐이다.
>     캐시 신선도는 두 길이 거의 같다(플러그인을 건드린 머지마다 새 사본). 다른 것은 판 문자열이 순서 있는 SemVer 인가
>     해시인가 하나이고, goal 의 네 갈래(넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름) 어느 것도 `version` 을 비워야 얻어지지 않는다.
> case_for_current:
>   strongest: >-
>     새 코어는 에픽을 병렬로 돌리는 팀 구조인데, 지금 규칙은 플러그인을 건드리는 모든 PR 이 같은 `plugin.json` 판 줄과
>     같은 CHANGELOG 머리를 고치게 만든다. 지휘 코드가 이미 이 둘을 「에픽이 함께 건드려 겹치기 쉬운 공유 파일」 로 이름 붙이고
>     「버전은 머지 직전에 정한다」 는 우회 규칙을 따로 둔다(RC10) — 규칙이 만든 충돌을 다른 규칙으로 막는 꼴이다.
>     `version` 을 비우면 그 충돌 자리가 구조로 사라지고, CLAUDE.md 가 두려워하는 「silent stale」 은 올림을 잊을 수 없으니
>     일어날 수 없다. 공식 문서가 이 길을 정식으로 적는다(「To let users track commits instead, leave `version` out of both
>     the manifest and the entry」).
>     비용은 레포에 실측돼 있다 — CHANGELOG 판 헤딩 460개(RC11), 문서 전용 올림이 릴리스 노트를 건너뛴 두 건과 그것을 막는
>     366줄 락(RC7), 판 리터럴 핀이 문서 전용 올림마다 stale-red 가 됐다는 테스트 주석(RC12).
>     goal 의 「가벼운 길」 · 「글 줄이기」 기준에서 한 줄 수정에 판 올림과 CHANGELOG 항목이 붙는 의식은 가장 먼저 풀 대상이고,
>     P4(추가보다 푸는 쪽)와 같은 방향이다. CLAUDE.md 가 제3자 설치를 아직 «확인되면» 의 일로 적는 지금(RC2)이 옮기는 값이
>     가장 싼 때다.
> premise_refutation:
>   hits: [P6]
>   why: >-
>     P6 「공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다」 는 「`version` 을 비워 커밋을 따라가게 한다」 갈래에서
>     깨진다(캐시 신선도 한 가지만 유지 · 강화된다).
>     (1) plugins/spec-distill/scripts/conductor_state.py `own_version` · `_check_writer` — `version` 이 문자열이 아니거나 비면
>     `WriterStop("플러그인 판이 비어 있다 … 플러그인을 다시 설치한다")` 로 멈추고, 기계 상태 머리말의 writer 판이 지금 판보다
>     크면 「이 기계 상태는 더 새 판이 썼다 — 플러그인을 업데이트하고 세션을 다시 연다」 로 막는다. 숫자 셋의 대소 비교라
>     커밋 SHA 로는 성립하지 않는다 — 사용자가 받던 「옛 판이 새 판의 상태를 건드리지 못함」 이 사라진다.
>     (2) plugins/spec-distill/scripts/conductor_ledger.py `version_report` — 설치본 `plugin.json` 의 `version` 에서 숫자 셋을
>     못 뽑으면 rc 1 「판을 비교하지 못했다」, 뽑으면 「설치된 … 이 레포 사본 … 보다 옛 판이다 … 플러그인을 갱신하거나 레포
>     사본으로 지휘한다」 를 낸다. 낡은 설치본 경고가 판 순서에 기댄다.
>     (3) shared/deps/check_deps.py `_measure_row` 의 `quality-gates` 갈래가 그 플러그인 `plugin.json` 의 `version` 을 읽고,
>     plugins/spec-distill/dependencies.md 는 「quality-gates | 14.6.0」 을 최소 판으로 둔다 — 판이 없으면 「판을 뽑지 못했다」 다.
>     (4) https://code.claude.com/docs/en/plugins/dependencies — 공식 의존 장치도 같다: 태그는 `<plugin-name>--v<version>` 이고
>     「`<version>` matches the `version` field in that commit's `plugin.json`」, npm · archive · command 소스에서는
>     「a `plugin.json` that sets no version satisfies no constraint」.
>     (5) CLAUDE.md 「호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다」 — 올릴 major 가
>     없어지면 이 일이 하는 이름 바꾸기(S2 · S8)의 깨짐 신호가 사용자에게 가지 않는다.
>     (6) https://code.claude.com/docs/en/plugins/loading — `version` 이 없으면 판은 「The commit SHA of the installed directory」
>     이고 그 문자열이 캐시 폴더 이름이 된다. `claude plugin list` 의 판과 CHANGELOG 헤딩을 잇던 길이 끊긴다.
>     「필수 키를 `name` 하나로」 갈래는 문면만 바꾸면 P6 에 닿지 않는다. 다만 실제로 `version` · `description` 을 빼는 순간
>     (1)–(3)과 소개 문구 동등 락(RC9)이 같은 이유로 걸린다.
> premise_list_challenge: >-
>   결함 셋과 닫힌 경로 하나.
>   (가) P6 은 ST1–ST3 세 항목에 한 문장으로 붙어 있어 이 항목에서는 둘로 갈린다 — 캐시 신선도는 유지되고(오히려 강해지고),
>   순서 있는 판 번호에 기대는 것은 유지되지 않는다. 전제를 「캐시 갱신」 과 「판 순서 · 깨짐 신호」 로 나눠 적어야 판정이 선다.
>   (나) 빠진 전제 — 「공식」 의 층위. trigger 는 「공식은 필수 키를 `name` 하나로 적는다」 만 들었는데, 같은 공식 자료에
>   로더 바닥(`name`) · 검증기 경고선(`version` · `description` · `author`) · Anthropic 자기 플러그인의 관행(넷 다 적음) ·
>   릴리스 방식 둘(「either increase `version` on each release or omit it」)이 함께 있다. 그래서 P3 의 「공식 쪽」 은 이
>   항목에서 방향이 하나가 아니고, 「명시 판 + 릴리스마다 올림」 은 「공식과 다른 자리」 가 아니라 공식이 적은 두 길 중 하나다.
>   devbrew 고유인 것은 「필수」 라는 낱말, 「PR 마다」 라는 단위, CHANGELOG · major 올림 규칙이다.
>   (다) 빠진 전제 — 캐시 사본을 쓰는 사람이 누구인가. CLAUDE.md 는 제3자 설치를 「확인되면」 의 일로 적고, README 는 github
>   소스 등록을 안내한다. 로컬 폴더로 더한 마켓플레이스면 플러그인이 제자리에서 읽혀 판 문자열이 갱신에 아무 일도 하지 않는다
>   (공식 문서). 사용자가 어느 길로 설치해 쓰는지는 이 인터뷰에서 확인되지 않았고, 그 답이 「판 올림이 사용자에게 주던 것」 의
>   크기를 정한다.
>   (라) 닫힌 경로 — 「이 셋은 옮기지 않는다」 는 S10 이 고르지 않았으므로 대안으로 내지 않았다. 다만 `version` 키의 존재와
>   CHANGELOG 판 헤딩 · major 올림 규칙에 한해서는 그 경로(그대로 둔다)가 최선이라 판단한다 — 이유는 위 P6 반증이다.
>   항목 전체를 그대로 두는 것이 최선이라고는 보지 않는다(문면과 올림 단위는 풀 값이 있다).
>   같은 입력을 다시 받은 것은 아니다 — 이 방향의 첫 dispatch 다.
> recommendation: refined
> refined_takes: >-
>   (1) 필수 키 문면을 공식 층위에 맞춘다 — CLAUDE.md 「메타데이터 & 버전 관리」 와 docs/plugin-authoring.md 의 트리 주석에
>   「로더가 요구하는 키는 `name` 하나」 를 적고, `version` · `description` 은 「필수」 가 아니라 devbrew 가 쓰는 이유(코드가 읽는
>   판 · 마켓플레이스 소개 문구 동등 락)와 함께 적는다.
>   (2) 「모든 PR마다」 의무를 푼다 — 기본은 설치본에 복사되는 내용(플러그인 폴더 + 링크로 배송되는 shared 정본)이 바뀌는
>   머지마다 올림이고, 설치본 동작에 닿지 않는 변경은 이유를 적고 건너뛴다. 건너뛴 변경은 캐시 사본에 전달되지 않는다는 것을
>   규칙이 함께 적는다. CHANGELOG 는 「올린 판마다 헤딩」 으로 따라가 지금 락(맨 위 헤딩 == `plugin.json` 판 · 건너뛴 판 없음)과
>   그대로 맞는다.
>   (3) 판을 머지 직전에 정하는 지금의 지휘 관행(RC10)을 규칙 문면으로 올려 병렬 에픽의 충돌 비용을 줄인다.
> refined_drops: >-
>   `version` 을 비워 커밋을 따라가게 하는 것. 필수 키에서 `version` 을 빼는 것(문면이 아니라 실물로). CHANGELOG 판 헤딩 규칙과
>   호출 이름 변경 시 major 올림 규칙을 푸는 것.
> evidence:
>   - url: "https://code.claude.com/docs/en/plugins/loading"
>     supports: both
>     claim: >-
>       「Versions and updates」 · 「How Claude Code computes the version」 원문. 판 계산 순서는 manifest `version` → 마켓플레이스
>       entry `version` → 소스 종류이고, 「Relative path inside a Git-hosted marketplace | The commit SHA of the installed directory」.
>       「a manifest that pins `"version": "1.0.0"` keeps every user on the cached copy until its author changes the string,
>       however many commits they push. To let users track commits instead, leave `version` out of both the manifest and the entry.」
>       「The version also names the plugin's cache directory.」 이전 판 폴더는 `.orphaned_at` 표시 뒤 14일 후 지워진다.
>       자동 갱신 기본값은 공식 마켓플레이스만 켜짐이고 「off for every other marketplace」 다.
>       로컬 경로 마켓플레이스의 상대경로 플러그인은 제자리에서 읽혀 「you don't need to increase the version」.
>       문서는 그 「commit SHA」 가 저장소 HEAD 인지 그 폴더를 마지막으로 건드린 커밋인지 적지 않는다 — HEAD 라면 문서 전용
>       커밋도 네 플러그인 모두의 새 판이 된다(확인 못 함).
>     touches: [P6]
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/host-marketplace"
>     supports: both
>     claim: >-
>       「Release a new version」 원문: 「either increase `version` on each release or omit it」 — 「Bump `version` on each release:
>       users stay on their cached copy until the string changes. If you set `"version": "1.0.0"` and push new commits without
>       changing it, users don't receive them.」 · 「Omit `version`: users track your commits instead.」 공식 문서는 두 길을 나란히
>       적고 어느 쪽도 기본으로 권하지 않는다. 「Don't set `version` in both `plugin.json` and the marketplace entry.」
>       자동 갱신은 「off for your marketplace by default, and `marketplace.json` has no field to turn it on」.
>     touches: [P3]
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
>     supports: both
>     claim: >-
>       「The manifest is optional.」 · 「`name` is the only required key.」 · `version`: 「A version string, not checked against
>       semver. Setting it pins the plugin to that version until you change it」. 같은 페이지의 검증기 절: 「Validation passed with
>       warnings: … a missing `version`, `description`, or `author`. Pass `--strict` to turn warnings into failures in CI」.
>       `name` 하나는 로더의 바닥이고, 경고 없는 선은 `version` · `description` · `author` 를 포함한다.
>     touches: [P3]
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/dependencies"
>     supports: alternative
>     claim: >-
>       공식 의존 장치는 명시 판을 전제한다. 「Tag each release as `<plugin-name>--v<version>`, where `<version>` matches the
>       `version` field in that commit's `plugin.json`.」 `claude plugin tag` 는 「builds the tag name from the plugin's manifest」.
>       npm · archive · command 소스에서는 「a `plugin.json` that sets no version satisfies no constraint」. 상대경로 플러그인은
>       맞는 태그가 없으면 마켓플레이스의 지금 사본을 쓰고 제약은 로드 때 그 사본의 판으로 검사한다.
>     touches: [P6]
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/marketplace-reference"
>     supports: both
>     claim: >-
>       entry `version`: 「When `plugin.json` also sets `version`, `plugin.json` takes precedence and `claude plugin validate`
>       warns.」 검증 메시지 「Entry declares version "x" but <path>/plugin.json says "y". At install time, plugin.json wins」.
>       상대경로 소스는 git · github · file · directory 마켓플레이스에서만 풀린다. `version` 을 비우려면 manifest 와 entry
>       양쪽에서 빼야 한다는 loading 문서와 맞물린다.
>     touches: []
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/agent-sdk-dev/.claude-plugin/plugin.json"
>     supports: alternative
>     claim: >-
>       Anthropic 공식 플러그인의 manifest 원문이 `name` · `description` · `version`("1.0.1") · `author` 넷을 적는다.
>       같은 저장소의 plugin-dev(0.1.2) · code-review(1.0.1)도 판을 적는다 — 이 둘은 요약 모델을 거쳐 확인했다.
>       devbrew 의 필수 셋은 공식 플러그인의 실제 관행과 같은 자리다.
>     touches: [P1]
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/.claude-plugin/marketplace.json"
>     supports: both
>     claim: >-
>       공식 마켓플레이스 entry 가운데 읽은 범위(19만 자 중 앞 10만 자, entry 167개)에서 entry 층위에 `version` 을 적은 것은 7개다.
>       entry 에서 판을 빼는 것은 흔하지만, 위 근거대로 상대경로 플러그인의 `plugin.json` 은 판을 적으므로 「공식 플러그인은 판을
>       비운다」 의 근거는 되지 못한다. 파일 뒷부분은 읽지 못했다.
>     touches: []
>     decides: []
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-structure/SKILL.md"
>     supports: both
>     claim: >-
>       CLAUDE.md 가 새 플러그인 설계의 기본 skill 로 지목한 `plugin-dev:plugin-structure` 는 필수 예시를 `{"name": "plugin-name"}`
>       하나로 들고, 권장 메타데이터에 `version` · `description` 을 넣으며 「Version format: Follow semantic versioning
>       (MAJOR.MINOR.PATCH)」 · 「Version consistently: Update version in plugin.json for releases」 라고 적는다(요약 모델 경유).
>       필수는 `name` 하나, 판은 SemVer 로 릴리스마다 올림 — 두 케이스에 하나씩 닿는다.
>     touches: [P3]
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://raw.githubusercontent.com/obra/superpowers/main/.claude-plugin/plugin.json"
>     supports: alternative
>     claim: >-
>       devbrew 가 의존하는 superpowers 의 manifest 는 `"version": "7.0.2"` 를 명시한다. devbrew 의 `dependencies.md` 가
>       superpowers 최소 판(7.0.0)을 잴 수 있는 것은 상류가 명시 판을 내기 때문이다 — 판을 비운 플러그인은 하류가 최소 판을
>       적을 수 없다.
>     touches: []
>     decides: [OQ11]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     version: {used: "7.0.0 (plugins/spec-distill/dependencies.md, 2026-10-22)", latest: "7.0.2"}
>     certainty: confirmed
>   - url: "https://dev.classmethod.jp/articles/claude-code-plugin-update-not-applied/"
>     supports: both
>     claim: >-
>       실패 사례. `plugin.json` 의 판을 올리지 않아 갱신 명령이 「already at the latest version」 을 내고 옛 동작이 남았다
>       (「`plugin.json` のversionを上げていなかったためキャッシュが効いたままになっていました」). 글쓴이는 고친 길로 판 올림을,
>       다른 길로 `version` 비우기를 들고, 비우면 판이 커밋 해시가 되어 읽을 수 있는 릴리스 신호를 잃으며 릴리스 주기가 정해진
>       플러그인에는 명시 판이 맞다고 적는다. 원안에는 「잊은 올림은 실제로 난다」, 대안에는 「비우기의 값은 릴리스 신호」 로 닿는다.
>     touches: []
>     decides: [OQ11]
>     source_kind: secondary
>     checked_at: "2026-11-14"
>     certainty: confirmed
> repo_claims:
>   - id: RC1
>     path: "CLAUDE.md"
>     anchor: "모든 PR마다 SemVer bump가 붙는 `plugin.json`."
>     claim: >-
>       지금 규칙의 원문. 필수는 `name` · `description` · `version` 이고 올림 이유를 「안 그러면 cache key가 silent stale」 로 적는다.
>       규칙이 댄 이유는 캐시 키 하나이고, 아래 RC3–RC6 이 보이는 「순서 있는 판」 의 쓰임은 규칙 문면에 없다.
>     touches: []
>     decides: [OQ11]
>   - id: RC2
>     path: "CLAUDE.md"
>     anchor: "호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다."
>     claim: >-
>       호출 이름 변경의 깨짐 신호가 major 올림에 실린다. 같은 문단이 이 예외는 「제3자 설치가 확인되면(외부 이슈 · 설치 보고 ·
>       마켓플레이스 공개 등록) 소멸한다」 고 적어 지금은 제3자 설치가 확인되지 않은 상태로 다룬다. `version` 이 없으면 이 규칙이
>       올릴 대상이 없다 — 이 일은 호출 이름 둘을 바꾼다(S2 · S8).
>     touches: [P6]
>     decides: [OQ11]
>   - id: RC3
>     path: "plugins/spec-distill/scripts/conductor_state.py"
>     anchor: "own_version"
>     line: 102
>     claim: >-
>       `own_version()` 은 `.claude-plugin/plugin.json` 의 `version` 을 읽고, 문자열이 아니거나 비면
>       `WriterStop("플러그인 판이 비어 있다: … — 플러그인을 다시 설치한다")` 를 던진다. `_check_writer`(123행)는 기계 상태 머리말의
>       writer 판과 지금 판을 숫자 셋으로 비교해 `wrote > triple` 이면 「이 기계 상태는 더 새 판이 썼다」 로 멈춘다. 기계 상태를 쓸
>       때(247행) `writer: <이름> <판>` 을 찍는다. `version` 을 비우면 지휘자의 기계 상태 쓰기가 멈춘다.
>     touches: [P6]
>     decides: [OQ11]
>   - id: RC4
>     path: "plugins/spec-distill/scripts/conductor_ledger.py"
>     anchor: "version_report"
>     line: 388
>     claim: >-
>       설치본 `plugin.json` 과 레포에 추적되는 같은 이름의 `plugin.json` 의 `version` 을 숫자 셋으로 비교한다. 설치본 판을 못 읽으면
>       rc 1 「판을 비교하지 못했다 — 설치본 판 … 을 읽지 못했다」, 레포 쪽이 크면 rc 1 「설치된 … 이 레포 사본 … 보다 옛 판이다 …
>       플러그인을 갱신하거나 레포 사본으로 지휘한다」. 하위 명령 `version --plugin-json` 으로 노출된다(1425행).
>       plugins/spec-distill/references/conducting.md 14행이 `--plugin-json` 과 「옛 판」 을 담는 것은 grep 으로 확인했고 그 행
>       전문은 읽지 못했다.
>     touches: [P6]
>     decides: [OQ11]
>   - id: RC5
>     path: "shared/deps/check_deps.py"
>     anchor: "_measure_row"
>     line: 250
>     claim: >-
>       `quality-gates` 행의 판은 `<plugin_root>/../quality-gates/.claude-plugin/plugin.json` 의 `version` 에서 잰다. 문자열이 아니거나
>       숫자 셋이 없으면 「quality-gates 의 plugin.json 에서 판을 뽑지 못했다」 를 낸다.
>     touches: [P6]
>     decides: [OQ11]
>   - id: RC6
>     path: "plugins/spec-distill/dependencies.md"
>     anchor: "| quality-gates | 14.6.0 | 2026-10-22 | 알림 |"
>     line: 18
>     claim: >-
>       플러그인 사이 최소 판이 SemVer 로 적혀 있다. 같은 표의 superpowers 행(7.0.0)도 상류의 명시 판에 기댄다.
>     touches: [P6]
>     decides: [OQ11]
>   - id: RC7
>     path: "shared/tests/test_changelog_integrity.sh"
>     anchor: "C2 맨 위 헤딩 버전 == plugin.json 버전."
>     line: 62
>     claim: >-
>       366줄 락이 C1(판 1.0.0 이상이면 CHANGELOG 필수) · C2 · C3(순감소) · C4(헤딩 형식) · C5(건너뛴 판 없음)를 잰다.
>       `plugin.json` 에서 SemVer 를 못 뽑으면 통과가 아니라 RED 다(197–200행 「추출 실패를 '문제 없음'으로 읽지 않는다」).
>       머리 주석(29–37행)은 문서 전용 올림 두 건(project-init 1.7.1 · spec-distill 0.11.1)이 「실제로 배포된 버전인데 릴리스 노트를
>       안 쓴」 경우라고 기록한다. 「PR 마다 올렸는가」 를 PR diff 와 대조하는 검사는 `**/*.{sh,py,js,json}` 의 `bump` 검색 범위에서
>       찾지 못했다 — 올림 의무 자체는 문면 규칙이고 기계 게이트가 아니다.
>     touches: []
>     decides: [OQ11]
>   - id: RC8
>     path: "plugins/plugin-audit/scripts/check-shape-completeness.py"
>     anchor: "plugin_json_fields"
>     line: 44
>     claim: >-
>       plugin-audit 의 모양 점검이 `name` · `version` · `description` 셋이 모두 있고 `version` 이 문자열일 때만 통과로 적는다
>       (출처 칸 「CLAUDE.md §메타데이터」). 같은 플러그인의 check-staleness.py 는 CHANGELOG 최신 헤딩과 `plugin.json` 판이 다르면
>       낡음으로 낸다(269–274행). 필수 키를 실물로 줄이면 이 둘이 함께 바뀐다.
>     touches: []
>     decides: [OQ11]
>   - id: RC9
>     path: "shared/tests/test_plugin_description_parity.sh"
>     anchor: "plugin.json 에 소개 문구가 없다"
>     line: 50
>     claim: >-
>       플러그인마다 `plugin.json` 의 `description` 이 마켓플레이스 entry 의 소개 문구와 글자까지 같아야 하고, `plugin.json` 에
>       소개 문구가 없으면 RED 다. `description` 을 필수에서 실물로 빼면 이 락이 걸린다.
>     touches: []
>     decides: [OQ11]
>   - id: RC10
>     path: "plugins/spec-distill/scripts/repo_defaults.py"
>     anchor: "SHARED_FILES"
>     line: 28
>     claim: >-
>       `SHARED_FILES = ("plugin.json", "CHANGELOG.md", "README.md")` — 주석 「에픽이 함께 건드려 겹치기 쉬운 공유 파일 이름」.
>       plugins/spec-distill/scripts/roadmap_status.py 59행은 이 셋을 경로 예약 겹침 · 위반에서 빼며 「버전은 머지 직전에 정한다(N6)」
>       라고 적는다. conducting.md 는 「공유 파일 · 코퍼스 락이 둘째 PR 에서만 깨지면 둘째 PR 에서 고치고」 를 둔다. 새 코어의 병렬
>       에픽에서 판 줄과 CHANGELOG 머리가 충돌 자리라는 것을 지휘 코드가 이미 안다.
>     touches: []
>     decides: [OQ11]
>   - id: RC11
>     path: "plugins/spec-distill/CHANGELOG.md"
>     anchor: "## [8.13.1] — 2026-10-30"
>     line: 3
>     claim: >-
>       `^## \[` 헤딩 수는 spec-distill 179 · quality-gates 204 · project-init 42 · plugin-audit 35, 합 460 이다. 같은 파일 29행
>       「patch 인 이유 — 링크로 배송하는 `scripts/codex_findings_to_yaml.py`(정본 `shared/codex/`)가 바뀌었다」 는 올림의 실제
>       방아쇠가 「플러그인 폴더」 보다 넓은 「설치본에 복사되는 내용」 임을 보인다.
>     touches: []
>     decides: [OQ11]
>   - id: RC12
>     path: "plugins/spec-distill/tests/test_readme_sync.sh"
>     anchor: "\"플러그인 건드리는 모든 PR은 patch-bump\" 규칙 때문에 리터럴 patch pin은 다음 doc-only"
>     line: 10
>     claim: >-
>       판 리터럴을 핀한 테스트가 문서 전용 올림마다 stale-red 가 된 전례를 주석이 기록하고, 그래서 판 단언을 하한(0.26 이상)으로
>       바꿨다. test_changelog_integrity.sh 45–47행도 같은 전례를 든다. PR 마다 올림이 낳은 반복 비용의 레포 안 기록이다.
>     touches: []
>     decides: [OQ11]
>   - id: RC13
>     path: ".claude-plugin/marketplace.json"
>     anchor: "\"source\": \"./plugins/quality-gates\""
>     line: 12
>     claim: >-
>       네 entry 모두 상대경로 소스이고 entry 층위 `version` 은 없다. 레포 README.md 는 github 소스(`Jeongho-K/devbrew`)로 등록하라고
>       안내한다. 따라서 `plugin.json` 에서 `version` 을 빼면 공식 표의 「Relative path inside a Git-hosted marketplace」 행이 그대로
>       적용된다 — entry 쪽에서 더 지울 것은 없다.
>     touches: []
>     decides: [OQ11]
>   - id: RC14
>     path: "plugins/spec-distill/.claude-plugin/plugin.json"
>     anchor: "\"version\": \"8.13.1\""
>     line: 4
>     claim: >-
>       네 플러그인의 manifest 가 모두 `name` · `description` · `version` · `author` 를 적는다(spec-distill 8.13.1 · quality-gates
>       14.8.1 · project-init 5.4.1 · plugin-audit 1.7.0). 공식 검증기의 경고 없는 선(`version` · `description` · `author`)을 이미 넘는다.
>     touches: []
>     decides: [OQ11]
>   - id: RC15
>     path: "docs/plugin-authoring.md"
>     anchor: "plugin.json           # 필수 — name, version (0.1.0로 시작), description"
>     line: 10
>     claim: >-
>       저술 가이드의 트리 주석이 같은 필수 셋을 적고, 12행은 「CHANGELOG.md # version ≥ v1.0.0이면 필수」 다. 48행은 `plugin-dev` 가
>       주는 것은 문법이고 devbrew 정책은 이 문서가 우선한다고 적는다. 문면을 고칠 자리는 CLAUDE.md 와 이 두 줄이다(P5).
>     touches: [P5]
>     decides: [OQ11]
> # repo root: /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit
> ```

**게이트-전 확인** — repo_claims: RC94–RC108 확인 15/15 · 부착 주장: loading → P6 확인 · host-marketplace → P3 확인 · manifest-reference → P3 확인 · dependencies → P6 확인 · agent-sdk-dev plugin.json → P1 확인 · plugin-structure skill → P3 확인 · 재검토 자격: 열림 6건(P6)

**사용자 선택** — 유지 (S12)

#### ST3 — 환경변수 kill switch 대신 공식 설정만 쓰고 런타임 상태를 공식 데이터 폴더로 옮기는 방향의 반론 검토

**dispatch 입력** — goal: S4 · 전제: P1 「내가 말하는거는 우리 레포에 바이어스 되게 보다 표준에 맞게 가자는거였어」 — 철학 문서를 두고 한 말(S1) · P2 공식 자료는 따라야 할 기준이 아니라 참고 내용이다(S1) · P3 공식과 다른 자리는 공식 쪽으로 옮길 후보로 본다(S6) · P4 「가능하면 추가보다는 푸는 쪽으로 가고」(S1) · P5 저술 가이드는 표준에 맞추는 방향과 새 코어에 맞추는 방향을 함께 적용해 고친다(S1) · P6 공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다(orchestrator 도출) · 제약: S1–S10 원문 전량 · trigger: 기존 사용자 제약과의 충돌 + landscape 모순

> 이 dispatch 는 OQ12 만 다뤘다. 계약(`<claims_contract>`)은 받았다. `id` 는 임시값이다.
>
> ```yaml
> case_for_alternative:
>   statement: "공식 장치를 «대신»이 아니라 «나란히» 둔다 — 환경변수 kill switch 와 프로젝트 안 `.claude/<plugin>/` 상태 자리는 지금 읽는 그대로 두고, 플랫폼이 집행하는 공식 스위치(`enabledPlugins` · `claude plugin disable --scope` · `disableAllHooks`)를 끄는 첫 길로 문서에 올리며, `${CLAUDE_PLUGIN_DATA}` 는 설치물 · 캐시 자리로만 저술 가이드에 들인다."
>   strongest: |
>     goal(S4)은 앞단을 새 코어에 맞추는 일이고 갈래는 넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름 넷이다. 원안의 두 이동은 그 넷 어디에도 서지 않으면서 범위는 가장 크다 — kill switch 변수는 docs 밖 127개 파일 647곳(RC3), 상태 루트는 spec-distill 테스트만 23개 파일 242곳(RC6)이고 무게 중심은 앞단이 아닌 quality-gates · plugin-audit 다. 게다가 `state_path.py` · `control_plane.py` · `conductor_state.py` · 레포의 유일한 훅 `post-tool-use.py` 는 옆 로드맵 R3 예약, CLAUDE.md 는 R2 예약이다(RC9). 새 코어 스스로가 상태를 다시 짜는 중이다 — STATUS.md 는 상태 브랜치의 추적 파일, machine.md 는 「이 기계 캐시로 줄임」(RC10). 지금 상태 자리를 옮기면 새 코어에 맞추는 것이 아니라 새 코어를 앞질러 정하는 것이다.
>     기능으로도 `disableAllHooks` 는 필요한 것보다 많이 끄고 필요한 것은 못 끈다. 공식 문서상 그 설정이 끄는 것은 hook · 사용자 상태줄 · `@` 파일 제안이고 개별 hook 은 못 끈다 — 사용자의 다른 플러그인 hook 과 자기 hook 까지 함께 꺼진다. 반대로 레포에 등록된 훅은 project-init 의 PostToolUse 하나뿐이고(RC1), 환경변수가 실제로 끄는 것은 진입 skill 열 개의 사전 검사(RC2)와 기능 단위 경로다 — 외부 codex 호출 · PR 코멘트 게시 · 「리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다」 는 차등 테스트(RC4) · 훅이 아닌 이름 붙은 자리(RC5). 이 가운데 `disableAllHooks` 가 닿는 것은 훅 하나와 상태줄뿐이다.
>     상태 자리도 같다. `${CLAUDE_PLUGIN_DATA}` 는 `~/.claude/plugins/data/<id>/` — 플러그인 단위이지 프로젝트 단위가 아니고, 플러그인을 마지막 자리에서 지우면 함께 지워지며, Bash 도구로 도는 명령의 환경에는 그 변수가 없고, 샌드박스는 `~/.claude` 의 대부분을 쓰기 거부한다. devbrew 의 상태 작성자는 전부 skill 이 Bash 로 부르는 스크립트이고(RC6 · RC7 · RC8) 상태의 수명은 세션 · 문서 · 로드맵 · 실행 단위다. Anthropic 의 공식 플러그인 plugin-dev 자신이 프로젝트 단위 설정 · 상태의 자리를 프로젝트 안 `.claude/plugin-name.local.md` 로 가르치고, Claude Code 자신이 `CLAUDE_CODE_DISABLE_*` 변수를 쉰 개 넘게 싣고 settings 의 `env` 키로 그것을 나르게 한다 — 지금 두 자리는 「공식과 다른 자리」 라기보다 공식이 쓰는 꼴과 같은 꼴이다.
> case_for_current:
>   strongest: |
>     보안 컨트롤이라면 플랫폼이 집행하는 스위치가 플러그인이 집행하는 스위치보다 강하다. 환경변수 스위치는 읽는 자리마다 읽어 줘야 듣는다 — 레포의 정본 모듈이 그 실패를 실측으로 적는다: 같은 책임이 열두 곳에 따로 살았고 한 곳은 `DEVBREW_SKIP_HOOKS` 를 「아예 읽지 않았다」, 「사용자가 껐다고 믿는 스위치가 어떤 지점에서는 무반응이었다」, 그 결함의 방향은 「언제나 fail-open」(RC3). README 에는 은퇴한 토큰의 묘지가 있고 그중 하나는 「이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다」 다(RC5). `disableAllHooks` 와 플러그인 끄기는 플러그인 코드 밖에서 집행돼 훅 스크립트가 깨져도 듣고, settings 파일 편집은 재시작 없이 도는 세션에 반영된다 — 환경변수는 「전부 세션 스코프 env var 라 재시작이 필요하다」(RC5).
>     잃는 것도 작다. 레포 전체에 등록된 훅이 하나라(RC1) 「개별 hook 끄기가 사라진다」 는 훅 하나의 이야기이고, 사용자는 그 손실을 선택지 설명에서 읽고 골랐다(S10). 얻는 것은 goal 의 「글 줄이기」 와 P4(푸는 쪽)에 바로 선다 — 앞단 skill 본문의 스위치 서술(request-framing 11곳 · pm-interview 9곳 · reviewing-brief 12곳 · spec-distill README 21줄), 플러그인마다 실린 판정 모듈 사본, 그것을 지키는 테스트가 걷힌다.
>     상태 자리는 프로젝트 안에 두기 때문에 생긴 장치가 통째로 사라진다 — 스스로 `.gitignore` 를 쓰고 추적 파일을 탐침하고 링크를 거부하고 worktree 에서 메인 레포를 찾아가는 코드(RC6), `.claude` 가 제자리의 실제 디렉토리인지 삭제 전에 재는 가드(RC7). 리뷰 대상 레포의 내용은 비신뢰 입력인데 상태 폴더가 그 트리 안에 있어서 필요한 방어다. 사용자 홈의 데이터 폴더는 그 트리 밖이라 링크 심기와 git 오염이 구조적으로 없고, worktree 가 사라져도 남으며, 공식 hooks 문서는 그 폴더를 「for dependencies and state that should survive plugin updates」 라고 적는다 — 상태는 용도 안이다.
> premise_refutation:
>   hits: [P6]
>   why: |
>     P6 「공식 장치로 옮겨도 지금 장치가 사용자에게 주던 것이 유지된다」 는 kill switch 쪽과 상태 쪽 둘 다에서 근거와 충돌한다.
>     (kill switch) https://code.claude.com/docs/en/hooks 「Disable or remove hooks」 는 「There is no way to disable an individual hook while keeping it in the configuration.」 이라 적고, https://code.claude.com/docs/en/settings-reference 의 `disableAllHooks` 행은 그 설정이 끄는 것을 「hooks, a custom status line, and a custom `@` file suggestion command」 로 적는다 — skill 은 닿지 않는다. 지금 장치가 주는 것은 `shared/entry/entry_preflight.py#sentinel` 이 진입 skill 을 `DEVBREW_<PLUGIN>_DISABLE=1` 로 끄는 것(RC2)과 기능 단위 스위치(RC4) · 훅이 아닌 이름 붙은 자리(RC5)다. 「disableAllHooks 만」 으로 가면 이 셋이 유지되지 않는다. S10 선택지 설명이 알린 손실은 「개별 hook 끄기가 사라진다」 하나였고 이 셋은 알리지 않았다.
>     (상태) https://code.claude.com/docs/en/plugins/manifest-reference 「Environment variables」 는 `${CLAUDE_PLUGIN_DATA}` 를 `~/.claude/plugins/data/<id>/` 로 풀고 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent.」 이라 적는다. https://code.claude.com/docs/en/plugins/cli-reference 는 마지막 자리에서 uninstall 하면 「its data directory, `~/.claude/plugins/data/<id>/`」 를 지운다고 적는다. https://code.claude.com/docs/en/sandboxing 「Protected paths」 는 `~/.claude` 를 「most of its contents」 쓰기 거부로 적고 `allowWrite` 로도 풀리지 않는다고 적는다. 지금 장치가 주는 것은 프로젝트 · 문서 · 로드맵 · 실행 단위의 수명(CLAUDE.md 「런타임 상태 & 훅」 — plugin-audit 실행 폴더는 「지우지 않는다」), Bash 로 도는 스크립트가 권한 없이 쓰는 자리(RC6 · RC7 · RC8)다. 플러그인 단위 · uninstall 때 삭제 · Bash 환경에 없음 · 샌드박스 쓰기 거부는 그것이 유지되지 않음을 뜻한다.
> premise_list_challenge: |
>   결함이 여섯 있다.
>   1. 빠진 전제 — 「devbrew 의 kill switch 가 끄는 것은 hook 이다」. 방향 문장과 조사 3 의 「hook 을 끄는 공식 수단은 `disableAllHooks` 설정뿐이다」 는 이 전제 위에 서 있는데 레포에서는 거짓이다. 등록된 훅은 하나이고(RC1) 스위치의 수신처 대부분은 진입 skill 과 스크립트 경로다. 조사 3 의 문장은 hook 에 대해서만 맞다.
>   2. 빠진 전제 — 「이 두 자리는 공식과 다른 자리다」. 비교 대상이 같은 종류가 아니다. `${CLAUDE_PLUGIN_DATA}` 는 플러그인 단위 자리이고 레포의 상태는 프로젝트 단위다. 프로젝트 단위 플러그인 상태에 대해 Anthropic 의 plugin-dev 는 프로젝트 안 `.claude/plugin-name.local.md` 를 가르친다. 환경변수 스위치도 공식 제품이 쓰는 꼴이다(`CLAUDE_CODE_DISABLE_*` · settings `env`). P3 의 「후보」 자격 자체가 약하다.
>   3. P6 은 orchestrator 가 도출한 전제인데, S10 선택지 설명이 이미 「개별 hook 끄기가 사라진다」 고 알렸다 — 사용자는 P6 이 통째로 참이라고 듣고 고른 것이 아니다. 받아들인 손실은 그 하나이고, 위 hits 가 적은 나머지 손실은 사용자가 보지 못했다.
>   4. 방향이 서로 기대지 않는 결정 둘(kill switch · 상태 자리)을 한 문장에 묶었다. 근거의 세기가 다르다 — 상태 쪽이 더 단단히 반증된다. 사용자에게는 둘로 갈라 묻는 것이 맞다.
>   5. 방향이 「공식 설정」 을 `disableAllHooks` 하나로 좁혔다. 공식에는 그 밖에 플러그인 단위 끄기(`enabledPlugins` · `claude plugin disable <plugin> --scope local` — 「turns off a project-enabled plugin for you alone」), skill 단위 거부 규칙(`Skill(name)`), 한 번 실행만 덮는 `--settings`, 플러그인 사용자 옵션 `userConfig` 가 있다. `DEVBREW_<PLUGIN>_DISABLE=1` 의 공식 대응물은 `disableAllHooks` 가 아니라 플러그인 끄기다. 다만 `userConfig` 로 기능 단위 스위치를 옮기는 길은 새 장치를 짓는 일이라 P4(푸는 쪽)와 반대 방향이고 이번에 대안으로 내지 않았다.
>   6. 범위가 모호하다. 방향 문장은 두 꼴(`DEVBREW_<PLUGIN>_DISABLE=1` · `DEVBREW_SKIP_HOOKS`)만 이름 붙였는데 레포에는 기능 단위 변수(`…_DISABLE_CODEX` · `…_DISABLE_WEB` · `…_DISABLE_PUBLISH` · `…_DISABLE_DIFFERENTIAL_TEST` 등)가 따로 있다. 「환경변수 kill switch 대신」 이 이것까지 뜻하는지 전제 목록이 말하지 않는다.
>   덧붙임 둘. S10 에서 고르지 않은 「이 셋은 옮기지 않는다」 를 그대로 대안으로 내지 않았다(규칙 9) — 낸 대안은 공식 장치를 나란히 들이는 것이라 그 선택지와 다르다. 다만 상태 자리 절반에 한해서는 근거가 가리키는 최선이 「옮기지 않는다」 와 사실상 같다는 것을 숨기지 않는다. 그리고 goal(S4)은 앞단을 재는 기준이라 quality-gates · plugin-audit 에 무게가 실린 이 방향을 약하게만 가른다 — 네 갈래와의 거리, 옆 로드맵 예약과의 겹침으로 쟀다. 같은 입력을 다시 받았다는 느낌은 없다(ST3 첫 dispatch).
> recommendation: refined
> refined_takes: |
>   「공식 쪽으로」 라는 방향과, 플랫폼이 집행하는 스위치를 끄는 첫 길로 올리는 것. 플러그인 전체 끄기는 `enabledPlugins` / `claude plugin disable <plugin> --scope local`, 훅 전부 끄기는 `disableAllHooks`(한 번 실행만이면 `--settings`)를 CLAUDE.md 「런타임 상태 & 훅」 과 각 README 에 적는다 — 플러그인 코드가 깨져도 듣고 재시작 없이 반영되는 길이다. `${CLAUDE_PLUGIN_DATA}` 는 저술 가이드에 플러그인 단위 설치물 · 캐시의 자리로 들인다(지금 저술 가이드와 CLAUDE.md 에는 언급이 0건이다). 새 코어가 machine.md 를 「이 기계 캐시」 로 줄이면 그 파일의 자리는 R3 가 이 구분으로 정한다.
> refined_drops: |
>   「disableAllHooks 만」 — 환경변수 스위치의 제거. `DEVBREW_<PLUGIN>_DISABLE` · `DEVBREW_SKIP_HOOKS` · 기능 단위 변수는 지금 읽는 그대로 읽는다(공식 장치가 닿지 않는 자리: 진입 skill 사전 검사 · 훅이 아닌 이름 붙은 자리 · codex · 게시 · 차등 테스트). CLAUDE.md 의 「kill switch는 보안 컨트롤」 조항 삭제. 세션 · 문서 · 로드맵 · 실행 단위 상태를 `${CLAUDE_PLUGIN_DATA}` 로 옮기는 것.
> evidence:
>   - url: "https://code.claude.com/docs/en/hooks"
>     supports: both
>     claim: "「Disable or remove hooks」 — 「To temporarily disable all hooks without removing them, set `\"disableAllHooks\": true` in your settings file.」 · 「There is no way to disable an individual hook while keeping it in the configuration.」 · 한 번 실행만은 `--settings '{\"disableAllHooks\": true}'` · 관리 설정으로 배포된 hook 은 사용자 · 프로젝트 · 로컬의 `disableAllHooks` 로 못 끈다. 원안 쪽 — 플랫폼이 집행하는 끄기가 실재한다. 대안 쪽 — 개별 끄기가 없고 전부를 끈다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/hooks"
>     supports: current
>     claim: "「Reference scripts by path」 — `${CLAUDE_PLUGIN_DATA}`: 「the plugin's persistent data directory, for dependencies and state that should survive plugin updates.」 hooks 문서는 그 폴더의 용도에 state 를 넣는다. hook 프로세스에는 `CLAUDE_PROJECT_DIR` · `CLAUDE_PLUGIN_ROOT` · `CLAUDE_PLUGIN_DATA` 가 환경변수로 실린다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/manifest-reference"
>     supports: alternative
>     claim: "「Environment variables」 — `${CLAUDE_PLUGIN_DATA}` 는 「`~/.claude/plugins/data/<id>/`, created on first reference and kept across plugin updates」, 용도 칸은 「Installed dependencies such as `node_modules`, generated code, and caches」. 「By default, Claude Code deletes the `${CLAUDE_PLUGIN_DATA}` directory when you uninstall the plugin from the last place it's installed.」 「The variables aren't present in the environment of commands Claude runs through the Bash tool, in the main session or in a subagent.」 — skill 본문에서는 `${...}` 를 인라인으로 치환받아야 한다. 플러그인 단위 자리이고 프로젝트를 가르는 성분이 없다. (옛 주소 `/docs/en/plugins-reference` 로 받아 이 페이지 전문을 읽었다.)"
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/plugins/cli-reference"
>     supports: both
>     claim: "uninstall — 「When you uninstall a plugin from the last scope it's installed at, Claude Code also deletes the plugin's stored options and secrets and its data directory, `~/.claude/plugins/data/<id>/`.」 예외는 `--keep-data` 등 셋. disable — 「`claude plugin disable formatter --scope local` turns off a project-enabled plugin for you alone」. 대안 쪽 — 데이터 폴더의 상태는 플러그인 삭제와 함께 사라진다. 원안 쪽 — 플러그인 단위 · 프로젝트 단위로 끄는 공식 스위치가 있다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/settings-reference"
>     supports: both
>     claim: "색인 행 — `disableAllHooks`: 「Turn off hooks, a custom status line, and a custom `@` file suggestion command at once.」 · `enabledPlugins`: 「Turn individual plugins on or off per scope.」 · `env`: 「Set environment variables for every session and its subprocesses.」 셋 다 Scope 는 Any file. `disableAllHooks` 는 skill 을 끄지 않고 사용자 상태줄까지 끈다. `env` 키는 환경변수 스위치를 공식 설정 파일로 나르는 길이다. 각 키의 본문 항목은 페이지가 길어 읽지 못했다 — 색인 행만 확인했다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://code.claude.com/docs/en/settings"
>     supports: current
>     claim: "「Claude Code watches your settings files and reloads them when they change, so it applies most edits to the running session without a restart, including edits to `permissions`, `hooks`」 · `--settings` 는 그 세션에만 적용되고 프로젝트 · 사용자 파일 위에 선다 · 「Environment variables aren't a level in this stack.」 설정 파일 기반 스위치는 도는 세션에 반영되고 범위(사용자 · 프로젝트 · 로컬 · 관리)를 갖는다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/skills"
>     supports: both
>     claim: "「Plugin skills are not affected by `skillOverrides`. Manage those through `/plugin` instead.」 · skill 단위 차단은 권한 거부 규칙 `Skill(name)` · `${CLAUDE_PLUGIN_DATA}` 는 「Substituted only in plugin skills. Use this to reference installed dependencies, generated files, or caches that must outlive an update.」 플러그인 skill 을 끄는 공식 길은 플러그인 끄기와 거부 규칙이고 `disableAllHooks` 는 이 페이지의 skill 끄기 수단에 없다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://code.claude.com/docs/en/sandboxing"
>     supports: alternative
>     claim: "기본 쓰기 — 「read and write access to the current working directory and its subdirectories, any directories you've added …, plus the per-user temp directory」. 「Protected paths」 — 「In `~/.claude`, or the directory `CLAUDE_CONFIG_DIR` points to: most of its contents」, 「If you add an `allowWrite` entry or an `Edit` allow rule that covers one of these paths, the protection still applies.」 「The sandbox covers shell commands only. Claude's file tools, MCP servers, and hooks run outside it.」 데이터 폴더는 샌드박스 밖에서 도는 hook · MCP 프로세스에는 열려 있고 Bash 로 도는 스크립트에는 기본으로 닫혀 있다. `~/.claude/plugins/data` 가 「most」 의 예외인지는 이 페이지가 적지 않는다."
>     touches: [P6]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: uncertain
>   - url: "https://code.claude.com/docs/en/env-vars"
>     supports: alternative
>     claim: "Claude Code 자신이 끄기 스위치를 환경변수로 싣는다 — 읽은 범위(앞 10만 자)에서 이름에 DISABLE 이 든 변수가 54개다(`CLAUDE_CODE_DISABLE_WEB_FETCH` · `CLAUDE_CODE_DISABLE_AUTO_MEMORY` 등, 하한). 「Add variables under the `env` key in a `settings.json` file」. 환경변수 kill switch 는 공식 제품의 관례와 같은 꼴이다."
>     touches: [P3]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-settings/SKILL.md"
>     supports: alternative
>     claim: "Anthropic 의 plugin-dev 플러그인이 가르치는 자리 — 「Plugins can store user-configurable settings and state in `.claude/plugin-name.local.md` files within the project directory.」 · 「Purpose: Per-project plugin configuration and state」 · 「Lifecycle: User-managed (not in git, should be in `.gitignore`)」 · 「Pattern 1: Temporarily Active Hooks」 는 그 파일의 `enabled` 값으로 hook 이 스스로 빠져나가게 한다. 프로젝트 단위 플러그인 상태를 프로젝트의 `.claude/` 아래에 두는 것과 hook 이 자기 스위치를 스스로 읽는 것 둘 다 공식 플러그인의 관례다. 조사 3 은 plugin-dev 가 공식 문서와 어긋나는 자리가 있다고 적었다 — 이것은 문서가 아니라 공식 플러그인의 서술이다."
>     touches: [P3]
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
>   - url: "https://pre-commit.com/"
>     supports: alternative
>     claim: "「pre-commit solves this by querying a `SKIP` environment variable.」 · 「The `SKIP` environment variable is a comma separated list of hook ids.」 · 「This allows you to skip a single hook instead of `--no-verify`ing the entire commit.」 `DEVBREW_SKIP_HOOKS` 와 같은 꼴(콤마 구분 hook id · 환경변수)의 선행 사례이고, 전부 끄기만 있는 것의 결함을 이유로 든다. 사용자는 맞출 표준으로 일반 개발 관례를 고르지 않았다(S1) — 표준 근거가 아니라 선행 사례로만 쓴다."
>     touches: []
>     decides: [OQ12]
>     source_kind: primary
>     checked_at: "2026-11-14"
>     certainty: confirmed
> repo_claims:
>   - id: RC1
>     path: "plugins/project-init/hooks/hooks.json"
>     anchor: "\"PostToolUse\""
>     line: 4
>     claim: "레포에 등록된 훅은 이것 하나다. `plugins/*/hooks/**` 는 이 파일과 `post-tool-use.py` 둘뿐이고 플러그인 넷의 `.claude-plugin/plugin.json` 에 `hooks` 키가 없다. 그 훅은 `post-tool-use.py#main` 첫 줄에서 `kill_switch_active(\"project-init\", \"post-tool-use\", \"PostToolUse\")` 를 읽는다(609행). 「개별 hook 끄기」 가 가르는 대상은 훅 하나다."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC2
>     path: "shared/entry/entry_preflight.py"
>     anchor: "sentinel"
>     line: 44
>     claim: "진입 skill 사전 검사는 `DEVBREW_<PLUGIN>_DISABLE` 값이 정확히 `1` 이면 `[devbrew-entry] disabled …` 줄을 내고 skill 을 세운다(50–51행). 수신처가 hook 이 아니라 skill 이라 `disableAllHooks` 가 닿지 않는다. `DEVBREW_SKIP_HOOKS` 는 진입에 걸리지 않는다 — `shared/tests/test_entry_preflight.sh` 74–75행이 그것을, 63–71행이 변수명 도출이 정본과 같음을 락으로 지킨다. 세 플러그인의 `scripts/entry_preflight.py` 는 이 파일을 가리키는 링크다(같은 테스트 20–29행)."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC3
>     path: "shared/killswitch/kill_switch_active.py"
>     anchor: "kill_switch_active"
>     line: 29
>     claim: "판정 정본이다. 머리말이 실측을 적는다 — 같은 책임이 「열두 곳」 에 따로 살았고 한 곳은 `DEVBREW_SKIP_HOOKS` 를 「아예 읽지 않았다」, 「사용자가 껐다고 믿는 스위치가 어떤 지점에서는 무반응이었다」, 그 결함의 방향은 「언제나 fail-open」(3–13행). 전역 변수명은 열거하지 않고 도출한다(46행). 플러그인이 스스로 집행하는 스위치의 약점(원안 쪽 근거)이자 그 약점을 이미 한 정본으로 모았다는 사실(대안 쪽 근거)이다. 이 두 변수 이름은 docs 밖에서 127개 파일 647곳에 나온다(Grep 계수 — 숨김 폴더 · 링크를 건너뛰므로 하한). 그중 앞단 skill 본문은 request-framing 11 · pm-interview 9 · reviewing-brief 12곳이다."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC4
>     path: "plugins/quality-gates/README.md"
>     anchor: "`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | ② 차등 테스트를 통째로 건너뛴다(리뷰 대상 저장소의 코드를 호스트 권한으로 돌리지 않는다)"
>     line: 477
>     claim: "기능 단위 스위치는 hook 이 아닌 자리에서 집행된다 — 차등 테스트(`run-test-selection.sh` · `e2e-state.sh`), 외부 codex 호출(469행, `detect_codex.sh`), PR 코멘트 게시(487행, sink `publish-comment.sh` 의 첫 검사 — gh 호출 0), 보안 리뷰어(470행). quality-gates 에는 등록된 훅이 없다(RC1). 공식 설정 가운데 이것들을 하나씩 끄는 것은 없다."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC5
>     path: "plugins/spec-distill/README.md"
>     anchor: "`DEVBREW_SKIP_HOOKS=spec-distill:review-entry` — 같은 효과의 이름 붙은 스위치."
>     line: 294
>     claim: "spec-distill 의 `DEVBREW_SKIP_HOOKS` 토큰은 전부 훅이 아닌 자리를 끈다 — `review-entry`(294행 「훅이 아니지만 지목할 이름을 갖는다」), `statusline`(288행), 원장 정리(295행 「설치되는 훅은 없다」). 282행은 환경변수 스위치의 한계를 적는다 — 「전부 세션 스코프 env var 라 재시작이 필요하다」. 320행은 은퇴한 토큰이 조용히 뜻을 잃은 사례다 — 「이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다」."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC6
>     path: "plugins/spec-distill/scripts/state_path.py"
>     anchor: "ensure_state_root"
>     line: 138
>     claim: "상태 루트는 cwd 가 worktree 여도 `<메인 레포>/.claude/spec-distill` 이다(`state_root` 98행 · `state_root_for_common` 73행). 프로젝트 안에 두기 때문에 드는 장치가 여기 있다 — `*` 한 줄 `.gitignore` 를 링크를 따르지 않고 쓰기(`_write_ignore` 120행), 무시되는지 · 추적 파일이 없는지 탐침하고 아니면 exit 3(`_check_state_root` 161–207행), 링크 성분 거부(`inside_root` 251행). 이 스크립트는 skill 이 Bash 로 부르는 CLI 라 `CLAUDE_PLUGIN_DATA` 환경변수를 받지 못한다. spec-distill 테스트 23개 파일 242곳이 이 자리를 가리킨다(Grep 계수 — `test_state_root.sh` 71 · `test_ledger_root.sh` 48 · `test_ledger_wiring.sh` 40 등, 본문은 읽지 않았다)."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC7
>     path: "plugins/quality-gates/scripts/setup-qg.sh"
>     anchor: "STATE_ROOT=\".claude/quality-gates\""
>     line: 194
>     claim: "qg 세션 폴더는 리포 최상위의 `.claude/quality-gates/<session-id>/` 다(188–201행). `.claude` 나 상태 루트가 제자리의 실제 디렉토리가 아니면 지우지도 쓰지도 않는다(`root_escapes` 213–223 · 255–256행). 같은 루트 아래 `worktrees/` 에 기준선 · HEAD 축의 git worktree 가 선다(`qg-worktree.sh` 50행). 리뷰 대상 레포와 한 묶음으로 사는 상태다."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC8
>     path: "plugins/plugin-audit/scripts/prepare-run-dir.py"
>     anchor: "<repo-root>/.claude/plugin-audit/<date>-<target>[-N]/ 을 os.mkdir 로 원자적으로 만들고"
>     line: 4
>     claim: "plugin-audit 실행 폴더는 넘겨받은 `--repo-root`(기본 cwd) 아래에 서고 기존 폴더를 덮거나 비우지 않는다(4–6 · 57행). CLAUDE.md 「런타임 상태 & 훅」 은 이 수명을 「실행 단위 산출(plugin-audit 실행 폴더 — 지우지 않는다)」 로 적는다. 플러그인을 지울 때 함께 지워지는 데이터 폴더의 수명과 맞지 않는다."
>     touches: [P6]
>     decides: [OQ12]
>   - id: RC9
>     path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md"
>     anchor: "### R3 — 지휘자 상태 브랜치 · 편지함"
>     line: 50
>     claim: "R3 의 경로 예약(56행)에 `conductor_state.py` · `control_plane.py` · `state_path.py` · `plugins/project-init/hooks/post-tool-use.py` 가 있다 — 상태 루트를 정하는 구현과 레포의 유일한 훅이 옆 로드맵 몫이다. CLAUDE.md 는 R2 예약이다(44행). 원안은 이 예약 파일 다섯을 모두 고쳐야 한다."
>     touches: []
>     decides: [OQ12]
>   - id: RC10
>     path: "docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R3.md"
>     anchor: "**D18** — STATUS.md 는 스크립트가 계산해 쓰는 추적 파일로, 로드맵 지휘자의 코드 없는 상태 브랜치에 두고 main 에 머지하지 않는다"
>     line: 47
>     claim: "새 코어는 상태 자리를 스스로 다시 정했다 — 현황은 git 의 추적 파일(D18), 사용자 선택 원문은 「machine.md 는 이 기계 캐시로 줄임」(130행), 근거 줄은 「지휘 기계 상태는 이 기계에서만 뜻이 있다」(70행). 상태를 레포 쪽(추적 파일)으로 당기는 방향이고, 남는 machine.md 만 캐시 성격이다 — 공식 데이터 폴더의 용도(캐시)에 맞는 유일한 후보이며 그 파일은 R3 몫이다."
>     touches: []
>     decides: [OQ12]
>   - id: RC11
>     path: "plugins/plugin-audit/scripts/check-shape-completeness.py"
>     anchor: "_hooks_killswitch_present"
>     line: 136
>     claim: "plugin-audit 가 CLAUDE.md 의 「모든 훅에 kill switch」 를 감사 기준으로 기계 집행한다 — 대상 플러그인의 등록된 훅 스크립트가 자기 이름의 스위치(`DEVBREW_SKIP_HOOKS` 또는 `kill_switch_active(\"<own>\"`)를 읽는지 본다(177–187행). 훅이 없으면 요건도 없다(149행). 원안은 이 감사 기준과 그 테스트(`test_check_shape_completeness.py`)의 삭제를 함께 뜻한다."
>     touches: []
>     decides: [OQ12]
>   - id: RC12
>     path: "plugins/spec-distill/references/docreview-profiles/brief.md"
>     anchor: "- Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다."
>     line: 74
>     claim: "앞단의 brief 리뷰 프로필이 kill switch 를 Law 셋과 같은 줄에서 「안 자른다」 로 보호한다. 원안을 따르면 이 인터뷰가 내는 brief 자체가 자기 리뷰 프로필의 보호 조항과 부딪힌다 — 이 프로필 줄도 함께 고쳐야 하고, CLAUDE.md 는 persona 약화를 보안 리뷰 대상으로 적는다."
>     touches: []
>     decides: [OQ12]
>   - id: RC13
>     path: "CLAUDE.md"
>     anchor: "kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다."
>     claim: "레포 규칙은 kill switch 이름의 은퇴를 금지하지 않고 공시를 조건으로 허용한다. 「런타임 상태 & 훅」 은 「모든 훅에 kill switch. 진입 skill 도 같다.」 와 「어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤.」 을 적는다. 원안은 규칙 위반이 아니라 규칙 개정이고(S6 이 연 범위), 개정 대상 문장은 이 둘과 상태 수명 넷을 적은 문단이다. `CLAUDE_PLUGIN_DATA` · `disableAllHooks` 는 레포에서 인터뷰 상태 파일 둘에만 나온다(Grep — 하한)."
>     touches: []
>     decides: [OQ12]
> ```
>
> 읽은 자리(절대경로):
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md` — 1–448행, 조사 3 의 678–727 · 940–979행, 조사 5 · 6 과 R3 블록 1456–1561행
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md` — 전문(S1)
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/killswitch/kill_switch_active.py` — 전문
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/entry/entry_preflight.py` — 전문
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/shared/tests/test_entry_preflight.sh` — 전문
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/spec-distill/scripts/state_path.py` — 전문
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/project-init/hooks/hooks.json` — 전문, `post-tool-use.py` 는 kill switch 줄만
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/quality-gates/scripts/setup-qg.sh` — 185–279행
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/plugins/plugin-audit/scripts/prepare-run-dir.py` — 1–60행
> - `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/framing-interview-constraint-audit/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md` · `R3.md` — Grep 으로 맞은 줄만
> - README 넷 · SKILL.md · `check-shape-completeness.py` · `brief.md` · 철학 문서 — Grep 으로 맞은 줄만
>
> 확인하지 못한 것:
> - `settings-reference` 의 `disableAllHooks` · `enabledPlugins` 본문 항목(색인 행만 읽었다) — 플러그인이 실은 hook 이 `disableAllHooks` 에 드는지는 hooks 문서의 「all hooks」 로만 읽었다.
> - `enabledPlugins` 를 `--settings` 로 한 번 실행에만 덮을 수 있는지.
> - `~/.claude/plugins/data` 가 샌드박스 보호 경로의 예외인지(문서는 「most of its contents」 까지만 적는다).
> - 실제 CLI 에서의 동작 — 전부 문서 대조이고 실측하지 않았다(이 agent 에 실행 도구가 없다).
> - spec-distill 상태 루트를 가리키는 테스트 23개 파일의 본문.
>
> Sources:
> - [Claude Code — hooks](https://code.claude.com/docs/en/hooks)
> - [Claude Code — plugin manifest reference](https://code.claude.com/docs/en/plugins/manifest-reference)
> - [Claude Code — plugin commands reference](https://code.claude.com/docs/en/plugins/cli-reference)
> - [Claude Code — settings reference](https://code.claude.com/docs/en/settings-reference)
> - [Claude Code — settings files and precedence](https://code.claude.com/docs/en/settings)
> - [Claude Code — skills](https://code.claude.com/docs/en/skills)
> - [Claude Code — sandboxing](https://code.claude.com/docs/en/sandboxing)
> - [Claude Code — environment variables](https://code.claude.com/docs/en/env-vars)
> - [anthropics/claude-plugins-official — plugin-dev plugin-settings skill](https://raw.githubusercontent.com/anthropics/claude-plugins-official/main/plugins/plugin-dev/skills/plugin-settings/SKILL.md)
> - [pre-commit — Temporarily disabling hooks](https://pre-commit.com/)

**게이트-전 확인** — repo_claims: RC109–RC121 확인 13/13 · 부착 주장: hooks(끄기) → P6 확인 · hooks(데이터 폴더 용도) → P6 확인 · manifest-reference → P6 확인 · cli-reference → P6 확인 · settings-reference → P6 확인 · plugin-dev plugin-settings → P3 확인 · settings · skills · sandboxing · env-vars → 확인 못 함(세지 않음) · 재검토 자격: 열림 4건(P6)

**사용자 선택** — 유지 (S13) — builder · orchestrator 추천(보완)과 다른 선택이다

## 4. 게이트 실행 기록

- check_brief.py gate — pass (2026-11-15) — web: enabled
- check_verbatim_coverage.py — exit 0 (2026-11-15)

## 5. 프로세스 로그

- round 1: path (a · b) — 옆 로드맵 다시 읽기 · 범위 조사 첫 dispatch · 이름 바꾸기의 대상 · 의도 폴더 쓰기 · 이 일의 중심
- round 2: path (a · b) — 공식 문서 대조 · 끝났을 때 참이어야 할 것 · 공식과 다른 자리의 처분 · 인터뷰의 새 이름
- round 3: path (a · b) — 인터뷰 둘로 나누기 · 공식 쪽으로 옮길 항목 고르기 → 반론 검토 셋과 숨은 가정 조사를 함께 띄움
- round 4: path (b) — steelman ST1 게이트(유지)
- round 5: path (b) — steelman ST2 게이트(유지)
- round 6: path (b) — steelman ST3 게이트(유지)
- round 7: path (a · b) — 공식 설정이 닿지 않는 스위치 · 옮긴 상태가 지킬 것 · S3 재확인 · 낱말 바로잡기
- round 8: path (a · b · d) — 판 올림 재검토 · 숨은 가정의 처분 · 가벼운 길과 구조 검사 · 덩어리 승인 화면
- round 9: path (b) — 철학 문서의 범위 · 레포 주장의 처분 · 열린 질문 목록 → 포화 판정 1
- round 10: path (a) — 빈 곳 넷 조사(질문 없음) → 포화 판정 2
- round 11: path (a · b) — 빈 곳 다섯 조사 · 샌드박스에서의 상태 자리 · 끝맺음 절차 파일의 주인 · 열린 질문 둘 추가 → 포화 판정 3
- round 12: path (b) — 반복 빈 곳의 처분(사용자 판단 포화) → 분해 판단(나눔 · 에픽 여덟 승인)
- 분해안의 배정 번호 계산을 승인 뒤에 한 곳 고쳤다 — 링크로 실리는 파일 수를 적은 근거(RC157)를 실측 · 이전 에픽에서 규칙 개정 에픽으로 옮겼다. 에픽의 수 · 범위 · 의존은 승인된 그대로다.
- 재지 못한 것: 샌드박스를 켠 세션에서 공식 데이터 폴더 쓰기 — 별도 세션을 띄우는 실측을 이 세션의 권한 판정이 거절했다. 우회하지 않았고 실측은 에픽 P1 로 넘겼다.
- 옆 세션(옆 로드맵의 리더)과 주고받은 것은 세션 메시지이고 사용자 말이 아니다 — 받은 내용은 본체가 문서 · PR 로 확인한 것만 근거로 썼다.
- brief 에 실은 레포 근거는 71건이다(미확인 1건은 표시). 나머지 대조 줄은 아래에 그대로 있고 미확인은 표시돼 있다.
- 리뷰 1라운드 뒤 확정 후보의 번호 여섯을 바꿨다(C3–C6 · C13 · C23 → D3–D6 · D13 · D23 — 고른 선택지 문장이라 출처 표기를 「선택」 으로 고쳤다). 리뷰 결정으로 항목 셋(C33 · D34 · D35) · 위험 하나(K23) · 근거 둘(RC11 · RC138)을 더했다.
- 리뷰 2라운드 뒤 확정 후보의 번호 넷을 더 바꿨다(C1 · C2 · C7 · C8 → D1 · D2 · D7 · D8 — Phase 0 이 쓴 문장을 사용자가 고른 것이라 「선택」 으로 고쳤다). 항목 다섯(C36 · C37 · C38 · D39 · D40)을 더했다 — C33 을 친 말과 고른 선택지로 갈랐다.
- 리뷰 3라운드 뒤 분해안 표의 낱말 한 곳을 승인 뒤에 고쳤다 — 「앞단의 끝」 에픽의 의도 문장 머리 「인터뷰의 끝이」 를 원문대로 「앞단의 끝이」 로. 에픽의 수 · 범위 · 의존은 승인된 그대로다. 항목 · 질문 · 위험의 번호는 바뀌지 않았다.
- 리뷰 상한 뒤 사용자 답 셋(S35–S37)을 반영했다 — 항목 하나(D41)를 더하고, 근거 수 줄 · 머지 순서 질문 · 에픽 「앞단의 끝」 의 범위(넘겨받는 것이 둘에서 셋으로)를 고쳤다. 3라운드의 수정 일곱과 이 반영은 리뷰어가 다시 보지 않았다(추가 라운드를 열지 않았다 — S35).
- 그 뒤 PR #274 와 옆 로드맵 수정 PR #279 가 머지돼(본체가 GitHub 에서 확인) 사용자에게 다시 물었다 — 답 셋(S38–S40)을 반영했다: 리뷰가 참고로 남긴 과설계 지적은 사용자가 보고 한 로드맵에 두기로 해 OQ39(해결)로 박제했고, PR #274 의 잔여 셋은 이 일이 받기로 다시 정해 항목 하나(D42)를 더했다. 승인 뒤 바뀐 분해안 표(번호 배정 추가 · 에픽 「앞단의 끝」 의 의도 문장과 범위)는 사용자가 다시 승인했다(S40). 이 반영도 리뷰어가 다시 보지 않았다.
- 냉독 뒤 다음 단계 절(§7)에 뒤 에픽 둘(F5 · F7)의 이름과 순서를 한 문장 더했다 — 냉독이 그 둘의 이름을 이 문서에서 찾지 못했다.
- 끝 게이트(2026-11-15): 사용자가 「확정하고 /compact 후 지휘자로 (권장)」 를 골랐다 — §2 의 항목 42개를 확정으로 바꾸고 로드맵을 다시 만들었다. 게이트 앞에 보인 것: 리뷰 결과 · 냉독 gap 넷 · 경고 셋(codex 부재 · 냉독 대체 · 사용자 판단 포화) · §1 줄의 출처 · 확정 후보 42개 · 확정으로 올리지 않은 발화 아홉.
- 대체됨: seed 「옆 세션 설계문서의 미룸 표는 앞단이 의도 폴더에 바로 쓰게 하는 일과 설계문서 머리 키의 이름을 이름 바꾸기 쪽과 그 로드맵의 이전 에픽 앞으로 함께 적어 두었다」 → 지금 판은 받는 곳 칸이 R5 하나이고 이유 칸이 「이름 바꾸기 로드맵(B13)이 먼저 하면 R5 는 옮길 때 확인만 한다」, 737행은 「그 로드맵이 … 정한다」 (조사 1 · 조사 2)
- 대체됨: seed 「인터뷰 결과물 리뷰 기준이 레포 원칙을 깎는 잣대로 쓴다」 → 사다리 2단 「이미 리포에 있는 원칙·메커니즘으로 되나」 는 줄이는 근거가 맞고, 「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다」 는 깎지 못하게 하는 보호 줄이다 (조사 1)
- 대체됨: Phase 0 기록 「필수 조사 둘과 포화 판정을 모델이 건너뛸 칸이 없다」 → 포화 판정에는 사용자 종료 · 사용자 판단 포화 칸이 있고 모델 판단 칸만 없다 (조사 1)
- 대체됨: Phase 0 기록 「약 2천 자 한 줄」 → finishing.md 551행은 3736자다 (조사 4 와 함께 본체가 잼)
- 대체됨: 옆 세션 넘김 글의 「인터뷰 → 의도 싱크」 한 덩어리 → 옆 세션이 그 등치는 자기 해석이었다고 알렸다(세션 메시지). 사용자 확인은 이 라운드 질문으로 받는다
- 재결정(P23): 원래 — seed 「인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다. (사용자 확인)」 / 재결정 — request-framing 이 「의도 싱크」가 되고 인터뷰는 새 이름을 따로 정한다(S2) / 근거 — 옆 세션이 전한 사용자 말 「외부 내부 조사를 담당하는거도 그쪽 역할인데 사실 의도 싱크는 framing에서 주 역할이고 interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」 를 질문에 그대로 싣고 사용자가 골랐다
- 대체됨: R1 «지금 이해» 「옆 설계문서 737행은 「그 로드맵이 `source_interview` 키와 `intent/` 에 바로 쓰기를 정한다」 고 이 일을 가리키고」 → 지금 판(771줄, 37fab27e)에는 그 문장이 없고 받는 곳은 R5, 조건은 「다른 로드맵이 먼저 하면 확인만」 이다 (조사 10)
- 대체됨: R3 답 기록 「S8 로 인터뷰의 새 이름도 정해졌다 — 「맥락 쌓기」 와 「로드맵 잡기」」 → 「맥락 쌓기」 는 본체가 쓴 선택지 문장이고 사용자 말은 「컨텍스트 쌓기」 다. 낱말은 OQ17 로 다시 묻는다 (조사 10)
- 재결정(P23): 원래 — R3 답 기록의 이름 「맥락 쌓기」 / 재결정 — 「컨텍스트 쌓기」(S17) / 근거 — 사용자 말 「interview는 컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」 의 글자
- 재결정(P23): 원래 — S15 「캐시만 옮긴다」(기록 둘은 프로젝트에 남는다고 본체가 표에 적음) / 재결정 — 기록까지 공식 데이터 폴더로 옮기고, 꼭 둬야 하는 것만 docs 아래에 둔다(S22 · S26) / 근거 — 사용자 말 「나머지는 다 공식대로 옮기면 되겠는데?」 · 「둬야할 위치를 docs아래로 바꾼다 꼭 둬야하는 경우에만」
- 대체됨: R8 보고의 「품질 게이트의 기준선 캐시 — 다시 만들 수 있다 — 공식 데이터 폴더 아래 프로젝트별 자리」 → 그 폴더는 지금 코드가 쓰지 않는 옛 잔재라 옮길 대상이 아니다 (조사 15)
- 대체됨: R8 보고의 「지휘 기계 상태 — 캐시로 줄어든 몫만 옮김」 → 에픽 PR 번호 기록과 쌓인 기록은 다시 만들 수 없어 「꼭 둬야 하는 것」 후보다 (조사 15)
- 대체됨: seed 「그 문서는 아직 리뷰와 승인 전이고」 → 옆 세션이 승인됐다고 알렸다(승인 사실 자체는 본체가 문서에서 확인하지 못했다 — 마지막 커밋과 줄 수만 확인) (옆 세션 메시지)
- 대체됨: seed 「그 대조표는 아직 그 세션의 임시 폴더에만 있고」 → PR #276 으로 올라가 있다(머지 전이라 기본 브랜치의 경로로는 아직 가리킬 수 없다) (옆 세션 메시지 · 본체 확인)
- 대체됨: 조사 14 의 「`shared/` 의 gc · killswitch · python · style · tests 와 레포 루트의 `tools/` 는 링크 대상이 아니다(설치본에 링크로 실리지 않는다)」 를 「실리지 않는다」 로 읽은 것 → gc · killswitch · python 의 파일과 쉬운 말 블록은 글자 사본으로 실린다. 실리지 않는 것은 `shared/tests` 와 `tools/` 다 (조사 18)
- 대체됨: 조사 14 의 「Bash 에서 그 폴더 아래에 쓰는 쓰기가 성공했다」 가 어느 세션에서나 통한다는 읽기 → 그 실측은 샌드박스를 켜지 않은 세션의 값이고, 샌드박스된 Bash 의 기본 쓰기 자리에 그 폴더는 없다 (조사 16 · 조사 20)
- 확인 RC64 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#열린 PR 274 — `gh pr view 274`: 열림 · 브랜치 `feature/interview-pr-merge` · 제목 「분해된 인터뷰가 끝맺음에서 PR 을 열고 머지를 묻는다」 · 고치는 파일은 spec-distill 의 plugin.json · CHANGELOG.md · README.md · dependencies.md · finishing.md 와 shared/tests/fixtures/ask-sites.tsv
- 확인 RC1 — 확인 — plugins/spec-distill/skills/pm-interview/references/seed-input.md#「§6 `S1` 은 「풀린 입력」 원문 그대로다」 — 주장과 일치
- 확인 RC2 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#ground_truth — 주장과 일치
- 확인 RC3 — 확인 — plugins/spec-distill/references/docreview-profiles/seed.md#layer1 — 주장과 일치(범주 다섯 · 29행 omission 규칙)
- 확인 RC4 — 확인 — plugins/spec-distill/scripts/seed_body.py#「받는 문법(허용 목록)을 적고, 그 밖은 전부 거부한다」 — 주장과 일치
- 확인 RC5 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「superpowers 부재 시」 — 주장과 일치(444행 · 테스트 107–112행)
- 확인 RC6 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「다음 세션 줄 — 분해된 일 ①/② 공통」 — 주장과 일치
- 확인 RC7 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「사용자 선호: 이 brief 의 설계는 설계문서를 쓰는 크기다」 — 주장과 일치(epic-handoff.md 7행에도 같은 라벨)
- 확인 RC8 — 확인 — plugins/spec-distill/scripts/check_brief.py#budget_mapper_failures — 주장과 일치(saturation_failures 포함)
- 확인 RC9 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#「필수 자리 둘(첫 질문 전 `coverage-mapper`」 — 주장과 일치
- 확인 RC10 — 확인 — plugins/spec-distill/scripts/build_seed_inline_blob.py#main — 코드와 락은 주장과 일치, 실행은 하지 않았다
- 확인 RC11 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#「판정 절차 — 사다리」 — 주장과 일치(seed 의 서술은 절반만 맞다)
- 확인 RC12 — 확인 — plugins/spec-distill/references/compression.md#「3. 레포 `CLAUDE.md`·`AGENTS.md` 에 이미 있는가」 — 46행은 일치, 「올리는 길이 없다」 는 부재 주장이라 다시 세지 않았다
- 확인 RC13 — 확인 — plugins/spec-distill/references/research-claims.md#「출처: `docs/archive/interview/2026-07-12-project-init-audit-interview.md`」 — 주장과 일치
- 확인 RC14 — 확인 — docs/plugin-authoring.md#「quality-gates:doc-recritic」 — 주장과 일치(quality-gates agents 넷 · doc-recritic 은 spec-distill 에 있다)
- 확인 RC15 — 확인 — docs/plugin-authoring.md#「command-development」 — 주장과 일치(45행 · 22행)
- 확인 RC16 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#find_specs — 주장과 일치(336 · 680행 글자 대조)
- 확인 RC17 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#KEYS — 주장과 일치
- 확인 RC18 — 확인 — shared/tests/test_invocation_surface.sh#ENTRY — 주장과 일치(34행 · 135–158행)
- 확인 RC19 — 확인 — plugins/spec-distill/tests/test_superpowers_presence.sh#FIN — 주장과 일치, 파일 수는 본체 계수 58(보고 57)
- 확인 RC20 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#파일 전체 줄 수 — 줄 수 일치(1373 · 600 · 741 · 685), 비율은 재지 않았다
- 확인 RC21 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「B-2 — 단일 `AskUserQuestion` proceed 게이트 (4옵션, AC2)」 — 인용한 줄은 일치, 「약 45곳」 은 확인하지 못했다
- 확인 RC22 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「저자 편집 공시 — 라운드 게이트 앞 · 확정 게이트 앞」 — 주장과 일치
- 확인 RC23 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R2 — 지휘 절차 개편」 — 주장과 일치(32 · 44 · 79행)
- 확인 RC24 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#C2 — 주장과 일치(42 · 52 · 105행)
- 확인 RC25 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「brief · audit 를 `intent/` 에 바로 쓰기 · `source_interview` 키 이름」 — 주장과 일치(649 · 737 · 204 · 176 · 401행)
- 확인 RC26 — 확인 — docs/philosophy/devbrew-harness-philosophy.md#「P8 — Determinism Economy」 — 주장과 일치(82 · 84행)
- 확인 RC27 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「git commit -q --only -m 'docs(interview): <topic> interview seed + audit'」 — 주장과 일치(1157행 · finishing.md 640행 · 템플릿 11행)
- 확인 RC28 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「2026-11-14 · 처음 로드맵」 — 주장과 일치(두 판 파일 일곱이 바이트 동일 · 결정 기록 절 비어 있음)
- 확인 RC29 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「경로 예약」 — 주장과 일치
- 확인 RC30 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다」 — 주장과 일치
- 확인 RC31 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R2 — 지휘 절차 개편」 — 주장과 일치(40행 범위 · 119행 K14)
- 확인 RC32 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R5 — 이전 · 재측정」 — 주장과 일치(75 · 79행)
- 확인 RC33 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#K1 — 주장과 일치
- 확인 RC34 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md#「0. 역참조」 — 주장과 일치(묶음 여섯 모두 한 줄씩 · roadmap_render.py 336행)
- 확인 RC35 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md#「S1 최초 요청(Phase 0 seed 전문)」 — 116행은 일치, 묶음에 framing 원문 절이 없다는 부분은 다시 세지 않았다
- 확인 RC36 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#「C2 · D11」 — 주장과 일치
- 확인 RC37 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R5.md#OQ47 — 주장과 일치(53행 · S49 184행)
- 확인 RC38 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#OQ24 — 주장과 일치(R1.md 86행 OQ45 포함)
- 확인 RC39 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#OQ23 — 주장과 일치(로드맵 폴더 일곱 파일에 「의도 싱크」 · `interview_dir` 0건)
- 확인 RC40 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R2.md#ids — 주장과 일치(C50 은 있고 S50 은 ids 에 없다)
- 확인 RC41 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R1.md#「7. 인터페이스」 — R1 은 일치, 다른 묶음은 다시 열지 않았다
- 확인 RC42 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Context / Why」 — 주장과 일치(28 · 34행)
- 확인 RC43 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§3 원자료 — `intent/`」 — 주장과 일치
- 확인 RC44 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§1 팀 폴더 — `intent/` 행」 — 주장과 일치(98 · 114 · 188 · 498행이 서로 다르게 적는다)
- 확인 RC45 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「한 번만 짓는다.」 — 주장과 일치
- 확인 RC46 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§11 생성기」 — 주장과 일치(390–392 · 546행)
- 확인 RC47 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「분해 승인 화면에 과제마다 지시 원문 범위의 글을 보이기」 — 주장과 일치(642행 · 로드맵 44행에 그 파일 없음)
- 확인 RC48 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「`references/epic-handoff.md`」 — 주장과 일치(401 · 405행)
- 확인 RC49 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Non-goals」 — 주장과 일치(51 · 671 · 737행)
- 확인 RC50 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸 — brief · audit 를 `intent/` 에 바로 쓰기」 — 주장과 일치(문서 안에서 받는 곳이 갈린다)
- 확인 RC51 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「과제는 에픽이거나 단순 작업」 — 주장과 일치(127 · 371 · 376 · 396 · 643 · 685행)
- 확인 RC52 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「사용자에게 보이는 말은 「리더」다」 — 주장과 일치(71 · 409–411 · 597행)
- 확인 RC53 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Files to Modify」 — 주장과 일치(철학 문서 · 레포 CLAUDE.md 없음 · 308 · 468 · 535 · 711행)
- 확인 RC54 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「재분해 신호」 — 주장과 일치(726행 ④ 가 R2.md 실물과 C50 에서 어긋난다)
- 확인 RC55 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Handoff Context — 원자료 대조표」 — 주장과 일치(736행 · 두 worktree 에 `framing-ledger.md` 없음)
- 확인 RC56 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸」 — 주장과 일치(628–655행)
- 확인 RC57 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「D33 행」 — 주장과 일치(513 · 644행 · 로드맵 28행)
- 확인 RC58 — 미확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「원문 대조 — 원자료:」 — 463행의 줄 범위 인용은 있으나 그 범위가 옛 audit 실물과 맞는지는 대조하지 않았다
- 확인 RC59 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#ROADMAP_META_KEYS — 주장과 일치, `interview_dir` 글자 수는 본체 계수 21개 파일 125번(보고 119번)
- 확인 RC60 — 확인 — plugins/spec-distill/scripts/roadmap_status.py#find_specs — 주장과 일치, `source_interview` 글자 수는 본체 계수 24개 파일 72번(보고 65번)
- 확인 RC61 — 확인 — plugins/spec-distill/references/epic-handoff.md#「에픽 넘김 줄」 — 주장과 일치
- 확인 RC62 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「payload frontmatter」 — 주장과 일치(74–76 · 229 · 556 · 588 · 606행)
- 확인 RC63 — 확인 — docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-interview.md#「인터뷰를 의도 싱크로 바꾸는 이름 바꾸기는 이 일에 합친다. (사용자 확인)」 — 주장과 일치
- 확인 RC65 — 확인 — docs/plugin-authoring.md#「agent frontmatter 에 `model` 키를 두지 않는다.」 — 주장과 일치(22행, 근거는 P8)
- 확인 RC66 — 확인 — docs/plugin-authoring.md#「dispatch 시점의 `model` 인자는 오케스트레이터의 재량이다.」 — 주장과 일치
- 확인 RC67 — 확인 — docs/plugin-authoring.md#「Starter 디렉토리 트리」 — 주장과 일치(5–20행 · 29행)
- 확인 RC68 — 확인 — docs/plugin-authoring.md#「`plugin-dev`가 주는 것은 **문법**이다.」 — 주장과 일치(48행)
- 확인 RC69 — 확인 — docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md#「A. 측정 여섯」 — 43행 · 미실측 U1 · U2(71–73행)는 일치, F1–F5 본문은 다시 읽지 않았다
- 확인 RC70 — 확인 — plugins/spec-distill/dependencies.md#「claude-code | 2.1.303 | 2026-10-22」 — 주장과 일치(네 플러그인 · superpowers 7.0.0 · plugin-dev 행 없음)
- 확인 RC71 — 확인 — CLAUDE.md#「모든 PR마다 SemVer bump가 붙는 `plugin.json`.」 — 주장과 일치(spec-distill plugin.json 키는 author · description · name · version)
- 확인 RC72 — 확인 — CLAUDE.md#「Scoped agents — default-everything 금지.」 — 주장과 일치(agent 20개 모두 `tools:` · `model:` 0건)
- 확인 RC73 — 확인 — CLAUDE.md#「`allowed-tools` 는 제한이 아니다.」 — 주장과 일치(SKILL.md 9개가 선언 · `disallowed-tools` 0건)
- 확인 RC74 — 확인 — CLAUDE.md#「Progressive disclosure.」 — 주장과 일치
- 확인 RC75 — 확인 — CLAUDE.md#「모든 skill에 `cost_class` 선언」 — 주장과 일치, SKILL.md 는 본체 계수 10개(보고 11개)
- 확인 RC76 — 확인 — CLAUDE.md#「런타임 상태 & 훅」 — 주장과 일치
- 확인 RC77 — 확인 — CLAUDE.md#「Self-narrating artifact」 — 주장과 일치
- 확인 RC78 — 확인 — plugins/spec-distill/agents/brief-readback.md#「tools: []」 — 주장과 일치(13행 · seed-readback.md 15행)
- 확인 RC79 — 확인 — CLAUDE.md#「Doc Conventions」 — 주장과 일치(103줄)
- 확인 RC80 — 확인 — docs/plugin-authoring.md#「agent frontmatter 에 `model` 키를 두지 않는다.」 — 주장과 일치
- 확인 RC81 — 확인 — docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md#「A. 측정 여섯」 — 주장과 일치(프로브 둘 · 트레이드오프 수용 17 · 92행)
- 확인 RC82 — 확인 — plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh#「예외는 없다」 — 주장과 일치(8행 · README 134행 문장을 46행이 단언)
- 확인 RC83 — 확인 — plugins/quality-gates/tests/test_agent_model_mutation.sh#「pairs=(」 — 주장과 일치(짝 아홉 · 테스트 파일 여덟 · 규약 문장 락 · docreview 락)
- 확인 RC84 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#「리뷰어 모델:」 — 주장과 일치(372행 · 계약 테스트 215행)
- 확인 RC85 — 확인 — plugins/quality-gates/README.md#「Choosing a cheaper tier for devbrew subagents is the user's call」 — 주장과 일치(141 · 147행)
- 확인 RC86 — 확인 — docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md#「K1. 리뷰는 opus 다.」 — 주장과 일치(102 · 675행)
- 확인 RC87 — 확인 — docs/superpowers/specs/2026-10-17-shared-review-engine-devices-design.md#「리뷰어 모델 opus 고정 둘」 — 주장과 일치(107행 · qg CHANGELOG 155행)
- 확인 RC88 — 확인 — docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/flexibility-audit.md#「고치는 꼴」 — 주장과 일치(5 · 9행)
- 확인 RC89 — 확인 — CLAUDE.md#「레포 전용 값 금지.」 — 주장과 일치(31행 · test_conducting_reference.sh 395–397행)
- 확인 RC90 — 확인 — plugins/spec-distill/skills/epic-conductor/SKILL.md#「모델 칸은 해결자」 — 주장과 일치(173 · 180행)
- 확인 RC91 — 확인 — plugins/plugin-audit/scripts/check-plugin-structure.sh#has_model_key — 주장과 일치(63행)
- 확인 RC92 — 확인 — plugins/quality-gates/agents/security-reviewer.md#frontmatter — 주장과 일치(agent 20개 · `model:` 0건)
- 확인 RC93 — 확인 — CLAUDE.md#「이 예외는 제3자 설치가 확인되면」 — 문장은 일치(줄은 43행 — 보고의 49행과 다르다)
- 확인 RC94 — 확인 — CLAUDE.md#「모든 PR마다 SemVer bump가 붙는 `plugin.json`.」 — 주장과 일치
- 확인 RC95 — 확인 — CLAUDE.md#「호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다.」 — 주장과 일치
- 확인 RC96 — 확인 — plugins/spec-distill/scripts/conductor_state.py#own_version — 주장과 일치(102 · 110 · 123 · 247행)
- 확인 RC97 — 확인 — plugins/spec-distill/scripts/conductor_ledger.py#version_report — 주장과 일치(388 · 391 · 423 · 1425행), conducting.md 14행은 다시 열지 않았다
- 확인 RC98 — 확인 — shared/deps/check_deps.py#_measure_row — 주장과 일치(232 · 250 · 259행)
- 확인 RC99 — 확인 — plugins/spec-distill/dependencies.md#「quality-gates | 14.6.0」 — 주장과 일치
- 확인 RC100 — 확인 — shared/tests/test_changelog_integrity.sh#「C2 맨 위 헤딩 버전 == plugin.json 버전.」 — 주장과 일치(366줄 · 30 · 62 · 199행), 「PR 마다 올렸는지 재는 검사가 없다」 는 부재 주장이라 다시 세지 않았다
- 확인 RC101 — 확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#plugin_json_fields — 주장과 일치(8 · 44행 · check-staleness.py 269–274행)
- 확인 RC102 — 확인 — shared/tests/test_plugin_description_parity.sh#「plugin.json 에 소개 문구가 없다」 — 주장과 일치
- 확인 RC103 — 확인 — plugins/spec-distill/scripts/repo_defaults.py#SHARED_FILES — 주장과 일치(28행 · roadmap_status.py 59행)
- 확인 RC104 — 확인 — plugins/spec-distill/CHANGELOG.md#「[8.13.1] — 2026-10-30」 — 주장과 일치(헤딩 179 · 204 · 42 · 35)
- 확인 RC105 — 확인 — plugins/spec-distill/tests/test_readme_sync.sh#「플러그인 건드리는 모든 PR은 patch-bump」 — 주장과 일치
- 확인 RC106 — 확인 — .claude-plugin/marketplace.json#「"source": "./plugins/quality-gates"」 — 주장과 일치(상대경로 넷 · entry 에 version 없음 · README 는 github 소스 안내)
- 확인 RC107 — 확인 — plugins/spec-distill/.claude-plugin/plugin.json#「"version": "8.13.1"」 — 주장과 일치(네 플러그인 모두 네 키)
- 확인 RC108 — 확인 — docs/plugin-authoring.md#「plugin.json # 필수 — name, version (0.1.0로 시작), description」 — 주장과 일치(10 · 12행)
- 확인 RC109 — 확인 — plugins/project-init/hooks/hooks.json#「"PostToolUse"」 — 주장과 일치(훅 파일 둘 · plugin.json 넷에 hooks 키 없음 · post-tool-use.py 609행)
- 확인 RC110 — 확인 — shared/entry/entry_preflight.py#sentinel — 주장과 일치(44–51행 · 테스트 74–75행)
- 확인 RC111 — 확인 — shared/killswitch/kill_switch_active.py#kill_switch_active — 주장과 일치(3–13 · 29행), 127개 파일 647곳은 다시 세지 않았다
- 확인 RC112 — 확인 — plugins/quality-gates/README.md#「DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1」 — 주장과 일치(469 · 470 · 477 · 487행)
- 확인 RC113 — 확인 — plugins/spec-distill/README.md#「DEVBREW_SKIP_HOOKS=spec-distill:review-entry」 — 주장과 일치(282 · 288 · 294 · 295 · 320행)
- 확인 RC114 — 확인 — plugins/spec-distill/scripts/state_path.py#ensure_state_root — 주장과 일치(73 · 98 · 120 · 138 · 161 · 251행), 테스트 23개 파일 242곳은 다시 세지 않았다
- 확인 RC115 — 확인 — plugins/quality-gates/scripts/setup-qg.sh#「STATE_ROOT=".claude/quality-gates"」 — 주장과 일치(194 · 213 · 255행)
- 확인 RC116 — 확인 — plugins/plugin-audit/scripts/prepare-run-dir.py#「os.mkdir 로 원자적으로 만들고」 — 주장과 일치(4–6행)
- 확인 RC117 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R3 — 지휘자 상태 브랜치 · 편지함」 — 주장과 일치(50 · 56 · 44행)
- 확인 RC118 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/R3.md#D18 — 주장과 일치(47 · 70 · 130행)
- 확인 RC119 — 확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#_hooks_killswitch_present — 주장과 일치(136행)
- 확인 RC120 — 확인 — plugins/spec-distill/references/docreview-profiles/brief.md#「Law 1·2·3 과 kill switch 는 어떤 모드에서도 안 자른다.」 — 주장과 일치(74행)
- 확인 RC121 — 확인 — CLAUDE.md#「kill switch 이름은 이 예외에 들지 않는다」 — 주장과 일치
- 확인 RC122 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「분해 판단 — Step A 직전」 — 주장과 일치(24 · 26 · 63 · 65행), pm-interview SKILL.md 562행은 다시 열지 않았다
- 확인 RC123 — 확인 — plugins/spec-distill/skills/pm-interview/references/finishing.md#「위험 번호.」 — 148행 · 655행 제목은 일치, 210–232행은 R1 때 229행만 보았다
- 확인 RC124 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「원문 보존」 — 주장과 일치(220행 · 이 파일의 P21 은 643행 하나 · pm-interview SKILL.md 172행)
- 확인 RC125 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「`## 1` append-only 의 유일한 예외입니다」 — 주장과 일치(605–610행)
- 확인 RC126 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#AC4 — 주장과 일치(563 · 564 · 177행 — 771줄 판)
- 확인 RC127 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「이 로드맵 안에서는 R5 가 받고」 — 주장과 일치(771줄 · 「바로 쓰기를 정한다」 0건 · 189 · 660 · 709 · 768행)
- 확인 RC128 — 확인 — /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/team-file-contract/docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「§3 원자료 — `intent/`」 — 주장과 일치(183–191행)
- 확인 RC129 — 확인 — docs/superpowers/interview/2026-11-14-framing-interview-constraint-audit-brief-interview.state.md#user_statements — 주장과 일치(S2–S10 가운데 선택지 문장이 일곱)
- 확인 RC130 — 확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#_has_cost_class — 주장과 일치(104–108행 · 테스트 144행 `FIXED_CLAUDE`), 실행은 하지 않았다
- 확인 RC131 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「R2 — 지휘 절차 개편」 — 주장과 일치(40 · 44행 · 옆 설계문서 598행)
- 확인 RC132 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#K1 — 주장과 일치(106행 · 옆 설계문서 652행 · token-baseline.md 없음)
- 확인 RC133 — 확인 — plugins/spec-distill/scripts/state_path.py#_SLOTS — 주장과 일치(213 · 350행 · check_brief.py 1633행 · spec_review_bundle.py 31행 · interview_state.py 137 · 211행)
- 확인 RC156 — 확인 — plugins/spec-distill/scripts/state_path.py#state_root — 메인 레포의 `.claude/` 아래 실제 폴더: `spec-distill/`(`.docreview` · `conductor` · `.gitignore`) · `quality-gates/`(세션 폴더 · `baseline-cache` · `worktrees`) · `plugin-audit/`(`worktrees` — 실행 폴더는 `<date>-<target>` 꼴로 생긴다). project-init 은 상태 폴더가 없다(스크립트에 그 경로 0건)
- 확인 RC134 — 확인 — plugins/plugin-audit/CHANGELOG.md#「[0.9.4] — 2026-09-22」 — 인용 자리는 일치(191행), 종류별 수(35개)는 다시 세지 않았다
- 확인 RC135 — 확인 — plugins/project-init/CHANGELOG.md#「v1.7.1은 marketplace description 압축에 따른 doc-only patch bump」 — 인용 자리는 일치(449행), 종류별 수(42개)는 다시 세지 않았다
- 확인 RC136 — 확인 — plugins/spec-distill/CHANGELOG.md#「patch 인 이유 — 링크로 배송하는 `render_disposition.py` 가 바뀌었다」 — 인용 자리는 일치(785행), 종류별 수(179개)는 다시 세지 않았다
- 확인 RC137 — 확인 — plugins/quality-gates/CHANGELOG.md#「배포 바이트 변경에 따른 cache key bump」 — 인용 자리는 일치(207행), 종류별 수(204개)는 다시 세지 않았다
- 확인 RC138 — 미확인 — plugins/quality-gates/CHANGELOG.md#「[14.8.1] — 2026-10-30」 — 헤딩 합 460 은 본체 계수와 같다. 종류별 합(326 · 32 · 46 · 25 · 2 · 29)과 23% 는 조사의 근사이고 본체가 확정하지 못했다
- 확인 RC139 — 확인 — plugins/quality-gates/CHANGELOG.md#「링크라 그 대상이 바뀐 이상 배포 트리 안의 코드가 바뀐 것이고 bump 대상이다」 — 주장과 일치(726행 — 보고의 723행과 다르다)
- 확인 RC140 — 확인 — plugins/spec-distill/CHANGELOG.md#「을 함께 bump」 — 주장과 일치(1996행)
- 확인 RC141 — 확인 — plugins/quality-gates/CHANGELOG.md#「[6.6.3] — 2026-09-04」 — 주장과 일치(같은 날 헤딩 수 qg 20 · 10, spec-distill 15 · 8 — 본체 계수)
- 확인 RC142 — 확인 — plugins/quality-gates/CHANGELOG.md#「[8.3.0] — 2026-09-22」 — 주장과 일치(675행이 686 · 696 · 704행 위), 다른 어긋난 자리는 다시 보지 않았다
- 확인 RC143 — 확인 — plugins/quality-gates/CHANGELOG.md#「머지 시점에 `3.1.0` 으로 재산정됐다」 — 주장과 일치(3169행)
- 확인 RC144 — 확인 — plugins/spec-distill/CHANGELOG.md#「제자리 교체했다」 — 주장과 일치(1971행 · test_changelog_integrity.sh 9행)
- 확인 RC145 — 확인 — shared/tests/test_changelog_integrity.sh#「C3 헤딩 버전이 위에서 아래로 **순감소**.」 — 주장과 일치(63행)
- 확인 RC146 — 확인 — plugins/quality-gates/CHANGELOG.md#「SKILL 제목 두 개가 8.0.0 bump 뒤에도 `(v7.0.0)` 이었다」 — 주장과 일치(718행 · SKILL.md 45행 · 테스트 226행)
- 확인 RC147 — 확인 — plugins/quality-gates/tests/test_artifact_metadata.sh#「floor는 minor(>=2.11) invariant다」 — 7행은 일치, 나머지 테스트 넷은 파일 실재만 확인했다
- 확인 RC148 — 확인 — plugins/spec-distill/tests/test_conductor_state.py#test_writer_stamp_roundtrip — 178행은 일치, 다른 테스트 줄은 다시 열지 않았다
- 확인 RC149 — 확인 — shared/deps/check_deps.py#superpowers_version — 221행은 일치
- 확인 RC150 — 확인 — plugins/plugin-audit/scripts/check-staleness.py#_semver_at_least_1_0_0 — 주장과 일치(535행 · check-shape-completeness.py 51–55행)
- 확인 RC151 — 확인 — plugins/spec-distill/README.md#「버전 붙은 플러그인 폴더를 박아 두지 않고」 — 주장과 일치(177행)
- 확인 RC152 — 확인 — plugins/spec-distill/references/conductor-dispatch.md#「판 번호.」 — 주장과 일치(16행 · conducting.md 113행)
- 확인 RC153 — 확인 — docs/git-workflow/commit-conventions.md#「SemVer Mapping」 — 주장과 일치(51 · 61행)
- 확인 RC154 — 확인 — plugins/plugin-audit/CHANGELOG.md#「minor 인 이유 — 옛 consent.json」 — 11행은 일치, 「이유」 줄 수는 본체 계수 53(보고 41)
- 확인 RC155 — 확인 — plugins/project-init/CHANGELOG.md#「one-minor deprecation window 없이」 — 218행은 일치, 다른 두 자리는 다시 열지 않았다
- 확인 RC157 — 확인 — shared/docreview/scripts/docreview_state.py#플러그인이 링크로 싣는 정본 — `git ls-files` 의 링크(mode 120000)는 `plugins/` 아래 43개이고 대상은 `shared/` 의 adjudication · codex · deps · docreview · entry · test-selection 여섯 폴더다. `shared/` 의 gc · killswitch · python · style · tests 와 레포 루트의 `tools/` 는 링크 대상이 아니다(설치본에 링크로 실리지 않는다)
- 확인 RC158 — 확인 — plugins/spec-distill/scripts/state_path.py#_check_state_root — 함수와 무시 · 추적 검사 줄은 일치, 오류 문구는 다시 읽지 않았다
- 확인 RC159 — 미확인 — plugins/spec-distill/scripts/gc_common.py#root_escapes — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC160 — 미확인 — plugins/spec-distill/skills/spec-review/SKILL.md#path-inside --root — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC161 — 미확인 — plugins/spec-distill/scripts/docreview_state.py#state_dir_for — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC162 — 미확인 — plugins/spec-distill/scripts/docreview_state.py#save_state — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC163 — 미확인 — plugins/spec-distill/scripts/docreview_state.py#RECOVER — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC164 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#「원장 자리의 수명」 — 주장과 일치(1071–1075행)
- 확인 RC165 — 미확인 — plugins/spec-distill/skills/request-framing/SKILL.md#BUNDLE= — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC166 — 미확인 — plugins/spec-distill/scripts/ledger_marker.py#MARKER — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC167 — 미확인 — plugins/spec-distill/scripts/ledger_sweep.py#sweep_ledgers — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC168 — 미확인 — shared/docreview/scripts/nofollow_write.py#「마지막 경로 성분의 링크를 따라가지 않고 파일을 쓴다.」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC169 — 미확인 — plugins/spec-distill/scripts/conductor_state.py#machine_dir — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC170 — 미확인 — plugins/spec-distill/scripts/conductor_state.py#SECTIONS — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC171 — 확인 — plugins/spec-distill/references/roadmap-ontology.md#「쌓인 기록만은 다시 만들 수 없다」 — 주장과 일치(38행 · conducting.md 82행)
- 확인 RC172 — 미확인 — plugins/spec-distill/scripts/conductor_ledger.py#disposable_kind — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC173 — 미확인 — plugins/spec-distill/scripts/merge_check.py#make_copies — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC174 — 미확인 — plugins/spec-distill/scripts/suite_lock.py#lock_path — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC175 — 미확인 — plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md#「생명주기」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC176 — 확인 — plugins/quality-gates/scripts/setup-qg.sh#「세션 폴더를 지우고 다시 만드는 줄」 — 주장과 일치(188–193행 — 상태 루트가 지금 작업 사본의 최상위)
- 확인 RC177 — 미확인 — plugins/quality-gates/scripts/qg-gc.py#_is_session_folder — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC178 — 확인 — plugins/quality-gates/README.md#「12.x 까지의 판이 남긴 기준선 캐시 폴더다」 — 주장과 일치(427행)
- 확인 RC179 — 확인 — plugins/quality-gates/scripts/qg-worktree.sh#make_detached_worktree — 주장과 일치(51–57행 — 레포 밖이면 만들지 않는 가드)
- 확인 RC180 — 미확인 — plugins/quality-gates/scripts/seal-worktree.sh#「워킹트리 쪽에서 집지 않는다」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC181 — 확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#「실행 디렉토리」 — 300행은 일치, 파일 목록은 다시 세지 않았다
- 확인 RC182 — 미확인 — plugins/plugin-audit/scripts/prepare-run-dir.py#「parent = args.repo_root.resolve()」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC183 — 미확인 — plugins/plugin-audit/scripts/audit-sandbox.sh#create-sandbox — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC184 — 미확인 — .gitignore#「plugin state dirs」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC185 — 미확인 — shared/killswitch/kill_switch_active.py#def kill_switch_active — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC186 — 확인 — shared/entry/entry_preflight.py#def switch_name — 이 스크립트를 부르는 SKILL 의 이름 아홉은 일치한다 — 보고가 적은 「여덟」 은 틀렸다(아홉). 읽는 변수는 다시 읽지 않았다
- 확인 RC187 — 미확인 — shared/python/devbrew-python.sh#kill_switch_active() — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC188 — 미확인 — shared/codex/detect_codex.sh#CODEX_KILL_SWITCH_VAR — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC189 — 확인 — plugins/project-init/hooks/hooks.json#PostToolUse — 추적되는 훅 폴더 파일은 project-init 의 둘뿐이고(테스트 fixture 제외) 네 plugin.json 에 hooks 키가 없다
- 확인 RC190 — 미확인 — plugins/project-init/hooks/post-tool-use.py#kill_switch_active("project-init", "post-tool-use", "PostToolUse") — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC191 — 미확인 — plugins/spec-distill/README.md#「스위치 목록」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC192 — 미확인 — plugins/spec-distill/scripts/review_entry.py#def disabled_reason — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC193 — 미확인 — plugins/spec-distill/scripts/control_plane.py#kill_switch_active("spec-distill", "statusline") — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC194 — 미확인 — plugins/spec-distill/scripts/ledger_sweep.py#def disabled — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC195 — 미확인 — plugins/spec-distill/scripts/review_entry.py#GONE_TOKENS — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC196 — 미확인 — plugins/spec-distill/skills/spec-review/SKILL.md#codex-gate — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC197 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC198 — 미확인 — plugins/spec-distill/README.md#DEVBREW_SPEC_DISTILL_DISABLE_WEB — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC199 — 확인 — plugins/spec-distill/skills/request-framing/SKILL.md#DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC200 — 확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC201 — 확인 — plugins/spec-distill/skills/pm-interview/references/saturation.md#「상한 값」 — 주장과 일치 — 본체가 그 절을 직접 읽었다(16–22행)
- 확인 RC202 — 미확인 — plugins/spec-distill/skills/reviewing-brief/SKILL.md#DEVBREW_SPEC_DISTILL_SKIP_VC_ONCE — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC203 — 미확인 — plugins/spec-distill/scripts/state_path.py#def resolve_session_id — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC204 — 미확인 — shared/docreview/scripts/docreview_config.py#ENV — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC205 — 미확인 — plugins/quality-gates/README.md#DEVBREW_QUALITY_GATES_DISABLE=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC206 — 확인 — plugins/quality-gates/scripts/qg-gc.py#kill_switch_active("quality-gates", "qg-gc") — 요약 줄은 print 로 stdout 에 내고(127–128행) README 407행은 「stderr로」 라고 적는다 — 어긋남은 주장 그대로. 나머지는 다시 읽지 않았다
- 확인 RC207 — 미확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#DEVBREW_QUALITY_GATES_DISABLE_CODEX=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC208 — 확인 — plugins/quality-gates/skills/quality-pipeline/SKILL.md#DEVBREW_QUALITY_GATES_DISABLE_SECURITY_REVIEWER=1 — 실행 코드(테스트 밖 .py · .sh · .js · .conf · .json)에서 이 이름을 읽는 자리 0건 — skill 본문의 문장으로만 꺼진다
- 확인 RC209 — 미확인 — shared/test-selection/run-test-selection.sh#adapter_usable — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC210 — 미확인 — plugins/quality-gates/scripts/e2e-state.sh#killed_by_switch — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC211 — 미확인 — plugins/quality-gates/scripts/publish-comment.sh#「kill switch — 어떤 gh 호출보다 먼저」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC212 — 확인 — plugins/quality-gates/scripts/artifact_max_rounds.sh#DEVBREW_QUALITY_GATES_CRITIQUE_MAX_ROUNDS — 끄기 변수(DISABLE_CRITIQUE)를 읽는 실행 코드는 artifact_commit.sh 하나다. README 에 이름이 없다는 부분은 다시 보지 않았다
- 확인 RC213 — 미확인 — plugins/quality-gates/scripts/doc_paths.py#ENV_KEY — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC214 — 확인 — shared/docreview/scripts/run_docreview_codex_reviewer.sh#DEVBREW_QUALITY_GATES_DISABLE_WEB — 실행 코드에서 이 이름을 읽는 자리는 이 러너 하나다
- 확인 RC215 — 미확인 — plugins/quality-gates/scripts/run_codex_reviewer.sh#DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC216 — 미확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#DEVBREW_PLUGIN_AUDIT_DISABLE=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC217 — 미확인 — plugins/plugin-audit/skills/plugin-audit/SKILL.md#DEVBREW_PLUGIN_AUDIT_DISABLE_CODEX=1 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC218 — 미확인 — plugins/plugin-audit/scripts/run_audit_codex_reviewer.sh#DEVBREW_PLUGIN_AUDIT_DISABLE_WEB — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC219 — 확인 — plugins/plugin-audit/scripts/audit-sandbox.sh#create-sandbox — 새 이름과 옛 이름(DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX) 둘 다 읽어 exit 3 으로 끝낸다(33–38행). CHANGELOG 문장끼리의 충돌은 다시 보지 않았다
- 확인 RC220 — 미확인 — plugins/plugin-audit/scripts/check-staleness.py#_REGISTRY_ENV — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC221 — 확인 — CLAUDE.md#「모든 훅에 kill switch」 — 꼴 둘과 예시 둘은 주장과 일치(71행). 다른 최상위 문서 부분은 다시 보지 않았다
- 확인 RC222 — 미확인 — plugins/quality-gates/CHANGELOG.md#「환경변수 어순을 DEVBREW_<PLUGIN>_<REST> 하나로 통일」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC223 — 미확인 — plugins/plugin-audit/scripts/check-shape-completeness.py#def _has_killswitch — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC224 — 확인 — tools/plain-language/measure_output.py#DEVBREW_PLUGINS — 테스트 · CHANGELOG 밖의 DEVBREW_ 이름 57개에 이 상수와 heredoc 구분자들이 들어 있다 — 환경 변수가 아니다
- 확인 RC225 — 확인 — plugins/spec-distill/scripts/gc_common.py## copy-of: shared/gc/gc_common.py — 두 사본 모두 일반 파일(100644)이고 표시 줄 하나를 빼면 정본과 같다
- 확인 RC226 — 확인 — plugins/project-init/scripts/kill_switch_active.py## copy-of: shared/killswitch/kill_switch_active.py — 세 사본 모두 일반 파일이고 표시 줄 하나를 빼면 정본과 같다
- 확인 RC227 — 확인 — plugins/project-init/scripts/devbrew-python.sh## copy-of: shared/python/devbrew-python.sh — 사본은 project-init 하나이고 정본과 같다 — spec-distill · quality-gates 에는 그 파일이 추적되지 않는다
- 확인 RC228 — 확인 — shared/README.md#「세 플러그인에 물리 사본으로 배포된다」 — 33행이 그렇게 적는다 — 트리의 사본은 하나라 어긋난다
- 확인 RC229 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#<!-- plain-language:begin --> — SKILL.md 10개 모두에 정본과 같은 블록이 있고 commands 파일은 0개다
- 확인 RC230 — 미확인 — shared/tests/test_plain_language_block.sh#「대상은 두 글롭에서 도출한다」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC231 — 미확인 — shared/tests/test_copy_of_contract.sh#「축 1b」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC232 — 미확인 — shared/tests/test_python_floor.sh#「축 B」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC233 — 미확인 — shared/tests/test_no_new_duplication.sh#「실제 동일성은 test_copy_of_contract.sh 의 GREEN 에 기댄다」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC234 — 미확인 — plugins/quality-gates/scripts/codex_prompt_common.py## copy-of: shared/codex/codex_prompt_common.py — 사본임은 확인했다. 「동기화 스크립트가 없다」 는 부분은 다시 찾지 않았다
- 확인 RC235 — 확인 — plugins/spec-distill/scripts/runner_common.sh## copy-of: shared/codex/runner_common.sh — codex_jsonl.py(셋) · codex_prompt_common.py(둘) · runner_common.sh(둘) · 리뷰어 agent 정의 셋 모두 일반 파일 사본이고 표시 줄을 빼면 정본과 같다
- 확인 RC236 — 확인 — shared/tests/assert.sh#「사본이 없다」 — shared/README.md 11행(「직접 source한다. 사본도 링크도 필요 없다」)과 일치. plugins 안 같은 이름 0건은 다시 세지 않았다
- 확인 RC237 — 확인 — tools/plain-language/README.md#「플러그인에 들어가지 않는다」 — tools 의 파일과 같은 이름의 추적 파일이 plugins 아래에 0건이다. 쓰는 쪽 목록은 다시 보지 않았다
- 확인 RC238 — 확인 — shared/README.md#「설치본에 들어가지 않는다」 — 주장과 일치(3행 · 10행)
- 확인 RC239 — 확인 — CLAUDE.md#「플러그인을 건드리는 모든 PR마다 bump」 — CLAUDE.md 에 shared · tools 변경과 판 올림을 잇는 문장은 없다(42행). docs 쪽 부재는 다시 찾지 않았다
- 확인 RC240 — 미확인 — shared/tests/test_changelog_integrity.sh#「구조적 정합」 — 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC241 — 확인 — docs/superpowers/specs/2026-08-22-subagent-adjudication-contract-design.md#「배포 링크를 받는 플러그인은 bump 한다」 — 725행 · quality-gates CHANGELOG 706행은 주장과 일치. 다른 계획의 줄은 다시 읽지 않았다
- 확인 RC242 — 확인 — docs/superpowers/plans/2026-09-03-adjudication-topology.md#「두 플러그인 다 bump 한다」 — 3473행 · spec-distill CHANGELOG 2071행은 주장과 일치
- 확인 RC243 — 확인 — docs/superpowers/plans/2026-09-24-qg-recritic-swap-pr4a.md#「플러그인 표면이 아니다」 — 186행 · 같은 계획 문서(adjudication-topology) 976행 「shared/ 만 건드렸으므로 bump 없음」 은 주장과 일치. 다른 두 계획의 줄은 다시 읽지 않았다
- 확인 RC244 — 확인 — tools/suite/run-all.sh#find shared/tests plugins/*/tests — 27행 · shared/README.md 21행은 주장과 일치
- 확인 RC245 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「어느 쪽이든 과제 폴더 없이 도는 일은 없다」 — (옆 worktree 에만 있는 파일) 128행 · 155행은 주장과 일치. 692행 인용은 다시 읽지 않았다
- 확인 RC246 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「job new --roadmap <로드맵>」 — (옆 worktree 에만 있는 파일) 407행은 주장과 일치. 382 · 387행은 다시 읽지 않았다
- 확인 RC247 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「도는 로드맵이 없을 때 단순 작업을 어느 팀의 jobs/ 에 둘지」 — (옆 worktree 에만 있는 파일) 665행(받는 곳 R2) · 402행은 주장과 일치
- 확인 RC248 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「사용자가 준 것을 줄이지 않고 옮긴 한 벌이다」 — (옆 worktree 에만 있는 파일) 183행 앵커와 402행은 주장과 일치. 나머지 인용은 다시 읽지 않았다
- 확인 RC249 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「brief · audit 파일 자체를 intent/ 로 옮기는 일은 이 설계가 하지 않는다」 — (옆 worktree 에만 있는 파일) 189행은 주장과 일치
- 확인 RC250 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「바이트가 같고」 — (옆 worktree 에만 있는 파일) 575행 앵커가 실재하고 문서 전체에 「비밀」 · secret 이 든 줄이 0개다
- 확인 RC251 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「사용자 원문 절은 싣지 않는다」 — (옆 worktree 에만 있는 파일) 205행 앵커가 주장 그 문장이다. seed 에 대한 나머지 인용은 다시 읽지 않았다
- 확인 RC252 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸」 표 — R2 로 가는 행 — (옆 worktree 에만 있는 파일) 665행만 보았고 나머지 행은 본체가 다시 읽지 않았다
- 확인 RC253 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「미룸」 표 — R3 · R4 · R5 · #277 로 가는 행 — (옆 worktree 에만 있는 파일) 674행(R5)만 보았고 나머지 행은 본체가 다시 읽지 않았다
- 확인 RC254 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「brief · audit 를 intent/ 에 바로 쓰기 · source_interview 키 이름」 — (옆 worktree 에만 있는 파일) 674행 · 412행은 주장과 일치
- 확인 RC255 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「앞단(framing · 인터뷰)의 이름 바꾸기」 — (옆 worktree 에만 있는 파일) 51행 앵커가 실재하고 request-framing 리터럴 0건 · pm-interview 1건이다
- 확인 RC256 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「의도 싱크로 바꾸고 따로 에픽으로 두자」 — (옆 worktree 에만 있는 파일) 696행 앵커가 실재하고 809행(받는 브랜치가 이 worktree 의 브랜치)은 주장과 일치
- 확인 RC257 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「컨텍스트 쌓기와 로드맵 잡는게 주 역할이야」 — (옆 worktree 에만 있는 파일) 723행 앵커가 실재하고 809행은 주장과 일치
- 확인 RC258 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「원자료 — 앞단(framing · 인터뷰)에서 온 사용자 말」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC259 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Files to Modify」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC260 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「재분해 신호」 ⑥ — (옆 worktree 에만 있는 파일) 798행 ⑥ 은 주장과 일치 — 끝맺음 절차 파일이 R2 예약에 없고 「예약에 더하거나, 그 파일을 함께 고치는 앞단 로드맵(B13)과 나눈다」
- 확인 RC261 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「새 설정 키는 둘이다」 — (옆 worktree 에만 있는 파일) 421행 앵커가 실재하고 이 worktree 의 repo_defaults.py 36 · 38행(KEYS · ROADMAP_META_KEYS)은 주장과 일치
- 확인 RC262 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「skill 이름 epic-conductor 는 이 설계가 바꾸지 않는다」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC263 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「spec 승인 · 2026-11-14」 — (옆 worktree 에만 있는 파일) 870행은 주장과 일치 — 승인 줄이 문서에 있다
- 확인 RC264 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「Deferred to plan」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC265 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「등록만 하고 직접 만들지 않는다」 는 아직 정해지지 않았다 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC266 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「리더 상태 브랜치를 만들고 올리는 일은 R3 다」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC267 — 확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「크기가 커서 계획 셋으로 나눈다」 — (옆 worktree 에만 있는 파일) 428행 앵커가 실재하고 434행(계획마다 판 올림 · CHANGELOG)은 주장과 일치
- 확인 RC268 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「넘기는 곳. R2」 — (옆 worktree 에만 있는 파일) 앵커는 실재하고 주장 본문은 본체가 구현을 다시 읽지 않았다
- 확인 RC269 — 미확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#「상태 칸은 없다」 — 앵커는 실재한다. ref 관찰은 본체가 다시 보지 않았다 — PR #274 · #276 이 열려 있다는 것만 따로 확인했다(조사 16)
- 확인 RC270 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#R1 의 「경로 예약」 — 두 worktree 의 roadmap.md 가 글자까지 같다. R1 블록의 줄은 다시 읽지 않았다
- 확인 RC271 — 확인 — docs/superpowers/roadmaps/2026-11-14-conductor-context-economy-brief/roadmap.md#R2 의 「경로 예약」 — 44 · 56 · 68 · 79행은 주장과 일치 — R2 예약에 설정 키 파일 · 철학 문서 · CLAUDE.md 가 있고 끝맺음 절차 파일은 없다. R3 예약에 상태 자리 스크립트가, R5 예약에 CHANGELOG 가 있다
- 확인 RC272 — 미확인 — docs/superpowers/specs/2026-11-14-team-file-contract-design.md#「origin/main 8b7ddf4d」 — (옆 worktree 에만 있는 파일) 그 문서의 마지막 커밋이 eaff8a4f 인 것은 본체가 확인했다. 나머지 ref 관찰은 다시 보지 않았다
- 확인 RC273 — 확인 — plugins/spec-distill/dependencies.md#「claude-code | 2.1.303」 — 네 플러그인의 dependencies.md 가 같은 행을 갖는다
- 확인 RC274 — 확인 — plugins/#CLAUDE_PLUGIN_DATA — 추적 파일 전체(plugins · shared · tools)에서 0건이다
- 확인 RC275 — 확인 — plugins/spec-distill/.claude-plugin/plugin.json#userConfig — 네 plugin.json 에 userConfig · defaultEnabled 가 없다
- 확인 RC276 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#SD="${CLAUDE_PLUGIN_ROOT}" — 56행 · 109행은 주장과 일치
- 확인 RC277 — 확인 — plugins/project-init/hooks/hooks.json#「command」 — 10행의 훅 명령은 shell 꼴이고 변수를 따옴표 없이 쓴다. 공식 문서의 따옴표 권고는 본체가 다시 확인하지 않았다
- 확인 RC278 — 확인 — plugins/project-init/scripts/devbrew-python.sh#_ks_skip_has — 46행은 주장과 일치. 판정 흐름 전체는 다시 읽지 않았다
- 확인 RC279 — 확인 — plugins/spec-distill/skills/pm-interview/SKILL.md#「이 표가 보는 kill switch 는 DEVBREW_SPEC_DISTILL_DISABLE=1 하나다」 — 49행은 주장과 일치

### brief 리뷰 (reviewing-brief — 문서 리뷰 엔진)

- 라운드: 3 · 재리뷰 카운트 2 · 추가 라운드 0 — 승인 게이트 도달 사유: 상한 · 리뷰 완료: 예
- 결정: `## 8. 리뷰 결정` 4건 · 열린 채 남은 항목 0건(ask · decide 없음) — 엔진 원장에는 3라운드의 fix 일곱이 「아직 안 고친 곳」 으로 남아 있다(0138b17b#r3.1 · 1677e331#r3.1 · 1677e331#r3.2 · 40f9462c#r3.1 · 997c959a#r3.1 · e99bfa50#r3.1 · eb353eb4#r3.1): 저자는 일곱을 모두 고쳤으나 사용자가 추가 라운드를 열지 않아(S35) 엔진이 관측하지 않았고 리뷰어도 다시 보지 않았다. 상한 뒤 사용자 답 여섯(S35–S40)의 반영도 리뷰 밖이다
- codex: 없음 — exit_nonzero(사용 한도 · 세 라운드 모두) · 웹: Claude doc-critic-web · codex codex 부재
- 냉독: gap 4건 (G3 1 — C37 · C38 이 요약에 없다 · G6 1 — 머리 키 next_phase 와 안내문의 brainstorming 이 §7 의 지휘 절차와 다르게 읽힌다 · G7 2 — 뒤 에픽 둘(F5 · F7)의 이름을 문서에서 찾지 못함(§7 에 더해 고침) · 「옆 로드맵의 이전 에픽」 의 「이전」 이 「앞선」 으로도 읽힌다)
- degrade: readback:전용 agent(brief-readback)가 도구가 없어 경로로 준 문서를 읽지 못해, 같은 지시문으로 읽기 도구가 있는 일반 agent 가 대신 쟀다 · codex:사용 한도로 세 라운드 모두 돌지 못함(exit_nonzero) · 참고 1건(8199b8ed#r1.1)은 끝에서 보였고 사용자가 한 로드맵에 두기로 했다(S38 — OQ39)

## 6. 사용자 원문

> **출처 표기** — 🗣 사용자 발화 · ☑ 사용자 선택 · ✎ 모델 추론

- **S2** ☑ 선택:
  > framing 이 의도 싱크, 인터뷰는 새 이름 (권장) — request-framing 을 「의도 싱크」로 바꾸고, 인터뷰는 맥락 쌓기 · 로드맵 잡기에 맞는 새 이름을 이 인터뷰에서 따로 정한다. 호출 이름 둘이 다 바뀐다.
- **S3** ☑ 선택:
  > 이 일이 맡는다 (권장) — 앞단이 원자료 파일과 결과물을 처음부터 그 폴더에 쓴다. 옆 로드맵은 사본을 만들지 않게 되고 옮길 때 확인만 한다. 이 일의 범위가 커진다.
- **S4** ☑ 선택:
  > 새 코어에 맞추기 (권장) — 원문 보존은 그 안의 한 갈래다. 넘기는 곳 · 글 줄이기 · 가벼운 길 · 이름이 같은 무게로 간다.
- **S5** 🗣 발화:
  > 사본이 없다 (권장), 원자료는 글자 그대로 (권장), 로드맵 없는 일도 같은 자리, 3 시작이 framing일수도 있고 아닐수도 있긴함
- **S6** ☑ 선택:
  > 공식 쪽으로 옮길 후보로 본다 — 다른 자리를 항목마다 다시 여쭤 공식 쪽으로 옮길지 정한다. 이 일이 CLAUDE.md 규칙 개정으로 넓어진다.
- **S7** 🗣 발화:
  > 파이프라인으로서 둘로 나눠도 되고
- **S8** ☑ 선택:
  > 둘로 나누는 방향 (권장) — 인터뷰를 「맥락 쌓기」와 「로드맵 잡기」 두 단계로 나누고 이름도 그 둘로 한다. 나누는 자리와 호출 이름은 설계에서 정한다.
- **S9** ☑ 선택:
  > cost_class 를 metadata 아래로 (권장), integrity 규칙 걷어내기 (권장), disallowed-tools 반영 (권장)
- **S10** ☑ 선택:
  > plugin.json 필수 · 판 올림 완화, agent 의 model 키 허용, kill switch · 상태 자리를 공식으로
- **S11** 🗣 발화:
  > 공식을 따라가
- **S12** 🗣 발화:
  > 공식대로 가고 기존 판올림도 다시 다 검토해봐
- **S13** ☑ 선택:
  > 유지 — 고르신 대로 환경변수 kill switch 를 없애고 공식 설정만 쓰며, 상태를 공식 데이터 폴더로 옮긴다. 진입 skill 끄기와 기능 단위 스위치가 사라진다.
- **S14** ☑ 선택:
  > 다른 공식 장치로 대체 (권장) — 진입 skill 끄기는 공식 플러그인 끄기나 skill 거부 규칙으로, 기능 단위 스위치는 공식 플러그인 사용자 옵션으로 옮긴다. 공식 대응물이 없는 것만 환경변수로 남긴다.
- **S15** 🗣 발화:
  > 프로젝트마다 갈린다 (권장), 캐시만 옮긴다, 뭐가 옮겨질지 나에게 보고해줘 기존 이후 어떻게 될지
- **S16** ☑ 선택:
  > 그대로 이 일이 맡는다 (권장) — 앞 답을 유지한다. 이 일이 먼저 하고 옆 로드맵의 이전 에픽은 확인만 한다. 누가 먼저인지는 옆 세션에 알려 맞춘다.
- **S17** ☑ 선택:
  > 컨텍스트 쌓기 (권장) — 말씀하신 글자 그대로 쓴다.
- **S18** ☑ 선택:
  > 판은 두고 올림 단위를 푼다 (권장) — 공식의 「릴리스마다 올림」 길. 판 번호는 남기고, 「모든 PR 마다」와 함께 올리는 관행을 없애 설치본 동작이 바뀔 때만 올린다. 판을 읽는 코드는 그대로 돈다.
- **S19** ☑ 선택:
  > 원자료의 비밀값 (권장), 질문 · 선택지의 의역 (권장), 한 일에 너무 많이 실림
- **S20** ☑ 선택:
  > 사람에게 보이고 통과 (권장) — 검사가 「모델 판단으로 건너뜀 — 이유」를 따로 받아 통과시키고, 끝의 승인 화면 앞에서 무엇을 왜 건너뛰었는지 사용자에게 보인다.
- **S21** ☑ 선택:
  > 문단 전체가 두 번 나온다 (권장), 어느 지적 때문인지 안 보인다 (권장), 덩어리마다 질문이 따로다, 추천이 없다
- **S22** 🗣 발화:
~~~~
.claude/<플러그인>/worktrees/ 이거보다는 그냥 워크트리를 쓰는게 좋을거 같고 나머지는 다 공식대로 옮기면 되겠는데?
~~~~
- **S23** ☑ 선택:
  > P8 은 옆에 두고 그 밖만 (권장) — 옆 로드맵이 고치는 원칙 P8 문장은 그쪽에 두고, 이 일은 그 밖의 공식과 다른 자리 · 낡은 서술 · 앞단에 닿는 문장만 고친다.
- **S24** ☑ 선택:
  > 그대로 싣고 미확인은 표시 (권장) — 확인한 것은 근거로 싣고, 미확인 셋과 일부만 본 것은 그렇다고 표시해 싣는다. 설계가 필요하면 다시 연다.
- **S25** ☑ 선택:
  > 이대로 싣는다 (권장) — 목록 열하나를 열린 질문으로 싣는다. 다음은 조사가 충분한지 판정한 뒤 이 일을 하나로 할지 나눌지를 여쭙는다.
- **S26** 🗣 발화:
  > 2, 둬야할 위치를 docs아래로 바꾼다 꼭 둬야하는 경우에만
- **S27** ☑ 선택:
  > 방향 유지, 설계가 먼저 잰다 (권장) — 옮기는 방향은 그대로 둔다. 설계 첫 걸음에서 샌드박스를 켠 세션으로 재고, 막히면 설계가 대체 길을 제안해 다시 여쭌다.
- **S28** ☑ 선택:
  > 이 일이 맡는다 (권장) — 그 파일은 이 일만 고치고 옆 로드맵이 넘긴 둘도 이 일이 받는다. 이 일이 커지고, 그 둘은 옆 로드맵 첫 에픽이 머지된 뒤에만 할 수 있다. 옆 세션에 알린다.
- **S29** ☑ 선택:
  > 이대로 싣는다 (권장) — 둘을 더한 목록을 열린 질문으로 싣는다. 올림 단위는 설계가 어긋난 기록을 보고 정한다.
- **S30** ☑ 선택:
  > 포화로 보고 종료 (권장) — 조사를 여기서 닫고 결과물로 간다. 빈 곳 여덟은 「설계가 먼저 볼 것」으로 싣고, 새로 열린 결정(Claude Code 최소 판을 강제할지)은 열린 질문에 더한다.
- **S31** 🗣 발화:
  > 1, 그래 꺼져있는걸 알 수 있게 하자
- **S32** ☑ 선택:
  > 고친다 — 고른 항목만, 나머지는 묻기 (권장) — 「공식 자료는 참고」를 그대로 두고, 공식 쪽을 고른 것은 그 항목에 한한 선택이며 남은 자리는 항목마다 여쭌다고 적는다(리뷰 지적 a6484ced#r1.1).
- **S33** ☑ 선택:
  > 고친다 — 방향 유지, 실측 넓히기 (권장) — 옮기는 방향은 그대로 두고, 실측을 샌드박스 쓰기에서 작업 폴더 밖 읽기 · 쓰기 승인과 하위 agent 의 읽기까지 넓힌다. 막히면 다시 여쭌다(리뷰 지적 abf668a4#r1.1).
- **S34** ☑ 선택:
  > 고친다 — 이름만 필수, 경고를 규칙에 적기 (권장) — 규칙을 이름만 필수로 풀고 감사 검사를 함께 고친다. 판 번호 · 소개 문구 · 저자를 빼면 공식 검증 명령이 경고를 낸다는 것을 규칙에 적는다(리뷰 지적 abf668a4#r2.1).
- **S35** ☑ 선택:
  > 열지 않음 (권장) — 열린 지적 7개를 두고 진행 — 고친 일곱은 결과물에 들어가 있고, 리뷰어의 재확인 없이 끝맺음(읽어 보기 · 확정 후보 · 다음 단계 질문)으로 간다.
- **S36** ☑ 선택:
  > 지금대로 둔다 (권장) — 결과물은 71건을 싣고 나머지는 기록 파일을 가리킨다. 고르신 방식과 달라진 것을 사용자가 받아들였다고 결과물에 적는다.
- **S37** ☑ 선택:
  > (가)만 받는다 (권장) — 커밋 범위 행은 에픽 「앞단의 끝」 이 받는다. PR #274 잔여 셋은 받지 않고, 그 PR 쪽에서 고칠 일로 옆 세션에 알린다.
- **S38** ☑ 선택:
  > 한 로드맵에 둔다 (권장) — 승인하신 에픽 여덟 그대로 간다. 이 지적은 사용자가 보고 그대로 두기로 했다고 결과물에 적는다.
- **S39** ☑ 선택:
  > 이 일이 받는다 (권장) — 에픽 「앞단의 끝」 범위에 잔여 셋이 더해진다. 끝맺음 절차 파일은 계속 이 일만 고친다.
- **S40** ☑ 선택:
  > 승인 (권장) — 위에 적은 변경과 두 답에 따른 변경을 반영해 로드맵을 다시 만든다. 에픽의 수 · 의존 · 브랜치는 그대로다(첫 질문에서 「뺀다」를 고르면 새 분해안을 따로 보여 드린다).

## 7. 확산 원자료

- «cc-sub-agents» — https://code.claude.com/docs/en/sub-agents — 하위 agent 모델 해석 순서 · 한 모델로 묶는 환경변수
- «cc-skills» — https://code.claude.com/docs/en/skills — 본문 500줄 · 할 일만 적기 · allowed-tools · disallowed-tools · metadata · 치환 자리
- «cc-plugins-components» — https://code.claude.com/docs/en/plugins/components — 플러그인 agent 가 받는 키 · command 는 옛 형식 · 데이터 폴더 용도
- «cc-plugins-reference» — https://code.claude.com/docs/en/plugins-reference — manifest 필수 키 · 키 목록 · 경로 변수가 풀리는 자리 · 데이터 폴더 수명 · userConfig
- «cc-host-marketplace» — https://code.claude.com/docs/en/plugins/host-marketplace — 판을 올리는 두 길
- «cc-plugins-loading» — https://code.claude.com/docs/en/plugins/loading — 판 계산 · 도는 세션에 닿는 때 · enabledPlugins 우선순위
- «cc-plugins-dependencies» — https://code.claude.com/docs/en/plugins/dependencies — manifest 의 의존 선언과 판 범위
- «cc-hooks» — https://code.claude.com/docs/en/hooks — 훅 하나 끄기 없음 · 훅 전부 끄기와 우선순위
- «cc-plugins-cli» — https://code.claude.com/docs/en/plugins/cli-reference — 플러그인 끄기 명령의 옵션 · 지울 때 데이터 폴더
- «cc-settings» — https://code.claude.com/docs/en/settings — 실행 옵션 설정은 한 세션 · worktree 의 로컬 설정 파일
- «cc-sandboxing» — https://code.claude.com/docs/en/sandboxing — 기본 쓰기 자리 · 보호 경로 · 훅은 샌드박스 밖
- «cc-memory» — https://code.claude.com/docs/en/memory — 지시 글은 집행이 아님 · 어긋난 규칙
- «pew-survey» — https://www.pewresearch.org/writing-survey-questions/ — 선택지 제시와 순서가 답에 미치는 효과
- «fowler-semantic-conflict» — https://martinfowler.com/bliki/SemanticConflict.html — 글자 병합은 통과하고 뜻이 깨지는 충돌
- «github-sensitive-data» — https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/removing-sensitive-data-from-a-repository — 올라간 비밀값의 처리
- «anthropic-context-eng» — https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents — 맥락 크기와 되찾기 정확도
- «anthropic-multiagent» — https://www.anthropic.com/engineering/built-multi-agent-research-system — 넘김에서 깎이는 정보 · 산출물을 밖에 두기
- «cognition» — https://cognition.com/blog/dont-build-multi-agents — 행동에 실린 암묵적 결정
- «google-small-cls» — https://google.github.io/eng-practices/review/developer/small-cls.html — 작은 변경 · 리팩터링 가르기
- «claude-prompting» — https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/claude-prompting-best-practices — 이유를 주면 일반화
- «cc-issue-87507» — https://github.com/anthropics/claude-code/issues/87507 — 도는 세션이 옛 판 캐시의 skill 을 푸는 보고

## 8. 리뷰 결정

- D1.1 · r1 · adopt · 402da1b4#r1.1 · "1, 그래 꺼져있는걸 알 수 있게 하자" — 환경변수로 끄는 스위치를 없애는 방향에, 이미 그 변수를 켜 둔 환경에서 끄기가 알림 없이 풀리는 경우와 레포 규칙이 요구하는 은퇴 공시가 열린 질문에도 위험에도 없다 — 옛 변수를 한동안 함께 읽을지, 공시만 하고 바로 없앨지가 정해지지 않았다 (D21 · D22 · OQ32).
- D1.2 · r1 · adopt · a6484ced#r1.1 · "고친다 — 고른 항목만, 나머지는 묻기 (권장)" — 공식 자료는 따라야 할 기준이 아니라 참고라는 Non-goal 과 그 뒤에 쌓인 「공식대로」 결정들이 나란히 확정돼 있어, 아직 묻지 않은 자리에서 공식 쪽이 기본인지 항목마다 따로 정하는지가 두 갈래로 읽힌다 (Non-goal 둘째 줄 · C7 대 C19 · C20 · D21 · C28).
- D1.3 · r1 · adopt · abf668a4#r1.1 · "고친다 — 방향 유지, 실측 넓히기 (권장)" — 기록 성격의 상태(문서 리뷰 원장 · 지휘 기계 상태)까지 공식 데이터 폴더로 옮기는 방향은 공식 문서와 어긋난다 — 문서는 그 폴더의 쓰임을 의존성 · 생성 코드 · 캐시로 적고, 프로젝트가 아니라 플러그인 단위로 두며, 작업 폴더 밖이라 읽기에 승인이 드는 자리다 (D21 · C28 · C30 · D31).
- D2.4 · r2 · adopt · abf668a4#r2.1 · "고친다 — 이름만 필수, 경고를 규칙에 적기 (권장)" — plugin.json 필수 키를 완화한다는 방향은, 판 번호를 남기기로 한 뒤에는 실제로 풀리는 것이 description 하나뿐이고 공식 검증 명령은 그 키가 없으면 경고를 낸다 — 필수 키 규칙을 지금대로 두거나, 그래도 name 만 필수로 푼다 (D18 · D24)
- docreview 계수 — spec-distill-59ec298a/2026-11-14-framing-interview-constraint--053d33aa615ef286 r1: advice_new=1 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-framing-interview-constraint--053d33aa615ef286 r2: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
- docreview 계수 — spec-distill-59ec298a/2026-11-14-framing-interview-constraint--053d33aa615ef286 r3: advice_new=0 · advice_repeat=0 · mc_preexisting_new=0
