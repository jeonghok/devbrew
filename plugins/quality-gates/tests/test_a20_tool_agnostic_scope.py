"""A20 — Bash 로 쓴 파일이 `/qg` 기본 scope 에 들어간다.

설계 §12 는 A20 을 헤드리스 턴으로 재라고 적었고, 그 측정은 여기서 대체하지 않는다.
이 락이 재는 것은 **그 결과를 참으로 만드는 메커니즘**이다: 기본 scope 가 git 에서
도출되면 git 은 어느 도구가 썼는지 묻지 않으므로 Bash 로 쓴 파일이 자동으로 들어온다.

세 축 모두 **∃-존재검사가 아니라 ∀-지배관계**이고, 비교 집합은 열거하지 않고 도출한다.

  축 1 — SKILL 이 말하는 질의를 **그대로 실행**한다. 질의 목록은 SKILL.md 의 문구가
         아니라 **구조**(```bash 펜스 안에서 `git ` 로 시작하는 줄)에서 뽑는다. 그
         질의들의 합집합을, **다른 git 표면**(`git log --name-only` + `git status
         --porcelain`)으로 독립 계산한 오라클과 **집합 상등**으로 비교한다 — 기대값이
         런타임 도출이라 상수로 만족시킬 수 없다. 픽스처의 모든 변경은 오직 셸로만
         만든다(heredoc · 리다이렉트 · `sed -i`) — 그것이 A20 의 조건 자체다.

  축 2 — 배포되는 결정론 신호(`scripts/check-review-scope.sh`)가 그 셸-작성 변경을
         본다. `branch_ahead_count` 의 기대값도 git 에서 런타임 도출한다. 상수-yes
         락이 되지 않도록 **아무 변경 없는 픽스처**를 양성 대조로 함께 돌린다.

  축 3 — 은퇴한 세션 산출물이 모델이 읽는 표면으로 돌아오지 않는다. 비교 집합
         (그 산출물의 이름들)은 이 파일에 적지 않고 `scripts/qg-gc.py` 의
         `LEGACY_SESSION_MARKERS` 에서 읽는다 — 회수 마커 목록이 곧 「4.x 가 남긴
         세션 산출물」의 분포다. 새 이름이 그 목록에 들어오면 이 축이 자동으로 넓어진다.
         (원래 브리프의 검사가 자기 본문의 리터럴을 스스로 매치해 성립할 수 없었던
         문제도 이렇게 사라진다 — 리터럴이 이 파일에 없다.)
"""
from __future__ import annotations

import ast
import io
import os
import re
import shlex
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
SKILL = PLUGIN_ROOT / "skills" / "quality-pipeline" / "SKILL.md"
GC = PLUGIN_ROOT / "scripts" / "qg-gc.py"
CHECK = PLUGIN_ROOT / "scripts" / "check-review-scope.sh"

# 셸 메타문자가 섞인 줄은 실행하지 않는다. 이 락은 피검자(SKILL.md)의 텍스트를
# 실행하므로, 실행 대상은 인자 배열로만 넘길 수 있는 순수 git 호출로 제한한다.
_UNSAFE = re.compile(r"[;|&`><]|\$\(")


def _read(path: Path) -> str:
    with io.open(path, encoding="utf-8") as fh:
        return fh.read()


def _bash_fence_lines(md: str) -> list:
    """```bash 펜스 안의 줄들. 앵커는 문구가 아니라 펜스라는 **구조**다."""
    lines, lang = [], None
    for raw in md.splitlines():
        stripped = raw.strip()
        if stripped.startswith("```"):
            lang = None if lang is not None else (stripped[3:].strip().lower() or "-")
            continue
        if lang == "bash":
            lines.append(stripped)
    return lines


def _skill_git_queries() -> list:
    return [ln for ln in _bash_fence_lines(_read(SKILL)) if ln.startswith("git ")]


def _legacy_markers() -> tuple:
    """`qg-gc.py` 의 LEGACY_SESSION_MARKERS 를 소스에서 읽는다 (import 하지 않는다 —
    그 모듈은 import 시점에 형제 스크립트를 sys.path 로 끌어온다)."""
    tree = ast.parse(_read(GC))
    for node in tree.body:
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == "LEGACY_SESSION_MARKERS":
                return tuple(ast.literal_eval(node.value))
    raise AssertionError(
        "qg-gc.py 에서 LEGACY_SESSION_MARKERS 를 찾지 못했다 — 이 락의 비교 집합이 "
        "사라졌다(계측기 고장). 이름이 바뀌었다면 이 파일도 같은 커밋에서 고쳐라."
    )


def _git(args, cwd, env):
    return subprocess.run(["git"] + list(args), cwd=cwd, env=env,
                          capture_output=True, text=True)


def _names(text: str) -> set:
    return {ln.strip() for ln in text.splitlines() if ln.strip()}


class _ShellOnlyFixture:
    """모든 변경을 **셸로만** 만드는 throwaway 리포. A20 의 전제 자체다."""

    def __init__(self, with_changes: bool = True) -> None:
        self.root = Path(tempfile.mkdtemp())
        self.env = dict(os.environ)
        for k in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE",
                  "CLAUDE_CODE_SESSION_ID"):
            self.env.pop(k, None)
        self.env["HOME"] = str(self.root)
        self.env["GIT_CONFIG_NOSYSTEM"] = "1"
        self._build(with_changes)

    def sh(self, script: str) -> None:
        proc = subprocess.run(["bash", "-c", script], cwd=str(self.root),
                              env=self.env, capture_output=True, text=True)
        assert proc.returncode == 0, f"fixture 셸 실패: {script}\n{proc.stderr}"

    def _build(self, with_changes: bool) -> None:
        self.sh("git init -q . && git symbolic-ref HEAD refs/heads/main")
        self.sh("git config user.email t@t.test && git config user.name tester")
        # base — 전부 heredoc/리다이렉트로 쓴다.
        self.sh(
            "cat > seed.txt <<'EOF'\nseed\nEOF\n"
            "printf 'x\\n' > tracked.txt\n"
            "printf 'build/\\n' > .gitignore\n"
            "git add -A && git commit -qm base"
        )
        self.sh("git checkout -q -b feature")
        if not with_changes:
            return
        # (a) 커밋된 변경 — Bash heredoc 으로 쓴 새 파일.
        self.sh(
            "cat > committed_by_heredoc.txt <<'EOF'\nheredoc write\nEOF\n"
            "git add -A && git commit -qm feat"
        )
        # (b) tracked 미커밋 — `sed -i` 로 제자리 편집.
        self.sh("sed -i.bak 's/x/y/' tracked.txt && rm -f tracked.txt.bak")
        # (c) 무시되지 않은 untracked — 리다이렉트.
        self.sh("printf 'new\\n' > untracked_by_redirect.txt")
        # 무시되는 파일 — scope 에 **들어오면 안 된다**.
        self.sh("mkdir -p build && printf 'junk\\n' > build/artifact.bin")

    def merge_base(self) -> str:
        return _git(["merge-base", "main", "HEAD"], self.root, self.env).stdout.strip()

    def cleanup(self) -> None:
        shutil.rmtree(self.root, ignore_errors=True)


class SkillQueriesCoverShellWrites(unittest.TestCase):
    """축 1 — SKILL 이 적어 둔 질의를 실행해 셸-작성 변경을 전부 잡는가."""

    def setUp(self) -> None:
        self.fx = _ShellOnlyFixture()
        self.addCleanup(self.fx.cleanup)

    def test_union_equals_independently_derived_oracle(self):
        queries = _skill_git_queries()
        # 계측기 확인 — 뽑은 게 없으면 아래 합집합은 공허하게 무엇이든 만족시킨다.
        self.assertGreaterEqual(
            len(queries), 3,
            "SKILL.md 의 ```bash 펜스에서 git 질의를 3개 미만 뽑았다 — Step 1 의 "
            "도출이 사라졌거나 추출기가 깨졌다: %r" % (queries,))
        for q in queries:
            self.assertIsNone(_UNSAFE.search(q),
                              "실행 불가한 셸 메타문자가 섞인 질의: %r" % (q,))

        env = dict(self.fx.env)
        env["MERGE_BASE"] = self.fx.merge_base()
        union = set()
        for q in queries:
            argv = [
                tok.replace("${MERGE_BASE}", env["MERGE_BASE"])
                   .replace("$MERGE_BASE", env["MERGE_BASE"])
                for tok in shlex.split(q, comments=True)
            ]
            proc = subprocess.run(argv, cwd=str(self.fx.root), env=env,
                                  capture_output=True, text=True)
            self.assertEqual(proc.returncode, 0,
                             "SKILL 의 질의가 실행되지 않는다: %r\n%s"
                             % (q, proc.stderr))
            union |= _names(proc.stdout)

        # 오라클은 **다른 git 표면**에서 독립 도출한다 — 위 질의의 동어반복이 아니다.
        log = _git(["log", "--name-only", "--pretty=format:",
                    "%s..HEAD" % env["MERGE_BASE"]], self.fx.root, self.fx.env)
        status = _git(["status", "--porcelain"], self.fx.root, self.fx.env)
        oracle = _names(log.stdout) | {
            ln[3:].strip() for ln in status.stdout.splitlines() if ln.strip()
        }
        self.assertTrue(oracle, "오라클이 비었다 — 픽스처가 아무 변경도 만들지 않았다")
        self.assertEqual(
            union, oracle,
            "SKILL Step 1 의 질의 합집합이 git 이 보고하는 변경 집합과 다르다.\n"
            "질의만 있는 것: %r\n오라클만 있는 것: %r"
            % (sorted(union - oracle), sorted(oracle - union)))

    def test_each_shell_write_mechanism_is_in_scope(self):
        """∀ 셸-작성 파일 ∈ 합집합, 그리고 무시된 파일 ∉ 합집합."""
        env = dict(self.fx.env)
        env["MERGE_BASE"] = self.fx.merge_base()
        union = set()
        for q in _skill_git_queries():
            argv = [
                tok.replace("${MERGE_BASE}", env["MERGE_BASE"])
                   .replace("$MERGE_BASE", env["MERGE_BASE"])
                for tok in shlex.split(q, comments=True)
            ]
            proc = subprocess.run(argv, cwd=str(self.fx.root), env=env,
                                  capture_output=True, text=True)
            union |= _names(proc.stdout)
        for written in ("committed_by_heredoc.txt", "tracked.txt",
                        "untracked_by_redirect.txt"):
            self.assertIn(written, union,
                          "셸로 쓴 %s 가 기본 scope 에서 빠졌다 (A20 위반)" % written)
        self.assertNotIn("build/artifact.bin", union,
                         "gitignore 된 파일이 scope 에 들어왔다")


class ShippedSignalSeesShellWrites(unittest.TestCase):
    """축 2 — 배포되는 `check-review-scope.sh` 가 셸-작성 변경을 본다."""

    @staticmethod
    def _fields(root: Path, env: dict) -> dict:
        proc = subprocess.run(["bash", str(CHECK)], cwd=str(root), env=env,
                              capture_output=True, text=True)
        assert proc.returncode == 0, proc.stderr
        out = {}
        for ln in proc.stdout.splitlines():
            if ":" in ln:
                k, _, v = ln.partition(":")
                out[k.strip()] = v.strip()
        return out

    def test_counts_match_git_not_a_constant(self):
        fx = _ShellOnlyFixture()
        self.addCleanup(fx.cleanup)
        f = self._fields(fx.root, fx.env)
        self.assertEqual(f.get("degraded"), "no", f)
        self.assertEqual(f.get("changes_exist"), "yes", f)
        self.assertEqual(f.get("worktree_dirty"), "yes", f)
        expected = len(_names(_git(
            ["diff", "--name-only", "%s..HEAD" % fx.merge_base()],
            fx.root, fx.env).stdout))
        self.assertGreater(expected, 0, "픽스처가 커밋된 변경을 만들지 못했다")
        self.assertEqual(int(f.get("branch_ahead_count", "-1")), expected,
                         "branch_ahead_count 가 git 의 답과 다르다: %r" % (f,))

    def test_clean_fixture_reports_no_changes(self):
        """양성 대조 — 상수-yes 락이 아니다."""
        fx = _ShellOnlyFixture(with_changes=False)
        self.addCleanup(fx.cleanup)
        f = self._fields(fx.root, fx.env)
        self.assertEqual(f.get("degraded"), "no", f)
        self.assertEqual(f.get("changes_exist"), "no", f)


class RetiredSessionArtifactStaysGone(unittest.TestCase):
    """축 3 — 은퇴한 세션 산출물이 모델이 읽는 표면으로 돌아오지 않는다."""

    CORPUS_DIRS = ("skills", "commands", "agents", "hooks", "scripts")

    def _corpus(self) -> list:
        files = []
        for sub in self.CORPUS_DIRS:
            files += [p for p in (PLUGIN_ROOT / sub).rglob("*")
                      if p.is_file() and p.resolve() != GC.resolve()]
        return files

    def test_markers_absent_from_model_read_surface(self):
        markers = _legacy_markers()
        self.assertTrue(markers, "LEGACY_SESSION_MARKERS 가 비었다 — 이 축이 공허해진다")
        corpus = self._corpus()
        self.assertGreater(len(corpus), 20,
                           "코퍼스가 비정상적으로 작다 — 글롭이 깨졌다")
        hits = []
        for marker in markers:
            pat = re.compile(r"(?<![\w.-])" + re.escape(marker))
            for path in corpus:
                try:
                    text = _read(path)
                except (OSError, UnicodeDecodeError):
                    continue
                if pat.search(text):
                    hits.append("%s → %s" % (path.relative_to(PLUGIN_ROOT), marker))
        self.assertEqual(hits, [], "은퇴한 세션 산출물이 살아있는 표면에 있다:\n"
                                   + "\n".join(hits))

    def test_detector_actually_detects(self):
        """계측기 확인 — 같은 탐지기가 회수 마커의 **출처**에서는 히트를 낸다."""
        markers = _legacy_markers()
        text = _read(GC)
        for marker in markers:
            pat = re.compile(r"(?<![\w.-])" + re.escape(marker))
            self.assertIsNotNone(
                pat.search(text),
                "탐지기가 qg-gc.py 안의 %r 조차 못 찾는다 — 위 부재 단언이 공허하다"
                % (marker,))


if __name__ == "__main__":
    unittest.main()
