#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""team_write.py — team 형식 생성기의 몸. `roadmap_write.py` 가 자기 모듈 객체(W)를 넘겨 부른다.

W 에서 Refused · Usage · Txn · run_txn · git_top · rel · read 를 쓴다. 이 모듈은 roadmap_write 를 import 하지 않는다 —
스크립트로 돌 때 그 모듈은 `__main__` 이라 다시 import 하면 예외 클래스가 갈려 main 이 잡지 못한다.
"""
from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Optional

sys.path.insert(0, str(Path(__file__).resolve().parent))
import brief_body  # noqa: E402
import legacy_names  # noqa: E402
import repo_defaults  # noqa: E402
import roadmap_render as R  # noqa: E402
import section6  # noqa: E402
import seed_review_log  # noqa: E402
import team_check  # noqa: E402
import team_files  # noqa: E402
import team_layout  # noqa: E402
import workflow_superpowers  # noqa: E402
from roadmap_model import BLOCK_ID_RE, frontmatter, parse_roadmap, unquote  # noqa: E402

PREFIX = "[spec-distill] "
NO_FRAMING = "framing audit 없음"
NO_FRAMING_SAID = ("framing 원문 · 질문 전체 없이 brief 쪽 사용자 원문만 옮겼다 — 출처 줄 끝에 `%s` 을 적었다. "
                   "framing 을 거친 컨텍스트 쌓기라면 `original --brief <brief> --out <로드맵 폴더> --framing-audit <경로>` 로 "
                   "덧붙인다" % NO_FRAMING)
FRAMING_TYPE = legacy_names.INTENT_SEED_AUDIT
SEED_NONE = "없음"   # 상태 파일의 seed 값 — framing 을 거치지 않은 컨텍스트 쌓기
FRAMING_LOST = ("상태 파일 %s 의 seed 는 %s 인데 framing audit 를 찾지 못했다 — %s. "
                "framing 원문 · 질문 전체 없이는 원자료 사본을 만들지 않는다. framing audit 의 경로를 "
                "`original --brief <brief> --out <로드맵 폴더> --framing-audit <경로>` 로 주어 원자료 사본을 먼저 만든다"
                "(`create --layout team` 이 멈췄으면 그 뒤에 다시 돈다)")
FRAMING_HEADS = seed_review_log.AUDIT_HEADINGS[:3]   # 원문 · 질문 전체 구간의 경계 줄(문자열 비교) — audit 를 읽는 쪽과 같은 제목
UNCOMMITTED = "출처 파일에 커밋되지 않은 변경이 있다: %s — 먼저 커밋한 뒤 다시 돈다"
NO_COMMIT = "출처 파일의 커밋을 정하지 못했다: %s — git log 종료 코드 %d · 출력 %r 이 커밋 번호가 아니다"
NOT_HERE = ".claude"
_SHA_RE = re.compile(r"[0-9a-f]{40}(?:[0-9a-f]{24})?")
FRONT = "---\ntype: roadmap\n"   # 로드맵 틀의 첫 두 줄 — team 로드맵은 그 뒤에 layout 줄을 넣는다
OLD_HANDOFF = "에픽마다 원본 brief · 이 로드맵 · 에픽 묶음을 넘긴다."
TEAM_HANDOFF = "에픽마다 과제 폴더의 INTENT.md 를 넘긴다."
HAND_FIX = ("손으로 고칠 것 — %s 의 INTENT.md(%s)는 다시 쓰지 않았다. 사용자 승인 뒤 아래대로 고치고 결정 기록에 "
            "`- 결정 · <날짜> · 「…」` 한 줄을 남긴다. 과제 브랜치가 있으면 일꾼이 돌아온 뒤 그 브랜치의 INTENT.md 를, "
            "없으면 이 브랜치의 것을 고친다.")
RANGE_READ = ("지시 원문 범위는 이 브랜치의 INTENT.md 에서 읽는다 — 과제 브랜치의 INTENT.md 를 고쳤으면 그 브랜치가 "
              "이 브랜치에 합쳐진 뒤에 같은 표로 다시 돌아야 0 이다(그 전에는 같은 고칠 글을 다시 내고 종료 코드 4 다)")
EPIC_SHAPED = "%s 은 에픽 번호 꼴이다 — 뒤에 올 에픽의 과제 폴더 자리를 막는다"
FOREIGN = "이 생성기가 만들지 않은 파일은 덮어쓰지 않는다 — %s"
LEFT_FILE = ("%s 가 이미 있다 — 묶음이 아니던 과제 %s 의 자리에 남은 파일이다(앞서 묶음이었다가 그대로 둔 과제 폴더일 수 있다). "
             "덮어쓰지 않는다 — 손으로 옮기거나 지운 뒤 다시 돈다")
LEFT_JOB = "사라진 에픽 %s: 과제 폴더 %s 를 그대로 뒀다 — 필요 없으면 손으로 지운다"
INDENT = "    "
UNCHECKABLE = "검사 불가 — "


def check_screen(unknown: list, notes: list) -> list:
    """team 나무 검사의 검사 불가 줄 · 알림 줄을 화면에 낼 꼴로(머리 PREFIX, 검사 불가는 UNCHECKABLE 을 붙인다)."""
    return [PREFIX + UNCHECKABLE + u for u in unknown] + [PREFIX + n for n in notes]


# ── 자리 ─────────────────────────────────────────────────────────────────────

def roadmaps_dir_of(top: Path, W) -> str:
    """해결자의 roadmaps_dir. 설정을 못 읽으면 Refused."""
    try:
        result = repo_defaults.resolve(str(top))
    except repo_defaults.SettingsError as exc:
        raise W.Refused("레포 설정을 읽지 못해 로드맵 폴더를 정하지 못했다 — %s" % exc)
    if result["errors"]:
        raise W.Refused("레포 설정을 읽지 못해 로드맵 폴더를 정하지 못했다 — %s" % result["errors"][0])
    return result["values"]["roadmaps_dir"]


def team_for(top: Path, roadmap_dir: Path, W):
    """로드맵 폴더(--out)의 Team. 해결자의 roadmaps_dir 바로 아래가 아니거나 · 역할 이름이거나 · `.claude` 아래면 Refused."""
    roadmaps_dir = roadmaps_dir_of(top, W)
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
    rc, out = team_check.git_bytes(top, "log", "-1", "--no-show-signature", "--format=%H", "--", rel)
    commit = out.decode("utf-8", "replace").strip()
    if rc == 0 and not commit:   # 커밋된 적이 없다
        raise W.Refused(UNCOMMITTED % rel)
    if rc != 0 or not _SHA_RE.fullmatch(commit):
        raise W.Refused(NO_COMMIT % (rel, rc, commit[:80]))
    if team_check.show(top, commit, rel) != work:
        raise W.Refused(UNCOMMITTED % rel)
    return commit, work


def _decoded(rel: str, data: bytes, W) -> str:
    try:
        return data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise W.Refused("UTF-8 로 읽지 못했다: %s (%s)" % (rel, exc))


def _framing_from_state(top: Path, state_rel: str, W) -> tuple:
    """(framing audit 의 레포 상대 경로, 못 찾은 사유) — 많아야 하나만 값이다. 상태 파일이 없거나 seed 가 비었거나 「없음」 이면
    framing 을 거치지 않은 컨텍스트 쌓기라 (None, None) 이다. 찾는 자리는 컨텍스트 쌓기가 읽는 자리와 같다 — seed 와 같은 폴더에서
    seed 파일 이름의 `.md` 를 `.audit.md` 로 바꾼 파일. seed 머리의 audit_file 은 읽지 않는다."""
    state = top / state_rel
    if not state.is_file():
        return None, None
    seed = unquote(frontmatter(W.read(state)).get("seed", "").strip())
    if not seed or seed == SEED_NONE:
        return None, None
    if not (top / seed).is_file():
        return None, FRAMING_LOST % (state_rel, seed, "seed 파일 %s 이 없다" % seed)
    if not seed.endswith(".md"):
        return None, FRAMING_LOST % (state_rel, seed, "seed 파일 이름 %s 이 .md 로 끝나지 않아 framing audit 의 이름을 정하지 못한다" % seed)
    named = seed[:-3] + ".audit.md"
    if not (top / named).is_file():
        return None, FRAMING_LOST % (state_rel, seed, "seed 파일 이름으로 정한 자리 %s 에 파일이 없다" % named)
    return W.rel(top, top / named), None


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


def framing_pair(existing: bytes, brief_rel: str):
    """사본에 든 framing 짝의 출처, 없으면 None — 이 brief 의 첫 사용자 원문 구간에 표지 NO_FRAMING 이 없고, 그 바로 앞 두
    구간이 같은 출처의 원문 · 질문 전체 차례일 때만 그 출처다(wanted_sections 가 한 번에 붙이는 차례). 표지가 있으면 그 brief 는
    framing 없이 옮겨졌다는 기록이라 앞의 짝(다른 brief 를 위해 나중에 붙은 것)을 제 것으로 읽지 않는다. 표지 없는 첫 구간은
    framing 구간을 손에 쥐고 붙인 것이라(같은 바이트가 이미 있어 건너뛰었으면 그 구간은 사본의 다른 자리에 있다) 그 brief 의
    framing 원문은 사본에 있다 — 다만 돌려주는 출처가 그 brief 가 받은 audit 와 다를 수 있어 참 · 거짓으로만 쓴다.
    짝이 아니거나 사본을 읽지 못하면 None."""
    try:
        sections = team_files.parse_original(existing) if existing else []
    except team_files.FormatError:
        return None
    first = next((i for i, s in enumerate(sections) if s.source == brief_rel and s.label == team_files.LABELS[2]), None)
    if first is None or first < 2 or NO_FRAMING in sections[first].note.split(" · "):
        return None
    head, questions = sections[first - 2], sections[first - 1]
    if (head.label, questions.label) != team_files.LABELS[:2] or head.source != questions.source:
        return None
    return head.source


def wanted_sections(top: Path, brief: Path, framing_audit, W, existing: bytes = b"") -> list:
    """original.md 에 옮길 구간들 — framing 원문 · framing 질문 전체 · brief §6 · audit §6 순서.
    항목은 team_files.extend_original 의 (source, commit, label, first, lines, note). framing audit 없이 옮기는 구간에는
    표지 NO_FRAMING 을 적는다. 있는 사본(existing)에서 이 brief 의 첫 사용자 원문 구간에 표지 NO_FRAMING 이 없고 그 바로 앞에
    같은 출처의 원문 · 질문 전체 짝이 있으면(framing_pair) framing audit 를 찾지 못해도 멈추지 않고 표지도 적지 않는다 — 원문 없이
    만들지 않는다는 뜻은 사본 안의 짝으로 지켜진다. 그 밖에는 상태 파일의 seed 가 가리키는 framing audit 를 찾지 못하고
    framing_audit 도 없으면 멈춘다."""
    brief_rel = W.rel(top, brief)
    if not brief_rel.endswith(".md"):
        raise W.Usage("--brief 는 .md 파일이다: %s" % brief_rel)
    stem = brief_rel[:-3]
    audit_rel = stem + ".audit.md"
    found, lost = _framing_from_state(top, stem + ".state.md", W)
    given = W.rel(top, framing_audit) if framing_audit else None
    if found and given and found != given:
        raise W.Usage("--framing-audit(%s) 이 컨텍스트 쌓기 상태 파일이 가리키는 framing audit(%s) 와 다르다 — 하나만 쓴다"
                      % (given, found))
    paired = framing_pair(existing, brief_rel)
    if lost and not given and not paired:   # framing 을 거친 컨텍스트 쌓기다 — 그 원문 없이 조용히 가지 않는다
        raise W.Refused(lost)
    framing = found or given
    out, note = [], ""
    if framing:
        commit, data = _committed(top, framing, W)
        kind = unquote(frontmatter(_decoded(framing, data, W)).get("type", ""))
        if not legacy_names.kind_matches(kind, FRAMING_TYPE):
            raise W.Refused("%s 는 framing audit 이 아니다 — 머리 type 이 %s 가 아니다(%s)" % (framing, FRAMING_TYPE, kind or "없음"))
        out += [(framing, commit, label, first, lines, "") for label, first, lines in _framing_parts(framing, data, W)]
    elif not paired:
        note = NO_FRAMING
    b_commit, b_data = _committed(top, brief_rel, W)
    a_commit, a_data = _committed(top, audit_rel, W)
    b_first, b_lines, b_sids = _user_words(brief_rel, b_data, W)
    a_first, a_lines, a_sids = _user_words(audit_rel, a_data, W)
    out.append((brief_rel, b_commit, team_files.LABELS[2], b_first, b_lines, note))
    # audit 에 발화 번호가 있고 그것이 모두 brief §6 에 있을 때만 audit 구간은 같은 말을 두 번 싣는 것이다 —
    # 번호가 하나도 없는 audit §6 의 글은 빈 집합이 「모두 있다」 로 읽혀 빠지면 안 된다
    if not (a_sids and a_sids <= b_sids):
        out.append((audit_rel, a_commit, team_files.LABELS[2], a_first, a_lines, note))
    return out


def framing_notice(existing: bytes, new: bytes) -> list:
    """이번에 붙인 구간(existing 뒤에 new 가 더한 것) 가운데 표지 NO_FRAMING 이 붙은 것이 있으면 화면에 낼 한 줄, 없으면 []."""
    before = len(team_files.parse_original(existing)) if existing else 0
    added = team_files.parse_original(new)[before:]
    return [PREFIX + NO_FRAMING_SAID] if any(NO_FRAMING in s.note.split(" · ") for s in added) else []


# ── create --layout team ─────────────────────────────────────────────────────

def _refuse_links(top: Path, rel: str, W):
    """rel 의 폴더 성분(top 아래)에 심볼릭 링크가 있으면 Refused — 링크 너머에 쓰지 않는다."""
    parts = rel.split("/")
    for i in range(1, len(parts)):
        if os.path.islink(str(top.joinpath(*parts[:i]))):
            raise W.Refused("심볼릭 링크로는 쓰지 않는다: %s (%s 를 쓰려 했다)" % ("/".join(parts[:i]), rel))


def render_team_roadmap(template: str, rows, idx, title, brief_rel, roadmap_rel, history) -> str:
    """옛 로드맵 틀에 머리말 layout 줄을 넣고 넘김 문장을 바꾼 뒤 그린다 — 사용자 글에 든 같은 문장은 건드리지 않는다.
    틀에 두 자리가 한 번씩이 아니면 TableError."""
    for mark in (FRONT, OLD_HANDOFF):
        if template.count(mark) != 1 or (mark == FRONT and not template.startswith(FRONT)):
            raise R.TableError("로드맵 틀이 바뀌었다 — %r 가 한 번이 아니라 %d번 나온다(머리말은 맨 앞이어야 한다)"
                               % (mark, template.count(mark)))
    layout_line = "%s: %s\n" % (team_layout.LAYOUT_KEY, team_layout.LAYOUT_TEAM)
    team_template = FRONT + layout_line + template[len(FRONT):].replace(OLD_HANDOFF, TEAM_HANDOFF)
    return R.render_roadmap(team_template, rows, idx, title, brief_rel, roadmap_rel, history, layout=team_layout.LAYOUT_TEAM)


def seed_common(top: Path, roadmaps_dir: str, W) -> dict:
    """로드맵 폴더 바로 아래의 공통 문서(역할 문서 넷 · HANDBOOK) 가운데 없는 것의 {Path: 틀 글}. 있는 것은 건드리지 않는다."""
    pairs = [(team_layout.role_doc(roadmaps_dir, r), team_files.role_template(r)) for r in team_layout.ROLES]
    pairs.append((team_layout.handbook(roadmaps_dir), team_files.TEMPLATES / team_layout.HANDBOOK_FILE))
    out = {}
    for rel, template in pairs:
        _refuse_links(top, rel, W)
        if not os.path.lexists(str(top / rel)):
            out[top / rel] = W.read(template, keep_newlines=True)
    return out


def _intent_text(template: str, r, roadmap_rel: str) -> str:
    """묶음 행 하나의 INTENT.md 글 — 목표 · 지시 원문(줄 범위) · 하지 않을 것을 행에서 채운다."""
    return team_files.render_intent(template, r.id, team_files.KIND_EPIC, roadmap_rel, team_files.goal_text(r.intent, r.scope),
                                    team_files.original_pointer(r.ranges, roadmap_rel), team_files.not_text(r.scope))


def create_files(top: Path, team, rows, idx, title, brief_rel, roadmap_rel, history, brief: Path, W) -> tuple:
    """(다시 쓰는 파일 {Path: 글}, 없을 때만 까는 파일 {Path: 글}, 화면 줄들). 다시 쓰는 것은 로드맵과 묶음 행마다 INTENT · sources,
    없을 때만 까는 것은 규칙 파일 · 원자료 사본 · 결과 폴더의 빈 파일 · 공통 문서다. 폴더 성분이 링크면 Refused.
    화면 줄은 원자료 사본을 framing 구간 없이 만들 때의 한 줄이다."""
    intent_template = W.read(team_files.TEMPLATES / team_layout.INTENT_FILE)
    rewrite = {top / team.roadmap: render_team_roadmap(W.read(R.TEMPLATE), rows, idx, title, brief_rel, roadmap_rel, history)}
    once, said = {}, []

    def absent(rel: str) -> bool:
        _refuse_links(top, rel, W)
        return not os.path.lexists(str(top / rel))

    if absent(team.rules):
        once[top / team.rules] = W.read(team_files.TEMPLATES / team_layout.RULES_FILE, keep_newlines=True)
    for r in rows:
        if r.kind != R.KIND_BUNDLE:
            continue
        rewrite[top / team.intent(r.id)] = _intent_text(intent_template, r, roadmap_rel)
        ids, parts = R.bundle_parts(r, idx)
        rewrite[top / team.sources(r.id)] = team_files.render_sources(r.id, r.title, ids, parts, r.receives, r.gives)
        if absent(team.keep(r.id)):
            once[top / team.keep(r.id)] = ""
    if absent(team.original):
        data, _notes = team_files.extend_original(b"", wanted_sections(top, brief, None, W))
        once[top / team.original] = data.decode("utf-8")
        said = framing_notice(b"", data)
    for path in rewrite:
        _refuse_links(top, path.relative_to(top).as_posix(), W)
    once.update(seed_common(top, team.roadmaps_dir, W))
    return rewrite, once, said


def check_rerun(top: Path, team, record: set, rewrite: dict, W):
    """다시 돌 때 멈출 자리 둘(P13) — 생성 기록에 있는 INTENT.md 에 결정 기록 줄이 있거나, 생성 기록에 있는데 이번 표에
    없는 과제의 파일이 남아 있으면 Refused. create 는 그 파일을 고치거나 지우지 않는다 — 재분해는 update 의 몫이다."""
    for path in sorted(rewrite):
        rel = W.rel(top, path)
        if path.name != team_layout.INTENT_FILE or rel not in record or not path.is_file():
            continue
        try:
            decided = team_files.intent_sections(W.read(path))[team_files.SECTIONS[3]]
        except team_files.FormatError as exc:
            raise W.Refused("%s 의 네 칸을 읽지 못해 다시 쓰지 않는다 — %s" % (rel, exc))
        if any(line.startswith("- ") for line in decided.split("\n")):
            raise W.Refused("%s 의 결정 기록에 줄이 있다 — create 는 이 파일을 다시 쓰지 않는다. 재분해는 update 로 한다" % rel)
    targets = {W.rel(top, p) for p in rewrite}
    left = sorted(p for p in record - targets if p.startswith(team.dir + "/") and os.path.lexists(str(top / p)))
    if left:
        raise W.Refused("생성 기록에 있는데 이번 표에 없는 과제의 파일이 남아 있다 — %s. create 는 지우지 않는다 — 재분해는 update 로 한다"
                        % " · ".join(left))


# ── update (team) ─────────────────────────────────────────────────────────────

def hand_fix(team, r) -> list:
    """있던 과제의 INTENT.md 를 손으로 고칠 글 — 머리 줄과 목표 · 지시 원문 범위 · 하지 않을 것(글은 줄마다 네 칸 들인다)."""
    def indented(text):
        return [INDENT + line for line in text.split("\n")]
    return ([PREFIX + HAND_FIX % (r.id, team.intent(r.id)), "  목표:"]
            + indented(team_files.goal_text(r.intent, r.scope))
            + ["  지시 원문 범위: " + team_files.format_ranges(r.ranges), "  하지 않을 것:"]
            + indented(team_files.not_text(r.scope)))


def hand_fixes(top: Path, team, old: dict, new: dict, W) -> tuple:
    """(손으로 고칠 과제 번호들, 화면 줄들) — 있던 과제(옛 행 · 새 행 모두 묶음) 가운데 의도 · 범위 · 지시 원문 범위가 옛 행
    (지시 원문 범위는 INTENT.md 에서 읽은 것)과 다른 것. 지시 원문 범위는 차례를 무시하고 견준다. 범위가 다른 과제가 있으면
    끝에 어느 INTENT.md 를 읽는지 한 줄을 붙인다. 새 표의 묶음 행 범위가 원자료 사본 밖이면 Refused — 파일 밖 범위를 적으라고 하지 않는다."""
    try:
        total = team_files.line_count((top / team.original).read_bytes())
    except OSError as exc:
        raise W.Refused("원자료 사본을 읽지 못했다: %s (%s)" % (team.original, exc))
    ids, todo, ranged = [], [], False
    for r in new.values():
        if r.kind != R.KIND_BUNDLE:
            continue
        far = ["%d–%d" % ab for ab in r.ranges if ab[1] > total]
        if far:
            raise W.Refused("%s: 지시 원문 범위 %s 가 %s 의 %d줄 밖이다" % (r.id, " · ".join(far), team.original, total))
        before = old.get(r.id)
        if before is None or before.kind != R.KIND_BUNDLE:
            continue
        other_ranges = sorted(before.ranges) != sorted(r.ranges)
        if other_ranges or (before.intent, before.scope) != (r.intent, r.scope):
            ids.append(r.id)
            todo += hand_fix(team, r)
            ranged = ranged or other_ranges
    return ids, todo + ([PREFIX + RANGE_READ] if ranged else [])


def update_files(top: Path, team, old: dict, new: dict, changed: list, added: list, removed: list, idx, roadmap_rel: str,
                 W) -> tuple:
    """(쓸 파일 {Path: 글}, 없을 때만 까는 파일 {Path: 글}, 알림 줄들) — update 의 team 갈래.

    바뀌었거나 새로 온 묶음 행의 sources.md 는 글이 다를 때만 다시 쓴다. 새로 묶음이 된 행은 INTENT.md 와 결과 폴더의
    빈 파일을 깐다 — 그 sources.md 자리에 무엇이든 있으면 생성기가 만든 파일이 아니라 Refused, INTENT.md 자리에 무엇이든
    (매달린 링크도) 있어도 Refused. 있던 과제의 INTENT.md 는 쓰지 않는다 — 손으로 고칠 글 · 범위 검사는 hand_fixes 가
    따로 낸다. 사라졌거나 묶음이 아니게 된 과제의 폴더는 건드리지 않고 알린다. 쓸 자리 · 그 폴더 성분이 심볼릭 링크면 Refused."""
    intent_template = W.read(team_files.TEMPLATES / team_layout.INTENT_FILE)
    rewrite, once, notes, foreign, left = {}, {}, [], [], []
    for r in [new[i] for i in new if i in changed or i in added]:
        if r.kind != R.KIND_BUNDLE:
            continue
        ids, parts = R.bundle_parts(r, idx)
        text = team_files.render_sources(r.id, r.title, ids, parts, r.receives, r.gives)
        src = team.sources(r.id)
        _refuse_links(top, src, W)
        if os.path.islink(str(top / src)):
            raise W.Refused("심볼릭 링크로는 쓰지 않는다: %s" % src)
        before = old.get(r.id)
        fresh = before is None or before.kind != R.KIND_BUNDLE
        if fresh and os.path.lexists(str(top / src)):
            if before is None:
                foreign.append(src)
            else:   # 묶음이 아니던 행 — 앞서 묶음이었을 때 그대로 둔 폴더일 수 있어 남의 파일이라 하지 않는다
                left.append(LEFT_FILE % (src, r.id))
            continue
        if not (top / src).is_file() or W.read(top / src) != text:
            rewrite[top / src] = text
        if not fresh:
            continue
        intent = team.intent(r.id)
        _refuse_links(top, intent, W)
        if os.path.lexists(str(top / intent)):
            raise W.Refused("%s 가 이미 있다 — 새 과제 %s 의 INTENT.md 는 덮어쓰지 않는다" % (intent, r.id))
        once[top / intent] = _intent_text(intent_template, r, roadmap_rel)
        keep = team.keep(r.id)
        _refuse_links(top, keep, W)
        if not os.path.lexists(str(top / keep)):
            once[top / keep] = ""
    if foreign or left:
        raise W.Refused(" / ".join(([FOREIGN % " · ".join(foreign)] if foreign else []) + left))
    for i in old:
        if old[i].kind == R.KIND_BUNDLE and (i in removed or (i in changed and new[i].kind != R.KIND_BUNDLE)):
            notes.append(PREFIX + LEFT_JOB % (i, team.job(i)))
    return rewrite, once, notes


def range_screen(top: Path, team, rows) -> list:
    """과제마다 `<번호> 지시 원문 <범위>행:` 줄과 원자료 사본의 그 줄들 — 화면에만 낸다."""
    lines = team_files.byte_lines((top / team.original).read_bytes())
    out = []
    for r in rows:
        if r.kind != R.KIND_BUNDLE:
            continue
        out.append(PREFIX + "%s 지시 원문 %s행:" % (r.id, team_files.format_ranges(r.ranges)))
        for a, z in r.ranges:
            out.extend(line.decode("utf-8").rstrip("\n") for line in lines[a - 1:z])
    return out


# ── 명령 ─────────────────────────────────────────────────────────────────────

def cmd_original(a, W) -> int:
    out_dir = Path(os.path.realpath(a.out))
    top = W.git_top(out_dir)
    team = team_for(top, out_dir, W)
    target = top / team.original
    linked = any(os.path.islink(str(p)) for p in (target.parent, target))   # 링크 너머는 읽지도 않는다 — 아래에서 거절한다
    existing = target.read_bytes() if target.is_file() and not linked else b""
    wanted = wanted_sections(top, Path(a.brief), a.framing_audit, W, existing)
    for path in (target.parent, target):
        if os.path.islink(str(path)):
            raise W.Refused("심볼릭 링크로는 쓰지 않는다: %s" % path)
    if os.path.lexists(str(target)) and not target.is_file():
        raise W.Refused("원자료 사본 자리가 파일이 아니다: %s" % team.original)
    new, notes = team_files.extend_original(existing, wanted)
    roadmap = top / team.roadmap
    if new == existing:
        shown = []
        if roadmap.exists():
            _errors, unknown, check_notes = team_check.check_tree(top, team)
            shown = check_screen(unknown, check_notes)
        print(PREFIX + "원자료 사본이 이미 출처와 같다 — 쓰지 않았다: %s" % team.original)
        for line in shown:
            print(line)
        return 0
    added = len(team_files.parse_original(new)) - (len(team_files.parse_original(existing)) if existing else 0)
    said = framing_notice(existing, new)
    shown = []   # 화면 줄은 거래 안에서 계산한다 — 커밋 뒤에는 예외가 날 일을 하지 않는다
    txn = W.Txn()

    def body():
        txn.ensure_dir(target.parent)
        txn.write(target, new.decode("utf-8"))
        if roadmap.exists():
            errors, unknown, check_notes = team_check.check_tree(top, team)
            if errors:
                raise W.Refused("검사 실패 — %s" % " / ".join(errors))
            shown.extend(check_screen(unknown, check_notes))

    W.run_txn(txn, body)
    for line in notes:
        print(PREFIX + line)
    print(PREFIX + "원자료 사본을 썼다: %s — 구간 %d개를 끝에 더했다" % (team.original, added))
    for line in said + shown:
        print(line)
    return 0


# ── job new: 단순 작업의 과제 폴더 ─────────────────────────────────────────────

LINE_BREAKS = ("\n", "\r")
PATH_FORBIDDEN = ("[", "]") + LINE_BREAKS   # 머리 `paths: [a, b]` 한 줄을 깨는 글자 — 쉼표는 나누는 자리라 빈 원소로 드러난다


def _one_line(flag: str, value: str, W) -> str:
    """빈 글이거나 줄바꿈이 든 값은 Usage — 머리 한 줄 · 칸의 한 줄에 들어갈 값이다."""
    if not value.strip():
        raise W.Usage("%s 가 비었다" % flag)
    if any(c in value for c in LINE_BREAKS):
        raise W.Usage("%s 는 한 줄이다 — 줄바꿈이 들었다: %r" % (flag, value))
    return value


def job_paths(value: str, W) -> list:
    """`--paths` 의 쉼표 목록 → 앞뒤 공백을 뗀 원소들. 비었거나 빈 원소 · `[` `]` · 줄바꿈이 든 원소가 있으면 Usage."""
    items = [p.strip() for p in value.split(",")]
    if not value.strip():
        raise W.Usage("--paths 가 비었다")
    for p in items:
        if not p:
            raise W.Usage("--paths 에 빈 원소가 있다(쉼표가 겹치거나 끝에 있다): %r" % value)
        if any(c in p for c in PATH_FORBIDDEN):
            raise W.Usage("--paths 의 원소에 [ ] 나 줄바꿈을 넣지 않는다: %r" % p)
    return items


def received_text(data: bytes, W) -> str:
    """표준 입력의 바이트 → 글(엄격한 UTF-8, 줄바꿈은 바꾸지 않는다). 비었거나 공백뿐이면 · UTF-8 이 아니면 Refused."""
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise W.Refused("받은 말(표준 입력)이 UTF-8 이 아니다(%s)" % exc)
    if not text.strip():
        raise W.Refused("받은 말이 비었다 — 지시 원문은 표준 입력으로 받는다")
    return text


def job_name_refusal(top: Path, team, name: str, roadmap_text: str):
    """과제 이름으로 못 쓰는 사유 한 줄, 쓸 수 있으면 None — 이름 꼴 · 그 로드맵의 블록 번호(대소문자 무시) ·
    블록 번호 꼴(뒤에 올 에픽의 과제 폴더 자리) · 이미 있는 과제 폴더 자리(매달린 링크도, 대소문자만 다른 이름도)."""
    problem = team_layout.job_name_problem(name)
    if problem:
        return problem
    _meta, blocks, _rec, _risk, _errors = parse_roadmap(roadmap_text)
    hit = [b["id"] for b in blocks if str(b.get("id", "")).casefold() == name.casefold()]
    if hit:
        return "%s 는 로드맵 %s 의 블록 번호(%s)와 겹친다 — 에픽 · 결정 블록 번호는 과제 이름으로 쓰지 않는다" % (
            name, team.roadmap, hit[0])
    if BLOCK_ID_RE.fullmatch(name):
        return EPIC_SHAPED % name
    folder = top / team.job(name)
    parent = folder.parent
    taken = [n for n in (os.listdir(str(parent)) if parent.is_dir() else []) if n.casefold() == name.casefold()]
    if os.path.lexists(str(folder)) or taken:
        return "과제 폴더 자리가 이미 있다: %s — 덮어쓰지 않는다" % team.job(taken[0] if taken else name)
    return None


def cmd_job_new(a, W) -> int:
    """team 로드맵의 팀 폴더에 단순 작업(kind: task)의 과제 폴더를 한 거래로 만든다 — INTENT.md(지시 원문은 표준 입력의
    바이트 그대로)와 결과 폴더의 빈 파일. 쓴 뒤 team 나무 검사가 오류를 내면 되돌린다. 브랜치를 만들거나 커밋하지 않는다."""
    goal = _one_line("--goal", a.goal, W)
    branch = _one_line("--branch", a.branch, W)
    paths = job_paths(a.paths, W)
    nots = [_one_line("--not", n, W) for n in a.nots or []]
    roadmap = Path(os.path.realpath(a.roadmap))
    top = W.git_top(roadmap)
    text = W.read(roadmap)
    if W.roadmap_layout(text) != team_layout.LAYOUT_TEAM:
        raise W.Refused("team 형식 로드맵이 아니다 — 머리말에 `%s: %s` 가 없다: %s"
                        % (team_layout.LAYOUT_KEY, team_layout.LAYOUT_TEAM, W.rel(top, roadmap)))
    team = team_for(top, roadmap.parent, W)
    if W.rel(top, roadmap) != team.roadmap:
        raise W.Refused("--roadmap 은 팀 폴더의 %s 다: %s" % (team_layout.ROADMAP_FILE, W.rel(top, roadmap)))
    refusal = job_name_refusal(top, team, a.name, text)
    if refusal:
        raise W.Refused(refusal)
    said = received_text(sys.stdin.buffer.read(), W)
    not_do = "\n".join("- %s" % n for n in nots) if nots else team_files.not_text("")
    intent = team_files.render_intent(W.read(team_files.TEMPLATES / team_layout.INTENT_FILE), a.name, team_files.KIND_TASK,
                                      team.roadmap, goal, said, not_do, branch, paths)
    try:   # 쓰기 전에 되읽는다 — 받은 말 · 한 줄 값이 네 칸을 가르지 않아야 한다
        back = team_files.intent_sections(intent)
    except team_files.FormatError:
        back = {}
    if tuple(back.get(k) for k in team_files.SECTIONS[:3]) != (goal, said, not_do):
        raise W.Refused("만든 INTENT.md 가 목표 · 지시 원문 · 하지 않을 것 칸으로 되읽히지 않는다 — 쓰지 않았다"
                        "(--goal 이 `## <칸 이름>` 꼴이면 칸이 갈린다)")
    targets = (team.intent(a.name), team.keep(a.name))
    for rel_path in targets:
        _refuse_links(top, rel_path, W)
    txn = W.Txn()
    shown = []   # 화면 줄은 거래 안에서 계산한다

    def body():
        for rel_path, content in zip(targets, (intent, "")):
            txn.ensure_dir((top / rel_path).parent)
            txn.write(top / rel_path, content)
        errors, unknown, check_notes = team_check.check_tree(top, team)
        if errors:
            raise W.Refused("team 나무 검사 실패 — %s" % " / ".join(errors))
        shown.extend(check_screen(unknown, check_notes))

    W.run_txn(txn, body)
    print(PREFIX + "과제 폴더를 만들었다: %s (kind: %s · 브랜치 %s) — 브랜치를 만들거나 커밋하지 않았다"
          % (team.job(a.name), team_files.KIND_TASK, branch))
    for line in shown:
        print(line)
    return 0


# ── job sync: 결과 파일 맞추기 ─────────────────────────────────────────────────

SYNC_HEAD_KEYS = ("type", "stage", "plan", "attempt", "role", "head", "bundle_at", "rules_at", "job_at")


def _commit_flag(flag: str, value, W) -> str:
    if not _SHA_RE.fullmatch(value or ""):
        raise W.Usage("%s 는 커밋 번호 꼴(소문자 16진 40자 또는 64자)이다: %r" % (flag, value))
    return value


def _unresolved_rel(top: Path, value: str):
    """링크를 풀지 않은 `--result` 의 레포 상대 경로. 작업 트리 안으로 이어지는 조상을 못 찾으면 None."""
    full = os.path.abspath(value)
    base = full
    while os.path.realpath(base) != str(top):
        parent = os.path.dirname(base)
        if parent == base:
            return None
        base = parent
    return None if base == full else os.path.relpath(full, base).replace(os.sep, "/")


def sync_result_path(top: Path, value: str, W) -> tuple:
    """`--result` → (Path, 레포 상대 경로, Team, 과제, (단계, 계획, 시도)). 결과 폴더의 결과 파일 이름이 아니면 Refused."""
    rel_path = _unresolved_rel(top, value)
    if rel_path is None:   # 풀지 않은 경로가 작업 트리로 이어지지 않으면(링크 너머 · 밖) 풀린 경로로 되돌려 쓰지 않는다
        raise W.Refused("작업 트리 안의 경로로 이어지지 않는다(심볼릭 링크 너머이거나 작업 트리 밖이다): %s" % value)
    path = top / rel_path
    _refuse_links(top, rel_path, W)   # 풀기 전 경로의 폴더 성분들 — 링크 너머에 쓰지 않는다
    if os.path.islink(str(path)):
        raise W.Refused("심볼릭 링크로는 쓰지 않는다: %s" % rel_path)
    if NOT_HERE in rel_path.split("/"):
        raise W.Refused("%s 아래에는 쓰지 않는다 — %s" % (NOT_HERE, rel_path))
    hit = team_layout.job_of_path(roadmaps_dir_of(top, W), rel_path)
    folder, _sep, name = (hit[2] if hit else "").rpartition("/")
    parsed = team_layout.parse_result_name(name) if hit else None
    if not hit or folder != team_layout.RESULTS_DIR or parsed is None:
        raise W.Refused("과제 폴더의 결과 폴더 안 결과 파일 이름이 아니다(%s/<단계>-<시도>.md 꼴): %s"
                        % (team_layout.RESULTS_DIR, rel_path))
    team, job, _rest = hit
    if not (top / team.job(job)).is_dir():
        raise W.Refused("과제 폴더가 없다: %s" % team.job(job))
    return path, rel_path, team, job, parsed


def _new_head(parsed: tuple, role: str, bundle_at: str, job_at: str, rules_at: Optional[str] = None) -> str:
    stage, plan, attempt = parsed
    values = {"type": team_files.RESULT_TYPE, "stage": stage, "plan": plan, "attempt": attempt,
              "role": role, "head": job_at, "bundle_at": bundle_at, "rules_at": rules_at, "job_at": job_at}
    lines = ["%s: %s" % (k, values[k]) for k in SYNC_HEAD_KEYS if values[k] is not None]
    return "---\n" + "\n".join(lines) + "\n---\n\n"


def _swap_head(text: str, commit: str, key: str = "head", insert_after: Optional[str] = None) -> str:
    """머리의 `<key>:` 줄을 commit 으로 — 머리 밖은 건드리지 않는다. 그 줄이 없고 insert_after 가 있으면
    머리의 `<insert_after>:` 줄 바로 뒤에 새 줄로 넣는다(그 줄의 줄바꿈 꼴 그대로)."""
    lines = text.split("\n")
    after = None
    for i in range(1, len(lines)):
        if lines[i].rstrip("\r") == "---":
            break
        if lines[i].startswith(key + ":"):
            lines[i] = "%s: %s%s" % (key, commit, "\r" if lines[i].endswith("\r") else "")
            return "\n".join(lines)
        if insert_after is not None and after is None and lines[i].startswith(insert_after + ":"):
            after = i
    if after is not None:
        lines.insert(after + 1, "%s: %s%s" % (key, commit, "\r" if lines[after].endswith("\r") else ""))
    return "\n".join(lines)


def _drop_head(text: str, key: str) -> str:
    """머리의 `<key>:` 줄을 지운다 — 머리 밖과 다른 줄은 건드리지 않는다. 없으면 글 그대로."""
    lines = text.split("\n")
    for i in range(1, len(lines)):
        if lines[i].rstrip("\r") == "---":
            break
        if lines[i].startswith(key + ":"):
            del lines[i]
            break
    return "\n".join(lines)


def _appended(text: str, new_lines: list) -> str:
    """줄들을 끝에 붙인다 — 파일이 CRLF 면 CRLF 로, 끝 줄바꿈이 없으면 그 파일의 줄바꿈 하나만 보태고 붙인다."""
    if not new_lines:
        return text
    eol = "\r\n" if "\r\n" in text else "\n"
    return text + ("" if text.endswith("\n") or not text else eol) + eol.join(new_lines) + eol


def cmd_job_sync(a, W) -> int:
    """결과 파일을 한 거래로 맞춘다 — 없으면 머리를 만들고, 원장 · 계획 파일이 있으면 변환기가 낸 줄 가운데 없는 것만 덧붙이고,
    `--end` 면 머리의 head 를 고쳐 「끝」 줄을 단다. 「끝」 줄이 없는 결과 파일(이어 쓰는 파일)에 `--bundle-at` · `--job-at` 을
    함께 주면 머리의 그 두 커밋을 새 값으로 고치고, 둘 가운데 하나만 주면 사용법 오류다. `--rules-at`(팀 규칙을 읽은
    상태 브랜치 커밋)은 그 둘과 함께만 받는다 — 새 머리와 이어 쓰는 파일에서는 `bundle_at` 바로 뒤에 적고, 이어 쓰는
    파일에 그 둘만 주면(기본 브랜치에서 규칙을 읽은 묶음) 머리의 옛 `rules_at` 줄을 지운다. 그 밖의 있는 줄은 바이트 그대로 둔다. git 은 레포 뿌리와 레포 설정(`roadmaps_dir`)을
    읽을 때만 부르고, 과제 브랜치의 커밋 · 이력은 읽지 않으며 커밋하지 않는다."""
    if bool(a.ledger) != bool(a.plan_file):
        raise W.Usage("--ledger 와 --plan-file 은 함께만 준다")
    if a.role is not None and a.role not in team_layout.ROLES:
        raise W.Usage("--role 은 %s 가운데 하나다: %r" % (" · ".join(team_layout.ROLES), a.role))
    for flag, value in (("--bundle-at", a.bundle_at), ("--job-at", a.job_at), ("--rules-at", a.rules_at), ("--end", a.end)):
        if value is not None:
            _commit_flag(flag, value, W)
    if a.rules_at is not None and not (a.bundle_at and a.job_at):
        raise W.Usage("--rules-at 은 --bundle-at · --job-at 과 함께만 준다")
    path = Path(os.path.realpath(a.result))
    top = W.git_top(path)
    path, rel_path, team, job, parsed = sync_result_path(top, a.result, W)
    layout_text = W.read(top / team.roadmap) if (top / team.roadmap).is_file() else None
    if layout_text is None or W.roadmap_layout(layout_text) != team_layout.LAYOUT_TEAM:
        raise W.Refused("team 형식 로드맵의 과제가 아니다 — %s 가 없거나 머리말에 `%s: %s` 가 없다"
                        % (team.roadmap, team_layout.LAYOUT_KEY, team_layout.LAYOUT_TEAM))
    new_lines, total = [], 0
    if a.ledger:
        total = workflow_superpowers.task_total(W.read(Path(a.plan_file)))
        new_lines = workflow_superpowers.ledger_lines(W.read(Path(a.ledger)), total)
    done = []
    if path.exists():
        old = W.read(path, keep_newlines=True)
        r = team_files.parse_result(old)
        if r.problems:
            raise W.Refused("결과 파일을 읽지 못했다: %s — %s" % (rel_path, r.problems[0]))
        if (r.stage, r.plan, r.attempt) != parsed:
            raise W.Refused("결과 파일 머리의 단계 · 계획 · 시도 %s 가 이름 %s 와 다르다"
                            % ((r.stage, r.plan, r.attempt), path.name))
        text = old
    else:
        if not (a.role and a.bundle_at and a.job_at):
            raise W.Refused("머리를 만들 값이 없다 — 결과 파일이 없으면 --role · --bundle-at · --job-at 이 모두 필요하다: %s"
                            % rel_path)
        old, r = None, None
        text = _new_head(parsed, a.role, a.bundle_at, a.job_at, a.rules_at)
        done.append("머리 만듦")
    if r is not None and r.end is None and (a.bundle_at or a.job_at):   # 이어 쓰는 파일 — 머리의 묶은 커밋 둘을 새 값으로 고친다
        if not (a.bundle_at and a.job_at):
            raise W.Usage("이어 쓰는 결과 파일의 머리는 --bundle-at 과 --job-at 을 함께 줘야 고친다")
        text = _swap_head(_swap_head(text, a.bundle_at, "bundle_at"), a.job_at, "job_at")
        if a.rules_at:
            text = _swap_head(text, a.rules_at, "rules_at", insert_after="bundle_at")
        else:   # 기본 브랜치에서 규칙을 읽은 묶음 — 옛 rules_at 이 남으면 묶음 낡음이 다른 커밋의 규칙과 견준다
            text = _drop_head(text, "rules_at")
        if text != old:
            done.append("묶은 커밋 고침")
    # 계획의 task 절 수보다 큰 번호와 task 절이 없는 계획만 거절한다.
    # 전체가 앞 줄과 달라지는 것은 쓴다 — 읽는 쪽이 마지막 줄의 전체를 쓴다
    for line in new_lines:
        if line.startswith("Task "):
            n = int(line[len("Task "):].split("/", 1)[0])
            if total == 0:
                raise W.Refused("계획 파일 %s 에 task 절이 없다 — 원장의 Task %d 의 끝을 진행 줄로 쓰지 않았다" % (a.plan_file, n))
            if n > total:
                raise W.Refused("원장은 Task %d 의 끝을 말하는데 계획 파일 %s 의 task 절은 %d개다 — 진행 줄을 쓰지 않았다"
                                % (n, a.plan_file, total))
    have = set(line.rstrip("\r") for line in (r.machine_text.split("\n") if r else []))   # 펜스 밖 · 머리 아래의 줄만
    new_lines = [line for line in new_lines if line not in have]
    text = _appended(text, new_lines)
    for label, prefix in (("Task", "Task "), ("Ruling", workflow_superpowers.RULING_MARK)):
        n = sum(1 for line in new_lines if line.startswith(prefix))
        if n:
            done.append("%s 줄 +%d" % (label, n))
    closed = r is not None and r.end is not None
    if closed and (new_lines or (a.end and a.end != r.end)):
        raise W.Refused("끝난 결과 파일은 고치지 않는다 — 다시 하는 일은 새 시도 번호다: %s" % rel_path)
    if a.end:
        text = _swap_head(text, a.end)
        if not closed:
            text = _appended(text, [team_files.END_PREFIX + a.end])
            done.append("끝 줄")
    if closed and text != old:
        raise W.Refused("끝난 결과 파일은 고치지 않는다 — 다시 하는 일은 새 시도 번호다: %s" % rel_path)
    if old is not None and text == old:
        print(PREFIX + "바뀐 것 없음: %s" % rel_path)
        return 0
    txn = W.Txn()

    def body():
        txn.ensure_dir(path.parent)
        txn.write(path, text)

    W.run_txn(txn, body)
    print(PREFIX + "결과 파일을 맞췄다: %s — %s" % (rel_path, " · ".join(done)))
    return 0
