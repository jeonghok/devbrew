# -*- coding: utf-8 -*-
"""L1 판정기 — 버리는 분기가 처분 호출을 갖는지.

대상은 파일의 «모든» `for` 문이다. 「처분 메서드가 불리는 함수」로 좁히면 전혀
배선되지 않은 버리기가 영원히 안 보이고, 모집단이 피검자 손에 들어간다.

컴프리헨션은 대상이 아니다 — 표현식 안에 문장을 넣을 수 없어 「처분을 부르라」는
요구가 문법상 성립하지 않는다. 대신 개수를 세어 호출자가 회귀로 잡게 한다.
"""
import ast
import io

DISPOSITION = frozenset((
    "accept", "reject", "hold", "absorbed", "coerced",
    "source_failed", "uncountable", "suppressed",
))

DISCARD_NODES = (ast.Continue, ast.Break, ast.Return)

# 면제는 «이 파일»에 산다 — 피검자 파일이 아니라. 각 값은 설계 §8 의 C6 조건
# 하나를 인용해야 한다: C6(1) 대응물이 원리적으로 없음 · C6(2) 측정된 이유.
# 인용 없는 항목(빈 문자열)은 호출자가 RED 로 만든다.
#
# Task 1 Step 6 이 이 목록의 초기 내용을 정한다. 착수 시점에는 비어 있다 —
# 비어 있는 것이 이 락이 오늘 RED 인 이유의 일부다.
EXEMPT = {
    # ("plugins/.../foo.py", 146): "C6(1) 제자리 변형 루프 — 버려지는 항목이 없다",
}


def _disposition_calls(node):
    return [n for n in ast.walk(node)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
            and n.func.attr in DISPOSITION]


def _parent_map(tree):
    parents = {}
    for node in ast.walk(tree):
        for child in ast.iter_child_nodes(node):
            parents[child] = node
    return parents


def _enclosing_loop(node, parents):
    """`node` 를 감싸는 가장 안쪽 for 문. 없으면 None.

    함수 경계와 while 경계를 넘지 않는다 — 중첩 함수 안의 return 은 바깥
    루프의 버리는 분기가 아니고, for 안에 중첩된 while 의 continue/break 도
    그 while 소속이지 바깥 for 의 인구가 아니다(while 자체는 이 판정기의
    대상이 아니므로 그런 노드는 어느 for 에도 귀속되지 않는다 — 조용히
    제외된다. 함수 경계와 같은 종류의 fail-closed 다).
    """
    cur = parents.get(node)
    while cur is not None:
        if isinstance(cur, (ast.For, ast.AsyncFor)):
            return cur
        if isinstance(cur, (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda,
                            ast.While)):
            return None
        cur = parents.get(cur)
    return None


def _enclosing_branch(loop, target, parents):
    """`target` 을 감싸는 가장 안쪽 분기 본문. 없으면 None.

    분기 컨테이너는 `If.body`/`If.orelse` 뿐 아니라 `Try.body`(try 본문)·
    `Try.orelse`(else)·`Try.finalbody`(finally)·`ExceptHandler.body`(except
    본문)도 같은 자격으로 포함한다 — try/except 도 배선 태스크들에서 실제로
    쓰는 처분 형태이고, 안쪽 except 본문에 처분 호출이 있는데 If 만 인식하면
    「배선 안 됨」이라는 거짓 신호가 난다.

    부모 사슬을 «올라가서» 첫 분기 컨테이너를 만난다 — 포함 관계 그 자체다.
    본문의 «길이»를 안쪽의 대리 지표로 쓰면 안 된다: 그 둘은 같지 않고, 바깥
    분기가 더 짧으면 거기 있는 무관한 처분 호출이 이 분기를 guarded 로
    만든다.
    """
    node = target
    while node is not loop:
        parent = parents.get(node)
        if parent is None:
            return None
        if isinstance(parent, ast.If):
            if any(child is node for child in parent.body):
                return parent.body
            if any(child is node for child in parent.orelse):
                return parent.orelse
        elif isinstance(parent, ast.Try):
            if any(child is node for child in parent.body):
                return parent.body
            if any(child is node for child in parent.orelse):
                return parent.orelse
            if any(child is node for child in parent.finalbody):
                return parent.finalbody
        elif isinstance(parent, ast.ExceptHandler):
            if any(child is node for child in parent.body):
                return parent.body
        node = parent
    return None


def _func_of(tree, node):
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if any(x is node for x in ast.walk(fn)):
                return fn.name
    return "<module>"


def scan(paths):
    """버리는 분기 전수. 각 항목은 guarded 여부를 함께 낸다.

    분기 «노드»에서 출발한다 — 루프에서 출발해 하위를 훑으면 중첩 루프 안의
    한 문장이 바깥·안쪽 양쪽에 귀속돼 두 번 세어진다.
    """
    out = []
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        parents = _parent_map(tree)
        for n in ast.walk(tree):
            if not isinstance(n, DISCARD_NODES):
                continue
            loop = _enclosing_loop(n, parents)
            if loop is None:
                continue
            branch = _enclosing_branch(loop, n, parents)
            # 분기를 못 찾으면 루프 본문 전체로 넓히지 «않는다» — 그것이
            # 루프 최상위의 맨 continue 를 guarded 로 읽는 fail-open 이다.
            scope = branch if branch is not None else [n]
            out.append({
                "file": path,
                "line": n.lineno,
                "kind": type(n).__name__.lower(),
                "func": _func_of(tree, n),
                "guarded": any(_disposition_calls(s) for s in scope),
            })
    return out


def comprehension_count(paths):
    """컴프리헨션 내포 수 — 요구가 아니라 회귀 축이다."""
    total = 0
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        total += sum(
            len(n.generators) for n in ast.walk(tree)
            if isinstance(n, (ast.ListComp, ast.SetComp,
                              ast.DictComp, ast.GeneratorExp)))
    return total


import re
from pathlib import Path

_IMPORT_RE = re.compile(r'^\s*(?:from\s+adjudication\s+import|import\s+adjudication)',
                        re.M)
_ANCHOR_RE = re.compile(r'consumer=([^\s·]+\.py)')


def derive_consumers(repo_root):
    """회계 소비자(㉮) — 두 경로의 «합집합».

    import 하나로만 도출하면 «그 import 를 지우는 것»이 락에서 빠져나가는 길이
    된다. 앵커는 다른 파일(skill)에 살고 기존 락의 축 A(4)·B 가 그것을 이미
    전량 검사하므로, 피검자가 자기 파일을 고쳐서 두 번째 경로를 벗어날 수 없다.

    두 경로가 오늘 같은 집합을 내는 것이 합집합이 공허하지 않다는 증거는
    아니다 — 갈리는 순간이 회귀 신호이고 호출자가 두 값을 따로 기록한다.
    """
    repo = Path(repo_root)
    by_import, by_anchor = set(), set()

    for pat in ("plugins/*/scripts/*.py", "plugins/*/hooks/*.py"):
        for f in repo.glob(pat):
            if f.is_symlink() or not f.is_file():
                continue
            if _IMPORT_RE.search(f.read_text(encoding="utf-8")):
                by_import.add(str(f.relative_to(repo)))

    for pat in ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md",
                "plugins/*/agents/*.md"):
        for f in repo.glob(pat):
            if not f.is_file():
                continue
            for m in _ANCHOR_RE.finditer(f.read_text(encoding="utf-8")):
                cand = m.group(1)
                if (repo / cand).is_file():
                    by_anchor.add(cand)

    return sorted(by_import | by_anchor), sorted(by_import), sorted(by_anchor)
