# R3 — 지휘자 경유 입구 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지휘자가 네 자리(spec 승인 앞 · 에픽 머지 뒤 · 로드맵 끝 · 이름으로 청함)에서 담당자를 시켜 qg 를 `range <시작>..<끝> --origin <원문>` 한 꼴로 부르고, 돌아온 `intent-critic` 질문을 게이트 사이에 사용자에게 옮겨 묻고, 질문과 답을 로드맵 폴더 `reviews/` 의 기록 파일로 남기게 한다. qg 는 범위로 부른 리뷰가 바뀐 의도 문서의 머리 줄을 따라가게 한 곳만 고친다.

**Architecture:** 절차는 새 파일 하나(`plugins/spec-distill/skills/epic-conductor/references/qg-review.md`)에 두고 `conducting.md` 에는 그 파일로 들어가는 문장만 둔다. 에픽 머지 뒤의 범위는 새 읽기 전용 스크립트(`plugins/spec-distill/scripts/merged_pr_range.py`)가 머지 방식별로 확인해 낸다. qg 쪽은 `intent_origin.review_breadth` 의 범위 모드 갈래가 바뀐 의도 문서 목록을 내게만 고친다 — 그 목록을 따라가는 길(`build_origin` · `_follow_changed` · `_follow_roadmaps`)은 이미 있다.

**Tech Stack:** Python 3(레포의 `python3` 는 3.9.6 — 3.9 문법만) · git · bash(macOS 3.2 호환) · unittest · 셸 문서 락(`shared/tests/assert.sh`).

**Spec:** `docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다. 설계문서 본문(`## 결정 기록` · `## 지휘 기록` 포함)은 고치지 않는다 — `## 미룸` 표에 행을 더하는 것만 끝 과제에서 한다.

## Global Constraints

- 경로 예약: `plugins/spec-distill/references/conducting.md` · `plugins/spec-distill/skills/epic-conductor/` · `plugins/quality-gates/scripts/setup-qg.sh` · `plugins/quality-gates/scripts/intent_origin.py` · `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(뒤 둘은 로드맵 수정 PR #308 로 더하는 중). 새 파일(`qg-review.md` · `merged_pr_range.py` · 테스트), 테스트 · `plugin.json` · `CHANGELOG.md` · `README.md` · `dependencies.md` · `shared/tests/fixtures/ask-sites.tsv` 는 쓴다. **그 밖의 있는 파일을 고쳐야만 AC 를 채울 수 있으면 고치지 말고 멈춰 지휘자에게 보고한다(재분해 신호).**
- 고치지 않음(설계문서 `## Files to Modify`): qg 본문(`SKILL.md`) · `intent_critic.py` · `intent_answers.py` · `other_teams.py` · 리뷰어 정의 · `conductor-dispatch.md` · `roadmap_status.py` · `conductor_ledger.py` · `conductor_state.py` · spec 리뷰 skill · `request-framing` skill.
- `conducting.md` 에는 들어가는 문장만 둔다 — 절차를 풀어 쓰지 않는다.
- 플러그인 경계: spec-distill 은 qg 스크립트를 부르지 않는다. 접점은 skill 호출 한 줄 · `intent-return.md`(계약 2판) · 그 파일이 가리키는 다른 팀 기록.
- 끄기 변수를 새로 두지 않는다. 지출 승인을 묻지 않는다 — 보내기 전에 규모를 한 줄로 알린다.
- 레포 전용 값을 박지 않는다 — 기본 브랜치는 `origin/HEAD`, 묶음 · 인터뷰 문서 경로는 로드맵에서 읽는다. 담당자의 모델 이름을 적지 않는다(보낼 때 역할을 보고 고르고 이유를 한 줄로 알린다). `test_repo_literals.sh` 의 규칙(기본 브랜치 이름 · `feature/`·`fix/` 접두 · `docs/superpowers` 같은 레포 구조 경로 · 모델 이름)을 새 파일도 지킨다.
- 옛 형식 로드맵만 다룬다.
- 판: spec-distill minor · quality-gates minor. 번호는 **구현을 시작할 때의 origin/main 판 위 minor** 로 적고, 머지 직전에 지휘자가 다시 정한다.
- 커밋: Conventional Commits, `type`·`scope` 는 영어 · 설명은 한국어. pathspec 커밋. 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md`.
- 새 셸 테스트는 실행 비트를 준다 — `git ls-files -s <파일>` 이 `100755` 인지 확인한다.
- 레포 락(새 스크립트 · 테스트): `plugins/*/scripts/*.py` 의 `open(` · `.read_text(` 에 `encoding` · `.py` 안 `"python3"` 리터럴 금지 · scripts 의 `re.compile` 리터럴이 `"## 6. 사용자 원문"` 앞머리와 3글자 이상 맞으면 안 된다(헤딩은 문자열 메서드로) · 같은 20줄 블록을 두 파일에 두지 않는다 · CHANGELOG 새 머리는 바로 다음 판이고 `plugin.json` 과 같다.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 를 뒤로 옮기기(reset · rebase · force).
- 임시 폴더: 지휘자가 준 `TMPDIR` 에 셸로 쓴다(격리 worktree 에서는 Write · Edit 도구가 막힌다). 셸로도 막히면 자기 worktree 안 `git check-ignore -q <자리>` 로 무시되는 자리를 쓰고 그 경로를 보고에 적는다.
- **전체 스위트는 공유 잠금 아래서만 돌린다:** `python3 "<SD>"/scripts/suite_lock.py run --lock <지휘자가 주는 스위트 잠금 경로> --owner <agent 이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'`(`<SD>` 는 spec-distill 플러그인 폴더 · 스위트 명령은 로드맵 머리말 `test_command`). 하위 agent 에게 보내는 글에도 이 줄과 경로를 그대로 싣는다. 못 잡으면 주인 · 잡은 시각을 보고한다. 과제 안에서는 좁은 테스트만 돌린다 — 전체 스위트는 Task 9 에서 한 번(SDD 의 과제 구현자에게 맡기지 않는다).

## Review Focus

1. **head 커밋이 로컬에 없는 머지된 PR** — 브랜치가 지워져 fetch 되지 않은 PR 이면 범위 확인 스크립트는 「확인 못 함」 으로 뭉뚱그리지 않고 `git fetch origin pull/<번호>/head` 를 하라는 사유를 낸다. 테스트: Task 4 `test_missing_head_says_fetch`.
2. **squash 뒤 기본 브랜치가 같은 파일의 다른 곳을 고친 경우** — 사람은 PR 이 리뷰되기를 기대한다. 줄 번호를 지운 비교라 확인돼야 한다. 테스트: Task 4 `test_squash_after_base_touched_same_file`.
3. **같은 에픽 · 같은 PR 에 리뷰를 두 번 보내는 일(압축 · 새 세션 뒤)** — 「머지됨」 은 계속 참이다. 보관 폴더 이름(`qg-<에픽>-merged-pr<번호>-<날짜>`)이 `## 자원` 에 있거나 그 자리의 쌓인 기록 줄이 있으면 보내지 않는다. 테스트: Task 5 문서 락 `already-sent`.
4. **기록 브랜치가 이미 머지됐는데 다음 리뷰가 온 경우** — 기본 브랜치에서 다시 만든다. 테스트: Task 6 문서 락 `record-branch-remade`.
5. **qg 의 문서 경로 설정이 `docs/` 를 거르는 레포** — spec 승인 앞 · 로드맵 끝이 「리뷰할 diff 없음」 건너뜀으로 끝나면 지휘자는 그 사유를 그대로 보이고 `reason_text` 를 보인다. 테스트: Task 5 문서 락 `doc-path-skip` · Task 8 README 락.

---

## 열린 결정 — 구현 전에 지휘자가 답을 적는다

아래 다섯은 설계의 글자 · 수용 기준 · 보이는 동작을 바꾸므로 이 계획이 정하지 않았다(마지막 절 `## 설계에 없던 결정` 에 항목마다 그대로 두면 · 고치면 · 권고). **각 과제 본문은 「그대로 두면」 을 기본으로 적고, 결정이 「고치면」 이면 바뀌는 단계를 `[P<n> 고치면: …]` 로 함께 적었다.** 구현자는 지휘자가 적어 준 답대로 한쪽만 한다. 답이 없으면 구현을 시작하지 않는다.

| 결정 | 닿는 과제 | 답(사용자 · 2026-11-20) |
|---|---|---|
| P1 범위 모드에서 바뀐 문서를 따라가는 조건 | Task 3 | 「고치면」 |
| P2 기록 머리의 `source_brief:` 줄 | Task 6 | 「고치면」 |
| P3 기록 브랜치 이름 | Task 6 | 「고치면」 |
| P4 「잘못 골랐다」 설명의 셋째 갈래 | Task 6 | 「고치면」 |
| P5 spec 승인 앞에서 spec 리뷰로 넘어가는 조건 | Task 5 | 「고치면」 |

다섯 다 「고치면」 이다 — 구현자는 과제마다 `[P<n> 고치면: …]` 쪽만 한다. 설계문서의 수용 기준 AC10 · AC13 · AC21 은 지휘자가 이 답대로 고쳐 두었다(설계문서 `## 결정 기록` 끝의 「계획 검토」 줄). 설계문서 본문의 §1 · §3 · §4 · §5 문장이 이 답과 다르면 이 답이 앞선다.

Task 7 Step 5 의 처분 검사 넓히기(레포 공유 검사 `shared/tests/test_dispatch_disposition.sh` 가 내장 일반 agent 의 dispatch 도 세게 한다)도 사용자가 골랐다 — 「넓힌다」.

---

### Task 1: 기본 브랜치 합치기와 다시 확인

설계문서가 근거로 든 자리가 지금 코드에서도 그런지 본다. AC 를 직접 맡지 않는다 — 뒤 과제 전부의 전제다.

**Files:** 없음(읽기만. 결과는 `$TMPDIR/recheck.md` 에 셸로 적는다).

- [ ] **Step 1: 기본 브랜치를 합친다**

설계 바탕(`3b4e582a`) 뒤에 기본 브랜치에 지휘 절차를 고친 PR(#306 — 상태 브랜치 · `conductor_status.py`)이 머지돼, 이 브랜치의 `conducting.md` 가 낡았다.

```bash
git fetch origin
git merge --no-edit origin/HEAD
```

Expected: 충돌 없이 merge 커밋(이 브랜치는 설계문서만 바꿨다). 충돌이면 멈추고 보고한다.

- [ ] **Step 2: 근거 자리를 하나씩 확인한다**

각 줄의 명령 출력이 「기대」 와 같은지 `$TMPDIR/recheck.md` 에 한 줄씩(같음 · 다름 + 본 것) 적는다.

| # | 확인 | 명령 | 기대 |
|---|---|---|---|
| 1 | 걸음 7 의 옛 qg 문장 | `grep -c '로드맵 시작 커밋부터 지금 기본 브랜치까지 돌린다' plugins/spec-distill/references/conducting.md` | `1` |
| 2 | 걸음 7 판단의 「없으면」 문장 | `grep -c '품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」를 알리고 진행한다' plugins/spec-distill/references/conducting.md` | `1` |
| 3 | 걸음 3 의 spec 리뷰 불릿 · 걸음 6 기본값 · 손 절차 3 · 6 · 9 | `grep -nE '^  - spec 리뷰: |^### 6\. 머지 뒤|^3\. \*\*흐름과 설계|^6\. \*\*머지 뒤|^9\. \*\*끝' plugins/spec-distill/references/conducting.md` | 다섯 줄 |
| 4 | 지휘자 skill 의 규모 줄 · 보이기 | `grep -nE '^### 4\. 규모 공시|agent 수는 에픽마다 계획 1|^## 보이기' plugins/spec-distill/skills/epic-conductor/SKILL.md` | 세 줄 |
| 5 | `--origin` 도움말 줄 | `grep -n -- '--origin <path>' plugins/quality-gates/scripts/setup-qg.sh` | 한 줄 |
| 6 | 범위 모드는 바뀐 문서를 따라가지 않는다 | `grep -n 'return ("range" if names else "narrow", \[\], 0)' plugins/quality-gates/scripts/intent_origin.py` | 한 줄 |
| 7 | 넘기는 쪽은 이미 그대로 흘린다 | `grep -n 'changed_docs=docs' plugins/quality-gates/scripts/intent_critic.py` | 한 줄 |
| 8 | 의도 문서 표시에 `roadmap` · `source_brief` | `grep -n '^DEFAULT_MARKERS' plugins/quality-gates/scripts/intent_origin.py` | 두 낱말이 든다 |
| 9 | PR 캐시 칸 | `grep -n '"headRefOid", "교차 레포", "baseRefName", "mergeCommit"' plugins/spec-distill/scripts/conductor_state.py` | 한 줄 |
| 10 | 계약 2판 칸 | `grep -n '^## 돌려주는 꼴 — `intent-return.md` (2판)' plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md` | 한 줄(머리 칸에 `contract` · `status` · `outcome` · `result_line` · `reason_text` · `other_teams`, 질문 칸에 `id` · `state` · `question` · `observation`) |
| 11 | qg 질문 라벨 · 고정 문장 | `grep -n '의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다' plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md` 와 같은 파일의 `label: "의도다"` · `label: "잘못 골랐다"` · `label: "지금은 모르겠다"` | 각 한 줄 |
| 12 | 범위 모드 끝내기 질문 · 낮춘 지적 질문의 라벨 | `grep -c 'label: "지금 판정으로 끝내기"' plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `grep -c 'label: "그대로 둔다"' 같은 파일` | 1 이상 · 1 이상 |
| 13 | 질문 자리 목록의 qg 행 종류 | `grep -n 'intent-critic.md	비움' shared/tests/fixtures/ask-sites.tsv` | 한 줄 |
| 14 | `request-framing` 의 `@경로` 풀기 | `grep -n '^### 2. `@경로` 풀기' plugins/spec-distill/skills/request-framing/SKILL.md` | 한 줄 |
| 15 | 브랜치 접두 해결자 | `python3 plugins/spec-distill/scripts/repo_defaults.py get branch_prefix` | rc 0 · 값 한 줄 |
| 16 | 질문 걸기 기록 | `grep -n 'conductor_status.py waiting add' plugins/spec-distill/references/conducting.md` | 걸음 2 에 한 줄(#306 이 더함 — 알고 있는 차이) |

**알고 있는 차이(멈추지 않는다):** #306 이 더한 것 — 걸음 1 의 상태 브랜치 맞추기 · 걸음 2 의 `conductor_status.py waiting add/clear` · 걸음 7 기본값 끝의 상태 브랜치 지우기 문장 · 기계 상태 `## 지금 묻는 질문` 절. 이 계획은 그것을 지키며 쓴다(Task 6 묻기 · Task 7 걸음 7).

- [ ] **Step 3: 다르면 멈춘다**

위 표에서 「다름」 이 하나라도 있고 알고 있는 차이가 아니면 구현을 멈추고 `$TMPDIR/recheck.md` 를 지휘자에게 보고한다. 모두 같으면 Task 2 로 간다. 커밋할 것은 Step 1 의 merge 커밋뿐이다.

---

### Task 2: 측정 가 · 나 — 담당자가 qg 를 범위 모드로 돌릴 수 있는가

설계문서 `## Verification Plan` 의 「계획의 첫 측정」 이다. **둘 가운데 하나라도 기대와 다르면 구현을 멈추고 지휘자에게 돌려보낸다 — 설계가 바뀐다.** 규모: 실제 qg 실행 두 번(각각 리뷰어 여럿 · 차등 테스트 한 번 · 켜져 있으면 codex). 차례로 돌린다(qg 가 안에서 스위트를 돌린다).

**Files:** 없음. 결과는 `$TMPDIR/measure-a/` · `$TMPDIR/measure-b/` 와 `$TMPDIR/measure.md`.

- [ ] **Step 1: 스위트 잠금이 비었는지 본다**

`python3 "<SD>"/scripts/suite_lock.py show --lock <지휘자가 주는 스위트 잠금 경로>` — 잡혀 있으면 풀릴 때까지 기다린다(측정 담당자의 qg 차등 테스트가 다른 스위트와 겹치지 않게).

- [ ] **Step 2: 측정 가를 보낸다 — 머지된 에픽 하나의 머지 커밋 범위**

대상은 R5 의 머지 커밋 `269ead33c9eedb89735735e0818fcc2410376613`(부모 둘, 첫 부모 `cfb25c5f6c06a6cdc8f7a2ddc94442a16d60383a`). 아래 글로 `isolation: "worktree"` · 백그라운드 agent 하나를 보낸다(모델은 역할 — 긴 skill 을 그대로 따라 도는 일 — 을 보고 고르고 이유를 한 줄로 적는다).

```text
너는 qg 측정 담당자다. 자리: 네 격리 worktree 에서 `git fetch origin` 뒤 `git switch --detach origin/HEAD` 로 기본 브랜치 끝에 선다(브랜치를 쥐지 않는다).
아래 호출 줄을 글자 그대로 한 번만 부른다 — 두 번 부르지 않는다(둘째 호출이 첫 결과를 지운다):
/quality-gates:quality-pipeline range cfb25c5f6c06a6cdc8f7a2ddc94442a16d60383a..269ead33c9eedb89735735e0818fcc2410376613 --origin docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/R5.md
미리 받은 답: 범위 모드에서 지적이 있을 때의 끝내기 질문에는 「지금 판정으로 끝내기」. 「낮춘 지적」 질문에는 모든 묶음에 「그대로 둔다」. 그 밖에 사람에게 묻는 자리를 만나면 멈추고 (a) 쉬운 요약 (b) 질문 원문을 돌려보낸다.
끝내기 전에 qg 세션 폴더의 intent-return.md · result.md · (intent-return.md 의 other_teams 값이 `-` 가 아니면) 그 파일을 <보관 폴더> 로 셸 복사한다.
마지막 보고: qg 가 낸 범위 공시 줄 · 판정 줄 · intent-critic 결과 줄을 글자 그대로, 코드 리뷰 지적 목록, 낮춘 지적 표 전부(위치 · 원래 심각도 · 내용 · 낮춘 이유)와 미리 받은 답을 쓴 자리, qg 가 낸 공시 줄 전부, 옮긴 파일의 경로. 옮기지 못했으면 그 사실과 이유.
TMPDIR=<보관 폴더>. 전체 스위트를 따로 돌리지 않는다. 금지: 공유 임시 폴더 glob 삭제 · git stash · 다른 worktree 의 git · HEAD 뒤로 옮기기. 스위트를 돌려야 하면: python3 "<SD>"/scripts/suite_lock.py run --lock <지휘자가 주는 스위트 잠금 경로> --owner <agent 이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'
```

`<보관 폴더>` 는 `$TMPDIR/measure-a`.

Expected: `$TMPDIR/measure-a/intent-return.md` 가 있고 그 안에 `contract: 2` 와 `status:` 줄이 있다.

- [ ] **Step 3: 측정 나를 보낸다 — 문서 하나만 바뀐 범위**

같은 글에서 호출 줄만 바꾼다 — 이 에픽 브랜치의 설계문서만 든 범위다(`3b4e582a..828a7cbc` 의 바뀐 파일은 설계문서 하나):

```text
/quality-gates:quality-pipeline range 3b4e582a26d5d538cef027d68244f67567e20b0e..828a7cbcadc9f996142941e3e74e3e7068677b4e --origin docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/R3.md
```

`<보관 폴더>` 는 `$TMPDIR/measure-b`. 측정 가가 돌아온 뒤에 보낸다.

Expected: `$TMPDIR/measure-b/intent-return.md` 에 `status: ran` 이 있고(작은 수정 건너뜀 `reason: trivia` 도, `reason: empty-diff` 도 아니다) `result_line:` 이 `-` 가 아니다.

- [ ] **Step 4: 판정을 적는다**

`$TMPDIR/measure.md` 에 측정마다 한 줄(된다 · 안 된다 + 본 칸 값) — 그리고 측정 나에서 리뷰어 입력에 묶음과 로드맵이 실렸는지(돌려준 공시 줄에 「원문 없음」 · 「로드맵 없음」 이 있었는지)를 적는다. 하나라도 「안 된다」 면 멈추고 그 파일과 담당자 보고 원문을 지휘자에게 보고한다. 둘 다 되면 Task 3 으로 간다. 담당자가 돌려준 보고에서 Task 5 의 보내는 글 틀에 반영할 것(보고 칸이 모자랐던 것 등)을 같은 파일에 적는다.

---

### Task 3: qg — 범위로 부른 리뷰가 바뀐 의도 문서의 머리 줄을 따라간다

맡는 AC: **AC21** · **AC17** · **AC18**(quality-gates 쪽).

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_origin.py:496-519`(`review_breadth`)
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md:104`(넓이 문단)
- Modify: `plugins/quality-gates/scripts/setup-qg.sh:138`(도움말)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`
- Test: `plugins/quality-gates/tests/test_intent_wide.py` · `plugins/quality-gates/tests/test_setup_qg.sh` · `plugins/quality-gates/tests/test_intent_critic_wiring.sh`

**Interfaces:**
- Produces: `review_breadth(mode, names, read_doc, markers) -> (넓이, 의도 문서 목록, 읽지 못한 수)` — 범위 모드의 반환이 `("range", [바뀐 의도 문서…], <읽지 못한 수>)` 가 된다(넓이 이름 `range` 그대로). `intent_critic._breadth` · `build_origin(changed_docs=…)` 는 고치지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다(`test_intent_wide.py`)**

`TestBreadth` 에:

```python
def test_range_lists_changed_intent_docs(self):
    design = "docs/specs/a-design.md"
    self.assertEqual(self._b("range", {"src/a.py", design}), ("range", [design], 0))
    self.assertEqual(self._b("range", {"docs/guide.md", "src/a.py"}), ("range", [], 0))
    self.assertEqual(self._b("range", {"skills/x/SKILL.md"}), ("range", [], 0))   # 모델이 읽는 파일은 읽지 않는다
    self.assertEqual(self._b("range", None), ("narrow", [], 0))
```

[P1 고치면: 첫 단언을 `("range", [], 0)`(코드가 섞인 범위는 따라가지 않는다)로, 그 아래에 `self.assertEqual(self._b("range", {design, "CHANGELOG.md"}), ("range", [design], 0))` 를 더한다.]

`TestWidePrepare` 의 `_prep` 에 인자 `origin=None` 을 더해 있으면 `args.append("--origin=" + origin)` 한다. 새 테스트 셋(기록 파일 픽스처는 테스트 안에서 쓰고 커밋한다 — `REC = "docs/rm/one/reviews/2026-11-20-roadmap-end.md"`, 머리는 `tic._fm(type="roadmap-review", roadmap="docs/rm/one/roadmap.md", source_brief="docs/brief.md")`. 이 픽스처는 qg 의 따라가기(AC21)를 재는 일반 의도 문서라 P2 의 답과 무관하게 `source_brief:` 를 둔다):

```python
def test_range_record_follows_roadmap_and_brief(self):
    p = self._prep(mode="range", names=(REC,))
    self.assertIn("breadth: range", self._plan())
    self.assertIn("one-intent-token", self._f("intent-roadmap.md"))
    self.assertIn("brief-quote-token", self._f("intent-origin.md"))
    out = p.stdout.splitlines()
    self.assertFalse([l for l in out if l.startswith("로드맵 없음") or l.startswith("원문 없음")])

def test_range_origin_same_file_loaded_once(self):
    self._prep(mode="range", names=(REC,), origin="docs/brief.md")
    origin = self._f("intent-origin.md")
    self.assertEqual(origin.count("brief-quote-token"), 1)
    self.assertEqual(origin.count("<!-- origin-source: docs/brief.md · file: docs/brief.md -->"), 1)

def test_range_code_only_keeps_today(self):
    p = self._prep(mode="range", names=("src/a.py",))
    self.assertTrue(self._f("intent-roadmap.md").startswith("로드맵 없음 — "))
    self.assertIn("넓게 본다 — 범위 모드", p.stdout.splitlines())
```

PR 범위의 동작이 바뀌지 않는다는 락은 지금 테스트(`test_design_doc_only_calls` · `test_code_pr_is_r1` · `TestBreadth.test_table` 의 `pr` 행)가 맡는다 — 고치지 않는다.

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_wide.TestBreadth test_intent_wide.TestWidePrepare -v`
Expected: 새 테스트 셋이 FAIL(`("range", [], 0)` · 「로드맵 없음」), 나머지는 PASS.

- [ ] **Step 3: `review_breadth` 의 범위 모드 갈래를 고친다**

범위 모드면 `names` 가 비면 `("narrow", [], 0)`, 아니면 `sorted(names)` 가운데 `doc_paths.is_doc_file(rel) and not doc_paths.is_model_read(rel)` 인 것만 `read_doc` 으로 열어 PR 갈래와 같은 방식(`None` 이면 읽지 못한 수, `is_intent_doc` 이면 목록)으로 모아 `("range", intent_docs, unread)` 를 낸다. 의도 문서를 모으는 고리는 PR 갈래와 함께 쓰는 작은 도우미로 뺀다(20줄 중복 락). docstring 의 넓이 설명에 「범위 모드도 바뀐 의도 문서 목록을 낸다」 를 더한다. [P1 고치면: 범위 모드에서도 PR 갈래와 같은 조건 — 바뀐 파일이 모두 문서 파일이고 모델이 읽는 파일이 없을 때만 — 목록을 내고, 아니면 `("range", [], 0)`.]

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/quality-gates/tests && python3 -m unittest test_intent_wide test_intent_critic -v 2>&1 | tail -5`
Expected: OK. 범위 모드로 도는 기존 테스트 가운데 새 동작 때문에 깨진 것이 있으면 새 동작에 맞춰 고치고 그 이름을 PR 본문 몫으로 `$TMPDIR/pr-notes.md` 에 적는다(설계문서 Verification Plan). 2026-11-20 조사로는 그런 락이 없다.

- [ ] **Step 5: 변이로 이빨을 본다**

범위 갈래를 옛 한 줄(`return ("range" if names else "narrow", [], 0)`)로 되돌려 새 테스트 셋이 RED 인지, `test_range_origin_same_file_loaded_once` 는 `_open_doc` 의 `seen_rel == rel` 비교와 `_add_origin_doc` 첫 줄의 `rel in st["done"]` 검사를 함께 꺼 RED 인지 본다(둘 가운데 하나만 끄면 다른 하나가 막아 GREEN 이다 — 그것은 이빨 없음이 아니다). 되돌린 뒤 `git diff HEAD --stat` 이 이 과제의 변경뿐인지 확인한다(변이는 커밋한 뒤에 한다 — Step 9 뒤로 미뤄도 된다).

- [ ] **Step 6: 절차 문서 문장 · 도움말 · 그 락**

`intent-critic.md` 의 **넓이** 문단 끝에 이 문장을 더한다(글자 그대로):

> 범위 모드에서도 바뀐 파일 가운데 의도 문서(문서 파일이고 모델이 읽지 않는 파일 가운데 의도 문서 표시가 있는 것)는 PR 범위와 같이 머리 줄(`source_interview:` · `source_brief:` · `roadmap:`)을 따라가 원문과 로드맵을 싣는다 — `--origin` 으로 넘긴 원문과 같은 파일이면 한 번만 싣는다. 넓이 이름은 그대로 `range` 다.

[P1 고치면: 괄호 안을 「바뀐 파일이 모두 문서 파일이고 모델이 읽는 파일이 없을 때의 의도 문서」 로.]

`setup-qg.sh` 의 `--origin` 줄 바로 아래에 한 줄:

```text
                       If that file has no roadmap: line, the other-teams map reports 「로드맵 없음」.
```

락: `test_intent_critic_wiring.sh` 에 `assert_contains "$(cat "$PROC")" '범위 모드에서도 바뀐 파일 가운데 의도 문서' "…"`(`PROC` 는 그 테스트가 이미 정의한 `intent-critic.md` 경로), `test_setup_qg.sh` 에 `--help` 출력에서 `--origin` 줄의 다음 줄이 `roadmap:` 과 `로드맵 없음` 을 담는다는 단언(AC17).

Run: `bash plugins/quality-gates/tests/test_setup_qg.sh 2>&1 | tail -3 && bash plugins/quality-gates/tests/test_intent_critic_wiring.sh 2>&1 | tail -3`
Expected: 두 파일 모두 `Fail: 0`.

- [ ] **Step 7: 판과 CHANGELOG**

`plugins/quality-gates/.claude-plugin/plugin.json` 의 `version` 을 그때의 origin/main 판 위 minor 로, `CHANGELOG.md` 맨 위에 같은 판 머리 `## [<판>] — <YYYY-MM-DD>` 와 `### Changed`(범위로 부른 리뷰가 바뀐 의도 문서의 머리 줄을 따라가 원문 · 로드맵을 싣는다 · `--origin` 과 같은 파일은 한 번 · `setup-qg.sh --help` 의 `--origin` 한 줄).

Run: `bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -3`
Expected: `Fail: 0`.

- [ ] **Step 8: 커밋**

```bash
git add plugins/quality-gates/scripts/intent_origin.py plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/tests/test_intent_wide.py plugins/quality-gates/tests/test_setup_qg.sh plugins/quality-gates/tests/test_intent_critic_wiring.sh plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "feat(qg): 범위로 부른 리뷰가 바뀐 의도 문서의 머리 줄을 따라간다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

---

### Task 4: 범위 확인 스크립트

맡는 AC: **AC4**(스크립트 쪽 — 네 꼴의 픽스처 테스트 · 파일 수는 근거가 아님).

**Files:**
- Create: `plugins/spec-distill/scripts/merged_pr_range.py`
- Test: `plugins/spec-distill/tests/test_merged_pr_range.py`

**Interfaces:**
- Produces(Task 5 가 절차에 적는 명령):
  - `python3 "<SD>"/scripts/merged_pr_range.py --roadmap <로드맵> --pr <번호>` — 기계 상태 PR 캐시에서 그 PR 줄(`번호` 칸이 `#<번호>`)의 `headRefOid` · `mergeCommit` 을 읽어 확인한다. 레포 루트는 cwd 의 `git rev-parse --show-toplevel`.
  - `python3 "<SD>"/scripts/merged_pr_range.py --merge <커밋> --head <커밋> --pr <번호>` — 값을 직접 준다(테스트 · 손).
  - stdout(rc 0) 세 줄: `start: <40자>` · `end: <40자>` · `how: merge-commit | squash | rebase-<N>`.
  - rc: `0` 확인됨 · `2` 사용법 · `3` 확인하지 못함(stdout 비움, stderr 한 줄 `[spec-distill] 범위를 확인하지 못했다 — <사유>`) · `4` 캐시에 머지 커밋이 없다(PR 줄이 없거나 `mergeCommit` 이 `-` — stderr `[spec-distill] PR #<번호> 의 머지 커밋이 PR 캐시에 없다 — ledger pr-refresh 뒤 다시 부른다`).
  - 모듈: `confirm(repo: str, merge: str, head: str, pr: str) -> tuple`(`((start, end, how), None)` 또는 `(None, 사유)`) · `same_change(repo: str, a1: str, b1: str, a2: str, b2: str) -> bool` · `main(argv=None) -> int`.
- Consumes: `conductor_state.machine_path(root, roadmap_rel)` · `conductor_state.load(path, roadmap_rel)` 의 `["PR"]` 줄.

규칙(설계 §1 · 리뷰 지적 cddb035a 의 풀이):
- 머지 커밋의 부모가 둘이고 둘째 부모가 head 면 `start` = 첫 부모, `how: merge-commit`. 둘째 부모가 head 가 아니면 확인 못 함(사유 `부모가 둘인데 둘째 부모가 PR 의 head 가 아니다`). 셋 이상이면 확인 못 함(`부모가 셋 이상인 머지다`).
- 부모가 하나면 `F = merge-base(head, merge)`(없으면 `head 와 머지 커밋의 공통 조상이 없어 PR 의 커밋 수를 셀 수 없다`), `N = rev-list --count F..head`(0 이면 같은 사유). 후보는 `merge~N`(N>1 일 때 먼저 — `how: rebase-<N>`)과 `merge~1`(`how: squash`) 차례다. 후보마다 `same_change(repo, 후보, merge, F, head)` 가 참인 첫 후보를 쓴다. 없으면 확인 못 함(`부모가 하나인데 바로 앞 커밋부터도 PR 의 커밋 수(<N>)만큼 앞부터도 PR 의 변경과 같지 않다`).
- `same_change`: 먼저 두 diff 의 `git patch-id --stable` 이 다르면 거짓(좁히기). 같으면 `git diff --no-color --no-ext-diff --no-textconv --no-renames --full-index -U0 <a> <b>` 두 출력에서 `index ` 로 시작하는 줄을 빼고 `@@` 로 시작하는 줄을 `@@` 로 줄인 글이 글자로 같을 때만 참 — 공백 · 들여쓰기 차이는 보존된다. 바뀐 파일 수는 쓰지 않는다.
- head 객체가 없으면 사유는 `head 커밋 <8자> 이 이 레포에 없다 — git fetch origin pull/<번호>/head 뒤 다시 부른다`.
- 읽기만 한다 — 허용 git 하위 명령은 `rev-parse` · `rev-list` · `merge-base` · `diff` · `patch-id` · `cat-file` 뿐(`branch_tip.py` 의 `GIT_ALLOWED` 방식).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

임시 레포 도우미(`tempfile.TemporaryDirectory` · `git init -q -b <임의 이름>` · 사용자 이름/메일 설정 · 커밋 도우미)를 테스트 파일 안에 둔다. 테스트(값은 모두 실제 커밋 해시로 비교):

```python
def test_merge_commit(self):           # git merge --no-ff topic
    got, why = mpr.confirm(R, merge, head, "1")
    self.assertIsNone(why); self.assertEqual(got, (first_parent, merge, "merge-commit"))

def test_squash(self):                 # 기본 브랜치에 무관한 커밋 하나 뒤 git merge --squash topic + commit
    self.assertEqual(mpr.confirm(R, sq, head, "2")[0], (sq_parent, sq, "squash"))

def test_rebase_three_commits_same_file(self):
    # topic 세 커밋이 모두 a.txt 만 고친다: c1 이 `x = 1` 줄을 더하고, c2 가 다른 줄을 더하고, c3 이 c1 의 줄을 `x = 2` 로 바꾼다.
    # 기본 브랜치(움직이지 않음)에서 c1..c3 을 cherry-pick(새 커밋 셋) — merge = 마지막 cherry-pick, head = c3.
    got, why = mpr.confirm(R, merge, c3, "3")
    self.assertEqual(got, (base_before, merge, "rebase-3"))
    self.assertNotEqual(got[0], parent_of_merge)   # 마지막 커밋만 잡지 않는다
    # 바뀐 파일 수가 같아도(둘 다 a.txt 하나) 마지막 커밋만의 변경은 PR 의 변경이 아니다
    self.assertFalse(mpr.same_change(R, parent_of_merge, merge, base_before, c3))

def test_unconfirmable(self):          # head 와 무관한 부모 하나짜리 커밋을 merge 로 준다
    got, why = mpr.confirm(R, unrelated, head, "4")
    self.assertIsNone(got); self.assertIn("같지 않다", why)

def test_second_parent_not_head(self):  # merge --no-ff 한 뒤 다른 커밋을 head 로 준다
    self.assertIsNone(mpr.confirm(R, merge, other, "5")[0])

def test_missing_head_says_fetch(self):
    got, why = mpr.confirm(R, merge, "0" * 40, "6")
    self.assertIsNone(got); self.assertIn("git fetch origin pull/6/head", why)

def test_whitespace_difference_is_not_same_change(self):
    # c1 이 줄 `x = 1` 을 들여쓰기만 바꾸고 c2 가 그 줄 값을 바꾼다. (base, c2) 와 (c1, c2) 는 patch-id 가 같지만 같은 변경이 아니다.
    self.assertFalse(mpr.same_change(R, c1, c2, base, c2))
    self.assertTrue(mpr.same_change(R, base, c2, base, c2))

def test_squash_after_base_touched_same_file(self):
    # topic 이 a.txt 의 위쪽을, 기본 브랜치가 그 뒤 같은 파일의 먼 아래쪽을 고친 다음 squash
    self.assertEqual(mpr.confirm(R, sq, head, "7")[0][2], "squash")

def test_cli_rc(self):
    # 확인됨: rc 0 · stdout 세 줄 꼴 / 확인 못 함: rc 3 · stdout 빈 글 · stderr 가 "[spec-distill] 범위를 확인하지 못했다 — " 로 시작
    # 캐시에 머지 커밋 없음: --roadmap 갈래에서 mergeCommit `-` 줄 → rc 4. 캐시 파일은 conductor_state.render_machine 으로
    # 임시 레포 아래 conductor_state.machine_path 자리에 쓴다(그 자리가 임시 레포 밖이면 conductor_state.load 를 mock.patch 로 대신한다).
```

- [ ] **Step 2: 실패를 확인한다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_merged_pr_range -v 2>&1 | tail -5`
Expected: `ModuleNotFoundError`(아직 스크립트가 없다).

- [ ] **Step 3: `merged_pr_range.py` 를 쓴다**

위 Interfaces 와 규칙대로. `subprocess.run(..., encoding="utf-8", errors="replace")` · `patch-id` 는 diff 출력을 `input=` 으로 준다. 해시 인자는 `[0-9a-f]{7,40}` 를 `fullmatch` 로 거른 뒤 `rev-parse --verify <x>^{commit}` 으로 푼다. 첫 줄 docstring 은 하는 일 · 사용법 · 종료 코드만 적는다(출처 · 배경 금지).

- [ ] **Step 4: 통과를 확인한다**

Run: `cd plugins/spec-distill/tests && python3 -m unittest test_merged_pr_range -v 2>&1 | tail -5` 와 `cd plugins/quality-gates/tests && python3 -m unittest test_utf8_explicit 2>&1 | tail -3` 와 `bash shared/tests/test_python_floor.sh 2>&1 | tail -3`
Expected: 모두 OK · `Fail: 0`.

- [ ] **Step 5: 변이로 이빨을 본다(커밋 뒤)**

① `same_change` 에서 엄격 비교를 빼고 patch-id 만 쓴다 → `test_whitespace_difference_is_not_same_change` RED. ② 후보 순서만 squash 먼저로 바꾼다 → 엄격 비교가 막아 GREEN 이 정상이다(확인만 하고 적는다). ③ 둘째 부모 == head 검사를 뺀다 → `test_second_parent_not_head` RED. ④ `same_change` 앞머리에 「바뀐 파일 수가 같으면 참」 지름길을 넣는다 → `test_rebase_three_commits_same_file` 의 마지막 단언 RED. 매번 `git checkout HEAD -- <파일>` 로 되돌리고 `git diff HEAD --stat` 이 비었는지 본다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/merged_pr_range.py plugins/spec-distill/tests/test_merged_pr_range.py
git commit -m "feat(spec-distill): 머지된 PR 하나의 커밋 범위를 머지 방식별로 확인하는 스크립트를 더한다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

---

### Task 5: `qg-review.md` 앞 절 — 호출 줄 · 자리 · 담당자 · 돌아왔을 때

맡는 AC: **AC1** · **AC3** · **AC4**(지휘자 쪽 — 확인되지 않거나 머지 커밋이 없으면 보내지 않는다) · **AC5** · **AC6**(앞 문장) · **AC7** · **AC14** · **AC15** · **AC16**(스위트 잠금 · 보내기 전 규모) · **AC22** · **AC23** · **AC24**.

**Files:**
- Create: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`
- Create: `plugins/spec-distill/tests/test_qg_review_reference.sh`(100755)

**Interfaces:**
- Consumes: Task 4 의 명령 두 꼴 · 종료 코드. Task 2 의 `$TMPDIR/measure.md` 에 적힌 보내는 글 고칠 점.
- Produces: 절 머리(Task 6 · 7 이 가리킨다) — `## 호출 줄` · `## 자리` · `## 담당자` · `## 돌아왔을 때` (Task 6 이 `## 보관과 기록 파일` · `## 묻기` · `## 「잘못 골랐다」 의 행선` 을 잇는다). 자리 이름 넷의 글자: `spec 승인 앞` · `에픽 머지 뒤` · `로드맵 끝` · `이름으로 청함`.

파일 첫머리는 맡는 일만 한 문장으로 적는다(「지휘 세션이 qg 리뷰 자리에 닿았을 때 따르는 절차다」). 출처 · 배경 · 존재 이유는 적지 않는다(Self-narrating artifact). `<SD>` · `<로드맵>` · `<세션>` · `ledger <명령>` 은 `conducting.md` 의 정의를 쓴다고 한 줄로 밝힌다.

- [ ] **Step 1: 실패하는 문서 락을 쓴다**

`test_qg_review_reference.sh` 머리(형제 `test_conducting_reference.sh` 의 꼴):

```bash
#!/usr/bin/env bash
# R3 — 지휘자 경유 qg 리뷰 절차(skills/epic-conductor/references/qg-review.md)와 들어가는 문장. 정적 락이다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_qg_review_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
QR="$ROOT/plugins/spec-distill/skills/epic-conductor/references/qg-review.md"
[ -f "$QR" ] && ok "qg-review.md 가 있다" || { no "qg-review.md 가 없다"; finish; exit $?; }
sec() { awk -v h="$1" '$0==h{f=1;next} f&&/^## /{exit} f' "$QR"; }   # 절 본문(머리 줄 제외)
once() { assert_eq "$(printf '%s\n' "$1" | grep -oF -- "$2" | wc -l | tr -d ' ')" "1" "$3"; }
```

이 과제에서 넣는 단언(모두 **절 본문**에서 — 머리 줄이 만족시키지 않는 글자로). `L(x)` 는 아래 Step 3 이 글자 그대로 넣는 문장이다.

| 표지 | 절 | 단언 |
|---|---|---|
| AC1 호출 줄 | `## 호출 줄` | `once` `/quality-gates:quality-pipeline range <시작 커밋>..<끝 커밋> --origin <원문 파일의 레포 상대경로>` · 파일 전체에서 `quality-pipeline` 을 부르는 다른 꼴(`quality-pipeline range` 가 이 한 줄 밖에)이 없다 |
| AC1 표 | `## 자리` | 표 머리 줄 `\| 자리 \| 언제 \| 시작 \| 끝 \| 원문 \| 「잘못 골랐다」 \| 기록이 실리는 곳 \|` 이 한 번 · 표의 첫 칸이 차례로 `spec 승인 앞` · `에픽 머지 뒤` · `로드맵 끝` · `이름으로 청함` |
| AC3 직접 부르지 않음 | `## 호출 줄` | `L(nodirect)` 한 번 · 양성 짝: `## 담당자` 에 `isolation: "worktree"` |
| AC3 보내는 글 | `## 담당자` | `한 번만 부른다` · `「지금 판정으로 끝내기」` · `모든 묶음에 「그대로 둔다」` · `intent-return.md` · `other_teams` · `result.md` · `낮춘 지적 표 전부(위치 · 원래 심각도 · 내용 · 낮춘 이유)` |
| AC3 처분 | `## 담당자` | 처분 줄 글자 그대로 한 번(Step 3) · 그 줄이 `Agent(` 줄 아래 40줄 안 |
| AC3 되올림 | `## 담당자` | `L(raise)` 한 번 · `qg 를 다시 돌리지 않는다` |
| AC4 지휘자 | `## 자리` | `merged_pr_range.py --roadmap <로드맵> --pr <번호>` · `L(norange)` · `바뀐 파일 수가 같다는 것은 근거로 쓰지 않는다` |
| AC5 | `## 자리` | `L(endmerge)` · `만든 것: <에픽 번호> · <설계문서의 레포 상대경로> · PR #<번호> · <머지 커밋>` |
| AC6 앞 | `## 돌아왔을 때` | `질문을 가져오지 못했다 — <담당자가 적은 이유>` · `「셀 수 없음」` |
| AC7 | `## 돌아왔을 때` | `결과 파일의 판(<값>)을 읽지 못한다` · `` `status` 가 `ran` 이 아니면 `reason_text` 를 `` · `` `outcome` 이 `questions` 가 아니면 `result_line` 을 그대로 `` |
| AC14 | `## 자리` | `L(resend)` 한 번 · `같은 spec 리뷰 안의 수정(「지적대로 고치기」 · 「직접 편집」 · 리뷰 라운드의 수정)으로는 다시 보내지 않는다` |
| AC15 | `## 호출 줄` | `품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다` · 그 줄에 `건너뛴다` |
| AC16 | `## 자리` | `ledger suite-lock --roadmap <로드맵>` · `L(suitewait)` · `규모를 한 줄로 알리고 바로 보낸다` |
| AC22 | `## 자리` | 다섯 상태 머리 `로드맵 —` · `머지된 에픽 —` · `설계문서가 브랜치에 있고 spec 승인 전인 에픽 —` · `spec 승인 뒤 · 머지 전인 에픽` · `설계문서가 아직 없는 에픽 —` 와 `PR 마다 한 번씩 보낸다` |
| AC23 | `## 자리` | `L(failed)` · 음성 짝: `스스로 다시 보낸다` 가 없다(양성: `지휘자가 스스로 다시 보내지 않는다`) |
| AC24 | `## 담당자` | `L(premerge)` |
| Review Focus 3 | `## 자리` | `L(alreadysent)` (표지 `already-sent`) |
| Review Focus 5 | `## 자리` | `리뷰할 diff 없음` 과 `그 사유를 그대로 보인다` 가 한 문장에 (표지 `doc-path-skip`) |
| 레포 전용 값 | 파일 전체 | `origin/main` · `feature/` · `docs/superpowers` 가 없다(양성: `origin/HEAD` 가 있다) |

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/spec-distill/tests/test_qg_review_reference.sh && bash plugins/spec-distill/tests/test_qg_review_reference.sh 2>&1 | tail -3`
Expected: `qg-review.md 가 없다` 로 FAIL.

- [ ] **Step 3: `qg-review.md` 앞 절을 쓴다**

내용은 설계문서 §1 · §2 다. 아래는 글자가 정해진 것 — 그대로 넣는다. 나머지 문장은 설계 §1 · §2 의 불릿을 행동 문장으로 옮긴다.

`## 호출 줄`: 펜스 안 호출 줄 한 줄(위 AC1 글자) · L(nodirect) = 「지휘 세션은 qg skill 을 직접 부르지 않는다 — 자리마다 담당자 하나를 백그라운드로 보내 이 줄을 부르게 한다.」 · 「skill 목록에 `quality-gates:quality-pipeline` 이 없으면 그 자리마다 「품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」를 알리고 건너뛴다. 건너뛴 사실은 지휘 기록에 적는다.」

`## 자리`: 설계 §1 의 표를 칸 이름 그대로(「기록이 실리는 곳」 칸의 「로드맵의 기록 브랜치」 는 Task 6 의 `### 기록 브랜치` 를 가리킨다). 이어 소절:
- `### 한 박자` — 「보내기 전에 규모를 한 줄로 알리고 바로 보낸다 — 승인을 기다리지 않는다.」 규모 줄 꼴: `qg 담당자 1 · <자리> · <대상> · 범위 <시작 8자>..<끝 8자> — 리뷰어 여럿 · 차등 테스트 한 번 · 켜져 있으면 codex`. 보낸 담당자는 `ledger add --section "살아 있는 agent"` 와 `## 작업` 표에 적고 권장 병렬 수에 센다.
- `### spec 승인 앞` — 순서(설계문서 커밋 → 설계문서 점검과 그 수정의 커밋 → qg 담당자 → 질문과 답 → spec 리뷰), 설계문서 점검과 나란히 보내지 않는다, 범위(에픽 브랜치가 기본 브랜치에서 갈라진 커밋 `git merge-base origin/HEAD <에픽 브랜치>` 부터 보낼 때의 에픽 브랜치 끝), 원문 = 에픽 묶음(로드맵 블록에서 읽는다). L(resend) = 「다시 보내는 때는 둘이다 — 의도 점검의 「잘못 골랐다」 로 설계 대화에 돌아가 고친 뒤, 그리고 spec 리뷰의 「수정 필요」 에서 「이 에픽 다시 설계」 로 설계 대화에 돌아가 고친 뒤. 둘 다 고친 설계문서를 커밋한 뒤, spec 리뷰를 부르기 전에 위 순서로 보내고 질문을 띄운다.」 그리고 「같은 spec 리뷰 안의 수정(「지적대로 고치기」 · 「직접 편집」 · 리뷰 라운드의 수정)으로는 다시 보내지 않는다 — 다르게 판단하면 이유를 지휘 기록에 적는다.」 spec 리뷰로 넘어가는 조건(P5): 그대로 두면 — 「담당자가 돌아와 질문을 한 번 띄우기 전에는 spec 리뷰를 시작하지 않는다 — 답을 받았거나 「답하지 않음」 으로 기록했으면 간다.」 [P5 고치면: 「담당자가 돌아와 그 결과를 보인 뒤에 spec 리뷰를 시작한다 — 질문이 있으면 띄워 답을 받았거나 「답하지 않음」 으로 기록한 뒤, 질문이 없거나(`outcome` 이 `questions` 가 아님) 리뷰가 돌지 않았거나(`status` 가 `ran` 이 아님) 결과를 가져오지 못했으면 그 사실을 보이고 기록한 뒤 간다. 「잘못 골랐다」 가 있으면 가지 않는다(「잘못 골랐다」 의 행선).」 — 락 표지에 `P5` 행 하나를 더해 `결과를 가져오지 못했으면 그 사실을 보이고 기록한 뒤 간다` 를 잠근다.]
- `### 에픽 머지 뒤 — 범위` — 걸음 6 이 머지를 확인한 PR 마다: `python3 "<SD>"/scripts/merged_pr_range.py --roadmap <로드맵> --pr <번호>` (head 객체가 없다는 사유면 `git fetch origin pull/<번호>/head` 뒤 한 번 다시), rc 0 의 `start` · `end` 로 부른다. 원문 = 에픽 묶음. L(norange) = 「rc 가 3 이면 보내지 않고 「범위를 확인하지 못해 리뷰하지 못했다」 와 스크립트가 낸 사유를 보인다 — 범위를 추측해 맞추지 않는다. rc 가 4 면 보내지 않고 머지 커밋이 PR 캐시에 없다는 사실을 알린다.」 「바뀐 파일 수가 같다는 것은 근거로 쓰지 않는다.」 「에픽에 PR 이 여럿이면 머지될 때마다 한 번이다.」 L(alreadysent) = 「보내기 전에 `ledger resources --roadmap <로드맵>` 에 `qg-<에픽>-merged-pr<번호>-` 로 시작하는 보관 폴더가 있거나 `## 쌓인 기록` 에 그 자리(`merged-pr<번호>`)의 줄이 있으면 이미 보낸 것이다 — 다시 보내지 않는다.」
- `### 보내지 못했거나 셀 수 없이 끝난 리뷰` — L(failed) = 「범위를 확인하지 못했거나 머지 커밋이 없어 보내지 못한 리뷰와, 담당자가 결과 파일을 옮기지 못해 「셀 수 없음」 으로 끝난 리뷰는 사용자에게 사유와 함께 보이고 `ledger add --section "쌓인 기록"` 으로 한 줄(자리 · 대상 · 사유)을 남긴다. 지휘자가 스스로 다시 보내지 않는다 — 사용자가 이름으로 청하면 그때 다시 시도한다.」
- `### 로드맵 끝` — L(endmerge) = 「보내기 전에 로드맵의 기록 브랜치에 기본 브랜치 끝을 합치고(`git merge --no-edit origin/HEAD`, 기록 브랜치 worktree 에서), 이 리뷰의 기록 파일 머리(frontmatter · 제목 · 「만든 것」 줄들)를 커밋한 뒤 보낸다. 범위는 합친 뒤의 갈라진 커밋(그때의 기본 브랜치 끝)부터 기록 브랜치 끝까지다.」 「만든 것」 줄의 꼴(위 AC5 글자)과 머지된 에픽마다 한 줄 · 원문 = 로드맵 머리말 `source_brief` 의 문서 · 걸음 7 의 옛 「로드맵 시작 커밋부터」 호출을 대신한다는 말은 적지 않는다(행동만). 「문서 경로로 걸러지지 않은 바뀐 파일이 있어야 qg 가 리뷰한다 — 레포가 문서 경로 설정으로 `docs/` 를 거르면 spec 승인 앞과 로드맵 끝은 「리뷰할 diff 없음」 건너뜀으로 끝나고 지휘자는 그 사유를 그대로 보인다.」
- `### 이름으로 청함` — 설계 §1 의 다섯 상태를 불릿 머리 글자 그대로(위 AC22 표), 각 상태의 범위 · 「잘못 골랐다」 의 행선 · 기록 자리. 「머지된 PR 이 여럿이면 PR 마다 한 번씩 보낸다. 사용자가 PR 을 짚었으면 그것만 보낸다.」 spec 승인 뒤 · 머지 전인 에픽은 구현 중인 커밋이 든다는 것을 보낼 때 알리고, 「잘못 골랐다」 는 재분해 신호로 보이며, 기록은 기록 브랜치에 쓴다.
- `### 스위트 잠금` — `ledger suite-lock --roadmap <로드맵>` 의 주인 칸을 보고 L(suitewait) = 「스위트 잠금이 잡혀 있으면 qg 담당자를 보내지 않고 풀릴 때까지 기다린다. qg 담당자가 도는 동안 스위트 대조를 시작하지 않는다.」 「다른 하위 agent 의 전체 스위트와 겹쳤으면 qg 의 테스트 비교 결과가 경합일 수 있다고 보고에 적어 보인다.」

`## 담당자`:
- `### 보내는 글` — 펜스 안 틀. `conductor-dispatch.md` 의 「늘 싣는 것」 가운데 자리 · 임시 폴더 · 금지 · 스위트 잠금 줄을 그대로 싣는다는 말과, 틀 본문(Task 2 의 측정 글에서 호출 줄을 `<호출 줄>` 로, 보관 폴더를 `<보관 폴더>` 로 바꾼 것 + Task 2 에서 적은 고칠 점). 자리 문장은 「네 격리 worktree 에서 `git fetch origin` 뒤 `git switch --detach origin/HEAD` 로 기본 브랜치 끝에 선다(브랜치를 쥐지 않는다). 원문 파일은 그 커밋에 있다.」
- `### 보내기` — 펜스:

```text
Agent(
  description: "Run quality gates for <대상> <자리>",
  subagent_type: "general-purpose",
  // **처분** — consumer=orchestrator · fail-closed · disclosure=담당자가 돌려준 판정 줄 · 지적 목록 · 낮춘 지적 표 · intent-critic 결과 줄 · 질문 전부를 그 자리 이름과 함께 사용자에게 보인다
  isolation: "worktree",
  run_in_background: true,
  model: "<역할을 보고 고른 모델 — 고른 이유를 한 줄로 알린다>",
  prompt: "<위 보내는 글 — 칸을 채워 글로 싣는다(경로로 넘기지 않는다)>"
)
```

- `### 낮춘 지적` — 「지휘자는 담당자가 돌려준 「낮춘 지적」 표를 빠짐없이 보이고 「낮춘 대로 뒀다 — 되올릴 것이 있으면 말한다」 를 붙인다.」 L(raise) = 「사용자가 되올릴 지적을 말하면 qg 를 다시 돌리지 않는다 — 그 지적을 「사용자가 되올림」 표시와 원래 심각도로 지휘 기록과, 머지 뒤 자리면 후속 PR 의 고칠 목록에 올린다.」 「qg 가 낸 판정 줄은 낮춘 대로 남는다.」
- `### 판정과 코드 리뷰 지적` — 「의도 점검 질문과 섞지 않고 목록으로 보인다. 에픽 머지 뒤 · 로드맵 끝의 지적은 후속 PR 하나의 고칠 목록에 올린다.」 L(premerge) = 「머지 전 자리(spec 승인 앞 · 이름으로 청한 머지 전 에픽)의 판정 줄과 코드 리뷰 지적은 보이기만 하고 spec 리뷰와 승인을 막지 않으며, 그 에픽 설계문서의 `## 지휘 기록` 에 적어 설계 수정이나 구현의 입력으로 둔다.」

`## 돌아왔을 때` — 설계 §2 의 「돌아왔을 때 읽는 법」 네 갈래를 차례대로(위 AC6 · AC7 글자). 「지휘자는 옮겨진 `intent-return.md` 만 읽는다 — qg 의 다른 파일과 qg 본문을 읽지 않는다.」 옮겨진 파일이 없으면 「질문을 가져오지 못했다 — <담당자가 적은 이유>」 를 보이고 그 자리의 리뷰를 「셀 수 없음」 으로 기록한다(조용히 「질문 없음」 으로 넘기지 않는다).

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_qg_review_reference.sh 2>&1 | tail -3`
Expected: `Fail: 0`.

- [ ] **Step 5: 변이로 이빨을 본다(커밋 뒤)**

① L(nodirect) 줄을 지운다 → RED. ② 처분 줄의 `fail-closed` 를 `fail-open` 으로 → 처분 줄 글자 단언 RED. ③ 「지휘자가 스스로 다시 보내지 않는다」 를 「지휘자가 스스로 다시 보낸다」 로 뒤집는다 → AC23 음성 짝 RED. ④ 표의 넷째 칸 `이름으로 청함` 을 지운다 → AC1 표 RED. ⑤ 「바뀐 파일 수가 같다는 것은 근거로 쓰지 않는다」 를 「…근거로 쓴다」 로 → RED 가 아니면 부정형 단언(`근거로 쓴다` 가 없다)을 더한다. 매번 `git checkout HEAD -- <파일>` · `git diff HEAD --stat` 확인.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/spec-distill/tests/test_qg_review_reference.sh
git ls-files -s plugins/spec-distill/tests/test_qg_review_reference.sh   # 100755 확인
git commit -m "feat(spec-distill): 지휘자가 qg 를 부르는 자리 · 범위 · 담당자 절차를 더한다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

---

### Task 6: `qg-review.md` 뒤 절 — 보관 · 기록 파일 · 묻기 · 행선

맡는 AC: **AC6**(보관 사본이 덮이지 않는다) · **AC8**(질문 꼴) · **AC9** · **AC10** · **AC11** · **AC12** · **AC13**.

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`(뒤에 세 절)
- Modify: `plugins/spec-distill/tests/test_qg_review_reference.sh`

**Interfaces:**
- Consumes: Task 5 의 자리 이름 넷 · `## 돌아왔을 때`.
- Produces: 기록 파일 이름 규칙 `<로드맵 폴더>/reviews/<YYYY-MM-DD>-<대상>-<자리>.md`(대상 `R3 등 | roadmap` · 자리 `spec | merged-pr<번호> | end | asked`), 보관 폴더 이름 `qg-<대상>-<자리>-<날짜>`, 질문 자리 앵커(Task 7 의 ask-sites 행이 쓴다) `**의도 점검 질문.**` 와 그 범위 끝 글자 `라벨 셋의 글자와 순서는 qg 와 같다.`, 걸음 1 들어가는 문장이 가리키는 굵은 머리 `**아직 묻지 못한 질문.**`.

- [ ] **Step 1: 실패하는 단언을 더한다**

| 표지 | 절 | 단언 |
|---|---|---|
| AC6 보관 | `## 보관과 기록 파일` | `ledger resource-dir --roadmap <로드맵> --kind report --name qg-<대상>-<자리>-<날짜>` · `끝에 -2, -3 … 을 붙여 앞 사본을 덮지 않는다` |
| AC10 틀 | `## 보관과 기록 파일` | (이 표의 `\|` 는 표 이스케이프 — 파일의 글자는 `\|` 없이 `|`) 기록 틀 펜스(Step 3)의 frontmatter 칸 `type: roadmap-review` · `roadmap:` · `epic:` · `site:` · `reviewed_base:` · `reviewed_head:` · `contract: 2` 각 한 번, 질문 칸 `- 정체: <id>` · `- 질문: <question>` · `- 관찰:` · `- qg 가 돌려준 상태: <state>` · `- 같은 대상에 전에 물은 것:` · `- 답 원문: <직접 쓴 글 그대로 \| ->` 각 한 번 · `L(noquestions)` · `L(sourcebrief)` |
| AC10 계약 칸 이름 | `## 보관과 기록 파일` | 틀의 `<id>` · `<question>` · `<observation 의 줄 전부>` · `<state>` · `<target_source>` · `<target_id>` · `<label>` · `<quote>` · `<evidence>` 가 계약 2판 질문 칸 이름과 같다(이 락이 칸 이름을 하나씩 잠근다) |
| AC11 | `## 보관과 기록 파일` | `L(branchspec)` · `L(pushnow)` · PR 을 여는 때 셋의 문장 `L(openpr)` |
| AC9 | `## 보관과 기록 파일` | `L(prior)` · `글자가 같지 않으면 짝짓지 않는다` · 양성 짝: `## 묻기` 에 `같은 대상에 전에 물은 것이 있어도 질문은 띄운다` |
| AC8 꼴 | `## 묻기` | 질문 틀 펜스(Step 3)의 `header: "의도 점검 <n>"` · `{label: "의도다",` · `{label: "잘못 골랐다",` · `{label: "지금은 모르겠다",` 가 이 차례로 · 펜스 안에 `(권장)` 이 없다 · 고정 문장 `intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · 동작)가 맞는지를 점검한다. 아래 질문의 답은 판정을 바꾸지 않는다.` 한 번 · `한 호출에 많아야 셋` · `` `state` 가 `묻지 않음` 인 질문 `` · 음성: `같은 질문을 다시 묻지 않는다` 와 `다음에 다시 물을 수 있다` 가 파일에 없다 |
| AC13 | `## 묻기` | `L(waiting)` · `설계문서 점검의 질문과도 다른 메시지 · 다른 질문 호출` · `「답하지 않음」 으로 남기고 다시 묻지 않는다` |
| AC12 | `## 「잘못 골랐다」 의 행선` | `L(wrongspec)` · `/spec-distill:request-framing @<기록 파일의 레포 상대경로>` · `그 PR 이 머지된 뒤 친다` |
| Review Focus 4 | `## 보관과 기록 파일` | `L(remade)` (표지 `record-branch-remade`) |

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/spec-distill/tests/test_qg_review_reference.sh 2>&1 | tail -3`
Expected: 새 단언 FAIL · Task 5 단언 PASS.

- [ ] **Step 3: 세 절을 쓴다**

`## 보관과 기록 파일`:
- `### 보관` — 「담당자가 옮기는 자리는 `ledger resource-dir --roadmap <로드맵> --kind report --name qg-<대상>-<자리>-<날짜>` 가 낸 폴더다. 같은 이름의 폴더가 이미 있으면 끝에 -2, -3 … 을 붙여 앞 사본을 덮지 않는다. 그 폴더를 `## 자원` 에 적는다 — 로드맵이 끝나면 다른 자원과 함께 정리된다.」 `<자리>` 는 기록 파일 이름의 자리 글자와 같다(`spec` · `merged-pr<번호>` · `end` · `asked`).
- `### 기록 파일` — 이름 규칙(Produces 글자) · 「같은 이름이 이미 있으면 끝에 -2, -3 … 을 붙인다」 · 설계 §3 의 기록 틀을 글자 그대로 펜스에 [P2 고치면: 틀에서 `source_brief:` 줄을 뺀다]. L(noquestions) = 「질문이 하나도 없는 리뷰는 파일을 만들지 않고 `ledger add --section "쌓인 기록"` 으로 한 줄(자리 · 범위 · 결과 줄)만 남긴다 — 로드맵 끝과 이름으로 청한 로드맵은 예외로 늘 파일이 있다.」 L(sourcebrief) = 「`source_brief:` 줄은 로드맵을 보는 리뷰(로드맵 끝 · 이름으로 청한 로드맵)의 기록에만 둔다.」 [P2 고치면: L(sourcebrief) 를 넣지 않고 그 단언을 「`source_brief:` 가 틀에 없다」 로 바꾼다.] 「결과 파일의 글 칸은 글자 그대로 옮긴다. 사용자가 직접 쓴 답도 글자 그대로 적는다. 지휘자가 손으로 쓴다.」 「지난 기록은 고치지 않는다 — 답을 뒤집을 때는 새 기록이 옛 기록을 가리킨다.」
- `### 기록 브랜치` — L(branchspec) = 「spec 승인 앞의 기록은 에픽 worktree 에서 에픽 브랜치에 커밋한다 — 에픽 PR 과 함께 머지된다. 그 밖(에픽 머지 뒤 · 로드맵 끝 · 이름으로 청함 — spec 승인 전 에픽 제외)의 기록은 로드맵마다 하나인 기록 브랜치에 쓴다.」 이름(P3): 그대로 두면 — `docs/roadmap-<로드맵 폴더 이름>-reviews`. [P3 고치면: 레포 브랜치 규칙의 접두 — 아래 펜스로 얻는 `<접두>roadmap-<로드맵 폴더 이름>-reviews`(`redecompose.md` 의 로드맵 수정 브랜치와 같은 규칙):

```bash
BP="$(python3 "<SD>/scripts/repo_defaults.py" get branch_prefix)" || BP=""
[ -n "$BP" ] || { echo "[spec-distill] 브랜치 접두를 정하지 못했다 — 위 줄의 사유를 고친 뒤 다시 돌린다" >&2; exit 1; }
```
]
자리: 「기록 브랜치 worktree 는 `git worktree add "$(ledger worktree-path --name <로드맵 폴더 이름>-reviews)" <기록 브랜치>` 로 만들고(브랜치가 없으면 `-b <기록 브랜치> origin/HEAD`), `ledger add --section "자원"` 으로 「기록 브랜치 worktree」 용도로 적는다. 기록 커밋 · push · PR 은 거기서 한다.」 L(remade) = 「기록 브랜치가 이미 머지됐으면 기본 브랜치에서 다시 만든다.」 L(pushnow) = 「기록 브랜치에 쓴 기록은 답을 받은 직후 커밋하고 push 한다 — 다음 PR 을 기다리지 않는다.」 L(openpr) = 「기록 브랜치의 PR 을 여는 때는 셋이다 — 「잘못 골랐다」 가 하나라도 있으면 바로, 로드맵을 닫을 때(그 PR 이 로드맵을 닫는 PR 이다), 로드맵이 이미 닫힌 뒤 이름으로 청한 리뷰면 답을 받은 직후. 그 밖에는 push 만 해 두고 로드맵을 닫을 때 함께 연다.」 「지휘자가 여는 이 PR 들도 머지 전에 걸음 5 의 확인을 거친다.」 「에픽 머지 뒤의 기록을 쓸 때는 기록 브랜치에 기본 브랜치를 합치지 않아도 된다.」
- `### 같은 대상에 전에 물은 것` — L(prior) = 「묻기 전에 이 로드맵의 기록 파일 전부(기본 브랜치의 `reviews/` · 에픽 브랜치의 것 · 기록 브랜치의 것)에서 정체(`id`)가 글자로 같은 질문을 찾아, 있으면 가장 최근 것의 질문 글과 답을 함께 적는다 — 「같은 질문」 이라 부르지 않고 그때의 질문 글을 보여 사용자가 판단하게 한다.」 「글자가 같지 않으면 짝짓지 않는다 — 뜻이 비슷한지를 모델이 판단해 잇지 않는다.」 찾는 명령: `git grep -F -- "- 정체: <id>" origin/HEAD -- "<로드맵 폴더>/reviews/"` 와 같은 꼴을 에픽 브랜치 · 기록 브랜치 끝에도.

`## 묻기`:
- 언제 — `conducting.md` 걸음 2 의 「게이트와 게이트 사이, 대화가 끊긴 자리, 리뷰가 끝난 뒤」 그대로. 「spec 승인 앞의 질문은 spec 리뷰를 시작하기 전에 묻는다 — 설계문서 점검의 질문과도 다른 메시지 · 다른 질문 호출이다.」 질문을 걸기 직전 `python3 "<SD>"/scripts/conductor_status.py waiting add --roadmap <로드맵> --session <세션> --epic <에픽 | 로드맵 밖> --kind 옮긴 질문 --via 질문 창`(로드맵 리뷰는 `로드맵 밖`), 답을 받으면 같은 스크립트의 `waiting clear`.
- `**아직 묻지 못한 질문.**` 굵은 머리로 시작하는 문단(Task 7 의 걸음 1 들어가는 문장이 이 머리를 가리킨다)에 L(waiting) = 「담당자가 질문을 돌려줬는데 바로 묻지 못하면 `ledger add --section "기다리는 질문"` 으로 한 줄(에픽 또는 로드맵 · 기대는 일 · 「의도 점검 질문 <k>개 — <보관 폴더 경로>」)을 적는다. spec 승인 앞이면 기대는 일은 「spec 리뷰 시작」 이다. 답을 받았거나 「답하지 않음」 으로 기록하면 그 줄을 지운다(`ledger drop`). 그 줄이 남아 있는 에픽의 spec 리뷰는 시작하지 않는다.」
- 앞 글 — 따로 된 메시지로: 자리와 대상 · qg 판정 줄 그대로 · 코드 리뷰 지적 목록 · `intent-critic` 결과 줄 그대로 · 고정 문장(AC8 글자).
- `**의도 점검 질문.**` 으로 시작하는 문단 + 설계 §4 의 질문 틀 펜스를 글자 그대로. 「잘못 골랐다」 설명은 그대로 두면 두 갈래(`<spec 승인 앞: spec 리뷰로 가지 않고 설계를 고친다. | 그 밖: 새 일의 씨앗으로 남기고 다음 세션 첫 줄을 안내한다.>`). [P4 고치면: 셋째 갈래 `| spec 승인 뒤 · 머지 전 에픽: 재분해 신호로 보인다 — 설계 대화로 돌아가지 않는다.` 를 더하고 락에 그 글자를 더한다.] 이어 「라벨 셋의 글자와 순서는 qg 와 같다. 추천 표시를 달지 않는다.」 「묻는 것은 `state` 가 `묻지 않음` 인 질문이다 — 결과 파일의 순서대로, 한 호출에 많아야 셋. 넷 이상이면 호출을 나눠 이어 묻는다. `상한 넘어 남김` 은 묻지 않고 기록에만 남긴다.」 「같은 대상에 전에 물은 것이 있어도 질문은 띄운다.」 「질문 창을 닫았거나 답하지 않은 질문은 기록에 「답하지 않음」 으로 남기고 다시 묻지 않는다.」 답을 받은 뒤 한 메시지로 기록 파일 경로와 (있으면) 행선 안내.

`## 「잘못 골랐다」 의 행선`:
- L(wrongspec) = 「spec 승인 앞에서 하나라도 있으면 spec 리뷰를 시작하지 않는다 — 그 에픽의 설계 대화로 돌아가 그 질문과 답을 입력으로 설계를 고치고, 고친 설계문서 커밋에 qg 를 다시 보낸다.」 다른 에픽 경계에 닿으면 재분해 신호. spec 리뷰 skill 은 고치지 않는다.
- 에픽 머지 뒤 · 로드맵 끝 — 「기록 파일이 새 일의 씨앗이다 — 씨앗 파일을 따로 만들지 않는다.」 기록만 담은 PR 을 열고 다음 세션 첫 줄 `/spec-distill:request-framing @<기록 파일의 레포 상대경로>` 와 「그 PR 이 머지된 뒤 친다」 를 안내한다.
- 끝나지 않은 에픽에 닿으면 걸음 6 의 남은 에픽 재평가에서 재분해 신호. 「의도다」 · 「지금은 모르겠다」 는 기록만. 한참 뒤에 알아챈 경우는 입구를 새로 두지 않는다 — `/spec-distill:request-framing` 으로 말을 꺼내고 `reviews/` 에서 찾는다. [P4 고치면: spec 승인 뒤 · 머지 전 에픽 불릿을 더한다.]

- [ ] **Step 4: 통과를 확인한다**

Run: `bash plugins/spec-distill/tests/test_qg_review_reference.sh 2>&1 | tail -3`
Expected: `Fail: 0`.

- [ ] **Step 5: 변이로 이빨을 본다(커밋 뒤)**

① 질문 틀에서 `지금은 모르겠다` 와 `잘못 골랐다` 의 차례를 바꾼다 → AC8 차례 RED. ② 라벨 하나에 `(권장)` 을 붙인다 → RED. ③ 「의도다」 설명에 「같은 질문을 다시 묻지 않는다」 를 넣는다 → RED. ④ 틀의 `<observation 의 줄 전부>` 를 `<observations>` 로 → 계약 칸 락 RED. ⑤ L(pushnow) 를 「로드맵을 닫을 때 커밋한다」 로 → RED. 매번 되돌리고 확인.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/spec-distill/tests/test_qg_review_reference.sh
git commit -m "feat(spec-distill): qg 리뷰의 보관 · 기록 파일 · 묻기 · 행선 절차를 더한다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

---

### Task 7: 들어가는 문장 · 지휘자 skill · 질문 자리 목록 · 처분 검사

맡는 AC: **AC2** · **AC8**(질문 자리 목록) · **AC16**(지휘자 skill 의 규모 줄) · **AC3**(처분 검사가 그 자리를 센다) · **AC13**(걸음 3 의 들어가는 문장).

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md` — 지휘 순환 머리 불릿 · 걸음 1 · 3 · 6 · 7, 손 절차 머리 불릿 · 1 · 3 · 6 · 9
- Modify: `plugins/spec-distill/skills/epic-conductor/SKILL.md` — `### 4. 규모 공시` 의 agent 수 문장 · `## 보이기`
- Modify: `shared/tests/fixtures/ask-sites.tsv`
- Modify: `shared/tests/test_dispatch_disposition.sh` — 내장 일반 agent 의 dispatch 를 센다
- Modify: `plugins/spec-distill/tests/test_conducting_loop.sh:51` · `plugins/spec-distill/tests/test_repo_literals.sh:21`(TARGETS) · `plugins/spec-distill/tests/test_epic_conductor_skill.sh`(규모 줄 단언) · `plugins/spec-distill/tests/test_qg_review_reference.sh`

**Interfaces:**
- Consumes: Task 5 · 6 의 자리 이름 넷 · 앵커 `**의도 점검 질문.**`.
- Produces: 들어가는 문장의 공통 글자 `QE='`<SD>/skills/epic-conductor/references/qg-review.md` 를 읽고 그 자리('` — 락이 지휘 순환과 손 절차 맞은편 걸음에서 이 글자를 센다.

- [ ] **Step 1: 실패하는 단언을 쓴다**

`test_qg_review_reference.sh` 에 `conducting.md` 절:

```bash
CD="$ROOT/plugins/spec-distill/references/conducting.md"
QE='`<SD>/skills/epic-conductor/references/qg-review.md` 를 읽고 그 자리('
LOOP="$(awk '$0=="## 지휘 순환"{f=1;next} f&&/^## /{exit} f' "$CD")"
MAN="$(awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$CD")"
lstep() { printf '%s\n' "$LOOP" | awk -v n="$1" 'index($0, "### " n ". ")==1{f=1;next} f&&/^### /{exit} f'; }
mstep() { printf '%s\n' "$MAN" | awk -v n="$1" 'index($0, n ". ")==1{f=1;print;next} f&&/^[1-9]\. /{exit} f'; }
```

단언:
- 지휘 순환 걸음 3 · 6 · 7 과 손 절차 3 · 6 · 9 에 `QE` 가 각각 정확히 한 번, 각 문장의 자리 이름이 3 → `spec 승인 앞` · 6 → `에픽 머지 뒤` · 7 · 9 → `로드맵 끝`.
- 지휘 순환 머리(걸음 1 앞)와 손 절차 머리(걸음 1 앞)에 `QE` + `이름으로 청함` 한 번씩, 지휘 순환 걸음 1 과 손 절차 1 에 `QE` + `아직 묻지 못한 질문` 한 번씩(리뷰 지적 d5b0cf8b — 이름으로 청한 리뷰와 압축 뒤 남은 의도 점검 질문의 입구).
- AC2 음성 + 양성 짝: `conducting.md` 전체에 `로드맵 시작 커밋부터` 가 없다(양성: 걸음 7 에 `QE`). 절차가 새지 않았다 — `conducting.md` 전체에 `intent-return.md` · `merged_pr_range.py` · `의도 점검 <n>` · `reviews/<YYYY-MM-DD>` · `qg-<대상>-<자리>` 가 없다(양성: 같은 글자가 `qg-review.md` 에 있다).
- 걸음 7 에 `품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다` 가 남아 있다(형제 `test_superpowers_presence.sh` 의 단언이 계속 잡는다).
- `SKILL.md` 의 `### 4. 규모 공시` 에 `qg 담당자(spec 승인 앞 1 · 머지된 PR 마다 1)` 와 `로드맵 끝 qg 담당자 1` 이 한 번씩, `## 보이기` 에 `의도 점검 질문` 이 한 번.
- `ask-sites.tsv` 에 `plugins/spec-distill/skills/epic-conductor/references/qg-review.md<TAB>비움<TAB>**의도 점검 질문.**` 로 시작하는 행이 한 줄.

`test_conducting_loop.sh:51` 의 `'로드맵 시작 커밋부터'` 와 `'그 사실을 알린다'` 를 `'qg-review.md` 를 읽고 그 자리(「로드맵 끝」)'` 와 `'알리고 진행한다'` 로 바꾼다. `test_repo_literals.sh` TARGETS 에 `skills/epic-conductor/references/qg-review.md scripts/merged_pr_range.py` 를 더한다. `test_epic_conductor_skill.sh` 의 규모 줄 단언 목록(36행 근처)에 `qg 담당자` 를 더한다.

- [ ] **Step 2: 실패를 확인한다**

Run: `for t in test_qg_review_reference test_conducting_loop test_repo_literals test_epic_conductor_skill; do bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done`
Expected: 앞의 둘과 넷째가 FAIL(새 단언) · 셋째는 새 대상이 깨끗하면 PASS(깨지면 Task 4 · 5 · 6 파일을 고친다).

- [ ] **Step 3: `conducting.md` 에 들어가는 문장을 둔다**

모든 문장은 `품질 게이트 리뷰는 `<SD>/skills/epic-conductor/references/qg-review.md` 를 읽고 그 자리(「<자리 이름>」)의 줄을 따른다.` 꼴이다(절차를 풀어 쓰지 않는다). 자리:
- 지휘 순환 머리 불릿 목록 끝에 새 불릿: 「사용자가 에픽이나 로드맵 이름을 대며 리뷰를 청하면 어느 걸음에 있든 품질 게이트 리뷰는 `…qg-review.md` 를 읽고 그 자리(「이름으로 청함」)의 줄을 따른다.」 손 절차 머리 불릿 목록 끝에도 같은 불릿.
- 걸음 1 `- 판단:` 칸 끝: 「`## 기다리는 질문` 에 의도 점검 질문 줄이 있으면 `…qg-review.md` 를 읽고 그 자리(「아직 묻지 못한 질문」 — 그 파일의 `## 묻기`)의 줄을 따른다.」 손 절차 1 끝에도 같은 문장. (자리 이름 「아직 묻지 못한 질문」 은 `## 묻기` 의 그 문단을 가리킨다 — Task 6 의 L(waiting) 앞에 `**아직 묻지 못한 질문.**` 굵은 머리를 둔다.)
- 걸음 3 의 `  - spec 리뷰:` 불릿 맨 앞: 「spec 리뷰를 부르기 전에 품질 게이트 리뷰를 끝낸다 — `…qg-review.md` 를 읽고 그 자리(「spec 승인 앞」)의 줄을 따른다.」 손 절차 3 의 spec 리뷰를 말하는 문장 앞에도 같은 문장.
- 걸음 6 `- 기본값:` 칸의 첫 문장 뒤: 「머지를 확인한 PR 마다 품질 게이트 리뷰는 `…qg-review.md` 를 읽고 그 자리(「에픽 머지 뒤」)의 줄을 따른다.」 손 절차 6 에도.
- 걸음 7: `- 기본값:` 의 「그때 품질 게이트(`/quality-gates:quality-pipeline`)를 한 번, 로드맵 시작 커밋부터 지금 기본 브랜치까지 돌린다.」 를 「그때 품질 게이트 리뷰는 `…qg-review.md` 를 읽고 그 자리(「로드맵 끝」)의 줄을 따른다.」 로 바꾼다(그 뒤의 상태 브랜치 지우기 문장은 그대로). `- 판단:` 에서 「품질 게이트가 범위 입력을 받는지는 그 skill 의 인자 안내로 정한다 — 받지 않으면 품질 게이트 없이 가고 그 사실을 알린다. 지적은 후속 PR 하나로.」 를 지운다(「품질 게이트 없이 간다 …」 문장은 남긴다). `- 부를 skill:` 을 「없음(품질 게이트는 `qg-review.md` 의 담당자가 부른다).」 로. 손 절차 9 에 같은 들어가는 문장.

각 걸음의 다섯 칸(`- 기본값:` …)은 하나씩 그대로다(`test_conducting_loop.sh` 의 칸 수 단언).

- [ ] **Step 4: 지휘자 skill 두 자리**

`### 4. 규모 공시` 의 agent 수 문장에서 「통합 리뷰 1 이상에,」 를 「통합 리뷰 1 이상 · qg 담당자(spec 승인 앞 1 · 머지된 PR 마다 1)에, 로드맵 끝 qg 담당자 1 과,」 로 바꾼다(규모 줄 꼴 자체는 그대로). `## 보이기` 에 한 문장: 「qg 담당자가 돌려준 의도 점검 질문은 `qg-review.md` 의 `## 묻기` 대로 따로 된 앞 글 뒤에 묻고, 질문 문장 앞머리에 에픽 이름(로드맵 리뷰면 「로드맵」)을 쓴다.」

- [ ] **Step 5: 질문 자리 목록과 처분 검사**

`ask-sites.tsv` 에 행 하나(qg 의 같은 질문 행과 같은 종류 `비움`): `plugins/spec-distill/skills/epic-conductor/references/qg-review.md<TAB>비움<TAB>**의도 점검 질문.**<TAB>라벨 셋의 글자와 순서는 qg 와 같다.<TAB>1<TAB>` (끝 칸은 질문 틀 펜스 바로 뒤 문장 — 앵커 문단만으로는 펜스 안의 `AskUserQuestion` 이 범위에 들지 않는다. 설명 수 칸은 qg 행처럼 비운다). `bash shared/tests/test_ask_recommendation.sh` 로 덮는 수가 1 인지 본다.

`test_dispatch_disposition.sh` 는 지금 `plugins/*/agents/*.md` 의 이름으로만 dispatch 를 센다 — `qg-review.md` 의 처분 줄은 짝 없는 앵커가 되어 축 A① 이 깨진다. 에이전트 집합 도출(「1) 에이전트 집합」) 바로 뒤에 Claude Code 내장 일반 agent 하나를 더한다: `agents.setdefault("general-purpose", "(Claude Code 내장 agent)")` 와 그 까닭 주석 한 줄(내장 agent 를 부르는 자리도 처분을 밝힌다). 이 편집은 락을 넓히는 쪽이다(약화 아님). 넓힌 뒤 지금 코퍼스에서 `general-purpose` dispatch 가 `qg-review.md` 하나뿐인지(`PRINT_4_per_agent general-purpose 1`)와 `ZERO_AGENTS` 에 들지 않는지 본다. 축 B · C 가 내장 agent 의 정의 파일 경로를 요구하면 그 축에서만 이 이름을 건너뛰게 하고 그 사실을 PR 본문 몫(`$TMPDIR/pr-notes.md`)에 적는다.

- [ ] **Step 6: 통과를 확인한다**

Run: `for t in plugins/spec-distill/tests/test_qg_review_reference.sh plugins/spec-distill/tests/test_conducting_loop.sh plugins/spec-distill/tests/test_conducting_reference.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_superpowers_presence.sh plugins/spec-distill/tests/test_end_gates.sh plugins/spec-distill/tests/test_parallel_recommend_docs.sh shared/tests/test_ask_recommendation.sh shared/tests/test_dispatch_disposition.sh shared/tests/test_invocation_surface.sh; do echo "== $t"; bash "$t" 2>&1 | tail -1; done`
Expected: 모두 `Fail: 0`.

- [ ] **Step 7: 변이로 이빨을 본다(커밋 뒤)**

① 손 절차 9 의 들어가는 문장을 지운다 → 맞은편 단언 RED. ② 걸음 7 에 「로드맵 시작 커밋부터 지금 기본 브랜치까지 돌린다」 를 되살린다 → AC2 음성 RED. ③ `conducting.md` 걸음 6 에 `intent-return.md` 를 읽으라는 문장을 넣는다 → 절차 새어 듦 RED. ④ `qg-review.md` 의 처분 줄을 지운다 → `test_dispatch_disposition.sh` RED(넓힌 축이 이빨을 가졌다는 양성 대조). ⑤ ask-sites 행을 지운다 → `test_ask_recommendation.sh` 전수 검사 RED.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/references/conducting.md plugins/spec-distill/skills/epic-conductor/SKILL.md shared/tests/fixtures/ask-sites.tsv shared/tests/test_dispatch_disposition.sh plugins/spec-distill/tests/test_conducting_loop.sh plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_qg_review_reference.sh
git commit -m "feat(spec-distill): 지휘 절차의 네 자리에서 qg 리뷰 절차로 들어가게 한다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

---

### Task 8: spec-distill README · dependencies · 판 · CHANGELOG

맡는 AC: **AC18**(spec-distill 쪽).

**Files:**
- Modify: `plugins/spec-distill/README.md`(Prerequisites 의 quality-gates 줄)
- Modify: `plugins/spec-distill/dependencies.md`(quality-gates 행)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`
- Test: `plugins/spec-distill/tests/test_qg_review_reference.sh`

- [ ] **Step 1: 실패하는 단언을 더한다**

README `## Prerequisites` 의 `- **quality-gates**` 줄에 `spec 승인 앞 · 에픽 머지 뒤 · 로드맵 끝 · 이름으로 청한 리뷰` · `품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다` · `리뷰할 diff 없음`, 음성 짝으로 `걸음 7 이 범위 입력을 받으면` 이 없다. `dependencies.md` 의 `| quality-gates |` 행 「없을 때」 칸에 `자리 넷` 이 든다.

- [ ] **Step 2: 실패를 확인한다** — Run: `bash plugins/spec-distill/tests/test_qg_review_reference.sh 2>&1 | tail -3` · Expected: 새 단언 FAIL.

- [ ] **Step 3: 고친다**

README quality-gates 줄을 이 글로 바꾼다:

> - **quality-gates** (같은 마켓플레이스, optional) — 지휘자가 자리 넷(spec 승인 앞 · 에픽 머지 뒤 · 로드맵 끝 · 이름으로 청한 리뷰)에서 담당자를 시켜 `/quality-gates:quality-pipeline range <시작>..<끝> --origin <원문>` 을 부르고, 돌아온 의도 점검 질문을 사용자에게 옮겨 묻는다. 설치돼 있지 않으면 그 자리마다 「품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」를 알리고 진행한다. qg 의 문서 경로 설정이 `docs/` 를 거르는 레포에서는 spec 승인 앞과 로드맵 끝의 리뷰가 「리뷰할 diff 없음」 건너뜀으로 끝난다.

`dependencies.md` quality-gates 행 「없을 때」: 「지휘자의 품질 게이트 자리 넷(spec 승인 앞 · 에픽 머지 뒤 · 로드맵 끝 · 이름으로 청한 리뷰)이 자리마다 「품질 게이트 없이 간다」를 알리고 진행한다」. 판 칸은 손으로 고치지 않는다 — `python3 plugins/spec-distill/scripts/check_deps.py measure --plugin-root plugins/spec-distill` 을 돌려 잰 값을 쓴다(다른 행이 함께 바뀌면 그대로 두고 PR 본문 몫에 적는다).

`plugin.json` `version` 을 그때의 origin/main 판 위 minor 로, CHANGELOG 맨 위에 같은 판 머리와 `### Added`(`skills/epic-conductor/references/qg-review.md` — 자리 넷 · 담당자 · 기록 파일 · 묻기 · 행선 / `scripts/merged_pr_range.py`) · `### Changed`(지휘 절차 걸음 1 · 3 · 6 · 7 과 손 절차의 들어가는 문장 · 걸음 7 의 「로드맵 시작 커밋부터」 호출을 로드맵 끝 리뷰로 · 규모 줄의 qg 담당자 · README · dependencies.md).

- [ ] **Step 4: 통과를 확인한다**

Run: `for t in plugins/spec-distill/tests/test_qg_review_reference.sh plugins/spec-distill/tests/test_superpowers_presence.sh shared/tests/test_changelog_integrity.sh; do bash "$t" 2>&1 | tail -1; done`
Expected: 모두 `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/README.md plugins/spec-distill/dependencies.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/tests/test_qg_review_reference.sh
git commit -m "docs(spec-distill): quality-gates 의존 줄을 자리 넷으로 고치고 판을 올린다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

---

### Task 9: 미룬 행 확인 · 전체 스위트 · 마지막 전체 리뷰

맡는 AC: **AC19** · **AC20**, 그리고 마지막 전체 리뷰가 AC1 – AC24 전부를 판정한다.

**Files:** 설계문서 `## 미룸` 표(행 더하기만 — 필요할 때) · 보고 파일은 git 이 추적하지 않는 자리(`$TMPDIR/ac-report.md`).

- [ ] **Step 1: AC19 — 미룬 행 24 이 모두 처리 칸을 가진다**

```bash
awk '$0=="## 미룬 행 대조"{f=1;next} f&&/^## /{exit} f&&/^\| [0-9]+ \|/' docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md | awk -F'|' '$5 ~ /[^ ]/' | wc -l
```

Expected: `24`. 아니면 멈추고 보고한다(설계문서 본문은 고치지 않는다).

- [ ] **Step 2: AC20 — 전체 스위트를 잠금 아래 한 번**

Run: `python3 "<SD>"/scripts/suite_lock.py run --lock <지휘자가 주는 스위트 잠금 경로> --owner <agent 이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'`
Expected: `FAILED` 줄이 없거나, 있으면 이름마다 기본 브랜치에서도 실패하는지 본다(worktree 에서만 나는 기존 실패 `TestCrossResolverAdvisory` 는 알려진 것). 이 브랜치에만 있는 실패는 고친다. 최종 대조는 지휘자의 머지 전 스위트 대조가 한다.

- [ ] **Step 3: 마지막 전체 리뷰 — AC 마다 한 줄**

고른 실행 방식의 마지막 전체 리뷰(쓰기 도구가 없는 리뷰어)에 아래를 싣는다:
- 설계문서 `## Acceptance Criteria` 의 AC1 – AC24 원문 전체.
- 「AC 마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴로 보고하라(판정은 구현됨 · 미룸 · 빠짐 중 하나, 근거는 파일:줄 또는 테스트 이름).」
- 「설계문서 `## 있는 것 검토` 절이 고른 것(qg 의 `range` · `--origin` 입구 · 결과 파일 계약 2판 · 기계 상태 PR 캐시의 머지 커밋 · head 커밋 · qg 의 바뀐 의도 문서 따라가기 · `git patch-id` · `conductor-dispatch.md` 의 보내는 글 방식 · `ledger resource-dir` 와 `## 자원` · `## 쌓인 기록` · `## 작업` · 걸음 2 의 따로 묻는 규칙 · qg 질문 꼴의 글자 · 설계 대화로 돌아가는 길 · `/spec-distill:request-framing`)을 실제로 썼는지, 같은 것을 다시 만들지 않았는지 묻는다 — 특히 범위 확인 스크립트가 상태 계산 · 원장을 다시 짓지 않았는지, 지휘자가 qg 답 파일 꼴을 흉내 내지 않았는지.」
- 리뷰 초점(설계 Verification Plan): 계획이 시킨 테스트 코드 자체(이 계획이 쓴 테스트라는 라벨을 단다) · 새 파일이 자기 출처나 배경을 적지 않고 행동만 적는지 · `conducting.md` 에 절차가 새어 들어가지 않았는지 · 기록 틀의 칸이 계약 2판의 칸 이름과 맞는지 · 끝에서 끝 흐름(걸음 6 의 머지 확인 → 범위 스크립트 rc → 담당자 → 보관 → 기록 → 묻기 → 기록 브랜치 push)의 rc 소비와 상태 가정.
- 이 스위트 잠금 줄과 경로.

리뷰가 낸 AC 보고를 `$TMPDIR/ac-report.md` 에 그대로 적는다(git 이 추적하지 않는 자리).

- [ ] **Step 4: 미룸을 표에 올리고 대조 스크립트를 돌린다**

미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 행으로 더한다(그 밖의 본문은 고치지 않는다). 그다음:

Run: `python3 "<SD>"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md "$TMPDIR/ac-report.md"`
Expected: 경고가 있으면 그대로 마지막 보고에 싣는다(사용자에게 보인다).

- [ ] **Step 5: 커밋**

`## 미룸` 에 행을 더했으면:

```bash
git add docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md
git commit -m "docs(spec): R3 구현이 미룬 것을 미룸 표에 올린다" -m "Spec: docs/superpowers/specs/2026-11-20-conductor-qg-entry-design.md"
```

마지막 보고에 판정 목록 전체 · AC 보고 전체 · `$TMPDIR/pr-notes.md` 의 내용 · 대조 스크립트 출력을 싣는다(실행 방식이 작업 폴더를 지울 수 있다).

---

## 계획이 정한 것(설계가 계획에 넘긴 것)

- 들어가는 문장의 글과 자리 — Task 7 Step 3. 설계가 적은 걸음 3 · 6 · 7 과 손 절차 3 · 6 · 9 에 더해, 리뷰 지적 d5b0cf8b 대로 지휘 순환 · 손 절차의 머리(이름으로 청함)와 걸음 1 · 손 절차 1(아직 묻지 못한 질문)에도 같은 꼴의 문장을 둔다.
- `qg-review.md` 의 절 나누기 — `## 호출 줄` · `## 자리` · `## 담당자` · `## 돌아왔을 때` · `## 보관과 기록 파일` · `## 묻기` · `## 「잘못 골랐다」 의 행선`.
- 다음 세션 첫 줄 — `/spec-distill:request-framing @<기록 파일의 레포 상대경로>`(그 skill 의 `### 2. @경로 풀기` 가 받는 꼴).
- 범위 확인 스크립트 — 이름 `merged_pr_range.py` · 인자 두 꼴 · rc 0 · 2 · 3 · 4 · 비교는 patch-id 로 좁히고 공백을 보존한 diff 글자로 확인(리뷰 지적 cddb035a).
- qg 의 범위 모드 테스트 가운데 고칠 것 — 2026-11-20 조사로 없음(있으면 Task 3 Step 4 가 고치고 PR 본문에 적는다).
- 질문 자리 목록 행 — 종류 `비움` · 앵커 `**의도 점검 질문.**`.
- 테스트 자리 — 새 `test_merged_pr_range.py` · 새 `test_qg_review_reference.sh` · qg 쪽은 있는 `test_intent_wide.py` · `test_setup_qg.sh` · `test_intent_critic_wiring.sh`.
- 측정 대상 — 측정 가 R5 머지 커밋 `269ead33` · 측정 나 이 브랜치의 설계문서만 든 범위 `3b4e582a..828a7cbc`.
- 이미 보낸 리뷰의 표지(3라운드 참고 지적) — 새 표지를 두지 않고 보관 폴더 이름(`qg-<에픽>-merged-pr<번호>-`)과 쌓인 기록 줄로 가린다(Task 5 L(alreadysent)).
- 기록 브랜치를 쓰는 자리(3라운드 참고 지적) — 전용 worktree(`ledger worktree-path --name <로드맵 폴더 이름>-reviews`)를 `## 자원` 에 「기록 브랜치 worktree」 로 적는다(Task 6).
- 기본 브랜치에 #306 이 더한 질문 걸기 기록 — 의도 점검 질문은 `conductor_status.py waiting add --kind 옮긴 질문 --via 질문 창`(로드맵 리뷰는 `--epic 로드맵 밖`)으로 올리고 답 뒤 내린다(Task 6).
- 처분 검사 넓히기 — `test_dispatch_disposition.sh` 가 내장 `general-purpose` agent 의 dispatch 도 세게 한다(Task 7 Step 5). 이 자리의 처분 줄(AC3)이 검사에 짝 없는 앵커로 걸리지 않게 하는 유일한 길이고, 락을 넓히는 쪽이다.

## 설계에 없던 결정

다섯 항목 모두 설계문서 `### Deferred to plan` 의 3라운드 참고 지적에서 왔다. 지휘자가 사용자에게 묻고 답을 이 계획 첫머리 「열린 결정」 표 옆에 적는다.

**P1 — 범위 모드에서 바뀐 문서를 따라가는 조건**(f4958e73#r3.1)
- 무엇을 정하나: qg 가 범위로 부른 리뷰에서 바뀐 의도 문서의 머리 줄을 언제 따라가는가.
- 그대로 두면: 모든 범위에서, 바뀐 파일 가운데 문서 파일이고 모델이 읽지 않는 것의 머리 줄을 따라간다(AC21 글자대로). 코드가 섞인 에픽 머지 뒤 범위에서도 돌아, 그 에픽이 고친 `tests/` 아래 마크다운 픽스처의 `roadmap:` · `source_brief:` 머리까지 따라가 없는 로드맵을 읽으려 하거나(「로드맵 링크 거부」 공시) 묶음에 더해 인터뷰 문서 전체가 실릴 수 있다(`doc_paths` 의 모델 읽기 폴더에 `tests` 가 없다).
- 고치면: PR 범위와 같은 조건 — 바뀐 파일이 모두 문서 파일이고 모델이 읽는 파일이 없을 때만 따라간다. spec 승인 앞과 로드맵 끝은 문서만 바뀐 범위라 그대로 되고, 에픽 머지 뒤는 지금 동작 그대로다. AC21 에 그 조건이 붙는다.
- 권고: 고치면. 이 에픽이 필요로 하는 두 자리는 그대로 되고 qg 의 바뀌는 폭이 작아진다. P2 의 까닭(인터뷰 문서가 두 번 실림)도 사라진다.

**P2 — 기록 머리의 `source_brief:` 줄**(57a6de72#r3.1)
- 무엇을 정하나: 로드맵을 보는 리뷰의 기록 파일 머리에 처음 인터뷰 문서 줄을 둘지.
- 그대로 두면: 로드맵 끝 · 이름으로 청한 로드맵의 기록에만 `source_brief:` 를 두는 규칙과 AC10 의 그 문장이 남는다. 호출 줄이 이미 같은 파일을 `--origin` 으로 넘겨 하는 일은 없다(qg 가 같은 파일을 한 번만 싣는다).
- 고치면: 기록 머리에서 `source_brief:` 줄과 「로드맵을 보는 기록에만」 규칙, AC10 의 마지막 문장을 뺀다. 사람은 기록의 `roadmap:` 줄에서 로드맵 머리말로 따라가 인터뷰 문서에 닿는다.
- 권고: 고치면. 규칙 하나와 수용 기준 한 문장이 줄고 동작은 같다.

**P3 — 기록 브랜치 이름**(3라운드 참고 지적 — 표 아래 둘째)
- 무엇을 정하나: 로드맵마다 하나인 기록 브랜치의 이름 규칙.
- 그대로 두면: 설계 글자대로 `docs/` 로 시작하는 이름(`docs/roadmap-<로드맵 폴더 이름>-reviews`). 다른 접두를 쓰는 레포에서도 `docs/` 로 박힌다(레포 전용 값).
- 고치면: 레포의 브랜치 접두 해결자(`repo_defaults.py get branch_prefix`)로 `<접두>roadmap-<로드맵 폴더 이름>-reviews` — 로드맵 수정 PR 브랜치(`redecompose.md`)와 같은 규칙. 이 레포에서는 지금 `feature/roadmap-…-reviews` 가 된다.
- 권고: 고치면. 설계의 「레포 전용 값을 박지 않는다」 제약과 있는 규칙에 맞는다.

**P4 — 「잘못 골랐다」 설명의 셋째 갈래**(3라운드 참고 지적 — 표 아래 셋째)
- 무엇을 정하나: 질문 창의 「잘못 골랐다」 설명에 spec 승인 뒤 · 머지 전 에픽(이름으로 청한 리뷰)의 갈래를 더할지.
- 그대로 두면: 설명이 두 갈래(spec 승인 앞 · 그 밖)뿐이라, 그 에픽에서 사용자가 보는 설명(「새 일의 씨앗으로 남긴다」)과 실제 행선(재분해 신호로 보인다 — §1)이 다르다.
- 고치면: 셋째 설명 「재분해 신호로 보인다 — 설계 대화로 돌아가지 않는다」 를 더하고 행선 절에도 그 갈래를 적는다. 사용자에게 보이는 선택지 설명 한 갈래가 늘어난다.
- 권고: 고치면. 보이는 설명이 실제 동작과 같아진다.

**P5 — spec 승인 앞에서 spec 리뷰로 넘어가는 조건**(3라운드 참고 지적 — 표 아래 넷째)
- 무엇을 정하나: 질문이 돌아오지 않은 경우(질문 없음 · 리뷰가 돌지 않음 · 결과를 가져오지 못함) spec 리뷰로 언제 가는가.
- 그대로 두면: 「질문을 한 번 띄우기 전에는 spec 리뷰를 시작하지 않는다」(AC13 글자)만 있어, 질문이 없는 경우에 언제 가는지가 글로 없다 — 지휘자가 그때마다 판단한다.
- 고치면: 「담당자가 돌아와 결과를 보인 뒤」 로 적고, 질문이 없거나 리뷰가 돌지 않았거나 결과를 가져오지 못했으면 그 사실을 보이고 기록한 뒤 간다고 나열한다(「잘못 골랐다」 가 있으면 가지 않는다). AC13 의 조건 문장이 넓어진다.
- 권고: 고치면. §1 의 「셀 수 없이 끝난 리뷰는 하지 못한 것으로 남는다」 와 맞고 멈춰 서는 자리가 없어진다.
