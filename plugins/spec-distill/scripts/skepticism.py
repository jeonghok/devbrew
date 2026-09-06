#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""skepticism.py — brief payload `## 5. 기각 · Blind Spots` 의 skepticism 검사. **이 리포에서 한 곳.**

입력은 이미 잘린 것만 받는다 — payload §5 의 entry 줄 목록(`entries`, check_brief 의
`section5_entries()` 가 자른 것)과 audit §3 텍스트(`audit_sec3_text`, check_brief 의
`_section_text(audit, "3", "Steelman 원문")` 이 자른 것). 절 자르기·불릿 관례는 check_brief 에
남는다. 이 모듈은 check_brief 를 import 하지 않는다 — 의존 방향은 check_brief → skepticism 하나다.

검사 넷:
- verdict 항목 형식(`skepticism_malformed`) — PN4 containment: 유효 토큰 · statement ≥10자 · ST<N> 참조.
- 검토 항목(`review_record_*`) — steelman 0건으로 skepticism 을 닫는 기록. 네 토큰 containment.
- 폐쇄(`skepticism_closure_ok`) — verdict ≥1 또는 형식 통과 검토 ≥1. 둘 다 0 이면 False.
- bijection A(`bijection_a_errors`) — payload §5 의 ST<N> 참조 집합 == audit §3 의 `#### ST<N>` 집합.
"""
from __future__ import annotations

import re

URL_RE = re.compile(r"https?://\S+")
# 불릿을 떼는 곳은 여기 하나다 — `-` 와 `*` 를 둘 다 받는다(check_brief 의 `_entry_lines` 와 같은 관례).
BULLET_PREFIX_RE = re.compile(r"^\s*[-*]\s+")


def strip_bullet(ln: str) -> str:
    """항목 줄에서 선행 불릿(`-` 또는 `*`) **하나**와 뒤따르는 공백을 뗀다."""
    return BULLET_PREFIX_RE.sub("", ln, count=1)


VALID_VERDICTS = ("kept", "refined", "switched", "deferred")
# statement<10c 측정에서 판정 어구 자체를 제외한다 — 남겨두면 그 어구(>=14자)가 항상 통과시켜
# 검사가 도달 불가능해진다.
VERDICT_CLAUSE_RE = re.compile(r"verdict:\s*\S+", re.IGNORECASE)
ST_HEADING_RE = re.compile(r"^####\s+(ST\d+)\b", re.MULTILINE)
ST_REF_RE = re.compile(r"\b(ST\d+)\b")

# 검토 항목 — steelman 0건 폐쇄 기록. `steelman 0건` 리터럴까지 요구해 미래의 다른 `검토 —` 와 겹치지 않게 좁힌다.
REVIEW_RECORD_RE = re.compile(r"^\s*[-*]\s*검토\s*—\s*steelman\s*0건", re.IGNORECASE)
REVIEW_RECORD_TOKENS = ("검토한 방향", "전제", "trigger 후보", "기각 이유")


def verdict_entries(entries: list[str]) -> list[str]:
    return [ln for ln in entries if "verdict:" in ln]


def review_record_entries(entries: list[str]) -> list[str]:
    return [ln for ln in entries if REVIEW_RECORD_RE.match(ln)]


def review_record_malformed(entries: list[str]) -> list[str]:
    """검토 항목 형식 검사 — 네 토큰 containment(정확 일치 아님)."""
    bad: list[str] = []
    for ln in review_record_entries(entries):
        miss = [tok for tok in REVIEW_RECORD_TOKENS if tok not in ln]
        if miss:
            bad.append(f"{ln[:60]} :: missing {','.join(miss)}")
    return bad


def skepticism_closure_ok(entries: list[str]) -> bool:
    """skepticism 을 닫을 기록이 있는가 — verdict 항목 ≥1 **또는** 형식 통과 검토 항목 ≥1 (C26).

    둘 다 0 이면 False. 원장 행(`floor:skepticism — closed`)은 형식만 보므로 검토 흔적은 여기서만 요구된다.
    """
    if verdict_entries(entries):
        return True
    records = review_record_entries(entries)
    if not records:
        return False
    return len(review_record_malformed(entries)) < len(records)


def skepticism_malformed(entries: list[str]) -> list[str]:
    """§5 `verdict:` 항목 형식 검사. PN4: containment. URL 요구는 없다(N1a 가 별도로 금지)."""
    bad: list[str] = []
    for ln in entries:
        if "verdict:" not in ln:
            continue
        has_verdict = bool(re.search(r"verdict:\s*(?:%s)\b" % "|".join(VALID_VERDICTS),
                                     ln, re.IGNORECASE))
        # URL 을 먼저 벗겨낸 뒤 ST<N> 을 찾는다 — URL 경로 조각의 word-bounded ST<N>(예: `/ST9/`) 방어.
        ln_no_url = URL_RE.sub("", ln)
        has_st = bool(ST_REF_RE.search(ln_no_url))
        stripped = strip_bullet(VERDICT_CLAUSE_RE.sub("", ST_REF_RE.sub("", ln_no_url))).strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and has_st):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if not has_verdict:
                miss.append("no-verdict")
            if not has_st:
                miss.append("no-ST-ref")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


def bijection_a_errors(entries: list[str], audit_sec3_text: str) -> list[str]:
    """bijection A — payload §5 ↔ audit §3. 개수 비교가 아니라 **id 집합 비교**다.

    양쪽 공집합(steelman 0건)은 정합이다 — 0건 폐쇄의 기록은 `skepticism_closure_ok` 가 따로 요구한다.
    """
    refs = set()
    for ln in verdict_entries(entries):
        refs |= set(ST_REF_RE.findall(URL_RE.sub("", ln)))
    declared = set(ST_HEADING_RE.findall(audit_sec3_text))
    errs = []
    for st in sorted(refs - declared):
        errs.append(f"{st}: payload §5가 참조하지만 audit §3에 없음 (원문 없는 판정)")
    for st in sorted(declared - refs):
        errs.append(f"{st}: audit §3에 있지만 payload §5가 참조하지 않음 (판정 없는 steelman)")
    return errs
