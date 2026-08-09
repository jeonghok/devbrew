"""AC22 — `codex_degraded`가 한 곳에서만 정의된다.

merge_review.py는 `not codex_avail`로, merge_brief_review.py는 `bool(codex_failed)`로
**독립 정의**하고 있었다. 같은 술어의 두 이름이 두 파일에서 따로 계산되면, 한쪽의
의미가 바뀔 때 다른 쪽이 조용히 갈라진다 — 이 사이클이 층④에서 고친 병과 같은 모양이다.
"""
import re
import unittest
from pathlib import Path

SD = Path(__file__).resolve().parents[1]
CANON = SD / "scripts" / "merge_review.py"
BRIEF = SD / "scripts" / "merge_brief_review.py"
# `"codex_degraded": <식>` 형태의 **계산 지점**. 키를 읽기만 하는 곳은 세지 않는다.
ASSIGN = re.compile(r'"codex_degraded"\s*:\s*(?!\s*$)')
# 딕셔너리 키로서의 **실제 emission 지점**. `codex_degraded_from`(정본 함수명)은
# "codex_degraded"를 접두사로 포함하지만 그 뒤에 닫는 따옴표가 오지 않으므로
# 이 패턴과는 매치하지 않는다 — substring 검사(`"codex_degraded" in text`)와 달리
# 정본 함수명 자체가 위양성 소비 증거가 되지 않는다.
EMIT = re.compile(r'"codex_degraded"\s*:')


class TestDegradeAliasSingleDefinition(unittest.TestCase):
    def test_canonical_defines_the_predicate(self):
        body = CANON.read_text(encoding="utf-8")
        self.assertIn("def codex_degraded_from(", body,
                      "정본 정의가 이름 붙은 함수여야 한다 — 인라인 식은 복제를 부른다")

    def test_brief_merger_imports_rather_than_redefines(self):
        body = BRIEF.read_text(encoding="utf-8")
        self.assertIn("codex_degraded_from", body,
                      "brief 병합기가 정본 정의를 써야 한다")
        # 인라인 재정의가 남아 있으면 안 된다.
        self.assertNotIn("bool(codex_failed)", body,
                         "독립 정의 잔존 — 두 곳이 따로 계산하면 조용히 갈라진다")

    def test_only_one_computation_site_across_the_plugin(self):
        sites = []
        for p in sorted((SD / "scripts").glob("*.py")):
            for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
                if ASSIGN.search(line) and "codex_degraded_from" not in line:
                    sites.append(f"{p.name}:{i}")
        self.assertEqual(sites, [],
                         f"정본을 거치지 않는 계산 지점: {sites}")

    def test_predicate_is_still_consumed(self):
        """음의 락에는 양의 짝이 필요하다 — 키를 통째로 지워도 위 검사는 통과한다.

        substring `"codex_degraded" in text`만 보면 정본 함수명 `codex_degraded_from`
        자체가 그 substring을 포함해 위양성이 난다 — emission 지점(dict key)을 전부
        지워도 함수 정의/호출부 텍스트가 남아 emitted가 줄지 않는다. 실제 emission
        지점(`"codex_degraded":` 딕셔너리 키)만 센다.
        """
        emitted = 0
        for p in sorted((SD / "scripts").glob("*.py")):
            if EMIT.search(p.read_text(encoding="utf-8")):
                emitted += 1
        self.assertGreaterEqual(emitted, 2,
                                "codex_degraded가 emit되는 곳이 사라졌다 (죽은 키)")


if __name__ == "__main__":
    unittest.main()
