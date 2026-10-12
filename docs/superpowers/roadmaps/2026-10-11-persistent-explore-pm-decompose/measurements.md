# 실측 — R0

설계문서에는 결과를 적지 않는다. 결과가 바꾸는 에픽은 표의 마지막 칸이다. 측정: 2026-10-11 · Claude Code 2.1.296 · superpowers 6.4.1.

| # | 묻는 것 | 결과(한 줄) | 바꾸는 것 |
|---|---|---|---|
| M1 | 백그라운드 subagent(worktree 격리)에서 brainstorming 이 사용자에게 물을 수 있는가 · SDD 가 자기 subagent 를 부르며 끝까지 가는가 | 묻지 못한다(AskUserQuestion 이 subagent 에 없음 — 가설대로). SDD 는 subagent 안에서 구현 · 리뷰 subagent 셋을 부르며 끝까지 가고, 사람에게 묻는 자리(머지 메뉴)에서만 멈춘다. 다만 사람에게 물을 질문 하나(main 에서 시작해도 되는지)는 백그라운드 SDD 가 스스로 판정했다 — 브랜치를 제 마음대로 만들었다. 지휘 절차 2 가 에픽 브랜치와 worktree 를 먼저 만들어 이를 피한다 | R5(OQ30) |
| M2 | 지휘 세션의 작업 목록이 /compact · /new 뒤와 백그라운드 작업 중에 남고 보이는가 | 백그라운드 작업 중에도, /compact 뒤에도 남고 보인다(압축 전 작업 둘이 번호 · 상태 그대로). /new 뒤에는 남지 않는다(새 세션의 목록이 비어 있다) | R6(OQ34) |
| M3 | 플러그인이 상태줄을 제공할 수 있는가, 사용자 설정뿐인가 | 사용자 · 프로젝트 설정뿐이다 — 플러그인 설정은 `agent` · `subagentStatusLine` 두 키만 적용된다. 상태줄 입력에 작업 목록 필드가 없다 (문서 확인 — 격리 설치는 하지 않음) | R6(OQ34) |
| M4 | 에픽 하나를 거치며 superpowers 가 사용자를 기다린 자리 | 계획까지 아홉 자리 — brainstorming 여덟(이해 확인 1 · 명확화 질문 3 · 접근 선택 1 · 설계 절 승인 3)과 writing-plans 끝의 계획 검토 + 실행 방식 하나. 설계문서 검토 자리는 devbrew 에서 spec-review 가 대신해 superpowers 몫으로 세지 않았다. 구현 · 머지 메뉴 자리는 이 표를 쓴 뒤라 아래 절에 이어 적는다 | D37 확인 · R5 |
| M5 | 지휘 세션이 brainstorming → spec-review → 승인 → writing-plans 를 이어 부른 뒤 지휘 절차로 돌아오는가 | 돌아왔다 — 다만 skill 이 데려다준 것이 아니라 지휘 세션이 로드맵을 다시 읽고 돌아왔다. writing-plans 는 계획 검토 + 실행 방식 질문으로 끝나고 브랜치 커밋 · 상태 계산 · 작업 목록 갱신을 말하지 않는다. 지휘 세션이 그 질문 전에 절차 1 · 2 를 했다(계획 커밋 → fetch → `roadmap_status.py` 「계획」 → 작업 제목 갱신) | R5(OQ30) |

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
- /compact 뒤(사용자가 /compact 를 친 직후 첫 도구 호출) TaskList 원 출력:
  ```
  #7 [pending] M2 확인 A
  #8 [pending] M2 확인 B
  ```
  압축 전 작업 둘이 번호 · 상태 그대로 남았다. 그러므로 위 관찰의 #1~#6 부재는 압축이 지운 것이 아니다.
- /new 뒤(새 세션의 첫 도구 호출) TaskList 원 출력:
  ```
  No tasks found
  ```
  작업 목록은 세션을 넘지 않는다 — /new 뒤 새 세션에는 이전 작업이 하나도 없다.

판정: 작업 목록은 한 세션 안에서만 산다 — 백그라운드 작업 중에도, /compact 뒤에도 남지만 /new 뒤 새 세션에는 없다. R6 은 작업 목록을 세션을 넘는 진행 상태의 저장소로 쓰지 않는다. 세션을 넘는 진행 상태는 git 에서 계산한 `roadmap_status.py` 출력에서 읽고, 작업 목록은 한 세션 안의 표시로만 쓴다. 남은 것 둘: 이 세션 기록에 남은 명령은 `/clear` 였다 — /new 와 같은 명령으로 보았고 따로 확인하지 않았다. 압축 전 작업 #1~#6 이 목록에서 사라진 까닭은 모른다(압축이 지운 것은 아니다). /compact 측정은 한 번이다.

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

## M4

방법: R1 을 지휘 세션 하나에서 걸으며(2026-10-12 · superpowers 6.4.1) superpowers 가 사용자 답을 받아야 다음으로 가는 자리를 차례로 적었다. 고지만 하고 기다리지 않은 자리는 따로 표시했다.

- 대기 아님: brainstorming 의 분류 고지(architectural) — 사용자가 뒤집을 기회만 준다.
- W1 이해를 써 보이고 정정 받기 — 첫 결정 질문(판정자를 무엇으로 할지)과 한 메시지로 합쳤다.
- W2 · W3 · W4 명확화 질문 셋(root_problem 칸 · 레포 조사 subagent · 20회 계수 대상).
- W5 접근 2–3개 중 고르기.
- W6 · W7 · W8 설계 절 승인 셋.
- 대기 아님(devbrew 가 대신): brainstorming 체크리스트 8 「사용자가 쓴 spec 을 검토」 — spec-review 의 라운드 게이트와 승인 게이트가 그 자리다. 이 걷기에서 spec-review 가 사용자를 기다린 자리는 라운드 게이트 질문 5(1라운드 3 · 2라운드 2), 승인 게이트 1단계 질문 2, 2단계 진행 옵션 1 이었다.
- W9 writing-plans 끝의 계획 검토 + 실행 방식 선택 — 한 질문.
- 이어서 잴 자리: 실행 중(SDD 의 판정 목록은 멈추지 않는다 — 지휘 절차 5) · finishing 의 머지 메뉴.

판정: 설계 단계의 대기는 brainstorming 에 몰려 있다(여덟). writing-plans 는 중간에 묻지 않고 끝에서 한 번 묻는다. W1 처럼 한 메시지에 둘을 합치면 대기 수가 줄지만, 그만큼 사용자가 한 번에 판단할 양이 는다.

## M5

방법: spec-review 승인(진행 옵션 ② — `/compact` 뒤 다음 세션 줄) 뒤 writing-plans 를 부르고, 그것이 끝난 자리에서 지휘 세션이 무엇을 하는지 적었다.

- spec-review 의 ②: 두 줄을 내고 턴을 끝냈다(같은 턴에 writing-plans 를 부르지 않음). 사용자가 `/compact` 와 다음 세션 줄을 입력해 writing-plans 가 시작됐다. 작업 목록은 압축을 넘어 그대로였다(M2 와 같다).
- writing-plans 는 계획을 저장하고 「검토 + 실행 방식」 질문으로 끝내라고만 한다. 계획을 에픽 브랜치에 커밋하라 · 상태를 다시 계산하라 · 작업 목록을 맞추라는 말은 없다.
- 지휘 세션은 그 질문 전에 로드맵의 지휘 절차를 다시 보고 1 · 2 를 했다: 계획 커밋 → `git fetch` → `roadmap_status.py`(R1 「계획 · 계획 있음」, rc 0) → 작업 제목 「R1 인터뷰 탐색 개편 — 계획」. `git fetch` 가 main 의 이동(spec-distill 5.4.0)을 드러내 계획의 Task 0 이 merge 로 시작한다.
- 그 뒤 writing-plans 의 질문을 절차 4 대로 사용자에게 그대로 가져갔다.

판정: 돌아오기는 했지만 장치가 아니라 지휘 세션의 기억(로드맵을 다시 읽는 습관)에 기댔다. 압축 요약이 「writing-plans 뒤 지휘 절차로 돌아오는지 관측」을 할 일로 들고 있었기 때문에 돌아왔을 공산이 크다 — 측정 자체가 결과를 밀었다. R5 지휘자는 writing-plans 끝을 절차의 다음 걸음(커밋 · 상태 계산 · 작업 목록)에 묶는 자리를 가져야 한다.
