#!/usr/bin/env python3
"""AC12 — Hook output schema 통합 회귀 방지 test (v0.5.0).

Covers AC1–AC3 + AC5 (4 hook output schemas; AC4 removed in v0.7.0), AC1a (encoding round-trip),
AC7.1/7.2/7.3 (Stop hook ordering + rewrite-fail behavior + ordering
verification 3-prong), AC10/AC11 (kill switches), NG9 (cross-resolver
advisory).

Run:
    python3 -m unittest plugins/spec-distill/tests/test_hook_output_schema.py
"""
from __future__ import annotations

import ast
import contextlib
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
HOOKS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "hooks"
SCRIPTS_DIR = REPO_ROOT / "plugins" / "spec-distill" / "scripts"

# 상한 값은 리터럴로 핀하지 않는다 — DISPATCH_ATTEMPT_CAP 이 바뀌면 테스트가
# 제품과 함께 움직여야지, stale red 로 남아 bump 규칙과 싸우면 안 된다.
sys.path.insert(0, str(SCRIPTS_DIR))
import arm_ledger  # noqa: E402  # pyright: ignore[reportMissingImports]


def _make_temp_repo() -> Path:
    """Create a temp dir initialised as a git repo (state_path needs git).

    `resolve()` 로 symlink 를 푼다(macOS `/var` → `/private/var`). 발견은
    `git rev-parse --show-toplevel` 이 주는 **물리 경로**에 조인해 절대경로를 내므로,
    풀지 않으면 기대 경로와 emit 된 경로가 문자열로 어긋난다.
    """
    tmp = Path(tempfile.mkdtemp(prefix="specdistill-schema-")).resolve()
    subprocess.run(["git", "init", "-q"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=tmp, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=tmp, check=True)
    subprocess.run(
        ["git", "commit", "-q", "--allow-empty", "-m", "seed"],
        cwd=tmp, check=True,
    )
    return tmp


def _write_pending_review_state(
    repo: Path, session_id: str, *, spec_path: str = "/tmp/x-spec.md",
    mode: str = "spec", worktree_path: str | None = None,
    triggered_at: str = "2026-05-17T00:00:00Z",
    last_dispatched_at: str | None = None,
) -> Path:
    """Write a state.local.md with a pending_review block."""
    state_dir = repo / ".claude" / "spec-distill" / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    block = (
        f"pending_review:\n"
        f"  path: {spec_path}\n"
        f"  mode: {mode}\n"
    )
    if worktree_path:
        block += f"  worktree_path: {worktree_path}\n"
    block += f"  triggered_at: {triggered_at}\n"
    tail = ""
    if last_dispatched_at:
        tail = f"\nlast_dispatched_at: {last_dispatched_at}\n"
    state_file.write_text(
        f"---\nsession_id: {session_id}\n---\n\n{block}{tail}",
        encoding="utf-8",
    )
    return state_file


#: 구조적으로 통과하는 design 문서 본문 (placeholder·ambiguity 없음).
DESIGN_DOC_BODY = (
    "# Test Design\n\nContext / Why\n\nGoals\n\nNon-goals\n\n"
    "Constraints\n\nAcceptance Criteria\n\nFiles\n\nVerification Plan\n\n"
    "Rejected Alternatives\n\nMetadata\n"
)


def _write_scope_doc(repo: Path, rel: str, *, body: str = DESIGN_DOC_BODY) -> Path:
    """dirty·untracked 스코프 문서를 만든다 — **dispatch 의 연료**.

    Stop 훅은 상태 파일의 블록이 아니라 `git status` 가 내는 dirty 집합에서 대상을
    고른다. 그래서 dispatch 경로를 태우려면 리포에 진짜 문서가 있어야 한다.
    """
    p = repo / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text(body, encoding="utf-8")
    return p


def _write_state(repo: Path, session_id: str, extra: str = "") -> Path:
    """frontmatter 만 있는 상태 파일(+ 원장 블록). pending 은 싣지 않는다."""
    state_dir = repo / ".claude" / "spec-distill" / session_id
    state_dir.mkdir(parents=True, exist_ok=True)
    state_file = state_dir / "state.local.md"
    state_file.write_text(
        f"---\nsession_id: {session_id}\n---\n\n{extra}", encoding="utf-8")
    return state_file


def _expire_inflight(repo: Path, session_id: str) -> None:
    """in-flight 표시의 타임스탬프를 과거로 밀어 TTL 만료를 시뮬레이션한다.

    `INFLIGHT_TTL_SEC` 은 환경변수로 못 낮추므로 시간을 기다리는 대신 원장을 늙힌다.
    쓰기는 원장 자신의 composer(`mark_inflight`)로 한다 — 블록 모양을 테스트가
    따로 흉내내면 그 흉내가 진짜 모양과 갈리는 날 조용히 무의미해진다.
    """
    f = repo / ".claude" / "spec-distill" / session_id / "state.local.md"
    body = f.read_text(encoding="utf-8")
    for key in list(arm_ledger.inflight(body)):
        body = arm_ledger.mark_inflight(body, key, "2020-01-01T00:00:00Z")
    f.write_text(body, encoding="utf-8")


def _run_hook(
    hook_relpath: str, *,
    cwd: Path, env_extra: dict[str, str] | None = None,
    stdin_payload: dict | None = None,
    binary: str = "python3",
) -> subprocess.CompletedProcess:
    """Run a hook with isolated env. cwd=temp repo redirects state_root()."""
    env = {"HOME": os.environ.get("HOME", "/tmp"), "PATH": os.environ["PATH"]}
    if env_extra:
        env.update(env_extra)
    hook_path = HOOKS_DIR / hook_relpath
    stdin_str = json.dumps(stdin_payload or {})
    return subprocess.run(
        [binary, str(hook_path)],
        cwd=cwd, env=env, input=stdin_str, text=True,
        capture_output=True, timeout=15,
    )


class HookOutputSchemaTestBase(unittest.TestCase):
    """Base class with shared fixture lifecycle."""

    def setUp(self):
        self.repo = _make_temp_repo()

    def tearDown(self):
        shutil.rmtree(self.repo, ignore_errors=True)


class TestReviewDispatchSchema(HookOutputSchemaTestBase):
    """AC1 — review-dispatch.py (Stop hook) output schema."""

    def test_discovered_doc_emits_decision_block_with_reason(self):
        session_id = "test-stop-happy"
        doc = _write_scope_doc(
            self.repo, "docs/superpowers/specs/2026-05-16-happy-design.md")
        result = _run_hook(
            "review-dispatch.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg="stdout empty")
        payload = json.loads(result.stdout)
        self.assertEqual(payload.get("decision"), "block")
        reason = payload.get("reason", "")
        self.assertIn("MANDATORY", reason)
        self.assertIn("mode:", reason)
        # `worktree_path:` 줄은 은퇴했다 — 그 값의 출처는 pending 을 쓰던 훅의 cwd
        # 였고, 발견이 내는 spec path 가 절대경로라 같은 사실(어느 체크아웃인가)을
        # 스스로 말한다. 그래서 재는 것은 줄의 존재가 아니라 경로 자체다.
        self.assertIn(f"spec path: {doc}", reason)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg, msg="systemMessage missing")
        self.assertLessEqual(len(sysmsg), 120, msg=f"systemMessage too long: {len(sysmsg)}")
        self.assertTrue(sysmsg.startswith("[spec-distill]"))

    def test_reason_encoding_safe_with_special_chars(self):
        """AC1a — special chars in spec path must round-trip via json.loads.

        경로가 발견에서 오므로 특수문자도 **실재하는 파일명**으로 재야 한다.
        `git status --porcelain -z` 는 NUL 구분이라 경로를 인용하지 않는다(따옴표
        인용은 `-z` 없을 때만) — 그래서 이 이름이 파서를 그대로 통과한다.
        """
        session_id = "test-stop-encoding"
        doc = _write_scope_doc(
            self.repo,
            "docs/superpowers/specs/2026-05-16 with $special `chars`-design.md")
        result = _run_hook(
            "review-dispatch.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0)
        payload = json.loads(result.stdout)  # ← round-trip via stdlib json
        self.assertIn(str(doc), payload["reason"])

    def test_rewrite_failure_suppresses_emit(self):
        """AC7.2 — if rewrite_state raises OSError, hook must NOT emit decision:block."""
        session_id = "test-stop-rewrite-fail"
        _write_scope_doc(
            self.repo, "docs/superpowers/specs/2026-05-16-rofail-design.md")
        state_file = _write_state(self.repo, session_id)
        # Make state file read-only to force rewrite_state OSError on open(w).
        # File-level chmod is required: parent-dir chmod doesn't block writes
        # to existing owned files. Also chmod the parent so any fallback
        # create/rename also fails.
        parent = state_file.parent
        original_file_mode = state_file.stat().st_mode
        original_parent_mode = parent.stat().st_mode
        try:
            os.chmod(state_file, 0o444)  # r--r--r--
            os.chmod(parent, 0o555)  # r-xr-xr-x
            result = _run_hook(
                "review-dispatch.py",
                cwd=self.repo,
                env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
            )
        finally:
            os.chmod(parent, original_parent_mode)
            os.chmod(state_file, original_file_mode)
        self.assertEqual(result.returncode, 0)
        # stdout must be empty or {} — NOT decision:block
        stripped = result.stdout.strip()
        if stripped:
            payload = json.loads(stripped)
            self.assertNotEqual(
                payload.get("decision"), "block",
                msg=f"AC7.2 violated: emitted decision:block despite rewrite failure: {stripped}",
            )
        # stderr should contain the loud log
        self.assertIn("state rewrite failed", result.stderr)
        self.assertIn("dispatch suppressed", result.stderr)

    def test_arm_gate_import_failure_falls_open_to_arm(self):
        """`import arm_ledger`가 실패하면(예: 모킹) validator는 게이트를 건너뛰고
        정상 arm한다 (fail-safe = 리뷰가 일어나는 쪽, Law 1)."""
        import importlib.util
        import io
        spec_module = importlib.util.spec_from_file_location(
            "spec_write_validator_failopen", HOOKS_DIR / "spec-write-validator.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        repo = _make_temp_repo()
        try:
            session_id = "test-armgate-failopen"
            rel = "docs/superpowers/specs/2026-01-01-x-design.md"
            doc = repo / rel
            doc.parent.mkdir(parents=True, exist_ok=True)
            doc.write_text(
                "# Doc\n\n## Goal\n\n한 줄.\n", encoding="utf-8")
            # 게이트가 살아 있었다면 arm을 막았을 진짜 원장 상태.
            state_dir = repo / ".claude" / "spec-distill" / session_id
            state_dir.mkdir(parents=True, exist_ok=True)
            (state_dir / "state.local.md").write_text(
                f"---\nsession_id: {session_id}\n---\n\narmed_paths:\n  - {rel}\n",
                encoding="utf-8",
            )
            payload = json.dumps({
                "tool_name": "Write",
                "tool_input": {"file_path": str(doc)},
            })
            out, err = io.StringIO(), io.StringIO()
            # sys.modules['arm_ledger'] = None → `import arm_ledger` ImportError.
            with mock.patch.dict(sys.modules, {"arm_ledger": None}), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 mock.patch("sys.stdin", new=io.StringIO(payload)), \
                 contextlib.redirect_stdout(out), \
                 contextlib.redirect_stderr(err):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    rc = mod.main()
                finally:
                    os.chdir(cwd_before)
            self.assertEqual(rc, 0)
            self.assertIn("arm gate failed", err.getvalue())
            state_body = (state_dir / "state.local.md").read_text(encoding="utf-8")
            self.assertIn(
                "pending_review:", state_body,
                msg="fail-open 시에도 arm(pending_review 기록)해야 함",
            )
        finally:
            shutil.rmtree(repo, ignore_errors=True)

    def test_write_state_collapses_stale_pending_under_arm_gate_import_failure(self):
        """리뷰 발견 — `import arm_ledger`가 실패해도 write_state는 기존(다른 문서의)
        pending_review를 무조건 strip해야 한다. strip이 생략되면 블록이 둘 남고,
        Stop은 `PENDING_RE.search`(첫 매치)로 stale 블록(다른 문서)을 집어 dispatch하며,
        `rewrite_state`의 전역 `re.sub`가 방금 arm된 문서의 트리거까지 함께 지운다
        — 오류 한 줄 없는 under-review(Law 1이 금지하는 방향)."""
        import importlib.util
        import io
        spec_module = importlib.util.spec_from_file_location(
            "spec_write_validator_doublepending", HOOKS_DIR / "spec-write-validator.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        repo = _make_temp_repo()
        try:
            session_id = "test-armgate-doublepending"
            rel_a = "docs/superpowers/specs/2026-01-01-docA-design.md"
            rel_b = "docs/superpowers/specs/2026-01-01-docB-design.md"
            doc_b = repo / rel_b
            doc_b.parent.mkdir(parents=True, exist_ok=True)
            doc_b.write_text(
                "# Doc B\n\n## Goal\n\n한 줄.\n", encoding="utf-8")
            # 같은 세션 안에 이미 다른 문서(docA)의 미소비 pending_review가 있다 —
            # 같은 turn에 두 문서를 쓰고 Stop이 아직 안 돈, 정상적인 워크플로우.
            state_dir = repo / ".claude" / "spec-distill" / session_id
            state_dir.mkdir(parents=True, exist_ok=True)
            (state_dir / "state.local.md").write_text(
                f"---\nsession_id: {session_id}\n---\n\n"
                f"pending_review:\n  path: {rel_a}\n  mode: design\n"
                f"  triggered_at: 2026-01-01T00:00:00Z\n",
                encoding="utf-8",
            )
            payload = json.dumps({
                "tool_name": "Write",
                "tool_input": {"file_path": str(doc_b)},
            })
            out, err = io.StringIO(), io.StringIO()
            # sys.modules['arm_ledger'] = None → arm 게이트의 `import arm_ledger`도
            # ImportError. write_state는 이 import에 의존하지 않아야 통과한다.
            with mock.patch.dict(sys.modules, {"arm_ledger": None}), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 mock.patch("sys.stdin", new=io.StringIO(payload)), \
                 contextlib.redirect_stdout(out), \
                 contextlib.redirect_stderr(err):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    rc = mod.main()
                finally:
                    os.chdir(cwd_before)
            self.assertEqual(rc, 0)
            state_body = (state_dir / "state.local.md").read_text(encoding="utf-8")
            self.assertEqual(
                state_body.count("pending_review:"), 1,
                msg=(
                    "두 블록이 남으면 Stop이 stale 블록(docA)을 소비하고 docB의 "
                    f"트리거까지 함께 지운다 — state: {state_body!r}"
                ),
            )
            self.assertIn(str(doc_b), state_body, msg="fresh block은 docB여야 함")
            self.assertNotIn(rel_a, state_body, msg="stale docA 블록이 남아있으면 안 됨")
        finally:
            shutil.rmtree(repo, ignore_errors=True)


class TestReviewDispatchMandateScope(HookOutputSchemaTestBase):
    """mandate 가 자기 **수명**을 밝히는가, 그리고 두 수명 문장이 상호배타인가.

    수명이 적혀 있지 않았을 때 "이번 리뷰만 멈춰달라"는 요청에 세션 전체를 끄는
    환경변수가 답으로 나왔다 — 읽는 쪽이 수명을 모르면 영구로 가정하고 최대 화력을
    고른다. 아래 세 테스트는 **양방향**이라 함께 있어야 이빨이 생긴다: 하나는 문장의
    존재를, 둘은 두 문장이 서로의 분기로 새지 않음을 잰다. 한쪽만 두면 두 문장을
    모두 내보내는 mutation(같은 숨결로 모순되는 두 수명을 주장)이 GREEN 이 된다.
    """

    # 본문 고유(body-unique) 조각만 쓴다. 헤더·주석에도 있는 문구로 assert 하면
    # 정작 emit 되는 문장을 지워도 통과한다.
    SCOPE_PHRASE = "이번 dispatch 1회에만 유효"
    CAP_PHRASE = "자동 dispatch를 중단한다"

    # mandate 가 **정확히 이 문장으로 끝나야** 한다. 금지어 blacklist 로는 부족하다 —
    # 다른 표현("커밋 이후에는 자동 리뷰가 붙지 않는다")을 새로 지어 붙이면 금지어가
    # 없어 통과한다. 종결 일치로 두면 어떤 표현이든 **덧붙이는 순간** RED 다.
    EXPECTED_TAIL = "이 mandate는 이번 dispatch 1회에만 유효하다."

    IN_SCOPE_DOC = "docs/superpowers/specs/2026-08-06-scope-design.md"

    def _dispatch(self, session_id: str, *, spec_path: str, attempts: int | None = None):
        """Stop 훅을 한 번 돌리고 payload 를 돌려준다. attempts 는 사전 시도 횟수.

        `spec_path` 는 리포-루트 상대 경로다 — 그 자리에 진짜 문서를 만든다.
        원장 키는 `canonical_key` 가 내는 접두 이후 substring 이라 상대 경로와 같다.
        """
        _write_scope_doc(self.repo, spec_path)
        extra = ""
        if attempts is not None:
            extra = f"dispatch_attempts:\n  {spec_path}: {attempts}\n"
        _write_state(self.repo, session_id, extra)
        result = _run_hook(
            "review-dispatch.py", cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg=f"stdout empty; stderr: {result.stderr}")
        return json.loads(result.stdout)

    def test_normal_dispatch_states_mandate_lifetime(self):
        """정상 dispatch 는 mandate 의 수명을 밝히고, **거기서 멈춘다**."""
        reason = self._dispatch(
            "test-scope-normal", spec_path=self.IN_SCOPE_DOC,
        ).get("reason", "")
        self.assertIn(
            self.SCOPE_PHRASE, reason,
            msg=(
                "mandate 가 수명을 안 밝히면 '이번 리뷰만 멈추는 법'을 묻는 쪽이 "
                f"세션 전체 kill switch 를 고른다 — reason: {reason!r}"
            ),
        )
        # 재발동 조건을 덧붙이려는 모든 시도를 여기서 막는다. 두 번 시도했고 두 번 다
        # 거짓이었다(커밋 단정 → git fail-open / 재편집 단정 → mark_reviewed 경로).
        self.assertTrue(
            reason.rstrip().endswith(self.EXPECTED_TAIL),
            msg=(
                "mandate 가 수명 문장 뒤에 무언가를 더 주장한다. 재발동은 "
                "(원장 ∧ git ∧ 상한)의 함수이고 셋 다 emit 시점에 확정되지 않으므로 "
                f"어떤 단정도 언젠가 거짓이 된다 — reason: {reason!r}"
            ),
        )

    def test_normal_dispatch_does_not_claim_dispatch_stopped(self):
        """상한 문구가 정상 dispatch 로 새면 안 된다 (상호배타 ←)."""
        reason = self._dispatch(
            "test-scope-normal-2", spec_path=self.IN_SCOPE_DOC,
        ).get("reason", "")
        self.assertNotIn(
            self.CAP_PHRASE, reason,
            msg=f"아직 상한이 아닌데 중단을 주장한다 — reason: {reason!r}",
        )

    def test_cap_reaching_dispatch_omits_rearm_promise(self):
        """상한에 닿은 dispatch 에서는 '재편집하면 재발동' 이 거짓이다 (상호배타 →).

        그 문서는 이 세션에서 이미 중단됐다. 두 문장을 함께 내면 훅이 같은 숨결로
        서로 모순되는 두 수명을 주장한다.
        """
        payload = self._dispatch(
            "test-scope-cap", spec_path=self.IN_SCOPE_DOC,
            attempts=arm_ledger.DISPATCH_ATTEMPT_CAP - 1,
        )
        reason = payload.get("reason", "")
        self.assertIn(
            self.CAP_PHRASE, reason,
            msg=f"상한 도달을 알리지 않는다 — reason: {reason!r}",
        )
        self.assertNotIn(
            self.SCOPE_PHRASE, reason,
            msg=f"중단된 문서에 '1회 유효'를 함께 주장한다 — reason: {reason!r}",
        )


class TestMandateClaimsAreTrue(HookOutputSchemaTestBase):
    """mandate 가 **주장하는 내용이 사실인지**를 실제 훅을 태워 검증한다.

    형제 클래스 `TestReviewDispatchMandateScope` 는 문장이 `reason` 채널에 실리는지를
    잰다 — 그것만으로는 문장이 **거짓이어도** GREEN 이다. 실제로 이 PR 의 초판은
    "커밋하면 더 이상 arm 되지 않는다"를 무조건 단정했는데 `is_born()` 의 git fail-open
    경로에서 거짓이었고, 문구 락 3종은 전부 통과했다. 그래서 남긴 두 주장 각각에
    **동작 검증**을 붙인다. 주장을 줄이면 이 클래스도 함께 줄어야 한다.
    """

    DESIGN_BODY = (
        "# Test Design\n\nContext / Why\n\nGoals\n\nNon-goals\n\n"
        "Constraints\n\nAcceptance Criteria\n\nFiles\n\nVerification Plan\n\n"
        "Rejected Alternatives\n\nMetadata\n"
    )
    REL = Path("docs") / "superpowers" / "specs" / "2026-08-08-claims-design.md"

    def _write_doc(self, extra: str = "") -> Path:
        abs_path = self.repo / self.REL
        abs_path.parent.mkdir(parents=True, exist_ok=True)
        abs_path.write_text(self.DESIGN_BODY + extra, encoding="utf-8")
        return abs_path

    def _run_stop(self, sid: str):
        # TTL 가드를 **끈다**. 이 클래스가 재려는 것은 원장이 만드는 단발성이지
        # "30초 redispatch TTL" 이 아니다. 기본 TTL 로 두면 두 번째 Stop 은 밀리초
        # 안에 실행되어 TTL 이 먼저 침묵시키고, 그러면 in-flight 표시를 아예 안 찍게
        # 망가뜨려도 락이 GREEN 이 된다 — 실제로 mutation N1 이 그렇게 통과했다.
        # TTL=0 이면 침묵을 설명할 수 있는 것은 원장의 표시뿐이다.
        return _run_hook(
            "review-dispatch.py", cwd=self.repo,
            env_extra={
                "DEVBREW_SPEC_DISTILL_SESSION_ID": sid,
                "DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC": "0",
            },
        )

    def _state(self, sid: str) -> str:
        return (self.repo / ".claude" / "spec-distill" / sid
                / "state.local.md").read_text(encoding="utf-8")

    def test_claim_single_shot_holds(self):
        """주장 1: "이 mandate는 이번 dispatch 1회에만 유효하다".

        문서가 그 사이에 달라지지 않았다면 다음 Stop 이 같은 강제를 반복하지 않는다.
        예전에는 dispatch 가 연료(pending)를 **소진**해서 그것이 성립했다. 지금은
        문서가 커밋 전까지 매 턴 다시 발견되므로, 성립시키는 것은 dispatch 가 emit
        **이전에** 찍는 in-flight 표시뿐이다(A12) — 그래서 그 표시의 존재를 함께
        단언한다. 그것이 mandate 문장이 기대는 "이미 일어난 사실"이다.
        """
        sid = "test-claim-single"
        doc = self._write_doc()

        first = self._run_stop(sid)
        self.assertIn(
            "block", first.stdout,
            msg=f"전제 실패: 첫 Stop 이 강제하지 않음: {first.stdout!r} / {first.stderr!r}")
        self.assertIn(str(doc), json.loads(first.stdout).get("reason", ""),
                      msg="첫 Stop 이 이 문서를 강제한 것이 아니다")
        # **원장의 파서로 읽는다.** `state.split("inflight_paths:")[-1]` 은 블록이
        # 없으면 파일 전체를 돌려주고, `dispatch_attempts` 가 같은 `키: ` 부분문자열을
        # 담고 있어 표시가 하나도 없어도 통과했다 — 커버리지처럼 읽히는 죽은 단언.
        state = self._state(sid)
        self.assertIn(
            self.REL.as_posix(), arm_ledger.inflight(state),
            msg=f"dispatch 가 in-flight 표시를 남기지 않았다: {state!r}")

        # 문서를 건드리지 않은 채 두 번째 Stop — 주장대로면 아무것도 나오면 안 된다.
        second = self._run_stop(sid)
        self.assertEqual(
            second.stdout.strip(), "",
            msg=(
                "문서가 그대로인데 두 번째 Stop 이 다시 강제한다 — mandate 는 1회가 "
                f"아니다: {second.stdout!r}"
            ),
        )

    def _mark_reviewed(self, sid: str, abs_path: Path):
        return subprocess.run(
            ["python3", str(SCRIPTS_DIR / "arm_ledger.py"), "mark-reviewed",
             sid, str(abs_path)],
            cwd=self.repo, text=True, capture_output=True, timeout=30,
            env={"HOME": os.environ.get("HOME", "/tmp"), "PATH": os.environ["PATH"]},
        )

    def test_unreviewed_doc_rearms_after_inflight_expiry(self):
        """완료가 기록되지 않은 문서의 게이트는 한 번의 강제로 꺼지지 않는다.

        **재발동의 계기가 바뀌었다.** 예전에는 "재편집"이었다 — 편집이 PostToolUse
        훅을 태워 연료를 다시 깔았기 때문이다. dirty·untracked 문서를 다시 편집해도
        git 이 보는 사실은 달라지지 않으므로, 지금 그 자리를 지키는 것은 진행중 표시의
        TTL 만료다(`INFLIGHT_TTL_SEC` 의 계약). 편집은 시나리오를 알아보게 남겨 두되
        판정은 **강제가 다시 나가는가**로 한다 — 원장 부기가 아니라 emit 채널이다.

        형제 케이스와 짝이다: 아래는 같은 조건에서 정반대 결과를 낸다.
        """
        sid = "test-claim-reedit"
        doc = self._write_doc()
        first = self._run_stop(sid)
        self.assertIn("block", first.stdout,
                      msg=f"전제 실패: 첫 Stop 이 강제하지 않음: {first.stderr!r}")

        _expire_inflight(self.repo, sid)
        self._write_doc(extra="\n<!-- edit 2 -->\n")
        second = self._run_stop(sid)
        self.assertIn(
            "block", second.stdout,
            msg=("완료도 커밋도 되지 않은 문서인데 게이트가 다시 발동하지 않는다 — "
                 f"한 번의 강제로 조용히 꺼졌다: {second.stdout!r} / {second.stderr!r}"),
        )
        self.assertIn(str(doc), json.loads(second.stdout).get("reason", ""),
                      msg="두 번째 강제가 이 문서에 대한 것이 아니다")
        self.assertNotIn(
            "armed_paths:", self._state(sid),
            msg="verdict 가 없었는데 원장에 완료가 기록됐다 — 전제가 깨졌다")

    def test_reviewed_doc_does_NOT_rearm_after_inflight_expiry(self):
        """**완료가 기록된** 문서는 같은 조건에서도 다시 강제되지 않는다.

        이 쌍(위 테스트와 함께)이 "재발동은 …할 때 일어난다" 류의 **무조건** 단정이
        왜 불가능한지를 보인다 — 같은 상황(문서는 여전히 dirty, 진행중 표시 없음)이
        원장 상태에 따라 정반대 결과를 낸다. 초판 mandate 가 그 단정을 담았다가 여기
        걸렸다.

        `mark-reviewed` 는 완료를 쓰면서 진행중 표시를 **지운다**. 그래서 이 침묵은
        위 케이스의 TTL 로 설명되지 않는다 — 원인이 완료 기록 하나로 좁혀진다. 그
        배제를 실제로 재기 위해 진행중 표시의 부재를 함께 단언한다.
        """
        sid = "test-claim-reviewed"
        doc = self._write_doc()
        first = self._run_stop(sid)
        self.assertIn("block", first.stdout,
                      msg=f"전제 실패: 첫 Stop 이 강제하지 않음: {first.stderr!r}")
        r = self._mark_reviewed(sid, doc)
        self.assertEqual(r.returncode, 0,
                         msg=f"전제 실패: mark-reviewed rc={r.returncode} {r.stderr}")

        state = self._state(sid)
        self.assertIn(self.REL.as_posix(), arm_ledger.armed_keys(state),
                      msg=f"전제 실패: 완료가 원장에 없다: {state!r}")
        self.assertNotIn(
            self.REL.as_posix(), arm_ledger.inflight(state),
            msg=("진행중 표시가 남아 있다 — 아래 침묵이 완료 기록 때문인지 "
                 f"표시 때문인지 가를 수 없다: {state!r}"))

        self._write_doc(extra="\n<!-- edit 2 -->\n")
        second = self._run_stop(sid)
        self.assertEqual(
            second.stdout.strip(), "",
            msg=(
                "리뷰를 마친 문서가 다시 강제됐다 — arm-once 가 깨졌거나, mandate 에 "
                f"'재편집하면 재발동' 을 다시 적어도 된다는 뜻이 아니다: {second.stdout!r}"
            ),
        )


class TestReviewDispatchOrdering(unittest.TestCase):
    """AC7.3 — verify rewrite_state runs BEFORE print(json.dumps(...))."""

    @staticmethod
    def _is_decision_emit(call) -> bool:
        """`print(json.dumps({"decision": ...}))` 인가 — stderr 진단과 가른다.

        emit 딕셔너리의 `"decision"` 키 리터럴을 찾는다. 이 구분이 없으면 아래 락은
        "rewrite 뒤에 **아무 print** 나 오면 통과" 가 되는데, main() 의 print 는 대부분
        stderr 진단이라 그 조건은 거의 언제나 참이다 — 락이 GREEN 을 유지한 채 변별력만
        잃는 모양이고, 그 손실은 스위트 diff 에 보이지 않는다.
        """
        return any(isinstance(c, ast.Constant) and c.value == "decision"
                   for c in ast.walk(call))

    def _walk_calls_in_order(self, body_nodes, target_names):
        """Yield (lineno, name) for Call nodes whose func.id is in target_names.

        `print` 는 **decision emit 인 것만** 낸다 (`_is_decision_emit`).
        Recurses into FunctionDef body if encountered (handles helper refactor
        per AC7.3.1 commentary)."""
        for node in body_nodes:
            if isinstance(node, ast.Expr) and isinstance(node.value, ast.Call):
                call = node.value
                name = None
                if isinstance(call.func, ast.Name):
                    name = call.func.id
                elif isinstance(call.func, ast.Attribute):
                    name = call.func.attr
                if name in target_names:
                    if name != "print" or self._is_decision_emit(call):
                        yield (node.lineno, name)
            if isinstance(node, ast.With):
                yield from self._walk_calls_in_order(node.body, target_names)
            if isinstance(node, ast.Try):
                yield from self._walk_calls_in_order(node.body, target_names)
                for handler in node.handlers:
                    yield from self._walk_calls_in_order(handler.body, target_names)
            if isinstance(node, ast.If):
                yield from self._walk_calls_in_order(node.body, target_names)
                yield from self._walk_calls_in_order(node.orelse, target_names)
            if isinstance(node, ast.FunctionDef):
                yield from self._walk_calls_in_order(node.body, target_names)

    def test_ast_rewrite_before_print(self):
        """AC7.3.1 — static AST scan: rewrite_state appears before print."""
        source = (HOOKS_DIR / "review-dispatch.py").read_text(encoding="utf-8")
        tree = ast.parse(source)
        main_fn = next(
            n for n in tree.body
            if isinstance(n, ast.FunctionDef) and n.name == "main"
        )
        calls = list(self._walk_calls_in_order(main_fn.body, {"rewrite_state", "print"}))
        rewrite_lines = [ln for ln, n in calls if n == "rewrite_state"]
        print_lines = [ln for ln, n in calls if n == "print"]
        self.assertTrue(rewrite_lines, "no rewrite_state call found in main()")
        self.assertTrue(
            print_lines,
            "main() 에 decision emit 이 없다 — 이 락이 잴 대상 자체가 사라졌다")
        # 재는 성질은 **상태 write 가 decision emit 보다 앞선다** 이지 "언젠가 print 가
        # 나온다" 가 아니다. 그래서 `min(rewrite) < max(print)` 가 아니라
        # `max(rewrite) < max(decision emit)` 이다: 마지막 상태 write 가 마지막 emit
        # 보다 앞서야 한다. 앞의 형태는 rewrite 뒤에 stderr print 하나만 있어도
        # 통과하므로, rewrite 를 emit 뒤로 옮기는 변이를 놓친다.
        self.assertLess(
            max(rewrite_lines), max(print_lines),
            msg=(f"AC7.3.1 violated: 상태 write 가 decision emit 뒤에 있다 — "
                 f"두 번째 Stop 이 stale state 를 읽고 block storm 을 낸다. "
                 f"rewrite={rewrite_lines}, decision_emit={print_lines}"),
        )

    def test_mock_trace_rewrite_before_print(self):
        """AC7.3.3 — execute-time mock trace verifies rewrite runs first."""
        import importlib.util
        spec_module = importlib.util.spec_from_file_location(
            "review_dispatch_under_test", HOOKS_DIR / "review-dispatch.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        import builtins
        call_log: list[str] = []
        original_rewrite = mod.rewrite_state
        original_print = builtins.print

        def traced_rewrite(*args, **kwargs):
            call_log.append("rewrite_state")
            return original_rewrite(*args, **kwargs)

        def traced_print(*args, **kwargs):
            # Only count stdout prints (json emit), not stderr loud logs.
            if kwargs.get("file") is None:
                call_log.append("print_stdout")
            return original_print(*args, **kwargs)

        repo = _make_temp_repo()
        try:
            session_id = "test-mock-trace"
            _write_scope_doc(
                repo, "docs/superpowers/specs/2026-05-16-trace-design.md")
            _write_state(repo, session_id)
            # emit 을 삼킨다 — 훅의 block JSON 이 스위트 출력에 섞이면 진짜 실패를
            # 가린다. `traced_print` 의 계수는 영향받지 않는다: 그것은 `file` 인자를
            # 보지 sys.stdout 이 무엇인지를 보지 않는다.
            with mock.patch.object(mod, "rewrite_state", traced_rewrite), \
                 mock.patch.object(builtins, "print", traced_print), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 contextlib.redirect_stdout(__import__("io").StringIO()), \
                 mock.patch("sys.stdin", new=__import__("io").StringIO("{}")):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    mod.main()
                finally:
                    os.chdir(cwd_before)
        finally:
            shutil.rmtree(repo, ignore_errors=True)
        try:
            r_idx = call_log.index("rewrite_state")
        except ValueError:
            self.fail(f"rewrite_state not called; trace: {call_log}")
        try:
            p_idx = call_log.index("print_stdout")
        except ValueError:
            self.fail(f"print_stdout not called; trace: {call_log}")
        self.assertLess(
            r_idx, p_idx,
            msg=f"AC7.3.3 violated: rewrite at {r_idx}, print at {p_idx}; trace: {call_log}",
        )


class TestSpecWriteValidatorSchema(HookOutputSchemaTestBase):
    """AC2 — spec-write-validator.py advisory branch output schema."""

    def test_design_mode_advisory_emits_additional_context(self):
        # Create a valid design.md fixture so the validator passes structural
        # checks and reaches the advisory branch.
        spec_rel = Path("docs") / "superpowers" / "specs" / "2026-05-17-test-design.md"
        spec_abs = self.repo / spec_rel
        spec_abs.parent.mkdir(parents=True, exist_ok=True)
        spec_abs.write_text(
            "# Test Design\n\nContext / Why\n\nGoals\n\nNon-goals\n\n"
            "Constraints\n\nAcceptance Criteria\n\nFiles\n\nVerification Plan\n\n"
            "Rejected Alternatives\n\nMetadata\n",
            encoding="utf-8",
        )
        stdin_payload = {
            "session_id": "test-pttu",
            "hook_event_name": "PostToolUse",
            "tool_name": "Write",
            "tool_input": {"file_path": str(spec_abs)},
            "tool_output": "ok",
            "cwd": str(self.repo),
        }
        result = _run_hook(
            "spec-write-validator.py",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": "test-pttu"},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip(), msg="advisory stdout empty")
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "PostToolUse")
        ac = hso.get("additionalContext", "")
        self.assertIn("structural OK", ac)
        self.assertIn("Reviewer will be dispatched", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)
        self.assertTrue(sysmsg.startswith("[spec-distill]"))


class TestPendingReviewReminderSchema(HookOutputSchemaTestBase):
    """AC3 — pending-review-reminder.py output schema."""

    def test_pending_review_past_ttl_emits_reminder_in_additional_context(self):
        session_id = "test-reminder"
        # last_dispatched_at older than 30s default TTL.
        old_ts = "2026-05-16T00:00:00Z"
        _write_pending_review_state(
            self.repo, session_id,
            spec_path="/tmp/x-design.md", mode="design",
            worktree_path="/tmp/wt",
            last_dispatched_at=old_ts,
        )
        stdin_payload = {"user_prompt": "hi", "session_id": session_id}
        result = _run_hook(
            "pending-review-reminder.py",
            cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id},
        )
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(result.stdout.strip())
        payload = json.loads(result.stdout)
        hso = payload.get("hookSpecificOutput", {})
        self.assertEqual(hso.get("hookEventName"), "UserPromptSubmit")
        ac = hso.get("additionalContext", "")
        self.assertIn("REMINDER", ac)
        self.assertIn("pending_review", ac)
        self.assertIn("reviewing-spec", ac)
        sysmsg = payload.get("systemMessage", "")
        self.assertTrue(sysmsg)
        self.assertLessEqual(len(sysmsg), 120)


class TestKillSwitches(HookOutputSchemaTestBase):
    """AC10/AC11 — DEVBREW_SPEC_DISTILL_DISABLE=1 and DEVBREW_SKIP_HOOKS=spec-distill:<event>."""

    def _empty_or_braces(self, stdout: str) -> bool:
        s = stdout.strip()
        return s == "" or s == "{}"

    def _armed_stop_run(self, session_id: str, env_extra: dict):
        """**억제할 것이 실제로 있는** 상태에서 Stop 훅을 돌린다.

        후보가 없으면 kill switch 없이도 조용하므로, 문서를 깔지 않은 이 케이스는
        아무것도 재지 못한다(무엇을 바꿔도 GREEN). 그래서 dirty 스코프 문서를 깔고,
        **상태 파일이 바이트 단위로 그대로인지**까지 잰다 — 훅이 정말 안 돌았다는
        증거는 emit 부재가 아니라 발견 커서·in-flight 미기록이다. 이 배치의 양성
        대조는 형제 케이스 `test_discovered_doc_emits_decision_block_with_reason`
        (같은 픽스처, kill switch 없음 → block)이다.
        """
        _write_scope_doc(
            self.repo, "docs/superpowers/specs/2026-05-16-killswitch-design.md")
        state_file = _write_state(self.repo, session_id)
        before = state_file.read_bytes()
        env = {"DEVBREW_SPEC_DISTILL_SESSION_ID": session_id}
        env.update(env_extra)
        result = _run_hook("review-dispatch.py", cwd=self.repo, env_extra=env)
        self.assertEqual(result.returncode, 0, msg=f"stderr: {result.stderr}")
        self.assertTrue(self._empty_or_braces(result.stdout),
                        msg=f"kill switch 가 emit 을 막지 못했다: {result.stdout!r}")
        self.assertEqual(
            state_file.read_bytes(), before,
            msg="kill switch 가 걸렸는데 훅이 상태 파일을 건드렸다 — 안 돈 것이 아니다")

    def test_global_disable_silences_review_dispatch(self):
        self._armed_stop_run("ks-review", {"DEVBREW_SPEC_DISTILL_DISABLE": "1"})

    def test_hook_specific_disable_silences_review_dispatch(self):
        self._armed_stop_run(
            "ks-review-2", {"DEVBREW_SKIP_HOOKS": "spec-distill:Stop"})

    def test_global_disable_silences_spec_write_validator(self):
        spec_abs = self.repo / "docs" / "superpowers" / "specs" / "x-design.md"
        spec_abs.parent.mkdir(parents=True, exist_ok=True)
        spec_abs.write_text("# x\n", encoding="utf-8")
        stdin_payload = {
            "tool_name": "Write",
            "tool_input": {"file_path": str(spec_abs)},
            "hook_event_name": "PostToolUse",
        }
        result = _run_hook(
            "spec-write-validator.py", cwd=self.repo, stdin_payload=stdin_payload,
            env_extra={"DEVBREW_SPEC_DISTILL_DISABLE": "1"},
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))

    def test_global_disable_silences_pending_review_reminder(self):
        session_id = "ks-reminder"
        _write_pending_review_state(
            self.repo, session_id, spec_path="/x", mode="spec",
            last_dispatched_at="2026-05-16T00:00:00Z",  # past TTL
        )
        result = _run_hook(
            "pending-review-reminder.py", cwd=self.repo,
            stdin_payload={"user_prompt": "hi"},
            env_extra={
                "DEVBREW_SPEC_DISTILL_DISABLE": "1",
                "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
            },
        )
        self.assertEqual(result.returncode, 0)
        self.assertTrue(self._empty_or_braces(result.stdout))


def _in_worktree() -> bool:
    """Detect git worktree (vs main repo) via .git file (not dir)."""
    try:
        cp = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=REPO_ROOT, capture_output=True, text=True, timeout=3, check=False,
        )
        if cp.returncode != 0 or cp.stdout.strip() != "true":
            return False
        # main repo has .git/ dir; worktree has .git file pointing to gitdir.
        dot_git = REPO_ROOT / ".git"
        return dot_git.is_file()
    except (OSError, subprocess.TimeoutExpired):
        return False


class TestCrossResolverAdvisory(unittest.TestCase):
    """NG9 — Python state_path vs bash CLAUDE_PROJECT_DIR resolver consistency.

    Skips if not running inside a worktree (the cross-resolver mismatch only
    manifests there). PASS = both resolvers point to the same dir; FAIL = the
    follow-up unification PR is needed.
    """

    @unittest.skipUnless(_in_worktree(), "cross-resolver test runs only inside a git worktree")
    def test_python_and_bash_resolvers_agree(self):
        # Python resolver: state_path.state_root()
        sys.path.insert(0, str(SCRIPTS_DIR))
        try:
            import state_path  # type: ignore
            py_root = state_path.state_root()
        finally:
            sys.path.pop(0)
        # Bash resolver: ${CLAUDE_PROJECT_DIR:-$PWD}/.claude/spec-distill
        bash_root = Path(os.environ.get("CLAUDE_PROJECT_DIR", os.getcwd())) \
            / ".claude" / "spec-distill"
        self.assertEqual(
            py_root.resolve(), bash_root.resolve(),
            msg=(
                "Python state_path and bash CLAUDE_PROJECT_DIR resolvers disagree. "
                "Follow-up PR per spec NG9 needed."
            ),
        )


class TestInterviewDirectionLayerHook(unittest.TestCase):
    """AC9/V7/C8 — design-doc detection survives; interview/ is out of scope."""

    def setUp(self) -> None:
        self.repo = _make_temp_repo()

    def tearDown(self) -> None:
        shutil.rmtree(self.repo, ignore_errors=True)

    def _post_write(self, rel_path: str) -> subprocess.CompletedProcess:
        """Simulate a PostToolUse Write of a .md file at rel_path under the temp repo."""
        abs_path = self.repo / rel_path
        abs_path.parent.mkdir(parents=True, exist_ok=True)
        abs_path.write_text(
            "---\nname: x\n---\n\n# X\n\nsome design prose with clear components.\n",
            encoding="utf-8",
        )
        return _run_hook(
            "spec-write-validator.py",
            cwd=self.repo,
            env_extra={"DEVBREW_SPEC_DISTILL_SESSION_ID": "hooktestsession"},
            stdin_payload={
                "tool_name": "Write",
                "tool_input": {"file_path": str(abs_path)},
                "session_id": "hooktestsession",
            },
        )

    def test_design_doc_under_specs_triggers_design_mode(self) -> None:
        """AC9: -design.md under specs/ → design mode + pending_review block."""
        cp = self._post_write(
            "docs/superpowers/specs/2026-05-31-interview-direction-layer-design.md"
        )
        self.assertEqual(cp.returncode, 0, cp.stderr)
        out = json.loads(cp.stdout)
        self.assertIn("design", out["hookSpecificOutput"]["additionalContext"])
        state = (
            self.repo / ".claude" / "spec-distill" / "hooktestsession" / "state.local.md"
        )
        self.assertTrue(state.exists(), "pending_review state not written")
        body = state.read_text(encoding="utf-8")
        self.assertIn("pending_review:", body)
        self.assertIn("mode: design", body)

    def test_interview_brief_path_is_out_of_scope(self) -> None:
        """C8: docs/superpowers/interview/ is outside PATH_PREFIX → no review gate."""
        cp = self._post_write(
            "docs/superpowers/interview/2026-05-31-sample-topic-interview.md"
        )
        self.assertEqual(cp.returncode, 0, cp.stderr)
        # Out of scope → hook exits 0 silently, no additionalContext, no state written.
        self.assertEqual(cp.stdout.strip(), "", "interview/ path should produce no output")
        state = (
            self.repo / ".claude" / "spec-distill" / "hooktestsession" / "state.local.md"
        )
        self.assertFalse(state.exists(), "interview/ path must not write pending_review")


if __name__ == "__main__":
    unittest.main()
