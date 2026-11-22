#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_write.py check — 파일을 쓰지 않는 검증 길(F5 AC8 · AC39).

Run (리포 루트에서): python3 plugins/spec-distill/tests/test_roadmap_write_check.py
"""
from __future__ import annotations

import hashlib
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPTS = REPO / "plugins" / "spec-distill" / "scripts"
sys.path.insert(0, str(SCRIPTS))
import roadmap_write as W  # noqa: E402

RW = SCRIPTS / "roadmap_write.py"
RS = SCRIPTS / "roadmap_status.py"

BRIEF = """---
type: interview-brief
user_sourced_items:
  - id: C1
    statement: "첫 확정"
  - id: D2
    statement: "둘째 확정"
  - id: C3
    statement: "셋째 확정"
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
- 🗣 confirmed **C3** — 셋째 확정 ⟨S1⟩

## 3. Open Questions

- OQ1: 열린 하나

## 4. External Landscape

- 바깥 하나 «ext-a» — [취함] [→ OQ1]
- 바깥 둘 «ext-b» — [중립] [→ 없음]

## 5. 기각 · Blind Spots

- 기각 — 다른 길 — verdict: kept — ST1 — 부착 2/2
{RISKS}
- 위험 — 사실 | 사실 하나 — RC1 (a/b.py) [RC1 → OQ1]

## 6. 사용자 원문

- **S1** 🗣 최초 요청:
  > 처음 말

## 7. Next Action

다음.
"""
RISKS_BARE = "- 위험 — 숨은 가정: 가정 — 근거 약함\n- 위험 — 실패 양식: 실패 — 근거 약함"
RISKS_MIXED = "- 위험 K1 — 숨은 가정: 가정 — 근거 약함\n- 위험 — 실패 양식: 실패 — 근거 약함"
RISKS_DUP = "- 위험 K2 — 숨은 가정: 가정 — 근거 약함\n- 위험 K2 — 실패 양식: 실패 — 근거 약함"

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
E1 = ("| E1 | 첫 에픽 | 묶음 | 첫 의도 | 한다 가 / 안 한다 나 | P1 | feature/e1 | a/x.py | "
      "C1 · D2 · OQ1 · RC1 · K1 · «ext-a» · S1 · S2 | 없음 | E2 에 x |")
E2 = ("| E2 | 둘째 에픽 | 묶음 | 둘째 의도 | 한다 다 / 안 한다 라 | E1 | feature/e2 | 없음 | "
      "C3 · ST1 · K2 · «ext-b» · S1 | E1 의 x | 없음 |")


def table(*rows):
    return "# state\n\n## 분해안\n\n%s\n%s\n%s\n" % (HEAD, SEP, "\n".join(rows))


def brief(risks=RISKS_BARE):
    return BRIEF.replace("{RISKS}", risks)


TABLE_ALL = table(P1, E1, E2)
# C3 를 빼 미배정 1 · S2 를 빼 고아 1 · C99 를 더해 모르는 번호 1
TABLE_MISSING = table(P1, E1.replace(" · S2 |", " |"), E2.replace("C3 · ", "C99 · "))


def digest(root: Path) -> dict:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file()}


class Base(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.dir = Path(self.tmp.name)

    def run_check(self, brief_text, audit_text, table_text):
        b, a = self.dir / "brief.md", self.dir / "brief.audit.md"
        b.write_text(brief_text, encoding="utf-8")
        a.write_text(audit_text, encoding="utf-8")
        cmd = [sys.executable, str(RW), "check", "--brief", str(b), "--audit", str(a)]
        if table_text is not None:
            t = self.dir / "state.md"
            t.write_text(table_text, encoding="utf-8")
            cmd += ["--plan-table", str(t)]
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", env=env)
        return p.returncode, p.stdout


class Check(Base):
    def test_risk_ok_and_table_ok(self):
        rc, out = self.run_check(brief(), AUDIT, TABLE_ALL)
        self.assertEqual(rc, 0, out)
        self.assertEqual(out.splitlines()[0], "brief-risk: OK")
        self.assertEqual(out.splitlines()[1], "roadmap-table: OK 미배정 0 · 고아 0 · 모르는 번호 0")
        self.assertEqual(len(out.splitlines()), 2)

    def test_unassigned_and_orphan_counted(self):
        rc, out = self.run_check(brief(), AUDIT, TABLE_MISSING)
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-table: FAIL 미배정 1 · 고아 1 · 모르는 번호 1", out)
        self.assertIn("  미배정: C3", out)
        self.assertIn("  고아: S2", out)
        self.assertIn("  모르는 번호: C99", out)

    def test_empty_lists_are_not_printed(self):
        rc, out = self.run_check(brief(), AUDIT, table(P1, E1, E2.replace("C3 · ", "")))
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-table: FAIL 미배정 1 · 고아 0 · 모르는 번호 0", out)
        self.assertIn("  미배정: C3", out)
        self.assertNotIn("  고아:", out)
        self.assertNotIn("  모르는 번호:", out)

    def test_risk_mixed_numbers_fail(self):
        rc, out = self.run_check(brief(RISKS_MIXED), AUDIT, None)
        self.assertEqual(rc, 1)
        self.assertTrue(out.startswith("brief-risk: FAIL brief §5 위험 줄 가운데 K 번호가 없는 줄이 있다"), out)

    def test_risk_duplicate_fail(self):
        rc, out = self.run_check(brief(RISKS_DUP), AUDIT, None)
        self.assertEqual(rc, 1)
        self.assertIn("brief-risk: FAIL brief §5 위험 줄의 K 번호가 겹친다: K2", out)

    def test_no_table_prints_only_risk_line(self):
        rc, out = self.run_check(brief(), AUDIT, None)
        self.assertEqual(rc, 0)
        self.assertEqual(out.strip().splitlines(), ["brief-risk: OK"])

    def test_risk_fail_with_table_still_reports_table_unknown(self):
        rc, out = self.run_check(brief(RISKS_MIXED), AUDIT, TABLE_ALL)
        self.assertEqual(rc, 1)
        lines = out.splitlines()
        self.assertTrue(lines[0].startswith("brief-risk: FAIL "))
        self.assertTrue(lines[1].startswith("roadmap-table: UNKNOWN "), out)

    def test_unreadable_table_unknown(self):
        rc, out = self.run_check(brief(), AUDIT, "# state\n\n표가 없다\n")
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-table: UNKNOWN `## 분해안` 절이 없다", out)

    def test_usage_error_rc2(self):
        p = subprocess.run([sys.executable, str(RW), "check", "--brief", "x"], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2)

    def test_writes_nothing(self):
        b, a, t = self.dir / "brief.md", self.dir / "brief.audit.md", self.dir / "state.md"
        b.write_text(brief(), encoding="utf-8")
        a.write_text(AUDIT, encoding="utf-8")
        t.write_text(TABLE_MISSING, encoding="utf-8")
        before = digest(self.dir)
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")
        subprocess.run([sys.executable, str(RW), "check", "--brief", str(b), "--audit", str(a),
                        "--plan-table", str(t)], capture_output=True, text=True, env=env)
        self.assertEqual(digest(self.dir), before)
        self.assertNotIn("## 생성 기록", t.read_text(encoding="utf-8"))

    def test_check_counts_sorted(self):
        counts = W.check_counts(brief(), AUDIT, table(P1, E1.replace(" · S2 |", " |"),
                                                      E2.replace("C3 · ", "C100 · C99 · ")))
        self.assertEqual(counts["unassigned"], ["C3"])
        self.assertEqual(counts["orphans"], ["S2"])
        self.assertEqual(counts["unknown_ids"], ["C99", "C100"])   # 숫자 순 — 글자 순이면 C100 이 앞선다


class MatchesRoadmapStatus(Base):
    """같은 입력으로 create 뒤 roadmap_status --json 의 세 목록과 check_counts 가 같다."""

    def git(self, *args, cwd=None):
        env = dict(os.environ, GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        return subprocess.run(["git", "-C", str(cwd or self.repo), "-c", "user.name=t", "-c", "user.email=t@e.invalid",
                               "-c", "commit.gpgsign=false", *args], capture_output=True, text=True, env=env,
                              check=True)

    def test_counts_match_roadmap_status_after_create(self):
        self.repo = self.dir / "repo"
        origin = self.dir / "origin.git"
        (self.repo / "docs" / "iv").mkdir(parents=True)
        (self.repo / "docs" / "iv" / "brief.md").write_text(brief(), encoding="utf-8")
        (self.repo / "docs" / "iv" / "brief.audit.md").write_text(AUDIT, encoding="utf-8")
        subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(origin)], check=True)
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.repo)], check=True)
        self.git("remote", "add", "origin", str(origin))
        self.git("add", "--", "docs")
        self.git("commit", "-qm", "brief")
        self.git("push", "-q", "origin", "main")
        self.git("fetch", "-q", "origin")
        self.git("remote", "set-head", "origin", "main")
        state = self.dir / "state.md"
        state.write_text(TABLE_ALL, encoding="utf-8")
        env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")
        p = subprocess.run([sys.executable, str(RW), "create", "--brief", "docs/iv/brief.md", "--audit",
                            "docs/iv/brief.audit.md", "--plan-table", str(state), "--out", "docs/rm", "--title", "t",
                            "--date", "2026-10-15", "--approval", "승인"], cwd=self.repo, capture_output=True,
                           text=True, env=env)
        self.assertEqual(p.returncode, 0, p.stdout + p.stderr)

        def status():
            q = subprocess.run([sys.executable, str(RS), "--roadmap-file", "docs/rm/roadmap.md", "--json"],
                               cwd=self.repo, capture_output=True, text=True, env=env)
            return json.loads(q.stdout)

        def counts():
            extracted = subprocess.run([sys.executable, str(RW), "extract", "--roadmap", "docs/rm/roadmap.md"],
                                       cwd=self.repo, capture_output=True, text=True, env=env, encoding="utf-8")
            return W.check_counts(brief(), AUDIT, extracted.stdout)

        keys = (("unassigned", "unassigned"), ("orphans", "orphans"), ("unknown_ids", "unknown_ids"))
        clean = status()
        self.assertEqual({k: clean[s] for k, s in keys}, counts())
        self.assertEqual(counts(), {"unassigned": [], "orphans": [], "unknown_ids": []})
        # 묶음 E2 에서 번호 둘을 빼고(C3 미배정 · S1 은 E1 이 가져 그대로) 모르는 번호 하나를 더한다
        e2 = self.repo / "docs" / "rm" / "E2.md"
        text = e2.read_text(encoding="utf-8")
        self.assertIn("C3", text)
        e2.write_text(text.replace("C3, ", "C99, ", 1), encoding="utf-8")
        drift = status()
        self.assertEqual(drift["unassigned"], ["C3"])
        self.assertEqual(drift["unknown_ids"], ["C99"])
        self.assertEqual({k: drift[s] for k, s in keys}, counts())


if __name__ == "__main__":
    unittest.main()
