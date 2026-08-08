"""codex_audit_to_json.py — 층④. 형제 추출기들의 기성 규약을 따른다.

기성 규약(qg/sd `codex_findings_to_yaml.py`에서):
  - 마지막 agent_message 채택
  - **마지막** fenced block 채택 (중간 메시지에 주입된 앞선 블록을 이긴다)
  - degrade 시 meta.codex_failed + meta.reason
  - 스키마 검증은 성공 마커를 찍기 **전에** 한다 (indeterminate ≠ clean)
"""
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / "scripts" / "codex_audit_to_json.py"
KEYS = ("findings", "d_verdicts", "oq_answers", "new_open_questions")


def run(stdin_text, *args):
    p = subprocess.run([sys.executable, str(SCRIPT), *args],
                       input=stdin_text, capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


def event(text):
    return json.dumps({"type": "item.completed",
                       "item": {"type": "agent_message", "text": text}}) + "\n"


def fenced(payload):
    return "```json\n" + json.dumps(payload) + "\n```"


class TestCodexAuditToJson(unittest.TestCase):
    def test_happy_path_emits_four_collections(self):
        payload = {"findings": [{"id": "CX-1", "title": "t", "axis": 3}],
                   "d_verdicts": [{"id": "D1", "verdict": "confirmed"}],
                   "oq_answers": [{"id": "OQ1", "answer": "a"}],
                   "new_open_questions": [{"id": "NOQ1", "why_not_gap": "x"}]}
        rc, out, _ = run(event(fenced(payload)))
        self.assertEqual(rc, 0)
        d = json.loads(out)
        for k in KEYS:
            self.assertIn(k, d, f"{k} 키가 없다")
        self.assertEqual(d["findings"][0]["id"], "CX-1")
        self.assertIs(d["meta"]["codex_failed"], False,
                      "정상 실행은 양성 성공 표식을 가져야 한다")

    def test_missing_collections_default_to_empty_lists(self):
        _, out, _ = run(event(fenced({"findings": []})))
        d = json.loads(out)
        for k in KEYS:
            self.assertEqual(d[k], [], f"{k}가 빈 리스트로 기본값을 가져야 한다")
        self.assertIs(d["meta"]["codex_failed"], False)

    def test_last_fenced_block_wins(self):
        """주입 방어: 감사 대상 파일이 앞선 fence를 심어도 마지막이 이긴다."""
        text = ("무시할 앞선 블록:\n" + fenced({"findings": [{"id": "EVIL"}]})
                + "\n진짜 답:\n" + fenced({"findings": [{"id": "CX-9"}]}))
        d = json.loads(run(event(text))[1])
        self.assertEqual(d["findings"][0]["id"], "CX-9")

    def test_last_agent_message_wins(self):
        stream = event(fenced({"findings": [{"id": "OLD"}]})) + \
                 event(fenced({"findings": [{"id": "NEW"}]}))
        d = json.loads(run(stream)[1])
        self.assertEqual(d["findings"][0]["id"], "NEW")

    def test_non_list_collection_is_schema_mismatch_not_success(self):
        """indeterminate ≠ clean. 컨테이너 타입 위반은 성공으로 기록되면 안 된다.

        이것이 qg 사본이 2026-05-14 이후 틀린 답을 내던 바로 그 경로다
        (`{"findings": {}}` → codex_failed: false)."""
        d = json.loads(run(event(fenced({"findings": {}})))[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertEqual(d["meta"]["reason"], "schema_mismatch")
        self.assertEqual(d["meta"]["raw_findings_type"], "dict")

    def test_non_dict_elements_are_dropped_and_reported(self):
        d = json.loads(run(event(fenced({"findings": [1, {"id": "CX-1"}, "x"]})))[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertEqual(d["meta"]["reason"], "schema_mismatch")
        self.assertEqual(d["meta"]["bad_element_types"], "int,str")
        self.assertEqual([f["id"] for f in d["findings"]], ["CX-1"],
                         "유효한 형제는 보존한다")

    def test_bad_schema_in_any_collection_is_caught(self):
        d = json.loads(run(event(fenced({"findings": [], "d_verdicts": {}})))[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertIn("d_verdicts", d["meta"]["reason"] + str(d["meta"]))

    def test_empty_stream_is_missing_result(self):
        d = json.loads(run("")[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertEqual(d["meta"]["reason"], "missing_result")

    def test_unparseable_stream_is_malformed_json(self):
        d = json.loads(run("not json at all\n")[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertEqual(d["meta"]["reason"], "malformed_json")

    def test_exit_code_override_forces_failure(self):
        """§4.1 규칙 1 — exit ≠ 0이면 결과를 신뢰하지 않는다."""
        d = json.loads(run(event(fenced({"findings": []})),
                           "--meta-override-exit-code", "1",
                           "--meta-override-reason", "exit_nonzero")[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertEqual(d["meta"]["reason"], "exit_nonzero")
        self.assertEqual(d["meta"]["exit_code"], 1)

    def test_auth_error_in_stderr(self):
        with tempfile.NamedTemporaryFile("w", suffix=".err", delete=False,
                                         encoding="utf-8") as fh:
            fh.write("Error: 401 Unauthorized — please run `codex login`\n")
            errp = fh.name
        d = json.loads(run("", "--stderr-file", errp)[1])
        self.assertIs(d["meta"]["codex_failed"], True)
        self.assertEqual(d["meta"]["reason"], "auth_error_in_stderr")

    def test_always_exit_zero(self):
        """추출기가 비-0을 내면 러너의 `|| [ ! -s ]` 가드가 이중 발화한다."""
        for stdin_text in ("", "garbage", event("no fence here")):
            self.assertEqual(run(stdin_text)[0], 0)


if __name__ == "__main__":
    unittest.main()
