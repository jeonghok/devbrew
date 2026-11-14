"""쓴소리 리뷰어의 입력 조립 — 근거 · 원문 · 로드맵 · 의심.

원문 · 로드맵 링크는 리포 안 추적 파일(보통 파일)만 따라간다. 거부된 링크는 내용을 입력에
싣지 않고 이유만 공시한다. 이 모듈은 `adjudication` 을 쓰지 않는다 — 회계는 intent_critic.py 가 한다.
"""
from __future__ import annotations

import subprocess
from typing import List, Optional

import yaml

PASS_VERDICTS = ("STILL_GREEN", "FIXED", "NEW_TEST_GREEN")
NOTICE_DIFF_UNREADABLE = "차등 결과를 읽지 못함 — 근거로 세지 않았다"
REASON_UNTRACKED = "추적 안 된 파일 또는 없음"
# 리뷰 트리에서 읽은 값은 줄 단위 세션 파일(intent-plan.txt 등)로 간다 — 한 줄 · 제어 문자 없음만 받는다.
REASON_CONTROL = "여러 줄 또는 제어 문자"

_INTENT_DOUBT_WORDS = ("위험", "기각", "열린 질문", "risk", "rejected", "open question")
_ROADMAP_DOUBT_WORDS = ("위험", "열린 질문", "risk", "open question")
_RECHECK = "다시 검증할 것"
_LEAD = ">-* \t"


def total_bytes(*texts: str) -> int:
    total = 0
    for t in texts:
        total += len(t.encode("utf-8"))
    return total


# ---------------------------------------------------------------- 근거

def _differential_state(differential: Optional[str]) -> tuple:
    """(읽을 수 있나, 통과로 끝나지 않은 판정이 있나)."""
    if differential is None or not differential.strip():
        return (True, False)
    try:
        data = yaml.safe_load(differential)
    except yaml.YAMLError:
        return (False, False)
    if data is None:
        return (True, False)
    if not isinstance(data, dict):
        return (False, False)
    adapters = data.get("per_adapter")
    if not isinstance(adapters, list):
        return (True, False)
    for adapter in adapters:
        if not isinstance(adapter, dict):
            continue
        attributions = adapter.get("attributions")
        if not isinstance(attributions, list):
            continue
        for attribution in attributions:
            if not isinstance(attribution, dict):
                continue
            if str(attribution.get("verdict")) not in PASS_VERDICTS:
                return (True, True)
    return (True, False)


def _nonblank_lines(text: Optional[str]) -> List[str]:
    out = []
    for line in (text or "").splitlines():
        if line.strip():
            out.append(line.rstrip("\r\n"))
    return out


def has_evidence(e2e_record: Optional[str], differential: Optional[str]) -> tuple:
    readable, non_pass = _differential_state(differential)
    notices = []
    if not readable:
        notices.append(NOTICE_DIFF_UNREADABLE)
    walked = bool(_nonblank_lines(e2e_record))
    return (walked or non_pass, notices)


def build_evidence(e2e_record: Optional[str], differential: Optional[str]) -> tuple:
    ok, _ = has_evidence(e2e_record, differential)
    if not ok:
        return ("", 0)
    readable, _ = _differential_state(differential)
    rows = []
    for line in _nonblank_lines(e2e_record):
        rows.append("[e2e] " + line)
    if readable:
        for line in _nonblank_lines(differential):
            rows.append("[차등] " + line)
    out = []
    for n, row in enumerate(rows, 1):
        out.append("%4d\t%s" % (n, row))
    return ("\n".join(out), len(out))


def evidence_line_numbers(text: str) -> set:
    nums = set()
    for line in text.split("\n"):
        head = line.split("\t", 1)[0].strip()
        if head.isdigit():
            nums.add(int(head))
    return nums


# ---------------------------------------------------------------- 추적 파일 읽기

def _run_git(repo: str, *args: str):
    try:
        return subprocess.run(["git", "-C", repo] + list(args), capture_output=True)
    except (OSError, ValueError):
        return None


def single_line(value: str) -> bool:
    """줄바꿈 · 탭 · 제어 문자 · 구분 문자(보통 공백 말고)가 없는 한 줄인가."""
    return value.isprintable()


def read_tracked(repo: str, commit: str, rel: str) -> tuple:
    """(내용 | None, 거부 사유 | None). 그 커밋에서 추적되는 보통 파일만 읽는다."""
    if not single_line(rel):
        return (None, REASON_CONTROL)
    if rel.startswith("/"):
        return (None, "절대 경로")
    parts = rel.split("/")
    if ".." in parts:
        return (None, "상위 경로(..)")
    if ".git" in parts:
        return (None, ".git 아래")
    if not rel:
        return (None, REASON_UNTRACKED)
    tree = _run_git(repo, "ls-tree", "-z", commit, "--", rel)
    if tree is None or tree.returncode != 0:
        return (None, REASON_UNTRACKED)
    mode = None
    for entry in tree.stdout.decode("utf-8", "replace").split("\0"):
        meta, sep, path = entry.partition("\t")
        if sep and path == rel:
            mode = meta.split(" ", 1)[0]
            break
    if mode is None:
        return (None, REASON_UNTRACKED)
    if mode == "120000":
        return (None, "심볼릭 링크")
    if mode not in ("100644", "100755"):
        return (None, "보통 파일이 아님")
    shown = _run_git(repo, "show", "%s:%s" % (commit, rel))
    if shown is None or shown.returncode != 0:
        return (None, REASON_UNTRACKED)
    return (shown.stdout.decode("utf-8", "replace"), None)


def frontmatter_value(text: str, key: str) -> Optional[str]:
    if not text.startswith("---\n"):
        return None
    end = text.find("\n---", 4)
    if end < 0:
        return None
    try:
        data = yaml.safe_load(text[4:end])
    except yaml.YAMLError:
        return None
    if not isinstance(data, dict) or data.get(key) is None:
        return None
    return str(data[key]).strip()


# ---------------------------------------------------------------- 절 가르기

def _depth(line: str) -> int:
    if line.startswith("### "):
        return 3
    if line.startswith("## "):
        return 2
    return 0


def split_sections(text: str) -> list:
    """[(머리 줄 | None, 본문)]. 절은 같은 깊이 이상의 다음 머리 앞에서 끝난다."""
    out = []
    head = None
    depth = 0
    buf: List[str] = []
    for line in text.splitlines(keepends=True):
        d = _depth(line)
        if d and (head is None or d <= depth):
            if head is not None or buf:
                out.append((head, "".join(buf)))
            head = line.rstrip("\r\n")
            depth = d
            buf = []
        else:
            buf.append(line)
    if head is not None or buf:
        out.append((head, "".join(buf)))
    return out


def _with_newline(text: str) -> str:
    return text if not text or text.endswith("\n") else text + "\n"


def _split_by_heading(text: str, words: tuple) -> tuple:
    kept: List[str] = []
    moved: List[str] = []
    for head, body in split_sections(text):
        if head is None:
            kept.append(body)
            continue
        whole = head + "\n" + body
        if any(w in head.lower() for w in words):
            moved.append(_with_newline(whole))
            continue
        if head.startswith("## "):
            inner_kept, inner_moved = _split_by_heading(body, words)
            if inner_moved:
                kept.append(head + "\n" + inner_kept)
                moved.append(inner_moved)
                continue
        kept.append(whole)
    return ("".join(kept), "".join(moved))


def _indent(line: str) -> int:
    return len(line) - len(line.lstrip(" \t"))


def _is_quote(line: str) -> bool:
    return line.lstrip().startswith(">")


def _is_bullet(line: str) -> bool:
    core = line.lstrip(" \t")
    if core.startswith(("- ", "* ")):
        return True
    digits = core.lstrip("0123456789")
    return len(digits) < len(core) and digits.startswith(". ")


def _is_heading_line(line: str) -> bool:
    core = line.lstrip("> \t")
    return core.startswith("#") and core.lstrip("#")[:1] == " "


def _recheck_ends(line: str, start_indent: int, start_quote: bool) -> bool:
    """「다시 검증할 것」 문단이 이 줄 앞에서 끝나나 — 빈 줄 · `>` 만 있는 줄 · 머리 줄 ·
    인용 밖으로 나가는 줄(또는 인용으로 들어가는 줄) · 시작 줄과 같거나 얕은 들여쓰기의 새 목록 항목."""
    if line.strip().strip(">").strip() == "" or _is_heading_line(line):
        return True
    if start_quote:
        return not _is_quote(line)
    if _is_quote(line):
        return True
    return _is_bullet(line) and _indent(line) <= start_indent


def move_recheck_paragraphs(text: str) -> tuple:
    """「다시 검증할 것」 줄부터 그 문단 끝까지를 옮긴다 → (kept, moved). 끝 줄은 옮기지 않는다."""
    kept: List[str] = []
    paras: List[str] = []
    cur: Optional[List[str]] = None
    start_indent = 0
    start_quote = False
    for line in text.splitlines(keepends=True):
        if cur is not None:
            if _recheck_ends(line, start_indent, start_quote):
                paras.append("".join(cur))
                cur = None
            else:
                cur.append(line)
                continue
        if line.lstrip(_LEAD).startswith(_RECHECK):
            cur = [line]
            start_indent = _indent(line)
            start_quote = _is_quote(line)
        else:
            kept.append(line)
    if cur is not None:
        paras.append("".join(cur))
    moved = "\n".join(_with_newline(p) for p in paras)
    return ("".join(kept), moved)


def _join_moved(*parts: str) -> str:
    return "\n".join(_with_newline(p) for p in parts if p.strip())


def strip_intent_doubts(intent_text: str) -> tuple:
    """첫 호출용 의도에서 위험 · 기각 · 열린 질문 절과 「다시 검증할 것」 문단을 뺀다 → (kept, moved)."""
    kept, moved = _split_by_heading(intent_text, _INTENT_DOUBT_WORDS)
    kept, recheck = move_recheck_paragraphs(kept)
    return (kept, _join_moved(moved, recheck))


def _is_risk_line(line: str) -> bool:
    core = line.lstrip(_LEAD)
    if not core.startswith("K"):
        return False
    i = 1
    while i < len(core) and core[i] in "0123456789":
        i += 1
    return i > 1 and core[i:].startswith(" — 위험")


def strip_roadmap_doubts(text: str) -> tuple:
    """로드맵에서 위험 · 열린 질문 절, `K<n> — 위험` 줄, 「다시 검증할 것」 문단을 뺀다 → (kept, moved)."""
    kept, moved = _split_by_heading(text, _ROADMAP_DOUBT_WORDS)
    stay: List[str] = []
    risk_lines: List[str] = []
    for line in kept.splitlines(keepends=True):
        if _is_risk_line(line):
            risk_lines.append(line)
        else:
            stay.append(line)
    rest, recheck = move_recheck_paragraphs("".join(stay))
    return (rest, _join_moved(moved, "".join(risk_lines), recheck))


# ---------------------------------------------------------------- 원문 · 로드맵 조립

_ORIGIN_HEADS = ("## 6.", "## 2.")
_DOUBT_HEADS = ("## 5.", "## 3.")


def _note(st: dict, line: str) -> None:
    if line not in st["notices"]:
        st["notices"].append(line)


def _open_doc(repo: str, commit: str, rel: str, st: dict, label: str) -> Optional[str]:
    for seen_rel, _, seen_text in st["opened"]:
        if seen_rel == rel:
            return None if rel in st["done"] else seen_text
    text, why = read_tracked(repo, commit, rel)
    if text is None:
        _note(st, "%s — %s" % (label, why))
        st["rejected"] = True
        return None
    st["opened"].append((rel, commit, text))
    return text


def _add_origin_doc(rel: str, text: str, st: dict) -> None:
    if rel in st["done"]:
        return
    st["done"].append(rel)
    source = rel
    if frontmatter_value(text, "type") == "epic-bundle":
        brief = frontmatter_value(text, "source_brief")
        if brief and not single_line(brief):
            _note(st, "묶음 source_brief 거부 — " + REASON_CONTROL)
        elif brief:
            source = brief
            st["aliases"][rel] = brief
    if source not in st["sources"]:
        st["sources"].append(source)
    marker = "<!-- origin-source: %s · file: %s -->" % (source, rel)
    origin_parts: List[str] = []
    doubt_parts: List[str] = []
    for head, body in split_sections(text):
        if head is None:
            continue
        if head.startswith(_ORIGIN_HEADS):
            origin_parts.append(head + "\n" + body)
        elif head.startswith(_DOUBT_HEADS):
            doubt_parts.append(head + "\n" + body)
    if not origin_parts and not doubt_parts:
        st["origin"].append(marker + "\n" + text)
        st["mixed"] = True
        _note(st, "직접 쓴 말 · 고른 라벨을 가르지 못함")
        _note(st, "첫 호출에 의심이 섞였다")
        return
    origin_text, recheck = move_recheck_paragraphs("".join(origin_parts))
    doubt_text = _join_moved("".join(doubt_parts), recheck)
    st["origin"].append(marker + "\n" + origin_text)
    if doubt_text.strip():
        st["doubts"].append(marker + "\n" + doubt_text)


def _follow_roadmaps(repo: str, st: dict) -> str:
    seen: List[str] = []
    parts: List[str] = []
    for rel, commit, text in list(st["opened"]):
        path = frontmatter_value(text, "roadmap")
        if path is None or path in seen:
            continue
        seen.append(path)
        body, why = read_tracked(repo, commit, path)
        if body is None:
            _note(st, "로드맵 링크 거부 — %s" % why)
            st["rejected_roadmap"] = True
            continue
        kept, moved = strip_roadmap_doubts(body)
        parts.append("<!-- roadmap: %s · from: %s -->\n%s" % (path, rel, kept))
        if moved.strip():
            st["doubts"].append("<!-- roadmap-doubts: %s -->\n%s" % (path, moved))
    if parts:
        return "\n".join(parts)
    reason = "로드맵 링크 거부" if st.get("rejected_roadmap") else "연 문서에 roadmap: 없음"
    line = "로드맵 없음 — " + reason
    _note(st, line)
    return line


def build_origin(repo: str, head_commit: str, review_commit: str,
                 caller_origin: Optional[str], specs: list) -> dict:
    st: dict = {"origin": [], "doubts": [], "sources": [], "aliases": {}, "notices": [],
                "mixed": False, "rejected": False, "opened": [], "done": []}
    if caller_origin:
        text = _open_doc(repo, head_commit, caller_origin, st, "원문 링크 거부")
        if text is not None:
            _add_origin_doc(caller_origin, text, st)
    else:
        for spec in specs:
            spec_text = _open_doc(repo, review_commit, spec, st, "원문 링크 거부")
            if spec_text is None:
                continue
            link = frontmatter_value(spec_text, "source_interview")
            if link is None:
                continue
            text = _open_doc(repo, review_commit, link, st, "원문 링크 거부")
            if text is not None:
                _add_origin_doc(link, text, st)
    if st["origin"]:
        origin = "\n".join(st["origin"])
    else:
        if st["rejected"]:
            reason = "원문 링크 거부"
        elif not specs and not caller_origin:
            reason = "의도 출처에 설계문서 없음"
        else:
            reason = "부른 쪽 원문도 설계문서 링크도 없음"
        origin = "원문 없음 — " + reason
        _note(st, origin)
    roadmap = _follow_roadmaps(repo, st)
    return {"origin": origin, "doubts": "\n".join(st["doubts"]), "roadmap": roadmap,
            "sources": st["sources"], "aliases": st["aliases"], "notices": st["notices"],
            "mixed": st["mixed"]}
