---
type: devbrew-dependencies
plugin: project-init
---

# project-init 의존

최소 판은 이 플러그인 판을 개발 · 검증할 때 깔려 있던 판이다. 판 칸(`최소 판` · `잰 날짜`)은 플러그인 폴더에서 `python3 scripts/check_deps.py measure --plugin-root .` 가 쓴다 — 손으로 고치지 않는다.

강도: 멈춤 = 없거나 낮으면 멈춘다 · 알림 = 알리고 진행한다 · 기록 = 판을 적어 두기만 한다. `python-hook` 의 멈춤은 진입이 아니라 훅이 멈춘다는 뜻이다 — 훅은 작업을 막지 않고 자기만 건너뛴다.

| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |
|---|---|---|---|---|
| python | 3.9.6 | 2026-10-22 | 멈춤 | 진입에서 멈추고 Python 3 을 설치하거나 업데이트하라고 보인다 |
| python-hook | 3.12.13 | 2026-10-22 | 멈춤 | 바닥 미만이면 훅이 돌지 않고 알림 없이 건너뛴다 — README Prerequisites 의 Python 줄 |
| claude-code | 2.1.303 | 2026-10-22 | 기록 | 잰 판을 기록만 한다 |
