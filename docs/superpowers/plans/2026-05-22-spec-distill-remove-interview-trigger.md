# spec-distill interview-trigger + cleanup_stale_states 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 플러그인에서 dead code 2종(`interview-trigger.sh` advisory 훅 + `state_path.py:cleanup_stale_states()` deprecated no-op)과 모든 활성 참조를 제거하고 v0.7.0으로 bump한다.

**Architecture:** 순수 제거 PR. 표준 red-green TDD가 아니라 *제거 → 검증(기존 suite green + AC grep) → 커밋* 단위로 진행. review 강제 체인(spec-write-validator/review-dispatch/pending-review-reminder)·`/interview`·`session-anchor`·`resolve_session_id`/`state_root`는 불변. 근거 spec: `docs/superpowers/specs/2026-05-22-spec-distill-remove-interview-trigger-design.md`.

**Tech Stack:** bash, python3 (stdlib `unittest`), jq, git. devbrew 마켓플레이스 플러그인(Korean-primary 문서, plugin.json SemVer bump 필수).

---

## File Structure

| 파일 | 작업 | 책임 |
|---|---|---|
| `plugins/spec-distill/hooks/interview-trigger.sh` | 삭제 | advisory build nudge 훅 (dead) |
| `plugins/spec-distill/hooks/hooks.json` | 수정 | UserPromptSubmit 등록 + description |
| `plugins/spec-distill/hooks/state_path.py` | 수정 | cleanup_stale_states/DEPRECATION_MARKER/docstring/main 분기 제거 |
| `plugins/spec-distill/tests/test_state_cleanup.sh` | 삭제 | 제거된 함수 전용 테스트 |
| `plugins/spec-distill/tests/test_hook_output_schema.py` | 수정 | interview-trigger 테스트 클래스/메서드 + docstring 수 |
| `plugins/spec-distill/tests/test_hooks.sh` | 수정 | interview-trigger 섹션 (session-anchor 유지) |
| `plugins/spec-distill/README.md` | 수정 | Hooks Installed 표 행 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 수정 | version 0.6.0 → 0.7.0 |
| `plugins/spec-distill/CHANGELOG.md` | 수정 | v0.7.0 Removed 항목 |

**작업 디렉토리:** 이미 `feature/spec-distill-remove-interview-trigger` 브랜치에 있고 spec이 커밋(`6841dcb`)되어 있다. 모든 명령은 repo 루트 `/Users/jeonghokim/Downloads/devbrew`에서 실행.

---

## Task 1: interview-trigger.sh 훅 제거

**Files:**
- Delete: `plugins/spec-distill/hooks/interview-trigger.sh`
- Modify: `plugins/spec-distill/hooks/hooks.json`

- [ ] **Step 1: 훅 스크립트 파일 삭제**

```bash
git rm plugins/spec-distill/hooks/interview-trigger.sh
```

- [ ] **Step 2: hooks.json에서 등록 + description 수정**

`plugins/spec-distill/hooks/hooks.json`의 최상단 `description`을 (interview 제거):

```json
  "description": "spec-distill — UserPromptSubmit reminder, SessionStart anchor, PostToolUse spec/design validator, Stop reviewer dispatch, SessionEnd cleanup.",
```

그리고 `.hooks.UserPromptSubmit` 배열을 interview-trigger 엔트리 제거 후 다음으로 교체 (reminder만 남김):

```json
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "python3 ${CLAUDE_PLUGIN_ROOT}/hooks/pending-review-reminder.py",
            "timeout": 5
          }
        ]
      }
    ],
```

다른 4개 이벤트(SessionStart/PostToolUse/Stop/SessionEnd) 블록은 건드리지 않는다.

- [ ] **Step 3: hooks.json 유효성 + 구성 검증 (AC1/AC2/AC3/AC5)**

```bash
test ! -f plugins/spec-distill/hooks/interview-trigger.sh && echo "AC1 ok"
jq -e '.hooks.UserPromptSubmit[0].hooks | length == 1
       and (.[0].command | test("pending-review-reminder.py"))
       and (.[0].command | test("interview-trigger") | not)' \
   plugins/spec-distill/hooks/hooks.json && echo "AC2 ok"
jq -e '.hooks | keys == ["PostToolUse","SessionEnd","SessionStart","Stop","UserPromptSubmit"]' \
   plugins/spec-distill/hooks/hooks.json && echo "AC3 ok"
jq -e '.description | test("interview") | not' plugins/spec-distill/hooks/hooks.json && echo "AC5 ok"
```

Expected: `AC1 ok` / `AC2 ok` / `AC3 ok` (jq prints `true`) / `AC5 ok`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/hooks/hooks.json
git commit -m "refactor(spec-distill): remove interview-trigger hook (dead advisory, 0 firings)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: cleanup_stale_states 제거 (state_path.py + 전용 테스트)

**Files:**
- Modify: `plugins/spec-distill/hooks/state_path.py`
- Delete: `plugins/spec-distill/tests/test_state_cleanup.sh`

- [ ] **Step 1: 모듈 docstring의 `cleanup` CLI 줄 제거**

`state_path.py` 상단 docstring(lines 8–11)을 다음으로 교체 (`cleanup` 줄만 제거):

```python
CLI:
  python3 state_path.py state-root [<cwd>]    → prints absolute path to stdout
"""
```

- [ ] **Step 2: `DEPRECATION_MARKER` 상수 + `cleanup_stale_states()` 함수 전체 블록 제거**

`state_path.py`에서 `DEPRECATION_MARKER = ...` 줄(line 77)과 `def cleanup_stale_states(root: Path) -> None:` 함수 전체(정의·docstring·본문, lines 80–105)를 삭제한다. 삭제 후 `state_root()` 함수 다음에 바로 `def main(argv...)`가 오도록 한다. `SESSION_PATTERN`/`resolve_session_id`/`state_root`는 보존.

- [ ] **Step 3: `main()`의 `cleanup` 분기 + usage 토큰 제거**

`main()` 함수를 다음으로 교체:

```python
def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: state_path.py state-root [<cwd>]", file=sys.stderr)
        return 2
    sub = argv[1]
    if sub == "state-root":
        cwd = argv[2] if len(argv) >= 3 else None
        print(str(state_root(cwd)))
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2
```

- [ ] **Step 4: 전용 테스트 파일 삭제**

```bash
git rm plugins/spec-distill/tests/test_state_cleanup.sh
```

- [ ] **Step 5: 제거 완결성 + helper 보존 + import 무결성 검증 (AC6/AC7)**

```bash
! grep -rn "cleanup_stale_states\|DEPRECATION_MARKER" plugins/spec-distill --include='*.py' --include='*.sh' \
  && echo "AC7 ok (no active refs)"
! grep -in "cleanup" plugins/spec-distill/hooks/state_path.py && echo "AC6 no cleanup residue"
grep -q "def resolve_session_id" plugins/spec-distill/hooks/state_path.py \
  && grep -q "def state_root" plugins/spec-distill/hooks/state_path.py && echo "AC6 helpers preserved"
test ! -f plugins/spec-distill/tests/test_state_cleanup.sh && echo "AC7 test deleted ok"
# import 무결성: 다른 hook이 state_path를 import해도 깨지지 않음
python3 -c "import ast,sys; ast.parse(open('plugins/spec-distill/hooks/state_path.py').read()); print('state_path.py parses ok')"
python3 plugins/spec-distill/hooks/state_path.py state-root . >/dev/null && echo "state-root CLI ok"
```

Expected: `AC7 ok` / `AC6 no cleanup residue` / `AC6 helpers preserved` / `AC7 test deleted ok` / `state_path.py parses ok` / `state-root CLI ok`.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/hooks/state_path.py
git commit -m "refactor(spec-distill): remove deprecated cleanup_stale_states (v0.6.0 no-op)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: test_hook_output_schema.py 정리

**Files:**
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py`

- [ ] **Step 1: 모듈 docstring hook 수 갱신**

line 4를 다음으로 교체:

```python
Covers AC1–AC3 + AC5 (4 hook output schemas; AC4 interview-trigger removed v0.7.0), AC1a (encoding round-trip),
```

- [ ] **Step 2: `TestInterviewTriggerSchema` 클래스 제거**

`class TestInterviewTriggerSchema(HookOutputSchemaTestBase):`(line 368)부터 그 클래스의 마지막 메서드 끝(line 409, `TestSessionAnchorSchema` 직전)까지 클래스 전체를 삭제한다. `TestSessionAnchorSchema` 클래스(docstring "AC5", `AC5-a` 데코레이터 포함)는 **그대로 둔다** (renumber 하지 않음 — spec §AC8).

- [ ] **Step 3: `test_global_disable_silences_interview_trigger` 메서드 제거**

`def test_global_disable_silences_interview_trigger(self):` 메서드 전체(약 line 532–, 다음 메서드/클래스 직전까지)를 삭제한다. 같은 클래스의 다른 kill-switch 테스트는 보존.

- [ ] **Step 4: 잔여 참조 0 확인 + 테스트 통과 (AC8)**

```bash
! grep -n "interview-trigger\|interview_trigger\|InterviewTrigger" plugins/spec-distill/tests/test_hook_output_schema.py \
  && echo "no interview-trigger refs"
python3 plugins/spec-distill/tests/test_hook_output_schema.py && echo "AC8 ok"
```

Expected: `no interview-trigger refs`, 그리고 unittest 전체 통과 후 `AC8 ok`. (jq 환경에 따라 일부 `skipUnless`가 skip될 수 있으나 fail은 0이어야 함.)

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "test(spec-distill): drop interview-trigger schema cases (4 hooks)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: test_hooks.sh 정리 (session-anchor 유지)

**Files:**
- Modify: `plugins/spec-distill/tests/test_hooks.sh`

- [ ] **Step 1: `TRIGGER` 변수 정의 제거**

line 11 `TRIGGER="$PLUGIN_ROOT/hooks/interview-trigger.sh"`를 삭제한다. line 12 `ANCHOR="$PLUGIN_ROOT/hooks/session-anchor.sh"`는 보존.

- [ ] **Step 2: interview-trigger 테스트 섹션 제거**

`echo "=== interview-trigger.sh ==="`(line 27)부터 마지막 interview-trigger 테스트(`/interview prefix → silent` 블록, line 75)까지 삭제한다. `echo "=== session-anchor.sh ==="`(line 78) 이후 session-anchor 섹션과 lines 1–26의 공통 setup(PLUGIN_ROOT/note()/카운터/ANCHOR)은 보존. 파일은 **삭제하지 않는다**.

- [ ] **Step 3: 잔여 참조 0 + session-anchor 테스트 통과 (AC4 부분/AC9)**

```bash
! grep -n "interview-trigger\|TRIGGER" plugins/spec-distill/tests/test_hooks.sh && echo "no TRIGGER refs"
bash plugins/spec-distill/tests/test_hooks.sh && echo "AC9 ok (session-anchor tests pass)"
```

Expected: `no TRIGGER refs`, session-anchor 테스트 전부 PASS 후 `AC9 ok ...` (exit 0).

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/test_hooks.sh
git commit -m "test(spec-distill): drop interview-trigger cases from test_hooks.sh

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: README Hooks Installed 표 갱신

**Files:**
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: interview-trigger 행 제거**

`README.md` "Hooks Installed" 표에서 다음 행(line 99)을 삭제한다:

```markdown
| UserPromptSubmit | `hooks/interview-trigger.sh` | vague build/make 요청 감지 → advisory | 사용자 자동 prompt에 반응해야 함 (skill은 사용자가 invoke해야 동작). |
```

표의 나머지 5개 행(SessionStart / PostToolUse / Stop / UserPromptSubmit reminder / SessionEnd)과 "Output schema" 단락은 그대로 둔다 (additionalContext 설명의 `UserPromptSubmit` 언급은 reminder 훅에 여전히 유효).

- [ ] **Step 2: 잔여 참조 0 확인 (AC4/AC10)**

```bash
! grep -n "interview-trigger" plugins/spec-distill/README.md && echo "AC10 README ok"
```

Expected: `AC10 README ok`.

- [ ] **Step 3: 커밋**

```bash
git add plugins/spec-distill/README.md
git commit -m "docs(spec-distill): remove interview-trigger from Hooks Installed

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 버전 bump + CHANGELOG

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: plugin.json version bump**

`plugins/spec-distill/.claude-plugin/plugin.json`의 `"version": "0.6.0"`를 `"version": "0.7.0"`으로 변경.

- [ ] **Step 2: CHANGELOG v0.7.0 항목 추가**

`CHANGELOG.md` line 1 `# Changelog` 다음, `## [0.6.0] — 2026-05-19` 직전에 다음 섹션을 삽입:

```markdown
## [0.7.0] — 2026-05-22

### Removed
- `hooks/interview-trigger.sh` + `hooks.json` UserPromptSubmit 등록 — advisory build/make nudge 훅. ~80개 세션 트랜스크립트 hook-attachment 전수 스캔 결과 3주간 0회 발화 (trigger 조건 `키워드 + <20단어`가 실사용 프롬프트와 미매칭). 훅 surface는 review 강제(Law 2)로 정당화되며 interview 진입은 `/interview` 직접 호출로 충분 — advisory(`additionalContext`)는 모델이 무시 가능해 비결정적. `hooks.json` `description`에서 "interview" 문구 제거.
- `hooks/state_path.py`:`cleanup_stale_states()` 함수 전체 블록 + `DEPRECATION_MARKER` 상수 + 모듈 docstring `cleanup` CLI 줄 + `main()`의 `cleanup` 분기·usage 토큰 — v0.6.0에 deprecated된 no-op(약속대로 제거). 호출처 없음 (TTL-GC + SessionEnd hook이 정리 담당). `tests/test_state_cleanup.sh` 삭제.
- 테스트 정리: `tests/test_hook_output_schema.py`의 `TestInterviewTriggerSchema` + `test_global_disable_silences_interview_trigger`, `tests/test_hooks.sh`의 interview-trigger 섹션, `README.md` Hooks Installed 표의 interview-trigger 행.
```

- [ ] **Step 3: 버전/CHANGELOG 검증 (AC11/AC12)**

```bash
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.7.0" && echo "AC11 ok"
grep -q "## \[0.7.0\] — 2026-05-22" plugins/spec-distill/CHANGELOG.md && echo "AC12 ok"
```

Expected: `AC11 ok` / `AC12 ok`.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): bump to v0.7.0 + CHANGELOG (remove dead code)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 전체 검증 (spec Verification Plan 전량)

**Files:** 없음 (검증 전용)

- [ ] **Step 1: spec의 12개 AC 일괄 실행**

repo 루트에서 다음을 실행하고 모든 라인이 의도대로 출력되는지 확인:

```bash
# AC1
test ! -f plugins/spec-distill/hooks/interview-trigger.sh && echo "AC1 ok"
# AC2/AC3/AC5
jq -e '.hooks.UserPromptSubmit[0].hooks | length == 1
       and (.[0].command | test("pending-review-reminder.py"))
       and (.[0].command | test("interview-trigger") | not)' \
   plugins/spec-distill/hooks/hooks.json && echo "AC2 ok"
jq -e '.hooks | keys == ["PostToolUse","SessionEnd","SessionStart","Stop","UserPromptSubmit"]' \
   plugins/spec-distill/hooks/hooks.json && echo "AC3 ok"
jq -e '.description | test("interview") | not' plugins/spec-distill/hooks/hooks.json && echo "AC5 ok"
# AC4
! grep -rn "interview-trigger\|interview_trigger" plugins/spec-distill \
    --include='*.sh' --include='*.py' --include='*.json' --include='README.md' && echo "AC4 ok"
# AC6/AC7
! grep -rn "cleanup_stale_states\|DEPRECATION_MARKER" plugins/spec-distill --include='*.py' --include='*.sh' \
  && echo "AC7 ok"
! grep -in "cleanup" plugins/spec-distill/hooks/state_path.py && echo "AC6 no cleanup residue"
grep -q "def resolve_session_id" plugins/spec-distill/hooks/state_path.py \
  && grep -q "def state_root" plugins/spec-distill/hooks/state_path.py && echo "AC6 helpers preserved"
test ! -f plugins/spec-distill/tests/test_state_cleanup.sh && echo "AC7 test deleted ok"
# AC8/AC9
python3 plugins/spec-distill/tests/test_hook_output_schema.py && echo "AC8 ok"
if [ -f plugins/spec-distill/tests/test_hooks.sh ]; then
  bash plugins/spec-distill/tests/test_hooks.sh && echo "AC9 ok (tests pass)"
else
  echo "AC9 ok (file deleted)"
fi
# AC10
! grep -n "interview-trigger" plugins/spec-distill/README.md && echo "AC10 ok"
# AC11/AC12
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.7.0" && echo "AC11 ok"
grep -q "## \[0.7.0\] — 2026-05-22" plugins/spec-distill/CHANGELOG.md && echo "AC12 ok"
```

Expected: `AC1 ok` … `AC12 ok` 전부 출력 (중간 grep `!` 패턴은 매칭 0이면 통과).

- [ ] **Step 2: 전체 spec-distill 테스트 스위트 회귀 확인**

```bash
for t in plugins/spec-distill/tests/*.sh; do echo "--- $t ---"; bash "$t" || echo "FAIL: $t"; done
for t in plugins/spec-distill/tests/*.py; do echo "--- $t ---"; python3 "$t" || echo "FAIL: $t"; done
```

Expected: `FAIL:` 라인이 하나도 없어야 함. (삭제한 `test_state_cleanup.sh`는 목록에 없어야 정상.)

- [ ] **Step 3: PR 생성 (사용자 승인 후)**

사용자가 PR 생성을 승인하면:

```bash
git push -u origin feature/spec-distill-remove-interview-trigger
gh pr create --base main --title "refactor(spec-distill): remove interview-trigger + cleanup_stale_states dead code (v0.7.0)" \
  --body "$(cat <<'EOF'
## Summary
spec-distill v0.7.0 — dead code 2종 제거.

- **interview-trigger.sh**: advisory build nudge 훅. 트랜스크립트 전수 스캔 결과 3주간 0회 발화. 훅 surface는 review 강제(Law 2)로 정당화되며 interview 진입은 `/interview`로 충분.
- **cleanup_stale_states()**: v0.6.0에 deprecated된 no-op. CHANGELOG 약속대로 제거 (TTL-GC + SessionEnd hook이 정리 담당).

Spec: `docs/superpowers/specs/2026-05-22-spec-distill-remove-interview-trigger-design.md` (3 round adversarial spec-review 통과).

## Verification
- 12개 AC 전량 green (Task 7 Step 1)
- 전체 test suite 회귀 0 (Task 7 Step 2)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (작성자 체크리스트)

- **Spec coverage:** AC1(T1)·AC2/3/5(T1)·AC4(T1/T3/T4/T5/T7)·AC6/7(T2)·AC8(T3)·AC9(T4)·AC10(T5)·AC11/12(T6)·전량검증(T7) — spec의 12개 AC + Files-to-Modify 9개 파일 전부 task에 매핑됨. 누락 없음.
- **Placeholder scan:** TODO/TBD/"적절히"/"비슷하게" 없음. 제거 대상은 정확한 파일/라인/앵커로 지정, 편집 대상(hooks.json/state_path.py main·docstring/plugin.json/CHANGELOG/README 행)은 before→after 명시.
- **Type/identifier consistency:** `pending-review-reminder.py`, `resolve_session_id`, `state_root`, `SESSION_PATTERN`, `TestInterviewTriggerSchema`, `TestSessionAnchorSchema`, `test_global_disable_silences_interview_trigger`, `DEPRECATION_MARKER`, `cleanup_stale_states` — 전 task에서 철자 일관. hooks.json 키 정렬(`PostToolUse,SessionEnd,SessionStart,Stop,UserPromptSubmit`) AC3와 일치.
