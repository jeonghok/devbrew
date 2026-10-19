# R10 계획 3 — 진입 이름 pm-interview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰 진입 skill 의 이름을 `spec-interview` 에서 `pm-interview` 로 바꾸고(별칭 없이 즉시 · spec-distill major bump), 이력 기록 밖에 옛 이름이 남지 않게 기계 락으로 막는다.

**Architecture:** 옛 이름을 막는 일은 새 grep 락을 만들지 않고 호출 표면 락(`shared/entry/check_invocation_surface.py`)의 축 I(살아 있는 표면의 옛 이름 + 새 이름 양성 짝)에 옛 이름 둘을 더해 맡긴다 — 5.0.0 개명 때 쓴 장치 그대로다. 락을 먼저 바꿔 RED 목록을 받고(그 목록이 작업 목록이다), skill 디렉토리를 `git mv` 한 뒤 살아 있는 참조를 모두 고쳐 GREEN 으로 만든다. 이력 기록(CHANGELOG 옛 항목 · `docs/superpowers/` · `docs/archive/`)은 축 I 가 보지 않고 이 계획도 고치지 않는다.

**Tech Stack:** Markdown skill · agent 정의, Python 3.9 표준 라이브러리, bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-10-19-interview-open-research-design.md` (§9 · §11 계획 3 · AC31 · AC32 · Verification Plan 끝 줄)

## Global Constraints

- **시작 시점.** 구현은 R10 계획 2(`feature/interview-end-gates`)가 기본 브랜치에 머지된 뒤 시작한다. 그때 `spec-interview` 참조를 가진 다른 열린 브랜치가 있으면 시작하지 않고 보고한다(설계 §11 「계획 3 은 `spec-interview` 참조를 가진 열린 브랜치가 모두 머지된 뒤」). 이 계획의 숫자(파일 73개 · 238줄)는 계획을 쓴 때의 기본 브랜치(c6c51fab) 기준이고, 작업 목록의 정본은 Task 0 의 재집계와 Task 1 의 RED 목록이다.
- 브랜치 `feature/pm-interview-rename`. 시작 때 기본 브랜치를 merge 한다(rebase 금지). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec(`git commit -- <경로…>`, 옮긴 파일은 옛 경로와 새 경로를 함께), `git stash` 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **호출 이름 변경은 별칭 없이 즉시 · spec-distill major bump**(CLAUDE.md 메타데이터 절 — 제3자 설치 확인 전까지의 예외). 옛 이름으로 부르는 자리 · 옛 이름을 읽는 호환 코드를 만들지 않는다.
- **kill switch 이름은 바꾸지 않는다**(`DEVBREW_SPEC_DISTILL_DISABLE` · `DEVBREW_SPEC_DISTILL_DISABLE_WEB` · `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT` 등). 이름에 `spec-interview` 가 든 kill switch 가 새로 보이면 그대로 두고 보고한다(설계 §9).
- **이력 기록은 고치지 않는다** — `plugins/*/CHANGELOG.md` 의 옛 항목, `docs/superpowers/{specs,plans,interview,roadmaps}/**`, `docs/archive/**`. 로드맵 문서는 지휘자 몫이고(설계 §11), R10 블록의 경로 예약에는 이미 `plugins/spec-distill/skills/pm-interview/` 가 있다.
- 판 번호는 머지 직전 지휘자가 정한다. 구현 중에는 기본 브랜치 spec-distill 판의 다음 major(계획 2 가 7.8.0 으로 머지했으면 `8.0.0`)를 임시로 쓰고, quality-gates 는 다음 patch 를 임시로 쓴다. CHANGELOG 머리는 plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- 셸 파일을 옮기거나 새로 만들면 `git ls-files -s <경로>` 로 `100755` 를 확인한다(실행 비트 없는 테스트는 qg 가 줍지 않는다). 인라인 python 은 `python3 -I`, 파일 읽기는 `encoding="utf-8"`. bash 3.2: `$var` 바로 뒤에 한글이 오면 `${var}`. `$( )` 안 heredoc 금지.
- 일괄 치환 도구가 심볼릭 링크를 보통 파일로 바꾸지 않게, 치환 대상 목록에서 mode `120000` 을 뺀다.
- 레포 전용 값(기본 브랜치 이름 · 경로 · 테스트 명령 · `gh`)을 박지 않는다 — 기본 브랜치는 `git symbolic-ref refs/remotes/origin/HEAD` 로 도출한다.
- 전체 스위트는 지휘자가 준 공유 스위트 잠금 아래서만 돌린다: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c '<스위트 명령>'`. 잠금을 못 잡으면(종료 코드 3 · 75) 잠금 없이 돌리지 않고 보고한다. 과제 안의 좁은 테스트는 잠금 없이 돌린다.
- 사람에게 보이는 새 문면(README · CHANGELOG)은 `shared/style/plain-language.md`.
- persona 파일(`agents/*.md`)은 이름 바꿈만 한다. 그 과제의 리뷰 요청과 PR 본문에 「persona 편집 — 보안 리뷰 대상(레포 규칙 「Persona 파일은 보안-민감 코드」), diff 는 이름 바꿈뿐」을 적는다.

## 설계와 다른 점 · 설계에 없던 결정

1. **옛 이름 락은 호출 표면 락 축 I 에 옛 이름 둘을 더하는 것이다.** 설계 Verification Plan 의 「`test_invocation_surface.sh` 와 개념 별칭 grep」을 한 장치로 합친다 — 축 I 는 이미 살아 있는 표면(`plugins/` · `shared/` · `docs/philosophy/` · 루트 `CLAUDE.md` · `README.md` · `docs/plugin-authoring.md`)을 git 이 아는 파일에서 도출해 읽고, CHANGELOG · `tests/fixtures/` · 자기 파일을 면제하며, 새 이름 양성 짝도 잰다. 새 grep 락을 따로 두면 같은 코퍼스를 두 번 정의하게 된다.
2. **seed 템플릿의 옛 값 `spec-distill:interview` 도 축 I 옛 이름이다** — 뒤에 이름 글자(`-` · 영숫자 · `_`)가 이어지는 꼴은 잡지 않는다.
3. **진입 테스트 파일 이름도 바꾼다** — `plugins/spec-distill/tests/test_spec_interview_entry.sh` → `test_pm_interview_entry.sh`(`git mv`). 이 파일 이름을 부르는 살아 있는 자리는 없다(계획 기록에만 있다).
4. **기록을 정답으로 읽는 테스트의 옛 경로는 리터럴을 쪼갠다.** 예: `plugins/spec-distill/tests/test_roadmap_status.sh` 실데이터 `OVERLAPS` 기대값은 로드맵의 머지된 에픽 경로 예약(`…/skills/spec-interview/references/finishing.md`)을 그대로 읽는다. 로드맵은 고치지 않으므로 기대값도 옛 경로가 정답이다 — `spec-""interview` 로 쪼개 쓴다(5.0.0 의 `conducting""-interview` 와 같은 관용구). 이 예외는 「그 테스트가 고치지 않는 기록을 읽는다」일 때만 쓴다.
5. **quality-gates 도 patch bump 한다.** `plugins/quality-gates/tests/lib/reconstruct-skill.sh` 의 주석 한 줄이 옛 이름을 예로 든다 — 축 I 가 잡으므로 고치고, 플러그인을 건드리는 PR 은 bump 한다.
6. **옛 seed 호환 자리는 만들지 않지만(설계 §9), 옛 `next_phase` 값 둘을 가진 seed 가 그대로 들어오는지는 잰다** — seed 는 `type: interview-seed` 로 알아보므로 지금 코드로 참이고, 누가 `next_phase` 로 분기하게 바꾸면 RED 가 나게 한다(Review Focus 3).
7. **템플릿의 `source:` 줄**(`interview-audit-template.md` · `interview-brief-template.md`)은 이름만 바꾸고 판 꼬리(`v0.57.0` · `v0.23.0`)는 그대로 둔다 — 그 값을 읽는 코드가 없고, 판을 고치는 일은 이 계획 범위가 아니다.

## Review Focus

1. **업그레이드한 사용자가 옛 이름 `/spec-distill:spec-interview` 를 친다.** 별칭이 없으니 플랫폼이 skill 을 못 찾는다(레포 규칙). 사람은 CHANGELOG 와 README 에서 새 이름을 바로 찾기를 기대한다. Task 3 의 CHANGELOG 절 락(옛 → 새 표 행 · major)과 README 양성 짝이 잠근다.
2. **request-framing 게이트가 내준 다음 세션 줄(①②)을 그대로 복사해 친다.** 그 줄이 새 이름이어야 다음 세션이 열린다. Task 2 에서 `test_seed_at_path_handoff.sh` 의 ①② 행 단언을 새 이름으로 바꾸고, 축 I 가 옛 이름의 재등장을 막는다.
3. **이 릴리스 전에 만든 seed(`next_phase: spec-distill:spec-interview` 또는 템플릿 옛 값 `spec-distill:interview`)를 새 이름으로 부른다.** 그대로 seed 로 받아 `NEW-SEED` 로 가야 한다. Task 2 의 `test_interview_state.py` 사례가 잠근다.
4. **인터뷰 도중 옮긴 reference(`finishing.md` · `saturation.md` 등)를 연다.** `Read ${CLAUDE_PLUGIN_ROOT}/skills/<이름>/references/…` 하나라도 옛 경로로 남으면 종료 절차를 못 읽어 인터뷰가 끝에서 멈춘다. 기존 `shared/tests/test_skill_reference_pointers.sh`(정방향 실재)와 축 I 가 잠근다 — Task 2 Step 5 에서 둘 다 돌린다.
5. **`DEVBREW_SPEC_DISTILL_DISABLE=1` 로 꺼 둔 사용자가 새 이름을 부른다.** 사전 검사 줄의 인자가 `spec-distill pm-interview` 여야 감시줄이 「disabled」를 내고 멈춘다. 축 C(사전 검사 줄의 정확한 모양 — `ENTRY_SKILLS` 에서 도출)와 `shared/tests/test_entry_preflight.sh` 가 잠근다.

---

### Task 0: 시작 조건 · 재집계 · 기준선

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r10-plan3/baseline.sh` · `$HOME/.claude/sdd-mirror/r10-plan3/recount.txt` (레포 밖)
- Modify: 이 계획 파일(재집계로 숫자 · 파일 목록이 바뀌면)

- [ ] **Step 1: 시작 조건을 확인한다**

Run (`refs/remotes/origin/HEAD` 가 없으면 먼저 `git remote set-head origin --auto`): `git fetch origin && D="$(git symbolic-ref --short refs/remotes/origin/HEAD)" && git log "$D" --merges --oneline --grep 'feature/interview-end-gates' | head -1 && git branch -r --no-merged "$D"`
Expected: 첫 줄에 계획 2 의 merge 커밋이 있다. `--no-merged` 목록의 브랜치(이 브랜치 제외)마다 `git diff --name-only "$D"...<브랜치>` 와 `git grep -l -E 'spec[-_ ]interview|spec-distill:interview' <브랜치> --` 를 보고, 옛 이름 참조를 더하거나 고치는 브랜치가 하나라도 있으면 멈추고 지휘 세션에 그 브랜치 이름을 보고한다.

- [ ] **Step 2: 기본 브랜치를 merge 한다**

Run: `git merge --no-edit "$D"`
Expected: 충돌 없음(이 브랜치에는 이 계획 파일만 있다).

- [ ] **Step 3: 개념 별칭으로 다시 센다** (숨김 디렉토리 포함 — `git grep` 은 추적 파일 전부를 본다)

Run:
```bash
A='spec[-_ ]interview|spec-distill:interview'
{ echo "== 내용"; git grep -c -E "$A" -- . ':!docs/superpowers' ':!docs/archive' ':!*/CHANGELOG.md'
  echo "== 경로"; git ls-files | grep -E 'spec[-_]interview'
  echo "== 링크"; git ls-files -s | awk '$1=="120000"{print $4}' | while read -r l; do t="$(readlink "$l")"; case "$t" in *spec-interview*) echo "$l -> $t";; esac; done
  echo "== 미추적 비무시"; git ls-files -o --exclude-standard | xargs grep -l -E "$A" /dev/null 2>/dev/null
} > "$HOME/.claude/sdd-mirror/r10-plan3/recount.txt"; cat "$HOME/.claude/sdd-mirror/r10-plan3/recount.txt"
```
Expected: 「내용」은 계획을 쓴 때의 73파일에 계획 2 가 더한 파일(예: `plugins/spec-distill/tests/test_end_gates.sh`)이 붙은 목록, 「경로」는 `skills/spec-interview/` 아래 파일들과 `tests/test_spec_interview_entry.sh`, 「링크」 · 「미추적 비무시」는 비어 있다. 비지 않으면 그 항목을 Task 2 의 범주에 넣고 이 계획에 적는다. 「내용」에서 테스트가 기록 파일(`docs/superpowers/**`)을 읽어 비교하는 자리를 따로 표시해 둔다(결정 4).

- [ ] **Step 4: 기준 스위트 스크립트를 쓴다** — R2a 계획 1(`docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md` Task 0 Step 1)의 `baseline.sh` 를 그대로 `$HOME/.claude/sdd-mirror/r10-plan3/baseline.sh` 에 쓴다(셸 테스트 · unittest 둘 다, 실패 줄 «이름» 집합을 남김).

- [ ] **Step 5: 기준을 잰다** (버릴 clone — `git clone --no-local` 로 merge 한 이 브랜치 HEAD 를 받아 그 루트에서, 공유 스위트 잠금 아래)

Run: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c 'cd <clone> && bash "$HOME/.claude/sdd-mirror/r10-plan3/baseline.sh" "$HOME/.claude/sdd-mirror/r10-plan3/before"'`
Expected: `before.tsv` · `before.names` 생성.

- [ ] **Step 6: 계획 고침이 있으면 커밋한다**

```bash
git commit -m 'docs(plan): R10 계획 3 — 계획 2 머지 뒤 재집계로 맞춤' -- docs/superpowers/plans/2026-10-20-r10-plan3-pm-interview-rename.md
```

---

### Task 1: 옛 이름 락 — 호출 표면 축 I · 진입 테스트 (AC31 · AC32 의 락 쪽)

**Files:**
- Modify: `shared/entry/check_invocation_surface.py` (`ENTRY_SKILLS` · `OLD_NAME_RE`)
- Modify: `shared/tests/test_invocation_surface.sh` (1부 합성 리포 `ENTRY` · README 줄 · 변이 c3 · 새 변이 · 3부 실제 변이)
- Move + Modify: `plugins/spec-distill/tests/test_spec_interview_entry.sh` → `plugins/spec-distill/tests/test_pm_interview_entry.sh`

**Interfaces:**
- Produces: `check_invocation_surface.py` 의 축 I 가 `spec-interview` · `spec-distill:interview` 를 「옛 이름 '<토큰>'」으로 내고, `ENTRY_SKILLS` 의 `("spec-distill", "pm-interview")` 가 없으면 「새 이름 진입 skill 'pm-interview' 가 자기 자리에 없다(양성 짝)」를 낸다. Task 2 · 3 은 `python3 shared/entry/check_invocation_surface.py` 의 `RED I …` 줄을 작업 목록으로 쓴다.

- [ ] **Step 1: 합성 리포 테스트를 새 이름으로 바꾸고 변이를 더한다** (`shared/tests/test_invocation_surface.sh` — 이 파일은 축 I 의 자기 파일이라 옛 이름을 그대로 써도 된다)

- `mk_repo` 의 `ENTRY` 에서 `("spec-distill", "spec-interview", False)` → `("spec-distill", "pm-interview", False)`, README 줄 `` `/spec-interview` 를 친다`` → `` `/pm-interview` 를 친다``.
- `variant c3` 의 바꿔치기 인자를 `"spec-distill pm-interview\`"` 로.
- 새 변이(1부, 기존 `i1`~`i_ol` 뒤):

```bash
variant i_si; put "$TMP/v-i_si/plugins/spec-distill/README.md" "/spec-distill:spec-interview 로 부른다"
expect_red "$TMP/v-i_si" I "축 I: 옛 진입 이름 spec-interview" "옛 이름 'spec-interview'"
variant i_sp; put "$TMP/v-i_sp/plugins/spec-distill/skills/request-framing/SKILL.md" 'Read ${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/finishing.md'
expect_red "$TMP/v-i_sp" I "축 I: 옛 skill 경로" "옛 이름 'spec-interview'"
variant i_np; put "$TMP/v-i_np/plugins/spec-distill/templates/s.md" "next_phase: spec-distill:interview"
expect_red "$TMP/v-i_np" I "축 I: seed 템플릿 옛 next_phase 값" "옛 이름 'spec-distill:interview'"
variant i_pm; put "$TMP/v-i_pm/plugins/spec-distill/scripts/q.py" "# /spec-distill:pm-interview · skills/pm-interview/ · docs/superpowers/interview/x.md · spec-distill:interview-x 는 옛 이름이 아니다"
expect_green "$TMP/v-i_pm" "축 I 음성 대조: 새 이름 · 인터뷰 산출물 폴더 · 이름 글자가 이어진 꼴은 걸리지 않는다"
variant i_fx; put "$TMP/v-i_fx/plugins/spec-distill/tests/fixtures/s.md" "next_phase: spec-distill:spec-interview"
expect_green "$TMP/v-i_fx" "축 I 면제 대조: tests/fixtures 의 옛 seed 값은 걸리지 않는다"
```

- 3부 실제 변이(`real g` 줄을 새 이름으로: `"다음은 /pm-interview 다"` · 사유 `"bare /pm-interview"`) 뒤에:

```bash
real si; put "$TMP/r-si/plugins/spec-distill/README.md" "/spec-distill:spec-interview"; expect_red "$TMP/r-si" I "실제 I 추가: 옛 진입 이름 재삽입" "옛 이름 'spec-interview'"
real pm; rm -rf "$TMP/r-pm/plugins/spec-distill/skills/pm-interview"; expect_red "$TMP/r-pm" I "실제 I 삭제: 새 이름 skill 디렉토리(양성 짝)" "'pm-interview'"
```

- [ ] **Step 2: 진입 테스트를 옮기고 새 단언을 쓴다**

Run: `git mv plugins/spec-distill/tests/test_spec_interview_entry.sh plugins/spec-distill/tests/test_pm_interview_entry.sh`

내용: 머리 주석 · `SKILL` 경로 · `^name: pm-interview$`(두 곳) · spec-review 재진입 참조 `grep -q 'pm-interview' "$REVIEW"` 로 바꾸고, 아래를 더한다(이 파일은 축 I 코퍼스라 옛 이름은 쪼개 쓴다):

```bash
[ ! -e "$SD/skills/spec-""interview" ] \
    && ok "AC31: 옛 skill 디렉토리가 없다(별칭 없음)" \
    || no "AC31: 옛 skill 디렉토리가 남아 있다"
grep -qx 'next_phase: spec-distill:pm-interview' "$SD/templates/interview-seed-template.md" \
    && ok "AC31: seed 템플릿의 next_phase 가 새 이름이다" \
    || no "AC31: seed 템플릿의 next_phase 가 새 이름이 아니다"
grep -qF '/spec-distill:pm-interview' "$SD/README.md" \
    && ok "AC31: README 가 새 완전명을 보인다(축 I 부재의 양성 짝)" \
    || no "AC31: README 에 새 완전명이 없다"
```

(CHANGELOG 절 단언은 Task 3 이 이 파일에 더한다.)

- [ ] **Step 3: 락을 바꾼다** — `shared/entry/check_invocation_surface.py`

- `ENTRY_SKILLS` 의 `("spec-distill", "spec-interview")` → `("spec-distill", "pm-interview")`.
- `OLD_NAME_RE` 에 대안 둘을 더한다: `spec-interview` · `spec-distill:interview(?![-A-Za-z0-9_])`.

- [ ] **Step 4: 합성 리포 부분이 맞고 실제 리포가 RED 인지 본다**

Run: `bash shared/tests/test_invocation_surface.sh 2>&1 | grep -E '^(ok|not ok|PASS|FAIL)|축 I|실제' | head -60` 그리고 `python3 shared/entry/check_invocation_surface.py > "$HOME/.claude/sdd-mirror/r10-plan3/red-i.txt"; echo rc=$?`
Expected: 1부의 새 변이 다섯이 모두 기대대로(RED 셋 · GREEN 둘), 양성 대조 GREEN(계획을 쓴 때 버린 사본에서 Task 1~3 의 고침을 모두 얹고 모의 실행 — 새 변이 다섯 · 실제 변이 둘 포함 82/82 통과). 2부(이 리포 무변이)는 RED 다 — `red-i.txt` 의 `RED I … 옛 이름 'spec-interview'` 줄들과 `RED I … 'pm-interview' 가 자기 자리에 없다(양성 짝)` 한 줄, 축 C · A 의 새 이름 줄이 Task 2 · 3 의 작업 목록이다. `rc=1`.

- [ ] **Step 5: 변이로 새 단언의 이빨을 본다** (커밋한 뒤, 이 브랜치의 `git clone --no-local` 사본에서 · `PYTHONDONTWRITEBYTECODE=1`)

1. 양성 대조: 사본에서 `OLD_NAME_RE` 를 그대로 두고 `test_invocation_surface.sh` 1부 → 새 RED 셋이 RED.
2. `OLD_NAME_RE` 에서 `spec-interview` 대안을 지운다 → `i_si` · `i_sp` 가 「축 I 태그 또는 사유 없음」으로 실패한다.
3. `spec-distill:interview` 대안의 뒤 조건 `(?![-A-Za-z0-9_])` 를 지운다 → `i_pm` 음성 대조가 실패한다.
4. 대안을 `spec-interview` 대신 `spec_interview` 로 바꾼다(표기 축) → `i_si` 실패.
Expected: 넷 다 위대로. 결과를 `$HOME/.claude/sdd-mirror/r10-plan3/mutations.md` 에 한 줄씩(무엇을 바꿨나 · 어느 단언이 RED).

- [ ] **Step 6: 커밋한다** (실제 리포 2부가 RED 인 채로 — Task 2 · 3 이 GREEN 으로 만든다. 커밋 메시지에 그 사실을 적는다)

```bash
git commit -m 'test(shared): 옛 진입 이름 spec-interview 를 호출 표면 락 축 I 에 — 실제 리포는 Task 2 · 3 까지 RED' -- shared/entry/check_invocation_surface.py shared/tests/test_invocation_surface.sh plugins/spec-distill/tests/test_spec_interview_entry.sh plugins/spec-distill/tests/test_pm_interview_entry.sh
```

---

### Task 2: 이름 옮기기 — skill 디렉토리 · 플러그인 표면 · 테스트 (AC31)

**Files:**
- Move: `plugins/spec-distill/skills/spec-interview/` → `plugins/spec-distill/skills/pm-interview/` (계획 2 머지 뒤 그 안의 파일 전부)
- Modify: Task 0 재집계 「내용」 목록 가운데 `docs/philosophy/` · `plugins/*/CHANGELOG.md` 를 뺀 전부 — 계획을 쓴 때 기준 범주:
  - skill · reference · agent · template · script: `skills/pm-interview/SKILL.md` · `skills/pm-interview/references/{finishing,seed-input,state-migration,steelman}.md` · `skills/{request-framing,reviewing-brief,spec-review}/SKILL.md` · `references/{epic-handoff,proceed-gate,trivia-escape}.md` · `agents/{blind-spot-prober,coverage-mapper,steelman-builder}.md`(persona — 이름만) · `templates/{interview-audit-template,interview-brief-template,interview-seed-audit-template,interview-seed-template}.md` · `scripts/{brief_body,check_brief,check_verbatim_coverage}.py`(주석 · docstring)
  - README: `plugins/spec-distill/README.md`(진입 줄 · 예시 · 흐름도 · Principles Instantiated · kill switch 절의 진입 skill 목록)
  - 테스트: `plugins/spec-distill/tests/` 49파일(경로 변수 · `# guards:` 줄 · 인라인 seed 의 `next_phase` · 단언 리터럴 · 주석) · `plugins/spec-distill/tests/fixtures/seed-*.md` 다섯(`next_phase`) · `shared/tests/{test_docreview_advice_procedure,test_docreview_procedure_paths,test_inline_python_isolated,test_skill_reference_pointers}.sh` · `plugins/quality-gates/tests/lib/reconstruct-skill.sh`(주석)
- Test: `plugins/spec-distill/tests/test_interview_state.py` (옛 seed 값 사례)

**Interfaces:**
- Consumes: Task 1 의 `red-i.txt`(작업 목록) · `ENTRY_SKILLS` 의 새 이름.
- Produces: `/spec-distill:pm-interview` 로 풀리는 진입 skill · `${CLAUDE_PLUGIN_ROOT}/skills/pm-interview/references/<파일>` 경로 · seed 템플릿 `next_phase: spec-distill:pm-interview`. Task 3 은 남은 RED 가 `docs/philosophy/` 뿐이라고 기대한다.

- [ ] **Step 1: 옛 seed 값 사례를 쓴다** — `plugins/spec-distill/tests/test_interview_state.py` 의 `EntryTest` 에

```python
def test_seed_with_old_next_phase_values_still_enters(self):
    for old in ("spec-distill:spec-" "interview", "spec-distill:" "interview"):
        with self.subTest(old=old):
            seed = self.put("2026-10-15-t-interview.md", "interview-seed", "next_phase: %s\n" % old)
            rc, out, _ = run("entry", "--arg", str(seed), "--session", SID, cwd=self.tmp)
            self.assertEqual((rc, last(out)), (0, "interview-state: NEW-SEED t-brief seed=docs/superpowers/interview/2026-10-15-t-interview.md"))
```

(옛 값은 인접 문자열로 쪼개 축 I 에 걸리지 않게 쓴다.)

- [ ] **Step 2: 사례가 지금 통과하는지 본다** (호환 코드 없이 참이어야 하는 사실이다)

Run: `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_interview_state.py -k old_next_phase -v`
Expected: PASS. 이빨은 Task 4 의 변이가 본다.

- [ ] **Step 3: 디렉토리를 옮기고 살아 있는 참조를 바꾼다**

Run:
```bash
git mv plugins/spec-distill/skills/spec-interview plugins/spec-distill/skills/pm-interview
L="$HOME/.claude/sdd-mirror/r10-plan3/rename-list.txt"
git grep -l -E 'spec-interview|spec-distill:interview' -- plugins shared ':!*/CHANGELOG.md' ':!shared/entry/check_invocation_surface.py' ':!shared/tests/test_invocation_surface.sh' > "$L"
python3 -I - "$L" <<'PY'
import os, re, sys
changed = 0
for p in open(sys.argv[1], encoding="utf-8").read().splitlines():
    if os.path.islink(p):
        print("링크라 건너뜀:", p); continue
    with open(p, encoding="utf-8", newline="") as fh:
        t = fh.read()
    n = re.sub(r"spec-distill:interview(?![-A-Za-z0-9_])", "spec-distill:pm-interview", t).replace("spec-interview", "pm-interview")
    if n != t:
        with open(p, "w", encoding="utf-8", newline="") as fh:
            fh.write(n)
        changed += 1
print("바꾼 파일", changed)
PY
python3 shared/entry/check_invocation_surface.py --print-head spec-distill pm-interview
```
(`xargs -I{}` 는 macOS 에서 「command line cannot be assembled, too long」으로 아무것도 바꾸지 않고 지나간다 — 모의 실행에서 확인. 그래서 파이썬 한 번으로 바꾸고 `newline=""` 로 줄 끝을 그대로 둔다.)

Expected: 「바꾼 파일」이 목록 줄 수와 같다(계획을 쓴 때 기준 70 — 모의 실행). 마지막 명령이 낸 사전 검사 줄 · `allowed-tools` 줄과 `skills/pm-interview/SKILL.md` 머리가 글자 그대로 같다(다르면 그 출력으로 맞춘다). 치환은 `tests/fixtures/` 의 seed 다섯도 바꾼다(픽스처는 템플릿 사본이다 — 설계 §9). 락의 자기 파일 둘(`check_invocation_surface.py` · `test_invocation_surface.sh`)은 옛 이름을 일부러 담으므로 치환에서 뺀다 — 이것을 빼지 않으면 `OLD_NAME_RE` 의 옛 이름이 새 이름으로 바뀌어 락이 거꾸로 선다.

- [ ] **Step 4: 기록을 읽는 테스트를 되돌린다** (결정 4) — 치환 뒤 `test_roadmap_status.sh` 의 실데이터 `OVERLAPS` 기대값 속 경로를 옛 경로로 되돌리되 `spec-""interview` 로 쪼갠다. Task 0 Step 3 에서 표시한 다른 「기록 대조」 자리도 같게 한다. 그 밖의 자리는 되돌리지 않는다.

- [ ] **Step 5: 좁은 테스트를 돌린다**

Run:
```bash
for t in plugins/spec-distill/tests/test_pm_interview_entry.sh plugins/spec-distill/tests/test_seed_at_path_handoff.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_saturation_reference.sh plugins/spec-distill/tests/test_next_session_command.sh plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_roadmap_status.sh plugins/spec-distill/tests/test_seed_inline_blob.sh plugins/spec-distill/tests/test_seed_provenance.sh shared/tests/test_skill_reference_pointers.sh shared/tests/test_entry_preflight.sh plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh; do printf '%s ' "$t"; bash "$t" 2>&1 | tail -1; done
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_interview_state.py plugins/spec-distill/tests/test_finishing_block_scope.py plugins/spec-distill/tests/test_r2_bypass_residue.py plugins/spec-distill/tests/test_seed_grammar_crosscheck.py
python3 shared/entry/check_invocation_surface.py
```
Expected: 셸 테스트 모두 0 실패, unittest OK. 호출 표면 락의 남은 RED 는 `docs/philosophy/devbrew-harness-philosophy.md` 의 축 I 줄 둘뿐이다. (계획을 쓴 때 기본 브랜치의 버린 사본에서 Step 3 · 4 를 모의 실행한 결과가 이와 같았다 — Step 4 전에는 `test_roadmap_status.sh` 의 실데이터 겹침 단언 하나만 실패했다.)

- [ ] **Step 6: diff 를 범주별로 훑는다**

Run: `git diff --cached --stat -M; git diff -M -- plugins/spec-distill/agents | grep '^[-+][^-+]'`
Expected: 옮김은 rename 으로 잡힌다(내용 유사도 높음). persona 셋의 바뀐 줄은 `spec-interview` → `pm-interview` 뿐이다. 다른 낱말이 바뀐 줄이 있으면 되돌린다.

- [ ] **Step 7: 커밋한다**

```bash
git add -A -- plugins/spec-distill/skills plugins/spec-distill/tests plugins/spec-distill/references plugins/spec-distill/agents plugins/spec-distill/templates plugins/spec-distill/scripts plugins/spec-distill/README.md shared/tests plugins/quality-gates/tests/lib/reconstruct-skill.sh
git commit -m 'feat(spec-distill)!: 인터뷰 진입 이름을 pm-interview 로 — 별칭 없이' -- plugins/spec-distill/skills plugins/spec-distill/tests plugins/spec-distill/references plugins/spec-distill/agents plugins/spec-distill/templates plugins/spec-distill/scripts plugins/spec-distill/README.md shared/tests plugins/quality-gates/tests/lib/reconstruct-skill.sh
```
(`git add -A` 는 위 경로로 한정한다 — 옮긴 파일의 삭제 쪽까지 잡으려는 것이다.)

---

### Task 3: 문서 · 버전 — 철학 문서 · CHANGELOG · major bump (AC31 · AC32 의 문서 쪽)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md` (코드 지도의 경로 둘)
- Modify: `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_pm_interview_entry.sh` (CHANGELOG 절 단언)

**Interfaces:**
- Consumes: Task 2 뒤 남은 축 I 줄(철학 문서뿐).

- [ ] **Step 1: CHANGELOG 절 단언을 쓴다** — `test_pm_interview_entry.sh` 끝(`finish` 앞)에

```bash
python3 -I - "$SD/CHANGELOG.md" <<'PY' && ok "AC31: CHANGELOG 의 major 절이 옛 → 새 진입 이름 표 행을 Removed 에 싣는다" || no "AC31: CHANGELOG 에 옛 → 새 진입 이름의 major Removed 행이 없다"
import re, sys
t = open(sys.argv[1], encoding="utf-8").read()
secs = [s for s in re.split(r"(?m)^(?=## \[)", t) if s.startswith("## [")]
heads = [re.match(r"## \[(\d+)\.(\d+)\.(\d+)\]", s) for s in secs]
old = "/spec-distill:spec-" + "interview"
row = re.compile(r"(?m)^\|\s*`" + re.escape(old) + r"`\s*\|\s*`/spec-distill:pm-interview`\s*\|")
hit = [i for i, s in enumerate(secs) if "### Removed" in s and row.search(s.split("### Removed", 1)[1])]
assert len(hit) == 1, hit
m, prev = heads[hit[0]], heads[hit[0] + 1]
assert (m.group(2), m.group(3)) == ("0", "0"), m.group(0)
assert int(m.group(1)) == int(prev.group(1)) + 1, (m.group(0), prev.group(0))
PY
```

- [ ] **Step 2: 단언이 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_pm_interview_entry.sh 2>&1 | tail -3`
Expected: FAIL — 「CHANGELOG 에 옛 → 새 진입 이름의 major Removed 행이 없다」.

- [ ] **Step 3: 문서와 버전을 쓴다**

- 철학 문서: `plugins/spec-distill/skills/spec-interview/SKILL.md` 두 곳 → `plugins/spec-distill/skills/pm-interview/SKILL.md`.
- spec-distill `plugin.json` 을 다음 major(임시 — Global Constraints), CHANGELOG 맨 위에 `## [<그 판>] — <날짜>`: 첫 줄 「major 인 이유 — 인터뷰를 부르는 이름이 바뀌었다. 옛 이름은 별칭 없이 사라졌다.」, `### Removed` 에 `| 옛 이름 | 새 이름 |` 표 한 행 `` | `/spec-distill:spec-interview` | `/spec-distill:pm-interview` | ``, `### Changed` 에 셋 — seed 템플릿 `next_phase` 가 `spec-distill:pm-interview` 이고 옛 값(`spec-distill:spec-interview` · `spec-distill:interview`)을 가진 seed 도 그대로 받는다(seed 는 `type: interview-seed` 로 알아본다) · 꺼 두는 스위치 이름은 그대로다 · 인터뷰 산출물 폴더(`docs/superpowers/interview/`)와 상태 파일은 그대로다. 그리고 한 줄 — 설정(권한 목록 등)이나 자기 스크립트에 옛 이름을 적어 둔 사용자는 새 이름으로 바꿔야 한다.
- quality-gates `plugin.json` 다음 patch, CHANGELOG `### Changed` 한 줄 — 테스트 도우미 주석의 skill 이름을 spec-distill 의 새 이름으로.

- [ ] **Step 4: 통과를 본다**

Run: `bash plugins/spec-distill/tests/test_pm_interview_entry.sh 2>&1 | tail -1 && bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1 && bash plugins/spec-distill/tests/test_readme_sync.sh 2>&1 | tail -1 && python3 shared/entry/check_invocation_surface.py; echo rc=$?`
Expected: 셋 다 0 실패, 호출 표면 락 `rc=0`.

- [ ] **Step 5: 커밋한다**

```bash
git commit -m 'docs(spec-distill): pm-interview 개명 — CHANGELOG major · 철학 문서 경로 · qg patch' -- docs/philosophy/devbrew-harness-philosophy.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/tests/test_pm_interview_entry.sh
```

---

### Task 4: 다시 세기 · 변이 · 스위트 대조 · 끝에서 끝 (AC32 마감 · AC31 확인)

**Files:**
- 없음(확인만). 결과는 PR 본문과 `$HOME/.claude/sdd-mirror/r10-plan3/` 에.

- [ ] **Step 1: 개념 별칭으로 다시 센다** — Task 0 Step 3 명령을 `recount-after.txt` 로.

Expected: 「내용」은 락의 자기 파일 둘(`shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh` — 옛 이름을 일부러 담는다)뿐이다(결정 4 의 쪼갠 리터럴 · 테스트의 쪼갠 옛 값은 정규식에 걸리지 않으므로 목록에 없다). 「경로」 · 「링크」 · 「미추적 비무시」 0건. `git ls-files | grep -c 'skills/pm-interview/'` 가 Task 0 의 옛 경로 수와 같다.

- [ ] **Step 2: 변이로 이빨을 본다** (커밋한 HEAD 의 `git clone --no-local` 사본 · `PYTHONDONTWRITEBYTECODE=1` · 매 변이 뒤 `git checkout HEAD -- .` 과 `git diff HEAD --quiet` 로 복원 확인)

1. 양성 대조: 무변이 사본에서 `test_invocation_surface.sh` 2부 GREEN · `test_pm_interview_entry.sh` 0 실패.
2. `skills/pm-interview/SKILL.md` 의 `name:` 을 옛 이름으로 → 축 A · I RED, `test_pm_interview_entry.sh` 의 name 단언 RED.
3. seed 템플릿 `next_phase` 를 옛 값으로 → 축 I RED(「옛 이름 'spec-distill:interview'」) · 템플릿 단언 RED.
4. CHANGELOG Removed 행을 지운다 → CHANGELOG 절 단언 RED. 그 절의 판을 minor 꼴(`x.1.0`)로 → 같은 단언 RED.
5. README 의 `/spec-distill:pm-interview` 를 모두 지운다 → README 양성 짝 RED.
6. `scripts/interview_state.py` 의 seed 판별을 `next_phase == "spec-distill:pm-interview"` 까지 요구하게 → `test_seed_with_old_next_phase_values_still_enters` RED.
7. `skills/pm-interview/SKILL.md` 의 `Read ${CLAUDE_PLUGIN_ROOT}/skills/pm-interview/references/finishing.md` 를 옛 경로로 → 축 I RED · `test_skill_reference_pointers.sh` RED.
Expected: 모두 위대로. Task 1 Step 5 의 기록과 합쳐 PR 본문 「변이 확인」 표로. 생존한 변이가 있으면 그 락을 고친 뒤에만 PR 을 연다.

- [ ] **Step 3: 스위트를 기준선과 대조한다** (버릴 clone · 공유 스위트 잠금 아래)

Run: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c 'cd <clone> && bash "$HOME/.claude/sdd-mirror/r10-plan3/baseline.sh" "$HOME/.claude/sdd-mirror/r10-plan3/after"'` 그다음 `comm -13 <(sort -u "$HOME/.claude/sdd-mirror/r10-plan3/before.names") <(sort -u "$HOME/.claude/sdd-mirror/r10-plan3/after.names")`
Expected: 새 실패 이름 0. 옮긴 테스트(`test_spec_interview_entry` → `test_pm_interview_entry`)는 이름이 바뀐 것이지 새 실패가 아니다 — 새 이름이 실패 목록에 없으면 된다.

- [ ] **Step 4: 배포 경로를 잰다**

Run: `bash shared/tests/test_invocation_surface.sh 2>&1 | grep -E 'manifest|SKIPPED'` (4부 — `claude plugin validate --strict`). CLI 가 있으면 격리 설치(`CLAUDE_CONFIG_DIR=<빈 임시 폴더>` — 쓰기 전에 그 폴더가 비었는지 먼저 보인다)로 이 브랜치 clone 을 마켓플레이스로 더해 spec-distill 을 설치하고, 캐시 사본의 `skills/` 아래에 `pm-interview` 가 있고 `spec-interview` 가 없는지 본다.
Expected: validate 통과, 캐시 사본에 새 디렉토리만. CLI 가 없거나 설치가 막히면 「재지 않았다」와 이유를 PR 본문에 적는다(조용히 건너뛰지 않는다).

- [ ] **Step 5: 지휘 세션이 걸을 것을 PR 본문에 적는다** — 새 세션에서 `/spec-distill:pm-interview` 가 skill 목록에 보이고 `/spec-distill:spec-interview` 가 없다 · `/spec-distill:request-framing` 끝 게이트 ①② 줄이 새 이름이다 · `DEVBREW_SPEC_DISTILL_DISABLE=1` 에서 새 이름이 멈춘다. 사람 · 모델이 필요한 자리라 지휘 세션이 걷는다.

- [ ] **Step 6: push 한다**

```bash
git push -u origin feature/pm-interview-rename
```
PR 본문(한국어): 변이 확인 표 · 재집계 전후 · 스위트 대조 · 배포 경로 측정 · persona 편집 문장(Global Constraints 끝 줄) · 이력 기록을 고치지 않은 범위 · 임시 판 번호(지휘자가 머지 직전 확정).
