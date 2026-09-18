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
  log             <audit> --kind 편집|답|거부 --round N --target T --quote Q [--note S]
      finding 없는 처분(편집 · 답), 또는 문구 없이 눌린 drop 을 사용자에게 다시 물어 채운 기록(거부)
      한 줄을 `## 6` 에 적는다.
  append-verbatim <audit> --section H --title T <file>
      <file> 내용을 인용 블록으로 H 절 끝에 붙인다.

엔진 원장(`docreview-state.md`)의 내부 형식은 읽지 않는다 — 엔진이 CLI 로 내는 `gate` 요약과
엔진이 audit 에 쓴 줄만 읽는다. 엔진 줄 모양이 바뀌면 tests/test_seed_review_log.sh 의 엔진
왕복이 RED 가 된다.
rc: 0 정상 · 1 check-drops 위반 · 2 입력 오류.
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


def format_host_line(kind: str, rnd: int, target: str, quote: str, note: str) -> str:
    # 큰따옴표는 이 줄의 파싱 경계다 — 사용자 문구 속 큰따옴표는 홑따옴표로 적는다.
    target = target.replace('"', "'")
    quote = quote.replace('"', "'")
    return '- %s · r%d · %s · "%s" — %s' % (kind, rnd, target, quote, note or "")


def _read(path: str) -> str:
    return pathlib.Path(path).read_text(encoding="utf-8")


def main(argv=None) -> int:
    p = argparse.ArgumentParser(prog="seed_review_log.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    x = sp.add_parser("user-quotes"); x.add_argument("audit")
    x = sp.add_parser("check-drops"); x.add_argument("audit"); x.add_argument("gate_json")
    x = sp.add_parser("log"); x.add_argument("audit")
    x.add_argument("--kind", required=True); x.add_argument("--round", required=True, type=int)
    x.add_argument("--target", required=True); x.add_argument("--quote", required=True)
    x.add_argument("--note", default="")
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
            v = check_drops(_read(a.audit), dropped)
            print(json.dumps({"ok": not v, "dropped": dropped, "violations": v}, ensure_ascii=False))
            return 1 if v else 0
        if a.cmd == "log":
            if a.kind not in HOST_KINDS:
                print("kind 는 %s 중 하나다: %r" % ("/".join(HOST_KINDS), a.kind), file=sys.stderr)
                return 2
            line = format_host_line(a.kind, a.round, a.target, a.quote, a.note)
            if not HOST_LINE_RE.match(line):
                print("만든 줄이 파서 모양과 맞지 않는다: %s" % line, file=sys.stderr)
                return 2
            append_under(pathlib.Path(a.audit), DECISION_HEADING, line)
            return 0
        if a.cmd == "append-verbatim":
            content = _read(a.file).rstrip("\n").split("\n")
            quoted = "\n".join(("> " + l) if l.strip() else ">" for l in content)
            append_under(pathlib.Path(a.audit), a.section, "### %s\n\n%s" % (a.title, quoted))
            return 0
    except (OSError, UnicodeError) as e:
        print("[spec-distill] 입력 오류: %s" % e, file=sys.stderr)
        return 2
    return 2


if __name__ == "__main__":
    sys.exit(main())
