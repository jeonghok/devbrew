---
name: project-init-git-strategy-faithfulness
type: design
created_at: 2026-07-05
session_id: bcccf21f-e46e-4fda-9596-61f585860349
source_brief: docs/superpowers/interview/2026-07-05-project-init-git-strategy-faithfulness-interview.md
next_phase: superpowers:writing-plans
plugin: project-init
version_bump: 1.6.0 -> 1.7.0   # minor — enforcement 동작 surface 변경
---

# project-init git-strategy enforcement faithfulness — Design

> Interview brief(`docs/superpowers/interview/2026-07-05-project-init-git-strategy-faithfulness-interview.md`)의
> 해답공간(Double Diamond 2nd diamond). Locked Directions LD1–LD6은 재논쟁하지 않는다.

## 1. Context / Why

`project-init`은 3개 브랜치 전략(GitHub Flow / Git Flow / Trunk-based)을 동등하게 제시하고,
각 전략 템플릿이 자기 브랜치 regex를 `docs/git-workflow/branch-strategy.md`에 인코딩한다.
enforcement hook `post-tool-use.py`는 `get_branch_pattern()`으로 그 regex를 **런타임에 읽어**
검증하므로 전략 지원 자체는 건전하다.

문제(root cause, brief §1)는 **enforcement 계층의 전략-불충실**이다 — hook이 프로젝트가
*선택하지 않은* GitHub Flow를 세 지점에서 단정한다:

- **F1** (`post-tool-use.py:19`) — `DEFAULT_BRANCH_PATTERN = ^(feature|fix)/…`. 전략 미선언 시
  이 폴백이 GitHub-Flow형으로 **silent 디폴트**해 Git Flow의 `release/*`·`hotfix/*`를 거부한다
  ("fail-toward-GitHub-Flow" anti-pattern — brief §3 authzed fail-open 근거).
- **F2** (`post-tool-use.py:102-105`) — `validate_branch` 교정 제안이 활성 전략과 무관하게 항상
  `feature/{name}`. Git Flow의 `hotfix-login` 오타에도 `feature/…`를 제안한다.
- **F3** (`templates/trunk-based/branch-strategy.md` Pattern B) — 템플릿이 `release/*` 예외를
  만들려 `DEVBREW_DISABLE_PROJECT_INIT=1`로 **hook 전체를 끄라**고 안내(commit 검증까지 함께
  꺼짐). 그러나 hook은 non-blocking이라 `release/*` 생성은 경고만 뜰 뿐 차단되지 않아 bypass가
  불필요하다.

`post-tool-use.py`는 **현재 테스트 전무**(brief OQ4) — F1/F2 코드 수정은 신규 테스트 하니스를
load-bearing 항목으로 요구한다.

## 2. Goals

1. enforcement가 **선택된 전략에 충실**해진다: 폴백·제안이 GitHub Flow를 단정하지 않는다.
2. 전략 미선언 시 **loud-advisory fail-open** — 검증을 건너뛰되 discoverable하게 알린다(LD2).
3. 교정 제안이 **활성 패턴에서 파생**된다(LD4) — `feature/` 하드코딩 종료.
4. trunk 템플릿이 **hook의 non-blocking 성격을 정직하게** 안내하고 kill-switch 우회를 제거(LD5).
5. `post-tool-use.py`가 **테스트로 보호**된다(OQ4) — F1/F2 회귀 방지.

## 3. Non-goals (LD1 / OQ1 — 재논쟁 금지)

- **F4** (merge-전략 런타임 강제) & **F5** (base-branch 규율 강제) 신규 결정론 가드 추가 —
  devbrew "harness lightness — trust the model" 기준으로 **명시적 defer**. 후속 사이클이 lightness
  bar를 통과시킬 때만 재검토(OQ1). 이 작업으로 유추하지 않는다.
- 3전략 지원 설계 재고 — 감사 결과 편향이 hook에 국소화됐고 설계는 건전(Tried & Discarded).
- hook을 blocking(PreToolUse deny)으로 승격 — advisory 성격 유지가 LD3.
- 서버측 강제(GitHub rulesets) 문서화 신규 작업 — 이미 `shared/pr-process.md`가 정직히 인정.

## 4. Constraints

- **advisory hook 유지**(LD3) — PostToolUse, 항상 `sys.exit(0)` + `systemMessage`. blocking 아님.
- **kill switch 불변**(devbrew) — `DEVBREW_DISABLE_PROJECT_INIT=1` / `DEVBREW_SKIP_HOOKS=project-init:post-tool-use`.
- **commit 검증 경로 회귀 없음** — `validate_commit` **함수 내부 로직은 불변**(호출 빈도는 §5.5에서 개선 — compound 명령에서 branch 경고와 무관하게 실행됨).
- **신규 워크트리에서 구현**(LD6) — `feature/git-strategy-faithfulness` (이미 생성됨).
- **plugin.json bump 동반**(devbrew) — 같은 PR에서 `1.6.0 → 1.7.0`(minor).
- **문서 Korean-primary**(devbrew) — CHANGELOG/README 동기화.
- 테스트 실행은 `python3 -m unittest`(repo 관례) — 직접 실행은 vacuous.

## 5. Design

### 5.1 F1 — loud-advisory fail-open 폴백 (`post-tool-use.py`)

`get_branch_pattern()`의 반환 계약을 `re.Pattern` → **`Optional[re.Pattern]`**으로 바꾼다.
아래 넷을 **하나의 fail-open 경로로 통일**해 `None`을 반환한다:

1. `branch-strategy.md` 파일 부재,
2. ```regex 블록 부재,
3. **regex 자체가 malformed**(`re.error`) — 오늘은 silent하게 GitHub-Flow로 떨어졌으나 이제 loud,
4. **```regex 블록이 비었거나 공백-only**(`.strip()` 후 empty) — 퇴화 패턴이 *모든* 브랜치명을 silent pass-all 하지 않도록 fail-open(reviewer cccfc098).

`DEFAULT_BRANCH_PATTERN`(line 19)은 **완전 삭제**(OQ2 해소). 폴백이 `None`을 반환하면 호출자가
0이 되어 dead code이며, 남겨두면 GitHub-Flow 디폴트가 잔존한다. lightness → 삭제.

```python
def get_branch_pattern():
    """Return the declared branch pattern, or None when none is validly declared.

    None => fail-open: 전략 미선언 → 브랜치명 검증을 건너뛴다(loud advisory).
    """
    project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
    strategy_path = os.path.join(project_dir, "docs", "git-workflow", "branch-strategy.md")
    try:
        with open(strategy_path, "r") as f:
            content = f.read()
        match = re.search(r"```regex\n(.+?)\n```", content)
        if match and match.group(1).strip():   # 빈/공백-only 캡처 → 무효(fail-open, reviewer cccfc098)
            return re.compile(match.group(1).strip())
    except (FileNotFoundError, IOError, re.error):
        pass
    return None
```

`validate_branch()`의 검증 분기:

```python
pattern = get_branch_pattern()
if pattern is None:                       # 유효 패턴 없음(부재/regex-less/malformed) → fail OPEN, loudly
    return ("project-init: no valid branch-naming pattern found in "
            "docs/git-workflow/branch-strategy.md — skipping branch-name "
            "validation (fail-open).")
if pattern.match(branch_name):
    return None
# else → 5.2 F2 suggestion
```

**한 줄** discoverable 안내(파일 경로 + 무엇을 건너뛰는지 명시). 거부 아님. **OQ3 해소:**
`pr-process.md` cross-reference **없음** — LD2가 *한 줄*을 지정하고, 서버측 강제는 `pr-process.md`가
독립적으로 문서화하므로 cross-ref는 lightness가 거부하는 bloat.

> **Fail-open의 loud 성격(설계 의도):** 브랜치 생성마다 안내가 뜨는 건 전략 미선언이라는 edge
> case(플러그인 미실행/파일 삭제)에서만이다 — 정상 project-init 리포는 항상 전략을 선언한다.
> "조용히 GitHub Flow로 검증"보다 "시끄럽게 검증 생략"이 fail-open 원칙에 충실(brief §3).

### 5.2 F2 — 활성 패턴 파생 제안 (`post-tool-use.py`)

신규 헬퍼 `derive_prefixes(pattern)` — regex 소스의 **선두 identifier-alternation 그룹**에서 허용
prefix를 추출한다. **"exotic"의 구체 정의**: 선두가 `^(` 또는 `^(?:` 직후 identifier-alternation
(`[a-z][a-z0-9-]*` 토큰을 `|`로 이은 것)이 *아닌* 모든 것 — inline flags(`(?i)`), nested group
(`^((?:a|b))/`), 리터럴 접두(`^feature-.*`) 등. 이 경우 `[]`로 강등(제안에서 prefix 하드코딩 금지).
그룹 내용을 regex로 못박으므로 별도 token 검증은 불필요:

```python
def derive_prefixes(pattern):
    """Extract allowed branch prefixes from a compiled pattern's leading alternation group.

    ^(feature|fix|release|hotfix)/…  ->  ["feature","fix","release","hotfix"]
    ^(?:feature|fix)/…               ->  ["feature","fix"]   (non-capturing OK)
    선두가 identifier-alternation이 아니면(inline flags (?i), nested group, 리터럴 등) → []
    (교정 제안에서 prefix 하드코딩 금지). 그룹 내용을 [a-z][a-z0-9-]* 토큰의 |-결합으로
    못박아 `(?i)` 같은 flag 그룹이 "i" 프리픽스로 오파싱되지 않게 한다(reviewer a909f052).
    """
    m = re.match(r"\^?\((?:\?:)?([a-z][a-z0-9-]*(?:\|[a-z][a-z0-9-]*)*)\)", pattern.pattern)
    return m.group(1).split("|") if m else []
```

교정 제안(현행 line 102-105 `feature/{name}` 하드코딩 대체):

```python
name_part = branch_name.split("/", 1)[1] if "/" in branch_name else branch_name
prefixes = derive_prefixes(pattern)
if prefixes:
    hint = f"Allowed prefixes: {', '.join(prefixes)}"
    cmd = f"Rename with: git branch -m <prefix>/{name_part}   (choose a prefix above)"
else:                                     # exotic regex → NO feature/ 하드코딩
    hint = "See docs/git-workflow/branch-strategy.md for allowed prefixes."
    cmd = None

lines = [
    f'project-init: Branch "{branch_name}" does not follow naming convention.',
    f"Expected pattern: {pattern.pattern}",
    hint,
]
if cmd:
    lines.append(cmd)
return "\n".join(lines)
```

Git Flow(`^(feature|fix|release|hotfix)/…`)에서 `hotfix-login` 입력 시 출력:

```
project-init: Branch "hotfix-login" does not follow naming convention.
Expected pattern: ^(feature|fix|release|hotfix)/[a-z0-9][a-z0-9.-]*$
Allowed prefixes: feature, fix, release, hotfix
Rename with: git branch -m <prefix>/hotfix-login   (choose a prefix above)
```

`<prefix>`는 **플레이스홀더**(단일 prefix를 강제하지 않음) — 사용자/모델이 허용 집합에서 고른다.
이것이 F2의 핵심: 어떤 단일 prefix도 하드코딩하지 않아 Git Flow hotfix 오제안이 끝난다.

### 5.3 F3 — doc-only trunk 템플릿 (`templates/trunk-based/branch-strategy.md`)

**코드 변경 0.** trunk 템플릿은 이미 `^(feature|fix)/…`를 선언하므로 `release/*`는 정확히 밖이며
hook이 F2 경로로 **다중 줄** advisory(허용 prefix `feature`/`fix` 제시)를 낸다 — fail-open 한 줄이
*아님*(declared-pattern 위반이라 §5.2 경로; reviewer 36168703). 차단 아님. Pattern B 노트(line 88-94)에서
`DEVBREW_DISABLE_PROJECT_INIT=1` 우회를 **제거**하고 non-blocking 성격을 정직히 설명:

- 삭제: line 88의 kill-switch 우회 문장 + line 94의 `DEVBREW_DISABLE_PROJECT_INIT=1 git checkout -b release/v1.x`.
- 대체 문구(예):

  > **Note:** `release/*`는 이 strategy의 regex(`^(feature|fix)/…`) 밖이라 hook이 **advisory
  > 경고**(허용 prefix `feature`/`fix`를 제시하는 다중 줄 메시지 — 이 전략엔 관용 없는 예외)를
  > 냅니다. 단, project-init hook은 **non-blocking**(PostToolUse advisory)이라 브랜치 생성을
  > **차단하지 않습니다** — 의도된 backport 예외이므로 경고를 무시하고 진행하세요. hook 전체를
  > 끄지 마세요(commit 검증까지 함께 꺼집니다).

- line 91-94의 코드 블록은 `git checkout -b release/v1.x`(kill-switch 없이)로 단순화.

### 5.4 컴포넌트 경계

- `get_branch_pattern()` — 순수 read: (env, 파일) → `Optional[re.Pattern]`. fail-open 판정 단일 지점.
- `derive_prefixes(pattern)` — 순수 함수: `re.Pattern` → `list[str]`. 독립 테스트 가능.
- `validate_branch(command)` — 조합: 위 둘 + 메시지 빌드. side-effect 없음(문자열 반환).
- `main()` — combination 로직만 변경(§5.5): `or` short-circuit → 두 검증기 실행+concatenate.
- `validate_commit` / `kill_switch_active` — **불변**(회귀 가드 대상).

### 5.5 `main()` 이중 검증 (compound 명령 commit 회귀 봉쇄)

현행 `main()`은 `warning = validate_branch(command) or validate_commit(command)` — branch 경고가
있으면 commit 검증이 short-circuit된다. F1 fail-open이 *모든* branch-create에 advisory를 반환하면서
`git checkout -b feature/x && git commit -m "feat: x"` 같은 compound 명령에서(전략 미선언 시) commit
검증이 **항상** 건너뛰어지는 빈도-증가 회귀가 생긴다(reviewer e65cae85 — pre-change엔 브랜치명이
*실제 위반*일 때만 short-circuit). 두 검증기를 **모두 실행**하고 경고를 concatenate해 short-circuit을
제거한다(pre-existing 잠재 회귀도 함께 해소):

```python
warnings = [w for w in (validate_branch(command), validate_commit(command)) if w]
if warnings:
    print(json.dumps({"systemMessage": "\n\n".join(warnings)}))
else:
    print(json.dumps({}))
```

non-blocking·advisory 성격 불변(둘 다 warning 문자열만 반환). 검증 커버리지는 넓어질 뿐 좁아지지 않음.

## 6. Files to Modify

| 파일 | 변경 | Finding |
|---|---|---|
| `plugins/project-init/hooks/post-tool-use.py` | `DEFAULT_BRANCH_PATTERN` 삭제; `get_branch_pattern`→Optional; `derive_prefixes` 신규; `validate_branch` fail-open+파생 제안; `main()` 이중 검증(§5.5) | F1, F2, e65cae85 |
| `plugins/project-init/templates/trunk-based/branch-strategy.md` | Pattern B 노트 doc-only 재작성(kill-switch 우회 제거) | F3 |
| `plugins/project-init/hooks/tests/test_post_tool_use.py` | **신규** 테스트 하니스 | OQ4 |
| `plugins/project-init/.claude-plugin/plugin.json` | `version` `1.6.0` → `1.7.0` | — |
| `plugins/project-init/CHANGELOG.md` | `## [1.7.0] — 2026-07-05` 엔트리 | — |
| `plugins/project-init/README.md` | "## 설치된 Hook"의 `post-tool-use` 줄(현재 "브랜치 명·커밋 메시지 검증")을 fail-open advisory 성격으로 동기화 | — |

## 7. Verification Plan (OQ4 — load-bearing)

신규 `hooks/tests/test_post_tool_use.py` — `unittest.TestCase`, `python3 -m unittest`로 실행,
hyphen 파일명이라 `importlib.util.spec_from_file_location`로 모듈 로드(`test_docs_lint.py` 미러).
임시 `CLAUDE_PROJECT_DIR`(tempdir)에 전략 파일을 놓고 검증.

| 그룹 | 케이스 |
|---|---|
| **F1 fail-open** | (a) 파일 부재 → `get_branch_pattern()==None` + fail-open advisory("skipping"/"fail-open") 거부 아님 (b) regex-less 파일 → 동일 (c) malformed regex → 동일 (d) 선언된 git-flow regex → `release/x` **통과**(None) (e) **빈/공백-only ` ```regex ` 블록 → None(fail-open), 임의 브랜치 silent pass-all 아님**(reviewer cccfc098) |
| **F1 회귀 락** | `DEFAULT_BRANCH_PATTERN` 심볼 부재 assert(`assertFalse(hasattr(mod, "DEFAULT_BRANCH_PATTERN"))`) — silent 재도입 방지 teeth |
| **F2 파생** | `derive_prefixes`: github-flow→`[feature,fix]` / git-flow→`[feature,fix,release,hotfix]` / 비캡처 `^(?:feature\|fix)/…`→`[feature,fix]` / **inline-flag `(?i)^(feature\|fix)/…`→`[]`**(reviewer a909f052) / nested `^((?:a\|b))/…`→`[]` / 리터럴 `^feature-.*`→`[]`. git-flow 위반 브랜치 → advisory가 `release,hotfix` 나열 **AND `feature/<name>` 하드코딩 부재**. exotic → `feature/` 부재 + 문서 안내 |
| **main() 이중 검증** | fail-open 상태 compound `git checkout -b feat && git commit -m "add x"` → branch fail-open advisory **AND** commit(Conventional 위반) advisory가 **둘 다** 출력(commit 검증 미-skip; reviewer e65cae85); 정상 전략 compound에서도 두 검증기 독립 실행 |
| **보존 동작** | protected(`main`) skip; 유효 브랜치 → None; conventional-commit pass/fail 불변; kill switch(subprocess); 비-Bash tool skip; malformed stdin JSON → `{}` |

- 순수 함수(`get_branch_pattern`/`derive_prefixes`/`validate_branch`/`validate_commit`)는 직접 unit.
- e2e 2건(kill switch + `main()` stdin 경로)은 subprocess로 hook 스크립트 실행.
- 기존 `smoke.sh`·`test_docs_lint.py` 회귀 없음(docs-lint 미변경).
- 병합 전 `/qg` Review + Runtime 게이트.

## 8. Acceptance Criteria

- **AC1** — `branch-strategy.md` 부재/regex-less/malformed/**빈-or-공백-only regex 블록** 시 `validate_branch`가 브랜치명을 거부하지 않고 fail-open 한 줄 advisory를 반환(F1/LD2; 빈-블록 silent pass-all 방지, reviewer cccfc098).
- **AC2** — `DEFAULT_BRANCH_PATTERN` 심볼이 `post-tool-use.py`에서 완전 제거(OQ2).
- **AC3** — 선언된 전략 regex는 그대로 존중(git-flow `release/*` 통과, github-flow `feature/*` 통과) — 회귀 없음.
- **AC4** — 위반 브랜치 교정 제안이 활성 패턴 파생 prefix를 나열하고 `feature/` 단일 하드코딩이 없음(F2/LD4); Git Flow hotfix에 `feature/` 오제안 없음.
- **AC5** — exotic regex(inline flags `(?i)`, nested group, 리터럴 접두 등)에서 `derive_prefixes`가 `[]`를 반환하고 제안이 `feature/`를 하드코딩하지 않고 문서로 강등 — `(?i)…`→`[]` 구체 테스트 포함(reviewer a909f052).
- **AC6** — trunk 템플릿 Pattern B에서 `DEVBREW_DISABLE_PROJECT_INIT=1` 우회 안내 제거 + non-blocking·**다중 줄 advisory** 성격 정확 명시(F3/LD5, reviewer 36168703).
- **AC7** — `validate_commit` / kill switch / non-Bash skip / malformed-JSON 경로 회귀 없음.
- **AC8** — 신규 `test_post_tool_use.py`가 §7 매트릭스를 커버하고 `python3 -m unittest` green.
- **AC9** — `plugin.json` `1.7.0`, `CHANGELOG.md` [1.7.0] 엔트리, README "## 설치된 Hook" `post-tool-use` 줄 동기화.
- **AC10** — compound 명령(`git checkout -b … && git commit -m …`)에서 두 검증기가 모두 실행돼 branch advisory가 commit 검증을 short-circuit하지 않음(§5.5, AC7 fail-open 회귀 봉쇄, reviewer e65cae85).

## 9. Rejected Alternatives

- **F2 파생 = 템플릿에 명시적 `prefixes:` 필드 추가(Option B)** → 버림: 신규 템플릿 surface + 새 parse
  타깃 + 이미 생성된 모든 `branch-strategy.md` 마이그레이션 필요. regex 선두 그룹 파싱(Option A)이
  template surface 0으로 lightness에 부합하고 기존 파일에 self-heal.
- **F2 = pattern-echo만, 구체 rename 제거(Option C)** → 버림: `feature/` 제거는 되나 도움되는
  nudge(허용 prefix 목록 + `git branch -m` 템플릿)를 잃어 UX 후퇴.
- **hook 축소/제거(brief §4 steelman)** → 버림: R3 게이트 defended. agentic 루프에서 `systemMessage`는
  human이 무시하는 noise가 아니라 LLM이 self-correct하는 신호. 헌장이 enforcement substrate로 확립.
- **F4/F5 전면 하드닝** → 버림(§3 Non-goals, OQ1): 신규 결정론 가드 증식이 lightness와 충돌.
- **F1 세 원인(부재/regex-less/malformed)을 구분된 메시지로 분기** → 버림(stated decision, reviewer 94d5d6b5): LD2가 *한 줄* discoverable 안내를 지정. 셋 다 "선언된 유효 패턴 없음"으로 귀결이 동일하고, 메시지가 파일 경로(`docs/git-workflow/branch-strategy.md`)를 명시하므로 malformed regex도 사용자가 찾아 고칠 수 있다. 별도 malformed 분기는 코드 branch만 늘릴 뿐 lightness 대비 이득이 낮다. "no *valid* pattern found" 문구로 세 경우를 모두 정확히 커버(§5.1).
- **`main()` short-circuit 유지 + None-pattern 경로만 commit-check 예외** → 버림(reviewer 권고 반영): `or` short-circuit을 남기고 fail-open 경로만 특수 처리하는 대안은 분기 복잡도만 늘린다. 두 검증기를 무조건 실행+concatenate(§5.5)가 더 단순하고 커버리지도 균일하게 넓다.

## 10. Handoff Context

### TL;DR
project-init enforcement hook을 선택된 git 전략에 충실하게 만든다: **F1** fail-open 폴백(전략 미선언
시 GitHub-Flow 단정 대신 loud advisory), **F2** 활성-패턴 파생 제안(`feature/` 하드코딩 제거), **F3**
trunk 템플릿 doc-only 정직화, **main() 이중 검증**(compound 명령 commit 검증 회귀 봉쇄), 신규
`test_post_tool_use.py`, `plugin.json` 1.6.0→1.7.0.

### Implicit context (writing-plans가 알아야 할 것)
- 구현은 워크트리 `feature/git-strategy-faithfulness`에서(이미 생성, base 00415d9). 서브에이전트 매
  Edit 지시에 **워크트리 절대경로 명시**(main-repo 동명 파일 drift 방지 — memory 선례).
- `post-tool-use.py`는 PostToolUse **advisory**(항상 exit 0). blocking 승격 금지(LD3).
- 테스트는 worktree root에서 `python3 -m unittest`(직접 실행=vacuous). hyphen 파일명 → `importlib`
  로드(`test_docs_lint.py` 미러).
- 매 PR이 `plugin.json` bump 동반(1.6.0→1.7.0 minor) — **같은 커밋**.
- git **merge over rebase**; 서브에이전트 **순차**(병렬·투기 dispatch 금지).

### Deferred to plan (writing-plans가 결정)
- Task 분해·순서(TDD 권장: 실패 테스트 먼저 → F1/F2/main fix → green).
- 커밋 분할 granularity.
- README "## 설치된 Hook" `post-tool-use` 줄의 정확한 wording.

## 11. Metadata

- **Plugin:** project-init `1.6.0 → 1.7.0` (minor — enforcement 동작 surface 변경).
- **Branch:** `feature/git-strategy-faithfulness` (worktree, LD6).
- **Law 1** — 이 design은 구조 게이트(Context/Why … Handoff Context) 충족. **Law 2** — `spec-distill:spec-reviewer`
  (write-blocked)가 이 doc을 adversarial 리뷰(writer 턴 self-approval 불가; round 1 `needs_revise` 5건 반영). **Law 3** — 버그가
  리뷰를 탈출하면 잡았어야 할 reviewer/persona가 아니라 **테스트 부재**가 근인 → `test_post_tool_use.py`가
  compounding substrate.
- **Reference:** brief `docs/superpowers/interview/2026-07-05-project-init-git-strategy-faithfulness-interview.md`.
