# 흐름 고정 점검 (2026-10-17)

사용자 원칙: 「내가 앞에 말한거랑 이거랑 다 가능성을 제약하여 유연함을 잃는 사례거든 중요하니 이런게 발생하지 않도록 주의해줘 앞으로도, 다만 정석 파이프라인 흐름은 있긴 하겠지 brainstorming같은 외부에서 시작하면 plan -> 구현 이 순서로 가는게 의도인거야 의도를 무시하진 말아야 겠지.」 · 「또 고정한걸 풀을곳은 없을까 devbrew에서」

고치는 꼴: 「언제나 X」 를 「기본은 X, 일의 모양이 다르면 모델이 판단해 고르고 무엇을 왜 골랐는지 적는다」 로. 아래 「유지」 는 load-bearing 이라 풀지 않는다 — Law 2 · `tools:` allowlist · 리뷰어 입력 격리 · kill switch · 사용자 승인 게이트(P17)와 AP2 · 루프 상한 · 보안 · 정확성 검사 · Law 1 의 필수 구조 · security-reviewer 웹 금지(P21).

## 사용자 결정 (원문)

- 넷 모두 기본값 + 모델 판단으로: 「에픽 실행 방식 SDD 고정, 「끝에 할 일 하나」, Law 1 의 중간 단계, qg 리뷰어 모델 opus 고정, 1번의 경우 writing plan이 끝나면 권장 실행 방식이 있을거야 subagent driven이라고 되어있는걸 권장 구현 방식으로 간다고 해둬」
- 인터뷰 조사: 「1, 일단 조사의 경우 흐름을 너무 강제하기보다 모델이 알아서 서브에이전트 여러개 띄워서 조사도 돌릴 수 있게끔 열어주자 물론 기존에 있는 방식에 더하는 방향으로」
- 인터뷰 끝 게이트: 「새 인터뷰 에픽에 함께 (권장)」 · 「new 권장 말고 compact 로 가자」

## 결함 (고정이 아니라 틀린 것 — 먼저 고친다)

| 자리 | 무엇 | 받는 곳 |
|---|---|---|
| `shared/docreview/scripts/docreview_route.py:42, :852` | 같은 이름 블록이 여럿이면 `ms[-1]` 마지막만 읽고 `--critic` 은 하나만 받는다 — 탐지 리뷰어를 여럿 열면 앞의 지적이 원장 계수 없이 사라진다. 여럿을 열기 **전에** 고친다 | R2a |
| `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:210-211` | 「adversarial 도 egress 도구를 가진다」 — 실제 `tools:` 는 Read · Grep · Glob | R2a |
| `plugins/quality-gates/README.md:16` | 지운 「authoring-time hard-review」 게이트를 아직 인용(이전 sweep #112 의 미룬 항목) | R2a |

## 받는 곳별 — 풀 것

### 새 인터뷰 에픽 (재분해로 만든다)

**설계 입력 — 신선하고 믿을 만한 근거 (사용자 원문, 2026-10-17).** 조사를 열어 두는 이유가 이것이다: 「이거도 인터뷰 에픽에 추가해줘 고려해보게, 서브에이전트 조사 막 시키는게 이러한 이유야(라운드나 제약이나 형식이런거 제한 있으면 모델이 잘 못하는거도 있을거고」

> LLM이 사용하는 지식은 오래되어 있는게 대부분이다, `/interview` 과정에서 현재의 그리고 최신의 신선한, 신뢰할 수 있는 근거를 새로운 컨텍스트로 제공해야 한다. 예를 들어 패키지 버전, 변경·폐기된 API, 최신 공식 문서와 다른 사용법뿐 아니라 제품 정책, 표준, 제도 등 개발 외 영역의 시의성 있는 지식도 대상이다.(예시에 한정되지 말아줘) 잘못된 지식이 활성 컨텍스트에 그대로 남아서는 안 된다. 자연스러운 설계를 제안해줘.
> 다만 다음 원칙은 지켜야 한다.
>   - 모델이 자신의 지식이 오래되었는지 정확히 안다고 가정하지 말고, 시간에 따라 변할 수 있으며 현재 결정에 영향을 주는 사실을 검증 대상으로 삼는다.
>   - 조사 에이전트가 잘못된 지식을 가져왔을 수 있으니 항상비판적으로 봐야한다. 향후에도 항상 검증을 통해 뒤집힐 수 있는 컨텍스트이며 조사해온 내용으로 인해 잘못된 방향으로 빠지면 안된다
>   - 기술 정보는 현재 프로젝트가 실제로 사용하는 버전과 최신 upstream 버전을 혼동하지 않는다.
>   - 최신과 신뢰성 간 스윗포인트를 생각해야하며 사용자에게 선택지를 줄 수 있어야 한다 모델이 혼자 결정하지 않음
>   - 가능한 경우 공식 문서와 1차 자료를 우선한다.
>   - 확인하지 못한 내용은 현재 사실처럼 단정하지 말고 불확실성을 드러낸다.
>   - 조사 능력을 제한하는 임의의 검색 횟수·출처 수 상한이나, 형식만 채우는 무거운 게이트를 추가하지 않는다.
>   - 사용자 판단과 외부 사실의 교정을 구분하고 기존 사용자 결정권을 유지한다.

설계 때 이 원문과 지금 장치(R1 의 조사 주장 계약 V1 · `repo_claims` · 웹 항목 줄 · 조사 상한 20 · 포화 판정자 · request-framing 의 「다시 검증할 것」 문단)가 어디서 맞고 어디서 부딪히는지 먼저 대조한다 — 특히 「임의의 검색 횟수 상한을 두지 않는다」 와 지금의 조사 상한(루프 상한으로 둔 것)의 관계는 설계에서 사용자에게 묻는다.

- 조사 subagent 를 모델 판단으로 여럿 동시에(기존 방식에 더함) — `skills/spec-interview/SKILL.md:303-313`. 함께: 포화 판정의 「최근 두 항목 · 시간 순」 을 묶음 단위로(`agents/saturation-judge.md:44, :52-57`, `references/saturation.md:61`), 동시 묶음의 상한 계수 정의.
- 라운드마다 질문 1개 고정 — 기본 1개, 독립 결정은 한 호출에 묶을 수 있게(본체 직접 조사의 상한은 먼저 따로 세운다) — `SKILL.md:185, :193-195, :313`.
- 첫 조사 순서와 R1 대기 · landscape 를 웹으로만 닫기 — floor 는 유지, 시점은 모델 판단, 「외부 선례 무관 — <이유>」 를 사용자 S 로 닫는 길 — `SKILL.md:304, :327-329, :396, :429/:443` (check_brief 손봄).
- 포화 판정 최소 조사 2회 — 판단 경로뿐이면 「조사 불필요」 제안을 사용자 S 로 닫는 길 — `references/saturation.md:61`.
- request-framing 의 웹 금지 — 기본 금지, 레포로 설명 안 되는 이름은 짧은 조회를 audit 에 남기고 seed 밖으로(DISABLE_WEB 확인을 그 자리에) — `skills/request-framing/SKILL.md:265-272`.
- request-framing 의 다음 단계가 인터뷰 하나뿐 — 기본 인터뷰, 모델 제안 대안을 이유와 함께 — `SKILL.md:962-968, :989-994`.
- 인터뷰 끝 게이트: 분해된 일의 ①② 이름이 「…후 brainstorming」(실제는 지휘 줄) — `references/finishing.md:414-415`. 분해된 일의 다음 세션 줄이 에픽마다 brainstorming 고정 — `finishing.md:556`. /compact 권장은 그대로.
- 하나짜리 brief 의 다음 단계 표기: `next_phase: superpowers:brainstorming` · §7 · brief 정의가 「brainstorming 용」 — 기본 경로로 두되 유일 경로가 아니게 — `finishing.md:73`, `templates/interview-brief-template.md:7, :33, :111-113`, `SKILL.md:107`.
- readback 의 닫힌 여섯 클래스에 「그 밖」 — `skills/reviewing-brief/SKILL.md:641`.
- trivia 판정의 닫힌 패턴 5개 · 「<10 토큰」 — 예시로 낮추고 기준은 P12 의 「한 문장으로 설명 가능한가」 — `references/trivia-escape.md:11, :20`.
- steelman 「셋 중 하나」 · 「2-4줄」 — 예시로 — `agents/steelman-builder.md:63-64, :88-89`.

### R5 지휘자
- 지휘 절차 4 의 실행 방식 — 「writing-plans 가 계획을 마치며 권하는 실행 방식으로 간다」(사용자 결정). 템플릿 4 도 같은 뜻으로(`templates/roadmap-template.md:20`).
- 에픽 넘김 줄의 brainstorming 고정 풀기 — 기본 정석, 조사 · 측정 · 결정 에픽은 모델 판단 — `references/epic-handoff.md:7`, `templates/roadmap-template.md:18`. 에픽 종류에 조사 · spike 를 더할지(`finishing.md:55`).
- 「묶음을 다시 나누지 않는다」 → 「나눠야 할 근거가 보이면 redecompose 로 보고한다」 — `epic-handoff.md:7`.
- 재분해 신호 「셋」 → 열린 목록(계획 · 구현 세션이 경계 오류를 찾는 경우 포함) — `references/redecompose.md:9`.
- 구현 대조(`--impl`)와 다음 세션 줄의 「SDD 의 마지막 전체 리뷰」 가정 → 「고른 실행 방식의 마지막 전체 리뷰(또는 조사 산출의 AC 대조)」 — `epic-handoff.md:7`, `skills/spec-review/SKILL.md:620`, `finishing.md:439`.
- spec-review 게이트 ③ 「인터뷰 다시 열기」 를 로드맵 에픽에서 늘 재분해로 — 이 에픽 안에서 끝나는 지적이면 진짜 인터뷰 재개도 고를 수 있게 — `skills/spec-review/SKILL.md:608`.
- 이 세션에서 계속(①/② 없이) 선택지를 둘지 — `references/proceed-gate.md:30-37` · CLAUDE.md polite handoff 와 함께, 설계 때 사용자에게 묻는다.

### R2a 공유 엔진 · qg 파급 · persona 보안 리뷰
- 탐지 리뷰어 1명 고정(`detectors != 1` 거부) → 기본 1, 선언하면 N — `shared/docreview/scripts/docreview_state.py:144`, `shared/docreview/references/reviewing-document.md:18`, `plugins/quality-gates/references/docreview-profiles/generic.md:2` (위 결함 먼저).
- qg 리뷰어 구성표(최대 8, 기계 신호로만 고름) → 기본값, 모델이 근거와 함께 더할 수 있게 — `plugins/quality-gates/skills/quality-pipeline/SKILL.md:286-299`.
- 같은 리뷰어 다시 부르기 금지 → 일시 실패 1회 재시도 · 선언된 분할 병렬 — `quality-pipeline/SKILL.md:1070-1071`.
- 「changed code only」 → 「위치는 diff 밖이어도 원인은 이 변경」 — `quality-pipeline/SKILL.md:353`, `agents/security-reviewer.md:112` (persona 편집 — 보안 리뷰).
- 「documentation paths excluded」 정의 없음 → 행동을 정하는 .md(SKILL · agents)는 포함 — `quality-pipeline/SKILL.md:217, :338`, `agents/security-reviewer.md:40`.
- qg 리뷰어 모델 opus 고정 → 세션 모델을 따르게(사용자 결정) — `agents/security-reviewer.md:6`, `agents/code-recritic.md:13` (persona 편집 — 보안 리뷰).
- 문서 비평: 대상 하나 · 커밋 강제 · 디스패치 수 고정 → 읽기 전용 다중 대상 · 「지적만 받기」 선택지 · 기본값으로 — `skills/critiquing-artifacts/SKILL.md:74, :144, :151, :258`.
- e2e 시나리오 단일 선택 → multiSelect — `references/e2e.md:34`.
- 토픽 선언이면 trivia 우회 불가 → 토픽 diff 전체가 trivia 면 허용 — `quality-pipeline/SKILL.md:164-172`.
- 차등 테스트 밖 스위트 실행 금지 → 판정 입력이 아닌 조사용 실행 허용 — `references/differential-test.md:130`.
- qg 로 통합 리뷰를 할 때 걸리는 점(사용자 제안 「아님 qg를 활용해도 되고」): 문서 위주 변경은 clean 이 안 나옴 · 여러 브랜치 동시 불가 · 리뷰만 하는 모드 없음 · 열린 PR 코멘트 자동 게시. R5 설계와 함께 본다.

### R9 규칙 · 문서
- 「끝에 할 일 하나」 → 기본 하나, 여럿이거나 병렬이면 그렇다고 밝힘 · 커밋 · PR 본문은 순서 규칙에서 뺌(사용자 결정) — `shared/style/plain-language.md:5` 와 모든 skill 의 같은 블록.
- Law 1 의 trivia / 전체 명세 이분법에 중간 단계 — 중간 크기 일은 기본 경로(설계→계획→구현)에 더해 이유를 밝힌 가벼운 꼴(PR 본문 계획 · 짧은 brief)을 고를 수 있게(사용자 결정, 헌법 변경) — `CLAUDE.md:24`, `docs/philosophy/devbrew-harness-philosophy.md:43`.
- 「버그가 새면 해결책은 persona 편집」 → 기본 persona, 락 · 스크립트 · 메모리가 더 맞으면 그것 — `CLAUDE.md:91`.
- 「먼저 로드 / 진입할 때만 로드」 등 특정 skill 강제 → 기본 경로 — `CLAUDE.md:76`, `docs/plugin-authoring.md:42-48`.
- project-init: AGENTS.md 이전 거절 시 전체 중단 → 「CLAUDE.md 에 바로 쓰기」 선택지 · 헌장 단계 건너뛰기 선택지 · Phase 0 스캔은 질문과 겹쳐 돌려도 됨 — `plugins/project-init/skills/project-init/SKILL.md:48, :65, :119, :121, :147-164, :201`.
- 브랜치 접두 `feature/` · `fix/` 고정 · 「ALWAYS 브랜치 확인」 — 접두 선택지(`docs/` · `chore/`) · 확인은 변경 작업일 때만 · worktree 경로 — `plugins/project-init/hooks/post-tool-use.py:144`, `docs/git-workflow/branch-strategy.md:12, :32-38, :57-61`, `plugins/project-init/templates/*/branch-strategy.md:57-61`.
- plugin-audit 6축 고정 → 동의 게이트에서 축 일부만 고르는 모드 — `plugins/plugin-audit/scripts/audit-workflow.js:295, :498`.

### 이 로드맵 (다음 로드맵 PR)
- 지휘 절차 8 「쓰기 도구가 없는 리뷰어 하나」 → 「하나 이상, 동시에, qg 사용 가능 — 쓰기 도구 없음은 유지」.
- 지휘 절차 4 실행 방식 → writing-plans 가 권하는 방식(사용자 결정).
- 지휘 절차 9 끝에서 끝 확인을 한 경로로 고정 → brainstorming 을 거치지 않은 에픽의 경로도 걸어 본다.

## 메모리 (지휘자가 2026-10-17 고침)
- SDD 「엄격 순차 · 병렬 금지」 → 한 task 안은 순서, 독립 task 는 worktree 를 나눠 동시 가능(판정 전 기록 금지는 유지).
- 「설계 진입 시 deep-research 로 prior-art」 → prior-art 확인이 기본, 방법은 모델 판단, deep-research 는 명시 요청 때만.
- version bump 「같은 커밋서」 → bump 는 PR 마다, 번호는 머지 직전.
- 계획 리뷰 「≥2 라운드 · 계획 파일에 Self-Critique 이력」 → 멈출 조건으로 라운드 수, 이력은 계획 파일 밖.
- 「findings → 편집 사이 adversarial 반드시」 → 여러 건 · 가드 제거 수정이면 기본, 작은 기계적 수정은 판단.
