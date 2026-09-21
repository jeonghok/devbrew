# qg 스코프 기계 (PR1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 선언(`Spec:` 커밋 트레일러)에서 커밋 집합 · 경계 · 끝점 · 두 축 트리를 도출하는 결정론
스크립트 셋과 그 회귀 락 둘을 만든다. **호출자는 0 이다** — 이 PR 은 기존 `/qg` 동작을 바꾸지 않는다.

**Architecture:** 세 스크립트가 각자 한 가지만 한다. `resolve-topic.sh` 는 히스토리를 읽어
`key: value` 사실만 내고(판정하지 않는다 — `resolve-baseline.sh` 와 같은 계약), `seal-worktree.sh`
는 임시 인덱스로 워킹트리를 커밋 하나에 봉인하며, `combine-tips.sh` 는 끝점들을
`git merge-tree --write-tree` 로 순차 합쳐 트리 하나를 낸다. 셋 다 워크트리를 만들지 않고 리포
상태를 바꾸지 않는다. 락 둘은 scratch 리포에 합성 토픽 픽스처를 세워 동작을 잰다.

**Tech Stack:** bash 3.2 호환 (macOS 시스템 bash — `mapfile`·연관배열 금지), git 2.54.0,
`shared/tests/assert.sh` 판정 헬퍼, scratch git 리포 픽스처. 테스트는 `bash <file>` 로 실행한다
(세션 셸은 zsh 라 `PIPESTATUS` 가 비고, 셸 테스트는 리포 루트에서 돈다).

**Spec:** `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` — §6.2(스코프
모델) · §6.4.1(봉인) · §7(실측) · §11(AC) · §13(Verification Plan) · §16(구현 분할) ·
`### Deferred to plan` 이 정본이다. 실행자는 이 계획과 설계를 함께 읽는다. **설계의 확정 항목과
D1–D6 은 근거가 있으면 보고 후 재결정할 수 있고 임의 변경은 금지다(P23).**

## 목차

- [Global Constraints](#global-constraints)
- [이 PR 의 AC 부분집합](#이-pr-의-ac-부분집합)
- [Deferred to plan 의 처분 — 이 계획이 정하는 것](#deferred-to-plan-의-처분--이-계획이-정하는-것)
- [이 계획이 새로 잰 것](#이-계획이-새로-잰-것)
- [File Structure](#file-structure)
- [Task 1: 착수 확인 · baseline 포착 · §7 E·I 재검증](#task-1-착수-확인--baseline-포착--7-ei-재검증)
- [Task 2: resolve-topic.sh — 선언 질의와 B_t 도출](#task-2-resolve-topicsh--선언-질의와-b_t-도출)
- [Task 3: resolve-topic.sh — 경계 · 끝점 · 커밋 집합](#task-3-resolve-topicsh--경계--끝점--커밋-집합)
- [Task 4: seal-worktree.sh — 임시 인덱스 봉인](#task-4-seal-worktreesh--임시-인덱스-봉인)
- [Task 5: combine-tips.sh — 순차 merge-tree](#task-5-combine-tipssh--순차-merge-tree)
- [Task 6: mutation 네 축 + 양성 대조](#task-6-mutation-네-축--양성-대조)
- [Task 7: 회귀 스위트 · bump · CHANGELOG · PR](#task-7-회귀-스위트--bump--changelog--pr)
- [실패 시 되돌리기](#실패-시-되돌리기)
- [Self-Review 기록](#self-review-기록)

## Global Constraints

모든 Task 의 요구에 이 절이 암묵적으로 포함된다. 값은 설계와 리포에서 그대로 옮긴 것이다.

- **G-C1 — 워크트리 격리.** 모든 편집·실행은 워크트리
  `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope` 의 **절대경로**
  로 한다. 메인 체크아웃(`/Users/jeonghokim/Downloads/devbrew`)으로 `cd` 하지 않는다. Bash 도구는
  호출마다 새 셸이라 `cd` 가 다음 호출로 이어지지 않는다 — 누산기가 필요하면 파일로 둔다.
- **G-C2 — 이 PR 은 호출자를 만들지 않는다.** `SKILL.md` · `qg.md` · `references/runtime-gate.md`
  를 건드리지 않는다. 배선은 PR4 다(§16 순서 제약 1→2→3→4→5). 세 스크립트를 부르는 자리는
  이 PR 의 테스트뿐이다. **기존 동작 영향 0 이 이 PR 의 판정 기준이다.**
- **G-C3 — bash 3.2.** `mapfile` · 연관배열(`declare -A`) · `${arr[@]}` 의 무방비 확장을 쓰지
  않는다(`set -u` 아래 빈 배열 확장이 unbound 로 죽는다). 배열 대신 공백 구분 문자열 + `for` 를
  쓴다. `$( )` 안에 heredoc 을 넣지 않는다(본문 내용에 따라 파싱이 깨진다).
- **G-C4 — 스크립트는 판정하지 않는다.** 세 스크립트는 `key: value` **사실만** 낸다.
  `clean`/`defect`/`not-certified` 어휘는 PR2 가 만들고 PR4 가 배선한다. 이 PR 의 스크립트가 그
  단어를 내면 설계 이탈이다.
- **G-C5 — 리포 상태를 바꾸지 않는다.** 세 스크립트 전부 read-only 여야 한다(봉인이 만드는 git
  객체는 ref 없는 객체라 상태 변경이 아니다 — AC14 가 그것을 잰다). `git worktree add` 를 쓰지
  않는다.
- **G-C6 — 테스트는 scratch 리포에서만 git 을 돌린다.** 실제 리포에서 fixture git 명령을 돌리지
  않는다(`test_resolve_baseline.sh` 의 머리말이 같은 것을 못 박는다: *"각 케이스는 mktemp 아래
  일회용 git 레포를 만든다 (fail-closed: 실제 레포에서 git 실행 금지)"*).
- **G-C7 — 버전 bump 는 같은 커밋에서.** `plugins/quality-gates/` 를 건드리는 커밋은
  `.claude-plugin/plugin.json` 을 같은 커밋에서 bump 하고 `CHANGELOG.md` 항목을 단다. 이 PR 은
  **새 표면 · breaking 없음 → minor**: `7.6.2` → `7.7.0`. **번호는 머지 직전에 재확인한다** —
  같은 버전 문자열은 충돌 없이 병합되므로 먼저 머지되는 쪽이 이긴다.
- **G-C8 — 선언은 이 PR 자신에게도 적용된다.** 이 PR 의 커밋은 트레일러
  `Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1` 을 단다(§16 —
  다섯 PR 이 같은 값을 쓰면 분할이 비용을 늘린다). 커밋 메시지 끝에
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` 를 붙인다.
- **G-C9 — `gh pr merge` 는 금지.** auto-mode 판정기가 막는다. 머지는 사용자가
  `! gh pr merge <n> --merge` 로 직접 한다. `gh api` 우회는 금지다.

## 이 PR 의 AC 부분집합

설계 §11 의 23개 중 **PR1 이 지는 것만** 여기 적는다. 나머지는 PR2–PR5 가 진다.

| AC | 이 PR 이 지는 범위 | 검증 |
|---|---|---|
| **AC3** | `Spec:` 트레일러가 둘 이상의 브랜치에 걸쳐 있을 때 `resolve-topic.sh` 가 그 전부를 한 집합으로 낸다 | `test_topic_boundary.sh` F1 |
| **AC4** | 구성원 하나가 이미 `main` 에 머지돼 있어도 집합에 든다 — ref 가 살아 있든 지워졌든 | F2 · F3 |
| **AC5** | 경계가 `fork(b)` 들의 merge-base 다. `parents(T) \ T` 도 `merge-base(base_ref, HEAD)` 도 쓰지 않는다 | F1 · F2 · Task 6 변이 |
| **AC6** | 끝점 계산이 **봉인 커밋을 후보에 먼저 넣은 뒤 극대원소**다(치환이 아니다). HEAD 축이 끝점들의 `merge-tree --write-tree` 결과다 | F8 · `test_seal_no_side_effects.sh` |
| **AC7** | 합치기 충돌 시 `combine-tips.sh` 가 `status: merge-conflict` 와 **충돌 파일 목록**을 낸다 | Task 5 |
| **AC14** | 봉인이 실제 인덱스 · HEAD · 워킹트리를 바꾸지 않고, 워크트리를 만들지 않으며, **봉인 트리에 임시 인덱스 파일이 없다** | `test_seal_no_side_effects.sh` |
| **AC15** (부분) | 세 스크립트가 커밋 SHA 전부 · 끝점 · 경계 · 합친 트리 OID 를 **산출한다**. 그것을 판정 산출물이 **싣는** 것은 PR4 다 | F1 · Task 5 |
| **AC16** (부분) | 트레일러가 있는데 경로가 실재하지 않거나 한 브랜치가 서로 다른 토픽 키를 담으면 `status: declaration-invalid` 다. 선언이 **없을** 때 세 모드로 내려가는 배선은 PR4 다 | F6 · F7 |

**PR1 이 지지 않는 것** — AC1 · AC2 · AC8–AC13 · AC17–AC23. 특히 **AC21**(제거된 테스트가 어떤
`# guards:` 글롭의 유일 대상이 아님)은 이 PR 이 테스트를 하나도 지우지 않으므로 해당 없다.

## Deferred to plan 의 처분 — 이 계획이 정하는 것

설계 `### Deferred to plan` 의 다섯 중 이 PR 에 해당하는 넷을 여기서 확정한다.

### D-1. 세 스크립트의 CLI 표면과 출력 키

`resolve-baseline.sh` 의 계약을 그대로 따른다 — **stdout 은 `key: value` 고정 줄 수, 없는 값은
`-`, exit 0 이 정상, 사실만 내고 판정하지 않는다.** 파싱은 `shared/tests/assert.sh` 의
`field <key> <text>` 가 한다.

**`resolve-topic.sh`** — 서브커맨드 둘.

```
resolve-topic.sh resolve <topic-key> [--seal <B>]    → 요약 9줄
resolve-topic.sh commits <topic-key>                 → T 의 커밋 SHA, topo-order, 한 줄에 하나
```

`--seal <B>` 는 **봉인 커밋을 끝점 후보에 먼저 넣는다**(§6.2.4 · AC6). 끝점 도출은 이 스크립트의
책임이므로 여기에 둔다 — `seal-worktree.sh` 를 이 스크립트가 부르지는 않는다(스크립트끼리 부르지
않는다). 배선은 PR4 가 한다: 봉인 → `--seal` → 끝점 → `combine-tips.sh`.

`resolve` 의 9키:

| 키 | 값 |
|---|---|
| `topic_key:` | 질의한 값 그대로(조각 포함) 또는 `-` |
| `status:` | `ok` \| `no-declaration` \| `declaration-invalid` \| `base-unresolved` |
| `reason:` | `-` 또는 한 줄 사유 |
| `declared:` | 선언 커밋 수 `\|C\|` |
| `branches:` | `B_t` — `<ref이름>` 또는 `merged:<주제쪽부모 SHA>`, 쉼표 구분 |
| `boundary:` | 경계 커밋 full SHA |
| `tips:` | 끝점 SHA, topo-order, 쉼표 구분 |
| `commits:` | `\|T\|` |
| `base_ref:` | `resolve-baseline.sh` 가 낸 `base_ref` |

`status` 는 **스크립트 자신의 어휘**다. PR4 가 판정 어휘로 옮기는 매핑을 여기 못 박는다 —
그 매핑이 없으면 PR4 가 `base-unresolved` 를 갈 곳 없이 받는다:

| `status` | PR4 의 판정 |
|---|---|
| `ok` | 선언 경로로 진행 |
| `no-declaration` | §6.2.5 fallback — 기존 세 모드. **`not-certified` 가 아니다**(AC16) |
| `declaration-invalid` | `not-certified (declaration-invalid)` |
| `base-unresolved` | `not-certified (baseline-unrunnable)` — 기준선 축을 세울 수 없다 |

**`seal-worktree.sh`** — 서브커맨드 하나.

```
seal-worktree.sh seal <session-id>   → 봉인 커밋 SHA 한 줄 (stdout)
```

실패는 `die` 로 exit 2 (`qg-worktree.sh` 의 계약과 같다).

**`combine-tips.sh`** — 인자로 끝점들을 순서대로 받는다.

```
combine-tips.sh <tip1> [<tip2> ...]   → 요약 6줄
```

| 키 | 값 |
|---|---|
| `tree:` | 합친 트리 OID 또는 `-` |
| `status:` | `ok` \| `merge-conflict` \| `bad-input` |
| `steps:` | 수행한 `merge-tree` 횟수 (`N-1`) |
| `intermediates:` | 순차 합치기가 만든 `commit-tree` 중간 커밋 SHA, 쉼표 구분 (PR4 가 `qg-gc.py` 로 넘긴다) |
| `conflicts:` | 충돌 파일 경로, 쉼표 구분 |
| `failed_at:` | 충돌을 일으킨 구성원 tip SHA — **순차가 주는 귀속**(§14 가 octopus 를 기각한 이유) |

### D-2. 머지된 구성원의 `fork(b)` — 설계가 남긴 빈칸

설계 §6.2.3 은 *"`fork(b)` 가 `base_ref` 안쪽으로 들어오면 그 브랜치의 주제 쪽 첫 커밋의 부모를
`fork` 로 쓴다"* 라고만 적었다. 구현 가능한 형태로 확정한다:

```
m        = git rev-list --ancestry-path --merges <c>..<base_ref> | tail -1   # c 를 처음 담은 머지
side     = m 의 부모 중 c 를 포함하는 것                                      # 주제 쪽
mainline = m^1                                                              # 기반 쪽
fork(b)  = git merge-base <side> <mainline>
```

**`^2` 를 주제 쪽으로 단정하지 않는다** — 부모마다 `merge-base --is-ancestor <c> <parent>` 를
걸어 고른다. 표준 형태에서는 `^2` 가 나오지만(아래 실측 3), 반대로 머지한 이력에서도 옳다.

**`merge-base(base_ref, tip)` 를 머지된 구성원에 그냥 쓰면 안 된다** — 실측 2 가 그것이
`tip` 자신을 돌려주는 것을 보였다. 그러면 그 브랜치 전체가 경계 뒤로 숨어 seed 가 이름 붙인
결함이 그대로 재발한다.

### D-3. 새 락 둘의 픽스처 구성

`test_topic_boundary.sh` 의 합성 토픽 픽스처 **여덟**(F1–F8)과 `test_seal_no_side_effects.sh` 의
픽스처는 각 Task 의 Step 에 코드로 적혀 있다. mutation 네 축(삭제 · 변형 · 추가 · 불일치)과
양성 대조는 Task 6 이다.

### D-4. `# guards:` 선언 — 하지 않는다

새 락 둘은 `# guards:` 를 **선언하지 않는다.** 근거는 리포의 선례다: `# guards:` 를 다는 락은
리포 코퍼스를 글롭으로 훑는 것들(`test_copy_of_contract.sh` · `test_dispatch_disposition.sh` 등
61개)이고, `test_resolve_baseline.sh` 처럼 **scratch 리포에서 스크립트 동작을 재는 락은 선언하지
않는다**. 이 PR 의 락 둘은 후자다. 게다가 선언하면
`test_guards_coverage_bidirectional.sh` 가 `bash <lock> --emit-scanned` 를 호출하므로 그 플래그를
구현해야 하고, 코퍼스를 안 읽는 락은 빈 출력을 내 「미지원」으로 떨어진다 — 선언이 공허해진다.

## 이 계획이 새로 잰 것

설계 §7 의 **E 와 I 는 구현 전 재검증 필수**로 표시돼 있다. 이 계획을 쓰면서 **격리된 scratch
리포에서** 형태를 확인했다. **아래는 scratch 실측이고 실제 devbrew 리포의 실측이 아니다** —
실제 리포에서의 재검증은 Task 1 이다.

| # | 잰 것 | 결과 |
|---|---|---|
| 1 | `git log --all --grep='^Spec: docs/x-design\.md#pr1$'` | 선언 커밋 둘 히트. **맨 경로 질의(`…\.md$`)는 0 히트** — 조각이 다른 토픽임이 질의 층에서 성립한다(D1.4 유지) |
| 2 | 머지된 구성원에 `merge-base(main, tip)` | **`tip` 자신을 돌려준다** — 브랜치 전체가 경계 뒤로 숨는다. 특례가 필요한 이유의 실물 |
| 3 | `fork = merge-base(side, m^1)` | 진짜 분기점과 **일치**. `m` 은 `rev-list --ancestry-path --merges c..base \| tail -1`, `side` 는 `c` 를 포함하는 부모(표준 형태에서 `^2`) |
| 4 | 경계 = fork 들의 merge-base (머지된 것 + 살아 있는 것 혼합) | 작업이 실제 시작된 지점과 **일치** — AC5 의 모양 |
| 5 | `git merge-tree --write-tree` 정상 | rc 0 · stdout 한 줄 = 트리 OID |
| 6 | 같은 명령, 충돌 | **rc 1** · **stdout 에 전부** 나오고 **stderr 는 0바이트**. 1줄 = 트리 OID, 그다음 `<mode> <oid> <stage>\t<path>` 스테이지 줄, 빈 줄, `CONFLICT (content): …` |
| 7 | 임시 인덱스 봉인 | 수정·삭제·untracked 반영 ✓ · ignored 제외 ✓ · HEAD/인덱스/워킹트리 불변 ✓ · 워크트리 0 ✓ · 봉인 트리에 인덱스 파일 없음 ✓ |
| 8 | `rev-list --topo-order --no-walk` 에 인자 순서를 바꿔 넣기 | **출력이 인자 순서에 의존한다.** `--no-walk=sorted` 도 같다 |
| 9 | 극대원소 계산 (`merge-base --is-ancestor` 이중 루프) | 스택 A→B 에서 `tip(A)` 가 정확히 빠진다 |
| 10 | 봉인 커밋을 후보에 **먼저 넣고** 극대원소 | 봉인이 극대원소로 서고 `tip(A)` 는 빠진다 — 「치환」이 불가능했던 그 형태(AC6) |

**실측 8 이 순서 규칙을 정한다** — 설계 §6.2.4 의 「순서 = topo-order, 결정론으로 고정」은 SHA
목록만으로는 얻어지지 않는다. **먼저 SHA 집합을 사전순(`sort -u`)으로 정규화한 뒤**
`rev-list --topo-order --no-walk` 에 넣는다. 그러면 출력이 «집합»의 순수 함수가 되어 발견 순서와
무관해진다. 이 두 단계를 한 단계로 줄이면 결정론이 조용히 사라진다.

**실측 6 이 파싱 규칙을 정한다** — 충돌 정보가 stderr 가 아니라 stdout 에 있으므로
`out=$(git merge-tree --write-tree A B)` 로 잡고 `head -1` 이 트리, 스테이지 줄에서 경로를 뽑는다.
`2>/dev/null` 로 버려도 아무것도 잃지 않는다.

**실측 4 가 §15-2 의 알려진 한계도 보였다** — 토픽 중간에 main 병합이 끼면 그 병합이 가져온 남의
커밋이 `T` 에 든다. 막지 않고 공시한다(설계가 그렇게 정했다).

## File Structure

```
plugins/quality-gates/
  scripts/
    resolve-topic.sh          [신설]  선언 → C → B_t → 경계 · 끝점 · T
    seal-worktree.sh          [신설]  임시 인덱스로 워킹트리를 커밋 하나에 봉인
    combine-tips.sh           [신설]  끝점들을 순차 merge-tree 로 트리 하나에
  tests/
    test_topic_boundary.sh    [신설]  AC3·AC4·AC5·AC6(끝점)·AC15·AC16 — 합성 토픽 픽스처 F1–F8
    test_seal_no_side_effects.sh [신설] AC14 — 봉인 부작용 0 + 봉인 트리에 인덱스 없음
  .claude-plugin/plugin.json  [수정]  7.6.2 → 7.7.0
  CHANGELOG.md                [수정]  [7.7.0] Added 항목
```

각 파일의 책임은 하나다. `resolve-topic.sh` 는 히스토리만 읽고, `seal-worktree.sh` 는 워킹트리만
읽고, `combine-tips.sh` 는 커밋 인자만 받는다 — 셋이 서로를 부르지 않는다(합성은 PR4 의 일이다).
이 경계 덕분에 각 락이 한 스크립트만 세우면 된다.

---

## Task 1: 착수 확인 · baseline 포착 · §7 E·I 재검증

**Files:**
- Create: `$CLAUDE_JOB_DIR/tmp/pr1-baseline.txt` (작업 산출물 아님 — 기준선 기록)
- Read: `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` §7 · §15-7

**Interfaces:**
- Consumes: 없음 (첫 Task)
- Produces: `pr1-baseline.txt` — 착수 시점의 선재 RED 목록(**파일 이름 + 실패 줄 수**). Task 7 이
  이 파일과 대조해 「내가 만든 RED 인가」를 가른다.

- [ ] **Step 1: 작업 트리가 깨끗한지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git status --porcelain
```

Expected: 빈 출력. 비어 있지 않으면 **멈추고 사용자에게 보고한다** — 남의 편집 위에 쌓지 않는다.

- [ ] **Step 2: base 이동량을 잰다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git fetch -q origin && git rev-list --count HEAD..origin/main
```

Expected: 숫자. **0 이 아니면** `git merge origin/main` 으로 먼저 최신화한다(rebase 금지 — 이
리포는 merge 규약이다). 충돌하면 멈추고 보고한다.

- [ ] **Step 3: 선재 RED baseline 을 포착한다 — rc 가 아니라 실패 «줄 수»로**

`rc` 만 잡으면 이미 RED 인 파일 «안»의 새 실패가 원리적으로 안 보인다. 실패 파일 이름과 실패
줄 수를 함께 남긴다.

아래를 `$CLAUDE_JOB_DIR/tmp/pr1_baseline.sh` 로 저장하고 `bash` 로 돌린다:

```bash
#!/usr/bin/env bash
# PR1 착수 baseline — 셸 락의 실패 «줄 수»까지 남긴다.
set -u
W=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
OUT="${CLAUDE_JOB_DIR:?}/tmp/pr1-baseline.txt"
cd "$W" || exit 1
: > "$OUT"
for t in plugins/quality-gates/tests/test_*.sh shared/tests/test_*.sh plugins/spec-distill/tests/test_*.sh; do
  [ -f "$t" ] || continue
  o=$(bash "$t" 2>&1); rc=$?
  fails=$(printf '%s\n' "$o" | grep -c '✗')
  printf '%s\trc=%s\tfail_lines=%s\n' "$t" "$rc" "$fails" >> "$OUT"
done
echo "=== 선재 RED (rc != 0) ==="
awk -F'\t' '$2 != "rc=0"' "$OUT"
echo "=== 합계: $(wc -l < "$OUT" | tr -d ' ') 파일 · RED $(awk -F"\t" '$2 != "rc=0"' "$OUT" | wc -l | tr -d ' ') ==="
```

Expected: `pr1-baseline.txt` 가 생기고 RED 목록이 출력된다. **RED 가 0 이 아닌 것이 정상이다** —
이 리포에는 stale red 가 있다. 이 목록을 Task 7 이 대조한다.

- [ ] **Step 4: §7-E 를 «새 규칙»으로 실제 리포에서 재검증한다**

설계 §7-E 는 옛 규칙(`parents(T) \ T`)으로 잰 값이다. 경계가 **브랜치 분기점**으로 바뀌었으므로
같은 토픽에 새 규칙을 다시 건다. 아래를 `$CLAUDE_JOB_DIR/tmp/pr1_verify_e.sh` 로 저장해 돌린다:

```bash
#!/usr/bin/env bash
# §7-E 재검증 — 새 경계 규칙(브랜치 분기점)을 실제 리포의 한 토픽에 건다.
# 이 리포에는 아직 `Spec:` 트레일러가 0 개이므로(실측 §7-B), 대리 트레일러
# `Claude-Session` 으로 «규칙의 모양»을 잰다 — 값이 아니라 모양이 검증 대상이다.
set -u
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope || exit 1
KEY=$(git log -n 200 --format='%(trailers:key=Claude-Session,valueonly)' \
      | grep -v '^$' | sort | uniq -c | sort -rn | head -1 | awk '{print $2}')
echo "대리 토픽 키: $KEY"
C=$(git log --all --grep="^Claude-Session: ${KEY}\$" --format='%H')
echo "|C| = $(printf '%s\n' "$C" | grep -c .)"
BASE_REF=$(bash plugins/quality-gates/scripts/resolve-baseline.sh | awk -F': ' '/^base_ref:/{print $2}')
echo "base_ref = $BASE_REF"
FORKS=""
for ref in $(git for-each-ref --format='%(refname:short)' refs/heads); do
  tip=$(git rev-parse "$ref")
  git merge-base --is-ancestor "$tip" "$BASE_REF" 2>/dev/null && continue
  for c in $C; do
    if git merge-base --is-ancestor "$c" "$tip" 2>/dev/null; then
      f=$(git merge-base "$BASE_REF" "$tip")
      echo "  살아있는 구성원 $ref  fork=$f"
      FORKS="$FORKS $f"; break
    fi
  done
done
for c in $C; do
  hit=no
  for ref in $(git for-each-ref --format='%(refname:short)' refs/heads); do
    tip=$(git rev-parse "$ref")
    git merge-base --is-ancestor "$tip" "$BASE_REF" 2>/dev/null && continue
    git merge-base --is-ancestor "$c" "$tip" 2>/dev/null && { hit=yes; break; }
  done
  [ "$hit" = yes ] && continue
  m=$(git rev-list --ancestry-path --merges "$c..$BASE_REF" 2>/dev/null | tail -1)
  [ -n "$m" ] || { echo "  고아 선언 $c"; continue; }
  side=""
  for p in $(git rev-list --parents -n 1 "$m" | cut -d' ' -f2-); do
    git merge-base --is-ancestor "$c" "$p" 2>/dev/null && { side="$p"; break; }
  done
  [ -n "$side" ] || { echo "  고아 선언 $c"; continue; }
  f=$(git merge-base "$side" "$(git rev-parse "$m^1")")
  echo "  머지된 구성원 merged:$side  m=$m  fork=$f"
  FORKS="$FORKS $f"
done
FORKS=$(printf '%s\n' $FORKS | sort -u | tr '\n' ' ')
echo "forks = $FORKS"
set -- $FORKS
B="$1"; shift
for f in "$@"; do B=$(git merge-base "$B" "$f"); done
echo "경계 = $B"
git log -n 1 --format='  %h %s' "$B"
```

Expected: 경계 SHA 가 하나 나오고, 그 커밋이 **그 작업이 실제로 시작된 직전 지점**으로 읽힌다.

> **판정 기준** — 모양이 맞으면(경계가 작업 시작 직전) 통과. **값이 §7-E 의 `add4c9cd` 와 달라도
> 회귀가 아니다** — 규칙이 바뀌었으므로 값이 달라지는 것이 정상이다. 모양이 **틀리면**(경계가
> 브랜치 tip 이거나 리포 최초 커밋이면) 멈추고 사용자에게 보고한다 — 설계 §6.2.3 의 재결정
> 사안이다.

- [ ] **Step 5: §7-I 를 실제 리포에서 재검증한다 — `.gitignore` 깊이**

scratch 리포와 실제 리포의 `.gitignore` 가 다르다. 봉인 인덱스가 놓일 자리가 실제로 git-ignored
인지 잰다:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && mkdir -p .claude/quality-gates && git check-ignore -v .claude/quality-gates/seal-probe.index; echo "check-ignore rc=$?"
```

Expected: `rc=0` 이고 `.gitignore:219:/.claude/*` 같은 줄이 나온다. **rc 가 1 이면**(무시되지
않음) 멈추고 보고한다 — 그 상태로 봉인하면 AC14 가 깨진다. (이것이 Task 4 의 스크립트가
`check-ignore` 가드와 봉인 «후» 트리 검사를 **둘 다** 갖는 이유다.)

- [ ] **Step 6: 정리 — 프로브 잔존물을 지운다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && rm -f .claude/quality-gates/seal-probe.index && git status --porcelain
```

Expected: 빈 출력.

---

## Task 2: `resolve-topic.sh` — 선언 질의와 `B_t` 도출

**Files:**
- Create: `plugins/quality-gates/scripts/resolve-topic.sh`
- Create: `plugins/quality-gates/tests/test_topic_boundary.sh`

**Interfaces:**
- Consumes: `plugins/quality-gates/scripts/resolve-baseline.sh` — `base_ref:` 키 (기존 스크립트,
  변경 없음). `shared/tests/assert.sh` 의 `ok` · `no` · `field` · `finish`.
- Produces: `resolve-topic.sh resolve <topic-key>` 가 **9키 중 `topic_key` · `status` · `reason` ·
  `declared` · `branches` · `base_ref` 다섯**을 채운다. `boundary` · `tips` · `commits` 는 이
  Task 에서 `-` 이고 Task 3 이 채운다. 키 이름과 `status` 어휘(`ok` · `no-declaration` ·
  `declaration-invalid` · `base-unresolved`)가 Task 3 · Task 5 · PR4 의 계약이다.

- [ ] **Step 1: 실패하는 테스트를 쓴다 — F1·F2·F3·F5·F6**

`plugins/quality-gates/tests/test_topic_boundary.sh` 를 만든다:

```bash
#!/usr/bin/env bash
# test_topic_boundary.sh — scripts/resolve-topic.sh (설계 §6.2, AC3·AC4·AC5·AC15·AC16).
#
# 각 케이스는 mktemp 아래 **일회용 git 리포**를 세운다 — 실제 리포에서 fixture git 실행 금지.
# 합성 토픽 픽스처 F1–F8 + Task 6 의 양성 대조가 이 락의 이빨이다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RT="$PLUGIN_ROOT/scripts/resolve-topic.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

KEY='docs/x-design.md#pr1'
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

new_repo() {   # 빈 리포 + main 한 커밋. CWD = 리포
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo r0 > f.txt; git add f.txt; git commit -qm r0
}

decl_commit() {   # <파일> <내용> <메시지> — 토픽 선언 트레일러를 단 커밋
  echo "$2" > "$1"; git add "$1"
  git commit -qm "$3

Spec: $KEY"
}

# ── F1: 형제 브랜치 둘이 같은 토픽을 선언 → 한 집합 (AC3) ──────────────────
case_f1_two_siblings() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  git checkout -q topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F1 status: ok"
  assert_eq "$(field declared "$out")" "2" "F1 선언 커밋 2"
  assert_grep "$(field branches "$out")" 'topicA' "F1 branches 에 topicA"
  assert_grep "$(field branches "$out")" 'topicB' "F1 branches 에 topicB"
  cleanup
}

# ── F2: 구성원 하나가 머지됨 + ref 살아 있음 → 여전히 포함 (AC4) ────────────
#    라운드 2 재비판이 잡은 회귀의 회귀 락이다: 1단계는 tip 이 base 의 조상이라
#    떨어뜨리고, 2단계 발동 조건이 「살아 있는 ref 에 안 걸리면」이면 여기서
#    발동하지 않아 고아로 떨어진다. 조건은 「1단계가 낸 B_t 에 안 들어가면」이다.
case_f2_merged_ref_alive() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  git merge -q --no-ff -m "merge topicA" topicA     # ref 는 그대로 둔다
  git checkout -q -b topicB; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F2 status: ok"
  assert_eq "$(field declared "$out")" "2" "F2 선언 커밋 2"
  assert_grep "$(field branches "$out")" 'merged:|topicA' "F2 머지된 구성원이 branches 에 있다"
  cleanup
}

# ── F3: 구성원 하나가 머지되고 ref 도 삭제됨 → 2단계가 받는다 (AC4) ─────────
case_f3_merged_ref_deleted() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q main
  git merge -q --no-ff -m "merge topicA" topicA
  git branch -q -D topicA
  git checkout -q -b topicB; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "ok" "F3 status: ok"
  assert_grep "$(field branches "$out")" 'merged:' "F3 ref 삭제된 구성원을 merged: 로 받는다"
  cleanup
}

# ── F5: 조각은 서로 다른 토픽이다 (D1.4) ────────────────────────────────────
case_f5_fragment_discriminates() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

Spec: docs/x-design.md#pr2"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field declared "$out")" "1" "F5 #pr1 질의가 #pr2 를 매치하지 않는다"
  local out2; out2=$(bash "$RT" resolve 'docs/x-design.md')
  assert_eq "$(field status "$out2")" "no-declaration" "F5 맨 경로 질의는 조각을 매치하지 않는다"
  cleanup
}

# ── F6: 트레일러는 있는데 가리키는 경로가 실재하지 않음 (AC16) ──────────────
case_f6_path_absent() {
  new_repo
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt
  git commit -qm "a1

Spec: docs/nonexistent-design.md#pr1"
  local out; out=$(bash "$RT" resolve 'docs/nonexistent-design.md#pr1')
  assert_eq "$(field status "$out")" "declaration-invalid" "F6 경로 부재 → declaration-invalid"
  assert_grep "$(field reason "$out")" '.' "F6 사유가 비어 있지 않다"
  cleanup
}

# (F4 · F7 · F8 은 Task 3 이 더한다 — 셋 다 경계 또는 T 가 있어야 잴 수 있다.)

# ── 선언이 아예 없는 리포 ───────────────────────────────────────────────────
case_no_declaration() {
  new_repo
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt; git commit -qm "a1 (선언 없음)"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "no-declaration" "선언 0 → no-declaration"
  assert_eq "$(field declared "$out")" "0" "declared: 0"
  cleanup
}

# ── 출력 계약: 9키가 «항상» 나온다 ──────────────────────────────────────────
case_nine_keys_always() {
  new_repo
  local out; out=$(bash "$RT" resolve "$KEY")
  local n; n=$(printf '%s\n' "$out" | grep -cE '^[a-z_]+:')
  assert_eq "$n" "9" "선언 0 인 리포에서도 9키 전부 emit"
  local rc; bash "$RT" resolve "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "0" "정상 경로 exit 0"
  cleanup
}

for c in case_f1_two_siblings case_f2_merged_ref_alive case_f3_merged_ref_deleted \
         case_f5_fragment_discriminates case_f6_path_absent \
         case_no_declaration case_nine_keys_always; do
  echo "== $c"; $c
done
finish
```

- [ ] **Step 2: 돌려서 실패를 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_topic_boundary.sh
```

Expected: FAIL — 모든 케이스가 `✗`. 스크립트가 없어 `bash: …/resolve-topic.sh: No such file` 가
stderr 로 나오고 `field` 가 빈 값을 내 비교가 어긋난다.

- [ ] **Step 3: `resolve-topic.sh` 를 쓴다 — 선언 질의와 `B_t` 까지**

`plugins/quality-gates/scripts/resolve-topic.sh`:

```bash
#!/usr/bin/env bash
# resolve-topic.sh — 선언(`Spec:` 커밋 트레일러) → 커밋 집합 → 경계 · 끝점.
#   (설계 2026-09-21 §6.2, AC3·AC4·AC5·AC15·AC16)
#
# Subcommands:
#   resolve <topic-key>   -> key: value 요약 9줄
#   commits <topic-key>   -> T 의 커밋 SHA (topo-order), 한 줄에 하나
#
# **사실만 낸다 — 판정하지 않는다.** `resolve-baseline.sh` 와 같은 계약이다:
# 고정 키 집합 · 없는 값은 `-` · 정상 경로는 언제나 exit 0. `not-certified` 같은
# 판정 어휘는 이 층에 없다 — 소비자(PR4)가 `status:` 를 판정으로 옮긴다.
#
#   status: ok                  선언 경로로 진행
#   status: no-declaration      선언 0 — 기존 세 모드로 fallback (판정 아님)
#   status: declaration-invalid 선언이 깨졌다 (경로 부재 · 한 브랜치에 여러 키)
#   status: base-unresolved     base_ref 미해결 — 기준선 축을 세울 수 없다
#
# **토픽 키는 트레일러 값 «전체»다 — 조각(`#pr1`)까지 포함한다.** 조각을 무시하는
# 질의를 쓰면 여러 PR 이 한 토픽으로 합쳐진다(설계 §6.2.1 · §16).
#
# bash 3.2 호환: 배열 대신 공백 구분 문자열을 쓴다.
set -u

die() { echo "resolve-topic: $*" >&2; exit 2; }

SUB="${1:-}"; TOPIC="${2:-}"
case "$SUB" in
  resolve|commits) ;;
  *) die "usage: resolve-topic.sh {resolve|commits} <topic-key>" ;;
esac
[ -n "$TOPIC" ] || die "empty topic key"

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"

DECLARED="-"; BRANCHES="-"; BOUNDARY="-"; TIPS="-"; NCOMMITS="-"; BASE_REF="-"

emit() {   # <status> <reason>
  echo "topic_key: $TOPIC"
  echo "status: $1"
  echo "reason: ${2:--}"
  echo "declared: $DECLARED"
  echo "branches: $BRANCHES"
  echo "boundary: $BOUNDARY"
  echo "tips: $TIPS"
  echo "commits: $NCOMMITS"
  echo "base_ref: $BASE_REF"
  exit 0
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || emit base-unresolved "not a git work tree"

# base_ref 는 기존 모듈이 푼다 — 후보 체인을 두 벌 두지 않는다.
BASE_REF=$(bash "$SCRIPT_DIR/resolve-baseline.sh" | awk -F': ' '/^base_ref:/{print $2}')
[ -n "$BASE_REF" ] && [ "$BASE_REF" != "-" ] || { BASE_REF="-"; emit base-unresolved "resolve-baseline.sh degraded"; }

# ── C = 선언 커밋 ──────────────────────────────────────────────────────────
# git 의 `--grep` 은 기본이 BRE 다. 토픽 키에 `.` 가 흔하므로 메타문자를 이스케이프한다.
# 이스케이프를 빼면 `x-design.md` 의 `.` 가 임의 문자가 되어 다른 토픽을 삼킨다.
esc=$(printf '%s' "$TOPIC" | sed 's/[][\.*^$\\]/\\&/g')
C=$(git log --all --grep="^Spec: ${esc}\$" --format='%H' 2>/dev/null)
DECLARED=$(printf '%s\n' "$C" | grep -c . )
[ "$DECLARED" -gt 0 ] || { DECLARED=0; emit no-declaration "no commit carries this topic key"; }

# ── 선언이 가리키는 경로가 실재하는가 (AC16) ────────────────────────────────
# 토픽 키에서 조각(`#…`)을 떼면 리포-상대 경로다. working tree 기준으로 본다 —
# 선언은 «지금» 무엇을 가리키는가의 문제다.
path="${TOPIC%%#*}"
[ -e "$path" ] || emit declaration-invalid "declared path does not exist: $path"

# (AC16 의 나머지 절반 — 「한 브랜치가 서로 다른 토픽 키를 함께 담음」 — 은 Task 3 이
#  더한다. 그 검사는 **T 위에서** 해야 한다: 커밋의 조상 전체를 훑으면 main 에 이미
#  머지된 앞 토픽의 키까지 세어 거짓 양성이 난다.)

# ── B_t 1단계: 살아 있는 ref ───────────────────────────────────────────────
# `git branch --contains` 를 쓰지 않는다 — 머지된 커밋에 대해 main 과 후손 전부를
# 돌려줘 끝점을 식별할 수 없다(설계 §7-C).
BR_NAMES=""; BR_TIPS=""
for ref in $(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null); do
  tip=$(git rev-parse "$ref" 2>/dev/null) || continue
  # base_ref 의 조상인 ref(= main 자신 · 이미 머지돼 tip 이 안 움직인 브랜치)는 뺀다.
  git merge-base --is-ancestor "$tip" "$BASE_REF" 2>/dev/null && continue
  for c in $C; do
    if git merge-base --is-ancestor "$c" "$tip" 2>/dev/null; then
      BR_NAMES="$BR_NAMES $ref"; BR_TIPS="$BR_TIPS $tip"; break
    fi
  done
done

# ── B_t 2단계: 머지된 구성원 ───────────────────────────────────────────────
# 발동 조건은 **「1단계가 낸 B_t 에 들어가지 않으면」** 이다 — 「어느 살아 있는 ref
# 에도 안 걸리면」이 아니다. 머지됐는데 ref 는 살아 있는(가장 흔한) 경로가 그 차이로
# 고아가 되어 AC4 가 깨진다.
ORPHANS=""
for c in $C; do
  in_bt=no
  for tip in $BR_TIPS; do
    git merge-base --is-ancestor "$c" "$tip" 2>/dev/null && { in_bt=yes; break; }
  done
  [ "$in_bt" = yes ] && continue
  m=$(git rev-list --ancestry-path --merges "$c..$BASE_REF" 2>/dev/null | tail -1)
  [ -n "$m" ] || { ORPHANS="$ORPHANS $c"; continue; }
  # 주제 쪽 부모 — `^2` 로 단정하지 않고 c 를 포함하는 부모를 고른다.
  side=""
  for p in $(git rev-list --parents -n 1 "$m" 2>/dev/null | cut -d' ' -f2-); do
    git merge-base --is-ancestor "$c" "$p" 2>/dev/null && { side="$p"; break; }
  done
  [ -n "$side" ] || { ORPHANS="$ORPHANS $c"; continue; }
  dup=no
  for t in $BR_TIPS; do [ "$t" = "$side" ] && { dup=yes; break; }; done
  [ "$dup" = yes ] && continue
  BR_NAMES="$BR_NAMES merged:$side"; BR_TIPS="$BR_TIPS $side"
  # 경계 계산이 쓸 mainline 부모를 짝지어 기억한다.
  MERGED_MAINLINE="${MERGED_MAINLINE:-} $side:$(git rev-parse "$m^1")"
done

# 1·2 가 둘 다 답을 못 낸 선언 커밋은 고아다 (설계 §6.2.2 3단계).
if [ -n "$ORPHANS" ]; then
  first=$(printf '%s' "$ORPHANS" | awk '{print $1}')
  emit declaration-invalid "orphan declaration commit (no containing branch, no merge): ${first:0:8}"
fi

BRANCHES=$(printf '%s\n' $BR_NAMES | sort -u | paste -sd, -)
[ -n "$BRANCHES" ] || BRANCHES="-"

# Task 3 이 boundary · tips · commits 를 채운다.
emit ok "-"
```

- [ ] **Step 4: 실행 권한을 주고 테스트가 통과하는지 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && chmod +x plugins/quality-gates/scripts/resolve-topic.sh && bash plugins/quality-gates/tests/test_topic_boundary.sh
```

Expected: PASS — 모든 `✓`, `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
git add plugins/quality-gates/scripts/resolve-topic.sh plugins/quality-gates/tests/test_topic_boundary.sh
git commit -q \
  -m "feat(qg): 선언에서 토픽 커밋 집합을 도출한다" \
  -m "Spec: 트레일러 질의와 B_t 도출 세 갈래. git branch --contains 를 쓰지 않고, 2단계 발동 조건은 「1단계가 낸 B_t 에 안 들어가면」이다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git log -n 1 --format='%h %s'
```

> **트레일러 둘은 «한» `-m` 안에 함께 넣는다.** `-m` 마다 문단이 갈라지는데 git 의 트레일러
> 파서는 **마지막 문단만** 본다 — 따로 넣으면 `Spec:` 이 트레일러로 파싱되지 않아
> `%(trailers:key=Spec,valueonly)` 가 빈 값을 낸다(Task 3 의 F7 검사가 그 필드를 쓴다).
> 모든 Task 의 커밋이 이 형태를 쓴다.

Expected: 커밋 해시와 제목 한 줄.

- [ ] **Step 6: 트레일러가 실제로 트레일러로 파싱되는지 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git log -n 1 --format='%(trailers:key=Spec,valueonly)'
```

Expected: `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1` 한 줄.
빈 출력이면 트레일러가 마지막 문단에 없는 것이다 — `git commit --amend` 로 고친다.
---

## Task 3: `resolve-topic.sh` — 경계 · 끝점 · 커밋 집합

**Files:**
- Modify: `plugins/quality-gates/scripts/resolve-topic.sh` (Task 2 가 만든 파일의 끝을 채운다)
- Modify: `plugins/quality-gates/tests/test_topic_boundary.sh` (F4 · F7 · F8 과 경계 단언을 더한다)

**Interfaces:**
- Consumes: Task 2 가 세운 `$BR_TIPS` · `$BR_NAMES` · `$BASE_REF` · `$C` · `$MERGED_MAINLINE`
  (`<side>:<mainline>` 공백 구분 짝). 이 이름들이 Task 2 와 Task 3 사이의 계약이다.
- Produces: `resolve` 의 `boundary:`(full SHA) · `tips:`(쉼표 구분 SHA, 정규화된 topo-order) ·
  `commits:`(정수). 새 서브커맨드 `commits <topic-key>` 가 `T` 의 SHA 를 한 줄에 하나씩 낸다
  (`status != ok` 이면 stdout 없이 **exit 3**). 새 옵션 `--seal <B>`.
  PR4 가 `tips:` 를 `combine-tips.sh` 의 인자로, `boundary:` 를 `create-baseline` 의 인자로 쓴다.

- [ ] **Step 1: 실패하는 테스트를 더한다 — F4 · F7 · F8 + 경계 단언**

`plugins/quality-gates/tests/test_topic_boundary.sh` 의 `for c in …` 루프 **앞**에 아래를 넣고,
루프의 이름 목록에 새 케이스 여섯을 더한다:

```bash
# ── F1 의 경계 (AC5) — 형제 둘의 fork 가 같으므로 경계 = 분기점 ─────────────
case_f1_boundary() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"
  git checkout -q topicA
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field boundary "$out")" "$R" "F1 경계 = 두 fork 의 merge-base = 분기점"
  assert_eq "$(field commits "$out")" "2" "F1 |T| = 2"
  cleanup
}

# ── F2 의 경계 (AC4+AC5) — 머지된 구성원이 경계 뒤로 숨으면 안 된다 ──────────
#    순진한 merge-base(base_ref, tip) 은 머지된 구성원에 대해 tip 자신을 돌려준다.
#    그러면 그 브랜치 전체가 경계 뒤로 숨어 seed 가 이름 붙인 결함이 재발한다.
case_f2_boundary_merged_not_hidden() {
  new_repo
  local FORKPT; FORKPT=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q main
  echo r2 >> f.txt; git commit -qam r2          # main 이 무관하게 앞으로 나간다
  git merge -q --no-ff -m "merge topicA" topicA
  git checkout -q -b topicB; decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field boundary "$out")" "$FORKPT" "F2 경계 = 앞 브랜치의 진짜 분기점"
  assert_not_contains "$(field boundary "$out")" "$TIPA" "F2 경계가 머지된 tip 이 아니다"
  cleanup
}

# ── F4: 선언 없는 조상 커밋도 브랜치 소속으로 들어온다 (§6.2.2) ─────────────
#    R→A→B 에서 B 에만 트레일러를 붙여도 A 가 T 에 들어야 한다. 안 그러면
#    A 의 회귀가 선재 결함으로 숨는다.
case_f4_undeclared_ancestor_included() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA
  echo a1 > a.txt; git add a.txt; git commit -qm "a1 (선언 없음)"
  decl_commit b.txt b1 "b1"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field boundary "$out")" "$R" "F4 경계 = 브랜치 분기점(선언 커밋이 아니다)"
  assert_eq "$(field commits "$out")" "2" "F4 선언 없는 조상 a1 도 T 에 든다"
  local cs; cs=$(bash "$RT" commits "$KEY")
  assert_eq "$(printf '%s\n' "$cs" | grep -c .)" "2" "F4 commits 서브커맨드도 2줄"
  cleanup
}

# ── F7: 토픽 커밋 집합이 서로 다른 토픽 키를 함께 담음 (AC16) ───────────────
case_f7_mixed_keys_in_T() {
  new_repo
  mkdir -p docs; : > docs/x-design.md; git add docs; git commit -qm docs
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  echo b1 > b.txt; git add b.txt
  git commit -qm "b1

Spec: docs/x-design.md#pr2"
  local out; out=$(bash "$RT" resolve "$KEY")
  assert_eq "$(field status "$out")" "declaration-invalid" "F7 한 집합에 두 토픽 키 → declaration-invalid"
  local rc; bash "$RT" commits "$KEY" >/dev/null 2>&1; rc=$?
  assert_eq "$rc" "3" "F7 status != ok 이면 commits 는 exit 3 (fail-closed)"
  cleanup
}

# ── F8: 끝점 = 봉인을 «먼저 넣고» 극대원소 (AC6) ────────────────────────────
#    스택 A→B 에서 현재 체크아웃이 A 면 tip(A) 는 tip(B) 의 조상이라 극대원소가
#    아니다 — 「끝점 중 현재 브랜치 것을 치환」할 자리가 없다. 봉인을 먼저 넣으면
#    그 자신이 극대원소로 선다.
case_f8_seal_first_then_maximal() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"
  local TIPA; TIPA=$(git rev-parse HEAD)
  git checkout -q -b topicB; decl_commit b.txt b1 "b1"
  local TIPB; TIPB=$(git rev-parse HEAD)
  git checkout -q topicA
  # 봉인 커밋을 손으로 만든다 — seal-worktree.sh 는 Task 4 다(이 Task 는 그것에 기대지 않는다).
  local SEAL; SEAL=$(git commit-tree "$TIPA^{tree}" -p "$TIPA" -m seal)

  local out0; out0=$(bash "$RT" resolve "$KEY")
  assert_not_contains "$(field tips "$out0")" "$TIPA" "F8 --seal 없으면 tip(A) 는 극대원소가 아니라 빠진다"
  assert_contains "$(field tips "$out0")" "$TIPB" "F8 tip(B) 는 끝점이다"

  local out1; out1=$(bash "$RT" resolve "$KEY" --seal "$SEAL")
  assert_contains "$(field tips "$out1")" "$SEAL" "F8 봉인을 먼저 넣으면 끝점에 든다"
  assert_not_contains "$(field tips "$out1")" "$TIPA" "F8 tip(A) 는 여전히 빠진다(조상이므로)"
  cleanup
}

# ── 끝점 순서 결정론: 발견 순서와 무관해야 한다 ─────────────────────────────
case_tips_order_deterministic() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b zzz "$R"; decl_commit z.txt z "z"
  git checkout -q -b aaa "$R"; decl_commit a.txt a "a"
  git checkout -q -b mmm "$R"; decl_commit m.txt m "m"
  local o1 o2
  o1=$(field tips "$(bash "$RT" resolve "$KEY")")
  o2=$(field tips "$(bash "$RT" resolve "$KEY")")
  assert_eq "$o1" "$o2" "tips 두 번 호출 동일"
  assert_eq "$(printf '%s' "$o1" | tr ',' '\n' | grep -c .)" "3" "끝점 3개"
  cleanup
}
```

루프를 이렇게 바꾼다:

```bash
for c in case_f1_two_siblings case_f1_boundary case_f2_merged_ref_alive \
         case_f2_boundary_merged_not_hidden case_f3_merged_ref_deleted \
         case_f4_undeclared_ancestor_included case_f5_fragment_discriminates \
         case_f6_path_absent case_f7_mixed_keys_in_T case_f8_seal_first_then_maximal \
         case_tips_order_deterministic case_no_declaration case_nine_keys_always; do
  echo "== $c"; $c
done
finish
```

- [ ] **Step 2: 돌려서 새 케이스가 실패하는지 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_topic_boundary.sh
```

Expected: Task 2 의 케이스는 `✓`, 새 케이스 여섯은 `✗` (`boundary`·`tips`·`commits` 가 `-` 이고
`commits` 서브커맨드가 없다).

- [ ] **Step 3: `--seal` 파싱을 인자 검사 자리에 더한다**

`resolve-topic.sh` 의 `[ -n "$TOPIC" ] || die "empty topic key"` **바로 아래**에 넣는다:

```bash
SEAL=""
if [ "${3:-}" = "--seal" ]; then
  SEAL="${4:-}"
  [ -n "$SEAL" ] || die "--seal needs a commit"
  git rev-parse --verify --quiet "$SEAL^{commit}" >/dev/null 2>&1 || die "not a commit: $SEAL"
elif [ -n "${3:-}" ]; then
  die "unknown option: $3"
fi
```

- [ ] **Step 4: 경계 · 끝점 · T 를 계산한다**

`resolve-topic.sh` 의 **마지막 두 줄**(`# Task 3 이 boundary · tips · commits 를 채운다.` 주석과
`emit ok "-"`)을 아래로 **교체**한다. 그 위의 `BRANCHES=…` 두 줄은 Task 2 것이 그대로 남는다 —
다시 쓰면 중복된다.

```bash
# ── 경계 = fork 들의 merge-base (§6.2.3 · AC5) ─────────────────────────────
# 머지된 구성원에는 merge-base(base_ref, tip) 을 쓸 수 없다 — 그것은 tip 자신을
# 돌려주고, 그러면 그 브랜치 전체가 경계 뒤로 숨는다〔실측 2〕. 대신 그 브랜치를
# 받아들인 머지 커밋의 mainline 부모와의 merge-base 가 진짜 분기점이다〔실측 3〕.
FORKS=""
for tip in $BR_TIPS; do
  ml=""
  for pair in ${MERGED_MAINLINE:-}; do
    case "$pair" in "$tip:"*) ml="${pair#*:}"; break ;; esac
  done
  if [ -n "$ml" ]; then
    f=$(git merge-base "$tip" "$ml" 2>/dev/null)
  else
    f=$(git merge-base "$BASE_REF" "$tip" 2>/dev/null)
  fi
  [ -n "$f" ] || emit base-unresolved "cannot compute fork for ${tip}"
  FORKS="$FORKS $f"
done
FORKS=$(printf '%s\n' $FORKS | sort -u | tr '\n' ' ')
set -- $FORKS
BOUNDARY="$1"; shift
for f in "$@"; do
  BOUNDARY=$(git merge-base "$BOUNDARY" "$f" 2>/dev/null) \
    || emit base-unresolved "merge-base of forks failed"
done
[ -n "$BOUNDARY" ] || emit base-unresolved "empty boundary"

# ── 끝점 = (tips ∪ {봉인}) 의 극대원소 (§6.2.4 · AC6) ──────────────────────
# 「치환」이 아니라 «먼저 넣고 계산»이다. 스택에서 현재 브랜치가 다른 구성원의
# 조상이면 치환할 자리가 없어 미커밋 변경이 조용히 사라진다〔실측 10〕.
CANDS=$(printf '%s\n' $BR_TIPS $SEAL | grep -v '^$' | sort -u)
MAXIMAL=""
for a in $CANDS; do
  is_anc=no
  for b in $CANDS; do
    [ "$a" = "$b" ] && continue
    git merge-base --is-ancestor "$a" "$b" 2>/dev/null && { is_anc=yes; break; }
  done
  [ "$is_anc" = no ] && MAXIMAL="$MAXIMAL $a"
done
[ -n "$MAXIMAL" ] || emit base-unresolved "no maximal endpoint"

# 순서 결정론 — **두 단계다.** `rev-list --topo-order --no-walk` 의 출력은 인자
# 순서에 의존하므로〔실측 8〕, 먼저 집합을 사전순으로 정규화한 뒤 topo-order 를
# 건다. 한 단계로 줄이면 발견 순서가 결과에 새어 들어가 결정론이 조용히 사라진다.
MAXIMAL=$(printf '%s\n' $MAXIMAL | sort -u | tr '\n' ' ')
TIPS=$(git rev-list --topo-order --no-walk $MAXIMAL 2>/dev/null | paste -sd, -)
[ -n "$TIPS" ] || TIPS="-"

# ── T = 끝점들에서 경계를 뺀 합집합 ────────────────────────────────────────
TSET=$(git rev-list --topo-order $MAXIMAL "^$BOUNDARY" 2>/dev/null)
NCOMMITS=$(printf '%s\n' "$TSET" | grep -c .)

# ── AC16 나머지 절반: T 가 서로 다른 토픽 키를 함께 담는가 ──────────────────
# 조상 전체가 아니라 **T 위에서** 센다 — 조상을 훑으면 main 에 이미 머지된 앞
# 토픽의 키까지 세어 거짓 양성이 난다.
nkeys=$(git log --format='%(trailers:key=Spec,valueonly)' $MAXIMAL "^$BOUNDARY" 2>/dev/null \
        | grep -v '^$' | sort -u | grep -c .)
if [ "$nkeys" -gt 1 ]; then
  emit declaration-invalid "topic commit set carries $nkeys distinct Spec keys"
fi

# ── commits 서브커맨드 ─────────────────────────────────────────────────────
if [ "$SUB" = "commits" ]; then
  printf '%s\n' "$TSET"
  exit 0
fi
emit ok "-"
```

- [ ] **Step 5: `commits` 의 fail-closed 경로를 `emit` 에 넣는다**

`emit()` 함수의 `exit 0` **앞**에 넣는다 — `status != ok` 로 끝나는 모든 경로가 여기를 지난다:

```bash
  if [ "$SUB" = "commits" ] && [ "$1" != "ok" ]; then
    echo "resolve-topic: status=$1 (${2:--}) — no commit set" >&2
    exit 3
  fi
```

> **exit 3 은 die 의 2 와 다른 코드다** — `qg-worktree.sh` 의 `create-sandbox` 가 kill switch 에
> 쓰는 것과 같은 관례다. 소비자가 「집합이 비었다」와 「스크립트가 깨졌다」를 갈라 읽는다.
> 침묵과 0 은 다른 사실이므로 stderr 로 사유를 낸다.

- [ ] **Step 6: 테스트가 통과하는지 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_topic_boundary.sh
```

Expected: PASS — 전부 `✓`, `Fail: 0`.

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
git add plugins/quality-gates/scripts/resolve-topic.sh plugins/quality-gates/tests/test_topic_boundary.sh
git commit -q \
  -m "feat(qg): 토픽의 경계와 끝점을 브랜치 분기점에서 도출한다" \
  -m "경계 = fork 들의 merge-base. 머지된 구성원은 merge-base(side, m^1) 로 진짜 분기점을 되찾는다. 끝점은 봉인을 먼저 넣고 계산한 극대원소이고, 순서는 집합을 사전순 정규화한 뒤 topo-order 를 걸어 발견 순서와 무관하다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git log -n 1 --format='%h %s'
```

---

## Task 4: `seal-worktree.sh` — 임시 인덱스 봉인

**Files:**
- Create: `plugins/quality-gates/scripts/seal-worktree.sh`
- Create: `plugins/quality-gates/tests/test_seal_no_side_effects.sh`

**Interfaces:**
- Consumes: 없음 (git 과 워킹트리만 읽는다). Task 2·3 의 스크립트를 부르지 않는다.
- Produces: `seal-worktree.sh seal <session-id>` → 봉인 커밋 SHA 한 줄(stdout). 실패는 exit 2.
  PR4 가 그 SHA 를 `resolve-topic.sh --seal <B>` 로 넘기고, 합친 트리를 `create-head` 로 넘긴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_seal_no_side_effects.sh`:

```bash
#!/usr/bin/env bash
# test_seal_no_side_effects.sh — scripts/seal-worktree.sh (설계 §6.4.1, AC14).
#
# 회귀 락의 핵심은 **봉인 트리에 임시 인덱스 파일이 없다** 이다 — 설계의 실측이
# 정확히 그 결함(인덱스를 리포 안 추적 자리에 두면 봉인 트리에 들어간다)을 잡았다.
# 위치가 아니라 **결과**를 잰다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SEAL="$PLUGIN_ROOT/scripts/seal-worktree.sh"
. "$(cd "$(dirname "$0")/../../.." && pwd)/shared/tests/assert.sh"

SID="deadbeefcafebabe"
REPO=""
cleanup() { cd / && rm -rf "$REPO"; }

mk_repo() {   # .gitignore 가 /.claude/* 를 덮는 정상 리포
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  printf '/.claude/*\n' > .gitignore
  echo tracked > a.txt
  echo doomed  > b.txt
  git add -A; git commit -qm base
}

case_seal_content() {
  mk_repo
  echo "uncommitted" >> a.txt          # 수정
  rm -f b.txt                          # 삭제
  echo "new" > c.txt                   # untracked (ignored 아님)
  mkdir -p .claude/quality-gates
  echo "ignored" > .claude/quality-gates/junk

  local B; B=$(bash "$SEAL" seal "$SID")
  if [ -z "$B" ]; then no "봉인 커밋이 안 나왔다"; cleanup; return; fi
  local names; names=$(git ls-tree -r --name-only "$B")

  assert_grep "$names" '^c\.txt$'        "untracked 파일이 봉인 트리에 든다"
  assert_not_grep "$names" '^b\.txt$'    "삭제가 봉인 트리에 반영된다"
  assert_not_grep "$names" '^\.claude/'  "git-ignored 자리는 봉인 트리에 없다"
  assert_grep "$(git show "$B:a.txt")" 'uncommitted' "미커밋 수정이 봉인 트리에 든다"
  cleanup
}

# ★ AC14 의 핵심 — 실측 결함의 회귀 락
case_no_index_in_tree() {
  mk_repo
  echo "x" >> a.txt
  local B; B=$(bash "$SEAL" seal "$SID")
  local names; names=$(git ls-tree -r --name-only "$B")
  assert_not_grep "$names" 'seal-.*\.index' "봉인 트리에 임시 인덱스 파일이 없다"
  assert_not_grep "$names" '\.lock$'        "봉인 트리에 인덱스 lock 파일이 없다"
  cleanup
}

case_no_side_effects() {
  mk_repo
  echo "x" >> a.txt; echo "y" > d.txt
  local head_before status_before wt_before
  head_before=$(git rev-parse HEAD)
  status_before=$(git status --porcelain | sort)
  wt_before=$(git worktree list | wc -l | tr -d ' ')

  bash "$SEAL" seal "$SID" >/dev/null

  assert_eq "$(git rev-parse HEAD)" "$head_before" "HEAD 불변"
  assert_eq "$(git status --porcelain | sort)" "$status_before" "인덱스·워킹트리 불변"
  assert_eq "$(git worktree list | wc -l | tr -d ' ')" "$wt_before" "추가 워크트리 0"
  cleanup
}

case_index_file_cleaned_up() {
  mk_repo
  echo "x" >> a.txt
  bash "$SEAL" seal "$SID" >/dev/null
  local left; left=$(find .claude -name 'seal-*' 2>/dev/null | grep -c .)
  assert_eq "$left" "0" "봉인 후 임시 인덱스 파일이 남지 않는다"
  cleanup
}

# ★ 양성 대조 — 인덱스 자리가 git-ignored 가 아니면 **죽어야** 한다(fail-closed).
#    이 케이스가 없으면 위의 부재 단언들은 「그냥 통과」할 수 있다.
case_fails_closed_when_not_ignored() {
  REPO=$(mktemp -d) || exit 1; cd "$REPO" || exit 1
  git init -q .
  git config user.email t@t.test; git config user.name tester
  git checkout -q -b main
  echo tracked > a.txt; git add -A; git commit -qm base    # .gitignore 없음
  local out rc
  out=$(bash "$SEAL" seal "$SID" 2>&1); rc=$?
  assert_eq "$rc" "2" "인덱스 자리가 ignored 가 아니면 exit 2"
  assert_grep "$out" 'git-ignored'    "사유가 메시지에 있다"
  cleanup
}

case_usage() {
  mk_repo
  local rc; bash "$SEAL" 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "인자 없이 부르면 exit 2"
  bash "$SEAL" seal "" 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "빈 session-id 는 exit 2"
  cleanup
}

for c in case_seal_content case_no_index_in_tree case_no_side_effects \
         case_index_file_cleaned_up case_fails_closed_when_not_ignored case_usage; do
  echo "== $c"; $c
done
finish
```

- [ ] **Step 2: 돌려서 실패를 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_seal_no_side_effects.sh
```

Expected: FAIL — 전부 `✗` (스크립트 부재).

- [ ] **Step 3: `seal-worktree.sh` 를 쓴다**

```bash
#!/usr/bin/env bash
# seal-worktree.sh — 워킹트리(수정 · 삭제 · untracked 반영)를 **워크트리 생성 없이**
#   커밋 하나로 봉인한다. (설계 2026-09-21 §6.4.1, AC14)
#
#   seal <session-id>   -> 봉인 커밋 SHA 한 줄 (stdout)
#
# `create-sandbox` 를 대체한다. 그것은 워크트리를 만들고 파일을 한 벌 복사한 뒤
# 커밋했다 — 여기서는 **임시 인덱스**로 같은 트리를 만든다. 워크트리도, 복사도 없다.
#
# **요건은 「리포 밖」이 아니라 「git 이 무시하는 자리」다.** 인덱스를 추적 대상 자리에
# 두면 `.qg-seal-index` 와 그 `.lock` 이 봉인 트리에 들어간다(설계 §7-I 의 실측 결함).
# 그래서 가드가 둘이다 — 봉인 «전» check-ignore, 봉인 «후» 트리 검사. 뒤의 것이
# 권위다: 위치가 아니라 결과를 잰다.
set -u

die() { echo "seal-worktree: $*" >&2; exit 2; }

[ "${1:-}" = "seal" ] || die "usage: seal-worktree.sh seal <session-id>"
sid="${2:-}"
sid_short="${sid:0:8}"
[ -n "$sid_short" ] || die "empty session-id"

main_root=$(git rev-parse --show-toplevel 2>/dev/null) || die "not a git repo"
main_root=$(cd "$main_root" && pwd -P) || die "cd failed: $main_root"

rel=".claude/quality-gates/seal-${sid_short}.index"
SEAL_INDEX="$main_root/$rel"
mkdir -p "$main_root/.claude/quality-gates" || die "cannot create .claude/quality-gates"

# 이른 가드 — 친절한 사유를 준다. 「git add -A」 가 이 자리를 집으면 AC14 가 깨진다.
git -C "$main_root" check-ignore -q "$rel" 2>/dev/null \
  || die "seal index path is not git-ignored: $rel — that path would be sealed into the tree (AC14). Add it to .gitignore."

rm -f "$SEAL_INDEX" "$SEAL_INDEX.lock"
trap 'rm -f "$SEAL_INDEX" "$SEAL_INDEX.lock"' EXIT

# `export` 가 load-bearing 이다 — 그냥 대입하면 아래 git 들이 **실제 인덱스**를 쓴다.
# 서브셸로 감싸 이 스크립트의 나머지 환경에 새지 않게 한다.
B=$(
  export GIT_INDEX_FILE="$SEAL_INDEX"
  cd "$main_root" || exit 1
  git read-tree HEAD || exit 1
  git add -A || exit 1
  TREE=$(git write-tree) || exit 1
  git -c user.email=qg-seal@devbrew.local \
      -c user.name='qg seal' \
      -c commit.gpgsign=false \
      commit-tree "$TREE" -p HEAD -m "qg: sealed" || exit 1
) || die "seal failed"
[ -n "$B" ] || die "seal produced no commit"

# 권위 있는 가드 — **결과**를 잰다.
if git -C "$main_root" ls-tree -r --name-only "$B" | grep -q "seal-${sid_short}\.index"; then
  die "sealed tree contains the temp index ($rel) — AC14 violation"
fi

printf '%s\n' "$B"
```

- [ ] **Step 4: 실행 권한을 주고 테스트가 통과하는지 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && chmod +x plugins/quality-gates/scripts/seal-worktree.sh && bash plugins/quality-gates/tests/test_seal_no_side_effects.sh
```

Expected: PASS — 전부 `✓`, `Fail: 0`.

- [ ] **Step 5: 실제 리포에서 한 번 돌려 본다 (Task 1 Step 5 의 짝)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && B=$(bash plugins/quality-gates/scripts/seal-worktree.sh seal probe0001) && echo "B=$B" && git ls-tree -r --name-only "$B" | grep -c 'seal-' && git status --porcelain && git worktree list
```

Expected: `B=<40자 SHA>` · `grep -c 'seal-'` 가 **0** · `git status --porcelain` 이 커밋 전과
같음 · `git worktree list` 가 이 워크트리 한 줄. 어느 하나라도 다르면 멈추고 보고한다.

- [ ] **Step 6: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
git add plugins/quality-gates/scripts/seal-worktree.sh plugins/quality-gates/tests/test_seal_no_side_effects.sh
git commit -q \
  -m "feat(qg): 워크트리 없이 워킹트리를 커밋 하나로 봉인한다" \
  -m "임시 인덱스(GIT_INDEX_FILE)로 read-tree · add -A · write-tree · commit-tree. 인덱스 자리는 git 이 무시하는 자리여야 하고, 가드는 봉인 전 check-ignore 와 봉인 후 트리 검사 둘이다 — 뒤의 것이 권위다(위치가 아니라 결과를 잰다)." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git log -n 1 --format='%h %s'
```

---

## Task 5: `combine-tips.sh` — 순차 `merge-tree`

**Files:**
- Create: `plugins/quality-gates/scripts/combine-tips.sh`
- Modify: `plugins/quality-gates/tests/test_topic_boundary.sh` (합치기 케이스 셋을 더한다)

**Interfaces:**
- Consumes: 끝점 SHA 들을 **인자로** 받는다 — `resolve-topic.sh` 의 `tips:` 를 쉼표에서 공백으로
  바꾼 것이 그 값이다(배선은 PR4). 스크립트끼리 부르지 않는다.
- Produces: 6키 — `tree:` · `status:`(`ok`\|`merge-conflict`\|`bad-input`) · `steps:` ·
  `intermediates:` · `conflicts:` · `failed_at:`. PR4 가 `tree:` 를 `create-head` 로,
  `intermediates:` 를 `qg-gc.py` 로, `status: merge-conflict` 를
  `not-certified (merge-conflict)` 로 옮긴다(AC7).

- [ ] **Step 1: 실패하는 테스트를 더한다**

`test_topic_boundary.sh` 의 상단 변수 자리에 `CT="$PLUGIN_ROOT/scripts/combine-tips.sh"` 를 더하고,
루프 앞에 아래 셋을 넣는다:

```bash
# ── 합치기 정상: 겹치지 않는 두 끝점 → 트리 하나 (AC6) ─────────────────────
case_combine_clean() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"; local TA; TA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit b.txt b1 "b1"; local TB; TB=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA" "$TB")
  assert_eq "$(field status "$out")" "ok" "합치기 정상 → status: ok"
  assert_eq "$(field steps "$out")" "1" "끝점 둘 → merge-tree 1회"
  assert_grep "$(field tree "$out")" '^[0-9a-f]{40}$' "트리 OID 한 개"
  # 합친 트리가 양쪽 파일을 다 갖는다
  local names; names=$(git ls-tree -r --name-only "$(field tree "$out")")
  assert_grep "$names" '^a\.txt$' "합친 트리에 a.txt"
  assert_grep "$names" '^b\.txt$' "합친 트리에 b.txt"
  assert_grep "$(field intermediates "$out")" '^[0-9a-f]{40}$' "중간 커밋 SHA 가 나온다"
  cleanup
}

# ── 합치기 충돌: status · 충돌 파일 · 귀속 (AC7) ────────────────────────────
case_combine_conflict() {
  new_repo
  local R; R=$(git rev-parse HEAD)
  git checkout -q -b topicA; decl_commit f.txt AAA "a"; local TA; TA=$(git rev-parse HEAD)
  git checkout -q -b topicB "$R"; decl_commit f.txt BBB "b"; local TB; TB=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA" "$TB")
  assert_eq "$(field status "$out")" "merge-conflict" "충돌 → status: merge-conflict"
  assert_eq "$(field tree "$out")" "-" "충돌이면 트리를 내지 않는다"
  assert_eq "$(field conflicts "$out")" "f.txt" "충돌 파일 목록"
  assert_eq "$(field failed_at "$out")" "$TB" "충돌을 일으킨 구성원이 귀속된다(순차의 이득)"
  cleanup
}

# ── 끝점 하나 · 나쁜 입력 ───────────────────────────────────────────────────
case_combine_edges() {
  new_repo
  git checkout -q -b topicA; decl_commit a.txt a1 "a1"; local TA; TA=$(git rev-parse HEAD)
  local out; out=$(bash "$CT" "$TA")
  assert_eq "$(field status "$out")" "ok" "끝점 하나도 정상"
  assert_eq "$(field steps "$out")" "0" "끝점 하나 → merge-tree 0회"
  assert_eq "$(field tree "$out")" "$(git rev-parse "$TA^{tree}")" "끝점 하나면 그 트리 그대로"
  assert_eq "$(field intermediates "$out")" "-" "중간 커밋 없음"

  local out2; out2=$(bash "$CT" "deadbeefdeadbeefdeadbeefdeadbeefdeadbeef")
  assert_eq "$(field status "$out2")" "bad-input" "없는 커밋 → bad-input"
  local out3; out3=$(bash "$CT")
  assert_eq "$(field status "$out3")" "bad-input" "인자 0 → bad-input"

  local n; n=$(printf '%s\n' "$out3" | grep -cE '^[a-z_]+:')
  assert_eq "$n" "6" "bad-input 에서도 6키 전부 emit"
  cleanup
}
```

루프 이름 목록 끝에 `case_combine_clean case_combine_conflict case_combine_edges` 를 더한다.

- [ ] **Step 2: 돌려서 새 케이스가 실패하는지 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | tail -25
```

Expected: 합치기 케이스 셋만 `✗`.

- [ ] **Step 3: `combine-tips.sh` 를 쓴다**

```bash
#!/usr/bin/env bash
# combine-tips.sh — 끝점들을 순차 `git merge-tree --write-tree` 로 합쳐 트리 하나를 낸다.
#   (설계 2026-09-21 §6.2.4, AC6·AC7)
#
#   combine-tips.sh <tip1> [<tip2> ...]   -> key: value 6줄
#
# **워크트리를 만들지 않는다.** octopus 를 쓰지 않는 이유는 둘이다(설계 §14):
# `git merge-tree` 는 두 갈래만 받으므로 octopus 는 실제 워크트리를 되살리고,
# octopus 는 한 파일에서 충돌하면 전체를 중단해 **어느 구성원 때문인지 안 알려준다**.
# 순차는 실패한 단계가 곧 그 구성원이라 `failed_at:` 에 귀속이 실린다.
#
# 순차의 대가는 `commit-tree` 중간 커밋이 unreachable 로 남는 것이고, 그것은 기존
# `qg-gc.py` 경로가 받는다 — `intermediates:` 로 넘긴다.
#
# **사실만 낸다** — `not-certified` 같은 판정 어휘는 이 층에 없다.
set -u

die() { echo "combine-tips: $*" >&2; exit 2; }

TREE="-"; STATUS="ok"; STEPS=0; INTERMEDIATES=""; CONFLICTS="-"; FAILED_AT="-"

emit() {
  echo "tree: $TREE"
  echo "status: $STATUS"
  echo "steps: $STEPS"
  echo "intermediates: ${INTERMEDIATES:--}"
  echo "conflicts: $CONFLICTS"
  echo "failed_at: $FAILED_AT"
  exit 0
}

[ $# -ge 1 ] || { STATUS="bad-input"; emit; }
for t in "$@"; do
  git rev-parse --verify --quiet "$t^{commit}" >/dev/null 2>&1 \
    || { STATUS="bad-input"; FAILED_AT="$t"; TREE="-"; emit; }
done

acc="$1"; shift
TREE=$(git rev-parse "$acc^{tree}" 2>/dev/null) || die "cannot read tree of $acc"

for tip in "$@"; do
  # 〔실측 6〕충돌 정보는 **stdout** 에 있고 stderr 는 0바이트다. 1줄이 트리 OID,
  # 그다음이 `<mode> <oid> <stage>\t<path>` 스테이지 줄이다. 그래서 stdout 만 잡는다.
  out=$(git merge-tree --write-tree "$acc" "$tip" 2>/dev/null); rc=$?
  STEPS=$((STEPS+1))
  if [ "$rc" -ne 0 ]; then
    STATUS="merge-conflict"
    FAILED_AT="$tip"
    TREE="-"
    CONFLICTS=$(printf '%s\n' "$out" \
      | awk -F'\t' 'NF==2 && $1 ~ /^[0-7]{6} [0-9a-f]+ [123]$/ { print $2 }' \
      | sort -u | paste -sd, -)
    [ -n "$CONFLICTS" ] || CONFLICTS="-"
    emit
  fi
  tree=$(printf '%s\n' "$out" | head -1)
  case "$tree" in
    [0-9a-f]*) ;;
    *) die "merge-tree gave no tree OID: $(printf '%s' "$out" | head -c 120)" ;;
  esac
  acc=$(git -c user.email=qg-seal@devbrew.local \
            -c user.name='qg seal' \
            -c commit.gpgsign=false \
            commit-tree "$tree" -p "$acc" -p "$tip" -m "qg: combine step $STEPS") \
    || die "commit-tree failed at step $STEPS"
  INTERMEDIATES="${INTERMEDIATES:+$INTERMEDIATES,}$acc"
  TREE="$tree"
done

emit
```

> **알려진 한계(주석으로 스크립트에 남긴다)** — 충돌 파일 경로에 탭이나 개행이 들어 있으면
> 스테이지 줄 파싱이 어긋난다. 공백은 안전하다(탭 구분이다). git 이 그런 경로를 따옴표로
> 감싸므로 소실이 아니라 표기 문제다.

- [ ] **Step 4: 실행 권한을 주고 테스트가 통과하는지 본다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && chmod +x plugins/quality-gates/scripts/combine-tips.sh && bash plugins/quality-gates/tests/test_topic_boundary.sh
```

Expected: PASS — 전부 `✓`, `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
git add plugins/quality-gates/scripts/combine-tips.sh plugins/quality-gates/tests/test_topic_boundary.sh
git commit -q \
  -m "feat(qg): 끝점들을 순차 merge-tree 로 한 트리에 합친다" \
  -m "충돌은 rc 1 이고 정보는 stdout 에 있다 — 스테이지 줄에서 충돌 파일을 뽑고, 실패한 단계가 곧 그 구성원이라 failed_at 에 귀속이 실린다. 중간 커밋은 intermediates 로 내 기존 GC 경로가 받는다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git log -n 1 --format='%h %s'
```

---

## Task 6: mutation 네 축 + 양성 대조

설계 §13: *"새 락 전부를 네 축으로 흔든다: **삭제 · 변형 · 추가 · 불일치**. 각 축에 **양성 대조**를
둔다(green-expected 단언은 모양으로 이빨을 판별할 수 없다)."*

**Files:**
- Modify: 없음 (변이는 전부 되돌린다)
- Create: `$CLAUDE_JOB_DIR/tmp/pr1-mutations.txt` — 변이별 기대/관측 기록

**Interfaces:**
- Consumes: Task 2–5 가 커밋한 스크립트 셋과 락 둘
- Produces: 「이 락들이 실제로 이빨을 가졌다」의 증거. Task 7 의 PR 본문이 이 표를 싣는다.

> **변이 전에 반드시 커밋돼 있어야 한다.** 복원은 `git checkout HEAD -- <파일>` 로 하고,
> `git checkout -- <파일>`(index 로 복원)은 쓰지 않는다. 매 복원 뒤 `git diff HEAD` 가 비었는지
> 확인한다 — 복원이 안 되면 다음 변이의 관측이 오염된다.

- [ ] **Step 1: 변이 전 GREEN 을 확인한다 (기준선)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git status --porcelain && bash plugins/quality-gates/tests/test_topic_boundary.sh | tail -1 && bash plugins/quality-gates/tests/test_seal_no_side_effects.sh | tail -1
```

Expected: `git status` 빈 출력 · 두 락 다 `Fail: 0`. 여기가 GREEN 이 아니면 변이를 시작하지
않는다 — RED 위에서 변이하면 무엇이 무엇을 잡았는지 가릴 수 없다.

- [ ] **Step 2: M1 (변형) — 경계 규칙을 옛 규칙으로 되돌린다**

`resolve-topic.sh` 의 fork 계산 블록에서 머지된 구성원 분기를 지우고 언제나
`git merge-base "$BASE_REF" "$tip"` 을 쓰게 바꾼다 (`if [ -n "$ml" ]; then … else … fi` 를
`f=$(git merge-base "$BASE_REF" "$tip" 2>/dev/null)` 한 줄로).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_topic_boundary.sh 2>&1 | grep -E '✗|Fail:' | head
```

Expected: **RED** — 최소 `F2 경계 = 앞 브랜치의 진짜 분기점` 이 `✗`. 복원:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git checkout HEAD -- plugins/quality-gates/scripts/resolve-topic.sh && git diff HEAD --stat
```

- [ ] **Step 3: M2 (삭제) — `B_t` 2단계를 통째로 지운다**

`# ── B_t 2단계: 머지된 구성원 ──` 부터 `if [ -n "$ORPHANS" ]; then … fi` 까지를 지운다.

Expected: **RED** — `F2 …`, `F3 ref 삭제된 구성원을 merged: 로 받는다` 가 `✗`. 복원 후
`git diff HEAD --stat` 이 비었는지 확인.

- [ ] **Step 4: M3 (변형) — 2단계 발동 조건을 「살아 있는 ref 에 안 걸리면」으로 되돌린다**

`in_bt` 판정을 `$BR_TIPS`(1단계 결과) 대신 **모든** `refs/heads` 의 tip 에 대해 돌게 바꾼다.

```bash
# 바꿀 자리: for tip in $BR_TIPS; do   →   for tip in $(git for-each-ref --format='%(objectname)' refs/heads); do
```

Expected: **RED** — `F2 status: ok` 가 `✗` 이고 `declaration-invalid`(고아)로 떨어진다.

> **이 변이가 라운드 2 재비판이 잡은 회귀의 회귀 락이다.** 머지됐는데 ref 는 살아 있는(가장 흔한)
> 경로가 정확히 여기서 고아가 된다. 이 변이가 RED 를 안 내면 F2 가 그 결함을 못 잡는 것이다.

- [ ] **Step 5: M4 (변형) — 토픽 질의가 조각을 무시하게 만든다**

`--grep="^Spec: ${esc}\$"` 의 끝 `\$` 를 지운다(접두 일치가 된다).

Expected: **RED** — `F5 #pr1 질의가 #pr2 를 매치하지 않는다` 가 `✗`(2 를 낸다).

> 이것이 D1.4 의 회귀 락이다 — 조각이 선택자가 아니게 되면 다섯 PR 이 한 토픽으로 합쳐진다.

- [ ] **Step 6: M5 (삭제) — 봉인 후 트리 검사를 지운다 + 인덱스를 추적 자리로 옮긴다**

`seal-worktree.sh` 에서 ⑴ `check-ignore` 가드 ⑵ 봉인 후 `ls-tree` 검사를 **둘 다** 지우고,
`rel` 을 `.qg-seal-${sid_short}.index`(리포 루트, 무시되지 않는 자리)로 바꾼다.

Expected: **RED** — `봉인 트리에 임시 인덱스 파일이 없다` 와 `인덱스 자리가 ignored 가 아니면
exit 2` 가 `✗`.

- [ ] **Step 7: M6 (변형) — 끝점을 「치환」으로 되돌린다**

극대원소 블록을 「`$SEAL` 이 있으면 `$BR_TIPS` 중 현재 HEAD 의 것을 `$SEAL` 로 바꾼다」로
교체한다(설계가 기각한 형태).

Expected: **RED** — `F8 봉인을 먼저 넣으면 끝점에 든다` 가 `✗` (현재 브랜치 tip 이 다른
구성원의 조상이라 치환할 자리가 없어 `$SEAL` 이 어디에도 안 들어간다).

- [ ] **Step 8: M7 (추가) — 선언 없는 브랜치를 하나 더한다 · GREEN 이 기대값**

`test_topic_boundary.sh` 의 `case_f1_two_siblings` 에 선언 없는 브랜치 하나를 더한다:

```bash
  git checkout -q -b noise "$R"; echo n > n.txt; git add n.txt; git commit -qm "noise (선언 없음)"
  git checkout -q topicA
```

Expected: **GREEN 유지** — `branches` 가 여전히 2개다. RED 가 나면 스크립트가 선언과 무관한
브랜치를 빨아들이는 것이다. **이 변이는 되돌리지 않고 락에 남긴다** — 음의 방향(「안 들어와야
한다」)을 재는 양의 짝이다.

- [ ] **Step 9: M8 (불일치) — 브랜치 발견 순서를 뒤집는다 · GREEN 이 기대값**

`resolve-topic.sh` 의 1단계 루프를 `for ref in $(git for-each-ref … refs/heads | sort -r); do` 로
바꾼다.

Expected: **GREEN 유지** — `case_tips_order_deterministic` 이 통과한다(집합을 사전순 정규화한 뒤
topo-order 를 걸기 때문이다). **RED 가 나면 결정론이 발견 순서에 의존하는 것이다** — 실측 8 이
경고한 바로 그 경로다. 확인 후 복원한다.

- [ ] **Step 10: 변이 기록을 남긴다**

`$CLAUDE_JOB_DIR/tmp/pr1-mutations.txt` 에 축 · 변이 · 기대 · 관측을 표로 적는다:

```
축      변이                                   기대    관측
변형    M1 경계를 merge-base(base,tip) 으로    RED     <채운다>
삭제    M2 B_t 2단계 제거                      RED     <채운다>
변형    M3 2단계 조건을 살아있는-ref 로        RED     <채운다>
변형    M4 질의에서 끝 앵커 제거               RED     <채운다>
삭제    M5 봉인 가드 둘 제거 + 추적 자리       RED     <채운다>
변형    M6 끝점을 치환으로                     RED     <채운다>
추가    M7 선언 없는 브랜치 추가               GREEN   <채운다>
불일치  M8 브랜치 발견 순서 역순               GREEN   <채운다>
```

- [ ] **Step 11: 전부 복원됐는지 확인하고 M7 만 커밋한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git diff HEAD --stat && bash plugins/quality-gates/tests/test_topic_boundary.sh | tail -1 && bash plugins/quality-gates/tests/test_seal_no_side_effects.sh | tail -1
```

Expected: `git diff HEAD --stat` 이 **`test_topic_boundary.sh` 한 파일만**(M7) · 두 락 다
`Fail: 0`. 스크립트 셋에 변이가 남아 있으면 복원이 덜 된 것이다.

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
git add plugins/quality-gates/tests/test_topic_boundary.sh
git commit -q \
  -m "test(qg): 선언 없는 브랜치가 토픽에 안 들어오는지 재는 양의 짝" \
  -m "부재 단언만 있으면 통째로 지워도 통과한다. 선언 없는 브랜치를 실제로 하나 더해 branches 가 2 로 남는 것을 잰다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 회귀 스위트 · bump · CHANGELOG · PR

**Files:**
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json`
- Modify: `plugins/quality-gates/CHANGELOG.md`

**Interfaces:**
- Consumes: Task 1 의 `pr1-baseline.txt`, Task 6 의 `pr1-mutations.txt`
- Produces: 머지 가능한 PR. PR2 가 이 브랜치의 산출물(스크립트 셋 · 락 둘) 위에서 시작한다.

- [ ] **Step 1: 회귀 스위트 전량을 돌리고 baseline 과 대조한다**

`$CLAUDE_JOB_DIR/tmp/pr1_after.sh` 로 저장해 돌린다 (Task 1 Step 3 과 같은 형태, 출력만 다르다):

```bash
#!/usr/bin/env bash
set -u
W=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
BEFORE="${CLAUDE_JOB_DIR:?}/tmp/pr1-baseline.txt"
AFTER="${CLAUDE_JOB_DIR:?}/tmp/pr1-after.txt"
cd "$W" || exit 1
: > "$AFTER"
for t in plugins/quality-gates/tests/test_*.sh shared/tests/test_*.sh plugins/spec-distill/tests/test_*.sh; do
  [ -f "$t" ] || continue
  o=$(bash "$t" 2>&1); rc=$?
  fails=$(printf '%s\n' "$o" | grep -c '✗')
  printf '%s\trc=%s\tfail_lines=%s\n' "$t" "$rc" "$fails" >> "$AFTER"
done
echo "=== 새로 RED 가 된 파일 (내가 만든 회귀) ==="
join -t"$(printf '\t')" -j1 -o 0,1.2,1.3,2.2,2.3 \
  <(sort "$BEFORE") <(sort "$AFTER") 2>/dev/null \
  | awk -F'\t' '$2 != $4 || $3 != $5 { print "  " $0 }'
echo "=== 새 파일(baseline 에 없던 것) ==="
comm -13 <(cut -f1 "$BEFORE" | sort) <(cut -f1 "$AFTER" | sort) | sed 's/^/  /'
```

Expected: 「새로 RED」가 **비어 있다**. 새 파일은 `test_topic_boundary.sh` 와
`test_seal_no_side_effects.sh` 둘뿐이고 둘 다 `rc=0`.

> **`fail_lines` 까지 비교하는 것이 load-bearing 이다** — 이미 RED 인 파일 «안»의 새 실패는 rc
> 만으로는 원리적으로 안 보인다. `fail_lines` 가 늘었는데 rc 가 그대로면 그것도 내 회귀다.

- [ ] **Step 2: `# guards:` 선언이 공허해지지 않았는지 확인한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | tail -3
```

Expected: `Fail: 0`. 이 PR 은 `# guards:` 를 **선언하지 않으므로**(→ D-4) 이 락의 대상 집합이
움직이지 않는다. RED 가 나면 새 락에 `# guards:` 가 실수로 들어간 것이다.

- [ ] **Step 3: 세 스크립트가 아무도 부르지 않는지 확인한다 (G-C2)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && grep -rn 'resolve-topic\.sh\|seal-worktree\.sh\|combine-tips\.sh' plugins shared .claude-plugin CLAUDE.md docs 2>/dev/null | grep -v '^docs/superpowers/' | grep -v '/tests/'
```

Expected: **히트는 스크립트 파일 자신뿐**(`plugins/quality-gates/scripts/<그 파일>`). 다른
히트가 있으면 이 PR 이 배선을 했다는 뜻이고 그것은 PR4 의 일이다 — 멈추고 보고한다.

- [ ] **Step 4: `plugin.json` 을 bump 한다**

`plugins/quality-gates/.claude-plugin/plugin.json` 의 `"version": "7.6.2"` 를 `"7.7.0"` 로
바꾼다. **`description` 은 건드리지 않는다** — 「2-gate」 문자열 이동은 PR5 다(§6.5.1 의 10·11번).

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && grep -n '"version"' plugins/quality-gates/.claude-plugin/plugin.json
```

Expected: `"version": "7.7.0"`.

- [ ] **Step 5: CHANGELOG 항목을 쓴다**

`plugins/quality-gates/CHANGELOG.md` 의 `## [7.6.2] — 2026-09-19` **바로 위**에 넣는다:

```markdown
## [7.7.0] — 2026-09-22

### Added

- **선언(`Spec:` 커밋 트레일러)에서 리뷰 스코프를 도출하는 스크립트 셋.** `scripts/resolve-topic.sh` 가 트레일러 값(조각 포함)으로 선언 커밋을 찾아 그것을 담은 브랜치 집합을 도출하고, 경계(= 각 브랜치 분기점들의 merge-base)와 끝점(= 극대원소)과 토픽 커밋 집합을 낸다. `scripts/seal-worktree.sh` 가 임시 인덱스로 워킹트리를 커밋 하나에 봉인하고, `scripts/combine-tips.sh` 가 끝점들을 순차 `git merge-tree --write-tree` 로 합쳐 트리 하나를 낸다. **셋 다 워크트리를 만들지 않고 리포 상태를 바꾸지 않는다.**
- **`tests/test_topic_boundary.sh` · `tests/test_seal_no_side_effects.sh`.** 합성 토픽 픽스처 위에서 경계·끝점·봉인을 재는 회귀 락 둘. 봉인 락의 핵심 단언은 「봉인 트리에 임시 인덱스 파일이 없다」 — 위치가 아니라 결과를 잰다.

**호출자는 아직 0 이다.** 이 릴리스는 기계만 들여놓고 `/qg` 의 동작은 바꾸지 않는다 — 배선은 뒤 릴리스다. `git branch --contains` 를 쓰지 않는 이유(머지된 커밋에 대해 `main` 과 후손 전부를 돌려줘 끝점을 식별할 수 없다)와 머지된 구성원의 분기점을 `merge-base(주제쪽 부모, 머지의 mainline 부모)` 로 되찾는 이유는 설계문서 §6.2 에 있다.
```

- [ ] **Step 6: CHANGELOG 락을 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && bash shared/tests/test_changelog_integrity.sh | tail -3 && python3 plugins/quality-gates/scripts/check-changelog-korean-primary.py plugins/quality-gates/CHANGELOG.md; echo "rc=$?"
```

Expected: 둘 다 통과. 실패하면 문면을 고친다(형식 문제이지 설계 문제가 아니다).

- [ ] **Step 7: bump 와 CHANGELOG 를 커밋한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope
git add plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -q \
  -m "chore(qg): 7.7.0 — 스코프 기계 신설" \
  -m "새 표면만 더하고 breaking 은 없다. 번호는 머지 직전에 재확인한다." \
  -m "Spec: docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md#pr1
Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>"
git log --oneline -6
```

- [ ] **Step 8: 계획 문서가 이미 커밋돼 있는지 확인한다**

이 계획 문서는 작성 시점에 이미 커밋됐다(`docs(plan): qg 스코프 기계 (PR1) 구현 계획`). 확인만
한다:

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git log --oneline -- docs/superpowers/plans/2026-09-22-qg-scope-machine-pr1.md | head -3
```

Expected: 커밋 한 줄 이상. 실행 중에 계획을 고쳤으면 그 수정을 별도 커밋으로 남긴다 — 계획과
구현이 어긋난 채 머지되면 다음 PR 의 계획이 틀린 전제 위에 선다.

- [ ] **Step 9: 구현 리뷰를 받는다**

`/qg` 를 돌리거나 `pr-review-toolkit:code-reviewer` 를 디스패치해 이 브랜치의 diff 를 리뷰받는다.
**리뷰어에게 절대경로를 못 박는다** — 워크트리 세션에서 리뷰어가 메인 체크아웃의 동명 파일을
보면 엉뚱한 것을 읽는다:

> 리뷰 대상은 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope`
> 의 `origin/main..HEAD` 다. 설계문서는 같은 워크트리의
> `docs/superpowers/specs/2026-09-21-qg-target-derived-judgment-design.md` §6.2 · §6.4.1 · §11.
> 특히 봐 달라: ⑴ `B_t` 2단계 발동 조건이 「1단계가 낸 집합에 안 들어가면」인가 ⑵ 머지된
> 구성원의 fork 가 `merge-base(주제쪽, mainline)` 인가 ⑶ 봉인이 리포 상태를 정말 안 바꾸는가
> ⑷ 세 스크립트가 판정 어휘(`clean`/`defect`/`not-certified`)를 쓰지 않는가.

- [ ] **Step 10: push 하고 PR 을 연다**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/qg-review-only-sdd-scope && git push -u origin feature/qg-review-only-sdd-scope
```

PR 본문에 싣는 것:

- 이 PR 이 지는 AC 여덟(AC3·AC4·AC5·AC6·AC7·AC14·AC15 부분·AC16 부분)과 각각의 락
- **「호출자 0 · 기존 동작 영향 0」** — 이 PR 의 판정 기준
- Task 6 의 변이 표 (여덟 축 · 기대 · 관측)
- Task 1 이 잰 §7-E·§7-I 재검증 결과
- 설계가 남긴 빈칸 중 이 계획이 채운 것: 머지된 구성원의 fork 규칙 · 끝점 순서의 두 단계 정규화
  · `status` → 판정 어휘 매핑 · `--seal` 의 소유자
- 끝에 `🤖 Generated with [Claude Code](https://claude.com/claude-code)`

- [ ] **Step 11: 머지는 사용자가 한다**

`gh pr merge` 는 auto-mode 판정기가 막는다. 사용자에게 `! gh pr merge <번호> --merge` 를
그대로 보이고, 머지 직전에 **버전 번호를 재확인**한다(먼저 머지되는 쪽이 이긴다).
머지 뒤 `MERGED` 를 직접 확인한다.

---

## 실패 시 되돌리기

- **Task 2–5 중 어느 Step 이 실패하면** 그 Task 의 파일만 `git checkout HEAD -- <파일>` 로
  되돌린다. 커밋된 Task 는 건드리지 않는다 — 각 Task 가 독립적으로 GREEN 이다.
- **Task 1 Step 4 의 경계 재검증이 모양부터 틀리면** 멈추고 사용자에게 보고한다. 설계 §6.2.3 의
  재결정 사안이지 구현으로 덮을 문제가 아니다(P23 — 근거 있는 재결정은 사용자 동의로).
- **Task 1 Step 5 의 `check-ignore` 가 rc 1 이면** 멈춘다. 그 상태로 봉인하면 AC14 가 깨진다.
- **회귀 스위트에 새 RED 가 생기면** 그 락이 무엇을 재는지 먼저 읽는다. 이 PR 은 기존 파일을
  거의 안 건드리므로, 새 RED 는 대개 ⑴ `# guards:` 코퍼스가 움직였거나 ⑵ CHANGELOG·버전 형식
  이거나 ⑶ 선재 RED 를 baseline 에 안 넣은 것이다.
- **브랜치 전체를 버려야 하면** `git reset --hard origin/main` 전에
  `git merge-base --is-ancestor HEAD origin/main` 으로 손실 여부를 확인한다. 로컬 `main` 기준
  비교는 오판한다.

---

## Self-Review 기록

계획을 다 쓴 뒤 설계와 대조해 고친 것:

1. **F7(한 브랜치에 여러 토픽 키)을 Task 2 → Task 3 으로 옮겼다.** Task 2 의 초안은 선언 커밋의
   **조상 전체**를 훑었는데, 그러면 `main` 에 이미 머지된 앞 토픽의 키까지 세어 거짓 양성이 난다.
   그 검사는 `T` 가 있어야 하므로 경계를 계산하는 Task 3 의 것이다.
2. **끝점 순서의 결정론을 두 단계로 나눴다.** `rev-list --topo-order --no-walk` 가 인자 순서에
   의존한다는 것을 실측으로 확인했다(실측 8). 설계의 「topo-order 로 고정」한 줄만 보고 구현하면
   발견 순서가 결과에 새어 든다 — 사전순 정규화를 앞에 둔다.
3. **머지된 구성원의 fork 규칙을 명령 형태로 확정했다.** 설계 §6.2.3 은 「주제 쪽 첫 커밋의
   부모」라고만 적었다. `merge-base(side, m^1)` 로 확정하고 실측으로 맞음을 봤다(실측 3).
   그리고 `^2` 를 주제 쪽으로 단정하지 않고 「`c` 를 포함하는 부모」로 고른다.
4. **`--seal` 의 소유자를 `resolve-topic.sh` 로 정했다.** 끝점 도출이 그 스크립트의 책임이고,
   스크립트끼리 부르지 않는다는 구조를 지키려면 `B` 는 인자로 들어와야 한다.
5. **`commits` 서브커맨드를 fail-closed(exit 3)로 만들었다.** `status != ok` 인데 빈 stdout 을
   내면 소비자가 「집합이 비었다」로 읽는다 — 침묵과 0 은 다른 사실이다.
6. **커밋 트레일러를 한 `-m` 안에 넣게 고쳤다.** `-m` 마다 문단이 갈리는데 git 의 트레일러
   파서는 마지막 문단만 본다. 따로 넣으면 이 PR 자신의 `Spec:` 이 트레일러로 파싱되지 않아,
   이 PR 이 만드는 바로 그 기계가 자기 커밋을 못 읽는다.
7. **AC21 을 「해당 없음」으로 명시했다.** 이 PR 은 테스트를 하나도 지우지 않는다. 대신 새 락이
   `# guards:` 를 선언하지 **않는** 근거를 리포 선례로 적었다(D-4).

**남는 불확실 둘** — 설계 §15 의 한계이지 이 계획이 덮을 것이 아니다:

- **§15-2** 토픽 중간에 `main` 병합이 끼면 그 병합이 가져온 남의 커밋이 `T` 에 든다. 실측 4 가
  실물을 보였다(|T|=4 에 무관한 커밋 하나). 공시하되 막지 않는 것이 설계의 결정이다.
- **§15-10** 「기준선이 뒤로 밀려 실행 불가가 기본 경로가 될 수 있다」는 아직 라벨만 있다.
  **PR1 에서는 재지 못한다** — 기준선 축을 실제로 세우는 것은 PR4 의 배선 뒤다. 설계는 「구현
  계획이 실측으로 빈도를 먼저 재고 그때 고른다」고 적었으므로, 그 측정은 **PR4 의 계획**이
  지어야 한다. PR4 계획을 쓸 때 이 항목을 Task 로 세울 것.
