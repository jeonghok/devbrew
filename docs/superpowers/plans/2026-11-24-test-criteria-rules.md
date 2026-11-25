# 테스트 기준과 규칙 문서 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 맷 포콕 tdd skill 본문 세 파일을 `docs/testing.md` 아래쪽에 글자 그대로 싣고, 그 위에 이 레포의 테스트 기준(절 열)을 적고, 루트 `CLAUDE.md` 의 한 항목과 `docs/plugin-authoring.md` 의 한 줄이 그 문서를 가리키게 하며, 그 항목이 지워지면 헌장 인용 락이 실패하게 한다.

**Architecture:** 새 문서 넷(기준 문서 · 고지 파일 · 지운 것 기록 · 알림 글)과 가리키는 줄 둘, 있는 락(`shared/tests/test_charter_citations.sh`)에 확인 하나. 기준과 원문을 한 파일에 두는 꼴은 `plugins/spec-distill/references/existing-first.md` + `existing-first.NOTICE.txt` 를 따른다. 먼저 설계문서 본문에서 2라운드 참고 일곱이 짚은 어긋남을 맞추고, 새 문서는 맞춘 본문을 따른다.

**Tech Stack:** 마크다운 · bash 테스트(`shared/tests/assert.sh`) 안의 python3 판정 코어 · git(색인 · 클론) · `gh api`(상류 커밋 확인).

**Spec:** `docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md`(승인 2026-11-24 · 커밋 e09e6590). 설계문서 끝의 「### Deferred to plan」 표 가운데 `#r2` 로 끝나는 참고 일곱과 `2e6610eb#r1.1` 을 이 계획이 받는다 — 일곱의 원문은 `gate-r2.md`(리뷰 상태 폴더)의 「이 라운드의 지적 원문」 이고, 설계문서 표에는 그 가운데 다섯만 실려 있다(`e4d45dbb#r2.2` · `e7ee34d1#r2.1` 은 게이트 원문에만 있다). `#r1` 로 끝나는 참고 다섯은 본문에 이미 반영됐다 — 다시 하지 않는다.

## Global Constraints

- 바꾸는 파일은 설계 [Files to Modify] 와 같다 — 새로: `docs/testing.md` · `docs/testing.NOTICE.txt` · `docs/removed-tests.md` · `docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/test-criteria-notice.md`. 고침: `CLAUDE.md`(항목 하나 더함) · `docs/plugin-authoring.md`(한 줄 바꿈) · `shared/tests/test_charter_citations.sh`(확인 하나 더함) · 설계문서 본문 · 이 계획. `plugins/` 아래와 `docs/superpowers/roadmaps/worker/` 아래는 한 파일도 바꾸지 않는다. 판을 올리지 않는다.
- `CLAUDE.md` 와 `shared/tests/test_charter_citations.sh` 는 더한 줄만 있다(`git diff --numstat` 의 지운 줄 0).
- 설계문서의 「## 결정 기록」 · 「### Deferred to plan」 · 「## 지휘 기록」 은 고치지 않는다.
- 원문은 글자 그대로 싣고 풀이를 붙이지 않는다. 원문과의 차이는 고지 파일의 「뺀 것」 · 「제자리 수정」 목록과 정확히 같다(AC9).
- 규칙 문서(`docs/testing.md` 위쪽 · `CLAUDE.md` 항목)는 배경 · 이력 · 진단 숫자 · 자기 출처를 싣지 않는다(설계 §3 머리 · CLAUDE.md 「Self-narrating artifact」).
- 새 테스트 파일을 만들지 않는다. 기준 문서의 문장을 무는 확인을 만들지 않는다. 원문 대조 스크립트 · 사본은 `$TMPDIR` 에 두고 커밋하지 않는다.
- 문서는 한국어가 기본이다. 사람에게 보이는 보고는 첫 줄에 상태, 번호 · 해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 끝에 할 일(기본 하나).
- 커밋: Conventional Commits + 한국어 설명, pathspec 으로만(`git add <경로>` · `git commit -- <경로>`). 꼬리에 구현 커밋마다 `Spec: docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md`, 그리고 그 agent 모델의 `Co-Authored-By` 줄과 `Claude-Session: https://claude.ai/code/session_013DBLoQzwpjuxtVa85VfBH1`. 커밋 뒤 `git push origin HEAD:feature/test-criteria-rules`.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 뒤로 옮기기. 지우는 것은 자기가 만든 경로를 이름으로만.
- `TMPDIR=/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/tmp/<agent 이름>`(Write · Edit 도구로는 못 쓴다 — 셸로 쓴다. 셸로도 막히면 worktree 안 `.claude/tmp/<agent 이름>` 을 쓰고 그 경로를 보고한다). 복합 셸 명령은 `$TMPDIR` 의 스크립트 파일로 돌린다.
- 전체 스위트는 `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-20-test-method-rework-brief/files/suite-lock --owner <이 agent 이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'` 으로만 돌린다(지휘자 대조와 같은 공유 잠금 — 기다림은 줄이고, 못 잡으면 주인 · 잡은 시각을 보고). 과제 구현 agent 에게는 전체 스위트를 맡기지 않는다 — Task 7 에서 컨트롤러가 한 번 돌린다. 하위 agent 에게 보내는 글에는 이 줄과 경로를 그대로 싣는다. 과제 안의 좁은 테스트는 잠금 없이 돌린다.
- 하위 agent 를 띄울 때마다 superpowers subagent-driven-development 의 「Model Selection」 으로 모델을 골라 이름으로 지정하고 이유를 한 줄 적는다.
- 원문 자리: `/Users/jeonghokim/.claude/plugins/cache/mattpocock/mattpocock-skills/1.3.2/skills/engineering/tdd/`(작업 폴더 밖 — Read 가 막히면 셸 `cat`). SHA-256 이 AC10 값과 다르면 멈추고 알린다.
- 테스트 실행 꼴: 셸 테스트 `bash <경로>`, python 테스트 `python3 -m unittest discover -s <폴더> -p <파일 이름>`. 판정은 rc 0 과 출력의 `✗` · `FAIL:` · `ERROR:` 없음.

## Review Focus

1. **원문을 옮기며 글자가 바뀐다** — 굽은 따옴표 · `_imagined_` 같은 밑줄 강조 · `→` · 줄 끝 공백 · 코드 펜스 안 들여쓰기 · 마지막 줄바꿈. 기대: 원문과의 차이가 고지 목록뿐이다. Task 4 의 대조 스크립트가 줄 단위로 잰다. 그 스크립트에 글자 하나 바꾼 사본을 먹여 차이를 보고하는지(양성 대조)도 본다.
2. **제자리 수정한 링크 · 가리키는 줄의 앵커가 실제 제목과 안 맞는다.** 기대: `#good-and-bad-tests` · `#when-to-mock` · `testing.md#망가뜨려-보기` 가 가리키는 제목이 `docs/testing.md` 에 꼭 한 번씩 있다. Task 4 Step 5 · Task 5 Step 6 이 잰다.
3. **새 확인이 엉뚱한 인용으로 만족된다** — `docs/testing.NOTICE.txt` 나 `docs/testing.md.bak` 만 인용해도 통과. 기대: 경로가 정확히 `docs/testing.md` 일 때만 통과한다. Task 5 Step 7 의 사본 C 가 잰다.
4. **새 문서와 바꾼 줄이 부재 코퍼스 락에 걸린다** — `docs/` 를 통째로 훑는 스윕(`test_publish_surface_removed.sh`) · `CLAUDE.md` 와 `docs/plugin-authoring.md` 를 훑는 부재 락(`test_law2_prose.sh` · `test_governance_no_capability_caps.sh`). 기대: Task 1 목록의 테스트가 바꾼 뒤에도 전부 통과한다. Task 3 Step 4 · Task 5 Step 8 이 돌린다.
5. **판정 코어에 더한 긴 한글 문자열이 CPython 토크나이저를 깨뜨린다**(긴 비ASCII 줄의 Non-UTF-8 SyntaxError). 기대: 락이 판정 코어 죽음(`판정 코어가 죽었다`) 없이 돈다. Task 5 의 메시지는 짧은 줄 · 인접 문자열로 나눈다 — Step 2 · 4 의 실행이 잰다.

---

### Task 1: 가벼운 다시 확인 · 두 규칙 문서를 읽는 테스트 목록 (AC17)

**Files:** 고치지 않는다. 산출: `$TMPDIR/e2-recheck.md`(확인 결과) · `$TMPDIR/e2-readers.tsv`(목록 — 칸: 테스트 경로 · 읽는 것 · 실행 명령 · 기준선 결과).

**Interfaces:**
- Produces: `$TMPDIR/e2-readers.tsv` — Task 3 · 5 · 7 이 이 목록의 「실행 명령」 칸을 그대로 돌린다.

- [ ] **Step 1: 설계가 근거로 든 자리가 지금도 그런지 본다**

| 근거 | 확인 | 기대 |
|---|---|---|
| `CLAUDE.md` Law 3 아래 목록 끝 | `grep -n '^- \*\*있는 것 먼저\.\*\*' CLAUDE.md` 와 그 다음 줄들 | 한 줄 · 그 뒤 빈 줄 · `## Plugin Shape` |
| `docs/plugin-authoring.md` 변이 줄 | `grep -cF '락을 쓰거나 고치면 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다. 부재 락에는 양성 짝을 둔다.' docs/plugin-authoring.md` | 1 · 같은 목록의 다른 줄 넷(별도 모듈 · 코퍼스 락 찾기 · 실행 비트 · 내용으로 싣기) |
| 역할 문서는 틀과 바이트가 같다 | `grep -n 'def test_repo_copies_are_the_templates' plugins/spec-distill/tests/test_team_files.py` | 한 줄 |
| 보내는 글 틀은 레포 문서를 가리키지 않는다 | `grep -nE 'docs/(testing|plugin-authoring)' plugins/spec-distill/references/conductor-dispatch.md` | 0건 |
| 헌장 인용 락이 추적 파일을 색인에서 읽고 `CLAUDE.md` 의 백틱 · 링크 경로 실재를 잰다 | `shared/tests/test_charter_citations.sh` 의 `git("ls-files")` · `UNTRACKED_CITED` · 「그 경로가 리포에 없다」 | 셋 다 있다 |
| 원문 세 파일 | `shasum -a 256` 세 파일 | AC10 의 세 값 |
| 고지 선례 | `plugins/spec-distill/references/existing-first.md` · `existing-first.NOTICE.txt` | 둘 다 있다 |
| 지운 것 기록의 선례 | `grep -n 'test_review_floor_lock.sh' plugins/quality-gates/CHANGELOG.md` | 「지운 테스트 · 대신 맡는 테스트 · 이유」 줄 |
| E4 묶음의 열린 물음 | `grep -nE 'OQ18|OQ20' docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/E4.md` | 둘 다 `[열림]` |
| Constraints 의 테스트 여섯 | 여섯 경로가 추적 파일이다 | 여섯 |

하나라도 다르면 여기서 멈추고 달라진 것을 보고한다(다음 과제로 가지 않는다).

계획을 쓸 때(2026-11-24) 확인한 것: 위 열 줄이 모두 그대로였다. 원문 폴더에는 세 파일 밖에 `agents/openai.yaml`(다른 도구의 화면 이름 · 짧은 설명, SHA-256 `ea6f01cf1b8c06a4b0f5b649d74b1b8ce8685e72af1b38d70d877693e092af0b`)이 있다 — 본문이 아니라 싣지 않고, 고지 파일에 「싣지 않은 파일」 로 적는다(Task 4).

- [ ] **Step 2: 두 규칙 문서와 새 경로를 코퍼스로 읽는 테스트를 찾는다**

Run: `git grep -l -E 'CLAUDE\.md|plugin-authoring' -- 'shared/tests/*' 'plugins/*/tests/*' 'tools/*'` 로 후보를 뽑고, 파일마다 열어 루트 `CLAUDE.md` 나 `docs/plugin-authoring.md` 의 **내용을 읽는** 것만 남긴다(주석 속 언급 · 다른 레포의 `CLAUDE.md` · 역할 문서 `CLAUDE.md` 는 뺀다). 이어서 새 경로 넷(`docs/testing.md` · `docs/testing.NOTICE.txt` · `docs/removed-tests.md` · 알림 글)이 드는 코퍼스 — `git ls-files -- docs` 처럼 `docs/` 를 통째로 훑거나 `docs/superpowers/roadmaps/` 를 읽는 테스트 — 를 같은 방법으로 찾는다.

Expected: 목록이 Constraints 의 여섯(`shared/tests/test_charter_citations.sh` · `shared/tests/test_invocation_surface.sh` · `shared/tests/test_cost_disclosure.sh` · `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `plugins/quality-gates/tests/test_law2_prose.sh` · `plugins/spec-distill/tests/test_walk_docs.py`)을 포함한다. 계획을 쓸 때 미리 훑어 더 나온 후보: `plugins/plugin-audit/tests/test_check_shape_completeness.py`(§Plugin Shape) · `plugins/spec-distill/tests/test_epic_conductor_skill.sh`(cost 줄) · `plugins/quality-gates/tests/test_publish_surface_removed.sh`(`docs` 통째 스윕). 이 셋도 열어 보고 판정한다.

- [ ] **Step 3: 목록의 테스트를 지금(바꾸기 전) 돌려 기준선을 적는다**

Run: 목록의 「실행 명령」 을 하나씩. Expected: 전부 통과. 바꾸기 전에 실패하는 것이 있으면 「기준선 실패」 로 적고 보고한다 — 이 일의 회귀로 세지 않는다.

- [ ] **Step 4: 결과를 보고한다** (커밋 없음 — `$TMPDIR` 의 두 파일 경로와 요약).

---

### Task 2: 설계문서 본문의 어긋난 일곱 자리를 맞춘다

**Files:**
- Modify: `docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md` — 아래 일곱 줄만.

**Interfaces:**
- Produces: 맞춘 설계 본문 — Task 3(§3 의 7 · 10 · §5) · Task 6(§6) 이 이 본문을 따른다.

- [ ] **Step 1: 일곱 줄을 바꾼다**

자리마다 「찾을 글」(설계문서에서 꼭 한 번 나온다 — 줄 번호는 커밋 e09e6590 기준)을 「바꾼 글」 로 바꾼다. 펜스 안에서 머리(「찾을 글: 」 · 「바꾼 글: 」) 뒤의 글자 그대로다.

1. §3 의 7 셋째 점(176행) · `e4d45dbb#r2.2`
   ```
   찾을 글: 8번의 「못 대면 지운다」 를 쓰지 않는다.
   바꾼 글: 8번의 「못 대면 지운다」 · 「글자에 묶였으면 줄인다」 를 쓰지 않는다.
   ```
2. §3 의 10 셋째 점(194행) · `e4d45dbb#r2.1` — 그 줄 전체
   ```
   찾을 글: - 지운 테스트마다 `docs/removed-tests.md` 에 한 줄을 남긴다(§5). 합치기와 줄이기는 남기지 않는다 — 지키던 것이 남아 있다.
   바꾼 글: - 확인이 다른 테스트로 옮겨지지 않고 사라지면 판정이 어느 줄이든 `docs/removed-tests.md` 에 한 줄을 남긴다(§5). 상대가 이미 다 지켜 옮길 것이 없던 것은 「지금 지키는 것」 에 그 경로를 적는다. 확인을 옮긴 합치기와 줄이기는 남기지 않는다 — 지키던 것이 남아 있다.
   ```
3. §5 줄 꼴(214행) · `94ee7b34#r2.1` · `e4d45dbb#r2.1`
   ```
   찾을 글: 판정: <§8 의 어느 줄>
   바꾼 글: 판정: <`docs/testing.md` 「값 대비 비용」 의 어느 줄>
   ```
4. §6 표의 E4 행(229행) · `e7ee34d1#r2.1` — 둘째 칸 맨 앞에 더한다
   ```
   찾을 글: | 이 로드맵 E4 | 가르는 차례(§3 의 8)
   바꾼 글: | 이 로드맵 E4 | 글자 확인 기준 — 「행동을 정하는 문장」 규칙(§3 의 5)은 이 설계가 정했다(E4 묶음이 열린 채 든 물음 OQ18 가운데 규칙은 닫혔고, 테스트마다 대어 보는 일이 E4 몫이다) · 가르는 차례(§3 의 8)
   ```
5. 인터뷰와 달라진 것 표 둘째 행(257행) · `7ea40468#r2.1`
   ```
   찾을 글: 계획 3 은 문장을 무는 테스트를 새로 더하며 사용자가 「의도다」 로 답했다
   바꾼 글: 계획 3 은 문장을 무는 테스트를 새로 더하며, 사용자가 「의도다」 로 답했다고 앞단 지휘 세션이 알렸다(기록은 이 레포에서 확인하지 못했다 — §6)
   ```
6. 상류 · 하류 연계의 넘기는 곳(295행) · `0dc75b00#r2.1`
   ```
   찾을 글: E4(§3 의 7 · 8 · 10)
   바꾼 글: E4(§3 의 5 · 7 · 8 · 10)
   ```
7. 미룸 표 셋째 행(374행) · `0459cd4a#r2.1`
   ```
   찾을 글: 같은 알림 글의 E4 행 — 가르는 차례
   바꾼 글: 같은 알림 글의 E4 행 — 「행동을 정하는 문장」 규칙은 이 설계가 정했고 테스트마다 대어 보는 일이 E4 몫이다 · 가르는 차례
   ```

- [ ] **Step 2: 바뀐 것이 일곱 줄뿐인지 본다**

Run: `git diff --numstat -- docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md` 와 `git diff -U0 -- <같은 경로> | grep '^@@'`
Expected: `7	7` · 바뀐 줄이 모두 「## 결정 기록」(463행) 앞이다.

- [ ] **Step 3: 커밋**

```bash
git add docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md
git commit -m "docs(spec): 설계 리뷰 2라운드 참고 일곱이 짚은 본문 어긋남을 맞춘다 (E2)" -- docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md
```

---

### Task 3: 기준 문서 위쪽 · 지운 것 기록 (AC1 · AC2 · AC3 · AC4 · AC5 · AC6 · AC7 · AC8 · AC11)

**Files:**
- Create: `docs/testing.md`(위쪽 — 제목 · 첫 문단 · 절 열)
- Create: `docs/removed-tests.md`

**Interfaces:**
- Consumes: Task 2 가 맞춘 설계 §2 · §3 · §5.
- Produces: `docs/testing.md` 의 절 제목 열 — 번호 없이 `## 적용 범위` · `## 좋은 테스트` · `## 테스트할 자리` · `## 쓰는 차례` · `## 글을 무는 확인` · `## 망가뜨려 보기` · `## 보안 갈래` · `## 값 대비 비용` · `## 새 테스트가 하지 않는 것` · `## 지우기 · 합치기 · 줄이기의 승인과 기록`. Task 4 는 이 아래에 원문을 붙이고, Task 5 의 가리키는 줄은 `testing.md#망가뜨려-보기` 를 쓴다.

- [ ] **Step 1: `docs/testing.md` 위쪽을 쓴다**

- 첫머리: `# 테스트 기준` 과 한 문단 — 이 레포에서 테스트를 쓰거나 고치거나 지울 때 따른다 · 아래 「원문」 은 맷 포콕 tdd skill 본문이다(고지: [`testing.NOTICE.txt`](testing.NOTICE.txt)) · 위쪽과 원문이 다르면 위쪽이 앞선다.
- 절 열 열 개를 위 차례로. 내용은 설계 §3 의 1–10(Task 2 로 맞춘 판)을 빠짐없이 옮기고 문장만 다듬는다. 절 사이 참조는 번호가 아니라 절 이름으로 한다(「보안 갈래」 절 · 「값 대비 비용」 의 첫째 줄).
- 설계 §2 의 「이 레포의 낱말로 옮기는 것」 표(원문의 말 → 이 레포에서)는 `## 좋은 테스트` 절 안에 둔다 — 그 절이 「경계는 이 표다」 로 가리킨다.
- 글자 그대로 들어가야 하는 것: `## 망가뜨려 보기` 의 보안 갈래 줄에 「변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다」(AC4).
- 수용 기준이 요구하는 낱낱(빠지면 안 되는 것): AC2 의 다섯 · AC3 의 조건 넷과 사례 넷(드는 쪽: 금지 문장 · 절차의 걸음 문장 / 안 드는 쪽: 질문 표의 한 줄 전체 · 보고 글의 첫 줄과 끝 문단) · AC5 의 넷과 예외 둘의 한정(겹침 확인과 오래 걸리면 구조를 고치는 판정은 보안 갈래에도 그대로) · AC6 의 차례 다섯 · 잣대 둘 · 「열어 본 것만 겹침」 · 「잃는 확인을 적는다」 · 숫자 문턱 없음 · AC7 의 넷 · AC8 의 PR 하나 = 묶음 하나 · 표의 칸 다섯 · 승인 뒤 커밋 · 기록 경계(Task 2 가 맞춘 §3 의 10 문장).
- 배경 · 진단 숫자 · 이력 · 「이 문서가 왜 있나」 는 싣지 않는다.

- [ ] **Step 2: `docs/removed-tests.md` 를 쓴다** (AC11)

머리 한 문단(지운 테스트마다 한 줄을 남기는 파일이다 · 언제 적나는 `docs/testing.md` 「지우기 · 합치기 · 줄이기의 승인과 기록」 · 테스트를 빠져나간 실수를 고칠 때 새 테스트를 쓰기 전에 여기서 먼저 찾는다) · 줄의 꼴(Task 2 가 맞춘 §5 의 펜스 블록 그대로) · `## 항목` 제목 아래 항목 0개.

- [ ] **Step 3: 낱낱이 들어갔는지 한 번 본다** (커밋하지 않는 확인)

Run: `grep -n '^## ' docs/testing.md` · `grep -cF '변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다' docs/testing.md` · `grep -cF '「값 대비 비용」 의 어느 줄' docs/removed-tests.md`
Expected: 절 제목 열이 Interfaces 의 차례 그대로 · 1 · 1. 이어서 AC1–AC8 · AC11 을 한 줄씩 읽어 대조하고 빠진 것을 채운다.

- [ ] **Step 4: 코퍼스 테스트를 돌린다**

Run: `$TMPDIR/e2-readers.tsv` 의 「실행 명령」 전부. Expected: 기준선과 같다(새 실패 0).

- [ ] **Step 5: 커밋**

```bash
git add docs/testing.md docs/removed-tests.md
git commit -m "docs(testing): 이 레포의 테스트 기준 절 열과 지운 것 기록 파일을 둔다 (E2)" -- docs/testing.md docs/removed-tests.md
```

---

### Task 4: 원문과 고지 파일 (AC9 · AC10)

**Files:**
- Modify: `docs/testing.md`(맨 아래에 원문 덧붙임)
- Create: `docs/testing.NOTICE.txt`
- 커밋하지 않음: `$TMPDIR/e2-compare-original.py`(대조 스크립트) · `$TMPDIR/e2-compare-original.txt`(결과 — PR 본문에 싣는다)

**Interfaces:**
- Consumes: Task 3 의 `docs/testing.md`.
- Produces: `$TMPDIR/e2-compare-original.txt` — Task 7 의 PR 본문 재료.

- [ ] **Step 1: 원문을 덧붙인다**

`docs/testing.md` 끝에 빈 줄 · `---` · 빈 줄을 두고, 원문을 이 꼴로 잇는다: `SKILL.md` 6–38행(10행 · 26행은 뺀다 — 9행과 11행, 25행과 27행의 빈 줄은 남는다) · 빈 줄 하나 · `tests.md` 1–77행 · 빈 줄 하나 · `mocking.md` 1–59행. 손으로 옮겨 치지 말고 셸로 원문 파일에서 잘라 붙인다. 제목 수준(`#`)도 원문 그대로다.

제자리 수정 둘(설계 §2):
- 16행 원문 `See [tests.md](tests.md) for examples and [mocking.md](mocking.md) for mocking guidelines.` → `See [tests.md](#good-and-bad-tests) for examples and [mocking.md](#when-to-mock) for mocking guidelines.`(링크 글자는 그대로, 대상만)
- 38행 원문 ``- **Refactoring is not part of the loop.** It belongs to the review stage (see the `code-review` skill), not the red → green implementation cycle.`` → `- **Refactoring is not part of the loop.** It belongs to the review stage, not the red → green implementation cycle.`

- [ ] **Step 2: 대조 스크립트를 쓴다** — `$TMPDIR/e2-compare-original.py <docs/testing.md> <원문 폴더>`

`docs/testing.md` 에서 `# Test-Driven Development` 줄부터 끝까지를 잘라, Step 1 의 꼴대로 원문에서 만든 기대 줄 목록과 줄 단위로 견준다. 기대 목록은 원문에서 뺀 줄을 빼고 제자리 수정 둘을 적용해 만든다 — 뺀 줄 번호와 수정 쌍은 스크립트 안의 상수로 둔다(고지 파일의 목록과 같은 값). 출력: 세 파일의 SHA-256 · 다른 줄마다 `파일:줄 — 기대 / 실제` · 끝줄 `차이 0` 또는 `차이 N`. 차이가 있으면 rc 1.

- [ ] **Step 3: 대조를 돌리고, 계측기가 살아 있음을 본다**

Run: `python3 $TMPDIR/e2-compare-original.py docs/testing.md <원문 폴더> > $TMPDIR/e2-compare-original.txt; echo rc=$?`
Expected: `차이 0` · rc 0.
양성 대조: `docs/testing.md` 사본(`$TMPDIR` 안)에서 `→` 하나를 `->` 로, 줄 하나 끝에 공백 하나를 더한 뒤 같은 스크립트를 돌린다. Expected: `차이 2` · rc 1. 사본은 이름으로 지운다.

- [ ] **Step 4: `docs/testing.NOTICE.txt` 를 쓴다** (꼴은 `existing-first.NOTICE.txt`)

담을 것 — 첫 줄(`docs/testing.md` 의 「# Test-Driven Development」 부터 끝까지는 아래 세 파일을 가져와 덜어 낸 것이다) · 출처(저장소 `https://github.com/mattpocock/skills` · 경로 `skills/engineering/tdd/` · 판 1.3.2(플러그인 `mattpocock-skills`) · 커밋(Step 5) · 세 파일의 SHA-256(AC10 값) · 확인한 날) · 잇는 꼴(세 파일을 `SKILL.md` · `tests.md` · `mocking.md` 차례로 빈 줄 하나씩 두고 잇는다) · 뺀 것(`SKILL.md` 1–4행 머리말(뒤의 빈 5행도 함께 — 6행 제목부터 싣는다) · 10행 GLOSSARY · ADR 문단 · 26행 `codebase-design` 문단) · 제자리 수정(16행 · 38행 — 원문 → 바꾼 글) · 싣지 않은 파일(`agents/openai.yaml` — 다른 도구의 화면 이름 · 짧은 설명, 본문이 아니다 · SHA-256) · 「그 밖의 글자는 원문 그대로다」 · 라이선스(설치본 `LICENSE` 전문 — `Copyright (c) 2026 Matt Pocock`, 셸로 복사).

- [ ] **Step 5: 상류 커밋을 확인한다**

Run: `gh api repos/mattpocock/skills/tags --paginate --jq '.[] | "\(.name) \(.commit.sha)"'` 에서 `1.3.2` 에 해당하는 태그를 찾고, 그 커밋에서 세 파일을 받아(`gh api "repos/mattpocock/skills/contents/skills/engineering/tdd/<파일>?ref=<커밋>" --jq .content | base64 -d | shasum -a 256`) AC10 값과 견준다.
Expected: 세 값이 같으면 그 커밋(과 날짜)을 고지에 적는다. 태그가 없거나 · 값이 다르거나 · 네트워크가 막히면 고지에 「확인 못 함 — <이유 한 구>」 로 적는다(값이 다르면 그 사실도 보고한다).

- [ ] **Step 6: 앵커가 맞는지 본다**

Run: `grep -cx '# Good and Bad Tests' docs/testing.md` · `grep -cx '# When to Mock' docs/testing.md` · `grep -cx '## 망가뜨려 보기' docs/testing.md` · `wc -l docs/testing.md`
Expected: 1 · 1 · 1. 300줄을 넘으면 `# 테스트 기준` 의 첫 문단 다음에 위쪽 절 열과 원문 제목을 가리키는 `## 목차` 를 두고(CLAUDE.md Doc Conventions) Step 3 대조를 다시 돌린다.

- [ ] **Step 7: 커밋**

```bash
git add docs/testing.md docs/testing.NOTICE.txt
git commit -m "docs(testing): 맷 포콕 tdd skill 본문 세 파일을 옮겨 싣고 고지 파일을 둔다 (E2)" -- docs/testing.md docs/testing.NOTICE.txt
```

---

### Task 5: 가리키는 줄 둘과 헌장 인용 락의 확인 하나 (AC12 · AC13 · AC15 · AC16)

**Files:**
- Modify: `shared/tests/test_charter_citations.sh`(판정 코어 갈래 1 — 더한 줄만)
- Modify: `CLAUDE.md`(Law 3 아래 목록 끝 「있는 것 먼저」 항목 뒤에 한 항목)
- Modify: `docs/plugin-authoring.md:56`(변이 줄 한 줄)

**Interfaces:**
- Consumes: Task 3 · 4 의 `docs/testing.md`(추적 파일이어야 헌장 인용 락의 실재 확인이 통과한다).
- Produces: 락 출력의 새 판정 줄 — 통과 `CLAUDE.md 가 테스트 기준 docs/testing.md 를 가리킨다`, 실패 `CLAUDE.md 가 docs/testing.md 를 가리키지 않는다 — 테스트 기준이 닿는 길이 끊겼다`.

- [ ] **Step 1: 확인을 더한다** (실패하는 테스트 먼저)

판정 코어 갈래 1 에서: 루프 앞에 `cites_testing = False`. 루프 안 `path` 를 다 만든 직후(추적 대조 앞)에 `if doc == "CLAUDE.md" and path == "docs/testing.md": cites_testing = True`. 루프 뒤(모양 인용 하한 판정 다음)에 `cites_testing` 이 참이면 `out("OK", …)`, 거짓이면 `out("NO", …)` — 글은 Interfaces 의 두 줄. 한글 문자열은 짧게 두거나 인접 문자열로 나눈다(Review Focus 5). 머리 주석에 한 줄: 「CLAUDE.md 가 테스트 기준(docs/testing.md)을 가리킨다 — 기준이 세션에 닿는 길(테스트 기준 설계 AC16).」 있던 줄은 지우거나 고치지 않는다.

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash shared/tests/test_charter_citations.sh; echo rc=$?`
Expected: rc ≠ 0 · 실패 줄은 `CLAUDE.md 가 docs/testing.md 를 가리키지 않는다` 하나뿐(다른 확인은 통과).

- [ ] **Step 3: `CLAUDE.md` 에 항목을 더한다** (AC12)

`- **있는 것 먼저.** …` 줄 바로 뒤, `## Plugin Shape` 앞의 빈 줄 앞에 한 줄:

```
- **테스트 기준.** 테스트를 쓰거나 고치거나 지우기 전에 [`docs/testing.md`](docs/testing.md) 를 따른다. 설계문서에 `## 테스트할 자리` 절을 두고, 테스트는 그 자리에 하나씩 쓴다 — 실패를 먼저 본다.
```

- [ ] **Step 4: 돌려서 통과를 본다**

Run: `bash shared/tests/test_charter_citations.sh; echo rc=$?`
Expected: rc 0 · `CLAUDE.md 가 테스트 기준 docs/testing.md 를 가리킨다` 가 통과 줄로 보인다.

- [ ] **Step 5: `docs/plugin-authoring.md` 의 변이 줄을 바꾼다** (AC13)

56행 `- 락을 쓰거나 고치면 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다. 부재 락에는 양성 짝을 둔다.` →
```
- 테스트를 쓰거나 고치면 [`docs/testing.md`](testing.md#망가뜨려-보기) 의 「망가뜨려 보기」 를 따른다.
```

- [ ] **Step 6: diff 가 약속대로인지 본다** (AC12 · AC13 · AC15)

Run: `git diff --numstat -- CLAUDE.md shared/tests/test_charter_citations.sh docs/plugin-authoring.md`
Expected: `CLAUDE.md` `1	0` · 락 `n	0`(지운 줄 0) · `docs/plugin-authoring.md` `1	1`.

- [ ] **Step 7: 사본에서 실패를 본다** (AC16 · `2e6610eb#r1.1`)

이 락은 추적 파일 목록을 git 색인(`git ls-files`)에서, 사라진 이름을 `git log HEAD` 에서 읽는다 — 그래서 파일 이름만 바꾼 작업 사본은 실패하지 않고, git 이력이 없는 사본은 다른 까닭으로 실패한다. 사본은 Step 1–5 를 커밋한 **뒤** 온전한 클론으로 뜬다: `git clone -q --no-local <worktree> "$TMPDIR/e2-cc-<x>"`(얕은 클론 금지) — 뜬 뒤 `git -C "$TMPDIR/e2-cc-<x>" rev-parse HEAD` 가 worktree 의 `git rev-parse HEAD` 와 같은지 먼저 본다(다르면 `git -C <사본> checkout -q <그 해시>`). 사본마다 그 사본의 락을 돌린다: `bash "$TMPDIR/e2-cc-<x>/shared/tests/test_charter_citations.sh"`.

| 사본 | 바꿈 | 기대 |
|---|---|---|
| P(양성 대조) | 없음 | rc 0 — 사본에서 계측기가 산다 |
| A | `CLAUDE.md` 에서 「테스트 기준」 항목 줄을 지운다(작업 트리만 — 락은 `CLAUDE.md` 를 파일로 읽는다) | rc ≠ 0 · 실패 줄은 새 확인 하나뿐 |
| B | `git -C <사본> mv docs/testing.md docs/test-criteria.md`(색인에 반영된다 — 커밋은 필요 없다) | rc ≠ 0 · 있던 확인 `` CLAUDE.md: `docs/testing.md` — 그 경로가 리포에 없다 `` 가 실패한다 · 새 확인은 통과 |
| C(Review Focus 3) | `CLAUDE.md` 항목의 `docs/testing.md` 두 곳을 `docs/testing.NOTICE.txt` 로 | rc ≠ 0 · 새 확인이 실패한다 |

네 사본의 rc 와 실패 줄을 `$TMPDIR/e2-ac16.txt` 에 적고(PR 본문 재료), 사본 넷을 이름으로 지운다.

- [ ] **Step 8: 코퍼스 테스트를 돌린다** (AC17)

Run: `$TMPDIR/e2-readers.tsv` 의 「실행 명령」 전부. Expected: 전부 통과(기준선 실패는 기준선과 같게).

- [ ] **Step 9: 커밋**

```bash
git add shared/tests/test_charter_citations.sh CLAUDE.md docs/plugin-authoring.md
git commit -m "docs(claude-md): 테스트 기준 문서를 가리키는 항목과 그 항목을 지키는 확인을 더한다 (E2)" -- shared/tests/test_charter_citations.sh CLAUDE.md docs/plugin-authoring.md
```

---

### Task 6: 다른 일에 알리는 글 (AC18)

**Files:**
- Create: `docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/test-criteria-notice.md`

**Interfaces:**
- Consumes: Task 2 가 맞춘 설계 §6.
- Produces: 알림 글 — 머지 뒤 지휘자가 그 경로와 요점을 보낸다(AC19 — 이 계획 몫이 아니다).

- [ ] **Step 1: 글을 쓴다**

- 제목과 첫 문단: 테스트 기준(`docs/testing.md`)이 생겼고 받는 쪽마다 달라지는 것을 적는다.
- 표 `| 받는 쪽 | 달라지는 것 |` — 설계 §6 의 다섯 행(앞단 F5 의 남은 계획 2–4 · F7 둘째 계획 · 지휘 R5 · E3 · E4). 행마다 가리키는 절은 설계의 「§3 의 n」 대신 `docs/testing.md` 의 절 이름으로 적는다(예: 「글을 무는 확인」 절). E4 행에는 Task 2 가 더한 「행동을 정하는 문장」 규칙(OQ18 가운데 규칙은 닫혔고 테스트마다 대어 보는 일이 E4 몫)과 지운 것 기록의 자리와 꼴(OQ20 은 닫혔다 · `docs/removed-tests.md`)이 함께 있다.
- `## 문구 테스트의 예외` — 설계 §6 의 그 문단 내용을 그대로: `test_stage_prose_trim.sh` 는 「글을 무는 확인」 과 다르다 · 사용자가 「의도다」 로 정했다고 앞단 지휘 세션이 2026-11-24 에 알렸다 · 그 답의 기록은 이 레포에서 확인하지 못했다 · E4 는 그 테스트를 가르는 차례에 올리지 않는다 · 다시 가르려면 사용자에게 묻는다.

- [ ] **Step 2: 다섯 행과 예외 넷이 있는지 읽어서 본다** (AC18) — 다섯 받는 쪽 · 예외 문단의 「E4 는 올리지 않는다」 · 「사용자에게 묻는다」 · 「확인하지 못했다」.

- [ ] **Step 3: 커밋**

```bash
git add docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/test-criteria-notice.md
git commit -m "docs(roadmap): 테스트 기준이 달라지게 하는 것을 받는 쪽마다 알리는 글을 둔다 (E2)" -- docs/superpowers/roadmaps/2026-11-20-test-method-rework-brief/test-criteria-notice.md
```

---

### Task 7: 전체 확인 · 마지막 전체 리뷰 · PR 준비 (AC14 · AC15 · AC17 · AC1–AC18 대조)

**Files:**
- Modify(필요할 때만): 설계문서 `## 미룸` 표 — 리뷰의 미룸 · 빠짐과 리뷰 후속으로 미룬 것.
- 커밋하지 않음: `$TMPDIR/e2-final-review.md`(AC 대조 보고).

- [ ] **Step 1: 건드리지 않은 것을 diff 로 본다** (AC14 · AC15)

Run: `git diff --name-status bfdc9593...HEAD`
Expected: 이름 목록이 Global Constraints 첫 줄의 목록(+ 이 계획)과 같다 · `plugins/` · `docs/superpowers/roadmaps/worker/` 0건 · `D` 0건. `git diff --numstat bfdc9593...HEAD -- CLAUDE.md shared/tests/test_charter_citations.sh` 의 지운 줄 0.

- [ ] **Step 2: 목록의 테스트를 다시 돌린다** (AC17) — `$TMPDIR/e2-readers.tsv` 전부, 전부 통과.

- [ ] **Step 3: 컨트롤러가 전체 스위트를 한 번 돌린다** — Global Constraints 의 잠금 줄(`--owner <이 agent 이름>`). Expected: 새 실패 0. worktree 에서만 나는 기존 실패는 기준 브랜치(`bfdc9593`)에서도 나는지 견줘 적는다. 잠금을 못 잡으면 잠금 없이 돌리지 않고 주인 · 잡은 시각을 보고한다.

- [ ] **Step 4: 마지막 전체 리뷰** (실행 방식의 마지막 전체 리뷰 자리)

리뷰어(쓰기 도구 없는 agent)에게 보내는 글에 싣는 것: 이 계획 경로 · 설계문서 경로 · `bfdc9593...HEAD` diff · 설계문서 `## Acceptance Criteria` 의 AC1–AC18 원문(그대로 붙인다 — AC19 · AC20 은 지휘자 몫이라 「대상 아님」 으로 밝힌다) · `$TMPDIR/e2-compare-original.txt` · `$TMPDIR/e2-ac16.txt` · `$TMPDIR/e2-readers.tsv` 의 내용 · 잠금 줄과 경로. 묻는 것:
- AC 마다 한 줄 `AC<n>: 구현됨 | 미룸 | 빠짐 — 근거`.
- 설계 `## 있는 것 검토` 가 고른 것을 실제로 썼는가, 같은 것을 다시 만들지 않았는가 — `existing-first` 의 꼴(위 규칙 · 아래 원문 · 옆 고지)을 따랐나 · 변이 줄을 보안 갈래 문장으로 글자 그대로 옮겼나 · 헌장 인용 락에 확인을 더했고 새 테스트 파일을 만들지 않았나 · 지운 것 기록이 CHANGELOG 한 줄 꼴을 따랐나 · 쓰지 않기로 한 것(해시 테스트 · 검토를 마친 실패 원장 꼴 · 이름 목록 등호 테스트 · 리뷰 프로필 필수 섹션 · 역할 문서)을 만들지 않았나.
- 기준 문서 위쪽이 설계 §3 과 줄마다 맞는가(Verification Plan 첫째 줄).

컨트롤러는 그 보고를 그대로 `$TMPDIR/e2-final-review.md` 에 셸로 적는다(git 이 추적하지 않는 파일).

- [ ] **Step 5: 미룸을 설계문서에 올린다**

보고의 `미룸` · `빠짐` 과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 행씩 더한다. 없으면 고치지 않는다. 고쳤으면 `docs(spec): …` 로 pathspec 커밋 · push.

- [ ] **Step 6: 구현 대조 스크립트를 돌려 경고를 사용자에게 보인다** (PR 을 만들기 전)

Run: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.25.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-24-test-criteria-rules-design.md $TMPDIR/e2-final-review.md`
Expected: rc 0 또는 1(경고). 경고 줄은 고치지 않고 사용자에게 그대로 보인다.

- [ ] **Step 7: PR 본문 재료를 모은다** — 승인받은 설계의 `## 테스트할 자리` 표 · AC9 대조 결과(`e2-compare-original.txt`) · AC16 사본 넷의 결과(`e2-ac16.txt`) · AC17 목록과 결과 · 상류 커밋 확인 결과 · `--impl` 경고. 품질 게이트는 머지 준비 때 한 번 보낸다(이 로드맵에서 사용자가 정한 것 — 지휘자의 단위마다 qg).
