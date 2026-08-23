---
description: "Run the quality gates pipeline (review → runtime verification)"
argument-hint: "[critique <path>|review|runtime|both] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
---

# Quality Gates Pipeline

Run the 2-gate quality verification pipeline to ensure code quality before PR merge.

**Arguments:** $ARGUMENTS

## Special argument: `--reset`

`$ARGUMENTS` 가 `--reset` 포함 시 setup 안 돌리고 자기 세션 폴더 + legacy 파일 정리:

```!
SID="${CLAUDE_CODE_SESSION_ID:-}"
if [ -n "$SID" ]; then
  rm -rf ".claude/quality-gates/$SID"
fi
rm -f .claude/quality-gates.local.md \
      .claude/quality-gates-session.local.md \
      .claude/quality-gates-branch.local.md \
      .claude/qg-diff-cache.txt \
      .claude/qg-code-paths.tmp
```

종료 후 "Quality-gates state cleared." 보고.

## Special argument: `--gc`

`$ARGUMENTS` 가 `--gc` 포함 시 (단독 또는 다른 인자와 함께) TTL GC를 명시 실행:

```!
python3 "${CLAUDE_PLUGIN_ROOT}/scripts/qg-gc.py"
```

`--gc` 단독: 종료. 다른 인자와 함께: GC 후 setup 진행.

## Special mode: `critique` (비-코드 산출물 비평 루프)

`$ARGUMENTS`가 `critique`로 시작하거나(예: `/qg critique docs/design.md`), 사용자가
자연어로 **비-코드 산출물** 비평 의도를 밝히면(예: `이 설계문서 비평해줘`), 이는 코드
2게이트 파이프라인이 아니라 **산출물 비평-수정 루프** 모드다. 이 경우 `setup-qg.sh`·
`quality-pipeline`을 실행하지 말고 곧장 신규 skill을 호출한다:

`Skill("quality-gates:critiquing-artifacts")`

그 skill이 소유: E0 kill switch → E1 코드/비-코드 분류(코드면 "코드는 /qg로" 안내 후 종료)
→ E2 브랜치 안전 → E2b clean 전제 → E3 upfront 동의 게이트 → 비평-수정-재비평 루프
(라운드별 커밋). `critique <path>`는 결정론적 진입(고정 라우팅), 자연어 의도는 모델이
해석(별도 토큰 parser 없음 — P8 determinism-economy). 코드/산출물 의도가 **진짜 모호**할
때만 mode-branch를 확인하고, 명확하면 안 띄운다(dominant한 코드 경로에 마찰 0).

**코드 파이프라인 인자**(bare `/qg`, `both|review|runtime|branch|--paths ...`)는 아래
기존 경로 그대로 — 무변경.

## Instructions

Execute the setup script to initialize the pipeline:

```!
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" $ARGUMENTS
```

Now invoke `Skill("quality-gates:quality-pipeline")` with the parsed
arguments. The skill runs the pipeline in this turn — after the
gate-scope question it runs the Review gate (with internal fix-loop) and,
when both gates are selected, the Runtime gate — surfacing decision points
via AskUserQuestion. No further commands are needed unless the pipeline
is aborted at a decision point.

### After the pipeline: publish offer

파이프라인 스킬(`Skill("quality-gates:quality-pipeline")`)이 종료해 제어가 이
커맨드로 돌아오면, 아래를 **순서대로** 수행한다. 이는 게이트가 아니라 게이트
**뒤에** 얹힌 opt-in 연속이다 — verdict·pass/fail에 영향 없음.

<!-- 이 "예" 분기의 Skill 호출은 commands/qg-publish.md의 dispatch와 동일 호출.
     두 call site가 drift하지 않도록 함께 수정할 것 (Law 3 위생). -->

1. **Kill switch.** `DEVBREW_QUALITY_GATES_DISABLE=1`(전역) 또는
   `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1`(publish 전용) 중 **어느 하나라도** 설정돼
   있으면 offer를 건너뛴다 — 전역 kill 시 `setup-qg.sh`는 자신의 global-kill
   체크에서 즉시 exit해 stale-sentinel 삭제(더 뒤 단계)까지 도달하지 못하므로,
   이전 같은-세션 실행의 sentinel이 남아있을 수 있다; offer도 publish-전용
   switch만 보면 이를 놓친다(kill switch = security control, CLAUDE.md). 설정된
   쪽에 맞춰 한 줄만 출력하고 종료:
   - `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1` → `> [quality-gates] publish offer disabled via DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1`
   - `DEVBREW_QUALITY_GATES_DISABLE=1` → `> [quality-gates] publish offer skipped: quality-gates globally disabled (DEVBREW_QUALITY_GATES_DISABLE=1).`
2. **Eligibility (fail-safe — default no-offer).** 아래 둘이 **모두** 참이 아니면
   offer 없이 조용히 종료(비완료/abort/trivia는 sentinel 부재 → 여기서 걸림):
   - `test -f ".claude/quality-gates/$CLAUDE_CODE_SESSION_ID/publish-eligible.md"` 성공, **그리고**
   - 그 파일 1번째 줄이 정확히 `<!-- qg-publish-eligible:v1 -->` (마커 유효).
3. **Offer.** sentinel의 `verdict:` 줄 값을 `<verdict>`로 읽어(파싱 실패 시 `완료`
   로 대체) 아래 `AskUserQuestion`을 발동한다:

   ```
   AskUserQuestion({ questions: [{
     question: "게이트 완료 (<verdict>) — 이 브랜치의 PR-이해글을 생성해서 게시할까요? (게시 전 미리보기 + 별도 동의가 있습니다.)",
     header: "PR 이해글",
     options: [
       {label: "예, 이어서 생성·게시", description: "publishing-pr-understanding skill 실행 — 미리보기·secret-scan·동의 게이트를 거쳐 게시."},
       {label: "아니오",              description: "여기서 종료. 나중에 /qg-publish로 따로 실행할 수 있습니다."}
     ], multiSelect: false }]})
   ```

   - **"예, 이어서 생성·게시"** → `Skill("quality-gates:publishing-pr-understanding")`
     를 인자 없이 호출(= 게시 경로). 이후는 그 skill이 소유: Preflight → Build →
     Generate → Scan(FAIL-CLOSED) → Preview → **Consent(informed)** → Publish →
     Report. offer는 GitHub write를 pre-consent하지 **않는다** — 그 skill의
     informed-consent 게이트가 반드시 다시 fire한다(2차 touchpoint).
   - **"아니오"** → 종료.
   - **graceful floor (관측 가능한 Skill 에러에 한함).** post-pipeline 단계가
     **실행은 됐으나** 위 `Skill(...)` 호출이 관측 가능하게 에러(스킬 부재·
     invocation 실패)하면, crash하지 말고 정확히 한 줄 출력한다:
     `> 이어서 게시하려면: /qg-publish` (누락 capability는 downgrade, crash 아님).

### Quick Reference

| Command | Effect |
|---------|--------|
| `/qg critique <path>` | 비-코드 산출물 비평-수정 루프(별도 skill; 라운드별 커밋; 코드 아님) |
| `/qg` | Ask gate scope (Review only / both), then run; git-derived diff (branch + worktree) |
| `/qg both` | Full pipeline (both gates), no gate-scope question; git-derived diff (branch + worktree) |
| `/qg branch` | Ask gate scope, then run; full-branch diff (vs `main`) |
| `/qg branch <name>` | Ask gate scope, then run against branch `<name>` in isolated worktree |
| `/qg --paths <glob>...` | Ask gate scope, then run; scope to matched paths |
| `/qg --reset` | Clear current session folder + legacy v1.5.0 flat files and exit |
| `/qg --gc` | Run TTL GC on stale session folders |
| `/qg review` | Review gate only |
| `/qg runtime` | Runtime gate only |
| `/qg --skip-runtime` | Review gate only (skip runtime) |
| `/qg --plan <path>` | Use specific plan file |
| `/qg --pr-url <url>` | Specify PR URL |
| `/cancel-qg` | Cancel active pipeline |
| `/qg-publish [--dry-run]` | Generate + publish a PR-understanding comment (separate skill; consent-gated; not a gate) |
| (완료 후 자동) | 비중단 완료 시 "PR-이해글 이어서 게시?" opt-in offer (consent-gated; 게이트 아님; `DEVBREW_QUALITY_GATES_DISABLE_PUBLISH=1`로 끔) |
| `DEVBREW_QUALITY_GATES_DISABLE_BRANCH_WORKTREE=1` | Disable `/qg branch <name>` auto-worktree mode |
| `DEVBREW_QUALITY_GATES_KEEP_WORKTREE=1` | Preserve branch worktree after pipeline completes or is cancelled (default: removed) |
| `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` | Disable the Runtime gate sandbox executor (read-only smoke fallback; verdict capped at SKIP_WITH_EVIDENCE) |

### Scope (default: git 변경)

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
emit하고, Review gate의 **정직-verdict floor**가 `resolved scope 0 AND changes_exist == yes`이면
verdict를 `no scope reviewed … NOT certified clean`으로 교체한다(load-bearing, kill 불가). 무엇을
리뷰할지(routing)는 모델이 소유 — 빈 scope면 모델이 `/qg branch`(전체 브랜치 리뷰)를 제안한다.
진짜 변경 없음(genuine no-op)은 그대로 `clean`; 신호가 degraded면 fail-open + loud advisory.

암묵 session scope로 돌 때 qg는 그 사실을 한 줄로 밝힌다 (`Review scope: session (N files)` — 전체
PR/브랜치는 `/qg branch`). 자연어로 브랜치/전체 리뷰 의도를 말하면 모델이 `/qg branch`(branch
scope)로 해석한다 — 별도 토큰 alias 없음 (P8 determinism-economy: non-load-bearing 라우팅은
모델 신뢰, 결정론적 보장은 literal `/qg branch`에).

### Cost guidance

Approximate cost per run vs default-Opus baseline (full-branch + cross-gate
loop, the pre-redesign behavior):

| Auto-detected depth | Cost | Trigger |
|---|---|---|
| Trivia | ~0% | ≤3 lines whitespace/rename single file |
| Quick | ~25–35% | <50 LOC, single concern, no new files |
| Standard | ~30–45% | 50–199 LOC or multi-file simple |
| Deep | ~55–75% | ≥200 LOC, new files, config changes (AskUserQuestion gate fires) |

Set `DEVBREW_QUALITY_GATES_DISABLE=1` to globally disable. Set
`DEVBREW_SKIP_HOOKS=quality-gates:session-tracker` to disable just the
session-tracker hook (keeps SessionStart advisor active). v1.32.0 has no
Stop hook.

### Gates

- **Review gate** — Iterative code review (scout → Phase 1+2 → adversarial → synthesizer); within-gate fix-loop up to 5 iterations
- **Runtime gate** — Launches app and verifies behavior with browser automation

### Pipeline Rules (v2.0.0)

- Pipeline runs in a single assistant turn (no Stop hook, no continuation
  sentinel, no cross-turn state machine).
- **Forward-only**: code-change verdicts terminate. The Review gate fix-loop applies
  user-consented fixes inline (orchestrator-as-writer); does NOT auto-restart
  from an earlier gate.
- The Review gate iterates up to 5 times internally; AskUserQuestion fires at every
  iteration boundary with `Retry` / `Proceed to Runtime gate` / `Stop`.
- AskUserQuestion also fires on Review gate max-iter and Runtime gate
  NEEDS_RESOLUTION.
- State tracked minimally in `.claude/quality-gates/<session-id>/pipeline.md`
  (managed by `scripts/setup-qg.sh`; SKILL reads worktree_path only).
