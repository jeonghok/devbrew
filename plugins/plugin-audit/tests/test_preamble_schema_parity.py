"""락 B (Task 15b, 결함 B) — preamble이 지시하는 응답 스키마와 추출기가 요구하는 스키마가
갈라지지 않는다.

결함 (원래 발견, V2 실측 2026-08-09): `codex_audit_to_json.py`의 COLLECTIONS(=4키)를
요구하는 쪽은 추출기뿐이었다. `codex-prompt-preamble.md`는 codex에게 "axis 질문에
findings를 file:line 증거와 함께 보고하라"는 산문 한 문장만 줬다 — JSON도, 펜스도, 네 키
이름 중 어느 것도 요구하지 않았다. codex는 산문으로 답했고 추출기는 malformed_json으로
degrade했다.

결함 (Fix round 1 재발견, V2 재실행 2026-08-09): 위를 고친 뒤에도 pa-audit은 여전히
codex_failed: true였다 — 이번엔 `schema_mismatch`. preamble이 "네 키, 각각 배열"까지는
말했지만 **배열 원소가 무엇이어야 하는지는 말하지 않았다.** codex는 `oq_answers`를
`["문자열"]`로 냈다 — 유효한 배열이지만 추출기는 원소가 dict이길 요구한다
(`codex_audit_to_json.py:97`, `[x for x in raw if isinstance(x, dict)]`). 산출자가 소비자의
요구를 여전히 다 듣지 못한 것 — 같은 병의 한 겹 아래.

**두 층의 락:**
  1. **키 parity** (`test_every_collection_key_appears_in_preamble`) — 이름이 preamble에
     등장하는가. **키 목록을 이 파일에 손으로 다시 적지 않는다** — `codex_audit_to_json.py`의
     COLLECTIONS를 **읽는다**. 손으로 다시 적으면 목록이 셋이 되고(추출기 / preamble / 이
     테스트) 그중 둘이 갈라져도 아무도 못 본다.
  2. **행동** (`test_preamble_example_satisfies_extractor`) — preamble이 담은 **예시 자체를
     추출해 추출기에 실제로 먹이고**, `codex_failed: false`가 나오는지 잰다. 키 이름 문구가
     아니라 실제 파싱 결과를 잰다 — Fix round 1의 원소-타입 결함은 키 parity 층으로는 잡히지
     않았다(이름은 다 있었으니까). 예시 추출 규약(마지막 펜스 블록)도 손으로 다시 적지 않는다
     — 추출기 자신의 `FENCE_RE`를 재사용한다(같은 이유: 두 규약이 갈라지면 이 락이 추출기가
     실제로 보는 것과 다른 것을 재게 된다).
"""
import importlib.util
import json
import subprocess
import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]          # plugins/plugin-audit
EXTRACTOR = ROOT / "scripts" / "codex_audit_to_json.py"
PREAMBLE = ROOT / "scripts" / "codex-prompt-preamble.md"


def _load_extractor_module():
    spec = importlib.util.spec_from_file_location("codex_audit_to_json", EXTRACTOR)
    if spec is None or spec.loader is None:
        # spec_from_file_location/loader는 이론상 None을 반환할 수 있다(예: 경로가
        # 없거나 로더가 결정 불가) — 그 경우 module_from_spec/exec_module에 그대로
        # 넘기면 AttributeError로 불명확하게 죽는다. 읽을 수 있는 실패로 바꾼다.
        raise RuntimeError(
            f"codex_audit_to_json.py를 모듈로 로드하지 못했다 (spec={spec!r}) — "
            f"경로 확인: {EXTRACTOR}")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)   # 모듈 최상위 실행뿐 — main()은 __main__ 가드 뒤라 안전
    return mod


def _event(text):
    return json.dumps({"type": "item.completed",
                        "item": {"type": "agent_message", "text": text}}) + "\n"


def _run_extractor(stdin_text):
    p = subprocess.run([sys.executable, str(EXTRACTOR)], input=stdin_text,
                        capture_output=True, text=True)
    return p.returncode, p.stdout, p.stderr


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

    def test_preamble_example_satisfies_extractor(self):
        """행동 락 (Fix round 1). preamble의 worked example을 **그대로** 추출기에 먹인다 —
        codex가 이 예시를 그대로 모방해 답하는 최선의 경우조차 추출기를 만족 못 시키면,
        실제 codex 응답이 만족할 리 없다(brief 지시대로 재실행하지 않고도 잡아야 하는 회귀).
        """
        mod = _load_extractor_module()
        preamble_text = PREAMBLE.read_text(encoding="utf-8")

        # 예시 추출 규약은 추출기 자신의 FENCE_RE를 재사용한다 — 이 파일에 별도 정규식을
        # 손으로 다시 적으면 "마지막 펜스 블록" 규약이 두 곳에서 따로 관리돼 갈라질 수 있다.
        self.assertTrue(hasattr(mod, "FENCE_RE"), "codex_audit_to_json.py에 FENCE_RE가 없다")
        blocks = mod.FENCE_RE.findall(preamble_text)
        self.assertTrue(blocks, "preamble에 펜스된 JSON 블록(worked example)이 없다 — "
                         "이 락이 재고자 있는 대상 자체가 사라졌다")
        example_json = blocks[-1]   # 추출기와 같은 관습: 마지막 펜스 블록

        # 추출기가 실제로 파싱 가능한 JSON인지도 여기서 확인 — 예시 자체가 깨진 JSON이면
        # 아래 subprocess 호출이 malformed_json으로 실패하고, 그 실패 사유가 이 assert에서
        # 먼저 드러나야 디버깅이 쉽다.
        try:
            json.loads(example_json)
        except json.JSONDecodeError as e:
            self.fail(f"preamble의 worked example이 유효한 JSON이 아니다: {e}")

        stdin_text = _event("worked example:\n```json\n" + example_json + "\n```\n")
        rc, out, err = _run_extractor(stdin_text)
        self.assertEqual(rc, 0, f"추출기가 비-0으로 종료 (stderr={err!r})")
        doc = json.loads(out)
        self.assertIs(
            doc.get("meta", {}).get("codex_failed"), False,
            f"preamble의 worked example이 추출기를 만족시키지 못했다 — "
            f"meta={doc.get('meta')!r}. preamble의 예시와 추출기(COLLECTIONS 원소 검증)가 "
            "갈라졌다는 뜻이다.")


if __name__ == "__main__":
    unittest.main()
