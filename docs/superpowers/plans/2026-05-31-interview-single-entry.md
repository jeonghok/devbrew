# `/interview` 단일 사용자 진입점 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `conducting-interview` 스킬에 `user-invocable: false` 한 줄을 추가해 `/` 슬래시 메뉴에서 숨기고 `/interview`를 단일 사용자 진입점으로 만든다 — 프로그램 호출(command dispatch + reviewing-spec re-entry + 모델 자동 트리거)은 전부 보존.

**Architecture:** CC frontmatter의 `user-invocable: false`는 (공식 doc verbatim) *"only controls menu visibility, not Skill tool access"*. 따라서 메뉴에서만 사라지고 `Skill conducting-interview` dispatch는 그대로 동작. 변경은 frontmatter 1줄 + 회귀 가드 테스트 + devbrew 메타데이터(version bump + CHANGELOG). blast radius = spec-distill 내부 한정(외부 참조 0건).

**Tech Stack:** Markdown(SKILL.md frontmatter), bash 회귀 테스트(`grep`/`jq`), JSON(plugin.json).

**Spec:** `docs/superpowers/specs/2026-05-31-interview-single-entry-design.md` (spec-reviewer 4-round approved).

**Working directory:** `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-single-entry` (git worktree, branch `worktree-feature+interview-single-entry`). **모든 경로는 이 worktree 기준 절대경로로 commit할 것** — main repo(`/Users/jeonghokim/Downloads/devbrew`)에 쓰지 말 것.

---

## File Structure

| 파일 | 책임 | 변경 |
|---|---|---|
| `plugins/spec-distill/tests/test_conducting_interview_internal.sh` | AC1+AC2+AC3 회귀 가드의 단일 정규 위치 | **신규** |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | 인터뷰 엔진 스킬 — frontmatter에 visibility 토글 | frontmatter 1줄 추가 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 플러그인 메타데이터 | version bump |
| `plugins/spec-distill/CHANGELOG.md` | 변경 이력 | v0.11.2 항목 추가 |

Task 순서는 TDD: 회귀 가드 테스트를 **먼저** 작성(AC1 부분에서 fail) → 필드 추가(pass) → 메타데이터 → 전체 suite green 확인.

---

## Task 1: 회귀 가드 테스트 작성 (AC6, AC1+AC2+AC3 검증)

**Files:**
- Create: `plugins/spec-distill/tests/test_conducting_interview_internal.sh`

- [ ] **Step 1: Write the failing test**

`plugins/spec-distill/tests/test_conducting_interview_internal.sh` 생성. 기존 `test_brainstorming_entry.sh` 스타일(PLUGIN_DIR 해석 + `[PASS]/[FAIL]` + `exit 1`)을 따른다:

```bash
#!/usr/bin/env bash
# AC6 회귀 가드 — conducting-interview는 내부 전용 스킬(user-invocable: false).
# AC1: user-invocable: false 존재 / AC2: 기존 frontmatter 3키 보존 /
# AC3: command dispatch + reviewing-spec re-entry 프로그램 호출 경로 보존.
set -uo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$PLUGIN_DIR/skills/conducting-interview/SKILL.md"
CMD="$PLUGIN_DIR/commands/interview.md"
REVIEW="$PLUGIN_DIR/skills/reviewing-spec/SKILL.md"

fail=0
note() { echo "[$1] $2"; [[ "$1" == "FAIL" ]] && fail=$((fail+1)) || true; }

# AC1 — user-invocable: false 존재 (메뉴 은닉)
grep -q '^user-invocable: false$' "$SKILL" \
    && note PASS "AC1: user-invocable: false present" \
    || note FAIL "AC1: user-invocable: false MISSING"

# AC2 — 기존 frontmatter 키 보존 (의미 변경 없음)
grep -q '^name: conducting-interview$' "$SKILL" \
    && note PASS "AC2: name preserved" \
    || note FAIL "AC2: name field broken"
grep -q '^description:' "$SKILL" \
    && note PASS "AC2: description preserved" \
    || note FAIL "AC2: description field broken"
grep -q '^cost_class: medium$' "$SKILL" \
    && note PASS "AC2: cost_class preserved" \
    || note FAIL "AC2: cost_class field broken"

# AC3 — 프로그램 호출 경로 보존 (메뉴만 숨고 dispatch는 살아있음)
grep -q 'Skill conducting-interview' "$CMD" \
    && note PASS "AC3: command dispatch line preserved" \
    || note FAIL "AC3: command dispatch line MISSING"
grep -q 'conducting-interview' "$REVIEW" \
    && note PASS "AC3: reviewing-spec re-entry reference preserved" \
    || note FAIL "AC3: reviewing-spec re-entry reference MISSING"

echo
[[ $fail -eq 0 ]] && echo "PASSED: all AC1/AC2/AC3 guards green" || echo "FAILED: $fail guard(s)"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2: Run test to verify it fails on AC1**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_internal.sh`
Expected: `[FAIL] AC1: user-invocable: false MISSING` + 마지막 줄 `FAILED: 1 guard(s)`, exit 1. (AC2/AC3 6개는 이미 PASS — 기존 파일에 해당 content가 실재하므로.)

- [ ] **Step 3: chmod +x (다른 테스트와 실행 권한 일관)**

Run: `chmod +x plugins/spec-distill/tests/test_conducting_interview_internal.sh`

- [ ] **Step 4: Commit (failing guard — red 상태 기록)**

```bash
git add plugins/spec-distill/tests/test_conducting_interview_internal.sh
git commit -m "test(spec-distill): add conducting-interview internal-only regression guard (AC6, red)"
```

---

## Task 2: `user-invocable: false` 추가 (AC1, AC2)

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (frontmatter, line 9 `cost_class: medium` 직후)

- [ ] **Step 1: 필드 추가**

현재 frontmatter(line 1–10):

```yaml
---
name: conducting-interview
description: >
  Use this skill to run the spec-distill 4-block Korean Socratic interview.
  Called by /interview command after trivia escape check passes. Implements
  C43 4-path routing (factual auto-confirm / judgment→user / ambiguity→sub-agent /
  ontological→5-type), C44 Dialectic Rhythm Guard, C45 breadth-keeper dispatch
  (max 1 per round, AC13). Persists state to .claude/spec-distill/<session-id>/state.local.md.
cost_class: medium
---
```

`cost_class: medium` 줄 **직후**, 닫는 `---` **직전**에 한 줄 추가하여 다음으로 만든다:

```yaml
cost_class: medium
user-invocable: false
---
```

(Edit tool 사용: old_string = `cost_class: medium\n---`, new_string = `cost_class: medium\nuser-invocable: false\n---`. SKILL.md에서 `cost_class: medium\n---` 패턴은 frontmatter에 유일.)

- [ ] **Step 2: Run the guard test to verify it now passes**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_internal.sh`
Expected: 7개 모두 `[PASS]`, 마지막 줄 `PASSED: all AC1/AC2/AC3 guards green`, exit 0.

- [ ] **Step 3: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -m "feat(spec-distill): hide conducting-interview from slash menu (user-invocable: false)

/interview를 단일 사용자 진입점으로. 내부 엔진 스킬은 command dispatch +
reviewing-spec re-entry로만 호출(메뉴 비노출). AC1/AC2 회귀 가드 green."
```

---

## Task 3: version bump + CHANGELOG (AC4, AC5, devbrew C3)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`"version": "0.11.1"` → `"0.11.2"`)
- Modify: `plugins/spec-distill/CHANGELOG.md` (line 1 `# Changelog` 직후에 새 섹션 삽입)

- [ ] **Step 1: plugin.json version bump**

`plugins/spec-distill/.claude-plugin/plugin.json`에서 (Edit tool: old_string = `"version": "0.11.1",`, new_string = `"version": "0.11.2",`).

- [ ] **Step 2: Verify version**

Run: `jq -r .version plugins/spec-distill/.claude-plugin/plugin.json`
Expected: `0.11.2`

- [ ] **Step 3: CHANGELOG 항목 추가**

`CHANGELOG.md` line 1(`# Changelog`)과 line 3(`## [0.11.0] — 2026-05-29`) 사이에 새 섹션 삽입. (Edit tool: old_string = 첫 두 줄 `# Changelog\n\n## [0.11.0] — 2026-05-29`, new_string으로 사이에 v0.11.2 블록 삽입):

```markdown
# Changelog

## [0.11.2] — 2026-05-31

### Changed
- `skills/conducting-interview/SKILL.md` — frontmatter에 `user-invocable: false` 추가. 내부 인터뷰 엔진 스킬을 `/` 슬래시 메뉴에서 숨겨 사용자 진입점을 `/interview` 하나로 단일화 (`/conducting-interview` 직접 호출 시 command의 kill switch·trivia escape 게이트 우회 → Law 1 진입 규율 무결성 보호). CC 공식 doc verbatim: `user-invocable`은 *"only controls menu visibility, not Skill tool access"* — command의 `Skill conducting-interview` dispatch·`reviewing-spec` re-entry·모델 자동 트리거는 전부 보존. `disable-model-invocation`은 정반대 효과(Skill tool 차단)라 미사용.

### Added
- `tests/test_conducting_interview_internal.sh` — 회귀 가드. `user-invocable: false` 존재(AC1) + 기존 frontmatter 3키 보존(AC2) + command dispatch·reviewing-spec re-entry 프로그램 호출 경로 보존(AC3). 누가 필드를 지우거나 dispatch 라인을 깨면 fail (Law 3 compounding).

## [0.11.0] — 2026-05-29
```

- [ ] **Step 4: Verify CHANGELOG entry**

Run: `grep -q '## \[0.11.2\] — 2026-05-31' plugins/spec-distill/CHANGELOG.md && echo OK`
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): v0.11.2 — plugin.json bump + CHANGELOG (AC4, AC5)"
```

---

## Task 4: 전체 suite green 확인 + worktree 검증 (Verification Plan)

**Files:** (변경 없음 — 검증 only)

- [ ] **Step 1: baseline 캡처 — 본 변경 *이전*의 기존 red 파악**

> 메모리(`project_qg_pre_existing_test_reds`)상 devbrew에는 CI가 없고 일부 stale red가 존재할 수 있음. 우리 변경이 *새* red를 만들지 않았음을 보이려면 baseline 대비 비교가 필요.

Run (repo root에서):
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-single-entry
for t in plugins/spec-distill/tests/test_*.sh; do
  bash "$t" >/dev/null 2>&1 && echo "PASS  $t" || echo "FAIL  $t"
done | tee /tmp/spec-distill-after.txt
```
Expected: `test_conducting_interview_internal.sh`는 **PASS**. 다른 테스트의 FAIL이 있다면 그것이 본 변경과 무관한 pre-existing인지 확인 — 본 PR이 건드린 파일(conducting-interview SKILL.md, plugin.json, CHANGELOG)은 다른 테스트의 대상이 아니므로 우리 변경으로 인한 신규 red는 없어야 함.

- [ ] **Step 2: 신규 가드 단독 재실행 (green 재확인)**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_internal.sh; echo "exit=$?"`
Expected: 7 PASS + `exit=0`.

- [ ] **Step 3: AC4/AC5 메타데이터 일관성 재확인**

Run:
```bash
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.11.2" && echo "AC4 ok"
grep -q '## \[0.11.2\] — 2026-05-31' plugins/spec-distill/CHANGELOG.md && echo "AC5 ok"
```
Expected: `AC4 ok` + `AC5 ok`.

- [ ] **Step 4: worktree drift 검증 (commit이 올바른 worktree/branch에 있는지)**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-single-entry
git branch --show-current
git log --oneline -4
git status --short
```
Expected: branch = `worktree-feature+interview-single-entry`, 최근 4 commit이 test(red)/feat/chore/(spec doc) 순, working tree clean. main repo(`/Users/jeonghokim/Downloads/devbrew`)에 본 변경 파일이 새지 않았는지 확인.

- [ ] **Step 5: (수동 런타임 — CC 세션 필요, 자동화 불가) 다음 단계로 위임 기록**

자동 검증 불가한 두 항목은 PR 머지 전 수동 실행 + PR 설명에 결과 기록:
1. **프로그램 호출 보존(G2)**: 플러그인 재로드 후 `/interview <rough request>` 실행 → trivia escape 통과 → `conducting-interview` 정상 dispatch + 4-block 첫 round 진행. (실패 시 = claim 오류 → `user-invocable: false` 1줄 revert.)
2. **메뉴 은닉(G1)**: 재로드 후 `/` 입력 → `/interview` 보이고 `/spec-distill:conducting-interview` 안 보임. + 테스트한 CC 클라이언트 버전 기록(C5).

이 plan의 자동 task(1–4)는 여기서 완료. 수동 런타임은 PR 검증 단계 책임.

---

## Self-Review (작성자 체크리스트)

**1. Spec coverage:**
- AC1(user-invocable: false) → Task 2 Step 1 ✓
- AC2(기존 frontmatter 보존) → Task 1 test + Task 2 Step 2 ✓
- AC3(dispatch/re-entry 보존, content grep) → Task 1 test(느슨한 `conducting-interview` 패턴) ✓
- AC4(version 0.11.2) → Task 3 Step 1–2 ✓
- AC5(CHANGELOG) → Task 3 Step 3–4 ✓
- AC6(회귀 가드 테스트) → Task 1 전체 ✓
- Verification Plan(자동/수동) → Task 4 ✓
- C3(version bump 동반) → Task 3 ✓ / C5(CC 버전 기록) → Task 4 Step 5 ✓

**2. Placeholder scan:** TBD/TODO/"적절히" 없음. 모든 코드/명령 블록은 실제 content. ✓

**3. Type consistency:** 파일 경로·grep 패턴·version 문자열(`0.11.2`)·날짜(`2026-05-31`)가 Task 전반에서 일관. Task 1 test의 grep 패턴과 AC3 spec 정의 일치. ✓

**4. TDD 순서:** Task 1(red) → Task 2(green) → Task 3(메타) → Task 4(suite) — red-before-green 보장. ✓
