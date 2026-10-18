#!/usr/bin/env python3
"""리뷰 diff 에서 뺄 문서 경로 규칙 — 이 규칙의 유일한 자리다(AC23).

패턴은 환경 변수 DEVBREW_QUALITY_GATES_DOC_PATHS(쉼표 목록)가 정하고, 없으면 기본 목록이다.
빈 값은 「아무것도 빼지 않음」이다. 이 변경이 `.claude/settings.json` 의 그 키를 바꾸면
기본 목록으로 돌아간다(리뷰 대상이 자기 리뷰 범위를 정하지 못하게).

포함 규칙이 먼저다 — 패턴에 맞아도 문서 파일만 빠진다. 문서 파일 중 모델이 읽는 파일은 남긴다.
패턴에 걸렸지만 남긴 경로는 `kept` 로 이름을 낸다.

패턴 문법: `/` 가 없는 패턴은 어느 깊이의 파일 이름에나 맞고, `/` 가 있는 패턴은 레포 루트
기준 경로 전체에 맞는다. `**` 는 여러 마디, `*` · `?` 는 한 마디 안, `[...]` 는 문자 묶음.

  doc_paths.py select --names <file> --settings-base <file> --settings-head <file>

    --names 는 한 줄에 경로 하나. 설정 파일 인자는 없는 경로여도 된다(그쪽에 설정 없음).
    stdout: doc_paths_source · doc_paths · bad_patterns · excluded · kept_model 다섯 줄 뒤에
    뺀 경로마다 `exclude<TAB><경로>`, 남긴 경로마다 `kept<TAB><경로>`.
    rc 0 · 사용 오류 2 · 입력 파일을 못 읽음 4.
"""
from __future__ import annotations

import json
import os
import re
import sys
from typing import List, Optional, Tuple

ENV_KEY = "DEVBREW_QUALITY_GATES_DOC_PATHS"
DEFAULT_DOC_PATHS = ("README*", "CHANGELOG*")
DOC_EXTS = (".md", ".markdown", ".mdx", ".rst", ".txt", ".adoc")
DOC_BARE_NAMES = ("README", "CHANGELOG")
MODEL_READ_NAMES = ("CLAUDE.md", "AGENTS.md", "SKILL.md")
MODEL_READ_SEGMENTS = ("agents", "skills", "commands", "references", "templates", "hooks",
                       ".claude", ".claude-plugin")

_CTRL = re.compile(r"[\x00-\x1f\x7f]")


def parse_patterns(raw: Optional[str]) -> Tuple[List[str], List[str], str]:
    """(적용할 패턴, 읽지 못한 패턴, 출처 default|env)."""
    if raw is None:
        return list(DEFAULT_DOC_PATHS), [], "default"
    good: List[str] = []
    bad: List[str] = []
    for item in raw.split(","):
        item = item.strip()
        if not item:
            continue
        if item.startswith((":", "!")) or _CTRL.search(item):
            bad.append(item)
        else:
            good.append(item)
    return good, bad, "env"


def pattern_regex(pat: str) -> "re.Pattern[str]":
    out: List[str] = []
    i, n = 0, len(pat)
    while i < n:
        if pat.startswith("**/", i):
            out.append("(?:[^/]+/)*")
            i += 3
        elif pat.startswith("/**", i) and i + 3 == n:
            out.append("(?:/.*)?")
            i += 3
        elif pat.startswith("**", i):
            out.append(".*")
            i += 2
        elif pat[i] == "*":
            out.append("[^/]*")
            i += 1
        elif pat[i] == "?":
            out.append("[^/]")
            i += 1
        elif pat[i] == "[":
            j = i + 1
            if j < n and pat[j] == "!":
                j += 1
            if j < n and pat[j] == "]":
                j += 1
            while j < n and pat[j] != "]":
                j += 1
            if j >= n:
                out.append(re.escape("["))
                i += 1
                continue
            body = pat[i + 1:j]
            neg = body.startswith("!")
            if neg:
                body = body[1:]
            body = body.replace("\\", "\\\\")
            if not neg and body.startswith("^"):
                body = "\\" + body
            out.append("[" + ("^" if neg else "") + body + "]")
            i = j + 1
        else:
            out.append(re.escape(pat[i]))
            i += 1
    return re.compile("".join(out), re.DOTALL)


def matches(pat: str, path: str) -> bool:
    if "/" in pat:
        target = path
        if pat.startswith("/"):
            pat = pat[1:]
    else:
        target = path.rsplit("/", 1)[-1]
    return pattern_regex(pat).fullmatch(target) is not None


def is_doc_file(path: str) -> bool:
    if _CTRL.search(path):
        return False
    name = path.rsplit("/", 1)[-1]
    if name in DOC_BARE_NAMES:
        return True
    return name.lower().endswith(DOC_EXTS)


def is_model_read(path: str) -> bool:
    parts = path.split("/")
    if parts[-1] in MODEL_READ_NAMES:
        return True
    return any(seg in MODEL_READ_SEGMENTS for seg in parts[:-1])


_ABSENT = object()


def _key_state(text: Optional[str]):
    """설정 글 → 그 키의 값(없으면 _ABSENT). JSON 이 아니면 ValueError."""
    if text is None:
        return _ABSENT
    obj = json.loads(text)
    if not isinstance(obj, dict):
        return _ABSENT
    env = obj.get("env")
    if not isinstance(env, dict) or ENV_KEY not in env:
        return _ABSENT
    return env[ENV_KEY]


def settings_key_changed(base_text: Optional[str], head_text: Optional[str]) -> bool:
    if base_text == head_text:
        return False
    try:
        return _key_state(base_text) != _key_state(head_text)
    except ValueError:
        return True


def select(paths: List[str], patterns: List[str]) -> Tuple[List[str], List[str]]:
    """(뺀 경로, 패턴에 걸렸지만 남긴 경로)."""
    regs = []
    for p in patterns:
        if "/" in p:
            regs.append((True, pattern_regex(p[1:] if p.startswith("/") else p)))
        else:
            regs.append((False, pattern_regex(p)))
    excluded: List[str] = []
    kept: List[str] = []
    for path in paths:
        base = path.rsplit("/", 1)[-1]
        if not any(r.fullmatch(path if full else base) for full, r in regs):
            continue
        if is_doc_file(path) and not is_model_read(path):
            excluded.append(path)
        else:
            kept.append(path)
    return excluded, kept


def _read_optional(path: str) -> Optional[str]:
    try:
        with open(path, "rb") as fh:
            data = fh.read()
    except FileNotFoundError:
        return None
    return data.decode("utf-8", errors="replace")


def _usage(msg: str) -> int:
    sys.stderr.write("doc_paths: %s\nusage: doc_paths.py select --names <file> "
                     "--settings-base <file> --settings-head <file>\n" % msg)
    return 2


def main(argv: List[str]) -> int:
    if not argv or argv[0] != "select":
        return _usage("첫 인자는 select 여야 한다")
    opts = {"--names": None, "--settings-base": None, "--settings-head": None}
    rest = argv[1:]
    i = 0
    while i < len(rest):
        k = rest[i]
        if k not in opts or i + 1 >= len(rest) or opts[k] is not None:
            return _usage("알 수 없는 인자 또는 값 없음: %s" % k)
        opts[k] = rest[i + 1]
        i += 2
    if any(v is None or v == "" for v in opts.values()):
        return _usage("--names · --settings-base · --settings-head 가 모두 필요하다")

    try:
        with open(opts["--names"], "r", encoding="utf-8", errors="surrogateescape") as fh:
            paths = [ln.rstrip("\n") for ln in fh if ln.rstrip("\n")]
        base_text = _read_optional(opts["--settings-base"])
        head_text = _read_optional(opts["--settings-head"])
    except OSError as e:
        sys.stderr.write("doc_paths: 입력 파일을 읽지 못했다: %s\n" % e)
        return 4

    if settings_key_changed(base_text, head_text):
        patterns, bad, source = list(DEFAULT_DOC_PATHS), [], "default-settings-changed"
    else:
        patterns, bad, source = parse_patterns(os.environ.get(ENV_KEY))

    excluded, kept = select(paths, patterns)
    lines = [
        "doc_paths_source: %s" % source,
        "doc_paths: %s" % (",".join(patterns) if patterns else "(없음)"),
        "bad_patterns: %s" % (",".join(_CTRL.sub("?", b) for b in bad) if bad else "-"),
        "excluded: %d" % len(excluded),
        "kept_model: %d" % len(kept),
    ]
    lines += ["exclude\t%s" % p for p in excluded]
    lines += ["kept\t%s" % p for p in kept]
    out = "\n".join(lines) + "\n"
    sys.stdout.buffer.write(out.encode("utf-8", errors="surrogateescape"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
