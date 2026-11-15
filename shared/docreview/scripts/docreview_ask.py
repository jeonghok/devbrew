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
    `keep_label`(고정 얻음 라벨 또는 None) · `render`(짧은 묶음의 렌더 한 줄)."""
    out = []
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
