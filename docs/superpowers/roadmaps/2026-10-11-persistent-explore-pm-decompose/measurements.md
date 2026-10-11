# 실측 — R0

설계문서에는 결과를 적지 않는다. 결과가 바꾸는 에픽은 표의 마지막 칸이다. 측정: 2026-10-11 · Claude Code 2.1.296 · superpowers 6.4.1.

| # | 묻는 것 | 결과(한 줄) | 바꾸는 것 |
|---|---|---|---|
| M1 | 백그라운드 subagent(worktree 격리)에서 brainstorming 이 사용자에게 물을 수 있는가 · SDD 가 자기 subagent 를 부르며 끝까지 가는가 | 묻지 못한다(AskUserQuestion 이 subagent 에 없음 — 가설대로). SDD 는 subagent 안에서 구현 · 리뷰 subagent 셋을 부르며 끝까지 가고, 사람에게 묻는 자리(머지 메뉴)에서만 멈춘다. 다만 사람에게 물을 질문 하나(main 에서 시작해도 되는지)는 백그라운드 SDD 가 스스로 판정했다 — 브랜치를 제 마음대로 만들었다. 지휘 절차 2 가 에픽 브랜치와 worktree 를 먼저 만들어 이를 피한다 | R5(OQ30) |
| M2 | 지휘 세션의 작업 목록이 /compact · /new 뒤와 백그라운드 작업 중에 남고 보이는가 | 백그라운드 작업 중에는 보인다. /compact · /new 뒤는 아래 절 | R6(OQ34) |
| M3 | 플러그인이 상태줄을 제공할 수 있는가, 사용자 설정뿐인가 | 사용자 · 프로젝트 설정뿐이다 — 플러그인 설정은 `agent` · `subagentStatusLine` 두 키만 적용된다. 상태줄 입력에 작업 목록 필드가 없다 (문서 확인 — 격리 설치는 하지 않음) | R6(OQ34) |
| M4 | 에픽 하나를 거치며 superpowers 가 사용자를 기다린 자리 | R1 걷기에서 | D37 확인 · R5 |
| M5 | 지휘 세션이 brainstorming → spec-review → 승인 → writing-plans 를 이어 부른 뒤 지휘 절차로 돌아오는가 | R1 걷기에서 | R5(OQ30) |

## M1

방법: devbrew 밖의 버릴 레포(`~/.claude/sdd-mirror/r0-m1/toy`, 장난감 계획 2 Task)에서 지휘 세션이 subagent 둘을 띄웠다 — (a) `isolation: "worktree"` 백그라운드 subagent 가 `superpowers:brainstorming` 을 불러 첫 질문을 시도, (b) 백그라운드 subagent 가 `superpowers:subagent-driven-development` 를 장난감 계획으로 돌림.

(a) 원 출력 요지:
- AskUserQuestion: 처음 도구 목록 · 지연 로드 목록 어디에도 없음. `ToolSearch "select:AskUserQuestion"` → "No matching deferred tools found".
- brainstorming 은 목적 질문 하나(「이 인사 파일은 무엇을 위한 것인가요?」, 선택지 셋)를 하려 했다. skill 의 지시는 대화 메시지로 묻는 것이고, subagent 의 글은 사람에게 가지 않는다(결과는 hand-back 하나로만 나가고 그 호출이 실행을 끝낸다).
- AskUserQuestion 직접 호출 결과(원문): `Error: No such tool available: AskUserQuestion. AskUserQuestion is not available inside subagents. Complete the task with the tools provided and return findings to the orchestrator.`
- 멈춘 곳: brainstorming 체크리스트 3단계 첫 질문.

(b) 원 출력 요지:
- Agent 도구 있음 · 동작. AskUserQuestion 없음.
- SDD 가 2 Task 를 구현자 하나(haiku)에 묶어 보냄 → 커밋 둘 → Task 리뷰어(sonnet) 승인 → 최종 리뷰어(opus) "Ready to merge? Yes" → finishing-a-development-branch Step 4 머지 메뉴에서 멈춤. subagent 셋 모두 돌아옴, 수정 라운드 0.
- 사람에게 물어야 했던 자리 둘: SDD 착수 때 main 에서 시작해도 되는지(물을 수 없어 subagent 가 스스로 브랜치를 만들기로 판정), finishing 의 머지 메뉴(물을 수 없어 멈춤 — 브랜치 미머지 · 미푸시).
- 부작용: subagent 가 SDD 작업 폴더 스크립트를 처음에 지휘 세션의 워크트리에서 돌려 그 레포의 git-ignored 자리에 폴더를 만들었다가 지웠다. 지휘 세션의 원장은 무사했다. 지휘 세션의 워크트리 Bash 가드가 subagent 의 git 명령에도 걸렸다(복합 명령 거부, `git -C <경로>` 는 통과).

판정: 설계 단계(사용자에게 묻는 brainstorming · spec 승인)는 지휘 세션에서 한 에픽씩 해야 한다. 구현(SDD)은 백그라운드 subagent 에서 끝까지 갈 수 있고, 머지 메뉴는 지휘 세션이 사용자에게 가져와야 한다. 백그라운드 SDD 는 사람에게 물을 질문(main 에서 시작해도 되는지)도 스스로 판정해 브랜치를 만들었다 — 지휘 절차 2 가 에픽 브랜치와 worktree 를 먼저 만들어 이 판정이 필요 없게 한다. subagent 에는 작업 디렉토리를 절대경로로 못 박는다.

## M2

- 만든 직후 · 백그라운드 작업 중(측정 subagent 셋과 구현 subagent 하나가 도는 동안) TaskList 원 출력:
  ```
  #7 [pending] M2 확인 A
  #8 [pending] M2 확인 B
  ```
- 덧붙인 관찰: 이 지휘 세션은 이미 /compact 를 한 번 거쳤다. 압축 전에 만든 작업(#1~#6, 그중 #6 은 completed)은 목록에 없고, 새 번호는 #7 부터 이어졌다. 압축 뒤 이전 작업이 사라졌는지, 끝난 작업이 감춰지는지는 이 관찰만으로 가르지 못한다.
- /compact 뒤: 사용자가 /compact 를 친 뒤 적는다.
- /new 뒤: 사용자가 /new 를 친 뒤 새 세션이 적는다.

## M3

방법: 공식 문서 확인(claude-code-guide). 출처는 Claude Code 공식 문서의 statusline · plugins components · plugin manifest reference · hooks · settings reference 페이지다.

- 플러그인 기본 설정(plugin `settings.json` · manifest `settings`)은 두 키만 적용한다. 원문: "Two keys take effect, `agent` and `subagentStatusLine`, and every other key is dropped." manifest reference 도 같다: "Only `agent` and `subagentStatusLine` take effect; other keys are dropped at load."
- 메인 `statusLine` 은 사용자 · 프로젝트(· local · managed) 설정에 둔다. 원문: "Add a `statusLine` field to your user settings (`~/.claude/settings.json` …) or [project settings]."
- 플러그인이 줄 수 있는 가장 가까운 것은 `subagentStatusLine` 이다(subagent 작업 행만 다시 씀).
- statusLine 명령의 입력(stdin)에 작업 목록 · todo 필드는 문서에 없다(model · cwd · workspace · cost · context_window · rate_limits · session_id 등). `tasks[]` 는 subagentStatusLine 입력에만 있고 subagent 행 정보다.
- 훅: TaskCreated · TaskCompleted 이벤트가 있다(exit 2 로 차단 가능). 이 두 이벤트에서 화면에 글을 띄우는 길은 문서로 확인되지 않는다 — `systemMessage` 가 보이는지 문서가 말하지 않고, `additionalContext` 는 모델에게만 간다.
- 확신: 플러그인이 메인 statusLine 을 못 준다 — 높음(두 키 허용 목록 원문). 훅이 화면에 글을 못 띄운다 — 중상(hooks 페이지는 요약 경유로 읽음).
- 격리 설치 실측: 하지 않음 — 문서가 허용 키를 명시해 확인할 모호함이 없다.
- 확인 못 함: TaskCreated · TaskCompleted 훅의 `systemMessage` 화면 표시 — R6 이 착수 때 버릴 플러그인으로 잰다.

## M4 — R1 걷기에서

## M5 — R1 걷기에서
