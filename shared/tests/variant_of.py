#!/usr/bin/env python3
"""variant-of 관계 — 변형 정본이 기준 정본과 «정해진 차이만» 갖는가.

변형(V)은 머리 20줄 안의 `# variant-of: <기준 경로>` 마커로 기준(B)을 가리킨다. 관계는 두 조건이
함께 설 때만 성립한다:
  ① frontmatter — 최상위 키 집합이 같고, `name`·`description`·`tools` 밖의 키는 값 블록이 줄 단위로
     같다. 컬럼-0 주석 줄(`# copy-of:`·`# variant-of:`)은 비교에서 뺀다. `tools` 는 자유 키다 —
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
_KEY = re.compile(r'^([A-Za-z_][A-Za-z0-9_.-]*):')
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


def _fm_blocks(lines: List[str]) -> Optional[Dict[str, List[str]]]:
    """최상위 키 → 그 키의 줄 블록(키 줄 + 이어지는 들여쓴·빈 줄). 중복 키·키 없는 내용은 None."""
    blocks: Dict[str, List[str]] = {}
    key = None
    for ln in lines:
        if ln.startswith("#"):
            continue
        m = _KEY.match(ln)
        if m:
            key = m.group(1)
            if key in blocks:
                return None
            blocks[key] = [ln]
        elif key is None:
            if ln.strip():
                return None
        else:
            blocks[key].append(ln)
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
