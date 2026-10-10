---
description: "Run the quality gates pipeline (review → differential test → verdict → PR comment)"
argument-hint: "[critique <path>] [branch|--paths <glob>...] [--plan <path>]"
---

# Quality Gates Pipeline

<!-- plain-language:begin -->
## 사람에게 쓰는 글
이 절은 사용자에게 보이는 글(답변·보고·질문·선택지·경고·PR 본문·커밋)에만 적용한다. 지시문·subagent 프롬프트·state 파일에는 적용하지 않는다. 아래 절차가 출력 형식·원문 보존·분량을 따로 정한 자리에서는 그 절차를 따른다.
- 처음 보는 사람이 한 번에 이해하게 쓴다. 번호·해시·필드 이름·내부 용어는 가리키는 내용을 문장으로 먼저 쓰고 괄호 안에만 둔다. 지어낸 말은 쓰지 않거나 처음 쓸 때 풀어 쓴다.
- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일 하나. 할 일이 없으면 없다고 쓴다.
- 질문 하나에 결정 하나. 선택지 이름은 짧은 쉬운 말로, 설명에는 고르면 무엇이 달라지는지만 쓴다. 본문에 없던 주제를 선택지에서 꺼내지 않는다. 추천은 「(권장)」으로 표시한다.
- 제목과 목록으로 나누되 표의 칸은 짧게 쓴다. 굵은 글씨는 꼭 필요한 곳에만 쓴다.
- 사용자가 알 필요 없는 글은 쓰지 않는다: 도구 호출 사이의 진행 설명, 전부 정상인 항목의 나열. 확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.
- 판정·개수·공시 줄은 스크립트가 낸 쉬운 첫 줄을 그대로 쓰고, 자기 말로 다시 풀거나 덧붙이지 않는다. 스크립트·subagent 가 낸 원문은 고치지 않는다. 스크립트가 풀어 두지 않은 오류에만 쉬운 설명을 앞에 붙이되 통과·실패는 말하지 않는다.
- 사용자와 대화하는 언어로 쓴다. 코드·명령·고유명사·자연스러운 대응어가 없는 기술어는 영어 그대로 둔다. 커밋·PR은 그 레포의 규칙을 따르고, 없으면 대화 언어로 쓴다.
예) 전: `[미적용 fix] 3720b2b7#r1.1` → 후: 리뷰가 고치라고 한 곳 하나가 아직 안 고쳐졌다(3720b2b7#r1.1).
예) 전: (codex 정상 · 재비판 정상 · 저자 편집 없음 · ask_open 0건) → 후: 이상 없음.
<!-- plain-language:end -->

Run the quality pipeline — one pipeline, one verdict (`clean` · `defect` · `not-certified (<사유>)`).

**Arguments:** $ARGUMENTS

## Special mode: `critique` (비-코드 산출물 비평 루프)

`$ARGUMENTS`가 `critique`로 시작하거나(예: `/qg critique docs/design.md`), 사용자가
자연어로 **비-코드 산출물** 비평 의도를 밝히면(예: `이 설계문서 비평해줘`), 이는
코드 파이프라인이 아니라 **산출물 비평-수정 루프** 모드다. 이 경우 `setup-qg.sh`·
`quality-pipeline`을 실행하지 말고 곧장 신규 skill을 호출한다:

`Skill("quality-gates:critiquing-artifacts")`

그 skill이 소유: E0 kill switch → E1 코드/비-코드 분류(코드면 "코드는 /qg로" 안내 후 종료)
→ E2 브랜치 안전 → E2b clean 전제 → E3 upfront 동의 게이트 → 비평-수정-재비평 루프
(라운드별 커밋). `critique <path>`는 결정론적 진입(고정 라우팅), 자연어 의도는 모델이
해석(별도 토큰 parser 없음 — P8 determinism-economy). 코드/산출물 의도가 **진짜 모호**할
때만 mode-branch를 확인하고, 명확하면 안 띄운다(dominant한 코드 경로에 마찰 0).

**코드 파이프라인 인자**(bare `/qg`, `branch|--paths ...`)는 아래
기존 경로 그대로 — 무변경.

## Instructions

Execute the setup script to initialize the pipeline:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" $ARGUMENTS
```

사용자의 의도가 비-코드 산출물 비평이면(첫 인자 `critique` 든 자연어든) setup 의 출력과 종료 코드와 무관하게
위 critique 절을 따른다 — 자연어 인자는 setup 이 `Unknown argument` 로 거부하지만 아무것도 쓰지 않았다.
setup 이 `인자는 없어졌다 — … 실행하지 않는다.` 줄을 냈으면(exit 2) 그 줄을 그대로 보이고 끝낸다 —
파이프라인 skill 을 부르지 않는다. 그 밖에 setup 이 비0 으로 끝났으면 그 출력을 그대로 보이고 끝낸다.
인자가 `critique` 로 시작하면 setup 은 출력 없이 0 으로 끝난다 — 이 규칙 대신 위 critique 절을 따른다.

Otherwise invoke `Skill("quality-gates:quality-pipeline")` with the parsed
arguments. The skill runs the pipeline in this turn — reviewers,
re-critique, differential test, synthesis — with its internal fix-loop, surfacing
decision points via AskUserQuestion. No further commands are needed unless
the pipeline is aborted at a decision point.

### Quick Reference

| Command | Effect |
|---------|--------|
| `/qg critique <path>` | 비-코드 산출물 비평-수정 루프(별도 skill; 라운드별 커밋; 코드 아님) |
| `/qg` | Run the pipeline; `Spec:` 트레일러로 선언된 토픽이면 토픽 전체(합친 트리), 아니면 git-derived diff (branch + worktree) |
| `/qg branch` | Run on the full-branch diff (vs `main`) |
| `/qg --paths <glob>...` | Scope to matched paths |
| `/qg --plan <path>` | Use specific plan file |
| `branch <name>` · `--reset` · `--gc` · `--pr-url` | 없어졌다(v10) — 안내 한 줄을 내고 실행하지 않는다 |
| `both` · `review` · `runtime` · `--skip-runtime` | 제거됨 — 한 줄 공지 후 그대로 진행 |
| `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` | 차등 테스트를 건너뛴다 — 판정은 `not-certified (kill-switch)` |

다른 브랜치를 보려면 그 브랜치를 체크아웃하거나 그 브랜치의 git worktree 안에서 `/qg` 를 돌린다.
세션 폴더는 `/qg` 를 시작할 때마다 지우고 다시 만들며, 오래된 폴더는 같은 시점의 TTL GC 가 회수한다.

### Scope (default: git 변경)

선언이 있으면 기본 scope 는 **토픽**이다 — README 「토픽 스코프」. 아래는 선언이 없을 때(session)다.

`/qg` 는 **git 이 보고하는 변경**을 기본 scope 로 리뷰한다 — base 대비 브랜치 diff
와 worktree 변경의 합집합이며, 오케스트레이터가 그 집합을 직접 resolve 해 리뷰
scope 로 쓴다(`scripts/check-review-scope.sh` 의 산출값이 **아니다** — 그 스크립트는
독립적인 `changes_exist` 교차검증 신호만 결정론으로 공급하고, resolved scope 와
같은 소스로 합쳐지면 정직-verdict floor 의 비교가 무력화된다). v5.0.0 이전에는
PostToolUse 훅이 편집 파일을 누적했고, 그래서 Bash heredoc·`sed -i` 로 쓴 파일이
scope 에서 조용히 빠졌다. git 도출은 어떤 도구로 썼든 같은 답을 낸다.

**리포 밖 절대경로 편집은 잡히지 않는다** — `--paths` 로 명시한다.

Override with `/qg branch` (full branch) or `/qg --paths <glob>...` (manual).

빈 세션에서 커밋된 변경이 있어 resolved scope가 0인데 브랜치는 base보다 앞서 있으면 (false-clean),
qg는 "clean"이라 하지 않는다 — read-only `check-review-scope.sh`가 `changes_exist`를 결정론으로
emit하고, 파이프라인의 **정직-verdict floor**가 `resolved scope 0 AND changes_exist == yes`이면
판정이 `not-certified (scope-empty)` 가 된다(load-bearing, kill 불가). 무엇을
리뷰할지(routing)는 모델이 소유 — 빈 scope면 모델이 `/qg branch`(전체 브랜치 리뷰)를 제안한다.
진짜 변경 없음(genuine no-op)도 더는 무조건 `clean` 이 아니다 — ②(차등 테스트)가 매
iteration 도는 한, R1b 가 영향 unit 을 0개 고르면 차등 테스트 자신이 `expected-empty`
를 내고 그것이 `not-certified (scope-empty)` 로 판정된다(정직-verdict floor 와는 별도
경로 — resolved scope 0 문제가 아니라 test unit 0 문제다). 신호가 degraded면
fail-open + loud advisory.

암묵 session scope로 돌 때 qg는 그 사실을 한 줄로 밝힌다 (`Review scope: session (N files)` — 전체
PR/브랜치는 `/qg branch`). 토픽 선언(`Spec:` 트레일러)으로 풀리면 대신
`Review scope: topic <키> (N files · 구성원 <branches>)` 를 밝힌다. 자연어로 브랜치/전체 리뷰 의도를 말하면 모델이 `/qg branch`(branch
scope)로 해석한다 — 별도 토큰 alias 없음 (P8 determinism-economy: non-load-bearing 라우팅은
모델 신뢰, 결정론적 보장은 literal `/qg branch`에).

### Cost guidance

리뷰어는 기본 셋(code-reviewer · security-reviewer · codex) + 조건부 ≤4 + 재비판(iteration 당 최대 8)이다.
비용은 diff 크기와 iteration 수(≤5)에 따라 달라지고, trivia 로 닫힌 실행은 리뷰어를 부르지 않는다.

Set `DEVBREW_QUALITY_GATES_DISABLE=1` to globally disable.

### Pipeline

- ① 리뷰(기본 셋 + 조건부 ≤4 → 출처-제거 재비판) → ② 차등 테스트(기준선 대비, 매 iteration) → ③ 합성 · 판정
- Fix-loop: 막는 지적이나 차등 defect 가 남으면 iteration 마다 항목별 적용/제외 분류표와 함께 `Retry` / `Accept and finish` / `Stop` 로 사용자가 진행을 정한다(최대 5회). Retry 는 「적용」 항목만 고친다.

### Pipeline Rules

- Pipeline runs in a single assistant turn (no Stop hook, no continuation
  sentinel, no cross-turn state machine).
- **Forward-only**: code-change verdicts terminate. The fix-loop applies
  user-consented fixes inline (orchestrator-as-writer); does NOT auto-restart
  from an earlier iteration.
- The pipeline iterates up to 5 times; AskUserQuestion fires at every
  iteration boundary with `Retry` / `Accept and finish` / `Stop`.
- AskUserQuestion also fires on max-iter, and on the differential test's gap
  gate (R3) when something was left out.
- Local result in `.claude/quality-gates/<session-id>/result.md`
  (written by `scripts/setup-qg.sh`, which recreates the folder at every `/qg` start).
