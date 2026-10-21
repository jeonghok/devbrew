# R12 계획 1 — 공유 리뷰 엔진 · spec-distill 절차 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 공유 리뷰 엔진(`shared/docreview`)이 범위 밖 값 · 모양을 이유와 함께 거부하고, 흡수 · 보호 · 정리 · 닫힌 리뷰의 결정 줄에서 항목과 보호를 조용히 잃지 않으며, 원장 쓰기 순서 규칙을 락이 산문까지 지키고, spec-distill 절차의 손 편집 · 셸 대입 · 재분해 갈래를 고친다.

**Architecture:** 엔진 고침은 이미 있는 장치에 붙인다 — 최댓값은 `docreview_config.MINIMUM` 옆 `MAXIMUM`, 「새 항목만 추가」는 스냅숏 칸 하나(`item_marks`), 보호 계보는 `_expected_lines` 처럼 원장 스냅숏을 걷는 함수 하나(`lineage_anchors`)를 보호 · 불변 계산 자리 전부가 지나게, 닫힌 리뷰의 손 줄은 결정 기록 절 줄 출처 판정(`_log_verdicts`)의 새 규칙 하나로. 펜스 락은 `test_ledger_wiring.sh` 의 `ac8_scan` 대상을 `git ls-files` 로 도출하고 산문 문단 검사를 더한다(엔진은 표지를 모른다). 절차는 spec-review `SKILL.md` · `references/redecompose.md` · `references/conducting.md` 의 문단 · 펜스만 고친다.

**Tech Stack:** Python 3.9 표준 라이브러리 + PyYAML(엔진이 이미 씀), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), Markdown skill · reference.

**Spec:** `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` (§2 · §3 · §4 · §5 · §6 · §9 의 conducting.md 걸음 4 ③ · AC1~AC16 · AC34)

**구현 브랜치:** `feature/review-engine-leftovers`(이 계획 파일이 있는 브랜치). 계획 2(`feature/qg-verdict-state`) · 계획 3(`feature/review-lock-leftovers`)과 병렬로 간다.

## 목차

- [Global Constraints](#global-constraints)
- [설계와 다른 점 · 설계에 없던 결정](#설계와-다른-점--설계에-없던-결정)
- [Review Focus](#review-focus)
- [Task 0: 시작 · 기준선 · 줄 번호 다시 읽기](#task-0-시작--기준선--줄-번호-다시-읽기)
- [Task 1: 엔진 값 최댓값 (AC1)](#task-1-엔진-값-최댓값-ac1)
- [Task 2: 불변 절은 「새 항목만 추가」 (AC2)](#task-2-불변-절은-새-항목만-추가-ac2)
- [Task 3: `related-changes` 출력 이스케이프 (AC3)](#task-3-related-changes-출력-이스케이프-ac3)
- [Task 4: 라우터 — 재비판 흡수의 막는 목록 · 복수 앵커 · `§` 앵커 · 같은 임시 번호 (AC4 · AC5 · AC6 · AC7)](#task-4-라우터--재비판-흡수의-막는-목록--복수-앵커---앵커--같은-임시-번호-ac4--ac5--ac6--ac7)
- [Task 5: 흡수 분기의 배선 락 (AC8)](#task-5-흡수-분기의-배선-락-ac8)
- [Task 6: 보호 · 불변의 계보 (AC9)](#task-6-보호--불변의-계보-ac9)
- [Task 7: finalize 를 두 번 불러도 같은 보고 (AC10)](#task-7-finalize-를-두-번-불러도-같은-보고-ac10)
- [Task 8: 리뷰가 닫힌 뒤 손으로 쓴 결정 줄 · 지휘 절차 걸음 4 ③ (AC11)](#task-8-리뷰가-닫힌-뒤-손으로-쓴-결정-줄--지휘-절차-걸음-4-③-ac11)
- [Task 9: 원장 쓰기 순서 락을 산문까지 (AC12)](#task-9-원장-쓰기-순서-락을-산문까지-ac12)
- [Task 10: 손 편집의 허가 걸음 · 재분해 rc 1 가르기 (AC13 · AC16)](#task-10-손-편집의-허가-걸음--재분해-rc-1-가르기-ac13--ac16)
- [Task 11: 셸 대입 · 사용자 말 · 결정 줄 펜스의 레포 (AC14 · AC15)](#task-11-셸-대입--사용자-말--결정-줄-펜스의-레포-ac14--ac15)
- [Task 12: 문서 · 버전 · 스위트 대조 · 변이 · AC 보고 (AC34 마감)](#task-12-문서--버전--스위트-대조--변이--ac-보고-ac34-마감)

## Global Constraints

- **시작.** 이 브랜치에서 시작하고 기본 브랜치를 merge 한다(rebase 금지). 기본 브랜치 이름은 `git symbolic-ref --short refs/remotes/origin/HEAD` 로 도출한다(없으면 `git remote set-head origin --auto`). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec(`git commit -- <경로…>`), `git stash` 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 구현 커밋마다 `Spec: docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md` 트레일러, 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- **버전.** 공유 엔진은 링크로 spec-distill · quality-gates 둘에 실려 나간다 — 이 계획은 **spec-distill 과 quality-gates** 를 올린다. 판 번호는 머지 직전 지휘자가 정한다. 구현 중에는 기본 브랜치 판의 다음 minor 를 임시로 쓴다(spec-distill 8.0.0 → 8.1.0 · quality-gates 14.1.1 → 14.2.0 꼴 — 그새 판이 바뀌었으면 그 다음 minor). CHANGELOG 머리는 plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- **경로 겹침.** `tools/adjudication/check_wiring.py` 는 계획 2(합성기 줄 이동) · 계획 3(키에서 줄 번호 빼기)도 고친다. 계획 3 이 먼저 머지됐으면 `EXEMPT` 키에 줄 번호가 없으니 다시 박지 않는다. 아니면 이 계획이 옮긴 줄을 실측으로 다시 박는다(Task 5). `shared/tests/fixtures/docreview/cases.sh` 는 계획 3 도 케이스를 더한다 — 뒤에 머지하는 쪽이 기본 브랜치를 merge 하고 두 쪽 케이스를 모두 남긴다.
- **R13 · R8 경로 예약.** spec-review `SKILL.md` · request-framing · reviewing-brief 는 R13, `docreview_state.py` · `redecompose.md` · `conducting.md` 는 R8 도 예약했다 — 이 계획이 먼저 고친다. request-framing · reviewing-brief 는 넓힌 펜스 락(Task 9)이 거는 산문만 고친다.
- **셸.** 펜스와 테스트는 macOS bash 3.2 에서 돈다. `$var` 바로 뒤에 한글이 오면 `${var}`. `$( )` 안 heredoc 금지. 새 · 바뀐 셸 테스트는 `chmod +x` 후 `git ls-files -s` 로 `100755` 확인. Bash 도구 셸은 zsh 다 — `PIPESTATUS` 가 필요하면 `bash -c` 안에서 잡는다.
- **파이썬.** 파일 읽기 · 쓰기는 `encoding="utf-8"`. 플러그인 `.py` 에 `"python3"` 리터럴 금지. 인라인 python 은 `python3 -I`. 긴 한글 줄은 인접 문자열로 나눈다(CPython 토크나이저). 비신뢰 입력의 신원 정규식은 `fullmatch`.
- **변이.** 변이 전에 커밋한다. 변이는 `git clone --no-local` 사본에서 `PYTHONDONTWRITEBYTECODE=1` 로 돌리고, 매 변이 뒤 `git checkout HEAD -- <파일>` 과 `git diff HEAD --quiet` 로 복원을 확인한다. 변이마다 양성 대조(무변이 사본 GREEN)를 먼저 본다. 변이는 삭제만이 아니라 추가 · 반전 · 형태 변경으로 흔든다. 음의 락에는 양의 짝을 둔다.
- **골든.** 엔진 골든(`shared/tests/fixtures/docreview/golden/`)은 `case_*_state.md` 다섯을 빼고 바뀌지 않는다. Task 7(finalize 멱등)만 `*.state.md` 다섯의 라운드 기록에 보고서 사본 칸을 더해 바꾼다 — 그 까닭을 그 커밋 본문에 적고 `fixtures/docreview/capture_finalize_golden.sh` 로 다시 뜬다. `§` 정규화(Task 4)는 골든을 바꾸지 않는다.
- **락 지도의 R12 행 넷**(`cases_advice.sh` 의 `case_advice_pre_upgrade_ledger` · `case_AC6_render_cap`, 골든 `case_T05_T06_reject.gate.txt` · `case_T11_permit_keeps_disposition.gate.txt`)은 끝까지 GREEN 이다.
- 레포 전용 값(경로 · 테스트 명령 · 브랜치 · 모델 · `gh`)을 박지 않는다. 사람에게 보이는 새 문면(실패 메시지 · 게이트 줄 · README · CHANGELOG)은 `shared/style/plain-language.md`. 모델이 읽는 새 문면에는 출처 · 배경 · 정당화를 쓰지 않는다(Self-narrating artifact).
- **전체 스위트**는 지휘자가 준 공유 스위트 잠금 아래서만 돈다: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c '<스위트 명령>'`. 잠금을 못 잡으면(종료 코드 3 · 75) 잠금 없이 돌리지 않고 보고한다. 과제 안의 좁은 테스트는 잠금 없이 돈다. 과제 경계마다 바꾼 파일을 코퍼스로 읽는 락까지 넓게 돈다(테스트 안에서 그 파일 이름으로 `grep -l`).
- 리뷰어 요청에는 계획이 쓴 테스트 코드에 「plan-mandated — 계획이 적은 테스트라 덜 검사받기 쉽다, 따로 보라」 라벨을 매번 싣는다.

## 설계와 다른 점 · 설계에 없던 결정

1. **최댓값 넷(§2):** `detectors` 6 · `rereview_cap` 10 · `render_cap` 100 · `summary_width` 500. 기본값(1 · 2 · 8 · 60)과 지금 테스트 값(탐지 3 · 상한 1 · 참고 3 · 폭 20)보다 넉넉하다. 거부 출력에 `allowed`(「최소~최대」) 칸을 더한다. `advice --cap` 도 최댓값을 지난다(넘으면 `config_invalid` rc 2 — 1 보다 작으면 지금처럼 `cap_invalid`).
2. **줄 머리 표시의 이름과 모양(§2):** 스냅숏 절마다 `item_marks` — `line_hashes` 와 같은 길이의 `0`/`1` 문자열(그 줄이 0열 `- ` 로 시작하면 `1`). `begin-round` 는 **불변 절에만** 옮겨 적는다(결정 기록 · 미룸 절은 `_log_verdicts` 가 보므로 옮기지 않는다 — 그래서 design-doc 골든이 안 바뀐다). `item_marks` 가 없는 절(옛 원장 · 손으로 만든 스냅숏)은 「추가만」 면제를 받지 않는다(닫힌 쪽).
3. **finalize 멱등은 보고서 사본을 원장에 둔다(§4 — 설계 변경 보고 대상).** 지금 원장의 `route_report` 는 요약뿐이라 「같은 보고」를 다시 낼 재료가 없다. 첫 finalize 가 낸 JSON 을 그 라운드 기록 `rounds[n].finalize_out` 에 남기고, 둘째 finalize 는 그것을 글자 그대로 다시 내고 stderr 에 「이 라운드는 이미 정리됐다」 한 줄을 낸다. 원장 칸이 하나 는다(Anti-goals 의 「새 원장 칸」) — 진입 skill 셋이 `> fin.json` 으로 받으므로 다른 모양을 내면 `advisory[]` · `blocks` 를 잃는다. 골든 `*.state.md` 다섯이 바뀐다.
4. **계수 줄 표지(§4 — 설계 변경 보고 대상).** 「마지막 계수 줄」을 원장이 알아보려면 엔진 줄 기록(`engine_lines`)의 어느 줄이 계수 줄인지 알아야 한다(줄 해시만으로는 못 가린다 — 계수 줄의 정체는 상태 폴더 경로에서 나온다). `cmd_advice --log-file` 이 계수 줄을 쓸 때 그 `engine_lines` 항목에 `"kind": "count"` 를 붙인다. 이미 있는 기록 항목의 칸 하나다. 표지가 없는 옛 원장은 닫힌 뒤 줄을 기록으로 읽지 않는다(지금처럼 묻는다).
5. **닫힌 뒤 손 줄의 면제 라벨은 `closed-log`** 이고 `RESERVED_SCOPES` 에 더한다(리뷰어가 쓴 범위로 위조되지 않게).
6. **보류 사유 글자는 `항목 파손: edit_scope_multi_anchor` · `항목 파손: duplicate_ref`** — `Ledger.held_by_class` 의 「항목 파손」 묶음에 들고, 게이트는 이미 있는 「보류」 쉬운 말 줄의 괄호에 사유를 싣는다(새 WARN_GLOSS 행 없음).
7. **흡수 분기 배선 락(§3):** 배선 스캔(`check_wiring._disposition_calls`)이 `ev("<처분 이름>", …)` 꼴(이름 호출 + 첫 인자가 처분 이름 글자)도 처분 호출로 센다. 그리고 `merge_list_blocks` · `cmd_prepare` 의 흡수 분기를 `continue` 로 끝나게 다시 쓴다 — 지금은 버리는 노드가 없어 스캔이 그 분기를 보지 못한다.
8. **§6 허가 길 확인 결과(설계 `### Deferred to plan` 첫 줄 — 설계 변경 보고 대상).** 계획을 쓰며 코드를 읽어 확인했다: `declare-related` 는 그 라운드의 **채택된 결정과 그 apply permit** 이 있어야 받고(`cmd_declare_related` 의 `decision_not_adopted`), `check-intent --decision-id` 도 permit 이 있어야 받는다. 기각 되돌리기(승인 게이트 후속 질문의 기타 칸 답)와 재분해(「인터뷰 다시 열기」 갈래)에는 채택 결정이 없는 것이 보통이다 — 그 경우 허가 길로 표현되지 않는다. 이 계획은 (가) 채택 결정이 있을 때 묶는 걸음을 절차에 적고 끝에서 끝으로 잰다, (나) 채택 결정이 없을 때 고친 행이 다음 게이트에 「허가 없이 바뀜」으로 다시 온다는 사실을 그 자리에서 사용자에게 알리는 문장을 적는다. 새 엔진 명령은 만들지 않는다. 지휘 세션이 다른 답(엔진 길을 연다 등)을 주면 Task 10 을 고친다.
9. **경로 대입 줄의 꼴(§6):** spec-review 의 아홉 자리 대입 지시를 한 정의 문단(「경로 대입 줄」)으로 모은다 — 변수마다 `IFS= read -r <변수> <<'DEVBREW_PATH_EOF'` · 값 한 줄 · `DEVBREW_PATH_EOF`. 아홉 자리는 그 정의를 가리킨다.
10. **펜스 락 코퍼스에서 CHANGELOG 를 뺀다(§5).** 설계가 적은 「지금 트리에서 들어오는 파일」(진입 skill 셋 · `finishing.md` · `reviewing-document.md` · README)과 맞추려면 이력 기록(`plugins/spec-distill/CHANGELOG.md`)을 빼야 한다. 산문 꼴은 `docreview_state.py` 와 하위 명령 사이에 따옴표 · 백틱 · 공백과 조사 「의」 하나까지 낀 꼴을 센다(`` `docreview_state.py` 의 `declare-related` `` 꼴 포함).
11. **계획 나누기는 설계 §11 그대로다.** R13 을 빨리 열려고 펜스 락만 떼어 먼저 머지하는 길은 도움이 안 된다 — R13 이 고칠 spec-review `SKILL.md` 를 이 계획의 §6 과제도 고친다.

## Review Focus

1. **보호 절의 자식이 채택한 제목 삽입으로 밀려난 뒤, 다른 리뷰어가 그 자식 절에 `fix` 를 낸다.** 사람은 그 고침이 조용히 적용되지 않고 결정으로 올라오기를 기대한다 — 라우터 분류(`_classify_items`)와 `check-intent` 가 같은 답을 내야 한다. Task 6 의 `case_lineage_routing_and_intent_agree` 가 잠근다.
2. **리뷰를 닫은 뒤 결정 기록 끝에 손으로 두 줄을 쓰고, 재리뷰를 시작한 뒤 한 줄을 더 쓴다.** 앞 두 줄은 기록으로, 뒤 한 줄은 질문으로 와야 한다. Task 8 의 `case_closed_log_after_close_vs_after_begin` 이 잠근다.
3. **설계문서 경로에 작은따옴표 · `$( )` · 역따옴표가 든다(사용자가 고른 폴더 이름).** spec-review 의 어느 펜스도 그 글을 셸로 실행하지 않고 경로 그대로 써야 한다. Task 11 의 `case_path_assignment_hostile` 가 잠근다.
4. **같은 라운드에 `finalize` 를 두 번 부른다(진입 skill 이 한 번 더 돌림).** 둘째가 `fin.json` 을 빈 파일로 덮지 않고 같은 보고를 내야 한다 — 다른 라운드의 준비면 지금처럼 거부한다. Task 7 의 `case_finalize_twice_same_report` 가 잠근다.
5. **엔진 환경 값을 아주 크게 준다(`DEVBREW_DOCREVIEW_DETECTORS=500`).** 탐지 리뷰어 500명을 띄우지 않고 이름 · 값 · 허용 범위 · 출처를 보이며 라운드를 시작하지 않아야 한다. Task 1 의 `case_config_maximum_refused` 가 잠근다.

---

### Task 0: 시작 · 기준선 · 줄 번호 다시 읽기

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r12-plan1/baseline.sh` (레포 밖)
- Modify: 이 계획 파일(줄 번호 · 함수 자리 고침이 있으면)

- [ ] **Step 1: 기본 브랜치를 merge 한다** — `git fetch origin && D="$(git symbolic-ref --short refs/remotes/origin/HEAD)" && git merge --no-edit "$D"`. 충돌 없음이 기대값(이 브랜치는 설계문서 · 계획만 더했다).

- [ ] **Step 2: 계획 2 · 3 의 머지 상태를 본다**

Run: `git log --oneline "$D" --merges --grep 'feature/review-lock-leftovers' | head -1; git log --oneline "$D" --merges --grep 'feature/qg-verdict-state' | head -1`
Expected: 계획 3 이 머지돼 있으면 `tools/adjudication/check_wiring.py` 의 `EXEMPT` 키에 줄 번호가 없다 — Task 5 Step 5 의 다시 박기를 건너뛴다. 보고 기록에 둘의 상태를 적는다.

- [ ] **Step 3: 고칠 자리를 다시 읽고 계획을 맞춘다** — `shared/docreview/scripts/docreview_config.py`(`MINIMUM` · `_int` · `resolve`), `docreview_anchor.py`(`parse_sections` · `classify_anchor` · `cmd_check_intent` · `cmd_diff`), `docreview_state.py`(`round_fence` · `_log_verdicts` · `scope_problem` · `_appended_only` · `cmd_begin_round` · `_immutable_adopt_anchors` · `cmd_declare_related` · `cmd_related_changes` · `_expected_lines` · `gate_summary` · `cmd_advice`), `docreview_route.py`(`merge_list_blocks` · `normalize` · `cmd_prepare` · `_absorb_same_as` · `_classify_items` · `_auto_decides` · `_build_report` · `cmd_finalize`). 보호 · 불변 계산 자리를 다시 센다:

Run: `grep -n "anchors_matching(prof\[\"\(immutable\|protected_headings\)\"\]\|fence_anchors(\|round_fence(\|classify_anchor(\|scope_problem(\|_immutable_adopt_anchors(" shared/docreview/scripts/*.py`
Expected: 계획을 쓴 때(6e4acd2a)의 자리 — `classify_anchor` 정의 · 부르는 곳 셋(`docreview_anchor.py` check-intent, `docreview_route.py` `_classify_items` · `_auto_decides`), `scope_problem` 부르는 곳 넷(check-intent 둘 · `_adopt_problem_for` · `cmd_declare_related`), `round_fence` 부르는 곳 셋(`exempt_scopes` · `round_diff` · `observe_ledger`), `begin-round` 의 `imm`, `_immutable_adopt_anchors` 부르는 곳 둘, `snapshot_problem` 의 `fence_anchors`. 더 있으면 Task 6 의 `Modify:` 에 더한다.

- [ ] **Step 4: 기준 스위트 스크립트를 쓴다** — R2a 계획 1(`docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md` Task 0 Step 1)의 `baseline.sh` 를 그대로 `$HOME/.claude/sdd-mirror/r12-plan1/baseline.sh` 에 쓴다(셸 테스트 · unittest 둘 다, 실패 줄 «이름» 집합을 남김).

- [ ] **Step 5: 기준을 잰다** (버릴 clone — `git clone --no-local` 로 merge 한 HEAD 를 받아 그 루트에서, 공유 스위트 잠금 아래)

Run: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c 'cd <clone> && bash "$HOME/.claude/sdd-mirror/r12-plan1/baseline.sh" "$HOME/.claude/sdd-mirror/r12-plan1/before"'`
Expected: `before.tsv` · `before.names` 생성.

- [ ] **Step 6: 계획 고침이 있으면 커밋한다** — `git commit -m 'docs(plan): R12 계획 1 — 기준선 뒤 자리 맞춤' -- docs/superpowers/plans/2026-10-20-r12-plan1-engine-procedure.md`

---

### Task 1: 엔진 값 최댓값 (AC1)

**Files:**
- Modify: `shared/docreview/scripts/docreview_config.py` · `shared/docreview/scripts/docreview_state.py`(`load_profile` 의 `config_invalid` · `cmd_begin_round` · `cmd_advice` 의 `fail` 셋 · `--cap`)
- Modify: `plugins/spec-distill/README.md`(`DEVBREW_DOCREVIEW_*` 표의 범위 칸) · quality-gates README 에 같은 표가 있으면 그것도(`grep -n DEVBREW_DOCREVIEW_ plugins/*/README.md`)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_state.sh`(케이스 등록)

**Interfaces:**
- Produces: `docreview_config.MAXIMUM: dict` (`{"detectors": 6, "rereview_cap": 10, "render_cap": 100, "summary_width": 500}`) · `docreview_config.allowed_range(name: str) -> str` (예: `"1~6"`). `ConfigInvalid` 는 그대로(이름 · 값 · 출처). 거부 출력(stderr JSON)은 `{"ok": false, "reason": "config_invalid", "name", "value", "where", "allowed"}`.

- [ ] **Step 1: 실패하는 케이스를 쓴다** — `cases.sh` 에 `case_config_maximum_refused` 를 더하고 `test_docreview_state.sh` 목록의 `case_config_invalid_refused` 다음에 등록한다.

```bash
case_config_maximum_refused() {
  local d s err rc; d="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")" || { no "max: init 실패"; return; }
  s="$d/s1.json"; snap "$FX/design-sample.md" "$s"
  err="$(DEVBREW_DOCREVIEW_DETECTORS=500 py docreview_state.py begin-round --state-dir "$d" --snapshot "$s" 2>&1 >/dev/null)"; rc=$?
  assert_eq "$rc" "2" "max: 최댓값을 넘는 환경 값은 라운드를 시작하지 않는다(rc 2)"
  assert_contains "$err" '"reason": "config_invalid"' "max: 사유 이름"
  assert_contains "$err" '"allowed": "1~6"' "max: 허용 범위를 낸다"
  assert_contains "$err" 'DEVBREW_DOCREVIEW_DETECTORS' "max: 출처(변수 이름)를 낸다"
  assert_eq "$(st_yaml "$d" 'st["round"]')" "0" "max: 거부는 원장을 바꾸지 않는다"
  for kv in DEVBREW_DOCREVIEW_REREVIEW_CAP=11 DEVBREW_DOCREVIEW_RENDER_CAP=101 DEVBREW_DOCREVIEW_SUMMARY_WIDTH=501; do
    env "$kv" python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d" --snapshot "$s" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "2" "max: ${kv} 는 최댓값+1 이라 거부된다"
  done
  for kv in DEVBREW_DOCREVIEW_DETECTORS=6 DEVBREW_DOCREVIEW_REREVIEW_CAP=10 DEVBREW_DOCREVIEW_RENDER_CAP=100 DEVBREW_DOCREVIEW_SUMMARY_WIDTH=500; do
    local d2; d2="$(mk_state "$FX/design-sample.md" "$PROF_SD/design-doc.md")"
    env "$kv" python3 "$SCRIPTS/docreview_state.py" begin-round --state-dir "$d2" --snapshot "$s" >/dev/null 2>&1; rc=$?
    assert_eq "$rc" "0" "max 양성 짝: ${kv} 는 최댓값 그대로라 받는다"; rm -rf "$d2"
  done
  rm -rf "$d"
}
```

더해서 같은 케이스 안에 (a) 프로필 값 — 프로필 사본의 `rereview_cap: 11` 이 `load_profile` 에서 `config_invalid` 이고 그 메시지에 `1~10` 이 아니라 `0~10` 이 든다(`rereview_cap` 의 최솟값은 0), (b) 진입 값 — `begin-round --detectors 7` 이 rc 2 · `"where": "진입"`, (c) `advice --cap 101` 이 rc 2 `config_invalid` 이고 `advice --cap 100` 은 그 사유로 거부되지 않는다를 단언한다. 프로필 사본은 `mktemp -d` 안에서 `sed` 로 만든다.

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash shared/tests/test_docreview_state.sh 2>&1 | grep -E '✗ max'`
Expected: `max: 최댓값을 넘는 환경 값은 라운드를 시작하지 않는다` 등 RED(지금은 500 을 받는다).

- [ ] **Step 3: 구현한다** — `docreview_config.py` 에 `MAXIMUM` 과 `allowed_range(name)` 을 두고 `_int` 가 `v < MINIMUM[name] or v > MAXIMUM[name]` 이면 `ConfigInvalid`. 모듈 docstring 의 「최솟값보다 작으면」 을 「허용 범위 밖이면」 으로. `docreview_state.py` 의 `fail("config_invalid", …)` 두 자리에 `allowed=_cfg.allowed_range(e.name)` 를 더하고, `load_profile` 의 `ProfileError("config_invalid:%s=%r")` 에 범위를 붙인다(`config_invalid:%s=%r(허용 %s)`). `cmd_advice` 에서 `a.cap` 이 주어졌고 `MAXIMUM["render_cap"]` 을 넘으면 `fail("config_invalid", name="render_cap", value=str(a.cap), where="진입 --cap", allowed=…)` 뒤 rc 2.

- [ ] **Step 4: README 범위를 공시한다** — spec-distill README `DEVBREW_DOCREVIEW_*` 표의 「(1 이상)」 류를 「(1~6)」 · 「(0~10, 0 이면 재리뷰 없음)」 · 「(1~100)」 · 「(1~500)」 로 바꾸고 표 아래 한 줄: 「범위 밖 값은 라운드를 시작하지 않고 이름 · 값 · 허용 범위 · 출처를 보인다.」

- [ ] **Step 5: 돌려 통과를 본다** — 같은 명령에서 `✗` 0. 락 지도의 R12 행 넷도 돈다.

Run: `bash shared/tests/test_docreview_state.sh && bash shared/tests/test_docreview_advice.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_docreview_profiles.sh`
Expected: PASS(골든 diff 없음).

- [ ] **Step 6: 커밋** — `git commit -m 'fix(docreview): 엔진 값에 최댓값 — 범위 밖이면 이유와 함께 거부' -- shared/docreview/scripts/docreview_config.py shared/docreview/scripts/docreview_state.py shared/tests/fixtures/docreview/cases.sh shared/tests/test_docreview_state.sh plugins/spec-distill/README.md`(qg README 를 고쳤으면 더한다)

---

### Task 2: 불변 절은 「새 항목만 추가」 (AC2)

**Files:**
- Modify: `shared/docreview/scripts/docreview_anchor.py`(`parse_sections` · `cmd_diff`) · `shared/docreview/scripts/docreview_state.py`(`_appended_only` · `cmd_begin_round`)
- Create: `shared/tests/fixtures/docreview/brief-append-r2-cont.md` · `brief-append-r2-blank.md`
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_route.sh` 또는 `test_docreview_state.sh`(기존 `case_AC14_append_only_passes` 가 등록된 쪽에 등록)

**Interfaces:**
- Produces: 스냅숏 절의 `item_marks: str` — `line_hashes` 와 같은 길이, 줄마다 `"1"`(0열 `- ` 로 시작) 또는 `"0"`. `_appended_only(old_sec, new_sec) -> bool` 의 뜻이 「옛 줄 해시가 앞부분이고, 덧붙은 꼬리의 첫 내용 줄(빈 줄을 건너뜀)이 `item_marks` 에서 `1`」 로 좁아진다.

- [ ] **Step 1: 픽스처를 만든다** — `brief-append-r2-cont.md` 는 `brief-append-r1.md` 의 §6 마지막 `S<N>` 항목 바로 밑에 들여쓴 인용 줄 `  > 이어 쓴 인용` 하나를 붙인 것, `brief-append-r2-blank.md` 는 빈 줄 하나 뒤 새 항목 `- **S3** 「셋째 말」` 을 붙인 것이다.

- [ ] **Step 2: 실패하는 케이스를 쓴다** — 기존 `case_AC14_append_only_passes` 의 꼴(두 라운드 · `exempt-anchors`)을 따라 `case_AC2_append_new_item_only` 를 더한다.

단언:
- `brief-append-r2.md`(0열 새 항목) → 그 라운드 얼림 diff 의 `#6-…` 절이 `exempt_applied` 에 `scope: append-only` 로 있다(양성).
- `brief-append-r2-blank.md`(빈 줄 뒤 새 항목) → 같은 면제(양성).
- `brief-append-r2-cont.md`(들여쓴 이어 쓴 줄) → `#6-…` 이 `changed` 에 있다(음성 — 지금은 면제된다).
- 스냅숏 JSON(`docreview_anchor.py snapshot`)의 각 절에 `item_marks` 가 있고 길이가 `line_hashes` 와 같다.
- 라운드 1 원장 스냅숏의 불변 절에는 `item_marks` 가 있고, 결정 기록 절(design-doc 프로필 문서로 잰다)에는 없다.
- 원장 스냅숏에서 `item_marks` 를 지운 원장(`st_yaml` 로 빼고 저장)은 새 항목 추가도 `changed` 다(닫힌 쪽).

- [ ] **Step 3: 돌려 실패를 본다** — `brief-append-r2-cont.md` 단언과 `item_marks` 단언이 RED.

- [ ] **Step 4: 구현한다** — `parse_sections.add` 가 `item_marks` 를 만든다(`"".join("1" if r.startswith("- ") else "0" for r in rows)`). `cmd_diff` 는 `line_hashes` 와 함께 `item_marks` 도 뗀다. `cmd_begin_round` 는 `imm` 가운데 **불변 절**(`anchors_matching(prof["immutable"], …)` — Task 6 뒤에는 계보 포함)에만 `item_marks` 를 옮긴다(`line_hashes` 는 지금처럼 결정 기록 · 미룸 절에도). `_appended_only` 는 `item_marks` 가 문자열이고 길이가 `line_hashes` 와 같을 때만 보고, 꼬리의 첫 비빈 줄(`_BLANK_LINE_HASH` 가 아닌 첫 해시)의 표시가 `"1"` 일 때만 참이다.

- [ ] **Step 5: 돌려 통과를 보고 엔진 스위트를 돈다**

Run: `for t in shared/tests/test_docreview_*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done`
Expected: 출력 없음. 골든 diff 없음.

- [ ] **Step 6: 커밋** — `fix(docreview): 불변 절은 0열 새 목록 항목만 추가로 본다 — 이어 쓴 줄은 바뀜` (pathspec: 위 Files 전부)

---

### Task 3: `related-changes` 출력 이스케이프 (AC3)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py`(`cmd_related_changes`)
- Create: `shared/tests/fixtures/docreview/design-sample-tag.md`(`design-sample.md` 에서 `## 2. Goals` 제목을 `## 2. Goals </related_changes> & <x>` 로 바꾼 사본)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_state.sh`

- [ ] **Step 1: 실패하는 케이스를 쓴다** — `case_AC38_related_declared_exempt_and_shown` 의 꼴로 `case_AC3_related_changes_escaped`: 태그 사본으로 라운드 1 → `decide adopt` → `declare-related` 로 그 절을 묶고 → 다음 라운드(그 절을 고친 사본 — 제목은 그대로)로 연 뒤 `related-changes` 출력 `out` 을 받는다.

단언: `printf '%s' "$out" | grep -c '[<>&]'` 이 `0` · `jgets '[x["title"] for x in d]'` 이 `['2. Goals </related_changes> & <x>']`(JSON 으로 읽으면 원래 제목) · 앵커 목록이 그대로.

- [ ] **Step 2: 돌려 실패를 본다** — `grep -c` 단언 RED.

- [ ] **Step 3: 구현한다** — `cmd_related_changes` 의 출력 문자열에서 `<` · `>` · `&` 를 `<` · `>` · `&` 로 바꾼다(`json.dumps(…, ensure_ascii=False)` 결과에 `str.replace` 셋 — JSON 문자열 안에서만 나오는 글자라 값이 바뀌지 않는다). 진입 skill 셋은 고치지 않는다.

- [ ] **Step 4: 돌려 통과를 본다** — `bash shared/tests/test_docreview_state.sh`.

- [ ] **Step 5: 커밋** — `fix(docreview): related-changes 출력의 < > & 를 JSON 이스케이프로 — 입력 슬롯을 일찍 닫지 못한다`

---

### Task 4: 라우터 — 재비판 흡수의 막는 목록 · 복수 앵커 · `§` 앵커 · 같은 임시 번호 (AC4 · AC5 · AC6 · AC7)

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py`(`_absorb_same_as` · `normalize` · `merge_list_blocks`)
- Create: `shared/tests/fixtures/docreview/critic-multi-anchor.txt` · `critic-dupref.txt`
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_route.sh`

**Interfaces:**
- Consumes: `docreview_state._SLUG_STRIP`(import 한다 — 엔진 slug 와 같은 문자 제거).
- Produces: `normalize` 가 `edit_scope` 에 앵커가 둘 이상이면 `ledger.hold(tag, "항목 파손: edit_scope_multi_anchor")` 후 `None`. `anchor` · `edit_scope` 의 앵커 글자에 `#` 뒤만 `_SLUG_STRIP` 를 적용하고 바뀌면 `ledger.coerced("anchor"|"edit_scope", 원래, 바뀐 값)`(gate=False). `merge_list_blocks` 가 한 블록 안에서 같은 `ref` 를 두 번째로 쓴 항목은 `ev("hold", "<name>#b<k>:<ref>", "항목 파손: duplicate_ref")` 후 버린다.

- [ ] **Step 1: 실패하는 케이스 넷을 쓴다** (모두 `test_docreview_route.sh` 목록에 등록)

1. `case_AC4_recritic_same_as_keeps_blocks` — `case_same_as_merge_counts_blocked_fix_once` 의 꼴로 critic 출력에 fix 둘(`c1` · `c2`)과 ask 둘(`c3` 이 `blocks: [c1]` · `c4` 가 `blocks: [c2]`, 요약은 같은 질문을 다르게 쓴 것)을 두고, 재비판이 `c4` 의 f 를 `same_as: [<c3 의 f>]` 로 묶는다. 단언: `fin.json` 의 남은 ask(`category` 로 고른다) 하나의 `blocks` 가 두 fix 의 id 를 **둘 다** 담는다(지금은 하나).
2. `case_AC5_multi_anchor_held` — `critic-multi-anchor.txt`(층 2 항목 하나의 `edit_scope: "#2-goals, #3-non-goals"`). 단언: `prep.json` 의 항목 수에 그 항목이 없다 · `fin.json` `adjudication_held` ≥ 1 · `blocks` 가 `True` · `advisory` 에 `edit_scope_multi_anchor` 가 든 줄 · `gate --render` 출력에 `edit_scope_multi_anchor` 가 보인다. 공백만으로 이은 꼴(`"#2-goals #3-non-goals"`)도 같다. 양성 짝: `insert-after:#2-goals` 한 앵커는 보류되지 않는다.
3. `case_AC6_section_sign_anchor_normalized` — `design-sample.md` 에 `### §B 부분` 절을 더한 사본으로 라운드 1, 리뷰어 항목 `anchor: "#§b-부분"` · `edit_scope: "#§b-부분"`(fix). 단언: `fin.json` 의 그 지적 `anchor` 가 엔진 앵커(`docreview_anchor.py snapshot` 이 낸 그 절의 앵커 — 하드코딩하지 말고 스냅숏에서 읽는다)와 같다 · `adjudication_coerced` 가 1 늘었다 · `check-intent <id> --intent <엔진 앵커>` 가 `ok: true` 이고 다음 라운드에 `expired` 나 재상승으로 돌지 않는다(`gate` JSON 의 `expired` · `blocked_expired` 가 비었다). `bash shared/tests/test_docreview_golden.sh` 가 그대로 GREEN.
4. `case_AC7_duplicate_ref_in_block_held` — `critic-dupref.txt`(한 층 2 블록에 `ref: c1` 두 항목, 요약이 다르다). 단언: `prep.json` 에 둘째 항목 요약이 없다 · `fin.json` `advisory` 에 `duplicate_ref` · `adjudication_held` ≥ 1. 양성 짝: 기존 `case_same_name_blocks_ref_collision`(블록 사이 겹침은 `@b<k>` 로 푼다)이 그대로 GREEN.

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash shared/tests/test_docreview_route.sh 2>&1 | grep -E '✗ (AC4|AC5|AC6|AC7)'`
Expected: 넷 다 RED.

- [ ] **Step 3: 구현한다** — `_absorb_same_as`: 빈 산문 칸을 채우는 루프 옆에서 생존자 `items[keep]["blocks"]` 에 흡수된 구성원(`m != keep`)의 `blocks` 를 순서대로 중복 없이 더한다(`cmd_prepare` 흡수와 같은 규칙). `break` · `continue` · 걸러 내는 컴프리헨션을 쓰지 않는다(배선 락이 버리는 분기로 읽는다). `normalize`: `edit_scope` 를 `re.split(r"[,\s]+", …)` 로 나눠 `#` 또는 `insert-after:#` 로 시작하는 조각이 둘 이상이면 보류. 앵커 정규화는 보류 판정 뒤에. `merge_list_blocks` 1 걸음: 블록 안 `ref` 집합을 두고 이미 본 `ref` 의 새 항목(글자까지 같은 흡수 항목은 제외)은 보류하고 `continue`.

- [ ] **Step 4: 돌려 통과를 보고 라우터 스위트 · 골든을 돈다**

Run: `bash shared/tests/test_docreview_route.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_docreview_mutations.sh`
Expected: PASS. 배선 락(`shared/tests/test_adjudication_wiring.sh`)은 Task 5 에서 맞춘다 — 여기서 RED 면 그 이름을 적어 둔다.

- [ ] **Step 5: 커밋** — `fix(docreview): 재비판 흡수가 막는 목록을 잇고 복수 앵커 · 같은 임시 번호는 보류, § 앵커는 엔진 slug 로`

---

### Task 5: 흡수 분기의 배선 락 (AC8)

**Files:**
- Modify: `tools/adjudication/check_wiring.py`(`_disposition_calls` · 계획 3 미머지면 `EXEMPT` 줄 번호) · `shared/docreview/scripts/docreview_route.py`(`merge_list_blocks` · `cmd_prepare` 의 흡수 분기를 `continue` 로)
- Test: `shared/tests/test_adjudication_wiring.sh`

**Interfaces:**
- Produces: `_disposition_calls(node)` 가 `X.<처분>(…)` 에 더해 `ast.Call` 의 `func` 가 `ast.Name` 이고 첫 인자가 `DISPOSITION` 에 든 문자열 상수인 호출도 낸다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `test_adjudication_wiring.sh` 에 두 단언: (a) 스캔 행 가운데 `func == "merge_list_blocks"` 이고 `kind == "continue"` 인 행이 있고 모두 `guarded`, `func == "cmd_prepare"` 의 흡수 분기(가드 글자에 `first` 가 든 행) 하나가 `guarded`. (b) 변이 프로브 — 테스트가 `mktemp` 사본에 `docreview_route.py` 를 복사해 흡수 분기의 `ev("absorbed", …)` 줄을 지운 뒤(`python3 -I` 로 정확한 줄을 찾아 지운다 — 줄 번호를 박지 않는다) 그 사본을 `check_wiring.scan` 에 넣으면 `unwired` 에 그 행이 나온다.

- [ ] **Step 2: 돌려 실패를 본다** — (a) RED(지금 흡수 분기에는 `continue` 가 없다).

- [ ] **Step 3: 구현한다** — `_disposition_calls` 넓히기. `merge_list_blocks` 1 걸음의 흡수 분기를 `ev("absorbed", …)` · `plan.append((None, None))` · 참조 이어 주기 뒤 `continue` 로 끝낸다(else 갈래를 들여쓰기 없이 뒤로). `cmd_prepare` 의 리뷰어 사이 겹침 루프도 `if first is None: …; continue` / `if first["detector"] == it["detector"]: deduped.append(…); continue` / 흡수 본문(`ev("absorbed", …)` 와 막는 목록 · 빈 칸 잇기) 뒤 `continue` 꼴로 바꾼다 — 동작은 같다.

- [ ] **Step 4: EXEMPT 를 맞춘다** — Task 0 Step 2 에서 계획 3 이 머지돼 있었으면 건너뛴다. 아니면 `bash shared/tests/test_adjudication_wiring.sh` 의 `exempt_stale` 이름을 보고 `docreview_route.py` 키의 줄 번호만 실측으로 다시 박는다(가드 글자 · 사유 무변경). escalated · reraise 예약 두 자리(`continue in _auto_decides @ if not f0`)는 순서로 짝짓고 코드에서 `esc_unconsumed` · `reraise_unconsumed` 블록을 읽어 확인한다(파일 안 「재앵커 함정」 문단).

- [ ] **Step 5: 돌려 통과를 본다**

Run: `bash shared/tests/test_adjudication_wiring.sh && bash shared/tests/test_adjudication_consumed.sh && bash shared/tests/test_docreview_route.sh && bash shared/tests/test_docreview_golden.sh`
Expected: PASS · `exempt_stale=0` · `unwired=0`.

- [ ] **Step 6: 커밋** — `test(adjudication): 흡수 분기의 ev 호출을 배선 락이 처분으로 센다`

---

### Task 6: 보호 · 불변의 계보 (AC9)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py`(`lineage_anchors` 새 함수 · `round_fence` · `scope_problem` · `cmd_begin_round` · `_immutable_adopt_anchors` · `_adopt_problem_for` · `cmd_declare_related`) · `shared/docreview/scripts/docreview_anchor.py`(`classify_anchor` · `cmd_check_intent`) · `shared/docreview/scripts/docreview_route.py`(`_classify_items` · `_auto_decides`)
- Modify: `plugins/spec-distill/README.md`(보호 한 줄)
- Create: `shared/tests/fixtures/docreview/design-sample-pushed.md`(`design-sample.md` 에서 `### 5.1 Parts` 바로 앞에 `## 6. Inserted` 제목과 본문 한 줄을 넣은 사본) · `design-sample-pushed-r3.md`(그 사본에서 `### 5.1 Parts` 본문 한 줄을 고친 것) · `design-sample-pushed-r4.md`(r3 에서 같은 절을 한 번 더 고친 것)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_state.sh` · `test_docreview_route.sh`

**Interfaces:**
- Produces: `docreview_state.lineage_anchors(st, prof, key: str, upto: int) -> set` — `key` 는 `"protected_headings"` 또는 `"immutable"`; 원장 스냅숏 `1..upto` 를 뒤에서부터 걸으며(`_expected_lines` 의 걷기 꼴) 그 스냅숏에서 `anchors_matching(prof[key], sections)` 에 든 앵커 전부. 프로필 목록이 비면 빈 집합.
- `classify_anchor(anchor, sections, prof, lineage=None) -> dict` — `lineage` 는 `{"protected": set, "immutable": set}` 이고 주어지면 지금 스냅숏 판정과 합친다(OR). `cmd_protected` CLI 는 계보 없이 부른다.
- `scope_problem(scope, sections, prof, immutable_lineage=frozenset())` — 불변 판정에 계보 집합을 합친다.
- `_immutable_adopt_anchors(prof, sections, immutable_lineage=frozenset())` — 울타리와 계보 불변을 뺀다.
- `round_fence(st, prof, r)` = 지금 값 ∪ `lineage_anchors(st, prof, "immutable", r)`.

- [ ] **Step 1: 실패하는 케이스 셋을 쓴다**

1. `case_lineage_protected_child_pushed_out` — 라운드 1(`design-sample.md`), decide 지적(`anchor: "#5-architecture"`, `edit_scope: "insert-after:#5-architecture"`)을 심어 `decide adopt` → 라운드 2(`design-sample-pushed.md`). 단언: 라운드 2 스냅숏에서 `#51-parts` 의 `parents` 에 `#5-architecture` 가 없다(전제) · fix 지적(`anchor: "#51-parts"`)을 심어 `check-intent <id> --intent '#51-parts'` 가 rc 1 · `reason: anchor_protected` · `gate` 의 `escalated` 에 든다 · 같은 문서로 `docreview_anchor.py protected '#51-parts' --profile … --snapshot <라운드 2 스냅숏>`(계보 없음)은 `protected: false`(대조 — CLI 는 스냅숏만 본다).
2. `case_lineage_routing_and_intent_agree` — 위 원장의 라운드 2 에서 리뷰어가 `#51-parts` 에 `fix` 를 내는 critic 출력으로 `prepare-recritic` · `finalize`. 단언: 그 지적이 `decide`(`promotion: protected`)로 올라간다.
3. `case_lineage_adopt_once_then_ask_again` — 라운드 2 에서 `#51-parts` 를 겨눈 decide 를 채택(라운드 3 permit) → 라운드 3(`design-sample-pushed-r3.md`) 의 얼림 diff 에 `#51-parts` 가 `changed` 에 없다(허가된 그 변경) → 라운드 4(`design-sample-pushed-r4.md`) 의 `finalize` 가 `#51-parts` 의 `frozen_change` decide 를 층 1(`layer: 1`)로 낸다(다음 변경은 다시 묻는다, U6).

불변 쪽: brief 프로필(`^6\.`)로 §6 의 하위 절이 제목 삽입으로 밀려난 사본을 만들어 `round_fence` 가 그 하위 절을 계속 담고 `begin-round` 가 그 절의 `line_hashes` · `item_marks` 를 원장에 옮기는지 `case_lineage_immutable_child_fenced` 로 단언한다.

- [ ] **Step 2: 돌려 실패를 본다** — 1 의 `anchor_protected` · 2 의 승격 · 불변 케이스가 RED.

- [ ] **Step 3: 구현한다** — `lineage_anchors` 를 두고 Task 0 Step 3 의 자리 전부가 그것을 지나게 한다: `cmd_check_intent` 는 `lineage={"protected": lineage_anchors(st, prof, "protected_headings", n), "immutable": lineage_anchors(st, prof, "immutable", n)}` 로 `classify_anchor` 를 부르고 `scope_problem` 에 불변 계보를 넘긴다. `_classify_items` · `_auto_decides` 도 같은 계보로 `classify_anchor` 를 부른다(`cmd_finalize` 가 한 번 계산해 넘긴다). `round_fence` · `cmd_begin_round` 의 `imm`(직전 라운드까지의 계보) · `_immutable_adopt_anchors` · `_adopt_problem_for` · `cmd_declare_related` 도 계보를 쓴다. 보호를 푸는 길은 만들지 않는다.

- [ ] **Step 4: 자리를 다시 센다** — Task 0 Step 3 의 `grep` 을 다시 돌려 모든 자리가 계보를 받거나(인자) 계보가 필요 없는 이유(`cmd_protected` CLI — 원장이 없다)가 그 자리 주석 없이도 이 계획에 적혀 있는지 확인한다. 빠진 자리가 있으면 케이스를 더하고 고친다.

- [ ] **Step 5: README 한 줄** — spec-distill README 의 리뷰 보호 설명 자리에 「한 번 보호된 절은 제목이 바뀌거나 다른 절 밑으로 밀려나도 보호가 이어지고, 이후 변경마다 다시 묻는다.」

- [ ] **Step 6: 돌려 통과를 본다**

Run: `for t in shared/tests/test_docreview_*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done; bash shared/tests/test_adjudication_wiring.sh`
Expected: 출력 없음 · 배선 PASS(줄이 밀렸으면 Task 5 Step 4 대로 다시 맞춘다).

- [ ] **Step 7: 커밋** — `fix(docreview): 보호 · 불변을 원장 스냅숏 계보로 — 밀려난 자식 절도 계속 묻는다`

---

### Task 7: finalize 를 두 번 불러도 같은 보고 (AC10)

**Files:**
- Modify: `shared/docreview/scripts/docreview_route.py`(`_build_report` · `cmd_finalize`)
- Modify: `shared/tests/fixtures/docreview/golden/case_*.state.md`(다섯 — 다시 뜬다)
- Test: `shared/tests/fixtures/docreview/cases.sh` · `shared/tests/test_docreview_route.sh`

**Interfaces:**
- Produces: 원장 `rounds[n].finalize_out` — 그 라운드 첫 성공 finalize 가 stdout 에 낸 객체 그대로. 둘째 호출: 준비가 없고(`no_pending_recritic`) `rounds[n].route_report` 와 `finalize_out` 이 있으면 `finalize_out` 을 같은 모양(`indent=1`)으로 stdout 에 내고 stderr 에 `[docreview] 이 라운드(<n>)는 이미 정리됐다 — 앞 finalize 의 보고를 다시 냈다` 한 줄, rc 0, `finalize_failed` 를 남기지 않는다.

- [ ] **Step 1: 실패하는 케이스를 쓴다** — `case_finalize_twice_same_report`: `route_r1` 로 라운드 1 을 끝낸 뒤(`$d/fin.json`) 같은 인자로 한 번 더 `finalize > "$d/fin2.json" 2> "$d/fin2.err"`. 단언: rc 0 · `cmp -s "$d/fin.json" "$d/fin2.json"` · `fin2.err` 에 「이미 정리됐다」 · `st_yaml` 의 `rounds["1"].get("finalize_failed")` 가 `None` · `gsum "$d" "$UNV3"` 가 `(None, None, True)`. 대조 둘: 기존 `case_T46_finalize_without_prepare_marks_round`(준비도 보고도 없으면 지금처럼 거부)와 `case_T46_stale_pending_refused`(다른 라운드 준비면 거부)가 그대로 GREEN.

- [ ] **Step 2: 돌려 실패를 본다** — 둘째 finalize rc 1 이라 RED.

- [ ] **Step 3: 구현한다** — `_build_report` 끝에서 `st["rounds"][str(n)]["finalize_out"] = out`. `cmd_finalize` 의 `pending_mismatch` 갈래에서 사유가 `no_pending_recritic` 이고 그 라운드 기록에 `route_report` 와 `finalize_out` 이 있으면 위 Interfaces 대로 다시 내고 return 0 — 원장을 저장하지 않는다.

- [ ] **Step 4: 골든을 다시 뜬다** — `bash shared/tests/fixtures/docreview/capture_finalize_golden.sh` 로 다섯 케이스를 다시 뜨고 `git diff --stat shared/tests/fixtures/docreview/golden/` 이 `*.state.md` 다섯만 바뀌었는지, 그 diff 가 `finalize_out:` 블록 더하기뿐인지 본다(`*.fin.json` · `*.gate.*` 무변경).

- [ ] **Step 5: 돌려 통과를 본다** — `bash shared/tests/test_docreview_route.sh && bash shared/tests/test_docreview_golden.sh && bash shared/tests/test_docreview_round_gate_split.sh`.

- [ ] **Step 6: 커밋** — 본문에 「골든 state 다섯이 바뀐 까닭: 둘째 finalize 가 같은 보고를 내려면 첫 보고가 원장에 있어야 한다(라운드 기록의 finalize_out). fin.json · 게이트 골든은 그대로.」 `fix(docreview): finalize 두 번째는 같은 보고를 rc 0 으로 — 미검증으로 닫지 않는다`

---

### Task 8: 리뷰가 닫힌 뒤 손으로 쓴 결정 줄 · 지휘 절차 걸음 4 ③ (AC11)

**Files:**
- Modify: `shared/docreview/scripts/docreview_state.py`(`RESERVED_SCOPES` · `cmd_advice` 의 계수 줄 기록 · `_log_verdicts` · `gate_summary` · `render_gate`)
- Modify: `plugins/spec-distill/references/conducting.md`(걸음 4 의 `- 기록:` 줄) · `plugins/spec-distill/references/redecompose.md`(§4 마지막 문장 「리뷰가 닫힌 뒤 … 알려진 열린 항목(받는 곳 R12 …)」)
- Test: `shared/tests/fixtures/docreview/cases_advice.sh`(계수 줄을 쓰는 끝맺음 흐름이 이 파일에 있다) · `shared/tests/test_docreview_advice.sh` · `plugins/spec-distill/tests/test_conducting_loop.sh` · `plugins/spec-distill/tests/test_conducting_reference.sh`

**Interfaces:**
- Produces: `engine_lines` 항목의 선택 칸 `kind: "count"`(계수 줄만). `_log_verdicts` 의 새 규칙 `"closed"` — 라벨 `closed-log`. `gate_summary(st)["closed_log_lines"]: list[str]`(이번 라운드에 기록으로 읽은 손 줄의 글 — 문서 결정 기록 절에서 해시로 찾은 글, 못 찾으면 `(지금 문서에 없는 줄)`). 렌더 줄: `리뷰가 닫힌 뒤 손으로 더한 결정 줄 N개 — 기록으로 읽었다` 다음에 그 줄들을 `  - ` 들여 싣는다.
- 규칙(설계 §4 · U5): 라운드 r 의 결정 기록 묶음 diff(스냅숏 r−1 → r)에서, 창 `[r−1, r)` 안에 `kind: count` 엔진 줄이 있고(리뷰가 r−1 뒤 닫혔다), 새 묶음 줄(절 순서대로 이은 `line_hashes`)이 옛 줄을 앞부분으로 가지며, 마지막 계수 줄 **아래**의 줄 가운데 엔진 줄이 아닌 것만 기록으로 읽는다. 마지막 계수 줄 위에 끼워 넣은 줄 · 옛 줄의 변경 · 다른 절 · 스냅숏 r 뒤에 더한 줄(다음 라운드 diff)은 지금처럼 `changed`.

- [ ] **Step 1: 실패하는 케이스를 쓴다** — `cases_advice.sh` 에 `case_closed_log_after_close_vs_after_begin`: must_catch 프로필(`$PROF_MC` design-doc)로 라운드 1 → `finalize` → 끝맺음(`advice --log-file "$doc"` — 계수 줄 기록) → 문서 결정 기록 끝에 손 줄 둘(`doc_append`) → `begin-round`(라운드 2 — 재리뷰 시작) → 손 줄 하나 더 → 라운드 2 `finalize`(라운드 2 diff 는 앞 두 줄만 담는다) → 라운드 3 `begin-round` → 라운드 3 `finalize`.

단언: 라운드 2 `fin.json` 에 결정 기록 절의 `frozen_change` decide 가 없다 · `gate` JSON `closed_log_lines` 가 손 줄 둘의 글 · `gate --render` 에 「리뷰가 닫힌 뒤 손으로 더한 결정 줄 2개 — 기록으로 읽었다」 · 라운드 3 `fin.json` 에 셋째 줄 때문에 결정 기록 절 `frozen_change` decide 가 있다(재리뷰 시작 뒤 줄은 묻는다).

음성 케이스 셋을 같은 파일에: `case_closed_log_inserted_above_count_asks`(계수 줄 위에 끼운 손 줄 → 라운드 2 에 `frozen_change`) · `case_closed_log_other_section_asks`(닫힌 뒤 다른 절 손 편집 → `frozen_change`) · `case_closed_log_old_ledger_asks`(`engine_lines` 의 `kind` 를 지운 원장 → 손 줄 둘도 `frozen_change` — 닫힌 쪽).

- [ ] **Step 2: 지휘 절차 단언을 먼저 바꾼다** — `test_conducting_loop.sh:80` · `test_conducting_reference.sh:80-81` 의 ③ 문장 단언을 아래 새 ③ 으로, `once 4 '리뷰가 열려 있거나 원장이 남은 문서의 …'` 를 「리뷰가 열려 있는 문서의 `## 결정 기록` 에는 손으로 쓰지 않는다」로 바꾸고, 옛 문장(「사용자 원문과 함께 `## 지휘 기록` 에 둔다」)의 부재 단언을 하나 더한다.

새 ③: `③ 리뷰가 닫혔으면 `## 결정 기록` 절 끝(마지막 계수 줄 아래)에 손으로 쓴다 — 다음 재리뷰가 그 줄을 기록으로 읽는다(재리뷰를 시작한 뒤에 쓴 줄은 다시 묻는다)`

- [ ] **Step 3: 돌려 실패를 본다**

Run: `bash shared/tests/test_docreview_advice.sh 2>&1 | grep '✗'; bash plugins/spec-distill/tests/test_conducting_loop.sh 2>&1 | grep '✗'; bash plugins/spec-distill/tests/test_conducting_reference.sh 2>&1 | grep '✗'`
Expected: 새 케이스 · 새 문장 단언 RED.

- [ ] **Step 4: 구현한다** — `cmd_advice --log-file` 의 계수 줄 `engine_append` 직후 방금 더한 `engine_lines` 항목에 `kind: "count"` 를 단다(`engine_append` 에 `kind=None` 선택 인자를 더해 거기서 단다). `_log_verdicts` 의 `o is not None` 갈래에서 `_log_change_ok` 가 거짓이면 새 판정 `_closed_change_ok(st, h, o_lh, n_lh, r, group_new) -> list | None` 을 부른다(받은 손 줄 해시 목록이면 `out[a] = ("closed-log", "closed")`). `gate_summary` 는 `_log_check_skipped` 꼴로 이번 라운드의 `closed` 판정을 다시 계산해 해시를 문서 결정 기록 절(`section_body(Path(st["doc"]), heading)`)의 줄에서 찾아 글을 싣는다. 렌더는 게이트 앞부분의 공시 줄 묶음에 한 줄 + 들여 쓴 줄들. `conducting.md` 걸음 4 `- 기록:` 의 「리뷰가 열려 있거나 원장이 남은 문서의 …」 문장과 ③ 을 새 문장으로, `redecompose.md` §4 의 「리뷰가 닫힌 뒤 원장이 남은 문서에 손으로 쓴 줄은 … 알려진 열린 항목 …」 을 「리뷰가 닫힌 뒤에는 `## 결정 기록` 절 끝(마지막 계수 줄 아래)에 손으로 쓴다 — 다음 재리뷰가 그 줄을 기록으로 읽는다」로 바꾼다. 같은 옛 사실(「닫힌 뒤 … 다시 묻는다」 · 「받는 곳 R12」)을 적은 다른 자리를 찾아 함께 고친다:

Run: `git grep -n -e '닫힌 뒤' -e '받는 곳 R12' -e '알려진 열린 항목' -- plugins shared ':!*CHANGELOG.md'`

- [ ] **Step 5: 돌려 통과를 본다** — Step 3 명령에서 `✗` 0, 그리고 `for t in shared/tests/test_docreview_*.sh; do bash "$t" >/dev/null 2>&1 || echo "FAIL $t"; done` 출력 없음 · 골든 diff 는 Task 7 의 것뿐.

- [ ] **Step 6: 커밋** — `fix(docreview): 닫힌 리뷰 뒤 결정 기록 끝의 손 줄은 재리뷰가 기록으로 읽는다 — 지휘 절차도 그 자리에 쓴다`

---

### Task 9: 원장 쓰기 순서 락을 산문까지 (AC12)

**Files:**
- Modify: `plugins/spec-distill/tests/test_ledger_wiring.sh`(`GUARDED` 도출 · 산문 검사 · 음 · 양의 짝)
- Modify(락이 걸면): 도출된 코퍼스의 산문 문단 — 지금 트리 기대: `shared/docreview/references/reviewing-document.md` · `plugins/spec-distill/README.md` · 진입 skill 셋 · `skills/pm-interview/references/finishing.md`

**Interfaces:**
- Produces: 셸 함수 `derive_guarded` — `git -C "$ROOT_REPO" ls-files -s -- 'plugins/spec-distill/*.md'` 에서 `CHANGELOG.md` 를 빼고, mode `120000` 은 `readlink` 로 정본(레포 안 경로)으로 바꾸고, 내용에 `docreview_(state|route|anchor)` 가 있는 파일만 낸다(중복 제거). 셸 함수 `ac12_prose_scan <파일>` — 펜스 밖 산문을 문단(빈 줄 사이 블록 · 목록 안에서는 줄 머리 `- ` · `* ` · `<숫자>. ` 항목 하나)으로 나누고, 꼴 `docreview_state\.py[`"']*\s*(?:의\s*)?[`"']*\s*(declare-related|log-decision)(?![A-Za-z0-9-])` 가 든 문단이 `표지 확인 줄 다음에만` 을 담지 않으면 rc 1(문단 첫 줄을 stderr 에). 처분 줄(`**처분** —`)이 든 문단과 `**원장 쓰기 전 확인.**` 으로 시작하는 문단은 뺀다.

- [ ] **Step 1: 도출을 먼저 쓰고 대조한다** — `GUARDED="$(derive_guarded)"` 로 바꾸고 단언 둘: 도출에 `shared/docreview/references/reviewing-document.md` 가 든다 · 옛 목록 넷(`$SR $RB $FIN request-framing`)이 모두 든다. 도출 수가 0 이면 `no`(공허 방지).

- [ ] **Step 2: 산문 검사와 짝을 쓴다** — 도출된 파일마다 `ac12_prose_scan` 이 rc 0. 음성 프로브(각각 RED 여야 한다 — 임시 파일에 문단 하나): `docreview_state.py declare-related --state-dir D` · `` `docreview_state.py log-decision` `` · `` `docreview_state.py` 의 `declare-related` `` · `"$SD/scripts/docreview_state.py" log-decision` · `'docreview_state.py' declare-related` · 펜스 밖 한 줄 `python3 "$SD/scripts/docreview_state.py" log-decision --state-dir "$STATE_DIR"`(펜스에서 빼낸 호출). 양성 대조: 같은 문단들 끝에 「(진입 skill 의 표지 확인 줄 다음에만 부른다)」 를 붙이면 통과 · 하위 명령 이름만 적은 설명(`` `declare-related` 로 묶는다 ``)은 통과 · `check-intent` 꼴은 통과 · 처분 줄 문단은 통과. 엔진 쪽 음의 락: `grep -c 'reviewing-by' shared/docreview/scripts/*.py` 합이 0, 양의 짝: `plugins/spec-distill/scripts/ledger_marker.py` 에는 있다.

- [ ] **Step 3: 돌려 걸리는 자리를 본다**

Run: `bash plugins/spec-distill/tests/test_ledger_wiring.sh 2>&1 | grep '✗'`
Expected: 프로브 · 양성 대조는 기대대로. 지금 트리 파일 가운데 걸리는 자리(넓힌 `ac8_scan` 의 펜스 검사 포함)의 목록 — 그 목록이 이 과제의 고칠 자리다.

- [ ] **Step 4: 걸린 문단을 고친다** — 각 문단에 그 명령이 원장 쓰기이고 진입 skill 의 표지 확인 줄 다음에만 같은 Bash 호출에서 부른다는 문장을 넣는다(`reviewing-document.md:87-88` 의 문장 꼴). request-framing · reviewing-brief 는 걸린 문단만.

- [ ] **Step 5: 변이로 이빨을 본다**(커밋 뒤 clone 사본) — ① `reviewing-document.md:87` 의 「표지 확인 줄 다음에만」 구절을 지운다 → RED. ② `derive_guarded` 의 `120000` 갈래를 지운다 → 「도출에 reviewing-document.md 가 든다」 RED. ③ 꼴 정규식에서 `(?:의\s*)?` 를 지운다 → 「의」 프로브 RED. ④ 문단 나누기를 「빈 줄 사이만」 으로 바꾼다 → 목록 항목 프로브(규칙 문장이 옆 항목에만 있는 목록)가 RED.

- [ ] **Step 6: 커밋** — `test(spec-distill): 원장 쓰기 순서 락을 도출한 문서 전부의 산문까지 — 엔진은 표지를 모른다`

---

### Task 10: 손 편집의 허가 걸음 · 재분해 rc 1 가르기 (AC13 · AC16)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(「기타 칸 — 기각 번호 되돌리기」 문단) · `plugins/spec-distill/references/redecompose.md`(§4 「진행 중 에픽의 범위가 바뀌면」 줄 · §5 「적용」 뒤 rc 1 문단)
- Test: `shared/tests/fixtures/docreview/cases.sh`(끝에서 끝 픽스처) · `plugins/spec-distill/tests/test_finish_commit_roadmap.sh`(재분해 문면) · spec-review 문면을 읽는 테스트(`grep -l '기각 번호 되돌리기' plugins/spec-distill/tests/*.sh`)

- [ ] **Step 1: 끝에서 끝 케이스를 쓴다** — `case_AC13_table_row_with_adopted_decision`: 라운드 1 에 decide 를 심어 `decide adopt` → 문서의 다른 절(`#12-files-to-modify` — 표 행 대역)을 고친 사본 → 고치기 전에 `declare-related --decision D1.1 --anchors '#12-files-to-modify'` → 라운드 2 `finalize`. 단언: 라운드 2 `fin.json` 에 그 절의 `frozen_change` decide 가 없다 · 게이트에 「이 결정 때문에 함께 바뀐 곳」. 대조 `case_AC13_table_row_without_decision`: 채택 결정 없이 같은 절을 고치면 라운드 2 에 `frozen_change` decide 가 있다(허가 길이 없을 때의 지금 동작 — 절차가 그 사실을 알린다).

- [ ] **Step 2: 문면 단언을 쓴다** — spec-review 기각 되돌리기 문단에: 「표 행을 고치기 전에」 · `declare-related` · 「채택한 결정이 없으면」 + 「다음 게이트에 「허가 없이 바뀜」 결정으로 다시 온다」 를 사용자에게 알린다는 문장. `redecompose.md` §4 에 같은 걸음. `redecompose.md` §5 에: `brief §5 위험 줄 가운데 K 번호가 없는 줄` · `brief §5 위험 줄의 K 번호가 겹친다` 사유면 「표로 돌아가지 않고 멈추고 사유를 보인다」 · 「재분해는 이력 brief 를 고치지 않는다」 · `RISK_ORDER_NOTICE` 는 「정보 줄이라 멈추지 않는다」. 옛 단일 갈래 문장(「rc 1 — 사유를 그대로 보이고 3 으로 돌아간다」 가 위험 줄 사유까지 덮는 꼴)이 그 사유를 빼고 남는지 본다.

- [ ] **Step 3: 돌려 실패를 본다** — 문면 단언 RED · `case_AC13_table_row_with_adopted_decision` 은 지금도 GREEN 일 수 있다(엔진 길은 이미 있다 — 이 케이스는 절차가 가리키는 길이 실제로 닫히는지의 증거다).

- [ ] **Step 4: 절차를 고친다** — 기각 되돌리기: 「원장 열기를 다시 돈 뒤, 표 행을 고치기 전에 — 이 라운드 게이트에서 이 되돌림의 근거가 된 채택 결정이 있으면 `docreview_state.py declare-related --state-dir D --decision <D#> --anchors '<번호 대조 절 앵커>'` 로 그 절을 결정에 묶는다(원장 쓰기 — 진입 skill 의 표지 확인 줄 다음에만, 같은 Bash 호출에서). 채택 결정이 없으면 고친 행은 다음 라운드 게이트에 「허가 없이 바뀜」 결정으로 다시 온다 — 그 사실을 사용자에게 먼저 알리고 그 게이트에서 「고친 대로 둠」으로 닫는다.」 재분해 §4 줄에도 같은 걸음(묶을 절은 `## 미룸` · `## 결정 기록` 밖의 고친 절 — 결정 기록 · 미룸 절은 엔진 울타리라 묶을 수 없다는 점 포함). §5 rc 1 문단을 finishing B-R 처럼 가른다.

- [ ] **Step 5: 돌려 통과를 본다** — `bash shared/tests/test_docreview_state.sh && bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh && bash plugins/spec-distill/tests/test_ledger_wiring.sh`(새 산문이 펜스 락을 지난다).

- [ ] **Step 6: 커밋** — `docs(spec-distill): 표 행 손 편집 전 허가 걸음 · 재분해 rc 1 을 위험 줄 사유로 가른다`

---

### Task 11: 셸 대입 · 사용자 말 · 결정 줄 펜스의 레포 (AC14 · AC15)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md`(아홉 대입 지시 · 「경로 대입 줄」 정의 문단 · `decision-line` 펜스) · `plugins/spec-distill/references/redecompose.md`(§5 펜스의 `--approval`)
- Test: `plugins/spec-distill/tests/test_ledger_wiring.sh`(결정 줄 펜스 · 대입 꼴) · `plugins/spec-distill/tests/test_finish_commit_roadmap.sh`(재분해 펜스)

**Interfaces:**
- Produces: spec-review 의 「경로 대입 줄」 정의 — 변수마다

```bash
IFS= read -r spec_path <<'DEVBREW_PATH_EOF'
<경로 그대로>
DEVBREW_PATH_EOF
```

  (값에 구분 줄과 같은 줄이 있으면 구분자를 함께 바꾼다). 재분해 적용 펜스: 사용자 말마다 따옴표 heredoc → 임시 파일 → `--approval="$(cat "$AF<k>")"`(`=` 꼴).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

1. `case_path_assignment_hostile`(test_ledger_wiring.sh) — 레포 안에 이름이 `x'$(touch $T/pwned-p)`a"b` 인 폴더를 만들고 그 안 설계문서 경로로, spec-review 에서 뽑은 정의 꼴(테스트가 SKILL.md 의 「경로 대입 줄」 펜스를 마커로 뽑아 `<경로 그대로>` 자리를 채운다) + `ledger-open` 펜스를 한 Bash 호출로 돈다. 단언: `ledger-open: HELD` · `$T/pwned-*` 없음 · 원장의 `doc` 이 그 경로 글자 그대로.
2. 문면 단언: spec-review 에 `spec_path='<` · `bundle_arg='<` · `bundle_path='<` · `repo_root='<` 가 0건 · 「경로 대입 줄」 정의가 1건(음 · 양의 짝).
3. 재분해(test_finish_commit_roadmap.sh 의 표 heredoc 시험 꼴) — 사용자 말 `말 "따옴표" $(touch $T/pwned-a) \`touch $T/pwned-b\`` 로 적용 펜스를 돈다(생성기는 테스트 대역). 단언: 대역이 받은 `--approval` 값이 글자 그대로 · `pwned-*` 없음.
4. 결정 줄 펜스 cwd(test_ledger_wiring.sh 결정 줄 펜스 블록 끝) — `dl_run sess-eeee5555 "$ddoc" "$SD" "$T/other-repo"`(원장이 있는 레포가 아닌 다른 git 레포에서 돈다). 단언: rc 0 · `$ddoc` 에 그 결정 줄 한 줄 · 출력에 「다른 레포」 알림 · 그 레포의 `.claude/spec-distill` 에 아무것도 생기지 않는다. 기존 `dl_no_dir` 셋(상대 경로 · 상태 루트 실패 · 링크 밖)은 그대로 GREEN.

- [ ] **Step 2: 돌려 실패를 본다** — 1 · 2 · 3 · 4 RED(4 는 지금 「원장 없음 — 손으로 쓴다」).

- [ ] **Step 3: 구현한다** — spec-review `## 입력` 가까이에 「경로 대입 줄」 정의 문단 + 펜스(마커 `<!-- path-assign:begin/end -->`)를 두고 아홉 자리는 「펜스 앞에 `spec_path` 의 경로 대입 줄을 붙인다」 꼴로(`bundle_arg` · `bundle_path` · `repo_root` 도 같은 꼴, 빈 값이면 값 줄을 비운다). `decision-line` 펜스 첫머리: 절대 경로 확인(지금 문구 유지) 뒤 `here_top="$(git rev-parse --show-toplevel 2>/dev/null || true)"; cd "$(dirname "$spec_path")" || { …멈춤…; exit 1; }; doc_top="$(git rev-parse --show-toplevel)" || …멈춤…`, 둘이 다르면 `[spec-distill] 결정 줄은 문서가 사는 레포(<doc_top>)의 원장으로 쓴다 — 지금 작업 폴더의 레포(<here_top>)와 다르다.` 를 알린다. redecompose §5 펜스의 `--approval "<사용자 말 그대로>"` 를 말마다 heredoc 임시 파일로.

- [ ] **Step 4: 돌려 통과를 본다** — `bash plugins/spec-distill/tests/test_ledger_wiring.sh && bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh && bash shared/tests/test_inline_python_isolated.sh && bash shared/tests/test_skill_body_no_positional_tokens.sh`.

- [ ] **Step 5: 커밋** — `fix(spec-distill): 경로 · 사용자 말을 따옴표 heredoc 으로 받는다 — 결정 줄은 문서의 레포 원장으로`

---

### Task 12: 문서 · 버전 · 스위트 대조 · 변이 · AC 보고 (AC34 마감)

**Files:**
- Modify: `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/README.md`(Principles Instantiated) · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json` · 루트 `.claude-plugin/marketplace.json`(설명이 바뀔 때만)
- Modify: `docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md`(`## 미룸` 표 — 미룸 · 빠짐이 있을 때만)
- Create: `$HOME/.claude/sdd-mirror/r12-plan1/ac-report.md`(레포 밖 — git 이 추적하지 않는다)

- [ ] **Step 1: README · CHANGELOG · 버전** — spec-distill README `Principles Instantiated` 의 리뷰 엔진 줄에 한 구절(엔진 값 범위 · 「새 항목만 추가」 · 보호 계보 · 닫힌 뒤 결정 줄 · 원장 쓰기 순서 락이 산문까지). CHANGELOG 두 플러그인에 `## [<임시 판>] — <날짜>`: Fixed(AC1~AC11 · AC13~AC16 의 사람 말 요약) / Changed(conducting.md 걸음 4 ③ · redecompose rc 1) / Security(셸 대입 heredoc · `</related_changes>` 이스케이프). quality-gates CHANGELOG 는 「공유 리뷰 엔진 고침이 함께 실린다」 한 줄과 같은 Fixed 요약. plugin.json minor.

Run: `bash shared/tests/test_changelog_integrity.sh && bash plugins/spec-distill/tests/test_readme_sync.sh && bash plugins/spec-distill/tests/test_stale_terms.sh && bash shared/tests/test_invocation_surface.sh && bash shared/tests/test_copy_of_contract.sh`
Expected: PASS.

- [ ] **Step 2: 스위트를 기준선과 대조한다**(버릴 clone · 공유 스위트 잠금 아래)

Run: `python3 plugins/spec-distill/scripts/suite_lock.py run --lock <스위트 잠금 경로> --owner <agent 이름> --wait <초> -- bash -c 'cd <clone> && bash "$HOME/.claude/sdd-mirror/r12-plan1/baseline.sh" "$HOME/.claude/sdd-mirror/r12-plan1/after"'` 그다음 `comm -13 <(sort -u "$HOME/.claude/sdd-mirror/r12-plan1/before.names") <(sort -u "$HOME/.claude/sdd-mirror/r12-plan1/after.names")`
Expected: 새 실패 이름 0.

- [ ] **Step 3: 변이 기록을 모은다** — Task 1~11 의 락마다 변이 하나 이상(무엇을 바꿨고 어느 단언이 RED 였나)을 PR 본문 「변이 확인」 표로. 최소: `MAXIMUM` 한 값을 최솟값으로(Task 1) · `_appended_only` 의 표시 검사 지우기(Task 2) · 이스케이프 셋 중 하나 지우기(Task 3) · `_absorb_same_as` 의 blocks 합치기 지우기(Task 4) · `lineage_anchors` 가 빈 집합을 내게(Task 6 — 케이스 셋 RED) · `finalize_out` 저장 지우기(Task 7) · `kind: count` 표지 지우기(Task 8) · Task 9 Step 5 넷 · 「경로 대입 줄」 정의를 `spec_path='…'` 로 되돌리기(Task 11). 생존한 변이가 있으면 그 락을 고친 뒤에만 다음으로 간다.

- [ ] **Step 4: 마지막 전체 리뷰 — AC 보고** — 고른 실행 방식의 마지막 전체 리뷰 요청에 설계문서 `## Acceptance Criteria` 가운데 이 계획 몫 **AC1~AC16 · AC34** 의 원문을 그대로 싣고, AC 마다 한 줄 `AC<번호>: 구현됨 | 미룸 | 빠짐 — <근거>` 로 보고하게 한다. 같은 요청에 과제 사이 이음매(Task 6 계보와 Task 2 `item_marks` 가 `begin-round` 한 자리에서 만나는 것 · Task 7 `finalize_out` 과 Task 8 `gate_summary` 의 라운드 기록 공유 · Task 9 락과 Task 10 · 11 의 새 산문 · 종료 코드를 받는 쪽 · 상태 가정)와 「plan-mandated」 라벨을 단 계획 작성 테스트 코드를 묻는다. 보고를 `$HOME/.claude/sdd-mirror/r12-plan1/ac-report.md` 에 글자 그대로 쓴다.

- [ ] **Step 5: 미룸 표와 구현 대조** — 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 한 행씩 올린다. 그다음 지휘자가 준 spec-distill 플러그인 폴더(`<SD>` — 없으면 레포의 `plugins/spec-distill`)로:

Run: `python3 "<SD>"/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md "$HOME/.claude/sdd-mirror/r12-plan1/ac-report.md" --acs "AC1~AC16 · AC34"`
Expected: 첫 줄 `구현 대조: 경고 없음 …` 또는 경고 목록. 경고는 고치지 않고 마지막 보고에 그대로 싣는다(지휘자가 사용자에게 보인다).

- [ ] **Step 6: 커밋 · push**

```bash
git commit -m 'chore(spec-distill): R12 계획 1 — README · CHANGELOG · 판' -- plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/README.md plugins/quality-gates/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md
git push -u origin feature/review-engine-leftovers
```
PR 은 지휘자가 연다. 마지막 보고에: 판정 전체 · AC 보고 내용 전체 · `--impl` 첫 줄과 경고 · 커밋 목록 · 본 테스트 실패 이름 · 「설계 변경 보고 대상」 셋(이 계획 결정 3 · 4 · 8)의 구현 결과.
