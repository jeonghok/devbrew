# spec-distill

> 흐릿한 요청을 인터뷰로 다듬어 brainstorming 에 넘길 brief 로 만들고, 설계문서는 문서를 고칠 수 없는 독립 리뷰어가 검토하게 하는 플러그인.

## 이 플러그인이 하는 일

흐릿한 요청을 한국어 인터뷰로 다듬어 brainstorming 에 넘길 문서(interview brief)로 만들고, 그 뒤에 나온 설계문서는 고칠 수 없는 독립 리뷰어가 검토합니다. 인터뷰는 «지금 이해 · 다음 결정 · 질문 하나» 형식으로 진행하고, 필요하면 웹에서 비슷한 사례를 찾고(횟수 제한) 약한 방향은 반대 입장을 가장 강하게 세워 시험합니다(steelman). brief 는 **2파일 쌍**으로 나옵니다 — 본문 `docs/superpowers/interview/YYYY-MM-DD-<topic>-interview.md`(결론부터 쓰는 **8섹션**, `templates/interview-brief-template.md`)와 기록 `…-interview.audit.md`(5섹션, `templates/interview-audit-template.md`)이고, `.audit.md` 이름은 본문 파일명에서 따라 정해집니다. 인터뷰 진행 기록은 같은 줄기의 `…-interview.state.md` 에 남아 새 세션에서 `/spec-distill:pm-interview @<그 파일>` 로 이어 갈 수 있고, 인터뷰가 끝날 때 brief · audit 와 함께 한 커밋으로 남습니다(기본 브랜치에서는 커밋하지 않고 세 경로를 보입니다).

## 쓰는 법

사용자가 부르는 진입 skill 은 다섯입니다.

- `/request-framing` — 요청이 아직 흐릿해서 방향부터 맞추고 싶을 때. 다음 세션 첫 턴이 가리킬 요청 요약 파일(`interview-seed`)이 나옵니다.
- `/pm-interview` — 요청을 인터뷰로 다듬고 싶을 때. 인터뷰 결과를 정리한 문서(interview brief)가 나옵니다.
- `/spec-review` — brainstorming 이 설계문서를 쓴 뒤 검토하고 싶을 때. 문서 리뷰 결과와 다음 단계를 고르는 질문이 나옵니다.
- `/roadmap-status` — 로드맵의 에픽 지도(단계 · 기다리는 에픽 · 경고 · 진행 중 인터뷰 조사 수)를 보고 싶을 때. 읽기만 합니다.
- `/spec-distill:epic-conductor [<로드맵 경로>]` — 승인된 로드맵의 에픽을 이 세션에서 끝까지 지휘합니다(cost_class high — 시작 승인, 같은 세션 · 표지가 살아 있고 · 규모가 글자 그대로 같으면 공시만).

```
/pm-interview todo 앱 만들어줘
```

`pm-interview` skill 이 «지금 이해 · 다음 결정 · 질문 하나» 형식으로 첫 라운드를 시작합니다.

설치 환경에 같은 이름이 있으면 `/spec-distill:pm-interview` 처럼 완전명으로 부릅니다. 기계가 내는 안내(핸드오프 · trivia 문면)는 처음부터 완전명을 씁니다.

`/pm-interview` 는 `@` 로 시작하는 인자에 공백이 섞이면 풀지 않고 멈춥니다(경로 한 토큰으로 다시 부르세요). `/request-framing` 은 그런 인자를 받은 그대로 회의 재료로 씁니다.

## 흐름

아래 그림이 전체 순서입니다. 사용자가 고르는 자리는 «게이트» 로 표시했고, 경고가 있으면 그 질문 바로 앞 글에 적힙니다.

```
/request-framing ─→ [Phase 0] request-framing — 확산 후 압축
                                       · 확산 — 원문 보존 → 레포 읽기 → 질문 라운드 + 풀이 확인 질문 (상한 없음)
                                       · 압축 — check_seed.py 게이트 다섯 (Law 1)
                                       · 검증 — 문서 리뷰 엔진(seed 프로필: 탐지 doc-critic + codex → 재비판 doc-recritic)
                                                · 처분은 사용자가 — 처분 전 편집 금지 · 저자 편집 diff 공시 · 문구 없는 drop 차단
                                                · 냉독 축(seed-readback)
                                       ▼ [확정 — proceed 게이트] ①/compact 후 /pm-interview @경로 · ②/new 후 /pm-interview @경로 · ③수정 필요 · ④멈춤
                                   interview-seed → docs/superpowers/interview/   ← 문서가 아니라 다음 세션 첫 턴이 가리키는 파일
                                       ▼ 다음 세션 첫 턴 = `/pm-interview @<seed 경로>` (진입 단계가 frontmatter 포함 전문으로 풀어 인터뷰에 넘김)
/pm-interview ─→ [0] Trivia escape ─→ [1] Interview (문제공간 stage)
                                       · 지금 이해 · 다음 결정 · 질문 하나 + 3-path (web=path(a))
                                       · R1 사용자 말 그대로 / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ
                                       ▼ 5 의례 통과 (check_brief.py gate, Law 1)
                                   interview brief (payload + audit) → docs/superpowers/interview/   ← terminal 산출물
                                       ▼ [Step A.5]  ※ 구조 게이트를 통과했을 뿐 아직 분리 리뷰 전
                                   [2] reviewing-brief → 문서 리뷰 엔진 (Law 2 분리 리뷰, brief 프로필, cost_class: medium)
                                       │  라운드마다 먼저: 진입 게이트 둘(check_brief.py · check_verbatim_coverage.py) → payload+audit 번들
                                       ├─ 층 1 방향성 · 층 2 충실도  doc-critic-web(DISABLE_WEB 이면 doc-critic) + codex → doc-recritic
                                       │                라운드 게이트 → 저자 수정 → 다음 라운드 (재리뷰 상한 2)
                                       └─ 냉독    brief-readback  (엔진 밖 advisory, G1–G7 gap)
                                       ▼ 산출물 셋 (엔진 게이트 결과 / 냉독 요약+gap / degrade 채널)
                                       ▼ [Step B proceed 게이트] ①/compact 후 다음 세션 줄 · ②/new 후 다음 세션 줄 · ③확정 목록 수정 · ④brief만 종료  (superpowers 있을 때만)
                                   superpowers:brainstorming → -design.md
                                       ▼ brainstorming 이 설계문서를 쓰고 커밋 · 설계문서 점검(builder check)과 그 질문 — 그 뒤 문서 승인 자리
                                       ▼ 오케스트레이터가 그 경로로 spec-review 호출 (핸드오프 지시 · description — 훅 강제 없음)
                                   [3] spec-review → 문서 리뷰 엔진 doc-critic → doc-recritic (Law 2, design-mode only)
                                       ├─ approval_gate_open → [5] proceed 게이트 → 재리뷰 상한 2 → writing-plans  (지휘 세션이 돌린 로드맵 에픽은 승인 질문 하나 → 같은 턴에 계획 담당자)
                                       └─ round_gate_needed(decide 묶음 + 차단 ask) → brainstorming author 수정 → fresh 재리뷰
```

인터뷰가 끝나면 brief 를 쓰기 전에 일을 spec 하나로 할지 나눌지 사용자가 정합니다(분해 판단). 나누면 로드맵과 에픽 묶음이 함께 만들어지고, 다음 세션은 그 로드맵의 지휘 절차로 시작합니다.

## Principles Instantiated

이 플러그인이 instantiate하는 devbrew 철학.

### Three Laws

- **Law 1 (Clarity Before Code)** — 이 플러그인이 있는 이유다: 명세가 모호하면 구현으로 가지 않는다. 인터뷰 → brief → design doc → reviewer → human gate. **설계문서에는 필수 섹션 구조 게이트가 없다** — 설계문서의 명확성은 `doc-critic` 층 2(`placeholder`·`ambiguity`)와 승인 게이트가 판정한다 — 이 리포의 Law 1 필수 섹션 게이트 구현은 0 이다.
- **Law 1 (Clarity) — 문제공간 게이트** — 인터뷰가 끝나려면 다섯 가지 확인(R1–R5: 사용자 말 그대로 · 사례 조사 · 반대 입장 시험 · 해보고 버린 것 · 열린 질문)을 거쳐야 하고, 그것을 `check_brief.py`로 기계가 검사하는 구조 게이트다. 약한 방향(무인용 landscape·un-challenged 의심·빈 시행착오)은 brief 종료를 차단. 종료는 고정 라운드 수가 아니라 커버리지 원장(고정 floor 5 + 주제에서 도출한 차원, status ∈ {open, in-progress, closed})이 정한다.
- **Law 1 — 진입 skill 의 본문 전 사전 검사(`!`)가 kill switch 를 모델 판단 밖에서 집행한다.** 끄기로 해 둔 기능은 모델이 마음을 바꿔도 돌지 않는다는 뜻이다 — skill 본문을 읽기 전에 정해진 검사가 먼저 돌아 스위치를 확인한다.
- **Law 1 — 허용 문법 판독기(`brief_body`)** — brief · audit 는 `scripts/brief_body.py`, seed 는 `scripts/seed_body.py` 가 각자 허용 문법 하나로 읽고 문법 밖은 해석하지 않고 거부한다. 기계가 쓰는 글이라 꼴을 막는 정규식을 늘어놓지 않고 읽는 쪽을 하나로 둔다.
- **Law 2 (Writer/Reviewer 분리)** — `tools:` allowlist frontmatter로 doc-critic(`Read, Grep, Glob`) + doc-critic-web(`Read, Grep, Glob, WebSearch, WebFetch`) + doc-recritic(`Read, Grep, Glob`) + coverage-mapper(`Read, Grep, Glob, WebSearch, WebFetch`) + blind-spot-prober(`Read, Grep, Glob, WebSearch, WebFetch`) + repo-researcher(`Read, Grep, Glob`) + open-researcher(`Read, Grep, Glob, WebSearch, WebFetch`) + saturation-judge(`Read, Grep, Glob`) agent의 *물리적* 분리. 프롬프트가 아닌 frontmatter scoping이며, **허용할 도구만 적는 방식이라 적지 않은 쓰기·실행·위임 도구는 자동으로 막힌다**(막을 도구만 적는 방식(denylist)은 내일 생길 도구를 오늘 적을 수 없어 기본값이 열림이 되므로 쓰지 않는다).
- **Law 2 — 리뷰 진입은 집행이 아니다** — 설계문서 리뷰 진입에 훅 강제가 없다. brainstorming 뒤·writing-plans 앞에 `spec-review` 를 부르는 것은 오케스트레이터이고, 근거는 인터뷰 핸드오프 문구(`finishing.md` 의 다음 세션 줄, brief 템플릿 §7)와 이 skill 의 description 이다 — 철학 P13(hook = 집행 / skill = capability 표면) 기준으로 이 자리에는 집행이 없다. `/brainstorming` 직접 경로는 description 하나에 기대므로 건너뛰는 일이 흔할 것이다 — 그때는 `/spec-distill:spec-review <경로>` 로 부른다. 리뷰어의 물리 분리(`tools:` allowlist)는 그대로다.
- **Law 3 (Compounding) — 처분 회계(adjudication `Ledger`)** — 리뷰가 찾은 결함을 버릴 때마다 장부에 남겨 조용히 사라지지 않게 한다. 버려지는 자리가 `shared/adjudication/adjudication.py` 의 처분을 부른다. 소비자는 문서 리뷰 엔진의 `scripts/docreview_route.py`(`shared/docreview/` 심볼릭 링크 — design doc · brief · seed 세 자리의 finding 이 여기서 라우팅된다) 등이고, 전수 목록은 `tools/adjudication/check_wiring.py` 가 import 로 도출한다 — 여기서 열거하지 않는다. 집행은 `shared/tests/test_adjudication_{wiring,consumed}.sh`. **범위**: `consumer=orchestrator`/`human` 인 dispatch 자리는 `disclosure=` 리터럴 실재까지만 검사된다(CLAUDE.md 축 C 한계) — 이 플러그인의 앵커 다수가 그쪽이다.
- **Law 2 (입력 오염 차단) — `input_slots`** — 리뷰어가 받는 입력에 앞선 판정이나 점수가 섞이지 않게, 이 플러그인의 agent 열이 frontmatter 에 받는 입력의 `tag`/`var`/`kind` 를 선언한다. 금지 종류(`prior_verdict`·`score`·`orchestrator_framing`)는 C6 인용과 함께 `tools/adjudication/check_slots.py` 의 `EXEMPT_SLOTS` 등재(면제 목록)를 요구한다 — `blind-spot-prober.framing` 이 그 하나다(맡은 일이 오케스트레이터가 모은 framing — 사용자 원문과 확인한 사실 — 을 따지는 것이라서). 집행은 `shared/tests/test_agent_input_slots.sh`.
- **Law 3 (Compounding)** — 설계문서가 이름이 있고 git 이력이 남고 달라진 곳을 볼 수 있는 파일이라서, 다음 세션이 그것을 찾아 이어받을 수 있다. 설계문서 `docs/superpowers/specs/…-design.md` 자체가 named, git-versioned, diff-able artifact (P5).
- **Law 3 (Compounding) — model diversity** — 서로 다른 모델이 같은 문서를 따로 읽게 하려고 codex 가 문서 리뷰에 나란히 도는 공동 리뷰어로 참여한다. codex가 Claude persona가 반복해 놓치는 결함류(fail-open)를 잡으면 → 그 자리의 persona 파일(`shared/docreview/agents/doc-critic.md`) 편집이 compounding 이벤트.
- **Law 1 (Clarity) — 핸드오프 게이트** — 인터뷰는 매 라운드 사용자가 실제로 답한 것을 `user_statements` 에 판정 없이 기록하고, brief 구조 검사는 두 파일을 모두 읽어 하나라도 못 읽으면 통과시키지 않는다(**2파일 fail-closed**). payload frontmatter `audit_file`(basename만, traversal 거부)로 audit을 해석하고, 못 열면 payload-only로 degrade하지 않고 red를 낸다. `user_sourced_items` 스키마 + 세 bijection(A: payload §5 ↔ audit §3 / B: body §2 ↔ frontmatter — statement 내용까지 / C: `evidence: S<N>` → payload §6 ∪ audit §6)이 라벨과 내용이 어긋나는 drift를 기계로 잡는다.
- **P17 (User sovereignty) — 확정 권한 반환** — 무엇이 확정인지는 사용자가 인터뷰 끝에 한 번에 정한다. 라운드마다 결정을 잠그지 않고 `status: confirmed`를 **종료 시 사용자 일괄 확인**으로만 발생시킨다. 확인은 새 의례가 아니라 기존 proceed 게이트에 흡수돼 상호작용이 1회로 유지된다(trivia ceremony 회피). 재제시에는 상한 2회가 있고 닿은 뒤 다시 고치려 하면 강등하지 않고 계속 고칠지 · 지금 목록으로 확정할지 · brief 만 종료할지를 사용자에게 묻는다(Unbounded-autonomy 가드).
- **Law 3 · P17 — 인터뷰 조사 열기 (R10)** — 인터뷰의 조사는 모델이 판단해 서로 기대지 않는 것을 여럿 동시에 띄우고, 필요한 조사를 만들어 보낸다(`open-researcher`). 비상 끝은 띄운 agent 수의 상한이다(기본 60 · 닿으면 사용자가 늘릴 수 있다). 신선한 근거 원칙 여덟(`references/fresh-evidence.md`)은 게이트가 아니라 기본 행동이고, 멈춤의 주인은 여전히 포화 판정자와 사용자다.
- **덜어 낸 것은 보인다 (R2)** — seed 압축 · 확정 후보 · 리뷰 참고 · 라운드 요약이 덜어 낸 것을 사용자가 보는 자리에 한 줄로 공시하고 되살릴 길을 준다(압축 규약 `references/compression.md`).
- **Law 2 (brief 자리)** — brief 를 쓴 쪽이 자기 brief 를 승인하지 못하도록 읽기만 하는 리뷰어가 따로 검토한다. `reviewing-brief` 가 `shared/docreview/` 엔진의 두 번째 껍데기다. 탐지 `doc-critic-web` → 재비판 `doc-recritic` 이 층 1(방향성) · 층 2(충실도)를 한 라운드에서 보고, 둘 다 `tools:` 에 쓰기 · 실행 · 위임이 없다. 3중 분리: (a) **리뷰어 도구 분리** — `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 이면 선택 펜스가 웹 도구 없는 `doc-critic` 을 지명한다(dispatch 는 지명된 블록을 따르고 그 선택을 강제하는 훅은 없다 — 물리적인 것은 그 사본의 `tools:` 에 웹 도구가 없다는 것뿐이다), (b) **입력 격리** — 탐지 · 재비판은 번들의 내용을 받고 냉독 `brief-readback` 은 `tools: []` 로 payload 전문만 받으며, 네 페르소나 모두 원문 블록을 데이터로 읽는다(주입 경계), (c) **수정 후 재리뷰** — 저자 수정은 다음 라운드의 fresh 탐지를 거친다(재리뷰 상한 2, 라운드 4 이상은 사용자 문구로 승인) — writer 가 자기 수정을 승인하는 경로가 없다.
- **Law 3 (brief 자리)** — 리뷰가 놓친 결함은 다음 리뷰가 잡도록 검사 기준 자체를 고쳐 쌓는다. brief 프로필(`references/docreview-profiles/brief.md`)의 충실도 범주 여섯(`layer_rubric.layer2`)과 냉독 gap 클래스 G1–G7 가
  compounding substrate다. 리뷰가 놓친 결함류가 나오면 그 프로필과 페르소나를 편집하는 것이
  compounding 이벤트다 — codex 도 같은 프로필 본문을 받으므로 한 곳을 고치면 두 판정자가 함께 바뀐다(persona = 보안-민감 코드).
- **Law 2 (seed 자리) — 처분 주체는 사용자 (request-framing)** — 요청 요약(seed)의 리뷰 지적을 받아들일지는 사용자가 정하고, 저자가 먼저 고치지 않는다. Phase 0 seed 를 `shared/docreview/` 엔진의 셋째 껍데기로 리뷰한다(탐지 `doc-critic` + codex → 재비판 `doc-recritic`). seed 는 헤딩이 없어 엔진의 얼림 · 보호가 꺼지므로 차단은 호스트가 진다: 저자는 사용자가 처분하기 전에 seed 를 편집하지 않고, 엔진이 게이트를 열지 않는 `fix` · `ask` 도 사용자 앞에 올리며, 저자 편집은 기준 사본 diff(`scripts/seed_edit_diff.py`)로 라운드 게이트와 확정 게이트 앞에서 덩어리마다 처분받고, 문구 없는 `drop` 은 진행을 막는다(`scripts/seed_review_log.py`). 형성 라운드의 풀이는 공시가 아니라 양의 선택 질문으로 확인받고 압축이 고친 문장의 확인 표시는 떨어지며(`scripts/seed_provenance.py`), Phase 1 은 audit 원문과 대조해 출처와 확인을 두 축으로 가른다. **한계**: 차단은 엔진의 기계적 거부가 아니라 호스트의 단계 순서 + 관측이다 — 어긴 편집은 다음 공시에서 반드시 보이고 보이면 멈추지만, 엔진처럼 거부하지는 않는다.
- **「공시와 차단은 다른 술어」 — 리뷰되지 않은 라운드** — 리뷰가 제대로 돌지 못한 라운드는 «통과» 처럼 보이지 않게 그 사실을 맨 앞에 알리되, 알린다고 해서 모두 진행을 막지는 않는다. 엔진이 critic 사망 두 번 · `finalize` 실패 · 라우팅 보고서가 없는 라운드를 결정론으로 알고 게이트 요약에 싣는다(`unverified` · `approval_label` · `round_reviewed` · `unreviewed_reason`). 「미검증」(critic 사망 · `finalize` 실패)은 승인 게이트를 그 라벨로 연다. 「미검증」이 아닌 `unrouted` 는 공시만 한다: 게이트 첫 줄이 「이상 없음」·「경고 없음」일 수 없고 「다음:」 줄에 꼬리가 붙는다. brief 자리는 같은 값을 Step B 로 싣고, 엔진 밖의 강등(진입 게이트 강등 · 냉독 실패 · brief 리뷰 skip 등)은 state 의 `brief_review_degradations` 원장으로 함께 싣는다 — 돌지 못한 검사가 통과한 검사로 집계되지 않는다.
- **Law 3 (Compounding) — 문서 리뷰 엔진** — 문서 리뷰 자리(design doc · brief · seed)가 같은 공용 엔진 `shared/docreview/` 를 쓴다. 처분(decide·ask·fix·defer·drop)이 finding 의 수신자를 정하고, 회귀는 편집 범위·얼림·보호 부류로 막는다. 한 번 보호된 절은 다른 절 밑으로 밀려나도 보호가 이어지고 이후 변경마다 다시 묻는다. 보호된 절의 제목을 바꾸거나 절을 지우면 그 바꿈을 보호 절의 변경으로 묻는다. 엔진 값이 허용 범위를 넘으면 라운드를 시작하지 않고, 불변 절의 「추가만」 면제는 새 목록 항목(`- `)을 더할 때만 받으며, 닫힌 리뷰의 결정 기록 끝에 손으로 쓴 줄은 기록으로 읽고, 원장 쓰기 순서 락은 절차 산문까지 본다. 집행은 `shared/tests/test_docreview_*.sh` + 변이 매트릭스.
- **「판정기가 항목을 버리면 센다」 + fail-closed** — 엔진은 항목을 조용히 버리지 않고 검사를 열린 채 통과시키지 않는다. 승인 차단은 역방향 스캔이 아니라 **전방 포인터**(`superseded_by`)로 판정하고, 소비되지 못한 재상승 예약·어휘 밖 재비판 verdict·`same_as` 허상 타겟은 버리지 않고 `reraise_unconsumed`/`coerced` 로 **센다**. 영구 차단에는 사용자 탈출구를 주되 「보류」는 거부한다 — 재상승 후속에도 같은 가드가 걸리고(제안하는 선택지와 받아주는 선택지가 한 함수에서 나온다), 후속은 원본의 `kind`·`prev_hash` 를 물려받아 원복 의무가 강등되지 않는다. `escalated` 예약도 재상승 예약과 같은 누적·dedup·계수 규칙을 따르고, 상태 축의 정본 표(`is_open`·`gate_summary`·`render_gate` 를 한 표에서 도출)가 «막는 집합 ⊆ 그리는 집합»을 구조로 보장한다. 집행: 실제 `fin.json`+state 골든 동치(`shared/tests/test_docreview_golden.sh`) · 단언 수까지 대조하는 전수 스위트 · 셀마다 diff 규모를 선언해 앵커 소실을 계측기 고장으로 잡는 변이 매트릭스.
- **Law 2 (Writer/Reviewer 분리) — design doc 자리** — 설계문서 리뷰는 공용 문서 리뷰 엔진 위에서 돌고, 리뷰어는 문서를 고칠 수 없다. `spec-review` 가 `shared/docreview/` 엔진의 껍데기다. 리뷰어는 `doc-critic`→`doc-recritic`(둘 다 `agents/*.md` 에 `# copy-of:` 마커로 바이트 동일 배포, `tools: Read, Grep, Glob` 뿐 — 심볼릭 링크 agent 는 dispatch 되지 않는다는 실측 때문에 사본이다) 이고, 승인은 verdict 없이 게이트 판정(`approval_gate_open`)의 집계로 도출된다. **능력의 빈자리를 공시한다** — design-doc 리뷰에는 외부 prior-art 대조가 Claude·codex 양쪽 모두 없다(`design-doc.md` 프로필 `web: false`). **집행 없는 kill switch 는 이름조차 남기지 않는다(P21)** — 집행 지점이 없는 옛 handoff 우회 스위치(이름은 `CHANGELOG.md` `[1.0.0]` Removed)는 이 README 에 적지 않고, `test_handoff_kill_switch.sh` 의 부재 판정 코퍼스가 이 README 를 포함해 그 이름이 design 자리 표면에 다시 나타나면 RED 가 난다 — 그래서 이 README 는 그 이름을 리터럴로 쓰지 않는다.
- **Law 1 (Clarity) — 조사가 방향에 닿는가** — 웹 조사에서 나온 주장이 실제로 방향 결정에 쓰였는지 확인한다. 조사 주장의 계약(`references/research-claims.md`)이
  네 자리에 걸리고 검문소 셋(라운드 안 V1 · 종료 누락 대조 V2 · 게이트 V3)이 그것을 집행한다. 게이트의
  술어 다섯은 **전부 ∀ 형태**이고 차단 판정에 개수가 없다 — 재서 **막으면** 사후 장치이고 재서
  **보이면** 공시다. 「조사를
  했어야 했는가」는 기계가 알 수 없고(`check_brief.py` 는 brief 파일만 읽는다) 0건 advisory 가 Step B
  게이트로 사람에게 간다.
- **Law 1 · Law 2 — 멈춤의 주인은 독립 판정자** — 인터뷰가 한 번에 닫지 않고 결정에 닿는 새 사실이 없을 때까지 조사한다. 그 «없음» 을 조사하는 모델이 아니라 쓰기 권한 없는 `saturation-judge` 가 조사 원문에서 직접 판정하고, 「충분해 보인다」는 근거가 아니다. 구조 게이트(`check_brief.py` `saturation_failures`)가 판정 없는 종료를 거절한다. 사용자가 고른 답으로 닫는 두 길에는 한계가 있다: 「조사 불필요」로 포화를 닫으면 게이트는 그 답 번호가 brief 의 사용자 원문 절(payload · audit 어느 쪽이든)에 있는지만 보고 사람에게 확인하라는 참고 줄로 넘기며, 「외부 선례 무관」으로 landscape 를 닫으면 그 답이 고른 선택지(☑)로 적혔는지까지 본다. 둘 다 그 답을 모델이 아니라 사용자가 골랐는지는 증명하지 못한다. 리뷰 진입의 `check_verbatim_coverage.py` 는 두 답이 인터뷰 상태 파일에 고른 선택지(`source: chosen`)로 기록됐는지도 대조하고, 아니면 리뷰를 멈춘 뒤 같은 세션의 마무리 단계가 그 질문을 선택지로 다시 묻는다 — 상태 파일도 모델이 쓰므로 이 대조는 brief 와 상태 파일이 서로 맞는지를 잴 뿐이다. 이 대조는 brief 를 쓴 뒤 리뷰 진입(`check_verbatim_coverage.py`)에서 돈다 — 리뷰를 거치지 않는 길에서는 돌지 않는다. 다시 묻는 길은 인터뷰를 끝낸 그 세션에만 있어, 다른 세션에서 리뷰를 따로 불러 이 사유로 멈추면 끝난 인터뷰라 이어 갈 수 없다.
- **Law 3 (컨트롤 플레인)** — 에픽 단계 · 경고 · 받은 시각을 상태줄과 `roadmap-status` 가 늘 보여, 모르는 사이의 드리프트를 다음 세션이 아니라 지금 본다. 「없음」과 「확인 못 함」(`검사 불가` · `셀 수 없음`)을 섞지 않는다.
- **Law 1 · Law 3 — 나누는 결정이 spec 앞에 있다** — 일을 spec 하나로 할지 나눌지를 brief 를 쓰기 전에 신호를 보이고 사용자가 승인 게이트로 정하며(숫자 컷오프 없음), 로드맵 쓰기는 «쓰고 검증하거나 원래대로 되돌린다» 로 fail-closed 다. 재분해는 승인 뒤에만 같은 로드맵 위에서 일어나 다음 사이클이 같은 지도를 이어 받는다.
- **Law 3 (Compounding) — 로드맵 온톨로지 · 사실마다 주인 하나** — 로드맵이 가장 상류의 정본이고, 객체 · 링크 · 주인을 `references/roadmap-ontology.md` 표 하나에 둔다. 다시 불러도 같은 자리에서 이어 가도록 이어 갈 기록은 git 이 추적하는 설계문서 절에, 이 기계에서만 뜻이 있는 것만 기계 상태에 둔다(`scripts/conductor_state.py`). 링크 칸 이름의 실재는 `tests/test_roadmap_ontology.py` 가 잰다.
- **Law 1 · P17 — 흐름을 고정하지 않는다** — 정석 흐름은 기본값이고 일의 모양이 다르면 모델이 고르되 사용자가 정한다: 에픽 넘김 줄은 블록의 `흐름:` 을 따르고, 재분해 신호는 열린 목록이며, 게이트 ③ 은 로드맵 에픽에서 「이 에픽 다시 설계」 를 고를 수 있고, 진행 게이트는 기타 칸의 「여기서 계속」 을 받는다. 승인 게이트는 설계가 받지 않기로 한 번호를 보여 사용자가 「반영」 으로 되돌릴 수 있다(N18). 문면은 `tests/test_epic_handoff.sh` · `test_decompose_surface.sh` · `test_review_handoff_order.sh` · `test_seed_at_path_handoff.sh` · `test_conducting_reference.sh` 가 잠근다. 인터뷰 끝 게이트는 하나짜리 brief 에서 둘째 질문으로 다른 다음 단계를 고를 수 있고 이름이 고른 단계를 따르며, trivia 는 한 문장 기준이고 패턴은 예시다 — 이 문면은 `tests/test_end_gates.sh` 가 잠근다.

### Principles 흡수

- **한계 — 상태 폴더 쓰기의 링크 (P21)** — 펜스의 상태 폴더 쓰기는 writer(`scripts/nofollow_write.py`)를 거쳐 링크를 따라가지 않는다. 다만 Write 도구로 쓰는 상태 폴더 파일(`said-*.txt` · `readback.txt` · `note-<id>.txt` · `critic*.txt` · `recritic.txt`)은 writer 로 감싸지 못하고, writer 는 마지막 경로 성분만 지키며, 실행 중 다시 심는 링크는 지키지 않는다. 러너의 `write_failclosed` · `_degrade_if_empty` 는 첫 쓰기 뒤라 그대로다.
- **한계 — 원장 정리의 뿌리 (P14)** — request-framing 의 원장 정리와 지휘자는 지금 작업 폴더 레포의 뿌리를 쓴다 — 다른 레포의 문서를 리뷰하는 동안에는 지금 작업 폴더 레포의 원장이 그때 정리되지 않는다.
- **P2 (Ambiguity Gate)** — numerical 거부 (philosophy P2). 설계문서의 모호성은 `doc-critic` 층 2 가 판정한다 — 필수 섹션 구조 게이트는 없다(위 Law 1).
- **P12 (Trivia escape)** — `/pm-interview` first-step rule (판정 기준은 한 문장으로 설명 가능한가 — typo / 주석-only / formatting / rename / 짧은 안전 동사는 예시). 파일 수는 자격 기준이 아니다.
- **P14 (State preservation)** — 인터뷰 진행 기록은 작업 트리의 `docs/superpowers/interview/<날짜>-<주제>-interview.state.md` 에 살아 압축 · 세션 종료 · 다른 세션의 정리로 사라지지 않고, 인터뷰가 끝날 때 brief · audit 와 함께 커밋된다(기본 브랜치에서는 커밋하지 않는다). 이 세션의 옛 `.claude/spec-distill/<session-id>/state.local.md` 가 있으면 인터뷰 진입이 docs 로 옮기고 그 사실을 보인다. 다른 세션의 옛 기록은 그 세션을 이어 열고(`claude --resume`) 인터뷰에 들어오거나, 작업 트리에서 `python3 <플러그인 루트>/scripts/interview_state.py migrate-legacy --session <옛 세션 id> --topic <kebab 주제> [--seed <seed 경로>]` 로 옮긴다. 리뷰 원장은 `.claude/spec-distill/.docreview/<stem>-<hash>/` 에 문서마다 하나라(`docreview_state.py state-dir-for --root --doc`) 세션이 끝나도 남아 라운드를 이어 세고, 위치가 `state_path.state_root()` 하나로 정해져 worktree 에서 불러도 main repo 의 `.claude/spec-distill/` 에만 기록된다(`ExitWorktree action: remove` 로 원장이 조용히 사라지지 않는다). 그 밖의 세션 폴더는 만들지 않는다. 원장 정리는 문서가 사라질 때 한다: 리뷰를 시작하는 진입 셋(spec-review · reviewing-brief · request-framing 의 리뷰)이 원장을 열 때 `scripts/ledger_sweep.py` 가 한 번 돈다 — 기록된 문서가 없고 원장 폴더에 TTL 동안 쓰기가 없는 원장을 지우고, 옛 버전의 세션 폴더 `<session-id>/` 중 `state.local.md` 가 없고 TTL 을 넘은 것을 지우되 그 안의 옛 원장 중 문서가 남은 것은 먼저 `.docreview/` 로 옮긴다. `state.local.md` 가 있는 옛 폴더는 시간과 무관하게 지우지 않고 알린다(아직 docs 로 옮기지 않은 인터뷰 기록이다 — 옮기거나 지우는 일은 사용자 몫이다). 정리는 루트 디렉토리 잠금(`O_NOFOLLOW` 로 연 디렉토리 fd 의 `flock`, 락 파일 없음) 안에서 돈다.
- **P17 (User sovereignty)** — 문서 리뷰 엔진의 **승인 게이트**(정본 `references/proceed-gate.md` — 진행·수정·멈춤을 사용자가 고른다), all kill switches.
- **P17 (User sovereignty) — 사용자가 시계** — 차원은 사용자 발화 `S<N>` 을 인용해야 닫히고(`check_brief.py` 앵커 게이트), 재개방에 상한이 없다 — 재개방은 사용자 답 · 근거와의 충돌로만 일어나고, 조사 총량은 조사 호출 상한(사용자 연장)이 묶는다.
- **P18 (Stagnation detection)** — 라운드 n 의 **열린 계보**(`open_lineages`) 집합이 n−1 과 같고 그 사이 진행이 0 건이면 stagnation 이고, 승인 게이트가 즉시 열린다(`shared/docreview/scripts/docreview_state.py` 의 `gate_summary`). 「진행」은 `check-intent` 를 통과한 fix 적용과 채택 결정의 permit 적용 둘을 센다 — 채택대로 고친 라운드는 계보가 같아도 stagnation 이 아니다.
- **P18 보강 — must-catch 멈춤 기준** — 프로필이 `must_catch` 로 막는 축을 지목하면 그 밖의 rubric 축 finding 은 참고(advisory)로 라우팅돼 승인을 막지 않고 끝에서 한 번 보인다(`shared/docreview/scripts/docreview_advice.py`). 라운드별 계수 줄이 결정 기록 절에 남아 다음 사이클이 must-catch 축의 수렴 가정을 잰다(Law 3).
- **P21 (Secret 기록 금지 / untrusted input)** — 인터뷰 상태 파일(커밋되는 파일이다 — `## 풀린 입력` 블록 포함)의 token/key/credential placeholder 치환. `audit_file`은 frontmatter에서 오는 신뢰 경계 밖 입력이므로 basename으로 제한한다(`../`·절대경로·서브경로 전부 거부).
- **P22 (Cost class)** — 모든 skill cost_class 선언 (pm-interview: variable / request-framing: variable / spec-review: medium / reviewing-brief: medium / epic-conductor: high / roadmap-status: low — medium 인 reviewing-brief 에는 진입 지출 승인 게이트가 없고(epic-conductor 의 high 는 시작 승인 게이트를 갖는다), 재리뷰 상한은 안전 정지이고 승인 게이트에서 사용자가 연다).
- **P23 (Decisions Stay Refutable)** — `request-framing`의 「재결정 규약」 절(정본은 `references/proceed-gate.md`)이 확산에서 확정된 것을 압축 단계가 뒤집을 때 임의 변경이 아니라 근거 제시 + 사용자 동의 + audit *원래/재결정/근거* 세 칸 기록을 강제한다. `pm-interview`도 하류에서 같은 원칙을 잇는다 — `type: interview-seed` 입력을 받고(seed 가 아닌 입력에는 한 줄 안내만 내고 막지 않는다), 인터뷰 중 새 발화가 seed의 확정을 뒤집으면 조용히 덮어쓰지 않고 새 발화가 이기며, §5 기각에 같은 *원래/재결정/근거* 형태로 남는다.

### Roadmap absorption (C-numbers)

- **C43** 3-path Socratic routing (factual auto-confirm / judgment→user / ontological, 라벨 강제 없음).
- **C1** 사용자-발화 floor 탈출구 — Unbounded-autonomy 가드(사용자가 언제든 종료를 요청하면 미충족 floor를 사용자-승인 박제로 닫고 payload §3 Open Questions로 이월).
- **C4** coverage-mapper agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — advisory 주제-도출 차원 제안자) + **blind-spot-prober** agent (`tools: Read, Grep, Glob, WebSearch, WebFetch` — 적대적 premortem). 둘 다 첫 호출은 필수(하한)이고 그 뒤는 조사 호출 상한 하나가 총량을 묶는다.

### Anti-pattern 회피

- **AP3 (Self-approval)** — writer/reviewer 물리적 분리 (frontmatter scoping).
- **AP2 (Polite stop)** — **정본은 `references/proceed-gate.md`**. 두 proceed 게이트(spec-review 의 `## 게이트` 절 · pm-interview 종료 Step B)가 그 파일의 골격·두 가드·예외 경로를 공유하며, 각 skill 은 자기 어휘(옵션 라벨 · 다음 세션 줄 · 고유 스텝)만 인라인으로 갖는다. 아래는 그 계약의 **요약**이지 별개 저술이 아니다 — 계약이 바뀌면 정본을 고치고 여기를 따라 고친다. 다음 단계 추천은 hook(텍스트 주입만 가능)이 아니라 `AskUserQuestion` proceed 게이트로 전한다 — 사용자가 redirect 가능한 approval gate(P17)다. approve tail = proceed 게이트(AskUserQuestion) → 미커밋 확인(`spec-review` `## 게이트` 의 리터럴 펜스 — 미커밋이거나 git 이 확인에 실패하면 advisory 만 내고 아무것도 기록하지 않는다). 게이트를 skip한 narrate-only 종료 금지. cross-compact 조기 진행(①/② 의 두 줄 명령 노출 후 같은 턴에 다음 단계로 직진)도 게이트 P17 우회의 대칭 실패로 금지. interview→brainstorming Step B의 **4옵션**: ①/compact 후 다음 세션 줄 / ②/new 후 다음 세션 줄 / ③확정 목록 수정 / ④brief만 종료. ①·② 의 다음 세션 줄은 `@<brief 절대경로>` 로 시작해 새 세션이 brief 를 붙여 읽는다(정본 `## 다음 세션 명령`) — 전용 handoff 스크립트를 호출하지 않음(brief는 막 검증됨). 질문의 기타 칸에 「여기서 계속」 을 적으면 ①/② 의 고유 단계를 마친 뒤 압축 없이 이 세션에서 다음 단계를 잇는다 — 사용자가 고른 진행이라 게이트를 건너뛴 것이 아니다.
- **AP5 (Trivia ceremony)** — `/pm-interview` first-step trivia escape (한 문장 기준 · 예시 다섯, 정본 `references/trivia-escape.md` — `/request-framing` 도 가리킨다).
- **AP9 (Subagent spray)** — `plugins/spec-distill/agents/` 13종(doc-critic·doc-critic-web·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·repo-researcher·open-researcher·saturation-judge·brief-readback·seed-readback·integration-reviewer·relay-checker). 지휘자(`epic-conductor`)는 fan-out 앞에 규모(남은 에픽 · agent 대략 수 · 순서)를 보이고 승인받는다. 상한이 선언된 것: 조사 subagent 는 조사 호출 상한 하나(기본 60, 사용자 연장) · 문서 리뷰 엔진의 탐지 dispatch 는 라운드당 한 번(critic 사망이면 재dispatch 1회)이고 라운드 수는 재리뷰 상한 2 가 막는다(spec-review · reviewing-brief · request-framing).
- **Law 1 (Clarity) — `steelman-builder` 의심 게이트** — 의심 방향에 대해 builder 가 원안·대안 **양쪽**의 최강 케이스를 사용자 goal 기준으로 쓰고 근거가 핵심 전제에 닿는지 판정한다. 재검토를 여는 열쇠는 전제 충돌 하나 — 그 외 근거는 원안 강화·경계 다듬기에 쓴다. 판정 어휘 유지/보완/전환/보류(kept/refined/switched/deferred), 선택은 사용자.
- **AP16 (Unbounded autonomy)** — 재리뷰 상한 2 (정본은 `shared/docreview/references/reviewing-document.md` 한 줄이고, 라운드 4 이상은 승인 게이트에서 사용자가 연다), 조사 호출 상한(기본 60) · 포화 판정 상한(기본 5) · 본체의 반복 감지(같은 빈 곳이면 사용자에게), kill switch.
- **Graceful degradation with loud logging (CLAUDE.md 런타임 상태 & 훅)**: `resolve_session_id` 검증 실패 시 None 반환 + stderr advisory. 리뷰 진입의 원장 정리(`scripts/ledger_sweep.py`)는 지우거나 옮긴 수를 한 줄로 내고, 읽지 못한 원장 · 옮기지 않은 옛 인터뷰 기록 · 옛 원장 충돌 · 셀 수 없음(pyyaml 없음 포함) · 다른 세션이 정리 중이라 건너뜀을 각각 따로 낸다. 조용한 것은 할 일이 없을 때와, TTL 안이거나 재는 사이 바뀐 폴더를 건너뛸 때(다음 진입에서 다시 본다)다. 정리 자체가 실패해도 리뷰는 계속하고 그 사실을 한 줄로 낸다. 미커밋 확인·진입 검사 실패는 advisory — 사용자 attention 가용성에 따라 loud 정도 조정. 진입 검사 자신의 실패는 끔으로 친다(fail-closed).
- **동시 리뷰 표지** — 같은 문서를 두 세션이 함께 리뷰해 원장을 덮어쓰지 않게, 원장 열기가 원장 폴더의 `reviewing-by`(세션 id 한 줄)를 배타 생성으로 잡고 원장에 쓰는 명령마다 그 앞에서 표지를 확인한다(`scripts/ledger_marker.py`). 남의 표지면 멈추고 「그만둠 (권장)」/「이어 씀」을 묻는다 — 이어 씀이면 표지를 이 세션 것으로 바꾼다(임시 파일 + `os.replace`). 표지는 승인 게이트의 답을 원장에 적은 뒤 끝맺음 펜스가 푼다. 다른 세션의 원장을 이어 받을 때는 「이전 리뷰 라운드 <n> 에서 이어 간다」 한 줄이 나온다.
- **P21 — 저장소가 심은 링크를 따라 쓰지 않는다**: 저장소는 어떤 이름으로든 링크를 커밋할 수 있다. 원장 · 표지 · 인터뷰 상태 파일을 쓰거나 옮기거나 지우는 자리는 경로 성분의 링크 · `..` · 작업 트리 밖을 거부한다(`state_path.py path-inside`). 그래서 `.claude` · `.claude/spec-distill` · `.docreview` 가 링크인 저장소에서는 리뷰 라운드 대신 거부 사유 한 줄이 나오고(원장 열기가 `NO_DIR` 로 끝나 리뷰 없이 끝난 사실이 각 자리의 안내 · degrade 로 보인다), 원장 정리는 링크인 state root · `.docreview` 를 「셀 수 없음」 으로 내고 그 너머를 옮기거나 지우지 않는다 — 링크가 저장소 **안**을 가리켜도 거부다. 인터뷰 상태 파일 경로가 링크이거나 작업 트리 밖이면 진입이 그 파일을 이어 가지 않고(`REJECT`), 끝의 brief · audit · 상태 파일 커밋도 하지 않고 세 경로와 사유를 보인다.
- **Law 1 · Law 3 — 번호 인계** — brief · 에픽 묶음의 번호가 설계문서 · 계획 · 구현으로 넘어가는 이음매마다 기계 대조가 있다: 번호 대조(빠진 번호는 spec-review 진입 때 보이고 게이트 경고 수에 들며 지휘 절차는 그 때문에 spec-review 앞에서 멈춘다, 얕음 · 받드는 에픽 없음은 승인 때의 경고) · `--plan` · `--impl` · `roadmap_status.py` 의 받는 곳 없는 미룸 경고. 외부 skill(brainstorming · writing-plans · SDD)은 고치지 않는다 — 넘길 때 보내는 글과 돌아온 결과 검사만 devbrew 쪽에 있다. 내용이 실제로 답하는지는 리뷰어(design-doc 프로필의 scope 축)가 판정한다.
- **Law 2 — 통합 리뷰어는 쓰지 못한다** — 에픽 사이 이음매 리뷰는 `tools: Read, Grep, Glob` 인 `integration-reviewer` 가 한다. superpowers 리뷰 요청 skill 의 틀만 빌리고 그 skill 이 부르는 쓰기 가능한 agent 는 쓰지 않는다. 지휘자가 하위의 질문을 옮긴 기록의 대조도 같은 도구만 가진 `relay-checker` 가 한다.
- **Law 3 · P23 — 다시 불러도 같은 자리** — 지휘자는 무엇이 끝났는지 기억에 기대지 않고 git(설계문서의 승인 줄 · 판정 · 구현 대조 절)과 기계 상태에서 다시 계산한다. 기계 상태를 지워도 잃는 것은 다시 만들 수 있는 것뿐이다(`tests/test_conductor_e2e.sh`).
- **레포 전용 값 금지** — 지휘자 표면에는 기본 브랜치 이름 · 브랜치 접두 · 레포 구조 경로 · 모델 이름이 없다. 외부 도구 기본 경로는 `scripts/repo_defaults.py` 상수에만 있고 설계문서 · 계획 폴더는 로드맵 frontmatter(`specs_dir` · `plans_dir`)가 이긴다(`tests/test_repo_literals.sh`).
- **cost_class high 의 이름 붙인 예외** — 같은 세션 · 표지가 살아 있고 · 규모가 글자 그대로 같으면 이미 받은 시작 승인을 다시 쓰고 공시만 한다. 규모가 바뀌거나 다른 세션이거나 새로 잡기 · 넘겨받기 · 놓기를 거치면 다시 묻는다.

## 로드맵 · 에픽 묶음

큰 일을 에픽으로 나눠 진행할 때 쓰는 로드맵 · 묶음 스크립트 넷이 있습니다. 그 넷 가운데 `roadmap_write.py` 만 로드맵과 묶음을 쓰고 나머지 셋은 읽기 전용입니다. 지휘자 스크립트 둘은 로드맵 · 묶음은 쓰지 않지만 쓰기를 합니다 — `conductor_ledger.py` 는 기계 상태 · 자원 폴더와 설계문서의 기록 절을, `merge_check.py` 는 일회용 사본과 공유 스위트 잠금(`scripts/suite_lock.py` — 하위 agent 의 전체 스위트와 같은 잠금 하나)을 씁니다. 앞의 넷(`roadmap_status.py` · `check_bundle_coverage.py` · `spec_review_bundle.py` · `roadmap_write.py`)은 네트워크에 나가지 않습니다. 지휘자 스크립트 둘은 나갑니다 — `merge_check.py` 는 `--no-fetch` 가 없으면 `git fetch origin` 을 하고, `conductor_ledger.py` 의 `pr-handoffs` · `audit` · `review-pack` 은 `gh` 를 부릅니다. 단위는 로드맵 > 에픽(spec 하나) > plan(PR 하나) > task 이고, 에픽 하나는 `브랜치:` 에 브랜치를 여럿 적어 PR 여럿을 냅니다. 객체 · 링크 · 주인은 `references/roadmap-ontology.md` 에 있습니다.

- `scripts/roadmap_status.py <로드맵 경로>` — 기본 브랜치(`origin/HEAD`)의 로드맵과 git 을 읽어 에픽마다 단계와 경고를 냅니다. 아직 기본 브랜치에 없는 로드맵은(이때 종료 코드 4) `--roadmap-file <파일>` 로 줍니다. 머지됨 자동 판정은 merge commit 방식에서만 됩니다. 브랜치가 지워졌으면 GitHub 의 머지 메시지 `Merge pull request #<n> from <owner>/<브랜치>` 로만 알아봅니다. squash · rebase 로 머지했거나 로컬에서 머지한 뒤 브랜치를 지웠으면 로드맵 결정 기록에 머지 줄을 적어야 합니다. 설계문서 · 계획 폴더는 로드맵 frontmatter `specs_dir` · `plans_dir`(없으면 superpowers 기본 폴더)에서 찾고, 단계는 브랜치마다 · 계획마다 구현 중 · 구현 끝까지 셉니다. 블록에 적힌 브랜치가 모두 머지된 에픽은 기본 브랜치에 아직 들어가지 않은 브랜치의 로드맵 사본이 그 블록에 더한 브랜치(사본의 블록이 기본 브랜치 블록의 브랜치를 모두 품고, 그 브랜치가 있고 아직 머지되지 않았을 때만)도 세어 「일부 머지」 로 내고 그 사실을 정보 줄로 밝힙니다 — 다음 계획의 브랜치가 자기 브랜치에서만 블록에 자신을 더한 경우입니다. 사본을 만든 뒤 기본 브랜치 블록의 `브랜치:` 가 바뀌면 그 사본은 세지 않습니다 — 열린 브랜치에 기본 브랜치를 merge 하면 풀립니다.
- `scripts/check_bundle_coverage.py <묶음|brief> <설계문서>` — 정답 출처의 번호가 설계문서 `## 번호 대조` 표에 다 있는지(빠지면 종료 코드 1), 반영 칸이 설계문서의 실제 자리를 가리키는지 · 기각한 번호를 받드는 에픽이 있는지(경고 줄 — 종료 코드는 그대로) 봅니다. 로드맵을 못 찾으면 그 항목은 「셀 수 없음」으로 셉니다.
- `scripts/check_bundle_coverage.py --plan <설계문서> <계획>` · `--impl <설계문서> <보고 파일>` — 설계문서 AC 가 계획 Task 에 다 있는지, 구현 보고의 미룸 · 빠짐이 설계문서 `## 미룸` 표에 받는 곳과 함께 올랐는지 봅니다. `--acs <AC 목록>` 이면 그 AC 만 대조합니다. `--impl` 의 받는 곳은 설계문서 `roadmap:` 의 로드맵에 있는 에픽이나 `#<n>` 이어야 합니다.
- `scripts/spec_review_bundle.py` — `spec-review <설계문서> --bundle <묶음|brief>` 의 정답 출처 확인 · 진입 대조 · 승인 때 로드맵 위치와 이웃 결정. `rejected` 는 승인 게이트 2단계 앞 글에 설계가 받지 않기로 한 번호(번호 대조의 기각)의 수와 목록을 냅니다 — 되돌리려면 게이트 ③ 의 후속 질문 기타 칸에 번호를 적습니다.
- `references/epic-handoff.md` — 로드맵 에픽의 설계를 여는 넘김 줄. 지휘 세션이 자리표를 채워 씁니다. brainstorming 이 기본이고 블록에 `흐름:` 이 있으면 그 흐름을 따르며, 나눌 근거가 보이면 재분해로 보고하고, 설계문서에 「있는 것 검토」 · 「상류 · 하류 연계」 절을 두고, 여러 산출물 · 상태가 얽히면 계층 · 온톨로지(객체 · 링크 · 속성 · 주인)를 밝혀 진입점에서 따라 내려가게 합니다.
- `references/conducting.md` — 지휘 순환 걸음 1~7(지휘자가 따른다)과 끝 절의 손 절차(지휘자를 부르지 않고 진행할 때 — `DEVBREW_SPEC_DISTILL_DISABLE=1` 은 리뷰 · 상태 계산까지 spec-distill 전체를 끄므로 손 절차를 쓰려면 끄지 않는다)입니다. 레포마다 다른 값은 로드맵 frontmatter 와 `origin/HEAD` 에서 읽습니다.
- `references/conductor-dispatch.md` — 지휘자가 하위 agent 에게 보내는 글(자리 · 미리 받은 답 · 두 부분 반환 · 처분 줄 · 사람 자리에서 질문을 옮기는 규칙 둘).
- `scripts/merge_check.py` — 머지 전 스위트 대조(실패를 단위와 이름으로 가름). 종료 코드 0 · 1 새 실패 · 3 검사 불가 · 4 이름 대조 불가 단위 · 5 다른 스위트가 공유 잠금을 쥠(주인 · 잡은 시각을 보인다 — `--wait <초>` 면 줄을 선다) · 6 테스트 명령 모름 · 7 테스트 없음. 로컬 브랜치와 `origin/<브랜치>` 가 다르면 앞선 쪽을 쓰고 알리며, 갈라졌으면 3 이다(`--branch origin/<브랜치>` 도 받는다) — 이 끝 고르기는 `scripts/branch_tip.py` 하나이고 `conductor_ledger.py review-pack` 도 같이 쓴다.
- `scripts/suite_lock.py` — 공유 스위트 잠금. 지휘자의 스위트 대조와 하위 agent 의 전체 스위트가 기계 상태 자원 폴더의 잠금 하나(`<기계 상태 폴더>/files/suite-lock`)를 쓴다. 하위는 `run --lock <경로> --owner <이름> [--wait <초>] -- bash -c '<명령>'` 한 번으로 잡고 · 돌리고 · 푼다(못 잡으면 75 · 잠금 폴더에 쓰지 못하면 3 — 잠금 없이 돌리지 않는다). 주인이 프로세스 번호가 아닌 잠금은 살았는지 알 수 없어 훔치지 않고 주인 · 잡은 시각을 보인다.
- `scripts/conductor_ledger.py` — 기계 상태 · 시작 승인 · 자원 폴더(`resource-dir`) · 자원 정리(확인 없이 치우는 것은 버릴 것(합친 사본 · 리뷰 묶음 · 자원 폴더 항목)뿐 — 사용자 worktree 는 깨끗하고 등록된 것만 `--force` 없이 지우고, 지휘 세션의 자리는 지우지 않으며, 브랜치는 그대로) · 설계문서 기록 절 · 통합 리뷰 묶음(열린 에픽 브랜치는 상태 계산과 같은 규칙으로 — 기본 브랜치 블록에 더해 블록을 잇는 로드맵 사본이 더한 브랜치도) · 공유 스위트 잠금 경로(`suite-lock`) · 실행 원장마다 마지막 고친 시각과 마지막 줄(`progress`). 기계 상태의 `## 작업` 표는 로드맵 밖 일(수리 PR · 정리 일)까지 한 곳에 담고, 상태 보기가 그 표와 돌고 있는 큰 작업 수 · 권장 수(로드맵 frontmatter `parallel_default`, 없거나 깨졌으면 3 — 기본값이지 상한이 아니다) · 스위트 잠금을 함께 보인다.
- `agents/integration-reviewer.md` — 쓰기 권한 없는 통합 리뷰어(`Read, Grep, Glob`).
- `agents/relay-checker.md` — 쓰기 권한 없는 옮김 대조 agent(`Read, Grep, Glob`). 에픽이 끝나면 지휘자가 하위의 질문을 사용자에게 옮긴 기록마다 선택지 수 · 순서 · 라벨 · 「(권장)」 과 사용자 답이 그대로 갔는지 대조한다.
- spec-review 게이트 ③ — 로드맵 에픽의 설계문서면 「이 에픽 다시 설계」(같은 묶음으로 brainstorming 을 다시) 와 재분해(「인터뷰 다시 열기」) 를 고를 수 있습니다. 재분해 신호는 열린 목록입니다(`references/redecompose.md` 1).
- `scripts/roadmap_write.py create · update · extract · migrate` — 인터뷰가 승인받은 분해안 표(`## 분해안`, 칸 열하나)로 로드맵과 에픽 묶음을 쓰고(create), 재분해 때 바뀐 블록과 그 묶음만 다시 쓰고(update), 로드맵에서 표를 거꾸로 뽑습니다(extract). update 는 새 에픽 번호가 문자마다 최댓값 다음부터 빈틈없이 이어져야 하고, 「…」 인용은 재분해 이력의 번호 판정에서 뺍니다. create 는 상태 파일 `## 생성 기록` 에 적힌 파일만 덮어쓰고, 자기 것이 아닌 `<id>.md` 를 덮어쓰게 되면 쓰기 전에 거부합니다. 검증이 실패하면 새로 만든 파일은 지웁니다. `--audit` 은 `--brief` 경로의 `.md` 를 `.audit.md` 로 바꾼 파일이어야 하고(아니면 사용법 오류 2), update 는 묶음 번호 순서만 다른 표를 바뀜으로 세지 않습니다. 쓴 직후 `roadmap_status.py --json` 의 `format_errors` · `unassigned` · `orphans` · `unknown_ids` 중 하나라도 비지 않으면 쓴 것을 원래 바이트(파일 모드 포함)로 되돌리고 1 로 끝납니다. 머지된 에픽은 바꾸지 않고 사라진 번호는 다시 쓰지 않습니다. 재분해 절차는 `references/redecompose.md` 에 있습니다. migrate 는 옛 꼴 블록을 새 형식(범위 하위 항목)으로 다시 씁니다 — 각 블록의 `- 범위:` 줄만 고치고 바꿀 수 없는 것은 1 로 거절하며 CRLF 를 지킵니다.

경로 예약 겹침과 다른 에픽이 예약한 파일의 편집은 경고가 아니라 정보입니다 — 종료 코드를 바꾸지 않고, 에픽은 병렬로 갑니다. 충돌은 머지 때 풉니다(나중에 머지하는 PR 이 main 을 merge 하고 스위트를 다시 돌립니다).

머지 메시지로 머지됨을 판정할 때는 브랜치 이름만 봅니다 — 머지된 PR 과 같은 이름으로 다시 만든 브랜치나 다른 owner 의 같은 이름 브랜치도 머지됨으로 보일 수 있습니다.

종료 코드는 둘 다 0 이상 없음 · 1 경고 · 2 사용법 오류 · 3 검사 불가이고, `roadmap_status.py` 는 4 (로드맵이 아직 기본 브랜치에 없음)를 더 내고, `control_plane.py show --tasks` 도 4 를 낼 수 있습니다. `roadmap_write.py` 는 0 성공 · 1 쓰지 않음 · 2 사용법 오류입니다. 형식은 `docs/superpowers/specs/2026-10-11-roadmap-walking-skeleton-design.md` §3 에 있습니다.

### 상태줄

에픽 단계 요약 · 경고 수 · 마지막 fetch 경과 · 진행 중 인터뷰 조사 수를 Claude Code 상태줄 한 줄로 늘 볼 수 있습니다. 예: `2026-10-11-persistent-explore-pm-decompose · 설계 2 · 구현 1 · 준비 3 · 경고 없음 · 받은 지 12분`. 자세히는 `/spec-distill:roadmap-status`(에픽 하나는 `<로드맵> <에픽>`), 지휘 세션의 작업 목록은 `python3 <플러그인>/scripts/control_plane.py show --tasks <로드맵>` 의 줄(`<제목>` 탭 `<pending|in_progress|completed|keep>`)로 맞춥니다.

플러그인이 대신 켜 줄 수 없습니다 — 메인 `statusLine` 은 사용자 · 프로젝트 설정만 정합니다. 직접 켭니다.

1. 아래 스크립트를 `~/.claude/devbrew-statusline` 로 저장합니다. 버전 붙은 플러그인 폴더를 박아 두지 않고, 실행할 때마다 설치된 spec-distill 을 찾습니다(Claude Code 가 설치 기록 `plugins/installed_plugins.json` 의 `installPath` 에 적은 폴더 — 2026-10-15 · 2.1.299 실측). 못 찾으면 빈 줄이 아니라 `상태줄 꺼짐 — 플러그인을 못 찾음` 을 냅니다. 로드맵도 진행 중 인터뷰도 없으면 빈 줄입니다.

<!-- control-plane-statusline:begin -->
```sh
#!/bin/sh
d="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
p=$(grep -o '"installPath": *"[^"]*/spec-distill/[^"]*"' "$d/plugins/installed_plugins.json" 2>/dev/null | head -n 1 | sed 's/.*"\([^"]*\)"$/\1/')
if [ -n "$p" ] && [ -f "$p"/scripts/control_plane.py ]; then
  exec python3 "$p"/scripts/control_plane.py statusline
fi
echo "상태줄 꺼짐 — 플러그인을 못 찾음"
```
<!-- control-plane-statusline:end -->

2. 사용자 설정 `~/.claude/settings.json` 에 넣습니다(devbrew 레포의 프로젝트 설정에는 커밋하지 않습니다):

```json
{ "statusLine": { "type": "command", "command": "sh ~/.claude/devbrew-statusline" } }
```

이미 상태줄을 쓰고 있으면 기존 명령 뒤에 이어 붙입니다 — 상태줄 입력(JSON)을 두 명령에 똑같이 넘깁니다:

```sh
in=$(cat); a=$(printf '%s' "$in" | <기존 명령>); b=$(printf '%s' "$in" | sh ~/.claude/devbrew-statusline); printf '%s  %s\n' "$a" "$b"
```

캐시는 `<git 공용 디렉토리>/devbrew/control-plane.json` 하나이고 레포 파일과 git 상태는 바꾸지 않습니다. 상태 계산이 실패하면 `검사 불가` 조각이 붙습니다 — 「없음」과 섞지 않습니다.

상태줄 한 번은 3초 안에 끝납니다. 넘으면 그 레포에서 마지막으로 낸 줄 뒤에 ` · 시간 초과` 를 붙여 내고, 낸 적이 없으면 `상태줄 — 시간 초과` 를 냅니다. 로드맵이 많거나 커서 첫 계산이 3초를 넘으면 `/spec-distill:roadmap-status` 를 한 번 부르면(30초 안) 같은 캐시가 채워집니다 — 다만 캐시는 브랜치나 origin/main 이 움직일 때마다 다시 계산되므로, 계산이 늘 3초를 넘는 레포에서는 상태줄에 ` · 시간 초과` 가 자주 붙습니다. 스크립트는 자기 하위 프로세스에 시간 제한을 두어 스스로 묶습니다. Claude Code 가 상태줄 실행을 도중에 버릴 때 그 자식을 끝내는지는 재지 않았습니다. 인터뷰 상태 파일은 일반 파일만 64 KiB 까지 읽고, 넘거나 링크 · 파이프면 `셀 수 없음` 으로 보입니다.

## Hooks Installed

설치되는 훅이 없다 — 원장 정리는 리뷰 진입(`scripts/ledger_sweep.py`)이 한다.

## 설정

문서 리뷰 엔진은 값 넷을 쓴다. 정하는 순서는 기본 < 프로필 < 진입 < 환경 변수이고, 바꾼 값은 다음 라운드부터 적용된다. 라운드마다 게이트 둘째 줄에 쓴 값과 그 출처를 밝힌다. 프로필 필드 이름은 환경 변수 이름과 짝이다(`detectors` · `rereview_cap` · `render_cap` · `summary_width`).

| 환경 변수 | 프로필 필드 | 뜻 | 기본 |
|---|---|---|---|
| `DEVBREW_DOCREVIEW_DETECTORS` | `detectors` | 탐지 리뷰어 수(1~6) | 1 |
| `DEVBREW_DOCREVIEW_REREVIEW_CAP` | `rereview_cap` | 한 문서의 재리뷰 상한(0~10, 0 이면 재리뷰 없음) | 2 |
| `DEVBREW_DOCREVIEW_RENDER_CAP` | `render_cap` | 조언 목록에 펼치는 지적 수(1~100) | 8 |
| `DEVBREW_DOCREVIEW_SUMMARY_WIDTH` | `summary_width` | 지적 요약 줄 너비(1~500) | 60 |

진입 skill 이 `advice --cap` 으로 펼치는 수를 넘기면 그 값이 `render_cap` 의 환경 변수보다 앞선다. 정수가 아니거나 범위 밖이면 그 값은 쓰지 않고 이름과 값을 밝히며 멈춘다.

범위 밖 값은 라운드를 시작하지 않고 이름 · 값 · 허용 범위 · 출처를 보인다.

## 끄는 법

### 먼저 — 설계문서 리뷰를 끄는 법

설계문서 리뷰 진입은 `spec-review` 가 엔진 라운드 전에 도는 진입 검사(`scripts/review_entry.py` + 리터럴 펜스)가 판정한다. 끄는 스위치는 셋이고 셋 다 수동 호출(`/spec-distill:spec-review`)까지 끈다: `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` · `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` · 플러그인 전체 `DEVBREW_SPEC_DISTILL_DISABLE=1`. 진입 검사 자신이 실패하면(모듈 부재 · rc≠0 · 출력 계약 위반) 끔으로 친다 — 그 사실이 advisory 로 나오고 brainstorming 의 문서 승인 자리로 돌아간다. 전부 세션 스코프 env var 라 재시작이 필요하다.

### 스위치 목록

- `DEVBREW_SPEC_DISTILL_DISABLE=1` — plugin 전체 abort, state 보존. 리뷰 진입의 원장 정리(`scripts/ledger_sweep.py`)도 아무것도 지우지 않는다.
  진입 skill 다섯(`request-framing` · `pm-interview` · `spec-review` · `roadmap-status` · `epic-conductor`)은 본문 전 사전 검사가 `DEVBREW_SPEC_DISTILL_DISABLE=1` 을 판정한다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다. 사전 검사 스크립트(`scripts/entry_preflight.py`)나 `python3` 가 없으면 플랫폼이 skill 호출을 끊는다 — 헤드리스에서는 출력 없이 끝난다.
- `DEVBREW_SKIP_HOOKS=spec-distill:statusline` — 컨트롤 플레인(`scripts/control_plane.py`)을 끈다: 상태줄은 빈 줄, `/spec-distill:roadmap-status` 의 지도는 `꺼져 있다 — <스위치>` 한 줄, `show --tasks` 는 표준 출력을 비우고 rc 3. 훅이 아니지만 지목할 이름을 갖는다. `DEVBREW_SPEC_DISTILL_DISABLE=1` 도 같은 효과다.
- `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` — codex 병렬 co-review만 skip. Claude 리뷰(탐지 · 재비판)는 정상 동작하고, codex 부재는 엔진이 `fin.json` 의 `advisory[]` 와 게이트 첫 줄로 loud 하게 공시한다. 전역 `DEVBREW_SPEC_DISTILL_DISABLE`과 독립. **적용 범위는 문서 리뷰 엔진 자리 셋 전부**: (a) design-doc 리뷰(`spec-review`), (b) brief 리뷰(`reviewing-brief`), (c) seed 리뷰(`request-framing`) — 세 자리 모두 codex 호출은 SKILL 의 리터럴 게이트 펜스(`codex-gate` 표지) 하나이고 매 라운드 4단계에서 돈다. 게이트는 **호출자 책임**이다 — `detect_codex.sh`가 이 스위치를 `codex_available: false`(`skip_reason: kill_switch`)로 옮기고 펜스가 그 값으로 러너 호출을 가르며, 러너(`run_docreview_codex_reviewer.sh`)는 이 변수를 보지 않는다. 펜스 밖에서 러너를 부르면 opt-out이 무시된 채 지출이 나간다.
- `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC=1` — 문서 리뷰 엔진의 **재비판 단계만** skip (`doc-recritic` dispatch 없음). 탐지·codex 는 정상 동작한다. 기각 경로가 0 이 된 사실은 `fin.json` 의 `advisory[]` 로 공시된다 — 오탐이 걸러지지 않은 라운드라는 뜻이므로 조용히 넘어가지 않는다.
- `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT=<n>` — interview 조사 agent 호출 상한의 시작값(기본 60, 양의 정수가 아니면 60 과 한 줄 공시). 띄운 agent 수만 센다 — agent 안의 검색 · 출처 수는 세지 않는다. 닿으면 연장 · 판정 · 종료를 묻는다. 끄는 스위치가 아니다. 이 상한이 사슬 전체의 바깥 조사 중 띄운 agent 몫을 묶고(Phase 0 은 레포를 읽고 웹은 이름 확인에만 쓰며 조사 agent 를 띄우지 않는다), 본체 직접 웹 검색은 라운드 규약(라운드마다 질문 호출 하나 · 질문마다 답 하나)이 묶는다.
- `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT=<n>` — 포화 판정자 호출 상한의 시작값(기본 5). floor 가 닫힌 뒤 판정 고리가 사용자 턴 없이 도는 것을 묶는다.
- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` — `spec-review` 진입 검사가 설계문서 리뷰를 끈다 — **수동 호출 포함** skill 전체다. 파일 분류(content-aware 판별)는 없다 — 이 skill 은 받은 경로를 `design-doc.md` 프로필로 리뷰한다(대안 비교는 기각한 대안도 같은 기준으로 견준다).
- `DEVBREW_SKIP_HOOKS=spec-distill:review-entry` — 같은 효과의 이름 붙은 스위치. 수신처는 `scripts/review_entry.py` 의 진입 검사다(`spec-distill:review-entry`) — 훅이 아니지만 지목할 이름을 갖는다(`spec-distill-gc` 와 같은 관례).
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionEnd` (alias: `spec-distill:session-end-cleanup`) — 리뷰 진입 때의 원장 정리(`scripts/ledger_sweep.py`)를 끈다 — 문서 없는 원장 삭제 · 옛 세션 폴더 정리 · 옛 원장 옮기기가 모두 멈춘다. 설치되는 훅은 없다.
- `DEVBREW_SKIP_HOOKS=spec-distill:spec-distill-gc` — 같은 원장 정리를 끈다. 이 셋은 모두 옛 시간 기준 정리를 멈추던 이름이라, 훅이 없어진 뒤에도 정리를 꺼 둔 사용자에게 삭제가 다시 켜지지 않게 그대로 읽는다.
- `DEVBREW_SPEC_DISTILL_TTL_HOURS=<int>` — 리뷰 진입의 원장 정리가 두 자리에 쓰는 시간(기본 24, 0 이하이거나 정수가 아니면 24): ① 기록된 문서가 사라진 원장의 삭제 유예 — 원장 폴더에 이 시간 동안 쓰기가 없어야 지운다(다른 브랜치로 옮겨 문서가 잠시 없는 동안 원장이 남는 창이다), ② 옛 버전 세션 폴더의 정리 판정 — 이 시간을 넘은 폴더만 지운다. `state.local.md` 가 있는 옛 폴더는 이 값과 무관하게 지우지 않는다. 짧게 잡으면 다른 브랜치에 오래 있다 돌아온 문서의 원장이 사라져 리뷰가 라운드 1 부터 다시 센다(사용자 결정은 문서의 결정 절에 남는다).
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` — 이 kill switch 가
  **두 자리**의 웹 접근을 끈다: interview 웹 리서치(landscape · 웹 agent dispatch · 만들어 보낸 조사 `open-researcher`), 그리고
  brief 리뷰 자리의 웹 둘 — codex 웹 검색(공유 러너 `run_docreview_codex_reviewer.sh` 가 이 스위치와
  `DEVBREW_QUALITY_GATES_DISABLE_WEB` 을 함께 본다)과 Claude 쪽 탐지(선택 펜스가 웹 사본
  `doc-critic-web` 대신 웹 도구 없는 `doc-critic` 을 **지명**한다 — dispatch 는 지명된 블록을 따르고,
  그 선택을 강제하는 훅은 없다). 구조 게이트 `check_brief.py` 도 §4 sentinel 하나를 완화하며 자기
  advisory 로 공시한다. 어느 쪽이든 loud log(brief 자리는 degrade record 도)와 함께 생략, crash
  없음 (graceful degradation). **design-doc 리뷰는 이 스위치의 대상이 아니다** — `doc-critic`·
  `doc-recritic` 은 `tools:` 에 웹 도구가 아예 없고 `design-doc.md` 프로필이 `web: false` 를
  고정해서 켜고 끌 것이 없다. 이 스위치는 `request-framing` 의 이름 조회(웹을 이름 확인에만 쓰는
  자리)도 끈다 — 조회 직전마다 정확히 `1` 인지 보고, 켜져 있으면 조회를 건너뛴다.
- `DEVBREW_SPEC_DISTILL_DISABLE_WORKTREE=1` — `request-framing` 진입 직후의 워크트리
  질문을 **묻지 않고** 현재 디렉토리에서 진행한다. `EnterWorktree` 도구 부재와 같은 경로다.
  audit §5 에 «워크트리 없음 —» 강등 기록이 남고, 어느 경우도 seed 작성을 막지 않는다.
- `DEVBREW_SPEC_DISTILL_DISABLE_BRIEF_REVIEW=1` — brief 리뷰 전체 skip(엔진 라운드 · 냉독).
  `component: pipeline` degradation record + loud advisory를 남기고 Step B로 직행한다(조용한
  생략이 아니다). 엔진 라운드(방향성 · 충실도)와 냉독이 전부 미검증이라는 사실이 다음 단계 게이트 앞 글에 표시된다.

### 은퇴한 스위치 (v0.36.0 · 3.0.0 · 6.0.0)

`PostToolUse` validator 와 `UserPromptSubmit` reminder(v0.36.0), 설계문서 리뷰 훅(3.0.0)이 삭제되면서 다음 훅 토큰 · 변수가 아무것도 끄지 않게 됐다. `spec-review` 의 진입 검사가 리뷰를 부를 때마다 advisory 로 알린다. 6.0.0 에서 은퇴한 이름은 끄는 스위치가 아니라 진단 출력 변수 하나다(맨 아래).

- `DEVBREW_SKIP_HOOKS=spec-distill:Stop` / `:review-dispatch` (3.0.0) — 가리키던 훅이 삭제됐다. **리뷰를 막지 않는다** — 이 토큰으로 자동 리뷰를 꺼 두었다면 이제 리뷰가 돈다. 끄려면 위 `spec-distill:review-entry` 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`. 이 토큰은 리뷰 진입의 원장 정리(옛 TTL-GC)도 멈추지 않는다.
- `DEVBREW_SKIP_HOOKS=spec-distill:PostToolUse` / `:validator` (v0.36.0) — 끄던 구조 검사가 삭제돼 아무것도 끄지 않는다.
- `DEVBREW_SKIP_HOOKS=spec-distill:UserPromptSubmit` / `:reminder` (v0.36.0) — 재-nag 층 자체가 없다.
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.36.0) — 읽는 곳이 없다. 설계문서 리뷰를 끄려면 위 `spec-distill:review-entry` 또는 `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`.
- `DEVBREW_SPEC_DISTILL_GC_VERBOSE=1` (6.0.0) — TTL-GC 의 진단 출력 변수였다(끄는 스위치가 아니다). 읽던 TTL-GC 스크립트가 지워져 읽는 곳이 없다. 진입 검사는 이 이름을 알리지 않는다. 원장 정리는 한 일을 늘 한 줄로 낸다.

## Prerequisites

- **Python 3** — 스킬이 부르는 `scripts/*.py` 는 사용자의 `python3` 로 돈다. 이 플러그인에는 훅이 없어
  devbrew 의 출하 Python 바닥(루트 README 「Python」)을 집행하는 해석기를 거치지 않는다. 문서 리뷰 엔진은
  PyYAML 을 쓴다 — 없으면 리뷰 진입의 원장 정리는 「셀 수 없음(pyyaml 없음)」 을 내고 아무것도 지우지 않는다.
- **superpowers** (외부, optional) — 있으면 brief를 `brainstorming` 해답공간으로 넘기고 `writing-plans`로 이어집니다. 없으면 interview는 brief를 완료하고 loud advisory 후 정지 (단독 완결, AC13).
- **quality-gates** (같은 마켓플레이스, optional) — 지휘 순환 걸음 7 이 범위 입력을 받으면 `/quality-gates:quality-pipeline` 을 부른다 — 받지 않으면 품질 게이트 없이 가고 그 사실을 알린다. 설치돼 있지 않을 때의 동작은 걸음 7 이 따로 말하지 않는다.
- **gh CLI** (외부, optional) — 머지된 PR 번호 · PR 인계를 모은다. 없으면 공시하고 강등한다(crash 없음).
- **codex CLI** (외부, optional) — 있으면 문서 리뷰 엔진 라운드(design doc · interview brief · interview seed)에 병렬 독립 co-reviewer로 참여(model diversity). 없거나 auth 미설정이면 Claude-only로 graceful degrade + loud advisory(crash 없음). kill switch `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1`.

## License

(devbrew root 정책 따름.)
