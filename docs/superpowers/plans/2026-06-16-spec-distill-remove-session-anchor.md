# spec-distill SessionStart anchor 훅 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill의 SessionStart `session-anchor.sh` 훅(존재하지 않는 `/interview resume`를 매 세션 시작마다 안내하던 stale advisory)을 완전히 제거하고, 문서·테스트·버전을 동기화하며, 재도입 방지 회귀 락을 남긴다.

**Architecture:** 순수 제거 작업. 새 surface 없음. 훅 파일 1개 삭제 + `hooks.json`의 SessionStart 등록 제거 + 해당 훅을 검증하던 테스트를 "재도입 금지" 회귀 락으로 repurpose + 단위 테스트에서 anchor 단언 외과 제거 + README/CHANGELOG/plugin.json/test_readme_sync 동기화. 5개 훅 중 나머지 4개(UserPromptSubmit reminder, PostToolUse validator, Stop review-dispatch, SessionEnd cleanup)와 리뷰 파이프라인(`pending_review`/`suppressed_paths`)은 이벤트별로 격리돼 있어 영향 없음.

**Tech Stack:** Bash 훅, Python3 훅, JSON 설정, Markdown 문서. 테스트 러너: bash 스위트는 `bash tests/<name>.sh`, python 스위트는 `python3 -m unittest`(직접 실행은 vacuous — `reference_spec_distill_test_runner` 메모리).

**Source spec:** `docs/superpowers/specs/2026-06-16-spec-distill-remove-session-anchor-design.md` (Law 2 분리 리뷰 2라운드 통과, approved).

**작업 위치:** 모든 명령은 repo root `/Users/jeonghokim/Downloads/devbrew`에서 실행. 현재 브랜치 `feature/spec-distill-remove-session-anchor`. **이 작업은 worktree가 아니라 현재 working tree에서 in-place로 진행한다.**

---

## 중요한 사전 지식 (구현자가 먼저 읽을 것)

이 plan을 처음 보는 엔지니어가 반드시 알아야 하는 함정:

1. **`import shutil`을 지우지 말 것.** `tests/test_hook_output_schema.py`에서 제거하는 `TestSessionAnchorSchema` 클래스가 `shutil.which()`를 쓰지만, `shutil`은 같은 파일의 다른 4곳(`shutil.rmtree` at 라인 96/226/329/607)에서도 쓰인다. 클래스 제거 후에도 import는 유지해야 한다(deferred 항목 해소 완료).

2. **"anchor"는 중의적 토큰이다.** `grep -i anchor`는 본 작업과 **무관한** 합법적 hit가 있다 — `agents/spec-reviewer.md`, `scripts/parse_spec_structure.py`, `skills/conducting-interview/SKILL.md`의 "markdown section anchor"(`#goals` 같은 앵커). 이들은 절대 건드리지 않는다. **검증은 `resume`(AC3, 제거 후 0건)와 README의 `SessionStart`(AC4)에만 hard-assert하고, bare "anchor"로 0건을 기대하지 말 것.**

3. **제거 후에도 `SessionStart` 문자열이 정당하게 남는 두 곳이 있다.** (a) 새 회귀 락 `tests/test_hooks.sh`는 "SessionStart 키 부재"를 *단언하기 위해* 그 문자열을 포함한다. (b) `CHANGELOG.md`는 역사 항목 + 새 `[0.16.0]` 항목에서 언급한다. 둘 다 dangling이 아니라 의도된 것. AC3 grep은 `CHANGELOG.md`를 제외한다.

4. **NG5 — 아카이브는 청소 대상이 아니다.** `docs/superpowers/plans/2026-05-09-spec-distill.md`(v0.1.0 아카이브 plan)에 역사적 `/interview resume`·`SessionStart anchor` 언급이 있으나, 그 시점 상태를 기록한 point-in-time 문서이므로 **수정 금지**(CHANGELOG history와 동일). resume 0건 목표는 **live 플러그인(`plugins/spec-distill/`) 한정**이다.

5. **회귀 락은 정확히 두 단언만.** 보안/정확성 게이트가 아니라 "이미 떼어낼 테스트 파일의 1:1 repurpose"다(`feedback_harness_lightness_trust_model`). 키 부재 + 파일 부재 외에 가드를 추가하지 말 것.

---

## File Structure

| 파일 | 역할 | 작업 |
|---|---|---|
| `plugins/spec-distill/hooks/session-anchor.sh` | SessionStart 훅 본체 | **삭제** |
| `plugins/spec-distill/hooks/hooks.json` | 5개 훅 등록 | SessionStart 블록 + description 조각 제거 |
| `plugins/spec-distill/tests/test_hooks.sh` | 훅 동작 테스트 | 회귀 락(2단언)으로 재작성 |
| `plugins/spec-distill/tests/test_hook_output_schema.py` | 훅 출력 스키마 단위 테스트 | anchor 클래스 + global-disable 메서드 제거 |
| `plugins/spec-distill/README.md` | 플러그인 문서 | Hooks Installed 행 / Output-schema / Kill switch 제거 |
| `plugins/spec-distill/CHANGELOG.md` | 변경 이력 | `## [0.16.0]` 항목 추가 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 메타데이터 | version 0.15.0 → 0.16.0 |
| `plugins/spec-distill/tests/test_readme_sync.sh` | 버전 동기화 테스트 | 기대 버전 0.16.0 |

**커밋 전략 (3 커밋, 각 커밋은 green + committable):**
- 커밋 1 (Task 1): 훅 + 모든 관련 테스트 제거 + 회귀 락 (D1+D2+D3 원자적). diff가 self-justifying(파일 삭제 + 그 테스트 제거가 같은 diff) → cherry-pick 의심 회피.
- 커밋 2 (Task 2): README 동기화 (D4 README).
- 커밋 3 (Task 3): 릴리스 — CHANGELOG + plugin.json + test_readme_sync (D4 CHANGELOG + D5). 이 셋은 version-coupled라 원자적.

> **devbrew 버전 규약 주의:** `plugins/<name>/`를 건드리는 PR은 `plugin.json` SemVer bump 동반(`feedback_plugin_version_bump`). 본 plan은 bump를 **마지막 릴리스 커밋(Task 3)**에 둔다 — plugin.json/CHANGELOG/test_readme_sync가 서로를 검증하므로 한 커밋에서 같이 움직여야 각 커밋이 green을 유지한다. 브랜치 전체(머지 시점)가 0.16.0을 carry하므로 cache 무효화 요건은 PR 레벨에서 충족된다.

---

## Pre-flight: 테스트 baseline 캡처

변경 전 스위트를 한 번 돌려 **pre-existing red를 기록**한다(AC9의 "회귀 0"은 baseline 대비이므로). `project_qg_pre_existing_test_reds` 메모리: main에도 stale red가 있을 수 있다.

- [ ] **Pre-flight Step 1: baseline 실행 + 저장**

Run (repo root):
```bash
cd /Users/jeonghokim/Downloads/devbrew
mkdir -p "$CLAUDE_JOB_DIR/tmp" 2>/dev/null || true
BASE="${CLAUDE_JOB_DIR:-/tmp}/tmp/specdistill-baseline.txt"
{
  echo "### PYTHON ###"
  python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -5
  echo "### BASH ###"
  for t in plugins/spec-distill/tests/test_*.sh; do
    if bash "$t" >/dev/null 2>&1; then echo "PASS $t"; else echo "FAIL $t"; fi
  done
} | tee "$BASE"
```
Expected: 대부분 PASS. FAIL이 있으면 그 목록을 기억(우리 작업과 무관한 pre-existing red). 우리가 만지는 `test_hooks.sh`, `test_readme_sync.sh`, `test_hook_output_schema.py`는 **현재 PASS여야 정상**(아직 제거 전).

---

## Task 1: SessionStart anchor 훅 + 관련 테스트 제거 + 회귀 락 (D1+D2+D3)

**Files:**
- Modify: `plugins/spec-distill/tests/test_hooks.sh` (회귀 락으로 재작성)
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py` (anchor 단언 제거)
- Delete: `plugins/spec-distill/hooks/session-anchor.sh`
- Modify: `plugins/spec-distill/hooks/hooks.json` (SessionStart 블록 + description 제거)

**순서 주의:** `.py`의 anchor 테스트는 `session-anchor.sh`를 실행하므로, 파일을 삭제하기 *전에* 먼저 제거해야 한다(아니면 `.py` 스위트가 깨짐). 아래 스텝 순서를 지킬 것.

- [ ] **Step 1: 회귀 락 작성 (test_hooks.sh 전체 교체)**

`plugins/spec-distill/tests/test_hooks.sh`의 전체 내용을 아래로 교체한다:

```bash
#!/usr/bin/env bash
# spec-distill — SessionStart anchor 제거 회귀 락 (v0.16.0).
# Run: bash plugins/spec-distill/tests/test_hooks.sh
# session-anchor.sh 훅이 실수로 되살아나지 않음을 보장. Exits 0 on pass, 1 on fail.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"
HOOKS_JSON="$PLUGIN_ROOT/hooks/hooks.json"
ANCHOR="$PLUGIN_ROOT/hooks/session-anchor.sh"

pass=0
fail=0

note() {
  if [[ "$1" == "PASS" ]]; then
    pass=$((pass+1))
    echo "  ✓ $2"
  else
    fail=$((fail+1))
    echo "  ✗ $2"
  fi
}

echo "=== SessionStart anchor removal regression lock ==="

# 1. hooks.json must NOT register a SessionStart hook (and must stay valid JSON).
if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(1 if "SessionStart" in d.get("hooks", {}) else 0)' "$HOOKS_JSON"; then
  note PASS "hooks.json has no SessionStart key"
else
  note FAIL "hooks.json still registers a SessionStart hook (or is invalid JSON)"
fi

# 2. The session-anchor.sh hook file must NOT exist.
if [[ ! -e "$ANCHOR" ]]; then
  note PASS "hooks/session-anchor.sh does not exist"
else
  note FAIL "hooks/session-anchor.sh still exists"
fi

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: 회귀 락이 RED인지 확인 (TDD)**

Run:
```bash
bash plugins/spec-distill/tests/test_hooks.sh
```
Expected: **FAIL (exit 1)** — 두 단언 모두 ✗. `hooks.json`에 SessionStart 키가 아직 있고, `session-anchor.sh`가 아직 존재하므로 RED여야 정상이다. (RED를 못 보면 회귀 락이 무의미하므로 반드시 확인.)

- [ ] **Step 3: 단위 테스트에서 `TestSessionAnchorSchema` 클래스 제거**

`plugins/spec-distill/tests/test_hook_output_schema.py`에서 아래 클래스(현재 라인 419–469) 전체를 삭제한다. `import shutil`은 **유지**한다(다른 테스트가 사용). 삭제 대상 verbatim:

```python
class TestSessionAnchorSchema(HookOutputSchemaTestBase):
    """AC5 — session-anchor.sh output schema (bash, jq + no-jq paths)."""

    def setUp(self):
        super().setUp()
        # Pre-populate a state dir so session-anchor finds "previous sessions".
        prev = self.repo / ".claude" / "spec-distill" / "previous-session"
        prev.mkdir(parents=True)
        (prev / "state.local.md").write_text(
            "---\nsession_id: previous-session\n---\n", encoding="utf-8",
        )

    def _run(self, env_extra=None):
        env = {"CLAUDE_PROJECT_DIR": str(self.repo)}
        if env_extra:
            env.update(env_extra)
        return _run_hook(
            "session-anchor.sh",
            cwd=self.repo, env_extra=env, binary="bash",
        )

    @unittest.skipUnless(shutil.which("jq"), "jq required for AC5-a")
    def test_jq_path_emits_additional_context(self):
        result = self._run()
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg=f"empty stdout; stderr: {result.stderr}")
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "SessionStart")
        ac = hso.get("additionalContext", "")
        self.assertIn("이전 인터뷰 세션", ac)
        self.assertIn("/interview", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)

    def test_no_jq_fallback_emits_additional_context(self):
        no_jq_bin = self.repo / "no-jq-bin-2"
        no_jq_bin.mkdir()
        for tool in ("bash", "python3", "sed", "tr", "grep", "printf", "cat",
                     "wc", "find", "head"):
            src = shutil.which(tool)
            if src:
                (no_jq_bin / tool).symlink_to(src)
        result = self._run(env_extra={"PATH": str(no_jq_bin)})
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "SessionStart")
        self.assertIn("이전 인터뷰 세션", hso.get("additionalContext", ""))
```

삭제 후 그 자리에는 다음 클래스(`class TestKillSwitches(...)`)가 와야 하며, 두 top-level 클래스 사이에 **빈 줄 2개**가 유지되도록 한다.

- [ ] **Step 4: 단위 테스트에서 global-disable anchor 메서드 제거**

같은 파일 `tests/test_hook_output_schema.py`의 `TestKillSwitches` 클래스(현재 라인 539–552) 안에서 아래 메서드 전체를 삭제한다:

```python
    def test_global_disable_silences_session_anchor(self):
        prev = self.repo / ".claude" / "spec-distill" / "x"
        prev.mkdir(parents=True)
        (prev / "state.local.md").write_text("---\n---\n", encoding="utf-8")
        result = _run_hook(
            "session-anchor.sh", cwd=self.repo,
            env_extra={
                "DEVBREW_DISABLE_SPEC_DISTILL": "1",
                "CLAUDE_PROJECT_DIR": str(self.repo),
            },
            binary="bash",
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))
```

이 메서드는 `TestKillSwitches`의 마지막 메서드다. 삭제 후 `TestKillSwitches`의 마지막 남는 메서드(`test_global_disable_silences_pending_review_reminder`)와 그다음 module-level `def _in_worktree(...)` 사이에 **빈 줄 2개**가 유지되도록 정리한다. `TestKillSwitches`에는 여전히 4개 테스트(`..._review_dispatch` x2, `..._spec_write_validator`, `..._pending_review_reminder`)가 남는다.

- [ ] **Step 5: `.py` 스위트가 import/구문 오류 없이 green인지 확인**

(이 시점에 `session-anchor.sh`는 **아직 존재**한다 — 그래서 .py에서 anchor 테스트만 떼어내도 깨지지 않는다.)

Run:
```bash
python3 -m py_compile plugins/spec-distill/tests/test_hook_output_schema.py && echo "py_compile OK"
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_hook_output_schema.py' -v 2>&1 | tail -15
```
Expected: `py_compile OK` + 스위트 green(`OK`). `TestSessionAnchorSchema` 관련 테스트가 더 이상 collect되지 않아야 하고, 나머지는 모두 PASS.

- [ ] **Step 6: 훅 파일 삭제**

Run:
```bash
git rm plugins/spec-distill/hooks/session-anchor.sh
```
(`git rm`을 쓰면 스테이징까지 한 번에. 일반 `rm`이어도 무방하나 이후 `git add` 필요.)

- [ ] **Step 7: hooks.json에서 SessionStart 블록 제거**

`plugins/spec-distill/hooks/hooks.json`에서 SessionStart 등록 블록(현재 라인 15–25)을 통째로 삭제한다. 삭제 대상 verbatim:

```json
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/session-anchor.sh",
            "timeout": 5
          }
        ]
      }
    ],
```

삭제 후 `UserPromptSubmit` 블록의 닫는 `],`(라인 14) 다음에 곧바로 `"PostToolUse": [`(현재 라인 26)가 와야 한다.

- [ ] **Step 8: hooks.json description에서 "SessionStart anchor, " 제거**

같은 파일 라인 2의 `description`을 수정한다.

Before:
```json
  "description": "spec-distill — UserPromptSubmit reminder, SessionStart anchor, PostToolUse spec/design validator, Stop reviewer-dispatch, SessionEnd cleanup.",
```
After:
```json
  "description": "spec-distill — UserPromptSubmit reminder, PostToolUse spec/design validator, Stop reviewer-dispatch, SessionEnd cleanup.",
```

- [ ] **Step 9: hooks.json JSON 유효성 확인 (AC2)**

Run:
```bash
python3 -c "import json; d=json.load(open('plugins/spec-distill/hooks/hooks.json')); assert 'SessionStart' not in d['hooks'], 'SessionStart still present'; assert 'SessionStart anchor' not in d['description'], 'description still mentions anchor'; print('hooks.json OK:', list(d['hooks'].keys()))"
```
Expected: `hooks.json OK: ['UserPromptSubmit', 'PostToolUse', 'Stop', 'SessionEnd']` (무오류).

- [ ] **Step 10: 회귀 락이 GREEN으로 전환됐는지 확인 (TDD)**

Run:
```bash
bash plugins/spec-distill/tests/test_hooks.sh
```
Expected: **PASS (exit 0)** — `Results: 2 passed, 0 failed`. Step 2의 RED가 이제 GREEN.

- [ ] **Step 11: `.py` 스위트 재확인 (파일 삭제 후에도 green)**

Run:
```bash
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_hook_output_schema.py' -v 2>&1 | tail -10
```
Expected: green(`OK`). (anchor 테스트가 이미 제거됐으므로 `session-anchor.sh` 부재가 스위트를 깨지 않음.)

- [ ] **Step 12: 커밋**

```bash
git add plugins/spec-distill/tests/test_hooks.sh \
        plugins/spec-distill/tests/test_hook_output_schema.py \
        plugins/spec-distill/hooks/hooks.json
# session-anchor.sh는 Step 6의 git rm으로 이미 스테이징됨
git commit -m "$(cat <<'EOF'
refactor(spec-distill): remove dead SessionStart anchor hook + regression lock

session-anchor.sh advised `/interview resume`, a command that was never
implemented (no resume branch in commands/interview.md). The hook injected
an unactionable advisory into LLM context at every session start. Remove the
hook + its hooks.json registration, drop its unit tests (TestSessionAnchorSchema
+ the global-disable anchor case; import shutil retained — used elsewhere), and
repurpose test_hooks.sh into a two-assertion regression lock (no SessionStart
key in hooks.json + session-anchor.sh absent). Review pipeline is unaffected:
pending_review/suppressed_paths are consumed by the UserPromptSubmit/Stop hooks.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: README 문서 동기화 (D4 README)

**Files:**
- Modify: `plugins/spec-distill/README.md` (3곳)

- [ ] **Step 1: Hooks Installed 표에서 SessionStart 행 삭제**

`plugins/spec-distill/README.md`에서 아래 행(현재 라인 108) 전체를 삭제한다(앞뒤 행은 보존):

```
| SessionStart | `hooks/session-anchor.sh` | resumed session에 spec-distill anchor 표시 | session-level lifecycle event는 hook 전용. |
```

- [ ] **Step 2: Output-schema 문장에서 SessionStart 이벤트 제거**

같은 파일 라인 114의 Output schema 문장에서 이벤트 목록을 수정한다.

Before (부분 문자열):
```
`hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit/SessionStart, `decision:"block" + reason` for Stop
```
After:
```
`hookSpecificOutput.additionalContext` for PostToolUse/UserPromptSubmit, `decision:"block" + reason` for Stop
```
(즉 `/SessionStart`만 제거. 나머지 문장 — `decision:"block" + reason` for Stop 등 — 은 불변.)

- [ ] **Step 3: Kill switches 목록에서 SessionStart 항목 삭제**

같은 파일에서 아래 줄(현재 라인 120) 전체를 삭제한다:

```
- `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` — SessionStart hook만 skip.
```

- [ ] **Step 4: README에 SessionStart 잔재 0 확인 (AC4)**

Run:
```bash
grep -n "SessionStart" plugins/spec-distill/README.md; echo "exit=$? (1=no matches=good)"
```
Expected: `exit=1` (매치 없음). README에서 SessionStart가 모두 사라짐.

- [ ] **Step 5: test_readme_sync 키워드 회귀 확인 (안전망)**

README 편집이 sync 테스트의 키워드(`DEVBREW_SPEC_DISTILL_DISABLE_WEB`, `interview-brief`, `steelman-builder`, `cancel-review`)를 건드리지 않았는지 확인. (이 시점 plugin.json은 아직 0.15.0이고 test_readme_sync도 0.15.0을 기대하므로 green이어야 정상.)

Run:
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh
```
Expected: **PASS** (`Fail: 0`) — 아직 버전을 안 올렸으므로 0.15.0 기준으로 green. (버전 bump는 Task 3.)

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/README.md
git commit -m "$(cat <<'EOF'
docs(spec-distill): drop SessionStart anchor from README hooks/kill-switches

Remove the Hooks Installed row, the SessionStart entry in the output-schema
sentence, and the spec-distill:SessionStart kill-switch bullet — the last
live-plugin references to the removed hook.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 릴리스 — CHANGELOG + plugin.json + test_readme_sync (D4 CHANGELOG + D5)

**Files:**
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (기대 0.16.0)
- Modify: `plugins/spec-distill/CHANGELOG.md` (`[0.16.0]` 추가)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (version 0.16.0)

TDD: 먼저 test_readme_sync를 0.16.0 기대로 올려 RED를 보고, CHANGELOG + plugin.json을 채워 GREEN으로 전환한다.

- [ ] **Step 1: test_readme_sync.sh를 0.16.0 기대로 교체**

`plugins/spec-distill/tests/test_readme_sync.sh`의 전체 내용을 아래로 교체한다(버전 리터럴만 0.15.0 → 0.16.0, L2 주석의 feature 명칭 갱신; 나머지 구조 동일):

```bash
#!/usr/bin/env bash
# AC16 — README/plugin.json/CHANGELOG synced with v0.16.0 (SessionStart anchor removal).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
README="$REPO_ROOT/plugins/spec-distill/README.md"
PLUGIN_JSON="$REPO_ROOT/plugins/spec-distill/.claude-plugin/plugin.json"
CHANGELOG="$REPO_ROOT/plugins/spec-distill/CHANGELOG.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

grep -q '"version": "0.16.0"' "$PLUGIN_JSON" \
  && note PASS "AC16: plugin.json version 0.16.0" || note FAIL "AC16: plugin.json not 0.16.0"
grep -qE '^## \[0\.16\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC16: CHANGELOG [0.16.0] entry with ISO date" || note FAIL "AC16: CHANGELOG [0.16.0] missing/!ISO"
grep -qE '^## \[0\.16\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC16: CHANGELOG date has XX placeholder" || note PASS "AC16: no XX placeholder in date"

for kw in 'DEVBREW_SPEC_DISTILL_DISABLE_WEB' 'interview-brief' 'steelman-builder' 'cancel-review'; do
  grep -q "$kw" "$README" \
    && note PASS "AC16: README mentions $kw" || note FAIL "AC16: README missing $kw"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: test_readme_sync가 RED인지 확인 (TDD)**

Run:
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh; echo "exit=$?"
```
Expected: **FAIL (exit≠0)** — plugin.json이 아직 0.15.0이고 CHANGELOG에 `[0.16.0]`이 없으므로 두 단언이 ✗. RED 정상.

- [ ] **Step 3: CHANGELOG에 `[0.16.0]` 항목 추가**

`plugins/spec-distill/CHANGELOG.md`의 맨 위(`# Changelog` 다음, `## [0.15.0]` 앞)에 아래 블록을 삽입한다.

Before:
```markdown
# Changelog

## [0.15.0] — 2026-06-16
```
After:
```markdown
# Changelog

## [0.16.0] — 2026-06-16

### Removed
- `hooks/session-anchor.sh` (SessionStart 훅) + `hooks/hooks.json`의 SessionStart 등록. 이 훅은 이전 인터뷰 세션 디렉토리를 감지해 `/interview resume` 재진입을 안내했으나, `/interview resume`는 구현된 적이 없다(`commands/interview.md`에 resume 분기 부재) — state-storage 재설계에서 resume 커맨드가 사라진 뒤에도 안내 훅만 남아 매 세션 시작마다 실행 불가능한 조언을 LLM context에 주입하던 stale advisory였다. 훅은 P14 read-only advisor라 출력 소비처가 없고, 리뷰 흐름 상태(`pending_review`/`suppressed_paths`)는 UserPromptSubmit/Stop 훅이 독립 소비하므로 제거가 리뷰 파이프라인에 영향 없음. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Changed
- `tests/test_hooks.sh` — session-anchor 동작 테스트(기존 케이스 9–12)를 SessionStart 재도입 방지 회귀 락(hooks.json에 SessionStart 키 부재 + `session-anchor.sh` 파일 부재 두 단언)으로 재작성.
- `tests/test_hook_output_schema.py` — `TestSessionAnchorSchema` 클래스 및 `TestKillSwitches.test_global_disable_silences_session_anchor` 메서드 제거(`import shutil`은 다른 테스트가 사용하므로 유지).
- `README.md` — Hooks Installed 표의 SessionStart 행, Output schema 문장의 SessionStart 이벤트, Kill switches의 `DEVBREW_SKIP_HOOKS=spec-distill:SessionStart` 항목 제거.
- `tests/test_readme_sync.sh` — 버전 기대값 0.15.0 → 0.16.0.

## [0.15.0] — 2026-06-16
```

(이 CHANGELOG 항목은 `/interview resume`를 언급하지만 `CHANGELOG.md` 안이므로 AC3 grep에서 제외 대상 — dangling 아님.)

- [ ] **Step 4: plugin.json version bump**

`plugins/spec-distill/.claude-plugin/plugin.json`에서:

Before:
```json
  "version": "0.15.0",
```
After:
```json
  "version": "0.16.0",
```

- [ ] **Step 5: test_readme_sync가 GREEN으로 전환됐는지 확인 (TDD)**

Run:
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh; echo "exit=$?"
```
Expected: **PASS (exit 0)** — `Fail: 0`. Step 2의 RED가 GREEN.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "$(cat <<'EOF'
chore(spec-distill): bump to 0.16.0 (SessionStart anchor removal)

Add CHANGELOG [0.16.0] (Removed: session-anchor hook; Changed: tests + README),
bump plugin.json 0.15.0 → 0.16.0, and update test_readme_sync.sh expectations.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Final Verification (AC1–AC9 매핑)

모든 커밋 후 repo root에서 실행. 각 AC를 명령으로 검증한다.

- [ ] **AC1 — session-anchor.sh 부재**
```bash
test ! -e plugins/spec-distill/hooks/session-anchor.sh && echo "AC1 PASS" || echo "AC1 FAIL"
```

- [ ] **AC2 — hooks.json SessionStart 키 부재 + description 정리 + 유효 JSON**
```bash
python3 -c "import json; d=json.load(open('plugins/spec-distill/hooks/hooks.json')); assert 'SessionStart' not in d['hooks']; assert 'SessionStart anchor' not in d['description']; print('AC2 PASS', list(d['hooks'].keys()))"
```

- [ ] **AC3 — live 플러그인 resume 0건 (CHANGELOG 제외)**
```bash
grep -rni "resume" plugins/spec-distill --include='*.md' --include='*.sh' --include='*.py' --include='*.json' | grep -v "/CHANGELOG.md:"; echo "exit=$? (1=zero matches=PASS)"
```
Expected: 매치 없음 → `exit=1`. (CHANGELOG.md의 resume 언급은 grep -v로 제외; 아카이브 `docs/superpowers/plans/`는 스코프 밖이라 grep 대상 아님 — NG5.)

- [ ] **AC4 — README SessionStart 0건**
```bash
grep -n "SessionStart" plugins/spec-distill/README.md; echo "exit=$? (1=PASS)"
```

- [ ] **AC5 — plugin.json 0.16.0 + CHANGELOG [0.16.0] ISO 날짜**
```bash
grep -q '"version": "0.16.0"' plugins/spec-distill/.claude-plugin/plugin.json && echo "version PASS"
grep -qE '^## \[0\.16\.0\] — 2026-06-16$' plugins/spec-distill/CHANGELOG.md && grep -q '### Removed' plugins/spec-distill/CHANGELOG.md && echo "changelog PASS"
```

- [ ] **AC6 — 회귀 락 green**
```bash
bash plugins/spec-distill/tests/test_hooks.sh
```
Expected: `Results: 2 passed, 0 failed` (exit 0).

- [ ] **AC7 — output-schema 스위트 green**
```bash
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_hook_output_schema.py' -v 2>&1 | tail -5
```
Expected: `OK`.

- [ ] **AC8 — test_readme_sync green**
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh
```
Expected: `Fail: 0` (exit 0).

- [ ] **AC9 — 전체 스위트 회귀 0 (baseline 대비)**
```bash
echo "### PYTHON ###"
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -5
echo "### BASH ###"
for t in plugins/spec-distill/tests/test_*.sh; do
  if bash "$t" >/dev/null 2>&1; then echo "PASS $t"; else echo "FAIL $t"; fi
done
```
Expected: Pre-flight baseline에서 PASS였던 것은 전부 PASS 유지. 새로운 FAIL이 없어야 함(baseline의 pre-existing red는 무관). 특히 `test_hooks.sh`/`test_readme_sync.sh`/`test_hook_output_schema.py`는 PASS.

- [ ] **Law 2 리뷰 게이트 — `/qg`**

구현 완료 후 사용자가 `/qg`(또는 `/qg review`)를 실행해 spec-conformance 리뷰 게이트를 통과시킨다. 기준은 본 design의 AC1–AC9. (writing-plans 단계의 실행 모드 선택과는 별개 — 구현이 끝난 뒤의 별도 리뷰 단계.)

---

## Self-Review (작성자 점검 — 이미 수행)

1. **Spec coverage:** design의 D1→Task1(Step6–8), D2→Task1(Step1·10), D3→Task1(Step3–4), D4→Task2 + Task3(Step3), D5→Task3(Step1·4). G1–G4 / AC1–AC9 전부 task에 매핑됨. NG1–NG5는 "중요한 사전 지식" + AC3 스코프로 보호.
2. **Placeholder scan:** "TBD"/"적절히"/"등등" 없음. 모든 코드/명령 블록은 실제 내용. 삭제 대상은 verbatim 제공.
3. **Type/이름 일관성:** `HOOKS_JSON`/`ANCHOR` 변수, `note()` 헬퍼, 클래스명 `TestSessionAnchorSchema`/`TestKillSwitches`, 메서드명 `test_global_disable_silences_session_anchor` 모두 실제 소스와 일치(라인 확인 완료).
4. **TDD 순서 검증:** 회귀 락(Task1 Step1→2 RED, Step10 GREEN)과 test_readme_sync(Task3 Step1→2 RED, Step5 GREEN) 모두 fail-first. `.py` anchor 테스트는 파일 삭제 *전*(Step3–4)에 제거해 스위트가 깨지지 않도록 순서 고정.
5. **scope 판단:** `test_readme_sync.sh`의 `AC16:` 라벨은 v0.15.0 AC 넘버링의 잔재지만 design D5 스코프(버전 리터럴만)를 넘지 않기 위해 라벨은 그대로 두고 버전 리터럴만 갱신했다. 의도적 보수 선택.

## Notes

- **버전:** main = 0.15.0 → 작업 후 0.16.0 (minor — surface 제거).
- **머지:** GitHub Flow, **merge commit** (rebase 금지 — `feedback_git_merge_over_rebase`). PR로 main에 merge back.
- **관련 메모리:** `feedback_harness_lightness_trust_model`(회귀 락 2단언 한정), `reference_spec_distill_test_runner`(python은 `-m unittest`), `project_qg_pre_existing_test_reds`(baseline 캡처), `feedback_plugin_version_bump`(버전 bump).
