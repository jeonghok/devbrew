# Changelog

## [0.6.1] — 2026-08-23

### Fixed
- `scripts/audit-workflow.js`: codex 갈래가 `rec.unverified = true`를 세우면서 `degradedEvent`를
  push하지 않아, refuter가 판정을 누락한 codex finding이 배너 없이 통과하던 것. 구조가 같은
  Claude 갈래(axis 결과 병합 루프의 `else if (!v)` 분기)는 이미 `degradedEvents.push(...)`를
  하고 있었다 — codex 병합 루프의 대칭 분기만 침묵이었다. 같은 push 구조로 맞췄다.
