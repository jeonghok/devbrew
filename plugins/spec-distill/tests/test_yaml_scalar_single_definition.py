"""`_yaml_scalar` 가 이 플러그인 안에서 한 번만 정의되고, 그 하나가 합집합이다.

census #45(spec-distill 부분): 같은 이름의 함수가 셋 있었고 **셋 다 달랐다** —
빈 문자열 가드(`merge_review` 에만 없었다) · escape 문자 집합(`[]{}` 가
`brief_review_state` 에만 있었다) · None 처리(`brief_review_state` 에만 없었다).
갈라진 사본은 "한쪽만 고치는" 결함을 부르고, 실제로 두 merge 스크립트의 advisory
리터럴 5건이 인용 없이 나가 YAML flow sequence 로 읽히고 있었다.

이 락이 재는 것은 둘이다:
  ① 정의가 하나뿐이고 소비자들이 **그 하나를** 부른다(같은 함수 객체인지로 잰다 —
     텍스트 검사는 사본을 다른 이름으로 부르면 통과한다).
  ② 그 하나가 합집합의 행동을 갖는다. 각 assert 는 세 사본 중 **적어도 하나가
     갖지 못했던** 성질이다 — 이관 전 어느 본문으로 되돌려도 하나는 RED 가 된다.

`float` 분기는 assert 하지 않는다. `brief_review_state` 에만 없던 분기지만, 없어도
`str(v)` 경로가 같은 문자열을 내므로 어떤 입력으로도 구분되지 않는다 — 통과가 정답인
assert 는 이빨이 없다.
"""
import importlib
import re
import sys
import unittest
from pathlib import Path

SD = Path(__file__).resolve().parents[1]
SCRIPTS = SD / "scripts"
sys.path.insert(0, str(SD / "hooks"))
sys.path.insert(0, str(SCRIPTS))

CANON_MODULE = "hook_common"
DEF_RE = re.compile(r"^def _yaml_scalar\b", re.MULTILINE)
CALL_RE = re.compile(r"_yaml_scalar\s*\(")


def _plugin_py_files():
    """tests 를 뺀 이 플러그인이 **소유한** .py — 이름을 열거하지 않고 구조에서 얻는다.

    심볼릭 링크는 뺀다. `scripts/codex_findings_to_yaml.py` 는
    `shared/codex/codex_findings_to_yaml.py` 를 가리키는 링크이고, 그 파일은 세
    플러그인이 공유하는 정본이라 이 플러그인 안의 사본이 아니다(그쪽 `_yaml_scalar`
    는 여전히 네 번째 변종이지만 — ensure_ascii 기본값, `[]{}` 없음 — 이 락의 범위
    밖이다. 고치면 quality-gates·plugin-audit 의 출력이 함께 바뀐다).
    """
    return sorted(p for p in SD.rglob("*.py")
                  if "tests" not in p.parts and "__pycache__" not in p.parts
                  and not p.is_symlink())


def _consumer_modules():
    """`_yaml_scalar` 를 **호출**하는 scripts/ 모듈 이름. 정본과 링크는 뺀다."""
    out = []
    for p in sorted(SCRIPTS.glob("*.py")):
        if p.stem == CANON_MODULE or p.is_symlink():
            continue
        text = p.read_text(encoding="utf-8")
        # 정의줄을 지운 뒤 호출이 남는지 본다 — 사본이 자기 정의만 갖고 안 쓰는
        # 경우를 소비자로 세지 않기 위해서다.
        body = DEF_RE.sub("", text)
        if CALL_RE.search(body):
            out.append(p.stem)
    return out


class TestYamlScalarSingleDefinition(unittest.TestCase):
    def test_exactly_one_definition_in_the_plugin(self):
        sites = []
        for p in _plugin_py_files():
            for i, line in enumerate(p.read_text(encoding="utf-8").splitlines(), 1):
                if DEF_RE.match(line):
                    sites.append(f"{p.relative_to(SD)}:{i}")
        self.assertEqual(len(sites), 1,
                         f"`_yaml_scalar` 정의가 하나가 아니다: {sites}")
        self.assertTrue(sites[0].startswith(f"scripts/{CANON_MODULE}.py:"),
                        f"정의가 정본이 아닌 곳에 있다: {sites}")

    def test_consumers_call_the_same_function_object(self):
        consumers = _consumer_modules()
        # 축퇴 가드: 소비자를 하나도 못 찾으면 아래 루프가 공허하게 통과한다.
        self.assertGreaterEqual(len(consumers), 3,
                                f"소비자를 3개 미만으로 찾았다 — 검사가 공허하다: {consumers}")
        canon = importlib.import_module(CANON_MODULE)
        for name in consumers:
            mod = importlib.import_module(name)
            self.assertIs(getattr(mod, "_yaml_scalar", None), canon._yaml_scalar,
                          f"{name} 가 정본과 다른 `_yaml_scalar` 를 쓴다 (사본 재발)")

    # --- 합집합 행동 -------------------------------------------------------
    def _f(self):
        return importlib.import_module(CANON_MODULE)._yaml_scalar

    def test_empty_string_is_quoted(self):
        """`merge_review` 본문에 없던 가드. 인용 없는 빈 값을 YAML 은 null 로 읽는다."""
        self.assertEqual(self._f()(""), '""')

    def test_flow_indicators_are_quoted(self):
        """`brief_review_state` 에만 있던 `[]{}`. 실제로 advisory 5건이 이 모양이었다."""
        f = self._f()
        for raw in ("[spec-distill v0.20.0] review indeterminate — fail-safe",
                    "[bracket]", "{brace}", "a[b", "a]b", "a{b", "a}b"):
            self.assertEqual(f(raw), f'"{raw}"', f"인용되지 않았다: {raw!r}")

    def test_none_becomes_yaml_null(self):
        """`brief_review_state` 본문에 없던 분기 — 그쪽은 `None` 이라는 문자열을 냈다."""
        self.assertEqual(self._f()(None), "null")

    def test_plain_scalars_stay_unquoted(self):
        """음의 assert 들의 양의 짝 — '전부 인용' 으로 도망가면 여기서 잡힌다."""
        f = self._f()
        for raw in ("approved", "needs_revise", "inconclusive", "critic"):
            self.assertEqual(f(raw), raw)
        self.assertEqual(f(True), "true")
        self.assertEqual(f(False), "false")
        self.assertEqual(f(3), "3")

    def test_korean_is_not_escaped(self):
        """ensure_ascii=False — 사람이 읽는 게이트가 \\uXXXX 로 깨지면 안 된다."""
        out = self._f()("사유: 판정 불가")
        self.assertIn("판정 불가", out)
        self.assertNotIn("\\u", out)


if __name__ == "__main__":
    unittest.main()
