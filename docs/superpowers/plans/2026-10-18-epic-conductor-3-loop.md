# R5 지휘자 — 계획 3: 지휘 순환 · 지휘자 skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 로드맵 하나를 끝까지 지휘하는 진입 skill `/spec-distill:epic-conductor` 와 그것이 기대는 기계 부분(스위트 대조 `merge_check.py` · 기록 · 자원 · 감사 `conductor_ledger.py` · 쓰기 권한 없는 통합 리뷰어)과 판단 부분(`references/conducting.md` 의 지휘 순환 걸음 1~7 · `references/conductor-dispatch.md`)을 만들고, 지휘자를 가리키는 진입 안내(나눈 일의 다음 세션 줄 · 로드맵 템플릿과 이 로드맵의 지휘 절차 · 에픽 넘김 줄 · spec-review 승인 게이트 줄의 로드맵 갈래)를 바꾼다.

**Architecture:** 흐름은 코드에 박지 않는다 — skill 본문은 순환의 차례와 걸음마다 읽을 reference 만 두고, 걸음의 기본값 · 판단 기준은 `conducting.md` 가 담는다. 스크립트는 superpowers 에 없는 「에픽 사이」 기계 일만 한다: `merge_check.py` 는 R2a 가 `shared/test-selection/` 으로 옮긴 공유본 넷(링크)으로 단위를 짝짓고 그 위에 실패 «이름» 대조를 얹는다. `conductor_ledger.py` 는 계획 1 의 `conductor_state.py`(기계 상태 형식 · 표지)와 `roadmap_model.py`(읽기 전용 넘김 · 절 읽기) 위에서 쓰기 · 자원 · 기록 절 · 감사 후보를 맡는다. 상태 계산(`roadmap_status.py`)은 git 만 읽는 성질을 지키며 승인 줄을 읽는다.

**Tech Stack:** Python 3.9 표준 라이브러리, bash 3.2 셸 테스트(`shared/tests/assert.sh`), git, 선택적으로 `gh`. 새 패키지 없음.

**Spec:** `docs/superpowers/specs/2026-10-17-epic-conductor-design.md` — 이 계획은 §11 의 계획 3(지휘자)이다. 이 계획의 AC: AC15 · AC16 · AC17 · AC18 · AC19 · AC20 · AC21 · AC22 · AC23 · AC24 · AC25 · AC26 · AC27 · AC28 · AC29 · AC30 · AC31(「넘김 줄은 지휘자를 끈 경우에만」) · AC36 · AC37 · AC38 · AC41 · AC42(로드맵 갈래) · AC43(기록 자리와 PR 순서) · AC44 · AC45. 설계 `## 미룸` 표에서 받는 곳이 R5 인 행 전부와 `### Deferred to plan` 두 행도 이 계획이 받는다(아래 「받은 미룸」). 브랜치는 `feature/epic-conductor-loop`(로드맵 R5 블록의 셋째 브랜치, 계획 1 · 2 가 머지된 기본 브랜치에서)이다. R2a 의 `shared/test-selection/` 이 기본 브랜치에 있다(D1.3 의 선행 조건 충족).

## Global Constraints

- `python3` 는 3.9.6 이다 — `match` 문, 런타임 `X | Y` 타입, `str.removeprefix` 금지. 표준 라이브러리만 쓴다(설계 §8). `plugins/**/*.py` 에 `"python3"` 문자열을 쓰지 않는다(`shared/tests/test_python_floor.sh`) — 파이썬 스크립트를 부를 때는 `sys.executable`. 모든 `open(` · `.read_text(` 에 `encoding="utf-8"` 를 준다(글자 검사라 주석 안 `open(` 도 걸린다 — `plugins/quality-gates/tests/test_utf8_explicit.py`).
- 새 `scripts/*.py` 의 `re.compile` 리터럴은 `"## 6. 사용자 원문"` 맨 앞 3글자 이상과 맞으면 안 된다(`tests/test_check_brief.sh` §6 단일화) — 머리 찾기는 문자열 메서드(`startswith` · `==`)로 한다. `r"^##\s"` 같은 일반 패턴도 걸린다.
- 정적 읽기 전용 락(`tests/test_roadmap_status.sh` `static_check` — `roadmap_status.py` · `check_bundle_coverage.py` · `roadmap_model.py` · `spec_review_bundle.py` · `repo_defaults.py` · `section6.py`)에 든 파일에는 새 import · 쓰기 호출 · subprocess 를 더하지 않는다. 메서드 이름이 `WRITE_ATTRS` 에 든 호출(`replace` · `mkdir` · `rename` · `unlink` · `write_text` …)은 `str.replace` 라도 쓰지 않는다(계획 1 판정). 쓰는 일은 `conductor_ledger.py` · `merge_check.py` 만 한다.
- 레포 전용 값을 박지 않는다(설계 §9 · AC29). 지휘자 skill · `conducting.md` · `conductor-dispatch.md` · `merge_check.py` · `conductor_ledger.py` · `agents/integration-reviewer.md` 에 기본 브랜치 이름(`main` · `master` · `origin/main`), 브랜치 접두(`feature/` · `fix/`), 레포 구조 경로(`docs/superpowers/` · `.superpowers/` · `plugins/spec-distill` · `.claude/worktrees`), 모델 이름(`opus` · `sonnet` · `haiku` · `fable` · `gpt-`)을 쓰지 않는다. 외부 도구가 정한 기본 경로와 플러그인 자기 상태 폴더 이름은 `scripts/repo_defaults.py` 상수에만 둔다(Task 14 의 락이 잰다). 기본 브랜치는 `origin/HEAD`, 브랜치 이름은 로드맵 블록, 폴더 · 테스트 명령 · 리뷰 모델은 로드맵 frontmatter 에서 읽는다.
- skill · reference 에 `${CLAUDE_PLUGIN_ROOT}` 를 쓰면 그 reference 를 `Read` 하는 SKILL.md 줄과 치환 안내 문장이 있어야 한다(`shared/tests/test_plugin_root_no_cwd_fallback.sh` 축 3). `conducting.md` · `conductor-dispatch.md` 에는 그 토큰을 쓰지 않고 `<SD>`(spec-distill 플러그인 폴더의 절대경로) 자리표를 쓴다 — 계획 2 의 손 절차와 같다. 다른 reference 는 파일 이름만 적는다(`shared/tests/test_skill_reference_pointers.sh`).
- skill 본문에 `$1` · `$2` 같은 위치 인자를 쓰지 않는다(`shared/tests/test_skill_body_no_positional_tokens.sh` — Skill 인자로 치환된다). 펜스 안 셸 함수도 이름 있는 변수로.
- 인라인 python 은 `python3 -I`(`shared/tests/test_inline_python_isolated.sh`). 스크립트 파일 호출에는 `-I` 를 붙이지 않는다.
- 새 진입 skill 은 `shared/entry/check_invocation_surface.py` 의 `ENTRY_SKILLS` 와 `shared/tests/test_invocation_surface.sh` 의 합성 리포 `ENTRY` 에 함께 등록한다(축 A~I). 사전 검사 줄 · `allowed-tools` 한 줄 · `## 진입 단계` 표는 `check_invocation_surface.py --print-head spec-distill epic-conductor` 출력을 그대로 쓴다.
- 사람에게 보이는 출력(스크립트 줄 · skill 의 글)은 `shared/style/plain-language.md` 를 따른다 — 내용을 먼저, 내부 용어 · 번호는 괄호에. SKILL.md 에는 `<!-- plain-language:begin -->` 블록을 `skills/roadmap-status/SKILL.md` 의 것과 바이트 그대로 둔다(`shared/tests/test_plain_language_block.sh`).
- 같은 20줄(200자 이상) 블록을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`). 셸 테스트에서 변수 바로 뒤 비ASCII 글자는 중괄호(`「${lit}」`). 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s` 가 `100755` 인지 본다. 셸 테스트는 리포 루트에서 `bash <파일>` 로 돈다. `# guards:` 머리는 달지 않는다(달면 `--emit-scanned` 를 요구한다).
- 스위트 둘을 같은 시각에 돌리지 않는다. 테스트 임시 폴더는 각 테스트가 `mktemp -d` 로 자기 것을 만들고 그것만 지운다 — 공유 임시 폴더를 glob 으로 지우지 않는다.
- 고치지 않는 것: superpowers 파일, `plugins/quality-gates/`, `shared/docreview/` · `shared/test-selection/`(R2a — 링크로 쓰기만), `skills/spec-interview/` 가운데 `references/finishing.md` 의 나눈 일 다음 세션 줄 한 줄 밖(R10 예약), `skills/request-framing/SKILL.md`(R10), 리뷰 엔진 동작.
- 커밋은 Conventional Commits, 설명은 한국어, `type`·`scope` 영어. 구현 커밋마다 `Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md` 트레일러. 커밋은 pathspec 으로(`git commit -m … -- <경로…>`) — 같은 worktree 의 다른 staged 변경을 쓸어 담지 않는다. 커밋 뒤 `git show --stat HEAD` 의 파일 수가 그 Task 의 파일 수와 같은지 본다. HEAD 를 뒤로 옮기지 않는다(reset · rebase · force 금지). 지휘 세션이 같은 worktree 에서 설계문서 · 로드맵을 고칠 수 있다 — 그 파일들을 되돌리지 않는다.
- 버전: 이 PR 은 `plugins/spec-distill/.claude-plugin/plugin.json` 의 minor 를 하나 올린다(새 진입 skill · 새 스크립트 · 새 agent). 번호는 머지 직전에 origin 기본 브랜치의 값을 보고 정한다(Task 16).
- 실행 방식의 마지막 전체 리뷰에는 설계문서 `## Acceptance Criteria` 중 이 계획의 AC(위 **Spec:** 줄)를 싣고, AC 마다 한 줄 `AC15: 구현됨 — 근거` 꼴(구현됨 · 미룸 · 빠짐)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일(SDD 작업 폴더의 `ac-report.md`)에 적는다(Task 16).

## Review Focus

1. **지휘자를 다시 불렀는데 기계 상태가 없거나 깨졌다** — 다른 기기 · `.claude` 삭제 · 반쯤 쓴 파일. 잃는 것은 다시 만들 수 있는 것뿐이어야 하고(PR 번호는 `gh`, 자원은 「주인 모름」 목록, 기다리는 질문은 걸음 2 가 다시 모음), 깨진 파일을 빈 상태로 읽어 덮어쓰면 안 된다(Task 4 · Task 15 테스트).
2. **같은 로드맵을 두 세션이 동시에 지휘한다** — 둘째 세션은 기계 상태를 쓰지 못하고 읽기 전용으로 보여야 하며, 스위트 대조 둘이 같은 시각에 돌면 안 된다(Task 3 잠금 · Task 4 표지 테스트).
3. **양쪽 다 빨간 테스트 파일 안에 새 실패가 생겼다** — 단위 종료 코드만 보면 「원래 있던 실패」로 접힌다. 이름으로 갈라야 하고, 이름을 못 뽑으면 빈 집합끼리 같다고 하지 말고 「이름 대조 불가 — 단위 수준만」 이라고 해야 한다(Task 3 테스트).
4. **기본 브랜치 이름이 `main` 이 아닌 레포 · `gh` 가 없는 기계 · 테스트가 없는 레포** — 지휘 순환의 기계 부분이 레포 전용 값 없이 돌고, 빠진 것은 알리고 강등해야 한다(Task 7 · Task 15 테스트).
5. **승인 줄을 손으로 다르게 쓴 설계문서 · `## 지휘 기록` 머리가 둘인 설계문서** — 상태 계산이 「spec 있음」과 「승인됨」을 가르되, 깨진 문서를 「승인 없음」으로 조용히 떨어뜨리지 않아야 한다(Task 2 테스트).

## 받은 미룸

설계 `## 미룸` 표의 받는 곳 R5 행과 `### Deferred to plan` 두 행을 이 계획이 어디서 받는지:

| 미룸 행(요지) | 받는 Task |
|---|---|
| 기본 브랜치를 모를 때 상태줄이 빈칸 | Task 2(결정 F) |
| 에픽 보기가 머지된 에픽의 PR 번호를 안 보임 | Task 2 |
| 맞추기 걸음에서 설치된 spec-distill 버전 확인 | Task 7 · Task 10 |
| 단계마다 새 agent · 원장과 파일로 넘김 | Task 9 · Task 10 |
| 에픽에 새 항목을 넣을 때 brainstorming 필요 판단 | Task 10 |
| worktree 격리 세션이 그 worktree 를 떠날 수 있는지 실측 | 지휘 세션 실측(2026-10-18 — `EnterWorktree(path=…)` 로 옮겨 가기 · 돌아오기 · 옮긴 자리의 사전 검사 `root=` 모두 됨) · Task 1 이 그 사실을 M6 으로 적는다 · Task 10 |
| 로드맵 R5 범위를 재결정에 맞춤 | 이미 처리됨(#224 가 R5 범위 줄을 고쳤다) — Task 16 이 그 사실을 `## 지휘 기록` 에 남긴다 |
| 재분해 이력의 「순서만」 경우 · 라벨만 고른 답의 `--approval` | Task 12 |
| 실행 방식이 미리 받은 답인지 사람에게 돌리는 자리인지 | Task 9 |
| AC15 같은 세션 이어 부르기와 `cost_class: high` 의 긴장 | Task 4 · Task 11(결정 B) |
| `## 지휘 기록` 의 spec 승인 줄 형식 | Task 2 · Task 6(결정 C) |
| 에픽 넘김 줄 머리말이 재결정 전 표현 | Task 12 |
| `--impl` 은 작업 트리 로드맵, 상태 계산은 기본 브랜치 로드맵 · `DEFAULT_REF` · `NO_DEFAULT` 겹침 | Task 2(결정 G) |
| Deferred 9e1747a6#r1.1 — 알림 도구 · `SendMessage` 동작 실측 | Task 1(M7) |
| Deferred 2e6610eb#r2.1 — 손 헬퍼와 `merge_check` 의 실패 이름 집합 대조 | Task 13 |

## 설계에 없던 결정

설계가 정하지 않은 것을 이 계획이 정한 자리다. 지휘자가 사용자에게 물을 대상이다 — 답이 다르면 해당 Task 의 문면 · 코드만 바뀐다.

- **(결정 아님 — 실측으로 정함) 지휘 세션이 에픽 worktree 로 옮겨 가는 길.** 2026-10-18 지휘 세션 실측(사용자 승인): worktree 안에서 시작한 세션이 `EnterWorktree(path=<하니스 worktree 폴더 아래 다른 worktree>)` 로 옮겨 가 `pwd` · `git rev-parse --show-toplevel` 이 그 worktree 였고 git 과 쓰기가 됐으며, 다시 `EnterWorktree(path=<앞 worktree>)` 로 돌아왔다. 이어서 옮겨 간 자리에서 `spec-distill:spec-review` 를 부르면 진입 사전 검사 줄이 `root=<그 worktree>` 를 냈다(실측 2). 그래서 기본 길은 ① `EnterWorktree(path=<에픽 worktree>)` → 사전 검사 줄의 `root=` 가 그 worktree 인지 확인 → 그 자리에서 spec-review(설계문서 · 묶음 절대경로) → 그 자리에서 커밋 → `EnterWorktree(path=<앞 자리>)` 로 돌아옴(앞 자리가 메인 체크아웃이고 이 세션이 지금 worktree 에 하니스로 들어갔으면 `ExitWorktree(action: "keep")`) 이고, 안 되면 ② 메인 체크아웃에서 Bash `cd`, 그것도 안 되면 ③ 그 에픽 담당 agent 가 두 부분(쉬운 요약 + 원문)으로 돌려보낸다. 실측이 정한 제약 셋: (1) 이미 worktree 안에 있는 세션은 `EnterWorktree(name=…)` 로 새 worktree 를 만들 수 없다 — 에픽 worktree 는 `git worktree add <메인 체크아웃>/<하니스 worktree 폴더>/<이름> -b <블록의 브랜치> <기준>` 으로 만들고(격리 세션에서도 허용, 2026-10-17 실측) 그다음 `EnterWorktree(path=…)` · (2) 옮겨 가기는 하니스 worktree 폴더(이름은 `repo_defaults.WORKTREE_HOME` 상수) 아래 worktree 에만 닿는다 · (3) 옮긴 뒤에는 앞 worktree 가 다시 들어가기 전까지 읽기 전용이다 — 지휘자는 옮기기 전에 그 자리의 쓰기(커밋 포함)를 끝낸다. 이 길은 실측으로 정해졌으므로 사용자에게 다시 묻지 않는다. 바뀌는 것: `conducting.md` 걸음 3 과 손 절차 걸음 2 · 3 의 해당 문장(Task 10), 사전 검사 `root=` 확인을 잠그는 테스트(Task 10).
- **B. 같은 세션에서 지휘자를 다시 부를 때의 시작 승인(AC15 vs `cost_class: high`).** 권장: 이름 붙인 예외 — 기계 상태에 `## 시작 승인` 절(세션 · 규모 · 때)을 더해, 같은 세션의 승인이 살아 있고 규모 줄이 글자 그대로 같으면 `AskUserQuestion` 대신 「이 세션에서 이미 승인받은 규모 그대로다」 공시만 한다. 규모가 바뀌었거나 다른 세션이면 다시 묻는다. 예외의 이름과 이유는 SKILL.md 와 README 에 적고, 지출 조항 문면 자체는 R9 가 고친다. 대안: 부를 때마다 승인(레포 규칙 그대로, 압축 뒤 이어 부를 때마다 질문 하나가 는다). 바뀌는 것: `conductor_state.SECTIONS` 의 절 하나 · `conductor_ledger approval` · SKILL.md 진입 단계 문장(Task 4 · Task 11).
- **C. spec 승인 줄 형식과 상태 계산이 그것을 보이는 방법.** 권장: `- spec 승인 · <YYYY-MM-DD> · 「<고른 선택지 원문>」` 한 줄(`conductor_ledger record --approval` 이 쓴다). 상태 계산은 단계 이름을 늘리지 않고 「설계 중」의 근거를 `spec 승인됨(<날짜>) · 계획 없음` 으로 바꾸고 JSON 에 `approved` 칸을 더한다. 손으로 쓴 옛 줄도 읽는다 — `## 지휘 기록` 의 `- ` 줄 가운데 날짜와 「승인」 이 함께 있고 「대기 · 전 · 거절 · 않」 이 없는 줄. 대안: 새 단계 「승인됨」(작업 목록 · 상태줄 묶음 · 락 여럿이 함께 바뀐다). 바뀌는 것: `roadmap_model.approval_date` · `roadmap_status.progress`(Task 2).
- **D. 통합 리뷰어.** `superpowers:requesting-code-review` 는 `general-purpose` agent 를 부른다(쓰기 도구가 있다 — Task 1 M9 가 근거를 적는다). 권장: 그 skill 의 리뷰 요청 틀(`code-reviewer.md`)을 쓰되 부르는 agent 는 spec-distill 의 새 읽기 전용 agent `integration-reviewer`(`tools: Read, Grep, Glob`)로 하고, 모델은 로드맵 frontmatter `review_model`(없으면 세션 모델)을 dispatch 에 준다. 대안: 다른 플러그인의 읽기 전용 리뷰어(선언 안 한 의존이 된다) · general-purpose 에 「쓰지 말라」 문장(Law 2 위반). 바뀌는 것: 새 파일 `agents/integration-reviewer.md` 와 SKILL.md 의 dispatch 자리(Task 11 — agent 와 그것을 부르는 자리는 같은 커밋이어야 dispatch 처분 락이 「어디서도 부르지 않는 agent」로 빨개지지 않는다).
- **E. devbrew 자신의 스위트 명령.** 탐지만으로는 devbrew 의 실행 비트 없는 셸 테스트 · `node --test` 테스트가 빠진다(설계 Metadata 참고 84d5a0c7). 권장: 레포 쪽 스크립트 `tools/suite/run-all.sh`(실패마다 `FAILED <파일>: <이름>` 한 줄)를 더하고 이 로드맵 frontmatter 에 `test_command: bash tools/suite/run-all.sh` 를 올린다 — 플러그인 밖 레포 파일이라 레포 전용 값 금지와 부딪히지 않는다. 대안: 더하지 않고 `merge_check` 가 첫 실행에 묻게 둔다. 바뀌는 것: Task 13 전체.
- **F. 기본 브랜치를 모를 때 상태줄.** 권장: 상태줄은 지금처럼 조용히 둔다(상태줄은 모든 레포에서 돌고, 작업 트리에서 로드맵을 찾으려면 폴더를 박거나 파일을 다 읽어야 한다). 대신 지휘자 맞추기 걸음과 `roadmap-status` 화면이 「기본 브랜치 모름」을 낸다(이미 낸다 — Task 2 가 테스트로 잠근다). 대안: 작업 트리에 `type: roadmap` 파일이 있을 때만 상태줄에 「기본 브랜치 모름」. 바뀌는 것: Task 2 의 한 Step.
- **G. `--impl` 이 읽는 로드맵.** `check_bundle_coverage.py` 는 정적 읽기 전용 락 안이라 git 을 부를 수 없다 — 권장: 지금처럼 작업 트리의 로드맵을 읽되 출력 줄에 그 사실을 적고, 지휘자는 `--impl` 전에 에픽 worktree 에 기본 브랜치를 merge 해 둔다(걸음 4). `DEFAULT_REF` · `NO_DEFAULT` 는 `roadmap_model.py` 한 곳으로 옮긴다. 대안: `--impl` 에 `--roadmap-text <파일>` 을 더해 지휘자가 기본 브랜치의 로드맵을 넘김. 바뀌는 것: Task 2 의 문구 한 줄.
- **H. 실행 방식은 「미리 받은 답」이다.** 설계 §3 걸음 3 · 4 와 §4 가 갈리던 것을 하나로 — 계획 agent 는 계획 검토 · 실행 방식 질문을 두 부분으로 돌려보내고 멈추며(지휘자가 「설계에 없던 결정」을 가르는 자리라서), 구현 agent 를 보낼 때는 writing-plans 가 권한 실행 방식을 미리 받은 답으로 적는다. 사용자가 다른 방식을 말하면 그 말을 따른다. 바뀌는 것: `conductor-dispatch.md` 의 한 절(Task 9).
- **I. 단계마다 새 agent.** 계획 agent 와 구현 agent 를 따로 보내고, 사이는 커밋된 계획 파일 · 설계문서 경로로만 넘긴다(맥락 94만 토큰 실측 — 미룸 행). 리뷰 원장을 이어야 하는 재리뷰만 같은 agent 를 이어 부른다(`SendMessage`, Task 1 M7 결과에 따라). 바뀌는 것: `conductor-dispatch.md` 한 절(Task 9).
- **K. 로드맵 에픽의 승인 게이트 둘째 줄과 계획 agent 의 입력.** 설계는 AC42 에서 로드맵 에픽의 다음 세션 줄을 「지휘자 이어 부르기」 로 바꾸라 하고, AC44 · §3 에서는 「다음 세션 줄을 계획 agent 의 입력으로 넘긴다」 고 한다 — 둘째 줄이 지휘자 호출이면 계획 agent 가 받을 writing-plans 지시가 사라진다. 권장: 로드맵 에픽이면 ①/② 가 치게 하는 둘째 줄은 `/spec-distill:epic-conductor <로드맵 절대경로>` 로 바꾸고, 원래의 writing-plans 줄은 지우지 않고 「계획 agent 의 입력(치지 않는다)」 머리 아래 그대로 보인다 — 지휘자가 그 줄을 계획 agent 에게 넘긴다. 대안: 둘째 줄만 바꾸고 계획 agent 의 지시는 `conductor-dispatch.md` 의 계획 틀만으로(게이트 글이 짧아지지만 손 절차 걸음 3 의 「그 줄을 계획 agent 에게 넘긴다」 문장과 그 락을 함께 고쳐야 한다). 바뀌는 것: `skills/spec-review/SKILL.md` 의 한 문단과 그 락(Task 12).
- **J. 머지된 에픽의 PR 번호.** 머지 커밋 메시지를 해석하지 않고(호스트마다 모양이 다르다) 기계 상태 캐시 → `gh pr list --state all --head <브랜치>` 순으로, 에픽 하나로 내려가는 보기에서만 찾는다(지도 전체에서 머지된 에픽마다 `gh` 를 부르면 느리다). 바뀌는 것: Task 2 의 `control_plane.py` 한 함수.

## 경로 예약 겹침(정보)

겹침은 막지 않는다 — 통합 리뷰에서 맞춘다.

- `skills/spec-interview/references/finishing.md` — R10 예약(인터뷰 끝 게이트 · `spec-interview` → `pm-interview` 개명). 이 계획은 나눈 일의 다음 세션 줄 한 줄과 그 바로 아래 설명 문단만 고친다(AC36). R10 이 먼저 머지되면 파일 경로가 바뀐다 — merge 로 따라간다.
- `shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` — 진입 skill 등록 두 줄. R10 의 개명도 같은 목록을 고친다.
- `tools/suite/run-all.sh`(새 파일, 결정 E)와 `docs/superpowers/roadmaps/…/roadmap.md` frontmatter · `## 지휘 절차` · `measurements.md` — 어느 에픽의 경로 예약에도 없다.
- `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` — R10 · R2a 도 bump 한다. 번호는 머지 직전에.

## 파일 구조

| 파일 | 책임 | Task |
|---|---|---|
| `scripts/roadmap_model.py` (고침) | 승인 줄 읽기 · 기본 브랜치 참조 상수 한 곳 | 2 |
| `scripts/roadmap_status.py` (고침) | 「설계 중」 근거에 승인 · JSON `approved` | 2 |
| `scripts/control_plane.py` (고침) | 상수 import · 머지된 에픽 PR 번호 | 2 |
| `scripts/check_bundle_coverage.py` (고침) | `--impl` 받는 곳 규칙 줄에 읽은 로드맵 | 2 |
| `scripts/merge_check.py` (새) | 합친 사본 · 잠금 · 스위트 대조(이름) | 3 |
| `scripts/run-test-selection.sh` 외 셋 (새 링크) | `shared/test-selection/` 공유본으로 가는 상대 링크 | 3 |
| `scripts/repo_defaults.py` (고침) | `WORKTREE_HOME` · `MERGE_CHECK_DIR` 상수 | 3 |
| `scripts/conductor_state.py` (고침) | `## 시작 승인` 절 | 4 |
| `scripts/conductor_ledger.py` (새) | 표지 · 행 쓰기 · 시작 승인 · 로드맵 찾기 · 자원 · 정리 전 확인 · 주인 모름 · 기록 절 · 판정 거두기 · 감사 · PR 인계 · 통합 리뷰 묶음 | 4~8 |
| `references/conductor-dispatch.md` (새) | 하위에게 주는 글의 틀 · 금지 · 두 부분 반환 · 처분 줄 | 9 |
| `references/conducting.md` (고침) | 지휘 순환 걸음 1~7 절(손 절차 앞) · 손 절차의 worktree 옮겨 가기 문장 | 10 |
| `skills/epic-conductor/SKILL.md` (새) · `agents/integration-reviewer.md` (새) | 진입 · 시작 승인 · 순환 차례 · 걸음별 reference · 처분 줄 · 쓰기 권한 없는 통합 리뷰어 | 11 |
| 진입 안내 넷 + `references/redecompose.md` (고침) | 지휘자를 가리키는 안내 | 12 |
| `tools/suite/run-all.sh` (새) · 로드맵 frontmatter | devbrew 의 스위트 명령(결정 E) | 13 |
| `tests/test_repo_literals.sh` (새) | AC29 락 · 변이 | 14 |
| `tests/test_conductor_e2e.sh` (새) | AC30 버릴 레포 끝에서 끝 | 15 |

---

### Task 0: 스위트 기준선

**Files:**
- Create: `.superpowers/sdd/2026-10-18-epic-conductor-3-loop/suite-names.sh` (git 이 추적하지 않는다)
- Create: `.superpowers/sdd/2026-10-18-epic-conductor-3-loop/baseline.txt`

**Interfaces:**
- Produces: `suite-names.sh` — 리포 루트에서 돌면 실패 «이름» 을 한 줄씩(`<파일>: <이름>`) 정렬해 낸다. Task 13 은 같은 스크립트를 「손 헬퍼」로 삼아 `merge_check` 와 대조하고, Task 16 은 이 기준선과 대조한다.

- [ ] **Step 1: 스크립트를 쓴다**

```bash
#!/usr/bin/env bash
# 실패 이름 집합 — 셸 테스트의 「  ✗ 」 줄, unittest 의 FAIL: · ERROR: 줄, node --test 의 not ok 줄.
# 실패 표시 줄 없이 rc≠0 이면 그 사실을 한 줄로.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
{
  for f in plugins/spec-distill/tests/*.sh plugins/quality-gates/tests/*.sh shared/tests/test_*.sh; do
    [ -f "$f" ] || continue
    out="$(bash "$f" 2>&1)"; rc=$?
    name="${f}"
    printf '%s\n' "$out" | sed -n 's/^  ✗ //p' | sed "s|^|$name: |"
    if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -q '^  ✗ '; then
      echo "$name: rc $rc (✗ 줄 없음)"
    fi
  done
  for d in plugins/spec-distill/tests plugins/quality-gates/tests shared/tests; do
    python3 -m unittest discover -s "$d" -p 'test_*.py' 2>&1 | grep -E '^(FAIL|ERROR): ' | sed "s|^|$d: |"
  done
  for f in $(git ls-files 'plugins/*/tests/*.test.mjs'); do
    node --test --test-reporter=tap "$f" 2>&1 | grep -E '^\s*not ok ' | sed "s|^|$f: |"
  done
} | LC_ALL=C sort
```

- [ ] **Step 2: 기준선을 잰다(이 브랜치의 지금 HEAD)**

Run: `mkdir -p .superpowers/sdd/2026-10-18-epic-conductor-3-loop && bash .superpowers/sdd/2026-10-18-epic-conductor-3-loop/suite-names.sh > .superpowers/sdd/2026-10-18-epic-conductor-3-loop/baseline.txt; wc -l .superpowers/sdd/2026-10-18-epic-conductor-3-loop/baseline.txt`
Expected: 파일이 생기고 줄 수가 찍힌다. 이미 빨간 이름은 이 계획의 회귀가 아니다 — Task 16 이 이름 집합으로 대조한다. 실행 중에는 이 스크립트를 고치지 않는다(bash 는 실행 중에 파일을 읽는다).

커밋하지 않는다.

---

### Task 1: 실측 — worktree 옮겨 가기 · 알림 · 이어 부르기 · 테스트 공유본 · 리뷰 요청 agent (M6~M9)

이 Task 는 코드를 만들지 않고 뒤 Task 들이 기대는 도구 동작을 잰다(설계 Deferred 9e1747a6#r1.1 「계획이 먼저 실측한다」, 사용자 원칙 「설계는 도구 동작 사실을 단정하지 말 것」). **M7 은 이 계획을 돌리는 메인 세션(SDD 의 지휘 세션 또는 단일 세션)이 직접 한다** — 하위 agent 의 도구 목록은 메인 세션과 다르다. M8 · M9 는 구현 agent 가 해도 된다. M6(worktree 옮겨 가기)은 지휘 세션이 2026-10-18 에 이미 쟀다 — 그 결과를 옮겨 적기만 한다. 결과는 로드맵의 `measurements.md` 에 적는다.

**Files:**
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md` (표에 M6~M9 행 · 절 넷)
- Create: `.superpowers/sdd/2026-10-18-epic-conductor-3-loop/m8.sh` (git 이 추적하지 않는다)

**Interfaces:**
- Produces: M6 절 — 지휘 세션 실측(2026-10-18)의 옮겨 적기. Task 10 의 기본 길 문장의 근거다.
- Produces: M7 의 결론 — 알림 도구(`PushNotification`)가 이 세션에 있는지 · 그 도구 설명이 「터미널을 보고 있으면 보내지 않는다」를 말하는지(말하지 않으면 conducting.md 는 그 문장을 쓰지 않는다) · 끝난 agent 에 `SendMessage` 를 보내면 그 agent 가 앞 맥락을 갖고 이어 가는지. Task 9 · 10 이 쓴다.
- Produces: M8 의 결론 — 공유본 `detect` · `assign` · `run` · `diff-test-results.py` 의 실제 입출력과, `run … per-unit` 의 표준 오류에 러너 출력(이름이 든 줄)이 실리는지. Task 3 이 쓴다.
- Produces: M9 — `requesting-code-review` 가 부르는 agent 종류(근거 줄). Task 11 이 쓴다.

- [ ] **Step 1: M6 — 지휘 세션 실측을 옮겨 적는다(새로 재지 않는다)**

2026-10-18 지휘 세션이 사용자 승인 아래 잰 것: (가) worktree 안에서 시작한 세션이 `EnterWorktree(path=<하니스 worktree 폴더 아래 다른 worktree>)` 로 옮겨 가 `pwd` · `git rev-parse --show-toplevel` 이 그 worktree 였고 `git status` · `git log` · 쓰기가 됐다. 같은 방법으로 앞 worktree 로 돌아와 git · 쓰기가 됐다. (나) 옮겨 간 자리에서 `spec-distill:spec-review` 를 부르자 사전 검사 줄이 `root=<그 worktree>` 였다. (다) 알려진 제약 — 이미 worktree 안에 있는 세션은 `EnterWorktree(name=…)` 로 새 worktree 를 못 만든다(`git worktree add` 는 격리 세션에서도 허용, 2026-10-17) · 옮겨 가기는 하니스 worktree 폴더 아래만 닿는다 · 옮긴 뒤 앞 worktree 는 다시 들어가기 전까지 읽기 전용이다. 이 셋을 Step 5 의 M6 절에 그대로 적는다.

- [ ] **Step 2: M7 — 알림 · 이어 부르기 (메인 세션이 직접)**

1. `ToolSearch` 로 `select:PushNotification` 을 불러 도구가 있는지, 그 설명 문면에 「보고 있을 때 보내지 않는다」 뜻이 있는지 원문 한 줄을 적는다. 없으면 「없음」.
2. 아무 일도 하지 않는 agent 하나를 보낸다(`Agent`, 프롬프트 「숫자 7 을 기억하고 'ok' 라고만 답하라」). 끝난 뒤 `SendMessage` 로 「기억한 숫자를 답하라」를 보내 답에 7 이 있는지 적는다. `SendMessage` 가 없거나 거부되면 그 문면을 적는다.

- [ ] **Step 3: M8 — 테스트 공유본 입출력 (구현 agent 가 해도 됨)**

`.superpowers/sdd/2026-10-18-epic-conductor-3-loop/m8.sh`:

```bash
#!/usr/bin/env bash
# M8 — shared/test-selection 의 입출력을 버릴 레포 셋(pytest · unittest · 실행 비트 셸)에서 잰다.
set -u
SHARED="$(git rev-parse --show-toplevel)/shared/test-selection"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
mk() {  # mk <이름> — 기본 브랜치 trunk 인 버릴 레포
  local d="$T/$1"
  git init -q -b trunk "$d" && git -C "$d" config user.email m8@x && git -C "$d" config user.name m8
}
mk py; mkdir -p "$T/py/tests"; printf '[pytest]\n' > "$T/py/pytest.ini"
printf 'def test_a():\n    assert 1 == 2\n\ndef test_b():\n    assert True\n' > "$T/py/tests/test_x.py"
mk ut; mkdir -p "$T/ut/tests"; touch "$T/ut/tests/__init__.py"
printf 'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 2)\n' > "$T/ut/tests/test_y.py"
mk sh; mkdir -p "$T/sh/tests"; printf '#!/usr/bin/env bash\necho "  ✗ 하나가 틀렸다"\nexit 1\n' > "$T/sh/tests/t.sh"; chmod +x "$T/sh/tests/t.sh"
for r in py ut sh; do
  d="$T/$r"; git -C "$d" add -A && git -C "$d" commit -qm init
  git -C "$d" worktree add -q --detach "$T/$r-wt" HEAD
  echo "== $r detect"; bash "$SHARED/run-test-selection.sh" detect "$T/$r-wt"
  git -C "$T/$r-wt" ls-files > "$T/$r.files"
  bash "$SHARED/run-test-selection.sh" assign "$T/$r-wt" "$T/$r.assign" < "$T/$r.files"
  echo "== $r assign"; cat "$T/$r.assign"
  runner="$(awk -F'\t' '$2!="unclaimed" && $1!~/^#/{print $2; exit}' "$T/$r.assign")"
  unit="$(awk -F'\t' '$2!="unclaimed" && $1!~/^#/{print $1; exit}' "$T/$r.assign")"
  mkdir -p "$T/$r.rows"
  echo "== $r run per-unit $runner $unit (stderr 아래)"
  bash "$SHARED/run-test-selection.sh" run "$T/$r-wt" "$runner" per-unit "$T/$r.rows/baseline-$runner.tsv" "$unit" 2> "$T/$r.err"; echo "rc=$?"
  sed -n '1,40p' "$T/$r.err"
  cp "$T/$r.rows/baseline-$runner.tsv" "$T/$r.rows/head-$runner-i1.tsv"
  sha="$(git -C "$T/$r-wt" rev-parse HEAD)"
  echo "== $r diff"; python3 "$SHARED/diff-test-results.py" --assign "$T/$r.assign" --rows "$T/$r.rows" --iter 1 --baseline-commit "$sha" --head-commit "$sha"; echo "rc=$?"
done
echo "== compute --total"; (cd "$T/py-wt" && bash "$SHARED/compute-test-scope-candidates.sh" --total --tree HEAD; echo "rc=$?")
```

Run: `bash .superpowers/sdd/2026-10-18-epic-conductor-3-loop/m8.sh > .superpowers/sdd/2026-10-18-epic-conductor-3-loop/m8.out 2>&1; cat .superpowers/sdd/2026-10-18-epic-conductor-3-loop/m8.out`
적을 것: (a) `assign` 에 모든 파일을 넣었을 때 테스트 아닌 파일이 `unclaimed` 행으로 남는지, (b) `run … per-unit` 의 표준 오류에 pytest 의 `FAILED tests/test_x.py::test_a` · unittest 의 `FAIL: test_a` · 셸의 `  ✗ ` 줄이 실리는지, (c) `diff-test-results.py` 출력의 `per_adapter` · `attributions` · `verdict` 모양, (d) `run` 이 붙지 않은(detached) worktree 를 요구하는지, (e) `--total --tree HEAD` 가 그 레포의 테스트 파일 수를 내는지.

- [ ] **Step 4: M9 — 리뷰 요청 skill 이 부르는 agent**

Run: `grep -n "general-purpose" "$(ls -d ~/.claude/plugins/cache/*/superpowers/*/skills/requesting-code-review | tail -1)/SKILL.md"`
Expected: `Dispatch a \`general-purpose\` subagent` 줄. 그 줄을 근거로 적는다(general-purpose 는 쓰기 도구를 가진다 — 결정 D 의 근거).

- [ ] **Step 5: measurements.md 에 적는다**

표(`| # | 묻는 것 | 결과(한 줄) | 바꾸는 것 |`) 끝에 네 행을 더하고, 파일 끝에 `## M6` ~ `## M9` 절(방법 · 적은 것 · 판정)을 더한다. 첫 줄의 측정 버전 문장 뒤에 「M6~M9: 2026-10-18 · Claude Code <claude --version 값>」 을 덧붙인다. 결과 칸은 관측한 것만 쓴다 — 관측하지 못한 것은 「재지 못함 — <이유>」.

```markdown
| M6 | 지휘 세션이 다른 worktree 로 옮겨 가 쓰고 돌아올 수 있는가 · 옮겨 간 뒤 진입 사전 검사의 `root=` · 하니스 폴더 밖 worktree | 하니스 worktree 폴더 아래로 `EnterWorktree(path=…)` 옮겨 가기 · 돌아오기 · git · 쓰기 됨, 옮긴 자리의 spec-review 사전 검사 `root=` 가 그 worktree(2026-10-18 지휘 세션 실측). 폴더 밖은 닿지 않고, 옮긴 뒤 앞 worktree 는 읽기 전용, worktree 안에서는 `EnterWorktree(name=…)` 로 새로 못 만든다 | R5 계획 3(conducting.md 걸음 3 의 옮겨 가는 길) |
| M7 | 알림 도구가 있는가 · 보고 있을 때 안 보낸다고 하는가 · 끝난 agent 를 `SendMessage` 로 이어 부르면 맥락이 이어지는가 | <Step 2 결과 한 줄> | R5 계획 3(conducting.md 알림 · conductor-dispatch.md 이어 부르기) |
| M8 | `shared/test-selection` 공유본의 배정 · 단위 실행 · 귀속 입출력, 단위 실행의 표준 오류에 실패 이름이 실리는가 | <Step 3 결과 한 줄> | R5 계획 3 Task 3(merge_check) |
| M9 | `requesting-code-review` 가 부르는 agent 와 그 쓰기 권한 | <Step 4 결과 한 줄> | R5 계획 3 결정 D(integration-reviewer) |
```

- [ ] **Step 6: 커밋**

```bash
git commit -m "docs(roadmap): R5 계획 3 실측 M6~M9 — worktree 옮겨 가기 · 알림 · 이어 부르기 · 테스트 공유본

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md
git show --stat HEAD   # 파일 하나
```

**멈출 조건:** M8 에서 (b) 가 아니면(단위 실행의 표준 오류에 러너 출력이 실리지 않으면) Task 3 의 「이름은 `run` 표준 오류에서 뽑는다」 가 성립하지 않는다 — Task 3 을 시작하지 말고 그 결과를 BLOCKED 로 보고한다(지휘자가 설계 재결정을 묻는다). M7 결과는 멈추지 않는다 — Task 9 · 10 의 갈래를 고를 뿐이다.

---
### Task 2: 상태 계산이 승인 줄을 읽고 · 기본 브랜치 참조를 한 곳에 · 머지된 에픽의 PR 번호 (AC17 · AC43 · 결정 C · F · G · J)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py` (상수 둘 이동 · `approval_date`)
- Modify: `plugins/spec-distill/scripts/roadmap_status.py` (상수 import · `approval_of` · `progress` 근거 · 블록 `approved`)
- Modify: `plugins/spec-distill/scripts/control_plane.py` (상수 import · `merged_prs` · `overlay`/`gather` 의 `focus` · `epic_view` PR 줄)
- Modify: `plugins/spec-distill/scripts/check_bundle_coverage.py` (`--impl` 받는 곳 규칙 문구)
- Create: `plugins/spec-distill/tests/test_roadmap_approval.py`
- Modify: `plugins/spec-distill/tests/test_coverage_scope.py` (규칙 문구 두 줄)

**Interfaces:**
- Produces: `roadmap_model.DEFAULT_REF = "refs/remotes/origin/HEAD"` · `roadmap_model.NO_DEFAULT`(글 그대로 옮김) · `roadmap_model.APPROVAL_PREFIX = "- spec 승인 · "` · `roadmap_model.approval_date(doc_text: str) -> str | None`(가장 늦은 승인 날짜 `YYYY-MM-DD`, 머리가 둘이면 `FormatError`).
- Produces: `roadmap_status.approval_of(git, tip: str, specs: list) -> tuple[str | None, str | None]`(날짜, 읽기 불가 사유). 블록 보고에 `approved`(날짜 또는 `None`). 「설계 중」 근거 셋: `spec 있음` · `spec 승인됨(<날짜>) · 계획 없음` · `spec 있음 · 지휘 기록 읽기 불가 — <사유>`.
- Produces: `control_plane.merged_prs(b: dict, prs: dict, gh_lookup) -> list[tuple[str, dict]]` · `gather(..., focus=None)` · `overlay(..., focus=None)` · 블록 `merged_prs`. Task 6 · 11 이 승인 줄을 쓰고 읽는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_roadmap_approval.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""승인 줄 읽기 · 상태 계산의 「설계 중」 근거 · 머지된 에픽 PR 번호(R5 계획 3 Task 2 — 결정 C · J).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_roadmap_approval.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import control_plane as cp  # noqa: E402
import roadmap_model as M  # noqa: E402
import roadmap_status as rs  # noqa: E402

DOC = "---\nsource_interview: b.md\n---\n\n# 설계\n\n## 지휘 기록\n\n%s\n"


class ApprovalDate(unittest.TestCase):
    def test_canonical_line(self):
        self.assertEqual(M.approval_date(DOC % "- spec 승인 · 2026-10-18 · 「① /compact 후 다음 세션 줄 (권장)」"), "2026-10-18")

    def test_latest_of_several(self):
        doc = DOC % "- spec 승인 · 2026-10-17 · 「①」\n- spec 승인 · 2026-10-19 · 「②」"
        self.assertEqual(M.approval_date(doc), "2026-10-19")

    def test_hand_written_line(self):
        self.assertEqual(M.approval_date(DOC % "- 2026-10-18 사용자가 spec 을 승인했다(① 고름)"), "2026-10-18")

    def test_negated_lines_are_not_approval(self):
        for line in ("- 2026-10-18 승인 대기", "- 2026-10-18 승인 전 리뷰 3라운드", "- 2026-10-18 승인 거절 — 고침",
                     "- 2026-10-18 아직 승인하지 않았다", "- 2026-10-18 승인 안 됨"):
            self.assertIsNone(M.approval_date(DOC % line), line)

    def test_no_section_or_no_line(self):
        self.assertIsNone(M.approval_date("# 설계\n"))
        self.assertIsNone(M.approval_date(DOC % "- 넘김 확인 · R2 · 0123abcd · 받음"))
        self.assertIsNone(M.approval_date(DOC % "승인 2026-10-18 (목록 줄 아님)"))

    def test_duplicate_heading_is_format_error(self):
        doc = DOC % "- spec 승인 · 2026-10-18 · 「①」" + "\n## 지휘 기록\n\n- x\n"
        with self.assertRaises(M.FormatError):
            M.approval_date(doc)

    def test_heading_in_fence_is_not_section(self):
        doc = "# 설계\n\n```\n## 지휘 기록\n- spec 승인 · 2026-10-18 · 「①」\n```\n"
        self.assertIsNone(M.approval_date(doc))


class FakeGit:
    """progress 가 부르는 git 읽기만 흉내 낸다 — 커밋 하나(tip)의 파일들."""
    def __init__(self, files, plans=()):
        self.files, self.plans = files, list(plans)

    def grep_files(self, tree, needle, folder):
        return [p for p in self.files if p.startswith(folder)]

    def blob(self, tree, path):
        return self.files.get(path)

    def merge_base(self, a, b):
        return "base"

    def changed(self, base, tip, folder):
        return [p for p in self.plans if p.startswith(folder)]

    def first_touch(self, base, tip, path):
        return "c1"

    def trailer_after(self, c, tip, base, trailers):
        return False


SETTINGS = {"specs_dir": "docs/superpowers/specs/", "plans_dir": "docs/superpowers/plans/"}
SPEC = "docs/superpowers/specs/x-design.md"


def spec_text(record):
    return "---\nsource_interview: rm/A1.md\n---\n\n# x\n\n## 지휘 기록\n\n%s\n" % record


class Progress(unittest.TestCase):
    def block(self):
        return {"id": "A1", "kind": "bundle", "fields": {}}

    def test_spec_only(self):
        b = self.block()
        got = rs.progress(FakeGit({SPEC: "---\nsource_interview: rm/A1.md\n---\n# x\n"}), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[:2], ("설계 중", "spec 있음"))
        self.assertIsNone(b["approved"])

    def test_approved_no_plan(self):
        b = self.block()
        got = rs.progress(FakeGit({SPEC: spec_text("- spec 승인 · 2026-10-18 · 「①」")}), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[:2], ("설계 중", "spec 승인됨(2026-10-18) · 계획 없음"))
        self.assertEqual(b["approved"], "2026-10-18")

    def test_broken_record_is_not_silent(self):
        b = self.block()
        doc = spec_text("- spec 승인 · 2026-10-18 · 「①」") + "\n## 지휘 기록\n\n- y\n"
        got = rs.progress(FakeGit({SPEC: doc}), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[0], "설계 중")
        self.assertTrue(got[1].startswith("spec 있음 · 지휘 기록 읽기 불가 — "), got[1])
        self.assertIsNone(b["approved"])

    def test_plan_wins_over_approval(self):
        b = self.block()
        plan = "docs/superpowers/plans/x.md"
        files = {SPEC: spec_text("- spec 승인 · 2026-10-18 · 「①」"), plan: "**Spec:** `%s`\n" % SPEC}
        got = rs.progress(FakeGit(files, [plan]), "main", "tip", b, "rm/A1.md", SETTINGS)
        self.assertEqual(got[0], "계획")


class OneDefaultRef(unittest.TestCase):
    def test_constants_live_in_model_only(self):
        self.assertIs(rs.DEFAULT_REF, M.DEFAULT_REF)
        self.assertIs(cp.DEFAULT_REF, M.DEFAULT_REF)
        self.assertIs(rs.NO_DEFAULT, M.NO_DEFAULT)
        self.assertIs(cp.NO_DEFAULT, M.NO_DEFAULT)
        for name in ("roadmap_status.py", "control_plane.py"):
            text = (Path(rs.__file__).parent / name).read_text(encoding="utf-8")
            self.assertNotIn('DEFAULT_REF = "', text, name)
            self.assertNotIn("NO_DEFAULT = (", text, name)


class MergedPrs(unittest.TestCase):
    def b(self):
        return {"id": "R1", "stage": "머지됨", "branch_states": [
            {"branch": "feature/a", "tip": None, "merged": "x"}, {"branch": "feature/b", "tip": None, "merged": "y"}]}

    def test_cache_then_gh(self):
        prs = {"feature/a": {"브랜치": "feature/a", "번호": "#7", "상태": "머지됨", "확인한 때": "t"}}
        calls = []

        def gh(br):
            calls.append(br)
            return {"number": "#9", "state": "머지됨", "source": "gh"}
        got = cp.merged_prs(self.b(), prs, gh)
        self.assertEqual(got, [("feature/a", {"number": "#7", "state": "머지됨", "source": "기계 상태"}),
                               ("feature/b", {"number": "#9", "state": "머지됨", "source": "gh"})])
        self.assertEqual(calls, ["feature/b"])

    def test_no_gh(self):
        got = cp.merged_prs(self.b(), {}, None)
        self.assertEqual([p["state"] for _b, p in got], ["알 수 없음", "알 수 없음"])

    def test_overlay_only_for_focus(self):
        report = {"blocks": [self.b(), dict(self.b(), id="R2")]}
        cp.overlay([("rm/roadmap.md", report)], lambda rel: ({"PR": [], "실행 원장": []}, None),
                   lambda br: {"number": "#1", "state": "머지됨", "source": "gh"}, True,
                   read=lambda p, n: "", focus="R1")
        self.assertIn("merged_prs", report["blocks"][0])
        self.assertNotIn("merged_prs", report["blocks"][1])

    def test_epic_view_shows_merged_prs(self):
        b = dict(self.b(), title="가", reason="머지", deps=[], parallel=[], specs=[], plans=[],
                 merged_prs=[("feature/a", {"number": "#7", "state": "머지됨", "source": "기계 상태"})])
        lines, rc = cp.epic_view("rm/roadmap.md", {"blocks": [b], "handoffs": [], "machine": None}, "R1")
        self.assertEqual(rc, 0)
        self.assertIn("  PR: feature/a #7 머지됨(기계 상태)", lines)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_approval.py 2>&1 | tail -3`
Expected: FAIL — `AttributeError: module 'roadmap_model' has no attribute 'approval_date'` 등.

- [ ] **Step 3: `roadmap_model.py` — 상수와 승인 줄 읽기**

`RECORD_HEADING = "## 지휘 기록"` 줄 바로 아래에 더한다(새 import · 새 `re.compile` 없음 — 정적 락과 §6 락):

```python
# 기본 브랜치 참조 — 상태 계산 · 화면 · 스위트 대조가 이 한 곳을 쓴다(계획 1 미룸: 두 스크립트에 겹쳤다).
DEFAULT_REF = "refs/remotes/origin/HEAD"
NO_DEFAULT = ("기본 브랜치를 알 수 없다 — origin/HEAD 가 없다. `git remote set-head origin --auto` 로 만든 뒤 "
              "다시 계산한다")
# `## 지휘 기록` 의 spec 승인 줄 — 지휘자가 `- spec 승인 · <YYYY-MM-DD> · 「<고른 선택지 원문>」` 로 쓴다.
APPROVAL_PREFIX = "- spec 승인 · "
APPROVAL_DENY = ("승인 대기", "승인 전", "승인 거절", "승인하지 않", "승인 안")


def approval_date(doc_text: str):
    """`## 지휘 기록` 의 spec 승인 날짜 가운데 가장 늦은 것. 절이 없거나 승인 줄이 없으면 None.
    정해진 꼴 밖의 손으로 쓴 줄도 읽는다 — 날짜와 「승인」 이 함께 있고 부정 구절(APPROVAL_DENY)이 없는 `- ` 줄.
    머리가 둘이면 FormatError(section_lines) — 깨진 문서를 「승인 없음」 으로 떨어뜨리지 않는다."""
    lines = section_lines(doc_text, RECORD_HEADING)
    dates = []
    for line in lines or []:
        if not line.startswith("- "):
            continue
        canonical = line.startswith(APPROVAL_PREFIX)
        if not canonical and ("승인" not in line or any(w in line for w in APPROVAL_DENY)):
            continue
        found = DATE_RE.search(line[len(APPROVAL_PREFIX):] if canonical else line)
        if found:
            dates.append(found.group(0))
    return max(dates) if dates else None
```

(`section_lines` · `DATE_RE` 는 같은 파일에 이미 있다. `DATE_RE` 가 `section_lines` 보다 위에 정의돼 있는지 보고, 아니면 이 함수를 `section_lines` 정의 아래로 옮긴다.)

- [ ] **Step 4: `roadmap_status.py` — 상수 import · 승인 근거**

1. `DEFAULT_REF = "refs/remotes/origin/HEAD"` 와 `NO_DEFAULT = (…)` 두 정의(두 줄 문자열 포함)를 지우고, `from roadmap_model import (` 목록에 `DEFAULT_REF, NO_DEFAULT, approval_date,` 를 더한다.
2. `progress` 위에 더한다:

```python
def approval_of(git: Git, tip: str, specs: list):
    """(가장 늦은 spec 승인 날짜 | None, 읽기 불가 사유 | None) — 그 브랜치 설계문서들의 `## 지휘 기록`."""
    dates = []
    for s in specs:
        try:
            d = approval_date(git.blob(tip, s) or "")
        except FormatError as exc:
            return None, "지휘 기록 읽기 불가 — %s(%s)" % (exc, s)
        if d:
            dates.append(d)
    return (max(dates) if dates else None), None
```

3. `progress` 의 `if not plans:` 갈래를 바꾼다:

```python
    if not plans:
        when, why = approval_of(git, tip, specs)
        block["approved"] = when
        if why:
            return "설계 중", "spec 있음 · " + why, specs, []
        if when:
            return "설계 중", "spec 승인됨(%s) · 계획 없음" % when, specs, []
        return "설계 중", "spec 있음", specs, []
```

그리고 `progress` 첫 줄(`specs = find_specs(…)`) 바로 아래에 `block.setdefault("approved", None)` 을 둔다(spec 이 없거나 계획이 있는 갈래도 칸을 갖게).
4. `compute` 의 `b.update(stage=None, …)` 에 `approved=None` 을 더한다.

- [ ] **Step 5: `control_plane.py` — 상수 import · 머지된 에픽 PR**

1. `NO_DEFAULT = (…)`(61줄 근처) · `DEFAULT_REF = "refs/remotes/origin/HEAD"`(330줄 근처) 정의를 지우고 `from roadmap_model import BLOCK_ID_RE, FormatError` 를 `from roadmap_model import BLOCK_ID_RE, DEFAULT_REF, NO_DEFAULT, FormatError` 로 바꾼다.
2. `overlay` 위에 더한다:

```python
def merged_prs(b: dict, prs: dict, gh_lookup) -> list:
    """머지된 에픽의 브랜치마다 PR — 기계 상태 캐시가 먼저, 없으면 gh. 머지 커밋 메시지는 해석하지 않는다(호스트마다 다르다)."""
    out = []
    for s in b.get("branch_states") or []:
        br = s["branch"]
        if br in prs:
            row = prs[br]
            out.append((br, {"number": row["번호"], "state": row["상태"], "source": "기계 상태"}))
        elif gh_lookup is None:
            out.append((br, _pr_unknown("기계 상태에 없고 gh 가 없다")))
        else:
            out.append((br, gh_lookup(br)))
    return out
```

3. `overlay` 의 서명을 `def overlay(items, machine_lookup, gh_lookup, use_gh: bool, read=read_capped, deadline=None, focus=None) -> None:` 로 바꾸고, 블록 고리 안 `if use_gh and (stage in IMPL_STAGES or partial or stage == "머지됨"):` 줄 바로 앞(그 줄과 같은 들여쓰기)에 더한다:

```python
            if use_gh and focus is not None and b.get("id") == focus and stage == "머지됨":
                b["merged_prs"] = merged_prs(b, prs, gh_lookup)
```

4. `gather` 의 서명을 `def gather(cwd: str, arg, deadline: Deadline, ctx: dict, use_gh: bool = True, focus=None):` 로 바꾸고 그 안의 `overlay(…, deadline=deadline)` 호출에 `focus=focus` 를 더한다. `cmd_show` 의 `v = gather(os.getcwd(), arg, Deadline(SHOW_BUDGET), {})` 를 `v = gather(os.getcwd(), arg, Deadline(SHOW_BUDGET), {}, focus=epic)` 으로 바꾼다.
5. `epic_view` 의 `if b.get("pr"):` 두 줄 바로 아래에 더한다:

```python
    if b.get("merged_prs"):
        out.append(clean("  PR: " + " · ".join("%s %s" % (br, pr_text(pr)) for br, pr in b["merged_prs"])))
```

- [ ] **Step 6: `check_bundle_coverage.py` — `--impl` 이 읽은 로드맵을 말한다(결정 G)**

`check_impl` 의 `rule = "로드맵의 에픽 또는 PR 번호(#숫자)"` 를 `rule = "로드맵의 에픽 또는 PR 번호(#숫자) — 작업 트리의 로드맵으로 쟀다"` 로 바꾼다. `tests/test_coverage_scope.py` 의 두 기대 문자열(100 · 105줄 근처 `(받는 곳 규칙: 로드맵의 에픽 또는 PR 번호(#숫자))`)도 같은 글로 바꾼다.

- [ ] **Step 7: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_approval.py plugins/spec-distill/tests/test_coverage_scope.py plugins/spec-distill/tests/test_control_plane.py plugins/spec-distill/tests/test_roadmap_model.py 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2`
Expected: 모두 OK · 실패 0. `test_roadmap_status.sh` 의 정적 락(쓰기 · subprocess · import)과 G1 의 「spec 있음」 근거가 그대로 통과해야 한다. `test_epic_view_shows_merged_prs` 가 `KeyError` 를 내면 `epic_view` 를 고치지 말고 그 테스트의 블록 사전을 `tests/test_control_plane.py` 의 블록 픽스처 모양(빠진 칸)에 맞춘다.

결정 F(상태줄)는 권장대로면 코드 변경이 없다 — `show` 의 「기본 브랜치를 알 수 없다」 줄은 이미 있다(`cmd_show` 의 `shown_error`). 사용자가 대안을 고르면 이 Task 에 `statusline_text` 한 갈래와 그 테스트를 더한다.

- [ ] **Step 8: 커밋**

```bash
git commit -m "feat(spec-distill): 상태 계산이 spec 승인 줄을 읽고 머지된 에픽의 PR 을 보인다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/scripts/roadmap_status.py plugins/spec-distill/scripts/control_plane.py plugins/spec-distill/scripts/check_bundle_coverage.py plugins/spec-distill/tests/test_roadmap_approval.py plugins/spec-distill/tests/test_coverage_scope.py
git show --stat HEAD   # 파일 여섯
```

---

### Task 3: 스위트 대조 `merge_check.py` · 공유본 링크 (AC18)

M8(Task 1)의 결론이 이 Task 의 전제다 — `run … per-unit` 의 표준 오류에 러너 출력이 실리고, 배정에 모든 파일을 넣으면 테스트 아닌 파일이 `unclaimed` 로 남는다. 다르면 시작하지 않는다(Task 1 멈출 조건).

**Files:**
- Create: `plugins/spec-distill/scripts/merge_check.py`
- Create (상대 링크 넷): `plugins/spec-distill/scripts/run-test-selection.sh` · `diff-test-results.py` · `compute-test-scope-candidates.sh` · `resolve-baseline.sh` → `../../../shared/test-selection/<이름>`
- Modify: `plugins/spec-distill/scripts/repo_defaults.py` (상수 둘)
- Create: `plugins/spec-distill/tests/test_merge_check.sh`

**Interfaces:**
- Consumes: `roadmap_model.DEFAULT_REF` · `NO_DEFAULT` · `frontmatter` · `unquote`(Task 2), `repo_defaults.repo_settings`, `conductor_state.machine_dir`, `state_path.state_root`.
- Produces: `repo_defaults.WORKTREE_HOME = ".claude/worktrees/"`(하니스가 worktree 를 두는 폴더 — 외부 도구 기본값) · `repo_defaults.MERGE_CHECK_DIR = "merge-check"`(기계 상태 폴더 안 하위 폴더).
- Produces: CLI `merge_check.py run --roadmap <로드맵 레포 상대경로> --branch <브랜치> [--keep-merged] [--no-fetch] [--root <레포>]`. 종료 코드 `0` 새 실패 없음 · `1` 새 실패 있음 · `3` 검사 불가 · `4` 새 실패는 없으나 이름 대조 불가 단위가 있음 · `5` 다른 대조가 도는 중 · `6` 테스트 명령을 모른다(묻는 자리) · `7` 스위트 대조 없음. 첫 줄은 늘 `[spec-distill] 스위트 대조 — …`. `--keep-merged` 면 `남긴 사본: <절대경로>` 줄 — 지휘자가 기계 상태 `## 자원` 에 「합친 사본」 으로 적는다(Task 5).
- Produces: `merge_check.names_in(text: str, pattern: str | None) -> tuple[set, str | None]` — Task 13 이 쓴다.

- [ ] **Step 1: 링크와 상수**

```bash
for n in run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh; do
  ln -s "../../../shared/test-selection/$n" "plugins/spec-distill/scripts/$n"
done
git add plugins/spec-distill/scripts/run-test-selection.sh plugins/spec-distill/scripts/diff-test-results.py plugins/spec-distill/scripts/compute-test-scope-candidates.sh plugins/spec-distill/scripts/resolve-baseline.sh
git ls-files -s plugins/spec-distill/scripts/run-test-selection.sh   # 120000
```

`repo_defaults.py` 의 `CONDUCTOR_DIR = "conductor"` 줄 아래에 더한다:

```python
WORKTREE_HOME = ".claude/worktrees/"   # 하니스(EnterWorktree)가 worktree 를 두고 옮겨 갈 수 있는 폴더 — 외부 도구 기본값
MERGE_CHECK_DIR = "merge-check"        # 기계 상태 폴더 안의 스위트 대조 잠금 · 일회용 사본 자리
```

모듈 머리 독스트링의 「외부 도구가 정한 기본 경로(…)」 괄호에 「하니스의 worktree 폴더」 를 더한다.

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_merge_check.sh`:

```bash
#!/usr/bin/env bash
# R5 AC18 — merge_check.py: 합친 사본 · 잠금 · 단위 짝짓기 · 이름 대조 · 테스트 명령 · 강등.
# 버릴 레포(기본 브랜치 trunk)마다 원격(bare) · 로드맵 frontmatter · 에픽 브랜치를 만든다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_merge_check.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
MC="$ROOT/plugins/spec-distill/scripts/merge_check.py"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PYTHONDONTWRITEBYTECODE=1
RM="plan/rm/roadmap.md"

for n in run-test-selection.sh diff-test-results.py compute-test-scope-candidates.sh resolve-baseline.sh; do
  assert_eq "$(git -C "$ROOT" ls-files -s -- "plugins/spec-distill/scripts/$n" | awk '{print $1}')" "120000" "${n} 는 링크다"
  assert_eq "$(readlink "$ROOT/plugins/spec-distill/scripts/$n")" "../../../shared/test-selection/$n" "${n} 는 공유본으로 가는 상대 링크다"
done

g() { git -C "$W" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "$@"; }
mkrepo() {  # mkrepo <이름> [frontmatter 추가 줄] — 원격 trunk · 로드맵 · 첫 커밋. W 를 그 클론으로.
  local o="$T/$1.git"
  git init -q --bare -b trunk "$o"
  W="$T/$1"; git clone -q "$o" "$W" 2>/dev/null
  g checkout -q -b trunk 2>/dev/null || true
  mkdir -p "$W/plan/rm"
  printf -- '---\ntype: roadmap\n%b---\n\n# r\n' "${2:-}" > "$W/$RM"
}
put() { mkdir -p "$(dirname "$W/$1")"; printf '%s\n' "$2" > "$W/$1"; }
push_base() { g add -A && g commit -qm base && g push -q origin trunk && g remote set-head origin --auto >/dev/null; }
branch_with() {  # branch_with <브랜치> — 지금 작업 트리 변경을 그 브랜치에 커밋하고 trunk 로 돌아온다
  g checkout -q -b "$1" && g add -A && g commit -qm "$1" && g checkout -q trunk
}
mc() { (cd "$W" && python3 "$MC" run --roadmap "$RM" --no-fetch "$@" 2>&1); }

# 1 — pytest: 양쪽 다 빨간 파일 안의 새 실패를 이름으로 가른다
if python3 -m pytest --version >/dev/null 2>&1; then
  mkrepo py; put pytest.ini '[pytest]'
  put tests/test_x.py $'def test_a():\n    assert 1 == 2\n\ndef test_b():\n    assert True'
  push_base
  put tests/test_x.py $'def test_a():\n    assert 1 == 2\n\ndef test_b():\n    assert True\n\ndef test_c():\n    assert 0'
  branch_with feature/py
  out="$(mc --branch feature/py)"; rc=$?
  assert_eq "$rc" "1" "pytest: 양쪽 빨간 파일 안의 새 실패 → rc 1"
  assert_contains "$out" "tests/test_x.py::test_c" "pytest: 새 실패 이름"
  assert_contains "$out" "양쪽 다 있는 실패 1개: tests/test_x.py: tests/test_x.py::test_a" "pytest: 원래 있던 실패는 양쪽 다 있는 실패다"
  assert_eq "$(git -C "$W" worktree list | wc -l | tr -d ' ')" "1" "pytest: 일회용 사본을 지웠다"
else
  no "pytest 가 없어 1번 장면을 돌리지 못했다 — 이 기계에 pytest 를 깔고 다시 돈다"
fi

# 2 — unittest: 초록이던 테스트가 빨개진다(단위 수준 새 실패) · 이름도 낸다
mkrepo ut; put tests/__init__.py ''
put tests/test_y.py $'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 1)'
push_base
put tests/test_y.py $'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        self.assertEqual(1, 2)'
branch_with feature/ut
out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "1" "unittest: 새 실패 → rc 1"
assert_contains "$out" "test_a" "unittest: 새 실패 이름"

# 3 — 실행 비트 셸: 양쪽 빨강 · ✗ 줄로 이름 대조
mkrepo sh
put tests/t.sh $'#!/usr/bin/env bash\necho "  ✗ 하나"\nexit 1'; chmod +x "$W/tests/t.sh"
push_base
put tests/t.sh $'#!/usr/bin/env bash\necho "  ✗ 하나"\necho "  ✗ 둘"\nexit 1'; chmod +x "$W/tests/t.sh"
branch_with feature/sh
out="$(mc --branch feature/sh)"; rc=$?
assert_eq "$rc" "1" "셸: 양쪽 빨간 단위 안의 새 실패 → rc 1"
assert_contains "$out" "둘" "셸: 새 실패 이름(✗ 줄)"

# 4 — test_command(node --test tap) · 고쳐짐도 보인다
mkrepo nd 'test_command: node --test --test-reporter=tap tests/a.test.js\n'
put tests/a.test.js $'const t = require("node:test"); const a = require("node:assert");\nt("one", () => a.equal(1, 2));\nt("two", () => a.equal(1, 1));'
push_base
put tests/a.test.js $'const t = require("node:test"); const a = require("node:assert");\nt("one", () => a.equal(1, 1));\nt("two", () => a.equal(1, 2));'
branch_with feature/nd
out="$(mc --branch feature/nd)"; rc=$?
assert_eq "$rc" "1" "test_command: 새 실패 → rc 1"
assert_contains "$out" "two" "test_command: 새 실패 이름(tap not ok)"
assert_contains "$out" "기본 브랜치에만 있는 실패(고쳐짐) 1개: one" "test_command: 기본 브랜치에만 있는 실패(고쳐짐)를 이름으로 보인다"

# 5 — 이름을 못 뽑는 명령: 양쪽 다 빨강이면 빈 집합끼리 같다고 하지 않는다
mkrepo nn 'test_command: bash -c "exit 1"\n'; put a.txt a; push_base; put b.txt b; branch_with feature/nn
out="$(mc --branch feature/nn)"; rc=$?
assert_eq "$rc" "4" "이름 없는 명령 · 양쪽 빨강 → rc 4"
assert_contains "$out" "이름 대조 불가 — 단위 수준만" "이름 없는 명령: 단위 수준 공시"

# 6 — test_failure_pattern 이 이긴다
mkrepo pt 'test_command: bash run.sh\ntest_failure_pattern: "^BAD: (.+)$"\n'
put run.sh $'echo "BAD: alpha"\nexit 1'; push_base
put run.sh $'echo "BAD: alpha"\necho "BAD: beta"\nexit 1'; branch_with feature/pt
out="$(mc --branch feature/pt)"; rc=$?
assert_eq "$rc" "1" "test_failure_pattern: 새 이름 → rc 1"
assert_contains "$out" "beta" "test_failure_pattern: 새 이름 beta"

# 7 — 테스트 없음 → 7 · 러너 없는 테스트 파일 → 6
mkrepo none; put README.md r; push_base; put x.txt x; branch_with feature/none
out="$(mc --branch feature/none)"; rc=$?
assert_eq "$rc" "7" "테스트 없음 → rc 7"
assert_contains "$out" "스위트 대조 없음" "테스트 없음 공시"
mkrepo ask; put tests/t.sh $'#!/usr/bin/env bash\nexit 0'; push_base; put x.txt x; branch_with feature/ask
out="$(mc --branch feature/ask)"; rc=$?
assert_eq "$rc" "6" "실행 비트 없는 셸 테스트만 → rc 6(묻는 자리)"
assert_contains "$out" "test_command" "묻는 자리: 로드맵 frontmatter 키를 말한다"

# 8 — 잠금: 살아 있는 주인이면 5, 죽은 주인이면 풀고 간다
LOCKD="$(cd "$T/ut" && python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import conductor_state as cs, repo_defaults as r, state_path as s; print(cs.machine_dir(s.state_root(), sys.argv[2]) / r.MERGE_CHECK_DIR / "lock")' "$ROOT/plugins/spec-distill/scripts" "$RM")"
mkdir -p "$LOCKD"; printf '%s x\n' "$$" > "$LOCKD/owner"
W="$T/ut"; out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "5" "살아 있는 잠금 → rc 5"
printf '999999 x\n' > "$LOCKD/owner"
out="$(mc --branch feature/ut)"; rc=$?
assert_contains "$out" "주인 없는 잠금을 풀었다" "죽은 주인의 잠금은 알리고 푼다"
assert_eq "$rc" "1" "잠금을 푼 뒤 대조가 돈다"
[ -d "$LOCKD" ] && no "대조가 끝난 뒤 잠금이 남았다" || ok "대조가 끝나면 잠금을 푼다"

# 9 — 합칠 수 없음 · 기본 브랜치 모름 · 사본 남기기
mkrepo cf; put a.txt one; push_base
g checkout -q -b feature/cf; put a.txt two; g add -A; g commit -qm cf; g checkout -q trunk
put a.txt three; g add -A; g commit -qm main3; g push -q origin trunk
out="$(mc --branch feature/cf)"; rc=$?
assert_eq "$rc" "3" "충돌 → rc 3"
assert_contains "$out" "합칠 수 없다 — 충돌 파일: a.txt" "충돌 파일을 보인다"
W="$T/ut"; out="$(mc --branch feature/ut --keep-merged)"; rc=$?
kept="$(printf '%s\n' "$out" | sed -n 's/^남긴 사본: //p')"
[ -n "$kept" ] && [ -d "$kept" ] && ok "사본 남기기: 경로가 있다" || no "사본 남기기: 남긴 사본이 없다"
assert_eq "$(git -C "$W" worktree list | wc -l | tr -d ' ')" "2" "사본 남기기: 합친 사본 하나만 남는다"
g remote set-head origin -d
out="$(mc --branch feature/ut)"; rc=$?
assert_eq "$rc" "3" "origin/HEAD 없음 → rc 3"
assert_contains "$out" "origin/HEAD 가 없다" "기본 브랜치 모름 사유"

# 10 — names_in: 알려진 모양 · 모양 없음
NAMES="$(python3 -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
for t in ("FAILED a.py::t1 - x", "FAIL: t2 (m.C)", "not ok 3 - t3", "  ✗ t4", "nothing here"):
    print(sorted(m.names_in(t, None)[0]), m.names_in(t, None)[1])' "$ROOT/plugins/spec-distill/scripts")"
assert_eq "$NAMES" "$(printf "%s\n" "['a.py::t1'] pytest" "['t2 (m.C)'] unittest" "['t3'] tap" "['t4'] ✗ 표시" "[] None")" "names_in: 알려진 모양 넷과 모양 없음"

finish
```

- [ ] **Step 3: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_merge_check.sh && bash plugins/spec-distill/tests/test_merge_check.sh 2>&1 | tail -5`
Expected: 링크 단언은 통과, 나머지는 `merge_check.py` 가 없어 실패.

- [ ] **Step 4: `merge_check.py` 를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""merge_check.py — 머지 전 스위트 대조(R5 AC18).

합친 사본(origin 기본 브랜치 + 에픽 브랜치)과 기준선 사본(origin 기본 브랜치)을 일회용 worktree 로 만들고,
그 레포의 스위트를 두 사본에서 돌려 실패를 단위와 «이름» 으로 대조한다. 동시 실행은 잠금으로 막는다.

명령줄:
  merge_check.py run --roadmap <로드맵 레포 상대경로> --branch <브랜치> [--keep-merged] [--no-fetch] [--root <레포>]

무엇을 돌리나: 기본 브랜치의 로드맵 frontmatter `test_command` 가 있으면 그것 — 실패 이름은 `test_failure_pattern`
(정규식, 묶음이 있으면 첫 묶음) 또는 알려진 모양. 없으면 이 폴더의 공유본 링크로 러너 탐지 · 배정 · 단위 실행 ·
귀속을 하고, 양쪽 다 빨간 단위는 그 단위의 러너 출력에서 실패 이름을 뽑아 대조한다.

종료 코드: 0 새 실패 없음 · 1 새 실패 있음 · 3 검사 불가 · 4 새 실패는 없으나 이름 대조 불가 단위가 있다 ·
5 다른 대조가 도는 중 · 6 테스트 명령을 모른다(사용자에게 묻는다) · 7 스위트 대조 없음(테스트 없음).
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
from roadmap_model import DEFAULT_REF, NO_DEFAULT, frontmatter, unquote  # noqa: E402
from state_path import state_root  # noqa: E402

SELECT = HERE / "run-test-selection.sh"
DIFF = HERE / "diff-test-results.py"
SCOPE = HERE / "compute-test-scope-candidates.sh"
KNOWN_SHAPES = (
    ("pytest", re.compile(r"^FAILED (\S+)", re.M)),
    ("unittest", re.compile(r"^(?:FAIL|ERROR): (.+)$", re.M)),
    ("tap", re.compile(r"^\s*not ok \d+ - (.+)$", re.M)),
    ("✗ 표시", re.compile(r"^\s*✗ (.+)$", re.M)),
)
NEW, FIXED = ("NEW_REGRESSION", "NEW_TEST_RED"), ("FIXED",)
LOCK_YOUNG = 60  # 주인 기록 전 잠금은 이 초 동안 바쁜 것으로 본다


class Stop(Exception):
    def __init__(self, rc: int, msg: str):
        super().__init__(msg)
        self.rc = rc


def git(cwd, *args):
    p = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout.strip(), p.stderr.strip()


def stamp() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def names_in(text: str, pattern=None):
    """(실패 이름 집합, 쓴 모양). 모양이 하나도 안 맞으면 (빈 집합, None) — 「이름 대조 불가」 의 근거다."""
    shapes = [("test_failure_pattern", re.compile(pattern, re.M))] if pattern else list(KNOWN_SHAPES)
    for label, rx in shapes:
        found = set()
        for m in rx.finditer(text):
            found.add((m.group(1) if rx.groups else m.group(0)).strip())
        if found:
            return found, label
    return set(), None


# ── 잠금 ─────────────────────────────────────────────────────────────────────

def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def take_lock(d: Path) -> None:
    d.parent.mkdir(parents=True, exist_ok=True)
    for _try in (1, 2):
        try:
            d.mkdir()
        except FileExistsError:
            owner_file = d / "owner"
            owner = owner_file.read_text(encoding="utf-8").strip() if owner_file.is_file() else ""
            head = owner.split(" ", 1)[0]
            pid = int(head) if head.isdigit() else None
            young = (time.time() - d.stat().st_mtime) < LOCK_YOUNG
            if (pid is not None and _alive(pid)) or (pid is None and young):
                raise Stop(5, "다른 스위트 대조가 도는 중이다(잠금 %s · 주인 %s) — 끝난 뒤 다시 돈다" % (d, owner or "기록 전"))
            print("[spec-distill] 주인 없는 잠금을 풀었다(%s · %s)" % (d, owner or "주인 기록 없음"))
            shutil.rmtree(str(d), ignore_errors=True)
            continue
        (d / "owner").write_text("%d %s\n" % (os.getpid(), stamp()), encoding="utf-8")
        return
    raise Stop(5, "잠금을 잡지 못했다: %s" % d)


def drop_lock(d: Path) -> None:
    owner_file = d / "owner"
    owner = owner_file.read_text(encoding="utf-8").split(" ", 1)[0] if owner_file.is_file() else ""
    if owner == str(os.getpid()):
        shutil.rmtree(str(d), ignore_errors=True)


# ── 사본 ─────────────────────────────────────────────────────────────────────

def make_copies(root: Path, work: Path, branch: str):
    rc, base_sha, _e = git(root, "rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if rc:
        raise Stop(3, NO_DEFAULT)
    tip = None
    for ref in ("refs/heads/" + branch, "refs/remotes/origin/" + branch):
        rc, out, _e = git(root, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
        if rc == 0:
            tip = out
            break
    if tip is None:
        raise Stop(3, "브랜치를 찾지 못했다: %s" % branch)
    base, merged = work / "base", work / "merged"
    for d in (base, merged):
        rc, _o, err = git(root, "worktree", "add", "--detach", str(d), base_sha)
        if rc:
            raise Stop(3, "사본을 만들지 못했다(%s): %s" % (d, err))
    rc, _o, err = git(merged, "-c", "user.name=merge-check", "-c", "user.email=merge-check@invalid",
                      "-c", "commit.gpgsign=false", "merge", "--no-ff", "--no-edit", tip)
    if rc:
        _r, files, _e = git(merged, "diff", "--name-only", "--diff-filter=U")
        git(merged, "merge", "--abort")
        raise Stop(3, "합칠 수 없다 — 충돌 파일: %s" % (" · ".join(files.split()) or err))
    _r, merged_sha, _e = git(merged, "rev-parse", "HEAD")
    return base, merged, base_sha, tip, merged_sha


def drop_copy(root: Path, d: Path, work: Path) -> None:
    """일회용 사본만 지운다 — work 밖 경로는 건드리지 않는다. 테스트가 남긴 파일 때문에 rmtree 뒤 prune."""
    if work not in d.parents:
        return
    shutil.rmtree(str(d), ignore_errors=True)
    git(root, "worktree", "prune")


# ── 테스트 명령 ──────────────────────────────────────────────────────────────

def run_command(cmd: str, tree: Path, tmp: Path):
    tmp.mkdir(parents=True, exist_ok=True)
    p = subprocess.run(["bash", "-c", cmd], cwd=str(tree), env=dict(os.environ, TMPDIR=str(tmp)),
                       capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout + "\n" + p.stderr


def compare_command(cmd: str, pattern, base: Path, merged: Path, work: Path) -> dict:
    res = {"new": [], "fixed": [], "both": [], "unit_only": [], "notes": ["무엇을 돌렸나: test_command(`%s`)" % cmd]}
    b_rc, b_out = run_command(cmd, base, work / "tmp-base")
    m_rc, m_out = run_command(cmd, merged, work / "tmp-merged")
    if 127 in (b_rc, m_rc):
        raise Stop(3, "테스트 명령을 실행하지 못했다(rc 127): %s" % cmd)
    b_names, _s = names_in(b_out, pattern)
    m_names, shape = names_in(m_out, pattern)
    named = (b_rc == 0 or b_names) and (m_rc == 0 or m_names)
    if named:
        res["new"] = sorted(m_names - b_names)
        res["fixed"] = sorted(b_names - m_names)
        res["both"] = sorted(b_names & m_names)
        if shape:
            res["notes"].append("실패 이름 모양: %s" % shape)
        if m_rc != 0 and not res["new"] and not m_names - b_names and b_rc == 0:
            res["new"].append("(test_command) 전체 — 종료 코드만 실패")
    elif m_rc != 0 and b_rc == 0:
        res["new"].append("(test_command) 전체 — 이름 대조 불가 — 단위 수준만")
    elif m_rc != 0:
        res["unit_only"].append("(test_command) — 양쪽 다 실패, 이름을 뽑지 못했다")
    elif b_rc != 0:
        res["fixed"].append("(test_command) 전체")
    return res


# ── 탐지 경로(공유본) ────────────────────────────────────────────────────────

def select(*args, stdin=None, tmp=None):
    env = dict(os.environ, TMPDIR=str(tmp)) if tmp else None
    p = subprocess.run(["bash", str(SELECT), *args], input=stdin, capture_output=True, encoding="utf-8",
                       errors="replace", env=env)
    return p.returncode, p.stdout, p.stderr


def test_file_count(tree: Path):
    p = subprocess.run(["bash", str(SCOPE), "--total", "--tree", "HEAD"], cwd=str(tree), capture_output=True,
                       encoding="utf-8", errors="replace")
    out = p.stdout.strip()
    return int(out) if p.returncode == 0 and out.isdigit() else None


def _assign_rows(path: Path):
    rows = []
    for line in path.read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            cells = line.split("\t")
            if len(cells) == 3:
                rows.append(tuple(cells))
    return rows


def assignment(tree: Path, work: Path):
    _rc, files, _e = git(tree, "ls-files")
    first = work / "all.assign"
    rc, _o, err = select("assign", str(tree), str(first), stdin=files + "\n")
    if rc:
        raise Stop(3, "배정이 실패했다: %s" % err.strip()[-300:])
    claimed = [u for u, r, _g in _assign_rows(first) if r != "unclaimed"]
    final = work / "units.assign"
    rc, _o, err = select("assign", str(tree), str(final), stdin="\n".join(claimed) + "\n")
    if rc:
        raise Stop(3, "배정이 실패했다: %s" % err.strip()[-300:])
    return final, [r for r in _assign_rows(final) if r[1] != "unclaimed"]


def run_side(tree: Path, side: str, rows: list, work: Path) -> dict:
    """{(러너, 단위): 그 실행의 표준 오류}. 행 파일은 공유본이 쓴다."""
    logs, rows_dir = {}, work / "rows"
    rows_dir.mkdir(exist_ok=True)
    for runner in sorted({r for _u, r, _g in rows}):
        units = [u for u, r, _g in rows if r == runner]
        gran = next(g for _u, r, g in rows if r == runner)
        target = rows_dir / (("baseline-%s.tsv" % runner) if side == "base" else ("head-%s-i1.tsv" % runner))
        groups, mode = ([["BULK"]], "bulk") if gran == "bulk" else ([[u] for u in units], "per-unit")
        for grp in groups:
            rc, _o, err = select("run", str(tree), runner, mode, str(target), *grp, tmp=work / ("tmp-" + side))
            if rc == 2:
                raise Stop(3, "단위 실행이 실패했다(%s %s): %s" % (runner, grp[0], err.strip()[-300:]))
            logs[(runner, grp[0])] = err
    return logs


def parse_attributions(text: str) -> list:
    out, runner, unit = [], None, None
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- runner: "):
            runner = s[len("- runner: "):]
        elif s.startswith("- unit: "):
            unit = json.loads(s[len("- unit: "):])
        elif s.startswith("verdict: ") and unit is not None:
            out.append((runner, unit, s[len("verdict: "):]))
            unit = None
    return out


def compare_detected(base: Path, merged: Path, base_sha: str, merged_sha: str, work: Path) -> dict:
    rc, out, err = select("detect", str(merged))
    if rc:
        raise Stop(3, "러너 탐지가 실패했다: %s" % err.strip()[-300:])
    runners = [l.split(": ", 1)[1] for l in out.splitlines() if l.startswith("runner: ")]
    count = test_file_count(merged)
    final, rows = assignment(merged, work) if runners else (None, [])
    if not rows:
        if count:
            raise Stop(6, "테스트로 보이는 파일 %d개를 돌릴 러너를 모른다 — 테스트 명령을 정해 주면 로드맵 "
                          "frontmatter `test_command` 로 올린다" % count)
        raise Stop(7, "스위트 대조 없음 — 이 레포에서 테스트를 찾지 못했다. 통합 리뷰만 한다")
    res = {"new": [], "fixed": [], "both": [], "unit_only": [],
           "notes": ["무엇을 돌렸나: 탐지한 러너 %s" % " · ".join(sorted({r for _u, r, _g in rows}))]}
    files = [u for u, _r, g in rows if g == "file"]
    if count is not None and len(files) < count and not any(g == "bulk" for _u, _r, g in rows):
        res["notes"].append("테스트로 보이는 파일 %d개 중 %d개만 러너가 맡았다 — 나머지까지 돌리려면 "
                            "`test_command` 를 정한다(지휘자가 한 번 묻는다)" % (count, len(files)))
    b_logs = run_side(base, "base", rows, work)
    m_logs = run_side(merged, "merged", rows, work)
    p = subprocess.run([sys.executable, str(DIFF), "--assign", str(final), "--rows", str(work / "rows"),
                        "--iter", "1", "--baseline-commit", base_sha, "--head-commit", merged_sha],
                       capture_output=True, encoding="utf-8", errors="replace")
    if p.returncode:
        raise Stop(3, "귀속이 실패했다: %s" % p.stderr.strip()[-300:])
    for line in p.stdout.splitlines():
        if line.startswith("degrade_causes: ") and line != "degrade_causes: []":
            res["notes"].append("귀속 강등: %s" % line[len("degrade_causes: "):])
    for runner, unit, verdict in parse_attributions(p.stdout):
        b_names, _s = names_in(b_logs.get((runner, unit), ""))
        m_names, _s = names_in(m_logs.get((runner, unit), ""))
        if verdict in NEW:
            fresh = sorted(m_names - b_names)
            res["new"] += ["%s: %s" % (unit, n) for n in fresh] or ["%s — 이름 대조 불가 — 단위 수준만" % unit]
        elif verdict in FIXED:
            res["fixed"].append(unit)
        elif verdict == "PRE_EXISTING":
            if b_names and m_names:
                res["new"] += ["%s: %s" % (unit, n) for n in sorted(m_names - b_names)]
                res["fixed"] += ["%s: %s" % (unit, n) for n in sorted(b_names - m_names)]
                res["both"] += ["%s: %s" % (unit, n) for n in sorted(b_names & m_names)]
            else:
                res["unit_only"].append("%s — 양쪽 다 빨강, 이름을 뽑지 못했다" % unit)
        elif verdict in ("SILENT_DROP", "BASELINE_UNRUNNABLE"):
            res["unit_only"].append("%s — %s" % (unit, verdict))
    return res


# ── 보고 ─────────────────────────────────────────────────────────────────────

def report(res: dict) -> int:
    for note in res["notes"]:
        print("- " + note)
    for label, key in (("이 브랜치에만 있는 실패", "new"), ("기본 브랜치에만 있는 실패(고쳐짐)", "fixed"),
                       ("양쪽 다 있는 실패", "both")):
        print("- %s %d개%s" % (label, len(res[key]), (": " + " · ".join(res[key])) if res[key] else ""))
    if res["unit_only"]:
        print("- 이름 대조 불가 — 단위 수준만 %d개: %s" % (len(res["unit_only"]), " · ".join(res["unit_only"])))
    if res["new"]:
        print("판정: 새 실패 %d개 — 고치거나 이유를 적는다" % len(res["new"]))
        return 1
    if res["unit_only"]:
        print("판정: 새 실패는 찾지 못했으나 이름으로 가르지 못한 단위가 있다 — 위 줄을 사용자에게 보인다")
        return 4
    print("판정: 새 실패 없음")
    return 0


def run(root: Path, a) -> int:
    if not a.no_fetch:
        rc, _o, err = git(root, "fetch", "--quiet", "origin")
        if rc:
            print("[spec-distill] git fetch 가 실패했다 — 받아 둔 기본 브랜치로 대조한다(%s)" % err[-200:])
    rc, ref_name, _e = git(root, "rev-parse", "--abbrev-ref", DEFAULT_REF)
    if rc:
        raise Stop(3, NO_DEFAULT)
    rc, text, _e = git(root, "show", "%s:%s" % (DEFAULT_REF, a.roadmap))
    if rc:
        raise Stop(3, "기본 브랜치에서 로드맵을 읽지 못했다: %s" % a.roadmap)
    meta = frontmatter(text)
    settings = repo_defaults.repo_settings(meta)
    if settings["errors"]:
        raise Stop(3, "레포 설정이 깨졌다: %s" % settings["errors"][0])
    pattern = unquote(meta["test_failure_pattern"]) if "test_failure_pattern" in meta else None
    if pattern:
        try:
            re.compile(pattern)
        except re.error as exc:
            raise Stop(3, "test_failure_pattern 정규식이 깨졌다: %s" % exc)
    try:
        mdir = cs.machine_dir(state_root(str(root)), a.roadmap) / repo_defaults.MERGE_CHECK_DIR
    except cs.MachineError as exc:
        raise Stop(3, str(exc))
    lock = mdir / "lock"
    take_lock(lock)
    work = mdir / ("run-%s-%d" % (datetime.datetime.now().strftime("%Y%m%d%H%M%S"), os.getpid()))
    keep = None
    try:
        work.mkdir(parents=True)
        base, merged, base_sha, tip, merged_sha = make_copies(root, work, a.branch)
        print("[spec-distill] 스위트 대조 — %s(%s) 를 기본 브랜치 %s(%s) 에 합친 사본(%s)과 기본 브랜치 사본을 돌렸다"
              % (a.branch, tip[:8], ref_name, base_sha[:8], merged_sha[:8]))
        if settings["test_command"]:
            res = compare_command(settings["test_command"], pattern, base, merged, work)
        else:
            res = compare_detected(base, merged, base_sha, merged_sha, work)
        if a.keep_merged:
            keep = merged
        rc = report(res)
        if keep is not None:
            print("남긴 사본: %s" % keep)
        return rc
    finally:
        for d in (work / "base", work / "merged"):
            if d != keep:
                drop_copy(root, d, work)
        if keep is None:
            shutil.rmtree(str(work), ignore_errors=True)
        drop_lock(lock)


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="merge_check.py", description="머지 전 스위트 대조")
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("run")
    r.add_argument("--roadmap", required=True)
    r.add_argument("--branch", required=True)
    r.add_argument("--keep-merged", action="store_true")
    r.add_argument("--no-fetch", action="store_true")
    r.add_argument("--root")
    a = ap.parse_args(argv)
    top = a.root or git(os.getcwd(), "rev-parse", "--show-toplevel")[1]
    if not top:
        print("[spec-distill] 스위트 대조 — git 레포 안이 아니다")
        return 3
    try:
        return run(Path(top), a)
    except Stop as stop:
        print("[spec-distill] 스위트 대조 — %s" % stop)
        return stop.rc


if __name__ == "__main__":
    sys.exit(main())
```

주의: (1) `Stop` 이 `try` 밖(잠금 전)에서 나면 첫 줄이 `[spec-distill] 스위트 대조 — <사유>` 하나다. 잠금 뒤 `Stop` 은 `finally` 가 사본 · 잠금을 치운 뒤 `main` 이 그 줄을 낸다. (2) 일회용 사본은 우리가 만든 detached worktree 라 `rmtree` + `worktree prune` 으로 지운다 — 사용자 worktree 를 지우는 정리(Task 5)와 달리 `--force` 판단이 필요 없다. (3) `test_failure_pattern` 은 §6 의 레포 설정 키 목록에 없지만 §2 가 정한 선택 키다 — `repo_settings` 를 넓히지 않고 여기서만 읽는다.

- [ ] **Step 5: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_merge_check.sh 2>&1 | tail -5 && bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2 && bash shared/tests/test_python_floor.sh 2>&1 | tail -2 && python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py 2>&1 | tail -2 && bash shared/tests/test_test_selection_bundle.sh 2>&1 | tail -2`
Expected: 모두 실패 0. 9 장면 가운데 하나가 M8 과 다르게 굴면(예: pytest 요약 줄이 `-q` 에서 안 나온다) 기대를 바꾸지 말고 `names_in` 의 모양 · `run_side` 를 고친다.

- [ ] **Step 6: 커밋**

```bash
git commit -m "feat(spec-distill): 머지 전 스위트 대조 merge_check — 공유본으로 단위를 짝짓고 실패 이름으로 가른다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/merge_check.py plugins/spec-distill/scripts/run-test-selection.sh plugins/spec-distill/scripts/diff-test-results.py plugins/spec-distill/scripts/compute-test-scope-candidates.sh plugins/spec-distill/scripts/resolve-baseline.sh plugins/spec-distill/scripts/repo_defaults.py plugins/spec-distill/tests/test_merge_check.sh
git show --stat HEAD   # 파일 일곱
```

---
### Task 4: 기계 상태 쓰기 · 표지 · 시작 승인 · 로드맵 찾기 — `conductor_ledger.py` 의 뼈대 (AC15 의 기계 몫 · AC17 · AC41 의 표지 · 결정 B)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_state.py` (`SECTIONS` 에 절 하나)
- Create: `plugins/spec-distill/scripts/conductor_ledger.py`
- Create: `plugins/spec-distill/tests/test_conductor_ledger.py`
- Modify(필요할 때만): `plugins/spec-distill/tests/test_conductor_state.py` · `test_control_plane.py` — 빈 기계 상태의 렌더 글 전체를 비교하는 단언이 있으면 새 절 머리를 기대에 더한다

**Interfaces:**
- Consumes: `conductor_state.{machine_path, machine_dir, load, save, acquire, takeover, release, holder, MachineError, COLUMNS, SEP}`, `roadmap_model.{DEFAULT_REF, NO_DEFAULT, frontmatter, unquote}`(Task 2), `state_path.state_root`.
- Produces: `conductor_state.SECTIONS` 끝에 `("시작 승인", ("세션", "때", "규모"))` — `규모` 가 마지막 칸이라 ` · ` 를 담을 수 있다.
- Produces: `conductor_ledger.py` 모듈 함수 — `git(cwd, *args) -> (rc, out, err)` · `top(cwd=None) -> Path` · `now() -> str`(`YYYY-MM-DD HH:MM`) · `class Fail(Exception)`(`.rc`) · `mpath(root, roadmap) -> Path` · `split_cells(section, text) -> dict` · `scale_check(rows, session, scale) -> tuple[bool, str]`. 하위 명령 표 `COMMANDS = {이름: (함수, 인자 정의 함수)}` — 뒤 Task 가 여기에 더한다.
- Produces: CLI(모두 `--root <레포>` 선택, 없으면 cwd 의 git 최상위)
  - `roadmaps` — 기본 브랜치에서 git 이 추적하는 `.md` 가운데 frontmatter `type: roadmap` 이고 끝나지 않은 블록이 있는 것. 줄마다 `<경로><탭><끝나지 않은 에픽 수 | 검사 불가>`. rc 0 · 2 없음 · 3 기본 브랜치 모름.
  - `claim --roadmap <r> --session <s>` — rc 0 `acquired` · `held` / rc 5 다른 세션이 쥠(그 세션 id 와 「읽기 전용으로 보인다」).
  - `takeover --roadmap <r> --session <s>` · `release --roadmap <r> --session <s>`.
  - `add --roadmap <r> --session <s> --section <절> --cells "<칸1> · <칸2> …"` · `drop --roadmap <r> --session <s> --section <절> --where <칸>=<값>`(rc 1 맞는 행 없음).
  - `approval --roadmap <r> --session <s> --scale "<규모 줄>"` — rc 0 `공시만 — …` · rc 1 `승인 필요 — <이유>`. `approve` — 그 세션의 행을 바꿔 적는다.
  - 표지가 이 세션 것이 아니면 쓰는 명령은 rc 5 와 `읽기 전용 — 표지를 쥔 세션: <id>`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_conductor_ledger.py`:

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_ledger.py — 기계 상태 쓰기 · 표지 · 시작 승인 · 로드맵 찾기(R5 계획 3 Task 4). 뒤 Task 가 클래스를 더한다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py
"""
from __future__ import annotations

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from contextlib import redirect_stdout
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import conductor_ledger as L  # noqa: E402
import conductor_state as cs  # noqa: E402

SID, OTHER = "session-aaaa1111", "session-bbbb2222"
RM = "plan/rm/roadmap.md"
ENV = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")


def sh(cwd, *args):
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@x", "-c", "commit.gpgsign=false", *args],
                          cwd=str(cwd), env=ENV, capture_output=True, encoding="utf-8", check=True).stdout


def roadmap(blocks):
    head = "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
    tail = "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n"
    return head + blocks + tail


BLOCK = ("### A1 — 가\n- 의도: 가\n- 범위:\n  - 한다: x\n  - 안 한다: y\n- 의존: 없음\n- 브랜치: feature/a1\n"
         "- 묶음: A1.md\n- 경로 예약: 없음\n\n"
         "### A2 — 나\n- 의도: 나\n- 범위:\n  - 한다: z\n  - 안 한다: w\n- 의존: 없음\n- 브랜치: feature/a2\n"
         "- 묶음: A2.md\n- 경로 예약: 없음\n\n")


class Repo(unittest.TestCase):
    """원격(bare, 기본 브랜치 trunk)과 클론 하나. self.w 가 작업 레포."""
    def setUp(self):
        self.t = Path(tempfile.mkdtemp())
        self.o, self.w = self.t / "o.git", self.t / "w"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "trunk", str(self.o)], env=ENV, check=True)
        subprocess.run(["git", "clone", "-q", str(self.o), str(self.w)], env=ENV, capture_output=True, check=True)
        sh(self.w, "checkout", "-q", "-B", "trunk")
        (self.w / "plan/rm").mkdir(parents=True)
        (self.w / RM).write_text(roadmap(BLOCK), encoding="utf-8")
        (self.w / "notes.md").write_text("---\ntype: note\n---\n", encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", "base")
        sh(self.w, "push", "-q", "origin", "trunk")
        sh(self.w, "remote", "set-head", "origin", "--auto")

    def tearDown(self):
        shutil.rmtree(str(self.t), ignore_errors=True)

    def cli(self, *args):
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = L.main(["--root", str(self.w), *args])
        return rc, buf.getvalue()


class Fixture(unittest.TestCase):
    def test_roadmap_fixture_parses(self):
        import roadmap_model as M
        _m, blocks, _r, _k, errors = M.parse_roadmap(roadmap(BLOCK))
        self.assertEqual(errors, [])
        self.assertEqual([b["id"] for b in blocks], ["A1", "A2"])


class Marker(Repo):
    def test_claim_held_other(self):
        self.assertEqual(self.cli("claim", "--roadmap", RM, "--session", SID)[0], 0)
        rc, out = self.cli("claim", "--roadmap", RM, "--session", SID)
        self.assertEqual((rc, out.strip()), (0, "held"))
        rc, out = self.cli("claim", "--roadmap", RM, "--session", OTHER)
        self.assertEqual(rc, 5)
        self.assertIn(SID, out)
        self.assertIn("읽기 전용", out)

    def test_write_needs_marker(self):
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                           "--cells", "worktree · /x · A1 · 설계 · 2026-10-18")
        self.assertEqual(rc, 5)
        self.assertIn("읽기 전용", out)

    def test_add_drop_round_trip(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, _o = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                          "--cells", "worktree · /x · A1 · 설계 · 가 · 나")
        self.assertEqual(rc, 0)
        data = cs.load(L.mpath(self.w, RM), RM)
        self.assertEqual(data["자원"][0]["만든 때"], "가 · 나")
        self.assertEqual(self.cli("drop", "--roadmap", RM, "--session", SID, "--section", "자원",
                                  "--where", "경로=/x")[0], 0)
        self.assertEqual(cs.load(L.mpath(self.w, RM), RM)["자원"], [])
        self.assertEqual(self.cli("drop", "--roadmap", RM, "--session", SID, "--section", "자원",
                                  "--where", "경로=/x")[0], 1)

    def test_wrong_cell_count(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "PR", "--cells", "feature/a1 · #3")
        self.assertEqual(rc, 2)
        self.assertIn("칸 4개", out)

    def test_broken_machine_state_is_not_overwritten(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        path = L.mpath(self.w, RM)
        path.write_text("깨진 글\n", encoding="utf-8")
        rc, out = self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                           "--cells", "worktree · /x · A1 · 설계 · t")
        self.assertEqual(rc, 3)
        self.assertEqual(path.read_text(encoding="utf-8"), "깨진 글\n")


class StartApproval(Repo):
    def test_same_session_same_scale_is_disclosure(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        rc, out = self.cli("approval", "--roadmap", RM, "--session", SID, "--scale", "남은 에픽 2 · agent 약 6")
        self.assertEqual(rc, 1)
        self.assertIn("승인 필요", out)
        self.assertEqual(self.cli("approve", "--roadmap", RM, "--session", SID,
                                  "--scale", "남은 에픽 2 · agent 약 6")[0], 0)
        rc, out = self.cli("approval", "--roadmap", RM, "--session", SID, "--scale", "남은 에픽 2 · agent 약 6")
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith("공시만"), out)
        rc, out = self.cli("approval", "--roadmap", RM, "--session", SID, "--scale", "남은 에픽 3 · agent 약 9")
        self.assertEqual(rc, 1)
        self.assertIn("규모가 바뀌었다", out)

    def test_other_session_must_ask(self):
        ok, why = L.scale_check([{"세션": SID, "때": "t", "규모": "s"}], OTHER, "s")
        self.assertFalse(ok)
        self.assertIn("이 세션의 승인이 없다", why)

    def test_approve_replaces_own_row(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("approve", "--roadmap", RM, "--session", SID, "--scale", "a")
        self.cli("approve", "--roadmap", RM, "--session", SID, "--scale", "b")
        rows = cs.load(L.mpath(self.w, RM), RM)["시작 승인"]
        self.assertEqual([r["규모"] for r in rows], ["b"])


class Roadmaps(Repo):
    def test_finds_by_frontmatter_not_folder(self):
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 0, out)
        self.assertEqual(out.strip().split("\t")[0], RM)

    def test_no_default_branch(self):
        sh(self.w, "remote", "set-head", "origin", "-d")
        rc, out = self.cli("roadmaps")
        self.assertEqual(rc, 3)
        self.assertIn("origin/HEAD", out)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: FAIL — `ModuleNotFoundError: No module named 'conductor_ledger'`.

- [ ] **Step 3: `conductor_state.py` 에 절 하나**

`SECTIONS` 튜플의 `("레포 설정", ("키", "값")),` 다음에 `("시작 승인", ("세션", "때", "규모")),` 를 더한다. 모듈 독스트링 첫 문단의 담는 것 목록에 「시작 승인(같은 세션 이어 부르기 공시)」 을 더한다.

- [ ] **Step 4: `conductor_ledger.py` 의 뼈대를 쓴다**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""conductor_ledger.py — 지휘자의 쓰기 · 자원 · 기록 절 · 감사 후보(R5 설계 §2 · §5).

기계 상태(`conductor_state.py` 형식) 쓰기는 세션 표지를 쥔 세션만 한다. 이어 가기에 필요한 기록은 에픽 설계문서의
절(`## 판정` · `## 구현 대조 — <계획>` · `## 지휘 기록`)에 쓰고, 커밋은 지휘자가 한다(이 스크립트는 커밋하지 않는다).

명령줄(모두 `--root <레포>` 선택):
  roadmaps                                             끝나지 않은 로드맵 찾기(frontmatter `type: roadmap`)
  claim | takeover | release --roadmap R --session S    세션 표지
  add  --roadmap R --session S --section 절 --cells "칸 · 칸 …"
  drop --roadmap R --session S --section 절 --where 칸=값
  approval | approve --roadmap R --session S --scale "규모"   시작 승인 공시 판단 · 기록
  (Task 5~7 이 자원 · 기록 절 · 감사 명령을 더한다)

종료 코드: 0 · 1(없음/아님) · 2 사용법 · 3 읽기 불가 · 5 다른 세션의 표지.
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import conductor_state as cs  # noqa: E402
import repo_defaults  # noqa: E402
from roadmap_model import DEFAULT_REF, NO_DEFAULT, frontmatter, unquote  # noqa: E402
from state_path import state_root  # noqa: E402

DONE = ("머지됨", "끝남")


class Fail(Exception):
    def __init__(self, rc: int, msg: str):
        super().__init__(msg)
        self.rc = rc


def git(cwd, *args):
    p = subprocess.run(["git", *args], cwd=str(cwd), capture_output=True, encoding="utf-8", errors="replace")
    return p.returncode, p.stdout.rstrip("\n"), p.stderr.strip()


def top(cwd=None) -> Path:
    rc, out, _e = git(cwd or os.getcwd(), "rev-parse", "--show-toplevel")
    if rc or not out:
        raise Fail(3, "git 레포 안이 아니다")
    return Path(out)


def now() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M")


def mpath(root, roadmap: str) -> Path:
    try:
        return cs.machine_path(state_root(str(root)), roadmap)
    except cs.MachineError as exc:
        raise Fail(3, str(exc))


def load(root, roadmap: str) -> dict:
    try:
        return cs.load(mpath(root, roadmap), roadmap)
    except cs.MachineError as exc:
        raise Fail(3, "기계 상태를 읽지 못했다 — 덮어쓰지 않는다: %s" % exc)


def update(root, roadmap: str, session: str, change) -> dict:
    """표지를 쥔 세션만 쓴다. 깨진 기계 상태는 읽기에서 멈춘다(빈 상태로 덮어쓰지 않는다)."""
    path = mpath(root, roadmap)
    owner = cs.holder(path.parent)
    if owner != session:
        raise Fail(5, "읽기 전용 — 표지를 쥔 세션: %s" % (owner or "없음(먼저 claim)"))
    data = load(root, roadmap)
    change(data)
    try:
        cs.save(path, roadmap, data, session)
    except cs.MachineError as exc:
        raise Fail(3, "기계 상태를 쓰지 못했다: %s" % exc)
    return data


def split_cells(section: str, text: str) -> dict:
    cols = cs.COLUMNS.get(section)
    if cols is None:
        raise Fail(2, "모르는 절: %r — 절은 %s" % (section, " · ".join(cs.COLUMNS)))
    cells = [c.strip() for c in text.split(cs.SEP, len(cols) - 1)]
    if len(cells) != len(cols) or not all(cells):
        raise Fail(2, "%s 절은 칸 %d개(%s)다 — 받은 것: %r" % (section, len(cols), " · ".join(cols), text))
    return dict(zip(cols, cells))


def scale_check(rows: list, session: str, scale: str):
    """(공시만이면 True, 이유). 같은 세션의 승인이 있고 규모 줄이 글자 그대로 같을 때만 공시만이다(결정 B)."""
    mine = [r for r in rows if r["세션"] == session]
    if not mine:
        return False, "이 세션의 승인이 없다"
    last = mine[-1]
    if last["규모"] != scale:
        return False, "규모가 바뀌었다 — 전: %s → 지금: %s" % (last["규모"], scale)
    return True, "이 세션에서 %s 에 승인받은 규모 그대로다" % last["때"]


# ── 하위 명령 ────────────────────────────────────────────────────────────────

def c_roadmaps(root, a) -> int:
    rc, _o, _e = git(root, "rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if rc:
        raise Fail(3, NO_DEFAULT)
    rc, out, err = git(root, "grep", "-l", "-I", "--full-name", "-e", "^type: roadmap$", DEFAULT_REF, "--", "*.md")
    if rc not in (0, 1):
        raise Fail(3, "기본 브랜치의 파일을 읽지 못했다: %s" % err)
    found = 0
    for line in out.splitlines():
        path = line.split(":", 1)[1] if ":" in line else line
        _r, text, _e = git(root, "show", "%s:%s" % (DEFAULT_REF, path))
        if unquote(frontmatter(text).get("type", "")) != "roadmap":
            continue
        p = subprocess.run([sys.executable, str(HERE / "roadmap_status.py"), "--json", path], cwd=str(root),
                           capture_output=True, encoding="utf-8", errors="replace")
        try:
            blocks = json.loads(p.stdout).get("blocks") or []
            left = str(sum(1 for b in blocks if b.get("stage") not in DONE))
        except ValueError:
            left = "검사 불가"
        if left != "0":
            print("%s\t%s" % (path, left))
            found += 1
    if not found:
        print("끝나지 않은 로드맵이 없다")
        return 2
    return 0


def c_claim(root, a) -> int:
    got = cs.acquire(mpath(root, a.roadmap).parent, a.session)
    if got in ("acquired", "held"):
        print(got)
        return 0
    print("다른 세션(%s)이 이 로드맵을 지휘하고 있다 — 이 세션은 읽기 전용으로 보인다. 넘겨받을지는 사용자가 정한다(takeover)" % got)
    return 5


def c_takeover(root, a) -> int:
    prev = cs.takeover(mpath(root, a.roadmap).parent, a.session)
    print("표지를 넘겨받았다 — 이전 주인: %s" % (prev or "없음"))
    return 0


def c_release(root, a) -> int:
    print("표지를 풀었다" if cs.release(mpath(root, a.roadmap).parent, a.session) else "이 세션의 표지가 아니다 — 그대로 둔다")
    return 0


def c_add(root, a) -> int:
    row = split_cells(a.section, a.cells)
    update(root, a.roadmap, a.session, lambda d: d[a.section].append(row))
    print("적었다 — %s: %s" % (a.section, a.cells))
    return 0


def c_drop(root, a) -> int:
    key, _eq, value = a.where.partition("=")
    if key not in cs.COLUMNS.get(a.section, ()):
        raise Fail(2, "%s 절에 %r 칸이 없다" % (a.section, key))
    gone = []

    def change(d):
        keep = [r for r in d[a.section] if r[key] != value]
        gone.extend(r for r in d[a.section] if r[key] == value)
        d[a.section] = keep
    update(root, a.roadmap, a.session, change)
    print("지웠다 %d줄 — %s: %s=%s" % (len(gone), a.section, key, value))
    return 0 if gone else 1


def c_approval(root, a) -> int:
    ok, why = scale_check(load(root, a.roadmap)["시작 승인"], a.session, a.scale)
    print(("공시만 — " if ok else "승인 필요 — ") + why)
    return 0 if ok else 1


def c_approve(root, a) -> int:
    def change(d):
        d["시작 승인"] = [r for r in d["시작 승인"] if r["세션"] != a.session]
        d["시작 승인"].append({"세션": a.session, "때": now(), "규모": a.scale})
    update(root, a.roadmap, a.session, change)
    print("시작 승인을 적었다 — %s" % a.scale)
    return 0


def _rs(p):
    p.add_argument("--roadmap", required=True)
    p.add_argument("--session", required=True)


def _rows(p):
    _rs(p)
    p.add_argument("--section", required=True)


COMMANDS = {
    "roadmaps": (c_roadmaps, lambda p: None),
    "claim": (c_claim, _rs),
    "takeover": (c_takeover, _rs),
    "release": (c_release, _rs),
    "add": (c_add, lambda p: (_rows(p), p.add_argument("--cells", required=True))),
    "drop": (c_drop, lambda p: (_rows(p), p.add_argument("--where", required=True))),
    "approval": (c_approval, lambda p: (_rs(p), p.add_argument("--scale", required=True))),
    "approve": (c_approve, lambda p: (_rs(p), p.add_argument("--scale", required=True))),
}


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="conductor_ledger.py", description="지휘자 기록 · 자원 · 감사")
    ap.add_argument("--root")
    sub = ap.add_subparsers(dest="cmd", required=True)
    for name, (_fn, define) in COMMANDS.items():
        define(sub.add_parser(name))
    a = ap.parse_args(argv)
    try:
        root = Path(a.root) if a.root else top()
        return COMMANDS[a.cmd][0](root, a)
    except Fail as exc:
        print("[spec-distill] %s" % exc)
        return exc.rc
    except cs.MachineError as exc:
        print("[spec-distill] %s" % exc)
        return 3


if __name__ == "__main__":
    sys.exit(main())
```

주의: `split_cells` 가 칸 수가 틀리면 rc 2 를 내야 한다(테스트의 `칸 4개`). `json` · `shutil` · `tempfile` · `repo_defaults` import 는 Task 5~7 이 쓴다 — 이 Task 에서 쓰지 않는 import 는 그 Task 에서 더해도 된다(린터가 경고하면 그쪽으로 옮긴다).

- [ ] **Step 5: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_conductor_state.py plugins/spec-distill/tests/test_control_plane.py 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_control_plane.sh 2>&1 | tail -2 && bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2`
Expected: OK · 실패 0. `test_conductor_state.py` · `test_control_plane.py` 가 빈 기계 상태 렌더 전체를 비교해 빨개지면 기대 글에 `## 시작 승인` 머리와 빈 줄을 더한다(형식이 바뀐 것이 맞다).

- [ ] **Step 6: 커밋**

```bash
git commit -m "feat(spec-distill): 지휘자 기록 도구 conductor_ledger — 표지 · 행 쓰기 · 시작 승인 · 로드맵 찾기

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/conductor_state.py plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py
git show --stat HEAD   # 파일 셋(기대 글을 고쳤으면 그 테스트 파일까지 pathspec 에 더한다)
```

---

### Task 5: 자원 · 정리 전 확인 · 「주인 모름」 worktree (AC20)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`
- Modify: `plugins/spec-distill/tests/test_conductor_ledger.py` (클래스 하나)

**Interfaces:**
- Consumes: Task 4 의 `update` · `load` · `git` · `COMMANDS`, `repo_defaults.{SDD_WORKSPACE, MERGE_CHECK_DIR}`.
- Produces: `dirty_lines(path: Path) -> list[str]`(수정 · 추적 안 된 파일 · git 밖 실행 기록 폴더) · `worktrees(root) -> list[dict]`(`git worktree list --porcelain` 의 `path` · `branch` · `head`).
- Produces: CLI
  - `resources --roadmap R` — 기계 상태 `## 자원` 줄들(없으면 「없음」).
  - `cleanup-check --path P` — rc 0 깨끗 · 1 남은 것 있음(줄마다 하나) · 2 worktree 가 아님.
  - `cleanup --roadmap R --session S --path P` — 그 자원을 지운다. 스위트 대조의 일회용 사본(기계 상태 폴더의 `merge-check` 아래)은 지우고 `worktree prune`, 그 밖 worktree 는 깨끗할 때만 `git worktree remove <P>`(`--force` 없음) — 남은 것이 있으면 rc 1 과 그 목록(「사용자에게 보이고 묻는다」). 브랜치는 지우지 않는다. 지운 뒤 `## 자원` 의 그 경로 줄을 뺀다.
  - `orphans --roadmap R` — 메인 체크아웃과 기계 상태 `## 자원` 에 없는 worktree 를 「주인 모름」 으로, 줄마다 `<경로><탭><브랜치 | detached><탭><깨끗 | 남은 것 n개>`. 없으면 「주인 모름 worktree 없음」.

- [ ] **Step 1: 실패하는 테스트를 더한다**

`test_conductor_ledger.py` 의 `if __name__` 줄 앞에 더한다:

```python
class Resources(Repo):
    def add_wt(self, name, branch=None):
        p = self.t / name
        if branch:
            sh(self.w, "worktree", "add", "-q", "-b", branch, str(p), "trunk")
        else:
            sh(self.w, "worktree", "add", "-q", "--detach", str(p), "trunk")
        return p

    def test_cleanup_check_lists_dirty_and_outside_records(self):
        p = self.add_wt("wt1", "feature/a1")
        self.assertEqual(self.cli("cleanup-check", "--path", str(p))[0], 0)
        (p / "new.txt").write_text("x", encoding="utf-8")
        (p / ".superpowers" / "sdd" / "plan").mkdir(parents=True)
        (p / ".superpowers" / "sdd" / "plan" / "progress.md").write_text("Ruling: a", encoding="utf-8")
        rc, out = self.cli("cleanup-check", "--path", str(p))
        self.assertEqual(rc, 1)
        self.assertIn("new.txt", out)
        self.assertIn("실행 방식 작업 폴더", out)
        self.assertEqual(self.cli("cleanup-check", "--path", str(self.t / "nope"))[0], 2)

    def test_cleanup_refuses_dirty_and_keeps_branch(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        p = self.add_wt("wt2", "feature/a1")
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                 "--cells", "worktree · %s · A1 · 구현 · t" % p)
        (p / "x.txt").write_text("x", encoding="utf-8")
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
        self.assertEqual(rc, 1)
        self.assertTrue(p.exists())
        (p / "x.txt").unlink()
        rc, out = self.cli("cleanup", "--roadmap", RM, "--session", SID, "--path", str(p))
        self.assertEqual(rc, 0, out)
        self.assertFalse(p.exists())
        self.assertIn("feature/a1", sh(self.w, "branch", "--list", "feature/a1"))
        self.assertEqual(cs.load(L.mpath(self.w, RM), RM)["자원"], [])

    def test_orphans(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        known = self.add_wt("known")
        stray = self.add_wt("stray", "feature/stray")
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "자원",
                 "--cells", "worktree · %s · A1 · 설계 · t" % known)
        rc, out = self.cli("orphans", "--roadmap", RM)
        self.assertEqual(rc, 0)
        self.assertIn(str(stray.resolve()), out)
        self.assertNotIn(str(known.resolve()), out)
        self.assertNotIn(str(self.w.resolve()) + "\t", out)
        self.assertIn("feature/stray", out)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: FAIL — `invalid choice: 'cleanup-check'`.

- [ ] **Step 3: 구현한다**

`conductor_ledger.py` 의 `# ── 하위 명령` 줄 위에 더한다:

```python
def worktrees(root) -> list:
    rc, out, err = git(root, "worktree", "list", "--porcelain")
    if rc:
        raise Fail(3, "worktree 목록을 읽지 못했다: %s" % err)
    items, cur = [], None
    for line in out.splitlines() + [""]:
        if line.startswith("worktree "):
            cur = {"path": str(Path(line[len("worktree "):]).resolve()), "branch": "detached", "head": ""}
        elif cur is not None and line.startswith("branch "):
            cur["branch"] = line[len("branch "):].split("refs/heads/", 1)[-1]
        elif cur is not None and line.startswith("HEAD "):
            cur["head"] = line[len("HEAD "):]
        elif not line and cur is not None:
            items.append(cur)
            cur = None
    return items


def dirty_lines(path: Path) -> list:
    """지우기 전에 보일 것 — 수정 · 추적 안 된 파일과 git 밖 실행 기록 폴더(SDD 원장 등)."""
    rc, out, _e = git(path, "status", "--porcelain", "--untracked-files=all")
    if rc:
        raise Fail(2, "worktree 가 아니다: %s" % path)
    lines = ["바뀐 파일: %s" % l[3:] for l in out.splitlines() if l.strip()]
    work = path / repo_defaults.SDD_WORKSPACE
    if work.is_dir() and any(work.iterdir()):
        lines.append("실행 방식 작업 폴더(git 밖 기록 — 남길 것은 설계문서 절로 옮긴다): %s" % work)
    return lines


def _is_merge_copy(root, roadmap: str, path: Path) -> bool:
    base = (mpath(root, roadmap).parent / repo_defaults.MERGE_CHECK_DIR).resolve()
    return base in path.resolve().parents
```

`COMMANDS` 위에 하위 명령 넷을 더한다:

```python
def c_resources(root, a) -> int:
    rows = load(root, a.roadmap)["자원"]
    for r in rows:
        print(" · ".join(r[c] for c in cs.COLUMNS["자원"]))
    if not rows:
        print("없음")
    return 0


def c_cleanup_check(root, a) -> int:
    path = Path(a.path)
    if not path.is_dir():
        print("worktree 가 아니다: %s" % path)
        return 2
    lines = dirty_lines(path)
    for l in lines:
        print(l)
    if not lines:
        print("깨끗하다 — 지워도 된다: %s" % path)
    return 1 if lines else 0


def c_cleanup(root, a) -> int:
    path = Path(a.path)
    if _is_merge_copy(root, a.roadmap, path):
        shutil.rmtree(str(path), ignore_errors=True)
        git(root, "worktree", "prune")
    else:
        lines = dirty_lines(path) if path.is_dir() else []
        if lines:
            for l in lines:
                print(l)
            print("지우지 않았다 — 위 내용을 사용자에게 보이고 묻는다(--force 를 쓰지 않는다)")
            return 1
        if path.is_dir():
            rc, _o, err = git(root, "worktree", "remove", str(path))
            if rc:
                raise Fail(3, "worktree 를 지우지 못했다: %s" % err)
    update(root, a.roadmap, a.session,
           lambda d: d.__setitem__("자원", [r for r in d["자원"] if Path(r["경로"]).resolve() != path.resolve()]))
    print("정리했다 — %s (브랜치는 그대로)" % path)
    return 0


def c_orphans(root, a) -> int:
    known = {str(Path(r["경로"]).resolve()) for r in load(root, a.roadmap)["자원"]}
    items = worktrees(root)
    stray = [w for w in items[1:] if w["path"] not in known]
    for w in stray:
        n = len(dirty_lines(Path(w["path"]))) if Path(w["path"]).is_dir() else 0
        print("%s\t%s\t%s" % (w["path"], w["branch"], "깨끗" if not n else "남은 것 %d개" % n))
    if not stray:
        print("주인 모름 worktree 없음")
    return 0
```

`COMMANDS` 에 더한다:

```python
    "resources": (c_resources, lambda p: p.add_argument("--roadmap", required=True)),
    "cleanup-check": (c_cleanup_check, lambda p: p.add_argument("--path", required=True)),
    "cleanup": (c_cleanup, lambda p: (_rs(p), p.add_argument("--path", required=True))),
    "orphans": (c_orphans, lambda p: p.add_argument("--roadmap", required=True)),
```

`git worktree list --porcelain` 의 첫 항목은 메인 체크아웃이다 — `items[1:]` 이 그것을 뺀다.

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: OK.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): 지휘자 자원 정리 — 지우기 전 확인 · --force 없음 · 주인 모름 worktree

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py
git show --stat HEAD   # 파일 둘
```

---

### Task 6: 기록 절 쓰기 · 승인 줄 · 판정 거두기 · 쌓인 기록 (AC17 · AC22 · AC43 · 결정 C)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`
- Modify: `plugins/spec-distill/tests/test_conductor_ledger.py` (클래스 하나)

**Interfaces:**
- Consumes: `roadmap_model.{RECORD_HEADING, RULINGS_HEADING, IMPL_PREFIX, APPROVAL_PREFIX, FormatError, section_lines, approval_date}`(Task 2), `conductor_state.ledger_rulings`.
- Produces: 순수 함수 `insert_record(text: str, line: str) -> str` · `insert_sections(text, plan_rel, rulings: list, impl_line: str, counts: str) -> str`(`Fail` 3 · 2) · `harvest(report_text: str, ledger_texts: list) -> dict`(`lines` · `report` · `ledger` · `only_report` · `only_ledger`) · `write_atomic(path: Path, text: str)`.
- Produces: CLI
  - `record --spec <설계문서> --line "<글>"` — `## 지휘 기록` 끝에 `- <글>` 한 줄(절이 없으면 문서 끝에 만든다). `--approval --date <YYYY-MM-DD> --choice "<원문>"` 이면 `- spec 승인 · <날짜> · 「<원문>」`.
  - `rulings --report <파일> [--ledger <파일> …] [--out <파일>]` — 원장(실행 중 읽은 것)과 하위의 마지막 보고를 합친 판정 목록. 하나도 없으면 rc 3 과 「판정 줄 — 셀 수 없음」.
  - `write-sections --spec <설계문서> --plan <계획 레포 상대경로> --rulings <파일> --impl-line "<--impl 첫 줄>" --counts "<AC n개 중 …>"` — `## 판정` 아래 `### <계획>` 과 `## 구현 대조 — <계획>` 을 쓴다. 그 계획의 구현 대조 절이 이미 있으면 rc 2, 앞 계획의 판정 줄이 하위 머리 없이 있으면 rc 3(「먼저 `### <앞 계획 경로>` 아래로 옮긴다」).
  - `flush --roadmap R --session S --epic E --spec <설계문서>` — 기계 상태 `## 쌓인 기록` 의 그 에픽 · 절 「지휘 기록」 줄을 설계문서에 옮기고 기계 상태에서 뺀다(하위가 일하던 동안 쌓은 기록 — §2 의 첫째 자리). `pending --roadmap R [--epic E]` — 쌓인 기록을 PR 본문 `## 지휘 기록` 절에 붙일 꼴로 낸다(머지 뒤 · 설계문서 없는 자리).

- [ ] **Step 1: 실패하는 테스트를 더한다**

```python
SPEC_DOC = "---\nroadmap: plan/rm/roadmap.md\n---\n\n# 설계\n\n## Acceptance Criteria\n\n- AC1 가\n"


class Records(unittest.TestCase):
    def test_insert_record_creates_and_appends(self):
        t = L.insert_record(SPEC_DOC, "흐름: 설계 흐름(기본)")
        self.assertTrue(t.endswith("## 지휘 기록\n\n- 흐름: 설계 흐름(기본)\n"), t)
        t2 = L.insert_record(t + "\n## 판정\n\n- Ruling: x\n", "- 건너뜀: 통합 리뷰 — 테스트 없음")
        self.assertIn("- 흐름: 설계 흐름(기본)\n- 건너뜀: 통합 리뷰 — 테스트 없음\n\n## 판정", t2)

    def test_insert_record_refuses_duplicate_heading(self):
        with self.assertRaises(L.Fail):
            L.insert_record(SPEC_DOC + "\n## 지휘 기록\n\n- a\n\n## 지휘 기록\n\n- b\n", "c")

    def test_approval_line_round_trips_with_status_reader(self):
        import roadmap_model as M
        t = L.insert_record(SPEC_DOC, L.approval_line("2026-10-18", "① /compact 후 다음 세션 줄 (권장)"))
        self.assertEqual(M.approval_date(t), "2026-10-18")
        self.assertIn("- spec 승인 · 2026-10-18 · 「① /compact 후 다음 세션 줄 (권장)」", t)

    def test_insert_sections_new_and_continue(self):
        t = L.insert_sections(SPEC_DOC, "plans/p1.md", ["- Ruling: a"], "경고 없음 (AC 1개)", "AC 1개 중 구현됨 1")
        self.assertIn("## 판정\n\n### plans/p1.md\n\n- Ruling: a\n", t)
        self.assertIn("## 구현 대조 — plans/p1.md\n\n- 구현 대조: 경고 없음 (AC 1개)\n- 보고: AC 1개 중 구현됨 1\n", t)
        t2 = L.insert_sections(t, "plans/p2.md", ["- Ruling: b"], "경고 없음", "AC 1개 중 구현됨 1")
        self.assertEqual(t2.count("## 판정"), 1)
        self.assertLess(t2.index("### plans/p2.md"), t2.index("## 구현 대조 — plans/p1.md"))
        with self.assertRaises(L.Fail) as cm:
            L.insert_sections(t2, "plans/p2.md", [], "x", "y")
        self.assertEqual(cm.exception.rc, 2)

    def test_insert_sections_refuses_headless_rulings(self):
        doc = SPEC_DOC + "\n## 판정\n\n- Ruling: 옛 줄\n"
        with self.assertRaises(L.Fail) as cm:
            L.insert_sections(doc, "plans/p2.md", ["- Ruling: b"], "x", "y")
        self.assertEqual(cm.exception.rc, 3)

    def test_harvest(self):
        got = L.harvest("끝\n- Ruling: b — 왜 — 값\nRuling: c — 왜 — 값\n", ["- Ruling: a — 왜 — 값\n- Ruling: b — 왜 — 값\n"])
        self.assertEqual(got["lines"], ["- Ruling: a — 왜 — 값", "- Ruling: b — 왜 — 값", "- Ruling: c — 왜 — 값"])
        self.assertEqual((len(got["only_report"]), len(got["only_ledger"])), (1, 1))
        self.assertEqual(L.harvest("없음", [])["lines"], [])

    def test_write_atomic_keeps_file_on_bad_text(self):
        d = Path(tempfile.mkdtemp())
        try:
            p = d / "x.md"
            p.write_text("원래", encoding="utf-8")
            with self.assertRaises(L.Fail):
                L.write_atomic(p, "깨진 \udc80 글")
            self.assertEqual(p.read_text(encoding="utf-8"), "원래")
        finally:
            shutil.rmtree(str(d))


class Pending(Repo):
    def test_flush_moves_rows_into_spec(self):
        self.cli("claim", "--roadmap", RM, "--session", SID)
        self.cli("add", "--roadmap", RM, "--session", SID, "--section", "쌓인 기록",
                 "--cells", "A1 · 지휘 기록 · 건너뜀: 통합 리뷰 — 이유 · 둘")
        spec = self.w / "s.md"
        spec.write_text(SPEC_DOC, encoding="utf-8")
        rc, out = self.cli("pending", "--roadmap", RM)
        self.assertIn("건너뜀: 통합 리뷰 — 이유 · 둘", out)
        rc, _o = self.cli("flush", "--roadmap", RM, "--session", SID, "--epic", "A1", "--spec", str(spec))
        self.assertEqual(rc, 0)
        self.assertIn("## 지휘 기록\n\n- 건너뜀: 통합 리뷰 — 이유 · 둘\n", spec.read_text(encoding="utf-8"))
        self.assertEqual(cs.load(L.mpath(self.w, RM), RM)["쌓인 기록"], [])
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: FAIL — `module 'conductor_ledger' has no attribute 'insert_record'`.

- [ ] **Step 3: 구현한다**

import 줄을 `from roadmap_model import (APPROVAL_PREFIX, DEFAULT_REF, IMPL_PREFIX, NO_DEFAULT, RECORD_HEADING, RULINGS_HEADING, FormatError, frontmatter, section_lines, unquote)` 로 넓히고, `# ── 하위 명령` 위에 더한다(머리 찾기는 문자열 비교만 — §6 락):

```python
def _heads(lines: list) -> list:
    """(줄 번호, 머리) — 펜스 밖 `## ` 머리."""
    out, fence = [], False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            fence = not fence
        elif not fence and line.startswith("## "):
            out.append((i, line.rstrip()))
    return out


def _section_end(lines: list, start: int) -> int:
    nxt = [i for i, _h in _heads(lines) if i > start]
    end = nxt[0] if nxt else len(lines)
    while end > start + 1 and not lines[end - 1].strip():
        end -= 1
    return end


def _finish(lines: list) -> str:
    return "\n".join(lines).rstrip("\n") + "\n"


def insert_record(text: str, line: str) -> str:
    line = line if line.startswith("- ") else "- " + line
    try:
        section_lines(text, RECORD_HEADING)
    except FormatError as exc:
        raise Fail(3, "지휘 기록 절을 읽지 못했다: %s" % exc)
    lines = text.rstrip("\n").split("\n")
    at = [i for i, h in _heads(lines) if h == RECORD_HEADING]
    if not at:
        return _finish(lines + ["", RECORD_HEADING, "", line])
    end = _section_end(lines, at[0])
    if end == at[0] + 1:
        return _finish(lines[:end] + ["", line] + lines[end:])
    return _finish(lines[:end] + [line] + lines[end:])


def approval_line(date: str, choice: str) -> str:
    return "%s%s · 「%s」" % (APPROVAL_PREFIX, date, choice)


def insert_sections(text: str, plan_rel: str, rulings: list, impl_line: str, counts: str) -> str:
    lines = text.rstrip("\n").split("\n")
    heads = _heads(lines)
    if any(h == IMPL_PREFIX + plan_rel for _i, h in heads):
        raise Fail(2, "이미 있다 — %s%s" % (IMPL_PREFIX, plan_rel))
    try:
        section_lines(text, RULINGS_HEADING)
    except FormatError as exc:
        raise Fail(3, "판정 절을 읽지 못했다: %s" % exc)
    block = ["### " + plan_rel, ""] + [r if r.startswith("- ") else "- " + r for r in rulings]
    at = [i for i, h in heads if h == RULINGS_HEADING]
    if at:
        end = _section_end(lines, at[0])
        body = lines[at[0] + 1:end]
        first_sub = next((k for k, l in enumerate(body) if l.startswith("### ")), len(body))
        if any(l.startswith("- ") for l in body[:first_sub]):
            raise Fail(3, "앞 계획의 판정 줄이 하위 머리 없이 있다 — 먼저 `### <앞 계획 경로>` 아래로 옮긴다")
        lines = lines[:end] + [""] + block + lines[end:]
    else:
        lines = lines + ["", RULINGS_HEADING, ""] + block
    lines += ["", IMPL_PREFIX + plan_rel, "", "- 구현 대조: " + impl_line, "- 보고: " + counts]
    return _finish(lines)


def harvest(report_text: str, ledger_texts: list) -> dict:
    """실행 중 원장에서 읽은 판정과 하위의 마지막 보고의 판정을 합친다 — 보고에만 · 원장에만 있는 수도 낸다."""
    def norm(l):
        body = l.strip().lstrip("-*").strip()
        return "- " + body
    led = [norm(l) for t in ledger_texts for l in cs.ledger_rulings(t)]
    rep = [norm(l) for l in cs.ledger_rulings(report_text)]
    lines = list(dict.fromkeys(led + rep))
    return {"lines": lines, "report": len(rep), "ledger": len(led),
            "only_report": [l for l in rep if l not in led], "only_ledger": [l for l in led if l not in rep]}


def write_atomic(path: Path, text: str) -> None:
    """인코딩을 먼저 하고 임시 파일 + 교체 — 실패해도 원래 파일이 남는다."""
    try:
        data = text.encode("utf-8")
    except UnicodeEncodeError as exc:
        raise Fail(3, "글을 UTF-8 로 바꾸지 못해 쓰지 않았다: %s" % exc)
    fd, tmp = tempfile.mkstemp(prefix=".ledger.", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            fh.write(data)
        os.replace(tmp, str(path))
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        raise Fail(3, "읽지 못했다: %s (%s)" % (path, type(exc).__name__))
```

하위 명령:

```python
def c_record(root, a) -> int:
    path = Path(a.spec)
    if a.approval:
        if not (a.date and a.choice):
            raise Fail(2, "--approval 에는 --date 와 --choice 가 필요하다")
        line = approval_line(a.date, a.choice)
    elif a.line:
        line = a.line
    else:
        raise Fail(2, "--line 또는 --approval 이 필요하다")
    write_atomic(path, insert_record(_read(path), line))
    print("적었다(커밋은 지휘자가) — %s: %s" % (path, line))
    return 0


def c_rulings(root, a) -> int:
    got = harvest(_read(Path(a.report)), [_read(Path(p)) for p in a.ledger or []])
    if not got["lines"]:
        print("판정 줄 — 셀 수 없음(보고에도 원장에도 판정이 없다)")
        return 3
    text = "\n".join(got["lines"]) + "\n"
    if a.out:
        write_atomic(Path(a.out), text)
    print(text, end="")
    print("판정 %d개(보고 %d · 원장 %d · 보고에만 %d · 원장에만 %d)"
          % (len(got["lines"]), got["report"], got["ledger"], len(got["only_report"]), len(got["only_ledger"])))
    return 0


def c_write_sections(root, a) -> int:
    path = Path(a.spec)
    rulings = [l for l in _read(Path(a.rulings)).splitlines() if l.startswith("- ")]
    write_atomic(path, insert_sections(_read(path), a.plan, rulings, a.impl_line, a.counts))
    print("판정 %d줄과 구현 대조 절을 썼다(커밋 · push 는 지휘자가) — %s" % (len(rulings), path))
    return 0


def c_flush(root, a) -> int:
    path = Path(a.spec)
    rows = [r for r in load(root, a.roadmap)["쌓인 기록"] if r["에픽"] == a.epic and r["절"] == "지휘 기록"]
    text = _read(path)
    for r in rows:
        text = insert_record(text, r["글"])
    write_atomic(path, text)
    update(root, a.roadmap, a.session, lambda d: d.__setitem__(
        "쌓인 기록", [r for r in d["쌓인 기록"] if not (r["에픽"] == a.epic and r["절"] == "지휘 기록")]))
    print("쌓인 기록 %d줄을 옮겼다(커밋은 지휘자가) — %s" % (len(rows), path))
    return 0


def c_pending(root, a) -> int:
    rows = [r for r in load(root, a.roadmap)["쌓인 기록"] if not a.epic or r["에픽"] == a.epic]
    for r in rows:
        print("- %s · %s" % (r["에픽"], r["글"]) if not a.epic else "- " + r["글"])
    if not rows:
        print("쌓인 기록 없음")
    return 0
```

`COMMANDS` 에 더한다:

```python
    "record": (c_record, lambda p: (p.add_argument("--spec", required=True), p.add_argument("--line"),
                                    p.add_argument("--approval", action="store_true"), p.add_argument("--date"),
                                    p.add_argument("--choice"))),
    "rulings": (c_rulings, lambda p: (p.add_argument("--report", required=True),
                                      p.add_argument("--ledger", action="append"), p.add_argument("--out"))),
    "write-sections": (c_write_sections, lambda p: (p.add_argument("--spec", required=True),
                                                    p.add_argument("--plan", required=True),
                                                    p.add_argument("--rulings", required=True),
                                                    p.add_argument("--impl-line", required=True),
                                                    p.add_argument("--counts", required=True))),
    "flush": (c_flush, lambda p: (_rs(p), p.add_argument("--epic", required=True), p.add_argument("--spec", required=True))),
    "pending": (c_pending, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic"))),
```

에픽 없이 부른 `pending` 은 줄마다 `- <에픽> · <글>` 이다(PR 본문 하나에 여러 에픽의 기록이 모일 수 있다).

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py plugins/spec-distill/tests/test_roadmap_approval.py 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2`
Expected: OK · 실패 0.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): 지휘 기록 절 쓰기 — 승인 줄 · 판정 거두기 · 구현 대조 절 · 쌓인 기록 옮기기

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py
git show --stat HEAD   # 파일 둘
```

---

### Task 7: 사용자 몫 감사 후보 · 줄어든 넘김 · PR 인계 모으기 · 설치본 버전 (AC19 · AC24 · AC25)

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`
- Modify: `plugins/spec-distill/tests/test_conductor_ledger.py` (클래스 하나)

**Interfaces:**
- Consumes: `spec_review_bundle.rejected(spec, root) -> list`, `check_bundle_coverage.deferred_rows(text) -> list[(항목, 이유, 받는 곳)]`, `roadmap_model.rulings_archived`, `roadmap_status.py --json`(블록 `specs` · `tip` · `stage`).
- Produces: 순수 함수 `handoff_section(body: str) -> list[str]`(PR 본문의 `## 통합 리뷰 인계` 절 줄들) · `after_review_lines(body: str) -> list[str]`(「리뷰 뒤 반영」 줄) · `carried(item: str, receiver_text: str) -> bool`(받은 쪽 설계문서의 번호 대조 · AC · 미룸 절에 그 항목의 앞 16글자(백틱 · 별표 · 겹친 공백을 뺀 것)가 있는가 — 후보를 내는 데만 쓴다, 판정은 지휘자) · `version_gap(root, plugin_json: Path) -> str | None`.
- Produces: CLI
  - `pr-handoffs --roadmap R --epic E` — 블록 브랜치마다 `gh pr list --state all --head <브랜치> --json number,state,body` 의 인계 절 · 리뷰 뒤 반영 줄. `gh` 가 없거나 실패하면 rc 4 와 「PR 인계를 읽지 못했다 — <이유>. 설계문서 `## 미룸` 표와 `## 지휘 기록` 을 쓴다」.
  - `audit --roadmap R --epic E` — 후보 다섯 갈래(기각 행 · 미룸 행 · 판정 · 리뷰 뒤 반영 · 줄어든 넘김 의심). 갈래마다 머리 한 줄과 항목 줄. 후보가 없으면 「감사 후보 없음」.
  - `version --plugin-json <설치본 plugin.json>` — 이 레포가 같은 이름의 플러그인 소스를 추적하고 그 버전이 설치본보다 높으면 rc 1 과 「설치된 spec-distill <a> 이 레포 사본 <b> 보다 옛 판이다 — …」. 아니면 rc 0 한 줄.

- [ ] **Step 1: 실패하는 테스트를 더한다**

```python
class Audit(unittest.TestCase):
    def test_handoff_section_and_after_review(self):
        body = ("## 요약\n\n가\n\n## 통합 리뷰 인계\n\n- 이 PR 이 고침: x\n- R3 이 고침: y\n\n## 기타\n\n"
                "- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): 오타\n")
        self.assertEqual(L.handoff_section(body), ["- 이 PR 이 고침: x", "- R3 이 고침: y"])
        self.assertEqual(L.after_review_lines(body), ["- 리뷰 뒤 반영(리뷰 라운드를 거치지 않았다): 오타"])
        self.assertEqual(L.handoff_section("본문만"), [])

    def test_carried(self):
        recv = ("# r\n\n## 번호 대조\n\n| 번호 | 반영/기각 | 자리 |\n|---|---|---|\n| C1 | 반영 | §1 |\n\n"
                "## Acceptance Criteria\n\n- AC1 qg 범위 입력(로드맵 시작 커밋부터)을 받는다\n\n## 미룸\n\n없음\n")
        self.assertTrue(L.carried("qg 범위 입력(로드맵 시작 커밋부터) · 「문서 경로」 정의", recv))
        self.assertFalse(L.carried("전혀 다른 넘김 항목이 여기 있다 길게", recv))

    def test_version_gap(self):
        d = Path(tempfile.mkdtemp())
        try:
            (d / "p").mkdir()
            sh_init = ["git", "init", "-q", str(d)]
            subprocess.run(sh_init, env=ENV, check=True)
            (d / "p" / "plugin.json").write_text('{"name": "spec-distill", "version": "7.3.0"}', encoding="utf-8")
            sh(d, "add", "-A")
            sh(d, "commit", "-qm", "x")
            inst = d / "installed.json"
            inst.write_text('{"name": "spec-distill", "version": "5.3.0"}', encoding="utf-8")
            self.assertIn("옛 판", L.version_gap(d, inst))
            inst.write_text('{"name": "spec-distill", "version": "7.3.0"}', encoding="utf-8")
            self.assertIsNone(L.version_gap(d, inst))
        finally:
            shutil.rmtree(str(d))


class PrHandoffs(Repo):
    def test_no_gh_degrades(self):
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)  # gh 없는 PATH — git 은 절대경로로 부른다
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 4)
        self.assertIn("설계문서 `## 미룸` 표와 `## 지휘 기록` 을 쓴다", out)

    def test_gh_stub(self):
        stub = self.t / "bin"
        stub.mkdir()
        (stub / "pr.json").write_text(json.dumps([{"number": 5, "state": "OPEN",
                                                   "body": "## 통합 리뷰 인계\n\n- R2 가 고침: z\n"}]), encoding="utf-8")
        (stub / "gh").write_text("#!/bin/sh\ncat '%s'\n" % (stub / "pr.json"), encoding="utf-8")
        (stub / "gh").chmod(0o755)
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(stub) + os.pathsep + old
        try:
            rc, out = self.cli("pr-handoffs", "--roadmap", RM, "--epic", "A1")
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("#5", out)
        self.assertIn("- R2 가 고침: z", out)
```

`test_no_gh_degrades` 가 `git` 을 PATH 에서 못 찾지 않도록, `conductor_ledger.git` 은 `shutil.which("git")` 을 모듈 로드 때 한 번 읽어 둔 절대경로(`GIT = shutil.which("git") or "git"`)로 부른다 — Step 3 에서 `git()` 의 `["git", *args]` 를 `[GIT, *args]` 로 바꾼다.

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: FAIL — `has no attribute 'handoff_section'`.

- [ ] **Step 3: 구현한다**

모듈 머리 import 아래에 `GIT = shutil.which("git") or "git"` 를 두고 `git()` 이 그것을 쓰게 한다. 그리고 `# ── 하위 명령` 위에 더한다:

```python
HANDOFF_HEADING = "## 통합 리뷰 인계"
AFTER_REVIEW = "리뷰 뒤 반영"
CARRY_HEADS = ("## 번호 대조", "## Acceptance Criteria", "## 미룸")
CARRY_PREFIX = 16


def handoff_section(body: str) -> list:
    out, inside = [], False
    for line in body.splitlines():
        if line.startswith("## "):
            inside = line.rstrip() == HANDOFF_HEADING
            continue
        if inside and line.strip():
            out.append(line.rstrip())
    return out


def after_review_lines(body: str) -> list:
    return [l.rstrip() for l in body.splitlines() if AFTER_REVIEW in l and l.lstrip().startswith("- ")]


def _plain(text: str) -> str:
    return " ".join(text.translate({ord("`"): None, ord("*"): None}).split())


def carried(item: str, receiver_text: str) -> bool:
    """받은 쪽 설계문서의 번호 대조 · AC · 미룸 절에 넘김 항목의 앞부분이 있는가 — 「줄어든 넘김 의심」 후보용."""
    key = _plain(item)[:CARRY_PREFIX]
    body, inside = [], False
    for line in receiver_text.splitlines():
        if line.startswith("## "):
            inside = line.rstrip() in CARRY_HEADS
            continue
        if inside:
            body.append(line)
    return bool(key) and key in _plain("\n".join(body))


def _version_tuple(v: str):
    parts = v.split(".")
    return tuple(int(p) if p.isdigit() else 0 for p in parts)


def version_gap(root, plugin_json: Path):
    """설치본 플러그인과 같은 이름의 플러그인 소스를 이 레포가 추적하고 그쪽이 더 새 판이면 그 사실 한 줄."""
    try:
        inst = json.loads(Path(plugin_json).read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return "설치본 플러그인 버전을 읽지 못했다: %s" % plugin_json
    rc, out, _e = git(root, "ls-files", "--", "*plugin.json")
    for rel in out.splitlines() if rc == 0 else []:
        try:
            src = json.loads((Path(root) / rel).read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if src.get("name") == inst.get("name") and _version_tuple(str(src.get("version", ""))) > _version_tuple(str(inst.get("version", ""))):
            return ("설치된 %s %s 이 레포 사본 %s 보다 옛 판이다 — 레포 사본의 기능(예: 묶음 대조 · 「여기서 계속」 · 기각 번호 보이기)이 "
                    "없을 수 있다. 플러그인을 갱신하거나 레포 사본으로 지휘한다" % (inst.get("name"), inst.get("version"), src.get("version")))
    return None


def _status(root, roadmap: str) -> dict:
    p = subprocess.run([sys.executable, str(HERE / "roadmap_status.py"), "--json", roadmap], cwd=str(root),
                       capture_output=True, encoding="utf-8", errors="replace")
    try:
        return json.loads(p.stdout)
    except ValueError:
        raise Fail(3, "상태 계산을 읽지 못했다(rc %d): %s" % (p.returncode, p.stderr.strip()[-200:]))


def _block(report: dict, epic: str) -> dict:
    b = next((x for x in report.get("blocks") or [] if x.get("id") == epic), None)
    if b is None:
        raise Fail(2, "에픽 %s 가 로드맵에 없다" % epic)
    return b


def _doc(root, b: dict, path: str) -> str:
    ref = b.get("tip") or DEFAULT_REF
    _r, text, _e = git(root, "show", "%s:%s" % (ref, path))
    return text


def _gh() -> str:
    exe = shutil.which("gh")
    if not exe:
        raise Fail(4, "PR 인계를 읽지 못했다 — gh 가 없다. 설계문서 `## 미룸` 표와 `## 지휘 기록` 을 쓴다")
    return exe


def _prs(root, b: dict):
    exe = _gh()
    out = []
    for br in b.get("branches") or [s["branch"] for s in b.get("branch_states") or []]:
        p = subprocess.run([exe, "pr", "list", "--state", "all", "--head", br, "--json", "number,state,body",
                            "--limit", "5"], cwd=str(root), capture_output=True, encoding="utf-8", errors="replace",
                           env=dict(os.environ, GH_PROMPT_DISABLED="1", NO_COLOR="1"))
        if p.returncode:
            raise Fail(4, "PR 인계를 읽지 못했다 — gh 실패(%s). 설계문서 `## 미룸` 표와 `## 지휘 기록` 을 쓴다"
                       % p.stderr.strip()[-160:])
        try:
            items = json.loads(p.stdout)
        except ValueError:
            raise Fail(4, "PR 인계를 읽지 못했다 — gh 출력 모양이 다르다. 설계문서 `## 미룸` 표와 `## 지휘 기록` 을 쓴다")
        out += [(br, it) for it in items if isinstance(it, dict)]
    return out
```

하위 명령:

```python
def c_pr_handoffs(root, a) -> int:
    _gh()  # gh 가 없으면 상태 계산보다 먼저 강등을 알린다
    b = _block(_status(root, a.roadmap), a.epic)
    for br, it in _prs(root, b):
        body = str(it.get("body") or "")
        print("%s #%s(%s)" % (br, it.get("number"), it.get("state")))
        for line in handoff_section(body) or ["(인계 절 없음)"]:
            print("  " + line)
        for line in after_review_lines(body):
            print("  " + line)
    return 0


def c_audit(root, a) -> int:
    import check_bundle_coverage as cbc
    import spec_review_bundle as srb
    from roadmap_model import rulings_archived
    report = _status(root, a.roadmap)
    b = _block(report, a.epic)
    groups = []
    for spec in b.get("specs") or []:
        text = _doc(root, b, spec)
        groups.append(("기각한 번호(%s)" % spec, srb.rejected(str(Path(root) / spec), str(root)) if (Path(root) / spec).exists() else []))
        try:
            groups.append(("미룸(%s)" % spec, ["%s → %s" % (it, recv) for it, _w, recv in cbc.deferred_rows(text)]))
        except FormatError as exc:
            groups.append(("미룸(%s)" % spec, ["셀 수 없음 — %s" % exc]))
        try:
            groups.append(("판정(%s)" % spec, rulings_archived(text) or []))
        except FormatError as exc:
            groups.append(("판정(%s)" % spec, ["셀 수 없음 — %s" % exc]))
    try:
        groups.append(("리뷰 뒤 반영", [l for _br, it in _prs(root, b) for l in after_review_lines(str(it.get("body") or ""))]))
    except Fail as exc:
        groups.append(("리뷰 뒤 반영", ["읽지 못함 — %s" % exc]))
    shrunk = []
    mine = "\n".join(_doc(root, b, s) for s in b.get("specs") or [])
    for other in report.get("blocks") or []:
        for spec in other.get("specs") or []:
            try:
                rows = cbc.deferred_rows(_doc(root, other, spec))
            except FormatError:
                continue
            for item, _why, recv in rows:
                if recv == a.epic and mine and not carried(item, mine):
                    shrunk.append("%s → %s: %s" % (other["id"], a.epic, item))
    groups.append(("줄어든 넘김 의심", shrunk))
    shown = 0
    for label, items in groups:
        if items:
            print("%s %d개" % (label, len(items)))
            for it in items:
                print("  " + it)
            shown += 1
    if not shown:
        print("감사 후보 없음")
    return 0


def c_version(root, a) -> int:
    gap = version_gap(root, Path(a.plugin_json))
    print(gap or "설치본과 레포 사본의 판이 맞다(또는 레포에 같은 플러그인 소스가 없다)")
    return 1 if gap else 0
```

`COMMANDS` 에 더한다:

```python
    "pr-handoffs": (c_pr_handoffs, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True))),
    "audit": (c_audit, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True))),
    "version": (c_version, lambda p: p.add_argument("--plugin-json", required=True)),
```

`spec_review_bundle.rejected(spec, root)` 의 출력은 이미 「이 설계가 받지 않기로 한 번호 …」 줄들이다 — 그대로 싣는다. 줄어든 넘김은 «의심 후보» 다 — 지휘자가 모델 판단으로 사용자에게 물을 것을 고른다(설계 §5).

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -2`
Expected: OK · 실패 0.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): 사용자 몫 감사 후보 · 줄어든 넘김 의심 · PR 인계 모으기 · 설치본 판 확인

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py
git show --stat HEAD   # 파일 둘
```

---
### Task 8: 통합 리뷰 묶음 · 에픽 worktree 자리 (AC19 의 입력 · AC44 의 worktree 만들기)

설계 §8 의 손 헬퍼(합친 읽기 사본 · 열린 다른 에픽 diff · 충돌 미리 보기)를 옮긴다. 합친 사본 자체는 `merge_check.py --keep-merged` 가 남긴다(Task 3).

**Files:**
- Modify: `plugins/spec-distill/scripts/conductor_ledger.py`
- Modify: `plugins/spec-distill/tests/test_conductor_ledger.py` (클래스 하나)

**Interfaces:**
- Consumes: Task 4~7 의 `git` · `write_atomic` · `_gh` · `_prs` · `handoff_section` · `mpath`, `roadmap_model.parse_roadmap`, `repo_defaults.WORKTREE_HOME`.
- Produces: CLI
  - `review-pack --roadmap R --epic E --branch B [--merged <합친 사본>] [--out <폴더>]` — 폴더(기본: 기계 상태 폴더의 `review/<에픽>-<때>`)에 `pr.diff`(기본 브랜치에서 갈라진 뒤 이 브랜치의 diff) · `open-<에픽>-<브랜치>.diff`(기본 브랜치에 아직 안 들어간 다른 블록 브랜치마다) · `conflicts.txt`(`git merge-tree` 미리 보기, 없으면 「충돌 없음」) · `handoffs.md`(블록 브랜치들의 PR 인계 절, `gh` 가 없으면 그 사유 한 줄) · `README.txt`(파일마다 한 줄 뜻 + 합친 사본 경로)를 쓰고, 폴더 경로와 파일 목록을 낸다. 지휘자는 이 폴더를 `## 자원` 에 「리뷰 묶음」 으로 적는다.
  - `worktree-path --name <이름>` — `<메인 체크아웃>/<하니스 worktree 폴더>/<이름>` 절대경로 한 줄(메인 체크아웃 = `git worktree list` 의 첫 항목). 이름은 영숫자 · `.` · `_` · `-` 만.

- [ ] **Step 1: 실패하는 테스트를 더한다**

```python
class ReviewPack(Repo):
    def branch(self, name, path, text):
        sh(self.w, "checkout", "-q", "-b", name, "trunk")
        (self.w / path).write_text(text, encoding="utf-8")
        sh(self.w, "add", "-A")
        sh(self.w, "commit", "-qm", name)
        sh(self.w, "checkout", "-q", "trunk")

    def test_pack(self):
        self.branch("feature/a1", "x.txt", "a1\n")
        self.branch("feature/a2", "x.txt", "a2\n")
        out_dir = self.t / "pack"
        old = os.environ.get("PATH", "")
        os.environ["PATH"] = str(self.t)  # gh 없음 — handoffs.md 가 사유를 적는다
        try:
            rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1",
                               "--merged", "/somewhere/merged", "--out", str(out_dir))
        finally:
            os.environ["PATH"] = old
        self.assertEqual(rc, 0, out)
        self.assertIn("+a1", (out_dir / "pr.diff").read_text(encoding="utf-8"))
        self.assertIn("+a2", (out_dir / "open-A2-feature_a2.diff").read_text(encoding="utf-8"))
        self.assertIn("A2(feature/a2): x.txt", (out_dir / "conflicts.txt").read_text(encoding="utf-8"))
        self.assertIn("gh 가 없다", (out_dir / "handoffs.md").read_text(encoding="utf-8"))
        self.assertIn("/somewhere/merged", (out_dir / "README.txt").read_text(encoding="utf-8"))

    def test_merged_branch_is_not_open(self):
        self.branch("feature/a2", "y.txt", "y\n")
        sh(self.w, "merge", "-q", "--no-ff", "feature/a2", "-m", "merge a2")
        sh(self.w, "push", "-q", "origin", "trunk")
        sh(self.w, "fetch", "-q", "origin")
        self.branch("feature/a1", "x.txt", "a1\n")
        out_dir = self.t / "pack2"
        rc, out = self.cli("review-pack", "--roadmap", RM, "--epic", "A1", "--branch", "feature/a1", "--out", str(out_dir))
        self.assertEqual(rc, 0, out)
        self.assertFalse((out_dir / "open-A2-feature_a2.diff").exists())
        self.assertEqual((out_dir / "conflicts.txt").read_text(encoding="utf-8").strip(), "충돌 없음")

    def test_worktree_path(self):
        rc, out = self.cli("worktree-path", "--name", "a1")
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip().endswith("/a1"), out)
        self.assertTrue(out.strip().startswith(str(self.w.resolve())), out)
        self.assertEqual(self.cli("worktree-path", "--name", "../x")[0], 2)
```

- [ ] **Step 2: 실패를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: FAIL — `invalid choice: 'review-pack'`.

- [ ] **Step 3: 구현한다**

import 에 `parse_roadmap` 을 더하고(`from roadmap_model import (… parse_roadmap …)`), `# ── 하위 명령` 위에 더한다:

```python
NAME_CHARS = set("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")


def _tip(root, branch: str):
    for ref in ("refs/heads/" + branch, "refs/remotes/origin/" + branch):
        rc, out, _e = git(root, "rev-parse", "--verify", "--quiet", ref + "^{commit}")
        if rc == 0:
            return out
    return None


def _roadmap_blocks(root, roadmap: str) -> list:
    rc, _o, _e = git(root, "rev-parse", "--verify", "--quiet", DEFAULT_REF + "^{commit}")
    if rc:
        raise Fail(3, NO_DEFAULT)
    rc, text, err = git(root, "show", "%s:%s" % (DEFAULT_REF, roadmap))
    if rc:
        raise Fail(3, "기본 브랜치에서 로드맵을 읽지 못했다: %s" % roadmap)
    _m, blocks, _r, _k, errors = parse_roadmap(text)
    if errors:
        raise Fail(3, "로드맵 형식이 깨졌다: %s" % errors[0])
    return blocks
```

하위 명령:

```python
def c_review_pack(root, a) -> int:
    blocks = _roadmap_blocks(root, a.roadmap)
    tip = _tip(root, a.branch)
    if tip is None:
        raise Fail(3, "브랜치를 찾지 못했다: %s" % a.branch)
    out = Path(a.out) if a.out else (mpath(root, a.roadmap).parent / "review" /
                                     ("%s-%s" % (a.epic, datetime.datetime.now().strftime("%Y%m%d%H%M%S"))))
    out.mkdir(parents=True, exist_ok=False)
    files, conflicts = [], []

    def put(name, text):
        write_atomic(out / name, text)
        files.append(name)
    _r, d, _e = git(root, "diff", "%s...%s" % (DEFAULT_REF, tip))
    put("pr.diff", d + "\n")
    for b in blocks:
        for br in b.get("branches") or []:
            other = _tip(root, br) if br != a.branch else None
            if other is None:
                continue
            if git(root, "merge-base", "--is-ancestor", other, DEFAULT_REF)[0] == 0:
                continue  # 이미 기본 브랜치에 들어갔다
            _r, d2, _e = git(root, "diff", "%s...%s" % (DEFAULT_REF, other))
            put("open-%s-%s.diff" % (b["id"], br.replace("/", "_")), d2 + "\n")
            rc, mt, err = git(root, "merge-tree", "--write-tree", "--name-only", "--no-messages", tip, other)
            if rc == 1:
                names = [n for n in mt.splitlines()[1:] if n.strip()]
                conflicts.append("%s(%s): %s" % (b["id"], br, " · ".join(names)))
            elif rc != 0:
                conflicts.append("%s(%s): 미리 보기 실패 — %s" % (b["id"], br, err[-160:]))
    put("conflicts.txt", ("\n".join(conflicts) or "충돌 없음") + "\n")
    try:
        _gh()
        lines = []
        for b in blocks:
            for br, it in _prs(root, b):
                sec = handoff_section(str(it.get("body") or ""))
                if sec:
                    lines += ["### %s %s #%s(%s)" % (b["id"], br, it.get("number"), it.get("state")), ""] + sec + [""]
        handoffs = "\n".join(lines) or "앞선 인계 절 없음"
    except Fail as exc:
        handoffs = "(%s)" % exc
    put("handoffs.md", handoffs + "\n")
    readme = ["이 폴더는 통합 리뷰 묶음이다 — %s 의 %s" % (a.epic, a.branch),
              "합친 사본: %s" % (a.merged or "(넘기지 않았다)"),
              "pr.diff — 기본 브랜치에서 갈라진 뒤 이 브랜치의 diff",
              "open-<에픽>-<브랜치>.diff — 아직 기본 브랜치에 안 들어간 다른 에픽 브랜치의 diff",
              "conflicts.txt — 이 브랜치와 열린 다른 브랜치를 합칠 때 충돌할 파일(git merge-tree)",
              "handoffs.md — 앞선 PR 들의 `## 통합 리뷰 인계` 절"]
    put("README.txt", "\n".join(readme) + "\n")
    print(out)
    for f in files:
        print("  " + f)
    return 0


def c_worktree_path(root, a) -> int:
    if not a.name or not set(a.name) <= NAME_CHARS or a.name in (".", ".."):
        raise Fail(2, "worktree 이름은 영숫자 · . · _ · - 만 쓴다: %r" % a.name)
    main_checkout = Path(worktrees(root)[0]["path"])
    print(main_checkout / repo_defaults.WORKTREE_HOME / a.name)
    return 0
```

`COMMANDS` 에 더한다:

```python
    "review-pack": (c_review_pack, lambda p: (p.add_argument("--roadmap", required=True), p.add_argument("--epic", required=True),
                                              p.add_argument("--branch", required=True), p.add_argument("--merged"),
                                              p.add_argument("--out"))),
    "worktree-path": (c_worktree_path, lambda p: p.add_argument("--name", required=True)),
```

`--no-messages` 가 이 기계의 git 에 없으면(`git merge-tree -h` 로 본다) 그 플래그를 빼고, 출력에서 첫 빈 줄 앞까지만 이름으로 읽는다.

- [ ] **Step 4: 통과를 확인한다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_ledger.py 2>&1 | tail -3`
Expected: OK.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): 통합 리뷰 묶음 — 이 PR · 열린 에픽 diff · 충돌 미리 보기 · 앞선 인계, 에픽 worktree 자리

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/conductor_ledger.py plugins/spec-distill/tests/test_conductor_ledger.py
git show --stat HEAD   # 파일 둘
```

---

### Task 9: 하위에게 보내는 글 `references/conductor-dispatch.md` (AC21 · AC45 · 결정 H · I)

**Files:**
- Create: `plugins/spec-distill/references/conductor-dispatch.md`
- Create: `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh`

**Interfaces:**
- Consumes: Task 1 M7 의 결론 — `SendMessage` 로 끝난 agent 를 이어 부를 수 있었으면 「같은 agent 를 이어 부른다(`SendMessage`)」 문장을 그대로 두고, 이어지지 않았으면 그 문장을 「리뷰 엔진의 문서별 상태 경로를 넘겨 새 agent 로」 하나로 바꾼다(테스트의 그 단언도 같이).
- Produces: 절 머리 다섯 — `## 늘 싣는 것` · `## 사람 자리` · `## 단계마다 새 agent` · `## 마지막 보고` · `## 틀`. `conducting.md`(Task 10)와 SKILL.md(Task 11)가 이 파일을 이름으로 가리킨다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_conductor_dispatch_reference.sh`:

```bash
#!/usr/bin/env bash
# R5 계획 3 — 하위에게 보내는 글(`references/conductor-dispatch.md`): AC21 의 항목 · 두 부분 반환(AC45) · 처분 줄 ·
# 미리 받은 답과 돌려보낼 자리의 구분(결정 H) · 단계마다 새 agent(결정 I). 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
F="$ROOT/plugins/spec-distill/references/conductor-dispatch.md"
[ -f "$F" ] && ok "conductor-dispatch.md 가 있다" || { no "conductor-dispatch.md 가 없다"; finish; exit $?; }
TXT="$(cat "$F")"
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^## /{exit} f' "$F"; }
for h in '## 늘 싣는 것' '## 사람 자리' '## 단계마다 새 agent' '## 마지막 보고' '## 틀'; do
  assert_eq "$(grep -cxF -- "$h" "$F" || true)" "1" "절 머리 「${h}」 가 정확히 하나"
done
once() {  # once <절> <문장>
  assert_eq "$(sec "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "${1}: 「${2}」 정확히 한 번"
}
for lit in '그 에픽 worktree 의 절대경로' '고른 흐름과 그 이유' '단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지' \
           '`TMPDIR`' '공유 임시 폴더의 glob 삭제' '`git stash`' '다른 worktree 의 git 조작' '`Spec: <설계문서 레포 상대경로>`' \
           'HEAD 를 뒤로 옮기지 않는다' 'pathspec'; do
  once '## 늘 싣는 것' "$lit"
done
assert_eq "$(grep -cxF -- '**처분** — consumer=orchestrator · fail-closed · disclosure=하위가 돌려보낸 사람 자리 원문(쉬운 배경 뒤 늘 첨부) · 판정 목록 · AC 보고를 빠짐없이 사용자에게 보인다' "$F" || true)" "1" "처분 줄이 설계 §4 글자 그대로 한 줄"
for lit in '「브랜치 그대로 두기」(3번)' 'Push 와 PR 은 지휘자가 구현 대조 뒤에 한다' '구현 agent 를 보낼 때만' \
           '계획 agent 에게는 싣지 않는다' '(a) 사람에게 보일 쉬운 요약' '(b) skill 이 낸 문면 원문' '내부 기호는 괄호에만' \
           '수 · 순서 · 라벨 · 「(권장)」' '「지휘자 의견:」 한 줄' '원문은 늘 붙인다' '사용자 답은 글자 그대로 같은 agent 에 돌려준다' \
           '쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다' '그 자리만 지휘자가 직접 돌리는 길로 되돌리고'; do
  once '## 사람 자리' "$lit"
done
for lit in '계획 agent' '구현 agent 는 새로 보낸다' '커밋된 계획 경로 · 설계문서 경로' '리뷰 엔진의 문서별 상태 경로'; do
  assert_contains "$(sec '## 단계마다 새 agent')" "$lit" "단계마다 새 agent: $lit"
done
for lit in '판정 전체' 'AC 보고 내용 전체' '경로만으로는 부족하다' '잠긴 스위트 대조' '경합으로 보고'; do
  once '## 마지막 보고' "$lit"
done
TPL="$(sec '## 틀')"
for lit in '### 계획 agent' '### 구현 agent' '### 이어 부르기'; do
  assert_contains "$TPL" "$lit" "틀: $lit"
done
assert_contains "$TPL" 'check_bundle_coverage.py --plan' "계획 틀: --plan 대조"
assert_contains "$TPL" 'check_bundle_coverage.py' "틀: 대조 스크립트"
assert_not_contains "$TXT" 'CLAUDE_PLUGIN_ROOT' "플러그인 루트 토큰을 쓰지 않는다(<SD> 자리표)"
# 부재 락 — 옛 결정(실행 방식 고정 · Push 후 PR · 계획 검토 무대기)
bad="$(printf '%s\n' "$TXT" | grep -nE 'Push 후 PR|푸시 후 PR|계획 검토는 기다리지 않|언제나 subagent|항상 subagent' || true)"
assert_eq "$bad" "" "옛 결정 문면이 없다"
for lit in 'Push 후 PR 을 고른다' '계획 검토는 기다리지 않는다' '실행 방식은 언제나 subagent-driven'; do
  [ -n "$(printf '%s\n' "$lit" | grep -nE 'Push 후 PR|푸시 후 PR|계획 검토는 기다리지 않|언제나 subagent|항상 subagent' || true)" ] \
    && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_conductor_dispatch_reference.sh && bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh 2>&1 | tail -3`
Expected: `conductor-dispatch.md 가 없다`.

- [ ] **Step 3: reference 를 쓴다**

`plugins/spec-distill/references/conductor-dispatch.md`:

~~~markdown
# 지휘 — 하위 agent 에게 보내는 글

지휘 순환(같은 폴더 `conducting.md`)이 계획 · 구현 · 다시 보는 리뷰를 하위 agent 에게 보낼 때 쓰는 틀이다. 하위가 구현하는 쪽이든 리뷰하는 쪽이든 같다. `<SD>` 는 spec-distill 플러그인 폴더의 절대경로다.

## 늘 싣는 것

1. **자리.** 그 에픽 worktree 의 절대경로와 브랜치. 이 worktree 밖의 git 은 조작하지 않는다.
2. **흐름.** 고른 흐름과 그 이유 한 줄(기본은 설계 흐름), 조사 · 결정 흐름이면 산출물 경로.
3. **같은 skill 그대로.** 이 흐름의 skill 을 단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지 돈다. skill 안의 테스트 실행도 그대로 둔다.
4. **미리 받은 답.** 아래 `## 사람 자리` 의 미리 받은 답 가운데 이 일에 닿는 것.
5. **임시 폴더.** `TMPDIR` 를 이 agent 몫 폴더(기계 상태 자원 폴더 아래, 지휘자가 만들어 `## 자원` 에 적은 것)로 준다. 하위는 자기 폴더만 쓰고 지운다.
6. **금지.** 공유 임시 폴더의 glob 삭제(자기 하위 폴더만 지운다) · `git stash` · 다른 worktree 의 git 조작. 그리고 HEAD 를 뒤로 옮기지 않는다(reset · rebase · force 없음) — 커밋은 pathspec 으로 한다. 지휘 세션이 같은 worktree 의 설계문서를 고칠 수 있으니 그 파일을 되돌리지 않는다.
7. **트레일러.** 구현 커밋마다 `Spec: <설계문서 레포 상대경로>` — 품질 게이트의 의도 출처가 이것을 읽는다.
8. **마지막 보고.** 아래 `## 마지막 보고` 의 칸.
9. **처분.** 보내는 자리마다 아래 줄을 그대로 단다.

**처분** — consumer=orchestrator · fail-closed · disclosure=하위가 돌려보낸 사람 자리 원문(쉬운 배경 뒤 늘 첨부) · 판정 목록 · AC 보고를 빠짐없이 사용자에게 보인다

## 사람 자리

미리 받은 답이 있는 자리 — 하위는 그 답을 그대로 쓰고, 쓴 자리와 답을 보고에 적는다.
- 머지 메뉴(`superpowers:finishing-a-development-branch`) — 「브랜치 그대로 두기」(3번). Push 와 PR 은 지휘자가 구현 대조 뒤에 한다.
- finishing 이 묻는 기준 브랜치 — 보내는 글에 적은 브랜치.
- 실행 방식 — writing-plans 가 권한 방식. 구현 agent 를 보낼 때만 이 답을 싣는다. 계획 agent 에게는 싣지 않는다 — writing-plans 끝의 계획 검토 · 실행 방식 질문은 지휘자가 「설계에 없던 결정」 을 가르는 자리라서 돌려보내야 한다. 사용자가 다른 방식을 말하면 그 말을 따른다.

그 밖의 자리(미리 받은 답이 없는 것, 그리고 writing-plans 끝의 질문처럼 지휘자가 가를 자리)에서 하위는 멈추고 두 부분을 함께 돌려보낸다.
- (a) 사람에게 보일 쉬운 요약 — 무엇을 정하나 · 고르면 무엇이 달라지나(그대로 두면 · 고치면) · 배경. 내부 기호는 괄호에만.
- (b) skill 이 낸 문면 원문 — 앞 글 · 경고 · 질문 · 선택지.

지휘자는 배경을 먼저 쉬운 말로 쓰고 질문만 봐도 결정할 수 있게 묻는다(`shared/style/plain-language.md` 의 규칙). 선택지는 (b) 의 수 · 순서 · 라벨 · 「(권장)」 를 글자 그대로 두고, 각 선택지 설명에 원문의 「고르면 무엇이 달라지나」 를 빠뜨리지 않는다. 지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다. 원문은 늘 붙인다. 사용자 답은 글자 그대로 같은 agent 에 돌려준다. 선택지로 받을 수 없는 답(사용자가 직접 써야 하는 것)은 게이트 밖에서 따로 묻고 그 사실과 이유를 적는다. 옮길 때마다 받은 원문과 실제로 띄운 질문을 기계 상태 자원 폴더의 파일(`relay-<에픽>-<번호>.md`)에 남기고, 에픽이 끝나면 쓰기 권한 없는 agent 가 둘의 선택지 수 · 라벨 · 순서를 대조한다. 그대로 전할 수 없는 자리는 그 자리만 지휘자가 직접 돌리는 길로 되돌리고 이유를 그 에픽 설계문서 `## 지휘 기록` 에 적는다 — 사용자가 결정하지 못하게 되는 것이 가장 큰 실패다.

## 단계마다 새 agent

- 계획 agent 는 writing-plans 로 계획을 쓰고 커밋한 뒤 대조를 돌리고, writing-plans 끝의 질문에서 두 부분을 돌려보내고 멈춘다.
- 구현 agent 는 새로 보낸다 — 계획 agent 를 이어 쓰지 않는다(한 agent 가 리뷰~계획을 이으면 맥락이 백만 토큰 가까이 커진다). 입력은 커밋된 계획 경로 · 설계문서 경로 · 미리 받은 답(실행 방식 포함) · 기준 브랜치뿐이다.
- 하위가 돌린 리뷰를 다시 돌거나 좁은 재리뷰를 할 때는 같은 agent 를 이어 부른다(`SendMessage`). 그 agent 가 없으면 리뷰 엔진의 문서별 상태 경로를 넘겨 라운드 수와 재리뷰 상한이 처음부터 다시 세어지지 않게 한다.

## 마지막 보고

하위의 마지막 메시지는 아래를 모두 싣는다 — 실행 방식이 작업 폴더를 지울 수 있어 경로만으로는 부족하다.
- 판정 전체 — 실행 방식의 마지막 목록 그대로(줄마다 `Ruling:`).
- AC 보고 내용 전체 — AC 마다 `AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거`.
- 쓴 미리 받은 답과 그 자리 · 커밋 목록(해시와 한 줄) · 브랜치 · 남긴 파일.
- 하위가 본 테스트 실패와 그 이름. 진짜 실패인지는 지휘자의 잠긴 스위트 대조(`merge_check.py`)만 판정한다 — 그 대조에서 사라지는 실패는 경합으로 보고 알린다.

## 틀

### 계획 agent

```text
너는 <에픽> 의 계획 agent 다. 자리: <에픽 worktree 절대경로>(브랜치 <브랜치>). 이 worktree 밖의 git 은 조작하지 않는다.
흐름: <고른 흐름> — <이유>. 입력: 설계문서 <설계문서 절대경로>. 승인 게이트가 낸 계획 agent 의 입력 줄: <그 줄 그대로>.
superpowers:writing-plans 를 단일 세션과 똑같이, 단계를 빼거나 다시 쓰지 말고 끝까지 돈다. 계획을 커밋한 뒤
python3 <SD>/scripts/check_bundle_coverage.py --plan <설계문서> <계획>[ --acs "<이 계획 몫 AC>"] 를 돌려 빠진 AC 를 계획에 더하고 그 첫 줄을 보고한다.
writing-plans 가 끝에 묻는 질문(계획 검토 · 실행 방식)에서 멈추고 (a) 사람에게 보일 쉬운 요약 (b) 질문 원문을 함께 돌려보낸다.
금지: 공유 임시 폴더 glob 삭제 · git stash · 다른 worktree 의 git · HEAD 뒤로 옮기기. 커밋은 pathspec. TMPDIR=<이 agent 폴더>.
```

### 구현 agent

```text
너는 <에픽> 의 구현 agent 다. 자리: <에픽 worktree 절대경로>(브랜치 <브랜치>). 이 worktree 밖의 git 은 조작하지 않는다.
계획 <계획 레포 상대경로> 를 <writing-plans 가 권한 실행 방식 skill> 로 단일 세션과 똑같이 끝까지 실행한다.
미리 받은 답: 머지 메뉴는 「브랜치 그대로 두기」(3번) · 기준 브랜치 <브랜치>. 그 밖에 사람에게 묻는 자리를 만나면 멈추고 (a) 쉬운 요약 (b) 원문을 돌려보낸다.
마지막 전체 리뷰는 설계문서 ## Acceptance Criteria 가운데 <이 계획 몫 AC> 를 AC 마다 한 줄(AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거)로 보고하게 한다.
구현 커밋마다 Spec: <설계문서 레포 상대경로> 트레일러. 마지막 보고에 판정 전체 · AC 보고 내용 전체 · 커밋 목록 · 본 테스트 실패 이름을 싣는다.
금지: 공유 임시 폴더 glob 삭제 · git stash · 다른 worktree 의 git · HEAD 뒤로 옮기기. 커밋은 pathspec. TMPDIR=<이 agent 폴더>.
```

### 이어 부르기

```text
(같은 agent 에 SendMessage) 사용자 답: <글자 그대로>. 멈춘 자리에서 이어 간다. 위 금지와 마지막 보고는 그대로다.
```
~~~

M7 결과가 「이어지지 않음」 이면 `## 단계마다 새 agent` 의 셋째 불릿과 `### 이어 부르기` 틀을 「리뷰 엔진의 문서별 상태 경로를 넘겨 새 agent 로 다시 돌린다 — 사용자 답과 멈춘 자리를 함께 준다」 로 바꾼다(테스트 단언 `### 이어 부르기` 는 그대로 둔다).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh 2>&1 | tail -3 && bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -2 && bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -2 && bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -2`
Expected: 실패 0. 포인터 락이 `shared/style/plain-language.md` 를 이 파일 폴더 기준으로 풀어 빨개지면 그 괄호를 「레포의 쉬운 말 규칙」 으로 바꾼다.

- [ ] **Step 5: 커밋**

```bash
git commit -m "docs(spec-distill): 하위에게 보내는 글 — 미리 받은 답과 두 부분 반환 · 단계마다 새 agent · 마지막 보고

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/references/conductor-dispatch.md plugins/spec-distill/tests/test_conductor_dispatch_reference.sh
git show --stat HEAD   # 파일 둘
```

---

### Task 10: 지휘 순환 걸음 1~7 을 `conducting.md` 에 (AC16 · AC22 · AC23 · AC26 · AC27 · AC28 · AC41 · AC43 · AC44)

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md` (제목 아래 · `## 손으로 따르는 절차` 앞에 `## 지휘 순환` 절, 손 절차 걸음 2 · 3 의 옮겨 가는 길 문장)
- Create: `plugins/spec-distill/tests/test_conducting_loop.sh`
- Modify: `plugins/spec-distill/tests/test_conducting_reference.sh` (걸음 2 의 새 문장 단언 하나)

**Interfaces:**
- Consumes: Task 1 M6(옮겨 가기 실측) · M7(알림 도구 설명), Task 2~8 의 명령 이름(`ledger claim` · `approval` · `record --approval` · `rulings` · `write-sections` · `flush` · `pending` · `audit` · `review-pack` · `worktree-path` · `cleanup-check` · `cleanup` · `orphans` · `version` · `release`, `merge_check.py run … --keep-merged` 의 종료 코드).
- Produces: `## 지휘 순환` 아래 `### 1. 맞추기` ~ `### 7. 끝` · `### /compact 시점` · `### 알림`. 걸음마다 `- 기본값:` · `- 판단:` · `- 부를 skill:` · `- 기록:` · `- 기계 상태:` 다섯 줄 머리. 공유 문장(AC37) `실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.` — Task 12 가 템플릿 · 로드맵에 같은 문장을 둔다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_conducting_loop.sh`:

```bash
#!/usr/bin/env bash
# R5 계획 3 — 지휘 순환(`references/conducting.md` 의 `## 지휘 순환`): 걸음 1~7 · 다섯 칸 · 걸음별 장치 · 끝 절은 손 절차(AC16).
# 정적 락이다 — 지휘 세션이 실제로 따르는지는 재지 못한다(그것은 계획 끝의 관측표).
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conducting_loop.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
CD="$ROOT/plugins/spec-distill/references/conducting.md"
LOOP="$(awk '$0=="## 지휘 순환"{f=1;next} f&&/^## /{exit} f' "$CD")"
[ -n "$LOOP" ] && ok "지휘 순환 절을 읽었다" || { no "지휘 순환 절이 없다"; finish; exit $?; }
assert_eq "$(grep -E '^## ' "$CD" | tail -1)" "## 손으로 따르는 절차" "끝 절은 손으로 따르는 절차다(AC16)"
assert_eq "$(printf '%s\n' "$LOOP" | grep -E '^### [1-7]\. ' | sed 's/^### \([1-7]\)\..*/\1/' | tr '\n' ' ')" "1 2 3 4 5 6 7 " "걸음 1~7 이 차례로 있다"
step() { printf '%s\n' "$LOOP" | awk -v n="$1" 'index($0, "### " n ". ")==1{f=1;next} f&&/^### /{exit} f'; }
for n in 1 2 3 4 5 6 7; do
  for cell in '- 기본값:' '- 판단:' '- 부를 skill:' '- 기록:' '- 기계 상태:'; do
    assert_eq "$(step "$n" | grep -cF -- "$cell" || true)" "1" "걸음 ${n}: 「${cell}」 칸이 하나"
  done
done
once() { assert_eq "$(step "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "걸음 ${1}: 「${2}」 정확히 한 번"; }
for lit in 'control_plane.py show --tasks <로드맵>' 'ledger claim --roadmap <로드맵> --session <세션>' '읽기 전용으로 보이며' \
           '덮어쓰지 않는다' '주인을 믿고 캐시를 고친 뒤 알린다' '놀고 있는 agent 는 내린다' '기억에 기대지 않는다' \
           'ledger orphans' 'ledger version'; do once 1 "$lit"; done
for lit in '「지금 답할 수 있나」' '배경과 함께 하나씩' '첫 줄에 에픽 이름' '그 답에 기대는 일' '무관하다고 본 이유를 적는다' \
           '그 리뷰 게이트의 질문 호출에 섞지 않고' 'ledger audit' 'brainstorming 을 거친다'; do once 2 "$lit"; done
for lit in '한 번에 한 에픽씩' '다른 세션을 열라는 줄을 주지 않는다' '`AskUserQuestion` 으로 승인받는다' '`epic-handoff.md`' \
           'worktree-path --name <이름>' '하니스의 새 worktree 만들기를 쓸 수 없어서' '옮기기 전에 지금 자리의 쓰기(커밋 포함)를 끝낸다' \
           '진입 사전 검사 줄의 `root=` 가 그 worktree 인지 확인한 뒤 리뷰한다' '리뷰 원장이 라운드 · 상한을 잇는다' \
           'ledger record --spec <설계문서> --approval' '규모(몇 agent · 무엇)를 알린다'; do once 3 "$lit"; done
for lit in '실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.' \
           '계획을 쓴 agent 가 스스로 가르지 않는다' '답 전에는 그 에픽의 구현을 보내지 않는다' '그 에픽만 멈추고' '다른 에픽은 계속한다' \
           'ledger rulings' '판정 줄 — 셀 수 없음' 'check_bundle_coverage.py --impl' 'ledger write-sections' 'ledger flush' '같은 worktree 에 두 writer 를 두지 않는다'; do once 4 "$lit"; done
for lit in 'merge_check.py run --roadmap <로드맵> --branch <브랜치> --keep-merged' 'ledger review-pack' \
           '`review_model`' '「이 PR 이 고침」 · 「뒤 에픽이 고침」' '`## 통합 리뷰 인계`' 'PR 하나에 두 번까지' '머지는 사용자가 한다'; do once 5 "$lit"; done
for lit in 'superpowers:systematic-debugging' 'superpowers:verification-before-completion' 'superpowers:receiving-code-review'; do
  assert_contains "$(step 5)" "$lit" "걸음 5: $lit"
done
for lit in '직접 merge 하지 않는다' '다음 task 경계에서 merge 하라고' '그 에픽만 멈추고 알린다' '`redecompose.md`' '브랜치는 지우지 않는다' 'ledger pending' '맡을 에픽을 제안하고' '이슈를 새로 만드는 것은 그때마다 묻는다'; do once 6 "$lit"; done
for lit in '끝에서 끝 확인' '로드맵 시작 커밋부터' '그 사실을 알린다' 'ledger release'; do once 7 "$lit"; done
COMPACT="$(printf '%s\n' "$LOOP" | awk '$0=="### /compact 시점"{f=1;next} f&&/^### /{exit} f')"
assert_contains "$COMPACT" '`/compact` 와 `/spec-distill:epic-conductor <로드맵>`' "/compact: 두 줄"
assert_contains "$COMPACT" '커밋하고 기계 상태를 저장한 뒤' "/compact: 저장이 먼저"
ALERT="$(printf '%s\n' "$LOOP" | awk '$0=="### 알림"{f=1;next} f&&/^### /{exit} f')"
assert_contains "$ALERT" '멈췄을 때와 모두 끝났거나 더 갈 일이 없을 때만' "알림: 두 경우만"
# 순서: 옮겨 간 뒤 root= 확인이 spec-review 부르기보다 먼저(같은 문장 안)
order="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
a, b = t.find("`pwd` 와 `git rev-parse --show-toplevel` 이 그 worktree 인지 보고"), t.find("확인한 뒤 리뷰한다")
print("yes" if 0 <= a < b else "no")' "$(step 3)")"
assert_eq "$order" "yes" "걸음 3: 위치 확인 → root= 확인 → 리뷰 순서"
# 부재 — 다른 세션을 열게 하는 말 · 옛 미리 받은 답 · 플러그인 루트 토큰
forbid() { local t="${1//다른 세션을 열라는 줄을 주지 않는다/}"; t="${t//세션을 새로 열지 않고/}"; printf '%s\n' "$t" | grep -nE '세션을 (새로 )?열어|/new 로|새 세션에서|Push 후 PR|계획 검토는 기다리지 않' || true; }
assert_eq "$(forbid "$LOOP")" "" "지휘 순환: 세션을 새로 열게 하는 말 · 옛 미리 받은 답이 없다"
for lit in '새 세션에서 이어 간다' '에픽마다 세션을 새로 열어' 'Push 후 PR 을 고른다'; do
  [ -n "$(forbid "$lit")" ] && ok "양성 대조: 「${lit}」 를 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done
assert_not_contains "$LOOP" 'CLAUDE_PLUGIN_ROOT' "지휘 순환: 플러그인 루트 토큰 없음(<SD>)"
finish
```

`tests/test_conducting_reference.sh` 의 걸음 2 `once` 목록(`for lit in '그 리뷰 게이트 질문에 섞지 않고' …`)에 `'하니스의 worktree 들어가기(경로 지정)'` 를 더한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_conducting_loop.sh && bash plugins/spec-distill/tests/test_conducting_loop.sh 2>&1 | tail -3`
Expected: `지휘 순환 절이 없다`.

- [ ] **Step 3: `## 지휘 순환` 절을 쓴다**

`conducting.md` 의 제목 줄(`# 지휘 — …`) 다음 빈 줄 뒤, `## 손으로 따르는 절차` 앞에 넣는다. `### 알림` 의 마지막 문장은 Task 1 M7 결과로 고른다 — 알림 도구 설명이 「사용자가 보고 있으면 보내지 않는다」는 뜻을 말하면 그 원문 요지를 한 문장으로, 말하지 않으면 그 문장을 넣지 않는다(설계 Deferred 9e1747a6#r1.1 — 실측 없는 도구 동작을 쓰지 않는다). 도구가 없으면 「알림 도구가 없으면 멈춘 사실을 다음 응답 첫 줄에 쓴다」 로.

~~~markdown
## 지휘 순환

지휘자 skill(`/spec-distill:epic-conductor`)이 불릴 때마다 걸음 1 부터 차례로 돈다. 걸음마다 다섯 칸(기본값 · 판단 · 부를 skill · 기록 · 기계 상태)이고, 기본값과 다르게 하면 무엇을 왜 다르게 했는지 그 에픽 설계문서 `## 지휘 기록` 에 적는다(에픽에 매이지 않은 판단은 다음 로드맵 수정 PR 본문의 `## 지휘 기록` 절에). 정석 흐름(brainstorming → 계획 → 구현)의 뜻은 지킨다. superpowers 는 부르기만 하고 고치지 않는다.

- `<SD>` 는 spec-distill 플러그인 폴더의 절대경로, `<로드맵>` 은 로드맵 파일의 레포 루트 기준 경로, `<세션>` 은 `python3 "<SD>"/scripts/state_path.py session-id` 의 값이다. `ledger <명령>` 은 `python3 "<SD>"/scripts/conductor_ledger.py <명령>` 을 줄인 것이다.
- 레포마다 다른 값은 박지 않고 읽는다 — 기본 브랜치는 `origin/HEAD`, 브랜치 이름은 로드맵 블록의 `브랜치:`, 설계문서 · 계획 폴더 · 테스트 명령 · 리뷰 모델은 로드맵 frontmatter 의 `specs_dir` · `plans_dir` · `test_command` · `review_model` 이다.
- 하위에게 보내는 글은 같은 폴더 `conductor-dispatch.md` 의 틀이다. 각 칸의 주인은 같은 폴더 `roadmap-ontology.md` 에 있다.

### 1. 맞추기
- 기본값: `git fetch origin` → `python3 "<SD>"/scripts/control_plane.py show --tasks <로드맵>` 으로 작업 목록을 맞춘다(종료 코드 3 · 4 의 뜻은 손 절차 1 과 같다) → `ledger claim --roadmap <로드맵> --session <세션>` 으로 표지를 잡는다 → 기계 상태의 PR 캐시를 주인(GitHub)과 맞춘다 → 살아 있는 agent 를 센다.
- 판단: 표지를 다른 세션이 쥐었으면 쓰지 않고 읽기 전용으로 보이며, 넘겨받을지(`ledger takeover`)는 사용자에게 묻는다. 기계 상태가 깨졌으면 사유를 보이고 덮어쓰지 않는다 — 다시 만들 수 있는 것(PR 번호 · 자원 · 기다리는 질문)은 주인에서 다시 모은다. 캐시는 「PR 열림」인데 GitHub 은 머지면 주인을 믿고 캐시를 고친 뒤 알린다. 끝났는데 보고하지 않은 agent 는 결과를 거두고 놀고 있는 agent 는 내린다. 기다릴 때는 끊어서 기다리고 사이마다 살아 있는 하위를 다시 센다(superpowers SDD 의 「Waiting on dispatched subagents」 방식). 압축 · 새 세션 뒤에도 여기서 시작한다 — 무엇이 끝났는지 기억에 기대지 않는다. 이 세션에서 처음 부를 때는 `ledger orphans --roadmap <로드맵>` 의 「주인 모름」 worktree(고른 것만 지운다)와 `ledger version --plugin-json "<SD>"/.claude-plugin/plugin.json` 의 판 차이를 보인다.
- 부를 skill: 없음.
- 기록: 없음 — 주인과 캐시를 맞춘 사실은 알림으로만.
- 기계 상태: `## PR`(캐시 고침) · `## 살아 있는 agent`(거둔 것 · 내린 것 빼기) · `## 실행 원장`(읽은 줄).

### 2. 사람 몫 모으기
- 기본값: 열린 결정마다 「지금 답할 수 있나」를 판정해, 답할 수 있는 것만 배경과 함께 하나씩 묻는다. 질문마다 첫 줄에 에픽 이름을 쓴다.
- 판단: 앞 에픽의 결과를 봐야 답할 수 있는 것은 아직 묻지 않는다. 답을 기다리는 동안 그 답에 기대는 일(같은 에픽의 다음 단계 · 의존 에픽 · 같은 파일을 고치는 에픽)은 진행하지 않는다 — brief · 설계 · 계획처럼 방향을 정하는 단계면 특히 그렇다. 계속 가는 것은 그 답과 무관한 일뿐이고 무관하다고 본 이유를 적는다. 판단이 서지 않으면 기다린다. 한 에픽의 spec 리뷰가 도는 동안(진입부터 승인 게이트까지) 다른 에픽에서 돌아온 질문 · 멈춤은 받은 원문을 기계 상태 자원 폴더의 파일에 적어 두기만 하고, 그 리뷰 게이트의 질문 호출에 섞지 않고 게이트와 게이트 사이나 리뷰가 끝난 뒤 묻는다. 사용자 몫 감사는 `ledger audit --roadmap <로드맵> --epic <에픽>` 의 후보 가운데 실제로 사용자가 정할 것만 모델이 골라 묻는다 — spec 승인 게이트 · 머지 전 확인 · 지휘자를 다시 불렀을 때. 에픽에 새 항목을 넣을 때는 기존 결정 · 원칙의 수리면 바로 넣고, 사용자에게 보이는 동작 · 새 요구 · 다른 에픽의 경계에 닿으면 (작으면 채팅 안의 짧은 설계로) brainstorming 을 거친다 — 고른 쪽과 이유를 한 줄로 보인다.
- 부를 skill: 없음(질문은 `AskUserQuestion`).
- 기록: 무관하다고 보고 계속 간 일과 그 이유 · 감사에서 물은 것과 답 → 그 에픽 설계문서 `## 지휘 기록`.
- 기계 상태: `## 기다리는 질문`(에픽 · 기대는 일 · 질문) · 받은 원문 파일은 `## 자원` 에 「질문 원문」 으로.

### 3. 다음 일 고르기와 보내기
- 기본값: 준비된 에픽마다 설계 흐름(brainstorming → spec-review → 계획 → 구현)이다. 사람에게 묻는 단계(brainstorming 의 질문 · 절별 승인 · spec 승인)는 이 세션이 한 번에 한 에픽씩, 의존 사슬의 앞쪽부터 직접 한다. 사용자에게 다른 세션을 열라는 줄을 주지 않는다 — 같은 세션의 `/compact` 뒤 이어 갈 줄만 준다.
- 판단: 조사 · 측정 · 결정처럼 설계 흐름이 맞지 않으면 고른 흐름 · 이유 · 산출물을 보이고 `AskUserQuestion` 으로 승인받는다(거절이면 설계 흐름). 승인된 흐름 · 산출물은 같은 폴더 `redecompose.md` 의 재분해 절차로 로드맵 `흐름:` · `산출물:` 칸에 적는다. brainstorming 의 입력과 지시는 같은 폴더 `epic-handoff.md` 의 에픽 넘김 줄이 싣는 것과 같다 — 그 줄을 사용자에게 주지 않고 이 세션의 입력으로 쓴다.
  - 에픽 worktree: 블록의 `브랜치:` 이름으로 먼저 만든다 — `git worktree add "$(python3 "<SD>"/scripts/conductor_ledger.py worktree-path --name <이름>)" -b <브랜치> origin/HEAD`. 하니스가 옮겨 갈 수 있는 폴더에 만들고, worktree 안에 있는 세션은 하니스의 새 worktree 만들기를 쓸 수 없어서 `git worktree add` 로 만든다. `브랜치:` 가 여럿이면 적힌 순서가 계획 순서이고, 다음 계획의 브랜치는 앞 계획이 머지됐으면 기본 브랜치에서, 아직이면 앞 계획의 브랜치에서 만든다.
  - 옮겨 가는 길(2026-10-18 실측): 하니스의 worktree 옮겨 가기(`EnterWorktree`, 경로 지정)로 그 worktree 에 들어가 할 일을 하고 앞 자리로 돌아온다(앞 자리도 경로 지정으로, 메인 체크아웃이면 하니스의 worktree 나가기 `ExitWorktree` keep). 옮기기 전에 지금 자리의 쓰기(커밋 포함)를 끝낸다 — 옮긴 뒤 앞 자리는 다시 들어가기 전까지 읽기 전용이다. 하니스로 옮겨 갈 수 없으면(하니스 worktree 폴더 밖의 worktree 등) 메인 체크아웃에서 Bash 로 셸의 작업 폴더를 옮기고, 그것도 안 되면 그 에픽 담당 agent 가 두 부분으로 돌려보내는 길로 하고 그 사실을 알린다.
  - spec 리뷰: 설계문서는 이 세션이 brainstorming 끝에 써서 에픽 worktree 에서 커밋하고, spec 리뷰도 이 세션이 같은 skill(`/spec-distill:spec-review <설계문서 절대경로> --bundle <묶음 절대경로>`)로 직접 돌린다. 옮겨 간 뒤 `pwd` 와 `git rev-parse --show-toplevel` 이 그 worktree 인지 보고, 진입 사전 검사 줄의 `root=` 가 그 worktree 인지 확인한 뒤 리뷰한다 — 아니면 멈춘다. 리뷰 반영 커밋도 그 worktree 에서 한다. 리뷰 도중 압축되면 같은 설계문서 경로로 다시 부른다 — 리뷰 원장이 라운드 · 상한을 잇는다.
  - 승인 게이트: ① · ② · 기타 칸 「여기서 계속」 은 선택지를 그대로 보이되, 무엇을 골라도 이 세션은 writing-plans 를 따르지 않고 게이트가 낸 계획 agent 의 입력 줄을 계획 agent 에게 넘긴다. 승인 사실은 미커밋 확인 뒤 `ledger record --spec <설계문서> --approval --date <YYYY-MM-DD> --choice "<고른 선택지 원문>"` 으로 적어 그 에픽 worktree 에서 커밋한다. ① 이면 이 세션의 `/compact` 를 권하고, ② 를 골라도 세션을 새로 열지 않고 ① 과 같이 처리한다고 알린다.
  - 보내기: spec 이 승인되면 계획 agent 를 그 에픽 worktree 로 보내고(`conductor-dispatch.md` 의 계획 틀) 다음 에픽의 설계로 간다. 의존 · 같은 파일 겹침(상태 계산의 동시 가능 목록)이 없으면 동시에 보낸다 — 띄우기 전에 규모(몇 agent · 무엇)를 알린다.
- 부를 skill: `superpowers:brainstorming` · `superpowers:using-git-worktrees`(하니스 기본 기능 우선) · `/spec-distill:spec-review` · `superpowers:dispatching-parallel-agents`.
- 기록: 고른 흐름과 이유 · spec 승인 줄 → 그 에픽 설계문서 `## 지휘 기록`(에픽 worktree 에서 커밋).
- 기계 상태: `## 자원`(에픽 worktree · 질문 원문 파일 · agent 몫 임시 폴더) · `## 살아 있는 agent`(계획 agent).

### 4. 돌아오기
- 기본값: 백그라운드 agent 가 끝나면 알림이 온다 — 걸음 1 로 가서 상태를 다시 계산하고 작업 목록을 갱신한다. 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 판단: 계획 agent 가 돌아오면 이 세션이 계획을 읽고 「설계에 없던 결정(범위 · 인터페이스 · 파일 배치 등)」 이 있는지 가른다 — 계획을 쓴 agent 가 스스로 가르지 않는다. 없으면 계획 경로만 보이고 새 구현 agent 를 보낸다(writing-plans 가 권한 실행 방식을 미리 받은 답으로). 있으면 그 결정들을 배경과 함께 사용자에게 묻고(걸음 2), 답 전에는 그 에픽의 구현을 보내지 않는다. 구현 중에는 맞추기마다 실행 방식 원장(SDD 면 그 worktree 작업 폴더의 `progress.md`)의 `Ruling:` 줄을 읽어 화면의 판정 줄에 올린다. 판정이 승인된 설계의 수용 기준 · 의도를 바꾸거나 구현이 막히면(SDD 의 BLOCKED 포함) 그 에픽만 멈추고 배경과 함께 묻는다 — 다른 에픽은 계속한다. 설계 안의 판정은 멈추지 않고 끝에 목록 전체를 보인다.
  - 구현 agent 가 돌아오면 보고에서 판정 전체와 AC 보고 내용 전체를 거둔다(작업 폴더는 지워질 수 있어 경로에 기대지 않는다): 보고를 기계 상태 자원 폴더의 파일로 두고 → `ledger rulings --report <보고 파일> --ledger <원장 사본> --out <판정 파일>`(보고에도 원장에도 판정이 없으면 「판정 줄 — 셀 수 없음」 을 보인다) → 에픽 브랜치에 기본 브랜치를 merge 해 받는 곳 규칙이 최신 로드맵을 보게 한 뒤 `python3 "<SD>"/scripts/check_bundle_coverage.py --impl <설계문서> <AC 보고 파일>`(계획을 나눴으면 `--acs`)의 경고를 사용자에게 보인다 → `ledger write-sections --spec <설계문서> --plan <계획> --rulings <판정 파일> --impl-line "<대조 첫 줄>" --counts "<AC n개 중 …>"` → 에픽 worktree 에서 커밋 · push → `gh pr create` 로 PR 을 열고 번호를 `ledger add --section PR` 로 적는다(`gh` 가 없으면 PR 을 열 명령을 사용자에게 준다).
- 부를 skill: writing-plans 가 권한 실행 방식(`superpowers:subagent-driven-development` · `superpowers:executing-plans`) — 구현 agent 안에서.
- 기록: 「설계에 없던 결정」 을 가른 결과와 이유 · 판정 보관본(`## 판정` 아래 `### <계획>`) · `## 구현 대조 — <계획>` → 설계문서. 하위가 그 브랜치에서 일하는 중이면 바로 쓰지 않고 `ledger add --section "쌓인 기록"` 으로 쌓았다가 돌아온 뒤 `ledger flush` 로 한 번에 옮겨 커밋한다 — 같은 worktree 에 두 writer 를 두지 않는다.
- 기계 상태: `## 실행 원장`(에픽 · 계획 · 원장 경로 · 읽은 줄) · `## PR` · `## 살아 있는 agent`(구현 agent) · `## 쌓인 기록`.

### 5. 머지 전 확인
- 기본값: PR 마다(문서만 고친 PR 도 — 모델이 읽는 skill · reference · 템플릿 · 리뷰어 프로필은 문서로 치지 않는다) 스위트 대조 → 통합 리뷰 → 리뷰 뒤 반영 → 완료 전 확인을 한다. 건너뛴 확인은 무엇을 왜 건너뛰었는지 적는다.
- 판단:
  - 스위트 대조: `python3 "<SD>"/scripts/merge_check.py run --roadmap <로드맵> --branch <브랜치> --keep-merged`. 종료 코드 1(새 실패)이면 `superpowers:systematic-debugging` 으로 원인을 찾아 고치거나 이유를 적고, 4(이름으로 가르지 못한 단위)면 그 줄을 사용자에게 보이고, 5(다른 대조가 도는 중)면 끝난 뒤 다시 돌고, 6(테스트 명령을 모른다)이면 사용자에게 한 번 물어 기계 상태 `## 레포 설정` 에 임시로 둔 뒤 다음 로드맵 수정 PR 에서 frontmatter `test_command` 로 올리고, 7(테스트 없음)이면 「스위트 대조 없음」 을 알리고 통합 리뷰만 한다. 하위가 본 실패가 이 대조에서 사라지면 경합으로 보고 알린다.
  - 통합 리뷰: `ledger review-pack --roadmap <로드맵> --epic <에픽> --branch <브랜치> --merged <합친 사본>` 이 이 PR diff · 열린 다른 에픽 diff · 충돌 미리 보기 · 앞선 인계 절을 한 폴더에 모은다. 그 폴더와 `superpowers:requesting-code-review` 의 리뷰 요청 틀로, 쓰기 도구가 없는 통합 리뷰어(지휘자 skill 본문의 dispatch 자리)를 로드맵 frontmatter `review_model`(없으면 세션 모델)로 부른다 — 이음매가 여럿이면 여럿을 동시에. 지적은 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눠 PR 본문 `## 통합 리뷰 인계` 절에 담당 에픽과 함께 적는다. 뒤 에픽의 통합 리뷰는 앞선 인계 절의 항목이 실제로 고쳐졌는지 확인한다. `gh` 가 없거나 GitHub 레포가 아니면 설계문서 `## 미룸` 표와 `## 지휘 기록` 에 적고 알린다.
  - 리뷰 뒤 반영: 고침은 `superpowers:receiving-code-review` 로 받는다. 동작 · 락 · 보안 경계 · 리뷰어 프로필을 바꾼 수정은 매번 좁은 재리뷰를 받고, 좁은 재리뷰는 PR 하나에 두 번까지다 — 첫 재리뷰를 보내기 전에 멈출 조건(남는 지적을 잔여로 공시하고 넘길 곳)을 PR 본문에 적는다. 동작을 바꾸지 않는 수정은 PR 본문에 「리뷰 뒤 반영(리뷰 라운드를 거치지 않았다)」 으로 적는다.
  - 끝으로 `superpowers:verification-before-completion`. 릴리스 번호는 이때 정한다(먼저 머지되는 쪽이 낮은 번호). 머지 명령 줄만 준비하고 머지는 사용자가 한다. 리뷰가 끝나면 합친 사본과 리뷰 묶음을 `ledger cleanup` 으로 지운다.
- 부를 skill: `superpowers:systematic-debugging` · `superpowers:requesting-code-review`(틀) · `superpowers:receiving-code-review` · `superpowers:verification-before-completion`.
- 기록: 건너뛴 확인과 이유 · 「리뷰 뒤 반영」 → PR 본문과 그 에픽 설계문서 `## 지휘 기록`.
- 기계 상태: `## 자원`(합친 사본 · 리뷰 묶음 · 통합 리뷰어) · `## 레포 설정`(물어 얻은 값).

### 6. 머지 뒤
- 기본값: 머지를 확인하면(상태 계산의 「머지됨」) 열린 에픽 브랜치마다 기본 브랜치를 merge 하고 스위트 대조를 다시 돈다. 남은 에픽을 재평가하고, 바뀔 때만 재분해 절차(`redecompose.md`)로 사용자 승인 뒤 로드맵 수정 PR 을 연다. 머지된 에픽의 worktree 는 `ledger cleanup-check` 뒤 `ledger cleanup` 으로 지운다 — 남은 것이 있으면 보이고 묻는다. 브랜치는 지우지 않는다.
- 판단: 그 브랜치에서 agent 가 일하고 있으면 직접 merge 하지 않는다 — 돌아올 때까지 기다리거나, 다음 task 경계에서 merge 하라고 그 agent 에 전한다. merge 가 충돌하면 그 에픽만 멈추고 알린다. 받는 에픽이 머지되면 넘긴 항목이 처리됐는지 받은 쪽 설계문서의 번호 대조 · AC 보고 · 통합 리뷰로 확인한다. 넘김의 받는 곳이 `없음` 이거나 로드맵에 없는 이름이면(화면의 「받는 곳 없음」) 맡을 에픽을 제안하고, 그 에픽 범위에 없으면 재분해 절차로 사용자 승인 뒤 로드맵에 넣는다. 맡을 에픽이 없으면 GitHub 이슈(`#<n>`)를 받는 곳으로 쓸 수 있으나, 이슈를 새로 만드는 것은 그때마다 묻는다.
- 부를 skill: 없음.
- 기록: 넘김 확인은 `- 넘김 확인 · <준 에픽> · <키> · <근거>` 꼴(키는 `conductor_state.confirm_line` 이 만든다)로 — 받는 에픽이 아직 머지 전이면 그 설계문서 `## 지휘 기록` 에, 이미 머지됐으면 `ledger add --section "쌓인 기록"` 으로 쌓아 다음 로드맵 수정 PR 본문 `## 지휘 기록` 절에 싣는다(`ledger pending`).
- 기계 상태: `## 쌓인 기록` · `## 자원`(지운 worktree 빼기).

### 7. 끝
- 기본값: 모든 에픽이 머지되면 끝에서 끝 확인 — 기본 경로(인터뷰 → 분해 → 에픽 설계 → spec-review → 계획 · 구현 대조 → 작업 목록 · 상태줄)와 설계 흐름이 아닌 에픽의 경로를 실제 명령으로 걷는다. 그때 품질 게이트(`/quality-gates:quality-pipeline`)를 한 번, 로드맵 시작 커밋부터 지금 기본 브랜치까지 돌린다.
- 판단: 품질 게이트가 범위 입력을 받는지는 그 skill 의 인자 안내로 정한다 — 받지 않으면 품질 게이트 없이 가고 그 사실을 알린다. 지적은 후속 PR 하나로. 넘김이 모두 처리됐는지 `python3 "<SD>"/scripts/control_plane.py show <로드맵> <에픽>` 의 열린 넘김으로 확인하고, 쌓인 기록이 남았으면 기록만 담은 로드맵 수정 PR 로 싣는다. 쓴 자원을 `ledger resources` · `ledger orphans` 로 보고 정리한 뒤 표지를 푼다(`ledger release`).
- 부를 skill: `/quality-gates:quality-pipeline`(범위 입력이 있을 때).
- 기록: 끝에서 끝 확인 결과 · 품질 게이트를 건너뛴 사실 → 마지막 로드맵 수정 PR 본문 `## 지휘 기록`.
- 기계 상태: 비운다(남은 자원 · agent · 쌓인 기록이 없을 때).

### /compact 시점
에픽 하나의 spec 리뷰가 끝나 계획 agent 를 보낸 직후처럼 끊기 좋은 자리에서 맥락이 무거우면, 기록(설계문서 절)을 커밋하고 기계 상태를 저장한 뒤 두 줄을 준다 — `/compact` 와 `/spec-distill:epic-conductor <로드맵>`. 압축은 사용자만 한다. 압축 뒤에는 걸음 1 부터 한다.

### 알림
사람 답이 없어 에픽이 멈췄을 때와 모두 끝났거나 더 갈 일이 없을 때만 알림 도구(`PushNotification`)를 보낸다. <M7 결과로 고른 문장 — 위 설명>
~~~

- [ ] **Step 4: 손 절차 걸음 2 · 3 의 옮겨 가는 길을 실측에 맞춘다**

손 절차 걸음 2 의 문장 「지휘 세션은 어느 worktree 에도 속하지 않은 메인 체크아웃(`git worktree list` 의 첫 줄)에 머문다 — worktree 격리로 시작됐으면 시작할 때 그 사실을 알리고, 그 worktree 를 떠날 수 있는지(하니스의 worktree 나가기)를 먼저 재 본다. 떠날 수 없으면 다른 에픽의 spec 리뷰는 그 에픽 담당 agent 를 거쳐(4 의 두 부분 반환) 하고 그 사실을 알린다 — 사용자에게 다른 세션을 열라고 하지 않는다.」 를 아래로 바꾼다(기존 락의 `메인 체크아웃` · `worktree 를 떠날 수 있는지` · `다른 에픽의 spec 리뷰는 그 에픽 담당 agent 를 거쳐` 를 지킨다):

```markdown
지휘 세션의 기본 자리는 어느 worktree 에도 속하지 않은 메인 체크아웃(`git worktree list` 의 첫 줄)이다. worktree 안에서 시작됐으면 시작할 때 그 사실을 알린다 — 그 자리에서도 지휘한다. 에픽 worktree 로는 하니스의 worktree 들어가기(경로 지정)로 옮겨 가고, 볼 일을 마치면 앞 자리로 돌아온다 — 옮기기 전에 지금 자리의 쓰기(커밋 포함)를 끝낸다. 하니스로 옮겨 갈 수 없으면(하니스 worktree 폴더 밖 등) 메인 체크아웃에서 셸의 작업 폴더를 옮기고, worktree 를 떠날 수 있는지(하니스의 worktree 나가기 · 들어가기)마저 막히면 다른 에픽의 spec 리뷰는 그 에픽 담당 agent 를 거쳐(4 의 두 부분 반환) 하고 그 사실을 알린다 — 사용자에게 다른 세션을 열라고 하지 않는다. 에픽 worktree 는 하니스 worktree 폴더 아래에 `git worktree add` 로 만든다(worktree 안에 있는 세션은 하니스의 새 worktree 만들기를 쓸 수 없다).
```

손 절차 걸음 3 의 「부르기 전에 그 에픽 worktree 로 옮겨 가(셸의 작업 폴더를 그 worktree 로)」 를 「부르기 전에 그 에픽 worktree 로 옮겨 가(2 의 길 — 하니스의 들어가기, 안 되면 셸의 작업 폴더)」 로 바꾼다. 같은 걸음의 「그다음 메인 체크아웃으로 돌아온다」 는 글자를 지키고 바로 뒤에 「(worktree 안에서 시작한 세션이면 앞 자리로)」 를 더한다.

- [ ] **Step 5: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_conducting_loop.sh 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_conducting_reference.sh 2>&1 | tail -3 && bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | tail -2 && bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -2 && bash shared/tests/test_no_new_duplication.sh 2>&1 | tail -2 && bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh 2>&1 | tail -2`
Expected: 실패 0. 손 절차 락(`test_conducting_reference.sh`)이 지휘 순환 절의 글을 손 절차로 오인하면 — `man_of` 는 `## 손으로 따르는 절차` 절만 읽으므로 그렇지 않아야 한다 — 그 단언이 아니라 절 머리를 확인한다. 중복 락이 손 절차와 지휘 순환의 같은 20줄을 잡으면 지휘 순환 쪽 문장을 줄여 손 절차를 가리킨다.

- [ ] **Step 6: 커밋**

```bash
git commit -m "docs(spec-distill): 지휘 순환 걸음 1~7 — 기본값 · 판단 · 부를 skill · 기록 · 기계 상태, 옮겨 가는 길 실측 반영

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/references/conducting.md plugins/spec-distill/tests/test_conducting_loop.sh plugins/spec-distill/tests/test_conducting_reference.sh
git show --stat HEAD   # 파일 셋
```

---

### Task 11: 진입 skill `epic-conductor` · 통합 리뷰어 agent (AC15 · AC44 · AC45 · 결정 B · D)

**Files:**
- Create: `plugins/spec-distill/skills/epic-conductor/SKILL.md`
- Create: `plugins/spec-distill/agents/integration-reviewer.md`
- Modify: `shared/entry/check_invocation_surface.py` (`ENTRY_SKILLS` 한 줄)
- Modify: `shared/tests/test_invocation_surface.sh` (합성 리포 `ENTRY` 한 항목)
- Create: `plugins/spec-distill/tests/test_epic_conductor_skill.sh`

**Interfaces:**
- Consumes: Task 4 의 `ledger roadmaps` · `claim` · `approval` · `approve`, Task 9 · 10 의 두 reference, Task 1 M9.
- Produces: `/spec-distill:epic-conductor [<로드맵 경로>]`. dispatch 자리 하나(`subagent_type: "spec-distill:integration-reviewer"`)와 그 처분 줄. agent 입력 칸 다섯(`review_request` · `merged_copy` · `pr_diff` · `open_diffs` · `handoffs`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_epic_conductor_skill.sh`:

```bash
#!/usr/bin/env bash
# R5 계획 3 — 진입 skill epic-conductor(AC15 · AC44)와 통합 리뷰어 agent(결정 D)의 정적 락.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_epic_conductor_skill.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SK="$ROOT/plugins/spec-distill/skills/epic-conductor/SKILL.md"
AG="$ROOT/plugins/spec-distill/agents/integration-reviewer.md"
[ -f "$SK" ] && ok "SKILL.md 가 있다" || { no "SKILL.md 가 없다"; finish; exit $?; }
[ -f "$AG" ] && ok "integration-reviewer.md 가 있다" || no "integration-reviewer.md 가 없다"
HEAD="$(python3 "$ROOT/shared/entry/check_invocation_surface.py" --print-head spec-distill epic-conductor)"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  grep -qxF -- "$line" "$SK" && ok "머리 줄: $line" || no "머리 줄이 없다: $line"
done <<< "$HEAD"
assert_file_grep "$SK" '^cost_class: high$' "cost_class: high"
fm() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }
assert_eq "$(fm "$SK" | grep -c '^name: epic-conductor$')" "1" "name 이 디렉토리 이름과 같다"
BODY="$(cat "$SK")"
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^##/{exit} f' "$SK"; }
for lit in 'conductor_ledger.py" roadmaps' '여럿이면 `AskUserQuestion`'; do
  assert_contains "$(sec '### 2. 로드맵 정하기')" "$lit" "로드맵 정하기: $lit"
done
for lit in 'worktree 안에서 시작했다' '여기서도 지휘한다' 'state_path.py" session-id' 'conductor_ledger.py" claim' '읽기 전용'; do
  assert_contains "$(sec '### 3. 자리 · 세션 · 표지')" "$lit" "자리 · 세션 · 표지: $lit"
done
APP="$(sec '### 4. 시작 승인')"
for lit in '남은 에픽' 'agent 약' '라운드마다 부르는 리뷰어 agent' 'conductor_ledger.py" approval' '`AskUserQuestion`' 'conductor_ledger.py" approve' \
           '승인 전에는 agent 를 보내지 않는다' '이름 붙인 예외' '규모 줄이 글자 그대로 같을 때만'; do
  assert_contains "$APP" "$lit" "시작 승인: $lit"
done
# 시작 승인 순서: 규모 공시 → approval → (rc 1 이면) AskUserQuestion → approve
order="$(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys
t = sys.argv[1]
ks = ["규모 줄", "conductor_ledger.py\" approval", "`AskUserQuestion`", "conductor_ledger.py\" approve "]
ix = [t.find(k) for k in ks]
print("yes" if min(ix) >= 0 and ix == sorted(ix) else "no")' "$APP")"
assert_eq "$order" "yes" "시작 승인: 규모 → approval → 질문 → approve 순서"
assert_contains "$BODY" 'Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md' "conducting.md 를 읽는다"
assert_contains "$BODY" 'Read ${CLAUDE_PLUGIN_ROOT}/references/conductor-dispatch.md' "conductor-dispatch.md 를 읽는다"
assert_contains "$BODY" '손으로 따르는 절차' "꺼짐: 손 절차를 가리킨다"
assert_file_grep "$SK" '^\| `\[devbrew-entry\] disabled …` \| .*손으로 따르는 절차.*멈춘다 \|$' "감시줄 표의 꺼짐 행이 손 절차를 가리키고 멈춘다"
assert_contains "$BODY" 'subagent_type: "spec-distill:integration-reviewer"' "통합 리뷰어 dispatch 자리"
assert_not_contains "$BODY" '다른 세션을 열어' "다른 세션을 열라는 말이 없다"
# agent — 쓰기 도구 없음(Law 2) · 역할 문장 · 입력 칸
assert_eq "$(fm "$AG" | grep -E '^tools:' )" "tools: Read, Grep, Glob" "agent tools 는 Read, Grep, Glob 뿐"
assert_eq "$(fm "$AG" | grep -cE '^(disallowedTools|allowed-tools|allowedTools):' || true)" "0" "agent 에 거부 목록 · 오기 필드가 없다"
for lit in 'You are the integration reviewer' 'You are responsible for' 'You are NOT responsible for'; do
  assert_file_grep "$AG" "$lit" "agent 역할: $lit"
done
for t in review_request merged_copy pr_diff open_diffs handoffs; do
  assert_eq "$(fm "$AG" | grep -c "tag: $t$")" "1" "agent 입력 칸 $t"
done
for f in test_invocation_surface.sh test_dispatch_disposition.sh test_agent_input_slots.sh test_plain_language_block.sh \
         test_skill_reference_pointers.sh test_plugin_root_no_cwd_fallback.sh test_skill_body_no_positional_tokens.sh test_inline_python_isolated.sh; do
  out="$(bash "$ROOT/shared/tests/$f" 2>&1)"; rc=$?
  assert_eq "$rc" "0" "공유 락 $f 가 통과한다"
  [ "$rc" -eq 0 ] || printf '%s\n' "$out" | grep -E '✗|RED|FAIL' | head -5
done
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_epic_conductor_skill.sh && bash plugins/spec-distill/tests/test_epic_conductor_skill.sh 2>&1 | tail -3`
Expected: `SKILL.md 가 없다`.

- [ ] **Step 3: 호출 표면에 등록한다**

`shared/entry/check_invocation_surface.py` 의 `ENTRY_SKILLS` 에 `("spec-distill", "roadmap-status"),` 다음 줄로 `("spec-distill", "epic-conductor"),` 를 더한다. `shared/tests/test_invocation_surface.sh` 의 합성 리포 `ENTRY = [` 목록의 `("spec-distill", "roadmap-status", False),` 뒤에 `("spec-distill", "epic-conductor", False),` 를 더한다. 그다음 `python3 shared/entry/check_invocation_surface.py --print-head spec-distill epic-conductor` 를 돌려 머리 줄들을 받아 둔다.

- [ ] **Step 4: agent 를 쓴다**

`plugins/spec-distill/agents/integration-reviewer.md`:

~~~markdown
---
name: integration-reviewer
description: >
  Use this agent before a roadmap epic's PR merges to review the seams between epics. Given the merged copy
  (default branch + this branch), this PR's diff, the other open epics' diffs with a conflict preview, and earlier
  handoff notes, it reports seam defects split into 「이 PR 이 고침」 and 「뒤 에픽이 고침」. Read-only by design
  (Law 2 frontmatter scoping) — it never edits files.

  <example>Context: the conductor finished the suite comparison for a PR and assembled a review pack.
  user: "에픽 사이 이음매를 봐줘"
  assistant: "I'll dispatch integration-reviewer with the review request, the merged copy, and the pack files."</example>
tools: Read, Grep, Glob
color: cyan
cost_class: medium
input_slots:
  - tag: review_request
    var: REVIEW_REQUEST
    kind: task
  - tag: merged_copy
    var: MERGED_COPY
    kind: repo_context
  - tag: pr_diff
    var: PR_DIFF
    kind: artifact
  - tag: open_diffs
    var: OPEN_DIFFS
    kind: artifact
  - tag: handoffs
    var: HANDOFFS
    kind: artifact
---

You are the integration reviewer for a roadmap whose epics merge one PR at a time. You are responsible for finding defects that live between epics — seams a single-epic review cannot see. You are NOT responsible for re-reviewing each epic's internal correctness, for fixing anything, or for deciding merge order.

## 입력

- `<review_request>` — 리뷰 요청 틀을 채운 글(무엇을 · 왜 · 어디부터 어디까지).
- `<merged_copy>` — 기본 브랜치에 이 브랜치를 합친 사본의 절대경로. 이 사본의 파일을 읽어 판단한다.
- `<pr_diff>` — 이 PR diff 파일 경로. `<open_diffs>` — 열린 다른 에픽 diff 파일들과 충돌 미리 보기 파일의 경로. `<handoffs>` — 앞선 PR 들의 `## 통합 리뷰 인계` 를 모은 파일 경로.

## 볼 이음매

1. 옮겨지거나 이름이 바뀐 것의 import · 호출 — 다른 에픽의 diff 가 옛 이름을 쓰는가.
2. 같은 파일을 고친 에픽들의 순서와 문구 — 머지 순서에 따라 한쪽 문구가 되살아나거나 사라지는가.
3. 상태 · 경로 규약 — 한 에픽이 바꾼 경로 · 형식을 다른 에픽이 옛 꼴로 읽는가.
4. 합계 제약 — 줄 상한 · 버전 · 개수처럼 따로는 맞고 합치면 넘는 것.
5. 테스트가 못 잡는 되살아난 옛 문구, 리뷰어 프로필의 규칙 제거 · 기준 완화(사용자 결정이 앞선 인계에 있는가).
6. 앞선 인계의 「뒤 에픽이 고침」 항목이 이 PR 에서 실제로 고쳐졌는가.

## 내는 것

지적마다 한 블록:

```
- 이음매: <위 1~6 의 이름>
  자리: <합친 사본 기준 경로:줄>
  무엇이 깨지나: <한두 문장>
  고칠 곳: 이 PR 이 고침 | <에픽> 이 고침
  근거: <읽은 파일과 줄>
```

지적이 없으면 「이음매 지적 없음」 한 줄과 본 이음매 목록을 낸다. 확인하지 못한 것은 「확인 못 함 — <이유>」 로 따로 적는다 — 없는 것과 확인 못 한 것은 다르다.
~~~

- [ ] **Step 5: SKILL.md 를 쓴다**

머리 줄(`---` 안의 `name` · `description` · `cost_class` · `argument-hint` · `allowed-tools`)과 사전 검사 줄 · `## 진입 단계` 는 Step 3 의 `--print-head` 출력을 그대로 쓰고, 아래 본문을 채운다. `<!-- plain-language:begin -->` 블록은 `skills/roadmap-status/SKILL.md` 의 것을 바이트 그대로 복사한다. 펜스의 첫 줄(플러그인 루트 가드)은 `skills/roadmap-status/SKILL.md` 펜스의 첫 줄을 글자 그대로 복사한다.

~~~markdown
---
name: epic-conductor
description: >
  사용자가 `/spec-distill:epic-conductor [<로드맵 경로>]` 로 부른다. 승인된 로드맵의 에픽들을 이 세션이 끝까지 지휘한다 —
  다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇고, 사람 몫(설계 · spec 승인 · 계획의 설계에 없던 결정)은
  이 세션에서 한 번에 한 에픽씩 배경과 함께 묻고, 계획 · 구현 · 머지 전 확인은 하위 agent 와 스크립트로 병렬로 끝까지 간다.
cost_class: high
argument-hint: "[<로드맵 경로>]"
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill epic-conductor)
---

# epic-conductor — 로드맵 지휘

<!-- plain-language:begin -->
(roadmap-status 의 블록을 바이트 그대로)
<!-- plain-language:end -->

지휘의 걸음은 두 reference 가 담는다 — 이 본문은 진입 · 시작 승인 · 차례 · 통합 리뷰어 dispatch 자리만 둔다.

!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill epic-conductor`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 2 로 간다. 그 줄의 `root=` 값을 아래에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고, 지휘자가 꺼져 있으니 이 플러그인 references 폴더의 지휘 절차 파일(conducting.md) 끝 절인 손으로 따르는 절차를 따르라고 한 줄로 알린 뒤 멈춘다 |
| `[devbrew-entry] error …` | `[spec-distill] epic-conductor 사전 검사 실패 — <reason= 값>. 지휘하지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] epic-conductor 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 지휘하지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] epic-conductor 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 지휘하지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다.

### 2. 로드맵 정하기

받은 인자(`$ARGUMENTS`)를 본다. 토큰이 하나면 로드맵 경로다 — 영문자 · 숫자 · `.` `_` `/` `@` `+` `-` 로만 되어 있고 `-` 로 시작하지 않아야 한다(아니면 셸에 넘기지 않고 `[spec-distill] epic-conductor 인자는 로드맵 경로 하나다 — 받은 것: <인자>.` 를 내고 멈춘다). 절대경로면 `root=` 기준 상대경로로 바꿔 쓴다. 비었으면 아래 펜스로 찾는다(`<root>` 는 감시줄 `root=` 값).

```bash
<roadmap-status 펜스 첫 줄 그대로>
cd "<root>" && python3 "$SD/scripts/conductor_ledger.py" roadmaps
```

줄마다 `<경로><탭><끝나지 않은 에픽 수>` 다. 하나면 그것, 여럿이면 `AskUserQuestion` 으로 고르게 한다. 종료 코드 2(없음)면 그 줄을 보이고 멈추고, 3 이면 사유를 보이고 멈춘다.

### 3. 자리 · 세션 · 표지

```bash
<roadmap-status 펜스 첫 줄 그대로>
cd "<root>" && echo "toplevel=$(git rev-parse --show-toplevel)" && git worktree list --porcelain | head -1
sid="$(python3 "$SD/scripts/state_path.py" session-id)" || sid=""
[ -n "$sid" ] && python3 "$SD/scripts/conductor_ledger.py" claim --roadmap "<로드맵>" --session "$sid"
echo "session=${sid:-없음}"
```

- `toplevel=` 이 첫 worktree 줄(메인 체크아웃)과 다르면 「이 세션은 worktree(<경로>) 안에서 시작했다 — 여기서도 지휘한다. 에픽 worktree 로는 하니스의 worktree 옮겨 가기로 오간다」 를 한 줄로 알린다. 새 세션을 열라고 하지 않는다.
- `session=없음` 이면 표지를 잡을 수 없다 — 「세션 id 를 얻지 못해 기계 상태를 쓸 수 없다 — 읽기 전용으로 지도만 보인다」 를 알리고 `control_plane.py show <로드맵>` 을 보인 뒤 멈춘다.
- `claim` 이 종료 코드 5 면 다른 세션이 지휘 중이다 — 이 세션은 읽기 전용이다. 지도를 보이고, 넘겨받을지 `AskUserQuestion` 으로 묻는다(「읽기만 (권장)」 · 「넘겨받기 — 그 세션은 쓰기를 멈춘다」). 넘겨받기면 `conductor_ledger.py takeover` 뒤 4 로 간다.

### 4. 시작 승인

`python3 "$SD/scripts/control_plane.py" show "<로드맵>"` 으로 남은 에픽과 의존 순서를 읽어 규모 줄 하나를 만든다 — `남은 에픽 <n>(<번호 목록>) · agent 약 <n> · 순서 <번호 → 번호 …>`. agent 수는 에픽마다 계획 1 · 구현 1(실행 방식 안의 agent 는 task 수에 따라 더) · 통합 리뷰 1 이상에, 이 세션의 spec 리뷰가 라운드마다 부르는 리뷰어 agent(탐지 · 재비판 둘 이상, 라운드 상한까지)를 더한 대략이다. 같은 상태에서는 같은 줄이 나오게 이 꼴 그대로 쓴다.

규모 줄을 보이고 `python3 "$SD/scripts/conductor_ledger.py" approval --roadmap "<로드맵>" --session "$sid" --scale "<규모 줄>"` 을 돌린다.
- 종료 코드 0(「공시만 — …」): 그 줄을 보이고 5 로 간다.
- 종료 코드 1(「승인 필요 — …」): `AskUserQuestion` 으로 묻는다 — 「이 규모로 지휘 시작 (권장)」 · 「멈춤」. 시작이면 `python3 "$SD/scripts/conductor_ledger.py" approve --roadmap "<로드맵>" --session "$sid" --scale "<규모 줄>"` 뒤 5 로, 멈춤이면 표지를 풀고(`release`) 멈춘다.

승인 전에는 agent 를 보내지 않는다. 그 뒤의 dispatch 는 띄우기 전에 규모만 알리고 간다.

**`cost_class: high` 의 이름 붙인 예외 — 같은 세션 이어 부르기.** 레포 규칙은 high skill 이 쓰기 전에 `AskUserQuestion` 으로 승인받게 한다. 이 skill 은 같은 세션에서 이미 받은 승인이 기계 상태 `## 시작 승인` 에 있고 규모 줄이 글자 그대로 같을 때만 그 승인을 다시 쓰고, 묻는 대신 공시한다(압축 뒤 이어 부를 때마다 같은 질문을 되풀이하지 않게). 규모가 바뀌었거나 다른 세션이면 다시 묻는다.

### 5. 지휘 순환

```
Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md
Read ${CLAUDE_PLUGIN_ROOT}/references/conductor-dispatch.md
```

두 파일의 `<SD>` 는 위 `Read` 줄의 플러그인 폴더(이 skill 이 쓰는 spec-distill 의 절대경로)다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

`conducting.md` 의 `## 지휘 순환` 걸음 1~7 을 차례로 돈다 — 1 맞추기 · 2 사람 몫 모으기 · 3 다음 일 고르기와 보내기 · 4 돌아오기 · 5 머지 전 확인 · 6 머지 뒤 · 7 끝. 하위에게 보내는 글은 `conductor-dispatch.md` 의 틀이고 그 파일의 처분 줄을 보내는 자리마다 단다. 같은 파일의 손으로 따르는 절차는 지휘자를 껐을 때의 것이다 — 이 skill 안에서는 따르지 않는다.

### 6. 통합 리뷰어

걸음 5 의 통합 리뷰는 아래 자리에서 부른다. `REVIEW_REQUEST` 는 `superpowers:requesting-code-review` 의 리뷰 요청 틀(`code-reviewer.md`)을 이 PR 로 채운 글, `MERGED_COPY` 는 `merge_check.py --keep-merged` 가 남긴 합친 사본, 나머지 셋은 `conductor_ledger.py review-pack` 이 만든 폴더의 파일 경로다. 그 skill 이 스스로 부르는 agent 는 쓰기 도구를 가져 쓰지 않는다 — 틀만 빌린다. 로드맵 frontmatter `review_model` 이 이 dispatch 의 모델 칸이 받는 이름이면 그 값을 주고, 아니면 모델 칸을 빼 세션 모델로 가며 그 사실을 알린다. 이음매가 여럿이면 여럿을 동시에 부른다. 통합 리뷰 지적 전부를 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눠 PR 본문 인계 절과 사용자에게 보인다.

```
Agent(
  description: "Integration review of epic seams",
  subagent_type: "spec-distill:integration-reviewer",
  // **처분** — consumer=orchestrator · fail-closed · disclosure=통합 리뷰 지적 전부를 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눠 PR 본문 인계 절과 사용자에게 보인다
  model: "<review_model — 받는 이름일 때만>",
  prompt: "<review_request>${REVIEW_REQUEST}</review_request>
    <merged_copy>${MERGED_COPY}</merged_copy>
    <pr_diff>${PR_DIFF}</pr_diff>
    <open_diffs>${OPEN_DIFFS}</open_diffs>
    <handoffs>${HANDOFFS}</handoffs>"
)
```

## 보이기

사람에게 쓰는 글은 위 쉬운 말 규칙을 따른다. 질문마다 첫 줄에 에픽 이름을 쓰고, 하위가 돌려보낸 사람 자리는 `conductor-dispatch.md` 의 `## 사람 자리` 대로 배경을 먼저 쉬운 말로 쓴 뒤 선택지를 원문 그대로 묻는다.
~~~

`<roadmap-status 펜스 첫 줄 그대로>` 두 자리는 실제 그 줄로 바꾼다(자리표를 남기지 않는다). `$ARGUMENTS` 는 위치 인자 락 밖이다(`$1` 류만 금지). 본문에 `$1` · `$2` 가 없는지 Step 6 이 공유 락으로 잰다.

- [ ] **Step 6: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh 2>&1 | tail -5`
Expected: 실패 0 — 그 안에서 공유 락 여덟(호출 표면 · dispatch 처분 · 입력 칸 · 쉬운 말 블록 · reference 포인터 · 플러그인 루트 · 위치 인자 · 인라인 python)이 모두 통과한다. dispatch 처분 락이 「앵커 수 ≠ dispatch 수」 로 빨개지면 `subagent_type` 줄 바로 아래 창 안에 처분 줄이 하나뿐인지, 설명 문단의 disclosure 문장이 처분 줄과 글자 그대로 같은지 본다.

- [ ] **Step 7: 커밋**

```bash
git commit -m "feat(spec-distill): 진입 skill epic-conductor — 시작 승인 · 같은 세션 예외 · 지휘 순환 · 쓰기 권한 없는 통합 리뷰어

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/skills/epic-conductor/SKILL.md plugins/spec-distill/agents/integration-reviewer.md shared/entry/check_invocation_surface.py shared/tests/test_invocation_surface.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh
git show --stat HEAD   # 파일 다섯
```

---
### Task 12: 지휘자를 가리키는 진입 안내 (AC31 의 「넘김 줄은 지휘자를 끈 경우에만」 · AC36 · AC37 · AC42 의 로드맵 갈래 · 결정 K)

§11 이 정한 대로 아직 없는 skill 을 가리키는 릴리스가 생기지 않게, 진입 안내는 지휘자 skill(Task 11)과 같은 PR 에서 바꾼다.

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` (나눈 일의 다음 세션 줄 한 줄과 바로 아래 설명 문단 — R10 예약과 겹침, 정보)
- Modify: `plugins/spec-distill/templates/roadmap-template.md` (`## 지휘 절차`)
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` (`## 지휘 절차`)
- Modify: `plugins/spec-distill/references/epic-handoff.md` (머리말 · 끝 문장)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (로드맵 에픽의 둘째 줄 문단 하나)
- Modify: `plugins/spec-distill/references/redecompose.md` (`## 5. 적용` 의 불릿 하나)
- Modify: `plugins/spec-distill/tests/test_decompose_surface.sh` (AC7 의 다음 세션 줄 단언 · 템플릿 지휘 절차 단언)
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh` (finishing 이 epic-handoff 를 가리키던 단언 한 줄)
- Create: `plugins/spec-distill/tests/test_entry_guidance.sh`

**Interfaces:**
- Consumes: Task 10 의 공유 문장 `실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.`
- Produces: 나눈 일의 다음 세션 줄 `` `/spec-distill:epic-conductor <roadmap-path>` `` · spec-review 의 `**로드맵 에픽이면 — 둘째 줄은 지휘자 호출.**` 문단 · 「계획 agent 의 입력(치지 않는다)」 머리.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_entry_guidance.sh`:

```bash
#!/usr/bin/env bash
# R5 계획 3 — 지휘자를 가리키는 진입 안내: 나눈 일의 다음 세션 줄(AC36) · 템플릿과 이 로드맵의 지휘 절차(AC37) ·
# 에픽 넘김 줄은 지휘자를 끈 경우에만(AC31) · spec-review 승인 게이트의 로드맵 갈래(AC42 · 결정 K) · 재분해 이력 문면.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_entry_guidance.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
FIN="$SD/skills/spec-interview/references/finishing.md"
TPL="$SD/templates/roadmap-template.md"
RMAP="$ROOT/docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"
EH="$SD/references/epic-handoff.md"
SR="$SD/skills/spec-review/SKILL.md"
RED="$SD/references/redecompose.md"
CD="$SD/references/conducting.md"
SHARED='실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.'
MARK='**다음 세션 줄 — 분해된 일 ①/② 공통**'
DLINE="$(awk -v m="$MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$FIN")"
assert_eq "$DLINE" '`/spec-distill:epic-conductor <roadmap-path>`' "AC36: 나눈 일의 다음 세션 줄이 지휘자 호출 한 줄"
assert_eq "$(grep -cF '이 로드맵의 지휘 절차대로 진행하라' "$FIN" || true)" "0" "AC36: 옛 지휘 절차 줄이 없다"
cond() { awk '$0=="## 지휘 절차"{f=1;next} f&&/^## /{exit} f' "$1"; }
for f in "$TPL" "$RMAP"; do
  C="$(cond "$f")"
  assert_contains "$C" '/spec-distill:epic-conductor' "AC37: ${f##*/} 지휘 절차가 지휘자 호출을 안내한다"
  assert_contains "$C" "$SHARED" "AC37: ${f##*/} 지휘 절차 4 의 뜻이 공유 문장과 같다"
  assert_contains "$C" '손으로 따르는 절차' "AC37: ${f##*/} 지휘자를 끈 경우의 손 절차를 가리킨다"
  assert_eq "$(printf '%s\n' "$C" | grep -cE '^[0-9]+\. ' || true)" "0" "AC37: ${f##*/} 지휘 절차에 옛 번호 걸음이 없다"
done
assert_eq "$(grep -cF -- "$SHARED" "$CD")" "1" "AC37: conducting.md 에 같은 문장이 한 번"
assert_contains "$(sed -n '1,5p' "$EH")" '지휘자를 껐거나' "AC31: 넘김 줄은 지휘자를 끈 경우(또는 사용자가 따로 진행할 때)에만"
assert_contains "$(sed -n '1,5p' "$EH")" '자기 brainstorming 입력으로 쓴다' "AC31: 지휘자는 넘김 줄을 사용자에게 주지 않는다"
assert_eq "$(grep -cF '지휘 세션이 붙여 넣는 줄' "$EH" || true)" "0" "넘김 줄 머리말: 재결정 전 표현이 없다"
assert_eq "$(grep -cF '새 세션(`/new`)의 첫 줄로' "$EH" || true)" "0" "넘김 줄 끝 문장: 새 세션을 전제하지 않는다"
RB="$(awk '/^\*\*로드맵 에픽이면 — 둘째 줄은 지휘자 호출\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f' "$SR")"
[ -n "$RB" ] && ok "AC42: spec-review 의 로드맵 갈래 문단이 있다" || no "AC42: 로드맵 갈래 문단이 없다"
for lit in '`roadmap:` 줄이 있으면' '`/spec-distill:epic-conductor <roadmap 절대경로>`' '계획 agent 의 입력(치지 않는다)' '`roadmap:` 줄이 없으면 위 줄 그대로다'; do
  assert_contains "$RB" "$lit" "AC42: $lit"
done
assert_contains "$(awk '/^## 5\. 적용/{f=1;next} f&&/^## /{exit} f' "$RED")" '고른 라벨을 글자 그대로' "재분해 5: 라벨만 고른 답의 --approval"
assert_contains "$(awk '/^## 5\. 적용/{f=1;next} f&&/^## /{exit} f' "$RED")" '「순서만」' "재분해 5: 순서만 바뀐 경우"
finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_entry_guidance.sh && bash plugins/spec-distill/tests/test_entry_guidance.sh 2>&1 | tail -5`
Expected: AC36 · AC37 · AC31 · AC42 단언이 실패.

- [ ] **Step 3: 나눈 일의 다음 세션 줄(finishing.md)**

`**다음 세션 줄 — 분해된 일 ①/② 공통**` 아래의 `` `@<roadmap-path> 이 로드맵의 지휘 절차대로 진행하라. …` `` 한 줄을 `` `/spec-distill:epic-conductor <roadmap-path>` `` 로 바꾸고, 바로 아래 설명 문단(「분해된 일이면 ①/② 의 둘째 줄은 …」)을 아래로 바꾼다. 그 밖의 줄(앞 문단의 「지휘 세션을 이 커밋이 기본 브랜치에 머지된 뒤 열라고」 문장 포함 — R10 몫)은 건드리지 않는다.

```markdown
분해된 일이면 ①/② 의 둘째 줄은 위 brief 줄 대신 이 줄이다 — 지휘자가 이 세션에서 로드맵의 에픽들을 끝까지 이끈다. `<roadmap-path>` 는 로드맵의 절대경로로 치환한다 — 치환하지 못하거나 경로에 공백이 있으면 줄을 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. 로드맵: <로드맵 경로>. /spec-distill:epic-conductor 뒤에 이 로드맵 경로를 직접 붙여 부른다.` 한 줄을 보인 뒤 멈춘다. 나누지 않은 일의 둘째 줄은 위 brief 줄 그대로다.
```

- [ ] **Step 4: 템플릿과 이 로드맵의 `## 지휘 절차`**

`templates/roadmap-template.md` 의 `## 지휘 절차` 절 본문(머리 다음부터 `## 결정 기록` 앞까지)을 아래로 바꾼다:

```markdown
이 로드맵은 지휘자가 이끈다 — `/spec-distill:epic-conductor {{ROADMAP}}`. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. 지휘자를 껐으면(`DEVBREW_SPEC_DISTILL_DISABLE=1`) spec-distill 의 `references/conducting.md` 끝 절 「손으로 따르는 절차」 를 따른다.

- 사람 몫(brainstorming · spec 승인 · 계획의 설계에 없던 결정)은 지휘 세션이 한 번에 한 에픽씩 배경과 함께 묻는다.
- 실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- 머지는 사용자가 한다.
```

이 로드맵 `roadmap.md` 의 `## 지휘 절차` 본문도 같은 글로 바꾸되 `{{ROADMAP}}` 은 `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` 로 쓴다. 바꾸기 전에 옛 절에만 있는 인용을 잰다 — 사라지면 `tests/test_roadmap_migrate.py` 의 「옮기기 전부터 있던 인용이 사라지지 않는다」 가 빨개진다:

Run: `python3 -I -c 'import sys; sys.path.insert(0, "plugins/spec-distill/scripts"); import roadmap_model as M, subprocess
p = "docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md"
t = open(p, encoding="utf-8").read(); a = t.index("## 지휘 절차"); b = t.index("## 결정 기록")
pre = subprocess.run(["git", "show", "ed0da79f:" + p], capture_output=True, text=True).stdout
keep = [q for q in M.quotes(t[a:b]) if q in M.quotes(pre) and q not in M.quotes(t[:a] + t[b:])]
print(" · ".join(dict.fromkeys(keep)))'`

나온 인용이 있으면 새 절 끝에 한 줄을 더한다 — `- 손 절차로 옮긴 옛 지휘 절차의 인용: <나온 줄 그대로>`. `PRE`(`ed0da79f`)는 `test_roadmap_migrate.py` 의 상수와 같아야 한다 — 다르면 그 상수를 쓴다.

- [ ] **Step 5: 에픽 넘김 줄의 머리말과 끝 문장(epic-handoff.md)**

첫 문단의 첫 문장 「승인된 로드맵의 에픽 하나를 설계하는 세션을 열 때 지휘 세션이 붙여 넣는 줄이다.」 를 아래로 바꾼다:

```markdown
승인된 로드맵의 에픽 하나를 설계하는 세션의 첫 줄이다 — 지휘자를 껐거나(손 절차) 사용자가 에픽을 자기 세션에서 따로 진행하겠다고 할 때만 쓴다. 지휘자는 이 줄을 사용자에게 주지 않고 같은 내용을 자기 brainstorming 입력으로 쓴다.
```

끝 문단의 「새 세션(`/new`)의 첫 줄로 붙여 넣는다.」 를 「그 세션의 첫 줄로 붙여 넣는다.」 로 바꾼다. 넘김 줄 자체(인용 줄)와 자리표 절은 건드리지 않는다 — `tests/test_epic_handoff.sh` 의 순서 · 자리표 락.

- [ ] **Step 6: spec-review 승인 게이트의 로드맵 갈래(결정 K)**

`skills/spec-review/SKILL.md` 에서 다음 세션 줄의 설명 문단(「`<spec_path>` 는 세 자리 모두 … 노출하고, 두 줄을 따로 입력하라는 안내와 git 작업 트리 루트의 절대경로를 함께 낸다(규칙 1 · 7).」) 바로 다음, `- **①/② 의 정지 요건**` 불릿 앞에 한 문단을 넣는다:

```markdown
**로드맵 에픽이면 — 둘째 줄은 지휘자 호출.** 설계문서 frontmatter 에 `roadmap:` 줄이 있으면 ①/② 가 치게 하는 둘째 줄은 위 줄 대신 `/spec-distill:epic-conductor <roadmap 절대경로>` 다(`<roadmap 절대경로>` 는 `roadmap:` 값을 git 작업 트리 루트에 붙인 것) — 계획은 지휘자가 계획 agent 로 보낸다. 위 writing-plans 줄은 지우지 않고 「계획 agent 의 입력(치지 않는다)」 머리 아래 그대로 보인다 — 지휘자가 그 줄을 계획 agent 에게 넘긴다. 치환 규칙과 노출하지 못할 때의 문면은 위 줄과 같다. `roadmap:` 줄이 없으면 위 줄 그대로다.
```

`skills/spec-review/SKILL.md` 의 치환 안내 문장 · `Read` 줄 · 가드 줄은 건드리지 않는다(계획 2 의 축 3 · C5 락).

- [ ] **Step 7: 재분해 이력 문면(redecompose.md 5)**

`## 5. 적용` 의 첫 불릿(「바뀐 블록과 그 묶음만 다시 쓰고, …」) 다음에 불릿 하나를 넣는다:

```markdown
- 사용자가 선택지 라벨만 고르고 따로 적은 말이 없으면 `--approval` 에 고른 라벨을 글자 그대로 넘긴다 — 고른 라벨이 그 사용자의 말이다. 표가 블록 순서만 다르면 생성기는 바뀜에 「순서만」 을 적는다 — 그때 `--change` 사유에 무엇을 왜 다시 나눴는지 적는다.
```

- [ ] **Step 8: 뒤집힌 락을 고친다**

1. `tests/test_decompose_surface.sh` AC7: `case "$DLINE" in '`@<roadmap-path> 이 로드맵의 지휘 절차대로 진행하라.'*)` 를 `case "$DLINE" in '`/spec-distill:epic-conductor <roadmap-path>`')` 로, 메시지를 「분해된 일: 다음 세션 줄이 지휘자 호출」 로 바꾸고, 다음 줄의 `has "$DLINE" '사람에게 쓰는 글 규칙' …` 단언을 지운다(슬래시 명령 줄은 문장을 싣지 않는다 — 글 규칙은 지휘자 skill 안의 쉬운 말 블록이 맡는다). 같은 파일의 `for lit in '${CLAUDE_PLUGIN_ROOT}/references/epic-handoff.md 의 에픽 넘김 줄' '--bundle 과 그 묶음의 레포 루트 기준 상대경로'; do has "$DLINE" …` 묶음을 지운다.
2. 같은 파일 「R3 넘김」 절의 템플릿 지휘 절차 단언(`for lit in '`references/epic-handoff.md` 에 있는 에픽 넘김 줄' …` 과 그 아래 `case "$CONDUCT" in *'0 이 나오기 전에는…'`)을 아래로 바꾼다:

```bash
for lit in '/spec-distill:epic-conductor {{ROADMAP}}' '손으로 따르는 절차' '실행 방식은 writing-plans 가 권하는 방식이고, 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.'; do
  has "$CONDUCT" "$lit" "로드맵 템플릿 지휘 절차: $lit"
done
```

3. `tests/test_review_handoff_order.sh` 끝의 `assert_file_grep "$FIN" '\$\{CLAUDE_PLUGIN_ROOT\}/references/epic-handoff\.md' "finishing.md 가 에픽 넘김 줄 reference 를 가리킨다(AC2 · 고아 reference 방지)"` 를 아래로 바꾼다 — 고아 방지는 이제 손 절차가 진다(`test_conducting_reference.sh` 걸음 3 의 `` `epic-handoff.md` 의 에픽 넘김 줄 `` 단언):

```bash
assert_file_grep "$ROOT/plugins/spec-distill/references/conducting.md" 'epic-handoff\.md' "conducting.md 가 에픽 넘김 줄 reference 를 가리킨다(고아 reference 방지 — 나눈 일의 다음 세션 줄은 지휘자 호출이 됐다)"
```

- [ ] **Step 9: 통과를 확인한다**

Run: `for t in test_entry_guidance test_decompose_surface test_review_handoff_order test_epic_handoff test_seed_at_path_handoff test_next_session_command test_conducting_reference test_proceed_gate_adopters; do bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done; python3 -m unittest plugins/spec-distill/tests/test_roadmap_migrate.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_finishing_block_scope.py 2>&1 | tail -2; bash plugins/spec-distill/tests/test_roadmap_status.sh 2>&1 | tail -1; bash shared/tests/test_invocation_surface.sh 2>&1 | tail -1`
Expected: 모두 실패 0. `test_roadmap_status.sh` 의 실데이터 락이 이 로드맵의 `## 지휘 절차` 글을 읽으면 기대를 새 글로 맞춘다.

- [ ] **Step 10: 커밋**

```bash
git commit -m "feat(spec-distill): 진입 안내를 지휘자로 — 나눈 일 다음 세션 줄 · 지휘 절차 · 넘김 줄 머리말 · 승인 게이트 로드맵 갈래

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/templates/roadmap-template.md docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/references/redecompose.md plugins/spec-distill/tests/test_decompose_surface.sh plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_entry_guidance.sh
git show --stat HEAD   # 파일 아홉(+ 실데이터 락을 고쳤으면 그 파일)
```

---

### Task 13: devbrew 의 스위트 명령 · 손 헬퍼와 `merge_check` 대조 (결정 E · Deferred 2e6610eb#r2.1)

**Files:**
- Create: `tools/suite/run-all.sh`
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` (frontmatter 두 줄)
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md` (M10 행 · 절)

**Interfaces:**
- Consumes: Task 0 의 `suite-names.sh`(손 헬퍼), Task 3 의 `merge_check.py` · `names_in`.
- Produces: 로드맵 frontmatter `test_command: bash tools/suite/run-all.sh` · `test_failure_pattern: "^FAILED (.+)$"` — `run-all.sh` 의 이름에는 공백이 있어 pytest 모양(`FAILED (\S+)`)으로는 잘린다.

- [ ] **Step 1: 스위트 명령을 쓴다**

`tools/suite/run-all.sh`:

```bash
#!/usr/bin/env bash
# devbrew 전체 스위트 — 실패마다 `FAILED <파일>: <이름>` 한 줄, 하나라도 있으면 rc 1.
# 셸 테스트(실행 비트와 무관)의 「  ✗ 」 줄 · python unittest 의 FAIL: · ERROR: 줄 · node --test 의 not ok 줄.
# 실패 표시 줄 없이 rc≠0 인 파일은 `FAILED <파일>: rc <n>(실패 표시 줄 없음)`.
# 로드맵 frontmatter test_command 가 이것을 부른다(spec-distill merge_check). 스위트 둘을 같은 시각에 돌리지 않는다.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
LIST="$(mktemp "${TMPDIR:-/tmp}/run-all.XXXXXX")" || exit 2
trap 'rm -f -- "$LIST"' EXIT
{
  for f in plugins/*/tests/*.sh shared/tests/test_*.sh; do
    [ -f "$f" ] || continue
    out="$(bash "$f" 2>&1)"; rc=$?
    printf '%s\n' "$out" | sed -n 's/^  ✗ //p' | sed "s|^|FAILED $f: |"
    if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -q '^  ✗ '; then
      echo "FAILED $f: rc $rc(실패 표시 줄 없음)"
    fi
  done
  for d in plugins/*/tests shared/tests; do
    [ -d "$d" ] || continue
    python3 -m unittest discover -s "$d" -p 'test_*.py' 2>&1 | grep -E '^(FAIL|ERROR): ' | sed "s|^|FAILED $d: |"
  done
  for f in $(git ls-files 'plugins/*/tests/*.test.mjs'); do
    node --test --test-reporter=tap "$f" 2>&1 | grep -E '^[[:space:]]*not ok ' | sed "s|^[[:space:]]*|FAILED $f: |"
  done
} | LC_ALL=C sort > "$LIST"
cat "$LIST"
[ -s "$LIST" ] && exit 1 || exit 0
```

Run: `chmod +x tools/suite/run-all.sh && git add tools/suite/run-all.sh && git ls-files -s tools/suite/run-all.sh` — `100755`.

- [ ] **Step 2: 로드맵 frontmatter 에 올린다**

`roadmap.md` frontmatter 의 `review_model: opus` 줄 아래에 두 줄을 더한다:

```yaml
test_command: bash tools/suite/run-all.sh
test_failure_pattern: "^FAILED (.+)$"
```

Run: `python3 -I -c 'import sys; sys.path.insert(0, "plugins/spec-distill/scripts"); import roadmap_model as M, repo_defaults as R; t = open("docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md", encoding="utf-8").read(); s = R.repo_settings(M.frontmatter(t)); print(s["test_command"], s["errors"])'`
Expected: `bash tools/suite/run-all.sh []`.

- [ ] **Step 3: 커밋(대조 전에 — 대조는 커밋된 브랜치 끝을 쓴다)**

```bash
git commit -m "chore(roadmap): devbrew 스위트 명령과 실패 이름 모양을 로드맵 레포 설정으로

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- tools/suite/run-all.sh docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md
git show --stat HEAD   # 파일 둘
```

- [ ] **Step 4: 손 헬퍼와 `merge_check` 를 같은 브랜치에 돌려 대조한다**

`merge_check` 를 그대로 부르면 기본 브랜치의 로드맵(아직 `test_command` 가 없다)을 읽어 탐지 경로로 돈다. 그래서 `merge_check` 와 같은 사본 둘(기본 브랜치 · 기본 브랜치에 이 브랜치를 합친 것)을 손으로 만들고, 각 사본에서 손 헬퍼(`suite-names.sh`)와 스위트 명령(`run-all.sh`)을 돌려 `merge_check` 의 이름 추출(`names_in` + 이 로드맵의 `test_failure_pattern`)로 읽은 집합과 견준다. 스위트는 한 번에 하나씩 돈다.

```bash
J="$PWD/.superpowers/sdd/2026-10-18-epic-conductor-3-loop/m10"; H="$PWD/.superpowers/sdd/2026-10-18-epic-conductor-3-loop/suite-names.sh"; RA="$PWD/tools/suite/run-all.sh"
mkdir -p "$J"; git fetch origin
git worktree add --detach "$J/base" origin/HEAD
git worktree add --detach "$J/merged" origin/HEAD
git -C "$J/merged" -c user.name=m10 -c user.email=m10@invalid -c commit.gpgsign=false merge --no-ff --no-edit "$(git rev-parse HEAD)"
for side in base merged; do
  mkdir -p "$J/tmp-$side-a" "$J/tmp-$side-b"
  (cd "$J/$side" && TMPDIR="$J/tmp-$side-a" bash "$H") > "$J/hand-$side.txt"
  (cd "$J/$side" && TMPDIR="$J/tmp-$side-b" bash "$RA") > "$J/mc-$side.raw"
  python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import merge_check as m
print("\n".join(sorted(m.names_in(open(sys.argv[2], encoding="utf-8").read(), "^FAILED (.+)$")[0])))' "$PWD/plugins/spec-distill/scripts" "$J/mc-$side.raw" > "$J/mc-$side.txt"
done
narrow() { grep -E '^(plugins/(spec-distill|quality-gates)|shared)/' "$1" | LC_ALL=C sort; }
for side in base merged; do narrow "$J/hand-$side.txt" > "$J/h-$side"; narrow "$J/mc-$side.txt" > "$J/m-$side"; done
diff <(comm -13 "$J/h-base" "$J/h-merged") <(comm -13 "$J/m-base" "$J/m-merged") && echo "새 실패 집합 같음"
diff <(comm -23 "$J/h-base" "$J/h-merged") <(comm -23 "$J/m-base" "$J/m-merged") && echo "고쳐짐 집합 같음"
```

(손 헬퍼는 `<파일>: <이름>`, 스위트 명령은 앞에 `FAILED ` 가 붙고 `names_in` 이 그것을 뗀다 — 두 집합은 같은 꼴이다. 손 헬퍼의 범위(spec-distill · quality-gates · shared)가 스위트 명령(모든 플러그인)보다 좁아 `narrow` 로 같은 범위만 견준다.)

Expected: 「새 실패 집합 같음」 · 「고쳐짐 집합 같음」. 다르면 어느 쪽이 무엇을 놓쳤는지 적고, `merge_check`(또는 `run-all.sh`)를 고친다 — 손 헬퍼를 고치지 않는다.

그다음 사본을 지운다(이 대조의 일회용 사본이라 지워도 된다): `rm -rf "$J"; git worktree prune` — 이 Task 가 만든 `$J` 폴더 하나만 지운다(공유 임시 폴더를 glob 으로 지우지 않는다).

- [ ] **Step 5: M10 으로 적는다**

`measurements.md` 표에 행 하나와 `## M10` 절(방법 = Step 4, 결과 = 두 집합 줄 수와 같음 여부, 판정)을 더한다:

```markdown
| M10 | devbrew 에서 손 헬퍼(실패 이름 스크립트)와 merge_check 의 스위트 명령이 같은 브랜치에서 같은 새 실패 · 고쳐짐 집합을 내는가 | <같음/다름 — 줄 수> | R5 계획 3 Task 13 · 설계 Deferred 2e6610eb#r2.1 |
```

```bash
git commit -m "docs(roadmap): M10 — 손 헬퍼와 merge_check 의 실패 이름 집합 대조

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/measurements.md
git show --stat HEAD   # 파일 하나
```

---

### Task 14: 레포 전용 리터럴 락과 변이 (AC29)

**Files:**
- Create: `plugins/spec-distill/tests/test_repo_literals.sh`

**Interfaces:**
- Consumes: 대상 여섯 — `skills/epic-conductor/SKILL.md` · `references/conducting.md` · `references/conductor-dispatch.md` · `scripts/merge_check.py` · `scripts/conductor_ledger.py` · `agents/integration-reviewer.md`. 허용 목록은 `scripts/repo_defaults.py` 한 모듈 — 그 모듈의 `/` 가 든 대문자 상수 값은 대상에 글자로 나오면 안 된다(∀ — 상수를 더하면 자동으로 금지 목록에 든다).

- [ ] **Step 1: 락을 쓴다**

`plugins/spec-distill/tests/test_repo_literals.sh`:

```bash
#!/usr/bin/env bash
# R5 AC29 — 지휘자 skill · reference · 새 스크립트 · 통합 리뷰어에 레포 전용 리터럴(기본 브랜치 이름 · 브랜치 접두 ·
# 레포 구조 경로 · 모델 이름)이 없다. 외부 도구 기본 경로와 자기 상태 경로는 repo_defaults.py 상수에만 있다.
# 이빨은 변이로 잰다 — 표기 · 값 · 위치 · 부정문 네 축, 그리고 대상 여섯 하나하나가 실제로 읽히는지.
# 한계: 글자를 쪼개 이어 붙인 것(`"ori" + "gin/main"`)은 잡지 못한다 — 리뷰가 본다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_repo_literals.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
TARGETS="skills/epic-conductor/SKILL.md references/conducting.md references/conductor-dispatch.md scripts/merge_check.py scripts/conductor_ledger.py agents/integration-reviewer.md"
scan() {  # scan <파일...> — 걸린 줄을 `<파일>:<줄>: <종류>` 로
  PYTHONIOENCODING=utf-8 python3 -I - "$SD/scripts" "$@" <<'PY'
import re, sys
sys.path.insert(0, sys.argv[1])
import repo_defaults as R
consts = sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)
if not consts:
    print("상수 없음 — 허용 목록이 비었다(락이 공허하다)")
rules = [
    ("기본 브랜치 이름", re.compile(r"origin/(?:main|master)(?![\w-])|refs/heads/(?:main|master)(?![\w-])|[\"'`](?:main|master)[\"'`]")),
    ("브랜치 접두", re.compile(r"(?<![\w/.-])(?:feature|fix)/")),
    ("레포 구조 경로", re.compile(r"docs/superpowers/|\.superpowers/|plugins/spec-distill|\.claude/worktrees")),
    ("모델 이름", re.compile(r"(?i)(?<![a-z])(?:opus|sonnet|haiku|fable)(?![a-z])|gpt-")),
]
for path in sys.argv[2:]:
    with open(path, encoding="utf-8") as fh:
        for n, line in enumerate(fh, 1):
            for kind, rx in rules:
                if rx.search(line):
                    print("%s:%d: %s" % (path, n, kind))
            for c in consts:
                if c.rstrip("/") in line:
                    print("%s:%d: 상수 %s" % (path, n, c))
PY
}
files=()
for t in $TARGETS; do
  [ -f "$SD/$t" ] && ok "대상이 있다: $t" || no "대상이 없다: $t"
  files+=("$SD/$t")
done
assert_eq "$(scan "${files[@]}")" "" "대상 여섯에 레포 전용 리터럴이 없다"
# 양성 대조 · 변이 — 대상마다 사본에 한 줄을 넣으면 잡힌다(대상이 실제로 읽힌다)
mut() {  # mut <대상> <넣을 줄> — 사본에 줄을 넣고 그 사본만 스캔
  local c="$T/$(basename "$1").mut"
  cp "$SD/$1" "$c" && printf '\n%s\n' "$2" >> "$c" && scan "$c"
}
for t in $TARGETS; do
  [ -n "$(mut "$t" 'x origin/main y')" ] && ok "변이(대상 ${t}): 넣은 줄을 잡는다" || no "변이(대상 ${t}): 못 잡는다 — 이 대상은 스캔되지 않는다"
done
for line in 'git diff origin/main...HEAD' 'refs/heads/master' 'branch == "main"' "base = 'master'" 'feature/epic-x' 'fix/typo' \
            'docs/superpowers/specs/x.md' '.superpowers/sdd/p/progress.md' 'plugins/spec-distill/scripts' '.claude/worktrees/x' \
            'model: opus' 'Sonnet 으로' 'FABLE' 'haiku.' 'gpt-5' '# origin/main 을 쓰지 않는다' '```origin/master```'; do
  [ -n "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "변이: 「${line}」 를 잡는다" || no "변이: 「${line}」 를 못 잡는다"
done
for line in 'opusculum' 'mainline' 'domain/main.py' 'prefix/feature/x'; do
  [ -z "$(mut skills/epic-conductor/SKILL.md "$line")" ] && ok "음성 대조: 「${line}」 는 잡지 않는다" || no "음성 대조: 「${line}」 를 잘못 잡는다"
done
# 허용 목록은 하나 — 상수 값 자체를 넣으면 잡힌다(상수 밖 같은 글자)
for c in $(PYTHONIOENCODING=utf-8 python3 -I -c 'import sys; sys.path.insert(0, sys.argv[1]); import repo_defaults as R
print(" ".join(sorted(v for k, v in vars(R).items() if k.isupper() and isinstance(v, str) and "/" in v)))' "$SD/scripts"); do
  [ -n "$(mut scripts/merge_check.py "X = \"$c\"")" ] && ok "변이: 상수 값 「${c}」 를 상수 밖에서 잡는다" || no "변이: 상수 값 「${c}」 를 못 잡는다"
done
finish
```

- [ ] **Step 2: 돌린다**

Run: `chmod +x plugins/spec-distill/tests/test_repo_literals.sh && bash plugins/spec-distill/tests/test_repo_literals.sh 2>&1 | tail -5`
Expected: 실패 0. 대상에서 걸린 줄이 나오면 그 대상을 고친다(상수 이름 · 도출로) — 락을 넓히지 않는다. 음성 대조가 빨개지면 정규식의 경계를 고친다.

- [ ] **Step 3: 커밋**

```bash
git commit -m "test(spec-distill): 지휘자 표면의 레포 전용 리터럴 락과 네 축 변이

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/tests/test_repo_literals.sh
git show --stat HEAD   # 파일 하나
```

---

### Task 15: devbrew 밖 버릴 레포에서 지휘 순환의 기계 부분 (AC30 · AC17)

**Files:**
- Create: `plugins/spec-distill/tests/fixtures/conductor-e2e/roadmap.md` · `b.md` · `b.audit.md` · `E1.md` · `E2.md`
- Create: `plugins/spec-distill/tests/test_conductor_e2e.sh`

**Interfaces:**
- Consumes: Task 2~8 의 명령 전부, `control_plane.py show --tasks`, `roadmap_status.py --json`, `merge_check.py run`.

버릴 레포의 기본 브랜치는 `trunk`, 브랜치 접두는 `work/`, 설계문서 · 계획 폴더는 frontmatter 의 `plan/specs/` · `plan/plans/` 다 — 레포 전용 값이 하나도 박혀 있지 않음을 이 장면이 잰다. 설계 에픽 하나(E1)와 조사 에픽 하나(E2, `흐름:` · `산출물:`)다. 러너별 대조(pytest · 셸 · node)는 Task 3 의 장면이 이미 버릴 레포에서 잰다 — 여기서는 pytest 하나로 끝에서 끝을 잇는다.

- [ ] **Step 1: 픽스처를 쓴다**

`tests/fixtures/conductor-e2e/roadmap.md`:

~~~markdown
---
type: roadmap
source_brief: plan/br/b.md
specs_dir: plan/specs/
plans_dir: plan/plans/
---

# 버릴 로드맵

## 에픽

### E1 — 설계 에픽
- 의도: 설계 흐름 한 바퀴
- 범위:
  - 한다: 핵심 함수 하나
  - 안 한다: 화면
- 의존: 없음
- 브랜치: work/e1
- 묶음: E1.md
- 경로 예약: src/core.py

### E2 — 조사 에픽
- 의도: 조사 흐름 한 바퀴
- 범위:
  - 한다: 사례 조사
  - 안 한다: 구현
- 의존: 없음
- 브랜치: work/e2
- 묶음: E2.md
- 경로 예약: 없음
- 흐름: 조사 — 「조사로 간다 (권장)」
- 산출물: plan/research/e2.md

## 지휘 절차

이 로드맵은 지휘자가 이끈다.

## 결정 기록

## 재분해 이력

- 없음

## 위험 번호표

- K1 — 위험 — 숨은 가정: 버릴 가정 — 근거 없음
~~~

`b.md`(brief) · `b.audit.md` 는 `tests/test_roadmap_status.sh` 의 `write_brief` 와 같은 절 구조(`## 0.` ~ `## 7.`, frontmatter `type: interview-brief` · `user_sourced_items`)로 쓰되 번호는 `C1` · `OQ1` · `S1` · `«e2e-k»` · 위험 줄 하나만 둔다 — 문장은 이 장면의 것으로 쓴다(그 파일과 20줄이 같으면 중복 락이 잡는다). `E1.md` · `E2.md` 는 `type: epic-bundle` · `epic` · `roadmap: plan/rm/roadmap.md` · `source_brief: plan/br/b.md` · `ids` frontmatter 의 묶음이다 — `E1` 은 `[C1, S1, OQ1]`, `E2` 는 `[«e2e-k», K1]`.

픽스처를 처음 돌려(Step 3) `roadmap_status.py --json` 이 종료 코드 3 을 내면 `unknown_reasons` · `format_errors` 를 보고 **픽스처**를 고친다 — 해석기를 고치지 않는다. 미배정 번호 경고(종료 코드 1)는 받아들인다.

- [ ] **Step 2: 장면을 쓴다**

`plugins/spec-distill/tests/test_conductor_e2e.sh`:

```bash
#!/usr/bin/env bash
# R5 AC30 · AC17 — devbrew 밖 버릴 레포(기본 브랜치 trunk · 접두 work/ · 폴더는 frontmatter)에서 지휘 순환의 기계 부분:
# 상태 → 표지 · 시작 승인 → 에픽 worktree → 설계문서 · 승인 줄 → 계획 → 구현 → 판정 · 구현 대조 절 → 스위트 대조 →
# 머지 → 정리 → 기계 상태를 지워도 같은 상태. 조사 에픽은 산출물로 단계가 매겨진다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conductor_e2e.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
S="$ROOT/plugins/spec-distill/scripts"
FX="$ROOT/plugins/spec-distill/tests/fixtures/conductor-e2e"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 PYTHONDONTWRITEBYTECODE=1
python3 -m pytest --version >/dev/null 2>&1 || { no "pytest 가 없어 끝에서 끝을 걷지 못했다 — 이 기계에 pytest 를 깔고 다시 돈다"; finish; exit $?; }
W="$T/w"; RM="plan/rm/roadmap.md"; SID="session-e2e00001"
g() { git -C "$1" -c user.name=t -c user.email=t@example.invalid -c commit.gpgsign=false "${@:2}"; }
L() { (cd "$W" && python3 "$S/conductor_ledger.py" "$@"); }
stage_of() { (cd "$W" && python3 "$S/roadmap_status.py" --json "$RM") | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print(next(b["stage"] for b in r["blocks"] if b["id"]==sys.argv[1]))' "$1"; }
reason_of() { (cd "$W" && python3 "$S/roadmap_status.py" --json "$RM") | python3 -I -c 'import json,sys; r=json.load(sys.stdin); print(next(b["reason"] for b in r["blocks"] if b["id"]==sys.argv[1]))' "$1"; }

git init -q --bare -b trunk "$T/o.git"
git clone -q "$T/o.git" "$W" 2>/dev/null; g "$W" checkout -q -B trunk
mkdir -p "$W/plan/rm" "$W/plan/br" "$W/src" "$W/tests"
cp "$FX/roadmap.md" "$FX/E1.md" "$FX/E2.md" "$W/plan/rm/"; cp "$FX/b.md" "$FX/b.audit.md" "$W/plan/br/"
printf '[pytest]\n' > "$W/pytest.ini"
printf 'def core():\n    return 1\n' > "$W/src/core.py"
printf 'import sys, os\nsys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "src"))\nimport core\n\ndef test_core():\n    assert core.core() == 1\n' > "$W/tests/test_core.py"
g "$W" add -A; g "$W" commit -qm base; g "$W" push -q origin trunk; g "$W" remote set-head origin --auto >/dev/null

# 1 — 상태 · 작업 목록(기본 브랜치 trunk)
tasks="$(cd "$W" && python3 "$S/control_plane.py" show --tasks "$RM")"; rc=$?
assert_eq "$rc" "0" "작업 목록 rc 0(기본 브랜치 trunk)"
assert_contains "$tasks" "E1" "작업 목록에 E1"
assert_eq "$(stage_of E1)" "준비" "E1 준비"

# 2 — 표지 · 시작 승인(같은 규모면 공시만)
L claim --roadmap "$RM" --session "$SID" >/dev/null
SCALE="남은 에픽 2(E1 · E2) · agent 약 6 · 순서 E1 → E2"
L approval --roadmap "$RM" --session "$SID" --scale "$SCALE" >/dev/null; assert_eq "$?" "1" "처음엔 승인 필요"
L approve --roadmap "$RM" --session "$SID" --scale "$SCALE" >/dev/null
assert_contains "$(L approval --roadmap "$RM" --session "$SID" --scale "$SCALE")" "공시만" "같은 세션 · 같은 규모면 공시만"

# 3 — 에픽 worktree(하니스 폴더 · 접두 work/) · 자원 기록
WT="$(L worktree-path --name e1)"
g "$W" worktree add -q "$WT" -b work/e1 origin/HEAD
L add --roadmap "$RM" --session "$SID" --section 자원 --cells "worktree · $WT · E1 · 설계 · t" >/dev/null
mkdir -p "$WT/plan/specs"
printf -- '---\nsource_interview: plan/rm/E1.md\nroadmap: plan/rm/roadmap.md\n---\n\n# E1 설계\n\n## Acceptance Criteria\n\n- AC1 core 가 1 을 낸다\n' > "$WT/plan/specs/e1-design.md"
g "$WT" add -A; g "$WT" commit -qm spec
assert_eq "$(stage_of E1)" "설계 중" "설계문서 → 설계 중"
assert_eq "$(reason_of E1)" "spec 있음" "승인 전 근거"

# 4 — 승인 줄 → 근거가 승인됨
L record --spec "$WT/plan/specs/e1-design.md" --approval --date 2026-10-18 --choice "① /compact 후 다음 세션 줄 (권장)" >/dev/null
g "$WT" add -A; g "$WT" commit -qm approval
assert_eq "$(reason_of E1)" "spec 승인됨(2026-10-18) · 계획 없음" "승인 줄 → 근거가 승인됨"

# 5 — 계획 → 구현(Spec 트레일러) → 판정 · 구현 대조 절 → 구현 끝
mkdir -p "$WT/plan/plans"; printf '# 계획\n\n**Spec:** plan/specs/e1-design.md\n' > "$WT/plan/plans/e1.md"
g "$WT" add -A; g "$WT" commit -qm plan
assert_eq "$(stage_of E1)" "계획" "계획 → 계획"
printf 'def core():\n    return 1  # e1\n' > "$WT/src/core.py"; g "$WT" add -A
g "$WT" commit -qm "feat: e1" -m "Spec: plan/specs/e1-design.md"
assert_eq "$(stage_of E1)" "구현 중" "Spec 트레일러 커밋 → 구현 중"
printf 'Rulings I made:\n- Ruling: 작은 판정 — 이유 — 비용\nAC1: 구현됨 — core\n' > "$T/report.md"
L rulings --report "$T/report.md" --out "$T/rulings.md" >/dev/null; assert_eq "$?" "0" "판정 거두기"
L write-sections --spec "$WT/plan/specs/e1-design.md" --plan plan/plans/e1.md --rulings "$T/rulings.md" \
  --impl-line "경고 없음 (AC 1개)" --counts "AC 1개 중 구현됨 1 · 미룸 0 · 빠짐 0" >/dev/null
g "$WT" add -A; g "$WT" commit -qm records
assert_eq "$(stage_of E1)" "구현 끝" "구현 대조 절 → 구현 끝"

# 6 — 스위트 대조(pytest · 새 실패 없음)
out="$(cd "$W" && python3 "$S/merge_check.py" run --roadmap "$RM" --branch work/e1 --no-fetch)"; rc=$?
assert_eq "$rc" "0" "스위트 대조 rc 0: $out"

# 7 — 조사 에픽: 산출물이 브랜치에 생기면 설계 중
WT2="$(L worktree-path --name e2)"
g "$W" worktree add -q "$WT2" -b work/e2 origin/HEAD
mkdir -p "$WT2/plan/research"; printf '# E2 조사\n' > "$WT2/plan/research/e2.md"; g "$WT2" add -A; g "$WT2" commit -qm research
assert_eq "$(stage_of E2)" "설계 중" "조사 에픽: 산출물 → 설계 중"

# 8 — 머지(사용자 몫을 흉내) → 머지됨 → 정리(브랜치는 남는다) → 주인 모름은 E2 worktree
g "$W" merge -q --no-ff work/e1 -m "Merge pull request #1 from o/work/e1"; g "$W" push -q origin trunk; g "$W" fetch -q origin
assert_eq "$(stage_of E1)" "머지됨" "머지 → 머지됨"
assert_eq "$(L cleanup --roadmap "$RM" --session "$SID" --path "$WT" >/dev/null; echo $?)" "0" "E1 worktree 정리"
[ -d "$WT" ] && no "정리했는데 worktree 가 남았다" || ok "E1 worktree 를 지웠다"
assert_contains "$(g "$W" branch --list work/e1)" "work/e1" "브랜치는 지우지 않는다"
assert_contains "$(L orphans --roadmap "$RM")" "work/e2" "기계 상태에 없는 E2 worktree 는 주인 모름"

# 9 — 기계 상태를 지워도 상태는 git 에서 같다(AC17)
before="$(cd "$W" && python3 "$S/control_plane.py" show --tasks "$RM")"
rm -f -- "$(cd "$W" && python3 "$S/conductor_state.py" path --roadmap "$RM")"
after="$(cd "$W" && python3 "$S/control_plane.py" show --tasks "$RM")"
assert_eq "$after" "$before" "기계 상태를 지워도 작업 목록이 같다"
assert_eq "$(L resources --roadmap "$RM")" "없음" "잃은 것은 다시 만들 수 있는 자원 목록뿐"

# 10 — 레포 전용 값이 박혀 있지 않다: 이 레포에는 main · feature/ · docs/superpowers 가 없다
assert_eq "$(g "$W" branch -a --list '*main*' | wc -l | tr -d ' ')" "0" "버릴 레포에 main 브랜치가 없다"
[ -d "$W/docs" ] && no "버릴 레포에 docs 폴더가 생겼다(기본 폴더를 박은 곳이 있다)" || ok "기본 폴더를 쓰지 않았다(frontmatter 폴더만)"
finish
```

- [ ] **Step 3: 돌린다**

Run: `chmod +x plugins/spec-distill/tests/test_conductor_e2e.sh && bash plugins/spec-distill/tests/test_conductor_e2e.sh 2>&1 | tail -8`
Expected: 실패 0. `stage_of` 가 파이썬 오류를 내면 `roadmap_status.py --json` 출력을 직접 보고 픽스처를 고친다(Step 1 의 규칙). 장면 9 의 작업 목록은 받은 시각 문구가 없어야 같다 — 다르면 `show --tasks` 출력에서 시각을 빼고 비교한다(줄의 `<제목><탭><상태>` 만).

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/fixtures/conductor-e2e
git commit -m "test(spec-distill): 버릴 레포에서 지휘 순환의 기계 부분을 끝에서 끝으로 — 기본 브랜치 trunk · 폴더는 frontmatter

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/tests/test_conductor_e2e.sh plugins/spec-distill/tests/fixtures/conductor-e2e
git show --stat HEAD   # 파일 여섯
```

---

### Task 16: 릴리스 · 문서 · 스위트 대조 · 구현 대조 (AC38)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md`
- Modify: `docs/superpowers/specs/2026-10-17-epic-conductor-design.md` (`## 미룸` · `## 판정` · `## 구현 대조 — <이 계획 경로>` · `## 지휘 기록`)

**Interfaces:**
- Consumes: Task 0 의 `suite-names.sh` · `baseline.txt`, `check_bundle_coverage.py --plan · --impl --acs`, `conductor_ledger.py rulings · write-sections · record`(이 계획의 구현 대조를 이 계획이 만든 도구로 쓴다).

- [ ] **Step 1: 버전**

Run: `git fetch origin && git show origin/HEAD:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'; grep '"version"' plugins/spec-distill/.claude-plugin/plugin.json`
둘 중 큰 값의 minor 를 하나 올린 번호(지금 기본 브랜치가 `7.2.1` 이면 `7.3.0`)를 쓴다. 머지 직전에 origin 기본 브랜치의 값이 바뀌었으면 다시 정한다.

- [ ] **Step 2: CHANGELOG**

맨 위 버전 블록 앞에(번호는 Step 1, 날짜는 커밋하는 날):

```markdown
## [7.3.0] — 2026-10-18

### Added
- 진입 skill `/spec-distill:epic-conductor [<로드맵 경로>]` — 승인된 로드맵의 에픽을 한 세션이 끝까지 지휘한다. 다시 불러도 git 과 기계 상태에서 상태를 다시 계산해 같은 자리에서 잇는다. `cost_class: high` — 시작할 때 규모(남은 에픽 · agent 대략 수 · 순서)를 보이고 승인받는다. 같은 세션에서 이미 받은 승인이 있고 규모가 글자 그대로 같으면 묻는 대신 공시한다(이름 붙인 예외 — 지출 조항 문면 개정은 로드맵 R9). 끄기는 `DEVBREW_SPEC_DISTILL_DISABLE=1` — 꺼져 있으면 손 절차를 가리킨다.
- `references/conducting.md` 의 `## 지휘 순환` 걸음 1~7(맞추기 · 사람 몫 모으기 · 다음 일 고르기와 보내기 · 돌아오기 · 머지 전 확인 · 머지 뒤 · 끝)과 /compact 시점 · 알림. 손 절차는 끝 절로 남는다.
- `references/conductor-dispatch.md` — 하위에게 보내는 글: 자리 · 흐름 · 같은 skill 그대로 · 미리 받은 답(머지 메뉴 3번 · 기준 브랜치 · 구현 agent 의 실행 방식)과 두 부분 반환(쉬운 요약 + 원문) · 단계마다 새 agent · 마지막 보고 · 처분 줄.
- `scripts/merge_check.py` — 머지 전 스위트 대조. 합친 사본과 기본 브랜치 사본에서 그 레포의 스위트를 돌려 실패를 단위와 이름으로 가른다. 단위 짝짓기는 `shared/test-selection/` 공유본(링크 넷), 이름은 pytest · unittest · TAP · ✗ 줄 또는 로드맵 frontmatter `test_failure_pattern`. 이름을 못 뽑으면 「이름 대조 불가 — 단위 수준만」. 잠금으로 동시 실행을 막는다.
- `scripts/conductor_ledger.py` — 기계 상태 쓰기(세션 표지 아래) · 시작 승인 · 로드맵 찾기(frontmatter `type: roadmap`) · 자원과 정리 전 확인(`--force` 없음, 브랜치는 지우지 않음) · 주인 모름 worktree · 설계문서 기록 절(spec 승인 줄 · 판정 · 구현 대조) · 판정 거두기 · 쌓인 기록 · 감사 후보 · 줄어든 넘김 의심 · PR 인계 모으기 · 통합 리뷰 묶음 · 설치본 판 확인.
- agent `integration-reviewer` — 쓰기 권한 없는(`Read, Grep, Glob`) 통합 리뷰어. 에픽 사이 이음매를 보고 「이 PR 이 고침」 · 「뒤 에픽이 고침」으로 나눈다.

### Changed
- 상태 계산: spec 승인 줄(`- spec 승인 · <날짜> · 「…」`, 손으로 쓴 옛 줄 포함)이 있으면 「설계 중」 의 근거가 「spec 승인됨(<날짜>) · 계획 없음」 이다. 기본 브랜치 참조 상수는 `roadmap_model.py` 한 곳. 에픽 하나로 내려가는 보기가 머지된 에픽의 PR 을 보인다.
- 나눈 일의 다음 세션 줄이 `/spec-distill:epic-conductor <로드맵>` 한 줄이다. 로드맵 템플릿의 `## 지휘 절차` 가 지휘자 안내로 줄었다. 에픽 넘김 줄은 지휘자를 껐거나 사용자가 따로 진행할 때만 쓴다. spec-review 승인 게이트: 로드맵 에픽이면 둘째 줄이 지휘자 호출이고, writing-plans 줄은 「계획 agent 의 입력(치지 않는다)」 으로 남는다.
- `--impl` 의 받는 곳 규칙 줄이 작업 트리의 로드맵으로 쟀다고 말한다.
```

- [ ] **Step 3: README**

`plugins/spec-distill/README.md`:
- 진입 skill 목록(`/spec-distill:roadmap-status` 줄 근처)에 `- `/spec-distill:epic-conductor [<로드맵 경로>]` — 승인된 로드맵의 에픽을 이 세션에서 끝까지 지휘합니다(cost_class high — 시작 승인, 같은 세션 같은 규모면 공시만).` 을 더한다.
- `## 로드맵 · 에픽 묶음` 의 `references/conducting.md` 줄을 「지휘 순환 걸음 1~7(지휘자가 따른다)과 끝 절의 손 절차(지휘자를 껐을 때)」 로 고치고, 그 아래 `references/conductor-dispatch.md` · `scripts/merge_check.py` · `scripts/conductor_ledger.py` · `agents/integration-reviewer.md` 를 한 줄씩 더한다.
- `## Principles Instantiated` 에 더한다:

```markdown
- **Law 2 — 통합 리뷰어는 쓰지 못한다 (7.3.0)** — 에픽 사이 이음매 리뷰는 `tools: Read, Grep, Glob` 인 `integration-reviewer` 가 한다. superpowers 리뷰 요청 skill 의 틀만 빌리고 그 skill 이 부르는 쓰기 가능한 agent 는 쓰지 않는다.
- **Law 3 · P23 — 다시 불러도 같은 자리 (7.3.0)** — 지휘자는 무엇이 끝났는지 기억에 기대지 않고 git(설계문서의 승인 줄 · 판정 · 구현 대조 절)과 기계 상태에서 다시 계산한다. 기계 상태를 지워도 잃는 것은 다시 만들 수 있는 것뿐이다(`tests/test_conductor_e2e.sh`).
- **레포 전용 값 금지 (7.3.0)** — 지휘자 표면에는 기본 브랜치 이름 · 브랜치 접두 · 레포 구조 경로 · 모델 이름이 없다. 외부 도구 기본 경로는 `scripts/repo_defaults.py` 상수에만 있고 로드맵 frontmatter 가 이긴다(`tests/test_repo_literals.sh`).
- **cost_class high 의 이름 붙인 예외 (7.3.0)** — 같은 세션에서 같은 규모로 지휘자를 다시 부르면 이미 받은 시작 승인을 다시 쓰고 공시만 한다. 규모가 바뀌거나 다른 세션이면 다시 묻는다.
```

- [ ] **Step 4: 스위트를 기준선과 대조한다**

Run: `bash .superpowers/sdd/2026-10-18-epic-conductor-3-loop/suite-names.sh > .superpowers/sdd/2026-10-18-epic-conductor-3-loop/after.txt; comm -13 .superpowers/sdd/2026-10-18-epic-conductor-3-loop/baseline.txt .superpowers/sdd/2026-10-18-epic-conductor-3-loop/after.txt`
Expected: 빈 출력(이 브랜치에만 있는 실패 이름 없음). `comm -23` 으로 고쳐진 이름도 본다. 이 대조는 spec-distill · quality-gates · shared 를 덮는다(설계 Verification Plan — 계획 셋째는 R2a 가 바꾼 quality-gates 도). `shared/tests/test_changelog_integrity.sh` · `test_invocation_surface.sh` · `test_dispatch_disposition.sh` · `test_agent_input_slots.sh` · `test_no_new_duplication.sh` 가 기준선과 같은지 이 대조가 함께 잰다.

- [ ] **Step 5: 계획 대조**

Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --plan docs/superpowers/specs/2026-10-17-epic-conductor-design.md docs/superpowers/plans/2026-10-18-epic-conductor-3-loop.md --acs "AC15~AC31 · AC36 · AC37 · AC38 · AC41 · AC42 · AC43 · AC44 · AC45"`
Expected: `계획 대조: 계획에 없는 AC 없음 (…)`.

- [ ] **Step 6: 커밋**

```bash
git commit -m "chore(spec-distill): 지휘자 릴리스 기록

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git show --stat HEAD   # 파일 셋
```

- [ ] **Step 7: 마지막 전체 리뷰 뒤 — 구현 대조를 설계문서에 남긴다(이 계획의 도구로)**

구현 대조를 거두는 쪽이 한 번만 한다(지휘 세션이 보냈으면 지휘 세션). 설계문서에 `## 구현 대조 — docs/superpowers/plans/2026-10-18-epic-conductor-3-loop.md` 절이 이미 있으면 건너뛴다.

1. 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 올린다(받는 곳은 로드맵의 에픽 번호나 `#<n>`). 이 계획이 받은 R5 미룸 행(「받은 미룸」 표)은 처리했으면 표에서 빼지 않고 이유 칸 끝에 「— 계획 3 에서 처리(Task <n>)」 를 붙인다.
2. Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-17-epic-conductor-design.md .superpowers/sdd/2026-10-18-epic-conductor-3-loop/ac-report.md --acs "AC15~AC31 · AC36 · AC37 · AC38 · AC41 · AC42 · AC43 · AC44 · AC45"` — 출력을 고치지 않고 사용자에게 보인다.
3. 판정 목록(실행 방식의 마지막 「Rulings I made」)을 `.superpowers/sdd/2026-10-18-epic-conductor-3-loop/final-report.md` 에 두고:

```bash
python3 plugins/spec-distill/scripts/conductor_ledger.py rulings --report .superpowers/sdd/2026-10-18-epic-conductor-3-loop/final-report.md --ledger .superpowers/sdd/2026-10-18-epic-conductor-3-loop/progress.md --out .superpowers/sdd/2026-10-18-epic-conductor-3-loop/rulings.md
python3 plugins/spec-distill/scripts/conductor_ledger.py write-sections --spec docs/superpowers/specs/2026-10-17-epic-conductor-design.md --plan docs/superpowers/plans/2026-10-18-epic-conductor-3-loop.md --rulings .superpowers/sdd/2026-10-18-epic-conductor-3-loop/rulings.md --impl-line "<위 2 의 첫 줄 그대로>" --counts "AC <n>개 중 구현됨 <n> · 미룸 <n> · 빠짐 <n>"
python3 plugins/spec-distill/scripts/conductor_ledger.py record --spec docs/superpowers/specs/2026-10-17-epic-conductor-design.md --line "미룸 「로드맵 R5 범위를 재결정에 맞춤」 은 #224 가 처리했다 — R5 블록 범위 줄이 「spec 리뷰까지는 지휘 세션이 직접」 을 싣는다"
```

4. 커밋:

```bash
git commit -m "docs(spec-distill): R5 계획 3 의 판정과 구현 대조

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- docs/superpowers/specs/2026-10-17-epic-conductor-design.md
git show --stat HEAD   # 파일 하나
```

---

## 구현 뒤 — 지휘 세션 몫(구현 agent 가 하지 않는다)

설계 Verification Plan 의 「판단 동작」 은 정적 락으로 잴 수 없다 — 다음 묶음(R2a · R10 · R11)을 이 지휘자로 지휘하는 첫 실사용에서, 지휘 세션 하나의 기록(도구 호출 순서 · 사용자에게 보인 글)을 아래와 대조해 로드맵 `measurements.md` 에 M11 로 적는다. 판단의 질은 재지 않고 「그 자리에서 그 일을 했는가」 만 본다.

| 관측 | 통과 | AC |
|---|---|---|
| 첫 `AskUserQuestion` 앞에 규모 줄이 있고, 그 승인 전에는 Agent dispatch 가 없다 · 같은 세션 이어 부르기에서 규모가 같으면 질문 대신 공시 | 둘 다 | AC15 |
| 가짜 실행 원장에 수용 기준을 바꾸는 판정 줄 → 그 에픽의 다음 dispatch 가 멈추고 배경과 함께 질문, 다른 에픽 dispatch 는 이어짐. 설계 안 판정만이면 멈춤 없음 | 둘 다 | AC22 |
| 앞 에픽 결과에 기대는 질문은 그 에픽이 끝나기 전에 안 나오고, 질문은 하나씩 배경과 함께. 계획에 설계에 없던 결정을 심으면 질문이 나오고 답 전엔 구현 dispatch 없음, 안 심으면 질문 없이 구현 dispatch | 셋 다 | AC23 |
| `PushNotification` 은 사람 답이 없어 멈춘 때와 모두 끝난 때에만 | 그 둘만 | AC26 |
| /compact 제안 글보다 앞에 설계문서 절 커밋과 기계 상태 쓰기 | 순서 | AC27 |
| 승인 게이트 전까지 spec-review Skill 호출이 이 세션에 있고 그 리뷰를 맡기는 Agent dispatch 는 없음 · 호출 앞에 에픽 worktree 로의 이동과 `root=` 확인 · 승인 뒤 첫 dispatch 는 계획 agent · 설계문서 `## 지휘 기록` 에 승인 줄 커밋 · 리뷰 도중 다른 에픽 질문이 그 게이트 질문에 섞이지 않음 | 다섯 다 | AC44 |
| 담당 agent 를 거친 사람 몫 자리마다 다섯 칸 표(skill 이 낸 문면 · agent 가 돌려보낸 것 · 사용자에게 보인 것 · 사용자 답 · agent 에 돌려준 것)와 사용자 반응 — 선택지 · 정보 빠짐 · 라벨 · 답 바뀜 · 결정 불가가 없음. `relay-*.md` 파일을 쓰기 권한 없는 agent 가 대조 | 표 전부 | AC45 |
