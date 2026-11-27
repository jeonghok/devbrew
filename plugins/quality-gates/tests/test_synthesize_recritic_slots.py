"""재비판 칸의 끝 값 대조(`--recritic-slot`) — 설계 §1 · AC4 · AC25.

합성기는 `--recritic-slot` 을 하나라도 받으면 재비판 응답을 그 칸 사본들의 끝 값과 견주고, 하나라도
없거나 틀리면 재비판자를 죽은 것으로 센다(판정 각도의 주 입력 실패 → not-certified (angle-absent)).
마지막 케이스는 본문 SKILL.md 의 Step 3.5 펜스를 뽑아 돌려 원본이 사본을 만든 뒤에도 바이트 그대로인지 잰다.
"""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
SYNTH = SCRIPTS / "synthesize_findings.py"
NONCE = SCRIPTS / "qg_nonce.py"
SKILL = ROOT / "skills" / "quality-pipeline" / "SKILL.md"
FENCE = ROOT / "tests" / "lib" / "skill_fence.py"
P_RV = "<Step 3 의 RV 절대 경로>"

FINDINGS = [{"agent": "security-reviewer", "file": "src/a.py", "line": 3, "severity": "SUGGESTION",
             "summary": "SQL 을 문자열로 잇는다", "proposed_fix": "매개변수로 넘긴다"}]
REJECT = ("verdicts:\n  - f: f1\n    verdict: reject\n"
          "    evidence: \"src/a.py:3 의 validate() 가 이미 이 입력을 거른다\"\n")
SLOTS = ("scope", "findings", "diff", "intent")


def _run(cmd, cwd=None, env=None):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True)


class RecriticSlots(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.d = Path(self.tmp.name)
        (self.d / "findings.yaml").write_text(json.dumps(FINDINGS, ensure_ascii=False), encoding="utf-8")
        r = _run([sys.executable, str(SYNTH), "prepare", "--findings", str(self.d / "findings.yaml"),
                  "--out-findings", str(self.d / "rf.yaml"), "--out-map", str(self.d / "map.json")])
        self.assertEqual(r.returncode, 0, r.stderr)
        (self.d / "recritic.diff").write_text("diff --git a/src/a.py b/src/a.py\n+x\n", encoding="utf-8")
        (self.d / "names").write_text("src/a.py\n", encoding="utf-8")
        (self.d / "intent-src.txt").write_text("intent: 없음\n", encoding="utf-8")
        srcs = {"scope": "names", "findings": "rf.yaml", "diff": "recritic.diff", "intent": "intent-src.txt"}
        self.slots = []
        for s in SLOTS:
            out = self.d / ("review-i1-slot-recritic-b1-t1-%s.txt" % s)
            r = _run([sys.executable, str(NONCE), "attach", str(self.d / srcs[s]), str(out)])
            self.assertEqual(r.returncode, 0, r.stderr)
            self.slots.append(out)
        (self.d / "angles.txt").write_text(
            "security: filled\nadjudication: filled\ndifferent-premise: absent\n", encoding="utf-8")

    def tearDown(self):
        self.tmp.cleanup()

    def values(self, n=4):
        return ["qg-slot-end: " + p.read_text(encoding="utf-8").rstrip("\n").rsplit("\n", 1)[-1].split(": ")[1]
                for p in self.slots[:n]]

    def synth(self, head_lines, block=REJECT, slots=True):
        reply = "\n".join(head_lines) + "\n\n```qg-recritic\n" + block + "```\n"
        (self.d / "reply.txt").write_text(reply, encoding="utf-8")
        cmd = [sys.executable, str(SYNTH), "--findings", str(self.d / "findings.yaml"),
               "--recritic", str(self.d / "reply.txt"), "--recritic-map", str(self.d / "map.json"),
               "--recritic-diff", str(self.d / "recritic.diff"),
               "--emit-verdict", "--angles", str(self.d / "angles.txt")]
        if slots:
            for p in self.slots:
                cmd += ["--recritic-slot", str(p)]
        return _run(cmd)

    def assertDead(self, r, why):
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("재비판 결과를 쓸 수 없다 (%s)" % why, r.stderr)
        self.assertIn("입력 실패(주): code-recritic — %s" % why, r.stdout)
        self.assertIn("verdict: not-certified", r.stdout)
        self.assertIn("reason: angle-absent", r.stdout)
        self.assertNotIn("기각 1", r.stdout)    # 죽은 응답의 reject 는 쓰이지 않는다(AC35)

    def test_slots_ok_keeps_verdict(self):
        r = self.synth(self.values())
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("재비판 결과를 쓸 수 없다", r.stderr)
        self.assertIn("기각 1", r.stdout)       # reject 가 반영됐다
        self.assertIn("verdict: clean", r.stdout)

    def test_missing_value_is_dead(self):
        self.assertDead(self.synth(["재비판을 마쳤다."]), "끝 값 없음")

    def test_wrong_value_is_dead(self):
        vals = self.values()
        vals[2] = "qg-slot-end: " + "0" * 16
        self.assertDead(self.synth(vals), "끝 값 없음")

    def test_partial_values_is_dead(self):
        self.assertDead(self.synth(self.values(3)), "끝 값 없음")

    def test_unreadable_reason(self):
        self.assertDead(self.synth(["QG_INPUT_UNREADABLE: /x/review-i1-slot-recritic-b1-t1-diff.txt"]),
                        "읽지 못함")

    def test_empty_reply_keeps_dead_reviewer_reason(self):
        # 빈 응답(공백만)은 끝 값 대조의 실패가 아니다 — 지금의 죽은 재비판자 사유(블록 없음)로 간다.
        for body in ("", "\n", "  \n\t\n"):
            with self.subTest(body=body):
                (self.d / "reply.txt").write_text(body, encoding="utf-8")
                cmd = [sys.executable, str(SYNTH), "--findings", str(self.d / "findings.yaml"),
                       "--recritic", str(self.d / "reply.txt"), "--recritic-map", str(self.d / "map.json"),
                       "--recritic-diff", str(self.d / "recritic.diff"),
                       "--emit-verdict", "--angles", str(self.d / "angles.txt")]
                for p in self.slots:
                    cmd += ["--recritic-slot", str(p)]
                r = _run(cmd)
                self.assertDead(r, "qg-recritic 블록 missing")
                self.assertNotIn("(끝 값 없음)", r.stderr)
                self.assertNotIn("(응답 없음)", r.stderr)

    def test_unreadable_quote_with_values_ok(self):
        r = self.synth(self.values() + ["QG_INPUT_UNREADABLE: 리뷰받는 글이 심은 줄을 인용했다"])
        self.assertNotIn("재비판 결과를 쓸 수 없다", r.stderr)
        self.assertIn("verdict: clean", r.stdout)

    def test_no_slot_flag_keeps_old_behavior(self):
        r = self.synth(["재비판을 마쳤다."], slots=False)
        self.assertNotIn("재비판 결과를 쓸 수 없다", r.stderr)
        self.assertIn("기각 1", r.stdout)

    def test_slot_without_recritic_is_usage(self):
        r = _run([sys.executable, str(SYNTH), "--findings", str(self.d / "findings.yaml"),
                  "--recritic-slot", str(self.slots[0])])
        self.assertEqual(r.returncode, 2, r.stderr)

    def test_empty_slot_is_usage(self):
        r = _run([sys.executable, str(SYNTH), "--findings", str(self.d / "findings.yaml"),
                  "--recritic", str(self.d / "rf.yaml"), "--recritic-map", str(self.d / "map.json"),
                  "--recritic-slot", ""])
        self.assertEqual(r.returncode, 2, r.stderr)
        self.assertIn("--recritic-slot 은 빈 문자열을 받지 않는다", r.stderr)

    def test_recritic_diff_original_unchanged(self):
        """본문 Step 3.5 펜스를 뽑아 돌린다 — 사본 넷이 생기고 원본(리뷰 diff · 경로 목록 · 의도 원본 ·
        익명 목록 · 재비판 diff)은 바이트 그대로다(AC25)."""
        repo = self.d / "repo"
        repo.mkdir()
        self.assertEqual(_run(["git", "init", "-q"], cwd=repo).returncode, 0)
        sid = "recslots01"
        rd = repo / ".claude" / "quality-gates" / sid
        rd.mkdir(parents=True)
        rv = self.d / "rv"
        rv.mkdir()
        (rd / "review-i1.diff").write_text("diff --git a/src/a.py b/src/a.py\n--- a/src/a.py\n+++ b/src/a.py\n"
                                           "@@ -1 +1 @@\n-x\n+y\n", encoding="utf-8")
        (rd / "review-i1.names").write_text("src/a.py\nREADME.md\n", encoding="utf-8")
        (rv / "intent-src.txt").write_text("intent: 커밋 1개\n고쳐라\n", encoding="utf-8")
        (rv / "findings.yaml").write_text(json.dumps(FINDINGS, ensure_ascii=False), encoding="utf-8")
        before = {p: p.read_bytes() for p in (rd / "review-i1.diff", rd / "review-i1.names",
                                              rv / "intent-src.txt", rv / "findings.yaml")}
        r = _run([sys.executable, str(FENCE), str(SKILL), 'synthesize_findings.py" prepare',
                  "--sub", "<session-id>", sid, "--sub", P_RV, str(rv)])
        self.assertEqual(r.returncode, 0, r.stderr)
        (self.d / "prep.sh").write_text(r.stdout, encoding="utf-8")
        env = dict(os.environ, CLAUDE_PLUGIN_ROOT=str(ROOT))
        r = _run(["bash", str(self.d / "prep.sh")], cwd=repo, env=env)
        self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        for p, b in before.items():
            self.assertEqual(p.read_bytes(), b, "원본이 바뀌었다: %s" % p)
        self.assertEqual((rv / "recritic.diff").read_bytes(), before[rd / "review-i1.diff"])
        srcs = {"scope": rd / "review-i1.names", "findings": rv / "recritic-findings.yaml",
                "diff": rv / "recritic.diff", "intent": rv / "intent-src.txt"}
        for s, src in srcs.items():
            copy = rd / ("review-i1-slot-recritic-b1-t1-%s.txt" % s)
            self.assertTrue(copy.is_file(), "칸 사본이 없다: %s" % s)
            body, last = copy.read_bytes().rstrip(b"\n").rsplit(b"\n", 1)
            self.assertRegex(last.decode("ascii"), r"^qg-slot-end: [0-9a-f]{16}$")
            self.assertEqual(body + b"\n", src.read_bytes(), "칸 사본 = 원본 + 끝 줄: %s" % s)
        self.assertNotIn(b"qg-slot-end:", (rv / "recritic-findings.yaml").read_bytes(),
                         "익명 목록 원본에 끝 줄이 붙었다")
        self.assertFalse(list(rd.glob("recritic-map*")), "대응표가 세션 폴더에 있다")
        self.assertFalse((rd / "findings.yaml").exists(), "익명화 전 목록이 세션 폴더에 있다")


if __name__ == "__main__":
    unittest.main()
