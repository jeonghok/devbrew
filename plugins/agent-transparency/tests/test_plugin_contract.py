#!/usr/bin/env python3
"""플러그인 계약 테스트 — AC16① · AC25–AC27 · AC32 · AC33 · AC35 · AC39 · AC43 · AC51.

Run:
    python3 -m unittest plugins/agent-transparency/tests/test_plugin_contract.py
"""
from __future__ import annotations

import json
import subprocess
import sys
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]
PLUGIN_DIR = REPO_ROOT / "plugins" / "agent-transparency"


def read(rel: str) -> str:
    return (PLUGIN_DIR / rel).read_text(encoding="utf-8")


class TestManifest(unittest.TestCase):
    """AC26 — plugin.json 에 name · description · version 이 있다."""

    def setUp(self) -> None:
        self.manifest = json.loads(read(".claude-plugin/plugin.json"))

    def test_required_keys_present(self) -> None:
        for key in ("name", "description", "version"):
            self.assertIn(key, self.manifest)
            self.assertTrue(str(self.manifest[key]).strip(), key)

    def test_name_matches_directory(self) -> None:
        self.assertEqual(self.manifest["name"], "agent-transparency")

    def test_version_is_semver(self) -> None:
        parts = str(self.manifest["version"]).split(".")
        self.assertEqual(len(parts), 3)
        for part in parts:
            self.assertTrue(part.isdigit(), self.manifest["version"])

    def test_description_matches_output_style(self) -> None:
        """AC26 — plugin.json 의 description 이 output style frontmatter 와 같은 문구.

        output style 의 description 은 YAML 접힘(두 줄)이라 편다 — 이어지는 줄은
        들여쓰기로만 식별한다(다음 키는 열 0에서 시작한다).
        """
        body = read("output-styles/agent-transparency.md").split("---", 2)[1]
        head, tail = body.split("description:", 1)[1].split("\n", 1)
        folded = [head.strip()]
        for line in tail.splitlines():
            if not line.startswith("  "):
                break
            folded.append(line.strip())
        self.assertEqual(self.manifest["description"], " ".join(folded))


class TestMarketplaceEntry(unittest.TestCase):
    """D12 — marketplace 에 등록되지 않으면 설치가 안 된다."""

    def test_entry_exists_and_points_at_plugin(self) -> None:
        market = json.loads(
            (REPO_ROOT / ".claude-plugin" / "marketplace.json").read_text(encoding="utf-8")
        )
        hits = [p for p in market["plugins"] if p.get("name") == "agent-transparency"]
        self.assertEqual(len(hits), 1)
        self.assertEqual(hits[0]["source"], "./plugins/agent-transparency")


class TestGitignore(unittest.TestCase):
    """§8 — tests/out/ 은 커밋되지 않는다(러너 산출물에 실제 트랜스크립트 사본이 있다)."""

    def test_out_dir_ignored(self) -> None:
        self.assertIn("tests/out/", read(".gitignore"))


SKILL_REL = "skills/briefing-current-state/SKILL.md"


def frontmatter(text: str) -> dict:
    """`key: value` 만 뽑는 최소 파서 — 이 파일들은 중첩 구조를 쓰지 않는다."""
    block = text.split("---", 2)[1]
    out = {}
    for line in block.splitlines():
        if ":" in line and not line.startswith(" "):
            key, value = line.split(":", 1)
            out[key.strip()] = value.strip()
    return out


class TestSkillFrontmatter(unittest.TestCase):
    """AC27 — cost_class **값이 variable** · context: fork · agent · background."""

    def setUp(self) -> None:
        self.meta = frontmatter(read(SKILL_REL))

    def test_cost_class_is_variable(self) -> None:
        """`low` 면 red — 같은 절이 '읽는 양에 상한을 걸지 않는다' 고 명시하므로
        상한 없는 탐색은 정의상 variable 이다."""
        self.assertEqual(self.meta.get("cost_class"), "variable")

    def test_context_is_fork(self) -> None:
        self.assertEqual(self.meta.get("context"), "fork")

    def test_agent_points_at_dedicated_reader(self) -> None:
        """`Explore` 면 red — 훅이 자기 fork 를 구분할 수 없게 된다."""
        self.assertEqual(self.meta.get("agent"), "agent-transparency:transcript-reader")

    def test_background_is_false(self) -> None:
        self.assertEqual(self.meta.get("background"), "false")


class TestSkillTranscriptFacts(unittest.TestCase):
    """AC35①–⑤ — 세 트랜스크립트 사실 · 「읽지 않는 것」 · 표본 하한.

    ⑥(tests/probe/skill_body.txt)은 실물 측정이 필요해 별도 배정이다.
    앞선 판에서 이것들은 추출기 **코드**에 있었다 — 코드가 사라졌으므로
    검사 대상이 지시문으로 옮겨갔다.
    """

    FRAGMENTS = {
        "①-세-레코드-타입": ['type=="user"', 'type=="queue-operation"',
                              'attachment.type=="queued_command"'],
        "②-last-prompt-제외": ['type=="last-prompt"'],
        "③-텍스트-없는-레코드-건너뛰기": ["텍스트 없는 레코드를 건너뛴다"],
        "④-읽지-않는-것": ["`Bash` 명령 문자열", "파일 내용", "`tool_result` 본문",
                            "에이전트 반환값 본문", "subagents/*.jsonl"],
        "⑤-표본-하한": ["가장 최근 블록", "모든 `AskUserQuestion` 호출과 그 짝",
                        "하한이지 상한이 아니다"],
    }

    def setUp(self) -> None:
        self.text = read(SKILL_REL)

    def test_all_fragments_present(self) -> None:
        for name, fragments in self.FRAGMENTS.items():
            for fragment in fragments:
                self.assertIn(fragment, self.text, "%s: %s" % (name, fragment))

    def test_mutation_each_fragment_removal_is_detected(self) -> None:
        """하나를 지우면 red — 항목별로 확인한다."""
        for name, fragments in self.FRAGMENTS.items():
            mutated = self.text.replace(fragments[0], "")
            self.assertNotIn(fragments[0], mutated, name)

    def test_ask_user_question_exception_is_scoped(self) -> None:
        """예외는 AskUserQuestion 하나뿐이고 다른 tool_result 는 계속 배제된다."""
        self.assertIn("다른 어떤 도구의 `tool_result` 도 계속 전부 배제한다", self.text)


class TestQuotePreservation(unittest.TestCase):
    """AC16① — 문구 보존 요구와 `(미답)` 표기가 **둘 다** 있다(mutation).

    ②(실제 산출의 정확성)는 런타임 신호가 게이트 5a 뿐이고 고른 라벨 보존은
    실물로 측정되지 않는다 — OQ-AA.
    """

    def setUp(self) -> None:
        self.text = read(SKILL_REL)

    def test_verbatim_requirement(self) -> None:
        self.assertIn("한 글자도 바꾸지 않는다", self.text)

    def test_unanswered_marker(self) -> None:
        self.assertIn("(미답)", self.text)

    def test_mutation_either_side_removed(self) -> None:
        for fragment in ("한 글자도 바꾸지 않는다", "(미답)"):
            self.assertNotIn(fragment, self.text.replace(fragment, ""))


class TestNoShellInjectionPath(unittest.TestCase):
    """AC43 — 사용자 문자열이 셸에 도달하는 경로가 없다."""

    EXPANSIONS = ("$ARGUMENTS", "${ARGUMENTS", "$1", "$@", "$*", "$USER_INPUT")

    def test_dynamic_context_line_is_a_fixed_string(self) -> None:
        line = [ln for ln in read(SKILL_REL).splitlines() if ln.strip().startswith("!`")]
        self.assertEqual(len(line), 1, "동적 컨텍스트 주입 줄이 정확히 1개여야 한다")
        for token in self.EXPANSIONS:
            self.assertNotIn(token, line[0])

    def test_script_takes_no_user_argument(self) -> None:
        script = (PLUGIN_DIR / "scripts" / "prepare_standup.py").read_text(encoding="utf-8")
        self.assertIn('add_argument("--session-id"', script)
        # 위치 인자를 받으면 사용자 유래 값이 들어올 수 있다.
        self.assertNotIn('add_argument("scope"', script)

    def test_shell_metacharacter_payload_has_no_effect(self) -> None:
        """통합 검사 — 메타문자를 인자로 넣어도 부수효과가 없다."""
        import tempfile as _tf
        with _tf.TemporaryDirectory() as tmp:
            canary = Path(tmp) / "pwn"
            proc = subprocess.run(
                [sys.executable, str(PLUGIN_DIR / "scripts" / "prepare_standup.py"),
                 "--session-id", "; touch %s" % canary],
                cwd=tmp, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            self.assertFalse(canary.exists())
            self.assertIn(proc.returncode, (0, 3, 4))


class TestCommandFile(unittest.TestCase):
    """AC51 (D7 신설) — commands/standup.md 의 본문을 직접 검증한다.

    AC39 는 이름 충돌, AC40 은 러너, AC43 은 SKILL.md 를 보므로 이 glue 파일의
    오타·스킬명 오기·$ARGUMENTS 누락은 어떤 테스트도 안 거쳤다.
    """

    def setUp(self) -> None:
        self.text = read("commands/standup.md")

    def test_frontmatter_has_description(self) -> None:
        self.assertTrue(frontmatter(self.text).get("description"))

    def test_body_invokes_the_skill_by_namespaced_name(self) -> None:
        self.assertIn("Skill agent-transparency:briefing-current-state $ARGUMENTS",
                      self.text)

    def test_skill_name_actually_exists(self) -> None:
        """스킬명 오기를 잡는다 — 이름이 실제 디렉토리와 맞는지."""
        self.assertTrue((PLUGIN_DIR / SKILL_REL).is_file())
        self.assertEqual(frontmatter(read(SKILL_REL)).get("name"),
                         "briefing-current-state")

    def test_arguments_flow_as_prompt_text_only(self) -> None:
        """$ARGUMENTS 가 셸 호출 안에 있으면 red — 프롬프트 텍스트로만 흐른다."""
        for line in self.text.splitlines():
            if "$ARGUMENTS" in line:
                self.assertFalse(line.strip().startswith("!`"), line)
                self.assertNotIn("bash", line.lower())


class TestReferenceIsNormative(unittest.TestCase):
    """AC32 우변 · AC33 — 게이트 표의 판정 방식과 5a·5b 의 판정 대상."""

    def setUp(self) -> None:
        self.text = read("REFERENCE.md")

    def test_gate_table_declares_rubric_for_3_4_5b_6(self) -> None:
        rows = [ln for ln in self.text.splitlines() if ln.startswith("| ")]
        for gate in ("| 3 ", "| 4 ", "| 5b ", "| 6 "):
            row = [ln for ln in rows if ln.startswith(gate)]
            self.assertTrue(row, gate)
            self.assertIn("루브릭", row[0])

    def test_no_count_based_gate_wording_remains(self) -> None:
        """개수 기반 문구가 남아 있으면 red — 굵은 문구 넷을 세는 검사는
        무관한 굵은 문구 넷으로도 통과한다."""
        for banned in ("굵은 라벨 개수", "라벨 4개 이상", "볼드 개수"):
            self.assertNotIn(banned, self.text)

    def test_gate_5a_and_5b_exist(self) -> None:
        """AC33 — 두 행이 있고 판정 구간 표에 `/standup` 행이 있다."""
        self.assertIn("| 5a ", self.text)
        self.assertIn("| 5b ", self.text)
        self.assertIn("/standup", section_of(self.text, "판정 구간 표"))

    def test_standup_verdict_target_is_defined_at_gate_definition(self) -> None:
        """AC33 — 게이트 5a·5b 가 판정하는 것은 준비 스크립트의 stdout 이 아니라
        실제로 실행된 `/standup` 응답이라는 주장은 루브릭 프롬프트 안에만 있으면
        미래 편집자가 장식으로 보고 잘라낼 수 있다 — 게이트가 정의되는 판정
        구간 표 절 안에, 문서 전체 아무 데나가 아니라 **여기에** 있어야 한다.
        """
        span_section = section_of(self.text, "판정 구간 표")
        self.assertIn("5a", span_section)
        self.assertIn("5b", span_section)
        self.assertIn("스크립트", span_section)
        self.assertIn("stdout", span_section)
        self.assertIn("실행", span_section)


def section_of(text: str, heading: str) -> str:
    start = text.index("## " + heading)
    rest = text[start + 3:]
    end = rest.find("\n## ")
    return rest if end < 0 else rest[:end]


class TestSkillBodyProbe(unittest.TestCase):
    """AC35⑥ — SKILL.md 본문이 fork 에 도달하는지의 관측 기록.

    OQ-AE 에는 fail-closed 락이 있는데 이쪽에 없던 비대칭을 리뷰가 적발했다.
    """

    def setUp(self) -> None:
        self.lines = [ln.strip() for ln in
                      read("tests/probe/skill_body.txt").splitlines() if ln.strip()]

    def test_four_line_format(self) -> None:
        self.assertGreaterEqual(len(self.lines), 4)
        self.assertIn("claude", self.lines[1])
        self.assertRegex(self.lines[3], r"\d+\.\d+\.\d+")

    def test_first_line_is_not_body_unreachable(self) -> None:
        """첫 줄이 '본문 미도달' 이면 red — 그러면 규칙을 한 곳에 둔 결정이
        **규칙을 아무 데도 두지 않은 것**이 되고, 인벤토리 전달 경로도 무너진다."""
        self.assertNotIn("본문 미도달", self.lines[0])

    def test_records_both_observations(self) -> None:
        """관측은 두 값이다 — ⓐ 본문 텍스트 도달 ⓑ 주입 결과 도달."""
        self.assertIn("본문", self.lines[0])
        self.assertIn("주입", self.lines[0])


class TestCommandNameProbe(unittest.TestCase):
    """AC39 — 명령 이름이 내장 command 와 겹치지 않는다.

    바이너리 문자열 추출만으로는 **번들 prompt 계열 명령을 못 본다**
    (실측: 존재하는 `/review`·`/pr-comments` 가 그 방식으로 0회로 나왔다).
    그래서 실물 probe 기록이 유일한 검증 수단이다.
    """

    def setUp(self) -> None:
        self.lines = [ln.strip() for ln in
                      read("tests/probe/command_name.txt").splitlines() if ln.strip()]

    def test_four_line_format(self) -> None:
        self.assertGreaterEqual(len(self.lines), 4)

    def test_bare_name_is_unknown_without_the_plugin(self) -> None:
        self.assertIn("Unknown command", self.lines[0])
        self.assertIn("standup", self.lines[0])

    def test_command_file_uses_that_name(self) -> None:
        self.assertTrue((PLUGIN_DIR / "commands" / "standup.md").is_file())


class TestReadme(unittest.TestCase):
    """AC25 — README 맨 앞의 **다섯 항목**.

    OQ-J 가 README 공개를 요구하는데 이 AC 가 그것을 검사하지 않으면 요구가
    문서에만 남는다.
    """

    ITEMS = {
        "force-for-plugin 경고": "끄려면 플러그인 전체를 비활성화",
        "설치 이전 구간": "설치 이전 작업에는 이 플러그인이 만든 설명이 없",
        "OQ-J 잔여 위험": "어떤 비밀 필터도 없",
        "Principles Instantiated": "## Principles Instantiated",
        "Hooks Installed": "## Hooks Installed",
    }

    def setUp(self) -> None:
        self.text = read("README.md")

    def test_all_five_items_present(self) -> None:
        for name, fragment in self.ITEMS.items():
            self.assertIn(fragment, self.text, name)

    def test_warning_is_near_the_top(self) -> None:
        head = "\n".join(self.text.splitlines()[:25])
        self.assertIn("끄려면 플러그인 전체를 비활성화", head)

    def test_mutation_each_item_removal_is_detected(self) -> None:
        for name, fragment in self.ITEMS.items():
            self.assertNotIn(fragment, self.text.replace(fragment, ""), name)

    def test_post_merge_checklist_is_operationalised(self) -> None:
        """D11 — OQ-R 의 '머지 후 수동 확인' 이 수행 가능한 형태여야 한다."""
        self.assertIn("## 머지 후 수동 확인", self.text)
        self.assertIn("- [ ]", self.text.split("## 머지 후 수동 확인", 1)[1])


if __name__ == "__main__":
    unittest.main()
