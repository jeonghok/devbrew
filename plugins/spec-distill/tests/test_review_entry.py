#!/usr/bin/env python3
"""AC4 · AC5 — `scripts/review_entry.py` 의 끄기 판정과 은퇴 스위치 공시.

프로세스로 실행해 stdout JSON 한 줄을 본다 — 소비자(`reviewing-spec` 의 진입 펜스)가 보는
것과 같은 채널이다. 환경은 케이스마다 PATH·HOME 만 남기고 새로 짠다: 러너 셸에 켜져 있는
스위치가 케이스를 오염시키지 않게.

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_review_entry
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "review_entry.py"

ENTRY_TOKEN = "spec-distill:review-entry"
DESIGN_VAR = "DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"
GLOBAL_VAR = "DEVBREW_SPEC_DISTILL_DISABLE"
AUTOREVIEW_VAR = "DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW"
REVIEW_RETIRED = ("spec-distill:Stop", "spec-distill:review-dispatch")
GONE_RETIRED = ("spec-distill:validator", "spec-distill:PostToolUse",
                "spec-distill:reminder", "spec-distill:UserPromptSubmit")


def run_raw(**env_extra: str) -> subprocess.CompletedProcess:
    env = {"PATH": os.environ["PATH"], "HOME": os.environ.get("HOME", "/tmp"),
           "PYTHONDONTWRITEBYTECODE": "1"}
    env.update(env_extra)
    return subprocess.run(["python3", str(SCRIPT)], env=env, capture_output=True,
                          text=True, encoding="utf-8", timeout=10)


def run_entry(**env_extra: str) -> dict:
    cp = run_raw(**env_extra)
    if cp.returncode != 0:
        raise AssertionError(f"rc={cp.returncode} stderr={cp.stderr}")
    lines = cp.stdout.splitlines()
    if len(lines) != 1:
        raise AssertionError(f"stdout 이 JSON 한 줄이 아니다: {cp.stdout!r}")
    return json.loads(lines[0])


class TestDisabledVerdict(unittest.TestCase):
    """AC4 — 끄는 스위치 셋과 `=0`·무설정."""

    def test_nothing_set_proceeds(self):
        self.assertEqual(run_entry(), {"disabled": False, "reason": None, "advisories": []})

    def test_global_disable(self):
        out = run_entry(**{GLOBAL_VAR: "1"})
        self.assertTrue(out["disabled"])
        self.assertEqual(out["reason"], f"{GLOBAL_VAR}=1")

    def test_entry_token(self):
        out = run_entry(DEVBREW_SKIP_HOOKS=ENTRY_TOKEN)
        self.assertTrue(out["disabled"])
        self.assertEqual(out["reason"], f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}")

    def test_entry_token_among_others_with_spaces(self):
        out = run_entry(DEVBREW_SKIP_HOOKS=f"quality-gates:Stop, {ENTRY_TOKEN} ")
        self.assertTrue(out["disabled"])

    def test_design_mode_disable(self):
        out = run_entry(**{DESIGN_VAR: "1"})
        self.assertTrue(out["disabled"])
        self.assertEqual(out["reason"], f"{DESIGN_VAR}=1")

    def test_zero_values_do_not_disable(self):
        for var in (GLOBAL_VAR, DESIGN_VAR):
            with self.subTest(var=var):
                self.assertFalse(run_entry(**{var: "0"})["disabled"])

    def test_superstring_entry_token_does_not_disable(self):
        self.assertFalse(run_entry(DEVBREW_SKIP_HOOKS=ENTRY_TOKEN + "-v2")["disabled"])

    def test_c_locale_still_one_json_line(self):
        cp = run_raw(LC_ALL="C", DEVBREW_SKIP_HOOKS="spec-distill:Stop")
        self.assertEqual(cp.returncode, 0, cp.stderr)
        self.assertEqual(len(cp.stdout.splitlines()), 1)
        self.assertIn("더 이상 리뷰를 막지 않는다", cp.stdout,
                      "한국어가 \\uXXXX 로 나가면 사람이 읽는 advisory 가 판독 불가다")


class TestRetiredSwitchAdvisory(unittest.TestCase):
    """AC5 — 은퇴 스위치 일곱. 각 스위치를 읽던 방식 그대로 읽는다.

    토큰은 콤마 분리 + 양끝 공백 제거 + 전체 일치(부분 문자열이면 설정하지 않은 토큰을
    설정했다고 말한다), `SKIP_AUTOREVIEW` 는 `== "1"`(설정만 보면 `=0` 으로 꺼 둔 사용자에게
    거짓을 말한다).
    """

    def test_each_retired_token_is_named_and_does_not_disable(self):
        for tok in REVIEW_RETIRED + GONE_RETIRED:
            with self.subTest(tok=tok):
                out = run_entry(DEVBREW_SKIP_HOOKS=tok)
                self.assertFalse(out["disabled"], "은퇴 토큰은 리뷰를 끄지 않는다(D9)")
                self.assertEqual(len(out["advisories"]), 1)
                self.assertIn(tok, out["advisories"][0])

    def test_autoreview_var_1_is_named(self):
        out = run_entry(**{AUTOREVIEW_VAR: "1"})
        self.assertFalse(out["disabled"])
        self.assertEqual(len(out["advisories"]), 1)
        self.assertIn(AUTOREVIEW_VAR, out["advisories"][0])

    def test_autoreview_var_not_1_is_silent(self):
        for value in ("0", "", "true", "yes"):
            with self.subTest(value=value):
                self.assertEqual(run_entry(**{AUTOREVIEW_VAR: value})["advisories"], [])

    def test_superstring_retired_token_is_silent(self):
        for tok in ("spec-distill:validator-v2", "spec-distill:Stop2"):
            with self.subTest(tok=tok):
                self.assertEqual(run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"], [])

    def test_review_retired_says_review_proceeds_and_names_new_switches(self):
        for tok in REVIEW_RETIRED:
            with self.subTest(tok=tok):
                msg = run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"][0]
                self.assertIn("더 이상 리뷰를 막지 않는다", msg)
                self.assertIn("이번 리뷰는 진행된다", msg)
                self.assertIn(f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}", msg)
                self.assertIn(f"{DESIGN_VAR}=1", msg)

    def test_review_retired_with_live_switch_states_why_off(self):
        out = run_entry(DEVBREW_SKIP_HOOKS="spec-distill:Stop", **{DESIGN_VAR: "1"})
        self.assertTrue(out["disabled"])
        msg = out["advisories"][0]
        self.assertNotIn("이번 리뷰는 진행된다", msg)
        self.assertIn(f"{DESIGN_VAR}=1 때문에 꺼졌다", msg)

    def test_review_retired_with_entry_token_in_same_list(self):
        out = run_entry(DEVBREW_SKIP_HOOKS=f"spec-distill:Stop,{ENTRY_TOKEN}")
        self.assertTrue(out["disabled"])
        self.assertIn(f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN} 때문에 꺼졌다", out["advisories"][0])

    def test_gone_retired_names_no_alternative(self):
        for tok in GONE_RETIRED:
            with self.subTest(tok=tok):
                msg = run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"][0]
                self.assertIn("대상이 삭제돼 아무것도 끄지 않는다", msg)
                self.assertNotIn(ENTRY_TOKEN, msg)
                self.assertNotIn(DESIGN_VAR, msg)
                self.assertNotIn("spec-distill:Stop", msg)

    def test_advisories_point_only_at_live_switches(self):
        """advisory 가 «권하는» 스위치는 전부 살아 있는 끄기 스위치다.

        사용자 자신의 `SKIP_AUTOREVIEW=1` 읽기(`{AUTOREVIEW_VAR}=1 은 읽는 곳이 없어…`)는
        권유가 아니라 되읽기라, 셈에 넣기 전에 그 문장을 지워 걸러낸다 — 지우지 않으면 그
        문장 자신이 「권하는 스위치」로 오추출된다. 은퇴한 `{AUTOREVIEW_VAR}=1` 은 이제
        허용 집합에 없다 — 권해도 안 되는 죽은 스위치다. 토큰 되읽기(`DEVBREW_SKIP_HOOKS 의
        spec-distill:Stop`)는 `=` 가 없어 추출되지 않는다.
        """
        live = {f"DEVBREW_SKIP_HOOKS={ENTRY_TOKEN}", f"{DESIGN_VAR}=1", f"{GLOBAL_VAR}=1"}
        every = ",".join(REVIEW_RETIRED + GONE_RETIRED)
        out = run_entry(DEVBREW_SKIP_HOOKS=every, **{AUTOREVIEW_VAR: "1"})
        text = " ".join(out["advisories"])
        text = text.replace(f"{AUTOREVIEW_VAR}=1 은 읽는 곳이 없어", "")
        suggested = set(re.findall(
            r"DEVBREW_SKIP_HOOKS=spec-distill:[A-Za-z-]+|DEVBREW_[A-Z_]+=1", text))
        self.assertTrue(suggested, "권하는 스위치를 하나도 못 뽑았다 — 추출이 깨졌다")
        self.assertLessEqual(suggested, live)


if __name__ == "__main__":
    unittest.main()
