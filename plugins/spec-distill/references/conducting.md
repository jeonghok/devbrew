# 지휘 — 로드맵의 에픽을 끝까지 이끄는 절차

## 지휘 순환

지휘자 skill(`/spec-distill:epic-conductor`)이 불릴 때마다 걸음 1 부터 차례로 돈다. 걸음마다 다섯 칸(기본값 · 판단 · 부를 skill · 기록 · 기계 상태)이고, 기본값과 다르게 하면 무엇을 왜 다르게 했는지 그 에픽 설계문서 `## 지휘 기록` 에 적는다(에픽에 매이지 않은 판단은 다음 로드맵 수정 PR 본문의 `## 지휘 기록` 절에). 설계문서 없이 산출물만 내는 에픽이면 같은 절(지휘 기록 · 판정 · 구현 대조)을 그 산출물 파일에 둔다. 정석 흐름(brainstorming → 계획 → 구현)의 뜻은 지킨다. superpowers 는 부르기만 하고 고치지 않는다.

- `<SD>` 는 spec-distill 플러그인 폴더의 절대경로, `<로드맵>` 은 로드맵 파일의 레포 루트 기준 경로, `<세션>` 은 `python3 "<SD>"/scripts/state_path.py session-id` 의 값이다. `ledger <명령>` 은 `python3 "<SD>"/scripts/conductor_ledger.py <명령>` 을 줄인 것이다. `<설계문서>` 는 그 에픽 worktree 안 설계문서의 절대경로다 — `ledger record` · `ledger write-sections` · `ledger flush` 는 상대경로를 지금 작업 폴더 기준으로 풀어서, 메인 체크아웃에서 부르면 다른 사본을 고친다. 기계 상태 자원 폴더는 `ledger resource-dir --roadmap <로드맵> --kind tmp|relay|report --name <이름>` 이 만들고 경로를 낸다 — 만든 것은 `## 자원` 에 적고, 끝나면 `ledger cleanup` 이 확인 없이 지운다. 「에픽 worktree」 는 그 에픽 브랜치가 지금 서 있는 worktree 다 — 하위 agent 가 자기 격리 worktree 에서 그 브랜치에 섰으면(걸음 3 의 「하위 agent 의 자리」) 그 worktree 다.
- 레포마다 다른 값은 박지 않고 읽는다 — 기본 브랜치는 `origin/HEAD`, 브랜치 이름은 로드맵 블록의 `브랜치:`, 설계문서 · 계획 폴더 · 테스트 명령 · 리뷰 모델(`specs_dir` · `plans_dir` · `test_command` · `review_model`)은 해결자(`repo_defaults.py get`)가 로드맵 · 레포 설정 파일 · 기본값에서 낸다.
- 하위에게 보내는 글은 같은 폴더 `conductor-dispatch.md` 의 틀이다. 각 칸의 주인은 같은 폴더 `roadmap-ontology.md` 에 있다.
- 에픽 PR 번호는 PR 을 열 때(걸음 4)와 쌓인 PR 의 바탕을 기본 브랜치로 바꾼 직후(걸음 5)에만 `ledger pr-record` 로 적는다 — 번호 없는 PR 을 찾아 적는 걸음은 없고, 그 밖의 PR(손으로 연 PR · 이 판 전에 연 PR)은 지휘 세션이 `ledger pr-record --roadmap <로드맵> --session <세션> --epic <에픽> --pr <번호>` 를 한 번 부른다(번호는 숫자만). `ledger pr-refresh` 가 「적은 PR #N 이 <브랜치> 와 맞지 않는다」 경고를 내면 그 줄의 두 명령 가운데 하나를 부른다 — 이 에픽의 PR 이면 다시 적고, 아니면 `--drop` 으로 번호 기록을 지운다.
- 사용자가 에픽이나 로드맵 이름을 대며 리뷰를 청하면 어느 걸음에 있든 품질 게이트 리뷰는 `<SD>/skills/epic-conductor/references/qg-review.md` 를 읽고 그 자리(「이름으로 청함」)의 줄을 따른다.

### 걸음 표

| 걸음 | 들어서는 때 | 지시서 | 함께 읽는 것 |
|---|---|---|---|
| 1 맞추기 | 부를 때마다 | `<SD>/references/conducting-step-1.md` | — |
| 2 사람 몫 모으기 | 사용자를 기다리는 질문이 있을 때 | `<SD>/references/conducting-step-2.md` | — |
| 3 다음 일 고르기와 보내기 | 단계: 준비 · 설계 중 · 일부 머지 | `<SD>/references/conducting-step-3.md` | — |
| 4 돌아오기 | 단계: 계획 · 구현 중 · 구현 끝 · 진행 중 | `<SD>/references/conducting-step-4.md` | — |
| 5 머지 전 확인 | 단계: PR · 결과 받음 | `<SD>/references/conducting-step-5.md` | — |
| 6 머지 뒤 | 에픽 PR 이 머지된 뒤 그 에픽의 줄(작업 · 자원 · 살아 있는 agent)이 기계 상태에 남아 있는 동안 — 단계: 머지됨 · 끝남 | `<SD>/references/conducting-step-6.md` | — |
| 7 끝 | 끝나지 않은 에픽이 없을 때 | `<SD>/references/conducting-step-7.md` | — |

### 걸음에 달리지 않은 지시서

- 승인 뒤 계획 담당자를 보낸 직후 · 담당자를 보낸 뒤처럼 끊기 좋은 자리에서 맥락이 무거울 때 — `<SD>/references/conducting-resume.md`
- 로드맵 머리말이 `layout: team` 일 때만 — `<SD>/references/conducting-team.md`

### 알림
사람 답이 없어 에픽이 멈췄을 때와 모두 끝났거나 더 갈 일이 없을 때만 알림 도구(`PushNotification`)를 보낸다. 알림 도구가 없으면 멈춘 사실을 다음 응답 첫 줄에 쓴다.

## 손으로 따르는 절차

손으로 따르는 절차는 `<SD>/references/conducting-manual.md` 에 있다 — 지휘자를 부르지 않고 진행할 때의 것이고, 지휘자 skill 안에서는 따르지 않는다.
