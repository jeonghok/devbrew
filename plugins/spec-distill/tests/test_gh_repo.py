#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""gh_repo.py — origin URL 판독(호스트 · owner · repo)과 못 뽑는 URL 의 멈춤(R8 AC16).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_gh_repo.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import gh_repo  # noqa: E402

STOP = "origin URL 에서 호스트 · owner · repo 를 뽑지 못했다 — git remote get-url origin 을 확인한다"


class ParseOriginUrl(unittest.TestCase):
    SAME = (
        "https://github.com/me/r.git",
        "https://user@github.com/me/r.git",
        "https://github.com:443/me/r.git",
        "https://github.com/me/r",
        "ssh://git@github.com/me/r.git",
        "git@github.com:me/r.git",
        "https://github.com/me/r/",
    )

    def test_seven_forms_give_same_triple(self):
        for url in self.SAME:
            with self.subTest(url=url):
                self.assertEqual(gh_repo.parse_origin_url(url), ("github.com", "me", "r"))

    def test_ssh_port_and_case(self):
        self.assertEqual(gh_repo.parse_origin_url("ssh://git@GHE.Example.com:2222/o/r.git"),
                         ("ghe.example.com", "o", "r"))
        self.assertEqual(gh_repo.parse_origin_url("git@ghe.example.com:o/r.git\n"),
                         ("ghe.example.com", "o", "r"))

    def test_positive_control_other_owner(self):
        self.assertEqual(gh_repo.parse_origin_url("https://github.com/up/r"), ("github.com", "up", "r"))
        self.assertNotEqual(gh_repo.parse_origin_url("https://github.com/up/r"),
                            gh_repo.parse_origin_url("https://github.com/me/r"))

    def test_unparseable_urls_stop(self):
        for url in ("file:///x", "/srv/git/r.git", "https://github.com/r", "", "../r.git",
                    "https://github.com/a/b/c", "https:///me/r", "file://host/o/r", "git://github.com/me/r"):
            with self.subTest(url=url):
                self.assertIsNone(gh_repo.parse_origin_url(url))
                with self.assertRaises(gh_repo.GhStop) as cm:
                    gh_repo.slug_from_url(url)
                self.assertEqual(str(cm.exception), STOP)

    def test_slug_from_url_joins_host(self):
        self.assertEqual(gh_repo.slug_from_url("git@ghe.example.com:o/r.git"), "ghe.example.com/o/r")


class EnvNotices(unittest.TestCase):
    def test_notices_name_and_value(self):
        env = {"GH_REPO": "up/r", "GH_HOST": "ghe.example.com", "PATH": "/x"}
        self.assertEqual(gh_repo.env_notices(env), [
            "GH_REPO 이 설정돼 있다(up/r) — devbrew 는 -R 로 origin 을 명시해 쓴다",
            "GH_HOST 이 설정돼 있다(ghe.example.com) — devbrew 는 -R 로 origin 을 명시해 쓴다",
        ])

    def test_no_notice_when_unset_or_empty(self):
        self.assertEqual(gh_repo.env_notices({"GH_REPO": "", "PATH": "/x"}), [])


class StderrKinds(unittest.TestCase):
    def test_auth(self):
        for err in ("To get started with GitHub CLI, please run:  gh auth login",
                    "You are not logged into any GitHub hosts.",
                    "HTTP 401: authentication required"):
            with self.subTest(err=err):
                self.assertEqual(gh_repo.stop_for(4, err, "github.com", "github.com/me/r"),
                                 "gh 인증이 안 됐다 — gh auth login --hostname github.com 를 돈다")

    def test_repository_not_resolved(self):
        for err in ("GraphQL: Could not resolve to a Repository with the name 'o/r'. (repository)",
                    "graphql: could not resolve to a repository with the name 'o/r'."):
            with self.subTest(err=err):
                self.assertEqual(gh_repo.stop_for(1, err, "github.com", "github.com/o/r"),
                                 "gh 가 origin(github.com/o/r)을 다루지 못한다 — devbrew 는 origin 이 GitHub 인 레포만 "
                                 "지원한다(비공개 레포면 접근 권한도 확인한다)")

    def test_other_not_found_is_not_repository_resolution(self):
        for err in ("gh: Not Found (HTTP 404)",
                    "HTTP 404: Not Found (https://gitlab.com/api/graphql)",
                    "GraphQL: No such type PullRequest, so it can't be a fragment condition (fragment pr)",
                    "error connecting to ghe.example.com",
                    "could not resolve host: ghe.example.com"):
            with self.subTest(err=err):
                self.assertEqual(gh_repo.stop_for(1, err, "github.com", "github.com/o/r"),
                                 "gh 실패(rc 1): " + err)

    def test_other(self):
        self.assertEqual(gh_repo.stop_for(2, "\nboom here\nsecond", "github.com", "github.com/me/r"),
                         "gh 실패(rc 2): boom here")


if __name__ == "__main__":
    unittest.main()
