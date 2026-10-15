#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""check_bundle_coverage.py — 정답 출처(에픽 묶음 · brief)의 번호와 설계문서 `## 번호 대조` 표를 맞춘다.

명령줄: check_bundle_coverage.py <묶음|brief> <설계문서> [--json]
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

`roadmap_status.py` 는 `check(bundle_text, spec_text)` 를 import 해 `git show` 로 읽은 글을 넘기고 status 만 본다.
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
from roadmap_model import (  # noqa: E402,F401 — 이 이름들은 이 모듈의 공개 표면이기도 하다
    FormatError, PREFIX_ORDER, SEP_CELL_RE, SEP_RE, TOKEN_RE, brief_universe, bundle_ids,
    collect_assigned, frontmatter, id_sort_key, parse_ids, parse_roadmap, section_body, unquote)

TABLE_HEADING = "## 번호 대조"
AC_HEADING = "## Acceptance Criteria"
# 자리 표기 — `§<n>` · `§<n>-<m>` · `AC<n>`. 숫자 뒤에 숫자가 이어지면 다른 토큰이다(AC1 ≠ AC10).
SECTION_TOKEN_RE = re.compile(r"§(\d+)(?:-(\d+))?(?!\d)")
AC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])AC(\d+)(?!\d)")
AC_ITEM_RE = re.compile(r"\s*[-*]\s+(?:\*\*)?AC(\d+)(?!\d)")
EPIC_TOKEN_RE = re.compile(r"(?<![A-Za-z0-9])(R\d+[a-z]?|P\d+)(?![A-Za-z0-9])")


class Repo:
    """레포 루트 기준 읽기 — 로드맵 · 다른 묶음 · 작업 트리 설계문서. 읽기만 한다."""

    def __init__(self, root: str):
        self.root = root
        self._specs = None

    def read(self, rel: str):
        try:
            with open(os.path.join(self.root, rel), encoding="utf-8") as fh:
                return fh.read()
        except (OSError, UnicodeDecodeError):
            return None

    def exists(self, rel: str) -> bool:
        return os.path.exists(os.path.join(self.root, rel))

    def specs_for(self, source: str) -> list:
        """`docs/superpowers/specs/*.md` 중 frontmatter `source_interview` 가 source 인 (경로, 글)."""
        if self._specs is None:
            self._specs = []
            try:
                names = sorted(os.listdir(os.path.join(self.root, "docs", "superpowers", "specs")))
            except OSError:
                names = []
            for name in names:
                if not name.endswith(".md"):
                    continue
                rel = "docs/superpowers/specs/" + name
                text = self.read(rel)
                if text is not None:
                    self._specs.append((rel, unquote(frontmatter(text).get("source_interview", "")), text))
        return [(rel, text) for rel, src, text in self._specs if src == source]


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


def design_sections(spec_text: str) -> dict:
    """펜스 밖 `### §<n>` 절마다 본문 줄 — {n: [줄]}. 다음 `## ` · `### ` 제목에서 끝난다."""
    out, cur = {}, None
    for line in _outside_fences(spec_text):
        if line.startswith("## ") or line.startswith("### "):
            cur = None
            if line.startswith("### §"):
                digits = ""
                for ch in line[len("### §"):]:
                    if ch not in "0123456789":
                        break
                    digits += ch
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
    """(view, 사유). view 는 {"blocks", "rel", "errors"} — 로드맵을 못 읽으면 None 과 사유."""
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
    return {"blocks": blocks, "rel": rel, "errors": errs}, None


def _block_specs(block: dict, view: dict, repo) -> list:
    """그 블록의 작업 트리 설계문서 글들."""
    if block["kind"] == "branch":
        rel = block["fields"].get("spec", "").strip().strip("`")
        text = repo.read(rel) if rel else None
        return [text] if text is not None else []
    if block["kind"] == "bundle":
        rdir = view["rel"].rsplit("/", 1)[0] if "/" in view["rel"] else "."
        return [text for _rel, text in repo.specs_for(rdir + "/" + block["fields"]["묶음"])]
    return []


def _serves(block: dict, s: str, view: dict, repo, epic: str) -> bool:
    """다른 블록이 S 를 받드는가 — 배정됐고, 그 블록의 설계문서가 그 S 를 기각하지 않았다(N17)."""
    if block["id"] == epic or s not in block.get("assigned", []):
        return False
    for text in _block_specs(block, view, repo):
        try:
            rows = table_rows(text)
        except FormatError:
            continue
        if any(s in ids and verb.startswith("기각") for ids, verb, _cell in rows):
            return False
    return True


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
        epics = EPIC_TOKEN_RE.findall(cell)
        rejected_s = [t for t in ids if _is_s(t) and t in seen]
        if view is None:
            targets = list(ids) if epics else rejected_s
            unknown += ["%s — %s" % (t, note) for t in targets]
            continue
        known = {b["id"] for b in view["blocks"]}
        absent = [e for e in epics if e not in known]
        if absent:
            shallow += [{"id": t, "reason": "넘긴 에픽이 로드맵에 없다: " + " · ".join(absent)} for t in ids]
        for s in rejected_s:
            if any(_serves(b, s, view, repo, epic) for b in view["blocks"]):
                continue
            if view["errors"]:
                unknown.append("%s — 로드맵의 묶음을 다 읽지 못했다: %s" % (s, view["errors"][0]))
            else:
                unserved.append(s)
    return {"status": 1 if missing else 0, "mode": mode, "missing": missing, "extra": extra,
            "shallow": shallow, "unserved": unserved, "unknown": unknown,
            "bundle_count": len(seen), "table_count": len(have), "reason": None}


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
                                 description="정답 출처(에픽 묶음 · brief)의 번호와 설계문서 번호 대조 표를 맞춘다.")
    ap.add_argument("first", help="에픽 묶음 또는 interview brief")
    ap.add_argument("second", help="설계문서")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args(argv)
    result = coverage(args.first, args.second)
    print(json.dumps(result, ensure_ascii=False) if args.json else render(result))
    return result["status"]


if __name__ == "__main__":
    sys.exit(main())
