import subprocess
import sys
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "scripts" / "compute_issue_id.py"


def run(cat, sec):
    r = subprocess.run(
        [sys.executable, str(SCRIPT), cat, sec],
        capture_output=True, text=True,
    )
    return r.returncode, r.stdout.strip()


class TestComputeIssueId(unittest.TestCase):
    def test_deterministic(self):
        rc1, id1 = run("ambiguity", "#2-goals")
        rc2, id2 = run("ambiguity", "#2-goals")
        self.assertEqual(rc1, 0)
        self.assertEqual(id1, id2)  # AC8: same input → same id

    def test_shape(self):
        _, id1 = run("isolation", "#6-components")
        self.assertEqual(len(id1), 12)  # 12 hex chars
        self.assertTrue(all(c in "0123456789abcdef" for c in id1))

    def test_different_section_differs(self):
        _, a = run("ambiguity", "#2-goals")
        _, b = run("ambiguity", "#3-non-goals")
        self.assertNotEqual(a, b)  # AC8: different section → different id

    def test_different_category_differs(self):
        _, a = run("ambiguity", "#2-goals")
        _, b = run("testing", "#2-goals")
        self.assertNotEqual(a, b)

    def test_importable(self):
        sys.path.insert(0, str(SCRIPT.parent))
        import compute_issue_id
        self.assertEqual(
            compute_issue_id.compute("ambiguity", "#2-goals"),
            run("ambiguity", "#2-goals")[1],
        )

    def test_arg_error(self):
        r = subprocess.run([sys.executable, str(SCRIPT), "only-one"],
                           capture_output=True, text=True)
        self.assertNotEqual(r.returncode, 0)  # usage error


if __name__ == "__main__":
    unittest.main()
