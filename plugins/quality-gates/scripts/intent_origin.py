"""intent-critic 리뷰어의 입력 조립 — 근거 · 원문 · 로드맵 · 의심 · 의도 문서 표시 · 리뷰의 넓이 · scope 칸.

원문 · 로드맵 링크는 리포 안 추적 파일(보통 파일)만 따라간다. 거부된 링크는 내용을 입력에
싣지 않고 이유만 공시한다. 이 모듈은 `adjudication` 을 쓰지 않는다 — 회계는 intent_critic.py 가 한다.
"""
from __future__ import annotations

import datetime
import os
import stat
import subprocess
import sys
from typing import List, Optional

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import yaml  # noqa: E402

import doc_paths  # noqa: E402

PASS_VERDICTS = ("STILL_GREEN", "FIXED", "NEW_TEST_GREEN")
NOTICE_DIFF_UNREADABLE = "차등 결과를 읽지 못함 — 근거로 세지 않았다"
NOTICE_DIFF_SHAPE = "차등 결과의 꼴이 다르다 — 읽지 못한 부분은 근거로 세지 않았다"
MARK_E2E = "[e2e] "
MARK_DIFF = "[차등] "
MARK_TEAMS = "[다른 팀] "
REASON_UNTRACKED = "추적 안 된 파일 또는 없음"
# 리뷰 트리에서 읽은 값은 줄 단위 세션 파일(intent-plan.txt 등)로 간다 — 한 줄 · 제어 문자 없음만 받는다.
REASON_CONTROL = "여러 줄 또는 제어 문자"
REASON_NOT_REGULAR = "보통 파일이 아님"
REASON_LINK = "심볼릭 링크"
REGULAR_MODES = ("100644", "100755")
LINK_MODE = "120000"
# 의도 문서를 가리는 머리 표시 — `<키>` 는 그 줄이 있음, `<키>=<값>` 은 그 줄의 값이 같음.
DEFAULT_MARKERS = ("source_intent", "source_interview", "roadmap", "source_brief", "type=roadmap", "type=epic-bundle")

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
    """(읽을 수 있나, 통과로 끝나지 않은 판정이 있나, 꼴이 맞나).

    꼴이 다른 것(`per_adapter` 가 없거나 목록이 아님 · adapter 가 dict 가 아님 · `attributions` 가
    없거나 목록이 아님 · attribution 이 dict 가 아님)은 건너뛰고 세지 않는다 — 부르는 판정은 읽은
    부분만으로 한다.
    """
    if differential is None or not differential.strip():
        return (True, False, True)
    try:
        data = yaml.safe_load(differential)
    except Exception:  # noqa: BLE001 — YAML 은 YAMLError 말고도 낸다(없는 날짜 · 틀린 수의 ValueError)
        return (False, False, True)
    if data is None:
        return (True, False, False)
    if not isinstance(data, dict):
        return (False, False, True)
    adapters = data.get("per_adapter")
    if not isinstance(adapters, list):
        return (True, False, False)
    non_pass = False
    shape_ok = True
    for adapter in adapters:
        attributions = adapter.get("attributions") if isinstance(adapter, dict) else None
        if not isinstance(attributions, list):
            shape_ok = False
            continue
        for attribution in attributions:
            if not isinstance(attribution, dict):
                shape_ok = False
            elif str(attribution.get("verdict")) not in PASS_VERDICTS:
                non_pass = True
    return (True, non_pass, shape_ok)


def _nonblank_lines(text: Optional[str]) -> List[str]:
    out = []
    for line in (text or "").splitlines():
        if line.strip():
            out.append(line.rstrip("\r\n"))
    return out


def has_evidence(e2e_record: Optional[str], differential: Optional[str]) -> tuple:
    readable, non_pass, shape_ok = _differential_state(differential)
    notices = []
    if not readable:
        notices.append(NOTICE_DIFF_UNREADABLE)
    if not shape_ok:
        notices.append(NOTICE_DIFF_SHAPE)
    walked = bool(_nonblank_lines(e2e_record))
    return (walked or non_pass, notices)


def build_evidence(e2e_record: Optional[str], differential: Optional[str],
                   other_teams: str = "") -> tuple:
    """번호 붙은 근거 글 → (글, 줄 수). 돌려 본 줄(`[e2e] ` · `[차등] `) 뒤에 다른 팀 기록의 빈 줄 아닌
    줄을 `[다른 팀] ` 표지로 잇는다. 돌려 본 근거가 없어도 다른 팀 줄은 싣는다."""
    rows = []
    ok, _ = has_evidence(e2e_record, differential)
    if ok:
        for line in _nonblank_lines(e2e_record):
            rows.append(MARK_E2E + line)
        if _differential_state(differential)[0]:
            for line in _nonblank_lines(differential):
                rows.append(MARK_DIFF + line)
    for line in _nonblank_lines(other_teams):
        rows.append(MARK_TEAMS + line)
    out = []
    for n, row in enumerate(rows, 1):
        out.append("%4d\t%s" % (n, row))
    return ("\n".join(out), len(out))


KIND_RUN = "돌려서 봄"
KIND_TEAMS = "다른 팀에서 봄"
KIND_READ = "읽어서 봄"
KINDS_ORDER = (KIND_RUN, KIND_TEAMS, KIND_READ)
MARK_READ = "[읽음] "


def evidence_kind(line: str) -> str:
    """근거 줄(`<번호>\\t<표지><글>`)의 근거 종류 — 첫 탭 바로 뒤가 다른 팀 표지일 때만 다른 팀이다.

    걷기 관찰 글이 `[다른 팀] ` 을 담아도 그 줄은 `[e2e] ` 로 시작하므로 돌려 본 근거로 남는다.
    """
    _head, sep, body = line.partition("\t")
    return KIND_TEAMS if sep and body.startswith(MARK_TEAMS) else KIND_RUN


def teams_bytes(evidence: str) -> int:
    """근거 글에서 다른 팀 줄(`evidence_kind` 가 `KIND_TEAMS`)을 `\\n` 으로 이은 글의 UTF-8 바이트."""
    rows = []
    for line in evidence.split("\n"):
        if evidence_kind(line) == KIND_TEAMS:
            rows.append(line)
    return len("\n".join(rows).encode("utf-8"))


def ordered_kinds(found: set) -> List[str]:
    """근거 종류들 → `돌려서 봄` · `다른 팀에서 봄` · `읽어서 봄` 순서의 목록."""
    out = []
    for kind in KINDS_ORDER:
        if kind in found:
            out.append(kind)
    return out


def quote_line(quote: dict) -> str:
    """확인된 읽은 인용의 관찰 줄 — `[읽음] <경로>:<줄> <글>`. 경로와 글은 `printable` 로 거른다
    (글 가운데의 줄 가름 글자가 관찰 줄을 둘로 가르지 못하게)."""
    return "%s%s:%d %s" % (MARK_READ, printable(quote["path"]), quote["line"],
                           printable(quote["text"]))


def _checked_quote(tree_root: str, quote, files: dict) -> Optional[dict]:
    """인용 하나를 리뷰 트리의 그 줄과 견준다 — 맞으면 (경로 · 줄 · 걷은 글), 아니면 None.

    파일은 `read_tree`(추적되는 보통 파일 · 경로 마디마다 링크 거부)로만 읽는다. 줄과 글은 앞뒤 공백만
    걷어 견주고, 걷은 글이 비면 인용이 아니다(빈 줄과 맞아 통과하지 않게).
    """
    if not isinstance(quote, dict):
        return None
    path, line, text = quote.get("path"), quote.get("line"), quote.get("text")
    if not isinstance(path, str) or type(line) is not int or line < 1 or not isinstance(text, str):
        return None
    wanted = text.strip()
    if not wanted or not tree_root:
        return None
    if path not in files:
        files[path] = read_tree(tree_root, path)[0]
    content = files[path]
    if content is None:
        return None
    rows = content.split("\n")
    if line > len(rows) or rows[line - 1].strip() != wanted:
        return None
    return {"path": path, "line": line, "text": wanted}


def verify_quotes(tree_root: str, quotes) -> tuple:
    """리뷰어가 적은 읽은 인용들 → (확인된 인용들, 버린 수). 목록이 아니면 ([], 0)."""
    if not isinstance(quotes, list):
        return ([], 0)
    kept: List[dict] = []
    files: dict = {}
    for quote in quotes:
        checked = _checked_quote(tree_root, quote, files)
        if checked is not None:
            kept.append(checked)
    return (kept, len(quotes) - len(kept))


def evidence_line_numbers(text: str) -> set:
    nums = set()
    for line in text.split("\n"):
        head = line.split("\t", 1)[0].strip()
        if head.isdigit():
            nums.add(int(head))
    return nums


# ---------------------------------------------------------------- 추적 파일 읽기

GIT_TIMEOUT = 30
REASON_TIMEOUT = "git 읽기가 시간 한도 %d초를 넘김" % GIT_TIMEOUT


class _TimedOut:
    """시간 한도를 넘긴 git 호출이 `None` 대신 돌려주는 값 — 실패한 호출처럼 읽힌다."""
    returncode = -1
    stdout = b""
    stderr = b""


TIMED_OUT = _TimedOut()


def _run_git(repo: str, *args: str):
    try:
        return subprocess.run(["git", "-C", repo] + list(args), capture_output=True,
                              timeout=GIT_TIMEOUT)
    except subprocess.TimeoutExpired:
        return TIMED_OUT
    except (OSError, ValueError):
        return None


def single_line(value: str) -> bool:
    """줄바꿈 · 탭 · 제어 문자 · 구분 문자(보통 공백 말고)가 없는 한 줄인가."""
    return value.isprintable()


def _path_rejection(rel: str) -> Optional[str]:
    """리뷰 트리 · 커밋에서 읽을 경로의 꼴 검사 — 거부 사유, 받으면 None."""
    if not single_line(rel):
        return REASON_CONTROL
    if rel.startswith("/"):
        return "절대 경로"
    parts = rel.split("/")
    if ".." in parts:
        return "상위 경로(..)"
    for part in parts:
        # 대소문자를 가리지 않는 파일 시스템에서는 `.GIT` 이 `.git` 이다 — 글자 크기를 접어 견준다.
        if part.casefold() == ".git":
            return ".git 아래"
    if not rel:
        return REASON_UNTRACKED
    return None


def _listed_mode(listing, rel: str) -> tuple:
    """`ls-tree -z` · `ls-files -s -z` 출력에서 경로가 정확히 rel 인 줄의 모드 → (모드 | None, 폴더인가)."""
    if listing is None or listing.returncode != 0:
        return (None, False)
    folder = False
    for entry in listing.stdout.decode("utf-8", "replace").split("\0"):
        meta, sep, path = entry.partition("\t")
        if not sep:
            continue
        if path == rel:
            return (meta.split(" ", 1)[0], False)
        if path.startswith(rel + "/"):
            folder = True
    return (None, folder)


def _mode_rejection(mode: Optional[str], folder: bool) -> Optional[str]:
    if mode is None:
        return REASON_NOT_REGULAR if folder else REASON_UNTRACKED
    if mode == LINK_MODE:
        return REASON_LINK
    if mode not in REGULAR_MODES:
        return REASON_NOT_REGULAR
    return None


def read_tracked(repo: str, commit: str, rel: str) -> tuple:
    """(내용 | None, 거부 사유 | None). 그 커밋에서 추적되는 보통 파일만 읽는다."""
    why = _path_rejection(rel)
    if why is not None:
        return (None, why)
    tree = _run_git(repo, "ls-tree", "-z", commit, "--", ":(literal)" + rel)
    if tree is TIMED_OUT:
        return (None, REASON_TIMEOUT)
    why = _mode_rejection(*_listed_mode(tree, rel))
    if why is not None:
        return (None, why)
    # `<rev>:<경로>` 는 pathspec 이 아니다 — 뒤를 `--` 로 닫아 같은 이름의 작업 폴더 파일과 갈리지 않게 한다.
    shown = _run_git(repo, "show", "%s:%s" % (commit, rel), "--")
    if shown is TIMED_OUT:
        return (None, REASON_TIMEOUT)
    if shown is None or shown.returncode != 0:
        return (None, REASON_UNTRACKED)
    return (shown.stdout.decode("utf-8", "replace"), None)


def read_tree(tree_root: str, rel: str) -> tuple:
    """(내용 | None, 거부 사유 | None). 리뷰 트리(작업 사본)에서 색인에 있는 보통 파일만 읽는다.

    추적 여부는 색인의 모드로 가리고, 작업 사본의 경로 마디가 하나라도 링크면 거부한다 —
    색인에는 보통 파일인데 작업 사본에서 링크로 바뀐 마디가 트리 밖을 읽게 하지 않는다.
    """
    why = _path_rejection(rel)
    if why is not None:
        return (None, why)
    listing = _run_git(tree_root, "ls-files", "-s", "-z", "--", ":(literal)" + rel)
    if listing is TIMED_OUT:
        return (None, REASON_TIMEOUT)
    why = _mode_rejection(*_listed_mode(listing, rel))
    if why is not None:
        return (None, why)
    path = tree_root
    info = None
    for part in rel.split("/"):
        path = os.path.join(path, part)
        try:
            info = os.lstat(path)
        except OSError:
            return (None, REASON_UNTRACKED)
        if stat.S_ISLNK(info.st_mode):
            return (None, REASON_LINK)
    if info is None or not stat.S_ISREG(info.st_mode):
        return (None, REASON_NOT_REGULAR)
    try:
        fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0))
        with os.fdopen(fd, "rb") as fh:
            data = fh.read()
    except OSError:
        return (None, REASON_UNTRACKED)
    return (data.decode("utf-8", "replace"), None)


def read_changed_doc(tree_root: str, rel: str, timed_out: Optional[list] = None) -> Optional[str]:
    """바뀐 파일 목록의 문서를 리뷰 트리에서 읽는다 — 읽지 못하면 None.

    리뷰 트리에 경로가 아예 없는(지운) 문서는 빈 글이다 — 의도 문서도 「확인 못 한 문서」 도 아니다.
    시간 한도로 못 읽으면 `timed_out` 에 `rel` 을 더한다.
    """
    text, why = read_tree(tree_root, rel)
    if why == REASON_TIMEOUT and timed_out is not None:
        timed_out.append(rel)
    if (text is None and why == REASON_UNTRACKED and _path_rejection(rel) is None
            and not os.path.lexists(os.path.join(tree_root, rel))):
        return ""
    return text


def printable(value: str) -> str:
    """한 줄 값 — 인쇄할 수 없는 글자(줄바꿈 · 제어 문자 · 짝 없는 surrogate)는 `?`."""
    out = []
    for ch in value:
        out.append(ch if ch.isprintable() else "?")
    return "".join(out)


def _rev_arg_ok(rev: str) -> bool:
    """git 인자로 넘길 rev — 비어 있지 않고 `-` 로 시작하지 않는 한 줄."""
    return bool(rev) and not rev.startswith("-") and single_line(rev)


def commit_titles(repo: str, base: str, end: str) -> Optional[List[str]]:
    """`base..end` 커밋 제목(한 줄에 하나, 인쇄할 수 없는 글자는 `?`). 읽지 못하면 None."""
    if not _rev_arg_ok(base) or not _rev_arg_ok(end):
        return None
    proc = _run_git(repo, "log", "--no-show-signature", "--format=%s", "%s..%s" % (base, end), "--")
    if proc is None or proc.returncode != 0:
        return None
    out = []
    for line in proc.stdout.decode("utf-8", "replace").split("\n"):
        if line:
            out.append(printable(line))
    return out


BREADTH_LABELS = {"narrow": "좁게 본다 — 코드가 바뀐 PR", "range": "넓게 본다 — 범위 모드",
                  "intent-docs": "넓게 본다 — 의도 문서가 바뀐 변경"}


def render_scope(breadth: str, names: Optional[set], repo: str, base: str, end: str) -> str:
    """리뷰어의 `<scope>` 칸(`intent-scope.md`) — 넓이 · 읽은 인용을 받는지 · 바뀐 파일 · 커밋 제목.

    경로 · 커밋 제목은 다른 사람의 글이다 — 줄마다 `- ` 를 붙여, 어떤 값도 머리 두 줄이나 절 머리와
    같은 줄이 되지 못하게 한다.
    """
    lines = ["넓이: " + BREADTH_LABELS[breadth],
             "읽은 인용: " + ("받지 않는다" if breadth == "narrow" else "받는다"), "", "## 바뀐 파일"]
    items = ["모름"] if names is None else []
    for rel in sorted(names or ()):
        items.append(printable(rel))
    titles = None if base == "-" else commit_titles(repo, base, end)
    if base == "-":
        heads = ["없음 — 기준 커밋을 모름"]
    elif titles is None:
        heads = ["모름 — 커밋 제목을 읽지 못함"]
    else:
        heads = titles or ["없음"]
    for item in items:
        lines.append("- " + item)
    lines += ["", "## 커밋 제목"]
    for item in heads:
        lines.append("- " + item)
    return "\n".join(lines) + "\n"


def _frontmatter(text: str) -> tuple:
    """(머리의 YAML 값 | None, 머리가 있는데 YAML 로 읽지 못했나).

    YAML 은 YAMLError 말고도 예외를 낸다(없는 날짜 · 틀린 수의 ValueError 등) — 어떤 예외든 읽지 못한 머리다.
    """
    if not text.startswith("---\n"):
        return (None, False)
    end = text.find("\n---", 4)
    if end < 0:
        return (None, False)
    try:
        data = yaml.safe_load(text[4:end])
        if isinstance(data, dict):
            for value in data.values():
                if isinstance(value, _SCALARS):
                    str(value)  # 글로 바꿀 수 없는 값(아주 큰 정수 등)은 예외로 드러난다
        return (data, False)
    except Exception:  # noqa: BLE001 — 남의 문서 머리 하나가 단계를 죽이지 않게
        return (None, True)


def frontmatter_unreadable(text: str) -> bool:
    """머리(`---` 사이)가 있는데 YAML 로 읽히지 않는가 — 「머리 없음」 과 가르려고."""
    return _frontmatter(text)[1]


# 머리 값으로 받는 꼴 — 목록 · 매핑은 받지 않는다(글로 바꾸면 YAML 별칭이 펼쳐진다).
_SCALARS = (str, int, float, datetime.date)


def frontmatter_value(text: str, key: str) -> Optional[str]:
    data = _frontmatter(text)[0]
    if not isinstance(data, dict):
        return None
    value = data.get(key)
    if value is None or not isinstance(value, _SCALARS):
        return None
    try:
        return str(value).strip()
    except Exception:  # noqa: BLE001 — 글로 바꿀 수 없는 값은 없는 값이다
        return None


# ---------------------------------------------------------------- 의도 문서 · 리뷰의 넓이

def _marker_chars_ok(text: str, extra: str) -> bool:
    if not text:
        return False
    for ch in text:
        if not (ch.isascii() and (ch.isalnum() or ch in "_-" + extra)):
            return False
    return True


def parse_markers(raw: str) -> Optional[List[str]]:
    """쉼표 목록 → 표시 목록. 빈 목록이거나 틀린 토큰이 하나라도 있으면 None."""
    out: List[str] = []
    for token in raw.split(","):
        token = token.strip(" ")
        key, sep, value = token.partition("=")
        if not _marker_chars_ok(key, ""):
            return None
        if sep and not _marker_chars_ok(value, "."):
            return None
        out.append(token)
    return out


def is_intent_doc(text: str, markers: List[str]) -> bool:
    for marker in markers:
        key, sep, value = marker.partition("=")
        found = frontmatter_value(text, key)
        if found is not None and (not sep or found == value):
            return True
    return False


def _intent_docs(ordered: List[str], read_doc, markers: List[str]) -> tuple:
    """(의도 문서 경로 목록, 읽지 못한 문서 수) — `read_doc(rel)` 이 None 이면 읽지 못한 것."""
    intent_docs: List[str] = []
    unread = 0
    for rel in ordered:
        text = read_doc(rel)
        if text is None:
            unread += 1
        elif is_intent_doc(text, markers):
            intent_docs.append(rel)
    return intent_docs, unread


def review_breadth(mode: str, names: Optional[set], read_doc, markers: List[str]) -> tuple:
    """(넓이, 의도 문서 경로 목록, 읽지 못한 문서 수).

    넓이: `range`(범위 모드 · 바뀐 파일 있음) · `intent-docs`(PR 의 바뀐 파일이 모두 문서 파일이고
    의도 문서가 하나 이상) · `narrow`(그 밖). `read_doc(rel)` 이 None 인 문서는 의도 문서로 세지
    않고 읽지 못한 수에 더한다. 범위 모드도 바뀐 파일이 모두 문서 파일이고 모델이 읽는 파일이
    없을 때만 바뀐 의도 문서 목록을 낸다.
    """
    if mode not in ("range", "pr") or not names:
        return ("narrow", [], 0)
    ordered = sorted(names)
    for rel in ordered:
        if not doc_paths.is_doc_file(rel) or doc_paths.is_model_read(rel):
            return ("range", [], 0) if mode == "range" else ("narrow", [], 0)
    intent_docs, unread = _intent_docs(ordered, read_doc, markers)
    if mode == "range":
        return ("range", intent_docs, unread)
    return ("intent-docs" if intent_docs else "narrow", intent_docs, unread)


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

# 출처 표지 — 원문 · 로드맵 · 의심 칸에서 스크립트가 쓰는 표지 줄의 머리 낱말. 본문(리뷰받는 쪽 글)에
# 같은 꼴이 있으면 `<!--` 를 `&lt;!--` 로 바꿔 싣는다 — 표지는 스크립트가 쓴 것만 남는다.
MARK_OPEN = "<!--"
MARK_OPEN_SAFE = "&lt;!--"
MARK_CLOSE = "-->"
MARK_CLOSE_SAFE = "--&gt;"
MARK_KEYS = ("origin-source", "roadmap", "intent-doubts")
# `<!--` 와 머리 낱말 사이에 있어도 표지로 읽힐 글자 — 빈칸(str.isspace)과 폭 없는 글자.
_MARK_GAP = "\u200b\u200c\u200d\u2060\ufeff"


def _marker_like(rest: str) -> bool:
    i = 0
    while i < len(rest) and (rest[i].isspace() or rest[i] in _MARK_GAP):
        i += 1
    head = rest[i:i + 32].casefold()
    for key in MARK_KEYS:
        if head.startswith(key):
            return True
    return False


def neutralize_markers(text: str) -> str:
    """본문의 표지 꼴(`<!--` 뒤 빈칸 · 폭 없는 글자 다음이 표지 머리 낱말 — 글자 크기 무관, 줄 어디서든)의
    `<!--` 를 `&lt;!--` 로 바꾼다."""
    out: List[str] = []
    start = 0
    while True:
        at = text.find(MARK_OPEN, start)
        if at < 0:
            out.append(text[start:])
            return "".join(out)
        out.append(text[start:at])
        end = at + len(MARK_OPEN)
        out.append(MARK_OPEN_SAFE if _marker_like(text[end:]) else MARK_OPEN)
        start = end


def marker_field(value: str) -> str:
    """표지 안에 들어가는 필드(출처 · 경로) — 표지를 닫거나 새 표지를 여는 글자를 무력화한다."""
    return neutralize_markers(value).replace(MARK_CLOSE, MARK_CLOSE_SAFE)
_DOUBT_HEADS = ("## 5.", "## 3.")


def _note(st: dict, line: str) -> None:
    if line not in st["notices"]:
        st["notices"].append(line)


def _open_doc(read, rel: str, st: dict, label: str) -> Optional[str]:
    """`read(rel) -> (글 | None, 사유)` 로 연다. 연 문서는 읽은 쪽과 함께 남긴다 — 로드맵도 그 쪽에서 읽는다."""
    for seen_rel, _, seen_text in st["opened"]:
        if seen_rel == rel:
            return None if rel in st["done"] else seen_text
    text, why = read(rel)
    if text is None:
        if why == REASON_TIMEOUT:
            _note(st, "%s 를 읽지 못함 — %s" % (rel, REASON_TIMEOUT))
        else:
            _note(st, "%s — %s" % (label, why))
        st["rejected"] = True
        return None
    st["opened"].append((rel, read, text))
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
    marker = "<!-- origin-source: %s · file: %s -->" % (marker_field(source), marker_field(rel))
    text = neutralize_markers(text)
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


def _follow_roadmaps(st: dict) -> str:
    """연 문서의 `roadmap:` 줄을 따라가 로드맵 칸을 짓는다. 바뀐 로드맵 자체(`own_roadmaps`)는 그 글을 싣는다."""
    seen: List[str] = []
    parts: List[str] = []
    for rel, read, text in list(st["opened"]):
        own = rel in st["own_roadmaps"]
        path = rel if own else frontmatter_value(text, "roadmap")
        if path is None or path in seen:
            continue
        seen.append(path)
        body, why = (text, None) if own else read(path)
        if body is None:
            if why == REASON_TIMEOUT:
                _note(st, "로드맵 %s 를 읽지 못함 — %s" % (path, why))
            else:
                _note(st, "로드맵 링크 거부 — %s" % why)
            st["rejected_roadmap"] = True
            continue
        kept, moved = strip_roadmap_doubts(neutralize_markers(body))
        st["roadmaps"].append(path)
        parts.append("<!-- roadmap: %s · from: %s -->\n%s"
                     % (marker_field(path), marker_field(rel), kept))
        if moved.strip():
            st["doubts"].append("<!-- roadmap-doubts: %s -->\n%s" % (marker_field(path), moved))
    if parts:
        return "\n".join(parts)
    reason = "로드맵 링크 거부" if st.get("rejected_roadmap") else "연 문서에 roadmap: 없음"
    line = "로드맵 없음 — " + reason
    _note(st, line)
    return line


def _reader(repo: str, commit: str, tree_root: Optional[str] = None):
    if tree_root is not None:
        return lambda rel: read_tree(tree_root, rel)
    return lambda rel: read_tracked(repo, commit, rel)


def _head_link(text: str) -> Optional[str]:
    """머리의 원문 링크 — 새 키 `source_intent:` 에 값이 있으면 그 값, 키가 없거나 값이 없으면 옛 `source_interview:`(따옴표만 빈 값 `""` 은 값이다)."""
    link = frontmatter_value(text, "source_intent")
    if link is None:
        link = frontmatter_value(text, "source_interview")
    return link


def _follow_changed(read, rel: str, st: dict) -> None:
    """바뀐 의도 문서 — `source_intent:` · 옛 `source_interview:` · `source_brief:` 를 원문으로 따라가고, 로드맵 자체면 로드맵 칸에 싣는다."""
    text = _open_doc(read, rel, st, "원문 링크 거부")
    if text is None:
        return
    if frontmatter_value(text, "type") == "roadmap":
        st["own_roadmaps"].append(rel)
    for link in (_head_link(text), frontmatter_value(text, "source_brief")):
        if link is None:
            continue
        linked = _open_doc(read, link, st, "원문 링크 거부")
        if linked is not None:
            _add_origin_doc(link, linked, st)


def build_origin(repo: str, head_commit: str, review_commit: str,
                 caller_origin: Optional[str], specs: list, changed_docs=(),
                 tree_root: Optional[str] = None) -> dict:
    """원문 · 의심 · 로드맵 칸. 리뷰 쪽 문서(설계문서 · 그 링크 · 바뀐 의도 문서 · 그들의 로드맵)는
    `tree_root` 가 있으면 리뷰 트리에서, 없으면 `review_commit` 에서 읽는다. 부른 쪽 원문과 그 로드맵은
    늘 `head_commit` 에서 읽는다."""
    st: dict = {"origin": [], "doubts": [], "sources": [], "aliases": {}, "notices": [],
                "mixed": False, "rejected": False, "opened": [], "done": [],
                "own_roadmaps": [], "roadmaps": []}
    review = _reader(repo, review_commit, tree_root)
    if caller_origin:
        text = _open_doc(_reader(repo, head_commit), caller_origin, st, "원문 링크 거부")
        if text is not None:
            _add_origin_doc(caller_origin, text, st)
    else:
        for spec in specs:
            spec_text = _open_doc(review, spec, st, "원문 링크 거부")
            if spec_text is None:
                continue
            link = _head_link(spec_text)
            if link is None:
                continue
            text = _open_doc(review, link, st, "원문 링크 거부")
            if text is not None:
                _add_origin_doc(link, text, st)
    for rel in changed_docs:
        _follow_changed(review, rel, st)
    if st["origin"]:
        origin = "\n".join(st["origin"])
    else:
        if st["rejected"]:
            reason = "원문 링크 거부"
        elif not specs and not caller_origin and not changed_docs:
            reason = "의도 출처에 설계문서 없음"
        else:
            reason = "부른 쪽 원문도 설계문서 링크도 없음"
        origin = "원문 없음 — " + reason
        _note(st, origin)
    roadmap = _follow_roadmaps(st)
    return {"origin": origin, "doubts": "\n".join(st["doubts"]), "roadmap": roadmap,
            "sources": st["sources"], "aliases": st["aliases"], "notices": st["notices"],
            "mixed": st["mixed"], "roadmaps": st["roadmaps"]}
