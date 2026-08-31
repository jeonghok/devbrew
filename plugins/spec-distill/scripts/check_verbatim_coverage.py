#!/usr/bin/env python3
"""spec-distill — payload/audit §6 원문 완전성 검사 (Spec B AC10/AC11/AC12/AC14).

payload(§6 `S1`)와 audit(§6 `S2` 이상)의 합집합을 state.local.md(`user_statements`
원장)와 대조한다. v0.43.0부터 §6 원문 자체가 payload·audit 두 파일에 나뉘어 산다 —
`S1`은 payload에, `S2` 이상은 audit에(설계 §2 「payload/audit 분리」). 그래서 이
스크립트는 **세 파일**을 읽는다 — 우회에 세 곳 모두의 조작이 필요하므로 이빨이
있다(spec §6.3). 게이트를 분리해 둔 덕에 `check_brief.py`의 "brief 파일만 읽는다"
불변식이 유지된다(AC16 · E12 · E11).

audit 경로는 호출자가 **명시**해야 한다(3번째 CLI 인자) — payload 파일명이나
frontmatter에서 유도하지 않는다. `check_brief.py`의 `resolve_audit()`이 stem을
유도하는 것은 payload가 남의 audit을 자기 것이라 부르지 못하게 **거절**하는 것이고,
여기서는 그 반대다 — 무엇을 대조 재료로 쓸지 유추가 실패하면 조용하고, 잘못된
재료로 검증을 태우는 것이 아예 안 하는 것보다 나쁘다(아래 `main()` 참조).

  L1: state `user_statements[].id` ⊆ payload §6 `**S<N>**` 앵커 집합.  위반 → red
  L2: 정규화 후 payload §6 항목 본문이 state `text`를 **포함**하는가.   위반 → red
      P21 placeholder 토큰이 **어느 한쪽**(state `text` 또는 payload §6 항목 본문)에
      관여하면 그 statement는 **판정하지 않는다 → exit 3(검사 불가)**. clean도 violation도
      아니다. redaction 뒤에 무엇이 있었는지는 원리적으로 알 수 없고, 부분 매칭으로
      통과/차단을 가르려는 시도는 어느 앵커를 걸어도 한쪽에서 샌다 — 토큰이 문장 끝에
      붙으면 그 뒤의 임의 누락이 허용되고(누락 세탁), 앵커를 조이면 원문에 맥락을 덧붙인
      정당한 payload를 오차단한다. 두 실패는 같은 함수의 양면이라 동시에 없앨 수 없다.
      (2026-07-29 /qg iter-2: 부분 매칭 술어를 리뷰어 4/4가 CRITICAL로 판정 → 제거.)

      exit 3은 호출자 rc 표에서 degradation record가 **의무**인 행이다. 원래 결함의
      본질은 "통과했다"가 아니라 **"강등이 조용했다"** 였다(rc 0의 advisory는 호출자
      표에서 폐기됐다). 판정을 포기하되 그 사실을 사람에게 반드시 도달시킨다.

정규화 N1–N5 (spec §5.5) — **순서 고정 `N1 → N2 → N3 → N4 → N5`**:
  N1 각 줄 앞 인용 마커 1회 제거 · N2 강조/링크 제거 · N3 연속 whitespace(개행 포함)
  단일화 · N4 양끝 trim · N5 **NFC**(전각/반각을 접지 않는다 — NFKC는 `①→1`·`ﬁ→fi`까지
  접어 실제 왜곡을 통과시킨다).
  **N3보다 N1이 반드시 먼저**다. N3이 개행을 space로 바꾸면 줄 경계가 사라져 둘째 줄
  이후의 `>` 마커를 `^` 앵커로 지울 수 없고 문자열 중간에 남는다(§6 템플릿의 멀티라인
  인용이 정확히 그 형태).

exit 계약:
  0  위반 없음
  1  **위반 발견** (missing_ids 또는 not_contained 비어 있지 않음) — 호출자는 차단
  3  검사 불가 (파일 부재·파싱 실패 — 의도적으로 매핑된 경로) — degrade 후 계속
  4  내부 오류 (미처리 예외) — Python 기본 종료 코드 1을 절대 쓰지 않는다.
     `main()`이 top-level `try/except`로 감싸여 있고, "exit 1은 오직 명시적 위반
     판정에서만 나온다"가 계약이다. 이 계약이 없으면 예상 못 한 버그가 "원문이 빠졌다"로
     오분류돼 **정상 brief를 차단**한다.
  64 usage
  그 외 non-zero는 호출자가 3과 동일하게 취급한다(indeterminate ≠ clean).
"""
from __future__ import annotations

import json
import re
import sys
import unicodedata
from pathlib import Path

# §6 경계는 이 파일이 계산하지 않는다 — `scripts/section6.py` 한 곳이다. 이 파일의 옛
# 종결 규칙(`^##\s`)은 게이트(`^##\s+\d+\.`, 펜스 밖)보다 이르게 끊어, 같은 문서가 두
# 소비자에게 다른 §6 을 갖게 했다(v0.47.0).
_SCRIPTS_DIR = str(Path(__file__).resolve().parent)
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)
import section6  # noqa: E402

EXIT_OK = 0
EXIT_VIOLATION = 1
EXIT_INDETERMINATE = 3
EXIT_INTERNAL = 4
EXIT_USAGE = 64

ITEM_RE = re.compile(r"^\s*[-*]\s+\*\*(S\d+)\*\*(.*)$")
# P21 canonical placeholder 토큰 (conducting-interview SKILL.md의 P21 줄과 같은 집합).
# 라벨 문자류는 `[\w.-]` — 파이썬 3에서 `\w`는 유니코드 인식이라 `[A-Za-z0-9_]`에
# **다른 문자 체계의 글자/숫자**가 더해진다. producer 문서(Korean-primary)가 예시로
# 드는 `<REDACTED:라벨>`이 checker에 안 잡히던 drift를 producer가 아니라 **checker**
# 쪽을 넓혀서 맞춘다: 한국어 라벨은 이 리포의 문서 규약상 정상이고, producer를 ASCII로
# 좁히면 규약과 싸우게 된다. 넓힌 것은 **글자 종류뿐**이고 경계는 그대로다 —
# 공백·`>`·`<`는 여전히 못 들어가고 길이 상한 64도 유지한다. 즉 산문 한 문장을 라벨로
# 위장해 L2 비교를 통째로 강등시키는 경로는 열리지 않는다.
P21_PLACEHOLDER_RE = re.compile(
    r"<(?:REDACTED|SECRET|TOKEN|KEY|CREDENTIAL|PLACEHOLDER)"
    r"(?:[:_-][\w.-]{0,64})?>"
)


class ParseError(Exception):
    """검사 불가(exit 3)로 매핑되는, 의도적으로 처리된 파싱 실패."""


class StructuralViolation(Exception):
    """위반(exit 1)로 매핑되는 **구조적** 규칙 위반.

    `ParseError`(판독 불가)와 구분한다. 판독에 실패한 것이 아니라 판독에 성공했고
    그 결과가 규칙 위반인 경우다 — 3(degrade 후 계속)으로 내면 위반 항목뿐 아니라
    **전 statement**의 L1·L2가 함께 skip되고 호출자는 그것을 "계속"으로 읽는다.
    """



def normalize(s: str) -> str:
    """N1 → N5. 순서를 바꾸면 L2의 pass/fail이 바뀐다(위 docstring 참조)."""
    s = re.sub(r"(?m)^[ \t]*>[ \t]?", "", s)        # N1 (1회 — 중첩 인용은 남긴다)
    s = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", s)  # N2 링크 → 텍스트
    s = re.sub(r"[*`]", "", s)                      # N2 강조 마커
    s = re.sub(r"\s+", " ", s)                      # N3
    s = s.strip()                                   # N4
    return unicodedata.normalize("NFC", s)          # N5 — NFKC 아님


def _frontmatter(text: str) -> str:
    if not text.startswith("---"):
        raise ParseError("frontmatter 부재 (첫 줄이 '---' 아님)")
    end = text.find("\n---", 3)
    if end == -1:
        raise ParseError("frontmatter 종료 구분자 부재")
    return text[3:end]


def _unquote(raw: str) -> str:
    raw = raw.strip()
    m = re.match(r'^"((?:[^"\\]|\\.)*)"', raw)
    if m:
        try:
            return json.loads('"' + m.group(1) + '"')
        except ValueError:
            return m.group(1)
    m = re.match(r"^'((?:[^']|'')*)'", raw)
    if m:
        return m.group(1).replace("''", "'")
    # 인용 없는 스칼라에서만 인라인 주석을 떼어낸다 (인용 안 '#'은 원문의 일부다).
    return re.sub(r"\s+#.*$", "", raw).strip()


def _read_block_scalar(lines: list[str], i: int, key_indent: int) -> tuple[str, int]:
    """`text: |` 다음의 블록 스칼라를 읽는다. 반환 (본문, 다음 인덱스)."""
    body: list[str] = []
    while i < len(lines):
        ln = lines[i]
        if ln.strip() == "":
            body.append("")
            i += 1
            continue
        indent = len(ln) - len(ln.lstrip())
        if indent <= key_indent:
            break
        body.append(ln)
        i += 1
    real = [b for b in body if b.strip()]
    dedent = min((len(b) - len(b.lstrip()) for b in real), default=0)
    return "\n".join(b[dedent:] if len(b) > dedent else "" for b in body).rstrip("\n"), i


def parse_user_statements(fm: str) -> list[dict]:
    """state frontmatter의 `user_statements` 리스트를 파싱한다(서드파티 YAML 금지).

    **필수 필드 누락과 판독 불가 항목은 ParseError(→ exit 3)다.** 조용히 건너뛰면
    그 statement는 payload §6과 **한 번도 대조되지 않은 채** 검사가 exit 0으로 끝난다 —
    호출자는 0을 "위반 없음"으로 매핑하므로 완전성 검사가 돌지도 않고 clean으로 보인다
    (indeterminate ≠ clean). 두 경로를 모두 닫는다:

      (1) `- id:`로 시작하지 않는 리스트 항목 — 이전엔 통째로 무시됐다(항목이 원장에서
          사라져 L1/L2 어느 쪽도 그 id를 찾지 않았다).
      (2) `text` 키 자체가 부재 — 이전엔 advisory 한 줄만 남기고 exit 0이었다.

    스키마(conducting-interview SKILL.md)는 각 레코드의 **첫 키가 `id`**임을 규정하므로
    (1)은 새 제약이 아니라 기존 계약의 집행이다.

    `text`가 **존재하지만 비어 있는**(또는 정규화 후 비는) 경우는 여기서 보지 않는다 —
    그 사실은 `run()`의 `not want` 분기가 단독으로 책임진다. 두 곳에서 같은 입력을 막으면
    어느 쪽도 load-bearing이 아니게 되어(한쪽을 지워도 회귀 테스트가 green) mutation으로
    이빨을 증명할 수 없다.
    """
    lines = fm.splitlines()
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^user_statements\s*:", ln):
            start = i
            break
    if start is None:
        raise ParseError("state에 user_statements 키가 없다")
    if re.match(r"^user_statements\s*:\s*\[\s*\]\s*$", lines[start]):
        return []
    items: list[dict] = []
    cur: dict | None = None
    i = start + 1
    while i < len(lines):
        ln = lines[i]
        # 블록 종료 = 들여쓰기 없고 '-'로도 시작하지 않는 비어있지 않은 줄(다음 top-level 키).
        if ln.strip() and not ln[0].isspace() and not ln.lstrip().startswith("-"):
            break
        m = re.match(r"^\s*-\s+id\s*:\s*(\S+)", ln)
        if m:
            cur = {"id": m.group(1).strip().rstrip(","), "text": None}
            items.append(cur)
            i += 1
            continue
        if re.match(r"^\s*-\s+\S", ln):
            raise ParseError(
                f"user_statements 항목이 `- id:`로 시작하지 않는다: {ln.strip()!r} "
                "— 조용히 버리면 그 발화가 대조 대상에서 사라진다")
        m = re.match(r"^(\s*)text\s*:\s*(.*)$", ln)
        if m and cur is not None:
            raw = m.group(2).strip()
            if raw in ("|", "|-", "|+", ">", ">-", ">+"):
                cur["text"], i = _read_block_scalar(lines, i + 1, len(m.group(1)))
                continue
            cur["text"] = _unquote(raw)
            i += 1
            continue
        i += 1
    for it in items:
        if it["text"] is None:
            raise ParseError(
                f"user_statements {it['id']}에 필수 필드 text가 없다 "
                "— 이 발화는 대조가 불가능하므로 '위반 없음'으로 집계하지 않는다")
    return items


def parse_section6(text: str, label: str) -> dict[str, str]:
    """`## 6.` 의 `**S<N>**` 항목 → 본문 매핑. 본문은 헤더 줄 *다음* 줄들이다
    (헤더 줄은 출처 표기이고 원문이 아니다). 다음 줄이 없으면 헤더의 `:` 뒤를 쓴다.

    v0.43.0: payload와 audit 양쪽에 쓰인다. `label`은 오류 메시지 전용이다 —
    "어느 문서의 §6이 없는가"가 안 보이면 호출자가 잘못된 파일을 고친다.
    """
    body = section6.body(text)
    if body is None:
        amb = section6.ambiguities(text)
        if amb:
            # 부재가 아니라 **구조 위반**이다 — 「검사 불가(3)」로 내리면 어느 §6 을 봤어야
            # 하는지 아무도 모른 채 전 statement 의 L1·L2 가 skip 된다.
            raise StructuralViolation(f"{label} §6 경계가 유일하지 않다 — {amb[0]}")
        raise ParseError(f"{label}에 '## 6.' 섹션이 없다")
    bodies: dict[str, list[str]] = {}
    heads: dict[str, str] = {}
    order: list[str] = []
    cur = None
    for ln in body.splitlines():
        m2 = ITEM_RE.match(ln)
        if m2:
            cur = m2.group(1)
            if cur in bodies:
                # 위임하지 않는다. `check_brief.py`의 `verbatim_anchors()`는 §6 앵커를
                # set()으로 모아 중복을 **아예 보지 않으므로**, 여기서 3(검사 불가)으로
                # 내면 그 사실을 아무도 잡지 못한 채 전 statement의 L1·L2가 skip된다.
                # 중복 앵커는 판독 실패가 아니라 append-only 규칙의 구조적 위반이다.
                raise StructuralViolation(f"{label} §6에 {cur} 앵커가 중복 — append-only 위반")
            bodies[cur] = []
            heads[cur] = m2.group(2)
            order.append(cur)
            continue
        if cur is not None:
            bodies[cur].append(ln)
    out: dict[str, str] = {}
    for sid in order:
        joined = "\n".join(bodies[sid]).strip()
        if not joined:
            tail = heads[sid]
            joined = tail.split(":", 1)[1].strip() if ":" in tail else tail.strip()
        out[sid] = joined
    return out


def parse_section6_union(payload_text: str, audit_text: str) -> dict[str, str]:
    """payload §6 ∪ audit §6. `S1`은 payload에, `S2` 이상은 audit에 산다.

    한쪽 절 부재를 **조용한 코퍼스 축소로 처리하지 않는다** — 그러면
    "원문 완전성 통과"가 거짓이 된다. 양쪽 다 ParseError를 그대로 올린다
    (호출자가 exit 3으로 바꾼다 — 검사 불가는 위반이 아니지만 통과도 아니다).

    같은 앵커가 양쪽에 있으면 **append-only 위반**이다. 오늘 payload 안의 중복이
    구조 위반인 것과 같은 이유이며, 코퍼스가 합집합이 됐으므로 집행도 합집합
    위에서 돈다 — 안 그러면 규범만 audit으로 가고 기계 집행은 payload에 남는다.
    """
    pay = parse_section6(payload_text, "payload")
    aud = parse_section6(audit_text, "audit")
    both = sorted(set(pay) & set(aud))
    if both:
        raise StructuralViolation(
            f"{', '.join(both)} 앵커가 payload §6과 audit §6 양쪽에 — append-only 위반")
    merged = dict(pay)
    merged.update(aud)
    return merged


def run(payload_path: Path, state_path: Path, audit_path: Path) -> tuple[int, dict]:
    result: dict = {"missing_ids": [], "not_contained": [], "advisories": []}
    try:
        payload_text = payload_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        result["advisories"].append(f"검사 불가 — payload unreadable: {exc}")
        return EXIT_INDETERMINATE, result
    try:
        state_text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        result["advisories"].append(f"검사 불가 — state unreadable: {exc}")
        return EXIT_INDETERMINATE, result
    try:
        audit_text = audit_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        result["advisories"].append(f"검사 불가 — audit unreadable: {exc}")
        return EXIT_INDETERMINATE, result
    try:
        # payload(+audit)를 **먼저** 판다. 순서를 뒤집으면 state의 ParseError가
        # payload의 StructuralViolation을 선점해, state에서 키 하나만 빼는 것으로 구조
        # 위반(차단)이 검사 불가(계속)로 되돌아간다 — state는 저자가 쓰는 git-ignored
        # 파일이다.
        items = parse_section6_union(payload_text, audit_text)
        statements = parse_user_statements(_frontmatter(state_text))
    except StructuralViolation as exc:
        result["not_contained"].append("§6")
        result["advisories"].append(f"구조 위반 — {exc}")
        return EXIT_VIOLATION, result
    except ParseError as exc:
        result["advisories"].append(f"검사 불가 — parse failed: {exc}")
        return EXIT_INDETERMINATE, result

    # 확정 위반은 뒤 항목의 불확정에 밀려 강등되지 않는다. 루프 안에서 곧바로
    # `return EXIT_INDETERMINATE` 하면 이미 누적한 not_contained가 rc 3(= 호출자에겐
    # "degrade 후 계속")으로 나가 차단되지 않는다. 판정은 루프 **밖**에서 한 번,
    # 위반 > 불확정 순으로 한다.
    saw_indeterminate = False

    # 빈 전칭명제는 clean이 아니다. 원장에 statement가 0건이면 L1·L2 어느 것도 돌지 않고
    # 루프가 통째로 skip되는데, 그것을 "위반 없음"으로 집계하면 **원장을 비우는 것만으로**
    # 완전성 검사가 조용히 우회된다(같은 diff가 test_agent_frontmatter_keys.sh의 빈-glob
    # 구멍을 닫은 것과 같은 클래스다).
    if not statements:
        result["advisories"].append(
            "검사 불가 — state 원장에 user_statements가 0건이다 (대조 대상 없음). "
            "빈 집합 위의 '위반 없음'은 검증이 아니다")
        return EXIT_INDETERMINATE, result

    for st in statements:
        sid = st["id"]
        if sid not in items:
            result["missing_ids"].append(sid)
            continue
        raw_state = st["text"]
        want = normalize(raw_state)
        have = normalize(items[sid])
        if want and want in have:
            continue
        if not want:
            # state text가 존재하지만 비어 있거나 정규화(N1–N5) 후 비었다 — 대조 불가.
            result["advisories"].append(
                f"검사 불가 — {sid}: state text가 비어 있다(또는 정규화 후 빈 문자열) "
                "— L2 대조가 성립하지 않는다")
            saw_indeterminate = True
            continue
        state_tok = P21_PLACEHOLDER_RE.search(raw_state)
        item_tok = P21_PLACEHOLDER_RE.search(items[sid])
        if state_tok or item_tok:
            # **P21이 관여하면 판정하지 않는다.** redaction 뒤에 무엇이 있었는지는 원리적으로
            # 알 수 없으므로, 부분 매칭으로 통과/차단을 가르려는 시도는 어느 앵커를 걸어도
            # 한쪽에서 샌다: 토큰이 문장 끝에 붙으면 그 뒤 임의 누락이 허용되고(누락 세탁),
            # 앵커를 조이면 원문에 맥락을 덧붙인 정당한 payload를 오차단한다. 그래서 이
            # 경로의 결과는 clean(0)도 violation(1)도 아닌 **검사 불가(3)** 다.
            #
            # 이것으로 원래 결함의 본질이 닫힌다 — 문제는 "통과했다"가 아니라 "강등이
            # 조용했다"였고(rc 0의 advisory는 호출자 표에서 폐기됐다), rc 3은 SKILL rc 표에서
            # degradation record가 **의무**인 행이라 Step B 사용자에게 반드시 도달한다.
            side = "양쪽" if (state_tok and item_tok) else ("state" if state_tok else "payload")
            result["advisories"].append(
                f"검사 불가 — {sid}: P21 placeholder 관여({side}) — redaction 뒤의 원문을 "
                "확인할 수 없어 L2를 판정하지 않는다(통과로 집계하지 않는다)")
            saw_indeterminate = True
            continue
        result["not_contained"].append(sid)

    if result["missing_ids"] or result["not_contained"]:
        return EXIT_VIOLATION, result
    if saw_indeterminate:
        return EXIT_INDETERMINATE, result
    return EXIT_OK, result


def main(argv: list[str]) -> int:
    # 이 스크립트는 한국어 advisory를 stdout/stderr로 낸다. locale이 UTF-8이 아니면
    # (`LC_ALL=C`) print가 UnicodeEncodeError로 죽어 **exit 1**이 되고, 호출자 rc 표는
    # 1을 "위반 발견 → 차단"으로 읽는다 — 인코딩 사고가 정상 brief를 막는다.
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass
    if len(argv) != 4:
        print("usage: check_verbatim_coverage.py <payload> <state.local.md> <audit>",
              file=sys.stderr)
        return EXIT_USAGE
    try:
        code, result = run(Path(argv[1]), Path(argv[2]), Path(argv[3]))
    except Exception as exc:  # noqa: BLE001 — 계약: 어떤 예외도 exit 4 (1로 새지 않는다)
        print(json.dumps({"missing_ids": [], "not_contained": [],
                          "advisories": [f"내부 오류: {type(exc).__name__}: {exc}"]},
                         ensure_ascii=False))
        return EXIT_INTERNAL
    print(json.dumps(result, ensure_ascii=False))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
