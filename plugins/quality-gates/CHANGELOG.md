# 변경 로그

`quality-gates` 플러그인의 주요 변경 사항을 기록합니다.
포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 버전 규칙은 [SemVer](https://semver.org/spec/v2.0.0.html)를 따릅니다.

## [2.2.0] — 2026-05-31

`runtime-verifier`를 read-only 관찰자에서 **git-worktree 샌드박스 기능-executor**로 전환.
서비스를 띄우고 real user flow를 구동하며 spec Acceptance Criteria 대비 동작을
**증거-접지** 방식으로 단언한다. Write를 허용하되, orchestrator가 immutable baseline
commit 대비 `git diff`로 product 변경을 ground-truth로 잡아 **PASS를 구조적으로 차단**하고
무커밋·샌드박스 폐기로 Law 2 self-approval을 물리적으로 봉쇄한다. 운영 DB/네트워크는
git-ignored 파일(prod `.env`) 미복사로 원천 미접근.

### Added
- **`scripts/qg-worktree.sh create-sandbox`**: working-tree를 byte-faithful 반영한
  일회용 detached worktree 생성(`cp -a`로 mode/symlink/binary 보존, git-ignored 미복사,
  deletion 반영) + immutable baseline commit `B` 봉인. 출력=경로+SHA 2줄.
- **`scripts/qg-worktree.sh mutation-guard`**: `(sandbox, B)`만 입력받는 순수-git product-
  mutation oracle. `tracked_diff` / `disallowed_new_files`(신규 non-ignored 파일 + 모든 신규
  symlink) / `forced_downgrade` emit. verifier 자기판단과 독립 → Law 2 구조적 가드.
- **`detect-runtime.sh` blast-radius 분류**: process-start kind(dev/start/serve, cargo-run,
  go-run, makefile run/serve) + 네트워크/배포/파괴 신호 매칭 surface에 `requires_decision: true`.
  test runner kind은 자동.
- **Upfront Execution Plan** (SKILL): `requires_decision` surface가 있을 때만 1회 발화해
  gate 범위·runtime 범위(`approved_surfaces`)·block 정책(`stop`/`skip`/`ask`)을 확정.
  그 외 zero-click.
- **신규 테스트**: `test_qg_runtime_sandbox.sh`, `test_qg_mutation_guard.sh`,
  `test_detect_runtime.sh` blast-radius 확장, fixtures `gate3/cli-tool`·`gate3/danger-signal`·`gate3/force-flag`.
- **kill switch `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`**: 샌드박스 끄고 read-only smoke
  fallback + loud log.

### Changed
- **`agents/runtime-verifier.md`**: `model: sonnet → inherit`; `allowedTools`에
  `Write`/`Edit`/`MultiEdit` + chrome-devtools 상호작용 도구(click/fill/fill_form/type_text/
  hover/press_key/evaluate_script) 추가; `disallowedTools`는 `NotebookEdit`만 유지.
  body를 sandbox-executor 정체성 + spec AC 기능 단언 + evidence-log
  `writes`/`functional_assertions` 섹션으로 재작성.
- **`SKILL.md`**: Runtime gate를 R0(sandbox)~R6(routing)로 재배선, mutation-guard 결과로
  verdict ≤FAIL 강제, spec AC thread, blocked-path 정책 라우팅, cost heads-up. v2.2.0.
- **`check-allowed-tools-order.sh`**: 정전 allowlist에 `qg-worktree.sh` 추가.

### Security
- **Law 2 메커니즘 이전 (도구 deny → git-diff 가드).** `runtime-verifier`의 self-approval
  방지가 `disallowedTools: [Write]`(behavioral tool deny)에서 **orchestrator의 immutable-
  baseline git-diff 가드**(구조적, verifier 주장과 독립)로 이동. 외부 표면(`/qg`)은
  하위호환(additive + gated)이라 minor bump. `test-scope-validator`/`security-reviewer`/
  `adversarial`은 read-only reviewer로 불변. persona 편집은 보안-민감 변경.
- **운영 안전.** 샌드박스가 git-ignored 파일(prod `.env`/자격증명/deps)을 복사하지 않아
  운영 DB/네트워크 접근 경로를 원천 차단. process-start/네트워크/파괴 surface는 upfront
  승인 게이트(blast-radius) 뒤로. OS-수준 egress 격리는 명시적 non-goal(한계 인정).
- **fallback Law 2 보존.** `DEVBREW_QG_DISABLE_RUNTIME_SANDBOX=1`로 샌드박스를 끈 경우에도 verifier는 frontmatter상 Write를 갖지만, orchestrator가 R3 dispatch 전후의 `git status --porcelain` 차이로 실제 working-tree mutation을 잡아 verdict를 ≤FAIL로 강제 + loud warn — 구조적 Law 2 보장이 fallback에서도 유지(behavioral-only로 격하되지 않음).

## [2.1.0] — 2026-05-31

qg가 처음으로 **사용자 프로젝트 spec을 단일 truth로 read**. cycle 위계(spec=truth ⊃
plan=구현 방식)를 instantiate — 그동안 qg는 plan만 읽고 spec은 한 번도 읽지 않아
`test-scope-validator`가 입력을 "spec/plan"으로 융합하고 있었음. spec-conformance는
코드가 *존재*해야만 가능하므로 review/verify 단계인 qg만 닫을 수 있는 비중복 루프
(plan-verify를 v2.0.0이 제거한 것과 비대칭). **advisory only — gate를 block하지 않음.**

### Added
- **`scripts/discover-spec.sh`** + **`tests/test_discover_spec.sh`**: 프로젝트 spec
  우선순위 탐색(`--spec` → `docs/superpowers/specs/*.md`). AC-섹션 적격성 + 최신 mtime
  tiebreak. legacy-global 소스 없음(spec은 프로젝트 artifact). `discover-plan.sh` 거울.
- **`test-scope-validator` `ac_coverage` advisory 블록**: spec 발견 시 AC별
  covered/uncovered + `covered_by` 테스트 ref. note "advisory only — does not block".
- **codex `<spec_context>` 슬롯**: v2.0.0에서 `/dev/null`로 죽어 있던 `<plan_context>`
  슬롯을 부활 — `run_codex_reviewer.sh`가 spec AC 섹션을 script-internal로 추출·주입.
- **kill switch `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`**: spec이 있어도 no-spec 경로
  강제(ac_coverage 생략, codex spec context 비움; validator는 plan-기반 계속).
- **README "Spec Discovery Sources"** 절 + "Principles Instantiated"에 **C66**.

### Changed
- **`test-scope-validator` 기준 축 전환**: 입력 융합(`spec/plan markdown`)을
  `spec_path`(AC truth, primary) + `plan_path`(구현-방식 보조 hint)로 분리.
  cherry-pick-suspicion 기준이 "plan scope" → "spec acceptance criteria scope에
  orthogonal"로 재정의. plan은 강등(제거 아님).
- **`build_codex_prompt.py`**: `<plan_context>`/`{{PLAN_SUMMARY}}`/`<plan_summary_file>`
  → `<spec_context>`/`{{SPEC_AC}}`/`<spec_ac_file>`.
- **`run_codex_reviewer.sh`**: `PLAN_SUMMARY_FILE`/`PLAN_SUMMARY` → `SPEC_AC_FILE`/`SPEC_AC`;
  spec discovery + AC 섹션 awk 추출 + spec 부재 시 loud log를 script-internal로 추가.
- **`SKILL.md`**: `spec_path` 인자 문서화 + test-scope-validator dispatch에 `spec_path:` 줄.
  `allowed-tools` frontmatter는 불변(invocation parity).

### Fixed
- **`agents/test-scope-validator.md:54` spec/plan 융합 해소**: 입력을 문자 그대로
  "path to the spec/plan markdown"으로 적어 spec(truth)과 plan(파생 hint)을 교환 가능한
  한 덩어리로 취급하던 버그 수정 — 위계 복원.

### Unchanged (의도적 보존)
- **`scripts/discover-plan.sh` + `tests/test_discover_plan.sh`**: byte-identical.
  plan *discovery*는 존속(보조 hint), plan *verify*만 v2.0.0이 제거.
- **철학 문서**: 새 P#/AP# 없음 — C66 + Law 1 instantiation(devbrew design-lightness).
- **reviewer agent `disallowedTools` 격리**: 불변(Law 2). spec 읽기는 read-only.
- **advisory invariant**: `ac_coverage`·spec-conformance는 Runtime gate를 block 안 함.

## [2.0.0] — 2026-05-30

**BREAKING.** Gate 1(plan verification) 제거 + wall-clock budget 제거 + 두 게이트
비수치 rename. plan 검증은 상류 `superpowers:writing-plans` / `spec-distill`가 담당하는
중복 단계였고, v1.32.0 single-turn 재설계 후 남은 wall-clock 잔재를 정리.

### Removed
- **`agents/plan-verifier.md`** + **`tests/test_plan_verifier_behavior.py`**: Gate 1
  plan-verifier agent 완전 제거. plan 검증은 writing-plans/spec-distill 소관.
- **`/qg gate1` 서브커맨드**: 제거 (alias 없음).
- **scout `gate1_verdict` 입력 필드** + reviewer dispatch의 `gate1_summary` 핸드오프: 제거.
- **codex per-call 600s wall-clock timeout** (`run_codex_reviewer.sh`의 `timeout 600`
  래퍼·`no_timeout_binary` 분기·`OVERRIDE_REASON=timeout`): 제거. hang 위험은 수용 —
  backstop은 Bash tool timeout + `DEVBREW_DISABLE_QG_CODEX=1` + `/cancel-qg`.
- **README wall-clock budget deferred 노트** + codex "Per-call wall-clock ceiling: 600s"
  표현: 제거.
- **철학 문서 AP16 `(b) wall-clock budget` guard**: 제거 (autonomous-loop guard 4→3개:
  max-iter / repeat 감지 / kill switch).
- **state-file-format `wall_clock_deadline_at`** 행: 제거.

### Changed
- **게이트 비수치 rename**: `Gate 2: PR Review` → **Review gate**, `Gate 3: Runtime
  Verification` → **Runtime gate**. "gate" 명사는 플러그인 이름·`/qg`와 정합 위해 유지.
- **서브커맨드**: `/qg gate2` → `/qg review`, `/qg gate3` → `/qg runtime`.
- **env var**: `DEVBREW_GATE3_MAX_RESOLUTIONS` → `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS`;
  `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` → `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION`.
- **hook 키**: `quality-gates:gate3-test-scope` → `quality-gates:runtime-test-scope`.
- **state 필드**: `gate3_max_resolutions` → `runtime_max_resolutions`.
- **내부 식별자**: `max_gate2_iterations` → `max_review_iterations`; `gate3-evidence.md`
  → `runtime-evidence.md`; `gate3_fail` → `runtime_fail`; `gate3_repeat_detected` →
  `runtime_repeat_detected`; synthesize heading `## Gate 2 Findings` → `## Review Findings`.
- **유지**: `scripts/discover-plan.sh` + "Plan Discovery Sources" 문서 (Runtime gate의
  test-scope-validator가 `plan_path:auto`로 소비 — plan *verify*만 제거, plan *discovery*는 존속).
  P22 Cost Awareness·`cost_class`·Cost Class % 표·`detect_codex.sh` 5s probe도 유지.

### Migration (1.32.3 → 2.0.0)

**Deprecated alias 없음** — clean break (P17 사용자 주권 우선, P23 deprecation-window
하우스 룰의 의도적 예외; major bump가 breaking을 신호). 구→신 매핑:

| old | new |
|---|---|
| `/qg gate1` | *(제거 — plan 검증은 writing-plans/spec-distill)* |
| `/qg gate2` | `/qg review` |
| `/qg gate3` | `/qg runtime` |
| `DEVBREW_GATE3_MAX_RESOLUTIONS` | `DEVBREW_QG_RUNTIME_MAX_RESOLUTIONS` |
| `DEVBREW_DISABLE_GATE3_TEST_VALIDATION` | `DEVBREW_QG_DISABLE_RUNTIME_TEST_VALIDATION` |
| `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` | `...=quality-gates:runtime-test-scope` |

구 `gate1`/`gate2`/`gate3` 서브커맨드와 `DEVBREW_GATE3_*` env는 **즉시 무효** — 스크립트·CI에서
참조 중이면 위 표대로 갱신 필요.

## [1.32.3] — 2026-05-28

PR #71 (v1.32.0 → v1.32.2) merge 후 deferred된 6건의 follow-up.
모든 변경은 비기능적 polish/defense-in-depth (breaking change 없음).
3-round spec review 통과 (8 + 4 + 0 issues 모두 흡수).

### Added
- **`scripts/read-frontmatter.py`**: frontmatter `key: "value"` 파싱
  helper. escape-aware regex로 embedded `\"` / `\\` 처리. 3 call site
  (`pre-pipeline-check.sh` × 2, `cancel-qg-core.sh` × 1)의 `awk -F'"'`
  패턴 대체 (MED-3).
- **`scripts/check-allowed-tools-order.sh`**: SKILL.md `allowed-tools`
  pipeline-order 검증 linter. Canonical source = 내부 `EXPECTED_ORDER`
  배열 (single source of truth). 16 tools 5 groups (I-D).
- **`scripts/check-changelog-korean-primary.py`**: CHANGELOG `[1.32.0]`
  Korean-primary 컨벤션 단락 단위 검증 (I-C). 영구 보존 (향후 항목
  추가 시 재검증 가능).
- **`tests/test_read_frontmatter.sh`**: 5 케이스 — quoted / unquoted /
  missing / embedded-quote (val"ue) / embedded-backslash (a\b).
- **`tests/test_cancel_qg_med4.sh`**: MED-4 검증. mv backup + cp stub +
  `trap '...' EXIT` 패턴으로 fixture stub 통한 실패 경로 검증 (3 assertion:
  stub 메시지 prefix / exit code 1 라인 / sed invocation 0건).
- **`tests/test_check_allowed_tools_order.sh`**: linter 4 시나리오 —
  canonical PASS / within-group swap FAIL / cross-group move FAIL /
  unknown tool FAIL.
- **`tests/fixtures/qg-worktree-fail-stub.sh`**: MED-4 영구 fixture.
  qg-worktree.sh 실패 simulator (exit 1 + stderr 메시지).

### Changed
- **`cancel-qg-core.sh`**:
  - MED-1: qg-worktree.sh 부재/비실행 메시지 self-actionable화. MISSING
    vs EXISTS-but-not-executable 구별, 사용자 직접 실행 명령
    (`git worktree remove --force "<path>"`) 명시.
  - MED-4: pipe-to-stream-editor 제거. `cmd | sed` 대신 stdout/stderr
    병합 capture + 수동 prefix. `if/else` 형태로 `set -e` 안전하게 exit
    code 캡처. qg-worktree.sh 출력 계약(병합 스트림 prefix-emit) 보존.
  - MED-3 transition: `awk -F'"'` 호출부를 `read-frontmatter.py` 호출로
    교체. `SCRIPT_DIR` 변수를 file top으로 끌어올려 lowercase `script_dir`
    정의와 통일.
- **`pre-pipeline-check.sh`**: MED-3 transition 2 site
  (`branch` / `session_id` 파싱). `tr -d '[:space:]'` 제거 (helper가
  `.strip()` 내부 처리). `SCRIPT_DIR` 변수 file top에 추가.
- **`skills/quality-pipeline/SKILL.md`**: `allowed-tools` frontmatter
  pipeline-order 재정렬 (I-D). 5 group 경계를 YAML comment로 inline 문서화.
- **`CHANGELOG.md` `[1.32.0]` body**: English prose → Korean-primary 변환
  (I-C). Technical 사실 변경 없음.

### Fixed
- **`tests/test_pre_pipeline_check.sh`**: MED-2 SID guard 4 boundary
  케이스 추가 — empty / too-short (7 char) / invalid-char (`abc/def123`) /
  valid (15 char + sandbox `git init` + fresh state로 isolation).

### Acceptance Criteria
- AC1 (MED-1): cancel-qg-core.sh stderr 메시지 검증
- AC2 (MED-2): 4 SID boundary 케이스 PASS
- AC3 (MED-3 transition): `awk -F'"'` 0 hits, `SCRIPT_DIR` 정의 확인
- AC4 (MED-3 unit): 5 helper 케이스 PASS
- AC5 (MED-4): sed 0건, exit code 라인 검증
- AC6 (I-C): `check-changelog-korean-primary.py` PASS
- AC7 (I-D ordering): linter exit 0
- AC8 (I-D linter unit): 4 scenarios PASS
- AC9 (regression): 기존 testsuite + 신규 7 test 전체 PASS
- AC10: `plugin.json.version` == `"1.32.3"`
- AC11: 이 CHANGELOG entry 존재

## [1.32.2] — 2026-05-28

### Fixed (Gate 2 iter-2 review-driven follow-up, same PR #71)

- **CRIT-1-iter2**: `pre-pipeline-check.sh` `no_session_id` 와
  `invalid_session_id` 분기에서 `exit 1`로 변경 (이전 `exit 0`).
  setup-qg.sh와 대칭 의미론. SKILL.md preflight P3에 result-code
  enumeration 추가 — 모든 알려진 코드별 downstream action 명시 +
  unknown code는 contract violation으로 abort. silent fall-through
  방지.
- **CRIT-2-iter2**: `cancel-qg-core.sh`에서 `DEVBREW_QG_KEEP_WORKTREE=1`
  시 worktree AND state folder를 unit으로 보존. 이전: state folder만
  무조건 삭제되어 worktree path 가 영구 leak. 이제: 둘 다 보존하고
  loud advisory 출력하여 사용자가 미래 `/cancel-qg`로 회수 가능.
  qg-worktree.sh missing case도 loud diagnostic.
- **I-A-iter2**: plugin.json 1.32.1 → 1.32.2 bump.
  `feedback_plugin_version_bump.md` 메모리 + CLAUDE.md "every PR
  touching plugins/<name>/ must bump that plugin's version field in
  the same commit" 준수. iter-1 commit 이후 cache key 무효화 보장.
- **I-B-iter2**: `commands/cancel-qg.md`의 "v1.32.0 minimal schema"
  표기를 "v1.32.1 minimal schema"로 정정. `gate3_max_resolutions:`는
  v1.32.1에서 추가된 필드 (C3 복구).
- **HIGH-1-iter2**: `LEGACY_V1_KEYS` invariant 주석을 실제 enforcement
  형태와 일치시키고 새로운 V8d source-text 테스트 추가. 이전 주석은
  "AC17 unsplit literal forms do NOT appear" 라는 존재하지 않는 test를
  주장. 이제: behavioral (V8c) + source-text (V8d) 이중 enforcement.
  V8d는 split form 양쪽 존재 + unsplit literal 절대 부재를 grep으로
  검증 — ruff/black auto-fix merging 방어.

## [1.32.1] — 2026-05-28

### Fixed (Gate 2 iter-1 review-driven follow-up, same PR #71)

- **C1-iter1**: `SKILL.md` frontmatter `allowed-tools`에 `AskUserQuestion`
  + `detect-runtime.sh` + `compute-test-scope-candidates.sh` + `detect_codex.sh`
  추가. v1.32.0 단일-턴 설계가 의존하는 도구들이 누락되어 있었음.
- **I-iter1-2**: `commands/cancel-qg.md` v1.32.0 minimal schema에 정렬.
  제거된 v1.5.x 필드(`status`/`current_gate`/`gate2_iteration`) 참조 제거.
- **I-iter1-3**: `scripts/cancel-qg-core.sh` worktree-aware cleanup —
  `pipeline.md`에 `worktree_path:`가 있으면 `qg-worktree.sh remove`
  먼저 호출 (DEVBREW_QG_KEEP_WORKTREE=1 가드). session-end-cleanup.py와
  대칭 의미론.
- **I-iter1-4**: `LEGACY_V1_KEYS` invariant 주석 정확도 개선. `status:`는
  split 안 하는 이유(자기-참조 substring 부재 + 일반성) 명시.
- **I-iter1-5**: `scripts/pre-pipeline-check.sh` SESSION_ID pattern guard
  추가 (`^[A-Za-z0-9_-]{8,}$`). `setup-qg.sh`/`cancel-qg-core.sh`와 일관.
- **I-iter1-6**: SKILL.md Retry error handling option labels 재조정 —
  "Abort retry" / "Skip this file" (이전: "Skip retry / abort" / "Continue
  with next file" — 의미 역전).
- **I-iter1-7**: `references/state-file-format.md` v1.32.1 schema에 정렬.
  `gate2_iteration: 0` 제거 → Removed Fields에 이동. `gate3_max_resolutions:`
  활성 필드로 추가.
- **I-iter1-8**: `agents/runtime-verifier.md`의 `project_dir` input에
  "절대 재계산 금지" 강제 문구 + Forbidden 섹션 항목 추가. 나머지 3개
  reviewer agent와 동일 contract.
- **I-iter1-9**: CHANGELOG C1 entry English-prose → Korean-primary로 재작성.
- **I-iter1-10**: state file watermark `(v1.32.0)` → `(v1.32.1)`
  (setup-qg.sh + state-file-format.md).

### Fixed (Gate 2 review-driven, PR #71)

- **C1**: `SKILL.md` — `project_dir:` threading을 4개 reviewer dispatch
  (`adversarial`, `test-scope-validator`, `security-reviewer`,
  `runtime-verifier`) 전체에 복구. 신규 preflight P0 step에서
  `project_dir=$(pwd)`로 도출 후 매 dispatch에 전달. 워크트리 모드에서
  agent가 `pwd`/`git rev-parse`로 재도출 시 발생하는 coordinate drift 차단.
- **C2**: `pre-pipeline-check.sh` 세션 ID 가드 추가. 같은 세션이
  소유한 `pipeline.md`는 절대 삭제 안 함 (setup-qg P2 → pre-pipeline-check
  P3 race 차단). stderr 권고: `pre-pipeline-check: preserving
  session-owned state file`.
- **C3**: `DEVBREW_GATE3_MAX_RESOLUTIONS` 검증 블록 `setup-qg.sh`에
  복구. 정수 파싱 + clamp 0..10 + default 3. state 파일에
  `gate3_max_resolutions:` 필드로 기록. P18 unbounded-autonomy
  guard 회귀 해소.
- **C4**: `tests/test_setup_qg.sh` v1.32.1 schema 기준으로 재작성.
  제거된 9개 stale assertion (removed schema keys, removed stderr
  warnings) 정리. 새 assertion: --ensure 멱등성, clamp 값, per-session
  folder isolation, schema invariants.
- **C5**: v1 `tests/test_session_start_advisor.py` 삭제. v2 shell
  wrapper (V8a/V8b/V8c)가 대체.
- **C6**: 새로운 `tests/harness/test_skill_orchestration_behavior.sh` —
  SKILL.md orchestration의 protocol-shape 검증 (순서/근접성/섹션
  멤버십). 12개 assertion. V7 tautological substring grep은 같은
  commit에서 삭제 (`grep -c 'PASS'`가 항상 0을 반환해 negative-assertion
  path가 unreachable이었음).
- **I1**: `test_kill_switches.py` advisor sanity 검사를 stderr로 전환
  (v1.32.0 advisor는 stdout이 아닌 stderr에 출력).
- **I2**: `test_worktree.sh` T5 4개 reviewer 모두에 대해 uniform
  `quality-gates:<name>` subagent_type anchor 사용. T9 (state
  frontmatter `project_dir:`) 제거 — v1.32.0 schema에서 의도적으로
  제거된 필드.
- **I3**: `setup-qg.sh` 헤더 주석에서 "Stop hook-based" 표현 제거,
  "in-turn pipeline orchestration (AskUserQuestion-iteration model;
  no Stop hook continuation)"로 교체.
- **I4/I5**: `session-start-advisor.py` silent-failure (OSError /
  JSONDecodeError) diagnostic stderr로 전환. 빈 fallback은 유지
  (advisor가 SessionStart를 crash시키면 안 됨).
- **I6**: SKILL.md Retry path error handling — `Edit` 실패 시
  AskUserQuestion으로 사용자에게 surface ("Retry failed at <file>:
  <reason>. Skip retry / abort? / Continue with next file."). silent
  skip 금지.
- **I7**: `check-trivia.sh` exit code 2 분기 SKILL.md에서 제거
  (script가 절대 2로 종료하지 않음 — unreachable). 0/1 이외의
  non-zero는 script crash로 propagate되어 파이프라인 abort.
- **I8**: README v1.5.0 Stop-hook ASCII 다이어그램 제거. v1.32.0
  AskUserQuestion 다이어그램만 남음. 주변 prose의 "Stop hook" 참조
  제거.
- **I9**: `tests/e2e-scenarios.md` v1.5.0 잔재 (stop-hook.py,
  `<qg-signal>`, gate2_repeat_detected) 4곳 정리.
- **I10**: SKILL.md Retry path file-write safety — reviewer 공급
  `file:` 필드를 `os.path.realpath` + `os.path.commonpath`로 양쪽
  canonicalize. `project_dir` 외부로 escape하는 경로는 `SecurityError`
  raise. AskUserQuestion description에 full canonicalized path
  list 노출. symlink-traversal 회피.
- **I11**: `setup-qg.sh` state 템플릿에서 `gate2_iteration: 0`
  phantom 필드 제거. 실제 iteration counter는 History 섹션에 기록됨
  (spec/plan은 SKILL.md frontmatter에 있다고 잘못 명시했지만, 실제
  위치는 state 템플릿).
- **I12**: `tests/test_readme_state_diagram_complete.sh` v1.32.1 README
  기준으로 전면 재작성. v1.5.0 Mermaid stateDiagram-v2 13-transition
  assertion 삭제, v1.32.0 ASCII pipeline 다이어그램의 10개
  protocol-shape marker 검증으로 전환.

### Fixed (Medium tier)

- LEGACY_V1_KEYS 두 번째 split 완성 (`consecutive_no_signal:` →
  string-concat 형식). v1.32.0이 `current_gate:`만 split한 half-applied
  fix 완성. Invariant 주석 추가 (AC17 acceptance criterion 명시).
- `cancel-qg-core.sh` 추출 (TQ-2): commands/cancel-qg.md와
  tests/test_cancel_qg.sh가 동일 helper 호출. SID pattern guard
  (`[A-Za-z0-9_-]{8,}`) 헬퍼 내장. command-test drift 차단.
- 새 `tests/test_pre_pipeline_check.sh` (C2 회귀 방지). 4 cases:
  fresh_start / same_session_preserved / cross_session_deleted /
  advisory_emitted.
- `test_kill_switches.py`에 `test_skill_setup_qg_honors_disable_kill_switch`
  케이스 추가. `setup-qg.sh`가 SKILL preflight P1 외에 자체적으로도
  `DEVBREW_DISABLE_QUALITY_GATES=1`을 honor (defense in depth).
- `test_skill_orchestration.sh` V2b anchor uniqueness 강화: `findings
  remain`이 `question:` 라인 정확히 1회만 등장해야 함 (다른 AskUserQuestion
  섹션으로의 복사-붙여넣기 차단).
- `test_session_start_advisor_v2.sh` V8 → V8a/V8b/V8c 분리.
  V8a (per-session fixture only), V8b (flat-legacy fixture only),
  V8c (LEGACY_V1_KEYS 3-token fixture-based regression).
- `test_branch_worktree.sh` comment drift 4곳 정리 (stop-hook 참조 →
  AskUserQuestion-cleanup 표현; 삭제된 test_stop_hook_worktree_cleanup.py
  참조 acknowledge).

### Security

- I10: reviewer 공급 path가 `project_dir` 외부로 escape하는 것을 차단
  (`realpath` + `commonpath` 양쪽 normalisation). symlink-traversal
  회피. AskUserQuestion description에 full canonicalized file list
  노출하여 사용자가 매 write surface 가시화.

## [1.32.0] — 2026-05-27

### Breaking
- **Stop hook 제거.** `hooks/stop-hook.py` (1205 LOC, 13-transition state
  machine, wall-clock guard, no-signal counter)가 `hooks.json`의 `Stop`
  event 등록과 함께 삭제됨. Pipeline progression은 이제 `quality-pipeline`
  SKILL 안에서 in-turn serial dispatch로 전적으로 처리됨.
- **`<qg-signal>` emission contract 제거.** SKILL이 더 이상 signal tag를
  emit하지 않음. `# QG-STOP-HOOK-CONTINUATION` sentinel은 어떤 코드 경로에서도
  인식되지 않음.
- **State file shape 변경.** v1.32.0 state file은 minimal: `session_id`,
  `started_at`, `worktree_path` (optional), `gate2_iteration`. 제거된 필드:
  `status`, `current_gate`, `consecutive_no_signal`,
  `max_gate2_iterations`, `gate3_resolution_iter`, `last_gate3_needed_hash`,
  `max_gate3_resolutions`, `skip_runtime`, `single_gate`, `plan_file`,
  `pr_url`, `available_plugins`, `wall_clock_deadline_at`, `project_dir`.
- **Env vars 제거.** `DEVBREW_QG_DEADLINE_MIN`과
  `DEVBREW_QG_NO_SIGNAL_MAX`가 더 이상 존재하지 않음 (wall-clock guard와
  no-signal counter는 stop-hook과 함께 사라짐). 다른 env vars는 미변경.

### Added
- **AskUserQuestion progression primitive.** SKILL이 Gate 1 FAIL, Gate 2
  iter boundary (매 iteration), Gate 2 max-iter (silent halt 대체), Gate 3
  NEEDS_RESOLUTION에서 AskUserQuestion 호출. Same-turn tool 결과가 다음
  dispatch를 구동.
- **Static SKILL orchestration test:** `tests/test_skill_orchestration.sh`
  (V2a gate-order + V2b context-anchor + V7 PASS-proximity heuristic).
- **`/cancel-qg`, `/qg --reset`, `/qg --gc` fixture test:**
  `tests/test_cancel_qg.sh`.
- **Session-start advisor v2 test:** `tests/test_session_start_advisor_v2.sh`
  (V8 legacy advisory + V8-pre code-structure guard).

### Changed
- **SKILL.md** single-gate-per-turn에서 AskUserQuestion gating의
  single-turn-serial dispatch로 재작성.
- **setup-qg.sh**가 minimal state schema를 emit; wall-clock과 gate3-max
  계산 제거.
- **session-start-advisor.py**는 in-flight pipeline detection을 drop;
  legacy v1.x state file을 감지해 one-shot `/cancel-qg` stderr advisory
  emit. Frontmatter scan sub-feature는 미변경.
- **commands/qg.md** Pipeline Rules 섹션 재작성; "Stop hook handles
  progression" 주장 제거.
- **README.md** Hook 테이블이 더 이상 stop-hook.py를 나열하지 않음;
  state diagram은 ASCII single-turn sequence로 교체; Principles 섹션에
  P22 일반화 노트 추가.

### Removed
- `hooks/stop-hook.py`
- `hooks/hooks.json`의 `Stop` event block
- SKILL / scripts / hooks 의 모든 `<qg-signal>` 참조
- stop-hook semantics에 coupled된 obsolete test
  (`test_forward_only_prose.sh` + Task 7에서 감지된 stop-hook-coupled test)

### Migration
v1.x in-flight pipeline은 v1.32.0에서 resume 불가. 업그레이드 후
`/cancel-qg` (per-session) 또는 `/qg --reset` (legacy flat files)을
실행해 옛 state를 clear. SessionStart advisor가 다음 session 시작 시
guide를 emit함.

## [1.31.0] — 2026-05-20

### Changed
- `agents/adversarial.md` — persona 강화. sonnet 시절의 미니멀 "calibration only" 프롬프트를 opus-critic에 맞는 다단계 검증으로 확장: per-finding **3-gate** (real in code? / introduced by THIS diff? / handled elsewhere?), CRITICAL/IMPORTANT용 **severity realist check** (이론적 최악 아닌 현실적 최악 + mitigation, 단 data-loss/security/auth-bypass/financial은 절대 다운그레이드 금지), **cross-reviewer corroboration** 신호, **evidence bar** (증거 없는 CRITICAL/IMPORTANT은 opinion → reject/downgrade), manufactured-outrage 금지. 강화만 — 임계치 완화·규칙 제거 없음 (persona는 보안-민감 코드). 역할(verdict-only, no new findings)·cwd 금지 규칙 보존.
- `agents/adversarial.md` — 출력 스키마를 top-level `verdicts:` wrapper로 정렬 (synthesizer는 이미 wrapper와 bare list 둘 다 수용 — `synthesize_findings.py:32`; behavioral 테스트 fixture와도 일치). `finding_id: <agent>-<file>-<line>` 매칭 키 보존.

### Fixed
- adversarial reviewer model 선언 drift 정합. `agents/adversarial.md` frontmatter와 README 모델 노트는 `sonnet`이라 적혀 있었으나 `SKILL.md` Phase 1.5 dispatch가 `model="opus"`로 frontmatter를 덮어, 실제로는 **opus로 실행**되고 있었음 (세 사이트 불일치). adversarial은 Sonnet Phase 1 워커 위의 **Opus-critic** — Gate 2의 유일한 모델-기반 판단 게이트 — 이므로 의도된 모델은 opus. 세 사이트를 모두 opus로 정합: frontmatter `model: opus`, SKILL은 dispatch override를 제거하고 frontmatter에 위임(다른 qg-owned agent 관례와 일치), README 모델 노트를 opus 근거로 재작성. effective 모델은 변화 없음(원래도 opus 실행); 선언 정합 + persona 강화가 본 릴리스의 변경.

### Added
- `tests/test_adversarial_model_consistency.sh` — drift 가드. 세 선언 사이트(frontmatter / SKILL dispatch / README 모델 노트 + phase 다이어그램)가 opus로 일관됨을 검증. 미래 단일 사이트 편집(예: cost-cut으로 한 곳만 sonnet 변경)이 CI에서 즉시 fail. CLAUDE.md Law 3 — "리뷰를 탈출한 drift는 코드만 패치하지 말고 재발을 잡는 가드를 신설".

## [1.30.1] — 2026-05-20

### Changed
- `agents/security-reviewer.md` — `color: red` → `color: purple`. Cosmetic only; 채도 높은 red가 눈에 쨍해 차분한 purple로 교체. 격리(`disallowedTools`)·로직 영향 없음.

## [1.30.0] — 2026-05-19

### Added
- 5 behavioral test files for surviving leaf agents (plan-verifier, security-reviewer, adversarial, test-scope-validator, runtime-verifier). Each test uses `tests/harness/agent_stub.py` to short-circuit dispatch with frozen YAML fixtures — deterministic, hermetic, no LLM call. 3 tests per agent (AC45 schema/enum, AC46 missing-key-raises, AC47 invalid-yaml-raises) = 15 total. Completes CLAUDE.md Law 3 (Compounding) for the qg agent surface: any future drift in output contract fails CI immediately (T3-4, AC45-AC48).

### Reached
- v1.30.0 — spec upper bound. All 56 acceptance criteria from `docs/superpowers/specs/2026-05-17-qg-tier2-3-improvements-design.md` implemented. Tier 2 + Tier 3 cycle complete.

## [1.29.0] — 2026-05-19

### Removed
- `agents/scout.md` — replaced by `scripts/scout.py`. Depth-decision table was already deterministic in v1.x; LLM was only applying the rules. Saves ~5-15K input + 500 output tokens per Gate 2 iteration. Eliminates scout-fallback path (script can't JSON-parse-fail) — `fallback: false` always (T3-1, AC29-AC33).

### Added
- `scripts/scout.py` — ~70-line rule-based depth + agent selection. Stdin JSON → stdout YAML with `depth`, `phase1_agents`, `phase2_agents`, `rationale`, `fallback`.
- `tests/test_scout_script.sh` — 5 fixture tests covering AC29-AC33 (small whitespace / medium new-files / large config / large+type / large+test).

### Changed
- SKILL.md Phase 0 prose: scout invocation now `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/scout.py` (was: `Agent(subagent_type="quality-gates:scout", ...)`). Frontmatter `allowed-tools` extended.
- `tests/test_scout_codex_integration.sh`: anchor patterns updated to reference scout.py.
- `tests/test_worktree.sh` T5/T8 loops drop `scout` (no longer applies).

## [1.28.0] — 2026-05-19

### Removed
- `agents/synthesizer.md` — replaced by `scripts/synthesize_findings.py`. Algorithm is fully deterministic (5 steps: apply verdict / dedup / suppress<7 except CRITICAL / sort / render Markdown). No LLM judgment was being used; dispatch cost (~3K tokens × every Gate 2 iteration) eliminated (T3-2, AC34-AC39).

### Added
- `scripts/synthesize_findings.py` — ~120-line deterministic post-processor. Accepts `--adversarial <yaml> --findings <yaml>`, emits Markdown to stdout matching the v1.x synthesizer schema.
- `tests/test_synthesize_findings.sh` — 6 fixture-based tests covering AC34-AC39.

### Changed
- SKILL.md Phase 1.6 prose: synthesizer is now invoked via `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py ...` (was: `Agent(subagent_type="quality-gates:synthesizer", ...)`). Frontmatter `allowed-tools` extended with the new script entry.
- `tests/test_worktree.sh` T8 loop drops `synthesizer` (no longer applies). T5 loop also drops `synthesizer` (no longer an Agent() dispatch).

## [1.27.0] — 2026-05-19

### Removed
- `agents/codex-reviewer.md` — replaced by `scripts/run_codex_reviewer.sh`. Layer 1 isolation now provided by SKILL.md narrow Bash allowlist instead of agent frontmatter `disallowedTools`. Layer 3 sandbox (`codex exec -s read-only`) preserved inside the script (T3-3, AC40-AC44).

### Added
- `scripts/run_codex_reviewer.sh` — independent codex review subprocess (88 lines). Takes `<diff_path> <project_dir> <output_yaml_path>`; emits canonical Phase 1 finding YAML.
- `tests/test_skill_bash_allowlist_narrow.sh` — AC44 regression: SKILL.md `allowed-tools` frontmatter must enumerate specific script paths, never `Bash(*)` wildcard.

### Changed
- `tests/test_codex_reviewer_frontmatter.sh` — rewritten: was a frontmatter grep on the deleted agent; now asserts agent absence + script existence + Layer 3 sandbox preservation.
- `tests/test_codex_dispatch_invariant.sh` — anchor patterns updated to reference the new script invocation prose instead of agent dispatch.
- `tests/test_worktree.sh` T8 — codex-reviewer removed from agent-file project_dir loop (no longer applicable post-T3-3).
- SKILL.md Phase 1 dispatch prose: codex-reviewer invocation is now a Bash script call, not an Agent() dispatch. Frontmatter gains narrow `allowed-tools` entry for the new script.

## [1.26.0] — 2026-05-19

### Fixed
- `tests/harness/agent_stub.py` `run_agent_stub`: guard against `yaml.safe_load` returning `None` for empty/whitespace/`null`/`~` input. Previously the None propagated silently to callers; now raises `AssertionError` naming the agent and fixture. Caught by qg self-review Gate 2 silent-failure-hunter (confirmed by adversarial).
- `tests/harness/agent_stub.py` `assert_yaml_schema`: changed `if enum:` to `if enum is not None:` so an empty `enum={}` dict is treated as "validate against zero constraints" (no-op loop) rather than "skip validation entirely" (silent green). Empty-dict was a real risk for programmatic enum builders that produce zero entries.

### Added
- `tests/test_agent_stub_harness.py`: 2 regression tests covering both fixes (`test_run_agent_stub_raises_on_empty_yaml` over 5 empty-form variants, `test_assert_yaml_schema_empty_enum_dict_is_not_skipped` over no-violation + missing-key compositions). 9/9 tests PASS.

## [1.25.0] — 2026-05-19

### Added
- color: <enum> frontmatter on 5 agents that previously lacked it: adversarial=orange, codex-reviewer=pink, scout=purple, security-reviewer=red, synthesizer=blue. Total 8 agents now color-coded from Claude Code 8-color palette (cyan/green/yellow/blue/red/purple/orange/pink). UX: parallel dispatch threads are visually distinguishable when 5+ reviewers fire concurrently in Gate 2 deep mode (T2-9).
- tests/test_agent_color.sh — dynamic AC53/AC55 verification: every extant agent file has color from the 8-color enum. Survives T3-1/2/3 refactor (which deletes scout/synthesizer/codex-reviewer.md).

## [1.24.0] — 2026-05-19

### Changed
- agents/adversarial.md: model downgrade opus → sonnet. Adversarial task is calibration (confirm/downgrade/reject verdict mapping per finding) — not new generation. Sonnet sufficient at ~5x lower cost per dispatch; savings compound across 3-5 iter Gate 2 fix-loop (T2-8).
- README Cost Class section adds Adversarial reviewer model subsection documenting downgrade rationale + infrastructure-dispatch exclusion policy (scout/adversarial/synthesizer not counted in AskUserQuestion fan-out prompt).

## [1.23.0] — 2026-05-19

### Added
- README §파이프라인 흐름: Mermaid `stateDiagram-v2` block enumerating all 13 stop-hook transition types (`next_gate`, `retry_gate`, `complete`, `abort`, `continue`, `gate2_user_choice`, `max_gate2_exceeded`, `gate3_fail`, `gate3_needs_resolution`, `gate3_repeat_detected`, `wall_clock_exceeded`, `no_signal_inc`, `no_signal_max`). New contributors can see forward-only invariants at a glance — NEEDS_RESTART → user gate (not auto-retry), terminal cleanup paths, both stuck-state guards (T2-7).
- `tests/test_readme_state_diagram_complete.sh` — grep-based drift detection: diagram set must equal authoritative 13-row set (no missing, no superset).

## [1.22.0] — 2026-05-19

### Fixed
- `stop-hook.py` step 8 `except Exception` block: PIPELINE_ERROR routing broadened from `{gate3_needs_resolution, gate3_repeat_detected}` to ALL non-terminal transitions. Forward-progress writes (`next_gate`, `retry_gate`, `continue`, `gate2_user_choice`, `max_gate2_exceeded`, `gate3_fail`) now also abort on persist failure rather than falling through with stale in-memory state. Terminal (complete/abort) intentionally fall through to step 9 cleanup which is independently resilient (T2-6).
- New `TestStateWriteFailureBroadening` contract tests covering AC22 (8 forward-progress transition types emit error) and AC23 (2 terminal transitions are silent).

## [1.21.0] — 2026-05-19

### Added
- SKILL.md `Codex skip 안내` visibility-policy section — for `codex_available: false` responses, 4 of 6 `skip_reason` enum values now emit a one-line stderr message explaining the cause (`not_installed`, `auth_missing`, `timeout_binary_missing`, `known_bad_version`). The other 2 (`kill_switch`, `inside_codex_sandbox`) remain silent by policy (user-intended disable / recursion guard). Fulfills CLAUDE.md "loud logging + graceful degradation" promise — users paying for Codex now know why dispatch was skipped (T2-5).
- `tests/test_skill_codex_skip_prose.sh` — grep-based AC19/AC20/AC21 verification.

## [1.20.0] — 2026-05-19

### Changed
- SKILL.md Phase 1 dispatch: unified `#### Phase 1 (unified dispatch)` section replaces dual headings (primary `#### Phase 1: Critical Analysis` + `#### Phase 1 (legacy/fallback)`). Two parallel gate-path sections collapse into one 4-step linear flow — single dispatch builder = single source of truth for future persona edits (T2-2 / T3-5). Raw line count change is small (+76/-47); the structural gain is removing the dual-path dispatch logic split.
- AskUserQuestion fan-out gate now applies to BOTH primary and fallback paths (was: fallback skipped the gate — degraded paths got less friction, not more, contradicting graceful-degradation principle).

### Fixed
- Fallback dispatch path no longer silently skips the user-cost-consent prompt at fan-out ≥4.

## [1.19.0] — 2026-05-19

### Added
- `check-trivia.sh` new detector kinds: `comment` (comment-only diffs ≤3 lines), `typo` (single-token substitution with length-diff ≤2), `untracked-newfile` (single new file ≤3 lines, all blank/comment/shebang). Fulfills CLAUDE.md P12 anti-corollary 4-axis coverage promise (T2-1).
- New `tests/test_check_trivia.sh` with 6 fixture-based AC tests (AC1..AC6).
- README §Trivia detector coverage subsection documenting all 5 kinds.

### Fixed
- Untracked single-file additions no longer fall through to full pipeline when they qualify as trivia (regression: previous `gd --name-only` did not see untracked files).
- `test_check_trivia.sh` `run_case`: added `trap RETURN` for tmpdir cleanup so a failing setup-fn under `set -euo pipefail` does not leak tmpdirs.

### Changed
- SKILL.md propagates `--paths` argument to `check-trivia.sh` so user-supplied scope is honored.
- `check-trivia.sh`: renamed diff-context `line_count` variable to `diff_line_count` so it does not shadow the untracked-newfile detector's physical-line-count variable. Behavior unchanged.
- `test_check_trivia.sh`: added comment documenting `$TRIVIA_ARGS` unquoted-by-design (word-split intended for multi-token args).

## [1.18.0] — 2026-05-19

### Added
- `DEVBREW_QG_NO_SIGNAL_MAX` (default 3, `0`=disabled) — stop-hook counter that prevents infinite re-injection when the model fails to emit `<qg-signal>` for N consecutive turns. New transition types `no_signal_inc` (silent increment) and `no_signal_max` (user-choice intercept) (T2-4).
- `compute_no_signal_transition(state, max_no_signal)` pure helper and `reset_no_signal(state)` helper for testability.

### Fixed
- `_persist_no_signal_counter`: wrap initial `open()` in `(IOError, OSError)` handler to match `update_state_file`'s established pattern.
- `compute_no_signal_transition`: ceiling-value semantics — `no_signal_max` branch now returns `new_count = cur` (not `cur+1`) so persisted and user-facing counter values agree.
- `main()` no-signal branch: mirror `new_count` into in-memory `state["consecutive_no_signal"]` before `build_special_prompt` so fmt rendering uses the post-increment count.

### Changed
- `setup-qg.sh`: state frontmatter adds `consecutive_no_signal: 0` initial field.
- `parse_state_file`: defaults `consecutive_no_signal` to 0 for backward-compat with v1.16.x state files.
- `USER_CHOICE_TYPES` set extended with `"no_signal_max"`; `build_system_message` user-choice branch updated.

## [1.17.0] — 2026-05-19

### Added
- `DEVBREW_QG_DEADLINE_MIN` (default 30 min, `0`=disabled) — pipeline wall-clock budget. main() 흐름에서 `deadline_exceeded(state, now=None)` pure helper로 검사 후 `wall_clock_exceeded` user-choice transition emit. CLAUDE.md `P18 anti-corollary` 4-가드 중 누락되었던 wall-clock 추가 (T2-3).

### Fixed
- Wall-clock budget no longer overrides terminal/self-acknowledging transitions: added `BUDGET_SKIPPABLE = frozenset({"abort", "complete", "wall_clock_exceeded"})` module constant; step 7.5 in `main()` consults it before re-injecting `wall_clock_exceeded`. Previous behavior caused unescapable loop once the deadline was past (T2-3 round 1 fix in `14dab3a`).
- `wall_clock_exceeded` prompt's "Accept partial" option now instructs the model to emit `<qg-signal action="complete" />` (was `gate="N" verdict="PASS_WITH_WARNINGS"`). The previous wording routed Accept-partial → `next_gate` on Gates 1/2, which step 7.5 re-overrode — second loop. Now Accept-partial finalizes the pipeline via `complete`, matching user intent ("stop spending more time; finalize as-is") (T2-3 round 2 fix in `e570780`).
- `setup-qg.sh` GNU `date -d` fallback now suppresses stderr and degrades gracefully to no-deadline mode if neither BSD nor GNU `date` variant works (loud-logging via stderr warning, no abort under `set -euo pipefail`).

### Changed
- `setup-qg.sh`: state frontmatter에 `wall_clock_deadline_at: "<ISO8601>"` 신설.
- `stop-hook.py`: `_SPECIAL_PROMPTS`에 `wall_clock_exceeded` entry, `USER_CHOICE_TYPES`에 동일 추가.
- `BUDGET_SKIPPABLE` promoted to module-level `frozenset` (was local set in `main()`); test fixtures import `stop_hook.BUDGET_SKIPPABLE` so any future divergence between production and test fails immediately.
- `USER_CHOICE_TYPES_FOR_HINT` aliasing removed — `USER_CHOICE_TYPES` is the single source.

## [1.16.0] — 2026-05-17

### Security
- `commands/cancel-qg.md`: `$CLAUDE_CODE_SESSION_ID`가 비어있거나 패턴이 깨졌을 때 `rm -rf ".claude/quality-gates/$SID"`가 plugin 루트(`. claude/quality-gates/`)로 expand되어 동시에 실행 중인 모든 세션 폴더를 wipe하는 catastrophic 경로를 차단. 모든 destructive Bash 블록에 `[[ -n "$SID" && "$SID" =~ ^[A-Za-z0-9_-]{8,}$ ]]` SID-pattern 가드를 강제 (LLM prose 가드 → 셸-level 가드 격상). `--all` 경로에도 `[[ -d ".claude/quality-gates" ]]` 존재 가드 추가. Origin: Tier 1 audit U-7. *Persona-as-security-code 트리거: 향후 cancel-qg 가드 약화는 security review 대상.*

### Changed
- `README.md` "인스턴스화한 원칙" 섹션의 AP-ID cite drift 수정. `AP3 (Trivia ceremony)` → `P12 anti-corollary (former AP5)` (AP3는 §11.1 migration table 상 *Self-Approval*, AP5가 *Trivia Pipeline Overhead*였음). `AP9` → `P22 anti-corollary (former AP9)`, `AP16` → `P18 anti-corollary (former AP16)`로 post-restructure cite style로 정렬. Trivia 항목엔 현재 coverage(whitespace+rename only)와 deferred 확장 추적을 명시. Origin: Tier 1 audit F-3.
- `README.md` `## 설정` 섹션을 `### Tuning knobs` + `### Kill switches (보안 컨트롤)` 두 subsection으로 재구성. 모든 component disable env var (`DEVBREW_DISABLE_QUALITY_GATES`, `DEVBREW_DISABLE_QG_CODEX`, `DEVBREW_DISABLE_QG_SECURITY_REVIEWER`, `DEVBREW_DISABLE_GATE3_TEST_VALIDATION`, `DEVBREW_QG_DISABLE_BRANCH_WORKTREE`) + 모든 hook 키 (`stop-hook`, `session-tracker`, `post-tool-use`, `session-start-advisor`, `session-start-advisor:frontmatter-scan`, `session-end-cleanup`, `gate3-test-scope`)을 표 형식으로 통합. CLAUDE.md *"kill switch는 보안 컨트롤"* 원칙 instantiation: 보이지 않는 보안 컨트롤은 컨트롤이 아님. Origin: Tier 1 audit U-3 + U-4.
- `agents/plan-verifier.md`, `agents/runtime-verifier.md`, `agents/test-scope-validator.md`: opening identity prompt에 *"You are NOT responsible for ..."* clause 추가. CLAUDE.md Plugin Shape > Component Isolation의 *"You are X. You are responsible for Y. You are NOT responsible for Z."* triad 완성. Z 절은 persona-as-security-code의 scope-creep 방지 lock — 향후 PR에서 이 문장이 weakened되면 security-review trigger. Origin: Tier 1 audit F-8.
- `skills/quality-pipeline/SKILL.md`: 1349줄 SKILL 상단에 `## Contents` TOC 추가 (Workflow / Per-gate dispatch logic / Output templates 세 그룹). CLAUDE.md `docs/**.md ~300줄 이상이면 TOC 필수` 규정 instantiation. Origin: Tier 1 audit A-12.

### Removed
- `hooks/stop-hook.py` + `skills/quality-pipeline/SKILL.md`: dead `extend` transition 제거. v1.5.0이 cross-gate restart 메커니즘을 삭제하면서 `extend` action은 effective no-op이 되었으나 (update_state_file에서 no replacements, main에서 `("continue", "extend")` 공동 분기) 코드와 docstring·signal example에 잔존. `compute_transition`의 `action == "extend"` 분기, `update_state_file`의 trailing comment, `main()`의 합쳐진 elif 분기, signal example (`<qg-signal action="extend" />`) 모두 제거. 테스트 영향 없음 (extend signal 참조하는 테스트 0개). Origin: Tier 1 audit A-9.

### Deferred (Tier 2/3 spec)
- 다음 항목은 별도 spec 파일 `docs/superpowers/specs/2026-05-17-qg-tier2-3-improvements-design.md`로 분리되어 다음 release cycle에서 처리:
  - **Tier 2 (correctness)**: trivia escape coverage 확장 (comment-only, `--paths` 전파, untracked single-file), scout fallback의 AskUserQuestion 게이트 우회 차단 + Phase 1 dual-dispatch 통합, pipeline wall-clock budget, stop-hook no-signal infinite re-injection counter, codex 미설치 시 loud logging, state-write 실패 시 forward-progress 경로 routing, README state-machine diagram, adversarial 비용 prompt 포함.
  - **Tier 3 (refactor)**: scout/synthesizer/codex-reviewer를 deterministic script로 (LLM 판단 없는 layer), 8개 에이전트 중 7개의 behavioral test backfill.

## [1.15.0] — 2026-05-17

### Added
- `/qg branch <name>` — 다른 브랜치를 격리된 detached worktree에서 검사하는 새 surface. 현재 작업트리 무손상.
- `scripts/qg-worktree.sh` — worktree 라이프사이클 헬퍼 (`sanitize` / `validate-branch` / `create` / `remove` subcommands).
- State file schema fields: `worktree_path`, `target_branch` (worktree 모드일 때만 frontmatter에 emit).
- `tests/test_qg_worktree_helper.sh` — 18 unit cases (sanitize 6 + validate-branch 3 + create 6 + remove 3).
- `tests/test_branch_worktree.sh` — 20 integration cases (AC1–AC11 from spec).
- `tests/test_stop_hook_worktree_cleanup.py` — 6 unit cases (complete/abort/KEEP/legacy + AC8 preservation).
- `tests/test_session_end_cleanup.py` — 2 new cases for dangling worktree safety net.
- Kill switches: `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` (기능 차단), `DEVBREW_QG_KEEP_WORKTREE=1` (cleanup 차단).
- README "Recipes" 섹션 — PR 브랜치 검사 워크플로우 + worktree 보존/비활성화 가이드.
- Principles Instantiated 2 entries — Law 1 (7 rejection scenarios → AC1–AC11) + Law 3 (worktree path convention §4.8).

### Changed
- `scripts/setup-qg.sh`: `branch` 키워드 뒤 non-flag non-gate 토큰을 `<target-branch>`로 해석. 해당 모드에서 `qg-worktree.sh create`를 호출하고 state frontmatter의 `project_dir`을 worktree absolute path로 freeze. 새 토큰이 없으면 기존 `/qg branch` 동작 보존.
- `hooks/stop-hook.py`: terminal status (`complete`/`abort`) 분기에서 state의 `worktree_path` 존재 시 자동 cleanup (`DEVBREW_QG_KEEP_WORKTREE` 존중). non-terminal status에서는 보존 + stderr 안내 메시지로 사용자에게 worktree 경로 표시.
- `hooks/session-end-cleanup.py`: dangling worktree safety net — 세션 종료 시 state에 `worktree_path`가 있고 KEEP env가 미설정이면 `qg-worktree.sh remove` 호출.
- `commands/qg.md`: argument-hint 갱신 (`branch [<name>]`), Quick Reference에 `/qg branch <name>` 행 + 두 kill switch 환경변수 행 추가.

### Upgrade notes
- v1.14.x state file은 새 필드 `worktree_path` / `target_branch` 부재 → 기존 로직으로 fall through (stop-hook이 `state.get("worktree_path", "")` 빈 문자열 → cleanup 분기 미진입). Migration 없음.
- 기존 `/qg branch` (인자 없음) 동작 100% 보존 — argument-hint도 backward-compatible (`[branch [<name>]|...]`).
- v1.14.0의 worktree cwd contract (`project_dir` state frontmatter) 위에 올려짐. v1.14.0 미만에서 in-flight pipeline은 새 surface 사용 불가 (state schema 호환성 누락).

## [1.14.0] — 2026-05-16

### Added
- State file schema field `project_dir` (frontmatter) — single pipeline coordinate frozen at preflight (AC6, B6 fix).
- `project_dir` input contract on 6 Gate-2 agents: scout, codex-reviewer, adversarial, synthesizer, test-scope-validator, security-reviewer (AC2).
- `tests/test_hook_cwd_contract.py` — payload cwd contract for post-tool-use-session-tracker and session-start-advisor.
- `tests/test_worktree.sh` T5/T6/T7/T8/T9 — regression guards for SKILL dispatch, hook AST, codex-reviewer plugin paths, agent.md drift, state schema.
- `tests/test_codex_dispatch_invariant.sh` Scenario 4 — anchor-then-window awk for Pattern-P and Pattern-L dispatch blocks.

### Changed
- `hooks/stop-hook.py`: removed module-level `ROOT` constant; introduced `_state_root(hook_input)` helper deriving state path from payload cwd. `state_file_for(session_id, hook_input)` signature updated.
- `hooks/stop-hook.py:build_gate_prompt()`: all 3 gate branches now inject `project_dir: {state["project_dir"]}` into continuation prompts, ensuring gate-boundary cwd persistence.
- `hooks/stop-hook.py:parse_state_file()`: surfaces `project_dir` with v1.13.x backward-compat fallback (`os.getcwd()` + stderr warning, mirroring `gate3_resolution_iter` pattern at L114-120).
- `hooks/post-tool-use-session-tracker.py`: state path and `abs_path` resolution base both derived from payload cwd.
- `hooks/session-start-advisor.py`: `_scan_agent_frontmatter_keys` now takes payload arg and derives `repo_root` from payload cwd instead of `Path.cwd()`.
- `agents/codex-reviewer.md`: bash block guards empty `project_dir`, `cd "$project_dir"`, `REPO_ROOT="$project_dir"` (no more `git rev-parse`); plugin scripts called via `${CLAUDE_PLUGIN_ROOT}/scripts/` instead of `$REPO_ROOT/plugins/quality-gates/scripts/` (which only existed in devbrew's self-test).
- `skills/quality-pipeline/SKILL.md`: 4 Pattern-P dispatch blocks (scout/adversarial/synthesizer/test-scope-validator) and 1 Pattern-L block (Agent D security-reviewer) now declare `project_dir: <current working directory>` in their prompts.

### Fixed
- **B1**: stop-hook.py `ROOT` constant relative-path bug — state file path now derived from payload cwd (worktree-safe).
- **B2**: post-tool-use-session-tracker.py `Path(".claude/quality-gates")` relative bug + `abs_path` resolution against wrong base.
- **B3**: session-start-advisor.py `Path.cwd()` worktree blindness.
- **B4**: SKILL.md missing `project_dir` in dispatches to scout/codex-reviewer/adversarial/synthesizer/test-scope-validator/security-reviewer.
- **B5**: codex-reviewer.md (a) `$REPO_ROOT/plugins/quality-gates/scripts/...` path broken outside devbrew, (b) missing `cd "$project_dir"` causing subprocess cwd nondeterminism.
- **B6**: state file schema lacked `project_dir`; stop-hook `build_gate_prompt()` never propagated it across gate boundaries — caused gate2/3 continuations to re-evaluate cwd in main repo when pipeline was launched from worktree.
- **B3 completion**: session-start-advisor primary advisory path (sibling-count + self-pipeline check) now derives state root from payload cwd, matching the frontmatter-scan sub-feature fix.
- **B7 (new)**: session-end-cleanup.py removed module-level relative ROOT; per-session folder cleanup now anchored to payload cwd, eliminating silent state-leak when session ends with process-cwd different from worktree.

### Upgrade notes
- In-flight v1.13.x pipelines: state file lacks `project_dir`; `parse_state_file()` falls back to `os.getcwd()` + stderr warning. If your continuation is running from a worktree, expect one warning per gate transition. For clean state, run `/cancel-qg && /qg` after upgrade.
- No state-file format break: v1.13.x state files remain readable; v1.14.0 state files have one additional `project_dir:` line that older code would simply ignore.

## [1.13.0] — 2026-05-16

### Added

- **Phase 1 always-run `security-reviewer` agent.** Code-level security review now runs on every Gate 2 invocation (all 3 depth tiers: quick / standard / deep). Hunts injection, authn/authz bypass, secrets, SSRF + path traversal, insecure deserialization, cryptographic misuse, raw-HTML escape hatches, and dependency manifest changes. Emits canonical finding YAML schema (`adversarial.md:22-30`). Persona declares `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` for Law 2 physical isolation; `cost_class: medium`; `model: inherit`.
- **Kill switch `DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1`.** Mirrors codex-reviewer's `DEVBREW_DISABLE_QG_CODEX` pattern. Loud-logging graceful degradation: stderr emits `security-reviewer disabled via DEVBREW_DISABLE_QG_SECURITY_REVIEWER=1` on activation; other Phase 1 reviewers continue to run.
- **Structural tests.** `tests/test_security_reviewer_persona.sh` (frontmatter + schema keyword + role declaration grep) and `tests/test_security_reviewer_kill_switch.sh` (SKILL.md kill switch reference grep).
- **Integration smoke fixtures.** `tests/fixtures/security-reviewer/{sql-concat,clean,expected}/` — opt-in, CI-non-blocking (LLM non-determinism).

### Changed

- **Phase 1 dispatch fan-out.** Phase 1 catalog grows by 1 (now: code-reviewer, silent-failure-hunter, feature-dev:code-reviewer, security-reviewer + conditional codex-reviewer). On `deep` depth with codex-reviewer available, `phase1_agents = 4` + `external_reviewers = 1` = 5, exceeding the AskUserQuestion fan-out gate (≥ 4) — users see an explicit confirm before parallel dispatch.
- **Synthesizer suppression rule (`synthesizer.md` step 4).** Was: "Suppress entries where confidence < 7." Now: "Suppress entries where confidence < 7 AND severity != CRITICAL." Honors spec §4.4 "P0 + anchor 50 always reports" — a critical-impact finding surfaces even at low confidence. Applies to all Phase 1 reviewers (not just security-reviewer). Output section label updated to `### Suppressed (confidence < 7, severity != CRITICAL)`.

### Security

- New `security-reviewer` persona file is security-sensitive code per CLAUDE.md ("Persona 파일은 보안-민감 코드"). PRs weakening hunt categories, lowering anchored confidence rubric, or removing the forced-findings prohibition rule require security review.

## [1.12.0] — 2026-05-14

### Added

- `tests/test_agent_frontmatter_keys.sh` — repo-wide agent frontmatter convention deny-list (AC15).
- `hooks/session-start-advisor.py` 에 frontmatter scan sub-feature 확장 + `_subfeature_disabled()` helper (AC14).
- `tests/test_consent_marker_write_failure.sh` (AC11 검증).
- `tests/test_codex_dispatch_invariant.sh` scenario 3 (AC13 fallback).
- `tests/fixtures/codex_findings_dict_input.json`, `codex_findings_string_input.json`, `codex_two_fenced_blocks.json` (AC9 fixtures).

### Changed

- `scripts/detect_codex.sh` — `codex --version` 호출을 `timeout 5` 로 래핑. 7번째 case `skip_reason: timeout_binary_missing` 추가 (AC7).
- `agents/codex-reviewer.md` agent body — TIMEOUT_CMD/REPO_ROOT empty 검사 + prompt builder exit-code 검사 (AC8/AC10).
- `README.md` — 디렉토리 트리에 codex 관련 4파일 추가, Gate 2 stage diagram에 codex-reviewer 노드, Fan-out 11→12, Principles Instantiated에 Law 2/Law 3 instantiation (AC16).
- `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` — 스크립트 파일명 dashes → underscores (AC17).

### Fixed

- `scripts/codex_findings_to_yaml.py`:
  - non-list findings → `meta.reason: schema_mismatch` + `meta.raw_findings_type` surface (silent coerce 종료) (AC9a).
  - `parse_fenced_json` last block 선택 (prompt injection 차단) (AC9b).
  - `AUTH_ERROR_RE` 확장: 401/403/forbidden/quota/expired 등 (AC9c).
  - stderr 읽기 실패 시 `meta.stderr_read_error: <errno>` (AC9d).
- `skills/quality-pipeline/SKILL.md`:
  - cost consent marker write 실패 시 stderr 메시지 — fenced bash block + `# QG-CONSENT-MARKER-WRITE` 식별 주석으로 V14가 추출 검증 가능 (AC11).
  - detect_codex.sh manifest schema validation (AC12).
  - scout-fallback 분기에서도 codex 가용 + consent 시 codex-reviewer dispatch + 명시적 stderr 메시지 (AC13).

### Notes

- Spec: `docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md` (AC7–AC19).
- Audit: `docs/research/2026-05-14-pr33-pr32-retroactive-audit.md`.
- Law 2 instantiation: 3-layer reviewer-writer isolation (codex-reviewer)가 v1.11.1에서 복구된 후 v1.12.0에서 schema/auth/timeout 안전성 추가.
- Law 3 instantiation: agent frontmatter convention drift 재발을 차단하는 compounding mechanism (advisor + bash test) 신설.

## [1.11.1] — 2026-05-14

### Fixed

- `agents/codex-reviewer.md` frontmatter key를 `allowed-tools` (kebab-case) → `allowedTools` (camelCase) 로 수정. v1.11.0에서 Layer 2 isolation (narrow Bash whitelist)이 잘못된 키 때문에 실질적으로 비활성이었음. `tests/test_codex_reviewer_frontmatter.sh` 도 같은 잘못된 키를 검사하던 4 occurrences를 함께 수정.
- `agents/scout.md`에서 codex-reviewer dispatch instruction 제거. v1.11.0에서 scout이 `phase1_agents`에 codex-reviewer를 추가하면 SKILL.md validation FAIL → scout-fallback → codex-reviewer silently dropped 상태였음. dispatch 단일 진실은 SKILL.md로 이동 (manifest 가용성 + consent 기반).
- `skills/quality-pipeline/SKILL.md` Phase 1 dispatch logic: codex 가용 + consent OK 시 codex-reviewer를 in-process subagent 3개와 parallel dispatch에 무조건 포함. codex 미가용 시 v1.10.x byte-equivalent 3-agent dispatch 유지.

### Security

- 3-layer reviewer-writer isolation의 Layer 2 (`allowedTools` deny-list/allow-list narrow whitelist) 복구. v1.11.0의 광고된 보안 보장이 실제로 작동 시작.

### Notes

**SemVer 분류 근거**: v1.11.0의 codex-reviewer dispatch는 C1+C2 결함으로 인해 production에서 실제로 작동하지 않았음 — 본 PR의 "scout codex emit 제거"는 SemVer 의미상 "deprecation of never-working behavior" 이므로 backward-incompatible 변경 아님. devbrew CLAUDE.md "one-minor deprecation window" 요건은 본 케이스에 적용되지 않음.

Audit findings: `docs/research/2026-05-14-pr33-pr32-retroactive-audit.md` (C1, C2, I-부분).
Spec: `docs/superpowers/specs/2026-05-14-qg-codex-reviewer-recovery-design.md` (AC1–AC6).

## [1.11.0] — 2026-05-14

### Added

- `codex-reviewer` agent: independent code reviewer dispatched as a separate process via `codex exec --json -s read-only` when Codex CLI is detected. Adds OS-process + model-family separation to QG Gate 2 Phase 1, strengthening Law 2 (writer-reviewer physical separation).
- `scripts/detect_codex.sh`: 6-case probe (not_installed, kill_switch, inside_codex_sandbox, auth_missing, known_bad_version, ok). Read-only, exit 0 always. Known-bad version regex covers Codex CLI 0.120.0-0.120.2 (stdin deadlock bug).
- `scripts/codex_findings_to_yaml.py`: JSONL stream parser with 3-stage fallback chain (fenced JSON → raw JSON → malformed_json). Handles both Codex 0.130+ nested `item.completed` event shape and legacy top-level `agent_message` shape. Includes stderr capture for `auth_error_in_stderr` (Codex exit 0 + auth failure pattern). Supports `--meta-override-exit-code` and `--meta-override-reason` flags for agent-side timeout/exit-nonzero classification.
- `scripts/build_codex_prompt.py`: safe prompt construction — reads inputs from file paths, substitutes via `str.replace` with no shell/Python literal injection vector.
- First-use cost consent gate: `AskUserQuestion`-based prompt with marker file at `~/.claude/quality-gates/codex-cost-consent.md`. Silent after first approval. Test harness uses `QG_MOCK_ASKUSER_PATH` env var for deterministic verification.
- Kill switch: `DEVBREW_DISABLE_QG_CODEX=1` disables codex-reviewer globally.
- Task 0 prompt-engineering spike (`tests/spike/`) — empirically validated codex emits fenced JSON in `agent_message` ≥2/3 runs. Frozen sample (`fixtures/codex_jsonl_sample.json`) serves as regression anchor against future codex event-schema drift.

### Changed

- `agents/scout.md`: dispatch input now includes `codex_manifest` (backwards-compatible — when `codex_available: false`, Phase 1 dispatch list is unchanged from prior behavior).
- `skills/quality-pipeline/SKILL.md`: Gate 2 Phase 0 prerequisite now runs `detect_codex.sh` and synthesizes the manifest into Scout's input. Cost consent gate fires between probe and Scout dispatch.

### Security

- 3-layer reviewer-writer isolation for codex-reviewer agent:
  1. Frontmatter `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit, Glob]`
  2. Frontmatter `allowed-tools` narrow Bash whitelist (no `Bash(cat *)` — prevents redirection bypass)
  3. `codex exec -s read-only` OS-level sandbox
- Closed prompt-injection vector during Task 4 review: agent body now writes inputs to scratch files via single-quoted heredocs (`<<'EOF'`) and substitutes via Python `str.replace` on file paths — adversarial PR content (e.g., `"""` in diff text) cannot escape into outer agent execution.

### Notes

- Bumps QG Gate 2 max parallel fan-out from 11 → 12 (deep depth with codex-reviewer in Phase 1 + all Phase 2 specialists). Still within declared fan-out regime.
- AC7 (backward-compat regression) is verified structurally (probe + scout-rule + existing test suite) rather than via synthesizer baseline diff. See `tests/fixtures/baseline_capture_README.md` for the deferral rationale.
- Spec: `docs/superpowers/specs/2026-05-13-qg-codex-reviewer-design.md` v3.1 (3 rounds adversarial review, 29 issues addressed).

## [1.10.0] — 2026-05-13

### Changed
- **SKILL.md prose** aligned with the v1.5.0 forward-only state machine. Five
  sites in `skills/quality-pipeline/SKILL.md` had carried the pre-1.5.0
  "auto-restart from Gate 1" vocabulary; they now describe the actual
  Stop-hook behavior (user-choice prompt; user re-runs `/qg`).
- **`GATE3_FAIL` prompt option 1 label** is now `"Fix and re-run /qg"`
  (was `"Fix issues (will restart from Gate 1)"`). User-visible string
  change; semantics already matched the new label since v1.5.0.
- **Example history log** in `references/state-file-format.md` no longer
  shows `Restarting from Gate 1 (iteration 2)` — replaced with the
  forward-only termination line.

### Removed
- **`total_iterations` / `max_total_iterations`** state-file fields. Deprecated
  in v1.5.0, never written since, and (discovered during this cleanup) the
  `extend` branch in `update_state_file` that incremented `new_max_total`
  was already a dead write because `max_total_iterations` had been absent
  from the `replacements` dict for a year. Removed from `parse_state_file`,
  `update_state_file`, schema doc, and three fixture files. The
  `test_no_max_total_iterations_constant` gate test is preserved.

### Fixed
- **Doc-vs-code drift**: SKILL.md verdict definitions, GATE3_FAIL prompt,
  and Gate 2 output format no longer mis-instruct reviewers that the
  pipeline auto-restarts from Gate 1. Locked by the new
  `tests/test_forward_only_prose.sh` grep guard (AC1–AC8 + NG7,
  8 assertions, exit 0 on PASS).
- **Stale comment in `main()` extend branch** (`# State file already
  updated with new max`) replaced with an accurate description: the prior
  `new_max_total += additional` was a silent no-op since v1.5.0 because
  `max_total_iterations` was never in the replacements dict. Caught during
  Task 3 code review; CLAUDE.md Law 3 compounding.

### Internal
- **`build_special_prompt`** refactored from a 6-case if/elif ladder
  (~146 LoC) to a module-level `_SPECIAL_PROMPTS` per-case dict + a 43-line
  dispatcher. Semantics preserved; locked by `tests/test_stop_hook_unit.py`
  (5 invariants: exact case-tag header prefix, length > 200, `<qg-signal`
  ≥ 2 directives, abort option present, exact `PIPELINE_ERROR\n\n`
  prefix on unknown transitions).
- **`main()` transition-handler** collapses 4 duplicated
  `print(json.dumps({...})); sys.exit(0)` blocks into a single
  `emit_continuation` helper called after a small prompt-selector
  dispatch. Handler block shrank ~73 → ~51 LoC (-22).
- **`hooks/stop-hook.py` LoC**: before 960, after 964. The spec's
  ≤ 800 target turned out to be over-optimistic — the `_SPECIAL_PROMPTS`
  dict for 7 cases is roughly as long as the original if/elif ladder
  (data encoding doesn't compress over branches). The realistic floor
  for D1+D2+D3 was ~950–960. The substantive win is structural (one
  source of truth per case, unified trailer) and the unit-test net
  protects against future drift, not raw LoC.

### Notes
- Stop-hook itself remains. The spec's "Stop-hook review" section enumerates
  6 responsibilities (turn-boundary auto-progression, multi-turn Gate 2
  fix-loop, user-choice prompt injection, state-file management, repeat-
  detection invariant, mid-session cleanup); none can be moved into the
  skill without losing automatic continuation or the code-enforced
  AP15 *"loop without repeat detection"* guard. The user-prompted
  re-evaluation ("이제와서는 stop hook이 반드시 필요할지도 검토해봐")
  is preserved in the spec's §Context for future readers.

## [1.9.0] — 2026-05-12

### Added
- **Gate 3 Step 2.5 — Test scope validator** (informational, non-blocking).
  New `test-scope-validator` agent classifies scope-relevant test files as
  `aligned` / `outdated-suspicion` / `cherry-pick-suspicion` / `unclear`
  before `runtime-verifier` executes them. Surfaces silent failure modes
  (outdated tests against post-refactor behavior; tautological assertions
  added for coverage padding) without blocking Gate 3.
- `scripts/compute-test-scope-candidates.sh` — deterministic candidate
  resolver (Python/JS/TS heuristic src→test mapping + changed-test fallback).
- `agents/test-scope-validator.md` — read-only agent with `Write`/`Edit`
  disallowed (Law 2 3-way separation: writer / test-scope-validator /
  runtime-verifier).
- `tests/test_compute_test_scope_candidates.sh`, `tests/test_test_scope_validator_frontmatter.sh`
- `tests/fixtures/test-scope/{aligned,outdated,cherry-pick}/` — reference
  fixtures for manual verification.

### Changed
- `skills/quality-pipeline/SKILL.md` — Gate 3 gained Step 2.5 between
  Step 2 (Upfront resolution) and Step 3 (Dispatch runtime-verifier).
  Existing verdict model and stop-hook continuation prompts unchanged.

### Environment
- New: `DEVBREW_DISABLE_GATE3_TEST_VALIDATION=1` — skip Step 2.5 entirely.
- New: `DEVBREW_SKIP_HOOKS=quality-gates:gate3-test-scope` — alternate kill
  switch (consistent with existing skip-hook pattern).

## [1.8.1] — 2026-05-12

### Added
- **Worktree regression guards** (`tests/test_worktree.sh`, `tests/test_isolation.sh`): hermetic mktemp-based tests that lock in qg's PWD-relative state-path contract — the structural property that makes git-worktree isolation work without any worktree-specific code in the plugin. `test_worktree.sh` (10 assertions) verifies setup/discover/trivia/pre-check all read worktree-local context and never leak into the origin repo's `.claude/`. `test_isolation.sh` (11 assertions) verifies bidirectional isolation under a shared session ID (worktree ↔ origin), distinct-inode property of the two pipeline.md files, and that two concurrent sessions in the same directory remain independent. These tests will fail if anyone introduces `git rev-parse --git-common-dir` / `--show-toplevel`-rooted state paths, which would silently break worktree isolation.

## [1.8.0] — 2026-05-11

### Added
- **Pre-flight runtime detector** (`scripts/detect-runtime.sh`): `project_type`, `runnable_surfaces` (docker-compose / npm-script / pytest / cargo / go / makefile), `test_runners`, `mcp_browser` (chrome-devtools / playwright / none), `app_url_candidates`, `env_status`, `plan_features` (`PLAN_PATH` env에서 추출) 를 YAML manifest로 산출하는 결정적 bash script. read-only.
- **Fast-path SKIP_WITH_EVIDENCE**: detector가 runnable_surfaces / test_runners / plan_features 모두 비어있다고 보고하면 Gate 3가 agent dispatch 없이 즉시 SKIP_WITH_EVIDENCE emit (token cost = 0).
- **Mid-run NEEDS_RESOLUTION escalation**: agent가 fixable한 missing resource에 대해 사용자 해결을 요청 가능. Skill이 3자 ping-pong (skill ↔ user ↔ agent)을 AskUserQuestion 으로 중재. `max_gate3_resolutions` (기본 3) 으로 묶임.
- **`DEVBREW_GATE3_MAX_RESOLUTIONS` env override** (0..10 clamp). `0` 으로 설정 시 mid-run escalation 비활성화 (Approach 2 mode — 첫 NEEDS_RESOLUTION 이 바로 `gate3_fail` transition 으로 가서 user에게 fix/skip/abort 선택 제시).
- **Repeat detection** (`needed_hash` 기반): 같은 missing resource가 2회 연속이면 `gate3_repeat_detected` → user choice (proceed_with_warnings / abort).
- **Evidence-log validation** (skill 측): manifest의 모든 항목이 attempted entry를 가져야 함; 누락된 항목이 있으면 SKIP_WITH_EVIDENCE 를 자동 FAIL 로 격상.
- **Fixture 기반 테스트**: 4개 fixture (web-compose / web-example-only / library-tests / markdown-only), `tests/test_detect_runtime.sh` 의 30+ assertion, `TestGate3ResolutionState` 의 10+ 신규 state-machine 테스트, frontmatter lint 테스트, secret-leakage regression 테스트 (AC12 / P21).

### Changed
- **`runtime-verifier.md` 재작성 (v2)**:
  - Frontmatter 가 `allowedTools: [Read, Bash, Grep, Glob, mcp__plugin_chrome-devtools-mcp_*]` 와 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 명시 — CLAUDE.md Plugin Shape "default-everything 금지" 위반 fix.
  - `cost_class: variable` (기존 `low` 에서 변경 — iteration loop 가능).
  - Body: manifest-driven attempt 흐름, evidence-log 작성 의무, 4-verdict 체계 (PASS / FAIL / SKIP_WITH_EVIDENCE / NEEDS_RESOLUTION), secret 값 요청 금지 P21 guard 명시.
- **SKILL.md Gate 3 섹션** 6 단계 재작성 (detect → fast-path → upfront resolution → dispatch → evidence validation → NEEDS_RESOLUTION).
- **stop-hook.py**: 신규 transition `gate3_needs_resolution`, `gate3_repeat_detected`; 신규 state field `gate3_resolution_iter`, `max_gate3_resolutions`, `last_gate3_needed_hash`. 기존 `SKIP` verdict 는 그대로 `complete` 로 라우팅 (back-compat); `SKIP_WITH_EVIDENCE` 와 `PASS_WITH_WARNINGS` 가 같은 complete-bucket 에 합류.

### Fixed
- **Gate 3 의 silent SKIP regression**: 이전엔 project type detection fall-through (`package.json scripts.dev` 없음, `manage.py` 없음) 시 silently `unknown` → SKIP 으로 빠지면서 user 에게 알림이 없었음. 이제 evidence-required SKIP 이 이 경로를 거부; skill 이 fast-path SKIP (evidence log 동반) 으로 처리하거나 incomplete attempt 를 FAIL 로 격상.
- **chrome-devtools MCP under-utilization**: 이전엔 agent 가 사용 가능한 browser MCP tool 을 runtime keyword search 로 발견해야 했음. 이제 detector 가 `mcp_browser: chrome-devtools | playwright | none` 을 manifest 에 결정적으로 inject.

## [1.7.0] — 2026-05-10

### Added
- **Project-local plan discovery** (`scripts/discover-plan.sh`): Gate 1 plan-verifier가 `docs/superpowers/plans/` (superpowers:writing-plans 의 기본 저장 경로)을 1순위로, `~/.claude/plans/`를 legacy fallback으로 consult. 이전에는 `~/.claude/plans/`만 봐서 superpowers 워크플로우로 만든 plan이 항상 SKIP 되거나 옛 plan을 false-match 하던 버그 fix.
- **`Source` 필드** Gate 1 report에 추가 — 어떤 source(explicit / project-local / legacy-global)에서 plan을 가져왔는지 사용자가 즉시 인지 가능.
- **단위 테스트 10 개** (`tests/test_discover_plan.sh`): 양쪽 source 비어있음, project-local 우선, legacy fallback, non-plan 파일 필터, explicit override, mtime tiebreaker, `--plan` 인자 누락 regression(T10) 등 매트릭스 커버.

### Changed
- Discovery 알고리즘이 `agents/plan-verifier.md` prose 안의 자유서술에서 결정적 bash script로 이동. 미래 source 추가도 회귀 없이 가능. (Law 2 정신 — agent 자유서술 vs script contract.)
- Legacy source (`~/.claude/plans/`) 사용 시 `agents/plan-verifier.md`가 `⚠️ Legacy plan source ... Consider migrating ...` 1줄 deprecation 경고를 report 헤더 직전에 emit. project-local hit이면 silent.
- README "Principles Instantiated" 섹션에 Law 3 cross-plugin compounding 항목 추가 — `superpowers:writing-plans`의 출력 위치를 sister-plugin contract로 명시.
- `discover-plan.sh`가 `plan_path` 필드를 절대 경로로 emit (Task 2 fix). agent의 `Read` 호출이 cwd와 무관하게 작동.

### Fixed
- **Path mismatch (Gate 1 SKIP/false-match bug)**: `superpowers:writing-plans` 가 `docs/superpowers/plans/` 에 plan을 저장하는데 plan-verifier 는 `~/.claude/plans/`만 스캔해서 (a) 사용자의 최신 plan을 찾지 못하거나 (b) `~/.claude/plans/` 의 옛날 무관한 plan을 잘못 verify 하던 문제. 1.7.0 부터 priority 기반 discovery 로 정확히 매칭.
- **`--plan <missing>` 무한 루프**: `discover-plan.sh --plan` (path 인자 누락) 시 `shift 2` 실패가 silent하게 묵살되어 무한 루프에 빠지던 corner case. `[[ $# -lt 2 ]]` 가드 + exit 2 처리 + T10 regression test.

## [1.6.3] — 2026-05-10

### Fixed
- **Step 0 review-range fallback** (skill `quality-pipeline`): 작업 트리가 깨끗할 때(모두 commit됨) 기존 bash block은 빈 `git diff`로 fall-through해 review 대상이 0줄이 되던 문제. 이제 working tree가 dirty면 unstaged diff(기존), clean이면서 `main..HEAD`에 commit이 있으면 자동으로 `main...HEAD` 누적 branch diff로 전환. 6개의 `git diff` 호출 모두 통일된 `$REVIEW_RANGE`를 사용. (qg self-review §5.1 — v1.6.2 dogfood에서 발견)
- **Test detection regex**: `^tests?/`가 top-level `tests/`만 매칭해 nested `<sub>/tests/` (monorepo / plugin marketplace 구조)에서 `test_change=0` false negative 발생. `(^|/)tests?/`로 변경 — top-level + nested 모두 매칭.
- **`set -e` 제거 (Step 0 bash block)**: 모든 명령이 이미 `|| true` / `|| echo 0`으로 실패 처리하고 있어 `set -e`는 redundant했고, subshell command substitution과 상호작용하면서 fix-loop iteration에서 silent abort 유발. 제거 후 각 명령의 failure mode가 local + 예측 가능.

### Changed
- Step 0 JSON output에 `review_range` 필드 추가 — 어떤 모드(unstaged / `main...HEAD`)로 review됐는지 사용자가 보이도록.

## [1.6.2] — 2026-05-10

### Fixed
- v1.6.1의 kill switch fix가 5개 hook 중 3개만 다룬 상태였음 — `session-start-advisor.py`와 `session-end-cleanup.py`는 글로벌 `DEVBREW_DISABLE_QUALITY_GATES=1`만 honor하고 per-hook `DEVBREW_SKIP_HOOKS=quality-gates:<key>`을 무시했음. 두 hook 모두 `_disabled()`에 SKIP_HOOKS 체크 추가 (skip key: `quality-gates:session-start-advisor`, `quality-gates:session-end-cleanup`). 이제 README의 "All hooks honor..." 약속이 5/5 hook에서 코드로 지켜짐.
- **CRITICAL — substring prefix collision**: 5개 hook 모두 `_disabled()`에서 raw `"quality-gates:<key>" in skip` 형태의 substring match를 사용해, 사용자가 `DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use-session-tracker`을 설정하면 (script filename을 key로 잘못 사용한 자연스러운 실수) `quality-gates:post-tool-use`가 그 안에 prefix로 포함되어 `post-tool-use.py`도 함께 silently 비활성화됨. 5개 hook 모두 whole-token match로 변경 — `skip.split(",")` 후 `t.strip()`된 토큰 set에 정확히 매칭. CLAUDE.md "kill switch는 보안 컨트롤" 규정의 contract 위반 fix. (Gate 2 pipeline review에서 발견)

### Added
- `tests/test_kill_switches.py` 회귀 테스트: 5개 hook 모두에 대해 글로벌 + per-hook + CSV 형태 SKIP_HOOKS가 side effect를 차단하는지 검증. side effect 검출은 hook별로 differentiated (state mutation / `systemMessage` injection / `files.md` 생성 / advisor stdout / 폴더 삭제). sanity test로 *kill switch 없을 때* setup이 실제로 side effect를 일으키는지도 검증해 trivial pass 방지.
- `test_per_hook_skip_does_not_cross_contaminate` — 위 substring prefix collision 회귀 가드. `DEVBREW_SKIP_HOOKS=quality-gates:post-tool-use-session-tracker` 설정 시 `post-tool-use.py`가 *여전히* 작동(`systemMessage` emit) 확인.
- `test_all_hooks_declare_kill_switch_strings` — `hooks/*.py`를 동적으로 enumerate해서 각 파일에 `DEVBREW_DISABLE_QUALITY_GATES`와 `DEVBREW_SKIP_HOOKS` 문자열이 모두 존재하는지 source-text static check. 새 hook이 `HOOK_CONTRACTS` static list에 추가되지 않은 채 kill switch 없이 ship되는 회귀 패턴(v1.6.1, v1.6.2의 동일 원인)을 merge time에 잡음.
- `_assert_no_side_effect`의 stop-hook assertion에 `proc.stdout.strip() == ""` 추가 — 기존엔 `pipeline.md` 미변경만 체크해 `_disabled()`가 silently broken되어도 통과했음 (no-signal stop-hook 정상 path도 pipeline.md를 변경하지 않으므로). stdout 체크가 두 path를 discriminate.
- sanity test의 stop-hook 분기를 bare `pass`에서 `assertIn("decision", proc.stdout)`로 교체 — sanity test가 stop-hook에 대해서도 진짜 차이를 검증.

## [1.6.1] — 2026-05-10

### Fixed
- **CRITICAL**: `stop-hook.py`와 `post-tool-use.py`에 `DEVBREW_DISABLE_QUALITY_GATES=1` 및 hook 단위 `DEVBREW_SKIP_HOOKS=quality-gates:<hook>` kill switch 누락. README는 "All hooks honor..."를 보장하지만 두 hook은 환경변수를 무시하고 fire하던 상태. CLAUDE.md "kill switch는 보안 컨트롤" 규정 위반 fix. fail-closed 패턴(부수효과 발생 전 `sys.exit(0)`)으로 main() 진입점 최상단에 추가.
- README "Principles Instantiated" 섹션의 stale 문구 *"once that file lands on `main`"* 제거 — `docs/philosophy/devbrew-harness-philosophy.md`는 이미 main에 있음.

### Changed
- `README.md`를 Korean-primary로 재작성. CLAUDE.md "Korean-primary, English-terms-only" 정책 적용 (식별자·고유명사·원문 인용·번역 어색한 기술 용어에만 영어 허용).
- `CHANGELOG.md`를 Korean-primary로 재작성. 기존 영문 prose를 한국어로 번역, Keep a Changelog 섹션 헤더(Added/Changed/Fixed/Security 등)는 컨벤션상 영어 유지.

### Removed
- `README.ko.md`와 `CHANGELOG.ko.md` 동반 파일 삭제. CLAUDE.md "`*.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치)" 규정 적용.

## [1.6.0] — 2026-05-08

### Added
- SessionEnd hook (`session-end-cleanup.py`) — 정상 종료 시 per-session state cleanup.
- `scripts/qg-gc.py`: `fcntl` lock + double-stat ns race guard + rename-then-rmtree로 보호된 TTL 기반 GC 헬퍼.
- 환경변수: `DEVBREW_QG_TTL_HOURS` (기본 24), `DEVBREW_QG_GC_VERBOSE` (기본 off).
- `/cancel-qg --gc` (TTL sweep)와 `/cancel-qg --all` (active sibling 리스트 + confirm 후 전체 wipe).
- `/qg --gc` flag — 명시적 GC 호출.
- `setup-qg.sh --session-id <id>` 인자 — `CLAUDE_CODE_SESSION_ID` env var 미설정 시 fallback.
- `post-tool-use.py`를 `hooks.json`에 PostToolUse(Bash) hook으로 등록 (이전엔 orphan 상태).

### Changed
- state 위치를 flat `.claude/quality-gates*.local.md` (5 파일)에서 per-session `.claude/quality-gates/<session-id>/{pipeline,files,branch}.md` + `{diff-cache,code-paths}` 로 이동.
- `session-start-advisor.py`가 이제 현재 세션만 scope하고 read-only (CLAUDE.md "SessionStart never mutates" 룰).
- `setup-qg.sh`가 `CLAUDE_CODE_SESSION_ID`도 `--session-id`도 없으면 hard-fail.
- `setup-qg.sh`가 시작 시 `qg-gc.py` 호출 (best-effort; 실패해도 setup은 abort 안 함).
- `/qg --reset`이 현재 세션 폴더 + legacy v1.5.0 파일을 wipe (이전엔 flat 파일만).
- README "Principles Instantiated": P21 mis-citation을 P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)로 정정. state 파일 룰은 P21 (Security & Supply Chain)에 속한 적이 없음.

### Fixed
- 같은 프로젝트의 동시 세션이 더 이상 서로의 state를 corrupt하지 않음 (이전엔 5개 공유 `.claude/` 파일).
- crash/close된 세션의 stale state가 무관한 새 세션에서 misleading "in-flight pipeline" advice를 트리거하지 않음.
- `post-tool-use.py`의 "active pipeline" 체크가 호출 세션만 scope (이전엔 어느 세션의 파이프라인이라도 auto-trigger를 차단).

### Removed
- flat per-project state file 모델. 5개 legacy 파일(`quality-gates.local.md`, `quality-gates-session.local.md`, `quality-gates-branch.local.md`, `qg-diff-cache.txt`, `qg-code-paths.tmp`)은 upgrade 후 첫 `/qg` 실행 시 stderr 경고와 함께 unlink.

### Migration
- `session-start-advisor`가 legacy 파일 발견 시 일회성 stdout 메시지 (read-only — 절대 삭제 안 함).
- in-flight v1.5.0 파이프라인은 자동 마이그레이션되지 않음. 이전 session_id는 그 prior 세션에만 의미가 있으므로, `/qg` 재실행.

## [1.5.0] — 2026-04-30

### Added
- Phase 0 `scout` agent: Sonnet, 모델 기반 Gate 2 dispatch planner. 필터링된 diff + Gate 1 summary를 읽어 구조화된 YAML dispatch plan (depth + phase1_agents + phase2_agents + rationale)을 생성.
- Phase 1.5 `adversarial` agent: Opus, Phase 1+2 finding의 false-positive 사냥 (confirm/downgrade/reject 판정). 노이즈에 의한 fix-loop 반복을 줄이며 리뷰를 강화.
- Phase 1.6 `synthesizer` agent: Sonnet, finding을 dedupe/rank (severity × confidence), confidence < 7 suppress, 사용자에게 보일 prioritized Markdown 산출.
- `PostToolUse` hook `post-tool-use-session-tracker.py`: Edit/Write/MultiEdit 파일 경로를 `.claude/quality-gates-session.local.md`에 누적해 `/qg` scope을 좁힘.
- `SessionStart` hook `session-start-advisor.py`: 변경 없는 read-only advisor — in-flight 파이프라인을 알림 (CLAUDE.md hook coexistence 룰 준수).
- `/qg branch`, `/qg --paths <glob>`, `/qg --reset` flag 지원.
- pipeline skill과 모든 신규 agent에 `cost_class` 선언.
- Trivia escape (`scripts/check-trivia.sh`): 단일 파일·≤3줄 whitespace/rename 시 파이프라인 전체 자동 skip.
- Docs 필터 (`scripts/filter-docs.sh`): `*.md` / `docs/**` / `CHANGELOG*` / `README*`을 코드 reviewer scope에서 제외 (Gate 1 plan-verifier는 raw diff를 그대로 봄).
- Repeat-detection: 두 iteration 연속으로 scout dispatch plan + synthesizer 출력이 동일하면 `gate2_repeat_detected` user choice 발동 (philosophy AP15 인스턴스화).
- Gate 1 → Gate 2 핸드오프 포맷: 구조화된 `gate1_summary` YAML 블록; FAIL 시 Gate 2 진입 차단 (Law 1).
- Phase 1+2 dispatch 수가 ≥4일 때 AskUserQuestion hard gate (philosophy AP9 인스턴스화).
- Pre-pipeline check (`scripts/pre-pipeline-check.sh`): 세션 라이프사이클 처리 (active resume / branch mismatch / staleness / fresh start).
- `tests/` 신규 테스트: `test_session_tracker.py` (7), `test_session_start_advisor.py` (10), `test_stop_hook_state_machine.py` (6).

### Changed
- 기본 review scope이 풀 브랜치 diff가 아니라 **현재 Claude Code 세션에서 편집한 파일들**로 변경. 기존 동작은 `/qg branch`로 사용.
- Gate 2 Phase 1 fan-out이 scout의 plan에 따라 depth별로 다름 (1 / 2 / 3 agent; 더 이상 항상 3개 아님).
- Gate 2 내부 fix-loop이 매 iteration마다 delta diff (이전 iter 이후 변경된 파일만)로 scout을 재실행.
- `total_iterations`와 `max_total_iterations`는 더 이상 `setup-qg.sh`가 작성하지 않음; `stop-hook.py`는 stale state 파일 호환을 위해 읽기만 함.
- 시스템 메시지 포맷 갱신: `iter N/M`은 Gate 2만 표시; 다른 게이트는 게이트 이름만 표시.

### Removed
- **Cross-gate restart 루프**: Gate 2 / Gate 3 `NEEDS_RESTART`가 더 이상 Gate 1으로 자동 재진입하지 않음. user-choice prompt ("변경을 적용하고 /qg 재실행")로 종료.
- `MAX_TOTAL_ITERATIONS` 상수와 `restart` transition을 `stop-hook.py`와 `setup-qg.sh` 양쪽에서 모두 제거.
- SKILL.md의 룰 기반 `SCOPE_*` env-var Phase 2 게이팅 제거 (scout의 `phase2_agents` 필드로 대체; scout 실패 시 fallback으로 레거시 코드 유지).

### Fixed
- Gate 1 plan-verifier 출력 포맷 표준화: 구조화된 `gate1_summary` YAML 블록 필수 (이전엔 자유 산문). 결정론적 Gate 2 dispatch 가능.
- Stop-hook state machine: `compute_transition`을 top-level 순수 함수로 추출 (이전엔 `main()` 안에 inline). 단위 테스트 가능.

### Security
- 모든 신규 reviewer agent (`scout`, `adversarial`, `synthesizer`)가 `disallowedTools: [Write, Edit, MultiEdit, NotebookEdit]` 선언 (Law 2 강제).

## [1.4.0] — 이전

- Gate 2 orchestration을 `quality-pipeline` skill 안으로 이동 (PR #14).

## [1.3.0] — 이전

- Stop-hook 기반 파이프라인 진행 + Gate 2 토큰 절감 (PR #12).

## 그 이전

- 초기 Stop-hook 기반 파이프라인 (PR #10), 시그널 검출 수정 (PR #11).
