# 판정 지형 — 회계 배선과 도출 락 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 판정 항목이 버려질 때 `Ledger` 메서드를 반드시 부르게 배선하고, 그것을 부르는지 검사하는 락 넷을 두되 검사 대상을 목록이 아니라 구조에서 도출한다.

**Architecture:** 회계 어휘(`shared/adjudication/adjudication.py`)는 이미 완성돼 있고 배선과 소비가 절반이다. 세 층으로 작업한다 — ⑴ `shared/` 의 어휘를 둘 확장(`suppressed()`·`held_by_class()`) ⑵ 락 다섯을 `shared/tests/` 에 신설, 모집단은 전부 구조 도출(파일 glob·frontmatter `name:`·기존 도출기 출력) ⑶ 소비자 넷과 훅 하나를 배선. 락이 먼저 들어가고(PR1, 전부 RED) 배선이 그것을 GREEN 으로 만든다(PR2). AST 판정 로직은 셸이 아니라 `shared/adjudication/check_*.py` 에 두고 셸 락은 그것을 호출만 한다.

**Tech Stack:** Python 3(표준 라이브러리 `ast` 만 — 서드파티 없음) · bash 3.2 호환 셸 테스트(`shared/tests/assert.sh` 헬퍼) · YAML(`pyyaml`, 기존 의존)

**Spec:** `docs/superpowers/specs/2026-09-02-adjudication-topology-design.md`

## Global Constraints

설계와 리포 규약에서 그대로 옮긴다. **모든 Task 의 요구사항에 이 절이 암묵적으로 포함된다.**

- **버전 bump** — `plugins/<name>/` 를 건드리는 모든 커밋에 같은 커밋 안에서 SemVer bump. 현재 `quality-gates` = `5.1.0`, `spec-distill` = `0.47.0`. 파일은 `plugins/<name>/.claude-plugin/plugin.json` (루트가 아니다). v1.0.0 이상이면 `CHANGELOG.md` 항목도 같은 커밋에.
- **`shared/` 는 플러그인이 아니다** — 그 자체로는 bump 대상이 아니지만, `shared/adjudication/adjudication.py` 는 `plugins/quality-gates/scripts/adjudication.py` 와 `plugins/spec-distill/scripts/adjudication.py` 로 **심볼릭 링크(git mode 120000)** 되어 있으므로 그것을 고치면 **두 플러그인 다 bump** 한다.
- **커밋 메시지** — Conventional Commits (`<type>(<scope>): <설명>`). 브랜치는 이미 `feature/adjudication-topology-unification`.
- **문서 언어** — 한국어 primary. 영어는 식별자·고유명사·원문 인용·자연스러운 한국어 대응이 없는 기술어(`frontmatter`·`hook`·`subagent` 등)에 한정.
- **Self-narrating artifact 금지** — 모델이 읽고 행동하는 산출물(락 파일의 주석 포함)에 「무엇이 이 파일을 만들었다」·배경·존재 정당화를 넣지 않는다. **단 실측 사실과 실패 이력은 예외** — 이 리포의 기존 락들이 그렇게 하고 있고, 그것은 자기 정당화가 아니라 다음 저자가 같은 함정에 빠지지 않게 하는 데이터다.
- **`PYTHONDONTWRITEBYTECODE=1`** — 파이썬을 부르는 모든 테스트/변이 실행에 붙인다. 같은 길이 변이가 stale `.pyc` 를 넘지 못해 거짓 GREEN·거짓 RED 를 둘 다 낸 기록이 있다.
- **heredoc 을 `$( )` 안에 넣지 않는다** — `shared/tests/test_dispatch_disposition.sh:43-51` 이 실측으로 기록한다. 파이썬 본문의 `\'` + `)` 교차항에서 `bash -n` 이 죽는다. 파일이나 리다이렉트로 받는다.
- **면제는 락의 상수에 산다** — 저자 파일이 아니라. 각 면제 항목은 설계 §8 의 C6 두 조건 중 하나를 인용한다: **C6⑴** 대응물이 원리적으로 없음 · **C6⑵** 측정된 이유(기존에 기록된 설계 이유 포함). 인용이 없으면 RED.
- **변이 전에 커밋한다** — `git checkout --` 는 「내 마지막 변이」가 아니라 HEAD 로 되돌린다.
- **워크트리 밖으로 나가지 않는다** — 모든 명령을 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+adjudication-topology-unification` 에서 실행한다. `cd` 로 원본 리포에 가지 않는다. `git stash` 를 맨손으로 쓰지 않는다(스택이 워크트리 간 공유).

---

## 이 계획이 닫는 미결 (설계 §14 의 U1~U4)

설계는 이 넷의 형태를 **의도적으로 정하지 않고** 넘겼다 — 앞 판본들이 산문으로 정했다가 리뷰어가 파일을 열어 반증했기 때문이다. 여기서 닫되, 각 결정의 근거는 **이 계획이 실행한 측정(F5)** 이거나 리포 파일의 인용이다.

| # | 설계가 남긴 미결 | 이 계획의 결정 | 근거 | 어느 Task |
|---|---|---|---|---|
| **U1** | L1 의 정밀 구현 + 면제 목록 초기 내용 | 대상 = `ast.For`/`ast.AsyncFor` **문**. 버리는 분기 = `continue`·`break`·이른 `return` **셋만**. 「본문 끝까지 append 없음」은 **v1 범위 밖**(Known gap). 컴프리헨션은 **별도 회귀 축**(개수 baseline 초과 시 RED) | F5 census — `for` 문 39 · 컴프리헨션 내포 28 · `continue` 20(미배선 ~13) | Task 1·3 |
| **U2** | L3 의 슬롯 문법 + `kind:` 판정기 | frontmatter `input_slots:` 리스트(`tag`·`var`·`kind`·`optional`). `kind:` 는 **선언값 판정** + **변수명 휴리스틱**을 보조 축으로 | `test_seed_agents.sh:119-120` 의 `PAIR_RE` 가 이미 (태그,변수) 쌍을 정규화한다 — 문법을 그 위에 세운다 | Task 7·13 |
| **U3** | L4 의 런타임 인터페이스 + T5 의 `reason` 이 회계 요건을 충족하는가 | L4 는 **선언만** 검사(정적). 런타임 도달은 **범위 밖**(Known gap). T5 의 `reason` 은 **충족한다** — 조건은 `Ledger.reasons()` 의 줄을 그 필드에 싣는 것 | 인터뷰 실측 `reason` 7/7 모델 도달. CLAUDE.md 「공시와 차단은 다른 술어 — 무엇이 degrade 든 언제나 드러내되」 | Task 5·11 |
| **U4** | T4-2 토큰 규칙 + `held_by_class()` 미지 접두 처리 | T4-2 는 기존 `NOTATION` 필터를 **빼지 않고** 두 번째 코퍼스를 **더한다** — 백틱 안의 `<plugin>:<name>` 꼴만. 미지 접두는 `"기타"` 키로 모으고 0이 아니면 §5 배관 칸에 싣고 stderr advisory | 설계 §6 의 실측 제약(맨 `adversarial` 5줄 산문)을 우회가 아니라 직교로 푼다 — 맨 단어에는 백틱도 콜론도 없다 | Task 2·6 |

---

## F5 — 이 계획이 실행한 측정

설계의 F2 는 프로브가 `ast.Continue` 만 보고 **5자리**를 냈고 **스스로 「하한」이라 적었다**. 전수를 다시 셌다.

```
파일                              for문  컴프리헨션  continue 줄번호                      처분호출 줄번호
synthesize_findings.py             7        8      233 239 295 307 310 333             305
synthesize_artifact_findings.py    5       13      105 109 109 200 203 216 221         199
merge_review.py                   17        5      97 153 158 268 322 371              96 104 295 321 369 489 538
merge_brief_review.py             10        2      182                                 180 192 289
──────────────────────────────────────────────────────────────────────────────────────────────────
합계                              39       28      continue 20 · break 0 · return(루프 내) 1
```

**읽는 법 셋.**

1. **미배선 `continue` 는 약 13자리** — 처분 호출 줄번호와 인접하지 않은 것: `synthesize_findings` 233·239·295·310·333 / `synthesize_artifact` 105·109·203·216·221 / `merge_review` 153·158·268. F2 의 5자리의 **2.6배**다. **Task 1 의 P3 가 이 목록을 정밀 구현으로 확정한다 — 위 13은 인접 휴리스틱의 산출이지 오라클이 아니다.**
2. **`break` 0 · 루프 내 `return` 1** — 설계 §4.1 이 정의한 네 버리기 형태 중 둘은 오늘 거의 안 쓰인다. 그래도 락에 넣는다(미래의 우회 경로).
3. **컴프리헨션 내포 28개는 설계에 없던 구멍이다.** `[f for f in xs if ok(f)]` 는 `ast.For` 가 아니라 `ast.comprehension` 이라 L1 의 대상 밖이고, 버리기를 그 형태로 바꾸면 락이 조용해진다. 문법상 표현식 안에 처분 호출 **문장**을 넣을 수 없으므로 「처분을 요구한다」는 요구 자체가 성립하지 않는다(C6⑴). 그래서 요구하지 않고 **개수를 baseline 으로 못 박아 증가를 RED 로 만든다** — 우회가 조용하지 않게.

---

## File Structure

**신설 — `shared/adjudication/`** (판정 로직. 셸이 아니라 파이썬. 각각 fixture 로 단위 테스트 가능)

| 파일 | 책임 |
|---|---|
| `check_wiring.py` | L1 판정기 — 주어진 파일들의 `for` 문에서 버리는 분기를 찾아 처분 호출 유무를 낸다. 면제 상수를 소유한다 |
| `check_consumed.py` | L2 판정기 — `report()` 의 카운트 키가 소비자의 출력 경로에 실리는지 |
| `check_slots.py` | L3 판정기 — agent frontmatter 의 `input_slots:` ↔ dispatch 자리의 (태그,변수) 쌍 일치 + `kind:` 금지 종류 |
| `check_names.py` | T4-2 판정기 — 백틱 안 `<plugin>:<name>` 참조가 실재 정의를 갖는지 |

**신설 — `shared/tests/`** (락. 위 판정기를 실제 코퍼스에 돌리고 `assert.sh` 로 판정)

| 파일 | 락 |
|---|---|
| `test_adjudication_wiring.sh` | **L1** |
| `test_adjudication_consumed.sh` | **L2** |
| `test_agent_input_slots.sh` | **L3** |
| `test_runner_disposition.sh` | **L4** |
| `test_dispatch_name_defined.sh` | **T4-2** |
| `fixtures/adjudication/` | 위 판정기들의 단위 테스트용 소형 파이썬/마크다운 fixture |

**수정**

| 파일 | 무엇 |
|---|---|
| `shared/adjudication/adjudication.py` | `suppressed()` 추가 · `held_by_class()` 추가 · `report()["counts"]` 에 `suppressed` 추가 |
| `plugins/quality-gates/scripts/synthesize_findings.py` | T1-1·2·3·4·8·9·10·12 |
| `plugins/quality-gates/scripts/synthesize_artifact_findings.py` | T1-5·6·7·11 |
| `plugins/spec-distill/hooks/review-dispatch.py` | T5-1·2 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` | T4-1 (`:511` 의 stale 이름) |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | `:116` 의 merge_review 출력 키 열거 (L2 가 카운트를 실으면 깨진다) |
| `plugins/*/agents/*.md` (20개) | `input_slots:` 선언 (PR3) |
| `plugins/*/skills/**/SKILL.md` 의 dispatch 자리 | 슬롯 표기 (PR3) |

**경계** — 판정기는 `shared/adjudication/` 에, 락은 `shared/tests/` 에. 락은 판정기를 **호출만** 한다. 이유는 둘: ⑴ 판정기를 fixture 로 단위 테스트할 수 있어야 M6 의 변이가 「락이 죽었나」와 「판정기가 죽었나」를 구별한다 ⑵ 셸 안의 파이썬 heredoc 이 이 리포에서 **다섯 번 조용히 깨진 기록**이 있다.

---

## PR1 — 락 다섯 (전부 RED 인 채로 들어간다)

**왜 RED 인 채로 들어가나** — 락이 오늘 RED 라는 것이 「이 락에 이빨이 있다」의 증거다(설계 M1). 배선 뒤에 락을 넣으면 도착 즉시 GREEN 이고, 그 GREEN 이 배선 덕인지 락이 아무것도 안 재서인지 구별할 수 없다.

**대가** — 리포에 CI 가 없고 자동 실행자를 만들지 않기로 했으므로(설계 D6), PR1 의 RED 커밋이 merge 후 `main` 의 조상이 된다. GREEN 인 것은 **트리 상태**이지 히스토리가 아니다. 이것은 완화되지 않았다(설계 §4.5·§13).

---

### Task 1: 선결 조건 — baseline 과 전수 census

설계 §9 의 P1~P6. **이 Task 의 산출물이 뒤 Task 전부의 기준점이다** — 특히 P4 의 baseline 없이는 M10(「신규 RED 0」)을 잴 수 없고, P3 의 census 없이는 L1 의 면제 목록을 정할 수 없다.

**Files:**
- Create: `docs/superpowers/plans/2026-09-03-adjudication-topology-baseline.md`
- Create: `shared/adjudication/check_wiring.py` (초안 — Task 3 이 락으로 감싼다)

**Interfaces:**
- Produces: `check_wiring.py` 의 `scan(paths) -> list[dict]` — 각 dict 는 `{"file": str, "line": int, "kind": "continue"|"break"|"return", "func": str, "guarded": bool}`. Task 3 의 락과 Task 8·9 의 배선이 이 함수의 출력을 오라클로 쓴다.
- Produces: `check_wiring.py` 의 `comprehension_count(paths) -> int` — Task 3 의 회귀 축이 소비한다.
- Produces: baseline 문서의 「선재 RED 목록」 — Task 15 의 M10 이 대조한다.

- [ ] **Step 1: P4 — 기존 락 전량 baseline 캡처**

`shared/tests/` 와 두 플러그인의 `tests/` 를 전부 돌리고 결과를 파일로 남긴다. **이것을 먼저 하는 이유**: 이 리포는 `main` 에 선재 RED 가 있는 것으로 기록돼 있고, 그것을 내 작업의 회귀로 오인하면 진단이 통째로 틀어진다.

```bash
mkdir -p /tmp/adjtopo
for t in shared/tests/test_*.sh; do
  printf '=== %s ===\n' "$t"
  bash "$t" 2>&1 | tail -3
done > /tmp/adjtopo/baseline-shared.txt 2>&1

for t in plugins/quality-gates/tests/test_*.sh plugins/spec-distill/tests/test_*.sh; do
  printf '=== %s ===\n' "$t"
  bash "$t" 2>&1 | tail -3
done > /tmp/adjtopo/baseline-plugins.txt 2>&1

grep -c '^=== ' /tmp/adjtopo/baseline-shared.txt /tmp/adjtopo/baseline-plugins.txt
grep -B3 'Fail: [1-9]' /tmp/adjtopo/baseline-shared.txt /tmp/adjtopo/baseline-plugins.txt | grep '^===' | sort -u
```

- [ ] **Step 2: baseline 문서를 쓴다 — 선재 RED 마다 «이름과 이유»**

`docs/superpowers/plans/2026-09-03-adjudication-topology-baseline.md` 에 표로 적는다. **이유 없이 이름만 적지 않는다** — 면제 목록은 그 질문을 영구히 닫고, 이유가 없으면 다음 저자가 그것이 무해한지 판단할 근거를 잃는다.

```markdown
# 착수 시점 baseline (Task 1)

기준 커밋: <HEAD 의 SHA>
실행: `bash shared/tests/test_*.sh` · `bash plugins/*/tests/test_*.sh`

## 선재 RED

| 락 | 실패 단언 | 왜 오늘 RED 인가 | 내 작업과 관계 |
|---|---|---|---|
| <경로> | <단언 문구> | <이유> | 무관 / 이 계획이 고친다 / 이 계획이 건드린다 |

## GREEN 인 락 <개수>개

(전량 목록 — M10 이 이것과 대조한다)

## §8 제외 범위 추가 후보 (Step 8 이 채운다)

| 자리 | C6 | 근거 |
|---|---|---|
```

- [ ] **Step 3: P2 — ㉯ 도출 재실행 + 후처리 확인**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 plugins/quality-gates/tests/lib/extract_codex_invocations.py "$(pwd)/plugins" > /tmp/adjtopo/codex-invocations.txt
echo "후처리 전:"; wc -l < /tmp/adjtopo/codex-invocations.txt
grep '/scripts/' /tmp/adjtopo/codex-invocations.txt > /tmp/adjtopo/codex-runners.txt
echo "/scripts/ 후처리 후:"; wc -l < /tmp/adjtopo/codex-runners.txt
cat /tmp/adjtopo/codex-runners.txt
```

기대: 후처리 전 **7**(러너 6 + `tests/spike/test_codex_json_extraction.sh`), 후 **6**.
**그 도구 파일을 고치지 않는다** — `collect()` 의 출력이 `plugins/quality-gates/tests/test_sandbox_enforced.sh:51-62` 의 standing assertion 에 묶여 있고, 그 파일의 `:58-74` 주석이 확장자 필터를 «의도적으로 제거했다»고 적는다. 스코프는 후처리로만 준다.

- [ ] **Step 4: P3 — L1 판정기 초안을 쓴다**

`shared/adjudication/check_wiring.py`:

```python
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


def _disposition_calls(node):
    return [n for n in ast.walk(node)
            if isinstance(n, ast.Call) and isinstance(n.func, ast.Attribute)
            and n.func.attr in DISPOSITION]


def _enclosing_branch(loop, target):
    """`target` 을 직접 감싸는 가장 «안쪽» If 본문. 없으면 None.

    바깥 If 를 고르면 scope 가 넓어져 무관한 처분 호출이 이 분기를 guarded 로
    만든다 — fail-open 이다. 그래서 후보 중 가장 짧은 것을 고른다.
    """
    best = None
    for anc in ast.walk(loop):
        if not isinstance(anc, ast.If):
            continue
        for body in (anc.body, anc.orelse):
            if any(x is target for stmt in body for x in ast.walk(stmt)):
                if best is None or len(body) < len(best):
                    best = body
    return best


def _func_of(tree, node):
    for fn in ast.walk(tree):
        if isinstance(fn, (ast.FunctionDef, ast.AsyncFunctionDef)):
            if any(x is node for x in ast.walk(fn)):
                return fn.name
    return "<module>"


def scan(paths):
    """버리는 분기 전수. 각 항목은 guarded 여부를 함께 낸다."""
    out = []
    for path in paths:
        tree = ast.parse(io.open(path, encoding="utf-8").read())
        loops = [n for n in ast.walk(tree)
                 if isinstance(n, (ast.For, ast.AsyncFor))]
        for loop in loops:
            for n in ast.walk(loop):
                if not isinstance(n, DISCARD_NODES):
                    continue
                branch = _enclosing_branch(loop, n)
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
```

- [ ] **Step 5: P3 — 전수를 돌려 U1 을 닫는다**

`/tmp/adjtopo/run_scan.py` 를 쓰고 실행한다 (heredoc 을 `$()` 안에 넣지 않는다):

```python
import sys
sys.path.insert(0, 'shared/adjudication')
from check_wiring import scan, comprehension_count

FILES = ['plugins/quality-gates/scripts/synthesize_findings.py',
         'plugins/quality-gates/scripts/synthesize_artifact_findings.py',
         'plugins/spec-distill/scripts/merge_review.py',
         'plugins/spec-distill/scripts/merge_brief_review.py']
rows = scan(FILES)
bad = [r for r in rows if not r['guarded']]
for r in bad:
    print('%-34s :%-5d %-8s %s'
          % (r['file'].split('/')[-1], r['line'], r['kind'], r['func']))
print('---')
print('버리는 분기 %d 중 미배선 %d' % (len(rows), len(bad)))
print('컴프리헨션 내포 %d' % comprehension_count(FILES))
```

```bash
PYTHONDONTWRITEBYTECODE=1 python3 /tmp/adjtopo/run_scan.py
```

- [ ] **Step 6: 면제 후보를 고르고 baseline 문서에 적는다**

Step 5 의 미배선 목록에서, **설계 T1 표(이 계획의 Task 8·9)가 배선할 자리를 뺀** 나머지가 면제 후보다. 각 후보에 C6 조건을 인용한다. 예상되는 형태 둘:

| 후보 형태 | C6 | 인용 |
|---|---|---|
| 제자리 변형 루프 — 출력 컬렉션이 없고 원소를 수정만 한다 (`synthesize_artifact_findings.py:146` 의 `for f in findings: f.setdefault(...)`) | ⑴ | 버려지는 항목이 없으므로 처분할 대상이 없다 |
| 순수 집계 루프 — `continue` 가 「이 원소는 이 집계에 안 들어간다」이지 항목 소실이 아님 | ⑴ | 같음 |
| **선택 루프** — 출력이 컬렉션이 아니라 «단일 선택»(`for c in cands: … return c`)이거나, 걸러진 원소가 «별도 컬렉션에 수집»된다 | ⑴ | 버려지는 항목이 없다. 후보는 다음 호출에 다시 평가되거나 다른 리스트에 살아 있다 |

**세 번째 형태는 착수 전 pre-flight 가 실측으로 찾았다.** Task 11 이 훅을 ㉮ 에 넣으면 `review-dispatch.py` 의 버리는 분기 **10자리**가 L1 의 대상이 되는데(`continue` 9 + 루프 내 `return` 1), Task 11 이 배선하는 것은 2자리이고 **그 둘은 이 루프들 안에 있지도 않다**. 세 루프를 읽은 결과 열 자리 모두 항목이 소실되지 않는다 — 자세한 근거는 `.superpowers/sdd/2026-09-03-adjudication-topology/progress.md` 의 R1.

**그 열 중 둘(`:308`·`:310` 의 상한 도달 분기)은 다툼의 여지가 있다** — 규칙 억제(`suppressed()`)로 볼 수도 있다. 면제로 두되 그 사실을 baseline 문서에 적는다.

**인용 없는 항목은 넣지 않는다** — 넣으면 Task 3 의 락이 RED 를 낸다. 그것이 이 규칙의 이빨이다.

- [ ] **Step 7: P5 — 훅에서 `adjudication` import 가 실제로 되는지 확인**

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -c "import sys; sys.path.insert(0, 'plugins/spec-distill/scripts'); from adjudication import Ledger; L = Ledger(items='open'); L.hold('probe', '도달 확인'); print('reachable:', L.report()['counts']['held'] == 1)"
ls -l plugins/spec-distill/scripts/adjudication.py
sed -n '50,54p' plugins/spec-distill/hooks/review-dispatch.py
```

기대: `reachable: True`, 심볼릭 링크 존재, `:52-53` 이 `SCRIPTS_DIR` 을 `sys.path` 에 넣는다. **실패하면 Task 11(T5)을 재설계한다** — 그때는 여기서 멈추고 보고한다.

- [ ] **Step 8: P1 — L3 와 기존 seed 락의 충돌 확인**

```bash
bash plugins/spec-distill/tests/test_seed_agents.sh 2>&1 | tail -5
grep -n 'PAIR_RE\|PAIR_SED\|input_slots' plugins/spec-distill/tests/test_seed_agents.sh
grep -rn 'check_seed.py' plugins/spec-distill/scripts/ plugins/spec-distill/skills/ 2>/dev/null | head -5
bash plugins/spec-distill/tests/test_seed_one_sentence.sh 2>&1 | tail -5
```

**충돌해도 L3 를 빼지 않는다**(설계 P1). 충돌하는 그 자리만 baseline 문서의 「§8 추가 후보」 절에 C6⑵ 로 적는다.

- [ ] **Step 9: P6 — 형제 세션과 `review-dispatch.py` 동시 편집 조율**

**존치 확인이 아니다.** 입력 인터뷰 `:190-193` 이 OQ3 을 이미 닫았다 — 형제는 그 훅을 걷어내지 않고 **목적지 리터럴만** 고친다. 실제 제약은 같은 파일을 두 사이클이 동시에 고치는 것이다.

```bash
git fetch origin
git log --oneline origin/main -5
git log --oneline --all -- plugins/spec-distill/hooks/review-dispatch.py | head -10
```

baseline 문서에 「내가 만질 자리 = `:598-602`·`:751-755` 의 두 `decision:"block"` 분기 / 형제가 만질 자리 = 목적지 리터럴」을 적고, **Task 11 착수 직전에 다시 확인한다** — 확인과 편집 사이가 창이다.

- [ ] **Step 10: 커밋**

```bash
git add docs/superpowers/plans/2026-09-03-adjudication-topology.md docs/superpowers/plans/2026-09-03-adjudication-topology-baseline.md shared/adjudication/check_wiring.py
git commit -m "chore(adjudication): 착수 baseline 과 L1 판정기 초안 — P1~P6"
```

플러그인 파일을 안 건드렸으므로 이 커밋에는 bump 가 없다.

---

### Task 2: `Ledger` 어휘 확장 — `suppressed()` 와 `held_by_class()`

**왜 락보다 먼저인가** — L2(소비 락)의 요구가 「`report()` 의 카운트가 **전부** 프로덕션 출력에 실려야 한다」이므로, 카운트 «목록»이 확정되기 전에는 L2 가 무엇을 요구하는지 정의되지 않는다. 어휘 확장은 생산이 아니라 계약이고 락이 그 계약을 잰다. **설계는 이 순서를 명시하지 않았다 — 이 계획이 정한다.**

**Files:**
- Modify: `shared/adjudication/adjudication.py` (심볼릭 링크로 두 플러그인에 배포됨)
- Test: `shared/tests/test_adjudication_behavior.sh`
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/spec-distill/.claude-plugin/plugin.json` · 두 `CHANGELOG.md`

**Interfaces:**
- Produces: `Ledger.suppressed(item, why)` — 규칙 억제. 내부 리스트 `self._suppressed: list[(item, why)]`
- Produces: `Ledger.held_by_class() -> dict[str, int]` — 키는 정확히 `"판정자 부재"` · `"항목 파손"` · `"기타"` 셋. 값의 합은 항상 `report()["counts"]["held"]` 와 같다
- Produces: `report()["counts"]["suppressed"]: int` — **기존 여섯 카운트가 일곱이 된다**
- Consumes: 없음 (`shared/` 의 뿌리)

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`shared/tests/test_adjudication_behavior.sh` 끝의 `finish` 호출 **앞**에 추가:

```bash
note "── 억제(D4) — reject 와 다른 칸이다"
OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_ROOT/shared/tests/fixtures/adjudication/probe_suppressed.py" "$REPO_ROOT")"
assert_contains "$OUT" "suppressed=1"   "suppressed() 가 자기 칸에 센다"
assert_contains "$OUT" "rejected=0"     "억제는 기각에 섞이지 않는다 (D4)"
assert_contains "$OUT" "blocks=False"   "규칙 억제는 차단이 아니다"
assert_contains "$OUT" "degraded=False" "규칙 억제는 degrade 가 아니다 — 규칙이 정한 결과다"

note "── held_by_class — 접두별 분류"
OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$REPO_ROOT/shared/tests/fixtures/adjudication/probe_held_class.py" "$REPO_ROOT")"
assert_contains "$OUT" "부재=1" "held_by_class: 판정자 부재"
assert_contains "$OUT" "파손=2" "held_by_class: 항목 파손"
assert_contains "$OUT" "기타=1" "held_by_class: 미지 접두는 «기타» 로 — 조용히 사라지지 않는다 (U4)"
assert_contains "$OUT" "합=4"   "held_by_class 의 합 == held 총계. 어느 항목도 분류에서 빠지지 않는다"
```

`shared/tests/fixtures/adjudication/probe_suppressed.py`:

```python
import sys
sys.path.insert(0, sys.argv[1] + "/shared/adjudication")
from adjudication import Ledger

L = Ledger(items="open")
L.suppressed("f1", "conf<=4")
r = L.report()
print("suppressed=%d" % r["counts"]["suppressed"])
print("rejected=%d" % r["counts"]["rejected"])
print("blocks=%s" % L.blocks())
print("degraded=%s" % r["degraded"])
```

`shared/tests/fixtures/adjudication/probe_held_class.py`:

```python
import sys
sys.path.insert(0, sys.argv[1] + "/shared/adjudication")
from adjudication import Ledger

L = Ledger(items="open")
L.hold("a", "판정자 부재: adversarial 판정 없음")
L.hold("b", "항목 파손: not a mapping")
L.hold("c", "항목 파손: missing file")
L.hold("d", "접두 없는 사유")
c = L.held_by_class()
print("부재=%d" % c["판정자 부재"])
print("파손=%d" % c["항목 파손"])
print("기타=%d" % c["기타"])
print("합=%d" % sum(c.values()))
```

**「합=4」가 이 테스트의 이빨이다** — 접두 셋만 세고 미지를 버리면 `held` 총계와 갈라지는데, 그 차이는 §5 배관 칸에서 조용히 사라진다.

- [ ] **Step 2: 실패를 확인한다**

```bash
bash shared/tests/test_adjudication_behavior.sh 2>&1 | tail -20
```

기대: `AttributeError: 'Ledger' object has no attribute 'suppressed'` 계열로 여덟 단언 전부 FAIL, `Fail: 8`.

- [ ] **Step 3: 최소 구현**

`shared/adjudication/adjudication.py` — `__init__` 의 리스트 선언 끝(`self._unknown` 다음)에 한 줄:

```python
        self._unknown = []           # [(what, why)]
        self._suppressed = []        # [(item, why)]
```

처분 메서드 절 끝(`uncountable` 다음, `# ── 파생 술어` 주석 앞)에:

```python
    def suppressed(self, item, why):
        """규칙 억제 — 판정자의 판단이 아니라 규칙(임계값)이 정한 배제.

        `reject` 와 합치지 않는다. 합치면 「누가 왜 뺐나」가 다시 사라진다.
        degrade 가 아니고 차단하지도 않는다: 규칙이 예상대로 작동한 것이다.
        """
        self._suppressed.append((item, why))
```

파생 술어 절(`_has_gate_coercion` 다음, `blocks` 앞)에:

```python
    _HOLD_CLASSES = ("판정자 부재", "항목 파손")

    def held_by_class(self):
        """`hold()` 의 `why` 접두별 개수. 합은 항상 `held` 총계와 같다.

        알려진 접두에 안 걸리는 사유는 «기타» 로 «센다» — 버리면 이 반환의
        합이 held 와 갈라지고, 그 차이는 소비자의 출력에서 조용히 사라진다.
        `"기타" > 0` 일 때 advisory 를 내는 것은 소비자의 책임이다 — 이 모듈은
        회계만 하고 렌더 권위가 아니다(모듈 docstring).
        """
        out = {k: 0 for k in self._HOLD_CLASSES}
        out["기타"] = 0
        for (_item, why) in self._held:
            for k in self._HOLD_CLASSES:
                if str(why).startswith(k):
                    out[k] += 1
                    break
            else:
                out["기타"] += 1
        return out
```

`report()` 의 `counts` dict 마지막 항목 뒤에 한 줄:

```python
                "sources_failed": len(self._sources_failed),
                "suppressed": len(self._suppressed),
```

- [ ] **Step 4: 통과를 확인한다**

```bash
bash shared/tests/test_adjudication_behavior.sh 2>&1 | tail -8
```

기대: `Fail: 0`.

- [ ] **Step 5: 버전 bump**

`/tmp/adjtopo/bump.py` 를 쓰고 실행한다:

```python
import json
import pathlib

for p, new in (("plugins/quality-gates/.claude-plugin/plugin.json", "5.2.0"),
               ("plugins/spec-distill/.claude-plugin/plugin.json", "0.48.0")):
    f = pathlib.Path(p)
    d = json.loads(f.read_text(encoding="utf-8"))
    d["version"] = new
    f.write_text(json.dumps(d, ensure_ascii=False, indent=2) + "\n",
                 encoding="utf-8")
    print(p, "->", new)
```

```bash
PYTHONDONTWRITEBYTECODE=1 python3 /tmp/adjtopo/bump.py
git diff --stat plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json
```

**diff 를 눈으로 본다** — `json.dumps` 의 들여쓰기·키 순서가 원본과 다르면 무관한 줄이 함께 움직인다. 움직였으면 스크립트를 버리고 손으로 한 줄만 고친다.

- [ ] **Step 6: CHANGELOG 두 개**

`plugins/quality-gates/CHANGELOG.md` 맨 위(제목 다음):

```markdown
## [5.2.0] — 2026-09-03

### Added
- `Ledger.suppressed(item, why)` — 규칙 억제를 기각과 분리된 칸으로 센다. 차단도 degrade 도 아니다.
- `Ledger.held_by_class()` — `hold()` 사유의 접두별 개수. 미지 접두는 「기타」로 세어 합이 `held` 총계와 항상 일치한다.

### Changed
- `report()["counts"]` 에 `suppressed` 추가 (여섯 → 일곱).
```

`plugins/spec-distill/CHANGELOG.md` 에 같은 내용을 `## [0.48.0] — 2026-09-03` 으로.

minor bump 인 이유: 새 surface 추가이고 기존 키를 제거하지 않는다.

- [ ] **Step 7: 커밋**

```bash
git add shared/adjudication/adjudication.py shared/tests/test_adjudication_behavior.sh shared/tests/fixtures/adjudication/ plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/spec-distill/CHANGELOG.md
git commit -m "feat(adjudication): 억제 칸과 hold 분류를 어휘에 더한다 (qg v5.2.0, sd v0.48.0)"
```

---

### Task 3: L1 — 배선 락

**요구** — ㉮ 파일의 **모든** `for` 문에서, 루프 원소가 출력에 도달 못 하고 끝나는 경로마다 **같은 분기에** 처분 호출이 있어야 한다.

**모집단이 피검자 손에 없다는 것이 이 락의 핵심 성질이다.** 앞 설계 판본 둘은 대상을 「ledger 를 인자로 받는 함수」와 「처분 메서드가 불리는 함수」로 잡았고 리뷰어 둘이 각각 독립으로 순환을 지적했다 — 전자는 파일 하나를 통째로 놓치고(4파일 전부 `Ledger` 를 로컬로 만든다), 후자는 **전혀 배선 안 된 버리기가 영원히 안 보인다**.

**Files:**
- Create: `shared/tests/test_adjudication_wiring.sh`
- Modify: `shared/adjudication/check_wiring.py` (면제 상수 + `derive_consumers()` 추가)
- Create: `shared/tests/fixtures/adjudication/wiring_bad.py` · `wiring_good.py` · `wiring_exempt.py`

**Interfaces:**
- Consumes: Task 1 의 `scan(paths)` · `comprehension_count(paths)`
- Produces: `check_wiring.py` 의 `derive_consumers(repo_root) -> tuple[list[str], list[str], list[str]]` — `(합집합, import경로, 앵커경로)` **셋**을 낸다. 합집합만 반환하면 M7 이 요구하는 「두 경로를 따로 기록」을 할 수 없다. 소비자 둘(`run_wiring_scan.py`·`run_consumed.py`)이 `union, by_import, by_anchor = …` 로 언패킹한다. ㉮ 를 **두 경로의 합집합**으로 도출. ⑴ `plugins/*/scripts/*.py` + `plugins/*/hooks/*.py` 중 `adjudication` 을 import 하는 것 ∪ ⑵ 처분 앵커의 `consumer=<path>.py` 가 지목한 것. Task 11(T5)이 훅을 배선하면 이 함수가 4 → 5 를 낸다
- Produces: `check_wiring.py` 의 `EXEMPT: dict[(file, line), str]` — 값은 C6 인용 문자열. **키가 아니라 값의 유무가 락의 이빨이다**

- [ ] **Step 1: 판정기에 면제 상수와 도출을 더한다**

`shared/adjudication/check_wiring.py` 상단, `DISCARD_NODES` 다음:

```python
# 면제는 «이 파일»에 산다 — 피검자 파일이 아니라. 각 값은 설계 §8 의 C6 조건
# 하나를 인용해야 한다: C6(1) 대응물이 원리적으로 없음 · C6(2) 측정된 이유.
# 인용 없는 항목(빈 문자열)은 호출자가 RED 로 만든다.
#
# Task 1 Step 6 이 이 목록의 초기 내용을 정한다. 착수 시점에는 비어 있다 —
# 비어 있는 것이 이 락이 오늘 RED 인 이유의 일부다.
EXEMPT = {
    # ("plugins/.../foo.py", 146): "C6(1) 제자리 변형 루프 — 버려지는 항목이 없다",
}
```

파일 끝에:

```python
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
```

**심볼릭 링크를 건너뛰는 이유** — `plugins/*/scripts/adjudication.py` 는 `shared/` 의 링크다. 세면 소비자가 자기 자신이 된다.

- [ ] **Step 2: 판정기의 단위 fixture 셋을 쓴다**

이 fixture 들이 M6 에서 「락이 죽었나」와 「판정기가 죽었나」를 가른다.

`shared/tests/fixtures/adjudication/wiring_bad.py`:

```python
def f(items, ledger):
    out = []
    for it in items:
        if not isinstance(it, dict):
            continue          # 처분 호출 없음 — 잡혀야 한다
        out.append(it)
    return out
```

`shared/tests/fixtures/adjudication/wiring_good.py`:

```python
def f(items, ledger):
    out = []
    for it in items:
        if not isinstance(it, dict):
            ledger.hold(repr(it), "항목 파손: not a mapping")
            continue          # 같은 분기에 처분 호출 — 통과해야 한다
        out.append(it)
    return out
```

`shared/tests/fixtures/adjudication/wiring_farguard.py` — **fail-open 회귀 fixture**:

```python
def f(items, ledger):
    out = []
    for it in items:
        if it.get("late"):
            ledger.absorbed(it, "elsewhere")
        if not isinstance(it, dict):
            continue          # 처분 호출은 «다른» 분기에 있다 — 잡혀야 한다
        out.append(it)
    return out
```

**`wiring_farguard.py` 가 이 판정기의 가장 중요한 단언이다** — 설계 F2 의 프로브가 정확히 여기서 fail-open 이었다(분기를 못 찾으면 scope 를 루프 본문 전체로 넓혀 무관한 처분 호출이 이 `continue` 를 guarded 로 만들었다).

- [ ] **Step 3: 락을 쓴다**

`shared/tests/test_adjudication_wiring.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py
#
# 버리는 분기가 자기 처분을 부르는지 검사한다.
#
# 대상은 «파일의 모든 for 문»이다. 「처분 호출이 있는 함수」로 좁히면 전혀
# 배선되지 않은 버리기가 영원히 안 보인다 — 모집단이 피검자 손에 들어간다.
#
# 컴프리헨션은 요구 대상이 아니다(표현식에 문장을 못 넣는다). 대신 개수를
# baseline 으로 못 박는다 — 버리기를 그 형태로 옮기는 우회가 조용하지 않게.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t adjwire-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

note "── 판정기 자체 (fixture) — 락이 죽었나와 판정기가 죽었나를 가른다"
PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_wiring_probe.py" \
  "$REPO_ROOT" > "$TMPD/probe.txt" 2>&1
PROBE="$(cat "$TMPD/probe.txt")"
assert_contains "$PROBE" "bad=1"      "무방비 continue 를 잡는다"
assert_contains "$PROBE" "good=0"     "같은 분기의 처분 호출을 통과시킨다"
assert_contains "$PROBE" "farguard=1" "다른 분기의 처분 호출로 만족되지 않는다 (fail-open 회귀)"

note "── 모집단 도출 (㉮) — 두 경로를 따로 기록한다"
PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_wiring_scan.py" \
  "$REPO_ROOT" > "$TMPD/scan.txt" 2>&1
SCAN="$(cat "$TMPD/scan.txt")"
note "$SCAN"

n_union="$(printf '%s\n' "$SCAN"  | sed -n 's/^union=//p')"
n_import="$(printf '%s\n' "$SCAN" | sed -n 's/^import=//p')"
n_anchor="$(printf '%s\n' "$SCAN" | sed -n 's/^anchor=//p')"

# 0 은 통과가 아니라 실패다 — 도출이 깨지면 이 락 전체가 vacuous 해진다.
if [ "${n_union:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉮ 도출 $n_union 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉮ 도출이 0 이다 — glob 이나 앵커 스캔이 깨졌다. 이 락의 모든 단언이 공허하다"
fi
assert_eq "$n_import" "$n_anchor" "㉮ 의 두 경로(import·앵커)가 같은 수를 낸다 — 갈리면 회귀 신호다"

note "── 배선 — 미배선 자리 0"
unwired="$(printf '%s\n' "$SCAN" | sed -n 's/^unwired=//p')"
assert_eq "$unwired" "0" "버리는 분기 전부가 같은 분기에 처분 호출을 갖는다"
printf '%s\n' "$SCAN" | sed -n 's/^  UNWIRED //p' | while IFS= read -r l; do
  note "      미배선: $l"
done

note "── 면제 — 각 항목이 C6 조건을 인용한다"
uncited="$(printf '%s\n' "$SCAN" | sed -n 's/^exempt_uncited=//p')"
exempt_n="$(printf '%s\n' "$SCAN" | sed -n 's/^exempt_total=//p')"
assert_eq "$uncited" "0" "C6 인용 없는 면제 항목 0 (인용 없는 면제는 그냥 구멍이다)"
note "      면제 목록 크기: $exempt_n  ← M8 이 이 수의 증가를 본다"

note "── 컴프리헨션 회귀 축 — 요구가 아니라 baseline"
comp="$(printf '%s\n' "$SCAN" | sed -n 's/^comprehensions=//p')"
COMP_BASELINE=28   # Task 1 F5 census. 늘면 그 커밋에 이유가 있어야 한다.
if [ "${comp:-0}" -le "$COMP_BASELINE" ] 2>/dev/null; then
  ok "컴프리헨션 내포 $comp <= baseline $COMP_BASELINE"
else
  no "컴프리헨션 내포가 $comp 로 늘었다 (baseline $COMP_BASELINE) — 버리기가 for 문 밖으로 옮겨갔을 수 있다. 늘린 커밋이 이유를 적고 baseline 을 올려라"
fi

finish
```

- [ ] **Step 4: 락이 부르는 프로브 둘을 쓴다**

`shared/tests/fixtures/adjudication/run_wiring_probe.py`:

```python
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "shared" / "adjudication"))
from check_wiring import scan  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
for name in ("bad", "good", "farguard"):
    rows = scan([str(FX / ("wiring_%s.py" % name))])
    print("%s=%d" % (name, len([r for r in rows if not r["guarded"]])))
```

`shared/tests/fixtures/adjudication/run_wiring_scan.py`:

```python
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "shared" / "adjudication"))
from check_wiring import (  # noqa: E402
    EXEMPT, comprehension_count, derive_consumers, scan)

union, by_import, by_anchor = derive_consumers(str(root))
print("union=%d" % len(union))
print("import=%d" % len(by_import))
print("anchor=%d" % len(by_anchor))
for p in union:
    print("  CONSUMER %s" % p)

abs_paths = [str(root / p) for p in union]
rows = scan(abs_paths)
unwired = []
for r in rows:
    rel = str(Path(r["file"]).relative_to(root))
    if r["guarded"]:
        continue
    if (rel, r["line"]) in EXEMPT:
        continue
    unwired.append((rel, r["line"], r["kind"], r["func"]))
print("unwired=%d" % len(unwired))
for (rel, line, kind, func) in unwired:
    print("  UNWIRED %s:%d %s in %s" % (rel, line, kind, func))

print("exempt_total=%d" % len(EXEMPT))
print("exempt_uncited=%d" % len([v for v in EXEMPT.values()
                                 if "C6" not in str(v)]))
print("comprehensions=%d" % comprehension_count(abs_paths))
```

- [ ] **Step 5: RED 를 확인한다 — 그리고 «어떤» RED 인지 확인한다**

```bash
chmod +x shared/tests/test_adjudication_wiring.sh
bash shared/tests/test_adjudication_wiring.sh 2>&1 | tail -40
```

기대:
- fixture 단언 셋(`bad=1`·`good=0`·`farguard=1`)은 **PASS** — 판정기는 작동한다
- `㉮ 도출 4개` **PASS** · 두 경로 일치 **PASS**
- `unwired=0` **FAIL** — 미배선 자리가 F5 의 ~13 근처로 나온다
- 면제 인용 **PASS**(목록이 비었으므로 vacuous 하게 통과 — 정상)
- 컴프리헨션 **PASS**

**fixture 셋이 FAIL 이면 배선이 아니라 판정기가 문제다.** 그때는 여기서 멈추고 판정기를 고친다 — 그것을 가르는 것이 이 fixture 의 존재 이유다.

- [ ] **Step 6: 커밋**

```bash
git add shared/tests/test_adjudication_wiring.sh shared/tests/fixtures/adjudication/ shared/adjudication/check_wiring.py
git commit -m "test(adjudication): L1 배선 락 — 버리는 분기가 처분을 부르는지 (RED)"
```

`shared/` 만 건드렸으므로 bump 없음.

---

### Task 4: L2 — 소비 락

**요구** — `report()` 의 카운트가 **전부**(`accepted` 포함) 그리고 `unknown_counts` 가 프로덕션 출력 경로에 실려야 한다.

**오늘 RED 인 근거** — 프로덕션이 읽는 것은 `held` 하나다(`synthesize_findings.py:562` · `synthesize_artifact_findings.py:211` · `merge_review.py:559` 근방). Task 2 가 `suppressed` 를 더했으므로 이제 카운트는 **일곱**이고 미소비는 여섯이다.

**Files:**
- Create: `shared/adjudication/check_consumed.py`
- Create: `shared/tests/test_adjudication_consumed.sh`
- Create: `shared/tests/fixtures/adjudication/consumed_partial.py` · `consumed_full.py`

**Interfaces:**
- Consumes: Task 3 의 `derive_consumers(repo_root)`
- Produces: `check_consumed.py` 의 `required_keys(repo_root) -> list[str]` — **`Ledger` 자신에게서 도출**한다. 키 목록을 락에 하드코딩하지 않는다: 하드코딩하면 `Ledger` 에 카운트를 더해도 락이 조용하다
- Produces: `check_consumed.py` 의 `missing(path, keys) -> list[str]`

- [ ] **Step 1: 판정기를 쓴다**

`shared/adjudication/check_consumed.py`:

```python
# -*- coding: utf-8 -*-
"""L2 판정기 — 원장의 카운트가 소비자의 출력 경로에 실리는지.

요구 키를 «Ledger 자신에게서» 도출한다. 락에 열거하면 어휘가 늘어도 락이
조용하고, 그 침묵이 정확히 이 락이 막으려는 것이다.

문자열 «등장»이 아니라 AST 의 첨자/딕셔너리 키로만 센다. 주석 안의 키 이름이
소비로 읽히면 이 락은 검사가 아니라 장식이 된다.
"""
import ast
import io


def required_keys(repo_root):
    """`report()` 가 내는 카운트 키 전부 + `unknown_counts`."""
    import sys
    sys.path.insert(0, repo_root + "/shared/adjudication")
    from adjudication import Ledger
    rep = Ledger(items="open").report()
    return sorted(rep["counts"].keys()) + ["unknown_counts"]


def _string_keys(tree):
    """첨자(`x["k"]`)와 딕셔너리 리터럴 키로 «쓰인» 문자열만."""
    found = set()
    for n in ast.walk(tree):
        if isinstance(n, ast.Subscript):
            s = n.slice
            if isinstance(s, ast.Constant) and isinstance(s.value, str):
                found.add(s.value)
        elif isinstance(n, ast.Dict):
            for k in n.keys:
                if isinstance(k, ast.Constant) and isinstance(k.value, str):
                    found.add(k.value)
    return found


def missing(path, keys):
    tree = ast.parse(io.open(path, encoding="utf-8").read())
    found = _string_keys(tree)
    return [k for k in keys if k not in found]
```

- [ ] **Step 2: fixture 둘을 쓴다**

`shared/tests/fixtures/adjudication/consumed_partial.py`:

```python
def emit(report):
    # `held` 만 읽는다 — 오늘의 프로덕션과 같은 모양
    return "held=%d" % report["counts"]["held"]
```

`shared/tests/fixtures/adjudication/consumed_full.py`:

```python
def emit(report):
    c = report["counts"]
    return "a=%d r=%d h=%d ab=%d co=%d sf=%d su=%d u=%s" % (
        c["accepted"], c["rejected"], c["held"], c["absorbed"],
        c["coerced"], c["sources_failed"], c["suppressed"],
        report["unknown_counts"])
```

- [ ] **Step 3: 락을 쓴다**

`shared/tests/test_adjudication_consumed.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/*/scripts/*.py plugins/*/hooks/*.py
#
# 원장이 «낸» 카운트를 소비자가 «읽는지» 검사한다.
#
# 요구 키는 Ledger 자신에게서 도출한다 — 여기 열거하면 어휘가 늘어도 락이
# 조용하고, 그 침묵이 이 락이 막으려는 바로 그것이다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t adjcons-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_consumed.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_partial_missing=7" "held 만 읽는 소비자에서 나머지 일곱을 찾아낸다"
assert_contains "$OUT" "fx_full_missing=0"    "전부 읽는 소비자는 통과한다"

note "── 요구 키가 Ledger 에서 도출된다"
nkeys="$(printf '%s\n' "$OUT" | sed -n 's/^keys=//p')"
if [ "${nkeys:-0}" -ge 8 ] 2>/dev/null; then
  ok "요구 키 $nkeys 개 (카운트 7 + unknown_counts)"
else
  no "요구 키가 $nkeys 개다 — Ledger 도출이 깨졌으면 이 락 전체가 vacuous 하다"
fi

note "── 프로덕션 소비자"
nfiles="$(printf '%s\n' "$OUT" | sed -n 's/^consumers=//p')"
if [ "${nfiles:-0}" -gt 0 ] 2>/dev/null; then
  ok "소비자 $nfiles 개"
else
  no "소비자 도출이 0 이다 — 락이 vacuous 하다"
fi
unconsumed="$(printf '%s\n' "$OUT" | sed -n 's/^unconsumed_total=//p')"
assert_eq "$unconsumed" "0" "모든 소비자가 모든 카운트를 읽는다"

finish
```

`shared/tests/fixtures/adjudication/run_consumed.py`:

```python
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "shared" / "adjudication"))
from check_consumed import missing, required_keys  # noqa: E402
from check_wiring import derive_consumers  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
keys = required_keys(str(root))
print("keys=%d" % len(keys))
print("  KEYS %s" % ", ".join(keys))

print("fx_partial_missing=%d" % len(missing(str(FX / "consumed_partial.py"), keys)))
print("fx_full_missing=%d" % len(missing(str(FX / "consumed_full.py"), keys)))

union, _, _ = derive_consumers(str(root))
print("consumers=%d" % len(union))
total = 0
for rel in union:
    miss = missing(str(root / rel), keys)
    total += len(miss)
    if miss:
        print("  UNCONSUMED %s: %s" % (rel, ", ".join(miss)))
print("unconsumed_total=%d" % total)
```

- [ ] **Step 4: RED 를 확인한다**

```bash
chmod +x shared/tests/test_adjudication_consumed.sh
bash shared/tests/test_adjudication_consumed.sh 2>&1 | tail -30
```

기대: fixture 둘 **PASS**, 키 8개 **PASS**, 소비자 4개 **PASS**, `unconsumed_total=0` **FAIL** (네 파일 합쳐 20+ 개 미소비).

- [ ] **Step 5: 커밋**

```bash
git add shared/adjudication/check_consumed.py shared/tests/test_adjudication_consumed.sh shared/tests/fixtures/adjudication/
git commit -m "test(adjudication): L2 소비 락 — 낸 카운트를 읽는지 (RED)"
```

---

### Task 5: L4 — 역할 선언 락

**요구** — ㉯(외부 모델 판정자 = codex 러너 6개)가 처분 선언 셋을 갖는다: `consumer=` · `fail-open|fail-closed` · `disclosure=`.

**이 락의 한계를 락 자신이 적는다** — `disclosure=` 리터럴이 파일에 있다는 것은 그 채널이 **실제로 읽힌다**는 증거가 아니다. 정적 검사의 밖이고, 그것이 U3 이 「L4 의 런타임 인터페이스는 범위 밖」으로 닫힌 이유다. 형제 락 `test_dispatch_disposition.sh:11-15` 가 같은 한계를 자기 축 C 에 대해 적는다 — 같은 어휘를 쓴다.

**Files:**
- Create: `shared/tests/test_runner_disposition.sh`

**Interfaces:**
- Consumes: `plugins/quality-gates/tests/lib/extract_codex_invocations.py` (**무수정**) + `/scripts/` 후처리
- Produces: 없음 (락)

- [ ] **Step 1: 락을 쓴다**

`shared/tests/test_runner_disposition.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/*/scripts/*codex*.sh
#
# 외부 모델 판정자(codex 러너)가 자기 처분을 밝히는지 검사한다.
#
# 모집단은 신설하지 않는다 — 리포에 도출기가 이미 있고 standing assertion 에
# 묶여 있다. 그 도구를 «고치지 않고» 출력에 /scripts/ 후처리만 건다.
#
# 이 축은 약하다. `disclosure=` 리터럴이 파일에 있다는 것이 그 채널이 실제로
# 읽힌다는 증거는 아니다 — 값이 저자 손에 있는 한 이 축에서 그 이상은 나오지
# 않는다. 없앴다고 주장하지 않고 어디로 옮겼는지 밝힌다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

EXTRACT="$REPO_ROOT/plugins/quality-gates/tests/lib/extract_codex_invocations.py"
if [ ! -f "$EXTRACT" ]; then
  no "도출기 부재: $EXTRACT — 모집단을 계산할 수 없다"
  finish; exit
fi

TMPD="$(mktemp -d -t rundisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$EXTRACT" "$REPO_ROOT/plugins" > "$TMPD/all.txt" 2>&1
grep '/scripts/' "$TMPD/all.txt" > "$TMPD/runners.txt" || true

n_all="$(wc -l < "$TMPD/all.txt" | tr -d ' ')"
n_run="$(wc -l < "$TMPD/runners.txt" | tr -d ' ')"
note "도출기 출력 $n_all → /scripts/ 후처리 후 $n_run"

# 0 은 통과가 아니라 실패다.
if [ "${n_run:-0}" -gt 0 ] 2>/dev/null; then
  ok "㉯ 도출 $n_run 개 (0 이 아니다 — 락이 vacuous 하지 않다)"
else
  no "㉯ 도출이 0 이다 — 도출기 출력이나 후처리가 깨졌다. 이 락의 모든 단언이 공허하다"
fi

# 후처리가 실제로 무언가를 걸러냈는지 — 안 걸러내면 후처리가 죽은 것이다.
if [ "${n_all:-0}" -gt "${n_run:-0}" ] 2>/dev/null; then
  ok "/scripts/ 후처리가 $((n_all - n_run)) 개를 걸러냈다 (spike/ 등)"
else
  no "후처리가 아무것도 안 걸러냈다 — 도출기 출력이 바뀌었거나 필터가 죽었다"
fi

while IFS= read -r rel; do
  [ -n "$rel" ] || continue
  f="$REPO_ROOT/$rel"
  base="$(basename "$rel")"
  if [ ! -f "$f" ]; then no "$base: 도출된 경로가 실재하지 않는다"; continue; fi
  body="$(cat "$f")"
  assert_grep "$body" 'consumer=' \
    "$base: consumer= 를 밝힌다 (누가 이 판정을 읽는가)"
  assert_grep "$body" 'fail-(open|closed)' \
    "$base: fail-open/fail-closed 를 밝힌다 (죽었을 때 어느 쪽으로 기우는가)"
  assert_grep "$body" 'disclosure=' \
    "$base: disclosure= 를 밝힌다 (어느 채널로 드러나는가)"
done < "$TMPD/runners.txt"

finish
```

- [ ] **Step 2: RED 를 확인한다**

```bash
chmod +x shared/tests/test_runner_disposition.sh
bash shared/tests/test_runner_disposition.sh 2>&1 | tail -30
```

기대: 도출 6개 **PASS**, 후처리 **PASS**, 각 러너의 세 단언 **전부 FAIL** — 6 × 3 = 18 FAIL. 설계 §4 의 「RED — 6/6 없음」과 일치한다.

**도출이 6이 아니면 멈춘다** — Task 1 Step 3 이 7 → 6 을 확인했으므로 다르면 그 사이에 무언가 바뀐 것이다.

- [ ] **Step 3: 커밋**

```bash
git add shared/tests/test_runner_disposition.sh
git commit -m "test(adjudication): L4 역할 선언 락 — codex 러너가 처분을 밝히는지 (RED)"
```

---

### Task 6: T4-2 — 참조 이름 락 (stale 이름이 «살아 있을 때» 들어간다)

**요구** — 문서가 백틱으로 감싸 부르는 `<plugin>:<name>` 은 전부 실재하는 정의(agent · skill · command)를 가져야 한다.

**순서가 이 Task 의 전부다.** 이 락은 stale 이름(`quality-pipeline/SKILL.md:511` 의 `quality-gates:synthesizer` — `37ea0d7` 이 정의를 지우고 스크립트로 옮겼다)이 **아직 살아 있는 지금** 들어가야 RED 가 나고, 그 RED 가 이빨의 증거다. Task 12 가 그 이름을 지우면 GREEN 이 된다(M4).

**U4 의 결정 — 기존 필터를 빼지 않고 두 번째 코퍼스를 더한다.** 설계 §6 이 넘긴 실측 제약은 이것이다: `shared/tests/test_dispatch_disposition.sh:80-84` 가 *"표기 필터를 이름 매칭보다 먼저 걸지 않으면 산문 속 영어 단어가 dispatch 로 잡힌다"* 를 기록했고(맨 `adversarial` 이 `critiquing-artifacts/SKILL.md` 의 5줄에 등장하며 전부 산문), T4-2 는 산문을 봐야 하므로 그 필터와 정면충돌한다. **직교로 푼다** — 백틱 + 콜론이라는 두 조건을 동시에 요구하면 맨 영어 단어는 애초에 걸리지 않는다. 기존 락의 `NOTATION` 은 손대지 않는다.

**Files:**
- Create: `shared/adjudication/check_names.py`
- Create: `shared/tests/test_dispatch_name_defined.sh`
- Create: `shared/tests/fixtures/adjudication/names_stale.md` · `names_ok.md` · `names_prose.md`

**Interfaces:**
- Produces: `check_names.py` 의 `defined(repo_root) -> set[str]` — `<plugin>:<name>` 꼴 전부. agent 는 frontmatter `name:`, skill 은 `skills/<dir>/SKILL.md` 의 디렉토리명, command 는 `commands/<file>.md` 의 파일명
- Produces: `check_names.py` 의 `references(repo_root) -> list[(path, line, token)]`
- Produces: `check_names.py` 의 `EXEMPT_FILES` — CHANGELOG 등 이력 문서

- [ ] **Step 1: 판정기를 쓴다**

`shared/adjudication/check_names.py`:

```python
# -*- coding: utf-8 -*-
"""T4-2 판정기 — 백틱으로 불린 `<plugin>:<name>` 이 실재 정의를 갖는지.

기존 dispatch 락의 표기 필터(subagent_type:|agentType:|Agent\\(|^\\s*agent:)를
«빼지 않는다». 그 필터는 산문 속 맨 영어 단어가 dispatch 로 잡히는 것을 막고
있고 그 필요는 실측으로 기록돼 있다(test_dispatch_disposition.sh:80-84).

여기서는 «백틱 + 콜론» 두 조건을 동시에 요구한다. 맨 단어는 둘 다 없으므로
그 필터와 겹치지 않는다 — 우회가 아니라 직교다.
"""
import re
from pathlib import Path

# 이력 문서는 과거 이름을 legitimately 담는다. 지운 이름을 CHANGELOG 가
# 말하지 못하게 되면 그것이야말로 이력의 소실이다.
EXEMPT_FILES = ("CHANGELOG.md",)

# 백틱 안, `<plugin>:<name>` 꼴. 양쪽 다 kebab-case 만.
_REF_RE = re.compile(r'`([a-z][a-z0-9-]*):([a-z][a-z0-9-]*)`')


def defined(repo_root):
    """실재하는 `<plugin>:<name>` 전부 — agent · skill · command."""
    repo = Path(repo_root)
    out = set()
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
    for pat in ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md",
                "plugins/*/agents/*.md", "plugins/*/README.md"):
        for f in sorted(repo.glob(pat)):
            if not f.is_file() or f.name in EXEMPT_FILES:
                continue
            rel = str(f.relative_to(repo))
            for i, line in enumerate(f.read_text(encoding="utf-8").splitlines(), 1):
                for m in _REF_RE.finditer(line):
                    if m.group(1) in plugins:
                        out.append((rel, i, "%s:%s" % (m.group(1), m.group(2))))
    return out


def dangling(repo_root):
    known = defined(repo_root)
    return [r for r in references(repo_root) if r[2] not in known]
```

- [ ] **Step 2: fixture 셋을 쓴다**

`shared/tests/fixtures/adjudication/names_stale.md` — 잡혀야 한다:

```markdown
Dispatch `quality-gates:no-such-agent` to consolidate findings.
```

`shared/tests/fixtures/adjudication/names_ok.md` — 통과해야 한다:

```markdown
Dispatch `quality-gates:adversarial` for Phase 1.5.
```

`shared/tests/fixtures/adjudication/names_prose.md` — **걸리면 안 된다**(기존 락의 실측 제약을 이 락이 재현하지 않는지):

```markdown
The adversarial reviewer is adversarial by design; adversarial output
feeds the adversarial gate. Note the ratio 3:1 and the key value: here.
```

**`names_prose.md` 가 이 판정기의 회귀 fixture 다** — 맨 `adversarial` 다섯 번과 백틱 없는 콜론 둘. 하나라도 걸리면 판정기가 기존 락이 이미 해결한 문제를 되살린 것이다.

- [ ] **Step 3: 락을 쓴다**

`shared/tests/test_dispatch_name_defined.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/*/skills/**/*.md plugins/*/commands/**/*.md plugins/*/agents/*.md
#
# 백틱으로 불린 `<plugin>:<name>` 이 실재 정의를 갖는지 검사한다.
#
# 기존 dispatch 락과 «방향이 반대»다: 그쪽은 정의에서 출발해 호출을 찾고,
# 이쪽은 호출에서 출발해 정의를 찾는다. 지워진 정의를 가리키는 이름은 그쪽
# 방향에서 구조적으로 안 보인다.
#
# 백틱과 콜론을 «동시에» 요구한다. 산문 속 맨 영어 단어는 둘 다 없으므로
# 기존 락의 표기 필터와 겹치지 않는다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t dispname-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_names.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_stale=1"  "지워진 이름을 잡는다"
assert_contains "$OUT" "fx_ok=0"     "실재하는 이름을 통과시킨다"
assert_contains "$OUT" "fx_prose=0"  "산문 속 맨 단어와 백틱 없는 콜론은 잡지 않는다 (기존 락의 실측 제약)"

note "── 정의 집합"
ndef="$(printf '%s\n' "$OUT" | sed -n 's/^defined=//p')"
if [ "${ndef:-0}" -gt 0 ] 2>/dev/null; then
  ok "정의 $ndef 개 (agent + skill + command)"
else
  no "정의 도출이 0 이다 — 락이 vacuous 하다"
fi

note "── 참조 코퍼스"
nref="$(printf '%s\n' "$OUT" | sed -n 's/^refs=//p')"
if [ "${nref:-0}" -gt 0 ] 2>/dev/null; then
  ok "참조 $nref 건"
else
  no "참조 도출이 0 이다 — 코퍼스 glob 이 깨졌으면 이 락의 단언이 전부 공허하다"
fi

note "── 존재하지 않는 정의를 가리키는 참조"
nd="$(printf '%s\n' "$OUT" | sed -n 's/^dangling=//p')"
assert_eq "$nd" "0" "모든 참조가 실재 정의를 가리킨다"
printf '%s\n' "$OUT" | sed -n 's/^  DANGLING //p' | while IFS= read -r l; do
  note "      매달림: $l"
done

finish
```

`shared/tests/fixtures/adjudication/run_names.py`:

```python
import sys
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "shared" / "adjudication"))
import check_names  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
known = check_names.defined(str(root))
print("defined=%d" % len(known))

# fixture 는 코퍼스 밖이므로 참조 추출만 직접 돌린다.
plugins = {p.name for p in (root / "plugins").glob("*") if p.is_dir()}
for name in ("stale", "ok", "prose"):
    text = (FX / ("names_%s.md" % name)).read_text(encoding="utf-8")
    hits = [m for m in check_names._REF_RE.finditer(text)
            if m.group(1) in plugins]
    bad = [m.group(0) for m in hits
           if "%s:%s" % (m.group(1), m.group(2)) not in known]
    print("fx_%s=%d" % (name, len(bad)))

refs = check_names.references(str(root))
print("refs=%d" % len(refs))
dang = check_names.dangling(str(root))
print("dangling=%d" % len(dang))
for (path, line, tok) in dang:
    print("  DANGLING %s:%d %s" % (path, line, tok))
```

- [ ] **Step 4: RED 를 확인한다 — «지금» stale 이름이 살아 있는 채로**

```bash
chmod +x shared/tests/test_dispatch_name_defined.sh
bash shared/tests/test_dispatch_name_defined.sh 2>&1 | tail -30
grep -n 'quality-gates:synthesizer' plugins/quality-gates/skills/quality-pipeline/SKILL.md
```

기대: fixture 셋 **PASS**, `dangling=0` **FAIL** 이고 매달림 목록에 `plugins/quality-gates/skills/quality-pipeline/SKILL.md:511 quality-gates:synthesizer` 가 나온다.

**매달림이 0 이면 이 Task 를 멈춘다** — 락이 이빨 없이 도착했다는 뜻이다. 그 경우 `grep` 결과와 대조해 판정기의 코퍼스나 정규식을 고친다.

- [ ] **Step 5: 커밋**

```bash
git add shared/adjudication/check_names.py shared/tests/test_dispatch_name_defined.sh shared/tests/fixtures/adjudication/
git commit -m "test(adjudication): T4-2 참조 이름 락 — 지워진 정의를 가리키는 이름 (RED)"
```

---

### Task 7: L3 — 입력 선언 락 (가장 큰 단일 작업)

**요구 둘.** (a) agent 가 **선언한** 입력 슬롯과 dispatch 자리가 **전달하는** 것이 일치한다. (b) 선언된 슬롯에 **금지 종류**가 없다.

**(a) 만으로는 부족한 이유** — `<history>${ISSUE_HISTORY}</history>` 를 선언하면 누출이 그대로인 채 GREEN 이 된다. 「적으면 통과」다. (b)가 *무엇을 선언해도 되는가*의 어휘를 준다.

**U2 의 결정 — 문법.** agent frontmatter 에:

```yaml
input_slots:
  - tag: task
    var: TASK_TEXT
    kind: task
  - tag: history
    var: ISSUE_HISTORY
    kind: same_origin_history
    optional: true
```

`kind:` 어휘 — 허용 `task` · `artifact` · `same_origin_history` · `repo_context`, 금지 `prior_verdict` · `score` · `orchestrator_framing`(설계 §4.2, brief C8 의 세 범주).

**판정기는 새로 만든다.** 앞 설계 판본이 `plugins/plugin-audit/scripts/check-no-verdict-injection.py` 를 승격해 치환한다고 적었으나 그것은 **다른 플러그인**이고(설치본에서 런타임 도달 불가) 특정 사건에서 귀납한 **한국어 문구 블랙리스트**(`BANNED`:47-63)이며 `score`·`orchestrator_framing` 에 대응하는 패턴이 없고, 헤더 `:16-20` 이 *"Narrowing the scope is how the false positives go away"* 로 **좁은 스코프가 하중**임을 명시한다. **가져오는 것은 어휘가 아니라 배치 하나** — 「주입 표면을 열거하고 그 표면만 스캔한다」.

**(b)의 이빨과 그 한계.** 선언값 판정만 하면 저자가 `kind` 를 거짓으로 적어 빠져나간다. 보조 축으로 **변수명 휴리스틱**을 둔다 — 변수명에 `VERDICT`·`SCORE`·`RANK`·`SEVERITY` 가 들어가면 그 슬롯의 `kind:` 는 금지 셋 중 하나여야 하고, 그러면 면제 등재가 강제된다. **완전한 ∀-지배관계가 아니다** — 저자가 이름도 kind 도 함께 속이면 통과한다. 이것을 락 주석에 적는다.

**Files:**
- Create: `shared/adjudication/check_slots.py`
- Create: `shared/tests/test_agent_input_slots.sh`
- Create: `shared/tests/fixtures/adjudication/slots_*.md` (5개)

**Interfaces:**
- Consumes: 없음 (자체 도출)
- Produces: `check_slots.py` 의 `agents(repo_root) -> dict[str, dict]` — 키는 `<plugin>:<name>`, 값은 `{"path": str, "slots": list[dict] | None}`. `None` 은 **선언 자체가 없음**(오늘 20 중 18)
- Produces: `check_slots.py` 의 `dispatch_pairs(repo_root) -> dict[str, list[(tag, var, path, line)]]`
- Produces: `check_slots.py` 의 `ALLOWED_KINDS` · `FORBIDDEN_KINDS` · `EXEMPT_SLOTS`

- [ ] **Step 1: 판정기를 쓴다**

`shared/adjudication/check_slots.py`:

```python
# -*- coding: utf-8 -*-
"""L3 판정기 — agent 가 «선언한» 입력과 dispatch 가 «전달하는» 것의 일치,
그리고 선언된 종류가 금지 어휘가 아닌지.

(a) 만으로는 「적으면 통과」다. (b) 가 무엇을 선언해도 되는가의 어휘를 준다.

(b) 의 한계 — 선언값 판정이므로 저자가 kind 를 거짓으로 적으면 빠져나간다.
변수명 휴리스틱이 보조 축이지만 이름과 kind 를 함께 속이면 통과한다. 이 락은
그 구멍을 없앴다고 주장하지 않고 어디에 있는지 밝힌다.
"""
import re
from pathlib import Path

import yaml

ALLOWED_KINDS = ("task", "artifact", "same_origin_history", "repo_context")
FORBIDDEN_KINDS = ("prior_verdict", "score", "orchestrator_framing")

# 앞 판정을 반박하는 것이 과업인 agent 는 prior_verdict 를 «받아야» 한다.
# 각 값은 C6 조건을 인용한다 — 인용 없는 항목은 호출자가 RED 로 만든다.
EXEMPT_SLOTS = {
    # ("quality-gates:adversarial", "verdicts"):
    #     "C6(1) 앞 판정을 반박하는 것이 이 agent 의 과업이다 — 대응물이 없다",
}

# 변수명이 판정·점수를 시사하면 kind 가 금지 셋 중 하나여야 한다.
# 그러면 면제 등재가 강제되고, 등재는 C6 인용을 요구한다.
_SUSPECT_VAR = re.compile(r'VERDICT|SCORE|RANK|SEVERITY|CONFIDENCE', re.I)

_FM_RE = re.compile(r'\A---\n(.*?)\n---\n', re.S)
_PAIR_RE = re.compile(
    r'<([a-zA-Z_][a-zA-Z0-9_]*)>\s*\$\{([A-Za-z_][A-Za-z0-9_]*)\}')
_SUBAGENT_RE = re.compile(r'subagent_type:\s*"([a-z0-9-]+:[a-z0-9-]+)"')


def agents(repo_root):
    """정의 집합(∀) — frontmatter 의 `name:` 에서. 선언 부재는 None 으로 «남긴다»."""
    repo = Path(repo_root)
    out = {}
    for f in sorted(repo.glob("plugins/*/agents/*.md")):
        text = f.read_text(encoding="utf-8")
        m = _FM_RE.match(text)
        if not m:
            continue
        try:
            fm = yaml.safe_load(m.group(1)) or {}
        except yaml.YAMLError:
            fm = {}
        name = str(fm.get("name", "")).split(":")[-1]
        if not name:
            continue
        plugin = f.parent.parent.name
        slots = fm.get("input_slots")
        out["%s:%s" % (plugin, name)] = {
            "path": str(f.relative_to(repo)),
            "slots": slots if isinstance(slots, list) else None,
        }
    return out


def dispatch_pairs(repo_root):
    """dispatch 자리가 실제로 전달하는 (태그, 변수) 쌍.

    코퍼스는 skill·command 의 md 전부다. 특정 SKILL 하나로 좁히지 않는다 —
    좁히면 다른 파일의 dispatch 가 영원히 안 보인다.
    """
    repo = Path(repo_root)
    out = {}
    for pat in ("plugins/*/skills/**/*.md", "plugins/*/commands/**/*.md"):
        for f in sorted(repo.glob(pat)):
            if not f.is_file():
                continue
            rel = str(f.relative_to(repo))
            lines = f.read_text(encoding="utf-8").splitlines()
            # 펜스 단위로 자른다 — 펜스마다 독립 dispatch 다. 합치면 죽은
            # 펜스가 살아 있는 펜스의 결손을 가린다.
            buf, start, inside = [], 0, False
            for i, line in enumerate(lines, 1):
                if re.match(r'^```', line):
                    if inside:
                        _harvest("\n".join(buf), rel, start, out)
                        buf, inside = [], False
                    else:
                        inside, start = True, i
                    continue
                if inside:
                    buf.append(line)
    return out


def _harvest(block, rel, line, out):
    m = _SUBAGENT_RE.search(block)
    if not m:
        return
    key = m.group(1)
    out.setdefault(key, [])
    for p in _PAIR_RE.finditer(block):
        out[key].append((p.group(1), p.group(2), rel, line))


def check(repo_root):
    """(a) 일치 · (b) 금지 종류. 위반 목록을 낸다."""
    defs = agents(repo_root)
    pairs = dispatch_pairs(repo_root)
    problems = []

    for key, info in sorted(defs.items()):
        delivered = pairs.get(key, [])
        if info["slots"] is None:
            problems.append(("no_declaration", key, info["path"], ""))
            continue
        declared = {}
        for s in info["slots"]:
            if not isinstance(s, dict) or "tag" not in s:
                problems.append(("bad_slot", key, info["path"], repr(s)))
                continue
            declared[str(s["tag"])] = s

        # (a) 선언 ↔ 전달
        for (tag, var, path, ln) in delivered:
            if tag not in declared:
                problems.append(("undeclared", key, "%s:%d" % (path, ln),
                                 "<%s>${%s}" % (tag, var)))
            elif str(declared[tag].get("var", var)) != var:
                problems.append(("var_mismatch", key, "%s:%d" % (path, ln),
                                 "<%s> 선언=%s 전달=%s"
                                 % (tag, declared[tag].get("var"), var)))
        got = {t for (t, _v, _p, _l) in delivered}
        for tag, s in declared.items():
            if tag not in got and not s.get("optional"):
                problems.append(("undelivered", key, info["path"],
                                 "<%s> 를 선언했으나 전달하는 dispatch 가 없다" % tag))

        # (b) 금지 종류
        for tag, s in declared.items():
            kind = str(s.get("kind", ""))
            var = str(s.get("var", ""))
            if not kind:
                problems.append(("no_kind", key, info["path"], tag))
            elif kind in FORBIDDEN_KINDS:
                if (key, tag) not in EXEMPT_SLOTS:
                    problems.append(("forbidden_kind", key, info["path"],
                                     "<%s> kind=%s" % (tag, kind)))
            elif kind not in ALLOWED_KINDS:
                problems.append(("unknown_kind", key, info["path"],
                                 "<%s> kind=%s" % (tag, kind)))
            if _SUSPECT_VAR.search(var) and kind not in FORBIDDEN_KINDS:
                problems.append(("suspect_var", key, info["path"],
                                 "<%s> var=%s 인데 kind=%s — 판정·점수를 시사하는 "
                                 "이름은 금지 종류로 선언하고 면제에 등재하라"
                                 % (tag, var, kind)))
    return problems


def uncited_exemptions():
    return [k for k, v in EXEMPT_SLOTS.items() if "C6" not in str(v)]
```

- [ ] **Step 2: fixture 다섯을 쓴다**

`shared/tests/fixtures/adjudication/` 아래, 각각 agent 정의 한 벌 + dispatch 한 벌:

| fixture | 무엇을 재나 | 기대 |
|---|---|---|
| `slots_match.md` | 선언 ↔ 전달 일치 | 위반 0 |
| `slots_undeclared.md` | dispatch 가 선언에 없는 태그를 전달 | `undeclared` 1 |
| `slots_undelivered.md` | 필수 슬롯을 선언했으나 전달 없음 | `undelivered` 1 |
| `slots_forbidden.md` | `kind: prior_verdict` 를 면제 없이 선언 | `forbidden_kind` 1 |
| `slots_suspectvar.md` | `var: PRIOR_VERDICTS` 인데 `kind: task` | `suspect_var` 1 |

**`slots_suspectvar.md` 가 (b)의 이빨 fixture 다** — 그것이 없으면 (b)는 저자의 정직성에만 기댄다.

**fixture 는 «디렉토리»다.** `check()` 가 repo_root 를 받으므로 각 fixture 가 최소 트리를 갖는다. `slots_match/` 의 전체 내용:

`shared/tests/fixtures/adjudication/slots_match/plugins/fx/agents/a.md`:

```markdown
---
name: a
description: fixture agent
tools: []
model: inherit
input_slots:
  - tag: task
    var: TASK_TEXT
    kind: task
---

fixture body.
```

`shared/tests/fixtures/adjudication/slots_match/plugins/fx/skills/s/SKILL.md`:

````markdown
# fixture skill

```javascript
Agent({
  subagent_type: "fx:a",
  prompt: "<task>${TASK_TEXT}</task>"
})
```
````

나머지 넷은 `slots_match/` 를 복사해 **한 곳씩만** 바꾼다:

| fixture | 바꾸는 곳 | 어떻게 |
|---|---|---|
| `slots_undeclared/` | SKILL.md 의 prompt | `"<task>${TASK_TEXT}</task><extra>${EXTRA}</extra>"` |
| `slots_undelivered/` | agent 의 `input_slots` | 두 번째 슬롯 `- {tag: history, var: HIST, kind: same_origin_history}` 추가 (SKILL 은 그대로) |
| `slots_forbidden/` | agent 의 `kind` | `kind: task` → `kind: prior_verdict` |
| `slots_suspectvar/` | agent 와 SKILL **양쪽**의 변수명 | `TASK_TEXT` → `PRIOR_VERDICT_TEXT` (`kind: task` 는 **유지**) |

**`slots_suspectvar/` 만 두 파일을 함께 고치는 이유** — 한쪽만 고치면 `var_mismatch` 가 먼저 터져서 `suspect_var` 가 나오는지 확인할 수 없다. 한 fixture 는 한 가지만 재야 한다.

- [ ] **Step 3: 락을 쓴다**

`shared/tests/test_agent_input_slots.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/*/agents/*.md plugins/*/skills/**/*.md
#
# agent 가 «선언한» 입력과 dispatch 가 «전달하는» 것이 맞는지, 그리고 선언된
# 종류가 금지 어휘가 아닌지 검사한다.
#
# 모집단은 agent 정의 집합(∀)이다. dispatch 표기 열거에서 출발하면 표기를
# 하나 놓칠 때마다 그만큼 조용해진다.
#
# (b) 의 구멍을 밝힌다: 선언값 판정이라 저자가 kind 를 거짓으로 적으면
# 빠져나간다. 변수명 휴리스틱이 보조 축이지만 이름과 kind 를 «함께» 속이면
# 통과한다. 이 락은 그 구멍을 없앴다고 주장하지 않는다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/assert.sh"
REPO_ROOT="$(cd "$HERE/../.." && pwd)"

TMPD="$(mktemp -d -t slots-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

PYTHONDONTWRITEBYTECODE=1 python3 "$HERE/fixtures/adjudication/run_slots.py" \
  "$REPO_ROOT" > "$TMPD/out.txt" 2>&1
OUT="$(cat "$TMPD/out.txt")"
note "$OUT"

note "── 판정기 자체 (fixture)"
assert_contains "$OUT" "fx_match=0"           "일치하는 선언·전달을 통과시킨다"
assert_contains "$OUT" "fx_undeclared=1"      "선언 없는 태그의 전달을 잡는다"
assert_contains "$OUT" "fx_undelivered=1"     "필수 선언의 미전달을 잡는다"
assert_contains "$OUT" "fx_forbidden=1"       "금지 종류를 잡는다"
assert_contains "$OUT" "fx_suspectvar=1"      "이름은 판정인데 kind 가 무해한 슬롯을 잡는다 (b 의 보조 축)"

note "── 모집단 (㉰)"
nag="$(printf '%s\n' "$OUT" | sed -n 's/^agents=//p')"
if [ "${nag:-0}" -gt 0 ] 2>/dev/null; then
  ok "agent 정의 $nag 개"
else
  no "agent 도출이 0 이다 — 락이 vacuous 하다"
fi

note "── 선언 부재"
nodecl="$(printf '%s\n' "$OUT" | sed -n 's/^no_declaration=//p')"
assert_eq "$nodecl" "0" "모든 agent 가 input_slots 를 선언한다"

note "── 일치와 종류"
nprob="$(printf '%s\n' "$OUT" | sed -n 's/^problems_other=//p')"
assert_eq "$nprob" "0" "선언 ↔ 전달 일치, 금지 종류 없음"
printf '%s\n' "$OUT" | sed -n 's/^  PROBLEM //p' | while IFS= read -r l; do
  note "      $l"
done

note "── 면제"
unc="$(printf '%s\n' "$OUT" | sed -n 's/^exempt_uncited=//p')"
nex="$(printf '%s\n' "$OUT" | sed -n 's/^exempt_total=//p')"
assert_eq "$unc" "0" "C6 인용 없는 면제 항목 0"
note "      면제 목록 크기: $nex  ← M8 이 이 수의 증가를 본다"

finish
```

`shared/tests/fixtures/adjudication/run_slots.py`:

```python
import sys
from collections import Counter
from pathlib import Path

root = Path(sys.argv[1])
sys.path.insert(0, str(root / "shared" / "adjudication"))
import check_slots  # noqa: E402

FX = root / "shared" / "tests" / "fixtures" / "adjudication"
for name in ("match", "undeclared", "undelivered", "forbidden", "suspectvar"):
    probs = check_slots.check(str(FX / ("slots_%s" % name)))
    print("fx_%s=%d" % (name, len(probs)))

defs = check_slots.agents(str(root))
print("agents=%d" % len(defs))
probs = check_slots.check(str(root))
kinds = Counter(p[0] for p in probs)
print("no_declaration=%d" % kinds.get("no_declaration", 0))
print("problems_other=%d" % (len(probs) - kinds.get("no_declaration", 0)))
for p in probs:
    if p[0] != "no_declaration":
        print("  PROBLEM %s %s @ %s %s" % p)
print("exempt_total=%d" % len(check_slots.EXEMPT_SLOTS))
print("exempt_uncited=%d" % len(check_slots.uncited_exemptions()))
```

**fixture 는 디렉토리로 만든다** — `check()` 가 repo_root 를 받으므로 각 fixture 가 `plugins/<p>/agents/*.md` + `plugins/<p>/skills/<s>/SKILL.md` 의 최소 트리를 갖는다. 즉 `slots_match/plugins/fx/agents/a.md` 꼴.

- [ ] **Step 4: RED 를 확인한다**

```bash
chmod +x shared/tests/test_agent_input_slots.sh
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -40
```

기대: fixture 다섯 **PASS**, `agents=20` **PASS**, `no_declaration=0` **FAIL** (18 이 나온다 — 설계 §4.3 의 「20 중 18은 슬롯 선언 자체가 없다」), 나머지 문제 목록도 **FAIL**.

- [ ] **Step 5: P1 의 결과를 반영한다**

Task 1 Step 8 이 `test_seed_agents.sh` 와의 충돌을 찾았으면, 그 자리를 `EXEMPT_SLOTS` 에 C6⑵ 인용과 함께 넣는다. **L3 를 빼지 않는다.**

- [ ] **Step 6: 커밋**

```bash
git add shared/adjudication/check_slots.py shared/tests/test_agent_input_slots.sh shared/tests/fixtures/adjudication/
git commit -m "test(adjudication): L3 입력 선언 락 — 선언·전달 일치와 금지 종류 (RED)"
```

- [ ] **Step 7: M1 — 다섯이 «전부» RED 인지 한 자리에서 확인한다**

각 Task 가 자기 락의 RED 를 확인했지만, M1 은 **다섯을 동시에** 본다. 하나가 GREEN 이면 그 락은 도착 즉시 이빨이 없었다는 뜻이고 **재설계 대상**이다.

```bash
for t in test_adjudication_wiring test_adjudication_consumed test_agent_input_slots test_runner_disposition test_dispatch_name_defined; do
  printf '%-32s ' "$t"
  bash "shared/tests/$t.sh" 2>&1 | tail -1
done
```

기대: 다섯 줄 전부 `Fail:` 뒤가 0 이 **아니다**.

**GREEN 인 락이 있으면 PR 을 열지 않는다.** 그 락으로 돌아가 무엇을 재고 있는지 다시 본다 — vacuous 가드(`0 은 통과가 아니다`)가 이미 있으므로, GREEN 은 「도출은 됐는데 위반이 없다」이거나 「단언이 대상을 못 짚는다」 둘 중 하나다. 각 락의 fixture 단언이 그 둘을 가른다.

- [ ] **Step 8: PR1 을 연다**

```bash
git push -u origin feature/adjudication-topology-unification
gh pr create --title "판정 지형 PR1 — 락 다섯 (전부 RED)" --body "$(cat /tmp/adjtopo/pr1-body.md)"
```

PR 본문에 **RED 인 채로 들어간다는 사실과 그 이유**를 적는다:

```markdown
## 무엇

회계 배선을 검사하는 락 다섯을 신설한다. **전부 RED 인 채로 들어간다.**

| 락 | 파일 | 오늘 |
|---|---|---|
| L1 배선 | `shared/tests/test_adjudication_wiring.sh` | RED — 미배선 <N>자리 |
| L2 소비 | `shared/tests/test_adjudication_consumed.sh` | RED — 카운트 7 중 6 미소비 |
| L3 입력 선언 | `shared/tests/test_agent_input_slots.sh` | RED — 20 중 18 선언 부재 |
| L4 역할 선언 | `shared/tests/test_runner_disposition.sh` | RED — 6/6 없음 |
| T4-2 참조 이름 | `shared/tests/test_dispatch_name_defined.sh` | RED — 매달림 1 |

## 왜 RED 인 채로

락이 오늘 RED 라는 것이 「이 락에 이빨이 있다」의 증거다. 배선 뒤에 넣으면 도착
즉시 GREEN 이고, 그 GREEN 이 배선 덕인지 락이 아무것도 안 재서인지 구별할 수 없다.
T4-2 는 특히 그렇다 — stale 이름이 살아 있는 지금 들어가야 RED 가 난다.

## 대가 (완화하지 않는다)

리포에 CI 가 없고 자동 실행자를 만들지 않기로 했으므로, 이 PR 의 RED 커밋은 merge
후 `main` 의 조상이 된다. GREEN 인 것은 트리 상태이지 히스토리가 아니다.
PR2 가 L1·L2·L4·T4-2 를, PR3 가 L3 를 GREEN 으로 만든다.

## 각 락이 못 하는 것

- **L1** — 컴프리헨션 필터로 버리면 요구가 문법상 성립하지 않는다. 개수 baseline 으로만 잡는다.
- **L2** — 키가 파일에 «쓰였는지»만 본다. 그 값이 stdout 까지 가는지는 정적으로 못 잰다.
- **L3(b)** — 선언값 판정이라 이름과 kind 를 함께 속이면 통과한다.
- **L4** — `disclosure=` 채널이 실제로 읽히는지는 못 잰다.

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01HEeJ3asbqiYTMQeCZQ4GfK
```

---

## PR2 — 배선 (락 넷 중 셋을 GREEN 으로)

### 이 계획이 설계 T1 표에서 고친 것 둘

**설계는 실제 코드에 맞춰 조정돼야 한다.** 배선 대상을 열면서 두 어긋남을 찾았다. 둘 다 설계의 방향은 맞고 자리 지정이 틀렸다.

| # | 설계 | 실제 | 이 계획 |
|---|---|---|---|
| ① | T1-2 가 `synthesize_findings.py:295` 를 「ⓐ 의 `dropped_raw` 흡수」로 적는다 | `:295` 는 `apply_verdicts` 안의 **항목 수준** 드롭이라 `dropped_primary` 를 낸다. `dropped_raw` 는 `_as_list`(`:75-104`)에서 온다 | `:295` 는 `hold("항목 파손: …")`(T1-2 의 메서드 그대로). `dropped_raw` 는 A1 로 옮긴다 |
| ② | T1-3 이 `dropped_verdicts`·`dropped_newlist` 를 「컨테이너 수준, 자리 미지정」으로 둔다 | 그 둘과 `dropped_raw` 가 **전부 `_as_list` 한 곳**을 지난다(`:53`·`:55`·`:56`·`:109`·`:110`·`:115`) | **셋이 한 자리로 접힌다** — `_as_list` 에 계산기 인자 하나. 설계가 「L1 이 구조적으로 못 보는 자리」로 분류한 것도 맞다(함수가 원소 루프를 갖지 않는다) |

**그리고 설계 T1 표에 없는 행이 하나 필요하다 — `accept()`.**
설계 §5 의 출력 예시는 `수용 8` 을 보여주고 L2 는 `accepted` 카운트의 소비를 요구한다. 그런데 T1 표 12행 어디에도 `accept()` 를 부르는 자리가 없다. 아무도 안 부르면 그 칸은 영구히 0이고, **0인 칸을 렌더하는 것은 「아무것도 수용되지 않았다」는 거짓말**이다. 아래 A10 이 그 행이다.

---

### Task 8: T1-A — `synthesize_findings.py` 배선

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py`
- Test: `plugins/quality-gates/tests/test_synthesize_promoted_findings.sh` (기존 — `dropped` 2수준 계수가 깨진다)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 2 의 `Ledger.suppressed(item, why)` · `Ledger.held_by_class()`
- Produces: `_as_list(value, what, ledger=None)` — **세 번째 인자 추가**. 호출부 여섯(`:53`·`:55`·`:56`·`:109`·`:110`·`:115`)이 전달한다
- Produces: `promote_new_findings(raw_new, existing, ledger=None)` · `dedup(findings, ledger=None)` · `suppress(findings, ledger=None)` · `_normalize_identity(f, ledger=None)` — 전부 계산기 인자 추가
- Produces: `load_yaml(path, ledger=None)` · `extract_verdicts(doc, ledger=None)` · `extract_new_findings(doc, ledger=None)`
- Produces: `render(...)` 의 시그니처 변경은 **Task 10 이 한다** — 이 Task 는 생산만, 소비는 다음 Task

- [ ] **Step 1: 실패하는 테스트를 쓴다 — 처분 행렬 fixture**

`plugins/quality-gates/tests/test_synthesize_disposition.sh` (신설). **라이브 `/qg` 에 의존하지 않는다**(M11):

```bash
#!/usr/bin/env bash
# guards: plugins/quality-gates/scripts/synthesize_findings.py
#
# 처분 여섯 종류가 각각 최소 1건씩 세어지는지 결정론 fixture 로 검사한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
SCRIPT="$REPO_ROOT/plugins/quality-gates/scripts/synthesize_findings.py"

TMPD="$(mktemp -d -t qgdisp-XXXXXX)" || exit 1
trap 'rm -rf "$TMPD"' EXIT

cat > "$TMPD/findings.yaml" <<'YAML'
findings:
  - {agent: sec, file: a.py, line: 1, severity: CRITICAL, summary: kept, confidence: 9}
  - {agent: sec, file: b.py, line: 2, severity: IMPORTANT, summary: rejected, confidence: 8}
  - {agent: sec, file: c.py, line: 3, severity: SUGGESTION, summary: low, confidence: 2}
  - {agent: rev, file: a.py, line: 1, severity: CRITICAL, summary: dup, confidence: 7}
  - "형태 불량 — 매핑이 아니다"
  - {agent: sec, file: d.py, line: 4, severity: IMPORTANT, summary: 판정없음, confidence: 8}
YAML

cat > "$TMPD/adversarial.yaml" <<'YAML'
verdicts:
  - {finding_id: "sec-a.py-1", verdict: confirm}
  - {finding_id: "sec-b.py-2", verdict: reject}
  - {finding_id: "sec-c.py-3", verdict: confirm}
  - {finding_id: "rev-a.py-1", verdict: confirm}
new_findings: "리스트가 아니다 — 컨테이너 소실"
YAML

OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT" \
        --findings "$TMPD/findings.yaml" \
        --adversarial "$TMPD/adversarial.yaml" 2>"$TMPD/err.txt")"
note "$OUT"

assert_grep "$OUT" '수용 [1-9]'      "수용이 세어진다 (accept — T1 표에 없던 행)"
assert_grep "$OUT" '기각 [1-9]'      "기각이 세어진다 (reject)"
assert_grep "$OUT" '억제 [1-9]'      "억제가 세어진다 (suppressed — D4)"
assert_grep "$OUT" '흡수 [1-9]'      "흡수가 세어진다 (absorbed — dedup)"
assert_grep "$OUT" '미판정 [1-9]'    "판정자 부재가 세어진다 (hold)"
assert_grep "$OUT" '배관 손실 [1-9]' "항목 파손 + 입력 실패가 배관 칸으로 간다"

finish
```

- [ ] **Step 2: 실패를 확인한다**

```bash
chmod +x plugins/quality-gates/tests/test_synthesize_disposition.sh
bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -20
```

기대: 여섯 단언 전부 FAIL — 오늘의 출력에 그 줄들이 아예 없다.

- [ ] **Step 3: A1 — `_as_list` 에 계산기 인자 (컨테이너 카운터 셋을 한 자리로)**

`:75` 의 시그니처와 `:100-104` 를 고친다:

```python
def _as_list(value, what, ledger=None):
```

```python
    lost = len(value) if isinstance(value, dict) else 1
    if ledger is not None:
        # primary=False — 이 컨테이너가 죽어도 «축»은 살아 있다(주 findings
        # 경로는 따로 돈다). primary=True 로 하면 blocks() 가 켜져 오늘 통과하는
        # 실행이 차단된다: 공시와 차단은 다른 술어다.
        ledger.source_failed(
            what, "expected list, got %s — %d건" % (type(value).__name__, lost),
            primary=False)
    print(f"[synthesize_findings] {what} is {type(value).__name__}, "
```

호출부 여섯에 `ledger` 를 흘린다:

```python
def load_yaml(path, ledger=None):
    ...
    if isinstance(data, dict) and "verdicts" in data:
        return _as_list(data.get("verdicts"), "verdicts", ledger)
    if isinstance(data, dict) and "findings" in data:
        return _as_list(data.get("findings"), "findings", ledger)
    return _as_list(data, "findings document", ledger)


def extract_verdicts(doc, ledger=None):
    if isinstance(doc, dict):
        return _as_list(doc.get("verdicts"), "verdicts", ledger)
    return _as_list(doc, "adversarial document", ledger)


def extract_new_findings(doc, ledger=None):
    if isinstance(doc, dict):
        return _as_list(doc.get("new_findings"), "new_findings", ledger)
    return [], 0
```

**`dropped` 반환값을 지우지 않는다** — `dropped_malformed` 는 stdout 공지의 기존 채널이고 `test_synthesize_promoted_findings.sh` 가 그 2수준 계수를 못 박고 있다. 원장은 **더한다**, 대체하지 않는다.

- [ ] **Step 4: A2·A3·A10 — `apply_verdicts` 세 자리**

`:289-318` 를 고친다:

```python
    for f in findings:
        if not isinstance(f, dict):
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(f)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed finding "
                  f"({type(f).__name__}, expected mapping): {str(f)[:80]!r}",
                  file=sys.stderr)
            continue
        f = _normalize_identity(dict(f), ledger=ledger)
        v = by_id.get(finding_id(f))
        if v is None:
            if ledger is not None:
                ledger.hold(finding_id(f), "판정자 부재: adversarial 판정 없음")
            out.append(f)
            continue
        verdict = v.get("verdict", "confirm")
        if verdict == "reject":
            if ledger is not None:
                ledger.reject(finding_id(f), "adversarial 기각")
            continue
        if verdict == "downgrade":
            f = dict(f)
            if "adjusted_severity" in v:
                f["severity"] = v["adjusted_severity"]
            if "adjusted_confidence" in v:
                f["confidence"] = v["adjusted_confidence"]
        if ledger is not None:
            ledger.accept(finding_id(f))
        out.append(f)
```

**세 가지가 바뀌었다.** ⑴ `:305` 의 `hold` 사유에 **접두를 붙였다**(`"판정자 부재: "`) — `held_by_class()` 가 그것으로 분류한다. ⑵ 기각 자리(T1-1). ⑶ **`accept()`** — 설계 T1 표에 없던 행. `v is None` 경로는 `hold` 뒤에 append 하므로 `accept` 를 부르지 않는다: 그것은 수용이 아니라 판정 없이 통과한 것이다.

- [ ] **Step 5: A4·A5 — `promote_new_findings` 두 자리**

`:226-239` 를 고친다. 시그니처에 `ledger=None` 을 더하고:

```python
    for item in raw_new:
        if not isinstance(item, dict):
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(item)[:60], "항목 파손: not a mapping")
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  "not a mapping", file=sys.stderr)
            continue
        missing = [k for k in NEW_FINDING_REQUIRED if not item.get(k)]
        if missing:
            dropped += 1
            if ledger is not None:
                ledger.hold(repr(item.get("summary", item))[:60],
                            "항목 파손: missing %s" % ", ".join(missing))
            print("[synthesize_findings] dropped malformed adversarial finding: "
                  f"missing {', '.join(missing)}", file=sys.stderr)
            continue
```

`:253` 의 `_normalize_identity(f)` 도 `_normalize_identity(f, ledger=ledger)` 로.

- [ ] **Step 6: A6 — `dedup` 의 흡수 (L1 이 구조적으로 못 보는 자리)**

`:321-342`. 손실이 그룹 «안»에서 일어나고 루프는 매 회 append 하므로 **L1 은 이 자리를 못 본다** — 락이 아니라 이 Task 가 책임진다.

```python
def dedup(findings, ledger=None):
    ...
    deduped = []
    for key, group in by_key.items():
        group.sort(key=_conf, reverse=True)
        merged = dict(group[0])
        merged["sources"] = sorted({g.get("agent", "?") for g in group})
        if ledger is not None:
            # 그룹의 첫 항목만 살아남는다. 나머지는 «소실이 아니라 귀속»이다 —
            # absorbed 는 degrade 가 아니다(adjudication.py 모듈 docstring).
            for g in group[1:]:
                ledger.absorbed(finding_id(g), finding_id(merged))
        deduped.append(merged)
    return deduped + passthrough
```

- [ ] **Step 7: A7 — `suppress` 의 억제 (D4 의 새 칸)**

`:345-365`:

```python
def suppress(findings, ledger=None):
    ...
    for f in findings:
        sev = _norm_sev(f)
        conf = _conf(f)
        if sev != "CRITICAL" and conf <= 4:
            if ledger is not None:
                ledger.suppressed(finding_id(f),
                                  "non-CRITICAL conf=%d <= 4 (C30 rubric)" % conf)
            suppressed.append(f)
        else:
            kept.append(f)
```

**`reject` 에 합치지 않는다**(D4) — 기각은 판정자의 판단이고 억제는 임계값의 결과다. 합치면 D2 가 없애려던 실명이 재발한다.

- [ ] **Step 8: A8 — `_normalize_identity` 확장의 강제 기록**

`:149-159`. **신설이 아니라 확장이다** — `_norm_sev`(`:386-412`)는 네 곳에서 불려 그 안에 넣으면 네 번 세어진다. 입력 직후 정규화 패스는 이 함수로 이미 존재한다.

```python
def _normalize_identity(f, ledger=None):
    """수집 지점에서 스칼라 정체성 필드를 확정한다(소비 지점마다 가드 금지).
    ...(기존 docstring 유지)...
    """
    for key, fn in (("file", _norm_file), ("line", _norm_line)):
        raw = f.get(key)
        new = fn(f)
        if ledger is not None and raw != new:
            # gate=False — 이 강제는 게이트 판정을 바꾸지 않는다(정체성 필드의
            # 표기만 바꾼다). gate=True 는 `>=3` 같은 임계 비교를 무력화하는
            # 대체에만 쓴다(adjudication.py:59-64).
            ledger.coerced(key, raw, new, gate=False)
        f[key] = new
    return f
```

**폭발 반경 주의**(설계 §10) — 이 함수는 `apply_verdicts:298` 과 `promote_new_findings:253` 두 곳에서 불린다. 형제 `_norm_sev` 의 주석이 과거 사고를 기록한다. Step 10 에서 기존 테스트 전량을 돌린다.

- [ ] **Step 9: A9 — `main` 에서 계산기를 흘린다**

`:538-556`:

```python
    doc = load_yaml_doc(args.adversarial) if args.adversarial else None
    verdicts, dropped_verdicts = extract_verdicts(doc, ledger=ledger)
    raw, dropped_raw = (load_yaml(args.findings, ledger=ledger)
                        if args.findings else ([], 0))

    findings, dropped_primary = apply_verdicts(raw, verdicts, ledger=ledger)
    new_raw, dropped_newlist = extract_new_findings(doc, ledger=ledger)
    promoted, dropped_promoted = promote_new_findings(new_raw, findings,
                                                      ledger=ledger)
    dropped_malformed = (dropped_raw + dropped_verdicts + dropped_newlist
                         + dropped_primary + dropped_promoted)
    findings = findings + promoted
    findings = dedup(findings, ledger=ledger)
    kept, suppressed = suppress(findings, ledger=ledger)
    kept = sort_findings(kept)
```

- [ ] **Step 10: 기존 테스트 전량 — 회귀를 잡는다**

```bash
for t in plugins/quality-gates/tests/test_synthesize*.sh; do
  printf '=== %s ===\n' "$t"; bash "$t" 2>&1 | tail -3
done
bash plugins/quality-gates/tests/test_synthesize_promoted_findings.sh 2>&1 | tail -15
```

**`test_synthesize_promoted_findings.sh` 의 `dropped` 2수준 계수는 반드시 GREEN 이어야 한다**(설계 §4.4). RED 면 원장이 기존 채널을 «대체»한 것이다 — 더하기로 되돌린다.

- [ ] **Step 11: L1 이 이 파일에서 GREEN 인지 확인한다**

```bash
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -A20 '미배선'
```

`synthesize_findings.py` 자리가 목록에서 사라져야 한다. **남는 자리가 있으면 면제 후보다** — Task 1 Step 6 의 규칙대로 C6 인용과 함께 `EXEMPT` 에 등재한다.

- [ ] **Step 12: bump + CHANGELOG + 커밋**

```bash
bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -12
```

여섯 단언 중 「배관 손실」·「수용」 등은 **Task 10 이 렌더를 붙이기 전까지 여전히 FAIL** 이다 — 이 Task 는 생산만 한다. 그 사실을 커밋 메시지에 적는다.

`plugins/quality-gates/.claude-plugin/plugin.json` → `5.3.0`, CHANGELOG:

```markdown
## [5.3.0] — 2026-09-03

### Changed
- `synthesize_findings.py` 의 버리는 자리 전부가 원장 처분을 부른다 — 기각·보류·흡수·억제·강제·입력 실패, 그리고 수용.
- `_as_list` 가 계산기 인자를 받는다: 컨테이너 카운터 셋(`dropped_raw`·`dropped_verdicts`·`dropped_newlist`)이 한 자리를 지나므로 그곳 하나가 셋을 덮는다.
- `hold()` 사유에 접두 둘(`판정자 부재: ` / `항목 파손: `)을 통일 — `held_by_class()` 가 그것으로 분류한다.

### Fixed
- 기존 `dropped_*` 카운터는 유지된다. 원장은 더하기이지 대체가 아니다.
```

```bash
git add plugins/quality-gates/scripts/synthesize_findings.py plugins/quality-gates/tests/test_synthesize_disposition.sh plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "feat(quality-gates): synthesize_findings 의 버리는 자리를 원장에 배선 (v5.3.0)"
```

---

### Task 9: T1-B — `synthesize_artifact_findings.py` 배선

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_artifact_findings.py`
- Test: `plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` (기존 — `degraded_reason` 닫힌 어휘 4값이 깨진다)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 2 의 `Ledger.held_by_class()`
- Produces: `phase_key(paths, ledger=None)` — `sources_failed` 카운터는 **유지**하고 원장을 더한다
- Produces: `phase_synth` 안의 `L` 이 `reject`·`hold`·`absorbed`·`source_failed` 를 부른다

**이 파일의 특수 사정** — `L = Ledger(items="closed")`(`:195`)다. 미판정 항목의 방향이 「제외」이므로 `surfaced()` 가 빈 리스트를 반환한다. **그래서 설계 §3.1 이 `surfaced()` 배선을 철회했다** — 여기서도 부르지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/quality-gates/tests/test_synthesize_artifact_findings.sh` 의 `finish` 앞에 추가:

```bash
note "── 처분 회계 (T1-B)"
cat > "$TMPD/afind.yaml" <<'YAML'
findings:
  - {agent: critic, target_anchor: "#a", severity: CRITICAL, summary: kept, dedup_key: k1}
  - {agent: critic, target_anchor: "#b", severity: IMPORTANT, summary: rejected, dedup_key: k2}
  - {agent: critic, target_anchor: "#c", severity: IMPORTANT, summary: 판정없음, dedup_key: k3}
sources_failed: 1
YAML
cat > "$TMPD/aadv.yaml" <<'YAML'
verdicts:
  - {finding_key: k1, verdict: confirm}
  - {finding_key: k2, verdict: reject}
new_findings:
  - "형태 불량"
  - {agent: adv, target_anchor: "#a", severity: IMPORTANT, summary: dup, dedup_key: k1}
YAML
OUT="$(PYTHONDONTWRITEBYTECODE=1 python3 "$SCRIPT" synth \
        --findings "$TMPD/afind.yaml" --adversarial "$TMPD/aadv.yaml" 2>&1)"
assert_grep "$OUT" 'rejected: *[1-9]'  "기각이 원장에 실린다"
assert_grep "$OUT" 'held: *[1-9]'      "판정자 부재가 원장에 실린다"
assert_grep "$OUT" 'absorbed: *[1-9]'  "kept_keys 중복 흡수가 세어진다"
assert_grep "$OUT" 'sources_failed: *[1-9]' "입력 실패가 원장에 실린다"
```

(출력 키 이름은 Task 10 이 정하는 렌더 모양을 따른다 — 이 파일은 YAML 을 낸다.)

- [ ] **Step 2: 실패를 확인한다**

```bash
bash plugins/quality-gates/tests/test_synthesize_artifact_findings.sh 2>&1 | tail -20
```

- [ ] **Step 3: B1 — `phase_key` 의 입력 실패 둘 (`:100-109`)**

```python
def phase_key(paths, ledger=None):
    by_key = {}
    sources_failed = 0
    for p in paths:
        doc = _load(p)
        if not _is_findings_doc(doc):
            sources_failed += 1
            if ledger is not None:
                ledger.source_failed(str(p), "findings 문서가 아니다", primary=False)
            continue
        for f in _findings_of(doc):
            if not isinstance(f, dict):
                sources_failed += 1
                if ledger is not None:
                    ledger.hold(repr(f)[:60], "항목 파손: not a mapping")
                continue
```

**둘의 처분이 다르다.** 위는 소스 하나가 통째로 죽은 것(`source_failed`), 아래는 그 안의 항목 하나가 깨진 것(`hold` + 「항목 파손」 접두). 오늘은 둘 다 같은 `sources_failed` 카운터로 흘러 구별되지 않는다 — 이것이 배선의 실질이다.

`primary=False` 인 이유: 여러 소스 중 하나가 죽은 것이고 나머지가 살아 있다. 유일 소스였는지는 이 함수가 모른다.

- [ ] **Step 4: B2 — `phase_synth` 의 항목 처분 넷 (`:196-223`)**

```python
    for f in findings:
        v = by_v.get(f["dedup_key"])
        if v is None:
            L.hold(f["dedup_key"], "판정자 부재: adversarial 판정 없음")
            continue
        verdict = str(v.get("verdict", "")).lower()
        if verdict == "reject":
            L.reject(f["dedup_key"], "adversarial 기각")
            continue
        if verdict == "downgrade":
            ns = str(v.get("new_severity", "")).upper()
            if ns in SEV:
                f = dict(f)
                f["severity"] = ns
        L.accept(f["dedup_key"])
        kept.append(f)
    unadjudicated = L.report()["counts"]["held"]

    kept_keys = {f["dedup_key"] for f in kept}
    for nf in new_findings:
        if not isinstance(nf, dict):
            L.hold(repr(nf)[:60], "항목 파손: not a mapping")
            continue
        g = dict(nf)
        g["severity"] = _norm_sev(g)
        g["dedup_key"] = dedup_key(g)
        if g["dedup_key"] in kept_keys:
            L.absorbed(g["dedup_key"], g["dedup_key"])
            continue
        kept_keys.add(g["dedup_key"])
        kept.append(g)
```

**`:199` 의 `hold` 사유에 접두를 붙였다** — 오늘은 `"adversarial 판정 부재"` 라 `held_by_class()` 가 「기타」로 분류한다. `unadjudicated` 의 값은 안 바뀐다(`held` 총계를 읽으므로).

`:216`(형태 불량 신규 finding)과 `:221`(dedup 흡수)은 **F2 가 새로 찾은 두 자리**다 — 오늘 아무 카운터도 없이 사라진다.

- [ ] **Step 5: B3 — `phase_synth` 의 로드 실패 (`:144-155`)**

```python
    findings_load_failed = (not findings_path) or (not _is_findings_doc(merged_doc))
    ...
    L = Ledger(items="closed")
    if findings_load_failed:
        # primary=True — 주 입력이 통째로 죽었으면 «아무도 안 봤다».
        L.source_failed(str(findings_path or "<no --findings>"),
                        "findings 문서 로드 실패", primary=True)
    if sources_failed > 0:
        L.source_failed("phase_key merge", "%d건 소실" % sources_failed,
                        primary=False)
```

**`L` 의 생성을 `:195` 에서 `:156` 근처로 «앞당긴다»** — 로드 실패를 기록하려면 그때 이미 원장이 있어야 한다. 순수 이동이고 `items="closed"` 는 그대로다.

- [ ] **Step 6: B4 — ⓑ 의 자체 `degraded`/`degraded_reason` 흡수 (`:235-243`)**

**닫힌 어휘 4값(`adversarial`·`findings_load`·`sources_failed`·`none`)을 유지한다** — `test_synthesize_artifact_findings.sh:86-241` 이 그것을 못 박는다. 원장은 **병행**으로 낸다:

```python
    degraded = adv_degraded or findings_load_failed or (sources_failed > 0)
    # 원장이 독립으로 계산한 degrade. 위 4값 어휘는 소비자 계약이라 유지하고,
    # 원장은 «더해서» 낸다 — 둘이 갈리면 그 자체가 회귀 신호다.
    ledger_degraded = L.report()["degraded"]
```

그리고 출력 dict 에 `ledger:` 블록을 더한다(Task 10 이 모양을 정한다).

- [ ] **Step 7: 기존 테스트와 L1 을 확인한다**

```bash
bash plugins/quality-gates/tests/test_synthesize_artifact_findings.sh 2>&1 | tail -12
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -c 'synthesize_artifact'
```

두 번째 명령의 기대: `0` — 이 파일의 미배선 자리가 사라졌다.

- [ ] **Step 8: bump + CHANGELOG + 커밋**

`plugin.json` → `5.4.0`. CHANGELOG 에 `## [5.4.0]` 항목. 커밋:

```bash
git add plugins/quality-gates/scripts/synthesize_artifact_findings.py plugins/quality-gates/tests/test_synthesize_artifact_findings.sh plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "feat(quality-gates): synthesize_artifact_findings 의 버리는 자리를 원장에 배선 (v5.4.0)"
```

---

### Task 10: T3 — 출력 모양 (L2 를 GREEN 으로)

**목표 모양**(설계 §5):

```
**Findings:** 0 CRITICAL / 3 IMPORTANT / 5 SUGGESTION
**처분:** 수용 8 · 기각 7 · 억제 2 · 흡수 4 · 미판정 1     ← 상태별, 차단 아님
**배관 손실:** 3 · 셀 수 없음 1 (차단)                      ← 차단은 blocks() 가 정한다
```

| 칸 | 들어가는 것 | 차단 |
|---|---|---|
| **처분** | `accepted` · `rejected` · `suppressed` · `absorbed` · `held_by_class()["판정자 부재"]` | 아니오 |
| **배관 손실** | `sources_failed` · `held_by_class()["항목 파손"]` · `held_by_class()["기타"]` · `coerced` · **`unknown_counts`(셀 수 없음)** | `blocks()` 가 정한다 |

**세 가지를 명시한다.**
⑴ **`unknown_counts` 는 `report()["counts"]` 에 없다** — 그런데 `blocks()` 의 세 항 중 하나다(`adjudication.py:96-98`). 빼면 **`uncountable` 로 차단된 실행이 어느 칸에도 숫자를 안 남긴다**. 별도 항목으로 싣는다.
⑵ **`coerced` 는 `blocks()` 가 읽지 않는다**(확인함, `:96-98`). 칸에는 싣되 차단에 기여하지 않는다. 칸의 합계와 차단이 같은 집합이 아니므로 `(차단)`/`(차단 아님)` 을 리터럴로 붙인다.
⑶ **`held_by_class()["기타"]` 를 배관 칸에 넣는 것이 U4 의 결정이다.** 미지 접두를 어느 칸에도 안 넣으면 두 칸의 합이 `held` 총계와 갈라지고 그 차이가 조용히 사라진다.

**Files:**
- Modify: `plugins/quality-gates/scripts/synthesize_findings.py` (`render` · `main`)
- Modify: `plugins/quality-gates/scripts/synthesize_artifact_findings.py` (출력 dict)
- Modify: `plugins/spec-distill/scripts/merge_review.py` · `merge_brief_review.py` (stdout 키)
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md:116` (키 열거 — L2 가 카운트를 실으면 깨진다)
- Test: `plugins/quality-gates/tests/test_synthesize_disposition.sh` (Task 8 이 만든 것 — 여기서 GREEN 이 된다)

**Interfaces:**
- Consumes: Task 2 의 `held_by_class()` · Task 8·9 의 배선
- Produces: `render(kept, suppressed_count, dropped_malformed, report, held_classes)` — **시그니처 변경**. 오늘의 `held_count`·`degraded`·`degrade_reasons` 셋을 `report` dict 하나로 대체한다
- Produces: `_disposition_lines(report, held_classes) -> list[str]` — 두 줄을 만드는 순수 함수. 네 소비자가 공유한다

- [ ] **Step 1: 두 줄을 만드는 순수 함수를 `shared/` 에 둔다**

네 소비자가 같은 두 줄을 내야 하므로 사본을 만들지 않는다. `shared/adjudication/render_disposition.py`:

```python
# -*- coding: utf-8 -*-
"""처분 두 줄 — 네 소비자가 공유하는 렌더.

회계 모듈(`adjudication.py`)은 «회계만» 한다(모듈 docstring:3-5). 서식은
이 파일의 몫이고, 여기 한 벌만 둔다 — 사본이 넷이면 한 칸을 고칠 때 셋이
남는다.

칸의 합계와 차단은 «같은 집합이 아니다». `coerced` 는 배관 칸에 실리지만
blocks() 가 읽지 않고, `unknown_counts` 는 counts dict 에 없지만 blocks() 의
세 항 중 하나다. 그래서 각 줄에 (차단)/(차단 아님) 을 리터럴로 붙인다.
"""


def disposition_lines(report, held_classes):
    """`Ledger.report()` 와 `held_by_class()` 로 두 줄을 만든다.

    반환은 `(처분줄, 배관줄, advisory목록)`. advisory 는 미지 접두가 있을 때만
    비어 있지 않다 — 회계 모듈이 아니라 소비자가 내는 것이 계약이다.
    """
    c = report["counts"]
    unknown = report.get("unknown_counts") or []

    line1 = ("**처분:** 수용 %d · 기각 %d · 억제 %d · 흡수 %d · 미판정 %d"
             "     (차단 아님)"
             % (c["accepted"], c["rejected"], c["suppressed"], c["absorbed"],
                held_classes["판정자 부재"]))

    plumbing = (c["sources_failed"] + held_classes["항목 파손"]
                + held_classes["기타"] + c["coerced"])
    line2 = ("**배관 손실:** %d · 셀 수 없음 %d     (차단: %s)"
             % (plumbing, len(unknown), "예" if report["degraded"] else "아니오"))

    advisories = []
    if held_classes["기타"] > 0:
        advisories.append(
            "[adjudication] hold 사유 %d건이 알려진 접두(「판정자 부재: 」·"
            "「항목 파손: 」)에 안 걸린다 — 배관 칸에 실었으나 분류되지 않았다."
            % held_classes["기타"])
    return line1, line2, advisories
```

**`(차단: 예/아니오)` 가 `report["degraded"]` 를 읽는 이유** — `blocks()` 는 원장 객체의 메서드이고 `report()` 는 dict 다. 소비자가 원장 객체를 안 들고 다녀도 되게 dict 만으로 만든다. `degraded` 는 `blocks()` 를 포함하되 더 넓다(`_degraded():100-103`) — **더 넓은 쪽을 쓴다**: 공시는 언제나, 차단은 좁게.

- [ ] **Step 2: 배포 링크를 만든다**

`adjudication.py` 와 같은 방식으로 두 플러그인에 심볼릭 링크를 건다:

```bash
ln -s ../../../shared/adjudication/render_disposition.py plugins/quality-gates/scripts/render_disposition.py
ln -s ../../../shared/adjudication/render_disposition.py plugins/spec-distill/scripts/render_disposition.py
git add plugins/quality-gates/scripts/render_disposition.py plugins/spec-distill/scripts/render_disposition.py
git ls-files -s plugins/*/scripts/render_disposition.py
```

**`git ls-files -s` 가 `120000` 을 내는지 확인한다** — `100644` 면 링크가 아니라 사본이 커밋된 것이고, 그러면 한 벌만 둔다는 이 Task 의 전제가 무너진다.

- [ ] **Step 3: `render()` 를 고친다**

`synthesize_findings.py` — `render` 시그니처와 `:490-504`:

```python
def render(kept, suppressed_count, dropped_malformed, report, held_classes):
```

```python
    counts_line = (
        f"**Findings:** {counts['CRITICAL']} CRITICAL / "
        f"{counts['IMPORTANT']} IMPORTANT / {counts['SUGGESTION']} SUGGESTION"
    )
    if suppressed_count > 0:
        counts_line += f" — {suppressed_count} suppressed (conf <= 4)"

    disp_line, plumb_line, advisories = disposition_lines(report, held_classes)
    for a in advisories:
        print(a, file=sys.stderr)

    out = ["## Review Findings (Synthesized)", "", counts_line,
           disp_line, plumb_line, ""]
```

`:496-498` 의 `held_count` 분기는 **삭제한다** — `미판정` 이 처분 줄로 옮겨갔다. 상단에 import 한 줄:

```python
from render_disposition import disposition_lines
```

`main` 의 마지막 두 줄:

```python
    report = ledger.report()
    sys.stdout.write(render(kept, len(suppressed), dropped_malformed,
                            report, ledger.held_by_class()))
```

- [ ] **Step 4: 나머지 소비자 셋**

**`synthesize_artifact_findings.py`** — YAML 출력이므로 두 줄이 아니라 dict 를 낸다. `phase_synth` 의 출력 dict 에 블록 하나를 더한다. **기존 `degraded`·`degraded_reason` 4값 어휘는 그대로 둔다**(§4.4):

```python
    rep = L.report()
    out["adjudication"] = {
        "counts": rep["counts"],
        "held_by_class": L.held_by_class(),
        "unknown_counts": rep["unknown_counts"],
        "degraded": rep["degraded"],
        "reasons": rep["reasons"],
    }
```

**`Ledger(items="closed")` 라 `surfaced()` 를 부르지 않는다** — 빈 리스트를 반환한다(`adjudication.py:136-138`). 설계 §3.1 이 철회한 그 자리다.

**`merge_review.py`** — `:592-593` 이 이미 두 키를 낸다. 나머지를 **같은 자리에** 더한다:

```python
    print(f"adjudication_held: {_yaml_scalar(merged['held'])}")
    print(f"adjudication_unknown: {_yaml_scalar(','.join(merged['unknown']))}")
    # L2 가 요구하는 나머지 — 카운트가 «전부» 출력에 실려야 한다.
    _c = merged["report"]["counts"]
    for _k in ("accepted", "rejected", "absorbed", "coerced",
               "sources_failed", "suppressed"):
        print(f"adjudication_{_k}: {_yaml_scalar(_c[_k])}")
    _hc = merged["held_by_class"]
    print(f"adjudication_held_unadjudicated: {_yaml_scalar(_hc['판정자 부재'])}")
    print(f"adjudication_held_malformed: {_yaml_scalar(_hc['항목 파손'])}")
    print(f"adjudication_held_other: {_yaml_scalar(_hc['기타'])}")
```

**키 이름을 `for` 루프로 만드는 이유** — 여섯 개를 손으로 적으면 `Ledger` 에 카운트가 늘어도 이 자리가 조용하다. 그것이 L2 가 막으려는 바로 그 모양이다. **단 이 루프 자체가 L1 의 대상이 된다** — `continue` 가 없으므로 통과한다.

`merged` 에 `report`·`held_by_class` 를 싣는 것은 병합 함수의 몫이다. `codex_ledger`·`history_ledger` 둘이 있으므로(`:486`·`:530`) **합쳐서 하나로 보고한다** — 각각 따로 내면 소비자가 둘을 더해야 하고, 더하는 자리가 새 결함 지점이 된다.

**`merge_brief_review.py`** — 같은 키 셋, 같은 루프. 이 파일도 원장을 셋 만든다(`:180`·`:192`·`:289` 근방의 처분 호출) — 확인해서 전부 합친다.

- [ ] **Step 5: `reviewing-spec/SKILL.md:116` 의 키 열거를 갱신한다**

그 줄이 merge_review stdout 의 키를 열거하고 있어 L2 가 카운트를 실으면 부정확해진다. 새 키 여섯을 더하고, **「뒤 둘은 각각 버린 항목 수 · 셀 수 없는 항목」 서술을 새 목록에 맞게 고친다.**

```bash
sed -n '116p' plugins/spec-distill/skills/reviewing-spec/SKILL.md
grep -rn 'adjudication_held' plugins/spec-distill/ | grep -v CHANGELOG
```

**두 번째 명령이 중요하다** — 그 키를 파싱하는 자리가 SKILL.md 말고 또 있으면 함께 고친다.

- [ ] **Step 6: L2 와 Task 8 의 테스트를 GREEN 으로**

```bash
bash shared/tests/test_adjudication_consumed.sh 2>&1 | tail -20
bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -12
```

기대: 둘 다 `Fail: 0`.

**L2 가 여전히 RED 면 어느 키가 남았는지 목록에 나온다** — `UNCONSUMED <파일>: <키들>`.

- [ ] **Step 7: bump + CHANGELOG + 커밋**

두 플러그인 다 건드렸다 — `quality-gates` → `5.5.0`, `spec-distill` → `0.49.0`.

```bash
git add shared/adjudication/render_disposition.py plugins/quality-gates/scripts/ plugins/spec-distill/scripts/ plugins/spec-distill/skills/reviewing-spec/SKILL.md plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md plugins/spec-distill/CHANGELOG.md
git commit -m "feat(adjudication): 처분 두 줄을 소비자 넷에 실는다 (qg v5.5.0, sd v0.49.0)"
```

---

### Task 11: T5 — 훅 층 회계

**C13 이 confirmed 이고** *"Phase 0 이 이 세션에 배정한 훅 차단 결정 2곳을 더한다"* 로 포함을 명시한다.

| # | 자리 | 무엇 |
|---|---|---|
| T5-1 | `review-dispatch.py:598-602` (`decision:"block"` — 구조 검증 실패) | 차단 사실과 사유를 원장 어휘로 |
| T5-2 | `review-dispatch.py:751-755` (`decision:"block"` — 다음 턴 dispatch 강제) | 같음 |

**공시 채널은 `reason` 이다.** 그 두 자리는 이미 `decision`·`reason`·`systemMessage` **세 키**를 낸다(F3). 입력 인터뷰 `:515-520` 이 카나리로 실측했다 — `systemMessage` **0/14 도달** · `additionalContext` 8/8 · 차단 결정에 딸린 `reason` **7/7**. `additionalContext` 는 쓰지 않는다(brief OQ26 의 폭주 실측 대상). **영속 기록은 `write_state_file()`**(`:198-204`).

**U3 의 결정 — 이 `reason` 기록이 회계 요건을 충족한다.** 근거: CLAUDE.md 의 계약이 *"무엇이 degrade 든 언제나 드러내되, 막는 것은 …"* 이고 이 자리는 **이미 막고 있다**. 남은 요구는 공시이고 `reason` 이 7/7 로 도달한다. 원장 객체는 프로세스와 함께 사라지므로 **`reasons()` 의 줄을 `reason` 에 실어 보내는 것으로 회계가 «완료»된다** — 이 사실을 코드 주석에 적는다.

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py`
- Test: `plugins/spec-distill/tests/test_review_dispatch_disposition.sh` (신설)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: `from adjudication import Ledger` — `:52-53` 이 이미 `SCRIPTS_DIR` 을 `sys.path` 에 넣는다(Task 1 Step 7 이 실행으로 확인)
- Produces: 없음 (훅은 종단이다)

- [ ] **Step 1: P6 를 다시 확인한다 — 편집 직전에**

Task 1 Step 9 가 형제 세션의 편집 범위를 적었다. **확인과 편집 사이가 창이므로 여기서 다시 본다:**

```bash
git fetch origin
git log --oneline origin/main -3
git diff --stat origin/main -- plugins/spec-distill/hooks/review-dispatch.py
sed -n '596,604p' plugins/spec-distill/hooks/review-dispatch.py
sed -n '749,757p' plugins/spec-distill/hooks/review-dispatch.py
```

**두 `decision:"block"` 분기가 그대로 있는지 눈으로 확인한다.** 줄번호가 움직였으면 그 줄번호를 쓰고, 분기 자체가 사라졌으면 **여기서 멈추고 보고한다**(설계 §7 의 재설계 조건).

- [ ] **Step 2: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_review_dispatch_disposition.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/hooks/review-dispatch.py
#
# 훅의 차단 결정 두 자리가 자기 처분을 원장 어휘로 밝히는지 검사한다.
#
# 채널은 `reason` 이다. `systemMessage` 는 모델 컨텍스트에 도달하지 않는다
# (카나리 14개 중 0개). `reason` 은 차단 결정에 딸릴 때 7/7 도달한다.
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../../../shared/tests/assert.sh"
REPO_ROOT="$(cd "$HERE/../../.." && pwd)"
HOOK="$REPO_ROOT/plugins/spec-distill/hooks/review-dispatch.py"

BODY="$(cat "$HOOK")"

assert_grep "$BODY" 'from adjudication import Ledger' \
  "훅이 원장을 import 한다 (㉮ 에 들어온다 — L1 의 대상이 된다)"

# 차단 결정 자리마다 처분 호출이 있는지. 자리 «수»에서 출발한다 —
# 하나를 배선하고 다른 하나를 잊는 것이 이 검사가 막는 것이다.
nblock="$(printf '%s\n' "$BODY" | grep -c '"decision": "block"')"
ndisp="$(printf '%s\n' "$BODY" | grep -cE '\.(hold|reject|source_failed|uncountable)\(')"
note "차단 결정 $nblock 자리 · 처분 호출 $ndisp 건"
if [ "${nblock:-0}" -gt 0 ] 2>/dev/null; then
  ok "차단 결정 $nblock 자리 (0 이 아니다)"
else
  no "차단 결정이 0 이다 — grep 이 깨졌거나 분기가 사라졌다. 이 검사가 공허하다"
fi
if [ "${ndisp:-0}" -ge "${nblock:-0}" ] 2>/dev/null; then
  ok "처분 호출 $ndisp >= 차단 자리 $nblock"
else
  no "차단 자리 $nblock 중 $((nblock - ndisp)) 곳이 처분을 안 부른다"
fi

# `reason` 에 원장 사유가 실리는지 — 채널을 못 박는다.
assert_grep "$BODY" 'reasons\(\)' \
  "원장의 reasons() 를 읽는다 (원장 객체는 프로세스와 함께 사라진다)"
assert_not_grep "$BODY" 'systemMessage.*reasons\(\)' \
  "원장 사유를 systemMessage 로 보내지 않는다 (모델 도달 0/14)"

finish
```

**`assert_not_grep` 이 짝이다** — 「`reason` 에 실어라」만 재면 `systemMessage` 에도 실은 판본이 통과한다.

- [ ] **Step 3: 실패를 확인한다**

```bash
chmod +x plugins/spec-distill/tests/test_review_dispatch_disposition.sh
bash plugins/spec-distill/tests/test_review_dispatch_disposition.sh 2>&1 | tail -15
```

- [ ] **Step 4: import 와 헬퍼를 더한다**

`review-dispatch.py` `:54-55` 근처(다른 `scripts/` import 들과 같은 자리):

```python
from adjudication import Ledger  # noqa: E402
```

그리고 `write_state_file`(`:198`) 근처에 헬퍼 하나:

```python
def _block_with_ledger(payload: dict, ledger: Ledger, advisory) -> int:
    """차단 결정에 원장 사유를 «reason 으로» 실어 낸다.

    원장 객체는 이 프로세스와 함께 사라진다. `reasons()` 의 줄을 reason 에
    실어 보내는 것이 이 층의 회계 완료 조건이다 — 그 필드가 모델에 도달하는
    유일한 채널이기 때문이다(카나리: systemMessage 0/14 · reason 7/7).
    """
    lines = ledger.reasons()
    if lines:
        payload["reason"] = (payload.get("reason", "")
                             + "\n\n[처분] " + " · ".join(lines))
    print(json.dumps(with_advisory(payload, advisory)), flush=True)
    return 0
```

- [ ] **Step 5: T5-1 — 구조 검증 실패 자리 (`:598-602`)**

```python
        L = Ledger(items="closed")   # 다음 소비자가 기계(다음 턴의 dispatch)다
        for line in lines:
            L.hold(line[:60], "항목 파손: 스코프 문서 구조 검증 실패")
        return _block_with_ledger({
            "decision": "block",
            "reason": "\n".join(lines),
            "systemMessage": "[spec-distill] 스코프 문서 구조 검증 실패 — 이번 turn 은 리뷰 dispatch 없음",
        }, L, capped_advisory)
```

**`for line in lines:` 가 루프다** — 훅이 ㉮ 에 들어오면 L1 이 이 파일의 모든 `for` 문을 보므로 이 루프도 대상이 되고, 처분 호출이 같은 분기 안에 있어 통과한다. 설계 §7 이 지적한 「공허한 GREEN」이 여기서 닫힌다.

- [ ] **Step 6: T5-2 — dispatch 강제 자리 (`:751-755`)**

```python
    L = Ledger(items="closed")
    L.hold(str(picked), "판정자 부재: 리뷰가 아직 안 돌았다 — 다음 턴에 강제한다")
    return _block_with_ledger({
        "decision": "block",
        "reason": msg,
        "systemMessage": "[spec-distill] reviewing-spec dispatch enforced for next turn",
    }, L, capped_advisory)
```

- [ ] **Step 7: 훅이 여전히 도는지 실행으로 확인한다**

정적 검사만으로는 import 실패를 못 잡는다. 훅을 실제 payload 로 부른다:

```bash
echo '{"session_id":"probe-t5","transcript_path":"/dev/null","cwd":"'"$(pwd)"'","hook_event_name":"Stop"}' \
  | PYTHONDONTWRITEBYTECODE=1 DEVBREW_SPEC_DISTILL_SESSION_ID=probe-t5 \
    python3 plugins/spec-distill/hooks/review-dispatch.py; echo "rc=$?"
```

기대: `rc=0`, `ImportError` 없음. **stdout 이 비어도 정상이다**(발견할 문서가 없는 세션).

- [ ] **Step 8: M3 — 「L1 GREEN」만으로 판정하지 않는다**

```bash
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -E 'union=|CONSUMER|미배선'
bash plugins/spec-distill/tests/test_review_dispatch_disposition.sh 2>&1 | tail -10
grep -c '"decision": "block"' plugins/spec-distill/hooks/review-dispatch.py
```

기대 셋: ㉮ 가 **4 → 5**(훅이 들어왔다) · 새 테스트 `Fail: 0` · 차단 자리 **2**.
**㉮ 가 5가 된 것만으로 통과로 읽지 않는다**(설계 M3) — 세 번째 명령이 두 자리를 확인하고 두 번째 명령이 각 자리의 처분 호출을 확인한다.

**L1 은 이 파일에서 열 자리를 새로 요구한다** — 이 Task 가 배선하는 둘은 그 열에 «포함되지 않는다»(두 `decision:"block"` 은 루프 안이 아니다). 착수 전 pre-flight 가 세 루프를 읽고 열 자리 전부 항목이 소실되지 않음을 확인했다(R1 판정). Task 1 Step 6 의 면제 절차를 그대로 적용한다:

```bash
PYTHONDONTWRITEBYTECODE=1 python3 /tmp/adjtopo/run_scan.py | grep 'review-dispatch'
```

나온 자리를 `check_wiring.EXEMPT` 에 **선택 루프** 형태의 C6⑴ 인용과 함께 등재한다. 등재 후 L1 이 GREEN 이어야 한다. **`:308`·`:310`(상한 도달)은 규칙 억제로 볼 여지가 있다** — 면제로 두되 그 사실을 baseline 문서에 적어 최종 리뷰가 보게 한다.

- [ ] **Step 9: bump + CHANGELOG + 커밋**

`spec-distill` → `0.50.0`.

```bash
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/tests/test_review_dispatch_disposition.sh plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "feat(spec-distill): 훅의 차단 결정 두 자리를 원장에 배선 (v0.50.0)"
```

---

### Task 12: T4-1 — stale 이름 제거 + §4.4 기존 락 갱신

**T4-1 은 긴급하지 않다.** `quality-pipeline/SKILL.md:511` 이 *"Dispatch `quality-gates:synthesizer` **(or local synthesize_findings.py)**"* 로 적고 **괄호 안이 이미 탈출구다**. 값은 T4-2(Task 6)가 다음 stale 을 잡는 데 있다 — 이 Task 는 그 락을 GREEN 으로 만든다(M4).

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:511`
- Modify: `plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh` (§4.4 — **약화 금지**)
- Modify: `plugins/quality-gates/.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 6 의 `check_names.dangling(repo_root)`

- [ ] **Step 1: stale 이름을 지운다**

`:511` 을 이렇게 바꾼다:

```markdown
4. Run `synthesize_findings.py` (`${CLAUDE_PLUGIN_ROOT}/scripts/`)
   to consolidate findings. **Capture the script's complete stdout** — the
```

`quality-gates:synthesizer` agent 는 `37ea0d7 refactor(quality-gates): synthesizer agent → script (T3-2, v1.28.0)` 이 정의를 지우고 스크립트로 옮겼다. 괄호 안의 대안이 유일한 실체이므로 **괄호를 본문으로 승격한다.**

- [ ] **Step 2: 다른 자리에 남았는지 스윕한다 — 식별자가 아니라 «개념»으로**

```bash
grep -rn 'quality-gates:synthesizer' --include='*.md' . | grep -v CHANGELOG
grep -rn 'synthesizer' plugins/quality-gates/skills/ plugins/quality-gates/agents/ plugins/quality-gates/commands/ 2>/dev/null
grep -rln 'Dispatch .*synthesi' plugins/
```

**세 번째 명령이 개념 스윕이다** — 식별자만 grep 하면 다른 이름으로 같은 것을 가리키는 참조가 살아남는다.

- [ ] **Step 3: T4-2 가 GREEN 이 되는지 확인한다 (M4)**

```bash
bash shared/tests/test_dispatch_name_defined.sh 2>&1 | tail -20
```

기대: `dangling=0` **PASS**. PR1 에서 RED 였던 것이 여기서 GREEN 이 된다 — **그 전이가 이 락에 이빨이 있다는 증거다.**

- [ ] **Step 4: §4.4 의 기존 락 넷을 확인하고 «갱신»한다**

| 락 | 무엇이 깨지나 | 어떻게 |
|---|---|---|
| `test_skill_drop_notice_consumed.sh` | 생산자–소비자 문자열 동일성. **리포에서 그 seam 을 재는 유일한 락** | **약화 금지.** 문자열이 바뀌었으면 락의 «양쪽»을 같이 고친다. 조건을 느슨하게 하지 않는다 |
| `test_synthesize_artifact_findings.sh:86-241` | `degraded_reason` 닫힌 어휘 4값 | Task 9 가 4값을 유지했으므로 GREEN 이어야 한다. RED 면 Task 9 가 어휘를 바꾼 것이다 |
| `test_synthesize_promoted_findings.sh` | `dropped` 2수준 계수 | Task 8 이 카운터를 유지했으므로 GREEN 이어야 한다 |
| `reviewing-spec/SKILL.md:116` | merge_review 출력 키 열거 | Task 10 이 이미 갱신했다 — 확인만 |

```bash
bash plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh 2>&1 | tail -10
bash plugins/quality-gates/tests/test_synthesize_artifact_findings.sh 2>&1 | tail -5
bash plugins/quality-gates/tests/test_synthesize_promoted_findings.sh 2>&1 | tail -5
```

**seam 락이 RED 면 «조건을 완화하지 않는다»** — 그것이 이 리포에서 생산자–소비자 결합을 재는 유일한 락이고, 느슨하게 만드는 순간 이빨이 사라진다. Task 14 의 M9 가 그 이빨의 생존을 따로 잰다.

- [ ] **Step 5: bump + CHANGELOG + 커밋 + PR2**

`quality-gates` → `5.6.0`.

```bash
git add plugins/quality-gates/skills/quality-pipeline/SKILL.md plugins/quality-gates/tests/ plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "fix(quality-gates): stale agent 이름 제거 — 정의는 37ea0d7 이 스크립트로 옮겼다 (v5.6.0)"
git push
```

PR2 본문에 **네 락의 전이**를 적는다:

```markdown
## 락의 전이 (PR1 → PR2)

| 락 | PR1 | PR2 | 무엇이 바꿨나 |
|---|---|---|---|
| L1 배선 | RED (<N>자리) | **GREEN** | Task 8·9·11 의 배선 |
| L2 소비 | RED (7 중 6 미소비) | **GREEN** | Task 10 의 두 줄 |
| L4 역할 선언 | RED (6/6 없음) | RED — **PR3 로** | 러너 편집이 PR3 범위 |
| T4-2 참조 이름 | RED (매달림 1) | **GREEN** | Task 12 의 stale 제거 |
| L3 입력 선언 | RED (20 중 18) | RED — **PR3 로** | 20 에이전트 마이그레이션 |

**「L1 GREEN」을 「배선 완료」로 읽지 말 것.** L1 이 구조적으로 못 보는 자리가 넷 있고
(`_as_list` 의 컨테이너 수준 · `dedup` 의 그룹 내부 손실 · `suppress` 의 리스트 분기 ·
`_normalize_identity` 의 값 강제) 그 넷은 락이 아니라 Task 8·9 가 책임진다.
`test_synthesize_disposition.sh` 의 처분 행렬이 그것을 따로 잰다.
```

---

## PR3 — 선언 마이그레이션 (L4·L3 을 GREEN 으로)

### Task 13: L4 — codex 러너 여섯에 처분 선언

**요구** — ㉯ 의 여섯 러너가 `consumer=` · `fail-open|fail-closed` · `disclosure=` 를 밝힌다.

**형태** — CLAUDE.md 의 처분 앵커와 같은 한 줄을 러너 상단 주석에 둔다:

```bash
# **처분** — consumer=<같은 플러그인의 .py|orchestrator|human> · fail-<open|closed> · disclosure=<리터럴>
```

**`consumer=` 가 경로면 그 경로는 실재해야 하고 앵커가 사는 파일과 «같은 플러그인»이어야 한다** — 설치본에서 다른 플러그인의 스크립트는 도달 불가다. `disclosure=` 는 `consumer=` 가 `.py` 경로일 때만 생략 가능하다(그때는 그 파일이 회계 모듈을 실제로 import 하는지가 대신 검사된다).

**Files:**
- Modify: Task 1 Step 3 이 `/tmp/adjtopo/codex-runners.txt` 에 남긴 여섯 파일
- Modify: 각 러너가 속한 플러그인의 `plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 5 의 `test_runner_disposition.sh`

- [ ] **Step 1: 여섯 러너의 실제 소비자를 «읽어서» 확인한다**

선언을 추측으로 쓰지 않는다. 각 러너가 무엇을 내고 누가 그것을 읽는지 본다:

```bash
cat /tmp/adjtopo/codex-runners.txt
while IFS= read -r f; do
  printf '\n===== %s =====\n' "$f"
  grep -n 'OUT\|yaml\|json\|>' "$f" | head -12
done < /tmp/adjtopo/codex-runners.txt
```

그리고 각 러너의 산출물을 누가 읽는지 역방향으로:

```bash
grep -rn 'run_spec_codex_reviewer\|run_brief_codex\|codex_findings_to_yaml' plugins/*/skills/ plugins/*/scripts/ | grep -v CHANGELOG | head -20
```

- [ ] **Step 2: 여섯 자리에 앵커를 쓴다**

각 러너의 shebang 다음, 파일 설명 주석 안에. **여섯 개를 같은 값으로 복사하지 않는다** — Step 1 이 읽은 실제 소비자를 각각 적는다. 예(`run_spec_codex_reviewer.sh`):

```bash
#!/usr/bin/env bash
# spec design doc 의 codex co-review 를 돌리고 YAML 을 낸다.
#
# **처분** — consumer=plugins/spec-distill/scripts/merge_review.py · fail-open · disclosure=advisory
#
# fail-open 인 이유: codex 가 죽어도 Claude 리뷰는 이미 돌았다. 이 축의 주
# 판정자가 아니라 모델 다양성 보조다 — 죽으면 공시하되 막지 않는다.
```

**`fail-open` / `fail-closed` 를 근거 없이 적지 않는다.** 각 러너 밑에 한 줄로 이유를 붙인다 — 그 한 줄이 다음 저자가 값을 뒤집을 때 무엇을 뒤집는지 알게 하는 유일한 것이다.

- [ ] **Step 3: `consumer=` 경로가 실재하고 같은 플러그인인지 확인한다**

```bash
grep -rn '\*\*처분\*\*' plugins/*/scripts/*.sh
grep -rhn 'consumer=[^ ·]*\.py' plugins/*/scripts/*.sh | sed 's/.*consumer=\([^ ·]*\.py\).*/\1/' | sort -u | while IFS= read -r p; do
  if [ -f "$p" ]; then echo "OK   $p"; else echo "MISS $p"; fi
done
```

`MISS` 가 하나라도 있으면 그 앵커는 도달 불가한 소비자를 가리킨다.

- [ ] **Step 4: L4 가 GREEN 인지 확인한다**

```bash
bash shared/tests/test_runner_disposition.sh 2>&1 | tail -25
```

기대: 18 단언(6 × 3) 전부 PASS, `Fail: 0`.

- [ ] **Step 5: 기존 dispatch 락이 안 깨졌는지**

```bash
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -10
```

앵커 서식(축 A④)이 이미 검사되고 있으므로 서식이 어긋나면 여기서 RED 가 난다.

- [ ] **Step 6: bump + CHANGELOG + 커밋**

건드린 플러그인마다 bump. 러너가 `quality-gates` 와 `spec-distill` 양쪽에 있으므로 둘 다일 가능성이 높다 — `git diff --name-only` 로 확인하고 bump 한다.

```bash
git diff --name-only | cut -d/ -f2 | sort -u
git add plugins/
git commit -m "feat(adjudication): codex 러너 여섯이 자기 처분을 밝힌다 — L4 GREEN"
```

---

### Task 14: L3 — 에이전트 스무 개의 슬롯 선언 + dispatch 표기

**이 계획의 가장 큰 단일 작업이다.** 20 에이전트 중 **18은 슬롯 선언 자체가 없고**, 5개 플러그인의 dispatch 표기가 따라온다.

**Files:**
- Modify: `plugins/*/agents/*.md` 20개 (frontmatter `input_slots:`)
- Modify: `plugins/*/skills/**/SKILL.md` 의 dispatch 자리 (태그·변수 쌍)
- Modify: 건드린 플러그인마다 `plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: Task 7 의 `check_slots.check(repo_root)` — 문제 목록이 작업 목록이다

- [ ] **Step 1: 작업 목록을 판정기에서 «도출»한다**

손으로 열거하지 않는다. 락이 이미 전수를 낸다:

```bash
bash shared/tests/test_agent_input_slots.sh 2>&1 | grep -E 'PROBLEM|no_declaration'
PYTHONDONTWRITEBYTECODE=1 python3 shared/tests/fixtures/adjudication/run_slots.py "$(pwd)" > /tmp/adjtopo/slots-todo.txt
grep -c 'PROBLEM' /tmp/adjtopo/slots-todo.txt
```

- [ ] **Step 2: 에이전트 하나로 문법을 확정한다 — 나머지는 그 형태를 따른다**

가장 단순한 것부터. `plugins/spec-distill/agents/seed-readback.md`(도구 0개, 슬롯 하나):

```yaml
---
name: seed-readback
description: ...
tools: []
model: inherit
input_slots:
  - tag: seed
    var: SEED_TEXT
    kind: artifact
---
```

그리고 그 dispatch 자리(`conducting-interview/SKILL.md` 의 javascript 펜스)가 `<seed>${SEED_TEXT}</seed>` 를 전달하는지 확인한다:

```bash
grep -n 'seed>\${' plugins/spec-distill/skills/*/SKILL.md
bash shared/tests/test_agent_input_slots.sh 2>&1 | grep 'seed-readback'
```

**한 개가 통과하는 것을 확인한 뒤에 나머지로 간다** — 문법이 틀렸으면 20번 고쳐야 한다.

- [ ] **Step 3: `kind:` 를 «읽어서» 정한다 — 추측하지 않는다**

각 에이전트의 dispatch 프롬프트가 실제로 무엇을 싣는지 보고 정한다.

| 실린 것 | `kind:` |
|---|---|
| 이번 과업의 지시·대상 경로 | `task` |
| 리뷰 대상 문서·코드 본문 | `artifact` |
| **같은 출처**의 과거 findings/이슈 이력 | `same_origin_history` |
| 리포 규약·CLAUDE.md·설계 문서 | `repo_context` |
| **다른 리뷰어의 판정** | `prior_verdict` ← 금지. 면제 등재 필요 |
| 점수·순위·신뢰도 | `score` ← 금지 |
| orchestrator 의 기대·유도 문구 | `orchestrator_framing` ← 금지 |

**금지 종류가 실제로 실리고 있으면 두 길뿐이다.** ⑴ 그것을 빼는 것(누출을 고치는 것) ⑵ `EXEMPT_SLOTS` 에 **C6 인용과 함께** 등재하는 것. adversarial·refuter 계열은 ⑵ 가 맞다 — 앞 판정을 반박하는 것이 그 agent 의 과업이라 대응물이 원리적으로 없다(C6⑴).

```python
EXEMPT_SLOTS = {
    ("quality-gates:adversarial", "verdicts"):
        "C6(1) 앞 판정을 반박하는 것이 이 agent 의 과업이다 — 대응물이 없다",
    ("plugin-audit:audit-refuter", "findings"):
        "C6(1) 감사 findings 를 반박하는 것이 과업이다",
}
```

**⑴ 과 ⑵ 를 구별하는 것이 이 Step 의 실질이다.** 전부 면제로 넣으면 L3(b)가 장식이 된다 — M8 이 그래서 목록 크기를 잰다.

- [ ] **Step 4: 스무 개를 마이그레이션한다 — 다섯씩 넷으로 나눠 커밋**

한 커밋에 20개를 넣으면 어느 것이 무엇을 깼는지 못 가른다.

```bash
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -12
```

를 **다섯 개마다** 돌린다. 문제 수가 단조 감소하지 않으면 직전 다섯이 새 문제를 만든 것이다.

```bash
git add plugins/<p>/agents/ plugins/<p>/skills/
git commit -m "feat(<p>): agent 입력 슬롯 선언 (L3, <n>/20)"
```

- [ ] **Step 5: dispatch 표기를 맞춘다**

`undeclared` / `var_mismatch` / `undelivered` 문제는 **양쪽 중 어느 쪽이 옳은지 판단**해서 고친다:

- `undeclared` — dispatch 가 선언에 없는 것을 전달한다. **대개 선언을 더하는 것이 맞다**(실제로 전달되고 있으므로). 단 그것이 금지 종류면 dispatch 쪽을 고친다.
- `undelivered` — 선언했는데 전달하는 dispatch 가 없다. **대개 `optional: true` 이거나 선언이 과했다.**
- `var_mismatch` — 이름이 갈렸다. **dispatch 쪽을 선언에 맞춘다**(선언이 계약이다).

- [ ] **Step 6: L3 가 GREEN 인지 확인한다 (M5)**

```bash
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -20
```

기대: `agents=20` · `no_declaration=0` · `problems_other=0` · `exempt_uncited=0` · `Fail: 0`.

**면제 목록 크기를 기록한다** — 그 수가 M8 의 입력이다.

- [ ] **Step 7: 기존 seed 락이 안 깨졌는지**

```bash
bash plugins/spec-distill/tests/test_seed_agents.sh 2>&1 | tail -8
bash plugins/spec-distill/tests/test_seed_one_sentence.sh 2>&1 | tail -5
```

Task 1 Step 8 이 예측한 충돌이 여기서 실현된다. **L3 를 빼지 않는다** — 충돌 자리를 `EXEMPT_SLOTS` 에 C6⑵ 로 등재하거나 기존 락을 「약화가 아닌 갱신」으로 고친다.

- [ ] **Step 8: bump + CHANGELOG + PR3**

건드린 플러그인 전부 bump.

```bash
git diff --name-only origin/main | cut -d/ -f2 | sort -u
git add plugins/ shared/adjudication/check_slots.py
git commit -m "feat(adjudication): 에이전트 스무 개의 입력 슬롯 선언 — L3 GREEN"
git push
```

---

## 검증 — 락이 실제로 이빨을 가졌는지

### Task 15: M6 락별 귀속 변이 + M9 seam 락 이빨

**M6 의 규칙** — 변이마다 **어느 락이 RED 여야 하는지 «미리» 적고** 실행한다. 다른 락도 함께 RED 인 것은 정상이다. **지정한 락이 GREEN 이면 실패다.**

**변이 목록을 임의로 고르지 않는다.** 각 락의 «단언»에서 도출한다 — 그것이 내 변이가 락의 전제를 공유하는 것을 막는 유일한 방법이다.

- [ ] **Step 1: 변이 전에 커밋한다**

```bash
git status --short
git rev-parse HEAD
```

**작업 트리가 깨끗해야 한다.** `git checkout --` 는 「내 마지막 변이」가 아니라 HEAD 로 되돌리므로, 미커밋 작업이 있으면 복원이 그것을 함께 지운다. 그리고 복원 후의 clean 은 성공처럼 보인다.

- [ ] **Step 2: 변이 목록을 각 락의 단언에서 도출한다**

`/tmp/adjtopo/mutations.md` 에 표로 쓴다. **네 축으로 흔든다** — 삭제·추가·반전·형태 변경. 삭제만 하면 「추가로 우회」가 안 보인다.

| # | 변이 | 축 | 어느 락이 RED 여야 하나 |
|---|---|---|---|
| μ1 | `synthesize_findings.py:310` 의 `ledger.reject(...)` 한 줄 **삭제** | 삭제 | **L1** |
| μ2 | 같은 자리의 `reject` 를 `accept` 로 **바꿈** | 형태 | 없음 — **L1 은 이것을 못 본다.** 처분 «종류」가 아니라 «유무」를 잰다. 이 μ 의 목적은 그 경계를 기록하는 것 |
| μ3 | `render()` 에서 `**배관 손실:**` 줄 **삭제** | 삭제 | **L2** |
| μ4 | `Ledger.report()["counts"]` 에 `"foo": 0` **추가** | 추가 | **L2** — 소비자가 새 키를 안 읽으므로 |
| μ5 | `check_wiring.EXEMPT` 에 인용 없는 항목 **추가** | 추가 | **L1** (`exempt_uncited`) |
| μ6 | agent 하나의 `input_slots:` **삭제** | 삭제 | **L3** (`no_declaration`) |
| μ7 | agent 하나의 `kind: task` → `kind: prior_verdict` | 반전 | **L3** (`forbidden_kind`) |
| μ8 | agent 하나의 `var: TASK` → `var: PRIOR_VERDICT` (kind 는 `task` 유지) | 형태 | **L3** (`suspect_var`) — (b)의 보조 축 |
| μ9 | 러너 하나의 `disclosure=` **삭제** | 삭제 | **L4** |
| μ10 | SKILL 하나에 `` `quality-gates:no-such` `` **추가** | 추가 | **T4-2** |
| μ11 | 훅의 `decision:"block"` 한 자리에서 처분 호출 **삭제** | 삭제 | **L1** + 훅 테스트 |
| μ12 | `test_skill_drop_notice_consumed.sh` 의 소비자 분기 **삭제** | 삭제 | **그 락 자신** (M9) |

- [ ] **Step 3: 양성 대조를 먼저 세운다**

**RED 도 그 자체로는 증거가 아니다.** 계측기가 고장 나서 무엇을 해도 RED 를 내는 것과 구별해야 한다. 각 변이 전에 **해당 락이 GREEN 인지** 확인한다:

```bash
bash shared/tests/test_adjudication_wiring.sh 2>&1 | tail -3
bash shared/tests/test_adjudication_consumed.sh 2>&1 | tail -3
bash shared/tests/test_agent_input_slots.sh 2>&1 | tail -3
bash shared/tests/test_runner_disposition.sh 2>&1 | tail -3
bash shared/tests/test_dispatch_name_defined.sh 2>&1 | tail -3
```

다섯 다 `Fail: 0` 이어야 시작한다. **하나라도 RED 면 그 락의 변이 결과는 무의미하다.**

- [ ] **Step 4: 변이를 하나씩 돌린다**

각 μ 마다:

```bash
# 1. 변이를 가한다 (수동 편집 또는 sed)
# 2. 지정한 락을 돌린다
bash shared/tests/<지정한 락>.sh 2>&1 | tail -5
# 3. 결과를 /tmp/adjtopo/mutations.md 에 적는다 (기대 / 실제)
# 4. 복원한다
git checkout -- <변이한 파일>
git status --short          # ← 비어야 한다
```

**매 복원 후 `git status --short` 가 비는지 확인한다.** 안 비면 변이가 다른 파일에도 닿은 것이다.

- [ ] **Step 5: μ2 의 결과를 락의 주석에 기록한다**

μ2(처분 «종류» 교체)가 어느 락도 RED 로 만들지 않는다면 **그것이 L1 의 경계**다. `test_adjudication_wiring.sh` 의 상단 주석에 한 줄로 적는다:

```bash
# 이 락은 처분의 «유무»를 재고 «종류」는 재지 않는다. reject 를 accept 로
# 바꾸면 통과한다 — 종류의 정합은 처분 행렬 테스트
# (quality-gates/tests/test_synthesize_disposition.sh) 가 잰다.
```

**측정하지 않은 것을 주장하지 않는다** — 이 계획이 상속한 설계의 규율이다.

- [ ] **Step 6: M9 — seam 락의 이빨 생존**

μ12 는 다른 것들과 성격이 다르다. Task 12 Step 4 가 `test_skill_drop_notice_consumed.sh` 를 **갱신**했으므로, 그 갱신이 약화가 아니었는지 별도로 잰다:

```bash
grep -n 'consumed\|notice' plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh | head -20
# 소비자 분기를 지운 뒤
bash plugins/quality-gates/tests/test_skill_drop_notice_consumed.sh 2>&1 | tail -5
git checkout -- plugins/quality-gates/
```

**기대: RED.** GREEN 이면 그 락은 갱신 과정에서 이빨을 잃었고, 그것이 리포에서 생산자–소비자 seam 을 재는 유일한 락이다.

- [ ] **Step 7: 결과를 문서로 남기고 커밋**

`/tmp/adjtopo/mutations.md` 를 `docs/superpowers/plans/2026-09-03-adjudication-topology-mutations.md` 로 옮긴다. **GREEN 이어야 할 것이 GREEN 이었던 μ 도 적는다**(μ2 처럼) — 경계의 기록이다.

```bash
git add docs/superpowers/plans/2026-09-03-adjudication-topology-mutations.md shared/tests/test_adjudication_wiring.sh
git commit -m "test(adjudication): 락별 귀속 변이 12건 — 기대와 실제, 그리고 L1 의 경계"
```

---

### Task 16: M7·M8·M10·M11·M12 — 최종 검증

- [ ] **Step 1: M7 — 도출 셋의 수**

```bash
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep -E '^union=|import=|anchor=|㉮'
bash shared/tests/test_runner_disposition.sh 2>&1 | grep '도출기 출력'
bash shared/tests/test_agent_input_slots.sh 2>&1 | grep 'agent 정의'
grep -E 'tests/spike/|detect_codex\.sh|runner_common\.sh' /tmp/adjtopo/codex-runners.txt
```

기대: ㉮ **5** (import 경로와 앵커 경로를 **따로** 기록 — 갈리면 회귀 신호) · ㉯ **6** · ㉰ **20**. 네 번째 명령은 **아무것도 출력하지 않아야 한다**(`tests/spike/`·`detect_codex.sh`·`runner_common.sh` 가 ㉯ 에 없다).

- [ ] **Step 2: M8 — 면제 목록 둘의 인용과 «크기»**

```bash
bash shared/tests/test_adjudication_wiring.sh 2>&1 | grep '면제 목록 크기'
bash shared/tests/test_agent_input_slots.sh 2>&1 | grep '면제 목록 크기'
```

인용 없는 항목은 0이어야 한다(락이 이미 잰다). **크기를 baseline 문서에 적는다** — ㉮ 네 파일의 `for` 문이 **39개**(F5)라 면제 팽창이 L1 의 유일한 이빨 리스크다. 다음 저자가 크기를 늘리면 그 커밋이 이유를 적어야 한다.

- [ ] **Step 3: M10 — 기존 락 전량 vs Task 1 의 baseline**

```bash
for t in shared/tests/test_*.sh; do
  printf '=== %s ===\n' "$t"; bash "$t" 2>&1 | tail -3
done > /tmp/adjtopo/final-shared.txt 2>&1
for t in plugins/quality-gates/tests/test_*.sh plugins/spec-distill/tests/test_*.sh; do
  printf '=== %s ===\n' "$t"; bash "$t" 2>&1 | tail -3
done > /tmp/adjtopo/final-plugins.txt 2>&1
diff /tmp/adjtopo/baseline-shared.txt /tmp/adjtopo/final-shared.txt
diff /tmp/adjtopo/baseline-plugins.txt /tmp/adjtopo/final-plugins.txt
```

**통과 조건: 신규 RED 0.** baseline 에 이름이 오른 선재 RED 는 그대로여도 된다. 새 락 다섯이 GREEN 으로 바뀐 것은 기대된 차이다.

- [ ] **Step 4: M11 — 결정론 fixture 로 처분 행렬**

```bash
bash plugins/quality-gates/tests/test_synthesize_disposition.sh 2>&1 | tail -12
```

기대: 여섯 처분(기각·억제·흡수·미판정·배관 손실·셀 수 없음)이 각각 최소 1건. **라이브 `/qg` 에 의존하지 않는다** — 이것이 M11 과 M12 를 나눈 이유다.

「셀 수 없음」이 fixture 에 안 나오면 `uncountable()` 을 부르는 자리가 없다는 뜻이다. **그것이 사실이면 fixture 를 조작하지 말고 그 사실을 Known gaps 에 적는다.**

- [ ] **Step 5: M12 — 라이브 `/qg` 한 번**

```
/qg
```

기대: 출력에 세 줄(`**Findings:**` · `**처분:**` · `**배관 손실:**`)이 렌더된다. **숫자는 0이어도 통과다** — 이 측정은 렌더 경로의 도달을 재지 값을 재지 않는다.

- [ ] **Step 6: 워크트리를 정리하고 최종 보고**

```bash
git status --short
git log --oneline origin/main..HEAD
git branch --show-current
```

브랜치가 `feature/adjudication-topology-unification` 인지, detached HEAD 가 아닌지 확인한다(변이 과정에서 checkout 을 여러 번 했다).

---

## 남은 사용자 판정 둘 — 계획이 정하지 않는다

설계 §13 이 사용자에게 올린 둘이고, **이 계획도 정하지 않는다.** 실행 중 해당 지점에서 다시 묻는다.

| # | 무엇 | 어디서 걸리나 | 뒤집으려면 |
|---|---|---|---|
| 1 | **RED 커밋이 `main` 의 조상이 된다** — 리포에 CI 가 없고 D6 이 실행자를 제외했으므로 막는 메커니즘이 없다 | Task 7 Step 8(PR1 을 여는 자리) | 「PR 을 쪼개지 말고 하나로」라고 말한다. 그러면 M1(락이 오늘 RED 였다는 증거)을 잃는다 |
| 2 | **C5 가 2/3만 달성된다** — 입력(L3)·회계(T1·L1·L2·T3)는 달성하고 **역할 축은 미달**이다. L4·T4·T5 는 선언·이름·회계이지 「비판자의 역할 구조 통일」이 아니다 | 계획 전체 | 「역할 축도 이 사이클에서」라고 말한다. 그러면 미해소 근거(brief §3 의 **OQ11~OQ19 아홉 건** — 방향성 리뷰의 미반영 지적) 위에 배치를 바꾸게 된다 |

---

## Known gaps — 이 계획이 «못 하는» 것

**이 절이 없으면 위의 GREEN 들이 실제보다 넓게 읽힌다.**

| # | 무엇 | 왜 |
|---|---|---|
| 1 | **판정자가 둘로 남는다** — `audit-workflow.js:492…596` 의 `degradedEvents` 는 JS 라 이 어휘 밖 | 설계 §8: JS 는 개념의 대응물을 갖췄고 없는 것은 심볼릭 링크다(C6⑵). drift 쌍 조건이 성립한다 |
| 2 | **자동 실행자가 없다** — 락 다섯을 아무도 안 돌릴 수 있다 | D6(사용자 결정) |
| 3 | **`disclosure=` 채널이 실제로 읽히는지 못 잰다** | 정적 검사 밖. L4 의 주석이 그 한계를 적는다 |
| 4 | **L1 은 「본문 끝까지 append 없음」을 안 본다** — 네 버리기 형태 중 하나 | 출력 컬렉션을 AST 로 신뢰성 있게 식별할 수 없다. 켜면 제자리 변형 루프가 전부 오탐 |
| 5 | **L1 은 컴프리헨션 필터를 «요구»하지 않는다** | 표현식에 문장을 못 넣는다(C6⑴). 개수 baseline(28)으로 증가만 잡는다 |
| 6 | **L1 은 처분의 «종류»를 안 본다** | Task 15 μ2 가 실측한다. 종류 정합은 처분 행렬 테스트가 잰다 |
| 7 | **L2 는 키가 파일에 «쓰였는지»만 본다** | 그 값이 stdout 까지 가는지는 정적으로 못 잰다 |
| 8 | **L3(b)는 이름과 `kind` 를 «함께» 속이면 통과한다** | 선언값 판정 + 변수명 휴리스틱이 전부. 완전한 ∀-지배관계가 아니다 |
| 9 | **축 A⑤** — `test_dispatch_disposition.sh` 는 코드가 7축, 문서가 6축이고 mutation 검증 0건 | 설계가 이월한 gap. 이 계획이 건드리지 않는다 |
| 10 | **정적 검사의 절대 경계** — 이름을 문자열 연결로 쪼개면 이 리포의 락도 새 락도 침묵한다 | 설계 §10 |
| 11 | **방향성 리뷰의 미반영 지적 — brief §3 의 OQ11~OQ19 아홉 건** | 축 교체가 단독 저자 preprint 하나에 기댄다. 설계 §8 의 C3·C5 행이 이것을 근거로 배치 변경을 보류한다 |

---

## 실행 순서 요약

| PR | Task | 산출 | 락 상태 |
|---|---|---|---|
| — | 1 | baseline · census · L1 판정기 초안 | — |
| **PR1** | 2 | `Ledger` 어휘 확장 | — |
| **PR1** | 3 | L1 락 | L1 **RED** |
| **PR1** | 4 | L2 락 | L2 **RED** |
| **PR1** | 5 | L4 락 | L4 **RED** |
| **PR1** | 6 | T4-2 락 (stale 이름이 살아 있을 때) | T4-2 **RED** |
| **PR1** | 7 | L3 락 + PR1 을 연다 | L3 **RED** |
| **PR2** | 8 | `synthesize_findings.py` 배선 | — |
| **PR2** | 9 | `synthesize_artifact_findings.py` 배선 | — |
| **PR2** | 10 | 처분 두 줄을 소비자 넷에 | L1·L2 **GREEN** |
| **PR2** | 11 | 훅 층 회계 | ㉮ 4→5 |
| **PR2** | 12 | stale 이름 제거 + 기존 락 갱신 + PR2 | T4-2 **GREEN** |
| **PR3** | 13 | 러너 여섯의 처분 선언 | L4 **GREEN** |
| **PR3** | 14 | 에이전트 스무 개의 슬롯 선언 + PR3 | L3 **GREEN** |
| — | 15 | 변이 12건 + seam 이빨 | 귀속 확인 |
| — | 16 | M7·M8·M10·M11·M12 | 최종 |
