"""finishing.md 의 bash 펜스는 앞 펜스의 변수를 물려받지 못한다.

Bash 도구는 호출마다 새 셸이고 유지되는 것은 cwd 뿐이다. 이 문서의 절차는 `Skill` 호출과
`AskUserQuestion` 을 사이에 끼고 여러 셸에 걸쳐 돈다 — 한 펜스가 앞 펜스에서만 정의된
`$ROOT`·`$harness_sid` 같은 값을 쓰면 빈 문자열로 전개돼 `'/scripts/…'` 같은 경로가 만들어지고,
실패는 rc≠0 하나로 조용히 지나간다. 이 락이 생긴 실측(지금은 삭제된 사후 측정 단계):

    $ bash <<'B'
    > python3 "$PR/scripts/depth_record.py" ...
    > B
    can't open file '/scripts/depth_record.py': [Errno 2]   rc=2

그 단계는 사라졌지만 불변식은 남는 펜스(Step A 5 게이트 · Step A.5 · B-0)에 그대로 걸린다.

**이 락은 열거가 아니라 도출이다.** 변수 이름 목록을 핀하지 않고, 펜스마다 «쓰인 변수»와
«그 펜스가 정의한 변수»를 각각 뽑아 차집합을 본다. 새 블록이 생기거나 변수 이름이 바뀌어도
축이 그대로 산다 — 열거였다면 다음 블록은 검사 밖이었을 것이다.

환경에서 오는 것만 예외다(`ENV_PROVIDED`). 이 집합을 넓히는 것은 곧 검사를 무르게 하는
것이므로, 항목마다 «누가 그 값을 넣어 주는가» 를 답할 수 있어야 한다.
"""
import re
import unittest
from pathlib import Path

FIN = (Path(__file__).resolve().parent.parent / "skills" / "conducting-interview"
       / "references" / "finishing.md")

# 하니스가 넣어 주는 값. `CLAUDE_PLUGIN_ROOT` 는 플러그인 실행 시 Claude Code 가 export 한다
# (그래서 문서의 블록들도 `${CLAUDE_PLUGIN_ROOT:-...}` 로 fallback 을 단다).
ENV_PROVIDED = {"CLAUDE_PLUGIN_ROOT"}

FENCE_OPEN = re.compile(r"^\s*```bash\s*$")
FENCE_CLOSE = re.compile(r"^\s*```\s*$")
# `$VAR` · `${VAR}` — `$?`·`$1` 같은 셸 특수변수는 이름 규칙에 안 맞아 자연히 빠진다.
USE_RE = re.compile(r"\$\{?([A-Za-z_][A-Za-z0-9_]*)\}?")
ASSIGN_RE = re.compile(r"^\s*([A-Za-z_][A-Za-z0-9_]*)=")


def bash_fences(text):
    """(시작줄, 끝줄, 본문줄들) 목록. 열거가 아니라 파일에서 도출한다."""
    out, cur, inb, start = [], [], False, 0
    for i, ln in enumerate(text.splitlines(), 1):
        if not inb and FENCE_OPEN.match(ln):
            inb, cur, start = True, [], i
            continue
        if inb and FENCE_CLOSE.match(ln):
            out.append((start, i, cur))
            inb = False
            continue
        if inb:
            cur.append(ln)
    return out


class FinishingBlockScope(unittest.TestCase):
    def setUp(self):
        self.text = FIN.read_text(encoding="utf-8")
        self.fences = bash_fences(self.text)

    def test_corpus_is_actually_read(self):
        """양성 대조 — 펜스를 못 찾으면 아래 단언이 통째로 공허해진다.

        부재 검사만으로 된 락은 대상 파일을 지워도 통과한다. 여기서는 '펜스가 셋 이상 있고
        그중 게이트 호출(check_brief.py)을 담은 것이 있다' 를 먼저 못 박는다.
        """
        self.assertGreaterEqual(len(self.fences), 3,
                                "finishing.md 에서 bash 펜스를 셋 이상 못 찾았다 — 추출기가 깨졌다")
        joined = "\n".join("\n".join(b) for _, _, b in self.fences)
        self.assertIn("check_brief.py", joined,
                      "게이트 호출이 어떤 bash 펜스에도 없다 — 락이 겨눌 대상이 사라졌다")

    def test_no_variable_carried_across_fences(self):
        """펜스마다: 쓰인 변수 ⊆ 그 펜스가 정의한 변수 ∪ 환경 제공."""
        offenders = []
        for start, end, body in self.fences:
            used, assigned = set(), set()
            for ln in body:
                m = ASSIGN_RE.match(ln)
                if m:
                    assigned.add(m.group(1))
                used.update(USE_RE.findall(ln))
            unbound = used - assigned - ENV_PROVIDED
            if unbound:
                offenders.append((start, end, sorted(unbound)))
        self.assertEqual(
            offenders, [],
            "블록 간에 변수를 나르는 bash 펜스가 있다 (줄범위, 미정의 변수): %r\n"
            "각 펜스는 머리에서 경로를 다시 도출해야 한다 — Bash 도구는 호출마다 새 셸이다."
            % (offenders,))


if __name__ == "__main__":
    unittest.main()
