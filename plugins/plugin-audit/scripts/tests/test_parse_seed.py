import json, subprocess, sys, tempfile, unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "parse-seed.py"

SEED = """---
target: quality-gates
---
## 추가 scope
- docs/qg-notes.md
- .claude-plugin/marketplace.json

## Open Questions
- OQ1: 축3 — runtime gate가 PreToolUse로 승격돼야 하나?

## 후보 단서
- D1 (축1): README가 없는 기능을 광고 — plugins/quality-gates/README.md:12
"""


def run(path):
    r = subprocess.run([sys.executable, str(SCRIPT), str(path)],
                       capture_output=True, text=True)
    return r


class TestParseSeed(unittest.TestCase):
    def test_extracts_all_sections(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "seed.md"
            p.write_text(SEED, encoding="utf-8")
            r = run(p)
            self.assertEqual(r.returncode, 0)
            obj = json.loads(r.stdout)
            self.assertEqual(obj["target"], "quality-gates")
            self.assertIn("docs/qg-notes.md", obj["extra_scope"])
            self.assertEqual(obj["open_questions"][0]["id"], "OQ1")
            self.assertEqual(obj["open_questions"][0]["axis"], 3)
            c = obj["candidate_clues"][0]
            self.assertEqual((c["id"], c["axis"], c["file"], c["line"]),
                             ("D1", 1, "plugins/quality-gates/README.md", 12))

    def test_missing_file_is_empty_not_crash(self):
        r = run(Path("/nonexistent/seed.md"))
        self.assertEqual(r.returncode, 0)
        self.assertEqual(json.loads(r.stdout), {})
        self.assertIn("seed", r.stderr.lower())

    def test_malformed_clue_in_section_warns(self):  # SF1 (/qg 2026-07-20 round-2)
        # silent-failure-hunter: 인식된 섹션 안에서 CLUE_RE/OQ_RE에 안 맞는 불릿(em-dash·file:line 누락 등)이
        # 조용히 드롭된다 — 사용자의 감사 단서가 흔적 없이 증발(CONTRACT rule 11을 입력에 위반). 경고를 내야.
        seed = ("## 후보 단서\n"
                "- D1 (축1): 정상 단서 — plugins/x/README.md:12\n"
                "- D2 (축2): 형식 틀림, dash도 file line도 없음\n")
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "seed.md"; p.write_text(seed, encoding="utf-8")
            r = run(p)
            self.assertEqual(r.returncode, 0)
            obj = json.loads(r.stdout)
            self.assertEqual(len(obj.get("candidate_clues", [])), 1, "정상 단서 1개만 파싱돼야")
            self.assertIn("파싱 실패", r.stderr, "드롭된 malformed 불릿에 경고 없음 (조용한 증발)")

    def test_nonempty_unparseable_seed_has_distinct_diagnostic(self):  # SF1
        # 완전히 인식 불가한 non-empty seed는 {}를 내지만 absent-seed의 {}와 **구별되는** 진단을 남겨야
        # (둘이 동일 출력이면 사용자 단서가 조용히 사라진 걸 모른다).
        seed = "# 그냥 산문\n임의의 텍스트, 인식되는 섹션 헤더가 하나도 없음.\n"
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "seed.md"; p.write_text(seed, encoding="utf-8")
            r = run(p)
            self.assertEqual(r.returncode, 0)
            self.assertEqual(json.loads(r.stdout), {})
            self.assertIn("인식된 항목이 0개", r.stderr,
                          "non-empty이나 파싱 0인 seed가 absent-seed와 구별되는 진단 없음")


if __name__ == "__main__":
    unittest.main()
