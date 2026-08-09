"""락 B (Task 15b, 결함 B) — preamble이 지시하는 응답 키와 추출기가 요구하는 키가
갈라지지 않는다.

결함: `codex_audit_to_json.py`의 COLLECTIONS(=4키)를 요구하는 쪽은 추출기뿐이었다.
`codex-prompt-preamble.md`는 codex에게 "axis 질문에 findings를 file:line 증거와 함께
보고하라"는 산문 한 문장만 줬다 — JSON도, 펜스도, 네 키 이름 중 어느 것도 요구하지
않았다(V2 실측, 2026-08-09). codex는 산문으로 답했고 추출기는 malformed_json으로
degrade했다. 합성 축 파일 탓이 아니라 실사용에서도 매번 재현되는 구조적 결함이었다.

**키 목록을 이 파일에 손으로 다시 적지 않는다.** `codex_audit_to_json.py`가 이미
COLLECTIONS를 갖고 있다 — 여기서 그것을 **읽는다**. 손으로 다시 적으면 목록이 셋이
되고(추출기 / preamble / 이 테스트) 그중 둘이 갈라져도 아무도 못 본다 — 정확히
결함 B가 재발하는 경로다(브리프 §락 B).
"""
import importlib.util
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]          # plugins/plugin-audit
EXTRACTOR = ROOT / "scripts" / "codex_audit_to_json.py"
PREAMBLE = ROOT / "scripts" / "codex-prompt-preamble.md"


def _load_extractor_module():
    spec = importlib.util.spec_from_file_location("codex_audit_to_json", EXTRACTOR)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)   # 모듈 최상위 실행뿐 — main()은 __main__ 가드 뒤라 안전
    return mod


class TestPreambleSchemaParity(unittest.TestCase):
    def test_collections_is_derivable_and_has_more_than_one_key(self):
        # positive: 도출 자체가 살아있는가 — COLLECTIONS가 비었거나 1개뿐이면
        # 아래 판정은 vacuous PASS일 수 있다(mB의 계측기 붕괴 방지).
        mod = _load_extractor_module()
        self.assertTrue(hasattr(mod, "COLLECTIONS"), "codex_audit_to_json.py에 COLLECTIONS가 없다")
        self.assertIsInstance(mod.COLLECTIONS, tuple)
        self.assertGreater(len(mod.COLLECTIONS), 1,
                            f"COLLECTIONS가 {len(mod.COLLECTIONS)}개뿐 — 도출 계측기가 붕괴했을 수 있다")

    def test_every_collection_key_appears_in_preamble(self):
        mod = _load_extractor_module()
        text = PREAMBLE.read_text(encoding="utf-8")
        missing = [k for k in mod.COLLECTIONS if k not in text]
        self.assertEqual(
            missing, [],
            f"preamble에 등장하지 않는 추출기 키: {missing} — 추출기가 요구하는 응답 스키마와 "
            "preamble이 codex에게 지시하는 스키마가 갈라졌다. 추출기에 키를 추가했다면 "
            "preamble도 같은 커밋에서 고쳐라(Task 15b 결함 B와 같은 재발 경로).")


if __name__ == "__main__":
    unittest.main()
