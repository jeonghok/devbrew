"""옛 꼴 기록 묶음과 새 꼴 기록 묶음에 같은 스크립트가 같은 판정을 낸다.

임시 git 저장소에 같은 내용의 기록 묶음을 두 꼴로 짓고, 스크립트마다 종료 코드와 정규화한 출력을
견준다. 정규화는 폴더 · 파일 이름 끝 · 종류 글자 · 머리 키를 자리표로 바꾸는 것이라 남는 차이가 판정 차이다.
옛 · 새 글자는 이 파일에 박아 둔다 — 대응표 모듈에서 짝을 만들면 시험이 그 모듈의 전제를 물려받는다.
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

TESTS = Path(__file__).resolve().parent
SCRIPTS = TESTS.parent / "scripts"
sys.path.insert(0, str(TESTS))
import raw_source_fixture as RSF  # noqa: E402

FORMS = {
    "old": {"dir": "docs/superpowers/interview/", "seed": "-interview.md", "brief": "-interview.md",
            "state": "-interview.state.md", "k_seed": "interview-seed", "k_framing": "interview-seed-audit",
            "k_state": "interview-state", "k_brief": "interview-brief", "k_audit": "interview-audit",
            "head": "source_interview"},
    "new": {"dir": "docs/superpowers/intent/", "seed": "-intent.md", "brief": "-context.md",
            "state": "-context.state.md", "k_seed": "intent-seed", "k_framing": "intent-seed-audit",
            "k_state": "context-state", "k_brief": "context-brief", "k_audit": "context-audit",
            "head": "source_intent"},
}
OLD = FORMS["old"]
ENV = dict(os.environ, PYTHONDONTWRITEBYTECODE="1", GIT_CONFIG_GLOBAL="/dev/null", GIT_CONFIG_NOSYSTEM="1")

# 이 파일이 만드는 이름 — 옛 꼴로 짓고 새 꼴이면 아래 표대로 옮긴다
STEMS = ("t-seed", "t-brief")


def _git(repo, *args):
    return subprocess.run(["git", "-c", "user.name=t", "-c", "user.email=t@example.invalid",
                           "-c", "commit.gpgsign=false", "-c", "core.hooksPath=/dev/null"] + list(args),
                          cwd=str(repo), check=True, capture_output=True, text=True, encoding="utf-8")


def _convert(text: str, form: dict) -> str:
    """옛 꼴로 지은 글을 form 의 글자로 바꾼다(옛 꼴이면 그대로)."""
    # 긴 글자부터
    for old, new in (("interview-seed-audit", form["k_framing"]), ("interview-seed", form["k_seed"]),
                     ("interview-state", form["k_state"]), ("interview-brief", form["k_brief"]),
                     ("interview-audit", form["k_audit"]), ("source_interview", form["head"])):
        text = text.replace(old, new)
    for stem in STEMS:
        tail = form["seed"] if stem == "t-seed" else form["brief"]
        text = text.replace(stem + "-interview.audit.md", stem + tail[:-3] + ".audit.md")
        text = text.replace(stem + "-interview.state.md", stem + form["state"])
        text = text.replace(stem + "-interview.md", stem + tail)
    return text.replace("docs/iv/", form["dir"])


def build(tmp: str, form_name: str, mode: str = "recorded") -> dict:
    """옛 꼴 묶음을 만든 뒤 form 의 이름 · 글자로 옮겨 커밋한다. 경로는 저장소 상대 경로로 돌려준다."""
    form = FORMS[form_name]
    made = RSF.make_repo(tmp, mode=mode)
    repo = Path(made["repo"])
    for src in sorted((repo / "docs" / "iv").iterdir()):
        text = _convert(src.read_text(encoding="utf-8"), form)
        name = _convert("docs/iv/" + src.name, form)
        dst = repo / name
        dst.parent.mkdir(parents=True, exist_ok=True)
        src.unlink()
        dst.write_text(text, encoding="utf-8")
    shutil.rmtree(repo / "docs" / "iv", ignore_errors=True)
    stem = "t-brief" + form["brief"][:-3]
    seed = "t-seed" + form["seed"]
    d = form["dir"]
    paths = {"repo": str(repo), "brief": d + stem + ".md", "audit": d + stem + ".audit.md",
             "state": d + "t-brief" + form["state"], "seed": d + seed, "framing": d + seed[:-3] + ".audit.md"}
    _git(repo, "add", "-A", "docs")
    _git(repo, "commit", "-q", "-m", "form")
    return paths


def norm(text: str, form_name: str, repo: str) -> str:
    """꼴마다 다른 글자를 자리표로 바꾼다. 종류 · 머리 키는 두 꼴의 글자를 모두 바꾼다 — 오류 글자가 새 이름을
    내는지는 각 시험이 원문으로 따로 본다."""
    form = FORMS[form_name]
    text = text.replace(repo, "<REPO>").replace(os.path.realpath(repo), "<REPO>")
    text = text.replace(form["dir"], "<DIR>")
    text = text.replace("t-seed" + form["seed"][:-3], "t-seed<SEEDTAIL>")
    text = text.replace("t-brief" + form["brief"][:-3], "t-brief<BRIEFTAIL>")
    for key, token in (("k_framing", "<KFRAMING>"), ("k_seed", "<KSEED>"), ("k_state", "<KSTATE>"),
                       ("k_brief", "<KBRIEF>"), ("k_audit", "<KAUDIT>"), ("head", "<HEAD>")):
        for f in FORMS.values():
            text = text.replace(f[key], token)
    return text


def run(cwd: str, script: str, *args: str):
    cp = subprocess.run([sys.executable, str(SCRIPTS / script)] + list(args), cwd=cwd, env=ENV,
                        capture_output=True, text=True, encoding="utf-8")
    return cp


class Pair(unittest.TestCase):
    """같은 호출을 두 꼴 저장소에서 돌려 (rc, 정규화한 stdout+stderr) 를 견준다."""

    def setUp(self):
        self._tds = []
        self.world = {}
        for name in FORMS:
            td = tempfile.TemporaryDirectory()
            self.addCleanup(td.cleanup)
            self.world[name] = build(os.path.join(td.name, "r"), name)

    def pair(self, script, argfn, *, rc_expect=None):
        out = {}
        self.raw = {}
        for name, w in self.world.items():
            cp = run(w["repo"], script, *argfn(w))
            self.raw[name] = cp.stdout + "\n--stderr--\n" + cp.stderr
            out[name] = (cp.returncode, norm(self.raw[name], name, w["repo"]))
        self.assertEqual(out["old"], out["new"], "두 꼴의 판정이 갈린다:\n--old--\n%s\n--new--\n%s" % (out["old"], out["new"]))
        if rc_expect is not None:
            self.assertEqual(out["new"][0], rc_expect, out["new"][1])
        return out["new"]

    def test_check_brief_gate_same(self):
        rc, text = self.pair("check_brief.py", lambda w: ["gate", w["brief"]])
        self.assertNotIn("type !=", text)

    def test_kind_cross_rejected(self):
        # 결과물 자리의 type 이 옛 seed 종류 — 두 꼴이 같은 거절, 사유 글자는 새 종류 이름
        for name, w in self.world.items():
            for rel, kind in ((w["brief"], FORMS[name]["k_brief"]), (w["audit"], FORMS[name]["k_audit"])):
                p = Path(w["repo"]) / rel
                t = p.read_text(encoding="utf-8")
                self.assertIn("type: " + kind, t)
                p.write_text(t.replace("type: " + kind, "type: interview-seed", 1), encoding="utf-8")
        rc, text = self.pair("check_brief.py", lambda w: ["gate", w["brief"]])
        self.assertNotEqual(rc, 0)
        for name in FORMS:   # 사유의 종류 이름은 두 꼴 모두 새 글자다
            self.assertIn("type != context-brief", self.raw[name])
            self.assertIn("!= 'context-audit'", self.raw[name])

    def test_check_verbatim_same(self):
        self.pair("check_verbatim_coverage.py", lambda w: [w["brief"], w["state"], w["audit"]])

    def test_raw_source_locate_same(self):
        rc, text = self.pair("raw_source.py", lambda w: ["locate", "--interview", w["brief"], "--absolute"], rc_expect=0)
        self.assertIn("raw-source: FOUND", text)

    def test_build_brief_bundle_same(self):
        self.pair("build_brief_bundle.py", lambda w: [w["brief"], w["audit"], "--raw-audit", w["framing"]])

    def test_team_write_framing_same(self):
        # team_write 가 framing 기록 종류를 견주는 길 — 맞는 종류는 받고 틀린 종류는 같은 말로 거절
        def args(w):
            return ["original", "--brief", w["brief"], "--out", "docs/superpowers/roadmaps/t1",
                    "--framing-audit", w["framing"]]
        self.pair("roadmap_write.py", args)
        for name, w in self.world.items():
            p = Path(w["repo"]) / w["framing"]
            p.write_text(p.read_text(encoding="utf-8").replace("type: " + FORMS[name]["k_framing"],
                                                                "type: interview-brief", 1), encoding="utf-8")
            _git(w["repo"], "add", "-A", "docs")
            _git(w["repo"], "commit", "-q", "-m", "bad framing type")
        rc, text = self.pair("roadmap_write.py", lambda w: ["original", "--brief", w["brief"], "--out",
                                                           "docs/superpowers/roadmaps/t2",
                                                           "--framing-audit", w["framing"]])
        self.assertNotEqual(rc, 0)


    def _design_doc(self, name, w, body="", head=None):
        form = FORMS[name]
        p = Path(w["repo"]) / "docs/superpowers/specs/t-design.md"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text("---\n%s: %s\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n"
                     "| C1 | 반영 | §1 |\n%s" % (head or form["head"], w["brief"], body), encoding="utf-8")
        _git(w["repo"], "add", "-A", "docs")
        _git(w["repo"], "commit", "-q", "-m", "design")
        return "docs/superpowers/specs/t-design.md"

    def test_bundle_coverage_same(self):
        specs = {n: self._design_doc(n, w) for n, w in self.world.items()}
        rc, text = self.pair("check_bundle_coverage.py", lambda w: [w["brief"], specs[self._name(w)]])
        self.assertNotIn("셀 수 없음", text.splitlines()[0])

    def _name(self, w):
        return next(n for n, x in self.world.items() if x is w)

    def test_spec_review_bundle_same(self):
        for n, w in self.world.items():
            self._design_doc(n, w)
        rc, text = self.pair("spec_review_bundle.py", lambda w: [
            "entry", "--spec", "docs/superpowers/specs/t-design.md", "--bundle", w["brief"], "--root", w["repo"]])
        for n in FORMS:
            self.assertEqual(self.raw[n].split("\n--stderr--")[0].strip().splitlines()[-1].split(" ")[0:2],
                             ["bundle-entry:", "PROCEED"], text)

    def test_spec_review_bundle_other_file_same(self):
        for n, w in self.world.items():
            self._design_doc(n, w)
        rc, text = self.pair("spec_review_bundle.py", lambda w: [
            "entry", "--spec", "docs/superpowers/specs/t-design.md", "--bundle", w["audit"], "--root", w["repo"]])
        self.assertIn("bundle-entry: REFUSE", text)
        for n in FORMS:   # 사유의 종류 이름 · 머리 키 이름은 새 글자다
            self.assertIn("frontmatter type 이 epic-bundle · context-brief 가 아니다", self.raw[n])

    def test_spec_review_bundle_head_key_message(self):
        # 머리 키가 없는 설계문서 · 다른 파일을 가리키는 설계문서 — 사유가 새 머리 키 이름을 쓴다
        for n, w in self.world.items():
            p = Path(w["repo"]) / "docs/superpowers/specs/none-design.md"
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_text("---\nname: x\n---\n\n# 출처 없음\n", encoding="utf-8")
        rc, text = self.pair("spec_review_bundle.py", lambda w: [
            "entry", "--spec", "docs/superpowers/specs/none-design.md", "--bundle", w["brief"], "--root", w["repo"]])
        self.assertIn("bundle-entry: REFUSE", text)
        for n in FORMS:
            self.assertIn("설계문서 frontmatter 에 source_intent 가 없다", self.raw[n])
        for n, w in self.world.items():
            self._design_doc(n, w, head=FORMS[n]["head"])
            p = Path(w["repo"]) / "docs/superpowers/specs/t-design.md"
            p.write_text(p.read_text(encoding="utf-8").replace(w["brief"], w["audit"]), encoding="utf-8")
        rc, text = self.pair("spec_review_bundle.py", lambda w: [
            "entry", "--spec", "docs/superpowers/specs/t-design.md", "--bundle", w["brief"], "--root", w["repo"]])
        for n in FORMS:
            self.assertIn("설계문서 source_intent(", self.raw[n])


FIXTURE_BRIEF = "interview-brief-valid"


def _rm_brief_files(repo: str, form_name: str) -> str:
    """로드맵 레포에 brief · audit 을 둔다. 돌려주는 것: brief 의 레포 상대 경로."""
    form = FORMS[form_name]
    d = Path(repo) / form["dir"]
    d.mkdir(parents=True, exist_ok=True)
    stem = "e-x" + form["brief"][:-3]
    brief = (TESTS / "fixtures" / (FIXTURE_BRIEF + ".md")).read_text(encoding="utf-8")
    audit = (TESTS / "fixtures" / (FIXTURE_BRIEF + ".audit.md")).read_text(encoding="utf-8")
    brief = brief.replace("audit_file: %s.audit.md" % FIXTURE_BRIEF, "audit_file: %s.audit.md" % stem)
    audit = audit.replace("payload: %s.md" % FIXTURE_BRIEF, "payload: %s.md" % stem)
    brief = brief.replace("type: interview-brief", "type: " + form["k_brief"], 1)
    audit = audit.replace("type: interview-audit", "type: " + form["k_audit"], 1)
    (d / (stem + ".md")).write_text(brief, encoding="utf-8")
    (d / (stem + ".audit.md")).write_text(audit, encoding="utf-8")
    return form["dir"] + stem + ".md"


def rm_repo(tmp: str, brief_form: str, head_forms: "list[str]") -> str:
    """origin 이 있는 로드맵 레포. 에픽마다 브랜치 feature/g<n> 에 설계문서가 있고 그 머리 키가 head_forms[n-1] 꼴이다
    (단계 「설계 중」)."""
    top = Path(tmp)
    bare = top / "origin.git"
    work = top / "work"
    subprocess.run(["git", "init", "-q", "--bare", "-b", "main", str(bare)], check=True, env=ENV)
    subprocess.run(["git", "clone", "-q", str(bare), str(work)], check=True, env=ENV, capture_output=True)
    work = Path(os.path.realpath(str(work)))
    brief_rel = _rm_brief_files(str(work), brief_form)
    (work / "docs/rm").mkdir(parents=True, exist_ok=True)
    blocks, specs = [], []
    for i, f in enumerate(head_forms, 1):
        eid = "G%d" % i
        (work / ("docs/rm/%s.md" % eid)).write_text(
            "---\ntype: epic-bundle\nepic: %s\nroadmap: docs/rm/roadmap.md\nsource_brief: %s\nids: [C1]\n---\n\n# %s\n"
            % (eid, brief_rel, eid), encoding="utf-8")
        blocks.append("### %s — 에픽 %s\n- 의도: %s 의 의도\n- 범위: 한다 %s / 안 한다 없음\n- 의존: 없음\n"
                      "- 브랜치: feature/g%d\n- 묶음: %s.md\n- 경로 예약: 없음\n\n" % (eid, eid, eid, eid, i, eid))
        specs.append((i, "---\n%s: docs/rm/%s.md\n---\n\n# 설계\n\n## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n"
                         "|---|---|---|\n| C1 | 반영 | §1 |\n" % (FORMS[f]["head"], eid)))
    (work / "docs/rm/roadmap.md").write_text(
        "---\ntype: roadmap\nsource_brief: %s\n---\n\n# 로드맵\n\n## 에픽\n\n" % brief_rel + "".join(blocks)
        + "## 지휘 절차\n\n1. fetch\n\n## 결정 기록\n\n쉬운 말 PR 은 이미 머지됐다 — 블록 없음.\n\n## 재분해 이력\n\n- 없음\n\n## 위험 번호표\n\n"
        "- K1 — 위험 — 숨은 가정: 가정 하나 — 근거 없음\n", encoding="utf-8")
    _git(work, "checkout", "-q", "-b", "main")
    _git(work, "add", "-A", "docs")
    _git(work, "commit", "-q", "-m", "roadmap")
    _git(work, "push", "-q", "origin", "main")
    _git(work, "remote", "set-head", "origin", "main")
    for i, spec in specs:
        _git(work, "checkout", "-q", "-b", "feature/g%d" % i, "main")
        sp = work / ("docs/superpowers/specs/g%d-design.md" % i)
        sp.parent.mkdir(parents=True, exist_ok=True)
        sp.write_text(spec, encoding="utf-8")
        _git(work, "add", "-A", "docs")
        _git(work, "commit", "-q", "-m", "spec g%d" % i)
        _git(work, "checkout", "-q", "main")
    _git(work, "fetch", "-q", "origin")
    return str(work)


def rm_stages(repo: str, form_hint: str = "") -> "list[tuple]":
    import json
    cp = run(repo, "roadmap_status.py", "--json", "docs/rm/roadmap.md")
    r = json.loads(cp.stdout)
    return [(b["id"], b["stage"], b["reason"], [re.sub(r"e\d-x(-intent|-context|-interview)?", "<STEM>", w)
                                                for w in b["warnings"]]) for b in r["blocks"]]


class RoadmapForms(unittest.TestCase):
    def mk(self, brief_form, head_forms):
        td = tempfile.TemporaryDirectory()
        self.addCleanup(td.cleanup)
        return rm_repo(td.name, brief_form, head_forms)

    def test_roadmap_status_same(self):
        old = rm_stages(self.mk("old", ["old"]))
        new = rm_stages(self.mk("new", ["new"]))
        self.assertEqual(old, new)
        self.assertEqual(old[0][1], "설계 중", old)
        self.assertEqual(old[0][2], "spec 있음", old)   # 설계문서가 머리 키로 묶음을 찾았다

    def test_mixed_old_and_new_in_one_repo(self):
        # 한 레포에 옛 꼴 묶음과 새 꼴 묶음이 함께 있어도 서로를 남의 것으로 읽지 않는다
        both = rm_stages(self.mk("old", ["old", "new"]))
        self.assertEqual([x[:3] for x in both], [("G1", "설계 중", "spec 있음"), ("G2", "설계 중", "spec 있음")], both)
        warns = [[re.sub(r"g\d-design", "gN-design", w) for w in x[3]] for x in both]
        self.assertEqual(warns[0], warns[1], both)


class MixedRepo(unittest.TestCase):
    def test_both_forms_one_repo(self):
        tds = []
        worlds = {}
        for name in FORMS:
            td = tempfile.TemporaryDirectory()
            self.addCleanup(td.cleanup)
            worlds[name] = build(os.path.join(td.name, "r"), name)
        # 새 꼴 파일을 옛 꼴 저장소로 복사한다
        old, new = worlds["old"], worlds["new"]
        src = Path(new["repo"]) / FORMS["new"]["dir"]
        dst = Path(old["repo"]) / FORMS["new"]["dir"]
        shutil.copytree(str(src), str(dst))
        _git(old["repo"], "add", "-A", "docs")
        _git(old["repo"], "commit", "-q", "-m", "mixed")
        results = {}
        for name, w in worlds.items():
            cp = run(old["repo"], "raw_source.py", "locate", "--interview", w["brief"], "--absolute")
            gate = run(old["repo"], "check_brief.py", "gate", w["brief"])
            results[name] = (cp.returncode, gate.returncode, norm(cp.stdout, name, old["repo"]).strip().splitlines()[-1])
        self.assertEqual(results["old"], results["new"])
        self.assertEqual(results["new"][0], 0)


class SpecsFor(unittest.TestCase):
    def test_specs_for_counts_old_and_new_head_key_together(self):
        sys.path.insert(0, str(SCRIPTS))
        import check_bundle_coverage as cbc
        with tempfile.TemporaryDirectory() as td:
            d = Path(td) / "specs"
            d.mkdir()
            (d / "a-design.md").write_text("---\nsource_interview: docs/rm/B.md\n---\n\n# a\n", encoding="utf-8")
            (d / "b-design.md").write_text("---\nsource_intent: docs/rm/B.md\n---\n\n# b\n", encoding="utf-8")
            (d / "c-design.md").write_text("---\nsource_intent: docs/rm/OTHER.md\n---\n\n# c\n", encoding="utf-8")
            got = sorted(rel for rel, _ in cbc.Repo(td).specs_for("docs/rm/B.md", "specs"))
        self.assertEqual(got, ["specs/a-design.md", "specs/b-design.md"])


if __name__ == "__main__":
    unittest.main()
