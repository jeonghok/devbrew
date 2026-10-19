"""A20 — Bash 로 쓴 파일이 `/quality-gates:quality-pipeline` 기본 scope 에 들어간다.

설계 §12 는 A20 을 헤드리스 턴으로 재라고 적었고, 그 측정은 여기서 대체하지 않는다.
이 락이 재는 것은 **그 결과를 참으로 만드는 메커니즘**이다: 기본 scope 가 git 에서
도출되면 git 은 어느 도구가 썼는지 묻지 않으므로 Bash 로 쓴 파일이 자동으로 들어온다.

세 축 모두 **∃-존재검사가 아니라 ∀-지배관계**이고, 비교 집합은 열거하지 않고 도출한다.

  축 1 — SKILL 이 부르는 리뷰 diff 스크립트를 **그대로 실행**한다. 스크립트는 SKILL.md 의
         문구가 아니라 **구조**(```bash 펜스 안에서 `review-diff.sh` 를 부르는 줄 — Step 1c)
         에서 뽑고, 그 줄의 모드 자리에 session 이 있는지 본다. 실제 인자는 자리표시가 아니라
         Step 1 창 안 1c 표의 session 행에서 읽는다(그 행이 기본 scope 를 정한다). 그
         인자로 스크립트를 돌린 경로 집합을, **다른 git 표면**(`git log --name-only` + `git status
         --porcelain`)으로 독립 계산한 오라클과 **집합 상등**으로 비교한다 — 기대값이
         런타임 도출이라 상수로 만족시킬 수 없다. 리뷰어가 받는 걸러진 diff 에도 셸로 쓴
         파일이 전부 있어야 한다. 픽스처의 모든 변경은 오직 셸로만 만든다(heredoc ·
         리다이렉트 · `sed -i`) — 그것이 A20 의 조건 자체다.

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
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parents[1]
SKILL = PLUGIN_ROOT / "skills" / "quality-pipeline" / "SKILL.md"
GC = PLUGIN_ROOT / "scripts" / "qg-gc.py"
CHECK = PLUGIN_ROOT / "scripts" / "check-review-scope.sh"

# SKILL 의 Step 1c 줄에서 스크립트 이름과 모드 자리를 읽는다. 줄 자체는 자리표시가 있어
# 실행하지 않는다 — 이름이 가리키는 배포 스크립트를 인자 배열로 부른다.
_RD_SCRIPT = re.compile(r'"\$QG/scripts/(review-diff\.sh)"')
_RD_MODES = re.compile(r"--mode <([^>]*)>")
# 기본 scope 의 실제 인자는 펜스의 자리표시가 아니라 Step 1 창 안 1c 표의 session 행이다.
_STEP1 = re.compile(r"^### Step 1 — scope$(.*?)^### Step 1b", re.M | re.S)
_SESSION_ROW = re.compile(r"^[ \t]*\| session \| `([^`]*)` \|[ \t]*$", re.M)


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


def _skill_review_diff_calls() -> list:
    return [ln for ln in _bash_fence_lines(_read(SKILL)) if _RD_SCRIPT.search(ln)]


def _skill_session_rows() -> list:
    """Step 1 창 안 1c 표의 session 행이 적은 인자(백틱 안)."""
    m = _STEP1.search(_read(SKILL))
    return _SESSION_ROW.findall(m.group(1)) if m else []


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
                  "CLAUDE_CODE_SESSION_ID", "DEVBREW_QUALITY_GATES_DOC_PATHS"):
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


class SkillReviewDiffCoversShellWrites(unittest.TestCase):
    """축 1 — SKILL 이 부르는 리뷰 diff 스크립트가 셸-작성 변경을 전부 잡는가."""

    SHELL_WRITTEN = ("committed_by_heredoc.txt", "tracked.txt",
                     "untracked_by_redirect.txt")

    def setUp(self) -> None:
        self.fx = _ShellOnlyFixture()
        self.addCleanup(self.fx.cleanup)
        # 출력 폴더와 스크립트의 HOME 은 픽스처 리포 밖 — 안에 두면 그 자체가 untracked
        # 변경이 된다(픽스처의 HOME 은 리포 루트라, 스크립트가 부른 도구가 HOME 아래에
        # 캐시를 만들면 오라클에만 새 경로가 생긴다).
        self.out = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, str(self.out), True)
        self.home = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, str(self.home), True)

    def _session_run(self) -> dict:
        """SKILL Step 1c 의 줄에서 스크립트를 찾아 session 모드로 돌린다."""
        calls = _skill_review_diff_calls()
        # 계측기 확인 — 뽑은 게 없으면 아래 비교는 대상이 없다.
        self.assertEqual(
            len(calls), 1,
            "SKILL.md 의 ```bash 펜스에서 review-diff.sh 를 부르는 줄이 정확히 하나가 "
            "아니다 — Step 1c 가 사라졌거나 추출기가 깨졌다: %r" % (calls,))
        line = calls[0]
        modes = _RD_MODES.search(line)
        self.assertIsNotNone(modes, "Step 1c 줄에 --mode <…> 자리가 없다: %r" % (line,))
        self.assertIn("session", modes.group(1).split("|"),
                      "Step 1c 줄의 모드 자리에 session 이 없다 — 기본 scope 가 이 "
                      "스크립트를 지나지 않는다: %r" % (line,))
        script = PLUGIN_ROOT / "scripts" / _RD_SCRIPT.search(line).group(1)
        self.assertTrue(script.is_file(), "SKILL 이 부르는 스크립트가 없다: %s" % script)
        # 모드는 고정하지 않는다 — SKILL 의 session 행이 적은 인자를 그대로 쓴다. 그 행이
        # 다른 모드를 적으면 아래 집합 비교가 셸로 쓴 변경의 소실로 드러난다.
        rows = _skill_session_rows()
        self.assertEqual(
            len(rows), 1,
            "Step 1 창의 1c 표에서 session 행을 정확히 하나 찾지 못했다 — 기본 scope 의 "
            "인자를 읽을 수 없다: %r" % (rows,))
        args = rows[0].split()
        self.assertTrue(args and args[0] == "--mode" and len(args) >= 2,
                        "session 행이 --mode <값> 으로 시작하지 않는다: %r" % (rows[0],))
        self.assertFalse(any("<" in a or ">" in a for a in args),
                         "session 행의 인자에 자리표시가 남아 있다: %r" % (rows[0],))
        env = dict(self.fx.env)
        env["HOME"] = str(self.home)
        proc = subprocess.run(
            ["bash", str(script), "--dir", str(self.out), "--iter", "1"] + args,
            cwd=str(self.fx.root), env=env, capture_output=True, text=True)
        self.assertEqual(proc.returncode, 0,
                         "review-diff.sh session 이 실패했다: %s" % proc.stderr)
        fields = {}
        for ln in proc.stdout.splitlines():
            k, _, v = ln.partition(":")
            fields[k.strip()] = v.strip()
        self.assertEqual(fields.get("degraded"), "no", fields)
        return {
            "fields": fields,
            "names": _names(_read(self.out / "review-i1.names")),
            "diff": _read(self.out / "review-i1.diff"),
        }

    def test_names_equal_independently_derived_oracle(self):
        run = self._session_run()
        # 오라클은 **다른 git 표면**에서 독립 도출한다 — 스크립트의 동어반복이 아니다.
        mb = self.fx.merge_base()
        log = _git(["log", "--name-only", "--pretty=format:", "%s..HEAD" % mb],
                   self.fx.root, self.fx.env)
        status = _git(["status", "--porcelain"], self.fx.root, self.fx.env)
        oracle = _names(log.stdout) | {
            ln[3:].strip() for ln in status.stdout.splitlines() if ln.strip()
        }
        self.assertTrue(oracle, "오라클이 비었다 — 픽스처가 아무 변경도 만들지 않았다")
        self.assertEqual(
            run["names"], oracle,
            "SKILL Step 1c 의 session 경로 집합이 git 이 보고하는 변경 집합과 다르다.\n"
            "스크립트만 있는 것: %r\n오라클만 있는 것: %r"
            % (sorted(run["names"] - oracle), sorted(oracle - run["names"])))
        self.assertEqual(run["fields"].get("files"), str(len(oracle)), run["fields"])

    def test_each_shell_write_mechanism_reaches_reviewers(self):
        """∀ 셸-작성 파일 ∈ 경로 집합 ∧ 걸러진 diff, 그리고 무시된 파일 ∉ 둘 다."""
        run = self._session_run()
        for written in self.SHELL_WRITTEN:
            self.assertIn(written, run["names"],
                          "셸로 쓴 %s 가 기본 scope 에서 빠졌다 (A20 위반)" % written)
            self.assertIn("+++ b/%s" % written, run["diff"].splitlines(),
                          "셸로 쓴 %s 가 리뷰어가 받는 diff 에서 빠졌다 (A20 위반)" % written)
        self.assertNotIn("build/artifact.bin", run["names"],
                         "gitignore 된 파일이 scope 에 들어왔다")
        self.assertNotIn("build/artifact.bin", run["diff"],
                         "gitignore 된 파일이 리뷰 diff 에 들어왔다")


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
