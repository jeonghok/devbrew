# qg v10 ⑤ 차등 테스트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 차등 테스트 기계를 요구 R1~R24 를 지키는 얇은 새 기계로 갈아끼우고, 마지막 소비자와 함께 지워지는 부품(baseline-cache · 원장 · test-scope-validator · discover-plan · `--plan` · `DISABLE_SPEC_CONFORMANCE` · `spec_path`)을 지운다.

**Architecture:** `run-test-selection.sh`(어댑터 표의 유일 소유자)가 행을 **꼬리 줄 달린 행 파일**에 병합해 쓰고, `diff-test-results.py` 가 배정 파일 · 두 축의 행 파일을 직접 읽어 짝짓기와 집계를 한 번에 내며, 그 출력이 그대로 `verdict.py --differential` 로 간다. 세션을 넘는 캐시 대신 한 번의 `/qg` 동안만 사는 실행 안 메모(리포 밖 임시 디렉토리)를 `qg-worktree.sh memo-init/memo-drop` 이 관리한다. 오케스트레이터 절차는 `references/differential-test.md` 를 요구 목록 + D0~D8 짧은 절차로 제자리에서 다시 쓴다.

**Tech Stack:** bash 3.2(macOS 기본) · Python 3.9+ 표준 라이브러리 · git · `shared/tests/assert.sh`

**Spec:** `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` (§3 차등 테스트 · §6 · §7 ⑤ 행 · §요구 목록 R1~R24 · AC22 · AC23 · AC25 · AC27). 컷오버 사이 계약은 `docs/superpowers/plans/2026-10-08-qg-v10-00-index.md` 의 K-1~K-9 — 이 plan 은 그것을 다시 정의하지 않는다.

## 목차

- [Global Constraints](#global-constraints)
- [Review Focus](#review-focus)
- [이 plan 이 정한 것](#이-plan-이-정한-것)
- [요구 → 테스트](#요구--테스트)
- [옛 테스트의 처분](#옛-테스트의-처분)
- [파일 지도](#파일-지도)
  - [Task 0: Pre-flight — 분기 · 앞 컷오버 확인 · 기준 RED · 측정 도구](#task-0-pre-flight--분기--앞-컷오버-확인--기준-red--측정-도구)
  - [Task 1: `run-test-selection.sh` 다시 쓰기 ① — 어댑터 표 · detect · granularity](#task-1-run-test-selectionsh-다시-쓰기-①--어댑터-표--detect--granularity)
  - [Task 2: `run-test-selection.sh` 다시 쓰기 ② — assign 과 배정 파일](#task-2-run-test-selectionsh-다시-쓰기-②--assign-과-배정-파일)
  - [Task 3: `run-test-selection.sh` 다시 쓰기 ③ — run · unrun · pending 과 행 파일](#task-3-run-test-selectionsh-다시-쓰기-③--run--unrun--pending-과-행-파일)
  - [Task 4: `qg-worktree.sh` — 실행 안 메모 · 일회용 트리 재생성](#task-4-qg-worktreesh--실행-안-메모--일회용-트리-재생성)
  - [Task 5: `compute-test-scope-candidates.sh` 얇게 다시 쓰기](#task-5-compute-test-scope-candidatessh-얇게-다시-쓰기)
  - [Task 6: `diff-test-results.py` 다시 쓰기 — 짝짓기 · 집계 · 판정 입력 한 파일](#task-6-diff-test-resultspy-다시-쓰기--짝짓기--집계--판정-입력-한-파일)
  - [Task 7: 절차 문서 제자리 재작성 · SKILL 의 차등 절](#task-7-절차-문서-제자리-재작성--skill-의-차등-절)
  - [Task 8: 마지막 소비자와 함께 지우기 — 캐시 · 원장 · validator · plan 탐색](#task-8-마지막-소비자와-함께-지우기--캐시--원장--validator--plan-탐색)
  - [Task 9: 표면 정리 — `--plan` · `DISABLE_SPEC_CONFORMANCE` · `spec_path` · 옛 절차 문면 락](#task-9-표면-정리----plan--disable_spec_conformance--spec_path--옛-절차-문면-락)
  - [Task 10: 문서 · 버전 · AC23 · 전체 검증](#task-10-문서--버전--ac23--전체-검증)
- [plan 작성 때 확인한 것](#plan-작성-때-확인한-것)

## Global Constraints

- 이 PR 은 `main` 에서 분기한 독립 PR·릴리스다. ①~④ 가 머지된 뒤에 분기한다(색인 「계획 다섯」).
- 상태 폴더 표지는 K-1 「⑤ 뒤」 행이다: `SESSION_MARKERS = ("result.md",)`, `LEGACY_SESSION_MARKERS = ("files.md", "publish-eligible.md", "pipeline.md", "runtime-evidence.md")`.
- `discover-spec.sh` 의 stdout JSON 에서 `spec_path` 키만 지운다. `intent_source` · `intent_note` · `intent_file` 은 그대로다(K-5 ⑤ 줄).
- `verdict.py` 의 판정 어휘 · `CAUSE_TO_REASON` 은 바꾸지 않는다. 새 `diff-test-results.py` 의 `degrade_causes` 는 그 열거 안에서만 낸다.
- 판정 줄의 「차등 새 실패」 칸(K-3)은 새 출력의 `new_failures:` 값이다.
- kill switch: `DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 은 오케스트레이터(절차 D0)와 러너(`run-test-selection.sh run`) 양쪽에서 저장소 코드 실행을 막는다(R22). `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` 는 이 PR 에서 사라진다(spec §6 kill switch 표).
- 인자: `--plan` 은 「제거 안내 한 줄을 내고 끝난다」(AC25) — ① 이 `--pr-url` 등에 쓴 것과 같은 방식이다.
- 셸은 macOS bash 3.2 에서 돈다: `mapfile` 없음 · 한국어 글자 바로 앞 변수는 `${v}` · 파이프 rc 는 PIPESTATUS(zsh 에선 빈 값) 대신 캡처 후 판정.
- Python 은 3.9 에서 돈다: `from __future__ import annotations` 를 쓰고, 생성 파일은 `encoding="utf-8"` 로 읽고 쓴다.
- 테스트 이름에 요구 번호를 싣는다(`case_R7_…` · `test_R7_…`). 새 락 · 원장을 두지 않는다(spec K5) — 요구 번호 대조와 변이 확인은 커밋하지 않는 측정이다.
- persona 가 아닌 스크립트 재작성이지만 kill switch(R22) · 경로 탈출(R20) 코드를 다시 쓰므로 리뷰에 보안 각도를 포함한다.
- 리뷰 라운드는 최대 2(spec §7 공정). 같은 자리에 새 차단이 또 나오면 라운드를 더 돌지 않고 층위를 의심한다. 이 변경의 결함이 아닌 「새 장치 추가」 지적은 spec §7 다음 사이클 후보로 보낸다.
- 버전 번호는 머지 직전에 정한다. `--plan` 인자와 `DISABLE_SPEC_CONFORMANCE` 를 지우므로 major 다.

## Review Focus

이 spec 이 함의하지만 Task 의 테스트가 직접 두드리기 쉽지 않은 입력 다섯이다. 각 줄의 테스트는 해당 Task 에 들어 있다.

1. **이번 변경이 테스트 파일을 지웠다** — 지운 테스트가 후보로 들어와 HEAD 에 없으면(기준선 pass · HEAD absent) 조용한 clean 이 아니라 SILENT_DROP 으로 공시돼야 한다. → Task 6 `test_R7_deleted_test_is_silent_drop_not_clean`.
2. **Retry 로 배정이 바뀐 다음 iteration** — 메모에 남은 앞 iteration 의 기준선 행(이번 배정에 없는 unit)이 판정에 섞이면 안 된다. → Task 6 `test_R8_memo_rows_outside_this_assign_are_ignored`.
3. **아직 `git add` 하지 않은 새 테스트** — untracked 새 테스트도 후보이고, 분모(`--total`)에도 들어가 「N개 선택 (전체 M개 중)」 에서 N ≤ M 이어야 한다. → Task 5 `case_name_mapping_and_changed_tests` · `case_total_contains_every_candidate`.
4. **`TMPDIR` 이 리뷰 대상 리포 안** — 메모가 봉인(HEAD 축)에 섞이면 안 된다. → Task 4 `case_R6_memo_inside_the_tree_is_refused`.
5. **앞 실행이 중간에 죽어 일회용 트리가 남음** — 다음 실행이 「refuse to clobber」 로 영영 막히지 않고 그 트리를 지우고 다시 만들어야 한다. → Task 4 `case_R23_stale_tree_is_replaced`.

**리뷰를 거치지 않은 spec 문면(색인 끝 절)** — spec §3 의 `test-scope-validator` 행 교훈 칸 「부정 신호 — `outdated`/`cherry-pick` 으로 찍힌 테스트는 커버리지로 세지 않는다」. 9.3.6 `differential-test.md:242` 의 표와 일치한다(그 분류는 R2 산문 · gap 공시에만 쓰였고 판정 입력으로 읽히지 않았다). 이 plan 은 그 판단을 오케스트레이터에 옮기고(절차 D2), 그 목록을 `result.md` 에 공시한다. 리뷰어는 「후보는 바닥 — 더하기만」(R17)과 이 「돌리되 커버리지로 세지 않음」이 서로 어긋나지 않는지 본다.

## 이 plan 이 정한 것

spec 이 부품 처분만 정하고 구현을 맡긴 자리다. 바꾸려면 리뷰에서 근거와 함께 올린다.

| # | 결정 | 근거(요구) |
|---|---|---|
| P1 | 행 파일 4열(`unit · status · exit · mode`) + 꼬리 줄 `#qg-rows runner= commit= rows= flaky=`. `run` 이 행을 **파일에 병합**한다(같은 unit 은 교체) | R5(행이 나온 트리의 커밋을 기계가 대조) · R7(중복 없음) · R17(잘린 파일 ≠ 빈 결과) · R24(행을 모델이 옮겨 적지 않음) |
| P2 | 실행 방식을 **행마다** 기록하고, 도말 판정은 「양측 red 이면서 그 unit 의 어느 축 행이 bulk」 로 한다. `--baseline-mode`/`--head-mode` 인자는 없어진다 | R9 · R10 — 9.3.6 은 축 하나의 mode 를 보수적으로 접어, 기준선이 늘 bulk 로 시작하는 탓에 per-unit 으로 다시 확인한 양측 red 까지 `smeared` 로 막았다(R10 「과차단 방지」와 어긋남) |
| P3 | 입도는 `diff-test-results.py` 가 러너에서 도출한다(`--granularity` 인자 없음). 배정 파일의 입도 칸이 다르면 exit 4 | R9 |
| P4 | `--baseline-detected` · `probe` 를 없앤다. 기준선 행의 유효성은 꼬리 줄의 커밋 = `--baseline-commit` 대조로 판정한다 | R5 · R14 — 캐시가 사라져 「run 없이 행이 생기는」 경로가 없다 |
| P5 | 두 축의 트리가 같으면(`baseline^{tree} == head^{tree}`) 기준선 축을 unrun 으로 내린다 → baseline-unrunnable | R12 · R13 — 9.3.6 의 `same_as_head` · `worktree_dirty` 산문 표를 코드로 옮김 |
| P6 | flaky 재실행은 `run … flaky` 모드: 행 파일당 한 번(꼬리 `flaky=1`), 관측 못 하면 원래 행 유지, 기준선 pass 가 아닌 unit 의 flaky 행은 `diff-test-results.py` 가 exit 4 | R15 |
| P7 | 배정 파일 꼬리 줄 `#qg-assign adapters= rows=`. 미지원 후보(`unclaimed`)는 집계에서 `silent-drop`, 감지 0 은 `no-adapters`, claim 된 unit 0 은 `expected-empty` | R1 · R16 · R17 · R19 |
| P8 | 실행 안 메모는 `qg-worktree.sh memo-init/memo-drop` — 일회용 디렉토리를 다루는 기존 파일에 둔다. 리포 밖이 아니면 거부, 표지(`.qg-memo`) 없는 디렉토리는 지우지 않는다 | R6 |
| P9 | `create-baseline`/`create-head` 는 같은 자리에 남은 일회용 트리를 강제로 지우고 다시 만든다. ① 이 branch 모드(`create`)를 지워 그 이름공간을 사용자 worktree 가 나눠 쓸 길이 없어졌기 때문에 안전하다 | R23 |
| P10 | 후보는 `resolve-baseline.sh` 의 merge_base 대비 작업트리 + 무시되지 않는 untracked 다(9.3.6 은 미커밋 변경이 있으면 커밋된 브랜치 변경을 빠뜨렸다). 기준선 미확정은 exit 4. 토픽은 `--topic <boundary> <tree>` 로 스크립트가 직접 센다 | R11 · R17 |
| P11 | `run-test-selection.sh` 를 하위명령별 파일로 **나누지 않는다**(Deferred). 하위명령 여섯이 어댑터 표 · 경로 담김 검사를 함께 쓰고, 그 표의 유일 소유자가 한 파일이어야 소비자(오케스트레이터 · `diff-test-results.py` 의 입도 질의)가 한 곳을 부른다. 1006줄 → 664줄이고, 테스트는 하위명령 경계(`test_runner_adapters.sh` = detect · 관문, `test_run_test_selection.sh` = assign · 행 파일)로 나뉜다 | — |
| P12 | 출력에 `new_failures:`(NEW_REGRESSION + NEW_TEST_RED) · `unclaimed:` 목록을 더한다. `verdict.py` 가 읽는 `degrade_causes:` · `  confirmed_product_defect:` 는 여전히 파일에 정확히 한 번이다 | R24 · K-3 |

## 요구 → 테스트

AC22 의 관측표다. 「변이」 칸은 `r-mutations.py`(Task 0 이 만든 측정 도구, 커밋하지 않음)의 변이 ID 이고 그 변이에서 해당 테스트가 RED 여야 한다.

| 요구 | 테스트(파일 · 이름) | 변이 |
|---|---|---|
| R1 | `test_diff_test_results.py` `test_R1_zero_units_is_scope_empty` · `test_R1_zero_adapters_is_scope_empty` | R1 |
| R2 | `test_diff_test_results.py` `test_R2_pass_then_error_is_new_regression` · `test_R2_error_on_either_axis_blocks_certification` | R2 |
| R3 | `test_runner_adapters.sh` `case_R3_missing_toolchain_is_unrun` · `case_R3_setup_failure_is_unrun` · `case_R3_exit_127_is_unrun`, `test_diff_test_results.py` `test_R3_baseline_unrun_is_baseline_unrunnable` | R3 · R3s |
| R4 | `test_runner_adapters.sh` `case_R4_other_exit_is_error_not_unrun` | R4 |
| R5 | `test_run_test_selection.sh` `case_R5_rows_carry_their_tree_commit`, `test_diff_test_results.py` `test_R5_rows_from_another_commit_are_refused` | R5 · R5b |
| R6 | `test_differential_trees.sh` `case_R6_memo_lives_outside_the_tree` · `case_R6_memo_inside_the_tree_is_refused` · `case_R6_memo_drop_refuses_unmarked_dir` | R6 · R6b |
| R7 | `test_run_test_selection.sh` `case_R7_rerun_replaces_rows`, `test_diff_test_results.py` `test_R7_missing_row_is_silent_drop` · `test_R7_duplicate_row_is_exit_4` · `test_R7_deleted_test_is_silent_drop_not_clean` | R7 · R7b |
| R8 | `test_diff_test_results.py` `test_R8_expected_comes_from_assign_not_results` · `test_R8_memo_rows_outside_this_assign_are_ignored` | R8 |
| R9 | `test_diff_test_results.py` `test_R9_bulk_both_red_is_smeared_on_file_granularity` · `test_R9_bulk_granularity_both_red_degrades` · `test_R9_granularity_is_derived_from_runner` | R9 · R9b |
| R10 | `test_diff_test_results.py` `test_R10_per_unit_both_red_is_disclosed_not_blocked` | R10 |
| R11 | `test_run_test_selection.sh` `case_R11_run_refuses_live_tree` | R11 |
| R12 | `test_differential_trees.sh` `case_R12_head_axis_refuses_the_baseline_sha`, `test_diff_test_results.py` `test_R12_R13_same_tree_axes_are_not_comparable` | R12 · R13 |
| R13 | `test_diff_test_results.py` `test_R12_R13_same_tree_axes_are_not_comparable` · `test_R12_R13_positive_control_different_trees_compare` | R13 |
| R14 | `test_runner_adapters.sh` `case_R14_tree_without_adapter_is_unrun` | R14 |
| R15 | `test_run_test_selection.sh` `case_R15_flaky_rerun_once_and_keeps_unobserved` · `case_R15_flaky_rerun_unobserved_exit_keeps_row` · `case_R15_flaky_rerun_replaces_observed_row`, `test_diff_test_results.py` `test_R15_flaky_only_on_baseline_pass` · `test_R15_flaky_pass_is_noted_and_green` | R15 · R15b · R15c |
| R16 | `test_run_test_selection.sh` `case_R16_unhandled_candidate_is_unclaimed`, `test_diff_test_results.py` `test_R16_unclaimed_unit_blocks_certification` | R16 · R16b |
| R17 | `test_run_test_selection.sh` `case_R17_assign_writes_trailer` · `case_R17_failed_assign_leaves_no_file`, `test_compute_test_scope_candidates.sh` `case_R17_*`, `test_diff_test_results.py` `test_R17_*` | R17 · R17b · R17c |
| R18 | `test_differential_procedure.sh` `case_R18_failed_pairing_routes_to_error_axis` | R18 |
| R19 | `test_diff_test_results.py` `test_R19_missing_rows_file_for_an_assigned_runner_is_exit_4` · `test_R19_head_file_of_another_iteration_is_not_read` | R19 |
| R20 | `test_run_test_selection.sh` `case_R20_assign_refuses_units_outside_tree` · `case_R20_shell_scope` · `case_R20_run_rechecks_scope` | R20a · R20s · R20r · R20b |
| R21 | `test_run_test_selection.sh` `case_R21_unittest_refuses_unjudgeable_files` · `case_R21_go_unit_is_package`, `test_runner_adapters.sh` `case_R21_go_package_without_tests_is_absent` | R21 · R21g · R21b |
| R22 | `test_runner_adapters.sh` `case_R22_kill_switch_runs_no_repo_code`, `test_differential_procedure.sh` `case_R22_orchestrator_honors_kill_switch` | R22 · R22o |
| R23 | `test_differential_trees.sh` `case_R23_stale_tree_is_replaced` · `case_R23_remove_refuses_outside_namespace` | R23 |
| R24 | `test_diff_test_results.py` `test_R24_real_producer_output_reaches_verdict_without_transcription` · `test_R24_truncated_output_cannot_reach_clean`, `test_differential_procedure.sh` `case_R24_verdict_reads_the_machine_output` | R24 |

## 옛 테스트의 처분

9.3.6 기준 목록이다. ②~④ 가 이미 지웠거나 바꾼 것은 Task 9 의 열거 스크립트가 「이미 없음」으로 알린다.

| 파일(9.3.6) | 지키던 것 | 처분 |
|---|---|---|
| `test_run_test_selection.sh`(944줄) | assign · run · probe · 경로 담김 · 종료 코드 | **새로**(Task 2·3) — R5 · R7 · R11 · R15 · R16 · R17 · R20 · R21. `probe` 케이스(T70~T72)는 버림: probe 가 사라졌고 그 목적(캐시 적중 시 관문)은 캐시와 함께 없어졌다 — 지워도 조용히 통과하는 것 없음 |
| `test_runner_adapters.sh`(849줄) | 어댑터 9종 감지 · setup · 가용성 · 환경 디렉토리 | **새로**(Task 1·3) — 감지 표 + R3 · R4 · R14 · R21 · R22. `case_no_reimpl_in_skill`(SKILL 에 감지 표 재구현 없음)은 버림: 새 절차는 감지 표를 담지 않고, 담으면 R24 절차 락이 아니라 리뷰가 잡는다 — 지워도 판정이 조용히 통과하는 길은 없다 |
| `test_diff_test_results.py`(1178줄) | 16칸 귀속 · 도말 · 집계 · 인자 필수 | **새로**(Task 6) — R1 · R2 · R5 · R7~R10 · R12 · R13 · R15 · R16 · R17 · R19 · R24. 인자 필수 검사(`--baseline-mode` 등)는 인자가 사라져 버림 |
| `test_resolution_disclosure.sh` | 양측 red 공시 · 공시가 막지 않음 | **옮김** → `test_R10_per_unit_both_red_is_disclosed_not_blocked` · `test_R9_*`. 파일 삭제(Task 6) |
| `test_compute_test_scope_candidates.sh` | 이름 매핑 · 분모 · exit 4 | **새로**(Task 5) — R17 |
| `test_baseline_cache.sh` | 캐시 키 · 원자 쓰기 · fail 재검증 | **버림**(Task 8) — 캐시 삭제. 그 교훈(심은 pass · 세션 넘는 오염)은 R5 · R6 테스트가 진다 |
| `test_qa_ledger.sh` | 원장 구조 · 전사 대조 · unclaimed | **옮김** → R16(`test_R16_unclaimed_unit_blocks_certification`) · R24. 파일 삭제(Task 8) |
| `test_discover_plan.sh` | plan 탐색 | **버림**(Task 8) — 마지막 소비자(validator) 삭제 |
| `test_test_scope_validator_behavior.py` · `test_test_scope_validator_frontmatter.sh` · `tests/fixtures/test-scope/` | validator 분류 · frontmatter | **버림**(Task 8) — agent 삭제. 판단은 오케스트레이터 절차 D2 로 옮김 |
| `test_runtime_verdict_precedence.sh` | 옛 절차 문면(R-init 판별자 · probe · 원장 · 갭 게이트 · 6필드 산문) | **삭제**(Task 9) — 각 케이스의 요구는 위 「요구 → 테스트」 의 R3 · R5 · R13 · R14 · R15 · R16 · R18 이 행동으로 잰다. 6필드 산문 · 비용 신호 · 갭 게이트는 spec §3 이 지운 장치다 |
| `test_pipeline_verdict_wiring.sh` 의 `case_degraded_ledger_row_reaches_silent_drop` · `case_pre_r6_abort_*` · `case_r3_stop_choice_routes_to_error_axis` · `case_zero_adapter_aggregate_skips_glob` | 옛 R6·R8 라우팅 문면 | **케이스 삭제**(Task 9) → R16 · R18 · R1 |
| `test_topic_scope_wiring.sh` 의 옛 R-init·R1a·R1b·R4·R5b 문면 케이스 7개 | 토픽 경로의 옛 문면 | **바꿈**(Task 9) — 새 절차의 토픽 경로 한 케이스 + `case_topic_mode_reads_the_tree`(Task 5) |
| `test_one_pipeline_surface.sh` 의 reference 단계 집합 케이스 | 옛 단계 이름 | **바꿈**(Task 9) — D0~D8 |
| `test_verdict_vocabulary.sh` 의 `case_real_producer_per_adapter_feeds_verdict` · `case_real_producer_aggregate_feeds_verdict` | 옛 CLI 산출물 → verdict.py | **케이스 삭제**(Task 9) → `test_R24_*` · `test_R16_*` · `test_R3_*`(진짜 산출물이 verdict.py 로 간다) |
| `test_impact_runtime_docs.sh` `NEW_SCRIPTS` | 다섯 스크립트 실재 · README 등재 | **바꿈**(Task 9) — 셋 |

## 파일 지도

- 다시 씀: `plugins/quality-gates/scripts/run-test-selection.sh` · `scripts/diff-test-results.py` · `scripts/compute-test-scope-candidates.sh` · `skills/quality-pipeline/references/differential-test.md`
- 고침: `scripts/qg-worktree.sh`(메모 · 일회용 트리 재생성) · `scripts/discover-spec.sh`(`spec_path` 키) · `scripts/run_codex_reviewer.sh` · `scripts/build_codex_prompt.py`(`DISABLE_SPEC_CONFORMANCE`) · `scripts/qg-gc.py`(K-1) · `scripts/setup-qg.sh` · `commands/qg.md`(`--plan`) · `skills/quality-pipeline/SKILL.md`(`## Differential test` 절 · 옛 차등 토큰) · `skills/quality-pipeline/references/state-file-format.md` · `README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json`
- 새 테스트: `tests/test_differential_trees.sh` · `tests/test_differential_procedure.sh` · `tests/test_discover_spec_keys.sh`
- 다시 쓴 테스트: `tests/test_runner_adapters.sh` · `tests/test_run_test_selection.sh` · `tests/test_diff_test_results.py` · `tests/test_compute_test_scope_candidates.sh`
- 지움: `scripts/{baseline-cache.sh,check_qa_ledger.py,discover-plan.sh,discover_common.sh}` · `agents/test-scope-validator.md` · `tests/fixtures/test-scope/` · `tests/{test_baseline_cache.sh,test_qa_ledger.sh,test_discover_plan.sh,test_test_scope_validator_behavior.py,test_test_scope_validator_frontmatter.sh,test_resolution_disclosure.sh,test_runtime_verdict_precedence.sh}`
- 소비자 정리: `tests/{test_pipeline_verdict_wiring.sh,test_topic_scope_wiring.sh,test_one_pipeline_surface.sh,test_verdict_vocabulary.sh,test_impact_runtime_docs.sh,test_qg_gc.py,test_guards_declaration_mapping.sh,test_agent_model_mutation.sh,test_worktree.sh,test_law2_prose.sh,test_codex_runner_degrade_contract.sh,test_runtime_contract_invariance.sh,test_setup_qg.sh}` · `tests/harness/{agent_stub.py,test_skill_orchestration_behavior.sh}` · `tests/lib/reconstruct-skill.sh` · `shared/tests/test_plugin_root_no_cwd_fallback.sh`(하한, 필요할 때만)

**Task 사이 상태.** Task 1~3 은 `run-test-selection.sh` 를 갈아끼우고 Task 6 이 `diff-test-results.py` 를 갈아끼운다. 그 사이에는 옛 절차 문면을 재는 소비자 락(Task 9 대상)과 옛 CLI 를 쓰는 테스트가 RED 일 수 있다 — 각 Task 의 통과 기준은 그 Task 가 만든 테스트 파일이고, 스위트 전체 대조는 Task 10 이 한다.

**plan 이 쓴 테스트 코드.** 아래 테스트 전문은 plan 이 쓴 것이다. 리뷰어는 구현 코드만큼 테스트를 의심한다 — 특히 픽스처가 그 요구의 분기를 실제로 지나는지(각 Task 의 변이 단계가 그 증거다).

---

### Task 0: Pre-flight — 분기 · 앞 컷오버 확인 · 기준 RED · 측정 도구

**Files:**
- 리포 파일은 바꾸지 않는다. 측정 도구와 기록은 리포 밖 `$SCR` 에 둔다.

**Interfaces:**
- Consumes: ①~④ 머지 결과(색인 K-1 · K-5 · K-8).
- Produces: `$SCR/preflight-c5.sh` · `$SCR/baseline-red.sh` · `$SCR/baseline-red.tsv` · `$SCR/aliases-c5.sh` · `$SCR/aliases-before.txt` · `$SCR/r-mutations.py` · `$SCR/drop_cases.py` · `$SCR/old/{run-test-selection.sh,diff-test-results.py}` · `$SCR/ac23-compare.sh` · `$SCR/ac23-fixture.sh`. 뒤 Task 들은 이 경로를 그대로 쓴다.

`$SCR` 는 이 plan 전체에서 `${TMPDIR:-/tmp}/qg-c5` 다. 리포 안이면 안 된다(봉인 · 스캔에 섞인다). Bash 도구는 호출마다 새 셸이므로 **`$SCR` 를 쓰는 명령마다 앞에 `SCR="${TMPDIR:-/tmp}/qg-c5";` 를 붙인다.** 모든 명령은 리포 루트에서 돈다.

- [ ] **Step 1: main 에서 분기**

```bash
git fetch origin
git switch -c feature/qg-v10-differential origin/main
git log --oneline -1
SCR="${TMPDIR:-/tmp}/qg-c5"; mkdir -p "$SCR/old"; echo "$SCR"
```

Expected: 새 브랜치가 `origin/main` 끝에 있다. `$SCR` 가 리포 밖 절대 경로다.

- [ ] **Step 2: 앞 컷오버가 계약대로 들어왔는지 확인**

`$SCR/preflight-c5.sh` 를 아래 내용으로 만들고 리포 루트에서 돌린다:

````bash
#!/bin/bash
# preflight-c5.sh <repo-root> — ⑤ 착수 전 확인. 하나라도 ✗ 면 멈추고 보고한다(앞 컷오버가 계약대로 들어오지 않았다).
set -u
R=${1:?repo root}
Q="$R/plugins/quality-gates"
bad=0
chk() {   # chk <설명> <명령…> — 명령이 참이면 ✓
  local what=$1; shift
  if "$@" >/dev/null 2>&1; then echo "  ✓ $what"; else echo "  ✗ $what"; bad=1; fi
}
count() { grep -c -- "$1" "$2" 2>/dev/null || true; }
eq() { [ "$1" = "$2" ]; }
ge1() { [ "${1:-0}" -ge 1 ]; }

echo "## ① 정리"
chk "/cancel-qg 가 없다" test ! -e "$Q/commands/cancel-qg.md"
chk "qg-worktree.sh 에 branch 모드(create) arm 이 없다 — Task 4 의 강제 재생성 전제" eq "$(grep -cE '^  create\)' "$Q/scripts/qg-worktree.sh")" 0
chk "qg-worktree.sh 에 create-sandbox 가 없다" eq "$(count 'create-sandbox' "$Q/scripts/qg-worktree.sh")" 0
chk "qg-gc.py 가 result.md 를 안다" ge1 "$(count 'result.md' "$Q/scripts/qg-gc.py")"
echo "## ② 다이어트"
chk "code-recritic agent 가 있다" test -f "$Q/agents/code-recritic.md"
chk "discover-spec.sh 가 spec_path 를 아직 낸다(⑤ 가 지울 대상)" ge1 "$(count 'spec_path' "$Q/scripts/discover-spec.sh")"
chk "discover-spec.sh 가 discover_common.sh 를 더는 source 하지 않는다" eq "$(count 'discover_common' "$Q/scripts/discover-spec.sh")" 0
chk "SKILL.md 에 '## Differential test' 절이 정확히 하나" eq "$(grep -cx '## Differential test' "$Q/skills/quality-pipeline/SKILL.md")" 1
chk "SESSION_MARKERS 가 K-1 「② 뒤」 행" grep -qF 'SESSION_MARKERS = ("result.md", "runtime-evidence.md")' "$Q/scripts/qg-gc.py"
chk "LEGACY_SESSION_MARKERS 가 K-1 「② 뒤」 행" grep -qF 'LEGACY_SESSION_MARKERS = ("files.md", "publish-eligible.md", "pipeline.md")' "$Q/scripts/qg-gc.py"
echo "## ③ 게시"
chk "publish-comment.sh 가 있다" test -f "$Q/scripts/publish-comment.sh"
chk "SKILL.md 에 '## Publish' 절" eq "$(grep -cx '## Publish' "$Q/skills/quality-pipeline/SKILL.md")" 1
echo "## ④ e2e"
chk "e2e-state.sh 가 있다" test -f "$Q/scripts/e2e-state.sh"
chk "SKILL.md 에 '## e2e' 절" eq "$(grep -cx '## e2e' "$Q/skills/quality-pipeline/SKILL.md")" 1
chk "verdict.py 에 e2e-unconfirmed" ge1 "$(count 'e2e-unconfirmed' "$Q/scripts/verdict.py")"
echo "## ⑤ 가 바꿀 9.3.6 기계가 그대로다"
chk "baseline-cache.sh 가 아직 있다" test -f "$Q/scripts/baseline-cache.sh"
chk "test-scope-validator agent 가 아직 있다" test -f "$Q/agents/test-scope-validator.md"
chk "run-test-selection.sh 에 probe 가 아직 있다" ge1 "$(count '  probe)' "$Q/scripts/run-test-selection.sh")"
chk "verdict.py CAUSE_TO_REASON 이 일곱 원인을 안다" python3 - "$Q/scripts" <<'PY'
import sys; sys.path.insert(0, sys.argv[1]); import verdict
need = {"expected-empty", "no-adapters", "baseline-unrunnable", "silent-drop", "error-axis", "bulk-pre-existing", "smeared"}
sys.exit(0 if need <= set(verdict.CAUSE_TO_REASON) else 1)
PY
[ "$bad" -eq 0 ] && echo "preflight: 통과" || { echo "preflight: 실패 — 위 ✗ 를 보고하고 멈춘다"; exit 1; }
````

Run: `bash "$SCR/preflight-c5.sh" "$PWD"`
Expected: 마지막 줄 `preflight: 통과`. **하나라도 ✗ 면 멈추고 보고한다** — 특히 「branch 모드(create) arm 이 없다」가 ✗ 면 Task 4 의 강제 재생성(P9)이 사용자 worktree 를 지울 수 있다.

- [ ] **Step 3: 닿는 스위트의 기준 RED 를 실패 줄 수와 함께 캡처**

`$SCR/baseline-red.sh` 를 아래 내용으로 만들고 돌린다:

````bash
#!/bin/bash
# baseline-red.sh <repo-root> <out.tsv> — 닿는 스위트(quality-gates · shared)를 파일마다 돌려 rc 와 실패 줄 수를 적는다.
# 실패 줄 수까지 적어야 이미 RED 인 파일 안의 새 실패가 보인다. 리포 루트에서 돈다.
set -u
R=${1:?repo root}; OUT=${2:?out}
cd "$R" || exit 1
: > "$OUT"
for t in plugins/quality-gates/tests/test_*.sh plugins/quality-gates/tests/test_*.py \
         plugins/quality-gates/tests/harness/test_*.sh shared/tests/test_*.sh; do
  [ -f "$t" ] || continue
  log=$(mktemp)
  case "$t" in
    *.py) PYTHONDONTWRITEBYTECODE=1 python3 "$t" >"$log" 2>&1; rc=$? ;;
    *)    bash "$t" >"$log" 2>&1; rc=$? ;;
  esac
  n=$(grep -cE '✗|^FAIL|^ERROR|not ok|Traceback' "$log")
  printf '%s\t%s\t%s\n' "$t" "$rc" "$n" >> "$OUT"
  rm -f "$log"
done
awk -F'\t' '$2 != 0 || $3 != 0' "$OUT" | sed 's/^/RED  /'
echo "기록: $OUT ($(wc -l < "$OUT" | tr -d ' ')개 파일)"
````

Run: `bash "$SCR/baseline-red.sh" "$PWD" "$SCR/baseline-red.tsv"`
Expected: `RED  …` 줄 목록(선재 RED)과 `기록:` 줄. 이 파일이 Task 10 의 대조 기준이다.

- [ ] **Step 4: 개념 별칭을 센다(지울 대상의 소비자 지도)**

`$SCR/aliases-c5.sh` 를 아래 내용으로 만들고 돌린다:

````bash
#!/bin/bash
# aliases-c5.sh <repo-root> — ⑤ 가 지우거나 바꾸는 개념의 별칭을 리포 전체(숨김 디렉토리 포함)에서 센다.
# git ls-files 가 대상이라 심볼릭 링크 · 숨김 디렉토리를 빠뜨리지 않는다. 범위는 quality-gates · shared · 헌장 · 루트 문서이고,
# CHANGELOG 는 역사 기록이라 뺀다. 허용되는 남은 자리는 plan Task 10 의 표에 있다.
set -u
R=${1:?repo root}
cd "$R" || exit 1
ALIASES=(
  'baseline-cache' 'baseline_cache' 'check_qa_ledger' 'qa_ledger' 'runtime-evidence' 'floor:verification'
  'discover-plan' 'discover_common' 'plan_path' '--plan' 'test-scope-validator' 'fixtures/test-scope'
  'DISABLE_SPEC_CONFORMANCE' 'spec_path' 'expected-adapters' 'baseline-detected' 'baseline_detected'
  'baseline-mode' 'head-mode' 'cargo-target-dir' 'run-test-selection.sh" probe' 'R-init' 'R1a' 'R1b' 'R5b' '갭 게이트'
)
for a in "${ALIASES[@]}"; do
  hits=$(git ls-files -z -- plugins/quality-gates shared docs/philosophy CLAUDE.md README.md .claude-plugin \
         | xargs -0 grep -lF -- "$a" 2>/dev/null | grep -vE '/CHANGELOG\.md$' || true)
  n=$(printf '%s' "$hits" | grep -c . || true)
  printf '%-34s %s\n' "$a" "$n"
  [ "$n" -gt 0 ] && printf '%s\n' "$hits" | sed 's/^/    /'
done
````

Run: `bash "$SCR/aliases-c5.sh" "$PWD" > "$SCR/aliases-before.txt"; cat "$SCR/aliases-before.txt"`
Expected: 별칭마다 0 이상의 수와 파일 목록. 「옛 테스트의 처분」 · 「파일 지도」 에 없는 파일이 나오면 Task 9 의 처분 규칙으로 다룬다.

- [ ] **Step 5: AC23 비교용 옛판을 지금 떠 둔다(설치된 main 판)**

```bash
git show origin/main:plugins/quality-gates/scripts/run-test-selection.sh > "$SCR/old/run-test-selection.sh"
git show origin/main:plugins/quality-gates/scripts/diff-test-results.py   > "$SCR/old/diff-test-results.py"
ls -l "$SCR/old"
```

`$SCR/ac23-compare.sh` 와 `$SCR/ac23-fixture.sh` 를 아래 내용으로 만든다(Task 10 이 쓴다):

````bash
#!/bin/bash
# ac23-compare.sh <old-scripts-dir> <new-scripts-dir> <repo> <base-commit> <head-commit> <unit>...
# 같은 입력(리포 · 두 커밋 · shell unit 목록)에서 옛 차등 기계와 새 기계의 unit 별 귀속 범주와 판정 입력 플래그를 나란히 낸다.
# 커밋하지 않는 측정 도구다(K5). shell 러너만 다룬다.
set -u
OLD=$1; NEW=$2; REPO=$3; B=$4; H=$5; shift 5
T=$(mktemp -d) || exit 1
trap 'git -C "$REPO" worktree remove --force "$T/bw" >/dev/null 2>&1; git -C "$REPO" worktree remove --force "$T/hw" >/dev/null 2>&1; rm -rf "$T"' EXIT
git -C "$REPO" worktree add -q --detach "$T/bw" "$B" || exit 1
git -C "$REPO" worktree add -q --detach "$T/hw" "$H" || exit 1

# 옛 기계: run 은 stdout 3열, bulk → 실패 unit per-unit 교체, diff 는 플래그 인자.
old_axis() {   # old_axis <tree> <out>
  local tree=$1 out=$2 u
  bash "$OLD/run-test-selection.sh" run "$tree" shell bulk "${UNITS[@]}" 2>/dev/null > "$out.bulk"
  : > "$out"
  for u in "${UNITS[@]}"; do
    if awk -F'\t' -v u="$u" '$1==u && ($2=="fail"||$2=="error"){f=1} END{exit !f}' "$out.bulk"; then
      bash "$OLD/run-test-selection.sh" run "$tree" shell per-unit "$u" 2>/dev/null >> "$out"
    else
      awk -F'\t' -v u="$u" '$1==u' "$out.bulk" >> "$out"
    fi
  done
}
UNITS=("$@")
old_axis "$T/bw" "$T/old-base.tsv"
old_axis "$T/hw" "$T/old-head.tsv"
printf '%s\n' "${UNITS[@]}" > "$T/expected.txt"
( cd "$REPO" && python3 "$OLD/diff-test-results.py" --expected "$T/expected.txt" --baseline "$T/old-base.tsv" \
    --head "$T/old-head.tsv" --granularity file --runner shell --baseline-mode bulk --head-mode per-unit \
    --baseline-detected shell ) > "$T/old.yaml" 2>"$T/old.err"
echo "old_rc=$?"

# 새 기계: 같은 unit 을 배정 파일 없이 행 파일로 — 같은 bulk → per-unit 두 단계.
M="$T/memo"; mkdir "$M"
{ for u in "${UNITS[@]}"; do printf '%s\tshell\tfile\n' "$u"; done
  printf '#qg-assign\tadapters=shell\trows=%s\n' "${#UNITS[@]}"; } > "$M/assign-i1.tsv"
new_axis() {   # new_axis <tree> <rows>
  local tree=$1 rows=$2 fails
  bash "$NEW/run-test-selection.sh" run "$tree" shell bulk "$rows" "${UNITS[@]}" 2>/dev/null
  fails=$(awk -F'\t' '$2=="fail"||$2=="error"{print $1}' "$rows")
  # shellcheck disable=SC2086
  [ -n "$fails" ] && bash "$NEW/run-test-selection.sh" run "$tree" shell per-unit "$rows" $fails 2>/dev/null
}
new_axis "$T/bw" "$M/baseline-shell.tsv"
new_axis "$T/hw" "$M/head-shell-i1.tsv"
( cd "$REPO" && python3 "$NEW/diff-test-results.py" --assign "$M/assign-i1.tsv" --rows "$M" --iter 1 \
    --baseline-commit "$B" --head-commit "$H" ) > "$T/new.yaml" 2>"$T/new.err"
echo "new_rc=$?"

cats() { awk '/- unit: /{u=$3} /verdict: /{print u "\t" $2}' "$1" | sort; }
flags() { grep -E '^  (confirmed_product_defect|silent_drop|baseline_unrunnable): ' "$1"; }
echo "--- 범주 diff (빈 출력 = 같음)"; diff <(cats "$T/old.yaml") <(cats "$T/new.yaml")
echo "--- 판정 입력 플래그 diff (빈 출력 = 같음)"; diff <(flags "$T/old.yaml") <(flags "$T/new.yaml")
echo "--- degrade_causes (차이는 사람이 본다)"; grep '^degrade_causes' "$T/old.yaml" "$T/new.yaml" | sed "s|$T/||"
````

````bash
#!/bin/bash
# ac23-fixture.sh <old-scripts-dir> <new-scripts-dir> — 귀속 범주 여덟 중 일곱을 내는 shell 픽스처로 ac23-compare.sh 를 돌린다.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
F=$(mktemp -d) || exit 1; trap 'rm -rf "$F"' EXIT
git init -q -b main "$F/r"; cd "$F/r" || exit 1
git config user.email t@t; git config user.name t; git config commit.gpgsign false
mkdir tests
t() { printf '#!/bin/bash\nexit %s\n' "$2" > "tests/$1"; chmod +x "tests/$1"; }
t reg.sh 0; t pre.sh 1; t green.sh 0; t gone.sh 0; t fixed.sh 1
printf '#!/bin/bash\nexit 0\n' > tests/unrun.sh   # 기준선에서는 실행 비트 없음 → unrun
git add -A; git commit -qm base; B=$(git rev-parse HEAD)
t reg.sh 1; t fixed.sh 0; t newred.sh 1; t newgreen.sh 0; git rm -q tests/gone.sh; chmod +x tests/unrun.sh
git add -A; git commit -qm head; H=$(git rev-parse HEAD)
bash "$HERE/ac23-compare.sh" "$1" "$2" "$F/r" "$B" "$H" \
  tests/reg.sh tests/pre.sh tests/green.sh tests/gone.sh tests/fixed.sh tests/newred.sh tests/newgreen.sh tests/unrun.sh
````

Run: `bash -n "$SCR/ac23-compare.sh" && bash -n "$SCR/ac23-fixture.sh" && echo ok`
Expected: `ok`

- [ ] **Step 6: 요구별 변이 도구를 만든다(커밋하지 않는다)**

`$SCR/r-mutations.py` 를 아래 내용으로 만든다. 각 Task 의 변이 단계가 `python3 "$SCR/r-mutations.py" "$PWD" <ID>…` 로 부른다. 변이는 메모리의 원문으로 되돌리고 끝에 `git diff --quiet` 로 확인한다 — **변이 단계 전에 그 Task 의 변경을 커밋한다**(되돌림 확인이 HEAD 기준이다).

````python
#!/usr/bin/env python3
"""r-mutations.py <repo-root> [R…] — 요구마다 그 요구를 깨는 변이를 하나 적용하고 지목한 테스트가 RED 인지 본다.

커밋하지 않는 측정 도구다. 변이는 메모리의 원문으로 되돌리고, 끝에 `git diff --quiet` 로 확인한다.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

WORK = Path(sys.argv[1]).resolve()
QG = WORK / "plugins/quality-gates"
S = "scripts/"
T = "tests/"

# (요구, 파일, 바꿀 문자열, 새 문자열, 테스트 파일)
MUT = [
    # Task 2 — assign
    ("R16b", S + "run-test-selection.sh", '      else\n        emit "$f" unclaimed file\n      fi', '      else\n        :\n      fi', T + "test_run_test_selection.sh"),
    ("R17c", S + "run-test-selection.sh", '    mv -f "$tmp" "$out" || { rm -f "$tmp"; die "배정 파일을 옮기지 못했다: $out"; }', '    mv -f "$tmp" "$out"; sed -i.x "\\$d" "$out"', T + "test_run_test_selection.sh"),
    ("R20a", S + "run-test-selection.sh", '      if ! unit_within_worktree "$w" "$f"; then\n        emit "$f" unclaimed file; continue', '      if false; then\n        emit "$f" unclaimed file; continue', T + "test_run_test_selection.sh"),
    ("R20s", S + "run-test-selection.sh", '          tests/*.sh|*/tests/*.sh) [[ -x "$w/$f" ]] && claimed=shell ;;', '          *.sh) claimed=shell ;;', T + "test_run_test_selection.sh"),
    ("R21", S + "run-test-selection.sh", "  grep -qE '^(async[[:space:]]+)?def[[:space:]]+test' \"$f\" 2>/dev/null && return 1\n", "", T + "test_run_test_selection.sh"),
    ("R21g", S + "run-test-selection.sh", "        *_test.go) has_adapter go && claimed=go ;;", "        *.go) has_adapter go && claimed=go ;;", T + "test_run_test_selection.sh"),
    # Task 3 — run · unrun · pending
    ("R3", S + "run-test-selection.sh", "127) echo unrun ;;", "127) echo error ;;", T + "test_runner_adapters.sh"),
    ("R3s", S + "run-test-selection.sh", '      USABLE_REASON=setup_failed; return 1', '      USABLE_REASON=setup_failed', T + "test_runner_adapters.sh"),
    ("R4", S + "run-test-selection.sh", "1) echo fail ;; 127) echo unrun ;; *) echo error ;;", "1) echo fail ;; 127) echo unrun ;; *) echo unrun ;;", T + "test_runner_adapters.sh"),
    ("R5b", S + "run-test-selection.sh", '      [[ "$T_COMMIT" == "$commit" ]] || die "행 파일이 다른 트리의 것이다', '      true || die "행 파일이 다른 트리의 것이다', T + "test_run_test_selection.sh"),
    ("R7b", S + "run-test-selection.sh", '        [[ "${ROWS_UNIT[$i]}" == "${NEW_UNIT[$j]}" ]] && { keep=0; break; }', '        :', T + "test_run_test_selection.sh"),
    ("R11", S + "run-test-selection.sh", '    if git -C "$w" symbolic-ref -q HEAD >/dev/null 2>&1; then', '    if false; then', T + "test_run_test_selection.sh"),
    ("R14", S + "run-test-selection.sh", '  if ! detect_set "$w" | grep -qxF -- "$runner"; then', '  if false; then', T + "test_runner_adapters.sh"),
    ("R15", S + "run-test-selection.sh", '      [[ "$T_FLAKY" == "0" ]] || die "flaky 재실행은', '      true || die "flaky 재실행은', T + "test_run_test_selection.sh"),
    ("R15b", S + "run-test-selection.sh", '        case "$2" in pass|fail|error) ;; *) return 0 ;; esac', '        :', T + "test_run_test_selection.sh"),
    ("R20r", S + "run-test-selection.sh", '        file)    unit_within_worktree "$w" "$1" && [[ -f "$w/$1" ]] ;;', '        file)    [[ -f "$w/$1" ]] ;;', T + "test_run_test_selection.sh"),
    ("R20b", S + "run-test-selection.sh", '        tests/*.sh|*/tests/*.sh) [[ -x "$w/$1" ]] ;;\n        *) return 1 ;;', '        tests/*.sh|*/tests/*.sh) [[ -x "$w/$1" ]] ;;\n        *) return 0 ;;', T + "test_run_test_selection.sh"),
    ("R21b", S + "run-test-selection.sh", '&& [[ -d "$w/$1" ]] && has_go_tests "$w/$1" ;;', '&& [[ -d "$w/$1" ]] ;;', T + "test_runner_adapters.sh"),
    ("R22", S + "run-test-selection.sh", '  if [[ "${DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST:-}" == "1" ]]; then', '  if false; then', T + "test_runner_adapters.sh"),
    # Task 4 — 일회용 트리 · 메모
    ("R6", S + "qg-worktree.sh", '      "$root"/*) rmdir "$memo"; die', '      "$root"/nomatch) rmdir "$memo"; die', T + "test_differential_trees.sh"),
    ("R6b", S + "qg-worktree.sh", '    rm -rf -- "$2" || die "메모를 지우지 못했다: $2"', '    true', T + "test_differential_trees.sh"),
    ("R12", S + "qg-worktree.sh", '      [[ "$(git rev-parse "$2^{tree}")" == "$(git rev-parse "$ch_expected^{tree}")" ]] \\\n        || die "sealed-sha mismatch', '      true \\\n        || die "sealed-sha mismatch', T + "test_differential_trees.sh"),
    ("R23", S + "qg-worktree.sh", '    git worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf -- "$wt" \\\n      || die "앞 실행이 남긴 트리를 지우지 못했다: $wt"', '    die "앞 실행이 남긴 트리를 지우지 못했다: $wt"', T + "test_differential_trees.sh"),
    # Task 5 — 후보
    ("R17b", S + "compute-test-scope-candidates.sh", '    || die4 "기준선 미확정(degraded=', '    || mb=HEAD || die4 "기준선 미확정(degraded=', T + "test_compute_test_scope_candidates.sh"),
    # Task 6 — 짝짓기 · 집계
    ("R1", S + "diff-test-results.py", '        causes.append("expected-empty")\n', "        pass\n", T + "test_diff_test_results.py"),
    ("R2", S + "diff-test-results.py", '    if error_seen:\n        causes.append("error-axis")\n', "", T + "test_diff_test_results.py"),
    ("R5", S + "diff-test-results.py", '    if kv.get("commit") != commit:\n', '    if False:\n', T + "test_diff_test_results.py"),
    ("R7", S + "diff-test-results.py", '        if unit in rows:\n            fail4(f"{path}:{n} 중복 unit 행', '        if False:\n            fail4(f"{path}:{n} 중복 unit 행', T + "test_diff_test_results.py"),
    ("R8", S + "diff-test-results.py", '        units = [u for u, g in by_runner[runner]]\n', '        units = sorted(set(read_rows(memo / f"head-{runner}-i{args.iter}.tsv", runner, args.head_commit)))\n', T + "test_diff_test_results.py"),
    ("R9", S + "diff-test-results.py", '                smeared = True', '                smeared = False', T + "test_diff_test_results.py"),
    ("R9b", S + "diff-test-results.py", '        gran = granularity_of(runner)\n', '        gran = by_runner[runner][0][1]\n', T + "test_diff_test_results.py"),
    ("R10", S + "diff-test-results.py", '                    and "bulk" in (b[2], h[2])):', '                    ):', T + "test_diff_test_results.py"),
    ("R13", S + "diff-test-results.py", '    return trees[0] == trees[1]\n', '    return False\n', T + "test_diff_test_results.py"),
    ("R15c", S + "diff-test-results.py", '            if h[2] == "flaky" and b[0] != "pass":', '            if False:', T + "test_diff_test_results.py"),
    ("R16", S + "diff-test-results.py", '        causes.append("silent-drop")   # 고른 unit', '        pass   # 고른 unit', T + "test_diff_test_results.py"),
    ("R17", S + "diff-test-results.py", '    except OSError as exc:\n        fail4(f"{label} 를 읽을 수 없다', '    except OSError as exc:\n        return "#qg-assign\\tadapters=-\\trows=0\\n"\n        fail4(f"{label} 를 읽을 수 없다', T + "test_diff_test_results.py"),
    ("R19", S + "diff-test-results.py", '    if not path.is_file():\n        fail4(', '    if not path.is_file():\n        return {}\n        fail4(', T + "test_diff_test_results.py"),
    ("R24", S + "diff-test-results.py", '           f"  confirmed_product_defect: {\'true\' if defect else \'false\'}",', '           "  confirmed_product_defect: false",', T + "test_diff_test_results.py"),
    # Task 7 — 절차 문서
    ("R18", "skills/quality-pipeline/references/differential-test.md", "| `diff_rc` 가 0 이 아니다 · 파일이 없다 · D5 전에 절차가 끝났다(D0 메모 실패 · D2 exit 4 포함) | `--reason error-axis` (R18) |\n", "", T + "test_differential_procedure.sh"),
    ("R22o", "skills/quality-pipeline/references/differential-test.md", "| D0 의 kill switch | `--reason kill-switch` |\n", "", T + "test_differential_procedure.sh"),
]


def run_test(rel):
    path = QG / rel
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
    cmd = [sys.executable, str(path)] if rel.endswith(".py") else ["bash", str(path)]
    p = subprocess.run(cmd, cwd=WORK, capture_output=True, text=True, env=env)
    out = p.stdout + p.stderr
    if rel.endswith(".py"):
        return p.returncode != 0, out
    return ("Fail: 0" not in out.splitlines()[-1]) if out.strip() else True, out


def main():
    only = set(sys.argv[2:])
    results = []
    for rid, f, old, new, test in MUT:
        if only and rid not in only:
            continue
        p = QG / f
        src = p.read_text(encoding="utf-8")
        n = src.count(old)
        if n != 1:
            results.append((rid, f"BAD ANCHOR count={n}"))
            continue
        p.write_text(src.replace(old, new), encoding="utf-8")
        try:
            red, out = run_test(test)
        finally:
            p.write_text(src, encoding="utf-8")
        results.append((rid, "RED" if red else "SURVIVED"))
    for rid, r in results:
        print(f"{rid}\t{r}")
    dirty = subprocess.run(["git", "-C", str(WORK), "diff", "--quiet", "--", "plugins/quality-gates"]).returncode
    print("tree restored" if dirty == 0 else "WARNING: plugins/quality-gates 에 되돌리지 못한 변경이 있다 — git diff 로 확인하라")


if __name__ == "__main__":
    main()
````

Run: `python3 -m py_compile "$SCR/r-mutations.py" && echo ok`
Expected: `ok`

- [ ] **Step 7: 옛 case 를 지우는 도구를 만든다(커밋하지 않는다)**

Task 4 · Task 9 가 소비자 테스트에서 옛 case 를 지울 때 쓴다. `$SCR/drop_cases.py`:

````python
#!/usr/bin/env python3
"""drop_cases.py <test.sh> <case_name>... — 셸 테스트 파일에서 case 함수 정의와 실행 목록의 그 이름을 지운다.

함수는 `case_x() {` 줄부터 0열의 `}` 줄까지이고, 바로 위에 붙은 `#` 주석 줄도 함께 지운다.
이미 없는 이름은 「없음」으로 알리고 넘어간다(앞 컷오버가 지웠을 수 있다). 실행 목록 줄이 비면 그 줄을 지운다.
"""
import re
import sys
from pathlib import Path


def main():
    path = Path(sys.argv[1])
    names = sys.argv[2:]
    lines = path.read_text(encoding="utf-8").split("\n")
    for name in names:
        start = next((i for i, l in enumerate(lines) if re.match(rf"^{re.escape(name)}\(\)\s*\{{", l)), None)
        if start is None:
            print(f"없음: {name}")
            continue
        end = start
        if not lines[start].rstrip().endswith("}") or lines[start].count("{") > lines[start].count("}"):
            end = next(i for i in range(start + 1, len(lines)) if lines[i] == "}")
        top = start
        while top > 0 and lines[top - 1].startswith("#"):
            top -= 1
        del lines[top:end + 1]
        print(f"지움: {name} ({end - top + 1}줄)")
    text = "\n".join(lines)
    for name in names:
        text = re.sub(rf"[ \t]+{re.escape(name)}(?=[ \t;\\\n])", "", text)
    # 이름이 다 빠져 `\` 만 남은 이어쓰기 줄을 지운다.
    while True:
        cleaned = re.sub(r"\n[ \t]*\\\n", "\n", text)
        if cleaned == text:
            break
        text = cleaned
    path.write_text(text, encoding="utf-8")


if __name__ == "__main__":
    main()
````

Run: `python3 -m py_compile "$SCR/drop_cases.py" && echo ok`
Expected: `ok`

---

### Task 1: `run-test-selection.sh` 다시 쓰기 ① — 어댑터 표 · detect · granularity

**Files:**
- Modify(전문 교체): `plugins/quality-gates/scripts/run-test-selection.sh`
- Modify(전문 교체): `plugins/quality-gates/tests/test_runner_adapters.sh`

**Interfaces:**
- Consumes: 없음.
- Produces: `run-test-selection.sh detect <tree>`(출력 형식 불변: `runner:`/`granularity:`/`setup_cmd:` 3줄 × N, 빈 줄 구분) · `granularity <runner>`(file|package|bulk, 미지 러너 exit 2). 내부 함수 `unit_within_worktree` · `adapter_usable` · `detect_set` · `granularity_of` · `setup_cmd_of` · `unittest_can_judge` 는 Task 2·3 이 쓴다. `probe` · `cargo-target-dir` 하위명령은 없어진다.

- [ ] **Step 1: 새 어댑터 테스트를 쓴다**

`plugins/quality-gates/tests/test_runner_adapters.sh` 를 아래 전문으로 바꾼다:

````bash
#!/usr/bin/env bash
# test_runner_adapters.sh — run-test-selection.sh 의 어댑터 표(detect · granularity)와 실행 관문.
# 요구: R3 · R4 · R14 · R21(go) · R22 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
RTS="$PLUGIN_ROOT/scripts/run-test-selection.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

W=""
mkw() { W=$(mktemp -d) && [ -d "$W" ] || { echo "mktemp 실패" >&2; exit 1; }; }
rmw() { cd / && rm -rf "$W"; }
runners() { bash "$RTS" detect "$1" 2>/dev/null | awk '$1 == "runner:" { print $2 }'; }
gran_of() { bash "$RTS" detect "$1" 2>/dev/null | awk -v r="$2" '$1=="runner:"{c=$2} $1=="granularity:" && c==r {print $2}'; }

# 일회용 트리: <repo>/main 에 커밋하고 <repo>/wt 에 detached 로 연다. run 은 detached 일회용 트리만 받는다.
TREE=""; REPO=""
mktree() {   # mktree — 호출 전에 $REPO/main 에 파일을 둔다
  ( cd "$REPO/main" && git add -A && git commit -qm t ) || { no "픽스처 커밋 실패"; return 1; }
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt" HEAD || { no "픽스처 worktree 실패"; return 1; }
  TREE="$REPO/wt"
}
mkrepo() {
  REPO=$(mktemp -d) && [ -d "$REPO" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$REPO/main" || exit 1
  git -C "$REPO/main" config user.email t@t; git -C "$REPO/main" config user.name t
  git -C "$REPO/main" config commit.gpgsign false
}
rmrepo() { cd / && rm -rf "$REPO"; }
row_of() { awk -F'\t' -v u="$2" '$1 == u { print $2 "\t" $3 }' "$1"; }

# ── detect: 어댑터 표 ────────────────────────────────────────────────────────────
case_detect_pytest()   { mkw; : > "$W/pytest.ini"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  assert_eq "$(runners "$W")" "pytest" "pytest.ini → pytest"; rmw; }
case_detect_unittest() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  assert_eq "$(runners "$W")" "unittest" "설정 없는 test_*.py → unittest"; rmw; }
case_detect_pytest_declared() { mkw; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"; : > "$W/conftest.py"
  assert_eq "$(runners "$W")" "pytest" "conftest.py + test_*.py → pytest"; rmw; }
case_detect_shell() { mkw; mkdir -p "$W/tests"; printf '#!/bin/bash\nexit 0\n' > "$W/tests/t.sh"; chmod +x "$W/tests/t.sh"
  assert_eq "$(runners "$W")" "shell" "실행 비트 tests/*.sh → shell"; rmw; }
case_detect_jest()   { mkw; printf '{"devDependencies":{"jest":"29"}}' > "$W/package.json"
  assert_eq "$(runners "$W")" "jest" "devDependencies.jest → jest"; rmw; }
case_detect_vitest() { mkw; printf '{"devDependencies":{"vitest":"1"}}' > "$W/package.json"
  assert_eq "$(runners "$W")" "vitest" "devDependencies.vitest → vitest"; rmw; }
case_detect_go()     { mkw; : > "$W/go.mod"; assert_eq "$(runners "$W")" "go" "go.mod → go"; rmw; }
case_detect_cargo()  { mkw; : > "$W/Cargo.toml"; assert_eq "$(runners "$W")" "cargo" "Cargo.toml → cargo"; rmw; }
case_detect_make()   { mkw; printf 'test:\n\ttrue\n' > "$W/Makefile"; assert_eq "$(runners "$W")" "make" "Makefile test: → make"; rmw; }
case_detect_npm_script() { mkw; printf '{"scripts":{"test":"node t.js"}}' > "$W/package.json"
  assert_eq "$(runners "$W")" "npm-script" "scripts.test → npm-script"; rmw; }
case_detect_zero() { mkw; local out rc; out=$(bash "$RTS" detect "$W"); rc=$?
  assert_eq "$rc:$out" "0:" "어댑터 0개는 빈 출력 + exit 0"; rmw; }
case_detect_polyglot() { mkw; : > "$W/go.mod"; : > "$W/Cargo.toml"; mkdir -p "$W/tests"; : > "$W/tests/test_a.py"
  assert_eq "$(runners "$W" | tr '\n' ' ')" "unittest go cargo " "폴리글랏은 집합"; rmw; }
case_detect_js_ambiguous_is_loud() { mkw; printf '{"devDependencies":{"jest":"1","vitest":"1"},"scripts":{"test":"node x"}}' > "$W/package.json"
  local err; err=$(bash "$RTS" detect "$W" 2>&1 >/dev/null)
  assert_eq "$(runners "$W")" "npm-script" "jest+vitest 모호 → npm-script"
  assert_contains "$err" "jest 와 vitest" "모호함을 알린다"; rmw; }
case_detect_malformed_package_json_is_loud() { mkw; printf '{not json' > "$W/package.json"
  local err; err=$(bash "$RTS" detect "$W" 2>&1 >/dev/null)
  assert_contains "$err" "파싱에 실패" "package.json 파손을 알린다"; rmw; }
case_granularity_table() {
  local r out=""
  for r in pytest unittest shell jest vitest go cargo make npm-script; do out="$out$r=$(bash "$RTS" granularity "$r") "; done
  assert_eq "$out" "pytest=file unittest=file shell=file jest=file vitest=file go=package cargo=bulk make=bulk npm-script=bulk " "입도 표"
  bash "$RTS" granularity rspec >/dev/null 2>&1; assert_eq "$?" "2" "미지 러너는 exit 2"
}
# 어댑터 개수를 적은 문서 주장은 닫힌 집합과 같아야 한다.
case_adapter_count_claims_match() {
  local n found=0 bad=0 hit claimed
  n=$(sed -n '/^granularity_of() {/,/^}/p' "$RTS" | grep -oE '^[[:space:]]+[a-z|-]+\)' | tr -d ' )' | tr '|' '\n' | grep -c .)
  while IFS= read -r hit; do
    found=$((found + 1))
    claimed=$(sed -E 's/.*러너 어댑터 ([0-9]+)종.*/\1/' <<<"$hit")
    [ "$claimed" = "$n" ] || { bad=1; echo "    불일치 $claimed≠$n: ${hit:0:110}"; }
  done < <(grep -rnE "러너 어댑터 [0-9]+종" "$PLUGIN_ROOT" --include='*.md' --include='*.sh' --include='*.py' 2>/dev/null | grep -v '/CHANGELOG.md:')
  [ "$n" -eq 9 ] && ok "닫힌 집합 9종" || no "닫힌 집합 파싱 n=$n"
  [ "$found" -gt 0 ] && [ "$bad" -eq 0 ] && ok "어댑터 개수 주장 ${found}곳 일치" || no "어댑터 개수 주장 불일치 또는 0건(found=$found)"
}

for c in case_detect_pytest case_detect_unittest case_detect_pytest_declared case_detect_shell \
         case_detect_jest case_detect_vitest case_detect_go case_detect_cargo case_detect_make \
         case_detect_npm_script case_detect_zero case_detect_polyglot case_detect_js_ambiguous_is_loud \
         case_detect_malformed_package_json_is_loud case_granularity_table case_adapter_count_claims_match; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 2: 옛 스크립트로 돌려 본다(특성 테스트)**

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | tail -3`
Expected: `Fail: 0` — 행동을 보존하는 재작성이라 옛 스크립트도 통과한다. 통과하지 않으면 옛 감지 표와 이 테스트가 어긋난 자리를 먼저 보고한다.

- [ ] **Step 3: 스크립트를 새 전문으로 바꾼다**

`plugins/quality-gates/scripts/run-test-selection.sh` 를 아래 전문으로 바꾼다(실행 비트 유지):

````bash
#!/usr/bin/env bash
# run-test-selection.sh — 테스트 러너 어댑터 표의 유일 소유자 (차등 테스트).
#
#   detect      <tree>                                 → 어댑터 집합 (runner/granularity/setup_cmd 3줄 × N, 빈 줄 구분)
#   granularity <runner>                               → file|package|bulk (순수 함수)
#   assign      <tree> <assign-file>      < 후보 파일    → 배정 파일을 원자적으로 쓴다
#   run         <tree> <runner> <bulk|per-unit|flaky> <rows-file> <unit>...
#                                                      → 행 파일에 그 unit 들의 행을 원자적으로 병합한다
#   unrun       <rows-file> <runner> <commit|-> <unit>...  → 관측 없는 행(unrun)을 병합한다
#   pending     <rows-file> <unit>...                  → 관측된 행이 아직 없는 unit 을 한 줄씩 낸다
#
# 배정 파일: `<unit>\t<runner|unclaimed>\t<granularity>` 행들 + 마지막 줄
#   `#qg-assign\tadapters=<a,b|->\trows=<N>`
# 행 파일:   `<unit>\t<pass|fail|error|unrun|absent>\t<exit|->\t<bulk|per-unit|flaky|skip>` 행들 + 마지막 줄
#   `#qg-rows\trunner=<runner>\tcommit=<sha|->\trows=<N>\tflaky=<0|1>`
# 두 꼬리 줄은 이 스크립트만 쓴다. diff-test-results.py 가 그것을 요구한다 — 잘린 파일과 빈 결과를
# 가르는 것은 꼬리 줄이다(R17).
#
# 결과는 종료 코드로만 읽는다 — 0=pass · 1=fail · 127=unrun · 그 밖=error(R2~R4). 러너별 출력 파서는 없다.
#
# Exit: 0 = 정상 · 2 = 사용 오류(아무것도 쓰지 않는다) · 3 = 어댑터 사용 불가(run: 해당 unit 을 unrun 으로 병합)
# DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 이면 run 은 저장소 코드를 돌리지 않고 3 으로 끝난다(R22).
set -u

die() { echo "run-test-selection: $*" >&2; exit 2; }

cargo_target_dir_for() { printf '%s/target\n' "$1"; }

# 심볼릭 링크를 끝까지 따라가 최종 대상의 정규화 위치를 낸다. 고리 · 끝이 링크면 실패.
resolve_leaf_dir() {
  local p=$1 hops=0 t
  while [[ -L "$p" && $hops -lt 20 ]]; do
    t=$(readlink "$p") || return 1
    case "$t" in
      /*) p=$t ;;
      *)  p="$(dirname "$p")/$t" ;;
    esac
    hops=$((hops + 1))
  done
  [[ -L "$p" ]] && return 1
  if [[ -d "$p" ]]; then
    (cd "$p" 2>/dev/null && pwd -P) || return 1
  else
    (cd "$(dirname "$p")" 2>/dev/null && pwd -P) || return 1
  fi
}

# unit 은 트리 안이어야 한다 — 절대경로 · `..` 성분 · 트리 밖으로 풀리는 링크를 거부한다(R20).
unit_within_worktree() {
  local w=$1 u=$2 root d leaf
  case "$u" in
    /*)                            return 1 ;;
    ..|../*|*/../*|*/..)           return 1 ;;
  esac
  root=$(cd "$w" 2>/dev/null && pwd -P) || return 1
  d=$(cd "$w/$(dirname -- "$u")" 2>/dev/null && pwd -P) || return 0
  case "$d" in
    "$root"|"$root"/*) ;;
    *) return 1 ;;
  esac
  if [[ -L "$w/$u" ]]; then
    leaf=$(resolve_leaf_dir "$w/$u") || return 1
    case "$leaf" in
      "$root"|"$root"/*) ;;
      *) return 1 ;;
    esac
  fi
  return 0
}

dir_is_ignored() {
  git -C "$1" rev-parse --git-dir >/dev/null 2>&1 || return 0
  git -C "$1" check-ignore -q "$2/" 2>/dev/null
}

poetry_in_project() {
  local w=$1
  case "${POETRY_VIRTUALENVS_IN_PROJECT:-}" in
    1|true|True|TRUE)    return 0 ;;
    0|false|False|FALSE) return 1 ;;
  esac
  if [[ -f "$w/poetry.toml" ]] \
     && grep -qE '^[[:space:]]*in-project[[:space:]]*=[[:space:]]*true' "$w/poetry.toml" 2>/dev/null; then
    return 0
  fi
  if command -v poetry >/dev/null 2>&1; then
    local cfg
    cfg=$( (cd "$w" && poetry config virtualenvs.in-project 2>/dev/null) ) || cfg=""
    case "$cfg" in
      true)  return 0 ;;
      false) return 1 ;;
      *)     return 0 ;;
    esac
  fi
  return 0
}

setup_env_dir_of() {
  case "$2" in
    pytest|unittest)
      case "$(python_env_of "$1")" in
        uv|venv) echo .venv ;;
        poetry)  poetry_in_project "$1" && echo .venv || echo "" ;;
        *)       echo "" ;;
      esac ;;
    jest|vitest|npm-script) echo node_modules ;;
    *) echo "" ;;
  esac
}

python_env_of() {
  local w=$1
  if   [[ -f "$w/uv.lock"          ]]; then echo uv
  elif [[ -f "$w/poetry.lock"      ]]; then echo poetry
  elif [[ -f "$w/requirements.txt" ]]; then echo venv
  else echo ambient; fi
}

py_argv() {
  case "$(python_env_of "$1")" in
    uv)     PY_ARGV=(uv run python) ;;
    poetry) PY_ARGV=(poetry run python) ;;
    venv)   PY_ARGV=(.venv/bin/python) ;;
    *)      PY_ARGV=(python3) ;;
  esac
}

granularity_of() {
  case "$1" in
    pytest|unittest|shell|jest|vitest) echo file ;;
    go)                                echo package ;;
    cargo|make|npm-script)             echo bulk ;;
    *) die "unknown runner: $1" ;;
  esac
}

pkg_field() {
  python3 - "$1/package.json" "$2" <<'PY' 2>/dev/null
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as fh:
        cur = json.load(fh)
except Exception:
    sys.exit(1)
for key in sys.argv[2].split("."):
    if not isinstance(cur, dict) or key not in cur:
        sys.exit(1)
    cur = cur[key]
print(cur if isinstance(cur, str) else "1")
PY
}

pkg_json_malformed() {
  [[ -f "$1/package.json" ]] || return 1
  if ! command -v python3 >/dev/null 2>&1; then
    PKG_JSON_REASON=no_parser; return 1
  fi
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8"))' \
    "$1/package.json" >/dev/null 2>&1 && return 1
  PKG_JSON_REASON=parse_error
  return 0
}

has_pytest_config() {
  local w=$1
  [[ -f "$w/pytest.ini" ]] && return 0
  [[ -f "$w/tox.ini"    ]] && grep -q '^\[pytest\]'      "$w/tox.ini"    2>/dev/null && return 0
  [[ -f "$w/setup.cfg"  ]] && grep -q '^\[tool:pytest\]' "$w/setup.cfg"  2>/dev/null && return 0
  [[ -f "$w/pyproject.toml" ]] && grep -q '^\[tool\.pytest' "$w/pyproject.toml" 2>/dev/null && return 0
  return 1
}

# unittest 가 이 파일을 판정할 수 있는가(R21). discover 가 놓치는 것이 하나라도 있으면 claim 하지 않는다:
# 모듈-레벨 bare `def test` · TestCase 를 상속하지 않는 `class Test…` 가 있으면 거부, TestCase 하위클래스나
# `load_tests` 가 있어야 수락.
unittest_can_judge() {
  local f="$1/$2"
  grep -qE '^(async[[:space:]]+)?def[[:space:]]+test' "$f" 2>/dev/null && return 1
  if grep -E '^class[[:space:]]+Test' "$f" 2>/dev/null | grep -qvF 'TestCase'; then
    return 1
  fi
  grep -qE '^[[:space:]]*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\([^)]*TestCase' "$f" 2>/dev/null && return 0
  grep -qE '^[[:space:]]*def[[:space:]]+load_tests[[:space:]]*\(' "$f" 2>/dev/null && return 0
  return 1
}

# 이 레포가 pytest 를 선언했는가 — 이 머신에 pytest 가 깔렸는가가 아니다.
repo_declares_pytest() {
  local w=$1 f
  find "$w" -name .git -prune -o -type f -name 'conftest.py' -print 2>/dev/null | head -1 | grep -q . && return 0
  for f in requirements.txt requirements-dev.txt requirements/dev.txt pyproject.toml setup.cfg tox.ini; do
    [[ -f "$w/$f" ]] && grep -qiE '(^|[^a-z-])pytest(-[a-z0-9]+)*([^a-z-]|$)' "$w/$f" 2>/dev/null && return 0
  done
  return 1
}

has_python_tests() {
  find "$1" -name .git -prune -o -type f \
       \( -name 'test_*.py' -o -name '*_test.py' \) -print 2>/dev/null | head -1 | grep -q .
}

has_exec_shell_tests() {
  find "$1" -name .git -prune -o -type f -perm -u+x -name '*.sh' -path '*/tests/*' \
       -print 2>/dev/null | head -1 | grep -q .
}

setup_cmd_of() {
  local w=$1
  case "$2" in
    pytest|unittest)
      case "$(python_env_of "$w")" in
        uv)     echo 'uv sync --frozen' ;;
        poetry) echo 'poetry install --no-interaction' ;;
        venv)   echo 'python3 -m venv .venv && .venv/bin/python -m pip install -q -r requirements.txt' ;;
        *)      echo '-' ;;
      esac ;;
    jest|vitest|npm-script)
      if   [[ -f "$w/pnpm-lock.yaml"    ]]; then echo 'pnpm install --frozen-lockfile'
      elif [[ -f "$w/yarn.lock"         ]]; then echo 'yarn install --frozen-lockfile'
      elif [[ -f "$w/package-lock.json" ]]; then echo 'npm ci'
      else echo 'npm install --no-audit --no-fund --no-package-lock'; fi ;;
    shell|go|cargo|make) echo '-' ;;
    *) die "unknown runner: $2" ;;
  esac
}

detect_set() {
  local w=$1 out=""
  if has_pytest_config "$w"; then
    out="$out pytest"
  elif has_python_tests "$w" && repo_declares_pytest "$w"; then
    out="$out pytest"
  elif has_python_tests "$w"; then
    out="$out unittest"
  fi

  has_exec_shell_tests "$w" && out="$out shell"

  local has_jest=0 has_vitest=0 js_pick="" test_script=""
  PKG_JSON_REASON=""
  if pkg_json_malformed "$w"; then
    echo "run-test-selection: package.json 이 있으나 파싱에 실패했다 — JS 어댑터(jest·vitest·npm-script) 감지를 건너뛴다 (in $w). 'JS 어댑터 없음' 과 다른 사건이다." >&2
  elif [[ "$PKG_JSON_REASON" == "no_parser" ]]; then
    echo "run-test-selection: python3 가 없어 package.json 을 읽지 못했다 — JS 어댑터 감지를 건너뛴다 (in $w)." >&2
  fi
  pkg_field "$w" devDependencies.jest   >/dev/null 2>&1 && has_jest=1
  pkg_field "$w" devDependencies.vitest >/dev/null 2>&1 && has_vitest=1
  if [[ $has_jest -eq 1 && $has_vitest -eq 1 ]]; then
    test_script=$(pkg_field "$w" scripts.test 2>/dev/null || true)
    case "$test_script" in
      *vitest*) js_pick=vitest ;;
      *jest*)   js_pick=jest ;;
      *)        js_pick=""
                echo "run-test-selection: jest 와 vitest 가 함께 선언됐고 scripts.test 가 어느 쪽도 호출하지 않는다 — npm-script(bulk)로 폴백한다 (in $w)." >&2 ;;
    esac
  elif [[ $has_jest   -eq 1 ]]; then js_pick=jest
  elif [[ $has_vitest -eq 1 ]]; then js_pick=vitest
  fi
  [[ -n "$js_pick" ]] && out="$out $js_pick"

  [[ -f "$w/go.mod"     ]] && out="$out go"
  [[ -f "$w/Cargo.toml" ]] && out="$out cargo"
  [[ -f "$w/Makefile"   ]] && grep -qE '^test:' "$w/Makefile" 2>/dev/null && out="$out make"
  if [[ -z "$js_pick" ]] && pkg_field "$w" scripts.test >/dev/null 2>&1; then
    out="$out npm-script"
  fi

  local r
  for r in $out; do echo "$r"; done
}

runner_available() {
  local w=$1
  case "$2" in
    shell)       command -v bash  >/dev/null 2>&1 ;;
    go)          command -v go    >/dev/null 2>&1 ;;
    cargo)       command -v cargo >/dev/null 2>&1 ;;
    make)        command -v make  >/dev/null 2>&1 ;;
    npm-script)  command -v npm   >/dev/null 2>&1 ;;
    jest|vitest) command -v npx >/dev/null 2>&1 \
                   && ( cd "$w" && npx --no-install "$2" --version ) >/dev/null 2>&1 ;;
    pytest)      ( cd "$w" && "${PY_ARGV[@]}" -m pytest --version ) >/dev/null 2>&1 ;;
    unittest)    ( cd "$w" && "${PY_ARGV[@]}" -c '' ) >/dev/null 2>&1 ;;
    *)           return 1 ;;
  esac
}

# 실행 관문. 순서가 계약이다: kill switch → 이 트리의 감지(R14) → setup 이 만들 환경 디렉토리가
# 무시되는가 → setup(R3) → 러너 가용성(R3). setup 앞에서 디렉토리를 봐야 무시되지 않는 디렉토리에
# 설치하지 않고, 가용성은 setup 뒤에 봐야 setup 이 설치하는 러너를 놓치지 않는다.
adapter_usable() {
  local w=$1 runner=$2 scmd env_dir
  USABLE_REASON=""
  if [[ "${DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST:-}" == "1" ]]; then
    echo "run-test-selection: 차등 테스트가 DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 로 꺼져 있다 — 저장소 코드를 돌리지 않는다 ($runner in $w)" >&2
    USABLE_REASON=kill_switch; return 1
  fi
  if ! detect_set "$w" | grep -qxF -- "$runner"; then
    echo "run-test-selection: 어댑터 사용 불가: $runner — 이 트리가 선언하지 않았다 (in $w)" >&2
    USABLE_REASON=not_detected; return 1
  fi
  scmd=$(setup_cmd_of "$w" "$runner")
  if [[ "$scmd" != "-" ]]; then
    env_dir=$(setup_env_dir_of "$w" "$runner")
    if [[ -n "$env_dir" ]] && ! dir_is_ignored "$w" "$env_dir"; then
      echo "run-test-selection: 어댑터 사용 불가: $runner — setup 이 만드는 '$env_dir/' 를 이 레포가 gitignore 하지 않는다 (in $w)" >&2
      USABLE_REASON=env_dir_not_ignored; return 1
    fi
    if ! ( cd "$w" && sh -c "$scmd" ) >&2 2>&1; then
      echo "run-test-selection: setup 실패: $scmd" >&2
      USABLE_REASON=setup_failed; return 1
    fi
  fi
  PY_ARGV=(python3)
  py_argv "$w"
  if ! runner_available "$w" "$runner"; then
    echo "run-test-selection: 러너 실행 불가: $runner — 도구가 이 머신에 없다 (in $w)" >&2
    USABLE_REASON=runner_missing; return 1
  fi
  return 0
}

case "${1:-}" in
  detect)
    [[ $# -eq 2 ]] || die "usage: detect <tree>"
    w=$2
    [[ -d "$w" ]] || die "not a directory: $w"
    first=1
    while IFS= read -r r; do
      [[ -z "$r" ]] && continue
      [[ $first -eq 1 ]] || echo
      first=0
      g=$(granularity_of "$r")     || die "unknown runner from detect_set: $r"
      s=$(setup_cmd_of "$w" "$r")  || die "unknown runner from detect_set: $r"
      echo "runner: $r"
      echo "granularity: $g"
      echo "setup_cmd: $s"
    done < <(detect_set "$w")
    exit 0
    ;;
  granularity)
    [[ $# -eq 2 ]] || die "usage: granularity <runner>"
    granularity_of "$2"
    exit 0
    ;;
  *)
    die "unknown subcommand: ${1:-} (expected detect|granularity|assign|run|unrun|pending)"
    ;;
esac
````

- [ ] **Step 4: 문법과 테스트**

Run: `bash -n plugins/quality-gates/scripts/run-test-selection.sh && bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | tail -1`
Expected: `Total: 19 | Pass: 19 | Fail: 0`

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/tests/test_runner_adapters.sh
git commit -m "refactor(quality-gates): run-test-selection — adapter table, detect, granularity rewritten thin"
```

---

### Task 2: `run-test-selection.sh` 다시 쓰기 ② — assign 과 배정 파일

**Files:**
- Modify: `plugins/quality-gates/scripts/run-test-selection.sh`(assign arm 삽입)
- Modify(전문 교체): `plugins/quality-gates/tests/test_run_test_selection.sh`

**Interfaces:**
- Consumes: Task 1 의 `detect_set` · `unit_within_worktree` · `unittest_can_judge` · `granularity_of`.
- Produces: `run-test-selection.sh assign <tree> <assign-file>` — stdin 의 후보 파일을 읽어 `<unit>\t<runner|unclaimed>\t<granularity>` 행 + 마지막 줄 `#qg-assign\tadapters=<a,b|->\trows=<N>` 을 **원자적으로** 쓴다(실패하면 파일을 남기지 않는다). 사용 오류 exit 2. Task 6 의 `diff-test-results.py --assign` 이 이 파일을 읽는다.

- [ ] **Step 1: assign 테스트를 쓴다**

`plugins/quality-gates/tests/test_run_test_selection.sh` 를 아래 전문으로 바꾼다:

````bash
#!/usr/bin/env bash
# test_run_test_selection.sh — assign · run · unrun · pending 의 행 파일 계약.
# 요구: R5 · R7 · R11 · R15 · R16 · R17 · R20 · R21 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
RTS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/run-test-selection.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

REPO=""; TREE=""
mkrepo() {
  REPO=$(mktemp -d) && [ -d "$REPO" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$REPO/main" || exit 1
  git -C "$REPO/main" config user.email t@t; git -C "$REPO/main" config user.name t
  git -C "$REPO/main" config commit.gpgsign false
  mkdir -p "$REPO/main/tests"; printf 'x\n' > "$REPO/main/README"
}
shtest() {   # shtest <relpath> <exit> — 실행 비트가 있는 shell 테스트
  mkdir -p "$REPO/main/$(dirname "$1")"
  printf '#!/bin/bash\nexit %s\n' "$2" > "$REPO/main/$1"; chmod +x "$REPO/main/$1"
}
mktree() {
  ( cd "$REPO/main" && git add -A && git commit -qm t ) || { no "픽스처 커밋 실패"; return 1; }
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt" HEAD || { no "픽스처 worktree 실패"; return 1; }
  TREE="$REPO/wt"
}
rmrepo() { cd / && rm -rf "$REPO"; }
row_of() { awk -F'\t' -v u="$2" '$1 == u { print $2 "\t" $3 "\t" $4 }' "$1"; }
trailer() { tail -n 1 "$1"; }
assign() { printf '%s\n' "$@" | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>/dev/null; }
arow() { awk -F'\t' -v u="$1" '$1 == u { print $2 "\t" $3 }' "$REPO/assign.tsv"; }

# ── assign ──────────────────────────────────────────────────────────────────────
# R17 — 배정 파일은 꼬리 줄(감지된 어댑터 · 행 수)로 끝난다. 생산자가 끝까지 썼다는 증거다.
case_R17_assign_writes_trailer() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  assign tests/a.sh; local rc=$?
  assert_eq "$rc" "0" "R17: assign exit 0"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=shell	rows=1" "R17: 꼬리 줄"
  rmrepo
}
# R17 — 사용 오류로 죽은 assign 은 배정 파일을 남기지 않는다(빈 파일이 「배정할 것 없음」으로 읽히지 않게).
case_R17_failed_assign_leaves_no_file() {
  mkrepo; mktree || { rmrepo; return; }
  printf 'x\n' | bash "$RTS" assign "$REPO/no-such-tree" "$REPO/assign.tsv" 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R17: 없는 트리 → exit 2"
  [ ! -e "$REPO/assign.tsv" ] && ok "R17: 배정 파일이 생기지 않았다" || no "R17: 실패한 assign 이 파일을 남겼다"
  rmrepo
}
# R20 — 트리 밖으로 나가는 후보(절대경로 · `..` · 밖을 가리키는 링크)는 claim 되지 않고 unclaimed 다.
case_R20_assign_refuses_units_outside_tree() {
  mkrepo; shtest tests/a.sh 0; mkdir -p "$REPO/outside/tests"; printf '#!/bin/bash\n' > "$REPO/outside/tests/x.sh"
  chmod +x "$REPO/outside/tests/x.sh"; mktree || { rmrepo; return; }
  ln -s "$REPO/outside/tests" "$TREE/tests/escape"
  assign "/etc/passwd" "../outside/tests/x.sh" "tests/escape/x.sh" tests/a.sh
  assert_eq "$(arow /etc/passwd)" "unclaimed	file" "R20: 절대경로 → unclaimed"
  assert_eq "$(arow ../outside/tests/x.sh)" "unclaimed	file" "R20: .. → unclaimed"
  assert_eq "$(arow tests/escape/x.sh)" "unclaimed	file" "R20: 밖을 가리키는 링크 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조: 트리 안 shell 테스트는 claim"
  rmrepo
}
# R20 — shell 은 tests/*.sh 이면서 실행 비트가 있을 때만 claim 한다.
case_R20_shell_scope() {
  mkrepo; shtest tests/a.sh 0; shtest scripts/b.sh 0; printf '#!/bin/bash\n' > "$REPO/main/tests/c.sh"
  mktree || { rmrepo; return; }
  assign scripts/b.sh tests/c.sh tests/a.sh
  assert_eq "$(arow scripts/b.sh)" "unclaimed	file" "R20: tests/ 밖 .sh → unclaimed"
  assert_eq "$(arow tests/c.sh)" "unclaimed	file" "R20: 실행 비트 없음 → unclaimed"
  assert_eq "$(arow tests/a.sh)" "shell	file" "R20 양성 대조"
  rmrepo
}
# R21 — unittest 는 판정하지 못하는 파일을 claim 하지 않는다.
case_R21_unittest_refuses_unjudgeable_files() {
  mkrepo
  printf 'def test_bare():\n    assert False\n' > "$REPO/main/tests/test_bare.py"
  printf 'from unittest.mock import patch\nclass TestHelper:\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_plain_class.py"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\n' > "$REPO/main/tests/test_real.py"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_x(self):\n        pass\ndef test_bare():\n    assert False\n' > "$REPO/main/tests/test_mixed.py"
  mktree || { rmrepo; return; }
  assign tests/test_bare.py tests/test_plain_class.py tests/test_real.py tests/test_mixed.py
  assert_eq "$(arow tests/test_bare.py)" "unclaimed	file" "R21: 모듈 레벨 bare def test → unclaimed"
  assert_eq "$(arow tests/test_plain_class.py)" "unclaimed	file" "R21: TestCase 아닌 class Test → unclaimed"
  assert_eq "$(arow tests/test_mixed.py)" "unclaimed	file" "R21: TestCase + 모듈 레벨 bare def test 섞임 → unclaimed"
  assert_eq "$(arow tests/test_real.py)" "unittest	file" "R21 양성 대조: TestCase 하위클래스 → unittest"
  rmrepo
}
# R21 — go 는 *_test.go 를 패키지 unit 으로 접는다.
case_R21_go_unit_is_package() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"
  printf 'package pkg\n' > "$REPO/main/pkg/a_test.go"; printf 'package pkg\n' > "$REPO/main/pkg/b_test.go"
  mktree || { rmrepo; return; }
  assign pkg/a_test.go pkg/b_test.go pkg/a.go
  assert_eq "$(arow pkg)" "go	package" "R21: *_test.go → 패키지 unit"
  assert_eq "$(grep -c '^pkg	' "$REPO/assign.tsv")" "1" "R21: 같은 패키지는 한 행"
  assert_eq "$(arow pkg/a.go)" "unclaimed	file" "R21: *_test.go 아닌 go 파일은 claim 안 함"
  rmrepo
}
# R16 — 어느 어댑터도 못 돌리는 후보는 unclaimed 행으로 남는다(조용히 사라지지 않는다).
case_R16_unhandled_candidate_is_unclaimed() {
  mkrepo; printf 'x\n' > "$REPO/main/README"; mktree || { rmrepo; return; }
  assign spec/foo_spec.rb
  assert_eq "$(arow spec/foo_spec.rb)" "unclaimed	file" "R16: 지원하지 않는 후보 → unclaimed"
  assert_eq "$(trailer "$REPO/assign.tsv")" "#qg-assign	adapters=-	rows=1" "R16: 감지 0 은 adapters=-"
  rmrepo
}
case_bulk_absorbs_residual() {
  mkrepo; printf '[package]\nname="x"\n' > "$REPO/main/Cargo.toml"; printf 'test:\n\ttrue\n' > "$REPO/main/Makefile"
  mktree || { rmrepo; return; }
  local err; err=$(printf 'src/lib.rs\n' | bash "$RTS" assign "$TREE" "$REPO/assign.tsv" 2>&1 >/dev/null)
  assert_eq "$(arow BULK)" "cargo	bulk" "잔여는 첫 bulk 러너가 흡수"
  assert_contains "$err" "미실행 러너: make" "흡수하지 않은 bulk 러너를 알린다"
  rmrepo
}

for c in case_R17_assign_writes_trailer case_R17_failed_assign_leaves_no_file \
         case_R20_assign_refuses_units_outside_tree case_R20_shell_scope \
         case_R21_unittest_refuses_unjudgeable_files case_R21_go_unit_is_package \
         case_R16_unhandled_candidate_is_unclaimed case_bulk_absorbs_residual; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | tail -1`
Expected: FAIL — `Pass: 2 | Fail: 20` 근처(assign 하위명령이 아직 없어 `unknown subcommand`).

- [ ] **Step 3: assign arm 을 넣는다**

`plugins/quality-gates/scripts/run-test-selection.sh` 에서 아래 두 줄을 찾아(Edit 의 old_string)

```bash
  *)
    die "unknown subcommand: ${1:-} (expected detect|granularity|assign|run|unrun|pending)"
```

그 **바로 앞에** 다음 블록을 넣는다(new_string = 이 블록 + 위 두 줄):

````bash
  assign)
    [[ $# -eq 3 ]] || die "usage: assign <tree> <assign-file>   # stdin: 후보 파일 경로"
    w=$2; out=$3
    [[ -d "$w" ]] || die "not a directory: $w"
    [[ -d "$(dirname -- "$out")" ]] || die "배정 파일의 디렉토리가 없다: $out"
    adapters=$(detect_set "$w")
    has_adapter() { printf '%s\n' "$adapters" | grep -qxF -- "$1"; }
    # bulk 러너는 어느 파일 어댑터도 claim 하지 않은 잔여를 흡수한다. 둘 이상이면 첫째만 흡수자다.
    absorber=""; unused_bulk=""
    for r in cargo make npm-script; do
      if has_adapter "$r"; then
        if [[ -z "$absorber" ]]; then absorber="$r"; else unused_bulk="$unused_bulk $r"; fi
      fi
    done
    py=""; has_adapter pytest && py=pytest; has_adapter unittest && py=unittest
    js=""; has_adapter jest   && js=jest;   has_adapter vitest   && js=vitest
    tmp=$(mktemp "$(dirname -- "$out")/.qg-assign.XXXXXX") || die "임시 파일을 만들 수 없다: $out"
    residual=0; seen=""; n=0
    emit() {   # emit <unit> <runner> <granularity> — 같은 unit 은 한 번만
      printf '%s\n' "$seen" | grep -qxF -- "$1" && return 0
      printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$tmp" || { rm -f "$tmp"; die "배정 파일을 쓰지 못했다: $out"; }
      seen="$seen
$1"
      n=$((n + 1))
    }
    while IFS= read -r f || [[ -n "$f" ]]; do
      [[ -z "$f" ]] && continue
      if ! unit_within_worktree "$w" "$f"; then
        emit "$f" unclaimed file; continue
      fi
      claimed=""
      case "$f" in
        *_test.go) has_adapter go && claimed=go ;;
      esac
      if [[ -z "$claimed" && -n "$py" ]]; then
        case "$f" in test_*.py|*/test_*.py|*_test.py) claimed="$py" ;; esac
        if [[ "$claimed" == "unittest" ]] && ! unittest_can_judge "$w" "$f"; then
          claimed=""
        fi
      fi
      if [[ -z "$claimed" ]] && has_adapter shell; then
        case "$f" in
          tests/*.sh|*/tests/*.sh) [[ -x "$w/$f" ]] && claimed=shell ;;
        esac
      fi
      if [[ -z "$claimed" && -n "$js" ]]; then
        case "$f" in
          *.test.ts|*.test.tsx|*.test.js|*.test.jsx|*.spec.*) claimed="$js" ;;
        esac
      fi
      if [[ -n "$claimed" ]]; then
        if [[ "$(granularity_of "$claimed")" == "package" ]]; then
          emit "$(dirname -- "$f")" "$claimed" package
        else
          emit "$f" "$claimed" file
        fi
      elif [[ -n "$absorber" ]]; then
        residual=1
      else
        emit "$f" unclaimed file
      fi
    done
    [[ $residual -eq 1 ]] && emit BULK "$absorber" bulk
    for r in $unused_bulk; do
      echo "run-test-selection: 미실행 러너: $r (bulk 잔여는 $absorber 가 흡수)" >&2
    done
    adapter_list=$(printf '%s\n' "$adapters" | sed '/^$/d' | paste -sd, -)
    printf '#qg-assign\tadapters=%s\trows=%s\n' "${adapter_list:--}" "$n" >> "$tmp" \
      || { rm -f "$tmp"; die "배정 파일을 쓰지 못했다: $out"; }
    mv -f "$tmp" "$out" || { rm -f "$tmp"; die "배정 파일을 옮기지 못했다: $out"; }
    exit 0
    ;;
````

- [ ] **Step 4: 테스트 통과**

Run: `bash -n plugins/quality-gates/scripts/run-test-selection.sh && bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | tail -1`
Expected: `Total: 22 | Pass: 22 | Fail: 0`

- [ ] **Step 5: Commit**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/tests/test_run_test_selection.sh
git commit -m "feat(quality-gates): run-test-selection assign writes an atomic assign file with a trailer"
```

- [ ] **Step 6: 변이로 이빨을 확인한다**

Run: `python3 "$SCR/r-mutations.py" "$PWD" R16b R17c R20a R20s R21 R21g`
Expected: 여섯 줄 모두 `RED`, 마지막 줄 `tree restored`. `SURVIVED` 가 있으면 그 요구의 픽스처가 분기를 지나지 않는다는 뜻이다 — 테스트를 고치고 다시 잰다.

---

### Task 3: `run-test-selection.sh` 다시 쓰기 ③ — run · unrun · pending 과 행 파일

**Files:**
- Modify: `plugins/quality-gates/scripts/run-test-selection.sh`(행 파일 도우미 · run/unrun/pending arm 삽입)
- Modify: `plugins/quality-gates/tests/test_runner_adapters.sh`(실행 관문 case 추가)
- Modify: `plugins/quality-gates/tests/test_run_test_selection.sh`(행 파일 case 추가)

**Interfaces:**
- Consumes: Task 1 의 `adapter_usable` · `py_argv` · `granularity_of` · `unit_within_worktree` · `cargo_target_dir_for`.
- Produces:
  - `run <tree> <runner> <bulk|per-unit|flaky> <rows-file> <unit>...` — `<tree>` 는 detached 연결 worktree 여야 한다(주 작업 트리 · 브랜치에 붙은 트리는 exit 2). 행 `<unit>\t<status>\t<exit|->\t<mode>` 를 행 파일에 병합(같은 unit 교체)하고 꼬리 줄 `#qg-rows\trunner=<r>\tcommit=<tree HEAD sha>\trows=<N>\tflaky=<0|1>` 을 원자적으로 쓴다. 기존 행 파일의 runner · commit 이 다르면 exit 2. 어댑터 사용 불가면 그 unit 을 `unrun` 으로 병합하고 exit 3. `flaky` 는 per-unit 으로 돌리고 관측한 행(pass/fail/error)만 교체하며 행 파일당 한 번이다.
  - `unrun <rows-file> <runner> <commit|-> <unit>...` — 관측 없음 행(`unrun - skip`)을 병합한다.
  - `pending <rows-file> <unit>...` — 관측된 행(unrun 아닌 행)이 없는 unit 을 한 줄씩 낸다.
  - Task 6 의 `diff-test-results.py` 가 이 행 파일을 읽는다.

- [ ] **Step 1: 실행 관문 테스트를 더한다**

`plugins/quality-gates/tests/test_runner_adapters.sh` 의 끝 블록(Edit 의 old_string)

````bash
for c in case_detect_pytest case_detect_unittest case_detect_pytest_declared case_detect_shell \
         case_detect_jest case_detect_vitest case_detect_go case_detect_cargo case_detect_make \
         case_detect_npm_script case_detect_zero case_detect_polyglot case_detect_js_ambiguous_is_loud \
         case_detect_malformed_package_json_is_loud case_granularity_table case_adapter_count_claims_match; do
  echo "== $c"; $c
done
finish
````

을 아래로 바꾼다(new_string):

````bash
# ── 실행 관문 ───────────────────────────────────────────────────────────────────
# R14 — 기준선 트리는 어댑터를 스스로 다시 탐지한다: 그 트리에 없는 어댑터는 unrun 이다.
case_R14_tree_without_adapter_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"; printf 'x\n' > "$REPO/main/README"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R14: 트리에 shell 어댑터가 없으면 exit 3"
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh)" "unrun	-" "R14: 그 unit 은 unrun"
  rmrepo
}
# R3 — 러너가 이 머신에 없으면 unrun 이다(PRE_EXISTING 위장 방지).
case_R3_missing_toolchain_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"; printf 'package pkg\n' > "$REPO/main/pkg/a_test.go"
  mktree || { rmrepo; return; }
  PATH=/usr/bin:/bin bash "$RTS" run "$TREE" go per-unit "$REPO/rows.tsv" pkg 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R3: go 가 PATH 에 없으면 exit 3"
  assert_eq "$(row_of "$REPO/rows.tsv" pkg)" "unrun	-" "R3: unrun 행"
  rmrepo
}
# R3 — setup 실패도 unrun 이다. 러너(venv 의 python)는 있는데 의존성 설치만 실패하는 픽스처라
# setup 관문만이 이 unit 을 막는다(네트워크 없이 pip 가 바로 거부하는 요구 줄).
case_R3_setup_failure_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"
  printf '!!!not-a-requirement\n' > "$REPO/main/requirements.txt"; printf '.venv/\n' > "$REPO/main/.gitignore"
  printf 'import unittest\nclass T(unittest.TestCase):\n    def test_a(self):\n        pass\n' > "$REPO/main/tests/test_a.py"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" unittest per-unit "$REPO/rows.tsv" tests/test_a.py 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R3: setup(pip install) 실패면 exit 3"
  assert_eq "$(row_of "$REPO/rows.tsv" tests/test_a.py)" "unrun	-" "R3: unrun 행"
  rmrepo
}
# R3 — 실행 도중의 exit 127 도 unrun 이다.
case_R3_exit_127_is_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"
  printf '#!/bin/bash\nqg-no-such-command-xyz\n' > "$REPO/main/tests/a.sh"; chmod +x "$REPO/main/tests/a.sh"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh)" "unrun	127" "R3: exit 127 → unrun"
  rmrepo
}
# R4 — 0/1/127 밖의 종료 코드는 unrun 으로 접지 않는다(error).
case_R4_other_exit_is_error_not_unrun() {
  mkrepo; mkdir -p "$REPO/main/tests"
  printf '#!/bin/bash\nexit 2\n' > "$REPO/main/tests/a.sh"; chmod +x "$REPO/main/tests/a.sh"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh)" "error	2" "R4: exit 2 → error"
  rmrepo
}
# R21 — go unit 은 *_test.go 가 있는 패키지여야 존재한다. 없으면 absent(아무것도 판정하지 않은 pass 방지).
case_R21_go_package_without_tests_is_absent() {
  mkrepo; mkdir -p "$REPO/main/pkg"; printf 'module x\n' > "$REPO/main/go.mod"; printf 'package pkg\n' > "$REPO/main/pkg/a.go"
  mktree || { rmrepo; return; }
  local bin; bin=$(mktemp -d); printf '#!/bin/bash\nexit 0\n' > "$bin/go"; chmod +x "$bin/go"
  PATH="$bin:/usr/bin:/bin" bash "$RTS" run "$TREE" go per-unit "$REPO/rows.tsv" pkg 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" pkg)" "absent	-" "R21: *_test.go 없는 패키지 → absent"
  rm -rf "$bin"; rmrepo
}
# R22 — kill switch 가 켜져 있으면 run 은 저장소 코드를 하나도 실행하지 않는다.
case_R22_kill_switch_runs_no_repo_code() {
  mkrepo; mkdir -p "$REPO/main/tests"; local mark="$REPO/RAN"
  printf '#!/bin/bash\ntouch %q\n' "$mark" > "$REPO/main/tests/a.sh"; chmod +x "$REPO/main/tests/a.sh"
  mktree || { rmrepo; return; }
  DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "3" "R22: kill switch → exit 3"
  [ ! -e "$mark" ] && ok "R22: 저장소 코드가 돌지 않았다" || no "R22: kill switch 아래에서 저장소 코드가 돌았다"
  # 양성 대조 — 스위치 없이는 같은 픽스처가 실제로 돈다.
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows2.tsv" tests/a.sh 2>/dev/null
  [ -e "$mark" ] && ok "R22 양성 대조: 스위치 없이 돈다" || no "R22 양성 대조 실패 — 픽스처가 원래 안 돈다"
  rmrepo
}
# 카고 빌드 산출물은 트리마다 따로 둔다(R11 의 두 축 분리).
case_cargo_target_dir_is_per_tree() {
  mkrepo; printf '[package]\nname="x"\n' > "$REPO/main/Cargo.toml"
  mktree || { rmrepo; return; }
  local bin obs; bin=$(mktemp -d); obs="$bin/obs"
  printf '#!/bin/bash\nprintf "%%s\\n" "$CARGO_TARGET_DIR" > %q\nexit 0\n' "$obs" > "$bin/cargo"; chmod +x "$bin/cargo"
  PATH="$bin:/usr/bin:/bin" bash "$RTS" run "$TREE" cargo bulk "$REPO/rows.tsv" BULK 2>/dev/null
  assert_eq "$(cat "$obs" 2>/dev/null)" "$TREE/target" "cargo 는 그 트리의 target 에 빌드한다"
  rm -rf "$bin"; rmrepo
}
for c in case_detect_pytest case_detect_unittest case_detect_pytest_declared case_detect_shell \
         case_detect_jest case_detect_vitest case_detect_go case_detect_cargo case_detect_make \
         case_detect_npm_script case_detect_zero case_detect_polyglot case_detect_js_ambiguous_is_loud \
         case_detect_malformed_package_json_is_loud case_granularity_table case_adapter_count_claims_match \
         case_R14_tree_without_adapter_is_unrun case_R3_missing_toolchain_is_unrun \
         case_R3_setup_failure_is_unrun case_R3_exit_127_is_unrun case_R4_other_exit_is_error_not_unrun \
         case_R21_go_package_without_tests_is_absent case_R22_kill_switch_runs_no_repo_code \
         case_cargo_target_dir_is_per_tree; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 2: 행 파일 테스트를 더한다**

`plugins/quality-gates/tests/test_run_test_selection.sh` 의 끝 블록(Edit 의 old_string)

````bash
for c in case_R17_assign_writes_trailer case_R17_failed_assign_leaves_no_file \
         case_R20_assign_refuses_units_outside_tree case_R20_shell_scope \
         case_R21_unittest_refuses_unjudgeable_files case_R21_go_unit_is_package \
         case_R16_unhandled_candidate_is_unclaimed case_bulk_absorbs_residual; do
  echo "== $c"; $c
done
finish
````

을 아래로 바꾼다(new_string):

````bash
# ── run · unrun · pending ───────────────────────────────────────────────────────
# R11 — 브랜치에 붙은 트리 · 주 작업 트리에서는 돌리지 않는다.
case_R11_run_refuses_live_tree() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$REPO/main" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R11: 브랜치에 붙은 주 작업 트리 → exit 2"
  [ ! -e "$REPO/rows.tsv" ] && ok "R11: 행 파일을 쓰지 않았다" || no "R11: 거부했는데 행 파일이 생겼다"
  git -C "$REPO/main" checkout -q --detach
  bash "$RTS" run "$REPO/main" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: detached 라도 주 작업 트리면 exit 2"
  git -C "$REPO/main" worktree add -q -b side "$REPO/attached" >/dev/null 2>&1
  bash "$RTS" run "$REPO/attached" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "2" "R11: 브랜치에 붙은 연결 트리 → exit 2"
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/a.sh 2>/dev/null; rc=$?
  assert_eq "$rc" "0" "R11 양성 대조: 일회용 detached 트리는 돈다"
  rmrepo
}
# R5 — 행 파일은 그 행을 만든 트리의 커밋을 꼬리에 싣는다. 다른 트리의 행 파일에 병합하지 않는다.
case_R5_rows_carry_their_tree_commit() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  local c; c=$(git -C "$TREE" rev-parse HEAD)
  assert_eq "$(trailer "$REPO/rows.tsv")" "#qg-rows	runner=shell	commit=$c	rows=1	flaky=0" "R5: 꼬리 줄이 트리 커밋을 싣는다"
  ( cd "$REPO/main" && echo y > tests/y && git add -A && git commit -qm y )
  git -C "$REPO/main" worktree add -q --detach "$REPO/wt2" HEAD
  bash "$RTS" run "$REPO/wt2" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R5: 다른 커밋의 트리로 같은 행 파일에 병합하면 exit 2"
  rmrepo
}
# R7 — 다시 돌린 unit 의 행은 교체된다. 같은 unit 이 두 행이 되지 않는다.
case_R7_rerun_replaces_rows() {
  mkrepo; shtest tests/ok.sh 0; shtest tests/bad.sh 1; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell bulk "$REPO/rows.tsv" tests/ok.sh tests/bad.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/ok.sh)" "fail	1	bulk" "R7 전제: bulk red 는 모든 unit 에 찍힌다"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/ok.sh tests/bad.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/ok.sh)" "pass	0	per-unit" "R7: per-unit 행이 bulk 행을 교체"
  assert_eq "$(grep -c '^tests/ok.sh	' "$REPO/rows.tsv")" "1" "R7: 같은 unit 은 한 행"
  assert_eq "$(trailer "$REPO/rows.tsv" | cut -f4)" "rows=2" "R7: 꼬리 행 수"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/ok.sh tests/ok.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R7: 인자에 같은 unit 이 두 번 오면 exit 2"
  rmrepo
}
# R15 — flaky 재실행은 행 파일당 한 번이고, 관측하지 못한 재실행은 원래 행을 지킨다.
case_R15_flaky_rerun_once_and_keeps_unobserved() {
  mkrepo; shtest tests/bad.sh 1; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/bad.sh 2>/dev/null
  DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1 bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/bad.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/bad.sh)" "fail	1	per-unit" "R15: 관측 못 한 flaky 재실행은 원래 행을 지킨다"
  assert_eq "$(trailer "$REPO/rows.tsv" | cut -f5)" "flaky=1" "R15: 시도는 한 번으로 센다"
  bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/bad.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "R15: 두 번째 flaky 재실행은 거부"
  rmrepo
}
case_R15_flaky_rerun_unobserved_exit_keeps_row() {
  mkrepo; local flag="$REPO/flag127"
  printf '#!/bin/bash\n[ -e %q ] && exec qg-no-such-command-xyz\ntouch %q\nexit 1\n' "$flag" "$flag" > "$REPO/main/tests/gone.sh"
  chmod +x "$REPO/main/tests/gone.sh"; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/gone.sh 2>/dev/null
  bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/gone.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/gone.sh)" "fail	1	per-unit" "R15: 재실행이 exit 127(관측 없음)이면 원래 행을 지킨다"
  rmrepo
}
case_R15_flaky_rerun_replaces_observed_row() {
  mkrepo; local flag="$REPO/flag"
  printf '#!/bin/bash\n[ -e %q ] && exit 0\ntouch %q\nexit 1\n' "$flag" "$flag" > "$REPO/main/tests/flip.sh"
  chmod +x "$REPO/main/tests/flip.sh"; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/flip.sh 2>/dev/null
  bash "$RTS" run "$TREE" shell flaky "$REPO/rows.tsv" tests/flip.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" tests/flip.sh)" "pass	0	flaky" "R15: 관측한 flaky 재실행은 행을 교체하고 표시한다"
  rmrepo
}
# R20 — run 에서도 같은 범위를 다시 검사한다: 트리 밖 unit 은 absent, 범위 밖 shell 은 실행하지 않는다.
case_R20_run_rechecks_scope() {
  mkrepo; shtest tests/a.sh 0; local mark="$REPO/RAN"
  printf '#!/bin/bash\ntouch %q\n' "$mark" > "$REPO/main/run.sh"; chmod +x "$REPO/main/run.sh"
  mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" ../main/run.sh run.sh tests/a.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/rows.tsv" ../main/run.sh | cut -f1)" "absent" "R20: 트리 밖 unit → absent"
  assert_eq "$(row_of "$REPO/rows.tsv" run.sh | cut -f1)" "unrun" "R20: 범위 밖 shell unit → unrun(실행 거부)"
  [ ! -e "$mark" ] && ok "R20: 범위 밖 스크립트가 돌지 않았다" || no "R20: 범위 밖 스크립트가 돌았다"
  assert_eq "$(row_of "$REPO/rows.tsv" tests/a.sh | cut -f1)" "pass" "R20 양성 대조"
  rmrepo
}
case_unrun_and_pending() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" unrun "$REPO/b.tsv" shell - tests/a.sh tests/b.sh 2>/dev/null
  assert_eq "$(row_of "$REPO/b.tsv" tests/a.sh)" "unrun	-	skip" "unrun 은 skip 행을 쓴다"
  assert_eq "$(trailer "$REPO/b.tsv")" "#qg-rows	runner=shell	commit=-	rows=2	flaky=0" "unrun 꼬리 줄"
  bash "$RTS" unrun "$REPO/b.tsv" shell nothex tests/a.sh 2>/dev/null; assert_eq "$?" "2" "commit 은 sha 또는 - 만"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  assert_eq "$(bash "$RTS" pending "$REPO/rows.tsv" tests/a.sh tests/new.sh | tr '\n' ' ')" "tests/new.sh " \
    "pending 은 관측된 행이 없는 unit 만 낸다"
  assert_eq "$(bash "$RTS" pending "$REPO/b.tsv" tests/a.sh | tr '\n' ' ')" "tests/a.sh " "unrun 행은 관측이 아니다"
  rmrepo
}
case_truncated_rows_file_is_refused() {
  mkrepo; shtest tests/a.sh 0; mktree || { rmrepo; return; }
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null
  sed -i.bak '$d' "$REPO/rows.tsv"
  bash "$RTS" run "$TREE" shell per-unit "$REPO/rows.tsv" tests/a.sh 2>/dev/null; local rc=$?
  assert_eq "$rc" "2" "꼬리 줄이 잘린 행 파일에 병합하지 않는다"
  rmrepo
}
for c in case_R17_assign_writes_trailer case_R17_failed_assign_leaves_no_file \
         case_R20_assign_refuses_units_outside_tree case_R20_shell_scope \
         case_R21_unittest_refuses_unjudgeable_files case_R21_go_unit_is_package \
         case_R16_unhandled_candidate_is_unclaimed case_bulk_absorbs_residual \
         case_R11_run_refuses_live_tree case_R5_rows_carry_their_tree_commit case_R7_rerun_replaces_rows \
         case_R15_flaky_rerun_once_and_keeps_unobserved case_R15_flaky_rerun_unobserved_exit_keeps_row \
         case_R15_flaky_rerun_replaces_observed_row \
         case_R20_run_rechecks_scope case_unrun_and_pending case_truncated_rows_file_is_refused; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 3: 실패를 확인한다**

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | tail -1`
Expected: 둘 다 FAIL(`run` · `unrun` · `pending` 이 아직 없다) — 대략 `Pass: 20 | Fail: 12`, `Pass: 32 | Fail: 17`.

- [ ] **Step 4: 행 파일 도우미를 넣는다**

`run-test-selection.sh` 에서 최상위 `case "${1:-}" in` 줄 바로 다음 줄이 `  detect)` 인 자리(Edit 의 old_string = 이 두 줄)

```bash
case "${1:-}" in
  detect)
```

앞에 다음 블록을 넣는다(new_string = 이 블록 + 위 두 줄):

````bash
COMMIT_RE='^([0-9a-f]{40}|[0-9a-f]{64}|-)$'

# 행 파일을 읽어 ROWS_UNIT/ROWS_LINE 배열과 꼬리 값(T_RUNNER/T_COMMIT/T_FLAKY)을 채운다.
# 없는 파일은 빈 행 집합이다. 꼬리 줄이 정확히 하나, 마지막 줄이 아니거나 행 수가 다르면 die.
ROWS_UNIT=(); ROWS_LINE=(); T_RUNNER=""; T_COMMIT=""; T_FLAKY=0
load_rows() {
  local f=$1 line n=0 tails=0 last=""
  ROWS_UNIT=(); ROWS_LINE=(); T_RUNNER=""; T_COMMIT=""; T_FLAKY=0
  [[ -e "$f" ]] || return 0
  [[ -f "$f" ]] || die "행 파일이 일반 파일이 아니다: $f"
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ -z "$line" ]] && continue
    last=$line
    if [[ "$line" == '#qg-rows'$'\t'* ]]; then
      tails=$((tails + 1))
      T_RUNNER=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^runner=//p')
      T_COMMIT=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^commit=//p')
      T_FLAKY=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^flaky=//p')
      T_ROWS=$(printf '%s\n' "$line" | tr '\t' '\n' | sed -n 's/^rows=//p')
      continue
    fi
    ROWS_UNIT+=("${line%%$'\t'*}")
    ROWS_LINE+=("$line")
    n=$((n + 1))
  done < "$f"
  [[ $tails -eq 1 && "$last" == '#qg-rows'$'\t'* ]] || die "행 파일 꼬리 줄이 정확히 하나의 마지막 줄이 아니다: $f"
  [[ "${T_ROWS:-}" == "$n" ]] || die "행 파일 행 수 불일치(꼬리 ${T_ROWS:-?} · 실제 $n): $f"
}

# 새 행(NEW_UNIT/NEW_LINE)을 기존 행에 병합해 원자적으로 쓴다. 같은 unit 은 교체한다(R7).
write_rows() {
  local f=$1 runner=$2 commit=$3 flaky=$4 tmp i j keep n=0
  tmp=$(mktemp "$(dirname "$f")/.qg-rows.XXXXXX") || die "임시 파일을 만들 수 없다: $(dirname "$f")"
  {
    for ((i = 0; i < ${#ROWS_UNIT[@]}; i++)); do
      keep=1
      for ((j = 0; j < ${#NEW_UNIT[@]}; j++)); do
        [[ "${ROWS_UNIT[$i]}" == "${NEW_UNIT[$j]}" ]] && { keep=0; break; }
      done
      [[ $keep -eq 1 ]] && { printf '%s\n' "${ROWS_LINE[$i]}"; n=$((n + 1)); }
    done
    for ((j = 0; j < ${#NEW_UNIT[@]}; j++)); do
      printf '%s\n' "${NEW_LINE[$j]}"; n=$((n + 1))
    done
    printf '#qg-rows\trunner=%s\tcommit=%s\trows=%s\tflaky=%s\n' "$runner" "$commit" "$n" "$flaky"
  } > "$tmp" || { rm -f "$tmp"; die "행 파일을 쓰지 못했다: $f"; }
  mv -f "$tmp" "$f" || { rm -f "$tmp"; die "행 파일을 옮기지 못했다: $f"; }
}

# 같은 unit 이 인자에 두 번 오면 거부한다 — 병합이 입력 순서에 의존하게 된다.
reject_duplicate_units() {
  local seen="" u
  for u in "$@"; do
    printf '%s\n' "$seen" | grep -qxF -- "$u" && die "unit 이 두 번 왔다: $u"
    seen="$seen
$u"
  done
}
````

- [ ] **Step 5: run · unrun · pending arm 을 넣는다**

Task 2 Step 3 과 같은 자리(`  *)` + `die "unknown subcommand: …"` 두 줄) **바로 앞에** 다음 블록을 넣는다:

````bash
  run)
    [[ $# -ge 6 ]] || die "usage: run <tree> <runner> <bulk|per-unit|flaky> <rows-file> <unit>..."
    w=$2; runner=$3; mode=$4; rows=$5; shift 5
    [[ -d "$w" ]] || die "not a directory: $w"
    case "$mode" in bulk|per-unit|flaky) ;; *) die "unknown mode: $mode (expected bulk|per-unit|flaky)" ;; esac
    gran=$(granularity_of "$runner") || die "unknown runner: $runner"
    [[ -d "$(dirname -- "$rows")" ]] || die "행 파일의 디렉토리가 없다: $rows"
    reject_duplicate_units "$@"
    # HEAD 축과 기준선 축은 둘 다 일회용 트리다 — 브랜치에 붙은 작업 트리에서는 돌리지 않는다(R11).
    git -C "$w" rev-parse --git-dir >/dev/null 2>&1 || die "git 트리가 아니다: $w"
    if git -C "$w" symbolic-ref -q HEAD >/dev/null 2>&1; then
      die "브랜치에 붙은 트리에서는 돌리지 않는다 — create-baseline/create-head 가 만든 detached 트리를 넘겨라: $w"
    fi
    [[ "$(git -C "$w" rev-parse --git-dir)" != "$(git -C "$w" rev-parse --git-common-dir)" ]] \
      || die "주 작업 트리에서는 돌리지 않는다 — 일회용 트리를 넘겨라: $w"
    commit=$(git -C "$w" rev-parse HEAD 2>/dev/null) || die "트리의 커밋을 읽지 못했다: $w"
    load_rows "$rows"
    if [[ ${#ROWS_UNIT[@]} -gt 0 || -n "$T_RUNNER" ]]; then
      [[ "$T_RUNNER" == "$runner" ]] || die "행 파일의 러너가 다르다(${T_RUNNER} ≠ $runner): $rows"
      [[ "$T_COMMIT" == "$commit" ]] || die "행 파일이 다른 트리의 것이다(${T_COMMIT} ≠ $commit): $rows"
    fi
    flaky_out=$T_FLAKY
    if [[ "$mode" == "flaky" ]]; then
      [[ "$T_FLAKY" == "0" ]] || die "flaky 재실행은 행 파일당 한 번이다(R15): $rows"
      flaky_out=1
    fi

    NEW_UNIT=(); NEW_LINE=()
    if ! adapter_usable "$w" "$runner"; then
      if [[ "$mode" != "flaky" ]]; then
        for u in "$@"; do NEW_UNIT+=("$u"); NEW_LINE+=("$u"$'\t'"unrun"$'\t'"-"$'\t'"$mode"); done
      fi
      write_rows "$rows" "$runner" "$commit" "$flaky_out"
      exit 3
    fi
    PY_ARGV=(python3)
    py_argv "$w"

    has_go_tests() {
      local d=$1 g
      for g in "$d"/*_test.go; do [[ -f "$g" ]] && return 0; done
      return 1
    }
    # file unit 은 트리 안의 일반 파일, package unit 은 *_test.go 가 있는 디렉토리여야 존재한다(R20 · R21).
    exists_unit() {
      case "$gran" in
        file)    unit_within_worktree "$w" "$1" && [[ -f "$w/$1" ]] ;;
        package) unit_within_worktree "$w" "$1" && [[ -d "$w/$1" ]] && has_go_tests "$w/$1" ;;
        bulk)    [[ "$1" == "BULK" ]] ;;
      esac
    }
    shell_unit_in_scope() {
      unit_within_worktree "$w" "$1" || return 1
      case "$1" in
        tests/*.sh|*/tests/*.sh) [[ -x "$w/$1" ]] ;;
        *) return 1 ;;
      esac
    }
    refused=""
    is_refused() { printf '%s\n' "$refused" | grep -qxF -- "$1"; }
    status_of_exit() {
      case "$1" in 0) echo pass ;; 1) echo fail ;; 127) echo unrun ;; *) echo error ;; esac
    }
    run_units() {
      local rc=0 u d b dotted
      local -a go_args
      case "$runner" in
        pytest)
          ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m pytest -p no:cacheprovider -q "$@" ) >&2 || rc=$? ;;
        unittest)
          for u in "$@"; do
            d=$(dirname -- "$u"); b=$(basename -- "$u")
            if [[ "$d" == "." || -f "$w/$d/__init__.py" ]]; then
              dotted="${u%.py}"; dotted=$(printf '%s' "$dotted" | tr '/' '.')
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m unittest "$dotted" ) >&2 || rc=$?
            else
              ( cd "$w" && PYTHONDONTWRITEBYTECODE=1 "${PY_ARGV[@]}" -m unittest discover -s "$d" -p "$b" ) >&2 || rc=$?
            fi
          done ;;
        shell)
          for u in "$@"; do
            if ! shell_unit_in_scope "$u"; then
              echo "run-test-selection: 실행 거부: $u — shell 어댑터의 범위(tests/*.sh, 실행 비트) 밖" >&2
              refused="$refused
$u"
              continue
            fi
            ( cd "$w" && bash "$u" ) >&2 || rc=$?
          done ;;
        jest)
          ( cd "$w" && npx --no-install jest --cache=false --ci "$@" ) >&2 || rc=$? ;;
        vitest)
          ( cd "$w" && npx --no-install vitest run "$@" ) >&2 || rc=$? ;;
        go)
          # 모듈 모드에서 `./` 없는 패턴은 import 경로로 풀린다 — 디렉토리 패턴으로 넘긴다.
          go_args=()
          for u in "$@"; do
            case "$u" in
              .|./*) go_args+=("$u") ;;
              *)     go_args+=("./$u") ;;
            esac
          done
          ( cd "$w" && go test "${go_args[@]}" ) >&2 || rc=$? ;;
        cargo)
          # 빌드 산출물은 트리마다 따로 둔다 — 두 축이 같은 target 을 나누면 한쪽 빌드가 다른 쪽을 덮는다.
          ( cd "$w" && CARGO_TARGET_DIR="$(cargo_target_dir_for "$w")" cargo test ) >&2 || rc=$? ;;
        make)
          ( cd "$w" && make test ) >&2 || rc=$? ;;
        npm-script)
          ( cd "$w" && npm test ) >&2 || rc=$? ;;
      esac
      return $rc
    }
    row_mode=$mode
    [[ "$mode" == "flaky" ]] && row_mode=flaky
    add_row() {   # add_row <unit> <status> <exit>
      if [[ "$mode" == "flaky" ]]; then
        # flaky 재실행이 관측하지 못한 unit 은 원래 행을 지킨다(R15).
        case "$2" in pass|fail|error) ;; *) return 0 ;; esac
      fi
      NEW_UNIT+=("$1"); NEW_LINE+=("$1"$'\t'"$2"$'\t'"$3"$'\t'"$row_mode")
    }
    exec_mode=$mode
    [[ "$mode" == "flaky" ]] && exec_mode=per-unit
    if [[ "$exec_mode" == "bulk" ]]; then
      present=()
      for u in "$@"; do exists_unit "$u" && present+=("$u"); done
      if [[ ${#present[@]} -gt 0 ]]; then
        run_units "${present[@]}"; brc=$?
        bst=$(status_of_exit "$brc")
      fi
      for u in "$@"; do
        if is_refused "$u"; then add_row "$u" unrun -
        elif exists_unit "$u"; then add_row "$u" "$bst" "$brc"
        else add_row "$u" absent -; fi
      done
    else
      for u in "$@"; do
        if exists_unit "$u"; then
          run_units "$u"; urc=$?
          if is_refused "$u"; then add_row "$u" unrun -
          else add_row "$u" "$(status_of_exit "$urc")" "$urc"; fi
        else
          add_row "$u" absent -
        fi
      done
    fi
    write_rows "$rows" "$runner" "$commit" "$flaky_out"
    exit 0
    ;;
  unrun)
    [[ $# -ge 5 ]] || die "usage: unrun <rows-file> <runner> <commit|-> <unit>..."
    rows=$2; runner=$3; commit=$4; shift 4
    granularity_of "$runner" >/dev/null
    [[ "$commit" =~ $COMMIT_RE ]] || die "commit 은 전체 sha 또는 '-' 여야 한다: $commit"
    [[ -d "$(dirname -- "$rows")" ]] || die "행 파일의 디렉토리가 없다: $rows"
    reject_duplicate_units "$@"
    load_rows "$rows"
    if [[ ${#ROWS_UNIT[@]} -gt 0 || -n "$T_RUNNER" ]]; then
      [[ "$T_RUNNER" == "$runner" ]] || die "행 파일의 러너가 다르다(${T_RUNNER} ≠ $runner): $rows"
      [[ "$T_COMMIT" == "$commit" ]] || die "행 파일이 다른 커밋의 것이다(${T_COMMIT} ≠ $commit): $rows"
    fi
    NEW_UNIT=(); NEW_LINE=()
    for u in "$@"; do NEW_UNIT+=("$u"); NEW_LINE+=("$u"$'\t'"unrun"$'\t'"-"$'\t'"skip"); done
    write_rows "$rows" "$runner" "$commit" "$T_FLAKY"
    exit 0
    ;;
  pending)
    [[ $# -ge 3 ]] || die "usage: pending <rows-file> <unit>..."
    rows=$2; shift 2
    load_rows "$rows"
    for u in "$@"; do
      observed=0
      for ((i = 0; i < ${#ROWS_UNIT[@]}; i++)); do
        if [[ "${ROWS_UNIT[$i]}" == "$u" ]]; then
          st=$(printf '%s\n' "${ROWS_LINE[$i]}" | cut -f2)
          [[ "$st" != "unrun" ]] && observed=1
          break
        fi
      done
      [[ $observed -eq 1 ]] || printf '%s\n' "$u"
    done
    exit 0
    ;;
````

- [ ] **Step 6: 테스트 통과**

Run: `bash -n plugins/quality-gates/scripts/run-test-selection.sh && bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | tail -1 && bash plugins/quality-gates/tests/test_run_test_selection.sh 2>&1 | tail -1`
Expected: `Total: 32 | Pass: 32 | Fail: 0` 과 `Total: 49 | Pass: 49 | Fail: 0`. 전체 파일은 664줄 근처다(`wc -l`).

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/scripts/run-test-selection.sh plugins/quality-gates/tests/test_runner_adapters.sh plugins/quality-gates/tests/test_run_test_selection.sh
git commit -m "feat(quality-gates): run-test-selection merges rows into trailer-sealed row files (run/unrun/pending)"
```

- [ ] **Step 8: 변이로 이빨을 확인한다**

Run: `python3 "$SCR/r-mutations.py" "$PWD" R3 R3s R4 R5b R7b R11 R14 R15 R15b R20r R20b R21b R22`
Expected: 모두 `RED`, 마지막 줄 `tree restored`.

---

### Task 4: `qg-worktree.sh` — 실행 안 메모 · 일회용 트리 재생성

**Files:**
- Modify: `plugins/quality-gates/scripts/qg-worktree.sh`
- Create: `plugins/quality-gates/tests/test_differential_trees.sh`
- Modify(있을 때만): `plugins/quality-gates/tests/test_runtime_contract_invariance.sh`

**Interfaces:**
- Consumes: 없음(기존 `make_detached_worktree` · `create-head` · `remove`).
- Produces:
  - `qg-worktree.sh memo-init <project-dir>` — 리포 밖 임시 디렉토리를 만들고 표지 `.qg-memo` 를 둔 뒤 그 절대 경로를 한 줄 낸다. 리포 안이면 exit 2(만든 디렉토리는 지운다).
  - `qg-worktree.sh memo-drop <memo-dir>` — 표지가 있는 디렉토리만 지운다. 없는 경로는 exit 0, 표지 없는 디렉토리는 exit 2.
  - `create-baseline` · `create-head` 는 같은 자리에 남은 일회용 트리를 지우고 다시 만든다.

- [ ] **Step 1: 테스트를 쓴다**

`plugins/quality-gates/tests/test_differential_trees.sh` 를 만든다(실행 비트):

````bash
#!/usr/bin/env bash
# test_differential_trees.sh — 차등 테스트의 일회용 트리와 실행 안 메모(qg-worktree.sh).
# 요구: R6 · R12 · R23 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WT="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/qg-worktree.sh"
SEAL="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/seal-worktree.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=""
mkrepo() {
  R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
  R=$(cd "$R" && pwd -P)
  git init -q -b main "$R/repo" || exit 1
  git -C "$R/repo" config user.email t@t; git -C "$R/repo" config user.name t; git -C "$R/repo" config commit.gpgsign false
  printf '.claude/\n' > "$R/repo/.gitignore"; echo 1 > "$R/repo/a"
  ( cd "$R/repo" && git add -A && git commit -qm base ) || exit 1
}
rmrepo() { cd / && rm -rf "$R"; }

# R6 — 메모는 검사 대상 트리 밖에 생기고, 표지가 있는 디렉토리만 지운다.
case_R6_memo_lives_outside_the_tree() {
  mkrepo
  local m; m=$(bash "$WT" memo-init "$R/repo" 2>/dev/null)
  [ -n "$m" ] && [ -f "$m/.qg-memo" ] && ok "R6: 메모를 만들고 표지를 둔다" || no "R6: 메모 생성 실패 ($m)"
  case "$m/" in "$R/repo"/*) no "R6: 메모가 트리 안이다" ;; *) ok "R6: 메모는 트리 밖" ;; esac
  bash "$WT" memo-drop "$m"; assert_eq "$?" "0" "R6: memo-drop exit 0"
  [ ! -e "$m" ] && ok "R6: 실행이 끝나면 메모가 사라진다" || no "R6: 메모가 남았다"
  bash "$WT" memo-drop "$m"; assert_eq "$?" "0" "R6: 없는 메모 drop 은 멱등"
  rmrepo
}
case_R6_memo_inside_the_tree_is_refused() {
  mkrepo; mkdir -p "$R/repo/tmp"
  local out rc; out=$(TMPDIR="$R/repo/tmp" bash "$WT" memo-init "$R/repo" 2>/dev/null); rc=$?
  assert_eq "$rc" "2" "R6: TMPDIR 이 트리 안이면 exit 2"
  assert_eq "$(ls -A "$R/repo/tmp")" "" "R6: 거부하면서 만든 디렉토리를 남기지 않는다"
  rmrepo
}
case_R6_memo_drop_refuses_unmarked_dir() {
  mkrepo; mkdir -p "$R/precious"; echo keep > "$R/precious/f"
  bash "$WT" memo-drop "$R/precious" 2>/dev/null; assert_eq "$?" "2" "R6: 표지 없는 디렉토리는 거부"
  [ -f "$R/precious/f" ] && ok "R6: 거부된 디렉토리가 살아 있다" || no "R6: 표지 없는 디렉토리를 지웠다"
  rmrepo
}
# R12 — HEAD 축을 기준선 커밋으로 만들 수 없다(봉인과 트리가 다르면 거부).
case_R12_head_axis_refuses_the_baseline_sha() {
  mkrepo; local base; base=$(git -C "$R/repo" rev-parse HEAD)
  echo 2 > "$R/repo/a"
  ( cd "$R/repo" && bash "$WT" create-head "$base" "sess12345678" ) >/dev/null 2>&1; local rc=$?
  assert_eq "$rc" "2" "R12: 기준선 sha 로 HEAD 축을 만들면 거부"
  local sealed; sealed=$( cd "$R/repo" && bash "$SEAL" seal "sess12345678" 2>/dev/null )
  local wt; wt=$( cd "$R/repo" && bash "$WT" create-head "$sealed" "sess12345678" 2>/dev/null ); rc=$?
  assert_eq "$rc" "0" "R12 양성 대조: 지금 봉인으로는 만든다"
  ( cd "$R/repo" && bash "$WT" remove "$wt" ) >/dev/null 2>&1
  rmrepo
}
# R23 — 앞 실행이 남긴 일회용 트리(추적되지 않은 산출물이 있어도)는 다음 실행이 지우고 다시 만든다.
case_R23_stale_tree_is_replaced() {
  mkrepo; local base; base=$(git -C "$R/repo" rev-parse HEAD)
  local wt; wt=$( cd "$R/repo" && bash "$WT" create-baseline "$base" "sess12345678" 2>/dev/null )
  echo junk > "$wt/untracked-output"; echo changed > "$wt/a"
  local wt2 rc; wt2=$( cd "$R/repo" && bash "$WT" create-baseline "$base" "sess12345678" 2>/dev/null ); rc=$?
  assert_eq "$rc" "0" "R23: 남은 트리가 있어도 다시 만든다"
  assert_eq "$wt2" "$wt" "R23: 같은 자리"
  [ ! -e "$wt2/untracked-output" ] && [ "$(cat "$wt2/a")" = "1" ] && ok "R23: 새 트리는 깨끗하다" || no "R23: 앞 실행의 흔적이 남았다"
  ( cd "$R/repo" && bash "$WT" remove "$wt2" ) >/dev/null 2>&1
  [ ! -e "$wt2" ] && ok "R23: remove 가 트리를 지운다" || no "R23: remove 뒤에 트리가 남았다"
  rmrepo
}
case_R23_remove_refuses_outside_namespace() {
  mkrepo; mkdir -p "$R/repo/outside"
  ( cd "$R/repo" && bash "$WT" remove "$R/repo/outside" ) >/dev/null 2>&1; assert_eq "$?" "2" "R23: 이름공간 밖 remove 는 거부"
  [ -d "$R/repo/outside" ] && ok "R23: 거부된 대상이 살아 있다" || no "R23: 이름공간 밖을 지웠다"
  rmrepo
}

for c in case_R6_memo_lives_outside_the_tree case_R6_memo_inside_the_tree_is_refused \
         case_R6_memo_drop_refuses_unmarked_dir case_R12_head_axis_refuses_the_baseline_sha \
         case_R23_stale_tree_is_replaced case_R23_remove_refuses_outside_namespace; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/quality-gates/tests/test_differential_trees.sh && bash plugins/quality-gates/tests/test_differential_trees.sh 2>&1 | tail -1`
Expected: FAIL — `memo-init` · `memo-drop` 이 없고, 남은 트리 재생성이 「refuse to clobber」 로 막힌다.

- [ ] **Step 3: 스크립트를 고친다**

①~④ 가 이 파일의 주석을 바꿨을 수 있어서, 문자열이 아니라 자리로 고치는 스크립트를 쓴다 — `wt="$parent/${prefix}-${sid_short}"` 줄과 `git worktree add --detach "$wt" "$sha"` 줄 사이를 새 블록으로 바꾸고, 기본 arm(`  *)` + `unknown subcommand`) 앞에 `memo-init` · `memo-drop` arm 을 넣는다. `$SCR/patch_worktree.py` 로 저장하고 돌린다:

````python
#!/usr/bin/env python3
"""qg-worktree.sh 에 ⑤ 변경을 적용한다 — 일회용 트리 재생성(R23) · 실행 안 메모(R6)."""
import sys
from pathlib import Path

path = Path(sys.argv[1])
lines = path.read_text(encoding="utf-8").split("\n")

start = [i for i, l in enumerate(lines) if l.startswith('  wt="$parent/${prefix}-${sid_short}"')]
end = [i for i, l in enumerate(lines) if l.startswith('  git worktree add --detach "$wt" "$sha"')]
assert len(start) == 1 and len(end) == 1 and start[0] < end[0], (start, end)
block = [
    "",
    "  # 이 이름공간의 base-·head- 트리는 일회용이다. 앞 실행이 남긴 것은 지우고 다시 만든다 —",
    "  # 남겨 두면 그 세션은 다음 차등에서 트리를 못 만든다(R23).",
    "  git worktree prune >/dev/null 2>&1 || true",
    '  if [[ -L "$wt" ]]; then',
    '    rm -f -- "$wt" || die "앞 실행이 남긴 링크를 지우지 못했다: $wt"',
    '  elif [[ -e "$wt" ]]; then',
    '    git worktree remove --force "$wt" >/dev/null 2>&1 || rm -rf -- "$wt" \\',
    '      || die "앞 실행이 남긴 트리를 지우지 못했다: $wt"',
    "  fi",
    "  git worktree prune >/dev/null 2>&1 || true",
]
lines[start[0] + 1:end[0]] = block

memo = r'''  memo-init)
    # 실행 안 메모 — 한 번의 /qg 동안 기준선 행 · 배정 · 대조 산출을 담는다. 검사 대상 트리
    # 밖이어야 봉인(HEAD 축)에 섞이지 않는다(R6).
    [[ $# -eq 2 ]] || die "usage: memo-init <project-dir>"
    root=$(git -C "$2" rev-parse --show-toplevel 2>/dev/null) || die "git 리포가 아니다: $2"
    root=$(cd "$root" && pwd -P) || die "cd failed: $root"
    memo=$(mktemp -d "${TMPDIR:-/tmp}/qg-memo.XXXXXX") || die "메모 디렉토리를 만들지 못했다"
    memo_p=$(cd "$memo" && pwd -P) || { rmdir "$memo"; die "메모 디렉토리를 해소하지 못했다: $memo"; }
    case "$memo_p/" in
      "$root"/*) rmdir "$memo"; die "메모가 검사 대상 트리 안에 생긴다($memo_p) — TMPDIR 을 $root 밖으로 두고 다시 실행하라" ;;
    esac
    : > "$memo_p/.qg-memo" || { rmdir "$memo"; die "메모 표지를 쓰지 못했다: $memo_p"; }
    printf '%s\n' "$memo_p"
    ;;
  memo-drop)
    [[ $# -eq 2 ]] || die "usage: memo-drop <memo-dir>"
    [[ -e "$2" ]] || exit 0
    [[ -d "$2" && ! -L "$2" && -f "$2/.qg-memo" ]] || die "qg 메모가 아니다 — 지우지 않는다: $2"
    rm -rf -- "$2" || die "메모를 지우지 못했다: $2"
    ;;
'''
default = [i for i, l in enumerate(lines) if l == "  *)"]
assert len(default) >= 1, default
d = default[-1]
assert 'unknown subcommand' in lines[d + 1], lines[d + 1]
lines[d:d] = memo.rstrip("\n").split("\n")
path.write_text("\n".join(lines), encoding="utf-8")
print("patched", path)
````

Run: `python3 "$SCR/patch_worktree.py" plugins/quality-gates/scripts/qg-worktree.sh && bash -n plugins/quality-gates/scripts/qg-worktree.sh && git diff --stat -- plugins/quality-gates/scripts/qg-worktree.sh`
Expected: `patched …` 와 한 파일 변경. 파일 머리 주석의 하위명령 목록에 두 줄을 더한다:

```bash
#   memo-init <project-dir>      -> 리포 밖 실행 안 메모 디렉토리의 절대 경로 (표지 .qg-memo). 리포 안이면 exit 2
#   memo-drop <memo-dir>         -> 표지가 있는 메모만 지운다. 없는 경로는 exit 0, 표지 없으면 exit 2
```

머리 주석에 「`/qg branch` 와 같은 경로를 노린다」 류의 충돌 설명이 남아 있으면 지운다(그 모드는 ① 에서 사라졌다).

- [ ] **Step 4: 옛 「clobber 거부」 케이스를 정리한다**

`test_runtime_contract_invariance.sh` 에 `case_create_baseline_refuses_colliding_user_worktree` 가 아직 있으면(① 이 `create` 와 함께 지웠을 수 있다) 지운다 — 그 케이스의 픽스처(`qg-worktree.sh create base`)는 ① 에서 사라진 하위명령이고, 같은 자리의 요구는 `case_R23_stale_tree_is_replaced` 가 반대 방향(남은 일회용 트리는 다시 만든다)으로 잰다:

```bash
python3 "$SCR/drop_cases.py" plugins/quality-gates/tests/test_runtime_contract_invariance.sh case_create_baseline_refuses_colliding_user_worktree
```


- [ ] **Step 5: 테스트 통과**

Run: `bash plugins/quality-gates/tests/test_differential_trees.sh 2>&1 | tail -1 && bash plugins/quality-gates/tests/test_runtime_contract_invariance.sh 2>&1 | tail -1 && bash plugins/quality-gates/tests/test_topic_head.sh 2>&1 | tail -1`
Expected: 첫 줄 `Total: 17 | Pass: 17 | Fail: 0`. 뒤 둘은 Task 0 기준과 같은 실패 줄 수다(새 실패 없음).

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/qg-worktree.sh plugins/quality-gates/tests/test_differential_trees.sh plugins/quality-gates/tests/test_runtime_contract_invariance.sh
git commit -m "feat(quality-gates): qg-worktree memo-init/memo-drop and self-healing disposable trees"
```

- [ ] **Step 7: 변이로 이빨을 확인한다**

Run: `python3 "$SCR/r-mutations.py" "$PWD" R6 R6b R12 R23`
Expected: 모두 `RED`, `tree restored`.

---

### Task 5: `compute-test-scope-candidates.sh` 얇게 다시 쓰기

**Files:**
- Modify(전문 교체): `plugins/quality-gates/scripts/compute-test-scope-candidates.sh`
- Modify(전문 교체): `plugins/quality-gates/tests/test_compute_test_scope_candidates.sh`
- Modify: `plugins/quality-gates/tests/test_guards_declaration_mapping.sh`(픽스처 기본 브랜치 이름 고정)

**Interfaces:**
- Consumes: `resolve-baseline.sh`(같은 디렉토리 — 기준선의 유일 소유자).
- Produces: `compute-test-scope-candidates.sh` (작업트리) · `--topic <boundary> <tree>` · `--emit-guards` · `--total [--tree <tree>]`. 출력은 리포 상대 경로 한 줄에 하나 · 정렬 · 중복 없음. exit 0 / 1(git 리포 아님) / 4(범위나 분모를 확정하지 못함).

- [ ] **Step 1: 테스트를 쓴다**

`plugins/quality-gates/tests/test_compute_test_scope_candidates.sh` 를 아래 전문으로 바꾼다:

````bash
#!/usr/bin/env bash
# test_compute_test_scope_candidates.sh — 후보의 바닥(이름 일치 · 바뀐 테스트 · `# guards:`)과 분모.
# 요구: R17 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts"
SUT="$SCRIPTS/compute-test-scope-candidates.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=""
mkrepo() {   # main 에 기준 커밋, feature 브랜치로 체크아웃
  R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
  git init -q -b main "$R" || exit 1
  git -C "$R" config user.email t@t; git -C "$R" config user.name t; git -C "$R" config commit.gpgsign false
  mkdir -p "$R/src" "$R/tests" "$R/web" "$R/lib/tests" "$R/cmd"
  echo 'x=1' > "$R/src/foo.py"; echo x > "$R/tests/test_foo.py"; echo x > "$R/web/bar.ts"; echo x > "$R/web/bar.test.ts"
  echo x > "$R/cmd/plain.go"
  { printf '#!/bin/bash\n'; printf '# %s: src/**\n' guards; printf 'exit 0\n'; } > "$R/lib/tests/test_lock.sh"
  ( cd "$R" && git add -A && git commit -qm base && git checkout -q -b feature ) || exit 1
}
rmrepo() { cd / && rm -rf "$R"; }
cands() { ( cd "$R" && bash "$SUT" "$@" ) 2>/dev/null; }

case_name_mapping_and_changed_tests() {
  mkrepo
  ( cd "$R" && echo 'x=2' > src/foo.py && git commit -qam c1 && echo y > web/bar.ts && echo n > tests/test_new.py )
  local out; out=$(cands | tr '\n' ' ')
  assert_contains "$out" "tests/test_foo.py" "커밋된 소스 변경 → 이름이 맞는 테스트"
  assert_contains "$out" "web/bar.test.ts" "미커밋 소스 변경 → 이름이 맞는 테스트"
  assert_contains "$out" "tests/test_new.py" "untracked 새 테스트도 후보"
  assert_contains "$out" "lib/tests/test_lock.sh" "guards 글롭이 바뀐 파일에 걸린 락"
  rmrepo
}
case_no_change_is_empty() {
  mkrepo
  local out rc; out=$(cands); rc=$?
  assert_eq "$rc:$out" "0:" "변경 없음 → 빈 출력 + exit 0"
  rmrepo
}
case_unsupported_language_has_no_mapping() {
  mkrepo; ( cd "$R" && echo y > cmd/plain.go )
  assert_eq "$(cands)" "" "이름 규칙이 없는 언어는 매핑하지 않는다"
  rmrepo
}
# R17 — 범위를 확정하지 못한 것은 「후보 없음」이 아니다: 기준선 미확정 · git 실패는 exit 4.
case_R17_unresolved_baseline_is_exit_4() {
  R=$(mktemp -d); git init -q -b weird "$R"; git -C "$R" config user.email t@t; git -C "$R" config user.name t
  ( cd "$R" && echo a > a && git add a && git commit -qm a && git checkout -q -b other && git branch -qD weird )
  local out rc; out=$(cands); rc=$?
  assert_eq "$rc" "4" "R17: 기준선을 못 풀면 exit 4"
  assert_eq "$out" "" "R17: stdout 은 비어 있다"
  rmrepo
}
case_R17_git_failure_is_exit_4() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py )
  printf 'garbage' > "$R/.git/index"
  local rc; cands >/dev/null; rc=$?
  assert_eq "$rc" "4" "R17: 인덱스가 깨져 git 이 실패하면 exit 4"
  rmrepo
}
case_R17_bad_topic_args_are_exit_4() {
  mkrepo
  cands --topic nope HEAD >/dev/null; assert_eq "$?" "4" "R17: 풀 수 없는 경계 → exit 4"
  cands --topic main >/dev/null; assert_eq "$?" "4" "R17: --topic 인자 모양 위반 → exit 4"
  cands --total --tree >/dev/null; assert_eq "$?" "4" "R17: --total 인자 모양 위반 → exit 4"
  rmrepo
}
case_topic_mode_reads_the_tree() {
  mkrepo
  ( cd "$R" && echo 'x=2' > src/foo.py && git commit -qam c1 )
  local tree; tree=$(git -C "$R" rev-parse 'HEAD^{tree}')
  git -C "$R" checkout -q main
  local out; out=$(cands --topic main "$tree" | tr '\n' ' ')
  assert_contains "$out" "tests/test_foo.py" "토픽: 경계..트리 변경의 이름 일치"
  assert_contains "$out" "lib/tests/test_lock.sh" "토픽: 트리 안 락의 guards 를 읽는다"
  rmrepo
}
# 분모는 후보를 포함한다(후보 ⊂ 분모). 비율을 부풀릴 수 없게 분모를 이 스크립트가 센다.
case_total_contains_every_candidate() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py && echo n > tests/test_new.py )
  local n m; n=$(cands | grep -c .); m=$(cands --total)
  [ "$m" -ge "$n" ] && [ "$n" -ge 1 ] && ok "분모 $m ≥ 후보 $n" || no "분모 $m < 후보 $n"
  local tree; tree=$(git -C "$R" rev-parse 'HEAD^{tree}')
  assert_eq "$(cands --total --tree "$tree")" "3" "--total --tree 는 그 트리(커밋된 것)의 테스트 수"
  rmrepo
}
case_emit_guards_only_lists_guards() {
  mkrepo; ( cd "$R" && echo 'x=2' > src/foo.py )
  assert_eq "$(cands --emit-guards)" "lib/tests/test_lock.sh" "--emit-guards 는 guards 후보만"
  rmrepo
}

for c in case_name_mapping_and_changed_tests case_no_change_is_empty case_unsupported_language_has_no_mapping \
         case_R17_unresolved_baseline_is_exit_4 case_R17_git_failure_is_exit_4 case_R17_bad_topic_args_are_exit_4 \
         case_topic_mode_reads_the_tree case_total_contains_every_candidate case_emit_guards_only_lists_guards; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 2: 실패를 확인한다**

Run: `bash plugins/quality-gates/tests/test_compute_test_scope_candidates.sh 2>&1 | tail -1`
Expected: FAIL — 옛 스크립트는 `--topic` 이 없고, 미커밋 변경이 있으면 커밋된 브랜치 변경을 빠뜨리며, untracked 를 보지 않고, 기준선 미확정에서 exit 0 이다.

- [ ] **Step 3: 스크립트를 새 전문으로 바꾼다**

````bash
#!/usr/bin/env bash
# compute-test-scope-candidates.sh — 차등 테스트 후보의 바닥(R17). 오케스트레이터는 여기에 더하기만 한다.
#
#   compute-test-scope-candidates.sh                          변경 = 기준선(merge_base) 대비 작업트리 + 무시되지 않는 untracked
#   compute-test-scope-candidates.sh --topic <boundary> <tree>  변경 = <boundary>..<tree> (토픽 스코프)
#   compute-test-scope-candidates.sh --emit-guards            `# guards:` 선언이 변경에 걸린 테스트만
#   compute-test-scope-candidates.sh --total [--tree <tree>]  테스트 파일 수 (계획 줄의 분모)
#
# 후보 = 바뀐 테스트 파일 ∪ 바뀐 소스와 이름이 맞는 테스트(test_<b>.py · <b>_test.py · <b>.test|spec.[jt]sx?)
#        ∪ 머리 30줄의 `# guards: <글롭>...` 이 바뀐 파일에 걸리는 tests/ 아래 .sh.
# 출력: 리포 상대 경로 한 줄에 하나, 정렬·중복 제거. 빈 출력은 「후보가 없다」이다.
# Exit: 0 = 성공 · 1 = git 리포 아님 · 4 = 범위나 분모를 확정하지 못했다(빈 결과가 아니다 — R17).
set -u

die4() { echo "compute-test-scope-candidates: $*" >&2; exit 4; }

git rev-parse --git-dir >/dev/null 2>&1 || { echo "compute-test-scope-candidates: not a git repository" >&2; exit 1; }
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
TESTRE='(test|spec)\.[jt]sx?$|_test\.py$|(^|/)test_[^/]*\.py$|\.test\.|\.spec\.|(^|/)tests?/'
GIT=(git -c core.quotePath=false)

if [ "${1:-}" = "--total" ]; then
  if [ "$#" -eq 1 ]; then
    # 분자(후보)가 untracked 를 포함하므로 분모도 포함한다 — 후보 ⊂ 분모.
    names=$("${GIT[@]}" ls-files) || die4 "ls-files 실패 — 분모를 셀 수 없다"
    others=$("${GIT[@]}" ls-files --others --exclude-standard) || die4 "ls-files --others 실패 — 분모를 셀 수 없다"
    names=$(printf '%s\n%s\n' "$names" "$others" | sed '/^$/d' | sort -u)
  elif [ "$#" -eq 3 ] && [ "$2" = "--tree" ] && [ -n "$3" ]; then
    "${GIT[@]}" rev-parse --verify --quiet "$3^{tree}" >/dev/null 2>&1 || die4 "--tree 값을 트리로 풀 수 없다('$3')"
    names=$("${GIT[@]}" ls-tree -r --full-tree --name-only "$3") || die4 "ls-tree 실패 (--tree $3) — 분모를 셀 수 없다"
  else
    die4 "인자 모양이 '--total' 또는 '--total --tree <tree>' 가 아니다(받은 것: $*)"
  fi
  printf '%s\n' "$names" | grep -cE "$TESTRE" || true
  exit 0
fi

mode=worktree; emit_guards=0
case "${1:-}" in
  "") ;;
  --emit-guards) [ "$#" -eq 1 ] || die4 "--emit-guards 는 인자를 받지 않는다"; emit_guards=1 ;;
  --topic)
    [ "$#" -eq 3 ] || die4 "usage: --topic <boundary> <tree>"
    mode=topic; boundary=$2; tree=$3
    "${GIT[@]}" rev-parse --verify --quiet "$boundary^{commit}" >/dev/null 2>&1 || die4 "경계를 커밋으로 풀 수 없다('$boundary')"
    "${GIT[@]}" rev-parse --verify --quiet "$tree^{tree}" >/dev/null 2>&1 || die4 "트리로 풀 수 없다('$tree')"
    ;;
  *) die4 "알 수 없는 인자: $1" ;;
esac

if [ "$mode" = worktree ]; then
  rb=$("$SCRIPT_DIR/resolve-baseline.sh" 2>/dev/null) || die4 "resolve-baseline.sh 를 실행하지 못했다"
  degraded=$(printf '%s\n' "$rb" | awk '$1 == "degraded:" { print $2 }')
  mb=$(printf '%s\n' "$rb" | awk '$1 == "merge_base:" { print $2 }')
  [ "$degraded" = no ] && [ -n "$mb" ] && [ "$mb" != "-" ] \
    || die4 "기준선 미확정(degraded='${degraded:-?}' merge_base='${mb:-?}') — 범위를 확정하지 못했다"
  changed=$("${GIT[@]}" diff --name-only "$mb") || die4 "git diff 실패 ($mb..작업트리)"
  untracked=$("${GIT[@]}" ls-files --others --exclude-standard) || die4 "ls-files --others 실패"
  tracked=$("${GIT[@]}" ls-files) || die4 "ls-files 실패"
  changed=$(printf '%s\n%s\n' "$changed" "$untracked")
  universe=$(printf '%s\n%s\n' "$tracked" "$untracked")
  read_head() { head -30 -- "$1" 2>/dev/null; }
else
  changed=$("${GIT[@]}" diff --name-only "$boundary" "$tree") || die4 "git diff 실패 ($boundary..$tree)"
  universe=$("${GIT[@]}" ls-tree -r --full-tree --name-only "$tree") || die4 "ls-tree 실패 ($tree)"
  read_head() { "${GIT[@]}" show "$tree:$1" 2>/dev/null | head -30; }
fi
changed=$(printf '%s\n' "$changed" | sed '/^$/d' | sort -u)
universe=$(printf '%s\n' "$universe" | sed '/^$/d' | sort -u)

# 이름 일치 — 바뀐 소스의 이름으로 찾을 테스트 파일 이름 목록을 만들고 universe 를 한 번 훑는다.
wanted=$(printf '%s\n' "$changed" | grep -vE "$TESTRE" | awk '
  { n = split($0, p, "/"); f = p[n] }
  f ~ /\.py$/ { b = f; sub(/\.py$/, "", b); print "test_" b ".py"; print b "_test.py"; next }
  f ~ /\.(ts|tsx|js|jsx)$/ { b = f; sub(/\.[^.]*$/, "", b)
    split("test spec", k, " "); split("ts tsx js jsx", e, " ")
    for (i = 1; i <= 2; i++) for (j = 1; j <= 4; j++) print b "." k[i] "." e[j] }')
mapped=""
if [ -n "$wanted" ]; then
  mapped=$(printf '%s\n' "$universe" | awk 'NR == FNR { w[$0] = 1; next } { n = split($0, p, "/"); if (p[n] in w) print }' \
    <(printf '%s\n' "$wanted") -)
fi
changed_tests=$(printf '%s\n' "$changed" | grep -E "$TESTRE" || true)

# `# guards:` — 확장자와 무관하게 선언 글롭이 바뀐 파일에 걸리면 그 락을 후보에 넣는다.
guarded=""
while IFS= read -r tf; do
  [ -z "$tf" ] && continue
  decl=$(read_head "$tf" | sed -n 's/^[[:space:]]*#[[:space:]]*guards:[[:space:]]*//p' | sed 's/[[:space:]]*$//' | head -1)
  [ -z "$decl" ] && continue
  read -r -a globs <<< "$decl"
  hit=0
  for g in "${globs[@]}"; do
    while IFS= read -r ch; do
      [ -z "$ch" ] && continue
      # shellcheck disable=SC2254
      case "$ch" in $g) hit=1; break 2 ;; esac
    done <<< "$changed"
  done
  [ "$hit" -eq 1 ] && guarded="$guarded$tf"$'\n'
done < <(printf '%s\n' "$universe" | grep -E '\.sh$' | grep -E '(^|/)tests?/' || true)

if [ "$emit_guards" -eq 1 ]; then
  printf '%s' "$guarded" | sed '/^[[:space:]]*$/d' | sort -u
  exit 0
fi
printf '%s\n%s\n%s\n' "$mapped" "$changed_tests" "$guarded" | sed '/^[[:space:]]*$/d' | sort -u
exit 0
````

- [ ] **Step 4: guards 매핑 테스트의 픽스처를 고정한다**

새 스크립트는 기본 모드에서 `resolve-baseline.sh` 로 기준선을 풀므로, 픽스처 리포의 기본 브랜치 이름이 머신 설정(`init.defaultBranch`)에 따라 달라지면 안 된다. `test_guards_declaration_mapping.sh` 의 `git init -q && git config user.email t@t` 두 곳(`mk_repo` · `mk_repo_tab`)을 `git init -q -b main && git config user.email t@t` 로 바꾼다:

```bash
python3 - <<'PY'
from pathlib import Path
p = Path("plugins/quality-gates/tests/test_guards_declaration_mapping.sh")
s = p.read_text(encoding="utf-8")
old = "git init -q && git config user.email t@t"
assert s.count(old) == 2, s.count(old)
p.write_text(s.replace(old, "git init -q -b main && git config user.email t@t"), encoding="utf-8")
PY
```

- [ ] **Step 5: 테스트 통과 · 소비자 확인**

Run: `bash -n plugins/quality-gates/scripts/compute-test-scope-candidates.sh && for t in test_compute_test_scope_candidates.sh test_guards_declaration_mapping.sh test_resolve_baseline.sh test_guards_coverage_bidirectional.sh; do printf '%s: ' $t; bash plugins/quality-gates/tests/$t 2>&1 | tail -1; done`
Expected: `test_compute_test_scope_candidates.sh: Total: 17 | Pass: 17 | Fail: 0`, 나머지 셋은 `Fail: 0`.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/compute-test-scope-candidates.sh plugins/quality-gates/tests/test_compute_test_scope_candidates.sh plugins/quality-gates/tests/test_guards_declaration_mapping.sh
git commit -m "refactor(quality-gates): test-scope candidates — floor from merge_base incl. untracked, --topic, exit 4 on unresolved range"
```

- [ ] **Step 7: 변이로 이빨을 확인한다**

Run: `python3 "$SCR/r-mutations.py" "$PWD" R17b`
Expected: `R17b	RED`, `tree restored`.

---

### Task 6: `diff-test-results.py` 다시 쓰기 — 짝짓기 · 집계 · 판정 입력 한 파일

**Files:**
- Modify(전문 교체): `plugins/quality-gates/scripts/diff-test-results.py`
- Modify(전문 교체): `plugins/quality-gates/tests/test_diff_test_results.py`
- Delete: `plugins/quality-gates/tests/test_resolution_disclosure.sh`

**Interfaces:**
- Consumes: Task 2 의 배정 파일 · Task 3 의 행 파일(`<memo>/baseline-<runner>.tsv` · `<memo>/head-<runner>-i<N>.tsv`) · `run-test-selection.sh granularity`.
- Produces: `diff-test-results.py --assign <file> --rows <memo> --iter <N> --baseline-commit <sha|-> --head-commit <sha|->` — 리포 루트에서 부른다. stdout 은 `adapters:` · `verdict_input:`(세 플래그) · `attribution_status:` · `degrade_causes: [..]`(파일에 정확히 한 번) · `new_failures: <K>` · `unclaimed: [..]` · (있으면) `resolution_disclosure:` · `per_adapter:` 목록. exit 0 / 2(사용 오류) / 4(계약 위반). `verdict.py --differential` 이 이 파일을 그대로 읽는다(`degrade_causes:` · `  confirmed_product_defect:` 줄의 모양은 9.3.6 과 같다).

- [ ] **Step 1: 테스트를 쓴다**

`plugins/quality-gates/tests/test_diff_test_results.py` 를 아래 전문으로 바꾼다:

````python
#!/usr/bin/env python3
"""diff-test-results.py — 짝짓기 · 귀속 · 집계와 verdict.py 로 가는 출력 계약.

요구: R1 · R2 · R5 · R7 · R8 · R9 · R10 · R12 · R13 · R15 · R16 · R17 · R19 · R24
(docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
"""
from __future__ import annotations

import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
DIFF = SCRIPTS / "diff-test-results.py"
VERDICT = SCRIPTS / "verdict.py"
RTS = SCRIPTS / "run-test-selection.sh"


def git(cwd, *args):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, check=True).stdout.strip()


class Repo:
    """기준선 커밋 B · 다른 트리의 HEAD 커밋 H · B 와 같은 트리의 커밋 SAME 을 가진 임시 리포."""

    def __init__(self):
        self.root = Path(tempfile.mkdtemp(prefix="qg-diff-"))
        git(self.root, "init", "-q", "-b", "main")
        for k, v in (("user.email", "t@t"), ("user.name", "t"), ("commit.gpgsign", "false")):
            git(self.root, "config", k, v)
        (self.root / "a").write_text("1\n", encoding="utf-8")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-qm", "base")
        self.B = git(self.root, "rev-parse", "HEAD")
        (self.root / "a").write_text("2\n", encoding="utf-8")
        git(self.root, "commit", "-qam", "head")
        self.H = git(self.root, "rev-parse", "HEAD")
        tree = git(self.root, "rev-parse", f"{self.B}^{{tree}}")
        self.SAME = git(self.root, "commit-tree", tree, "-p", self.H, "-m", "same")

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)


def write_assign(memo: Path, rows, adapters="shell", name="assign-i1.tsv"):
    body = "".join(f"{u}\t{r}\t{g}\n" for u, r, g in rows)
    (memo / name).write_text(body + f"#qg-assign\tadapters={adapters}\trows={len(rows)}\n", encoding="utf-8")
    return memo / name


def write_rows(path: Path, runner, commit, rows, flaky=0):
    body = "".join(f"{u}\t{s}\t{c}\t{m}\n" for u, s, c, m in rows)
    path.write_text(body + f"#qg-rows\trunner={runner}\tcommit={commit}\trows={len(rows)}\tflaky={flaky}\n",
                    encoding="utf-8")


class DiffBase(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.repo = Repo()

    @classmethod
    def tearDownClass(cls):
        cls.repo.close()

    def setUp(self):
        self.memo = Path(tempfile.mkdtemp(prefix="qg-memo-"))
        self.addCleanup(shutil.rmtree, self.memo, ignore_errors=True)

    def run_diff(self, base=None, head=None, it=1, extra=()):
        argv = [sys.executable, str(DIFF), "--assign", str(self.memo / "assign-i1.tsv"),
                "--rows", str(self.memo), "--iter", str(it),
                "--baseline-commit", base or self.repo.B, "--head-commit", head or self.repo.H, *extra]
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        return subprocess.run(argv, cwd=self.repo.root, capture_output=True, text=True, env=env)

    def pair(self, runner, base_rows, head_rows, gran="file", it=1, flaky=0):
        write_assign(self.memo, [(u, runner, gran) for u, *_ in base_rows], adapters=runner)
        write_rows(self.memo / f"baseline-{runner}.tsv", runner, self.repo.B, base_rows)
        write_rows(self.memo / f"head-{runner}-i{it}.tsv", runner, self.repo.H, head_rows, flaky=flaky)

    @staticmethod
    def field(out, key):
        for line in out.splitlines():
            if line.startswith(key + ": "):
                return line.split(": ", 1)[1]
        return None

    @staticmethod
    def verdict_of(out, unit):
        lines = out.splitlines()
        for i, line in enumerate(lines):
            if line.strip() == f'- unit: "{unit}"':
                return lines[i + 1].split(": ", 1)[1]
        return None


class Attribution(DiffBase):
    def test_R2_pass_then_error_is_new_regression(self):
        self.pair("shell", [("t.sh", "pass", "0", "per-unit")], [("t.sh", "error", "2", "per-unit")])
        p = self.run_diff()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.verdict_of(p.stdout, "t.sh"), "NEW_REGRESSION")
        self.assertIn("confirmed_product_defect: true", p.stdout)

    def test_R2_error_on_either_axis_blocks_certification(self):
        self.pair("shell", [("t.sh", "error", "2", "per-unit")], [("t.sh", "error", "2", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.field(p.stdout, "attribution_status"), "degraded")
        self.assertIn("error-axis", self.field(p.stdout, "degrade_causes"))

    def test_R3_baseline_unrun_is_baseline_unrunnable(self):
        self.pair("shell", [("t.sh", "unrun", "-", "skip")], [("t.sh", "fail", "1", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.verdict_of(p.stdout, "t.sh"), "BASELINE_UNRUNNABLE")
        self.assertIn("baseline-unrunnable", self.field(p.stdout, "degrade_causes"))
        self.assertIn("confirmed_product_defect: false", p.stdout)

    def test_R7_missing_row_is_silent_drop(self):
        write_assign(self.memo, [("t.sh", "shell", "file"), ("u.sh", "shell", "file")])
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.B,
                   [("t.sh", "pass", "0", "per-unit"), ("u.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H, [("t.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.verdict_of(p.stdout, "u.sh"), "SILENT_DROP")
        self.assertIn("silent_drop: true", p.stdout)

    def test_R7_duplicate_row_is_exit_4(self):
        self.pair("shell", [("t.sh", "pass", "0", "per-unit")], [("t.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H,
                   [("t.sh", "pass", "0", "per-unit"), ("t.sh", "fail", "1", "per-unit")])
        self.assertEqual(self.run_diff().returncode, 4)

    def test_R7_deleted_test_is_silent_drop_not_clean(self):
        # 이번 변경이 지운 테스트 — 기준선 pass · HEAD absent 는 조용한 clean 이 아니다.
        self.pair("shell", [("old.sh", "pass", "0", "per-unit")], [("old.sh", "absent", "-", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.verdict_of(p.stdout, "old.sh"), "SILENT_DROP")
        self.assertIn("silent-drop", self.field(p.stdout, "degrade_causes"))

    def test_R8_memo_rows_outside_this_assign_are_ignored(self):
        # 앞 iteration 이 메모에 남긴 기준선 행은 이번 배정에 없는 unit 이면 판정에 들어가지 않는다.
        write_assign(self.memo, [("a.sh", "shell", "file")])
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.B,
                   [("a.sh", "pass", "0", "per-unit"), ("dropped.sh", "fail", "1", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H, [("a.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertNotIn("dropped.sh", p.stdout)
        self.assertEqual(self.field(p.stdout, "attribution_status"), "closed")

    def test_R8_expected_comes_from_assign_not_results(self):
        # 두 결과 파일이 같은 unit 을 대칭으로 빠뜨려도 배정 파일이 그 unit 을 기대한다.
        write_assign(self.memo, [("t.sh", "shell", "file"), ("gone.sh", "shell", "file")])
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.B, [("t.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H, [("t.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.verdict_of(p.stdout, "gone.sh"), "SILENT_DROP")
        self.assertEqual(self.field(p.stdout, "attribution_status"), "degraded")

    def test_R9_bulk_both_red_is_smeared_on_file_granularity(self):
        self.pair("shell", [("a.sh", "fail", "1", "bulk"), ("b.sh", "fail", "1", "bulk")],
                  [("a.sh", "fail", "1", "bulk"), ("b.sh", "fail", "1", "bulk")])
        p = self.run_diff()
        self.assertIn("smeared", self.field(p.stdout, "degrade_causes"))

    def test_R9_bulk_granularity_both_red_degrades(self):
        self.pair("cargo", [("BULK", "fail", "101", "bulk")], [("BULK", "fail", "101", "bulk")], gran="bulk")
        p = self.run_diff()
        self.assertIn("bulk-pre-existing", self.field(p.stdout, "degrade_causes"))

    def test_R9_granularity_is_derived_from_runner(self):
        # 배정 파일이 cargo 를 file 로 적어도 입도는 러너에서 도출된다 — 어긋나면 계약 위반.
        self.pair("cargo", [("BULK", "fail", "101", "bulk")], [("BULK", "fail", "101", "bulk")], gran="file")
        self.assertEqual(self.run_diff().returncode, 4)

    def test_R10_per_unit_both_red_is_disclosed_not_blocked(self):
        self.pair("shell", [("a.sh", "fail", "1", "per-unit")], [("a.sh", "fail", "1", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.field(p.stdout, "attribution_status"), "closed")
        self.assertIn("양측 빨강 unit 1개", self.field(p.stdout, "resolution_disclosure") or "")

    def test_R12_R13_same_tree_axes_are_not_comparable(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.SAME, [("a.sh", "pass", "0", "per-unit")])
        p = self.run_diff(head=self.repo.SAME)
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.verdict_of(p.stdout, "a.sh"), "BASELINE_UNRUNNABLE")
        self.assertIn("baseline-unrunnable", self.field(p.stdout, "degrade_causes"))

    def test_R12_R13_positive_control_different_trees_compare(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.verdict_of(p.stdout, "a.sh"), "STILL_GREEN")
        self.assertEqual(self.field(p.stdout, "attribution_status"), "closed")

    def test_R15_flaky_only_on_baseline_pass(self):
        self.pair("shell", [("a.sh", "fail", "1", "per-unit")], [("a.sh", "pass", "0", "flaky")], flaky=1)
        self.assertEqual(self.run_diff().returncode, 4)

    def test_R15_flaky_pass_is_noted_and_green(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "flaky")], flaky=1)
        p = self.run_diff()
        self.assertEqual(self.verdict_of(p.stdout, "a.sh"), "STILL_GREEN")
        self.assertIn("flaky 재실행 1회", p.stdout)


class Contract(DiffBase):
    def test_R1_zero_units_is_scope_empty(self):
        write_assign(self.memo, [], adapters="shell")
        p = self.run_diff()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertIn("expected-empty", self.field(p.stdout, "degrade_causes"))
        v = self.verdict(p.stdout)
        self.assertIn("reason: scope-empty", v)

    def test_R1_zero_adapters_is_scope_empty(self):
        write_assign(self.memo, [], adapters="-")
        p = self.run_diff()
        self.assertIn("no-adapters", self.field(p.stdout, "degrade_causes"))
        self.assertIn("reason: scope-empty", self.verdict(p.stdout))

    def test_R5_rows_from_another_commit_are_refused(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.H, [("a.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(p.returncode, 4)
        self.assertIn("커밋", p.stderr)

    def test_R16_unclaimed_unit_blocks_certification(self):
        write_assign(self.memo, [("a.sh", "shell", "file"), ("x.rb", "unclaimed", "file")])
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.B, [("a.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H, [("a.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertIn("silent-drop", self.field(p.stdout, "degrade_causes"))
        self.assertIn('"x.rb"', self.field(p.stdout, "unclaimed"))
        self.assertIn("reason: silent-drop", self.verdict(p.stdout))

    def test_R17_truncated_assign_is_exit_4(self):
        write_assign(self.memo, [("a.sh", "shell", "file")])
        text = (self.memo / "assign-i1.tsv").read_text(encoding="utf-8").splitlines()[:-1]
        (self.memo / "assign-i1.tsv").write_text("\n".join(text) + "\n", encoding="utf-8")
        self.assertEqual(self.run_diff().returncode, 4)

    def test_R17_missing_assign_is_exit_4(self):
        self.assertEqual(self.run_diff().returncode, 4)

    def test_R17_row_count_mismatch_is_exit_4(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        p = self.memo / "head-shell-i1.tsv"
        p.write_text(p.read_text(encoding="utf-8").replace("rows=1", "rows=2"), encoding="utf-8")
        self.assertEqual(self.run_diff().returncode, 4)

    def test_R19_missing_rows_file_for_an_assigned_runner_is_exit_4(self):
        write_assign(self.memo, [("a.sh", "shell", "file"), ("t_test.py", "pytest", "file")], adapters="shell,pytest")
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.B, [("a.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H, [("a.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(p.returncode, 4)
        self.assertIn("pytest", p.stderr)

    def test_R19_head_file_of_another_iteration_is_not_read(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        self.assertEqual(self.run_diff(it=2).returncode, 4)

    def test_usage_rejects_short_sha(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        self.assertEqual(self.run_diff(base="abc123").returncode, 2)

    def verdict(self, text):
        f = self.memo / "diff.yaml"
        f.write_text(text, encoding="utf-8")
        p = subprocess.run([sys.executable, str(VERDICT), "--differential", str(f)], capture_output=True, text=True)
        self.assertEqual(p.returncode, 0, p.stderr)
        return p.stdout


class ProducerToVerdict(unittest.TestCase):
    """R24 — 판정은 기계 출력을 직접 읽는다: 진짜 run → diff → verdict.py 를 전사 없이 잇는다."""

    def setUp(self):
        self.root = Path(tempfile.mkdtemp(prefix="qg-e2e-"))
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        r = self.root / "repo"
        git(self.root, "init", "-q", "-b", "main", str(r))
        for k, v in (("user.email", "t@t"), ("user.name", "t"), ("commit.gpgsign", "false")):
            git(r, "config", k, v)
        (r / "tests").mkdir()
        for name in ("a.sh", "b.sh"):
            (r / "tests" / name).write_text("#!/bin/bash\nexit 0\n", encoding="utf-8")
            os.chmod(r / "tests" / name, 0o755)
        git(r, "add", "-A"); git(r, "commit", "-qm", "base")
        self.B = git(r, "rev-parse", "HEAD")
        (r / "tests" / "a.sh").write_text("#!/bin/bash\nexit 1\n", encoding="utf-8")
        git(r, "commit", "-qam", "head")
        self.H = git(r, "rev-parse", "HEAD")
        git(r, "worktree", "add", "-q", "--detach", str(self.root / "bw"), self.B)
        git(r, "worktree", "add", "-q", "--detach", str(self.root / "hw"), self.H)
        self.repo = r
        self.memo = self.root / "memo"
        self.memo.mkdir()

    def sh(self, *args, stdin=None):
        return subprocess.run(["bash", str(RTS), *args], input=stdin, capture_output=True, text=True)

    def test_R24_real_producer_output_reaches_verdict_without_transcription(self):
        self.sh("assign", str(self.root / "hw"), str(self.memo / "assign-i1.tsv"), stdin="tests/a.sh\ntests/b.sh\n")
        for tree, f in (("bw", "baseline-shell.tsv"), ("hw", "head-shell-i1.tsv")):
            self.sh("run", str(self.root / tree), "shell", "bulk", str(self.memo / f), "tests/a.sh", "tests/b.sh")
            self.sh("run", str(self.root / tree), "shell", "per-unit", str(self.memo / f), "tests/a.sh", "tests/b.sh")
        d = subprocess.run([sys.executable, str(DIFF), "--assign", str(self.memo / "assign-i1.tsv"),
                            "--rows", str(self.memo), "--iter", "1",
                            "--baseline-commit", self.B, "--head-commit", self.H],
                           cwd=self.repo, capture_output=True, text=True)
        self.assertEqual(d.returncode, 0, d.stderr)
        (self.memo / "diff-i1.yaml").write_text(d.stdout, encoding="utf-8")
        v = subprocess.run([sys.executable, str(VERDICT), "--differential", str(self.memo / "diff-i1.yaml")],
                           capture_output=True, text=True)
        self.assertEqual(v.returncode, 0, v.stderr)
        self.assertEqual(v.stdout.splitlines()[0], "verdict: defect")
        self.assertIn("new_failures: 1", d.stdout)

    def test_R24_truncated_output_cannot_reach_clean(self):
        # 잘린 출력은 verdict.py 가 판정하지 않는다 — clean 으로 새는 길이 없다.
        (self.memo / "cut.yaml").write_text("adapters: [shell]\nverdict_input:\n", encoding="utf-8")
        v = subprocess.run([sys.executable, str(VERDICT), "--differential", str(self.memo / "cut.yaml")],
                           capture_output=True, text=True)
        self.assertEqual(v.returncode, 4)


if __name__ == "__main__":
    unittest.main()
````

- [ ] **Step 2: 실패를 확인한다**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_diff_test_results.py 2>&1 | tail -3`
Expected: FAIL — 옛 CLI 는 `--assign`/`--rows`/`--iter` 를 모른다(argparse exit 2 가 대부분의 케이스를 깨뜨린다).

- [ ] **Step 3: 스크립트를 새 전문으로 바꾼다**

````python
#!/usr/bin/env python3
"""diff-test-results.py — 기준선 × HEAD 행을 짝지어 귀속하고 판정 입력 하나로 모은다.

    diff-test-results.py --assign <배정 파일> --rows <메모 디렉토리> --iter <N>
                         --baseline-commit <sha|-> --head-commit <sha|->

읽는 것 (전부 run-test-selection.sh 가 쓴 파일이다):
    <배정 파일>                         기대 unit 의 유일한 출처(R8)
    <메모>/baseline-<runner>.tsv        기준선 축 행 — 같은 실행의 iteration 사이에 재사용된다
    <메모>/head-<runner>-i<N>.tsv       이번 iteration 의 HEAD 축 행

출력은 verdict.py --differential 이 그대로 읽는다(R24). 종료: 0 정상 · 2 사용 오류 · 4 계약 위반.
표준 라이브러리만 쓴다.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from typing import NoReturn

STATUSES = {"pass", "fail", "error", "unrun", "absent"}
MODES = {"bulk", "per-unit", "flaky", "skip"}

# error 는 fail 축으로 접는다 — 비대칭 (pass, error) 는 확증 회귀다(R2). 대칭 error 는 아래에서
# 인증을 막는다.
AXIS = {"pass": "P", "fail": "F", "error": "F", "absent": "A", "unrun": "U"}
ATTR = {
    ("P", "P"): "STILL_GREEN",         ("P", "F"): "NEW_REGRESSION",
    ("P", "A"): "SILENT_DROP",         ("P", "U"): "SILENT_DROP",
    ("F", "P"): "FIXED",               ("F", "F"): "PRE_EXISTING",
    ("F", "A"): "SILENT_DROP",         ("F", "U"): "SILENT_DROP",
    ("A", "P"): "NEW_TEST_GREEN",      ("A", "F"): "NEW_TEST_RED",
    ("A", "A"): "SILENT_DROP",         ("A", "U"): "SILENT_DROP",
    ("U", "P"): "BASELINE_UNRUNNABLE", ("U", "F"): "BASELINE_UNRUNNABLE",
    ("U", "A"): "BASELINE_UNRUNNABLE", ("U", "U"): "BASELINE_UNRUNNABLE",
}
CATEGORIES = [
    "STILL_GREEN", "NEW_REGRESSION", "PRE_EXISTING", "FIXED",
    "NEW_TEST_GREEN", "NEW_TEST_RED", "SILENT_DROP", "BASELINE_UNRUNNABLE",
]
DEFECTS = {"NEW_REGRESSION", "NEW_TEST_RED"}
# verdict.py 의 CAUSE_TO_REASON 키와 같은 닫힌 열거다. 튜플 순서가 출력 정렬 키다.
DEGRADE_CAUSES = (
    "expected-empty", "baseline-unrunnable", "silent-drop",
    "error-axis", "bulk-pre-existing", "smeared", "no-adapters",
)
SHA = re.compile(r"[0-9a-f]{40}|[0-9a-f]{64}|-")


def fail4(msg: str) -> NoReturn:
    print(f"diff-test-results: {msg}", file=sys.stderr)
    raise SystemExit(4)


def read_text(path: Path, label: str) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        fail4(f"{label} 를 읽을 수 없다: {path} ({exc})")
    except UnicodeDecodeError as exc:
        fail4(f"{label} 가 UTF-8 이 아니다: {path} ({exc})")


def split_trailer(text: str, tag: str, path: Path) -> tuple[list[str], dict[str, str]]:
    """본문 줄들과 꼬리 줄의 키=값을 돌려준다. 꼬리 줄은 정확히 하나, 마지막 비어 있지 않은 줄이다."""
    lines = [ln for ln in text.splitlines() if ln.strip()]
    tails = [i for i, ln in enumerate(lines) if ln.startswith(tag + "\t")]
    if len(tails) != 1 or tails[0] != len(lines) - 1:
        fail4(f"{path}: 꼬리 줄 '{tag}' 가 정확히 하나의 마지막 줄이 아니다 — 생산자가 끝까지 쓰지 못했다")
    kv = {}
    for field in lines[-1].split("\t")[1:]:
        k, sep, v = field.partition("=")
        if not sep or k in kv:
            fail4(f"{path}: 꼬리 줄 필드를 읽을 수 없다: {field!r}")
        kv[k] = v
    body = lines[:-1]
    if kv.get("rows") != str(len(body)):
        fail4(f"{path}: 행 수 불일치 (꼬리 {kv.get('rows')!r} · 실제 {len(body)})")
    return body, kv


def read_assign(path: Path) -> tuple[list[tuple[str, str, str]], list[str]]:
    body, kv = split_trailer(read_text(path, "배정 파일"), "#qg-assign", path)
    adapters = [] if kv.get("adapters") in (None, "", "-") else kv["adapters"].split(",")
    rows, seen = [], set()
    for n, ln in enumerate(body, 1):
        parts = ln.split("\t")
        if len(parts) != 3:
            fail4(f"{path}:{n} 필드 수 {len(parts)} != 3")
        unit, runner, gran = parts
        if unit in seen:
            fail4(f"{path}:{n} 중복 unit '{unit}'")
        seen.add(unit)
        rows.append((unit, runner, gran))
    return rows, adapters


def read_rows(path: Path, runner: str, commit: str) -> dict[str, tuple[str, str, str]]:
    """행 파일 → {unit: (status, exit, mode)}. 다른 러너 · 다른 트리의 행 파일은 계약 위반이다(R5)."""
    if not path.is_file():
        fail4(f"행 파일이 없다: {path} — 그 축을 돌리지 않았으면 run-test-selection.sh unrun 으로 채워야 한다")
    body, kv = split_trailer(read_text(path, "행 파일"), "#qg-rows", path)
    if kv.get("runner") != runner:
        fail4(f"{path}: 러너 {kv.get('runner')!r} ≠ {runner!r}")
    if kv.get("commit") != commit:
        fail4(f"{path}: 행이 커밋 {kv.get('commit')!r} 에서 나왔다 — 이 축의 커밋은 {commit!r} 다")
    rows: dict[str, tuple[str, str, str]] = {}
    for n, ln in enumerate(body, 1):
        parts = ln.split("\t")
        if len(parts) != 4:
            fail4(f"{path}:{n} 필드 수 {len(parts)} != 4")
        unit, status, code, mode = parts
        if status not in STATUSES:
            fail4(f"{path}:{n} 알 수 없는 상태값 '{status}'")
        if mode not in MODES:
            fail4(f"{path}:{n} 알 수 없는 실행 방식 '{mode}'")
        if unit in rows:
            fail4(f"{path}:{n} 중복 unit 행 '{unit}'")
        rows[unit] = (status, code, mode)
    return rows


def granularity_of(runner: str) -> str:
    """입도는 러너에서 도출한다 — 어댑터 표의 소유자에게 묻는다(R9)."""
    owner = Path(__file__).resolve().parent / "run-test-selection.sh"
    try:
        proc = subprocess.run(["bash", str(owner), "granularity", runner],
                              capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError) as exc:
        fail4(f"입도 소유자를 부를 수 없다 ({owner}): {exc}")
    gran = proc.stdout.strip()
    if proc.returncode != 0 or gran not in ("file", "package", "bulk"):
        fail4(f"러너 '{runner}' 의 입도를 얻지 못했다 (exit {proc.returncode}): {proc.stderr.strip()}")
    return gran


def same_tree(base: str, head: str) -> bool:
    """두 축이 같은 바이트면 차등이 성립하지 않는다(R12 · R13)."""
    if base == "-" or head == "-":
        return False
    trees = []
    for sha in (base, head):
        proc = subprocess.run(["git", "rev-parse", "--verify", "--quiet", f"{sha}^{{tree}}"],
                              capture_output=True, text=True)
        if proc.returncode != 0:
            fail4(f"커밋 {sha} 의 트리를 읽지 못했다 — 리포 루트에서 불러라")
        trees.append(proc.stdout.strip())
    return trees[0] == trees[1]


def yaml_str(s: str) -> str:
    escaped = (s.replace("\\", "\\\\").replace('"', '\\"')
               .replace("\n", "\\n").replace("\r", "\\r").replace("\t", "\\t"))
    return '"' + escaped + '"'


def attribute(runner, gran, units, base, head, axes_equal):
    attributions, causes = [], []
    counts = {c.lower(): 0 for c in CATEGORIES}
    error_seen = smeared = False
    for unit in units:
        notes = []
        b, h = base.get(unit), head.get(unit)
        if b is None or h is None:
            verdict = "SILENT_DROP"   # 행이 없는 것은 계약 위반이다 — 부재를 추론으로 메우지 않는다(R7)
            notes.append("행 없음: " + ",".join(n for n, v in (("baseline", b), ("head", h)) if v is None))
        else:
            if h[2] == "flaky" and b[0] != "pass":
                fail4(f"{runner}: '{unit}' 의 flaky 재실행은 기준선 pass 인 unit 에만 허용된다(R15)")
            for side, row in (("baseline", b), ("head", h)):
                if row[0] == "error":
                    notes.append(f"{side}=(error)")
                    error_seen = True
            b_axis = "U" if axes_equal else AXIS[b[0]]
            if axes_equal:
                notes.append("기준선과 HEAD 의 트리가 같다 — 비교할 차이가 없다")
            verdict = ATTR[(b_axis, AXIS[h[0]])]
            if h[2] == "flaky":
                notes.append(f"flaky 재실행 1회 → {h[0]}")
            if (verdict == "PRE_EXISTING" and gran != "bulk"
                    and "bulk" in (b[2], h[2])):
                smeared = True   # 한 종료 코드가 여러 unit 에 찍힌 양측 red — 회귀를 가릴 수 있다(R9)
                notes.append("bulk 실행의 양측 red — unit 별로 판정되지 않았다")
        counts[verdict.lower()] += 1
        attributions.append((unit, verdict, "; ".join(notes)))
    if counts["baseline_unrunnable"]:
        causes.append("baseline-unrunnable")
    if counts["silent_drop"]:
        causes.append("silent-drop")
    if error_seen:
        causes.append("error-axis")
    if gran == "bulk" and counts["pre_existing"]:
        causes.append("bulk-pre-existing")
    if smeared:
        causes.append("smeared")
    return attributions, counts, causes


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--assign", required=True)
    ap.add_argument("--rows", required=True)
    ap.add_argument("--iter", required=True, type=int)
    ap.add_argument("--baseline-commit", required=True)
    ap.add_argument("--head-commit", required=True)
    args = ap.parse_args()
    for name in ("baseline_commit", "head_commit"):
        if not SHA.fullmatch(getattr(args, name)):
            print(f"diff-test-results: --{name.replace('_', '-')} 는 전체 sha 또는 '-' 다", file=sys.stderr)
            return 2

    assign, detected = read_assign(Path(args.assign))
    unclaimed = [u for u, r, _ in assign if r == "unclaimed"]
    by_runner: dict[str, list[tuple[str, str]]] = {}
    for unit, runner, gran in assign:
        if runner != "unclaimed":
            by_runner.setdefault(runner, []).append((unit, gran))
    axes_equal = same_tree(args.baseline_commit, args.head_commit)
    memo = Path(args.rows)

    causes: list[str] = []
    if not by_runner:
        causes.append("expected-empty")
    if not detected:
        causes.append("no-adapters")
    if unclaimed:
        causes.append("silent-drop")   # 고른 unit 을 어느 어댑터도 못 돌린다(R16)
    blocks, totals = [], {c.lower(): 0 for c in CATEGORIES}
    for runner in sorted(by_runner):
        gran = granularity_of(runner)
        units = [u for u, g in by_runner[runner]]
        if any(g != gran for _, g in by_runner[runner]):
            fail4(f"배정 파일의 입도가 러너 {runner} 의 입도 {gran} 와 다르다")
        base = read_rows(memo / f"baseline-{runner}.tsv", runner, args.baseline_commit)
        head = read_rows(memo / f"head-{runner}-i{args.iter}.tsv", runner, args.head_commit)
        attributions, counts, adapter_causes = attribute(runner, gran, units, base, head, axes_equal)
        for k, v in counts.items():
            totals[k] += v
        for c in adapter_causes:
            if c not in causes:
                causes.append(c)
        blocks.append((runner, gran, attributions, counts, adapter_causes))
    causes.sort(key=DEGRADE_CAUSES.index)

    defect = any(totals[d.lower()] for d in DEFECTS)
    out = [f"adapters: [{', '.join(r for r, *_ in blocks)}]",
           "verdict_input:",
           f"  confirmed_product_defect: {'true' if defect else 'false'}",
           f"  silent_drop: {'true' if totals['silent_drop'] or unclaimed else 'false'}",
           f"  baseline_unrunnable: {'true' if totals['baseline_unrunnable'] else 'false'}",
           f"attribution_status: {'degraded' if causes else 'closed'}",
           f"degrade_causes: [{', '.join(causes)}]",
           f"new_failures: {totals['new_regression'] + totals['new_test_red']}"]
    out.append("unclaimed: [" + ", ".join(yaml_str(u) for u in unclaimed) + "]")
    if totals["pre_existing"]:
        # 양측 red 는 막지 않고 공시한다 — 그 안의 새 실패는 이 해상도에서 보이지 않는다(R10).
        out.append("resolution_disclosure: " + yaml_str(
            f"양측 빨강 unit {totals['pre_existing']}개 — 그 안의 새 실패는 "
            "이 해상도(unit 당 종료 코드 하나)에서 보이지 않는다"))
    out.append("per_adapter:" if blocks else "per_adapter: []")
    for runner, gran, attributions, counts, adapter_causes in blocks:
        out.append(f"  - runner: {runner}")
        out.append(f"    granularity: {gran}")
        out.append(f"    causes: [{', '.join(adapter_causes)}]")
        out.append("    counts: {" + ", ".join(f"{c.lower()}: {counts[c.lower()]}" for c in CATEGORIES) + "}")
        out.append("    attributions:" if attributions else "    attributions: []")
        for unit, verdict, note in attributions:
            out.append(f"      - unit: {yaml_str(unit)}")
            out.append(f"        verdict: {verdict}")
            out.append(f"        note: {yaml_str(note)}")
    print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
````

- [ ] **Step 4: 옮긴 테스트 파일을 지운다**

`test_resolution_disclosure.sh` 는 옛 `--aggregate` CLI 를 쓰고, 그 요구(양측 red 는 막지 않고 공시 · bulk 가드는 그대로)는 `test_R10_per_unit_both_red_is_disclosed_not_blocked` · `test_R9_*` 로 옮겼다:

```bash
git rm -q plugins/quality-gates/tests/test_resolution_disclosure.sh
```

- [ ] **Step 5: 테스트 통과 · 어휘 대응 확인**

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_diff_test_results.py 2>&1 | tail -3; bash plugins/quality-gates/tests/test_verdict_vocabulary.sh 2>&1 | grep -E 'bijective|UNMAPPED|ORPHAN|CAUSE_TO_REASON|Total'`
Expected: `Ran 28 tests … OK`. `test_verdict_vocabulary.sh` 의 `case_degrade_causes_and_cause_to_reason_are_bijective` 두 줄은 ✓ 다(새 `DEGRADE_CAUSES` 는 옛 것과 같은 일곱 원인). 그 파일의 옛 CLI 케이스 둘(`case_real_producer_*`)은 Task 9 가 지운다 — 여기서는 그 둘만 ✗ 다.

- [ ] **Step 6: Commit**

```bash
git add plugins/quality-gates/scripts/diff-test-results.py plugins/quality-gates/tests/test_diff_test_results.py
git commit -m "refactor(quality-gates): diff-test-results pairs assign + row files into one verdict input (R1-R24)"
```

- [ ] **Step 7: 변이로 이빨을 확인한다**

Run: `python3 "$SCR/r-mutations.py" "$PWD" R1 R2 R5 R7 R8 R9 R9b R10 R13 R15c R16 R17 R19 R24`
Expected: 모두 `RED`, `tree restored`.

---

### Task 7: 절차 문서 제자리 재작성 · SKILL 의 차등 절

**Files:**
- Modify(전문 교체): `plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(`## Differential test` 절 본문 교체 · 옛 차등 토큰 정리)
- Create: `plugins/quality-gates/tests/test_differential_procedure.sh`
- Modify(필요할 때만): `shared/tests/test_plugin_root_no_cwd_fallback.sh`(하한)

**Interfaces:**
- Consumes: Task 1~6 의 CLI 전부.
- Produces: 절차 D0~D8 · 판정 입력 표(D7). SKILL 의 `## Differential test` 절은 reference 를 읽고, 판정 입력과 D8 을 가리킨다. ③ 의 게시 · ④ 의 e2e 절은 건드리지 않는다.

- [ ] **Step 1: 절차 테스트를 쓴다**

`plugins/quality-gates/tests/test_differential_procedure.sh` 를 만든다(실행 비트):

````bash
#!/usr/bin/env bash
# test_differential_procedure.sh — 차등 테스트 절차 문서와 파이프라인 SKILL 의 판정 입력 배선.
# 요구: R18 · R22 · R24 (docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록)
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REF="$PLUGIN_ROOT/skills/quality-pipeline/references/differential-test.md"
SKILL="$PLUGIN_ROOT/skills/quality-pipeline/SKILL.md"
VERDICT="$PLUGIN_ROOT/scripts/verdict.py"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

has_line() { grep -qxF -- "$2" "$1"; }

# R18 — 짝짓기가 실패하면 error-axis 다. 표의 행이 그 대응을 싣고, verdict.py 가 그 사유를 not-certified 로 낸다.
case_R18_failed_pairing_routes_to_error_axis() {
  has_line "$REF" '| `diff_rc` 가 0 이 아니다 · 파일이 없다 · D5 전에 절차가 끝났다(D0 메모 실패 · D2 exit 4 포함) | `--reason error-axis` (R18) |' \
    && ok "R18: 판정 입력 표에 error-axis 행" || no "R18: 판정 입력 표에 error-axis 행이 없다"
  local out; out=$(python3 "$VERDICT" --reason error-axis)
  assert_eq "$(printf '%s\n' "$out" | sed -n '1,2p' | tr '\n' ' ')" "verdict: not-certified reason: error-axis " \
    "R18: --reason error-axis → not-certified (error-axis)"
}
# R22 — 오케스트레이터 쪽 kill switch: 절차 전체를 건너뛰고 kill-switch 사유를 싣는다.
case_R22_orchestrator_honors_kill_switch() {
  has_line "$REF" '| D0 의 kill switch | `--reason kill-switch` |' \
    && ok "R22: 판정 입력 표에 kill-switch 행" || no "R22: kill-switch 행이 없다"
  grep -qF '`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 이 절차 전체를 건너뛰고' "$REF" \
    && ok "R22: D0 이 스위치를 먼저 본다" || no "R22: D0 에 스위치 확인이 없다"
}
# R24 — 판정은 D5 산출 파일을 그대로 읽는다. 원장 전사 경로가 없다.
case_R24_verdict_reads_the_machine_output() {
  has_line "$REF" '| `diff_rc=0` 이고 `<memo>/diff-i<N>.yaml` 이 있다 | `--differential "<memo>/diff-i<N>.yaml"` |' \
    && ok "R24: 판정 입력은 D5 파일 경로다" || no "R24: 판정 입력 행이 없다"
  local f n=0
  for f in "$REF" "$SKILL"; do
    grep -qE 'runtime-evidence|check_qa_ledger|floor:verification' "$f" && { n=$((n + 1)); echo "    전사 원장 흔적: $f"; }
  done
  assert_eq "$n" "0" "R24: 절차와 SKILL 에 전사 원장이 없다"
  assert_not_grep "$(cat "$SKILL")" 'aggregate[._]yaml|\(new_regression\|new_test_red\)' \
    "R24: SKILL 은 옛 집계 파일을 읽거나 범주 카운트를 다시 세지 않는다(K 는 new_failures: 에서)"
  grep -qF 'diff-test-results.py' "$REF" && ok "R24 양성 짝: 절차가 diff-test-results.py 를 부른다" || no "R24: 절차가 짝짓기를 부르지 않는다"
}
# SKILL 의 차등 절은 reference 를 읽고, 실행이 끝날 때 메모를 지우라고 말한다.
case_skill_section_wires_the_reference() {
  local sec; sec=$(awk '/^## Differential test$/{on=1; next} on && /^## /{exit} on' "$SKILL")
  assert_contains "$sec" 'Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/differential-test.md' "SKILL: reference 를 읽는다"
  assert_contains "$sec" 'D8' "SKILL: 실행 끝 메모 지우기(D8)를 가리킨다"
  assert_contains "$sec" 'new_failures:' "SKILL: 판정 줄의 차등 새 실패는 new_failures: 에서 온다"
}

# 절차는 D0~D8 아홉 단계이고, 지운 단계(옛 R-init~R8 · 갭 게이트)가 남지 않았다.
case_reference_steps_are_d0_to_d8() {
  local got; got=$(grep -oE '^## D[0-9]+ ' "$REF" | tr -d '# ' | tr '\n' ' ')
  assert_eq "$got" "D0 D1 D2 D3 D4 D5 D6 D7 D8 " "절차 단계 D0~D8 이 순서대로 하나씩"
  assert_not_grep "$(cat "$REF")" '^\*\*Step R|갭 게이트|baseline-cache|test-scope-validator' "옛 단계 · 지운 장치가 절차에 없다"
}
# 토픽 스코프 경로: 기준선은 경계, HEAD 축은 합친 커밋, 후보와 분모는 그 트리에서 센다.
case_topic_path_wiring() {
  assert_contains "$(cat "$REF")" '`boundary:` 이고, HEAD 축은 그 파일의 `head_commit:` 이다' "토픽: 기준선 = 경계 · HEAD = 합친 커밋"
  assert_contains "$(cat "$REF")" '`create-head <head_commit> <session-id> --topic <topic 키>`' "토픽: HEAD 축 트리는 --topic 으로 다시 도출해 대조한다"
  assert_contains "$(cat "$REF")" '토픽 스코프면 `--topic <boundary> <tree>` 를 붙인다' "토픽: 후보는 경계..트리"
  assert_contains "$(cat "$REF")" '(토픽 스코프면 `--total --tree <tree>`)' "토픽: 분모도 그 트리에서"
}

for c in case_R18_failed_pairing_routes_to_error_axis case_R22_orchestrator_honors_kill_switch \
         case_R24_verdict_reads_the_machine_output case_skill_section_wires_the_reference \
         case_reference_steps_are_d0_to_d8 case_topic_path_wiring; do
  echo "== $c"; $c
done
finish
````

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/quality-gates/tests/test_differential_procedure.sh && bash plugins/quality-gates/tests/test_differential_procedure.sh 2>&1 | tail -1`
Expected: FAIL — 옛 절차에는 D0~D8 · D7 표가 없고 원장(`runtime-evidence`)이 있다.

- [ ] **Step 3: 절차 문서를 새 전문으로 바꾼다**

`plugins/quality-gates/skills/quality-pipeline/references/differential-test.md`:

````markdown
# 차등 테스트 절차

이번 변경이 닿는 테스트를 기준선 트리와 HEAD 트리에서 각각 돌려 짝짓는다. 무엇을 돌릴지는 오케스트레이터가
고르고, 실행 · 짝짓기 · 판정 입력은 스크립트가 만든다. 스크립트는 전부 오케스트레이터가 직접 부른다 — 테스트를
돌려 결과를 보고하는 subagent 는 없다.

## 지킬 것

- R1 0 단위 · 0 어댑터는 `not-certified (scope-empty)` 다.
- R2 어느 축이든 error 는 인증을 막고, (pass, error) 는 NEW_REGRESSION 이다.
- R3 exit 127 · 러너 없음 · setup 실패는 unrun 이고, (unrun, x) 는 baseline-unrunnable 이다.
- R4 0/1/127 밖의 종료 코드는 unrun 으로 접지 않는다.
- R5 기준선 행은 기준선 트리에서 실제로 돈 것만 유효하다.
- R6 실행 안 메모는 리포 밖에 살고 실행과 함께 사라진다.
- R7 단위마다 축별로 정확히 한 행이다. 누락은 SILENT_DROP, 중복은 거부다.
- R8 기대 단위 목록은 두 결과와 독립인 입력(배정 파일)이다.
- R9 bulk · 도말 실행의 양측 red 는 `granularity-smear` 이고, 입도는 러너에서 도출한다.
- R10 unit 별로 돈 양측 red 는 막지 않고 공시한다.
- R11 HEAD 축은 작업트리 전체를 봉인한 별도 트리다. 지금 쓰는 작업 트리에서 돌리지 않는다.
- R12 HEAD 축을 기준선 커밋으로 만들지 않는다.
- R13 두 축의 트리가 같으면 비교가 성립하지 않는다(not-certified).
- R14 기준선 트리는 어댑터를 스스로 다시 탐지한다.
- R15 flaky 재실행은 NEW_REGRESSION 만, HEAD 트리에서, 정확히 한 번이다. 관측하지 못하면 원래 행을 지킨다.
- R16 고른 단위를 어느 어댑터도 못 돌리면 막는다.
- R17 생산자 실패를 「비었음」으로 읽지 않는다.
- R18 짝짓기 · 집계가 0 이 아닌 종료 코드를 내거나 읽을 수 없으면 `not-certified (error-axis)` 다.
- R19 배정된 러너마다 두 축의 행 파일이 있어야 집계한다.
- R20 단위는 트리 안에 있어야 하고, shell 단위는 `tests/*.sh` 이면서 실행 비트가 있어야 한다.
- R21 unittest 는 판정하지 못하는 파일을 claim 하지 않고, go 단위는 `*_test.go` 를 요구한다.
- R22 kill switch 는 오케스트레이터와 러너 양쪽에서 저장소 코드 실행을 막는다.
- R23 일회용 트리는 모든 종료 경로에서 지운다.
- R24 판정은 기계 출력을 직접 읽고, 모델이 옮겨 적지 않는다.

R2~R5 · R7 · R9~R11 · R14 · R15 · R17 · R19~R21 은 `run-test-selection.sh` 와 `diff-test-results.py` 가
코드로 지킨다. 아래 절차는 그 스크립트들을 빠짐없이 부르는 순서다.

## D0 실행 시작 — 첫 iteration 에서 한 번

`DEVBREW_QUALITY_GATES_DISABLE_DIFFERENTIAL_TEST=1` 이면 이 절차 전체를 건너뛰고 판정 입력은
`--reason kill-switch` 다(R22). 러너도 같은 스위치를 보고 저장소 코드를 돌리지 않는다.

실행 안 메모를 만든다. 경로를 기억해 두고 실행이 끝날 때까지 모든 iteration 이 같은 메모를 쓴다(R6):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/qg-worktree.sh" memo-init "<project_dir>"
```

exit 2 면 stderr 를 그대로 보이고 차등 테스트를 하지 않는다 — 판정 입력은 `--reason error-axis` 다.

기준선을 정한다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/resolve-baseline.sh"
```

- 토픽 스코프(`.claude/quality-gates/<session-id>/topic-scope.txt` 의 `status: ok`)면 기준선 커밋은 그 파일의
  `boundary:` 이고, HEAD 축은 그 파일의 `head_commit:` 이다.
- 아니면 기준선 커밋은 `merge_base:` 다. `degraded: yes` 면 기준선 커밋은 `-` 이다 — 기준선 축을 돌리지 못하고,
  결과는 baseline-unrunnable 로 남는다.

한 줄로 알린다: `> [quality-gates] baseline: <base 또는 topic 키> @ <기준선 커밋 앞 12자> (<ahead>커밋 앞섬)`.

## D1 HEAD 축 트리 — 매 iteration

작업트리 전체를 봉인하고 그 커밋에서 HEAD 축 트리를 만든다(R11 · R12). 토픽 스코프면 봉인하지 않고 D0 의
`head_commit:` 으로 `create-head <head_commit> <session-id> --topic <topic 키>` 를 부른다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
sealed=$("$QG/scripts/seal-worktree.sh" seal "<session-id>") || sealed=""
head_tree=""
if [ -n "$sealed" ]; then
  head_tree=$("$QG/scripts/qg-worktree.sh" create-head "$sealed" "<session-id>") || head_tree=""
fi
printf 'head_commit=%s\nhead_tree=%s\n' "${sealed:--}" "$head_tree"
```

## D2 후보와 배정 — 매 iteration

후보의 바닥을 받는다. 토픽 스코프면 `--topic <boundary> <tree>` 를 붙인다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/compute-test-scope-candidates.sh"
"$QG/scripts/compute-test-scope-candidates.sh" --total
```

exit 4 는 「후보 없음」이 아니다(R17). stderr 를 그대로 보이고 이 iteration 의 판정 입력은 `--reason error-axis` 다.

후보는 바닥이다. 오케스트레이터는 diff 와 의도 출처를 보고 영향 테스트를 **더할** 수만 있고 뺄 수는 없다. 낡았거나
(이번 변경과 무관한 옛 동작을 검사) 골라 담은(변경을 피해 가는) 테스트로 판단한 것은 그대로 돌리되 커버리지로 세지
않는다 — 그 목록과 한 줄 이유를 `result.md` 의 `## 차등 테스트` 에 적는다. 영향 테스트가 하나도 없다고 판단되면
그 사실을 적고 러너 전체를 돌릴지(bulk) 정한다.

고른 파일을 배정 파일로 바꾼다. unit 변환(파일 → 패키지 · bulk 흡수)은 스크립트가 한다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
printf '%s\n' <고른 파일들> | "$QG/scripts/run-test-selection.sh" assign "<스캔 트리>" "<memo>/assign-i<N>.tsv"
```

스캔 트리는 D1 의 `head_tree` 다(비었으면 `<project_dir>`). 배정 파일의 행은
`<unit>\t<runner|unclaimed>\t<granularity>` 이고 마지막 줄은 `#qg-assign` 꼬리다. `unclaimed` 는 어느 러너 어댑터
9종도 못 돌리는 후보다 — 판정에서 silent-drop 이 된다(R16).

계획을 한 줄로 알린다. 분모는 `--total` 의 출력이다(토픽 스코프면 `--total --tree <tree>`):

> `> Differential scope: 영향 테스트 <N>개 선택 (전체 <M>개 중), 러너 <runners> — 이번 변경의 영향분만 기준선 대비로 돌린다.`

`granularity: bulk` 러너가 하나라도 있으면 같은 줄 뒤에 `커버리지 미보장(러너가 선택을 무시함)` 을 붙인다.

## D3 HEAD 축 실행 — 매 iteration

배정 파일의 러너마다(unclaimed 제외) 그 러너의 unit 을 bulk 로 돌리고, fail 이나 error 행이 있으면 그 unit 만
per-unit 으로 다시 돌린다. 다시 돈 행이 bulk 행을 교체한다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" run "<head_tree>" "<runner>" bulk "<memo>/head-<runner>-i<N>.tsv" <unit>...
"$QG/scripts/run-test-selection.sh" run "<head_tree>" "<runner>" per-unit "<memo>/head-<runner>-i<N>.tsv" <fail·error 인 unit>...
```

D1 의 `head_tree` 가 비었으면(봉인이나 트리 생성 실패) stderr 를 그대로 보이고, 지금 작업 트리로 대신 돌리지 않는다. 대신 그
러너의 unit 을 관측 없음으로 채우고 HEAD 커밋은 `-` 로 둔다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" unrun "<memo>/head-<runner>-i<N>.tsv" "<runner>" - <unit>...
```

## D4 기준선 축 — 매 iteration, 아직 돌지 않은 unit 만

같은 실행 안에서 기준선 커밋은 바뀌지 않는다. 메모에 관측된 행이 없는 unit 만 돌린다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" pending "<memo>/baseline-<runner>.tsv" <unit>...
```

나온 unit 이 있으면 기준선 트리를 만들어 D3 과 같은 bulk → per-unit 두 단계로 돌린다. 기준선 트리는 어댑터를
스스로 다시 탐지하므로 HEAD 의 어댑터 집합을 가져다 쓰지 않는다(R14):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
base_tree=$("$QG/scripts/qg-worktree.sh" create-baseline "<기준선 커밋>" "<session-id>") || base_tree=""
printf 'base_tree=%s\n' "$base_tree"
```

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" run "<base_tree>" "<runner>" bulk "<memo>/baseline-<runner>.tsv" <pending unit>...
"$QG/scripts/run-test-selection.sh" run "<base_tree>" "<runner>" per-unit "<memo>/baseline-<runner>.tsv" <fail·error 인 unit>...
```

기준선 커밋이 `-` 이거나 `base_tree` 가 비면 stderr 를 보이고 pending unit 을 관측 없음으로 채운다 — 커밋 칸에는
그 축의 기준선 커밋(`-` 포함)을 그대로 쓴다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" unrun "<memo>/baseline-<runner>.tsv" "<runner>" "<기준선 커밋>" <pending unit>...
```

## D5 짝짓기 — 매 iteration

리포 루트에서 부른다. 출력 파일이 이 iteration 의 판정 입력이다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/diff-test-results.py" --assign "<memo>/assign-i<N>.tsv" --rows "<memo>" --iter <N> \
  --baseline-commit "<기준선 커밋>" --head-commit "<HEAD 커밋>" > "<memo>/diff-i<N>.yaml"
echo "diff_rc=$?"
```

`per_adapter` 의 `attributions` 에 `NEW_REGRESSION` 인 unit 이 있으면 그 unit 만 HEAD 축 트리에서 한 번 다시 돌리고
(flaky 재실행) 이 펜스를 다시 부른다. 마지막 호출의 결과가 이 iteration 의 결과다(R15):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/run-test-selection.sh" run "<head_tree>" "<runner>" flaky "<memo>/head-<runner>-i<N>.tsv" <NEW_REGRESSION unit>...
```

## D6 트리 정리 — 모든 종료 경로

이 iteration 에서 만든 트리는 결과가 어떻든 지운다(R23). 지울 트리가 없으면 건너뛴다:

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
for t in "<base_tree>" "<head_tree>"; do
  if [ -n "$t" ] && [ -d "$t" ]; then "$QG/scripts/qg-worktree.sh" remove "$t"; fi
done
```

## D7 판정 입력

판정은 `verdict.py` 가 D5 의 파일을 직접 읽어 정한다(R24). 이 절차는 값을 옮겨 적지 않는다.

| 이 절차의 결과 | `verdict.py` 에 |
|---|---|
| D0 의 kill switch | `--reason kill-switch` |
| `diff_rc=0` 이고 `<memo>/diff-i<N>.yaml` 이 있다 | `--differential "<memo>/diff-i<N>.yaml"` |
| `diff_rc` 가 0 이 아니다 · 파일이 없다 · D5 전에 절차가 끝났다(D0 메모 실패 · D2 exit 4 포함) | `--reason error-axis` (R18) |

판정 줄의 「차등 새 실패」 칸은 그 파일의 `new_failures:` 값이다. `result.md` 의 `## 차등 테스트` 에는 그 파일을
그대로 붙이고, D2 에서 커버리지로 세지 않은 테스트 목록을 덧붙인다. 양측 빨강을 공시하는 `resolution_disclosure:`
줄이 있으면 판정 줄 옆에도 그대로 보인다(R10). bulk 러너가 양측 red 면 이 문장을 그대로 쓴다:

> `기준선도 빨간 상태입니다. 이 러너(<runner>)는 파일 단위 지목이 안 되므로 그 안에 새 회귀가 숨었는지 구분하지 못했습니다.`

## D8 실행 끝 — 메모 지우기

파이프라인이 어느 경로로 끝나든(최종 판정 · Stop · 중단) 마지막에 메모를 지운다(R6):

```bash
QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || { echo "[quality-gates] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라" >&2; exit 1; }
"$QG/scripts/qg-worktree.sh" memo-drop "<memo>"
```
````

- [ ] **Step 4: SKILL 의 `## Differential test` 절을 바꾼다**

② 가 쓴 그 절의 본문(제목 다음 줄부터 다음 `## ` 제목 앞까지)을 통째로 바꾼다. `$SCR/replace_skill_section.py`:

````python
#!/usr/bin/env python3
"""SKILL.md 의 `## Differential test` 절 본문을 ⑤ 의 본문으로 통째로 바꾼다. 다음 `## ` 제목 앞까지가 그 절이다."""
import sys
from pathlib import Path

BODY = """
절차는 `references/differential-test.md` 에 있다. 매 iteration 의 차등 테스트 단계에서 그 파일을 Read 로 읽고
D0~D8 을 그대로 따른다. trivia 로 파이프라인 전체를 건너뛴 실행만 읽지 않는다.

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/differential-test.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

- 판정 입력은 그 파일의 D7 표가 정한다 — `verdict.py`(합성기를 거치면 합성기)에 `--differential "<memo>/diff-i<N>.yaml"`
  또는 `--reason kill-switch` · `--reason error-axis` 중 하나를 싣는다.
- 판정 줄의 「차등 새 실패」 칸은 그 yaml 의 `new_failures:` 값이다.
- 차등 회귀(`confirmed_product_defect: true`)는 패치가 없는 defect 다 — Fix-loop 의 「패치가 없는 defect」 경로로 간다.
- 파이프라인이 어느 경로로 끝나든(최종 판정 · Stop · 중단) 마지막에 D8(실행 안 메모 지우기)을 돈다.

"""


def main():
    path = Path(sys.argv[1])
    lines = path.read_text(encoding="utf-8").split("\n")
    heads = [i for i, l in enumerate(lines) if l == "## Differential test"]
    if len(heads) != 1:
        sys.exit(f"'## Differential test' 제목이 {len(heads)}개 — 정확히 1개여야 한다")
    start = heads[0]
    end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith("## ")), None)
    if end is None:
        sys.exit("'## Differential test' 다음 '## ' 제목이 없다")
    lines[start + 1:end] = BODY.split("\n")
    path.write_text("\n".join(lines), encoding="utf-8")
    print(f"replaced lines {start + 2}..{end} of {path}")


if __name__ == "__main__":
    main()
````

Run: `python3 "$SCR/replace_skill_section.py" plugins/quality-gates/skills/quality-pipeline/SKILL.md && git diff --stat -- plugins/quality-gates/skills/quality-pipeline/SKILL.md`
Expected: `replaced lines …` 와 SKILL.md 한 파일 변경.

- [ ] **Step 5: SKILL 의 다른 절에 남은 옛 차등 토큰을 정리한다**

Run: `grep -nE 'runtime-evidence|check_qa_ledger|floor:verification|baseline-cache|test-scope-validator|discover-plan|plan_path|expected-adapters|baseline-detected|aggregate[._]yaml|new_regression\|new_test_red|R1b|R-init|R5b|갭 게이트' plugins/quality-gates/skills/quality-pipeline/SKILL.md`

나온 줄마다 아래 규칙으로 고친다. 표에 없는 모양이면 멈추고 보고한다.

| 나온 줄 | 처리 |
|---|---|
| frontmatter `allowed-tools` 의 지운 스크립트 항목(`baseline-cache.sh` · `check_qa_ledger.py`) | 그 항목 줄을 지운다 |
| `test-scope-validator` dispatch 블록 · 그 처분 줄 | 블록째 지운다 — 판단은 절차 D2 가 한다 |
| `plan_path` 인자 설명 | 그 불릿을 지운다(`spec_path` · `DISABLE_SPEC_CONFORMANCE` 는 Task 9 가 다룬다) |
| 판정 입력 라우팅에서 원장(`check_qa_ledger` · `runtime-evidence` · `floor:verification`)을 근거로 `--reason silent-drop` 을 싣는 행 | 그 행을 지운다 — 같은 사실(unclaimed · 행 누락)은 차등 파일의 `degrade_causes` 가 싣는다 |
| 판정 줄의 `K=` 추출 줄 — ② 의 `## Final verdict` · ④ 의 `## e2e` 펜스에서 `K=0; if [ -f "$RD/aggregate.yaml" ]; then for n in $(grep -oE '(new_regression\|new_test_red): [0-9]+' …` 모양으로 범주 카운트를 다시 더하는 문장 전체(`K=0;` 부터 그 `fi` 까지) | 아래 한 줄로 바꾼다. 차등 출력이 이미 그 합을 `new_failures:` 로 낸다(P12) — 다시 세면 같은 사실을 두 자리가 따로 말한다. `<memo>`·`<N>` 은 그 펜스가 쓰는 자리표시 그대로다:<br>`K=0; DY="<memo>/diff-i<N>.yaml"; if [ -f "$DY" ]; then K=$(sed -n 's/^new_failures: //p' "$DY"); [ -n "$K" ] \|\| { echo "[quality-gates] $DY 에 new_failures: 가 없다 — 차등 출력 계약 위반" >&2; K=0; }; fi` |
| 그 밖의 옛 집계 파일 경로(`$RD/aggregate.yaml` · `$aggregate_yaml` — 예: 합성기나 `verdict.py` 의 `--differential` 인자) | `"<memo>/diff-i<N>.yaml"` 로 바꾼다(D7 표와 같은 경로) |
| 옛 단계 이름(`R1b` · `R-init` · `R5b` · 갭 게이트)으로 절차를 가리키는 문장 | 「`references/differential-test.md` 의 D<n>」 으로 바꾼다(R-init→D0, R1a·R1b→D2, R4→D4, R5b→D3, R6→D5, R8→D7). 갭 게이트를 가리키는 문장은 지운다 |

Run(다시): 위 grep
Expected: 출력 없음.

- [ ] **Step 6: 테스트 · 공유 락**

Run: `bash plugins/quality-gates/tests/test_differential_procedure.sh 2>&1 | tail -1; bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -E '✗|하한|Total'`
Expected: 첫 줄 `Total: 17 | Pass: 17 | Fail: 0`. 공유 락은 `Fail: 0` 이어야 한다.

공유 락의 하한 둘(`축 2 대상 reference 펜스 … (하한 N)` · `가드를 지나는 펜스 … 핀한 하한 N`)이 ✗ 면, 새 절차의 가드 펜스는 15개이고 옛 절차(⑤ 직전)는 `git show "$(git merge-base origin/main HEAD)":plugins/quality-gates/skills/quality-pipeline/references/differential-test.md | grep -c '^QG="\${CLAUDE_PLUGIN_ROOT}"'` 개였다(이 plan 작성 시점 9.3.6 은 17). **모자란 수가 정확히 (옛 − 15) 일 때만** 그 하한을 그만큼 내리고, 같은 커밋 메시지에 「차등 절차 재작성으로 가드 펜스 <옛>→15」 를 적는다. 차이가 다르면 내리지 말고 원인(정규식 밖으로 다시 쓴 가드)을 찾는다.

- [ ] **Step 7: Commit**

```bash
git add plugins/quality-gates/skills/quality-pipeline/references/differential-test.md plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/test_differential_procedure.sh
git add shared/tests/test_plugin_root_no_cwd_fallback.sh 2>/dev/null || true
git commit -m "docs(quality-gates): differential-test reference rewritten in place — requirement list + D0-D8"
```

- [ ] **Step 8: 변이로 이빨을 확인한다**

Run: `python3 "$SCR/r-mutations.py" "$PWD" R18 R22o`
Expected: 둘 다 `RED`, `tree restored`.

---

### Task 8: 마지막 소비자와 함께 지우기 — 캐시 · 원장 · validator · plan 탐색

**Files:**
- Delete: `plugins/quality-gates/scripts/{baseline-cache.sh,check_qa_ledger.py,discover-plan.sh,discover_common.sh}` · `plugins/quality-gates/agents/test-scope-validator.md` · `plugins/quality-gates/tests/fixtures/test-scope/` · `plugins/quality-gates/tests/{test_baseline_cache.sh,test_qa_ledger.sh,test_discover_plan.sh,test_test_scope_validator_behavior.py,test_test_scope_validator_frontmatter.sh}`
- Modify: `plugins/quality-gates/scripts/qg-gc.py` · `plugins/quality-gates/tests/test_qg_gc.py` · `plugins/quality-gates/scripts/scope_tuple.py`(주석) · `plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md`
- Modify(소비자): `plugins/quality-gates/tests/{test_agent_model_mutation.sh,test_worktree.sh,test_law2_prose.sh,test_runtime_contract_invariance.sh,test_codex_runner_degrade_contract.sh}` · `plugins/quality-gates/tests/harness/agent_stub.py`

**Interfaces:**
- Consumes: Task 7 까지 — 이 Task 뒤에는 차등 절차가 지운 파일을 하나도 부르지 않는다(AC27).
- Produces: K-1 「⑤ 뒤」 표지.

- [ ] **Step 1: 지울 파일의 소비자가 남지 않았는지 먼저 본다**

Run: `bash "$SCR/aliases-c5.sh" "$PWD" | grep -A30 -E '^(baseline-cache|check_qa_ledger|discover-plan|discover_common|test-scope-validator|fixtures/test-scope) '`
Expected: 남은 자리는 지울 파일 자신 · 그 테스트 · 아래 Step 3~5 가 고칠 소비자 · README(Task 10)뿐이다. 그 밖의 파일이 나오면 멈추고 보고한다.

- [ ] **Step 2: 지운다**

```bash
git rm -q plugins/quality-gates/scripts/baseline-cache.sh plugins/quality-gates/scripts/check_qa_ledger.py \
  plugins/quality-gates/scripts/discover-plan.sh plugins/quality-gates/scripts/discover_common.sh \
  plugins/quality-gates/agents/test-scope-validator.md
git rm -rq plugins/quality-gates/tests/fixtures/test-scope
git rm -q plugins/quality-gates/tests/test_baseline_cache.sh plugins/quality-gates/tests/test_qa_ledger.sh \
  plugins/quality-gates/tests/test_discover_plan.sh plugins/quality-gates/tests/test_test_scope_validator_behavior.py \
  plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh
git status --short | head -20
```

- [ ] **Step 3: GC 테스트를 먼저 더한다**

`plugins/quality-gates/tests/test_qg_gc.py` 의 마지막 `if __name__ == "__main__":` 줄 **앞에** 다음 클래스를 넣는다:

```python
class LegacyRuntimeEvidenceMarker(unittest.TestCase):
    """K-1 ⑤ — runtime-evidence.md 는 생산자가 없는 회수 표지다. 그 표지만 남은 옛 폴더도 TTL 뒤 회수된다."""

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)

    def test_runtime_evidence_is_a_legacy_marker(self):
        import importlib.util
        spec = importlib.util.spec_from_file_location("qg_gc_mod", GC)
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        self.assertIn("runtime-evidence.md", mod.LEGACY_SESSION_MARKERS)
        self.assertNotIn("runtime-evidence.md", mod.SESSION_MARKERS)

    def test_runtime_evidence_only_folder_collected(self):
        folder = self.tmp / ".claude" / "quality-gates" / ("sess" + "e" * 8)
        folder.mkdir(parents=True)
        f = folder / "runtime-evidence.md"
        f.write_text("- x\n", encoding="utf-8")
        old = time.time() - 48 * 3600
        os.utime(f, (old, old))
        os.utime(folder, (old, old))
        proc = run_gc(self.tmp)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertFalse(folder.exists(), "runtime-evidence.md 만 남은 옛 폴더가 회수되지 않는다 — 업그레이드 누수")
```

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_qg_gc.py 2>&1 | tail -3`
Expected: FAIL — `test_runtime_evidence_is_a_legacy_marker` 가 실패한다(아직 `SESSION_MARKERS` 에 있다). `test_runtime_evidence_only_folder_collected` 는 이미 통과한다 — 회수 행동은 두 목록 어디에 있든 같고, 이 테스트는 이동 뒤에도 회수가 이어지는지를 지킨다.

- [ ] **Step 4: GC 표지를 K-1 「⑤ 뒤」 로 옮긴다**

```bash
python3 - <<'PY'
from pathlib import Path
p = Path("plugins/quality-gates/scripts/qg-gc.py")
s = p.read_text(encoding="utf-8")
for old, new in (
    ('SESSION_MARKERS = ("result.md", "runtime-evidence.md")', 'SESSION_MARKERS = ("result.md",)'),
    ('LEGACY_SESSION_MARKERS = ("files.md", "publish-eligible.md", "pipeline.md")',
     'LEGACY_SESSION_MARKERS = ("files.md", "publish-eligible.md", "pipeline.md", "runtime-evidence.md")'),
):
    assert s.count(old) == 1, old
    s = s.replace(old, new)
p.write_text(s, encoding="utf-8")
PY
grep -n 'runtime-evidence' plugins/quality-gates/scripts/qg-gc.py
```

Run: `PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/test_qg_gc.py 2>&1 | tail -3`
Expected: `OK`.

grep 이 보이는 주석 가운데 `runtime-evidence.md` 를 **지금 쓰는 생산자**가 있다고 말하는 문장(9.3.6 에서는 「`runtime-evidence.md`는 차등 테스트의 evidence-log 이름(R-AG로 존치) — skills/quality-pipeline/references/differential-test.md의 Step R8이 `.claude/quality-gates/<sid>/runtime-evidence.md`에 직접 쓴다(실재 확인됨).」 세 줄)을 그 문장의 모든 줄째 아래 한 줄로 바꾼다:

```python
# `runtime-evidence.md` 는 차등 테스트 재건(⑤) 전 버전의 원장 이름이다 — 생산자는 없고, 그 버전이 남긴 폴더를 회수하려고 LEGACY 에 둔다.
```

- [ ] **Step 5: validator · plan 탐색의 소비자를 정리한다**

```bash
python3 - <<'PY'
from pathlib import Path
Q = Path("plugins/quality-gates")
edits = [
    # 변이 락의 짝 목록에서 지운 agent 를 뺀다.
    (Q / "tests/test_agent_model_mutation.sh",
     '  "plugins/quality-gates/agents/test-scope-validator.md|plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh"\n', ''),
    # 러너가 쓰는 형제 목록에서 지운 파일을 뺀다(조건부 cp 라 없어도 통과하지만 별칭이 남는다).
    (Q / "tests/test_codex_runner_degrade_contract.sh",
     'for f in build_codex_prompt.py codex_prompt_common.py discover-spec.sh discover_common.sh prompt-preamble.md; do',
     'for f in build_codex_prompt.py codex_prompt_common.py discover-spec.sh prompt-preamble.md; do'),
]
for path, old, new in edits:
    s = path.read_text(encoding="utf-8")
    if old not in s:
        print(f"이미 없음(앞 컷오버가 바꿨다 — 손으로 확인): {path}")
        continue
    path.write_text(s.replace(old, new, 1), encoding="utf-8")
    print(f"고침: {path}")
PY
grep -nE 'test-scope-validator|discover-plan|discover_common' \
  plugins/quality-gates/tests/test_worktree.sh plugins/quality-gates/tests/test_law2_prose.sh \
  plugins/quality-gates/tests/harness/agent_stub.py plugins/quality-gates/tests/test_codex_runner_degrade_contract.sh \
  plugins/quality-gates/tests/test_runtime_contract_invariance.sh
```

grep 에 남은 자리를 이렇게 고친다:
- `test_worktree.sh` — `discover-plan.sh` 를 재는 Test 2 블록(`DISCOVER=` 줄과 그것을 쓰는 단언)을 지운다. `for agent in test-scope-validator security-reviewer` · `for name in test-scope-validator security-reviewer` 는 `security-reviewer` 하나만 남긴다.
- `test_law2_prose.sh` · `harness/agent_stub.py` — 주석 · docstring 의 agent 나열에서 `test-scope-validator` 를 뺀다(행동 변화 없음).
- `test_codex_runner_degrade_contract.sh` — `discover_common.sh` 를 형제로 설명하는 주석 두 줄을 지운다.
- `test_runtime_contract_invariance.sh` 의 `case_no_new_surfaces` — `[[ "$agents" == "N" ]]` 의 N 을 1 줄이고, 그 줄의 주석에 「⑤: test-scope-validator 삭제」 를 더한다(의식적 갱신 — 그 케이스 머리 주석의 규약).

- [ ] **Step 6: 남은 옛 이름 주석을 고친다**

`plugins/quality-gates/scripts/scope_tuple.py` 의 두 줄(9.3.6 기준 21~22행)

```python
# (§6.2.5), `base-unresolved` 는 차등 테스트 R-init 의 「baseline 확정 불가」가,
# `seal-failed` 는 R5b 의 HEAD 축 미관측이 이미 막는다. `unbounded` · `merge-failed` 는
```

을 아래로 바꾼다:

```python
# (§6.2.5), `base-unresolved` 는 차등 테스트 D0 의 기준선 미확정(기준선 커밋 `-`)이,
# `seal-failed` 는 D1 의 HEAD 축 미관측(HEAD 커밋 `-`)이 이미 막는다. `unbounded` · `merge-failed` 는
```

`references/state-file-format.md` 에 `runtime-evidence.md` 가 남아 있으면 그 언급을 지운다(동반 파일이 그것뿐인 문장은 문장째).

색인 K-1 의 조건 — 표지를 LEGACY 로 옮기는 커밋은 그 이름의 살아 있는 언급을 같은 커밋에서 모두 지운다
(`tests/test_a20_tool_agnostic_scope.py` 가 skills · commands · agents · hooks · scripts 에서 잰다, `qg-gc.py` 는 제외). Step 4 가 `runtime-evidence.md` 를 옮겼으므로 그 코퍼스에서 같은 탐지식으로 찾는다:

```bash
python3 - <<'PY'
import re
from pathlib import Path
Q = Path("plugins/quality-gates")
pat = re.compile(r"(?<![\w.-])runtime-evidence\.md")
for sub in ("skills", "commands", "agents", "hooks", "scripts"):
    for p in sorted((Q / sub).rglob("*")):
        if p.is_file() and p.name != "qg-gc.py":
            for i, line in enumerate(p.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
                if pat.search(line):
                    print(f"{p}:{i}: {line.strip()[:120]}")
PY
```

Expected: 출력 없음. 나오면(②~④ 가 `result.md` 설명 · `## Final verdict` · `## e2e` 등에 남긴 자리 포함) 그 언급을 지우거나 「차등 출력(`<memo>/diff-i<N>.yaml`)」 으로 바꾼다.

- [ ] **Step 7: 스위트 확인**

Run: `for t in test_qg_gc.py test_a20_tool_agnostic_scope.py test_agent_model_mutation.sh test_worktree.sh test_law2_prose.sh test_runtime_contract_invariance.sh test_codex_runner_degrade_contract.sh; do printf '%s: ' $t; case $t in *.py) PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/$t 2>&1 | tail -1 ;; *) bash plugins/quality-gates/tests/$t 2>&1 | tail -1 ;; esac; done`
Expected: 각 파일의 실패 줄 수가 Task 0 기준 이하다(새 실패 없음). 특히 `test_a20_tool_agnostic_scope.py` 는 `OK` 여야 한다 — `test_markers_absent_from_model_read_surface` 가 이 Task 의 K-1 이동을 잰다. `test_agent_model_mutation.sh` 는 「agents/ clean」 전제가 있어 커밋 뒤에 다시 돌린다.

- [ ] **Step 8: Commit**

```bash
git add -A plugins/quality-gates/scripts plugins/quality-gates/agents plugins/quality-gates/tests plugins/quality-gates/skills/quality-pipeline/references/state-file-format.md
git commit -m "feat(quality-gates)!: drop baseline cache, QA ledger, test-scope-validator and plan discovery with their last consumers"
bash plugins/quality-gates/tests/test_agent_model_mutation.sh 2>&1 | tail -1
```

Expected: 커밋 뒤 `test_agent_model_mutation.sh` 가 `Fail: 0`.

---

### Task 9: 표면 정리 — `--plan` · `DISABLE_SPEC_CONFORMANCE` · `spec_path` · 옛 절차 문면 락

**Files:**
- Modify: `plugins/quality-gates/scripts/setup-qg.sh` · `plugins/quality-gates/commands/qg.md` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md`
- Modify: `plugins/quality-gates/scripts/discover-spec.sh` · `plugins/quality-gates/scripts/run_codex_reviewer.sh` · `plugins/quality-gates/scripts/build_codex_prompt.py`
- Create: `plugins/quality-gates/tests/test_removed_plan_arg.sh` · `plugins/quality-gates/tests/test_discover_spec_keys.sh`
- Delete: `plugins/quality-gates/tests/test_runtime_verdict_precedence.sh`
- Modify(소비자): `plugins/quality-gates/tests/{test_pipeline_verdict_wiring.sh,test_topic_scope_wiring.sh,test_one_pipeline_surface.sh,test_verdict_vocabulary.sh,test_impact_runtime_docs.sh,test_discover_spec.sh}` · `tests/harness/test_skill_orchestration_behavior.sh` · `tests/lib/reconstruct-skill.sh`

**Interfaces:**
- Consumes: ① 의 제거 인자 처리(`--pr-url` 등) · ② 의 `discover-spec.sh`(K-5) · ② 의 `run_codex_reviewer.sh` 의도 입력.
- Produces: K-5 「⑤ 뒤」(키 셋) · AC25 의 `--plan`.

- [ ] **Step 1: 새 테스트 둘을 쓴다**

`plugins/quality-gates/tests/test_removed_plan_arg.sh`(실행 비트):

````bash
#!/usr/bin/env bash
# test_removed_plan_arg.sh — `--plan` 은 제거 안내 한 줄을 내고 끝난다(AC25). ① 이 지운 `--pr-url` 과 같은 길로 간다.
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
SETUP="$PLUGIN_ROOT/scripts/setup-qg.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
trap 'cd / && rm -rf "$R"' EXIT
git init -q -b main "$R" && git -C "$R" config user.email t@t && git -C "$R" config user.name t
( cd "$R" && echo x > a && git add a && git -c commit.gpgsign=false commit -qm a ) || exit 1

run_setup() {   # run_setup <args…> → "<rc>|<stdout+stderr>"
  local out rc
  out=$(cd "$R" && env -u DEVBREW_QUALITY_GATES_DISABLE CLAUDE_CODE_SESSION_ID=abcdefgh1234 bash "$SETUP" "$@" 2>&1); rc=$?
  printf '%s|%s' "$rc" "$out"
}

plan=$(run_setup --plan docs/x.md)
pr=$(run_setup --pr-url https://example.invalid/pr/1)
assert_eq "${plan%%|*}" "${pr%%|*}" "AC25: --plan 의 종료 코드가 제거된 --pr-url 과 같다"
assert_contains "${plan#*|}" "--plan" "AC25: 안내가 --plan 을 이름으로 말한다"
assert_not_contains "${plan#*|}" "Plan file:" "AC25: --plan 값을 쓰지 않는다"
assert_eq "$(printf '%s\n' "${plan#*|}" | grep -c -- '--plan')" "1" "AC25: 안내는 한 줄이다"
hint=$(sed -n 's/^argument-hint: //p' "$PLUGIN_ROOT/commands/qg.md")
[ -n "$hint" ] && ok "qg.md 에 argument-hint 줄이 있다" || no "qg.md argument-hint 줄을 찾지 못했다"
assert_not_contains "$hint" "--plan" "AC25: qg.md argument-hint 에 --plan 이 없다"
finish
````

`plugins/quality-gates/tests/test_discover_spec_keys.sh`(실행 비트):

````bash
#!/usr/bin/env bash
# test_discover_spec_keys.sh — ⑤ 뒤 discover-spec.sh 의 출력 키는 intent 셋뿐이다(K-5 ⑤ 줄 · AC27).
set -u
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DS="$(cd -- "$SCRIPT_DIR/.." && pwd)/scripts/discover-spec.sh"
. "$(cd "$SCRIPT_DIR/../../.." && pwd)/shared/tests/assert.sh"

R=$(mktemp -d) && [ -d "$R" ] || { echo "mktemp 실패" >&2; exit 1; }
trap 'cd / && rm -rf "$R"' EXIT
git init -q -b main "$R/repo" && git -C "$R/repo" config user.email t@t && git -C "$R/repo" config user.name t
mkdir -p "$R/repo/docs/superpowers/specs" "$R/bin"
printf '# s\n\n## Acceptance Criteria\n- AC1 x\n' > "$R/repo/docs/superpowers/specs/2026-01-01-x-design.md"
( cd "$R/repo" && git add -A && git -c commit.gpgsign=false commit -qm "feat: x" \
    -m "Spec: docs/superpowers/specs/2026-01-01-x-design.md" ) || exit 1
# gh 는 읽기 전용으로만 불린다 — 네트워크 없이 「gh 오류」 경로로 보낸다.
printf '#!/bin/sh\nexit 1\n' > "$R/bin/gh"; chmod +x "$R/bin/gh"

out=$(cd "$R/repo" && PATH="$R/bin:$PATH" bash "$DS" --intent-out "$R/intent.md" 2>/dev/null); rc=$?
assert_eq "$rc" "0" "discover-spec.sh exit 0"
keys=$(printf '%s' "$out" | python3 -c 'import json,sys; print(" ".join(sorted(json.loads(sys.stdin.read()))))' 2>/dev/null)
assert_eq "$keys" "intent_file intent_note intent_source" "K-5 ⑤: 키는 intent_source · intent_note · intent_file 셋"
assert_not_contains "$out" '"spec_path"' "K-5 ⑤: spec_path 키가 없다"
src=$(printf '%s' "$out" | python3 -c 'import json,sys; print(json.loads(sys.stdin.read())["intent_source"])' 2>/dev/null)
assert_eq "$src" "spec-trailer" "양성 짝: Spec: 트레일러는 여전히 첫 의도 출처다"
finish
````

- [ ] **Step 2: 실패를 확인한다**

Run: `chmod +x plugins/quality-gates/tests/test_removed_plan_arg.sh plugins/quality-gates/tests/test_discover_spec_keys.sh; bash plugins/quality-gates/tests/test_removed_plan_arg.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_discover_spec_keys.sh 2>&1 | tail -1`
Expected: 둘 다 FAIL — `--plan` 은 아직 값을 받고(`Plan file:`), `discover-spec.sh` 는 아직 `spec_path` 를 낸다.

- [ ] **Step 3: `--plan` 을 제거 인자로 옮긴다**

`setup-qg.sh` 에서 ① 이 만든 제거 인자 처리(`--pr-url` 을 받으면 제거 안내 한 줄을 내고 끝나는 arm)를 찾는다: `grep -n -- '--pr-url' plugins/quality-gates/scripts/setup-qg.sh`. 그 arm 의 패턴에 `--plan` 을 더해 **같은 동작**을 하게 하고, 값을 받던 `--plan)` arm 과 `PLAN_FILE` 변수 · `Plan file:` 출력을 지운다. 안내 문구는 ① 의 것과 같은 모양으로 `--plan` 을 이름으로 말한다. `--plan` 의 값 인자는 읽지 않아도 된다 — 안내를 내고 끝나기 때문이다.

`commands/qg.md`: frontmatter `argument-hint` 에서 `[--plan <path>]` 를 지우고, Quick Reference 의 `/qg --plan <path>` 행을 지운다. ① 이 제거 인자 행(예: 「`--reset` · `--gc` · `--pr-url` — 제거됨」)을 두었으면 그 행에 `--plan` 을 더한다.

`SKILL.md`: `grep -n -- '--plan\|plan_path' plugins/quality-gates/skills/quality-pipeline/SKILL.md` 로 남은 인자 설명을 찾아 지운다.

- [ ] **Step 4: `spec_path` 키와 `DISABLE_SPEC_CONFORMANCE` 를 지운다**

`discover-spec.sh`: stdout JSON 을 만드는 자리에서 `"spec_path"` 멤버와 그 값만 만드는 변수를 지운다. 나머지 세 키의 값과 순서는 그대로다. ②~④ 동안 그 키를 읽던 소비자(validator · 옛 차등 절차)는 Task 7·8 에서 사라졌다 — `grep -rn 'spec_path' plugins/quality-gates --include='*.sh' --include='*.py' --include='*.md' | grep -v CHANGELOG` 가 이 스크립트 밖에서 0 건이어야 한다(`test_discover_spec.sh` 가 그 키를 단언하면 그 단언을 지운다).

`run_codex_reviewer.sh`: `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` 를 보는 분기를 지워 의도 출처가 언제나 실리게 하고, 머리 주석의 그 env 설명 줄을 지운다. `build_codex_prompt.py` 의 그 스위치를 말하는 주석을 지운다. `SKILL.md` 의 kill switch 색인에서 그 줄을 지운다.

Run: `grep -rn 'DISABLE_SPEC_CONFORMANCE' plugins/quality-gates | grep -v CHANGELOG`
Expected: 출력 없음. 양성 짝으로 `grep -c 'DEVBREW_QUALITY_GATES_DISABLE_CODEX' plugins/quality-gates/scripts/run_codex_reviewer.sh` 가 1 이상(형제 스위치는 그대로다).

- [ ] **Step 5: 두 새 테스트 통과**

Run: `bash plugins/quality-gates/tests/test_removed_plan_arg.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_discover_spec_keys.sh 2>&1 | tail -1; bash plugins/quality-gates/tests/test_discover_spec.sh 2>&1 | tail -1`
Expected: 셋 다 `Fail: 0`.

- [ ] **Step 6: 옛 절차 문면 락을 정리한다**

옛 절차(R-init~R8 · probe · 원장 · 갭 게이트 · 6필드 산문)의 문면을 재던 케이스다. 각 요구는 「요구 → 테스트」 표의 행동 테스트가 진다.

```bash
git rm -q plugins/quality-gates/tests/test_runtime_verdict_precedence.sh
T=plugins/quality-gates/tests
python3 "$SCR/drop_cases.py" $T/test_pipeline_verdict_wiring.sh case_degraded_ledger_row_reaches_silent_drop \
  case_pre_r6_abort_reaches_error_axis_catchall case_pre_r6_abort_catchall_mirrored_in_reference \
  case_r3_stop_choice_routes_to_error_axis case_zero_adapter_aggregate_skips_glob
python3 "$SCR/drop_cases.py" $T/test_topic_scope_wiring.sh case_rinit_topic_branch_sets_axes \
  case_scan_dir_feeds_detect_and_assign case_r4_calls_use_baseline_commit case_r5b_skips_on_topic \
  case_r1b_topic_candidates_supplemented case_early_exit_discards_head_tree case_topic_denominator_uses_tree
python3 "$SCR/drop_cases.py" $T/test_one_pipeline_surface.sh case_reference_step_set case_reference_has_no_design_section_pointers
python3 "$SCR/drop_cases.py" $T/test_verdict_vocabulary.sh case_real_producer_per_adapter_feeds_verdict case_real_producer_aggregate_feeds_verdict
for f in test_pipeline_verdict_wiring.sh test_topic_scope_wiring.sh test_one_pipeline_surface.sh test_verdict_vocabulary.sh; do bash -n $T/$f && echo "$f syntax ok"; done
```

`test_impact_runtime_docs.sh`: `NEW_SCRIPTS=(resolve-baseline.sh run-test-selection.sh baseline-cache.sh` / `diff-test-results.py check_qa_ledger.py)` 두 줄을 `NEW_SCRIPTS=(resolve-baseline.sh run-test-selection.sh diff-test-results.py)` 한 줄로 바꾸고, 같은 파일의 「5종」 두 메시지를 「3종」으로 바꾼다.

- [ ] **Step 7: 남은 소비자를 돌리고 규칙대로 고친다**

Run: `for t in test_pipeline_verdict_wiring.sh test_topic_scope_wiring.sh test_one_pipeline_surface.sh test_verdict_vocabulary.sh test_impact_runtime_docs.sh harness/test_skill_orchestration_behavior.sh; do printf '%s: ' $t; bash plugins/quality-gates/tests/$t 2>&1 | tail -1; done`

Task 0 기준보다 실패 줄이 늘어난 파일마다, 늘어난 ✗ 의 단언이 **옛 차등 절차의 문면이나 지운 스크립트**(R-init · R1b · probe · `--aggregate` · `--expected-adapters` · `baseline-cache` · `check_qa_ledger` · `runtime-evidence` · `test-scope-validator` · `discover-plan`)를 재는지 본다.
- 그렇다면 그 단언(또는 그 케이스)을 지우고, 커밋 메시지 본문에 「<파일>:<케이스> → <요구 번호>(「요구 → 테스트」 표)」 한 줄을 남긴다. `tests/lib/reconstruct-skill.sh` 가 옛 절차의 단계 이름으로 SKILL 과 reference 를 이어 붙이면 그 이름을 D0~D8 로 바꾼다.
- 그렇지 않다면(차등과 무관한 단언) 고치지 말고 멈추고 보고한다 — 이 PR 이 다른 것을 깨뜨렸다.

Expected(고친 뒤): 각 파일의 실패 줄 수가 Task 0 기준 이하.

- [ ] **Step 8: Commit**

```bash
git add -A plugins/quality-gates
git commit -m "feat(quality-gates)!: remove --plan, DISABLE_SPEC_CONFORMANCE and spec_path; retire old procedure text locks"
```

---

### Task 10: 문서 · 버전 · AC23 · 전체 검증

**Files:**
- Modify: `plugins/quality-gates/README.md` · `plugins/quality-gates/CHANGELOG.md` · `plugins/quality-gates/.claude-plugin/plugin.json`

**Interfaces:**
- Consumes: Task 0 의 기록(`baseline-red.tsv` · `aliases-before.txt` · `old/`) · Task 1~9 의 결과.
- Produces: 머지 가능한 브랜치.

- [ ] **Step 1: README**

README 의 차등 테스트 서술을 새 기계에 맞춘다. ①~④ 가 README 를 고쳤으므로 문자열이 아니라 자리로 찾는다(`grep -n 'baseline-cache\|check_qa_ledger\|probe\|test-scope-validator\|discover-plan\|discover_common\|SPEC_CONFORMANCE\|spec_path\|--plan\|Plan Discovery' plugins/quality-gates/README.md`):
- 구조 트리: 지운 네 스크립트 줄과 `test-scope-validator.md` 줄을 지우고, 세 줄을 아래로 바꾼다.

```text
│   ├── run-test-selection.sh                 # 차등 — 러너 어댑터 9종 detect/assign/run/unrun/pending · 꼬리 줄 달린 행 파일 (어댑터 표의 유일 소유자, 오케스트레이터가 직접 호출)
│   ├── diff-test-results.py                  # 차등 — 배정 파일 + 두 축 행 파일 → 귀속 8종 + 판정 입력 한 파일 (verdict.py 가 그대로 읽음)
│   ├── compute-test-scope-candidates.sh      # 차등 — 후보의 바닥(이름 일치 · 바뀐 테스트 · # guards:) + 분모
```

- 「Plan Discovery Sources」 절은 지운다. spec 탐색 절에서 `spec_path` · `DISABLE_SPEC_CONFORMANCE` 문장을 지운다(의도 출처 설명은 ② 의 것 그대로). kill switch 표의 `DISABLE_SPEC_CONFORMANCE` 행을 지운다. 인자 설명의 `--plan` 을 지운다.
- baseline 캐시 · probe · 원장 · validator 를 설명하는 문단이 남아 있으면 그 문단들을 아래 한 문단으로 바꾼다:

```markdown
차등 테스트는 영향 테스트를 기준선 트리와 HEAD 트리(작업트리 전체를 봉인한 일회용 트리)에서 각각 돌려 짝짓는다. 행은 `run-test-selection.sh` 가 꼬리 줄 달린 행 파일에 쓰고, `diff-test-results.py` 가 배정 파일과 두 축의 행 파일을 짝지어 판정 입력 한 파일을 낸다 — 판정은 그 파일을 `verdict.py` 가 직접 읽는다. 기준선 행은 한 번의 `/qg` 동안만 사는 실행 안 메모(리포 밖)에 두고 같은 실행의 다음 iteration 에서 재사용한다. 세션을 넘는 캐시는 없다. 절차와 지킬 요구 R1~R24 는 `skills/quality-pipeline/references/differential-test.md` 에 있다.
```

Run: `bash plugins/quality-gates/tests/test_runner_adapters.sh 2>&1 | grep 'claims\|주장'; bash plugins/quality-gates/tests/test_impact_runtime_docs.sh 2>&1 | tail -1`
Expected: 어댑터 개수 주장 ✓(README 의 「러너 어댑터 9종」), `test_impact_runtime_docs.sh` `Fail: 0`.

- [ ] **Step 2: AC23 — 같은 입력에서 옛판과 범주가 같다**

(a) 여덟 범주 중 일곱을 내는 합성 픽스처:

Run: `bash "$SCR/ac23-fixture.sh" "$SCR/old" "$PWD/plugins/quality-gates/scripts"`

(b) 이 리포의 이 브랜치(기준선 = `origin/main` 과의 merge-base, HEAD = 지금 커밋):

Run: `bash "$SCR/ac23-compare.sh" "$SCR/old" "$PWD/plugins/quality-gates/scripts" "$PWD" "$(git merge-base origin/main HEAD)" "$(git rev-parse HEAD)" plugins/quality-gates/tests/test_compute_test_scope_candidates.sh plugins/quality-gates/tests/test_run_test_selection.sh plugins/quality-gates/tests/test_differential_trees.sh plugins/quality-gates/tests/test_baseline_cache.sh shared/tests/test_assert_behavior.sh`

Expected(둘 다): `old_rc=0` · `new_rc=0`, 「범주 diff」 와 「판정 입력 플래그 diff」 아래가 비어 있다. `degrade_causes` 의 차이는 `smeared` 하나만 허용된다 — 옛판은 기준선 축 mode 를 bulk 로 접어 per-unit 으로 다시 확인한 양측 red 도 도말로 막았고, 새판은 행마다 판정한다(P2 · R10). 그 밖의 차이가 있으면 멈추고 보고한다. 결과 두 묶음을 PR 본문에 붙인다.

- [ ] **Step 3: 요구 번호 대조(AC22)**

Run: `for n in $(seq 1 24); do c=$(grep -rhoE "(case|test)_R(${n}|[0-9]+_R${n})_[A-Za-z0-9_]*" plugins/quality-gates/tests | sort -u | wc -l | tr -d ' '); printf 'R%s %s\n' "$n" "$c"; done`
Expected: 스물네 줄 모두 1 이상.

Run: `python3 "$SCR/r-mutations.py" "$PWD"`
Expected: 마흔 줄 모두 `RED`, 마지막 줄 `tree restored`.

- [ ] **Step 4: 개념 별칭 스윕**

Run: `bash "$SCR/aliases-c5.sh" "$PWD"`
Expected: 아래 허용 자리 밖은 0 이다.

| 별칭 | 허용 자리 | 이유 |
|---|---|---|
| `runtime-evidence` | `scripts/qg-gc.py` · `tests/test_qg_gc.py` | K-1 LEGACY 회수 표지 |
| `baseline-cache` | `tests/test_qg_gc.py`(`test_baseline_cache_dir_survives_gc`) · `scripts/qg-gc.py` 의 형제 디렉토리 주석 | 옛 버전이 남긴 디렉토리를 세션 폴더로 오인하지 않는 락 |
| `R-init` | `scripts/resolve-baseline.sh` · `scripts/check-review-scope.sh` 의 `design 2026-08-01 §5.2 R-init` 인용 | 옛 설계 문서의 절 이름 인용 |
| `spec_path` · `--plan` | `tests/test_discover_spec_keys.sh` · `tests/test_removed_plan_arg.sh` · `setup-qg.sh` 의 제거 안내 · `commands/qg.md` 의 제거 행 | 부재 · 제거를 재는 자리 |

- [ ] **Step 5: 전체 스위트 대조**

Run: `bash "$SCR/baseline-red.sh" "$PWD" "$SCR/after-red.tsv" >/dev/null; join -t "$(printf '\t')" -a2 -e 0 -o 0,1.3,2.3 <(sort "$SCR/baseline-red.tsv") <(sort "$SCR/after-red.tsv") | awk -F'\t' '$3 > $2 { print "새 실패:", $1, $2, "→", $3 }'`
Expected: 출력 없음. 이 PR 이 지운 테스트 파일은 `after` 에 없어 대조되지 않는다(정상). 새 실패가 있으면 Task 9 Step 7 규칙으로 처리하거나 멈추고 보고한다.

- [ ] **Step 6: 버전 · CHANGELOG(머지 직전)**

버전은 머지 직전 `origin/main` 의 `plugins/quality-gates/.claude-plugin/plugin.json` 을 보고 정한다 — major 를 하나 올린다(`--plan` · `DISABLE_SPEC_CONFORMANCE` · `spec_path` 제거). `plugin.json` 의 `version` 을 그 값으로 바꾸고, `CHANGELOG.md` 맨 위 항목으로 아래를 넣는다(`<버전>` · `<날짜>` 는 그 시점 값):

```markdown
## [<버전>] — <날짜>

### Changed
- 차등 테스트를 요구 R1~R24 를 지키는 얇은 기계로 다시 지었다. `run-test-selection.sh` 는 행을 꼬리 줄 달린 행 파일에 병합하고(`run` · `unrun` · `pending`), `diff-test-results.py` 는 배정 파일과 두 축의 행 파일을 직접 읽어 판정 입력 한 파일을 낸다. `verdict.py` 가 그 파일을 그대로 읽는다.
- 도말 판정을 행마다 한다 — unit 별로 다시 확인한 양측 red 는 막지 않고 공시한다(R10). 이전 판은 기준선 축이 늘 bulk 로 시작한다는 이유로 이것까지 `granularity-smear` 로 막았다.
- 후보 바닥(`compute-test-scope-candidates.sh`)은 merge_base 대비 작업트리 + untracked 이고, 기준선을 못 풀면 exit 4 다. 토픽 스코프는 `--topic <boundary> <tree>`.
- `references/differential-test.md` 를 요구 목록 + D0~D8 절차로 제자리에서 다시 썼다.
- 일회용 기준선 · HEAD 트리는 같은 자리에 남은 것을 지우고 다시 만든다.

### Added
- `qg-worktree.sh memo-init` · `memo-drop` — 한 번의 `/qg` 동안만 사는 리포 밖 실행 안 메모.

### Removed
- `baseline-cache.sh`(세션을 넘는 기준선 캐시) · `run-test-selection.sh` 의 `probe` · `cargo-target-dir`.
- `check_qa_ledger.py` 와 `runtime-evidence.md` 원장 — 판정은 기계 출력을 직접 읽는다.
- `test-scope-validator` agent 와 그 fixture — 낡았거나 골라 담은 테스트의 판단은 오케스트레이터가 하고 공시한다.
- `discover-plan.sh` · `discover_common.sh` · `/qg --plan`(제거 안내 한 줄을 내고 끝난다).
- 차등 테스트의 갭 게이트(생략이 있을 때의 질문) — 생략은 공시와 not-certified 가 덮는다.
- `DEVBREW_QUALITY_GATES_DISABLE_SPEC_CONFORMANCE` · `discover-spec.sh` 출력의 `spec_path`.
```

Run: `python3 -c "import json; print(json.load(open('plugins/quality-gates/.claude-plugin/plugin.json'))['version'])"; head -3 plugins/quality-gates/CHANGELOG.md`
Expected: 새 버전 · 새 항목 머리.

- [ ] **Step 7: Commit · 마무리**

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/CHANGELOG.md plugins/quality-gates/.claude-plugin/plugin.json
git commit -m "docs(quality-gates): v10 differential — README, CHANGELOG, version"
git status --short   # 비어 있어야 한다
rm -rf "${TMPDIR:-/tmp}/qg-c5"   # 측정 도구 · 기록은 PR 본문에 붙인 뒤 지운다
```

마무리는 superpowers:finishing-a-development-branch 로 한다. PR 본문에 Task 10 Step 2 의 AC23 결과 두 묶음 · Step 3 의 요구 번호 표 · Step 5 의 「새 실패 없음」 · Task 7 Step 6 에서 공유 락 하한을 바꿨다면 그 근거를 싣는다. 리뷰 라운드는 최대 2 다.

---

## plan 작성 때 확인한 것

- Task 1~7 의 새 스크립트 · 테스트 전문은 9.3.6 리포 복사본 위에서 그대로 돌렸다: `test_runner_adapters.sh` 32/32 · `test_run_test_selection.sh` 49/49 · `test_diff_test_results.py` 28 OK · `test_compute_test_scope_candidates.sh` 17/17 · `test_differential_trees.sh` 17/17 · `test_differential_procedure.sh` 17/17(SKILL 의 옛 원장 · 집계 파일 줄을 지운 상태) · 소비자 `test_guards_declaration_mapping.sh` · `test_resolve_baseline.sh` · `test_guards_coverage_bidirectional.sh` · `shared/tests/test_plugin_root_no_cwd_fallback.sh` 모두 Fail 0.
- Task 1 → 2 → 3 의 단계별 상태에서 테스트가 기대대로 RED/GREEN 이었다(Task 2 의 v1 테스트는 Task 1 상태에서 20 실패, Task 2 상태에서 22/22).
- 변이 마흔 개 모두 해당 Task 상태에서 RED 였다(처음 SURVIVED 였던 R3s · R11 · R15b · R17 · R17b · R21 은 픽스처를 고쳐 RED 로 만들었다).
- AC23 합성 픽스처에서 옛판(9.3.6)과 새판의 범주 · 판정 입력 플래그가 같았고, `degrade_causes` 차이는 `[baseline-unrunnable, silent-drop, smeared]` → `[baseline-unrunnable, silent-drop]` 의 `smeared` 하나였다.
- 확인하지 못한 것: ①~④ 뒤 상태의 `setup-qg.sh` · `discover-spec.sh` · `SKILL.md` 위에서의 Task 4 · 7 · 9 편집(그 파일들이 아직 없다) — Task 0 의 preflight 와 각 Step 의 grep 이 그 자리를 다시 확인한다.
