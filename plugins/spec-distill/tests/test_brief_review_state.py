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

    def test_suppression_is_a_valid_axis(self):
        """AXES에 suppression이 없으면 seed 억제 축의 degrade를 기록할 수 없다.

        brief 원안은 `import_module("plugins.spec-distill.scripts...".replace("-", "_"))`로
        상수를 직접 봤지만, 디렉토리가 하이픈(`spec-distill`)이라 그 치환이 만드는
        `plugins.spec_distill...` 경로는 존재하지 않아 ModuleNotFoundError가 난다. 이 파일의
        다른 모든 테스트처럼 subprocess CLI로 확인한다 — suppression이 실제로 쓸 수 있는
        축인지는 `degrade-append --axis suppression`의 rc로 드러난다."""
        rc, out, _ = self.append(axis="suppression")
        self.assertEqual(rc, 0, f"suppression 축이 CLI에서 거부됐다: {out}")


class TestLedgerKeyOverride(Base):
    """--ledger-key — 두 번째 파이프라인(PR3 framing-requests)이 같은 writer를 자기 원장에
    쓰게 한다. 기본 원장(brief_review_degradations)과 새 원장(framing_degradations)이
    서로를 오염시키지 않아야 하고, 오타 키는 조용히 새 원장을 만들지 않고 거부돼야 한다."""

    def setUp(self):
        super().setUp()
        run("init", str(self.state))
        # init은 표준 3키만 만든다 — framing_degradations는 PR3 SKILL이 자기 state에
        # 직접 심는 자리라, 여기서는 그 계약을 픽스처로 흉내낸다. typo_degradations도
        # 일부러 실재하는 라인으로 심는다 — 그래야 "오타 거부"가 검증이 실제로 막는 것이지
        # "그 줄이 우연히 없어서" 통과하는 별개 fail-closed 경로의 부수효과가 아님을 확인한다.
        t = self.state_text().replace(
            "brief_review_degradations: []",
            "brief_review_degradations: []\nframing_degradations: []\n"
            "typo_degradations: []")
        self.state.write_text(t, encoding="utf-8")

    def append(self, ledger_key, component="critic", axis="suppression",
               status="degraded", reason="codex 미가동"):
        return run("degrade-append", str(self.state), "--component", component,
                   "--reason", reason, "--axis", axis, "--status", status,
                   "--ledger-key", ledger_key)

    def test_ledger_key_override_writes_to_named_key(self):
        """--ledger-key가 주어지면 그 키에 append한다(기본값은 불변)."""
        rc, _, _ = self.append("framing_degradations")
        self.assertEqual(rc, 0)
        text = self.state_text()
        self.assertIn("framing_degradations:", text)
        self.assertIn("suppression", text)
        # 기본 키는 건드리지 않는다 — 두 원장이 서로를 오염시키지 않는다.
        self.assertNotIn("suppression", text.split("brief_review_degradations:")[1]
                         .split("framing_degradations:")[0])

    def test_unknown_ledger_key_is_rejected(self):
        """임의 키 생성 금지 — 오타가 조용히 새 원장을 만들면 아무도 안 읽는다."""
        rc, _, _ = self.append("typo_degradations")
        self.assertEqual(rc, 1)

    def test_get_with_ledger_key_reads_matching_ledger_not_default(self):
        """근본 해소의 증거 — write가 새 키로 갔다면 같은 키를 넘긴 get이 그것을 봐야 하고,
        키 없는 기본 get(브리프 원장)에는 새지 않아야 한다. 쓰기만 파라미터화하고 읽기가
        KEY_DEGRADE에 남으면 여기서 RED가 난다(§task-9-context.md ③)."""
        rc, _, _ = self.append("framing_degradations")
        self.assertEqual(rc, 0)
        rc, out, _ = run("get", str(self.state), "--ledger-key", "framing_degradations")
        self.assertEqual(rc, 0)
        framing = json.loads(out)["brief_review_degradations"]
        self.assertEqual([r["component"] for r in framing], ["critic"],
                         "framing_degradations로 쓴 record를 같은 키로 get이 못 읽었다")
        default = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual(default, [], "기본 get이 framing 원장의 record를 흡수했다(오염)")

    def test_get_rejects_unknown_ledger_key(self):
        """읽기 쪽도 닫힌 열거다 — 오타 키로 get하면 빈 리스트가 아니라 실패해야 한다."""
        rc, _, _ = run("get", str(self.state), "--ledger-key", "typo_degradations")
        self.assertEqual(rc, 1)


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


class TestInitLedgerKey(Base):
    """`init --ledger-key` — 두 번째 파이프라인(framing-requests)이 자기 원장 줄을
    갖게 한다.

    이 옵션이 없던 판에서는 이런 상태였다: `framing_degradations`가 `LEDGER_KEYS`
    안에는 있는데 그 줄을 심는 코드가 어디에도 없어서, `degrade-append
    --ledger-key framing_degradations`가 항상 `"…라인 부재 — init을 먼저
    실행하라"`로 죽었다. 닫힌 열거에 이름이 있다는 것과 그 원장에 쓸 수 있다는 것은
    다른 사실이다.

    **기본값 경로는 바뀌면 안 된다.** brief 파이프라인의 SKILL 이 「키 3개」라고
    적고 있으므로, 인자 없는 `init`이 네 번째 줄을 심으면 그 문장이 거짓이 된다."""

    def test_default_init_does_not_plant_the_second_ledger(self):
        rc, _, _ = run("init", str(self.state))
        self.assertEqual(rc, 0)
        self.assertNotIn("framing_degradations", self.state_text(),
                         "인자 없는 init이 두 번째 원장을 심었다 — brief SKILL의 「키 3개」가 거짓이 된다")

    def test_ledger_key_plants_that_ledger_line(self):
        rc, out, _ = run("init", str(self.state), "--ledger-key", "framing_degradations")
        self.assertEqual(rc, 0)
        self.assertIn("framing_degradations: []", self.state_text())
        self.assertIn("framing_degradations", json.loads(out)["added"])

    def test_ledger_key_keeps_the_standard_three(self):
        """**추가**이지 치환이 아니다 — 기본 원장이 사라지면 brief 쪽 degrade가 통째로 죽는다."""
        run("init", str(self.state), "--ledger-key", "framing_degradations")
        t = self.state_text()
        self.assertIn("brief_review_stage: direction", t)
        self.assertIn("brief_critic_rounds: 0", t)
        self.assertIn("brief_review_degradations: []", t)

    def test_ledger_key_init_is_idempotent(self):
        run("init", str(self.state), "--ledger-key", "framing_degradations")
        t = self.state_text()
        rc, _, _ = run("init", str(self.state), "--ledger-key", "framing_degradations")
        self.assertEqual(rc, 0)
        self.assertEqual(t.count("framing_degradations"),
                         self.state_text().count("framing_degradations"),
                         "재호출이 원장 줄을 중복 추가했다")

    def test_unknown_ledger_key_is_rejected(self):
        """오타가 조용히 새 원장을 만들면 아무도 안 읽는다 — get/degrade-append와 같은 규율."""
        rc, out, _ = run("init", str(self.state), "--ledger-key", "typo_degradations")
        self.assertEqual(rc, 1)
        self.assertNotIn("typo_degradations", self.state_text())

    def test_append_works_after_ledger_key_init_without_hand_editing(self):
        """C2 의 근본 해소 증거 — 픽스처를 손으로 고치지 않고 init → append 가 이어진다.

        이 테스트만이 「이름이 열거에 있다」가 아니라 「그 원장에 실제로 쓸 수 있다」를
        잰다. 다른 단언들은 줄의 존재만 본다."""
        rc, _, _ = run("init", str(self.state), "--ledger-key", "framing_degradations")
        self.assertEqual(rc, 0)
        rc, out, _ = run("degrade-append", str(self.state),
                         "--component", "codex", "--reason", "codex 미가용: kill_switch",
                         "--axis", "suppression", "--status", "skipped",
                         "--ledger-key", "framing_degradations")
        self.assertEqual(rc, 0, f"init 직후 append가 실패했다: {out}")
        rc, out, _ = run("get", str(self.state), "--ledger-key", "framing_degradations")
        self.assertEqual(rc, 0)
        recs = json.loads(out)["brief_review_degradations"]
        self.assertEqual([r["component"] for r in recs], ["codex"])
        default = json.loads(run("get", str(self.state))[1])["brief_review_degradations"]
        self.assertEqual(default, [], "기본 원장이 framing record를 흡수했다(오염)")
