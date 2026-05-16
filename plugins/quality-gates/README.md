# Quality Gates 플러그인

Claude Code용 3-게이트 품질 검증 파이프라인. 멀티 플러그인 리뷰 위임 구조.

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 1 (Clarity Before Code)** — Gate 1 plan-verifier가 FAIL 시 `gate1_summary` YAML 핸드오프로 Gate 2 진입을 차단.
- **Law 2 (Writer ≠ Reviewer)** — 모든 reviewer agent가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 (frontmatter scoping으로 물리적 격리).
- **Law 3 (Compounding)** — scout `rationale` 필드가 매 iteration마다 state 파일에 로깅; reviewer-persona 편집이 학습된 교훈을 인코딩하는 substrate.
- **Law 3 (Compounding) — cross-plugin reader contract** — Gate 1 plan-verifier가 sister-plugin (`superpowers:writing-plans`)의 출력 경로 `docs/superpowers/plans/`를 1순위 source로 명시 consume; convention drift가 silent breakage가 되지 않도록 README "Plan Discovery Sources" 섹션이 reader/writer 약속을 문서화.
- **AP3 (Trivia ceremony) 회피** — `check-trivia.sh`가 단일 파일·≤3줄 whitespace/rename을 파이프라인 전체 skip.
- **AP9 (Subagent spray) hard gate** — Phase 1+2 dispatch 수가 ≥4일 때 AskUserQuestion 발동.
- **AP16 (Unbounded autonomy) 회피** — Gate 2 내부 fix-loop이 `max_gate2_iterations=5` + repeat-detection (no-progress check) + kill switch로 묶임.
- **P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)** — `.claude/quality-gates/<session-id>/` 하위 per-session markdown state (`*.local.md` gitignore 패턴으로 자동 제외; TTL sweep + SessionEnd hook으로 폴더 GC).
- **Law 1 (Verification Plan)** (v1.8.0) — Gate 3가 evidence-required SKIP을 강제. runtime-verifier가 manifest의 모든 surface를 attempt하고 evidence-log를 산출해야 하며, 증거 없는 SKIP은 skill이 거부하여 FAIL로 격상.
- **Law 2 (Writer ≠ Reviewer, frontmatter tool scoping으로 물리적 분리)** (v1.8.0) — `runtime-verifier` agent가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언. `cp .env.example .env`, `docker compose up` 같은 fixable한 파일 작업은 사용자가 AskUserQuestion에서 명시 선택한 후 skill의 Bash tool로만 수행.
- **AP16 (Unbounded autonomy) 회피 — Gate 3** (v1.8.0) — Gate 3의 NEEDS_RESOLUTION mid-run 루프가 `max_gate3_resolutions` (기본 3, env override `DEVBREW_GATE3_MAX_RESOLUTIONS=0..10`)로 묶임. `needed_hash` 기반 repeat detection이 iteration cap 도달 전에 non-converging loop을 잡음.
- **P21 (Secret이 prompt context에 들어가지 않음)** (v1.8.0) — Gate 3의 AskUserQuestion은 결정과 포인터(yes/no/path)만 묻고 secret 값은 절대 받지 않음. 누락된 secret은 사용자가 disk의 `.env`에 직접 추가 후 retry 선택으로 해결. regression test: `tests/test_no_secret_prompts.py`.
- **Law 2 (Writer ≠ Reviewer, 3-way 분리)** (v1.9.0) — Gate 3가 3-way agent 분리를 강제. writer (originating turn) ≠ `test-scope-validator` (Step 2.5 pre-execution 리뷰어) ≠ `runtime-verifier` (Step 3 executor). 두 reviewer 모두 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 — prompt 기반 분리가 아닌 frontmatter scoping으로 물리적 분리.
- **§5.3 (Categorical signal, no numeric scoring)** (v1.9.0) — `test-scope-validator`는 정확히 4-way enum 분류 (`aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`)만 emit. percentage, confidence, X/Y rating 모두 금지. summary의 counter 정수 (`1 aligned, 0 outdated…`) 는 허용. devbrew §5.3 "수치 스코어링 ban" instantiation.
- **Law 2 strengthening — model-family separation.** Optional `codex-reviewer` agent (when Codex CLI is detected) runs review in a separate process with a different model family (OpenAI vs Anthropic) and an OS-level read-only sandbox, giving 3-layer reviewer-writer isolation: `disallowedTools` + narrow `Bash` allowlist + `codex -s read-only`.
- **Law 2 (3-layer isolation, v1.11.0/v1.12.0)** — `codex-reviewer`의 3-layer isolation: (1) frontmatter `allowedTools`/`disallowedTools` camelCase deny/allow whitelist (AC1 fix, v1.11.1에서 복구), (2) narrow `Bash` allowlist (실제 키 `allowedTools`), (3) `codex exec -s read-only` OS-level sandbox. Layer 1 없이 Layer 2/3는 불완전 — 세 layer가 함께 물리적 격리를 구성.
- **Law 2 (Writer ≠ Reviewer, frontmatter scoping)** (v1.13.0) — `security-reviewer` agent가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언. Phase 1 always-run reviewer 중 4번째로 추가되며, kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`로 사용자가 disable 가능 (Plugin Shape — 모든 reviewer는 opt-out 가능).
- **Law 3 (Compounding — drift 재발 차단, v1.12.0)** — `hooks/session-start-advisor.py` frontmatter scanner (AC14): SessionStart마다 모든 agent 파일의 frontmatter key를 kebab-case drift 검사. `tests/test_agent_frontmatter_keys.sh` (AC15): repo-wide deny-list bash test — CI에서 C1 종류 (kebab-case 잘못된 키) drift를 자동 차단. 이 두 mechanism이 함께 "리뷰를 탈출한 버그 → reviewer persona 편집 + compounding linter 신설" Law 3 instantiation.
- **Law 1 — Clarity Before Code (좌표 계약 측면)**: pipeline 의 단일 좌표 `project_dir` 가 SKILL preflight 에서 frozen 되어 모든 subagent / hook / 외부 codex 프로세스에 명시적으로 propagate. cwd 재계산은 frontmatter Forbidden + grep-anchored drift guard 로 mechanically 차단. (v1.14.0)
- **Law 1 (Clarity Before Code) — `/qg branch <name>` surface** (v1.15.0) — 7개 거절 시나리오(존재하지 않는 브랜치, path traversal, kill switch, idempotent reuse 등)가 `tests/test_branch_worktree.sh` AC1–AC11에 acceptance criteria로 명시. 실패 경로마다 명확한 진단 메시지를 stderr로 출력.
- **Law 3 (Compounding) — worktree path 컨벤션** (v1.15.0) — `.claude/<plugin>/worktrees/<name>-<sid-short>/` 경로 패턴을 `docs/philosophy/devbrew-harness-philosophy.md` §4.8에 footnote로 박아 두어, 차후 다른 플러그인이 임시 worktree를 만들 때 같은 컨벤션을 재사용할 수 있게 함.

## 구조

```
quality-gates/
├── .claude-plugin/         # 플러그인 메타데이터
│   └── plugin.json
├── agents/                 # Gate agent (leaf agent; 파이프라인이 dispatch)
│   ├── plan-verifier.md         # Gate 1
│   ├── runtime-verifier.md      # Gate 3 Step 3 (runner)
│   ├── test-scope-validator.md  # Gate 3 Step 2.5 (pre-exec test scope check)
│   ├── scout.md                 # Gate 2 Phase 0 — 모델 기반 dispatch planner
│   ├── adversarial.md           # Gate 2 Phase 1.5 — false-positive hunter
│   ├── synthesizer.md           # Gate 2 Phase 1.6 — finding dedupe/rank
│   ├── codex-reviewer.md        # Gate 2 Phase 1 — external OpenAI reviewer (Layer 2/3 isolation)
│   └── security-reviewer.md     # Gate 2 Phase 1 always-run — 코드 레벨 보안 리뷰 (injection / authn-authz / secrets / SSRF / crypto-misuse / deserialization / raw-HTML / dependency manifest). Disable: `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`
├── commands/
│   ├── qg.md               # /qg slash command (--reset, --paths, branch flag 포함)
│   └── cancel-qg.md        # /cancel-qg command
├── hooks/
│   ├── hooks.json                            # Hook 설정
│   ├── stop-hook.py                          # 파이프라인 진행 (state machine)
│   ├── post-tool-use-session-tracker.py      # 세션 동안 편집한 파일 추적
│   ├── post-tool-use.py                      # PostToolUse(Bash) — auto-trigger 감지기
│   ├── session-start-advisor.py              # in-flight 파이프라인 read-only advisor
│   └── session-end-cleanup.py                # 정상 종료 시 현재 세션 폴더 제거
├── scripts/
│   ├── setup-qg.sh                           # 파이프라인 초기화
│   ├── pre-pipeline-check.sh                 # in-skill 세션 라이프사이클 체크
│   ├── check-trivia.sh                       # Trivia escape 감지기
│   ├── filter-docs.sh                        # 코드 reviewer용 docs path 필터
│   ├── discover-plan.sh                      # Plan 파일 우선순위 탐색 (Gate 1)
│   ├── detect-runtime.sh                     # Gate 3 런타임 surface 탐지 (manifest 산출)
│   ├── compute-test-scope-candidates.sh      # Gate 3 Step 2.5 — 후보 test 파일 산출 (Python/JS/TS heuristic)
│   ├── detect_codex.sh                       # Codex CLI 7-case probe (version/auth/sandbox/kill-switch/timeout)
│   ├── build_codex_prompt.py                 # Gate 2 Phase 1 codex-reviewer용 prompt builder
│   ├── codex_findings_to_yaml.py             # Codex JSONL stream → 표준 finding YAML (auth/schema/stderr 처리)
│   └── qg-gc.py                              # TTL 기반 stale 세션 GC (fcntl-locked)
├── skills/
│   └── quality-pipeline/
│       ├── SKILL.md         # 단일 게이트 실행기
│       └── references/
│           ├── dependency-check.md   # 사전 의존성 체크
│           └── state-file-format.md  # 파이프라인 state 파일 포맷
└── tests/                            # Bash 단위 테스트 (test_discover_plan.sh 등)
```

## 설치된 Hook

| Hook | 이벤트 | 변경? | 왜 hook인가 (skill이 아닌)? |
|---|---|---|---|
| `stop-hook.py` | Stop | 예 (state 파일) | 매 어시스턴트 turn 이후 파이프라인 진행이 결정적으로 필요. |
| `post-tool-use-session-tracker.py` | PostToolUse(Edit/Write/MultiEdit) | 예 (세션 파일) | 모든 파일 mutation을 결정적으로 관찰해야 함; hook만 가능. |
| `post-tool-use.py` | PostToolUse(Bash) | 아니오 — read-only | commit/PR Bash 활동을 감지해 `/qg` 제안; 현재 세션 scope. |
| `session-start-advisor.py` | SessionStart | **아니오 — read-only advisor** | mutation 없이 in-flight 파이프라인 알림 (CLAUDE.md hook coexistence 룰). |
| `session-end-cleanup.py` | SessionEnd | 예 (자기 세션 폴더 제거) | 정상 종료 시 per-session 정리; crash 시 TTL sweep으로 fallback. |

모든 hook은 `DEVBREW_DISABLE_QUALITY_GATES=1` (전역) 와 hook 단위 override
`DEVBREW_SKIP_HOOKS=quality-gates:<hook-name>`을 따릅니다.

## Cost Class

`quality-pipeline` skill은 `cost_class: variable` — 자동 감지된 depth에 따라 비용이 달라집니다:

| Depth | 기존 default-Opus 베이스라인 대비 비용 |
|---|---|
| Trivia | ~0% (즉시 skip) |
| Quick | ~25–35% |
| Standard | ~30–45% |
| Deep | ~55–75% (AskUserQuestion 게이트 발동) |

트리거 조건과 override flag는 [`commands/qg.md`](commands/qg.md) 참고.

### Codex reviewer cost

The optional `codex-reviewer` agent has `cost_class: variable` — it invokes the user's Codex CLI subscription/API on each `standard`/`deep` Gate 2 dispatch. First-use cost consent gate prompts via `AskUserQuestion`. Per-call wall-clock ceiling: 600s (proxy for cost ceiling — Codex CLI does not currently expose a token cap flag). Disable globally with `DEVBREW_DISABLE_QG_CODEX=1`.

## 게이트

| Gate | 주체 | 목적 | 위임 대상 |
|------|-----|------|---------|
| 1 | plan-verifier agent | plan checkbox와 git diff 교차 확인; `gate1_summary` YAML을 Gate 2로 핸드오프 | feature-dev:code-explorer (구현 추적), superpowers:verification-before-completion (증거) |
| 2 | quality-pipeline skill (inline) | scout 주도 orchestration: depth-aware dispatch + Phase 1.5 adversarial + Phase 1.6 synthesizer | pr-review-toolkit, feature-dev, superpowers (review agent들) |
| 3 | runtime-verifier agent | 앱 시작, 콘솔 에러 확인, 스크린샷 | chrome-devtools-mcp 또는 playwright |

**아키텍처 메모 — 왜 Gate 2는 agent가 없는가**: Claude Code는 skill만 (agent가 아닌) `Agent()`의 `subagent_type`을 사용 가능. Gate 2는 여러 Phase로 review agent를 dispatch해야 하므로 orchestration 로직이 `skills/quality-pipeline/SKILL.md`에 직접 있습니다. Gate 1과 3은 leaf agent (sub-agent dispatch 안 함).

## Gate 2 리뷰 단계 (v1.5.0 재설계)

```
Phase 0  Scout (항상, sonnet) — dispatch plan 산출: depth + agent subset
Phase 1  Critical analysis (depth-aware, 병렬)
  ├── pr-review-toolkit:code-reviewer        (항상; upstream Opus)
  ├── pr-review-toolkit:silent-failure-hunter (Standard/Deep; sonnet override)
  ├── feature-dev:code-reviewer              (Deep 전용)
  └── codex-reviewer                         (external; Codex CLI 가용 + consent 시 자동 포함, LD5)
Phase 2  Conditional (scout 추천만)
  ├── pr-review-toolkit:type-design-analyzer  → 신규 타입
  ├── pr-review-toolkit:pr-test-analyzer      → 테스트 변경
  ├── pr-review-toolkit:comment-analyzer      → 문서
  ├── superpowers:code-reviewer               → plan 정합성
  └── feature-dev:code-architect              → 아키텍처
Phase 1.5  Adversarial (Standard/Deep, opus) — false-positive 사냥
Phase 1.6  Synthesizer (Phase 1 실행 시 항상, sonnet) — dedupe/rank
Phase 3   Polish (one-shot, upstream Opus): pr-review-toolkit:code-simplifier
```

`len(phase1) + len(phase2) >= 4`일 때 AskUserQuestion 발동 (philosophy AP9). 최대 fan-out: Phase 1 (4) + Phase 2 (5) + Phase 1.5 (1) + Phase 1.6 (1) + Phase 3 (1) = 12.

## 파이프라인 흐름 (forward-only state machine, v1.5.0)

```
/qg → setup-qg.sh → pre-pipeline-check → trivia escape?
   ├── yes → 즉시 PASS, 0 dispatch
   └── no  → SKILL.md (Gate 1) → Stop hook → SKILL.md (Gate 2)
              → Stop hook → SKILL.md (Gate 3) → done
```

**v1.5.0에서 cross-gate restart 제거**: Gate 2 / Gate 3 NEEDS_RESTART는 더 이상 Gate 1으로 자동 재진입하지 않습니다. user-choice prompt ("변경을 적용하고 /qg 재실행")로 종료. Gate 2 내부 fix-loop (최대 5회)는 보존.

## 사용

```
/qg                            # 풀 파이프라인; 세션 단위 diff
/qg branch                     # 풀 파이프라인; main 대비 풀 브랜치 diff
/qg --paths <glob>...          # 풀 파이프라인; 명시 path scope
/qg --reset                    # 현재 세션 폴더 + legacy v1.5.0 파일 정리 후 종료
/qg --gc                       # stale sibling 세션 (TTL) sweep 후 종료
/qg gate1                      # plan 검증만
/qg gate2                      # PR 리뷰만
/qg gate3                      # 런타임 검증만
/qg --skip-runtime             # Gate 1 & 2만
/qg --plan <path>              # 특정 plan 파일 사용
/qg --pr-url <url>             # PR URL 명시
/cancel-qg                     # 현재 세션 활성 파이프라인 취소
/cancel-qg --gc                # stale 세션 TTL sweep
/cancel-qg --all               # 전 세션 wipe (확인 + 활성 sibling 리스트 먼저)
```

## Recipes

### 다른 브랜치를 격리된 worktree에서 검사

다른 브랜치를 검사하면서 본인 작업트리는 무손상 유지:

```bash
git fetch origin pull/123/head:pr-123  # PR을 로컬 브랜치로 가져오기
/qg branch pr-123                       # 임시 worktree에서 파이프라인 실행
```

내부 동작:

1. `<repo>/.claude/quality-gates/worktrees/pr-123-<sid>/` 에 detached worktree 생성
2. 그 안에서 Gate 1 → 2 → 3 실행, agent들이 worktree에서 diff를 읽음 (state는 main repo에 머묾, v1.14.0 worktree cwd contract 그대로 적용)
3. 정상 종료 (complete / cancel) 시 자동 cleanup. 비정상 종료 (NEEDS_RESTART 등) 시 보존 + stderr 안내 경로

### 디버깅용 worktree 보존

```bash
DEVBREW_QG_KEEP_WORKTREE=1 /qg branch feat-x
# 종료 후 .claude/quality-gates/worktrees/feat-x-<sid>/ 보존
# 수동 정리: git worktree remove <path>
```

### `/qg branch <name>` 자체를 비활성화

```bash
export DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1
```

`/qg branch` (인자 없음) 은 영향 없음.

## Plan Discovery Sources (Gate 1)

`/qg gate1`이 `--plan <path>`를 받지 않으면 다음 우선순위로 plan 파일을 탐색합니다 (위→아래로 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--plan <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/plans/*.md` (project-local) | checkbox `- [ ]` / `- [x]` 1개 이상 |
| 3 | `~/.claude/plans/*.md` (legacy global) | project-local 비었을 때만 consult. hit 시 deprecation 경고 출력 |

선택된 source 내부에서: unchecked checkbox 있는 파일 우선, 동률이면 mtime 가장 최근. 모두 all-checked면 mtime 가장 최근 ("방금 끝낸 plan, PASS 처리 정상").

**Soft dependency:** project-local source는 `superpowers:writing-plans` skill이 plan을 저장하는 경로 (`docs/superpowers/plans/`) 와 동일합니다. superpowers 플러그인을 설치하지 않았더라도 동일 경로에 `.md` 파일을 직접 두면 동작합니다.

알고리즘 자체는 `scripts/discover-plan.sh`에 분리되어 `tests/test_discover_plan.sh` 10개 fixture로 검증됩니다.

## 사전 요건

| 플러그인 | 필수 | 사용처 | 목적 |
|---------|------|-------|------|
| pr-review-toolkit | 예 | Gate 2 | 핵심 review agent |
| feature-dev | 아니오 | Gate 1, 2 | 컨벤션 리뷰, 아키텍처, 구현 추적 |
| superpowers | 아니오 | Gate 1, 2 | plan 정합성, 증거 검증 |
| chrome-devtools-mcp / playwright | 아니오 | Gate 3 | 브라우저 자동화 |

## 설정

- `MAX_GATE2_ITERATIONS`: 5 (Gate 2 내부 review-fix 사이클 수)
- `QG_STALE_HOURS`: 24 (`pre-pipeline-check.sh`의 세션 파일 staleness 기준)
- `DEVBREW_QG_TTL_HOURS`: 24 (sibling 세션 폴더 TTL; 더 오래된 폴더는 `/qg` 또는 `/cancel-qg --gc`에서 GC)
- `DEVBREW_QG_GC_VERBOSE`: unset (`1`로 설정 시 GC sweep 진단을 stderr로)
- `DEVBREW_DISABLE_GATE3_TEST_VALIDATION`: unset (`1` 설정 시 Gate 3 Step 2.5 (test scope validation) 완전 skip; default unset = validation enabled)
- `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope`: 위와 동일한 kill switch — 기존 hook-skip 패턴과 일관성 유지를 위한 alternate form
- `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1`: `/qg branch <name>` auto-worktree 비활성화 (기능을 disable; `/qg branch` no-arg는 영향 없음)
- `DEVBREW_QG_KEEP_WORKTREE=1`: worktree cleanup 비활성화 (디버깅용 보존)

(`MAX_TOTAL_ITERATIONS`와 cross-gate restart 루프는 v1.5.0에서 제거됨.)

## 파이프라인 state

state는 Claude Code 세션마다 `.claude/quality-gates/<session-id>/`에 추적됩니다:

- `pipeline.md` — 파이프라인 frontmatter (status, current_gate, iteration counters) + body (Gate Results, History).
- `files.md` — 이번 세션에서 편집한 파일들 (`/qg` scope narrowing 용).
- `branch.md` — 마지막으로 본 git 브랜치 (branch-mismatch 감지 용).
- `diff-cache.txt`, `code-paths.tmp` — transient cache.

stale sibling 폴더(mtime이 `DEVBREW_QG_TTL_HOURS`(기본 24h)보다 오래된)는
`/qg` 또는 `/cancel-qg --gc` 실행 시 garbage-collect됩니다. `SessionStart` hook은
strictly read-only (CLAUDE.md 룰); `SessionEnd` hook은 정상 종료 시 현재 세션
폴더를 제거. crash는 TTL sweep으로 fallback.

모든 파일은 `*.local.md` gitignore 패턴에 매칭되며, 별도의 `.gitignore` 변경은
필요 없습니다.
