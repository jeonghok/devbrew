# Quality-Gates Per-Session State (v1.6.0)

**Status:** Draft (revised after subagent review)
**Date:** 2026-05-08
**Plugin:** `quality-gates`
**Version target:** 1.5.0 → 1.6.0

## Context / Why

`quality-gates` 플러그인의 state는 현재 `.claude/` 평면에 흩뿌려진 **5개 파일**:

- `quality-gates.local.md` — 파이프라인 진행 상태 (frontmatter에 `session_id`만 존재; 파일은 프로젝트당 하나).
- `quality-gates-session.local.md` — 편집 파일 추적기 (`session_id` 자체 부재).
- `quality-gates-branch.local.md` — 마지막 본 git branch.
- `qg-diff-cache.txt`, `qg-code-paths.tmp` — 임시 캐시.

이 5개를 다루는 진입점:
- 5개 hook (`stop`, `post-tool-use`, `post-tool-use-session-tracker`, `session-start-advisor`).
- `scripts/setup-qg.sh`, `scripts/pre-pipeline-check.sh` (skill에서 호출).
- `commands/qg.md` (`--reset` flag), `commands/cancel-qg.md`.

세 가지 버그가 관찰됨:

1. **동시 세션 corruption.** 같은 프로젝트 두 Claude Code 세션 → 5개 파일 모두 공유 → tracker/branch/cache가 두 세션 작업으로 섞임.
2. **Stale state advisor.** 세션 A가 mid-pipeline에서 닫힘 → state 파일 보존 (의도된 resume) → 새 세션 B의 `session-start-advisor.py`가 `session_id`를 검사하지 않고 advise → B 사용자에게 자기 것이 아닌 in-flight 메시지.
3. **무관한 사용자 환경에 누적.** `/qg` 한 번도 안 돌렸어도 `Edit`/`Write` 한 번이면 tracker 파일 생성 → 영구 잔류.

## Goals

- 한 프로젝트의 두 세션이 서로의 state에 절대 간섭 안 함 (writer/reader 양쪽).
- 세션 비정상 종료 후 다른 세션이 잔재 때문에 잘못된 advisor 메시지를 보지 않음.
- Dormant 세션 state는 자동 정리 (수동 cleanup 의존 제거).
- `/qg`, `/cancel-qg` 외부 인터페이스 불변. 내부 path layout만 변경.

## Non-goals

- Cross-session 협업 모드 (의도적 거절 — "완전 독립 per-session" 결정).
- `.claude/` 외부 state 이동 (P5/§4.8 정합성 우선).
- v1.5.0 이전 in-flight pipeline 자동 마이그레이션 (state는 ephemeral).
- `.ko.md` 짝 파일 갱신 (별도 폐기 PR; CLAUDE.md ".ko.md 짝 모델 폐기" 결정 따름).

## Constraints

- **P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8 (State File)**: state는 `.claude/<plugin>.local.md` 또는 namespace 하위에 거주. 이 PR에서 §4.8 본문에 *"per-session 격리가 필요하면 `.claude/<plugin>/<session-id>/...` 하위 디렉토리도 허용"* 한 줄 보강.
- **CLAUDE.md "SessionStart 훅은 read-only 조언자, 절대 mutate 안 함"**: 이 룰은 절대적 — 예외 없음. 따라서 **GC는 SessionStart 훅 안에서 실행하지 않는다**. GC trigger는 (a) `setup-qg.sh` 시작부 (자기 세션 폴더 생성 직전), (b) `/cancel-qg --gc` 명시적 사용자 요청. 두 경로 모두 read-only가 아니므로 룰 위반 없음.
- **devbrew Law 2** (Writer/Reviewer 격리): hook/script 변경이라 reviewer agent에 직접 영향 없음.
- **kill switch**: `DEVBREW_DISABLE_QUALITY_GATES=1`이 신규 SessionEnd 훅, GC 헬퍼, 모든 신규 진입점에서 즉시 no-op으로 작동해야 함.
- **Atomic write**: 기존 `tmp.rename(target)` 패턴 유지.
- **Claude Code 환경 가정**: `${CLAUDE_CODE_SESSION_ID}` env-var이 Bash 도구에서 가용하지 *않을* 수 있음(CI, 특정 wrapper) → `setup-qg.sh`에 `--session-id` 명시 인자 fallback 추가. 모든 hook은 stdin JSON `session_id`를 source of truth로 사용.

## Acceptance Criteria

1. 두 세션 동시 `Edit` 수행 시 각자 `.claude/quality-gates/<own-session>/files.md`에만 기록; 상대 파일 영향 없음 (동시성 테스트).
2. 세션 A의 `session_id`로 만들어진 폴더에 in-flight state가 있을 때, *다른* `session_id`로 시작한 세션 B의 `session-start-advisor`는 그 폴더로부터 어떤 advisor 메시지도 출력하지 않음 (자기 폴더만 advise; sibling 폴더는 silent — 의도된 trade-off, debugging은 `DEVBREW_QG_GC_VERBOSE=1`로 sibling 카운트 가시화).
3. mtime이 TTL(기본 24h, env override `DEVBREW_QG_TTL_HOURS`)보다 오래된 *타* 세션 폴더는 다음 `/qg` 또는 `/cancel-qg --gc` 시점에 GC됨. 50ms 간격 double-stat 사이 mtime 변하면 skip; 폴더 ctime이 60초 이내인 빈 폴더는 무조건 skip (grace period).
4. `setup-qg.sh`가 `${CLAUDE_CODE_SESSION_ID}` 빈 값이고 `--session-id` 인자도 없으면 명확한 에러로 거절 (자동 테스트로 검증).
5. `complete`/`abort` transition 시 `stop-hook`이 자기 세션 폴더 전체를 `rmtree`함 (단일 파일 unlink 아님).
6. 신규 `SessionEnd` 훅이 graceful close 시 자기 세션 폴더를 `rmtree` (idempotent: 이미 없으면 noop).
7. v1.5.0 환경에서 업그레이드 시 5개 flat 파일이 다음 `/qg` 첫 실행에서 삭제되고, advisor가 systemMessage 한 번 + stderr 한 줄로 사용자에게 알림.
8. `DEVBREW_DISABLE_QUALITY_GATES=1` 시 SessionEnd 훅과 `qg-gc.py` 모두 즉시 exit; GC 안 돔, rmtree 안 함 (자동 테스트로 검증).
9. `/cancel-qg --all`은 `AskUserQuestion` 게이트 + 살아있는(mtime < 1h) sibling 세션 카운트 표시 후에만 wipe.
10. `plugin.json` version `1.6.0`, `CHANGELOG.md`에 해당 엔트리, README.md의 P21 mis-citation 수정 동반.

## Files to Modify

### 변경
- `plugins/quality-gates/.claude-plugin/plugin.json` — version 1.5.0 → 1.6.0.
- `plugins/quality-gates/CHANGELOG.md` — `## [1.6.0] — 2026-05-08` 엔트리.
- `plugins/quality-gates/README.md` — Pipeline state 섹션 갱신; **Principles Instantiated의 P21 → P5/P14/§4.8로 수정** (기존 mis-citation 동시 수정, Law 3 compounding event).
- `plugins/quality-gates/scripts/setup-qg.sh` — STATE_FILE per-session 경로, `--session-id <id>` 인자 추가, env가 비고 인자도 없으면 hard fail, mkdir per-session, **GC 진입점**(자기 폴더 생성 직전 `qg-gc.py` 호출).
- `plugins/quality-gates/scripts/pre-pipeline-check.sh` — STATE_FILE/SESSION_FILE/BRANCH_FILE 모두 per-session 경로, branch-mismatch 처리는 자기 세션 폴더 안에서만.
- `plugins/quality-gates/hooks/post-tool-use.py` — 자기 세션 폴더만 검사. systemMessage가 호출하는 `setup-qg.sh`에 `--session-id <hook_session>` 명시 전달.
- `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` — STATE_FILE 경로 변경, 빈 session_id silent exit, mkdir 추가.
- `plugins/quality-gates/hooks/session-start-advisor.py` — **자기 세션 폴더만 advise** (read-only 유지). GC 호출 안 함. `DEVBREW_QG_GC_VERBOSE=1`이면 sibling 폴더 카운트만 stdout 한 줄.
- `plugins/quality-gates/hooks/stop-hook.py` — STATE_FILE 경로 변경, complete/abort 시 폴더 전체 rmtree.
- `plugins/quality-gates/hooks/hooks.json` — `SessionEnd` 이벤트 등록.
- `plugins/quality-gates/commands/qg.md` — `--reset` 동작을 per-session 폴더 wipe + legacy 5파일 unlink로 갱신; `--gc` flag 신설(`qg-gc.py` 직접 호출).
- `plugins/quality-gates/commands/cancel-qg.md` — `allowed-tools`의 하드코딩된 path 갱신 (per-session 폴더 패턴), `--gc`/`--all` flag 동작 정의 (`--all`은 active sibling 리스트 + AskUserQuestion confirm).
- `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` — 경로 예시 갱신.
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` — `pre-pipeline-check.sh` 결과 처리 부분이 새 layout 가정.
- `plugins/quality-gates/tests/test_session_tracker.py` — 경로 갱신, 동시 세션 시뮬레이션.
- `plugins/quality-gates/tests/test_session_start_advisor.py` — cross-session no-advise 케이스, 자기 세션 advise 케이스.
- `plugins/quality-gates/tests/e2e-scenarios.md` — 동시 세션, dormant GC, graceful SessionEnd, legacy migration 시나리오.
- `docs/philosophy/devbrew-harness-philosophy.md` §4.8 — per-session subdir variant 한 줄 보강.
- `CLAUDE.md` — Plugin Shape의 markdown-state 요약 bullet에 같은 보강. **Citation 수정**: 본 spec과 README가 P21로 잘못 cite했음을 학습으로 capture (compounding 트레일).

### 신규
- `plugins/quality-gates/hooks/session-end-cleanup.py` — graceful close 시 자기 세션 폴더 rmtree. kill switch 존중. ignore_errors=True. stop-hook 직후 fire 시 idempotent.
- `plugins/quality-gates/scripts/qg-gc.py` — TTL GC 헬퍼. 단일 진입점:
  - 호출자: `setup-qg.sh` (자동), `commands/qg.md --gc` (명시), `commands/cancel-qg.md --gc`/`--all` (명시).
  - **GC lock**: `.claude/quality-gates/.gc.lock`에 `fcntl.flock(LOCK_EX | LOCK_NB)`. 이미 잡혀있으면 즉시 exit (silent, 다른 인스턴스가 청소 중).
  - **세션 ID 패턴 가드**: `^[A-Za-z0-9_-]{8,}$`. 자기 세션 폴더 + lock 파일 + 패턴 미일치는 GC 대상 제외.
  - **mtime 결정 규칙**: 폴더 내 `*.md`/`*.txt`/`*.tmp` 파일들의 `st_mtime_ns` 최대값 사용; 파일 없으면 폴더 자체 `st_mtime_ns` fallback. 폴더 `st_ctime_ns`가 60초 이내인 빈 폴더는 grace period로 skip.
  - **double-stat race 가드**: snapshot1 → `time.sleep(0.05)` → snapshot2. ns 단위 비교. 변화 시 skip. fs 해상도가 1초인 환경에선 race window가 ±1s로 넓어짐 — 알려진 limitation, 24h TTL 대비 무시 가능.
  - **rename-then-rmtree 패턴**: stale 폴더를 `.claude/quality-gates/.gc-pending-<uuid>/`로 rename(POSIX atomic) 후 rmtree. 다른 인스턴스가 도중 stat해도 원래 경로엔 없음 → 일관성.
- `plugins/quality-gates/tests/test_qg_gc.py` — TTL 만기/미만기, double-stat race, 패턴 가드, 자기 세션 제외, lock 파일 contention, rename-then-rmtree, kill switch.
- `plugins/quality-gates/tests/test_session_end_cleanup.py` — rmtree 성공/이미 없음/permission error.
- `plugins/quality-gates/tests/test_setup_qg.sh` (또는 bats) — `--session-id` 인자 동작, 빈 env+빈 인자 시 hard-fail, GC trigger 호출.

### 건드리지 않음
- `plugins/quality-gates/README.ko.md`, `CHANGELOG.ko.md` — `.ko.md` 짝 폐기 결정 (CLAUDE.md line ~103).

## Architecture

### 디렉토리 레이아웃 (신규)

```
.claude/
└─ quality-gates/
   ├─ .gc.lock                       # fcntl lock for concurrent GC
   ├─ .gc-pending-<uuid>/            # transient (rename-then-rmtree 중)
   ├─ <session-id-A>/
   │  ├─ pipeline.md                 # frontmatter + body (구 quality-gates.local.md)
   │  ├─ files.md                    # 편집 파일 리스트 (구 *-session.local.md)
   │  ├─ branch.md                   # 마지막 본 branch (구 *-branch.local.md)
   │  ├─ diff-cache.txt              # (구 qg-diff-cache.txt)
   │  └─ code-paths.tmp              # (구 qg-code-paths.tmp)
   └─ <session-id-B>/
      └─ ...
```

**Invariants:**
- 세션 ID는 **경로**가 source of truth. frontmatter `session_id` 필드는 보존(디버깅+cross-check).
- 한 세션은 자기 폴더 외부를 *읽지도 쓰지도 않음*.
- 유일한 mutate 예외: `qg-gc.py`가 sibling 폴더를 GC. 단 trigger는 항상 사용자 요청(`/qg`, `/cancel-qg --gc/--all`)이며 SessionStart에서는 절대 fire하지 않음.

### Hook & Script 책임

| 진입점                                 | Trigger                       | Reads                                       | Writes/Mutates                                       | New responsibility |
|----------------------------------------|-------------------------------|---------------------------------------------|------------------------------------------------------|--------------------|
| `setup-qg.sh`                          | `/qg` 호출                    | `${CLAUDE_CODE_SESSION_ID}` 또는 `--session-id` | `<self>/pipeline.md` 생성, GC trigger             | hard fail on empty session, GC 호출 |
| `pre-pipeline-check.sh`                | SKILL.md에서 호출             | `<self>/{pipeline,branch}.md`               | `<self>/{pipeline,session,branch}.md` (mismatch 시 wipe) | 자기 폴더 안에서만 동작 |
| `post-tool-use.py`                     | `Bash` (gh pr create)         | `<self>/pipeline.md` (existence)            | systemMessage (setup-qg에 `--session-id` 전달)       | self-session scope |
| `post-tool-use-session-tracker.py`     | `Edit`/`Write`/`MultiEdit`    | `<self>/files.md`                           | `<self>/files.md`                                    | self-session scope |
| `session-start-advisor.py`             | SessionStart                  | `<self>/pipeline.md`                        | **read-only** (P5/§4.8 + CLAUDE.md 룰)               | sibling silent 또는 verbose 카운트만 |
| `stop-hook.py`                         | Stop (every turn)             | `<self>/pipeline.md`                        | `<self>/pipeline.md`, complete/abort 시 rmtree `<self>/` | path 변경, rmtree 폴더 단위 |
| **NEW** `session-end-cleanup.py`       | SessionEnd                    | (없음)                                      | rmtree `<self>/` (best-effort, idempotent)           | graceful cleanup |
| **NEW** `scripts/qg-gc.py`             | `setup-qg.sh` + `cancel-qg`   | `.claude/quality-gates/*` mtime             | rename-then-rmtree expired sibling folders           | TTL GC + lock |
| `commands/qg.md` (`--reset`/`--gc`)    | 사용자 명시                   | (cmd)                                       | 자기 폴더 wipe + legacy 5파일 unlink (`--reset`); `qg-gc.py` 호출 (`--gc`) | unified entry |
| `commands/cancel-qg.md`                | 사용자 명시                   | (cmd)                                       | 자기 폴더 wipe; `--gc` sibling sweep; `--all` confirm 후 전체 wipe | path 갱신 |

## Cleanup Strategy

### TTL & 정책
- 기본 24시간. Override: `DEVBREW_QG_TTL_HOURS=N` (양의 정수, 파싱 실패 silent fallback to 24).
- "TTL since last write" 의미. 폴더 내 파일들의 `st_mtime_ns` 최대값 기준; 파일 없으면 폴더 `st_mtime_ns` fallback.
- 60초 grace period: 폴더 `st_ctime_ns`가 60초 이내면 GC skip (방금 만들어진 빈 폴더 보호 — F3 race 방지).

### Race 가드 (3-layer)
1. **GC lock**: `fcntl.flock(LOCK_EX | LOCK_NB)` on `.gc.lock`. 잡혀있으면 즉시 silent exit (다른 인스턴스가 처리 중).
2. **double-stat 50ms**: ns 단위 비교. 변하면 skip.
3. **rename-then-rmtree**: stale 폴더를 `.gc-pending-<uuid>/`로 rename 후 rmtree. POSIX rename은 atomic이므로 partial-state 시나리오에서 다른 인스턴스의 stat이 inconsistent state를 보지 못함.

**fs 해상도 limitation**: ext3/일부 NFS는 mtime 1초 해상도 → 50ms double-stat이 항상 같은 값을 보임 → race-guard가 layer 1(lock)+layer 3(rename)에 의존. 24h TTL 대비 실질적 영향 없음. spec 본문에 이 limitation을 적시.

### 이름 패턴 가드
세션 ID 형식 정규식: `^[A-Za-z0-9_-]{8,}$`. 비매칭 폴더는 GC 대상 제외 (사용자가 디버깅용으로 만든 폴더 보호). lock 파일과 `.gc-pending-*`도 패턴 비매칭이라 자동 제외. 8자 길이는 보수적 — Claude Code session_id가 UUID 같은 형식이면 36자 → 안전.

### 실행 시점
- **`setup-qg.sh` 시작부** (`/qg` 호출 시): 자기 세션 폴더 생성 직전 `qg-gc.py`를 background nice priority로 호출. 실패해도 setup은 진행 (loud logging만).
- **`/cancel-qg --gc`** (사용자 명시): foreground.
- **SessionStart에선 절대 실행 안 함** (P5/§4.8 + CLAUDE.md 룰).
- 자기 세션 폴더는 GC 후보에서 무조건 제외.

### Logging
- 기본 silent. `DEVBREW_QG_GC_VERBOSE=1` 시 `[quality-gates] GC: removed N stale session folder(s)` stdout 한 줄.
- 실패는 stderr 한 줄 경고 후 진행. GC가 setup-qg.sh를 abort하지 않음.
- `session-start-advisor`는 verbose 모드에서 sibling 폴더 카운트만 표시 (mutate 안 함, 단순 stat count).

### `/cancel-qg` 인터랙션
- 기본: 자기 세션 폴더만 rmtree.
- `--gc`: 자기 세션 + `qg-gc.py` 즉시 호출.
- `--all`: 살아있는(mtime < 1h) sibling 폴더 카운트 표시 → `AskUserQuestion` 명시 confirm → 전체 wipe.

## Migration Path (v1.5.0 → v1.6.0)

다음 5개 flat 파일이 발견되면 다음 `/qg` 첫 실행 시점에 처리 (setup-qg.sh 시작부):

```
.claude/quality-gates.local.md
.claude/quality-gates-session.local.md
.claude/quality-gates-branch.local.md
.claude/qg-diff-cache.txt
.claude/qg-code-paths.tmp
```

처리:
1. `session-start-advisor`가 SessionStart에서 *발견 시* systemMessage 한 번 출력 (사용자에게 visible) — read-only check, mutate 안 함.
2. setup-qg.sh가 `/qg` 호출 시 unlink + stderr 한 줄 경고 출력.

systemMessage (advisor) 예시:
```
[quality-gates] Legacy v1.5.0 state files detected. They will be removed on
your next /qg invocation. If you had an in-flight pipeline, re-run it.
```

stderr (setup-qg) 예시:
```
[quality-gates] Removed 5 legacy flat state file(s) from v1.5.0.
v1.6.0 uses per-session storage at .claude/quality-gates/<session>/.
```

이유: 이전 파일의 `session_id`는 *이전* 세션 것 → 현재 세션 폴더로 옮기면 잘못된 takeover. State는 ephemeral → 손실 비용 = "/qg 재실행".

## Versioning & CHANGELOG

`plugin.json`: `1.5.0` → `1.6.0` (minor). 사용자 명령 시그니처 불변, 내부 layout만 변경.

CHANGELOG.md `## [1.6.0] — 2026-05-08`:

```
### Added
- SessionEnd hook for graceful per-session state cleanup.
- scripts/qg-gc.py: TTL-based GC helper with file lock and rename-then-rmtree.
- Env: DEVBREW_QG_TTL_HOURS (default 24), DEVBREW_QG_GC_VERBOSE (default off).
- /cancel-qg --gc and --all flags (--all requires confirm + lists active siblings).
- /qg --gc flag for explicit GC invocation.
- setup-qg.sh --session-id <id> argument (fallback when CLAUDE_CODE_SESSION_ID is unset).

### Changed
- State moved from flat .claude/quality-gates*.local.md (5 files) to per-session
  .claude/quality-gates/<session-id>/{pipeline,files,branch}.md +
  {diff-cache,code-paths} files.
- session-start-advisor.py now scopes advice to current session only;
  read-only — never mutates (per CLAUDE.md SessionStart rule).
- setup-qg.sh hard-fails if neither CLAUDE_CODE_SESSION_ID nor --session-id is provided.
- /qg --reset now wipes the current session folder + legacy v1.5.0 files.
- README "Principles Instantiated": fixed mis-citation of P21 → corrected to
  P5 (Filesystem as Memory) + P14 (State Survives Compaction) + §4.8.

### Fixed
- Concurrent sessions in the same project no longer corrupt each other's
  state (was: 5 shared files in .claude/).
- Stale state from a crashed/closed session no longer triggers misleading
  "in-flight pipeline" advice in unrelated new sessions.

### Removed
- Flat per-project state file model (.claude/quality-gates*.local.md and
  .claude/qg-*.{txt,tmp}). 5 legacy files are unlinked on first /qg
  post-upgrade with a warning.

### Migration
- Advisor surfaces a one-time systemMessage when legacy files are found.
- In-flight v1.5.0 pipelines are not automatically migrated; re-run /qg.
```

## Verification Plan

### 단위 테스트
- `tests/test_session_tracker.py` — 새 경로, 두 sid 폴더 독립성.
- `tests/test_session_start_advisor.py` — 자기 sid advise / 다른 sid silent / verbose 카운트 / mutate 안 하는지 stat-only 검증.
- `tests/test_qg_gc.py` — TTL 만기/미만기, ns mtime 비교, 60초 grace, 패턴 가드, 자기 세션 제외, lock contention (두 process가 동시 실행), rename-then-rmtree atomicity, kill switch.
- `tests/test_session_end_cleanup.py` — rmtree 성공 / 이미 없음(idempotent) / permission error / kill switch.
- **신규** `tests/test_setup_qg.sh` (bash) — `--session-id` 인자 / 빈 env+빈 인자 hard-fail / GC trigger 동작 / legacy 5파일 unlink.

### 통합 (`tests/e2e-scenarios.md` 추가)
1. **동시 세션**: 두 임시 작업트리에서 각각 setup-qg + Edit → 자기 폴더에만.
2. **Dormant GC**: 폴더 안 파일 mtime을 25h 전으로 backdate → `/qg` 호출 → 폴더 사라짐.
3. **Graceful SessionEnd**: SessionEnd 훅 트리거 → 폴더 사라짐.
4. **Legacy migration**: flat 5파일 fixture → 다음 `/qg` 호출 → 5개 모두 unlink + advisor systemMessage + setup-qg stderr.
5. **GC lock contention**: 두 프로세스가 동시에 `qg-gc.py` 실행 → 한 명만 실제 GC, 다른 명 silent exit.
6. **Kill switch**: `DEVBREW_DISABLE_QUALITY_GATES=1` → SessionEnd hook + qg-gc 모두 즉시 no-op.

### 수동 검증
- 두 터미널에서 `/qg` → 독립 진행.
- 한쪽 강제 kill → 다른 쪽 SessionStart → advisor 노이즈 없음.
- 24h+1m 후 `/qg` 재실행 → 이전 세션 폴더 GC됨.

## Rejected Alternatives

### A. `~/.claude/plugin-state/quality-gates/<project-hash>/<session>/`
거절: P5/§4.8 정합성 우선; project-hash 컨벤션 신설 비용; `.claude/`가 더 discoverable.

### B. `$TMPDIR/quality-gates/<session>/`
거절: macOS 자동 정리 시점 불확실; P5/§4.8 위반.

### C. 한 파일 통합 (`state.md` 하나에 모두)
거절: tracker가 frontmatter 건드리며 race 표면 증가; 관심사 혼합.

### D. session_id 무관 단순 TTL (자기 세션도 GC 대상)
거절: 자기 파이프라인 실수 GC 위험; "자기 세션은 항상 살아있다" invariant 가치.

### E. Aggressive GC (SessionStart에서 타 세션 모두 wipe)
거절: 살아있는 형제 세션 진행 중 파이프라인 무차별 파괴; 사용자 결정과 정면 충돌.

### F. Legacy 파일 자동 마이그레이션
거절: 이전 파일의 session_id는 이전 세션 것; 현재 세션 폴더로 옮기는 행위 의미 잘못.

### G. SessionEnd 없이 TTL만으로 cleanup
거절: graceful close 시 즉시 정리가 UX상 자연스러움; TTL은 crash fallback.

### H. GC를 SessionStart 훅 안에서 실행 (초기 안 v1.0)
거절: CLAUDE.md *"SessionStart 훅은 read-only 조언자, 절대 mutate 안 함"* 룰 직접 위반. `rmtree`는 명백한 mutation. "narrow exception" 수사로 우회 불가능 — 룰에 예외 조항 없음. 대신 GC trigger를 setup-qg.sh + 명시적 사용자 명령으로 분산.

### I. CLAUDE.md "SessionStart mutate 금지" 룰 개정
거절: 한 PR에서 (a) 룰 우회 + (b) 룰 본문 침묵의 reinterpretation은 Law 3 (compounding이 학습을 정확히 capture)와 정면 충돌. 룰 개정이 정말 필요해지면 *별도 RFC PR*에서 명시적으로 처리.

### J. setup-qg.sh가 env 없을 때 silent fallback (UUID 자체 생성)
거절: 자체 생성 UUID는 hooks의 stdin `session_id`와 매칭 안 됨 → tracker hook이 다른 폴더에 씀 → 동시성 버그 재발. 명시적 hard fail + `--session-id` 인자가 더 안전.

## Metadata

- **Author:** Jeongho-K
- **Reviewers:** TBD
- **Plan file (next step):** `docs/superpowers/plans/2026-05-08-qg-per-session-state-plan.md` (writing-plans skill 단계).
- **Linked memory:** `feedback_plugin_version_bump.md`, `feedback_devbrew_korean_primary_docs.md`, `project_github_flow.md`.
- **Related principles:** P5 (Filesystem as Memory), P14 (State Survives Compaction), P12 (Transparency of Planning), Law 2 (writer/reviewer scoping via tools), Law 3 (compounding via test additions and citation fix).
- **Subagent review trail:** Two parallel general-purpose reviewers (technical correctness + devbrew compliance) flagged 12 + 7 findings; HIGH-severity items (P21 mis-citation, SessionStart mutate-rule violation, missing 3 state files, GC race, env-var hard-fail conflict) addressed in this revision. F11 (pattern guard length 8), F12 (CHANGELOG wording), and F7 (AC #2 trade-off) also incorporated.
