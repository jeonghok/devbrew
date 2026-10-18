# 실측 — R0

설계문서에는 결과를 적지 않는다. 결과가 바꾸는 에픽은 표의 마지막 칸이다. 측정: 2026-10-11 · Claude Code 2.1.296 · superpowers 6.4.1. M6~M9: 2026-10-18 · Claude Code 2.1.302.

| # | 묻는 것 | 결과(한 줄) | 바꾸는 것 |
|---|---|---|---|
| M1 | 백그라운드 subagent(worktree 격리)에서 brainstorming 이 사용자에게 물을 수 있는가 · SDD 가 자기 subagent 를 부르며 끝까지 가는가 | 묻지 못한다(AskUserQuestion 이 subagent 에 없음 — 가설대로). SDD 는 subagent 안에서 구현 · 리뷰 subagent 셋을 부르며 끝까지 가고, 사람에게 묻는 자리(머지 메뉴)에서만 멈춘다. 다만 사람에게 물을 질문 하나(main 에서 시작해도 되는지)는 백그라운드 SDD 가 스스로 판정했다 — 브랜치를 제 마음대로 만들었다. 지휘 절차 2 가 에픽 브랜치와 worktree 를 먼저 만들어 이를 피한다 | R5(OQ30) |
| M2 | 지휘 세션의 작업 목록이 /compact · /new 뒤와 백그라운드 작업 중에 남고 보이는가 | 백그라운드 작업 중에도, /compact 뒤에도 남고 보인다(압축 전 작업 둘이 번호 · 상태 그대로). /new 뒤에는 남지 않는다(새 세션의 목록이 비어 있다) | R6(OQ34) |
| M3 | 플러그인이 상태줄을 제공할 수 있는가, 사용자 설정뿐인가 | 사용자 · 프로젝트 설정뿐이다 — 플러그인 설정은 `agent` · `subagentStatusLine` 두 키만 적용된다. 상태줄 입력에 작업 목록 필드가 없다 (문서 확인 — 격리 설치는 하지 않음) | R6(OQ34) |
| M4 | 에픽 하나를 거치며 superpowers 가 사용자를 기다린 자리 | 열 자리 — brainstorming 여덟(이해 확인 1 · 명확화 질문 3 · 접근 선택 1 · 설계 절 승인 3) · writing-plans 끝의 계획 검토 + 실행 방식 하나 · finishing 의 머지 메뉴 하나. 구현(SDD) 중에는 0 — 결정은 판정 목록으로 끝에 보였다. 설계문서 검토 자리는 devbrew 에서 spec-review 가 대신해 superpowers 몫으로 세지 않았다 | D37 확인 · R5 |
| M5 | 지휘 세션이 brainstorming → spec-review → 승인 → writing-plans 를 이어 부른 뒤 지휘 절차로 돌아오는가 | 돌아왔다 — 다만 skill 이 데려다준 것이 아니라 지휘 세션이 로드맵을 다시 읽고 돌아왔다. writing-plans 는 계획 검토 + 실행 방식 질문으로 끝나고 브랜치 커밋 · 상태 계산 · 작업 목록 갱신을 말하지 않는다. 지휘 세션이 그 질문 전에 절차 1 · 2 를 했다(계획 커밋 → fetch → `roadmap_status.py` 「계획」 → 작업 제목 갱신) | R5(OQ30) |
| M6 | 지휘 세션이 다른 worktree 로 옮겨 가 쓰고 돌아올 수 있는가 · 옮겨 간 뒤 진입 사전 검사의 `root=` · 하니스 폴더 밖 worktree | 하니스 worktree 폴더 아래로 `EnterWorktree(path=…)` 옮겨 가기 · 돌아오기 · git · 쓰기 됨, 옮긴 자리의 spec-review 사전 검사 `root=` 가 그 worktree(2026-10-18 지휘 세션 실측). 폴더 밖은 닿지 않고, 옮긴 뒤 앞 worktree 는 읽기 전용, worktree 안에서는 `EnterWorktree(name=…)` 로 새로 못 만든다 | R5 계획 3(conducting.md 걸음 3 의 옮겨 가는 길) |
| M7 | 알림 도구가 있는가 · 보고 있을 때 안 보낸다고 하는가 · 끝난 agent 를 `SendMessage` 로 이어 부르면 맥락이 이어지는가 | `PushNotification` 은 이 측정 자리(지휘 세션이 보낸 SDD 실행 agent)의 도구 목록에 없다 — 「보고 있을 때 안 보낸다」 문면은 재지 못함(도구 없음), 지휘 세션 본체는 재지 못함. 끝난 agent 를 `SendMessage` 로 이어 부르면 앞 맥락을 갖고 이어 간다(숫자 7 을 답함) | R5 계획 3(conducting.md 알림 · conductor-dispatch.md 이어 부르기) |
| M8 | `shared/test-selection` 공유본의 배정 · 단위 실행 · 귀속 입출력, 단위 실행의 표준 오류에 실패 이름이 실리는가 | 실린다 — `run … per-unit` 의 표준 오류에 pytest `FAILED tests/test_x.py::test_a` · unittest `FAIL: test_a (tests.test_y.T)` · 셸 `  ✗ 하나가 틀렸다` 가 그대로 나오고 rc 는 0. 테스트 아닌 파일은 `unclaimed` 행. `run` 이 detached 트리를 요구한다는 것은 소스 확인뿐이다(붙은 트리는 재지 못함). `diff-test-results.py` 는 대상 레포 루트에서 불러야 하고 `adapters` · `verdict_input` · `per_adapter` · `attributions` 를 내며, `unclaimed` 가 남아 있으면 `silent_drop: true` · `degrade_causes` 에 `silent-drop` 이 붙는다(pytest · unittest 관측, 셸은 false). `--total --tree HEAD` 는 테스트 파일 수(1)를 낸다 | R5 계획 3 Task 3(merge_check) |
| M9 | `requesting-code-review` 가 부르는 agent 와 그 쓰기 권한 | ``Dispatch a `general-purpose` subagent`` — general-purpose 는 전체 도구(쓰기 포함)를 가진다 | R5 계획 3 결정 D(integration-reviewer) |
| M10 | devbrew 에서 손 헬퍼(실패 이름 스크립트)와 merge_check 의 스위트 명령이 같은 브랜치에서 같은 새 실패 · 고쳐짐 집합을 내는가 | 새 실패 집합은 같다(5줄, 끝 공백만 다름). 고쳐짐 집합은 1줄 다르다 — 스위트 명령 쪽 기준선 실행에서 한 번 빨갰던 `test_codex_backward_compat.sh` 가 혼자 두 번 돌리면 통과(원인은 재지 못함). 범위는 `✗` · unittest 줄, 이후 `run-all.sh` 가 바뀜 | R5 계획 3 Task 13 · 설계 Deferred 2e6610eb#r2.1 |

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
- 구현(subagent-driven-development, 11 Task): Task 사이에 사용자를 기다린 자리는 0 이었다. 계획 결함 · 구현자의 이탈 · 회귀는 전부 지휘 세션이 원장의 판정(Ruling)으로 정하고 이어 갔다 — 판정 20건을 끝에 한 목록으로 보였다(지휘 절차 5).
- W10 finishing 의 머지 메뉴(로컬 머지 · PR · 그대로) — 한 질문.

판정: 에픽 하나에 superpowers 가 기다린 자리는 열이다. 설계 단계의 대기는 brainstorming 에 몰려 있다(여덟). writing-plans 는 중간에 묻지 않고 끝에서 한 번 묻는다. 구현은 끝의 머지 메뉴 하나뿐이고, 그 사이의 결정은 사람이 아니라 판정 목록으로 넘어온다 — 사람이 그것을 읽을 자리는 머지 메뉴 앞뿐이다. W1 처럼 한 메시지에 둘을 합치면 대기 수가 줄지만, 그만큼 사용자가 한 번에 판단할 양이 는다.

## M5

방법: spec-review 승인(진행 옵션 ② — `/compact` 뒤 다음 세션 줄) 뒤 writing-plans 를 부르고, 그것이 끝난 자리에서 지휘 세션이 무엇을 하는지 적었다.

- spec-review 의 ②: 두 줄을 내고 턴을 끝냈다(같은 턴에 writing-plans 를 부르지 않음). 사용자가 `/compact` 와 다음 세션 줄을 입력해 writing-plans 가 시작됐다. 작업 목록은 압축을 넘어 그대로였다(M2 와 같다).
- writing-plans 는 계획을 저장하고 「검토 + 실행 방식」 질문으로 끝내라고만 한다. 계획을 에픽 브랜치에 커밋하라 · 상태를 다시 계산하라 · 작업 목록을 맞추라는 말은 없다.
- 지휘 세션은 그 질문 전에 로드맵의 지휘 절차를 다시 보고 1 · 2 를 했다: 계획 커밋 → `git fetch` → `roadmap_status.py`(R1 「계획 · 계획 있음」, rc 0) → 작업 제목 「R1 인터뷰 탐색 개편 — 계획」. `git fetch` 가 main 의 이동(spec-distill 5.4.0)을 드러내 계획의 Task 0 이 merge 로 시작한다.
- 그 뒤 writing-plans 의 질문을 절차 4 대로 사용자에게 그대로 가져갔다.

판정: 돌아오기는 했지만 장치가 아니라 지휘 세션의 기억(로드맵을 다시 읽는 습관)에 기댔다. 압축 요약이 「writing-plans 뒤 지휘 절차로 돌아오는지 관측」을 할 일로 들고 있었기 때문에 돌아왔을 공산이 크다 — 측정 자체가 결과를 밀었다. R5 지휘자는 writing-plans 끝을 절차의 다음 걸음(커밋 · 상태 계산 · 작업 목록)에 묶는 자리를 가져야 한다.

## M6

방법: 2026-10-18 지휘 세션이 사용자 승인 아래 쟀다. 이 절은 그 결과를 옮겨 적은 것이다(새로 재지 않았다).

- (가) worktree 안에서 시작한 세션이 `EnterWorktree(path=<하니스 worktree 폴더 아래 다른 worktree>)` 로 옮겨 가 `pwd` · `git rev-parse --show-toplevel` 이 그 worktree 였고 `git status` · `git log` · 쓰기가 됐다. 같은 방법으로 앞 worktree 로 돌아와 git · 쓰기가 됐다.
- (나) 옮겨 간 자리에서 `spec-distill:spec-review` 를 부르자 사전 검사 줄이 `root=<그 worktree>` 였다.
- (다) 알려진 제약 — 이미 worktree 안에 있는 세션은 `EnterWorktree(name=…)` 로 새 worktree 를 못 만든다(`git worktree add` 는 격리 세션에서도 허용, 2026-10-17) · 옮겨 가기는 하니스 worktree 폴더 아래만 닿는다 · 옮긴 뒤 앞 worktree 는 다시 들어가기 전까지 읽기 전용이다.

판정: 지휘 세션은 하니스 worktree 폴더 아래의 에픽 worktree 로 옮겨 가 일하고 돌아올 수 있다. 폴더 밖 worktree 와 새 worktree 만들기는 이 길로 안 된다.

## M7

방법: 이 계획을 돌리는 측정 자리(지휘 세션이 보낸 SDD 실행 agent — 지휘 세션 본체가 아니다)에서 쟀다. `claude --version` = 2.1.302 (Claude Code).

- `ToolSearch` 의 `select:PushNotification` 은 도구를 돌려주지 않았다. 「없음(이 측정 자리 — 지휘 세션이 보낸 SDD 실행 agent — 의 도구 목록에 없다. 지휘 세션 본체는 재지 못함)」. 그래서 「보고 있을 때 보내지 않는다」 문면: 재지 못함 — 도구 없음.
- 아무 일도 하지 않는 agent 에 「숫자 7 을 기억하고 'ok' 라고만 답하라」 를 보냈고 'ok' 로 답하고 끝났다. 뒤이어 `SendMessage` 로 「기억한 숫자를 답하라」 를 보내자 그 agent 가 이어 불렸고("Resuming agent") 7 을 답했다 — 맥락이 이어졌다.

판정: 끝난 agent 를 `SendMessage` 로 이어 부르면 앞 맥락을 갖고 이어 간다(2026-10-18, Claude Code 2.1.302). 알림 도구의 유무와 문면은 지휘 세션 본체에서 재지 못했다 — conducting.md 는 「보고 있으면 보내지 않는다」 를 쓰지 않는다.

## M8

방법: `.superpowers/sdd/2026-10-18-epic-conductor-3-loop/m8.sh` 가 버릴 레포 셋(pytest · unittest · 실행 비트 셸)을 만들어 `shared/test-selection` 을 불렀다(출력 `m8.out`, git 이 추적하지 않는다). `diff-test-results.py` 는 첫 실행에서 레포 루트 밖이라 rc 4 로 거절돼, 같은 스크립트에서 그 호출만 각 버릴 worktree 안에서 부르게 바꾼 변형(`m8b.sh`)으로 다시 쟀다.

- (a) `assign` 에 `git ls-files` 전부를 넣으면 테스트 아닌 파일이 `unclaimed` 행으로 남는다. 증거: `pytest.ini	unclaimed	file` · `tests/__init__.py	unclaimed	file`. 끝에 `#qg-assign	adapters=pytest	rows=2` 형태의 요약 줄이 붙는다. `detect` 는 `runner:` · `granularity:` · `setup_cmd:` 세 줄(예 `runner: pytest` · `granularity: file` · `setup_cmd: -`)을 낸다.
- (b) `run … per-unit` 의 표준 오류에 러너 출력이 실린다. 증거: pytest `FAILED tests/test_x.py::test_a - assert 1 == 2` · unittest `FAIL: test_a (tests.test_y.T)` · 셸 `  ✗ 하나가 틀렸다`. 실패하는 테스트인데도 `run` 의 rc 는 0 이었다.
- (c) `diff-test-results.py` 출력은 `adapters:` · `verdict_input:`(`confirmed_product_defect` · `silent_drop` · `baseline_unrunnable`) · `attribution_status` · `degrade_causes` · `new_failures` · `unclaimed` · `per_adapter:`(`runner` · `granularity` · `causes` · `counts` · `attributions:` 의 `unit` · `verdict` · `note`) 모양이다. 기준선 행을 그대로 베낀 같은 커밋 두 개로 부르면 `verdict: BASELINE_UNRUNNABLE`, `note: "기준선과 HEAD 의 트리가 같다 — 비교할 차이가 없다"`, `attribution_status: degraded`. `unclaimed` 가 비어 있지 않으면 `verdict_input.silent_drop: true` · `degrade_causes: [baseline-unrunnable, silent-drop]`(pytest · unittest 관측, 셸은 `unclaimed: []` 라 false; 소스 `diff-test-results.py` 246~247줄) — merge_check 는 `assign` 을 claimed 단위만으로 다시 돌려야 한다. 레포 루트 밖에서 부르면 `커밋 … 의 트리를 읽지 못했다 — 리포 루트에서 불러라`, rc 4. 실제로 다른 두 커밋의 귀속(`new_regression` 등)은 재지 못함 — 이 측정은 같은 커밋만 썼다.
- (d) `run` 은 detached 트리를 요구한다. 측정에서는 모두 `git worktree add --detach` 트리를 넘겼다. 브랜치에 붙은 트리를 넘기는 경우는 돌려 보지 않았고 소스 `run-test-selection.sh` 의 `브랜치에 붙은 트리에서는 돌리지 않는다 — create-baseline/create-head 가 만든 detached 트리를 넘겨라` 거절 줄로만 확인했다.
- (e) `compute-test-scope-candidates.sh --total --tree HEAD` 는 버릴 pytest 레포에서 `1`(rc 0)을 냈다 — (이 레포의 테스트 파일 하나와 일치).

판정: 「이름은 `run` 표준 오류에서 뽑는다」 가 성립한다(세 러너 모두 이름이 든 줄이 실린다).

## M9

방법: `grep -n "general-purpose" <superpowers 7.0.0 캐시>/skills/requesting-code-review/SKILL.md`.

- 34번째 줄: ``Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)``.

판정: 리뷰 요청 skill 이 부르는 agent 는 `general-purpose` 다. 이 레포의 agent 목록에서 general-purpose 의 도구는 전체(`*`)이므로 쓰기 도구를 가진다 — 결정 D 의 근거.

## M10

방법: 기본 브랜치(`origin/HEAD`)의 detached 사본과, 거기에 이 브랜치 끝(`0205ed1c`)을 `--no-ff` 로 합친 사본을 만들었다. 각 사본에서 손 헬퍼(`suite-names.sh`)와 `tools/suite/run-all.sh` 를 한 번에 하나씩 돌렸다(스위트 잠금을 쥔 채, 한 번에 약 19분씩 넷). `run-all.sh` 출력은 `merge_check.names_in(text, "^FAILED (.+)$")` 로 이름을 뽑았다. 손 헬퍼는 spec-distill · quality-gates · shared 만 재므로 두 쪽 모두 그 범위로 좁혀 견줬다(`plugin-audit` 실패 한 줄은 범위 밖).

결과(줄 수): 손 헬퍼 기준선 2 · 합친 것 7. 스위트 명령 원출력 기준선 4 · 합친 것 8, `names_in` 뒤 좁힌 집합 기준선 3 · 합친 것 7.

- 새 실패 집합: 같다. 다섯 줄 — `test_epic_conductor_skill.sh` 둘(`격리 없는 인라인 python 호출`, `공유 락 test_inline_python_isolated.sh 가 통과한다`) · `test_readme_sync.sh` 둘(AP9 `UNLISTED integration-reviewer`, AP9 수 `10`/`10`/`11`) · `shared/tests/test_inline_python_isolated.sh` 하나. 날것 비교에서는 AP9 UNLISTED 줄 하나가 달랐는데, 손 헬퍼 쪽 줄 끝에 공백이 하나 남고 `names_in` 이 끝 공백을 떼기 때문이다. 끝 공백을 떼어 견주면 같다.
- 고쳐짐 집합: 손 헬퍼는 0줄, 스위트 명령은 1줄(`plugins/quality-gates/tests/test_codex_backward_compat.sh: rc 1(실패 표시 줄 없음)`). 그 파일은 기준선 사본에서 `run-all.sh` 가 돌 때만 한 번 rc 1 이었고, 같은 사본에서 혼자 두 번 돌리자 둘 다 rc 0 이었으며 손 헬퍼의 기준선 실행에서도 통과했다. 그 파일이 `run-all.sh` 실행에서 rc 1 이 된 원인은 재지 못했다 — 당시 `run-all.sh` 는 `FAIL:` 줄을 버렸다.

동치의 범위: 견준 것은 셸 테스트의 `✗` 줄과 unittest 의 `FAIL:` · `ERROR:` 줄뿐이다. `plugin-audit` 와 node 테스트는 `narrow` 밖이었고, 실패 표시 줄 없이 rc 만 있는 꼴은 두 쪽의 글자가 다르다(손 헬퍼 `rc 1 (✗ 줄 없음)` · 스위트 명령 `rc 1(실패 표시 줄 없음)`).

판정: 새 실패 집합은 이 범위에서 손 헬퍼와 같았다. 고쳐짐 집합은 한 줄 달랐고 원인은 재지 못했다. `merge_check` 는 고치지 않았다.

M10 뒤의 변경: 이 대조는 아래 고치기 전의 `run-all.sh` 로 쟀다. 그 뒤 `run-all.sh` 는 셸 테스트의 `FAIL:` 표시 줄도 이름으로 뽑고, python · node 실행의 종료 코드를 잡아 실패 표시 줄이 없으면 rc 줄을 내고, 셸 테스트를 `find` 로 중첩 폴더까지(`spike` · `fixtures` 제외) 돌리고, `tools/*/test_*.py` 를 더하고, node 의 TAP 번호를 이름에서 떼고, unittest 를 인라인 `python3 -m unittest discover` 대신 스크립트 파일 `tools/suite/run_unittest_dir.py` 로 돌린다. 바뀐 `run-all.sh` 의 동치는 이 측정으로 확인된 것이 아니다.

`-I` 측정: 인라인 unittest 호출에 `python3 -I` 를 붙여 디렉토리별로 견주니 plugin-audit(304) · project-init(46) · shared/tests(0)는 같았으나 spec-distill 은 511개에 건너뜀 2개가 더 생겼고 quality-gates 는 142개 통과에서 107개 · 오류 4건이 됐다. 사용자 site-packages 가 빠져서이며(현재 디렉토리 때문이 아니다), 그래서 `-I` 대신 스크립트 파일 호출을 쓴다 — 그 호출은 sys.path 맨 앞에 스크립트 폴더를 두고 사용자 site-packages 는 남긴다. 스크립트 러너의 디렉토리별 개수는 평범한 `python3 -m unittest discover` 와 같았다(304 · 46 · 142 · 511(실패 1) · 0).
