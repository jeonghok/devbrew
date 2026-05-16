# quality-gates worktree cwd contract — design

> **Status**: draft (Spec Author phase) — 2026-05-16
> **Plugin**: `plugins/quality-gates/` (target version: `1.13.0`)
> **Authors**: brainstorming session 2026-05-16, claude-opus-4-7
> **Related**:
> - 2026-05-14-qg-codex-reviewer-recovery-design.md (codex-reviewer agent 도입)
> - tests/test_worktree.sh (기존 worktree 동작 검증)

## 1. Context / Why

사용자가 git worktree 안에서 `/qg`를 실행하면 quality-gates pipeline이 **혼합 좌표**로 동작한다 — 일부 컴포넌트는 worktree를 보고, 일부는 main repo를 보고, codex-reviewer는 둘 다 못 보는 경우도 있다. 결과: subagent들이 "잘못된 코드를 리뷰"하는 silent 오동작. 특히 codex-reviewer는 외부 프로세스 (`codex` CLI) 라 propagation chain이 가장 깁고, 거기서 가장 자주 깨진다.

### 1.1 root cause (6개 분산 위반)

| ID | 위치 | 위반 |
|---|---|---|
| B1 | `hooks/stop-hook.py:32` | `ROOT = ".claude/quality-gates"` 상대 경로; stdin payload의 `cwd` 키 무시 |
| B2 | `hooks/post-tool-use-session-tracker.py:64` | `Path(".claude/quality-gates")` 상대 경로; payload `cwd` 무시 |
| B3 | `hooks/session-start-advisor.py:74` | `repo_root = Path.cwd()` — 워크트리 인지 없음 |
| B4 | `skills/quality-pipeline/SKILL.md` | scout/codex-reviewer/adversarial/synthesizer/test-scope-validator/security-reviewer dispatch에 `project_dir` 미전달 (plan-verifier·runtime-verifier만 받음) |
| B5 | `agents/codex-reviewer.md:77,104` | (a) `$REPO_ROOT/plugins/quality-gates/scripts/...` → devbrew 자체 repo 외부에서는 존재하지 않는 경로 (b) bash에 `cd "$project_dir"` 없어서 cwd 비결정 |
| **B6** | `scripts/setup-qg.sh:252-266` + `hooks/stop-hook.py:525-563` | **state file frontmatter 에 `project_dir` 필드 없음**, `build_gate_prompt()` 의 3개 gate 분기 모두 `project_dir`을 continuation prompt 에 주입 안 함 → **gate boundary 마다 G1 "단일 좌표 frozen" 보장이 깨짐**. 첫 gate dispatch 에서만 worktree 좌표를 쓰고, gate 2/3 은 SKILL preflight 의 `<cwd>` 가 새로 평가되어 hook process cwd 에 의존. (spec-reviewer round 1, Issue #2/#7) |

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

- G1: **`project_dir` 단일 좌표 계약**을 quality-gates pipeline 전체에 강제. 한 pipeline run 동안 cwd는 SKILL preflight에서 한 번 결정되고 그 후 변경 불가 — 이 보장은 gate boundary 를 넘어서도 유지된다 (G6 참조).
- G2: 모든 Phase-1·Phase-2·infrastructure subagent (6개: scout / codex-reviewer / adversarial / synthesizer / test-scope-validator / security-reviewer) 가 `project_dir`을 **input contract**로 받는다. Bash 실행을 하는 agent (codex-reviewer) 는 추가로 bash 첫 줄에 `cd "$project_dir"` 실행. LLM-only agent (나머지 5개) 는 prompt 안에서 read tool 호출 시 `project_dir` 을 절대경로 base 로 사용 (`Read("$project_dir/<relative path>")`).
- G3: 모든 hook (3개) 이 stdin payload의 `cwd`를 읽어 state 경로를 정규화. 누락 시 loud stderr 경고 + `os.getcwd()` fallback.
- G4: codex-reviewer.md의 두 path 버그 (B5) 동시 fix — `${CLAUDE_PLUGIN_ROOT}` 사용, `cd "$project_dir"` prelude, empty-project_dir 가드.
- G5: 회귀 방지 — 새 테스트가 "subagent dispatch에 project_dir 없으면 빌드 깨짐"·"hook이 payload cwd 무시하면 깨짐"·"agent.md Inputs 에 project_dir 라인 없으면 빌드 깨짐"·"state file 에 project_dir 필드 없으면 빌드 깨짐"을 단정.
- **G6**: **gate boundary cross-cutting 좌표 영속화**. setup-qg.sh 가 state file frontmatter 에 `project_dir` 필드 write, stop-hook.py:build_gate_prompt() 가 모든 gate 분기 (1/2/3) 의 continuation prompt 에 `project_dir: {stored_value}` 라인 inject. 결과적으로 gate 2/3 의 SKILL re-invocation 이 hook process cwd 에 의존하지 않음. (Issue #2/#7 의 critical gap 해소)

## 3. Non-goals

- `EnterWorktree` / `ExitWorktree` 자체 동작 변경.
- 다른 플러그인 (pr-review-toolkit, feature-dev, superpowers 등) 의 worktree 처리.
- bg job (`$CLAUDE_JOB_DIR`) 환경에서 parallel pipeline 동시 실행 시 좌표 충돌 — 별도 design (parallel-qg-isolation) 으로 분리.
- codex CLI 자체 동작 — `-C` 플래그가 codex 자신의 cwd를 보장한다고 신뢰.
- 기존 v1.12.x 사용자의 state file migration — schema 변경 없음.

## 4. Constraints

- C1: **plug-in shape 규약** (CLAUDE.md):
  - 모든 변경된 surface에 SemVer bump → `1.12.0` → `1.13.0` (minor: 새 contract + state schema field 추가).
  - `CHANGELOG.md`에 `## [1.13.0] — 2026-05-16` entry, Added/Changed/Fixed 분류.
  - README.md "Principles Instantiated"에 Law 2 (writer/reviewer 분리의 좌표 계약 측면) 한 줄 추가.
- C2: **Law 2 — Writer/Reviewer separation은 frontmatter 기반**:
  - 모든 변경된 agent (6개) 의 `disallowedTools` 그대로 유지. cwd contract 추가가 권한 늘려서는 안 됨.
- C3: **Law 3 — compounding**:
  - 본 design 파일이 `docs/superpowers/specs/`에 commit.
  - 회귀 테스트가 grep-anchored 인 prose drift 가드 (`test_codex_dispatch_invariant.sh` 패턴 따름).
- C4: **하위 호환**:
  - 사용자가 worktree 안 쓰는 경우 (대다수 use case), 모든 변경은 no-op (project_dir이 cwd와 일치).
  - 기존 worktree 안 쓰는 회귀 테스트들 (`test_worktree.sh` T1~T4) 그대로 통과.
  - **State file schema 변경 backward-compat**: 신규 `project_dir` 필드는 v1.12.x state file 에 없을 수 있음. `parse_state_file()` 에 누락 시 기본값 `os.getcwd()` + stderr 경고 (v1.7→1.8 의 `gate3_resolution_iter` 추가 패턴 따름, stop-hook.py:114-120 참조).
  - **Mid-pipeline partial-deploy window (round 2 Issue [d9c7f5e2])**: v1.12.x → v1.13.0 업그레이드 시점에 진행 중인 (gate1 완료, gate2 미시작 등) pipeline 은 stop-hook 가 새 코드로 동작하지만 SKILL.md 가 인스톨러에서 이미 새 버전 — 두 컴포넌트는 install 이 atomic 이므로 partial-deploy window 자체가 없음. 단, 사용자가 v1.12.x state file 을 들고 v1.13.0 으로 업데이트한 직후 첫 continuation 에서는 `parse_state_file()` 의 fallback 으로 `os.getcwd()` 가 쓰이고 stderr 경고가 한 번 발생 — 이 동작은 의도된 graceful degradation. CHANGELOG 의 Upgrade 노트에 "in-flight pipeline 은 `/cancel-qg && /qg` 권장" 한 줄 추가.
- C5: **Trivia escape 우회 금지**: 본 diff는 10개 파일 + 신규 테스트 1개 + CHANGELOG entry → trivia 아님, 풀 pipeline 검증 필요.
- **C6**: **Persona hardening only, no weakening**: codex-reviewer.md (및 6개 agent.md) 의 `Forbidden` 섹션 변경은 **새 규칙 추가** (hardening) 이며, 기존 규칙 제거/완화 (weakening) 아님. CLAUDE.md "Persona 파일은 보안-민감 코드" 의 보안 리뷰 트리거 (규칙 제거, 임계치 완화) 에 해당하지 않음. (Issue #9)
- **C7**: **Codex CLI `-C` flag trust boundary**: `codex exec -C "$project_dir"` 가 codex 자체의 cwd 를 강제한다고 신뢰. detect_codex.sh 의 version 가드 (이미 `known_bad_version` skip_reason 처리 있음) 가 이 보장의 단일 fail-safe. 본 spec 은 codex CLI 자체 동작을 변경하지 않음. (Issue #10)

## 5. Acceptance Criteria

### AC1: SKILL.md dispatch 6개 블록에 `project_dir` 명시 (Gate 2)
**Scope clarification (round 2 Issue [7a3f2c1d])**: 6개 list 는 dispatch contract 일관성 차원에서 **모두 포함**. scout / adversarial / synthesizer / test-scope-validator 가 직접 cwd-sensitive bash 를 실행하지 않더라도, agent body 에서 Read 호출 시 worktree-relative path 를 base 로 쓰기 위해 `project_dir` input 이 필요 (G2 의 "Read tool 호출 시 `project_dir` 을 절대경로 base 로 사용" 정합). cwd-insensitive 라는 이유로 일부 agent 만 빼는 partial coverage 는 같은 버그 재발 위험 — 그래서 6개 전체.

**Dispatch 패턴 두 가지 (round 2 Issue [b4e91a2f])**: SKILL.md 는 두 dispatch 패턴 동시 사용:
- **Pattern P (primary)**: ` ```Agent( subagent_type="quality-gates:<name>", ...) ``` ` fenced code block 형태. plan-verifier (L139), runtime-verifier (L1066), scout (L445), adversarial (L669), synthesizer (L692), test-scope-validator (L994) 가 이 패턴.
- **Pattern L (legacy/fallback)**: `**Agent X — <plugin>:<name>**` prose 헤더 + `Immutable head:` 텍스트 형태. SKILL.md L548-591 의 Agent A/B/C/D 가 이 패턴. security-reviewer 는 **L 패턴만** 가짐 (current SKILL.md 에 P-pattern dispatch 블록 없음). codex-reviewer 는 L497-499 의 fan-out 평가 + L540-544 의 fallback inclusion prose 로 dispatch — P 패턴도 L 패턴도 아닌 reference-only 형태.

**6개 모두에 대한 project_dir 보장**:
- Pattern P (4개: scout / adversarial / synthesizer / test-scope-validator): Agent() prompt 문자열 안에 `project_dir: <current working directory>` 라인 추가.
- Pattern L (1개: security-reviewer): "Agent D — security-reviewer" 섹션의 "Immutable head" 다음에 `If the prompt contains a `## Current Diff` section, ...` 문장이 이미 있음. 그 직전/직후에 추가:
  > Your input prompt will include a `project_dir: <absolute path>` line. Use this verbatim for any Read tool call — do not re-resolve via `pwd` or `Path.cwd()`.
- Reference-only (1개: codex-reviewer): SKILL.md 가 직접 dispatch 하지 않으므로 SKILL.md 변경 불필요. 대신 codex-reviewer.md 의 Inputs 섹션 (AC2) 가 single source of truth — orchestrator 가 codex-reviewer 를 dispatch 할 때 prompt 에 `project_dir:` 라인 포함하라는 안내가 agent.md 자체에 있음.

**검증 (deterministic) — two-pattern aware**: `test_codex_dispatch_invariant.sh` 신규 Scenario 4:
```bash
SKILL="$REPO_ROOT/plugins/quality-gates/skills/quality-pipeline/SKILL.md"

# Pattern P — 4 agents with explicit Agent() block
for name in scout adversarial synthesizer test-scope-validator; do
  awk -v name="quality-gates:$name" '
    $0 ~ name { found=NR }
    found && NR <= found+15 && /project_dir:/ { ok=1; exit }
    END { exit !ok }
  ' "$SKILL" || fail "Scenario 4: Pattern-P dispatch for $name lacks project_dir"
done

# Pattern L — security-reviewer prose header
awk '
  /\*\*Agent D — security-reviewer\*\*/ { found=NR }
  found && NR <= found+30 && /project_dir/ { ok=1; exit }
  END { exit !ok }
' "$SKILL" || fail "Scenario 4: Pattern-L Agent D (security-reviewer) section lacks project_dir reference"

# Reference-only — codex-reviewer.md is the source of truth
grep -q 'project_dir' "$REPO_ROOT/plugins/quality-gates/agents/codex-reviewer.md" \
  || fail "Scenario 4: codex-reviewer.md lacks project_dir input contract"
```
- Window 가 P 패턴은 15 라인 (Agent() block 평균 길이 + 여유), L 패턴은 30 라인 (헤더 + Immutable head 본문 + 후속 prose 평균).

### AC2: 6개 agent.md에 `project_dir` input contract 추가 + drift guard
- 각 agent.md 의 "Inputs" 섹션 첫 항목 (또는 기존 첫 항목 바로 위) 에:
  ```
  - `project_dir`: project working directory (absolute path) — pipeline 의 단일 좌표. SKILL preflight 에서 frozen.
  ```
- 각 agent.md 에 "Forbidden" 섹션이 이미 있으면 한 줄 추가, 없으면 새 섹션 생성:
  > Do not re-resolve cwd via `git rev-parse`, `Path.cwd()`, `os.getcwd()`, or any shell `pwd` invocation — use `project_dir` from your input verbatim. Re-resolution at agent runtime defeats the pipeline-wide coordinate contract.
- **검증 (deterministic)**: `test_worktree.sh` 신규 T8 (Issue #8):
  ```bash
  for agent in scout adversarial synthesizer test-scope-validator codex-reviewer security-reviewer; do
    grep -q 'project_dir' "$PLUGIN_DIR/agents/$agent.md" \
      || fail "T8: agents/$agent.md missing project_dir Input contract"
  done
  ```

### AC3: codex-reviewer.md 의 5개 동시 fix
새 bash 블록 첫 라인 (`SCRATCH=...` 직전) 의 정확한 형태 — Issue #4 의 ambiguity 해소:
```bash
# AC3 guard — fail loud if pipeline coordinate is missing.
if [ -z "${project_dir:-}" ]; then
  echo '{"codex_failed": true, "reason": "missing_project_dir"}'
  exit 0
fi
cd "$project_dir" || { echo '{"codex_failed": true, "reason": "project_dir_unreachable"}'; exit 0; }

SCRATCH="$(mktemp -d -t qg-codex-rev-XXXXXX)"
...
REPO_ROOT="$project_dir"     # ← git rev-parse 제거; project_dir 이 단일 좌표
# 기존 AC10 의 `if [ -z "$REPO_ROOT" ]` 가드 블록은 제거 (위 첫 라인이 이미 covered).
# AC8 의 TIMEOUT_CMD 가드는 유지.
```
또한:
- `python3 "$REPO_ROOT/plugins/quality-gates/scripts/build_codex_prompt.py"` → `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/build_codex_prompt.py"`.
- `python3 "$REPO_ROOT/plugins/quality-gates/scripts/codex_findings_to_yaml.py"` → `python3 "${CLAUDE_PLUGIN_ROOT}/scripts/codex_findings_to_yaml.py"`.
- `codex exec ... -C "$REPO_ROOT" ...` 그대로 (REPO_ROOT 값이 이제 project_dir).
- **검증**: `test_worktree.sh` 신규 T7 — `grep -q '\$REPO_ROOT/plugins/quality-gates' agents/codex-reviewer.md` 결과 0건 (negative grep, exit 1 시 PASS).
- **상호작용 노트**: codex CLI 의 `-C` flag 동작은 C7 의 trust boundary. detect_codex.sh 의 `known_bad_version` skip_reason 이 단일 fail-safe.

### AC4: 3개 hook 의 payload `cwd` 사용 + state-file path 정규화
- `stop-hook.py`:
  - 신규 helper: `def _state_root(hook_input) -> Path: cwd = hook_input.get("cwd"); if not cwd: print("[quality-gates] stop-hook payload missing 'cwd'; falling back to process cwd", file=sys.stderr); cwd = os.getcwd(); return Path(cwd) / ".claude/quality-gates"`.
  - `state_file_for(session_id, hook_input)` → `_state_root(hook_input) / session_id / "pipeline.md"` (signature 변경, 호출처 모두 갱신).
  - **기존 `ROOT = ".claude/quality-gates"` 모듈 상수는 제거** (B1).
- `post-tool-use-session-tracker.py`:
  - `Path(payload.get("cwd") or os.getcwd()) / ".claude/quality-gates" / session_id / "files.md"`.
  - **abs_path resolve (Issue #5)**: 동일 payload-cwd 를 base 로 사용 — `abs_path = str((Path(payload.get("cwd") or os.getcwd()) / file_path).resolve())`. 단, Claude Code tool payload 의 `file_path` 는 일반적으로 absolute (Edit/Write tool spec) 이므로 `Path(file_path).is_absolute()` 시 base 무시 (`Path(file_path).resolve()` 직접 사용). Negative case: relative file_path 가 와도 worktree-correct base 사용.
- `session-start-advisor.py`:
  - 기존 `repo_root = Path.cwd()` (L74) → `repo_root = Path(payload.get("cwd") or os.getcwd())`. payload 는 `_self_session_id()` 가 이미 읽음 — 호출 순서만 정리.
- **out of scope for AC4**: `post-tool-use.py` (Bash matcher) 는 이미 line 58 에서 `input_data.get("cwd", os.getcwd())` 사용 중 — fix 불필요, 회귀만 보장. `session-end-cleanup.py` 도 동일하게 이미 payload-aware (L34).
- **검증**: 신규 unit test `test_hook_cwd_contract.py` — 3개 hook 각각에 payload `{cwd: <tmp_dir>, session_id: <fake>, ...}` 주입:
  - positive case: state file 경로가 `<tmp_dir>/.claude/quality-gates/<sid>/` 안에 생성됨.
  - positive case (session-tracker): relative file_path 주입 시 abs_path 가 `<tmp_dir>/...` 으로 resolve.
  - negative case: payload 에 `cwd` 키 없으면 stderr 에 정확히 `"[quality-gates] stop-hook payload missing 'cwd'"` 문자열 emit.

### AC5: 회귀 테스트 통과
- 기존 `test_worktree.sh` T1~T4 그대로 PASS (변경 없음).
- 신규 시나리오 T5~T9 PASS:
  - T5: SKILL.md prose 에서 6개 dispatch 블록 각각이 anchor-then-window 단정 통과 (AC1 검증).
  - T6 (Issue #11 보강): grep 대신 **간접 검증** — `python3 -c "import ast; ..."` 로 각 hook 파일의 AST 를 parse 해서 `payload.get("cwd")` 또는 `hook_input.get("cwd")` 호출이 실제로 존재함을 단정 (false-positive 없음). 패턴이 docstring/comment 에 있어도 무효.
  - T7: codex-reviewer.md 본문에 `$REPO_ROOT/plugins/quality-gates` 문자열 존재하지 않음 (AC3).
  - T8: 6개 agent.md 가 `project_dir` 라인을 Inputs/본문에 포함 (AC2).
  - T9: setup-qg.sh 가 state frontmatter 에 `project_dir:` 라인 write — `grep -q 'project_dir:' scripts/setup-qg.sh` 단정 (AC6).

### AC6: B6 fix — state file schema + build_gate_prompt() 영속화
- `scripts/setup-qg.sh` 의 frontmatter write 블록 (L252-266) 에 신규 라인 추가:
  ```bash
  project_dir: "$(pwd)"   # AC6: pipeline coordinate frozen at preflight
  ```
- **`$(pwd)` 시점 보장 (round 2 Issue [c6d84e3b])**: SKILL.md L52 의 호출 `"${CLAUDE_PLUGIN_ROOT}/scripts/setup-qg.sh" --ensure` 는 Claude Code Bash tool 로 실행되며, Bash tool 의 cwd 는 skill invocation cwd 를 inherit. 따라서 setup-qg.sh subshell 안에서의 `$(pwd)` 는 skill cwd 와 동일 — pipeline 의 결정적 단일 좌표. 별도의 `cd ... && bash setup-qg.sh` wrapping 불필요. (이 invariant 자체는 SKILL.md 의 instruction prose 가 보장; setup-qg.sh 안에 `cd "$1"` 같은 우회 코드를 추가하면 안 됨 — Forbidden.)
- `hooks/stop-hook.py:parse_state_file()` 에 `project_dir` 키 처리:
  - 존재 시 state["project_dir"] = 값.
  - 누락 시 (v1.12.x state file): `state["project_dir"] = os.getcwd()` + stderr 경고 `"⚠️ Quality Gates: state file lacks project_dir (v1.12.x schema?); defaulting to current process cwd"`. 패턴은 stop-hook.py L114-120 의 `gate3_resolution_iter` 처리와 동일.
- `hooks/stop-hook.py:build_gate_prompt()` 3개 분기 (gate 1/2/3) 모두에 라인 추가:
  ```python
  f"  project_dir: {state.get('project_dir', os.getcwd())}\n"
  ```
- **검증**: `test_stop_hook_unit.py` 신규 case — frontmatter 에 `project_dir: /foo/bar` 있는 state file 을 parse 하면 `build_gate_prompt(1, state, "")` 결과 문자열에 `project_dir: /foo/bar` 포함.

### AC7: plugin.json + CHANGELOG bump
- `plugin.json` version `1.12.0` → `1.13.0`.
- CHANGELOG.md 상단에 새 entry `## [1.13.0] — 2026-05-16`, sections:
  - **Added**: state file schema 필드 `project_dir`; agent input contract 6 agents; `test_hook_cwd_contract.py`; `test_worktree.sh` T5-T9.
  - **Changed**: stop-hook.py 의 `ROOT` 상수 제거 — payload-derived `_state_root()` helper 도입; build_gate_prompt() 가 모든 gate continuation 에 project_dir 전파; codex-reviewer.md 의 plugin script 경로를 `${CLAUDE_PLUGIN_ROOT}` 기반으로 표준화.
  - **Fixed**: B1~B6 (worktree cwd contract 분산 위반 6건).

### AC8: Manual e2e (개발자 확인, CI 아님 — Issue #6 보강)
임의 repo 에서 worktree 만들고 검증 (각 step 에 concrete 명령 포함):
```bash
# Setup
mkdir /tmp/qg-wt-test && cd /tmp/qg-wt-test
git init -q && echo "x" > README.md && git add . && git commit -q -m init
git worktree add ../wt-feat feature-x
cd ../wt-feat
echo "y = 1" > foo.py && git add . && git commit -q -m "add foo"

# Run qg gate2
/qg gate2

# Step 1 — codex-reviewer 가 foo.py 인식 (transcript inspection)
# Transcript 경로 탐색 (round 2 Issue [e2b8c4a1] — macOS /tmp ↔ /private/tmp symlink 회피)
TRANSCRIPT="$(find ~/.claude/projects -name '*.jsonl' -path '*wt-feat*' -newer /tmp/qg-wt-test -print 2>/dev/null | sort | tail -1)"
if [ -z "$TRANSCRIPT" ]; then
  echo "FAIL: no transcript found for wt-feat session"; exit 1
fi
python3 -c "
import sys, json
with open('$TRANSCRIPT') as f:
  for line in f:
    msg = json.loads(line)
    for blk in (msg.get('message', {}).get('content', []) or []):
      if isinstance(blk, dict) and blk.get('type') == 'text':
        if 'project_dir:' in blk.get('text', '') and 'wt-feat' in blk.get('text', ''):
          print('OK: project_dir worktree path found')
          sys.exit(0)
print('FAIL: no project_dir/wt-feat in transcript')
sys.exit(1)
"

# Step 2 — state file in worktree, NOT in main repo
[ -d /tmp/qg-wt-test/wt-feat/.claude/quality-gates ] && echo "OK: state in worktree"
[ ! -d /tmp/qg-wt-test/.claude/quality-gates ] && echo "OK: main repo untouched"

# Step 3 — no fallback warning in hook stderr (look at most recent claude-code log)
grep -q "missing 'cwd'" ~/.claude/logs/*.log && echo "FAIL: fallback warning emitted" || echo "OK: clean"
```

## 6. Files to Modify

| Path | Change kind | LoC delta (approx) |
|---|---|---|
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | 6개 dispatch 블록 prompt 에 `project_dir:` 라인 추가 | +6 |
| `plugins/quality-gates/agents/scout.md` | Inputs `project_dir` + Forbidden | +4 |
| `plugins/quality-gates/agents/codex-reviewer.md` | Inputs `project_dir` + Forbidden + bash 5개 fix (guard, cd, REPO_ROOT 단순화, 2개 plugin script path) + 기존 Forbidden 섹션의 `-C "$REPO_ROOT"` 멘션이 "project_dir 의 alias" 임을 명시하는 한 줄 추가 (round 2 Issue [f1d3a9c7] — 의미 변화 명시) | +12, -4 |
| `plugins/quality-gates/agents/adversarial.md` | Inputs `project_dir` + Forbidden | +4 |
| `plugins/quality-gates/agents/synthesizer.md` | Inputs `project_dir` + Forbidden | +4 |
| `plugins/quality-gates/agents/test-scope-validator.md` | Inputs `project_dir` + Forbidden | +4 |
| `plugins/quality-gates/agents/security-reviewer.md` | Inputs `project_dir` + Forbidden (Issue #1 — LLM-only 이지만 일관성 보장) | +4 |
| `plugins/quality-gates/hooks/stop-hook.py` | (B1) `ROOT` 상수 제거, `_state_root()` helper + 호출처 갱신; (B6) `parse_state_file()` 에 `project_dir` 처리; (B6) `build_gate_prompt()` 3개 분기에 `project_dir` line inject | +15, -3 |
| `plugins/quality-gates/hooks/post-tool-use-session-tracker.py` | state_file path + abs_path resolve base 모두 `payload["cwd"]` 사용 | +4, -2 |
| `plugins/quality-gates/hooks/session-start-advisor.py` | `Path.cwd()` → payload-derived | +3, -1 |
| `plugins/quality-gates/scripts/setup-qg.sh` | state frontmatter 에 `project_dir: "$(pwd)"` 라인 추가 (B6) | +1 |
| `plugins/quality-gates/tests/test_worktree.sh` | T5~T9 추가 (5개 신규 단정) | +50 |
| `plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` | Scenario 4 — 6 agent dispatch 블록 anchor-then-window 검사 | +12 |
| `plugins/quality-gates/tests/test_hook_cwd_contract.py` | 신규 unit test (3 hook × 2 case = 6 단정) | +80 |
| `plugins/quality-gates/tests/test_stop_hook_unit.py` | `build_gate_prompt` 가 project_dir 전파하는 case 추가 | +20 |
| `plugins/quality-gates/.claude-plugin/plugin.json` | version `1.12.0` → `1.13.0` | ±1 |
| `plugins/quality-gates/CHANGELOG.md` | `## [1.13.0]` entry — Added/Changed/Fixed | +22 |
| `plugins/quality-gates/README.md` | "Principles Instantiated" 한 줄 추가 (Law 1 좌표 계약 instantiation) | +1 |

Total ≈ +245 LoC, -10 LoC. 18 files touched.

## 7. Verification Plan

### 7.1 Local automated
- `bash plugins/quality-gates/tests/test_worktree.sh` → T1~T9 모두 PASS (9 단정).
- `bash plugins/quality-gates/tests/test_codex_dispatch_invariant.sh` → 4 scenarios (기존 3 + 신규 1) PASS.
- `python3 plugins/quality-gates/tests/test_hook_cwd_contract.py` → 6 단정 PASS (3 hook × positive/negative).
- `python3 plugins/quality-gates/tests/test_stop_hook_unit.py` → 기존 단정 + build_gate_prompt project_dir 전파 case PASS.
- 기존 regression suite: `test_setup_qg.sh`, `test_session_end_cleanup.py`, `test_isolation.sh`, `test_codex_backward_compat.sh`, `test_session_start_advisor.py`, `test_codex_reviewer_frontmatter.sh`, `test_scout_codex_integration.sh`, `test_kill_switches.py`, `test_agent_frontmatter_keys.sh`, `test_runtime_verifier_frontmatter.sh`, `test_test_scope_validator_frontmatter.sh` 모두 PASS.

### 7.2 Manual e2e
AC8 의 shell block 그대로 실행. 3개 OK 라인 (transcript / state-in-worktree / clean stderr) 모두 출력되면 PASS.

### 7.3 PR gate
- 모든 변경 surface 의 SemVer bump 확인 (`1.13.0`).
- CHANGELOG entry 가 Added/Changed/Fixed 사용.
- README "Principles Instantiated" 한 줄 추가 commit 포함.
- 본 spec 파일 (`docs/superpowers/specs/2026-05-16-qg-worktree-cwd-contract-design.md`) 함께 commit.

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

- **Status**: draft round 3 — spec-reviewer round 1 (12 issues) + round 2 (7 new issues from fix authoring) 모두 반영 완료
- **Estimated implementation time**: 5~6 hours (18 파일, 6 단정 신규 unit test, e2e 검증)
- **Risk level**: low–medium (대다수 사용자 no-op; state file schema 추가는 backward-compat 처리됨; gate boundary propagation 은 신규 영역이므로 단위 테스트 필수)
- **Plugin version target**: `quality-gates 1.13.0`
- **Dependencies**: 없음 (다른 플러그인 영향 없음)
- **Spec review history**:
  - Round 0: brainstorming session 2026-05-16, claude-opus-4-7
  - Round 1: spec-distill:spec-reviewer adversarial review — 12 issues (2 critical, 5 major, 4 minor, 1 block); all addressed in round 2
  - Round 2: spec-distill:spec-reviewer second-pass — 7 new issues introduced by round-1 fix-authoring (0 block, 3 high, 4 medium); all addressed in round 3
- **Forbidden patterns invoked**: trivia-ceremony 회피 (18개 파일 → 정상 minor); polite-stop 방지 (concrete next-action §11 명시)

## 11. Concrete Next Action

writing-plans skill 호출 시 다음 ordered sequence 로 implementation plan 생성:

### Phase A — State schema + gate boundary 영속화 (B6 fix, 가장 critical)
1. `scripts/setup-qg.sh` frontmatter write block 에 `project_dir: "$(pwd)"` 라인 추가 (AC6).
2. `hooks/stop-hook.py:parse_state_file()` 에 `project_dir` 필드 처리 (existing → use; missing → fallback + warning).
3. `hooks/stop-hook.py:build_gate_prompt()` 의 3개 gate 분기 (gate 1/2/3) 모두에 `f"  project_dir: {state.get('project_dir', os.getcwd())}\n"` 라인 추가.
4. `tests/test_stop_hook_unit.py` 에 project_dir 전파 case 추가.
5. (이 시점에서 `python3 plugins/quality-gates/tests/test_stop_hook_unit.py` PASS — Phase A 완료 검증.) **(round 2 Issue [a5c2d6f8] — Python 파일, `bash` 아닌 `python3`)**

### Phase B — Hook cwd 정규화 (B1/B2/B3 fix)
6. `hooks/stop-hook.py`: `ROOT` 상수 제거, `_state_root(hook_input)` helper 추가, `state_file_for` signature 갱신, 모든 호출처 갱신.
7. `hooks/post-tool-use-session-tracker.py`: state_file path + abs_path resolve base 둘 다 payload-cwd 사용.
8. `hooks/session-start-advisor.py`: `Path.cwd()` → payload-derived.
9. `tests/test_hook_cwd_contract.py` 신규 파일 작성 (3 hook × positive/negative = 6 단정).
10. (이 시점에서 `python3 tests/test_hook_cwd_contract.py` PASS — Phase B 완료 검증.)

### Phase C — Agent contract (B4 fix)
11. `agents/scout.md`, `adversarial.md`, `synthesizer.md`, `test-scope-validator.md`, `security-reviewer.md` 5개 LLM-only agent 에 Inputs `project_dir` + Forbidden 추가.
12. `agents/codex-reviewer.md` 에 Inputs + Forbidden 추가 + bash 블록 5개 fix (guard, cd, REPO_ROOT 단순화, 2개 plugin script path) (AC3).
13. (이 시점에서 `bash tests/test_worktree.sh` T7+T8 PASS 단계적 검증.)

### Phase D — SKILL dispatch propagation (B4 fix continued)
14. `skills/quality-pipeline/SKILL.md` 의 6개 Agent() dispatch 블록 (scout, codex-reviewer Phase 1 inclusion, adversarial, synthesizer, test-scope-validator, security-reviewer) prompt 에 `project_dir: <current working directory>` 라인 추가.
15. `tests/test_codex_dispatch_invariant.sh` Scenario 4 추가 (anchor-then-window awk).
16. `tests/test_worktree.sh` T5/T6/T9 추가.

### Phase E — Release artifacts
17. `.claude-plugin/plugin.json` version `1.12.0` → `1.13.0`.
18. `CHANGELOG.md` 에 `## [1.13.0] — 2026-05-16` entry 작성 (Added / Changed / Fixed).
19. `README.md` "Principles Instantiated" 한 줄 추가.
20. 본 spec 파일 + 모든 변경 commit (단일 PR, conventional commit: `fix(quality-gates): enforce project_dir cwd contract across pipeline (v1.13.0)`).

### Phase F — Manual e2e
21. AC8 shell block 실행, 3개 OK 라인 확인.
22. (선택) PR description 에 e2e 결과 paste.

**진입 명령** (Phase A 시작):
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-worktree-cwd-contract
$EDITOR plugins/quality-gates/scripts/setup-qg.sh  # AC6 라인 추가
```
