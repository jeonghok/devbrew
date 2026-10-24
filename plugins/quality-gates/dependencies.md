---
type: devbrew-dependencies
plugin: quality-gates
---

# quality-gates 의존

최소 판은 이 플러그인 판을 개발 · 검증할 때 깔려 있던 판이다. 판 칸(`최소 판` · `잰 날짜`)은 플러그인 폴더에서 `python3 scripts/check_deps.py measure --plugin-root .` 가 쓴다 — 손으로 고치지 않는다. 판을 잴 길이 없는 외부 플러그인 행만 판 칸 둘에 `—` 를 적는다 — `measure` 는 그 행을 「못 쟀다」로 알리고 그대로 둔다.

강도: 멈춤 = 없거나 낮으면 멈춘다 · 알림 = 알리고 진행한다 · 기록 = 판을 적어 두기만 한다.

| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |
|---|---|---|---|---|
| python | 3.9.6 | 2026-10-22 | 멈춤 | 진입에서 멈추고 Python 3 을 설치하거나 업데이트하라고 보인다 |
| git | 2.54.0 | 2026-10-22 | 멈춤 | 진입에서 멈추고 git 을 설치하거나 업데이트하라고 보인다 |
| gh | 2.88.1 | 2026-10-22 | 멈춤 | gh 를 쓰는 진입(quality-pipeline)에서 멈추고 gh 설치 방법을 보인다. 인증은 첫 gh 호출이 실패할 때 `gh auth login` 을 보이고 멈춘다 |
| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |
| pr-review-toolkit | — | — | 기록 | 외부 플러그인이라 판을 재지 못한다 — 없으면 이 리뷰어를 건너뛰고 나머지로 진행한다(README Prerequisites 의 optional 의존) |
