#!/usr/bin/env python3
"""spec-distill — payload §6 원문 완전성 검사 (Spec B AC10/AC11/AC12/AC14).

payload(§6 사용자 원문)와 state.local.md(`user_statements` 원장)를 대조한다.
`check_brief.py`와 달리 **두 파일**을 읽는다 — 우회에 양쪽 조작이 필요하므로 이빨이
있다(spec §6.3). 게이트를 분리해 둔 덕에 `check_brief.py`의 "brief 파일만 읽는다"
불변식이 유지된다(AC16 · E12 · E11).

  L1: state `user_statements[].id` ⊆ payload §6 `**S<N>**` 앵커 집합.  위반 → red
  L2: 정규화 후 payload §6 항목 본문이 state `text`를 **포함**하는가.   위반 → red
      P21 placeholder 토큰이 **어느 한쪽**(state `text` 또는 payload §6 항목 본문)에
      관여하면 advisory로 강등한다(spec §5.5). payload 쪽 P21 secret placeholder
      치환은 §6 append-only 규칙의 유일한 설계된 예외다(design doc §"§6 변경 금지 —
      P21 secret placeholder 치환만 예외") — payload는 `docs/`에 커밋되는 산출물이고
      state.local.md는 git-ignored이므로, "state는 리터럴을 들고 있는데 payload가
      그것을 redact해 보여주는" 시나리오가 정확히 의도된 정상 경로다. 따라서 어느
      한쪽이라도 placeholder를 보이면 엄격 비교가 성립하지 않으므로 강등한다.

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

EXIT_OK = 0
EXIT_VIOLATION = 1
EXIT_INDETERMINATE = 3
EXIT_INTERNAL = 4
EXIT_USAGE = 64

SECTION6_RE = re.compile(r"^##\s*6\.", re.MULTILINE)
NEXT_SECTION_RE = re.compile(r"^##\s", re.MULTILINE)
ITEM_RE = re.compile(r"^\s*[-*]\s+\*\*(S\d+)\*\*(.*)$")
# P21 canonical placeholder 토큰 (conducting-interview SKILL.md의 P21 줄과 같은 집합).
P21_PLACEHOLDER_RE = re.compile(
    r"<(?:REDACTED|SECRET|TOKEN|KEY|CREDENTIAL|PLACEHOLDER)"
    r"(?:[:_-][A-Za-z0-9._-]{0,64})?>"
)


class ParseError(Exception):
    """검사 불가(exit 3)로 매핑되는, 의도적으로 처리된 파싱 실패."""


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
    """state frontmatter의 `user_statements` 리스트를 파싱한다(서드파티 YAML 금지)."""
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
    return items


def parse_payload_section6(text: str) -> dict[str, str]:
    """payload §6의 `**S<N>**` 항목 → 본문 매핑. 본문은 헤더 줄 *다음* 줄들이다
    (헤더 줄은 출처 표기이고 원문이 아니다). 다음 줄이 없으면 헤더의 `:` 뒤를 쓴다."""
    m = SECTION6_RE.search(text)
    if not m:
        raise ParseError("payload에 '## 6.' 섹션이 없다")
    rest = text[m.end():]
    nxt = NEXT_SECTION_RE.search(rest)
    body = rest[: nxt.start()] if nxt else rest
    bodies: dict[str, list[str]] = {}
    heads: dict[str, str] = {}
    order: list[str] = []
    cur = None
    for ln in body.splitlines():
        m2 = ITEM_RE.match(ln)
        if m2:
            cur = m2.group(1)
            if cur in bodies:
                raise ParseError(f"payload §6에 {cur} 앵커가 중복 (구조는 check_brief.py 소관)")
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


def run(payload_path: Path, state_path: Path) -> tuple[int, dict]:
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
        statements = parse_user_statements(_frontmatter(state_text))
        items = parse_payload_section6(payload_text)
    except ParseError as exc:
        result["advisories"].append(f"검사 불가 — parse failed: {exc}")
        return EXIT_INDETERMINATE, result

    for st in statements:
        sid = st["id"]
        if sid not in items:
            result["missing_ids"].append(sid)
            continue
        raw_state = st["text"]
        if raw_state is None:
            result["advisories"].append(f"{sid}: state에 text 필드 부재 — L2 검사 생략")
            continue
        want = normalize(raw_state)
        have = normalize(items[sid])
        if want and want in have:
            continue
        if P21_PLACEHOLDER_RE.search(raw_state) or P21_PLACEHOLDER_RE.search(items[sid]):
            # 어느 한쪽에라도 P21 placeholder가 있으면 강등한다. payload 쪽 치환이
            # §6 append-only의 유일한 설계된 예외(spec §5.5) — state가 리터럴을
            # 들고 있어도 payload가 그것을 redact해 보여주는 것은 정상 경로다.
            result["advisories"].append(
                f"{sid}: P21 placeholder 관여 — L2를 advisory로 강등 (원문 미포함)")
            continue
        if not want:
            result["advisories"].append(f"{sid}: state text가 빈 문자열 — L2 검사 생략")
            continue
        result["not_contained"].append(sid)

    if result["missing_ids"] or result["not_contained"]:
        return EXIT_VIOLATION, result
    return EXIT_OK, result


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print("usage: check_verbatim_coverage.py <payload> <state.local.md>",
              file=sys.stderr)
        return EXIT_USAGE
    try:
        code, result = run(Path(argv[1]), Path(argv[2]))
    except Exception as exc:  # noqa: BLE001 — 계약: 어떤 예외도 exit 4 (1로 새지 않는다)
        print(json.dumps({"missing_ids": [], "not_contained": [],
                          "advisories": [f"내부 오류: {type(exc).__name__}: {exc}"]},
                         ensure_ascii=False))
        return EXIT_INTERNAL
    print(json.dumps(result, ensure_ascii=False))
    return code


if __name__ == "__main__":
    sys.exit(main(sys.argv))
