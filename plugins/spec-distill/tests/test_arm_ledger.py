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


class TestMarkReviewedPreservesUnreadableState(unittest.TestCase):
    """판독 실패한 원장은 덮어쓰지 않는다 — 부재(초기화 가능)와 판독불가(보존)를 가른다.

    `_read_body` 의 빈-body degrade 는 *읽기* 술어(`is_armed`)에는 옳다(미기록 → arm,
    안전한 방향). 같은 값을 read-modify-write 인 `mark_reviewed` 가 "새 세션" 으로 읽으면
    파일 전체를 덮어써, **다른 문서**의 `armed_paths` 와 `dispatch_attempts` 가 함께
    사라진다 — 이 릴리스가 제거하려는 재발동 그 자체이며 CLAUDE.md 의 "실패 시 디버깅을
    위해 보존" 위반이다.
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
        # 다른 문서(OTHER)의 armed 기록 + SPEC 의 진행 중인 시도 횟수가 담긴 파일이 깨졌다.
        good = arm_ledger.record_attempt(
            arm_ledger.mark_armed(HEAD, OTHER), SPEC, 2)
        raw = good.encode("utf-8") + b"\xff"
        self.state.write_bytes(raw)
        self.assertFalse(arm_ledger.mark_reviewed(self.state, SPEC))
        # 바이트 단위 보존 — OTHER 의 armed 도 SPEC 의 attempts 도 살아있어야 한다.
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
        env.pop("DEVBREW_SPEC_DISTILL_DISABLE", None)
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

    def test_clear_inflight_rejects_bad_sid_too(self):
        # sid 를 받는 두 subcommand 가 같은 guard 를 공유한다 — 한쪽만 검증하면
        # 비대칭이 새로 생긴다.
        cp = self._run("clear-inflight", "../../../etc", SPEC)
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
                       DEVBREW_SPEC_DISTILL_DISABLE="1")
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
    """`resolve_mode` 의 `PATH_PREFIX` 와 원장의 `PREFIX` 는 같아야 한다.

    Stop 훅은 두 리터럴을 **함께** 쓴다: 발견은 `canonical_key`(→ `PREFIX`)로 후보
    키를 만들고, dispatch 는 `resolve_mode`(→ `PATH_PREFIX`)로 리뷰어 라우팅 모드를
    정한다. 등식이 깨지면 한쪽이 스코프 안이라 부르는 문서를 다른 쪽이 스코프 밖으로
    떨어뜨려, 발견은 됐는데 `mode is None` 이라 영원히 dispatch 되지 않는 문서가
    생긴다(= 리뷰 미발동, Law 1 위반 방향). 두 파일에 리터럴이 따로 있으므로 락이
    없으면 한쪽만 바뀌어도 아무도 모른다.
    """

    def test_resolve_mode_and_ledger_prefixes_match(self):
        import re as _re
        src = (PLUGIN_ROOT / "scripts" / "resolve_mode.py").read_text(
            encoding="utf-8")
        m = _re.search(r'^PATH_PREFIX\s*=\s*"([^"]+)"', src, _re.MULTILINE)
        self.assertIsNotNone(m, msg="resolve_mode 의 PATH_PREFIX 리터럴을 못 찾았다")
        assert m is not None
        self.assertEqual(m.group(1), arm_ledger.PREFIX)


class TestInflightLedger(unittest.TestCase):
    """A12 — 리뷰 진행 중인 문서는 발견 결과에서 제외된다."""

    K = "docs/superpowers/specs/x-design.md"
    BODY = "---\nsession_id: s\n---\n\n"

    def test_mark_then_read(self):
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        self.assertEqual(arm_ledger.inflight(b), {self.K: "2026-08-23T00:00:00Z"})

    def test_clear_removes_only_that_key(self):
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        b = arm_ledger.mark_inflight(b, self.K.replace("x-", "y-"), "2026-08-23T00:00:00Z")
        b = arm_ledger.clear_inflight(b, self.K)
        self.assertEqual(list(arm_ledger.inflight(b)), [self.K.replace("x-", "y-")])

    def test_armed_and_attempts_blocks_survive(self):
        b = arm_ledger.mark_armed(self.BODY, self.K)
        b = arm_ledger.record_attempt(b, self.K, 2)
        b = arm_ledger.mark_inflight(b, self.K, "2026-08-23T00:00:00Z")
        self.assertIn(self.K, arm_ledger.armed_keys(b))
        self.assertEqual(arm_ledger.attempts(b)[self.K], 2)
        self.assertIn(self.K, arm_ledger.inflight(b))

    def test_expired_inflight_is_not_inflight(self):
        from datetime import datetime, timezone, timedelta
        t0 = datetime(2026, 8, 23, 0, 0, 0, tzinfo=timezone.utc)
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        self.assertTrue(arm_ledger.is_inflight(b, self.K, t0, 900))
        self.assertFalse(
            arm_ledger.is_inflight(b, self.K, t0 + timedelta(seconds=901), 900))

    def test_unparseable_timestamp_is_not_inflight(self):
        # 판독 불가 타임스탬프로 게이트가 영구히 닫히면 Law 1 이 금지하는 방향
        # (under-review) 으로 fail 한다. 만료로 읽어 dispatch 쪽으로 연다.
        from datetime import datetime, timezone
        b = arm_ledger.mark_inflight(self.BODY, self.K, "not-a-time")
        self.assertFalse(arm_ledger.is_inflight(
            b, self.K, datetime(2026, 8, 23, tzinfo=timezone.utc), 900))

    def test_mark_reviewed_clears_inflight(self):
        d = Path(tempfile.mkdtemp()) / "state.local.md"
        d.parent.mkdir(parents=True, exist_ok=True)
        d.write_text(arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z"),
                     encoding="utf-8")
        self.assertTrue(arm_ledger.mark_reviewed(d, self.K))
        b = d.read_text(encoding="utf-8")
        self.assertIn(self.K, arm_ledger.armed_keys(b))
        self.assertNotIn(self.K, arm_ledger.inflight(b))

    def test_default_ttl_sec_reaches_the_module_constant(self):
        # R42 — 리터럴 900을 박지 않는다. `ttl_sec`를 안 넘기고도(기본값 경유)
        # 실제로 쓰이는 값이 `INFLIGHT_TTL_SEC` 자신인지를 잰다 — reachability, 숫자가
        # 아니라. 상수를 바꾸면 이 경계도 같이 움직여야 한다.
        from datetime import datetime, timezone, timedelta
        t0 = datetime(2026, 8, 23, 0, 0, 0, tzinfo=timezone.utc)
        b = arm_ledger.mark_inflight(self.BODY, self.K, "2026-08-23T00:00:00Z")
        ttl = arm_ledger.INFLIGHT_TTL_SEC
        self.assertTrue(
            arm_ledger.is_inflight(b, self.K, t0 + timedelta(seconds=ttl - 1)))
        self.assertFalse(
            arm_ledger.is_inflight(b, self.K, t0 + timedelta(seconds=ttl + 1)))


class TestValidationAttempts(unittest.TestCase):
    """A14 — 검증 실패 상한. dispatch_attempts 와 **별도** 카운터다."""

    K = "docs/superpowers/specs/x-design.md"
    BODY = "---\nsession_id: s\n---\n\n"

    def test_separate_from_dispatch_attempts(self):
        b = arm_ledger.record_validation(self.BODY, self.K, 2)
        self.assertEqual(arm_ledger.validation_attempts(b)[self.K], 2)
        self.assertEqual(arm_ledger.attempts(b), {})

    def test_cap_is_three_and_independent(self):
        self.assertEqual(arm_ledger.VALIDATION_ATTEMPT_CAP, 3)
        self.assertEqual(arm_ledger.DISPATCH_ATTEMPT_CAP, 3)
        # 합치면 구조 실패 2회 뒤에 리뷰 dispatch 가 1회밖에 남지 않는다.
        b = arm_ledger.record_validation(self.BODY, self.K, 3)
        self.assertEqual(arm_ledger.next_attempt(b, self.K), 1)


if __name__ == "__main__":
    unittest.main()
