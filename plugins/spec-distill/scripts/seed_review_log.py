#!/usr/bin/env python3
"""seed_review_log.py — seed 리뷰가 audit 에 남기는 기록을 읽고 쓴다.

audit `## 6. 리뷰 결정` 의 줄은 두 곳에서 온다. 엔진(`docreview_state.py` 의 `decide` 와
`fix --event drop` 에 `--log-file` 을 넘기면 한 줄씩 적는다)과 이 파일의 `log`(finding 없는
처분 — 저자 편집 덩어리 · 비차단 ask 의 답). 두 모양 다 사용자 문구를 큰따옴표 한 쌍 안에
싣고 그 뒤에 « — » 와 요약이 온다.

  user-quotes     <audit>
      `## 6` 의 사용자 문구만 — 판정 이력(결정 id · 라운드 · 채택/기각 · finding id · 요약) 없이.
  check-drops     <audit> <gate.json>
      엔진 `gate` 요약의 `dropped`(엔진이 센 fix drop 전부)마다 문구 있는 drop 줄이 있는가.
  log             <audit> --kind 편집|답|거부 --round N --target T --quote-file F
                  [--note S | --note-file F]
      finding 없는 처분(편집 · 답), 또는 문구 없이 눌린 drop 을 사용자에게 다시 물어 채운 기록(거부)
      한 줄을 `## 6` 에 적는다. 사용자 문구는 파일로만 받는다(`--quote-file` — 셸 인자 `--quote` 는
      없다: 그 자리는 모델이 지어낸 글자를 사용자 문구로 박는 가장 쉬운 길이었다). 리뷰어 요약도 파일로
      받는다(`--note-file`) — 셸 인자에 직접 쓰면 그 안의 백틱 · `$( )` 를 셸이 실행한다. **한계**: 문구
      파일도 이 skill(모델)이 Write 로 쓴다 — 파일 경로는 출처를 보증하지 않고, 사용자 답을 그대로
      옮겼는지는 skill 문면의 절차가 진다. 여러 줄은 한 줄로
      잇는다(`## 6` 은 한 줄에 한 기록이다). 문구가 비면 적지 않는다(rc 2). `답` · `거부` 는 같은 줄이
      이미 있으면 다시 적지 않고 rc 0 이다(대상이 finding id 라 줄이 처분을 유일하게 가리킨다) —
      부분 실패 뒤 펜스를 통째로 다시 돌려도 그 두 기록은 겹치지 않는다. `편집` 은 언제나 덧붙인다:
      덩어리 번호가 공시마다 1 부터 다시 시작해 다른 공시의 다른 처분이 같은 줄이 되므로, 건너뛰면
      기록이 사라진다. 다시 돌린 만큼 겹칠 뿐이다.
  one-line        <file>
      파일 내용을 `log` 와 같은 규칙으로 한 줄로 이어 stdout 에 낸다 — 엔진의 `--reason` 처럼 인자로만
      받는 자리에 `"$(… one-line <file>)"` 로 넘긴다(명령 치환의 출력은 다시 전개되지 않는다).
      비었거나 못 읽으면 rc 2.
  append-verbatim <audit> --section H --title T <file>
      <file> 내용을 인용 블록으로 H 절 끝에 붙인다. 내용 안의 다른 줄 나눔 글자(`LINE_BREAK_CHARS`)는
      `\n` 으로 바꾼 뒤 줄마다 인용 표시를 단다 — audit 에 그 글자가 남으면 읽는 쪽이 판단을 거부한다.
      제목 T 도 한 줄로 잇는다. `## 6` 에는 붙이지 않는다(rc 2) — 그 절에는 기록 줄만 산다.

audit 의 절 구조는 `heading_structure` 하나가 판정한다 — 일곱 템플릿 제목은 각각 많아야 한 번,
템플릿 순서대로 나와야 한다(없는 제목은 «절 없음»). 비신뢰 `## 1` 원문 안에 심긴 제목은 펜스 안이든
밖이든 겹치거나 순서가 어긋난다. 펜스는 보지 않는다 — 원문의 닫히지 않은 펜스(잘린 붙여 넣기)가 뒤 절의
펜스와 짝지어져 진짜 제목을 삼키면 정직한 audit 이 막힌다. `## 6` 을 읽고 쓰는 모든 길(`user-quotes` ·
`check-drops` · `log` · `append-verbatim` · `parse_lines`)은 구조가 어긋나면 판단 · 쓰기를 거부한다
(rc 2 · `AuditAmbiguous`) — 어느 줄이 진짜 절인지 이 코드가 골라 버리면 심은 글이 사용자 결정 문구로
읽히거나 기록이 원문 안에 적힌다.

`## 6` 의 줄은 허용 목록으로 읽는다 — 빈 줄이 아닌 줄은 전부 엔진 기록 줄(`ENGINE_LINE_RE`) · 이 파일의
기록 줄(`HOST_LINE_RE`) · 엔진 계수 줄(`COUNT_LINE_RE` — 엔진의 `docreview_advice.count_line` 에서 도출) ·
절 머리의 템플릿 안내 괄호(템플릿 파일 그대로) · `없음` 한 줄 중 하나여야 한다. 모르는 줄이 하나라도 있으면 «모르는 것은
통과» 가 아니라 판단 · 쓰기 거부다(rc 2 · `AuditUnknownLine`). 거부 사유의 첫 줄은
`[seed_review_log] ## 6 에 기록 모양이 아닌 줄이 있다 — <n>째 줄` 이고 줄 글자는 싣지 않는다.

**줄은 `\n` 으로만 나눈다.** U+2028 · U+2029 · NEL · FF · VT · FS/GS/RS 같은 다른 줄 나눔 글자(`str.splitlines`
가 끊는 나머지)가 audit 에 하나라도 있으면 모든 읽는 길이 판단을 거부한다(rc 2) — 마크다운은 거기서 줄을
나누지 않는데 `splitlines` 는 나눠, 한 줄 안의 «사용자가 적은 말» 이 새 풀이 줄이나 기록 줄로 읽혔다.
거부 사유의 첫 줄은 `[seed_review_log] audit 에 줄을 나누는 다른 글자가 있다 — <n>째 줄` 이다.

엔진 원장(`docreview-state.md`)의 내부 형식은 읽지 않는다 — 엔진이 CLI 로 내는 `gate` 요약과
엔진이 audit 에 쓴 줄만 읽는다. 엔진 줄 모양이 바뀌면 tests/test_seed_review_log.sh 의 엔진
왕복이 RED 가 된다.
rc: 0 정상 · 1 check-drops 위반 · 2 입력 오류(그 밖의 예외 포함 — rc 1 은 위반에만 쓴다).
"""
from __future__ import annotations

import argparse
import json
import pathlib
import re
import sys
import unicodedata

_SCRIPTS_DIR = str(pathlib.Path(__file__).resolve().parent)
if _SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, _SCRIPTS_DIR)
import section6  # noqa: E402 — 제목 모양 판정은 이 리포에서 한 곳이다(§6-단일화 락)
import docreview_advice  # noqa: E402 — 엔진 계수 줄의 모양은 엔진이 정한다

DECISION_HEADING = "## 6. 리뷰 결정"
HOST_KINDS = ("편집", "답", "거부")
ENGINE_LINE_RE = re.compile(
    r'^- (?P<did>D\d+\.\d+) · r(?P<round>\d+) · (?P<choice>[a-z]+) · (?P<ids>[^"]+?) · '
    r'"(?P<quote>.*?)"(?: · supersedes D\d+\.\d+)? —')
HOST_LINE_RE = re.compile(
    r'^- (?P<kind>편집|답|거부) · r(?P<round>\d+) · (?P<target>[^"]*?) · "(?P<quote>.*?)" —')

# `interview-seed-audit-template.md` 의 일곱 절 제목 — 절 경계의 유일한 근거다. 이 밖의 `## ` 로
# 시작하는 줄(사용자가 붙여 넣은 마크다운 안의 `## 배경` 같은 줄)은 절을 끊지 않는다 —
# `section_body` 가 임의의 `## ` 줄에서 멈추면 비신뢰 본문 안의 heading-모양 줄 하나가 진짜 절 뒤
# 내용을 조용히 잘라낸다.
AUDIT_HEADINGS = (
    "## 1. 원문",
    "## 2. 질문 전체",
    "## 3. 긴 초안",
    "## seed 에서 덜어 낸 것",
    "## 4. 비평과 냉독",
    "## 5. degrade",
    "## 6. 리뷰 결정",
)


class AuditAmbiguous(ValueError):
    """audit 의 절 경계를 하나로 정할 수 없다 — 판단을 거부한다(rc 2)."""


class AuditUnknownLine(AuditAmbiguous):
    """`## 6` 에 허용 목록 밖의 줄이 있다 — 판단 · 쓰기를 거부한다(rc 2). 메시지 첫 줄이 쉬운 사유다."""


def _count_line_re() -> re.Pattern:
    """엔진 계수 줄 모양 — 엔진의 `count_line` 이 자리표 값으로 만든 줄에서 도출한다(손으로 다시 적지 않는다)."""
    marks = {"IDENTSENTINEL": r"\S+", "98765": r"\d+", "11111": r"\d+", "22222": r"\d+", "33333": r"\d+"}
    pat = re.escape(docreview_advice.count_line(
        "IDENTSENTINEL", 98765, {"advice_new": 11111, "advice_repeat": 22222, "mc_preexisting_new": 33333}))
    for k, v in marks.items():
        assert pat.count(k) == 1, k
        pat = pat.replace(k, v)
    return re.compile("^" + pat + "$")


COUNT_LINE_RE = _count_line_re()
EMPTY_SECTION = "없음"  # 기록이 없는 절을 적는 audit 관례(`## 5` 와 같다)
TEMPLATE_PATH = pathlib.Path(__file__).resolve().parent.parent / "templates" / "interview-seed-audit-template.md"


def fold_for_match(s: str) -> str:
    """판정용 접기 — 서식 문자(Cf: 제로폭 · BOM · 소프트 하이픈 등)를 지우고 NFKC 로 호환 글자(전각 ·
    작은 괄호 등)를 정본으로 바꾼 뒤, 앞 글자에 붙는 결합 기호(Mn · Me: 이형 선택자 등)를 지운다.
    사람과 모델은 이 차이를 같은 글자로 읽는다. 판정에만 쓴다 — 원문 바이트는 바꾸지 않는다."""
    s = unicodedata.normalize("NFKC", "".join(ch for ch in s if unicodedata.category(ch) != "Cf"))
    return "".join(ch for ch in s if unicodedata.category(ch) not in ("Cf", "Mn", "Me"))


# `\n` 밖에서 `str.splitlines` 가 줄을 끊는 글자 전부(`\r` 은 파일을 읽을 때 `\n` 으로 바뀐다).
LINE_BREAK_CHARS = "\r\x0b\x0c\x1c\x1d\x1e\x85\u2028\u2029"
_TO_NEWLINE = {ord(c): "\n" for c in LINE_BREAK_CHARS}


def to_newlines(s: str) -> str:
    """다른 줄 나눔 글자를 `\n` 으로 — 쓰는 쪽(`one_line` · `append-verbatim`)만 쓴다."""
    return s.translate(_TO_NEWLINE)


def separator_lines(text: str) -> list[int]:
    """다른 줄 나눔 글자가 든 줄의 번호(`\n` 기준 1-based). 비어 있으면 줄 구분이 하나로 정해진다."""
    return [n for n, line in enumerate(text.split("\n"), 1) if any(c in LINE_BREAK_CHARS for c in line)]


def separator_message(lines: list[int]) -> str:
    return "\n".join("audit 에 줄을 나누는 다른 글자가 있다 — %d째 줄" % n for n in lines)


def heading_lines(text: str, heading: str) -> list[tuple[int, bool]]:
    """줄 전체(앞뒤 공백 제외)가 `heading` 인 줄마다 `(줄 번호 0-based, 절 시작으로 인정되는가)`. 줄은 `\n`
    으로만 나눈다. 인정 조건은 제목 모양(`section6.HEADING_SHAPED_RE` — 들여쓰기 0–3칸. 4칸이면 코드
    블록이다) 하나다. 펜스는 보지 않는다(모듈 docstring — 심긴 제목은 `heading_structure` 가 잡는다)."""
    return [(i, section6.HEADING_SHAPED_RE.match(line) is not None)
            for i, line in enumerate(text.split("\n")) if line.strip() == heading]


def section_body(text: str, heading: str) -> str | None:
    """`heading` 절 시작으로 인정되는 첫 줄(`heading_lines`) 다음부터, `AUDIT_HEADINGS` 일곱 제목 중
    하나와 줄 전체가 같은 다음 줄 전까지(임의의 `## ` 줄이 아니다 — 비신뢰 본문 안에 `## ` 로 시작하는
    줄이 있어도 그 줄에서 절이 끊기지 않는다). 끝은 들여 쓴 제목 줄에서도 끊는다 — 끊는 쪽으로 틀리면
    덜 읽을 뿐이다. 인정되는 시작 줄이 없으면 None. 겹침 · 순서는 `heading_structure` 가 따로 본다."""
    starts = [i for i, ok in heading_lines(text, heading) if ok]
    if not starts:
        return None
    lines = text.split("\n")
    body = []
    for nxt in lines[starts[0] + 1:]:
        if nxt.strip() in AUDIT_HEADINGS:
            break
        body.append(nxt)
    return "\n".join(body)


def duplicate_headings(text: str) -> list[tuple[str, list[int]]]:
    """`AUDIT_HEADINGS` 중 텍스트에 줄 전체 일치로 두 번 이상(펜스 안팎 가리지 않고) 나오는 것과
    그 1-based 줄 번호들. `section_body` 는 첫 occurrence 를 고르므로, 비신뢰 본문 안에 같은
    제목 줄이 심겨 있으면 그 occurrence 가 진짜 절 시작을 가릴 수 있다. 비어 있으면 모호함이
    없다는 뜻이다."""
    lines = text.split("\n")
    out: list[tuple[str, list[int]]] = []
    for heading in AUDIT_HEADINGS:
        nums = [i + 1 for i, line in enumerate(lines) if line.strip() == heading]
        if len(nums) > 1:
            out.append((heading, nums))
    return out


def heading_structure(text: str) -> list[str]:
    """일곱 템플릿 제목(`AUDIT_HEADINGS`)이 각각 많아야 한 번, 템플릿 순서대로 나오는가 — 어긋난 사유들
    (제목과 1-based 줄 번호). 비어 있으면 구조가 하나로 정해진다. 줄은 `duplicate_headings` 와 같이 센다
    (줄 전체 일치 · 펜스 · 들여쓰기를 가리지 않는다). 없는 제목은 사유가 아니다 — «절 없음» 은 소비자가 판단한다.
    다른 줄 나눔 글자가 있으면 그것이 먼저다(줄 구분부터 정해지지 않는다)."""
    sep = separator_lines(text)
    if sep:
        return ["line_separator 줄 %s" % "·".join(map(str, sep))]
    out = ["duplicate_heading `%s` 줄 %s" % (h, "·".join(map(str, nums)))
           for h, nums in duplicate_headings(text)]
    if out:
        return out
    lines = text.split("\n")
    at = {}
    for h in AUDIT_HEADINGS:
        nums = [i + 1 for i, line in enumerate(lines) if line.strip() == h]
        if nums:
            at[h] = nums[0]
    present = [h for h in AUDIT_HEADINGS if h in at]
    return ["heading_order `%s`(줄 %d) 가 `%s`(줄 %d) 보다 앞에 있다 — 템플릿에서는 뒤에 온다"
            % (b, at[b], a, at[a]) for a, b in zip(present, present[1:]) if at[a] > at[b]]


def _template_guidance() -> list[str]:
    """템플릿 `## 6` 의 안내 괄호 줄(앞뒤 공백 제외). 템플릿을 못 읽으면 빈 목록 — 안내 괄호를 받지 않는 쪽(엄격)."""
    try:
        tpl = TEMPLATE_PATH.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        return []
    return [ln.strip() for ln in (section_body(tpl, DECISION_HEADING) or "").split("\n") if ln.strip()]


def decision_line_problems(audit_text: str) -> list[int]:
    """`## 6` 의 빈 줄 아닌 줄 가운데 허용 목록(모듈 docstring) 밖의 줄 번호(파일 기준 1-based)."""
    found = [i for i, ok in heading_lines(audit_text, DECISION_HEADING) if ok]
    if not found:
        return []
    lines = audit_text.split("\n")
    rows = []
    for j in range(found[0] + 1, len(lines)):
        if lines[j].strip() in AUDIT_HEADINGS:
            break
        if lines[j].strip():
            rows.append((j + 1, lines[j]))
    guide = _template_guidance()
    if guide and [ln.strip() for _, ln in rows[:len(guide)]] == guide:
        rows = rows[len(guide):]
    return [n for n, ln in rows
            if not (ENGINE_LINE_RE.match(ln) or HOST_LINE_RE.match(ln) or COUNT_LINE_RE.match(ln)
                    or ln.strip() == EMPTY_SECTION)]


def require_unambiguous(audit_text: str, heading: str) -> None:
    """`heading` 절을 읽거나 쓰기 전에 — 템플릿 제목 구조가 어긋나거나(`heading_structure`), `heading`
    줄이 있는데 절 시작으로 인정되지 않으면(코드 블록 · 한 줄 안에 숨음) `AuditAmbiguous`."""
    sep = separator_lines(audit_text)
    if sep:
        raise AuditUnknownLine("\n".join("[seed_review_log] " + ln for ln in separator_message(sep).split("\n")))
    problems = heading_structure(audit_text)
    if problems:
        raise AuditAmbiguous("; ".join(problems))
    found = heading_lines(audit_text, heading)
    if found and not any(ok for _, ok in found):
        raise AuditAmbiguous("heading_not_a_section %s" % heading)
    if heading == DECISION_HEADING:
        bad = decision_line_problems(audit_text)
        if bad:
            raise AuditUnknownLine("\n".join("[seed_review_log] ## 6 에 기록 모양이 아닌 줄이 있다 — %d째 줄" % n
                                             for n in bad))


def parse_lines(audit_text: str) -> list[dict]:
    require_unambiguous(audit_text, DECISION_HEADING)
    out = []
    for line in (section_body(audit_text, DECISION_HEADING) or "").split("\n"):
        m = ENGINE_LINE_RE.match(line)
        if m:
            out.append({"source": "engine", "choice": m["choice"], "round": int(m["round"]),
                        "ids": [s.strip() for s in m["ids"].split(",")], "quote": m["quote"]})
            continue
        m = HOST_LINE_RE.match(line)
        if m:
            out.append({"source": "host", "kind": m["kind"], "round": int(m["round"]),
                        "target": m["target"], "quote": m["quote"]})
    return out


def user_quotes(audit_text: str) -> list[str]:
    seen, out = set(), []
    for e in parse_lines(audit_text):
        q = e["quote"].strip()
        if q and q not in seen:
            seen.add(q)
            out.append(q)
    return out


def check_drops(audit_text: str, dropped: list[str]) -> list[dict]:
    """문구가 있는 기록은 둘 중 하나다 — 엔진의 drop 줄(`fix --event drop --reason … --log-file`),
    또는 이 파일의 `거부` 줄(문구 없이 눌린 drop 을 사용자에게 다시 물어 채운 것)."""
    quoted, bare = set(), set()
    for e in parse_lines(audit_text):
        if e["source"] == "engine" and e["choice"] == "drop":
            for fid in e["ids"]:
                (quoted if e["quote"].strip() else bare).add(fid)
        elif e["source"] == "host" and e["kind"] == "거부":
            (quoted if e["quote"].strip() else bare).add(e["target"].strip())
    return [{"id": fid, "reason": "empty_quote" if fid in bare else "no_log_line"}
            for fid in dropped if fid not in quoted]


def append_under(path: pathlib.Path, heading: str, block: str) -> None:
    """`heading` 절의 끝(다음 `## ` 앞, 절 끝 빈 줄 앞)에 block 을 붙인다. 절이 없으면 파일 끝에 만든다.
    읽는 쪽과 같은 절을 고른다 — 절 경계가 모호하면(`require_unambiguous`) 쓰지 않고 `AuditAmbiguous`."""
    text = path.read_text(encoding="utf-8")
    require_unambiguous(text, heading)
    lines = text.split("\n")
    block_lines = block.rstrip("\n").split("\n")
    found = [i for i, ok in heading_lines(text, heading) if ok]
    start = None
    if found:
        start = found[0]
    if start is None:
        text = "\n".join(lines).rstrip("\n") + "\n\n" + heading + "\n\n" + "\n".join(block_lines) + "\n"
        path.write_text(text, encoding="utf-8")
        return
    end = next((j for j in range(start + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
    ins = end
    while ins > start + 1 and lines[ins - 1].strip() == "":
        ins -= 1
    tail = lines[ins:]
    if tail and tail[0].strip() != "":
        tail = [""] + tail
    text = "\n".join(lines[:ins] + [""] + block_lines + tail)
    if not text.endswith("\n"):
        text += "\n"
    path.write_text(text, encoding="utf-8")


def one_line(s: str) -> str:
    """줄 나눔 글자(`\\n` 과 `LINE_BREAK_CHARS`)를 한 칸으로 — 줄마다 앞뒤 공백을 걷고 빈 줄은 뺀다."""
    return " ".join(part.strip() for part in to_newlines(s).split("\n") if part.strip())


def format_host_line(kind: str, rnd: int, target: str, quote: str, note: str) -> str:
    # 한 줄에 한 기록 — 줄바꿈이 남으면 둘째 줄이 다른 기록(엔진 줄 모양이면 엔진 기록)으로 읽힌다.
    # 큰따옴표는 이 줄의 파싱 경계다 — 사용자 문구 속 큰따옴표는 홑따옴표로 적는다.
    target = one_line(target).replace('"', "'")
    quote = one_line(quote).replace('"', "'")
    return ('- %s · r%d · %s · "%s" — %s' % (kind, rnd, target, quote, one_line(note or ""))).rstrip()


def _read(path: str) -> str:
    return pathlib.Path(path).read_text(encoding="utf-8")


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(prog="seed_review_log.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("user-quotes"); x.add_argument("audit")
    x = sp.add_parser("check-drops"); x.add_argument("audit"); x.add_argument("gate_json")
    # 줄임 인자를 받지 않는다 — 받으면 없앤 `--quote` 가 `--quote-file` 의 줄임으로 살아난다.
    x = sp.add_parser("log", allow_abbrev=False); x.add_argument("audit")
    x.add_argument("--kind", required=True); x.add_argument("--round", required=True, type=int)
    x.add_argument("--target", required=True)
    x.add_argument("--quote-file", required=True)
    g = x.add_mutually_exclusive_group()
    g.add_argument("--note", default=""); g.add_argument("--note-file")
    x = sp.add_parser("one-line"); x.add_argument("file")
    x = sp.add_parser("append-verbatim"); x.add_argument("audit")
    x.add_argument("--section", required=True); x.add_argument("--title", required=True)
    x.add_argument("file")
    try:
        a = p.parse_args(argv)
    except SystemExit:
        return 2
    try:
        if a.cmd == "user-quotes":
            for q in user_quotes(_read(a.audit)):
                print('- "%s"' % q)
            return 0
        if a.cmd == "check-drops":
            try:
                g = json.loads(_read(a.gate_json))
            except ValueError as e:
                print(json.dumps({"ok": False, "error": "gate_unreadable: %s" % e}, ensure_ascii=False))
                return 2
            dropped = g.get("dropped") if isinstance(g, dict) else None
            if not isinstance(dropped, list):
                print(json.dumps({"ok": False, "error": "gate_has_no_dropped_list"}, ensure_ascii=False))
                return 2
            audit_text = _read(a.audit)
            try:
                require_unambiguous(audit_text, DECISION_HEADING)
            except AuditAmbiguous as e:
                if isinstance(e, AuditUnknownLine):
                    print(str(e), file=sys.stderr)
                print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
                return 2
            v = check_drops(audit_text, dropped)
            print(json.dumps({"ok": not v, "dropped": dropped, "violations": v}, ensure_ascii=False))
            return 1 if v else 0
        if a.cmd == "log":
            if a.kind not in HOST_KINDS:
                print("kind 는 %s 중 하나다: %r" % ("/".join(HOST_KINDS), a.kind), file=sys.stderr)
                return 2
            require_unambiguous(_read(a.audit), DECISION_HEADING)
            quote = _read(a.quote_file)
            note = _read(a.note_file) if a.note_file else a.note
            if not one_line(quote):
                print("[spec-distill] 사용자 문구가 비었다(target=%r, file=%r) — 적지 않는다(고른 라벨 또는 "
                      "적은 말을 넘겨라)" % (a.target, a.quote_file), file=sys.stderr)
                return 2
            line = format_host_line(a.kind, a.round, a.target, quote, note)
            if not HOST_LINE_RE.match(line) or "\n" in line or separator_lines(line):
                print("만든 줄이 파서 모양과 맞지 않는다: %s" % line, file=sys.stderr)
                return 2
            # 같은 줄 건너뛰기는 `답` · `거부` 에만 쓴다 — 그 둘의 대상은 finding id 라 줄이 처분을
            # 유일하게 가리킨다. `편집` 은 다르다: 덩어리 번호가 공시마다 1 부터 다시 시작하고 문구는
            # 고른 라벨이라, 다른 공시의 다른 처분이 글자까지 같은 줄이 된다 — 그것을 「이미 있다」로
            # 읽으면 그 처분 기록이 조용히 사라진다(AC6). 되돌리기의 멱등은 `<base>.reverted` 표지가
            # 따로 맡으므로, 여기서는 다시 돌린 만큼 줄이 겹칠 뿐 기록이 빠지지는 않는다.
            if a.kind != "편집":
                existing = (section_body(_read(a.audit), DECISION_HEADING) or "").split("\n")
                if line in existing:
                    print("[spec-distill] 같은 기록 줄이 이미 있다 — 다시 적지 않는다: %s" % line, file=sys.stderr)
                    return 0
            append_under(pathlib.Path(a.audit), DECISION_HEADING, line)
            return 0
        if a.cmd == "one-line":
            s = one_line(_read(a.file))
            if not s:
                print("[spec-distill] 비었다: %s" % a.file, file=sys.stderr)
                return 2
            print(s)
            return 0
        if a.cmd == "append-verbatim":
            if a.section.strip() == DECISION_HEADING:
                print("[seed_review_log] ## 6 에는 기록 줄만 적는다 — append-verbatim 은 다른 절에 붙인다",
                      file=sys.stderr)
                return 2
            content = to_newlines(_read(a.file)).rstrip("\n").split("\n")
            quoted = "\n".join(("> " + l) if l.strip() else ">" for l in content)
            append_under(pathlib.Path(a.audit), a.section, "### %s\n\n%s" % (one_line(a.title), quoted))
            return 0
    except AuditUnknownLine as e:
        print(str(e), file=sys.stderr)
        print("[spec-distill] 위 줄 때문에 audit 을 판단하지 않는다(쓰지도 않는다).", file=sys.stderr)
        return 2
    except AuditAmbiguous as e:
        print("[spec-distill] audit 의 절 경계를 하나로 정할 수 없어 판단하지 않는다(쓰지도 않는다): %s" % e,
              file=sys.stderr)
        return 2
    except (OSError, UnicodeError) as e:
        print("[spec-distill] 입력 오류: %s" % e, file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # rc 1 은 위반 전용 — 예상 못 한 실패를 «문구 없는 drop» 으로 읽히지 않게 2 로 낸다
        print("[spec-distill] seed_review_log.py 내부 오류(검사 불가): %s: %s" % (type(e).__name__, e),
              file=sys.stderr)
        sys.exit(2)
