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


if __name__ == "__main__":
    unittest.main()
