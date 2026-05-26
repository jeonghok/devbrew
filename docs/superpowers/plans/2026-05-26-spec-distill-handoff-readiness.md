# spec-distill Handoff Readiness Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 플러그인 v0.8.1 → v0.9.0 마이너 업그레이드 — `## Handoff Context` 섹션을 spec/design 파일에 의무화하고 spec-reviewer에 `handoff_incomplete` block-severity 검사 카테고리 추가, `approve_handoff.sh`가 사용자에게 copy-paste 가능한 `/compact` 양식 + 다음 세션 첫 프롬프트로 구성된 Handoff packet emit.

**Architecture:** 4-surface patch — (a) `templates/spec-template.md` 새 섹션, (b) `agents/spec-reviewer.md` 새 카테고리 (spec mode + design mode), (c) `scripts/approve_handoff.sh` Step 2 출력 교체, (d) `plugin.json`/`CHANGELOG.md`/`README.md` 메타데이터. 새 agent/skill 없음 (devbrew "default to lightness"). TDD: grep-based static-text tests (기존 spec-distill 패턴 답습). 

**Tech Stack:** bash 5.x, python 3.x (기존 hook 스크립트와 동일), markdown templates, devbrew CLAUDE.md plugin conventions.

**Spec:** `docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md` (commits 504cde5 → 0def60a → 8b0803b, approved round 3).

---

## File Structure

**Modified files (6):**
- `plugins/spec-distill/.claude-plugin/plugin.json` — version bump 0.8.1 → 0.9.0
- `plugins/spec-distill/templates/spec-template.md` — `## Handoff Context` 섹션 신설 (`## Goal` 직후, `## Context / Why` 직전)
- `plugins/spec-distill/agents/spec-reviewer.md` — `handoff_incomplete` 카테고리 + 15 conversation reference 패턴 + kill switch 분기
- `plugins/spec-distill/scripts/approve_handoff.sh` — Step 2 출력 3-block packet으로 교체
- `plugins/spec-distill/CHANGELOG.md` — `## [0.9.0] — 2026-05-26` entry
- `plugins/spec-distill/README.md` — Kill switches 표 신규 행 + Phase 5 설명

**Created files (6 tests, all `test_handoff_*` prefix for V1 glob):**
- `plugins/spec-distill/tests/test_handoff_context_section_required.sh` — AC2
- `plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh` — AC3
- `plugins/spec-distill/tests/test_handoff_conversation_reference.sh` — AC4 (15 패턴 grep)
- `plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh` — AC5 (6 sub-assertions)
- `plugins/spec-distill/tests/test_handoff_kill_switch.sh` — AC6
- `plugins/spec-distill/tests/test_handoff_design_mode.sh` — AC7

---

## Task 0: Pre-execution — Worktree 생성

**Files:** N/A (workspace setup)

- [ ] **Step 0.1: 워크트리 생성**

`superpowers:using-git-worktrees` skill을 invoke해서 `feature/spec-distill-handoff-readiness` 브랜치 기반 새 worktree 만들기. 사용자가 brainstorming에서 명시한 isolation 요구.

Expected: `feature/spec-distill-handoff-readiness` 브랜치는 이미 존재 (504cde5 → 8b0803b 3개 commits). 워크트리는 main repo 옆 디렉토리(예: `../devbrew-handoff-readiness`)에 생성, 같은 브랜치 체크아웃.

---

## Task 1: Template — `## Handoff Context` 섹션 추가

**Files:**
- Modify: `plugins/spec-distill/templates/spec-template.md` (현재 68줄, line 17 `## Goal` 직후 삽입)

- [ ] **Step 1.1: 템플릿에 섹션 삽입**

`plugins/spec-distill/templates/spec-template.md`의 `## Goal` 섹션 (line 17–20) 직후, `## Context / Why` (line 22) 직전에 다음 블록 삽입:

```markdown
## Handoff Context

> 이 spec을 처음 보는 사람(또는 /compact 후 자기 자신)이 30초에 핵심 파악할 수 있게.
> 대화 컨텍스트를 가정하지 말 것 — 모든 사실은 spec 본문에 self-contained.

**TL;DR** (1–2 sentences — 무엇을, 왜):
- ...

**Implicit context** (Constraints에 안 박힌, 작업 진행에 필요한 외부 사실):
- ...

**Deferred to plan** (이 spec이 의도적으로 lock하지 않은 결정):
- ...

```

(빈 줄 1개로 다음 섹션과 분리.)

- [ ] **Step 1.2: 삽입 위치 verify**

Run:
```bash
awk '/^## /{print NR": "$0}' plugins/spec-distill/templates/spec-template.md
```

Expected output (line numbers approximate):
```
15: # <Topic title>     (no, this is H1)
17: ## Goal
22: ## Handoff Context
33: ## Context / Why
...
```

`## Handoff Context`가 `## Goal`과 `## Context / Why` 사이에 위치하는지 확인.

- [ ] **Step 1.3: Commit**

```bash
git add plugins/spec-distill/templates/spec-template.md
git commit -m "feat(spec-distill): add Handoff Context section to spec template

v0.9.0 — \`## Goal\` 직후, \`## Context / Why\` 직전에 새 섹션 신설.
TL;DR / Implicit context / Deferred to plan 3개 하위 항목.
self-containedness baseline (spec G2, AC1)."
```

---

## Task 2: 4개 reviewer test 동시 작성 (모두 initially FAIL)

**Files:**
- Create: `plugins/spec-distill/tests/test_handoff_context_section_required.sh` (AC2)
- Create: `plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh` (AC3)
- Create: `plugins/spec-distill/tests/test_handoff_conversation_reference.sh` (AC4)
- Create: `plugins/spec-distill/tests/test_handoff_kill_switch.sh` (AC6)

- [ ] **Step 2.1: AC2 test 작성**

`plugins/spec-distill/tests/test_handoff_context_section_required.sh`:

```bash
#!/usr/bin/env bash
# AC2 — agents/spec-reviewer.md must define `handoff_incomplete` category that
# fires when `## Handoff Context` section is absent.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC2a: `handoff_incomplete` 카테고리 ID 존재
grep -q 'handoff_incomplete' "$AGENT" \
  && note PASS "AC2: handoff_incomplete category defined" \
  || note FAIL "AC2 handoff_incomplete category missing"

# AC2b: `## Handoff Context` section 검사 명시
grep -qE '## Handoff Context|Handoff Context.*섹션' "$AGENT" \
  && note PASS "AC2: '## Handoff Context' section check referenced" \
  || note FAIL "AC2 section check missing from agent"

# AC2c: severity block-level
grep -qE 'handoff_incomplete.*block|block.*handoff_incomplete' "$AGENT" \
  && note PASS "AC2: handoff_incomplete is block-severity" \
  || note FAIL "AC2 handoff_incomplete severity not block"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

`chmod +x` 필수.

- [ ] **Step 2.2: AC3 test 작성**

`plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh`:

```bash
#!/usr/bin/env bash
# AC3 — handoff_incomplete fires when TL;DR / Implicit / Deferred 중 하나라도 비어있음.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC3: 3 sub-section labels referenced in agent
for label in "TL;DR" "Implicit context" "Deferred to plan"; do
  grep -qF "$label" "$AGENT" \
    && note PASS "AC3: sub-section '$label' referenced in agent" \
    || note FAIL "AC3 sub-section '$label' not in agent"
done

# AC3: empty-subsection 검출 로직 명시
grep -qE '비어.*있|empty|미작성' "$AGENT" \
  && note PASS "AC3: empty-subsection detection language present" \
  || note FAIL "AC3 empty-subsection detection missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2.3: AC4 test 작성 (15 패턴 grep)**

`plugins/spec-distill/tests/test_handoff_conversation_reference.sh`:

```bash
#!/usr/bin/env bash
# AC4 — agent file must enumerate all 15 C8 conversation reference patterns.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# 영어 8개
for pat in "as discussed" "as we agreed" "we talked about" "the user mentioned" \
           "you mentioned" "as mentioned before" "per our discussion" "earlier in this session"; do
  grep -qF "$pat" "$AGENT" \
    && note PASS "AC4: EN pattern '$pat' present" \
    || note FAIL "AC4 EN pattern '$pat' missing"
done

# 한국어 7개
for pat in "위에서 논의한" "위에서 언급한" "방금 결정한" "아까 결정한" \
           "이전에 말했듯이" "언급하셨던" "말씀하신"; do
  grep -qF "$pat" "$AGENT" \
    && note PASS "AC4: KO pattern '$pat' present" \
    || note FAIL "AC4 KO pattern '$pat' missing"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail (expected 15 patterns)"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2.4: AC6 kill switch test 작성**

`plugins/spec-distill/tests/test_handoff_kill_switch.sh`:

```bash
#!/usr/bin/env bash
# AC6 — DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1 must bypass handoff_incomplete only.
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"
README="$REPO_ROOT/plugins/spec-distill/README.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC6a: kill switch env var 이름 in agent
grep -q 'DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK' "$AGENT" \
  && note PASS "AC6: kill switch env var referenced in agent" \
  || note FAIL "AC6 kill switch env var missing from agent"

# AC6b: README Kill switches 표에 행 추가
grep -q 'DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK' "$README" \
  && note PASS "AC6: kill switch documented in README" \
  || note FAIL "AC6 kill switch not in README"

# AC6c: loud warning 텍스트 명시
grep -qE 'handoff readiness 검증 비활성화|handoff.*disabled' "$AGENT" \
  && note PASS "AC6: loud warning text present" \
  || note FAIL "AC6 loud warning text missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 2.5: chmod + verify FAIL**

```bash
chmod +x plugins/spec-distill/tests/test_handoff_context_section_required.sh
chmod +x plugins/spec-distill/tests/test_handoff_context_empty_subsections.sh
chmod +x plugins/spec-distill/tests/test_handoff_conversation_reference.sh
chmod +x plugins/spec-distill/tests/test_handoff_kill_switch.sh

for t in plugins/spec-distill/tests/test_handoff_{context_section_required,context_empty_subsections,conversation_reference,kill_switch}.sh; do
  echo "=== $t ===" ; bash "$t" || true
done
```

Expected: 4개 모두 FAIL (agent에 아직 변경 안 함). 각 test 마지막 줄 `Fail: N` (N>0).

- [ ] **Step 2.6: Commit (test-first)**

```bash
git add plugins/spec-distill/tests/test_handoff_*.sh
git commit -m "test(spec-distill): add 4 handoff reviewer tests (failing — TDD setup)

v0.9.0 — AC2/AC3/AC4/AC6 grep-based static-text tests against
agents/spec-reviewer.md. All 4 currently FAIL — next task implements
reviewer changes to make them pass."
```

---

## Task 3: spec-reviewer agent에 `handoff_incomplete` 카테고리 + C8 15 패턴 + kill switch 추가

**Files:**
- Modify: `plugins/spec-distill/agents/spec-reviewer.md`

- [ ] **Step 3.1: spec mode 카테고리 표 확장**

`plugins/spec-distill/agents/spec-reviewer.md`의 `## What to check` 섹션 표 (현재 6 행) 마지막에 추가:

```markdown
| `handoff_incomplete` | (a) `## Handoff Context` 섹션 부재, (b) TL;DR / Implicit context / Deferred to plan 중 하나라도 비어있음, (c) 본문에 C8 conversation reference 패턴 검출 (아래 list 참조) | block |
```

- [ ] **Step 3.2: design mode checklist 표 확장 (7 카테고리)**

같은 파일의 `### Design Mode Branch (v0.4.0)` 섹션 design 표 (현재 6 행)에도 같은 행 추가 (위 step 3.1 텍스트 그대로).

- [ ] **Step 3.3: C8 패턴 list 명시 (full 15)**

design 표 직후 다음 sub-section 신설:

```markdown
### Handoff readiness 검사 상세 (v0.9.0)

`handoff_incomplete` 카테고리는 *spec mode + design mode 양쪽에서* 동일하게 적용. 검사 3개 sub-pattern:

1. **섹션 부재**: 파일 본문에 `^## Handoff Context` 라인 부재 → `handoff_incomplete: section absent`.
2. **하위 항목 미작성**: 섹션은 있으나 `TL;DR`, `Implicit context`, `Deferred to plan` 3개 sub-block 중 하나라도 비어있음(label 이후 다음 빈 줄까지 의미 있는 텍스트 < 10자) → `handoff_incomplete: subsection empty`.
3. **Conversation reference 검출**: 다음 15개 substring (case-insensitive, normalize whitespace) 중 하나라도 본문에 포함되면 `handoff_incomplete: conversation reference detected`.

   **영어 8개**: `as discussed`, `as we agreed`, `we talked about`, `the user mentioned`, `you mentioned`, `as mentioned before`, `per our discussion`, `earlier in this session`.

   **한국어 7개**: `위에서 논의한`, `위에서 언급한`, `방금 결정한`, `아까 결정한`, `이전에 말했듯이`, `언급하셨던`, `말씀하신`.

   확장은 v0.10.0+ 별도 PR로 본 list에 라인 추가 (인프라 변경 없음).

#### Kill switch (v0.9.0)

`DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` 환경 변수가 설정되어 있으면 `handoff_incomplete` 카테고리만 우회. 다른 검사는 정상. agent는 stderr에 loud warning 출력:

```
[spec-distill v0.9.0] WARNING: handoff readiness 검증 비활성화 — /compact 이후 정보 손실 risk
```

다른 카테고리(`missing_section`, `ambiguous_requirement` 등)는 영향 없음.
```

- [ ] **Step 3.4: 4 test 다시 실행 — 모두 PASS**

```bash
for t in plugins/spec-distill/tests/test_handoff_{context_section_required,context_empty_subsections,conversation_reference,kill_switch}.sh; do
  echo "=== $t ===" ; bash "$t"
done
```

Expected: 4개 모두 통과. 각 test 마지막 줄 `Fail: 0`.

`test_handoff_kill_switch.sh`의 AC6b (README check)는 아직 fail할 수 있음 (Task 9에서 README 갱신). 일단 그 한 줄만 fail이면 OK.

- [ ] **Step 3.5: Commit (test passes)**

```bash
git add plugins/spec-distill/agents/spec-reviewer.md
git commit -m "feat(spec-distill): add handoff_incomplete check to spec-reviewer (v0.9.0)

- spec mode + design mode 양쪽에 \`handoff_incomplete\` block-severity 추가
- C8 15개 conversation reference 패턴 enumerate (영어 8 + 한국어 7)
- DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK kill switch + loud warning
- AC2/AC3/AC4/AC6 test 모두 통과 (단 AC6b README 검사는 Task 9 의존)"
```

---

## Task 4: design mode regression test (AC7)

**Files:**
- Create: `plugins/spec-distill/tests/test_handoff_design_mode.sh`

- [ ] **Step 4.1: AC7 test 작성**

`plugins/spec-distill/tests/test_handoff_design_mode.sh`:

```bash
#!/usr/bin/env bash
# AC7 — handoff_incomplete is wired into the design-mode checklist (7th category).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
AGENT="$REPO_ROOT/plugins/spec-distill/agents/spec-reviewer.md"

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# Locate design mode section
design_start=$(grep -n "^### Design Mode Branch" "$AGENT" | head -1 | cut -d: -f1)
[[ -n "$design_start" ]] && note PASS "AC7: design mode section located (line $design_start)" \
  || { note FAIL "design mode section header missing"; exit 1; }

# Within the design mode block, all 6 existing categories + handoff_incomplete must appear.
design_block=$(sed -n "${design_start},/^## /p" "$AGENT")

for cat in "placeholder" "ambiguity" "scope_creep" "approaches_comparison" "isolation" "testing" "handoff_incomplete"; do
  echo "$design_block" | grep -q "$cat" \
    && note PASS "AC7: design category '$cat' present" \
    || note FAIL "AC7 design category '$cat' missing"
done

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 4.2: chmod + 실행 — PASS 기대**

```bash
chmod +x plugins/spec-distill/tests/test_handoff_design_mode.sh
bash plugins/spec-distill/tests/test_handoff_design_mode.sh
```

Expected: `Fail: 0` (Task 3에서 이미 design 표에도 handoff_incomplete 추가했으므로).

- [ ] **Step 4.3: Commit**

```bash
git add plugins/spec-distill/tests/test_handoff_design_mode.sh
git commit -m "test(spec-distill): add design-mode 7-category regression (AC7)"
```

---

## Task 5: approve_handoff.sh — Step 2 출력 교체 (handoff packet 3-block)

**Files:**
- Modify: `plugins/spec-distill/scripts/approve_handoff.sh` (현재 49줄, lines 38–41 교체)

- [ ] **Step 5.1: Step 2 출력 교체**

기존 (lines 38–41):
```bash
# Step 2: handoff pointer
echo "Spec lock 완료. 다음 단계:"
echo "  Skill superpowers:writing-plans $spec_path"
```

교체:

```bash
# Step 2: handoff packet (v0.9.0)
cat <<EOF

===== spec-distill handoff packet =====
Spec lock 완료: $spec_path

[1] /compact 명령 (지금 복사-실행):

  /compact spec at $spec_path 보존. 그 spec 본문(특히 Handoff Context, Acceptance Criteria, Files to Modify) 유지하고 인터뷰 대화/기각된 대안/중간 추론 drop. 다음 단계는 "Skill superpowers:writing-plans $spec_path" 호출.

[2] /compact 후 첫 메시지 (자동 진행되면 생략):

  Skill superpowers:writing-plans $spec_path

========================================
EOF
```

(heredoc은 `$spec_path` 변수 전개 허용 — quoted EOF 아님.)

- [ ] **Step 5.2: 수동 dry-run으로 출력 확인**

```bash
bash plugins/spec-distill/scripts/approve_handoff.sh test-session-12345678 docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md 2>&1 | head -30
```

Expected stdout: divider 라인, `/compact spec at docs/...` 라인 (preserve directive + drop 지시어 + next-step embed), `Skill superpowers:writing-plans docs/...` 라인 [2] 블록, 종료 divider. (Step 1 git commit은 변경사항 없으면 실패할 수 있지만 stdout은 먼저 출력됨).

⚠ commit 실패 시 stderr `[spec-distill] commit failed` 출력 — 무시 가능 (dry-run 목적).

---

## Task 6: AC5 — approve packet emit test (6 sub-assertions)

**Files:**
- Create: `plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh`

- [ ] **Step 6.1: AC5 test 작성**

`plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh`:

```bash
#!/usr/bin/env bash
# AC5 — approve_handoff.sh stdout includes the full Handoff packet (6 sub-assertions).
set -u -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/spec-distill/scripts/approve_handoff.sh"

# Fake spec path (file does not need to exist — script git commit failure is OK, stdout
# still emitted before exit). Use a 12-char hex session_id to pass charset guard.
TEST_SID="aaaa11112222"
TEST_SPEC="docs/superpowers/specs/2026-05-26-FAKE-design.md"

# Capture stdout (script may exit non-zero from commit failure; we only care stdout).
out=$(bash "$SCRIPT" "$TEST_SID" "$TEST_SPEC" 2>/dev/null || true)

pass=0; fail=0
note() { if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"; else fail=$((fail+1)); echo "  ✗ $2"; fi; }

# AC5(a): divider opening
echo "$out" | grep -qF "===== spec-distill handoff packet =====" \
  && note PASS "AC5(a): opening divider present" \
  || note FAIL "AC5(a) opening divider missing"

# AC5(b): /compact line with preserve directive
echo "$out" | grep -E '^\s*/compact .*'"$TEST_SPEC"'.*Handoff Context.*Acceptance Criteria.*Files to Modify' >/dev/null \
  && note PASS "AC5(b): /compact preserve directive includes section names" \
  || note FAIL "AC5(b) /compact preserve directive incomplete"

# AC5(c): drop directive
echo "$out" | grep -E '/compact .*(drop|버리|기각)' >/dev/null \
  && note PASS "AC5(c): /compact drop directive present" \
  || note FAIL "AC5(c) /compact drop directive missing"

# AC5(d): next-step instruction embed inside /compact line
echo "$out" | grep -E '/compact .*Skill superpowers:writing-plans '"$TEST_SPEC" >/dev/null \
  && note PASS "AC5(d): next-step embed inside /compact" \
  || note FAIL "AC5(d) next-step not embedded in /compact"

# AC5(e): [2] safety net line (separate from /compact)
echo "$out" | grep -E '^\s*Skill superpowers:writing-plans '"$TEST_SPEC"'\s*$' >/dev/null \
  && note PASS "AC5(e): [2] standalone Skill writing-plans line" \
  || note FAIL "AC5(e) [2] standalone safety net line missing"

# AC5(f): closing divider (8+ '=' chars)
echo "$out" | grep -qE '^={8,}\s*$' \
  && note PASS "AC5(f): closing divider present" \
  || note FAIL "AC5(f) closing divider missing"

echo
echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
[[ $fail -eq 0 ]]
```

- [ ] **Step 6.2: chmod + 실행**

```bash
chmod +x plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh
bash plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh
```

Expected: 6 PASS / 0 FAIL.

- [ ] **Step 6.3: Commit**

```bash
git add plugins/spec-distill/scripts/approve_handoff.sh plugins/spec-distill/tests/test_handoff_approve_packet_emit.sh
git commit -m "feat(spec-distill): approve_handoff.sh emits 3-block Handoff packet (v0.9.0)

Step 2 출력을 minimal 2-line message에서 divider + /compact 명령 +
다음 세션 첫 프롬프트 + 종료 divider로 교체. /compact preserve directive에
next-step instruction embed (compact-survival best-effort) + [2] 안전망 라인.
AC5 6 sub-assertions test 통과."
```

---

## Task 7: plugin.json version bump 0.8.1 → 0.9.0

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`

- [ ] **Step 7.1: version 필드 갱신**

`plugins/spec-distill/.claude-plugin/plugin.json` line 4 `"version": "0.8.1"` → `"version": "0.9.0"`.

(다른 필드 변경 없음. JSON 구문 유지.)

- [ ] **Step 7.2: verify**

```bash
jq -r '.version' plugins/spec-distill/.claude-plugin/plugin.json
```

Expected: `0.9.0`

(AC8 자동 검증 — 별도 test 안 만들음. CI/사용 시 jq 확인.)

---

## Task 8: CHANGELOG.md — `## [0.9.0]` entry 추가

**Files:**
- Modify: `plugins/spec-distill/CHANGELOG.md` (line 3 직후 새 entry 삽입)

- [ ] **Step 8.1: 새 entry 추가**

`plugins/spec-distill/CHANGELOG.md`의 `# Changelog` (line 1) 다음 빈 줄 직후, 기존 `## [0.8.1] — 2026-05-26` (line 3) 직전에 삽입:

```markdown
## [0.9.0] — 2026-05-26

### Added
- `templates/spec-template.md` — `## Handoff Context` 섹션 신설 (`## Goal` 직후). TL;DR / Implicit context / Deferred to plan 3개 하위 항목. spec/design 파일 self-containedness baseline (G2, AC1).
- `agents/spec-reviewer.md` — `handoff_incomplete` block-severity 카테고리 (spec mode 11→12 카테고리, design mode 6→7 카테고리). 3개 sub-pattern (섹션 부재 / 하위 항목 미작성 / conversation reference 검출). 15개 conversation reference 패턴 enumerated (영어 8 + 한국어 7). v0.10.0+ list 확장 정책 명시.
- `scripts/approve_handoff.sh` — Step 2 출력 교체: minimal 2-line "다음 단계:"에서 3-block "Handoff packet" (divider / `/compact` 명령 with preserve+drop+next-step embed / `[2]` standalone safety net Skill writing-plans 라인 / 종료 divider). /compact preserve directive에 next-step instruction embed로 compact-survival best-effort 지원.
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` kill switch — `handoff_incomplete` 카테고리만 우회, 다른 검사는 정상. loud warning stderr 출력.
- `tests/test_handoff_*.sh` 6개 신규 test — AC2/AC3/AC4/AC5/AC6/AC7 (모두 `test_handoff_*` prefix로 V1 glob 일관).

### Changed
- spec/design 파일의 review 통과 기준이 self-containedness까지 확장. /compact 경계를 spec lifecycle의 1급 시민으로 승격 — Law 1 (Clarity Before Code) 자연스러운 확장.

### Notes
- Pre-v0.9.0 spec.md grandfather 처리 안 함 (design 문서 NG8 / R6). 기존 spec 재review 시 사용자가 `## Handoff Context` 섹션을 30초 분량 수동 추가 필요. reviewer가 추가 위치/내용을 recommendation으로 안내.

```

- [ ] **Step 8.2: verify**

```bash
grep -q "^## \[0.9.0\] — 2026-05-26" plugins/spec-distill/CHANGELOG.md && echo OK
```

Expected: `OK`.

---

## Task 9: README.md — Kill switches 표 + Phase 5 설명

**Files:**
- Modify: `plugins/spec-distill/README.md` (Kill switches 섹션 line 107–123)

- [ ] **Step 9.1: Kill switches 표에 신규 행 추가**

`plugins/spec-distill/README.md`의 Kill switches 섹션 (현재 line 107–123) 마지막 항목 다음에 추가:

```markdown
- `DEVBREW_SPEC_DISTILL_SKIP_HANDOFF_CHECK=1` (v0.9.0) — `handoff_incomplete` 카테고리만 우회. 다른 검사 (`missing_section` 등)는 정상 동작. loud warning stderr 출력. /compact 이후 정보 손실 risk 명시.
```

- [ ] **Step 9.2: Phase 5 설명에 packet 언급 추가** (optional, 짧게)

같은 파일의 Phase 5 또는 Flow 섹션이 있다면 (line 19–39 `Flow (Phase 0–5)` 다이어그램), 다이어그램 아래에 한 줄 추가:

```markdown
**v0.9.0**: `[5] approve → handoff` 시 stdout에 *Handoff packet* (3-block) emit — `/compact` 명령 양식 + 다음 세션 첫 프롬프트 (자세히는 `scripts/approve_handoff.sh`).
```

- [ ] **Step 9.3: kill switch test 재실행**

```bash
bash plugins/spec-distill/tests/test_handoff_kill_switch.sh
```

Expected: AC6b (README check) 이제 PASS. 전체 `Fail: 0`.

- [ ] **Step 9.4: Commit (metadata batch)**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git commit -m "chore(spec-distill): v0.9.0 — plugin.json + CHANGELOG + README

- plugin.json: 0.8.1 → 0.9.0 (new minor surface)
- CHANGELOG: [0.9.0] — 2026-05-26 entry (Added/Changed/Notes)
- README: Kill switches 표 신규 행 + Phase 5 handoff packet 언급
- AC8/AC9/AC10 verify 완료"
```

---

## Task 10: 전체 신규 테스트 + 기존 회귀 (V1 + V3)

**Files:** N/A (test execution only)

- [ ] **Step 10.1: 신규 6개 테스트 batch 실행 (V1)**

```bash
bash plugins/spec-distill/tests/test_handoff_*.sh
```

(여러 파일을 순차 실행. 일부 shell은 위 형식이 한 파일만 실행할 수 있음. 명시적 loop:)

```bash
for t in plugins/spec-distill/tests/test_handoff_*.sh; do
  echo "=== $t ==="
  bash "$t"
  echo
done
```

Expected: 6개 모두 `Fail: 0`.

- [ ] **Step 10.2: 기존 spec-distill 전체 회귀 (V3)**

```bash
for t in plugins/spec-distill/tests/test_*.sh; do
  echo "=== $t ==="
  bash "$t" || echo "  ⚠ failed"
done
```

(`.py` 테스트도 있다면 별도로 실행: `python plugins/spec-distill/tests/test_*.py`.)

Expected: 모든 테스트 `Fail: 0`. 신규 추가 6개 + 기존 ~20개 모두 통과.

회귀 fail 시 root cause 분석. v0.9.0 변경이 기존 mode 검사를 깬 게 있는지 spec-reviewer.md diff로 확인.

---

## Task 11: Dogfood verification (V4 positive + V5 negative)

**Files:** N/A (manual verification)

- [ ] **Step 11.1: V4 positive — design.md 자체를 reviewer에 dispatch**

이 시점에서 v0.9.0 변경이 완료되어 있어야 함. 본 PR의 design.md(`docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md`)는 `## Handoff Context` 섹션을 포함하고 (`Phase 5: V4 positive dogfood`) — reviewer dispatch 시 `handoff_incomplete` issue가 *나오지 않아야* 함.

수동 방법: Claude Code 세션에서 `Skill spec-distill:reviewing-spec` 호출, spec_path 이 design.md 지정. reviewer 출력 `Issues:` 블록에 `handoff_incomplete` 없음 확인.

Expected: status `approved` or 다른 카테고리(scope_creep 등)만 — `handoff_incomplete` 부재.

- [ ] **Step 11.2: V5 negative — Handoff Context 섹션을 제거한 사본으로 dispatch**

```bash
cp docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md /tmp/test-handoff-stripped.md
# Remove `## Handoff Context` block (섹션 시작부터 다음 `## ` 시작까지)
sed -i.bak '/^## Handoff Context/,/^## /{/^## Handoff Context/d;/^## /!d}' /tmp/test-handoff-stripped.md
# (위 sed는 macOS BSD 환경. Linux GNU sed라면 -i 형식 차이 주의.)
grep -c "## Handoff Context" /tmp/test-handoff-stripped.md  # 0 이어야 함
```

이 stripped 파일을 reviewing-spec에 dispatch (수동). reviewer 출력에 `handoff_incomplete: section absent` issue가 *나와야* 함.

Expected: `Status: needs_revise`, Issues에 `handoff_incomplete` 포함.

이로써 reviewer가 카테고리를 silent-skip하지 않음을 dogfood로 검증.

- [ ] **Step 11.3 (optional): silent-skip 의심 시 추가 negative case**

C8 패턴 fixture — design.md 본문 어딘가에 `as discussed` 한 줄 추가 후 dispatch. `handoff_incomplete: conversation reference detected` issue 나와야 함.

---

## Task 12: 최종 branch state + PR 준비

**Files:** N/A (git operations only)

- [ ] **Step 12.1: 전체 commit summary 확인**

```bash
git log --oneline main..HEAD
```

Expected (대략 12개 정도 commit, design 작성 3개 + 구현 commits + 메타 commits):
```
<sha> chore(spec-distill): v0.9.0 — plugin.json + CHANGELOG + README
<sha> test(spec-distill): add design-mode 7-category regression (AC7)
<sha> feat(spec-distill): approve_handoff.sh emits 3-block Handoff packet (v0.9.0)
<sha> feat(spec-distill): add handoff_incomplete check to spec-reviewer (v0.9.0)
<sha> test(spec-distill): add 4 handoff reviewer tests (failing — TDD setup)
<sha> feat(spec-distill): add Handoff Context section to spec template
<sha> docs(spec-distill): design revise round 2 — 6 reviewer issues addressed
<sha> docs(spec-distill): design revise round 1 — 8 reviewer issues addressed
<sha> docs(spec-distill): design v0.9.0 — Handoff Context section + approve packet
```

- [ ] **Step 12.2: full diff 점검**

```bash
git diff main..HEAD -- plugins/spec-distill/
```

10–15개 파일 변경. 무관한 파일 없음 확인.

- [ ] **Step 12.3: PR 생성 안내 (사용자가 직접)**

`commit-commands:commit-push-pr` skill 또는 수동 `gh pr create`로 PR 생성:

```bash
gh pr create --base main --title "feat(spec-distill): v0.9.0 — Handoff Context section + approve packet" --body-file <(cat <<'EOF'
## Summary
- spec/design 파일에 `## Handoff Context` 섹션 의무화 + spec-reviewer에 `handoff_incomplete` block-severity 검사 카테고리 (영어 8 + 한국어 7 conversation reference 패턴)
- `approve_handoff.sh`가 사용자에게 copy-paste 가능한 `/compact` 양식 + 다음 세션 첫 프롬프트로 구성된 3-block Handoff packet emit
- Law 1 (Clarity Before Code) 자연스러운 확장 — /compact 경계를 spec lifecycle의 1급 시민으로 승격

## Test plan
- [ ] 신규 6개 `test_handoff_*.sh` 모두 통과 (V1)
- [ ] 기존 spec-distill 회귀 통과 (V3)
- [ ] V4 positive dogfood — 본 PR의 design.md 자체를 reviewing-spec에 dispatch, `handoff_incomplete` 없음 확인
- [ ] V5 negative dogfood — Handoff Context 섹션 제거 사본 dispatch, `handoff_incomplete: section absent` issue emit 확인

## Spec
`docs/superpowers/specs/2026-05-26-spec-distill-handoff-readiness-design.md` (3 라운드 review approved)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)
```

(사용자가 push 권한 확인 + PR 본문 검토 후 실행. agent는 PR 생성 권한 없음 — 사용자 sovereignty.)

---

## Plan Self-Review Checklist

- ✅ **Spec coverage**: G1–G6, AC1–AC10 모두 task에 매핑됨 (G1=Task 3, G2=Task 1, G3=Task 5, G4=Task 3 kill switch, G5=Task 7, G6=Task 2/4/6).
- ✅ **No placeholders**: 모든 step에 구체 code/command/expected output. "implement later" 없음.
- ✅ **Type consistency**: test file 이름 prefix 전부 `test_handoff_*` (Round 2 fix), section name `## Handoff Context` 전체 통일.
- ✅ **Dependency order**: C9 (a)→(b)→(c)→(d) 따름 (Task 1 template → Task 3 reviewer → Task 5 approve_handoff → Task 7–9 metadata).
- ✅ **TDD pattern**: Task 2가 test-first (failing), Task 3이 implement → pass. Task 6도 동일.
- ⚠ **Open Question**: OQ1 (test_handoff_design_mode.sh fixture 방식) — Task 4에서 grep-based static-text test 패턴 답습으로 결정 (기존 `test_spec_reviewer_design_checklist.sh` 답습). 실제 reviewer dispatch + fixture 파일 비교는 v0.10.0+ heavier integration test로 defer.

---

**Plan complete and saved to `docs/superpowers/plans/2026-05-26-spec-distill-handoff-readiness.md`. Two execution options:**

**1. Subagent-Driven (recommended)** — fresh subagent per task, review between tasks, fast iteration.

**2. Inline Execution** — execute tasks in this session using `superpowers:executing-plans`, batch execution with checkpoints.

**Which approach?**
