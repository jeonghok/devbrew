#!/usr/bin/env python3
"""spec-distill — brief 리뷰 degrade 원장 (Spec B AC15).

`reviewing-brief`가 소유하는 state 키 하나를 이 모듈이 단독으로 읽고 쓴다
(E11 모듈화 — SKILL이 python heredoc으로 state를 조작하면 테스트할 대상이 없다):

  brief_review_degradations: []        # §5.6 record, append-only

두 번째 파이프라인(framing-requests)은 `--ledger-key` 로 자기 원장 줄을 같은 writer 로 쓴다.
단계·재리뷰 상한은 문서 리뷰 엔진 원장(`docreview-state.md`)의 몫이다 — 이 모듈은 옛 두 키
(`brief_review_stage` · `brief_critic_rounds`)를 심지도 읽지도 않는다. 옛 세션 state 에 남은 그
두 줄은 건드리지 않는다.

fail-closed 규율: state가 unreadable/absent이면 silent-create 하지 않고 exit 1 + JSON 으로
사유를 낸다. 「기록이 없다」와 「degrade 가 없다」는 다른 사실이므로, 쓰기 실패를 조용히
삼키면 원장이 비어 있는 것이 «깨끗함»으로 읽힌다. `degrade-append` 는 원장 줄을
silent-create하지 않는다(`init`만 생성).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# `_yaml_scalar` 의 정의는 `hook_common` 한 곳이다 — 같은 플러그인 안이라 import 하나로
# 중복이 소멸한다(설계 §6.1③).
from hook_common import _yaml_scalar  # noqa: E402

COMPONENTS = ("critic", "direction_reviewer", "readback", "codex",
              "verbatim_coverage", "pipeline")
AXES = ("fidelity", "direction", "readback", "completeness", "suppression", "all")
# `retried`는 없다 — 오염 재시도 메커니즘이 spec round-3에서 삭제됐다.
STATUSES = ("skipped", "degraded", "unavailable")

KEY_DEGRADE = "brief_review_degradations"
# degrade 원장 키의 **닫힌 열거**. 자유 문자열로 두면 오타가 새 원장을 만들고, 그 원장은
# 어떤 소비자도 읽지 않아 degrade가 기록됐는데 아무에게도 안 닿는다 — 침묵보다 나쁘다
# (기록이 있으니 됐다고 믿게 만든다). `_parse_degradations`(읽기)·`cmd_degrade_append`(쓰기)
# ·`cmd_get`(읽기 CLI) 셋 다 이 열거 하나로 검증한다 — 리터럴을 다시 하드코딩하지 말 것.
# 쓰기만 파라미터화하고 읽기가 KEY_DEGRADE에 남으면, append는 새 키로 성공하는데 다음
# get이 옛 키만 보는 상태가 된다(기록됐는데 아무에게도 안 닿는 실패가 다른 문으로 재현).
LEDGER_KEYS = (KEY_DEGRADE, "framing_degradations")


def _fail(reason: str) -> int:
    print(json.dumps({"ok": False, "reason": reason}, ensure_ascii=False))
    return 1


def _read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


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


def parse(text: str, ledger_key: str = KEY_DEGRADE) -> dict:
    """degrade 원장 한 줄을 읽는다. **부재**는 빈 목록 + `migrated` 열거(쓰지 않는다) — §5.7
    migration 계약.

    `ledger_key`는 원장을 **어느 줄에서** 읽을지 고른다(기본값은 brief 파이프라인의 것) —
    `LEDGER_KEYS`의 닫힌 열거를 따른다. 반환 dict의 필드명은 항상
    `brief_review_degradations`다(고정 스키마) — 값의 출처만 `ledger_key`가 바꾼다."""
    out = {"brief_review_degradations": [], "migrated": []}
    out["brief_review_degradations"] = _parse_degradations(text, out, ledger_key)
    return out


def _parse_degradations(text: str, out: dict, ledger_key: str = KEY_DEGRADE) -> list:
    # 콜론 앞뒤 모두 [ \t]*(줄 안 공백만) — \s*는 \n도 삼켜 값이 비면(멀티라인 블록 시작)
    # 다음 줄의 첫 `- component:` 불릿까지 매치에 먹혀 m.end()가 record 1 중간에 앉는다.
    m = re.search(rf"^{re.escape(ledger_key)}[ \t]*:[ \t]*(.*)$", text, re.MULTILINE)
    if not m:
        out["migrated"].append(ledger_key)
        return []
    raw = m.group(1).strip()
    if raw in ("[]", "[ ]"):
        return []
    # 값 검증 — 이 검증이 없어서 `brief_review_degradations: null`(또는 임의 스칼라)이 record
    # 스캔으로 흘러가 빈 리스트를 반환했다 — 손상 원장과 깨끗한 run의 Step B 텍스트가 바이트
    # 동일해져 "degrade 없음"으로 렌더된다. 원장은 indeterminate ≠ clean 설계 전체가 얹힌
    # 산출물이다. 허용 형태는 둘뿐이다: `[]`(빈 flow)와 값이 비어 있는 블록 시퀀스
    # 시작(`{ledger_key}:` + 다음 줄부터 `- …`).
    if raw:
        raise ValueError(
            f"{ledger_key} 값이 리스트가 아니다: {raw!r} — 빈 `[]`이거나 블록 시퀀스여야 한다"
            " (판독 불가를 '기록 없음'으로 읽지 않는다)")
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


# --- 서브커맨드 --------------------------------------------------------------
def cmd_init(args) -> int:
    if args.ledger_key not in LEDGER_KEYS:
        return _fail(f"ledger-key가 닫힌 열거 밖: {args.ledger_key!r}")
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
    # `--ledger-key`는 **추가**다(치환이 아니다). 기본 원장은 어느 파이프라인의 state에서든
    # 남고, 두 번째 파이프라인은 자기 원장 줄을 하나 더 얻는다. 치환으로 만들면 brief 쪽
    # state에서 기본 원장이 사라져 그 파이프라인의 degrade가 통째로 죽는다. 기본값으로 부르면
    # 기본 원장 한 줄만 심는다.
    keys = [(KEY_DEGRADE, "[]")]
    if args.ledger_key != KEY_DEGRADE:
        keys.append((args.ledger_key, "[]"))
    for key, default in keys:
        if not re.search(rf"^{key}[ \t]*:", text, re.MULTILINE):
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
    if args.ledger_key not in LEDGER_KEYS:
        return _fail(f"ledger-key가 닫힌 열거 밖: {args.ledger_key!r}")
    try:
        text = _read(Path(args.state))
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    try:
        data = parse(text, args.ledger_key)
    except ValueError as exc:
        return _fail(f"malformed: {exc}")
    print(json.dumps(data, ensure_ascii=False))
    return 0


def cmd_degrade_append(args) -> int:
    if args.component not in COMPONENTS:
        return _fail(f"component가 닫힌 열거 밖: {args.component!r}")
    if args.axis not in AXES:
        return _fail(f"affected_axis가 닫힌 열거 밖: {args.axis!r}")
    if args.status not in STATUSES:
        return _fail(f"verification_status가 닫힌 열거 밖: {args.status!r}")
    if args.ledger_key not in LEDGER_KEYS:
        return _fail(f"ledger-key가 닫힌 열거 밖: {args.ledger_key!r}")
    if not args.reason.strip():
        return _fail("reason이 비어 있다 — degrade는 원인 없이 기록되지 않는다")
    path = Path(args.state)
    try:
        text = _read(path)
    except (OSError, UnicodeDecodeError) as exc:
        return _fail(f"state unreadable: {exc}")
    key = args.ledger_key
    # 콜론 앞뒤 모두 [ \t]*(줄 안 공백만) — _parse_degradations와 동일 이유.
    # `key`는 여기부터 이 함수가 끝날 때까지 읽기·쓰기 양쪽에서 유일한 출처다 — KEY_DEGRADE
    # 리터럴을 다시 쓰면 --ledger-key로 찾은 줄과 실제로 쓰는 줄이 갈라진다.
    m = re.search(rf"^{re.escape(key)}[ \t]*:[ \t]*(.*)$", text, re.MULTILINE)
    if not m:
        return _fail(f"{key} 라인 부재 — init을 먼저 실행하라")
    record = (f"  - component: {_yaml_scalar(args.component)}\n"
              f"    reason: {_yaml_scalar(args.reason)}\n"
              f"    affected_axis: {_yaml_scalar(args.axis)}\n"
              f"    verification_status: {_yaml_scalar(args.status)}\n")
    raw_ledger = m.group(1).strip()
    if raw_ledger and raw_ledger not in ("[]", "[ ]"):
        # 스칼라 값 아래에 record를 splice하면 무효 YAML을 frontmatter에 써 넣고도
        # `{"ok": true}`를 반환한다 — 훅과 state_path.py 소비자가 읽는 파일이다.
        return _fail(
            f"{key} 값이 리스트가 아니다: {raw_ledger!r} — 손상된 원장에 append하지 않는다")
    if raw_ledger in ("[]", "[ ]"):
        text = text[:m.start()] + f"{key}:\n" + record + text[m.end() + 1:]
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
    sp = sub.add_parser("init")
    sp.add_argument("state")
    # get/degrade-append와 같은 이유로 choices=를 안 쓴다(닫힌 열거 위반은 exit 2가 아니라
    # exit 1 + {"ok": false, "reason": …}이어야 소비자가 rc로 원인을 가른다).
    sp.add_argument("--ledger-key", default=KEY_DEGRADE,
                    help="이 원장 줄도 함께 심는다(LEDGER_KEYS). 기본값이면 기본 원장 한 줄만")
    sp.set_defaults(fn=cmd_init)
    sp = sub.add_parser("get")
    sp.add_argument("state")
    # choices= 를 안 쓴다 — argparse가 invalid choice에 exit 2를 내는데, 이 스크립트의
    # 다른 모든 닫힌 열거(component/axis/status)는 cmd_*이 수동 검증해 exit 1 +
    # {"ok": false, "reason": …}을 낸다. 여기만 exit 2로 갈라지면 소비자가 rc로
    # "닫힌 열거 밖"과 "인자 자체가 틀림"을 구분 못 한다.
    sp.add_argument("--ledger-key", default=KEY_DEGRADE)
    sp.set_defaults(fn=cmd_get)
    sp = sub.add_parser("degrade-append")
    sp.add_argument("state")
    sp.add_argument("--component", required=True)
    sp.add_argument("--reason", required=True)
    sp.add_argument("--axis", required=True)
    sp.add_argument("--status", required=True)
    sp.add_argument("--ledger-key", default=KEY_DEGRADE,
                    help="degrade 원장 키(LEDGER_KEYS). 기본값은 brief 파이프라인의 것")
    sp.set_defaults(fn=cmd_degrade_append)
    args = p.parse_args(argv[1:])
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
