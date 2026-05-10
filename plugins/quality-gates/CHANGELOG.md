# 변경 로그

`quality-gates` 플러그인의 주요 변경 사항을 기록합니다.
포맷은 [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), 버전 규칙은 [SemVer](https://semver.org/spec/v2.0.0.html)를 따릅니다.

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
