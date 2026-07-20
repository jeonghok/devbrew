import os, subprocess, tempfile, unittest
from pathlib import Path

SCRIPTS_DIR = Path(__file__).resolve().parents[1]   # plugins/plugin-audit/scripts
SCRIPT = SCRIPTS_DIR / "check-integrity.sh"


def git(cwd, *a):
    subprocess.run(["git", *a], cwd=str(cwd), check=True,
                   capture_output=True, text=True)


def make_fixture(tmp):
    """격리된 임시 git repo. 실제 리포는 절대 건드리지 않는다."""
    tmp = Path(tmp)
    git(tmp, "init", "-q")
    git(tmp, "config", "user.email", "t@t")
    git(tmp, "config", "user.name", "t")
    # LD5 대상 구조
    pi = tmp / "plugins" / "myplugin"; pi.mkdir(parents=True)
    (pi / "plugin.json").write_text('{"name":"myplugin","version":"1.7.2"}\n', encoding="utf-8")
    (tmp / "docs" / "git-workflow").mkdir(parents=True)
    (tmp / "docs" / "git-workflow" / "g.md").write_text("x\n", encoding="utf-8")
    # 공유 marketplace 파일 (여러 플러그인 항목)
    cp = tmp / ".claude-plugin"; cp.mkdir()
    (cp / "marketplace.json").write_text('{"plugins":[{"name":"myplugin"},{"name":"other"}]}\n', encoding="utf-8")
    (tmp / ".gitignore").write_text(".DS_Store\n__pycache__/\n*.pyc\n.claude/\n", encoding="utf-8")
    git(tmp, "add", "-A")
    git(tmp, "commit", "-qm", "init")
    return tmp


def run_integrity(cwd, mode, out, *extra_args):
    r = subprocess.run(["bash", str(SCRIPT), mode, str(out), *extra_args],
                       cwd=str(cwd), capture_output=True, text=True)
    return r.returncode, r.stderr


class TestIntegrity(unittest.TestCase):
    def test_global_excludes_marketplace(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            out = fx / "m.txt"
            rc, err = run_integrity(fx, "global", out)
            self.assertEqual(rc, 0, err)
            manifest = out.read_text(encoding="utf-8")
            self.assertNotIn("marketplace.json", manifest,
                             "global 매니페스트가 공유 marketplace.json을 해싱한다 (형제 편집 오탐)")

    def test_global_stable_across_sibling_marketplace_edit(self):
        # 매니페스트 출력은 감사 대상 repo 밖(별도 tempdir)에 둔다: global 스코프는 "."(전체
        # repo)이므로, repo 루트 안에 out 파일을 두면 두 번째 실행이 첫 번째 실행의 산출물
        # 자체를 새 untracked 파일로 주워 marketplace.json과 무관한 거짓 diff를 만든다
        # (실제 사용도 항상 repo 밖 /tmp로 출력한다 — 이 실행 방식과 동일).
        with tempfile.TemporaryDirectory() as d, tempfile.TemporaryDirectory() as outdir:
            fx = make_fixture(d)
            a = Path(outdir) / "a.txt"; b = Path(outdir) / "b.txt"
            run_integrity(fx, "global", a)
            # 형제 플러그인 항목만 변경
            (fx / ".claude-plugin" / "marketplace.json").write_text(
                '{"plugins":[{"name":"myplugin"},{"name":"other","desc":"changed"}]}\n', encoding="utf-8")
            run_integrity(fx, "global", b)
            self.assertEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"),
                             "형제 marketplace 편집이 global 매니페스트를 바꿨다 (감사 무효 위험)")

    def test_ld5_excludes_machine_generated(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"
            run_integrity(fx, "ld5", a, "--target", "myplugin")
            # macOS가 디렉토리 열기만 해도 쓰는 .DS_Store 시뮬레이션 (ignored)
            (fx / "plugins" / "myplugin" / ".DS_Store").write_bytes(b"\x00junk")
            b = fx / "b.txt"
            run_integrity(fx, "ld5", b, "--target", "myplugin")
            self.assertEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"),
                             ".DS_Store가 LD5 매니페스트를 바꿨다 (정상 실행 사망)")

    def test_ld5_keeps_content_bearing_contamination(self):
        # D4 오염(내용 있는 ignored 파일)은 LD5가 잡아야 한다
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"
            run_integrity(fx, "ld5", a, "--target", "myplugin")
            contam = fx / "plugins" / "myplugin" / ".claude" / "state.md"
            contam.parent.mkdir(parents=True)
            contam.write_text("secret runtime state\n", encoding="utf-8")
            b = fx / "b.txt"
            run_integrity(fx, "ld5", b, "--target", "myplugin")
            self.assertNotEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"),
                                "LD5가 D4 오염(내용 있는 ignored)을 놓쳤다 — 백스톱의 존재 이유")

    def test_deterministic(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"; b = fx / "b.txt"
            run_integrity(fx, "ld5", a, "--target", "myplugin")
            run_integrity(fx, "ld5", b, "--target", "myplugin")
            self.assertEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"))

    def test_ld5_missing_target_exits_2(self):
        # ld5 모드는 --target 없이 실행되면 안 된다 (조용히 전체 repo를 스캔하는 대신
        # 즉시 exit 2로 실패해야 한다 — check-integrity.sh:77-80의 loud guard).
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            out = fx / "m.txt"
            rc, err = run_integrity(fx, "ld5", out)
            self.assertEqual(rc, 2, err)

    def test_ld5_extra_path_included(self):
        # --extra-path로 넘긴 스코프가 실제로 해싱되는지 확인한다. make_fixture가 이미
        # plugins/myplugin/ 밖에 내용 있는 파일(docs/git-workflow/g.md)을 두고 있으므로
        # 그대로 재사용한다 — 대조를 위해 --extra-path 없는 실행도 함께 확인.
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            without = fx / "without.txt"
            run_integrity(fx, "ld5", without, "--target", "myplugin")
            manifest_without = without.read_text(encoding="utf-8")
            self.assertNotIn("docs/git-workflow/g.md", manifest_without,
                             "--extra-path 없이도 ld5가 이미 docs를 포함한다 (대조 실패)")
            with_extra = fx / "with_extra.txt"
            run_integrity(fx, "ld5", with_extra, "--target", "myplugin", "--extra-path", "docs")
            manifest_with = with_extra.read_text(encoding="utf-8")
            self.assertIn("docs/git-workflow/g.md", manifest_with,
                          "--extra-path docs가 매니페스트에 반영되지 않았다")


if __name__ == "__main__":
    unittest.main()
