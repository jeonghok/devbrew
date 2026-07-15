import subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "check-no-verdict-injection.py"


def run_gate(*extra_surfaces):
    """게이트를 실행하고 (returncode, stderr)를 돌려준다."""
    r = subprocess.run(
        [sys.executable, str(SCRIPT), *extra_surfaces],
        capture_output=True, text=True, cwd=str(REPO),
    )
    return r.returncode, r.stderr


class TestBannedSync(unittest.TestCase):
    def _scan_temp(self, content):
        """임시 표면 파일 하나에 대해 게이트를 돌린다 (실제 리포 표면과 섞이지 않게 절대경로 인자로).

        게이트는 하드코딩된 실제 SURFACES를 항상 함께 스캔하므로 전역 rc로는 이 표면만
        격리할 수 없다. 대신 게이트가 각 히트를 `<abspath>:<line>`로 출력하는 점을 이용해,
        이 임시 파일의 절대경로가 stderr에 나타나는지로 '이 표면이 잡혔는가'를 판정한다.
        """
        with tempfile.TemporaryDirectory() as d:
            surf = Path(d) / "surface.md"
            surf.write_text(content, encoding="utf-8")
            rc, err = run_gate(str(surf))
            return rc, err, str(surf)

    def test_cheolhoe_dwaem_is_caught(self):
        # D2 "이미 철회됨" 형태
        rc, err, surf = self._scan_temp("- **D2** ❌ 이미 철회됨. 다시 열지 마라.\n")
        self.assertIn(surf, err, f"'철회됨'/'다시 열지 마'가 이 표면에서 안 잡혔다:\n{err}")

    def test_cheolhoe_bare_catches_d4_form(self):
        # D4 "주장은 철회됨" — '이미 철회' 앵커로는 놓치는 형태 (codex #1)
        rc, err, surf = self._scan_temp("유출 메커니즘 주장은 철회됨 — 재귀 복사 아님.\n")
        self.assertIn(surf, err, f"D4 형태 '주장은 철회됨'을 놓쳤다:\n{err}")

    def test_sasil_oryu_is_caught(self):
        rc, err, surf = self._scan_temp("최초 브리핑의 '존재하지 않는다'는 사실 오류다.\n")
        self.assertIn(surf, err, f"'사실 오류'가 안 잡혔다:\n{err}")

    def test_dasi_yeolji_ma_is_caught(self):
        # '다시 열지 마' 격리 이빨 — 이 문면엔 '철회'·'사실 오류'가 없어 이 패턴에만 매칭 (codex #2)
        rc, err, surf = self._scan_temp("이 판정은 이미 확정됐다. 다시 열지 마라.\n")
        self.assertIn(surf, err, f"'다시 열지 마'가 이 표면에서 안 잡혔다:\n{err}")

    def test_clean_surface_is_green(self):
        # 주장 + 포인터만 — 판정 없음
        rc, err, surf = self._scan_temp("- **D2** README:79가 'PR 생성 시 qg 트리거'를 주장한다. 훅 본문을 열어 판정하라.\n")
        self.assertNotIn(surf, err, f"중립 문면이 이 표면에서 FP로 잡혔다:\n{err}")

    def test_real_surfaces_are_green(self):
        # 커밋된 실제 주입 표면 3종에 판정 주입이 남아 있지 않다 (Task 2 이후 유지되는 회귀 락)
        rc, err = run_gate()
        self.assertEqual(rc, 0, f"실제 주입 표면에 판정이 새어 있다:\n{err}")


if __name__ == "__main__":
    unittest.main()
