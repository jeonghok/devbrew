#!/usr/bin/env python3
"""variant-of 관계 — 변형 정본이 기준 정본과 «정해진 차이만» 갖는가.

변형(V)은 머리 20줄 안의 `# variant-of: <기준 경로>` 마커로 기준(B)을 가리킨다. 관계는 두 조건이
함께 설 때만 성립한다:
  ① frontmatter — 최상위 키 집합이 같고, `name`·`description`·`tools` 밖의 키는 값 블록(키 줄 +
     이어지는 들여쓴·빈 줄 **전부**)이 줄 단위로 같다. 키 인식은 YAML 과 같다 — 컬럼-0 의 비지 않은
     줄(주석 제외)은 전부 키 줄이고, 따옴표 키(`"k":` · `'k':`)와 콜론 앞 공백 키(`k :`)도 이름으로
     정규화해 센다. 키로 못 읽는 컬럼-0 줄은 판정 불가다(앞 키의 값으로 흡수하면 frontmatter 에 숨은
     키가 관계를 통과한다). 컬럼-0 주석 줄(`# copy-of:`·`# variant-of:`)은 비교에서 뺀다. `tools` 는 자유 키다 —
     관계는 도구 표면을 판정하지 않는다(웹 사본의 도구 집합은 test_docreview_agents.sh 와
     test_brief_agents.sh 가 doc-critic 에서 도출한 집합 등식으로 잰다).
  ② 본문(frontmatter 닫힘 뒤) — V 는 B 에 연속한 한 덩어리를 끼워 넣은 것뿐이다. B 의 어느 줄도
     바뀌거나 빠지지 않고, 끼운 덩어리에는 빈 줄이 아닌 줄이 있다.

범위 — 마커는 agent 정의에만 쓴다. 변형은 `shared/<x>/agents/*.md`(정본) 또는
`plugins/<x>/agents/*.md`(그 배포 사본)이고, 대상은 `shared/<x>/agents/*.md` 정본이다.

소비자 셋: shared/tests/test_no_new_duplication.sh(범위 안에서 관계가 서는 쌍만 중복 면제) ·
shared/tests/test_docreview_agents.sh(웹 사본 drift 락) · shared/tests/test_variant_of_contract.sh
(마커 전수 감사 · 판정기 음성 fixture · 범위 음성 셀).

CLI:
  variant_of.py marker <file>              → 마커가 가리키는 경로(없으면 빈 출력) · rc 0
  variant_of.py check <variant> <base>     → "OK\\t<끼운 줄 수>" rc 0 | "FAIL\\t<사유>" rc 1
  variant_of.py inserted <variant> <base>  → 끼운 덩어리 원문 rc 0 | "FAIL\\t<사유>" rc 1
  variant_of.py audit <코퍼스 목록 파일>     → 마커 파일마다 "<경로>\\t<대상>\\tOK" 또는
                                              "<경로>\\t<대상>\\tFAIL:<사유>" · rc 0
python 3.9 · stdlib 만 쓴다.
"""
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

MARKER = re.compile(r'^\s*(?:#|//|<!--)\s*variant-of:\s*(\S+)')
HEAD_WINDOW = 20
FREE_KEYS = ("name", "description", "tools")
# 키 뒤의 콜론 — YAML 은 `:` 다음에 공백이나 줄 끝이 와야 키로 읽는다(`a:b: c` 의 키는 `a:b`).
_COLON_AFTER_QUOTED = re.compile(r'[ \t]*:(?:[ \t]|$)')
_PLAIN_COLON = re.compile(r':(?:[ \t]|$)')
# 평문 키로 시작할 수 없는 YAML 지시 문자(흐름 · 앵커 · 태그 · 블록 스칼라 · 예약) — 그런 컬럼-0 줄은
# 키로 못 읽는다.
_NOT_PLAIN_START = tuple("[]{},&*!|>%@`")
_AGENT_DEF = re.compile(r'^(?:shared|plugins)/[^/]+/agents/[^/]+\.md$')
_CANONICAL_AGENT = re.compile(r'^shared/[^/]+/agents/[^/]+\.md$')


def in_agent_scope(path: str) -> bool:
    """변형(과 그 짝)이 설 수 있는 자리 — agent 정의 파일(정본 또는 배포 사본)."""
    return bool(_AGENT_DEF.match(path))


def canonical_agent(path: str) -> bool:
    """마커가 가리킬 수 있는 자리 — `shared/` 의 agent 정본."""
    return bool(_CANONICAL_AGENT.match(path))


def marker(path) -> Optional[str]:
    """머리 20줄 안의 variant-of 마커가 가리키는 경로. 없거나 못 읽으면 None."""
    try:
        with open(path, encoding="utf-8") as fh:
            for i, line in enumerate(fh):
                if i >= HEAD_WINDOW:
                    break
                m = MARKER.match(line)
                if m:
                    return m.group(1).rstrip("->").strip()
    except (OSError, UnicodeDecodeError):
        return None
    return None


def _split(text: str) -> Optional[Tuple[List[str], List[str]]]:
    """(frontmatter 줄, 본문 줄). frontmatter 가 없으면 None."""
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    return text[4:end].split("\n"), text[end + 5:].split("\n")


def _top_key(ln: str) -> Optional[str]:
    """컬럼-0 줄이 여는 최상위 키의 이름 — 따옴표 둘과 콜론 앞 공백을 벗겨 정규화한다.
    키로 못 읽으면 None."""
    if ln[:1] in ('"', "'"):
        q, i, buf = ln[0], 1, []
        while i < len(ln):
            c = ln[i]
            if c == q:
                if q == "'" and ln[i + 1:i + 2] == "'":
                    buf.append("'")
                    i += 2
                    continue
                break
            if q == '"' and c == "\\" and i + 1 < len(ln):
                buf.append(ln[i:i + 2])
                i += 2
                continue
            buf.append(c)
            i += 1
        else:
            return None
        return "".join(buf) if _COLON_AFTER_QUOTED.match(ln, i + 1) else None
    if ln[:1] in _NOT_PLAIN_START or ln[:2] in ("- ", "? ", ": "):
        return None
    m = _PLAIN_COLON.search(ln)
    if not m:
        return None
    k = ln[:m.start()].rstrip(" \t")
    if not k or " #" in k or "\t#" in k:
        return None
    return k


def _fm_blocks(lines: List[str]) -> Optional[Dict[str, List[str]]]:
    """최상위 키 → 그 키의 줄 블록(키 줄 + 이어지는 들여쓴·빈 줄). 컬럼-0 의 비지 않은 줄(주석
    제외)은 전부 키 줄이어야 한다. 키로 못 읽는 컬럼-0 줄 · 중복 키(정규화한 이름으로) · 첫 키
    앞의 내용은 None."""
    blocks: Dict[str, List[str]] = {}
    key = None
    for ln in lines:
        if ln.startswith("#"):
            continue
        if not ln.strip() or ln[:1] in (" ", "\t"):
            if key is None:
                if ln.strip():
                    return None
                continue
            blocks[key].append(ln)
            continue
        k = _top_key(ln)
        if k is None or k in blocks:
            return None
        key = k
        blocks[key] = [ln]
    return blocks


def relation(variant, base) -> Tuple[bool, str, List[str]]:
    """(성립 여부, 사유, 끼운 줄 목록)."""
    try:
        vt = Path(variant).read_text(encoding="utf-8")
        bt = Path(base).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return False, "unreadable:%s" % type(exc).__name__, []
    vs, bs = _split(vt), _split(bt)
    if vs is None or bs is None:
        return False, "frontmatter_missing", []
    (vf, vb), (bf, bb) = vs, bs
    vk, bk = _fm_blocks(vf), _fm_blocks(bf)
    if vk is None or bk is None:
        return False, "frontmatter_unparsable", []
    if set(vk) != set(bk):
        return False, "frontmatter_keys_differ:%s" % ",".join(sorted(set(vk) ^ set(bk))), []
    for k in sorted(vk):
        if k not in FREE_KEYS and vk[k] != bk[k]:
            return False, "frontmatter_value_differs:%s" % k, []
    n, m = len(bb), len(vb)
    p = 0
    while p < n and p < m and bb[p] == vb[p]:
        p += 1
    s = 0
    while s < n - p and s < m - p and bb[n - 1 - s] == vb[m - 1 - s]:
        s += 1
    if p + s != n:
        return False, "body_changed_beyond_one_insertion:base_line_%d" % (p + 1), []
    ins = vb[p:m - s]
    if not any(x.strip() for x in ins):
        return False, "no_insertion", []
    return True, "", ins


def audit(paths: List[str]) -> List[Tuple[str, str, str]]:
    """코퍼스(경로 목록)의 마커 파일마다 (경로, 대상, 판정). 판정은 OK 또는 FAIL:<사유>.

    링크는 대상의 마커를 빌려 쓴다(open 이 따라간다) — 링크 자신은 면제를 받지 못하므로
    (중복 락이 링크를 ③ 에서 뺀다) 여기서도 마커를 단 링크 자체를 FAIL 로 드러낸다."""
    corpus = set(paths)
    out = []
    for p in paths:
        t = marker(p)
        if not t:
            continue
        if Path(p).is_symlink():
            verdict = "FAIL:symlink_with_marker"
        elif not in_agent_scope(p):
            verdict = "FAIL:out_of_scope"
        elif not canonical_agent(t):
            verdict = "FAIL:target_not_canonical_agent"
        elif t not in corpus or not Path(t).is_file() or Path(t).is_symlink():
            verdict = "FAIL:target_missing"
        elif marker(t):
            verdict = "FAIL:target_is_variant"
        else:
            holds, why, _ins = relation(p, t)
            verdict = "OK" if holds else "FAIL:relation:%s" % why
        out.append((p, t, verdict))
    return out


def main(argv: List[str]) -> int:
    if len(argv) >= 3 and argv[1] == "marker":
        t = marker(argv[2])
        if t:
            print(t)
        return 0
    if len(argv) >= 3 and argv[1] == "audit":
        with open(argv[2], encoding="utf-8") as fh:
            paths = [ln.strip() for ln in fh if ln.strip()]
        for p, t, v in audit(paths):
            print("%s\t%s\t%s" % (p, t, v))
        return 0
    if len(argv) >= 4 and argv[1] in ("check", "inserted"):
        holds, why, ins = relation(argv[2], argv[3])
        if not holds:
            print("FAIL\t%s" % why)
            return 1
        if argv[1] == "check":
            print("OK\t%d" % len(ins))
        else:
            print("\n".join(ins))
        return 0
    sys.stderr.write("usage: variant_of.py marker <file> | check|inserted <variant> <base> | audit <list>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
