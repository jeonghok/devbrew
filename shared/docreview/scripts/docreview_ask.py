"""docreview_ask.py — 리뷰 뒤 질문에 싣는 재료를 만드는 순수 함수 (leaf 모듈).

표준 라이브러리만 쓴다. `docreview_state` 를 import 하지 않는다 — 원장은 호출자가 읽고, 여기는 그 값만 받는다.
"""
from __future__ import annotations

import json

SHORT_WARN_HEAD = "리뷰 경고 %d개: %s"
SHORT_WARN_OTHER = "그 밖 %d개"


def short_warn_line(entries) -> str:
    """(짧은 이름, 쉬운 줄) 목록 → 질문의 상태 줄에 싣는 짧은 경고 줄. 비면 빈 글.

    개수는 목록의 길이 그대로다(게이트 첫 줄의 「경고 N개」와 같은 목록에서 센다). 짧은 이름은 처음 나온
    순서로 잇고, 같은 이름이 k(≥2)번이면 「<이름> ×k」로 접는다. 짧은 이름이 없는 것(표에 없는 원문)은
    버리지 않고 맨 끝에 「그 밖 N개」 하나로 센다."""
    entries = list(entries)
    if not entries:
        return ""
    order, count, other = [], {}, 0
    for short, _line in entries:
        if short is None:
            other += 1
            continue
        if short not in count:
            count[short] = 0
            order.append(short)
        count[short] += 1
    parts = [n if count[n] == 1 else "%s ×%d" % (n, count[n]) for n in order]
    if other:
        parts.append(SHORT_WARN_OTHER % other)
    return SHORT_WARN_HEAD % (len(entries), " · ".join(parts))


# ── 질문 재료(`ask-material`) ─────────────────────────────────────────────
# 「그대로 둔다」(수정 행이면 「적용하지 않음」)의 얻음 — 원문이 없는 칸이라 엔진이 고정 문구로 낸다.
KEEP_GAIN = "지금 글이 그대로 남는다"
# 리뷰어가 칸을 비웠을 때의 부재 표기 — 게이트 렌더(`_rg_decide`) · 라우터(`_decision_view`)와 같은 글자다.
ABSENT = {"replacement": "(대체안 미작성)", "if_unfixed": "(리뷰어가 안 적음)"}
# 고정 설명 — 결과가 정해진 선택지마다 (평문, 얻음 · 내줌). 문구는 엔진이 그 선택으로 실제로 하는 일이다
# (`cmd_decide` 의 hold · post 갈래와 `_rg_held_decide`). `approve_with_open` 은 열린 지적 수(%d)를 받는다.
FIXED_DESC = {
    "hold": ("지금 정하지 않는다 — 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다",
             "얻음: 지금 정하지 않고 넘어간다 · 내줌: 이 지적은 승인을 더 막지 않고 리뷰가 다시 묻지 않는다"),
    "post_adopt": ("바뀐 글을 받아들인다 — 되돌릴 의무가 끝나고 리뷰가 다시 확인하지 않는다",
                   "얻음: 바뀐 글이 그대로 남는다 · 내줌: 허가 없이 바뀐 글을 받아들여 되돌릴 의무가 끝난다"),
    "post_reject": ("바뀐 글을 이전 글로 되돌려야 한다 — 다음 라운드가 확인할 때까지 승인이 막힌다",
                    "얻음: 허가 없이 바뀐 글이 이전 글로 돌아간다 · "
                    "내줌: 손으로 되돌려야 하고 다음 라운드가 확인할 때까지 승인이 막힌다"),
    "extra_open": ("상한 밖 리뷰를 한 번 더 돈다",
                   "얻음: 고친 글을 리뷰가 한 번 더 본다 · 내줌: 상한 밖 라운드를 한 번 더 돌아 다음 단계가 그만큼 늦어진다"),
    "extra_skip": ("추가 라운드를 열지 않는다 — 남은 항목은 이 게이트에서 정한다",
                   "얻음: 리뷰를 이 라운드에서 닫는다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다"),
    "to_options": ("추가 라운드 없이 다음 단계 질문으로 간다",
                   "얻음: 리뷰를 닫고 다음 단계 질문으로 간다 · 내줌: 마지막으로 고친 글은 리뷰가 다시 보지 않는다"),
    "approve_with_open": ("열린 지적 %d개를 둔 채 다음 단계 질문으로 간다",
                          "얻음: 리뷰를 닫고 다음 단계로 간다 · 내줌: 열린 지적 %d개가 풀리지 않은 채 넘어간다"),
}
# 진입 skill 이 적용 여부를 묻는 수정 행의 선택지 — 둘째가 「그대로 둔다」 자리다.
FIX_CHOICES = ("적용", "적용하지 않음")
# 승인 게이트 1단계의 추가 라운드 묶음 — 선택지는 (라벨, 고정 설명 키). 열린 것이 0 이면 앞, 남았으면 뒤.
EXTRA_SUMMARY = "재리뷰 상한에 닿았다 — 리뷰를 한 번 더 열지 정한다"
EXTRA_CHOICES_READY = (("추가 라운드 1회 열기", "extra_open"), ("진행 옵션으로", "to_options"))
EXTRA_CHOICES_OPEN = (("열기", "extra_open"), ("열지 않음", "extra_skip"))
APPROVE_TAIL_HEAD = "승인 선택지 고정 설명: "
FULL_TEXT_HEAD = "전문: "
FULL_TEXT_FAILED = "전문: 전문 파일을 쓰지 못했다 — "
# 묶음이 0 일 때의 머리 줄 — 질문이 아니라는 것과 아래 두 줄(「상태」 · 「전문」)을 받는 곳을 밝힌다.
NO_BUNDLE_HEAD = "질문으로 뜨는 행 없음 — 아래 두 줄은 다음 단계 질문의 본문에 싣는다"


def _fold(text) -> str:
    """공백을 접은 한 줄 — 줄바꿈도 공백 하나가 된다. None 은 빈 글."""
    return " ".join(str(text).split()) if text is not None else ""


def length_mark(text, width: int) -> str:
    """원문 한 칸의 길이 표시 — None 이면 「부재」, 아니면 공백을 접은 글의 코드 포인트 수와 「그대로」 · 「줄인다」."""
    if text is None:
        return "부재"
    n = len(_fold(text))
    return "%d자 · %s" % (n, "그대로" if n <= width else "줄인다")


def full_text_line(result) -> str:
    """`gate-file` 이 낸 JSON 글 → 「전문」 줄. 부르지 않았거나(None) 읽지 못했거나 실패했으면 그 사실을 적는다."""
    if result is None:
        return FULL_TEXT_FAILED + "쓰는 명령을 부르지 않았다"
    try:
        d = json.loads(result)
    except ValueError:
        d = None
    if not isinstance(d, dict):
        return FULL_TEXT_FAILED + "결과를 읽지 못했다"
    shown = d.get("shown")
    if d.get("ok") is True and isinstance(shown, str) and shown.strip():
        return FULL_TEXT_HEAD + " ".join(shown.splitlines())   # 경로는 글자 그대로 — 줄 구분만 공백으로
    if d.get("ok") is False:
        reason = _fold(d.get("reason")) or "사유 없음"
        detail = _fold(d.get("detail"))
        return FULL_TEXT_FAILED + reason + (" · " + detail if detail else "")
    return FULL_TEXT_FAILED + "결과를 읽지 못했다"


# ── 전문 파일(`gate-file`) ─────────────────────────────────────────────────
# 구역 머리 — 엔진은 앞 둘을 쓰고, 셋째는 부른 펜스가 파일 끝에 덧붙인다(다시 쓰면 사라진다).
ZONE_GATE = "## 지금 게이트 글"
ZONE_ORIGINALS = "## 이 라운드의 지적 원문"
ZONE_CHANNELS = "## 다른 채널의 경고"
GATE_FILE_HEAD = "# 리뷰 %d라운드 — 게이트 전문"
ORIGINALS_NONE = "없음 — 이 라운드에 판정을 지난 지적이 없다"
_NO_VALUE = "—"
_ORIGINAL_FIELDS = (("그대로 두면", "if_unfixed"), ("고치면", "replacement"), ("근거", "evidence"),
                    ("자리", "anchor"))


def _original_value(label: str, value, absent: str) -> list:
    """원문 한 칸 → 줄 목록. 첫 줄은 「  <이름>: 」 뒤에, 나머지 줄은 네 칸 들여 잇는다 — 들여 쓴 줄은 구역 머리
    (`## `)와 섞이지 않는다. 비었으면 부재 표기."""
    text = "" if value is None else str(value).strip()
    lines = text.splitlines() if text else [absent]
    rest = ["    " + ln if ln.strip() else "" for ln in lines[1:]]
    return ["  %s: %s" % (label, lines[0])] + rest


def originals_block(items: list) -> str:
    """판정을 지난 지적 → 「이 라운드의 지적 원문」 구역 글. 항목마다 `- <요약> (<id>)` 와 들여쓴 넷.

    항목 dict 의 키: `id` · `summary` · `if_unfixed` · `replacement` · `evidence` · `anchor`(없으면 None).
    앞 둘의 부재 표기는 `ABSENT`, 근거 · 자리는 「—」다. 순서는 받은 그대로다."""
    if not items:
        return ORIGINALS_NONE
    out = []
    for it in items:
        out.append("- %s (%s)" % (_fold(it.get("summary")) or _NO_VALUE, it["id"]))
        for label, key in _ORIGINAL_FIELDS:
            out.extend(_original_value(label, it.get(key), ABSENT.get(key, _NO_VALUE)))
    return "\n".join(out)


def keep_originals(old_text):
    """옛 전문 파일 글 → 그 「이 라운드의 지적 원문」 구역 글(머리 줄 다음부터 채널 구역 머리 앞, 없으면 끝까지 —
    끝 개행은 뗀다). 구역이 없거나 비었으면 None — 부른 쪽이 새로 짓는다."""
    if old_text is None:
        return None
    lines = old_text.split("\n")
    try:
        start = lines.index(ZONE_ORIGINALS) + 1
    except ValueError:
        return None
    end = lines.index(ZONE_CHANNELS, start) if ZONE_CHANNELS in lines[start:] else len(lines)
    kept = "\n".join(lines[start:end]).rstrip("\n")
    return kept if kept.strip() else None


def gate_file_text(round_n: int, gate_text: str, originals: str) -> str:
    """전문 파일 글 — 머리 · 「지금 게이트 글」 구역 · 「이 라운드의 지적 원문」 구역. 끝은 개행 하나."""
    return "\n".join([GATE_FILE_HEAD % round_n, "", ZONE_GATE, gate_text.rstrip("\n"), "",
                      ZONE_ORIGINALS, originals.rstrip("\n")]) + "\n"


def display_path(path: str, cwd: str, home: str) -> str:
    """「전문」 줄에 싣는 경로 — `cwd` 아래면 상대 경로, 아니고 `home` 아래면 `~/…`, 둘 다 아니면 그대로.
    「아래」는 경로 성분 경계로 가른다(`/w/repo` 아래에 `/w/repository` 는 없다). 뿌리(`/`)는 기준으로 쓰지 않는다."""
    for base, lead in ((cwd, ""), (home, "~/")):
        base = (base or "").rstrip("/")
        if base and path.startswith(base + "/") and len(path) > len(base) + 1:
            return lead + path[len(base) + 1:]
    return path


def fixed_desc_line(label: str, key: str, n=None) -> str:
    """「<라벨> = <평문> | <얻음 · 내줌>」 — 고정 설명 한 줄. `n` 은 열린 지적 수를 받는 키에만 준다."""
    plain, trade = FIXED_DESC[key]
    if n is not None:
        plain, trade = plain % n, trade % n
    return "%s = %s | %s" % (label, plain, trade)


def render_material(bundles: list, status: str, full_text: str, width: int, tail: list) -> str:
    """묶음 목록 → 질문 재료 글. 묶음 사이에 빈 줄 하나, 꼬리 줄은 맨 끝에 빈 줄 하나를 두고 잇는다.

    묶음 dict 의 키: `kind`(`full` · `short` · `extra`) · `id` · `summary` · `choices`(라벨 목록) ·
    `replacement` · `if_unfixed`(없으면 None) · `notes`(덧줄) · `fixed`((라벨, 고정 설명 키) 목록) ·
    `keep_label`(고정 얻음 라벨 또는 None) · `render`(짧은 묶음의 렌더 한 줄).

    묶음이 0 이면 머리 줄(`NO_BUNDLE_HEAD`)과 「상태」 · 「전문」 두 줄을 낸다 — 다음 단계 질문이 싣는 줄이다."""
    out = [] if bundles else ["\n".join([NO_BUNDLE_HEAD, "상태: " + status, full_text])]
    for i, b in enumerate(bundles, 1):
        lines = ["질문 %d/%d (%s)" % (i, len(bundles), "추가 라운드" if b["kind"] == "extra" else b["id"]),
                 "본문: " + _fold(b["summary"]), "상태: " + status, full_text]
        if b["kind"] == "short":
            lines.append("렌더: " + _fold(b["render"]))
        else:
            lines.append("선택지: " + " / ".join(b["choices"]))
        if b["kind"] == "full":
            for name, key in (("고치면", "replacement"), ("그대로 두면", "if_unfixed")):
                v = b[key]
                text = ABSENT[key] if v is None else _fold(v)
                lines.append("%s (%s): %s" % (name, length_mark(v, width), text))
            lines.extend("덧줄: " + _fold(n) for n in b["notes"])
            if b["keep_label"]:
                lines.append("고정 얻음: %s = %s" % (b["keep_label"], KEEP_GAIN))
        lines.extend("고정 설명: " + fixed_desc_line(label, key) for label, key in b["fixed"])
        out.append("\n".join(lines))
    if tail:
        out.append("\n".join(tail))
    return "\n\n".join(out)
