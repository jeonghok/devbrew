# agent `model:` 핀 해제 — 사용자 subagent 설정을 통과시킨다 · Design

> 하니스는 티어를 정하지 않는다. `inherit` 도 정하는 것이다.

## Handoff Context

**TL;DR** — devbrew agent 20개의 frontmatter `model: inherit` 를 삭제한다. 실측(§A)으로 `inherit` 가
사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 무효화함이 확인됐다. 필드를 빼면
「사용자 설정 → 세션 모델」 순으로 위임되고, 설정이 없는 환경은 오늘과 동작이 같다. `inherit` 실재를
단언하는 락 16개는 「`model` 키 부재」 단언으로 반전하고, 규약 문장·README·skill 본문의 `inherit`
서술을 사실에 맞게 고친다. 플러그인 4개 minor bump.

**Implicit context** — (1) 2026-09-04 PR #139 는 「전 agent `opus` 핀」요청을 실측 끝에 「`inherit`
유지 + dispatch 시점 재량」으로 선회했다. 이 문서는 그 결정의 전제 하나(「`inherit` = 사용자 선택
존중」)를 반증하고 재결정한다 — 철학 P23, 근거 있는 재결정은 사용자 동의로 허용. (2) 발단은 세션이
Fable 로 돌 때 20개가 전부 Fable 로 실행되는 비용. (3) 사용자는 「환경변수를 `opus` 로 켠 Fable
세션에서 리뷰어가 writer 보다 한 티어 약해진다」는 트레이드오프를 인지하고 수용했다(2026-09-06) —
하니스가 아니라 사용자가 고르고 되돌릴 수 있다는 점이 #139 와 다르다. (4) 공식 문서가 말하는
settings 키 `subagentModel` 은 이 CLI 버전(2.1.261)에 없다 — 실재하는 레버는 환경변수 하나다.

**Deferred to plan** — 락 반전의 정확한 regex 문면(C2 의 요건만 여기서 정한다) · 스윕 락 rename 시
인용 갱신 목록(`grep -rn test_agent_model_inherit_sweep`) · 잔여 `inherit` 서술의 대체 어휘 통일
(§설계 3 이 후보를 준다) · AC6 실측에 OQ1 을 붙일지.

## 목차

- [A. 측정 여섯](#a-측정-여섯)
- [Goal](#goal)
- [Context / Why](#context--why)
- [Goals](#goals)
- [Non-goals](#non-goals)
- [Constraints](#constraints)
- [설계](#설계)
- [Acceptance Criteria](#acceptance-criteria)
- [Files to Modify](#files-to-modify)
- [Verification Plan](#verification-plan)
- [Rejected Alternatives](#rejected-alternatives)
- [Open Questions](#open-questions)
- [Concrete Next Action](#concrete-next-action)
- [재결정 기록](#재결정-기록)
- [부록 — 프로브 재현](#부록--프로브-재현)

## A. 측정 여섯

2026-09-06, Claude Code CLI **2.1.261**, `claude -p --model opus --plugin-dir <probe> --permission-mode acceptEdits
--output-format stream-json --verbose`. 프로브 플러그인은 agent 둘 — `probe-nomodel`(frontmatter 에
`model:` 없음)과 `probe-inherit`(`model: inherit`) — 이고 각자 자기 시스템 프롬프트의 모델명을
한 줄로 보고한다. 부모가 두 agent 를 dispatch 하며 `model` 인자를 넘기지 않았음은 스트림의
`tool_use.input` 에서 확인했다(여섯 실측 전부 `<absent>`). 재현 방법은 [부록](#부록--프로브-재현).

| 실측 | 조건 | `probe-nomodel` | `probe-inherit` |
|---|---|---|---|
| A | 환경변수 `CLAUDE_CODE_SUBAGENT_MODEL=haiku` | Haiku 4.5 | Opus 5 |
| B | 아무 설정 없음 (대조) | Opus 5 | Opus 5 |
| C | `--settings '{"subagentModel":"haiku"}'` (인라인 JSON) | Opus 5 | Opus 5 |
| D | `--settings <file>` 같은 내용 | Opus 5 | Opus 5 |
| E | `--settings '{"env":{"CLAUDE_CODE_SUBAGENT_MODEL":"haiku"}}'` | Haiku 4.5 | Opus 5 |
| F | 환경변수 + `CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` | Haiku 4.5 | Haiku 4.5 |

보조 관찰: CLI 바이너리(`~/.local/share/claude/versions/2.1.261`)에 문자열
`CLAUDE_CODE_SUBAGENT_MODEL`·`CLAUDE_CODE_SUBAGENT_MODEL_FORCE` 는 있고 `subagentModel` 은 **0건**.

**확정된 사실**

- F1. frontmatter `model:` 이 **없는** agent 는 환경변수 `CLAUDE_CODE_SUBAGENT_MODEL` 을 따르고, 없으면 세션 모델을 따른다 (A·B).
- F2. `model: inherit` 는 그 환경변수를 **무효화**한다 (A·E). 즉 `inherit` 는 "세션 모델" 을 하니스가 고정하는 값이다.
- F3. 환경변수는 사용자 `settings.json` 의 `env` 블록으로 줄 수 있다 (E).
- F4. `_FORCE=1` 은 frontmatter `inherit` 까지 덮는다 (F).
- F5. 공식 문서가 말하는 settings 키 `subagentModel` 은 이 버전에서 동작하지 않고 바이너리에 문자열도 없다 (C·D + 보조 관찰).

**미실측** — (U1) dispatch 시점 `model` 인자가 환경변수보다 우선하는지(문서: 우선순위 1). (U2) FORCE 가
dispatch 인자·외부 플러그인 리터럴 핀에 미치는 영향(문서: "모든 출처를 덮는다"). 이 문서의 AC 는 U1·U2
에 기대지 않으며, U1·U2 를 언급하는 자리(N4·R3)는 「문서 기술·미실측」으로 표시한다.

## Goal

devbrew 의 agent 20개가 사용자의 subagent 기본 모델 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 따르게 한다.
설정이 없는 환경에서는 오늘과 동일하게 세션 모델로 실행된다.

## Context / Why

`docs/plugin-authoring.md` 의 규약 「agent `model:` 은 `inherit`」의 근거는 P8 — *하니스가 사용자의
모델 선택을 덮어쓰지 않는다* — 였다. 리터럴 티어 핀에 대해서는 이 근거가 맞다. 그러나 F2 가 보여주듯
`inherit` 자체가 사용자 선택 한 가지(subagent 기본 티어)를 덮어쓴다. 지금 리포는 락 16개로 그 덮어쓰기를
**강제**하고 있다. 락이 지키는 명제와 락의 근거 문장이 어긋난 상태다.

비용 측면: 세션 모델이 Fable 일 때 판정·측정·프로브 20개가 전부 Fable 로 돈다. 사용자가 이를 낮추려고
공식 설정을 켜도 `inherit` 가 막는다.

#139 가 `opus` 핀을 버린 이유("Fable 세션에서 리뷰어가 writer 보다 약해진다")는 이 설계에도 그대로
적용된다 — 다만 그 하향을 **하니스가 아니라 사용자가** 고르고, 세션·머신 단위로 되돌릴 수 있다는 점이
다르다. 이 트레이드오프는 사용자가 인지하고 수용했다(2026-09-06).

## Goals

- G1. `plugins/*/agents/*.md` 20개 전부에서 frontmatter `model` 키 제거.
- G2. 규약을 「agent frontmatter 에 `model` 키를 두지 않는다」로 재기술 — 리터럴 핀도 `inherit` 도 두지 않는다. 문장에 측정 CLI 버전(2.1.261)을 함께 적어 재측정 트리거를 남긴다.
- G3. `inherit` 실재를 단언하는 락 16개 전부를 「`model` 키 부재」 단언으로 반전, 각 락에 변이 증거.
- G4. 사용자 안내 한 줄 — `~/.claude/settings.json` `env` 블록 예시 — 를 quality-gates README 에 둔다. 리포는 값을 정하지 않는다.
- G5. agent 본문·README·skill 본문·스크립트 주석에서 `inherit` 를 **현재 사실로 서술**하는 문장을 새 사실로 고친다(전수 목록은 §설계 3). 이력(CHANGELOG·archive)은 건드리지 않는다.
- G6. plugin-audit 의 `check-plugin-structure.sh` 필터를 새 규약에 맞춘다 — 「`model` 누락」만이 원인인 검증기 실패는 degrade 가 아니라 규약 준수다(§설계 4).

## Non-goals

- N1. dispatch 시점 `model` 인자 규칙의 변경. #139 규약(판정·측정 agent 엔 인자 안 넘김, 프로브·생성기만 재량) 그대로.
- N2. 외부(비-devbrew) 플러그인의 `model:` 핀·`inherit` 에 대한 어떤 조치. 계속 존중.
- N3. 리포의 `.claude/settings.json` 에 환경변수를 커밋하는 것 — 그러면 리포가 모든 사용자의 티어를 정한다(이 설계가 고치는 문제의 재현).
- N4. `_FORCE` 의 사용 권고. 권하지 않는 이유는 실측된 사실 하나 — frontmatter 층을 통째로 무시한다(F4) — 이고, 문서가 기술하는 「dispatch 인자·외부 핀까지 덮는다」는 미실측(U2)이라 근거로 쓰지 않는다. README 에 존재만 적고 권하지 않는다.
- N5. #139 후속 열림 세 건 전부 — (1) `docs/plugin-authoring.md` dispatch 재량 예시 3개의 처분 줄 술어 교체, (2) adversarial 락의 비-리터럴 `model=` 케이스, (3) `smoke-workflow.js` 호출부 차단 락. (1) 은 같은 조항의 **하위 bullet** 이고 어떤 락도 앵커하지 않아 이 사이클과 독립이다 — 별도 사이클.
- N6. 테스트 fixture 의 `model: inherit` — `shared/tests/fixtures/adjudication/**` 7건과 `test_agent_tools_lock_{mutation,differential}.sh` 가 `mktemp` 아래 `plugins/probe/agents/` 에 쓰는 임시 fixture. 둘 다 스윕 glob(`plugins/*/agents/*.md`, 리포 루트 기준) 밖이다 — 확인함. `plugins/plugin-audit/tests/test_check_law2.py:16` 의 fixture 문자열은 Law 2 검사 입력이라 그대로 둔다.
- N7. Law 2 도구 표면(`tools:` allowlist) 변경 없음.
- N8. `plugin-dev` 의 `validate-agent.sh` 자체(외부 플러그인)는 건드리지 않는다.

## Constraints

- C1. 플러그인 4개(`agent-transparency`·`plugin-audit`·`quality-gates`·`spec-distill`) 각각 `plugin.json` **minor** bump + `CHANGELOG.md` 항목 — agent 의 실행 티어 결정 방식이 바뀌는 동작 변경이라 patch 가 아니다.
- C2. 락은 **반전**이지 삭제가 아니다. 반전된 락이 잡아야 하는 것은 「frontmatter 의 최상위 `model` 키 존재」이며, 다음 다섯 변이 각각에서 RED 여야 한다: (a) `model: inherit` (b) `model: opus` (c) `model:inherit`(공백 없음) (d) `"model": inherit`(따옴표 키 — YAML 유효) (e) `model : inherit`(콜론 앞 공백). 부재 검출 regex 는 최소 `^["']?model["']?[[:space:]]*:` 를 포괄해야 한다(정확한 문면은 plans 가 정하고 변이 다섯으로 증명). 스윕 락은 추가로 (f) `agents/` glob 매치가 10 미만이면 RED (기존 하한 유지).
- C3. 규약 문장 락(`test_governance_no_capability_caps.sh` AC8d)은 두 단언을 **교체**한다. 양성: 새 처방 문장 리터럴(§설계 3 의 문장) 존재. 음성: 옛 처방 리터럴 `**agent `model:`은 `inherit`.**` 이 다시 나타나면 RED, 그리고 authoring 문서에 `^model: inherit` 코드 예시가 있으면 RED. **기존 음성 단언(`inherit` 가 있는 줄에 `쓰지 마|금지|말고 리터럴` → RED, 180–183행)은 제거한다** — 그것은 옛 규약의 방향을 지키던 것이라 새 문장(「`inherit` 도 두지 않는다」)에 그대로 발화한다. 한국어 어법 regex 는 새로 만들지 않는다 — 방향 반전은 리터럴 두 개(옛 문장 부재·새 문장 존재)로 충분하다.
- C4. 문서는 Korean-primary. 산출물(agent 파일)에 이 변경의 출처·정당화를 적지 않는다 — CHANGELOG 와 이 문서에만 (AP18 self-narrating artifact 금지).
- C5. 사용자 파일(`~/.claude/settings.json`)은 이 사이클이 편집하지 않는다.
- C6. 락 헤더·agent 본문·README·skill 본문 어디든 「왜 `inherit` 인가」를 현재 사실로 설명하는 문장은 F2 에 맞게 고친다 — 삭제된 규칙이 거짓 인용을 남기지 않도록. 이력 문서(CHANGELOG·`docs/archive/**`)는 제외.

## 설계

변경은 네 층이다.

**1. agent 파일 (20)** — frontmatter 에서 `model: inherit` 한 줄 삭제. 추가로 본문에 `inherit` 를 현재
사실로 서술하는 세 곳을 고친다: `plugins/quality-gates/agents/artifact-critic.md` 의 description(「inherit-tier
critic」)과 본문(「You run at the session tier (inherit) because …」), `plugins/quality-gates/agents/artifact-adversarial.md`
의 description(「inherit-tier adversary」). 대체 어휘 후보: 「tier-unpinned」 / 「하니스가 티어를 정하지 않는」.
그 외 17개는 frontmatter 한 줄만이 diff 다.

**2. 락 (16 파일)** — 세 종류.

| 종류 | 파일 | 반전 내용 |
|---|---|---|
| 스윕 | `plugins/quality-gates/tests/test_agent_model_inherit_sweep.sh` → 이름을 `test_agent_model_unpinned_sweep.sh` 로 | 규칙 1 「`model:` 줄 없음 = RED」를 「최상위 `model` 키 **있음** = RED」로. 규칙 2(리터럴 핀)·3(중복)은 규칙 1 에 흡수 — 단일 규칙 「C2 regex 매치 0」 + 하한 ≥10. 헤더의 「왜 inherit 인가」 문단을 F2 로 교체. |
| per-agent 양성 단언 | quality-gates 8 (`adversarial_persona`·`security_reviewer_persona`·`artifact_critic_frontmatter`·`artifact_adversarial_frontmatter`·`test_scope_validator_frontmatter`·`pr_understanding_builder_frontmatter`·`runtime_verifier_frontmatter`·`adversarial_model_consistency`), spec-distill 6 (`blind_spot_prober_frontmatter`·`coverage_mapper_frontmatter`·`seed_agents`·`spec_reviewer_frontmatter`·`brief_agents`·`steelman_builder_scope`) | 「`inherit` 매치 → ok」를 「C2 regex 매치 → **no**」로. 표기가 파일마다 다르다 — `'^model: inherit$'`, `'^model:[[:space:]]*inherit$'`, `[ "$ml" = "inherit" ]`(seed_agents) — 그래서 반전 대상은 substring grep 이 아니라 위 열거로 확정한다. `adversarial_model_consistency` 는 README 문구 앵커 2개(`(Phase 1.5, inherit)`·`` `adversarial` agent uses `model: inherit` ``)도 새 문구로. |
| 규약 문장 | `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` AC8d | C3 대로 — 양성 앵커 교체 + 기존 음성 단언 제거 + 새 음성 단언(옛 리터럴 부재·코드 예시 부재). |

**3. 문서·본문 — `inherit` 를 현재 사실로 서술하는 곳 전수** (2026-09-06 `grep -rni inherit` 후 분류; 이력·fixture·무관 어휘 제외)

- `docs/plugin-authoring.md:23` 조항 → 새 문장: 「**agent frontmatter 에 `model` 키를 두지 않는다.** 리터럴 티어(`opus`/`sonnet`/`haiku`)는 세션 선택을 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 덮어쓴다(CLI 2.1.261 실측, 2026-09-06). 키가 없으면 하니스는 「사용자 설정 → 세션 모델」 순으로 위임한다.」 하위 bullet(dispatch 재량)은 문면 유지(N5).
- `plugins/quality-gates/README.md` — 52(`inherit-tier`)·91(`model inherit`)·95·96(`inherit-tier`)·97(`model: inherit`)·172(`model: inherit`)·176(adversarial 모델 노트 문단)·209(`(Phase 1.5, inherit)`). 176 문단은 논지(「판정 병목은 하향되면 안 된다」)를 「하니스가 티어를 정하지 않는다 — 사용자 설정이 정한다」로 재작성하고 G4 안내 한 줄을 여기에 붙인다.
- `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md` — 6·156·157·175 의 `inherit-tier`(critic 을 가리키는 별칭) → 새 어휘. 289 는 `codex_available: false` 처리 문맥이라 같은 별칭이면 함께.
- `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:124` — 「`model: inherit`이 빌더 frontmatter에 선언돼 있다」 → 「빌더 frontmatter 에 `model` 키가 없다(여기서 override 하지 않음)」.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md:243` — 「on the inherited model」 → 「on the subagent's resolved tier」.
- `plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh:9-10` 주석 `inherit-tier` → 새 어휘.
- `plugins/quality-gates/scripts/experiment-model-override.md:16` 「현재 규약」 노트 갱신.
- `plugins/quality-gates/tests/e2e-scenarios.md:83·135` 기대값 문장(`model=inherit`) 갱신.
- 반전되는 락 16개의 헤더 주석(C6).
- CHANGELOG ×4, plugin.json ×4.

**4. plugin-audit 소비자 경계** — `plugins/plugin-audit/scripts/check-plugin-structure.sh:55-67` 은 agent 마다
plugin-dev 의 `validate-agent.sh` 를 돌리고, 실패 원인이 `color|model` 뿐이면 agent 당 `add_degr` 한 줄을 낸다.
오늘은 20개 중 19개가 `color:` 를 갖고 검증기가 통과하므로 이 줄이 나오지 않는다(2026-09-06 실행 확인).
핀을 빼면 검증기가 `❌ Missing required field: model` 을 내어 **agent 20개 전부에서 degrade 줄이 생긴다.**
결정: `model` 누락만이 원인인 실패는 devbrew 규약 준수이므로 degrade 가 아니다 — 필터를 「`model` 누락 단독
→ 기록 없음(규약 준수), `color` 누락 단독 → 기존 degrade 문구 유지」로 나눈다. 이 스크립트를 앵커하는 락은
없다(grep 확인) — 새 락 하나를 둔다: fixture agent(`model` 없음·`color` 있음)에 대해 degrade 0 줄, `model: opus`
를 넣은 fixture 에 대해서는 검증기가 통과하니 이 필터와 무관. 변이: 필터 분기를 지우면 fixture 에서 degrade 1 줄 → RED.

## Acceptance Criteria

- AC1. `git ls-files 'plugins/*/agents/*.md' | xargs grep -lE '^["'"'"']?model["'"'"']?[[:space:]]*:'` 가 0줄을 낸다.
- AC2. 새 스윕 락이 GREEN 이고, 임의의 agent 하나에 C2 의 변이 (a)~(e) 를 각각 넣으면 RED, `agents/` 매치가 10 미만이면 RED.
- AC3. 반전된 per-agent 락 14개 전부 GREEN 이고, 해당 agent 에 C2 변이 (a)·(d) 를 넣으면 그 락이 RED. 파일 하나가 agent 여럿을 보는 락(`seed_agents`·`brief_agents`)은 「그 파일에서 ≥1 RED」.
- AC4. `test_governance_no_capability_caps.sh` AC8d 가 새 처방 문장에서 GREEN, 옛 리터럴을 되살리면 RED, 새 문장을 지우면 RED.
- AC5. `grep -rnE 'model:[[:space:]]*inherit|"inherit"' plugins/*/tests shared/tests` 의 모든 hit 이 fixture(N6)·주석·음성 단언 중 하나로 분류되고, GREEN 조건으로 `inherit` 를 요구하는 단언은 0개다. 분류 결과를 CHANGELOG 가 아니라 PR 본문에 표로 남긴다.
- AC6. 사후 실측: 부록 프로브의 `probe-nomodel` 자리에 devbrew 의 실제 agent 하나(페르소나가 임의 지시를 그대로 수행하는 `plugin-audit:smoke-probe`)를 놓고 `CLAUDE_CODE_SUBAGENT_MODEL=haiku` 로 헤드리스 1회 → Haiku 보고. 환경변수 없이 1회 → 세션 모델 보고. 결과는 CHANGELOG 에 한 줄.
- AC7. 플러그인 4개 `plugin.json` minor bump + CHANGELOG 항목. 버전은 각각 `0.3.2→0.4.0`, `0.8.2→0.9.0`, `7.2.1→7.3.0`, `0.53.1→0.54.0`.
- AC8. `docs/plugin-authoring.md` 에 옛 처방 리터럴이 없고 §설계 3 의 새 문장이 있다.
- AC9. 착수 전 baseline 으로 「실패한 단언의 식별자 집합」(파일 + `no` 메시지 문자열)을 기록하고, 완료 후 집합에 **새 원소가 없다**. 줄 수 비교가 아니다 — 기존 실패가 사라지며 새 실패가 생기는 교차 회귀를 잡기 위함.
- AC10. agent 20개 중 17개는 diff 가 정확히 `-model: inherit` 한 줄. 나머지 3개(§설계 1)는 그 한 줄 + 본문 `inherit` 서술 수정만.
- AC11. `grep -rniE 'inherit' plugins docs/plugin-authoring.md` 의 잔여 hit 이 전부 (i) 이력(CHANGELOG·archive) (ii) fixture (iii) 음성 단언·주석 (iv) 무관 어휘(`inherits everything`·`inherit the env` 류) 중 하나다 — 현재 사실 서술로 남은 `inherit` 0건.
- AC12. plugin-audit: `check-plugin-structure.sh` 를 devbrew 플러그인 하나에 돌렸을 때 `validate-agent.sh(...)` degrade 줄이 0건이고, 새 락(§설계 4)이 GREEN + 변이 RED.

## Files to Modify

- `plugins/agent-transparency/agents/transcript-reader.md`
- `plugins/plugin-audit/agents/{audit-refuter,plugin-auditor,smoke-probe}.md`
- `plugins/quality-gates/agents/{adversarial,artifact-adversarial,artifact-critic,pr-understanding-builder,runtime-verifier,security-reviewer,test-scope-validator}.md` (`artifact-critic`·`artifact-adversarial` 은 본문도)
- `plugins/spec-distill/agents/{blind-spot-prober,brief-critic,brief-direction-reviewer,brief-readback,coverage-mapper,seed-critic,seed-readback,spec-reviewer,steelman-builder}.md`
- `plugins/quality-gates/tests/test_agent_model_inherit_sweep.sh` → `test_agent_model_unpinned_sweep.sh` (rename + 반전) + 그 이름을 인용하는 곳 전수
- `plugins/quality-gates/tests/{test_adversarial_persona,test_security_reviewer_persona,test_artifact_critic_frontmatter,test_artifact_adversarial_frontmatter,test_test_scope_validator_frontmatter,test_pr_understanding_builder_frontmatter,test_runtime_verifier_frontmatter,test_adversarial_model_consistency,test_governance_no_capability_caps}.sh`
- `plugins/spec-distill/tests/{test_blind_spot_prober_frontmatter,test_coverage_mapper_frontmatter,test_seed_agents,test_spec_reviewer_frontmatter,test_brief_agents,test_steelman_builder_scope}.sh`
- `plugins/plugin-audit/scripts/check-plugin-structure.sh` + 새 락 `plugins/plugin-audit/tests/test_check_plugin_structure_model_filter.sh`(이름은 plans 가 확정)
- `docs/plugin-authoring.md`
- `plugins/quality-gates/README.md`
- `plugins/quality-gates/skills/{critiquing-artifacts,publishing-pr-understanding,quality-pipeline}/SKILL.md`
- `plugins/quality-gates/scripts/{run_artifact_codex_reviewer.sh,experiment-model-override.md}`, `plugins/quality-gates/tests/e2e-scenarios.md`
- `plugins/{agent-transparency,plugin-audit,quality-gates,spec-distill}/.claude-plugin/plugin.json` + `CHANGELOG.md`

## Verification Plan

1. **baseline** — 착수 전 quality-gates·spec-distill·plugin-audit·shared 의 셸 락 전수를 돌려 「파일 + 실패 단언 메시지」 집합을 스크래치에 기록 (AC9).
2. **락 반전 먼저, agent 수정 나중** (TDD) — 반전 직후 스위트를 돌리면 반전된 락 16 파일 각각에서 ≥1 RED 여야 한다(agent 에 아직 `inherit` 가 있으므로). 이것이 락의 양성 대조다. 그 뒤 agent 20개를 고치면 GREEN.
3. **변이 다섯 + 하한** (C2) — 스크립트로 agent 하나씩 골라 (a)~(e) 삽입 → 스윕 락과 그 agent 의 per-agent 락이 RED 인지, 복원 후 GREEN 인지. 변이 전 커밋.
4. **규약 문장 변이** (AC4) — 옛 리터럴 복원 → RED, 새 문장 삭제 → RED.
5. **plugin-audit 필터 변이** (AC12).
6. **사후 헤드리스 실측** (AC6) — 부록 절차, agent 만 교체. `num_turns`·`tool_use.input.model` 부재까지 확인.
7. **어휘 스윕** (AC11) — `grep -rniE 'inherit' plugins docs/plugin-authoring.md` 잔여를 하나씩 (i)~(iv) 로 분류. 분류표는 PR 본문에.
8. **/qg** — 리뷰 게이트. 락·persona 파일을 건드리므로 보안-민감 편집으로 취급.

## Rejected Alternatives

- **R1. 전 agent `model: opus` 리터럴 핀** — #139 에서 실측 폐기. sonnet 세션에서 동의 없는 비용 증가, 설정으로 되돌릴 길 없음.
- **R2. `inherit` 유지 + dispatch 마다 오케스트레이터가 `model` 인자로 고른다** — writer 가 자기 리뷰어 티어를 고르는 구조(Law 2 취지 충돌), #139 규약 개정과 SKILL.md 약 18곳 수정 필요.
- **R3. 리포 무변경 + `_FORCE=1` 만** — 비용 목표는 즉시 달성(F4)하지만 frontmatter 층을 통째로 무시하고(F4, 실측), 문서 기술상으로는 dispatch 인자·외부 핀까지 덮는다(U2, 미실측). 그리고 락 16개가 지키는 명제와 근거의 어긋남(F2)이 남는다. 사용자가 일회성 스위치로 쓰는 것은 막지 않는다.
- **R4. 문서의 settings 키 `subagentModel` 에 의존** — 이 CLI 버전에 없음(F5). 나중에 들어오면 같은 우선순위 자리이므로 이 설계가 그대로 통과시킨다.
- **R5. 환경변수를 리포 `.claude/settings.json` 에 커밋** — N3.
- **R6. 프로브를 상시 락으로 승격** — 헤드리스 실행은 비용·비결정성이 있어 락이 아니라 사이클 종료 시 1회 측정(AC6)으로 둔다.
- **R7. 락 16개 삭제** — 부재 단언이 없으면 내일 누가 `model: sonnet` 을 박아도 아무 락이 안 운다(시간에 fail-open). 반전으로 대체.
- **R8. plugin-audit degrade 20줄을 그대로 수용** — 「규약을 지켰다」가 감사 리포트에 agent 당 degrade 로 찍히면 리포트가 거짓을 말한다. 필터 분기(§설계 4)가 더 싸다.
- **R9. 새 한국어 어법 음성 regex** — 기존 180행이 보여주듯 한 번 어긋나면 반대 방향으로 RED 를 낸다. 리터럴 두 개로 대체(C3).

## Open Questions

- OQ1. dispatch `model` 인자와 환경변수의 우선순위(U1) — 미실측. #139 규약(프로브·생성기 재량)의 실효성에 관계되지만 이 설계의 어느 AC 도 여기에 기대지 않는다. writing-plans 가 AC6 실측에 1회 추가할지 정한다.
- OQ2. 스윕 락 이름 변경 vs 유지 — 이름이 `inherit` 를 담고 있어 뒤집힌 뒤엔 오도한다. 설계는 rename 을 택했다. 인용 갱신 범위는 plans 단계에서 grep 으로 확정.

## Concrete Next Action

이 문서를 사용자가 검토 → `spec-distill:reviewing-spec` 리뷰 통과 → `superpowers:writing-plans` 로
구현 계획 작성. 계획의 첫 작업은 Verification Plan 1(baseline 실패 단언 집합 기록), 둘째는 2(락 반전 → 16 파일 RED 확인).

## 재결정 기록

| 원래 (#139, 2026-09-04) | 재결정 (2026-09-06) | 근거 |
|---|---|---|
| frontmatter 는 전부 `model: inherit` — "하니스가 사용자 모델 선택을 덮어쓰지 않는다" | frontmatter 에 `model` 키를 두지 않는다 | F2: `inherit` 가 사용자의 subagent 기본 티어 설정을 덮어쓴다 (실측 A·E) |
| `opus` 핀 폐기 사유 "Fable 세션에서 리뷰어 하향" | 사유는 유효. 하향을 사용자가 설정으로 고르는 것은 허용 | 하니스 결정 → 사용자 결정으로 층이 옮겨졌고 되돌릴 수 있음. 사용자 수용 |
| 리뷰 라운드 1 지적 — OQ3 「plugin-audit 필터 확인만」 | 필터 분기 변경(G6·§설계 4) | 검증기가 `model` 을 필수로 요구함을 실행으로 확인 — 20개 degrade 가 생긴다 |
| 리뷰 라운드 1 지적 — G5 「#139 후속 1 동승」 | 제외(N5) | 하위 bullet 이고 락이 앵커하지 않음 — 독립 |

## 부록 — 프로브 재현

플러그인 디렉토리 하나(`.claude-plugin/plugin.json` 에 `name: mprobe`)와 agent 둘:

```markdown
---
name: probe-nomodel
description: throwaway probe — frontmatter has NO model field
tools: Read
---
You are a probe. Reply with exactly one line: the model name your system prompt says you are powered by, quoted verbatim. Nothing else.
```

`probe-inherit` 는 위와 같고 frontmatter 에 `model: inherit` 한 줄 추가. 부모 프롬프트:

```
Use the Agent tool exactly twice, in parallel: subagent_type "mprobe:probe-nomodel" and subagent_type "mprobe:probe-inherit". Give each the prompt: "Report the model name stated in your system prompt, verbatim, one line." Do NOT pass a model parameter to either call. Then output exactly two lines and nothing else:
NOMODEL: <first agent's reply>
INHERIT: <second agent's reply>
```

실행:

```bash
CLAUDE_CODE_SUBAGENT_MODEL=haiku claude -p --model opus --plugin-dir ./mprobe \
  --permission-mode acceptEdits --output-format stream-json --verbose < prompt.txt > run.jsonl
```

`run.jsonl` 에서 확인할 것 셋 — `type=result` 의 `result` 두 줄, `num_turns`(3 이 정상; 0 은 조용한 실패),
`type=assistant` 안 `tool_use.name=Agent` 의 `input.model` 이 부재인지.
