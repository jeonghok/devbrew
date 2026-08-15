#!/usr/bin/env python3
"""AC29 — A/B 측정의 신뢰 기반 봉인.

게이트가 판정에 쓰는 것들은 전부 플러그인 트리 안에 있다: 숨김 오라클, 판정
스크립트(`ab_judge.py`), 그리고 **루브릭 원본인 `REFERENCE.md`**. 마지막 것이
특히 위험하다 — 루브릭은 판정 프롬프트에서 데이터 경계 **밖**, 즉 지시 위치에
들어간다(`ab_judge.build_judge_prompt`). 피검체가 `REFERENCE.md` 를 고칠 수 있으면
자기를 채점할 지시문을 자기가 쓰는 셈이다(2026-08-15 리뷰가 적발).

러너는 그 트리를 피검체에게 **원본으로 건네지 않고**(사본을 준다) 그 위에 이
봉인을 얹는다 — 사본이 막는 것은 *"건네받은 경로를 그냥 고치는"* 길이고, 봉인이
잡는 것은 **그 밖의 모든 경로**다. 피검체 코드는 검증 프로세스 안에서 사용자
권한으로 도니까 파일시스템을 훑어 찾아낼 수는 있다 — 그것을 막지는 못하고
**탐지**한다. 어긋나면 그 반복만이 아니라 **앞선 반복 전부**가 의심스러우므로
러너는 측정을 통째로 중단한다.

Usage:
    ab_seal.py seal   <root>              → `<파일수>:<sha256>` 를 stdout 에
    ab_seal.py verify <root> <expected>   → 일치 0 · 불일치 1 · 계산 불가 2
"""
from __future__ import annotations

import hashlib
import os
import sys

# 봉인에서 빼는 것 — 측정이 **정상적으로** 바꾸는 것들이다. 여기에 무엇을 더할
# 때는 "피검체가 그 경로로 판정을 바꿀 수 있나" 를 먼저 물어야 한다. 넓게 빼면
# 봉인이 이름만 남는다.
SKIP_DIR_NAMES = ("__pycache__", ".git")
SKIP_REL_PREFIXES = ("tests/out",)     # 옛 산출물 자리 (현재는 $PD 밖에 쓴다)
SKIP_SUFFIXES = (".pyc", ".pyo")


def _files(root):
    found = []
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in SKIP_DIR_NAMES]
        for name in names:
            path = os.path.join(base, name)
            rel = os.path.relpath(path, root)
            if rel.startswith(SKIP_REL_PREFIXES) or name.endswith(SKIP_SUFFIXES):
                continue
            found.append(path)
    return sorted(found)


def digest(root):
    """`<파일수>:<sha256>` — 다이제스트에는 **내용과 경로가 둘 다** 든다.

    내용만 이으면 이름 교환이 안 잡힌다: 정렬 순서를 유지하는 rename(`a.txt` →
    `b.txt`)은 같은 내용 집합을 같은 순서로 내므로 다이제스트가 그대로다.
    오라클 파일을 다른 이름의 파일로 갈아 끼우는 것이 정확히 그 모양이다.

    **앞의 개수는 계측용이지 무결성 장치가 아니다** — 파일 수는 이미 해시에 든
    경로들에서 도출되므로 아무것도 더 잡지 못한다. 사람이 산출물을 읽을 때
    *"이 봉인이 몇 개를 덮었나"* 를 보게 하려고 낸다. 빈 트리끼리 같은 값이 나오는
    (= 경로를 잘못 넘긴 실행이 **매번 일치**하는) 문제를 막는 것은 아래의 0-개
    가드다. 이 구분을 흐리면 있지도 않은 보호를 근거로 삼게 된다.
    """
    paths = _files(root)
    if not paths:
        raise SystemExit("봉인 대상이 0 개다 — 경로가 틀렸거나 트리가 비었다: %s" % root)
    outer = hashlib.sha256()
    for path in paths:
        outer.update(os.path.relpath(path, root).encode("utf-8"))
        outer.update(b"\0")
        inner = hashlib.sha256()
        with open(path, "rb") as fh:
            while True:
                chunk = fh.read(65536)
                if not chunk:
                    break
                inner.update(chunk)
        outer.update(inner.hexdigest().encode("ascii"))
        outer.update(b"\0")
    return "%d:%s" % (len(paths), outer.hexdigest())


def main(argv):
    if len(argv) >= 3 and argv[1] == "seal":
        sys.stdout.write("%s\n" % digest(argv[2]))
        return 0
    if len(argv) >= 4 and argv[1] == "verify":
        expected = argv[3].strip()
        if not expected:
            sys.stderr.write("[ab_seal] 비교할 봉인 값이 비었다\n")
            return 2
        actual = digest(argv[2])
        if actual == expected:
            return 0
        # 강등이 사람에게 안 닿으면 그것은 강등이 아니라 통과다(설계 §7).
        sys.stderr.write("[ab_seal] 신뢰 기반이 바뀌었다\n  기대: %s\n  실제: %s\n"
                         % (expected, actual))
        return 1
    sys.stderr.write("usage: ab_seal.py seal <root> | ab_seal.py verify <root> <expected>\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
