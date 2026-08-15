#!/usr/bin/env python3
"""prepare_standup.py — AC10 · AC11 · AC20 · AC34 · AC41 · AC42 · AC46 · AC49.

이 파일의 픽스처는 **전부 합성**이다. 실제 세션 파일은 테스트에 쓰지 않는다
(비밀·개인정보).

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_prepare_standup.py
"""
from __future__ import annotations

import importlib.util
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "agent-transparency" / "scripts" / "prepare_standup.py"


def load_script():
    spec = importlib.util.spec_from_file_location("prepare_standup", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def git(*args, cwd):
    subprocess.run(["git"] + list(args), cwd=str(cwd), check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def make_repo(path: Path, branch: str = "work") -> None:
    """git init + 최초 커밋 + 브랜치 이름 고정."""
    path.mkdir(parents=True, exist_ok=True)
    git("init", "-q", cwd=path)
    git("config", "user.email", "t@t.t", cwd=path)
    git("config", "user.name", "t", cwd=path)
    (path / "seed.txt").write_text("seed\n", encoding="utf-8")
    git("add", "-A", cwd=path)
    git("commit", "-qm", "seed", cwd=path)
    git("branch", "-M", branch, cwd=path)


def rec(**kw):
    """레코드 하나. timestamp 는 기본값을 준다."""
    base = {"timestamp": "2026-08-02T09:11:00.000Z"}
    base.update(kw)
    return base


def assistant_text(text, **kw):
    return rec(type="assistant",
               message={"role": "assistant", "content": [{"type": "text", "text": text}]},
               **kw)


def write_jsonl(path: Path, records) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as fh:
        for record in records:
            fh.write(json.dumps(record, ensure_ascii=False) + "\n")


class Sandbox:
    """임시 HOME + 메인 리포 + 워크트리 + 합성 프로젝트 디렉토리.

    **HOME 을 스스로 설정하고 close() 에서 되돌린다.** 테스트마다 os.environ 을
    손대고 복구하지 않으면 뒤 테스트가 앞 테스트의 HOME 을 물려받아, 실패가
    실행 순서에 따라 나타났다 사라진다.
    """

    def __init__(self) -> None:
        # macOS 의 mktemp 계열은 심볼릭 경로를 준다 — 슬러그가 어긋나므로 물리 경로로 푼다.
        self.root = Path(tempfile.mkdtemp(prefix="at-standup-")).resolve()
        self.home = self.root / "home"
        self.projects = self.home / ".claude" / "projects"
        self.projects.mkdir(parents=True)
        self.main = self.root / "devbrew"
        make_repo(self.main, branch="work")
        self.worktree = self.main / ".claude" / "worktrees" / "wt"
        git("worktree", "add", "-q", "-b", "wt-branch", str(self.worktree), cwd=self.main)
        self._prev_home = os.environ.get("HOME")
        os.environ["HOME"] = str(self.home)

    def project_dir(self, path: Path) -> Path:
        module = load_script()
        target = self.projects / module.slug(str(path))
        target.mkdir(parents=True, exist_ok=True)
        return target

    def close(self) -> None:
        if self._prev_home is None:
            os.environ.pop("HOME", None)
        else:
            os.environ["HOME"] = self._prev_home
        shutil.rmtree(self.root, ignore_errors=True)


class TestRootResolution(unittest.TestCase):
    """AC10 — 슬러그 접두사를 **메인 리포 루트**에서 만든다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_common_dir_is_absolute_even_in_main_repo(self) -> None:
        """메인 리포에서 git 은 상대 '.git' 을 준다 — 정규화가 없으면 비교가 깨진다."""
        raw = subprocess.run(["git", "rev-parse", "--git-common-dir"],
                             cwd=str(self.box.main), stdout=subprocess.PIPE,
                             check=True).stdout.decode().strip()
        self.assertFalse(os.path.isabs(raw))
        self.assertTrue(os.path.isabs(self.module.git_common_dir(str(self.box.main))))

    def test_same_common_dir_from_worktree_and_main(self) -> None:
        self.assertEqual(self.module.git_common_dir(str(self.box.main)),
                         self.module.git_common_dir(str(self.box.worktree)))

    def test_common_dir_matches_through_symlink(self) -> None:
        """`realpath` 정규화가 없으면 심볼릭 링크 경유 호출이 원본과 다른 문자열로 나온다.

        `os.path.join(cwd, out)` 만으로는 링크 경로 문자열이 그대로 살아남아
        원본 경로로 얻은 값과 문자열 비교가 깨진다.
        """
        link = self.box.root / "link-to-repo"
        os.symlink(self.box.main, link)
        self.assertEqual(self.module.git_common_dir(str(link)),
                         self.module.git_common_dir(str(self.box.main)))

    def test_common_dir_matches_from_unresolved_temp_path(self) -> None:
        """`realpath` 정규화가 없으면 미해석 tempdir 과 그 realpath 가 다른 문자열로 나온다.

        macOS 에서 raw tempdir 은 `/var/...` 로, realpath 는 `/private/var/...` 로
        시작한다. Sandbox.root 는 `.resolve()` 로 이 간극을 생성자에서 미리
        없애므로, 이 테스트는 Sandbox 밖에서 별도 repo 를 직접 만들어 그 간극을
        재현한다.
        """
        raw = tempfile.mkdtemp(prefix="at-standup-raw-")
        self.addCleanup(shutil.rmtree, raw, ignore_errors=True)
        make_repo(Path(raw))
        self.assertEqual(self.module.git_common_dir(raw),
                         self.module.git_common_dir(os.path.realpath(raw)))

    def test_root_from_worktree_is_main_repo(self) -> None:
        self.assertEqual(self.module.repo_root(str(self.box.worktree)),
                         str(self.box.main))

    def test_prefix_catches_main_and_sibling_worktree(self) -> None:
        """워크트리 안에서 실행해도 메인 리포와 형제 워크트리 디렉토리가 **둘 다** 잡힌다.

        `repo_root()` 를 거쳐야 한다 — root 를 `self.box.main` 으로 직접 넘기면
        `--show-toplevel` 기반 구현이 저지르는 실패 모드(워크트리 경로가 더
        길어 접두사 방향이 반대라 1개만 잡히는데도 0개가 아니라 정상처럼
        답하는 것)를 가린다. 프로덕션과 같은 경로 —
        `repo_root(worktree)` → `candidate_paths` — 로 라우팅해야 이를 잡는다.
        """
        main_dir = self.box.project_dir(self.box.main)
        wt_dir = self.box.project_dir(self.box.worktree)
        write_jsonl(main_dir / "aaa.jsonl", [assistant_text("m", gitBranch="work")])
        write_jsonl(wt_dir / "bbb.jsonl", [assistant_text("w", gitBranch="wt-branch")])
        os.environ["HOME"] = str(self.box.home)
        module = load_script()  # HOME 반영을 위해 재로드
        root = module.repo_root(str(self.box.worktree))
        found = module.candidate_paths(root)
        self.assertEqual(len(found), 2, found)


class TestCandidateValidation(unittest.TestCase):
    """AC41 — 무관한 리포 배제 · 삭제된 워크트리를 **오분류하지 않음** · 집합 술어."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.module = load_script()
        self.ours = self.module.git_common_dir(str(self.box.main))
        self.addCleanup(self.box.close)

    def test_other_repo_rejected(self) -> None:
        """접두사만 공유하는 다른 리포는 0건 포함."""
        other = self.box.root / "devbrew-experiments"
        make_repo(other, branch="main")
        ok, reason = self.module.classify(
            [rec(cwd=str(other), gitBranch="main")], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "other-repo")

    def test_deleted_worktree_is_cwd_gone_not_other_repo(self) -> None:
        """이미 삭제된 cwd 는 other-repo 가 아니라 cwd-gone 으로 계상된다.

        남의 리포와 합산하면 정당한 과거 세션이 조용히 사라진다.
        """
        ok, reason = self.module.classify(
            [rec(cwd=str(self.box.root / "vanished"))], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "cwd-gone")

    def test_no_cwd_anywhere_is_cwd_missing(self) -> None:
        """세 번째 사유 — cwd 없는 레코드만 있는 파일(D7)."""
        ok, reason = self.module.classify([rec(gitBranch="work")], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "cwd-missing")

    def test_mixed_cwds_accepted_by_set_predicate(self) -> None:
        """한 파일에 유효·무효 cwd 가 섞이면 **채택**. 단수 술어 구현은 red."""
        ok, reason = self.module.classify(
            [rec(cwd=str(self.box.root / "vanished")), rec(cwd=str(self.box.worktree))],
            self.ours, {})
        self.assertTrue(ok)
        self.assertEqual(reason, "")

    def test_containment_predicate_is_not_used(self) -> None:
        """cwd 가 메인 리포 루트 **아래**인지로 판정하면 안 된다 — 리포 밖 워크트리가 잘린다."""
        outside = self.box.root / "outside-worktree"
        git("worktree", "add", "-q", "-b", "outside", str(outside), cwd=self.box.main)
        ok, _ = self.module.classify([rec(cwd=str(outside))], self.ours, {})
        self.assertTrue(ok)

    def test_git_calls_are_cached_per_cwd(self) -> None:
        """같은 cwd 를 반복 검사하지 않는다(스캔 비용은 git 호출 수가 지배한다)."""
        cache = {}
        records = [rec(cwd=str(self.box.main)) for _ in range(5)]
        self.module.classify(records, self.ours, cache)
        self.assertEqual(len(cache), 1)

    def test_unresolved_ours_is_refused_not_matched(self) -> None:
        """센티널 충돌 — 우리 리포와 후보가 **같은 `None`** 을 "판정 불가" 로 쓴다.

        `None == None` 이 참이므로, 우리 쪽이 미해결이면 해석 불가능한 남의
        트랜스크립트가 **전부** 채택된다(전 범위 상실이 건강한 standup 으로
        렌더된다). 판정 불가는 일치가 아니므로 함수가 거절해야 한다.
        """
        plain = self.box.root / "not-a-repo"
        plain.mkdir()
        with self.assertRaises(ValueError):
            self.module.classify([rec(cwd=str(plain))], None, {})

    def test_unresolved_ours_refused_even_for_vanished_cwd(self) -> None:
        """사라진 cwd 도 `None` 을 캐시하므로 같은 충돌 경로다 — 두 입력 축을 모두 흔든다."""
        with self.assertRaises(ValueError):
            self.module.classify([rec(cwd=str(self.box.root / "vanished"))], None, {})

    def test_resolved_ours_still_rejects_unresolvable_candidate(self) -> None:
        """양의 짝 — 우리 쪽이 해결됐을 때 해석 불가 후보는 조용히 거절된다.

        위 두 락만 두면 `classify` 가 무조건 raise 해도 통과한다.
        """
        plain = self.box.root / "not-a-repo-2"
        plain.mkdir()
        ok, reason = self.module.classify([rec(cwd=str(plain))], self.ours, {})
        self.assertFalse(ok)
        self.assertEqual(reason, "other-repo")


class TestNonRecursiveGlob(unittest.TestCase):
    """AC49 — `<sid>/subagents/*.jsonl` 은 구조적으로 제외된다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_subagent_files_are_not_candidates(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        write_jsonl(pdir / "sess.jsonl", [assistant_text("main", gitBranch="work")])
        write_jsonl(pdir / "sess" / "subagents" / "agent-1.jsonl",
                    [assistant_text("sub", gitBranch="work")])
        found = self.module.candidate_paths(str(self.box.main))
        self.assertEqual([Path(p).name for p in found], ["sess.jsonl"])


def tool_use(name, tool_id, **kw):
    return rec(type="assistant",
               message={"role": "assistant",
                        "content": [{"type": "tool_use", "id": tool_id,
                                     "name": name, "input": {}}]},
               **kw)


def tool_result(tool_id, **kw):
    return rec(type="user",
               message={"role": "user",
                        "content": [{"type": "tool_result", "tool_use_id": tool_id,
                                     "content": "ok"}]},
               **kw)


class TestScopeUnion(unittest.TestCase):
    """AC11 — gitBranch 일치 **OR** 파일명이 세션 id. 합집합이다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_branch_only_and_session_only_both_included(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        # 브랜치만 맞는 파일
        write_jsonl(pdir / "branch-file.jsonl",
                    [assistant_text("b", gitBranch="work", cwd=str(self.box.main))])
        # 세션만 맞는 파일 — gitBranch 는 다른 값
        write_jsonl(pdir / "SID-1234.jsonl",
                    [assistant_text("s", gitBranch="other", cwd=str(self.box.main))])
        data = self.module.collect(str(self.box.main), "work", "SID-1234")
        names = sorted(Path(e["path"]).name for e in data["entries"]
                       if e["label"] == "in-scope")
        self.assertEqual(names, ["SID-1234.jsonl", "branch-file.jsonl"])

    def test_out_of_scope_file_is_labelled_not_dropped(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        write_jsonl(pdir / "elsewhere.jsonl",
                    [assistant_text("x", gitBranch="other", cwd=str(self.box.main))])
        data = self.module.collect(str(self.box.main), "work", "SID-1234")
        labels = [e["label"] for e in data["entries"]]
        self.assertEqual(labels, ["out-of-scope"])


class TestInventoryPredicates(unittest.TestCase):
    """AC34 — 술어를 값으로 못박는다. scan 은 형식만 검증 대상이다."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.pdir = self.box.project_dir(self.box.main)
        self.addCleanup(self.box.close)

    def test_known_fixture_yields_exact_numbers(self) -> None:
        cwd = str(self.box.main)
        records = [
            assistant_text("가나다", gitBranch="work", cwd=cwd,          # 9 bytes UTF-8
                           timestamp="2026-08-02T09:11:00.000Z"),
            assistant_text("", gitBranch="work", cwd=cwd),                # 빈 블록 — 안 센다
            assistant_text("abc", gitBranch="work", cwd=cwd,              # 3 bytes
                           timestamp="2026-08-06T22:51:00.000Z"),
            rec(type="assistant", gitBranch="work", cwd=cwd,              # thinking 전용
                message={"role": "assistant",
                         "content": [{"type": "thinking", "thinking": "…"}]}),
            tool_use("AskUserQuestion", "t1", gitBranch="work", cwd=cwd),
            tool_result("t1", gitBranch="work", cwd=cwd),
            tool_use("AskUserQuestion", "t2", gitBranch="work", cwd=cwd), # 짝 없음
            tool_use("Read", "t3", gitBranch="work", cwd=cwd),            # 다른 도구
        ]
        write_jsonl(self.pdir / "s.jsonl", records)
        with (self.pdir / "s.jsonl").open("a", encoding="utf-8") as fh:
            fh.write("{ not json\n")                                      # unparsed 1

        data = self.module.collect(cwd, "work", "s")
        self.assertEqual(data["files"], 1)
        self.assertEqual(data["candidates"], 1)
        self.assertEqual(sum(data["rejected"].values()), 0)
        self.assertEqual(data["blocks"], 2)
        self.assertEqual(data["bytes"], 12)          # '가나다'(9) + 'abc'(3)
        self.assertEqual(data["decisions"], 2)
        self.assertEqual(data["unpaired"], 1)
        self.assertEqual(data["unparsed"], 1)
        self.assertEqual(data["span_min"], "2026-08-02 09:11")
        self.assertEqual(data["span_max"], "2026-08-06 22:51")

    def test_blocks_counts_blocks_not_records(self) -> None:
        """한 레코드에 text 블록이 둘이면 2다. 레코드 수로 세면 red."""
        write_jsonl(self.pdir / "s.jsonl", [
            rec(type="assistant", gitBranch="work", cwd=str(self.box.main),
                message={"role": "assistant",
                         "content": [{"type": "text", "text": "one"},
                                     {"type": "text", "text": "two"}]}),
        ])
        data = self.module.collect(str(self.box.main), "work", None)
        self.assertEqual(data["blocks"], 2)

    def test_bytes_is_utf8_length_not_record_length(self) -> None:
        """레코드 직렬화 길이가 아니라 text 문자열의 UTF-8 인코딩 길이 합이다."""
        write_jsonl(self.pdir / "s.jsonl", [
            assistant_text("한글", gitBranch="work", cwd=str(self.box.main)),
        ])
        data = self.module.collect(str(self.box.main), "work", None)
        self.assertEqual(data["bytes"], 6)

    def test_rejected_breakdown_by_reason(self) -> None:
        other = self.box.root / "devbrew-experiments"
        make_repo(other, branch="main")
        odir = self.box.project_dir(other)
        write_jsonl(odir / "x.jsonl", [assistant_text("x", gitBranch="main", cwd=str(other))])
        write_jsonl(odir / "y.jsonl",
                    [assistant_text("y", gitBranch="main",
                                    cwd=str(self.box.root / "vanished"))])
        write_jsonl(odir / "z.jsonl", [assistant_text("z", gitBranch="main")])
        data = self.module.collect(str(self.box.main), "work", None)
        self.assertEqual(data["rejected"]["other-repo"], 1)
        self.assertEqual(data["rejected"]["cwd-gone"], 1)
        self.assertEqual(data["rejected"]["cwd-missing"], 1)
        self.assertEqual(data["candidates"], 0)


class TestPerFileInScopeCount(unittest.TestCase):
    """AC42 — 파일마다 **그 파일의 in-scope 레코드 수**를 낸다.

    한 세션이 여러 브랜치에 걸치면(이 리포에서 실제로 일어난다) 파일을 통째로
    세는 순간 인벤토리 숫자와 에이전트가 본 것이 어긋난다.
    """

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_mixed_branch_file_reports_in_scope_count(self) -> None:
        pdir = self.box.project_dir(self.box.main)
        cwd = str(self.box.main)
        write_jsonl(pdir / "mixed.jsonl", [
            assistant_text("a", gitBranch="work", cwd=cwd),
            assistant_text("b", gitBranch="work", cwd=cwd),
            assistant_text("c", gitBranch="main", cwd=cwd),
            assistant_text("d", gitBranch="main", cwd=cwd),
            assistant_text("e", gitBranch="main", cwd=cwd),
        ])
        data = self.module.collect(cwd, "work", None)
        entry = data["entries"][0]
        self.assertEqual(entry["in_scope"], 2)
        self.assertEqual(entry["total"], 5)


class TestRender(unittest.TestCase):
    """AC46 — scope 줄 + 세 블록 + listed. 라벨·수·기간이 계약대로."""

    def setUp(self) -> None:
        self.box = Sandbox()
        os.environ["HOME"] = str(self.box.home)
        self.module = load_script()
        self.pdir = self.box.project_dir(self.box.main)
        self.addCleanup(self.box.close)

    def render(self, session_id=None):
        data = self.module.collect(str(self.box.main), "work", session_id)
        return self.module.render_inventory(str(self.box.main), "work", session_id, data)

    def test_scope_line_has_three_fields(self) -> None:
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        first = self.render().splitlines()[0]
        self.assertTrue(first.startswith("scope:"))
        for field in ("repo=", "branch=", "+session="):
            self.assertIn(field, first)

    def test_three_block_labels_always_present(self) -> None:
        """빈 블록도 라벨을 낸다 — 데이터에 따라 계약이 갈리면 안 된다."""
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        out = self.render()
        self.assertIn("in-scope — ", out)
        self.assertIn("out-of-scope — ", out)
        self.assertIn("out-of-scope 디렉토리 집계 — ", out)

    def test_in_scope_lines_carry_count_and_span(self) -> None:
        write_jsonl(self.pdir / "mixed.jsonl", [
            assistant_text("a", gitBranch="work", cwd=str(self.box.main),
                           timestamp="2026-08-02T09:11:00.000Z"),
            assistant_text("b", gitBranch="main", cwd=str(self.box.main),
                           timestamp="2026-08-06T22:51:00.000Z"),
        ])
        line = [ln for ln in self.render().splitlines() if "mixed.jsonl" in ln][0]
        self.assertIn("1건", line)              # 전체 2가 아니라 in-scope 1
        self.assertIn("2026-08-02 09:11", line)

    def test_out_of_scope_capped_at_twenty_and_listed_reflects_it(self) -> None:
        """후보 25개 → out-of-scope 줄 20개 + listed 가 잘림을 반영."""
        for i in range(25):
            write_jsonl(self.pdir / ("f%02d.jsonl" % i),
                        [assistant_text("x", gitBranch="other", cwd=str(self.box.main),
                                        timestamp="2026-08-%02dT10:00:00.000Z" % (i + 1))])
        out = self.render()
        listed_lines = [ln for ln in out.splitlines() if ln.startswith("  ") and ".jsonl" in ln]
        self.assertEqual(len(listed_lines), 20)
        self.assertIn("listed: 20", out)

    def test_listed_counts_in_scope_plus_shown_out_of_scope(self) -> None:
        """I2 — `listed` = in-scope 전체 + out-of-scope 중 보인 것(캡 안).

        in-scope 가 0인 픽스처로는 이 덧셈이 실제로 검증되지 않는다 —
        `listed = len(shown)` 로 그 항을 통째로 빼도 같은 값이 나와 통과해버린다
        (실측: 187행). 최소 하나는 in-scope 로 둬 그 항이 실제로 더해지는지 잰다.
        """
        write_jsonl(self.pdir / "mine-a.jsonl",
                    [assistant_text("m", gitBranch="work", cwd=str(self.box.main))])
        write_jsonl(self.pdir / "mine-b.jsonl",
                    [assistant_text("m", gitBranch="work", cwd=str(self.box.main))])
        for i in range(23):
            write_jsonl(self.pdir / ("other%02d.jsonl" % i),
                        [assistant_text("x", gitBranch="other", cwd=str(self.box.main),
                                        timestamp="2026-08-%02dT10:00:00.000Z" % (i + 1))])
        out = self.render()
        # in-scope 2 + out-of-scope 캡(20) = 22. 캡(len(shown))만으로는 20이 나온다 —
        # 두 수가 다르므로 in-scope 항이 실제로 더해졌는지가 이 assert 로 갈린다.
        self.assertIn("listed: 22", out)

    def test_directory_rollup_body_lines_carry_each_directorys_own_count_and_span(self) -> None:
        """I2 — 폴딩된 각 디렉토리가 헤더가 아니라 **본문 줄**에 자기 개수·기간으로 나온다.

        디렉토리를 하나만 쓰면 헤더 문구("… 뺀 나머지 N개")가 우연히 본문 줄과 같은
        숫자를 담아 헤더만으로도 통과해버린다(실측: `for directory in sorted(rollup):`
        의 몸통을 `pass` 로 통째로 바꿔도 187행 전부 green). 최소 두 디렉토리로 갈라
        본문 줄이 실제로 그 디렉토리 고유의 개수·기간을 담는지 잰다.
        """
        main_dir = self.box.project_dir(self.box.main)
        wt_dir = self.box.project_dir(self.box.worktree)
        # 20개는 최근 날짜 — 캡 안에 들어 "보임" 처리된다(폴딩 대상이 아니다).
        for i in range(20):
            write_jsonl(main_dir / ("shown%02d.jsonl" % i),
                        [assistant_text("x", gitBranch="other", cwd=str(self.box.main),
                                        timestamp="2026-08-%02dT10:00:00.000Z" % (i + 1))])
        # 폴딩 대상 — main_dir 2개 + wt_dir 1개. 더 오래된 날짜라 캡 밖으로 밀린다.
        write_jsonl(main_dir / "old-a.jsonl",
                    [assistant_text("x", gitBranch="other", cwd=str(self.box.main),
                                    timestamp="2026-07-01T10:00:00.000Z")])
        write_jsonl(main_dir / "old-b.jsonl",
                    [assistant_text("x", gitBranch="other", cwd=str(self.box.main),
                                    timestamp="2026-07-02T10:00:00.000Z")])
        write_jsonl(wt_dir / "old-c.jsonl",
                    [assistant_text("x", gitBranch="other", cwd=str(self.box.worktree),
                                    timestamp="2026-07-03T10:00:00.000Z")])
        out = self.render()
        rollup = out.split("out-of-scope 디렉토리 집계")[1]
        body_lines = [ln for ln in rollup.splitlines() if ln.startswith("  ")]

        def line_for(directory):
            # 디렉토리 경로 뒤에 다른 워크트리 경로가 접두사로 겹칠 수 있으므로
            # ("…/devbrew" 는 "…/devbrew/.claude/worktrees/wt" 의 접두사다)
            # 부분 포함이 아니라 "그 줄의 디렉토리 필드가 정확히 이것"으로 잰다.
            return [ln for ln in body_lines
                    if ln.split("   ", 1)[0].strip() == str(directory)]

        main_lines = line_for(main_dir)
        wt_lines = line_for(wt_dir)
        self.assertEqual(len(main_lines), 1, body_lines)
        self.assertEqual(len(wt_lines), 1, body_lines)
        self.assertIn("2개", main_lines[0])
        self.assertIn("1개", wt_lines[0])
        self.assertIn("2026-07-01", main_lines[0])
        self.assertIn("2026-07-03", wt_lines[0])

    def test_directory_rollup_line_present_when_truncated(self) -> None:
        for i in range(25):
            write_jsonl(self.pdir / ("f%02d.jsonl" % i),
                        [assistant_text("x", gitBranch="other", cwd=str(self.box.main))])
        out = self.render()
        rollup = out.split("out-of-scope 디렉토리 집계")[1]
        self.assertIn("5개", rollup)            # 25 - 20 = 5

    def test_rejected_breakdown_is_always_rendered(self) -> None:
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        out = self.render()
        for reason in ("other-repo:", "cwd-gone:", "cwd-missing:"):
            self.assertIn(reason, out)

    def test_no_conversation_body_in_output(self) -> None:
        """출력에 없는 것 — 대화 본문 일체."""
        write_jsonl(self.pdir / "s.jsonl", [
            assistant_text("비밀문장-DO-NOT-LEAK", gitBranch="work",
                           cwd=str(self.box.main)),
        ])
        self.assertNotIn("비밀문장-DO-NOT-LEAK", self.render())

    def test_scan_format_only(self) -> None:
        """scan 은 정확값이 아니라 형식만 검증 대상이다 — 음수 아닌 수 + `s`."""
        write_jsonl(self.pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        value = self.render().split("scan:")[1].split()[0]
        self.assertTrue(value.endswith("s"), value)
        self.assertGreaterEqual(float(value[:-1]), 0.0)


class TestCodeState(unittest.TestCase):
    """AC20 — 코드 상태는 트랜스크립트가 아니라 git 에서 온다(양방향)."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.module = load_script()
        self.addCleanup(self.box.close)

    def test_positive_git_present(self) -> None:
        """D8 양의 짝 — git 이 있으면 실제 log/diff 결과가 들어간다."""
        (self.box.main / "new.txt").write_text("x\n", encoding="utf-8")
        git("add", "-A", cwd=self.box.main)
        git("commit", "-qm", "add new.txt", cwd=self.box.main)
        block = self.module.render_code_state(str(self.box.main))
        self.assertIn("## 코드 상태", block)
        self.assertIn("add new.txt", block)
        self.assertNotIn("git 조회 실패", block)

    def test_negative_git_absent(self) -> None:
        """git 없는 픽스처 — 그 자리에 한 줄이 들어가고 인벤토리는 정상."""
        plain = self.box.root / "not-a-repo"
        plain.mkdir()
        block = self.module.render_code_state(str(plain))
        self.assertIn("## 코드 상태", block)
        self.assertIn("git 조회 실패", block)


class TestExitCodes(unittest.TestCase):
    """종료 코드 0 / 3 / 4 + 실패 시 STANDUP-UNAVAILABLE 한 줄."""

    def setUp(self) -> None:
        self.box = Sandbox()
        self.addCleanup(self.box.close)

    def run_script(self, cwd, session_id="none", env=None):
        merged = dict(os.environ)
        merged["HOME"] = str(self.box.home)
        merged.update(env or {})
        proc = subprocess.run(
            [sys.executable, str(SCRIPT), "--session-id", session_id],
            cwd=str(cwd), stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=merged)
        return proc.returncode, proc.stdout.decode("utf-8")

    def test_no_target_files_exits_three(self) -> None:
        rc, out = self.run_script(self.box.main)
        self.assertEqual(rc, 3)
        self.assertTrue(out.startswith("STANDUP-UNAVAILABLE: session file not found"))
        self.assertIn("~/.claude/projects", out)

    def test_normal_run_exits_zero(self) -> None:
        module = load_script()
        pdir = self.box.projects / module.slug(str(self.box.main))
        pdir.mkdir(parents=True, exist_ok=True)
        write_jsonl(pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        rc, out = self.run_script(self.box.main)
        self.assertEqual(rc, 0)
        self.assertTrue(out.startswith("scope:"))

    def test_bare_repo_reports_unresolved_repo_not_missing_files(self) -> None:
        """센티널 충돌의 실물 진입로 — bare 리포에서 우리 쪽이 미해결이 된다.

        `git rev-parse --git-common-dir` 가 bare 에서 `.` 을 주므로 `repo_root`
        는 **부모**로 올라가고, 그 부모는 리포가 아니라 `git_common_dir` 가
        `None` 이다. 그 상태로 스캔하면 남의 트랜스크립트가 전부 채택된다.

        메시지도 함께 잠근다 — *"session file not found"* 로 강등하면 사용자는
        원인을 파일 부재로 읽고 진짜 원인(리포 미해결)을 영영 못 본다.
        """
        bare = self.box.root / "b.git"
        subprocess.run(["git", "init", "--bare", "-q", str(bare)], check=True)
        # 남의 트랜스크립트를 부모 슬러그 아래 심어 둔다 — 충돌이 살아 있으면
        # 이것이 채택되어 rc 0 과 정상 `scope:` 줄이 나온다.
        #
        # cwd 는 **해석 불가**여야 한다. 살아 있는 남의 git 리포를 쓰면
        # `git_common_dir` 가 실제 경로를 주어 `None` 과 비교되지 않고, 충돌
        # 경로를 한 번도 안 탄 채 이 락이 다른 이유로 red 가 된다.
        module = load_script()
        pdir = self.box.projects / module.slug(str(self.box.root))
        pdir.mkdir(parents=True, exist_ok=True)
        write_jsonl(pdir / "x.jsonl",
                    [assistant_text("남의 작업", gitBranch="main",
                                    cwd=str(self.box.root / "long-gone-clone"))])

        rc, out = self.run_script(bare)
        self.assertEqual(rc, 3, out)
        lines = out.splitlines()
        self.assertEqual(len(lines), 1, out)
        self.assertTrue(lines[0].startswith("STANDUP-UNAVAILABLE:"), out)
        self.assertNotIn("session file not found", out)
        self.assertNotIn("scope:", out)

    def test_not_a_git_repo_exits_three(self) -> None:
        """Finding 4 — main() 의 `repo_root(cwd) is None` 갈래는 새 코드인데 테스트가 없었다."""
        plain = self.box.root / "not-a-repo"
        plain.mkdir()
        rc, out = self.run_script(plain)
        self.assertEqual(rc, 3)
        lines = out.splitlines()
        self.assertEqual(len(lines), 1)
        self.assertTrue(lines[0].startswith("STANDUP-UNAVAILABLE:"))
        self.assertNotIn("scope:", out)

    def test_commits_agrees_with_code_state_with_base_ref(self) -> None:
        """Finding 1 회귀 락 — base-ref 있음. `commits:` 가 base..HEAD 커밋 수와 일치하고
        `## 코드 상태` 블록이 정말 그 base..HEAD 범위를 보여준다.

        Sandbox 자체는 건드리지 않는다 — main 브랜치는 이 테스트 안에서만 만든다.
        """
        module = load_script()
        # main 을 현재 HEAD(= "seed" 커밋)에 만들어 두고, 체크아웃은 그대로 "work" 에
        # 둔 채 그 위에 커밋 두 개를 더 쌓는다 — merge-base(HEAD, main) == seed.
        git("branch", "main", cwd=self.box.main)
        (self.box.main / "a.txt").write_text("a\n", encoding="utf-8")
        git("add", "-A", cwd=self.box.main)
        git("commit", "-qm", "add a.txt", cwd=self.box.main)
        (self.box.main / "b.txt").write_text("b\n", encoding="utf-8")
        git("add", "-A", cwd=self.box.main)
        git("commit", "-qm", "add b.txt", cwd=self.box.main)

        pdir = self.box.projects / module.slug(str(self.box.main))
        pdir.mkdir(parents=True, exist_ok=True)
        write_jsonl(pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        rc, out = self.run_script(self.box.main)
        self.assertEqual(rc, 0)

        commits = int(out.split("commits:")[1].split()[0])
        self.assertEqual(commits, 2)
        # base..HEAD 범위 — seed 는 base 자신이라 빠지고, 두 새 커밋만 나온다.
        self.assertIn("add a.txt", out)
        self.assertIn("add b.txt", out)
        log_block = out.split("$ git log --oneline")[1].split("\n\n")[0]
        self.assertNotIn("seed", log_block)
        self.assertNotIn("-20", out.split("$ git log --oneline")[1].split("\n")[0])

    def test_commits_agrees_with_code_state_without_base_ref(self) -> None:
        """Finding 1 회귀 락 — base-ref 없음(-20 강등). 원래 버그가 정확히 이 조건에서
        났다: `commits:` 는 늘 0 인데 바로 아래 블록엔 실제 커밋이 나열됐다.

        Sandbox 는 "main"/"origin/main" 을 만들지 않으므로 별도 설정 없이 이 조건이다.
        """
        module = load_script()
        (self.box.main / "a.txt").write_text("a\n", encoding="utf-8")
        git("add", "-A", cwd=self.box.main)
        git("commit", "-qm", "add a.txt", cwd=self.box.main)

        pdir = self.box.projects / module.slug(str(self.box.main))
        pdir.mkdir(parents=True, exist_ok=True)
        write_jsonl(pdir / "s.jsonl",
                    [assistant_text("a", gitBranch="work", cwd=str(self.box.main))])
        rc, out = self.run_script(self.box.main)
        self.assertEqual(rc, 0)

        commits = int(out.split("commits:")[1].split()[0])
        self.assertGreater(commits, 0)          # 버그였다면 여기서 0 이 나왔다
        self.assertEqual(commits, 2)             # seed + add a.txt
        self.assertIn("seed", out)
        self.assertIn("add a.txt", out)
        self.assertIn("(base-ref 를 구하지 못해 최근 20개 커밋으로 강등)", out)

    def test_exit_four_handler_survives_unprintable_message(self) -> None:
        """Finding 2 회귀 락 — 예외 메시지에 홑 서로게이트가 있어도 실패 경로가 죽지 않는다.

        `UnicodeEncodeError` 자체의 `str()` 은 escape 되어 ASCII-safe 하다(Task 7
        원 리포트의 rc=4 재현이 이 경로를 뚫지 못했던 이유). 여기서는 단일-인자
        `Exception.__str__()` 이 인자를 그대로 돌려주는 성질을 이용해, 원문 홑
        서로게이트를 **그대로** 담은 예외를 직접 구성한다. 서브프로세스로는 그런
        예외를 결정론적으로 주입할 방법이 없어(환경변수/인자 경계에서 인코딩이
        먼저 걸린다) 여기서는 실제 stdout 과 같은 규율(UTF-8, strict)의 스트림에
        in-process 로 강제 write 시켜 같은 실패 조건을 재현한다.
        """
        module = load_script()
        original_collect = module.collect

        def boom(*_args, **_kwargs):
            raise RuntimeError("\udc80 내부 오류")

        module.collect = boom
        self.addCleanup(setattr, module, "collect", original_collect)

        buf = io.BytesIO()
        fake_stdout = io.TextIOWrapper(buf, encoding="utf-8", errors="strict")
        original_stdout = module.sys.stdout
        prev_cwd = os.getcwd()
        os.chdir(str(self.box.main))
        module.sys.stdout = fake_stdout
        try:
            rc = module.main(["--session-id", "none"])
            fake_stdout.flush()
        finally:
            module.sys.stdout = original_stdout
            os.chdir(prev_cwd)

        out = buf.getvalue().decode("utf-8")
        self.assertEqual(rc, 4)
        self.assertEqual(out.count("\n"), 1)
        self.assertTrue(out.startswith("STANDUP-UNAVAILABLE: internal error"))


if __name__ == "__main__":
    unittest.main()
