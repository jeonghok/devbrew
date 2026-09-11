#!/usr/bin/env python3
"""variant-of 관계 — 변형 정본이 기준 정본과 «정해진 차이만» 갖는가.

변형(V)은 머리 20줄 안의 `# variant-of: <기준 경로>` 마커로 기준(B)을 가리킨다. 관계는 두 조건이
함께 설 때만 성립한다:
  ① frontmatter — 최상위 키 집합이 같고, `name`·`description`·`tools` 밖의 키는 값 블록(키 줄 +
     이어지는 들여쓴·빈 줄 **전부**)이 줄 단위로 같다. 컬럼-0 주석 줄(`# copy-of:`·`# variant-of:`)은
     비교에서 뺀다. `tools` 는 자유 키다 — 관계는 도구 표면을 판정하지 않는다(웹 사본의 도구 집합은
     test_docreview_agents.sh 와 test_brief_agents.sh 가 doc-critic 에서 도출한 집합 등식으로 잰다).
  ② 본문(frontmatter 닫힘 뒤) — V 는 B 에 연속한 한 덩어리를 끼워 넣은 것뿐이다. B 의 어느 줄도
     바뀌거나 빠지지 않고, 끼운 덩어리에는 빈 줄이 아닌 줄이 있다.

frontmatter 를 어떻게 읽는가 — 보장하는 것 셋과 보장하지 않는 것:
  (가) 한 경계 — frontmatter 는 첫 `---\\n` 과 그 뒤 처음 나오는 `\\n---\\n` 사이다. 위험 문자 검사 ·
      줄 문법 · 교차 대조 · 비교가 모두 이 경계 하나를 쓴다(`_fm_region`).
  (나) 줄 문법(허용 목록) — 두 파일의 frontmatter 모든 줄이 실제 agent 파일이 쓰는 모양 안에 있다:
      빈 줄 · 컬럼-0 주석 · 컬럼-0 `키: <그 줄에서 끝나는 평문>` · `키: >`(접힘 블록 — 본문은 2칸 이상
      들여쓴 줄) · `키: []` · 값 없는 `키:`(블록 시퀀스를 연다 — 자식은 `  - 키: 평문` · 그 뒤
      `    키: 평문` · 들여쓴 주석). 키는 `[A-Za-z_][A-Za-z0-9_]*`. 그 밖의 줄 — 따옴표 · flow 로 여는
      값, 다음 줄로 이어지는 값, 공백뿐인 줄, LF 밖 줄바꿈(CR · NEL · U+2028 · U+2029), 탭으로 시작하는
      줄 — 은 판정 불가다(`frontmatter_unparsable:<규칙>` · `frontmatter_nonlf_break:<문자>` ·
      `frontmatter_tab_line`). 값이 한 줄을 넘지 않으므로 「여는 따옴표 · flow 가 뒤따르는 컬럼-0 줄을
      삼키는」 부류가 모양째 없다.
  (다) 교차 대조 — 이 판정기가 읽은 최상위 키 집합이, 같은 frontmatter 를 PyYAML `safe_load` 가 읽은
      최상위 키 집합(문자열 키)과 같다. 두 파일 모두. 다르거나 PyYAML 이 못 읽으면 판정 불가
      (`frontmatter_yaml_mismatch:<무엇>`). PyYAML 을 import 할 수 없으면 판정 불가(`pyyaml_unavailable`
      + stderr) — 조용히 통과하지 않는다.
  보장하지 않는 것 — 런타임(Claude Code)이 frontmatter 를 읽는 파서 · YAML 판본을 모형화하지 않는다(대조
  기준은 PyYAML = YAML 1.1 하나다). 값의 의미(도구 이름이 실재하는가 등)와 본문의 의미는 판정하지 않는다.

규칙의 뜻은 형제 러너(`shared/docreview/scripts/run_docreview_codex_reviewer.sh` 의 `_parse_frontmatter`
— 「값은 한 줄에서 끝난다」 · LF 밖 줄바꿈 거절)와 같다. 코드는 나눠 쓰지 않는다: 그쪽은 셸 스크립트 안의
인라인 빌더라 import 할 모듈이 없고, 받는 모양도 다르다(프로필의 flow 목록 · 큰따옴표 값 ↔ agent 의
블록 시퀀스 · 접힘 블록).

범위 — 마커는 agent 정의에만 쓴다. 변형은 `shared/<x>/agents/*.md`(정본) 또는
`plugins/<x>/agents/*.md`(그 배포 사본)이고, 대상은 `shared/<x>/agents/*.md` 정본이다.

소비자 셋: shared/tests/test_no_new_duplication.sh(범위 안에서 관계가 서는 쌍만 중복 면제) ·
shared/tests/test_docreview_agents.sh(웹 사본 drift 락) · shared/tests/test_variant_of_contract.sh
(마커 전수 감사 · 판정기 음성 셀 · 범위 음성 셀 · agent 파일 전체 문자 금지).

CLI:
  variant_of.py marker <file>              → 마커가 가리키는 경로(없으면 빈 출력) · rc 0
  variant_of.py check <variant> <base>     → "OK\\t<끼운 줄 수>" rc 0 | "FAIL\\t<사유>" rc 1
  variant_of.py inserted <variant> <base>  → 끼운 덩어리 원문 rc 0 | "FAIL\\t<사유>" rc 1
  variant_of.py audit <코퍼스 목록 파일>     → 마커 파일마다 "<경로>\\t<대상>\\tOK" 또는
                                              "<경로>\\t<대상>\\tFAIL:<사유>" · rc 0
python 3.9 · stdlib + PyYAML(교차 대조에만).
"""
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple

MARKER = re.compile(r'^\s*(?:#|//|<!--)\s*variant-of:\s*(\S+)')
HEAD_WINDOW = 20
FREE_KEYS = ("name", "description", "tools")
_AGENT_DEF = re.compile(r'^(?:shared|plugins)/[^/]+/agents/[^/]+\.md$')
_CANONICAL_AGENT = re.compile(r'^shared/[^/]+/agents/[^/]+\.md$')

# LF 밖 줄바꿈 — PyYAML(YAML 1.1)은 넷 다 줄바꿈으로 읽는데 이 판정기는 LF 로만 줄을 나눈다. 판정기
# (frontmatter)와 V4(agent 파일 전체)가 이 한 정의를 쓴다(`nonlf_breaks`).
_NON_LF_BREAKS = ((chr(0x0D), "U+000D"), (chr(0x85), "U+0085"), (chr(0x2028), "U+2028"), (chr(0x2029), "U+2029"))

# 줄 문법(허용 목록) — 실제 agent 파일 24개(정본 3 · 배포 21)의 frontmatter 가 쓰는 모양에서 도출했다.
_KEY_LINE = re.compile(r'([A-Za-z_][A-Za-z0-9_]*):(?: (.*))?$')
_SEQ_ITEM = re.compile(r'  - [A-Za-z_][A-Za-z0-9_]*: (.+)$')
_SEQ_CONT = re.compile(r'    [A-Za-z_][A-Za-z0-9_]*: (.+)$')
_INDENTED_COMMENT = re.compile(r' +#')
_BLOCK_INDICATOR = ">"      # 실제 파일이 쓰는 블록 스칼라 표지는 접힘 `>` 하나다
_EMPTY_FLOW_LIST = "[]"     # 실제 파일이 쓰는 flow 값은 빈 목록 하나다
# 값을 여는 문자마다 따로 이름을 준다 — 하나를 풀면 그 규칙의 셀이 RED 가 된다.
_OPENERS = (('"', "value_double_quote"), ("'", "value_single_quote"),
            ("{", "value_flow_mapping"), ("[", "value_flow_sequence"))
# 평문이 시작할 수 없는 그 밖의 지시 문자(앵커 · 별칭 · 태그 · 블록 스칼라 · 예약 · 주석).
_INDICATOR_START = tuple("&*!|>%@`#")


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


def nonlf_breaks(text: str) -> List[str]:
    """text 에 든 LF 밖 줄바꿈의 이름들(`_NON_LF_BREAKS` 순서)."""
    return [name for ch, name in _NON_LF_BREAKS if ch in text]


def _fm_region(text: str) -> Optional[Tuple[str, str]]:
    """(frontmatter 원문, 본문 원문). 시작은 `---\\n`, 끝은 그 뒤 처음 나오는 `\\n---\\n`. 없으면 None."""
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---\n", 4)
    if end < 0:
        return None
    return text[4:end], text[end + 5:]


def _fm_hazard(fm: str) -> Optional[str]:
    """frontmatter 원문의 LF 밖 줄바꿈 · 탭으로 시작하는 줄 — 줄을 나누기 전에 본다."""
    hits = nonlf_breaks(fm)
    if hits:
        return "frontmatter_nonlf_break:%s" % hits[0]
    if any(ln.startswith("\t") for ln in fm.split("\n")):
        return "frontmatter_tab_line"
    return None


def _plain_ok(v: str) -> bool:
    """그 줄에서 끝나는 평문 — 비지 않고, 여는 문자 · 지시 문자로 시작하지 않고, 매핑 표지(`: ` · 끝
    `:`)나 주석 표지(` #`)를 담지 않는다."""
    return (bool(v.strip()) and v[:1] not in _INDICATOR_START
            and not any(v.startswith(ch) for ch, _ in _OPENERS)
            and v[:2] not in ("- ", "? ", ": ")
            and ": " not in v and not v.endswith(":") and " #" not in v)


def _value_mode(v: str) -> Tuple[Optional[str], Optional[str]]:
    """컬럼-0 키 줄의 값 → (뒤따르는 줄의 모드, None) 또는 (None, 규칙 이름)."""
    if v == _BLOCK_INDICATOR:
        return "block", None
    if v == _EMPTY_FLOW_LIST:
        return "scalar", None
    for ch, why in _OPENERS:
        if v.startswith(ch):
            return None, why
    if not _plain_ok(v):
        return None, "value_plain_shape"
    return "scalar", None


def _fm_blocks(lines: List[str]) -> Tuple[Optional[Dict[str, List[str]]], Optional[str]]:
    """줄 문법으로 읽는다 → ({최상위 키: 줄 블록}, None) 또는 (None, 규칙 이름). 블록은 키 줄 +
    이어지는 들여쓴·빈 줄이다. 컬럼-0 주석은 블록에 넣지 않는다."""
    blocks: Dict[str, List[str]] = {}
    key: Optional[str] = None
    mode: Optional[str] = None
    in_item = False
    for ln in lines:
        if not ln.strip():
            if ln:
                return None, "whitespace_line"
            if key is not None:
                blocks[key].append(ln)
            continue
        if ln.startswith("#"):
            continue
        if ln.startswith(" "):
            if key is None:
                return None, "content_before_key"
            if mode == "block":
                if not ln.startswith("  "):
                    return None, "block_indent"
            elif mode == "open":
                if _INDENTED_COMMENT.match(ln):
                    pass
                else:
                    item, cont = _SEQ_ITEM.match(ln), _SEQ_CONT.match(ln)
                    m = item or (cont if in_item else None)
                    if not m:
                        return None, "child_shape"
                    if not _plain_ok(m.group(1)):
                        return None, "child_value"
                    in_item = in_item or bool(item)
            else:
                return None, "value_continuation"
            blocks[key].append(ln)
            continue
        m = _KEY_LINE.match(ln)
        if not m:
            return None, "key_shape"
        k, v = m.group(1), m.group(2)
        if k in blocks:
            return None, "duplicate_key"
        if not v:
            mode = "open"
        else:
            mode, why = _value_mode(v)
            if why:
                return None, why
        key, in_item = k, False
        blocks[key] = [ln]
    return blocks, None


def _yaml_keys(fm: str) -> Tuple[Optional[set], Optional[str]]:
    """PyYAML `safe_load` 가 읽은 최상위 키 집합 → (집합, None) 또는 (None, 사유)."""
    try:
        import yaml  # noqa: PLC0415 — 교차 대조에만 쓴다
    except ImportError:
        sys.stderr.write("variant_of: PyYAML 을 import 할 수 없다 — 교차 대조 없이 판정하지 않는다\n")
        return None, "pyyaml_unavailable"
    try:
        data = yaml.safe_load(fm)
    except yaml.YAMLError as exc:
        return None, "frontmatter_yaml_mismatch:load_error:%s" % type(exc).__name__
    if not isinstance(data, dict):
        return None, "frontmatter_yaml_mismatch:not_mapping"
    odd = sorted(repr(k) for k in data if not isinstance(k, str))
    if odd:
        return None, "frontmatter_yaml_mismatch:non_string_key:%s" % ",".join(odd)
    return set(data), None


def _read_fm(fm: str) -> Tuple[Optional[Dict[str, List[str]]], str]:
    """한 파일의 frontmatter → (블록, "") 또는 (None, 사유) — 위험 문자 · 줄 문법 · 교차 대조 순서."""
    why = _fm_hazard(fm)
    if why:
        return None, why
    blocks, rule = _fm_blocks(fm.split("\n"))
    if rule:
        return None, "frontmatter_unparsable:%s" % rule
    ykeys, why = _yaml_keys(fm)
    if why:
        return None, why
    if ykeys != set(blocks):
        return None, "frontmatter_yaml_mismatch:keys:%s" % ",".join(sorted(ykeys ^ set(blocks)))
    return blocks, ""


def relation(variant, base) -> Tuple[bool, str, List[str]]:
    """(성립 여부, 사유, 끼운 줄 목록)."""
    try:
        # 바이트로 읽는다 — `read_text()` 의 universal newline 이 CR 을 LF 로 바꿔 CR 규칙을 우연에
        # 맡기지 않게.
        vt = Path(variant).read_bytes().decode("utf-8")
        bt = Path(base).read_bytes().decode("utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        return False, "unreadable:%s" % type(exc).__name__, []
    vs, bs = _fm_region(vt), _fm_region(bt)
    if vs is None or bs is None:
        return False, "frontmatter_missing", []
    (vfm, vbody), (bfm, bbody) = vs, bs
    vk, why = _read_fm(vfm)
    if vk is None:
        return False, why, []
    bk, why = _read_fm(bfm)
    if bk is None:
        return False, why, []
    if set(vk) != set(bk):
        return False, "frontmatter_keys_differ:%s" % ",".join(sorted(set(vk) ^ set(bk))), []
    for k in sorted(vk):
        if k not in FREE_KEYS and vk[k] != bk[k]:
            return False, "frontmatter_value_differs:%s" % k, []
    vb, bb = vbody.split("\n"), bbody.split("\n")
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
