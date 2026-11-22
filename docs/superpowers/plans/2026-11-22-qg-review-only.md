# R4 — qg 리뷰 전념 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** qg 한 실행이 한 번 보고 판정과 고칠 목록을 내고 끝나게 하고(고치기 반복 · 반복 번호 · 세션 파일 셋 · 판정 줄 두 칸을 걷어낸다), 지휘 중 qg 가 코드를 보는 자리를 에픽 PR 의 머지 앞으로 옮겨 막는 지적은 지휘자가 구현 길로 돌려보내고 고친 커밋만 좁게 다시 보게 한다.

**Architecture:** qg 쪽은 본문(`SKILL.md`) · reference 넷 · `verdict.py` 의 반복 갈래를 지우고 한 번 지나는 흐름의 문장으로 바꾼다 — 새 스크립트 · 새 인자 · 새 계약 판은 없다. 지휘 쪽은 `qg-review.md` 가 머지 앞 자리 · 되돌리기 · 좁은 재리뷰 · 머지 앞 「잘못 골랐다」 를 맡고, `conducting.md` 는 그 파일로 들어가는 문장과 걸음 4 · 5 · 6 의 순서만 고친다. 과제 순서는 qg 쪽 → 지휘 쪽 → 판 · CHANGELOG · README(설계 Metadata).

**Tech Stack:** 마크다운 절차 문서 · Python 3.9 문법(`verdict.py`) · bash(macOS 3.2 호환) 셸 문서 락(`shared/tests/assert.sh`) · unittest.

**Spec:** `docs/superpowers/specs/2026-11-22-qg-review-only-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다. 설계문서 본문은 고치지 않는다 — `## 미룸` 표에 행을 더하는 것만 끝 과제에서 한다. 설계문서 `## 결정 기록` 은 뒤 줄이 앞 줄을 바꾼다(D24 가 D15 를, D31 이 D11 · D25 를).

## Global Constraints

- 한 PR · 한 브랜치(`feature/qg-review-only`). qg 쪽 과제(Task 2–8)를 지휘 쪽(Task 9–12)보다 먼저 커밋한다(D12).
- 새 스크립트 · 새 agent · 새 skill · qg 호출 줄의 새 인자 · `intent-return.md` 판 올림 없음(D13 · Non-goals). `contract` 는 2 그대로.
- 리뷰어 정의는 보안 민감 파일이다 — `security-reviewer.md` 는 frontmatter `input_slots` 의 `iteration` 칸 선언만 지운다 · `code-recritic.md` 는 반복을 가리키는 낱말만 · `intent-critic.md` 는 `question` 칸 지시만. 규칙 · 임계치 · 처방 · 근거 규칙 · 상한 · 주입 경계 문장은 diff 0.
- 고치기 반복은 사용자가 명시 결정한 제거라 deprecation 창 없이 지우고 quality-gates `CHANGELOG.md` Removed 에 적는다 — quality-gates major. spec-distill minor. 번호는 **구현을 시작할 때의 origin/main 판 위**로 적고(지금 기준 quality-gates 15.3.1 → 16.0.0 · spec-distill 8.30.0 → 8.31.0) 머지 직전에 지휘자가 다시 정한다.
- 은퇴하는 kill switch 없음(Task 1 이 다시 확인).
- 플러그인 경계: spec-distill 은 quality-gates 를 skill 호출로만 부른다. quality-gates 가 없으면 「품질 게이트 없이 간다 — quality-gates 가 설치돼 있지 않다」 로 알리고 진행한다.
- 레포 전용 값을 박지 않는다 — 기본 브랜치는 `origin/HEAD`, 테스트 명령 · 모델 · 폴더는 해결자 값. `test_repo_literals.sh` 규칙(기본 브랜치 이름 · `feature/` 접두 · `docs/superpowers` 같은 구조 경로 · 모델 이름)을 고친 문서도 지킨다.
- 사람에게 보이는 글은 `shared/style/plain-language.md` 를 따른다. 질문 추천은 첫 자리 + 「(권장)」, 추천 없으면 표시 없음.
- 락은 본문에만 있는 글로 묶는다(헤더가 문구를 만족시키지 않게). 부재 단언마다 양의 짝. 락마다 변이(지우기 · 뒤집기 · 옛 문장 되살리기)로 실패하는지 본다 — 변이 전에 커밋하고 복원은 `git checkout HEAD -- <파일>` + `git diff HEAD` 로 확인. `PYTHONDONTWRITEBYTECODE=1`.
- 새 셸 테스트 파일은 만들지 않는다(설계 Files to Modify — 픽스처만 계획이 정한다). 고친 셸 테스트가 실행 비트를 잃지 않았는지 `git ls-files -s <파일>` 이 `100755` 인지 본다.
- 커밋: Conventional Commits, `type`·`scope` 영어 · 설명 한국어, pathspec 커밋. 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-22-qg-review-only-design.md`.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 뒤로 옮기기(reset · rebase · force) · push(지휘자가 한다).
- 임시 폴더는 지휘자가 준 `TMPDIR` 에 셸로 쓴다. 막히면 자기 worktree 안 `git check-ignore -q <자리>` 로 무시되는 자리를 쓰고 보고에 적는다.
- **전체 스위트는 공유 잠금 아래서만:** `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.29.0/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/suite-lock --owner <agent 이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'`. 하위 agent 에게 보내는 글에도 이 줄과 경로를 그대로 싣는다. 못 잡으면 주인 · 잡은 시각을 보고한다. 과제 안에서는 그 과제의 좁은 테스트만 잠금 없이 돌린다.

## Review Focus

1. **앞 리뷰의 `reviewed_head` 가 비어 온 좁은 재리뷰** — 의도 점검이 꺼졌거나 리뷰 트리를 못 만든 실행은 끝 커밋을 돌려주지 않는다. 사람은 재리뷰가 그래도 고친 커밋만 본다고 기대한다 — 시작은 PR 본문 `## qg 리뷰` 에 적은 「지난 리뷰의 끝」 이다. 테스트: Task 10 락 `recheck-start-from-pr-body`.
2. **좁은 재리뷰 범위에 기본 브랜치를 합친 커밋이 낀 경우** — 좁게 보면 기본 브랜치의 남의 변경까지 리뷰된다. 처음부터 다시 보고 재리뷰 한 번으로 센다. 테스트: Task 10 락 `recheck-merge-commit-full`.
3. **PR 번호 앞자리가 같은 두 PR(3 · 31)** — 「이미 보낸 것」 이 앞자리로 견주면 PR 31 의 리뷰를 PR 3 의 것으로 읽고 보내지 않는다. 자리 글자 뒤가 `-` 이거나 끝일 때만 같다. 테스트: Task 9 락 `already-sent-whole-token` 과 그 픽스처 표.
4. **열린 PR 이 있는 브랜치에서 직접 부른 실행이 막는 지적으로 끝남** — 「멈추기」 로 게시를 피하던 길이 없어져 판정이 PR 코멘트로 게시된다(D1.1). 테스트: Task 3 `case_defect_run_publishes` (게시 펜스를 defect 판정 · 열린 PR 가짜 sink 로 돌려 sink 가 한 번 불린다).
5. **team 형식 검수 결과 파일에 qg 지적을 글자 그대로 옮길 때** — qg 지적 글의 줄이 `AC<n>:` · `끝 — ` · `Task ` 로 시작하면 `team_files.py` 가 기계 줄로 읽어 결과 대조를 깨뜨린다. 옮긴 목록과 기록은 펜스 안에 둔다. 테스트: Task 11 `test_review_result_qg_block_is_not_machine_lines`(`plugins/spec-distill/tests/` 의 team_files 테스트 파일에 한 케이스 — `parse_result` 가 펜스 안의 `AC1: …` · `끝 — …` 줄을 기계 줄로 세지 않는다).

---

## 열린 결정 — 구현 전에 지휘자가 답을 적는다

아래 넷은 설계의 글자 · 수용 기준 · 보이는 동작이나 설계가 고치지 않는다고 한 파일에 닿아 이 계획이 정하지 않았다(끝 절 `## 설계에 없던 결정` 에 항목마다 그대로 두면 · 고치면 · 권고). **각 과제 본문은 「그대로 두면」 을 기본으로 적고, 「고치면」 이면 바뀌는 단계를 `[P<n> 고치면: …]` 로 함께 적었다.** 구현자는 지휘자가 적어 준 답대로 한쪽만 한다. 답이 없으면 구현을 시작하지 않는다.

| 결정 | 닿는 과제 | 답 |
|---|---|---|
| P1 스크립트의 반복 번호 인자(`--iter`)와 파일 이름의 `i<N>` | Task 3 · 6 | (지휘자가 적는다) |
| P2 걷는 사이 코드가 바뀐 걷기의 e2e 칸(`무효`) | Task 2 · 4 | (지휘자가 적는다) |
| P3 team 형식에서 qg 리뷰 기록을 적는 자리 | Task 11 | (지휘자가 적는다) |
| P4 지휘자의 새 질문 둘에 추천을 다는가 | Task 10 · 12 | (지휘자가 적는다) |

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 구현을 시작할 때의 기본 브랜치에서도 그런지 본다. AC 를 직접 맡지 않는다 — 뒤 과제 전부의 전제다.

**Files:** 읽기만. 결과는 `TMPDIR` 의 `recheck.md` 에 적고 마지막 보고에 싣는다.

- [ ] **Step 1: 기본 브랜치를 합친다.** `git fetch origin` → `git merge --no-edit origin/HEAD`(충돌이면 멈추고 보고).
- [ ] **Step 2: 반복을 읽는 자리를 다시 뽑는다.** `git grep -n -e 'Fix-loop' -e 'iteration' -e 'excluded.md' -e 'extra-iterations.md' -e 'classification.md' -e 'accepted with findings' -e 'aborted' -e 'Max-iter' -e '한 번 더 돌기' -e '고치고 다시 돌기' -e '제외 패치' -e 'Retry' -e '--iter' -- plugins/quality-gates shared/tests shared/test-selection plugins/spec-distill/tests`. 이 계획 Task 3–8 의 파일 목록에 없는 파일이 나오면 멈추고 보고한다.
- [ ] **Step 3: kill switch.** qg 본문 `## kill switch` 의 스위치가 일곱이고 고치기 반복만 끄는 것이 없는지 본다. 있으면 멈추고 보고한다(있으면 CHANGELOG Removed · README 공시가 필요하다).
- [ ] **Step 4: 옆 에픽과 겹치는 자리.** 설계 Constraints 의 겹침 목록(`feature/switch-retirement` · `feature/front-stage-restructure` · `feature/session-workers` · `feature/conductor-step-guides` · `feature/suite-time-cut`)마다 `git branch -r --merged origin/HEAD` · `gh pr list --state all --head <브랜치>` 로 머지 여부를 보고, 머지된 것이 있으면 이 에픽이 고칠 자리(qg 본문의 진입 단계 문장과 kill switch 절 · `conducting.md` 걸음 4 · 5 · 6 과 team 형식 절 · 지휘자 skill 본문 `### 4. 규모 공시` · Task 3–8 이 고칠 qg 테스트)를 다시 읽어 이 계획의 리터럴이 아직 맞는지 본다. 맞지 않으면 멈추고 보고한다.
- [ ] **Step 5: 형식 정본.** `plugins/spec-distill/references/team-files.md` §5 의 「검수 결과 파일」 문장과 `scripts/team_files.py` `parse_result` 의 기계 줄 판정이 아래 「설계와 리포가 어긋난 자리」 의 1 과 같은지 본다.
- [ ] **Step 6: 판 번호.** `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/spec-distill/.claude-plugin/plugin.json` 의 판을 적는다 — Task 8 · 12 가 그 위 major · minor 로 쓴다.
- [ ] **Step 7: 설계와 리포가 어긋난 자리가 늘었는지.** 아래 목록과 다르면 멈추고 보고한다. 같으면 「다시 확인 — 달라진 것 없음」 한 줄을 `recheck.md` 에 적고 다음 과제로 간다.

---

### Task 2: 판정 줄에서 두 칸을 뺀다

**AC:** AC5(판정 줄 · 스크립트 거절 몫). [P2 그대로 두면: AC4 의 `무효` e2e 칸 몫도 이 과제가 맡는다.]

**Files:**
- Modify: `plugins/quality-gates/scripts/verdict.py`(`render_line` · argparse · `--line` 필수 인자 검사 · `E2E_STATES`)
- Test: `plugins/quality-gates/tests/test_v1_verdict_line.sh` · `test_e2e_verdict.sh` · `test_synthesize_findings.sh`(L177-182) · `test_v_requirements.sh`(L31-36) · `test_review_diff.sh`(L1233) · `test_diff_test_results.py`(L413)

**Interfaces:**
- Produces: `verdict.py --line --blocking B --optional O --new-failures F --sha S [--e2e E]` → 한 줄 `qg: <decision> · 막는 지적 B · 선택 O · 차등 새 실패 F[ · e2e E] · S`. `--excluded` · `--iter` 를 주면 rc 2 와 stderr 사유. `render_line(decision, *, blocking, optional, new_failures, sha, e2e=None)`.

- [ ] **Step 1: 실패하는 테스트를 쓴다.** `test_v1_verdict_line.sh` 의 기대 줄을 새 꼴로 바꾼다 — `qg: defect · 막는 지적 2 · 선택 3 · 차등 새 실패 1 · abc1234`. 케이스 `case_removed_args_are_usage_errors` 를 더한다: `--excluded 0` 과 `--iter 1` 을 각각 붙여 부르면 rc 가 `2` 이고 stderr 에 `verdict.py: --excluded 는 받지 않는다 — 판정 줄에 제외 패치 칸이 없다` · `verdict.py: --iter 는 받지 않는다 — 판정 줄에 반복 번호 칸이 없다` 가 있다(rc 와 사유를 함께 단언). 양의 짝: 두 인자 없이 부르면 rc 0. `test_e2e_verdict.sh` 의 기대 줄은 `qg: clean · 막는 지적 0 · 선택 2 · 차등 새 실패 0 · e2e pass · abc1234` 이고 그 단언 이름 「e2e 칸은 차등 새 실패 뒤, sha 앞이다(색인 K-3)」. 나머지 네 파일의 `--excluded 0 --iter 1` 공급을 지우고 기대 줄을 새 꼴로 바꾼다.
- [ ] **Step 2: 실패를 본다.** `bash plugins/quality-gates/tests/test_v1_verdict_line.sh` → 새 케이스 FAIL.
- [ ] **Step 3: `verdict.py` 를 고친다.** argparse 에서 두 인자를 지우되 `parse_known_args` 로 남는 `--excluded` · `--iter`(`=` 꼴 포함)를 먼저 가려 위 사유로 rc 2 로 끝낸다 — argparse 의 「unrecognized arguments」 로 떨어지게 두지 않는다(rc 만 같고 사유가 다르면 락이 공허하다). `--line` 의 「모두 받는다」 사유 문장에서 두 인자를 뺀다. `render_line` 의 두 칸과 그 검사를 지운다. [P2 그대로 두면: `E2E_STATES` 에 `무효` 를 더한다 — 판정 줄 e2e 칸 값 `무효` 는 판정 결정을 바꾸지 않는다(`미확인` 과 같은 자리 · 같은 무게로 합성한다).]
- [ ] **Step 4: 통과를 본다.** 위 여섯 테스트를 돌려 PASS.
- [ ] **Step 5: 커밋.** `git add plugins/quality-gates/scripts/verdict.py <여섯 테스트>` · `git commit -m "feat(qg): 판정 줄에서 제외 패치 · 반복 번호 칸을 뺀다"`(트레일러).

---

### Task 3: qg 본문 — 한 번 지나는 흐름

**AC:** AC1 · AC2 · AC3 · AC5(게시 몫) · AC6(본문 몫) · AC7(dispatch 줄 몫) · AC15(행 9 · 12) · AC18(qg 본문 락 몫).

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- Test: `plugins/quality-gates/tests/test_one_pipeline_surface.sh` · `test_plain_qg_templates.sh` · `test_v_requirements.sh` · `test_pipeline_verdict_wiring.sh` · `test_publish_pipeline_wiring.sh` · `test_range_wiring.sh` · `test_verdict_no_reread.sh` · `test_skill_orchestration.sh` · `tests/harness/test_skill_orchestration_behavior.sh` · `test_skill_run_contract.sh` · `test_review_scope_composition.sh` · `test_lowered_gate_wiring.sh` · `test_intent_critic_wiring.sh` · `test_topic_scope_wiring.sh` · `test_e2e_docs.sh`(K-8 · M9 몫)

**Interfaces:**
- Consumes: Task 2 의 판정 줄 꼴과 `verdict.py` 인자.
- Produces: `result.md` 의 절 `## 고칠 목록`(아래 `### 막는 지적` · `### 제안` · `### 차등 회귀`, 비면 `(없음)`) — Task 6 의 `state-file-format.md` 가 같은 이름을 쓴다. 끝 한 줄 `> [quality-gates] 고칠 목록은 result.md 의 「## 고칠 목록」 에 있다 — 고친 뒤 qg 를 다시 부른다.` 본문 머리 `## ` 차례에서 `## Fix-loop` 이 빠진다.

지울 것(설계 §1 「걷어내는 것」): `## Fix-loop` 절 전부(796–1054 근처) · Flow 의 iteration 고리 · `**Iteration accounting.**` · Step 4.5 의 라우팅 갈래와 「상한(CAP)에서 도달하면」 문단 · 범위 모드 끝내기 질문 · Preflight 의 `excluded.md` · `extra-iterations.md` 지우기와 그 설명 · Final verdict 의 `QG_ARGS_X` 행 · `X_ARGS` · `--excluded` · `--iter <N>` · `반복\t<N>번` · `accepted with findings iter N` · `aborted iter N` · `## 제외 패치` · `## 추가 반복` 쓰기 · Publish 의 aborted 갈래 · `skipped: aborted` · 사유 목록의 `aborted` · `iter N —` 공시 앞머리 · Requirement index V9 행 · R24 의 「Fix-loop 제외 결과 줄」 · X2 의 「(리뷰·테스트부터 다시)」. Step 3 dispatch 의 `iteration: <iteration>${ITERATION}</iteration>` 줄은 Task 5 가 리뷰어 정의의 칸 선언과 같은 커밋에서 지운다(입력 칸 검사가 커밋마다 맞게). Step 1c 의 `--iter <N>` 와 `review-i<N>` 파일 이름은 이 과제에서 두고 Task 6 이 스크립트와 함께 바꾼다(커밋마다 본문과 스크립트가 맞게) — 이 과제는 그 둘을 뺀 문장의 「iteration」 낱말만 뺀다.

고쳐 쓸 것(정확한 글은 이 계획이 정한다 — 설계 Deferred to plan):
- frontmatter `description` 의 「Fix-loop decisions surface via AskUserQuestion.」 → 「A run looks once and ends with the verdict and a fix list — it does not edit the code.」
- Law 2 문단(69–75)의 끝 두 줄 → `You run both axes of the differential test yourself, and you write to the repository in one place only: the intent-critic answer files with their commit (\`scripts/intent_critic.py record\`). The session state folder and the throwaway worktrees are not repository writes.`
- Flow: `├ iteration N = 1..CAP …` 와 그 아래 Fix-loop · Max-iter 두 줄 · 「fail → Fix-loop 게이트 다시」 를 지우고 ①–③ 을 바로 `├` 아래에 두며, ③ 다음에 `│   막는 지적 · 차등 defect 가 있어도 묻지 않는다 — 고칠 목록을 result.md 에 남기고 e2e 질문으로 간다` 한 줄. trivia 줄의 「iteration 1 의 Step 1c 뒤에」 → 「Step 1c 뒤에」. ② 설명 문단의 「매 iteration 돈다 …」 두 줄은 지운다.
- Step 4.5 라우팅 → 「그다음: 판정이 무엇이든 [e2e](#e2e) 로 간다. 막는 지적 · 차등 defect 가 있으면 먼저 아래 「고칠 목록」 을 남긴다 — 묻지 않는다.」 와 `**고칠 목록.**` 문단: synth.out 의 지적과 `**고칠 방법:**` 을 막는 지적 · 제안으로, D5 사본의 회귀 unit 을 차등 회귀(unit 마다 오케스트레이터가 쓴 고칠 방법 한 줄)로 갈라 `result.md` 에 `## 고칠 목록` 으로 적는 펜스 하나(Bash heredoc `>>`, R2). 낮춘 지적 게이트 문단의 「반복마다 … 상한(CAP)의 반복도 같다」 → 「판정이 clean 이어도, 범위 모드에서도(코드를 고치지 않고 판정만 바꾼다)」.
- Step 4.5 머리글 `## qg 반복 N — <verdict>` → `## qg 판정 — <verdict>`(`not-certified` → `## qg 판정 — not-certified (<reason>)`).
- Final verdict 끝 요약 뒤: 막는 지적 · 차등 defect 가 있으면 위 끝 한 줄을 낸다.
- Publish: 판정 그대로 게시한다(범위 모드는 지금처럼 달지 않고 공시). 결과 칸 case 는 `finished)` 하나.
- R1 둘째 문장 → 「You do not edit working-tree files in this run — the only repository write is the intent-critic answer commit.」 e2e 걷기 문단의 「고침은 Retry 로만 한다」 → 「고치지 않는다 — 고칠 목록에 남는다」.
- Requirement index V9 → `| V9 한 실행은 한 번 지나고 저장소의 코드를 고치지 않는다 | Flow · Step 4.5 고칠 목록 · Law 2 |`. 「I1 intent-critic 은 판정 밖」 행의 번호를 `IC1` 로 바꾼다(references/intent-critic.md 의 걸음 I1 과 겹치지 않게 — 넘겨받은 행 7 의 라벨 겹침).
- P0 의 「범위 모드만 예외가 하나다 — …」 → 「예외는 둘이다 — 범위 모드는 P2b 의 리뷰 트리 펜스가 낸 `review_tree: <경로>` 가 이 실행의 `project_dir` 이고(실행에 한 번 정하고, 그 뒤로 다시 도출하지 않는다), intent-critic 단계는 PR 범위에서도 리뷰 트리를 `project_dir` 로 쓴다(references/intent-critic.md I1).」(행 9 통과 기준)
- kill switch 의 `DEVBREW_QUALITY_GATES_DISABLE_INTENT_CRITIC=1` 줄 끝 「집행은 `scripts/intent_critic.py gate` 다.」 → 「집행은 `scripts/intent_critic.py gate` 이고, 준비 걸음(`prepare`)도 이 스위치를 스스로 읽어 다른 팀 읽기 · PR 조회가 함께 꺼진다.」(행 12 통과 기준 — README L545 의 문장과 같은 뜻)
- 본문의 나머지 「iteration」 · 「반복」 · `<N>` 낱말(Step 1a · 1c · 3 · 3.5 · 3.9 · 4 · Differential test · e2e)은 뜻을 바꾸지 않고 「이 실행」 으로 바꾼다.

- [ ] **Step 1: 실패하는 락을 쓴다.**
  - `test_one_pipeline_surface.sh` `case_new_skeleton_present` 의 `## ` 차례 핀에서 `## Fix-loop` 을 뺀다. 새 케이스 `case_one_pass_flow`(양의 짝): `## Flow` 펜스에 `막는 지적 · 차등 defect 가 있어도 묻지 않는다 — 고칠 목록을 result.md 에 남기고 e2e 질문으로 간다` 가 한 번, Step 4.5 본문에 `**고칠 목록.**` 이 한 번, 본문 전체에 위 끝 한 줄이 한 번 있다. 짝 부재: 본문 전체에 `Fix-loop` · `Max-iter` · `CAP` · `excluded.md` · `extra-iterations.md` · `classification.md` · `accepted with findings` · `aborted iter` · `skipped: aborted` · `고치고 다시 돌기` · `한 번 더 돌기` · `지금 판정으로 끝내기` 가 0 번이다. `case_no_gate_scope_question` 의 「fix-loop 결정 도구는 남아 있다」 짝은 `header: "낮춘 지적",` 한 번으로 바꾼다.
  - `test_intent_critic_wiring.sh` L30 의 `LAW2_WRITES` 를 위 새 Law 2 문장(본문에만 있는 `in one place only: the intent-critic answer files` 구절)으로 바꾸고, 옛 문장 `the fixes the user approved at the Fix-loop gate` 부재를 짝으로 둔다. L111 의 앵커 `rm -f "$RD/excluded.md"` 를 P2 의 남는 `rm -f "$RD/differential.yaml"` 줄로 바꾼다.
  - `test_v_requirements.sh`: V9 두 단언과 `case_ac7_fix_loop_override_and_excluded_log` · `case_max_iter_cap_is_five` · `case_ac25_extra_iteration_record_runs` 를 지우고, `case_v9_one_pass_no_code_edits` 를 더한다 — Requirement index 에 위 V9 행이 한 번, R1 에 `the only repository write is the intent-critic answer commit` 이 한 번. L46 의 「이 iteration 은 **clean 이 아니다**」 를 고친 글로.
  - `test_publish_pipeline_wiring.sh`: aborted 세 케이스(AC13 · I1 · M2)를 지우고 `case_defect_run_publishes` 를 더한다(Review Focus 4 — `OUTCOME=finished` · defect 판정 줄 · 열린 PR 가짜 sink 로 펜스를 돌려 sink 가 한 번 불린다). 「범위: aborted 여도」 케이스와 L149 의 결과 토큰은 `finished` 로.
  - 나머지 파일은 지운 문장을 묶던 단언을 지우거나 고친 글로 바꾼다 — 목록은 Task 1 Step 2 의 결과와 이 과제 Files. 지운 부재 단언마다 위 `case_one_pass_flow` 의 짝이 양의 짝이다.
- [ ] **Step 2: 실패를 본다.** 위 테스트를 돌려 새 단언이 FAIL.
- [ ] **Step 3: 본문을 고친다.** 위 「지울 것」 · 「고쳐 쓸 것」.
- [ ] **Step 4: 통과를 본다.** 이 과제 Files 의 테스트 전부와 `bash shared/tests/test_agent_input_slots.sh`.
- [ ] **Step 5: 변이.** `case_one_pass_flow` 가 Flow 의 새 줄 지우기 · 옛 Fix-loop 줄 되살리기로 FAIL 하는지, `case_removed_args_are_usage_errors` 가 사유 문장을 argparse 기본 사유로 바꾸기로 FAIL 하는지 본다.
- [ ] **Step 6: 커밋.** `feat(qg)!: 고치기 반복을 걷어내고 한 번 보고 끝낸다`(본문 + 테스트, pathspec).

---

### Task 4: e2e 걷기 직후 게이트

**AC:** AC4.

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(`## e2e` E4 · E6 · 첫 문단) · `plugins/quality-gates/references/e2e.md`(3 절 L64 · 5 절 표와 불릿 · 6 절 표)
- Test: `plugins/quality-gates/tests/test_plain_qg_templates.sh`(L148-178) · `test_e2e_docs.sh` · `test_verdict_no_reread.sh`(L416-417)

**Interfaces:**
- Consumes: Task 3 의 Flow(판정 뒤 e2e 질문 한 번).
- Produces: 5 절 표 —
  - `| pass | 승인 / fail 로 뒤집기 / 다시 걷기 |`
  - `| fail | fail 로 둔다 / pass 로 뒤집기 / 다시 걷기 |`
  - `| 미확인(괄호 안 사유 포함) | 다시 걷기 / fail 로 뒤집기 / 그대로 둠 |`
  - `| 무효(코드 변경) | 무효로 남긴다 / 바뀐 경로가 앱 실행 산출물임을 확인하고 판정안 유지 |`
  - 6 절 표: `fail 로 둔다` → `fail`. [P2 그대로 두면: `무효로 남긴다` → `무효`. P2 고치면: `무효로 남긴다` → `미확인`.] 「fail 에서 지금 판정으로 끝내기 · 멈추기」 · 「무효인데 CAP 에 닿아」 · 「루프가 멈추기로 끝나」 행과 aborted 문단은 지운다.

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_e2e_docs.sh` 에 `case_gate_rows_one_pass` — 5 절 표의 네 행이 위 글자 그대로 한 번씩, 6 절에 `| fail 로 둔다 | \`fail\` | 아니오 |` 와 [P2 그대로 두면 `| 무효로 남긴다 | \`무효\` | 아니오 |` · 고치면 `| 무효로 남긴다 | \`미확인\` | 아니오 |`] 한 번. 부재 짝: SKILL `## e2e` 와 e2e.md 전체에 `고치고 다시 돌기` · `리뷰·테스트부터 다시` · `한 번 더 돌기` · `멈추기` · `Fix-loop` · `Retry` · `iteration` · `CAP` 0 번. `case_K8_…` 은 「`## e2e` 가 `## Differential test` 와 `## Final verdict` 사이」 로 바꾼다. `test_plain_qg_templates.sh` L148-178 의 e2e 게이트 단언은 지우고 이 케이스로 갈음한다. L101 M8 의 「iteration 을 쓰지 않는다」 는 「다시 걷기」 불릿의 새 글로. L337 은 「남은 시나리오를 걷지 않고 끝낸다」 가 남는지에 맞춘다.
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 고친다.** E4 의 불릿을 위 넷 선택지로 다시 쓴다 — 「다시 걷기」 는 걷기 펜스부터 다시, 「fail 로 둔다」 · 「무효로 남긴다」 는 E6 뒤 Final verdict 로. 「여러 시나리오」 문단은 루프로 가는 갈래를 지운다. E6 의 「(Fix-loop · Max-iter 의 「멈추기」 · 범위 모드 — 칸은 `안 함`)」 → 「(범위 모드 — 칸은 `안 함`)」. 첫 문단의 「리뷰·테스트 루프가 「멈추기」 없이 끝나면 … 」 → 「판정 뒤 최종 판정 전에 이 절을 한 번 돈다」.
- [ ] **Step 4: 통과를 본다.**
- [ ] **Step 5: 커밋.** `feat(qg)!: 걷기 직후 게이트에서 고치기 · 다시 돌기 · 멈추기를 뺀다`.

---

### Task 5: 리뷰어 정의 셋

**AC:** AC7 · AC20(리뷰어 정의 몫).

**Files:**
- Modify: `plugins/quality-gates/agents/security-reviewer.md`(frontmatter L19-21 만) · `plugins/quality-gates/agents/code-recritic.md`(L11 · L46 의 「iteration」 낱말만) · `plugins/quality-gates/agents/intent-critic.md`(L154-156 `question` 칸 지시만) · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(Step 3 보안 리뷰어 dispatch 의 `iteration: <iteration>${ITERATION}</iteration>` 줄과 `description: "Security review (qg iter N)"` 의 `iter N`)
- Test: `shared/tests/test_agent_input_slots.sh`(그대로 돌림) · `plugins/quality-gates/tests/test_code_recritic_frontmatter.sh`(L51 · L61) · `plugins/quality-gates/tests/test_intent_critic.py`(리뷰어 정의 문장 단언이 있으면)

**Interfaces:**
- Produces: `question` 칸 지시 글 — `- \`question\` — 사용자에게 묻는 질문 한 문장. 처음 보는 사람이 읽을 쉬운 말로 쓰고, 번호는 괄호 안에만 둔다. 직접 확인해 볼 자리가 있으면 그 뒤에 줄을 바꿔 「여기는 직접 확인해 보세요 — <어디 · 어떻게>」 한 줄을 단다 — 따로 된 칸은 없고 \`question\` 글의 일부다.` Task 7 · 10 의 묻는 틀이 이 글의 첫 줄(질문 한 문장)만 질문 창에 싣는다.

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_intent_critic.py` 에 `test_question_field_is_one_sentence` — 리뷰어 정의에 위 지시 글이 한 번, `한두 문장` 0 번. `test_one_pipeline_surface.sh` `case_one_pass_flow` 의 부재 목록에 `iteration: <iteration>` 을 더한다(본문에 0 번 — AC7 「dispatch 줄이 qg 본문에 없다」). `test_code_recritic_frontmatter.sh` L61 의 「앞 iteration」 단언을 고친 낱말(「앞 실행」)로.
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 세 파일을 고친다.** 위 범위 밖 글자는 건드리지 않는다.
- [ ] **Step 4: 통과와 diff 범위를 본다.** 위 테스트 + `bash shared/tests/test_agent_input_slots.sh` PASS. `git diff HEAD~1 -- plugins/quality-gates/agents/` 가 security-reviewer 의 세 줄 삭제 · code-recritic 의 낱말 둘 · intent-critic 의 지시 문단뿐인지 눈으로 보고, 그 diff 를 마지막 보고에 싣는다(AC7 · AC20 의 「diff 가 그 지시에 그친다」 증거).
- [ ] **Step 5: 커밋.** `feat(qg): 리뷰어 정의에서 반복 입력 칸을 빼고 질문 글을 한 문장으로`.

---

### Task 6: reference 둘과 반복 번호 인자

**AC:** AC6(reference · 스크립트 몫).

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md` · `references/state-file-format.md` · `plugins/quality-gates/scripts/review-diff.sh`(머리 주석 L4 · L61 · L226 · L238 의 `extra-iterations\.md`) · qg 본문(`SKILL.md`)과 `references/intent-critic.md` 의 `--iter <N>` · `review-i<N>` · `-i<N>` 자리 [P1 그대로 두면: 그 자리를 새 이름으로 + `review-diff.sh` 의 `--iter` 인자 · 출력 파일 이름 · `shared/test-selection/diff-test-results.py` 의 `--iter` · 메모 이름 · `plugins/quality-gates/scripts/intent_critic.py` `_last_iteration`. P1 고치면: 그 자리를 `--iter 1` · `review-i1` · `-i1` 로]
- Test: `plugins/quality-gates/tests/test_differential_procedure.sh` · `test_review_diff.sh` · `test_a20_tool_agnostic_scope.py` · `test_diff_test_results.py` · `test_intent_critic.py`(L2730 · L3201 · L3206) · `test_intent_wide.py` · `test_lowered_gate_wiring.sh`(L140-144 · L201-205) · `test_readme_state_diagram_complete.sh`(Task 8 에서 README 와 함께)

**Interfaces:**
- Consumes: Task 3 의 `## 고칠 목록` 절 이름.
- Produces: `state-file-format.md` 의 `result.md` 절 차례에서 `## 제외 패치` · `## 추가 반복` 자리에 `## 고칠 목록` 하나. 세션 폴더 파일 목록에서 `excluded.md` · `extra-iterations.md` 가 빠진다. [P1 그대로 두면: 리뷰 diff 파일 이름은 `review.diff` · `review.full.diff` · `review.names` · `review.mode` · `review.doc-paths` · `review.self-state`, 메모는 `head-<runner>.tsv` · `assign.tsv`. `review-diff.sh` 와 `diff-test-results.py` 는 `--iter` 를 받으면 사용법 오류(rc 2, 사유 `--iter 는 받지 않는다 — 한 실행은 한 번 지난다`). P1 고치면: 스크립트 인자 · 파일 이름은 그대로(`--iter 1` · `review-i1.*` · `-i1`), 문장에서 「iteration」 낱말만 뺀다.]

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_differential_procedure.sh` 의 머리 핀 넷(`## D0 실행 시작 — 첫 iteration 에서 한 번` 등)을 새 머리(`## D0 실행 시작` · `## D1 HEAD 축 트리` · `## D2 후보와 배정` · `## D5 짝짓기`)로 바꾸고 「R11: Retry 뒤 iteration 2 …」 케이스를 지운다. `test_lowered_gate_wiring.sh` 의 「`## 제외 패치` 앞」 단언을 「`## 고칠 목록` 앞」 으로. 부재 짝: 두 reference 에 `iteration` · `Retry` · `excluded.md` · `extra-iterations.md` · `제외 패치` · `추가 반복` 0 번, 양의 짝은 `state-file-format.md` 에 `## 고칠 목록` 한 번. [P1 그대로 두면: `test_review_diff.sh` 의 `--iter` · `review-i<N>` 를 새 이름으로 일괄 바꾸고 `case_iter_arg_rejected`(rc 2 + 사유) 를 더한다. `test_diff_test_results.py` 도 같은 꼴의 `test_iter_arg_rejected`.]
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 고친다.**
- [ ] **Step 4: 통과를 본다.** 이 과제 Files 의 테스트 + Task 3 의 Files 테스트를 다시(P1 그대로 두면 파일 이름이 본문과 맞는지).
- [ ] **Step 5: 커밋.** `refactor(qg): 차등 · 상태 파일 reference 에서 반복을 걷어낸다`.

---

### Task 7: intent-critic reference — 끝 안내와 직접 묻는 틀

**AC:** AC14 · AC20(qg 직접 묻는 틀 몫).

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(`--path` 표 L26 의 aborted 행 · L34 의 `aborted` · 직접 묻는 틀 L229-238 · I7 할 일 L309-311)
- Test: `plugins/quality-gates/tests/test_intent_critic.py`(L3161-3179 근처의 문서 문장 단언)

**Interfaces:**
- Consumes: Task 5 의 `question` 글 꼴. `result.md` `## intent-critic` 의 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록과 `## 게시` 줄(게시 펜스가 낸 줄).
- Produces: 직접 묻는 틀의 `question:` 값 `"<질문 글의 첫 줄>"` — 의심하는 것 · 근거의 종류와 근거 줄 · 질문 글의 둘째 줄부터 · 「이유를 남기려면 직접 입력 칸에 「의도다 — 이유」 처럼 쓴다」 는 질문 앞의 따로 된 글에 `질문 <n>` 번호와 함께 둔다.

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_intent_critic.py` 에
  - `test_direct_ask_question_is_one_sentence` — 틀의 `question:` 줄이 `question: "<질문 글의 첫 줄>",` 한 번, 그 앞 글 문단에 `이유를 남기려면 직접 입력 칸에` 한 번(질문 줄 밖), 옛 `근거로 본 것(<근거의 종류>)` 이 `question:` 줄에 0 번.
  - `test_end_guidance_covers_filtered_wrong_choice` — I7 에 「`wrong_choice: true` 인 질문이 있거나, result.md 의 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록이 비어 있지 않으면 — 「같은 브랜치에서 이어 고친다」(그 질문들을 함께 적는다)」 가 한 번.
  - `test_push_line_only_when_published` — I7 의 push 줄이 「`commit:` 이 커밋 해시이고 result.md `## 게시` 줄이 `posted:` 로 시작하면 — 「답 커밋 <해시> 를 push 한다 — 게시된 판정은 그 앞 커밋의 것이다」. 게시하지 않은 실행이면 — 「답 커밋 <해시> 를 push 한다」」 꼴로 갈래가 둘이고, 「게시된 판정」 이 게시하지 않은 갈래의 글에 0 번.
  - `--path` 표에 `aborted` 0 번(양의 짝: `final` · `trivia` · `scope-empty` 행이 남는다).
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: reference 를 고친다.** `intent_critic.py` 는 고치지 않는다(아래 「설계와 리포가 어긋난 자리」 2 · 「설계에 없던 결정」 E3).
- [ ] **Step 4: 통과를 본다.** `python3 -m unittest plugins/quality-gates/tests/test_intent_critic.py` 와 `test_intent_return.py`.
- [ ] **Step 5: 커밋.** `feat(qg): 거른 잘못 골랐다에도 이어 고칠 일을 내고 질문 창엔 한 문장만`.

---

### Task 8: qg 질문 자리 목록 · README · CHANGELOG · 판

**AC:** AC15(행 10 · 26 · 32) · AC17(quality-gates 몫) · AC18(README 락 몫).

**Files:**
- Modify: `shared/tests/fixtures/ask-sites.tsv`(L129-136 지움 · L146-147 의 끝 앵커를 새 5 절 글로) · `plugins/quality-gates/README.md` · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md` 제목 줄(판) · `plugins/quality-gates/scripts/review-diff.sh` 머리 주석(행 10)
- Test: `shared/tests/test_ask_recommendation.sh` · `plugins/quality-gates/tests/test_plain_qg_templates.sh`(L134-141) · `test_plain_readme.sh` · `test_readme_state_diagram_complete.sh` · `test_gate_era_prose_absent.sh` · `test_readme_scope_reconcile.sh` · `test_codex_backward_compat.sh`

- [ ] **Step 1: 실패하는 락을 쓴다.** README 락(`test_plain_readme.sh` 에 케이스 넷):
  - `case_readme_one_pass` — 흐름 그림이 `├ ① 리뷰` 부터 한 번 지나고 `qg iter loop` 0 번, P18 불릿 · L131 · L147 · L228 · L343 · L348 · L439 의 반복 · 상한 · 「한 번 더 돌기」 문장 0 번, 양의 짝으로 「막는 지적이 남아도 묻지 않고 고칠 목록을 result.md 에 남긴다」 한 번. `test_readme_state_diagram_complete.sh` 의 마커 `qg iter loop` 를 `① 리뷰` 로.
  - `case_readme_limits_one_pass` — `## 한계` 절에 「반복 중간 단계」 · 「반복 2 이후」 0 번.
  - `case_readme_rows_10_26_32` — ① `### intent-critic 답 파일` 머리 아래 첫 문단이 답 파일만 말하고 조언자 규칙은 새 머리 `### intent-critic 을 부르는 규칙` 아래에 있다(그 머리를 잠근 락을 같이 고친다) ② 「`--paths` 로 문서만 고른 범위도 넓게 본다」 한 번 ③ 구조 트리의 리뷰어 설명과 「표시 줄의 값이 목록 · 매핑인 문서」 문장이 「그 표시만 무시된다」 를 말한다 · `review-diff.sh` 머리 주석이 지금 동작대로다(설계 행 10 ③ 의 `--origin` 설명은 README 에 없다 — 어긋난 자리 5) ④ 「범위로 부른 리뷰에서 문서만 바뀐 범위면 바뀐 의도 문서의 머리 줄을 따라간다」 한 번(행 26) ⑤ 단계 스위치 행이 「`record` 도 이 스위치를 읽어 답 파일을 쓰지 않는다」 를 말한다(행 32).
  - `test_plain_readme.sh` 「M3(양의 짝): … 멈추기 …」 를 「게시는 판정 그대로 한다」 짝으로.
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 고친다.** README · `ask-sites.tsv`. CHANGELOG 새 머리 `## [16.0.0] — <구현일>`(Task 1 Step 6 의 판 위 major): Removed — 고치기 반복(Fix-loop · 분류표 · Max-iter · Retry) · 범위 모드 끝내기 질문 · e2e 게이트의 고치기 · 다시 돌기 · 멈추기 · 판정 줄의 `제외 패치` · `iter` 칸과 `verdict.py --excluded` · `--iter` · 세션 파일 `excluded.md` · `extra-iterations.md` · `classification.md` · 게시 `skipped: aborted` · security-reviewer 의 `iteration` 입력 칸. Changed — 막는 지적으로 끝난 직접 호출도 판정을 게시한다 · 리뷰어 질문 글 한 문장 · 직접 묻는 틀. `plugin.json` 판 · 본문 제목의 판을 같은 수로.
- [ ] **Step 4: 통과를 본다.** 위 테스트 + `bash shared/tests/test_ask_recommendation.sh`.
- [ ] **Step 5: 커밋.** `docs(qg): README · CHANGELOG 를 한 번 보고 끝나는 흐름으로 · 16.0.0`.

---

### Task 9: 지휘 — 머지 앞 자리 · 이미 보낸 것 · 담당자 틀

**AC:** AC8 · AC21 · AC16(행 29 · 30 · 31 · R3 지적 두 줄 · 행 21 의 `<SD>` · 「설치돼 있지 않으면」 몫).

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`(머리 · `## 호출 줄` · `## 자리` · `### 한 박자` · `### 이미 보낸 것` · `### 에픽 머지 뒤 — 범위` · `### 보내지 못했거나 …` · `### 이름으로 청함` · `## 담당자` · `### 낮춘 지적` · `### 판정과 코드 리뷰 지적` · `## 보관과 기록 파일` · `### 같은 대상에 전에 물은 것`)
- Test: `plugins/spec-distill/tests/test_qg_review_reference.sh`

**Interfaces:**
- Produces(Task 10 · 11 · 12 가 쓴다):
  - 자리 글자 `premerge-pr<번호>`(머지 앞 첫 리뷰) · `recheck-pr<번호>`(좁은 재리뷰) · 쌓인 기록 표지 `premerge-resend-pr<번호> · <사건의 정체>`. 기록 파일 머리 `site:` 값에 `premerge` · `recheck` 를 더한다. 보관 폴더 이름 `qg-<에픽>-premerge-pr<번호>-<날짜>` · `qg-<에픽>-recheck-pr<번호>-<날짜>`(같은 이름이면 `-2` …).
  - 자리 표 행(설계 §2 표의 칸 그대로): `| 머지 앞 | 구현 담당자가 돌아와 구현 대조와 PR 열기(걸음 4)가 끝난 뒤, 걸음 5 의 스위트 대조 앞 | 그 PR 의 바탕 — 기본 브랜치에서 갈라진 커밋(\`git merge-base origin/HEAD <브랜치>\`). 앞 계획 브랜치에 쌓은 PR 이면 그 앞 브랜치의 끝 | 보낼 때의 브랜치 끝 | 에픽 묶음 | 머지를 멈추고 이 에픽 안에서 고친다(\`## 「잘못 골랐다」 의 행선\`) | 에픽 브랜치(에픽 PR 과 함께 머지) |`. 첫 칸 차례는 `spec 승인 앞,머지 앞,로드맵 끝,이름으로 청함,`.
  - 자리 글자 견줌 규칙 한 문장: 「보관 폴더 이름과 쌓인 기록 줄의 자리 글자는 앞자리가 아니라 통째로 견준다 — 자리 글자 바로 뒤가 `-` 이거나 끝일 때만 같은 것으로 본다(PR 3 과 31 을 가른다).」

할 일:
- 「에픽 머지 뒤」 자동 자리 행과 `### 에픽 머지 뒤 — 범위` 를 지우고, 범위 스크립트(`merged_pr_range.py`) 줄은 `### 이름으로 청함` 의 「머지된 에픽」 아래로 옮긴다(그 길은 그대로 — 설계 §2).
- `### 한 박자`: 자동 자리의 단위는 에픽이다 — 「에픽마다 설계에 한 번(spec 승인 앞), 에픽 PR 마다 한 번(머지 앞). 지휘자가 스스로 여는 PR(로드맵 수정 · 지휘자 수리 · 기록만 담은 PR)에는 자동으로 걸지 않는다.」 와 「통합 리뷰 뒤 반영의 고침은 qg 를 다시 거치지 않는다 — 그 고침은 통합 리뷰의 좁은 재리뷰와 완료 전 확인이 본다.」(AC21) 규모 줄은 그대로.
- `### 이미 보낸 것`: 자동 자리 셋 = spec 승인 앞 · 머지 앞 · 로드맵 끝. 머지 앞의 새로 보낼지 줄 — 「보낸 횟수(`qg-<에픽>-premerge-pr<번호>` 자리 글자의 보관 폴더 수)가 보내도 되는 횟수(1 + 글 칸이 `premerge-resend-pr<번호>` 인 쌓인 기록 줄의 서로 다른 사건 정체 수)보다 적을 때만」. 위 견줌 규칙. 행 29 — 「1. 끝난 리뷰」 갈래 끝에 「그 폴더를 가리키는 `## 기다리는 질문` 줄이 남아 있으면 지운다(`ledger drop …`)」. 행 30 — 「2. 도는 중」 앞에 「작업 표의 담당 이름이 하니스 agent 목록(`ListAgents`)에 없으면 도는 중이 아니라 5 의 「돌아오지 못한 리뷰」 로 본다」. 행 27 은 Task 11.
- 행 31 — 기록 파일 「보관 사본:」 · 쌓인 기록 줄의 글 칸 끝 · 「이미 보낸 것」 의 견줌은 보관 폴더의 **이름**(마지막 경로 성분)만 쓴다. `ledger resources` 의 경로 칸에서 이름을 떼어 견준다.
- 행 21 — 머리에 `<SD>` 를 스스로 정의한다(「`<SD>` 는 spec-distill 플러그인 폴더의 절대경로다」). 「설치돼 있지 않으면」 규칙은 `## 호출 줄` 의 그 문장 한 곳에 두고, `conducting.md` 걸음 7 은 이 파일을 가리킨다(Task 11).
- R3 지적 (1) — `### 같은 대상에 전에 물은 것` 의 찾는 명령: 정체를 `printf '%s\n' "- 정체: <id>" > "$TMPDIR/qg-ident"` 로 파일에 쓰고 `git grep -l -F -f "$TMPDIR/qg-ident" <ref> -- "<로드맵 폴더>/reviews/"` 와 `git show "<ref>:<경로>" | grep -n -x -F -f "$TMPDIR/qg-ident"` 로 찾는다 — 「정체는 리뷰 대상의 글에서 온 값이라 셸 따옴표 안에 넣지 않는다」 한 문장.
- `## 담당자` 틀: 미리 받은 답에서 「범위 모드에서 지적이 있을 때의 끝내기 질문에는 「지금 판정으로 끝내기」.」 를 뺀다. 마지막 보고에 「막는 지적 · 차등 결함 목록(고칠 방법 포함, 합성 표가 합치기 전의 목록) 을 글자 그대로」 를 더한다(Task 10 의 되돌리기가 이 목록을 PR 본문에 옮긴다).
- `### 낮춘 지적`: 「머지 뒤 자리면 후속 PR 의 고칠 목록에 올린다」 → 「머지 앞 자리면 다음 되돌리기에 원래 심각도로 넣는다(`## 되돌리기`)」. `### 판정과 코드 리뷰 지적`: 「에픽 머지 뒤 · 로드맵 끝의 지적은 후속 PR …」 → 「머지 앞의 막는 지적은 `## 되돌리기` 로, 로드맵 끝의 지적은 후속 PR 하나의 고칠 목록에」.

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_qg_review_reference.sh`:
  - T:51 첫 칸 차례 핀을 `spec 승인 앞,머지 앞,로드맵 끝,이름으로 청함,` 으로, 위 자리 표 행을 `once` 로(AC8). 부재: `에픽 머지 뒤` 가 `## 자리` 와 `### 이미 보낸 것` 에 0 번.
  - `premerge-unit` — 「에픽 PR 마다 한 번(머지 앞)」 · 「지휘자가 스스로 여는 PR(로드맵 수정 · 지휘자 수리 · 기록만 담은 PR)에는 자동으로 걸지 않는다」 · 「통합 리뷰 뒤 반영의 고침은 qg 를 다시 거치지 않는다」 를 `BEAT` 에서 `once`(AC21).
  - `already-sent-whole-token` — 위 견줌 규칙 문장 `once` + 픽스처 표: 셸 함수 `same_site <폴더 이름> <자리 글자>` 를 이 테스트 안에 두지 않는다(문서 규칙 락이다) — 대신 규칙 문장에 예 `premerge-pr3` 과 `premerge-pr31-2026-11-22` 가 다르다는 구절이 있는지 본다.
  - 행 29 · 30 · 31 문장 `once` 와 옛 「그 폴더 경로를 덧붙인다」 부재.
  - R3 (1): `git grep -l -F -f` 와 `grep -n -x -F -f` 가 `KEEP` 에 한 번씩, 옛 `-e "- 정체: <id>"` 0 번(T:182-183 을 바꾼다).
  - 미리 받은 답: `끝내기 질문` 0 번, `모든 묶음에 「그대로 둔다」` 한 번(T:56 · T:426-431 의 `ENDLBL` 읽기를 지운다 — qg 본문에 그 질문이 없다).
  - `<SD>` 정의 문장 `HEAD_` 에 한 번.
- [ ] **Step 2: 실패를 본다.** `bash plugins/spec-distill/tests/test_qg_review_reference.sh`.
- [ ] **Step 3: `qg-review.md` 를 고친다.**
- [ ] **Step 4: 통과를 본다.**
- [ ] **Step 5: 변이.** 견줌 규칙 문장을 「로 시작하는」 앞자리 꼴로 되돌리기 · 자리 표의 머지 앞 행 지우기 · 「에픽 머지 뒤」 행 되살리기로 각각 FAIL.
- [ ] **Step 6: 커밋.** `feat(conductor): qg 자동 자리를 머지 앞으로 옮기고 보낸 리뷰를 통째로 견준다`.

---

### Task 10: 지휘 — 되돌리기 · 좁은 재리뷰 · 머지 앞 「잘못 골랐다」 · 줄인 묻기 틀

**AC:** AC10 · AC11 · AC12 · AC19 · AC20(지휘자 묻기 틀 몫) · AC16(행 28).

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`(새 절 `## 되돌리기` 를 `## 돌아왔을 때` 다음에 · `### spec 승인 앞` 의 표지 줄 · `## 묻기` · `## 「잘못 골랐다」 의 행선`)
- Test: `plugins/spec-distill/tests/test_qg_review_reference.sh`

**Interfaces:**
- Consumes: Task 9 의 자리 글자 · 표지 · 보관 폴더 이름.
- Produces: PR 본문 절 이름 `## qg 리뷰`(Task 11 의 team 형식 · 걸음 5 문장이 가리킨다). 질문 두 개의 선택지 라벨(Task 12 의 `ask-sites.tsv` 행이 가리킨다).

`## 되돌리기` 절의 불릿(설계 §3 를 차례대로 — 문장은 설계 §3 의 굵은 머리를 그대로 머리로 쓴다):
- **돌아온 즉시 목록을 적는다.** 담당자 마지막 보고의 막는 지적 · 차등 결함 목록(고칠 방법 포함, 합쳐지기 전)을 PR 본문 `## qg 리뷰` 에 글자 그대로, 질문을 묻기 전에. 돌려보내는 글은 그 절에서 싣는다(D30). team 형식은 Task 11.
- **의도 점검 질문이 함께 오면 질문부터 묻는다.** 「잘못 골랐다」 가 하나라도 있으면 돌려보내지 않고 `## 「잘못 골랐다」 의 행선` 의 머지 앞 갈래로 — 그때 막는 지적은 `## qg 리뷰` 에 「돌려보내지 않음」 으로(D26).
- **막는 지적 · 차등 결함이 있으면** 묻지 않고 걸음 5 의 「리뷰 뒤 반영」 과 같은 길로 — `superpowers:receiving-code-review`, 구현 담당자의 격리 worktree 가 남아 있으면 이어 부르고(`SendMessage`) 아니면 새 구현 담당자를 같은 브랜치로(`conductor-dispatch.md` 의 `### 이어 부르기` · `### 구현 agent` 틀). 보내는 글에 지적 목록을 글자 그대로(경로로 넘기지 않는다) 싣고, 마지막 보고에 지적마다 `고친 커밋 <해시>` · `반박 — <사유>` · `손대지 않음 — <사유>` 하나를 적게 한다. 합성 표가 합친 지적은 합쳐지기 전 목록으로 센다.
- **제안은 보이기만 한다** · **막는 지적 없이 끝난 리뷰에서도**(D32) · **낮춘 지적은 표로 보이고** · **설계에 닿는 지적은 고치지 않는다**(`conductor-dispatch.md` 의 `## 사람 자리` 를 가리킨다 — 새 질문 자리가 아니다).
- **고치지 않은 막는 지적.** 질문 하나 — 질문 문장 앞머리에 에픽 이름, 선택지 「다시 돌려보낸다」 · 「반박을 받아들이고 남긴 지적으로 적는다」 · 「이 에픽을 멈춘다」, 설명은 얻음 · 내줌 한 줄씩(아래 글). 고친 커밋이 하나도 없이 돌아온 때도 같다. [P4 그대로 두면: 질문 문단에 「추천을 달지 않는다 — 」 문장. P4 고치면: 「권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」 문장.]
  - 「다시 돌려보낸다」: 얻음: 그 지적을 고칠 기회를 한 번 더 준다 · 내줌: 좁은 재리뷰 한 번을 쓴다
  - 「반박을 받아들이고 남긴 지적으로 적는다」: 얻음: 머지 준비로 간다 · 내줌: 그 지적이 고쳐지지 않은 채 머지되고 `## 통합 리뷰 인계` 에 남는다
  - 「이 에픽을 멈춘다」: 얻음: 고치지 않은 채 머지되는 일이 없다 · 내줌: 이 에픽이 서고 다시 불러야 이어진다
- **좁은 재리뷰.** `range <지난 리뷰의 끝>..<고친 뒤의 끝>` — 지난 리뷰의 끝은 PR 본문 `## qg 리뷰` 에 적은 호출 줄의 끝 커밋, `reviewed_head` 는 견주는 데만(비어 오면 견주지 않는다 — Review Focus 1). 기록 커밋을 빼지 않는다. 범위에 merge 커밋이 있으면(`git rev-list --merges <시작>..<끝>` 가 비지 않으면) 그 PR 을 처음부터 다시 보고 재리뷰 한 번으로 세고 이유를 PR 본문에 적는다(Review Focus 2). 고친 커밋이 없으면 보내지 않는다. 자리 글자 `recheck-pr<번호>`.
- **두 번까지.** PR 하나에 두 번 — 첫 재리뷰 전에 멈출 조건을 PR 본문에. 두 번째 뒤에도 막는 지적이 남으면 질문 하나 — 선택지 「한 번 더 돌려보낸다」 · 「남은 지적을 적고 머지 준비로 간다」 · 「이 에픽을 멈춘다」, 설명 얻음 · 내줌 한 줄씩. 통합 리뷰의 재리뷰 횟수와 따로 센다. [P4 — 위와 같은 문장.]
  - 「한 번 더 돌려보낸다」: 얻음: 남은 지적을 고칠 기회를 한 번 더 준다 · 내줌: 상한을 넘어 리뷰 한 번이 더 든다
  - 「남은 지적을 적고 머지 준비로 간다」: 얻음: 머지 준비로 간다 · 내줌: 남은 지적이 고쳐지지 않은 채 머지되고 `## 통합 리뷰 인계` 에 남는다
  - 「이 에픽을 멈춘다」: 얻음: 고치지 않은 채 머지되는 일이 없다 · 내줌: 이 에픽이 서고 다시 불러야 이어진다
- **좁은 재리뷰의 의도 점검.** 거르지 않는다 — 같은 정체여도 지금 규칙대로 묻고 「같은 대상에 전에 물은 것」 을 앞 글에(D31).
- **PR 본문.** `## qg 리뷰` 에 적는 것(설계 §3 끝 불릿의 목록 그대로)과, 남기기로 한 막는 지적을 `## 통합 리뷰 인계` 에도 받는 에픽과 함께 — 첫 리뷰가 돌아온 뒤와 좁은 재리뷰가 돌아올 때마다 지휘자가 고친다.

`## 「잘못 골랐다」 의 행선` 에 **머지 앞** 갈래(설계 §4 의 불릿 넷 + 거른 「잘못 골랐다」 목록 줄): 그 PR 의 머지 명령 줄을 내지 않는다 · 열린 PR 은 닫지 않는다 · 설계 대화로 돌아가기 **전에** 쌓인 기록 표지 `premerge-resend-pr<번호> · <돌아가게 한 질문의 정체>` 를 적는다 · 다시 받는 머지 앞 리뷰는 PR 전체를 처음부터 보고 「두 번까지」 를 새로 센다(D33) · 범위를 넘으면 재분해 신호 · 담당자 보고의 「이미 『잘못 골랐다』 답이 있어 거른 질문」 은 「앞서 잘못 골랐다고 답한 것이 아직 그대로다」 로 보이고 같은 행선. 행 28 — `### spec 승인 앞` 의 표지 줄을 `spec-resend · <사건의 정체 — 돌아가게 한 질문의 정체 | spec 리뷰 라운드>` 로, 「같은 정체의 표지는 한 번만 센다」 · 「표지는 설계 대화로 돌아가기 전에 적는다」. `### 이미 보낸 것` 의 spec 승인 앞 줄도 「서로 다른 사건 정체 수」 로.

`## 묻기`: 질문 틀의 `question:` 값을 `"<에픽 이름 | 로드맵> — <질문 글의 첫 줄>"` 로 줄이고, 의심하는 것 · 근거의 종류와 관찰 · 질문 글의 둘째 줄부터 · 같은 대상에 전에 물은 것 · 「이유를 남기려면 직접 입력 칸에 「의도다 — 이유」 처럼 쓴다」 는 앞 글에 `질문 <n>` 번호와 함께. 「잘못 골랐다」 설명의 갈래에 `머지 앞: 머지를 멈추고 이 에픽 안에서 고친다.` 를 더하고 `spec 승인 뒤 · 머지 전 에픽` 갈래는 「구현 담당자가 아직 일하는 중이면」 으로 좁힌다(설계 §2 끝에서 둘째 불릿).

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_qg_review_reference.sh` 에 `ssec` 로 `## 되돌리기` 를 읽는 단언들(모두 `once`, 본문에만 있는 구절):
  - `return-record-first` — 「질문을 묻기 전에」 와 「PR 본문 `## qg 리뷰` 에 글자 그대로」(AC10).
  - `return-questions-first` — 「「잘못 골랐다」 가 하나라도 있으면 돌려보내지 않고」(AC10).
  - `return-no-ask` — 「묻지 않고」 · 「경로로 넘기지 않는다」 · 「제안은 보이기만 한다」 · 「원래 심각도로」 · D32 문장(AC10).
  - `return-per-finding-report` — `고친 커밋 <해시>` · `반박 — <사유>` · `손대지 않음 — <사유>`(AC19).
  - `unfixed-blocking-ask` — 세 라벨이 그 차례로 · 얻음 셋 · 내줌 셋 · 「고친 커밋이 하나도 없이 돌아온 때도 같다」 · `## 통합 리뷰 인계`(AC19).
  - `recheck-start-from-pr-body` — 「`reviewed_head` 는 견주는 데만」 과 「비어 오면 견주지 않는다」(AC11 · Review Focus 1).
  - `recheck-merge-commit-full` — `git rev-list --merges` 와 「재리뷰 한 번으로 센다」(AC11 · Review Focus 2).
  - `recheck-cap-two` — 「PR 하나에 두 번」 · 두 번째 뒤 세 라벨 차례 · 「따로 센다」(AC11).
  - `recheck-intent-not-filtered` — 「거르지 않는다」 와 「같은 대상에 전에 물은 것」(AC11).
  - `premerge-wrong-choice` — `WRONG` 에서 「머지 명령 줄을 내지 않는다」 · 「돌아가기 전에」 · `premerge-resend-pr<번호>` · 「처음부터 보고」 · 「새로 센다」 · 「재분해 신호」 · 「앞서 잘못 골랐다고 답한 것이 아직 그대로다」(AC12).
  - `wrong-choice-label-premerge` — 질문 틀 설명에 `머지 앞: 머지를 멈추고 이 에픽 안에서 고친다.` 한 번(AC12).
  - `ask-one-sentence` — 질문 틀의 `question:` 줄이 `question: "<에픽 이름 | 로드맵> — <질문 글의 첫 줄>",` 한 번, 그 줄에 `근거로 본 것` · `이유를 남기려면` 0 번, 앞 글 문단에 `이유를 남기려면 직접 입력 칸에` 한 번(AC20).
  - `spec-resend-identity` — `spec-resend · <사건의 정체` · 「한 번만 센다」 · 「돌아가기 전에」(행 28 · AC16).
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: `qg-review.md` 를 고친다.**
- [ ] **Step 4: 통과를 본다.**
- [ ] **Step 5: 변이.** `return-questions-first` 의 문장을 「돌려보낸 뒤 묻는다」 로 뒤집기 · `recheck-start-from-pr-body` 의 「견주는 데만」 지우기 · `ask-one-sentence` 의 옛 틀 되살리기로 FAIL.
- [ ] **Step 6: 커밋.** `feat(conductor): 머지 앞 qg 지적을 구현 길로 돌려보내고 고친 커밋만 다시 본다`.

---

### Task 11: 지휘 절차 · 걸음표 · 지휘자 skill 본문

**AC:** AC9 · AC11(합치기 미루기 · team 형식 두 번 몫) · AC13 · AC10 · AC19(team 형식 몫) · AC16(행 21 의 걸음 7 몫 · 22 · 23 · 27).

**Files:**
- Modify: `plugins/spec-distill/references/conducting.md`(걸음 1 · 4 · 5 · 6 · 7 · `## team 형식 로드맵` · 손 절차 6 · 8 · 9) · `plugins/spec-distill/references/walk-table.md`(검수 행) · `plugins/spec-distill/skills/epic-conductor/SKILL.md`(`### 4. 규모 공시` · `### 7. 옮김 대조`) · `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`(`### 로드맵 끝` 의 행 27 · team 형식 한 단락)
- Test: `plugins/spec-distill/tests/test_qg_review_reference.sh`(T:466-497 · T:501-503) · `test_conducting_loop.sh` · `test_superpowers_presence.sh`(L27 · L96-98) · `test_walk_table.py`(L43) · `test_walk_next.sh`(L78) · `test_epic_conductor_skill.sh` · team_files 테스트 파일(Review Focus 5)

**Interfaces:**
- Consumes: Task 9 의 「머지 앞」 자리 이름 · Task 10 의 `## 되돌리기` · `## qg 리뷰`.
- Produces: 걸음표 검수 행 `| 검수 | leader | review | — | — | — | spec-distill:integration-reviewer · quality-gates:quality-pipeline |`. 지휘 순환 걸음 5 기본값의 차례 `PR 캐시를 새로 채운 뒤 머지 앞 qg 리뷰와 되돌리기 → 스위트 대조 → 통합 리뷰 → 리뷰 뒤 반영 → 완료 전 확인`.

할 일:
- 걸음 5 기본값: 위 차례와 「머지 앞 qg 리뷰는 `<SD>/skills/epic-conductor/references/qg-review.md` 를 읽고 그 자리(「머지 앞」)의 줄을 따른다」. 손 절차 8 의 셋 앞에 같은 뜻의 불릿 「**머지 앞 qg 리뷰.**」 를 스위트 대조보다 앞에(AC9).
- 걸음 6 · 손 절차 6: qg 담당자를 보내는 문장(「에픽 머지 뒤」)을 지운다. 「열린 에픽 브랜치마다 기본 브랜치를 merge」 에 「머지 앞 리뷰를 보낸 뒤 그 PR 의 되돌리기가 끝나지 않은 브랜치는 끝난 뒤로 미룬다」 를 붙인다(AC9 · AC11).
- 걸음 4: 「에픽 브랜치에 기본 브랜치를 merge 해 …」 를 「구현 담당자가 처음 돌아온 때(머지 앞 리뷰를 보내기 전)에만 … merge 해 …. 되돌리기를 고치고 돌아온 때에는 합치지 않는다」 로(AC11).
- 걸음 1 행 22: 「`## 기다리는 질문` 에 의도 점검 질문 줄이 있으면」 뒤에 「(에픽 줄은 `control_plane.py show <로드맵> <에픽>` 의 `기다리는 질문:` 칸, 로드맵 단위 줄은 기계 상태 파일 `machine.md` 의 `## 기다리는 질문` 절)」.
- 걸음 7 행 21 · 23 · 27: 판단의 「skill 목록에 … 알리고 진행한다」 를 「품질 게이트가 설치돼 있지 않을 때는 `qg-review.md` 의 `## 호출 줄` 대로 한다」 로. 로드맵 끝에서 `ledger resource-dir --roadmap <로드맵> --kind relay --name roadmap` 폴더로 옮김 대조를 한 번 부른다(지휘자 skill 본문 `### 7. 옮김 대조` 에도 그 자리 한 줄). `qg-review.md` `### 로드맵 끝` 과 `### 이미 보낸 것` 에 「로드맵을 닫는 PR 이 머지된 로드맵(기본 브랜치에 그 로드맵의 `reviews/<날짜>-roadmap-end.md` 가 커밋돼 있다)에서는 자동 자리 셋을 보내지 않는다」.
- 손 절차 9 의 「설치돼 있지 않으면」 문장도 같은 가리킴으로(있으면).
- team 형식 절: 불릿 「**검수 걸음의 qg.**」 — 리더가 곧 지휘 세션이라 qg 를 부르는 길은 옛 형식과 같다(`qg-review.md` 의 「머지 앞」 자리, 검수 걸음 때) · 도구 칸에 qg · 리더의 검수 결과 파일 첫 줄(반려 여부)과 지적 목록에 qg 의 막는 지적 · 반려는 시작 묶음의 다음 시도로 구현 걸음에 · 지적별 처리는 다음 시도의 구현 결과 파일에 적게 한다 — 그 지시는 과제 결정 기록의 한 줄로 적어 시작 묶음이 싣게 한다 · 고치지 않은 막는 지적 묻기와 좁은 재리뷰는 옛 형식과 같다 · 「두 번까지」 는 같고 시작 묶음의 연속 실패 멈춤을 상한으로 쓰지 않는다(D24) · [P3 그대로 두면: 옛 형식이 PR 본문 `## qg 리뷰` 에 적는 것(리뷰 범위와 판정 줄 · 지난 리뷰의 끝 커밋 · 돌려보낼 막는 지적 목록 · 재리뷰 횟수 · 멈출 조건)을 검수 결과 파일(검수 시도마다 하나)의 지적 목록 아래 펜스 하나 안에 적고 거기서 세며, PR 이 열리면 그 내용을 본문 `## qg 리뷰` 로 옮긴다. P3 고치면: 그 기록을 과제 결정 기록의 줄로 적고 거기서 센다 — 검수 결과 파일에는 지적 목록만 둔다.] 걸음 · 관문 · 시작 묶음의 코드는 고치지 않는다.
- 지휘자 skill 본문 `### 4. 규모 공시`: `qg 담당자(spec 승인 앞 1 · 머지된 PR 마다 1)` → `qg 담당자(spec 승인 앞 1 · 에픽 PR 마다 머지 앞 1 · 좁은 재리뷰 PR 마다 많아야 2)`.

- [ ] **Step 1: 실패하는 락을 쓴다.**
  - `test_qg_review_reference.sh` T:466-469 · T:471-475 의 걸음 6 · 손 절차 6 진입 문장 핀(`「에픽 머지 뒤」)`)을 걸음 5 · 손 절차 8 의 `「머지 앞」)` 핀으로 바꾸고, `lstep 6` · `mstep 6` 에 `qg-review.md` 0 번(부재)과 `되돌리기가 끝나지 않은 브랜치는 끝난 뒤로 미룬다` 한 번(양의 짝). `lstep 5` 에서 `머지 앞 qg 리뷰와 되돌리기 → 스위트 대조` 한 번(차례 · AC9). `lstep 4` 에 `되돌리기를 고치고 돌아온 때에는 합치지 않는다` 한 번(AC11). T:491 과 `test_superpowers_presence.sh` L27 · L96-98 의 걸음 7 「설치돼 있지 않다」 핀은 「`qg-review.md` 의 `## 호출 줄` 대로」 핀으로 바꾸고, `설치돼 있지 않다` 가 `qg-review.md` 의 `## 호출 줄` 에 한 번 · `conducting.md` 에 0 번. 걸음 1 행 22 구절 · 걸음 7 `--name roadmap` · 행 27 문장 `once`. T:501-503 규모 공시 핀을 새 글로.
  - team 형식 절 단언(`test_qg_review_reference.sh` 의 CD 블록에 `team_sec`): 「검수 걸음의 qg」 머리 · `quality-gates:quality-pipeline` · 「다음 시도의 구현 결과 파일」 · 「과제 결정 기록의 한 줄」 · 「연속 실패 멈춤을 상한으로 쓰지 않는다」 · [P3 그대로 두면 「지적 목록 아래 펜스 하나 안에」 · 「PR 이 열리면 그 내용을 본문 `## qg 리뷰` 로 옮긴다」 · 고치면 「과제 결정 기록의 줄로 적고 거기서 센다」] 각 `once`(AC10 · AC11 · AC13 · AC19).
  - `test_walk_table.py` L43 기대를 `spec-distill:integration-reviewer · quality-gates:quality-pipeline` 으로 · `test_walk_next.sh` L78 도. `walk_table.py check` 가 기본 표에 0 을 내는 기존 `test_cli_check` 가 그대로 PASS 해야 한다(AC13).
  - `test_epic_conductor_skill.sh` 에 `### 7. 옮김 대조` 의 `--name roadmap` 한 번.
  - team_files 테스트: `test_review_result_qg_block_is_not_machine_lines` (Review Focus 5).
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 고친다.**
- [ ] **Step 4: 통과를 본다.** 위 테스트 + `test_conducting_reference.sh` · `test_parallel_recommend_docs.sh` · `test_repo_literals.sh` · `shared/tests/test_skill_reference_pointers.sh`.
- [ ] **Step 5: 커밋.** `feat(conductor): 걸음 5 에 머지 앞 qg 를 넣고 걸음 6 의 머지 뒤 qg 를 뺀다`.

---

### Task 12: 공용 락 · spec-distill README · 의존 표 · 판

**AC:** AC16(행 21 의 하한 몫) · AC17(spec-distill 몫).

**Files:**
- Modify: `shared/tests/test_dispatch_disposition.sh`(L73-78 · L290-291) · `shared/tests/fixtures/ask-sites.tsv`(qg-review.md 새 질문 행) · `plugins/spec-distill/README.md`(L437) · `plugins/spec-distill/dependencies.md`(L18) · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Test: `shared/tests/test_dispatch_disposition.sh` · `shared/tests/test_ask_recommendation.sh` · `plugins/spec-distill/tests/test_qg_review_reference.sh`(T:511-518)

- [ ] **Step 1: 실패하는 락을 쓴다.** `test_dispatch_disposition.sh` — 플러그인 agent 정의에서 센 수를 `PRINT_1_plugin_agents %d` 로 따로 내고(내장 `general-purpose` 를 더하기 전), 하한을 그 수에 건다: `if [ "${n_plugin_agents:-0}" -lt 1 ]; then no "에이전트 도출이 0 — 도출이 깨졌다 (vacuity 하한 — 내장 agent 이름을 뺀 수)"`. 변이로 확인: 도출 정규식을 깨뜨리면(플러그인 agent 0) FAIL — 지금은 내장 이름 하나로 1 이 되어 통과한다. `test_qg_review_reference.sh` T:511-518 의 README · 의존 표 핀을 `spec 승인 앞 · 머지 앞 · 로드맵 끝 · 이름으로 청한 리뷰` 로. `ask-sites.tsv` 에 qg-review.md 의 두 질문 행 — 질문 문단이 `AskUserQuestion` 을 이름으로 쓰면 행마다 `plugins/spec-distill/skills/epic-conductor/references/qg-review.md<TAB><종류><TAB>**고치지 않은 막는 지적.**<TAB><끝><TAB>1<TAB>3` · `…<TAB>**두 번까지.**<TAB>…<TAB>1<TAB>3`, 종류는 [P4 그대로 두면 `비움` · 고치면 `지시`].
- [ ] **Step 2: 실패를 본다.**
- [ ] **Step 3: 고친다.** README · `dependencies.md` 의 자리 넷 글. 의존 표의 판 칸은 손으로 고치지 않는다 — `python3 plugins/spec-distill/scripts/check_deps.py measure` 를 돌려 quality-gates 행을 다시 잰다(Task 8 의 16.0.0 이 깔린 판이 아니면 잰 값 그대로 두고 그 사실을 보고). CHANGELOG `## [8.31.0] — <구현일>`(Task 1 Step 6 의 판 위 minor): Changed — qg 자동 자리 「에픽 머지 뒤」 → 「머지 앞」, 되돌리기 · 좁은 재리뷰 · 머지 앞 「잘못 골랐다」, 의도 점검 질문 창에 한 문장, 걸음표 검수 행의 qg, 넘겨받은 행 21–23 · 27–31, R3 리뷰 지적 둘. Removed — 담당자 틀의 범위 모드 끝내기 질문 답. `plugin.json` 같은 수.
- [ ] **Step 4: 통과를 본다.**
- [ ] **Step 5: 커밋.** `chore(spec-distill): 처분 하한을 내장 agent 를 뺀 수로 · README · 의존 표 · 8.31.0`.

---

### Task 13: 마지막 확인

**AC:** AC18(새 실패 0) · 전체 AC 대조.

- [ ] **Step 1: 전체 스위트.** Global Constraints 의 잠금 줄로 한 번. 이 브랜치에만 있는 실패가 있으면 그 이름을 적고 원인을 고친 뒤 다시(지휘자의 머지 전 스위트 대조가 정본이다). `TestCrossResolverAdvisory` 는 worktree 전용 기존 실패로 알려져 있다 — 기본 브랜치에서도 실패하는지 보고 적는다.
- [ ] **Step 2: 부재 코퍼스.** `git grep -n -e 'Fix-loop' -e 'Max-iter' -e 'excluded.md' -e 'extra-iterations.md' -e 'classification.md' -e 'accepted with findings' -e 'aborted iter' -e 'skipped: aborted' -e '고치고 다시 돌기' -e '한 번 더 돌기' -e '제외 패치' -e '에픽 머지 뒤' -- plugins shared ':!plugins/*/CHANGELOG.md'` 가 0 줄(셸 grep 이 아니라 `git grep` — 숨김 폴더 · 심볼릭 링크 누락 없음). 남으면 그 자리를 고친다.
- [ ] **Step 3: 마지막 전체 리뷰.** 고른 실행 방식의 마지막 전체 리뷰에 설계문서 `## Acceptance Criteria` 의 AC 목록(AC1–AC21)을 싣고, AC 마다 한 줄 `AC1: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐)로 보고하게 한다. 같은 리뷰가 설계문서 `## 있는 것 검토` 가 고른 것 — qg 범위 호출 · 걸음 5 「리뷰 뒤 반영」 과 좁은 재리뷰 두 번 규칙 · `superpowers:receiving-code-review` · 걸음표 검수 걸음 · 「이름으로 청함 — spec 승인 뒤 · 머지 전」 의 범위 잡는 법 · 설계 대화로 돌아가 고치는 길 · 재분해 절차 — 을 실제로 썼는지(같은 것을 다시 만들지 않았는지)도 묻는다. 리뷰어 프롬프트에 「plan-mandated 테스트 코드도 같은 눈으로 본다」 와 끝에서 끝 흐름(qg 판정 → 지휘자 기록 → 되돌리기 → 좁은 재리뷰 → 스위트 대조)의 이음매를 물어라. 보고를 git 이 추적하지 않는 파일(`TMPDIR/ac-report.md`)에 적는다.
- [ ] **Step 4: 미룸.** 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리고 커밋(`docs(spec): R4 설계 미룸 표에 구현 뒤 미룬 것을 더한다`).
- [ ] **Step 5: 묶음 대조.** `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.29.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-22-qg-review-only-design.md <TMPDIR/ac-report.md>` 를 돌려 경고를 마지막 보고에 싣는다(지휘자가 PR 전에 사용자에게 보인다).
- [ ] **Step 6: 마지막 보고.** 판정 목록 전체 · AC 보고 전체 · Task 5 의 리뷰어 정의 diff · 커밋 목록 · 브랜치 끝 · 남긴 파일 · 본 테스트 실패와 이름.

---

## 설계와 리포가 어긋난 자리

계획을 쓰기 전에 설계문서의 2라운드 뒤 고친 문장(D28–D33 · §2–§4 · §7)과 Handoff 의 확인 대상을 기본 브랜치 `f153a43b` 의 리포와 견줬다. 설계문서의 글자 · 수용 기준 · 보이는 동작은 고치지 않았다.

1. **검수 결과 파일의 형식(§2 · D28).** `team-files.md` §5 는 「리더는 … 첫 줄에 반려 여부 한 줄을, 그 아래에 **지적 목록만** 적는다」 고 한다. 기계(`team_files.py` `parse_result`)는 펜스 밖 줄머리의 기계 줄 여섯(`Task ` · `Ruling:` · `AC<n>:` · `규칙 반증:` · `산출물:` · `끝 — `)만 읽고 그 밖 글과 닫힌 펜스는 무시해 막지 않는다. 형식 정본의 글은 막고 기계는 막지 않는다 — 설계가 「막으면 과제 결정 기록의 줄로」 라 했으므로 P3 으로 올렸다.
2. **끝 안내 문구의 주인(§5 · AC14 · Files to Modify).** 설계는 `intent_critic.py` 를 「끝 안내」 로 고칠 파일로 든다. 「같은 브랜치에서 이어 고친다」 와 「게시된 판정」 은 스크립트가 내지 않고 `references/intent-critic.md` I7 의 글을 오케스트레이터가 `intent-return.md` 칸으로 짓는다. 거른 「잘못 골랐다」 는 `intent-return.md` 행이 아니고(계약 2) `result.md` `## intent-critic` 의 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록에만 있다. 이 계획은 AC14 를 reference 에서 한다(Task 7) — 스크립트 · 계약은 그대로.
3. **반복 번호가 스크립트 인자 · 파일 이름이다(D7 · Files to Modify).** `review-diff.sh --iter <N>`(출력 `review-i<N>.*`, 테스트 `test_review_diff.sh` 에 약 175 자리), `shared/test-selection/diff-test-results.py --iter <N>`(메모 `head-<runner>-i<N>.tsv` · `assign-i<N>.tsv`), `intent_critic.py` `_last_iteration`. 설계 Files to Modify 에 `shared/test-selection/` 이 없다 → P1.
4. **e2e 칸에 `무효` 값이 없다(§1 · AC4).** 설계는 「걷는 사이 코드가 바뀐 걷기는 e2e 칸에 무효로 남는다」 고 하지만 `verdict.py` `E2E_STATES` 는 `pass · fail · 미확인 · 안 함 · 걸을 것 없음 · 걸을 도구 없음 · 꺼짐(kill switch)` 이고, 지금 「무효에서 그대로 둠」 은 `미확인` 칸이다 → P2.
5. **README 다듬기 행 10 ③ 의 `--origin` 설명.** qg README 에는 `--origin` 설명이 없다 — 그 설명은 qg 본문 L129 에만 있다. 「`--origin` 설명의 「만」」 을 고칠 자리가 README 에 없어 그 갈래는 할 일이 없다(행 10 ② · 행 26 의 문장도 README 에 없어 «더하는» 일이다).
6. **「설치돼 있지 않으면」 규칙의 자리(행 21).** 이 규칙은 `qg-review.md` 말고도 `conducting.md` 걸음 7 · spec-distill README 에 있고, `test_qg_review_reference.sh` T:491 과 설계가 고칠 테스트로 들지 않은 `test_superpowers_presence.sh`(L27 · L96-98)가 걸음 7 의 그 문장을 잠근다 — Task 11 이 두 테스트를 함께 고친다. README 는 사람에게 알리는 글이라 그대로 둔다.
7. **판 번호.** 기본 브랜치에서 quality-gates 는 15.3.1, spec-distill 은 8.30.0 이다(설계는 번호를 머지 직전에 정한다고만 한다). `dependencies.md` 의 quality-gates 최소 판은 15.3.0.
8. **연속 실패 멈춤의 셈(§2 · D24).** `job_results.py` `failed_attempts` 는 「「끝」 줄이 있고 산 받음 줄이 없는 시도」 를 이어지는 만큼 센다 — 설계의 「받음 줄이 없는 시도만 실패로 센다」 보다 조건이 하나 더 있지만(「끝」 줄), qg 가 반려한 받아진 시도를 세지 않는다는 결론은 같다.

맞은 것: 은퇴하는 kill switch 없음(일곱) · `conducting.md` 걸음 4 의 「에픽 브랜치에 기본 브랜치를 merge 해」 와 걸음 6 의 「열린 에픽 브랜치마다 기본 브랜치를 merge」 · `intent-critic.md` 의 `question` 칸 「한두 문장」 과 스크립트가 `observation` 을 근거 줄 · 읽은 인용으로 채우는 것(`intent_critic.py` 945–951) · `qg-review.md` 의 「이미 보낸 것」 앞자리 견줌(`merged-pr<번호>` 로 시작) · `git grep -l -F -e "- 정체: <id>"` · `spec-resend · <사건>` 표지 · 걸음표 검사(`walk_table.py check`)가 도구 칸을 보지 않는 것 · `test_dispatch_disposition.sh` 의 하한이 내장 `general-purpose` 를 더한 뒤 1 이라 공허하다는 것(행 21).

## 설계에 없던 결정

이 계획이 정해야 했던 자리다. P1–P4 는 위 「열린 결정」 이고 답이 오기 전에는 구현하지 않는다. E1–E6 은 설계가 「계획이 정한다」 고 맡긴 글자 · 이름이거나 보이는 동작을 바꾸지 않는 배치라 이 계획이 정했다 — 다르게 하려면 지휘자가 고친다.

- **P1 스크립트의 반복 번호(`--iter` · `i<N>`).** 그대로 두면(설계 D7 대로 남김없이): `review-diff.sh` · `diff-test-results.py` 의 `--iter` 를 없애고 파일 이름에서 번호를 뺀다 — 설계 Files to Modify 밖의 `shared/test-selection/diff-test-results.py` 를 고치고 테스트 약 200 자리를 바꾼다. 고치면: 스크립트 인자 · 파일 이름은 두고(본문은 `--iter 1` · `review-i1.*` 로 쓴다) 본문 문장에서 반복이라는 말만 뺀다 — 본문에 늘 1 인 파일 표지가 남는다(설계 Rejected Alternatives 첫 줄이 걱정한 「늘 1 인 반복」 에 가깝다). 권고: 그대로 두면 — 기각한 대안과 부딪히지 않고, 바꾸는 것은 기계적이다.
- **P2 걷는 사이 코드가 바뀐 걷기의 e2e 칸.** 그대로 두면(설계 §1 · AC4 글자대로): `verdict.py` 의 e2e 칸 값에 `무효` 를 더한다 — 판정 줄을 읽는 곳(게시 글 · 지휘자 기록 「qg 판정」 줄)에 새 값이 보인다. 고치면: `무효로 남긴다` 를 `미확인` 칸으로 적고 무효는 걷기 기록에만 남긴다 — 스크립트는 그대로지만 AC4 의 「e2e 칸에 무효로」 와 글자가 다르다. 권고: 그대로 두면.
- **P3 team 형식의 qg 리뷰 기록 자리.** 그대로 두면(설계 §2 · D28 글자대로): 검수 결과 파일의 지적 목록 아래 펜스 안에 적는다 — 기계는 막지 않지만 형식 정본의 「지적 목록만」 과 글이 어긋난다(어긋난 자리 1). 고치면: 과제 결정 기록의 줄로 적는다(설계가 「막으면」 의 길로 든 것) — 형식 정본과 맞지만 리뷰 범위 · 횟수가 결정 기록에 쌓인다. 권고: 그대로 두면 — 형식 정본의 「만」 은 리더가 리뷰어 전문을 옮기지 말라는 뜻으로 읽히고, 펜스가 기계 줄 충돌을 막는다(Review Focus 5).
- **P4 지휘자의 새 질문 둘(고치지 않은 막는 지적 · 두 번까지)의 추천.** 설계는 선택지 · 설명만 정하고 추천을 말하지 않는다. 그대로 두면: 추천을 달지 않는다(「추천을 달지 않는다 — 」 문장, `ask-sites.tsv` 종류 `비움`) — 남길지 멈출지는 사용자 몫이라는 읽기. 고치면: 「권하는 쪽이 있으면 첫 자리로 옮기고 라벨 끝에 「(권장)」을 단다」(종류 `지시`) — 지휘자가 상황마다 권한다. 권고: 고치면 — 레포의 질문 규칙(추천이 있으면 첫 자리 + 「(권장)」)과 같고, 재리뷰 상한 질문(걸음 5)도 같은 지시를 쓴다.
- **E1 자리 글자 · 표지 이름.** `premerge-pr<번호>` · `recheck-pr<번호>` · `premerge-resend-pr<번호> · <사건 정체>`, 기록 파일 `site:` 값 `premerge` · `recheck`(설계 §4 「보관 폴더 · 기록 파일의 이름은 계획이 정한다」).
- **E2 고칠 목록의 꼴.** `result.md` 의 `## 고칠 목록`(`### 막는 지적` · `### 제안` · `### 차등 회귀`)과 끝 한 줄의 글(설계 Deferred to plan).
- **E3 intent-critic `gate --path aborted`.** 결과 `aborted iter <N>` 이 없어져 부를 곳이 사라진다. reference 의 표에서 지우고 스크립트의 그 갈래(`intent_critic.py` L131 · 테스트 둘이 묶는다)는 남긴다 — `intent-return.md` 계약 2 의 사유 값을 바꾸지 않으려는 것(D13).
- **E4 요구 색인의 `I1` → `IC1`.** 넘겨받은 행 7 의 「I1 라벨 겹침」 을 qg 본문 요구 색인 쪽 번호를 바꿔 푼다(references/intent-critic.md 의 걸음 I1 은 그대로).
- **E5 판정 줄 꼴.** `qg: <decision> · 막는 지적 B · 선택 O · 차등 새 실패 F[ · e2e E] · <sha>` 와 `verdict.py` 거절 사유 글.
- **E6 걸음표 도구 칸 표기.** `spec-distill:integration-reviewer · quality-gates:quality-pipeline`.
