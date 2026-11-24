#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""roadmap_draft_entry.py — 로드맵 잡기 진입 검사(F5 AC6 · AC7 · AC11).

Run (리포 루트에서): python3 plugins/spec-distill/tests/test_roadmap_draft_entry.py
"""
from __future__ import annotations

import hashlib
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[3]
SCRIPT = REPO / "plugins" / "spec-distill" / "scripts" / "roadmap_draft_entry.py"
sys.path.insert(0, str(Path(__file__).resolve().parent))
import raw_source_fixture as F  # noqa: E402

ROADMAP_REL = "docs/superpowers/roadmaps/2026-11-20-x/roadmap.md"
SPLIT_LINE = "분해됨 — " + ROADMAP_REL
PLAN_TABLE = ("## 분해안\n\n| 번호 | 이름 |\n|---|---|\n| E1 | 첫 에픽 |\n\n"
              "승인: 「이대로」\n")


def git(repo, *args):
    p = subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.invalid", "-c", "commit.gpgsign=false",
                        "-c", "core.hooksPath=/dev/null"] + list(args),
                       cwd=str(repo), capture_output=True, text=True, encoding="utf-8")
    if p.returncode != 0:
        raise AssertionError("git %s: %s" % (args, p.stderr))
    return p.stdout


def digest(root: Path) -> dict:
    return {str(p.relative_to(root)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(root.rglob("*")) if p.is_file() and ".git" not in p.relative_to(root).parts}


class Base(unittest.TestCase):
    def build(self, mode="no-framing", split=True, state_extra="\n## R1\n\n본문\n", settings="intent_dir: docs/iv/"):
        """픽스처 레포 — 결과물 묶음은 docs/iv 에 옛 꼴 이름으로 있다. settings 는 기본 브랜치의 레포 설정 머리말 줄들."""
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        r = F.make_repo(Path(self.tmp.name) / "repo", mode=mode)
        self.repo = Path(r["repo"])
        self.p = r
        if settings:
            (self.repo / ".devbrew.md").write_text("---\n%s\n---\n" % settings, encoding="utf-8")
            git(self.repo, "add", ".devbrew.md")
            git(self.repo, "commit", "-q", "-m", "settings")
        git(self.repo, "branch", "-M", "main")
        git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        git(self.repo, "symbolic-ref", "refs/remotes/origin/HEAD", "refs/remotes/origin/main")
        git(self.repo, "checkout", "-q", "-b", "feature/x")
        brief = Path(r["brief"])
        text = brief.read_text(encoding="utf-8")
        if split:
            assert text.count("## 7. Next Action\n") == 1
            text = text.replace("## 7. Next Action\n", "## 7. Next Action\n\n- `%s`\n" % SPLIT_LINE)
            brief.write_text(text, encoding="utf-8")
        state = Path(r["state"])
        state.write_text(state.read_text(encoding="utf-8").rstrip("\n") + "\n" + state_extra, encoding="utf-8")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "fixture 2")
        self.brief, self.audit, self.state = r["brief"], r["audit"], r["state"]

    def drop_from_head(self, path, staged=False):
        """HEAD 에서 파일을 뺀 커밋을 하나 더해 «커밋된 적 없는» 파일로 만든다(작업 트리엔 남는다). staged 면 다시 스테이지한다."""
        git(self.repo, "rm", "-q", "--cached", path)
        git(self.repo, "commit", "-q", "-m", "drop")
        if staged:
            git(self.repo, "add", path)

    def run_entry(self, brief=None, cwd=None):
        p = subprocess.run([sys.executable, str(SCRIPT), "--brief", brief or self.brief],
                           cwd=str(cwd or self.repo), capture_output=True, text=True, encoding="utf-8")
        return p.returncode, p.stdout, p.stderr

    def append(self, path, text):
        with open(path, "a", encoding="utf-8") as fh:
            fh.write(text)


class TestEntry(Base):
    def test_clean_split_brief_ok(self):
        self.build()
        rc, out, err = self.run_entry()
        lines = out.strip().split("\n")
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(lines[0], "raw-source: NO-FRAMING")
        self.assertEqual(lines[-1], "roadmap-entry: OK")
        self.assertEqual(len(lines), 2, out)

    def test_uncommitted_brief_stops(self):
        self.build()
        self.append(self.brief, "\n덧붙임\n")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 결과물에 커밋하지 않은 변경이 있다: ", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: STOP")

    def test_never_committed_audit_stops(self):
        self.build()
        self.drop_from_head(self.audit)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP audit 이 커밋된 적이 없다: ", out)

    def test_staged_never_committed_audit_stops(self):
        self.build()
        self.drop_from_head(self.audit, staged=True)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP audit 이 커밋된 적이 없다: ", out)

    def test_state_never_committed_stops(self):
        self.build()
        self.drop_from_head(self.state)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 상태 파일이 커밋된 적이 없다: ", out)

    def test_staged_never_committed_state_stops(self):
        self.build()
        self.drop_from_head(self.state, staged=True)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 상태 파일이 커밋된 적이 없다: ", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: STOP")

    def test_state_changed_outside_two_sections_stops(self):
        self.build()
        self.append(self.state, "R1 에 덧붙인 줄\n")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 상태 파일의 커밋 뒤 변경이 두 절 밖에 있다: ## R1\n", out)

    def test_state_changed_inside_two_sections_ok(self):
        self.build()
        self.append(self.state, "\n" + PLAN_TABLE + "\n## 생성 기록\n\n- 생성된 파일: a.md\n")
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)
        self.assertNotIn("STOP", out)
        self.assertIn("roadmap-entry: RESUME 분해안 표 · 생성 기록\n", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: RESUME")

    def test_plan_appended_without_blank_line_is_resume(self):
        # 마지막 절의 끝 줄바꿈 뒤에 `## 분해안` 을 빈 줄 없이 붙여도 앞 절은 한 글자도 바뀌지 않았다.
        self.build()
        self.append(self.state, PLAN_TABLE)
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)
        self.assertNotIn("STOP", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: RESUME")

    def test_crlf_committed_state_with_plan_is_resume(self):
        # CRLF 로 커밋된 상태 파일 — 작업 트리는 줄바꿈을 접어 읽으므로 HEAD 쪽과 꼴만 다르다.
        self.build()
        st = Path(self.state)
        st.write_bytes(st.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "crlf")
        with open(self.state, "ab") as fh:
            fh.write(("\r\n" + PLAN_TABLE).replace("\n", "\r\n").replace("\r\r\n", "\r\n").encode("utf-8"))
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)
        self.assertNotIn("STOP", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: RESUME")

    def test_crlf_committed_state_changed_outside_still_stops(self):
        # 양의 짝 — 줄바꿈 꼴을 접어도 두 절 밖의 실제 변경은 그대로 멈춘다.
        self.build()
        st = Path(self.state)
        st.write_bytes(st.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "crlf")
        with open(self.state, "ab") as fh:
            fh.write("R1 에 덧붙인 줄\r\n".encode("utf-8"))
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 상태 파일의 커밋 뒤 변경이 두 절 밖에 있다: ## R1\n", out)

    def test_committed_state_deleted_from_worktree_stops(self):
        self.build()
        os.remove(self.state)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1, out)
        self.assertIn("roadmap-entry: STOP 상태 파일이 커밋된 뒤 작업 트리에서 지워졌다: ", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: STOP")

    def test_resume_on_approved_table(self):
        self.build(state_extra="\n" + PLAN_TABLE)
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: RESUME")
        self.assertIn("분해안 표", out)

    def test_emptied_two_sections_are_not_resume(self):
        self.build(state_extra="\n## 분해안\n\n## 생성 기록\n\n")
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: OK")

    def test_raw_source_uncommitted_stops(self):
        self.build(mode="recorded")
        self.append(self.p["framing"], "\n덧붙임\n")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertTrue(out.startswith("raw-source: FOUND "), out)
        self.assertIn("roadmap-entry: STOP 원자료에 커밋하지 않은 변경이 있다: ", out)

    def test_raw_source_never_committed_stops(self):
        self.build(mode="recorded")
        self.drop_from_head(self.p["seed"], staged=True)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 원자료가 커밋된 적이 없다: ", out)

    def test_raw_source_lost_does_not_stop(self):
        self.build(mode="lost")
        # LOST 일 때 남아 있는 seed 에 변경이 있어도 원자료 사유는 더하지 않는다.
        self.append(self.p["seed"], "\n덧붙임\n")
        rc, out, err = self.run_entry()
        self.assertEqual(out.split("\n")[0].split(" ")[:2], ["raw-source:", "LOST"], out)
        self.assertNotIn("원자료", out)
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: OK")

    def test_no_split_line_stops(self):
        self.build(split=False)
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 결과물 §7 에 분해됨 줄이 없다 — 나눌지는 컨텍스트 쌓기에서 정한다\n", out)

    def test_roadmap_on_default_branch_stops(self):
        self.build()
        road = self.repo / ROADMAP_REL
        road.parent.mkdir(parents=True)
        road.write_text("# 로드맵\n", encoding="utf-8")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "roadmap")
        git(self.repo, "update-ref", "refs/remotes/origin/main", "HEAD")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 이 결과물의 로드맵이 이미 기본 브랜치에 있다: " + ROADMAP_REL, out)

    def test_no_origin_head_stops(self):
        self.build()
        git(self.repo, "symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 기본 브랜치를 확인하지 못했다: ", out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: STOP")

    def test_origin_head_dangling_stops(self):
        self.build()
        git(self.repo, "update-ref", "-d", "refs/remotes/origin/main")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 기본 브랜치를 확인하지 못했다: ", out)

    def test_default_branch_failure_carries_stderr_hint(self):
        self.build()
        git(self.repo, "symbolic-ref", "--delete", "refs/remotes/origin/HEAD")
        rc, out, _ = self.run_entry()
        stop = [ln for ln in out.split("\n") if ln.startswith("roadmap-entry: STOP 기본 브랜치를 확인하지 못했다: ")]
        self.assertEqual(len(stop), 1, out)
        # repo_defaults.py 가 stderr 첫 줄에 싣는 사유가 STOP 줄에 함께 실린다
        self.assertIn(" — ", stop[0], stop[0])
        self.assertGreater(len(stop[0].split(" — ", 1)[1].strip()), 5, stop[0])

    def test_roadmap_only_on_branch_is_ok(self):
        self.build()
        road = self.repo / ROADMAP_REL
        road.parent.mkdir(parents=True)
        road.write_text("# 로드맵\n", encoding="utf-8")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "roadmap")
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)

    def test_brief_risk_defect_stops(self):
        self.build()
        brief = Path(self.brief)
        text = brief.read_text(encoding="utf-8")
        old = "- 위험 — 숨은 가정 |"
        self.assertEqual(text.count(old), 1)
        brief.write_text(text.replace(old, "- 위험 K1 — 숨은 가정 |"), encoding="utf-8")
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "risk")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        self.assertIn("roadmap-entry: STOP 결과물의 위험 줄 번호가 생성기 검사에 걸린다: brief §5", out)

    def test_unreadable_audit_states_read_failure(self):
        self.build()
        Path(self.audit).unlink()
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1, out)
        self.assertIn("roadmap-entry: STOP 결과물이나 audit 을 읽지 못했다: ", out)
        self.assertNotIn("위험 줄 번호", out)

    def test_all_reasons_listed(self):
        self.build(split=False)
        self.append(self.brief, "\n덧붙임\n")
        rc, out, _ = self.run_entry()
        self.assertEqual(rc, 1)
        stops = [ln for ln in out.split("\n") if ln.startswith("roadmap-entry: STOP ")]
        self.assertEqual(len(stops), 2, out)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: STOP")
        self.assertEqual(out.split("\n")[0], "raw-source: NO-FRAMING")

    def test_relative_brief_path_from_subdir(self):
        self.build()
        base = self.run_entry()
        sub = self.repo / "docs"
        rel = os.path.relpath(self.brief, sub)
        self.assertEqual(self.run_entry(brief=rel, cwd=sub), base)
        self.assertEqual(self.run_entry(cwd=Path(self.tmp.name)), base)

    def test_writes_nothing(self):
        self.build(mode="recorded")
        self.append(self.state, "R1 에 덧붙인 줄\n")
        self.append(self.brief, "\n덧붙임\n")
        before = (git(self.repo, "status", "--porcelain"), digest(self.repo))
        self.run_entry()
        after = (git(self.repo, "status", "--porcelain"), digest(self.repo))
        self.assertEqual(before, after)

    # ── 결과물이 의도 폴더 바로 아래인가 — 커밋 펜스가 늦게 거는 같은 판정을 진입에서 먼저 본다 ──
    INTENT_STOP = "roadmap-entry: STOP 결과물이 의도 폴더 바로 아래가 아니다: "

    def copy_set(self, folder, stem):
        """결과물 · audit · 상태 파일을 <folder>/<stem>{.md,.audit.md,.state.md} 로 옮겨 커밋하고 새 결과물 경로를 돌려준다."""
        dest = self.repo / folder
        dest.mkdir(parents=True, exist_ok=True)
        for src, tail in ((self.brief, ".md"), (self.audit, ".audit.md"), (self.state, ".state.md")):
            (dest / (stem + tail)).write_bytes(Path(src).read_bytes())
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", "moved set")
        return str(dest / (stem + ".md"))

    def intent_stops(self, out):
        return [ln for ln in out.split("\n") if ln.startswith(self.INTENT_STOP)]

    def test_brief_outside_intent_folder_stops(self):
        self.build()
        other = self.copy_set("docs/other", "t-brief-interview")
        rc, out, err = self.run_entry(brief=other)
        self.assertEqual(rc, 1, out + err)
        stops = self.intent_stops(out)
        self.assertEqual(len(stops), 1, out)
        # 사유는 해결자의 마지막 [spec-distill] 줄(거절 사유)이고 「값의 출처」 줄이 아니다
        reason = stops[0][len(self.INTENT_STOP):]
        self.assertTrue(reason.startswith("부모 폴더가 다르다: docs/other/t-brief-interview.md 의 부모는 docs/other/ "
                                          "인데 정해진 폴더는 docs/iv/ 다(intent_dir)"), reason)
        self.assertNotIn("값의 출처", out)
        self.assertNotIn("[spec-distill]", stops[0])
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: STOP")

    def test_brief_in_intent_folder_has_no_intent_stop(self):
        self.build()
        rc, out, err = self.run_entry()
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(self.intent_stops(out), [], out)

    def test_old_form_brief_in_old_folder_ok(self):
        # 두 폴더가 다르다(새 폴더 docs/new/, 옛 폴더 docs/iv/) — 옛 폴더의 옛 꼴 결과물(커밋됨)은 받는다
        self.build(settings="intent_dir: docs/new/\ninterview_dir: docs/iv/")
        rc, out, err = self.run_entry()
        self.assertEqual(self.intent_stops(out), [], out)
        self.assertEqual(rc, 0, out + err)
        self.assertEqual(out.strip().split("\n")[-1], "roadmap-entry: OK")

    def test_new_form_brief_in_old_folder_stops(self):
        # 같은 두 폴더 — 옛 폴더의 새 꼴 이름은 받지 않고, 사유가 옛 폴더 규칙을 댄다
        self.build(settings="intent_dir: docs/new/\ninterview_dir: docs/iv/")
        moved = self.copy_set("docs/iv", "t-brief-context")
        rc, out, err = self.run_entry(brief=moved)
        self.assertEqual(rc, 1, out + err)
        stops = self.intent_stops(out)
        self.assertEqual(len(stops), 1, out)
        self.assertIn("정해진 폴더는 docs/new/ 다(intent_dir)", stops[0])
        self.assertIn("옛 의도 폴더(docs/iv/)는 옛 꼴 이름", stops[0])

    def test_bad_args_rc2(self):
        p = subprocess.run([sys.executable, str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2)
        p = subprocess.run([sys.executable, str(SCRIPT), "--brief", "/nonexistent/x.md"], capture_output=True, text=True)
        self.assertEqual(p.returncode, 2)


if __name__ == "__main__":
    unittest.main()
