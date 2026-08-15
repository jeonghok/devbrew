# Changelog

## [0.1.0] — 2026-08-13

### Added
- `output-styles/agent-transparency.md` — 일곱 순간에 무엇을 담아야 하는지 규정하고 내장 `Explanatory` 스타일을 흡수한다(`force-for-plugin: true`).
- `/standup` (`commands/standup.md` · `skills/briefing-current-state/` · `agents/transcript-reader.md` · `scripts/prepare_standup.py`) — 트랜스크립트에 쌓인 설명과 git 산출물로 "지금 상태"에 답한다.
- 머지 게이트(AC29, `tests/ab_gate.sh` + `tests/ab_judge.py`) — 워커 24회 + `/standup` 3회 + 판정 36회, 일곱 게이트 전부 통과해야 머지 가능.
- AC1–AC51 (삭제된 AC12–15·17–19·21–24·30 과 AC6–AC9·AC36·AC37·AC44·AC50 제외, 총 31건)의 배정은 `REFERENCE.md`의 「AC ↔ 검증 산출물」 표에 못박혀 있다 — 대부분은 `tests/*.py` 다섯 파일과 `tests/ab_gate.sh` · `tests/oracle/` · `tests/ab_judge.py`가 검증하고, AC16②는 비대화형 실행에 답변 채널이 없어 실물로 측정되지 않아 `없음 — OQ-AA`로 등재돼 있다(전량이 아니다 — M6).

### Notes
- **훅을 두지 않는다.** 개발 중(2026-08-13) `SubagentStop` 훅을 설계에서 제거했다 — 라이브
  probe 가 그 `additionalContext` 는 메인 대화가 아니라 **방금 끝난 subagent** 로 배달되고
  그 subagent 를 계속 돌게 만든다는 것을 보였다. 이 버전은 미출시 상태에서 개정됐으므로
  별도 릴리스로 기록하지 않는다 — 훅이 실린 버전은 어떤 사용자에게도 배포된 적이 없다.
  근거 전량은 설계 문서 §11, 사용자용 요약은 `README.md` 의 「훅을 두지 않는다」 절.
- 그래서 **kill switch 가 없다** — 걸 지점이 없다. 끄는 방법은 `claude plugin disable` 뿐이다.
