#!/usr/bin/env python3
"""diff-test-results.py — 짝짓기 · 귀속 · 집계와 verdict.py 로 가는 출력 계약.

요구: R1 · R2 · R5 · R7 · R8 · R9 · R10 · R12 · R13 · R15 · R16 · R17 · R19 · R24
(docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md §요구 목록 · R24 의 새 뜻은
docs/superpowers/specs/2026-10-20-review-engine-leftovers-design.md §7)
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

    def test_R2_NEW_TEST_RED_is_defect(self):
        # 기준선에 없던 테스트가 HEAD 에서 빨강 — 결함이고 차등 새 실패 칸에 센다(P12 · K-3).
        self.pair("shell", [("n.sh", "absent", "-", "per-unit")], [("n.sh", "fail", "1", "per-unit")])
        p = self.run_diff()
        self.assertEqual(p.returncode, 0, p.stderr)
        self.assertEqual(self.verdict_of(p.stdout, "n.sh"), "NEW_TEST_RED")
        self.assertIn("confirmed_product_defect: true", p.stdout)
        self.assertEqual(self.field(p.stdout, "new_failures"), "1")
        (self.memo / "diff.yaml").write_text(p.stdout, encoding="utf-8")
        v = subprocess.run([sys.executable, str(VERDICT), "--differential", str(self.memo / "diff.yaml")],
                           capture_output=True, text=True)
        self.assertEqual(v.stdout.splitlines()[0], "verdict: defect")

    def test_R2_error_on_head_only_blocks_certification(self):
        self.pair("shell", [("t.sh", "fail", "1", "per-unit")], [("t.sh", "error", "2", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.field(p.stdout, "attribution_status"), "degraded")
        self.assertIn("error-axis", self.field(p.stdout, "degrade_causes"))

    def test_R2_error_on_baseline_only_blocks_certification(self):
        self.pair("shell", [("t.sh", "error", "2", "per-unit")], [("t.sh", "pass", "0", "per-unit")])
        p = self.run_diff()
        self.assertEqual(self.field(p.stdout, "attribution_status"), "degraded")
        self.assertIn("error-axis", self.field(p.stdout, "degrade_causes"))

    def test_R9_mixed_mode_baseline_bulk_head_per_unit_is_smeared(self):
        self.pair("shell", [("a.sh", "fail", "1", "bulk")], [("a.sh", "fail", "1", "per-unit")])
        self.assertIn("smeared", self.field(self.run_diff().stdout, "degrade_causes"))

    def test_R9_mixed_mode_baseline_per_unit_head_bulk_is_smeared(self):
        self.pair("shell", [("a.sh", "fail", "1", "per-unit")], [("a.sh", "fail", "1", "bulk")])
        self.assertIn("smeared", self.field(self.run_diff().stdout, "degrade_causes"))

    def test_R9_positive_control_both_per_unit_is_not_smeared(self):
        self.pair("shell", [("a.sh", "fail", "1", "per-unit")], [("a.sh", "fail", "1", "per-unit")])
        self.assertNotIn("smeared", self.field(self.run_diff().stdout, "degrade_causes"))

    def test_R15_baseline_rows_file_with_flaky_trailer_is_exit_4(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        base = self.memo / "baseline-shell.tsv"
        base.write_text(base.read_text(encoding="utf-8").replace("flaky=0", "flaky=1"), encoding="utf-8")
        p = self.run_diff()
        self.assertEqual(p.returncode, 4)
        self.assertIn("flaky", p.stderr)

    def test_R7_duplicate_unit_in_assign_is_exit_4(self):
        write_assign(self.memo, [("a.sh", "shell", "file"), ("a.sh", "shell", "file")])
        write_rows(self.memo / "baseline-shell.tsv", "shell", self.repo.B, [("a.sh", "pass", "0", "per-unit")])
        write_rows(self.memo / "head-shell-i1.tsv", "shell", self.repo.H, [("a.sh", "pass", "0", "per-unit")])
        self.assertEqual(self.run_diff().returncode, 4)

    def test_rows_path_check_oserror_and_missing_git_are_exit_4_not_1(self):
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        # git 을 못 부르는 환경(PATH 비움) — 예외가 새지 않고 계약 위반 exit 4 다.
        argv = [sys.executable, str(DIFF), "--assign", str(self.memo / "assign-i1.tsv"),
                "--rows", str(self.memo), "--iter", "1",
                "--baseline-commit", self.repo.B, "--head-commit", self.repo.H]
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", PATH="/nonexistent")
        p = subprocess.run(argv, cwd=self.repo.root, capture_output=True, text=True, env=env)
        self.assertEqual(p.returncode, 4, p.stderr)
        self.assertNotIn("Traceback", p.stderr)
        # 행 파일 경로가 OSError 를 내는 경우 — 너무 긴 이름(ENAMETOOLONG).
        argv[argv.index("--rows") + 1] = str(self.memo / ("x" * 5000))
        p = subprocess.run(argv, cwd=self.repo.root, capture_output=True, text=True,
                           env=dict(os.environ, PYTHONDONTWRITEBYTECODE="1"))
        self.assertEqual(p.returncode, 4, p.stderr)
        self.assertNotIn("Traceback", p.stderr)

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

    def test_R17_trailer_values_as_strict_as_the_producer(self):
        # 생산자(run-test-selection.sh)가 거부하는 꼬리 값은 소비자도 거부한다 — 더 너그럽지 않다.
        self.pair("shell", [("a.sh", "pass", "0", "per-unit")], [("a.sh", "pass", "0", "per-unit")])
        head = self.memo / "head-shell-i1.tsv"
        good = head.read_text(encoding="utf-8")
        for bad in (good.replace("flaky=0", "flaky=2"), good.replace("flaky=0", "flaky="),
                    good.replace("runner=shell", "runner="), good.replace(self.repo.H, "zzz")):
            head.write_text(bad, encoding="utf-8")
            self.assertEqual(self.run_diff().returncode, 4, bad)

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
    """R24 — 판정 인자는 숫자를 만든 직후의 펜스가 낸 줄의 글자 그대로다: 진짜 run → diff →
    verdict.py --emit-args(차등 결과 줄) → 판정 줄을 전사 없이 잇는다."""

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

    def test_R24_real_producer_output_reaches_verdict_through_the_args_line(self):
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
        # D5 펜스 끝의 차등 결과 줄 — 판정 펜스는 이 줄의 낱말을 그대로 넘긴다.
        a = subprocess.run([sys.executable, str(VERDICT), "--emit-args", "--differential",
                            str(self.memo / "diff-i1.yaml")], capture_output=True, text=True)
        self.assertEqual(a.returncode, 0, a.stderr)
        line = a.stdout.rstrip("\n")
        self.assertTrue(line.startswith("qg-verdict-args: --new-failures 1 --defect"), line)
        f = subprocess.run([sys.executable, str(VERDICT), "--line", "--blocking", "0", "--optional", "0",
                            *line[len("qg-verdict-args: "):].split(), "--excluded", "0", "--iter", "1",
                            "--sha", "abc1234"], capture_output=True, text=True)
        self.assertEqual(f.returncode, 0, f.stderr)
        self.assertEqual(f.stdout.splitlines()[0], "verdict: defect")
        self.assertIn(" · 차등 새 실패 1 · ", f.stdout.splitlines()[-1])

    def test_R24_truncated_output_cannot_reach_clean(self):
        # 잘린 출력은 verdict.py 가 판정하지 않는다 — clean 으로 새는 길이 없다.
        (self.memo / "cut.yaml").write_text("adapters: [shell]\nverdict_input:\n", encoding="utf-8")
        v = subprocess.run([sys.executable, str(VERDICT), "--differential", str(self.memo / "cut.yaml")],
                           capture_output=True, text=True)
        self.assertEqual(v.returncode, 4)


if __name__ == "__main__":
    unittest.main()
