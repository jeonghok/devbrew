#!/usr/bin/env python3
"""발견-구동 dispatch 대상 선택 — `select_dispatch_target` 의 술어.

dispatch 연료가 상태 파일의 블록에서 **발견된 후보**로 바뀌면, "같은 문서를 매 턴
다시 dispatch 하지 않는다" 를 지탱하던 소진(consumption) 이 사라진다. 그 자리를
원장의 세 표시(in-flight TTL · `dispatch_attempts` 상한 · `armed_paths`) 가 맡는다.
이 파일은 그 대체가 실제로 성립하는지를 **단위 수준**에서 잠근다.

제외 술어마다 **양성 짝**이 붙어 있다 — 제외만 단언하면 "언제나 None" 인 구현에서도
전부 공허하게 참이 된다.
"""
# 이 박스의 python3 는 3.9 라 `X | None` 주석이 def 시점에 평가돼 TypeError 를 낸다.
from __future__ import annotations

import contextlib
import importlib.util
import io
import subprocess
import sys
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

REPO = Path(subprocess.run(["git", "rev-parse", "--show-toplevel"],
                           capture_output=True, text=True, check=True).stdout.strip())
HOOK = REPO / "plugins" / "spec-distill" / "hooks" / "review-dispatch.py"
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import arm_ledger  # noqa: E402  # pyright: ignore[reportMissingImports]
from discover_candidates import Candidate  # noqa: E402  # pyright: ignore[reportMissingImports]

spec = importlib.util.spec_from_file_location("rd_dispatch", HOOK)
rd = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rd)

#: 상한은 `arm_ledger` 의 상수에서만 온다. 숫자를 다시 적으면 진실의 출처가 둘이 되고,
#: `DISPATCH_ATTEMPT_CAP`(:45) 과 `VALIDATION_ATTEMPT_CAP`(:58) 이 **별도 상수**라는
#: 계약(설계 §4.4)이 테스트 쪽에서 조용히 무너진다.
DCAP = arm_ledger.DISPATCH_ATTEMPT_CAP
VCAP = arm_ledger.VALIDATION_ATTEMPT_CAP

NOW = datetime(2026, 8, 23, 12, 0, 0, tzinfo=timezone.utc)
ROOT = "/tmp/not-a-real-repo"
KEY = "docs/superpowers/specs/2026-08-23-target-design.md"
EARLIER = "docs/superpowers/specs/2026-08-23-aaa-design.md"


def body(*blocks: str) -> str:
    """frontmatter + 0-indent 원장 블록들. 원장 writer 가 내는 모양 그대로."""
    return "---\nsession_id: t\n---\n\n" + "\n".join(blocks)


def iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def cand(key: str = KEY, *, born: bool = False) -> Candidate:
    """발견이 내는 모양의 후보 — `path` 는 **절대경로**다(`discover()` 의 계약)."""
    return Candidate(path=f"{ROOT}/{key}", key=key, born=born)


class SelectDispatchTargetBase(unittest.TestCase):
    def select(self, cands, state_body="", now=NOW):
        return rd.select_dispatch_target(cands, state_body, now)


class TestNothingToDispatch(SelectDispatchTargetBase):
    def test_no_candidates_selects_nothing(self):
        self.assertIsNone(self.select([]))


class TestBornIsNotReviewed(SelectDispatchTargetBase):
    """git 이 이미 아는 문서는 dispatch 대상이 아니다.

    `arm_ledger.is_born` 의 계약대로 `git add` 만 된 것도 태어난 것으로 본다 —
    저자가 리포에 넣기로 **이미 결정했다**는 뜻이다. 리뷰 대상은 그 반대편, 아직
    tracked 가 아닌 문서다.
    """

    def test_born_candidate_is_not_selected(self):
        self.assertIsNone(self.select([cand(born=True)]))

    def test_positive_same_candidate_unborn_is_selected(self):
        # 양성 짝 — 위 케이스가 재는 것이 born 축임을 고정한다.
        self.assertEqual(self.select([cand(born=False)]), cand(born=False))


class TestLedgerExclusions(SelectDispatchTargetBase):
    """원장의 세 표시가 반복 dispatch 를 막는다."""

    def test_armed_candidate_is_excluded(self):
        b = body(f"armed_paths:\n  - {KEY}\n")
        self.assertIsNone(self.select([cand()], b))

    def test_positive_other_key_armed_does_not_exclude(self):
        b = body(f"armed_paths:\n  - {EARLIER}\n")
        self.assertEqual(self.select([cand()], b), cand())

    def test_dispatch_capped_candidate_is_excluded(self):
        b = body(f"dispatch_attempts:\n  {KEY}: {DCAP}\n")
        self.assertIsNone(self.select([cand()], b))

    def test_positive_one_below_dispatch_cap_is_selected(self):
        # 경계 — `>=` 가 `>` 로 밀리면 이 짝 중 하나가 반드시 깨진다.
        b = body(f"dispatch_attempts:\n  {KEY}: {DCAP - 1}\n")
        self.assertEqual(self.select([cand()], b), cand())

    def test_validation_capped_candidate_is_excluded(self):
        """A14 의 dispatch 절반 — 구조 검증 상한에 닿은 문서는 리뷰어에게도 안 간다."""
        b = body(f"validation_attempts:\n  {KEY}: {VCAP}\n")
        self.assertIsNone(self.select([cand()], b))

    def test_positive_one_below_validation_cap_is_selected(self):
        b = body(f"validation_attempts:\n  {KEY}: {VCAP - 1}\n")
        self.assertEqual(self.select([cand()], b), cand())

    def test_inflight_candidate_is_excluded(self):
        """A12 — 리뷰가 도는 중인 문서는 다시 dispatch 되지 않는다."""
        b = body(f"inflight_paths:\n  {KEY}: {iso(NOW)}\n")
        self.assertIsNone(self.select([cand()], b))

    def test_positive_expired_inflight_is_selected(self):
        """TTL 이 만료되면 되돌아온다 — 죽은 리뷰가 게이트를 영구히 닫지 않는다."""
        stale = NOW - timedelta(seconds=arm_ledger.INFLIGHT_TTL_SEC + 60)
        b = body(f"inflight_paths:\n  {KEY}: {iso(stale)}\n")
        self.assertEqual(self.select([cand()], b), cand())


class TestSelectionScansPastExclusions(SelectDispatchTargetBase):
    """제외된 후보가 뒤의 적격 후보를 가리면 안 된다.

    가리면 armed 문서 하나가 그 세션의 모든 dispatch 를 조용히 막는다 — 발견이
    정렬된 목록을 주므로 그 문서는 매 턴 같은 자리에 온다.
    """

    def test_excluded_first_candidate_does_not_hide_the_next(self):
        b = body(f"armed_paths:\n  - {EARLIER}\n")
        got = self.select([cand(EARLIER), cand(KEY)], b)
        self.assertEqual(got, cand(KEY))


class TestOutOfModeCandidates(SelectDispatchTargetBase):
    """모드가 없는 문서는 dispatch 하지 않는다.

    `canonical_key` 는 in-scope 만 보고 확장자를 보지 않으므로 접두 아래의
    `notes.txt` 도 후보가 된다. 리뷰어는 mode 로 라우팅하므로 mode 가 없는 문서를
    보내면 "mode: None" 을 강제하는 셈이다. `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE`
    도 같은 자리로 떨어진다 — kill switch 는 보안 컨트롤이라 dispatch 가 그것을
    우회하면 안 된다(CLAUDE.md).
    """

    def test_non_markdown_candidate_is_not_selected(self):
        key = "docs/superpowers/specs/notes.txt"
        self.assertIsNone(self.select([cand(key)]))

    def test_design_mode_kill_switch_excludes_design_docs(self):
        with mock.patch.dict(
                "os.environ", {"DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE": "1"}):
            self.assertIsNone(self.select([cand()]))

    def test_positive_same_doc_without_the_kill_switch_is_selected(self):
        self.assertEqual(self.select([cand()]), cand())


class TestLedgerUnavailable(SelectDispatchTargetBase):
    """원장을 못 읽으면 dispatch 하지 않는다 — loud 하되 루프하지 않는다.

    방향이 검증 쪽과 같다: 상한을 셀 수 없는 상태에서 dispatch 하면 in-flight 표시도
    못 남기므로 다음 Stop 이 같은 문서를 다시 찾아 **상한 없는 block 루프**가 된다
    (CLAUDE.md: Unbounded autonomy). 조용히 떨어지지는 않는다.
    """

    def test_missing_ledger_selects_nothing_loudly(self):
        err = io.StringIO()
        with mock.patch.dict(sys.modules, {"arm_ledger": None}), \
             contextlib.redirect_stderr(err):
            got = self.select([cand()])
        self.assertIsNone(got)
        self.assertIn("원장", err.getvalue(),
                      msg=f"조용히 dispatch 를 접었다: {err.getvalue()!r}")


if __name__ == "__main__":
    unittest.main()
