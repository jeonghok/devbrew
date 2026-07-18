# Quality Gates 플러그인

Claude Code용 2-게이트 품질 검증 파이프라인. 멀티 플러그인 리뷰 위임 구조.

## 인스턴스화한 원칙

이 플러그인은 다음 devbrew 법칙·원칙을 인스턴스화합니다
([`docs/philosophy/devbrew-harness-philosophy.md`](../../docs/philosophy/devbrew-harness-philosophy.md) 참고):

- **Law 3 (Compounding)** — Phase 1 single dispatch builder (T2-2/T3-5). Future persona edits land in one place, never drift across two dispatch sections.
- **Law 2 (Writer ≠ Reviewer)** — 순수 read-only reviewer agent(`security-reviewer`/`adversarial`/`test-scope-validator`)가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 (frontmatter scoping으로 물리적 격리). `runtime-verifier`(sandbox-executor)는 예외로 Write를 갖되 git-diff mutation 가드로 Law 2 self-approval을 구조적으로 차단 — 아래 v2.2.0 bullet 참조.
- **Law 3 (Compounding)** — scout `rationale` 필드가 매 iteration마다 state 파일에 로깅; reviewer-persona 편집이 학습된 교훈을 인코딩하는 substrate.
- **Law 3 (Compounding) — cross-plugin reader contract** — Runtime gate의 test-scope-validator(`scripts/discover-plan.sh`)가 sister-plugin (`superpowers:writing-plans`)의 출력 경로 `docs/superpowers/plans/`를 1순위 source로 명시 consume; convention drift가 silent breakage가 되지 않도록 README "Plan Discovery Sources" 섹션이 reader/writer 약속을 문서화.
- **P12 anti-corollary (former AP5, trivia ceremony) 회피** — `check-trivia.sh`가 단일 파일·≤3줄 whitespace/rename을 파이프라인 전체 skip. *현재 coverage는 whitespace + rename에 국한. P12 canonical 자격(typo/comment-only/single-file formatting)을 완전히 충족하기 위한 확장은 deferred 항목 — Tier 2 spec은 아카이브됨: `git show pre-slim-archive-2026-07-09:docs/superpowers/specs/2026-05-17-qg-tier2-3-improvements-design.md`.*
- **P22 anti-corollary (former AP9, over-dispatching / subagent spray) hard gate** — Phase 1+2 dispatch 수가 ≥4일 때 AskUserQuestion 발동.
- **P18 anti-corollary (former AP16, unbounded autonomy) 회피** — Review gate 내부 fix-loop이 `max_review_iterations=5` + repeat-detection (no-progress check) + kill switch로 묶임.
- **P5 (Filesystem as Memory) + P14 (State Survives Compaction)** — `.claude/quality-gates/<session-id>/` 하위 per-session markdown state (`*.local.md` gitignore 패턴으로 자동 제외; TTL sweep + SessionEnd hook으로 폴더 GC).
- **Law 1 (Verification Plan)** (v1.8.0) — Runtime gate가 evidence-required SKIP을 강제. runtime-verifier가 manifest의 모든 surface를 attempt하고 evidence-log를 산출해야 하며, 증거 없는 SKIP은 skill이 거부하여 FAIL로 격상.
- **Law 2 (Writer ≠ Reviewer, git-diff 구조적 가드)** (v2.2.0; supersedes v1.8.0 tool-deny) — `runtime-verifier`는 이제 **sandbox-executor**다. Write/Edit가 허용되지만 *일회용 git-worktree 샌드박스 안에서만* 의미를 가지며, orchestrator(SKILL)가 샌드박스 생성 시 code-under-review를 immutable baseline commit `B`로 봉인하고 gate 종료 시 `qg-worktree.sh mutation-guard`(순수 git, verifier 주장과 독립)로 product 변경을 ground-truth로 산출 — 비어있지 않으면 verdict가 구조적으로 ≤FAIL로 강제되고 아무것도 commit되지 않으며 샌드박스는 폐기된다. 즉 self-approval 방지의 *물리적 보장 형태*가 "도구 deny" → "git ground-truth 가드"로 바뀐 것이지 보장이 사라진 것이 아니다. **대비: `test-scope-validator`/`security-reviewer`/`adversarial`은 순수 read-only reviewer로 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 불변.** 운영 DB/네트워크는 git-ignored 파일(prod `.env`) 미복사로 미접근. regression: `tests/test_qg_mutation_guard.sh`(가드 독립성), `tests/test_qg_runtime_sandbox.sh`(ignored 미복사).
- **Law 1 (Clarity / evidence-required) — 기능 단언** (v2.2.0) — Runtime gate가 spec Acceptance Criteria를 verifier에 thread해, 단순 "떴나?"가 아니라 AC별 flow를 구동하고 expected-vs-observed를 evidence(screenshot + DOM snapshot + network status)와 함께 단언. evidence 없는 "동작함"은 거부. spec 부재 시 plan_feature → smoke fallback(loud log).
- **운영-안전 게이트 (blast-radius)** (v2.2.0) — `detect-runtime.sh`가 process-start/네트워크/파괴 신호 surface를 `requires_decision: true`로 분류하고, SKILL의 Upfront Execution Plan이 그것들을 1회 사용자 승인 뒤로 둔다(deny-by-default). 운영 DB/네트워크는 샌드박스가 git-ignored prod config를 복사하지 않아 원천 차단(OS-수준 egress 격리는 명시적 non-goal — 한계 인정).
- **P18 — Upfront 1-회 결정 + 폐기** (v2.2.0; gate-scope 확장 v2.4.0) — **gate scope**(Review gate only / Run both gates)는 full `/qg`(gate arg 없음)마다 trivia escape 후 1회 발화하고(`/qg both|review|runtime`이면 0클릭), runtime 범위·block 정책은 `requires_decision` surface가 있을 때만 1회 확정(없으면 zero-click). executor-내부 setup retry ≤3/dispatch, SKILL re-dispatch ≤`runtime_max_resolutions`; 곱이 hard ceiling. kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`. fallback(샌드박스 비활성)에서도 working-tree `git status` mutation 체크로 Law 2 구조적 보장 유지(verifier가 실제 트리를 바꾸면 ≤FAIL + loud warn).
- **P8 determinism-economy (harness lightness — trust the model)** (v2.5.0) — 암묵 session scope로 Review gate가 돌 때 그 사실을 사용자-가시 한 줄로 밝히는 **scope 투명성**. 버려진 결정론적 under-coverage 경고를 결정론 가드가 아니라 *모델 행동*으로 대체(git 비교·차단 없음). 자연어 scope 의도는 별도 parser 없이 모델이 branch scope로 해석 — `/qg branch`는 결정론적 escape hatch로 유지. devbrew P8 determinism-economy refinement("Zero hooks" 일반화) instantiation.
- **P8 determinism-economy — self-honest verdict floor** (v2.6.0; routing 제거·단순화 v2.7.0) — Review gate가 *검토받았다고 믿는 scope*와 *resolve한 scope*가 발산할 때(빈 세션 → resolved scope 0 → "clean"의 false-clean)를 봉쇄. read-only `scripts/check-review-scope.sh`가 `changes_exist`를 결정론으로 emit하고, SKILL이 iter-1에서 1회 호출·캐시해 **정직-verdict floor**(load-bearing, kill 불가)가 `resolved scope 0 AND changes_exist == yes`이면 verdict를 `no scope reviewed … NOT certified clean`으로 교체. **무엇을 리뷰할지(routing)는 모델이 소유** — v2.7.0에서 v2.6.0의 redirect 게이트·`$effective_diff_scope` 배선·redirect kill switch를 제거하고 `/qg branch` escape hatch + honesty norm 한 줄로 대체(dogfood 5버그가 전부 routing 재구성에서 나왔고 floor의 load-bearing 입력 `changes_exist`는 틀린 적 없음). 결정론은 무결성 floor 한 점에만; routing/자연어는 모델 신뢰. genuine no-op·session 기본값·`/qg branch`는 무변경. regression: `tests/test_check_review_scope.sh`, `tests/test_qg_false_clean_floor.sh`.
- **P18 anti-corollary (former AP16, unbounded autonomy) 회피 — Runtime gate** (v1.8.0) — Runtime gate의 NEEDS_RESOLUTION mid-run 루프가 `runtime_max_resolutions` (기본 3, env override `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS=0..10`)로 묶임. `needed_hash` 기반 repeat detection이 iteration cap 도달 전에 non-converging loop을 잡음.
- **P21 (Secret이 prompt context에 들어가지 않음)** (v1.8.0) — Runtime gate의 AskUserQuestion은 결정과 포인터(yes/no/path)만 묻고 secret 값은 절대 받지 않음. 누락된 secret은 사용자가 disk의 `.env`에 직접 추가 후 retry 선택으로 해결. regression test: `tests/test_no_secret_prompts.py`.
- **Law 2 (Writer ≠ Reviewer, 3-way 분리)** (v1.9.0) — Runtime gate가 3-way agent 분리를 강제. writer (originating turn) ≠ `test-scope-validator` (Step 2.5 pre-execution 리뷰어) ≠ `runtime-verifier` (Step 3 executor). `test-scope-validator`는 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]`로 물리 분리(불변). `runtime-verifier`는 v2.2.0부터 sandbox-executor로, Write를 갖되 git-diff mutation 가드(구조적)로 Law 2 self-approval을 차단 — 분리의 형태만 다르고 writer≠approver 불변식은 유지.
- **P2 (Categorical signal, no numeric scoring)** (v1.9.0) — `test-scope-validator`는 정확히 4-way enum 분류 (`aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`)만 emit. percentage, confidence, X/Y rating 모두 금지. summary의 counter 정수 (`1 aligned, 0 outdated…`) 는 허용. devbrew P2 "수치 스코어링 ban" instantiation.
- **Law 2 strengthening — model-family separation.** Optional `codex-reviewer` agent (when Codex CLI is detected) runs review in a separate process with a different model family (OpenAI vs Anthropic) and an OS-level read-only sandbox, giving 3-layer reviewer-writer isolation: `disallowedTools` + narrow `Bash` allowlist + `codex -s read-only`.
- **Law 2 (codex 격리, v1.11.0/v1.12.0 → v2.11.0 정정)** — codex 리뷰의 격리는 **`codex exec -s read-only` OS-level 샌드박스 + 별도 프로세스/모델 패밀리**가 전부다. v1.11.0~v2.10.x의 이 항목은 그 위에 *"frontmatter 키 whitelist"* layer를 얹었다고 기록했으나 **그 layer는 존재한 적이 없다**: (1) 당시 명명된 키는 공식 subagent 규격에 없는 필드라 런타임이 조용히 무시했고, (2) T3-3에서 `codex-reviewer`가 agent → 스크립트(`scripts/run_codex_reviewer.sh`)로 이관돼 frontmatter 자체가 사라졌다 (`tests/test_codex_reviewer_frontmatter.sh`가 agent 파일 **부재**를 assert). 지금 격리를 지탱하는 것은 OS 샌드박스다.
- **Law 2 (Writer ≠ Reviewer, frontmatter scoping)** (v1.13.0) — `security-reviewer` agent가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언. Phase 1 always-run reviewer 중 4번째로 추가되며, kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`로 사용자가 disable 가능 (Plugin Shape — 모든 reviewer는 opt-out 가능).
- **Law 3 (Compounding — drift 재발 차단, v1.12.0)** — `hooks/session-start-advisor.py` frontmatter scanner (AC14): SessionStart마다 모든 agent 파일의 frontmatter key를 kebab-case drift 검사. `tests/test_agent_frontmatter_keys.sh` (AC15): repo-wide deny-list bash test — CI에서 C1 종류 (kebab-case 잘못된 키) drift를 자동 차단. 이 두 mechanism이 함께 "리뷰를 탈출한 버그 → reviewer persona 편집 + compounding linter 신설" Law 3 instantiation.
- **Law 1 — Clarity Before Code (좌표 계약 측면)**: pipeline 의 단일 좌표 `project_dir` 가 SKILL preflight 에서 frozen 되어 모든 subagent / hook / 외부 codex 프로세스에 명시적으로 propagate. cwd 재계산은 frontmatter Forbidden + grep-anchored drift guard 로 mechanically 차단. (v1.14.0)
- **Law 1 (Clarity Before Code) — `/qg branch <name>` surface** (v1.15.0) — 7개 거절 시나리오(존재하지 않는 브랜치, path traversal, kill switch, idempotent reuse 등)가 `tests/test_branch_worktree.sh` AC1–AC11에 acceptance criteria로 명시. 실패 경로마다 명확한 진단 메시지를 stderr로 출력.
- **Law 3 (Compounding) — worktree path 컨벤션** (v1.15.0) — `.claude/<plugin>/worktrees/<name>-<sid-short>/` 경로 패턴을 플러그인 공통 컨벤션으로 확립해, 차후 다른 플러그인이 임시 worktree를 만들 때 같은 컨벤션을 재사용할 수 있게 함.
- **Law 1 (Clarity Before Code) — single-turn dispatch contract** (v1.32.0) — pipeline progression이 `quality-pipeline` SKILL의 단일 assistant turn 내 serial dispatch로 일원화. cross-turn state machine (transition compute helpers, no-signal counter, 시간 기반 guard) 전부 삭제 — 진행 결정은 SKILL의 명시적 boundary + AskUserQuestion으로만 발생. State file은 GC mtime anchor + worktree tracking + Review gate iter counter reporting만 보존.
- **P22 generalization (consent gate → progression gate):** AskUserQuestion
  is reused as a **progression primitive** at every gate boundary and Gate
  2 fix-loop iteration. The same tool that gates subagent fan-out now
  gates inter-gate progression — no new principle ID needed.
- **C66 (Linked Artifact Flow) — spec을 truth로 instantiate** (v2.1.0) — qg가 처음으로 사용자 프로젝트 spec을 읽어(`scripts/discover-spec.sh`) test-scope-validator의 기준 축을 plan items → **spec Acceptance Criteria**로 전환하고, AC별 커버리지를 advisory `ac_coverage` 블록으로 surface하며, codex 경로(`run_codex_reviewer.sh`)가 spec AC를 `<spec_context>`에 주입. cycle 위계(spec=truth ⊃ plan=구현 방식)를 instantiate — spec→test 커버리지를 역방향 walk. plan은 구현-방식 보조 hint로 강등(제거 아님; `discover-plan.sh` byte-identical). **advisory only — Runtime gate를 block하지 않음.** spec 부재 시 loud log + v2.0.0 기능 동작 fallback. kill switch `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`.
- **P21 (Untrusted input — diff is data, not instructions)** (v2.8.0) — Review gate의 두 diff-reading reviewer(`security-reviewer`/`adversarial`)가 attacker-influenced `filtered_diff`(및 finding 텍스트)를 데이터로만 다루고 그 안의 prompt-injection·안전성 주장을 verdict 근거로 삼지 않도록 persona에 명시. 더해 언어/프레임워크 FP precedent 5건을 기능별 단일 배치(DRY)로 흡수 — suppress-at-source 3(security-reviewer anti-flag) + reject-at-verify 2(adversarial Gate C). 섹션-스코프 grep 회귀 락(`test_security_reviewer_persona.sh`/`test_adversarial_persona.sh`)으로 persona 약화 검출. 신규 P# 0, 결정론 가드 0 (Anthropic *"Using LLMs to Secure Source Code"* 평가 Tier-1; design-lightness).
- **P21 (Secret이 prompt context에 들어가지 않음) — 출력값 유출 차단으로 확장 (publish sink)** (v2.9.0) — `/qg-publish`가 게시 직전 `secret-scan.py`로 전체 payload(artifact + PR title + 브랜치명 + 커밋메시지; PR-create 시 히스토리까지)에서 시크릿 **값**(quoted string / vendor 패턴 / corpus-substring, keyword는 보조 신호)을 스캔해 hit 시 게시를 FAIL CLOSED로 거부한다 — 스캔 에러·타임아웃도 hit 취급. 기존 인스턴스(v1.8.0, secret 값이 prompt로 들어가지 않음)와 자매지만 방향이 반대다: 여기는 모델이 저술한 텍스트가 GitHub로 **나가기 전** 값 유출을 막는다. regression: `tests/test_secret_scan.py`, `tests/test_secret_scan_fp.py`.
- **P21 (Untrusted input — diff is data, not instructions) 확장** (v2.9.0) — v2.8.0에서 Review gate 두 reviewer에 넣은 norm을 `pr-understanding-builder` 페르소나와 publish orchestrator에도 확장한다. PR 코멘트는 id+마커 매칭용 opaque bytes로만 다루고(스크립트가 선택 계산; 모델이 내용을 읽고 지시로 따르지 않음), artifact 내 이미지는 auto-fetch 유출 벡터라 중립화한다.
- **P17 (Consent) — 게시는 게이트가 아니라 opt-in consent-gated 표면** (v2.9.0) — `/qg-publish`는 매 실행마다 사람이 읽는 preview 뒤 AskUserQuestion으로 명시 동의를 받아야만 GitHub에 쓴다(비가역·영구 노출 고지 포함; cross-repo "always" 없음). **`/qg`의 Review gate/Runtime gate 자체는 이 기능으로 변경되지 않는다 — publish는 그 위에 얹힌 별도 opt-in 표면이지 세 번째 게이트가 아니다.**
- **P18 (Bounded idempotency)** (v2.9.0) — `comment-upsert.py`가 인증 `user.id` 스코프 내에서 버전-패밀리 마커(`<!-- pr-understanding:v1 -->`, 첫 줄 anchored 매칭이 optional `tier=N` 접미사를 허용 — 빌더는 `tier=N`을 emit하지만 tier는 변경 파일 수에 따라 드리프트하므로 매칭은 tier를 무시해 멱등이 깨지지 않게 함)로 기존 코멘트를 조회해 0개→POST, 1개→PATCH, ≥2개(비정상)→REFUSE — 모호성 앞에서 임의로 고르지 않고 결정론적으로 멈추고 사용자 확인을 요구한다.
- **pwn-request Law-2형 물리 분리 — 생성 ≠ 게시** (v2.9.0 → v2.11.0에서 **처음으로 사실이 됨**) — `pr-understanding-builder` 에이전트는 `tools:`에 무해한 항목 **하나만** 선언한다 (fail-closed allowlist — 쓰기·실행·네트워크·위임 도구 0개, 유일 항목 = inert `Read`(생성기가 미호출), 유일 입력 = inlined `build-pr-context.sh` blob). `gh`/네트워크는 오직 `publishing-pr-understanding` skill(오케스트레이터)만 보유한다. ⚠️ **v2.9.0~v2.10.x에서 이 주장은 거짓이었다**: 당시 격리는 존재하지 않는 필드 + 11개 이름 denylist였고, denylist에 `mcp__*`가 없어 tavily 웹검색·chrome-devtools 브라우저 제어가 **열려 있었다**. 이름 기반 denylist는 원리적으로 닫을 수 없다 — `Monitor`가 이름 없는 셸(`command`)과 이름 없는 egress(`ws`)를 준다. allowlist만이 열거되지 않은 것과 **미래에 추가될 것**을 자동 차단한다.

## 구조

```
quality-gates/
├── .claude-plugin/         # 플러그인 메타데이터
│   └── plugin.json
├── agents/                 # Gate agent (leaf agent; 파이프라인이 dispatch)
│   ├── runtime-verifier.md      # Runtime gate Step 3 (sandbox executor — model inherit)
│   ├── test-scope-validator.md  # Runtime gate Step 2.5 (pre-exec test scope check)
│   ├── scout.md                 # Review gate Phase 0 — 모델 기반 dispatch planner
│   ├── adversarial.md           # Review gate Phase 1.5 — false-positive hunter
│   ├── synthesizer.md           # Review gate Phase 1.6 — finding dedupe/rank
│   ├── codex-reviewer.md        # Review gate Phase 1 — external OpenAI reviewer (Layer 2/3 isolation)
│   ├── security-reviewer.md     # Review gate Phase 1 always-run — 코드 레벨 보안 리뷰 (injection / authn-authz / secrets / SSRF / crypto-misuse / deserialization / raw-HTML / dependency manifest). Disable: `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`
│   └── pr-understanding-builder.md  # publish 생성기 — model: opus, tools: Read 1개 (inert·미호출; fail-closed; 쓰기·실행·네트워크·위임 0; 유일 입력 = inlined blob)
├── commands/
│   ├── qg.md               # /qg slash command (--reset, --paths, branch flag 포함)
│   ├── qg-publish.md       # /qg-publish slash command ([--dry-run]; publish skill로 얇은 dispatch)
│   └── cancel-qg.md        # /cancel-qg command
├── hooks/
│   ├── hooks.json                            # Hook 설정
│   ├── post-tool-use-session-tracker.py      # 세션 동안 편집한 파일 추적
│   ├── post-tool-use.py                      # PostToolUse(Bash) — auto-trigger 감지기; publish sentinel 존재 시 재유도 억제(AC11)
│   ├── session-start-advisor.py              # in-flight 파이프라인 read-only advisor
│   └── session-end-cleanup.py                # 정상 종료 시 현재 세션 폴더 제거
├── scripts/
│   ├── setup-qg.sh                           # 파이프라인 초기화
│   ├── pre-pipeline-check.sh                 # in-skill 세션 라이프사이클 체크
│   ├── check-trivia.sh                       # Trivia escape 감지기
│   ├── filter-docs.sh                        # 코드 reviewer용 docs path 필터
│   ├── discover-plan.sh                      # Plan 파일 우선순위 탐색 (Runtime gate test-scope-validator)
│   ├── discover-spec.sh                      # Spec 파일 우선순위 탐색 (test-scope-validator + codex; AC-섹션 적격성)
│   ├── detect-runtime.sh                     # Runtime gate 런타임 surface 탐지 (manifest 산출)
│   ├── compute-test-scope-candidates.sh      # Runtime gate Step 2.5 — 후보 test 파일 산출 (Python/JS/TS heuristic)
│   ├── detect_codex.sh                       # Codex CLI 7-case probe (version/auth/sandbox/kill-switch/timeout)
│   ├── build_codex_prompt.py                 # Review gate Phase 1 codex-reviewer용 prompt builder
│   ├── codex_findings_to_yaml.py             # Codex JSONL stream → 표준 finding YAML (auth/schema/stderr 처리)
│   ├── qg-gc.py                              # TTL 기반 stale 세션 GC (fcntl-locked)
│   ├── build-pr-context.sh                   # publish: base..HEAD 고정 context blob (diff+내용+이웃 시그니처+커밋메시지) — 빌더의 유일 입력
│   ├── diagram-facts.sh                      # publish: nodes/edges 산출 (changed files + 이웃 import; repo-root 상대 import만)
│   ├── secret-scan.py                        # publish: 게시 직전 값-차단 secret scan (FAIL CLOSED)
│   ├── pr-detect.sh                          # publish: 현재 브랜치의 PR 상태 탐지 (has_pr/number/url/state/head_pushed)
│   ├── comment-upsert.py                     # publish: marker 기반 멱등 upsert (user.id 스코프, 0/1/≥2 REFUSE) — DEVBREW_QG_DISABLE_PUBLISH 최내부 sink
│   ├── render-terminal.py                    # publish + Final Summary 공용 STATUS 표 / ASCII diagram / accuracy-warnings 렌더러
│   └── gh-identity.sh                        # publish: 인증 user login+numeric id 조회 (`gh api user` 캡슐화; empty id는 fail-closed)
├── skills/
│   ├── quality-pipeline/
│   │   ├── SKILL.md         # 단일 게이트 실행기
│   │   └── references/
│   │       ├── dependency-check.md   # 사전 의존성 체크
│   │       └── state-file-format.md  # 파이프라인 state 파일 포맷
│   └── publishing-pr-understanding/
│       └── SKILL.md         # /qg-publish orchestrator — gh를 가진 유일 컴포넌트 (cost_class: variable)
└── tests/                            # Bash/Python 단위 테스트 (test_discover_plan.sh, test_qg_publish_docs.sh 등)
```

## 설치된 Hook

| Hook | 이벤트 | 변경? | 왜 hook인가 (skill이 아닌)? |
|---|---|---|---|
| `post-tool-use-session-tracker.py` | PostToolUse(Edit/Write/MultiEdit) | 예 (세션 파일) | 모든 파일 mutation을 결정적으로 관찰해야 함; hook만 가능. |
| `post-tool-use.py` | PostToolUse(Bash) | 아니오 — read-only | commit/PR Bash 활동을 감지해 `/qg` 제안; 현재 세션 scope. `/qg-publish`는 `pr-create.sh`로 PR을 만들어 hook의 `gh pr create` 커맨드 매칭에 애초에 안 걸린다; 추가로 publish sentinel `publish-active.md`가 있으면 (직접 `gh pr create` 경로에서도) 억제한다(AC11, defense-in-depth) — publish와 review 두 표면이 서로 훈수 두지 않게. |
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

The optional `codex-reviewer` agent has `cost_class: variable` — it invokes the user's Codex CLI subscription/API on each `standard`/`deep` Review gate dispatch. First-use cost consent gate prompts via `AskUserQuestion`. Disable globally with `DEVBREW_DISABLE_QG_CODEX=1`.

### PR-understanding publish cost (`/qg-publish`, separate from the two gates)

`publishing-pr-understanding` skill은 `cost_class: variable` (context 크기·tier에 따라 다름). 저술을 맡는 `pr-understanding-builder`는 매 tier `model: opus`로 고정 — Deep tier만 실행 전 upfront cost 고지(AskUserQuestion)를 하며, 작은 diff는 비용이 자연히 bounded되고 `/qg-publish`는 명시적 실행이 곧 비용 수용이며, `/qg` 완료 시의 command-layer opt-in offer로도 이어질 수 있으나 자동 실행이 아니다(offer + 자체 consent = 2 touchpoint). Review/Runtime 두 게이트의 비용 표(위)와는 **완전히 별도** — publish는 게이트가 아니므로 depth 기반 자동 트리거가 없다.

### Adversarial reviewer model

`adversarial` agent uses `model: opus`. It is the **Opus-critic over the Sonnet Phase 1 workers** (cf. Anthropic multi-agent patterns: spend capability at the judgment bottleneck): the Phase 1/2 reviewers run on cheaper models and the synthesizer after it is a deterministic script, so adversarial is the *single model-based judgment gate* in the Review gate — every finding the user sees passed through its verdict. Its persona runs a per-finding 3-gate verification (real? / introduced-by-this-diff? / handled-elsewhere?) plus a severity realist check, which is reasoning-heavy enough to warrant opus. A prior cost pass (T2-8) drifted the frontmatter/README toward sonnet while the SKILL dispatch still pinned opus; the three sites are now reconciled to opus and locked by `tests/test_adversarial_model_consistency.sh`. Runs ~once per Review gate fix-loop iteration (≤5×). AskUserQuestion fan-out count excludes `adversarial`/`scout`/`synthesizer` (infrastructure dispatches; not user-visible cost). To reduce its cost, lower the *number* of Review gate iterations or the diff scope — not this model.

## 게이트

| 게이트 | 주체 | 목적 | 위임 대상 |
|------|-----|------|---------|
| Review gate | quality-pipeline skill (inline) | scout 주도 orchestration: depth-aware dispatch + Phase 1.5 adversarial + Phase 1.6 synthesizer | pr-review-toolkit, feature-dev, superpowers (review agent들) |
| Runtime gate | runtime-verifier agent | 앱 시작, 콘솔 에러 확인, 스크린샷 | chrome-devtools-mcp 또는 playwright |

**아키텍처 메모 — 왜 Review gate는 agent가 없는가**: Claude Code는 skill만 (agent가 아닌) `Agent()`의 `subagent_type`을 사용 가능. Review gate는 여러 Phase로 review agent를 dispatch해야 하므로 orchestration 로직이 `skills/quality-pipeline/SKILL.md`에 직접 있습니다. Runtime gate는 leaf agent (sub-agent dispatch 안 함).

**`/qg-publish` (PR-understanding generate/publish)는 세 번째 게이트가 아니다.** (v2.9.0)
`gh`는 위 두 게이트 어디에도 없다 — publish는 별도 skill(`publishing-pr-understanding`)에
격리된 **consent-gated opt-in 표면**이지, `/qg`의 Review/Runtime gate에 자동으로 연결되지
않는다. 정직 문구: 이 표면은 **deterministic envelope + model-authored content** —
gh I/O·secret-scan·marker-scoped idempotent upsert는 결정론 스크립트가 통제하고, 사람이
읽는 실제 산출물 텍스트는 opus 빌더가 저술한 model-authored content다. 게시는 매 실행
사람이 preview를 읽고 AskUserQuestion으로 명시 동의한 뒤에만 일어난다. `/qg` 완료 시
command-layer opt-in offer로 이어질 수 있으나 **자동 실행은 아니다** — offer(1차)와
publish의 informed-consent(2차) 둘 다 사람의 명시 동의가 필요하다(2 touchpoint).
세 번째 게이트도 아니고, gh는 여전히 게이트 어디에도 없다. 자세한 내용은
[`commands/qg-publish.md`](commands/qg-publish.md).

## Review gate 리뷰 단계 (v1.5.0 재설계)

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

## 파이프라인 흐름 (single-turn serial dispatch, v1.32.0)

`v1.32.0`에서 SKILL이 전체 파이프라인을 단일 assistant turn 내에서 serial dispatch로 실행합니다. Inter-gate progression과 Review gate fix-loop iteration은 모두 AskUserQuestion으로 사용자 동의를 받아 진행 — 동일한 도구가 subagent fan-out gate와 inter-gate progression gate를 함께 담당합니다. (v1.5.0의 turn-by-turn state machine 다이어그램은 제거됨; 단일 다이어그램만 유지.)


```
┌─ single assistant turn ──────────────────────────────────────────────┐
│                                                                       │
│   user: /qg                                                           │
│       │                                                               │
│       ▼                                                               │
│   setup-qg.sh --ensure  (creates .claude/quality-gates/<sid>/...)     │
│       │                                                               │
│       ▼                                                               │
│   SKILL preflight  (kill switch, pre-pipeline-check)                  │
│       │                                                               │
│       ▼                                                               │
│   trivia escape? ─── yes ──▶ "Trivia diff — all gates skipped"        │
│       │ no                                                            │
│       ▼                                                               │
│   gate scope?  AskUserQuestion ("...both gates?")                     │
│   (skipped if review | runtime | both | --skip-runtime arg)           │
│       ├── "Review gate only" ──▶ Review gate, then Final summary      │
│       │ "Run both gates"                                              │
│       ▼                                                               │
│   Review gate iter loop (≤5)                                          │
│       │                                                               │
│       ├── findings empty ──────────────────────────┐                  │
│       │                                            │                  │
│       └── findings remain ──▶ AskUserQuestion      │                  │
│                              ("findings remain..."  │                  │
│                               Retry / Proceed to    │                  │
│                               Runtime gate / Stop)  │                  │
│                                  │                  ▼                  │
│                                  └────────▶ Runtime gate dispatch      │
│                                             (runtime-verifier)         │
│                                                  │                     │
│                                                  ├── PASS              │
│                                                  ├── FAIL              │
│                                                  ├── SKIP_WITH_EVIDENCE │
│                                                  └── NEEDS_RESOLUTION   │
│                                                         ▶ AskUserQuestion
│                                                         ("Runtime
│                                                          verifier needs..."
│                                                          P21 reaffirmed)
│                                                  │                     │
│       ▼                                          ▼                     │
│   Final summary                                                       │
│                                                                       │
└───────────────────────────────────────────────────────────────────────┘
```

**v1.32.0 변경 요약**: 파이프라인 진행은 더 이상 turn-by-turn state machine으로 진행되지 않고, `quality-pipeline` SKILL이 단일 assistant turn 내에서 serial dispatch로 끝까지 실행합니다. AskUserQuestion이 subagent fan-out gate와 inter-gate progression gate를 함께 담당합니다.

### Trivia detector coverage

`scripts/check-trivia.sh`가 인식하는 trivia kind. 매칭 시 `/qg`는 dispatch를 건너뜀.

| kind | regex/조건 | 예 (positive) | 예 (negative) |
|---|---|---|---|
| `whitespace` | `git diff -w`가 비어 있음 | 들여쓰기 normalize | 한 토큰이라도 추가/삭제 |
| `rename` | `--diff-filter=R` ≥1 + content 변경 0 | `git mv a.py b.py` | `mv` + 한 줄 수정 |
| `comment` | 변경 line ≤3, 모두 `^[+-]\s*(#\|//\|--\|/*\|*)` 매칭 | docstring 한 줄 수정 | 코드 + 주석 혼합 |
| `typo` | 한 line 수정, 1 token만 다름, 길이 차 ≤2 | `colour → color`, `userId → userPid` | `userID → userIdentifier` (rename) |
| `untracked-newfile` | 새 파일 1개, ≤3줄, 모두 빈/주석/shebang | 빈 placeholder 추가 | 새 함수 정의 추가 |

`comment`, `typo`, `untracked-newfile`은 v1.16.0 (T2-1)에서 추가.

## 사용

```
/qg                            # gate scope 질문 후 실행; 세션 단위 diff
/qg branch                     # gate scope 질문 후 실행; main 대비 풀 브랜치 diff
/qg --paths <glob>...          # gate scope 질문 후 실행; 명시 path scope
/qg --reset                    # 현재 세션 폴더 + legacy v1.5.0 파일 정리 후 종료
/qg --gc                       # stale sibling 세션 (TTL) sweep 후 종료
/qg both                       # 두 게이트 모두 실행 (gate scope 질문 없음)
/qg review                     # Review gate만
/qg runtime                    # Runtime gate만
/qg --skip-runtime             # Review gate만 (런타임 skip)
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
2. 그 안에서 Review gate → Runtime gate 실행, agent들이 worktree에서 diff를 읽음 (state는 main repo에 머묾, v1.14.0 worktree cwd contract 그대로 적용)
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

## Plan Discovery Sources (Runtime gate test-scope-validator)

Runtime gate의 test-scope-validator가 `--plan <path>`를 받지 않으면 다음 우선순위로 plan 파일을 탐색합니다 (`scripts/discover-plan.sh`; 위→아래로 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--plan <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/plans/*.md` (project-local) | checkbox `- [ ]` / `- [x]` 1개 이상 |
| 3 | `~/.claude/plans/*.md` (legacy global) | project-local 비었을 때만 consult. hit 시 deprecation 경고 출력 |

선택된 source 내부에서: unchecked checkbox 있는 파일 우선, 동률이면 mtime 가장 최근. 모두 all-checked면 mtime 가장 최근 ("방금 끝낸 plan, PASS 처리 정상").

**Soft dependency:** project-local source는 `superpowers:writing-plans` skill이 plan을 저장하는 경로 (`docs/superpowers/plans/`) 와 동일합니다. superpowers 플러그인을 설치하지 않았더라도 동일 경로에 `.md` 파일을 직접 두면 동작합니다.

알고리즘 자체는 `scripts/discover-plan.sh`에 분리되어 `tests/test_discover_plan.sh` 10개 fixture로 검증됩니다.

## Spec Discovery Sources (Runtime gate test-scope-validator + Review gate codex)

Runtime gate의 test-scope-validator와 Review gate codex가 명시적 spec 경로를 받지 않으면 다음 우선순위로 사용자 프로젝트의 **spec**(Acceptance Criteria의 truth)을 탐색합니다 (`scripts/discover-spec.sh`; 위→아래 첫 자격 candidate에서 멈춤):

| 우선순위 | 위치 | 자격 조건 |
|---|---|---|
| 1 | `--spec <path>` (CLI 명시) | 존재하면 사용. 없으면 SKIP (fallback 안 함) |
| 2 | `./docs/superpowers/specs/*.md` (project-local) | `^#+ .*Acceptance Criteria` 섹션 헤더 1개 이상 |

plan과 달리 **legacy-global 소스는 없습니다** — spec은 프로젝트 artifact (글로벌 위치 관행 부재). 자격 파일 중 mtime 가장 최근이 선택됩니다.

**advisory only.** spec이 발견되면 test-scope-validator가 `ac_coverage` 블록(`note: "advisory only — does not block"` + AC별 covered/uncovered + covered_by 테스트 ref)을 emit하고, codex 경로(`run_codex_reviewer.sh`)가 spec의 AC 섹션을 `<spec_context>`에 script-internal로 주입합니다. 어느 경우에도 Runtime gate verdict를 **block하지 않습니다.** spec이 없으면 loud log를 출력하고 v2.0.0 동작(plan-기반 scope)으로 fallback합니다.

**kill switch:** `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1` — spec이 있어도 no-spec 경로를 강제 (ac_coverage 생략, codex `<spec_context>` 비움; validator는 plan-기반 계속).

**Soft dependency:** project-local source는 `superpowers:brainstorming` / `spec-distill`이 spec을 저장하는 경로 (`docs/superpowers/specs/`)와 동일합니다. spec-distill / `superpowers:brainstorming` 플러그인을 설치하지 않았더라도 동일 경로에 `.md` 파일을 직접 두면 동작합니다.

알고리즘 자체는 `scripts/discover-spec.sh`에 분리되어 `tests/test_discover_spec.sh` 8개 fixture로 검증됩니다.

## 사전 요건

| 플러그인 | 필수 | 사용처 | 목적 |
|---------|------|-------|------|
| pr-review-toolkit | 예 | Review gate | 핵심 review agent |
| feature-dev | 아니오 | Review gate | 컨벤션 리뷰, 아키텍처, 구현 추적 |
| superpowers | 아니오 | Review gate | plan 정합성, 증거 검증 |
| chrome-devtools-mcp / playwright | 아니오 | Runtime gate | 브라우저 자동화 |

## 설정

### Tuning knobs

- `MAX_REVIEW_ITERATIONS`: 5 (Review gate 내부 review-fix 사이클 수)
- `QG_STALE_HOURS`: 24 (`pre-pipeline-check.sh`의 세션 파일 staleness 기준)
- `DEVBREW_QG_TTL_HOURS`: 24 (sibling 세션 폴더 TTL; 더 오래된 폴더는 `/qg` 또는 `/cancel-qg --gc`에서 GC)
- `DEVBREW_QG_GC_VERBOSE`: unset (`1`로 설정 시 GC sweep 진단을 stderr로)
- `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`: 3 (`0..10`, Runtime gate NEEDS_RESOLUTION mid-run 루프 cap)
- `DEVBREW_QG_KEEP_WORKTREE=1`: `/qg branch` worktree cleanup 비활성화 (디버깅용 보존)

### Kill switches (보안 컨트롤)

CLAUDE.md Plugin Shape: *"kill switch는 보안 컨트롤"*. 모든 component 비활성화 경로는 환경 변수 한 번으로 cover되어야 함. 아래는 source-of-truth 인벤토리.

**전역 (모든 hook + 모든 reviewer 비활성화):**

| Env var | 효과 |
|---|---|
| `DEVBREW_DISABLE_QUALITY_GATES=1` | 모든 quality-gates hook + `qg-gc.py` no-op. `/qg`는 여전히 invocable하지만 hook이 fire하지 않음. `/qg` 완료 시의 command-layer publish offer도 skip된다(offer step-1이 이 전역 kill switch도 존중 — kill switch는 보안 컨트롤). |

**Reviewer 단위 disable (Review gate):**

| Env var | 효과 |
|---|---|
| `DEVBREW_DISABLE_QG_CODEX=1` | optional `codex-reviewer` 완전 skip (model-family diversity layer off). `scripts/detect_codex.sh`가 우선 검사. |
| `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1` | Phase 1 always-run `security-reviewer` skip. 다른 3개 phase-1 reviewer는 여전히 fire. |

**Runtime gate 단위 disable:**

| Env var | 효과 |
|---|---|
| `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION=1` | Runtime gate Step 2.5 (test scope validation) 완전 skip. `DEVBREW_SKIP_HOOKS=quality-gates:runtime-test-scope`과 동일. |
| `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` | `/qg branch <name>` auto-worktree 기능 disable (`/qg branch` no-arg는 영향 없음). |
| `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1` | spec 발견 시에도 no-spec 경로 강제 (ac_coverage 생략, codex `<spec_context>` 비움; validator는 plan-기반 계속). |
| `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1` | Runtime gate의 git-worktree 샌드박스 executor를 끄고 read-only smoke fallback. verdict는 SKIP_WITH_EVIDENCE로 cap(절대 PASS 아님), real-tree 변경 시 loud 경고. `qg-worktree.sh create-sandbox`가 exit 3. |

**Publish 단위 disable (`/qg-publish`, 게이트 아님):**

| Env var | 효과 |
|---|---|
| `DEVBREW_QG_DISABLE_PUBLISH=1` | **두 최내부 sink에서 결정론 강제**(skill 진입 자체는 막지 않음): `comment-upsert.py`(코멘트 POST/PATCH)와 `pr-create.sh`(`git push` + `gh pr create`). 로컬 artifact 생성 + `--dry-run` preview는 그대로 동작하되 GitHub에 대한 실제 네트워크 쓰기만 fail-closed로 차단된다. 같은 env var가 `/qg` 완료 시의 command-layer publish offer도 skip시킨다(커맨드가 env를 직접 체크; defense-in-depth — 동일 의도를 두 레이어에서). |

**Hook 단위 disable** (`DEVBREW_SKIP_HOOKS=quality-gates:<key>,quality-gates:<key2>...`):

| Hook 키 | 위치 | 기능 |
|---|---|---|
| `quality-gates:session-tracker` | `hooks/post-tool-use-session-tracker.py` | PostToolUse(Edit/Write/MultiEdit) — 편집된 파일을 `files.md`에 기록 |
| `quality-gates:post-tool-use` | `hooks/post-tool-use.py` | PostToolUse(Bash) — `gh pr create` 직후 `/qg` 시작 안내 (publish sentinel 존재 시 억제) |
| `quality-gates:session-start-advisor` | `hooks/session-start-advisor.py` | SessionStart — stale state 안내 (read-only) |
| `quality-gates:session-start-advisor:frontmatter-scan` | 위 hook의 sub-feature | Plugin 전체 agent frontmatter drift 스캔만 disable |
| `quality-gates:session-end-cleanup` | `hooks/session-end-cleanup.py` | SessionEnd — 현재 세션 폴더 cleanup |
| `quality-gates:runtime-test-scope` | (위 `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION`과 동의어) | Runtime gate Step 2.5 |

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
