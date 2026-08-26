#!/usr/bin/env python3
"""Stop 훅 흡수 — A4(import) · A10(순서) · A11(block 단일) · A13(기아 없음) · A16(git 불능)."""
import ast
import contextlib
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
from unittest import mock

REPO = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())
HOOK = REPO / "plugins" / "spec-distill" / "hooks" / "review-dispatch.py"
sys.path.insert(0, str(REPO / "plugins" / "spec-distill" / "scripts"))
spec = importlib.util.spec_from_file_location("rd", HOOK)
rd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rd)


class TestNoParserSubprocess(unittest.TestCase):
    """A4 — 파서를 subprocess 로 부르지 않는다. 발견 모듈의 git 호출은 별도 파일이다."""

    def test_hook_has_no_subprocess_call(self):
        tree = ast.parse(HOOK.read_text(encoding="utf-8"))
        calls = [n for n in ast.walk(tree)
                 if isinstance(n, ast.Attribute) and n.attr in ("run", "Popen")
                 and isinstance(n.value, ast.Name) and n.value.id == "subprocess"]
        self.assertEqual(calls, [], "review-dispatch.py 에 subprocess 호출이 있다")

    def test_parser_is_imported(self):
        src = HOOK.read_text(encoding="utf-8")
        self.assertIn("parse_spec_structure", src)

    def test_positive_control_discovery_module_may_call_git(self):
        # 양성 대조 — 이 락은 발견 모듈의 git 호출을 금지하지 않는다 (GREEN 이 정답).
        dc = (REPO / "plugins/spec-distill/scripts/discover_candidates.py").read_text("utf-8")
        self.assertIn("subprocess.run", dc)


class TestOrdering(unittest.TestCase):
    """A10 — 구조 검증이 TTL 가드보다 **먼저** 돈다. AST 로 잰다."""

    def test_validation_precedes_ttl_guard(self):
        tree = ast.parse(HOOK.read_text(encoding="utf-8"))
        fn = next(n for n in tree.body
                  if isinstance(n, ast.FunctionDef) and n.name == "main")
        src_lines = {}
        for node in ast.walk(fn):
            if isinstance(node, ast.Name) and node.id == "validate_document":
                src_lines.setdefault("validate", node.lineno)
            if isinstance(node, ast.Name) and node.id == "LAST_DISPATCHED_RE":
                src_lines.setdefault("ttl", node.lineno)
        self.assertIn("validate", src_lines, "main() 이 validate_document 를 부르지 않는다")
        self.assertIn("ttl", src_lines, "main() 에 TTL 가드가 없다")
        self.assertLess(src_lines["validate"], src_lines["ttl"],
                        "TTL 가드가 구조 검증보다 앞이다 — dispatch 후 30초 동안 "
                        "Bash 로 쓴 깨진 문서의 검증이 통째로 건너뛰어진다")


class TestStarvationFree(unittest.TestCase):
    """A13 — dirty 문서가 상한보다 많아도 모든 문서가 결국 선택된다."""

    def test_cursor_rotation_reaches_every_candidate(self):
        keys = [f"docs/superpowers/specs/{c}-design.md" for c in "abcdefg"]
        seen, cursor = set(), None
        for _turn in range(10):
            picked, cursor = rd.select_keys(keys, cursor=cursor, cap=5)
            seen.update(picked)
            if seen == set(keys):
                break
        self.assertEqual(seen, set(keys),
                         "커서가 회전하지 않아 뒤쪽 문서가 굶는다")

    def test_cap_is_respected(self):
        keys = [f"docs/superpowers/specs/{c}-design.md" for c in "abcdefg"]
        picked, _ = rd.select_keys(keys, cursor=None, cap=5)
        self.assertEqual(len(picked), 5)

    def test_wrap_turn_still_fills_the_cap(self):
        """끝에 닿는 턴도 상한을 채운다 — 회전(`% len`)이 실제로 사는 자리.

        위의 `test_cursor_rotation_reaches_every_candidate` 는 이것을 재지 못한다:
        회전을 지우고 슬라이스로 잘라도 커서가 끝을 넘어가면 시작이 0 으로 되감겨
        **기아는 생기지 않는다**(측정 확인 — 7개·cap 5 에서 5·2·5·2 로 전부 덮는다).
        갈리는 것은 커버리지가 아니라 그 턴이 예산을 채우는가다: 상한은 훅 timeout 이
        허용하는 **턴 예산**이므로, 감는 턴마다 꼬리만 내면 처리량이 절반으로 떨어진다.
        """
        keys = [f"docs/superpowers/specs/{c}-design.md" for c in "abcdefg"]
        _first, cursor = rd.select_keys(keys, cursor=None, cap=5)
        picked, _ = rd.select_keys(keys, cursor=cursor, cap=5)
        self.assertEqual(
            len(picked), 5,
            f"감는 턴이 상한을 못 채운다 — 남은 꼬리만 냈다: {picked!r}")


class TestGitUnavailable(unittest.TestCase):
    """A16 — git 불능은 후보 0 과 다르다."""

    def test_reason_string_names_git(self):
        self.assertIn("git", rd.GIT_UNAVAILABLE_ADVISORY.lower())
        self.assertIn("검증", rd.GIT_UNAVAILABLE_ADVISORY)


def _make_temp_repo() -> Path:
    tmp = Path(tempfile.mkdtemp(prefix="specdistill-absorb-"))
    for args in (["init", "-q"], ["config", "user.email", "t@t.t"],
                 ["config", "user.name", "t"],
                 ["commit", "-q", "--allow-empty", "-m", "seed"]):
        subprocess.run(["git", *args], cwd=tmp, check=True, capture_output=True)
    return tmp


def _drive_main(discover_impl):
    """`discover` 를 갈아끼우고 `main()` 을 한 번 돌린다 → (예외, stdout).

    예외를 잡아 돌려주는 이유는 아래 두 케이스가 **삼켜졌는가**를 서로 반대 방향으로
    재기 때문이다. 잡지 않으면 음의 케이스가 통과 여부가 아니라 오류로 끝난다.
    stderr 도 함께 삼킨다 — 훅의 loud degradation 로그가 스위트 출력을 오염시킨다.
    """
    repo = _make_temp_repo()
    out, err = io.StringIO(), io.StringIO()
    raised = None
    try:
        with mock.patch.object(rd, "discover", discover_impl), \
             mock.patch.dict(os.environ, {
                 "DEVBREW_SPEC_DISTILL_SESSION_ID": "test-absorb-git",
             }), \
             mock.patch("sys.stdin", new=io.StringIO("{}")), \
             contextlib.redirect_stderr(err), \
             contextlib.redirect_stdout(out):
            cwd_before = os.getcwd()
            try:
                os.chdir(repo)
                rd.main()
            except BaseException as exc:  # noqa: BLE001 — 어느 예외든 기록만 한다
                raised = exc
            finally:
                os.chdir(cwd_before)
    finally:
        shutil.rmtree(repo, ignore_errors=True)
    return raised, out.getvalue()


class TestDiscoveryBugIsNotReportedAsGitUnavailable(unittest.TestCase):
    """A16 의 반대편 — 발견 모듈의 **버그**를 "git 불능" 으로 오보하면 안 된다.

    `except GitUnavailable` 을 `except Exception` 으로 넓히면 발견 모듈의 어떤 결함이든
    "git 을 쓸 수 없다" 로 둔갑하고 게이트가 조용히 꺼진다 — 이 브랜치가 없애려는
    "리뷰가 덜 되는 방향" 그 자체다. `GitUnavailable` 의 docstring 이 요구하는 구별
    (git 불능 ≠ 후보 0)은 그 반대 방향에서도 성립해야 한다: git 불능 ≠ 아무 예외.

    **두 케이스가 짝이다.** 음(버그는 삼켜지지 않는다)만 두면 try/except 를 통째로
    지워도 통과하므로, 양(진짜 git 불능은 삼켜지고 advisory 를 낸다)이 함께 있어야
    이 락에 이빨이 있다.
    """

    def test_negative_non_git_exception_is_not_swallowed(self):
        def boom(*_a, **_k):
            raise RuntimeError("발견 모듈 버그")

        raised, stdout = _drive_main(boom)
        self.assertIsInstance(
            raised, RuntimeError,
            msg=("발견 모듈의 버그가 삼켜졌다 — except 절이 GitUnavailable 보다 "
                 f"넓다. stdout={stdout!r}"),
        )
        self.assertNotIn(
            rd.GIT_UNAVAILABLE_ADVISORY, stdout,
            msg="git 과 무관한 결함을 'git 불능' 으로 오보한다",
        )

    def test_positive_git_unavailable_is_swallowed_with_advisory(self):
        def nogit(*_a, **_k):
            raise rd.GitUnavailable("not a git repository")

        raised, stdout = _drive_main(nogit)
        self.assertIsNone(
            raised, msg=f"진짜 git 불능이 훅을 죽였다: {raised!r}")
        payload = json.loads(stdout)
        self.assertEqual(
            payload.get("systemMessage"), rd.GIT_UNAVAILABLE_ADVISORY,
            msg=f"git 불능 advisory 가 나가지 않았다: {stdout!r}",
        )


if __name__ == "__main__":
    unittest.main()
