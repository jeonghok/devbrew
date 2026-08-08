# 하니스 능력 억제 전수 census — 실측 기록

- **일자**: 2026-08-02 · **baseline**: `e45619b`
- **근거 핸드오프**: `docs/handoffs/2026-07-26-harness-capability-suppression-sweep.md`
- **설계**: `docs/superpowers/specs/2026-08-02-harness-capability-suppression-sweep-design.md`
- **방법**: 읽기전용 10축 병렬 조사(`plugin-audit:plugin-auditor` — `Glob, Grep, Read, WebSearch,
  WebFetch`만 보유, `Bash`·`Write` 물리적 부재) → 3슬라이스 **양방향** 반증(`plugin-audit:audit-refuter`).
  슬라이스는 축이 아니라 라운드로빈으로 나눠 finder와 refuter가 같은 프레이밍을 공유하지 않게 했다.
- **규모**: 13 agent · 110 findings + refuter 추가 14 · 2,077,370 subagent tokens · 41분

> **이 기록이 필요한 이유**: 억제 제거의 완결성 주장은 *무엇을 봤는지*에 달려 있다. 열거 없이
> "다 고쳤다"는 곧 "내가 고른 것만 고쳤다"이다. 후속 세션이 이 표를 재현·반증할 수 있어야 한다.

## 최종 분류

| 분류 | 건수 | 의미 |
|---|---|---|
| REMOVE | 36 | 능력 억제 — 제거 대상 |
| KEEP | 35 | load-bearing — 약화 금지 |
| USER_DECISION | 37 | 판단이 갈림 — 사용자에게 올림 |
| FALSE_POSITIVE | 2 | 반증 단계에서 사실 주장이 틀린 것으로 확인 |

**반증이 뒤집은 10건** — 이 census의 값은 여기 있다. 8건은 load-bearing을 억제로 오분류한 것을
되돌렸고(제거했다면 Law 2 분리·정확성 게이트가 무너졌을 것), 2건은 인용은 맞지만 핵심 사실
주장이 반증돼 기각됐다.

| id | finder 분류 | → 최종 | 위치 |
|---|---|---|---|
| `AGENTS-02` | USER_DECISION | **KEEP** | `plugins/quality-gates/agents/adversarial.md:6` |
| `AGENTS-10` | USER_DECISION | **REMOVE** | `plugins/spec-distill/agents/blind-spot-prober.md:41` |
| `AGENTS-13` | USER_DECISION | **REMOVE** | `plugins/spec-distill/agents/steelman-builder.md:41` |
| `ROOT-11` | USER_DECISION | **KEEP** | `docs/philosophy/devbrew-harness-philosophy.md:39` |
| `PA-01` | USER_DECISION | **KEEP** | `docs/plugin-authoring.md:29` |
| `QGSKILL-05` | USER_DECISION | **KEEP** | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:560` |
| `QGSKILL-08` | USER_DECISION | **KEEP** | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:127` |
| `QGSKILL-09` | USER_DECISION | **FALSE_POSITIVE** | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:170` |
| `MEM-05` | USER_DECISION | **FALSE_POSITIVE** | `~memory/project_law2_agent_tool_surface.md:40` |
| `HIST-09` | USER_DECISION | **KEEP** | `docs/superpowers/specs/2026-07-09-devbrew-context-slimming-design.md:425` |

## REMOVE — 제거 대상 (36)

`surface`가 `historical_record`인 항목은 제거가 아니라 **정정 append** 대상이다.

| id | 메커니즘 | surface | 위치 | 무엇을 억제하는가 |
|---|---|---|---|---|
| `AGENTS-01` | model_pin | 활성 | `plugins/quality-gates/agents/adversarial.md:4` | Review 게이트의 유일한 모델-판단 지점을 세션 모델과 무관하게 `opus` 별칭으로 고정해, 사용자가 더 강한(또는 별칭이 추적하지 않는) 모델로 세션을 돌려도 그 강도가 verdict에 도달하지 못하게 만든다. |
| `AGENTS-04` | model_pin | 활성 | `plugins/quality-gates/agents/pr-understanding-builder.md:4` | PR-이해 문서를 저술하는 이 파이프라인의 유일한 모델-판단 지점을 세션 모델과 분리해, 사용자가 선택한 모델 강도가 산출물 품질에 반영되지 못하게 한다. |
| `AGENTS-05` | model_pin | 활성 | `plugins/quality-gates/agents/test-scope-validator.md:3` | 테스트가 spec의 Acceptance Criteria를 실제로 덮는지 판단하는 유일한 지점을 세션 모델과 무관하게 sonnet으로 고정해, 강한 세션에서도 AC-커버리지 판단이 downgrade되게 한다. |
| `AGENTS-06` | narrowing_prompt | 활성 | `plugins/quality-gates/agents/test-scope-validator.md:39` | 후보 테스트 파일이 검증하려는 구현 소스와 spec 파일을 Read로 열어보지 못하게 막아, 50KB로 잘린 diff 밖의 변경에 대해서는 판단 자체를 불가능하게 만든다. |
| `AGENTS-08` | model_pin | 활성 | `plugins/spec-distill/agents/blind-spot-prober.md:3` | unknown-unknown을 찾아내는 적대적 premortem 전용 agent를 세션 모델과 무관하게 sonnet으로 고정해, 정확히 모델 강도가 결정적인 작업에서 세션의 강도를 버린다. |
| `AGENTS-09` | single_call_cap | 활성 | `plugins/spec-distill/agents/blind-spot-prober.md:40` | 단일 subagent 턴 안에서 웹 검색을 최대 2회로 묶어, 첫 두 질의가 빗나가면 더 찾을 수 있는데도 근거 없이 premortem을 내게 만든다. |
| `AGENTS-10` | narrowing_prompt | 활성 | `plugins/spec-distill/agents/blind-spot-prober.md:41` | 한 턴 안에서 독립적인 웹 질의를 동시에 던지는 것을 금지해, 같은 근거를 모으는 데 걸리는 라운드트립을 강제로 직렬화한다. |
| `AGENTS-11` | model_pin | 활성 | `plugins/spec-distill/agents/steelman-builder.md:3` | 대안의 가장 강한 논거를 구축하는 confirmation-bias 역행자를 세션 모델과 무관하게 sonnet으로 고정해, 사용자의 방향을 뒤집을 만한 논거의 강도를 구조적으로 낮춘다. |
| `AGENTS-12` | single_call_cap | 활성 | `plugins/spec-distill/agents/steelman-builder.md:40` | prior-art를 찾는 것이 존재 이유인 agent의 웹 검색을 단일 턴 안에서 최대 2회로 묶어, 성숙한 대안이 실재해도 첫 두 질의가 놓치면 '대안 약함'으로 결론 내게 만든다. |
| `AGENTS-13` | narrowing_prompt | 활성 | `plugins/spec-distill/agents/steelman-builder.md:41` | 한 턴 안의 독립적인 근거 질의를 동시에 던지지 못하게 해, prior-art 수집을 강제로 직렬화한다. |
| `AGENTS-14` | model_pin | 활성 | `plugins/spec-distill/agents/coverage-mapper.md:3` | 이 주제가 무엇을 놓치고 있는지(neglected dimension)를 발견하는 유일한 agent를 세션 모델과 무관하게 sonnet으로 고정한다. |
| `AGENTS-15` | model_pin | 활성 | `plugins/spec-distill/agents/spec-reviewer.md:3` | design doc의 적대적 리뷰어 — unstated assumption·untestable AC·isolation 결함을 잡는 유일한 Claude-측 지점 — 을 세션 모델과 무관하게 sonnet으로 고정한다. |
| `AGENTS-16` | tool_deficit | 활성 | `plugins/spec-distill/agents/spec-reviewer.md:6` | URL이 주어지면 열 수는 있지만 스스로 찾을 수는 없게 만들어, design doc이 단일 안만 제시했을 때(`approaches_comparison`) 실재하는 대안을 확인할 방법을 없앤다. |
| `ROOT-06` | codified_rule | 활성 | `CLAUDE.md:68` | 병렬 탐색·다중 리뷰어 구성을 '기본값에서 벗어난 예외'로 프레이밍해, 설계 단계의 모델이 독립 관점 다수가 필요한 문제에도 단일 agent 해법을 먼저 집도록 편향시킨다. |
| `ROOT-07` | codified_rule | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:96` | CLAUDE.md:68과 동일한 단일-agent 편향을 철학 레이어에서 반복해, 두 정본 모두를 읽는 세션에게 이중으로 각인시킨다. |
| `ROOT-08` | codified_rule | 활성 | `CLAUDE.md:69` | 모든 루프에 벽시계 예산을 필수 구성요소로 요구하여, 사람의 숙고 시간이 끼는 루프(인터뷰·리뷰 라운드)가 '오래 걸린다'는 이유만으로 중단되도록 설계를 강제한다. |
| `QGCODEX-01` | model_pin | 활성 | `plugins/quality-gates/scripts/run_codex_reviewer.sh:111` | 사용자가 ~/.codex/config.toml에 high/xhigh를 설정해 두었어도 qg 코드리뷰용 codex 호출만 medium으로 강제 하향시켜, 이 리포가 반복 실증한 '별-모델 codex가 same-family opus가 놓친 fail-open을 적발' 능력을 깎는다. |
| `QGART-01` | model_pin | 활성 | `plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh:39` | artifact-critique(`/qg critique`)의 별-모델 co-reviewer를 사용자 설정과 무관하게 medium 추론으로 고정해, 비-코드 산출물 비평에서 codex가 낼 수 있는 깊이를 상한한다. |
| `SDSPEC-01` | model_pin | 활성 | `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh:72` | design-doc 리뷰의 codex co-reviewer를 medium으로 고정해, spec-distill이 codex를 붙인 유일한 이유(Claude 리뷰어와 다른 계열의 적발력)를 사용자 설정보다 낮은 수준으로 묶는다. |
| `SDSPEC-02` | narrowing_prompt | 활성 | `plugins/spec-distill/scripts/build_spec_codex_prompt.py:29` | codex가 design doc에서 여섯 범주(placeholder/ambiguity/scope_creep/approaches_comparison/isolation/testing) 밖의 결함 — 예컨대 검증 게이트의 fail-open, 술어 반전, 상태 전이 누락 — 을 발견해도 보고하지 못하게 만든다. |
| `QGDETECT-01` | other | 활성 | `plugins/quality-gates/scripts/detect_codex.sh:39` | `timeout`/`gtimeout` 바이너리가 없다는 이유만으로 codex 리뷰어 **전체**를 unavailable로 선언해, 그 머신에서는 /qg가 영구히 same-family(Claude) 리뷰어만으로 돌게 만든다. |
| `SDDETECT-01` | other | 활성 | `plugins/spec-distill/scripts/detect_codex.sh:41` | 같은 조건(timeout 바이너리 부재)으로 spec-distill의 design-doc/brief codex co-reviewer를 통째로 unavailable 처리해, 리뷰가 Claude 단독으로 degrade되게 한다. |
| `QGREADME-01` | model_pin | 활성 | `plugins/quality-gates/README.md:143` | Review gate의 유일한 모델-기반 판단 게이트를 세션 모델과 무관하게 `opus` 리터럴로 고정하고, README가 그 고정을 '원칙 + 3-사이트 CI 락'으로 규약화해 미래 세션이 세션 모델을 따르지 못하게 만든다. |
| `QGREADME-02` | model_pin | 활성 | `plugins/quality-gates/README.md:139` | publish 산출물의 저자 모델을 세션 선택과 무관하게 `opus` 리터럴로 고정해, 세션이 더 강한 모델을 쓰고 있어도 그 능력을 쓰지 못하게 한다. |
| `QGREADME-03` | other | 활성 | `plugins/quality-gates/README.md:14` | trivia escape가 whitespace/rename만 커버한다고 규약화해, 이미 구현된 typo·주석-only·untracked-newfile diff에도 full 파이프라인을 돌리도록(= trivia ceremony) 유도한다. |
| `SDREADME-01` | tool_deficit | 활성 | `plugins/spec-distill/README.md:74` | design-doc 리뷰어가 저자가 링크해 둔 URL만 열 수 있고 저자 주장을 반증할 출처를 스스로 검색할 수 없게 만든다(URL은 열 수 있는데 찾을 수는 없음). |
| `SDSKILL-03` | other | 활성 | `plugins/spec-distill/skills/conducting-interview/SKILL.md:439` | 사용자가 확정 후보 목록 수정을 세 번째로 요구하면 모델이 게이트를 다시 띄우지 못하고, 확정도 handoff도 없이 인터뷰를 강제 종료해야 한다. |
| `SDSKILL-05` | teethless_check | 활성 | `plugins/spec-distill/skills/conducting-interview/SKILL.md:361` | 게이트를 통과하려면 저자가 매번 매직 주석 한 줄을 손으로 심어야 하고(빠뜨리면 첫 게이트 실행이 항상 red), 나중에 그 줄을 손으로 지우는 절차까지 짊어진다 — 통과가 아무 사실도 보장하지 않는데 실패만 생산한다. |
| `PAPI-01` | tool_deficit | 활성 | `plugins/project-init/commands/project-init.md:3` | command가 자기 본문이 두 번 명시적으로 요구하는 `AskUserQuestion`을 호출하지 못하게 만들어, Law 1 charter 구조 게이트(선택지 제시 + 최대 3회 재질문)를 자유서술 질문으로 격하시킨다. |
| `QGSKILL-01` | model_pin | 활성 | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:126` | PR-이해글 저자 에이전트를 세션 모델이 아니라 `opus` 리터럴에 묶고, 오케스트레이터가 dispatch 시점에 그 핀을 되돌리는 것까지 명시적으로 금지한다. |
| `QGSKILL-02` | codified_rule | 활성 | `plugins/quality-gates/skills/quality-pipeline/references/dependency-check.md:14` | 선택적 외부 플러그인(pr-review-toolkit) 하나가 없다는 이유로 Review gate 전체를 SKIP으로 표시하게 해, 현행 SKILL이 보장하는 Tier A floor(security-reviewer + adversarial)와 Tier B codex 리뷰까지 통째로 없앤다. |
| `QGSKILL-03` | codified_rule | 활성 | `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md:19` | SKILL이 게이트 verdict마다 `## History` 한 줄을 append하는 것(관측성 기록)을 전면 금지해, Final Summary가 출력하도록 지시받은 History 트리를 비게 만든다. |
| `MEM-01` | model_pin | 활성 | `~memory/feedback_respect_upstream_model_hardcoding.md:14` | 세션이 opus여도 `model: inherit` 에이전트를 dispatch 시점에 sonnet으로 강등하도록 허가해, frontmatter에서 제거 중인 모델 핀을 호출부로 이전시킨다. |
| `HIST-01` | tool_deficit | 이력 | `docs/superpowers/specs/2026-07-16-law2-agent-tool-surface-design.md:264` | spec-reviewer(Law 2 물리 분리 리뷰어)가 자기가 검증하려는 공식 문서·선례의 URL을 *찾을* 수 없게 만든다 — 이미 아는 URL만 열 수 있다. |
| `HIST-04` | single_call_cap | 이력 | `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md:667` | blind-spot-prober가 **단일 dispatch 안에서** 웹 검색을 사실상 2회로 묶고 병렬 조회까지 금지해, 적대적 premortem의 근거 폭을 프롬프트로 상한 처리한다. |
| `HIST-05` | model_pin | 이력 | `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md:630` | blind-spot-prober(적대적 premortem — unknown-unknowns 발굴이 존재 이유)를 세션 모델과 무관하게 sonnet으로 고정한다. |

## USER_DECISION — 판단 필요 (37)

사용자 방침(2026-08-02): *"룰은 최대한 들어내는 방향"* — 애매하면 제거가 default.

| id | 메커니즘 | surface | 위치 | 무엇을 억제하는가 |
|---|---|---|---|---|
| `AGENTS-03` | narrowing_prompt | 활성 | `plugins/quality-gates/agents/adversarial.md:149` | 파이프라인에서 가장 강한 모델이 값싼 리뷰어들이 놓친 실제 결함을 발견해도, 그것을 사용자가 실제로 행동하는 findings 표에 올리지 못하게 하고 승격되지 않는 단일 각주로 강등시킨다. |
| `AGENTS-07` | tool_deficit | 활성 | `plugins/quality-gates/agents/security-reviewer.md:38` | 새로 추가·업그레이드된 의존성이 실제로 알려진 취약점을 갖는지 확인할 수단(WebSearch/WebFetch)이 allowlist에 없어, 보안 리뷰어가 CVE 판정 대신 '나중에 확인하라'는 무판정 항목만 낼 수 있게 한다. |
| `ROOT-03` | codified_rule | 활성 | `CLAUDE.md:43` | 6개 이상의 병렬 subagent가 필요한 설계(예: 이 감사의 6축 fan-out)를 하려면 추가 설계 리뷰 관문을 통과해야 하므로, 저자가 관문을 피해 4개 이하로 축소하도록 유인한다. |
| `ROOT-04` | codified_rule | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:63` | CLAUDE.md:43과 같은 fan-out 임계를 철학 레이어에서 'Load-bearing'으로 격상시켜, 임계치 자체가 재평가 불가한 KEEP-12 원칙의 일부로 읽히게 만든다. |
| `ROOT-09` | codified_rule | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:43` | 두 파일 이상에 걸친 한 줄짜리 변경(같은 오타 3곳 수정, 심볼 rename)에도 Law 1 전체 스펙 게이트를 강제해, CLAUDE.md:67이 스스로 금지한 trivia ceremony를 규칙으로 요구한다. |
| `ROOT-10` | codified_rule | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:20` | KEEP-12 목록에 포함된 비용 임계치(P22의 N≥5·cost_class)까지 '모델이 좋아져도 재평가 대상이 아니다'로 선언해, 미래 세션이 그 임계치를 재검토하는 것 자체를 규칙 위반으로 읽게 만든다. |
| `WEBBUDGET-01` | single_call_cap | 활성 | `plugins/spec-distill/scripts/web_budget.py:45` | 인터뷰 세션 전체에서 웹 검색을 최대 8회(한 sweep 안에서는 4회)로 묶어, 그 이후에는 외부 landscape/prior-art 조사를 아예 하지 못하고 사용자 질문으로 강제 전환시킨다. |
| `SDREADME-02` | tool_deficit | 활성 | `plugins/spec-distill/README.md:110` | 인터뷰의 주제-도출 차원 제안자가 prior art·외부 사례를 한 번도 조회하지 못한 채 대화·리포 안에서만 차원을 제안하게 만든다. |
| `SDCHG-01` | single_call_cap | 이력 | `plugins/spec-distill/CHANGELOG.md:542` | ‘강한 문제공간 인터뷰’의 외부 리서치를 sweep당 4회·세션당 8회로 결정론적으로 묶고, 사용자에게는 웹을 끄는 스위치만 주고 상한을 올리는 경로는 주지 않는다. |
| `PA-02` | codified_rule | 활성 | `docs/plugin-authoring.md:33` | 정책의 '유일한 소스'를 자처하면서 agent `model:` 규약을 한 줄도 담지 않아, 새 플러그인이 reference 구현(quality-gates)의 `model: opus` 리터럴 핀을 그대로 복제하는 것을 막지 못한다. |
| `QGCHG-02` | model_pin | 이력 | `plugins/quality-gates/CHANGELOG.md:1133` | opus 리터럴을 세 선언 사이트에 CI 락으로 묶어, 어느 한 곳을 `model: inherit`으로 바꾸는 변경이 즉시 테스트 RED가 되게 한다 — 핀 제거에 실질 비용을 부과한다. |
| `CHECKS-01` | teethless_check | 활성 | `plugins/spec-distill/scripts/parse_spec_structure.py:45` | 아무것도 억제하지 않는다 — 반대로, Law 1 구조 게이트가 코드 펜스 안에 인용된 헤더 한 줄로 만족돼 섹션이 실제로 없는 spec을 통과시킨다(fail-open). |
| `CHECKS-02` | guard_on_nl_intent | 활성 | `plugins/spec-distill/scripts/parse_spec_structure.py:162` | 단어 경계 없는 부분문자열 매칭이라, `inefficient`·`fast-forward`·`improperly` 같은 정상 기술 용어가 금지어로 잡혀 spec/design 문서 작성이 hook exit 2로 차단된다. |
| `CHECKS-03` | teethless_check | 활성 | `plugins/plugin-audit/scripts/check-shape-completeness.py:100` | 아무것도 억제하지 않는다 — 반대로, frontmatter가 아예 없는(=런타임이 쓰기 가능 기본 도구를 주는) agent 파일이 본문의 `---` 두 개 사이에 `tools:` 한 줄만 있으면 Law 2 allowlist 검사를 통과한다. |
| `CHECKS-04` | teethless_check | 활성 | `plugins/plugin-audit/scripts/check-shape-completeness.py:175` | 아무것도 억제하지 않는다 — kill switch(보안 컨트롤)를 docstring에 **적기만** 하고 실제로 존중하지 않는 훅이 이 검사를 통과한다. |
| `CHECKS-05` | teethless_check | 활성 | `plugins/quality-gates/scripts/check-changelog-korean-primary.py:77` | 이미 얼어붙은 [1.32.0] 절만 검사하므로 앞으로 추가되는 어떤 CHANGELOG 항목에도 발화하지 않는다 — 동시에, 실행되면 단락마다 한글 1자를 강제해 영어 원문 인용 단락을 거짓 실패시킨다. |
| `CHECKS-06` | other | 활성 | `plugins/quality-gates/scripts/synthesize_findings.py:180` | confidence<=4인 non-CRITICAL findings을 사용자에게서 영구히 감춘다 — 안내된 복구 경로 `/qg --show-low-confidence`가 리포 어디에도 구현돼 있지 않기 때문이다. |
| `CHECKS-07` | other | 활성 | `plugins/quality-gates/scripts/synthesize_findings.py:70` | 같은 file:line·같은 severity의 서로 다른 지적을 한 건으로 접어버려, 두 번째 리뷰어의 findings 본문이 사라지고 남은 한 건에 그 리뷰어 이름이 출처로 덧붙는다(허위 귀속). |
| `SDSKILL-01` | narrowing_prompt | 활성 | `plugins/spec-distill/skills/conducting-interview/SKILL.md:293` | 인터뷰 오케스트레이터가 한 sweep에서 4회·세션 전체에서 8회를 넘겨 웹을 검색하지 못하게 하며, 그 천장을 올릴 사용자 승인 경로도 env override도 문서에 없다. |
| `SDSKILL-02` | tool_deficit | 활성 | `plugins/spec-distill/skills/reviewing-brief/SKILL.md:212` | 방향성 리뷰어(축 자체가 '근거 폭이 본질'이라고 선언된 리뷰어)에게 웹 도구를 쓰지 말라고 프롬프트로 지시해, 인터뷰가 이미 소진한 예산 때문에 외부 근거 없이 판정하게 만든다. |
| `SDSKILL-04` | other | 활성 | `plugins/spec-distill/skills/conducting-interview/SKILL.md:249` | 인터뷰가 아무리 길어지고 문제정의가 얼마나 크게 바뀌든, unknown-unknown을 표면화하는 적대적 premortem 에이전트를 두 번째로 돌릴 수 없다(재dispatch 금지). |
| `SDSKILL-06` | other | 활성 | `plugins/spec-distill/skills/reviewing-brief/SKILL.md:104` | devbrew 리포 밖(= 마켓플레이스로 설치돼 실제 프로젝트에서 /interview를 돌리는 정상 사용)에서는 참조 파일이 존재하지 않으므로 brief 리뷰 파이프라인 전체 — 방향성·충실도·냉독·codex 2회·§6 원문 완전성 검사 — 가 아예 시작되지 못한다. |
| `PAPI-02` | narrowing_prompt | 활성 | `plugins/project-init/commands/project-init.md:113` | 모델이 charter 산출물의 빈 필드(success criteria·personas·naming·error handling·anti-patterns)를 채우기 위해 추가 질문을 던지는 것을 규칙으로 금지해, 생성물이 구조적으로 절반 비어 나오게 만든다. |
| `PAPI-03` | codified_rule | 활성 | `plugins/project-init/hooks/docs-lint.py:123` | detail을 담으라고 만든 `docs/project/*.md`에까지 200줄 상한 조언을 걸어, 모델이 charter 상세 문서를 계속 잘라내거나 무의미하게 분할하도록 압박한다. |
| `PAPI-07` | codified_rule | 활성 | `plugins/project-init/templates/github-flow/branch-strategy.md:63` | 다른 사용자의 프로젝트에 '`git rebase` 절대 금지'라는 무조건 규칙을 심어, 그 프로젝트의 에이전트가 push 전 로컬 브랜치 정리처럼 안전한 rebase까지 거부하게 만든다. |
| `QGSKILL-04` | narrowing_prompt | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:546` | 리뷰어 선택을 6행 rubric 메뉴 안으로 닫아, 설치돼 있고 같은 플러그인 문서가 광고하는 다른 리뷰 에이전트(superpowers:code-reviewer, feature-dev:code-explorer 등)를 스코프가 요구해도 디스패치하지 못하게 한다. |
| `QGSKILL-06` | single_call_cap | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:862` | 한 iteration 안에서 같은 리뷰어를 두 번 부르지 못하게 해, 큰 diff를 나눠(backend/frontend, 또는 컨텍스트 초과 시 분할) security-reviewer를 두 번 돌리는 전략을 차단한다. |
| `QGSKILL-07` | guard_on_nl_intent | 활성 | `plugins/quality-gates/commands/qg.md:92` | 게이트가 실제로 비중단 완료했더라도 파이프라인이 sentinel 파일을 남기지 못한 경로(trivia escape, 세션-id 분기, 두 write 지점을 지나지 않는 종결)에서는 PR-이해글 게시 offer를 조용히 봉쇄한다. |
| `MEM-02` | codified_rule | 활성 | `~memory/feedback_respect_upstream_model_hardcoding.md:9` | "하드코딩된 모델 핀은 품질 보장"이라는 무한정 일반 원칙을 남겨, 스윕이 devbrew 자기 소유 에이전트의 `model: sonnet` 핀을 제거할 때 인용될 수 있는 반대 근거를 제공한다. |
| `MEM-03` | model_pin | 활성 | `~memory/project_spec_distill_interview_coverage_driven.md:24` | 미래 subagent-driven 사이클에서 구현 역할(writer)을 기본적으로 sonnet으로 내리도록 처방해, 세션이 더 강한 모델일 때 구현 품질을 하향 고정한다. |
| `HIST-02` | tool_deficit | 이력 | `docs/superpowers/specs/2026-07-16-law2-agent-tool-surface-design.md:265` | 보안 리뷰어가 CVE·알려진 취약점 패턴·라이브러리 advisory를 외부에서 확인하지 못하게 만들어 취약점 판정을 자기 사전지식에만 의존시킨다. |
| `HIST-03` | tool_deficit | 이력 | `docs/superpowers/specs/2026-07-16-law2-agent-tool-surface-design.md:269` | breadth-keeper(현 coverage-mapper)가 '이 주제가 어떤 커버리지 차원을 요구하는가'를 제안하면서 그 landscape 근거를 외부에서 찾지 못하게 만든다. |
| `HIST-06` | model_pin | 이력 | `docs/superpowers/plans/2026-07-20-spec-distill-interview-coverage-driven.md:479` | coverage-mapper(주제-도출 커버리지 차원 제안 + neglect flag)를 세션 모델과 무관하게 sonnet으로 고정한다. |
| `HIST-07` | codified_rule | 이력 | `docs/superpowers/specs/2026-07-20-spec-distill-interview-coverage-driven-design.md:98` | 인터뷰(그리고 같은 카운터를 쓰는 모든 하류 단계)의 외부 조사 깊이를 세션 8회로 묶고, 그 상한을 올리는 것 자체를 규범으로 금지한다. |
| `HIST-08` | narrowing_prompt | 이력 | `docs/superpowers/specs/2026-07-27-spec-distill-brief-review-pipeline-design.md:401` | brief 방향성 리뷰어('사용자가 잡은 방향 자체가 틀렸을 가능성'을 보는 유일한 역할)가 인터뷰가 이미 예산을 소진한 경우 외부 근거 없이 판정하도록 프롬프트로 강제된다. |
| `HIST-10` | other | 이력 | `docs/superpowers/specs/2026-07-12-project-init-audit-workflow-design.md:881` | CRITICAL/HIGH 발견이 9건 이상인 감사에서 9번째부터는 심층검증(추가 2렌즈 반박)을 아예 받지 못하게 만든다 — 검증 깊이가 발견 수와 무관하게 8로 잘린다. |
| `HIST-11` | codified_rule | 이력 | `docs/superpowers/plans/2026-07-17-law2-agent-tool-surface.md:1010` | spec-reviewer의 도구 목록을 정확 문자열로 못 박아, WebSearch를 **추가**하는 변경까지 회귀 락이 RED로 잡게 만든다. |

## KEEP — load-bearing (35)

이 항목들을 제거하면 무언가가 **조용히 통과**하게 된다. 그것이 유지 근거다.

| id | 메커니즘 | surface | 위치 | 무엇을 억제하는가 |
|---|---|---|---|---|
| `AGENTS-02` | other | 활성 | `plugins/quality-gates/agents/adversarial.md:6` | 직접적인 능력 억제는 아니지만, 최상위 티어 모델을 쓰는 게이트를 `low`로 신고해 CLAUDE.md의 비용-승인 규율(`high`는 지출 전 승인 게이트)이 이 지점에서 의미를 잃게 한다. |
| `ROOT-01` | other | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:75` | 근거(보안/정확성) 없는 결정론 가드를 하니스에 추가하는 것을 막는다 — 모델이 아니라 하니스 저자를 제약한다. |
| `ROOT-02` | other | 활성 | `CLAUDE.md:43` | cost_class: high 스킬이 사용자 확인 없이 곧바로 지출하는 것을 막는다 — 능력의 상한이 아니라 지출 시점의 동의 요구다. |
| `ROOT-05` | codified_rule | 활성 | `CLAUDE.md:68` | fan-out을 하되 그 사실과 N을 사용자에게 알리지 않는 것을 막는다 — fan-out 자체는 막지 않는다. |
| `ROOT-11` | codified_rule | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:39` | 교차 모델 리뷰를 '고위험 순간에만 켜는 opt-in'으로 규정해, 일반 리뷰에서는 모델 다양성이라는 backstop 없이 same-family 공유 맹점 상태로 진행되도록 기본값을 고정한다. |
| `ROOT-12` | other | 활성 | `docs/philosophy/devbrew-harness-philosophy.md:11` | 명세가 모호할 때 '모델이 알아서 잘 하겠지'로 넘어가는 것을 막는다 — Law 1 구조적 게이트 안으로 범위가 한정돼 있다. |
| `ROOT-13` | other | 활성 | `docs/git-workflow/branch-strategy.md:63` | feature 브랜치 최신화 수단으로 rebase를 선택하는 것을 절대 금지한다 — 도구 하나를 통째로 닫는다. |
| `ARTROUNDS-01` | other | 활성 | `plugins/quality-gates/scripts/artifact_max_rounds.sh:2` | artifact critique 루프를 기본 5라운드, 사용자 env로도 최대 10라운드까지만 돌게 제한한다. |
| `BRIEFROUNDS-01` | other | 활성 | `plugins/spec-distill/scripts/brief_review_state.py:33` | brief 충실도 수정-재리뷰 루프를 재dispatch 2회로 묶어, 3번째 수정 라운드를 자동으로 돌지 못하게 한다. |
| `PROBECAP-01` | other | 활성 | `plugins/spec-distill/scripts/probe_budget.py:30` | 인터뷰 probe(사용자 질문-답변 교환)를 기본 12회로 gate한다 — 단, 사용자가 '계속'을 고르면 base cap만큼 상한이 올라간다. |
| `SANDBOX-01` | other | 활성 | `plugins/quality-gates/scripts/run_codex_reviewer.sh:110` | codex 리뷰어가 워킹트리에 어떤 파일도 쓰지 못하게 OS 레벨에서 막는다. |
| `STAGNATION-01` | other | 활성 | `plugins/quality-gates/scripts/artifact_stagnation.py:28` | `--changed` 신호가 true/false가 아니면 정체(stagnant)로 판정해 critique 루프를 그 라운드에서 종료시킨다. |
| `PA-01` | narrowing_prompt | 활성 | `docs/plugin-authoring.md:29` | 새 플러그인 설계 단계에서 참조할 것을 skill 하나로 규정해, 그 시점의 prior-art 조사·다른 컴포넌트 문법 확인을 '필요 없는 것'으로 읽게 만든다. |
| `QGCHG-01` | model_pin | 이력 | `plugins/quality-gates/CHANGELOG.md:338` | 이 줄 자체는 아무 능력도 억제하지 않는다 — QGREADME-02의 핀이 언제·왜 들어왔는지의 기록이며, 지우면 그 이유가 사라진다. |
| `PICHG-01` | codified_rule | 이력 | `plugins/project-init/CHANGELOG.md:80` | 억제하지 않는다 — 반대로, 타깃 프로젝트 CLAUDE.md에 주입되던 4-bullet 행동 제약이 '제안 표면을 줄인다'는 이유로 전면 제거된 사실의 기록이다. |
| `SDSKILL-07` | other | 활성 | `plugins/spec-distill/skills/conducting-interview/SKILL.md:206` | (억제 아님) probe cap 12는 floor 미충족 상태의 probe 루프에만 걸리며, 도달 시 사용자 승인으로 무제한 상향된다. |
| `SDSKILL-08` | other | 활성 | `plugins/spec-distill/skills/reviewing-brief/SKILL.md:402` | (억제 아님) 충실도 재리뷰를 라운드당 1회씩 최대 2회로 묶고, 상한 도달 시 차단이 아니라 사용자 게이트로 이관한다. |
| `SDSKILL-09` | other | 활성 | `plugins/spec-distill/skills/reviewing-spec/SKILL.md:109` | (억제 아님) design doc 리뷰 반복이 5라운드를 넘으면 모델이 자동으로 또 한 라운드를 돌리지 못하고 사람 게이트로 넘긴다. |
| `SDSKILL-10` | teethless_check | 활성 | `plugins/spec-distill/templates/interview-audit-template.md:52` | (억제 아님) 리뷰 라운드 기록을 게이트로 승격시키지 않겠다는 선언 — 통과를 보장으로 오독시키는 검사를 의도적으로 만들지 않았다. |
| `PAPI-04` | other | 활성 | `plugins/project-init/commands/project-init.md:124` | (억제 아님) 실재하는 재질문 루프에 상한을 두어 사용자가 답을 주지 못할 때 무한 질문 루프를 끊는다. |
| `PAPI-05` | other | 활성 | `plugins/plugin-audit/scripts/audit-workflow.js:633` | (발견 억제 아님) 생존 CRITICAL/HIGH가 8건을 넘으면 초과분에 대해 2개 추가 렌즈의 *반박*을 실행하지 않는다 — 발견 자체는 리포트에 남는다. |
| `PAPI-06` | other | 활성 | `plugins/plugin-audit/scripts/codex-prompt-preamble.md:15` | (억제 없음) preamble에는 검색 금지·읽기 횟수 제한·finding 개수 상한이 존재하지 않는다. |
| `PAPI-08` | teethless_check | 활성 | `plugins/project-init/hooks/docs-lint.py:395` | (억제 아님) 통과 조건이 '작성자가 쓴 한 줄'이라 품질 보증은 못 하지만, 미치환 `{{VISION}}` 잔재와 라벨 누락이라는 기계적 실패는 실제로 잡는다. |
| `PAPI-09` | teethless_check | 활성 | `plugins/plugin-audit/skills/auditing-plugins/SKILL.md:55` | (억제 아님 — 반대 방향) 통과 조건이 '파일 부재' 단일 신호라, probe가 죽어 아무것도 실행되지 않은 경우와 allowlist가 실제로 Bash를 막은 경우가 구분되지 않는다. |
| `QGSKILL-05` | narrowing_prompt | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:560` | scout가 quick/standard depth를 내면 Tier C 전문가를 0~2명으로 줄이라고 프롬프트가 수치로 지시해, 작은 diff에 숨은 신호(예: 40줄짜리 crypto·역직렬화 변경)에 대해 전문가를 더 부르려는 모델 판단을 억제한다. |
| `QGSKILL-08` | narrowing_prompt | 활성 | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:127` | 산출물 비평의 리뷰어 구성을 고정 3인(동시 2)으로 못 박아, 대상 문서 성격(스펙 vs 설계 vs 설정)에 맞춘 추가 전문가 투입을 배제한다 — 같은 플러그인 코드 경로의 3-tier 스코프-구동 구성과 대조적이다. |
| `QGSKILL-10` | single_call_cap | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:285` | iteration 2–5에서 changes-exist 신호를 다시 측정하지 못하게 한다(`branch_ahead_count` / `worktree_dirty` / `degraded`가 iter-1 값으로 고정). |
| `QGSKILL-11` | other | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:259` | 리뷰-수정 루프를 5회에서 끊는다(그 뒤로는 사용자 선택으로만 진행/중단). |
| `QGSKILL-12` | other | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:749` | runtime-verifier가 한 dispatch 안에서 setup 자동수정 재시도를 3회로 끊고 그 뒤에는 사용자 판단(block_policy)으로 넘긴다. |
| `QGSKILL-13` | other | 활성 | `plugins/quality-gates/skills/quality-pipeline/SKILL.md:770` | mid-run 해상도 질문 루프를 기본 3회(최대 10회)로 끊고, 소진 시 skip-with-evidence로 흘린다. |
| `QGSKILL-14` | other | 활성 | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:117` | 비평-수정-재비평 자율 루프를 effective_max_rounds(기본 5)에서 끊는다. |
| `MEM-04` | single_call_cap | 이력 | `~memory/project_spec_distill_interview_frontstage.md:18` | 인터뷰의 외부 조사 깊이를 sweep당 4회·세션당 8회로 못 박아, 주제가 더 넓은 조사를 요구해도 모델이 더 찾지 못하게 한다. |
| `MEM-06` | codified_rule | 활성 | `~memory/feedback_evidence_before_approved.md:18` | 구현 subagent의 동시 실행을 무조건 금지해, 서로 무관한 파일을 만지는 태스크들의 병렬 처리까지 막는다. |
| `MEM-07` | single_call_cap | 이력 | `~memory/project_spec_distill_interview_coverage_driven.md:11` | 인터뷰가 제시할 수 있는 probe 수를 12로 제한한다(override 있음). |
| `HIST-09` | codified_rule | 이력 | `docs/superpowers/specs/2026-07-09-devbrew-context-slimming-design.md:425` | 5개 이상 병렬 subagent가 필요한 작업 전반에 authoring-time hard-review 부담을 걸어 병렬 탐색을 default에서 밀어낸다(그 짝인 philosophy의 'single-agent가 default'). |

## FALSE_POSITIVE — 기각 (2)

반증자가 인용은 확인했으나 핵심 사실 주장이 성립하지 않았다.

| id | 메커니즘 | surface | 위치 | 무엇을 억제하는가 |
|---|---|---|---|---|
| `QGSKILL-09` | narrowing_prompt | 활성 | `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:170` | artifact-adversarial에게 기존 finding에 대한 confirm/downgrade/reject 판정만 요구해, 산출물을 직접 읽는 두 번째 독립 리뷰어가 critic이 놓친 결함을 이번 라운드에 올릴 채널을 주지 않는다. |
| `MEM-05` | tool_deficit | 이력 | `~memory/project_law2_agent_tool_surface.md:40` | 리뷰어의 웹 조사 능력이 이미 보존돼 있다고 단언해, 실제로는 웹 도구가 없는(또는 WebFetch만 있는 비대칭) 리뷰어의 도구 결핍 수정을 불필요한 것으로 보이게 만든다. |

## 반증자가 추가로 발견 (14)

finder가 같은 파일의 다른 줄을 놓친 사례가 다수다 — 한 파일에서 `model:` 핀을 찾은 뒤
같은 파일 본문의 검색 횟수 상한을 지나쳤다. **핀의 실제 이빨인 테스트 락도 여기서 나왔다.**

| 메커니즘 | 분류 | 위치 |
|---|---|---|
| single_call_cap | REMOVE | `plugins/spec-distill/agents/steelman-builder.md:40` |
| single_call_cap | REMOVE | `plugins/spec-distill/agents/blind-spot-prober.md:40` |
| narrowing_prompt | USER_DECISION | `plugins/quality-gates/agents/test-scope-validator.md:39` |
| codified_rule | REMOVE | `plugins/quality-gates/tests/test_adversarial_model_consistency.sh:54` |
| codified_rule | REMOVE | `plugins/quality-gates/tests/test_adversarial_persona.sh:56` |
| codified_rule | REMOVE | `plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh:19` |
| codified_rule | REMOVE | `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:126` |
| model_pin | USER_DECISION | `~memory/feedback_respect_upstream_model_hardcoding.md:14` |
| tool_deficit | USER_DECISION | `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh:69` |
| model_pin | REMOVE | `plugins/spec-distill/scripts/run_spec_codex_reviewer.sh:72` |
| codified_rule | REMOVE | `plugins/spec-distill/tests/test_run_spec_codex_reviewer.sh:35` |
| model_pin | REMOVE | `plugins/quality-gates/agents/pr-understanding-builder.md:4` |

## 남는 한계

- 이 census는 **1회 실측이고 자동 회귀가 없다.** 새 억제가 들어와도 이 표는 갱신되지 않는다.
  알아채는 수단은 설계 §2의 판별 질의를 다시 돌리는 것뿐이다.
- 축별 auditor는 **자기 축 밖 파일을 조사하지 않았다**(설계상 격리). 그래서 축 경계에 걸친
  결함은 반증 단계에서만 드러났다 — 실제로 그렇게 드러난 것이 위 추가 발견 표다.
- `plugins/*/tests/`는 최초 10축에 **없었다.** 테스트가 억제를 락으로 고정한다는 사실은
  반증 단계와 별도 수동 조사에서 나왔다. 축 설계 자체의 사각지대였다.
- 분류는 판단이다. `USER_DECISION`이 37건인 것은 실패가 아니라 **애매한 것을 억지로
  판정하지 않은 결과**다 — 판정을 강요했다면 그 숫자만큼 근거 없는 확신이 생겼을 것이다.
