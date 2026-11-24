# 리더 덜기와 다시 띄우기 — 계획 1 걸음만 읽기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 리더가 한 걸음에서 그 걸음의 지시서만 읽고, 걸음 1 의 맞추기를 명령 하나로 끝내게 해서, 리더의 맥락을 지휘에 집중시킨다(설계 G0 의 수단 G1 · G2 · G6).

**Architecture:** 지휘 절차서(`references/conducting.md`, 102KB)를 차례 하나 · 걸음 지시서 일곱 · 끊고 잇기 지시서 · team 형식 지시서 · 손 절차 파일로 가른다. 차례의 걸음 표가 걸음 → 지시서 경로와 단계 → 걸음의 정본이고, 새 파서 모듈(`conductor_toc.py`)이 그 표를 읽는다. 새 맞추기 명령(`conductor_sync.py`)은 걸음 1 의 정해진 차례를 지금의 스크립트들로 한 번에 돌고 구간마다 한 줄만 내며, 끝에 일마다 서 있는 걸음과 지시서를 차례 표에서 찾아 낸다. 옮기는 커밋과 고치는 커밋을 갈라 락이 옮김을 증언하게 한다.

**Tech Stack:** Python 3(표준 라이브러리 — 기존 스크립트와 같은 꼴) · bash 테스트(`shared/tests/assert.sh`) · unittest · git · `hc`(있으면).

**Spec:** `docs/superpowers/specs/2026-11-24-leader-step-guides-restart-design.md` — 이 계획은 §1 · §2 와 §6 의 계획 1 줄을 구현한다(설계 §6 표: 계획 1 = §1(통합 리뷰어 자리 옮기기는 빼고) · §2(계획 2 가 더하는 구간 셋은 빼고), 수용 기준 AC1 ~ AC13 · AC35 · AC37, AC34 는 계획마다).

## Global Constraints

- 경로는 따로 적지 않으면 `plugins/spec-distill/` 기준이다. 기본 브랜치는 `origin/HEAD` 에서 읽는다 — 스크립트에 박지 않는다(설계 Constraints 「레포마다 다른 값(경로 · 테스트 명령 · 기본 브랜치 · 모델 · 판 번호 파일)은 스크립트에 박지 않고 지금의 해결자와 레포 설정에서 읽는다」).
- 「걸음 1 ~ 7 의 번호와 이름은 바꾸지 않는다」(설계 Constraints) — 1 맞추기 · 2 사람 몫 모으기 · 3 다음 일 고르기와 보내기 · 4 돌아오기 · 5 머지 전 확인 · 6 머지 뒤 · 7 끝.
- 「손 절차를 다시 쓰거나 없애기. 글자 그대로 옮기기만 한다」(설계 Non-goals) — 손 절차 파일 본문은 이 계획 끝까지 옮긴 그대로다.
- 「보내는 글 틀 · 품질 게이트 절차 · 상태 브랜치 절차 파일을 쪼개기」 는 하지 않는다(설계 Non-goals). 그 파일들에서 고치는 것은 과제가 이름 붙인 문장뿐이다.
- 「superpowers 는 부르기만 하고 고치지 않는다」 · 「기계 상태를 쓰는 명령은 표지를 쥔 세션만 돌린다. 상태 폴더 쓰기는 지금의 writer 를 거친다」(설계 Constraints) — 맞추기 명령은 기계 상태를 직접 쓰지 않고 지금의 스크립트를 부른다.
- 호출 이름(`epic-conductor`) · 스크립트 이름 접두(`conductor_`) · 상태 폴더 · 브랜치의 `conductor` 글자는 그대로다(설계 Non-goals). 낱말(「지휘자」 → 「리더」)은 계획 4 의 몫이다 — 이 계획이 새로 쓰는 글은 「리더」 를 쓰고, 옮기는 글의 낱말은 고치지 않는다.
- `### 6. 통합 리뷰어` 절(`skills/epic-conductor/SKILL.md`)은 건드리지 않는다(설계 §1.4 — 계획 3 의 몫).
- 옮기는 커밋에서는 「단언 수가 줄지 않는다」(설계 AC8). 기준 수는 Task 0 이 잰 값이다.
- 테스트는 `docs/testing.md` 를 따른다 — 가짜는 시스템 경계(gh · hc · git 원격 · 시간 · 네트워크)에만 두고 이 레포의 스크립트와 함수는 가짜로 바꾸지 않는다. 새 셸 테스트는 `chmod +x` 하고 `git ls-files -s` 로 100755 를 확인한다. 「없어야 한다」 를 보는 확인에는 「있을 때 잡힌다」 짝을 둔다.
- 새 파이썬 스크립트는 `#!/usr/bin/env python3`, 파일 읽기 · 쓰기에 `encoding="utf-8"` 를 적는다(레포 락). 긴 한글 문자열은 인접 문자열로 줄을 나눈다.
- 전체 스위트는 공유 잠금 줄로만 돈다 — `python3 "<SD>"/scripts/suite_lock.py run --lock <보내는 글이 준 잠금 경로> --owner <이름> --wait 3600 -- bash -c 'bash tools/suite/run-all.sh'`(지휘자 대조와 같은 공유 잠금 — 못 잡으면 주인 · 잡은 시각을 보고한다). 과제 경계에서는 그 과제의 테스트와 바꾼 파일을 코퍼스로 읽는 락만 돈다.
- 커밋: pathspec 커밋(`git commit -- <경로…>`) · Conventional Commits · 설명은 한국어 · type/scope 는 영어 · 구현 커밋 트레일러 `Spec: docs/superpowers/specs/2026-11-24-leader-step-guides-restart-design.md`. `git stash` · 공유 임시 폴더 glob 삭제 · 다른 worktree 의 git 은 쓰지 않는다. 임시 파일은 보내는 글이 준 `TMPDIR` 아래에만 둔다.
- 판 번호: spec-distill 는 지금 9.3.0 이다. 이 PR 은 새 surface(새 명령 · 새 reference)라 minor 를 올린다 — 머지 직전 `origin/HEAD` 의 판보다 한 minor 위로 정한다(Task 10).

## Review Focus

1. **차례 표를 사람이 고쳐 꼴이 깨진 경우** — 칸이 빠지거나 걸음 번호가 겹치면 맞추기 명령은 죽지 않고 「차례 — 이상: 표를 읽지 못했다 — <사유>」 를 내고 나머지 구간을 끝까지 돈다. Task 1 의 `test_parse_rejects_*` 와 Task 8 의 `test_toc_broken_does_not_stop` 이 문다.
2. **상태 보기가 처음 보는 줄을 낸 경우** — 맞추기 명령이 아는 「이상 없음」 꼴이 아닌 줄은 버리지 않고 이상으로 원문을 낸다(모르는 줄을 조용히 삼키면 리더가 기다리는 질문 · 온 글을 놓친다). Task 8 의 `test_status_line_outside_benign_is_shown` 이 문다.
3. **세션 번호를 얻지 못한 셸에서 원장 명령을 부른 경우** — 아무것도 쓰지 않고 멈춘다(빈 번호로 표지를 잡지 않는다). Task 7 의 `test_missing_session_writes_nothing` 이 문다.
4. **표에 없는 단계 이름(대기 · 로드맵 밖 일 · 뒤 판이 더한 단계)** — 그 일의 줄은 「걸음 없음 — 차례 표에 이 단계가 없다」 로 나오고 명령은 0 으로 끝난다. Task 8 의 `test_unmapped_stage_line` 이 문다. 머지된 에픽은 「끝나지 않은 일」 이 아니어서 걸음 6 이 출력에서 사라지기 쉽다 — 그 에픽의 줄이 기계 상태에 남은 동안은 걸음 6 으로 나온다. Task 8 의 `test_merged_epic_rows_bring_step6` 이 문다.
5. **나눈 파일 하나가 공유 락의 대상에서 빠진 경우** — 차례에서 읽은 파일 이름으로 견주는 확인이 실패한다. Task 3 의 `test_conducting_lock_targets.sh` 의 변이 대조가 문다.

## 계획이 정한 것

설계가 「계획이 정한다」 로 넘긴 것과 `### Deferred to plan` 가운데 계획 1 에 닿는 것이다. 사용자가 정한 것과 작성자 제안은 고치지 않았다.

| 무엇 | 정한 것 |
|---|---|
| 새 파일 이름(설계 §1.1 · Handoff Context) | `references/conducting.md`(차례 — 이름 그대로) · `references/conducting-step-1.md` ~ `conducting-step-7.md`(걸음 지시서) · `references/conducting-resume.md`(끊고 잇기 지시서) · `references/conducting-team.md`(team 형식 지시서) · `references/conducting-manual.md`(손 절차 파일). 모두 `references/` 바로 아래다 — 가리킴 락이 한 단계만 훑는다 |
| 새 모듈(설계 §2 · Files to Modify 「몇으로 나눌지는 계획이」) | `scripts/conductor_toc.py`(차례 표 파서 — 맞추기 명령과 테스트가 함께 쓴다) · `scripts/conductor_sync.py`(맞추기 명령). 테스트 `tests/test_conductor_toc.py` · `tests/test_conductor_sync.py` · `shared/tests/test_conducting_lock_targets.sh` · 테스트 도우미 `tests/conducting_corpus.sh`(이름이 `test_` 로 시작하지 않아 스위트가 돌리지 않는다) |
| 단계 → 걸음(설계 §2 「들어서는 때 칸에 상태 계산이 내는 단계 이름」) | 걸음 3: 준비 · 설계 중 · 일부 머지 / 걸음 4: 계획 · 구현 중 · 구현 끝 · 진행 중 / 걸음 5: PR · 결과 받음 / 걸음 6: 머지됨 · 끝남(아래 줄의 조건이 붙는다). 걸음 1 · 2 · 7 은 일에 달리지 않는다(칸에 `단계:` 가 없다). 「일부 머지 1/2」 처럼 뒤에 값이 붙는 단계는 표의 이름 뒤에 빈칸이 오면 맞는다 |
| 걸음 6 에 들어서는 때(설계 §2 — 리더의 계획 검토 고침) | 단계가 끝(`roadmap_status.DONE` — 머지됨 · 끝남)인 에픽 가운데 기계 상태에 그 에픽의 줄이 남은 것 — `## 작업`(단계 칸이 끝 낱말 `conductor_state.WORK_DONE` 이 아닌 줄) · `## 자원` · `## 살아 있는 agent` 에서 에픽 칸이 그 에픽인 줄. 맞추기 명령은 그런 에픽을 끝 묶음 `머지 뒤 일이 남은 에픽:` 에 걸음 6 과 그 지시서 경로, 남은 줄 수와 함께 낸다. 줄이 없으면 내지 않는다. 상태에서 읽으므로 같은 상태면 같은 출력이고(AC11), 새 기계 상태 칸은 만들지 않는다. 못 잡는 것: 줄을 남기지 않는 머지 뒤 일(남은 에픽 재평가 · 넘김 확인)만 남은 경우 — 그 일은 걸음 5 지시서의 머지 뒤 차례가 걸음 6 지시서로 잇는다 |
| 표에서 걸음을 찾지 못했을 때(Deferred e5f19361) | 그 일의 줄 끝을 `→ 걸음 없음 — 차례 표에 이 단계가 없다` 로 내고 종료 코드는 바꾸지 않는다. 표를 읽지 못하면 `차례 — 이상: 표를 읽지 못했다 — <사유>` 한 줄을 내고 일마다의 걸음 칸 없이 나머지를 돈다 |
| 머지 준비 담당자 틀의 줄(Deferred 719f25e9) | 계획 1 의 차례에는 그 줄이 없다(파일이 계획 3 뒤에 생긴다). 계획 3 이 차례의 「걸음에 달리지 않은 지시서」 목록에 「리더는 읽지 않는다 — 머지 준비 담당자를 보낼 때 명령이 채운다」 로 더한다 — 그 줄의 경로도 AC7 확인이 따라온다 |
| 끊고 잇기 지시서를 읽는 때(Deferred 32896450 · 설계 §1.2) | 계획 1 의 차례 줄은 지금 글의 자리를 이름으로 든다 — 「승인 뒤 계획 담당자를 보낸 직후 · 담당자를 보낸 뒤처럼 끊기 좋은 자리에서 맥락이 무거울 때」 |
| 「이 세션에서 처음일 때만」(설계 §2) | 표지 구간이 표지를 새로 잡았을 때(`claim` 이 `acquired`) 또는 넘겨받았을 때(`--takeover`)다. 이미 쥐고 있던 표지(`held` — 같은 세션의 압축 뒤)면 그 두 구간을 돌지 않는다 |
| 넘겨받기(설계 §2 「멈춤」) | 맞추기 명령은 다른 세션이 쥔 표지에서 5 로 멈춘다. 사용자가 넘겨받기를 고르면 리더는 같은 명령에 `--takeover` 를 붙여 다시 부른다 — 표지 구간이 `ledger takeover` 를 부른다 |
| 세션 번호를 얻지 못했을 때(설계 §2 · AC12) | 원장 명령은 `[spec-distill] 세션 번호를 얻지 못했다 — --session 을 주거나 Claude Code 세션 안에서 부른다. 기계 상태를 쓰지 않았다` 를 내고 3 으로 끝난다. 맞추기 명령은 작업 목록 구간까지 돈 뒤 표지 구간에서 같은 줄로 3 으로 멈춘다(지금의 「읽기 전용으로 지도만 보인다」) |
| 규모 줄(설계 §2 「규모 줄을 함께 낸다」) | 지금 SKILL `### 4. 규모 공시` 의 꼴 그대로이고, `agent 약` 은 `9 × 남은 에픽 수 + 1` 이다 — 에픽마다 계획 1 · 구현 1 · 통합 리뷰 1 · qg 담당자 4(spec 승인 앞 1 · 머지 앞 1 · 좁은 재리뷰 2) · spec 리뷰 한 라운드의 리뷰어 2, 그리고 로드맵 끝 qg 1. 지금 글이 모델에게 맡긴 「대략」 을 한 꼴로 굳힌 것이다 |
| 세션 담당자 구간(설계 §2 · §3.6 — 계획 1 몫) | `hc` 와 `$HC_TERMINAL_ID` 가 있으면 `hc ls --json --all` 의 `parent` 가 내 주소인 터미널을 기계 상태 `## 살아 있는 agent` 의 이름과 견준다. 표에 있고 내 자식이 아닌 줄은 「견줄 줄」(하니스 하위 agent 일 수 있다 — 리더가 agent 목록으로 견준다), 내 자식인데 표에 없으면 「표에 없는 내 자식」. 다른 터미널의 리더가 띄운 담당자 가르기는 계획 2 다 |
| 옮기는 커밋의 차례 | 옛 1 ~ 12행(제목 · `## 지휘 순환` · 머리 문단 · 공통 규칙 다섯 불릿)과 옛 `### 알림` 을 두고, 걸음 표(함께 읽는 것 칸은 `—`) · 「걸음에 달리지 않은 지시서」 목록 · 끝 절 가리킴 한 줄만 더한다. 나머지 차례 글은 Task 3 에서 쓴다 |

## 다시 확인(계획을 쓰며 본 것 — 2026-11-25, HEAD 4ba5ee1f)

설계가 근거로 든 자리 가운데 달라진 것은 하나다.

- PR #332 가 지휘 절차서에서 고친 한 줄은 **지휘 순환 걸음 3 이 아니라 손 절차의 「3. 흐름과 설계」(옛 145행)** 에 있다 — `source_interview` 가 `source_intent`(옛 문서는 `source_interview`)로 바뀌었다. 지휘 순환 걸음 3 에는 frontmatter 칸 이름이 없다. 그 줄은 손 절차 파일로 글자 그대로 옮겨 간다. 이 계획은 그 줄이 `conducting-manual.md` 에 있는지 본다(Task 2 · Task 10) — 설계 §6 · 상류 · 하류 연계의 「그 줄이 걸음 3 지시서에 있는지 본다」 와 다르다.

나머지는 설계와 같다 — 지휘 절차서 102,388 바이트, 세 파일 174,028 바이트, 절 구성(머리 다섯 불릿 · `### 1.` ~ `### 7.` · `### /compact 시점` · `### 알림` · `## team 형식 로드맵` · `## 손으로 따르는 절차`), 세 파일을 여는 테스트 23개(`git grep -l` 로 셈 — 목록은 Task 0), 공유 락 넷(가리킴 `shared/tests/test_skill_reference_pointers.sh` · 질문 자리 `shared/tests/test_ask_recommendation.sh` + `shared/tests/fixtures/ask-sites.tsv`(지휘 절차서 22행) · 레포 전용 값 `tests/test_repo_literals.sh` 의 `TARGETS` · 쉬운 말 `tests/test_plain_gate_templates.sh` 의 `--emit-scanned` 목록), `ledger release` · `start_bundle.py --role leader` · `state_path.py session-id`(`DEVBREW_SPEC_DISTILL_SESSION_ID` → `CLAUDE_CODE_SESSION_ID`) · 판 9.3.0.

---

## File Structure

| 파일 | 맡는 것 | 과제 |
|---|---|---|
| `scripts/conductor_toc.py`(새) | 차례 걸음 표 · 「걸음에 달리지 않은 지시서」 · 끝 절 가리킴을 읽어 걸음 · 단계 · 지시서 경로를 낸다 | 1 |
| `references/conducting.md` | 차례 | 2 · 3 · 4 · 5 · 6 · 8 |
| `references/conducting-step-1.md` ~ `-7.md`(새) | 걸음 지시서 | 2 · 4 · 8 |
| `references/conducting-resume.md`(새) | 끊고 잇기 지시서(지금 글 그대로 — 계획 2 가 고쳐 쓴다) | 2 |
| `references/conducting-team.md`(새) | team 형식 지시서 | 2 · 6 |
| `references/conducting-manual.md`(새) | 손 절차(글자 그대로) | 2 |
| `scripts/conductor_ledger.py` | `--session` 생략 | 7 |
| `scripts/conductor_sync.py`(새) | 맞추기 명령 | 8 |
| `skills/epic-conductor/SKILL.md` | 진입 단계 · `### 5. 지휘 순환` 읽기 | 9 |
| `references/redecompose.md` · `references/epic-handoff.md` · `skills/epic-conductor/references/qg-review.md` · `README.md` · `scripts/conductor_state.py`(주석 한 줄) | 손 절차 · team 절을 가리키는 문장 | 5 |
| `tests/conducting_corpus.sh`(새) | 테스트가 나눈 파일을 읽는 도우미 | 2 |
| 테스트 23개 + 공유 락 넷 | 대상 경로 옮기기 · 새 단언 | 2 ~ 9 |
| `shared/tests/test_conducting_lock_targets.sh`(새) | AC7 | 3 |
| `.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` | AC34 | 10 |

---

### Task 0: 기준 재기(커밋 없음)

**Files:** 없음 — 보고만 `$TMPDIR/plan1-baseline.md`(git 밖)에 쓴다.

**Interfaces:**
- Produces: `$TMPDIR/plan1-baseline.md` — 테스트마다 `<경로> · 통과|실패 · <단언 수>` 한 줄. 셸은 `finish` 의 `Total: N` 의 N, 파이썬은 `Ran N tests` 의 N. Task 2 가 이 수와 견준다.

- [ ] **Step 1: 테스트 목록을 다시 뽑는다**

Run: `git grep -l -E 'conducting\.md|conductor-dispatch\.md|epic-conductor/SKILL\.md' -- 'plugins/*/tests/*' 'shared/tests/*' ':!*fixtures*'`
Expected: 23 줄 — `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` 와 `plugins/spec-distill/tests/` 의 `test_conducting_loop.sh` · `test_conducting_reference.sh` · `test_conductor_dispatch_reference.sh` · `test_conductor_state_branch_docs.py` · `test_decompose_surface.sh` · `test_end_gates.sh` · `test_entry_guidance.sh` · `test_epic_conductor_skill.sh` · `test_human_lines.py` · `test_parallel_recommend_docs.sh` · `test_plain_gate_templates.sh` · `test_qg_review_readable.sh` · `test_qg_review_reference.sh` · `test_repo_literals.sh` · `test_review_handoff_order.sh` · `test_roadmap_status.sh` · `test_superpowers_presence.sh` · `test_team_docs.py` · `test_walk_docs.py`, 그리고 `shared/tests/test_cost_disclosure.sh` · `test_skill_cost_class_place.sh` · `test_skill_reference_pointers.sh`. 더하여 `shared/tests/test_ask_recommendation.sh` 를 함께 잰다. 목록이 다르면 다른 것을 보고에 적고, 새로 든 파일도 함께 잰다.

- [ ] **Step 2: 각각을 한 번 돌려 통과 · 실패와 단언 수를 적는다**

셸은 `bash <경로>`, 파이썬은 `python3 -m unittest <경로>` 를 리포 루트에서 돌린다. 이미 실패하는 것은 이름과 실패 단언을 적는다 — 이 계획이 만든 실패와 가르는 기준이다.

- [ ] **Step 3: PR #332 의 줄을 본다**

Run: `grep -c 'frontmatter `source_intent`' plugins/spec-distill/references/conducting.md`
Expected: `1`(손 절차 「3. 흐름과 설계」 안). 0 이면 멈추고 보고한다.

---

### Task 1: 차례 표 파서

**Files:**
- Create: `scripts/conductor_toc.py`
- Test: `tests/test_conductor_toc.py`

**Interfaces:**
- Produces(뒤 과제가 쓴다):
  - `class Step(NamedTuple): number: int; name: str; stages: tuple; guide: str; also: str` — `guide` 는 `<SD>/references/<이름>.md` 꼴 그대로.
  - `class Extra(NamedTuple): when: str; guide: str`
  - `class Toc(NamedTuple): steps: tuple; extras: tuple; manual: str`
  - `class TocError(Exception)` — `str(exc)` 가 사유 한 줄.
  - `parse(text: str) -> Toc` — 꼴이 틀리면 `TocError`.
  - `load(plugin_root: Path) -> Toc` — `plugin_root/references/conducting.md` 를 읽고, 이름 붙은 파일마다 있는지 본다(없으면 `TocError("지시서가 없다: <경로>")`).
  - `resolve(plugin_root: Path, sd_path: str) -> Path` — `<SD>/references/<이름>.md` 만 받는다.
  - `named_files(toc: Toc) -> list` — 걸음 1 ~ 7 의 지시서 · extras 차례 · manual. 차례 파일 자신은 넣지 않는다.
  - `step_for(toc: Toc, stage: str) -> Step | None`
  - 명령줄: `python3 conductor_toc.py files [--plugin-root <P>] [--kind all|step|extra|manual]` → 절대경로 한 줄씩(`all` 은 차례 자신을 맨 앞에), 0. `python3 conductor_toc.py step --stage "<단계>" [--plugin-root <P>]` → `<번호>\t<이름>\t<절대경로>`, 0 · 없으면 `걸음 없음 — 차례 표에 이 단계가 없다`, 1. 꼴이 틀리면 `[spec-distill] 차례를 읽지 못했다 — <사유>`, 3. `--plugin-root` 의 기본값은 이 스크립트의 부모의 부모다.

차례의 꼴(Task 2 · 3 이 이 꼴로 쓴다):

```markdown
### 걸음 표

| 걸음 | 들어서는 때 | 지시서 | 함께 읽는 것 |
|---|---|---|---|
| 1 맞추기 | 부를 때마다 · … | `<SD>/references/conducting-step-1.md` | — |
| 3 다음 일 고르기와 보내기 | 단계: 준비 · 설계 중 · 일부 머지 | `<SD>/references/conducting-step-3.md` | … |

### 걸음에 달리지 않은 지시서

- <읽는 때> — `<SD>/references/conducting-resume.md`

## 손으로 따르는 절차

<한 문장> `<SD>/references/conducting-manual.md` <…>
```

- 걸음 표는 `### 걸음 표` 바로 아래 첫 표다. 머리 줄은 글자 그대로 `| 걸음 | 들어서는 때 | 지시서 | 함께 읽는 것 |`. 행은 일곱이고 첫 칸이 `<1~7> <이름>` 으로 1 부터 차례다. 지시서 칸은 `` `<SD>/references/[a-z0-9-]+\.md` `` 하나뿐이다.
- 들어서는 때 칸에 `단계:` 가 있으면 그 뒤에서 칸 끝까지를 ` · ` 로 나눈 것이 그 걸음의 단계 이름들이다. 같은 단계 이름이 두 걸음에 있으면 `TocError`.
- extras 는 `### 걸음에 달리지 않은 지시서` 아래 `- ` 줄마다 ` — ` 뒤의 백틱 경로 하나.
- manual 은 `## 손으로 따르는 절차` 절 안의 `<SD>/references/…md` 백틱 경로 하나(둘 이상이면 `TocError`).
- 이름 붙은 경로가 겹치면 `TocError`.

- [ ] **Step 1: 실패하는 테스트를 하나씩 쓴다** — `tests/test_conductor_toc.py`(unittest, 픽스처 글은 테스트 안 문자열):
  - `test_parse_reads_seven_steps` — 일곱 행 표 → `[s.number for s in toc.steps] == [1,2,3,4,5,6,7]`, `toc.steps[2].stages == ("준비", "설계 중", "일부 머지")`, `toc.steps[5].stages == ("머지됨", "끝남")`, `toc.steps[0].stages == ()`.
  - `test_step_for_exact_and_suffixed` — `step_for(toc, "설계 중").number == 3` · `step_for(toc, "일부 머지 1/2").number == 3` · `step_for(toc, "머지됨").number == 6` · `step_for(toc, "일부 머지됨") is None` · `step_for(toc, "대기") is None`.
  - `test_parse_rejects_missing_row` · `test_parse_rejects_duplicate_stage` · `test_parse_rejects_bad_path`(`references/x.md` 처럼 `<SD>/` 없는 경로) · `test_parse_rejects_two_manual_paths` — 각각 `TocError` 이고 사유에 걸음 번호나 경로가 든다.
  - `test_named_files_order` — steps 1~7 · extras · manual 차례.
  - `test_cli_files_and_step` — 임시 폴더에 `references/conducting.md` 와 이름 붙은 파일을 만들고 `--plugin-root` 로 부른다: `files` rc 0 · 첫 줄이 차례 · `step --stage 준비` 의 첫 칸 `3` · `step --stage 대기` rc 1 · 지시서 하나를 지우면 `files` rc 3 과 `지시서가 없다`.
- [ ] **Step 2: 돌려 실패를 본다** — Run: `python3 -m unittest plugins/spec-distill/tests/test_conductor_toc.py -v` · Expected: `ModuleNotFoundError: conductor_toc` 또는 케이스 실패.
- [ ] **Step 3: `scripts/conductor_toc.py` 를 위 Interfaces 대로 쓴다** — 표 줄은 `|` 로 나누고 칸 앞뒤 빈칸을 뗀다. 칸 안에 `|` 는 오지 않는다.
- [ ] **Step 4: 돌려 통과를 본다** — 같은 명령 · Expected: OK.
- [ ] **Step 5: 커밋** — `git commit -m "feat(spec-distill): 차례 걸음 표를 읽는 파서를 더한다" -- plugins/spec-distill/scripts/conductor_toc.py plugins/spec-distill/tests/test_conductor_toc.py`(트레일러 `Spec:`).

---

### Task 2: 글자 그대로 옮기기(옮기는 커밋)

설계 §1.9 의 옮기는 커밋이다 — 글은 한 글자도 고치지 않고, 락은 대상 경로만 바꾼다. AC4(옮긴 커밋에서 글자로 같다) · AC8(걸음 번호에 묶인 락 넷 · 서로를 절 제목으로 가리키는 문장의 락 · 세션 꼬리 펜스 락이 새 자리에서 같은 것을 지키고, 단언 수가 줄지 않는다).

**Files:**
- Create: `references/conducting-step-1.md` ~ `conducting-step-7.md` · `references/conducting-resume.md` · `references/conducting-team.md` · `references/conducting-manual.md` · `tests/conducting_corpus.sh`
- Modify: `references/conducting.md` · Task 0 의 테스트 23개 가운데 지휘 절차서를 여는 것 · `shared/tests/fixtures/ask-sites.tsv` · `tests/test_repo_literals.sh`(`TARGETS`) · `tests/test_plain_gate_templates.sh`(`# guards:` 줄 · `--emit-scanned` 목록)

**Interfaces:**
- Consumes: Task 1 의 `conductor_toc.py files --kind …`.
- Produces: `tests/conducting_corpus.sh`(셸 테스트가 `. "$ROOT/plugins/spec-distill/tests/conducting_corpus.sh"` 로 읽는다) —
  - `cd_files [all|step|extra|manual]` — `conductor_toc.py files --kind` 의 출력. rc ≠ 0 이거나 비었으면 `no "차례를 읽지 못했다 — <출력>"` 를 내고 1.
  - `cd_all` — `cd_files all` 의 파일을 차례대로 이어 붙인 글(부재 확인의 코퍼스).
  - `cd_loop` — 차례의 `## 지휘 순환` 절 + 걸음 지시서 일곱 + `conducting-resume.md`(옛 `## 지휘 순환` 절과 같은 제목들을 담는다 — `### N.` · `### /compact 시점` · `### 알림`).
  - `cd_manual_file` · `cd_team_file` · `cd_resume_file` — 그 파일의 절대경로(`cd_files manual` · `extra` 에서 이름으로 고른다).
  - 파이썬 테스트는 `sys.path` 에 `scripts` 를 넣고 `conductor_toc.load` · `named_files` · `resolve` 로 같은 파일을 읽는다.

새 파일의 글(옛 `references/conducting.md` 의 줄 번호 — Task 0 의 HEAD 기준):
- `conducting-step-N.md` = 옛 `### N.` 머리 줄부터 다음 `### ` 앞까지(걸음 7 은 `### /compact 시점` 앞까지).
- `conducting-resume.md` = `### /compact 시점` 머리 줄부터 `### 알림` 앞까지.
- `conducting-team.md` = `## team 형식 로드맵` 머리 줄부터 `## 손으로 따르는 절차` 앞까지.
- `conducting-manual.md` = `## 손으로 따르는 절차` 머리 줄부터 파일 끝까지.
- 각 파일의 끝은 줄바꿈 하나다(절 사이의 빈 줄은 뗀다).
- 남는 `conducting.md` = 옛 1행부터 `### 1.` 앞까지 + 아래 새 글 + 옛 `### 알림` 절 + `## 손으로 따르는 절차` 와 가리킴 한 줄. 새 글은 `### 걸음 표`(Task 1 꼴 — 들어서는 때 칸은 위 「계획이 정한 것」 의 단계 → 걸음과, 1 「부를 때마다」 · 2 「사용자를 기다리는 질문이 있을 때」 · 6 「에픽 PR 이 머지된 뒤 그 에픽의 줄(작업 · 자원 · 살아 있는 agent)이 기계 상태에 남아 있는 동안 — 단계: 머지됨 · 끝남」(`단계:` 를 칸 끝에 둔다) · 7 「끝나지 않은 에픽이 없을 때」 · 함께 읽는 것 칸은 `—`)와 `### 걸음에 달리지 않은 지시서`(끊고 잇기 · team 형식 두 줄 — 읽는 때는 「계획이 정한 것」 의 글과 「로드맵 머리말이 `layout: team` 일 때만」)다. 끝 절 가리킴: `손으로 따르는 절차는 `<SD>/references/conducting-manual.md` 에 있다 — 지휘자를 부르지 않고 진행할 때의 것이고, 지휘자 skill 안에서는 따르지 않는다.`

- [ ] **Step 1: 새 파일을 옛 글에서 잘라 만든다** — `$TMPDIR` 의 일회용 스크립트로 자른다(커밋하지 않는다). 손으로 옮겨 적지 않는다.
- [ ] **Step 2: 글자 대조를 돌린다** — `$TMPDIR` 스크립트가 `git show HEAD:plugins/spec-distill/references/conducting.md` 에서 같은 범위를 다시 잘라 새 파일과 바이트로 견준다(끝 줄바꿈 하나 규칙만 맞춘 뒤). Expected: 파일 열 개 모두 같음. 결과 줄을 커밋 본문에 싣는다(AC4 의 「옮긴 커밋에서 글자로 같다」 근거).
- [ ] **Step 3: `conducting.md` 를 차례 꼴로 줄이고 `conductor_toc.py files` 를 돌린다** — Expected: rc 0 · 11줄(차례 + 열).
- [ ] **Step 4: `tests/conducting_corpus.sh` 를 쓰고 테스트의 대상 경로를 옮긴다.** 규칙:
  - 옛 `## 지휘 순환` 절을 awk 로 뽑던 자리(`test_conducting_loop.sh:9` · `test_parallel_recommend_docs.sh:17` · `test_qg_review_reference.sh:704` · `test_conducting_reference.sh:326` 의 `cyc_head`)는 `cd_loop` 에서 같은 awk 로 뽑는다.
  - 손 절차 절을 뽑던 자리(`test_conducting_reference.sh:16-19` · `test_conducting_loop.sh:182` · `test_parallel_recommend_docs.sh:19` · `test_qg_review_reference.sh:705` · `test_superpowers_presence.sh:89`)는 `cd_manual_file` 을 그 파일로 준다.
  - team 절을 뽑던 자리(`test_qg_review_reference.sh:763` · `test_walk_docs.py:87` · `test_human_lines.py:37`)는 team 지시서를 준다.
  - `### /compact 시점` 을 `LOOP` 에서 뽑던 자리(`test_conducting_loop.sh:133`)는 `cd_loop` 그대로 둔다(그 제목을 담는다).
  - 파일 전체를 읽는 부재 · 존재 확인(`cat "$CD"` · `$WHOLE` · `$CDALL` · `unsectioned` · `pr_by_hand` · `epic_pr_by_hand` · `test_epic_conductor_skill.sh:64,225,226` · `test_plain_gate_templates.sh:143-144` · `test_conductor_dispatch_reference.sh:139` 의 `disallowedTools` · `test_entry_guidance.sh:38` · `test_review_handoff_order.sh:265`)는 `cd_all` 로 바꾼다. 「정확히 한 번」 을 세는 것은 차례 끝 절과 손 절차 파일의 머리가 겹치지 않는지 본 뒤 옮긴다.
  - 「끝 절은 손 절차다」(`test_conducting_loop.sh:11`) · 「손 절차 절 머리가 정확히 하나」(`test_conducting_reference.sh:16`) · `test_walk_docs.py:121-123` 의 절 차례는 차례 파일과 손 절차 파일 각각에 그대로 선다 — 대상 파일만 바꾼다.
  - `test_conductor_state_branch_docs.py:32` 의 `LOOP` 는 `named_files` 로 이은 글을 읽는다.
  - 표 밖 문서의 문장 락(`test_decompose_surface.sh:206` · `test_conducting_reference.sh:422-423` · `test_qg_review_reference.sh:288`)은 이 커밋에서 바꾸지 않는다 — 그 문서들은 Task 5 에서 고친다.
- [ ] **Step 5: 공유 락의 대상을 넓힌다** — `ask-sites.tsv` 의 지휘 절차서 22행은 앵커가 든 새 파일 경로로 바꾼다(앵커 글자는 그대로 · 행 수 22 그대로). `test_repo_literals.sh` `TARGETS` 와 `test_plain_gate_templates.sh` 의 `# guards:` · `--emit-scanned` 목록에 새 파일 열을 더한다.
- [ ] **Step 6: 옮긴 락을 돌려 견준다** — Task 0 의 목록 전부와 `shared/tests/test_ask_recommendation.sh` · `shared/tests/test_skill_reference_pointers.sh` 를 돌린다. Expected: Task 0 에서 통과한 것은 모두 통과 · 단언 수는 Task 0 의 수 이상. 하나라도 줄면 커밋하지 않고 줄어든 테스트를 고친다.
- [ ] **Step 7: 옮긴 확인이 아직 무는지 한 번 본다**(`docs/testing.md` 「옮기거나 합치기만 했을 때」) — `$TMPDIR` 의 사본에서 `conducting-step-3.md` 의 「`AskUserQuestion` 으로 승인받는다」 를 지우고 `test_conducting_loop.sh` 를 사본 루트로 돌려 RED 를 본다. `conducting-manual.md` 의 걸음 `9. ` 머리를 지우고 `test_conducting_reference.sh` 가 RED 인지 본다. 사본은 그 뒤 지운다(자기가 만든 폴더만).
- [ ] **Step 8: 커밋** — `refactor(spec-distill): 지휘 절차서를 차례와 걸음 지시서로 글자 그대로 옮긴다`. 본문에 Step 2 의 대조 결과와 「단언 수 <앞> → <뒤>」 를 싣는다. pathspec 은 Step 1 ~ 5 가 고친 파일 전부다.

---

### Task 3: 차례 쓰기

설계 §1.2 · AC2 · AC7 · AC37.

**Files:**
- Modify: `references/conducting.md`
- Create: `shared/tests/test_conducting_lock_targets.sh`
- Modify: `tests/test_repo_literals.sh`(`--emit-scanned` 모드를 더한다) · `tests/test_conducting_loop.sh`(차례 단언)

**Interfaces:**
- Consumes: Task 1 의 `conductor_toc.py files` · Task 2 의 차례 꼴.
- Produces: 차례의 새 글. 뒤 과제(4 · 8)는 차례의 걸음 표 칸 이름과 「걸음에 달리지 않은 지시서」 제목을 바꾸지 않는다.

차례에 더할 것(`## 지휘 순환` 절, 걸음 표 앞):
- 머리 문단의 「걸음 1 부터 차례로 돈다」 를 「걸음 표의 차례로 돈다 — 걸음마다 그 걸음의 지시서를 읽는다」 로.
- 「리더」 한 줄: `리더는 로드맵을 이끄는 세션이다 — team 형식 설계 걸음의 leader 역할이 그 세션이다.`
- 지킬 순서 한 줄(AC37, 설계 §1.2 글 그대로): `지킬 순서 — 덜 읽는 것과 제대로 아는 것이 부딪히면 제대로 아는 것이 이긴다. 계획 검수는 계획을 통째로 읽고, 설계 대화에서는 묶음과 원문을 다시 읽고, 다른 에픽으로 넘기는 판단은 원문을 읽고 한다.`
- 읽는 규칙 한 문단(설계 §1.2): 걸음에 들어설 때 그 걸음의 지시서를 읽는다 · 이 대화에서 이미 읽은 지시서는 다시 읽지 않는다 · 압축이나 비우기 뒤에는 읽은 것으로 치지 않는다 · 차례가 이름 붙이는 파일은 지금 있는 것 전부다.
- 걸음 표의 함께 읽는 것 칸: 3 `` `<SD>/references/conductor-dispatch.md`(이 대화에서 담당자를 처음 보낼 때) · `<SD>/skills/epic-conductor/references/qg-review.md`(spec 승인 앞) `` · 4 `` `<SD>/references/conductor-dispatch.md`(돌아온 사람 자리를 옮길 때) `` · 5 `` `<SD>/skills/epic-conductor/references/qg-review.md`(머지 앞) `` · 1 `` `<SD>/references/conductor-state-branch.md`(맞추기 명령이 상태 브랜치 구간에 이상을 냈을 때 · 온 글이 있을 때) `` · 2 `` `<SD>/references/conductor-state-branch.md`(기다리는 질문을 걸 때) `` · 5 에 더해 `` `<SD>/references/conductor-state-branch.md`(안 올린 규칙 고침을 올릴 때) `` · 7 `` `<SD>/skills/epic-conductor/references/qg-review.md`(로드맵 끝) · `<SD>/references/conductor-state-branch.md`(상태 브랜치를 지울 때) `` · 나머지는 `—`. 설계 §1.5 의 때 밖의 읽기는 적지 않는다(§1.5 표는 2026-11-25 에 걸음 2 · 5 · 7 을 더했다 — 사용자 「셋을 더한다」).
- 머리 불릿 「하위에게 보내는 글은 같은 폴더 `conductor-dispatch.md` 의 틀이다」 뒤에 「— 읽는 때는 걸음 표의 함께 읽는 것 칸이다」 를 붙인다.

- [ ] **Step 1: AC2 · AC37 테스트를 쓴다** — `tests/test_conducting_loop.sh` 끝에 더한다:
  - `conductor_toc.py files` rc 0 이고 걸음 표 첫 칸이 `1 맞추기` · `2 사람 몫 모으기` · `3 다음 일 고르기와 보내기` · `4 돌아오기` · `5 머지 전 확인` · `6 머지 뒤` · `7 끝`(글자 그대로 일곱, 차례대로).
  - 끝 절 제목이 `## 손으로 따르는 절차` 이고 그 절에 `conducting-manual.md` 가 한 번.
  - 지킬 순서: 차례에 `제대로 아는 것이 이긴다` 한 번 · `계획 검수` · `설계 대화` · `다른 에픽으로 넘기는` 각 한 번 이상.
  - 「리더」 한 줄: 차례에 `리더는 로드맵을 이끄는 세션이다` 한 번.
- [ ] **Step 2: 돌려 실패를 본다**(지킬 순서 · 리더 줄이 아직 없다).
- [ ] **Step 3: AC7 테스트를 쓴다** — `shared/tests/test_conducting_lock_targets.sh`(`# guards: plugins/spec-distill/references/*.md shared/tests/test_skill_reference_pointers.sh shared/tests/test_ask_recommendation.sh plugins/spec-distill/tests/test_repo_literals.sh plugins/spec-distill/tests/test_plain_gate_templates.sh`):
  - `F` = `conductor_toc.py files --kind all` 의 레포 상대경로(비면 `no` 하고 끝).
  - 락마다 대상 목록을 얻는다 — 질문 자리 · 쉬운 말 · 레포 전용 값은 `bash <락> --emit-scanned`(레포 전용 값은 이 과제에서 `--emit-scanned` 를 더한다 — `TARGETS` 를 `plugins/spec-distill/` 를 붙여 한 줄씩 내고 0), 가리킴은 그 락 머리의 `# guards:` 글롭으로 `git ls-files` 한 것.
  - `F` 의 파일마다 넷 모두에 있으면 `ok`, 빠지면 `no "<파일> 이 <락> 의 대상에 없다"`.
  - 변이 대조: `$TMPDIR` 사본에서 `test_plain_gate_templates.sh` 의 목록에서 `conducting-step-4.md` 를 빼고 이 테스트를 사본 루트로 돌려 그 줄이 RED 인지 본다(양성 대조로 원본에서는 GREEN).
  - `chmod +x` 하고 100755 를 확인한다.
- [ ] **Step 4: 돌려 결과를 본다** — Expected: 레포 전용 값 락에 `--emit-scanned` 가 없어 실패 → 더한 뒤 통과.
- [ ] **Step 5: 차례 글을 위대로 쓰고 Step 1 · 3 의 테스트와 Task 2 의 옮긴 락을 다시 돈다** — Expected: 모두 통과.
- [ ] **Step 6: 커밋** — `docs(spec-distill): 차례에 걸음 표 칸 · 지킬 순서 · 읽는 규칙을 쓴다`(pathspec: 차례 · 새 테스트 · 고친 테스트 둘).

---

### Task 4: 걸음 지시서 고치기

설계 §1.3 · §1.5 · §1.8 · AC3 · AC6 · AC9.

**Files:**
- Modify: `references/conducting-step-1.md` ~ `-7.md` · `references/conducting.md`(필요하면 함께 읽는 것 칸)
- Test: `tests/test_conducting_loop.sh` · `tests/test_walk_docs.py`(`POINTER`) · `tests/test_conductor_state_branch_docs.py` · `tests/test_conductor_ledger.py`(AC9)

**Interfaces:**
- Produces: 지시서 꼴 — 첫 줄 `### <N>. <이름>`, 그 바로 아래 `- 읽을 것: …` · `- 남기는 것: …`, 그 뒤 지금의 다섯 칸(`- 기본값:` · `- 판단:` · `- 부를 skill:` · `- 기록:` · `- 기계 상태:`). Task 8 이 걸음 1 지시서의 `- 기본값:` 을 고친다.

고칠 것:
- 머리 두 줄(설계 §1.3): 읽을 것 = 이 걸음에서 함께 읽는 파일과 그 조건(차례의 함께 읽는 것 칸과 같은 때 — 설계 §1.5) · 남기는 것 = 이 걸음이 쓰는 기록 · 파일의 자리(설계문서 `## 지휘 기록` · 기계 상태의 절 · 옮김 폴더 파일 — 지금 「기록」 · 「기계 상태」 칸이 말하는 자리를 모은 것).
- 다른 걸음 · 다른 절을 가리키는 말에 파일을 붙인다 — 「걸음 3 의 「차례로」 확인」 → 「`<SD>/references/conducting-step-3.md` 의 「차례로」 확인」 꼴. 대상: `걸음 N 의` · `N 의 「` · `아래 맞추기 순서`(걸음 1 안이면 그대로) · `위 머리의 번호 적기 불릿`(→ 차례) · `손 절차 1`(→ `conducting-manual.md` 의 1) · `` 아래 `## team 형식 로드맵` 절 ``(→ `` `<SD>/references/conducting-team.md` ``) · `` `/compact 시점` ``(→ `` `<SD>/references/conducting-resume.md` ``). 찾는 법은 Step 1 의 grep 이다.
- 걸음끼리 함께 쓰는 문단은 한 지시서에만 둔다 — 걸음 1 과 걸음 4 의 「병렬 권장 수 …」 · 「구현 담당자를 보낼 때는 먼저 …」 문장이 겹치면 걸음 1 에 두고 걸음 4 는 가리킨다.
- 읽는 때(설계 §1.5): 보내는 글 틀은 걸음 3(이 대화에서 처음 보낼 때) · 걸음 4(돌아온 사람 자리를 옮길 때)에서만, 상태 브랜치 절차는 걸음 1(상태 브랜치 구간에 이상 · 온 글) · 걸음 2(기다리는 질문을 걸 때) · 걸음 5(안 올린 규칙 고침을 올릴 때) · 걸음 7(상태 브랜치를 지울 때)과 글을 보낼 때에서만 읽으라고 적는다 — 걸음 2 · 5 · 7 의 읽을 것 줄에 그 파일과 때를 올린다(설계 §1.5 표, 2026-11-25 사용자 「셋을 더한다」). 품질 게이트 절차의 「읽고 그 자리의 줄을 따른다」 문장은 그대로다. 걸음 5 처럼 담당자를 보내는 다른 걸음에 보내는 글 틀을 읽으라는 문장이 지금 있으면 Step 1 목록에 적고, 설계 §1.5 와 어긋나면 고치지 말고 멈춰 보고한다.
- 쌓는 줄의 꼴(설계 §1.8): 걸음 3 의 병렬 답 보기 `병렬 답 · <YYYY-MM-DD HH:MM> · 「<고른 선택지>」 …` 를 `- 병렬 답 · <YYYY-MM-DD> · 「<고른 선택지>」 · 준비 에픽 <…>` 꼴로 — 날짜 칸에 시각을 붙이지 않는다. 「가장 최근(줄의 시각)」 은 「가장 아래 줄(줄은 쌓기만 하고 고치지 않는다)」 로. 쌓인 기록 줄의 보기도 같은 꼴로.

- [ ] **Step 1: 가리키는 말의 전수를 뽑는다** — Run: `grep -n -E '걸음 [1-7] 의|[1-7] 의 「|아래 맞추기 순서|위 머리|손 절차 [1-9]|## team 형식 로드맵|/compact 시점' plugins/spec-distill/references/conducting-step-*.md` · 결과를 `$TMPDIR/plan1-pointers.txt` 에 두고 줄마다 고칠지(다른 파일) · 둘지(같은 파일 안)를 적는다.
- [ ] **Step 2: AC3 · AC6 · 겹침 테스트를 쓴다** — `tests/test_conducting_loop.sh`:
  - 지시서마다 첫 줄이 `### <N>. ` 이고 `- 읽을 것:` · `- 남기는 것:` · 다섯 칸이 각 정확히 하나, 읽을 것 · 남기는 것이 `- 기본값:` 보다 앞(AC3).
  - 걸음 1 · 2 · 5 · 6 · 7 지시서와 차례의 걸음 표 밖에 `conductor-dispatch.md` 가 「읽」 과 같은 문장에 없다 · 걸음 3 · 4 의 읽을 것 줄에 있다(AC6 의 보내는 글 틀). 상태 브랜치 절차는 걸음 1 · 2 · 5 · 7 의 읽을 것 줄에 있고, 걸음 3 · 4 · 6 지시서에는 `conductor-state-branch.md` 가 「읽」 과 같은 문장에 없다(AC6 의 상태 브랜치 절차).
  - 겹침: 지시서 둘에 같은 문장(마침표로 끝나는 80자 이상)이 없다. 짝: `$TMPDIR` 사본에서 걸음 1 의 한 문장을 걸음 5 에 붙이면 RED.
- [ ] **Step 3: AC9 테스트를 쓴다** — `tests/test_conductor_ledger.py` 에 `test_guide_example_lines_are_accepted`: 걸음 3 지시서에서 병렬 답 보기 줄과 쌓인 기록 줄 보기를 정규식으로 꺼내 꺾쇠 자리를 아는 값(날짜 `2026-11-25` · 선택지 `병렬 (권장)` · 에픽 `E4`)으로 채운 뒤, 옛 형식 설계문서 픽스처에 `record --spec <픽스처> --line <줄>` 과 team 형식 과제 파일 픽스처에 같은 명령을 주고 둘 다 rc 0 · 결정 기록에 그 줄이 있음을 본다. 쌓인 기록은 `add --section "쌓인 기록"` 뒤 `flush` 가 rc 0 이고 설계문서에 그 줄이 옮겨졌음을 본다. 같은 파일의 기존 픽스처 준비를 쓴다(케이스마다 레포를 새로 세우지 않는다).
- [ ] **Step 4: 돌려 실패를 본다** — Expected: 머리 두 줄 없음 · 병렬 답 보기에 시각이 있어 team 형식 `record` 가 rc 2.
- [ ] **Step 5: 지시서를 고친다** — Step 1 의 목록 줄마다. 옮긴 글의 낱말(「지휘자」 등)은 고치지 않는다.
- [ ] **Step 6: 옛 글을 박은 단언을 새 글로 맞춘다** — `test_walk_docs.py` 의 `POINTER` 를 새 가리킴 글로, 걸음 1 · 4 에서 옮긴 문장의 「정확히 한 번」 단언은 옮긴 쪽 걸음으로. 단언을 지우지 않는다(지워야 하면 멈추고 보고한다 — `docs/testing.md` 「지우기 · 합치기 · 줄이기」 는 사용자 승인이 든다).
- [ ] **Step 7: 돌려 통과를 본다** — Task 0 목록 전부 + `test_conducting_lock_targets.sh` · Expected: 통과 · 단언 수는 Task 2 뒤 수 이상.
- [ ] **Step 8: 커밋** — `docs(spec-distill): 걸음 지시서에 읽을 것 · 남기는 것과 파일 가리킴을 단다`.

---

### Task 5: 손 절차 · team 절을 가리키는 문서

설계 §1.6 · AC4.

**Files:**
- Modify: `skills/epic-conductor/SKILL.md:44`(꺼짐 행) · `references/redecompose.md:125` · `references/epic-handoff.md:3` · `skills/epic-conductor/references/qg-review.md:7,261` · `README.md:174` · `scripts/conductor_state.py:66`(주석)
- Test: `tests/test_decompose_surface.sh:206` · `tests/test_conducting_reference.sh:422-423` · `tests/test_qg_review_reference.sh:288,688` · `tests/test_epic_conductor_skill.sh:55-56` · `tests/test_entry_guidance.sh`

고칠 것:
- SKILL 꺼짐 행: 「이 플러그인 references 폴더의 지휘 절차 파일(conducting.md) 끝 절인 손으로 따르는 절차」 → 「이 플러그인 references 폴더의 손 절차 파일(`conducting-manual.md`)」. 「멈춘다」 는 그대로.
- `redecompose.md:125`: `` `${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 의 손 절차 6 `` → `` `${CLAUDE_PLUGIN_ROOT}/references/conducting-manual.md` 의 6 ``. 같은 줄의 「같은 파일 걸음 5」 가 지휘 순환 걸음 5 면 `` `${CLAUDE_PLUGIN_ROOT}/references/conducting-step-5.md` `` 로, 손 절차 걸음 5 면 손 절차 파일로 — 읽고 정해 커밋 본문에 적는다.
- `epic-handoff.md:3`: 「손 절차로 갈 때」 에 `` `<SD>/references/conducting-manual.md` `` 를 붙인다(이 파일에서 고치는 것은 이 문장 하나 — 설계 Files to Modify).
- `qg-review.md:7`: 「`conducting.md` 지휘 순환의 걸음이다 — 손으로 따르는 절차로 들어왔으면」 → 「`conducting.md` 차례의 걸음이다 — 손 절차(`conducting-manual.md`)로 들어왔으면」. 번호 대응(4 = 5 · 5 = 8 · 7 = 9 · 1 · 2 · 3 · 6 같음)은 그대로. `:261` 의 「`conducting.md` 의 `## team 형식 로드맵`」 → 「`conducting-team.md`」.
- `README.md:174`: 그 항목을 차례 · 걸음 지시서 일곱 · 끊고 잇기 · team 형식 · 손 절차 파일로 고쳐 쓴다(끄는 변수 경고는 그대로).
- `conductor_state.py:66` 주석의 「conducting.md 걸음 1」 → 「conducting-step-1.md」.
- 로드맵 틀(`templates/roadmap-template.md:15`)과 커밋된 로드맵은 고치지 않는다 — 차례 끝 절이 「`references/conducting.md` 끝 절 「손으로 따르는 절차」」 를 그대로 맞게 한다(설계 §1.2).

- [ ] **Step 1: 실패하는 단언으로 바꾼다** — 각 테스트의 옛 문장 단언을 새 문장으로(`test_decompose_surface.sh:206` 은 `conducting-manual.md` 의 6, `test_qg_review_reference.sh:288` 의 `L_stepmap` 은 새 문장 전체, `:688` 은 `conducting-team.md`). 더하여 `tests/test_entry_guidance.sh` 에: 로드맵 틀의 안내 줄이 가리키는 「`references/conducting.md` 끝 절 「손으로 따르는 절차」」 가 맞다 — 차례의 마지막 `## ` 이 `## 손으로 따르는 절차` 이고 그 절에 `conducting-manual.md` 가 있다.
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 문서를 고친다.**
- [ ] **Step 4: 돌려 통과를 본다** — 고친 테스트 + `shared/tests/test_skill_reference_pointers.sh` + `test_conducting_lock_targets.sh`.
- [ ] **Step 5: 커밋** — `docs(spec-distill): 손 절차와 team 절을 가리키는 문서가 새 파일을 가리킨다`.

---

### Task 6: team 형식 지시서

설계 §1.7 · AC5.

**Files:**
- Modify: `references/conducting-team.md` · 걸음 지시서의 team 가리킴 줄(Task 4 에서 고친 것 — 조건 글 확인만)
- Test: `tests/test_walk_docs.py`

더할 것(설계 §1.7 의 셋):
1. 결과 대조 · 받음 줄 걸음과, 다음 걸음이 「검수 — 누가 leader」 일 때의 검수 묶음 보내기.
2. 걸음 5 「승인 기록 다시 보이기」 의 team 전용 문장(표시 없는 `confirm` 이 내는 목록 · `confirm --confirmed`)을 가리키는 줄 — `` `<SD>/references/conducting-step-5.md` 의 「승인 기록 다시 보이기」 ``.
3. 한 문장, 글자 그대로: `작업 방식과 도구는 걸음 보기(`walk_table.py next`)가 낸 칸을 쓴다 — 걸음 지시서의 부를 skill 칸은 옛 형식의 값이다.`

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `test_walk_docs.py` 의 `ConductingTeam` 에: team 지시서에 `받음 줄` · `검수 묶음` · `confirm --confirmed` · `부를 skill 칸은 옛 형식의 값` 이 각 한 번 이상(1 ~ 3). 차례와 걸음 지시서에서 `conducting-team.md` 가 나오는 줄마다 `team 형식` 또는 `layout: team` 이 같은 줄에 있다(AC5 — 옛 형식 로드맵에서는 읽으라고 하지 않는다). 짝: 그 조건 글이 없는 줄을 사본에 넣으면 RED.
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: team 지시서에 셋을 더한다** — 1 은 지금 절의 「결과 대조」 · 「받음 줄」 글이 이미 있으면 그 자리를 가리키는 한 줄로 둔다(복제하지 않는다).
- [ ] **Step 4: 돌려 통과를 본다** — `test_walk_docs.py` · `test_human_lines.py` · `test_qg_review_reference.sh`.
- [ ] **Step 5: 커밋** — `docs(spec-distill): team 형식 지시서에 넘겨받은 셋을 싣는다`.

---

### Task 7: 원장 명령의 세션 번호

설계 §2 「세션 번호」 · AC12(원장 쪽).

**Files:**
- Modify: `scripts/conductor_ledger.py`(`_rs` 와 그것을 쓰는 명령)
- Test: `tests/test_conductor_ledger.py`

**Interfaces:**
- Produces: `--session` 을 받던 원장 명령(`claim` · `takeover` · `release` · `add` · `drop` · `cleanup` · `flush` · `pr-refresh` · `pr-record`)은 `--session` 이 없으면 `state_path.resolve_session_id(None)` 의 값을 쓴다. 그 값이 없으면 `Fail(3, "세션 번호를 얻지 못했다 — --session 을 주거나 Claude Code 세션 안에서 부른다. 기계 상태를 쓰지 않았다")`. `--session` 을 주면 지금과 같다. Task 8 이 같은 해결을 쓴다 — 공용 함수 `session_or_fail(given: str | None) -> str` 를 `conductor_ledger.py` 에 둔다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**
  - `test_session_defaults_to_env` — `DEVBREW_SPEC_DISTILL_SESSION_ID=session-plan1-a` 로 `claim --roadmap <픽스처>`(세션 없이) → rc 0 · 표지 파일 내용이 `session-plan1-a\n`.
  - `test_missing_session_writes_nothing` — 두 환경 변수를 다 지운 채 `claim` → rc 3 · 출력에 `세션 번호를 얻지 못했다` · 표지 파일과 기계 상태 파일이 없다(있었으면 바이트가 그대로).
  - `test_explicit_session_wins` — 환경 변수와 다른 `--session` 을 주면 그 값이 표지에 적힌다.
- [ ] **Step 2: 돌려 실패를 본다** — Expected: argparse 의 `--session` 필수 오류(rc 2).
- [ ] **Step 3: `_rs` 의 `--session` 을 `default=None` 으로 바꾸고 명령마다 `a.session = session_or_fail(a.session)` 을 앞에 둔다.**
- [ ] **Step 4: 돌려 통과를 본다** — `test_conductor_ledger.py` 전체 + `tests/test_ledger_wiring.sh`.
- [ ] **Step 5: 커밋** — `feat(spec-distill): 원장 명령이 세션 번호를 스스로 읽는다`.

---

### Task 8: 맞추기 명령

설계 §2 · AC10 · AC11 · AC12(맞추기 쪽).

**Files:**
- Create: `scripts/conductor_sync.py` · `tests/test_conductor_sync.py`
- Modify: `references/conducting-step-1.md`(`- 기본값:`) · `scripts/control_plane.py`(필요할 때만 — 아래)
- Test: `tests/test_conductor_sync.py` · 걸음 1 문장 락(`test_conducting_loop.sh` 의 `once 1 …` · `test_conductor_state_branch_docs.py` 의 걸음 1 낱말 · `test_epic_conductor_skill.sh:226`)

**Interfaces:**
- Consumes: Task 1 `conductor_toc.load` · `step_for` · Task 7 `conductor_ledger.session_or_fail` · `control_plane.gather`(작업 목록과 규모 줄을 한 번의 계산으로 — 같은 블록을 `tasks_output` 이 읽는 그대로 쓴다) · `roadmap_status.DONE` · `conductor_state.WORK_DONE` · 기계 상태 읽기(`control_plane.machine_for` 처럼 지금 읽는 길 — 걸음 6 조건의 세 절).
- Produces: 명령줄 `python3 conductor_sync.py --roadmap <로드맵> [--session <세션>] [--takeover]`. 종료 코드: 0 · 멈춤이면 그 구간의 종료 코드. 출력은 아래 꼴뿐이다.

출력의 꼴:
- 구간마다 `<구간> — <한 줄>`. 이상이면 `<구간> — 이상: <한 줄>` 뒤에 그 구간 원문을 줄마다 네 칸 들여 낸다.
- 멈춤이면 `멈춤 — <구간>: <사유 한 줄>` 과 원문(들여 쓴)을 내고 그 종료 코드로 끝난다. 뒤 구간은 돌지 않는다.
- 정보 줄은 `<무엇> <n>개 — 다시 보기: <명령>`.
- 끝 묶음: `규모 — <지금 SKILL 4 의 꼴>` → (team 형식이면) `리더 묶음 — 이 대화에서 처음이면 돌린다: python3 "<SD>"/scripts/start_bundle.py --roadmap <로드맵> --role leader` → `끝나지 않은 일:` 과 일마다 `- <작업 목록의 제목> → 걸음 <N> <이름> · <지시서 절대경로>`(못 찾으면 `→ 걸음 없음 — 차례 표에 이 단계가 없다`) → (있으면) `머지 뒤 일이 남은 에픽:` 과 에픽마다 `- <작업 목록의 제목> → 걸음 6 머지 뒤 · <지시서 절대경로> · 남은 줄: 작업 <a> · 자원 <b> · 살아 있는 agent <c>`(「계획이 정한 것」 의 걸음 6 조건 — 그 에픽의 단계로 `step_for` 가 6 을 낸다) → 작업 목록의 탭 없는 끝 줄(`동시에 갈 수 있는 준비 에픽: …`)이 있으면 그대로 → 마지막 줄 `맞추기 — <YYYY-MM-DD HH:MM> 기준`(시각 줄은 이 하나다).
- 일에 달리지 않은 걸음(1 · 2 · 7)은 일마다 내지 않는다. 단계가 끝인 에픽은 `끝나지 않은 일:` 에 넣지 않고, 걸음 6 조건에 맞을 때만 `머지 뒤 일이 남은 에픽:` 에 넣는다. 기계 상태 `## 작업` 의 로드맵 밖 줄도 그 단계 칸 글로 같은 찾기를 한다.

구간(차례대로 — 설계 §2):

| 구간 | 부르는 것 | 이상 없음 한 줄 | 이상(원문을 낸다) | 멈춤 |
|---|---|---|---|---|
| 자리 | `git rev-parse --show-toplevel` · `git worktree list --porcelain` 첫 줄 | `자리 — 메인 체크아웃` | 다르면 `자리 — worktree 안에서 시작했다(<경로>) — 여기서도 지휘한다` | 없음 |
| 원격 받기 | `git fetch origin` | `원격 받기 — 됨` | rc ≠ 0 | 없음 |
| 작업 목록 | `control_plane.gather` + `tasks_output` | `작업 목록 — 에픽 <n> · 끝나지 않은 일 <m>` | rc 3(검사 불가 사유) · rc 4(로드맵이 아직 기본 브랜치에 없다 — 손 절차 1 의 대신 계산을 쓴다) | 없음 |
| 표지 | `session_or_fail` → `ledger claim`(또는 `--takeover` 면 `ledger takeover`) | `표지 — 새로 잡았다` · `표지 — 이 세션이 쥐고 있다` · `표지 — 넘겨받았다(이전 주인 <x>)` | — | 세션 번호 없음 3 · 다른 세션이 쥠 5 · 기계 상태 읽기 불가 3(옛 PR 캐시 줄이면 원문에 `--reset` 명령이 실린다) · 그 밖 그 rc |
| 기본 브랜치 | `repo_defaults.py default-branch --check-remote` | `기본 브랜치 — <이름>` | rc 0 의 「대조하지 못했다」 | rc ≠ 0 — 표지를 풀고(`ledger release`) 그 rc |
| PR 캐시 | `ledger pr-refresh` | `PR 캐시 — 달라진 것 없음` | 고침 알림 · 「맞지 않는다」 경고 | rc 3 |
| 상태 브랜치 | `conductor_branch.py ensure` → `conductor_status.py sync` → `conductor_status.py show` | `상태 브랜치 — 기다리는 질문 0 · 온 글 0` 과 정보 줄 `다른 로드맵과 닿는 것 <n>개 — 다시 보기: python3 "<SD>"/scripts/conductor_status.py show --roadmap <로드맵>` | 아는 「이상 없음」 꼴이 아닌 줄 전부(기다리는 질문 · 온 글 · 검사 불가 · 남의 고침 · 판 번호 · 안 올린 규칙 고침 ≠ 0 …) — 모르는 줄도 이상이다 | rc 3 · rc 5 |
| 세션 담당자 | `hc ls --json --all`(hc 와 `$HC_TERMINAL_ID` 가 있을 때) 대 기계 상태 `## 살아 있는 agent` | `세션 담당자 — 표 <n> · 내 자식 <k> · 어긋남 0` 또는 `세션 담당자 — hc 없음 — 표의 줄 <n> 은 하니스 agent 목록과 견줄 줄` | `견줄 줄: <이름> · <에픽> · <일>`(표에 있고 내 자식이 아님) · `표에 없는 내 자식: <주소> <이름> <상태>` | 없음 — 줄을 지우거나 터미널을 닫지 않는다 |
| 스위트 잠금 | `ledger suite-lock` | `스위트 잠금 — <둘째 줄>` | rc ≠ 0 | 없음 |
| 실행 원장 | `ledger progress` | `실행 원장 — 없음` · `실행 원장 — <n>개 · 가장 늦은 고침 <YYYY-MM-DD HH:MM> — 다시 보기: python3 "<SD>"/scripts/conductor_ledger.py progress --roadmap <로드맵>` | rc ≠ 0 | 없음 |
| 주인 모를 worktree(처음일 때만) | `ledger orphans` | `주인 모를 worktree — 없음` | 있으면 원문 | 없음 |
| 판 차이(처음일 때만) | `ledger version --plugin-json "<SD>"/.claude-plugin/plugin.json` | `판 차이 — 없음` | 차이가 있으면 원문 | 없음 |
| 차례 | `conductor_toc.load` | (줄 없음) | `차례 — 이상: 표를 읽지 못했다 — <사유>` | 없음 |

- 이 레포의 스크립트는 지금 명령줄로 부른다(`sys.executable` + 그 스크립트 경로, 작업 폴더는 부른 곳). 원문과 종료 코드를 그대로 받는다. 스크립트에 레포 전용 값을 박지 않는다.
- 각 구간의 「이상 없음」 꼴은 그 스크립트가 지금 내는 글자에서 정한다 — 그 글자를 코드 상수로 두지 않고 그 스크립트의 상수를 import 해 쓸 수 있으면 그렇게 한다(예: `conductor_status` 의 줄 머리).
- `control_plane.py` 는 `gather` 의 블록에 걸음 찾기에 쓸 단계가 없을 때만 고친다(고치면 이유를 커밋에 적는다).
- 「지난 시간」 · 자리 글 · 질문 창 줄 내리기 · 다른 터미널 가르기는 계획 2 다 — 이 명령에 넣지 않는다.

걸음 1 지시서의 `- 기본값:` 은 「`python3 "<SD>"/scripts/conductor_sync.py --roadmap <로드맵>` 을 돌리고 그 출력을 본다」 로 시작하고, 지금 기본값의 차례 글(원격 받기 → … → 상태 브랜치)은 「명령이 도는 차례」 한 문장으로 줄인다. 판단 · 맞추기 순서 · 원천 · 세션 담당자의 원천 · 완료 표시 · 잠금 대기 · 병렬 권장 수 · 모자라면 채우기 · 로드맵 밖 일 불릿은 그대로 둔다 — 명령이 하지 않는 일(하니스 agent 목록 조회 · 표의 줄 지우기 · 거두기)은 리더가 한다.

- [ ] **Step 1: 테스트 준비물을 세운다** — `tests/test_conductor_sync.py` 의 `setUpClass` 가 버릴 레포 하나를 세운다(로컬 bare 레포를 `origin` 으로 · 로드맵과 에픽 둘 · 기계 상태 폴더는 그 레포 안). `tests/test_conductor_e2e.sh` 의 준비와 `tests/test_conductor_ledger.py` 의 가짜 `gh` 꼴을 따른다. 가짜는 `PATH` 앞의 `gh` · `hc`(받은 인자를 적고 픽스처 JSON 을 낸다)뿐이다. 세션은 `DEVBREW_SPEC_DISTILL_SESSION_ID`. 케이스마다 레포를 새로 세우지 않고, 케이스가 바꾼 표지 · 기계 상태는 그 케이스가 되돌린다.
- [ ] **Step 2: 실패하는 테스트를 하나씩 쓰고 돌리고 구현한다** — 케이스마다 쓰기 → 실패 보기 → 구현 → 통과:
  - `test_segments_in_order` — 첫 실행 출력에서 구간 이름이 `자리 · 원격 받기 · 작업 목록 · 표지 · 기본 브랜치 · PR 캐시 · 상태 브랜치 · 세션 담당자 · 스위트 잠금 · 실행 원장 · 주인 모를 worktree · 판 차이` 차례로 한 번씩 · 끝 묶음 `규모 —` · `끝나지 않은 일:` · 마지막 줄 `맞추기 — ` 로 시작해 ` 기준` 으로 끝남 · rc 0.
  - `test_first_only_segments` — 둘째 실행(같은 세션 · 표지 `held`)에는 `주인 모를 worktree` · `판 차이` 줄이 없고 `표지 — 이 세션이 쥐고 있다`.
  - `test_same_state_same_output` — 둘째 · 셋째 실행의 출력이 마지막 시각 줄을 빼면 바이트가 같다(AC11).
  - `test_stop_other_session_holds` — 다른 세션 번호로 `ledger claim` 한 뒤 → rc 5 · `멈춤 — 표지:` · `기본 브랜치` 줄 없음(AC10 — 뒤 구간은 돌지 않는다). `--takeover` 로 다시 부르면 rc 0 · `표지 — 넘겨받았다` · 처음일 때만 구간이 있다.
  - `test_stop_no_session` — 두 세션 변수를 지우고 → rc 3 · `작업 목록` 줄은 있고 `멈춤 — 표지: 세션 번호를 얻지 못했다` · 표지 파일이 생기지 않았다(AC12).
  - `test_stop_unreadable_state` — 기계 상태 파일을 깨진 꼴로 두고 → rc 3 · `멈춤 — 표지:`(원문 들여 씀). 픽스처를 되돌린다.
  - `test_status_line_outside_benign_is_shown` — 상태 보기 구간은 「이상 없음」 꼴의 줄을 허용 목록으로 갖고 그 밖의 줄은 모두 이상으로 낸다(목록에 없는 줄을 버리는 갈래를 두지 않는다). 기다리는 질문 한 줄을 `conductor_status.py waiting add` 로 올린 상태에서 `상태 브랜치 — 이상:` 과 그 질문 줄이 그대로 나온다(Review Focus 2).
  - `test_unmapped_stage_line` — 단계 「대기」 인 에픽 줄이 `→ 걸음 없음 — 차례 표에 이 단계가 없다` 로 끝나고 rc 0. 단계 「준비」 인 에픽 줄은 `→ 걸음 3 다음 일 고르기와 보내기 · ` 와 `conducting-step-3.md` 로 끝난다(Review Focus 4).
  - `test_merged_epic_rows_bring_step6` — 준비물에서 에픽 하나의 브랜치를 기본 브랜치에 머지해 단계를 「머지됨」 으로 만든다. 기계 상태 `## 자원` 에 그 에픽의 줄 하나(`ledger add --section "자원"`)가 있으면 출력에 `머지 뒤 일이 남은 에픽:` 과 그 에픽 줄이 `→ 걸음 6 머지 뒤 · ` · `conducting-step-6.md` · `자원 1` 을 담고 나온다 · 그 에픽은 `끝나지 않은 일:` 밑에 없다. 그 줄을 `ledger drop` 으로 지우고 다시 부르면 `머지 뒤 일이 남은 에픽:` 이 없다. 줄이 남은 상태에서 두 번 부르면 시각 줄을 빼고 같다(AC11).
  - `test_toc_broken_does_not_stop` — 플러그인 폴더 사본을 `$TMPDIR` 에 두고 사본 차례의 걸음 표 한 행을 지운 뒤 사본의 `scripts/conductor_sync.py` 를 부른다(차례 경로를 바꾸는 옵션 · 환경 변수는 만들지 않는다) → `차례 — 이상: 표를 읽지 못했다` · 나머지 구간이 끝까지 · rc 0(Review Focus 1).
  - `test_session_workers` — 가짜 `hc` 가 내 주소(`HC_TERMINAL_ID=t9a`)의 자식 둘(이름 `plan-e1` · `stray`)을 낸다 · 기계 상태 `## 살아 있는 agent` 에 `plan-e1` · `sub-x` → `견줄 줄: sub-x` · `표에 없는 내 자식: … stray` · 표의 줄은 그대로(`ledger` 로 다시 읽어 확인). `hc` 가 PATH 에 없으면 `세션 담당자 — hc 없음`.
  - `test_team_bundle_line` — team 형식 로드맵 픽스처에서 `리더 묶음 — ` 줄 하나 · 그 줄에 `start_bundle.py` 와 `--role leader` · 묶음 본문(역할 문서 글)이 출력에 없다.
- [ ] **Step 3: 걸음 1 지시서의 기본값을 고치고 걸음 1 문장 락을 맞춘다** — `test_conducting_loop.sh` 의 걸음 1 `once` 리터럴 가운데 기본값에서 빠진 것(`control_plane.py show --tasks <로드맵>` · `ledger claim --roadmap <로드맵> --session <세션>` · `ledger orphans` · `ledger version`)은 「명령이 도는 차례」 문장의 낱말(`conductor_sync.py --roadmap <로드맵>` · `주인 모를 worktree` · `판 차이`)로 바꾼다. `test_conductor_state_branch_docs.py` 의 걸음 1 낱말(`conductor_branch.py ensure` · `conductor_status.py sync` · `conductor_status.py show` · `받음 줄`)은 그 차례 문장과 「온 글은 읽고 받음 줄을 남긴다」 에 남긴다. `test_epic_conductor_skill.sh:226`(다시 채운 뒤 표지를 다시 잡는다)은 걸음 1 판단 글 그대로라 바꾸지 않는다.
- [ ] **Step 4: 돌려 통과를 본다** — `test_conductor_sync.py` · `test_conductor_toc.py` · `test_conductor_ledger.py` · Task 0 목록.
- [ ] **Step 5: 커밋** — `feat(spec-distill): 걸음 1 의 맞추기를 명령 하나로 돈다`.

---

### Task 9: 지휘자 skill 진입과 지휘 순환

설계 §1.4 · §2 「진입」 · AC1 · AC13(셸 호출 수).

**Files:**
- Modify: `skills/epic-conductor/SKILL.md`(31행 · `### 3. 자리 · 세션 · 표지` · `### 4. 규모 공시` · `### 5. 지휘 순환`)
- Test: `tests/test_epic_conductor_skill.sh` · `tests/test_conductor_state_branch_docs.py:186` · `shared/tests/fixtures/ask-sites.tsv`(SKILL 행 — 질문 문장이 옮겨 가면)

고칠 것:
- 진입 단계의 차례: 감시줄 판독 → 의존 확인 → 로드맵 정하기 → 맞추기 명령(설계 §2 「진입」).
- `### 3.` · `### 4.` 의 펜스와 그 아래 글을 맞추기 명령 하나로 모은다:

```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "<지금 가드 글 그대로>" >&2; exit 1; }
cd "<root>" && python3 "$SD/scripts/conductor_sync.py" --roadmap "<로드맵>"
```

  - 종료 코드 표: 0 → 5 로 · 5 → 지도(출력의 작업 목록 · 끝나지 않은 일)를 보이고 넘겨받을지 지금의 `AskUserQuestion` 글 그대로 묻는다 — 넘겨받기면 같은 펜스에 `--takeover` 를 붙여 돌린다 · 3 이고 출력에 `옛 판이 쓴 PR 캐시 줄` 이 있으면 지금의 「옛 PR 캐시 다시 채우기」 펜스(세션 번호 줄 없이 — `pr-refresh --reset` 0 이면 `release` 뒤 맞추기 명령을 다시)로 · 그 밖 → 출력을 그대로 보이고 멈춘다.
  - 규모 줄은 맞추기 명령이 낸 `규모 —` 줄을 그대로 보인다 — 지출 승인을 묻지 않는다(지금 글 그대로).
  - 남는 펜스에서 `sid="$(python3 "$SD/scripts/state_path.py" session-id)"` 줄을 뺀다(설계 §2 「펜스마다 붙던 세션 번호 줄이 없어진다」).
- `### 5. 지휘 순환` 의 Read 펜스를 `Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 한 줄로. 157행은 「차례의 걸음 표대로 돈다 — 걸음에 들어설 때 그 걸음의 지시서를 읽는다. 보내는 글 틀 · 상태 브랜치 절차는 차례의 함께 읽는 것 칸의 때에 읽는다. 손 절차 파일은 지휘자를 부르지 않고 진행할 때의 것이다 — 이 skill 안에서는 따르지 않는다」 로. 155행의 「세 파일의 `<SD>`」 는 「차례와 지시서의 `<SD>`」 로.
- 31행 「지휘의 걸음은 두 reference 가 담는다」 → 「지휘의 걸음은 차례(`references/conducting.md`)와 그 걸음 지시서가 담는다」.
- `### 6. 통합 리뷰어` · `### 7. 옮김 대조` 는 건드리지 않는다.

- [ ] **Step 1: 실패하는 단언으로 바꾼다** — `test_epic_conductor_skill.sh`:
  - AC1: `### 5. 지휘 순환` 절의 `Read ` 줄이 정확히 하나이고 `Read ${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 다 · SKILL 전체에 `Read ${CLAUDE_PLUGIN_ROOT}/references/conductor-dispatch.md` · `…/conductor-state-branch.md` 가 없다(짝: 지금 판에서는 있다 — 단언을 쓴 뒤 실패를 본다).
  - AC13: 진입 단계(`## 진입 단계` 부터 `### 5.` 앞)에서 지금 판의 정상 길이 도는 bash 펜스는 `### 1.5` 의 하나 · `### 2.` 의 하나(경로가 절대경로면 worktree 목록, 비었으면 로드맵 목록 — 둘 중 하나) · 맞추기 명령 하나다 — `conductor_sync.py` 펜스가 하나이고, `claim` · `state_path.py" session-id` · `control_plane.py" show` 가 진입 단계에 없다.
  - 옛 `claim_rc` · `takeover` 펜스 단언(`:25-59` 가운데 그 펜스를 박은 것)은 새 종료 코드 표의 낱말(`--takeover` · `옛 판이 쓴 PR 캐시 줄` · `읽기만 (권장)`)로 바꾼다. 지우는 단언이 생기면 멈추고 보고한다.
  - `test_conductor_state_branch_docs.py:186` 의 「SKILL 에 `Read <POINTER>`」 는 「걸음 1 지시서의 읽을 것 줄에 `conductor-state-branch.md`」 로 바꾼다.
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: SKILL 을 고친다** — 질문 문장(넘겨받기 · 로드맵 고르기)이 옮겨 가면 `ask-sites.tsv` 의 SKILL 행 앵커를 함께 맞춘다(행 수 그대로).
- [ ] **Step 4: 돌려 통과를 본다** — `test_epic_conductor_skill.sh` · `test_conductor_state_branch_docs.py` · `shared/tests/test_ask_recommendation.sh` · `shared/tests/test_cost_disclosure.sh` · `shared/tests/test_skill_cost_class_place.sh` · `shared/tests/test_invocation_surface.sh` · `shared/tests/test_dispatch_disposition.sh`.
- [ ] **Step 5: 커밋** — `feat(spec-distill): 지휘자 진입이 맞추기 명령 하나와 차례만 읽는다`.

---

### Task 10: 판 번호 · CHANGELOG · README · 바이트 앞뒤

설계 AC34 · AC13(PR 본문 바이트) · §6(기본 브랜치 합치기 뒤 PR #332 줄 확인). AC35(머지 뒤 새 세션에서 맞추기 끝까지의 맥락 토큰과 읽은 바이트를 재 지휘 기록에 적기)는 리더가 한다 — 이 과제는 하지 않고, Step 5 의 바이트 표가 리더가 견줄 앞 값(2026-11-24 의 174KB)과 같은 기준의 수를 남긴다.

**Files:**
- Modify: `.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md`
- Create(git 밖): `$TMPDIR/plan1-bytes.md`

- [ ] **Step 1: 기본 브랜치를 합친다** — `git fetch origin && git merge origin/HEAD`(충돌이면 멈추고 보고). 합친 뒤 Run: `grep -c 'frontmatter `source_intent`' plugins/spec-distill/references/conducting-manual.md` · Expected: `1`. 0 이면 PR #332 의 줄이 옮김에서 빠졌거나 합치기가 옛 파일에 다시 넣은 것이다 — `git grep -n 'source_intent' -- plugins/spec-distill/references/` 로 자리를 보고 멈춰 보고한다.
- [ ] **Step 2: 판을 정한다** — `git show origin/HEAD:plugins/spec-distill/.claude-plugin/plugin.json` 의 판보다 한 minor 위. 같은 판을 올린 다른 PR 이 있으면(`git log origin/HEAD -1 -- plugins/spec-distill/.claude-plugin/plugin.json`) 그 판 위로.
- [ ] **Step 3: CHANGELOG** — `## [<판>] — <YYYY-MM-DD>` 의 Added(맞추기 명령 · 차례 파서 · 지시서 열 파일 · 원장 `--session` 생략) · Changed(지휘 절차서가 차례가 됨 · 지휘자 skill 이 차례만 읽음 · 병렬 답 줄에 시각을 붙이지 않음 · 손 절차 파일 자리). 호출 이름은 그대로라고 적는다.
- [ ] **Step 4: README** — 스크립트 목록에 `conductor_sync.py` · `conductor_toc.py` 한 줄씩(무엇을 · 종료 코드 · 쓰기 여부 — 맞추기 명령은 지금 스크립트를 불러 표지 · PR 캐시 · 상태 브랜치를 쓰고, `git fetch` · `gh` · `hc` 를 부른다). Principles Instantiated 에 한 줄: 「Law 3 · P5 — 걸음마다 그 걸음의 지시서만: 차례의 걸음 표가 걸음 → 지시서의 한 곳이고 맞추기 명령이 같은 표를 읽는다」.
- [ ] **Step 5: 바이트를 잰다** — 앞: `git show <Task 0 의 HEAD>:<경로> | wc -c` 로 SKILL.md · `references/conducting.md` · `references/conductor-dispatch.md` · `references/conductor-state-branch.md`(진입에서 맞추기 끝까지 읽으라고 지시받던 것). 뒤: SKILL.md · 차례 · `conducting-step-1.md` 와 맞추기 명령 한 번의 출력(이 레포의 이 로드맵에서 — 표지를 쥔 세션이 아니면 출력 바이트는 재지 못했다고 적는다). 표로 `$TMPDIR/plan1-bytes.md` 에 쓴다 — PR 본문의 「바이트 앞뒤」 절이 이 표를 싣는다.
- [ ] **Step 6: 판 테스트를 돈다** — `shared/tests/test_changelog_integrity.sh` 와 판 번호를 읽는 테스트(`git grep -l 'plugin.json' -- 'plugins/spec-distill/tests/*' 'shared/tests/*'` 가운데 판을 보는 것).
- [ ] **Step 7: 커밋** — `chore(spec-distill): 판을 올리고 CHANGELOG · README 를 맞춘다`.
- [ ] **Step 8: 전체 스위트를 공유 잠금으로 한 번 돈다**(Global Constraints 의 잠금 줄) — Expected: Task 0 에서 이미 실패하던 것 밖의 실패가 없다. 있으면 그 이름과 첫 실패 줄을 보고한다.

---

## 마지막 전체 리뷰에 실을 것

고른 실행 방식의 마지막 전체 리뷰(브랜치 전체)에 아래를 싣는다.

- 설계문서 `## Acceptance Criteria` 의 AC 목록 전부. 리뷰는 AC 마다 한 줄 `AC<n>: <구현됨|미룸|빠짐> — <근거>` 로 보고하고, 그 보고를 git 이 추적하지 않는 파일(`$TMPDIR/plan1-ac-report.md`)에 적는다. 계획 2 ~ 4 의 AC(AC14 ~ AC33)는 `미룸 — 계획 <n>(설계 §6)` 으로, AC35 · AC36 은 `미룸 — 리더가 머지 뒤 걸어 본다` 로 적는다 — 이 둘은 설계 §6 이 이미 받는 곳을 정했으므로 `## 미룸` 표에 다시 올리지 않는다.
- 설계문서 `## 있는 것 검토` 가 고른 것을 실제로 썼는지 — `ledger release` · 표지 · 기계 상태 · 옮김 폴더 · `start_bundle.py --role leader` · 품질 게이트 절차의 「그 자리의 줄만」 방식 · 걸음표(칸을 더하지 않았는지) · 지금 스크립트(맞추기 명령이 같은 일을 다시 짜지 않고 부르는지).
- 끝에서 끝 흐름: 진입 → 맞추기 명령 → 차례 → 걸음 지시서 → 다음 걸음 지시서(가리킴을 따라가며 읽을 것이 빠지지 않는지) · 맞추기 명령의 종료 코드를 SKILL 의 종료 코드 표가 모두 받는지 · 차례 표를 고치면 맞추기 출력과 AC7 확인이 함께 따라오는지.
- 계획 1 의 AC 가운데 `미룸` · `빠짐` 과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올리고 커밋한다.
- PR 을 만들기 전에 `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/9.2.0"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-24-leader-step-guides-restart-design.md $TMPDIR/plan1-ac-report.md` 를 돌려 경고를 사용자에게 보인다.
- 걸어 보기(AC35 · AC36)는 이 계획의 과제가 아니다 — 리더가 머지 뒤 새 세션에서 한다.
