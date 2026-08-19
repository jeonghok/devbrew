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
import json
import re
import sys
import unittest
from pathlib import Path

SD = Path(__file__).resolve().parents[1]
SCRIPTS = SD / "scripts"
sys.path.insert(0, str(SCRIPTS))

CANON_MODULE = "hook_common"
DEF_RE = re.compile(r"^def _yaml_scalar\b", re.MULTILINE)
CALL_RE = re.compile(r"_yaml_scalar\s*\(")


def _plugin_py_files():
    """tests 를 뺀 이 플러그인이 **소유한** .py — 이름을 열거하지 않고 구조에서 얻는다.

    심볼릭 링크는 뺀다. `scripts/codex_findings_to_yaml.py` 는
    `shared/codex/codex_findings_to_yaml.py` 를 가리키는 링크이고, 그 파일은 두
    플러그인(quality-gates·spec-distill)이 공유하는 정본이라 이 플러그인 안의 사본이
    아니다 — **정의 개수**를 세는 이 검사의 범위 밖이다.

    2026-08-19: 그 정본의 `_yaml_scalar` 는 한때 네 번째 변종이었다(`[]{}` 없음 +
    빈 문자열 가드 없음). 지금은 인용 **여부**를 정하는 두 상수가 이 파일의 정본과
    같은 값이고, 그것을 `TestCanonicalAgreesWithSharedCodex` 가 잰다. 남은 의도된
    차이는 인용 **표기** 하나뿐이다 — 정본은 `ensure_ascii` 기본값(True), 여기는
    False. 왕복은 어느 쪽이든 원문을 그대로 낸다.
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

    def test_leading_indicators_are_quoted(self):
        """문자 멤버십 축이 못 잡는 **위치** 축 (2026-08-19).

        세 사본의 합집합(`:#"'\\n[]{}`)에는 `-` 도 backtick 도 없다. `- dash` 는
        인용 없이 나가면 block sequence 시작으로 읽혀 ScannerError 로 죽는다 —
        합집합 이관 뒤에도 남아 있던 잔여 구멍이다. 여기 값들은 전부 첫 글자를
        0x20–0x7E 전수로 돌려 얻은 "깨지는 첫 글자" 집합에서 왔다(상상이 아니다).
        """
        f = self._f()
        for raw in ("- dash", "? question", "@decorator 누락", "*args 처리 누락",
                    "!important 무시", "`handler()` 가 null 을 반환한다",
                    "| pipe", "> quote", ", comma", "% percent", "& anchor"):
            self.assertEqual(f(raw), json.dumps(raw, ensure_ascii=False),
                             f"첫 글자 지시자가 인용되지 않았다: {raw!r}")

    def test_indicator_not_at_first_position_stays_unquoted(self):
        """위치 축의 **음의 짝** — `_YAML_UNSAFE_FIRST` 를 멤버십 축으로 넓히면 RED.

        `codex-reviewer` · `fail-safe` 처럼 하이픈을 품은 값은 이 리포 전역에 있고,
        이들이 인용되기 시작하면 정본 출력의 `agent: codex-reviewer` 같은 줄이 통째로
        모양을 바꾼다. 첫 글자가 아닌 지시자는 bare 로 남아야 한다.
        """
        f = self._f()
        for raw in ("codex-reviewer", "fail-safe", "a*b", "a?b", "a@b", "a,b",
                    "a|b", "a>b", "a%b", "a&b", "a!b"):
            self.assertEqual(f(raw), raw, f"첫 글자가 아닌데 인용됐다: {raw!r}")

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


class TestCanonicalAgreesWithSharedCodex(unittest.TestCase):
    """이 플러그인의 `_yaml_scalar` 와 `shared/codex/` 정본이 **같이 인용한다**.

    census #45 는 두 태스크에 걸쳐 있었다 — Task 22 가 spec-distill 세 사본을
    합집합으로 모으고, Task 17 이 `codex_findings_to_yaml.py` 두 벌을 심볼릭 링크로
    하나로 만들었다. 그래서 **사본은 고쳐지고 그 사본들이 모여야 할 정본은 안 고쳐진**
    상태가 남았다(2026-08-19 실측: 정본은 `[CRITICAL] …` 를 bare 로 내보내 문서 전체가
    ParserError). 이 락은 그 역전이 다시 생기는 것을 막는다.

    무엇을 재고 무엇을 안 재는가: 인용 **여부**(어떤 입력을 인용하는가)는 같아야 하고,
    인용 **표기**(`ensure_ascii`)는 다를 수 있다 — 정본은 True, 여기는 False. 표기
    차이는 왕복을 바꾸지 않는다. 그래서 아래는 `json.loads` 로 되돌린 뒤 비교한다.
    """

    def _canon_pair(self):
        sys.path.insert(0, str(SCRIPTS))
        shared = importlib.import_module("codex_findings_to_yaml")
        local = importlib.import_module(CANON_MODULE)
        return local._yaml_scalar, shared._yaml_scalar

    def test_both_quote_the_same_inputs(self):
        local, shared = self._canon_pair()
        # 축을 먼저 적는다: ① 첫 글자 지시자 ② 문자열 내부 지시자 ③ 빈/공백
        # ④ 인용이 필요 없는 값. 각 축의 값들을 돌려 "인용했는가"만 비교한다.
        cases = [
            "[CRITICAL] 대괄호로 시작하는 요약", "[spec-distill] advisory",
            "{brace}", "- dash", "? q", "@a", "*a", "!a", "`code`", "| p",
            "> q", ", c", "% p", "& a",
            "", " lead", "trail ", "a: b", "a # b", 'say "hi"', "it's",
            "array[0] 범위 초과", "done}", "a[b", "a]b", "a{b", "a}b",
            "approved", "needs_revise", "codex-reviewer", "fail-safe",
            "a*b", "a?b", "a,b", "a|b", "plain summary", "한국어 요약",
        ]
        # 축퇴 가드: 두 진영(인용/비인용)이 모두 비면 아래 비교가 공허하다.
        quoted = [c for c in cases if local(c).startswith('"')]
        bare = [c for c in cases if not local(c).startswith('"')]
        self.assertGreaterEqual(len(quoted), 20, "인용 사례가 너무 적다 — 검사가 공허하다")
        self.assertGreaterEqual(len(bare), 5, "비인용 사례가 없다 — '전부 인용' 으로 도망갔다")
        for c in cases:
            with self.subTest(value=c):
                a, b = local(c), shared(c)
                self.assertEqual(a.startswith('"'), b.startswith('"'),
                                 f"인용 여부가 갈렸다: local={a!r} shared={b!r}")
                # 표기가 달라도(ensure_ascii) 되돌린 값은 같아야 한다.
                da = json.loads(a) if a.startswith('"') else a
                db = json.loads(b) if b.startswith('"') else b
                self.assertEqual(da, db)
                self.assertEqual(da, c, "인용/역인용 왕복이 원문을 바꿨다")

    def test_the_two_unsafe_sets_are_literally_equal(self):
        """행동 락의 구조적 짝 — 위 케이스 목록이 놓친 문자를 잡는다.

        `test_both_quote_the_same_inputs` 는 내가 떠올린 값만 돈다. 상수 자체를
        비교해야 내가 안 떠올린 문자에서 갈라지는 것을 잡는다.
        """
        sys.path.insert(0, str(SCRIPTS))
        shared = importlib.import_module("codex_findings_to_yaml")
        local = importlib.import_module(CANON_MODULE)
        for name in ("_YAML_UNSAFE_ANYWHERE", "_YAML_UNSAFE_FIRST"):
            a = getattr(local, name, None)
            b = getattr(shared, name, None)
            self.assertIsNotNone(a, f"{CANON_MODULE} 에 {name} 이 없다")
            self.assertIsNotNone(b, f"정본에 {name} 이 없다")
            self.assertEqual(a, b, f"{name} 이 정본과 다르다 (drift 재발)")
        # 두 상수가 겹치면 "위치 축" 이 사실상 죽은 코드가 된다.
        self.assertEqual(set(local._YAML_UNSAFE_ANYWHERE) & set(local._YAML_UNSAFE_FIRST),
                         set(), "두 집합이 겹친다 — 위치 축이 무의미해진다")


if __name__ == "__main__":
    unittest.main()
