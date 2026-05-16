# quality-gates worktree cwd contract — design

> **Status**: draft (Spec Author phase) — 2026-05-16
> **Plugin**: `plugins/quality-gates/` (target version: `1.13.0`)
> **Authors**: brainstorming session 2026-05-16, claude-opus-4-7
> **Related**:
> - 2026-05-14-qg-codex-reviewer-recovery-design.md (codex-reviewer agent 도입)
> - tests/test_worktree.sh (기존 worktree 동작 검증)

## 1. Context / Why

사용자가 git worktree 안에서 `/qg`를 실행하면 quality-gates pipeline이 **혼합 좌표**로 동작한다 — 일부 컴포넌트는 worktree를 보고, 일부는 main repo를 보고, codex-reviewer는 둘 다 못 보는 경우도 있다. 결과: subagent들이 "잘못된 코드를 리뷰"하는 silent 오동작. 특히 codex-reviewer는 외부 프로세스 (`codex` CLI) 라 propagation chain이 가장 깁고, 거기서 가장 자주 깨진다.

### 1.1 root cause (5개 분산 위반)

| ID | 위치 | 위반 |
|---|---|---|
| B1 | `hooks/stop-hook.py:32` | `ROOT = ".claude/quality-gates"` 상대 경로; stdin payload의 `cwd` 키 무시 |
| B2 | `hooks/post-tool-use-session-tracker.py:64` | `Path(".claude/quality-gates")` 상대 경로; payload `cwd` 무시 |
| B3 | `hooks/session-start-advisor.py:74` | `repo_root = Path.cwd()` — 워크트리 인지 없음 |
| B4 | `skills/quality-pipeline/SKILL.md` | scout/codex-reviewer/adversarial/synthesizer/test-scope-validator dispatch에 `project_dir` 미전달 (plan-verifier·runtime-verifier만 받음) |
| B5 | `agents/codex-reviewer.md:77,104` | (a) `$REPO_ROOT/plugins/quality-gates/scripts/...` → devbrew 자체 repo 외부에서는 존재하지 않는 경로 (b) bash에 `cd "$project_dir"` 없어서 cwd 비결정 |

### 1.2 가장 치명적인 경로 (codex)

```
사용자: cd ~/myapp/.claude/worktrees/feat-x && /qg
  ↓
SKILL Gate 2: Agent(codex-reviewer, prompt 안에 project_dir 없음)
  ↓
subagent runtime cwd가 worktree인지 main repo인지 보장 없음
  ↓
agent bash: git rev-parse --show-toplevel → cwd에 따라 결과 갈림
  ↓
codex exec -C "$REPO_ROOT" → main repo에서 read-only 실행
  ↓
WORKTREE의 변경사항을 못 보고 main repo의 무관한 코드 리뷰
  ↓
plus: python3 "$REPO_ROOT/plugins/quality-gates/scripts/..." 가 사용자 repo에 존재 안 함 → exit 1
```

## 2. Goals

- G1: **`project_dir` 단일 좌표 계약**을 quality-gates pipeline 전체에 강제. 한 pipeline run 동안 cwd는 SKILL preflight에서 한 번 결정되고 그 후 변경 불가.
- G2: 모든 subagent (5개) 가 `project_dir`을 **input contract**로 받고 bash 첫 줄에 `cd "$project_dir"` 실행.
- G3: 모든 hook (3개) 이 stdin payload의 `cwd`를 읽어 state 경로를 정규화. 누락 시 loud stderr 경고 + `os.getcwd()` fallback.
- G4: codex-reviewer.md의 두 path 버그 (B5) 동시 fix — `${CLAUDE_PLUGIN_ROOT}` 사용, `cd "$project_dir"` prelude.
- G5: 회귀 방지 — 새 테스트가 "subagent dispatch에 project_dir 없으면 빌드 깨짐"·"hook이 payload cwd 무시하면 깨짐"을 단정.

## 3. Non-goals

- `EnterWorktree` / `ExitWorktree` 자체 동작 변경.
- 다른 플러그인 (pr-review-toolkit, feature-dev, superpowers 등) 의 worktree 처리.
- bg job (`$CLAUDE_JOB_DIR`) 환경에서 parallel pipeline 동시 실행 시 좌표 충돌 — 별도 design (parallel-qg-isolation) 으로 분리.
- codex CLI 자체 동작 — `-C` 플래그가 codex 자신의 cwd를 보장한다고 신뢰.
- 기존 v1.12.x 사용자의 state file migration — schema 변경 없음.

## 4. Constraints

- C1: **plug-in shape 규약** (CLAUDE.md):
  - 모든 변경된 surface에 SemVer bump → `1.12.0` → `1.13.0` (minor: 새 contract).
  - `CHANGELOG.md`에 `## [1.13.0] — 2026-05-16` entry, Added/Changed/Fixed 분류.
  - README.md "Principles Instantiated"에 Law 2 (writer/reviewer 분리의 좌표 계약 측면) 한 줄 추가.
- C2: **Law 2 — Writer/Reviewer separation은 frontmatter 기반**:
  - 모든 변경된 agent (5개) 의 `disallowedTools` 그대로 유지. cwd contract 추가가 권한 늘려서는 안 됨.
- C3: **Law 3 — compounding**:
  - 본 design 파일이 `docs/superpowers/specs/`에 commit.
  - 회귀 테스트가 grep-anchored 인 prose drift 가드 (`test_codex_dispatch_invariant.sh` 패턴 따름).
- C4: **하위 호환**:
  - 사용자가 worktree 안 쓰는 경우 (대다수 use case), 모든 변경은 no-op (project_dir이 cwd와 일치).
  - 기존 worktree 안 쓰는 회귀 테스트들 (`test_worktree.sh` T1~T4) 그대로 통과.
- C5: **Trivia escape 우회 금지**: 본 diff는 8개 파일 + 신규 CHANGELOG entry → trivia 아님, 풀 pipeline 검증 필요.

## 5. Acceptance Criteria

### AC1: SKILL.md dispatch 5개 블록에 `project_dir` 명시 (Gate 2)
- scout, codex-reviewer, adversarial, synthesizer, test-scope-validator 의 dispatch 블록 (` ```Agent(...) ``` ` fenced code block) 내부 prompt 문자열에 `project_dir: <current working directory>` 라인 포함. (이미 plan-verifier 와 runtime-verifier 가 동일 형식으로 받는 패턴 따름 — SKILL.md L143, L1070 참조).
- 검증: `test_codex_dispatch_invariant.sh` 가 grep 으로 각 `subagent_type="quality-gates:<name>"` 라인부터 다음 `)` 까지의 윈도우 안에 `project_dir:` 존재 단정.

### AC2: 5개 agent.md에 `project_dir` input contract 추가
- 각 agent.md 의 "Inputs" 섹션 첫 라인에 `project_dir: project working directory (absolute path)`.
- "Forbidden" 섹션에 한 줄: "Do not re-resolve cwd (`git rev-parse`, `Path.cwd()` 금지) — use `project_dir` verbatim."

### AC3: codex-reviewer.md 의 4개 동시 fix
- bash 본문 첫 줄 (SCRATCH 생성 직전) 에 `cd "$project_dir"` 추가.
- `REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"` → `REPO_ROOT="$project_dir"`. AC10 의 `if [ -z "$REPO_ROOT" ]` empty-string 가드 블록은 **유지** (project_dir 자체가 누락되거나 비어있는 경우 동일하게 catch — `not_in_git_repo` reason 은 `missing_project_dir` 로 변경).
- `python3 "$REPO_ROOT/plugins/quality-gates/scripts/build_codex_prompt.py"` → `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py"`.
- `python3 "$REPO_ROOT/plugins/quality-gates/scripts/codex_findings_to_yaml.py"` → `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py"`.
- codex CLI 의 `-C "$REPO_ROOT"` 플래그는 그대로 유지 (REPO_ROOT 값만 project_dir 로 바뀜).
- 검증: `test_worktree.sh` 신규 T7 — `grep -q '\$REPO_ROOT/plugins/quality-gates' agents/codex-reviewer.md` 결과 0건 (negative grep, exit 1 시 PASS).

### AC4: 3개 hook 의 payload `cwd` 사용
- `stop-hook.py:main()`: `hook_input["cwd"]` 읽고 `STATE_ROOT = Path(hook_input.get("cwd") or os.getcwd()) / ".claude/quality-gates"`. payload 키 누락 시 `print("[quality-gates] stop-hook payload missing 'cwd'; falling back to process cwd", file=sys.stderr)`.
- `post-tool-use-session-tracker.py`: `Path(payload.get("cwd") or os.getcwd()) / ".claude/quality-gates" / session_id / "files.md"`.
- `session-start-advisor.py`: `repo_root = Path(payload.get("cwd") or os.getcwd())` (이미 payload 읽고 있으므로 한 줄 변경).
- **out of scope for AC4**: `post-tool-use.py` (Bash matcher) 는 이미 line 58 에서 `input_data.get("cwd", os.getcwd())` 사용 중 — fix 불필요, 회귀만 보장 (`session-end-cleanup.py` 도 동일하게 이미 payload-aware).
- 검증: 신규 unit test `test_hook_cwd_contract.py` — 3개 hook 각각에 payload `{cwd: /tmp/foo}` 주입하면 `/tmp/foo/.claude/quality-gates/...` 경로로 읽기/쓰기 수행하는지 단정. 추가로 negative case — payload 에 `cwd` 키 없으면 stderr 에 fallback 경고 라인 emit 단정.

### AC5: 회귀 테스트 통과
- 기존 `test_worktree.sh` T1~T4 그대로 PASS.
- 신규 시나리오 T5~T7 PASS:
  - T5: SKILL.md prose 에서 scout/codex-reviewer/adversarial/synthesizer/test-scope-validator dispatch 블록 각각이 같은 블록 내에 `project_dir:` 포함.
  - T6: stop-hook.py, post-tool-use-session-tracker.py, session-start-advisor.py 가 stdin payload 의 `cwd` 키를 읽음 (`grep -q 'payload.*cwd\|hook_input.*cwd'`).
  - T7: codex-reviewer.md 본문에 `$REPO_ROOT/plugins/quality-gates` 문자열 존재하지 않음.

### AC6: plugin.json + CHANGELOG bump
- `plugin.json` version `1.12.0` → `1.13.0`.
- CHANGELOG.md 상단에 새 entry `## [1.13.0] — 2026-05-16`, sections: Fixed (B1~B5 명시), Changed (project_dir contract 보편화), Added (test_hook_cwd_contract.py).

### AC7: Manual e2e (개발자 확인, CI 아님)
- 임의 repo에서 `git worktree add ../wt-test feature-x && cd ../wt-test && touch foo.py && /qg gate2` 실행 시:
  - codex-reviewer 가 worktree 의 `foo.py` 를 인식 (codex JSONL 출력에 `foo.py` 언급).
  - state file 이 `<worktree>/.claude/quality-gates/<sid>/` 에 생성 (main repo 에는 생성 안 됨).
  - hook stderr 에 "missing 'cwd'" 경고 없음.

## 6. Files to Modify

| Path | Change kind | LoC delta (approx) |
|---|---|---|
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 5개 dispatch 블록 prompt 추가 | +5 |
| `plugins/quality-gates/agents/scout.md` | Inputs/Forbidden 추가 | +4 |
| `plugins/quality-gates/agents/codex-reviewer.md` | Inputs/Forbidden + bash 4개 fix | +6, -2 |
| `plugins/quality-gates/agents/adversarial.md` | Inputs/Forbidden 추가 | +4 |
| `plugins/quality-gates/agents/synthesizer.md` | Inputs/Forbidden 추가 | +4 |
| `plugins/quality-gates/agents/test-scope-validator.md` | Inputs/Forbidden 추가 | +4 |
| `plugins/quality-gates/hooks/stop-hook.py` | `ROOT` → 함수형 helper, payload 기반 | +8, -2 |
| `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` | `Path()` 한 줄 정규화 | +3, -1 |
| `plugins/quality-gates/hooks/session-start-advisor.py` | `Path.cwd()` → payload | +3, -1 |
| `plugins/quality-gates/tests/test_worktree.sh` | T5~T7 추가 | +35 |
| `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` | project_dir 단정 추가 | +6 |
| `plugins/quality-gates/tests/test_hook_cwd_contract.py` | 신규 unit test | +60 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | version bump | ±1 |
| `plugins/quality-gates/CHANGELOG.md` | `## [1.13.0]` entry | +18 |
| `plugins/quality-gates/README.md` | "Principles Instantiated" 한 줄 보강 (선택) | +1 |

Total ≈ +172 LoC, -6 LoC.

## 7. Verification Plan

### 7.1 Local
- `bash plugins/quality-gates/tests/test_worktree.sh` → T1~T7 모두 PASS.
- `bash plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` → 4 scenarios (기존 3 + 신규 1) PASS.
- `python3 plugins/quality-gates/tests/test_hook_cwd_contract.py` → 3 hook 모두 PASS.
- `bash plugins/quality-gates/tests/test_setup_qg.sh`, `test_session_end_cleanup.py` 등 기존 hook 테스트들 PASS (regression).

### 7.2 Manual e2e (AC7)
1. 빈 repo 생성, `git worktree add ../wt feat-x`.
2. `cd ../wt && echo 'x = 1' > foo.py && git add . && /qg gate1` → plan SKIP (no plan), state 가 `../wt/.claude/quality-gates/<sid>/` 에 생성.
3. `/qg gate2` → codex-reviewer dispatch 시 prompt 에 `project_dir: <wt absolute path>` 포함 확인 (transcript inspection).
4. main repo `.claude/quality-gates/` 미생성 확인.

### 7.3 PR gate
- 모든 변경 surface 의 SemVer bump 확인 (`1.13.0`).
- CHANGELOG entry 가 Added/Changed/Fixed 사용.
- README "Principles Instantiated" 가 변경 시 commit 동일.

## 8. Rejected Alternatives

- **(B) `CLAUDE_PROJECT_DIR` env 주입**: SessionStart hook 의 env export 는 parent process 에 안 가고, subagent/codex 도 별도 프로세스이므로 보장 불가. 보조 수단으로도 가치 낮음.
- **(C) worktree 에서 qg 실행 차단**: devbrew 가 worktree 워크플로를 권장하는 정책과 충돌. fail-fast 가 안전하긴 하나 정상 use case 차단.
- **agent 본문에 `git rev-parse --show-toplevel` 유지하면서 SKILL 만 fix**: subagent runtime cwd 전파가 보장되지 않으면 동일 버그 재발. 인프라 fix 가 아닌 부분 패치.
- **project_dir 누락 시 silent fallback `pwd`**: silent 실패가 더 위험. agent 는 `{error: missing_project_dir}` 명시적 에러로 처리, hook 만 loud stderr fallback (hook 은 죽으면 안 됨).

## 9. Edge cases (out of acceptance criteria, but noted)

- **bg job + worktree**: `$CLAUDE_JOB_DIR` 가 `/tmp/...` 이고 사용자가 worktree 안의 코드를 검증하려는 경우. 현재 design 에서는 SKILL cwd 가 worktree 면 정상 동작. 별도 design 으로 분리.
- **symlinked worktree**: macOS `/var/folders/...` vs `/private/var/folders/...` 같은 symlink 이슈. `Path(...).resolve()` 호출은 본 fix 의 범위 밖 (기존 동작 유지).
- **parallel qg 동시 실행 (다른 worktree에서)**: session_id 가 다르므로 state file 충돌 없음. 다만 codex-cost-consent marker (`${HOME}/.claude/quality-gates/codex-cost-consent.md`) 는 전역이라 무관.
- **pipeline mid-run에 사용자가 cwd 변경**: SKILL preflight 시점 `pwd` 가 단일 좌표로 frozen — mid-run cwd 변경은 무시. 이미 Forbidden 으로 처리.

## 10. Metadata

- **Status**: draft (Spec Author phase)
- **Estimated implementation time**: 3~4 hours (코드 + 테스트 + CHANGELOG)
- **Risk level**: low (대다수 사용자에게 no-op; worktree 사용자에게 fix)
- **Plugin version target**: `quality-gates 1.13.0`
- **Dependencies**: 없음 (다른 플러그인 영향 없음)
- **Forbidden patterns invoked**: trivia-ceremony 회피 (8개 파일 + CHANGELOG → 정상 minor)
