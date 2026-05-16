# qg branch worktree — 다른 브랜치를 격리된 worktree에서 검사

**Status:** Draft (2026-05-17)
**Plugin:** `quality-gates` (v1.14.0 → v1.15.0)
**Author:** jeonghokim
**Related:** `2026-05-16-qg-worktree-cwd-contract-design.md` (선행 조건)

---

## 1. Context / Why

현재 `/qg`는 **현재 체크아웃된 브랜치**만 검사합니다. `scripts/pre-pipeline-check.sh:39`에서
`git rev-parse --abbrev-ref HEAD`로 ground truth를 잡고, branch marker가 바뀌면 state를 wipe합니다.

사용자는 종종 다음과 같은 워크플로우를 원합니다.

- 동료의 PR 브랜치를 본인 작업 환경 오염 없이 qg에 태우고 싶음
- 다른 feature 브랜치를 새 세션에서 검사하면서 현재 in-flight 작업은 그대로 두고 싶음
- CI 대용으로 여러 브랜치를 순차/병렬로 qg에 통과시키고 싶음

현재 우회 방법은 (1) `git stash` → `git checkout <other>` → 새 세션 → `/qg branch` → 되돌리기.
4단계, uncommitted change 충돌 위험, branch state wipe 등 fragility가 크고 ergonomics가 나쁩니다.

**P12 (trivia escape)** 관점에서도 "다른 브랜치 검사"는 frequent enough behavior이므로
first-class surface가 정당화됩니다.

## 2. Goals

- `/qg branch <name>` 호출 시 **임시 worktree를 자동 생성**하고 그 안에서 파이프라인 실행
- 현재 작업트리는 **무손상** — 사용자가 호출 전 어떤 작업을 하고 있었든 영향 없음
- 새 surface는 **단일 surface** — `--branch` 같은 flag 추가 없이 기존 `branch` 키워드 확장
- 정상 종료 시 worktree 자동 cleanup; 비정상 종료 시 보존 + 복구 경로 출력
- kill switch (`DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1`)로 기능 차단 가능
- 기존 `/qg branch` (인자 없음) 동작 100% 보존 — 회귀 없음

## 3. Non-goals

- 여러 브랜치 **병렬** 검사: out of scope (single-session, single-pipeline 가정 유지)
- 원격 브랜치 fetch: `<name>`은 로컬에 이미 존재하는 ref여야 함. `origin/feat-x`는 `git fetch` 후 사용자가 명시 호출
- worktree 안에서 fix-loop 자동 적용: Gate 2/3 NEEDS_RESTART는 기존대로 사용자에게 위임
- "다른 브랜치 검사 결과 자동 PR 코멘트": 별도 surface

## 4. Constraints

- **devbrew Law 1**: 새 surface 도입은 기존 워크플로우를 silent하게 깨면 안 됨. `/qg branch` (인자 없음)는 동작 동일.
- **devbrew Law 2**: writer/reviewer 분리 영향 없음 — worktree는 실행 환경이지 reviewer 권한과 무관.
- **devbrew Law 3**: 새 surface는 README + CHANGELOG에 instantiated, `docs/philosophy/...` 의 §4.8 (state isolation)에 컨벤션 footnote 추가.
- **State isolation (P14)**: worktree state는 `.claude/quality-gates/worktrees/` 하위, plugin namespace 위반 없음.
- **v1.14.0 worktree cwd contract**: 모든 hook이 payload cwd 기반으로 state path를 도출하도록 이미 정리됨. 본 spec은 그 기반 위에 올림.
- **Forbidden patterns**: "trivia ceremony" 회피 — 단순 호출엔 worktree 만들지 않음 (기존 `branch` 키워드는 그대로).

## 5. Design

### 5.1 Surface

```
/qg                          # default — session-scope
/qg branch                   # 현재 브랜치 full diff (기존 동작 보존)
/qg branch <name>            # NEW — <name>을 임시 worktree로 분리 후 qg
/qg branch <name> gate2      # 게이트 지정과 조합 가능
/qg branch <name> --skip-runtime
```

argument-hint 갱신:
```
"[gate1|gate2|gate3] [branch [<name>]|--paths <glob>...|--reset] [--skip-runtime] [--plan <path>] [--pr-url <url>]"
```

**파싱 규칙** (setup-qg.sh):
- 토큰 `branch`를 만나면 **다음 토큰을 peek**
- 다음 토큰이 (a) 없거나 (b) `--`로 시작하거나 (c) `gate1`/`gate2`/`gate3` 중 하나면 → 기존 "현재 브랜치 full diff" 동작
- 그 외 → 다음 토큰을 `TARGET_BRANCH`로 consume, worktree 모드 활성화

### 5.2 Worktree 라이프사이클

**경로 규약**:
```
<repo-root>/.claude/quality-gates/worktrees/<sanitized-name>-<session-id-short>/
```
- `sanitized-name`: `/` → `-`로 치환, 그 후 `[A-Za-z0-9._-]` 외 문자가 남아 있으면 거부. `..` 토큰 또는 leading `.` 거부. 길이 64자 cap.
- `session-id-short`: `CLAUDE_CODE_SESSION_ID` 앞 8자 (충돌 방지용)

**생성**:
```bash
git worktree add --detach "$WORKTREE_PATH" "$TARGET_BRANCH"
```
- `--detach`로 detached HEAD: 사용자가 worktree 안에서 실수 commit하는 사고 방지
- 이미 존재하면 `git worktree list`로 확인 후 reuse (idempotent)

**setup-qg.sh invocation**:
- worktree 생성 후 `cd "$WORKTREE_PATH"` 한 다음 setup-qg.sh를 invoke
- setup-qg.sh는 `pwd`를 `project_dir`로 frozen → state file이 worktree 안에 살게 됨
- 이후 모든 hook과 agent dispatch는 v1.14.0 contract에 따라 그 `project_dir`을 따라감

**Cleanup 정책**:

| 종료 상태 | Cleanup 동작 |
|---|---|
| Gate 1/2/3 pass (`pipeline_done`) | 자동 `git worktree remove --force` |
| 사용자 `/cancel-qg` | 자동 `git worktree remove --force` |
| `needs_restart` (Gate 2/3 fix-loop 후 사용자 선택 대기) | **보존**, recovery 경로 stdout 출력 |
| Agent crash / 비정상 종료 | **보존** |
| `DEVBREW_QG_KEEP_WORKTREE=1` | 종료 사유 무관 항상 보존 |

Cleanup은 **Stop hook** (`hooks/stop-hook.py`)에서 terminal status (`pipeline_done`/`cancelled`) 감지 시 분기 처리.

### 5.3 Validation

- `git rev-parse --verify "$TARGET_BRANCH"` 실패 → "Branch 'X' not found. Try `git branch --all`." 출력 후 exit 2
- 이름 sanitize 실패 (`..`, NUL, 길이 초과) → "Invalid branch name for worktree path." 출력 후 exit 2
- 같은 `<sanitized-name>-<session>` worktree가 이미 존재 → reuse (idempotent), stderr에 "Reusing existing worktree at <path>" 한 줄
- worktree 경로 생성 실패 (권한/디스크) → 명확한 에러 + 부분 상태 cleanup

### 5.4 Kill switch

- `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1`:
  - `/qg branch <name>` 호출 시 즉시 거절 ("Branch worktree mode disabled via DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1") + exit 1
  - 기존 `/qg branch` (인자 없음)는 영향 없음

### 5.5 Hook 영향

- **stop-hook.py**: terminal status 감지 시 state frontmatter에 `worktree_path` 필드가 있으면 cleanup 분기 (5.2 표 참조). frontmatter에 `worktree_path` 없으면 (일반 qg 경로) no-op.
- **post-tool-use-session-tracker.py**: 사용자가 worktree에서 편집하지 않으므로 fire되지 않음 — 변경 없음.
- **session-start-advisor.py**: read-only advisor, 변경 없음.
- **session-end-cleanup.py**: `worktree_path`가 있고 `DEVBREW_QG_KEEP_WORKTREE`가 0이면 best-effort cleanup. Session 종료 시 dangling worktree 회수 안전망.

### 5.6 State 스키마 확장

`pipeline.md` frontmatter에 2개 필드 추가 (worktree 모드일 때만):
```yaml
worktree_path: "/abs/path/to/.claude/quality-gates/worktrees/feat-x-abc12345"
target_branch: "feat-x"
```
v1.14.x state file은 두 필드 없음 → stop-hook의 `parse_state_file()`은 두 필드 부재를 일반 모드로 해석 (backward-compat).

### 5.7 Compounding 산출물 (Law 3)

- `CHANGELOG.md` `## [1.15.0] — 2026-05-17` Added 항목
- `README.md` Quick Reference 표 + 신규 "Recipes — 다른 브랜치 검사" 섹션
- `docs/philosophy/devbrew-harness-philosophy.md` §4.8에 worktree 경로 컨벤션 footnote (`.claude/<plugin>/worktrees/...`)

## 6. Acceptance Criteria

**테스트 가능한 시나리오**:

- **AC1**: 기존 `/qg branch` (인자 없음) 호출이 v1.14.0과 동일하게 동작 (회귀 가드).
- **AC2**: `/qg branch <존재하는-브랜치>` 호출 시 `.claude/quality-gates/worktrees/<name>-<sid>/` 디렉토리 생성, 그 안에서 setup-qg.sh가 실행되어 `pipeline.md`의 `project_dir`이 worktree path와 일치.
- **AC3**: `/qg branch <존재하지-않는-브랜치>` → exit code 2, stderr에 "not found" 메시지.
- **AC4**: `/qg branch ../evil` → exit code 2, stderr에 "Invalid branch name" 메시지.
- **AC5**: 같은 세션에서 `/qg branch <name>` 두 번 호출 → 두 번째는 기존 worktree reuse, stderr에 "Reusing existing worktree" 메시지.
- **AC6**: `/qg branch <name>` 후 정상 통과 → Stop hook이 `git worktree remove`로 정리, 다음 `git worktree list`에 해당 path 없음.
- **AC7**: `/qg branch <name>` 후 `/cancel-qg` → worktree cleanup 동일.
- **AC8**: `/qg branch <name>` 중 Gate 2 NEEDS_RESTART → worktree 보존, stdout에 "Worktree preserved at <path> — remove manually with `git worktree remove`" 문구.
- **AC9**: `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1 /qg branch <name>` → exit 1, kill switch 메시지. 기존 `/qg branch` (인자 없음)는 영향 없음.
- **AC10**: `DEVBREW_QG_KEEP_WORKTREE=1 /qg branch <name>` 통과 → worktree 보존.
- **AC11**: 본 작업트리의 `git status`는 `/qg branch <name>` 전후로 동일 (작업트리 무손상).
- **AC12**: worktree 내부에서 시작된 파이프라인의 Gate 2가 `project_dir`을 worktree path로 인식 (`scout.md`/`security-reviewer.md` 등 6개 agent의 input contract 준수, v1.14.0 contract 위반 없음).

## 7. Files to Modify

| 파일 | 변경 유형 | 비고 |
|---|---|---|
| `plugins/quality-gates/commands/qg.md` | 수정 | argument-hint, Quick Reference 표 |
| `plugins/quality-gates/scripts/setup-qg.sh` | 수정 | `branch <name>` 파싱, worktree wrapper 호출 |
| `plugins/quality-gates/scripts/qg-worktree.sh` | 신규 | worktree 생성·sanitize·검증·cleanup 헬퍼 |
| `plugins/quality-gates/hooks/stop-hook.py` | 수정 | terminal status 분기에 worktree cleanup |
| `plugins/quality-gates/hooks/session-end-cleanup.py` | 수정 | dangling worktree 회수 safety net |
| `plugins/quality-gates/.claude-plugin/plugin.json` | 수정 | v1.14.0 → v1.15.0 |
| `plugins/quality-gates/CHANGELOG.md` | 수정 | `## [1.15.0]` Added 항목 |
| `plugins/quality-gates/README.md` | 수정 | Quick Reference + Recipes 섹션, kill switch 환경변수 |
| `plugins/quality-gates/tests/test_branch_worktree.sh` | 신규 | AC1–AC11 통합 테스트 |
| `docs/philosophy/devbrew-harness-philosophy.md` | 수정 | §4.8 worktree 경로 컨벤션 footnote |

## 8. Verification Plan

1. **단위 검증** (스크립트 레벨):
   - `qg-worktree.sh sanitize feat/x` → `feat-x` 출력
   - `qg-worktree.sh sanitize ../evil` → exit 2
   - `qg-worktree.sh create <nonexistent>` → exit 2

2. **통합 테스트** (`test_branch_worktree.sh`):
   - 임시 git repo + 두 브랜치 만들고 AC1–AC11 시나리오 자동 실행
   - 기존 `tests/test_worktree.sh`의 fixture 패턴 재사용

3. **회귀 가드**:
   - `tests/test_worktree.sh` 전체 통과 (v1.14.0 contract 유지)
   - `tests/test_hook_cwd_contract.py` 통과

4. **수동 검증**:
   - 본 repo에서 `feature/test-qg-branch` 브랜치 만들고 main에서 `/qg branch feature/test-qg-branch` 실행 → worktree 생성 확인, Gate 2 통과 후 cleanup 확인
   - kill switch 시나리오 (AC9) 1회 수동 실행

## 9. Rejected Alternatives

### 9.1 `--branch <name>` flag로 노출

거절. surface 중복 (`branch` 키워드 + `--branch` 플래그). 사용자 요청 "브랜치 키워드를 통해 자동 동작"에 위배. argument-hint도 비대해짐.

### 9.2 `--worktree <path>` 인자로 사용자가 직접 worktree 준비

거절. ergonomics 떨어짐 — 사용자가 매번 `git worktree add` 명령 외워야 함. 자동화 가치 없어짐.

### 9.3 코드 변경 없이 README Recipes만 추가

거절. 사용자가 명시적으로 "개선 진행" 요구. surface 추가가 정당화됨.

### 9.4 worktree 위치를 `/tmp` 하위에

거절. plugin namespace 컨벤션 (P14, `.claude/<plugin>/...`) 위반. cleanup이 OS 임시 디렉토리 정책에 의존하게 됨.

### 9.5 항상 cleanup (실패 케이스 포함)

거절. 비정상 종료 시 디버깅 정보 손실. P13 (loud logging graceful degradation) 정신에 부합하게 보존 + 복구 경로 출력이 안전.

## 10. Metadata

- **Plugin version target**: v1.15.0 (minor — 새 surface)
- **Backward compatibility**: 완전 보장. v1.14.x state file 그대로 읽힘. 기존 `/qg branch` 동작 무변경.
- **cost_class 영향**: worktree 생성은 1회 git checkout 비용. Gate 2/3 자체 비용은 동일.
- **kill switch**:
  - `DEVBREW_QG_DISABLE_BRANCH_WORKTREE=1` — 기능 차단
  - `DEVBREW_QG_KEEP_WORKTREE=1` — cleanup 차단
  - 기존 `DEVBREW_DISABLE_QUALITY_GATES=1` — 전체 차단 (영향 동일)
- **Principles instantiated**:
  - Law 1 (clarity): 새 surface가 명세된 acceptance criteria로 정의됨
  - Law 3 (compounding): worktree 경로 컨벤션을 philosophy doc에 박아 차후 다른 플러그인이 재사용
- **Forbidden patterns 회피**:
  - "trivia ceremony": 기존 `/qg branch` 인자 없음은 그대로
  - "subagent spray": fan-out 변화 없음
  - "unbounded autonomy": cleanup 정책에 명시적 종료 조건
