#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_write.py — team 형식 생성기의 몸. `roadmap_write.py` 가 자기 모듈 객체(W)를 넘겨 부른다.

W 에서 Refused · Usage · Txn · run_txn · git_top · rel · read 를 쓴다. 이 모듈은 roadmap_write 를 import 하지 않는다 —
스크립트로 돌 때 그 모듈은 `__main__` 이라 다시 import 하면 예외 클래스가 갈려 main 이 잡지 못한다.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import brief_body  # noqa: E402
import repo_defaults  # noqa: E402
import section6  # noqa: E402
import team_check  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402
from roadmap_model import frontmatter, unquote  # noqa: E402

PREFIX = "[spec-distill] "
NO_FRAMING = "framing audit 없음"
FRAMING_TYPE = "interview-seed-audit"
FRAMING_HEADS = ("## 1. 원문", "## 2. 질문 전체", "## 3. 긴 초안")   # 원문 · 질문 전체 구간의 경계 줄(문자열 비교)
UNCOMMITTED = "출처 파일에 커밋되지 않은 변경이 있다: %s — 먼저 커밋한 뒤 다시 돈다"
NOT_HERE = ".claude"


# ── 자리 ─────────────────────────────────────────────────────────────────────

def team_for(top: Path, roadmap_dir: Path, W):
    """로드맵 폴더(--out)의 Team. 해결자의 roadmaps_dir 바로 아래가 아니거나 · 역할 이름이거나 · `.claude` 아래면 Refused."""
    try:
        result = repo_defaults.resolve(str(top))
    except repo_defaults.SettingsError as exc:
        raise W.Refused("레포 설정을 읽지 못해 로드맵 폴더를 정하지 못했다 — %s" % exc)
    if result["errors"]:
        raise W.Refused("레포 설정을 읽지 못해 로드맵 폴더를 정하지 못했다 — %s" % result["errors"][0])
    roadmaps_dir = result["values"]["roadmaps_dir"]
    rel_dir = W.rel(top, roadmap_dir)
    if NOT_HERE in rel_dir.split("/") or NOT_HERE in roadmaps_dir.split("/"):
        raise W.Refused("%s 아래에는 쓰지 않는다 — %s (로드맵 폴더 %s)" % (NOT_HERE, rel_dir, roadmaps_dir))
    try:
        return team_layout.team_from_roadmap(roadmaps_dir, rel_dir + "/" + team_layout.ROADMAP_FILE)
    except ValueError as exc:
        raise W.Refused("팀 폴더는 로드맵 폴더(%s) 바로 아래 한 단계다 — %s" % (roadmaps_dir, exc))


# ── 출처 ─────────────────────────────────────────────────────────────────────

def _committed(top: Path, rel: str, W) -> tuple:
    """(커밋, 바이트). 마지막 커밋의 바이트가 작업 트리와 다르거나 커밋된 적이 없으면 Refused."""
    try:
        work = (top / rel).read_bytes()
    except OSError as exc:
        raise W.Refused("못 읽었다: %s (%s)" % (rel, exc))
    rc, out = team_check.git_bytes(top, "log", "-1", "--format=%H", "--", rel)
    commit = out.decode("utf-8", "replace").strip() if rc == 0 else ""
    if not commit or team_check.show(top, commit, rel) != work:
        raise W.Refused(UNCOMMITTED % rel)
    return commit, work


def _decoded(rel: str, data: bytes, W) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise W.Refused("UTF-8 로 읽지 못했다: %s (%s)" % (rel, exc))


def _framing_from_state(top: Path, state_rel: str, W):
    """상태 파일의 seed 가 가리키는 framing audit(레포 상대), 못 찾으면 None."""
    state = top / state_rel
    if not state.is_file():
        return None
    seed = unquote(frontmatter(W.read(state)).get("seed", "").strip())
    if not seed or seed == "없음":
        return None
    seed_path = top / seed
    if not seed_path.is_file():
        return None
    name = unquote(frontmatter(W.read(seed_path)).get("audit_file", "").strip())
    if not name and seed_path.name.endswith(".md"):
        name = seed_path.name[:-3] + ".audit.md"
    if not name:
        return None
    if "/" in name or name in (".", ".."):
        raise W.Refused("seed 의 audit_file 은 seed 와 같은 폴더의 파일 이름이다: %s (%r)" % (seed, name))
    found = seed_path.parent / name
    return W.rel(top, found) if found.is_file() else None


def _framing_parts(rel: str, data: bytes, W) -> list:
    """[(절 이름, 첫 줄 번호, 줄들)] — 원문은 첫 경계 줄부터 둘째 앞까지, 질문 전체는 둘째부터 셋째 앞까지."""
    lines = team_files.byte_lines(data)
    bare = [(line[:-1] if line.endswith(b"\n") else line).decode("utf-8") for line in lines]
    bare = [b[:-1] if b.endswith("\r") else b for b in bare]
    at = []
    for head in FRAMING_HEADS:
        hits = [i for i, b in enumerate(bare) if b == head]
        if len(hits) != 1:
            raise W.Refused("%s: `%s` 줄이 %d개다(%s) — 한 번씩 있어야 원문 · 질문 전체 구간을 정한다"
                            % (rel, head, len(hits), " · ".join("%d행" % (i + 1) for i in hits) or "없음"))
        at.append(hits[0])
    if not at[0] < at[1] < at[2]:
        raise W.Refused("%s: %s 줄의 순서가 아니다(%s)"
                        % (rel, " · ".join(FRAMING_HEADS), " · ".join("%d행" % (i + 1) for i in at)))
    return [(team_files.LABELS[0], at[0] + 1, lines[at[0]:at[1]]),
            (team_files.LABELS[1], at[1] + 1, lines[at[1]:at[2]])]


def _user_words(rel: str, data: bytes, W) -> tuple:
    """(첫 줄 번호, 줄들, 발화 번호 집합) — `section6.span` 의 start 부터 end 앞까지의 줄."""
    text = _decoded(rel, data, W)
    sp = section6.span(text)
    if sp is None:
        raise W.Refused("%s: 사용자 원문 절(§6)을 하나로 읽지 못했다 — 없거나 경계가 모호하다" % rel)
    start, body_start, end = sp
    first = text.count("\n", 0, start) + 1
    last = text.count("\n", 0, end) + (1 if end == len(text) and not text.endswith("\n") else 0)
    sids = {sid for _n, sid, _rest in brief_body.anchor_lines(text[body_start:end])[0]}
    return first, team_files.byte_lines(data)[first - 1:last], sids


def wanted_sections(top: Path, brief: Path, framing_audit, W) -> list:
    """original.md 에 옮길 구간들 — framing 원문 · framing 질문 전체 · brief §6 · audit §6 순서.
    항목은 team_files.extend_original 의 (source, commit, label, first, lines, note)."""
    brief_rel = W.rel(top, brief)
    if not brief_rel.endswith(".md"):
        raise W.Usage("--brief 는 .md 파일이다: %s" % brief_rel)
    stem = brief_rel[:-3]
    audit_rel = stem + ".audit.md"
    found = _framing_from_state(top, stem + ".state.md", W)
    given = W.rel(top, framing_audit) if framing_audit else None
    if found and given and found != given:
        raise W.Usage("--framing-audit(%s) 이 인터뷰 상태 파일이 가리키는 framing audit(%s) 와 다르다 — 하나만 쓴다"
                      % (given, found))
    framing = found or given
    out, note = [], ""
    if framing:
        commit, data = _committed(top, framing, W)
        kind = unquote(frontmatter(_decoded(framing, data, W)).get("type", ""))
        if kind != FRAMING_TYPE:
            raise W.Refused("%s 는 framing audit 이 아니다 — 머리 type 이 %s 가 아니다(%s)" % (framing, FRAMING_TYPE, kind or "없음"))
        out += [(framing, commit, label, first, lines, "") for label, first, lines in _framing_parts(framing, data, W)]
    else:
        note = NO_FRAMING
    b_commit, b_data = _committed(top, brief_rel, W)
    a_commit, a_data = _committed(top, audit_rel, W)
    b_first, b_lines, b_sids = _user_words(brief_rel, b_data, W)
    a_first, a_lines, a_sids = _user_words(audit_rel, a_data, W)
    out.append((brief_rel, b_commit, team_files.LABELS[2], b_first, b_lines, note))
    if not a_sids <= b_sids:   # audit 의 발화가 모두 brief §6 에 있으면 audit 구간은 같은 말을 두 번 싣는 것이다
        out.append((audit_rel, a_commit, team_files.LABELS[2], a_first, a_lines, note))
    return out


# ── 명령 ─────────────────────────────────────────────────────────────────────

def cmd_original(a, W) -> int:
    out_dir = Path(os.path.realpath(a.out))
    top = W.git_top(out_dir)
    team = team_for(top, out_dir, W)
    wanted = wanted_sections(top, Path(a.brief), a.framing_audit, W)
    target = top / team.original
    for path in (target.parent, target):
        if os.path.islink(str(path)):
            raise W.Refused("심볼릭 링크로는 쓰지 않는다: %s" % path)
    if os.path.lexists(str(target)) and not target.is_file():
        raise W.Refused("원자료 사본 자리가 파일이 아니다: %s" % team.original)
    existing = target.read_bytes() if target.is_file() else b""
    new, notes = team_files.extend_original(existing, wanted)
    if new == existing:
        print(PREFIX + "원자료 사본이 이미 출처와 같다 — 쓰지 않았다: %s" % team.original)
        return 0
    roadmap = top / team.roadmap
    txn = W.Txn()

    def body():
        txn.ensure_dir(target.parent)
        txn.write(target, new.decode("utf-8"))
        if roadmap.exists():
            errors, _unknown, _notes = team_check.check_tree(top, team)
            if errors:
                raise W.Refused("검사 실패 — %s" % " / ".join(errors))

    W.run_txn(txn, body)
    for line in notes:
        print(PREFIX + line)
    added = len(team_files.parse_original(new)) - (len(team_files.parse_original(existing)) if existing else 0)
    print(PREFIX + "원자료 사본을 썼다: %s — 구간 %d개를 끝에 더했다" % (team.original, added))
    return 0
