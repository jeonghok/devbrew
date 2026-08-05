#!/usr/bin/env python3
"""diff-test-results.py 어댑터별 귀속 (design §5.5).

AC11 AC13 AC14 AC15 AC16 AC36 AC43 AC48 · T9 T10 T11 T12 T13 T27 T39 T45 · M4 M22
"""
import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "diff-test-results.py"


def load_module():
    """`diff-test-results.py`는 하이픈 파일명이라 `import`로 못 부른다 — 순수
    함수(`yaml_str`) 단위 테스트를 위해 파일 경로로 직접 로드한다."""
    spec = importlib.util.spec_from_file_location("diff_test_results", SCRIPT)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


_UNSET = object()


def run_diff(expected, baseline, head, granularity="file", runner="pytest",
             baseline_detected=_UNSET, mode: "str | None" = "per-unit"):
    """expected: [unit], baseline/head: [(unit, status, code)] → (rc, stdout, stderr)

    `baseline_detected` 기본값은 **`runner` 자신** — 기준선 트리에서 그 어댑터가
    감지된 정상 상태다. 기존 케이스의 의미가 바뀌지 않는다. `None` 을 넘기면
    플래그 자체를 생략한다 (필수 인자 검사용).
    """
    if baseline_detected is _UNSET:
        baseline_detected = runner
    with tempfile.TemporaryDirectory() as d:
        p = Path(d)
        (p / "e.txt").write_text("\n".join(expected) + "\n", encoding="utf-8")
        for name, rows in (("b.tsv", baseline), ("h.tsv", head)):
            (p / name).write_text(
                "".join(f"{u}\t{s}\t{c}\n" for u, s, c in rows), encoding="utf-8"
            )
        argv = [sys.executable, str(SCRIPT),
                "--expected", str(p / "e.txt"),
                "--baseline", str(p / "b.tsv"),
                "--head", str(p / "h.tsv"),
                "--granularity", granularity, "--runner", runner]
        if mode is not None:
            argv += ["--mode", mode]
        if baseline_detected is not None:
            argv += ["--baseline-detected", baseline_detected]
        r = subprocess.run(argv, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def verdict_of(out, unit):
    """YAML에서 unit의 verdict 한 줄을 뽑는다."""
    lines = out.splitlines()
    for i, ln in enumerate(lines):
        if ln.strip() == f'- unit: "{unit}"':
            return lines[i + 1].split("verdict:")[1].strip()
    return None


def flag_of(out, key):
    for ln in out.splitlines():
        if ln.strip().startswith(f"{key}:"):
            return ln.split(":")[1].strip()
    return None


class TestAttribution(unittest.TestCase):
    # T9 — 귀속 8종 각각 1 픽스처 (AC11)
    def test_eight_categories(self):
        cases = [
            ("still",    "pass",   "pass",   "STILL_GREEN"),
            ("regress",  "pass",   "fail",   "NEW_REGRESSION"),
            ("preexist", "fail",   "fail",   "PRE_EXISTING"),
            ("fixed",    "fail",   "pass",   "FIXED"),
            ("newgreen", "absent", "pass",   "NEW_TEST_GREEN"),
            ("newred",   "absent", "fail",   "NEW_TEST_RED"),
            ("dropped",  "pass",   "unrun",  "SILENT_DROP"),
            ("nobase",   "unrun",  "pass",   "BASELINE_UNRUNNABLE"),
        ]
        units = [c[0] for c in cases]
        b = [(u, bs, "0") for u, bs, _, _ in cases]
        h = [(u, hs, "0") for u, _, hs, _ in cases]
        rc, out, err = run_diff(units, b, h)
        self.assertEqual(rc, 0, err)
        for unit, _, _, want in cases:
            self.assertEqual(verdict_of(out, unit), want, f"{unit}: {out}")

    # T10 + M4 — PRE_EXISTING만 있는 입력은 확증 제품결함이 아니다 (AC13)
    def test_pre_existing_is_not_a_defect(self):
        rc, out, _ = run_diff(["a"], [("a", "fail", "1")], [("a", "fail", "1")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "PRE_EXISTING")
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "false")

    # /qg iter-1 (pr-test-analyzer, mutation 으로 실측) — DEFECTS 는 두 원소인데
    # NEW_TEST_RED 쪽 플래그만 어디에서도 잠겨 있지 않았다.
    # `DEFECTS = {"NEW_REGRESSION", "NEW_TEST_RED"}` → `{"NEW_REGRESSION"}` 로 줄여도
    # 스위트 전체가 GREEN 이었다. 기존 커버리지는 라벨(:71)·NEW_REGRESSION 의 양성
    # (:494)·PRE_EXISTING 의 음성(위 test_pre_existing_is_not_a_defect)뿐이라
    # NEW_TEST_RED 의 **플래그** 축이 비어 있었다.
    # NEW_TEST_RED = "이번 diff 가 추가한 테스트가 HEAD 에서 실패" 이므로, 빠지면
    # confirmed_product_defect 가 false 가 되고 R8 의 PASS 행이 그대로 충족된다.
    def test_new_test_red_is_a_defect(self):
        rc, out, _ = run_diff(["a"], [("a", "absent", "-")], [("a", "fail", "1")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "NEW_TEST_RED")
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "true")

    # T11 — SILENT_DROP 감지 (AC14)
    def test_silent_drop_flag(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "unrun", "-")])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "silent_drop"), "true")

    # T12 — BASELINE_UNRUNNABLE (AC15)
    def test_baseline_unrunnable_flag(self):
        rc, out, _ = run_diff(["a"], [("a", "unrun", "-")], [("a", "pass", "0")])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "baseline_unrunnable"), "true")
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")

    # T45 + M22 — SILENT_DROP은 --expected 기준으로 계산된다 (AC48).
    # 양측이 **대칭으로** 같은 unit을 빠뜨린 픽스처 — 상호 대조로 계산하면 놓친다.
    def test_symmetric_omission_is_caught(self):
        rc, out, _ = run_diff(["a", "b"], [("a", "pass", "0")], [("a", "pass", "0")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "b"), "SILENT_DROP")
        self.assertEqual(flag_of(out, "silent_drop"), "true")

    # T65 — SILENT_DROP 은 **인증을 막는다** (U1, 라운드 6·7 spec review 이월).
    #
    # `silent_drop` 플래그가 서는 것과 `attribution_status` 가 `degraded` 로 내려가는
    # 것은 **다른 사실**이다. 앞의 둘(T11·T45)은 플래그만 쟀고, 어떤 T/M 도 드롭이
    # 실제로 인증을 막는지 재지 않았다 — R8 PASS 행은 `attribution_status: closed`
    # 를 요구하므로, 플래그만 서고 status 가 `closed` 로 남으면 **영향분으로 고른
    # 것이 HEAD 에서 사라졌는데도 PASS** 가 나온다. 그 경로를 여기서 잠근다.
    #
    # 두 모양 다 확인한다 — head 에서만 빠진 경우와 양측 대칭 누락. 앞의 것만 잠그면
    # 대조 기반 계산으로 되돌리는 회귀(M22 축)가 통과한다.
    def test_silent_drop_blocks_certification(self):
        for label, expected, baseline, head in (
            ("head 에서만 소실", ["a"], [("a", "pass", "0")], [("a", "unrun", "-")]),
            ("양측 대칭 누락", ["a", "b"], [("a", "pass", "0")], [("a", "pass", "0")]),
        ):
            with self.subTest(label):
                rc, out, _ = run_diff(expected, baseline, head)
                self.assertEqual(rc, 0)
                self.assertEqual(flag_of(out, "silent_drop"), "true", out)
                self.assertEqual(flag_of(out, "attribution_status"), "degraded", out)

    # 양의 짝 — 드롭이 없으면 `closed` 여야 한다. 이게 없으면 "언제나 degraded"
    # 로 만드는 mutation 이 위 assert 를 통과한다 (음의 락엔 양의 짝이 필요하다).
    def test_no_silent_drop_still_certifies(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "silent_drop"), "false", out)
        self.assertEqual(flag_of(out, "attribution_status"), "closed", out)

    # T69 — 도말(smear)은 인증을 막는다 (/qg iter-5 SF1, CRITICAL).
    #
    # 실행이 배치(`--mode bulk`)인데 어댑터 입도가 그보다 잘면(`--granularity file`),
    # `run` 은 한 종료 코드를 전 unit 에 찍는다. 양측 red 면 실제 회귀까지
    # `(F,F)=PRE_EXISTING` 으로 접혀 `closed` → PASS 가 됐다. devbrew 자신(shell 130
    # unit + stale red)에선 이게 엣지가 아니라 first-run 기대 상태다.
    #
    # 픽스처는 silent-failure-hunter 가 실측한 것과 같은 모양: 3 unit 전부 양측 fail —
    # 그중 하나는 진짜 pre-existing, 하나는 실제로는 green, 하나는 실제로는 회귀.
    # 대조 단계는 그 셋을 구별할 수 없다. 구별할 수 없다는 사실 자체가 인증 불가 사유다.
    def test_bulk_smear_blocks_certification(self):
        rows_b = [("a", "fail", "1"), ("b", "fail", "1"), ("c", "fail", "1")]
        rows_h = [("a", "fail", "1"), ("b", "fail", "1"), ("c", "fail", "1")]
        rc, out, _ = run_diff(["a", "b", "c"], rows_b, rows_h,
                              granularity="file", runner="shell",
                              baseline_detected="shell", mode="bulk")
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "degraded", out)

    # 양의 짝 ①: 같은 픽스처를 per-unit 으로 돌면 상태가 정직하므로 인증된다.
    # 이게 없으면 "mode 를 아예 안 본다 / 언제나 degraded" mutation 이 통과한다.
    def test_per_unit_same_rows_still_certifies(self):
        rows = [("a", "fail", "1"), ("b", "fail", "1")]
        rc, out, _ = run_diff(["a", "b"], rows, rows,
                              granularity="file", runner="shell",
                              baseline_detected="shell", mode="per-unit")
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "closed", out)

    # 양의 짝 ②: 배치 green 은 도말이 아니다 — 배치 green = 전 unit 통과라 각 행이
    # 정직하다. 여기까지 degrade 하면 stale red 없는 레포에서도 PASS 가 사라진다.
    def test_bulk_green_is_not_smear(self):
        rows = [("a", "pass", "0"), ("b", "pass", "0")]
        rc, out, _ = run_diff(["a", "b"], rows, rows,
                              granularity="file", runner="shell",
                              baseline_detected="shell", mode="bulk")
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "closed", out)

    # 진짜 bulk 어댑터(granularity == mode == bulk)는 기존 절이 이미 담당한다 —
    # 새 절이 그 경로를 이중으로 잡아 의미를 바꾸지 않는지 확인한다.
    def test_true_bulk_adapter_still_degrades_via_existing_clause(self):
        rows = [("BULK", "fail", "101")]
        rc, out, _ = run_diff(["BULK"], rows, rows,
                              granularity="bulk", runner="cargo",
                              baseline_detected="cargo", mode="bulk")
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "degraded", out)

    # `--mode` 는 필수다. 선택 인자로 두고 부재를 per-unit 으로 읽으면, 값을 안 넘긴
    # 호출자(= 배치로 돌린 호출자)가 정확히 이 검사가 막으려던 경로로 통과한다.
    def test_mode_is_required(self):
        rc, _, err = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                              mode=None)
        self.assertEqual(rc, 2)
        self.assertIn("--mode", err)

    # T45(2) — 중복 unit 행은 exit 4 (AC48). 조용한 last-wins는 입력 순서 의존.
    def test_duplicate_unit_row_is_exit_4(self):
        rc, out, _ = run_diff(
            ["a"], [("a", "pass", "0"), ("a", "fail", "1")], [("a", "pass", "0")]
        )
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # T27 + AC36 — error는 fail 축으로 접히고 note에 `(error)`가 병기된다
    def test_error_folds_into_fail_with_note(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "error", "2")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "NEW_REGRESSION")
        self.assertIn("(error)", out)

    # ── /qg iter-2 CRITICAL — 판정 못 한 실행은 인증하지 않는다 ────────────────
    #
    # `error` 는 fail 축으로 접히므로 **양측** error 는 `(F,F)=PRE_EXISTING` 이었고,
    # PRE_EXISTING 은 DEFECTS 밖이라 `closed` → R8 의 PASS 행을 그대로 충족했다.
    # 즉 pytest 가 수집 0개(exit 5)로 끝났거나 import 가 깨졌거나(exit 2) 잘못된 ini
    # 옵션(exit 4)이면 **테스트를 하나도 판정하지 않고 PASS** 였다.
    #
    # 이 락은 라벨(PRE_EXISTING)이 아니라 **인증 여부**를 잰다 — 라벨을 바꾸는 수정은
    # 8종 카테고리 계약(AC11)을 깨고, iter-2 에서 실제로 그 방향의 수정이 더 나쁜
    # 결함을 만들었다.
    def test_error_on_either_axis_blocks_certification(self):
        for label, b, h in (
            ("symmetric", ("a", "error", "5"), ("a", "error", "5")),
            ("baseline",  ("a", "error", "5"), ("a", "pass",  "0")),
            ("head",      ("a", "pass",  "0"), ("a", "error", "5")),
        ):
            with self.subTest(label):
                rc, out, _ = run_diff(["a"], [b], [h])
                self.assertEqual(rc, 0)
                self.assertEqual(flag_of(out, "attribution_status"), "degraded",
                                 f"{label}: {out}")
        # 양성 짝 — error 가 없으면 같은 형상이 closed 다. 이것이 없으면 위 assert 는
        # "언제나 degraded" 로 통과한다 (부재 락에는 소비-위치 양성 짝이 필요하다).
        rc, out, _ = run_diff(["a"], [("a", "fail", "1")], [("a", "fail", "1")])
        self.assertEqual(flag_of(out, "attribution_status"), "closed", out)

    # 위 강화가 **비대칭 방향을 죽이지 않았음**을 잠근다. iter-2 에서 내가 낸 회귀가
    # 정확히 이 방향이었다 — "이 diff 가 import 를 깼다"를 비차단으로 내려보냈다.
    # degrade 는 인증을 막을 뿐 확증 결함을 결함이 아닌 것으로 만들지 않는다.
    def test_error_degrade_does_not_swallow_the_regression(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "error", "2")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "NEW_REGRESSION")
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "true", out)

    # ── /qg iter-2 CRITICAL — 기준선 행은 그 어댑터가 merge_base 에 실재할 때만 증거 ──
    #
    # 심어진 캐시 `pass` 로 R4① 이 전량 적중이 되면 조건부 R4②가 기준선 워크트리를
    # 만들지 않는다. merge_base 에 어댑터가 없어 원래 전량 `unrun` →
    # BASELINE_UNRUNNABLE → PASS 불가였던 실행이 STILL_GREEN → closed → PASS 가 된다.
    # §5.4 의 비대칭 표는 실제값이 pass/fail 인 줄만 셌기 때문에 이 줄을 놓쳤다 —
    # 결함 축이 아니라 **인증 축**이라 `fail` 전용 재검증이 닿지 않는다.
    def test_ungrounded_runner_forces_baseline_axis_unrun(self):
        # 정확히 그 공격 형상: 양측 pass (심어진 기준선 + 진짜 HEAD green).
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                              runner="pytest", baseline_detected="go")
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "BASELINE_UNRUNNABLE", out)
        self.assertEqual(flag_of(out, "baseline_unrunnable"), "true")
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")
        self.assertIn("어댑터 pytest 없음", out)
        # 양성 짝 — 같은 입력이 grounded 면 STILL_GREEN/closed 다.
        rc2, out2, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                                runner="pytest", baseline_detected="pytest")
        self.assertEqual(rc2, 0)
        self.assertEqual(verdict_of(out2, "a"), "STILL_GREEN", out2)
        self.assertEqual(flag_of(out2, "attribution_status"), "closed")

    # 러너 이름은 **부분문자열이 아니라 원소**로 대조한다. `pytest` 가 감지되지
    # 않았는데 `pytest-asyncio` 같은 이름이 집합에 있다고 grounded 가 되면 안 된다.
    def test_grounding_is_set_membership_not_substring(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                              runner="test", baseline_detected="pytest vitest")
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "BASELINE_UNRUNNABLE", out)

    # `NONE` 센티널 = 기준선 트리에서 감지 0개 (또는 R-init 이 degraded/same_as_head
    # 로 R4 를 통째로 건너뜀). 어떤 러너도 grounded 가 아니다.
    def test_none_sentinel_grounds_nothing(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                              baseline_detected="NONE")
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "BASELINE_UNRUNNABLE", out)

    # **이 플래그의 이빨은 필수성에 있다.** 선택 인자로 두고 부재를 "전부 감지됨"
    # 으로 읽으면, 값을 못 구한 호출자(= 기준선 트리를 안 만든 호출자)가 정확히 이
    # 검사가 막으려던 경로로 통과한다.
    def test_baseline_detected_is_required(self):
        rc, out, err = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                                baseline_detected=None)
        self.assertEqual(rc, 2, out)
        self.assertIn("--baseline-detected", err)

    # 빈 문자열도 통과시키지 않는다 — "감지 0개"는 `NONE` 으로 **명시**해야 한다.
    def test_empty_baseline_detected_is_exit_4(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")],
                              baseline_detected="   ")
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # T13 + AC16 — degrade 경로의 라벨에는 `_SUSPECT` 접미사가 붙는다
    def test_degrade_labels_carry_suspect_suffix(self):
        rc, out, _ = run_diff(["a"], [("a", "unrun", "-")], [("a", "fail", "1")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "BASELINE_UNRUNNABLE")
        self.assertIn("_SUSPECT", out)

    # T39 + AC43 — bulk에서 PRE_EXISTING이 나오면 원장 차원이 degraded.
    # 귀속 **카테고리**는 8종 밖으로 나가지 않는다.
    def test_bulk_pre_existing_degrades_ledger_not_category(self):
        rc, out, _ = run_diff(
            ["BULK"], [("BULK", "fail", "1")], [("BULK", "fail", "1")],
            granularity="bulk", runner="cargo",
        )
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "BULK"), "PRE_EXISTING")
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")
        # file granularity의 같은 입력은 closed
        rc2, out2, _ = run_diff(["a"], [("a", "fail", "1")], [("a", "fail", "1")])
        self.assertEqual(rc2, 0)
        self.assertEqual(flag_of(out2, "attribution_status"), "closed")

    # 알 수 없는 상태값은 조용히 통과하지 않는다
    def test_unknown_status_is_exit_4(self):
        rc, out, _ = run_diff(["a"], [("a", "weird", "0")], [("a", "pass", "0")])
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # Finding 3 — 입력 파일 부재는 파싱 실패다: 처리 안 된 OSError로 exit 1이 새면
    # 오케스트레이터의 0/2/4 분기가 미분류 크래시를 받는다. exit 4 + 빈 stdout이어야 한다.
    def test_missing_baseline_file_is_exit_4(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            (p / "e.txt").write_text("a\n", encoding="utf-8")
            (p / "h.tsv").write_text("a\tpass\t0\n", encoding="utf-8")
            r = subprocess.run(
                [sys.executable, str(SCRIPT),
                 "--expected", str(p / "e.txt"),
                 "--baseline", str(p / "missing.tsv"),
                 "--head", str(p / "h.tsv"),
                 "--granularity", "file", "--mode", "per-unit", "--runner", "pytest",
                 "--baseline-detected", "pytest"],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 4)
        self.assertEqual(r.stdout.strip(), "")

    # Finding 1 — 빈 --expected는 attributions: null이 아니라 attributions: []을
    # 낸다. bare `attributions:` 다음 줄이 `attribution_status:`이면 YAML 소비자가
    # `None`을 받아 `for a in doc["attributions"]:`가 TypeError로 죽는다.
    def test_empty_expected_emits_empty_attributions_list(self):
        rc, out, err = run_diff([], [], [])
        self.assertEqual(rc, 0, err)
        self.assertIn("attributions: []", out)
        self.assertNotIn("attributions:\n", out)
        self.assertIn(
            "counts: {still_green: 0, new_regression: 0, pre_existing: 0, "
            "fixed: 0, new_test_green: 0, new_test_red: 0, silent_drop: 0, "
            "baseline_unrunnable: 0}",
            out,
        )
        for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
            self.assertEqual(flag_of(out, key), "false", key)

    # Finding 2 — yaml_str은 \n \r \t를 이스케이프해 한 줄을 유지해야 한다.
    # 이 세 문자는 splitlines() 기반 입력 파싱(--expected/TSV 둘 다)을 통해서는
    # 구조적으로 unit 값에 도달할 수 없다(줄 경계 자체이므로 파싱 단계에서
    # 이미 잘린다) — 그래서 이 테스트는 CLI 왕복이 아니라 순수 함수를 직접
    # 호출해 이스케이프 로직 자체를 검증한다(디펜스-인-뎁스: 이 스크립트가
    # 아닌 다른 생산자가 같은 함수를 재사용할 미래를 가정).
    def test_yaml_str_escapes_control_chars(self):
        mod = load_module()
        raw = "a\nb\tc\rd"
        escaped = mod.yaml_str(raw)
        # 결과 자체가 물리적으로 한 줄이어야 한다 — 라인-지향 파서(Task 7)가
        # 값 중간에서 줄이 갈라지면 안 된다.
        self.assertEqual(len(escaped.splitlines()), 1)
        self.assertEqual(escaped, '"a\\nb\\tc\\rd"')
        # 왕복: 이스케이프를 손으로 되돌리면 원본과 같아야 한다.
        body = escaped[1:-1]
        roundtrip = (
            body.replace("\\t", "\t")
            .replace("\\r", "\r")
            .replace("\\n", "\n")
            .replace('\\"', '"')
            .replace("\\\\", "\\")
        )
        self.assertEqual(roundtrip, raw)

    # Finding 3a — 한쪽만 빠진 행(baseline에만 없음)도 SILENT_DROP이어야 한다.
    # 기존 test_symmetric_omission_is_caught은 양쪽 다 없는 경우만 본다.
    def test_one_sided_missing_row_baseline_only(self):
        rc, out, _ = run_diff(["a"], [], [("a", "pass", "0")])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "SILENT_DROP")

    # Finding 3a(2) — head에만 없는 반대 방향.
    def test_one_sided_missing_row_head_only(self):
        rc, out, _ = run_diff(["a"], [("a", "pass", "0")], [])
        self.assertEqual(rc, 0)
        self.assertEqual(verdict_of(out, "a"), "SILENT_DROP")

    # Finding 3b — read_text_or_fail4는 baseline/head/expected 셋이 공유하는
    # 헬퍼다. 기존 케이스는 --baseline 부재만 봤다 — 나머지 둘도 같은 계약을
    # 지키는지 개별 확인(미래 리팩터가 한쪽만 특별취급해도 안 새게).
    def test_missing_head_file_is_exit_4(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            (p / "e.txt").write_text("a\n", encoding="utf-8")
            (p / "b.tsv").write_text("a\tpass\t0\n", encoding="utf-8")
            r = subprocess.run(
                [sys.executable, str(SCRIPT),
                 "--expected", str(p / "e.txt"),
                 "--baseline", str(p / "b.tsv"),
                 "--head", str(p / "missing.tsv"),
                 "--granularity", "file", "--mode", "per-unit", "--runner", "pytest",
                 "--baseline-detected", "pytest"],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 4)
        self.assertEqual(r.stdout.strip(), "")

    def test_missing_expected_file_is_exit_4(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d)
            (p / "b.tsv").write_text("a\tpass\t0\n", encoding="utf-8")
            (p / "h.tsv").write_text("a\tpass\t0\n", encoding="utf-8")
            r = subprocess.run(
                [sys.executable, str(SCRIPT),
                 "--expected", str(p / "missing.txt"),
                 "--baseline", str(p / "b.tsv"),
                 "--head", str(p / "h.tsv"),
                 "--granularity", "file", "--mode", "per-unit", "--runner", "pytest",
                 "--baseline-detected", "pytest"],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 4)
        self.assertEqual(r.stdout.strip(), "")


def write_adapter_yaml(path: Path, runner, defect, drop, unrunnable, status="closed"):
    """per-adapter 모드가 실제로 내는 출력 형상 그대로 재현한 픽스처.

    `counts`는 per_adapter()가 flow-mapping 한 줄로 emit한다 (scripts/diff-test-
    results.py의 `# counts는 flow-mapping...` 주석 참고) — block 스타일(2칸
    들여쓰기 키:값 줄마다)로 쓰면 이 스크립트가 실제로 만드는 출력과 다른 것을
    파싱하는 셈이라 회귀를 못 잡는다. 8개 카테고리 전부를 채운다 — 집계 파서가
    누락된 카테고리를 exit 4로 잡는지 다른 테스트가 확인한다.
    """
    counts_body = ", ".join([
        "still_green: 0",
        f"new_regression: {1 if defect else 0}",
        "pre_existing: 0",
        "fixed: 0",
        "new_test_green: 0",
        "new_test_red: 0",
        "silent_drop: 0",
        "baseline_unrunnable: 0",
    ])
    path.write_text(
        f"runner: {runner}\n"
        "attributions: []\n"
        f"attribution_status: {status}\n"
        f"counts: {{{counts_body}}}\n"
        "verdict_input:\n"
        f"  confirmed_product_defect: {'true' if defect else 'false'}\n"
        f"  silent_drop: {'true' if drop else 'false'}\n"
        f"  baseline_unrunnable: {'true' if unrunnable else 'false'}\n",
        encoding="utf-8",
    )


def run_aggregate(specs, expected_adapters=None, extra_args=None):
    """specs: [(runner, defect, drop, unrunnable, status)] → (rc, stdout, stderr)"""
    with tempfile.TemporaryDirectory() as d:
        p = Path(d)
        files = []
        for i, (runner, defect, drop, unrunnable, status) in enumerate(specs):
            f = p / f"{i}.yaml"
            write_adapter_yaml(f, runner, defect, drop, unrunnable, status)
            files.append(str(f))
        n = len(specs) if expected_adapters is None else expected_adapters
        r = subprocess.run(
            [sys.executable, str(SCRIPT), "--aggregate", "--expected-adapters", str(n)]
            + files + (extra_args or []),
            capture_output=True, text=True,
        )
    return r.returncode, r.stdout, r.stderr


class TestAggregate(unittest.TestCase):
    # T53 — 어댑터 A 회귀 + B green → confirmed_product_defect: true (AC55)
    def test_one_adapter_regression_makes_the_whole_run_a_defect(self):
        rc, out, err = run_aggregate([
            ("pytest", True, False, False, "closed"),
            ("shell", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 0, err)
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "true")
        self.assertIn("pytest", out)
        self.assertIn("shell", out)

    # T53(2) + M25 — 입력 YAML 개수 부족 → exit 4, 남은 것만 낙관적으로 합치지 않는다
    def test_missing_adapter_yaml_is_exit_4(self):
        rc, out, _ = run_aggregate(
            [("pytest", False, False, False, "closed")], expected_adapters=2
        )
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # 같은 runner의 YAML이 두 번 오면 한 어댑터가 빠진 것을 개수로 못 잡는다 → exit 4
    def test_duplicate_runner_is_exit_4(self):
        rc, out, _ = run_aggregate([
            ("pytest", False, False, False, "closed"),
            ("pytest", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 4)
        self.assertEqual(out.strip(), "")

    # T26 + AC35 — 확증 회귀와 SILENT_DROP이 **동시** 성립해도 둘 다 살아남는다.
    # degrade 사실이 확증 결함에 삼켜지지 않고, 확증 결함이 degrade로 downgrade되지도
    # 않는다. §5.7 우선순위 표는 이 두 플래그를 함께 받아야 성립한다.
    def test_defect_and_degrade_are_both_reported(self):
        rc, out, _ = run_aggregate([
            ("pytest", True, False, False, "closed"),
            ("shell", False, True, False, "closed"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "true")
        self.assertEqual(flag_of(out, "silent_drop"), "true")

    # 어느 한 어댑터라도 degraded면 집계도 degraded (구조적 보장이 없으면 인증 없음)
    def test_degraded_propagates(self):
        rc, out, _ = run_aggregate([
            ("pytest", False, False, False, "closed"),
            ("cargo", False, False, False, "degraded"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "degraded")

    # 어느 어댑터도 degraded가 아니면 집계도 closed — degraded_propagates의 대칭
    # (양방향 확인 없으면 "OR"가 아니라 "항상 degraded"로 회귀해도 못 잡는다).
    def test_all_closed_stays_closed(self):
        rc, out, _ = run_aggregate([
            ("pytest", False, False, False, "closed"),
            ("cargo", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "attribution_status"), "closed")

    # 모든 어댑터가 green이면 confirmed_product_defect도 false — OR 병합이
    # "누구든 회귀면 true"이지 "항상 true"로 고정 회귀해도 못 잡는 것을 막는다.
    def test_all_green_is_not_a_defect(self):
        rc, out, _ = run_aggregate([
            ("pytest", False, False, False, "closed"),
            ("shell", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 0)
        self.assertEqual(flag_of(out, "confirmed_product_defect"), "false")
        self.assertEqual(flag_of(out, "silent_drop"), "false")
        self.assertEqual(flag_of(out, "baseline_unrunnable"), "false")

    # per_adapter 블록이 실제로 어댑터별 counts를 실어나른다 (값 캡처만 하고
    # 끝나면 회귀를 못 잡는다 — 값 자체를 assert한다).
    def test_per_adapter_counts_are_reported(self):
        rc, out, _ = run_aggregate([
            ("pytest", True, False, False, "closed"),
            ("shell", False, False, False, "closed"),
        ])
        self.assertEqual(rc, 0)
        self.assertIn("pytest: {baseline_unrunnable: 0, fixed: 0, new_regression: 1, "
                       "new_test_green: 0, new_test_red: 0, pre_existing: 0, "
                       "silent_drop: 0, still_green: 0}", out)
        self.assertIn("shell: {baseline_unrunnable: 0, fixed: 0, new_regression: 0, "
                       "new_test_green: 0, new_test_red: 0, pre_existing: 0, "
                       "silent_drop: 0, still_green: 0}", out)

    # 형상이 깨진 YAML은 조용히 무시되지 않는다
    def test_malformed_yaml_is_exit_4(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "bad.yaml"
            f.write_text("runner: pytest\n(garbage)\n", encoding="utf-8")
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--aggregate",
                 "--expected-adapters", "1", str(f)],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 4)
        self.assertEqual(r.stdout.strip(), "")

    # counts 블록이 카테고리 하나를 빠뜨리면(예: 손상된 상류 어댑터 출력) 0으로
    # 조용히 메우지 않고 exit 4 — 그 카테고리의 회귀가 집계에서 사라지는 것을 막는다.
    def test_incomplete_counts_block_is_exit_4(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "bad.yaml"
            f.write_text(
                "runner: pytest\n"
                "attributions: []\n"
                "attribution_status: closed\n"
                "counts: {still_green: 0, new_regression: 1}\n"
                "verdict_input:\n"
                "  confirmed_product_defect: true\n"
                "  silent_drop: false\n"
                "  baseline_unrunnable: false\n",
                encoding="utf-8",
            )
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--aggregate",
                 "--expected-adapters", "1", str(f)],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 4)
        self.assertEqual(r.stdout.strip(), "")

    # --expected-adapters 없이 --aggregate만 주면 사용 오류(exit 2) — 입력 검증
    # 실패(exit 4)와 구별된다.
    def test_aggregate_without_expected_adapters_is_exit_2(self):
        with tempfile.TemporaryDirectory() as d:
            f = Path(d) / "a.yaml"
            write_adapter_yaml(f, "pytest", False, False, False)
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--aggregate", str(f)],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 2)

    # `--expected-adapters 0` + 입력 0개는 **legal 하지만 인증은 아니다.**
    #
    # 이 케이스는 원래 `attribution_status: closed` 를 단언했다 — "이 선택을 의도된
    # 것으로 기록해 우연이 아니게 한다" 는 주석과 함께. /qg iter-3 에서 리뷰어 둘이
    # 독립적으로 그 단언이 **fail-open 을 계약으로 못 박고 있었다**고 보고했다:
    # `closed` + 3플래그 전부 false 는 R8 PASS 행의 결정론 조건을 **전부** 충족하므로,
    # 8종 어댑터를 하나도 지원하지 않는 레포(Ruby/Java 등)가 테스트를 한 개도 돌리지
    # 않고 PASS 를 받는다. 그것을 막던 유일한 것은 SKILL.md 의 한국어 문장이었다.
    #
    # 형상(exit 0 · `adapters: []` · `per_adapter: {}` — bare `per_adapter:` 는 YAML
    # null 이 되는 함정)은 그대로 유지한다. 바뀌는 것은 **인증 여부 하나**다.
    def test_zero_adapters_is_legal_but_not_certified(self):
        rc, out, err = run_aggregate([], expected_adapters=0)
        self.assertEqual(rc, 0, err)
        self.assertIn("adapters: []", out)
        self.assertIn("per_adapter: {}", out)
        self.assertNotIn("per_adapter:\n", out)
        for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
            self.assertEqual(flag_of(out, key), "false", key)
        self.assertEqual(flag_of(out, "attribution_status"), "degraded", out)

    # 양의 짝 — 어댑터가 하나라도 있으면 같은 all-green 입력이 `closed` 다.
    # 없으면 위 assert 는 "언제나 degraded" 로 통과한다.
    def test_nonzero_adapters_all_green_still_certifies(self):
        rc, out, err = run_aggregate(
            [("pytest", False, False, False, "closed")], expected_adapters=1
        )
        self.assertEqual(rc, 0, err)
        self.assertEqual(flag_of(out, "attribution_status"), "closed", out)

    # per-adapter 축의 같은 규칙 — 빈 `--expected` 는 판정 0건이므로 인증 불가.
    def test_empty_expected_is_not_certified(self):
        rc, out, _ = run_diff([], [], [])
        self.assertEqual(rc, 0)
        self.assertIn("attributions: []", out)
        self.assertEqual(flag_of(out, "attribution_status"), "degraded", out)
        # 양의 짝 — unit 이 하나라도 있고 초록이면 closed.
        rc2, out2, _ = run_diff(["a"], [("a", "pass", "0")], [("a", "pass", "0")])
        self.assertEqual(rc2, 0)
        self.assertEqual(flag_of(out2, "attribution_status"), "closed", out2)


def write_real_adapter_yaml(d, runner, expected, baseline, head, granularity="file"):
    """`write_adapter_yaml`과 달리 손으로 형상을 재현하지 않는다 — `run_diff`를 통해
    per-adapter 모드를 실제로 실행하고, 그 진짜 stdout을 파일에 그대로 옮겨 적는다.

    2026-08-02 리뷰 Finding 1: brief의 파서와 brief의 픽스처는 같은(틀린) 가정을
    공유해서 서로 맞아떨어졌다 — 픽스처 기반 `TestAggregate`만으로는 프로듀서
    포맷이 바뀌어도 손으로 쓴 `write_adapter_yaml`은 따라 바뀌지 않으므로 desync를
    구조적으로 못 잡는다. 이 헬퍼는 그 결합을 끊는다: 픽스처가 아니라 진짜
    프로듀서(및 그 CLI 계약)를 통해 입력을 만든다.
    """
    rc, out, err = run_diff(expected, baseline, head, granularity=granularity, runner=runner)
    assert rc == 0, f"real per-adapter invocation failed for {runner}: {err}"
    f = Path(d) / f"{runner}.yaml"
    f.write_text(out, encoding="utf-8")
    return str(f)


class TestAggregateRealProducer(unittest.TestCase):
    """`--aggregate`를 손으로 쓴 픽스처가 아니라 실제 per-adapter 모드가 emit한
    YAML로 먹인다 (리뷰 Finding 1). `write_adapter_yaml` 기반 `TestAggregate`는
    프로듀서 포맷 자체의 회귀(가령 `counts` flow-mapping의 콜론 뒤 공백이
    사라지는 변경)에는 눈이 멀어 있다 — 픽스처가 프로듀서 코드와 독립적으로
    같은 문자열을 손으로 유지하기 때문이다. 이 클래스는 그 사각을 없앤다.
    """

    # 두 실제 어댑터 — 하나는 NEW_REGRESSION, 하나는 전부 green.
    def test_real_producer_regression_plus_green_is_defect_true(self):
        with tempfile.TemporaryDirectory() as d:
            f1 = write_real_adapter_yaml(
                d, "pytest", ["a"], [("a", "pass", "0")], [("a", "fail", "1")]
            )
            f2 = write_real_adapter_yaml(
                d, "shell", ["b"], [("b", "pass", "0")], [("b", "pass", "0")]
            )
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--aggregate",
                 "--expected-adapters", "2", f1, f2],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(flag_of(r.stdout, "confirmed_product_defect"), "true")
        self.assertIn("pytest", r.stdout)
        self.assertIn("shell", r.stdout)

    # 두 실제 어댑터 모두 green — false/closed 방향도 실제 프로듀서 출력으로 확인
    # (한쪽 방향만 real-producer로 확인하면 "항상 true"로 깨져도 못 잡는다).
    def test_real_producer_all_green_is_defect_false(self):
        with tempfile.TemporaryDirectory() as d:
            f1 = write_real_adapter_yaml(
                d, "pytest", ["a"], [("a", "pass", "0")], [("a", "pass", "0")]
            )
            f2 = write_real_adapter_yaml(
                d, "shell", ["b"], [("b", "pass", "0")], [("b", "pass", "0")]
            )
            r = subprocess.run(
                [sys.executable, str(SCRIPT), "--aggregate",
                 "--expected-adapters", "2", f1, f2],
                capture_output=True, text=True,
            )
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(flag_of(r.stdout, "confirmed_product_defect"), "false")
        self.assertEqual(flag_of(r.stdout, "attribution_status"), "closed")


if __name__ == "__main__":
    unittest.main()
