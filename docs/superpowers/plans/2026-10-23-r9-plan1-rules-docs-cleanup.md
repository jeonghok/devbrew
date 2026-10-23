# R9 계획 1 — 규칙 문장 · 쉬운 말 · 옮김 규칙 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CLAUDE.md · 철학 · 가이드의 규칙 문장을 지금 장치가 하는 일에 맞추고, 흐름 고정 점검 R9 행 다섯(끝에 할 일 · Law 1 중간 단계 · persona · skill 강제 · 브랜치 접두)과 설계문서 리뷰어의 「필수 섹션 누락」 · 지휘자 권장 옮김 규칙을 문면과 락으로 고친다.

**Architecture:** 대부분 문면 고침이고 문면마다 양 · 음 단언 짝을 둔 락을 함께 고친다. 동작이 바뀌는 곳은 셋 — 설계문서 프로필의 층 2 · `must_catch` 항목(리뷰 엔진이 읽는다), 브랜치 정규식(project-init 훅이 기본 브랜치 판을 읽는다), 쉬운 말 블록 정본과 사본 10곳(동기화 락). R14 와 겹치는 파일(쉬운 말 사본 둘 · `docreview_state.py` · spec-distill README · `test_epic_conductor_skill.sh` · `test_roadmap_status.sh`)은 R14 머지 뒤로 미룬 과제에서만 고친다.

**Tech Stack:** Markdown, macOS bash 3.2 셸 테스트, Python 3.9 표준 라이브러리 unittest.

**Spec:** `docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md` (§5 · §6 · §7 · AC1~AC10 · AC19~AC21 · `### Deferred to plan`)

**구현 브랜치:** `feature/rules-docs-cleanup` — 설계문서와 이 계획이 이미 있다. 새 브랜치를 만들지 않는다. 계획 2(`docs/superpowers/plans/2026-10-23-r9-plan2-cost-scale-disclosure.md`)는 이 계획의 PR 이 머지된 뒤 기본 브랜치에서 `feature/cost-scale-disclosure` 로 시작한다.

## Global Constraints

- **판 번호(AC20):** 머지 시점 기본 브랜치의 판에서 정한다 — 쉬운 말 사본을 바꾼 네 플러그인(plugin-audit · project-init · quality-gates · spec-distill) 모두 patch 하나. R14 가 먼저 머지해 spec-distill 판을 올리므로 숫자를 미리 박지 않는다. CHANGELOG 머리는 plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- git: merge 만 · HEAD 를 뒤로 옮기지 않는다(reset · rebase · force 없음) · 커밋은 pathspec · `git stash` 금지 · 공유 임시 폴더 glob 삭제 금지 · 다른 worktree 의 git 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Spec: docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md` 와 세션이 주는 `Co-Authored-By:` · `Claude-Session:` 줄.
- 셸: 테스트는 `/bin/bash`(3.2)로 돈다 · `$var` 뒤에 한글이 오면 `${var}` · 바꾼 셸 테스트는 `git ls-files -s` 로 `100755` 를 확인한다.
- 파이썬: 3.9 문법 · `read_text(` · `open(` 에 `encoding="utf-8"` · 테스트 실행은 `PYTHONDONTWRITEBYTECODE=1`.
- **변이(AC19):** 바뀐 동작 · 문면마다 테스트를 먼저 쓰고 RED 를 본 뒤 고친다. 락마다 변이(삭제 · 추가 · 반전 · 형태 변경)로 RED 를 보고 양성 대조로 과잉을 본다. 변이 전에 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --quiet` 로 확인한다. 음의 락에는 양의 짝을 둔다.
- **전체 스위트:** 공유 잠금 아래서만 돈다 — 잠금 경로는 `python3 plugins/spec-distill/scripts/conductor_ledger.py suite-lock --roadmap docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` 의 첫 줄(`$LOCK`), 실행은 `python3 plugins/spec-distill/scripts/suite_lock.py run --lock "$LOCK" --owner <agent 이름> --wait 1800 -- bash -c 'bash tools/suite/run-all.sh > <출력 파일> 2>&1'`. 종료 코드 75 면 그 줄의 주인 · 잡은 시각을 보고한다. 과제 안에서는 그 과제가 건드린 테스트만 잠금 없이 돌린다. 하위 agent 에게 보내는 글에도 이 잠금 줄을 그대로 싣는다.
- 기록 폴더: `$HOME/.claude/sdd-mirror/r9/`(git 밖).
- **규칙 문면:** 아래 과제가 적은 새 문면을 글자 그대로 쓴다. 규칙 문장에 출처 · 날짜 · 정당화를 넣지 않는다(CLAUDE.md 「Self-narrating artifact」). 헌장(CLAUDE.md · `docs/philosophy/*.md`)에서 백틱으로 감싼 `<플러그인>:<이름>` 은 그 플러그인의 agent · skill · command 여야 한다(`shared/tests/test_charter_citations.sh`) — 이름 붙은 skip 자리는 `DEVBREW_SKIP_HOOKS=…` 통째로 백틱에 넣는다.
- **보안-민감:** 설계문서 프로필(`design-doc.md`)과 `relay-checker.md` 편집은 리뷰어 규칙을 조이는 편집이다. PR 본문에 보안 리뷰 대상으로 밝힌다. 다른 agent · persona 파일은 고치지 않는다(diff 의 `agents/` 는 `relay-checker.md` 하나 — AC5).
- **R14 겹침(AC21):** `plugins/spec-distill/skills/{spec-review,request-framing}/SKILL.md` · `shared/docreview/scripts/docreview_state.py` · `plugins/spec-distill/README.md` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` · `plugins/spec-distill/tests/test_roadmap_status.sh` 는 Task 6(합치기) 뒤의 과제만 고친다. R14 몫(에픽이 자기 PR 번호를 적는 길 등)의 줄은 건드리지 않고, 합칠 때 R14 가 넣은 줄을 남긴다.

## 설계와 다른 점 · 설계에 없던 결정

- 브랜치 훅 테스트의 자리는 `plugins/project-init/tests/test_post_tool_use.py` 다(임시 레포 헬퍼 `make_repo` · `_RepoTestCase` 가 있다). 경로 예약 밖이라 Task 10 이 예약에 더한다.
- `shared/README.md` 의 사본 수 문장은 「모든 SKILL.md · 명령 파일」이라고 쓴다 — 설계 표의 「모든 진입 skill 의 SKILL.md」는 내부 skill(`reviewing-brief`)도 블록을 가지므로 사실과 조금 다르다. 뜻(수를 박지 않고 도출)은 같다.
- 브랜치 문서의 worktree 절은 템플릿의 마지막 문장(「project-init 훅은 `git checkout -b` · `git switch -c` 로 만든 이름만 확인한다」)을 옮기지 않는다 — 지금 훅은 reflog 로 `worktree add -b` 도 잡는다(`plugins/project-init/README.md` 「설치된 Hook」). 템플릿 문장의 어긋남은 이 계획 밖이라 Task 12 가 설계 `## 미룸` 에 올린다.
- 쉬운 말 skill 자리 셋의 새 문장은 정본 문장의 낱말(「기본 하나」 · 「여럿이거나 함께(병렬로)」)을 그대로 쓴다.
- `relay-checker` · `conductor-dispatch.md` 의 새 문장은 `「지휘자 의견:」 한 줄` 을 다시 쓰지 않는다 — `test_conductor_dispatch_reference.sh` 의 `once` 가 그 구가 절에 한 번만 있기를 요구한다.

## Review Focus

1. **한국어 제목이나 「해당 없음 — 이유」 만 적은 섹션을 가진 설계문서.** 리뷰어가 「필수 섹션 누락」을 내면 안 된다(가벼운 꼴을 허용한 U5 와 어긋난다). 프로필 항목이 출구 두 문장을 담는지 Task 8 `profile_required_sections_exits` 가 잠근다.
2. **이 레포에서 `docs/` 뒤 이름이 비었거나 대문자인 브랜치(`docs/` · `docs/X`).** 새 접두를 더해도 이름 규칙은 그대로라 거부돼야 한다. Task 5 `test_this_repo_rule_accepts_four_prefixes` 가 잠근다.
3. **skill 원문 라벨에 이미 「(권장)」 이 있는 질문을 지휘자가 옮긴다.** 새 규칙이 그 꼬리까지 떼라고 읽히면 안 된다 — 「skill 이 붙인 자리에만, 그 자리에 그대로」 문장이 남아야 한다. Task 9 의 양성 단언이 잠근다.
4. **할 일이 여럿이거나 함께 돌릴 수 있는 보고 · 커밋 · PR 본문.** 정본이 여럿을 밝히게 하고 커밋 · PR 본문은 순서 밖이라고 말해야 한다. Task 7 의 정본 단언 둘이 잠근다.
5. **R14 머지와 합칠 때 쉬운 말 사본 · 옮김 규칙 문장이 옛 글로 되돌아온다.** 합친 뒤 사본 동기화 락과 옛 문장 부재 단언이 다시 돌아야 한다. Task 12 Step 1 이 합친 사본에서 다시 돈다.

---

### Task 0: 자리 · 기준선 · 가벼운 다시 확인

**Files:** 없음(기록은 `$HOME/.claude/sdd-mirror/r9/`)

- [ ] **Step 1:** `git fetch origin && git status -sb` — `feature/rules-docs-cleanup` 위인지, origin 이 앞서면 `git merge --ff-only origin/feature/rules-docs-cleanup`(안 되면 멈추고 보고).
- [ ] **Step 2:** 공유 잠금 아래 전체 스위트를 돌려 `$HOME/.claude/sdd-mirror/r9/plan1-baseline.txt` 에 남긴다 — 이미 RED 인 줄이 기준이다.
- [ ] **Step 3: 다시 확인(설계 §9).** 설계가 적은 자리(ad7efbb6 기준 줄 번호)가 바뀌었는지만 본다 — `git diff ad7efbb6 HEAD --stat -- CLAUDE.md docs/philosophy docs/plugin-authoring.md docs/git-workflow shared/style shared/README.md plugins/*/skills/*/SKILL.md plugins/spec-distill/references/conductor-dispatch.md plugins/spec-distill/agents/relay-checker.md plugins/spec-distill/references/docreview-profiles/design-doc.md` 와 아래 셋. 결과를 `plan1-recheck.md` 에 표(자리 · 설계가 본 것 · 지금 · 같음/다름)로 적고, 설계와 다른 사실은 보고에 싣는다(전수 조사는 다시 하지 않는다).
  - 중간 단계를 막는 장치 문장 — `git grep -n -e '설계 → 계획' -e 'brainstorming 을 건너' -e '반드시 설계문서' -- plugins/*/skills plugins/*/references` 에서 「설계 없이 계획 · 구현으로 가지 못한다」는 뜻의 문장이 있는지.
  - R2 §4 처분 결과(`docs/superpowers/specs/2026-10-15-distill-distortion-devices-design.md` §4)와 철학 문서가 어긋나지 않는지(R2 설계 :241).
  - §6 :70 행의 사실 — 상태 루트가 메인 레포 쪽이고 처음 만들 때 `.gitignore` 를 둔다(`plugins/spec-distill/scripts/state_path.py` · `ensure_state_root`), qg 는 다음 시작 때 세션 폴더를 지우고 TTL GC 가 있다(`plugins/quality-gates/scripts/qg-gc.py`), 엔진 상태 쓰기가 `nofollow_write` 를 쓴다, plugin-audit 실행 폴더는 `prepare-run-dir.py` 가 `--repo-root` 아래에 `os.mkdir` 로 만든다.

---

### Task 1: Law 1 사실 문장 · 중간 단계 · P12 (AC3 · AC4)

**Files:**
- Modify: `CLAUDE.md`(:24 Law 1 줄)
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`(:11 Law 1 · :43-44 P12)
- Test: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`

**Interfaces:**
- Produces: CLAUDE.md · 철학 Law 1 의 문장 `설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다` — Task 8 이 spec-distill README 에 같은 문장을 쓰고 같은 테스트에서 잰다.

- [ ] **Step 1: 실패하는 단언을 쓴다.** governance 테스트의 AC8d 블록 뒤 `finish` 앞에 「AC3 · AC4 — Law 1」 블록을 더한다. 변수: `LAW1_C="$(grep -F '**Law 1 — Clarity Before Code.**' "$CLAUDE_MD")"`, `LAW1_P="$(grep -F '**Law 1 — Clarity Before Code.**' "$PHIL")"`, 그리고 이미 있는 `$p12`. 단언(모두 `assert_contains` / `assert_not_contains`, 메시지 머리 `AC3:` · `AC4:`):

```bash
MID='기본은 설계 → 계획 → 구현이다. 중간 크기 일은 이유를 밝히고 가벼운 꼴(PR 본문의 계획 · 짧은 brief)을 고를 수 있다. 가벼운 꼴도 필수 섹션이 다루는 것을 짧게 덮고, 다루지 않는 섹션은 「해당 없음 — 이유」로 적는다.'
FACT='설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다'
assert_contains "$LAW1_C" "$MID"   "AC3: CLAUDE.md Law 1 에 중간 단계 문장"
assert_contains "$p12"    "$MID"   "AC3: P12 에 중간 단계 문장"
assert_contains "$LAW1_C" '한 문장으로 설명 가능한 trivia diff (typo, rename, 주석-only, formatting — **파일 수와 무관하게**)는 게이트 우회' "AC3: CLAUDE.md trivia escape 그대로(양)"
assert_contains "$p12"    '한 문장으로 묘사 가능한 trivia diff(typo·rename·comment-only formatting — 파일 수와 무관하게)만 게이트를 우회하고' "AC3: P12 trivia escape 그대로(양)"
assert_contains "$LAW1_C" "$FACT" "AC4: CLAUDE.md Law 1 이 설계문서 쪽 사실을 쓴다"
assert_contains "$LAW1_P" "$FACT" "AC4: 철학 Law 1 이 설계문서 쪽 사실을 쓴다"
assert_contains "$LAW1_C" '인터뷰 brief 는 `check_brief.py` 가 구조로 막는다' "AC4: CLAUDE.md Law 1 — brief 는 구조로 막는다"
assert_contains "$LAW1_P" '인터뷰 brief 는 `check_brief.py` 가 구조로 막는다' "AC4: 철학 Law 1 — brief 는 구조로 막는다"
assert_not_contains "$LAW1_C" '최소한 **구조적 게이트** (필수 섹션:' "AC4: CLAUDE.md 에 없는 구조 게이트를 있다고 쓰던 옛 구가 없다"
assert_not_contains "$LAW1_P" 'silent하게 skip할 수 없는 구조적 게이트' "AC4: 철학 Law 1 의 옛 구가 없다"
```

- [ ] **Step 2:** `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh` — 새 단언 RED(중간 단계 · 사실 문장 없음, 옛 구 있음), 기존 단언 GREEN.
- [ ] **Step 3: CLAUDE.md :24 를 이 한 줄로 바꾼다.**

```markdown
**Law 1 — Clarity Before Code.** 명세가 모호한 상태에서는 구현이 진행되지 않습니다. 코드를 shipping하는 모든 플러그인은 실제 거절 메커니즘을 가져야 합니다 — 최소한 필수 섹션(Context/Why, Goals, Non-goals, Constraints, Acceptance Criteria, Files to Modify, Verification Plan, Rejected Alternatives, Metadata)을 silent하게 skip할 수 없어야 합니다. 지금 막는 자리: 인터뷰 brief 는 `check_brief.py` 가 구조로 막는다. 설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다. 기본은 설계 → 계획 → 구현이다. 중간 크기 일은 이유를 밝히고 가벼운 꼴(PR 본문의 계획 · 짧은 brief)을 고를 수 있다. 가벼운 꼴도 필수 섹션이 다루는 것을 짧게 덮고, 다루지 않는 섹션은 「해당 없음 — 이유」로 적는다. Adversarial self-review는 구조적 baseline 위에 강력 권장, 수치 스코어링은 허용되지만 권장하지 않음 (철학 P2). *Trivia escape:* 한 문장으로 설명 가능한 trivia diff (typo, rename, 주석-only, formatting — **파일 수와 무관하게**)는 게이트 우회. 정의 및 자격 규정은 philosophy P12 참조.
```

- [ ] **Step 4: 철학 :11 Law 1 과 P12 를 바꾼다.** Law 1 줄의 `**실제 거절 메커니즘** — … — 을 가져야 한다.` 부분을 `**실제 거절 메커니즘** — 최소한 필수 섹션(Context/Why·Goals·Non-goals·Constraints·Acceptance Criteria·Files to Modify·Verification Plan·Rejected Alternatives·Metadata)을 silent하게 skip할 수 없게 하는 것 — 을 가져야 한다. 지금 막는 자리: 인터뷰 brief 는 `check_brief.py` 가 구조로 막는다. 설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다.` 로 바꾸고 뒤의 「모델 신뢰만으로는 부족하다.」는 둔다. P12 본문 줄은 `… 파일에 기록된다.` 뒤에 Step 1 의 `MID` 문장을 넣고, 끝 구 `triviality 판정은 invoking skill의 책임이다.` 를 `triviality 판정과 「중간 크기」 판정은 invoking skill의 책임이다.` 로 바꾼다. P12 코드 줄은 `코드: \`plugins/spec-distill/references/trivia-escape.md\` · CLAUDE.md Law 1` 로 바꾼다.
- [ ] **Step 5:** governance 테스트 GREEN, `bash shared/tests/test_charter_citations.sh` GREEN.
- [ ] **Step 6: 커밋** — `git add CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `docs(rules): Law 1 에 지금 막는 자리와 중간 단계를 쓴다`.
- [ ] **Step 7: 변이(커밋 뒤).** (a) CLAUDE.md 에서 `MID` 문장만 지움 → `AC3` 두 단언 중 CLAUDE.md 쪽 RED. (b) P12 에서 `MID` 지움 → P12 쪽 RED. (c) CLAUDE.md Law 1 에 옛 구 `최소한 **구조적 게이트** (필수 섹션:` 을 되살림 → 부재 단언 RED. (d) 사실 문장의 「기계 게이트는 아니다」를 「기계 게이트다」로 바꿈(반전) → RED. 각 변이 뒤 복원 · `git diff HEAD --quiet`.

---

### Task 2: persona 편집 문장 (AC5)

**Files:**
- Modify: `CLAUDE.md`(:97) · `docs/philosophy/devbrew-harness-philosophy.md`(P10 :35)
- Modify: `plugins/quality-gates/README.md`(:13) · `plugins/plugin-audit/README.md`(:75-77) · `plugins/plugin-audit/skills/plugin-audit/SKILL.md`(종료 보고의 「이 감사의 compounding 은 …」 문장)
- Test: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`

- [ ] **Step 1: 실패하는 단언.** 같은 테스트에 「AC5 — persona」 블록. `PERS_C="$(grep -F '**버그가 리뷰를 탈출하면**' "$CLAUDE_MD")"`, `p10="$(awk '/^### P10/{f=1;next} /^(## |### )/{f=0} f' "$PHIL")"`.

```bash
NEWP='그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다'
assert_contains "$PERS_C" '기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것이다 — 코드만 패치하지 않는다.' "AC5: CLAUDE.md persona 기본"
assert_contains "$PERS_C" "$NEWP" "AC5: CLAUDE.md — 더 맞는 자리면 그것"
assert_not_contains "$PERS_C" '메모리' "AC5: CLAUDE.md persona 문장에 메모리가 없다"
assert_contains "$p10" "$NEWP" "AC5: P10 — 더 맞는 자리면 그것"
assert_not_contains "$p10" '메모리' "AC5: P10 에 메모리가 없다"
assert_not_contains "$p10" 'fix는 코드 패치가 아니라 그 버그를 잡았어야 할 persona 파일 편집이고' "AC5: P10 옛 문장이 없다"
for f in plugins/quality-gates/README.md plugins/plugin-audit/README.md plugins/plugin-audit/skills/plugin-audit/SKILL.md; do
  assert_contains "$(tr '\n' ' ' < "$f" | tr -s ' ')" '락 · 스크립트 · skill 이면 그것을 고친다' "AC5: $f 가 같은 뜻"
done
```

- [ ] **Step 2:** 테스트 RED 확인.
- [ ] **Step 3: 문면.** CLAUDE.md :97 을 `**버그가 리뷰를 탈출하면** 기본 해결책은 잡았어야 할 reviewer persona 파일을 편집하는 것이다 — 코드만 패치하지 않는다. 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다. 그 commit 이 compounding 이벤트다(Law 3).` 로. P10 의 `Load-bearing:` 뒤를 `버그가 리뷰를 탈출하면 기본 해결책은 그 버그를 잡았어야 할 persona 파일 편집이다 — 코드만 패치하지 않는다. 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고치고 이유를 적는다. 그 커밋이 compounding 이벤트(Law 3)다.` 로. qg README :13 은 `- **Law 3 (Compounding)** — 기본 substrate 는 reviewer-persona 편집이다 — 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고친다.`. plugin-audit README :76-77 과 SKILL.md 종료 보고의 「compounding 은 감사가 낳은 수정 커밋과 reviewer persona 편집이 맡는다」는 `compounding 은 감사가 낳은 수정 커밋과, 기본으로는 reviewer persona 편집이 맡는다 — 그 버그를 더 잘 잡는 자리가 락 · 스크립트 · skill 이면 그것을 고친다` 로(줄 바꿈은 주변 폭에 맞춘다). persona 파일(`agents/*.md`)은 열지 않는다.
- [ ] **Step 4:** governance GREEN · `python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_plain_audit_text.py'` · `-p 'test_skill_orchestration.py'` GREEN(종료 보고 단언이 깨지지 않는다).
- [ ] **Step 5: 커밋** — `docs(rules): persona 편집을 기본으로, 더 맞는 자리면 그것을`.
- [ ] **Step 6: 변이.** CLAUDE.md persona 줄에 「메모리에 적는다」를 덧붙임(추가) → 부재 단언 RED. P10 에서 `NEWP` 문장 삭제 → RED.

---

### Task 3: skill 강제 문장 · 가이드 (AC6 · AC8 일부)

**Files:**
- Modify: `CLAUDE.md`(:82) · `docs/plugin-authoring.md`(:29 · :42-46)
- Test: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`

- [ ] **Step 1: 실패하는 단언** — 「AC6」 블록(`$AUTHORING` 파일 부재면 이미 있는 fail-closed 갈래를 따른다):

```bash
AUTH="$(cat "$AUTHORING")"
assert_contains "$(grep -F 'plugin-dev:plugin-structure' "$CLAUDE_MD")" '다른 길이 맞으면 이유를 적는다' "AC6: CLAUDE.md 가 기본 경로 꼴"
assert_not_contains "$(cat "$CLAUDE_MD")" 'skill을 먼저 로드' "AC6: CLAUDE.md 강제 구 없음"
assert_contains "$AUTH" '기본은 해당 단계에 들어갈 때 그 단계의 skill 을 로드하는 것이다 — 다른 순서가 맞으면 이유를 적는다' "AC6: 가이드 기본 경로"
for gone in '해당 단계에 진입할 때만 로드' '선행 일괄 로드는 progressive disclosure 위반' '이 단계에서 필요한 유일한 것' '`/plugin-audit` ('; do
  assert_not_contains "$AUTH" "$gone" "AC6: 가이드에 「$gone」 없음"
done
assert_contains "$AUTH" '`/plugin-audit:plugin-audit`' "AC6: 완전명(양)"
assert_contains "$AUTH" '`agents/`, `references/`, `scripts/`, `skills/`를 shipping' "AC8: qg 폴더가 지금 폴더"
assert_not_contains "$AUTH" 'writer + reviewer + hook 파이프라인' "AC8: qg 에 없는 hook 을 말하던 구가 없다"
```

- [ ] **Step 2:** RED 확인.
- [ ] **Step 3: 문면.** CLAUDE.md :82 의 `새 플러그인을 brainstorming/설계할 때는 \`plugin-dev:plugin-structure\` skill을 먼저 로드 — 컴포넌트 타입과 \`plugin.json\` 스키마를 실재하는 surface 위에서 확정한다.` 를 `새 플러그인을 설계할 때 기본은 \`plugin-dev:plugin-structure\` 로 컴포넌트 타입 · \`plugin.json\` 스키마를 실재하는 surface 위에서 확정하는 것이다 — 다른 길이 맞으면 이유를 적는다.` 로. 가이드 :29 의 qg 줄을 `**writer + reviewer 파이프라인**. … \`agents/\`, \`references/\`, \`scripts/\`, \`skills/\`를 shipping.` 으로(가운데 문장은 그대로). :42 의 `해당 단계에 진입할 때만 로드 — 선행 일괄 로드는 progressive disclosure 위반:` 을 `기본은 해당 단계에 들어갈 때 그 단계의 skill 을 로드하는 것이다 — 다른 순서가 맞으면 이유를 적는다:` 로, :44 의 `이 단계에서 필요한 유일한 것.` 을 `이 단계의 기본 skill 이다.` 로, :46 의 `` `/plugin-audit` `` 를 `` `/plugin-audit:plugin-audit` `` 로.
- [ ] **Step 4:** governance GREEN · `bash shared/tests/test_invocation_surface.sh` GREEN.
- [ ] **Step 5: 커밋** — `docs(rules): plugin-structure 로드를 기본 경로로 · 가이드의 qg 폴더와 감사 완전명`.
- [ ] **Step 6: 변이.** 가이드에 「이 단계에서 필요한 유일한 것」을 되살림 → RED. :46 을 `/plugin-audit` 로 되돌림 → RED.

---

### Task 4: §6 의 나머지 규칙 문장 (AC8)

**Files:**
- Modify: `CLAUDE.md`(:31 · :48 · :50 · :70 · :71 · :72 · :73 · :103)
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`(P13 :47-48)
- Modify: `shared/README.md`(:36)
- Test: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`

- [ ] **Step 1: 실패하는 단언** — 「AC8 — 장치와 맞춘 규칙 문장」 블록. 한 줄씩 그 줄의 굵은 머리로 뽑는다(`cline() { grep -F "$1" "$CLAUDE_MD"; }`).

```bash
assert_not_contains "$(cline '**레포 전용 값 금지.**')" '`gh`' "AC8 :31: gh 는 레포마다 정할 값이 아니다"
assert_contains "$(cline '**레포 전용 값 금지.**')" '경로 · 테스트 명령 · 브랜치 · 모델 같은 값' "AC8 :31(양)"
assert_contains "$(cline '**Scoped agents')" '역할 프롬프트는 첫머리에 맡는 일을 밝힌다' "AC8 :48"
assert_not_contains "$(cline '**Scoped agents')" 'You are NOT responsible for Z' "AC8 :48: 영어 공식 강제 없음"
assert_contains "$(cline '**최소 버전이 선언된 의존성.**')" '`dependencies.md` 표(이름 · 최소 판 · 강도 · 없을 때)' "AC8 :50"
assert_contains "$(cline '**최소 버전이 선언된 의존성.**')" '`check_deps.py measure`' "AC8 :50 판 측정"
assert_contains "$(cline '**JSON이 아니라 마크다운 state.**')" '로드맵 단위 지휘 기계 상태(`machine.md`)' "AC8 :70 수명 넷"
assert_contains "$(cline '**JSON이 아니라 마크다운 state.**')" '링크 검사 없이 만든다' "AC8 :70 예외"
assert_contains "$(cline '**모든 훅에 kill switch.**')" '그 플러그인의 훅과 진입 skill 을 끈다' "AC8 :71"
assert_contains "$(cline '**훅 공존.**')" 'Hooks Installed(한국어 README 는 「설치된 Hook」)' "AC8 :72"
assert_contains "$(cline '**Loud logging')" '필수 의존(`dependencies.md` 강도 멈춤)은 이유와 설치 방법을 보이고 멈춘다' "AC8 :73"
assert_contains "$(grep -F '## 목차' "$CLAUDE_MD")" '한 번 쓰고 닫는 계획 · 기록은 모델이 판단한다' "AC8 :103"
p13="$(awk '/^### P13/{f=1;next} /^(## |### )/{f=0} f' "$PHIL")"
assert_contains "$p13" '`plugins/project-init/hooks/hooks.json` · `shared/entry/entry_preflight.py`' "AC8 P13 코드"
assert_not_contains "$p13" 'hook=집행 레이어' "AC8 P13 옛 구 없음"
STYLE="$(grep -F '`style/`' shared/README.md)"
assert_not_grep "$STYLE" '[0-9]+곳' "AC8: shared/README 에 사본 수 숫자가 없다"
assert_contains "$STYLE" '글롭에서 도출' "AC8: shared/README 가 도출을 말한다(양)"
```

- [ ] **Step 2:** RED 확인.
- [ ] **Step 3: CLAUDE.md 문면.** 각 줄을 아래로 바꾼다(굵은 머리는 그대로 — shape 앵커 `모든 훅에 kill switch` · `최소 버전이 선언된 의존성` · `` `tools:` allowlist를 선언 ``).
  - :31 `- **레포 전용 값 금지.** 경로 · 테스트 명령 · 브랜치 · 모델 같은 값은 도출하거나 레포마다 정하게 한다(철학 P8).`
  - :48 — `역할 프롬프트는 *"You are X. You are responsible for Y. You are NOT responsible for Z."*로 시작.` 한 문장만 `역할 프롬프트는 첫머리에 맡는 일을 밝힌다. 맡지 않는 일(쓰기 · 고치기 등)은 \`tools:\` allowlist 가 막고, 프롬프트가 밝힐 때는 같은 첫머리에 둔다. 특정 영어 공식은 강제하지 않는다.` 로.
  - :50 `- **최소 버전이 선언된 의존성.** 플러그인이 기대는 도구 · 다른 플러그인은 그 플러그인의 \`dependencies.md\` 표(이름 · 최소 판 · 강도 · 없을 때)에 적고, 판 칸은 \`check_deps.py measure\` 가 잰다(개발 · 검증할 때 깔려 있던 판 — 손으로 고치지 않는다). \`other-plugin:agent-name\`을 dispatch하는 플러그인은 README prerequisites에도 \`other-plugin\`을 리스트. Silent coupling은 버그.`
  - :70 `- **JSON이 아니라 마크다운 state.** 런타임 state 는 \`.claude/<plugin>/\` 하위에 산다(git-ignored, plugin namespace 밖으로 나가지 않는다). 상태 루트는 메인 레포 쪽이고 처음 만들 때 자기 \`.gitignore\` 를 둔다. 수명은 넷이다 — 세션 단위(\`.claude/<plugin>/<session-id>/<file>\` — 성공 시 지우고 실패 시 디버깅을 위해 남긴다. qg 는 다음 시작 때 지우고 TTL GC 가 남은 것을 치운다) · 문서 단위 리뷰 원장(그 문서가 사라질 때 정리) · 로드맵 단위 지휘 기계 상태(\`machine.md\`) · 실행 단위 산출(plugin-audit 실행 폴더 — 지우지 않는다). 엔진 skill 의 상태 폴더 쓰기는 링크를 따라가지 않는다(\`nofollow_write\`). 예외 하나 — plugin-audit 실행 폴더는 넘겨받은 \`--repo-root\`(기본 cwd) 아래에 링크 검사 없이 만든다. 인터뷰처럼 세션을 넘는 진행 기록은 docs 의 추적 파일에 두고 산출물과 함께 커밋한다. **Secret 기록 금지** — placeholder 참조 사용 (철학 P21).` — Task 0 Step 3 이 다른 사실을 찾았으면 그 사실로 고쳐 쓰고 보고한다.
  - :71 `- **모든 훅에 kill switch.** 진입 skill 도 같다. \`DEVBREW_<PLUGIN>_DISABLE=1\` 은 그 플러그인의 훅과 진입 skill 을 끈다(진입 사전 검사). \`DEVBREW_SKIP_HOOKS=<plugin>:<이름>\` 은 이름 붙은 한 곳만 끈다 — 훅이나 훅이 아닌 이름 붙은 자리(예: \`DEVBREW_SKIP_HOOKS=spec-distill:review-entry\` · \`DEVBREW_SKIP_HOOKS=quality-gates:qg-gc\`)이고 진입 skill 자체는 끄지 않는다. 어떤 훅도 자신의 kill switch 존중을 거부할 수 없음 — kill switch는 보안 컨트롤.`
  - :72 — `README의 "Hooks Installed"에` 를 `README의 Hooks Installed(한국어 README 는 「설치된 Hook」) 절에` 로.
  - :73 `- **Loud logging을 동반한 graceful degradation.** 누락된 optional 의존성은 capability를 downgrade하고 알린다, crash하지 않음 — 사용자가 출력에서 fallback이 돌았음을 알 수 있어야 함. 필수 의존(\`dependencies.md\` 강도 멈춤)은 이유와 설치 방법을 보이고 멈춘다. 의존마다 없을 때의 동작은 그 표의 「없을 때」 칸이 적는다. 훅은 사람에게 말할 자리가 없어 바닥 미만이면 건너뛰고, 그 사실을 README Prerequisites 가 공시한다.`
  - :103 `- **\`docs/**.md\` 의 \`## 목차\` — 기본은 둔다.** 앵커로 인용되는 오래 사는 문서(가이드 · 철학 · 설계문서)가 ~300줄을 넘으면 상단(제목 + 에피그래프 + 한 줄 정체성 다음, 본문 진입 직전)에 \`## 목차\` 섹션을 두고 §X.Y depth로 anchor 링크한다. 섹션 추가/이름 변경/삭제 시 같은 commit에서 TOC도 동기화 (drift 시 cite-by-anchor 깨짐). 한 번 쓰고 닫는 계획 · 기록은 모델이 판단한다. 짧은 doc(<300줄)은 면제.`
- [ ] **Step 4: P13 · shared/README.** P13 본문 줄의 `hook=집행 레이어` 를 `hook=사건에 붙는 관찰 · 알림` 으로 바꾸고 `per-plugin kill switch).` 뒤에 `진입 skill 의 사전 검사(\`!\`)가 kill switch 를 모델 판단 밖에서 집행한다.` 를 넣는다. 코드 줄은 `코드: \`plugins/project-init/hooks/hooks.json\` · \`shared/entry/entry_preflight.py\``. `shared/README.md` :36 의 `15곳의 SKILL.md·명령 파일에 바이트 그대로 복사된다.` 를 `모든 SKILL.md · 명령 파일에 바이트 그대로 복사된다(대상은 락이 글롭에서 도출).` 로.
- [ ] **Step 5:** governance GREEN · `bash shared/tests/test_charter_citations.sh` · `python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_check_shape_completeness.py'` GREEN. charter 가 백틱 이름을 거부하면(`<플러그인>:<이름>` 꼴) 그 토큰을 `DEVBREW_SKIP_HOOKS=` 통째로 감싼다.
- [ ] **Step 6: 커밋** — `docs(rules): 의존 · state · kill switch · 훅 절 · degrade · 목차 · 역할 프롬프트 문장을 장치에 맞춘다`.
- [ ] **Step 7: 변이.** :71 에서 「진입 skill 을」 을 지움 → RED. shared/README 를 「15곳」으로 되돌림 → 부재 단언 RED. :72 에서 괄호를 지움 → RED.

---

### Task 5: 브랜치 규칙 문서 · 접두 넷 · 훅 테스트 (AC7)

**Files:**
- Modify: `docs/git-workflow/branch-strategy.md` · `CLAUDE.md`(:14 · :18)
- Test: `plugins/project-init/tests/test_post_tool_use.py`(새 클래스) · `plugins/project-init/tests/test_branch_strategy_rebase_clause.sh`(손대지 않고 GREEN)

**Interfaces:**
- Consumes: `_hook.read_branch_rule(cwd) -> (re.Pattern | None, str | None)` · `_hook.derive_prefixes(pattern) -> list[str]` · `_hook.check_branch_name(name, pattern) -> (str, str) | None` · 테스트 헬퍼 `make_repo(root, content, origin_head=True) -> str`(origin 기본 브랜치에 그 내용의 `docs/git-workflow/branch-strategy.md` 를 커밋한 클론).

- [ ] **Step 1: 실패하는 테스트.** `test_post_tool_use.py` 에 `class ThisRepoBranchStrategyTest(_RepoTestCase)`. `DOC = Path(__file__).resolve().parents[3] / "docs" / "git-workflow" / "branch-strategy.md"`. 도우미 `_rule(text)` 는 `self.repo(text)` 의 클론에서 `_hook.read_branch_rule(work)` 를 불러 `notice is None` 을 단언하고 패턴을 돌려준다.
  - `test_this_repo_rule_accepts_four_prefixes` — 이 레포 문서로: `docs/x` · `chore/x` · `feature/x` · `fix/x` 는 `p.match` 가 참, `misc/x` · `docs/` · `docs/X` 는 거짓. `_hook.derive_prefixes(p) == ["feature", "fix", "docs", "chore"]`. `_hook.check_branch_name("misc/x", p)[0]` 에 `허용 접두어: feature, fix, docs, chore` 가 있다.
  - `test_rule_without_docs_rejects_docs_branch` — 양성 대조: 이 레포 문서에서 `feature|fix|docs|chore` 를 `feature|fix|chore` 로 바꾼 글(바뀌었음을 먼저 단언)로 `p.match("docs/x")` 가 거짓.
- [ ] **Step 2:** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s plugins/project-init/tests -p 'test_post_tool_use.py' -k ThisRepo` — 첫 테스트 RED(지금 정규식은 둘), 둘째는 치환 대상이 없어 RED.
- [ ] **Step 3: `branch-strategy.md`.** :12 를 `^(feature|fix|docs|chore)/[a-z0-9][a-z0-9.-]*$` 로. 나머지 문면은 `plugins/project-init/templates/github-flow/branch-strategy.md` 의 지금 문면을 따른다 — :6 `- 모든 작업은 단명 브랜치(접두는 아래 \`Branch Naming Pattern\`)에서` · 접두 표에 `| \`docs/<name>\` | 문서만 바꾸는 일 | \`docs/branch-rules\` |` 과 `| \`chore/<name>\` | 설정 · 잡일 | \`chore/ci-cache\` |` 두 행 · `### Working in a worktree` 절(템플릿 :57-68, 마지막 문단의 「project-init 훅은 … 확인하지 않는다」 문장은 빼고 「이름은 위 \`Branch Naming Pattern\` 과 같은 규칙을 따른다.」만 둔다) · Rules for Claude 의 첫 줄을 `- **변경 작업(파일 편집 · 커밋)을 시작하기 전** 현재 브랜치 확인: \`git branch --show-current\` — 읽기만 하는 작업에는 확인하지 않는다` 로, 셋째 줄을 `- **ALWAYS** 브랜치 이름은 위 \`Branch Naming Pattern\` 의 접두 중 하나로 시작` 으로. 마지막 rebase 줄(`` `git rebase`는 절대 안 됨 ``)은 글자 그대로 둔다.
- [ ] **Step 4: CLAUDE.md.** :14 `- Branch: \`main\`에서 \`feature/*\` · \`fix/*\`(문서만이면 \`docs/*\`, 설정 · 잡일이면 \`chore/*\`). kebab-case, 2–4 단어.` · :18 `- project-init 훅이 브랜치 이름 · 커밋 꼴을 확인해 알린다(막지 않는다)`.
- [ ] **Step 5:** 새 테스트 GREEN · `test_post_tool_use.py` 전체 · `test_branch_prefix_templates.py` · `bash plugins/project-init/tests/test_branch_strategy_rebase_clause.sh` · `bash plugins/project-init/tests/test_post_tool_use_branch.sh` GREEN.
- [ ] **Step 6: 커밋** — `feat(project-init): 이 레포 브랜치 접두에 docs · chore 를 더한다 · 훅이 기본 브랜치 판으로 읽는 것을 잰다`.
- [ ] **Step 7: 변이.** 이 레포 문서 정규식에서 `docs|` 를 지움 → `test_this_repo_rule_accepts_four_prefixes` RED. `chore` 를 `chores` 로(형태 변경) → RED.

---

### Task 6: R14 머지 확인 · 기본 브랜치 합치기 (AC21 앞부분)

**Files:** 합치기 커밋뿐

- [ ] **Step 1:** `git fetch origin` 뒤 R14 PR 머지 여부를 본다 — `gh pr list --state merged --head feature/r8-device-leftovers --json number,mergeCommit` 이 비어 있지 않으면 머지됨.
- [ ] **Step 2 (머지됨):** `git merge --no-edit origin/main`(merge commit). 충돌은 R14 가 넣은 줄을 남기고 R9 줄만 다시 얹는다. 합친 뒤 Task 1~5 의 테스트와 `bash plugins/spec-distill/tests/test_roadmap_status.sh` · `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh` 를 돌린다. 기본 브랜치에서 이미 RED 였던 것은 Task 0 기준선과 견준다.
- [ ] **Step 2' (아직):** 기다리지 않는다. Task 7~10 을 지금 바탕에서 하고, Task 12 Step 1 이 R14 머지 뒤 같은 합치기를 한다(PR 은 R14 머지 전에 머지하지 않는다). 그 사실을 보고에 적는다.
- [ ] **Step 3:** 합쳤으면 `git push origin HEAD:feature/rules-docs-cleanup`.

---

### Task 7: 「끝에 할 일」 — 정본 · 사본 10곳 · skill 자리 셋 · N13 (AC1 · AC2)

**Files:**
- Modify: `shared/style/plain-language.md`(:5) 와 사본 10곳(`plugins/plugin-audit/skills/plugin-audit/SKILL.md` · `plugins/project-init/skills/project-init/SKILL.md` · `plugins/quality-gates/skills/{artifact-critique,quality-pipeline}/SKILL.md` · `plugins/spec-distill/skills/{epic-conductor,pm-interview,request-framing,reviewing-brief,roadmap-status,spec-review}/SKILL.md`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(완료 보고 :1498) · `plugins/quality-gates/skills/artifact-critique/SKILL.md`(최종 보고 :362) · `plugins/plugin-audit/skills/plugin-audit/SKILL.md`(종료 보고 :300)
- Test: `shared/tests/test_plain_language_block.sh` · `plugins/quality-gates/tests/test_plain_qg_templates.sh`(:89 · :156) · `plugins/plugin-audit/tests/test_plain_audit_text.py`(:62)

- [ ] **Step 1: 실패하는 단언.** `test_plain_language_block.sh` 의 예외 문장 단언 뒤에:

```bash
CANON="$(cat "$ROOT/shared/style/plain-language.md")"
NEW='- 순서: 첫 줄에 지금 상태(무엇을 했고 어디까지 왔나) 한 문장, 가운데에 이유·근거, 맨 끝에 사용자가 할 일. 할 일은 기본 하나다 — 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다. 할 일이 없으면 없다고 쓴다. 커밋·PR 본문에는 이 순서를 적용하지 않는다.'
assert_eq "$(grep -cxF -- "$NEW" "$ROOT/shared/style/plain-language.md")" "1" "AC1: 정본 순서 줄이 새 문장 그대로(양)"
assert_not_contains "$CANON" '맨 끝에 사용자가 할 일 하나.' "AC1: 정본에 옛 「할 일 하나」 가 없다(음)"
assert_contains "$CANON" '확인해서 남은 것도 경고도 없으면 「이상 없음」 한 줄로 쓴다. 확인하지 못한 것·빠진 검사·셀 수 없는 것은 따로 한 줄씩 쓴다 — 없는 것과 확인 못 한 것은 다르다.' "N13: 없음과 확인 못 함을 가른다(양)"
```

  `test_plain_qg_templates.sh` :89 는 `assert_contains "$SF" "After the publish result line, end with the user's next action — one by default; if there are several, or they can run together (in parallel), say so and list them together" "AC2: 완료 보고 끝 할 일 — 기본 하나 · 여럿이면 밝힘"` 과 `assert_not_contains "$SF" 'exactly one next action' "AC2: exactly one 없음"` 으로, :156 은 `assert_contains "$CAF" '맨 끝에 사용자가 할 일을 쓴다 — 기본 하나, 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다.' …` 와 `assert_not_contains "$CAF" '할 일 하나를 쓴다' …` 로 바꾼다. `test_plain_audit_text.py` :62 는 `assertIn("맨 끝에 사용자가 할 일을 쓴다 — 기본 하나, 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다", step)` 와 `assertNotIn("할 일 하나를 쓴다", step)`.
- [ ] **Step 2:** 세 테스트 RED.
- [ ] **Step 3: 정본 :5 를 Step 1 의 `NEW` 줄로 바꾸고, 사본 10곳의 같은 줄을 바이트 그대로 바꾼다** — `shared/tests/plain_language_block.py` 가 대상을 도출하니 손으로 고른 목록과 그 도출이 같은지 `bash shared/tests/test_plain_language_block.sh` 로 본다.
- [ ] **Step 4: skill 자리 셋.** quality-pipeline :1498 의 `After the publish result line, end with exactly one next action for the user (e.g. …)` 를 `After the publish result line, end with the user's next action — one by default; if there are several, or they can run together (in parallel), say so and list them together (e.g. …)` 로(예시 괄호는 그대로). artifact-critique :362 와 plugin-audit :300 의 `맨 끝에 사용자가 할 일 하나를 쓴다` 를 `맨 끝에 사용자가 할 일을 쓴다 — 기본 하나, 여럿이거나 함께(병렬로) 할 수 있으면 그렇다고 밝히고 함께 쓴다` 로(문장 끝 구두점 · 예시는 그대로). roadmap-status(:77) · project-init(:320) · epic-conductor(:225)는 고치지 않는다.
- [ ] **Step 5:** 세 테스트 GREEN · `git grep -n '할 일 하나' -- plugins/*/skills shared/style` 결과가 roadmap-status · project-init · epic-conductor 의 「하나만 고르는」 자리뿐인지 본다. `python3 -m unittest discover -s plugins/project-init/tests -p 'test_plain_init_text.py'` GREEN(project-init 보고 자리는 그대로다).
- [ ] **Step 6: 커밋** — `docs(style): 끝에 할 일은 기본 하나 — 여럿이거나 병렬이면 밝힌다 · 사본 10곳 · skill 자리 셋`.
- [ ] **Step 7: 변이.** 정본에 옛 「맨 끝에 사용자가 할 일 하나.」를 되돌림(사본은 그대로) → 정본 단언 RED 와 사본 동기화 RED 둘. 사본 하나만 옛 줄로(형태 변경) → 동기화 RED. 정본 N13 문장의 「확인 못 한 것은 다르다」 삭제 → N13 단언 RED.

---

### Task 8: 설계문서 리뷰어의 「필수 섹션 누락」 (AC4a — 보안-민감)

**Files:**
- Modify: `plugins/spec-distill/references/docreview-profiles/design-doc.md`(frontmatter `layer_rubric.layer2` · `must_catch` · `## 층 2` 목록)
- Modify: `shared/docreview/scripts/docreview_state.py`(`CATEGORY_GLOSS` 한 줄)
- Modify: `plugins/spec-distill/README.md`(:72 Law 1 줄 하나)
- Test: `shared/tests/test_docreview_profiles.sh`(:104 층 2 기대 목록 · 새 단언) · `plugins/spec-distill/tests/test_distortion_devices.sh`(:96) · `shared/tests/test_docreview_profile_schema.sh`(손대지 않고 GREEN — 사상 도출) · `shared/tests/fixtures/docreview/cases_advice.sh`(손대지 않고 GREEN) · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh`(README 사실 단언)

**Interfaces:**
- Consumes: Task 1 의 사실 문장 `FACT`.
- Produces: 범주 키 `required_sections`, 사람말 `필수 섹션 누락`.

- [ ] **Step 1: 실패하는 단언.** `test_docreview_profiles.sh` :104 의 기대 목록을 `['placeholder', 'ambiguity', 'scope_creep', 'approaches_comparison', 'isolation', 'testing', 'handoff_incomplete', 'required_sections']` 로, 메시지를 「design-doc 층 2 — 일곱 + 필수 섹션 누락」으로 바꾸고 아래를 더한다.

```bash
assert_eq "$(chk "$DD" '"required_sections" in d["must_catch"]')" "True" "AC4a: design-doc must_catch 가 필수 섹션 누락을 지목한다"
DDL2="$(awk '/^## 층 2/{f=1;next} /^## /{f=0} f' "$DD")"
RS_LINE="$(printf '%s\n' "$DDL2" | grep -F -- '- `required_sections` —')"
for s in 'Context/Why' 'Goals' 'Non-goals' 'Constraints' 'Acceptance Criteria' 'Files to Modify' 'Verification Plan' 'Rejected Alternatives' 'Metadata'; do
  assert_contains "$RS_LINE" "$s" "AC4a: required_sections 줄이 섹션 「$s」 를 이름으로 댄다"
done
assert_contains "$RS_LINE" '「해당 없음 — 이유」' "profile_required_sections_exits: 해당 없음 출구"
assert_contains "$RS_LINE" '제목이 달라도 같은 것을 다루면 있는 것으로 본다' "profile_required_sections_exits: 다른 제목 출구"
```

  `test_distortion_devices.sh` :96 의 기대 줄을 `'must_catch: [goal_fit, problem_definition, scope, architecture, required_sections]'`, 메시지를 「AC16b · R9 U10: 설계문서 must_catch 는 네 축 + 필수 섹션 누락」으로. governance 테스트의 Task 1 블록에 `assert_contains "$(grep -F '**Law 1 (Clarity Before Code)**' plugins/spec-distill/README.md)" "$FACT" "AC4a: spec-distill README Law 1 이 같은 사실"` 과 `assert_not_contains "$(cat plugins/spec-distill/README.md)" '필수 섹션 게이트 구현은 0' "AC4a: README 옛 구 없음"`.
- [ ] **Step 2:** 세 테스트 RED.
- [ ] **Step 3: 프로필.** frontmatter `layer2:` 끝에 `, required_sections`, `must_catch: [goal_fit, problem_definition, scope, architecture, required_sections]`. `## 층 2` 목록의 `handoff_incomplete` 줄 뒤에:

```markdown
- `required_sections` — 필수 섹션 누락. Context/Why · Goals · Non-goals · Constraints · Acceptance Criteria · Files to Modify · Verification Plan · Rejected Alternatives · Metadata 가운데 없는 절이 있거나, 있는데 비어 있고 「해당 없음 — 이유」도 없을 때만 낸다. 제목이 달라도 같은 것을 다루면 있는 것으로 본다(예: 한국어 제목). 처분은 빠진 절을 채우는 `fix` 다 — 그 절을 쓸 사실이 저자에게 없으면 `ask`.
```

- [ ] **Step 4: 사상.** `CATEGORY_GLOSS` 의 design-doc 층 1·2 묶음 끝(`"handoff_incomplete": "이어갈 컨텍스트 부족",` 뒤)에 `"required_sections": "필수 섹션 누락",`.
- [ ] **Step 5: README :72.** `**설계문서에는 필수 섹션 구조 게이트가 없다** — 설계문서의 명확성은 \`doc-critic\` 층 2(\`placeholder\`·\`ambiguity\`)와 승인 게이트가 판정한다 — 이 리포의 Law 1 필수 섹션 게이트 구현은 0 이다.` 를 `**설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다 — 기계 게이트는 아니다** — \`doc-critic\` 층 2 의 \`required_sections\` 를 프로필이 \`must_catch\` 로 지목해 승인 게이트의 질문이 된다. 그 밖의 명확성은 같은 층 2(\`placeholder\`·\`ambiguity\`)와 승인 게이트가 판정하고, 섹션 유무를 기계로 막는 게이트는 없다.` 로.
- [ ] **Step 6:** 아래가 모두 GREEN — `bash shared/tests/test_docreview_profiles.sh` · `bash plugins/spec-distill/tests/test_distortion_devices.sh` · `bash shared/tests/test_docreview_profile_schema.sh` · `bash shared/tests/test_docreview_advice.sh`(design-doc 참고 축 단언 `cases_advice.sh:16-18` 이 그대로 GREEN) · `bash shared/tests/test_docreview_golden.sh` · `bash shared/tests/test_docreview_mutations.sh` · `bash plugins/spec-distill/tests/test_dispatch_profile_inline.sh` · `bash plugins/spec-distill/tests/test_handoff_design_mode.sh` · `bash shared/tests/test_docreview_codex.sh` · governance · `python3 shared/docreview/scripts/docreview_state.py profile-check plugins/spec-distill/references/docreview-profiles/design-doc.md` rc 0. 그 밖에 `git grep -l 'design-doc.md' -- shared/tests plugins/spec-distill/tests` 의 셸 테스트를 모두 돌린다.
- [ ] **Step 7: 커밋** — `feat(spec-distill): 설계문서 리뷰어가 필수 섹션 누락을 승인을 막는 지적으로 낸다`(본문에 「리뷰어 규칙 조임 — 보안 리뷰 대상」).
- [ ] **Step 8: 변이.** (a) 층 2 목록 줄 `required_sections` 삭제 → profiles RED. (b) `must_catch` 에서만 뺌 → profiles · distortion RED. (c) `CATEGORY_GLOSS` 줄 삭제 → `test_docreview_profile_schema.sh` 사상 RED. (d) `must_catch` 에만 남기고 `layer2` 에서 뺌 → `profile-check` rc 2 `must_catch_unknown_axis:required_sections`.

---

### Task 9: 지휘자 권장 옮김 규칙 (AC9 — 보안-민감)

**Files:**
- Modify: `plugins/spec-distill/references/conductor-dispatch.md`(`## 사람 자리` :32)
- Modify: `plugins/spec-distill/agents/relay-checker.md`(항목 4 · 「지휘자가 만든 질문」 문단)
- Test: `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` · `plugins/spec-distill/tests/test_epic_conductor_skill.sh`(relay-checker 단언 줄 :61-63)

- [ ] **Step 1: 실패하는 단언.** dispatch 테스트의 `## 사람 자리` once 목록에 두 문장을 더한다 — `'지휘자 자신의 권장은 라벨 안 「(권장)」으로 넣지 않고 그 의견 줄에만 쓴다 — 지휘자가 만든 질문에서도 같다.'` · `'skill 이 문장으로 낸 권장(예: 「I recommend …」)은 그 문장을 옮겨 싣고 라벨 꼬리 「(권장)」으로 바꾸지 않는다 — 라벨은 원문 라벨 그대로다.'` · `'그 선택지에는 「(권장)」을 달지 않는다'`. 그리고 `assert_not_contains "$(sec '## 사람 자리')" '지휘자 것이라고 밝힌다' "AC9: 옛 문장 없음"`. epic-conductor 테스트의 relay-checker 리터럴 목록 뒤에 `assert_contains "$(cat "$RC")" '「문장 권장이 라벨 꼬리로 옮겨짐」' …` · `assert_contains "$(cat "$RC")" '「지휘자가 만든 질문의 라벨에 (권장)」' …` · `assert_contains "$(cat "$RC")" 'skill 이 붙인 자리에만, 그 자리에 그대로 있는가' "AC9(양): skill 원문의 (권장) 은 그대로 대조한다"` · `assert_not_contains "$(cat "$RC")" '지휘자 것이라고 밝혀 두었는지' …`.
- [ ] **Step 2:** 두 테스트 RED.
- [ ] **Step 3: dispatch 문면.** `지휘자 의견은 선택지 밖 「지휘자 의견:」 한 줄로만 쓴다.` 바로 뒤에 Step 1 의 첫 두 문장을 넣고, `그 선택지의 「(권장)」 도 지휘자 것이라고 밝힌다` 를 `그 선택지에는 「(권장)」을 달지 않는다` 로 바꾼다.
- [ ] **Step 4: relay-checker 문면.** 항목 4 끝에 `skill 원문이 권장을 라벨이 아니라 문장으로 냈는데 띄운 질문의 라벨에 「(권장)」 꼬리가 붙었으면 어긋남이다 — 「문장 권장이 라벨 꼬리로 옮겨짐」 이라고 적는다.` 를 더한다. 「지휘자가 만든 질문」 문단의 `그때도 그 질문에 보인 「(권장)」 마다 지휘자 것이라고 밝혀 두었는지 보고, 밝히지 않았으면 어긋남이다.` 를 `그때도 그 질문의 라벨에 「(권장)」 이 있으면 어긋남이다 — 「지휘자가 만든 질문의 라벨에 (권장)」 이라고 적는다(지휘자 권장은 선택지 밖 의견 줄에만 쓴다).` 로. 역할 첫 문단 · `tools:` 는 그대로.
- [ ] **Step 5:** 두 테스트 GREEN · `bash shared/tests/test_dispatch_disposition.sh` · `git grep -l 'relay-checker\|conductor-dispatch' -- plugins/spec-distill/tests shared/tests` 의 셸 테스트 GREEN.
- [ ] **Step 6: 커밋** — `fix(spec-distill): 지휘자 권장은 라벨 밖 · skill 의 문장 권장은 문장으로 옮긴다`(본문에 「옮김 대조 agent 를 조임 — 보안 리뷰 대상」).
- [ ] **Step 7: 변이.** dispatch 의 새 첫 문장을 옛 「그 선택지의 「(권장)」 도 지휘자 것이라고 밝힌다」로 되돌림 → RED. relay-checker 의 「문장 권장이 라벨 꼬리로 옮겨짐」 문장 삭제 → RED.

---

### Task 10: 로드맵 R9 경로 예약에 예약 밖 파일을 더한다

**Files:**
- Modify: `docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md` · `R9.md`(생성기가 다시 쓴다)
- Modify: `plugins/spec-distill/tests/test_roadmap_status.sh`(겹침 정보 단언 — R14 머지 뒤에만)

- [ ] **Step 1:** `python3 plugins/spec-distill/scripts/roadmap_write.py extract --roadmap docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md > $HOME/.claude/sdd-mirror/r9/table.md`. R9 행의 경로 예약 칸 끝에 ` · ` 로 이어 여섯을 더한다 — `plugins/spec-distill/references/docreview-profiles/design-doc.md` · `shared/docreview/scripts/docreview_state.py` · `shared/tests/test_docreview_profiles.sh` · `shared/tests/test_docreview_profile_schema.sh` · `plugins/spec-distill/tests/test_distortion_devices.sh` · `plugins/project-init/tests/test_post_tool_use.py`(칸 안 구분자는 표가 이미 쓰는 것을 따른다). `conducting.md` · `test_reviewing_brief_skill.sh` 는 더하지 않는다(설계 Files to Modify — 락 지도 · R14 예약).
- [ ] **Step 2:** `roadmap_write.py update --roadmap <로드맵> --brief docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.md --audit docs/superpowers/interview/2026-10-11-persistent-explore-pm-decompose-interview.audit.md --plan-table $HOME/.claude/sdd-mirror/r9/table.md --date <오늘> --change "R9 경로 예약에 설계의 예약 밖 파일 여섯 — 리뷰어 필수 섹션 누락(U9 · U10) · 브랜치 훅 테스트" --approval "리뷰어가 보게 한다 (권장)" --approval "승인을 막는다 (권장)"` (값은 `references/redecompose.md` §5 처럼 heredoc 파일로 넘긴다). rc 0 과 R9 블록 · 재분해 이력 한 항목만 바뀌었는지 `git diff` 로 본다.
- [ ] **Step 3:** `bash plugins/spec-distill/tests/test_roadmap_status.sh` — 겹침 정보(`OVERLAPS`)가 바뀌면 그 단언과 메시지의 기대 목록을 새 겹침(예: R9 ↔ R14 의 `docreview_state.py` · `README.md`, R9 ↔ R12 의 `design-doc.md`, R9 ↔ R13 의 `docreview_state.py`)으로 고친다 — 생성기 출력을 그대로 옮기고 R14 가 넣은 단언은 건드리지 않는다. `LOCKBAD` 가 비어 있는지 본다.
- [ ] **Step 4: 커밋** — `docs(roadmap): R9 경로 예약에 리뷰어 필수 섹션 · 브랜치 훅 테스트 파일`.

---

### Task 11: 규칙을 읽는 테스트 도출 실행 · 판 · CHANGELOG (AC10 · AC20)

**Files:**
- Modify: 네 플러그인 `.claude-plugin/plugin.json` · `CHANGELOG.md`

- [ ] **Step 1: 도출 목록(AC10).** `git grep -l -e 'CLAUDE\.md' -e 'devbrew-harness-philosophy' -e 'plugin-authoring' -e 'branch-strategy' -- 'plugins/*/tests/*' 'shared/tests/*' 'tools/*'` 에서 `test_*.sh` · `test_*.py` · `*.test.mjs` 만 고른다. `.sh` 는 `bash`, `.py` 는 `python3 -m unittest discover -s <폴더> -p <파일>`, `.mjs` 는 `node --test`. 목록 · 수 · 결과를 `$HOME/.claude/sdd-mirror/r9/plan1-ac10.md` 에 적는다(PR 본문에 옮긴다). Task 0 기준선 밖 RED 는 고친다.
- [ ] **Step 2: 판.** 머지 직전 기본 브랜치 판에서 patch 하나 — plugin-audit · project-init · quality-gates · spec-distill. CHANGELOG `## [<판>] — <날짜>`: 넷 공통 Changed 「사람에게 쓰는 글 — 끝에 할 일은 기본 하나, 여럿이거나 병렬이면 밝힌다(커밋 · PR 본문은 순서 밖)」. spec-distill 은 Changed 에 「설계문서 리뷰어가 필수 섹션 누락(`required_sections`)을 승인을 막는 지적으로 낸다」 · 「지휘자 권장은 라벨 밖, skill 의 문장 권장은 문장으로 옮긴다 — 옮김 대조가 두 어긋남을 잡는다」, Security 에 「리뷰어 규칙 조임 둘(프로필 · 옮김 대조 agent)」. quality-gates · plugin-audit 은 Changed 에 skill 자리의 할 일 문장 · persona 문장. project-init 은 사본만.
- [ ] **Step 3:** `bash shared/tests/test_changelog_integrity.sh` · `bash shared/tests/test_plugin_description_parity.sh` GREEN.
- [ ] **Step 4: 커밋** — `chore(release): R9 계획 1 판 · CHANGELOG`.

---

### Task 12: 합치기 · 전체 대조 · 마지막 리뷰 · 미룸 (AC19 · AC21 · AC1~AC10 확인)

AC19 확인: 리뷰가 과제마다 「테스트 먼저 · RED 확인 · 커밋 뒤 변이 · 양성 대조 · `/bin/bash` 3.2」 를 지켰는지 커밋 순서와 과제 기록으로 본다.

- [ ] **Step 1: 합치기.** R14 가 머지돼 있고 Task 6 이후 기본 브랜치가 더 나갔으면 `git merge --no-edit origin/main`. R14 가 먼저 머지된 뒤가 아니면 PR 을 만들지 않고 멈춰 보고한다. 합친 사본에서 Task 1~9 의 테스트를 다시 돌리고, R14 와 겹친 다섯 파일에서 R14 가 넣은 줄이 남았는지 `git diff origin/main -- <파일>` 로 확인해 PR 본문에 적는다(AC21).
- [ ] **Step 2:** 공유 잠금 아래 전체 스위트 → `$HOME/.claude/sdd-mirror/r9/plan1-after.txt`. 기준선에 없던 `FAILED` 줄은 이 계획의 몫이다 — 고치고 다시 돈다.
- [ ] **Step 3: 마지막 전체 리뷰.** 고른 실행 방식의 마지막 리뷰(가장 강한 모델 · 쓰기 권한 없는 리뷰어)에 설계문서 `## Acceptance Criteria` 절의 「계획 1」 AC1~AC10 과 「공통」 AC19~AC21 전문을 그대로 싣고, AC 마다 한 줄씩 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거>` 로 보고하게 한다. 함께 묻는다: 과제 사이 이음매(Task 1 의 `FACT` 문장과 Task 8 README 문장이 같은지 · 합치기 뒤 사본 동기화 · 브랜치 정규식과 CLAUDE.md :14 가 같은 접두를 말하는지), 계획이 쓴 테스트 코드(plan-mandated 라벨)의 이빨, 보안-민감 편집 둘. 보고를 git 이 추적하지 않는 `$HOME/.claude/sdd-mirror/r9/plan1-ac-report.md` 에 적는다.
- [ ] **Step 4: 미룸.** `미룸` · `빠짐` 판정과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 행씩 올린다. project-init 템플릿 `templates/github-flow/branch-strategy.md` :70 의 낡은 훅 문장(「`git checkout -b` · `git switch -c` 로 만든 이름만 확인한다」 — 지금 훅은 reflog 로 `worktree add -b` 도 잡는다)을 한 행으로 올린다(받는 곳은 지휘자가 정한다 — 「지휘자」로 적는다).
- [ ] **Step 5:** PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/7.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-23-rules-docs-cleanup-design.md $HOME/.claude/sdd-mirror/r9/plan1-ac-report.md --acs "AC1~AC10 · AC19~AC21"` 를 돌려 경고를 사용자에게 쉬운 말로 보인다.

---

## `### Deferred to plan` 답 (이 계획 몫)

| 항목 | 답 |
|---|---|
| relay-checker 의 두 어긋남 문장 글자 | 「문장 권장이 라벨 꼬리로 옮겨짐」 · 「지휘자가 만든 질문의 라벨에 (권장)」(Task 9) |
| §6 표 각 행의 정확한 문면 | Task 1 · 3 · 4 · 5 · 8 의 문면 — 뜻은 표대로 |
| 808c54ce · 20b8dc7d · 3d9ac787 | 계획 2 몫(설계 첫 커밋이 §3 · §4 에 반영) |
| 9f483f03 | 설계 첫 커밋이 반영 — project-init README 는 고치지 않고 CLAUDE.md :72 만(Task 4) |
| 공통 공시 문장 · `RETIRED_SECTIONS` · ledger 승인 클래스 | 계획 2 몫 |
