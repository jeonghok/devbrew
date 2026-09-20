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
  log             <audit> --kind 편집|답|거부 --round N --target T (--quote Q | --quote-file F)
                  [--note S | --note-file F]
      finding 없는 처분(편집 · 답), 또는 문구 없이 눌린 drop 을 사용자에게 다시 물어 채운 기록(거부)
      한 줄을 `## 6` 에 적는다. 사용자 문구 · 리뷰어 요약은 파일로 받는다(`--quote-file` ·
      `--note-file`) — 셸 인자에 직접 쓰면 그 안의 백틱 · `$( )` 를 셸이 실행한다. 여러 줄은 한 줄로
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
      <file> 내용을 인용 블록으로 H 절 끝에 붙인다. 줄 나눔은 읽는 쪽(`section_body`)과 같은
      `str.splitlines` 다 — `\n` 만으로 나누면 다른 줄 구분자 뒤 글자가 인용 표시 없는 줄로 읽힌다.

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

DECISION_HEADING = "## 6. 리뷰 결정"
HOST_KINDS = ("편집", "답", "거부")
ENGINE_LINE_RE = re.compile(
    r'^- (?P<did>D\d+\.\d+) · r(?P<round>\d+) · (?P<choice>[a-z]+) · (?P<ids>[^"]+?) · '
    r'"(?P<quote>.*?)"(?: · supersedes D\d+\.\d+)? —')
HOST_LINE_RE = re.compile(
    r'^- (?P<kind>편집|답|거부) · r(?P<round>\d+) · (?P<target>[^"]*?) · "(?P<quote>.*?)" —')

# `interview-seed-audit-template.md` 의 여섯 절 제목 — 절 경계의 유일한 근거다. 이 밖의 `## ` 로
# 시작하는 줄(사용자가 붙여 넣은 마크다운 안의 `## 배경` 같은 줄)은 절을 끊지 않는다 —
# `section_body` 가 임의의 `## ` 줄에서 멈추면 비신뢰 본문 안의 heading-모양 줄 하나가 진짜 절 뒤
# 내용을 조용히 잘라낸다.
AUDIT_HEADINGS = (
    "## 1. 원문",
    "## 2. 질문 전체",
    "## 3. 긴 초안",
    "## 4. 비평과 냉독",
    "## 5. degrade",
    "## 6. 리뷰 결정",
)


def section_body(text: str, heading: str) -> str | None:
    """`heading` 과 같은 줄 다음부터, `AUDIT_HEADINGS` 여섯 제목 중 하나와 줄 전체가 같은 다음
    줄 전까지(임의의 `## ` 줄이 아니다 — 비신뢰 본문 안에 `## ` 로 시작하는 줄이 있어도 그 줄에서
    절이 끊기지 않는다). 절이 없으면 None."""
    lines = text.splitlines()
    for i, line in enumerate(lines):
        if line.strip() == heading:
            body = []
            for nxt in lines[i + 1:]:
                if nxt.strip() in AUDIT_HEADINGS:
                    break
                body.append(nxt)
            return "\n".join(body)
    return None


def duplicate_headings(text: str) -> list[tuple[str, list[int]]]:
    """`AUDIT_HEADINGS` 중 텍스트에 줄 전체 일치로 두 번 이상(펜스 안팎 가리지 않고) 나오는 것과
    그 1-based 줄 번호들. `section_body` 는 첫 occurrence 를 고르므로, 비신뢰 본문 안에 같은
    제목 줄이 심겨 있으면 그 occurrence 가 진짜 절 시작을 가릴 수 있다. 비어 있으면 모호함이
    없다는 뜻이다."""
    lines = text.splitlines()
    out: list[tuple[str, list[int]]] = []
    for heading in AUDIT_HEADINGS:
        nums = [i + 1 for i, line in enumerate(lines) if line.strip() == heading]
        if len(nums) > 1:
            out.append((heading, nums))
    return out


def parse_lines(audit_text: str) -> list[dict]:
    out = []
    for line in (section_body(audit_text, DECISION_HEADING) or "").splitlines():
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
    """`heading` 절의 끝(다음 `## ` 앞, 절 끝 빈 줄 앞)에 block 을 붙인다. 절이 없으면 파일 끝에 만든다."""
    lines = path.read_text(encoding="utf-8").split("\n")
    block_lines = block.rstrip("\n").split("\n")
    start = next((i for i, l in enumerate(lines) if l.strip() == heading), None)
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
    """줄 구분자(`str.splitlines` 가 끊는 전부)를 한 칸으로 — 줄마다 앞뒤 공백을 걷고 빈 줄은 뺀다."""
    return " ".join(part.strip() for part in s.splitlines() if part.strip())


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
    x = sp.add_parser("log"); x.add_argument("audit")
    x.add_argument("--kind", required=True); x.add_argument("--round", required=True, type=int)
    x.add_argument("--target", required=True)
    g = x.add_mutually_exclusive_group(required=True)
    g.add_argument("--quote"); g.add_argument("--quote-file")
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
            dups = duplicate_headings(audit_text)
            if dups:
                print(json.dumps({"ok": False, "error": "duplicate_heading %s" % ", ".join(h for h, _ in dups)},
                                 ensure_ascii=False))
                return 2
            v = check_drops(audit_text, dropped)
            print(json.dumps({"ok": not v, "dropped": dropped, "violations": v}, ensure_ascii=False))
            return 1 if v else 0
        if a.cmd == "log":
            if a.kind not in HOST_KINDS:
                print("kind 는 %s 중 하나다: %r" % ("/".join(HOST_KINDS), a.kind), file=sys.stderr)
                return 2
            quote = _read(a.quote_file) if a.quote_file else a.quote
            note = _read(a.note_file) if a.note_file else a.note
            if not one_line(quote):
                print("[spec-distill] 사용자 문구가 비었다(target=%r, file=%r) — 적지 않는다(고른 라벨 또는 "
                      "적은 말을 넘겨라)" % (a.target, a.quote_file), file=sys.stderr)
                return 2
            line = format_host_line(a.kind, a.round, a.target, quote, note)
            if not HOST_LINE_RE.match(line) or len(line.splitlines()) != 1:
                print("만든 줄이 파서 모양과 맞지 않는다: %s" % line, file=sys.stderr)
                return 2
            # 같은 줄 건너뛰기는 `답` · `거부` 에만 쓴다 — 그 둘의 대상은 finding id 라 줄이 처분을
            # 유일하게 가리킨다. `편집` 은 다르다: 덩어리 번호가 공시마다 1 부터 다시 시작하고 문구는
            # 고른 라벨이라, 다른 공시의 다른 처분이 글자까지 같은 줄이 된다 — 그것을 「이미 있다」로
            # 읽으면 그 처분 기록이 조용히 사라진다(AC6). 되돌리기의 멱등은 `<base>.reverted` 표지가
            # 따로 맡으므로, 여기서는 다시 돌린 만큼 줄이 겹칠 뿐 기록이 빠지지는 않는다.
            if a.kind != "편집":
                existing = (section_body(_read(a.audit), DECISION_HEADING) or "").splitlines()
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
            content = _read(a.file).splitlines() or [""]
            quoted = "\n".join(("> " + l) if l.strip() else ">" for l in content)
            append_under(pathlib.Path(a.audit), a.section, "### %s\n\n%s" % (a.title, quoted))
            return 0
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
