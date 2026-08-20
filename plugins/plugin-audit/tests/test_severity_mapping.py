"""severity 어휘 통일의 매핑 락.

무손실 rename 이 아니다. 매핑을 잘못 잡으면 **머지 차단 임계가 이동한다** —
quality-gates/scripts/synthesize_findings.py:388 이 미지 severity 를 SUGGESTION 으로
강등하므로, plugin-audit 이 HIGH 를 계속 내보내면 그것이 조용히 최하위로 떨어진다.

이 락이 재는 것 셋:
  A) plugin-audit 의 어휘가 {CRITICAL, IMPORTANT, SUGGESTION} 안에 있다.
  B) 옛 어휘(HIGH/MEDIUM/LOW)가 **정렬 테이블에서 사라졌다** — 남아 있으면 두 어휘가
     공존하며 어느 쪽이 정본인지 확정되지 않는다.
  C) 정렬 **순서**가 보존된다. 어휘만 바꾸고 순위를 뒤집으면 리포트가 거꾸로 정렬된다.
"""
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / "plugins" / "plugin-audit" / "scripts"))

CANON = ("CRITICAL", "IMPORTANT", "SUGGESTION")


def _sev_rank_table():
    src = (ROOT / "plugins/plugin-audit/scripts/render-audit-report.py").read_text(encoding="utf-8")
    ns = {}
    for line in src.splitlines():
        if line.startswith("SEV_RANK"):
            exec(line, ns)  # noqa: S102 — 이 한 줄은 리터럴 dict 다
            break
    return ns.get("SEV_RANK")


class SeverityVocabulary(unittest.TestCase):
    def test_a_vocabulary_is_canonical(self):
        table = _sev_rank_table()
        self.assertIsNotNone(table, "SEV_RANK 를 찾지 못했다 — 이 락이 vacuous 하다")
        self.assertEqual(set(table), set(CANON),
                         f"어휘가 정본과 다르다: {sorted(table)}")

    def test_b_old_vocabulary_gone(self):
        table = _sev_rank_table()
        for old in ("HIGH", "MEDIUM", "LOW"):
            self.assertNotIn(old, table, f"옛 어휘 '{old}' 가 정렬 테이블에 남아 있다")

    def test_c_order_preserved(self):
        # 비감소(ranks == sorted(ranks))만으로는 부족하다 — IMPORTANT 와 SUGGESTION 이
        # 같은 rank(예: 둘 다 1)로 붕괴해도 [0,1,1] == sorted([0,1,1])이라 통과한다.
        # 엄격 단조증가(ascending 이자 distinct)를 두 조건으로 나눠 검증한다 — 실패
        # 메시지가 "역전"인지 "붕괴"인지 구분되게. 미래에 4번째 등급이 추가돼도 살아남도록
        # 리터럴 랭크값([0,1,2])은 pin하지 않는다 (Task 25의 `major == "3"` 핀이 stale-red로
        # 죽었던 전례 — 불변식만 핀, 리터럴은 unpin).
        table = _sev_rank_table()
        ranks = [table[s] for s in CANON]
        self.assertEqual(ranks, sorted(ranks),
                         "정렬 순위가 CRITICAL < IMPORTANT < SUGGESTION 순으로 오름차순이 "
                         "아니다 (역전)")
        self.assertEqual(len(set(ranks)), len(ranks),
                         "정렬 순위에 중복이 있다 — 서로 다른 severity 가 같은 rank 로 "
                         "붕괴했다 (예: IMPORTANT 와 SUGGESTION 이 같은 값)")

    def test_d_preamble_advertises_canonical_vocabulary(self):
        """codex 에게 주는 프리앰블이 옛 어휘를 광고하면 codex 가 그것을 낸다.

        정의부만 고치고 인용부를 남기면, 통일했다고 말하면서 실제로는 옛 어휘가
        계속 유입된다 — 삭제된 규칙이 거짓 인용을 남기는 형태.
        """
        pre = (ROOT / "plugins/plugin-audit/scripts/codex-prompt-preamble.md").read_text(encoding="utf-8")
        self.assertIn("CRITICAL", pre, "프리앰블에 severity 어휘 서술이 없다 — 이 락이 vacuous")
        for old in ("`HIGH`", "`MEDIUM`", "`LOW`"):
            self.assertNotIn(old, pre, f"프리앰블이 옛 어휘 {old} 를 여전히 광고한다")


if __name__ == "__main__":
    unittest.main()
