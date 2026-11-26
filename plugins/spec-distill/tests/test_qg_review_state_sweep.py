#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""qg_review_state.py 원칙 훑기 — 관문이 닫히는 까닭마다 그것을 푸는 할 일 하나(AC31 · AC32 · AC9 · AC33).

Run: cd plugins/spec-distill/tests && PYTHONDONTWRITEBYTECODE=1 python3 -m unittest test_qg_review_state_sweep -v

이 테스트가 뒤 과제(4–7)에 고정하는 접점:
- `qg_review_state.NEXT_ROWS` — 설계 §4 표의 줄을 위에서부터 차례대로 담은 목록. 줄마다
  `Row(id, reason, kind, conductor_choices)` 의 속성을 갖는다.
  - `reason` — 「까닭」 칸의 번호(1–8, int). 번호가 아닌 칸(R0 · R9 「없음 — 관문 열림」, RX 「—」)은 None.
  - `kind` — 「할 일」 의 꼴 낱말(아래 KINDS 가운데 하나). 보관 폴더에 따라 꼴이 갈리는 줄(R1b)만
    꼴 낱말의 tuple 이다.
  - `conductor_choices` — 「지휘자가 가린다」 줄(R1b · R1c · R7c)에서 지휘자가 대신 부를 수 있는 명령의
    꼴 글(예: `send --phase done --worker <이름>`)의 tuple. 첫 낱말이 하위 명령 이름이다. 그 밖의 줄은 빈 tuple.
- `next` 출력 — 1행 `할 일 · <꼴> · <글>`, 2행 `줄 · <id>`, 3행 `까닭 · <번호|없음>`(관문 열림이면 없음).
  사용자 차례면 `물을 것 · <종류> · <정체>` 줄을 함께 낸다.
- 명령줄 — `qg_review_state.py <명령> --roadmap <로드맵> --target <대상> [--repo <레포>] [--at <때>]`,
  뺄 파일 `--spec <설계문서>`(open · record · next · gate). 종료 코드 0 됨 · 1 관문 닫힘 · 2 사용법 ·
  3 파일 · 4 받지 않음. 명령별 인자는 계획 Task 4–7 그대로(open `--site --base --head --epic --session` ·
  send `--phase start|done [--worker]` · record `--input <JSON>` · next `--alive <이름>... --no-qg` ·
  gate `--no-qg`).
- `record --input` 의 JSON — `{"items": [...]}`, 항목 `kind` 는 answer · record_path · handling · return ·
  return_moved · route · mark (칸 이름은 계획 Task 6).

테스트 쪽에는 줄 id 마다 상태를 짓는 BUILD[id](변형마다 짓는 함수의 목록)와 그 할 일을 하는
DO[id](rig, out) 만 두고, 줄의 꼴 · 까닭은 NEXT_ROWS 에서 읽는다. EXPECTED 는 설계 §4 의 「까닭」 칸 번호와
「할 일」 의 꼴 낱말을 손으로 한 번 더 적은 대조표다(맞는 조건은 싣지 않는다 — 조건은 BUILD 가 상태로 잰다).
AFTER 는 §4 「그 할 일 뒤 상태」 칸을 줄 id 집합으로 옮긴 것이다.
"""
from __future__ import annotations

import importlib
import json
import sys
import unittest
from pathlib import Path
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import qg_review_file as F  # noqa: E402
from qg_review_state_fixture import BASE, EPIC, HEAD, ROADMAP, SESSION, Rig  # noqa: E402

TARGET = "pr12"
SPEC = "docs/superpowers/specs/a1-design.md"
AT = "2026-11-26 10:00"
LATER = "2026-11-26 11:00"
RECORD = "docs/qg-intent-answers/A1-q1.md"
NO_VERDICT = "qg 가 끝까지 돌지 못했다 — 보관한 결과에 판정이 없다"
QG_WORKER = "qg-w1"
IMPL_WORKER = "impl-w1"

KINDS = ("열기", "보냄", "돌아옴", "답 적기", "사용자 차례", "기다린다", "돌려보낸다", "기록 파일 쓰기",
         "머지 준비", "상태 보이기")

# 설계 §4 표의 줄 — 위에서부터 하나도 빼지 않고.
ORDER = ["R0", "R8a", "R1a", "R1b", "R1c", "R1d", "R1e", "R2", "R3a", "R3b", "R4", "R5",
         "R6a", "R6b", "R6c", "R6d", "R6e", "R7a", "R7b", "R7c", "R7d", "R7e", "R7f", "R8b", "R9", "RX"]
EXPECTED_IDS = frozenset(ORDER)
TABLE_ROWS = 26

# 줄 id → (「까닭」 칸 번호 | None, 「할 일」 의 꼴 낱말들)
EXPECTED = {
    "R0": (None, ("머지 준비",)),
    "R8a": (8, ("열기",)),
    "R1a": (1, ("보냄",)),
    "R1b": (1, ("돌아옴", "보냄")),
    "R1c": (1, ("사용자 차례",)),
    "R1d": (1, ("기다린다",)),
    "R1e": (1, ("돌아옴",)),
    "R2": (2, ("사용자 차례",)),
    "R3a": (3, ("사용자 차례",)),
    "R3b": (3, ("열기",)),
    "R4": (4, ("사용자 차례",)),
    "R5": (5, ("기록 파일 쓰기",)),
    "R6a": (6, ("답 적기",)),
    "R6b": (6, ("기다린다",)),
    "R6c": (6, ("열기",)),
    "R6d": (6, ("사용자 차례",)),
    "R6e": (6, ("열기",)),
    "R7a": (7, ("기다린다",)),
    "R7b": (7, ("답 적기",)),
    "R7c": (7, ("답 적기",)),
    "R7d": (7, ("돌려보낸다",)),
    "R7e": (7, ("열기",)),
    "R7f": (7, ("답 적기",)),
    "R8b": (8, ("열기",)),
    "R9": (None, ("머지 준비",)),
    "RX": (None, ("상태 보이기",)),
}

# 스크립트 명령으로 하는 할 일이 없는 줄 — 머지 준비(R0 · R9)와 끝 줄(RX).
NO_ACTION = frozenset({"R0", "R9", "RX"})

# 「그 할 일 뒤 상태」 칸의 단계 낱말을 줄 id 로 — 보냄 · 돌아옴에 머묾 · 닫힘.
SENT = frozenset({"R1c", "R1d", "R1e"})
RETURNED = frozenset({"R3a", "R4", "R5", "R6a", "R7a", "R7b", "R7c", "R7d"})
CLOSED = frozenset({"R2", "R3b", "R6a", "R6b", "R6c", "R6d", "R6e", "R7e", "R7f", "R8b", "R9"})
_AFTER_R7B = frozenset({"R7e", "R9", "R8b", "R4", "R7d"})
AFTER = {
    "R8a": {"R1a"},                                     # 열림
    "R1a": {"R1b"} | SENT,                              # 보내는 중 → 보냄
    "R1b": SENT | RETURNED | CLOSED,                    # 보냄 · 돌아옴 · 닫힘 가운데 하나
    "R1c": {"R1d", "R1e"} | RETURNED,                   # 보냄(답 있음) — 이어 부름 · 「돌아옴」 이면 돌아옴
    "R1d": {"R1e"},                                     # 보냄 · 담당자 없음
    "R1e": RETURNED | CLOSED,                           # 돌아옴 또는 닫힘
    "R2": RETURNED | (CLOSED - {"R2"}),                 # 돌아옴 — 닫는 조건으로 다시 가린다
    "R3a": {"R3b", "R9", "R8b", "R2"},                  # 닫힘 — 다시 보냄 · 리뷰 없이 감 · 에픽을 멈춤
    "R3b": {"R1a"},                                     # 새 리뷰가 열림
    "R4": set(ORDER[ORDER.index("R5"):-1]) | {"R2"},     # 답이 있다 — 닫히거나 아래 줄 · 멈춤
    "R5": set(ORDER[ORDER.index("R6a"):-1]),            # 경로가 적힘 — 이 줄은 다시 맞지 않는다
    "R6a": {"R6b", "R6d"},                              # 닫힘 — 설계 대화로 · 재분해 신호
    "R6b": {"R6c"},                                     # 「다시 구현됨」 표시가 붙음
    "R6c": {"R1a"},                                     # 열림
    "R6d": {"R6e"},                                     # 「재분해 뒤 이어 감」 표시가 붙음
    "R6e": {"R1a"},                                     # 열림
    "R7a": {"R7b", "R7c"},                              # 「아직」 · 담당자 없음
    "R7b": set(_AFTER_R7B),                             # 재리뷰로 이어짐 · 사용자가 남김 · 까닭 4 · 처리 없음 줄
    "R7c": {"R7a", "R4"},                               # 첫째: 새 「아직」 줄 · 두 번째: 까닭 4
    "R7d": {"R7a", "R7b", "R7c"},                       # 「아직」 인 「돌려보냄」
    "R7e": {"R1a"},                                     # 열림
    "R7f": {"R7d", "R4"},                               # 돌아옴 — 처리 없음 줄(두 번째면 까닭 4)
    "R8b": {"R1a"},                                     # 열림
}
# 「지휘자가 가린다」 줄에서 지휘자가 대신 부른 명령 뒤의 줄. R7c 의 대신 명령은 「위 줄처럼」 처리를 옮긴다 —
# R7b 의 뒤 상태다(§4 R7c 칸에는 적혀 있지 않다 — DO 길의 AFTER[R7c] 에는 넣지 않는다).
CHOICE_AFTER = {"R1b": AFTER["R1b"], "R1c": AFTER["R1c"], "R7c": set(_AFTER_R7B)}


def next_rows():
    """구현의 표 — 스크립트가 없으면 여기서 ImportError 로 테스트가 ERROR 다."""
    return importlib.import_module("qg_review_state").NEXT_ROWS


def kinds_of(kind) -> set:
    return set(kind) if isinstance(kind, tuple) else {kind}


def reason_text(reason) -> str:
    return "없음" if reason is None else str(reason)


# ---------------------------------------------------------------- 명령

def common(rig) -> list:
    return ["--roadmap", ROADMAP, "--target", TARGET, "--repo", str(rig.repo), "--at", AT]


def parse(proc) -> SimpleNamespace:
    lines = proc.stdout.splitlines()
    out = SimpleNamespace(rc=proc.returncode, lines=lines, kind=None, id=None, reason=None,
                          text="rc=%d\nstdout:\n%s\nstderr:\n%s" % (proc.returncode, proc.stdout,
                                                                     proc.stderr[-1500:]))
    if lines:
        head = lines[0].split(" · ", 2)
        if len(head) >= 2 and head[0] == "할 일":
            out.kind = head[1]
    if len(lines) >= 2 and lines[1].startswith("줄 · "):
        out.id = lines[1][len("줄 · "):]
    if len(lines) >= 3 and lines[2].startswith("까닭 · "):
        out.reason = lines[2][len("까닭 · "):]
    return out


def run_next(rig, alive=(), no_qg=False) -> SimpleNamespace:
    args = ["next"] + common(rig) + ["--spec", SPEC]
    for name in alive:
        args += ["--alive", name]
    if no_qg:
        args.append("--no-qg")
    return parse(rig.run(*args))


def run_gate(rig, no_qg=False):
    args = ["gate"] + common(rig) + ["--spec", SPEC] + (["--no-qg"] if no_qg else [])
    return rig.run(*args)


def run_open(rig, site):
    return rig.run("open", *common(rig), "--spec", SPEC, "--site", site, "--base", BASE,
                   "--head", HEAD, "--epic", EPIC, "--session", SESSION)


def run_send(rig, phase, worker=None):
    args = ["send"] + common(rig) + ["--phase", phase]
    if worker is not None:
        args += ["--worker", worker]
    return rig.run(*args)


def run_back(rig):
    return rig.run("back", *common(rig))


def run_record(rig, items=None):
    args = ["record"] + common(rig) + ["--spec", SPEC]
    if items is not None:
        rig.inputs = getattr(rig, "inputs", 0) + 1
        path = rig.t / ("input-%d.json" % rig.inputs)
        path.write_text(json.dumps({"items": items}, ensure_ascii=False), encoding="utf-8")
        args += ["--input", str(path)]
    return rig.run(*args)


def ok(rig, proc, what: str):
    rig.tc.assertEqual(proc.returncode, 0, "%s → rc=%d\nstdout:\n%s\nstderr:\n%s"
                       % (what, proc.returncode, proc.stdout, proc.stderr[-1500:]))
    return proc


def item_answer(question, ask_kind, value, original=""):
    return {"kind": "answer", "question": question, "ask_kind": ask_kind, "value": value,
            "original": original}


def state_count(rig) -> int:
    return len(list(rig.report_root.glob("*/" + F.STATE_NAME)))


def last(rig) -> F.Review:
    return F.reviews_for(rig.report_root, TARGET)[-1]


def same_commit(short: str, full: str) -> bool:
    return len(short) >= 7 and full.startswith(short)


# ---------------------------------------------------------------- 상태 짓기

def fresh(tc) -> Rig:
    """임시 리포 — 기본 브랜치 위 첫 커밋(`base_sha`) · 리뷰받는 브랜치의 구현 커밋 c1(설계문서 + 코드)."""
    rig = Rig(tc)
    rig.base_sha = rig.sha()
    rig.code_n = 1
    rig.c1 = rig.commit({SPEC: "# A1 설계\n", "src/a.py": "a = 1\nb = 1\n"}, "impl 1")
    return rig


def code(rig, msg: str = "fix") -> str:
    """리더 기록 파일 밖(코드)을 바꾼 커밋 — 기준 커밋."""
    rig.code_n += 1
    return rig.commit({"src/a.py": "a = %d\n" % rig.code_n}, "%s %d" % (msg, rig.code_n))


def spec_only(rig) -> str:
    """리더 기록 파일(설계문서)만 바꾼 커밋 — 기준 커밋이 아니다."""
    rig.code_n += 1
    return rig.commit({SPEC: "# A1 설계\n\n지휘 기록 %d\n" % rig.code_n}, "spec %d" % rig.code_n)


def review(site, order, start, end, **kw) -> F.Review:
    return F.Review(site=site, site_tag="%s-%s" % (site, TARGET), target=TARGET, order=order,
                    range_start=start, range_end=end, **kw)


def qg(order: int) -> str:
    return "qg-w%d · %s" % (order, AT)


def obtained(start, end) -> F.Result:
    return F.Result(kind="얻음", seen_range="%s..%s" % (start, end))


def failed() -> F.Result:
    return F.Result(kind="얻지 못함", reason=NO_VERDICT)


def finding(text, handling=F.NO_HANDLING, kind="막는 지적") -> F.Finding:
    return F.Finding(kind=kind, text=text, handling=handling)


def answer(ident, kind, value, record="") -> F.Answer:
    return F.Answer(id=ident, kind=kind, answer=value, at=AT, record=record)


def put(rig, rv: F.Review) -> Path:
    folder = rig.archive("qg-%s-%s-built-%d" % (EPIC, rv.site_tag, rv.order))
    F.write_review(folder / F.STATE_NAME, rv)
    return folder


def handling_path(rig, n: int) -> Path:
    return rig.resource_dir("report", EPIC) / ("handling-%d.md" % n)


def ret(rig, n: int, moved="아직", worker=IMPL_WORKER) -> F.ReturnLine:
    return F.ReturnLine(worker=worker, at=AT, path=str(handling_path(rig, n)), moved=moved)


def first_closed_rereview(rig) -> str:
    """차례 1 — 첫 리뷰의 막는 지적을 고친 커밋 c2 로 처리해 재리뷰로 이어짐으로 닫혔다. c2 를 낸다."""
    c2 = code(rig)
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                    worker=qg(1), result=obtained(rig.base_sha, rig.c1),
                    blocking=[finding("지적 1 — src/a.py 의 값", "고친 커밋 " + c2)],
                    returns=[ret(rig, 1, "옮김")]))
    return c2


def at_cap(rig):
    """차례 1 · 2 를 재리뷰로 이어짐으로 닫는다 — 셋째 리뷰(좁은 재리뷰 둘째)가 지적 목록을 얻으면 세는
    재리뷰가 상한(2)에 닿는다. (c2, c3) — 차례 2 의 끝 · 지금 끝 — 을 낸다."""
    c2 = first_closed_rereview(rig)
    c3 = code(rig)
    put(rig, review("recheck", 2, rig.c1, c2, stage="닫힘", close_reason="재리뷰로 이어짐",
                    worker=qg(2), result=obtained(rig.c1, c2),
                    blocking=[finding("지적 2", "고친 커밋 " + c3)], returns=[ret(rig, 2, "옮김")]))
    return c2, c3


def var(label, **kw) -> SimpleNamespace:
    base = dict(label=label, alive=(), no_qg=False, kind=None, open_site=None, open_range=None,
                after=None, open_rc=None)
    base.update(kw)
    return SimpleNamespace(**base)


def b_r0(rig):
    return var("qg 없음 · 상태 파일 없음", no_qg=True)


def b_r8a(rig):
    return var("상태 파일 없음", open_site="premerge", open_range=(rig.base_sha, rig.c1))


def b_r1a(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1))
    return var("열림")


def _sending(rig) -> Path:
    folder = put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="보내는 중"))
    (folder / "qg-answered.yaml").write_text("answers: []\n", encoding="utf-8")
    (folder / "qg-answered-notices.txt").write_text("", encoding="utf-8")
    return folder


def b_r1b_pre_only(rig):
    _sending(rig)
    return var("보내기 전 파일만", kind="보냄", after={"R1e"})


def b_r1b_moved(rig):
    folder = _sending(rig)
    (folder / "handler-report.md").write_text("# 담당자 보고\n", encoding="utf-8")
    return var("담당자가 옮긴 파일 있음 · 결과 파일 없음", kind="돌아옴", after={"R3a"})


def b_r1c(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="보냄", worker=qg(1),
                    asks=[F.Ask(kind="담당자가 옮긴 질문", id="w1",
                                text="담당자가 멈춘 질문 — 이 파일을 지워도 되나")]))
    return var("담당자가 옮긴 질문", after={"R1e"})


def b_r1d(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="보냄", worker=qg(1)))
    return var("담당자가 살아 있다", alive=(QG_WORKER,))


def b_r1e(rig):
    folder = put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="보냄", worker=qg(1)))
    rig.write_result(folder, "clean", rig.base_sha, rig.c1)
    rig.write_intent_return(folder, [])
    return var("담당자가 없다 · 결과 파일 있음", after={"R9"})


def b_r2(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="에픽을 멈춤",
                    worker=qg(1), result=failed(),
                    answers=[answer("q-failed", "지적 목록을 얻지 못함", "이 에픽을 멈춘다")]))
    return var("에픽을 멈춤", after={"R3b"})


def b_r3a(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1), result=failed(),
                    asks=[F.Ask(kind="지적 목록을 얻지 못함", id="q-failed", text=NO_VERDICT)]))
    return var("얻지 못함 · 답 없음", after={"R3b"})


def b_r3b(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="다시 보냄",
                    worker=qg(1), result=failed(),
                    answers=[answer("q-failed", "지적 목록을 얻지 못함", "다시 보낸다")]))
    return var("다시 보냄 · 새 리뷰 없음", open_site="premerge", open_range=(rig.base_sha, rig.c1))


def b_r4_intent(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1),
                    asks=[F.Ask(kind="의도 점검", id="q1", text="이 기능이 정말 필요한가")]))
    return var("의도 점검", after={"R5"})


def b_r4_two_max(rig):
    c2, c3 = at_cap(rig)
    put(rig, review("recheck", 3, c2, c3, stage="돌아옴", worker=qg(3), result=obtained(c2, c3),
                    blocking=[finding("지적 3")],
                    asks=[F.Ask(kind="두 번까지", id="q-cap", text="세 번째로 돌려보낼까")]))
    return var("「두 번까지」", after={"R7d"})


def b_r4_unfixed(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1),
                    blocking=[finding("지적 1", "반박 — 설계가 그렇게 정했다")],
                    returns=[ret(rig, 1, "옮김")],
                    asks=[F.Ask(kind="고치지 않은 막는 지적", id="q-unfixed", text="반박한 지적을 어떻게 할까")]))
    return var("고치지 않은 막는 지적", after={"R9"})


def b_r5(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1),
                    answers=[answer("q1", "의도 점검", "의도다")]))
    return var("기록 경로 빔", after={"R9"})


def b_r6a_returned(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1), blocking=[finding("지적 1")],
                    answers=[answer("q1", "의도 점검", "잘못 골랐다", RECORD)]))
    return var("돌아옴 · 의도 점검 답 「잘못 골랐다」", after={"R6b"})


def b_r6a_closed(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="막는 지적 없음",
                    worker=qg(1), result=obtained(rig.base_sha, rig.c1),
                    filtered_wrong=[F.Filtered(id="q7", text="앞서 잘못 골랐다고 답한 방향")]))
    return var("닫힘 · 거른 「잘못 골랐다」 목록", after={"R6d"})


def _wrong_closed(rig, reason, mark=""):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason=reason,
                    close_mark=mark, worker=qg(1), result=obtained(rig.base_sha, rig.c1),
                    answers=[answer("q1", "의도 점검", "잘못 골랐다", RECORD)]))


def b_r6b(rig):
    _wrong_closed(rig, F.REASON_DESIGN)
    spec_only(rig)  # 고친 설계문서 커밋으로 끝이 움직여도 표시 전에는 열지 않는다(AC9)
    return var("설계 대화로 · 표시 없음")


def b_r6c(rig):
    _wrong_closed(rig, F.REASON_DESIGN, "%s %s" % (F.MARK_REIMPLEMENTED, LATER))
    tip = code(rig, "reimpl")
    return var("설계 대화로 · 「다시 구현됨」", open_site="premerge", open_range=(rig.base_sha, tip))


def b_r6d(rig):
    _wrong_closed(rig, F.REASON_RESPLIT)
    return var("재분해 신호 · 표시 없음")


def b_r6e(rig):
    _wrong_closed(rig, F.REASON_RESPLIT, "%s %s" % (F.MARK_RESPLIT_CONTINUE, LATER))
    return var("재분해 신호 · 「재분해 뒤 이어 감」", open_site="premerge", open_range=(rig.base_sha, rig.c1))


def _pending_return(rig, header: bool):
    rig.fix = code(rig)
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1), blocking=[finding("지적 1")],
                    returns=[ret(rig, 1)]))
    rig.write_handling(handling_path(rig, 1), ["1 · 고친 커밋 " + rig.fix], header=header)


def b_r7a(rig):
    _pending_return(rig, header=True)
    return var("「아직」 · 살아 있음", alive=(IMPL_WORKER,), after={"R7b"})


def b_r7b(rig):
    _pending_return(rig, header=True)
    return var("「아직」 · 없음 · 처리 파일 있음", after={"R7e"})


def b_r7c_first(rig):
    _pending_return(rig, header=False)
    return var("첫째 — 머리 없는 결과 파일", after={"R7a"})


def b_r7c_second(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1), blocking=[finding("지적 1")],
                    returns=[ret(rig, 1, "처리 파일 없이 끝남"), ret(rig, 2, worker="impl-w2")]))
    return var("둘째 — 처리 파일 없음", after={"R4"})


def b_r7d(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="돌아옴", worker=qg(1),
                    result=obtained(rig.base_sha, rig.c1), blocking=[finding("지적 1")]))
    return var("돌아옴 · 처리 없음 · 상한 안")


def b_r7e_under_cap(rig):
    c2 = first_closed_rereview(rig)
    return var("상한 안", open_site="recheck", open_range=(rig.c1, c2))


def b_r7e_two_max_answered(rig):
    c2, c3 = at_cap(rig)
    put(rig, review("recheck", 3, c2, c3, stage="닫힘", close_reason="재리뷰로 이어짐", worker=qg(3),
                    result=obtained(c2, c3), blocking=[finding("지적 3", F.USER_LEFT)],
                    answers=[answer("q-cap", "두 번까지", "남은 지적을 적고 머지 준비로 간다")]))
    c4 = code(rig)  # 「남은 지적을 적고」 를 고른 사이 기준 커밋이 올라왔다
    return var("상한에 닿음 · 「두 번까지」 답 있음", open_site="recheck", open_range=(c3, c4))


def b_r7f(rig):
    c2 = first_closed_rereview(rig)
    rig.git("reset", "-q", "--hard", rig.c1)  # 닫은 뒤 브랜치가 다시 쓰여 고친 커밋이 사라졌다
    spec_only(rig)
    rig.dropped = c2
    return var("기준 커밋 없음 · 리더 기록 커밋만", after={"R7d"})


def b_r8b(rig):
    put(rig, review("asked", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="막는 지적 없음",
                    worker=qg(1), result=obtained(rig.base_sha, rig.c1)))
    return var("이름으로 청한 리뷰만 닫힘", open_site="premerge", open_range=(rig.base_sha, rig.c1))


def b_r9_clean(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="막는 지적 없음",
                    worker=qg(1), result=obtained(rig.base_sha, rig.c1)))
    return var("막는 지적 없음")


def b_r9_user_left(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="사용자가 남김",
                    worker=qg(1), result=obtained(rig.base_sha, rig.c1),
                    blocking=[finding("지적 1", F.USER_LEFT)],
                    answers=[answer("q-unfixed", "고치지 않은 막는 지적",
                                    "반박을 받아들이고 남긴 지적으로 적는다")]))
    return var("사용자가 남김")


def b_r9_no_review(rig):
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="리뷰 없이 감",
                    worker=qg(1), result=failed(),
                    answers=[answer("q-failed", "지적 목록을 얻지 못함", "리뷰 없이 머지 준비로 간다")]))
    return var("리뷰 없이 감")


def b_rx_malformed(rig):
    text = F.render(review("premerge", 1, rig.base_sha, rig.c1))
    folder = rig.archive("qg-%s-premerge-%s-built-1" % (EPIC, TARGET))
    (folder / F.STATE_NAME).write_text(text.replace("- 단계: 열림", "- 단계: 도는 중"), encoding="utf-8")
    return var("단계 값이 틀 밖", open_rc=3)


def b_rx_mismatch(rig):
    code(rig)
    put(rig, review("premerge", 1, rig.base_sha, rig.c1, stage="닫힘", close_reason="재리뷰로 이어짐",
                    worker=qg(1), result=obtained(rig.base_sha, rig.c1), blocking=[finding("지적 1")]))
    return var("재리뷰로 이어짐인데 처리 없음 지적", open_rc=4)


BUILD = {
    "R0": [b_r0], "R8a": [b_r8a], "R1a": [b_r1a], "R1b": [b_r1b_pre_only, b_r1b_moved],
    "R1c": [b_r1c], "R1d": [b_r1d], "R1e": [b_r1e], "R2": [b_r2], "R3a": [b_r3a], "R3b": [b_r3b],
    "R4": [b_r4_intent, b_r4_two_max, b_r4_unfixed], "R5": [b_r5],
    "R6a": [b_r6a_returned, b_r6a_closed], "R6b": [b_r6b], "R6c": [b_r6c], "R6d": [b_r6d],
    "R6e": [b_r6e], "R7a": [b_r7a], "R7b": [b_r7b], "R7c": [b_r7c_first, b_r7c_second],
    "R7d": [b_r7d], "R7e": [b_r7e_under_cap, b_r7e_two_max_answered], "R7f": [b_r7f],
    "R8b": [b_r8b], "R9": [b_r9_clean, b_r9_user_left, b_r9_no_review],
    "RX": [b_rx_malformed, b_rx_mismatch],
}


# ---------------------------------------------------------------- 할 일 하기 — 다음 `next` 에 넘길 살아 있는 이름을 낸다

def do_open(rig, out):
    ok(rig, run_open(rig, rig.v.open_site), "open --site " + rig.v.open_site)
    return ()


def do_r1a(rig, out):
    ok(rig, run_send(rig, "start"), "send --phase start")
    ok(rig, run_send(rig, "done", QG_WORKER), "send --phase done")
    return ()


def do_r1b(rig, out):
    if rig.v.kind == "보냄":
        ok(rig, run_send(rig, "done", "qg-w2"), "send --phase done")
    else:
        ok(rig, run_back(rig), "back")
    return ()


def do_r1c(rig, out):
    ok(rig, run_record(rig, [item_answer("w1", "담당자가 옮긴 질문", "지우지 않는다",
                                         "지우지 않는다 — 다른 에픽이 쓴다")]), "record answer")
    return ()


def do_drop_alive(rig, out):
    return ()


def do_back(rig, out):
    ok(rig, run_back(rig), "back")
    return ()


def do_resend_answer(rig, out):
    ok(rig, run_record(rig, [item_answer("q-failed", "지적 목록을 얻지 못함", "다시 보낸다")]),
       "record answer 다시 보낸다")
    return ()


def do_r4(rig, out):
    label = rig.v.label
    if label == "의도 점검":
        item = item_answer("q1", "의도 점검", "의도다")
    elif label == "「두 번까지」":
        item = item_answer("q-cap", "두 번까지", "한 번 더 돌려보낸다")
    else:
        item = item_answer("q-unfixed", "고치지 않은 막는 지적", "반박을 받아들이고 남긴 지적으로 적는다")
    ok(rig, run_record(rig, [item]), "record answer " + label)
    return ()


def do_r5(rig, out):
    ok(rig, run_record(rig, [{"kind": "record_path", "question": "q1", "path": RECORD}]),
       "record record_path")
    return ()


def do_r6a(rig, out):
    if rig.v.label.startswith("돌아옴"):
        item = {"kind": "route", "question": "q1", "value": "설계 대화로"}
    else:
        item = {"kind": "route", "question": "q7", "value": "재분해 신호"}
    ok(rig, run_record(rig, [item]), "record route")
    return ()


def do_r6b(rig, out):
    code(rig, "reimpl")  # 설계 대화 · spec 승인 뒤 다시 구현했다
    ok(rig, run_record(rig, [{"kind": "mark", "value": F.MARK_REIMPLEMENTED}]), "record mark")
    return ()


def do_r6d(rig, out):
    ok(rig, run_record(rig, [{"kind": "mark", "value": F.MARK_RESPLIT_CONTINUE}]), "record mark")
    return ()


def do_r7b(rig, out):
    ok(rig, run_record(rig, [{"kind": "return_moved", "value": "옮김"},
                             {"kind": "handling", "finding": 1, "value": "고친 커밋 " + rig.fix}]),
       "record return_moved 옮김")
    return ()


def do_r7c(rig, out):
    ok(rig, run_record(rig, [{"kind": "return_moved", "value": "처리 파일 없이 끝남"}]),
       "record return_moved 처리 파일 없이 끝남")
    if rig.v.label.startswith("첫째"):  # 첫 번째면 다시 돌려보낸다 — 「돌려보냄」 을 새로 적는다
        ok(rig, run_record(rig, [{"kind": "return", "worker": "impl-w2",
                                  "handling_file": str(handling_path(rig, 2))}]), "record return")
        return ("impl-w2",)
    return ()


def do_r7d(rig, out):
    ok(rig, run_record(rig, [{"kind": "return", "worker": IMPL_WORKER,
                              "handling_file": str(handling_path(rig, 1))}]), "record return")
    return (IMPL_WORKER,)


def do_r7f(rig, out):
    ok(rig, run_record(rig), "record (적을 값 없이)")
    return ()


DO = {
    "R0": None, "R9": None, "RX": None,
    "R8a": do_open, "R1a": do_r1a, "R1b": do_r1b, "R1c": do_r1c, "R1d": do_drop_alive, "R1e": do_back,
    "R2": do_resend_answer, "R3a": do_resend_answer, "R3b": do_open, "R4": do_r4, "R5": do_r5,
    "R6a": do_r6a, "R6b": do_r6b, "R6c": do_open, "R6d": do_r6d, "R6e": do_open,
    "R7a": do_drop_alive, "R7b": do_r7b, "R7c": do_r7c, "R7d": do_r7d, "R7e": do_open, "R7f": do_r7f,
    "R8b": do_open,
}


# 「지휘자가 가린다」 줄에서 지휘자가 대신 부르는 명령 — (하위 명령 이름, 하는 함수)
def choose_r1b(rig):
    ok(rig, run_send(rig, "done", "qg-w9"), "send --phase done (하니스 목록에서 찾은 담당자)")


def choose_r1c(rig):
    do_r1c(rig, None)
    ok(rig, run_back(rig), "back (이어 부를 수 없음)")


def choose_r7c(rig):
    ok(rig, run_record(rig, [{"kind": "return_moved", "value": "옮김"},
                             {"kind": "handling", "finding": 1, "value": "반박 — 설계가 그렇게 정했다"}]),
       "record (대화에 남은 하위 agent 의 처리)")


CHOOSE = {"R1b": ("send", choose_r1b), "R1c": ("back", choose_r1c), "R7c": ("record", choose_r7c)}

OPEN_ROWS = frozenset(r for r, (_n, kinds) in EXPECTED.items() if kinds == ("열기",))
# 마지막 리뷰가 닫혀 있어도 이름으로 청한 리뷰를 받지 않는 줄 — 까닭 2 와 까닭 6 의 표시 없는 줄(설계 §2
# 「앞 리뷰가 닫힌 뒤에 보낸다」 · AC33 · D77 · D78). 표시 뒤(R6c · R6e)와 그 밖의 닫힘에서는 받는다.
ASKED_REFUSED = frozenset(r for r, (n, kinds) in EXPECTED.items() if n in (2, 6) and kinds != ("열기",))


class TestQgReviewStateSweep(unittest.TestCase):
    def variants(self, ids=None):
        for row_id in ORDER if ids is None else ids:
            for build in BUILD[row_id]:
                yield row_id, build

    def build(self, build):
        rig = fresh(self)
        rig.v = build(rig)
        return rig, rig.v

    def assert_row(self, out, row_id, where: str):
        self.assertEqual(out.id, row_id, "%s — 맞은 줄이 다르다\n%s" % (where, out.text))

    def test_table_ids_match_design(self):
        self.assertEqual(len(ORDER), TABLE_ROWS)
        self.assertEqual(len(EXPECTED_IDS), TABLE_ROWS)
        self.assertEqual(set(EXPECTED), EXPECTED_IDS)
        self.assertEqual(set(BUILD), EXPECTED_IDS)
        self.assertEqual(set(DO), EXPECTED_IDS)
        self.assertEqual(set(AFTER), EXPECTED_IDS - NO_ACTION)
        self.assertTrue(all(BUILD[r] for r in ORDER))
        self.assertTrue(all(DO[r] is None for r in NO_ACTION))
        for _row, (_n, kinds) in EXPECTED.items():
            self.assertTrue(set(kinds) <= set(KINDS), kinds)
        rows = next_rows()
        self.assertEqual([row.id for row in rows], ORDER)
        for row in rows:
            want_reason, want_kinds = EXPECTED[row.id]
            self.assertEqual(row.reason, want_reason, row.id)
            self.assertEqual(kinds_of(row.kind), set(want_kinds), row.id)
        chosen = {row.id for row in rows if row.conductor_choices}
        self.assertEqual(chosen, set(CHOOSE))
        by_id = {row.id: row for row in rows}
        for row_id, (command, _fn) in CHOOSE.items():
            names = {choice.split()[0] for choice in by_id[row_id].conductor_choices}
            self.assertIn(command, names, row_id)

    def test_each_row_yields_its_action(self):
        rows = {row.id: row for row in next_rows()}
        for row_id, build in self.variants():
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                out = run_next(rig, v.alive, v.no_qg)
                self.assert_row(out, row_id, v.label)
                self.assertIn(out.kind, kinds_of(rows[row_id].kind), out.text)
                if v.kind is not None:
                    self.assertEqual(out.kind, v.kind, out.text)
                if row_id == "RX":
                    self.assertEqual(out.kind, "상태 보이기", out.text)
                    continue
                self.assertEqual(out.reason, reason_text(rows[row_id].reason), out.text)

    def test_action_resolves_reason(self):
        rows = {row.id: row for row in next_rows()}
        for row_id, build in self.variants([r for r in ORDER if r not in NO_ACTION]):
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                out = run_next(rig, v.alive, v.no_qg)
                self.assert_row(out, row_id, v.label)
                alive = DO[row_id](rig, out)
                after = run_next(rig, alive, v.no_qg)
                self.assertIsNotNone(after.id, after.text)
                self.assertNotEqual(after.id, row_id, "할 일 뒤에도 같은 줄이다\n" + after.text)
                self.assertNotEqual(after.id, "RX", "할 일 뒤 끝 줄이다\n" + after.text)
                self.assertIn(after.id, AFTER[row_id], "「그 할 일 뒤 상태」 칸 밖이다\n" + after.text)
                if v.after is not None:  # 그 변형이 적은 답 · 처리로 §4 가 정하는 다음 줄
                    self.assertIn(after.id, v.after, v.label + "\n" + after.text)

    def test_conductor_choices_accepted(self):
        for row_id, build in self.variants(list(CHOOSE)):
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                self.assert_row(run_next(rig, v.alive, v.no_qg), row_id, v.label)
                CHOOSE[row_id][1](rig)
                after = run_next(rig)
                self.assertIn(after.id, CHOICE_AFTER[row_id], after.text)

    def test_next_open_is_accepted(self):
        for row_id, build in self.variants([r for r in ORDER if r in OPEN_ROWS]):
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                out = run_next(rig, v.alive, v.no_qg)
                self.assert_row(out, row_id, v.label)
                self.assertEqual(out.kind, "열기", out.text)
                before = state_count(rig)
                proc = run_open(rig, v.open_site)
                ok(rig, proc, "open --site " + v.open_site)
                self.assertTrue(proc.stdout.startswith("보관 폴더 · "), proc.stdout)
                self.assertEqual(state_count(rig), before + 1)
                new = last(rig)
                self.assertEqual((new.site, new.stage, new.order), (v.open_site, "열림", before + 1))
                start, end = v.open_range
                self.assertTrue(same_commit(new.range_start, start) and same_commit(new.range_end, end),
                                "범위 %s..%s — 바라는 %s..%s" % (new.range_start, new.range_end, start, end))

    def test_open_refused_where_next_does_not_open(self):
        # R0 은 상태 파일이 없는 R8a 와 같은 상태다 — 「qg 없음」 은 `next` 의 인자라 `open` 은 받는다.
        ids = [r for r in ORDER if r not in OPEN_ROWS and r != "R0"]
        for row_id, build in self.variants(ids):
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                before = state_count(rig)
                if row_id == "RX":  # 꼴이 깨졌으면 rc 3(읽지 못함), 칸끼리 맞지 않으면 rc 4(받지 않음)
                    for site in ("premerge", "recheck", "asked"):
                        proc = run_open(rig, site)
                        self.assertEqual(proc.returncode, v.open_rc, site + "\n" + proc.stdout + proc.stderr)
                        self.assertEqual(state_count(rig), before, site)
                    continue
                for site in ("premerge", "recheck"):
                    proc = run_open(rig, site)
                    self.assertEqual(proc.returncode, 4, "%s\n%s%s" % (site, proc.stdout, proc.stderr))
                    self.assertEqual(state_count(rig), before, site)
                if last(rig).stage == "닫힘" and row_id not in ASKED_REFUSED:
                    ok(rig, run_open(rig, "asked"), "open --site asked (마지막 리뷰가 닫힘)")
                    self.assertEqual(state_count(rig), before + 1)
                    continue
                proc = run_open(rig, "asked")
                self.assertEqual(proc.returncode, 4, proc.stdout + proc.stderr)
                self.assertEqual(state_count(rig), before)
                now = run_next(rig, (), v.no_qg)
                lines = proc.stdout.splitlines()
                self.assertTrue(lines and lines[0].startswith("까닭 · "), proc.stdout)
                self.assertIn("할 일 · %s · " % now.kind, proc.stdout, proc.stdout + "\n--- next ---\n" + now.text)
                self.assertIn("줄 · %s" % now.id, lines, proc.stdout + "\n--- next ---\n" + now.text)

    def test_asked_accepted_after_mark(self):
        # 거절만 재면 늘 거절하는 구현도 통과한다 — 표시가 붙은 뒤에는 이름으로 청한 리뷰를 받는다(D77).
        self.assertEqual(ASKED_REFUSED, {"R2", "R6a", "R6b", "R6d"})
        for row_id, build in self.variants(["R6c", "R6e"]):
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                self.assert_row(run_next(rig, v.alive, v.no_qg), row_id, v.label)
                before = state_count(rig)
                ok(rig, run_open(rig, "asked"), "open --site asked (표시 뒤)")
                self.assertEqual(state_count(rig), before + 1)
                self.assertEqual((last(rig).site, last(rig).stage), ("asked", "열림"))

    def test_closed_reasons_sweep(self):
        cases = [
            ("막는 지적 없음", [b_r9_clean, b_r8b, b_r6a_closed]),
            ("재리뷰로 이어짐", [b_r7e_under_cap, b_r7e_two_max_answered, b_r7f]),
            ("사용자가 남김", [b_r9_user_left]),
            ("리뷰 없이 감", [b_r9_no_review]),
            ("다시 보냄", [b_r3b]),
            (F.REASON_DESIGN, [b_r6b, b_r6c]),
            (F.REASON_RESPLIT, [b_r6d, b_r6e]),
            ("에픽을 멈춤", [b_r2]),
        ]
        self.assertEqual({reason for reason, _ in cases}, set(F.CLOSE_REASONS))
        for reason, builds in cases:
            for build in builds:
                with self.subTest(reason=reason, variant=build.__name__):
                    rig, v = self.build(build)
                    self.assertEqual((last(rig).stage, last(rig).close_reason), ("닫힘", reason))
                    out = run_next(rig, v.alive, v.no_qg)
                    self.assertIn(out.id, EXPECTED_IDS - {"RX"}, out.text)

    def test_gate_open_states_go_to_merge(self):
        for row_id, build in self.variants(["R0", "R9"]):
            with self.subTest(row=row_id, variant=build.__name__):
                rig, v = self.build(build)
                out = run_next(rig, v.alive, v.no_qg)
                self.assert_row(out, row_id, v.label)
                self.assertEqual(out.kind, "머지 준비", out.text)
                proc = run_gate(rig, v.no_qg)
                self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
                first = proc.stdout.splitlines()[:1]
                if v.no_qg:
                    self.assertEqual(first, ["관문 · 열림 — qg 리뷰 없음(quality-gates 가 설치돼 있지 않다)"])
                    self.assertEqual(state_count(rig), 0)
                else:
                    self.assertEqual(first, ["관문 · 열림"])

    def assert_two_max_turn(self, rig, label):
        """「두 번까지」 의 답이 없는 동안 — 사용자 차례(R4)이고 돌려보내기 · 열기를 내지 않으며 좁은 재리뷰를 받지 않는다."""
        self.assertIn("두 번까지", [a.kind for a in last(rig).asks], label)
        out = run_next(rig)
        self.assert_row(out, "R4", label)
        self.assertNotIn(out.kind, ("돌려보낸다", "열기"), out.text)
        self.assertTrue(any(x.startswith("물을 것 · 두 번까지") for x in out.lines), out.text)
        before = state_count(rig)
        proc = run_open(rig, "recheck")
        self.assertEqual(proc.returncode, 4, proc.stdout + proc.stderr)
        self.assertEqual(state_count(rig), before)

    def test_cap_cases(self):
        with self.subTest(case="(가) 막는 지적 없이 닫힌 뒤 고른 제안"):
            # 「답 적기」 가 고른 제안을 마지막 리뷰에 적고 「돌아옴」 으로 되돌리며 「두 번까지」 를 적은 상태.
            rig = fresh(self)
            c2, c3 = at_cap(rig)
            put(rig, review("recheck", 3, c2, c3, stage="돌아옴", worker=qg(3), result=obtained(c2, c3),
                            blocking=[finding("제안 — 이름을 바꾼다", kind="고른 제안")],
                            asks=[F.Ask(kind="두 번까지", id="q-cap", text="세 번째로 돌려보낼까")]))
            self.assert_two_max_turn(rig, "(가)")

        with self.subTest(case="(나) 「한 번 더」 로 연 재리뷰가 막는 지적을 안고 옴"):
            rig = fresh(self)
            c2, c3 = at_cap(rig)
            c4 = code(rig)
            put(rig, review("recheck", 3, c2, c3, stage="닫힘", close_reason="재리뷰로 이어짐", worker=qg(3),
                            result=obtained(c2, c3), blocking=[finding("지적 3", "고친 커밋 " + c4)],
                            returns=[ret(rig, 3, "옮김")],
                            answers=[answer("q-cap", "두 번까지", "한 번 더 돌려보낸다")]))
            folder = put(rig, review("recheck", 4, c3, c4, stage="보냄", worker=qg(4)))
            rig.write_result(folder, "defect", c3, c4, blocking=["새 지적 4 — src/a.py"])
            rig.write_intent_return(folder, [])
            ok(rig, run_back(rig), "back")
            self.assert_two_max_turn(rig, "(나)")

        with self.subTest(case="상한에 닿았는데 거른 「잘못 골랐다」 목록"):
            rig = fresh(self)
            c2, c3 = at_cap(rig)
            folder = put(rig, review("recheck", 3, c2, c3, stage="보냄", worker=qg(3)))
            rig.write_result(folder, "defect", c2, c3, blocking=["지적 3 — src/a.py"],
                             filtered=[("q9", "방향이 맞나")], wrong=[("q9", "방향이 맞나")])
            rig.write_intent_return(folder, [], answered_filtered=1)
            ok(rig, run_back(rig), "back")
            self.assertNotIn("두 번까지", [a.kind for a in last(rig).asks])
            self.assert_row(run_next(rig), "R6a", "잘못 골랐다")

        with self.subTest(case="예외 — 「두 번까지」 답 뒤 기준 커밋으로 재리뷰로 이어짐"):
            rig = fresh(self)
            rig.v = b_r7e_two_max_answered(rig)
            out = run_next(rig)
            self.assert_row(out, "R7e", "예외")
            self.assertEqual(out.kind, "열기", out.text)
            ok(rig, run_open(rig, "recheck"), "open --site recheck")

    def resplit_then_open(self, rig) -> Path:
        """상한에 닿은 PR 이 재분해 신호로 닫혔다 → 표시 전 R6d · 열기 거절 → 표시 뒤 R6e · 첫 리뷰(PR 전체)."""
        c2, c3 = at_cap(rig)
        put(rig, review("recheck", 3, c2, c3, stage="닫힘", close_reason=F.REASON_RESPLIT, worker=qg(3),
                        result=obtained(c2, c3), blocking=[finding("지적 3")],
                        answers=[answer("q1", "의도 점검", "잘못 골랐다", RECORD)]))
        self.assert_row(run_next(rig), "R6d", "표시 전")
        before = state_count(rig)
        for site in ("premerge", "recheck"):
            self.assertEqual(run_open(rig, site).returncode, 4, site)
        self.assertEqual(state_count(rig), before)
        ok(rig, run_record(rig, [{"kind": "mark", "value": F.MARK_RESPLIT_CONTINUE}]), "record mark")
        self.assertTrue(last(rig).close_mark.startswith(F.MARK_RESPLIT_CONTINUE + " "), last(rig).close_mark)
        self.assert_row(run_next(rig), "R6e", "표시 뒤")
        proc = ok(rig, run_open(rig, "premerge"), "open --site premerge")
        new = last(rig)
        self.assertEqual((new.site, new.order, new.stage), ("premerge", 4, "열림"))
        self.assertTrue(same_commit(new.range_start, rig.base_sha) and same_commit(new.range_end, c3),
                        "PR 전체가 아니다: %s..%s" % (new.range_start, new.range_end))
        ok(rig, run_send(rig, "start"), "send --phase start")
        ok(rig, run_send(rig, "done", "qg-w4"), "send --phase done")
        return Path(proc.stdout.splitlines()[0][len("보관 폴더 · "):])

    def test_resplit_mark(self):
        with self.subTest(case="관문이 표시 뒤 첫 리뷰부터 센다"):
            rig = fresh(self)
            folder = self.resplit_then_open(rig)
            new = last(rig)
            rig.write_result(folder, "clean", new.range_start, new.range_end)
            rig.write_intent_return(folder, [])
            ok(rig, run_back(rig), "back")
            proc = run_gate(rig)
            self.assertEqual(proc.returncode, 0, proc.stdout + proc.stderr)
            self.assert_row(run_next(rig), "R9", "표시 뒤 첫 리뷰가 깨끗함")

        with self.subTest(case="세는 재리뷰가 표시 뒤 첫 리뷰부터 센다"):
            rig = fresh(self)
            folder = self.resplit_then_open(rig)
            new = last(rig)
            rig.write_result(folder, "defect", new.range_start, new.range_end, blocking=["새 지적 — src/a.py"])
            rig.write_intent_return(folder, [])
            ok(rig, run_back(rig), "back")
            self.assertNotIn("두 번까지", [a.kind for a in last(rig).asks])
            out = run_next(rig)
            self.assert_row(out, "R7d", "상한 안 — 표시 앞 재리뷰 둘을 세지 않는다")
            self.assertEqual(out.kind, "돌려보낸다", out.text)


if __name__ == "__main__":
    unittest.main()
