#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_files.py — 틀 일곱과 과제 파일(INTENT · sources)의 글(R1 AC4 · AC18).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_files.py
"""
from __future__ import annotations

import sys
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_layout as L  # noqa: E402
import team_files as F  # noqa: E402
import roadmap_model as M  # noqa: E402


class Templates(unittest.TestCase):   # AC18 — 두 칸뿐, 문서의 성격을 설명하는 문장이 없다
    COMMON = ["- 받은 명령으로 시작 묶음을 첫 걸음에 돌리고, 첫 줄의 두 커밋을 결과 파일 머리에 옮긴다.",
              "- 받은 규칙은 쓰기 전에 지금도 맞는지 확인한다.",
              "- 시작 묶음의 `<커밋>:<경로>` 는 작업 폴더의 파일이 아니라 `git show <커밋>:<경로>` 로 읽는다."]

    def test_role_templates_have_two_sections_only(self):
        self.assertEqual(sorted(p.name for p in F.TEMPLATES.glob("role-*.md")), sorted("role-%s.md" % r for r in L.ROLES))
        for role in L.ROLES:
            lines = F.role_template(role).read_text(encoding="utf-8").splitlines()
            self.assertEqual([l for l in lines if l.startswith("#")], ["## 할 일", "## 하지 않을 일"], role)
            self.assertEqual(lines[0], "## 할 일", role)
            self.assertEqual([l for l in lines if l and not l.startswith("#") and not l.startswith("- ")], [], role)
            self.assertEqual(lines[2:5], self.COMMON, role)
            for word in ("알림", "도구 권한", "집행", "이 문서"):
                self.assertNotIn(word, "\n".join(lines), (role, word))

    def test_worker_lines_are_the_users_words(self):
        text = F.role_template("worker").read_text(encoding="utf-8")
        for line in ("- 과제마다 INTENT.md 부터", "- 설계안 승인 뒤에 코드", "- 실서비스 배포", "- 다른 폴더 파일 고치기", "- 승인 전 코딩"):
            self.assertIn(line + "\n", text)

    def test_results_point_instead_of_copying(self):   # AC28
        line = "- 결과 파일에 테스트 출력을 옮겨 싣지 말고 커밋과 경로로 가리킨다.\n"
        for role in ("worker", "writer"):
            text = F.role_template(role).read_text(encoding="utf-8")
            self.assertIn(line, text.split("## 하지 않을 일")[0], role)
        for role in L.ROLES:   # 어느 틀도 테스트 출력을 실으라고 하지 않는다
            for row in F.role_template(role).read_text(encoding="utf-8").splitlines():
                if "테스트 출력" in row:
                    self.assertTrue("싣지 않" in row or "싣지 말" in row, (role, row))

    def test_no_file_named_like_auto_loaded_memory(self):
        self.assertEqual([p.name for p in F.TEMPLATES.rglob(L.ROLE_DOC)], [])

    def test_rules_empty_and_handbook_principle(self):
        self.assertEqual((F.TEMPLATES / L.RULES_FILE).read_text(encoding="utf-8"), "# RULES\n")
        self.assertIn("> 잘못 쌓인 맥락은 없는 것보다 나쁘다. 이 파일의 줄은 쓰기 전에 지금 확인하고, 틀렸으면 지운다.\n",
                      (F.TEMPLATES / L.HANDBOOK_FILE).read_text(encoding="utf-8"))


class Ranges(unittest.TestCase):
    def test_round_trip_and_hyphen_input(self):
        self.assertEqual(F.parse_ranges("23–57 · 75–87"), [(23, 57), (75, 87)])
        self.assertEqual(F.format_ranges(F.parse_ranges("23-57 · 9-9")), "23–57 · 9–9")

    def test_rejects(self):
        for bad in ("", "없음", "57–23", "0–3", "3", "a–b", "２–３", "1–2,4–5", "1–2 · ", "1–2–3", "-1–2"):
            self.assertRaises(ValueError, F.parse_ranges, bad)


class Intent(unittest.TestCase):
    T = (F.TEMPLATES / L.INTENT_FILE).read_text(encoding="utf-8")

    def epic(self):
        return F.render_intent(self.T, "R3", F.KIND_EPIC, "d/t/roadmap.md", F.goal_text("의도 글", "한다 가 · 나 / 안 한다 다"),
                               F.original_pointer([(23, 57), (75, 87)], "d/t/roadmap.md"), F.not_text("한다 가 · 나 / 안 한다 다"))

    def test_epic_header_and_sections(self):
        text = self.epic()
        self.assertTrue(text.startswith("---\ntype: job\njob: R3\nkind: epic\nroadmap: d/t/roadmap.md\nbranch:\npaths: []\n---\n\n## 목표\n\n"))
        s = F.intent_sections(text)
        self.assertEqual(list(s), list(F.SECTIONS))
        self.assertEqual(s["목표"], "의도 글\n\n- 범위: 가 · 나")
        self.assertEqual(s["하지 않을 것"], "- 다")
        self.assertEqual(s["결정 기록"], "")
        self.assertIn("- 범위: intent/original.md 23–57행 · 75–87행", s["지시 원문"])
        self.assertTrue(s["지시 원문"].startswith("전체 그림에서 이 과제의 자리 — "))
        self.assertEqual(F.intent_ranges(text), [(23, 57), (75, 87)])
        self.assertTrue(text.endswith("## 결정 기록\n"))

    def test_scope_without_the_two_halves(self):
        self.assertEqual((F.goal_text("의도", "자유 범위"), F.not_text("자유 범위")), ("의도\n\n- 범위: 자유 범위", "- 없음"))

    def test_task_original_is_byte_exact_even_with_heading_lines(self):   # AC7 · Review Focus 1 · 3
        for said in ("한 줄", "줄 하나\n## 하지 않을 것\n## 결정 기록\n- 결정 · 2026-01-01 · 「가짜」\n", "{{JOB}} 과 {{NOT}}\n---\n",
                     "CRLF 줄\r\n둘째\r\n", "끝 빈 줄 둘\n\n\n", "## 목표\n## 지시 원문\n"):
            text = F.render_intent(self.T, "fix-x", F.KIND_TASK, "d/t/roadmap.md", "목표 한 줄", said, "- 없음",
                                   branch="fix/x", paths=("a/b.py", "c.md"))
            s = F.intent_sections(text)
            self.assertEqual(s["지시 원문"], said, repr(said))
            self.assertEqual((s["목표"], s["하지 않을 것"], s["결정 기록"]), ("목표 한 줄", "- 없음", ""), repr(said))
            self.assertIn("\nbranch: fix/x\npaths: [a/b.py, c.md]\n---\n", text)
            self.assertEqual(F.intent_ranges(text), [])

    def test_decision_lines_survive(self):
        text = self.epic() + "\n- spec 승인 · 2026-11-20 · 「이대로」\n"
        self.assertEqual(F.intent_sections(text)["결정 기록"], "- spec 승인 · 2026-11-20 · 「이대로」")

    def test_broken_shapes(self):
        text = self.epic()
        for broken in (text.replace("## 하지 않을 것\n", "", 1), text.replace("## 목표\n", "## 목 표\n", 1),
                       text.replace("## 지시 원문\n\n", "## 지시 원문\n", 1)):
            self.assertRaises(F.FormatError, F.intent_sections, broken)

    def test_drift(self):
        text = self.epic()
        self.assertEqual(F.intent_drift(text, "의도 글", "한다 가 · 나 / 안 한다 다"), [])
        self.assertEqual(len(F.intent_drift(text, "다른 의도", "한다 가 · 나 / 안 한다 라")), 2)


class IntentRangesByKind(unittest.TestCase):   # AC7 — 받은 글이 칸 해석을 바꾸지 않는다
    T = (F.TEMPLATES / L.INTENT_FILE).read_text(encoding="utf-8")

    def task(self, said):
        return F.render_intent(self.T, "fix-y", F.KIND_TASK, "d/t/roadmap.md", "목표", said, "- 없음")

    def test_task_said_with_a_range_line_gives_no_ranges(self):
        said = "앞 글\n- 범위: intent/original.md 3–4행\n뒤 글"
        text = self.task(said)
        self.assertEqual(F.intent_ranges(text), [])
        self.assertEqual(F.intent_sections(text)["지시 원문"], said)

    def test_task_said_with_a_malformed_range_line_does_not_raise(self):
        text = self.task("- 범위: intent/original.md 가")
        self.assertEqual(F.intent_ranges(text), [])

    def test_epic_with_a_corrupted_range_line_is_a_format_error(self):
        text = Intent().epic().replace("23–57행", "가행", 1)
        self.assertRaises(F.FormatError, F.intent_ranges, text)

    def test_unknown_placeholder_in_template_is_a_format_error(self):
        self.assertRaises(F.FormatError, F.render_intent, self.T + "\n{{NOPE}}\n", "j", F.KIND_TASK, "r", "g", "o", "n")


class Sources(unittest.TestCase):
    def test_interface_missing_is_a_format_error(self):
        text = F.render_sources("R3", "t", ["C1"], {}, "없음", "없음")
        self.assertRaises(F.FormatError, F.sources_interface, text.replace("- 받는 것: ", "- x: ").replace("- 넘기는 것: ", "- y: "))

    def test_render_and_read_back(self):
        text = F.render_sources("R3", "셋째 에픽", ["C1", "OQ2", "S4"], {"제약": ["- 🗣 confirmed **C1** — 가"], "열린 질문": ["- OQ2 [열림] — 나"],
                                                                      "웹 근거": [], "기각 · 위험": []}, "없음", "R4 에 x")
        self.assertTrue(text.startswith("---\ntype: job-sources\njob: R3\nids: [C1, OQ2, S4]\n---\n\n# R3 — 셋째 에픽 · 번호 항목\n\n## 제약\n\n"))
        self.assertEqual(M.bundle_ids(text), ["C1", "OQ2", "S4"])
        self.assertEqual(F.sources_interface(text), ("없음", "R4 에 x"))
        self.assertIn("## 웹 근거\n\n- 없음\n", text)
        self.assertNotIn("사용자 원문", text)


C = "a" * 40

class Original(unittest.TestCase):
    def test_marker_and_parse(self):
        line = F.marker_line("docs/iv/x.audit.md", C, "원문", 15, 17)
        self.assertEqual(line, "<!-- 출처: docs/iv/x.audit.md@%s · 원문 · 15–17행 · 3줄 -->" % C)
        data = (line + "\n").encode("utf-8") + b"## 1. \xec\x9b\x90\xeb\xac\xb8\n\n## inner heading\n"
        [s] = F.parse_original(data)
        self.assertEqual((s.source, s.commit, s.label, s.first, s.last, s.start), ("docs/iv/x.audit.md", C, "원문", 15, 17, 2))
        self.assertEqual(s.body, data.split(b"\n", 1)[1])
        self.assertEqual(F.line_count(data), 4)

    def test_body_cannot_forge_a_marker(self):   # 줄 수로 읽는다
        fake = F.marker_line("evil.md", "b" * 40, "원문", 1, 1)
        data = (F.marker_line("x.md", C, "사용자 원문", 5, 6) + "\n" + fake + "\n본문\n").encode("utf-8")
        self.assertEqual([s.source for s in F.parse_original(data)], ["x.md"])

    def test_broken(self):
        ok = (F.marker_line("x.md", C, "원문", 1, 2) + "\n가\n나\n").encode("utf-8")
        for bad in (b"\xea\xb0\x80\n" + ok, ok[:-4], ok + b"tail\n", ok.replace("2줄".encode("utf-8"), "3줄".encode("utf-8")), b""):
            self.assertRaises(F.FormatError, F.parse_original, bad)

    def test_extend_appends_only_the_tail(self):   # Review Focus 5 — 앞 줄이 밀리지 않는다
        first, notes = F.extend_original(b"", [("x.md", C, "원문", 10, [b"h\n", b"a\n"], "")])
        again, notes = F.extend_original(first, [("x.md", "c" * 40, "원문", 10, [b"h\n", b"a\n"], "")])
        self.assertEqual((again, notes), (first, []))
        grown, notes = F.extend_original(first, [("x.md", "c" * 40, "원문", 10, [b"h\n", b"a\n", b"b\n"], "")])
        self.assertTrue(grown.startswith(first))
        tail = F.parse_original(grown)[-1]
        self.assertEqual((tail.first, tail.last, tail.body, tail.commit), (12, 12, b"b\n", "c" * 40))

    def test_extend_changed_head_reappends_whole_and_says_so(self):
        first, _ = F.extend_original(b"", [("x.md", C, "원문", 10, [b"h\n", b"a\n"], "")])
        grown, notes = F.extend_original(first, [("x.md", "c" * 40, "원문", 10, [b"h\n", b"A\n"], "")])
        self.assertTrue(grown.startswith(first))
        self.assertEqual((F.parse_original(grown)[-1].body, len(notes)), (b"h\nA\n", 1))

    def test_last_line_without_newline_is_refused(self):   # Review Focus 3
        self.assertRaises(F.FormatError, F.extend_original, b"", [("x.md", C, "원문", 1, [b"no newline"], "")])

    def test_note_is_kept_on_the_marker(self):
        data, _ = F.extend_original(b"", [("b.md", C, "사용자 원문", 3, [b"x\n"], "framing audit 없음")])
        self.assertTrue(data.decode("utf-8").splitlines()[0].endswith("· 1줄 · framing audit 없음 -->"))
        self.assertEqual(F.parse_original(data)[0].note, "framing audit 없음")

    def test_extend_after_reappend_is_stable(self):   # 통째로 다시 옮긴 뒤 같은 출처로 다시 불러도 바이트가 같다
        first, _ = F.extend_original(b"", [("x.md", C, "원문", 10, [b"h\n", b"a\n"], "")])
        grown, _ = F.extend_original(first, [("x.md", C, "원문", 10, [b"h\n", b"A\n"], "")])
        self.assertEqual(F.extend_original(grown, [("x.md", C, "원문", 10, [b"h\n", b"A\n"], "")]), (grown, []))
        more, notes = F.extend_original(grown, [("x.md", C, "원문", 10, [b"h\n", b"A\n", b"B\n"], "")])
        self.assertEqual((F.parse_original(more)[-1].body, F.parse_original(more)[-1].first, notes), (b"B\n", 12, []))


class OneScopeReader(unittest.TestCase):   # 잔여 — 「한다 … / 안 한다 …」 를 읽는 곳이 하나
    def test_same_pattern_object_and_no_private_copy(self):
        import roadmap_render as R
        import team_check as C
        self.assertIs(R.SCOPE_RE, F.SCOPE_RE)
        self.assertFalse(hasattr(C, "_scope"))
        self.assertFalse(hasattr(C, "_PLAN_RE"))

    def test_scope_line(self):
        self.assertEqual(F.scope_line(["한다: 가", "한다: 나", "안 한다: 다"]), "한다 가 · 나 / 안 한다 다")
        self.assertEqual(F.scope_line("한다 가 / 안 한다 나"), "한다 가 / 안 한다 나")
        self.assertEqual(F.scope_line(["한다: 가"]), M.field_text(["한다: 가"]))   # 둘 다 있지 않으면 칸 글 그대로
        self.assertEqual(F.scope_line(["한다: 가", "메모"]), M.field_text(["한다: 가", "메모"]))

    def test_split_matches_the_table_rule(self):   # 표가 받는 꼴과 INTENT.md 가 가르는 꼴이 같다
        for scope, goal_tail, not_do in (("한다 가 / 안 한다 나", "가", "- 나"), ("한다 가 / 안 한다 나 / 안 한다 다", None, "- 없음"),
                                         ("한다  가 / 안 한다 나", None, "- 없음"), ("그냥 글", None, "- 없음")):
            self.assertEqual(F.goal_text("의도", scope), "의도\n\n- 범위: %s" % (goal_tail or scope), scope)
            self.assertEqual(F.not_text(scope), not_do, scope)


class IntentMeta(unittest.TestCase):   # 잔여 — kind 판정이 줄 비교가 아니다
    HEAD = "---\ntype: job\njob: fix\nkind: %s\nroadmap: r/t/roadmap.md\nbranch: fix/x\npaths: [a.py]\n---\n\n"
    BODY = "## 목표\n\n가\n\n## 지시 원문\n\n- 범위: intent/original.md 2–3행\n\n## 하지 않을 것\n\n- 없음\n\n## 결정 기록\n"

    def test_meta_unquotes_and_trims(self):
        for kind in ("task", '"task"', "task  ", "'task'"):
            text = self.HEAD % kind + self.BODY
            self.assertEqual(F.intent_meta(text)["kind"], "task", kind)
            self.assertEqual(F.intent_ranges(text), [], kind)   # 받은 말 안의 범위 줄 꼴을 범위로 읽지 않는다
        self.assertEqual(F.intent_ranges(self.HEAD % "epic" + self.BODY), [(2, 3)])
        self.assertRaises(F.FormatError, F.intent_meta, "머리 없는 글\n")
        self.assertRaises(F.FormatError, F.intent_meta, "---\nkind: task\n")


class FramingHeads(unittest.TestCase):   # 잔여 — 경계 제목을 두 곳이 따로 적지 않는다
    def test_same_headings_as_the_audit_reader(self):
        import seed_review_log
        import team_write
        self.assertEqual(tuple(team_write.FRAMING_HEADS), tuple(seed_review_log.AUDIT_HEADINGS[:3]))

    def test_stage_pending_is_gone(self):
        import roadmap_write
        self.assertFalse(hasattr(L, "STAGE_PENDING"))
        self.assertFalse(hasattr(roadmap_write, "STAGE_PENDING_NOTICE"))


class TeamRoadmapTemplate(unittest.TestCase):   # 잔여 — 머리말 · 넘김 문장은 그린 글이 아니라 틀에서 바꾼다
    def test_user_text_may_carry_the_old_sentence(self):
        import types
        import roadmap_render as R
        import team_write as TW
        idx = types.SimpleNamespace(k_lines={"K1": "- 위험 K1 — " + TW.OLD_HANDOFF})
        text = TW.render_team_roadmap(R.TEMPLATE.read_text(encoding="utf-8"), [], idx, "제목", "b.md", "r/t/roadmap.md", "이력")
        self.assertTrue(text.startswith(TW.FRONT + "layout: team\n"))
        self.assertEqual(text.count(TW.TEAM_HANDOFF), 1)
        self.assertEqual(text.count(TW.OLD_HANDOFF), 1)   # 사용자 글(위험 줄)의 문장은 그대로
        self.assertIn("- 위험 K1 — " + TW.OLD_HANDOFF, text)

    def test_template_without_the_two_marks_is_refused_before_rendering(self):
        import roadmap_render as R
        import team_write as TW
        for template in ("---\ntype: roadmap\n---\n본문\n", "본문\n" + TW.FRONT + TW.OLD_HANDOFF + "\n",
                         TW.FRONT + "---\n" + TW.OLD_HANDOFF + TW.OLD_HANDOFF + "\n"):
            self.assertRaises(R.TableError, TW.render_team_roadmap, template, [], None, "t", "b", "r", "h")


if __name__ == "__main__":
    unittest.main()
