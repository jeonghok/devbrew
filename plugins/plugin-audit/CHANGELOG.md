# Changelog

## [0.9.0] — 2026-09-06

### Changed

- **agent frontmatter 의 `model: inherit` 를 제거했다 — `inherit` 는 사용자의 subagent
  기본 티어 설정을 덮어쓴다 (CLI 2.1.261 실측, 2026-09-06).** frontmatter 에 `model` 키가
  없으면 하니스가 「`CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델」 순으로 위임하고, `inherit` 는
  그 첫 단계를 건너뛴다(헤드리스 probe 6회, 설계 §A). 설정이 없는 환경은 동작이 같다.
  규약·락은 「키 부재」 단언으로 반전 — 정본은
  `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md`.

### Fixed

- **구조 검사가 `model` 키 부재를 degrade 로 세던 것.** plugin-dev `validate-agent.sh` 는
  `model` 을 필수로 요구하는데 그것은 devbrew 규약이 아니다 — 핀을 빼면 agent 마다 degrade
  한 줄이 생겼을 것이다. `check-plugin-structure.sh` 가 `model` 누락 단독은 기록하지 않고
  `color` 누락 단독만 기존대로 degrade 로 남긴다. 구현 중 확인: plugin-dev 검증기는 model 키 없는 agent 에서 ❌ 없이 조용히 죽는다(rc=1) — 그 경우는 agent 별이 아니라 플러그인당 집계 1줄로, model 키가 있는데 죽으면 agent 별 스퓨리어스 exit 줄로 기록한다(테스트 4건, 양성 짝 포함).

## [0.8.2] — 2026-09-05

### Fixed

- **README 의 「Principles Instantiated」에 이 사이클의 instantiation 이 없었다
  (최종 리뷰 K6b).** `처분`·`adjudication`·`Ledger`·`input_slots` 를 전수 grep 하면
  히트 0 이었다. `input_slots`(agent 셋 + `audit-refuter.findings` 의 C6 면제)와
  codex 러너의 `**처분**` 앵커 두 줄을 더했다. **범위 한계를 함께 적었다**: 이
  플러그인의 dispatch 는 `audit-workflow.js` 의 `agent(prompt, {agentType})` 라
  `shared/tests/test_agent_input_slots.sh` 의 `.md` dispatch 코퍼스에 «안 보이고»,
  셋 다 그 락의 새 `unmeasured` 축으로 세어져 이름이 나온다.
- **원장 정정 — `optional: true` 는 이 플러그인의 agent 셋에서 «무동작이 아니다».**
  SDD 원장이 「`optional: true` 는 판정기가 정적 텍스트만 보므로 무동작」이라고
  일반화해 적었는데, dispatch 가 `.md` 코퍼스 밖인 이 셋에서는 **유일한 침묵
  장치**다 — `smoke-probe.md` 에서 그 한 줄만 지우면 `PROBLEM undelivered` 로 즉시
  RED 가 된다(실측). 원장을 정정했다.

## [0.8.1] — 2026-09-04

### Fixed
- **Task 14 수정 라운드 1** — `tools/adjudication/check_slots.py`(L3 판정기,
  `plugins/*/agents/*.md` 전부를 검사)의 dispatch 펜스 스캐너가 들여쓴 펜스를
  구조적으로 못 보고, 한 펜스에 subagent_type 둘이면 조용히 첫 번째로만
  귀속하던 결함을 고쳤다 — 상세는 quality-gates CHANGELOG v6.6.1 참조. 이
  플러그인은 이 판정기의 검사 대상(plugin-auditor·audit-refuter·smoke-probe)이라
  선례대로 함께 bump. 이 라운드에서 이 플러그인의 파일 자체는 변경 없음.

## [0.8.0] — 2026-09-04

### Added
- **agent 3개(plugin-auditor·audit-refuter·smoke-probe)에 frontmatter
  `input_slots:` 선언 — L3(adjudication-topology Task 14).** 셋 다 dispatch 가
  `audit-workflow.js`/`smoke-workflow.js` 의 `agent(prompt, {agentType})` JS
  호출이라 `shared/tests/test_agent_input_slots.sh` 의 `.md`-only dispatch
  코퍼스(`subagent_type: "..."` 펜스 스캔)가 이 dispatch 자리 자체를 구조적으로
  못 본다 — 그래서 슬롯 전부 `optional: true` (미전달이 아니라 관찰 불가라는
  뜻, 각 파일에 주석으로 남김). `audit-refuter` 의 `findings` 는 `plugin-auditor`
  의 raw 감사 findings 를 반박하는 것 자체가 과업이라 `kind: prior_verdict` +
  `tools/adjudication/check_slots.py` 의 기존 `EXEMPT_SLOTS` placeholder(C6(1))를
  실제 태그명으로 채워 사용.

## [0.7.3] — 2026-09-04

### Fixed
- **`shared/tests/test_runner_disposition.sh`(codex 러너 처분 락)가 `consumer=`
  값의 참·거짓을 재지 못했다 — Task 13 수정 라운드 1이 이 플러그인 몫 러너에서
  실제로 그 구멍에 빠졌던 자리(adjudication-topology Task 13 수정 라운드 2).**
  `shared/tests/`에 있어 플러그인 자체는 아니지만 이 락의 코퍼스(`guards:
  plugins/*/scripts/*codex*.sh`)에 이 플러그인의 `run_audit_codex_reviewer.sh`가
  있어 함께 bump — 상세는 `shared/tests/test_runner_disposition.sh` 수정 내용
  참조(quality-gates·spec-distill CHANGELOG에도 같은 설명이 반복 기록됨, 셋 다
  이 락의 코퍼스에 러너가 있다).

## [0.7.2] — 2026-09-04

### Fixed
- **v0.7.1 이 낸 `consumer=orchestrator` 선언이 거짓이었다 — 리뷰가 Critical 로 잡았다
  (Task 13 수정 라운드 1).** `run_audit_codex_reviewer.sh` 의 산출물(`$CODEX_JSON`)을
  같은 플러그인의 `.py` 가 **직접 여는** 자리가 실재했다:
  `assemble-audit-data.py:233` 의 `load(a.codex_side)`(= `Path(p).read_text()`)가 그
  경로를 직접 read 한다 — `codex_audit_to_json.py` 자기 docstring("소비자가 둘이다 …
  나머지 셋은 `assemble-audit-data.py --codex-side`로 간다")과
  `auditing-plugins/SKILL.md:137` 표가 이미 이 사실을 적어 두고 있었는데, v0.7.1 이
  그 인용 바로 옆에서 반대 결론(`orchestrator`)을 냈다. `consumer=` 를
  `plugins/plugin-audit/scripts/assemble-audit-data.py` 로 교정 — 다른 채널
  (`findings` → `audit-workflow.js`, 오케스트레이터가 파싱해 넘길 뿐 파일을 직접
  열지 않는 쪽)은 앵커 산문에 부기만 한다(형제 `run_brief_codex_reviewer.sh` 가
  두 축을 같은 방식으로 처리한 선례). `fail-open`/`disclosure=meta.codex` 는
  리뷰가 독립 확인해 무변경 — `emit_degrade()` 가 실패 시에도 빈 컬렉션의 유효
  JSON 을 쓰므로 `assemble-audit-data.py` 의 `--codex-side` 가 그것을 읽어도
  하류가 막히지 않는다. `shared/tests/test_runner_disposition.sh` 는 이 경로의
  참·거짓을 구조적으로 재지 못해(존재+동일-플러그인만 검사) v0.7.1 도 GREEN 이었다
  — 락이 못 잡는 부류였고, 사람 리뷰가 코드 인용 셋으로 잡았다.

## [0.7.1] — 2026-09-04

### Fixed
- **`scripts/run_audit_codex_reviewer.sh` 가 자기 처분(누가 산출물을 읽는가·죽었을 때
  막는가 공시하는가·어느 채널로 드러나는가)을 밝히지 않고 있었다 — `shared/tests/test_runner_disposition.sh`
  (adjudication-topology Task 13) 가 26 단언 중 24 를 RED 로 잡았다.** 여섯 codex 러너 중
  이 플러그인 몫 하나에 `**처분**` 앵커를 추가: `consumer=orchestrator`(산출물
  `$CODEX_JSON` 을 `auditing-plugins/SKILL.md` 를 실행하는 오케스트레이터가 직접 읽어
  `findings` 는 `audit-workflow.js` 의 `codexFindings` 인자로, `d_verdicts`/`oq_answers`/
  `new_open_questions` 는 `assemble-audit-data.py` 의 `--codex-side` 로 나눠 넘긴다 — 두
  스크립트 중 어느 쪽도 이 파일을 직접 열지 않는다) · `fail-open`(codex 가 죽어도 나머지
  5축 감사(auditor+refuter)는 계속되고 `meta.codex.ran=false` + stderr 배너로만 공시된다
  — 이 축의 주 판정자가 아니라 모델 다양성 보조다) · `disclosure=meta.codex`.

## [0.7.0] — 2026-09-03

### Added

- **축 3(enforcement 능력)이 「지시가 수신자에게 도달하는가」를 묻는다.** 그 축은
  *"대상의 hook 이 무엇을 막는가"* 는 묻지만 도달은 안 물었다. 두 질문을 더한다 —
  ⑴ 모델에게 하는 지시가 모델이 실제로 읽는 채널로 나가는가(`systemMessage` 는
  사람 채널이다) ⑵ 한 산출물이 다음에 넘기는 값에 도착 확인 자리가 있는가.
  **축을 만들지 않는다** — `AXES` 원소는 6 그대로이고 기존 항목도 지우지 않는다.

### Known gaps

- 이 질문은 사용자가 `/plugin-audit` 을 실행할 때만 발화한다. 감사 없이 새 자리가
  생기면 여전히 안 묻는다. 상시 발화하는 자리(`CLAUDE.md`)는 상시 로드 표면을 늘려
  기각했다.

## [0.6.4] — 2026-08-25

### Added
- `tests/audit-workflow.test.mjs` — 결함 #9 의 **대칭 절반**(축 갈래) 회귀 테스트 2건.
  `[0.6.3]` 이 codex 갈래만 잠갔고, 그 테스트의 주석이 스스로 *"한쪽만 잠그면 정확히
  같은 방식으로 재발한다"* 고 적었는데 축 갈래(`scripts/audit-workflow.js:558`)의
  `degradedEvents.push` 를 지워도 스위트가 전건 GREEN 이었다(실측). 단언은 축 수를
  리터럴로 박지 않고 **「미검증 finding 마다 정확히 하나의 공시」** 라는 도출 관계로
  건다. 양성 짝(축 refuter 가 판정하면 공시 없음) 포함.

## [0.6.3] — 2026-08-25

### Added
- `tests/audit-workflow.test.mjs` — `[0.6.1]` 수리의 회귀 테스트 2건. 그 수리가 들어간 뒤에도
  스위트 어디에도 `degradedEvents` 문자열이 없어서, codex 갈래의 `push` 를 지워도 전부 GREEN
  이었다. 원 결함이 「구조가 같은 두 갈래 중 하나만 침묵」이었으므로 계측기 없이는 같은
  방식으로 재발한다. 판정 누락 시 공시가 쌓이는지 + 판정이 있으면 안 쌓이는지(양성 짝).

## [0.6.2] — 2026-08-23

### Added
- dispatch 자리(3곳)에 처분 앵커 — `**처분** — consumer=… · fail-… [· disclosure=…]`. `shared/tests/test_dispatch_disposition.sh` 축 A①②③④·B·C 가 집행한다.

## [0.6.1] — 2026-08-23

### Fixed
- `scripts/audit-workflow.js`: codex 갈래가 `rec.unverified = true`를 세우면서 `degradedEvent`를
  push하지 않아, refuter가 판정을 누락한 codex finding이 배너 없이 통과하던 것. 구조가 같은
  Claude 갈래(axis 결과 병합 루프의 `else if (!v)` 분기)는 이미 `degradedEvents.push(...)`를
  하고 있었다 — codex 병합 루프의 대칭 분기만 침묵이었다. 같은 push 구조로 맞췄다.
