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

# Task 11 (T5) — 훅에 `from adjudication import Ledger` 를 더하면서
# review-dispatch.py 가 처음으로 ㉮(회계 소비자)에 들어왔다. 이 파일의 다른
# for 문 열 자리가 그 순간 새로 이 락의 대상이 된다 — 이번 Task 가 배선한 두
# `decision:"block"` 자리(T5-1·T5-2)는 루프 «안»이 아니라서 이 열에 포함되지
# 않는다. 남은 열 자리는 전부 `select_dispatch_target()`(다음 턴에 dispatch할
# 문서 하나를 고르는 선택 루프)와 `main()` 의 검증 대상 선별 루프에 있다 —
# 신고된 발견물을 판정하는 자리가 아니라 "이번 턴에 무엇을 처리할지" 고르는
# 스케줄링 루프다.
#
# 근거(코드를 직접 읽고 확인 — 선재 판정을 그대로 받아 적지 않았다): 이 파일의
# 모듈 docstring 과 `discover_candidates.py` 의 모듈 docstring 이 함께 명시하듯
# "발견은 무상태"다 — 매 Stop 마다 `git status` 로 후보 전체를 다시 낸다.
# 그러므로 이번 턴에 선택되지 않은 후보는 «사라지는» 것이 아니라 다음 Stop 의
# 후보 목록에 그대로 다시 나타난다. 소실이라는 개념 자체가 성립하지 않는다
# (C6(1)) — "판정자가 처리하지 못해 항목이 사라졌다"는 전제가 스케줄링 루프에는
# 적용되지 않는다.
_T5_SELECT_LOOP = (
    "C6(1) — select_dispatch_target() 의 선택 루프(cands 를 훑어 dispatch 대상 "
    "하나를 고른다). discover()가 매 Stop마다 git status 로 후보 전체를 무상태 "
    "재스캔하므로, 이번 턴에 고르지 못한 후보는 사라지지 않고 다음 Stop 의 "
    "후보 목록에 그대로 다시 나타난다. 이 루프는 신고된 발견물을 판정하는 "
    "자리가 아니라 '이번 턴에 dispatch할 문서 하나'를 고르는 스케줄링이다 — "
    "회계가 대응할 처분 대상(accountable finding) 자체가 없다."
)
_T5_MAIN_VALIDATION_LOOP_INFLIGHT = (
    "C6(1) — main() 의 검증 대상 선별 루프(cands 를 훑어 validation_pool 을 "
    "만든다). is_inflight 는 arm_ledger.is_inflight(body, c.path, now) 로 매 "
    "Stop 마다 새로 계산되는 상태다 — 지금 다른 리뷰가 도는 문서를 이번 턴의 "
    "구조 검증에서만 뺀다. 리뷰가 끝나면 다음 Stop 에서 다시 후보가 되므로 "
    "영구 소실이 아니다."
)
_T5_MAIN_VALIDATION_LOOP_SUCCESS = (
    "C6(1) — main() 의 구조 검증 루프(`for key in picked`). `reasons` 가 "
    "빈 목록이면 그 문서는 구조 검증을 통과했다는 뜻이라 애초에 판정할 "
    "실패가 없다 — hold/reject 할 대상이 없는 성공 케이스에는 대응하는 "
    "처분 개념이 없다."
)

EXEMPT = {
    # ("plugins/.../foo.py", 146): "C6(1) 제자리 변형 루프 — 버려지는 항목이 없다",
    # Task 10 이 파일 상단에 `from render_disposition import disposition_lines`
    # 를 더해 이 줄이 358→359 로 밀렸다 — 인용 자체는 무변경(내용은 그대로다).
    ("plugins/quality-gates/scripts/synthesize_findings.py", 359):
        "C6(1) — dedup() 의 이 continue 는 `promoted` 항목을 그룹핑에서만 "
        "제외한다. 항목 자체는 이 loop 이전에 계산된 `passthrough` 리스트에 "
        "이미 담겨 있고 함수 반환값(`deduped + passthrough`)에 그대로 "
        "살아남는다 — 버려지는 항목이 없다.",
    # Task 10 — merge_review.py 의 `disposition_report()` 결과를 이름별로 펴는
    # 루프. `continue` 는 "reasons"·"held_by_class" 두 키를 이 loop 에서만
    # 제외한다 — 둘 다 다른 자리에서 이미/따로 실린다: "reasons" 는 이 loop
    # «이전»에 이미 `advisory.extend(merged["reasons"])`로 advisory 채널에
    # 실렸고, "held_by_class" 는 loop 직후(:619-621) 세 줄로 분해돼 실린다.
    # 버려지는 항목이 없다(C6(1)).
    ("plugins/spec-distill/scripts/merge_review.py", 618):
        "C6(1) — disposition_report().items() 를 도는 이 continue 는 "
        "\"reasons\"·\"held_by_class\" 두 키를 이 loop 에서만 제외한다. "
        "\"reasons\" 는 이 loop 이전에 이미 advisory 채널로, \"held_by_class\" "
        "는 loop 직후 세 줄(held_unadjudicated/held_malformed/held_other)로 "
        "각각 실린다 — 버려지는 항목이 없다.",
    # Task 10 수정 라운드 1 — merge_brief_review.py 가 형제 merge_review.py 와
    # 같은 편평화 루프를 쓴다. 원장이 하나뿐이라 합산이 없다는 점만 다르고
    # 제외 사유는 동일하다: "reasons" 는 이 loop 이전에 이미
    # `advisory.extend(L.reasons())`(:334)로, "held_by_class" 는 loop 직후
    # 세 줄로 각각 실린다 — 버려지는 항목이 없다.
    ("plugins/spec-distill/scripts/merge_brief_review.py", 363):
        "C6(1) — disposition_report().items() 를 도는 이 continue 는 "
        "\"reasons\"·\"held_by_class\" 두 키를 이 loop 에서만 제외한다. "
        "\"reasons\" 는 이 loop 이전에 이미 `advisory.extend(L.reasons())`(:334) "
        "로, \"held_by_class\" 는 loop 직후 세 줄(held_unadjudicated/"
        "held_malformed/held_other)로 각각 실린다 — 버려지는 항목이 없다.",

    # Task 11 (T5) — select_dispatch_target() 의 선택 루프 7 자리. 위
    # `_T5_SELECT_LOOP` 의 근거를 그대로 공유한다(동일 루프, 서로 다른 필터
    # 조건일 뿐). :338 은 그 루프의 `return c` — 첫 적격 후보를 찾고 순회를
    # 멈추는 것도 같은 이유로 소실이 아니다(discover()가 다음 Stop 에 나머지
    # 후보를 다시 낸다).
    ("plugins/spec-distill/hooks/review-dispatch.py", 327): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 329): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 331): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 333): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 335): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 337): _T5_SELECT_LOOP,
    ("plugins/spec-distill/hooks/review-dispatch.py", 338): _T5_SELECT_LOOP,

    # Task 11 (T5) — main() 의 검증 대상 선별 루프. :530 은 in-flight 스킵
    # (다른 리뷰가 도는 중 — 끝나면 다음 Stop 에 다시 후보가 된다).
    ("plugins/spec-distill/hooks/review-dispatch.py", 530):
        _T5_MAIN_VALIDATION_LOOP_INFLIGHT,

    # Task 11 (T5) — **경계 사례, 최종 리뷰가 다시 볼 것.** :533 은 검증 상한
    # (VALIDATION_ATTEMPT_CAP) 도달 스킵이다. `capped.append(c.key)` 가 바로
    # 위 같은 분기에서 먼저 실행되므로 항목 자체는 사라지지 않고 `capped` →
    # `capped_advisory` 를 타고 이번 턴의 JSON 출력 `systemMessage` 필드에
    # 실제로 실린다(추적: :554,570-574,619,627,671,680,690,774,786) — 그래서
    # C6(1)(대응물 없음)이 아니라 이미 다른 채널로 실린다는 논거로 면제한다.
    # 다만 이 Task(T5) 가 바로 옆 두 `decision:"block"` 자리에서 확인한 사실—
    # `systemMessage` 는 모델 컨텍스트에 카나리 14개 중 0개 도달— 이 이 채널
    # 에도 그대로 적용될 가능성이 있다. 즉 "실려는 있으나 그 채널이 모델에
    # 도달하는지는 검증되지 않았다." 규칙 억제(`suppressed()`)로 다시 봐야
    # 할 수 있는 자리라 baseline 문서에 남기고 최종 리뷰로 넘긴다.
    ("plugins/spec-distill/hooks/review-dispatch.py", 533):
        "C6(1)(경계) — 검증 상한 도달 스킵. `capped.append(c.key)` 가 같은 "
        "분기에서 continue 이전에 실행돼 항목이 `capped`→`capped_advisory`로 "
        "이 턴의 systemMessage 에 실린다(코드 추적 완료) — 그러나 이 Task 가 "
        "같은 파일의 decision:block 두 자리에서 실측한 바 systemMessage 는 "
        "모델 도달 카나리 0/14 다. 소실은 아니나 채널 효과가 의심되는 경계 "
        "사례 — 최종 리뷰가 재검토할 것(규칙 억제 재분류 후보).",

    # Task 11 (T5) — main() 의 구조 검증 루프. :589 는 `reasons` 가 빈
    # 성공 케이스 — 판정할 실패 자체가 없다.
    ("plugins/spec-distill/hooks/review-dispatch.py", 589):
        _T5_MAIN_VALIDATION_LOOP_SUCCESS,
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
