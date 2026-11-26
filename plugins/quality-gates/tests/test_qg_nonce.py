"""scripts/qg_nonce.py — 끝 값 · 칸 사본 · 묶음 사본 · 응답 대조의 명령줄 시험."""
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "qg_nonce.py"
END_RE = re.compile(r"qg-slot-end: ([0-9a-f]{16})\n\Z")


def run(*args):
    return subprocess.run(
        [sys.executable, str(SCRIPT)] + [str(a) for a in args],
        capture_output=True, text=True, encoding="utf-8",
    )


class QgNonceTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="qg-nonce-"))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)

    def test_hex_is_8_lower_hex_and_differs(self):
        a = run("hex")
        b = run("hex")
        self.assertEqual(a.returncode, 0, a.stderr)
        self.assertRegex(a.stdout, r"\A[0-9a-f]{8}\n\Z")
        self.assertRegex(b.stdout, r"\A[0-9a-f]{8}\n\Z")
        self.assertNotEqual(a.stdout, b.stdout)

    def test_attach_appends_one_end_line(self):
        src = self.tmp / "src.txt"
        src.write_bytes(b"a\nb")
        out = self.tmp / "slot.txt"
        r = run("attach", src, out)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, "%s\n" % out)
        self.assertEqual(src.read_bytes(), b"a\nb")
        data = out.read_bytes().decode("utf-8")
        self.assertRegex(data, r"\Aa\nb\nqg-slot-end: [0-9a-f]{16}\n\Z")

    def test_attach_does_not_follow_out_link(self):
        src = self.tmp / "src.txt"
        src.write_bytes(b"body\n")
        victim = self.tmp / "victim.txt"
        victim.write_bytes(b"keep\n")
        out = self.tmp / "slot.txt"
        os.symlink(str(victim), str(out))
        r = run("attach", src, out)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(victim.read_bytes(), b"keep\n")
        self.assertFalse(out.is_symlink())
        self.assertRegex(out.read_bytes().decode("utf-8"),
                         r"\Abody\nqg-slot-end: [0-9a-f]{16}\n\Z")

    def test_attach_value_differs_per_call(self):
        src = self.tmp / "src.txt"
        src.write_bytes(b"same\n")
        values = []
        for name in ("one.txt", "two.txt"):
            out = self.tmp / name
            r = run("attach", src, out)
            self.assertEqual(r.returncode, 0, r.stderr)
            m = END_RE.search(out.read_bytes().decode("utf-8"))
            self.assertIsNotNone(m)
            values.append(m.group(1))
        self.assertNotEqual(values[0], values[1])

    def _chunk(self, path, line):
        return (
            "diff --git a/%s b/%s\n"
            "index 1111111..2222222 100644\n"
            "--- a/%s\n"
            "+++ b/%s\n"
            "@@ -1 +1 @@\n"
            "-old\n"
            "+%s\n" % (path, path, path, path, line)
        )

    def test_split_picks_listed_files_only(self):
        a = self._chunk("src/a.py", "A")
        b = self._chunk("src/b.py", "B")
        c = self._chunk("src/c.py", "C")
        diff = self.tmp / "review.diff"
        diff.write_text(a + b + c, encoding="utf-8")
        out = self.tmp / "bundle.txt"
        r = run("split", diff, out, "--", "src/c.py", "src/a.py")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, "%s\n" % out)
        data = out.read_bytes().decode("utf-8")
        m = END_RE.search(data)
        self.assertIsNotNone(m)
        self.assertEqual(data[: m.start()], a + c)

    def test_split_rename_and_space(self):
        rename = (
            "diff --git a/old.py b/new.py\n"
            "similarity index 90%\n"
            "rename from old.py\n"
            "rename to new.py\n"
            "@@ -1 +1 @@\n"
            "-o\n"
            "+n\n"
        )
        # 옛 이름에 " b/" 가 들어 머리 줄만으로는 가를 수 없다 — rename to 줄로 맞춘다.
        rename_spaced = (
            "diff --git a/x b/y.py b/z.py\n"
            "similarity index 90%\n"
            "rename from x b/y.py\n"
            "rename to z.py\n"
        )
        quoted = (
            'diff --git "a/x y.py" "b/x y.py"\n'
            "--- \"a/x y.py\"\n"
            "+++ \"b/x y.py\"\n"
            "@@ -1 +1 @@\n"
            "-1\n"
            "+2\n"
        )
        # core.quotePath=false 의 git 은 공백만 든 경로를 따옴표 없이 쓴다.
        spaced = self._chunk("p q.py", "S")
        # 경로 안의 " b/" — 앞뒤 절반이 같은 머리로 가른다.
        spaced_b = self._chunk("dir b/f.py", "D")
        # 따옴표 꼴의 C 이스케이프(탭 · 8진 UTF-8 바이트)를 풀어 맞춘다.
        escaped = (
            'diff --git "a/t\\tab \\352\\260\\200.py" "b/t\\tab \\352\\260\\200.py"\n'
            "@@ -1 +1 @@\n"
            "-1\n"
            "+2\n"
        )
        other = self._chunk("keep/out.py", "K")
        diff = self.tmp / "review.diff"
        diff.write_text(
            other + rename + rename_spaced + quoted + spaced + spaced_b + escaped,
            encoding="utf-8")
        out = self.tmp / "bundle.txt"
        r = run("split", diff, out, "--", "new.py", "z.py", "x y.py",
                "p q.py", "dir b/f.py", "t\tab 가.py")
        self.assertEqual(r.returncode, 0, r.stderr)
        data = out.read_bytes().decode("utf-8")
        m = END_RE.search(data)
        self.assertIsNotNone(m)
        self.assertEqual(
            data[: m.start()],
            rename + rename_spaced + quoted + spaced + spaced_b + escaped)

    def test_split_unknown_path_fails(self):
        diff = self.tmp / "review.diff"
        diff.write_text(self._chunk("src/a.py", "A"), encoding="utf-8")
        out = self.tmp / "bundle.txt"
        r = run("split", diff, out, "--", "src/a.py", "src/missing.py")
        self.assertEqual(r.returncode, 4)
        self.assertFalse(out.exists())
        self.assertEqual(r.stdout, "")
        # rc 4 는 읽기/쓰기 실패와 같은 값이라 사유 줄로 가른다.
        self.assertEqual(
            r.stderr, "[qg_nonce] 리뷰 diff 에 없는 경로 — src/missing.py\n")

    def test_split_unreadable_diff_reason(self):
        out = self.tmp / "bundle.txt"
        missing = self.tmp / "none.diff"
        r = run("split", missing, out, "--", "src/a.py")
        self.assertEqual(r.returncode, 4)
        self.assertFalse(out.exists())
        self.assertEqual(r.stderr, "[qg_nonce] 읽지 못했다 — %s\n" % missing)

    def _slot(self, name, body="data\n"):
        src = self.tmp / ("src-" + name)
        src.write_text(body, encoding="utf-8")
        out = self.tmp / name
        r = run("attach", src, out)
        self.assertEqual(r.returncode, 0, r.stderr)
        value = END_RE.search(out.read_bytes().decode("utf-8")).group(1)
        return out, value

    def _response(self, text, name="resp.txt"):
        path = self.tmp / name
        path.write_text(text, encoding="utf-8")
        return path

    def test_check_ok_when_all_values_present(self):
        s1, v1 = self._slot("intent.txt")
        s2, v2 = self._slot("diff.txt")
        resp = self._response(
            "qg-slot-end: %s\nqg-slot-end: %s\n```yaml\nfindings: []\n```\n" % (v1, v2))
        r = run("check", "--response", resp, "--slot", s1, s2)
        self.assertEqual((r.returncode, r.stdout), (0, "ok\n"), r.stderr)

    def test_check_missing_value(self):
        s1, _ = self._slot("intent.txt")
        resp = self._response("```yaml\nfindings: []\n```\n")
        r = run("check", "--response", resp, "--slot", s1)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 끝 값 없음\n"))

    def test_check_wrong_value(self):
        s1, v1 = self._slot("intent.txt")
        other = "0123456789abcdef" if v1 != "0123456789abcdef" else "fedcba9876543210"
        resp = self._response("qg-slot-end: %s\nfindings: []\n" % other)
        r = run("check", "--response", resp, "--slot", s1)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 끝 값 없음\n"))

    def test_check_partial_values(self):
        s1, v1 = self._slot("intent.txt")
        s2, _ = self._slot("diff.txt")
        resp = self._response("qg-slot-end: %s\nfindings: []\n" % v1)
        r = run("check", "--response", resp, "--slot", s1, "--slot", s2)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 끝 값 없음\n"))

    def test_check_unreadable_line_with_values_is_ok(self):
        s1, v1 = self._slot("intent.txt")
        s2, v2 = self._slot("diff.txt")
        resp = self._response(
            "qg-slot-end: %s\nqg-slot-end: %s\n"
            "QG_INPUT_UNREADABLE: /x\n"
            "findings: []\n" % (v1, v2))
        r = run("check", "--response", resp, "--slot", s1, s2)
        self.assertEqual((r.returncode, r.stdout), (0, "ok\n"))

    def test_check_unreadable_reason(self):
        s1, _ = self._slot("intent.txt")
        resp = self._response("QG_INPUT_UNREADABLE: %s\n" % s1)
        r = run("check", "--response", resp, "--slot", s1)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 읽지 못함\n"))

    def test_check_unreadable_mid_line_is_not_reason(self):
        s1, _ = self._slot("intent.txt")
        resp = self._response("인용: QG_INPUT_UNREADABLE: /x\n")
        r = run("check", "--response", resp, "--slot", s1)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 끝 값 없음\n"))

    def test_check_slot_without_end_line_fails_closed(self):
        value = "0123456789abcdef"
        bad = self.tmp / "bad.txt"
        # 끝 줄 뒤에 다른 줄이 붙어 끝 줄이 꼴 밖이다.
        bad.write_text("data\nqg-slot-end: %s\ntrailer\n" % value, encoding="utf-8")
        resp = self._response("qg-slot-end: %s\ntrailer\ndata\n" % value)
        r = run("check", "--response", resp, "--slot", bad)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 끝 값 없음\n"))

    def test_check_missing_response(self):
        s1, _ = self._slot("intent.txt")
        r = run("check", "--response", self.tmp / "none.txt", "--slot", s1)
        self.assertEqual((r.returncode, r.stdout), (1, "fail: 응답 없음\n"))

    def test_check_without_slot_is_usage(self):
        resp = self._response("ok\n")
        r = run("check", "--response", resp)
        self.assertEqual(r.returncode, 2)
        self.assertEqual(r.stdout, "")

    # ── check-reviewer: $RD 의 칸 사본 · $RV 의 응답 사본 ──

    def _dirs(self):
        rd = self.tmp / "rd"
        rv = self.tmp / "rv"
        rd.mkdir(exist_ok=True)
        rv.mkdir(exist_ok=True)
        return rd, rv

    def _try(self, rd, rv, name, b, t, answer=True, respond=True,
             slots=("intent", "diff")):
        """묶음 b 의 시도 t 를 세운다 — 칸 사본들과(answer 면 값을 적은) 응답 사본."""
        values = []
        for slot in slots:
            src = self.tmp / ("src-%s-%s" % (name, slot))
            src.write_text("%s %s\n" % (name, slot), encoding="utf-8")
            out = rd / ("review-i1-slot-%s-b%d-t%d-%s.txt" % (name, b, t, slot))
            r = run("attach", src, out)
            self.assertEqual(r.returncode, 0, r.stderr)
            values.append(END_RE.search(out.read_bytes().decode("utf-8")).group(1))
        if respond:
            lines = ["qg-slot-end: %s\n" % v for v in values] if answer else []
            (rv / ("resp-%s-b%d-t%d.txt" % (name, b, t))).write_text(
                "".join(lines) + "findings: []\n", encoding="utf-8")

    def _check_reviewer(self, rd, rv, name):
        return run("check-reviewer", "--rd", rd, "--rv", rv, "--reviewer", name)

    def test_check_reviewer_all_bundles_ok(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1)
        self._try(rd, rv, "security", 2, 1)
        r = self._check_reviewer(rd, rv, "security")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout, "b1: ok\nb2: ok\nsecurity: ok\n")

    def test_check_reviewer_one_bundle_fails(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1)
        self._try(rd, rv, "security", 2, 1, answer=False)
        r = self._check_reviewer(rd, rv, "security")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(
            r.stdout, "b1: ok\nb2: fail: 끝 값 없음\nsecurity: fail: 끝 값 없음\n")

    def test_check_reviewer_retry_ok(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1, answer=False)
        self._try(rd, rv, "security", 1, 2)
        r = self._check_reviewer(rd, rv, "security")
        self.assertEqual((r.returncode, r.stdout), (0, "b1: ok\nsecurity: ok\n"))

    def test_check_reviewer_ok_then_failed_retry_stays_ok(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1)
        self._try(rd, rv, "security", 1, 2, answer=False)
        r = self._check_reviewer(rd, rv, "security")
        self.assertEqual((r.returncode, r.stdout), (0, "b1: ok\nsecurity: ok\n"))

    def test_check_reviewer_reason_is_last_try(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1, answer=False)
        self._try(rd, rv, "security", 1, 2, respond=False)
        r = self._check_reviewer(rd, rv, "security")
        self.assertEqual(
            (r.returncode, r.stdout),
            (1, "b1: fail: 응답 없음\nsecurity: fail: 응답 없음\n"))

    def test_check_reviewer_dead_try(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "recritic", 1, 1, respond=False,
                  slots=("scope", "findings", "diff", "intent"))
        r = self._check_reviewer(rd, rv, "recritic")
        self.assertEqual(
            (r.returncode, r.stdout),
            (1, "b1: fail: 응답 없음\nrecritic: fail: 응답 없음\n"))

    def test_check_reviewer_keeps_responses(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1, answer=False)
        resp = rv / "resp-security-b1-t1.txt"
        before = resp.read_bytes()
        r = self._check_reviewer(rd, rv, "security")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(resp.read_bytes(), before)

    def test_check_reviewer_hyphenated_name(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "ext-code-reviewer", 1, 1)
        self._try(rd, rv, "ext-code-reviewer", 2, 1, answer=False)
        r = self._check_reviewer(rd, rv, "ext-code-reviewer")
        self.assertEqual(r.returncode, 1)
        self.assertEqual(
            r.stdout,
            "b1: ok\nb2: fail: 끝 값 없음\next-code-reviewer: fail: 끝 값 없음\n")

    def test_check_reviewer_ext_reviewers_do_not_mix(self):
        rd, rv = self._dirs()
        # 한 이름이 다른 이름의 앞머리다 — 앞쪽 이름이 뒤쪽 이름의 사본을 집으면 안 된다.
        self._try(rd, rv, "ext-code", 1, 1)
        self._try(rd, rv, "ext-code-reviewer", 1, 1, answer=False)
        self._try(rd, rv, "ext-code-reviewer", 2, 1, answer=False)
        short = self._check_reviewer(rd, rv, "ext-code")
        self.assertEqual((short.returncode, short.stdout), (0, "b1: ok\next-code: ok\n"))
        long_ = self._check_reviewer(rd, rv, "ext-code-reviewer")
        self.assertEqual(long_.returncode, 1)
        self.assertEqual(
            long_.stdout,
            "b1: fail: 끝 값 없음\nb2: fail: 끝 값 없음\n"
            "ext-code-reviewer: fail: 끝 값 없음\n")

    def test_check_reviewer_no_slots_is_usage(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1)
        r = self._check_reviewer(rd, rv, "recritic")
        self.assertEqual(r.returncode, 2)
        self.assertEqual(r.stdout, "")

    def test_module_api_for_sibling_scripts(self):
        sys.path.insert(0, str(SCRIPT.parent))
        try:
            import qg_nonce
        finally:
            sys.path.pop(0)
        self.assertEqual(qg_nonce.UNREADABLE, "QG_INPUT_UNREADABLE:")
        src = self.tmp / "src.txt"
        src.write_bytes(b"x\n")
        out = self.tmp / "slot.txt"
        value = qg_nonce.attach(str(src), str(out))
        self.assertEqual(qg_nonce.slot_value(str(out)), value)
        self.assertIsNone(qg_nonce.check("qg-slot-end: " + value, [str(out)]))
        self.assertEqual(qg_nonce.check("", []), "끝 값 없음")
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1)
        self._try(rd, rv, "security", 2, 1, answer=False)
        self.assertEqual(
            qg_nonce.check_reviewer(str(rd), str(rv), "security"),
            ("끝 값 없음", [(1, None), (2, "끝 값 없음")]))

    def test_check_reviewer_name_outside_form_is_usage(self):
        rd, rv = self._dirs()
        self._try(rd, rv, "security", 1, 1)
        for bad in ("Security", "sec/../x", "sec.*", ""):
            r = self._check_reviewer(rd, rv, bad)
            self.assertEqual(r.returncode, 2, bad)
            self.assertEqual(r.stdout, "", bad)
            # 칸 사본이 없다는 rc 2 와 사유 줄로 가른다.
            self.assertEqual(
                r.stderr, "[qg_nonce] 리뷰어 이름이 꼴 밖이다 — %s\n" % bad, bad)


if __name__ == "__main__":
    unittest.main()
