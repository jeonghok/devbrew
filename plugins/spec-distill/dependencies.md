---
type: devbrew-dependencies
plugin: spec-distill
---

# spec-distill 의존

최소 판은 이 플러그인 판을 개발 · 검증할 때 깔려 있던 판이다. 판 칸(`최소 판` · `잰 날짜`)은 플러그인 폴더에서 `python3 scripts/check_deps.py measure --plugin-root . --superpowers-base "<불러온 superpowers skill 의 기준 폴더>"` 가 쓴다 — 손으로 고치지 않는다.

강도: 멈춤 = 없거나 낮으면 멈춘다 · 알림 = 알리고 진행한다 · 기록 = 판을 적어 두기만 한다.

| 이름 | 최소 판 | 잰 날짜 | 강도 | 없을 때 |
|---|---|---|---|---|
| python | 3.9.6 | 2026-11-24 | 멈춤 | 진입에서 멈추고 Python 3 을 설치하거나 업데이트하라고 보인다 |
| git | 2.54.0 | 2026-11-24 | 멈춤 | 진입에서 멈추고 git 을 설치하거나 업데이트하라고 보인다 |
| gh | 2.88.1 | 2026-11-24 | 멈춤 | gh 를 쓰는 진입(지휘자 · 분해 뒤 로드맵 흐름)에서 멈추고 gh 설치 방법을 보인다. 인증은 첫 gh 호출이 실패할 때 `gh auth login` 을 보이고 멈춘다. 로드맵 잡기 끝맺음의 PR 열기 · 머지는 멈추지 않고 건너뛴 뒤 직접 PR 을 열어 머지하라고 알린다 |
| superpowers | 7.0.0 | 2026-10-22 | 알림 | 없으면 컨텍스트 쌓기는 brief 까지 만들고 끝 질문으로 확정 · 커밋한 뒤 다음 단계로 넘기지 않고 끝내며, 지휘자 · 로드맵 흐름은 진입에서 멈춘다 |
| quality-gates | 17.0.0 | 2026-11-24 | 알림 | 지휘자의 품질 게이트 자리 넷(spec 승인 앞 · 머지 앞 · 로드맵 끝 · 이름으로 청한 리뷰)이 자리마다 「품질 게이트 없이 간다」를 알리고 진행한다 |
| claude-code | 2.1.330 | 2026-11-24 | 기록 | 잰 판을 기록만 한다 |

## 세션 기록

team 형식 로드맵의 사람 줄(`references/team-files.md` §2)은 Claude Code 가 쓰는 세션 기록 파일에 기댄다. 읽기만 하고 대화 내용은 옮기지 않는다 — 칸 이름과 고정 낱말뿐이다. 이 절의 칸은 표의 판 칸과 달리 `check_deps.py` 가 재지 않는다.

- 기대는 칸 — 항목의 종류 · 주 대화 여부(`isSidechain`) · 질문 창 도구(`AskUserQuestion`)의 호출과 그 결과를 잇는 칸(`sourceToolAssistantUUID`) · 결과의 `toolUseResult`(질문 글 · 고른 답) · 답 항목의 `permissionDecision`(`decision` · `source`) · 세션을 띄운 방식 `entrypoint` · 줄에 적을 날짜를 정하는 `timestamp`.
- 확인한 판 — Claude Code 2.1.296 – 2.1.327.
- 사람 답의 조건 셋 — `decision` 이 `accept` · `source` 가 `user_temporary` · `entrypoint` 가 `cli`. 사람이 아니라고 잰 값 둘 — `source` 가 `hook`(훅이 채운 답) · `entrypoint` 가 `sdk-cli`(프로그램이 권한 질문에 대신 답한 세션). 두 목록 어디에도 없는 값이나 없는 칸은 「확인 못 함」 이다.
- 이 칸들은 Claude Code 의 문서에 없고 판에 따라 바뀔 수 있다. 바뀌면 판정이 「확인 못 함」 이 되고 지나가는 자리에서 멈춘다 — 여는 길은 레포 설정 `human_gate: 끔` 이다.
- 재지 못한 것 — ① 대화형 세션에서 훅이 답을 채우면 `source: hook` 으로 남는지(프로그램이 대신 답하는 세션에서만 봤다) ② 터미널이 아닌 화면의 `entrypoint` 값(허용 목록에 없어 「확인 못 함」 으로 닫힌다) ③ 다른 세션이나 프로그램이 리더의 터미널에 글쇠를 넣어 고른 답(기록에서 사람 답과 갈리지 않는다).

## 권장 도구

herdr-core(`hc`) — 권장. 있으면 지휘자가 계획 · 구현 담당자를 따로 띄운 세션으로 돌린다. 없을 때는 하위 agent 길 그대로 돈다. 본 판은 hc 0.1.21(2026-11-22)이다. 이 절은 표가 아니고 `check_deps.py` 가 판을 재지 않는다.
