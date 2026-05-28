# quality-gates v1.32.3 follow-up — Design Spec

> **Status**: design (approved 2026-05-28)
> **Plugin**: `plugins/quality-gates`
> **Target version**: 1.32.2 → 1.32.3 (patch)
> **PR**: 미생성 — spec 승인 후 branch `feature/qg-v1322-followup`에서 작성
> **Prior context**: PR #71 (v1.32.0 → v1.32.2) merged 2026-05-28 (`b84b6ed`); 3 rounds of `/qg` resolved 32+ findings, 6건이 deferred됨

---

## 0. Context

PR #71 ("AskUserQuestion-driven in-turn iteration", v1.32.0 → v1.32.2) merge 후, 3 round의 `/qg` 리뷰에서 surface된 27+ → 10 → 5 finding curve가 수렴했고, 32+건이 해결됐다. 마지막 라운드에서 5개 blocking(2 Critical + 3 Important)을 fix한 후 "Accept partial" 옵션으로 wall-clock budget을 마무리하고 merge함. 이때 deferred로 분류된 6건이 본 spec의 대상이다.

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
| T-SID-valid | `CLAUDE_CODE_SESSION_ID="abc-def_123ABC"` (15 chars) | NOT `invalid_session_id` (proceeds to branch check) | 0 (or non-zero if other guards fire) |

각 케이스에서 stderr 메시지가 SID pattern guard 토큰을 포함하는지도 확인.

### 4.3 MED-3: frontmatter 파싱 helper로 통일

**현재 상태**: 세 곳에서 동일 패턴 `awk -F'"' '/^<key>:/ {print $2; exit}'`:
- `scripts/pre-pipeline-check.sh:47` — `branch:`
- `scripts/pre-pipeline-check.sh:56` — `session_id:`
- `scripts/cancel-qg-core.sh:57` — `worktree_path:`

embedded-quote에 fragile. 실 발생 가능성은 우리가 쓰는 값 schema(`worktree_path`/`session_id`/`branch`) 한정 ≈ 0이지만, helper 추출로 single-source-of-truth 확보 + 향후 schema 확장 시 안전.

**fix**: `scripts/read-frontmatter.py` 신규 (stdlib only, regex 기반):

```python
#!/usr/bin/env python3
"""Read a single frontmatter value from a YAML-frontmatter markdown file.

Usage: read-frontmatter.py <file> <key>
Stdout: value (without surrounding quotes), or empty if missing.
Exit: 0 on success (even if key missing — value just empty), 1 on file/parse error.
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

# Match `<key>: "value"` or `<key>: value` in the first frontmatter block.
# Frontmatter is delimited by `---` markers.
m = re.search(rf'^---\s*\n(.*?)\n---\s*\n', text, re.DOTALL)
fm = m.group(1) if m else text  # tolerate no delimiters
m2 = re.search(rf'^{re.escape(key)}:\s*(?:"([^"]*)"|(.*))$', fm, re.MULTILINE)
if m2:
    print(m2.group(1) if m2.group(1) is not None else m2.group(2).strip())
```

3 call site 전환:
- `pre-pipeline-check.sh:47`: `last_branch="$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$BRANCH_FILE" branch 2>/dev/null || echo "")"`
- `pre-pipeline-check.sh:56`: `pipeline_session="$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$STATE_FILE" session_id 2>/dev/null | tr -d '[:space:]')"`
- `cancel-qg-core.sh:57`: `worktree_path="$(python3 "$SCRIPT_DIR/read-frontmatter.py" "$target_dir/pipeline.md" worktree_path 2>/dev/null)"`

(각 호출부에서 `SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` 변수가 정의되어 있다고 가정 — 없으면 추가.)

**Helper unit test** (`tests/test_read_frontmatter.sh` 신규):

| Test | Input fixture | Key | Expected stdout |
|---|---|---|---|
| T-RF-quoted | `key: "value"` | `key` | `value` |
| T-RF-unquoted | `key: value` | `key` | `value` |
| T-RF-missing | `other: foo` | `key` | (empty) |
| T-RF-embedded-quote | `key: "val\"ue"` | `key` | `val` (current limitation 문서화 — `"` 임베디드 시 첫 `"`까지만; 실 사용 값 schema에는 없음) |

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

**fix**: stdout/stderr 분리 capture, prefix 수동:
```bash
worktree_output="$("$script_dir/qg-worktree.sh" remove "$worktree_path" 2>&1)"; worktree_rc=$?
if [[ -n "$worktree_output" ]]; then
  printf '%s\n' "$worktree_output" | while IFS= read -r line; do
    printf 'cancel-qg-core: worktree: %s\n' "$line" >&2
  done
fi
if [[ "$worktree_rc" -ne 0 ]]; then
  echo "cancel-qg-core: qg-worktree.sh remove exit code $worktree_rc (continuing with state-folder cleanup)" >&2
fi
```

이제 sed 의존 0건, exit code가 메시지에 명시됨.

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

**Linter** (`scripts/check-allowed-tools-order.sh` 신규, ~60 lines):
- 입력: `skills/quality-pipeline/SKILL.md`
- 동작: frontmatter `allowed-tools` 블록 추출 → 그룹 경계(`# Group N — ...`) 검출 → 각 그룹 내부 항목이 정의된 순서와 일치하는지 확인 → 새 도구가 그룹 정의 외에 추가되면 fail.
- Exit 0: PASS / Exit 1: FAIL with diagnostic.
- 실행: manual (`bash plugins/quality-gates/scripts/check-allowed-tools-order.sh`) — CI/hook 미도입.
- 새 도구 추가 시 linter 자체와 SKILL.md 동시 수정 필요 (강제 coupling으로 컨벤션 drift 방지).

## 5. Acceptance Criteria

| AC | 검증 |
|---|---|
| AC1 (MED-1) | `cancel-qg-core.sh` 직접 실행 시 (`qg-worktree.sh` chmod -x로 simulate), stderr에 `MISSING` 또는 `EXISTS but not executable` + `git worktree remove --force "<path>"` 명령 포함 |
| AC2 (MED-2) | `bash tests/test_pre_pipeline_check.sh` 출력에 `T-SID-empty PASS`, `T-SID-short PASS`, `T-SID-invalid-char PASS`, `T-SID-valid PASS` 모두 포함 |
| AC3 (MED-3) | `scripts/read-frontmatter.py` 존재 + executable. `grep -c "awk -F'\"'" plugins/quality-gates/scripts/*.sh` == 0 |
| AC4 (MED-3 unit) | `bash tests/test_read_frontmatter.sh` 모든 4 케이스 PASS |
| AC5 (MED-4) | `grep -c "sed" plugins/quality-gates/scripts/cancel-qg-core.sh` == 0 (변경 후 sed 호출 0건). `qg-worktree.sh` 실패 시 stderr에 정확한 exit code 명시 |
| AC6 (I-C) | `awk '/^## \[1\.32\.0\]/,/^## \[/' CHANGELOG.md`의 본문에서 영어 sentence가 *원문 인용 / 식별자 / env var / 파일경로* 외에 0건. (수동 확인: 한국어 문장 비율 > 80%) |
| AC7 (I-D) | SKILL.md frontmatter에 `# Group 1 — Preflight scripts` ... `# Group 5 — File operations` 5개 comment 존재. `bash scripts/check-allowed-tools-order.sh` exit 0 |
| AC8 (regression) | `bash tests/test_session_start_advisor_v2.sh && bash tests/test_cancel_qg.sh && bash tests/harness/test_skill_orchestration_behavior.sh && bash tests/test_pre_pipeline_check.sh && bash tests/test_read_frontmatter.sh` 전체 PASS |
| AC9 (version) | `plugin.json` `version` field == `"1.32.3"` |
| AC10 (changelog) | `CHANGELOG.md` 최상단 entry가 `## [1.32.3] — 2026-05-28` + Korean-primary 본문 + Added/Changed/Fixed 분류 |

## 6. Files to Modify

### Created
- `plugins/quality-gates/scripts/read-frontmatter.py` (~35 lines)
- `plugins/quality-gates/scripts/check-allowed-tools-order.sh` (~60 lines)
- `plugins/quality-gates/tests/test_read_frontmatter.sh` (~50 lines)

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

**Per-fix verification**:
1. MED-1: `chmod -x plugins/quality-gates/scripts/qg-worktree.sh` 후 `cancel-qg-core.sh` 직접 호출, stderr 검사. 복원 후 정상 동작 검증.
2. MED-2: `bash plugins/quality-gates/tests/test_pre_pipeline_check.sh` 실행, 4 boundary 케이스 PASS 확인.
3. MED-3: `bash plugins/quality-gates/tests/test_read_frontmatter.sh` PASS. `grep -rn "awk -F'\"'" plugins/quality-gates/scripts/` 0 hits.
4. MED-4: `cancel-qg-core.sh`에서 `qg-worktree.sh` 강제 실패 fixture(스크립트가 exit 1 echo only) 만들어 호출 → stderr에 `exit code 1` 라인 포함 검증.
5. I-C: `CHANGELOG.md` [1.32.0] section diff review.
6. I-D: `bash plugins/quality-gates/scripts/check-allowed-tools-order.sh` PASS. 무작위로 한 줄 swap 후 FAIL 확인.

**Regression**:
- `bash plugins/quality-gates/tests/test_session_start_advisor_v2.sh` PASS
- `bash plugins/quality-gates/tests/test_cancel_qg.sh` PASS
- `bash plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` PASS

**Final integration**: `/qg --paths plugins/quality-gates/` 실행 (선택적; trivia escape 가능성 있음, 변경량 ~150 LOC이라 trivia 아닐 가능성 큼). PR 전 manual review.

## 8. Rejected Alternatives

- **yq 의존성 도입 (MED-3)**: 좁은 frontmatter schema(`key: "value"` 한 줄)에 yq 풀세트는 overkill. 설치 보장도 불확실 (homebrew/apt 환경 차이).
- **bash regex helper (MED-3)**: `[[ $line =~ ^key:\ \"([^\"]*)\" ]]`로 가능하나 embedded `"` 동일 fragility — python3 도입의 정당성 약화. 사용자 결정: Python3.
- **MED-1 exit code 3 (orphan warning)**: 기존 caller(`commands/cancel-qg.md`) 변경 필요. scope creep. exit 0 + loud stderr advisory로 충분.
- **CHANGELOG 다른 버전(`[1.32.1]`, `[1.32.2]`) Korean 변환**: 이미 Korean-primary로 작성됨 (이번 PR #71 작업에서 일관성 확보). 본 spec scope는 [1.32.0]만.
- **I-D linter를 hooks/PostToolUse에 등록**: 매 SKILL.md edit마다 자동 실행되면 좋겠으나, 다른 plugin SKILL.md에 false positive 발생 가능 (다른 plugin의 컨벤션과 충돌). 본 PR scope는 manual linter만.
- **SKILL.md allowed-tools 단일 alphabetical**: enforcement는 쉽지만 pipeline-order 가독성 손실. 사용자 결정: pipeline-order grouping.

## 9. Metadata

| Field | Value |
|---|---|
| spec_version | 1.0.0 |
| spec_path | `docs/superpowers/specs/2026-05-28-qg-v1322-followup-design.md` |
| author | Jeongho-K + Claude (Opus 4.7) |
| created | 2026-05-28 |
| target_plugin_version | `1.32.3` |
| prior_pr | `#71` (b84b6ed) |
| branch | `feature/qg-v1322-followup` |
| worktree | `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature-qg-v1322-followup` |
| execution_mode | INLINE (Subagent-driven은 fix 단위가 작아 overhead 우세) |
| commit_granularity | per-file-group (~5-6 commits 예상) |
| acceptance_count | 10 (AC1–AC10) |
| total_LOC_estimate | ~180 (신규 ~145 + 수정 ~35) |
