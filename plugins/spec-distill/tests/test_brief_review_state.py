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


class TestBlankValueNewlineHazard(Base):
    """`\\s*`가 콜론 뒤에서 `\\n`을 삼켜 다음 줄의 내용을 이 라인의 값으로 오인하는 클래스의
    회귀 — KEY_STAGE/KEY_ROUNDS 읽기 경로 및 _set_scalar 쓰기 경로 양쪽 모두.
    fix round 1: 리뷰어가 재현한 3개 repro(§task-3-report.md 참고)의 회귀 락."""

    def setUp(self):
        super().setUp()
        run("init", str(self.state))

    def test_blank_stage_with_bare_word_next_line_fails_closed(self):
        # brief_review_stage:  (값 없음) 다음 줄에 `done`이 있어도 그 값을 조용히 흡수하면 안 된다.
        # rc != 0만으로는 "어떤 실패든" 통과하므로(엉뚱한 crash도 lock을 만족시킨다), reason이
        # 구체적으로 이 키·이 blank-value 가드를 지목하는지까지 확인한다.
        t = self.state_text().replace("brief_review_stage: direction",
                                       "brief_review_stage:\ndone")
        self.state.write_text(t, encoding="utf-8")
        rc, out, _ = run("get", str(self.state))
        self.assertNotEqual(rc, 0,
                             "빈 stage 값이 다음 줄의 `done`을 조용히 흡수했다 (newline hazard)")
        d = json.loads(out)
        self.assertIn("brief_review_stage", d["reason"],
                      "실패 사유가 brief_review_stage를 지목하지 않는다 (엉뚱한 실패일 수 있다)")
        self.assertIn("비어 있다", d["reason"],
                      "실패 사유가 blank-value 가드를 지목하지 않는다 (엉뚱한 실패일 수 있다)")

    def test_blank_rounds_with_bare_number_next_line_fails_closed(self):
        # brief_critic_rounds:  (값 없음) 다음 줄에 `42`가 있어도 조용히 읽고 clamp하면 안 된다
        # — 카운터를 알 수 없는 상태에서 0으로 읽는 것은 escalate 가드 방향으로 fail-open이다.
        # rc != 0만으로는 "어떤 실패든" 통과하므로, reason이 구체적으로 이 키·이 blank-value
        # 가드를 지목하는지까지 확인한다.
        t = self.state_text().replace("brief_critic_rounds: 0",
                                       "brief_critic_rounds:\n42")
        self.state.write_text(t, encoding="utf-8")
        rc, out, _ = run("get", str(self.state))
        self.assertNotEqual(rc, 0,
                             "빈 rounds 값이 다음 줄의 42를 조용히 흡수했다 (newline hazard)")
        d = json.loads(out)
        self.assertIn("brief_critic_rounds", d["reason"],
                      "실패 사유가 brief_critic_rounds를 지목하지 않는다 (엉뚱한 실패일 수 있다)")
        self.assertIn("비어 있다", d["reason"],
                      "실패 사유가 blank-value 가드를 지목하지 않는다 (엉뚱한 실패일 수 있다)")

    def test_set_stage_on_blank_stage_does_not_delete_adjacent_line(self):
        # 실제로 재현됐던 사고: brief_review_stage가 비어 있고 바로 다음 줄에
        # brief_critic_rounds: 0이 있으면, set-stage가 그 줄 전체를 삼켜 삭제했다.
        t = self.state_text().replace("brief_review_stage: direction",
                                       "brief_review_stage:")
        self.state.write_text(t, encoding="utf-8")
        self.assertIn("brief_critic_rounds: 0", self.state_text(),
                      "픽스처 전제 오류: 인접 라인이 없다")
        before = self.state_text()
        rc, _, _ = run("set-stage", str(self.state), "fidelity")
        self.assertNotEqual(rc, 0, "빈 stage 값 위에 set-stage가 조용히 성공했다")
        self.assertEqual(before, self.state_text(),
                         "실패한 set-stage가 인접 라인(brief_critic_rounds)을 삭제/변경했다")
        self.assertIn("brief_critic_rounds: 0", self.state_text(),
                      "인접 라인이 삭제됐다")

    def test_bump_on_blank_rounds_does_not_delete_adjacent_line(self):
        # 동일 클래스의 쓰기 경로 회귀 — ROUNDS 쪽. cmd_bump는 parse()를 먼저 호출하므로
        # _set_scalar에 도달하기 전에 fail-closed 되어야 하며, 인접 라인도 살아남아야 한다.
        t = self.state_text().replace("brief_critic_rounds: 0",
                                       "brief_critic_rounds:\n99")
        self.state.write_text(t, encoding="utf-8")
        self.assertIn("brief_review_degradations: []", self.state_text(),
                      "픽스처 전제 오류: 인접 라인이 없다")
        before = self.state_text()
        rc, _, _ = run("bump-critic-round", str(self.state))
        self.assertNotEqual(rc, 0, "빈 rounds 값 위에 bump가 조용히 성공했다")
        self.assertEqual(before, self.state_text(),
                         "실패한 bump가 인접 라인(brief_review_degradations)을 삭제/변경했다")
        self.assertIn("brief_review_degradations: []", self.state_text(),
                      "인접 라인이 삭제됐다")



class TestDegradationLedgerValueValidation(unittest.TestCase):
    """/qg iter-1 IMPORTANT — degradation 원장만 값 검증이 없던 결함.

    형제 두 키는 엄격하다: `brief_review_stage`는 빈 값에 ValueError·닫힌 열거 밖에
    ValueError, `brief_critic_rounds`는 빈 값·비-digit에 ValueError를 낸다. 그런데
    `brief_review_degradations`는 `[]`/`[ ]`만 특수 처리하고 **그 외 스칼라는 전부
    record 스캔으로 흘러가** 빈 리스트를 반환했다.

    결과: `brief_review_degradations: null`인 손상 원장이 `[]` + rc 0으로 읽혀,
    Step B 텍스트가 **깨끗한 run과 바이트 동일**해진다. SKILL.md가 명시로 금지한
    "기록이 없는 것과 degrade가 없는 것이 구분되지 않는다"(indeterminate ≠ clean).

    원장은 이 설계 전체가 얹힌 산출물이므로 셋 중 **가장 엄격**해야 한다.
    """

    def _state(self, degrade_line: str) -> Path:
        d = Path(tempfile.mkdtemp())
        p = d / "state.local.md"
        p.write_text(
            "---\n"
            "session_id: 11111111-1111-1111-1111-111111111111\n"
            "brief_review_stage: direction\n"
            "brief_critic_rounds: 0\n"
            f"{degrade_line}\n"
            "---\n\nbody\n", encoding="utf-8")
        return p

    def test_null_ledger_is_rejected_not_read_as_empty(self):
        p = self._state("brief_review_degradations: null")
        rc, out, _ = run("get", str(p))
        self.assertNotEqual(
            rc, 0,
            "`null` 원장이 rc 0으로 읽혔다 — 손상 원장과 깨끗한 run이 구분되지 않는다")
        self.assertNotIn(
            '"brief_review_degradations": []', out,
            "손상 원장이 빈 리스트로 렌더됐다 — 'degrade 없음'으로 표시된다")

    def test_arbitrary_scalar_ledger_is_rejected(self):
        for bad in ("not-a-list", "~", "0", "{}"):
            with self.subTest(value=bad):
                p = self._state(f"brief_review_degradations: {bad}")
                rc, _, _ = run("get", str(p))
                self.assertNotEqual(
                    rc, 0, f"스칼라 원장 {bad!r}이 통과했다 — 판독 불가를 빈 원장으로 읽는다")

    def test_degrade_append_refuses_to_splice_under_a_scalar(self):
        p = self._state("brief_review_degradations: not-a-list")
        rc, out, _ = run("degrade-append", str(p), "--component", "codex", "--reason", "x",
                          "--axis", "all", "--status", "skipped")
        self.assertNotEqual(
            rc, 0,
            "스칼라 값 아래에 record를 splice하고 ok:true를 반환했다 — 무효 frontmatter를 성공으로 보고한다")
        self.assertNotIn('"ok": true', out)

    def test_empty_block_form_and_bracket_form_still_parse(self):
        # 정상 두 형태는 계속 통과해야 한다(과잉 엄격으로 정상 경로를 잡지 않는다).
        for good in ("[]", "[ ]"):
            with self.subTest(value=good):
                p = self._state(f"brief_review_degradations: {good}")
                rc, out, _ = run("get", str(p))
                self.assertEqual(rc, 0, f"정상 원장 {good!r}이 거부됐다")
                self.assertIn('"brief_review_degradations": []', out)

if __name__ == "__main__":
    unittest.main()
