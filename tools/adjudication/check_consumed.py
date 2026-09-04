# -*- coding: utf-8 -*-
"""L2 판정기 — 원장의 카운트가 소비자의 출력 경로에 실리는지.

요구 키를 «Ledger 자신에게서» 도출한다. 락에 열거하면 어휘가 늘어도 락이
조용하고, 그 침묵이 정확히 이 락이 막으려는 것이다.

문자열 «등장»이 아니라 AST 의 첨자/딕셔너리 키로만 센다. 주석 안의 키 이름이
소비로 읽히면 이 락은 검사가 아니라 장식이 된다.

**판정 단위는 소비자 파일이 아니라 그 파일의 «폐포»다** — `_closure()` 가
소비자 + 그것이 import 하는 `shared/adjudication/` 모듈을 함께 본다(§5 의
공유 렌더 모듈이 설계이므로). 그래서 `missing()==[]` 이 다섯 번 나와도
**다섯 개의 독립 사실이 아니다.** 실측(최종 리뷰 K4a, 호출자가 매 실행마다
`OWNFILE`/`SHARED` 로 다시 낸다): 자기 파일만으로 여덟 키를 다 읽는 소비자는
`merge_review.py` 하나(8/8)이고 나머지 넷은 0/8·0/8·1/8·2/8 이며, 다섯 전부가
`render_disposition.py` 를 import 하고 그 한 파일이 혼자 8/8 을 덮는다.
이 판정기가 지키는 것은 **「그 공유 모듈이 여덟 키를 계속 부른다 + 소비자가
그것을 계속 import 한다」**이지 소비자 각자의 독립 소비가 아니다.
"""
import ast
import io
from pathlib import Path


def required_keys(repo_root):
    """`report()` 가 내는 카운트 키 전부 + `unknown_counts`."""
    import sys
    sys.path.insert(0, repo_root + "/shared/adjudication")
    from adjudication import Ledger
    rep = Ledger(items="open").report()
    return sorted(rep["counts"].keys()) + ["unknown_counts"]


def _shared_modules(repo_root):
    """`shared/adjudication/` 에 실재하는 모듈 이름 → 경로."""
    d = Path(repo_root) / "shared" / "adjudication"
    return {p.stem: str(p) for p in d.glob("*.py")}


def _closure(path, repo_root):
    """소비자 파일 **+ 그 파일이 import 하는 `shared/adjudication/` 모듈들**.

    카운트를 이름으로 부르는 자리가 소비자 파일이 아니라 «공유 렌더 모듈»에
    있을 수 있다 — 네 소비자가 같은 두 줄을 내려고 그 모듈을 두는 것이 이
    설계의 요점이다(§5). 파일 하나만 보면 **설계를 따르는 것이 곧 락 위반**이
    된다.
    """
    tree = ast.parse(io.open(path, encoding="utf-8").read())
    shared = _shared_modules(repo_root)
    out = [path]
    for n in ast.walk(tree):
        mods = []
        if isinstance(n, ast.ImportFrom) and n.module:
            mods.append(n.module.split(".")[-1])
        elif isinstance(n, ast.Import):
            mods += [a.name.split(".")[-1] for a in n.names]
        for m in mods:
            if m in shared and shared[m] not in out:
                out.append(shared[m])
    return out


def _consumed_names(tree):
    """키가 «읽힌» 자리 — 첨자 슬라이스와 튜플/리스트/집합 원소.

    딕셔너리 리터럴의 «키»는 세지 «않는다». 그것은 원장을 읽는 자리가 아니라
    출력을 만드는 자리라, 같은 이름의 무관한 지역 변수가 우연히 락을 만족시킨다
    — 실측: `synthesize_artifact_findings.py:131` 의 지역 카운터
    `"sources_failed": sources_failed` 가 원장의 그 칸을 읽는 것으로 세어졌다
    (그 파일의 `Ledger` 는 `source_failed()` 를 부른 적이 없다).

    튜플/리스트/집합 원소를 세는 이유는 반대쪽이다: 키 여섯을 루프로 도는 자리
    (`for _k in ("accepted", …)`)가 실제 소비인데 첨자만 보면 안 잡힌다.
    """
    found = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Subscript):
            s = n.slice
            if isinstance(s, ast.Constant) and isinstance(s.value, str):
                found.add(s.value)
        elif isinstance(n, (ast.Tuple, ast.List, ast.Set)):
            for e in n.elts:
                if isinstance(e, ast.Constant) and isinstance(e.value, str):
                    found.add(e.value)
    return found


def missing(path, keys, repo_root):
    found = set()
    for f in _closure(path, repo_root):
        found |= _consumed_names(ast.parse(io.open(f, encoding="utf-8").read()))
    return [k for k in keys if k not in found]
