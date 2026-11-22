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
    COMMON = ["- 받은 명령으로 시작 묶음을 첫 걸음에 돌리고, 묶음이 낸 맞추는 명령을 그대로 돌려 첫 줄의 두 커밋과 규칙을 읽은 커밋을 결과 파일 머리에 옮긴다.",
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

    BUNDLE_FAILED = "- 시작 묶음 명령이 0 이 아닌 종료 코드로 끝나면 일하지 않고 그 사유를 돌려보낸다."
    DESIGN_STEP = ("- 설계 걸음에서는 원자료(`intent/original.md`) 전체를 읽고 설계문서의 원문 대조 표부터 채운다.",
                   "- 원자료와 다르게 바꾼 것은 근거를 적거나 「작성자 제안」으로 표시한다.")
    PLAN_STEP = "- 계획 걸음에서는 승인된 설계로 계획을 쓰고, 설계에 없던 결정은 표시해 리더에게 돌려보낸다."

    def test_fourth_common_line_is_what_to_do_when_the_bundle_fails(self):   # R2 §5 · K14
        for role in L.ROLES:
            self.assertEqual(F.role_template(role).read_text(encoding="utf-8").splitlines()[5], self.BUNDLE_FAILED, role)

    def test_design_step_is_leaders_and_plan_step_is_workers(self):   # R2 AC15
        todo = {r: F.role_template(r).read_text(encoding="utf-8").split("## 하지 않을 일")[0] for r in L.ROLES}
        for line in self.DESIGN_STEP:
            self.assertIn(line + "\n", todo["leader"])
            for other in ("designer", "writer", "worker"):
                self.assertNotIn(line, todo[other], other)
        self.assertIn(self.PLAN_STEP + "\n", todo["worker"])
        for other in ("leader", "designer", "writer"):
            self.assertNotIn("계획 걸음", todo[other], other)
        self.assertNotIn("원자료", F.role_template("designer").read_text(encoding="utf-8"))

    WORKER_AC = "- 구현을 끝낼 때 수용 기준마다 `AC<번호>: 구현됨 | 미룸 | 빠짐 — 근거` 줄을 결과 파일에 쓴다."
    WORKER_PROSE = "- 본 테스트 실패 이름과 쓴 미리 받은 답은 결과 파일에 기계가 읽지 않는 글로 적는다."

    def test_worker_writes_ac_lines_and_prose(self):
        for role in L.ROLES:
            todo = F.role_template(role).read_text(encoding="utf-8").split("## 하지 않을 일")[0]
            for line in (self.WORKER_AC, self.WORKER_PROSE):
                if role == "worker":
                    self.assertIn(line + "\n", todo, role)
                else:
                    self.assertNotIn(line, todo, role)

    def test_format_doc_and_readme_quote_the_new_first_line(self):
        doc = (REPO / "plugins/spec-distill/references/team-files.md").read_text(encoding="utf-8")
        readme = (REPO / "plugins/spec-distill/README.md").read_text(encoding="utf-8")
        self.assertIn("첫 줄의 두 커밋과 규칙을 읽은 커밋", doc)
        self.assertNotIn("첫 줄의 두 커밋을 결과 파일 머리에 옮긴다", doc)
        self.assertIn("첫 줄의 두 커밋과 규칙을 읽은 커밋", readme)
        self.assertNotIn("첫 줄의 두 커밋을 일꾼이 결과 파일 머리에 옮깁니다", readme)
        line = [l for l in doc.splitlines() if "다른 세션이나 프로그램이 리더의 터미널에 키를 넣어 질문 창에 답하는 것" in l]
        self.assertEqual(len(line), 1)
        for word in ("`hc keys`", "억지로 보내기", "2026-11-22"):
            self.assertIn(word, line[0], word)

    def test_repo_copies_are_the_templates(self):   # 이 레포의 사본 — AC15 「틀과 이 레포의 사본에서」
        for role in L.ROLES:
            self.assertEqual((REPO / "docs/superpowers/roadmaps" / role / "CLAUDE.md").read_bytes(),
                             F.role_template(role).read_bytes(), role)

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

    def test_leader_template_has_the_rules_check_line_only(self):   # U10 가 — 리더 틀의 할 일 끝 한 줄
        line = "- 규칙을 고친 뒤 규칙 검사(team_rules.py check)를 돌린다."
        self.assertEqual(F.role_template("leader").read_text(encoding="utf-8").split("## 하지 않을 일")[0].splitlines()[-2], line)
        for role in ("designer", "writer", "worker"):
            self.assertNotIn(line, F.role_template(role).read_text(encoding="utf-8"), role)

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


class RoadmapRel(unittest.TestCase):   # I11 — INTENT.md 머리 roadmap 은 레포 상대 경로다
    def test_relative_path_is_returned(self):
        self.assertEqual(F.roadmap_rel({"roadmap": "docs/x/tm/roadmap.md"}), "docs/x/tm/roadmap.md")
        self.assertEqual(F.roadmap_rel({"roadmap": "docs/a..b/roadmap.md"}), "docs/a..b/roadmap.md")   # 조각이 `..` 인 것만 막는다

    def test_everything_else_is_a_format_error(self):
        for meta in ({}, {"roadmap": ""}, {"roadmap": "/abs/roadmap.md"}, {"roadmap": "../out/roadmap.md"},
                     {"roadmap": "docs/../../out.md"}, {"roadmap": "docs\\x\\roadmap.md"}):
            with self.assertRaises(M.FormatError, msg=str(meta)):
                F.roadmap_rel(meta)
        with self.assertRaises(M.FormatError) as cm:
            F.roadmap_rel({"roadmap": "../out/roadmap.md"})
        self.assertIn("머리 roadmap 이 레포 상대 경로가 아니다: ../out/roadmap.md", str(cm.exception))


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


class _ShutGit:   # rev-parse 가 실패하는 git — 아무것도 읽지 못한다
    failures = []

    def run(self, *args):
        return 128, ""

    def run_err(self, *args):
        return 128, "", ""

    def fail(self, sub, rc, err):
        pass

    def blob(self, rev, path):
        return None

    def absent(self, rev, path):
        return False


class BranchesWithoutFixture(unittest.TestCase):   # 분기 × 픽스처 대조가 찾은, 단언이 닿지 않던 갈래
    def test_shallow_question_unanswered_is_not_deep(self):   # team_status.Reader.shallow — 얕은지 묻지 못함
        import team_status as TS
        asked = []

        class Counted(_ShutGit):
            def run_err(self, *args):
                asked.append(args)
                return super().run_err(*args)

        reader = TS.Reader(Counted(), "0" * 40, L.Team("docs/r/", "t"), lambda p: None)
        self.assertEqual(reader.shallow(), "얕은 클론인지 읽지 못했다")
        self.assertEqual(reader.shallow(), "얕은 클론인지 읽지 못했다")   # 한 번만 묻고 같은 답
        self.assertEqual(asked, [("rev-parse", "--is-shallow-repository")])

    def test_ancestor_git_error_is_uncountable(self):   # job_results._ancestor — rc 0 · 1 밖은 「조상 아님」 이 아니라 셀 수 없음
        import job_results as JR
        import roadmap_status as rs
        import types

        class Rc(rs.Git):
            def __init__(self, rc):
                super().__init__(".")
                self.rc = rc

            def run_err(self, *args, env=None):
                return self.rc, "", "fatal: 조상 검사 막힘\n" if self.rc > 1 else ""

            def commit(self, ref):
                return ref

        for rc, want in ((0, True), (1, False)):
            git = Rc(rc)
            self.assertEqual((JR._ancestor(git, "a" * 40, "b" * 40), git.failures), (want, []), rc)
        git = Rc(128)
        self.assertEqual((JR._ancestor(git, "a" * 40, "b" * 40), git.failures),
                         (None, ["git merge-base 실패(rc 128): fatal: 조상 검사 막힘"]))
        r = types.SimpleNamespace(head="a" * 40, bundle_at=None, job_at=None)
        self.assertEqual(JR._commit_problems(Rc(128), r, "b" * 40), [])   # 셀 수 없음을 「조상이 아니다」 로 내지 않는다
        self.assertEqual(len(JR._commit_problems(Rc(1), r, "b" * 40)), 1)   # 양의 짝 — rc 1 은 거절 사유 하나

    def test_unreadable_copy_has_no_framing_pair(self):   # team_write.framing_pair — 사본을 읽지 못함 · 빈 사본
        import team_write as TW
        self.assertIsNone(TW.framing_pair(b"not a section line\n", "docs/b.md"))   # parse_original 이 FormatError 를 낸다
        self.assertIsNone(TW.framing_pair(b"", "docs/b.md"))

    def test_origin_table_separator_with_three_cells(self):   # check_bundle_coverage — 구분 행이 칸 넷이 아님
        import check_bundle_coverage as cbc
        spec = "# s\n\n## 원문 대조\n\n| 원문 | 설계 | 처리 | 근거 |\n|---|---|---|\n| a | b | 그대로 | — |\n"
        self.assertEqual(cbc.origin_notes(spec), (["원문 대조 표를 읽지 못했다 — 원문 대조 표 구분 행이 칸 넷이 아니다"], []))

    def test_unchecked_impl_still_shows_notices(self):   # check_bundle_coverage.render_impl — 검사 불가(3)에도 알림 줄
        import check_bundle_coverage as cbc
        self.assertEqual(cbc.render_impl({"status": 3, "reason": "사유", "notices": ["n1"]}), "구현 대조 검사 불가 — 사유\n알림 — n1")

    def test_neighbor_decisions_skip_and_unread_tree(self):   # spec_review_bundle._team_decisions — 과제 칸 없는 이웃 · 읽을 트리 없음
        import spec_review_bundle as srb
        blocks = [{"id": "P1", "stage": "끝남"},
                  {"id": "E2", "stage": "준비", "tip": None, "job": {"intent": "docs/r/t/jobs/E2/INTENT.md"}}]
        self.assertEqual(srb._team_decisions(_ShutGit(), None, blocks, {"P1", "E2"}),
                         ["  E2 — 셀 수 없음: 과제 파일을 읽지 못했다 — docs/r/t/jobs/E2/INTENT.md"])


if __name__ == "__main__":
    unittest.main()
