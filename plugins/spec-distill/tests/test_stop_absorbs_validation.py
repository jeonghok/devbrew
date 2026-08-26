#!/usr/bin/env python3
"""Stop 훅 흡수 — A4(import) · A10(순서) · A11(block 단일) · A13(기아 없음) · A16(git 불능)."""
# 이 박스의 python3 는 3.9 라 `Path | None` 같은 주석이 def 시점에 평가돼 TypeError 를 낸다.
from __future__ import annotations

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
import types
import unittest
from datetime import datetime, timezone
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

    #: `validate_document` 이 실제로 부르는 순수 함수 여섯. 이 집합이 곧 A4 의 내용이다.
    PARSER_NAMES = frozenset({
        "find_missing_sections", "load_blacklist", "parse_frontmatter",
        "scan_ambiguity", "scan_placeholders", "validate_locked_decisions",
    })

    def test_parser_is_imported(self):
        """A4 — 파서를 **import 로** 쓴다. 파싱한 AST 로 잰다.

        원래는 `assertIn("parse_spec_structure", src)` 였다. 그 문자열은 훅 안에
        두 번 나오는데 하나가 모듈 docstring 이라, **import 를 통째로 지워도 GREEN**
        이었다(헤더-satisfiable). 이름 여섯 개를 집합으로 요구하면 문서 산문은
        만족시킬 수 없고, 덤으로 "무엇을 import 하는가"까지 고정된다.
        """
        tree = ast.parse(HOOK.read_text(encoding="utf-8"))
        got = set()
        for n in ast.walk(tree):
            if isinstance(n, ast.ImportFrom) and n.module == "parse_spec_structure":
                got |= {a.name for a in n.names}
        self.assertEqual(
            got, set(self.PARSER_NAMES),
            msg=("review-dispatch.py 가 parse_spec_structure 의 순수 함수를 "
                 f"import 하지 않는다 (본 것: {sorted(got)})"))

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


def _drive_main(discover_impl, modules: dict | None = None):
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
             mock.patch.dict(sys.modules, modules or {}), \
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


BROKEN_REL = "docs/superpowers/specs/2026-01-01-armed-design.md"


def _repo_with_broken_scope_doc(session_id: str, ledger_block: str) -> Path:
    """Bash 로 쓴 것과 같은 상태의 깨진 스코프 문서 + 원장 블록 하나를 가진 리포.

    문서는 untracked·dirty·구조 실패(placeholder `TBD`)다 — 어떤 제외도 걸리지
    않으면 훅은 반드시 구조 block 을 낸다. 그래서 "block 이 나왔는가"가 곧
    "이 문서가 검증 후보에 들어갔는가"의 관측 가능한 대리값이 된다.
    """
    repo = _make_temp_repo()
    doc = repo / BROKEN_REL
    doc.parent.mkdir(parents=True, exist_ok=True)
    doc.write_text("# X\n\n## Goal\n\nTBD 아직.\n", encoding="utf-8")
    state = repo / ".claude" / "spec-distill" / session_id / "state.local.md"
    state.parent.mkdir(parents=True, exist_ok=True)
    state.write_text(
        f"---\nsession_id: {session_id}\n---\n\n{ledger_block}", encoding="utf-8")
    return repo


def _run_stop(repo: Path, session_id: str,
              cwd: Path | None = None) -> subprocess.CompletedProcess:
    """훅을 별도 프로세스로 돌린다. `cwd` 를 주면 리포 **하위 디렉터리**에서 돈다.

    깨끗한 env 를 쓰되 `PYTHONDONTWRITEBYTECODE` 는 부모에서 넘긴다(기본 "1").
    훅 자신은 `__main__` 이라 캐시되지 않지만 그것이 import 하는 `scripts/*.py`
    다섯은 `scripts/__pycache__/` 에 캐시된다 — 이 하니스로 검증하는 같은-길이
    변이가 stale `.pyc` 를 만나 거짓 GREEN·거짓 RED 를 낸다.
    """
    env = {
        "HOME": os.environ.get("HOME", "/tmp"),
        "PATH": os.environ["PATH"],
        "PYTHONDONTWRITEBYTECODE": os.environ.get("PYTHONDONTWRITEBYTECODE", "1"),
        "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
        "DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC": "0",
    }
    return subprocess.run(
        [sys.executable, str(HOOK)], cwd=str(cwd or repo), env=env,
        input="{}", text=True, capture_output=True, timeout=30)


class TestValidationExclusionAxes(unittest.TestCase):
    """어떤 원장이 **구조 검증**을 막고 어떤 것이 못 막는가 — 세 축을 따로 잠근다.

    `armed_paths` 의 의미는 "더 이상 **dispatch** 안 함"이지 "Layer 1 을 끈다"가
    아니다. 그것을 검증 앞에 두면 이번 세션에 리뷰를 마친 문서를 Bash 로 깨뜨렸을 때
    구조 검증이 다시 발화하지 않는다 — 쓰기 경로가 게이트를 우회한다는 이 브랜치의
    동기가 된 결함이 축소판으로 되살아나고, 방향은 Law 1 이 금지하는
    "리뷰가 덜 되는 쪽"이다. 설계 §9 의 A14 는 **검증 실패 상한**만을 검증 제외
    사유로 들고 `armed_paths` 를 한 번도 언급하지 않는다.

    **세 케이스가 한 묶음이다.** 첫째(armed 는 통과)만 두면 제외 블록을 통째로
    지워도 GREEN 이다. 나머지 둘이 그 vacuity 를 막는다 — 막아야 할 두 축은 여전히
    막는다는 양의 짝.
    """

    def _stop(self, session_id: str, ledger_block: str):
        repo = _repo_with_broken_scope_doc(session_id, ledger_block)
        self.addCleanup(shutil.rmtree, repo, True)
        r = _run_stop(repo, session_id)
        self.assertEqual(r.returncode, 0, msg=f"훅이 죽었다: {r.stderr}")
        return r

    def test_armed_document_is_still_structurally_validated(self):
        """armed 는 **검증을 막지 않는다** (R50 의 음의 방향)."""
        r = self._stop(
            "test-armed-validates", f"armed_paths:\n  - {BROKEN_REL}\n")
        self.assertTrue(
            r.stdout.strip(),
            msg=("리뷰를 마친 문서를 Bash 로 깨뜨렸는데 구조 검증이 침묵했다 — "
                 f"armed 가 Layer 1 앞을 막고 있다. stderr={r.stderr!r}"))
        payload = json.loads(r.stdout)
        self.assertEqual(payload.get("decision"), "block")
        self.assertIn(
            BROKEN_REL, payload.get("reason", ""),
            msg=f"block 은 났으나 그 문서 사유가 아니다: {payload!r}")

    def test_validation_capped_document_is_not_validated(self):
        """검증 실패 상한에 닿은 문서는 검증도 dispatch 도 없다 (A14, 양의 짝)."""
        r = self._stop(
            "test-valcap-silent",
            f"validation_attempts:\n  {BROKEN_REL}: 3\n")
        self.assertEqual(
            r.stdout.strip(), "",
            msg=f"상한에 닿은 문서가 다시 block 을 냈다 — 무한 루프다: {r.stdout!r}")
        self.assertIn(
            "구조 검증 상한", r.stderr,
            msg=f"상한 제외가 조용히 일어났다 (A14 는 advisory 를 요구한다): {r.stderr!r}")

    def test_inflight_document_is_not_validated(self):
        """리뷰가 도는 중인 문서는 검증 후보에서 빠진다 (A12, 양의 짝)."""
        now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        r = self._stop(
            "test-inflight-silent",
            f"inflight_paths:\n  {BROKEN_REL}: {now_iso}\n")
        self.assertEqual(
            r.stdout.strip(), "",
            msg=("리뷰 중인 문서에 구조 block 이 나갔다 — 그 라운드를 절단한다: "
                 f"{r.stdout!r}"))


class TestCandidatePathsSurviveSubdirectoryCwd(unittest.TestCase):
    """발견이 낸 경로는 훅의 **프로세스 cwd** 와 무관하게 열려야 한다 (FIX 1).

    `git status --porcelain -z` 는 리포-루트 상대 경로를 낸다. 그것을 그대로
    흘려보내면 훅의 cwd 가 서브디렉터리일 때 발견은 성공하고 `resolve_mode` 도
    (순수 substring 판정이라) 성공하는데 **파일 읽기만** 실패한다. 그러면
    `validate_document` 이 "문서를 읽지 못했다" 를 구조 실패 사유로 날조해,
    멀쩡한 문서에 상한까지 block 을 내고 그 뒤 영영 침묵한다 — 어느 방향도 사실이
    아니다. `discover()` 가 루트를 조인해 절대경로를 내는 것이 그 계약이다.

    이 케이스는 **사유의 내용**을 잰다. "block 이 났다" 만 재면 날조된 사유로도
    통과한다 — 정확히 그 결함이 통과한다.
    """

    def test_reason_is_the_real_defect_not_a_read_failure(self):
        session_id = "test-subdir-cwd"
        repo = _repo_with_broken_scope_doc(session_id, "")
        self.addCleanup(shutil.rmtree, repo, True)
        deep = repo / "sub" / "deep"
        deep.mkdir(parents=True)

        r = _run_stop(repo, session_id, cwd=deep)
        self.assertEqual(r.returncode, 0, msg=f"훅이 죽었다: {r.stderr}")
        self.assertTrue(
            r.stdout.strip(),
            msg=f"서브디렉터리 cwd 에서 구조 검증이 통째로 사라졌다: {r.stderr!r}")
        reason = json.loads(r.stdout).get("reason", "")
        self.assertIn(
            "placeholder hit", reason,
            msg=f"진짜 구조 실패(TBD)를 사유로 내지 않았다: {reason!r}")
        self.assertNotIn(
            "문서를 읽지 못했다", reason,
            msg=("발견 경로를 프로세스 cwd 에 대고 열었다 — 날조된 구조 실패 사유다: "
                 f"{reason!r}"))


class TestValidationBlockWritesBeforeEmit(unittest.TestCase):
    """구조-실패 block 도 AC7.1/AC7.2 계약을 진다 (FIX 6).

    이 경로는 dispatch 경로와 **별개로** write-before-print 와 "write 실패 →
    무-emit" 을 구현한다. AC7.3.1 정적 락은 `rewrite_state` 만 보므로 여기를 못 본다.
    뒤집으면 `validation_attempts` 를 못 올린 채 매 턴 block 이 나가는 무한 루프가
    되는데, 그것이 바로 AC7.2 가 쓰여진 이유다.
    """

    def test_unwritable_state_suppresses_the_block(self):
        session_id = "test-valblock-rofail"
        repo = _repo_with_broken_scope_doc(session_id, "")
        self.addCleanup(shutil.rmtree, repo, True)
        state = repo / ".claude" / "spec-distill" / session_id / "state.local.md"
        parent = state.parent
        orig_state, orig_parent = state.stat().st_mode, parent.stat().st_mode
        try:
            os.chmod(state, 0o444)
            os.chmod(parent, 0o555)
            r = _run_stop(repo, session_id)
        finally:
            os.chmod(parent, orig_parent)
            os.chmod(state, orig_state)

        self.assertEqual(r.returncode, 0, msg=f"훅이 죽었다: {r.stderr}")
        self.assertEqual(
            r.stdout.strip(), "",
            msg=("카운터를 못 올렸는데 block 을 냈다 — 매 턴 반복되는 무한 루프다: "
                 f"{r.stdout!r}"))
        self.assertIn(
            "구조 검증 기록 실패", r.stderr,
            msg=f"조용히 삼켰다 (loud 하되 루프하지 않아야 한다): {r.stderr!r}")


class TestLedgerBugIsNotSwallowed(unittest.TestCase):
    """원장 **파싱 버그**가 "조회 실패" 로 둔갑해 Layer 1 을 끄면 안 된다 (FIX 3).

    발견 쪽 except 에 대해 이 리포가 이미 확립한 논거와 같다: 넓힌 except 는
    게이트를 조용히 끄고, exit 0 의 stderr 는 사용자에게 전달되지 않는다.
    `arm_ledger` 자체가 없는 경우(import 프로브의 진짜 실패 모드)만 삼킨다.

    짝: 음(파싱 버그는 안 삼킴) + 양(모듈 부재는 삼키고 살아남음).
    """

    def _drive(self, stub):
        return _drive_main(lambda *_a, **_k: [], modules={"arm_ledger": stub})

    def test_negative_parse_bug_surfaces(self):
        stub = types.SimpleNamespace(
            VALIDATION_ATTEMPT_CAP=3,
            validation_attempts=lambda _b: (_ for _ in ()).throw(
                RuntimeError("원장 파서 버그")),
        )
        raised, stdout = self._drive(stub)
        self.assertIsInstance(
            raised, RuntimeError,
            msg=("원장 파싱 버그가 삼켜졌다 — except 절이 ImportError 보다 넓다. "
                 f"stdout={stdout!r}"))

    def test_positive_missing_module_degrades_without_dying(self):
        raised, stdout = self._drive(None)   # sys.modules[x] = None → ImportError
        self.assertIsNone(
            raised, msg=f"arm_ledger 부재가 훅을 죽였다: {raised!r}")
        self.assertEqual(
            stdout.strip(), "",
            msg=f"원장 없이 block 을 냈다 — 상한을 셀 수 없는 상태다: {stdout!r}")


if __name__ == "__main__":
    unittest.main()
