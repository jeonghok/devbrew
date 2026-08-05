#!/usr/bin/env python3
"""spec-distill — interview probe budget backstop (C1, C10, AC4, AC12).

커버리지-구동 인터뷰의 Unbounded-autonomy 가드. floor가 미충족이면 종료가 막히므로
probe가 무한히 돌 수 있다 — 이를 기계적으로 bound한다(프로즈 self-tracking 아님).

"probe" = 사용자와의 (b)/(d)-path 질문-답변 교환 1회. probe_count는 probe를 *제기한 뒤*
+1 된다(제기 전 gate에서 막힌 probe는 phantom 증가하면 안 됨). check가 유일한 *gate*이며,
increment는 절대 cap을 이유로 gate하지 않는다 — 단, increment/raise-cap 자체는 exit 0을
보장하지 않는다: state가 unreadable/absent이거나 카운터 라인이 부재/malformed면 check와
동일하게 fail-closed(exit 1)하며, 누락된 카운터 라인을 silent하게 생성하지 않는다.

  effective_cap = base_cap + probe_cap_override
  base_cap = int(env DEVBREW_SPEC_DISTILL_PROBE_CAP) if set else 12

CLI (모두 JSON 출력):
  probe_budget.py check <state.local.md>      → exit 0 if probe_count < effective_cap else 1 (gate, mutation 없음); stdout: remaining
  probe_budget.py increment <state.local.md>  → probe_count += 1; persist; exit 0 on 성공 (probe 제기 *후* 호출). check와 동일하게 state unreadable/absent/malformed(카운터 라인 부재 포함) 시 fail-closed(exit 1) — 카운터를 silent 생성하지 않는다.
  probe_budget.py raise-cap <state.local.md>  → probe_cap_override += base_cap; persist; exit 0 on 성공 (C1 '계속'). check와 동일하게 state unreadable/absent/malformed(카운터 라인 부재 포함) 시 fail-closed(exit 1) — 카운터를 silent 생성하지 않는다.
"""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

DEFAULT_BASE_CAP = 12


def _base_cap() -> int:
    raw = os.environ.get("DEVBREW_SPEC_DISTILL_PROBE_CAP")
    if raw is None or raw.strip() == "":
        return DEFAULT_BASE_CAP
    if not raw.strip().isdigit():
        raise ValueError(
            f"DEVBREW_SPEC_DISTILL_PROBE_CAP not a non-negative integer: {raw!r}")
    return int(raw.strip())


def _read_counter(text: str, key: str) -> int:
    """state frontmatter에서 비음수 정수 카운터를 읽는다. 인라인 주석 허용(캡처는 숫자에서 멈춤).
    부재 → 0 (fresh session — 아직 미기록). 존재하지만 비-정수 → ValueError(fail-closed;
    백스톱은 malformed 입력을 '예산 내'인 0으로 읽으면 안 된다)."""
    m = re.search(rf"^{re.escape(key)}\s*:\s*(\S+)", text, re.MULTILINE)
    if not m:
        return 0
    tok = m.group(1)
    if not tok.isdigit():
        raise ValueError(f"{key} present but not a non-negative integer: {tok!r}")
    return int(tok)


def _effective_cap(text: str) -> int:
    return _base_cap() + _read_counter(text, "probe_cap_override")


def check(state_path: Path) -> int:
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        count = _read_counter(text, "probe_count")
        cap = _effective_cap(text)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"malformed: {exc}"}))
        return 1
    if count >= cap:
        print(json.dumps({"ok": False, "probe_count": count, "effective_cap": cap,
                          "remaining": 0, "reason": f"probe_count {count} >= cap {cap}"}))
        return 1
    print(json.dumps({"ok": True, "probe_count": count, "effective_cap": cap,
                      "remaining": cap - count}))
    return 0


def _bump_line(text: str, key: str, delta: int) -> str:
    """정수 카운터 `key`를 `delta`만큼 바꾼 text를 반환. 인라인 주석 보존. 부재/비-정수 →
    ValueError(silent-create 금지 — GC-reset race는 fail-closed 여야 한다)."""
    pat = re.compile(rf"^({re.escape(key)}\s*:\s*)([0-9]+)(.*)$", re.MULTILINE)
    m = pat.search(text)
    if not m:
        raise ValueError(f"{key} counter line absent or non-numeric")
    new_val = int(m.group(2)) + delta
    return text[:m.start()] + f"{m.group(1)}{new_val}{m.group(3)}" + text[m.end():]


def increment(state_path: Path) -> int:
    """+1 probe_count, persist, exit 0 on 성공. probe 제기 *후* 호출. cap 도달을 이유로는
    절대 gate하지 않는다(C10 원자성) — 그 gate는 check 전담. 단 check와 마찬가지로 fail-closed:
    state가 unreadable/absent이거나 probe_count 카운터 라인이 부재/malformed면 exit 1이며,
    부재한 카운터 라인을 silent-create하지 않는다(GC-reset race 안전)."""
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        text = _bump_line(text, "probe_count", 1)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"increment failed: {exc}"}))
        return 1
    try:
        state_path.write_text(text, encoding="utf-8")
    except OSError as exc:
        print(json.dumps({"ok": False, "reason": f"state unwritable: {exc}"}))
        return 1
    print(json.dumps({"ok": True, "probe_count": _read_counter(text, "probe_count")}))
    return 0


def raise_cap(state_path: Path) -> int:
    """probe_cap_override += base_cap; persist; exit 0 on 성공 (C1 '계속' — effective_cap이
    base cap 하나만큼 올라 soft cap 이후에도 인터뷰가 계속될 수 있다). check/increment와
    마찬가지로 fail-closed: state가 unreadable/absent이거나 probe_cap_override 카운터 라인이
    부재/malformed면 exit 1이며, 부재한 카운터 라인을 silent-create하지 않는다."""
    try:
        text = state_path.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(json.dumps({"ok": False, "reason": f"state unreadable: {exc}"}))
        return 1
    try:
        base = _base_cap()
        text = _bump_line(text, "probe_cap_override", base)
    except ValueError as exc:
        print(json.dumps({"ok": False, "reason": f"raise-cap failed: {exc}"}))
        return 1
    try:
        state_path.write_text(text, encoding="utf-8")
    except OSError as exc:
        print(json.dumps({"ok": False, "reason": f"state unwritable: {exc}"}))
        return 1
    override = _read_counter(text, "probe_cap_override")
    print(json.dumps({"ok": True, "probe_cap_override": override,
                      "effective_cap": _base_cap() + override}))
    return 0


SUBCOMMANDS = {"check": check, "increment": increment, "raise-cap": raise_cap}


def main(argv: list[str]) -> int:
    if len(argv) < 3 or argv[1] not in SUBCOMMANDS:
        print("usage: probe_budget.py {check|increment|raise-cap} <state.local.md>",
              file=sys.stderr)
        return 64
    try:
        return SUBCOMMANDS[argv[1]](Path(argv[2]))
    except ValueError as exc:  # bad env cap
        print(json.dumps({"ok": False, "reason": str(exc)}))
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
