# Changelog

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
