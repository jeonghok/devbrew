#!/usr/bin/env python3
"""seed_edit_screen.py — 저자 편집 덩어리를 사람이 볼 화면으로 조립한다. 파일을 쓰지 않는다.

  preview <base> <seed>                     기준 사본 → seed 의 덩어리 JSON(`hunks` 와 같은 꼴 ·
                                            seed_sha256 포함). 공시 기록(.shown)을 남기지 않는다.
  screen --hunks <덩어리 JSON> --reasons <이유 파일> --state-dir <원장 폴더> [--final]
                                            화면 JSON({"text", "hunks", "questions", "notices"}).
                                            선택지 설명은 질문 기준 길이(DEVBREW_DOCREVIEW_ASK_WIDTH ·
                                            기본 110) 안에 든다 — 값이 잘못되면 rc 2.
  mark-used --hunks <덩어리 JSON> --reasons <이유 파일> --state-dir <원장 폴더> --ids <쉼표로 이은 번호>
                                            이유 파일이 댄 지적 id 를 쓴 지적 목록에 더한다.
rc: 0 정상 · 2 입력 오류와 그 밖의 예외 · 3 기준 사본 부재(preview).
"""
from __future__ import annotations

import argparse
import difflib
import json
import os
import pathlib
import sys

import docreview_advice
import docreview_config
import nofollow_write
import seed_edit_diff
from seed_provenance import MARK, SENT_SPLIT_RE, norm

NO_REASON = "대응하는 지적 없음 — 저자가 스스로 고침"
IND = "   "
USED_FILE = "hunk-used-findings.txt"
RECOMMEND_NOTE = ("(권장) 은 저자가 댄 지적을 사용자가 적용하기로 했다는 뜻입니다 — "
                  "편집이 그 지적에 맞는지는 아래 문장으로 직접 보세요")


def line_parts(line: str) -> list[tuple[str, str]]:
    parts: list[tuple[str, str]] = []
    gap, start = "", 0
    pieces = []
    for m in SENT_SPLIT_RE.finditer(line):
        pieces.append((gap, line[start:m.start()]))
        gap, start = m.group(0), m.end()
    pieces.append((gap, line[start:]))
    for g, piece in pieces:
        if (piece.strip() == MARK or not piece.strip()) and parts:
            pg, pu = parts[-1]
            parts[-1] = (pg, pu + g + piece)
        elif not piece.strip():
            continue
        else:
            parts.append(("" if not parts else g, piece))
    return parts


def line_units(line: str) -> list[str]:
    return [u for _, u in line_parts(line)]


def sentence_diff(base_keys: list[str], seed_keys: list[str]) -> tuple[list[int], list[int]]:
    rem: list[int] = []
    add: list[int] = []
    sm = difflib.SequenceMatcher(a=base_keys, b=seed_keys, autojunk=False)
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag != "equal":
            rem.extend(range(i1, i2))
            add.extend(range(j1, j2))
    return rem, add


def _cells(lines: list[str], gone: set) -> list[tuple]:
    """줄마다 (종류, 글자, 첫 남은 단위의 앞 공백). 그 단위가 줄의 원래 첫 단위면 앞 공백은 None
    — 상대 쪽의 어떤 앞 공백과도 맞는다."""
    cells = []
    k = 0
    for line in lines:
        parts = line_parts(line)
        if not parts:
            cells.append(("빈 줄", line, None))
            continue
        keep = []
        for pos, (g, u) in enumerate(parts):
            if k not in gone:
                keep.append((pos, g, u))
            k += 1
        if not keep:
            cells.append(("빈 자리", "", None))
        else:
            lead = None if keep[0][0] == 0 else keep[0][1]
            cells.append(("글", keep[0][2] + "".join(g + u for _, g, u in keep[1:]), lead))
    return cells


def _cell_match(a: tuple, b: tuple) -> bool:
    return a[:2] == b[:2] and (a[2] is None or b[2] is None or a[2] == b[2])


def _drop_holes(cells: list[tuple]) -> list[tuple]:
    dropped = [False] * len(cells)
    for i, c in enumerate(cells):
        if c[0] != "빈 자리":
            continue
        dropped[i] = True
        for j in (i - 1, i + 1):
            if 0 <= j < len(cells) and not dropped[j] and cells[j][0] == "빈 줄":
                dropped[j] = True
                break
    return [c for c, d in zip(cells, dropped) if not d]


def _same_skeleton(removed: list[str], added: list[str], rem: set, add: set) -> bool:
    b = _cells(removed, rem)
    s = _cells(added, add)
    b_holes = any(c[0] == "빈 자리" for c in b)
    s_holes = any(c[0] == "빈 자리" for c in s)
    if not s_holes:
        b = _drop_holes(b)
    if not b_holes:
        s = _drop_holes(s)
    return len(b) == len(s) and all(_cell_match(x, y) for x, y in zip(b, s))


def parse_reasons(path: str, version: str, hunk_ids: set) -> dict:
    """이유 파일을 읽는다. 첫 줄 `seed_sha256 <판본>`, 아래는 `<덩어리 번호><탭><지적 id 들(쉼표) | 없음>`."""
    out = {"by_hunk": {}, "dropped": 0, "stale": False, "unreadable": False, "present": False}
    p = pathlib.Path(path)
    if not p.is_file():
        return out
    out["present"] = True
    try:
        text = p.read_text(encoding="utf-8")
    except (OSError, UnicodeError):
        out["unreadable"] = True
        return out
    lines = [ln.rstrip("\r") for ln in text.split("\n")]
    if lines and lines[-1] == "":
        lines.pop()
    if not lines or lines[0].split() != ["seed_sha256", version]:
        out["stale"] = True
        return out
    for ln in lines[1:]:
        if not ln.strip():
            continue
        num, tab, val = ln.partition("\t")
        pieces = [x.strip() for x in val.split(",")]
        if (not tab or not num.isascii() or not num.isdigit() or int(num) not in hunk_ids
                or any(not x for x in pieces)):
            out["dropped"] += 1
            continue
        ent = out["by_hunk"].setdefault(int(num), {"ids": [], "self": False})
        for x in pieces:
            if x == "없음":
                ent["self"] = True
            elif x not in ent["ids"]:
                ent["ids"].append(x)
    return out


def load_ledger(state_dir: str):
    """리뷰 원장을 읽기만 한다. 어떤 이유로든 읽지 못하면 None."""
    try:
        import docreview_state
        return docreview_state.load_state(state_dir)
    except Exception:
        return None


def read_used(state_dir: str):
    """앞 화면에서 이미 댄 지적의 id 집합. 읽지 못하면 None(없는 파일은 빈 집합)."""
    p = pathlib.Path(state_dir) / USED_FILE
    if p.is_symlink():
        return None
    if not p.exists():
        return set()
    try:
        return {x.strip() for x in p.read_text(encoding="utf-8").split("\n") if x.strip()}
    except (OSError, UnicodeError):
        return None


def finding_status(st, fid: str, used):
    """(갈래, 이유 조각). 갈래는 confirmed · used · answered · unverified."""
    f = st.get("findings", {}).get(fid) if isinstance(st, dict) else None
    if not isinstance(f, dict):
        return "unverified", "저자가 댄 지적 %s 은 원장에서 확인되지 않는다" % fid
    head = "지적 「%s」(%s) — " % (norm(str(f.get("summary", ""))), fid)
    fix = st.get("fixes", {}).get(fid)
    if isinstance(fix, dict) and fix.get("state") in ("intent_passed", "applied"):
        why = "사용자가 「적용」 으로 처분"
    elif _adopted(st, fid):
        why = "사용자가 채택"
    else:
        ask = st.get("asks", {}).get(fid)
        if isinstance(ask, dict) and ask.get("answered"):
            return "answered", head + "사용자가 답한 열린 질문"
        return "unverified", "저자가 댄 지적 %s 은 원장에서 확인되지 않는다" % fid
    if used is not None and fid in used:
        return "used", head + "앞 화면에서 이미 댄 지적"
    return "confirmed", head + why


def _adopted(st: dict, fid: str) -> bool:
    """그 지적의 계보에서 마지막 결정이 채택이고 그 결정이 이 id 를 낼 때만 참이다."""
    dec = st.get("decides", {}).get(fid)
    if not isinstance(dec, dict) or dec.get("kind") == "post":
        return False
    f = st.get("findings", {}).get(fid)
    lin = f.get("lineage") if isinstance(f, dict) else None
    last = None
    for e in st.get("decision_log") or []:
        if not isinstance(e, dict):
            continue
        if fid in (e.get("finding_ids") or []) or (lin and e.get("lineage") == lin):
            last = e
    return last is not None and last.get("choice") == "adopt" and fid in (last.get("finding_ids") or [])


def hunk_view(h: dict) -> dict:
    b_units = [u for line in h["removed"] for u in line_units(line)]
    s_units = [u for line in h["added"] for u in line_units(line)]
    bk = [norm(u) for u in b_units]
    sk = [norm(u) for u in s_units]
    rem, add = sentence_diff(bk, sk)
    rem_set, add_set = set(rem), set(add)
    kb = [k for i, k in enumerate(bk) if i not in rem_set]
    ks = [k for i, k in enumerate(sk) if i not in add_set]
    view = {"id": h["id"], "removed_sentences": [], "added_sentences": [],
            "removed_moved": [], "added_moved": [], "removed_idx": [], "added_idx": [], "kept": 0}
    if kb != ks:
        view.update(shape=1, summary="문장으로 가르지 못함")
        return view
    rem_idx, add_idx = sorted(rem_set), sorted(add_set)
    view.update(removed_sentences=[b_units[i].strip() for i in rem_idx],
                added_sentences=[s_units[j].strip() for j in add_idx],
                removed_moved=[False] * len(rem_idx), added_moved=[False] * len(add_idx),
                removed_idx=rem_idx, added_idx=add_idx, kept=len(kb))
    if not rem_idx and not add_idx:
        view.update(shape=2, summary="바뀐 문장 없음")
        return view
    shape = 4 if _same_skeleton(h["removed"], h["added"], rem_set, add_set) else 3
    bits = []
    if rem_idx:
        bits.append("뺀 문장 %d개" % len(rem_idx))
    if add_idx:
        bits.append("더한 문장 %d개" % len(add_idx))
    bits.append("그대로 %d문장" % len(kb))
    view.update(shape=shape, summary=" · ".join(bits))
    return view


def mark_moves(views: list[dict]) -> None:
    pending: dict[str, list[tuple[int, int]]] = {}
    for vi, v in enumerate(views):
        for ai, s in enumerate(v["added_sentences"]):
            pending.setdefault(norm(s), []).append((vi, ai))
    for v in views:
        for ri, s in enumerate(v["removed_sentences"]):
            slots = pending.get(norm(s))
            if slots:
                vi, ai = slots.pop(0)
                v["removed_moved"][ri] = True
                views[vi]["added_moved"][ai] = True


def _render(k: int, h: dict, v: dict, pieces: list) -> list[str]:
    out = ["%d) 기준 %s → 현재 %s · %s" % (k, seed_edit_diff._span(*h["base"]),
                                         seed_edit_diff._span(*h["seed"]), v["summary"])]
    out += [IND + "고친 이유(저자가 댐): " + piece for piece in pieces]
    if v["shape"] == 1:
        out.append(IND + "문장으로 가르지 못함 — 줄 전체를 보인다")
    elif v["shape"] == 2:
        out.append(IND + "바뀐 문장 없음 — 줄 전체를 보인다")
    else:
        for s, moved in zip(v["removed_sentences"], v["removed_moved"]):
            out.append(IND + ("뺀 문장(자리 옮김): " if moved else "뺀 문장: ") + s)
        for s, moved in zip(v["added_sentences"], v["added_moved"]):
            out.append(IND + ("더한 문장(자리 옮김): " if moved else "더한 문장: ") + s)
        if v["shape"] == 3:
            out.append(IND + "문단 나눔 · 공백도 바뀜")
    if v["shape"] != 4:
        out += [IND + "- " + line for line in h["removed"]]
        out += [IND + "+ " + line for line in h["added"]]
    return out


def split_sizes(n: int) -> list[int]:
    """덩어리 n 개를 질문마다 둘에서 넷으로 나눈 크기들(n 이 4 이하면 [n])."""
    if n <= 0:
        return []
    if n <= 4:
        return [n]
    sizes = [4] * (n // 4)
    if n % 4:
        sizes.append(n % 4)
    if sizes[-1] == 1:
        sizes[-2:] = [3, 2]
    return sizes


MULTI_QUESTION = "그대로 둘 곳을 고르세요. 고르지 않은 곳은 되돌립니다. 전부 되돌리려면 기타 칸에 적어 주세요."
KEEP_HEAD = "얻음: 편집이 남는다(%s · 고친 이유(저자가 댐): "
KEEP_TAIL = ") · 내줌: 틀린 편집도 남는다"
REVERT_DESC = ("얻음: 기준 사본의 글로 돌아간다 · "
               "내줌: 편집이 고친 것도 사라진다 — 지적을 고친 편집이면 그 지적은 안 고친 채 남는다")
REASON_MIN = 12   # 요약이 길어 자리가 모자라도 이유 줄은 이만큼(「…」 포함) 싣는다


def _unmark(s: str) -> str:
    """설명 표지(얻음: · 내줌:)를 흉내 낸 글자가 설명의 꼴을 흐리지 않게 콜론 앞에 공백을 넣는다."""
    return s.replace("얻음:", "얻음 :").replace("내줌:", "내줌 :")


def keep_desc(v: dict, width: int) -> str:
    """「그대로 둔다」 의 설명 — 얻음에 덩어리 요약(그대로)과 고친 이유(권장의 근거 — 넘치면 끝을 「…」 로)를 싣는다.
    전체가 질문 기준 길이(`width`) 안에 들게 이유 줄만 엔진의 줄임(`docreview_advice.clip`)으로 줄인다."""
    head = KEEP_HEAD % v["summary"]
    room = max(width - len(head) - len(KEEP_TAIL), REASON_MIN)
    return head + docreview_advice.clip(_unmark(v["reason"]), room) + KEEP_TAIL


def build_questions(views: list[dict], width: int = docreview_config.ASK_WIDTH_DEFAULT) -> list[dict]:
    if not views:
        return []
    views = sorted(views, key=lambda v: v["id"])
    if len(views) == 1:
        v = views[0]
        keep = "그대로 둔다" + (" (권장)" if v["recommend"] else "")
        return [{"header": "저자 편집", "question": "저자 편집 1곳을 그대로 둘까요?", "multi": False,
                 "hunk_ids": [v["id"]],
                 "options": [{"label": keep, "description": keep_desc(v, width), "hunk_id": v["id"]},
                             {"label": "되돌린다", "description": REVERT_DESC, "hunk_id": v["id"]}]}]
    sizes = split_sizes(len(views))
    out, start = [], 0
    for size in sizes:
        group = views[start:start + size]
        start += size
        ordered = [v for v in group if v["recommend"]] + [v for v in group if not v["recommend"]]
        options = []
        for v in ordered:
            n = v["id"]
            options.append({"label": "%d번 그대로 둔다" % n + (" (권장)" if v["recommend"] else ""),
                            "description": keep_desc(v, width), "hunk_id": n})
        first, last = group[0]["id"], group[-1]["id"]
        out.append({"header": "저자 편집" if len(sizes) == 1 else "편집 %d–%d" % (first, last),
                    "question": MULTI_QUESTION, "multi": True,
                    "hunk_ids": [v["id"] for v in group], "options": options})
    return out


def build_screen(hunks_doc: dict, reasons_path: str, state_dir: str, final: bool = False,
                 width: int = docreview_config.ASK_WIDTH_DEFAULT) -> dict:
    hunks = hunks_doc["hunks"]
    views = [hunk_view(h) for h in hunks]
    mark_moves(views)
    if not hunks:
        for v in views:
            v["reason"], v["recommend"] = NO_REASON, False
        return {"text": "저자 편집 없음", "hunks": [], "questions": [], "notices": []}
    rs = parse_reasons(reasons_path, str(hunks_doc.get("seed_sha256", "")), {h["id"] for h in hunks})
    st = load_ledger(state_dir)
    used = read_used(state_dir)
    shown = []
    for h, v in zip(hunks, views):
        ent = rs["by_hunk"].get(h["id"], {"ids": [], "self": False})
        kinds, pieces = [], []
        for fid in ent["ids"]:
            kind, piece = finding_status(st, fid, used)
            kinds.append(kind)
            pieces.append(piece)
        if ent["self"] or not ent["ids"]:
            pieces.append(NO_REASON)
        shown.append(pieces)
        v["reason"] = " · ".join(pieces)
        v["recommend"] = bool(ent["ids"]) and not ent["self"] and all(k == "confirmed" for k in kinds) \
            and used is not None and not final
    notices = []
    if rs["unreadable"]:
        notices.append("이유 파일을 읽지 못했다 — 고친 이유를 쓰지 않았다")
    if rs["stale"]:
        notices.append("이유 파일이 이 공시의 것이 아니다 — 고친 이유를 쓰지 않았다")
    if rs["dropped"] > 0:
        notices.append("이유 파일에서 읽지 못한 줄 %d개" % rs["dropped"])
    if st is None:
        notices.append("리뷰 원장을 읽지 못했다 — 권장을 붙이지 않는다")
    if used is None:
        notices.append("쓴 지적 목록을 읽지 못했다 — 권장을 붙이지 않는다")
    lines = ["저자 편집 %d곳 — 달라진 문장만 보입니다" % len(hunks)]
    if any(v["recommend"] for v in views):
        lines.append(RECOMMEND_NOTE)
    lines += notices
    for k, (h, v, pieces) in enumerate(zip(hunks, views, shown), 1):
        lines.append("")
        lines += _render(k, h, v, pieces)
    return {"text": "\n".join(lines), "hunks": views, "questions": build_questions(views, width),
            "notices": notices}


def _int_list(raw: str):
    out = []
    for x in raw.split(","):
        x = x.strip()
        if not x:
            continue
        if not x.isascii() or not x.isdigit():
            return None
        out.append(int(x))
    return out


def mark_used(a) -> int:
    try:
        doc = json.loads(pathlib.Path(a.hunks).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as e:
        print("[spec-distill] 덩어리 JSON 을 읽지 못했다: %s (%s)" % (a.hunks, e), file=sys.stderr)
        return 2
    if not isinstance(doc, dict) or not isinstance(doc.get("hunks"), list):
        print("[spec-distill] 덩어리 JSON 에 hunks 목록이 없다: %s" % a.hunks, file=sys.stderr)
        return 2
    ids = _int_list(a.ids)
    if ids is None:
        print("[spec-distill] --ids 는 쉼표로 이은 정수여야 한다: %r" % a.ids, file=sys.stderr)
        return 2
    hunk_ids = sorted(h["id"] for h in doc["hunks"])
    if sorted(ids) != hunk_ids:
        missing = [n for n in hunk_ids if n not in ids]
        extra = sorted(set(n for n in ids if n not in hunk_ids) | set(n for n in ids if ids.count(n) > 1))
        print("[spec-distill] 처분 목록의 번호가 이 화면의 덩어리와 다르다 — 빠진 번호 %s · 없는 번호 %s"
              % (missing, extra), file=sys.stderr)
        return 2
    rs = parse_reasons(a.reasons, str(doc.get("seed_sha256", "")), set(hunk_ids))
    skipped = "no_reasons" if not rs["present"] else "stale_reasons" if rs["stale"] or rs["unreadable"] else None
    added: list[str] = []
    if skipped is None:
        used = read_used(a.state_dir)
        if used is None:
            print("[spec-distill] 쓴 지적 목록을 읽지 못했다 — %s" % (pathlib.Path(a.state_dir) / USED_FILE),
                  file=sys.stderr)
            return 2
        for n in hunk_ids:
            for fid in rs["by_hunk"].get(n, {"ids": []})["ids"]:
                if fid not in used and fid not in added:
                    added.append(fid)
        if added:
            path = pathlib.Path(a.state_dir) / USED_FILE
            try:
                old = path.read_text(encoding="utf-8") if path.exists() else ""
                lines = [x for x in old.split("\n") if x.strip()]
                nofollow_write.replace_bytes(str(path), ("\n".join(lines + added) + "\n").encode("utf-8"))
            except (OSError, UnicodeError) as e:
                print("[spec-distill] 쓴 지적 목록을 쓰지 못했다: %s (%s)" % (path, e), file=sys.stderr)
                return 2
    print(json.dumps({"added": added, "skipped": skipped}, ensure_ascii=False))
    return 0


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(prog="seed_edit_screen.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    pv = sp.add_parser("preview")
    pv.add_argument("base")
    pv.add_argument("seed")
    sc = sp.add_parser("screen")
    sc.add_argument("--hunks", required=True)
    sc.add_argument("--reasons", required=True)
    sc.add_argument("--state-dir", required=True)
    sc.add_argument("--final", action="store_true")
    mk = sp.add_parser("mark-used")
    mk.add_argument("--hunks", required=True)
    mk.add_argument("--reasons", required=True)
    mk.add_argument("--state-dir", required=True)
    mk.add_argument("--ids", required=True)
    try:
        a = p.parse_args(argv)
    except SystemExit:
        return 2
    if a.cmd == "preview":
        if not a.base or not a.seed:
            print("[spec-distill] 기준 사본 · seed 경로가 비었다(base=%r seed=%r)" % (a.base, a.seed),
                  file=sys.stderr)
            return 2
        base, seed = pathlib.Path(a.base), pathlib.Path(a.seed)
        if not seed.is_file():
            print("seed not found: %s" % seed, file=sys.stderr)
            return 2
        if not base.is_file():
            print(json.dumps({"base_present": False, "empty": None, "hunks": []}, ensure_ascii=False))
            return 3
        hunks = seed_edit_diff.compute_hunks(seed_edit_diff._read(base), seed_edit_diff._read(seed))
        print(json.dumps({"base_present": True, "empty": not hunks, "hunks": hunks,
                          "seed_sha256": seed_edit_diff._sha256(seed)}, ensure_ascii=False))
        return 0
    if a.cmd == "mark-used":
        return mark_used(a)
    try:
        doc = json.loads(pathlib.Path(a.hunks).read_text(encoding="utf-8"))
    except (OSError, UnicodeError, ValueError) as e:
        print("[spec-distill] 덩어리 JSON 을 읽지 못했다: %s (%s)" % (a.hunks, e), file=sys.stderr)
        return 2
    if not isinstance(doc, dict) or not isinstance(doc.get("hunks"), list):
        print("[spec-distill] 덩어리 JSON 에 hunks 목록이 없다: %s" % a.hunks, file=sys.stderr)
        return 2
    try:
        width = docreview_config.ask_width(os.environ)
    except docreview_config.ConfigInvalid as e:
        print("[spec-distill] 질문 설명 기준 길이 %s=%r 이 허용 범위(%s)의 정수가 아니다"
              % (docreview_config.ASK_WIDTH_ENV, e.raw, docreview_config.ask_width_range()), file=sys.stderr)
        return 2
    print(json.dumps(build_screen(doc, a.reasons, a.state_dir, a.final, width), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as e:  # 문서화된 rc(0 · 2 · 3) 밖으로 새지 않게
        print("[spec-distill] seed_edit_screen.py 내부 오류: %s: %s" % (type(e).__name__, e), file=sys.stderr)
        sys.exit(2)
