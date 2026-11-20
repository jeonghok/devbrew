#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""지휘자 상태 브랜치 테스트의 임시 레포 — 원격(bare) 하나 · 클론 하나 · 로드맵 둘. 테스트 파일이 가져다 쓴다."""
from __future__ import annotations

import hashlib
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import conductor_state as cs  # noqa: E402
from state_path import state_root  # noqa: E402

SID, OTHER = "aaaa1111-session", "bbbb2222-session"   # 앞 여덟 자가 서로 다르다 — STATUS 는 앞 여덟 자만 싣는다
ALPHA, BETA = "2026-01-01-alpha", "2026-01-02-beta"
ROADMAPS = "docs/superpowers/roadmaps/"
GIT_ENV = {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0"}   # 사용자 전역 git 설정 · 훅을 타지 않는다
ENV = dict(os.environ, **GIT_ENV)
STATE_DIR = ".claude/"   # 상태 루트(표지 · 기계 상태)가 사는 폴더 — 임시 레포가 커밋하지 않게 무시 목록에 넣는다


def rm(name: str) -> str:
    return ROADMAPS + name + "/roadmap.md"


def block(bid: str, title: str, branch: str, reserved: str = "없음", deps: str = "없음") -> str:
    return ("### %s — %s\n- 의도: 가\n- 범위:\n  - 한다: x\n  - 안 한다: y\n- 의존: %s\n- 브랜치: %s\n"
            "- 묶음: %s.md\n- 경로 예약: %s\n\n" % (bid, title, deps, branch, bid, reserved))


def roadmap_text(title: str, blocks: str) -> str:
    return ("---\ntype: roadmap\nsource_brief: b.md\n---\n\n# %s\n\n## 에픽\n\n%s"
            "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n" % (title, blocks))


class StateRepo(unittest.TestCase):
    """self.o 원격(기본 브랜치 trunk) · self.w 클론. ALPHA 는 A1(제목에 ` · `) · A2, BETA 는 B1 을 가진다."""
    ALPHA_BLOCKS = (block("A1", "가 · 나", "feature/a1", "src/a.py, src/shared.py, plugin.json")
                    + block("A2", "다", "feature/a2"))
    BETA_BLOCKS = block("B1", "라", "feature/b1", "src/shared.py, src/b.py, plugin.json")

    def setUp(self):
        patcher = mock.patch.dict(os.environ, GIT_ENV)   # 프로세스 안에서 부르는 스크립트의 git 도 같은 환경을 탄다 — 끝나면 되돌린다
        patcher.start()
        self.addCleanup(patcher.stop)
        self.t = Path(tempfile.mkdtemp())
        self.o, self.w = self.t / "o.git", self.t / "w"
        subprocess.run(["git", "init", "-q", "--bare", "-b", "trunk", str(self.o)], env=ENV, check=True)
        self.w = self.clone("w")
        self.g("checkout", "-q", "-B", "trunk")
        self.put({rm(ALPHA): roadmap_text("알파 — 로드맵", self.ALPHA_BLOCKS),
                  rm(BETA): roadmap_text("베타 — 로드맵", self.BETA_BLOCKS)})
        self.g("remote", "set-head", "origin", "--auto")

    def tearDown(self):
        shutil.rmtree(str(self.t), ignore_errors=True)

    def g(self, *args, repo=None, check=True) -> str:
        p = subprocess.run(["git", *args], cwd=str(repo or self.w), env=ENV, capture_output=True, encoding="utf-8")
        if check and p.returncode:
            raise AssertionError("git %s → %d: %s" % (" ".join(args), p.returncode, p.stderr))
        return p.stdout.strip()

    def rc(self, *args, repo=None) -> int:
        """종료 코드로만 답하는 git 명령(`merge-base --is-ancestor` 등)의 종료 코드. 출력으로 견주면 늘 빈 글이라 공허하다."""
        return subprocess.run(["git", *args], cwd=str(repo or self.w), env=ENV, capture_output=True).returncode

    def clone(self, label: str, *extra) -> Path:
        """원격의 클론 하나(다른 기계 흉내). 그 레포에만 git 이름을 준다."""
        d = self.t / label
        subprocess.run(["git", "clone", "-q", *extra, "file://%s" % self.o, str(d)], env=ENV, capture_output=True, check=True)
        for key, value in (("user.name", label), ("user.email", label + "@example.invalid"), ("commit.gpgsign", "false")):
            self.g("config", key, value, repo=d)
        info = d / ".git" / "info"
        info.mkdir(exist_ok=True)
        with open(str(info / "exclude"), "a", encoding="utf-8") as fh:   # `git add -A` 가 표지 · 기계 상태를 싣지 않게
            fh.write(STATE_DIR + "\n")
        if self.g("rev-parse", "--verify", "-q", "refs/remotes/origin/trunk", repo=d, check=False):
            self.g("remote", "set-head", "origin", "--auto", repo=d)
        return d

    def put(self, files: dict, repo=None, message: str = "files") -> None:
        """기본 브랜치에 파일을 커밋해 올린다."""
        repo = repo or self.w
        for rel, text in files.items():
            (repo / rel).parent.mkdir(parents=True, exist_ok=True)
            (repo / rel).write_text(text, encoding="utf-8")
        self.g("add", "-A", repo=repo)
        self.g("commit", "-qm", message, repo=repo)
        self.g("push", "-q", "origin", "trunk", repo=repo)

    def epic_branch(self, name: str, files: dict, push: bool = True) -> str:
        """trunk 에서 딴 에픽 브랜치에 파일을 커밋하고 trunk 로 돌아온다. 그 끝 커밋을 돌려준다."""
        self.g("checkout", "-q", "-b", name, "trunk")
        for rel, text in files.items():
            (self.w / rel).parent.mkdir(parents=True, exist_ok=True)
            (self.w / rel).write_text(text, encoding="utf-8")
        self.g("add", "-A")
        self.g("commit", "-qm", "feat: " + name)
        if push:
            self.g("push", "-q", "origin", name)
        tip = self.g("rev-parse", "HEAD")
        self.g("checkout", "-q", "trunk")
        return tip

    def merge_epic(self, name: str) -> None:
        """에픽 브랜치를 머지 커밋으로 trunk 에 넣고 올린다(브랜치는 남긴다) — 상태 계산이 그 에픽을 「머지됨」 으로 센다."""
        self.g("merge", "-q", "--no-ff", "-m", "Merge pull request #7 from me/" + name, name)
        self.g("push", "-q", "origin", "trunk")

    def claim(self, name: str = ALPHA, session: str = SID, repo=None) -> Path:
        """그 로드맵의 지휘 표지를 잡는다. 기계 상태 폴더를 돌려준다."""
        d = cs.machine_dir(state_root(str(repo or self.w)), rm(name))
        self.assertEqual(cs.acquire(d, session), "acquired")
        return d

    def snap(self, repo=None) -> tuple:
        """작업 폴더의 지문 — HEAD · 가리키는 브랜치 · index 파일 · 상태 줄. 쓰기 앞뒤로 같아야 한다."""
        repo = repo or self.w
        index = Path(self.g("rev-parse", "--path-format=absolute", "--git-path", "index", repo=repo))
        return (self.g("rev-parse", "HEAD", repo=repo), self.g("symbolic-ref", "-q", "HEAD", repo=repo, check=False),
                hashlib.sha256(index.read_bytes()).hexdigest(), self.g("status", "--porcelain=v1", repo=repo))

    def refs(self, repo=None) -> str:
        return self.g("for-each-ref", "--format=%(refname) %(objectname)", repo=repo)
