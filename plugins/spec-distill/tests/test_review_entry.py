#!/usr/bin/env python3
"""AC18 · AC19 — `scripts/review_entry.py` 의 은퇴 스위치 공시. 리뷰는 늘 진행된다.

프로세스로 실행해 stdout JSON 한 줄을 본다 — 소비자(`spec-review` 의 진입 펜스)가 보는
것과 같은 채널이다. 환경은 케이스마다 PATH·HOME 만 남기고 새로 짠다: 러너 셸에 켜져 있는
스위치가 케이스를 오염시키지 않게.

Run:
    cd plugins/spec-distill/tests && python3 -m unittest -v test_review_entry
"""
from __future__ import annotations

import json
import os
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


class TestEntryVerdict(unittest.TestCase):
    """AC19 — 은퇴한 끄기 이름은 리뷰를 끄지 않는다. 출력은 `advisories` 키 하나다."""

    def test_nothing_set_proceeds(self):
        self.assertEqual(run_entry(), {"advisories": []})

    def test_retired_switches_do_not_disable(self):
        for label, env in (
            ("통째", {GLOBAL_VAR: "1"}),
            ("설계 모드", {DESIGN_VAR: "1"}),
            ("review-entry 토큰", {"DEVBREW_SKIP_HOOKS": ENTRY_TOKEN}),
        ):
            with self.subTest(switch=label):
                out = run_entry(**env)
                self.assertEqual(list(out), ["advisories"])
                self.assertEqual(out["advisories"], [])

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
                self.assertEqual(list(out), ["advisories"], "은퇴 토큰은 리뷰를 끄지 않는다(D9)")
                self.assertEqual(len(out["advisories"]), 1)
                self.assertIn(tok, out["advisories"][0])

    def test_autoreview_var_1_is_named(self):
        out = run_entry(**{AUTOREVIEW_VAR: "1"})
        self.assertEqual(list(out), ["advisories"])
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

    def test_review_retired_says_review_proceeds_and_names_new_way(self):
        for tok in REVIEW_RETIRED:
            with self.subTest(tok=tok):
                msg = run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"][0]
                self.assertIn("더 이상 리뷰를 막지 않는다", msg)
                self.assertIn("이번 리뷰는 진행된다", msg)
                self.assertIn("/spec-distill:spec-review", msg)
                self.assertIn("플러그인 끄기", msg)

    def test_gone_retired_names_no_alternative(self):
        for tok in GONE_RETIRED:
            with self.subTest(tok=tok):
                msg = run_entry(DEVBREW_SKIP_HOOKS=tok)["advisories"][0]
                self.assertIn("대상이 삭제돼 아무것도 끄지 않는다", msg)
                self.assertNotIn(ENTRY_TOKEN, msg)
                self.assertNotIn(DESIGN_VAR, msg)
                self.assertNotIn("spec-distill:Stop", msg)

    def test_alternatives_name_no_retired_switch(self):
        """대신할 길 문장이 은퇴한 끄기 이름을 권하지 않는다 — 있을 때 잡히는 짝은 새 길 두 낱말이다."""
        every = ",".join(REVIEW_RETIRED + GONE_RETIRED)
        for label, env in (
            ("Stop 토큰", {"DEVBREW_SKIP_HOOKS": "spec-distill:Stop"}),
            ("전부 + AUTOREVIEW", {"DEVBREW_SKIP_HOOKS": every, AUTOREVIEW_VAR: "1"}),
        ):
            with self.subTest(case=label):
                text = " ".join(run_entry(**env)["advisories"])
                self.assertIn("/spec-distill:spec-review", text)
                self.assertIn("플러그인 끄기", text)
                for retired in (GLOBAL_VAR, DESIGN_VAR, ENTRY_TOKEN):
                    self.assertNotIn(retired, text)


if __name__ == "__main__":
    unittest.main()
