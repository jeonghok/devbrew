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

fail-closed 규율: state가 unreadable/absent이면 silent-create 하지 않고 exit 1 + JSON 으로
사유를 낸다. 「기록이 없다」와 「degrade 가 없다」는 다른 사실이므로, 쓰기 실패를 조용히
삼키면 원장이 비어 있는 것이 «깨끗함»으로 읽힌다. mutating 서브커맨드는 카운터 라인을
silent-create하지 않는다(`init`만 생성).
같은 규율이 **존재하지만 값이 비어 있는 라인**(`key:` 뒤 같은 줄에 내용이 없는 malformed
상태)에도 적용된다 — absent(라인 자체가 없음, `migrated` + in-memory default)와는 다른
사실이므로 default로 조용히 승격하지 않고 raise한다(`parse()`/`_set_scalar()` 참고).
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
# `_yaml_scalar` 는 이 플러그인 안의 세 소비자가 공유한다(merge_review ·
# merge_brief_review · 여기). 같은 플러그인 안이라 import 하나로 중복이 소멸한다(설계 §6.1③).
from hook_common import _yaml_scalar  # noqa: E402

STAGES = ("direction", "fidelity", "readback", "done")
CRITIC_ROUND_CAP = 2

COMPONENTS = ("critic", "direction_reviewer", "readback", "codex",
              "verbatim_coverage", "pipeline")
AXES = ("fidelity", "direction", "readback", "completeness", "suppression", "all")
# `retried`는 없다 — 오염 재시도 메커니즘이 spec round-3에서 삭제됐다.
STATUSES = ("skipped", "degraded", "unavailable")

KEY_STAGE = "brief_review_stage"
KEY_ROUNDS = "brief_critic_rounds"
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
    """세 키를 읽는다. **부재**는 default + `migrated` 열거(쓰지 않는다) — §5.7 migration
    계약. **존재하지만 값이 비어 있음**(콜론 뒤 같은 줄에 내용이 없음)은 부재와 다른 사실이며
    fail-closed다(ValueError) — 존재하지만 비-정수인 값은 0 으로 강등하지 않는다. 강등하면
    손상된 원장이 정상 원장과 구별되지 않는다. 특히 brief_critic_rounds가
    비어 있는데 0으로 읽으면 escalate 루프-가드 방향으로 fail-OPEN(실제로는 알 수 없는 상태인데
    재dispatch를 계속 허용)이 되므로 반드시 raise한다.

    `ledger_key`는 degrade 원장 세 번째 키를 **어느 줄에서** 읽을지 고른다(기본값은 brief
    파이프라인의 것) — `LEDGER_KEYS`의 닫힌 열거를 따른다. 반환 dict의 필드명은 항상
    `brief_review_degradations`다(고정 스키마) — 값의 출처만 `ledger_key`가 바꾼다.

    콜론 앞뒤 공백은 `[ \\t]*`(같은 줄 안)로 한정한다 — `\\s*`는 `\\n`도 삼켜, 값이 빈 줄
    (`key:` 다음 줄부터 내용이 시작하는 형태)에서 **다음 줄의 첫 토큰을 이 줄의 값으로 오인**한다
    (KEY_DEGRADE에서 실제로 터졌던 것과 동일 클래스의 버그 — 여기서는 STAGE/ROUNDS가 각각
    "닫힌 열거 밖 값을 조용히 통과"·"손상된 카운터를 조용히 읽기"로 나타난다)."""
    out = {"brief_review_stage": "direction", "brief_critic_rounds": 0,
           "brief_review_degradations": [], "migrated": [], "clamped": False}
    m = re.search(rf"^{KEY_STAGE}[ \t]*:[ \t]*(.*)$", text, re.MULTILINE)
    if m:
        tok_m = re.match(r"\S+", m.group(1))
        if not tok_m:
            raise ValueError(f"{KEY_STAGE} 라인이 있으나 값이 비어 있다(malformed) — fail-closed")
        val = _unscalar(tok_m.group(0))
        if val not in STAGES:
            raise ValueError(f"{KEY_STAGE} 값이 닫힌 열거 밖: {val!r}")
        out["brief_review_stage"] = val
    else:
        out["migrated"].append(KEY_STAGE)

    m = re.search(rf"^{KEY_ROUNDS}[ \t]*:[ \t]*(.*)$", text, re.MULTILINE)
    if m:
        tok_m = re.match(r"\S+", m.group(1))
        if not tok_m:
            raise ValueError(f"{KEY_ROUNDS} 라인이 있으나 값이 비어 있다(malformed) — fail-closed")
        tok = tok_m.group(0)
        if not tok.isdigit():
            raise ValueError(f"{KEY_ROUNDS} 가 비음수 정수가 아니다: {tok!r}")
        n = int(tok)
        if n > CRITIC_ROUND_CAP:
            out["clamped"] = True
            n = CRITIC_ROUND_CAP
        out["brief_critic_rounds"] = n
    else:
        out["migrated"].append(KEY_ROUNDS)

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
    # 형제 두 키(STAGE·ROUNDS)와 같은 규율을 적용한다. 여기만 검증이 없어서
    # `brief_review_degradations: null`(또는 임의 스칼라)이 record 스캔으로 흘러가
    # 빈 리스트를 반환했다 — 손상 원장과 깨끗한 run의 Step B 텍스트가 바이트 동일해져
    # "degrade 없음"으로 렌더된다. 원장은 indeterminate ≠ clean 설계 전체가 얹힌
    # 산출물이므로 셋 중 가장 엄격해야 한다. 허용 형태는 둘뿐이다: `[]`(빈 flow)와
    # 값이 비어 있는 블록 시퀀스 시작(`{ledger_key}:` + 다음 줄부터 `- …`).
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


def _set_scalar(text: str, key: str, value) -> str:
    """`key`의 인라인 스칼라 값을 새 값으로 교체한다. 콜론 앞뒤 공백은 전부 `[ \\t]*`
    (같은 줄 안)로 한정한다 — `\\s*`는 `\\n`도 삼키므로, 값이 빈 줄(`key:` 다음 줄부터
    새 키/블록이 시작하는 형태)에서 **다음 줄의 내용을 이 줄의 기존 값으로 오인**해
    그 줄 전체를 새 값으로 갈아치워 삭제해버린다(실제로 재현된 사고: brief_review_stage가
    비어 있고 바로 다음 줄에 brief_critic_rounds: 0이 있으면, set-stage가 그 줄 전체를
    지우고 새 stage 값으로 대체했다). 존재하지만 값이 비어 있으면(같은 줄에 내용 없음)
    fail-closed — 조용히 덮어쓰지 않고, 라인이 아예 부재한 경우와 구분되는 메시지를 낸다."""
    if not re.search(rf"^{re.escape(key)}[ \t]*:", text, re.MULTILINE):
        raise ValueError(f"{key} 라인 부재 — init을 먼저 실행하라 (silent-create 금지)")
    pat = re.compile(rf"^({re.escape(key)}[ \t]*:[ \t]*)(\S.*?)([ \t]*(?:#.*)?)$", re.MULTILINE)
    m = pat.search(text)
    if not m:
        raise ValueError(f"{key} 라인이 있으나 값이 비어 있다(malformed) — fail-closed, "
                          f"조용히 덮어쓰지 않는다(인접 라인을 삼키는 사고를 막는다)")
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
    for name, fn in (("init", cmd_init),
                     ("can-redispatch", cmd_can_redispatch),
                     ("bump-critic-round", cmd_bump)):
        sp = sub.add_parser(name)
        sp.add_argument("state")
        sp.set_defaults(fn=fn)
    sp = sub.add_parser("get")
    sp.add_argument("state")
    # choices= 를 안 쓴다 — argparse가 invalid choice에 exit 2를 내는데, 이 스크립트의
    # 다른 모든 닫힌 열거(component/axis/status)는 cmd_*이 수동 검증해 exit 1 +
    # {"ok": false, "reason": …}을 낸다. 여기만 exit 2로 갈라지면 소비자가 rc로
    # "닫힌 열거 밖"과 "인자 자체가 틀림"을 구분 못 한다.
    sp.add_argument("--ledger-key", default=KEY_DEGRADE)
    sp.set_defaults(fn=cmd_get)
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
    sp.add_argument("--ledger-key", default=KEY_DEGRADE,
                    help="degrade 원장 키(LEDGER_KEYS). 기본값은 brief 파이프라인의 것")
    sp.set_defaults(fn=cmd_degrade_append)
    args = p.parse_args(argv[1:])
    return args.fn(args)


if __name__ == "__main__":
    sys.exit(main(sys.argv))
