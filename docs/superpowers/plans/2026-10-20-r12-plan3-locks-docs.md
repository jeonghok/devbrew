# R12 계획 3 — 락 · 판정기 · 문서 · project-init · 지휘 절차 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공유 락 · 판정기의 남은 빈틈(배선 락 줄 번호 핀 · plugin-audit kill switch · copy-of-contract 소비 도출 · 같은 이름 블록 · 호출 표면)을 이빨과 양의 짝을 갖춰 닫고, 철학 P3 문장 · 설계문서 프로필의 대안 비교 한 줄 · project-init 공시 · 지휘 절차의 옮김 규칙을 고친다.

**Architecture:** 락마다 지금 트리에서 먼저 돌려 걸리는 자리를 같은 과제에서 고치고, 넓힐 때마다 음성 대조를 둔다. 배선 락은 면제 키에서 줄 번호를 빼고 둘러싼 `for` 의 글자로 같은 정체를 가른다. kill switch 판정은 이미 읽는 플러그인 자기 이름(`own_name`)에 묶는다. 문서 쪽은 한 줄 · 한 문단 고침이다.

**Tech Stack:** Python 3.9 표준 라이브러리(`ast`), bash 3.2 호환 셸 테스트, `python3 -m unittest`, Markdown.

**Spec:** `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` (§8 · §9 의 철학 P3 · 설계 프로필 · project-init · 지휘 절차 교훈 · AC25~AC33 · AC34)

**구현 브랜치:** `feature/review-lock-leftovers` — 시작할 때 기본 브랜치에서 새로 만든다(Task 0). 이 계획 파일과 설계문서는 `feature/review-engine-leftovers` 에 있다 — Task 0 이 두 파일을 그 브랜치에서 가져와 첫 커밋으로 싣는다. 계획 1 · 2 와 병렬로 간다. conducting.md 걸음 4 ③ 은 계획 1, 로드맵 R1 · R3 · R5 경로 예약은 지휘자 로드맵 PR(#240 으로 이미 머지 — Task 9 가 확인만 한다)이다.

## Global Constraints

- 기본 브랜치 이름은 `git symbolic-ref --short refs/remotes/origin/HEAD` 로 도출한다. merge 만(rebase 금지) · HEAD 를 뒤로 옮기지 않는다 · 커밋은 pathspec · `git stash` 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 구현 커밋마다 `Spec: docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` 트레일러, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 이 계획은 **spec-distill(설계 프로필 · conductor-dispatch) · plugin-audit · project-init** 를 올린다. 호출 표면 락(Task 5)이 다른 플러그인 문서를 고치게 하면 그 플러그인도 올린다. 판 번호는 머지 직전 지휘자가 정한다 — 구현 중에는 기본 브랜치 판의 다음 minor. CHANGELOG 머리는 plugin.json 과 같게.
- **경로 겹침.** `tools/adjudication/check_wiring.py` 를 계획 1(흡수 분기 · `EXEMPT` 줄) · 계획 2(합성기 줄)도 고친다 — 뒤에 머지하는 쪽이 기본 브랜치를 merge 하고, 그때 `EXEMPT` 에 줄 번호가 되살아나지 않게 이 계획의 키 꼴로 맞춘다. `shared/tests/fixtures/docreview/cases.sh` 는 계획 1 도 케이스를 더한다 — 두 쪽 케이스를 모두 남긴다. 설계문서 `## 미룸` 표도 같다.
- **persona · 프로필 편집.** `references/docreview-profiles/design-doc.md` 의 한 줄은 리뷰어 프로필 강화다 — 보안 리뷰 대상은 아니지만 그 과제의 리뷰 요청 · 커밋 본문 · PR 본문에 「리뷰어 프로필 편집(강화 — 규칙 더하기, 기준 완화 없음)」 을 밝힌다.
- **셸 · 파이썬 · 변이 · 스위트 잠금 · plan-mandated 라벨 · 사람에게 쓰는 글** — 계획 1 Global Constraints 와 같다(macOS bash 3.2 · `${var}` · 100755 · `encoding="utf-8"` · `python3 -I` · 변이 전 커밋 · `git clone --no-local` · `PYTHONDONTWRITEBYTECODE=1` · 복원 확인 · 양성 대조 · 음의 락엔 양의 짝 · 공유 스위트 잠금 · 과제 경계마다 바꾼 파일을 코퍼스로 읽는 락까지).
- 레포 전용 값을 박지 않는다. 모델이 읽는 새 문면에 출처 · 정당화를 쓰지 않는다.

## 설계와 다른 점 · 설계에 없던 결정

1. **배선 락 정체의 꼴(§8 의 `### Deferred to plan` — 확인됨).** `scan()` 은 행마다 `_enclosing_loop` 가 찾은 `for` 노드를 이미 갖고 있다 — 행에 `"loop": "for <ast.unparse(target)> in <ast.unparse(iter)>"` 를 더하고 정체를 `"<kind> in <func> @ <guard> ~ <loop>"` 로 한다. 키는 `(경로, 정체)` 2-튜플. 정체가 같은 행이 둘 이상이면 `duplicate_identity` 로 RED(면제 여부와 무관 — 키가 자리를 가르지 못한다는 사실 자체가 결함이다).
2. **kill switch 판정의 받는 꼴(§8):** `DEVBREW_<OWN>_DISABLE`(뒤에 `[A-Z0-9_]` 가 이어지지 않는 것 — `…_DISABLE_WEB` 같은 하위 스위치는 아니다) · `DEVBREW_SKIP_HOOKS` · 공유 모듈 호출 `kill_switch_active("<own_name>"`. `<OWN>` 은 `own_name.upper().replace("-", "_")`. 지금 레포에서 훅이 있는 플러그인은 project-init 하나다.
3. **copy-of-contract 소비 도출(§8):** 산문 도출에서 「파일이 속한 플러그인과 다른 플러그인의 전체 경로(`plugins/<다른>/(scripts|agents|references)/<이름>`)로 나타나는 매치」를 줄 단위로 뺀다 — 이미 있는 `shared/…` 줄 단위 제외와 같은 꼴. 양성 짝은 `doc-critic.md`(`shared/docreview/agents/doc-critic.md` 정본 — 배포 플러그인이 도출되는가).
4. **철학 P3 고침에 같은 개념 줄 쓸기를 더한다** — 「자리 넷」 을 말하는 살아 있는 문면(`plugins/spec-distill/tests/test_rereview_cap_consistency.sh:24` 주석 등)도 고친다. CHANGELOG 의 옛 항목은 이력이라 그대로 둔다.
5. **AC30 의 락 자리:** `shared/tests/test_docreview_profiles.sh` 에 음(「자리 넷」 없음) · 양(「자리 셋(design doc · brief · seed)」 과 `generic` 의 쓰임) 단언 둘을 더한다 — 엔진 자리 수를 말하는 사실이라 엔진 프로필 테스트 곁에 둔다.
6. **AC33 은 확인만 한다** — 로드맵 PR #240(「R12 계획 셋의 브랜치 · 경로 예약 등록 · R1 · R3 · R5 경로 예약을 pm-interview 이름으로」)이 기본 브랜치에 있다.

## Review Focus

1. **면제한 분기 위에 주석 한 줄을 더한다(평범한 고침).** 배선 락이 재앵커를 요구하지 않고 GREEN 이어야 한다 — 그러나 가드 글자를 바꾸면 지금처럼 RED. Task 1 의 `case_exempt_survives_insertion` · `case_exempt_guard_change_red` 가 잠근다.
2. **훅 스크립트가 다른 플러그인의 스위치(`DEVBREW_QUALITY_GATES_DISABLE`)만 읽는다.** plugin-audit 은 gap 으로 내야 한다 — 그 플러그인을 꺼도 이 훅은 꺼지지 않는다. Task 2 의 `test_foreign_switch_only_is_gap` 이 잠근다.
3. **문서에 `**/qg**` · `[/qg](…)` · 표 칸 `|/qg|` 로 옛 호출을 적는다.** 호출 표면 락이 잡아야 하고, ` /qg.md` 같은 파일 이름은 통과해야 한다. Task 5 의 프로브 짝이 잠근다.
4. **project-init 을 다시 돌려 S4 「옮기기」를 고르는데 AGENTS.md 에 `## Project Charter` 가 이미 있다.** CLAUDE.md 의 같은 절이 조용히 사라지지 않고 advisory · 끝 보고에 그 사실이 보여야 한다. Task 7 의 문면 단언이 잠근다.
5. **지휘자가 선택지 설명을 번역해 옮기며 문장 하나를 뺀다.** 지휘 절차가 그것을 금하고, 미리 받은 답을 실은 dispatch 의 글이 relay 파일에 남아 대조할 수 있어야 한다. Task 8 의 문면 단언이 잠근다.

---

### Task 0: 시작 · 설계문서 싣기 · 기준선

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r12-plan3/baseline.sh` (레포 밖)
- Create(이 브랜치): `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` · `docs/superpowers/plans/2026-10-20-r12-plan3-locks-docs.md`

- [ ] **Step 1: 브랜치를 만들고 두 파일을 싣는다**

Run: `git fetch origin && D="$(git symbolic-ref --short refs/remotes/origin/HEAD)" && git switch -c feature/review-lock-leftovers "$D" && git checkout origin/feature/review-engine-leftovers -- docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md docs/superpowers/plans/2026-10-20-r12-plan3-locks-docs.md && git commit -m 'docs(plan): R12 계획 3 — 설계문서 · 계획 싣기' -- docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md docs/superpowers/plans/2026-10-20-r12-plan3-locks-docs.md`

- [ ] **Step 2: 계획 1 · 2 의 머지 상태를 본다** — `git log --oneline "$D" --merges --grep 'feature/review-engine-leftovers'` · `--grep 'feature/qg-verdict-state'`. 머지된 쪽이 있으면 `EXEMPT` 의 `docreview_route.py` · `synthesize_findings.py` 자리가 이미 옮겨져 있다 — Task 1 은 그 트리 기준으로 다시 키를 만든다.

- [ ] **Step 3: 기준 스위트** — R2a 계획 1 Task 0 Step 1 의 `baseline.sh` 를 `$HOME/.claude/sdd-mirror/r12-plan3/baseline.sh` 에 쓰고 버릴 clone 에서 공유 스위트 잠금 아래 `before` 를 잰다.

---

### Task 1: 배선 락 면제 키에서 줄 번호를 뺀다 (AC25)

**Files:**
- Modify: `tools/adjudication/check_wiring.py`(`scan` · `exempt_key` · `stale_exempt` · `EXEMPT` 전부 · 재앵커 함정 문단 · 줄번호 주석)
- Test: `shared/tests/test_adjudication_wiring.sh`

**Interfaces:**
- Produces: `scan()` 행에 `"loop": str`. `exempt_key(rel, row) -> tuple[str, str]` = `(rel, "%s in %s @ %s ~ %s" % (kind, func, guard, loop))`. `duplicate_identities(rows, repo) -> list` — 같은 `(경로, 정체)` 가 둘 이상인 키.

- [ ] **Step 1: 실패하는 단언을 쓴다** — `test_adjudication_wiring.sh` 에:
  - `case_exempt_survives_insertion` — 사본 레포(`mktemp -d` 에 `git clone --no-local`)의 `docreview_route.py` 맨 위 import 다음에 주석 줄 열 개를 넣고 스캔 → `exempt_stale=0` · `unwired=0`.
  - `case_exempt_guard_change_red` — 면제 하나의 가드 글자(예: `if not live` → `if not live or False`)를 바꾸면 `exempt_stale` 에 그 키 · 같은 행이 `unwired`(지금 동작 유지).
  - `case_duplicate_identity_red` — 사본의 한 함수에 같은 `for` 글자 · 같은 가드의 버리는 분기를 하나 더 만들면 `duplicate_identity` 로 RED.
  - 정적 단언: `EXEMPT` 키가 모두 2-튜플이고 둘째 성분에 ` ~ for ` 가 든다 · escalated · reraise 두 키의 정체가 서로 다르다.

- [ ] **Step 2: 돌려 실패를 본다** — 첫 케이스 RED(지금은 줄이 밀리면 stale).

- [ ] **Step 3: 구현한다** — Interfaces 대로. `EXEMPT` 키를 스캔에서 다시 만든다(`python3 -I -c` 로 지금 행의 정체를 찍어 옮긴다 — 사유 상수는 그대로). escalated · reraise 두 자리는 이제 `loop` 글자로 갈리는지 눈으로 확인한다(`esc` 쪽 · `reraise` 쪽 순회 대상). 줄 번호 주석 · 「재앵커할 때 기계가 못 잡는 함정」 문단은 새 규칙에 맞게 두세 줄로 줄인다 — 같은 정체는 `duplicate_identity` 가 막는다는 사실만. `stale_exempt` 는 집합 대조 그대로.

- [ ] **Step 4: 돌려 통과를 본다** — `bash shared/tests/test_adjudication_wiring.sh && bash shared/tests/test_adjudication_consumed.sh && bash shared/tests/test_dispatch_disposition.sh`.

- [ ] **Step 5: 변이** — `exempt_key` 에서 `loop` 를 빼면 `case_duplicate_identity_red` 의 정적 단언(두 키가 다르다)이 RED · `duplicate_identities` 가 늘 빈 목록을 내게 하면 `case_duplicate_identity_red` RED.

- [ ] **Step 6: 커밋** — `fix(adjudication): 배선 락 면제 키에서 줄 번호를 빼고 둘러싼 for 로 정체를 가른다`

---

### Task 2: plugin-audit kill switch 를 자기 이름에 묶는다 (AC26)

**Files:**
- Modify: `plugins/plugin-audit/scripts/check-shape-completeness.py`(`_hooks_killswitch_present(pd, own_name)` · `_has_killswitch(text, own_name)` · `_KILLSWITCH_RE` 를 함수로)
- Test: `plugins/plugin-audit/tests/test_check_shape_completeness.py`

**Interfaces:**
- Produces: `_has_killswitch(text: str, own_name: str) -> bool` — 결정 2 의 세 꼴 중 하나.

- [ ] **Step 1: 지금 판정을 잰다** — `for p in plugins/*/; do python3 plugins/plugin-audit/scripts/check-shape-completeness.py "$p"; done > "$HOME/.claude/sdd-mirror/r12-plan3/shape-before.txt"`.

- [ ] **Step 2: 실패하는 테스트를 쓴다** — 임시 플러그인 폴더(`plugin.json` 의 `name: demo-x`, `hooks/hooks.json` 이 스크립트 하나를 등록)로: `test_foreign_switch_only_is_gap`(스크립트에 `DEVBREW_QUALITY_GATES_DISABLE` 만 → `hooks_killswitch` gap) · `test_sub_switch_only_is_gap`(`DEVBREW_DEMO_X_DISABLE_WEB` 만 → gap) · `test_own_switch_ok`(`DEVBREW_DEMO_X_DISABLE`) · `test_skip_hooks_ok`(`DEVBREW_SKIP_HOOKS`) · `test_shared_module_ok`(`kill_switch_active("demo-x", "h", "PostToolUse")`) · `test_shared_module_other_name_is_gap`(`kill_switch_active("other", …)`).

- [ ] **Step 3: 돌려 실패를 보고 구현한다** — `python3 -m unittest plugins/plugin-audit/tests/test_check_shape_completeness.py` RED → Interfaces 대로 → GREEN.

- [ ] **Step 4: 레포 실측 대조** — Step 1 명령을 `shape-after.txt` 로 다시 돌려 `diff` 가 비었는지 본다(AC26 「지금 레포 플러그인들의 판정은 바뀌지 않는다」). 다르면 멈추고 보고한다.

- [ ] **Step 5: 커밋** — `fix(plugin-audit): 훅 kill switch 는 그 플러그인 이름의 스위치여야 한다`

---

### Task 3: copy-of-contract 소비 도출의 다른 플러그인 경로 인용 (AC27)

**Files:**
- Modify: `shared/tests/test_copy_of_contract.sh`(산문 도출 `refs=` 의 줄 단위 제외 · 양성 짝 · 낡은 제외 목록 주석)

- [ ] **Step 1: 음성 프로브와 양성 짝을 쓴다** — 같은 파일 안 프로브 블록(사본 레포)에서: 플러그인 A 의 문서 한 줄이 `plugins/B/scripts/<정본 basename>` 를 인용하면 A 가 기대 배포 집합에 들지 않는다(지금은 들어 `missing` 오탐). 양성 짝: 정본 `shared/docreview/agents/doc-critic.md` 의 도출된 플러그인 집합에 spec-distill 이 든다 — 변이로 「`.md` 파일을 산문 도출에서 통째로 뺀다」 를 넣으면 이 단언이 RED.

- [ ] **Step 2: 돌려 실패를 본다** — 음성 프로브 RED.

- [ ] **Step 3: 고친다** — 결정 3 의 줄 단위 제외를 `refs=` 파이프에 더한다(매치 줄의 파일 경로에서 플러그인 이름을 뽑아 인용 경로의 플러그인과 다르면 뺀다 — `awk` 한 단계). 주석의 「오늘 그 다섯 밖에서 … 8개」 류 낡은 수 · 목록을 지우고 규칙만 남긴다.

- [ ] **Step 4: 돌려 통과를 본다** — `bash shared/tests/test_copy_of_contract.sh`(계약 수 서술 `shared/README.md` 대조 포함).

- [ ] **Step 5: 커밋** — `test(shared): copy-of 소비 도출은 같은 플러그인 참조만 센다 — doc-critic 양성 짝`

---

### Task 4: 같은 이름 블록 둘 다 읽기 (AC28)

**Files:**
- Modify: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_route.sh`(등록)
- Create: `shared/tests/fixtures/docreview/critic-two-blocks-distinct.txt`(층 1 블록 둘 — 각 블록에 서로 다른 성한 항목 하나, ref 도 다르다 · 층 2 빈 목록)

- [ ] **Step 1: 케이스를 쓴다** — `case_same_name_blocks_both_read`: `route_r1` 로 그 critic 출력을 넣고 `prep.json` 의 요약 목록에 두 항목이 모두 있다 · `degrade.blocks_merged` 가 `{'docreview-layer1': 2}`.

- [ ] **Step 2: 변이로 이빨을 본다** — 사본에서 `extract_blocks` 의 `for m in ms:` 를 `for m in ms[:1]:` 로 → 이 케이스 RED(그리고 `case_same_name_block_broken_kills_critic` 은 GREEN 으로 남는다 — 그 케이스만으로는 못 가른다는 설계 사실의 확인). `ms[-1:]`(마지막 블록만)으로도 RED.

- [ ] **Step 3: 통과를 보고 커밋** — `bash shared/tests/test_docreview_route.sh` · `test(docreview): 같은 이름 블록 둘이 모두 읽혔는지 잰다`

---

### Task 5: 호출 표면 락 넓히기 · 축 I 변이 유지 (AC29)

**Files:**
- Modify: `shared/entry/check_invocation_surface.py`(`_LEAD` · `_OLD_TRAIL` · `LIVE_TOP` · `LIVE_PREFIX`)
- Modify(락이 걸면): `docs/git-workflow/*` · `.claude-plugin/marketplace.json` · 걸린 살아 있는 문서
- Test: `shared/tests/test_invocation_surface.sh`

**Interfaces:**
- `_LEAD = r"(?:^|(?<=[\s`'\"(「*\[|>]))"`. `_OLD_TRAIL = r"(?![-A-Za-z0-9_/]|\.[A-Za-z0-9])"`(파일 이름 꼴 ` /qg.md` 는 옛 호출이 아니다 — 문장 끝 마침표는 그대로 잡는다). `LIVE_TOP` 에 `.claude-plugin/marketplace.json`, `LIVE_PREFIX` 에 `docs/git-workflow/`.

- [ ] **Step 1: 프로브를 쓴다**(`test_invocation_surface.sh` 의 `variant` · `put` · `expect_red` · `expect_green` 꼴)
  - RED: `**/qg**` · `[/qg](x)` · `| /qg |` 대신 `|/qg|` · `<code>/qg</code>` · `*/qg*` 를 살아 있는 문서에 넣은 사본 각각 · `docs/git-workflow/x.md` 에 옛 이름(`/spec-distill:spec-interview`) · `.claude-plugin/marketplace.json` 설명에 옛 이름.
  - GREEN(음성 대조): ` /qg.md` · `commands/qg.md` 를 말하는 이력 문장이 아닌 파일 이름 줄 · 문장 끝 `/qg.` 는 RED 로 남는다(대조 — 넓힘이 마침표 꼴을 놓치지 않는다).
  - 축 I 의 대안 둘(`spec-interview` · `spec-distill:interview(?![-A-Za-z0-9_])`)과 변이 일곱(`i_si` · `i_sp` · `i_np` · `i_pm` · `i_fx` · 실제 변이 `si` · `pm`)은 그대로 두고 기대값도 그대로다.

- [ ] **Step 2: 돌려 걸리는 자리를 본다** — `bash shared/tests/test_invocation_surface.sh 2>&1 | grep '✗'` — 새 프로브의 RED 기대가 아직 GREEN 이고, 넓힌 뒤에는 지금 트리의 살아 있는 문서(특히 `docs/git-workflow/` · `marketplace.json`)가 걸릴 수 있다.

- [ ] **Step 3: 구현하고 걸린 자리를 고친다** — Interfaces 대로. 걸린 문서는 새 이름으로 고친다(이력 기록 · CHANGELOG 는 축 밖이라 그대로). 고친 문서가 속한 플러그인이 있으면 버전 올릴 목록에 더한다.

- [ ] **Step 4: 돌려 통과를 보고 축 I 변이를 다시 본다** — 2부 GREEN · 변이 일곱이 기대대로 RED · GREEN(출력의 해당 줄을 PR 본문에 옮긴다).

- [ ] **Step 5: 커밋** — `fix(shared): 호출 표면 락이 강조 · 링크 · 표 칸 뒤의 옛 호출을 잡고 파일 이름은 넘긴다 — git 규칙 문서 · 마켓플레이스도 본다`

---

### Task 6: 철학 P3 문장 · 설계 프로필의 대안 비교 한 줄 (AC30 · AC32a)

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md:28` · `plugins/spec-distill/tests/test_rereview_cap_consistency.sh:24`(주석) · `plugins/spec-distill/references/docreview-profiles/design-doc.md`(`approaches_comparison` 줄)
- Test: `shared/tests/test_docreview_profiles.sh`

- [ ] **Step 1: 단언을 쓴다** — `test_docreview_profiles.sh` 에: 철학 문서에 「자리 넷」 0건(음) · 「문서 리뷰 자리 셋(design doc · brief · seed)」 과 「`generic` 프로필은 엔진 테스트만 읽는다」 1건(양). design-doc 프로필 본문의 `approaches_comparison` 줄에 「Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적」 1건 · `layer2` 축 목록이 그대로 일곱(기존 단언) · 골든 무변경(`bash shared/tests/test_docreview_golden.sh`).

- [ ] **Step 2: 돌려 실패를 보고 고친다** — 철학 28행을 「문서 리뷰 자리 셋(design doc · brief · seed)을 통일하는 엔진은 `shared/docreview/` — qg 의 `generic` 프로필은 엔진 테스트만 읽는다.」 로. 같은 개념 쓸기: `git grep -n '자리 넷' -- docs/philosophy plugins shared CLAUDE.md ':!*CHANGELOG.md'` 의 살아 있는 자리를 고친다(픽스처 문장 `cases_advice.sh:397` 의 「자리 넷 x 꼴 여섯」 은 다른 뜻 — 그대로). 프로필 줄은 「- `approaches_comparison` — 대안 비교 없이 단정된 선택. Rejected Alternatives 의 각 대안이 채택안과 같은 기준으로 비교됐는가 — 한 단어로만 기각했으면 지적.」

- [ ] **Step 3: 철학 문서를 읽는 다른 락을 돈다** — `git grep -l 'devbrew-harness-philosophy' -- '*/tests/*' 'shared/tests/*'` 가 낸 테스트(plugin-audit 픽스처 포함)를 돌려 GREEN 을 본다. 픽스처가 그 줄의 글자를 품고 있으면 같은 과제에서 고친다.

- [ ] **Step 4: 통과를 보고 커밋** — 본문에 「리뷰어 프로필 편집(강화 — 규칙 더하기, 기준 완화 없음)」. `docs(spec-distill): 철학 P3 는 리뷰 자리 셋 · 설계 프로필 대안 비교에 같은 기준 한 줄`

---

### Task 7: project-init 「CLAUDE.md 는 그대로 두기」 공시 · 옮기기 중복 공시 · Step 5 문구 (AC31)

**Files:**
- Modify: `plugins/project-init/skills/project-init/SKILL.md`(S4 선택지 설명 · 4c S4 「옮기기」 · Step 5 보고) · `plugins/project-init/README.md`
- Test: `plugins/project-init/tests/test_command_contract.py`

- [ ] **Step 1: 테스트를 먼저 바꾼다** — `test_command_contract.py`: `standalone_line(block, "> CLAUDE.md 를 그대로 뒀다면:")` 접두를 `"> 「CLAUDE.md 는 그대로 두기」를 골랐다면:"` 로. 새 단언: S4 「CLAUDE.md 는 그대로 두기」 설명과 Step 5 에 「AGENTS.md 에 `## Project Charter` 가 생기지 않아 실행마다 CLAUDE.md 의 헌장 절을 다시 읽는다」 · S4 「옮기기」 와 Step 5 에 「CLAUDE.md 의 `<절>` 은 AGENTS.md 에 이미 있어 옮기지 않았다 — CLAUDE.md 가 포인터로 바뀌며 사라졌다」 꼴(절 이름 자리 `## Project Charter` · `## Git Workflow`) · README 에 첫 공시 문장. 옛 접두 「CLAUDE.md 를 그대로 뒀다면:」 0건(음).

- [ ] **Step 2: 돌려 실패를 보고 고친다** — `python3 -m unittest plugins/project-init/tests/test_command_contract.py` RED → SKILL · README 를 설계 §9 문장대로 고친다 → GREEN. 동작(무엇을 쓰는가)은 바꾸지 않는다.

- [ ] **Step 3: project-init 테스트 전부** — `for t in plugins/project-init/tests/test_*.py; do python3 -m unittest "$t" >/dev/null 2>&1 || echo "FAIL $t"; done; for t in plugins/project-init/tests/*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done` 출력 없음.

- [ ] **Step 4: 커밋** — `docs(project-init): 그대로 두기 · 옮기기 중복의 결과를 공시한다 — Step 5 문구`

---

### Task 8: 지휘 절차의 옮김 규칙 (AC32)

**Files:**
- Modify: `plugins/spec-distill/references/conductor-dispatch.md`(`## 사람 자리`)
- Test: `plugins/spec-distill/tests/test_conductor_dispatch_reference.sh`

- [ ] **Step 1: 단언을 쓴다** — `## 사람 자리` 절에 두 문장: 「선택지 설명을 옮길 때 원문의 문장을 하나도 빼지 않는다 — 번역해도 문장 수를 지킨다.」 · 「미리 받은 답을 뒤 하위 agent 에 실을 때 그 dispatch 에 실제로 넣은 문장을 그 relay 파일의 「돌려보낸 글」 에 덧붙인다.」 relay-checker 정의(`agents/relay-checker.md`)의 바이트가 기본 브랜치와 같다(`git diff --quiet "$D" -- plugins/spec-distill/agents/relay-checker.md`).

- [ ] **Step 2: 돌려 실패를 보고 고친다** — `bash plugins/spec-distill/tests/test_conductor_dispatch_reference.sh` RED → 두 문장을 「사용자 답은 글자 그대로 같은 agent 에 돌려준다」 문장 가까이에 넣는다 → GREEN. `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh && bash plugins/spec-distill/tests/test_conducting_loop.sh` 도 GREEN.

- [ ] **Step 3: 커밋** — `docs(spec-distill): 지휘 옮김은 원문 문장을 다 싣고 미리 받은 답의 실린 글을 relay 에 남긴다`

---

### Task 9: AC33 확인 · 문서 · 버전 · 스위트 대조 · AC 보고 (AC33 · AC34 마감)

**Files:**
- Modify: `plugins/spec-distill/{CHANGELOG.md,.claude-plugin/plugin.json,README.md}` · `plugins/plugin-audit/{CHANGELOG.md,.claude-plugin/plugin.json,README.md}` · `plugins/project-init/{CHANGELOG.md,.claude-plugin/plugin.json}` · Task 5 가 고친 다른 플러그인의 같은 셋
- Modify: `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md`(`## 미룸` — 있을 때만)
- Create: `$HOME/.claude/sdd-mirror/r12-plan3/ac-report.md`

- [ ] **Step 1: AC33 을 확인한다**

Run: `git show "$D":docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/roadmap.md | awk '/^### R(1|3|5) /,/^### R(2|4|6) /' | grep -c 'skills/spec-interview/'`
Expected: `0`(로드맵 PR #240). 0 이 아니면 AC 보고에서 「빠짐 — 받는 곳 지휘자 로드맵 PR」 로 적는다(이 계획은 로드맵을 고치지 않는다).

- [ ] **Step 2: README · CHANGELOG · 버전** — plugin-audit README `Principles Instantiated` 의 kill switch 줄에 「자기 이름의 스위치」 한 구절, spec-distill README 는 프로필 · 지휘 절차 줄에 한 구절. CHANGELOG: spec-distill(Changed — 설계 프로필 대안 비교 · 지휘 옮김 규칙) · plugin-audit(Fixed — kill switch 이름 묶기) · project-init(Changed — 공시 · 문구). 공유 락 고침(배선 · copy-of · 호출 표면 · 같은 이름 블록)은 플러그인 CHANGELOG 대상이 아니면 PR 본문에만. plugin.json minor.

Run: `bash shared/tests/test_changelog_integrity.sh && bash shared/tests/test_invocation_surface.sh && bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: PASS.

- [ ] **Step 3: 스위트 대조** — 계획 1 Task 12 Step 2 와 같은 꼴(`r12-plan3` 폴더). 새 실패 이름 0.

- [ ] **Step 4: 변이 기록** — Task 1 Step 5 · Task 4 Step 2 · Task 5 Step 4 의 변이와 더해: `_has_killswitch` 를 옛 정규식으로(Task 2 — 다른 플러그인 · 하위 스위치 케이스 RED) · 결정 3 의 줄 제외 지우기(Task 3 프로브 RED) · 철학 줄을 되돌리기(Task 6 RED) · 프로필 한 줄 지우기(Task 6 RED) · 옛 Step 5 접두 되살리기(Task 7 RED). PR 본문 「변이 확인」 표로.

- [ ] **Step 5: 마지막 전체 리뷰 — AC 보고** — 마지막 전체 리뷰 요청에 설계문서 `## Acceptance Criteria` 의 **AC25~AC33(AC32a 포함) · AC34** 원문을 싣고 AC 마다 한 줄 `AC<번호>: 구현됨 | 미룸 | 빠짐 — <근거>`(AC32a 는 `AC32a:` 로 따로 한 줄 — 대조 스크립트는 그 줄을 읽지 않으므로 AC32 줄이 따로 있어야 한다)를 받는다. 이음매(Task 1 키 꼴과 계획 1 · 2 가 옮긴 `EXEMPT` 자리의 합류 · Task 5 넓힘이 Task 6 · 7 · 8 의 새 문면을 읽는지)와 plan-mandated 테스트 코드를 묻는다. 「리뷰어 프로필 편집(강화)」 을 요청에 밝힌다. 보고를 `$HOME/.claude/sdd-mirror/r12-plan3/ac-report.md` 에 쓴다.

- [ ] **Step 6: 미룸 표와 구현 대조**

Run: `python3 "<SD>"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md "$HOME/.claude/sdd-mirror/r12-plan3/ac-report.md" --acs "AC25~AC34"`
Expected: 첫 줄과 경고를 마지막 보고에 그대로 싣는다.

- [ ] **Step 7: 커밋 · push** — `chore(spec-distill): R12 계획 3 — README · CHANGELOG · 판`(pathspec) 뒤 `git push -u origin feature/review-lock-leftovers`. 마지막 보고: 판정 전체 · AC 보고 전체 · `--impl` 결과 · 커밋 목록 · 본 테스트 실패 · Task 2 실측 대조 결과.
