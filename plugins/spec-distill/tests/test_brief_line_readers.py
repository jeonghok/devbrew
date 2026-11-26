#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""brief §5 · §4 의 번호를 세는 쪽(`brief_universe`)과 줄을 찾는 쪽(`index_brief`)이 같은 번호를 읽는다.

Run (리포 루트에서): python3 -m unittest plugins/spec-distill/tests/test_brief_line_readers.py
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import roadmap_model as M  # noqa: E402
import roadmap_render as R  # noqa: E402

RW = SCRIPTS / "roadmap_write.py"

# §5 의 줄 꼴 — 괄호 꼴 · 연결로만 · 괄호 없는 본문 인용 · 한 줄에 번호 둘 · 복수 연결 · 닿는 결정 없음 · ST 가 「 — STn — 」 꼴이 아님.
S5_LINES = [
    "- 기각 — 다른 길 — verdict: kept — ST1 — 부착 2/2",
    "- 위험 — 숨은 가정: 가정 — 근거 약함",
    "- 위험 — 실패 양식: 실패 — 근거 약함",
    "- 위험 — 사실 | 고칠 자리 — RC1 (a/b.py) [RC1 → OQ1]",
    "- 위험 — 사실 | 연결에만 번호가 있다 [RC2 → OQ1]",
    "- 기각 — 원래 / 재결정 / 근거 RC3 반증 [RC3 → 없음]",
    "- 기각 — 한 줄에 둘 — RC4 와 RC5 가 함께 [RC4 → OQ1 · OQ2]",
    "- 기각 — 복수 연결 [RC6 → OQ1 · OQ2]",
    "- 기각 — a / b / c 가 ST2 에 기댄다 [→ 없음]",
    "- 기각 — RC1 이 뒤에도 나온다 [RC1 → OQ2]",
]
RC_ALL = ["RC%d" % n for n in range(1, 7)]

BRIEF = """---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "첫 확정"
  - id: D2
    statement: "둘째 확정"
---

# 픽스처 brief

## 0. 한눈에

**결정 목록**

- OQ1 [열림] — 열린 하나
- OQ2 [해결 ⟨S2⟩] — 닫힌 하나

## 1. Goal · Non-goal

- Goal: 픽스처 목표.
- Non-goal: 픽스처 비목표.

## 2. 제약

- 🗣 confirmed **C1** — 첫 확정 ⟨S1⟩
- ☑ confirmed **D2** — 둘째 확정 ⟨S2⟩

## 3. Open Questions

- OQ1: 열린 하나

## 4. External Landscape

- 바깥 하나 «ext-a» — [취함] [→ OQ1]
- 바깥 둘 «ext-b» — [중립] [→ 없음]
- 본문에만 있는 키
  - 안쪽 «ext-c» 와 RC7 인용 [→ 없음]
- 머리에 번호가 있는 항목 «ext-d» — RC9 (z.py) [취함] [→ 없음]

## 5. 기각 · Blind Spots

%s

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 말

## 7. Next Action

다음.
""" % "\n".join(S5_LINES)
AUDIT = """# audit

## 6. 사용자 원문

- **S2** 🗣 발화 (round 1):
  > 둘째 말
- **S3** ☑ 선택 (round 2):
  > 셋째 말

## 7. 기타

- 없음
"""
HEAD = "| 번호 | 이름 | 종류 | 의도 | 범위 | 의존 | 브랜치 | 경로 예약 | 배정 번호 | 받는 것 | 넘기는 것 |"
SEP = "|---|---|---|---|---|---|---|---|---|---|---|"
P1 = "| P1 | 결정 하나 | 결정 | 무엇을 정한다 | 한다 결정 / 안 한다 코드 | 없음 | 없음 | 없음 | S3 · OQ2 | 없음 | 없음 |"


def swap_s5(extra):
    return BRIEF.replace("\n".join(S5_LINES), "\n".join(S5_LINES + list(extra)))


class Invariant(unittest.TestCase):
    """세는 쪽과 줄을 찾는 쪽이 같은 번호를 읽는다 — 센 번호는 모두 줄을 얻고, 줄을 얻은 번호는 모두 센 번호다."""

    def check(self, brief):
        non_s, _s, _k = M.brief_universe(brief, AUDIT)
        idx = R.index_brief(brief, AUDIT)
        counted = {n for n in non_s if re.fullmatch(r"(?:RC|ST)\d+", n)}
        cited = set(idx.s5)
        self.assertEqual(sorted(counted - cited - set(idx.lines)), [], "센 번호가 줄을 못 얻었다")
        self.assertEqual(sorted(cited - counted), [], "센 적 없는 번호가 줄을 얻었다")
        for n, lines in idx.s5.items():
            for line in lines:
                self.assertRegex(line, r"\b%s\b" % n)
        return idx

    def test_task_shapes(self):
        idx = self.check(BRIEF)
        for n in RC_ALL + ["ST1", "ST2"]:
            self.assertIn(n, idx.s5)

    def test_shapes_outside_the_convention(self):
        extras = ["- 기각 — a, RC10, b 처럼 쉼표 사이", "- 기각 — RC11으로 시작하지 않는 붙임", "- 기각 — 끝에 RC12", "- 기각 — [RC13 → OQ1] 앞에",
                  "- 기각 — (RC14) 괄호 안", "- 기각 — RC15/RC16 슬래시", "- 기각 — ST7 와 RC17 와 ST8", "- 기각 — XRC18 은 번호가 아니다",
                  "- 기각 — RC19 RC19 두 번", "  - 들여쓴 줄 RC20", "- 기각 — `RC21` 코드 안", "- 기각 — RC22\u00a0NBSP"]
        for extra in extras:
            with self.subTest(extra):
                self.check(swap_s5([extra]))

    def test_number_on_several_lines_points_at_all_of_them_in_brief_order(self):
        more = ["- 기각 — 첫째 RC1 도 (z.py) [RC1 → OQ1]", "- 기각 — 근거 RC2 반증"]
        idx = self.check(swap_s5(more))
        self.assertEqual(idx.s5["RC1"], [S5_LINES[3], S5_LINES[9], more[0]])
        self.assertEqual(idx.s5["RC2"], [S5_LINES[4], more[1]])

    def test_line_with_two_numbers_is_listed_under_both(self):
        idx = self.check(BRIEF)
        self.assertEqual(idx.s5["RC4"], [S5_LINES[6]])
        self.assertEqual(idx.s5["RC5"], [S5_LINES[6]])

    def test_line_is_cut_like_the_rest_of_the_brief_readers(self):
        idx = self.check(swap_s5(["- 기각 — 줄 나눔 글자\u2028RC23 이 줄 안에 남는다"]))
        self.assertEqual(idx.s5["RC23"], ["- 기각 — 줄 나눔 글자\u2028RC23 이 줄 안에 남는다"])

    def test_section4_counted_equals_indexed(self):
        s4 = M.section4_items(M.brief_section(BRIEF, "4"))
        counted = {k for head, body in s4 for k in M.KEY_RE.findall("\n".join([head] + body))}
        counted |= {rc for head, _b in s4 for rc in M.RC_RE.findall(head)}
        indexed = set(R._section4_index(BRIEF))
        self.assertEqual(counted, indexed)

    def test_bundle_parts_lists_each_cited_line_once_in_brief_order(self):
        more = ["- 기각 — 첫째 RC1 도 (z.py) [RC1 → OQ1]"]
        idx = R.index_brief(swap_s5(more), AUDIT)
        row = R.parse_table("# s\n\n## 분해안\n\n%s\n%s\n%s\n" % (HEAD, SEP, "| E1 | 이름 | 묶음 | 의도 | 한다 가 / 안 한다 나 | 없음 | feature/e1 | 없음 | RC1 · RC4 · RC5 · ST1 | 없음 | 없음 |"))[0]
        _ids, parts = R.bundle_parts(row, idx)
        rest = parts[R.team_files.SOURCE_PARTS[3]]
        self.assertEqual(rest, [S5_LINES[3], S5_LINES[9], more[0], S5_LINES[6], S5_LINES[0]])


def git(top, *args):
    return subprocess.run(["git", "-C", str(top), "-c", "user.name=t", "-c", "user.email=t@example.invalid",
                           "-c", "commit.gpgsign=false", *args], check=True, capture_output=True, text=True)


def run_create(top, *args):
    env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
    return subprocess.run([sys.executable, str(RW), "create", *args], cwd=str(top), env=env,
                          capture_output=True, text=True)


class Create(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self._tmp.cleanup)
        self.tmp = Path(self._tmp.name)
        self.top = self.tmp / "repo"
        (self.top / "docs" / "iv").mkdir(parents=True)
        (self.top / "docs" / "iv" / "brief.md").write_text(BRIEF, encoding="utf-8")
        (self.top / "docs" / "iv" / "brief.audit.md").write_text(AUDIT, encoding="utf-8")
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(self.tmp / "origin.git")], check=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.top)], check=True)
        git(self.top, "remote", "add", "origin", str(self.tmp / "origin.git"))
        git(self.top, "add", "--", "docs")
        git(self.top, "commit", "-qm", "brief")
        git(self.top, "push", "-q", "origin", "main")
        git(self.top, "fetch", "-q", "origin")
        git(self.top, "remote", "set-head", "origin", "main")

    def rows(self):
        e1 = ("| E1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/e1 | a/x.py | "
              "C1 · OQ1 · RC1 · RC2 · RC4 · RC5 · K1 · «ext-a» · S1 · S2 | 없음 | E2 에 x |")
        e2 = ("| E2 | 둘째 에픽 | 묶음 | 둘째 의도 | 한다 다 / 안 한다 라 | E1 | feature/e2 | 없음 | "
              "D2 · RC3 · RC6 · ST1 · ST2 · K2 · «ext-b» · «ext-c» · «ext-d» · RC9 · S1 | E1 의 x | 없음 |")
        return [P1, e1, e2]

    def create(self):
        table = self.tmp / "state.md"
        table.write_text("# state\n\n## 분해안\n\n%s\n%s\n%s\n" % (HEAD, SEP, "\n".join(self.rows())), encoding="utf-8")
        return run_create(self.top, "--brief", "docs/iv/brief.md", "--audit", "docs/iv/brief.audit.md",
                          "--plan-table", str(table), "--out", "docs/rm", "--title", "픽스처 일",
                          "--date", "2026-11-26", "--approval", "이대로 승인")

    def test_old_layout_creates_and_bundles_carry_the_lines(self):
        r = self.create()
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        e1 = (self.top / "docs/rm/E1.md").read_text(encoding="utf-8")
        e2 = (self.top / "docs/rm/E2.md").read_text(encoding="utf-8")
        for line in (S5_LINES[3], S5_LINES[4], S5_LINES[6], S5_LINES[9]):
            self.assertEqual(e1.count(line), 1)
        for line in (S5_LINES[0], S5_LINES[5], S5_LINES[7], S5_LINES[8]):
            self.assertIn(line, e2)
        self.assertIn("«ext-d»", e2)
        self.assertEqual(e1.count(S5_LINES[6]), 1, "한 줄에 번호 둘 — 그 줄은 묶음에 한 번만")

    def test_team_layout_creates_and_sources_carry_the_lines(self):
        out = "docs/superpowers/roadmaps/tm"
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        o = subprocess.run([sys.executable, str(RW), "original", "--brief", "docs/iv/brief.md", "--out", out],
                           cwd=str(self.top), env=env, capture_output=True, text=True)
        self.assertEqual(o.returncode, 0, o.stdout + o.stderr)
        git(self.top, "add", "--", out)
        git(self.top, "commit", "-qm", "원자료 사본")
        head = HEAD + " 지시 원문 범위 |"
        rows = [P1 + " 없음 |"] + [r + " 2–4 |" for r in self.rows()[1:]]
        table = self.tmp / "tm-table.md"
        table.write_text("# state\n\n## 분해안\n\n%s\n%s---|\n%s\n" % (head, SEP, "\n".join(rows)), encoding="utf-8")
        r = run_create(self.top, "--layout", "team", "--brief", "docs/iv/brief.md", "--audit", "docs/iv/brief.audit.md",
                       "--plan-table", str(table), "--out", out, "--title", "픽스처 일", "--date", "2026-11-26",
                       "--approval", "이대로 승인")
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        sources = {p.parent.name: p.read_text(encoding="utf-8") for p in (self.top / out).rglob("sources.md")}
        self.assertEqual(sorted(sources), ["E1", "E2"])
        for line in (S5_LINES[3], S5_LINES[4], S5_LINES[6], S5_LINES[9]):
            self.assertEqual(sources["E1"].count(line), 1)
        for line in (S5_LINES[0], S5_LINES[5], S5_LINES[7], S5_LINES[8]):
            self.assertIn(line, sources["E2"])
        self.assertEqual(sources["E1"].count(S5_LINES[6]), 1)


if __name__ == "__main__":
    unittest.main()
