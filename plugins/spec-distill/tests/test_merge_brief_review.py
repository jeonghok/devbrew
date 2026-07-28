#!/usr/bin/env python3
"""Spec B T5 — merge_brief_review.py.

AC7(fail-closed 합집합 · codex binding) · AC8(`codex_isolated: false` 항상) ·
AC9(codex 부재 시 critic verdict 보존 + `codex_degraded: true`)

Run: cd plugins/spec-distill/tests && python3 -m unittest test_merge_brief_review -v
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "spec-distill" / "scripts" / "merge_brief_review.py"

CRITIC_APPROVED = """# Brief Fidelity Review

**Status:** Approved

```brief-critic-issues
{"issues": []}
```
"""

CRITIC_ISSUES = """# Brief Fidelity Review

**Status:** Issues Found

```brief-critic-issues
{"issues": [
  {"category": "distortion", "target_section": "#2-제약", "severity": "high",
   "message": "C1 statement가 S1 원문의 뜻을 바꿨다"}
]}
```
"""

def sub1(text: str, old: str, new: str) -> str:
    """`old` → `new` 치환. **치환이 실제로 일어났는지 확인한다.**

    `str.replace()`는 대상이 없으면 조용히 no-op이다. 픽스처 원본이 드리프트하면
    파생 픽스처가 원본과 **동일**해져 시나리오가 뒤바뀌고, 그런데도 양쪽에서 참인
    assertion 덕에 테스트는 계속 green이다(예: "findings 없음" 픽스처가 조용히
    "findings 있음"으로 되돌아가는 케이스). test_check_verbatim_coverage.sh가
    이미 `assert old in t, "fixture drift"` 관용구로 이 클래스를 막고 있다 —
    같은 가드를 파이썬 쪽에도 건다.
    """
    assert old in text, f"fixture drift: 치환 대상을 찾지 못했다 — {old[:60]!r}"
    return text.replace(old, new)


CRITIC_HEADING_STATUS = sub1(CRITIC_ISSUES, "**Status:** Issues Found",
                             "## Status: Issues Found")
CRITIC_NO_STATUS = sub1(CRITIC_ISSUES, "**Status:** Issues Found", "판정 없음")

# --- CR-1 픽스처: garbled issues 리스트 -------------------------------------
# `**Status:** Approved` + issues 원소가 계약을 어긴 경우들. 이 입력들은 fix 전에
# control(`{"issues": []}`)과 **바이트 동일** 출력을 냈다 — "리뷰어가 아무것도 못
# 찾았다"로 읽혔다는 뜻이다(indeterminate ≠ clean 위반).
def _critic_with_issues(issues_json: str) -> str:
    return ("# Brief Fidelity Review\n\n**Status:** Approved\n\n"
            "```brief-critic-issues\n" + issues_json + "\n```\n")


CRITIC_GARBLED_NON_DICT = _critic_with_issues('{"issues": ["not-a-record"]}')
CRITIC_GARBLED_MISSING_FIELD = _critic_with_issues(
    '{"issues": [{"category": "distortion", "target_section": "#2-제약", '
    '"severity": "high"}]}')          # message 없음
CRITIC_GARBLED_NON_STRING_FIELD = _critic_with_issues(
    '{"issues": [{"category": "distortion", "target_section": "#2-제약", '
    '"severity": 3, "message": "x"}]}')   # severity가 문자열이 아님
CRITIC_GARBLED_EMPTY_FIELD = _critic_with_issues(
    '{"issues": [{"category": "distortion", "target_section": "#2-제약", '
    '"severity": "high", "message": "   "}]}')   # message가 공백뿐
CRITIC_CONTROL_EMPTY = _critic_with_issues('{"issues": []}')
CRITIC_WELLFORMED_EXTRA_KEYS = _critic_with_issues(
    '{"issues": [{"category": "distortion", "target_section": "#2-제약", '
    '"severity": "high", "message": "C1이 S1을 왜곡했다", "confidence": 8, '
    '"proposed_fix": "제약 문구 교체"}]}')

CODEX_CLEAN = "findings: []\nmeta:\n  codex_failed: false\n"
CODEX_ISSUE = """findings:
  - agent: codex-reviewer
    category: omission
    target_section: "#2-제약"
    severity: high
    confidence: 8
    summary: S3 원문의 핵심이 §2에서 빠졌다
    proposed_fix: 제약 항목 추가
meta:
  codex_failed: false
"""
CODEX_FAILED = "findings: []\nmeta:\n  codex_failed: true\n  reason: missing_result\n"


def merge(critic_text, codex_text=None, omit_codex=False):
    with tempfile.TemporaryDirectory() as d:
        cpath = Path(d) / "critic.md"
        cpath.write_text(critic_text, encoding="utf-8")
        args = [sys.executable, str(SCRIPT), "--critic-output", str(cpath)]
        if not omit_codex:
            ypath = Path(d) / "codex.yaml"
            ypath.write_text(codex_text if codex_text is not None else CODEX_CLEAN,
                             encoding="utf-8")
            args += ["--codex-yaml", str(ypath)]
        proc = subprocess.run(args, capture_output=True, text=True)
        return proc.returncode, proc.stdout, proc.stderr


def kv(out):
    d = {}
    for line in out.splitlines():
        if ":" in line and not line.startswith((" ", "-")):
            k, _, v = line.partition(":")
            d[k.strip()] = v.strip()
    return d


def advisories(out):
    """`advisory:` 블록의 항목들을 실제 문자열 리스트로 추출.

    Fix round 1: `assertIn("advisory", out)` / `assertIn("codex", out.lower())`은
    `advisory:`(또는 `advisory: []`)와 `codex_verdict:`/`codex_isolated:`/
    `codex_degraded:` 키가 시나리오와 무관하게 항상 emit되므로 항상 참이었다(공허한
    assert — reviewer가 코드 축 advisory 메시지를 통째로 삭제해도 초록으로 남는 것으로
    실증). 이 헬퍼는 advisory 리스트의 **내용**을 꺼내, 그 라운드에 실제로 실린 구체적
    사유 문자열에 대해서만 단언할 수 있게 한다(`_yaml_scalar`가 특수문자 포함 시
    json.dumps로 감싼 값은 언쿠트).
    """
    lines = out.splitlines()
    try:
        i = lines.index("advisory:")
    except ValueError:
        return []
    items = []
    for line in lines[i + 1:]:
        if not line.startswith("  - "):
            break
        raw = line[4:]
        try:
            items.append(json.loads(raw))
        except json.JSONDecodeError:
            items.append(raw)
    return items


class TestExists(unittest.TestCase):
    def test_script_exists(self):
        self.assertTrue(SCRIPT.is_file(), f"스크립트 부재: {SCRIPT}")


class TestVerdictUnion(unittest.TestCase):
    def test_both_clean_approved(self):
        rc, out, _ = merge(CRITIC_APPROVED, CODEX_CLEAN)
        self.assertEqual(rc, 0)
        self.assertEqual(kv(out)["fidelity_verdict"], "approved")

    def test_critic_only_issues_makes_verdict(self):
        _, out, _ = merge(CRITIC_ISSUES, CODEX_CLEAN)
        self.assertEqual(kv(out)["fidelity_verdict"], "needs_revise")

    def test_codex_only_issues_makes_verdict(self):
        """codex는 binding — 단독으로 verdict를 만든다 (advisory 아님)."""
        _, out, _ = merge(CRITIC_APPROVED, CODEX_ISSUE)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "needs_revise")
        self.assertEqual(d["critic_verdict"], "approved")
        self.assertEqual(d["codex_verdict"], "needs_revise")

    def test_findings_carry_source_labels(self):
        _, out, _ = merge(CRITIC_ISSUES, CODEX_ISSUE)
        self.assertIn("source: critic", out)
        self.assertIn("source: codex", out)


class TestCodexIsolationLabel(unittest.TestCase):
    def test_codex_isolated_always_false_present(self):
        for critic, codex in ((CRITIC_APPROVED, CODEX_CLEAN),
                              (CRITIC_ISSUES, CODEX_ISSUE),
                              (CRITIC_APPROVED, CODEX_FAILED)):
            _, out, _ = merge(critic, codex)
            self.assertEqual(kv(out)["codex_isolated"], "false",
                             "codex_isolated: false 가 항상 출력되지 않는다")

    def test_codex_isolated_present_when_codex_omitted(self):
        _, out, _ = merge(CRITIC_APPROVED, omit_codex=True)
        self.assertEqual(kv(out)["codex_isolated"], "false")


class TestCodexDegrade(unittest.TestCase):
    def test_codex_missing_preserves_critic_verdict(self):
        _, out, _ = merge(CRITIC_ISSUES, omit_codex=True)
        d = kv(out)
        self.assertEqual(d["codex_degraded"], "true")
        self.assertEqual(d["critic_verdict"], "needs_revise")
        self.assertEqual(d["fidelity_verdict"], "needs_revise")

    def test_codex_missing_with_clean_critic_is_approved_but_loud(self):
        _, out, _ = merge(CRITIC_APPROVED, omit_codex=True)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "approved")
        self.assertEqual(d["codex_degraded"], "true")
        # `codex_degraded: true`가 있다는 것만으로는 "loud"의 증거가 아니다 — 그 키는
        # 이 시나리오에서 항상 emit된다. advisory 리스트에 codex 축이 실제로
        # skip/fail됐다는 구체적 사유 문자열이 실렸는지까지 확인한다.
        adv = advisories(out)
        self.assertTrue(
            any("SKIPPED/FAILED" in a for a in adv),
            f"codex 축 degrade가 advisory에 SKIPPED/FAILED로 실리지 않았다: {adv}")
        self.assertTrue(
            any("codex_yaml_missing" in a for a in adv),
            f"codex-yaml 부재라는 구체적 사유가 advisory에 없다: {adv}")

    def test_codex_failed_marker_is_degrade_not_clean(self):
        _, out, _ = merge(CRITIC_APPROVED, CODEX_FAILED)
        self.assertEqual(kv(out)["codex_degraded"], "true")


class TestCriticVerdictParsing(unittest.TestCase):
    def test_heading_status_line_is_recovered(self):
        """round-4 실측: `## Status:` 형식이 verdict 소실을 일으켰다."""
        _, out, _ = merge(CRITIC_HEADING_STATUS, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["critic_verdict_unrecoverable"], "false")
        self.assertEqual(d["critic_verdict"], "needs_revise")

    def test_heading_hash_separator_does_not_cross_newline(self):
        """fix round 1 실측: `#{1,6}\\s+`(heading-hash separator)가 개행을 건너뛰면
        content-free한 `##` 줄 다음, 들여쓰기된 `  Status: Approved` 줄까지 오매치한다
        — bare `Status:` 분기로는 잡히지 않는(들여쓰기가 있어) `\\s+`만의 결함이었다.
        """
        critic_text = sub1(CRITIC_APPROVED, "**Status:** Approved",
                           "##\n  Status: Approved")
        _, out, _ = merge(critic_text, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(
            d["critic_verdict_unrecoverable"], "true",
            "heading-hash separator가 개행+들여쓰기를 건너뛰어 다음 줄의 Status를 "
            "verdict로 오매치했다")

    def test_missing_status_is_unrecoverable_and_findings_still_parse(self):
        _, out, _ = merge(CRITIC_NO_STATUS, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["critic_verdict_unrecoverable"], "true")
        self.assertEqual(d["fidelity_verdict"], "needs_revise",
                         "findings가 있는데 approved로 갔다")
        self.assertIn("source: critic", out)

    def test_both_indeterminate_never_approves(self):
        """critic verdict 파싱 실패 + codex degraded → 사람에게. approved 금지."""
        # sub1이 치환 성공을 assert한다 — 드리프트하면 이 픽스처가 조용히
        # "findings 있음"으로 되돌아가고, 아래 두 assertion은 양쪽에서 참이라
        # 시나리오가 바뀐 채로 계속 green이 된다.
        no_findings = sub1(
            CRITIC_NO_STATUS,
            '{"issues": [\n  {"category": "distortion", "target_section": "#2-제약", '
            '"severity": "high",\n   "message": "C1 statement가 S1 원문의 뜻을 바꿨다"}\n]}',
            '{"issues": []}')
        self.assertIn('{"issues": []}', no_findings,
                      "픽스처가 실제로 'findings 없음'이 되지 않았다")
        _, out, _ = merge(no_findings, omit_codex=True)
        d = kv(out)
        self.assertNotEqual(d["fidelity_verdict"], "approved",
                            "양쪽 판정 불가가 approved로 해소됐다 (fail-open)")
        # `advisory:`(또는 `advisory: []`) 키는 시나리오와 무관하게 항상 emit되므로
        # `assertIn("advisory", out)`는 공허하다 — "critic verdict unrecoverable AND
        # codex degraded" 양쪽-판정-불가 분기의 사유 문자열이 실제로 실렸는지까지
        # 확인한다(critic verdict가 None일 때 항상 뜨는 별개의 일반 advisory와도
        # 구별되는, 이 분기 고유의 문구).
        adv = advisories(out)
        self.assertTrue(
            any("critic verdict unrecoverable AND codex degraded" in a for a in adv),
            f"양쪽 판정 불가 전용 advisory 사유가 실리지 않았다: {adv}")


class TestGarbledIssueElements(unittest.TestCase):
    """CR-1 — issues 원소가 계약을 어기면 `malformed`다 (조용히 버리지 않는다).

    fix 전에는 `extract_critic_issues`가 non-dict 원소를 `continue`로 버리고
    `malformed=False`를 반환해, garbled 입력이 control(`{"issues": []}`)과
    **바이트 동일** 출력을 냈다 — 잘린/깨진 critic 출력이 *"리뷰어가 아무것도
    찾지 못했다"* 로 읽혔다. 필수 4필드(`category`/`target_section`/`severity`/
    `message`; agents/brief-critic.md의 선언 스키마)는 존재해야 하고 비지 않은
    문자열이어야 한다.
    """

    GARBLED = (
        ("non-dict 원소", CRITIC_GARBLED_NON_DICT),
        ("필수 필드 누락", CRITIC_GARBLED_MISSING_FIELD),
        ("필수 필드가 non-string", CRITIC_GARBLED_NON_STRING_FIELD),
        ("필수 필드가 빈 문자열", CRITIC_GARBLED_EMPTY_FIELD),
    )

    def test_each_garbled_shape_escalates(self):
        for label, text in self.GARBLED:
            with self.subTest(shape=label):
                _, out, _ = merge(text, CODEX_CLEAN)
                self.assertNotEqual(
                    kv(out)["fidelity_verdict"], "approved",
                    f"{label}: garbled critic issues가 approved로 해소됐다 (fail-open)")

    def test_each_garbled_shape_raises_specific_advisory(self):
        for label, text in self.GARBLED:
            with self.subTest(shape=label):
                _, out, _ = merge(text, CODEX_CLEAN)
                adv = advisories(out)
                self.assertTrue(
                    any("critic issues 원소" in a for a in adv),
                    f"{label}: 원소 단위 malformed 사유가 advisory에 없다: {adv}")

    def test_garbled_differs_materially_from_control(self):
        """CR-1의 재현 그 자체 — garbled과 control이 구별 가능해야 한다."""
        _, control_out, _ = merge(CRITIC_CONTROL_EMPTY, CODEX_CLEAN)
        self.assertEqual(kv(control_out)["fidelity_verdict"], "approved")
        self.assertEqual(advisories(control_out), [])
        for label, text in self.GARBLED:
            with self.subTest(shape=label):
                _, out, _ = merge(text, CODEX_CLEAN)
                self.assertNotEqual(
                    out, control_out,
                    f"{label}: garbled 출력이 control과 바이트 동일하다")

    def test_wellformed_issue_with_extra_keys_is_not_malformed(self):
        """과잉 강화 방지 — 선택 키가 더 붙은 정상 finding은 malformed가 아니다."""
        _, out, _ = merge(CRITIC_WELLFORMED_EXTRA_KEYS, CODEX_CLEAN)
        adv = advisories(out)
        self.assertFalse(
            any("critic issues 원소" in a for a in adv),
            f"정상 finding이 malformed로 오분류됐다: {adv}")
        self.assertEqual(kv(out)["fidelity_verdict"], "needs_revise")
        self.assertIn("source: critic", out)

    def test_garbled_dict_element_is_still_carried_into_findings(self):
        """malformed 표시는 하되 정보는 버리지 않는다 — dict 원소는 그대로 실린다."""
        _, out, _ = merge(CRITIC_GARBLED_MISSING_FIELD, CODEX_CLEAN)
        self.assertIn("source: critic", out)


if __name__ == "__main__":
    unittest.main()
