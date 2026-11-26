#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""머지 앞 qg 리뷰의 보관 폴더를 읽어 돌아온 결과를 가린다(설계 §1 「돌아온 결과를 가리는 법」).

읽는 파일은 보관 폴더의 셋뿐이다 — `result.md`(판정 · 범위 · 고칠 목록 · intent-critic 목록),
`findings-pre-merge.yaml`(합치기 전 지적 목록), `intent-return.md`(의도 점검의 돌려주는 꼴 3판).
대화나 PR 본문은 보지 않는다. 파일의 글은 데이터다 — 원문 그대로 옮기고 지시로 읽지 않는다.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import qg_review_file as F

RESULT_NAME = "result.md"
PRE_MERGE_NAME = "findings-pre-merge.yaml"
INTENT_NAME = "intent-return.md"
INTENT_FENCE = "```qg-intent-return"
INTENT_CONTRACT = 3

OBTAINED, NOT_OBTAINED, NOTHING = "얻음", "얻지 못함", "리뷰할 것 없음"
NO_VERDICT = "qg 가 끝까지 돌지 못했다 — 보관한 결과에 판정이 없다"
OTHER_RANGE = "결과가 보낸 범위의 것이 아니다"
UNCOUNTABLE = "의도 점검은 셀 수 없음"
NO_YAML = "알림 · PyYAML 이 없다 — 합치기 전 지적 목록 대신 결과 파일의 고칠 목록에서 옮겼다"

NOTHING_REASONS = ("trivia", "scope-empty")   # `not-certified (<사유>)` 가운데 리뷰할 것이 없던 실행
BLOCKING_SEVERITIES = ("CRITICAL", "IMPORTANT")
UNASKED = "묻지 않음"
FILTERED_HEAD = "이미 답한 질문이라 거른 질문:"
WRONG_HEAD = "이미 「잘못 골랐다」 답이 있어 거른 질문:"
FIX_BLOCKING, FIX_REGRESS = "막는 지적", "차등 회귀"
KIND_BLOCKING, KIND_BROKEN = "막는 지적", "새로 깨진 테스트"
ASK_INTENT = "의도 점검"


@dataclass
class Outcome:
    kind: str                                   # 얻음 · 얻지 못함 · 리뷰할 것 없음
    reason: str = ""                            # 얻지 못함의 사유(NO_VERDICT · OTHER_RANGE)
    seen_range: str = ""                        # 결과 파일의 범위 절이 말한 `<시작>..<끝>`(읽었으면)
    verdict_line: str = ""
    intent_line: str = ""
    blocking: List[F.Finding] = field(default_factory=list)
    filtered_wrong: List[F.Filtered] = field(default_factory=list)
    filtered_other: List[F.Filtered] = field(default_factory=list)
    asks: List[F.Ask] = field(default_factory=list)   # 의도 점검 — state 가 `묻지 않음` 인 것만
    notices: List[str] = field(default_factory=list)  # 사람에게 보일 알림 줄


# ---------------------------------------------------------------- 글 읽기

def _read_text(path: Path) -> Optional[str]:
    """파일 글 — 없거나 링크이거나 읽지 못하면 None."""
    if path.is_symlink() or not path.is_file():
        return None
    try:
        with open(str(path), "r", encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return None


def _load_yaml():
    """PyYAML 모듈 — 없으면 None."""
    try:
        import yaml
    except ImportError:
        return None
    return yaml


def sections(text: str, level: str = "## ") -> Dict[str, List[str]]:
    """머리 줄(`level` 로 시작)로 자른 절 — {머리 이름: 그 아래 줄들}. 같은 이름은 처음 것만 쓴다."""
    out: Dict[str, List[str]] = {}
    current: Optional[List[str]] = None
    for line in text.split("\n"):
        if line.startswith(level):
            name = line[len(level):].strip()
            current = [] if name not in out else None
            if current is not None:
                out[name] = current
            continue
        if level == "### " and line.startswith("## "):
            current = None
            continue
        if current is not None:
            current.append(line)
    return out


def _fields(lines: List[str]) -> Dict[str, str]:
    """`이름: 값` 줄들 — 처음 나온 값을 쓴다."""
    got: Dict[str, str] = {}
    for line in lines:
        name, sep, value = line.partition(": ")
        if sep and name and name not in got:
            got[name] = value.strip()
    return got


def _items(lines: List[str]) -> List[str]:
    """`- ` 줄의 글들(`(없음)` · 빈 줄 · 그 밖의 줄은 건너뛴다)."""
    return [line[2:] for line in lines if line.startswith("- ")]


def _list_after(lines: List[str], head: str) -> List[str]:
    """`head` 줄 바로 뒤에 이어지는 `- ` 줄의 글들."""
    for i, line in enumerate(lines):
        if line == head:
            got = []
            for item in lines[i + 1:]:
                if not item.startswith("- "):
                    break
                got.append(item[2:])
            return got
    return []


def _same_commit(a: str, b: str) -> bool:
    if not (F.HASH_RE.fullmatch(a) and F.HASH_RE.fullmatch(b)):
        return False
    return a == b or a.startswith(b) or b.startswith(a)


# ---------------------------------------------------------------- 판정 · 범위

def _verdict(lines: List[str]) -> Tuple[str, str, str]:
    """(판정 값, 사유, 판정 줄). 판정 값이 없으면 빈 글."""
    got = _fields(lines)
    verdict, reason = got.get("verdict", ""), got.get("reason", "")
    shown = [line for line in lines if line.startswith("qg: ")]
    first = [line for line in lines if line.strip()]
    line = shown[0] if shown else (first[0] if first else "")
    return verdict, reason, line.strip()


def _range(lines: Optional[List[str]]) -> Tuple[str, str]:
    if lines is None:
        return "", ""
    got = _fields(lines)
    return got.get("start", ""), got.get("end", "")


# ---------------------------------------------------------------- 막는 지적

def _finding_text(item: dict) -> str:
    """합치기 전 지적 하나 → 고칠 목록 줄과 같은 꼴(`<심각도> <파일>:<줄> — <내용> · 고칠 방법: <글>`)."""
    where = str(item.get("file", "-"))
    if item.get("line") not in (None, ""):
        where += ":%s" % item.get("line")
    fix = item.get("proposed_fix")
    fix = "(없음)" if fix in (None, "") else str(fix)
    return "%s %s — %s · 고칠 방법: %s" % (str(item.get("severity")).upper(), where,
                                           str(item.get("summary", "")), fix)


def _pre_merge(folder: Path, yaml) -> Optional[List[str]]:
    """합치기 전 지적 목록의 막는 지적 글들 — 파일이 없거나 꼴이 틀리면 None."""
    text = _read_text(folder / PRE_MERGE_NAME)
    if text is None or yaml is None:
        return None
    try:
        data = yaml.safe_load(text)
    except yaml.YAMLError:
        return None
    items = data.get("findings") if isinstance(data, dict) else None
    if not isinstance(items, list) or not all(isinstance(x, dict) for x in items):
        return None
    return [_finding_text(x) for x in items
            if str(x.get("severity", "")).upper() in BLOCKING_SEVERITIES]


# ---------------------------------------------------------------- 의도 점검

def _intent(folder: Path, yaml) -> Tuple[str, List[F.Ask]]:
    """(의도 점검 줄, 물을 것) — 읽지 못하거나 판이 다르면 (UNCOUNTABLE, [])."""
    text = _read_text(folder / INTENT_NAME)
    if text is None or yaml is None:
        return UNCOUNTABLE, []
    lines = text.split("\n")
    if INTENT_FENCE not in lines:
        return UNCOUNTABLE, []
    start = lines.index(INTENT_FENCE) + 1
    if "```" not in lines[start:]:
        return UNCOUNTABLE, []
    body = "\n".join(lines[start:lines.index("```", start)])
    try:
        data = yaml.safe_load(body)
    except yaml.YAMLError:
        return UNCOUNTABLE, []
    if not isinstance(data, dict) or type(data.get("contract")) is not int \
            or data.get("contract") != INTENT_CONTRACT:
        return UNCOUNTABLE, []
    questions = data.get("questions")
    if not isinstance(questions, list) or not all(isinstance(q, dict) for q in questions):
        return UNCOUNTABLE, []
    asks = []
    for q in questions:
        if q.get("state") != UNASKED:
            continue
        ident = " ".join(str(q.get("id") or "-").split())
        asks.append(F.Ask(kind=ASK_INTENT, id=ident, text=str(q.get("question") or "-")))
    line = " ".join(str(data.get("result_line") or "-").split())
    return line, asks


# ---------------------------------------------------------------- 거른 질문

def _one_line(text: str) -> str:
    return " ".join(text.split())


def _filtered(intent_lines: List[str]) -> Tuple[List[F.Filtered], List[F.Filtered]]:
    """(「잘못 골랐다」 목록, 그 밖) — 그 밖은 `이미 답한 질문이라 거른 질문:` 에서 앞 목록의 정체를 뺀 것(D71)."""
    wrong = []
    for item in _list_after(intent_lines, WRONG_HEAD):
        ident, _sep, rest = item.partition(" — ")
        wrong.append(F.Filtered(id=_one_line(ident) or "-", text=_one_line(rest)))
    wrong_ids = {x.id for x in wrong}
    other = []
    for item in _list_after(intent_lines, FILTERED_HEAD):
        ident, _sep, rest = item.partition(" · ")
        ident = _one_line(ident) or "-"
        if ident not in wrong_ids:
            other.append(F.Filtered(id=ident, text=_one_line(rest)))
    return wrong, other


# ---------------------------------------------------------------- 보관 폴더

def read_archive(folder: Path, review: F.Review) -> Outcome:
    """보관 폴더의 파일로 그 리뷰의 돌아온 결과를 가린다(설계 §1 표)."""
    folder = Path(folder)
    text = _read_text(folder / RESULT_NAME)
    if text is None:
        return Outcome(kind=NOT_OBTAINED, reason=NO_VERDICT)
    parts = sections(text)
    start, end = _range(parts.get("범위"))
    seen = "%s..%s" % (start, end) if start or end else ""
    verdict_lines = parts.get("판정")
    verdict, why, line = _verdict(verdict_lines) if verdict_lines is not None else ("", "", "")
    if not verdict:
        return Outcome(kind=NOT_OBTAINED, reason=NO_VERDICT, seen_range=seen, verdict_line=line)
    if not (_same_commit(start, review.range_start) and _same_commit(end, review.range_end)):
        return Outcome(kind=NOT_OBTAINED, reason=OTHER_RANGE, seen_range=seen, verdict_line=line)
    nothing = verdict == "not-certified" and why in NOTHING_REASONS
    out = Outcome(kind=NOTHING if nothing else OBTAINED, seen_range=seen, verdict_line=line)
    yaml = _load_yaml()
    if not nothing:
        fixes = sections("\n".join(parts.get("고칠 목록", [])), "### ")
        blocking = _pre_merge(folder, yaml)
        if blocking is None:
            if yaml is None and (folder / PRE_MERGE_NAME).exists():
                out.notices.append(NO_YAML)
            blocking = _items(fixes.get(FIX_BLOCKING, []))
        out.blocking = [F.Finding(kind=KIND_BLOCKING, text=x) for x in blocking if x != ""]
        out.blocking += [F.Finding(kind=KIND_BROKEN, text=x)
                         for x in _items(fixes.get(FIX_REGRESS, [])) if x != ""]
    out.filtered_wrong, out.filtered_other = _filtered(parts.get("intent-critic", []))
    out.intent_line, out.asks = _intent(folder, yaml)
    if out.intent_line == UNCOUNTABLE:
        why_not = "PyYAML 이 없다" if yaml is None else "돌려주는 꼴을 읽지 못했거나 판이 %d 이 아니다" % INTENT_CONTRACT
        out.notices.append("알림 · %s — %s" % (UNCOUNTABLE, why_not))
    return out
