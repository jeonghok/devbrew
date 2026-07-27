#!/usr/bin/env python3
"""spec-distill — brief 리뷰 파이프라인 상태 (Spec B AC13/AC15).

`reviewing-brief`가 소유하는 state 키 **3개**를 이 모듈이 단독으로 읽고 쓴다
(E11 모듈화 — SKILL이 python heredoc으로 state를 조작하면 테스트할 대상이 없다):

  brief_review_stage: direction | fidelity | readback | done
  brief_critic_rounds: 0              # 이 spec의 유일한 루프 카운터. 상한 2 (AC13)
  brief_review_degradations: []        # §5.6 record, append-only

§6.2 전이 표의 경계값이 여기서 집행된다:
  - 최초 critic 리뷰는 카운터를 **올리지 않는다**(재라운드가 아니다).
  - 카운터는 **수정 후 재dispatch 시점에** +1 된다(리뷰 결과 수신 시점이 아니다).
  - escalate는 `== 2`에서 발화한다(`> 2`를 기다리지 않는다) → `can-redispatch` exit 1.
  - **상한 불변식**: 어떤 전이도 2를 초과시키지 않는다. 따라서 3 이상은 도달 불가능한
    손상 상태이며 **2로 clamp + advisory**한다(escalate로 수렴 — 덜 진행하는 쪽이 안전).

fail-closed 규율은 `probe_budget.py`와 동일하다: state가 unreadable/absent이면
mutating 서브커맨드는 exit 1이고, 카운터 라인을 silent-create하지 않는다(`init`만 생성).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

STAGES = ("direction", "fidelity", "readback", "done")
CRITIC_ROUND_CAP = 2

COMPONENTS = ("critic", "direction_reviewer", "readback", "codex",
              "verbatim_coverage", "pipeline")
AXES = ("fidelity", "direction", "readback", "completeness", "all")
# `retried`는 없다 — 오염 재시도 메커니즘이 spec round-3에서 삭제됐다.
STATUSES = ("skipped", "degraded", "unavailable")

KEY_STAGE = "brief_review_stage"
KEY_ROUNDS = "brief_critic_rounds"
KEY_DEGRADE = "brief_review_degradations"


def _fail(reason: str) -> int:
    print(json.dumps({"ok": False, "reason": reason}, ensure_ascii=False))
    return 1


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def _yaml_scalar(v) -> str:
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, int):
        return str(v)
    s = str(v)
    if s == "" or any(c in s for c in ":#\"'\n[]{}") or s.strip() != s:
        return json.dumps(s, ensure_ascii=False)
    return s


def _unscalar(v: str):
    v = v.strip()
    if len(v) >= 2 and v[0] == '"' and v[-1] == '"':
        try:
            return json.loads(v)
        except ValueError:
            return v[1:-1]
    return v


def _frontmatter_bounds(text: str) -> tuple[int, int]:
    if not text.startswith("---"):
        raise ValueError("frontmatter 부재")
    end = text.find("\n---", 3)
    if end == -1:
        raise ValueError("frontmatter 종료 구분자 부재")
    return 3, end


def parse(text: str) -> dict:
    """세 키를 읽는다. 부재는 default + `migrated` 열거(쓰지 않는다)."""
    out = {"brief_review_stage": "direction", "brief_critic_rounds": 0,
           "brief_review_degradations": [], "migrated": [], "clamped": False}
    m = re.search(rf"^{KEY_STAGE}\s*:\s*(\S+)", text, re.MULTILINE)
    if m:
        val = _unscalar(m.group(1))
        if val not in STAGES:
            raise ValueError(f"{KEY_STAGE} 값이 닫힌 열거 밖: {val!r}")
        out["brief_review_stage"] = val
    else:
        out["migrated"].append(KEY_STAGE)

    m = re.search(rf"^{KEY_ROUNDS}\s*:\s*(\S+)", text, re.MULTILINE)
    if m:
        tok = m.group(1)
        if not tok.isdigit():
            raise ValueError(f"{KEY_ROUNDS} 가 비음수 정수가 아니다: {tok!r}")
        n = int(tok)
        if n > CRITIC_ROUND_CAP:
            out["clamped"] = True
            n = CRITIC_ROUND_CAP
        out["brief_critic_rounds"] = n
    else:
        out["migrated"].append(KEY_ROUNDS)

    out["brief_review_degradations"] = _parse_degradations(text, out)
    return out


def _parse_degradations(text: str, out: dict) -> list:
    # 콜론 뒤는 [ \t]*(줄 안 공백만) — \s*는 \n도 삼켜 값이 비면(멀티라인 블록 시작)
    # 다음 줄의 첫 `- component:` 불릿까지 매치에 먹혀 m.end()가 record 1 중간에 앉는다.
    m = re.search(rf"^{KEY_DEGRADE}\s*:[ \t]*(.*)$", text, re.MULTILINE)
    if not m:
        out["migrated"].append(KEY_DEGRADE)
        return []
    if m.group(1).strip() in ("[]", "[ ]"):
        return []
    lines = text[m.end():].splitlines()
    recs: list = []
    cur: dict | None = None
    for ln in lines:
        if ln.strip() and not ln[0].isspace():
            break
        item = re.match(r"^\s*-\s+(\w+)\s*:\s*(.*)$", ln)
        if item:
            cur = {item.group(1): _unscalar(item.group(2))}
            recs.append(cur)
            continue
        kv = re.match(r"^\s+(\w+)\s*:\s*(.*)$", ln)
        if kv and cur is not None:
            cur[kv.group(1)] = _unscalar(kv.group(2))
    return recs


def _set_scalar(text: str, key: str, value) -> str:
    pat = re.compile(rf"^({re.escape(key)}\s*:\s*)(\S.*?)(\s*(?:#.*)?)$", re.MULTILINE)
    m = pat.search(text)
    if not m:
        raise ValueError(f"{key} 라인 부재 — init을 먼저 실행하라 (silent-create 금지)")
    return text[:m.start()] + f"{m.group(1)}{_yaml_scalar(value)}{m.group(3)}" + text[m.end():]


# --- 서브커맨드 --------------------------------------------------------------
def cmd_init(args) -> int:
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        _, end = _frontmatter_bounds(text)
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    added = []
    inject = ""
    for key, default in ((KEY_STAGE, "direction"), (KEY_ROUNDS, "0"),
                         (KEY_DEGRADE, "[]")):
        if not re.search(rf"^{key}\s*:", text, re.MULTILINE):
            inject += f"{key}: {default}\n"
            added.append(key)
    if inject:
        text = text[:end + 1] + inject + text[end + 1:]
        try:
            path.write_text(text, encoding="utf-8")
        except OSError as exc:
            return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, "added": added}, ensure_ascii=False))
    return 0


def cmd_get(args) -> int:
    try:
        text = _read(Path(args.state))
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        data = parse(text)
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    if data["clamped"]:
        data.setdefault("advisories", []).append(
            f"[spec-distill v0.24.0] {KEY_ROUNDS} 가 도달 불가 값(>{CRITIC_ROUND_CAP})이었다 "
            f"— {CRITIC_ROUND_CAP}으로 clamp하고 escalate 경로로 수렴한다")
    print(json.dumps(data, ensure_ascii=False))
    return 0


def cmd_can_redispatch(args) -> int:
    try:
        data = parse(_read(Path(args.state)))
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    n = data["brief_critic_rounds"]
    ok = n < CRITIC_ROUND_CAP
    print(json.dumps({"ok": ok, KEY_ROUNDS: n, "cap": CRITIC_ROUND_CAP,
                      "escalate": not ok, "clamped": data["clamped"]},
                     ensure_ascii=False))
    return 0 if ok else 1


def cmd_bump(args) -> int:
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        data = parse(text)
        n = min(data["brief_critic_rounds"] + 1, CRITIC_ROUND_CAP)
        text = _set_scalar(text, KEY_ROUNDS, n)
    except ValueError as exc:
        return _fail(f"bump failed: {exc}")
    try:
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, KEY_ROUNDS: n,
                      "clamped": data["clamped"] or n == CRITIC_ROUND_CAP,
                      "escalate": n >= CRITIC_ROUND_CAP}, ensure_ascii=False))
    return 0


def cmd_set_stage(args) -> int:
    if args.stage not in STAGES:
        return _fail(f"stage가 닫힌 열거 밖: {args.stage!r} (허용: {', '.join(STAGES)})")
    path = Path(args.state)
    try:
        text = _set_scalar(_read(path), KEY_STAGE, args.stage)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    except ValueError as exc:
        return _fail(f"set-stage failed: {exc}")
    try:
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, KEY_STAGE: args.stage}, ensure_ascii=False))
    return 0


def cmd_degrade_append(args) -> int:
    if args.component not in COMPONENTS:
        return _fail(f"component가 닫힌 열거 밖: {args.component!r}")
    if args.axis not in AXES:
        return _fail(f"affected_axis가 닫힌 열거 밖: {args.axis!r}")
    if args.status not in STATUSES:
        return _fail(f"verification_status가 닫힌 열거 밖: {args.status!r}")
    if not args.reason.strip():
        return _fail("reason이 비어 있다 — degrade는 원인 없이 기록되지 않는다")
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    # 콜론 뒤는 [ \t]*(줄 안 공백만) — _parse_degradations와 동일 이유.
    m = re.search(rf"^{KEY_DEGRADE}\s*:[ \t]*(.*)$", text, re.MULTILINE)
    if not m:
        return _fail(f"{KEY_DEGRADE} 라인 부재 — init을 먼저 실행하라")
    record = (f"  - component: {_yaml_scalar(args.component)}\n"
              f"    reason: {_yaml_scalar(args.reason)}\n"
              f"    affected_axis: {_yaml_scalar(args.axis)}\n"
              f"    verification_status: {_yaml_scalar(args.status)}\n")
    if m.group(1).strip() in ("[]", "[ ]"):
        text = text[:m.start()] + f"{KEY_DEGRADE}:\n" + record + text[m.end() + 1:]
    else:
        # 기존 블록의 마지막 항목 뒤에 삽입 (append-only).
        rest = text[m.end() + 1:]
        consumed = 0
        for ln in rest.splitlines(keepends=True):
            if ln.strip() and not ln[0].isspace():
                break
            consumed += len(ln)
        text = text[:m.end() + 1] + rest[:consumed] + record + rest[consumed:]
    try:
        path.write_text(text, encoding="utf-8")
    except OSError as exc:
        return _fail(f"state unwritable: {exc}")
    print(json.dumps({"ok": True, "appended": {"component": args.component,
                                               "affected_axis": args.axis,
                                               "verification_status": args.status}},
                     ensure_ascii=False))
    return 0


def main(argv: list[str]) -> int:
    p = argparse.ArgumentParser(prog="brief_review_state.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    for name, fn in (("init", cmd_init), ("get", cmd_get),
                     ("can-redispatch", cmd_can_redispatch),
                     ("bump-critic-round", cmd_bump)):
        sp = sub.add_parser(name)
        sp.add_argument("state")
        sp.set_defaults(fn=fn)
    sp = sub.add_parser("set-stage")
    sp.add_argument("state")
    sp.add_argument("stage")
    sp.set_defaults(fn=cmd_set_stage)
    sp = sub.add_parser("degrade-append")
    sp.add_argument("state")
    sp.add_argument("--component", required=True)
    sp.add_argument("--reason", required=True)
    sp.add_argument("--axis", required=True)
    sp.add_argument("--status", required=True)
    sp.set_defaults(fn=cmd_degrade_append)
    args = p.parse_args(argv[1:])
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
