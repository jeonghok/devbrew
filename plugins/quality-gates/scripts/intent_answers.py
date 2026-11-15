"""intent-critic 질문의 정체 · 답 파일 · 그 파일만 담는 커밋.

질문 정체는 `<출처>#<무엇>#<종류>` 다. 답 파일은 docs 답 자리에 새로 쓰고(덮어쓰지 않는다),
커밋은 그 파일만 담는다(이미 스테이지된 다른 변경은 건드리지 않는다).
"""
from __future__ import annotations

import hashlib
import os
import re
import subprocess
from typing import List, Optional

import yaml

KINDS = ("방향", "빠진 기능", "쓰이지 않을 기능", "범위 축소", "모호한 말 굳힘",
         "앞 결정 뒤집힘", "기본값", "조용한 실패", "마찰", "갈라짐", "중복", "기타")
ANSWERS = ("의도다", "잘못 골랐다", "지금은 모르겠다")

TYPE_VALUE = "qg-intent-answer"
_UNIDENTIFIED = re.compile(r"unidentified:[0-9a-f]{12}")
_HEAD_OBS = "## 근거로 본 관찰"
_WS = re.compile(r"\s")
# 답 파일 이름의 꼴 — answer_filename 이 내는 모양 하나. 읽을 때(read_answered)도 이 꼴만 받는다.
_ANSWER_NAME = re.compile(r"[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}\.md")


def make_id(source: str, what: str, kind: str) -> Optional[str]:
    if not isinstance(source, str) or not isinstance(what, str) or kind not in KINDS:
        return None
    if source != "diff":
        if (not source or source.startswith("/") or "#" in source or _WS.search(source)
                or ".." in source.split("/")):
            return None
    if not what or "#" in what or _WS.search(what):
        return None
    return "%s#%s#%s" % (source, what, kind)


def split_id(ident: str) -> Optional[tuple]:
    if not isinstance(ident, str):
        return None
    parts = ident.split("#")
    if len(parts) != 3:
        return None
    if make_id(parts[0], parts[1], parts[2]) != ident:
        return None
    return (parts[0], parts[1], parts[2])


def is_answer_filename(name: str) -> bool:
    """qg 가 쓰는 꼴(`<8자리>T<6자리>Z-<16진 12자>.md`)의 이름인가. 끝 개행도 받지 않는다(fullmatch)."""
    return isinstance(name, str) and _ANSWER_NAME.fullmatch(name) is not None


def answer_filename(ident: str, answered_at: str) -> str:
    stamp = re.sub(r"[-:]", "", answered_at)
    name = "%s-%s.md" % (stamp, hashlib.sha1(ident.encode("utf-8")).hexdigest()[:12])
    if not is_answer_filename(name):
        raise ValueError("answered_at 이 YYYY-MM-DDTHH:MM:SSZ 꼴이 아니다: %r" % answered_at)
    return name


def _defang(text: str) -> str:
    """본문 칸 안의 `## ` 줄이 절 머리로 읽히지 않게 한 칸 들여 쓴다."""
    lines = []
    for line in str(text).split("\n"):
        lines.append(" " + line if line.startswith("## ") else line)
    return "\n".join(lines)


def _quoted(value: str) -> str:
    out = ['"']
    for ch in str(value):
        if ch in '\\"':
            out.append("\\" + ch)
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\t":
            out.append("\\t")
        elif ord(ch) < 0x20:
            out.append(" ")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def render_answer_file(ident, question, quote, label, observation_lines, answer,
                       raw_text, target, answered_at) -> str:
    obs = "\n".join(_defang(x) for x in observation_lines)
    return (
        "---\n"
        "type: %s\n"
        "id: %s\n"
        "answer: %s\n"
        "answered_at: %s\n"
        "target: %s\n"
        "---\n\n"
        "## 질문\n\n%s\n\n"
        "## 의심한 구절\n\n%s (%s)\n\n"
        "%s\n\n%s\n\n"
        "## 답 원문\n\n%s\n"
    ) % (TYPE_VALUE, _quoted(ident), answer, _quoted(answered_at), _quoted(target),
         _defang(question), _defang(quote), label, _HEAD_OBS, obs, _defang(raw_text))


def _frontmatter(text: str):
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return None, None
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            return "\n".join(lines[1:i]), lines[i + 1:]
    return None, None


def _observation(body_lines: list) -> str:
    out = []
    inside = False
    for line in body_lines:
        if line.startswith("## "):
            if inside:
                break
            inside = line.strip() == _HEAD_OBS
            continue
        if inside:
            out.append(line)
    return "\n".join(out).strip()


def parse_answer_file(text: str) -> Optional[dict]:
    if not isinstance(text, str):
        return None
    head, body = _frontmatter(text)
    if head is None:
        return None
    try:
        data = yaml.safe_load(head)
    except Exception:  # noqa: BLE001 — YAML 은 YAMLError 말고도 낸다(없는 날짜 등)
        return None
    if not isinstance(data, dict) or data.get("type") != TYPE_VALUE:
        return None
    ident = data.get("id")
    if not isinstance(ident, str):
        return None
    if split_id(ident) is None and not _UNIDENTIFIED.fullmatch(ident):
        return None
    answer = data.get("answer")
    if answer not in ANSWERS:
        return None
    at = data.get("answered_at")
    target = data.get("target")
    try:
        return {"id": ident, "answer": answer,
                "answered_at": "" if at is None else str(at),
                "observation": _observation(body),
                "target": "" if target is None else str(target)}
    except Exception:  # noqa: BLE001 — 글로 바꿀 수 없는 값은 읽지 못한 답 파일
        return None


def read_answered(answers_dir: str) -> tuple:
    answered = {}
    unreadable = 0
    if not os.path.isdir(answers_dir):
        return {}, 0
    try:
        names = sorted(os.listdir(answers_dir))
    except OSError:
        return {}, 0
    for name in names:
        if not name.endswith(".md"):
            continue
        path = os.path.join(answers_dir, name)
        if not is_answer_filename(name) or os.path.islink(path) or not os.path.isfile(path):
            unreadable += 1
            continue
        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except (OSError, UnicodeDecodeError):
            unreadable += 1
            continue
        try:
            parsed = parse_answer_file(text)
        except Exception:  # noqa: BLE001 — 답 파일 하나가 읽기 전체를 죽이지 않게
            parsed = None
        if parsed is None:
            unreadable += 1
            continue
        if parsed["id"].startswith("unidentified:"):
            continue
        parsed["path"] = path
        prev = answered.get(parsed["id"])
        if prev is None or (parsed["answered_at"], name) >= (
                prev["answered_at"], os.path.basename(prev["path"])):
            answered[parsed["id"]] = parsed
    return answered, unreadable


REASON_LINKED = "답 자리가 심볼릭 링크를 지난다"


def read_answered_under(tree_root: str, answers_dir: str) -> tuple:
    """리뷰 트리 아래 답 자리를 읽는다 → (answered, 읽지 못한 수, 읽지 않은 사유 | None).

    트리 루트 아래 경로 마디 가운데 심볼릭 링크가 하나라도 있으면 읽지 않는다 — 쓸 때와 같은 규칙이고,
    링크 너머 파일은 리뷰 범위가 바꾼 파일 목록의 경로와 맞춰 볼 수 없다.
    """
    cur = os.path.normpath(tree_root)
    linked = False
    for part in answers_dir.split("/"):
        if part:
            cur = os.path.join(cur, part)
            if os.path.islink(cur):
                linked = True
    if linked:
        return {}, 0, REASON_LINKED
    answered, unreadable = read_answered(cur)
    return answered, unreadable, None


def _inside(root_real: str, path_real: str) -> bool:
    return path_real == root_real or path_real.startswith(root_real.rstrip(os.sep) + os.sep)


def _prepare_dir(repo_root: str, answers_dir: str):
    """답 자리를 만들고 (절대 경로, 리포 상대 경로, 오류) 를 낸다."""
    root_real = os.path.realpath(repo_root)
    target = os.path.normpath(os.path.join(repo_root, answers_dir))
    base = os.path.normpath(repo_root)
    if _inside(base, target):
        walk_root = base
    elif _inside(root_real, os.path.realpath(target)):
        walk_root, target = root_real, os.path.realpath(target)
    else:
        return None, None, "답 자리가 리포 밖이다"
    rel = os.path.relpath(target, walk_root)
    cur = walk_root
    if rel != ".":
        for part in rel.split(os.sep):
            cur = os.path.join(cur, part)
            if os.path.islink(cur):
                return None, None, "답 자리가 심볼릭 링크다"
            if not os.path.exists(cur):
                os.mkdir(cur)
    if not _inside(root_real, os.path.realpath(cur)):
        return None, None, "답 자리가 리포 밖이다"
    return cur, ("" if rel == "." else rel), None


def write_answer_files(repo_root: str, answers_dir: str, files: list) -> tuple:
    written: List[str] = []
    try:
        directory, rel, err = _prepare_dir(repo_root, answers_dir)
    except OSError:
        return written, "답 파일을 쓰지 못했다"
    if err:
        return written, err
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
    for name, text in files:
        if not name or os.sep in name or name in (".", ".."):
            return written, "답 파일을 쓰지 못했다"
        path = os.path.join(directory, name)
        try:
            body = text.encode("utf-8")   # 파일을 만들기 전에 — 쓸 수 없는 글이 빈 파일을 남기지 않게
        except UnicodeEncodeError:
            return written, "답 파일을 쓰지 못했다"
        try:
            fd = os.open(path, flags, 0o644)
        except FileExistsError:
            return written, "같은 이름의 답 파일이 이미 있다"
        except OSError:
            return written, "답 파일을 쓰지 못했다"
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(body)
        except OSError:
            return written, "답 파일을 쓰지 못했다"
        written.append(os.path.join(rel, name) if rel else name)
    return written, None


def _git(repo_root: str, *args: str):
    return subprocess.run(["git", "-C", repo_root] + list(args),
                          capture_output=True, text=True, encoding="utf-8", errors="replace")


def _literal(paths: list) -> list:
    """경로마다 `:(literal)` 을 붙인 pathspec — glob 글자 · `:!x` 같은 매직 꼴이어도 그 글자 그대로의 경로다.

    전역 `--literal-pathspecs` 는 쓰지 않는다: 그 플래그는 환경 변수로 `git commit` 이 띄우는 훅에 물려져
    훅 안의 pathspec 뜻까지 바꾼다.
    """
    out = []
    for path in paths:
        out.append(":(literal)" + path)
    return out


def _ignored(repo_root: str, paths: list) -> bool:
    """git 이 무시하는 경로가 하나라도 있나. check-ignore 는 pathspec 매직을 받지 않고 `-q` 는 경로 하나만
    받는다 — 경로마다 `./` 를 붙여(맨 앞 `:` 가 매직으로 읽히지 않게) 따로 묻는다."""
    ignored = False
    for path in paths:
        if _git(repo_root, "check-ignore", "-q", "--", "./" + path).returncode == 0:
            ignored = True
    return ignored


def _first_line(text: str) -> str:
    lines = (text or "").strip().splitlines()
    return lines[0] if lines else ""


def _unstage(repo_root: str, paths: list) -> None:
    """답 파일만 스테이지에서 내린다. HEAD 가 없어 restore 가 안 되면 캐시에서 뺀다."""
    specs = _literal(paths)
    if _git(repo_root, "restore", "--staged", "--", *specs).returncode != 0:
        _git(repo_root, "rm", "--cached", "--quiet", "--ignore-unmatch", "--", *specs)


def commit_answer_files(repo_root: str, paths: list, message: str) -> tuple:
    if not paths:
        return None, "커밋할 답 파일이 없다"
    if _git(repo_root, "symbolic-ref", "-q", "HEAD").returncode != 0:
        return None, "브랜치가 아니다(detached HEAD)"
    specs = _literal(paths)
    add = _git(repo_root, "add", "--", *specs)
    if add.returncode != 0:
        _unstage(repo_root, paths)
        if _ignored(repo_root, paths):
            return None, "답 자리를 git 이 무시한다"
        return None, "git add 실패 — " + _first_line(add.stderr)
    commit = _git(repo_root, "commit", "--only", "-q", "-m", message, "--", *specs)
    if commit.returncode != 0:
        _unstage(repo_root, paths)
        return None, "git commit 실패 — " + (_first_line(commit.stderr) or _first_line(commit.stdout))
    rev = _git(repo_root, "rev-parse", "--short", "HEAD")
    if rev.returncode != 0:
        return None, "git rev-parse 실패 — " + _first_line(rev.stderr)
    return rev.stdout.strip(), None
