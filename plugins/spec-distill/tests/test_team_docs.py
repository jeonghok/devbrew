#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team 형식의 사람이 읽는 형식 정본(references/team-files.md) · README · 판(R1 AC26 — 계획 1 몫).

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_team_docs.py
"""
from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

PLUGIN = Path(__file__).resolve().parents[1]
SCRIPTS = PLUGIN / "scripts"
sys.path.insert(0, str(SCRIPTS))
import team_layout as L  # noqa: E402
import team_files as F  # noqa: E402
import roadmap_render as R  # noqa: E402
import team_status as TS  # noqa: E402

DOC = PLUGIN / "references" / "team-files.md"
README = PLUGIN / "README.md"


class TeamFilesDoc(unittest.TestCase):   # R1 AC26 — 계획 1 몫
    def test_sections_of_this_plan(self):
        heads = [l for l in DOC.read_text(encoding="utf-8").splitlines() if l.startswith("## ")]
        self.assertEqual(heads, ["## §1 팀 폴더", "## §2 과제 폴더와 INTENT.md", "## §3 원자료", "## §4 sources.md", "## §5 결과 파일",
                                 "## §6 역할 문서", "## §10 단계 계산"])

    def test_names_come_from_the_code(self):
        text = DOC.read_text(encoding="utf-8")
        for name in L.ROLES + (L.RULES_FILE, L.HANDBOOK_FILE, L.INTENT_FILE, L.SOURCES_FILE, L.ORIGINAL_FILE, L.REVIEW_FILE, L.STATUS_FILE,
                               "layout: team", "type: job", "type: job-sources", "kind: epic", "kind: task", R.TEAM_COLUMN) + F.SECTIONS:
            self.assertIn(name, text, name)
        self.assertIn("<!-- 출처: ", text)   # 구간 첫 줄의 머리

    def test_users_example_is_verbatim(self):   # 원문 대조 — INTENT.md 예시 「로그인 개선」
        text = DOC.read_text(encoding="utf-8")
        for line in ("예시) 로그인 개선", "목표 - 재설정 뒤 다시 로그인 하는 단계 없애기",
                     "지시 원문 - 재설정 뒤에 다시 로그인 하는 단계 없애고, 디자인 톤은 유지",
                     "하지 않을 것 - 로그인 화면 디자인 바꾸기 소셜 로그인 추가", "결정 기록 - 10/22 방향 1 승인 단계가 가장 적음"):
            self.assertIn("\n" + line + "\n", text)

    def test_notice_not_enforcement_lives_here_and_in_readme_only(self):   # D2.19
        sentence = "역할 문서는 알림이고 막는 것은 도구 권한이다"
        self.assertIn(sentence, DOC.read_text(encoding="utf-8"))
        self.assertIn(sentence, README.read_text(encoding="utf-8"))

    def test_one_plan_per_branch_and_exit_codes(self):
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("브랜치 하나에 계획 하나", text)
        self.assertIn("종료 코드 4", text)


class Readme(unittest.TestCase):
    def test_team_layout_is_documented(self):
        text = README.read_text(encoding="utf-8")
        principles = text.split("## Principles Instantiated", 1)[1].split("\n## ", 1)[0]
        self.assertIn("team-files.md", principles)
        for name in ("--layout team", "team_layout.py check", "job new", "original --brief", "references/team-files.md"):
            self.assertIn(name, text, name)
        self.assertIn("`roadmap_write.py` 는 0 성공 · 1 쓰지 않음 · 2 사용법 오류 · 4 ", text)


def section(text, head):
    return text.split(head + "\n", 1)[1].split("\n## ", 1)[0]


class ReadSideDoc(unittest.TestCase):   # R1 AC26 — 계획 2 몫
    def test_section5_names_come_from_the_code(self):
        s5 = section(DOC.read_text(encoding="utf-8"), "## §5 결과 파일")
        for name in L.STAGES + F.DECISION_KINDS + F.BLOCKED_HEADS + (L.BLOCKED_FILE, F.RESULT_TYPE, F.BLOCKED_TYPE, "bundle_at", "job_at", "job sync",
                                                                     "job_results.py check", "Task <n>/<전체>: 끝|막힘 — <커밋>", "끝 — <커밋>",
                                                                     "- 결과 받음 · <YYYY-MM-DD> · 「<결과 파일 이름> · <커밋> · <대조 첫 줄>」"):
            self.assertIn(name, s5, name)

    def test_section10_names_the_stages_and_notices(self):
        s10 = section(DOC.read_text(encoding="utf-8"), "## §10 단계 계산")
        for word in ("설계 중", "계획", "구현 중", "구현 끝", "진행 중", "결과 받음", "결과 있음 · 받음 없음", "받은 뒤 바뀜", "받음 줄을 세지 않았다",
                     "막힘", "예약 밖 변경", "경로 예약 위반", TS.UNPUSHED, TS.SPLIT, "로드맵 밖 과제", "진행 줄 없음", "branch_tip.py"):
            self.assertIn(word, s10, word)

    def test_results_point_instead_of_copying(self):   # AC28 — 설계 · 틀의 글자(「말고」)
        text = DOC.read_text(encoding="utf-8")
        self.assertIn("옮겨 싣지 말고 커밋과 경로로 가리킨다", section(text, "## §5 결과 파일"))
        for row in text.splitlines():
            if "테스트 출력" in row:
                self.assertTrue("싣지 않" in row or "싣지 말" in row, row)   # 어디에도 테스트 출력을 실으라는 요구가 없다

    def test_no_build_schedule_words(self):   # 잔여 — 설치본만 읽는 사람이 풀 수 없는 글
        text = DOC.read_text(encoding="utf-8")
        for word in ("이 판은", "이 판의", "이 판에는", "다음 판", "(R3)", "계획 2"):
            self.assertNotIn(word, text, word)
        self.assertNotIn("머지 여부를 확인하지 못했다", text)
        self.assertIn("기준", section(text, "## §3 원자료"))   # 대체 대조(B22)를 적었다

    def test_readme_names_the_read_side(self):
        text = README.read_text(encoding="utf-8")
        principles = text.split("## Principles Instantiated", 1)[1].split("\n## ", 1)[0]
        self.assertIn("job_results.py", principles)
        for name in ("job sync", "job_results.py check", "workflow_superpowers.py", "로드맵 밖 과제", "결과 받음"):
            self.assertIn(name, text, name)
        self.assertNotIn("이 판에는 출처 줄의 커밋을 고치는 명령이 없습니다", text)


class CarriedRulings(unittest.TestCase):   # 계획 2 를 도는 동안 정해진 것 — 문서에 남아야 하는 글(코드의 글자는 코드에서 읽는다)
    def doc(self, head):
        return section(DOC.read_text(encoding="utf-8"), head)

    def test_task_scan_split_and_tasks_list(self):   # 과제의 사정은 알림 · 읽지 못함은 검사 불가 · 작업 목록에는 알림이 없다
        s10 = self.doc("## §10 단계 계산")
        for words in ("과제의 사정은 알림이고 읽지 못함은 검사 불가다", "파일이 아닌 경로", "레포 밖",
                      "작업 목록(`show --tasks`)에는 실리지 않는다", TS.SHALLOW, TS.RULINGS_UNREAD):
            self.assertIn(words, s10, words)

    def test_received_line_limits(self):   # 받은 뒤 바뀜이 보지 못하는 것 · 세는 것
        s10 = self.doc("## §10 단계 계산")
        self.assertIn("merge 커밋 안에서 손으로 고친 것은 보지 못한다", s10)
        self.assertIn("기본 브랜치에 닿지 않은 다른 에픽 브랜치를 합치면", s10)

    def test_result_check_edges(self):   # 빈 범위는 검사 불가 · 거절과 검사 불가가 함께면 3 · 다 읽지 못한 결과 파일 · 펜스
        s5 = self.doc("## §5 결과 파일")
        for words in ("task 절에 설계문서의 AC 가 하나도 없으면", "거절 사유와 검사 불가가 함께면 종료 코드는 3", TS.RESULT_UNREAD,
                      "CommonMark"):
            self.assertIn(words, s5, words)

    def test_redecompose_reads_this_branch(self):   # 재분해가 읽는 INTENT.md — 화면 글은 코드의 상수
        import team_write
        s2 = self.doc("## §2 과제 폴더와 INTENT.md")
        self.assertIn(team_write.RANGE_READ, s2)
        self.assertIn("머지되거나 끝난 에픽은 바꾸거나 지우지 않는다 — 지시 원문 범위만 바꾼 표도 같다", s2)
        self.assertIn("단계 계산도 그 과제 번호와 함께 알린다(§10)", s2)
        self.assertIn(team_write.EPIC_SHAPED % "<이름>", s2)
        for name in ("plan-0.md", "plan-02.md"):   # 계획 파일 이름이 아닌 꼴
            self.assertIn(name, s2, name)

    def test_framing_pair_and_fallback(self):   # ② 없이 다시 부르기 · 표지가 남음 · 출처 커밋을 읽지 못한 구간의 대체 대조
        s3 = self.doc("## §3 원자료")
        self.assertNotIn("사본에 framing 구간이 이미 있어도 ② 없이 부르면 같은 사유로 멈춘다", s3)
        for words in ("틀려도 멈추는 쪽으로만 틀린다", "덧붙인 뒤에도 brief 쪽 출처 줄 끝의 표지는 남는다", "트리 밖이라",
                      "의 같은 줄과 견줬다 — 같다", "의 같은 줄과도 다르다", "에도 그 파일이 없다", "의 그 파일도 읽지 못했다",
                      "을 몰라 같은 줄과 견주지 못했다"):
            self.assertIn(words, s3, words)

    def test_origin_table_and_review_entry(self):   # 원문 대조 표의 규칙 · spec-review 진입
        import check_bundle_coverage as cbc
        import spec_review_bundle as srb
        s10 = self.doc("## §10 단계 계산")
        for words in cbc.ORIGIN_KINDS + (cbc.ORIGIN_MISSING, "원문 대조 표를 읽지 못했다 — ", "그 행 하나만 알리고",
                                         "`## 번호 대조` 표가 없으면 검사 불가", srb.TASK_SKIP, "결정 줄 없음", "셀 수 없음: ",
                                         "번호 대조 검사 불가 — "):
            self.assertIn(words, s10, words)


FLOOR = (8, 16, 0)
FORMAT_FLOOR = (8, 15, 0)   # 다섯 낱말을 담은 절(형식 쪽 판)의 바닥
WORDS = ("--layout team", "rules_budget", "handbook_budget", "job new", "종료 코드 4")


def version_tuple(text: str):
    parts = text.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        return None
    return tuple(int(p) for p in parts)


def changelog_entries(log: str) -> list:
    """[(판 튜플, 그 판 절의 글)] — `## [x.y.z] — ` 머리 줄마다 다음 머리 앞까지."""
    out = []
    for line in log.split("\n"):
        head = line.startswith("## [") and "] — " in line and version_tuple(line[4:line.index("]")])
        if head:
            out.append((head, []))
        elif out:
            out[-1][1].append(line)
    return [(v, "\n".join(body)) for v, body in out]


def version_problems(version: str, log: str) -> list:
    """판 올림의 문제 줄들(없으면 []) — 판이 FLOOR 이상, 그 판의 CHANGELOG 머리가 있고, 다섯 낱말을 모두 담은 절이
    하나뿐이며 그 절의 판이 FORMAT_FLOOR 이상. 뒤의 판 올림이 새 절을 더해도 맞는다."""
    out = []
    got = version_tuple(version)
    if got is None or got < FLOOR:
        out.append("plugin.json 판 %r 이 %s 보다 낮다" % (version, FLOOR))
    if "## [%s] — " % version not in log:
        out.append("CHANGELOG 에 지금 판 %s 의 머리가 없다" % version)
    hits = [v for v, body in changelog_entries(log) if all(w in body for w in WORDS)]
    if len(hits) != 1:
        out.append("다섯 낱말을 모두 담은 CHANGELOG 절이 하나가 아니라 %d개다: %s" % (len(hits), hits))
    elif hits[0] < FORMAT_FLOOR:
        out.append("다섯 낱말을 담은 절의 판 %s 이 %s 보다 낮다" % (hits[0], FORMAT_FLOOR))
    return out


class Version(unittest.TestCase):
    def read(self):
        version = json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"]
        return version, (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")

    def test_bumped_with_changelog(self):
        self.assertEqual(version_problems(*self.read()), [])

    def test_logic_has_teeth(self):   # 양성 · 음성 대조 — 실제 CHANGELOG 를 고친 사본으로
        version, log = self.read()
        entries = changelog_entries(log)
        self.assertGreater(len(entries), 10)   # 절을 읽었다
        hit = [(v, body) for v, body in entries if all(w in body for w in WORDS)][0][1]
        later = "# Changelog\n\n## [8.99.0] — 2026-12-01\n\n### Fixed\n- 다른 일\n" + log.split("\n", 1)[1]
        self.assertEqual(version_problems("8.99.0", later), [])   # 뒤의 판 올림은 깨지 않는다
        self.assertNotEqual(version_problems("8.99.0", log), [])   # 그 판의 머리가 없으면 잡는다
        for word in WORDS:
            self.assertNotEqual(version_problems(version, log.replace(hit, hit.replace(word, "x"))), [], word)
        twice = log + "\n## [0.0.1] — 2026-01-01\n" + hit + "\n"
        self.assertNotEqual(version_problems(version, twice), [])   # 다섯 낱말을 담은 절이 둘
        self.assertNotEqual(version_problems("8.13.1", log), [])   # 판이 FLOOR 아래
        below = version_problems("8.15.0", log)   # 이 일보다 먼저 기본 브랜치에 있던 판 — 그 머리는 있으니 걸리는 것은 바닥 하나다
        self.assertEqual(len(below), 1, below)
        self.assertIn("보다 낮다", below[0])


READ_WORDS = ("job_results.py", "job sync", "workflow_superpowers.py", "결과 받음", "로드맵 밖 과제")


class ReadSideVersion(unittest.TestCase):   # 판 글자를 못 박지 않는다(판정 R-R 의 꼴)
    def entries(self, words):
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        out = []
        for chunk in log.split("\n## [")[1:]:
            version = chunk.split("]", 1)[0]
            if all(w in chunk for w in words):
                out.append(version_tuple(version))
        return out

    def test_one_entry_after_the_format_entry(self):
        mine, first = self.entries(READ_WORDS), self.entries(WORDS)
        self.assertEqual((len(mine), len(first)), (1, 1), (mine, first))
        self.assertGreater(mine[0], first[0])   # 읽기 쪽 판이 형식 쪽 판 뒤다
        current = version_tuple(json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"])
        self.assertGreaterEqual(current, mine[0])

    def test_entry_carries_what_existing_repos_must_know(self):   # 이미 깐 레포가 손으로 맞출 줄 · 바뀐 동작
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        mine = [body for v, body in changelog_entries(log) if all(w in body for w in READ_WORDS)]
        self.assertEqual(len(mine), 1)
        added = [l for l in (PLUGIN / "templates" / "team" / "role-worker.md").read_text(encoding="utf-8").splitlines()
                 if "테스트 출력" in l]
        self.assertEqual(len(added), 1, added)
        self.assertIn(added[0], mine[0])   # 틀에 더한 줄을 글자 그대로
        for words in ("`references/team-files.md` §3 의 글이 정본이다", "`--framing-audit` 없이 다시 불러도 멈추지 않는다",
                      "옛 형식 문서라도", "pr-record"):
            self.assertIn(words, mine[0], words)


if __name__ == "__main__":
    unittest.main()
