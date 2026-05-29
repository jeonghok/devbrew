# quality-gates v1.32.3 follow-up — Design Spec

> **Status**: design (approved 2026-05-28)
> **Plugin**: `plugins/quality-gates`
> **Target version**: 1.32.2 → 1.32.3 (patch)
> **PR**: 미생성 — spec 승인 후 branch `feature/qg-v1322-followup`에서 작성
> **Prior context**: PR #71 (v1.32.0 → v1.32.2) merged 2026-05-28 (`b84b6ed`); 3 rounds of `/qg` resolved 32+ findings, 6건이 deferred됨

---

## 목차

- [§0. Context](#0-context)
- [§1. Goals](#1-goals)
- [§2. Non-goals](#2-non-goals)
- [§3. Constraints](#3-constraints)
- [§4. Per-fix specifications](#4-per-fix-specifications)
  - [§4.1 MED-1: `qg-worktree.sh` 부재 메시지 self-actionable화](#41-med-1-qg-worktreesh-부재-메시지-self-actionable화)
  - [§4.2 MED-2: pre-pipeline-check SID guard boundary tests](#42-med-2-pre-pipeline-check-sid-guard-boundary-tests)
  - [§4.3 MED-3: frontmatter 파싱 helper로 통일](#43-med-3-frontmatter-파싱-helper로-통일)
  - [§4.4 MED-4: sed pipe 제거 (error attribution 명확화)](#44-med-4-sed-pipe-제거-error-attribution-명확화)
  - [§4.5 I-C: CHANGELOG [1.32.0] body Korean-primary 변환](#45-i-c-changelog-1320-body-korean-primary-변환)
  - [§4.6 I-D: SKILL.md `allowed-tools` pipeline-order](#46-i-d-skillmd-allowed-tools-pipeline-order)
- [§5. Acceptance Criteria](#5-acceptance-criteria)
- [§6. Files to Modify](#6-files-to-modify)
- [§7. Verification Plan](#7-verification-plan)
- [§8. Rejected Alternatives](#8-rejected-alternatives)
- [§9. Metadata](#9-metadata)

---

## 0. Context

PR #71 ("AskUserQuestion-driven in-turn iteration", v1.32.0 → v1.32.2) merge 후, 3 round의 `/qg` 리뷰에서 surface된 27+ → 10 → 5 finding curve가 수렴했고, 32+건이 해결됐다. 마지막 라운드에서 5개 blocking(2 Critical + 3 Important)을 fix한 후 "Accept partial" 옵션으로 wall-clock budget을 마무리하고 merge함. 이때 deferred로 분류된 6건이 본 spec의 대상이다.

### 0.1 Handoff Context (for writing-plans / executor)

**TL;DR**: PR #71의 deferred 6건을 단일 PR(v1.32.3, patch)로 ship. 4건 mechanical + 2건 design-decided. 기존 v1.32.2 testsuite regression 0. 신규 helper 2(`read-frontmatter.py`, `check-allowed-tools-order.sh`) + 검증용 helper 1(`check-changelog-korean-primary.py`) + 신규 test 3 + 신규 fixture 1.

**Implicit context (reader assumed to know)**:
- quality-gates plugin의 v1.32.0 minimal state schema (`session_id`, `started_at`, `worktree_path?`, `gate3_max_resolutions`, `target_branch?`). 본문에서 frontmatter 파싱 helper가 다루는 *값 schema*가 이 좁은 set.
- `set -euo pipefail`이 모든 shell script에 적용됨 (기존 코드 컨벤션). 새 코드도 동일 prelude 가정.
- `CLAUDE_PLUGIN_ROOT` env가 SKILL/command에서 `${CLAUDE_PLUGIN_ROOT}/scripts/...` 형태로 사용됨 — 새 helper 호출도 동일 패턴.
- 모든 cancel-qg-core.sh의 SID 가드(`^[A-Za-z0-9_-]{8,}$`)는 보안 제어 — 임의 강도 완화 금지.

**Deferred to plan (this spec이 결정 *안 하는* 사항, plan이 채울 것)**:
- 각 fix의 commit message 본문 정확한 문구 (commit granularity는 §3 명시; per-file-group).
- `tests/fixtures/qg-worktree-fail-stub.sh` 실행 권한 부여 절차 (`chmod +x` step을 commit 단위로 배치할지).
- CHANGELOG `[1.32.3]` Added/Changed/Fixed 분류 안의 항목별 한 줄 카피.
- spec_version `1.1.0` → `1.2.0`이 round 2 흡수로 bump되어야 하는가 (메타 trace 용도).

Deferred 6건은 모두 *작은* 비기능적 개선(defense-in-depth diagnostic 강화, 테스트 커버리지 보강, 코드/문서 컨벤션):

| ID | 카테고리 | 영향 |
|---|---|---|
| MED-1 | Defense-in-depth diagnostic | `cancel-qg-core.sh` `qg-worktree.sh` 부재 메시지 self-actionable화 |
| MED-2 | Test coverage | `pre-pipeline-check.sh` SID guard boundary test 부재 |
| MED-3 | Frontmatter 파싱 | `awk -F'"'` 파싱의 embedded-quote fragility |
| MED-4 | Diagnostic accuracy | `cancel-qg-core.sh` sed pipe로 인한 error misattribution |
| I-C | Doc convention | `CHANGELOG.md [1.32.0]` 본문이 English prose (Korean-primary 위반) |
| I-D | Doc convention | `SKILL.md` `allowed-tools` 정렬 컨벤션 부재 |

## 1. Goals

1. 6개 deferred 항목을 단일 PR로 v1.32.3에 ship.
2. 기존 v1.32.2 testsuite regression 0건.
3. MED-3 해결을 통해 frontmatter 파싱이 *임의 ASCII 값*(embedded `"`/`\\`/공백 포함)에 대해 정상 동작 (현재는 우리가 통제하는 좁은 값 schema에서만 안전).
4. I-D 컨벤션을 *enforceable*하게 만듦 (manual review가 아닌 lint script로 검증).

## 2. Non-goals

- 새 surface 추가 금지: `commands/`, `hooks/`, `agents/`, `skills/` 디렉토리에 신규 파일 X (`scripts/` 디렉토리 신규 helper 2개는 예외).
- Breaking changes 금지: `plugin.json` minor/major bump X, `cancel-qg-core.sh` exit code 변경 X, state schema 필드 변경 X.
- yq / PyYAML 등 신규 외부 의존성 도입 X.
- v1.32.0 본문의 *technical 정확성*은 그대로 유지 (Korean으로 번역만; 의미/사실 변경 X).
- spec-distill 등 타 plugin 영향 X.

## 3. Constraints

- **단일 PR**: `feature/qg-v1322-followup` → `main` (GitHub Flow, merge commit).
- **버전 bump**: `plugin.json` 1.32.2 → 1.32.3 (patch). 모든 PR마다 bump 규칙 (`feedback_plugin_version_bump.md`).
- **CHANGELOG**: `[1.32.3] — 2026-05-28` 항목을 *Korean-primary*로 prepend.
- **Worktree 절대경로**: 모든 Edit/Write는 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-v1322-followup/...` 절대경로 사용 (`feedback_subagent_worktree_path_emphasis.md`).
- **테스트**: 기존 testsuite 전체 PASS + 신규 MED-2 boundary 테스트 + MED-3 helper unit 테스트.
- **Korean-primary 컨벤션** (CLAUDE.md): English는 식별자(MED-#, P#, AC#, plugin/scripts 이름), 고유명사, 원문 인용, "frontmatter" 등 자연 대응 없는 기술 용어에 한정.

## 4. Per-fix specifications

### 4.1 MED-1: `qg-worktree.sh` 부재 메시지 self-actionable화

**현재 상태** (`scripts/cancel-qg-core.sh:77-79`):
```bash
else
  echo "cancel-qg-core: qg-worktree.sh missing or not executable at $script_dir — worktree at $worktree_path not removed; clean it manually" >&2
fi
```

문제: "clean it manually"이 actionable하지 않음. 사용자가 정확히 어떤 명령을 실행해야 하는지 알 수 없음. 또한 "missing" vs "not executable"이 구분되지 않아 fix 방법이 다른데도 메시지가 동일.

**fix**:
```bash
else
  if [[ ! -e "$script_dir/qg-worktree.sh" ]]; then
    echo "cancel-qg-core: qg-worktree.sh MISSING at $script_dir/" >&2
  else
    echo "cancel-qg-core: qg-worktree.sh EXISTS but not executable at $script_dir/qg-worktree.sh (mode: $(stat -f %Lp "$script_dir/qg-worktree.sh" 2>/dev/null || stat -c %a "$script_dir/qg-worktree.sh" 2>/dev/null))" >&2
  fi
  echo "cancel-qg-core: orphan worktree at $worktree_path — clean manually with:" >&2
  echo "  git worktree remove --force \"$worktree_path\"" >&2
fi
```

Exit code는 **0 유지** — state folder 정리는 계속 진행됨. WARN 라인은 stderr로만.

### 4.2 MED-2: pre-pipeline-check SID guard boundary tests

**현재 상태**: `pre-pipeline-check.sh:19-36`에 SID empty + pattern guard가 있으나 `tests/test_pre_pipeline_check.sh`에 boundary 케이스 검증 없음.

**fix**: `tests/test_pre_pipeline_check.sh`에 다음 4개 assertion 추가:

| Test | Input | Expected stdout | Expected exit |
|---|---|---|---|
| T-SID-empty | `CLAUDE_CODE_SESSION_ID=""` | `result: no_session_id` | 1 |
| T-SID-short | `CLAUDE_CODE_SESSION_ID="abcd123"` (7 chars) | `result: invalid_session_id` | 1 |
| T-SID-invalid-char | `CLAUDE_CODE_SESSION_ID="abc/def123"` | `result: invalid_session_id` | 1 |
| T-SID-valid | `CLAUDE_CODE_SESSION_ID="abc-def_123ABC"` (15 chars) + cwd가 git repo + state 폴더 부재 (fresh state) | `result: fresh_start` + `branch: <current>` | 0 |

T-SID-valid는 *isolation* 위해 sandbox temp dir에서 `git init` + `git commit --allow-empty -m init` 으로 minimal git repo 만든 후 실행 — 다른 guard(state file presence, branch mismatch)가 발화하지 않는 deterministic 환경. 각 invalid 케이스에서 stderr 메시지가 SID pattern guard 토큰(`fails pattern guard`)을 포함하는지 grep 확인.

### 4.3 MED-3: frontmatter 파싱 helper로 통일

**현재 상태**: 세 곳에서 동일 패턴 `awk -F'"' '/^<key>:/ {print $2; exit}'`:
- `scripts/pre-pipeline-check.sh:47` — `branch:`
- `scripts/pre-pipeline-check.sh:56` — `session_id:`
- `scripts/cancel-qg-core.sh:57` — `worktree_path:`

embedded-quote에 fragile. 실 발생 가능성은 우리가 쓰는 값 schema(`worktree_path`/`session_id`/`branch`) 한정 ≈ 0이지만, helper 추출로 single-source-of-truth 확보 + 향후 schema 확장 시 안전.

**fix**: `scripts/read-frontmatter.py` 신규 (stdlib only, YAML escape sequence 처리 포함):

```python
#!/usr/bin/env python3
"""Read a single frontmatter value from a YAML-frontmatter markdown file.

Usage: read-frontmatter.py <file> <key>
Stdout: value (without surrounding quotes; \\" / \\\\ escape 해제), 또는
        key 부재 시 빈 줄.
Exit: 0 on success (key 부재도 success), 1 on file/parse error.
"""
import re, sys
from pathlib import Path

if len(sys.argv) != 3:
    print("usage: read-frontmatter.py <file> <key>", file=sys.stderr)
    sys.exit(1)

path, key = Path(sys.argv[1]), sys.argv[2]
try:
    text = path.read_text(encoding="utf-8")
except OSError as e:
    print(f"read-frontmatter: {e}", file=sys.stderr)
    sys.exit(1)

# Frontmatter는 `---` 마커로 감싸짐. 없으면 전체 텍스트 대상.
m = re.search(r'^---\s*\n(.*?)\n---\s*\n', text, re.DOTALL)
fm = m.group(1) if m else text

# Match key: "...escaped..." (escape-aware) OR key: bare-value
# Escape-aware quoted: `[^"\\]` (일반 char) 또는 `\\.` (escape sequence) 반복.
m2 = re.search(
    rf'^{re.escape(key)}:\s*(?:"((?:[^"\\]|\\.)*)"|(.*))$',
    fm, re.MULTILINE
)
if m2:
    if m2.group(1) is not None:  # quoted form
        # Unescape minimal YAML double-quoted escape sequences (현재 schema 범위:
        # \" 와 \\ 만; \n/\t/\xXX는 지원 안 함 — 우리 frontmatter는 한 줄 값만).
        val = m2.group(1).replace('\\\\', '\x00').replace('\\"', '"').replace('\x00', '\\')
        print(val)
    else:  # bare form
        print(m2.group(2).strip())
else:
    print("")  # key 부재 — 명시적 빈 줄 (advisory 1 흡수)
```

3 call site 전환 (각 파일 상단에 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` 미정의 시 추가):
- `pre-pipeline-check.sh:47`: `last_branch="$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$BRANCH_FILE" branch 2>/dev/null || echo "")"`
- `pre-pipeline-check.sh:56`: `pipeline_session="$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$STATE_FILE" session_id 2>/dev/null)"` — helper가 `.strip()` 적용하므로 기존 `tr -d '[:space:]'` 제거 (advisory 3 흡수)
- `cancel-qg-core.sh:57`: `worktree_path="$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$target_dir/pipeline.md" worktree_path 2>/dev/null)"`

**Helper unit test** (`tests/test_read_frontmatter.sh` 신규):

| Test | Input fixture | Key | Expected stdout |
|---|---|---|---|
| T-RF-quoted | `key: "value"` | `key` | `value` |
| T-RF-unquoted | `key: value` | `key` | `value` |
| T-RF-missing | `other: foo` | `key` | (empty line) |
| T-RF-embedded-quote | `key: "val\"ue"` | `key` | `val"ue` (escape 처리됨 — MED-3 fragility 진짜 해소) |
| T-RF-embedded-backslash | `key: "a\\b"` | `key` | `a\b` (literal `\\` → `\`) |

### 4.4 MED-4: sed pipe 제거 (error attribution 명확화)

**현재 상태** (`scripts/cancel-qg-core.sh:71-76`):
```bash
if "$script_dir/qg-worktree.sh" remove "$worktree_path" 2>&1 \
    | sed 's/^/cancel-qg-core: worktree: /' >&2; then
  :
else
  echo "cancel-qg-core: worktree removal failed (continuing with state-folder cleanup)" >&2
fi
```

`set -o pipefail` (line 10)로 첫 non-zero가 propagate되지만, 만약 sed 자체가 실패하면 잘못된 메시지 출력. 그리고 `2>&1 | sed`는 stderr를 stdout으로 합쳐서 다시 stderr로 보내는 구조라 가독성 ↓.

**qg-worktree.sh 출력 계약 (preserved)**: 기존 코드(`2>&1 | sed`)와 동일하게 stdout + stderr 병합 스트림을 prefix-emit하여 stderr로 출력. qg-worktree.sh의 정상 경로 stdout이 비어있든 진단을 출력하든 *동작 변경 없음* (backward-compat 보장).

**fix**: stdout/stderr 병합 capture + `set -e` 안전 if/else 패턴 + prefix 수동:
```bash
# set -euo pipefail 활성 상태이므로 `var=$(failing_cmd)` 시 즉시 exit 위험.
# if/else 형태로 exit code를 명시 캡처해 회피 (advisory 3 흡수).
if worktree_output="$("$script_dir/qg-worktree.sh" remove "$worktree_path" 2>&1)"; then
  worktree_rc=0
else
  worktree_rc=$?
fi
if [[ -n "$worktree_output" ]]; then
  while IFS= read -r line; do
    printf 'cancel-qg-core: worktree: %s\n' "$line" >&2
  done <<< "$worktree_output"
fi
if [[ "$worktree_rc" -ne 0 ]]; then
  echo "cancel-qg-core: qg-worktree.sh remove exit code $worktree_rc (continuing with state-folder cleanup)" >&2
fi
```

이제 sed 의존 0건, exit code가 메시지에 명시됨, `set -e` 상호작용 안전.

**MED-4 검증용 fixture**: `tests/fixtures/qg-worktree-fail-stub.sh` 신규 (영구 파일, executable):
```bash
#!/usr/bin/env bash
# Stub: simulates qg-worktree.sh failure for MED-4 testing.
echo "stub: simulated worktree removal failure" >&2
exit 1
```

테스트(`tests/test_cancel_qg_med4.sh` 신규):
1. **Backup**: `mv plugins/quality-gates/scripts/qg-worktree.sh "$BACKUP"` (rename — symlink 아님, atomic on same filesystem).
2. **Install stub**: `cp tests/fixtures/qg-worktree-fail-stub.sh plugins/quality-gates/scripts/qg-worktree.sh` (copy로 영구 fixture 보존).
3. **trap EXIT 안전망**: `trap 'mv -f "$BACKUP" plugins/quality-gates/scripts/qg-worktree.sh' EXIT` — 비정상 종료 시에도 원본 자동 복원 (advisory 2 + issue 4c70bd68 흡수).
4. **호출**: `bash plugins/quality-gates/scripts/cancel-qg-core.sh --session-id test-sid-... 2>&1`.
5. **검증**: stderr에 `cancel-qg-core: worktree: stub: simulated worktree removal failure` + `cancel-qg-core: qg-worktree.sh remove exit code 1` 라인 grep.
6. **Cleanup**: trap이 처리하므로 명시 복원 step 불필요. trap 해제 후 정상 종료.

PATH 오염 없음. symlink 아닌 copy/rename 방식이라 비정상 종료 시 stale symlink 위험 0.

### 4.5 I-C: CHANGELOG [1.32.0] body Korean-primary 변환

**Scope**: `CHANGELOG.md`의 `## [1.32.0]` 섹션 내부 `### Breaking` / `### Added` / `### Changed` / `### Removed` / `### Migration` subsection 본문 모두.

**원칙**:
- *Technical 사실은 그대로*. 의미 변경 X. e.g., "Stop hook removed" → "Stop hook 제거" (의미 동일).
- English 유지 토큰: 파일 경로, 변수명, env var, `<qg-signal>`, plugin 이름, P# 식별자, 클래스/함수 이름.
- 백틱 코드 인용은 그대로.
- 영어 원문 인용(`"Stop hook handles progression"`)은 verbatim 유지.

**예시 변환**:
```
- Stop hook removed. hooks/stop-hook.py (1205 LOC, 13-transition state
  machine, wall-clock guard, no-signal counter) deleted along with
  the Stop event registration in hooks.json.
↓
- Stop hook 제거. `hooks/stop-hook.py` (1205 LOC, 13-transition state
  machine, wall-clock guard, no-signal counter)가 `hooks.json`의
  `Stop` event 등록과 함께 삭제됨.
```

다른 버전 섹션은 영향 없음.

### 4.6 I-D: SKILL.md `allowed-tools` pipeline-order

**현재 상태** (`skills/quality-pipeline/SKILL.md:12-28`): 16개 도구가 append-order로 나열됨. Preflight script와 Gate별 script와 generic CC tool이 섞여 있음.

**fix — 새 정렬**:
```yaml
allowed-tools:
  # Group 1 — Preflight scripts (실행 순서: setup → pre-check → trivia)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/pre-pipeline-check.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/check-trivia.sh:*)
  # Group 2 — Gate 2 PR review scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/scout.py:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/run_codex_reviewer.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/synthesize_findings.py:*)
  # Group 3 — Gate 3 runtime verification scripts
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect-runtime.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/detect_codex.sh:*)
  - Bash(${CLAUDE_PLUGIN_ROOT}/scripts/compute-test-scope-candidates.sh:*)
  # Group 4 — Meta (orchestration primitives)
  - Agent
  - AskUserQuestion
  # Group 5 — File operations
  - Read
  - Glob
  - Grep
  - Edit
  - Write
```

YAML comment(`#`)로 그룹 경계를 inline 문서화. (YAML 표준 comment, CC가 무시함.)

**Linter** (`scripts/check-allowed-tools-order.sh` 신규, ~80 lines):
- 입력: `skills/quality-pipeline/SKILL.md`
- **Canonical source of truth**: linter 내부에 하드코딩된 EXPECTED_ORDER 배열 (그룹별 도구 순서). SKILL.md의 `# Group N — ...` 주석은 *문서화*이지 canonical 아님 — drift 검출 시 SKILL.md를 linter에 맞춰 수정.
- 동작: frontmatter `allowed-tools` 블록 추출 → 각 항목을 linter EXPECTED_ORDER와 라인 단위 비교 → 불일치 시 diff 출력 + FAIL.
- Exit 0: PASS / Exit 1: FAIL with diagnostic ("expected at position N: X, found Y").
- 실행: manual (`bash plugins/quality-gates/scripts/check-allowed-tools-order.sh`) — CI/hook 미도입.
- 새 도구 추가 시 linter EXPECTED_ORDER 와 SKILL.md frontmatter를 같은 commit에서 함께 수정 — coupling으로 컨벤션 drift 방지.

**Linter 단위 테스트** (`tests/test_check_allowed_tools_order.sh` 신규):

| Test | SKILL.md 변경 | Expected exit |
|---|---|---|
| T-LA-canonical | 변경 없음 (현재 정렬) | 0 (PASS) |
| T-LA-within-group-swap | Group 5 안에서 `Read`와 `Glob` 위치 교환 | 1 (FAIL) — diagnostic에 `position 12: expected Read, found Glob` |
| T-LA-cross-group-move | `AskUserQuestion`을 Group 5로 이동 | 1 (FAIL) |
| T-LA-unknown-tool | 새 도구 `Notify` 추가 (linter EXPECTED_ORDER 미반영) | 1 (FAIL) — diagnostic에 `unexpected tool: Notify` |

각 test는 tempdir에 SKILL.md copy → mutation → linter 실행 → 원본 복원. 부수효과 없음.

## 5. Acceptance Criteria

| AC | 검증 |
|---|---|
| AC1 (MED-1) | **Reproducer**: tempdir에 `mkdir -p .claude/quality-gates/test-sid-12345678` + `printf '%s\n' '---' 'session_id: "test-sid-12345678"' 'started_at: "2026-05-28T00:00:00Z"' 'worktree_path: "/tmp/qg-test-wt"' '---' > .claude/quality-gates/test-sid-12345678/pipeline.md` + `mkdir -p /tmp/qg-test-wt` + `chmod -x plugins/quality-gates/scripts/qg-worktree.sh` 후 `bash plugins/quality-gates/scripts/cancel-qg-core.sh --session-id test-sid-12345678` 실행. **검증**: stderr에 `EXISTS but not executable` + `git worktree remove --force "/tmp/qg-test-wt"` 라인 포함. cleanup: `chmod +x` 복원. 별도 케이스(파일 자체 이동)로 `MISSING` 라인 grep 검증. cancel-qg-core.sh 호출 시그니처: `--session-id <id>` 또는 `CLAUDE_CODE_SESSION_ID` env fallback (기존 v1.32.2 미변경) |
| AC2 (MED-2) | `bash tests/test_pre_pipeline_check.sh` 출력에 `T-SID-empty PASS`, `T-SID-short PASS`, `T-SID-invalid-char PASS`, `T-SID-valid PASS` 모두 포함 |
| AC3 (MED-3 transition) | `scripts/read-frontmatter.py` 존재 + executable. `grep -rn "awk -F'\"'" plugins/quality-gates/scripts/` == 0 hits. 두 호출 파일(`pre-pipeline-check.sh`, `cancel-qg-core.sh`) 각각에 `SCRIPT_DIR="$(cd "$(dirname` 패턴 존재 (helper 호출 경로 확보) |
| AC4 (MED-3 unit) | `bash tests/test_read_frontmatter.sh` 모든 5 케이스 PASS — 특히 **T-RF-embedded-quote가 `val"ue` 출력**, T-RF-embedded-backslash가 `a\b` 출력 (escape 처리 정상 작동) |
| AC5 (MED-4) | `grep -c "sed" plugins/quality-gates/scripts/cancel-qg-core.sh` == 0 (변경 후 sed 호출 0건). `bash tests/test_cancel_qg_med4.sh` PASS — stub fixture 통해 `exit code 1` 라인이 stderr에 정확히 출력됨 검증 |
| AC6 (I-C) | `awk '/^## \[1\.32\.0\]/,/^## \[/' CHANGELOG.md` 본문의 모든 단락이 (a) Korean 문자 (Hangul `가-힯`) 1개 이상 포함, 또는 (b) verbatim 인용(따옴표 둘러싸인 영어), 또는 (c) 100% identifier (backtick + 백슬래시/슬래시/under/문자만)로 구성. `python3 scripts/check-changelog-korean-primary.py` (테스트용 임시 스크립트, PR 후 폐기 가능) 통해 자동 검증 — 단락 단위 deterministic 판정 |
| AC7 (I-D ordering) | SKILL.md frontmatter에 `# Group 1 — Preflight scripts` ... `# Group 5 — File operations` 5개 comment 존재. `bash scripts/check-allowed-tools-order.sh` exit 0 |
| AC8 (I-D linter unit) | `bash tests/test_check_allowed_tools_order.sh` 4개 시나리오(T-LA-canonical PASS, T-LA-within-group-swap FAIL, T-LA-cross-group-move FAIL, T-LA-unknown-tool FAIL) 모두 통과 |
| AC9 (regression) | `bash tests/test_session_start_advisor_v2.sh && bash tests/test_cancel_qg.sh && bash tests/harness/test_skill_orchestration_behavior.sh && bash tests/test_pre_pipeline_check.sh && bash tests/test_read_frontmatter.sh && bash tests/test_cancel_qg_med4.sh && bash tests/test_check_allowed_tools_order.sh` 전체 PASS |
| AC10 (version) | `plugin.json` `version` field == `"1.32.3"` |
| AC11 (changelog) | `CHANGELOG.md` 최상단 entry가 `## [1.32.3] — 2026-05-28` + Korean-primary 본문 + Added/Changed/Fixed 분류 |

## 6. Files to Modify

### Created
- `plugins/quality-gates/scripts/read-frontmatter.py` (~45 lines, escape-aware)
- `plugins/quality-gates/scripts/check-allowed-tools-order.sh` (~80 lines)
- `plugins/quality-gates/scripts/check-changelog-korean-primary.py` (~30 lines, AC6 verification helper — **영구 보존**: 향후 CHANGELOG 항목 추가 시에도 동일 컨벤션 재검증 가능. 폐기 시 AC6 재현 불가하므로 (advisory 1 흡수))
- `plugins/quality-gates/tests/test_read_frontmatter.sh` (~60 lines, 5 cases)
- `plugins/quality-gates/tests/test_check_allowed_tools_order.sh` (~70 lines, 4 scenarios)
- `plugins/quality-gates/tests/test_cancel_qg_med4.sh` (~50 lines)
- `plugins/quality-gates/tests/fixtures/qg-worktree-fail-stub.sh` (~5 lines, executable)

### Modified
- `plugins/quality-gates/scripts/cancel-qg-core.sh` (MED-1 + MED-3 + MED-4)
- `plugins/quality-gates/scripts/pre-pipeline-check.sh` (MED-3, 두 군데)
- `plugins/quality-gates/tests/test_pre_pipeline_check.sh` (MED-2, 4 assertion 추가)
- `plugins/quality-gates/skills/quality-pipeline/SKILL.md` (I-D frontmatter 재정렬)
- `plugins/quality-gates/CHANGELOG.md` (I-C [1.32.0] 본문 + [1.32.3] entry 추가)
- `plugins/quality-gates/.claude-plugin/plugin.json` (version 1.32.2 → 1.32.3)

### Not Modified
- 모든 commands/, hooks/, agents/ 파일
- 다른 plugins/* 디렉토리
- docs/philosophy/, CLAUDE.md
- 기존 `tests/` 다른 파일들 (regression-only)

## 7. Verification Plan

**Per-fix verification** (각 step은 *재현 가능* + AC와 1:1 매핑):

1. **MED-1** (AC1): `chmod -x plugins/quality-gates/scripts/qg-worktree.sh` 후 `bash plugins/quality-gates/scripts/cancel-qg-core.sh` 직접 호출 → stderr에 `EXISTS but not executable` + `git worktree remove --force` 라인 포함 grep. 복원 (`chmod +x`) 후 정상 path 재확인. (대안: 임시 디렉토리로 `qg-worktree.sh` 이동 후 호출 → `MISSING` 라인 grep.)
2. **MED-2** (AC2): `bash plugins/quality-gates/tests/test_pre_pipeline_check.sh` 실행, 4 boundary 케이스 PASS. T-SID-valid는 test 내부에서 sandbox `git init` 후 실행하므로 deterministic.
3. **MED-3 transition** (AC3): `bash plugins/quality-gates/tests/test_read_frontmatter.sh` PASS (5 cases). `grep -rn "awk -F'\"'" plugins/quality-gates/scripts/` 0 hits. `grep -c "SCRIPT_DIR=" plugins/quality-gates/scripts/pre-pipeline-check.sh plugins/quality-gates/scripts/cancel-qg-core.sh` 각각 ≥ 1.
4. **MED-3 escape** (AC4): T-RF-embedded-quote의 stdout이 정확히 `val"ue` (5 chars); T-RF-embedded-backslash의 stdout이 정확히 `a\b` (3 chars).
5. **MED-4** (AC5): `bash plugins/quality-gates/tests/test_cancel_qg_med4.sh` PASS — mv backup + cp stub + `trap '...' EXIT` 자동 복원 패턴(§4.4 참조)으로 `cancel-qg-core.sh` 호출 → stderr에 `exit code 1` 라인 grep. `grep -c "sed" cancel-qg-core.sh` == 0.
6. **I-C** (AC6): `python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py CHANGELOG.md` exit 0 — 단락 단위로 Hangul 또는 verbatim quote 또는 100% identifier 검증.
7. **I-D** (AC7+AC8): `bash plugins/quality-gates/scripts/check-allowed-tools-order.sh` exit 0. `bash plugins/quality-gates/tests/test_check_allowed_tools_order.sh` 4개 시나리오 모두 expected 결과.

**Regression** (AC9):
- `bash plugins/quality-gates/tests/test_session_start_advisor_v2.sh` PASS (v1.32.2 V8a-d 무결성)
- `bash plugins/quality-gates/tests/test_cancel_qg.sh` PASS (기존 cancel 경로)
- `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` PASS (V2/V7 protocol-shape)

**Final integration** (필수, *not* 선택): `/qg --paths plugins/quality-gates/` 실행. 변경량 ~210 LOC + 신규 7 파일이므로 trivia escape 자격 미달. Gate 1 (plan-verifier), Gate 2 (PR review), Gate 3 (runtime verify) 모두 통과 후에야 PR 생성. trivia escape 발화 시 (예상 외) `--no-trivia` flag로 강제 실행.

## 8. Rejected Alternatives

- **yq 의존성 도입 (MED-3)**: 좁은 frontmatter schema(`key: "value"` 한 줄)에 yq 풀세트는 overkill. 설치 보장도 불확실 (homebrew/apt 환경 차이).
- **bash regex helper (MED-3)**: `[[ $line =~ ^key:\ \"([^\"]*)\" ]]`로 가능하나 embedded `"` 동일 fragility — python3 도입의 정당성 약화. 사용자 결정: Python3.
- **awk 유지 + limitation 문서화 (MED-3)**: round-1 review에서 reviewer가 "helper 도입 목적이 fragility 해소인데 limitation으로 문서화하면 자기모순"이라 지적. *Rejected* — 진짜 escape-aware 정규식으로 처리하여 MED-3 본래 목적 달성 (T-RF-embedded-quote가 `val"ue`를 정상 반환). 추후 escape sequence(`\n`, `\xXX`)가 필요해지면 PyYAML safe_load로 추가 escalation 가능.
- **MED-1 exit code 3 (orphan warning)**: 기존 caller(`commands/cancel-qg.md`) 변경 필요. scope creep. exit 0 + loud stderr advisory로 충분.
- **CHANGELOG 다른 버전(`[1.32.1]`, `[1.32.2]`) Korean 변환**: 이미 Korean-primary로 작성됨 (이번 PR #71 작업에서 일관성 확보). 본 spec scope는 [1.32.0]만.
- **I-D linter를 hooks/PostToolUse에 등록**: 매 SKILL.md edit마다 자동 실행되면 좋겠으나, 다른 plugin SKILL.md에 false positive 발생 가능 (다른 plugin의 컨벤션과 충돌). 본 PR scope는 manual linter만.
- **SKILL.md allowed-tools 단일 alphabetical**: enforcement는 쉽지만 pipeline-order 가독성 손실. 사용자 결정: pipeline-order grouping.
- **linter canonical을 SKILL.md 주석에서 파싱 (I-D)**: round-1 review에서 reviewer가 "linter 하드코딩과 SKILL.md 주석이 독립 표현되면 SSoT 위반" 지적. linter 하드코딩 EXPECTED_ORDER를 canonical로 채택, SKILL.md 주석은 문서화 — drift 시 SKILL.md를 linter에 맞춤. SKILL.md 주석을 canonical로 했을 때 linter가 자기 자신을 검증해야 하는 부트스트랩 문제 회피.

## 9. Metadata

| Field | Value |
|---|---|
| spec_version | 1.2.0 (round-1 + round-2 review fixes 적용) |
| spec_path | `docs/superpowers/specs/2026-05-28-qg-v1322-followup-design.md` |
| author | Jeongho-K + Claude (Opus 4.7) |
| created | 2026-05-28 |
| target_plugin_version | `1.32.3` |
| prior_pr | `#71` (b84b6ed) |
| branch | `feature/qg-v1322-followup` |
| worktree | `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-v1322-followup` |
| execution_mode | INLINE (Subagent-driven은 fix 단위가 작아 overhead 우세) |
| commit_granularity | per-file-group (~6-8 commits 예상) |
| acceptance_count | 11 (AC1–AC11) |
| total_LOC_estimate | ~340 (신규 ~280 + 수정 ~60) |
| review_rounds | 2 (round-1: 8 issues + 3 adv 흡수; round-2: 1 block + 3 high + 3 adv 흡수) |
