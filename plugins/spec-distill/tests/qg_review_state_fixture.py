#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""리뷰 상태 테스트의 도우미 — 임시 리포 · 기계 상태 · 보관 폴더 · qg 결과 파일을 짓는다.

`Rig(testcase)` 는 바탕 클래스가 아니다 — 테스트의 `setUp` 에서 `self.rig = Rig(self)` 로 만들고,
치우기는 `testcase.addCleanup` 으로 건다. 리포는 기본 브랜치 `trunk-x` 위에 첫 커밋 하나를 두고
리뷰받는 브랜치 `feature/a1` 로 옮겨 있다. 기계 상태는 `conductor_ledger.py claim` 으로 만든다.
"""
from __future__ import annotations

import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest import mock

TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parent / "scripts"
sys.path.insert(0, str(SCRIPTS))
import conductor_ledger as L  # noqa: E402

SCRIPT = SCRIPTS / "qg_review_state.py"
GIT_ENV = {"GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "GIT_TERMINAL_PROMPT": "0"}
BASE = "trunk-x"
HEAD = "feature/a1"
EPIC = "A1"
SESSION = "session-aaaa1111"
ROADMAP = "docs/superpowers/roadmaps/rm/roadmap.md"
ROADMAP_TEXT = (
    "---\ntype: roadmap\nsource_brief: b.md\n---\n\n# r\n\n## 에픽\n\n"
    "### A1 — 가\n- 의도: 가\n- 범위:\n  - 한다: x\n  - 안 한다: y\n- 의존: 없음\n"
    "- 브랜치: feature/a1\n- 묶음: A1.md\n- 경로 예약: 없음\n\n"
    "## 결정 기록\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n")
INTENT_LEAD = ("intent-critic 은 의도대로 만들었는지가 아니라 의도 자체(사용자가 고른 방향 · 기능 · "
               "동작)가 맞는지를 점검한다. 이 절은 판정에 들지 않는다.")
RETURN_KEYS = ("contract", "status", "reason", "reason_text", "outcome", "result_line", "none_reason",
               "mode", "reviewed_head", "reviewed_base", "session_dir", "answers_dir",
               "answers_dir_source", "commit", "breadth", "other_teams", "overlaps",
               "answered_filtered")
QUESTION_KEYS = ("n", "id", "state", "answer", "answer_text", "wrong_choice", "failure", "file",
                 "evidence", "question", "target_source", "target_id", "label", "quote",
                 "observation", "why", "asked_before", "changed_observation")
HANDLING_HEAD = "## 지적마다의 처리"


PLAIN_KEYS = ("status", "reason", "outcome", "mode", "reviewed_head", "reviewed_base", "answers_dir",
              "answers_dir_source", "commit", "breadth", "other_teams", "state")
_PLAIN_BAD_START = "-?:,[]{}#&*!|>'\"%@` 0123456789.+~"
_YAML_WORDS = ("true", "false", "null", "yes", "no", "on", "off", "y", "n")


def _q(value) -> str:
    """글 칸 — 큰따옴표로 싼 한 줄(JSON 문자열은 YAML 로도 읽힌다). 없음은 `"-"`."""
    return json.dumps("-" if value in (None, "") else str(value), ensure_ascii=False)


def _scalar(value) -> str:
    """닫힌 어휘 칸 — qg 의 `_scalar` 처럼 글자 그대로 읽히는 글은 따옴표 없이, 아니면 싼다."""
    text = "-" if value in (None, "") else str(value)
    plain = (text[0] not in _PLAIN_BAD_START and ": " not in text and " #" not in text
             and "\n" not in text and not text.endswith((" ", ":")) and text.lower() not in _YAML_WORDS)
    return text if plain else json.dumps(text, ensure_ascii=False)


class Rig:
    """임시 리포 하나와 그 기계 상태. 속성: `t` · `repo` · `roadmap` · `session` · `epic` · `base` ·
    `head` · `machine` · `report_root`."""

    def __init__(self, testcase):
        self.tc = testcase
        patcher = mock.patch.dict(os.environ, GIT_ENV)
        patcher.start()
        testcase.addCleanup(patcher.stop)
        self.t = Path(tempfile.mkdtemp()).resolve()
        testcase.addCleanup(shutil.rmtree, str(self.t), True)
        self.repo = self.t / "repo"
        self.repo.mkdir()
        self.roadmap, self.session, self.epic = ROADMAP, SESSION, EPIC
        self.base, self.head = BASE, HEAD
        self._n = 0
        self.git("init", "-q", "-b", BASE)
        for key, value in (("user.name", "t"), ("user.email", "t@example.com"),
                           ("commit.gpgsign", "false")):
            self.git("config", key, value)
        self.commit({ROADMAP: ROADMAP_TEXT, "src/a.py": "a = 1\n"}, "base")
        self.git("checkout", "-q", "-b", HEAD)
        rc, out = self.ledger("claim", "--roadmap", ROADMAP, "--session", SESSION)
        if rc != 0:
            raise AssertionError("claim → %d: %s" % (rc, out))
        self.machine = L.mpath(self.repo, ROADMAP)
        self.report_root = self.machine.parent / "files" / "report"

    # ------------------------------------------------------------ git

    def git(self, *args, check: bool = True) -> str:
        p = subprocess.run(["git", *args], cwd=str(self.repo), env=dict(os.environ, **GIT_ENV),
                           capture_output=True, encoding="utf-8")
        if check and p.returncode:
            raise AssertionError("git %s → %d: %s" % (" ".join(args), p.returncode, p.stderr))
        return p.stdout.strip()

    def sha(self, rev: str = "HEAD") -> str:
        return self.git("rev-parse", rev)

    def commit(self, paths: dict, msg: str = "c") -> str:
        """`paths` 의 {레포 상대경로: 글 | None(지움)} 을 지금 브랜치에 커밋하고 그 해시를 낸다."""
        for rel, text in paths.items():
            target = self.repo / rel
            if text is None:
                self.git("rm", "-q", "--", rel)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(text, encoding="utf-8")
            self.git("add", "--", rel)
        self.git("commit", "-q", "--allow-empty", "-m", msg)
        return self.sha()

    def merge_commit(self) -> str:
        """기본 브랜치에 커밋 하나를 더해 리뷰받는 브랜치로 merge 커밋(--no-ff)을 만든다. 그 해시를 낸다."""
        self._n += 1
        self.git("checkout", "-q", BASE)
        self.commit({"trunk-%d.txt" % self._n: "t%d\n" % self._n}, "trunk %d" % self._n)
        self.git("checkout", "-q", HEAD)
        self.git("merge", "-q", "--no-ff", "-m", "merge trunk %d" % self._n, BASE)
        return self.sha()

    def rewrite_branch(self) -> str:
        """리뷰받는 브랜치의 끝 커밋을 고쳐 써(amend) 앞 끝이 조상이 아니게 한다. 새 끝 해시를 낸다."""
        self._n += 1
        rel = "rewrite-%d.txt" % self._n
        (self.repo / rel).write_text("r%d\n" % self._n, encoding="utf-8")
        self.git("add", "--", rel)
        self.git("commit", "-q", "--amend", "-m", "rewritten %d" % self._n)
        return self.sha()

    # ------------------------------------------------------------ 기계 상태

    def ledger(self, *args):
        """`conductor_ledger.py --root <리포> <args>` 를 프로세스 안에서 — (rc, stdout)."""
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = L.main(["--root", str(self.repo), *args])
        return rc, out.getvalue()

    def resource_dir(self, kind: str, name: str) -> Path:
        rc, out = self.ledger("resource-dir", "--roadmap", ROADMAP, "--kind", kind, "--name", name)
        if rc != 0:
            raise AssertionError("resource-dir → %d: %s" % (rc, out))
        return Path(out.strip())

    def archive(self, name: str) -> Path:
        """보고 폴더 나무 아래 보관 폴더 하나(`report_root/<name>`)."""
        return self.resource_dir("report", name)

    # ------------------------------------------------------------ qg 가 남기는 파일

    def write_result(self, folder, verdict, start, end, blocking=(), regress=(), filtered=(),
                     wrong=(), over=(), trivia=False) -> Path:
        """qg 결과 파일 `result.md` 를 `state-file-format.md` 꼴로 쓴다.

        `verdict` 는 `clean` · `defect` · `not-certified (<사유>)` 또는 None(판정 절 없음).
        `trivia` 가 참이면 판정은 `not-certified (trivia)`. `start` 가 None 이면 범위 절이 없다.
        `blocking` · `regress` 는 고칠 목록 줄(앞의 `- ` 없이). `filtered` · `wrong` · `over` 는
        intent-critic 목록 — 항목이 글이면 `- ` 뒤 줄 그대로, (정체, 질문) 쌍이면 그 목록의 꼴로 짓는다.
        """
        folder = Path(folder)
        folder.mkdir(parents=True, exist_ok=True)
        out = ["---", 'session_id: "rig-session-0001"', 'started_at: "2026-11-26T00:00:00Z"', "---",
               "", "# qg result"]
        if trivia:
            verdict = "not-certified (trivia)"
        if verdict is not None:
            value, _sep, reason = verdict.partition(" (")
            reason = reason.rstrip(")")
            lines = ["verdict: " + value]
            if reason:
                lines += ["reason: " + reason, "reasons: [%s]" % reason]
            head = "qg: " + value + (" (%s)" % reason if reason else "")
            lines.append("%s · 막는 지적 %d · 선택 0 · 차등 새 실패 %d · %s"
                         % (head, len(blocking), len(regress), (end or "0000000")[:7]))
            out += ["", "## 판정", ""] + lines
        if start is not None:
            out += ["", "## 범위", "", "mode: range", "status: ok", "start: " + start,
                    "end: " + (end or "")]
        out += ["", "## 고칠 목록", ""]
        for name, items in (("막는 지적", blocking), ("제안", ()), ("차등 회귀", regress)):
            out += ["### " + name, ""] + (["- " + x for x in items] or ["(없음)"]) + [""]
        out.pop()

        wrong_ids = {x[0] for x in wrong if not isinstance(x, str)}

        def listed(items, kind):
            rows = []
            for item in items:
                if isinstance(item, str):
                    rows.append("- " + item)
                elif kind == "filtered":
                    prev = "잘못 골랐다" if item[0] in wrong_ids else "의도다"
                    rows.append("- %s · %s · docs/qg-intent-answers/%s.md — %s"
                                % (item[0], prev, item[0], item[1]))
                else:
                    rows.append("- %s — %s" % (item[0], item[1]))
            return rows

        out += ["", "## intent-critic", "", INTENT_LEAD, "", "- intent-critic — 질문 없음", "",
                "- 다른 팀 기록 없음", "", "상한 넘어 남김:"] + (listed(over, "over") or ["- 없음"])
        if filtered:
            out += ["", "이미 답한 질문이라 거른 질문:"] + listed(filtered, "filtered")
        if wrong:
            out += ["", "이미 「잘못 골랐다」 답이 있어 거른 질문:"] + listed(wrong, "wrong")
        path = folder / "result.md"
        path.write_text("\n".join(out) + "\n", encoding="utf-8")
        return path

    def write_pre_merge(self, folder, findings) -> Path:
        """합치기 전 지적 목록 `findings-pre-merge.yaml`(`findings:` 목록). JSON 으로 써도 YAML 로 읽힌다."""
        folder = Path(folder)
        folder.mkdir(parents=True, exist_ok=True)
        path = folder / "findings-pre-merge.yaml"
        path.write_text(json.dumps({"findings": list(findings)}, ensure_ascii=False, indent=2) + "\n",
                        encoding="utf-8")
        return path

    def write_intent_return(self, folder, questions, **head) -> Path:
        """의도 점검의 돌려주는 꼴 3판 `intent-return.md`. `questions` 는 칸 dict 목록(`state` 는 필수).
        `head` 로 머리 칸을 바꾼다(기본 `status: ran` · 질문이 있으면 `outcome: questions`)."""
        folder = Path(folder)
        folder.mkdir(parents=True, exist_ok=True)
        values = {"contract": 3, "status": "ran", "outcome": "questions" if questions else "none",
                  "result_line": "intent-critic — 질문 %d개" % len(questions), "mode": "range",
                  "session_dir": str(folder), "breadth": "range", "answered_filtered": 0}
        values.update(head)
        lines = ["```qg-intent-return"]
        for key in RETURN_KEYS:
            value = values.get(key)
            if key in ("contract", "answered_filtered", "overlaps") and type(value) is int:
                lines.append("%s: %d" % (key, value))
            elif key in PLAIN_KEYS:
                lines.append("%s: %s" % (key, _scalar(value)))
            else:
                lines.append("%s: %s" % (key, _q(value)))
        lines.append("questions: []" if not questions else "questions:")
        for n, q in enumerate(questions, 1):
            if "state" not in q:
                raise ValueError("질문마다 state 가 있어야 한다")
            lines.append("  - n: %d" % q.get("n", n))
            for key in QUESTION_KEYS[1:]:
                value = q.get(key)
                if key == "wrong_choice":
                    lines.append("    wrong_choice: " + ("true" if value else "false"))
                elif key in ("answer_text", "observation", "changed_observation"):
                    if not value:
                        lines.append("    %s: %s" % (key, "[]" if key == "observation" else _q("-")))
                    else:
                        lines.append("    %s:" % key)
                        lines += ["      - " + _q(item) for item in value]
                elif key == "state":
                    lines.append("    state: " + _scalar(value))
                else:
                    lines.append("    %s: %s" % (key, _q(value)))
        lines.append("```")
        path = folder / "intent-return.md"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def write_handling(self, path, items, header: bool = True) -> Path:
        """처리 파일 — `header` 가 참이면 `## 지적마다의 처리` 머리 아래 `- <항목>` 줄들, 거짓이면 머리 없이."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        lines = ["# 구현 결과", ""]
        lines += [HANDLING_HEAD, ""] if header else ["## 보고", ""]
        lines += ["- " + x for x in items]
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    # ------------------------------------------------------------ 스크립트

    def run(self, *args) -> subprocess.CompletedProcess:
        """`qg_review_state.py <args>` 를 `sys.executable` 로 리포 안에서 부른다."""
        return subprocess.run([sys.executable, str(SCRIPT), *args], cwd=str(self.repo),
                              env=dict(os.environ, **GIT_ENV), capture_output=True, encoding="utf-8")
