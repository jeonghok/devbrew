# Quality-Gates Per-Session State (v1.6.0)

**Status:** Draft
**Date:** 2026-05-08
**Plugin:** `quality-gates`
**Version target:** 1.5.0 → 1.6.0

## Context / Why

`quality-gates` 플러그인의 state 파일은 현재 두 개:

- `.claude/quality-gates.local.md` — 파이프라인 진행 상태. frontmatter에 `session_id` 필드는 있지만 파일 자체는 프로젝트당 하나.
- `.claude/quality-gates-session.local.md` — `Edit`/`Write`/`MultiEdit`로 편집된 절대 경로 누적 추적기. `session_id` 필드 자체가 없음.

이 구조에서 세 가지 버그가 관찰됨:

1. **동시 세션 corruption.** 같은 프로젝트에서 두 Claude Code 세션이 동시에 떠 있으면 `quality-gates-session.local.md`에 두 세션의 편집 경로가 섞여서 누적됨. 한쪽이 `/qg`를 돌릴 때 scope에 다른 세션의 편집이 묻어 들어감.
2. **Stale state advisor.** 세션 A가 mid-pipeline 상태에서 닫히면 `quality-gates.local.md`이 보존됨 (의도된 resume 메커니즘). 새로 띄운 세션 B의 `session-start-advisor.py`는 `session_id`를 검사하지 않고 무조건 advise하므로, B 사용자에게 자기 것이 아닌 in-flight pipeline 메시지를 보여줌.
3. **무관한 사용자 환경에 누적.** 사용자가 `/qg`를 한 번도 안 돌렸어도 `Edit`/`Write` 한 번 발생하면 session-tracker 파일이 생성되어 영구 잔류.

## Goals

- 한 프로젝트에 떠 있는 두 세션이 서로의 state에 절대 간섭하지 않는다 (writer/reader 양쪽 모두).
- 세션이 비정상 종료되어도 다른 세션이 그 잔재 때문에 잘못된 advisor 메시지를 보지 않는다.
- Dormant 세션의 state는 자동으로 정리된다 (수동 cleanup 의존 제거).
- 사용자 명령(`/qg`, `/cancel-qg`)의 외부 인터페이스는 불변. 내부 path layout만 변경.

## Non-goals

- Cross-session 협업 모드 (예: 한 파이프라인을 두 세션이 함께 실행). 명시적으로 거절 — "완전 독립 per-session" 결정.
- `.claude/` 외부로의 state 이동 (`~/.claude/...`나 `$TMPDIR`). devbrew P21 정합성 유지가 우선.
- v1.5.0 이전 in-flight pipeline의 자동 마이그레이션. flat 파일 발견 시 한 줄 경고 후 삭제.
- `.ko.md` 짝 파일 갱신. 별도 폐기 PR에서 제거 (memory 결정).

## Constraints

- **devbrew P21**: state는 `.claude/<plugin>.local.md` 또는 그 namespace 하위에 존재해야 함. 이 PR에서 P21 본문에 per-session subdir variant 한 줄 보강 동반.
- **devbrew Law 2**: writer/reviewer 격리. 이 PR은 hook/script 변경이라 reviewer 격리는 직접 영향 없음 — 단, GC가 *타* 세션 폴더를 unlink하는 행위는 SessionStart의 read-only 권고에 대한 좁은 예외 (mtime 기반 housekeeping은 mutate가 아니다).
- **kill switch**: `DEVBREW_DISABLE_QUALITY_GATES=1`이 새 hook(`SessionEnd`)에서도 존중되어야 함.
- **Claude Code 환경**: `${CLAUDE_CODE_SESSION_ID}` 환경변수는 Bash 도구에서 가용해야 하고, 모든 hook stdin JSON에 `session_id` 필드가 들어와야 함. 둘 중 하나라도 비어있으면 hard fail (setup-qg) 또는 silent exit (hooks).
- **Atomic write**: 기존 `tmp.rename(target)` 패턴 유지. 새 디렉토리 구조에서도 동일.

## Acceptance Criteria

1. 두 세션이 동시에 `Edit`을 수행해도 각자 `.claude/quality-gates/<own-session>/files.md`에만 기록되고 상대방 파일에는 영향 없음 (동시성 테스트 통과).
2. 세션 A가 `gate2_running`인 채로 닫힌 후 새 세션 B가 시작되면 B의 `session-start-advisor`는 어떤 advisor 메시지도 출력하지 않음.
3. mtime이 TTL(기본 24h, env override `DEVBREW_QG_TTL_HOURS`)보다 오래된 타 세션 폴더는 SessionStart 시 GC됨. 단 50ms 간격 double-stat 사이에 mtime이 변하면 GC skip (race 가드).
4. `setup-qg.sh`가 `${CLAUDE_CODE_SESSION_ID}` 빈 값일 때 명확한 에러로 거절.
5. `complete`/`abort` transition 시 `stop-hook`이 자기 세션 폴더 전체를 `rmtree`함 (단일 파일 unlink 아님).
6. 신규 `SessionEnd` 훅이 graceful close 시 자기 세션 폴더를 `rmtree`함.
7. v1.5.0 환경에서 업그레이드 시 flat 파일 두 개가 SessionStart 첫 실행에서 stderr 한 줄 경고와 함께 삭제됨.
8. `plugin.json` version이 `1.6.0`으로 bump되고 `CHANGELOG.md`에 해당 엔트리 추가.

## Files to Modify

### 변경
- `plugins/quality-gates/.claude-plugin/plugin.json` — version 1.5.0 → 1.6.0.
- `plugins/quality-gates/CHANGELOG.md` — `## [1.6.0] — 2026-05-08` 엔트리 추가 (Added/Changed/Fixed/Removed).
- `plugins/quality-gates/scripts/setup-qg.sh` — STATE_FILE 경로를 per-session으로, 빈 SESSION_ID hard fail, mkdir per-session 폴더.
- `plugins/quality-gates/hooks/post-tool-use.py` — 자기 세션 폴더만 검사.
- `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` — STATE_FILE 경로 변경, 빈 session_id silent exit, mkdir 추가.
- `plugins/quality-gates/hooks/session-start-advisor.py` — 자기 세션만 advise, GC 호출 추가.
- `plugins/quality-gates/hooks/stop-hook.py` — STATE_FILE 경로 변경, complete/abort 시 폴더 전체 rmtree, 기존 session_id frontmatter 검사 defense-in-depth로 유지.
- `plugins/quality-gates/hooks/hooks.json` — `SessionEnd` 이벤트 등록.
- `plugins/quality-gates/commands/cancel-qg.md` — 자기 세션 폴더만 wipe, `--gc`/`--all` flag 동작 정의 (`--all`은 confirm prompt 필수).
- `plugins/quality-gates/README.md` — Pipeline state 섹션 갱신 (per-session 디렉토리 + GC 정책 설명). Principles Instantiated의 P21 cite 유지.
- `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` — 경로 예시 갱신.
- `plugins/quality-gates/tests/test_session_tracker.py` — 경로 갱신, 동시 세션 시뮬레이션 케이스 추가.
- `plugins/quality-gates/tests/test_session_start_advisor.py` — cross-session no-advise + 자기 세션 advise 케이스 갱신.
- `plugins/quality-gates/tests/e2e-scenarios.md` — 동시 세션, dormant 세션 GC, graceful SessionEnd 시나리오 추가.
- `docs/philosophy/devbrew-harness-philosophy.md` — P21 본문에 per-session subdir variant 한 줄 보강.
- `CLAUDE.md` — plugin shape의 P21 요약 bullet에 같은 보강.

### 신규
- `plugins/quality-gates/hooks/session-end-cleanup.py` — graceful close 시 자기 세션 폴더 rmtree. kill switch 존중. ignore_errors=True.
- `plugins/quality-gates/scripts/qg-gc.py` — TTL GC 헬퍼. session-start-advisor와 cancel-qg `--gc`가 공통 호출. session_id 패턴 가드(영숫자+`-`+`_`, 길이 ≥ 8) + double-stat 50ms race 가드 + 자기 세션 제외.
- `plugins/quality-gates/tests/test_qg_gc.py` — TTL 만기/미만기, double-stat race, session_id 패턴 가드, verbose flag.
- `plugins/quality-gates/tests/test_session_end_cleanup.py` — 자기 폴더 rmtree 성공/이미 없음/permission error 경로.

### 건드리지 않음
- `plugins/quality-gates/README.ko.md`, `plugins/quality-gates/CHANGELOG.ko.md` — `.ko.md` 짝 폐기 결정. drift는 deprecation signal.

## Architecture

### 디렉토리 레이아웃 (신규)

```
.claude/
└─ quality-gates/
   ├─ <session-id-A>/
   │  ├─ pipeline.md   # 기존 quality-gates.local.md 포맷 그대로
   │  └─ files.md      # 기존 quality-gates-session.local.md 포맷 그대로
   └─ <session-id-B>/
      └─ ...
```

**Invariants:**
- 세션 ID는 **경로**가 인코딩 (frontmatter `session_id` 필드는 보존하되 cross-check + 디버깅용).
- 한 세션은 자기 폴더 외부를 읽지도 쓰지도 않음.
- 유일한 예외: SessionStart의 GC가 타 세션 폴더의 mtime을 stat하고, TTL 초과 폴더만 unlink.

### Hook 책임

| Hook                                  | Trigger                       | Reads                            | Writes                                   | New responsibility |
|---------------------------------------|-------------------------------|----------------------------------|------------------------------------------|--------------------|
| `setup-qg.sh`                         | `/qg` invocation              | `${CLAUDE_CODE_SESSION_ID}`      | `<self>/pipeline.md` (create)            | Hard fail on empty session ID |
| `post-tool-use.py`                    | `Bash` tool (gh pr create)    | `<self>/pipeline.md` (existence) | systemMessage only                       | Self-session scope |
| `post-tool-use-session-tracker.py`    | `Edit`/`Write`/`MultiEdit`    | `<self>/files.md`                | `<self>/files.md`                        | Self-session scope |
| `session-start-advisor.py`            | SessionStart                  | `<self>/pipeline.md`             | (advisor stdout)                         | Self-only advise + invoke GC |
| `stop-hook.py`                        | Stop (every assistant turn)   | `<self>/pipeline.md`             | `<self>/pipeline.md`, rmtree `<self>/` on terminal | Path change only |
| **NEW** `session-end-cleanup.py`      | SessionEnd                    | (none)                           | rmtree `<self>/` (best-effort)           | Graceful cleanup |
| **NEW** `scripts/qg-gc.py` (helper)   | called by advisor + cancel-qg | `.claude/quality-gates/*` mtime  | rmtree expired sibling folders           | TTL GC |

## Cleanup Strategy

### TTL & 정책
- 기본 24시간. Override: `DEVBREW_QG_TTL_HOURS=N` (양의 정수, 파싱 실패 시 silent fallback to 24).
- "TTL since last write": 폴더 내부의 `pipeline.md`/`files.md` 중 가장 최근 mtime 기준. 활성 파이프라인은 매 turn마다 stop-hook이 atomic rename하므로 mtime이 갱신됨 → 살아있는 세션은 GC 안전.
- `started_at` 기준 아님. 의도적 — 사용자가 24h 동안 같은 파이프라인을 dormant하게 둔 경우는 ephemeral로 간주. 더 길게 보존하려면 env override.

### Race 가드 (double-stat 50ms)
1. 후보 폴더의 가장 최근 파일 mtime 기록 (snapshot1).
2. snapshot1이 TTL보다 오래됨 → `time.sleep(0.05)` → 다시 stat (snapshot2).
3. snapshot1 == snapshot2 → dead 확정 → `shutil.rmtree(ignore_errors=True)`.
4. snapshot1 ≠ snapshot2 → live 또는 막 깨어남 → skip.

### 이름 패턴 가드
세션 ID 형식이 아닌 폴더는 GC 대상 제외. 정규식 `^[A-Za-z0-9_-]{8,}$` (보수적). 사용자가 디버깅용으로 만든 폴더 보호.

### 실행 시점
- **SessionStart hook에서만 GC.** Stop hook이나 PostToolUse에는 걸지 않음 — 매 turn GC는 비용 낭비.
- 자기 세션 폴더는 GC 후보에서 무조건 제외.

### Logging
- 기본 silent. `DEVBREW_QG_GC_VERBOSE=1` 시 stdout 한 줄 (`[quality-gates] GC: removed N stale session folder(s)`).
- 실패는 stderr 한 줄 경고 후 진행 (SessionStart는 절대 abort 안됨).

### `/cancel-qg` 인터랙션
- 기본: 자기 세션 폴더만 rmtree.
- `--gc`: 자기 세션 + 즉시 TTL sweep.
- `--all`: 모든 세션 폴더 wipe — `AskUserQuestion` confirm prompt 필수 (devbrew "risky 작업" 가드).

## Migration Path (v1.5.0 → v1.6.0)

업그레이드 후 첫 SessionStart에서 다음 두 파일이 발견되면:
- `.claude/quality-gates.local.md`
- `.claude/quality-gates-session.local.md`

처리: stderr에 한 줄 경고 출력 후 unlink.

```
[quality-gates] Removed legacy flat state file (.claude/quality-gates.local.md).
v1.6.0 uses per-session storage at .claude/quality-gates/<session>/.
If you had an in-flight pipeline, re-run /qg.
```

이유: 이전 파일의 `session_id`는 *이전* 세션 것 — 현재 세션 폴더로 옮기면 잘못된 takeover. State는 ephemeral이므로 손실 비용은 "/qg 재실행"뿐.

## Versioning & CHANGELOG

`plugin.json`: `1.5.0` → `1.6.0` (minor). 사용자 명령 시그니처 불변, 내부 path layout만 변경 → minor가 적절.

CHANGELOG.md `## [1.6.0] — 2026-05-08` 엔트리:

```
### Added
- SessionEnd hook for graceful per-session state cleanup.
- scripts/qg-gc.py helper for TTL-based garbage collection of stale session folders.
- Env vars: DEVBREW_QG_TTL_HOURS (default 24), DEVBREW_QG_GC_VERBOSE (default off).
- /cancel-qg --gc and /cancel-qg --all flags.

### Changed
- State files moved from flat .claude/quality-gates*.local.md to per-session
  .claude/quality-gates/<session-id>/{pipeline.md,files.md}.
- session-start-advisor.py now scopes advice to current session only and runs
  TTL GC on stale sibling folders.
- setup-qg.sh hard-fails if CLAUDE_CODE_SESSION_ID is empty.

### Fixed
- Concurrent sessions in the same project no longer corrupt each other's
  edited-file tracker (was: shared .claude/quality-gates-session.local.md).
- Stale state from a crashed/closed session no longer triggers misleading
  "in-flight pipeline" advice in unrelated new sessions.

### Removed
- One-time legacy file cleanup: .claude/quality-gates.local.md and
  .claude/quality-gates-session.local.md are deleted on SessionStart with a warning.
```

## Verification Plan

### 단위 테스트
- `tests/test_session_tracker.py` — `tmp_dir/.claude/quality-gates/<sid>/files.md`에 쓰는지, 다른 sid 폴더에 영향 없는지.
- `tests/test_session_start_advisor.py` — 자기 sid 폴더의 in-flight 시 advise, 다른 sid 폴더 in-flight 시 advise 안 함.
- `tests/test_qg_gc.py` — TTL 만기/미만기, double-stat에서 mtime 변하면 skip, session_id 패턴 가드, verbose 플래그, 자기 세션 제외.
- `tests/test_session_end_cleanup.py` — rmtree 성공/이미 없음/permission error.

### 통합 (e2e-scenarios.md 추가)
1. **동시 세션**: 두 임시 작업트리에서 각각 setup-qg + Edit → 각자 자기 폴더에만 기록 확인.
2. **Dormant 세션 GC**: 폴더 mtime을 25시간 전으로 backdate → SessionStart → 폴더 사라짐.
3. **Graceful SessionEnd**: 세션 활성 상태에서 SessionEnd 훅 트리거 → 폴더 사라짐.
4. **Legacy migration**: flat 파일 두 개 fixture → SessionStart → 둘 다 삭제 + 경고 출력.

### 수동 검증
- 두 터미널에서 같은 프로젝트 열고 각각 `/qg` 실행 → 각자 독립 진행 확인.
- 한쪽 강제 kill → 다른 쪽 SessionStart → advisor 노이즈 없음 확인.

## Rejected Alternatives

### A. `~/.claude/plugin-state/quality-gates/<project-hash>/<session>/`
사용자 홈으로 옮기면 gitignore 고민 제로, worktree 독립. 거절 이유:
- devbrew P21 ("`.claude/<plugin>.local.md`에 산다")와 정면 충돌.
- project-hash 계산 컨벤션 신설 비용.
- 사용자가 직접 inspect할 때 발견 어려움 (`.claude/`가 더 discoverable).

### B. `$TMPDIR/quality-gates/<session>/`
OS가 자동 정리. 거절 이유:
- macOS의 `/var/folders/...`는 자동 정리 시점 불확실. 장기 active pipeline을 OS가 임의 제거할 수 있음.
- 디버깅 시 경로 추적 어려움.
- P21 위반.

### C. 한 파일 통합 (`state.md` 하나에 frontmatter + tracked_files)
파일 수 절반, GC 단순. 거절 이유:
- session-tracker가 frontmatter를 건드려야 해서 race 표면 증가.
- 관심사 혼합 (파이프라인 진행 vs 편집 추적).
- 기존 두 파서 로직 통째로 재작성 필요.

### D. session_id 무관 단순 TTL (자기 세션도 GC 대상)
GC 로직이 더 단순. 거절 이유:
- 자기 파이프라인을 실수로 GC할 위험 (mtime이 어떤 이유로든 stale일 때).
- "자기 세션 폴더는 항상 살아있다"는 invariant가 reasoning 단순화에 더 가치 있음.

### E. Aggressive GC (SessionStart에서 타 세션 폴더 모두 wipe)
가장 단순. 거절 이유:
- 다른 터미널에서 살아있는 형제 세션의 진행 중 파이프라인을 무차별 파괴.
- 사용자 결정 ("완전 독립 per-session")과 정면 충돌.

### F. Legacy 파일 자동 마이그레이션
update path 매끄러움. 거절 이유:
- 이전 파일의 `session_id`는 이전 세션 것 — 현재 세션 폴더로 옮기는 행위가 의미상 잘못됨.
- State는 ephemeral 데이터. 손실 비용 = "/qg 재실행".

### G. SessionEnd 없이 TTL만으로 cleanup
훅 하나 줄임. 거절 이유:
- graceful close 시 즉시 정리되는 게 UX상 자연스러움 (24h 잔재 vs 즉시 사라짐).
- TTL은 crash/force-kill의 fallback이지 primary 정책이 아니어야 함.

## Metadata

- **Author:** Jeongho-K
- **Reviewers:** TBD
- **Plan file (next step):** `docs/superpowers/plans/2026-05-08-qg-per-session-state-plan.md` (writing-plans skill로 생성 예정)
- **Linked memory:** `feedback_plugin_version_bump.md`, `feedback_devbrew_korean_primary_docs.md`
- **Related principles:** P21 (markdown state in `.claude/<plugin>` namespace), P12 (kill switches), Law 3 (compounding via test additions).
