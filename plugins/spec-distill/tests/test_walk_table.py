#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""walk_table.py — 기본 걸음표 · 읽기 · 검사(AC1).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_walk_table.py
"""
from __future__ import annotations

import ast
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import walk_table as W  # noqa: E402

GOOD = (W.DEFAULT_TABLE).read_text(encoding="utf-8")


def swap(text, old, new):
    assert old in text, old
    return text.replace(old, new, 1)


class DefaultTable(unittest.TestCase):   # AC1
    def test_two_tables_and_the_design_rows(self):
        t = W.parse(GOOD, "기본")
        self.assertEqual(sorted(t), sorted([W.team_status.DESIGN_FLOW, W.team_status.PLAIN_FLOW]))
        self.assertEqual([s.name for s in t[W.team_status.DESIGN_FLOW]],
                         ["방향 확인", "설계 대화", "설계 검토", "설계 승인", "계획", "계획 확인", "구현", "검수", "PR 전 확인", "머지", "회고"])
        self.assertEqual([s.name for s in t[W.team_status.PLAIN_FLOW]], ["방향 확인", "진행", "결과 확인"])
        rows = {s.name: s for s in t[W.team_status.DESIGN_FLOW]}
        self.assertEqual(rows["계획"][1:7], ("worker", "plan", "—", "superpowers:writing-plans", "—", "—"))
        self.assertEqual(rows["설계 승인"].gate, "spec 승인")
        self.assertEqual(rows["계획 확인"].gate, "계획 검토")
        self.assertEqual(rows["구현"].method, "superpowers:subagent-driven-development")
        self.assertEqual(rows["검수"].tool, "spec-distill:integration-reviewer · quality-gates:quality-pipeline")
        self.assertEqual(rows["회고"].tool, "spec-distill:relay-checker")
        self.assertEqual(t[W.team_status.PLAIN_FLOW][0].gate, "흐름 승인")
        self.assertEqual(W.ANCHORS[W.team_status.DESIGN_FLOW], tuple(s.name for s in t[W.team_status.DESIGN_FLOW]))
        self.assertEqual(W.missing_anchors(t), [])

    def test_the_file_is_only_a_title_two_headings_and_tables(self):   # 자기 설명 글이 없다
        for line in GOOD.splitlines():
            self.assertTrue(line == "" or line.startswith("|") or line in ("# 걸음표", "## 설계 흐름", "## 설계 없는 흐름"), line)


class Broken(unittest.TestCase):   # AC1 — 줄을 짚고 멈춘다
    def bad(self, text, *words):
        with self.assertRaises(W.TableError) as cm:
            W.parse(text, "t.md")
        for w in words:
            self.assertIn(w, str(cm.exception))

    def test_stage_and_gate_cells(self):
        self.bad(swap(GOOD, "| worker | plan |", "| worker | build |"), "t.md:", "행", "build")
        self.bad(swap(GOOD, "| spec 승인 |", "| 설계 승인 줄 |"), "t.md:", "설계 승인 줄")

    def test_shape(self):
        self.bad(swap(GOOD, "| 작업 방식 |", "| 방식 |"), "머리")                                   # 머리 행
        self.bad(swap(GOOD, "| 회고 | leader | — |", "| 회고 | leader |"), "칸")                    # 칸 수
        self.bad(GOOD.replace("## 설계 없는 흐름", "## 설계 없는 흐름 그리고"), "설계 없는 흐름")       # 절이 없다(제목은 글자 그대로)
        self.bad(GOOD + "\n## 설계 흐름\n", "설계 흐름")                                             # 절이 둘
        self.bad(swap(GOOD, "| 회고 |", "| 머지 |"), "머지")                                          # 이름 겹침

    def test_tolerated_noise(self):   # Review Focus 1 — 양성 대조
        noisy = GOOD.replace("\n", "\r\n").replace("| 계획 | worker |", "|  계획  |worker|")
        noisy = noisy.replace("## 설계 흐름", "설명 글 한 줄\r\n\r\n## 설계 흐름")
        noisy = swap(noisy, "| 회고 | leader | — |", "| 회고 | leader |  |")
        t = W.parse(noisy, "t.md")
        self.assertEqual(t[W.team_status.DESIGN_FLOW][4].name, "계획")
        self.assertEqual(t[W.team_status.DESIGN_FLOW][-1].stage, "—")

    def test_missing_anchor_is_only_a_notice(self):
        t = W.parse(swap(GOOD, "| 검수 |", "| 확인 |"), "t.md")
        self.assertEqual(W.missing_anchors(t), ["설계 흐름: 검수"])

    def test_anchor_stages_match_the_default_table(self):   # H2 — 막는 것의 단계는 이 상수에서
        t = W.parse(GOOD, "기본")
        for flow, steps in t.items():
            for s in steps:
                self.assertEqual(W.ANCHOR_STAGES.get((flow, s.name), "—"), s.stage, (flow, s.name))
        self.assertIs(W.Usage, W.team_rules.Usage)
        self.assertIs(W.Unchecked, W.team_rules.Unchecked)


class ReadOnly(unittest.TestCase):   # Global Constraints — 읽기만 한다
    def test_no_writes_no_subprocess(self):
        tree = ast.parse((W.Path(W.__file__)).read_text(encoding="utf-8"))
        names = {n.name for node in ast.walk(tree) if isinstance(node, (ast.Import, ast.ImportFrom)) for n in node.names}
        mods = {node.module for node in ast.walk(tree) if isinstance(node, ast.ImportFrom)}
        self.assertEqual((names | mods) & {"subprocess", "shutil", "socket"}, set())
        calls = {node.func.attr for node in ast.walk(tree) if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)}
        self.assertEqual(calls & {"write_text", "write_bytes", "replace", "unlink", "mkdir", "rename", "rmtree", "system", "popen"}, set())
        for node in ast.walk(tree):   # open 은 읽기 모드만
            if isinstance(node, ast.Call) and getattr(node.func, "id", None) == "open":
                modes = [a.value for a in node.args[1:2] if isinstance(a, ast.Constant)] + \
                        [k.value.value for k in node.keywords if k.arg == "mode" and isinstance(k.value, ast.Constant)]
                self.assertTrue(all(m in ("r", "rb") for m in modes), modes)

    def test_probe_has_teeth(self):   # 양성 대조 — 같은 훑기가 쓰는 모듈을 잡는다
        tree = ast.parse("import subprocess\nopen('x', 'w')\n")
        self.assertIn("subprocess", {n.name for node in ast.walk(tree) if isinstance(node, ast.Import) for n in node.names})


class Load(unittest.TestCase):   # AC1 — 설정이 가리키는 표는 기본 브랜치의 커밋에서 읽는다
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.dir = os.path.realpath(tmp.name)
        conf = tempfile.TemporaryDirectory()
        self.addCleanup(conf.cleanup)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_SYSTEM="/dev/null", GIT_TERMINAL_PROMPT="0",
                        CLAUDE_CONFIG_DIR=os.path.realpath(conf.name))
        patcher = mock.patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": self.env["CLAUDE_CONFIG_DIR"]})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.git_run("init", "-q", "-b", "main")
        self.git_run("remote", "add", "origin", self.dir)

    def git_run(self, *args):
        proc = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.com", "-c", "commit.gpgsign=false", *args],
                              cwd=self.dir, env=self.env, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.assertEqual(proc.returncode, 0, proc.stderr.decode("utf-8", "replace"))
        return proc.stdout.decode("utf-8").strip()

    def put(self, path, text):
        full = Path(self.dir) / path
        full.parent.mkdir(parents=True, exist_ok=True)
        full.write_text(text, encoding="utf-8")

    def land(self, files):
        """main 에 커밋하고 origin/main · origin/HEAD 를 같은 커밋으로 맞춘다."""
        for path, text in files.items():
            self.put(path, text)
        self.git_run("add", "--", *files)
        self.git_run("commit", "-q", "-m", "c", "--", *files)
        sha = self.git_run("rev-parse", "HEAD")
        self.git_run("update-ref", "refs/remotes/origin/main", sha)
        self.git_run("remote", "set-head", "origin", "main")
        return sha

    def setting(self, path="docs/walk.md"):
        return "---\nwalk_table: %s\n---\n" % path

    def test_l1_no_setting_uses_the_plugin_table(self):
        self.land({"README.md": "x\n"})
        table, source = W.load(self.dir)
        self.assertEqual(source, "플러그인 기본 표")
        self.assertEqual(table, W.parse(GOOD, "기본"))

    def test_l2_setting_reads_the_committed_file(self):
        mine = swap(GOOD, "superpowers:subagent-driven-development", "superpowers:executing-plans")
        sha = self.land({".devbrew.md": self.setting(), "docs/walk.md": mine})
        table, source = W.load(self.dir)
        self.assertEqual(source, "레포 설정 walk_table: docs/walk.md@" + sha[:8])
        self.assertEqual({s.name: s for s in table[W.team_status.DESIGN_FLOW]}["구현"].method, "superpowers:executing-plans")

    def test_l3_working_tree_edit_is_not_read(self):
        mine = swap(GOOD, "superpowers:subagent-driven-development", "superpowers:executing-plans")
        sha = self.land({".devbrew.md": self.setting(), "docs/walk.md": mine})
        self.put("docs/walk.md", GOOD)
        table, source = W.load(self.dir)
        self.assertEqual(source, "레포 설정 walk_table: docs/walk.md@" + sha[:8])
        self.assertEqual({s.name: s for s in table[W.team_status.DESIGN_FLOW]}["구현"].method, "superpowers:executing-plans")

    def test_l4_file_only_in_the_working_tree_stops(self):
        self.land({".devbrew.md": self.setting()})
        self.put("docs/walk.md", GOOD)
        with self.assertRaises(W.Unchecked) as cm:
            W.load(self.dir)
        self.assertIn("기본 브랜치에 없다", str(cm.exception))

    def test_l5_broken_committed_table_is_a_table_error(self):
        self.land({".devbrew.md": self.setting(), "docs/walk.md": swap(GOOD, "| worker | plan |", "| worker | build |")})
        with self.assertRaises(W.TableError) as cm:
            W.load(self.dir)
        self.assertIn("docs/walk.md:", str(cm.exception))

    def test_l6_symlink_stops(self):
        self.put("real.md", GOOD)
        os.symlink("real.md", os.path.join(self.dir, "walk-link.md"))
        self.land({".devbrew.md": self.setting("walk-link.md"), "real.md": GOOD, "walk-link.md": GOOD})
        with self.assertRaises(W.Unchecked) as cm:
            W.load(self.dir)
        self.assertIn("일반 파일이 아니다", str(cm.exception))

    def test_l7_absolute_path_setting_stops(self):
        self.land({".devbrew.md": self.setting("/abs.md")})
        with self.assertRaises(W.Unchecked) as cm:
            W.load(self.dir)
        self.assertIn("walk_table", str(cm.exception))

    def run_check(self, *args):
        proc = subprocess.run([sys.executable, str(SCRIPTS / "walk_table.py"), *args], cwd=self.dir, env=self.env,
                              stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return proc.returncode, proc.stdout.decode("utf-8"), proc.stderr.decode("utf-8")

    def test_cli_check(self):
        self.land({"README.md": "x\n"})
        rc, out, err = self.run_check("check")
        self.assertEqual(rc, 0, err)
        self.assertEqual(out.splitlines()[0], "걸음표 맞음 — 플러그인 기본 표 · 설계 흐름 11걸음 · 설계 없는 흐름 3걸음")
        self.put("broken.md", swap(GOOD, "| worker | plan |", "| worker | build |"))
        rc, out, err = self.run_check("check", "broken.md")
        self.assertEqual((rc, out), (3, ""))
        self.assertTrue(err.startswith("[spec-distill] 검사 불가 — "), err)
        self.put("noanchor.md", swap(GOOD, "| 검수 |", "| 확인 |"))
        rc, out, err = self.run_check("check", "noanchor.md")
        self.assertEqual(rc, 0, err)
        self.assertEqual(out.splitlines()[1], "알림: 걸음 보기가 쓰는 걸음 이름이 없다 — 설계 흐름: 검수")
        rc, out, err = self.run_check("check", "a", "b")
        self.assertEqual((rc, out), (2, ""))
        self.assertTrue(err.startswith("[spec-distill] 사용법 오류 — "), err)


if __name__ == "__main__":
    unittest.main()
