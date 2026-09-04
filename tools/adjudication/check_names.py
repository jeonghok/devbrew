# -*- coding: utf-8 -*-
"""T4-2 판정기 — 백틱으로 불린 `<plugin>:<name>` 이 실재 정의를 갖는지.

정의 집합은 넷이다 — agent · skill · command · **kill switch 키**. 넷째를
빠뜨리면 README 의 kill switch 문서 일곱 줄이 전부 「매달린 참조」로 나온다
(실측). 그것을 코퍼스에서 빼는 대신 «정의로 인정»하는 쪽을 고른 이유는 그
네임스페이스가 실재하고, 그 실재를 «호출부에서 도출»하면 새 이빨이 생기기
때문이다: 문서화됐는데 어떤 호출부도 안 받는 키는 fail-open 결함이다.

**넷을 어디서나 합치지는 않는다.** kill switch 키는 `README.md` 에서만
인정한다 — 그 키는 README 가 문서화하고, dispatch 는 skill·command·agent 에서
일어난다. 평면으로 합치면 저자가 훅 이름을 skill 로 착각해 쓴 dispatch 가
조용히 해소된다(실측: 도출된 14키 중 8개가 agent·skill·command 가 아니다).

**이 분리가 못 막는 것** — README 안에 잘못 쓰인 dispatch 참조는 여전히
가려진다. README 는 dispatch 하지 않고 문서화한다는 전제 위에 선 대가이고,
실측으로 재현된다.

기존 dispatch 락의 표기 필터(subagent_type:|agentType:|Agent\\(|^\\s*agent:)를
«빼지 않는다». 그 필터는 산문 속 맨 영어 단어가 dispatch 로 잡히는 것을 막고
있고 그 필요는 실측으로 기록돼 있다
(test_dispatch_disposition.sh 의 `NOTATION` 정규식 바로 위 주석).

여기서는 «백틱 + 콜론» 두 조건을 동시에 요구한다. 맨 단어는 둘 다 없으므로
그 필터와 겹치지 않는다 — 우회가 아니라 직교다.
"""
import ast
import re
from pathlib import Path

# 이력 문서는 과거 이름을 legitimately 담는다. 지운 이름을 CHANGELOG 가
# 말하지 못하게 되면 그것이야말로 이력의 소실이다.
#
# **오늘은 비활성이다** — 아래 `references()` 의 글롭 넷(skills/·commands/·
# agents/·README.md)이 플러그인 루트의 `CHANGELOG.md` 에 닿지 않는다. 글롭을
# 넓히는 날을 위한 가드로 남긴다. 죽은 코드처럼 보이지만 «지금 닿지 않을 뿐»
# 이라는 사실을 여기 적어 둔다.
EXEMPT_FILES = ("CHANGELOG.md",)

# 백틱 안, `<plugin>:<name>` 꼴. 양쪽 다 kebab-case 만.
_REF_RE = re.compile(r'`([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)`')

# `references()` 가 실제로 여는 코퍼스 — README.md 포함 넷. `scanned_paths()`
# 가 같은 튜플을 재사용한다(재도출 아님) — `--emit-scanned` 가 이 함수와
# 다른 글롭을 내면 낸 것과 읽은 것이 갈린다.
_REF_GLOBS = ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md",
              "plugins/*/agents/*.md", "plugins/*/README.md")

# `killswitch_keys()` 가 실제로 여는 코퍼스. `scanned_paths()` 가 같은
# 문자열을 재사용한다 — 하나의 상수로 묶는 이유는 두 함수가 «따로» 자기
# 글롭을 들고 있으면 한쪽만 바뀌어 갈릴 수 있기 때문이다(Task 12b 수정
# 라운드 1 리뷰가 지적한 것 — scanned_paths() 가 이 코퍼스를 아예 빼고
# 있었는데, dangling() 이 실제로 이 코퍼스를 소비한다: killswitch_keys() 의
# 결과가 defined(allow_killswitch=True) 를 거쳐 README 참조 판정에 쓰인다).
# 판정기의 스캔 «범위»는 좁히지 않는다 — 오늘 열거된 8개 호출부가 전부
# hooks/scripts 아래 있다고 해서 글롭을 그 두 디렉터리로 좁히면, 내일 다른
# 위치에 kill switch 호출이 생겨도 판정기가 조용히 못 본다.
_KILLSWITCH_GLOB = "plugins/*/**/*.py"


def _is_killswitch_call(func):
    if isinstance(func, ast.Name):
        return func.id == "kill_switch_active"
    if isinstance(func, ast.Attribute):
        return func.attr == "kill_switch_active"
    return False


def killswitch_keys(repo_root):
    """kill switch 키 — `kill_switch_active()` **호출부의 리터럴 인자**에서 도출한다.

    키를 열거한 표를 두지 않는다. 표는 공간·시간 양쪽으로 fail-open 이다
    (`kill_switch_active.py` 도입부가 같은 이유로 전역 스위치 변수명도 도출한다).

    이 축의 이빨: README 가 문서화한 키를 **어떤 호출부도 받지 않으면** 사용자는
    껐다고 믿는데 아무 일도 안 일어난다. kill switch 는 보안 컨트롤이라
    (CLAUDE.md) 그 결함의 방향이 fail-open 이고, 정본 모듈의 도입부가 그 사고를
    실측으로 기록한다 — `spec-distill-gc.py` 가 그 변수를 아예 안 읽었다.
    """
    out = set()
    for f in sorted(Path(repo_root).glob(_KILLSWITCH_GLOB)):
        if f.is_symlink() or not f.is_file():
            continue
        try:
            tree = ast.parse(f.read_text(encoding="utf-8"))
        except SyntaxError:
            continue
        for n in ast.walk(tree):
            if not (isinstance(n, ast.Call) and _is_killswitch_call(n.func)):
                continue
            args = [a.value for a in n.args
                    if isinstance(a, ast.Constant) and isinstance(a.value, str)]
            if len(args) >= 2:
                out.add("%s:%s" % (args[0], args[1]))
                # 이벤트명 별칭 — 정본이 훅명과 이벤트명 둘 다 받는다.
                if len(args) >= 3 and args[2]:
                    out.add("%s:%s" % (args[0], args[2]))
    return out


def defined(repo_root, allow_killswitch=False):
    """실재하는 `<plugin>:<name>` — agent · skill · command (+선택적으로 kill switch 키).

    `allow_killswitch` 는 **참조가 사는 파일 종류**가 정한다. kill switch 키는
    README 가 문서화하는 것이고, dispatch 는 skill·command·agent 에서 일어난다.
    네 네임스페이스를 어디서나 평면으로 합치면 **가림**이 생긴다 — 저자가 훅
    이름을 skill 이름으로 착각해 `Dispatch `<plugin>:<hook>`` 라고 써도 조용히
    해소된다. 실측: 도출된 키 14개 중 **8개가 agent·skill·command 가 전혀 아닌**
    실재 문자열이다.

    문맥을 «동사»(`Dispatch` 등)로 가르지 않는다 — 키 이름 자체에 `dispatch` 가
    든 것이 있어(`spec-distill:review-dispatch`) 그 매칭이 자기 자신을 문맥으로
    오인한다. 파일 종류는 그 함정이 없다.
    """
    repo = Path(repo_root)
    out = set(killswitch_keys(repo_root)) if allow_killswitch else set()
    for pdir in sorted(repo.glob("plugins/*")):
        if not pdir.is_dir():
            continue
        plugin = pdir.name
        for f in sorted(pdir.glob("agents/*.md")):
            m = re.search(r'^name:\s*(\S+)\s*$', f.read_text(encoding="utf-8"),
                          re.M)
            if m:
                out.add("%s:%s" % (plugin, m.group(1).split(":")[-1]))
        for f in sorted(pdir.glob("skills/*/SKILL.md")):
            out.add("%s:%s" % (plugin, f.parent.name))
        for f in sorted(pdir.glob("commands/*.md")):
            out.add("%s:%s" % (plugin, f.stem))
    return out


def _plugins(repo_root):
    return {p.name for p in Path(repo_root).glob("plugins/*") if p.is_dir()}


def references(repo_root):
    """코퍼스에서 백틱으로 불린 참조 전부.

    plugin 부분이 실재 플러그인 디렉토리명일 때만 참조로 본다 — 그래야
    `key:value` 같은 무관한 백틱 문자열이 걸리지 않는다.
    """
    repo = Path(repo_root)
    plugins = _plugins(repo_root)
    out = []
    for pat in _REF_GLOBS:
        for f in sorted(repo.glob(pat)):
            if not f.is_file() or f.name in EXEMPT_FILES:
                continue
            rel = str(f.relative_to(repo))
            for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                for m in _REF_RE.finditer(line):
                    if m.group(1) in plugins:
                        out.append((rel, i, "%s:%s" % (m.group(1), m.group(2))))
    return out


def scanned_paths(repo_root):
    """`--emit-scanned` 코퍼스 — `references()` 와 `killswitch_keys()` 가
    실제로 여는 파일 전부(참조/호출이 0건이어도 글롭에 매칭돼 `read_text()`
    가 불린 파일은 포함한다). `defined()` 의 agents/*.md 글롭은 `_REF_GLOBS`
    안에 이미 있다(동일 패턴) — 따로 더하지 않는다.

    `_KILLSWITCH_GLOB`(`plugins/*/**/*.py`, 실측 155개 — 글롭 자체는 161개를
    매칭하지만 6개는 심볼릭 링크라 `killswitch_keys()`·이 함수 둘 다 같은
    필터로 뺀다, 2026-09-04) 는
    **포함한다** — 이전 판(Task 12b 1라운드)은 이것을 "이 락의 주 모집단이
    아닌 보조 네임스페이스"라며 뺐는데, 그 판단이 틀렸다: `dangling()` 이
    README 참조에 대해 `defined(allow_killswitch=True)` 를 쓰고, 그 함수가
    `killswitch_keys()` 를 실제로 호출해 이 코퍼스를 소비한다 — 이 파일들이
    바뀌면 `dangling` 판정이 실제로 바뀐다. "포함하면 plugins 전체 .py 로
    넓어져 정밀도를 죽인다"는 우려도 근거가 약하다: `kill_switch_active()`
    를 실제로 «호출»하는 파일은 8개뿐이고(실측) 전부 `plugins/*/hooks/*.py`
    또는 `plugins/*/scripts/*.py` 안에 있다 — 이미 다른 두 락
    (`test_adjudication_wiring.sh`·`test_adjudication_consumed.sh`) 이
    같은 두 글롭을 선언으로 쓰고 있어 catch-all 이 아니다. 그럼에도 «판정기
    자신»의 스캔 글롭은 그 두 디렉터리로 좁히지 않는다 — 좁히면 판정기의
    동작이 바뀌고(열거의 함정: 내일 다른 위치에 kill switch 호출이 생기면
    조용히 못 본다), 넓은 선언은 그것이 참이면 결함이 아니다."""
    repo = Path(repo_root)
    out = set()
    for pat in _REF_GLOBS:
        for f in repo.glob(pat):
            if f.is_file():
                out.add(str(f.relative_to(repo)))
    for f in repo.glob(_KILLSWITCH_GLOB):
        if f.is_symlink() or not f.is_file():
            continue
        out.add(str(f.relative_to(repo)))
    return sorted(out)


def dangling(repo_root):
    """참조가 사는 파일 종류에 따라 정의 집합을 달리 적용한다."""
    strict = defined(repo_root, allow_killswitch=False)
    loose = defined(repo_root, allow_killswitch=True)
    out = []
    for (path, line, tok) in references(repo_root):
        known = loose if Path(path).name == "README.md" else strict
        if tok not in known:
            out.append((path, line, tok))
    return out
