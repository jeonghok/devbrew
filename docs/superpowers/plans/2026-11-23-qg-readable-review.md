# R6 — 읽히는 리뷰 글 · 답 이어지기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지휘 중 qg 리뷰의 결과 글과 질문 앞 글을 맥락 머리 네 줄로 시작하는 짧은 틀로 바꾸고(근거 · 인용은 파일로), 지휘자를 거친 답을 「이미 답한 것」 파일로 qg 에 넘겨 근거가 같으면 다음 리뷰에서 다시 묻지 않게 한다.

**Architecture:** qg 쪽은 리뷰어 출력에 `why` 를 더하고, `intent_critic.py` 가 `--answered` 로 받은 항목을 답 폴더의 답 옆에 따로 실어 거르며, 돌려주는 꼴을 3판(`answered_filtered` · `why` · `asked_before` · `changed_observation`)으로 올린다. 합성 스크립트는 합치기 전 지적 목록을 파일로 남기고, 다른 팀 읽기는 `type: roadmap-review` 문서를 뺀다. 지휘 쪽은 새 스크립트 `qg_answered.py` 가 기록 파일에서 「이미 답한 것」 을 만들고, `qg-review.md` 가 호출 줄 · 담당자 글 · 화면 틀 · 기록 틀을 바꾼다. 과제 순서는 qg 쪽(Task 2–10) → 지휘 쪽(Task 11–14) → 끝 확인(Task 15).

**Tech Stack:** Python 3.9 문법 · PyYAML(`safe_load` · `safe_dump`) · unittest · bash(macOS 3.2 호환) 셸 문서 락(`shared/tests/assert.sh`) · 마크다운 절차 문서.

**Spec:** `docs/superpowers/specs/2026-11-22-qg-readable-review-design.md` — 실행자는 이 계획과 설계문서를 함께 읽는다. 설계문서 본문은 고치지 않는다 — `## 미룸` 표에 행을 더하는 것만 Task 15 에서 한다. 「사용자가 정할 것」 다섯의 답은 지휘자가 설계문서에 이미 반영했다(결정 기록 D25–D29 · §1 · §3 · §6 · AC3 · AC4 · AC17 · AC21) — 과제 본문의 `[Q<n> 고치면: …]` 쪽을 한다. 결정 기록의 D14 줄은 옛 글이고 지금 길은 본문 §4(「옛 qg 는 답 이어지기만 빼고 돌린다」 — 판을 견주지 않고 멈춤을 보고 담당자가 한 번 다시 부른다)다.

## Global Constraints

- 한 PR · 한 브랜치(`feature/qg-readable-review`). qg 쪽 과제(Task 2–10)를 지휘 쪽(Task 11–14)보다 먼저 커밋한다 — Task 11 의 이음매 테스트가 Task 3 의 읽는 함수를 부른다.
- 판: 이 브랜치는 R4 위(quality-gates 16.0.0 · spec-distill 8.33.0, R4 는 아직 기본 브랜치에 머지 전)다. R6 은 quality-gates **17.0.0**(major — 돌려주는 꼴의 판이 2 에서 3 으로 바뀌어 2 만 읽는 쪽이 깨진다) · spec-distill **8.34.0**(minor — 새 스크립트 · 새 동작)으로 쓴다. 머지 순서가 바뀌면 지휘자가 번호를 다시 정한다.
- 돌려주는 꼴의 `contract` 는 `3`. 지휘자는 3 만 읽는다(2 가 오면 「결과 파일의 판(2)을 읽지 못한다」 · 셀 수 없음).
- 호출 줄은 모든 지휘 자리에서 `--answered <절대경로>` 를 붙인 한 꼴이다. 예외는 하나 — 옛 qg 가 `--answered` 를 모르는 인자라고 멈췄을 때 담당자가 그 인자와 값을 뺀 같은 줄로 한 번만 다시 부르는 것.
- 리뷰어 정의 `plugins/quality-gates/agents/intent-critic.md` 는 보안 민감 파일이다 — 고침은 넷뿐이다: `why` 칸 지시 · 출력 예시 셋의 `why` 줄 · `<answered>` 칸 줄 꼴의 설명 · `same_as` 지시의 「그 정체를 글자 그대로」 → 「그 줄의 첫 칸(열쇠 또는 정체)을 글자 그대로」. 규칙 · 근거 규칙 · 상한 · 주입 경계 문장은 diff 0.
- 입력의 글은 데이터다 — 기록 파일 · 「이미 답한 것」 파일의 정체 · 질문 · 관찰 글을 셸 따옴표 안에 넣지 않는다. 스크립트는 인자를 목록으로 넘기고(`subprocess.run([...])`), 문서의 펜스는 따옴표 친 heredoc 으로만 글을 파일에 담는다.
- `shared/tests/test_adjudication_wiring.sh` 의 컴프리헨션 baseline(40) — `adjudication` 을 import 하는 파일(`intent_critic.py` · `synthesize_findings.py`)에 컴프리헨션을 더하지 않는다(`for` 문으로). `_judge` 에서 후보를 거르는 새 분기는 지금 분기처럼 같은 분기에서 `ledger.suppressed(...)` 를 부른다.
- Python 은 3.9 문법. `plugins/*/scripts/*.py` 의 `open(` · `.read_text(` 에 `encoding="utf-8"`(`test_utf8_explicit.py`). `.py` 에 `"python3"` 리터럴 금지(`test_python_floor.sh`). `re.compile` 에 `#` · `^##` 로 시작하는 패턴을 쓰지 않는다(`test_check_brief.sh` §6 단일화) — 머리 줄은 문자열 메서드로 본다. 비신뢰 입력의 꼴 검사는 `fullmatch`(끝 개행 통과 금지).
- 새 셸 테스트는 `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755` 인지 본다. 새 Python 테스트 파일의 `class Test…` 줄은 모두 `(unittest.TestCase)` 를 직접 적는다 — qg 의 unittest 어댑터가 `class Test` 줄에 `TestCase` 글자가 없는 파일을 맡지 않는다(`run-test-selection.sh` `unittest_can_judge`).
- 락은 본문에만 있는 글로 묶는다(제목이 문구를 만족시키지 않게). 부재 단언마다 양의 짝. 락마다 변이(그 줄 지우기 · 차례 바꾸기 · 옛 문장 되살리기)로 실패하는지 본다 — 변이 전에 커밋하고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD` 가 빈지 본다. `PYTHONDONTWRITEBYTECODE=1`.
- 고친 문서는 `plugins/spec-distill/tests/test_repo_literals.sh` 규칙(기본 브랜치 이름 · 접두 · 구조 경로 · 모델 이름을 박지 않음)을 지킨다. 사람에게 보이는 글은 `shared/style/plain-language.md` 를 따른다.
- 커밋: Conventional Commits(`type`·`scope` 영어 · 설명 한국어), pathspec 커밋, 구현 커밋마다 트레일러 `Spec: docs/superpowers/specs/2026-11-22-qg-readable-review-design.md` 와 지휘자가 보내는 글에 준 끝 두 줄.
- 금지: 공유 임시 폴더 glob 삭제 · `git stash` · 다른 worktree 의 git · HEAD 뒤로 옮기기(reset · rebase · force) · push(지휘자가 한다).
- 임시 파일은 지휘자가 준 `TMPDIR`(`/Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/tmp/<담당자 이름>`)에 셸로 쓴다.
- **전체 스위트는 공유 잠금 아래서만:** `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.29.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-qg-epic-roadmap-intent-review-brief/files/suite-lock --owner <agent 이름> --wait 600 -- bash -c 'bash tools/suite/run-all.sh'`. 하위 agent 에게 보내는 글에도 이 줄과 경로를 그대로 싣는다. 못 잡으면 주인 · 잡은 시각을 보고한다. 과제 안에서는 그 과제의 좁은 테스트만 잠금 없이 돌린다.

## Review Focus

1. **같은 기록 파일이 두 자리에서 내용이 다르게 읽힘** — 기본 브랜치에 머지된 기록과 에픽 브랜치의 같은 이름 파일이 다르면, 사람은 한쪽이 조용히 이기지 않고 알림이 남기를 기대한다. 앞 자리(기본 → 기록 → 에픽) 것을 싣고 「열쇠가 같은데 내용이 다른 기록 1개」 를 낸다. 테스트: Task 11 `test_same_key_different_content_prefers_first_ref`.
2. **리뷰어가 넘겨받은 열쇠를 가리켰는데 정체가 다름** — 설계 승인 앞에서 답한 의심을 머지 앞 리뷰어가 다른 파일 · 다른 종류로 잡으면 걸러져야 하고, 잘못 가리킨 것이면 사람이 찾을 수 있어야 한다. 걸러지고 목록 줄에 「정체가 다름 — <그때> → <지금>」. 테스트: Task 5 `test_handed_key_with_other_identity_filters_and_marks`.
3. **넘겨받은 파일을 읽지 못함**(보관 폴더가 정리됨 · 링크 · 너무 큼 · 깨짐 · 옛 판) — 사람은 리뷰가 멈추지 않고 질문이 더 나오며 그 사실이 한 줄로 보이기를 기대한다. 테스트: Task 4 `test_unreadable_handed_file_runs_on_with_notice`(다섯 사유).
4. **뒤 기록이 앞 답을 다시 물어 새 답을 받음** — 옛 답이 더는 넘어가지 않아야 한다(사용자가 답을 뒤집었다). 테스트: Task 11 `test_later_record_supersedes_by_key`.
5. **깔린 qg 가 옛 판** — `--answered` 에서 멈춘 qg 를 담당자가 인자 없이 한 번만 다시 부르고, 화면에 「답 이어지기 없이 돌았다 — …」 가 맥락 머리 바로 아래에 보이며 질문은 「판을 읽지 못한다」 로 셀 수 없음이 된다. 테스트: Task 12 락 `old-qg-retry-once` · `back-contract-3`.

---

## 사용자가 정할 것 — 구현 전에 지휘자가 답을 적는다

아래 다섯은 설계의 글자 · 수용 기준 · 보이는 동작을 더하거나 바꿔 이 계획이 정하지 않았다(설계문서 `### Deferred to plan` 의 행). **과제 본문은 「그대로 두면」 을 기본으로 적고, 「고치면」 이면 바뀌는 단계를 `[Q<n> 고치면: …]` 로 함께 적었다.** 구현자는 지휘자가 적어 준 답대로 한쪽만 한다. 답이 없으면 구현을 시작하지 않는다.

| 결정 | 닿는 과제 | 권고 | 답 |
|---|---|---|---|
| Q1 의도 점검 결과만 읽지 못한 리뷰의 결과 줄(cf64b319#r2.1) — 그대로 두면 결과 파일을 옮기지 못함 · 판을 읽지 못함 · 보낸 범위의 것이 아님에서도 결과 줄 전체가 「셀 수 없음 — <사유>」 라 막는 지적 개수가 화면에서 사라진다. 고치면 그 셋은 지적 개수를 그대로 쓰고 끝에 「 · 의도 점검은 셀 수 없음(<사유>)」 를 붙이고, 결과 줄 전체 「셀 수 없음」 은 담당자가 돌아오지 않은 경우로 좁힌다(AC4 문장도 그렇게 읽는다) | 13 | 고치면 — 옛 qg 로 돈 리뷰(§4)는 판정과 지적이 오는데도 늘 「판을 읽지 못한다」 로 끝나, 그대로 두면 그 리뷰의 막는 지적 수가 매번 사라진다 | 고치면 — 사용자 「고치면 (권장)」(2026-11-23 · 설계 D25) |
| Q2 합쳐지기 전 지적 목록 파일이 세션 폴더에 없을 때(53fae0e6#r2.1 · b083a44d#r3.1 — 옛 qg 로 돈 리뷰 · 파일 쓰기 실패) — 그대로 두면 설계에 갈래가 없어 담당자가 지적 목록을 실을 자리가 없다. 고치면 담당자가 qg 의 고칠 목록(result.md 의 `### 막는 지적` · `### 제안` · `## 낮춘 지적`)에서 싣고 마지막 보고 첫머리에 「합쳐지기 전 목록 없이 실었다 — 같은 줄의 지적이 하나로 합쳐졌을 수 있다」 를 적으며, 지휘자가 그 줄을 맥락 머리 바로 아래에 보이고 되돌리기의 「지적마다 처리」 는 그 목록의 행 하나를 단위로 센다. 다른 길: 되돌리기 전에 새 qg 로 다시 리뷰해 목록을 얻는다(b083a44d 안) | 12 | 고치면(첫 길) — 다시 리뷰는 판을 올리기 전에는 같은 결과를 낸다 | 고치면(첫 길) — 사용자 「권고 길 (권장)」(2026-11-23 · 설계 D26) |
| Q3 낮춘 지적을 제안 묶음과 제안 개수에도 세는가(9600d39d#r2.2 — qg 는 낮춘 지적을 제안 심각도로 바꿔 같은 목록에 남긴다) — 그대로 두면 설계가 정하지 않아 구현마다 다를 수 있다. 「세지 않는다」 면 `lowered: true` 인 항목은 낮춘 지적 묶음에만 한 번 싣고 제안 수에서 뺀다. 「센다」 면 두 묶음에 두 번 싣는다 | 12 · 13 | 세지 않는다 — 「지적 하나에 한 줄」 과 「번호를 이어 매겨 3번 · 6번으로 짚는다」 가 한 지적이 두 번호를 가지면 깨진다 | 세지 않는다 — 사용자 「세지 않음 (권장)」(2026-11-23 · 설계 D27) |
| Q4 지적도 질문도 없는 리뷰의 「자세히」 줄(9600d39d#r2.1) — 그대로 두면 §3 대로 맥락 머리 네 줄과 「다음」 줄이 전부라, 질문이 모두 걸러진 리뷰에서 걸러진 목록의 경로가 화면에 없다. 고치면 그때도 끝에 `자세히: <보관 폴더의 result.md 경로>` 한 줄을 남긴다 | 13 | 고치면 — Anti-goals 의 「질문을 조용히 거르지 않는다 — 목록은 파일에 있다」 를 화면에서 가리킬 줄이 없어진다 | 고치면 — 사용자 「남김 (권장)」(2026-11-23 · 설계 D28) |
| Q5 기록 파일에 「달라진 관찰」 을 싣는가(9dbe3507#r2.1) — 그대로 두면 근거가 달라져 다시 물은 질문의 새 근거가 보관 폴더에만 있어, 로드맵이 끝나 그 폴더가 정리되면 왜 다시 물었는지 볼 곳이 없다. 고치면 기록 틀의 그 질문 절에 `- 달라진 관찰:` 줄과 그 아래 두 칸 들여 쓴 줄들(돌려주는 꼴의 `changed_observation` 그대로)을 `- 전에 한 답:` 줄 다음에 더한다(AC17 의 줄 목록이 하나 는다) | 13 | 고치면 — 기록 파일이 답의 정본이라 다시 물은 까닭도 거기 남아야 다음 사람이 읽는다 | 고치면 — 사용자 「실음 (권장)」(2026-11-23 · 설계 D29) |

---

### Task 1: 다시 확인

설계문서가 근거로 든 자리가 구현을 시작할 때도 그런지 본다. AC 를 직접 맡지 않는다 — 뒤 과제 전부의 전제다. (계획을 짤 때 2026-11-23 브랜치 끝 `0ddb516f` 에서 한 번 봤고 달라진 것이 없었다.)

**Files:** 읽기만. 결과는 `TMPDIR` 의 `recheck.md` 에 적고 마지막 보고에 싣는다.

- [ ] **Step 1: 바탕.** `git fetch origin` 뒤 `git merge-base --is-ancestor 685a8a87 HEAD`(R4 끝이 들어 있다)가 0 인지, R4(`feature/qg-review-only`)가 그 뒤 더 나갔는지(`git log --oneline HEAD..origin/feature/qg-review-only`) 본다. 더 나갔거나 R4 가 머지됐으면 멈추고 보고한다 — 지휘자가 합칠 자리를 정한다.
- [ ] **Step 2: qg 쪽 자리.** 아래가 그대로인지 본다 — `intent_critic.py` 의 `CONTRACT = 2` · `_answered_lines` 의 줄 꼴 `- %s · %s · 관찰: %s` · `_answered_state` 가 `same != ident` 면 거르지 않음 · `cmd_filter` 가 `_load_answered` 로 답 폴더를 다시 읽음, `agents/intent-critic.md` 의 `<answered>` 줄 설명(`- <정체> · <답> · 관찰: <글>`)과 `same_as` 지시(「그 정체를 글자 그대로 적는다」), `setup-qg.sh` 의 모르는 인자 줄 「모르는 인자다(Unknown argument)」, `synthesize_findings.py` 의 `main` 이 `dedup(findings + promoted)` 를 메모리에서 하고 `_lower` 가 낮춘 지적을 `SUGGESTION` 으로 같은 목록에 남김, `other_teams.py` `_intent_docs` 가 `io_.is_intent_doc` 로만 고름.
- [ ] **Step 3: 지휘 쪽 자리.** `qg-review.md` 에 `### 같은 대상에 전에 물은 것` 절 · 「같은 대상에 전에 물은 것이 있어도 질문은 띄운다」 · 좁은 재리뷰의 「돌아온 질문은 거르지 않는다」 · `## 돌아왔을 때` 2 의 「`contract` 가 `2` 가 아니면」 · 머지 앞 행선의 「`이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록이 있으면」 이 있는지 본다.
- [ ] **Step 4: 겹치는 옆 일.** `git log --oneline "$(git merge-base HEAD origin/HEAD)"..origin/HEAD -- plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/agents/intent-critic.md plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/scripts/other_teams.py` 로 이 브랜치가 갈라진 뒤 기본 브랜치에서 그 파일을 고친 커밋이 있는지 본다. 있으면 멈추고 보고한다.
- [ ] **Step 5: 판.** 두 `plugin.json` 의 판(16.0.0 · 8.33.0)을 적는다. 다르면 멈추고 보고한다.
- [ ] **Step 6:** 모두 같으면 「다시 확인 — 달라진 것 없음」 한 줄을 `recheck.md` 에 적고 다음 과제로 간다. 하나라도 다르면 무엇이 어떻게 달라졌는지 적고 멈춘다.

---

### Task 2: 리뷰어 정의 — `why` 와 `<answered>` 줄 꼴

**AC:** AC5.

**Files:**
- Modify: `plugins/quality-gates/agents/intent-critic.md`(L83 `<answered>` 줄 · L135 `same_as` 지시 · `## 질문 칸` 목록 · 출력 예시 셋)
- Test: `plugins/quality-gates/tests/test_intent_critic.py`(`class TestPersona` 에 케이스 셋)

**Interfaces:**
- Produces: 리뷰어 출력 질문 항목의 새 칸 `why`(글 한 줄). `<answered>` 줄 꼴 — 답 폴더 답 `- <정체> · <답> · 질문: <그때의 질문 글> · 관찰: <글>`, 넘겨받은 항목 `- <열쇠> · <정체> · <답> · 질문: <그때의 질문 글> · 관찰: <글>`(Task 4 가 이 꼴로 쓴다).

- [ ] **Step 1: 실패하는 테스트.** `TestPersona` 에 더한다.
  - `test_why_field_instruction` — 본문에 `- \`why\` — 이 질문의 답에 따라 무엇이 달라지는지를 처음 보는 사람이 읽을 쉬운 말 한 문장으로. 번호는 괄호 안에만 둔다.` 가 정확히 한 번, 그 줄이 `- \`question\` —` 줄 뒤에 있다.
  - `test_examples_carry_one_sentence_why` — `qg-intent-critic` 펜스의 `questions:` 항목 셋마다 `why:` 줄이 하나이고, 그 값(YAML 로 읽은 글)에 줄바꿈이 없고 「다.」 로 끝나며 「다.」 가 한 번뿐이다. 질문 없는 예시(`questions: []`)에는 `why` 가 없다.
  - `test_answered_slot_and_same_as_first_cell` — 본문에 `그 줄의 첫 칸(열쇠 또는 정체)을 글자 그대로 적는다` 가 한 번, 옛 `그 정체를 글자 그대로 적는다` 가 0번(양의 짝: 앞 단언). `<answered>` 설명 줄에 「첫 칸이 열쇠」 · 「그때의 질문 글」 이 있다.
- [ ] **Step 2: 돌려 실패를 본다.** `cd plugins/quality-gates/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_intent_critic.TestPersona -v` — 새 셋이 FAIL.
- [ ] **Step 3: 고친다.** 네 자리만, 이 글자로:
  - `<answered>` 줄(L83): `- \`<answered>\` — 이미 답한 질문. 한 줄에 하나다. 첫 칸이 열쇠(지휘자가 넘긴 답 — \`<기록 파일 이름>#<n>\`, 그 뒤에 정체가 한 칸 더 온다) 또는 정체(답 폴더의 답)이고, 그 뒤에 답 · \`질문:\` 뒤의 그때의 질문 글 · \`관찰:\` 뒤의 글이 온다.`
  - `same_as` 지시(L135): `- 이미 답한 질문과 같다고 보면 \`same_as\` 칸에 그 줄의 첫 칸(열쇠 또는 정체)을 글자 그대로 적는다(\`<answered>\` 줄의 \`- \` 뒤 첫 칸).`
  - `## 질문 칸` 의 `question` 불릿 바로 뒤에 Step 1 의 `why` 줄.
  - 예시 셋의 `question:` 줄 바로 뒤 `why:` — 차례로 `"CSV 하나로 두면 다른 형식이 필요한 사람은 내보내기를 쓰지 못한다."` · `"의도가 아니면 디스크가 가득 찰 때 사용자가 실패를 모른 채 끝난다."` · `"다른 팀과 이름 짓는 법이 갈라지면 두 기능이 만든 파일을 함께 쓸 때 섞인다."`
- [ ] **Step 4: 통과와 범위.** 같은 명령이 PASS. `git diff -U0 plugins/quality-gates/agents/intent-critic.md` 의 hunk 가 위 넷(예시 셋은 한 갈래)뿐인지 눈으로 본다 — 다른 줄이 바뀌었으면 되돌린다.
- [ ] **Step 5: 변이.** 커밋한 뒤 `why` 줄 지우기 · 예시 하나의 `why` 를 두 문장으로 · 옛 `그 정체를 글자 그대로` 되살리기마다 RED, 복원.
- [ ] **Step 6: 커밋.** `git commit -m "feat(qg): 리뷰어가 질문마다 왜 묻는지 한 문장을 낸다" -- plugins/quality-gates/agents/intent-critic.md plugins/quality-gates/tests/test_intent_critic.py`

---

### Task 3: 넘겨받은 답 읽기와 답 파일의 질문 글

**AC:** AC11(읽는 쪽) · AC12(답 폴더 답의 질문 글).

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_answers.py`
- Create: `plugins/quality-gates/tests/test_intent_handed.py`

**Interfaces:**
- Produces:
  - `read_handed(path: str) -> tuple` → `(entries: Optional[List[dict]], why: Optional[str])`. 성공이면 `(entries, None)`, 읽지 못하면 `(None, <사유>)`. 사유 상수 `HANDED_MISSING = "없음"` · `HANDED_NOT_FILE = "보통 파일이 아님"` · `HANDED_TOO_BIG = "크기 상한 넘음"` · `HANDED_BAD_SHAPE = "꼴이 맞지 않음"` · `HANDED_BAD_VERSION = "판이 다름"`. 상한 `HANDED_MAX_BYTES = 1000000`. 판 `HANDED_CONTRACT = 1`.
  - 항목 dict 키: `key` · `id` · `answer` · `question` · `observation` · `answered_at` · `route` · `record`(모두 `str`).
  - `parse_answer_file` 의 결과에 `question`(답 파일 `## 질문` 절의 글, 앞뒤 빈칸 뗌) 키를 더한다.
- 「이미 답한 것」 파일의 꼴(Task 7 이 qg reference 에 계약으로 적는다):

```yaml
contract: 1
entries:
  - key: "2026-11-22-R4-spec.md#2"
    id: "diff#docs/a.md#갈라짐"
    answer: "의도다"
    question: "<그때의 질문 글 — 한 줄>"
    observation: "<관찰 줄들을 \n 으로 이은 글>"
    answered_at: "2026-11-22 21:25"
    route: "-"
    record: "<로드맵 폴더>/reviews/2026-11-22-R4-spec.md"
```

- [ ] **Step 1: 실패하는 테스트.** `test_intent_handed.py` 에 `class TestReadHanded(unittest.TestCase)` · `class TestAnswerFileQuestion(unittest.TestCase)`.
  - `test_reads_entries_in_order` — 위 꼴의 항목 둘(둘째는 `answer: "잘못 골랐다"`, `route: "새 일의 씨앗"`)이 순서대로 dict 로 온다, `why` 는 None.
  - `test_unreadable_reasons` — 다섯 사유를 한 테스트에서: 없는 경로 → `없음`; 디렉터리와 정상 파일을 가리키는 심볼릭 링크 → `보통 파일이 아님`; `HANDED_MAX_BYTES + 1` 바이트 → `크기 상한 넘음`; YAML 이 깨짐 · `entries` 가 목록이 아님 · 항목에 키가 빠짐 · 값이 글이 아님(정수 · 목록 · 별칭으로 만든 목록) · `answer` 가 `지금은 모르겠다` · `key` 가 `<이름>.md#<숫자>` 꼴이 아님(`a.md#1\n` 포함) · 같은 `key` 두 번 → `꼴이 맞지 않음`; `contract: 2` 와 `contract` 없음 → `판이 다름`. 모두 `entries` 가 None.
  - `test_route_values` — `잘못 골랐다` 항목의 `route` 가 `이 에픽 안에서 고친다` · `새 일의 씨앗` · `재분해 신호` 밖이면 `꼴이 맞지 않음`, `의도다` 항목의 `route` 는 `-` 여야 한다.
  - `test_answer_file_question_section` — `render_answer_file(...)` 로 만든 글을 `parse_answer_file` 이 읽으면 `question` 이 넣은 질문 글과 같다. `## 질문` 절이 없으면 `question` 은 `""`.
- [ ] **Step 2: 돌려 실패를 본다.** `cd plugins/quality-gates/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_intent_handed -v`.
- [ ] **Step 3: 구현.** `read_handed` — `os.lstat` 로 링크 · 보통 파일을 먼저 가르고, 크기는 `st_size` 로 보고, `open(path, encoding="utf-8")` 로 읽어 `yaml.safe_load`(예외는 모두 꼴이 맞지 않음). 판 검사가 꼴 검사보다 먼저다(`contract` 가 정수 1 이 아니면 판이 다름). 항목 하나라도 틀리면 파일 전체를 받지 않는다 — 이 방향의 실패는 질문을 더 묻게 할 뿐이다. 열쇠 꼴: `#` 로 한 번 나눠 앞이 `.md` 로 끝나는 `/` 없는 이름, 뒤가 `isascii() and isdigit()`.
- [ ] **Step 4: 통과.** 같은 명령 PASS. `test_intent_critic.TestAnswerFile` 도 PASS.
- [ ] **Step 5: 커밋.** `git commit -m "feat(qg): 지휘자가 넘긴 「이미 답한 것」 파일을 읽는다" -- plugins/quality-gates/scripts/intent_answers.py plugins/quality-gates/tests/test_intent_handed.py`

---

### Task 4: 준비가 넘겨받은 답을 리뷰어 입력에 싣는다

**AC:** AC9(스크립트 쪽) · AC11 · AC12(리뷰어 입력 줄).

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`prepare` 인자 · `_prepare` · `_answered_lines`)
- Test: `plugins/quality-gates/tests/test_intent_handed.py`(`class TestPrepareHanded(unittest.TestCase)`)

**Interfaces:**
- Consumes: `ia.read_handed(path)` · 항목 키(Task 3). 답 폴더 답의 `question`(Task 3).
- Produces:
  - `intent_critic.py prepare … [--answered <경로>]`. 없으면 지금과 같다.
  - 세션 폴더 파일 `intent-handed.yaml` — `yaml.safe_dump({"entries": <읽은 항목들>}, allow_unicode=True, sort_keys=False)`. 넘겨받은 답이 없거나 읽지 못했으면 이 파일을 지운다(앞 실행이 남긴 것 포함). 상수 `HANDED = "intent-handed.yaml"`.
  - 공시 줄 `"넘겨받은 답을 읽지 못함 — " + <사유>` (상수 `HANDED_UNREAD`).
  - `_answered_lines(answered: dict, handed: List[dict]) -> str` — 답 폴더 답은 정체 차례로 `- <정체> · <답> · 질문: <질문 글> · 관찰: <관찰 첫 줄>`, 그 뒤에 넘겨받은 항목을 파일 차례로 `- <열쇠> · <정체> · <답> · 질문: <질문 글> · 관찰: <관찰 첫 줄>`. 칸 글은 `_one_line` 으로 한 줄로 접고, 빈 글은 `-`. 둘 다 없으면 `답한 질문 없음`.

- [ ] **Step 1: 실패하는 테스트.**
  - `test_handed_lines_one_per_entry_with_question` — 정체가 같은 넘겨받은 항목 둘(열쇠 다름)과 답 폴더 답 하나로 `prepare` 를 돌리면(근거 있는 픽스처 — `test_intent_critic.TestPrepare` 의 픽스처 만드는 길을 쓴다) `intent-answered.md` 가 세 줄이고, 넘겨받은 줄 둘이 `- <열쇠> · <같은 정체> · ` 로 시작하며 각자의 질문 글을 담고, 답 폴더 줄도 `질문: ` 칸이 있다(AC12).
  - `test_handed_copy_written_and_removed` — 읽은 항목이 `intent-handed.yaml` 에 같은 차례로 있다. `--answered` 없이 다시 돌리면 그 파일이 없다.
  - `test_unreadable_handed_file_runs_on_with_notice` — Task 3 의 다섯 사유마다 `prepare` rc 0 · 마지막 줄 `intent-call: ` · 공시에 `넘겨받은 답을 읽지 못함 — <사유>` 가 한 번 · `intent-handed.yaml` 없음 · `intent-answered.md` 에 넘겨받은 줄 없음(AC11).
  - `test_no_answered_arg_unchanged` — 인자 없이 돌린 `intent-answered.md` · 공시 줄이 이 과제 전의 꼴과 같다(답 폴더 줄에 `질문: ` 칸이 는 것만 다르다 — 기대값을 그 꼴로 적는다).
- [ ] **Step 2: 돌려 실패를 본다.** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_intent_handed.TestPrepareHanded -v`.
- [ ] **Step 3: 구현.** `prepare` 파서에 `p.add_argument("--answered", default=None, help="지휘자가 넘긴 「이미 답한 것」 파일(절대 경로) — intent-critic 단계에만 쓴다")`. `_prepare` 에서 넘겨받은 답 읽기는 좁은 리뷰 · 근거 없음 갈래(`return "none"`) **뒤**, 답 폴더 읽기 옆에서 한다 — 리뷰어를 부르지 않는 실행에는 걸러질 것이 없다. `_write(_path(rd, HANDED), …)` 는 `_write` 를 쓴다(UTF-8 · backslashreplace).
- [ ] **Step 4: 통과.** 같은 명령 PASS, `python3 -m unittest test_intent_critic -v` 가 그대로 PASS(답 폴더 줄 꼴이 바뀐 단언이 있으면 새 꼴로 고친다 — 고친 단언 이름을 보고에 적는다).
- [ ] **Step 5: 커밋.** `git commit -m "feat(qg): 넘겨받은 답을 리뷰어 입력에 항목마다 따로 싣는다" -- plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/tests/test_intent_handed.py plugins/quality-gates/tests/test_intent_critic.py`

---

### Task 5: 거르기 · 돌려주는 꼴 3판 · 결과 절의 목록

**AC:** AC6 · AC7 · AC10 · AC12(걸러진 목록).

**Files:**
- Modify: `plugins/quality-gates/scripts/intent_critic.py`(`CONTRACT` · `RETURN_KEYS` · `QUESTION_KEYS` · `_answered_state` → `_prior` · `_judge` · `cmd_filter` · `_question_record` · `_row` · `_write_return` · `_section` · `cmd_render`)
- Test: `plugins/quality-gates/tests/test_intent_handed.py`(`class TestFilterHanded(unittest.TestCase)` · `class TestReturnThree(unittest.TestCase)`), `plugins/quality-gates/tests/test_intent_return.py`(판 2 → 3 단언)

**Interfaces:**
- Consumes: `intent-handed.yaml`(Task 4) · `HANDED` 상수.
- Produces:
  - `CONTRACT = 3`. `RETURN_KEYS` 끝에 `answered_filtered`(정수 — 단계를 건너뛰었거나 셀 수 없으면 `-`). `QUESTION_KEYS` 끝에 `why` · `asked_before` · `changed_observation`.
  - `intent-questions.yaml` 질문 레코드의 새 키: `why`(글 | `-`), `asked_before`(글 | `-`), `changed_observation`(글 목록 | `-`), 넘겨받은 항목으로 걸러진 레코드는 `handed: true` · `deferred`(참거짓) · `identity_then`(그때의 정체 — 지금 정체와 다를 때만).
  - 새 거른 상태 `deferred-filtered`(넘겨받은 「잘못 골랐다」 가 새 일의 씨앗 · 재분해 신호이고 관찰이 같음).
  - `asked_before` 의 꼴 `<전 답> · <답한 때> · <열쇠 또는 정체> · <근거가 달라짐 | 고친 뒤에도 보임>`.
  - `changed_observation` 목록: 첫 항목은 화면 한 구절 — 리뷰어가 낸 `now_lines` 가운데 확인된 첫 줄(근거 파일 줄에서 앞의 `<번호>\t` 를 뗀 글)이 있으면 그것, 없으면 확인된 첫 `now_quotes` 의 `io_.quote_line` 글을 `_one_line` 으로 접어 `SNIPPET`(80)자를 넘으면 80자에서 자르고 「…」 를 붙인 것. 둘째 항목 `이전 관찰: <previous>`. 그 뒤 확인된 `now_lines` 의 근거 줄 전부와 확인된 `now_quotes` 의 `quote_line` 전부.
- 가르는 표(정체는 견주지 않는다 — `same_as` 가 넘겨받은 열쇠면 지금 질문이 정체를 가르지 못한 질문이어도 이 표대로 간다):

| `same_as` 가 가리킨 것 | 답 | 행선 | 리뷰어가 관찰이 달라졌다고 함(`_observation_changed`) | 결과 |
|---|---|---|---|---|
| 넘겨받은 열쇠 | 의도다 | `-` | 아니오 | `answered-filtered` |
| 넘겨받은 열쇠 | 의도다 | `-` | 예 | 묻는다 · 근거가 달라짐 |
| 넘겨받은 열쇠 | 잘못 골랐다 | 이 에픽 안에서 고친다 | 무관 | 묻는다 · 고친 뒤에도 보임(`changed_observation` 은 `-`) |
| 넘겨받은 열쇠 | 잘못 골랐다 | 새 일의 씨앗 · 재분해 신호 | 아니오 | `deferred-filtered` |
| 넘겨받은 열쇠 | 잘못 골랐다 | 새 일의 씨앗 · 재분해 신호 | 예 | 묻는다 · 근거가 달라짐 |
| 답 폴더의 정체(= 지금 정체) | 의도다 · 잘못 골랐다 | — | 아니오 | 지금 그대로(`answered-filtered` · `wrong-choice-filtered`) |
| 답 폴더의 정체(= 지금 정체) | 의도다 · 잘못 골랐다 | — | 예 | 묻는다 · 근거가 달라짐 |
| 그 밖(없는 열쇠 · 다른 정체 · 지금은 모르겠다) | | | | 거르지 않는다 · `asked_before` 는 `-` |

- 걸러진 것은 모두 `counts["answered"]` 에 세고 `answered_filtered` 가 그 수다. `NAMES_MISSING` 공시는 답 폴더 답으로 거른 것이 있을 때만 낸다(넘겨받은 항목엔 범위 표시가 없다).
- 결과 절의 `이미 답한 질문이라 거른 질문:` 줄 — 넘겨받은 항목은 `- <정체> · <앞 답> · <기록 파일 경로> · 넘겨받은 답[ · 미뤄 둔 의심][ · 정체가 다름 — <그때의 정체> → <지금 정체>] — <질문>`(범위 표시 없음). `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록에는 답 폴더의 `wrong-choice-filtered` 만 싣는다.

- [ ] **Step 1: 실패하는 테스트.**
  - `TestFilterHanded.test_one_run_covers_every_branch` — 리뷰어 출력 픽스처 하나에 질문 여덟을 둔다: (a) 의도다 · 관찰 같음 (b) 의도다 · 관찰 달라짐 (c) 잘못 골랐다 · 이 에픽 안에서 고친다 (d) 잘못 골랐다 · 새 일의 씨앗 · 관찰 같음 (e) 잘못 골랐다 · 재분해 신호 · 관찰 달라짐 (f) 정체가 같은 넘겨받은 항목 둘 가운데 둘째 열쇠만 가리킴 (g) 정체가 다른 넘겨받은 항목을 가리킴 (h) 없는 열쇠. 기대: 걸러짐 = a · d · f · g(`answered_filtered: 4`), 묻는 목록 = b · c · e · h. b · e 의 `asked_before` 넷째 칸이 `근거가 달라짐` 이고 `changed_observation` 첫 항목이 그 질문의 첫 근거 줄 글(번호 뗌), c 는 `고친 뒤에도 보임` 이고 `changed_observation` 이 `-`, h 는 `asked_before: "-"`. f 는 둘째 항목의 열쇠로 걸러진다(셋째 칸).
  - `test_handed_key_with_other_identity_filters_and_marks` — g 의 결과 절 줄에 `넘겨받은 답` · `정체가 다름 — <그때> → <지금>` 이 있고 범위 표시(`이 범위가 더한 답 파일`)가 없다. d 의 줄에 `미뤄 둔 의심` 이 있고 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록에는 없다.
  - `test_folder_answers_unchanged_and_asked_before` — 답 폴더의 「의도다」 · 관찰 같음은 지금처럼 걸러지고 범위 표시가 붙는다. 관찰 달라짐이면 묻고 `asked_before` 가 `의도다 · <answered_at> · <정체> · 근거가 달라짐`.
  - `test_snippet_cut_at_80` — 첫 근거 줄이 100자면 한 구절이 80자 + 「…」.
  - `TestReturnThree.test_contract_three_and_new_cells` — `render` 뒤 `intent-return.md` 의 `contract: 3`, 머리 끝 칸 `answered_filtered: 4`, 질문 칸 끝 `why` · `asked_before` · `changed_observation`. 리뷰어가 `why` 를 내지 않은 질문 · `why` 에 줄바꿈이 든 질문은 `why: "-"` 이고 그 질문이 남는다(AC6).
  - `test_all_filtered_still_counts` — 질문이 모두 걸러진 실행: `outcome` 이 `none`, `answered_filtered` 가 걸러진 수(AC7).
  - `test_intent_return.py` 의 판 단언을 3 으로, 칸 목록 단언에 새 칸을 더한다(`TestReturnDoc` 은 Task 7 의 문서와 함께 GREEN 이 된다 — 이 과제에서는 RED 로 남겨도 되고, 남겼으면 보고에 적는다).
- [ ] **Step 2: 돌려 실패를 본다.** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_intent_handed test_intent_return -v`.
- [ ] **Step 3: 구현.** `_prior(item: dict, ident: Optional[str], answered: dict, handed: dict, evidence: dict, wide: bool, tree_root: str) -> Optional[dict]` — 위 표를 그대로 옮기고 `{"state": <거른 상태 | None>, "asked_before": <글 | "-">, "changed": <목록 | "-">, "handed": <항목 | None>}` 를 낸다. `same_as` 가 넘겨받은 열쇠인지는 `handed` dict(열쇠 → 항목)에서 먼저 보고, 답 폴더는 지금처럼 `same == ident` 일 때만 본다(열쇠와 정체는 `#` 수가 달라 겹치지 않는다). `cmd_filter` 는 `intent-handed.yaml` 을 읽어 `handed` 를 만든다 — 파일이 없으면 `{}`, 읽지 못하면 `{}` 와 공시 `넘겨받은 답을 읽지 못함 — 꼴이 맞지 않음`. `_judge` 는 정체를 가르지 못한 질문에도 넘겨받은 열쇠를 본다. `why` 는 글이고 `"\n"` 이 없고 비지 않으면 `_one_line` 그대로, 아니면 `-`.
- [ ] **Step 4: 통과.** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_intent_handed test_intent_critic test_intent_wide -v` PASS. `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh` PASS. `bash shared/tests/test_adjudication_wiring.sh` PASS(컴프리헨션 수 그대로).
- [ ] **Step 5: 변이.** 커밋한 뒤 (c) 갈래를 관찰 같으면 거르게 · `deferred-filtered` 를 `wrong-choice-filtered` 로 · `CONTRACT = 2` 로 되돌리기마다 RED, 복원.
- [ ] **Step 6: 커밋.** `git commit -m "feat(qg): 넘겨받은 열쇠로 거르고 돌려주는 꼴을 3판으로 올린다" -- plugins/quality-gates/scripts/intent_critic.py plugins/quality-gates/tests/test_intent_handed.py plugins/quality-gates/tests/test_intent_return.py`

---

### Task 6: `--answered` 인자 받기

**AC:** AC9.

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh`(`--origin)` 갈래 옆 · `--help`), `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(L16 argument-hint · L127 인자 문단), `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(I2 펜스와 그 앞 자리 목록)
- Test: `plugins/quality-gates/tests/test_setup_qg.sh` · `plugins/quality-gates/tests/test_intent_critic_wiring.sh`(L62–63 곁)

**Interfaces:**
- Consumes: `prepare --answered`(Task 4).
- Produces: `setup-qg.sh` 가 `--answered <경로>` 의 값 하나를 소비하고 범위 인자로 세지 않는다. 값이 없거나 `-` 로 시작하면 `❌ --answered 뒤에 「이미 답한 것」 파일 경로가 없다.` rc 1. argument-hint: `"[branch|--paths <glob>...|range <시작>[..<끝>]] [--origin <경로>] [--answered <경로>]"`.

- [ ] **Step 1: 실패하는 테스트.** `test_setup_qg.sh` 의 `--origin` 블록(L208–216) 옆에 같은 꼴 — `--answered /tmp/x.yaml` 가 rc 0 · 모르는 인자로 읽지 않음 · 세션 폴더를 만듦, 범위 인자 하나 + `--answered` 셋 조합이 rc 0, 값 없는 `--answered` 가 rc 1 과 위 문구. `--help` 에 `--answered <path>` 줄. 인자 없는 호출은 지금 단언 그대로(AC9 「인자가 없는 호출의 동작은 바뀌지 않는다」 — 기존 케이스가 양의 짝). `test_intent_critic_wiring.sh` L62 의 꼴을 `'^argument-hint: ".*\[--origin <경로>\] \[--answered <경로>\]"$'` 로 바꾸고, L63 옆에 SKILL.md 문장 `` `--answered <경로>` 는 부른 쪽(지휘자)이 넘기는 「이미 답한 것」 파일의 절대 경로이고 범위 인자가 아니다. `` 단언과 reference I2 펜스에 `<<'QG_INTENT_ANSWERED'` · `A_ARGS=(--answered "$ANSWERED_ARG")` · `"${A_ARGS[@]}"` 가 있다는 단언을 더한다.
- [ ] **Step 2: 돌려 실패를 본다.** `bash plugins/quality-gates/tests/test_setup_qg.sh` · `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh`.
- [ ] **Step 3: 고친다.** `setup-qg.sh` 는 `--origin)` 갈래를 본떠 한 갈래를 더하고 `--help` 의 `--origin` 두 줄 뒤에 `  --answered <path>    Conductor's already-answered file for the intent critic (absolute path)`. SKILL.md 는 argument-hint 와 L127 문단 끝에 위 문장과 「쓰는 곳은 intent-critic 단계 I2 다.」 reference I2 는 자리 목록에 `- \`QG_INTENT_ANSWERED\` — 인자에 \`--answered <경로>\` 가 있었으면 그 경로를 글자 그대로, 없으면 빈 줄.` 을 더하고, 펜스의 `QG_INTENT_ORIGIN` heredoc 다음에 `QG_INTENT_ANSWERED` heredoc 과 `A_ARGS=(); [ -z "$ANSWERED_ARG" ] || A_ARGS=(--answered "$ANSWERED_ARG")`, `prepare` 줄 끝에 `"${A_ARGS[@]}"`. I2 의 공시 줄 목록에 `넘겨받은 답을 읽지 못함 — <사유>` 를 더한다.
- [ ] **Step 4: 통과.** 두 테스트 PASS. `bash -n plugins/quality-gates/scripts/setup-qg.sh`.
- [ ] **Step 5: 커밋.** `git commit -m "feat(qg): --answered 로 「이미 답한 것」 파일을 받는다" -- plugins/quality-gates/scripts/setup-qg.sh plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md plugins/quality-gates/tests/test_setup_qg.sh plugins/quality-gates/tests/test_intent_critic_wiring.sh`

---

### Task 7: qg 가 직접 묻는 틀과 계약 문서

**AC:** AC19 · AC7(문서 쪽) · AC20(상태 파일 형식 문서).

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md`(I5 의 질문 앞 글 · I7 의 돌려주는 꼴 설명 · 새 절 `## 넘겨받은 답`), `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`(L84 목록 꼴 · L118–128 칸)
- Test: `plugins/quality-gates/tests/test_intent_critic.py`(`class TestProcedureDoc`), `plugins/quality-gates/tests/test_intent_return.py`(`TestReturnDoc`)

**Interfaces:**
- Consumes: 새 칸 이름(Task 5) · 파일 꼴(Task 3).

- [ ] **Step 1: 실패하는 테스트.** `TestProcedureDoc` 에:
  - `test_direct_ask_front_text_shape` — I5 의 `**질문 (PR 범위 · k ≥ 1).**` 과 `AskUserQuestion(` 사이에 아래 펜스가 글자 그대로 한 번:

```text
<브랜치 이름> 리뷰
물을 것: <n>개[ · 전에 답해 묻지 않은 것 <m>개]

질문 <n> — <질문 문장>
  왜 묻나: <why>
  <「여기는 직접 확인해 보세요 — …」 줄 — 질문 글에 그 표지가 있을 때만>

자세히: <세션 폴더의 intent-questions.yaml 절대 경로>
답은 qg 판정을 바꾸지 않는다. 이유를 남기려면 직접 입력 칸에 「의도다 — 이유」 처럼 쓴다.
```

  - 같은 테스트에서 I5 에 「이 에픽이 하기로 한 것」 · `결과:` 가 없다(양의 짝: 위 펜스).
  - `test_meaning_is_shown_before_the_question_dialog` 를 뒤집는다 → `test_meaning_sentence_left_the_ask_template`: I5 의 앵커와 `AskUserQuestion(` 사이에 `MEANING` 이 0번, `이유를 남기려면 직접 입력 칸에` 가 홀로 선 줄로 없고 새 끝 줄의 뒷부분으로만 한 번(양의 짝: 끝 줄). `MEANING` 은 페르소나 · result.md 절에는 그대로 있다(그 테스트들은 손대지 않는다).
  - `test_direct_ask_question_is_one_sentence` 의 `outside[0].startswith("질문 창엔 ")` 단언을 새 끝 줄로 바꾼다 — 고친 단언을 보고에 적는다.
  - `test_why_rules_in_direct_ask` — I5 에 「왜 묻나」 채우기 규칙 셋: `why` 그대로 · `-` 면 `왜 묻나: 리뷰어가 적지 않았다` · `asked_before` 가 `-` 가 아니면 넷째 칸에 따라 `전에 「<답>」 라고 답하셨는데(<날짜>) 이번에는 <새로 보인 것> 가 보였다. ` 또는 `전에 「잘못 골랐다」 라고 답하셨다(<날짜>) — 고친 뒤에도 같은 의심이 보인다. ` 를 앞에 붙인다(<새로 보인 것> 은 `changed_observation` 의 첫 항목).
  - `test_handed_contract_section` — 새 절 `## 넘겨받은 답` 에 Task 3 의 YAML 꼴 펜스 · 키 여덟 · `contract: 1` · 사유 다섯 · 상한 1000000 바이트 · 「항목 하나라도 틀리면 파일 전체를 받지 않는다」.
  - `TestReturnDoc` 이 새 머리 칸 · 질문 칸을 문서에서 찾는다(state-file-format 의 `- 머리 칸(차례대로):` · `- 질문 칸(차례대로):` 줄 끝에 새 칸, `- \`contract\` — 꼴의 판(\`3\`).`, 새 칸의 뜻 줄).
- [ ] **Step 2: 돌려 실패를 본다.** `PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_intent_critic.TestProcedureDoc test_intent_return -v`.
- [ ] **Step 3: 고친다.** I5 의 「질문 창을 띄우기 바로 전에 이 줄을 글자 그대로 보인다」 와 그 인용 줄, 「질문 창엔 … 처럼 쓴다」 문단을 지우고 위 펜스와 채우는 법으로 바꾼다 — `<브랜치 이름>` 은 `git rev-parse --abbrev-ref HEAD` 의 값(분리된 HEAD 면 `HEAD <앞 8자>`), `<m>` 은 `intent-questions.yaml` 의 `counts.answered`(0 이면 괄호 몫을 싣지 않는다), `<질문 문장>` 과 직접 확인 줄은 지금의 표지 나누기 규칙 그대로. 의심하는 것 · 근거 줄 채우기 불릿은 지운다(화면에 싣지 않는다 — 파일에 있다). I7 의 「(2판)」 을 「(3판)」 으로, 칸 나열에 `answered_filtered` · `why` · `asked_before` · `changed_observation` 을, 「이미 답한 질문이라 거른 질문:」 불릿에 「넘겨받은 답 · 미뤄 둔 의심 · 정체가 다름 표시 포함」 을 더한다. 새 절 `## 넘겨받은 답`(I7 뒤)에 계약을 적는다. state-file-format 의 L84 목록 꼴에 넘겨받은 항목 줄 꼴(Task 5)을 더한다.
- [ ] **Step 4: 통과.** 같은 명령과 `python3 -m unittest test_intent_critic test_intent_return -v` 전부 PASS. `bash shared/tests/test_ask_recommendation.sh` 가 그대로 PASS(I5 의 질문 자리 앵커를 지키는지).
- [ ] **Step 5: 변이.** 커밋한 뒤 옛 고정 문장(`> intent-critic 은 의도대로 …`) 되살리기 · 끝 줄 지우기 · 「왜 묻나」 줄과 질문 줄 차례 바꾸기마다 RED, 복원.
- [ ] **Step 6: 커밋.** `git commit -m "feat(qg): 직접 묻는 틀을 질문 문장 먼저 · 왜 묻나 한 줄로 바꾼다" -- plugins/quality-gates/skills/quality-pipeline/references/intent-critic.md plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md plugins/quality-gates/tests/test_intent_critic.py plugins/quality-gates/tests/test_intent_return.py`

---

### Task 8: 합치기 전 지적 목록 파일

**AC:** AC21(스크립트 · qg 본문 쪽).

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`(`main` 인자 · 쓰기 한 자리 · 머리 독스트링 입력 목록), `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(Step 4 합성 펜스 · 「되올려 다시 합성하기」)
- Create: `plugins/quality-gates/tests/test_synthesize_pre_merge.py`(`class TestPreMergeOut(unittest.TestCase)` — 픽스처 만드는 길은 `test_synthesize_lowered.py` 를 본뜬다)

**Interfaces:**
- Produces: `synthesize_findings.py … --pre-merge-out <경로>` — 재비판 처분(`apply_verdicts`)과 추가 지적(`promote_new_findings`)을 반영한 뒤 · `dedup` 앞의 목록(`findings + promoted` 를 `sort_findings` 차례로)을 `yaml.safe_dump({"findings": <목록>}, allow_unicode=True, sort_keys=False)` 로 쓴다(tmp 에 쓰고 `os.replace`). 항목은 받은 칸 그대로(`file` · `line` · `severity` · `summary` · `plain` · `proposed_fix` · `lowered` · `lowered_from` · `lowered_reason` · `promoted` …). 쓰지 못하면 stderr 한 줄 `[synthesize_findings] 합치기 전 목록을 쓰지 못했다 — <예외 이름>` 을 내고 rc 와 stdout 은 그대로. 빈 글 값은 다른 경로 인자처럼 usage 오류(rc 2). 세션 폴더의 이름은 `findings-pre-merge.yaml`.

- [ ] **Step 1: 실패하는 테스트.**
  - `test_written_before_dedup` — 같은 `file:line` · 같은 심각도의 지적 둘(합쳐지는 쌍)과 재비판이 하나를 `lower` 한 픽스처: 파일의 `findings` 가 셋이고 합쳐지는 둘이 따로 있으며, 낮춘 것은 `severity: SUGGESTION` · `lowered: true`.
  - `test_does_not_change_verdict` — 같은 입력으로 인자 있이 · 없이 돌린 stdout 이 바이트로 같고 rc 가 같다(AC21 「판정과 합치기의 동작은 바꾸지 않는다」).
  - `test_unwritable_keeps_rc` — 쓸 수 없는 경로(없는 폴더 아래)면 stderr 에 위 줄, rc 0 · stdout 그대로.
  - `test_empty_is_usage` — `--pre-merge-out ""` 가 rc 2.
  - `test_skill_fences_pass_it` — SKILL.md 의 Step 4 펜스와 「되올려 다시 합성하기」 문단에 `--pre-merge-out "$RD/findings-pre-merge.yaml"` 이 있다(각 한 번), Step 3.9 의 `synth-review` 펜스에는 없다.
- [ ] **Step 2: 돌려 실패를 본다.** `cd plugins/quality-gates/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_synthesize_pre_merge -v`.
- [ ] **Step 3: 구현.** 인자는 `ap.add_argument("--pre-merge-out", default=None)` 이고 빈 글 검사 목록에 더한다. 쓰기는 `findings = sort_findings(dedup(...))` 줄 바로 앞, 판정 계산 전이다. 컴프리헨션 · `break` · `continue` 를 더하지 않는다. SKILL.md Step 4 펜스의 `--emit-verdict --angles "$RV/angles.txt" \` 줄 다음에 `  --pre-merge-out "$RD/findings-pre-merge.yaml" \` 를 넣고, 「되올려 다시 합성하기」 는 「위 펜스를 같은 판정 입력 그대로」 다시 돌리므로 같은 파일을 덮는다고 한 문장 더한다.
- [ ] **Step 4: 통과.** 그 테스트와 `bash plugins/quality-gates/tests/test_synthesize_findings.sh` · `python3 -m unittest test_synthesize_lowered` · `bash shared/tests/test_adjudication_wiring.sh` PASS.
- [ ] **Step 5: 커밋.** `git commit -m "feat(qg): 합치기 전 지적 목록을 세션 폴더에 남긴다" -- plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/test_synthesize_pre_merge.py`

---

### Task 9: 다른 팀 읽기가 리뷰 기록을 싣지 않는다

**AC:** AC18.

**Files:**
- Modify: `plugins/quality-gates/scripts/other_teams.py`(`_intent_docs` · `collect`)
- Create: `plugins/quality-gates/tests/test_other_teams_review_records.py`

**Interfaces:**
- Produces: `_intent_docs(repo, entry, markers, unverified, skipped: List[int]) -> List[tuple]` — 읽은 문서의 `io_.frontmatter_value(text, "type") == "roadmap-review"` 면 싣지 않고 `skipped[0] += 1`. `collect` 가 그 수가 0 이 아니면 기록 끝(`LINE_SIBLINGS` 줄 자리 다음, `## 상한` 앞)에 `LINE_REVIEW_RECORDS = "리뷰 기록 %d개는 다른 팀 근거로 싣지 않았다"` 한 줄을 싣는다.

- [ ] **Step 1: 실패하는 테스트.** `class TestReviewRecordsSkipped(unittest.TestCase)` — `setUp` 에서 임시 리포: `main` 에 첫 커밋, `refs/remotes/origin/main` 과 `refs/remotes/origin/HEAD`(심볼릭 → `refs/remotes/origin/main`), 브랜치 `feature/x` 에 `docs/r/reviews/2026-11-22-R1-spec.md`(머리 `type: roadmap-review` · `roadmap: docs/r/roadmap.md`, 본문에 `MARK-REVIEW`)와 `docs/r/specs/x-design.md`(머리 `roadmap: docs/r/roadmap.md`, 본문 `MARK-DESIGN`). `ot.collect(repo, repo, "main", set(), [], list(io_.DEFAULT_MARKERS), 80000, list_prs=lambda r: ([], None))` 의 `text`:
  - `test_review_record_not_loaded` — `MARK-DESIGN` 있음 · `MARK-REVIEW` 없음 · `리뷰 기록 1개는 다른 팀 근거로 싣지 않았다` 한 번.
  - `test_no_line_without_records` — 리뷰 기록을 뺀 같은 리포에서는 그 줄이 없다(양의 짝: `MARK-DESIGN`).
  - `test_other_roadmaps_records_too` — 다른 로드맵 폴더(`docs/q/reviews/…`)의 리뷰 기록도 빠진다(D18).
  - `test_branch_still_listed` — 리뷰 기록만 바꾼 브랜치는 「그 밖의 브랜치 … — 겹침 · 의도 문서 없음」 에 세인다(브랜치 자체는 다른 작업 목록에서 빠지지 않는다).
- [ ] **Step 2: 돌려 실패를 본다.** `cd plugins/quality-gates/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_other_teams_review_records -v`.
- [ ] **Step 3: 구현.** `collect` 에 `review_records = [0]` 을 두고 `_intent_docs` 에 넘긴다(`test_other_teams.py` L873–880 의 `mock.patch.object(ot, "_intent_docs", …)` 가 새 인자를 받게 그 가짜 함수 시그니처도 맞춘다).
- [ ] **Step 4: 통과.** 새 파일과 `python3 -m unittest test_other_teams -v` PASS.
- [ ] **Step 5: 커밋.** `git commit -m "fix(qg): 다른 팀 읽기가 리뷰 기록 파일을 의도 문서로 싣지 않는다" -- plugins/quality-gates/scripts/other_teams.py plugins/quality-gates/tests/test_other_teams_review_records.py plugins/quality-gates/tests/test_other_teams.py`

---

### Task 10: qg README · CHANGELOG · 판

**AC:** AC20(qg 쪽).

**Files:**
- Modify: `plugins/quality-gates/README.md` · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json`
- Test: `plugins/quality-gates/tests/test_intent_critic_wiring.sh`(README 단언 곁)

- [ ] **Step 1: 실패하는 테스트.** README 에 `--answered <경로>` 의 뜻 한 문장 · 「돌려주는 꼴 3판」 과 새 칸 넷의 이름 · 직접 묻는 틀이 질문 문장 먼저라는 문장 · 합치기 전 지적 목록 파일 이름 `findings-pre-merge.yaml` 이 있다는 단언(README 에만 있는 글자로 — 설계문서 낱말을 그대로 옮긴 문장은 쓰지 않는다).
- [ ] **Step 2: 돌려 실패를 본다.** `bash plugins/quality-gates/tests/test_intent_critic_wiring.sh`.
- [ ] **Step 3: 고친다.** `plugin.json` 을 `17.0.0` 으로. CHANGELOG 맨 위 `## [17.0.0] — <커밋 날짜>`: Changed(돌려주는 꼴 3판 — 2 만 읽는 쪽은 깨진다 · 직접 묻는 틀 · 다른 팀 읽기가 `type: roadmap-review` 문서를 뺌), Added(`--answered` · `why` · `asked_before` · `changed_observation` · `answered_filtered` · `--pre-merge-out`). README 의 intent-critic 절 · 인자 표 · 세션 폴더 파일 목록에 위를 더한다. `Principles Instantiated` 는 손대지 않는다.
- [ ] **Step 4: 통과.** 그 테스트, `bash shared/tests/test_changelog_integrity.sh`, `bash plugins/quality-gates/tests/test_plain_readme.sh` PASS.
- [ ] **Step 5: 커밋.** `git commit -m "docs(qg): 17.0.0 — 돌려주는 꼴 3판과 --answered 를 적는다" -- plugins/quality-gates/README.md plugins/quality-gates/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/tests/test_intent_critic_wiring.sh`

---

### Task 11: 「이미 답한 것」 을 만드는 스크립트

**AC:** AC13 · AC14.

**Files:**
- Create: `plugins/spec-distill/scripts/qg_answered.py` · `plugins/spec-distill/tests/test_qg_answered.py`

**Interfaces:**
- Consumes: qg 의 `intent_answers.read_handed`(이음매 테스트만 — 레포 안에서 경로로 import).
- Produces: `python3 qg_answered.py --roadmap <로드맵 파일의 레포 상대경로> --ref <ref> [--ref <ref> …] --out <파일> --notices <파일> [--repo <레포 루트, 기본 .>]`.
  - `--ref` 의 차례가 앞섬이다 — 지휘자는 `origin/HEAD` → `origin/<기록 브랜치>`(있으면) → 열린 에픽 브랜치마다 로컬 `<에픽 브랜치>` 로 준다.
  - 자리마다 `git ls-tree --name-only <ref> -- <로드맵 폴더>/reviews/` 의 `.md` 마다 `git show <ref>:<경로>` 로 읽는다(git 은 인자 목록으로, `timeout`). ref 를 풀지 못하면 그 자리를 `읽지 못한 기록` 에 `<ref>:<로드맵 폴더>/reviews/` 로 센다.
  - 기록 파일 하나 = 머리(YAML, `type: roadmap-review` 이고 `contract` 가 2 또는 3)와 `## 질문 <n>` 절들. 절의 줄: `- 정체:` · `- 질문:` · `- 관찰:`(아래 두 칸 들여 쓴 줄들 — 들여쓰기를 떼고 `\n` 으로 잇는다) · `- 전에 한 답:` · `- 답:` · `- 행선:` · `- 답한 때:`. 머리 · 절 머리 · 칸 이름은 문자열 메서드로 본다(`re.compile` 금지 — Global Constraints).
  - 싣는 것: `- 답:` 값이 글자로 `의도다` 또는 `잘못 골랐다`(`startswith` 가 아니라 같음)인 절. 열쇠 `<파일 이름>#<n>`. `record` 는 `<로드맵 폴더>/reviews/<파일 이름>`. `route` 는 `잘못 골랐다` 면 `- 행선:` 값, 그 줄이 없는 2판이면 머리 `site:` 로 — `spec` · `premerge` · `recheck` → `이 에픽 안에서 고친다`, `end` → `새 일의 씨앗`, `asked` → `이 에픽 안에서 고친다`(가를 수 없어 다시 묻는 쪽). `의도다` 면 `-`.
  - 빼는 것: 어느 기록이든 `- 전에 한 답:` 값(`없음` 이 아니면 ` · ` 로 나눈 넷째 칸 가운데 셋째 칸)이 가리키는 열쇠의 항목. 시각으로 견주지 않는다.
  - 같은 열쇠가 여러 자리에서 읽히면 내용(열쇠 밖 칸 일곱)이 같으면 한 번, 다르면 앞 자리 것을 싣고 그 수를 센다.
  - 읽지 못한 기록 파일로 세는 것: `git show` 실패 · UTF-8 아님 · 머리가 없거나 YAML 아님 · `type` 이 다름 · 판이 2 · 3 밖 · `- 전에 한 답:` 값이 `없음` 도 네 칸도 아님 · 칸 값에 제어 글자(`\t` 밖의 C0 · DEL)가 있음 · 절 번호가 ASCII 숫자가 아님. 그 파일의 항목은 하나도 싣지 않는다.
  - 출력: `--out` 에 Task 3 의 꼴(`contract: 1` · `entries`, 답이 없으면 `entries: []`)을 tmp + `os.replace` 로. `--notices` 에 알림 줄(없으면 빈 파일): `읽지 못한 기록 <n>개: <경로들 ` · ` 로>` · `열쇠가 같은데 내용이 다른 기록 <n>개`. 같은 줄을 stderr 에도 낸다. 종료 코드 0 정상(알림이 있어도) · 2 사용법(`--ref` 없음 · `--roadmap` 이 `/` 로 시작 · `..` 포함) · 3 출력 파일을 쓰지 못함(stderr 한 줄).

- [ ] **Step 1: 실패하는 테스트.** `class TestQgAnswered(unittest.TestCase)` — 임시 리포에 `main`(2판 기록 `2026-11-22-R4-spec.md`: 질문 1 의도다 · 질문 2 지금은 모르겠다 · 질문 3 잘못 골랐다, 머리 `site: spec` — 픽스처 꼴은 `docs/superpowers/roadmaps/2026-11-14-qg-epic-roadmap-intent-review-brief/reviews/2026-11-22-R4-spec.md` 에서 뜬다), `feature/rec`(3판 기록 둘), `feature/epic`(같은 이름의 기록, 질문 1 의 관찰만 다름).
  - `test_two_and_three_contract_records` — 2판 · 3판 모두 읽힌다. 2판 질문 2 는 실리지 않고, 질문 3 의 `route` 가 `이 에픽 안에서 고친다`. 3판의 `- 행선: 새 일의 씨앗` 이 그대로 온다. 열쇠가 `2026-11-22-R4-spec.md#1` 꼴.
  - `test_site_routes_for_contract_two` — `site:` 다섯 값의 2판 「잘못 골랐다」 가 위 표대로 간다.
  - `test_later_record_supersedes_by_key` — 3판 기록의 `- 전에 한 답: 의도다 · 2026-11-22 21:25 · 2026-11-22-R4-spec.md#1 · 근거가 달라짐` 이 있으면 `#1` 항목이 빠지고 새 기록의 항목은 실린다.
  - `test_same_key_different_content_prefers_first_ref` — `--ref main --ref feature/epic` 이면 `main` 의 관찰이 실리고 알림 파일 · stderr 에 `열쇠가 같은데 내용이 다른 기록 1개`. 내용이 같으면 한 번만 실리고 알림이 없다.
  - `test_unreadable_record_counted_not_dropped` — 머리 YAML 이 깨진 파일 · 판 4 · 풀 수 없는 `--ref nope` 이 `읽지 못한 기록 3개: …` 한 줄(경로 셋)이고 다른 파일의 항목은 실린다.
  - `test_no_answers_writes_empty_list` — 기록이 없는 로드맵이면 `entries: []` 인 파일과 빈 알림 파일, rc 0.
  - `test_untrusted_text_is_data`(AC14) — 정체 · 질문 글에 `$(touch PWNED)` · `` `id` `` · `"; rm -rf ~ #` · `\n## 질문 9` 흉내(같은 줄 안의 글자) · `- 답: 의도다` 흉내가 든 기록: 스크립트가 돈 뒤 작업 폴더에 `PWNED` 가 없고, 그 글이 출력 YAML 에 글자 그대로 있으며, 흉내 낸 절 · 답이 항목으로 늘지 않는다. 칸에 `\x1b` 가 든 기록은 읽지 못한 기록으로 세인다.
  - `test_usage_errors` — `--ref` 없음 · `--roadmap /abs` · `--roadmap a/../b` 가 rc 2. 쓸 수 없는 `--out` 이 rc 3.
  - `test_qg_reads_what_we_write`(이음매) — 이 스크립트가 쓴 파일을 `plugins/quality-gates/scripts` 를 `sys.path` 에 넣어 import 한 `intent_answers.read_handed` 가 `why is None` 으로 읽고 항목 수 · 열쇠가 같다.
- [ ] **Step 2: 돌려 실패를 본다.** `cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_answered -v`.
- [ ] **Step 3: 구현.** 독스트링 첫머리에 사용 · 출력 · 종료 코드(merged_pr_range.py 의 꼴). git 하위 명령은 `rev-parse` · `ls-tree` · `show` 만 허용 목록으로. 쓰기는 `yaml.safe_dump(..., allow_unicode=True, sort_keys=False)`. `adjudication` 을 import 하지 않는다.
- [ ] **Step 4: 통과.** 같은 명령 PASS. `bash shared/tests/test_python_floor.sh` · `python3 -m unittest plugins/quality-gates/tests/test_utf8_explicit.py` · `bash plugins/spec-distill/tests/test_check_brief.sh` · `bash shared/tests/test_no_new_duplication.sh` PASS.
- [ ] **Step 5: 커밋.** `git commit -m "feat(spec-distill): 리뷰 기록에서 「이미 답한 것」 파일을 만드는 스크립트" -- plugins/spec-distill/scripts/qg_answered.py plugins/spec-distill/tests/test_qg_answered.py`

---

### Task 12: 지휘 절차 — 호출 줄 · 담당자 글 · 돌아왔을 때 · 이미 답한 것 · 되돌리기

**AC:** AC8 · AC15 · AC21(문서 쪽) · AC22.

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`(`## 호출 줄` · `### 한 박자` · `### 이미 보낸 것` 1 · `### 보내는 글` · `### 보내기` · `## 돌아왔을 때` · `### 같은 대상에 전에 물은 것` → `### 이미 답한 것` · `### 이름으로 청함` · `## 되돌리기` · `## 「잘못 골랐다」 의 행선` 머지 앞)
- Create: `plugins/spec-distill/tests/test_qg_review_readable.sh`(100755)
- Modify: `plugins/spec-distill/tests/test_qg_review_reference.sh`

**Interfaces:**
- Consumes: `qg_answered.py` CLI(Task 11) · `--answered`(Task 6) · `contract: 3`(Task 5) · `findings-pre-merge.yaml`(Task 8).

- [ ] **Step 1: 실패하는 락.** `test_qg_review_readable.sh`(머리는 `test_qg_review_reference.sh` 의 `sec` · `ssec` · `once` · `starts` 도우미를 본뜬다 — 두 파일에 같은 20줄 블록이 생기지 않게 다르게 짠다) 에 아래 락. 이름은 단언 메시지 머리다.
  - `call-line-answered` — `## 호출 줄` 에 `/quality-gates:quality-pipeline range <시작 커밋>..<끝 커밋> --origin <원문 파일의 레포 상대경로> --answered <「이미 답한 것」 파일의 절대경로>` 한 번, 파일 전체의 `quality-pipeline range` 가 한 번.
  - `old-qg-retry-once` — `### 보내는 글` 펜스에 `qg 가 \`--answered\` 를 모르는 인자라고 멈추면 그 인자와 값을 뺀 같은 줄로 한 번만 다시 부르고, 마지막 보고 첫머리에 「답 이어지기 없이 돌았다 — 깔린 quality-gates 가 \`--answered\` 를 모른다」 를 적는다.` 한 번(AC8 · AC15 의 담당자 쪽 — 호출 줄 락과 따로).
  - `back-contract-3` — `## 돌아왔을 때` 에 `` `contract` 가 `3` 이 아니면 `` 한 번 · `` `contract` 가 `2` 가 아니면 `` 0번.
  - `answered-script-order` — `### 한 박자` 의 차례 문장에 `보관 폴더 만들기와 \`## 자원\` 에 적기` → `「이미 답한 것」 파일 만들기` → `보내기` 차례. `### 이미 답한 것` 에 `qg_answered.py --roadmap <로드맵> --ref origin/HEAD` · `--out <보관 폴더>/qg-answered.yaml --notices <보관 폴더>/qg-answered-notices.txt` · 세 자리(`` `origin/HEAD`(기본 브랜치) `` · `` `origin/<기록 브랜치>` `` · `열린 에픽 브랜치마다 로컬 \`<에픽 브랜치>\``)와 그 차례 · rc 2 면 부른 꼴을 고쳐 다시 · rc 3 이면 stderr 줄을 보이고 그대로 보낸다(qg 가 「넘겨받은 답을 읽지 못함 — 없음」 으로 알린다).
  - `self-filter-gone` — 파일에 `지휘자는 스스로 거르지 않는다 — 거르는 곳은 qg 한 곳이다.` 한 번. 부재 셋: `같은 대상에 전에 물은 것이 있어도 질문은 띄운다` · `돌아온 질문은 거르지 않는다` · `### 같은 대상에 전에 물은 것`(양의 짝: 앞 문장과 `### 이미 답한 것` 머리).
  - `report-only-wrong-list` — `### 보내는 글` 의 마지막 보고 줄에 `` `이미 「잘못 골랐다」 답이 있어 거른 질문:` `` 이 있고 `` `이미 답한 질문이라 거른 질문:` `` 이 없다. 머지 앞 행선 불릿이 그 목록을 읽는 문장이 그대로 한 번.
  - `pre-merge-file` — 보내는 글이 `findings-pre-merge.yaml` 을 보관 폴더로 셸 복사하고 마지막 보고의 지적 목록을 그 파일에서 싣는다 · 지적마다 묶음(막는 지적 · 제안 · 낮춘 지적) · 쉬운 한 문장(`plain`, 없으면 `summary`) · 파일 · 막는 지적엔 고치는 법(`proposed_fix`)의 첫 문장 · 낮춘 지적엔 원래 심각도(`lowered_from`)와 낮춘 이유(`lowered_reason`)의 첫 문장 · 새로 깨진 테스트는 result.md 의 `### 차등 회귀` 에서 「새로 깨진 테스트: <테스트 이름>」 으로. `## 되돌리기` 에 `지적마다의 처리는 합쳐지기 전 지적 목록 파일(\`findings-pre-merge.yaml\`)의 항목 하나를 단위로 센다` 한 번. [Q2 고치면: 보내는 글에 「세션 폴더에 그 파일이 없으면 qg 의 고칠 목록(result.md 의 `### 막는 지적` · `### 제안` · `## 낮춘 지적`)에서 싣고 마지막 보고 첫머리에 「합쳐지기 전 목록 없이 실었다 — 같은 줄의 지적이 하나로 합쳐졌을 수 있다」 를 적는다」 한 번, `## 되돌리기` 에 그때는 그 목록의 행을 단위로 센다는 문장 한 번.] [Q3 세지 않는다: 보내는 글에 「`lowered: true` 인 항목은 낮춘 지적 묶음에만 싣는다」 한 번.]
  - `degrade-lines-verbatim` — 보내는 글의 마지막 보고에 「qg 가 무엇이 빠지거나 줄어든 채 돌았다고 알린 줄(넘겨받은 답을 읽지 못함 · 리뷰어나 codex 가 돌지 못함 · 재비판이 돌지 못함 같은 줄)을 글자 그대로」 한 번.
  - `asked-then-recheck` — `## 되돌리기` 에 `구현이 끝난 머지 전 에픽을 이름으로 청해 본 리뷰(\`asked\`)가 막는 지적을 내 되돌린 뒤의 좁은 재리뷰는 \`recheck-pr<번호>\` 로 보내고 그 PR 의 「두 번까지」 에 센다. 그 뒤 자동 머지 앞 리뷰는 \`premerge-pr<번호>\` 로 평소대로 한 번 보낸다 — 이름으로 청한 리뷰는 그 횟수에 세지 않는다.` 한 번(AC22).
  - `recheck-intent-answered` — `- **좁은 재리뷰의 의도 점검.**` 불릿이 「호출 줄은 첫 리뷰와 같은 꼴이라(`--answered` 포함)」 와 「근거가 같으면 다시 묻지 않는다」 를 담는다.
  - 옛 락 고치기 — `test_qg_review_reference.sh` 에서 이 과제가 바꾼 문장을 묶은 단언을 새 문장으로 옮기거나 지운다. 알려진 것: L60 `DLINE`(처분 줄) · L57 의 `낮춘 지적 표 전부(위치 · 원래 심각도 · 내용 · 낮춘 이유)` · L135–136 `L_prior` · L182–206 의 AC9 블록 전부(찾는 명령 · 정체 파일 펜스 · `origin/<에픽 브랜치>` 부재는 `### 이미 답한 것` 의 세 자리 단언으로 옮긴다) · L263 `contract` 2 · L299 `L_sent2`(가리키는 절 이름을 `### 이미 답한 것` 으로) · L483 `L_lastfix` · L489–495 거른 목록 둘을 보내는 글에서 찾는 반복(둘째 머리는 부재로) · L602–606 `recheck-intent-not-filtered`. 옮긴 단언마다 메시지 앞에 `R6:` 를 붙인다. 다 고친 뒤 `bash plugins/spec-distill/tests/test_qg_review_reference.sh` 의 RED 메시지를 모두 읽어 이 목록 밖이 남았는지 본다 — 남았으면 그 단언이 무엇을 지키는지 읽고 옮기거나, 옮길 수 없으면 멈추고 보고한다.
- [ ] **Step 2: 돌려 실패를 본다.** `chmod +x plugins/spec-distill/tests/test_qg_review_readable.sh && bash plugins/spec-distill/tests/test_qg_review_readable.sh`.
- [ ] **Step 3: 고친다.** 락의 글자대로. 지우는 `### 같은 대상에 전에 물은 것` 의 세 자리 문장은 `### 이미 답한 것` 으로 옮겨 `### 이미 보낸 것` 1 의 「(아래 `### 이미 답한 것` 의 읽는 자리 셋)」 이 가리킨다. 처분 줄은 `**처분** — consumer=orchestrator · fail-closed · disclosure=담당자가 돌려준 판정 결과 · 지적 목록 · 의도 점검 결과와 질문을 그 자리 이름과 함께 결과 글 · 질문 블록의 틀로 사용자에게 보이고, 판정 줄 원문 · 공시 줄 · 거른 질문 목록은 보관 폴더의 파일로 가리킨다` 로, 그 아래 「돌아오면 …」 문단을 같은 뜻으로 고친다(빠진 채 돌았다는 알림 줄은 화면에 남긴다). `## 돌아왔을 때` 2 의 판을 3 으로. 머지 앞 행선 불릿의 「담당자 보고에 `이미 「잘못 골랐다」 답이 있어 거른 질문:` 목록이 있으면」 은 그대로 둔다(이 목록만 보고에 남는다).
- [ ] **Step 4: 통과.** 두 락 PASS. `bash shared/tests/test_dispatch_disposition.sh` · `bash shared/tests/test_ask_recommendation.sh` · `bash plugins/spec-distill/tests/test_repo_literals.sh` · `bash shared/tests/test_skill_reference_pointers.sh` · `bash plugins/spec-distill/tests/test_conducting_reference.sh` PASS. `git ls-files -s plugins/spec-distill/tests/test_qg_review_readable.sh` 가 `100755`.
- [ ] **Step 5: 변이.** 커밋한 뒤 `old-qg-retry-once` 문장 지우기 · `--answered` 를 호출 줄에서 지우기 · `같은 대상에 전에 물은 것이 있어도 질문은 띄운다` 되살리기 · `asked-then-recheck` 의 `recheck-pr` 를 `premerge-pr` 로 바꾸기마다 RED, 복원.
- [ ] **Step 6: 커밋.** `git commit -m "feat(spec-distill): 지휘자가 지난 답을 qg 에 넘기고 판 3 만 읽는다" -- plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/spec-distill/tests/test_qg_review_readable.sh plugins/spec-distill/tests/test_qg_review_reference.sh`

---

### Task 13: 지휘 절차 — 화면의 틀과 기록 틀

**AC:** AC1 · AC2 · AC3 · AC4 · AC16 · AC17.

**Files:**
- Modify: `plugins/spec-distill/skills/epic-conductor/references/qg-review.md`(`### 낮춘 지적` · `### 판정과 코드 리뷰 지적` → `### 결과 글` · `## 묻기` 의 앞 글 · `### 기록 파일`), `plugins/spec-distill/skills/epic-conductor/SKILL.md`(`## 보이기` 의 qg 질문 문장)
- Modify: `plugins/spec-distill/tests/test_qg_review_readable.sh` · `plugins/spec-distill/tests/test_qg_review_reference.sh`

**Interfaces:**
- Consumes: 돌려주는 꼴 3판의 칸(Task 5) · 알림 파일 `qg-answered-notices.txt`(Task 11 · 12) · 담당자 보고의 목록(Task 12).
- 틀(설계 §1–§3 의 글자 그대로 — 문서에 펜스로 싣는다):

```text
<대상 이름> — <자리의 쉬운 이름> 리뷰
이 에픽이 하기로 한 것: <로드맵 에픽 블록의 의도 줄 그대로>
결과: <막는 지적 n개 · 제안 n개 · 낮춘 지적 n개 | 막는 지적 없음 · …>
물을 것: <n개 | 없음>[ · 전에 답해 묻지 않은 것 <m>개]
```

```text
질문 <n> — <질문 문장>
  왜 묻나: <why>
  <「여기는 직접 확인해 보세요 — …」 줄 — 질문 글에 그 표지가 있을 때만>

자세히: <기록 파일 또는 보관 파일의 경로>
답은 qg 판정을 바꾸지 않는다. 이유를 남기려면 직접 입력 칸에 「의도다 — 이유」 처럼 쓴다.
```

```text
<맥락 머리 네 줄>
다음: <지금 일어나는 일 한 문장>

막는 지적
1. <그 지적의 쉬운 한 문장> (<파일>)
   고치는 법: <고치는 법의 첫 문장>
제안
3. <그 지적의 쉬운 한 문장> (<파일>)
낮춘 지적
6. <그 지적의 쉬운 한 문장> (<파일>) — 원래 <심각도>, 낮춘 이유: <한 구절>
자세히: <보관 폴더의 result.md 경로>
```

- 규칙(문서에 불릿으로): 「다음」 줄은 그 자리에서 지휘자가 하는 일 한 문장(예는 설계 §3 의 셋 — 「막는 지적을 구현 담당자에게 돌려보냈다 — 고친 부분만 다시 본다」 · 「막는 지적이 없어 머지 전 확인으로 간다」 · 「아래 질문 2개를 먼저 묻는다」) · 자리의 쉬운 이름 다섯(`spec` 「설계 승인 앞」 · `premerge` 「머지 앞」 · `recheck` 「머지 앞 — 고친 부분만」 · `end` 「로드맵 끝」 · `asked` 「이름으로 청함」) · 의도 줄은 로드맵 에픽 블록 `- 의도:` 줄 글자 그대로(로드맵 리뷰는 「이 로드맵이 하기로 한 것」 과 로드맵 제목) · 결과 개수는 담당자 보고 목록에서 세고 판정 줄 수를 쓰지 않음 · 막는 지적 = 막는 지적 + 새로 깨진 테스트(「막는 지적 n개(새로 깨진 테스트 k개 포함)」, 그 줄은 「새로 깨진 테스트: <테스트 이름>」 · 고치는 법 줄 없음) · `not-certified` 면 결과 줄 끝 「 · 인증 못 함(<사유 글자 그대로>)」 · 셀 수 없음이면 결과 줄 전체 「셀 수 없음 — <사유 문장>」 과 「물을 것」 줄 없음 [Q1 고치면: 그 셋은 개수를 쓰고 끝에 「 · 의도 점검은 셀 수 없음(<사유>)」, 전체 「셀 수 없음」 은 담당자가 돌아오지 않은 경우만] · 「전에 답해 묻지 않은 것」 은 `answered_filtered` 에서, 0 이면 붙이지 않음 · 맥락 머리 바로 아래에 담당자 보고의 빠진 채 돈 알림 줄과 알림 파일 `qg-answered-notices.txt` 의 줄을 글자 그대로 · 「왜 묻나」 채우기(Task 7 의 세 규칙과 같은 글자) · 화면에 싣지 않는 것(의심하는 인용 · 근거 줄 · 근거의 종류 · 정체 · 전에 물은 것의 질문 글) · 번호는 세 묶음을 이어서 · 쉬운 한 문장은 `plain`, 없으면 `summary`, 지휘자가 다시 쓰지 않음 · 낮춘 이유 한 구절은 `lowered_reason` 의 첫 문장 · 지적이 없고 질문만이면 맥락 머리 뒤 바로 질문 블록, 지적도 질문도 없으면 맥락 머리와 「다음」 줄이 전부 [Q4 고치면: 그때도 끝에 `자세히: <보관 폴더의 result.md 경로>`] · 지적과 질문이 함께면 한 메시지에 결과 글 먼저 · 맥락 머리 한 번 · `자세히` 경로는 기록 파일에 그 리뷰의 `## 질문` 절이 이미 있으면 그 경로, 아니면 보관 폴더의 절대 경로(로드맵 끝 · 이름으로 청한 로드맵처럼 머리만 먼저 커밋된 기록 파일은 아니다).
- 기록 틀(`### 기록 파일` 펜스)의 바뀌는 줄: `contract: 3` · `- 질문: <question>` 다음 `- 왜 묻나: <why>` · `- 같은 대상에 전에 물은 것: …` → `- 전에 한 답: <asked_before 그대로 | 없음>` · `- 답:` 줄 다음 `- 행선: <이 에픽 안에서 고친다 | 새 일의 씨앗 | 재분해 신호 — 답이 「잘못 골랐다」 일 때만>` [Q5 고치면: `- 전에 한 답:` 다음 `- 달라진 관찰:` 과 그 아래 두 칸 들여 쓴 `changed_observation` 줄들 — 없으면 그 줄을 쓰지 않는다]. 펜스 아래 불릿: 행선은 지휘자가 그 답을 보낸 길(「재분해 신호」 는 범위를 넘거나 구현 중인 에픽이라 재분해로 보인 경우) · `- 질문:` · `- 답:` · `- 답 원문:` 줄 이름과 자리 글자는 바꾸지 않는다(걸음 5 「승인 기록 다시 보이기」 가 읽는다) · 2판 기록은 고치지 않고 `qg_answered.py` 가 읽는다.

- [ ] **Step 1: 실패하는 락.** `test_qg_review_readable.sh` 에:
  - `context-head`(AC1) — `## 묻기` 와 `### 결과 글` 이 가리키는 맥락 머리 펜스가 파일에 한 번, 네 줄 차례가 위와 같고 둘째 · 셋째 · 넷째 줄 첫머리가 `이 에픽이 하기로 한 것:` · `결과:` · `물을 것:`. 「로드맵 에픽 블록의 `- 의도:` 줄을 글자 그대로 옮긴다」 한 번. 자리의 쉬운 이름 다섯이 한 불릿에.
  - `question-block`(AC2) — 질문 블록 펜스가 위 글자 그대로 한 번 · 「왜 묻나」 세 규칙 문장 각 한 번 · 화면에 싣지 않는 것 다섯 낱말이 한 불릿에 · 파일 전체에 `intent-critic 은 의도대로 만들었는지가 아니라` 0번 · `이유를 남기려면 직접 입력 칸에` 가 끝 줄 안에만 한 번(홀로 선 줄로는 0 — 양의 짝: 끝 줄).
  - `result-text`(AC3) — 결과 글 펜스 그대로 한 번 · 「번호는 세 묶음을 이어서 매긴다」 · 「`plain` 칸이고, 그 칸이 없는 지적은 `summary` 칸이다」 · 「새로 깨진 테스트: <테스트 이름>」 · 「낮춘 이유 한 구절은 `lowered_reason` 의 첫 문장」.
  - `result-line-cases`(AC4) — 「 · 인증 못 함(<그 사유 글자 그대로>)」 · 「셀 수 없음 — <그 자리에서 지휘자가 보이는 사유 문장 그대로>」 와 「「물을 것」 줄은 싣지 않는다」. [Q1 고치면: 「 · 의도 점검은 셀 수 없음(<사유>)」 한 번, 「담당자가 돌아오지 않은」 경우로 좁힌 문장 한 번.]
  - `filtered-count-and-notices`(AC16) — 「`answered_filtered` 에서 오고 0 이면 붙지 않는다」 · 「`qg-answered-notices.txt` 의 줄을 맥락 머리 바로 아래에 글자 그대로」 · 「빠지거나 줄어든 채 돌았다고 알리는 줄도 같은 자리에」.
  - `record-template-3`(AC17) — 기록 틀 펜스 줄 첫머리 `contract: 3` · `- 왜 묻나: <why>` · `- 전에 한 답: <asked_before 그대로 | 없음>` · `- 행선: <이 에픽 안에서 고친다 | 새 일의 씨앗 | 재분해 신호` 각 한 번, `- 왜 묻나:` 가 `- 질문:` 바로 다음 줄, `- 같은 대상에 전에 물은 것:` 0번. `- 질문:` · `- 답:` · `- 답 원문:` 줄은 그대로 한 번씩. [Q5 고치면: `- 달라진 관찰:` 한 번, `- 전에 한 답:` 바로 다음.]
  - `skill-show-line` — `SKILL.md` `## 보이기` 의 qg 문장이 「맥락 머리로 시작하는」 과 `references/qg-review.md` 를 가리킨다.
  - 옛 락 고치기 — `test_qg_review_reference.sh` 의 L138 `FIXED` 와 그 단언 둘(부재로 뒤집어 새 락으로 옮김) · L148–150 기록 틀 루프의 `contract: 2` · `- 같은 대상에 전에 물은 것:` · L157–165 계약 칸 루프(3판 칸으로 — `<why>` 더함) · L626–640 `ask-one-sentence` 의 앞 글 문단 · 앞 글 펜스 단언(새 질문 블록 단언으로) · L32 의 `QF`(질문 창 펜스 — 그대로 남아야 한다). `**의도 점검 질문.**` 앵커 · `라벨 셋의 글자와 순서는 qg 와 같다.` · 파일 전체 `AskUserQuestion` 한 번은 지킨다(`shared/tests/fixtures/ask-sites.tsv` 가 읽는다).
- [ ] **Step 2: 돌려 실패를 본다.** 두 락을 돌린다.
- [ ] **Step 3: 고친다.** `## 담당자` 아래 `### 낮춘 지적` 과 `### 판정과 코드 리뷰 지적` 을 `### 결과 글` 하나로 바꾼다 — 틀 펜스 둘(맥락 머리 · 결과 글)과 규칙 불릿, 그리고 지금 두 절의 처리 문장(L_raise · L_premerge · 머지 앞 막는 지적은 `## 되돌리기` · 로드맵 끝과 이름으로 청한 머지된 에픽의 지적은 후속 PR 하나의 고칠 목록)을 글자 그대로 옮긴다. 「낮춘 대로 뒀다 — 되올릴 것이 있으면 말한다」 는 틀에 없으므로 싣지 않는다 — 되올림은 「다음」 줄과 번호로 짚는다. `## 묻기` 의 「앞 글은 따로 된 메시지로 보인다 — …」 문단 · 고정 문장 인용 · 「앞 글에는 이어서 …」 문단 · 옛 앞 글 펜스를 질문 블록 틀과 규칙으로 바꾼다. 「칸은 결과 파일의 그 질문에서 채운다」 불릿에서 의심하는 것 · 근거의 종류 · 관찰 몫을 빼고 `why` · `asked_before` · `changed_observation` 을 더한다. `- 같은 대상에 전에 물은 것이 있어도 질문은 띄운다.`(Task 12 가 이미 지웠다) 자리에 아무것도 남기지 않는다.
- [ ] **Step 4: 통과.** 두 락과 Task 12 Step 4 의 다섯 테스트 PASS. `bash plugins/spec-distill/tests/test_epic_conductor_skill.sh` PASS.
- [ ] **Step 5: 변이.** 커밋한 뒤 맥락 머리 둘째 줄과 셋째 줄 차례 바꾸기 · 옛 고정 문장 되살리기 · 기록 틀의 `contract: 3` 을 2 로 · `- 왜 묻나:` 줄 지우기마다 RED, 복원.
- [ ] **Step 6: 커밋.** `git commit -m "feat(spec-distill): 리뷰 글을 맥락 머리 · 질문 블록 · 결과 글 틀로 바꾼다" -- plugins/spec-distill/skills/epic-conductor/references/qg-review.md plugins/spec-distill/skills/epic-conductor/SKILL.md plugins/spec-distill/tests/test_qg_review_readable.sh plugins/spec-distill/tests/test_qg_review_reference.sh`

---

### Task 14: spec-distill 의존 · README · CHANGELOG · 판

**AC:** AC8(의존 표) · AC20(spec-distill 쪽).

**Files:**
- Modify: `plugins/spec-distill/dependencies.md` · `plugins/spec-distill/README.md` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json`
- Test: `plugins/spec-distill/tests/test_qg_review_readable.sh`(README · 의존 표 단언)

- [ ] **Step 1: 실패하는 락.** `deps-min-qg` — `dependencies.md` 의 `| quality-gates | ` 행 둘째 칸이 `plugins/quality-gates/.claude-plugin/plugin.json` 의 `version` 과 같다(파일에서 읽어 견준다 — 리터럴로 박지 않는다). `readme-new-words` — spec-distill README 에 `qg_answered.py` · `--answered` · 「맥락 머리」 가 있다.
- [ ] **Step 2: 돌려 실패를 본다.**
- [ ] **Step 3: 고친다.** `plugin.json` 을 `8.34.0` 으로. 의존 표는 손으로 고치지 않는다 — `cd plugins/spec-distill && python3 scripts/check_deps.py measure --plugin-root . --superpowers-base "<불러온 superpowers skill 의 기준 폴더>"` 로 잰다(다른 행의 판 · 날짜가 함께 바뀌면 그대로 두고 보고에 적는다). quality-gates 행의 「없을 때」 칸은 그대로. CHANGELOG 맨 위 `## [8.34.0] — <커밋 날짜>`: Added(`qg_answered.py`), Changed(호출 줄 `--answered` · 판 3 만 읽음 · 화면의 틀 · 기록 틀 3판 · 좁은 재리뷰도 근거가 같으면 다시 묻지 않음 · 이름으로 청한 뒤의 자리 글자), Removed(「같은 대상에 전에 물은 것」 손 절차 — 스크립트로 바뀜). README 의 지휘자 qg 절에 바뀐 동작.
- [ ] **Step 4: 통과.** 그 락 · `bash shared/tests/test_changelog_integrity.sh` · `bash shared/tests/test_check_deps.sh` · `python3 -m unittest shared/tests/test_check_deps.py` PASS.
- [ ] **Step 5: 커밋.** `git commit -m "docs(spec-distill): 8.34.0 — 지난 답 넘기기와 읽히는 리뷰 글을 적는다" -- plugins/spec-distill/dependencies.md plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/tests/test_qg_review_readable.sh`

---

### Task 15: 끝 확인 — 스위트 · 전체 리뷰 · 미룸

**AC:** 전체(AC1–AC22 의 보고).

**Files:** `docs/superpowers/specs/2026-11-22-qg-readable-review-design.md`(`## 미룸` 표에 행만 더한다), 보고 파일 `TMPDIR/ac-report.md`(git 이 추적하지 않는다).

- [ ] **Step 1: 전체 스위트.** Global Constraints 의 잠금 줄로 `bash tools/suite/run-all.sh` 를 돈다. 실패는 이름을 모두 보고에 적는다 — 기본 브랜치 끝과의 대조는 지휘자의 스위트 대조가 한다.
- [ ] **Step 2: 전체 리뷰.** 실행 방식의 마지막 전체 리뷰(쓰기 도구가 없는 리뷰어)에 설계문서 `## Acceptance Criteria` 의 AC1–AC22 를 글자 그대로 싣고, AC 마다 한 줄 `AC<n>: <구현됨 | 미룸 | 빠짐> — <근거(파일:줄 · 테스트 이름)>` 로 보고하게 한다. 같은 리뷰에 묻는다 — 설계문서 `## 있는 것 검토` 가 고른 것(qg 의 「이미 답한 질문」 장치 · `--origin` 의 길 · 기록 파일 · `plain` 칸 · `shared/style/plain-language.md`)을 실제로 썼는지, 같은 것을 다시 만들지 않았는지(새 거르기 · 새 답 저장소 · 새 렌더러가 없는지). 그리고 이음매를 명시해 묻는다 — `qg_answered.py` 의 출력 → `--answered` → `prepare` → `intent-handed.yaml` → `filter` → `render` → `intent-return.md` 3판 → 지휘자의 `## 돌아왔을 때` · 맥락 머리 · 기록 틀 → 다음 `qg_answered.py` 가 끝에서 끝으로 같은 칸 이름 · 같은 판 · 같은 열쇠 꼴을 말하는지, 각 단계의 rc 를 다음 단계가 읽는지. 이 계획이 시킨 테스트 코드(Task 5 의 여덟 갈래 픽스처 · Task 11 의 이음매 테스트)는 「계획이 쓴 테스트」 라고 라벨을 붙여 따로 보게 한다.
- [ ] **Step 3: 보고 파일.** 리뷰의 AC 줄들을 `TMPDIR/ac-report.md` 에 셸로 쓴다.
- [ ] **Step 4: 미룸 표.** 리뷰가 미룸 · 빠짐으로 낸 AC 와 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 `| 항목 | 이유 | 받는 곳 |` 행으로 더한다(받는 곳은 로드맵의 에픽 번호 또는 `#<PR 번호>`). 커밋: `git commit -m "docs(spec): R6 구현 뒤 미룸을 적는다" -- docs/superpowers/specs/2026-11-22-qg-readable-review-design.md`
- [ ] **Step 5: 덮음 확인.** PR 을 만들기 전에 `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.29.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-11-22-qg-readable-review-design.md "$TMPDIR/ac-report.md"` 를 돌려 출력 전부를 마지막 보고에 싣는다(경고는 지휘자가 사용자에게 보인다).

---

## Deferred to plan 의 처리

설계문서 `### Deferred to plan` 의 행마다 이 계획이 받는 법이다. 「반영 확인」 은 계획을 짤 때 설계 본문에서 확인한 자리다.

| # | 처리 | 자리 |
|---|---|---|
| adc4a942#r1.1 | 반영 확인 — §3 「합쳐지기 전 지적 목록의 출처를 만든다」 · AC21 | Task 8 · 12 |
| 8dc76472#r1.1 | 반영 확인 — §4 판을 견주지 않고 멈춤을 보고 한 번 다시 부른다 | Task 12 `old-qg-retry-once` |
| 84b5030b#r1.1 | 반영 확인 — §5 답 폴더 「잘못 골랐다」 목록만 보고에 남기고 머지 앞 규칙이 읽는다 | Task 12 `report-only-wrong-list` |
| abcf8f1a#r1.1 | 반영 확인 — Rejected Alternatives 「돌려주는 꼴 2판과 3판을 모두 읽는다」 가 지금 사실로 다시 쓰였다 | — |
| 9dbe3507#r1.1 | 반영 확인 — §6 행선 값 셋(재분해 신호 포함) | Task 11 · 13 |
| fccf272b#r1.1 | 반영 확인 — AC15 가 담당자 다시 부르기 예외를 따로 묶는다 | Task 12 |
| 4e6c0c49#r2.1 | 반영 확인 — §1 · AC16 빠진 채 돈 알림 줄은 화면에 | Task 12 `degrade-lines-verbatim` · Task 13 |
| 1cdda836#r2.1 | 반영 확인 — Files to Modify 에 `### 보내기` 처분 줄과 「돌아오면」 문단 | Task 12 |
| 8569fc92#r2.1 | 과제에 넣음 — 코드 지적은 `findings-pre-merge.yaml` 에서, 새로 깨진 테스트는 result.md `### 차등 회귀` 에서 싣고 막는 지적 수는 둘을 더한다 | Task 12 `pre-merge-file` · Task 13 `result-text` |
| cf64b319#r2.1 | 사용자에게 올림 — Q1(권고: 고치면) | Task 13 |
| 9600d39d#r2.1 | 사용자에게 올림 — Q4(권고: 고치면) | Task 13 |
| a67cdb00#r2.1 | 받지 않음 — 설계 본문은 이 계획이 고치지 않고, 지휘 기록 2026-11-23 줄이 D14 가 옛 글이고 §4 가 지금 것이라고 이미 적었다. 이 계획 머리 `Spec:` 줄에도 적었다 | — |
| 53fae0e6#r2.1 | 사용자에게 올림 — Q2(권고: 고치면 첫 길) | Task 12 |
| b083a44d#r3.1 | 사용자에게 올림 — Q2 의 다른 길 | Task 12 |
| a893efdb#r3.1 | 과제에 넣음 — `자세히` 는 기록 파일에 그 리뷰의 `## 질문` 절이 이미 있을 때만 그 경로, 아니면 보관 폴더(머리만 먼저 커밋된 기록 파일은 가리키지 않는다) | Task 13 |
| 9600d39d#r2.2 | 사용자에게 올림 — Q3(권고: 세지 않는다) | Task 12 · 13 |
| 9600d39d#r2.3 | 과제에 넣음 — 낮춘 이유 한 구절은 `lowered_reason` 의 첫 문장(고치는 법과 같은 자르기, 지휘자가 짓지 않는다) | Task 12 · 13 |
| 9dbe3507#r2.1 | 사용자에게 올림 — Q5(권고: 고치면) | Task 13 |

## 계획이 정한 것 (설계에 없던 자리)

설계가 「계획이 정한다」 로 둔 자리와, 설계가 말하지 않아 이 계획이 채운 자리다. 위 「사용자가 정할 것」 다섯은 여기 넣지 않았다.

1. **합쳐지기 전 목록** — 인자 `--pre-merge-out`, 세션 폴더 파일 `findings-pre-merge.yaml`(`findings:` 목록, 받은 칸 그대로), 쓰지 못하면 stderr 한 줄 · rc 그대로. 다른 길: 파일을 쓰지 못하면 rc 를 0 아닌 값으로(판정까지 멈춘다).
2. **「달라진 관찰」 칸** — 이름 `changed_observation`, 꼴은 `-` 또는 글 목록(첫 항목 화면 한 구절 · `이전 관찰: …` · 지금의 근거 줄 · 인용), 한 구절 상한 80자(이미 있는 `SNIPPET`) + 「…」, 근거 줄의 앞 번호는 뗀다. 다른 길: 칸 둘로 나누기(`changed_snippet` 글 + `changed_observation` 목록) · 상한 120자.
3. **「이미 답한 것」 파일** — 이름 `qg-answered.yaml`(보관 폴더), 키 `contract: 1` · `entries`(`key` · `id` · `answer` · `question` · `observation` · `answered_at` · `route` · `record`), 알림 파일 `qg-answered-notices.txt`. 다른 길: JSON · 판 키 이름을 `answered_contract` 로.
4. **qg 의 읽기 규칙** — 상한 1000000 바이트, 항목 하나라도 틀리면 파일 전체를 받지 않는다(질문을 더 묻는 쪽), `잘못 골랐다` 의 행선 값 셋 밖이면 꼴이 맞지 않음. 다른 길: 틀린 항목만 버리고 나머지를 쓴다(걸러지는 것이 늘고 버린 수 공시가 새로 든다).
5. **준비와 거르기가 같은 것을 읽는 길** — 설계는 「넘겨받은 파일의 경로를 준비 파일에 남긴다」 였는데, 이 계획은 준비가 읽은 항목을 세션 폴더 `intent-handed.yaml` 에 옮겨 두고 거르기가 그것을 읽게 했다. 경로에 제어 글자가 있으면 계획 파일 한 줄이 깨지고, 준비와 거르기 사이에 원본이 바뀌어도 같은 것을 읽는다. 다른 길: 설계 글자대로 계획 파일에 `answered_file:` 줄을 두고 거르기가 다시 읽는다.
6. **리뷰어 입력 줄** — 관찰은 지금처럼 첫 줄만, 질문 글은 한 줄로 접어 전부. 줄 꼴 `- <열쇠> · <정체> · <답> · 질문: … · 관찰: …`(답 폴더 답은 열쇠 칸 없이). 다른 길: 관찰 전부를 싣는다(리뷰어 입력이 커지고 `previous` 인용이 길어진다).
7. **걸러진 수와 목록** — `answered_filtered` 는 걸러진 모두(넘겨받은 의도다 · 미뤄 둔 의심 · 답 폴더의 둘)를 센다. 넘겨받은 미뤄 둔 의심은 「이미 답한 질문이라 거른 질문:」 목록에 ` · 미뤄 둔 의심` 표시로 싣고 「이미 「잘못 골랐다」 답이 있어 거른 질문:」 에는 싣지 않는다(머지를 멈추는 규칙 · qg 의 「같은 브랜치에서 이어 고친다」 할 일이 그 목록을 읽는다). 다른 길: 미뤄 둔 의심 전용 목록 머리를 새로 둔다.
8. **정체를 가르지 못한 질문** — 넘겨받은 열쇠를 가리켰으면 그 질문도 거른다(정체는 견주지 않는다는 설계의 결정을 끝까지 적용). 다른 길: 지금처럼 정체가 있는 질문만 거른다.
9. **답 폴더 답의 `asked_before`** — 관찰이 달라져 다시 묻는 답 폴더 답에도 `asked_before`(셋째 칸은 정체)를 채운다(설계 §4 문장대로). 지금까지는 빈칸이었다.
10. **`qg_answered.py` 의 꼴** — 인자 `--roadmap` · `--ref`(차례가 앞섬) · `--out` · `--notices` · `--repo`, 종료 코드 0 · 2 · 3, 풀 수 없는 ref 는 「읽지 못한 기록」 에 `<ref>:<폴더>` 로 센다, 틀린 기록 파일은 통째로 「읽지 못한 기록」(그 파일의 항목은 싣지 않는다), 2판 `asked` 의 「잘못 골랐다」 는 행선 `이 에픽 안에서 고친다`(설계의 「다시 묻는 쪽」). rc 3 이면 지휘자는 stderr 를 보이고 그대로 보낸다(qg 가 「넘겨받은 답을 읽지 못함 — 없음」 으로 알린다). 다른 길: rc 3 이면 보내지 않고 사용자에게 묻는다.
11. **지휘 절차의 자리** — 지우는 손 절차 절의 세 자리 문장은 새 절 `### 이미 답한 것` 으로 옮기고 `### 이미 보낸 것` 1 이 그 절을 가리킨다. `### 낮춘 지적` · `### 판정과 코드 리뷰 지적` 은 `### 결과 글` 하나로 합친다. 「낮춘 대로 뒀다 — 되올릴 것이 있으면 말한다」 는 승인된 틀에 없어 싣지 않는다. 처분 줄의 공시 문구를 새 틀에 맞게 고친다.
12. **qg 직접 실행의 머리 줄** — `<리뷰 범위>` 는 브랜치 이름(분리된 HEAD 면 `HEAD <앞 8자>`). 다른 길: Step 1 의 「리뷰 범위:」 줄 글을 그대로.
13. **qg 인자 안내의 차례** — `[--origin <경로>] [--answered <경로>]`(호출 줄 차례와 같게), `--origin` 을 끝에 묶던 락을 고친다. 다른 길: `--answered` 를 `--origin` 앞에 두고 락을 그대로.
14. **락 자리** — 새 화면 틀 · 새 절차 문장은 새 락 `test_qg_review_readable.sh` 에, 옛 락 `test_qg_review_reference.sh` 는 바뀐 문장의 단언만 옮긴다. 다른 팀 읽기 테스트는 새 파일(`test_other_teams.py` 는 qg 어댑터가 맡지 않는 꼴이라). 넘겨받은 답 테스트도 새 파일 `test_intent_handed.py`.
15. **판** — quality-gates 17.0.0(major), spec-distill 8.34.0(minor). 다른 길: quality-gates 16.1.0(새 판을 「추가」 로 보고 minor — 2 만 읽는 쪽이 깨지므로 권하지 않는다).
16. **준비에서 넘겨받은 답을 읽는 때** — 좁은 리뷰에 돌려 본 근거가 없어 리뷰어를 부르지 않는 실행에서는 읽지 않는다(걸러질 것이 없어 공시도 없다). 다른 길: 늘 읽고 못 읽으면 알린다.
