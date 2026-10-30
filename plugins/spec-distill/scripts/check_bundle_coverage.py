#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 정답 출처(에픽 묶음 · brief)의 번호와 설계문서 `## 번호 대조` 표를 맞춘다.

명령줄:
  check_bundle_coverage.py <묶음|brief> <설계문서> [--json]        번호 대조(설계문서 단계)
  check_bundle_coverage.py --plan <설계문서> <계획> [--acs <AC 목록>] [--json]        계획 `### Task` 절에 없는 AC — 0 · 1 · 3
  check_bundle_coverage.py --impl <설계문서> <보고 파일> [--acs <AC 목록>] [--json]   구현 보고의 미룸 · 빠짐 — 0 · 1(경고) · 3
`--acs` 는 그 AC 만 대조한다(`AC1~AC14 · AC39` 꼴). `--impl` 은 설계문서 frontmatter `roadmap:` 의 로드맵에서
받는 곳 규칙(로드맵의 에픽 · `#<n>`)을 쓴다.
종료 코드 — 리뷰 전에 막을 것만 말한다: 0 빠진 번호 없음 · 1 빠진 번호 있음 · 2 사용법 오류 ·
3 검사 불가(`ids:` 없음 · 표 깨짐 · `## 번호 대조` 절 없음 · 파일이나 brief · audit 을 못 읽음 · 내부 오류).
얕은 답 · 받드는 에픽 없는 발화 · 셀 수 없음(로드맵을 못 읽음)은 종료 코드를 바꾸지 않는다 — 첫 줄의 개수와
번호별 줄, `--json` 의 `shallow` · `unserved` · `unknown` 이 말한다. rc 0 은 「리뷰 전에 막을 것 없음」이다.

계수 규칙(R3 설계 Deferred N17 · N18):
- 「기각」 행은 그 번호를 덮은 것으로 센다(빠진 번호가 아니다). 대신 기각 이유의 에픽 번호는 로드맵에 있어야
  하고(없으면 얕음), 기각한 발화(S)는 로드맵의 다른 블록이 받들어야 한다(없으면 받드는 에픽 없는 발화).
- 받듦은 배정만으로 세지 않는다 — 다른 블록에 배정됐어도 그 블록의 작업 트리 설계문서가 그 S 를 「기각」했으면
  받들지 않는다. 설계문서가 아직 없거나 표를 못 읽으면 배정이 받듦이다.
- brief 입력에는 로드맵이 없어 기각 에픽 · 받듦 검사를 하지 않는다.

`roadmap_status.py` 는 `check(bundle_text, spec_text, repo=…)` 를 import 해 `git show` 로 읽은 글과 main 트리를 읽는 repo 를
넘기고, status 와 함께 shallow · unserved · unknown 을 블록의 경고 줄로 싣는다(경고가 있으면 그 종료 코드는 1 이다).
읽기만 한다 — 파일을 쓰지 않고 git · 네트워크를 부르지 않는다.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from repo_defaults import SettingsError, resolve  # noqa: E402
from roadmap_model import (  # noqa: E402,F401 — 이 이름들은 이 모듈의 공개 표면이기도 하다
    FormatError, PREFIX_ORDER, SEP_CELL_RE, SEP_RE, TOKEN_RE, brief_universe, bundle_ids,
    collect_assigned, frontmatter, id_sort_key, parse_ids, parse_roadmap, receiver_ok, section_body, unquote)

TABLE_HEADING = "## 번호 대조"
AC_HEADING = "## Acceptance Criteria"
# 자리 표기 — `§<n>` · `§<n>-<m>` · `AC<n>`. 숫자 뒤에 숫자가 이어지면 다른 토큰이다(AC1 ≠ AC10).
SECTION_TOKEN_RE = re.compile(r"§(\d+)(?:-(\d+))?(?!\d)")
AC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])AC(\d+)(?!\d)")
AC_ITEM_RE = re.compile(r"\s*[-*]\s+(?:\*\*)?AC(\d+)(?!\d)")
EPIC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])([A-Z]\d+[a-z]?)(?![A-Za-z0-9])")
ACS_PART_RE = re.compile(r"AC(\d+)(?:~(?:AC)?(\d+))?")
ACS_RANGE_MAX = 1000
ACS_SEP = (",", "·")


def epic_refs(cell: str, known=None) -> list:
    """칸이 가리키는 에픽 이름(대문자 + 숫자 + 소문자 선택). brief 번호 꼴(S36 · C7 · K2 …)은 로드맵에 그 이름의
    에픽이 있을 때만 에픽으로 읽는다."""
    out = []
    for e in EPIC_TOKEN_RE.findall(cell):
        if (known is not None and e in known) or not TOKEN_RE.fullmatch(e):
            if e not in out:
                out.append(e)
    return out


def parse_acs(value: str) -> list:
    """`AC1~AC14 · AC39, AC40` → AC 목록(나온 순서, 중복 제거). `AC1~14` · `AC1 ~ AC3` 도 받고 범위는 1000개까지."""
    pieces = [value]
    for sep in ACS_SEP:
        pieces = [q for piece in pieces for q in piece.split(sep)]
    flat = "~".join(q.strip() for q in " ".join(pieces).split("~"))
    out = []
    for piece in flat.split():
        m = ACS_PART_RE.fullmatch(piece)
        if not m:
            raise FormatError("--acs 조각이 AC<n> 또는 AC<a>~AC<b> 가 아니다: %r" % piece)
        a, b = int(m.group(1)), int(m.group(2) or m.group(1))
        if b < a:
            raise FormatError("--acs 범위가 거꾸로다: %r" % piece)
        if b - a + 1 > ACS_RANGE_MAX:
            raise FormatError("--acs 범위가 너무 크다(%d개까지): %r" % (ACS_RANGE_MAX, piece))
        out += [ac for ac in ("AC%d" % n for n in range(a, b + 1)) if ac not in out]
    if not out:
        raise FormatError("--acs 가 비었다")
    return out


class Repo:
    """레포 루트 기준 읽기 — 로드맵 · 다른 묶음 · 작업 트리 설계문서. 읽기만 한다."""

    def __init__(self, root: str):
        self.root = root
        self._specs = {}
        self._unread = {}

    def read(self, rel: str):
        try:
            with open(os.path.join(self.root, rel), encoding="utf-8") as fh:
                return fh.read()
        except (OSError, UnicodeDecodeError):
            return None

    def exists(self, rel: str) -> bool:
        return os.path.exists(os.path.join(self.root, rel))

    def absent(self, rel: str) -> bool:
        """확인된 부재만 참이다 — 상위 폴더 권한처럼 있는지 모르는 경우는 거짓(못 읽음으로 센다). 끊긴 링크도 있는 것이다."""
        try:
            os.lstat(os.path.join(self.root, rel))
        except (FileNotFoundError, NotADirectoryError):
            return True
        except OSError:
            return False
        return False

    def specs_for(self, source: str, specs_dir: str) -> list:
        """설계문서 폴더(로드맵 레포 설정)의 `*.md` 중 frontmatter `source_interview` 가 source 인 (경로, 글)."""
        d = specs_dir.rstrip("/")
        if d not in self._specs:
            found, unread = [], []
            try:
                names = sorted(os.listdir(os.path.join(self.root, *d.split("/"))))
            except FileNotFoundError:   # 폴더가 없다 — 설계문서가 아직 없다
                names = []
            except OSError:   # 폴더를 못 읽었다 — 어느 묶음의 설계문서가 있는지 모른다
                names, unread = [], [d + "/"]
            for name in names:
                if not name.endswith(".md"):
                    continue
                rel = d + "/" + name
                text = self.read(rel)
                if text is not None:
                    found.append((rel, unquote(frontmatter(text).get("source_interview", "")), text))
                else:
                    unread.append(rel)
            self._specs[d] = found
            self._unread[d] = unread
        return [(rel, text) for rel, src, text in self._specs[d] if src == source]

    def unreadable_specs(self, specs_dir: str, source=None) -> list:
        """`specs_for` 가 읽지 못해 어느 묶음의 것인지 모르는 설계문서들(그 폴더를 한 번 훑은 뒤). 못 읽은 글은 어느
        묶음의 것인지 모르므로 source 와 상관없이 폴더 전부다."""
        return list(self._unread.get(specs_dir.rstrip("/"), []))


def find_repo(bundle_path: str, roadmap_rel: str):
    """묶음 파일의 디렉토리부터 위로 — `<조상>/<roadmap_rel>` 이 파일인 첫 조상을 레포 루트로 쓴다."""
    if not roadmap_rel:
        return None
    here = Path(os.path.abspath(bundle_path)).parent
    for anc in [here, *here.parents]:
        if (anc / roadmap_rel).is_file():
            return Repo(str(anc))
    return None


def _cells(row: str) -> list:
    if not (row.startswith("|") and row.endswith("|")):
        raise FormatError("표 행이 | 로 시작하고 끝나지 않는다: %r" % row)
    return [c.strip() for c in row[1:-1].split("|")]


def table_rows(spec_text: str) -> list:
    """`## 번호 대조` 표의 (번호 목록, 처리, 셋째 칸) 행들. 절이 없거나 표가 깨졌으면 FormatError."""
    body = section_body(spec_text, TABLE_HEADING)
    if body is None:
        raise FormatError("spec 에 `## 번호 대조` 절이 없다")
    rows = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    if len(rows) < 3:
        raise FormatError("번호 대조 표가 없거나 데이터 행이 없다")
    if len(_cells(rows[0])) != 3:
        raise FormatError("번호 대조 표 머리 행이 칸 셋이 아니다")
    sep = _cells(rows[1])
    if len(sep) != 3 or not all(SEP_CELL_RE.fullmatch(c) for c in sep):
        raise FormatError("번호 대조 표 구분 행이 칸 셋이 아니다")
    out = []
    for row in rows[2:]:
        cells = _cells(row)
        if len(cells) != 3:
            raise FormatError("번호 대조 표 행이 칸 셋이 아니다: %r" % row)
        if not (cells[1].startswith("반영") or cells[1].startswith("기각")):
            raise FormatError("둘째 칸이 반영/기각이 아니다: %r" % row)
        if not cells[2]:
            raise FormatError("셋째 칸(자리 또는 이유)이 비었다: %r" % row)
        out.append((parse_ids(cells[0]), cells[1], cells[2]))
    return out


def table_ids(spec_text: str) -> set:
    """`## 번호 대조` 표의 첫 칸 번호 전부."""
    out = set()
    for ids, _verb, _cell in table_rows(spec_text):
        out.update(ids)
    return out


def _outside_fences(text: str):
    in_fence = False
    for line in text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if not in_fence:
            yield line


def _lead_digits(text: str) -> str:
    digits = ""
    for ch in text:
        if ch not in "0123456789":
            break
        digits += ch
    return digits


def design_sections(spec_text: str) -> dict:
    """펜스 밖 `### §<n>` 또는 `## <n>.` 절마다 본문 줄 — {n: [줄]}. 다음 `## ` · `### ` 제목에서 끝난다.
    `## <n>.` 꼴에서는 `### <n>.<m>` 하위 제목이 그 절의 본문을 끝낸다 — `§<n>-<m>` 으로 풀지 않는다."""
    out, cur = {}, None
    for line in _outside_fences(spec_text):
        if line.startswith("## ") or line.startswith("### "):
            cur = None
            if line.startswith("### §"):
                digits = _lead_digits(line[len("### §"):])
            elif line.startswith("## "):
                head = line[3:]
                digits = _lead_digits(head)
                digits = digits if head[len(digits):len(digits) + 1] == "." else ""
            else:
                digits = ""
            if digits:
                cur = out.setdefault(int(digits), [])
            continue
        if cur is not None:
            cur.append(line)
    return out


def heading_parts(spec_text: str) -> set:
    """펜스 밖 `## ` 제목 전체와 ` / ` · ` · ` 로 나눈 조각들(`## 번호 대조` 는 빼고)."""
    parts = set()
    for line in _outside_fences(spec_text):
        if not line.startswith("## ") or line.rstrip() == TABLE_HEADING:
            continue
        title = line[3:].strip()
        if not title:
            continue
        parts.add(title)
        for sep in (" / ", " · "):
            parts.update(p.strip() for p in title.split(sep) if p.strip())
    return parts


def _word_char(ch: str) -> bool:
    return ch.isalnum() or ch == "_"


def has_word(cell: str, word: str) -> bool:
    """cell 안에 word 가 글자 · 숫자 경계로 있는가(「Goals」는 「Goals —」에 맞고 「Goalsx」에 안 맞는다)."""
    start = 0
    while True:
        i = cell.find(word, start)
        if i < 0:
            return False
        j = i + len(word)
        if (i == 0 or not _word_char(cell[i - 1])) and (j == len(cell) or not _word_char(cell[j])):
            return True
        start = i + 1


def acceptance_ids(spec_text: str):
    """`## Acceptance Criteria` 항목 머리의 AC 번호(등장 순서, 중복 제거). 절이 없으면 None."""
    body = section_body(spec_text, AC_HEADING)
    if body is None:
        return None
    out = []
    for line in body.splitlines():
        m = AC_ITEM_RE.match(line)
        if m and "AC" + m.group(1) not in out:
            out.append("AC" + m.group(1))
    return out


def location_problem(cell: str, sections: dict, acs: list, parts: set):
    """반영 칸의 자리 표기 문제 — 없으면 None, 있으면 사유."""
    found, absent = False, []
    for m in SECTION_TOKEN_RE.finditer(cell):
        found = True
        body = sections.get(int(m.group(1)))
        sub = m.group(2)
        if body is None or (sub is not None and not any(l.startswith("%d. " % int(sub)) for l in body)):
            absent.append(m.group(0))
    for m in AC_TOKEN_RE.finditer(cell):
        found = True
        if "AC" + m.group(1) not in acs:
            absent.append("AC" + m.group(1))
    if any(has_word(cell, p) for p in parts):
        found = True
    if absent:
        return "가리킨 자리가 설계문서에 없다: " + " · ".join(absent)
    if not found:
        return "가리킨 자리가 없다"
    return None


def _is_s(token: str) -> bool:
    return token.startswith("S") and token[1:].isdigit()


def _roadmap_view(fm: dict, repo):
    """(view, 사유). view 는 {"blocks", "rel", "errors", "specs_dir"} — 로드맵을 못 읽으면 None 과 사유."""
    rel = unquote(fm.get("roadmap", ""))
    if not rel:
        return None, "묶음 frontmatter 에 roadmap 이 없다"
    if repo is None:
        return None, "로드맵을 찾지 못했다: %s" % rel
    text = repo.read(rel)
    if text is None:
        return None, "로드맵을 못 읽었다: %s" % rel
    meta, blocks, _records, _risk, errors = parse_roadmap(text)
    if errors:
        return None, "로드맵 형식이 깨졌다: %s" % errors[0]
    _bundles, _union, errs = collect_assigned(blocks, meta, rel, repo.read, repo.exists)
    specs_dir = getattr(repo, "specs_dir", None)   # 부르는 쪽(상태 계산)이 해결자로 이미 정한 폴더
    if specs_dir is None:
        try:
            settings = resolve(repo.root, roadmap=rel, roadmap_text=text)
        except SettingsError as exc:
            return None, "레포 설정을 읽지 못했다: %s" % exc
        for line in settings["notices"]:
            print("[spec-distill] " + line, file=sys.stderr)
        if settings["errors"]:
            return None, "레포 설정이 깨졌다: %s" % settings["errors"][0]
        specs_dir = settings["values"]["specs_dir"]
    return {"blocks": blocks, "rel": rel, "errors": errs, "specs_dir": specs_dir}, None


def _block_specs(block: dict, view: dict, repo):
    """(그 블록의 작업 트리 설계문서 [(경로, 글)], 못 읽은 설계문서 경로들)."""
    if block["kind"] == "branch":
        rel = block["fields"].get("spec", "").strip().strip("`")
        if not rel:
            return [], []
        text = repo.read(rel)
        if text is not None:
            return [(rel, text)], []
        return [], ([] if repo.absent(rel) else [rel])   # 확인된 부재만 「아직 없음」 — 그 밖은 못 읽음
    if block["kind"] == "bundle":
        rdir = view["rel"].rsplit("/", 1)[0] if "/" in view["rel"] else "."
        source = rdir + "/" + block["fields"]["묶음"]
        found = repo.specs_for(source, view["specs_dir"])
        return found, repo.unreadable_specs(view["specs_dir"], source)
    return [], []


def _serves(block: dict, s: str, view: dict, repo, epic: str):
    """다른 블록이 S 를 받드는가 — 배정됐고, 그 블록의 설계문서가 그 S 를 기각하지 않았다(N17).

    -> (True | False | None, 사유). None 은 셀 수 없음이다 — 설계문서를 못 읽었거나 번호 대조 표가 깨져 그 블록이 S 를
    기각했는지 모른다. 받든다고 치지 않는다."""
    if block["id"] == epic or s not in block.get("assigned", []):
        return False, None
    found, unread = _block_specs(block, view, repo)
    broken = None
    for rel, text in found:   # 읽힌 문서의 분명한 기각이 먼저다 — 못 읽은 다른 문서가 그 기각을 셀 수 없음으로 내리지 않는다
        try:
            if section_body(text, TABLE_HEADING) is None:   # 번호 대조 절이 없는 설계문서 — 기각 기록이 없다(깨진 표가 아니다)
                continue
            rows = table_rows(text)   # 절이 둘 이상인 것도 깨진 표다(section_body 가 던진다)
        except FormatError as exc:
            broken = broken or "%s 의 설계문서 번호 대조 표를 읽지 못했다(%s): %s" % (block["id"], rel, exc)
            continue
        if any(s in ids and verb.startswith("기각") for ids, verb, _cell in rows):
            return False, None
    if broken:
        return None, broken
    if unread:
        return None, "%s 의 설계문서를 못 읽었다: %s" % (block["id"], unread[0])
    return True, None


def _unchecked(reason: str) -> dict:
    return {"status": 3, "mode": None, "missing": [], "extra": [], "shallow": [], "unserved": [],
            "unknown": [], "bundle_count": None, "table_count": None, "reason": reason}


def check(bundle_text: str, spec_text: str, *, audit_text=None, repo=None) -> dict:
    """정답 출처의 번호 중 표에 없는 번호(missing) · 얕은 답 · 받드는 에픽 없는 발화 · 셀 수 없음."""
    fm = frontmatter(bundle_text)
    mode = "brief" if unquote(fm.get("type", "")) == "interview-brief" else "bundle"
    try:
        if mode == "brief":
            if audit_text is None:
                raise FormatError("brief 또는 audit 을 못 읽었다")
            non_s, s_ids, _k = brief_universe(bundle_text, audit_text)
            want = sorted(non_s | s_ids, key=id_sort_key)
        else:
            want = bundle_ids(bundle_text)
        rows = table_rows(spec_text)
        acs = acceptance_ids(spec_text) or []
    except FormatError as exc:
        return _unchecked(str(exc))
    have = set()
    for ids, _verb, _cell in rows:
        have.update(ids)
    seen, missing = set(), []
    for token in want:
        if token not in have and token not in seen:
            missing.append(token)
        seen.add(token)
    extra = sorted(have - seen, key=id_sort_key)
    sections, parts = design_sections(spec_text), heading_parts(spec_text)
    view, note = _roadmap_view(fm, repo) if mode == "bundle" else (None, None)
    epic = unquote(fm.get("epic", ""))
    shallow, unserved, unknown = [], [], []
    for ids, verb, cell in rows:
        if verb.startswith("반영"):
            why = location_problem(cell, sections, acs, parts)
            if why:
                shallow += [{"id": t, "reason": why} for t in ids]
            continue
        if mode != "bundle":
            continue
        known = {b["id"] for b in view["blocks"]} if view is not None else None
        epics = epic_refs(cell, known)
        rejected_s = [t for t in ids if _is_s(t) and t in seen]
        if view is None:
            targets = list(ids) if epics else rejected_s
            unknown += ["%s — %s" % (t, note) for t in targets]
            continue
        absent = [e for e in epics if e not in known]
        if absent:
            shallow += [{"id": t, "reason": "넘긴 에픽이 로드맵에 없다: " + " · ".join(absent)} for t in ids]
        for s in rejected_s:
            verdicts = [_serves(b, s, view, repo, epic) for b in view["blocks"]]
            if any(v is True for v, _why in verdicts):
                continue
            unread = [why for v, why in verdicts if v is None]
            if unread:
                unknown.append("%s — %s" % (s, unread[0]))
            elif view["errors"]:
                unknown.append("%s — 로드맵의 묶음을 다 읽지 못했다: %s" % (s, view["errors"][0]))
            else:
                unserved.append(s)
    return {"status": 1 if missing else 0, "mode": mode, "missing": missing, "extra": extra,
            "shallow": shallow, "unserved": unserved, "unknown": unknown,
            "bundle_count": len(seen), "table_count": len(have), "reason": None}


DEFER_HEADING = "## 미룸"
REPORT_HEAD_RE = re.compile(r"AC\d+:")
REPORT_LINE_RE = re.compile(r"AC(\d+): (구현됨|미룸|빠짐) — (\S.*)")
VERDICTS = ("구현됨", "미룸", "빠짐")


def _says_none(line: str) -> bool:
    """표 없는 미룸 절의 한 줄이 「미룬 것 없음」만 말하나. 번호 토큰이나 「미룸」이 든 줄은 아니다."""
    if "미룸" in line or any(ch.isdigit() and i > 0 and (line[i - 1] in "#PR" or line[i - 2:i] == "AC")
                            for i, ch in enumerate(line)):
        return False
    for head in ("없음", "미룬 것 없음"):
        if line == head or line.startswith(head + " — "):
            return True
    return False


def deferred_rows(spec_text: str) -> list:
    """`## 미룸` 표의 (항목, 이유, 받는 곳) 행들. 절이 없거나 「없음」뿐이면 []. 표가 깨졌으면 FormatError."""
    body = section_body(spec_text, DEFER_HEADING)
    if body is None:
        return []
    rows = [l.strip() for l in body.splitlines() if l.strip().startswith("|")]
    if not rows:
        rest = [l.strip().lstrip("-*").strip().rstrip(".。!").strip() for l in body.splitlines() if l.strip()]
        if all(_says_none(r) for r in rest):
            return []
        raise FormatError("`## 미룸` 절에 표가 없다")
    if len(rows) < 2 or len(_cells(rows[0])) != 3:
        raise FormatError("`## 미룸` 표 머리 행이 칸 셋이 아니다")
    if _cells(rows[0]) != ["항목", "이유", "받는 곳"]:
        raise FormatError("`## 미룸` 표 머리 행이 항목 · 이유 · 받는 곳 순서가 아니다: %r" % rows[0])
    sep = _cells(rows[1])
    if len(sep) != 3 or not all(SEP_CELL_RE.fullmatch(c) for c in sep):
        raise FormatError("`## 미룸` 표 구분 행이 칸 셋이 아니다")
    out = []
    for row in rows[2:]:
        cells = _cells(row)
        if len(cells) != 3 or not all(cells):
            raise FormatError("`## 미룸` 표 행이 빈칸 없는 칸 셋이 아니다: %r" % row)
        out.append((cells[0], cells[1], cells[2].strip("`").strip()))
    return out


def plan_task_text(plan_text: str) -> str:
    """`### Task` 절들(머리 줄 포함)을 이어 붙인 글. 펜스 안 줄은 절 경계가 아니지만 본문에는 든다."""
    out, on, in_fence = [], False, False
    for line in plan_text.splitlines():
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        elif not in_fence and (line.startswith("## ") or line.startswith("### ")):
            on = line.startswith("### Task")
        if on:
            out.append(line)
    return "\n".join(out)


def _acs_or_error(spec_text: str) -> list:
    acs = acceptance_ids(spec_text)
    if acs is None:
        raise FormatError("설계문서에 `## Acceptance Criteria` 절이 없다")
    if not acs:
        raise FormatError("`## Acceptance Criteria` 절에 AC 항목이 없다")
    return acs


SCOPE_MARK = " · --acs 로 고른 것 · 뺀 AC %d개"


def _plan_unchecked(reason: str) -> dict:
    return {"status": 3, "missing": [], "ac_count": None, "scoped": False, "omitted": 0, "reason": reason}


def _only(acs: list, only):
    """(고른 AC, 사유). 설계문서에 없는 AC 를 고르면 사유."""
    if only is None:
        return acs, None
    absent = [a for a in only if a not in acs]
    if absent:
        return None, "설계문서에 없는 AC 를 --acs 에 적었다: %s" % " · ".join(absent)
    return [a for a in acs if a in only], None


def check_plan(spec_text: str, plan_text: str, only=None) -> dict:
    try:
        acs = _acs_or_error(spec_text)
    except FormatError as exc:
        return _plan_unchecked(str(exc))
    total = len(acs)
    acs, why = _only(acs, only)
    if why:
        return _plan_unchecked(why)
    have = {"AC" + m.group(1) for m in AC_TOKEN_RE.finditer(plan_task_text(plan_text))}
    missing = [a for a in acs if a not in have]
    return {"status": 1 if missing else 0, "missing": missing, "ac_count": len(acs),
            "scoped": only is not None, "omitted": total - len(acs), "reason": None}


def render_plan(r: dict) -> str:
    if r["status"] == 3:
        return "계획 대조 검사 불가 — %s" % r["reason"]
    scope = SCOPE_MARK % r["omitted"] if r.get("scoped") else ""
    if r["missing"]:
        return "계획 대조: 계획에 없는 AC %d개 — %s (AC %d개%s)" % (
            len(r["missing"]), " · ".join(r["missing"]), r["ac_count"], scope)
    return "계획 대조: 계획에 없는 AC 없음 (AC %d개%s)" % (r["ac_count"], scope)


def parse_report(text: str) -> dict:
    """{AC: (판정, 한 줄)}. `AC<n>:` 로 시작하는데 형식이 다르거나 같은 AC 가 두 번이면 FormatError."""
    out = {}
    for line in text.splitlines():
        s = line.strip()
        if s.startswith("- ") or s.startswith("* "):
            s = s[2:].strip()
        if not REPORT_HEAD_RE.match(s):
            continue
        m = REPORT_LINE_RE.fullmatch(s)
        if not m:
            raise FormatError("보고 줄이 `AC<n>: 구현됨|미룸|빠짐 — <한 줄>` 이 아니다: %r" % s)
        ac = "AC" + m.group(1)
        if ac in out:
            raise FormatError("보고에 %s 가 두 번 있다" % ac)
        out[ac] = (m.group(2), m.group(3))
    return out


def _impl_unchecked(reason: str) -> dict:
    return {"status": 3, "unreported": [], "unlisted": [], "no_receiver": [], "dropped": [],
            "receiver_unknown": [], "unknown_acs": [], "counts": None, "ac_count": None,
            "receiver_rule": None, "scoped": False, "omitted": 0, "reason": reason}


def check_impl(spec_text: str, report_text: str, only=None, epic_ids=None, receiver_problem=None) -> dict:
    try:
        all_acs = _acs_or_error(spec_text)
        report = parse_report(report_text)
        if not report:
            raise FormatError("보고에 AC 판정 줄이 없다")
        deferred = deferred_rows(spec_text)
    except FormatError as exc:
        return _impl_unchecked(str(exc))
    acs, why = _only(all_acs, only)
    if why:
        return _impl_unchecked(why)
    listed = {"AC" + m.group(1) for item, _why, _recv in deferred for m in AC_TOKEN_RE.finditer(item)}
    judged = [a for a in acs if a in report]
    if epic_ids is not None:
        no_receiver = [item for item, _why, recv in deferred if not receiver_ok(recv, epic_ids)]
        rule = "로드맵의 에픽 또는 PR 번호(#숫자) — 작업 트리의 로드맵으로 쟀다"
    else:
        no_receiver = [item for item, _why, recv in deferred if recv == "없음"]
        rule = "로드맵 없음 — 「없음」만 받는 곳 없음으로 센다"
    return {
        "status": 0, "reason": None, "ac_count": len(acs), "receiver_rule": rule,
        "scoped": only is not None, "omitted": len(all_acs) - len(acs),
        "unreported": [a for a in acs if a not in report],
        "unlisted": ["%s(%s)" % (a, report[a][0]) for a in judged
                     if report[a][0] != "구현됨" and a not in listed],
        "no_receiver": no_receiver,
        "receiver_unknown": [receiver_problem] if receiver_problem else [],
        "dropped": ["%s: %s" % (a, report[a][1]) for a in judged if report[a][0] == "빠짐"],
        "unknown_acs": sorted((a for a in report if a not in all_acs), key=lambda a: int(a[2:])),
        "counts": {v: sum(1 for a in judged if report[a][0] == v) for v in VERDICTS},
    }


IMPL_GROUPS = (("보고에 없는 AC", "unreported"), ("미룸 표에 없는 미룸/빠짐", "unlisted"),
               ("받는 곳 없는 미룸", "no_receiver"), ("받는 곳 검사 불가", "receiver_unknown"),
               ("빠짐", "dropped"))


def receiver_ids(spec_path: str, spec_text: str):
    """(로드맵 에픽 번호 집합, 사유). 설계문서에 `roadmap:` 이 없으면 (None, None) — 로드맵 없는 설계다."""
    rel = unquote(frontmatter(spec_text).get("roadmap", ""))
    if not rel:
        return None, None
    repo = find_repo(spec_path, rel)
    if repo is None:
        return None, "로드맵을 찾지 못했다: %s" % rel
    text = repo.read(rel)
    if text is None:
        return None, "로드맵을 못 읽었다: %s" % rel
    _meta, blocks, _records, _risk, errors = parse_roadmap(text)
    if errors:
        return None, "로드맵 형식이 깨졌다: %s" % errors[0]
    return {b["id"] for b in blocks}, None


def _impl_status(r: dict) -> dict:
    if r["status"] != 3:
        r["status"] = 1 if any(r[k] for _label, k in IMPL_GROUPS) else 0
    return r


def render_impl(r: dict) -> str:
    if r["status"] == 3:
        return "구현 대조 검사 불가 — %s" % r["reason"]
    n = sum(len(r[k]) for _label, k in IMPL_GROUPS)
    if n:
        lines = ["구현 대조: 경고 %d개 — %s"
                 % (n, " · ".join("%s %d개" % (label, len(r[k])) for label, k in IMPL_GROUPS))]
        if r["scoped"]:
            lines[0] += " (%s)" % SCOPE_MARK[3:] % r["omitted"]
        lines += ["%s — %s" % (label, " · ".join(r[k])) for label, k in IMPL_GROUPS if r[k]]
        if r["dropped"]:
            lines.append("빠짐은 머지 전에 고치거나 사용자가 미룸으로 옮긴다(설계문서 `## 미룸` 표).")
        lines.append("(받는 곳 규칙: %s)" % r["receiver_rule"])
    else:
        c = r["counts"]
        scope = SCOPE_MARK % r["omitted"] if r["scoped"] else ""
        lines = ["구현 대조: 경고 없음 (AC %d개 · 구현됨 %d개 · 미룸 %d개%s) (받는 곳 규칙: %s)"
                 % (r["ac_count"], c["구현됨"], c["미룸"], scope, r["receiver_rule"])]
    if r["unknown_acs"]:
        lines.append("정보: 설계문서에 없는 AC 가 보고에 있다 — %s" % " · ".join(r["unknown_acs"]))
    return "\n".join(lines)


def _two_files(first: str, second: str, fn, unchecked) -> dict:
    texts = []
    for path in (first, second):
        text, exc = _read(path)
        if text is None:
            return unchecked("파일을 못 읽었다: %s (%s)" % (path, exc))
        texts.append(text)
    try:
        return fn(texts[0], texts[1])
    except Exception as exc:  # 검사 자체가 죽어도 이상 없음(0)으로 내지 않는다
        return unchecked("내부 오류 — %s: %s" % (type(exc).__name__, exc))


def warning_count(result: dict) -> int:
    """spec-review 게이트의 「경고 N개」에 더할 수 — 검사 불가는 1."""
    if result.get("status") == 3:
        return 1
    return sum(len(result[k]) for k in ("missing", "shallow", "unserved", "unknown"))


def render(result: dict) -> str:
    if result["status"] == 3:
        return "번호 대조 검사 불가 — %s" % result["reason"]
    brief = result.get("mode") == "brief"
    m, sh, un, uk = (result[k] for k in ("missing", "shallow", "unserved", "unknown"))
    if not (m or sh or un or uk):
        lines = ["번호 대조: 빠진 번호 없음 (%s %d개 · 표 번호 %d개)"
                 % ("brief 번호" if brief else "묶음 번호", result["bundle_count"], result["table_count"])]
    else:
        head = "번호 대조: 빠진 번호 %d개 · 얕은 답 %d개 · 받드는 에픽 없는 발화 %d개" % (len(m), len(sh), len(un))
        if uk:
            head += " · 셀 수 없음 %d개" % len(uk)
        lines = [head]
        if m:
            lines.append("빠진 번호 %d개 — %s" % (len(m), " · ".join(m)))
        lines += ["얕은 답 — %s: %s" % (s["id"], s["reason"]) for s in sh]
        lines += ["받드는 에픽 없는 발화 — %s: 이 설계문서가 기각했는데 로드맵의 다른 에픽이 받들지 않는다" % s
                  for s in un]
        lines += ["셀 수 없음 — %s" % u for u in uk]
    if result["extra"]:
        lines.append("정보: %s 없는 번호 %d개가 표에 있다 — %s"
                     % ("brief 에" if brief else "묶음에", len(result["extra"]), " · ".join(result["extra"])))
    return "\n".join(lines)


def _read(path: str):
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read(), None
    except (OSError, UnicodeDecodeError) as exc:
        return None, exc


def coverage(first_path: str, spec_path: str) -> dict:
    """번호 대조 한 번 — 파일을 읽고, brief 면 옆 audit 을, 묶음이면 로드맵이 있는 레포를 찾아 check 를 부른다."""
    texts = []
    for path in (first_path, spec_path):
        text, exc = _read(path)
        if text is None:
            return _unchecked("파일을 못 읽었다: %s (%s)" % (path, exc))
        texts.append(text)
    try:
        fm = frontmatter(texts[0])
        if unquote(fm.get("type", "")) == "interview-brief":
            audit = _read(first_path[:-3] + ".audit.md")[0] if first_path.endswith(".md") else None
            return check(texts[0], texts[1], audit_text=audit)
        return check(texts[0], texts[1], repo=find_repo(first_path, unquote(fm.get("roadmap", ""))))
    except Exception as exc:  # 검사 자체가 죽어도 이상 없음(0)으로 내지 않는다
        return _unchecked("내부 오류 — %s: %s" % (type(exc).__name__, exc))


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    ap = argparse.ArgumentParser(prog="check_bundle_coverage.py",
                                 description="정답 출처의 번호와 설계문서 AC 를 설계문서 · 계획 · 구현 보고와 맞춘다.")
    mode = ap.add_mutually_exclusive_group()
    mode.add_argument("--plan", action="store_true", help="<설계문서> <계획>: 계획 Task 절에 없는 AC")
    mode.add_argument("--impl", action="store_true", help="<설계문서> <보고 파일>: 구현 보고의 미룸 · 빠짐")
    ap.add_argument("first", help="묶음 · brief(기본) 또는 설계문서(--plan · --impl)")
    ap.add_argument("second", help="설계문서(기본) · 계획(--plan) · 보고 파일(--impl)")
    ap.add_argument("--acs", help="--plan · --impl 에서 그 AC 만 대조한다(예: AC1~AC14 · AC39)")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    only = None
    if args.acs is not None:
        if not (args.plan or args.impl):
            ap.error("--acs 는 --plan · --impl 과만 쓴다")
        try:
            only = parse_acs(args.acs)
        except FormatError as exc:
            ap.error(str(exc))
    if args.plan:
        result = _two_files(args.first, args.second, lambda s, p: check_plan(s, p, only), _plan_unchecked)
        text = render_plan(result)
    elif args.impl:
        def impl(spec_text, report_text):
            ids, problem = receiver_ids(args.first, spec_text)
            return check_impl(spec_text, report_text, only, ids, problem)
        result = _impl_status(_two_files(args.first, args.second, impl, _impl_unchecked))
        text = render_impl(result)
    else:
        result = coverage(args.first, args.second)
        text = render(result)
    print(json.dumps(result, ensure_ascii=False) if args.json else text)
    return result["status"]


if __name__ == "__main__":
    sys.exit(main())
