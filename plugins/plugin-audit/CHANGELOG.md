# Changelog

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
