#!/usr/bin/env python3
"""arm_ledger 단위 테스트 (v0.25.0) — §5.1 판정 · §5.2 기록 시점 · G6 상한."""
import contextlib
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
import uuid
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PLUGIN_ROOT / "hooks"))
sys.path.insert(0, str(PLUGIN_ROOT / "scripts"))
import arm_ledger  # noqa: E402
# 착지점은 `state_path` 에서 **직접** 조립한다. arm_ledger 를 통해 부르면(예전 형태)
# 소유하지도 않는 이름의 re-export 에 기대게 되고, 무엇보다 착지점 계산이 피검자의
# 경로 조립 함수(`state_file_for`)와 같아지면 그 함수의 버그가 이 테스트를 눈멀게 한다.
from state_path import state_root  # noqa: E402 # pyright: ignore[reportMissingImports]

SPEC = "docs/superpowers/specs/2026-08-01-x-design.md"
OTHER = "docs/superpowers/specs/2026-08-01-y-design.md"
HEAD = "---\nsession_id: test-sid\n---\n\n"


@contextlib.contextmanager
def _capture_stderr():
    """degrade 경로의 loud logging 을 문자열로 잡는다 (CLAUDE.md graceful+loud)."""
    buf = io.StringIO()
    with contextlib.redirect_stderr(buf):
        yield buf


def _make_repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="armledger-")).resolve()
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    return repo


class TestCanonicalKey(unittest.TestCase):
    def test_absolute_worktree_and_relative_map_to_same_key(self):
        self.assertEqual(arm_ledger.canonical_key(f"/a/b/{SPEC}"), SPEC)
        self.assertEqual(arm_ledger.canonical_key(SPEC), SPEC)
        self.assertEqual(
            arm_ledger.canonical_key(f"/r/.claude/worktrees/wt/{SPEC}"), SPEC)

    def test_out_of_scope_is_none(self):
        self.assertIsNone(arm_ledger.canonical_key("/tmp/x-design.md"))
        self.assertIsNone(arm_ledger.canonical_key(""))


class TestControlCharRejection(unittest.TestCase):
    """제어문자가 섞인 경로는 스코프 밖으로 떨어져야 한다 (위조 차단).

    상태 파일은 0-indent 블록으로 파싱되는 마크다운이라, 개행이 든 경로가 그대로
    보간되면 `armed_paths:` 블록을 위조해 **다른 문서**의 리뷰를 영구 억제할 수 있다.
    """

    def test_newline_bearing_path_is_out_of_scope(self):
        forged = (f"{SPEC[:-3]}a\narmed_paths:\n  - {OTHER}\nx-design.md")
        self.assertIsNone(arm_ledger.canonical_key(forged))

    def test_carriage_return_path_is_out_of_scope(self):
        self.assertIsNone(arm_ledger.canonical_key(f"{SPEC[:-3]}\rx-design.md"))

    def test_ordinary_path_still_accepted(self):
        # 과잉 교정 방지 — 정상 경로는 그대로 통과해야 한다.
        self.assertEqual(arm_ledger.canonical_key(f"/w/{SPEC}"), SPEC)


class TestLedgerBody(unittest.TestCase):
    def test_mark_armed_is_idempotent(self):
        body = arm_ledger.mark_armed(HEAD, f"/w/{SPEC}")
        body2 = arm_ledger.mark_armed(body, SPEC)
        self.assertEqual(arm_ledger.armed_keys(body2), [SPEC])

    def test_mark_armed_out_of_scope_is_noop(self):
        self.assertEqual(arm_ledger.mark_armed(HEAD, "/tmp/z.md"), HEAD)

    def test_attempts_roundtrip(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, 2)
        self.assertEqual(arm_ledger.attempts(body), {SPEC: 2})

    def test_record_attempt_below_cap_does_not_arm(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, 1)
        body = arm_ledger.record_attempt(body, SPEC, 2)
        self.assertEqual(arm_ledger.armed_keys(body), [])
        self.assertEqual(arm_ledger.attempts(body), {SPEC: 2})

    def test_record_attempt_at_cap_arms(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, arm_ledger.DISPATCH_ATTEMPT_CAP)
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertEqual(arm_ledger.attempts(body)[SPEC],
                         arm_ledger.DISPATCH_ATTEMPT_CAP)

    def test_next_attempt_counts_from_zero_and_ignores_out_of_scope(self):
        self.assertEqual(arm_ledger.next_attempt(HEAD, SPEC), 1)
        body = arm_ledger.record_attempt(HEAD, SPEC, 2)
        self.assertEqual(arm_ledger.next_attempt(body, SPEC), 3)
        self.assertEqual(arm_ledger.next_attempt(body, "/tmp/z.md"), 0)

    def test_other_document_entries_survive(self):
        body = arm_ledger.record_attempt(HEAD, OTHER, 1)
        body = arm_ledger.mark_armed(body, SPEC)
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertEqual(arm_ledger.attempts(body), {OTHER: 1})

    def test_strip_pending_preserves_ledger_blocks(self):
        body = arm_ledger.mark_armed(HEAD, SPEC)
        body = body.rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        stripped = arm_ledger.strip_pending(body)
        self.assertNotIn("pending_review:", stripped)
        self.assertEqual(arm_ledger.armed_keys(stripped), [SPEC])


class TestIsBorn(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        (self.repo / "docs/superpowers/specs").mkdir(parents=True)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_tracked_document_is_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))

    def test_staged_only_document_is_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))

    def test_untracked_document_is_not_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        self.assertFalse(arm_ledger.is_born(SPEC))

    def test_dangling_path_is_not_born_and_does_not_raise(self):
        self.assertFalse(arm_ledger.is_born(SPEC))

    def test_committed_doc_is_born_from_subdirectory_cwd(self):
        """커밋된 문서는 하위 디렉토리 cwd 에서도 born 이어야 한다.

        `canonical_key` 는 worktree/절대/상대를 한 키로 정규화하는데 `is_born` 은
        raw_path 를 cwd 상대 git pathspec 으로 그대로 넘긴다 — should_arm 의 두 절반이
        서로 다른 경로 동일성을 쓴다. v0.14.0 에 출하됐던 버그와 같은 모양이며, 그때
        잡던 락(AC1c)은 승계 없이 삭제됐다.
        """
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))          # repo root cwd
        os.chdir(self.repo / "docs" / "superpowers")
        self.assertTrue(arm_ledger.is_born(SPEC))          # 하위 디렉토리 cwd

    def test_outside_repo_falls_open_to_not_born(self):
        outside = Path(tempfile.mkdtemp(prefix="armledger-norepo-")).resolve()
        try:
            os.chdir(outside)
            self.assertFalse(arm_ledger.is_born(str(outside / SPEC)))
        finally:
            os.chdir(self.repo)
            shutil.rmtree(outside, ignore_errors=True)


class TestShouldArmAndSkipReason(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        (self.repo / "docs/superpowers/specs").mkdir(parents=True)
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        self.state = self.repo / "state.local.md"
        self.state.write_text(HEAD, encoding="utf-8")

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def _commit(self):
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)

    def test_fresh_untracked_document_arms(self):
        self.assertTrue(arm_ledger.should_arm(self.state, SPEC))

    def test_ledger_entry_blocks_arm(self):
        self.state.write_text(arm_ledger.mark_armed(HEAD, SPEC), encoding="utf-8")
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "reviewed")

    def test_git_tracked_blocks_arm_even_with_empty_ledger(self):
        self._commit()
        self.assertEqual(arm_ledger.armed_keys(self.state.read_text()), [])
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "born")

    def test_cap_reached_reports_capped_not_reviewed(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, arm_ledger.DISPATCH_ATTEMPT_CAP)
        self.state.write_text(body, encoding="utf-8")
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "capped")

    def test_missing_state_file_falls_open_to_arm(self):
        self.state.unlink()
        self.assertTrue(arm_ledger.should_arm(self.state, SPEC))


class TestFileLevelWrites(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        self.state = self.repo / "state.local.md"

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_mark_reviewed_arms_and_clears_attempts(self):
        self.state.write_text(
            arm_ledger.record_attempt(HEAD, SPEC, 2), encoding="utf-8")
        self.assertTrue(arm_ledger.mark_reviewed(self.state, SPEC))
        body = self.state.read_text(encoding="utf-8")
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertNotIn(SPEC, arm_ledger.attempts(body))

    def test_mark_reviewed_out_of_scope_returns_false(self):
        self.state.write_text(HEAD, encoding="utf-8")
        self.assertFalse(arm_ledger.mark_reviewed(self.state, "/tmp/z.md"))

    def test_strip_pending_file_only_touches_same_key(self):
        body = HEAD + (
            f"pending_review:\n  path: {OTHER}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        self.assertFalse(arm_ledger.strip_pending_file(self.state, SPEC))
        self.assertIn("pending_review:", self.state.read_text(encoding="utf-8"))
        self.assertTrue(arm_ledger.strip_pending_file(self.state, OTHER))
        self.assertNotIn("pending_review:", self.state.read_text(encoding="utf-8"))

    def test_strip_pending_file_does_not_touch_ledger(self):
        body = arm_ledger.mark_armed(HEAD, OTHER).rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        arm_ledger.strip_pending_file(self.state, SPEC)
        self.assertEqual(
            arm_ledger.armed_keys(self.state.read_text(encoding="utf-8")), [OTHER])


class TestMarkReviewedPreservesUnreadableState(unittest.TestCase):
    """판독 실패한 원장은 덮어쓰지 않는다 — 부재(초기화 가능)와 판독불가(보존)를 가른다.

    `_read_body` 의 빈-body degrade 는 *읽기* 술어(`is_armed`)에는 옳다(미기록 → arm,
    안전한 방향). 같은 값을 read-modify-write 인 `mark_reviewed` 가 "새 세션" 으로 읽으면
    파일 전체를 덮어써, 다른 문서의 `armed_paths` 와 살아있는 `pending_review` 가 함께
    사라진다 — 이 릴리스가 제거하려는 재발동 그 자체이며 CLAUDE.md 의 "실패 시 디버깅을
    위해 보존" 위반이다. 같은 상황을 `spec-write-validator.write_state` 는 이미 보존으로
    처리한다.
    """

    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        self.state = self.repo / "state.local.md"

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_unreadable_state_is_preserved_not_overwritten(self):
        # 다른 문서(OTHER)의 원장 + SPEC 의 살아있는 pending 이 담긴 파일이 깨졌다.
        good = arm_ledger.mark_armed(HEAD, OTHER).rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        raw = good.encode("utf-8") + b"\xff"
        self.state.write_bytes(raw)
        self.assertFalse(arm_ledger.mark_reviewed(self.state, SPEC))
        # 바이트 단위 보존 — OTHER 의 원장도 SPEC 의 pending 도 살아있어야 한다.
        self.assertEqual(self.state.read_bytes(), raw)

    def test_unreadable_state_write_failure_is_loud(self):
        self.state.write_bytes(b"---\nsession_id: t\n---\n\n\xff")
        with _capture_stderr() as err:
            self.assertFalse(arm_ledger.mark_reviewed(self.state, SPEC))
        self.assertIn("보존", err.getvalue())

    def test_missing_state_file_is_still_created(self):
        # 과잉 교정 방지: 부재는 여전히 정상 초기화 경로여야 한다.
        self.assertFalse(self.state.exists())
        self.assertTrue(arm_ledger.mark_reviewed(self.state, SPEC))
        self.assertEqual(
            arm_ledger.armed_keys(self.state.read_text(encoding="utf-8")), [SPEC])

    def test_readable_state_still_records(self):
        self.state.write_text(arm_ledger.mark_armed(HEAD, OTHER), encoding="utf-8")
        self.assertTrue(arm_ledger.mark_reviewed(self.state, SPEC))
        self.assertEqual(
            sorted(arm_ledger.armed_keys(self.state.read_text(encoding="utf-8"))),
            sorted([OTHER, SPEC]))


class TestArmLedgerCLIRejects(unittest.TestCase):
    """CLI 거부 분기 — 삭제된 두 락(test_review_lock.py bad-sid, test_approve_handoff.sh
    charset/empty-arg)의 후속. sid 는 `state_file_for()` 에서 경로 세그먼트가 되고
    `mark_reviewed` 가 `mkdir(parents=True)` + write 를 하므로, 이 guard 가 caller 가 준
    sid 와 임의 파일시스템 쓰기 사이의 유일한 방벽이다 (CLAUDE.md: 보안 컨트롤).
    """

    def setUp(self):
        # 리포를 sandbox 한 겹 안에 둔다 — traversal 의 착지점을 관측 가능하게 만들기
        # 위해서다. `<repo>/.claude/spec-distill/../../../etc` 는 <sandbox>/etc 로
        # 정규화되므로 repo 만 훑으면 그 파일을 **영영 못 본다**(부모 디렉토리라
        # rglob 이 방문하지 않는다). 그 상태의 "쓰기 없음" assert 는 위반이 실제로
        # 일어나는 곳이 아니라 일어나지 않는 곳을 재는, 안심용 assert 다.
        self.sandbox = Path(tempfile.mkdtemp(prefix="armledger-cli-")).resolve()
        self.repo = self.sandbox / "repo"
        self.repo.mkdir()
        subprocess.run(["git", "init", "-q"], cwd=self.repo, check=True)
        subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=self.repo, check=True)
        subprocess.run(["git", "config", "user.name", "t"], cwd=self.repo, check=True)
        self.cwd = os.getcwd()
        os.chdir(self.repo)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.sandbox, ignore_errors=True)

    def _run(self, *args, **extra_env):
        env = dict(os.environ)
        env.pop("DEVBREW_DISABLE_SPEC_DISTILL", None)
        env.update(extra_env)
        return subprocess.run(
            [sys.executable, str(PLUGIN_ROOT / "scripts" / "arm_ledger.py"), *args],
            cwd=self.repo, capture_output=True, text=True, env=env)

    def _no_state_written(self):
        # sandbox 전체를 훑는다 — repo 밖 상위로 탈출한 착지점까지 본다.
        # 단, 트리 스캔은 **경계 안**만 볼 수 있다(아래 _landing 주석 참조).
        return list(self.sandbox.rglob("state.local.md")) == []

    def _landing(self, sid):
        """이 sid 가 guard 없이 통과했을 때 파일이 실제로 떨어질 경로.

        `_no_state_written()` 은 "아무 데도 안 썼다"는 **전칭 명제**를 유한한 트리
        스캔으로 재려 한다 — 경계를 넘어간 착지점은 구조적으로 못 본다. sandbox 를
        한 겹 둔 덕에 `../../../etc`(= <sandbox>/etc) 는 보이지만
        `../../../../../tmp/x` 는 다시 안 보인다. 즉 커버리지가 guard 가 아니라
        **입력 문자열의 깊이**에 묶여 있다. 입력에서 착지점을 직접 계산하면 깊이와
        무관하게 잴 수 있다.

        **결정 가능한 방향은 하나뿐이다.** "가드가 깨지면 파일이 생긴다 → RED" 는
        성립한다. 역방향("GREEN 이면 가드가 온전하다")은 착지점이 실행 **전에**
        비어 있었을 때만 성립하는데, sandbox 밖 착지점은 이 테스트가 만들지도
        지우지도 않는 영역이다. 그래서 호출부가 (1) 실행 전 부재를 assert 하고
        (2) run-unique 이름을 써 다른 실행과 충돌하지 않게 하고 (3) addCleanup 으로
        치운다. 셋 중 하나라도 빠지면 한 번의 유출이 그 머신에서 **무관한 변경까지
        영구 RED** 로 만든다 (리뷰에서 실제 관측: 연속 5 RED → 파일 삭제 후 복구).
        """
        return (state_root() / sid / "state.local.md").resolve()

    def test_traversal_sid_rejected_and_writes_nothing(self):
        cp = self._run("mark-reviewed", "../../../etc", SPEC)
        self.assertEqual(cp.returncode, 2)
        self.assertIn("session_id rejected", cp.stderr)
        # 깊이-독립: 이 입력의 착지점을 직접 계산해 부재를 잰다.
        self.assertFalse(self._landing("../../../etc").exists())
        self.assertTrue(self._no_state_written())

    def test_deep_traversal_sid_rejected(self):
        # sandbox 를 넘어가는 깊이 — 트리 스캔으로는 영영 못 보는 착지점.
        # 이름에 run-unique 접미사를 붙이는 이유는 _landing docstring 참조:
        # 고정 이름이면 sandbox 밖 **안정 경로**라 한 번의 유출이 영구 RED 를 만든다.
        deep = ("../../../../../tmp/qg-armledger-should-not-exist-"
                + uuid.uuid4().hex[:8])
        landing = self._landing(deep)
        # 픽스처 위생 — 실행 **전** 부재를 확인한다. 이게 없으면 이미 존재하는 파일이
        # "가드 회귀" 로 오독된다(위양성). 이 assert 가 실패하면 그건 제품 결함이
        # 아니라 픽스처 오염이라는 뜻이고, 메시지가 그렇게 말한다.
        self.assertFalse(landing.exists(), msg=f"픽스처 오염 — 사전 존재: {landing}")
        self.addCleanup(shutil.rmtree, landing.parent, True)
        cp = self._run("mark-reviewed", deep, SPEC)
        self.assertEqual(cp.returncode, 2)
        self.assertIn("session_id rejected", cp.stderr)
        self.assertFalse(landing.exists())

    def test_short_sid_rejected(self):
        cp = self._run("mark-reviewed", "abc", SPEC)
        self.assertEqual(cp.returncode, 2)
        self.assertIn("session_id rejected", cp.stderr)
        self.assertTrue(self._no_state_written())

    def test_strip_pending_rejects_bad_sid_too(self):
        # 두 subcommand 가 같은 guard 를 공유한다 — 한쪽만 검증하면 비대칭이 새로 생긴다.
        cp = self._run("strip-pending", "../../../etc", SPEC)
        self.assertEqual(cp.returncode, 2)
        self.assertIn("session_id rejected", cp.stderr)
        self.assertTrue(self._no_state_written())

    def test_unknown_subcommand_rejected(self):
        cp = self._run("frobnicate", "valid-sid-0001", SPEC)
        self.assertEqual(cp.returncode, 2)
        self.assertIn("unknown subcommand", cp.stderr)

    def test_missing_args_prints_usage(self):
        cp = self._run("mark-reviewed", "valid-sid-0001")
        self.assertEqual(cp.returncode, 2)
        self.assertIn("usage:", cp.stderr)

    def test_kill_switch_is_a_noop_that_writes_nothing(self):
        cp = self._run("mark-reviewed", "valid-sid-0001", SPEC,
                       DEVBREW_DISABLE_SPEC_DISTILL="1")
        self.assertEqual(cp.returncode, 0)
        self.assertIn("no-op", cp.stderr)
        # rc-only assert 는 "돌고 나서 0 을 냈다" 와 구분하지 못한다 — 부작용까지 본다.
        self.assertTrue(self._no_state_written())


# LINE SEPARATOR. `str.splitlines()` 는 여기서 쪼개지만 `ARMED_RE` 의 `[^\n]+` 는
# 통과시킨다. 소스에 리터럴로 넣지 않고 escape 로 쓴다 — 리터럴은 이 파일을 읽는
# 도구(YAML·에디터)에서 같은 방식으로 줄을 갈라 버린다(실제로 겪었다).
LS = "\u2028"


class TestArmedPathsForgeryViaSplitlines(unittest.TestCase):
    """`armed_paths` 위조는 개행 없이도 성립한다 — reader 가 `splitlines()` 를 쓰기 때문.

    writer 쪽 포맷만 보면 "위조하려면 `\\n` 이 필요하다"고 결론내기 쉽다. 틀렸다.
    줄 경계를 정하는 것은 writer 가 아니라 **reader** 이고, 이 모듈의 reader
    (`armed_keys`·`attempts`)는 `splitlines()` 를 쓴다 — 그건 universal-newline
    전체(VT·FF·FS·GS·RS·NEL·LS·PS)에서 쪼갠다.

    이 클래스는 리뷰에서 실제로 제안됐던 "`canonical_key` 를 `\\n\\r\\x00` 로 좁히자"는
    단순화를 RED 로 만든다. 좁히면 T16 이 막는 위조가 그대로 되열린다.
    """

    def test_splitlines_boundary_cannot_become_a_key(self):
        forged = f"{SPEC}{LS}  - {OTHER}"
        self.assertIsNone(arm_ledger.canonical_key(forged))

    def test_parser_really_would_split_it(self):
        """양의 짝 — 왜 거부해야 하는지를 잰다.

        위 assert 만 있으면 "거부한다"는 사실만 남고 그 거부가 무엇을 막는지는
        재지 못한다. 가드를 우회해 body 를 직접 만들면 victim 문서가 실제로
        armed 로 읽히는지 확인한다.
        """
        body = HEAD + "armed_paths:\n" + f"  - {SPEC}{LS}  - {OTHER}\n"
        keys = arm_ledger.armed_keys(body)
        self.assertEqual(len(keys), 2, msg=f"reader 가 쪼개지 않았다: {keys!r}")
        self.assertIn(OTHER, keys)

    def test_clean_key_still_round_trips(self):
        # 과잉 교정 방지 — 정상 키는 정확히 하나로 남아야 한다.
        self.assertEqual(arm_ledger.armed_keys(arm_ledger.mark_armed(HEAD, SPEC)),
                         [SPEC])


class TestIsBornCrossCheckout(unittest.TestCase):
    """다른 체크아웃의 문서를 이 리포의 동명 파일로 판정하면 안 된다.

    `canonical_key` 는 PREFIX 이후만 남기므로, 그 키를 repo-root pathspec 으로 접으면
    **어느 체크아웃의 문서였는지가 사라진다**. 접힌 키가 이 리포의 index 에 있으면
    born=True → `should_arm` False → 그 문서의 Law 1 게이트가 조용히 꺼진다.

    현실적 트리거는 이 프로젝트 자신의 레이아웃이다 — cwd 는 main repo, 편집 대상은
    `<main_repo>/.claude/worktrees/<name>/docs/superpowers/specs/…`.
    """

    def setUp(self):
        self.cwd = os.getcwd()
        self.a = _make_repo()   # 문서가 커밋된 리포
        self.b = _make_repo()   # 같은 상대경로에 untracked 사본이 있는 리포
        for repo in (self.a, self.b):
            (repo / "docs/superpowers/specs").mkdir(parents=True)
            (repo / SPEC).write_text("# x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.a, check=True)
        subprocess.run(["git", "commit", "-qm", "x"], cwd=self.a, check=True)
        os.chdir(self.a)

    def tearDown(self):
        os.chdir(self.cwd)
        for repo in (self.a, self.b):
            shutil.rmtree(repo, ignore_errors=True)

    def test_other_checkouts_untracked_doc_is_not_born(self):
        # 진실: B 의 사본은 B 에서 untracked 다. A 의 index 를 근거로 born 이라 하면 안 된다.
        with _capture_stderr():
            self.assertFalse(arm_ledger.is_born(str(self.b / SPEC)))

    def test_this_repos_own_absolute_path_is_still_born(self):
        # 과잉 교정 방지 — 같은 리포의 절대경로는 여전히 born 이어야 한다.
        self.assertTrue(arm_ledger.is_born(str(self.a / SPEC)))

    def test_glob_metacharacter_does_not_match_unrelated_files(self):
        """`--` 는 옵션 파싱만 멈춘다 — wildmatch 는 `literal` 매직으로만 꺼진다."""
        glob = "docs/superpowers/specs/*-design.md"
        self.assertFalse(arm_ledger.is_born(glob))

    def test_glob_in_absolute_path_does_not_match_either(self):
        """절대경로 분기의 `:(literal)` 도 함께 잠근다.

        위 테스트는 **상대경로**를 넘기므로 `:(top,literal)` 분기만 탄다. 그런데 훅
        payload 의 `tool_input.file_path` 는 항상 절대경로다 — 즉 production 에서
        지배적인 분기가 잠기지 않은 채였고, `:(literal)` 을 지워도 스위트가 GREEN 이었다.
        """
        glob_abs = str(self.a / "docs/superpowers/specs/*-design.md")
        self.assertFalse(arm_ledger.is_born(glob_abs))

    def test_relative_path_from_subdirectory_is_still_born(self):
        # 애초에 고치려던 버그 — 하위 디렉토리 cwd 에서도 커밋 문서는 born.
        os.chdir(self.a / "docs")
        self.assertTrue(arm_ledger.is_born(SPEC))


class TestPrefixContract(unittest.TestCase):
    """validator 의 `PATH_PREFIX` 와 원장의 `PREFIX` 는 같아야 한다.

    `spec-write-validator.unkeyable()` 는 이 등식에 기대어 `canonical_key` 의 `None` 을
    "제어문자" 로만 해석한다. 등식이 깨지면 그 `None` 에 "스코프 밖" 이 섞여 들어가,
    스코프 밖 문서의 pending 기록이 조용히 죽는다(= 리뷰 미발동, Law 1 위반 방향).
    두 파일에 리터럴이 따로 있으므로 락이 없으면 한쪽만 바뀌어도 아무도 모른다.
    """

    def test_validator_and_ledger_prefixes_match(self):
        import re as _re
        src = (PLUGIN_ROOT / "hooks" / "spec-write-validator.py").read_text(
            encoding="utf-8")
        m = _re.search(r'^PATH_PREFIX\s*=\s*"([^"]+)"', src, _re.MULTILINE)
        self.assertIsNotNone(m, msg="validator 의 PATH_PREFIX 리터럴을 못 찾았다")
        assert m is not None
        self.assertEqual(m.group(1), arm_ledger.PREFIX)


class TestStripPendingPreservesUnreadableState(unittest.TestCase):
    """`mark_reviewed` 와 대칭 — 판독 실패한 원장은 `strip_pending_file` 도 덮지 않는다.

    이 분기는 훅 경로에서 도달 불가능하다(두 훅이 자기 `read_text` 실패에서 먼저
    return 한다). 모듈 docstring 이 이 쌍을 "유일한 비대칭 방어" 라 부르는데, 락은
    `mark_reviewed` 쪽에만 있었다 — 삭제해도 전 스위트가 GREEN 이었다.
    """

    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        self.state = self.repo / "state.local.md"

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_unreadable_state_is_preserved(self):
        good = arm_ledger.mark_armed(HEAD, OTHER).rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        raw = good.encode("utf-8") + b"\xff"
        self.state.write_bytes(raw)
        with _capture_stderr() as err:
            self.assertFalse(arm_ledger.strip_pending_file(self.state, SPEC))
        self.assertEqual(self.state.read_bytes(), raw)
        self.assertIn("보존", err.getvalue())

    def test_readable_state_still_strips(self):
        # 과잉 교정 방지 — 정상 파일에서는 여전히 pending 을 지운다.
        body = HEAD + (f"pending_review:\n  path: {SPEC}\n  mode: design\n"
                       "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        self.assertTrue(arm_ledger.strip_pending_file(self.state, SPEC))
        self.assertNotIn("pending_review:",
                         self.state.read_text(encoding="utf-8"))


def _load_validator():
    """하이픈이 든 파일명이라 일반 import 가 안 된다 — 경로로 로드한다."""
    import importlib.util
    path = PLUGIN_ROOT / "hooks" / "spec-write-validator.py"
    spec = importlib.util.spec_from_file_location("spec_write_validator", path)
    assert spec is not None and spec.loader is not None
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


class TestWriteStateRejectsUnencodableValues(unittest.TestCase):
    """인코딩 불가 상태 값은 **쓰기 전에** 거부한다.

    `os.getcwd()` 는 디코딩 불가 바이트를 surrogateescape(U+DC80–U+DCFF 대역)로 담아
    돌려줄 수 있다. 그런 문자열은 줄 경계가 정상이라 `splitlines()` 검사를 통과하지만
    `write_text(encoding="utf-8")` 에서 `UnicodeEncodeError` 를 던진다 — 그건
    `ValueError` 하위이지 **`OSError` 가 아니므로** 호출부의
    `except (PermissionError, OSError)` 를 그대로 통과해 훅을 죽인다. 이 플러그인이
    읽기 쪽에서 이미 겪은 `UnicodeDecodeError` ⊄ `OSError` 의 쓰기 쪽 쌍이다.

    **왜 e2e 가 아니라 유닛인가:** 실제 트리거(비-UTF8 이름의 cwd)는 macOS APFS 가
    그런 이름 자체를 거부해 만들 수 없다(측정 확인). Linux ext4 에서는 만들어진다.
    못 만드는 픽스처를 흉내내 초록을 내는 대신 계약을 함수 인자 층에서 직접 잰다.
    """

    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        os.environ["CLAUDE_PROJECT_DIR"] = str(self.repo)
        self.v = _load_validator()

    def tearDown(self):
        os.chdir(self.cwd)
        os.environ.pop("CLAUDE_PROJECT_DIR", None)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_surrogate_worktree_path_is_refused_not_raised(self):
        bad = "/tmp/wt/" + chr(0xDCFF)   # surrogateescape 로 담긴 비-UTF8 바이트
        with _capture_stderr() as err:
            reason = self.v.write_state("enc-sid-0001", SPEC, "design", bad)
        self.assertEqual(reason, "unsafe-state-value")
        self.assertIn("UTF-8", err.getvalue())
        # 거부는 조용해선 안 되고, 상태 파일도 만들어지면 안 된다.
        self.assertEqual(list(self.repo.rglob("state.local.md")), [])

    def test_clean_values_still_record(self):
        # 과잉 교정 방지 — 정상 값은 여전히 기록된다(None = 성공).
        self.assertIsNone(
            self.v.write_state("enc-sid-0002", SPEC, "design", "/tmp/wt"))
        written = list(self.repo.rglob("state.local.md"))
        self.assertEqual(len(written), 1)
        self.assertIn("pending_review:", written[0].read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
