#!/usr/bin/env python3
"""SubagentStop 훅 — AC6 · AC7 · AC8 · AC9 · AC36 · AC37 · AC44 · AC48③ · AC50.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_subagent_hook.py
"""
from __future__ import annotations

import hashlib
import importlib.util
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"
HOOK = PLUGIN_DIR / "hooks" / "subagent-explain.py"


def check_four_elements(text: str) -> list[str]:
    """AC44 — 네 요소 (who ran / what they found / where the evidence is / how it changed your judgment)."""
    bad = []
    elements = [
        ("who ran", "agent 실행자 언급 없음"),
        ("what they found", "발견 내용 언급 없음"),
        ("where the evidence is", "증거 위치 언급 없음"),
        ("how it changed your judgment", "판정 변화 언급 없음"),
    ]
    for phrase, problem in elements:
        if phrase not in text:
            bad.append(problem)
    return bad


def load_hook():
    """하이픈이 든 파일명이라 일반 import 가 안 된다 — 경로로 로드한다."""
    spec = importlib.util.spec_from_file_location("subagent_explain", HOOK)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def run_hook(payload, env=None, cwd=None):
    """(rc, stdout, stderr) — 실제 프로세스로 돌린다."""
    merged = dict(os.environ)
    merged.pop("DEVBREW_DISABLE_AGENT_TRANSPARENCY", None)
    merged.pop("DEVBREW_SKIP_HOOKS", None)
    merged["PYTHONDONTWRITEBYTECODE"] = "1"  # Prevent stdlib bytecode caching in temp $HOME
    merged.update(env or {})
    proc = subprocess.run(
        [sys.executable, str(HOOK)],
        input=payload if isinstance(payload, bytes) else json.dumps(payload).encode("utf-8"),
        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env=merged, cwd=cwd,
    )
    return (proc.returncode,
            proc.stdout.decode("utf-8"),
            proc.stderr.decode("utf-8"))


class TestKillSwitch(unittest.TestCase):
    """AC6 — kill switch 2종. set 이면 stdout 비고 exit 0."""

    def test_global_kill_switch(self) -> None:
        rc, out, _ = run_hook({"agent_type": "Explore"},
                              env={"DEVBREW_DISABLE_AGENT_TRANSPARENCY": "1"})
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_per_hook_kill_switch(self) -> None:
        rc, out, _ = run_hook(
            {"agent_type": "Explore"},
            env={"DEVBREW_SKIP_HOOKS": "other:hook,agent-transparency:subagent-explain"})
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_kill_switch_off_produces_output(self) -> None:
        """양방향 — 끄지 않으면 나온다."""
        rc, out, _ = run_hook({"agent_type": "Explore"})
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())


class TestConstantBranches(unittest.TestCase):
    """AC7 · AC9 · AC36 · AC37 · AC44 — 상수 A·B 갈래."""

    def test_valid_json_with_additional_context(self) -> None:
        """AC7 — 상수 A·B 갈래에서 유효한 additionalContext JSON."""
        rc, out, _ = run_hook({"agent_type": "Explore"})
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertEqual(data["hookSpecificOutput"]["hookEventName"], "SubagentStop")
        self.assertTrue(data["hookSpecificOutput"]["additionalContext"].strip())

    def test_no_decision_key_ever(self) -> None:
        """AC9 — 어떤 경우에도 decision 키가 없다(불변식)."""
        for payload in ({"agent_type": "Explore"},
                        {"agent_type": "workflow-subagent"},
                        {}, b"not json at all"):
            rc, out, _ = run_hook(payload)
            self.assertEqual(rc, 0)
            if out.strip():
                self.assertNotIn("decision", json.loads(out))

    def test_agent_type_appears_verbatim(self) -> None:
        """AC36 — agent_type 값이 additionalContext 에 그대로."""
        rc, out, _ = run_hook({"agent_type": "code-reviewer"})
        self.assertEqual(rc, 0)
        self.assertIn("code-reviewer",
                      json.loads(out)["hookSpecificOutput"]["additionalContext"])

    def test_missing_key_falls_back(self) -> None:
        """AC36 — 키 없음 → '에이전트' 로 대체하고 **정상 출력**."""
        rc, out, _ = run_hook({})
        self.assertEqual(rc, 0)
        self.assertIn("에이전트",
                      json.loads(out)["hookSpecificOutput"]["additionalContext"])

    def test_broken_stdin_falls_back(self) -> None:
        """AC36 — 파싱 불가 → 같은 대체 + 정상 출력(예외 경로가 아니다)."""
        rc, out, _ = run_hook(b"{{{ not json")
        self.assertEqual(rc, 0)
        data = json.loads(out)
        self.assertIn("에이전트", data["hookSpecificOutput"]["additionalContext"])
        self.assertIn("additionalContext", data["hookSpecificOutput"])

    def test_grouping_sentence_both_directions(self) -> None:
        """AC37 — workflow-subagent 면 나오고, 그 외면 안 나온다(양방향)."""
        module = load_hook()
        on = module.build_output("workflow-subagent")
        off = module.build_output("Explore")
        self.assertIn(module.GROUPING_SENTENCE.strip(),
                      on["hookSpecificOutput"]["additionalContext"])
        self.assertNotIn(module.GROUPING_SENTENCE.strip(),
                         off["hookSpecificOutput"]["additionalContext"])

    def test_four_elements_present(self) -> None:
        """AC44 — 훅 상수가 네 요소를 모두 담는다."""
        module = load_hook()
        self.assertEqual(check_four_elements(module.BASE_CONTEXT), [])

    def test_four_elements_deletion_mutation(self) -> None:
        """AC44 mutation — 요소를 지우면 검사기가 적발한다."""
        module = load_hook()
        mutated = module.BASE_CONTEXT.replace(" / how it changed your judgment", "")
        self.assertNotEqual(check_four_elements(mutated), [])

    def test_four_elements_renaming_mutation(self) -> None:
        """AC44 mutation — 요소를 다른 표기로 바꾸면 검사기가 적발한다."""
        module = load_hook()
        mutated = module.BASE_CONTEXT.replace(
            "how it changed your judgment", "how it affected things")
        self.assertNotEqual(check_four_elements(mutated), [])


class TestSelfForkBranch(unittest.TestCase):
    """AC48③ — 전용 agent 의 fork 는 무출력, Explore 는 상수 A(양방향)."""

    def test_own_fork_is_silent(self) -> None:
        rc, out, _ = run_hook({"agent_type": "agent-transparency:transcript-reader"})
        self.assertEqual(rc, 0)
        self.assertEqual(out, "")

    def test_other_agent_is_not_silent(self) -> None:
        rc, out, _ = run_hook({"agent_type": "Explore"})
        self.assertEqual(rc, 0)
        self.assertTrue(out.strip())


class TestNoWrites(unittest.TestCase):
    """AC8 — 임시 HOME 과 임시 cwd 두 트리에 아무것도 쓰지 않는다.

    못 잡는 것: 절대경로·두 트리 밖 디렉토리 쓰기 · 생성 후 삭제된 임시 파일.
    """

    @staticmethod
    def tree_hash(root: Path) -> str:
        digest = hashlib.sha256()
        for path in sorted(root.rglob("*")):
            digest.update(str(path.relative_to(root)).encode("utf-8"))
            if path.is_file():
                digest.update(path.read_bytes())
        return digest.hexdigest()

    def test_two_trees_unchanged(self) -> None:
        with tempfile.TemporaryDirectory() as home, tempfile.TemporaryDirectory() as work:
            (Path(work) / "seed.txt").write_text("seed", encoding="utf-8")
            before = (self.tree_hash(Path(home)), self.tree_hash(Path(work)))
            run_hook({"agent_type": "Explore"}, env={"HOME": home}, cwd=work)
            after = (self.tree_hash(Path(home)), self.tree_hash(Path(work)))
            self.assertEqual(before, after)


class TestExceptionPath(unittest.TestCase):
    """AC50 — 예외면 systemMessage 만 담긴 JSON + exit 0 + stderr 사유.

    자극은 **직렬화 단계**다. 손상된 stdin 은 이 경로가 아니라 AC36 의
    '에이전트 로 대체하고 정상 출력' 경로다 — 두 자극을 섞으면 같은 입력에
    두 AC 가 상반된 출력을 요구하게 된다.
    """

    def test_serialization_failure(self) -> None:
        module = load_hook()
        written = []
        with mock.patch.object(module.json, "dumps", side_effect=RuntimeError("boom")), \
             mock.patch.object(module.sys.stdout, "write", side_effect=written.append), \
             mock.patch.object(module.sys.stderr, "write", side_effect=lambda s: None), \
             mock.patch.object(module.sys.stdin, "read", return_value='{"agent_type":"Explore"}'):
            rc = module.main()
        self.assertEqual(rc, 0)
        payload = json.loads("".join(written))
        self.assertIn("systemMessage", payload)
        self.assertNotIn("hookSpecificOutput", payload)
        self.assertNotIn("additionalContext", json.dumps(payload))

    def test_stderr_carries_reason(self) -> None:
        module = load_hook()
        errs = []
        with mock.patch.object(module.json, "dumps", side_effect=RuntimeError("boom")), \
             mock.patch.object(module.sys.stdout, "write", side_effect=lambda s: None), \
             mock.patch.object(module.sys.stderr, "write", side_effect=errs.append), \
             mock.patch.object(module.sys.stdin, "read", return_value="{}"):
            rc = module.main()
        self.assertEqual(rc, 0)
        self.assertIn("boom", "".join(errs))


class TestHooksJson(unittest.TestCase):
    def test_single_subagent_stop_entry_without_matcher(self) -> None:
        """SubagentStop 은 도구 매처를 받지 않으므로 matcher 키가 없다."""
        cfg = json.loads((PLUGIN_DIR / "hooks" / "hooks.json").read_text(encoding="utf-8"))
        entries = cfg["hooks"]["SubagentStop"]
        self.assertEqual(len(entries), 1)
        self.assertNotIn("matcher", entries[0])
        self.assertIn("subagent-explain.py", entries[0]["hooks"][0]["command"])


class TestDedicatedAgent(unittest.TestCase):
    """AC48①② — 전용 agent 존재 + fail-closed tools allowlist.

    ②는 **곱**이다: (a) `tools:` 가 키로 존재하고 비어 있지 않으며
    (b) 그 집합이 {Read, Glob, Grep} 의 **부분집합**이다. (a) 가 load-bearing —
    부분집합만 요구하면 키가 없거나 빈 값일 때 공집합이라 공허하게 참이 되는데,
    플랫폼 의미는 정반대(미선언 = 전 도구 허용)다.

    **부재 열거가 아니라 지배관계로 판정한다.** 금지 도구를 열거하는 검사는
    내일 추가될 쓰기 도구를 오늘 담을 수 없어 시간축으로 fail-open 이고,
    그것이 devbrew 가 `disallowedTools` 단독을 기각한 바로 그 근거다.
    """

    ALLOWED = {"Read", "Glob", "Grep"}
    AGENT = PLUGIN_DIR / "agents" / "transcript-reader.md"

    @staticmethod
    def tools_of(text: str):
        """선언된 tools 집합. 키가 없으면 None(= 미선언)."""
        body = text.split("---", 2)[1]
        for line in body.splitlines():
            if line.startswith("tools:"):
                raw = line.split(":", 1)[1].strip()
                return {t.strip() for t in raw.split(",") if t.strip()}
        return None

    def setUp(self) -> None:
        self.text = self.AGENT.read_text(encoding="utf-8")

    def test_agent_file_exists_with_name(self) -> None:
        self.assertTrue(self.AGENT.is_file())
        self.assertIn("name: transcript-reader", self.text)

    def test_tools_key_exists_and_is_non_empty(self) -> None:
        tools = self.tools_of(self.text)
        self.assertIsNotNone(tools, "tools: 키 자체가 없다 — 플랫폼 의미는 전 도구 허용")
        self.assertTrue(tools, "tools: 가 비어 있다 — 공집합은 공허하게 부분집합이다")

    def test_tools_are_dominated_by_allowlist(self) -> None:
        self.assertTrue(self.tools_of(self.text) <= self.ALLOWED)

    def test_glob_is_a_required_member(self) -> None:
        """OQ-AD 의 잔여위험 논증이 Glob 보유를 전제한다."""
        self.assertIn("Glob", self.tools_of(self.text))

    def test_disallowed_tools_alone_is_red(self) -> None:
        self.assertNotIn("disallowedTools", self.text)

    def test_mutation_tools_line_removed(self) -> None:
        """`tools:` 줄 삭제 mutation 에서 red."""
        mutated = "\n".join(ln for ln in self.text.splitlines()
                            if not ln.startswith("tools:"))
        self.assertIsNone(self.tools_of(mutated))

    def test_mutation_tools_line_emptied(self) -> None:
        mutated = self.text.replace("tools: Read, Glob, Grep", "tools:")
        self.assertEqual(self.tools_of(mutated), set())

    def test_mutation_write_tool_added(self) -> None:
        """추가 축 — 쓰기 도구가 들어오면 지배관계가 깨진다."""
        mutated = self.text.replace("tools: Read, Glob, Grep",
                                    "tools: Read, Glob, Grep, Write")
        self.assertFalse(self.tools_of(mutated) <= self.ALLOWED)


class TestAgentTypeProbe(unittest.TestCase):
    """AC48④ — probe 파일이 계약 형식대로 있고 첫 줄이 **훅 상수**와 일치한다.

    비교 대상은 agent frontmatter 의 `name:`(bare `transcript-reader`)이 아니다 —
    둘의 표기가 다르므로 술어를 여기서 못박는다.

    **왜 필요한가**: `agent_type` 은 문서화되지 않은 플랫폼 동작이라 드리프트할
    수 있다. ①②③만 있으면 합성 문자열 검사라 플랫폼이 라벨을 바꿔도 green 인
    채로 §6.2 의 자기모순이 되살아난다. ④가 그 드리프트를 red 로 바꾸는
    유일한 지점이다.
    """

    PROBE = PLUGIN_DIR / "tests" / "probe" / "agent_type.txt"

    def setUp(self) -> None:
        self.lines = [ln.strip() for ln in
                      self.PROBE.read_text(encoding="utf-8").splitlines() if ln.strip()]

    def test_four_lines(self) -> None:
        """뒤 세 줄이 없으면 red — 관측값만 있으면 재현할 수 없다."""
        self.assertGreaterEqual(len(self.lines), 4)

    def test_first_line_matches_hook_constant(self) -> None:
        self.assertEqual(self.lines[0], load_hook().SELF_AGENT_TYPE)

    def test_records_probe_command_and_raw_output_and_version(self) -> None:
        self.assertIn("claude", self.lines[1])
        self.assertTrue(self.lines[2])
        self.assertRegex(self.lines[3], r"\d+\.\d+\.\d+")


if __name__ == "__main__":
    unittest.main()
