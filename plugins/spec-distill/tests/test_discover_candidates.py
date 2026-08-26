#!/usr/bin/env python3
"""discover_candidates 단위 테스트 — A5(술어 일치) · A6(born 도출) · A17(파싱)."""
import importlib.util
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import arm_ledger  # noqa: E402
spec = importlib.util.spec_from_file_location("dc", SCRIPTS / "discover_candidates.py")
dc = importlib.util.module_from_spec(spec)
spec.loader.exec_module(dc)

PREFIX = arm_ledger.PREFIX


def git(*args, cwd):
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, check=True)


class TestParseStatusZ(unittest.TestCase):
    def test_plain_records(self):
        raw = b"?? a.md\x00 M b.md\x00"
        self.assertEqual(dc.parse_status_z(raw), [("??", "a.md"), (" M", "b.md")])

    def test_rename_consumes_orig_path_field(self):
        # rename/copy 항목은 `XY path\0origPath\0` 로 필드가 둘이다. orig 를 레코드로
        # 소비하면 이후 전체 항목이 한 칸씩 밀린다.
        raw = b"R  new.md\x00old.md\x00 M after.md\x00"
        self.assertEqual(dc.parse_status_z(raw),
                         [("R ", "new.md"), (" M", "after.md")])

    def test_space_and_newline_in_path(self):
        raw = b"?? a b.md\x00?? c\nd.md\x00"
        self.assertEqual(dc.parse_status_z(raw), [("??", "a b.md"), ("??", "c\nd.md")])

    def test_non_utf8_bytes_survive_as_replacement(self):
        raw = b"?? bad\xff.md\x00"
        got = dc.parse_status_z(raw)
        self.assertEqual(len(got), 1)
        self.assertEqual(got[0][0], "??")

    def test_trailing_garbage_without_nul_is_dropped(self):
        self.assertEqual(dc.parse_status_z(b"?? a.md\x00?? trunc"), [("??", "a.md")])


class TestBornAgreesWithArmLedger(unittest.TestCase):
    """A6 — born 도출이 arm_ledger.is_born 과 모든 도달 가능 조합에서 일치한다.

    코드를 열거하지 않는다. 픽스처로 상태를 만들고 git 이 실제로 낸 XY 를 받아
    두 판정을 비교한다 — `AM` 같은 조합이 열거에서 빠지는 실패를 구조적으로 막는다.
    """

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        # macOS 의 /tmp 는 /private/tmp 심볼릭 링크다 — 경로 포함 검사가 조용히 무너진다.
        self.tmp = Path(subprocess.run(["pwd", "-P"], cwd=self.tmp, capture_output=True,
                                       text=True, check=True).stdout.strip())
        git("init", "-q", cwd=self.tmp)
        git("config", "user.email", "t@t", cwd=self.tmp)
        git("config", "user.name", "t", cwd=self.tmp)
        self.specs = self.tmp / PREFIX
        self.specs.mkdir(parents=True)

    def _mk(self, name, body="x\n"):
        p = self.specs / name
        p.write_text(body, encoding="utf-8")
        return p

    def test_all_reachable_combos_agree(self):
        # 1) untracked
        self._mk("untracked-design.md")
        # 3) committed clean, then worktree-modified ( M)
        p = self._mk("mod-design.md"); git("add", str(p), cwd=self.tmp)
        # 4) staged-then-modified (AM) — 이 설계가 겨냥하는 바로 그 시나리오
        p4 = self._mk("am-design.md"); git("add", str(p4), cwd=self.tmp)
        git("commit", "-q", "-m", "c", cwd=self.tmp)
        (self.specs / "mod-design.md").write_text("y\n", encoding="utf-8")
        p4b = self._mk("am2-design.md"); git("add", str(p4b), cwd=self.tmp)
        p4b.write_text("z\n", encoding="utf-8")   # → AM
        # 2) staged-new (A ) — commit **이후**에 스테이징해야 한다. commit 이전에
        # 스테이징하면 위 커밋이 이 파일도 함께 묻어 커밋해버려 A 상태가 관측 시점
        # 이전에 사라진다(실측 — 원본 순서로는 seen 에 "A " 가 끝내 나타나지 않았다).
        p2 = self._mk("added-design.md"); git("add", str(p2), cwd=self.tmp)

        raw = subprocess.run(["git", "status", "--porcelain", "-z",
                              "--untracked-files=all"],
                             cwd=self.tmp, capture_output=True, check=True).stdout
        records = dc.parse_status_z(raw)
        self.assertTrue(records, "픽스처가 아무 상태도 만들지 못했다 — 계측기 고장")
        seen = set()
        cwd0 = os.getcwd()
        os.chdir(self.tmp)
        try:
            for xy, path in records:
                if not (self.tmp / path).exists():
                    continue           # 존재 필터가 born 판정보다 앞선다
                seen.add(xy)
                self.assertEqual(
                    dc.born_from_status(xy), arm_ledger.is_born(path),
                    f"XY={xy!r} path={path!r} 에서 born 판정이 갈렸다")
        finally:
            os.chdir(cwd0)
        # 양성 대조 — 픽스처가 의도한 조합을 실제로 만들었는가.
        self.assertIn("??", seen)
        self.assertIn("A ", seen)
        self.assertIn(" M", seen)
        self.assertIn("AM", seen)


class TestGitIsOnlyAnUpperBound(unittest.TestCase):
    """A5 — in-scope 판정은 canonical_key 단독. git 은 상계만 준다."""

    def test_out_of_scope_dirty_file_is_not_a_candidate(self):
        recs = [("??", "README.md"), ("??", PREFIX + "x-design.md")]
        keys = [c.key for c in dc.candidates_from_records(recs, exists=lambda p: True)]
        self.assertEqual(keys, [PREFIX + "x-design.md"])

    def test_predicate_is_canonical_key_itself(self):
        # 술어를 재구현하지 않는다는 것을 성질로 잰다: canonical_key 가 None 을 내는
        # 입력은 무엇이든 후보가 아니다.
        bad = PREFIX + "with\nnewline-design.md"
        self.assertIsNone(arm_ledger.canonical_key(bad))
        self.assertEqual(dc.candidates_from_records([("??", bad)],
                                                    exists=lambda p: True), [])

    def test_nested_prefix_path_is_a_candidate(self):
        # 판본 4·5 가 두 번 놓친 자리 — 중첩 접두. pathspec 을 쓰지 않으므로
        # 이 케이스는 구조적으로 빠질 수 없다.
        nested = "sub/dir/" + PREFIX + "y-design.md"
        self.assertEqual(
            [c.key for c in dc.candidates_from_records([("??", nested)],
                                                       exists=lambda p: True)],
            [PREFIX + "y-design.md"])


class TestGitUnavailableIsDistinctFromEmpty(unittest.TestCase):
    def test_non_repo_raises(self):
        tmp = Path(tempfile.mkdtemp())
        with self.assertRaises(dc.GitUnavailable):
            dc.discover(cwd=tmp)


class TestDiscoverFromSubdirectory(unittest.TestCase):
    """R37 — repo root 해석이 cwd 서브디렉터리에서도 후보를 찾는다.

    `git status --porcelain -z` 는 실행 cwd 와 무관하게 리포-루트 상대 경로를 낸다
    (실측). discover() 가 `exists` 술어를 `cwd` 인자에 대고 조인하면, cwd 가 서브
    디렉터리일 때 모든 경로가 존재하지 않는 것으로 판정돼 **조용히 후보 0** 이
    된다 — GitUnavailable 과 구별돼야 한다는 이 모듈 자신의 계약을 깨는 실패.
    """

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.tmp = Path(subprocess.run(["pwd", "-P"], cwd=self.tmp, capture_output=True,
                                       text=True, check=True).stdout.strip())
        git("init", "-q", cwd=self.tmp)
        git("config", "user.email", "t@t", cwd=self.tmp)
        git("config", "user.name", "t", cwd=self.tmp)
        self.specs = self.tmp / PREFIX
        self.specs.mkdir(parents=True)
        (self.specs / "sub-design.md").write_text("x\n", encoding="utf-8")
        self.subdir = self.tmp / "sub" / "deep"
        self.subdir.mkdir(parents=True)

    def test_discover_from_subdir_finds_candidate(self):
        cands = dc.discover(cwd=self.subdir)
        keys = [c.key for c in cands]
        self.assertIn(PREFIX + "sub-design.md", keys)


class TestDiscoverNestedPrefixCandidate(unittest.TestCase):
    """Step 5 의 MUT4 자기-지적 갭을 닫는다.

    `TestGitIsOnlyAnUpperBound` 는 `candidates_from_records` 순수 함수만 부르므로
    `git status` 에 pathspec 을 재도입하는 변이(MUT4 — 판본 4 의 결함)를 통과시킨다.
    `discover()` 를 실제로 돌려 중첩 접두 픽스처가 잡히는지 확인해야 그 변이가
    이 스위트에서 RED 로 잡힌다.
    """

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.tmp = Path(subprocess.run(["pwd", "-P"], cwd=self.tmp, capture_output=True,
                                       text=True, check=True).stdout.strip())
        git("init", "-q", cwd=self.tmp)
        git("config", "user.email", "t@t", cwd=self.tmp)
        git("config", "user.name", "t", cwd=self.tmp)
        nested_dir = self.tmp / "sub" / "dir" / PREFIX
        nested_dir.mkdir(parents=True)
        (nested_dir / "y-design.md").write_text("x\n", encoding="utf-8")

    def test_nested_prefix_candidate_found_via_discover(self):
        cands = dc.discover(cwd=self.tmp)
        keys = [c.key for c in cands]
        self.assertEqual(keys, [PREFIX + "y-design.md"])


if __name__ == "__main__":
    unittest.main()
