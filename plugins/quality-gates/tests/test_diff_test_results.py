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


def run_diff(expected, baseline, head, granularity="file", runner="pytest"):
    """expected: [unit], baseline/head: [(unit, status, code)] → (rc, stdout, stderr)"""
    with tempfile.TemporaryDirectory() as d:
        p = Path(d)
        (p / "e.txt").write_text("\n".join(expected) + "\n", encoding="utf-8")
        for name, rows in (("b.tsv", baseline), ("h.tsv", head)):
            (p / name).write_text(
                "".join(f"{u}\t{s}\t{c}\n" for u, s, c in rows), encoding="utf-8"
            )
        r = subprocess.run(
            [sys.executable, str(SCRIPT),
             "--expected", str(p / "e.txt"),
             "--baseline", str(p / "b.tsv"),
             "--head", str(p / "h.tsv"),
             "--granularity", granularity, "--runner", runner],
            capture_output=True, text=True,
        )
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
                 "--granularity", "file", "--runner", "pytest"],
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
                 "--granularity", "file", "--runner", "pytest"],
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
                 "--granularity", "file", "--runner", "pytest"],
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

    # 리뷰 Finding 2 — `--expected-adapters 0`에 입력 파일 0개는 legal한 경계로
    # 명시 취급한다(설계·brief 둘 다 이 경계를 언급하지 않는다). exit 0, 빈
    # `adapters: []`, `per_adapter: {}`(bare `per_adapter:`는 YAML null이 됨 —
    # `attributions: []`와 같은 함정, 위 `_aggregate`의 주석 참고) — 이 선택을
    # 의도된 것으로 기록해 우연이 아니게 한다.
    def test_zero_adapters_is_a_legal_empty_result(self):
        rc, out, err = run_aggregate([], expected_adapters=0)
        self.assertEqual(rc, 0, err)
        self.assertIn("adapters: []", out)
        self.assertIn("per_adapter: {}", out)
        self.assertNotIn("per_adapter:\n", out)
        for key in ("confirmed_product_defect", "silent_drop", "baseline_unrunnable"):
            self.assertEqual(flag_of(out, key), "false", key)
        self.assertEqual(flag_of(out, "attribution_status"), "closed")


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
