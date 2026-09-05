"""Task 6 — merge_brief_review.py 를 Ledger 로 전환한 회계가 실제 호출부에서 나오는지.

§9.1 잡종: 데이터는 fail-open, verdict 는 fail-closed. 이 스크립트에서 그 잡종은
두 갈래로 갈린다 —
  - `:162-167` 비-dict critic issue 원소: findings 로 승격 못 하고 **버려진다**(소실)
    → `L.hold(...)`.
  - `:168-175` 필수 필드가 나빠도 `kept.append(it)`로 **실린다**(fail-open 데이터
    경로 — 소실이 아니다) → `L.accept(it)`.
같은 어휘로 세면 이 설계가 없애려는 혼동 그 자체이므로, 두 사유가 advisory 에서
서로 다른 문구로 실제로 갈리는지를 잰다.

**call-site 를 구동한다** — `Ledger` 를 직접 만들어 단언하지 않는다. 손으로 만든
Ledger 단언은 전환을 되돌리거나 배선(`L.hold(...)` 호출 자체)을 지워도 통과한다
(Task 5 재리뷰가 실측한 함정). 여기 모든 테스트는 subprocess 로 실제 `main()`을
호출하고 emit 된 문서를 파싱해 `advisory`/불변 verdict 키를 단언한다.
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
SCRIPT = REPO_ROOT / "plugins" / "spec-distill" / "scripts" / "merge_brief_review.py"

# Task 10 수정 라운드 1 — 처분 회계(adjudication_*)가 stdout 계약에 들어오면서
# 8개(원래 §9.1 검토 시점)에서 21개로 늘었다. 이 락은 «금지»가 아니라 신중함
# 게이트다 — 「정확히 선언된 집합」이라는 계약은 새 집합을 «선언»하면 충족된다.
# 늘리는 커밋은 이 리터럴을 같은 커밋에서 갱신해 확장을 보이게 해야 한다.
DECLARED_KEYS = {
    "fidelity_verdict", "critic_verdict", "codex_verdict",
    "critic_verdict_unrecoverable", "codex_isolated", "codex_degraded",
    "fidelity_findings", "advisory",
    "adjudication_held", "adjudication_unknown", "adjudication_accepted",
    "adjudication_rejected", "adjudication_absorbed", "adjudication_coerced",
    "adjudication_sources_failed", "adjudication_suppressed",
    "adjudication_unknown_counts", "adjudication_degraded",
    "adjudication_held_unadjudicated", "adjudication_held_malformed",
    "adjudication_held_other",
}

CODEX_CLEAN = "findings: []\nmeta:\n  codex_failed: false\n"


def _critic(status: str, issues_json: str) -> str:
    return (f"# Brief Fidelity Review\n\n**Status:** {status}\n\n"
            "```brief-critic-issues\n" + issues_json + "\n```\n")


CRITIC_NON_DICT = _critic("Approved", '{"issues": ["not-a-record"]}')
CRITIC_BAD_FIELD_KEPT = _critic(
    "Approved",
    '{"issues": [{"category": "distortion", "target_section": "#2-제약", '
    '"severity": "high"}]}')  # message 없음 — 필드 나쁘지만 record 는 유지돼야 한다
CRITIC_NO_SENTINEL = "# Brief Fidelity Review\n\n**Status:** Approved\n"
CRITIC_CLEAN = _critic("Approved", '{"issues": []}')

# 중복 codex_failed 마커 → malformed. finding 1건이 파싱된 뒤 마커 위반이 걸린다
# (parse_codex_yaml: `if cur: findings.append(cur)` 가 malformed 판정보다 먼저 실행).
CODEX_MALFORMED_ONE_FINDING = (
    "findings:\n"
    "  - category: a\n"
    "    target_section: b\n"
    "    severity: high\n"
    "meta:\n"
    "  codex_failed: false\n"
    "  codex_failed: false\n")


def run(critic_text, codex_text=None, omit_codex=False):
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


def top_level_keys(out):
    keys = set()
    for line in out.splitlines():
        if ":" in line and not line.startswith((" ", "-")):
            k, _, _ = line.partition(":")
            keys.add(k.strip())
    return keys


def advisories(out):
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


class TestDroppedElementIsHeld(unittest.TestCase):
    """`:162-167` — 비-dict 원소는 findings 로 승격 못 하고 버려진다. 이것이 «소실»
    이고, Ledger 의 `hold()` 로 회계돼야 한다 — Ledger.reasons() 는 "보류: <item> —
    <why>" 형태를 낸다(shared/adjudication/adjudication.py 의 reasons())."""

    def test_advisory_carries_ledger_hold_line_for_dropped_element(self):
        _, out, err = run(CRITIC_NON_DICT, CODEX_CLEAN)
        adv = advisories(out)
        self.assertTrue(
            any("finding 승격 불가" in a for a in adv),
            f"비-dict 원소가 버려졌다는 Ledger hold() 사유가 advisory 에 없다: {adv}\nstderr={err}")

    def test_hold_reason_uses_repr_not_str(self):
        """critic 은 LLM 저작이다 — hold() 사유의 item 은 repr()로 담겨야 한다
        (correction #3: str() 을 쓰면 개행 포함 문자열이 advisory 줄을 깨뜨릴 수 있다)."""
        _, out, _ = run(CRITIC_NON_DICT, CODEX_CLEAN)
        adv = advisories(out)
        # repr("not-a-record") == "'not-a-record'" — 따옴표가 살아 있어야 repr 이다.
        self.assertTrue(
            any("'not-a-record'" in a for a in adv),
            f"hold() item 이 repr() 로 담기지 않았다(따옴표 소실): {adv}")


class TestKeptMalformedElementIsAcceptedNotHeld(unittest.TestCase):
    """`:168-175` — 필수 필드가 나빠도 record 자체는 findings 에 실린다(fail-open
    데이터 경로, §9.1). 이것은 소실이 아니므로 Ledger 의 `hold()` 어휘("보류:")로
    세면 안 된다 — `accept()`는 reasons()에 아무 줄도 남기지 않는다."""

    def test_kept_record_still_reaches_findings(self):
        _, out, _ = run(CRITIC_BAD_FIELD_KEPT, CODEX_CLEAN)
        self.assertIn("source: critic", out,
                      "필드가 나쁜 record 가 findings 에서 사라졌다 — fail-open 계약 위반")

    def test_kept_record_does_not_produce_a_hold_line(self):
        _, out, _ = run(CRITIC_BAD_FIELD_KEPT, CODEX_CLEAN)
        adv = advisories(out)
        self.assertFalse(
            any(a.startswith("보류:") for a in adv),
            f"유지된(accept) record 가 hold() 어휘로 새어나갔다 — 소실과 유지가 뒤섞였다: {adv}")

    def test_vocabulary_actually_differs_between_the_two_paths(self):
        """이 태스크의 핵심 — 버림과 유지가 같은 어휘를 쓰면 이 프로젝트의 주제 위반."""
        _, dropped_out, _ = run(CRITIC_NON_DICT, CODEX_CLEAN)
        _, kept_out, _ = run(CRITIC_BAD_FIELD_KEPT, CODEX_CLEAN)
        dropped_adv = advisories(dropped_out)
        kept_adv = advisories(kept_out)
        self.assertTrue(any(a.startswith("보류:") for a in dropped_adv),
                        "버려진 경로에 hold() 어휘가 없다")
        self.assertFalse(any(a.startswith("보류:") for a in kept_adv),
                         "유지된 경로에 hold() 어휘가 새어 들어왔다")


class TestCriticSourceFailedIsPrimary(unittest.TestCase):
    """`:274` escalates — critic 은 주(主) 판정자다. critic 이 완전히 깨지면
    (sentinel 자체 부재) `L.source_failed("critic", ..., primary=True)`가
    회계에 남아야 한다. escalates 값 자체(needs_revise)는 이미 검증됨
    (test_merge_brief_review.py) — 여기서는 Ledger 회계만 잰다."""

    def test_critic_broken_is_recorded_as_primary_source_failure(self):
        _, out, _ = run(CRITIC_NO_SENTINEL, CODEX_CLEAN)
        adv = advisories(out)
        self.assertTrue(
            any("입력 실패(주): critic" in a for a in adv),
            f"critic 파손이 주(主) source_failed 로 회계되지 않았다: {adv}")

    def test_clean_critic_has_no_source_failed_line(self):
        _, out, _ = run(CRITIC_CLEAN, CODEX_CLEAN)
        adv = advisories(out)
        self.assertFalse(
            any("입력 실패(주): critic" in a for a in adv),
            f"멀쩡한 critic 이 source_failed 로 오분류됐다: {adv}")


class TestCodexSourceFailedIsAuxiliary(unittest.TestCase):
    """`:302` codex_degraded — codex 는 보조(모델 다양성)다. 실패해도
    `L.source_failed("codex", ..., primary=False)`로 공시만 하고 차단하지 않는다.
    codex_degraded 의 실제 값(true/false)은 기존 스위트가 이미 검증한다."""

    def test_codex_missing_is_recorded_as_auxiliary_source_failure(self):
        _, out, _ = run(CRITIC_CLEAN, omit_codex=True)
        adv = advisories(out)
        self.assertTrue(
            any("입력 실패(보조): codex" in a for a in adv),
            f"codex 부재가 보조(補) source_failed 로 회계되지 않았다: {adv}")

    def test_codex_clean_has_no_source_failed_line(self):
        _, out, _ = run(CRITIC_CLEAN, CODEX_CLEAN)
        adv = advisories(out)
        self.assertFalse(
            any("입력 실패(보조): codex" in a for a in adv),
            f"멀쩡한 codex 가 source_failed 로 오분류됐다: {adv}")


class TestDiscardedCodexMalformedCountIsWired(unittest.TestCase):
    """Task 3 이 `parse_codex_yaml`을 4-tuple 로 바꿨고, 4번째 값(폐기된 codex
    finding 개수)을 Task 6 이 배선해야 한다. 값은 원리적 미상이 아니라 실제
    int(len(findings)) 이므로 — merge_review.py 의 `build_ledger`/`main` 과 같은
    관례로 `hold("codex_finding[i]", ...)`를 개수만큼 남긴다(uncountable 이 아니다)."""

    def test_discarded_codex_finding_count_is_held_not_silently_dropped(self):
        _, out, _ = run(CRITIC_CLEAN, CODEX_MALFORMED_ONE_FINDING)
        adv = advisories(out)
        self.assertTrue(
            any("codex_finding[0]" in a for a in adv),
            f"parse_codex_yaml 이 폐기한 codex finding 개수가 회계되지 않았다: {adv}")


class TestExternalKeysUnchanged(unittest.TestCase):
    """외부 계약(top-level 키 집합)은 «조용히» 자라면 안 된다 — 늘 때마다
    `DECLARED_KEYS` 를 같은 커밋에서 갱신해 그 확장이 리뷰에 보이게 만든다.

    원래(§9.1, correction #3) 8개였을 때는 "새 top-level 키를 추가하지 않는다"
    였다. Task 10 수정 라운드 1 이 처분 회계(`adjudication_*`, 형제
    merge_review.py 와 같은 모양)를 stdout 계약에 정식으로 추가하면서 21개로
    늘었다 — 그 확장이 `DECLARED_KEYS` 리터럴에 그대로 보인다. 이 락이 막는
    것은 «신규 키»가 아니라 «선언 없는 신규 키»다."""

    def test_top_level_keys_are_exactly_the_declared_set(self):
        _, out, _ = run(CRITIC_CLEAN, CODEX_CLEAN)
        self.assertEqual(top_level_keys(out), DECLARED_KEYS)

    def test_verdict_unaffected_by_ledger_accounting_clean_case(self):
        _, out, _ = run(CRITIC_CLEAN, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "approved")
        self.assertEqual(d["codex_degraded"], "false")

    def test_verdict_unaffected_by_ledger_accounting_broken_critic_case(self):
        """critic 이 완전히 깨져도(sentinel 부재) escalates 계산 자체는 Ledger
        도입 전과 동일해야 한다 — needs_revise. (기존 회귀 스위트가 이미 이
        분기의 값을 검증하지만, Ledger 배선이 그 값을 흔들지 않는다는 것까지
        이 파일이 재확인한다.)"""
        _, out, _ = run(CRITIC_NO_SENTINEL, CODEX_CLEAN)
        d = kv(out)
        self.assertEqual(d["fidelity_verdict"], "needs_revise")
        self.assertEqual(d["critic_verdict_unrecoverable"], "false")  # Status 줄은 있다


if __name__ == "__main__":
    unittest.main()
