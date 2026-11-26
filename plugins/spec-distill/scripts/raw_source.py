#!/usr/bin/env python3
"""원자료(framing 기록 파일)를 찾아 판결 한 줄을 내고, 결과물 첫 칸에 싣는 글과 리뷰 번들 블록을 낸다.

CLI
raw_source.py locate (--seed S | --interview P) [--absolute]
    --absolute: FOUND 의 경로를 절대경로로 낸다(--seed 는 os.path.abspath, --interview 는 상태 파일의 작업 트리 루트에 이은 것). 링크는 풀지 않는다.
raw_source.py first-cell --interview P
    stdout = first_cell_item 의 글 + 줄바꿈 하나(그 밖의 줄은 내지 않는다). 판결 줄은 stderr 마지막 줄.
raw_source.py place --interview P
    결과물의 S1 항목을 first_cell_item 으로 바꿔 쓴다. stdout 마지막 줄이 판결이다.
raw_source.py review-block --interview P [--with-sections]
    stdout = review_block 의 글(없으면 빈 출력). 판결 줄은 stderr 마지막 줄.

판결 줄(새 것): raw-source: PLACED <결과물 경로 — 받은 글자에서 도출한 것>
              raw-source: UNLOADABLE <n>줄 — 첫 줄 <절 이름> <k>째 줄(<사유 이름>)
종료 코드: 글을 냈거나 써 넣었다 · NO-FRAMING 0 / LOST 3 / UNLOADABLE 4 / 인자 오류 · 읽지 못함 · 쓰지 못함 2

locate 의 판결 줄 — stdout 마지막 줄이다(다른 줄은 stdout 에 내지 않는다)
    raw-source: FOUND <framing 기록 파일 경로>
    raw-source: NO-FRAMING
    raw-source: LOST <사유>
인자 오류 · 읽지 못함 · 쓰지 못함은 stderr `[raw_source] …` 한 줄이다(판결 줄은 내지 않는다). 새 명령 셋의 P 는 있는 파일이어야 한다.

찾는 길: seed 이름 끝의 `.md` 를 `.audit.md` 로 바꾼 파일이다. 받은 글자에서 도출하고 받은 경로를 풀지 않으며, seed 머리의
`audit_file:` 은 읽지 않는다. `--interview` 는 상태 파일 `seed:` 값(작업 트리 루트 기준 상대 경로)에서 같은 길로 간다 —
상태 파일 길은 seed 와 기록 파일이 작업 트리 안이고 링크를 거치지 않을 때만 따라간다(쓰는 쪽 `seed_value` 와 같은
`state_path.inside_root`). 아니면 LOST 다. `--seed` 길은 받은 경로를 그대로 따른다.

옆 생성기(`team_write._framing_from_state`)와 다른 갈래 둘:
- `seed:` 가 `없음` 이거나 비었는데 `## 풀린 입력` 이 seed 인 컨텍스트 쌓기를 옆 생성기는 framing 없는 컨텍스트 쌓기로 읽고
  이 모듈은 찾지 못함으로 읽는다 — 그쪽은 옮겨 적을 기록 파일이 없다는 것만 알면 되고, 이쪽은 첫 입력이 모델이 줄인 글이라는
  것까지 알아야 한다.
- 링크이거나 작업 트리 밖인 seed · 기록 파일을 옆 생성기는 따라 읽고 이 모듈은 LOST 로 읽는다.

기록 파일은 `seed_review_log.read_audit_text` 로 읽는다(`\\r\\n` 만 `\\n` 으로). 두 절(원문 절 · 질문 전체 절)의 줄에
다른 줄 나눔 글자(홀로 선 `\\r` · U+2028 등 — `seed_review_log.separator_lines`)가 있으면 그 줄은 `line_separator` 로
싣지 못한다 — 범용 줄바꿈으로 읽는 쪽에서는 그 글자가 들여쓰기 없는 새 줄이 된다.
"""
from __future__ import annotations

import argparse
import os
import re
import stat
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from state_path import frontmatter_scalars, inside_root, worktree_root  # noqa: E402
import brief_body  # noqa: E402
import legacy_names  # noqa: E402
import section6  # noqa: E402
import seed_review_log as srl  # noqa: E402

AUDIT_TYPE = legacy_names.INTENT_SEED_AUDIT
SEED_TYPE = legacy_names.INTENT_SEED
SEED_NONE = "없음"
INPUT_HEADING = "## 풀린 입력"

R_SEED_MISSING = "seed 파일이 없다 — {seed}"
R_SEED_NOT_MD = "seed 파일 이름이 .md 로 끝나지 않아 framing 기록 파일의 자리를 정하지 못한다 — {seed}"
R_AUDIT_MISSING = "seed 옆에 framing 기록 파일이 없다 — {audit}"
R_AUDIT_TYPE = "framing 기록 파일 머리의 type 이 intent-seed-audit 이 아니다 — {audit} (type: {kind})"
R_SEED_UNSAFE = "상태 파일의 seed 경로가 작업 트리 밖이거나 링크를 거친다 — {seed}: {why}"
R_AUDIT_UNSAFE = "framing 기록 파일이 작업 트리 밖이거나 링크를 거친다 — {audit}: {why}"
R_SEED_UNRECORDED = ("seed 로 시작했는데 상태 파일에 seed 경로가 기록되지 않았다 — 붙여 넣은 seed 이거나 링크 · "
                     "작업 트리 밖 · 이름 꼴이 다른 seed 다")

LABEL_RAW = "최초 요청(원자료 — framing 기록의 원문 절과 질문 전체 절)"
LABEL_UNLOADABLE = ("최초 요청(원자료를 그대로 싣지 못함 — 모델이 줄인 글. "
                    "원자료는 framing 기록의 원문 절과 질문 전체 절)")
LABEL_LOST = "최초 요청(원자료를 찾지 못함 — 모델이 줄인 글)"
LOAD_INDENT = "    "                       # 빈칸 넷 — 하나로는 굵은 S 줄 머리가 anchor_confusable 로 남는다
SECTION_NAMES = ("원문 절", "질문 전체 절")   # AUDIT_HEADINGS[0] · [1] 의 사람 말

ANCHOR_MARK = "🗣"
R_LINE_SEPARATOR = "line_separator"
E_NO_FILE = "파일이 없다 — %s"
E_NO_S1 = "결과물에 S1 앵커 줄이 없다 — §6 맨 앞에 「- **S1** 🗣 최초 요청:」 한 줄을 둔 뒤 다시 돌린다"

_FENCE_RE = re.compile(r"~{4,}")
_RUN_RE = re.compile(r"\s*(~+|`+)")
_KINDS = ((LABEL_RAW, "raw"), (LABEL_UNLOADABLE, "unloadable"), (LABEL_LOST, "lost"))


class StateUnreadable(ValueError):
    """상태 파일을 읽지 못했다(인자 오류와 같은 종료 코드 2)."""


class SectionsUnreadable(ValueError):
    """두 절 가운데 하나를 자르지 못했거나 기록의 절 구조가 어긋났다."""


@dataclass(frozen=True)
class Verdict:
    kind: str
    audit: "str | None"
    reason: "str | None"


def _found(audit: str) -> Verdict:
    return Verdict("FOUND", audit, None)


def _lost(reason: str) -> Verdict:
    return Verdict("LOST", None, " ".join(reason.split("\n")))


def _chain(seed: str, base: "Path | None") -> Verdict:
    """seed 문자열에서 넷을 잰다. 파일 검사는 base 기준, 보고하는 글자는 seed 그대로다."""
    def at(s: str) -> Path:
        return Path(s) if base is None else base / s

    if base is not None:   # 상태 파일 길만 — --seed 길은 받은 경로를 그대로 따른다
        why = inside_root(at(seed), base)
        if why:
            return _lost(R_SEED_UNSAFE.format(seed=seed, why=why))
    if not at(seed).is_file():
        return _lost(R_SEED_MISSING.format(seed=seed))
    if not seed.endswith(".md"):
        return _lost(R_SEED_NOT_MD.format(seed=seed))
    audit = seed[:-3] + ".audit.md"
    if base is not None:
        why = inside_root(at(audit), base)
        if why:
            return _lost(R_AUDIT_UNSAFE.format(audit=audit, why=why))
    if not at(audit).is_file():
        return _lost(R_AUDIT_MISSING.format(audit=audit))
    fm = frontmatter_scalars(at(audit))
    kind = "읽지 못함" if fm is None else fm.get("type") or "없음"
    if not legacy_names.kind_matches(kind, AUDIT_TYPE):
        return _lost(R_AUDIT_TYPE.format(audit=audit, kind=kind))
    return _found(audit)


def locate_from_seed(seed: str) -> Verdict:
    return _chain(seed, None)


def _solved_input_is_seed(text: str) -> bool:
    """frontmatter 뒤 첫 `## 풀린 입력` 줄 다음 첫 비지 않은 줄이 물결표 펜스이고, 그 안 첫 줄이 `---` 인 머리가 type: intent-seed(옛 기록은 옛 종류 글자)."""
    lines = text.split("\n")
    i = 0
    if lines and lines[0] == "---":
        i = 1
        while i < len(lines) and lines[i].strip() != "---":
            i += 1
        i += 1
    while i < len(lines) and lines[i] != INPUT_HEADING:
        i += 1
    i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i >= len(lines) or not _FENCE_RE.fullmatch(lines[i].strip()):
        return False
    i += 1
    if i >= len(lines) or lines[i].strip() != "---":
        return False
    for line in lines[i + 1:]:
        if line.strip() == "---":
            break
        if ":" in line and not line.startswith((" ", "\t", "#", "-")):
            key, val = line.split(":", 1)
            if key.strip() == "type":
                return legacy_names.kind_matches(val.strip().strip('"').strip("'"), SEED_TYPE)
    return False


def state_of(path: str) -> Path:
    """`--interview` 가 받은 글자에서 상태 파일 경로를 도출한다(brief 면 `.state.md` 로 바꾼다)."""
    if path.endswith(".audit.md") or not path.endswith(".md"):
        raise ValueError("--interview 는 brief 또는 상태 파일(.md, .audit.md 아님)을 받는다 — %s" % path)
    return Path(path if path.endswith(".state.md") else path[:-3] + ".state.md")


def locate_from_state(state: "Path") -> Verdict:
    """상태 파일을 그대로 받는다(이름에서 도출하지 않는다). 없으면 NO-FRAMING."""
    state = Path(state)
    if not state.is_file():
        return Verdict("NO-FRAMING", None, None)
    fm = frontmatter_scalars(state)
    if fm is None:
        raise StateUnreadable("상태 파일을 읽지 못했다 — %s" % state)
    seed = fm.get("seed", "")
    if seed and seed != SEED_NONE:
        return _chain(seed, worktree_root(str(state.parent))[0])
    try:
        text = state.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError):
        raise StateUnreadable("상태 파일을 읽지 못했다 — %s" % state)
    if _solved_input_is_seed(text):
        return _lost(R_SEED_UNRECORDED)
    return Verdict("NO-FRAMING", None, None)


def locate_from_interview(path: str) -> Verdict:
    return locate_from_state(state_of(path))


def audit_file(state: "Path", v: Verdict) -> "Path":
    """FOUND 의 절대경로 — 상태 파일의 작업 트리 루트에 잇는다(루트 아래 경로는 풀지 않는다 — 링크를 거치면 LOST 였다)."""
    if v.kind != "FOUND" or v.audit is None:
        raise ValueError("FOUND 판결이 아니다 — %s" % v.kind)
    return worktree_root(str(Path(state).parent))[0] / v.audit


def verdict_line(v: Verdict) -> str:
    if v.kind == "FOUND":
        return "raw-source: FOUND %s" % v.audit
    if v.kind == "LOST":
        return "raw-source: LOST %s" % v.reason
    return "raw-source: NO-FRAMING"


# ── 첫 칸에 싣는 꼴 ─────────────────────────────────────────────────────────────

def anchor_line(label: str) -> str:
    return "- **S1** " + ANCHOR_MARK + " " + label + ":"


def label_kind(anchor_rest: str) -> "str | None":
    """`brief_body.anchor_lines` 가 낸 앵커 본문(`🗣 최초 요청(…):`) → "raw" | "unloadable" | "lost" | None.
    앞의 표시 낱말 `🗣`(뒤의 U+FE0F 는 뗀다) 하나와 끝의 `:` 를 떼고 세 라벨과 글자 전체로 견준다."""
    mark, sep, rest = anchor_rest.partition(" ")
    if not sep or mark.replace("\ufe0f", "") != ANCHOR_MARK or not rest.endswith(":"):
        return None
    rest = rest[:-1]
    for label, kind in _KINDS:
        if rest == label:
            return kind
    return None


def _lf(text: str) -> str:
    return text.replace("\r\n", "\n")


_SEPARATOR_TO_SPACE = {ord(c): " " for c in srl.LINE_BREAK_CHARS}


def _refuse_ambiguous_structure(text: str) -> None:
    """`seed_review_log.require_unambiguous` 의 구조 거절 셋을 탄다 — 일곱 제목의 겹침 · 순서(`heading_structure`) ·
    절 시작으로 읽히지 않는 제목 줄(`heading_lines`). 어긋나면 `SectionsUnreadable` — 심긴 제목이 절의 시작과 끝을 가린다.
    다른 줄 나눔 글자는 거절하지 않는다(두 절은 `load_problems` 의 `line_separator` 로, 결정 줄은 번들의 `\\uXXXX` 로
    받는다) — 순서는 그 글자를 빈칸으로 바꾼 글에서 잰다(`\\n` 으로 나눈 줄과 제목 판정은 그대로다).
    `## 6` 의 기록 꼴이 아닌 줄은 거절하지 않고 `decision_lines` 가 건너뛴다."""
    dup = srl.duplicate_headings(text)
    if dup:
        raise SectionsUnreadable("framing 기록에 같은 절 제목이 두 번 이상 있다 — %s 줄 %s"
                                 % (dup[0][0], "·".join(map(str, dup[0][1]))))
    order = srl.heading_structure(text.translate(_SEPARATOR_TO_SPACE))
    if order:
        raise SectionsUnreadable("framing 기록의 절 순서가 템플릿과 다르다 — %s" % "; ".join(order))
    for heading in srl.AUDIT_HEADINGS:
        found = srl.heading_lines(text, heading)
        if found and not any(ok for _, ok in found):
            raise SectionsUnreadable("framing 기록의 「%s」 줄이 절 시작으로 읽히지 않는다(들여 쓴 줄) — 줄 %s"
                                     % (heading, "·".join(str(i + 1) for i, _ in found)))


def section_texts(audit_text: str) -> "tuple[str, str]":
    """두 절 — 제목 줄부터, 끝의 빈 줄(빈칸 · 탭뿐인 줄)을 뗀 글. 제목 줄 바로 뒤의 빈 줄은 그대로 둔다.
    절을 자르지 못하거나(`section_body` 가 None) 일곱 제목의 구조가 어긋나면(`_refuse_ambiguous_structure` — 심긴
    제목이 절을 자를 수 있다) `SectionsUnreadable`."""
    text = _lf(audit_text)
    _refuse_ambiguous_structure(text)
    out = []
    for heading in srl.AUDIT_HEADINGS[:2]:
        body = srl.section_body(text, heading)
        if body is None:
            raise SectionsUnreadable("framing 기록에 「%s」 절이 없다" % heading)
        lines = (heading + "\n" + body).split("\n")
        while len(lines) > 1 and not lines[-1].strip(" \t"):
            lines.pop()
        out.append("\n".join(lines))
    return out[0], out[1]


def _fence(texts) -> str:
    longest = 0
    for t in texts:
        for line in t.split("\n"):
            m = _RUN_RE.match(line)
            if m:
                longest = max(longest, len(m.group(1)))
    return "~" * max(4, longest + 1)


def _block(fence: str, text: str) -> str:
    return "\n".join([fence] + [LOAD_INDENT + line for line in text.split("\n")] + [fence])


def load_blocks(audit_text: str) -> "tuple[str, str]":
    """열 0 물결표 펜스 둘(원문 절이 먼저). 두 블록은 같은 길이의 펜스를 쓴다."""
    s1, s2 = section_texts(audit_text)
    fence = _fence((s1, s2))
    return _block(fence, s1), _block(fence, s2)


def first_cell_item(audit_text: str) -> str:
    b1, b2 = load_blocks(audit_text)
    return anchor_line(LABEL_RAW) + "\n" + b1 + "\n" + b2


def load_problems(audit_text: str) -> "list[tuple[str, int, str]]":
    """(절 이름, 그 절의 제목 줄을 1 로 센 줄 번호, 사유 이름). 빈 목록이면 실을 수 있다.
    `brief_body.anchor_lines(first_cell_item(...))` 의 거부 줄과, 다른 줄 나눔 글자가 든 줄(`line_separator`)이다.
    줄 순서대로 늘어놓고 같은 줄이면 `anchor_lines` 의 사유가 먼저다."""
    texts = section_texts(audit_text)
    n1 = len(texts[0].split("\n"))
    found = []
    for n, why in brief_body.anchor_lines(first_cell_item(audit_text))[1]:
        # 줄 1 은 앵커, 2 는 펜스, 3..2+n1 은 원문 절, 3+n1 · 4+n1 은 펜스, 5+n1.. 는 질문 전체 절
        if n >= 5 + n1:
            idx, k = 1, n - 4 - n1
        else:
            idx, k = 0, n - 2
        found.append((idx, k, 0, why))
    for idx, t in enumerate(texts):
        for k in srl.separator_lines(t):
            found.append((idx, k, 1, R_LINE_SEPARATOR))
    found.sort(key=lambda x: (x[0], x[1], x[2]))
    return [(SECTION_NAMES[idx], k, why) for idx, k, _, why in found]


def unloadable_line(problems: "list[tuple[str, int, str]]") -> str:
    lines = len({(name, k) for name, k, _ in problems})
    name, k, why = problems[0]
    return "raw-source: UNLOADABLE %d줄 — 첫 줄 %s %d째 줄(%s)" % (lines, name, k, why)


# ── 리뷰 번들 블록 ───────────────────────────────────────────────────────────────

def decision_lines(audit_text: str) -> "list[str]":
    """리뷰 결정 줄 가운데 큰따옴표 안 문구가 비지 않은 줄, 글자 그대로. 절이 없으면 빈 목록 · 기록 꼴이 아닌 줄은
    건너뛴다(옛 기록). 일곱 제목의 구조가 어긋나면 `section_texts` 와 같이 `SectionsUnreadable` — 원문 절에 심긴
    제목과 기록 줄이 사용자 결정 문구로 실린다."""
    text = _lf(audit_text)
    _refuse_ambiguous_structure(text)
    body = srl.section_body(text, srl.DECISION_HEADING)
    if body is None:
        return []
    out = []
    for line in body.split("\n"):
        m = srl.ENGINE_LINE_RE.match(line) or srl.HOST_LINE_RE.match(line)
        if m and m.group("quote").strip():
            out.append(line)
    return out


def review_block(audit_text: str, with_sections: bool) -> str:
    """`with_sections` 면 두 블록을 먼저, 빈 줄 하나 뒤에 결정 줄을 한 줄씩. 실을 것이 없으면 ""."""
    lines = decision_lines(audit_text)
    parts = []
    if with_sections:
        b1, b2 = load_blocks(audit_text)
        parts.append(b1 + "\n" + b2)
    if lines:
        parts.append("\n".join(lines))
    return "\n\n".join(parts)


# ── 결과물에 써 넣기 ─────────────────────────────────────────────────────────────

class PlaceRefused(ValueError):
    """결과물에 써 넣지 못한다(종료 코드 2)."""


def placed_text(brief_text: str, item: str) -> str:
    """결과물 글의 S1 항목(S1 앵커 줄부터 다음 문법 안 앵커 줄 앞, 없으면 절의 끝 앞까지에서 끝의 빈 줄을 뺀 줄들)을
    `item` 으로 바꾼 글. 그 범위 밖의 글자는 그대로다."""
    sp = section6.span(brief_text)
    if sp is None:
        raise PlaceRefused(E_NO_S1)
    body = brief_text[sp[1]:sp[2]]
    anchors = brief_body.anchor_lines(body)[0]
    s1 = next((n for n, sid, _ in anchors if sid == "S1"), None)
    if s1 is None:
        raise PlaceRefused(E_NO_S1)
    lines = brief_body.split_lines(body)
    nxt = next((n for n, _, _ in anchors if n > s1), len(lines) + 1)
    a, b = s1 - 1, nxt - 1
    while b > a + 1 and not lines[b - 1].strip():
        b -= 1
    new_body = "\n".join(lines[:a] + item.split("\n") + lines[b:])
    return brief_text[:sp[1]] + new_body + brief_text[sp[2]:]


def _read_keep_newlines(path: Path) -> str:
    with open(path, encoding="utf-8", newline="") as fh:
        return fh.read()


def _write_atomic(path: Path, text: str) -> None:
    fd, tmp = tempfile.mkstemp(dir=str(path.parent), prefix="." + path.name + ".", suffix=".tmp")
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        os.chmod(tmp, stat.S_IMODE(os.stat(path).st_mode))
        os.replace(tmp, str(path))
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise


# ── CLI ───────────────────────────────────────────────────────────────────────

def _err(msg: str) -> int:
    print("[raw_source] %s" % msg, file=sys.stderr)
    return 2


def _rc(v: Verdict) -> int:
    return 3 if v.kind == "LOST" else 0


def _cmd_locate(a) -> int:
    if a.seed is not None:
        v = locate_from_seed(a.seed)
        if a.absolute and v.kind == "FOUND":
            v = _found(os.path.abspath(v.audit))
    else:
        state = state_of(a.interview)
        v = locate_from_state(state)
        if a.absolute and v.kind == "FOUND":
            v = _found(str(audit_file(state, v)))
    print(verdict_line(v))
    return _rc(v)


def _cmd_text(a) -> int:
    """first-cell · place · review-block."""
    if not Path(a.interview).is_file():
        return _err(E_NO_FILE % a.interview)
    state = state_of(a.interview)
    out = sys.stderr if a.cmd in ("first-cell", "review-block") else sys.stdout
    brief = brief_s = None
    if a.cmd == "place":
        brief_s = a.interview[:-len(".state.md")] + ".md" if a.interview.endswith(".state.md") else a.interview
        brief = Path(brief_s)
        if brief.is_symlink():
            return _err("결과물이 링크다 — %s" % brief_s)
    v = locate_from_state(state)
    if v.kind != "FOUND":
        print(verdict_line(v), file=out)
        return _rc(v)
    try:
        text = srl.read_audit_text(audit_file(state, v))
    except (OSError, UnicodeDecodeError):
        return _err("framing 기록 파일을 읽지 못했다 — %s" % v.audit)
    if a.cmd == "review-block":
        block = review_block(text, a.with_sections)
        if block:
            print(block)
        print(verdict_line(v), file=out)
        return 0
    problems = load_problems(text)
    if problems:
        print(unloadable_line(problems), file=out)
        return 4
    item = first_cell_item(text)
    if a.cmd == "first-cell":
        print(item)
        print(verdict_line(v), file=out)
        return 0
    if not brief.is_file():
        return _err(E_NO_FILE % brief_s)
    try:
        old = _read_keep_newlines(brief)
    except (OSError, UnicodeDecodeError):
        return _err("결과물을 읽지 못했다 — %s" % brief_s)
    new = placed_text(old, item)
    if new != old:
        try:
            _write_atomic(brief, new)
        except OSError:
            return _err("결과물을 쓰지 못했다 — %s" % brief_s)
    print("raw-source: PLACED %s" % brief_s, file=out)
    return 0


def main(argv: "list[str] | None" = None) -> int:
    ap = argparse.ArgumentParser(prog="raw_source.py")
    sub = ap.add_subparsers(dest="cmd", required=True)
    loc = sub.add_parser("locate")
    grp = loc.add_mutually_exclusive_group(required=True)
    grp.add_argument("--seed")
    grp.add_argument("--interview")
    loc.add_argument("--absolute", action="store_true")
    for name in ("first-cell", "place", "review-block"):
        p = sub.add_parser(name)
        p.add_argument("--interview", required=True)
        if name == "review-block":
            p.add_argument("--with-sections", action="store_true")
    try:
        a = ap.parse_args(argv)
    except SystemExit as exc:
        return 2 if exc.code not in (0, None) else 0
    try:
        return _cmd_locate(a) if a.cmd == "locate" else _cmd_text(a)
    except ValueError as exc:   # StateUnreadable · SectionsUnreadable · PlaceRefused · 인자 꼴
        return _err(str(exc))


if __name__ == "__main__":
    sys.exit(main())
