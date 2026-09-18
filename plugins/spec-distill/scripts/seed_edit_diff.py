#!/usr/bin/env python3
"""seed_edit_diff.py — 저자 편집을 기준 사본과 대조해 덩어리로 낸다.

seed 는 헤딩이 없어 엔진의 얼림 검사가 모든 변경을 면제한다 — 엔진 계획서 T44 가 그 자리의
차단을 호스트로 넘겼다. `framing-requests` 가 이 모듈로 저자 편집을 전부 사용자 앞에 놓는다.

  init   <base> <seed>             기준 사본이 없을 때만 seed 를 복사한다. 있으면 손대지 않는다.
                                    실제로 새로 만들 때는 묵은 <base>.shown 도 지운다.
  hunks  <base> <seed>             기준 사본 → seed 의 변경 덩어리(JSON). 이 호출이 "공시" 다 —
                                    <base>.shown 에 지금 seed 의 sha256 을 적어 판본을 못박는다.
  revert <base> <seed> --ids 1,3   그 덩어리만 기준 사본 쪽으로 되돌려 seed 를 다시 쓴다. 공시
                                    (hunks) 이후 seed 가 또 바뀌었으면 rc 4 — 아무것도 안 쓴다.
                                    성공하면 결과(보인 것에서 고른 덩어리만 뺀 것)로 스스로 다시
                                    공시한다.
  accept <base> <seed>             seed 를 새 기준 사본으로 — 공시(hunks) 이후 seed 가 그대로일
                                    때만. 바뀌었으면 rc 4, 기준 사본은 그대로다. 성공하면 그 공시
                                    는 소진돼 <base>.shown 을 지운다.

기준 사본은 «공시될 때까지» 산다: 교체는 accept 하나뿐이고 init 은 덮어쓰지 않는다. 라운드마다
무조건 교체하면 그 사이의 편집이 diff 에서 사라진다. revert · accept 는 그 직전 hunks 가 보여준
판본에 묶인다(설계 §5.5-2) — 사용자가 보지 않은 편집을 조용히 기준으로 접거나 지우지 않는다.
rc: 0 정상 · 2 입력 오류(seed 부재 · 잘못된 id · UTF-8 아님) · 3 기준 사본 부재(hunks · revert)
  · 4 seed 가 공시된 판본과 다름(revert · accept).
"""
from __future__ import annotations

import argparse
import difflib
import hashlib
import json
import pathlib
import shutil
import sys


def _read(p: pathlib.Path) -> list[str]:
    return p.read_text(encoding="utf-8").splitlines(keepends=True)


def _sha256(p: pathlib.Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def _shown_path(base: pathlib.Path) -> pathlib.Path:
    return base.with_name(base.name + ".shown")


def _shown_matches(base: pathlib.Path, seed: pathlib.Path) -> bool:
    shown = _shown_path(base)
    if not shown.is_file():
        return False
    try:
        recorded = shown.read_text(encoding="utf-8").strip()
    except UnicodeDecodeError:
        return False
    return recorded == _sha256(seed)


def _version_stale_msg() -> str:
    return "[spec-distill] seed 가 공시 뒤 바뀌었다 — hunks 를 다시 돌려 다시 공시하라"


def _span(a: int, b: int) -> str:
    if a == b:
        return "%d행 앞(없음)" % (a + 1)
    return "%d행" % (a + 1) if b - a == 1 else "%d–%d행" % (a + 1, b)


def compute_hunks(base: list[str], seed: list[str]) -> list[dict]:
    sm = difflib.SequenceMatcher(a=base, b=seed, autojunk=False)
    out = []
    for tag, i1, i2, j1, j2 in sm.get_opcodes():
        if tag == "equal":
            continue
        k = len(out) + 1
        removed = [l.rstrip("\n") for l in base[i1:i2]]
        added = [l.rstrip("\n") for l in seed[j1:j2]]
        head = "덩어리 %d — 기준 %s → 현재 %s" % (k, _span(i1, i2), _span(j1, j2))
        render = "\n".join([head] + ["- " + l for l in removed] + ["+ " + l for l in added])
        out.append({"id": k, "tag": tag, "base": [i1, i2], "seed": [j1, j2],
                    "removed": removed, "added": added, "render": render})
    return out


def revert(base: list[str], seed: list[str], hunks: list[dict], ids: set[int]) -> list[str]:
    out = list(seed)
    for h in sorted((h for h in hunks if h["id"] in ids), key=lambda h: h["seed"][0], reverse=True):
        i1, i2 = h["base"]
        j1, j2 = h["seed"]
        out[j1:j2] = base[i1:i2]
    return out


def main(argv=None) -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")
    p = argparse.ArgumentParser(prog="seed_edit_diff.py")
    sp = p.add_subparsers(dest="cmd", required=True)
    for name in ("init", "hunks", "revert", "accept"):
        x = sp.add_parser(name)
        x.add_argument("base")
        x.add_argument("seed")
        if name == "revert":
            x.add_argument("--ids", required=True)
    try:
        a = p.parse_args(argv)
    except SystemExit:
        return 2
    base, seed = pathlib.Path(a.base), pathlib.Path(a.seed)
    if not seed.is_file():
        print("seed not found: %s" % seed, file=sys.stderr)
        return 2
    shown = _shown_path(base)
    if a.cmd == "init":
        if base.exists():
            print(json.dumps({"initialized": False, "reason": "base_exists"}, ensure_ascii=False))
            return 0
        base.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(seed, base)
        if shown.exists():
            shown.unlink()
        print(json.dumps({"initialized": True}, ensure_ascii=False))
        return 0
    if a.cmd == "accept":
        if not _shown_matches(base, seed):
            print(_version_stale_msg(), file=sys.stderr)
            return 4
        base.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(seed, base)
        shown.unlink(missing_ok=True)
        print(json.dumps({"accepted": True}, ensure_ascii=False))
        return 0
    if not base.is_file():
        print(json.dumps({"base_present": False, "empty": None, "hunks": []}, ensure_ascii=False))
        return 3
    try:
        b = _read(base)
    except UnicodeDecodeError as e:
        print("UTF-8 로 읽을 수 없다: %s (%s)" % (base, e), file=sys.stderr)
        return 2
    try:
        s = _read(seed)
    except UnicodeDecodeError as e:
        print("UTF-8 로 읽을 수 없다: %s (%s)" % (seed, e), file=sys.stderr)
        return 2
    hunks = compute_hunks(b, s)
    if a.cmd == "hunks":
        seed_sha = _sha256(seed)
        shown.write_text(seed_sha, encoding="utf-8")
        print(json.dumps({"base_present": True, "empty": not hunks, "hunks": hunks,
                          "seed_sha256": seed_sha}, ensure_ascii=False))
        return 0
    # cmd == revert
    if not _shown_matches(base, seed):
        print(_version_stale_msg(), file=sys.stderr)
        return 4
    try:
        ids = {int(x) for x in a.ids.split(",") if x.strip()}
    except ValueError:
        print("--ids 는 쉼표로 이은 정수다: %r" % a.ids, file=sys.stderr)
        return 2
    known = {h["id"] for h in hunks}
    if not ids or not ids <= known:
        print("없는 덩어리 번호: %s (있는 것: %s)" % (sorted(ids - known), sorted(known)), file=sys.stderr)
        return 2
    seed.write_text("".join(revert(b, s, hunks, ids)), encoding="utf-8")
    shown.write_text(_sha256(seed), encoding="utf-8")
    print(json.dumps({"reverted": sorted(ids), "remaining": len(compute_hunks(b, _read(seed)))},
                     ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
