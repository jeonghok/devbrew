# spec-distill 리뷰 락 session-id split 수정 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `reviewing-spec` 스킬이 리뷰 락·suppress·approve 를 훅과 동일한 harness session id 로 keyed 하도록 bridge 하여, `/compact`/resume 로 sid 가 drift 한 인터뷰-선행 플로우에서 Stop 재강제 루프를 봉쇄한다.

**Architecture:** `hooks/state_path.py` 에 env-only `session-id` CLI 서브커맨드를 추가하고(훅이 쓰는 `resolve_session_id` 재사용 = DRY 리졸버), `skills/reviewing-spec/SKILL.md` Step 1 이 그 CLI + `state-root` 로 상태 파일을 명시적으로 해석한 뒤 세 hook-facing 호출 지점(락 `set`·`pause`, `approve_handoff.sh`)에 `$harness_sid` 를 넘긴다. continuity 카운터(`rereview_count`/`issue_history`)의 읽기/쓰기는 **의도적으로 옮기지 않는다**(collapse 금지). 코드 변경은 CLI 1개 + 스킬 산문; 나머지는 grep/behavioral 회귀 락.

**Tech Stack:** Python 3.9+ (state_path.py, `-m unittest`), Bash (`tests/*.sh`, macOS `/bin/bash` 3.2 호환), Markdown skill 산문.

## Global Constraints

이 섹션의 값은 모든 task 에 암묵적으로 적용된다. 정확한 리터럴을 verbatim 으로 복사할 것.

- **소스에만 수정** — `plugins/spec-distill/` 아래만. `~/.claude/plugins/cache/` 는 절대 건드리지 않는다(C1).
- **브랜치** — `fix/spec-distill-review-lock-session-id` (main `00415d9` 에서 분기, 이미 체크아웃됨). merge over rebase — rebase 금지.
- **버전 bump** — `plugin.json` `0.18.0 → 0.19.0` (**minor**, patch 아님). 신규 CLI 서브커맨드 = 새 surface + 이 플러그인의 minor-for-fix 관례(C2).
- **테스트 실행 위치** — 항상 **repo root** 에서: `bash plugins/spec-distill/tests/<x>.sh` / `python3 -m unittest discover -s plugins/spec-distill/tests -p '<x>.py'` (C6, memory `reference_spec_distill_test_runner` — 직접 실행 금지).
- **fail-safe 방향 불변** — 락 부재/stale/env-unset 은 전부 정상 dispatch(리뷰 강제). 이 fix 는 리뷰 강제 계약(Law 1)을 약화하지 않는다(C5, G3).
- **continuity read collapse 금지** — `rereview_count`/`issue_history` 읽기(Step 1)·쓰기(Step 5)를 `$harness_sid` 로 치환하지 말 것. hook-facing trio(`pending_review`·lock·suppress)만 harness sid 로 고정(N1, C7, AC2c).
- **DRY 리졸버** — 스킬은 raw `$CLAUDE_CODE_SESSION_ID` 를 직접 읽지 않는다. 반드시 `state_path.py session-id`(= `resolve_session_id` 재사용, `DEVBREW_SPEC_DISTILL_SESSION_ID` override + charset/length 검증 경유)를 쓴다(C4).
- **grep teeth 함정** — 회귀 grep 은 헤더에 등장하지 않는 **명령-라인 고유 토큰**을 매치한다. POS/NEG fixture + 헤더-only/명령-삭제 mutation → red 로 teeth 증명(memory `feedback_grep_lock_header_satisfiable`).
- **한국어 primary 문서** — 스킬/CHANGELOG 산문은 한국어. 영어는 식별자/CLI/고유명사에 한정.

세 호출 지점의 정확한 최종 리터럴(모든 task 가 이 형태를 기준으로 grep/edit):
```
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" set "$harness_sid" "$spec_path"
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" pause "$harness_sid" "$spec_path"
bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/approve_handoff.sh" "$harness_sid" "$spec_path"
```
Step 1 상태 해석 리터럴(AC12 가 grep 하는 `state_path.py" session-id` 포함):
```
harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/hooks/state_path.py" session-id)"
ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/hooks/state_path.py" state-root)"
```

---

## Task 1: `state_path.py session-id` CLI 서브커맨드 (AC1, AC9)

env-only 리졸버 결과를 stdout 에 노출하는 서브커맨드. 스킬이 훅과 *정의상 동일한* sid 를 얻는 단일 진입점.

**Files:**
- Modify: `plugins/spec-distill/hooks/state_path.py:76-86` (`main()`)
- Test: `plugins/spec-distill/tests/test_session_id_resolution.sh` (확장 — 파일 끝에 케이스 추가)

**Interfaces:**
- Consumes: 기존 `resolve_session_id(payload: dict | None = None) -> str | None` (env-first: `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → payload). CLI 경로는 payload 가 없으므로 `resolve_session_id(None)` = env-only.
- Produces: `python3 state_path.py session-id` — 해석 성공 시 sid 를 stdout 에 print + **exit 0**; 미해석(env unset/charset·length 실패) 시 **stdout 무출력** + **exit 1**. (기존 `state-root` 서브커맨드는 무변경.)

- [ ] **Step 1: 실패하는 테스트 작성** — `test_session_id_resolution.sh` 의 마지막 케이스(Case 11) `if [[ "$fail" -gt 0 ]]` 블록 **직전**에 아래를 삽입한다. `env -i "PATH=$PATH"` clean-env 패턴을 재사용해 CLI 를 subprocess 로 구동한다:

```bash
# ── session-id 서브커맨드 (AC9 / T3) ──────────────────────────────────────
STATE_PATH="$HOOKS_DIR/state_path.py"

# call_session_id [KEY=VALUE ...] — runs `state_path.py session-id` in clean env,
# echoes "<stdout>|<exit_code>".
call_session_id() {
    local out rc
    out="$(env -i "PATH=$PATH" "$@" python3 "$STATE_PATH" session-id 2>/dev/null)"; rc=$?
    printf '%s|%s' "$out" "$rc"
}

# Case 12: env set (CLAUDE_CODE_SESSION_ID) → prints value, exit 0
res="$(call_session_id CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$res" == "ccsid-87654321|0" ]] \
    && note PASS "case 12: session-id prints resolved sid, exit 0" \
    || note FAIL "case 12: session-id set (got '$res')"

# Case 13: DEVBREW override precedence honored by CLI
res="$(call_session_id DEVBREW_SPEC_DISTILL_SESSION_ID=override-12345678 CLAUDE_CODE_SESSION_ID=ccsid-87654321)"
[[ "$res" == "override-12345678|0" ]] \
    && note PASS "case 13: session-id honors DEVBREW override" \
    || note FAIL "case 13: session-id override (got '$res')"

# Case 14: env unset → NO stdout ("<none>" 미출력) + exit 1
res="$(call_session_id)"
[[ "$res" == "|1" ]] \
    && note PASS "case 14: session-id unset → empty stdout + exit 1" \
    || note FAIL "case 14: session-id unset (got '$res')"

# Case 15: charset reject (spaces) → empty stdout + exit 1
res="$(call_session_id 'CLAUDE_CODE_SESSION_ID=with spaces')"
[[ "$res" == "|1" ]] \
    && note PASS "case 15: session-id charset reject → empty + exit 1" \
    || note FAIL "case 15: session-id charset reject (got '$res')"
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_session_id_resolution.sh`
Expected: Case 12–15 **FAIL** — 현재 `main()` 은 `session-id` 를 모르는 서브커맨드로 취급해 `unknown subcommand: session-id` stderr + **exit 2** (`"|2"` 아니라 stdout 빈+rc 2 → Case 12/13 은 `ccsid...|0` 기대에 불일치, Case 14/15 는 `|1` 기대인데 실제 `|2` → 불일치). "PASSED: 11 cases" 대신 "FAILED: N case(s)".

- [ ] **Step 3: 최소 구현** — `state_path.py` `main()` 의 `state-root` 분기 **뒤, `unknown subcommand` print 앞**에 서브커맨드를 추가한다. 파일 상단 docstring 의 CLI 예시도 갱신:

`main()` 편집 (현 76–86 라인):
```python
def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print("usage: state_path.py {state-root|session-id} [<cwd>]", file=sys.stderr)
        return 2
    sub = argv[1]
    if sub == "state-root":
        cwd = argv[2] if len(argv) >= 3 else None
        print(str(state_root(cwd)))
        return 0
    if sub == "session-id":
        # env-only resolve (no hook payload on the CLI path); mirrors what the
        # Stop/UserPromptSubmit/PostToolUse hooks resolve so the skill keys the
        # review lock to the SAME state file the hooks read. Unresolved → exit 1
        # with NO stdout (caller treats empty as "skip lock, keep enforcement").
        sid = resolve_session_id(None)
        if sid is None:
            return 1
        print(sid)
        return 0
    print(f"unknown subcommand: {sub}", file=sys.stderr)
    return 2
```

docstring CLI 블록(현 8–10 라인) 갱신:
```python
CLI:
  python3 state_path.py state-root [<cwd>]    → prints absolute path to stdout
  python3 state_path.py session-id            → prints env-resolved session id (exit 1 if unresolved)
```

- [ ] **Step 4: 테스트 실행 → 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_session_id_resolution.sh`
Expected: **PASSED: 15 cases** (기존 11 + 신규 4). 기존 케이스 회귀 0.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/hooks/state_path.py plugins/spec-distill/tests/test_session_id_resolution.sh
git commit -m "$(cat <<'EOF'
feat(spec-distill): add state_path.py session-id CLI subcommand (AC1/AC9)

env-only resolver surface so reviewing-spec keys the review lock to the same
harness sid the hooks read. Unresolved → exit 1, empty stdout.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: reviewing-spec SKILL.md — Step 1 해석 + 세 지점 `$harness_sid` + 산문 (AC2–AC5, AC11–AC13)

이 fix 의 핵심. Step 1 이 상태 파일을 harness sid + state-root 로 명시 해석하고, 세 hook-facing 호출 지점에 `$harness_sid` 를 넘기며, degradation/non-collapse/불변식 산문을 추가한다. **단일 파일 편집**이라 grep 회귀 락(POS/NEG + window)을 먼저 작성해 RED 를 본 뒤 한 번에 편집한다.

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (Step 1 = 현 18–26; ④ pause = 현 117–119; Approve handoff = 현 135–137)
- Test: `plugins/spec-distill/tests/test_reviewing_spec_lock.sh` (확장 — 기존 4 단언 유지, 신규 단언 추가)

**Interfaces:**
- Consumes: Task 1 의 `state_path.py session-id` (Step 1 이 호출) + 기존 `state_path.py state-root`. 기존 `review_lock.py {set|pause}` / `approve_handoff.sh` CLI (sid passthrough — 로직 무변경).
- Produces: SKILL.md 에 정확한 3 리터럴(Global Constraints 참조) + body-unique 산문 리터럴 3개: `리뷰 락 refresh skip (리뷰 강제 유지)`, `이 stop/approve는 기록되지 않음`, `continuity read collapse 금지`.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_reviewing_spec_lock.sh` 의 `echo` summary(현 46–48 라인) **직전**에 아래를 삽입한다. 기존 AC1/AC2/AC14a/AC14b 단언은 그대로 둔다:

```bash
# ── v0.19.0 harness-sid bridge 회귀 락 ────────────────────────────────────
# 윈도우 추출: ASCII-stable 구조 앵커로 각 호출 지점의 섹션만 잘라 grep(섹션 배치 증명).
step1_window()  { sed -n '/^## Steps$/,/^## Deterministic Routing Table/p' "$SKILL"; }
pause_window()  { sed -n '/^## Phase 5 Human Gate/,/^## Approve handoff sequence/p' "$SKILL"; }
appr_window()   { sed -n '/^## Approve handoff sequence/,/^## In-flight state migration/p' "$SKILL"; }

# AC8-a: Step 1 락 set 이 $harness_sid (NOT $session_id) — 자기 윈도우 안에서.
step1_window | grep -qF 'review_lock.py" set "$harness_sid' \
  && ! { step1_window | grep -qF 'review_lock.py" set "$session_id'; } \
  && note PASS "AC8-a: Step1 set uses \$harness_sid, not \$session_id" \
  || note FAIL "AC8-a: Step1 set not keyed to \$harness_sid"

# AC8-b: Phase 5 ④ pause 가 $harness_sid — pause 윈도우 안에서.
pause_window | grep -qF 'review_lock.py" pause "$harness_sid' \
  && ! { pause_window | grep -qF 'review_lock.py" pause "$session_id'; } \
  && note PASS "AC8-b: ④ pause uses \$harness_sid" \
  || note FAIL "AC8-b: ④ pause not keyed to \$harness_sid"

# AC8-c: Approve handoff 가 $harness_sid — approve 윈도우 안에서.
appr_window | grep -qF 'approve_handoff.sh" "$harness_sid' \
  && ! { appr_window | grep -qF 'approve_handoff.sh" "$session_id'; } \
  && note PASS "AC8-c: approve_handoff uses \$harness_sid" \
  || note FAIL "AC8-c: approve_handoff not keyed to \$harness_sid"

# AC8 teeth (POS/NEG discrimination — 명령-삭제/헤더-only mutation → red 증명).
POS=$(mktemp); NEG=$(mktemp)
printf '%s\n' 'noise' 'review_lock.py" set "$harness_sid" "$spec_path"' 'noise' > "$POS"
printf '%s\n' 'noise' '## Steps (header only, command removed)' 'noise' > "$NEG"
if grep -qF 'review_lock.py" set "$harness_sid' "$POS" \
   && ! grep -qF 'review_lock.py" set "$harness_sid' "$NEG"; then
  note PASS "AC8-teeth: harness_sid grep discriminates command-present vs header-only"
else
  note FAIL "AC8-teeth: grep failed to discriminate"
fi
rm -f "$POS" "$NEG"

# 강화된 count (round-3 advisory): 정확히 3개 명령이 "$harness_sid" "$spec_path" 로 끝남.
# 산문의 $harness_sid 언급은 이 접미 패턴에 매치 안 되므로 prose-immune·header-immune.
cnt=$(grep -cE '\$harness_sid" "\$spec_path"' "$SKILL")
[[ "$cnt" -eq 3 ]] \
  && note PASS "AC8-count: exactly 3 trio commands key \$harness_sid (got $cnt)" \
  || note FAIL "AC8-count: expected 3 harness_sid trio commands, got $cnt"

# AC12: Step 1 이 state_path.py session-id 로 read 를 해석(read==write 디렉토리) — Step1 윈도우.
step1_window | grep -qF 'state_path.py" session-id' \
  && note PASS "AC12: Step 1 resolves state via state_path.py session-id" \
  || note FAIL "AC12: Step 1 missing session-id read resolution"

# AC11: degradation exact-literal 두 개(grep -F, body-unique, header 아님).
grep -qF '리뷰 락 refresh skip (리뷰 강제 유지)' "$SKILL" \
  && note PASS "AC11-a: set degradation exact literal present" \
  || note FAIL "AC11-a: missing '리뷰 락 refresh skip (리뷰 강제 유지)'"
grep -qF '이 stop/approve는 기록되지 않음' "$SKILL" \
  && note PASS "AC11-b: pause/approve degradation exact literal present" \
  || note FAIL "AC11-b: missing '이 stop/approve는 기록되지 않음'"

# AC13: continuity non-collapse 가드 프로즈.
grep -qF 'continuity read collapse 금지' "$SKILL" \
  && note PASS "AC13: continuity non-collapse guard prose present" \
  || note FAIL "AC13: missing 'continuity read collapse 금지'"
```

> **주의(bash 3.2 문법):** `step1_window | grep ...` 처럼 함수를 파이프 좌변에 두는 형태는 유효하다(함수 호출은 명령). `sed` 의 Korean 앵커는 바이트 매치라 macOS `/bin/bash` 3.2 에서도 동작한다. 삽입 후 반드시 `bash -n` 으로 파싱 검증(아래 Step 2 에 포함).

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash -n plugins/spec-distill/tests/test_reviewing_spec_lock.sh && bash plugins/spec-distill/tests/test_reviewing_spec_lock.sh`
Expected: `bash -n` 무출력(문법 OK). 실행 시 **AC8-a/b/c, AC8-count, AC12, AC11-a/b, AC13 모두 FAIL** — 현 SKILL 은 세 지점이 `$session_id` 이고, Step 1 에 `state_path.py session-id` 해석·degradation·non-collapse 산문이 없다. 기존 AC1/AC2/AC14a/AC14b 는 PASS(변경 전이라 유지). AC8-teeth 는 fixture-only 라 PASS.

- [ ] **Step 3: SKILL.md 편집 (a) — Step 1 재작성** — 현 18–26 라인(`1. **Load state.local.md** …` 부터 `이 락은 subagent … 재개된다(fail-safe = 강제).` 블록까지)을 아래로 교체한다:

````markdown
1. **Load state.local.md (hook-facing 상태는 harness sid 로 명시 해석)** — 먼저 훅(Stop/UserPromptSubmit/PostToolUse)이 읽는 파일과 *정의상 동일한* harness session id + state root 로 상태 파일을 연다. 훅은 raw sid 가 아니라 `resolve_session_id`(env-first: `DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID` → payload)를 쓰므로, 스킬도 같은 리졸버를 CLI 로 재사용한다(DRY, C4):

   ```bash
   harness_sid="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/hooks/state_path.py" session-id)"
   ROOT="$(python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/hooks/state_path.py" state-root)"
   STATE="$ROOT/$harness_sid/state.local.md"   # 훅이 읽는 바로 그 파일
   ```

   이 `$STATE` 에서 `pending_review:`(→ `spec_path`·`mode`)를 읽는다. PostToolUse `spec-write-validator.py` 가 `pending_review:` 를 **항상 harness-sid 디렉토리**에 기록하므로, **read==write 디렉토리 불변식**(스킬의 pending/spec READ 와 락·suppress·approve WRITE 가 같은 `$STATE` 를 가리킴)이 성립해야 락이 훅에 보인다. block 이 없으면 manual override(loud advisory). v0.12.0부터 **design mode 전용**: 11-section/locked_decisions schema 검사는 적용 안 함(brainstorming 자유 형식). 본문의 placeholder/ambiguity/scope-creep/approaches-comparison/isolation/testing/handoff_incomplete만 spec-reviewer 에게 요청.

   **불변식 (hook-facing trio vs continuity):** hook-facing trio(`pending_review`·lock·suppress)의 read/write 는 harness sid(`$STATE`); `rereview_count`/`issue_history` continuity 는 이 fix 가 건드리지 않고 harness-sid 로 collapse 하지 않는다.

   **continuity read collapse 금지** — `rereview_count`/`issue_history`(아래 Step 5 에서 갱신) continuity 카운터는 인터뷰 선행 시 interview-UUID 파일(`conducting-interview/SKILL.md:35` self-`session_id`, `:41` `rereview_count`, `:43` `issue_history`)에 누적된다. **이 카운터의 읽기(이 Step)·쓰기(Step 5)를 `$harness_sid` 로 옮기지 말 것** — 옮기면 인터뷰-선행 플로우에서 `rereview_count` 가 0 으로 리셋돼 re-review cap(5)/round-level stagnation 조기-exit 가 약화된다. continuity 는 기존 메커니즘대로 읽고 쓴다(N1). 훅은 이 신호를 읽지 않으므로 read==write 불변식 대상이 아니다.

**리뷰 락 refresh (v0.18.0; v0.19.0: harness sid keying)** — state 로드 직후, `spec-reviewer` dispatch *전에* 이 문서의 review-in-progress 락을 harness sid 로 갱신한다 (매 진입 — 최초 + revise 재진입):

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" set "$harness_sid" "$spec_path"
```

   `$harness_sid` 가 빈 값(env unset → `state_path.py session-id` exit 1)이면 **리뷰 락 refresh skip (리뷰 강제 유지)** — 조용히 넘어가지 말고 advisory 를 남긴다. 락을 못 걸어도 Law 1 fail-safe 방향(락 부재 = 정상 dispatch = 리뷰 강제)이라 안전하다.

이 락은 subagent(async) 경계에서 발생하는 메인 `Stop`이 진행 중인 리뷰를 재강제(중복/절단)하지 않도록 `review-dispatch.py`(Stop)와 `pending-review-reminder.py`(UserPromptSubmit)가 참조한다. 락은 **문서별**이라 다른 문서의 최초 강제는 억제하지 않으며, stale(TTL 1800s 초과) 시 강제가 재개된다(fail-safe = 강제).
````

- [ ] **Step 4: SKILL.md 편집 (b) — ④ pause 를 `$harness_sid` 로 + degradation** — 현 117–119 라인의 pause 코드 블록을 교체하고, 블록 **뒤**(현 121 라인 `④에서 엔트리만 …` 문단 앞)에 degradation 문단을 추가한다:

pause 코드 블록(현 117–119):
```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/review_lock.py" pause "$harness_sid" "$spec_path"
```

pause 코드 블록 직후에 삽입할 degradation 문단(현 `④에서 엔트리만 제거하고 …` 앞):
```markdown
`$harness_sid` 가 빈 값이면 pause(④)·approve(①②) 모두 harness-sid 파일에 반영할 수 없다 — 조용히 swallow 하지 말고 **이 stop/approve는 기록되지 않음** 을 advisory 로 알리고 `/spec-distill:cancel-review <path>` 수동 억제 경로를 안내한다(다음 세션에서 재-arm 가능).
```

- [ ] **Step 5: SKILL.md 편집 (c) — Approve handoff 를 `$harness_sid` 로** — 현 135–137 라인의 코드 블록을 교체한다:

```bash
bash "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/approve_handoff.sh" "$harness_sid" "$spec_path"
```

> 참고: 이 세 지점 외에는 `$session_id` 가 SKILL.md 에 남지 않아야 한다(편집 후 `grep -c '\$session_id' SKILL.md` → 0 기대; continuity 는 shell 변수가 아니라 Step 5 산문 "rereview_count += 1" 이므로 `$session_id` 참조 없음). `$harness_sid" "$spec_path"` 접미는 정확히 3회.

- [ ] **Step 6: 테스트 실행 → 통과 확인 + 편집 검증**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/spec-distill/tests/test_reviewing_spec_lock.sh
grep -c '\$harness_sid" "\$spec_path"' plugins/spec-distill/skills/reviewing-spec/SKILL.md   # → 3
grep -c '"\$session_id"' plugins/spec-distill/skills/reviewing-spec/SKILL.md                 # → 0
```
Expected: 모든 단언(기존 4 + 신규 AC8-a/b/c, AC8-teeth, AC8-count, AC12, AC11-a/b, AC13) **PASS**, `Fail: 0`. count grep → `3`, session_id grep → `0`.

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/spec-distill/tests/test_reviewing_spec_lock.sh
git commit -m "$(cat <<'EOF'
fix(spec-distill): key reviewing-spec review-lock trio to harness sid (AC2-AC5)

Step 1 resolves state via state_path.py session-id + state-root; the three
hook-facing call sites (lock set/pause, approve_handoff.sh) now pass
$harness_sid so the lock lands in the file the hooks read. Adds degradation
+ continuity non-collapse prose. Closes the interview-originated Stop
re-force loop (v0.18.0 lock was keyed to the interview UUID).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: T1 behavioral 훅 repro (신규 `test_review_lock_session_id.sh`, AC7)

Handoff Context 의 결정론적 훅 repro 를 코드화한 characterization + 회귀 락. **RED-before-fix 아님**(Stop 훅은 v0.18.0부터 harness-sid 락을 이미 존중 — 버그는 스킬의 keying 이고 그 teeth 는 Task 2 AC8). 이 테스트는 "mis-keyed 락은 훅을 막지 못하고(fail-safe = block), correctly-keyed 락은 훅을 no-op 한다"는 메커니즘을 **두 assert 공존**으로 잠근다(G4). 훅의 `is_review_active` 게이트나 fail-safe 가 회귀하면 red.

**Files:**
- Create: `plugins/spec-distill/tests/test_review_lock_session_id.sh`
- Uses (무변경): `hooks/review-dispatch.py`, `scripts/review_lock.py`

**Interfaces:**
- Consumes: `review_lock.py set <sid> <raw_path>` CLI(state 를 `state_file_for(sid)` 에 씀 — cwd 의 git-common-dir 기준 state-root), `review-dispatch.py`(stdin payload `{"session_id":...}` + `DEVBREW_SPEC_DISTILL_SESSION_ID` env 로 harness sid 해석). doc 은 in-scope(`docs/superpowers/specs/…-design.md`)여야 `canonical_key` 가 살아있음.
- Produces: pass/fail summary, exit 0 on all-pass.

- [ ] **Step 1: 테스트 파일 작성** — `test_review_dispatch.sh` 의 mktemp+git-init 패턴을 따른다:

```bash
#!/usr/bin/env bash
# AC7 (T1) — review-lock session-id split 의 결정론적 훅-레벨 repro.
# mis-keyed(interview UUID) 락 → 훅이 못 봄 → dispatch(block); correctly-keyed
# (harness sid) 락 → 훅이 봄 → no-op(빈 stdout). 두 assert 공존.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"
LOCK="$REPO_ROOT/plugins/spec-distill/scripts/review_lock.py"
WORK=$(mktemp -d -t specdistill-locksid-XXXXXX)
WORK=$(cd "$WORK" && pwd -P)   # macOS /var → /private/var 정규화 (Path.resolve 일치)
trap 'rm -rf "$WORK"' EXIT

# git-aware state_root 경로를 실제로 태움 (fallback 마스킹 방지).
( cd "$WORK" && git init -q && git config user.email t@t.t \
  && git config user.name t && git commit -q --allow-empty -m seed )

HSID="hsid-aaaaaaaa"        # harness sid (훅이 payload/env 로 해석)
IUUID="iuuid-bbbbbbbb"      # interview UUID (버그: 스킬이 락을 여기에 걺)
DOC="docs/superpowers/specs/2026-07-05-locksid-design.md"
pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# harness-sid state 에 pending_review(doc) 시드 (last_dispatched 없음 → TTL 무관).
seed_pending() {
  mkdir -p "$WORK/.claude/spec-distill/$HSID"
  printf -- '---\nsession_id: %s\n---\n\npending_review:\n  path: %s\n  mode: design\n  triggered_at: 2026-05-16T10:00:00Z\n' \
    "$HSID" "$DOC" > "$WORK/.claude/spec-distill/$HSID/state.local.md"
}

run_hook() {
  cd "$WORK" && DEVBREW_SPEC_DISTILL_SESSION_ID="$HSID" \
    bash -c "printf '%s' '{\"session_id\":\"$HSID\"}' | python3 '$HOOK'" 2>/dev/null
}

# ── RED-repro: 락을 interview UUID 에 걸면 harness-sid 파일엔 없어 훅이 dispatch ──
seed_pending
( cd "$WORK" && python3 "$LOCK" set "$IUUID" "$DOC" )   # 버그 시나리오: 잘못된 sid
out=$(run_hook)
echo "$out" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && note PASS "AC7-repro: mis-keyed(interview UUID) lock → hook dispatches (block present)" \
  || note FAIL "AC7-repro: expected block with interview-UUID lock (out='$out')"

# ── GREEN: 락을 harness sid 에 걸면 훅이 보고 no-op(빈 stdout) ──
seed_pending                                            # dispatch 가 pending 소비했으니 재시드
( cd "$WORK" && python3 "$LOCK" set "$HSID" "$DOC" )    # fix 시나리오: 올바른 sid
out=$(run_hook)
[[ -z "$out" ]] \
  && note PASS "AC7-fix: harness-sid lock → hook no-op (empty stdout)" \
  || note FAIL "AC7-fix: expected empty stdout with harness-sid lock (out='$out')"

echo
echo "summary: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: 테스트 실행 → 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash -n plugins/spec-distill/tests/test_review_lock_session_id.sh && bash plugins/spec-distill/tests/test_review_lock_session_id.sh`
Expected: `bash -n` 무출력. 실행 시 **AC7-repro PASS + AC7-fix PASS** (`0 failed`). 두 assert 공존이 메커니즘을 양방향으로 잠금.

- [ ] **Step 3: teeth 확인(수동, 옵션) — 락 게이트 회귀 감지 증명**

`hooks/review-dispatch.py` 의 review-lock 게이트(현 165–168 라인 `if pending_key is not None and review_lock.is_review_active(...)` → `return 0`)를 임시로 주석 처리하면 GREEN assert(AC7-fix)가 red 가 됨을 육안 확인 후 **되돌린다**(커밋하지 않음). 게이트가 load-bearing 임을 증명.

- [ ] **Step 4: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/tests/test_review_lock_session_id.sh
git commit -m "$(cat <<'EOF'
test(spec-distill): T1 behavioral hook repro for review-lock session-id split (AC7)

Deterministic two-assert lock: mis-keyed(interview UUID) lock → hook dispatches;
harness-sid lock → hook no-op. Codifies the Handoff Context repro; guards the
is_review_active gate + fail-safe direction against regression.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: cancel_review 회귀 락 (AC10)

`cancel_review.py` 가 `resolve_session_id()`(env-first harness sid)를 계속 쓰는지 잠근다 — 미래에 interview-UUID 인자로 되돌리는 회귀 차단. `cancel_review.py` 는 **무변경**(이미 옳음); 테스트만 추가한다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_cancel_review.py` (`TestSuppressState` 에 소스-계약 테스트 1개 추가)
- Asserts against (무변경): `scripts/cancel_review.py`

**Interfaces:**
- Consumes: `cancel_review.py` 소스 텍스트.
- Produces: `test_ac10_cancel_uses_env_resolver` — 소스가 `from state_path import resolve_session_id` 를 import 하고 `resolve_session_id()` 를 **인자 없이**(env-first) 호출하며, sid 를 `sys.argv`/`argv[1]` 에서 취하지 않음을 단언.

- [ ] **Step 1: 실패하는 테스트 작성** — `test_cancel_review.py` `TestSuppressState` 클래스 안(예: `test_no_prefix_slice_outside_suppress_state` 뒤)에 추가:

```python
    def test_ac10_cancel_uses_env_resolver(self):  # AC10 회귀 락
        """cancel_review.py 는 env-first resolve_session_id() 를 계속 써야 한다.
        interview-UUID arg 로 되돌리는 회귀(예: sid = argv[1]) 를 차단."""
        src = (SCRIPTS / "cancel_review.py").read_text(encoding="utf-8")
        self.assertIn("from state_path import resolve_session_id", src,
                      "cancel_review must import the env-first resolver")
        self.assertIn("resolve_session_id()", src,
                      "cancel_review must call resolve_session_id() (no sid arg)")
        # sid 를 위치 인자에서 취하는 회귀 패턴 부재.
        for regression in ("sid = argv[1]", "sid = args[0]", "sid = sys.argv[1]"):
            self.assertNotIn(regression, src,
                             f"cancel_review must not key sid from CLI arg ({regression})")
```

- [ ] **Step 2: 테스트 실행 → 통과 확인 (특성 테스트)**

Run: `cd /Users/jeonghokim/Downloads/devbrew && python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_cancel_review.py' -v 2>&1 | tail -25`
Expected: `test_ac10_cancel_uses_env_resolver` **PASS** (cancel_review 는 이미 `resolve_session_id()` 사용 — 현행 :27 import, :51 호출). 전체 스위트 회귀 0.

- [ ] **Step 3: teeth 확인(수동, 옵션)** — `cancel_review.py:51` 의 `sid = resolve_session_id()` 를 임시로 `sid = sys.argv[1]` 로 바꾸면 이 테스트가 red 됨을 육안 확인 후 **되돌린다**(커밋 없음). 회귀 락이 실제 teeth 를 가짐을 증명.

- [ ] **Step 4: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/tests/test_cancel_review.py
git commit -m "$(cat <<'EOF'
test(spec-distill): lock cancel_review to env-first resolver (AC10)

Regression lock: cancel_review.py must keep resolve_session_id() (env-first
harness sid) and never key sid from a CLI arg. cancel_review itself unchanged.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: 버전 bump + CHANGELOG + version-sync (AC6, AC14)

`plugin.json` `0.18.0 → 0.19.0`, CHANGELOG `[0.19.0]` `### Fixed` + `### Added`, 그리고 **`test_readme_sync.sh` 의 하드코딩된 `0.18.0` 기대값 동기화**.

> **⚠ 스펙 Files-to-Modify 표 addendum:** 설계 문서의 표는 `tests/test_readme_sync.sh` 를 누락했다. 이 파일은 `"version": "0.18.0"` 를 하드-assert 하므로(현 :2 주석, :13 plugin.json grep, :15 CHANGELOG grep), plugin.json 을 bump 하면 **AC14(회귀 0)가 깨진다**. 메커니즘상 필수라 이 task 에 포함한다(memory `project_spec_distill_wall_clock_removal` "숨은 7번째 파일" 선례). README 산문 버전은 이 플러그인이 릴리스마다 bump 하지 않는 관례(0.15.0 이후 Flow 헤더 미갱신)라 스펙 스코프대로 **건드리지 않는다**(scope-creep 회피).

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json:4`
- Modify: `plugins/spec-distill/CHANGELOG.md` (상단에 `[0.19.0]` 블록 삽입)
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh:2,13-14,15-16`

**Interfaces:**
- Consumes: 없음.
- Produces: `test_readme_sync.sh` 가 `0.19.0` 을 기대하도록 갱신 → plugin.json/CHANGELOG 와 동기.

- [ ] **Step 1: test_readme_sync.sh 를 0.19.0 기대로 갱신(먼저 → RED)** — 세 지점 편집:

주석(현 :2):
```bash
# AC16 — README/plugin.json/CHANGELOG synced with v0.19.0 (review-lock session-id bridge).
```
plugin.json version grep(현 :13–14):
```bash
grep -q '"version": "0.19.0"' "$PLUGIN_JSON" \
  && note PASS "AC16: plugin.json version 0.19.0" || note FAIL "AC16: plugin.json not 0.19.0"
```
CHANGELOG grep(현 :15–16):
```bash
grep -qE '^## \[0\.19\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC16: CHANGELOG [0.19.0] entry with ISO date" || note FAIL "AC16: CHANGELOG [0.19.0] missing/!ISO"
```
XX-placeholder guard(현 :17–18)의 `0\.18\.0` → `0\.19\.0`:
```bash
grep -qE '^## \[0\.19\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC16: CHANGELOG date has XX placeholder" || note PASS "AC16: no XX placeholder in date"
```

- [ ] **Step 2: 테스트 실행 → 실패 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: **FAIL** — plugin.json 은 아직 `0.18.0`, CHANGELOG 에 `[0.19.0]` 없음. (README keyword 단언은 여전히 PASS.)

- [ ] **Step 3: plugin.json bump** — `.claude-plugin/plugin.json:4`:
```json
  "version": "0.19.0",
```

- [ ] **Step 4: CHANGELOG 상단에 [0.19.0] 블록 삽입** — 현 `# Changelog` (:1) 와 `## [0.18.0]` (:3) 사이에 삽입(날짜는 실제 구현일; 오늘 기준 `2026-07-05`):

```markdown
## [0.19.0] — 2026-07-05

### Fixed
- **review-lock session-id split → Stop 재강제 루프**: `reviewing-spec` 스킬이 리뷰 락·suppress·approve 를 **interview UUID** 로 keyed 했으나 훅(Stop/UserPromptSubmit/PostToolUse)은 **harness sid**(`resolve_session_id` env-first)로 상태를 읽어, 두 파일이 갈려 `is_review_active` 가 락을 못 찾고 `False`(fail-safe = 강제)를 반환 → v0.18.0 이 막으려던 subagent-경계 Stop 재강제가 **인터뷰-선행 플로우에서 여전히 발생**했다(harness sid 는 `/compact`/resume 에서 drift, interview UUID 는 stable). `reviewing-spec/SKILL.md` Step 1 이 `state_path.py session-id` + `state-root` 로 상태 파일을 명시 해석하고 세 hook-facing 호출 지점(락 `set`·`pause`, `approve_handoff.sh`)에 `$harness_sid` 를 넘겨 락·suppress·approve 가 훅이 읽는 파일에 기록되게 한다(read==write 디렉토리 불변식). approve 후 같은 design 재편집 시 재-arm 도 함께 해소(suppress 대칭 복원). `cancel_review.py`·`approve_handoff.sh`·`review_lock.py` 는 무변경(각각 이미 harness sid 이거나 sid passthrough). continuity(`rereview_count`/`issue_history`)는 harness-sid 로 collapse 하지 않아 인터뷰-선행 re-review cap/stagnation 을 보존(N1).

### Added
- `hooks/state_path.py` — `session-id` CLI 서브커맨드: env-only `resolve_session_id(None)` 결과를 stdout 에 print(exit 0), 미해석 시 stdout 무출력 + exit 1. 스킬과 훅이 *정의상 동일한* sid 를 얻는 단일 진입점(DRY 리졸버).
- `tests/test_review_lock_session_id.sh`(T1 behavioral 훅 repro) + `tests/test_reviewing_spec_lock.sh`·`tests/test_session_id_resolution.sh`·`tests/test_cancel_review.py` 회귀 락 확장(세 지점 mutation POS/NEG + degradation exact-literal + continuity non-collapse + cancel_review env-resolver 계약).
```

- [ ] **Step 5: 테스트 실행 → 통과 확인**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: **Fail: 0** — plugin.json/CHANGELOG/기대값 모두 `0.19.0` 동기, README keyword 유지.

- [ ] **Step 6: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "$(cat <<'EOF'
chore(spec-distill): bump 0.19.0 (review-lock session-id bridge) + doc/sync

plugin.json 0.18.0→0.19.0 (minor: new session-id CLI surface). CHANGELOG
[0.19.0] Fixed/Added. test_readme_sync.sh version expectations synced
(hidden 7th file — hard-asserts version).

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: 전체 스위트 회귀 스윕 + 결정론적 repro 육안 확인 (AC14, Verification Plan)

코드 deliverable 은 없다 — 전 task 통합 후 회귀 0 게이트 + 설계 문서의 결정론적 훅 repro 를 육안 확인한다.

**Files:** 없음(검증 전용).

- [ ] **Step 1: spec-distill 전체 테스트 스위트 실행** — repo root 에서 모든 `.sh` + `-m unittest`:

```bash
cd /Users/jeonghokim/Downloads/devbrew
echo "=== bash tests ==="; \
for t in plugins/spec-distill/tests/*.sh; do \
  echo "--- $t ---"; bash "$t" >/tmp/sd_$$.log 2>&1 && echo "OK" || { echo "FAIL"; tail -20 /tmp/sd_$$.log; }; \
done
echo "=== unittest ==="; \
python3 -m unittest discover -s plugins/spec-distill/tests -p 'test_*.py' 2>&1 | tail -15
```
Expected: 모든 `.sh` OK, unittest `OK`. **회귀 0**(AC14). 참고(memory `reference_spec_distill_test_runner`): 워크트리가 아닌 main-repo 체크아웃이므로 NG9 cross-resolver pre-existing red 는 해당 없음 — 발생 시 이 작업과 무관한 환경 이슈로 기록.

- [ ] **Step 2: 결정론적 훅 repro 육안 확인 (Verification Plan item 5)** — 설계 §Handoff Context 스크립트를 임시 dir 에서 실행(state_root 이 cwd 기준이므로 git repo 안에서):

```bash
cd /Users/jeonghokim/Downloads/devbrew
ROOT=$(mktemp -d); ( cd "$ROOT" && git init -q )
export DEVBREW_SPEC_DISTILL_SESSION_ID=hsid-aaaaaaaa
DOC='docs/superpowers/specs/2026-07-05-x-design.md'
mkdir -p "$ROOT/.claude/spec-distill/hsid-aaaaaaaa"
printf -- '---\nsession_id: hsid-aaaaaaaa\n---\n\npending_review:\n  path: %s\n  mode: design\n  triggered_at: 2000-01-01T00:00:00Z\n' "$DOC" > "$ROOT/.claude/spec-distill/hsid-aaaaaaaa/state.local.md"
LOCK=plugins/spec-distill/scripts/review_lock.py; HK=plugins/spec-distill/hooks/review-dispatch.py
( cd "$ROOT" && python3 "$OLDPWD/$LOCK" set iuuid-bbbbbbbb "$DOC" )   # 버그: interview UUID
echo "[mis-keyed] expect block:"; ( cd "$ROOT" && echo '{"session_id":"hsid-aaaaaaaa"}' | python3 "$OLDPWD/$HK" )
# 재시드(위 dispatch 가 pending 소비) 후 harness sid 락
printf -- '---\nsession_id: hsid-aaaaaaaa\n---\n\npending_review:\n  path: %s\n  mode: design\n  triggered_at: 2000-01-01T00:00:00Z\n' "$DOC" > "$ROOT/.claude/spec-distill/hsid-aaaaaaaa/state.local.md"
( cd "$ROOT" && python3 "$OLDPWD/$LOCK" set hsid-aaaaaaaa "$DOC" )     # fix: harness sid
echo "[harness-keyed] expect empty:"; ( cd "$ROOT" && echo '{"session_id":"hsid-aaaaaaaa"}' | python3 "$OLDPWD/$HK" )
unset DEVBREW_SPEC_DISTILL_SESSION_ID; rm -rf "$ROOT"
```
Expected: 첫 실행 `{"decision":"block",…}`, 둘째 실행 **빈 출력**. T1(Task 3)이 이미 자동화하지만 설계 문서 repro 와 1:1 대응을 육안 확증.

- [ ] **Step 3: 최종 브랜치 상태 확인** — detached HEAD/미의도 파일 점검(memory `feedback_review_subagent_baseline_checkout_detaches_head`):

```bash
cd /Users/jeonghokim/Downloads/devbrew
git branch --show-current    # → fix/spec-distill-review-lock-session-id (비면 재부착)
git status --short           # → clean (untracked 없음)
git log --oneline main..HEAD # → Task1–5 커밋 5개 (+ 무관한 f87b4c6 project-init interview 브리핑 존재 여부 확인)
```
Expected: 브랜치 attached, 트리 clean. `git log` 에 무관한 `f87b4c6`(project-init interview 브리핑, 공유 워킹디렉토리에서 유입)가 보이면 **파괴적 조치 금지** — PR 본문에 명시하는 선택지로 finishing 단계에서 사용자와 결정(rebase 불가·merge-over-rebase 선호). 이 plan 은 그 커밋을 건드리지 않는다.

---

## Self-Review

**1. Spec coverage** — 각 AC → task 매핑:
- AC1(session-id CLI) → **Task 1**. AC9(T3) → Task 1 Step 1.
- AC2(Step1 해석 + set `$harness_sid` + 2c non-collapse)/AC3(pause·approve `$harness_sid`)/AC4(불변식 프로즈)/AC5(degradation literals) → **Task 2**. AC11(degradation grep)/AC12(read-resolve grep)/AC13(non-collapse grep)/AC8(세 지점 mutation POS/NEG + count) → Task 2 Step 1.
- AC7(T1 behavioral) → **Task 3**.
- AC10(cancel_review 회귀) → **Task 4**.
- AC6(version+CHANGELOG) → **Task 5**. AC14(회귀 0) → Task 5 Step 5 + **Task 6 Step 1**.
- Verification Plan item 5(결정론 repro) → Task 6 Step 2. G3/C5 fail-safe → Task 3 teeth + degradation 프로즈. **모든 AC 커버됨.**

**2. Placeholder scan** — TBD/TODO/"적절히 처리" 없음. 모든 test·edit 스텝에 실제 코드+정확 리터럴+기대 출력 포함. ✓

**3. Type/리터럴 consistency** — 세 trio 리터럴이 Global Constraints·Task 2 edit·Task 2 grep·CHANGELOG 에서 동일(`review_lock.py" set/pause "$harness_sid`, `approve_handoff.sh" "$harness_sid`). `state_path.py" session-id`(AC12 grep) = Task 1 서브커맨드 이름 = Task 2 Step 1 STATE 해석 커맨드에서 일치. degradation 리터럴 `리뷰 락 refresh skip (리뷰 강제 유지)`·`이 stop/approve는 기록되지 않음`·`continuity read collapse 금지` 가 Task 2 grep(Step 1)과 edit(Step 3–4)에서 byte-동일. count 패턴 `\$harness_sid" "\$spec_path"` == 3 이 세 리터럴의 공통 접미와 정합. ✓

**4. Spec Files-to-Modify 대비 delta** — 스펙 표 + **test_readme_sync.sh**(hidden 7th, Task 5 에서 명시적 addendum 처리). README 는 스펙 스코프대로 미변경. 그 외 추가 파일 없음. ✓

**주의 사항(실행자):** ① 모든 테스트는 repo root 에서 실행(C6). ② SKILL.md 편집 후 `$session_id`→0, `$harness_sid" "$spec_path"`→3 을 반드시 확인(Task 2 Step 6). ③ 훅/스크립트 소스(state_path.py 외)는 이 fix 에서 무변경 — 실수로 편집 시 Law 스코프 이탈.
