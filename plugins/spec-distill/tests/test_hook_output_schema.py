#!/usr/bin/env python3
"""NG9 — 상태 루트 해석기가 하나로 모인다: 연결된 worktree 에서도 본 체크아웃의 `.claude/spec-distill`.

NG9 가 견주던 bash 쪽 식 `${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill` 은 SessionStart 훅
session-anchor.sh 에 있었고 그 훅은 지워졌다(3d4a021f). 지금 skill 의 셸 블록은 상태 루트를 모두
`state_path.py` 로 구한다. 이 시험은 Claude Code 가 세션을 worktree 에서 열 때처럼 CLAUDE_PROJECT_DIR 이
worktree 를 가리켜도 python 해석기와 셸 진입이 같은 루트 — 본 체크아웃 쪽 — 를 내는지 잰다.
worktree 는 시험이 임시 레포에 스스로 만든다(본 체크아웃에서 돌려도 건너뛰지 않는다).

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_hook_output_schema
"""
from __future__ import annotations

import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPTS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "scripts"
STATE_PATH = SCRIPTS_DIR / "state_path.py"
GIT_ENV = ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_COMMON_DIR")


def _git(*args: str, cwd: Path) -> None:
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True)


class TestCrossResolverAdvisory(unittest.TestCase):
    """NG9 — 연결된 worktree 안에서 python state_path 와 셸 진입이 본 체크아웃의 상태 루트로 모인다."""

    def setUp(self):
        self._td = tempfile.TemporaryDirectory()
        self.addCleanup(self._td.cleanup)
        base = Path(os.path.realpath(self._td.name))
        self.main = base / "main"
        self.wt = base / "wt"
        self.main.mkdir()
        self.env = {k: v for k, v in os.environ.items() if k not in GIT_ENV}
        with mock.patch.dict(os.environ, self.env, clear=True):
            _git("init", "-q", cwd=self.main)
            _git("-c", "user.email=t@t.t", "-c", "user.name=t", "commit", "-q", "--allow-empty", "-m", "init",
                 cwd=self.main)
            _git("worktree", "add", "-q", "--detach", str(self.wt), "HEAD", cwd=self.main)
        (self.wt / "docs").mkdir()
        self.doc = self.wt / "docs" / "d.md"
        self.doc.write_text("x\n", encoding="utf-8")
        self.env["CLAUDE_PROJECT_DIR"] = str(self.wt)
        self.expected = self.main / ".claude" / "spec-distill"

    def test_python_and_bash_resolvers_agree(self):
        self.assertTrue((self.wt / ".git").is_file(), "전제: 연결된 worktree 를 만들지 못했다 — 아래 단언이 공허하다")
        # python 해석기 — cwd 를 넘긴 꼴과 cwd 를 넘기지 않은 꼴(지금 작업 폴더가 worktree)
        sys.path.insert(0, str(SCRIPTS_DIR))
        prev = os.getcwd()
        try:
            import state_path  # type: ignore
            with mock.patch.dict(os.environ, self.env, clear=True):
                py_given = state_path.state_root(str(self.wt))
                os.chdir(self.wt)
                py_cwd = state_path.state_root()
        finally:
            os.chdir(prev)
            sys.path.pop(0)
        # 셸 진입 — skill 의 셸 블록이 부르는 꼴 그대로(state-root · state-root-for <문서>)
        sh = {}
        for name, script in (("state-root", 'python3 "$1" state-root'),
                             ("state-root-for", 'python3 "$1" state-root-for "$2"')):
            cp = subprocess.run(["bash", "-c", script, "_", str(STATE_PATH), str(self.doc)],
                                cwd=self.wt, env=self.env, capture_output=True, text=True, check=False)
            self.assertEqual(cp.returncode, 0, "셸 진입 %s 가 실패했다: %s" % (name, cp.stderr))
            sh[name] = Path(cp.stdout.strip())
        got = {"python state_root(cwd)": py_given, "python state_root()": py_cwd,
               "셸 state-root": sh["state-root"], "셸 state-root-for": sh["state-root-for"]}
        for label, root in got.items():
            with self.subTest(resolver=label):
                self.assertEqual(
                    root, self.expected,
                    msg="%s 가 worktree(CLAUDE_PROJECT_DIR=%s) 에서 본 체크아웃의 상태 루트가 아닌 곳을 낸다"
                        % (label, self.wt))


if __name__ == "__main__":
    unittest.main()
