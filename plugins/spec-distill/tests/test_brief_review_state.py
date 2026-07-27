#!/usr/bin/env python3
"""Spec B T6·T22(행위) — brief_review_state.py.

AC13(§6.2 전이 표: 카운터 증가 시점 · escalate 경계값 == 2 · 손상값 clamp)
AC15(degradation record 4필드 + 닫힌 enum + append-only)

Run: cd plugins/spec-distill/tests && python3 -m unittest test_brief_review_state -v
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "spec-distill" / "scripts" / "brief_review_state.py"

FRESH = """---
session_id: 22222222-2222-2222-2222-222222222222
phase: 1
probe_count: 0
---

body
"""


def run(*args):
    proc = subprocess.run([sys.executable, str(SCRIPT), *args],
                          capture_output=True, text=True)
    return proc.returncode, proc.stdout, proc.stderr


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.state = Path(self.tmp.name) / "state.local.md"
        self.state.write_text(FRESH, encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def state_text(self):
        return self.state.read_text(encoding="utf-8")


class TestScriptExists(Base):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file(), f"스크립트 부재: {SCRIPT}")


class TestInitAndGet(Base):
    def test_get_before_init_uses_defaults_without_writing(self):
        before = self.state_text()
        rc, out, _ = run("get", str(self.state))
        self.assertEqual(rc, 0)
        d = json.loads(out)
        self.assertEqual(d["brief_critic_rounds"], 0)
        self.assertEqual(d["brief_review_stage"], "direction")
        self.assertEqual(d["brief_review_degradations"], [])
        self.assertIn("brief_critic_rounds", d["migrated"])
        self.assertEqual(before, self.state_text(), "get은 state를 쓰지 않는다")

    def test_init_adds_three_keys_idempotently(self):
        rc, _, _ = run("init", str(self.state))
        self.assertEqual(rc, 0)
        t = self.state_text()
        self.assertIn("brief_review_stage: direction", t)
        self.assertIn("brief_critic_rounds: 0", t)
        self.assertIn("brief_review_degradations: []", t)
        rc, _, _ = run("init", str(self.state))
        self.assertEqual(rc, 0)
        self.assertEqual(t.count("brief_critic_rounds"),
                         self.state_text().count("brief_critic_rounds"),
                         "init 재호출이 키를 중복 추가했다")

    def test_missing_state_fails_closed(self):
        rc, _, _ = run("get", str(Path(self.tmp.name) / "nope.md"))
        self.assertNotEqual(rc, 0, "state 부재가 exit 0을 냈다 (fail-open)")


class TestTransitionTable(Base):
    """spec §6.2 전이 표 — 행 1~6 전부."""

    def setUp(self):
        super().setUp()
        run("init", str(self.state))

    def rounds(self):
        return json.loads(run("get", str(self.state))[1])["brief_critic_rounds"]

    def test_row1_first_review_keeps_counter_zero(self):
        # 최초 리뷰는 *재*라운드가 아니다 — dispatch만으로 카운터가 오르지 않는다.
        self.assertEqual(self.rounds(), 0)

    def test_row3_bump_after_fix_increments_to_one(self):
        rc, out, _ = run("bump-critic-round", str(self.state))
        self.assertEqual(rc, 0)
        self.assertEqual(json.loads(out)["brief_critic_rounds"], 1)
        self.assertEqual(self.rounds(), 1, "카운터가 state에 persist되지 않았다")

    def test_row5_counter_one_still_allows_redispatch(self):
        run("bump-critic-round", str(self.state))
        rc, _, _ = run("can-redispatch", str(self.state))
        self.assertEqual(rc, 0, "== 1 에서 escalate가 발화했다 (경계값 오류)")

    def test_row6_counter_two_escalates(self):
        run("bump-critic-round", str(self.state))
        run("bump-critic-round", str(self.state))
        self.assertEqual(self.rounds(), 2)
        rc, _, _ = run("can-redispatch", str(self.state))
        self.assertEqual(rc, 1, "== 2 에서 escalate가 발화하지 않았다 (`> 2`를 기다리는 버그)")

    def test_bump_clamps_at_two(self):
        for _ in range(4):
            run("bump-critic-round", str(self.state))
        self.assertEqual(self.rounds(), 2, "카운터가 상한 2를 넘었다")

    def test_corrupt_three_is_clamped_with_advisory_not_silent(self):
        t = self.state_text().replace("brief_critic_rounds: 0", "brief_critic_rounds: 3")
        self.state.write_text(t, encoding="utf-8")
        rc, out, _ = run("get", str(self.state))
        d = json.loads(out)
        self.assertEqual(rc, 0)
        self.assertEqual(d["brief_critic_rounds"], 2, "손상된 3이 clamp되지 않았다")
        self.assertTrue(d["clamped"], "clamp가 조용히 일어났다 (advisory 없음)")
        rc, _, _ = run("can-redispatch", str(self.state))
        self.assertEqual(rc, 1, "손상된 3이 재dispatch를 허용했다")

    def test_stage_transitions(self):
        for stage in ("direction", "fidelity", "readback", "done"):
            rc, _, _ = run("set-stage", str(self.state), stage)
            self.assertEqual(rc, 0)
            self.assertEqual(json.loads(run("get", str(self.state))[1])["brief_review_stage"],
                             stage)

    def test_bad_stage_rejected(self):
        rc, _, _ = run("set-stage", str(self.state), "whatever")
        self.assertNotEqual(rc, 0, "닫힌 열거 밖 stage가 통과했다")


class TestDegradationRecord(Base):
    def setUp(self):
        super().setUp()
        run("init", str(self.state))

    def append(self, component="codex", reason="kill switch", axis="all", status="skipped"):
        return run("degrade-append", str(self.state),
                   "--component", component, "--reason", reason,
                   "--axis", axis, "--status", status)

    def test_four_fields_persisted(self):
        rc, _, _ = self.append()
        self.assertEqual(rc, 0)
        t = self.state_text()
        for frag in ("component: codex", "affected_axis: all",
                     "verification_status: skipped"):
            self.assertIn(frag, t, f"record 필드 누락: {frag}")
        self.assertIn("reason:", t)

    def test_append_only_keeps_prior_records(self):
        self.append(component="codex")
        self.append(component="critic", axis="fidelity", status="degraded")
        recs = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual([r["component"] for r in recs], ["codex", "critic"],
                         "append가 기존 record를 덮어썼다")

    def test_probe_failure_writes_two_records(self):
        # spec §5.6: zero-tool probe 실패는 critic AND readback 2건이다.
        self.append(component="critic", axis="fidelity", status="degraded",
                    reason="zero-tool 불가 — 격리 미보장")
        self.append(component="readback", axis="readback", status="degraded",
                    reason="zero-tool 불가 — 격리 미보장")
        recs = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual({r["component"] for r in recs}, {"critic", "readback"})

    def test_reason_with_colon_and_quotes_roundtrips(self):
        nasty = 'exit 4: RuntimeError("boom") — #1'
        self.append(reason=nasty)
        recs = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual(recs[0]["reason"], nasty, "특수문자 reason이 깨졌다")

    def test_closed_enums_fail_closed(self):
        for bad in (("component", "reviewer"), ("axis", "everything"),
                    ("status", "retried")):
            field, value = bad
            kwargs = {"component": "codex", "axis": "all", "status": "skipped"}
            kwargs[field] = value
            rc, _, _ = self.append(**kwargs)
            self.assertNotEqual(rc, 0, f"닫힌 열거 밖 {field}={value} 가 통과했다")

    def test_retried_status_is_not_accepted(self):
        # round-3에서 삭제된 값 — 스키마에 되살아나면 red.
        rc, _, _ = self.append(status="retried")
        self.assertNotEqual(rc, 0)


if __name__ == "__main__":
    unittest.main()
