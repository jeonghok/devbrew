# Changelog

## [0.1.0] — 2026-08-08

### Added
- `output-styles/agent-transparency.md` — 일곱 순간에 무엇을 담아야 하는지 규정하고 내장 `Explanatory` 스타일을 흡수한다(`force-for-plugin: true`).
- `hooks/subagent-explain.py` — `SubagentStop` 훅. 에이전트가 끝난 직후 설명 자리를 만든다(검사·차단 없음, kill switch 2종).
- `/standup` (`commands/standup.md` · `skills/briefing-current-state/` · `agents/transcript-reader.md` · `scripts/prepare_standup.py`) — 트랜스크립트에 쌓인 설명과 git 산출물로 "지금 상태"에 답한다.
- 머지 게이트(AC29, `tests/ab_gate.sh` + `tests/ab_judge.py`) — 워커 24회 + `/standup` 3회 + 판정 36회, 일곱 게이트 전부 통과해야 머지 가능.
- AC1–AC51 (삭제된 AC12–15·17–19·21–24·30 제외, 원 38건 + AC51 신설) 전량을 `tests/*.py` 여섯 파일과 `tests/oracle/`이 검증한다.
