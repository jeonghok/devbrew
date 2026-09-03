"""test_hook_publish_suppression.py — AC11: post-tool-use.py suppresses the /qg
re-suggestion when the publish sentinel is present. Run: python3 -m unittest."""
from __future__ import annotations
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
HOOK = PLUGIN_ROOT / "hooks" / "post-tool-use.py"
SID = "pubsuppress123"


def run_hook(cwd: str):
    payload = {
        "tool_name": "Bash",
        "session_id": SID,
        "cwd": cwd,
        "tool_input": {"command": "gh pr create --fill"},
        "tool_response": {"stdout": "https://github.com/o/r/pull/42"},
    }
    r = subprocess.run([sys.executable, str(HOOK)], input=json.dumps(payload),
                       capture_output=True, text=True)
    return json.loads(r.stdout or "{}")


class PublishSuppression(unittest.TestCase):
    def test_sentinel_suppresses_suggestion(self):
        with tempfile.TemporaryDirectory() as d:
            sent = Path(d) / ".claude" / "quality-gates" / SID
            sent.mkdir(parents=True)
            (sent / "publish-active.md").write_text("publishing", encoding="utf-8")
            self.assertEqual(run_hook(d), {}, "sentinel must suppress /qg suggestion")

    def test_no_sentinel_still_suggests(self):
        with tempfile.TemporaryDirectory() as d:
            out = run_hook(d)
            self.assertIn("systemMessage", out, "without sentinel the /qg suggestion should fire")


class ChannelSplit(unittest.TestCase):
    """MU1·MU2 — 모델용 지시는 additionalContext, 사람용 사실은 systemMessage."""

    def test_model_instruction_goes_to_additional_context(self):
        with tempfile.TemporaryDirectory() as d:
            out = run_hook(d)
            hso = out.get("hookSpecificOutput", {})
            self.assertEqual(hso.get("hookEventName"), "PostToolUse")
            ac = hso.get("additionalContext", "")
            self.assertIn("setup-qg.sh", ac, "기동 명령이 모델 채널에 없다")
            self.assertIn("quality-gates:quality-pipeline", ac,
                          "skill 호출 지시가 모델 채널에 없다")

    def test_human_fact_stays_in_system_message(self):
        with tempfile.TemporaryDirectory() as d:
            sm = run_hook(d).get("systemMessage", "")
            self.assertIn("https://github.com/o/r/pull/42", sm,
                          "PR 사실이 사람 채널에 없다")

    def test_system_message_is_not_an_instruction_dump(self):
        """MU1 의 역방향: 기동 지시가 systemMessage 로 되돌아가면 RED."""
        with tempfile.TemporaryDirectory() as d:
            sm = run_hook(d).get("systemMessage", "")
            self.assertNotIn("setup-qg.sh", sm,
                             "기동 명령이 사람 채널에 남아 있다 — 채널이 갈리지 않았다")


if __name__ == "__main__":
    unittest.main()
