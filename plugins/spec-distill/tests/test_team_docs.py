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
import team_rules as TR  # noqa: E402
import repo_defaults  # noqa: E402
import start_bundle as SB  # noqa: E402
import human_lines as HL  # noqa: E402

DOC = PLUGIN / "references" / "team-files.md"
README = PLUGIN / "README.md"
REF = PLUGIN / "references"
REPO = PLUGIN.parents[1]


class TeamFilesDoc(unittest.TestCase):   # R1 AC26 — 계획 1 몫
    def test_sections_of_this_plan(self):
        heads = [l for l in DOC.read_text(encoding="utf-8").splitlines() if l.startswith("## ")]
        self.assertEqual(heads, ["## §1 팀 폴더", "## §2 과제 폴더와 INTENT.md", "## §3 원자료", "## §4 sources.md", "## §5 결과 파일",
                                 "## §6 역할 문서", "## §7 RULES.md 와 HANDBOOK.md", "## §8 REVIEW.md", "## §9 시작 묶음",
                                 "## §10 단계 계산", "## §15 브랜치 사이 흐름"])

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
        for word in ("| 설계 | 설계 중 |", "| 설계 | 계획 |", "| 설계 | 구현 중 |", "| 설계 | 구현 끝 |", "| 설계 없음 | 진행 중 |",
                     "| 설계 없음 | 결과 받음 |", "`결과 있음 · 받음 없음: <이름>(대조를 기다린다)`", "`받은 뒤 바뀜: <이름> — <파일들>`",
                     "`받음 줄을 세지 않았다: <이름> — <첫 사유>`", "`막힘: <단계> plan <n> 시도 <n> — <경로>`", "`예약 밖 변경: <파일들>`",
                     "`경로 예약 위반: <파일> 은 <블록> 만 예약했다`", TS.UNPUSHED, TS.SPLIT, "로드맵 밖 과제", "사유 「진행 줄 없음」",
                     "`scripts/branch_tip.py` 의 `tip()` 하나가 고른다"):
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
        self.assertIn("덧붙이기 검사와 같은 기준(`--base <ref>`, 없으면 기본 브랜치 `origin/HEAD`)의 같은 파일 · 같은 줄과 견준다",
                      section(text, "## §3 원자료"))   # 대체 대조(B22)를 적었다

    def test_readme_names_the_read_side(self):
        text = README.read_text(encoding="utf-8")
        principles = text.split("## Principles Instantiated", 1)[1].split("\n## ", 1)[0]
        self.assertIn("job_results.py", principles)
        for name in ("job sync", "job_results.py check", "workflow_superpowers.py", "로드맵 밖 과제", "결과 받음"):
            self.assertIn(name, text, name)
        self.assertNotIn("이 판에는 출처 줄의 커밋을 고치는 명령이 없습니다", text)


class RulesAndBundleDoc(unittest.TestCase):   # R1 AC26 — 계획 3 몫
    def doc(self, head):
        return section(DOC.read_text(encoding="utf-8"), head)

    def test_section7_grammar_and_the_users_six_lines(self):
        s = self.doc("## §7 RULES.md 와 HANDBOOK.md")
        for line in ("[테스트] 고친 곳엔 테스트 먼저", "[배포] 실 서비스는 사람만", "[문서] 바꾼 건 CHANGELOG에",
                     "[폴더] 남의 폴더 고치지 않기", "[보고] 끝나면 leader에게", "[설계] 승인 전엔 코드 짜지 않기"):
            self.assertIn("\n" + line + "\n", s)   # 원문 대조 — 글자 그대로
        for word in TR.MARKERS + repo_defaults.BUDGET_KEYS + ("team_rules.py check", "team_rules.py candidates", "--ref"):
            self.assertIn(word, s)

    def test_section9_two_ways_and_the_lines(self):   # AC24 — 묶음을 건네는 두 길
        s = self.doc("## §9 시작 묶음")
        for part in ("일꾼이 직접 돌린다", "임시 파일로 받아 그 경로를 넘긴다", "리더는 그 출력을 읽지 않는다",
                     "start_bundle.py --roadmap", "--role " + L.LEADER_ROLE, "기준 커밋:", "읽을 것:", "쓸 것:", "검수 기준"):
            self.assertIn(part, s)

    def test_section15_flow_table(self):   # AC31
        s = self.doc("## §15 브랜치 사이 흐름")
        rows = [l for l in s.splitlines() if l.startswith("| ")]
        self.assertEqual(len(rows), 9)   # 머리 행 하나 · 파일 여덟 행(가름 행은 `|---` 로 시작해 들지 않는다)
        for part in ("leader_ref", "기준 커밋", TS.STALE, "origin"):
            self.assertIn(part, s)

    def test_no_pointer_to_a_later_plan_is_left(self):   # 음의 락 + 양의 짝
        text = DOC.read_text(encoding="utf-8")
        self.assertNotIn("계획 3 이", text)
        self.assertGreaterEqual(text.count("리더가 쓰는 자리(§15)"), 3)

    def test_section10_new_notices(self):
        s = self.doc("## §10 단계 계산")
        for part in (TS.STALE + ": ", TS.STALE + "을 재지 못했다", TS.UNCOUNTED_SHAPE, "얕은지"):
            self.assertIn(part, s)

    def test_section10_shallow_guard_is_narrowed_after_the_old_sentence(self):   # C1 — 옛 문장은 그대로, 좁힘은 새 문장
        s = self.doc("## §10 단계 계산")
        old = "단계가 「%s」 인 과제(얕은 클론)에는 예약을 재지 않고 알림도 내지 않으며" % TS.UNKNOWN
        self.assertIn(old, s)
        tail = s.split(old, 1)[1]
        self.assertIn("재지 않는 것은 얕은 클론일 때뿐이다", tail)
        self.assertIn("얕은지 읽지 못하면", tail)

    def test_section9_and_coverage_carry_the_late_decisions(self):   # B35 · B36
        s9 = self.doc("## §9 시작 묶음")
        self.assertIn("`%s%s`" % (SB.PREFIX + "멈춤 — ", SB.ALREADY_MERGED % "<과제 이름>"), s9)
        s5 = self.doc("## §5 결과 파일")
        self.assertIn("머리 roadmap 이 레포 상대 경로가 아니다", s5 + self.doc("## §10 단계 계산"))

    def test_readme_names_the_new_commands(self):
        text = README.read_text(encoding="utf-8")
        for part in ("scripts/start_bundle.py", "scripts/team_rules.py", TS.STALE):
            self.assertIn(part, text)


class CarriedRulings(unittest.TestCase):   # 계획 2 를 도는 동안 정해진 것 — 문서에 남아야 하는 글(코드의 글자는 코드에서 읽는다)
    def doc(self, head):
        return section(DOC.read_text(encoding="utf-8"), head)

    def test_task_scan_split_and_tasks_list(self):   # 과제의 사정은 알림 · 읽지 못함은 검사 불가 · 작업 목록에는 알림이 없다
        s10 = self.doc("## §10 단계 계산")
        for words in ("과제의 사정은 알림이고 읽지 못함은 검사 불가다", "작업 목록(`show --tasks`)에는 실리지 않는다", TS.SHALLOW,
                      TS.RULINGS_UNREAD):
            self.assertIn(words, s10, words)

    def test_what_git_could_not_read_for_tasks(self):   # 목록을 못 읽음 · 받음 줄이 있을 때와 없을 때(코드의 글로)
        import job_results as JR
        s10 = self.doc("## §10 단계 계산")
        scan = s10.split("**로드맵 밖 과제.**", 1)[1].split("**계산 결과의 칸.**", 1)[0]
        # 기본 브랜치의 목록과 브랜치 끝의 목록은 알림 글이 다르다(「세지 못했다」 · 「다 세지 못했다」) — 글은 코드의 상수에서
        self.assertIn("기본 브랜치의 과제 폴더 이름 목록을 git 이 읽지 못하면 과제를 하나도 싣지 않고 `%s — %s` 를, 기본 브랜치에 "
                      "들어가지 않은 브랜치 끝 목록이나 그 끝의 과제 폴더 이름 목록을 읽지 못하면 읽은 과제는 싣고 `%s — …` 를 낸다. "
                      "둘 다 `git 읽기 실패 — …` 로 검사 불가 사유에 든다(종료 코드 3)."
                      % (TS.TASKS_UNCOUNTED, TS.MAIN_JOBS_UNREAD % "<과제 폴더>", TS.TASKS_PARTLY), scan)
        self.assertNotIn("과제 폴더 이름 목록 · 브랜치 끝 목록을 git 이 읽지 못하면", scan)
        self.assertNotEqual(TS.TASKS_UNCOUNTED, TS.TASKS_PARTLY)
        self.assertIn("`%s: <이름> — %s`" % (JR.NOT_COUNTED_HEAD, JR.NOT_A_FILE % "<경로>"), scan)
        self.assertIn("받음 줄이 없으면 그 결과 파일을 대조하지 않으므로 「결과 있음 · 받음 없음」 알림만 내고 종료 코드는 바뀌지 않는다", scan)
        self.assertNotIn("그때 알림은 `로드맵 밖 과제를 다 세지 못했다 — …` 다", scan)

    def test_unreadable_results_folder_by_flow(self):   # 설계 흐름은 알 수 없음 · 설계 없는 흐름은 진행 중 + 알림 · 둘 다 3
        import job_results as JR
        s10 = self.doc("## §10 단계 계산")
        self.assertIn("`%s: 결과 폴더를 읽지 못했다`" % JR.NOT_COUNTED_HEAD, s10)
        self.assertIn("설계 흐름은 spec 승인 뒤면 「알 수 없음」(`<결과 폴더> 를 읽지 못했다`), 설계 없는 흐름은 「진행 중」 · `브랜치 있음` 이다", s10)
        self.assertNotIn("결과 폴더를 읽지 못해 결과 파일이 없다고 할 수 없으면 「알 수 없음」 이다", s10)

    def test_job_sync_git_and_exit_codes(self):   # job sync 가 git 을 부르는 자리 · 빠졌던 종료 코드 셋
        import team_write as TW
        s5 = self.doc("## §5 결과 파일")
        sync = s5.split("**결과 파일 맞추기(`job sync`).**", 1)[1].split("**결과 대조", 1)[0]
        self.assertNotIn("git 을 부르지 않는다", sync)
        self.assertIn("git 은 레포 뿌리와 레포 설정(`roadmaps_dir`)을 읽을 때만 부르고, 과제 브랜치의 커밋 · 이력은 읽지 않으며 커밋하지 않는다", sync)
        for words in ("`%s` 아래 경로다" % TW.NOT_HERE, "레포 설정을 읽지 못했다", "git 작업 트리 밖이다"):
            self.assertIn(words, sync, words)

    def test_exact_sentences_from_the_code(self):   # 코드보다 흐리던 문장 일곱
        s5, s10 = self.doc("## §5 결과 파일"), self.doc("## §10 단계 계산")
        self.assertIn("흐름이 아니라 그 끝의 과제 폴더에 `design.md` 가 있는지로 가른다", s5)
        self.assertIn("명령은 막지 않는다 — `design` · `plan` 결과 파일도 대조하고 받음 줄을 내며 `record` 도 그 줄을 받는다. 단계 계산이 세지 않을 뿐이다", s5)
        self.assertIn("`%s — …` 한 줄이 끼고" % TS.UNPUSHED, s5)
        self.assertIn("과제 폴더의 계획 파일(`plan-<n>.md` 꼴이면 어느 n 이든)", s10)
        self.assertIn("`<INTENT.md 경로> 를 읽지 못했다`", s10)
        self.assertIn("머리 · 기계 줄에 읽지 못한 것이 하나라도 있으면 대조를 통과하지 않는다", s5)
        self.assertIn("알림 자체는 종료 코드를 바꾸지 않는다 — 다만 원인이 git 이 읽지 못한 것이면 그 실패가 검사 불가 사유에 들어 종료 코드가 3 이다", s10)

    def test_received_line_limits(self):   # 받은 뒤 바뀜이 보지 못하는 것 · 세는 것
        s10 = self.doc("## §10 단계 계산")
        self.assertIn("merge 커밋 안에서 손으로 고친 것은 보지 못한다", s10)
        self.assertIn("기본 브랜치에 닿지 않은 다른 에픽 브랜치를 합치면", s10)

    def test_result_check_edges(self):   # 빈 범위는 검사 불가 · 거절과 검사 불가가 함께면 3 · 다 읽지 못한 결과 파일 · 펜스
        s5 = self.doc("## §5 결과 파일")
        for words in ("계획 파일이 있는데 그 task 절에 설계문서의 AC 가 하나도 없으면 범위가 빈 것이라 통과가 아니라 검사 불가다",
                      "거절 사유와 검사 불가가 함께면 종료 코드는 3", TS.RESULT_UNREAD, "CommonMark"):
            self.assertIn(words, s5, words)

    def test_redecompose_reads_this_branch(self):   # 재분해가 읽는 INTENT.md — 화면 글은 코드의 상수
        import team_write
        s2 = self.doc("## §2 과제 폴더와 INTENT.md")
        self.assertIn(team_write.RANGE_READ, s2)
        self.assertIn("머지되거나 끝난 에픽은 바꾸거나 지우지 않는다 — 지시 원문 범위만 바꾼 표도 같다", s2)
        self.assertIn("단계 계산도 그 과제 번호와 함께 알린다(§10)", s2)
        self.assertIn(team_write.EPIC_SHAPED % "<이름>", s2)
        self.assertIn("`plan-0.md` · `plan-02.md` 는 계획 파일이 아니다", s2)   # 계획 파일 이름이 아닌 꼴 — 코드도 그렇게 읽는다
        self.assertEqual((L.plan_number("plan-0.md"), L.plan_number("plan-02.md"), L.plan_number("plan-2.md")), (None, None, 2))

    def test_framing_pair_and_fallback(self):   # ② 없이 다시 부르기 · 표지가 남음 · 출처 커밋을 읽지 못한 구간의 대체 대조
        s3 = self.doc("## §3 원자료")
        import team_check as TC
        self.assertNotIn("사본에 framing 구간이 이미 있어도 ② 없이 부르면 같은 사유로 멈춘다", s3)
        for words in ("틀려도 멈추는 쪽으로만 틀린다", "덧붙인 뒤에도 brief 쪽 출처 줄 끝의 표지는 남는다", "트리 밖이라"):
            self.assertIn(words, s3, words)
        # 「그 밖에는」 의 경우는 진짜 명령으로 잰 것만 — audit 를 나중에 고친 사본 · 링크로 준 audit 의 사본은 짝이 남아 지나간다
        self.assertNotIn("그 audit 를 고쳐 사본과 달라진 경우", s3)
        self.assertNotIn("심볼릭 링크로 준 audit 로 만든 사본 —", s3)
        # 짝이 남아 지나가는 것은 그 brief 를 옮길 때 framing 구간이 새로 붙은 사본뿐 — 다른 brief 가 이미 옮긴 audit 를 받은 사본은 멈춘다
        self.assertNotIn("사본을 만든 뒤 그 audit 를 고치거나 지운 경우와 심볼릭 링크로 준 audit 로 만든 사본도 짝이 남아 있어 지나간다", s3)
        self.assertIn("그 brief 를 옮길 때 framing 두 구간이 새로 붙었으면 — 심볼릭 링크로 준 audit 여도, 사본을 만든 뒤 그 audit 를 "
                      "고치거나 지워도 — 짝이 남아 있어 지나간다(고친 audit 를 찾으면 그 절을 끝에 통째로 다시 옮긴다). 그 밖에는 — "
                      "사본을 framing 없이 만든 뒤 ② 로 짝을 끝에 덧붙인 사본 · 구간 차례가 어긋난 사본 · 같은 팀 폴더의 다른 brief 가 "
                      "이미 옮긴 audit 를 ② 로 받아(링크로 같은 파일을 가리켜도) framing 구간이 건너뛰어진 사본처럼 이 brief 의 첫 구간 "
                      "바로 앞에 짝이 없으면 — 다시 부를 때마다 같은 ② 를 준다. 이 판정은 틀려도 멈추는 쪽으로만 틀린다.", s3)
        # 남는 것 둘째 — 고쳤다 되돌린 결과물(마지막 리뷰 I3)
        self.assertIn("\n  - 같은 브랜치에서 brief 를 고쳤다 되돌린 커밋도 이 검사를 지나간다 — 고친 커밋을 출처로 만든 사본은 지금 HEAD 의 조상인 출처 커밋을 받기 때문이다. "
                      "그 고침은 PR 의 바뀐 파일 목록에는 나오지 않고 커밋별 보기에서만 보인다. squash 머지면 머지 뒤 기준과 견줘 검사 불가로 드러나고, "
                      "머지 커밋으로 머지하면 계속 지나간다.\n", s3)
        # 남는 것 첫째의 뒤 문장 — 커밋했다 지운 framing audit 꼴 파일(PR #330 품질 게이트 리뷰)
        self.assertIn("같은 브랜치에 framing audit 꼴을 갖춘 파일을 새로 커밋하면 이 검사를 지나간다 — 그 파일은 PR 에 새 파일로 보인다. "
                      "그 파일을 같은 브랜치에서 다시 지워도 지나간다 — 그때는 PR 의 바뀐 파일 목록에 나오지 않고 커밋별 보기에서만 보인다.\n", s3)
        # 남는 것 셋째 — 견줄 기준의 사본이 없을 때 바꾼 source_brief(PR #330 품질 게이트 리뷰 · 좁은 재리뷰)
        self.assertIn("\n  - 덧붙이기 검사가 견줄 기준의 사본이 없으면 로드맵의 `source_brief` 를 다른 brief 로 바꾸고 사본을 그 brief 로 다시 만들어도 "
                      "이 검사를 지나간다 — 기준에 그 팀 폴더가 아직 없는 브랜치와, 기본 기준을 몰라 덧붙이기 검사를 건너뛴 때(그 알림 줄이 나온다)다. "
                      "PR 에는 로드맵 파일의 `source_brief` 값으로 보인다. 기준의 사본에 옛 brief 의 구간이 있으면 `source_brief` 를 바꿔도 "
                      "그 구간이 어긋남으로 남고, 사본을 다시 만들면 덧붙이기 검사가 거절한다.\n", s3)
        # 대체 대조의 사유 글 — 출처 쪽 말머리는 코드의 상수, 기준 쪽 글은 코드에 있는 글과 같은지 함께 본다
        for say in (TC._SRC_UNREAD, TC._SRC_ABSENT, TC._SRC_BROKEN, TC._SRC_FOREIGN):
            self.assertIn("`%s`" % say[0], s3, say)
        source = (SCRIPTS / "team_check.py").read_text(encoding="utf-8")
        for words in ("의 같은 줄과 견줬다 — 같다", "의 같은 줄과도 다르다", "에도 그 파일이 없다", "의 그 파일도 읽지 못했다",
                      "을 몰라 같은 줄과 견주지 못했다"):
            self.assertIn(words, source, words)
            self.assertIn(words, s3, words)

    def test_source_problem(self):   # AC1 · AC3 — 출처 규칙 하나
        import team_check as TC
        brief = "docs/iv/b.md"
        seed = b"---\ntype: interview-seed-audit\n---\n"
        self.assertEqual(TC.audit_of(brief), "docs/iv/b.audit.md")
        self.assertIsNone(TC.audit_of("docs/iv/b.txt"))
        self.assertIsNone(TC.source_problem(brief, brief, b"x"))
        self.assertIsNone(TC.source_problem("docs/iv/b.audit.md", brief, b"x"))
        self.assertIsNone(TC.source_problem("anywhere/s.audit.md", brief, seed))   # 옛 기록 — 옛 종류 글자
        self.assertIsNone(TC.source_problem("anywhere/s.audit.md", brief, b"---\ntype: intent-seed-audit\n---\n"))
        self.assertEqual(TC.source_problem("docs/x/forged.audit.md", brief, b"---\ntype: interview-audit\n---\n"),
                         TC.SOURCE_NOT_ALLOWED % brief)
        self.assertEqual(TC.source_problem("docs/iv/other.md", brief, b"no head"), TC.SOURCE_NOT_ALLOWED % brief)
        self.assertIsNone(TC.source_problem("docs/x/forged.audit.md", None, b"x"))     # Review Focus 3
        self.assertIsNone(TC.source_problem("docs/x/forged.audit.md", brief, None))    # 견줄 파일 없음 — 대조가 3 으로 끝낸다

    def test_one_source_rule(self):   # 규칙을 두 군데에 따로 적지 않는다 — framing 종류 글자는 대응표 모듈에서만 온다
        import re
        tw = (SCRIPTS / "team_write.py").read_text(encoding="utf-8")
        tc = (SCRIPTS / "team_check.py").read_text(encoding="utf-8")
        self.assertNotIn('".audit.md"', tw)
        self.assertEqual(tc.count('".audit.md"'), 1)
        for name, src in (("team_write.py", tw), ("team_check.py", tc)):
            for lit in ("interview-seed-audit", "intent-seed-audit"):   # 옛 글자 · 새 글자 리터럴 모두 없다(주석 포함)
                self.assertNotIn(lit, src, "%s: %s" % (name, lit))
            self.assertIsNone(re.search(r"[!=]=\s*(?:team_check\.)?FRAMING_TYPE", src), name)   # 글자 그대로 견주지 않는다
            self.assertEqual(src.count("legacy_names.kind_matches("), 1, name)   # 견주는 자리 하나 — 옛 글자도 받는다
        self.assertEqual(re.findall(r"(?m)^FRAMING_TYPE = .*$", tc), ["FRAMING_TYPE = legacy_names.INTENT_SEED_AUDIT"])
        self.assertEqual(re.findall(r"(?m)^FRAMING_TYPE = .*$", tw), ["FRAMING_TYPE = team_check.FRAMING_TYPE"])
        self.assertRegex(tc, r"(?m)^import legacy_names\b")

    def test_origin_table_and_review_entry(self):   # 원문 대조 표의 규칙 · spec-review 진입
        import check_bundle_coverage as cbc
        import spec_review_bundle as srb
        s10 = self.doc("## §10 단계 계산")
        for words in cbc.ORIGIN_KINDS + (cbc.ORIGIN_MISSING, "원문 대조 표를 읽지 못했다 — ", "그 행 하나만 알리고",
                                         "`## 번호 대조` 표가 없으면 검사 불가", srb.TASK_SKIP, "결정 줄 없음", "셀 수 없음: ",
                                         "번호 대조 검사 불가 — "):
            self.assertIn(words, s10, words)


class FinalReviewRulings(unittest.TestCase):   # 마지막 리뷰의 수정 — 문장은 줄 통째로(뒤에 부정을 붙이면 줄이 달라진다), 글은 코드의 상수
    def s10(self):
        return section(DOC.read_text(encoding="utf-8"), "## §10 단계 계산")

    def assertLine(self, line, text):
        self.assertIn("\n" + line + "\n", text)

    def test_partial_merge_with_an_uncounted_branch(self):   # 일부 머지가 덮은 「알 수 없음」 — 단계 글자 그대로 · 검사 불가(3)
        import roadmap_status as RS
        s10 = self.s10()
        self.assertLine("- 얕은 클론에서는 브랜치가 있는 블록이 「%s」 이고 근거는 「%s」 다. 앞 브랜치가 머지된 블록은 아래 「일부 머지」 "
                        "줄을 따른다." % (TS.UNKNOWN, TS.SHALLOW), s10)
        self.assertLine("- 「일부 머지 n/m」 인 블록에서 지금 브랜치를 세지 못하면(얕은 클론 · 그 끝의 INTENT.md 를 읽지 못함 · 결과 "
                        "폴더를 읽지 못함) 단계 글자는 「일부 머지 n/m」 그대로이고 근거가 `<브랜치> — %s · <사유>` 다. 그 근거가 검사 "
                        "불가 사유 `<번호> %s — <근거>` 로 올라 종료 코드는 3 이다." % (TS.UNKNOWN, RS.PARTIAL_UNCOUNTED), s10)

    def test_plain_flow_reads_design_only_when_checking(self):   # 리더 물음 1 — 설계 없는 흐름의 design.md
        self.assertLine("- 설계 없는 흐름의 단계는 `design.md` 에 기대지 않는다 — 그 파일은 결과 대조(§5)와 번호 대조에서만 읽는다(받음 줄을 "
                        "다시 계산할 때도 결과 대조다). 번호 대조는 설계문서가 번호를 기각했을 때 다른 블록이 그 번호를 받드는지 보려고 "
                        "그 블록의 `design.md` 를 읽는다. 받음 줄이 없으면 그 자리가 파일이 아니어도(블롭이 아님) 알림은 「%s」 그대로이고, "
                        "`job_results.py check` 를 돌릴 때 검사 불가(종료 코드 3)가 난다." % TS.NO_RECEIPT, self.s10())

    def test_received_without_the_output_file(self):   # 결과 받음인데 산출물 칸의 파일이 그 끝에 없다 — 경고(1)
        import roadmap_status as RS
        self.assertLine("- 설계 없는 흐름의 블록이 「%s」 인데 산출물 칸이 가리키는 파일이 그 끝에 하나도 없으면 대조할 문서가 없다 — "
                        "경고 `%s` 가 붙고 종료 코드는 경고의 규칙대로 1 이다(옛 형식에서 「계획」 이후 단계의 묶음에 붙는 경고와 같다)."
                        % (L.PLAIN_FLOW_STAGES[1], RS.SKIP_BUNDLE.replace("%d", "<n>")), self.s10())

    def test_task_reservation_notices(self):   # 로드맵 밖 과제의 예약 밖 변경 · 경로 예약 위반 — 종료 코드 그대로 · 머지된 과제는 없음
        import roadmap_status as RS
        self.assertLine("- 브랜치 끝에서 센 과제는 블록과 같은 판정으로 바꾼 파일을 알린다 — 고칠 자리는 INTENT.md 머리의 `paths` "
                        "다. 다른 블록이 예약한 파일은 `%s`, 공유 파일 · 머리 `paths` · 자기 과제 폴더 아래 · 어느 블록이 예약한 "
                        "파일을 뺀 나머지(팀 폴더의 다른 파일도 든다)는 `%s` 다. 그 과제의 알림이라 종료 코드를 바꾸지 않고, 바꾼 "
                        "파일을 git 이 읽지 못하면 `git 읽기 실패 — …` 로 검사 불가(종료 코드 3)다. 기본 브랜치에 있는 과제(%s)에는 "
                        "내지 않는다 — 잴 브랜치 끝이 없다. 단계가 「%s」 인 과제(얕은 클론)에는 예약을 재지 않고 알림도 내지 않으며, 그 "
                        "과제의 근거 끝에 `· %s` 가 붙는다."
                        % (RS.RESERVE_VIOLATION % ("<파일>", "<블록>"), RS.RESERVE_OUTSIDE % "<파일들>", TS.MERGED,
                           TS.UNKNOWN, TS.RESERVE_UNSCANNED), self.s10())

    def test_task_unreadable_result_without_a_receipt(self):   # 리더 물음 1 — 로드맵 밖 과제의 블롭 아닌 결과 파일 · 종료 코드 그대로
        scan = self.s10().split("**로드맵 밖 과제.**", 1)[1].split("**계산 결과의 칸.**", 1)[0]
        self.assertIn("받음 줄이 없으면 그 결과 파일을 대조하지 않으므로 「결과 있음 · 받음 없음」 알림만 내고 종료 코드는 바뀌지 않는다. "
                      "결과 파일이 파일이 아닌 경로(블롭이 아님)면 그 알림은 `%s: <이름>(%s)` 다 — 블록은 판정 줄을 읽다가 같은 "
                      "파일을 읽지 못해 판정 읽기 불가 경고와 3 이 나지만, 로드맵 밖 과제는 판정 줄을 읽지 않아 종료 코드가 그대로다. "
                      "기본 브랜치를 모르면 `%s — 기본 브랜치를 모른다` 다." % (TS.NO_RECEIPT, TS.UNREAD_END, TS.TASKS_UNCOUNTED), scan)

    def test_constants_feed_the_notices(self):   # 양성 대조 — 위 단언들이 읽는 상수가 실제 알림 글을 만든다
        import roadmap_status as RS
        self.assertEqual(RS.RESERVE_VIOLATION % ("a", "E1"), "경로 예약 위반: a 은 E1 만 예약했다")
        self.assertEqual(RS.RESERVE_OUTSIDE % "b", "예약 밖 변경: b")
        self.assertEqual(RS.SKIP_BUNDLE % 2, "번호 대조 건너뜀(셀 수 없음) — 설계문서 없는 묶음이라 배정 번호 2개를 대조하지 않았다")
        self.assertEqual(L.PLAIN_FLOW_STAGES, ("진행 중", "결과 받음"))


class HumanLines(unittest.TestCase):   # R2 AC22 — 계획 1 몫
    def test_team_files_documents_human_lines_and_gates(self):
        text = (REF / "team-files.md").read_text(encoding="utf-8")
        for kind in HL.KINDS:
            for label in HL.PASS_LABELS[kind]:
                self.assertIn("「%s」" % label, text, label)
        for word in (HL.PASS, HL.NO_EVIDENCE, HL.MISMATCH, HL.UNCHECKED, HL.STALE, HL.GATE_OFF, "human_gate", "record --human", "ask-head", "human-check",
                     "· 근거 <세션>:<항목>", "계획 검토 plan <n>", "다시 시도 plan <n> 시도 <k>", "다시 시도 구현 시도 <k>",
                     "<과제 번호> plan <n> @<판>", "줄 없음", "상태 보기는 이 브랜치를 머지로 세지 못한다"):
            self.assertIn(word, text, word)
        self.assertNotIn("`design` · `plan` 은 designer", text)
        self.assertNotIn("종류는 일곱", text)
        self.assertNotIn("다시 시도 시도 <k>", text)
        self.assertIn("날짜는 인자로 받지 않는다", text)

    def test_carried_rulings(self):   # 계획 1 을 도는 동안 정해진 것 — 글자는 코드(start_bundle · human_lines)에서 읽는다
        text = (REF / "team-files.md").read_text(encoding="utf-8")
        for word in ("질문 하나는 관문 이름 하나만 담는다", "기록 절은 제목이 정확히", HL.RECORD_HEADS[0], HL.DEFERRED_HEAD,
                     "## 구현 대조 — <계획 파일 경로>", "작은따옴표로 감싼다",
                     "그 브랜치를 만들거나 앞 계획을 먼저 머지한 뒤 다시 부른다", "기록 절 안에 설계 글을 적는 것"):
            self.assertIn(word, text, word)
        self.assertEqual(SB.sync_line("a b", "worker", "x", "y"), "맞추는 명령: python3 %s job sync --result 'a b' --role worker --bundle-at x --job-at y"
                      % SB.roadmap_status._sh_word(str(Path(SB.__file__).resolve().parent / "roadmap_write.py")))
        self.assertEqual(SB.sync_line("a b", "worker", "x", "y", "z"),
                         SB.sync_line("a b", "worker", "x", "y") + " --rules-at z")   # B1 — 넷인 부름은 그대로 · 다섯째는 끝에만
        self.assertIn("위 꼴의 `<…>` 는 자리표시다", text)
        self.assertNotIn("위 꼴의 따옴표는 자리표시의 표기이고", text)
        self.assertNotIn('맞추는 명령: python3 "<roadmap_write.py', text)   # 출력 꼴 블록의 경로 둘레에 따옴표를 두지 않는다
        self.assertIn("INTENT.md 머리를 읽지 못하면 로드맵 블록의 과제는 1(멈춤)이고, 로드맵 밖 과제는 과제로 세지 못해 3(검사 불가)이다.", text)   # 종료 코드 1 · 3 의 경계(K22)

    def test_readme_changelog_and_dependencies(self):
        readme = (PLUGIN / "README.md").read_text(encoding="utf-8")
        for word in ("human_gate", "record --human", "사람 줄"):
            self.assertIn(word, readme, word)
        deps = (PLUGIN / "dependencies.md").read_text(encoding="utf-8")
        for word in ("세션 기록", "AskUserQuestion", "toolUseResult", "permissionDecision", "entrypoint", "sourceToolAssistantUUID", "isSidechain", "2.1.296", "2.1.327", "sdk-cli", "hook"):
            self.assertIn(word, deps, word)
        sections = [body for ver, body in changelog_entries((PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")) if ver == (8, 25, 0)]
        self.assertEqual(len(sections), 1, "CHANGELOG 에 8.25.0 절이 하나가 아니다")   # 맨 위 절이 아니라 이름으로 고른다 — 뒤의 판 올림이 새 절을 더해도 맞는다
        for word in ("record --human", "human_gate", "worker"):
            self.assertIn(word, sections[0], word)


FLOOR = (8, 21, 0)
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
        below = version_problems("8.20.0", log)   # 이 일보다 먼저 기본 브랜치에 있던 판 — 그 머리는 있으니 걸리는 것은 바닥 하나다
        self.assertEqual(len(below), 1, below)
        self.assertIn("보다 낮다", below[0])


class SessionWorkerDocs(unittest.TestCase):
    def test_readme_prerequisites_recommend_herdr_core(self):
        text = README.read_text(encoding="utf-8")
        sec = text.split("\n## Prerequisites", 1)[1].split("\n## ", 1)[0]
        for word in ("**herdr-core**", "권장", "없으면 계획 · 구현 담당자는 하위 agent 로 돈다", "`hc --skill`"):
            self.assertIn(word, sec, word)

    def test_readme_points_to_session_section(self):
        self.assertIn("`references/conductor-dispatch.md` 의 `## 세션 담당자`", README.read_text(encoding="utf-8"))

    def test_dependencies_text_section(self):
        text = (PLUGIN / "dependencies.md").read_text(encoding="utf-8")
        lines = text.split("\n")
        self.assertIn("## 권장 도구", lines)
        sec = text.split("\n## 권장 도구", 1)[1].split("\n## ", 1)[0]
        for word in ("herdr-core", "판을 재지 않는다", "하위 agent 길", "hc 0.1.21"):
            self.assertIn(word, sec, word)
        self.assertFalse([l for l in sec.split("\n") if l.startswith("|")])
        sys.path.insert(0, str(REPO / "shared" / "deps"))
        import check_deps  # noqa: E402
        names = {r["name"] for r in check_deps.read_table(PLUGIN / "dependencies.md")}
        self.assertEqual(names, {"python", "git", "gh", "superpowers", "quality-gates", "claude-code"})

    def test_changelog_has_session_workers_entry(self):
        entries = [body for ver, body in changelog_entries((PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")) if ver == (8, 31, 0)]
        self.assertEqual(len(entries), 1)
        for word in ("세션 담당자", "herdr-core", "conductor-dispatch.md"):
            self.assertIn(word, entries[0], word)


READ_WORDS = ("job_results.py", "job sync", "workflow_superpowers.py", "결과 받음", "로드맵 밖 과제")


class ReadSideVersion(unittest.TestCase):   # 판 글자를 못 박지 않는다(판정 R-R 의 꼴)
    def pick_entry(self, log):
        """(형식 쪽 판, 이 일의 판, 이 일의 절 글) — 이 일의 절은 형식 쪽 판(다섯 낱말 절)보다 뒤의 판 가운데 READ_WORDS 를
        모두 담은 가장 이른 판이다. 자리가 아니라 항목 안의 글로 고르므로 사이에 낀 남의 항목은 건너뛰고, 더 뒤의 판이
        같은 낱말을 함께 적어도 고르는 절이 바뀌지 않는다. 그런 절이 없으면 사유가 보이는 실패다."""
        entries = changelog_entries(log)
        first = [v for v, body in entries if all(w in body for w in WORDS)]
        self.assertEqual(len(first), 1, first)
        mine = sorted((v, body) for v, body in entries if v > first[0] and all(w in body for w in READ_WORDS))
        self.assertTrue(mine, "형식 쪽 판 뒤에 READ_WORDS 를 모두 담은 항목이 없다")
        return first[0], mine[0][0], mine[0][1]

    def read_entry(self):
        return self.pick_entry((PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8"))

    def test_entry_chosen_by_its_words(self):
        first, mine, body = self.read_entry()
        self.assertGreater(mine, first)   # 읽기 쪽 판이 형식 쪽 판 뒤다
        for w in READ_WORDS:
            self.assertIn(w, body, w)
        current = version_tuple(json.loads((PLUGIN / ".claude-plugin" / "plugin.json").read_text(encoding="utf-8"))["version"])
        self.assertGreaterEqual(current, mine)

    def test_a_later_entry_with_the_same_words_does_not_move_the_choice(self):   # 양성 대조 — 뒤 판이 같은 낱말을 함께 적어도
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        later = "# Changelog\n\n## [9.0.0] — 2026-12-01\n\n### Changed\n- %s 를 고쳤다\n" % " · ".join(READ_WORDS) + log.split("\n", 1)[1]
        self.assertEqual(self.pick_entry(later), self.read_entry())

    def test_an_entry_in_between_does_not_move_the_choice(self):   # 남의 항목이 형식 쪽 판과 이 일의 판 사이에 끼어도
        first, mine, _body = self.read_entry()
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        head = "## [%d.%d.%d]" % mine
        self.assertEqual(log.count(head), 1)
        between = "## [%d.%d.%d] — 2026-01-02\n\n### Added\n- 남의 일 하나\n\n" % (first[0], first[1], first[2] + 1)
        self.assertGreater((first[0], first[1], first[2] + 1), first)
        self.assertGreater(mine, (first[0], first[1], first[2] + 1))
        self.assertEqual(self.pick_entry(log.replace(head, between + head, 1)), self.read_entry())

    def test_an_entry_missing_a_word_is_not_chosen(self):   # 음성 대조 — 낱말마다, 이 일의 절에서 하나를 지우면 고르지 못한다
        first, mine, body = self.read_entry()
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        for w in READ_WORDS:
            broken = log.replace(body, body.replace(w, "x"), 1)
            self.assertNotEqual(broken, log, w)
            with self.assertRaises(AssertionError, msg=w):
                self.pick_entry(broken)

    def test_entry_carries_what_existing_repos_must_know(self):   # 이미 깐 레포가 손으로 맞출 줄 · 바뀐 동작
        _first, _mine, body = self.read_entry()
        added = [l for l in (PLUGIN / "templates" / "team" / "role-worker.md").read_text(encoding="utf-8").splitlines()
                 if "테스트 출력" in l]
        self.assertEqual(len(added), 1, added)
        self.assertIn(added[0], body)   # 틀에 더한 줄을 글자 그대로
        for words in ("`references/team-files.md` §3 의 글이 정본이다", "`--framing-audit` 없이 다시 불러도 멈추지 않는다",
                      "옛 형식 문서라도", "pr-record"):
            self.assertIn(words, body, words)


class RepoFiles(unittest.TestCase):   # R1 AC25 — devbrew 레포의 공통 문서
    def rd(self):
        import repo_defaults
        front = (REPO / repo_defaults.SETTINGS_FILE).read_text(encoding="utf-8").split("---")[1]   # 설정 파일의 머리
        self.assertNotIn("roadmaps_dir", [l.split(":")[0].strip() for l in front.splitlines()])   # 설정을 바꾸지 않았다
        return repo_defaults.ROADMAPS_DIR   # 기본값 상수

    def test_review_file_at_the_top(self):
        text = (REPO / L.REVIEW_FILE).read_text(encoding="utf-8")
        for part in ("테스트가 하나라도 실패", "실제로 돌려 보거나 화면을 봤을 때", "어디서 · 무엇이 · 어떤 기준에 걸렸는지 한 줄"):
            self.assertIn(part, text)

    def test_handbook_carries_the_principle(self):
        text = (REPO / L.handbook(self.rd())).read_text(encoding="utf-8")
        self.assertIn("잘못 쌓인 맥락은 없는 것보다 나쁘다. 이 파일의 줄은 쓰기 전에 지금 확인하고, 틀렸으면 지운다.", text)

    def test_four_role_docs_with_two_sections(self):
        for role in L.ROLES:
            lines = (REPO / L.role_doc(self.rd(), role)).read_text(encoding="utf-8").splitlines()
            self.assertEqual([l for l in lines if l.startswith("#")], ["## 할 일", "## 하지 않을 일"], role)
            self.assertIn("- 받은 규칙은 쓰기 전에 지금도 맞는지 확인한다.", lines, role)
            self.assertEqual(sorted(p.name for p in (REPO / self.rd() / role).iterdir()), [L.ROLE_DOC], role)   # 역할 폴더는 로드맵 폴더가 아니다


RULE_WORDS = ("team_rules.py", "start_bundle.py", "묶음 낡음", "REVIEW.md")


class RulesVersion(unittest.TestCase):   # 판 글자를 못 박지 않는다 — 읽기 쪽 항목보다 뒤의 판 가운데 가장 이른 것
    def test_entry_chosen_by_its_words(self):
        log = (PLUGIN / "CHANGELOG.md").read_text(encoding="utf-8")
        entries = changelog_entries(log)
        read_side = min(v for v, body in entries if all(w in body for w in READ_WORDS))
        mine = sorted(v for v, body in entries if v > read_side and all(w in body for w in RULE_WORDS))
        self.assertTrue(mine, "읽기 쪽 판 뒤에 RULE_WORDS 를 모두 담은 항목이 없다")
        body = dict(entries)[mine[0]]
        self.assertFalse(all(w in body for w in ("--layout team", "rules_budget", "handbook_budget", "job new", "종료 코드 4")))
        self.assertIn("이미 깐", body)   # 리더 틀이 바뀐 것을 이미 깐 레포가 손으로 맞춘다(U10 가일 때)
        for word in ("--layout team", "종료 코드 4"):   # 이 항목에는 두 낱말을 하나도 쓰지 않는다(위 단언은 다섯이 다 들 때만 걸린다)
            self.assertNotIn(word, body)


if __name__ == "__main__":
    unittest.main()
