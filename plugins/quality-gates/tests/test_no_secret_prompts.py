"""Regression test for AC12 (P21 Secret 미노출).

Scans SKILL.md and other persona/agent files for AskUserQuestion-like prompts
that could solicit secret values. The contract: every user-facing option label
must be a *decision* (yes/no, retry/skip/abort) or *path*, never a free-form
input for a secret.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Files where AskUserQuestion options are defined or instructed.
#
# Task 31 fix round 5 (F1 계열): 이 스캔은 **절대부재** 검사다 — SKILL.md 전량에
# secret 유도 프롬프트가 없음을 잰다. `## Runtime gate` 절차가
# skills/quality-pipeline/references/runtime-gate.md 로 분리된 뒤, 이 P21 가드가
# 실제로 보는 범위는 2,079줄 중 906줄로 줄었다. 하필 Runtime 게이트가 실제
# 서비스를 부팅하는 절차라 `.env` · DB_URL · API 키를 사용자에게 물어보라는
# 지시가 새로 들어갈 **가장 그럴듯한 자리**가 검사 밖으로 나가 있었다.
# 그래서 references/*.md 를 **열거가 아니라 도출**해 코퍼스에 넣는다 — 새 참조
# 파일이 생겨도 자동으로 대상이 된다.
_REFERENCE_DOCS = sorted(ROOT.glob("skills/*/references/*.md"))

TARGETS = [
    ROOT / "skills/quality-pipeline/SKILL.md",
    ROOT / "agents/runtime-verifier.md",
] + _REFERENCE_DOCS

# Patterns that suggest secret-value extraction.
# These are heuristics: a free-text "input X" near a secret-like keyword is
# the smell we're guarding against. We accept these in option DESCRIPTIONS
# (e.g., "user has set DB_URL in .env") but flag any imperative
# "ask the user for <SECRET>" or "input the API_KEY" pattern.
SECRET_KEYWORDS = r"(API[_-]?KEY|TOKEN|PASSWORD|SECRET|CREDENTIAL|PRIVATE[_-]?KEY|DB[_-]?URL|DATABASE[_-]?URL|CONNECTION[_-]?STRING)"
LEAK_PATTERN = re.compile(
    rf"(ask|prompt|input|enter|provide|paste|type)\b[^\.\n]{{0,80}}\b{SECRET_KEYWORDS}\b",
    re.IGNORECASE,
)
# Whitelist: explicit text saying we DO NOT ask for secrets is fine.
NEGATION_HINT = re.compile(
    r"(never|don't|do not|cannot|must not)\b[^\.\n]{0,30}\b(ask|prompt|input)",
    re.IGNORECASE,
)


class TestNoSecretPrompts(unittest.TestCase):
    def test_no_imperative_secret_extraction(self):
        # vacuity: 글롭이 아무것도 못 맞추면 이 스캔은 분할 이전 범위로 조용히
        # 되돌아가면서도 GREEN 을 찍는다 — '0건 검사'를 '문제 없음'으로 읽지 않는다.
        self.assertGreater(
            len(_REFERENCE_DOCS), 0,
            "skills/*/references/*.md 를 0건 도출했다 — secret 스캔 코퍼스가 "
            "조용히 좁아졌다 (글롭이 깨졌거나 참조 파일이 전부 사라졌다)")
        offenders = []
        for path in TARGETS:
            if not path.exists():
                continue
            text = path.read_text(encoding="utf-8")
            for match in LEAK_PATTERN.finditer(text):
                start = max(0, match.start() - 100)
                ctx = text[start:match.end() + 50]
                if NEGATION_HINT.search(ctx):
                    continue  # Negated mention is fine
                offenders.append(f"{path.name}:{text[:match.start()].count(chr(10)) + 1}: "
                                 f"...{ctx[-150:]}...")
        self.assertEqual(offenders, [],
                         "Found prompts that may solicit secret values:\n"
                         + "\n".join(offenders))

    def test_runtime_verifier_disallows_secret_request(self):
        """runtime-verifier.md must explicitly state it does not request secret values."""
        path = ROOT / "agents/runtime-verifier.md"
        text = path.read_text(encoding="utf-8")
        # Must contain explicit guard text.
        self.assertRegex(
            text,
            r"(do not request secret|never request secret|cannot request secret|"
            r"never ask.*secret|do not ask.*secret)",
            "runtime-verifier.md must explicitly forbid secret-value requests",
        )

if __name__ == "__main__":
    unittest.main()
