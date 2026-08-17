# project-init 감사 하니스 구현 계획 (§14 프로토타입 갭 + 신규 검증 스크립트)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** project-init 읽기전용 6축 감사를 *실행 가능하게* 만드는 하니스를 완성한다 — 커밋된 프로토타입의 §14 갭 16건을 닫고, 미작성 검증 스크립트 4개를 저술하며, 각 수정을 mutation test로 증명한다.

**Architecture:** 감사자는 Bash 없는 로컬 에이전트(`.claude/agents/*.md`)이고, orchestrator(메인 루프)가 evidence pack 조립·codex 실행·무결성 스냅샷·조립·검증·렌더·커밋을 한다. Workflow 스크립트(`audit-workflow.js`)는 *발견만* 반환하고, 파이프라인 밖의 결정론 스크립트(`check-*.py/.sh`·`validate-audit-data.py`·`render-audit-report.py`)가 게이트를 건다. 이 계획은 그 스크립트들만 손대며 **`plugins/**`는 한 줄도 바꾸지 않는다.**

**Tech Stack:** Python 3.9 (`unittest`), Node 25 (`node --test`, `node:test`), bash 3.2, git. 검증 스크립트는 순수 파일시스템/정적분석 — 에이전트 0개.

**진리원천:** `docs/superpowers/specs/2026-07-12-project-init-audit-workflow-design.md` (커밋 HEAD `310a9a4`). **프로토타입 코드를 신뢰하지 말고 §14 표 + 수정된 설계 문면으로 재도출·검증하라.**

## Global Constraints

- **`plugins/**`·`quality-gates`를 한 줄도 수정하지 않는다** (읽기전용 감사 하니스; 설계 §14). 따라서 이 PR에 **어떤 `plugin.json` version bump도 불필요**하다 (bump 규칙은 "플러그인을 건드리는 PR"에만 적용).
- **각 코드 갭 수정은 mutation test로 이빨을 증명한다**: 결함을 재도입 → **RED**, 정상 → **GREEN**. GREEN만으로는 theater다 (설계 C11 · [[feedback_grep_lock_header_satisfiable]]).
- **테스트는 tempdir로 격리한다.** git을 쓰는 테스트는 `tempfile.mkdtemp()` 안에 `git init`한 fixture repo에서만 돌린다 — **실제 리포에 어떤 git 변경 명령도 내리지 않는다** (fixture live-repo 위험, qg 교훈).
- **Python 테스트는 `python3 -m unittest`로만 실행한다** — 직접 실행은 vacuous (memory: spec-distill test runner). **리포 root에서 실행한다** (리포 교훈).
- **생성 파일 read는 `encoding="utf-8"` 명시** (non-UTF-8 locale에서 한글 파일 fail-open 방지; memory: explicit-utf8-korean-primary).
- **문서·산출물은 Korean-primary** (설계 C8): 영어는 식별자·고유명사·원문 인용·번역 어색한 기술 용어에만.
- **안전 도구 집합** = `{Glob, Grep, Read, WebSearch, WebFetch}` — 감사 에이전트 3종의 `tools:` allowlist는 이 부분집합이어야 한다 (Law 2, 설계 §5.2).
- **주입 표면은 정확히 셋** (설계 §14): ① `audit-workflow.js`의 `CONTRACT`·`STEELMAN`·`AXES`·`findPrompt`·`refutePrompt`, ② codex 프롬프트, ③ `.claude/agents/{plugin-auditor,audit-refuter,smoke-probe}.md`. 이 셋에 **판정을 주입하지 않는다** — 주장 + `file:line`만 (설계 C6).

---

## File Structure

**수정 (커밋된 프로토타입 — §14 갭):**
- `scripts/audit-workflow.js` — Workflow 스크립트. rows 1·2·3·4·5·6·7·13·14·15. self-contained (Workflow 도구가 `import` 못 함 — top-level `await`/`return`).
- `scripts/check-law2.py` — Law 2 정적 게이트. rows 11·15.
- `scripts/check-integrity.sh` — 무결성 매니페스트. rows 9·10.
- `scripts/check-no-verdict-injection.py` — 판정-주입 게이트. row 12.
- `.claude/agents/audit-refuter.md` — refuter persona. rows 1(:75)·13(:36).

**신규 (미작성 — 각 test 동반):**
- `scripts/check-staleness.py` — 결정론 staleness sweep (§5.4a). 8 사실 클래스. 에이전트 0개.
- `scripts/smoke-workflow.js` — 1-에이전트 capability 스모크 미니 workflow (§16 · r14).
- `scripts/validate-audit-data.py` — `--data`(완결성·consent·codex 병합·cross-model·NOQ·gate-E) + `--artifacts`(파일 검사). rows 8·16의 이빨.
- `scripts/render-audit-report.py` — JSON → 마크다운 (골든 픽스처 테스트, §16·§11).

**신규 테스트 디렉토리:** `scripts/tests/`
- `scripts/tests/_wf_harness.mjs` — 공유 Node 하니스: Workflow 스크립트를 stub globals로 실행.
- `scripts/tests/audit-workflow.test.mjs` · `scripts/tests/smoke-workflow.test.mjs` — Node (`node --test`).
- `scripts/tests/test_check_law2.py` · `test_check_integrity.py` · `test_check_no_verdict_injection.py` · `test_check_staleness.py` · `test_validate_audit_data.py` · `test_render_audit_report.py` — Python (`python3 -m unittest`).

**런타임 산출물 (이 계획에서 만들지 않음 — orchestrator가 RUN에서 생성):** `docs/audits/*.json`·`*.md`·`*.jsonl`·`README.md`, `CLAUDE.md` 포인터 1줄. `.gitignore`의 `.claude/agents/` 재포함은 **이미 커밋됨** (확인: `.gitignore:214-220`).

**Rows 8·16 (post-1 orchestrator, 미작성):** 조립은 메인 루프가 설계 §6 post-1 런북을 따라 RUN 중에 수행한다. 이 두 갭의 **이빨은 `validate-audit-data.py --data`가 담당**한다 (Task 10) — row 16(backfill)은 완결성 검사가, row 8(gate-E→NOQ)은 scope-out NOQ 카운트 검사가 강제한다.

---

## Task 1: check-no-verdict-injection.py — BANNED를 §16과 동기화 (row 12)

**Files:**
- Modify: `scripts/check-no-verdict-injection.py:42-53` (`BANNED` 리스트)
- Test: `scripts/tests/test_check_no_verdict_injection.py` (신규)

**Interfaces:**
- Consumes: 없음 (게이트는 self-contained).
- Produces: `check-no-verdict-injection.py`는 CLI. exit 0=GREEN, 1=RED. `BANNED`에 `철회(됨|됐|된다)`·`사실 오류`·`다시 열지 마` 세 패턴이 추가돼 있어야 한다.

**근거 (설계 §14 row 12 · §16 line 1659):** 현재 `BANNED`(코드 line 43-53)는 r13 스포일러 계열만 잡고, **per-lead 판정 문구**(D2 *"이미 철회됨"* · D4 *"주장은 철회됨"* · *"사실 오류"* · *"다시 열지 마라"*)를 놓친다. `이미\s*철회`로 앵커하면 D4의 *"주장은 철회됨"*을 놓치므로 **bare `철회(됨|됐|된다)`**로 잡는다 (codex #1). `결함이다`·`정답`은 주입 표면에 정당한 실등장이 있어 bare로 넣지 않는다 (§16 line 1666-1673).

- [ ] **Step 1: 실패 테스트 작성** — `scripts/tests/test_check_no_verdict_injection.py`

```python
import subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "check-no-verdict-injection.py"


def run_gate(*extra_surfaces):
    """게이트를 실행하고 (returncode, stderr)를 돌려준다."""
    r = subprocess.run(
        [sys.executable, str(SCRIPT), *extra_surfaces],
        capture_output=True, text=True, cwd=str(REPO),
    )
    return r.returncode, r.stderr


class TestBannedSync(unittest.TestCase):
    def _scan_temp(self, content):
        """임시 표면 파일 하나에 대해 게이트를 돌린다 (실제 리포 표면과 섞이지 않게 절대경로 인자로)."""
        with tempfile.TemporaryDirectory() as d:
            surf = Path(d) / "surface.md"
            surf.write_text(content, encoding="utf-8")
            r = subprocess.run(
                [sys.executable, str(SCRIPT), str(surf)],
                capture_output=True, text=True, cwd=str(REPO),
            )
            return r.returncode, r.stderr

    def test_cheolhoe_dwaem_is_caught(self):
        # D2 "이미 철회됨" 형태
        rc, err = self._scan_temp("- **D2** ❌ 이미 철회됨. 다시 열지 마라.\n")
        self.assertEqual(rc, 1, f"'철회됨'/'다시 열지 마'가 통과했다:\n{err}")

    def test_cheolhoe_bare_catches_d4_form(self):
        # D4 "주장은 철회됨" — '이미 철회' 앵커로는 놓치는 형태 (codex #1)
        rc, err = self._scan_temp("유출 메커니즘 주장은 철회됨 — 재귀 복사 아님.\n")
        self.assertEqual(rc, 1, f"D4 형태 '주장은 철회됨'을 놓쳤다:\n{err}")

    def test_sasil_oryu_is_caught(self):
        rc, err = self._scan_temp("최초 브리핑의 '존재하지 않는다'는 사실 오류다.\n")
        self.assertEqual(rc, 1, f"'사실 오류'가 통과했다:\n{err}")

    def test_clean_surface_is_green(self):
        # 주장 + 포인터만 — 판정 없음
        rc, err = self._scan_temp("- **D2** README:79가 'PR 생성 시 qg 트리거'를 주장한다. 훅 본문을 열어 판정하라.\n")
        self.assertEqual(rc, 0, f"중립 문면이 FP로 잡혔다:\n{err}")

    def test_real_surfaces_are_green(self):
        # 커밋된 실제 주입 표면 3종에 판정 주입이 남아 있지 않다 (Task 2 이후 유지되는 회귀 락)
        rc, err = run_gate()
        self.assertEqual(rc, 0, f"실제 주입 표면에 판정이 새어 있다:\n{err}")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `python3 -m unittest scripts.tests.test_check_no_verdict_injection -v`
Expected: `test_cheolhoe_dwaem_is_caught`·`test_cheolhoe_bare_catches_d4_form`·`test_sasil_oryu_is_caught` FAIL (현재 BANNED가 이 세 형태를 안 잡음). `test_real_surfaces_are_green`은 Task 2 전이므로 audit-workflow.js에 아직 판정이 있어 FAIL일 수 있음 — Task 2에서 GREEN 전환됨.

> ⚠️ **실행 전 `scripts/tests/__init__.py`가 필요하다** (unittest가 `scripts.tests`를 패키지로 인식). Step 1에서 함께 만든다: `touch scripts/tests/__init__.py` + `scripts/__init__.py`가 없으면 `python3 -m unittest discover -s scripts/tests -t .` 형식으로 실행. **권장 실행식**: `python3 -m unittest discover -s scripts/tests -t . -v` (root에서).

- [ ] **Step 3: 최소 구현** — `scripts/check-no-verdict-injection.py`의 `BANNED`에 세 패턴 추가

```python
BANNED = [
    (r"이미\s*\d*\s*건?\s*중?\s*\d*\s*건?의?\s*전제가\s*틀렸", "D 단서의 판정을 미리 준다"),
    (r"전제가\s*이미\s*틀", "D 단서의 판정을 미리 준다"),
    (r"세\s*번\s*틀렸", "base-rate 앵커 — 판정을 withdrawn 쪽으로 민다"),
    (r"정면으로\s*겹친", "OQ3의 답을 미리 준다 (결론이지 사실이 아니다)"),
    (r"가장\s*값진\s*발견", "판정을 특정 방향으로 민다"),
    (r"낡음의\s*가장\s*큰\s*후보", "판정을 특정 방향으로 민다"),
    (r"재발견\s*금지", "재갈 — 감사자를 구조적으로 눈멀게 한다"),
    (r"반대\s*권고\s*금지", "재갈 — 구 C10의 형태"),
    (r"조건\s*\(?[a-d]\)?는?\s*미충족", "steelman 조건 판정을 대신 내린다"),
    # r15 — per-lead 판정. bare `철회`로 D2 "이미 철회됨" + D4 "주장은 철회됨" 양쪽을 잡는다
    # (`이미 철회` 앵커는 D4를 놓친다, codex #1). `결함이다`/`정답`은 주입 표면에 정당한 실등장이
    # 있어 bare로 넣지 않는다 (§16 line 1666-1673).
    (r"철회(됨|됐|된다)", "D 단서의 판정(철회)을 미리 준다"),
    (r"사실\s*오류", "D1 단서의 판정(사실 오류)을 미리 준다"),
    (r"다시\s*열지\s*마", "재갈 — settled 판정을 강제한다"),
]
```

- [ ] **Step 4: GREEN 확인** (Task 2 전이므로 `test_real_surfaces_are_green` 제외하고 확인)

Run: `python3 -m unittest scripts.tests.test_check_no_verdict_injection.TestBannedSync.test_cheolhoe_dwaem_is_caught scripts.tests.test_check_no_verdict_injection.TestBannedSync.test_cheolhoe_bare_catches_d4_form scripts.tests.test_check_no_verdict_injection.TestBannedSync.test_sasil_oryu_is_caught scripts.tests.test_check_no_verdict_injection.TestBannedSync.test_clean_surface_is_green -v`
Expected: 4 PASS.

- [ ] **Step 5: mutation으로 이빨 증명** — 세 패턴을 임시로 제거하면 RED가 나는지 확인 (수동): 방금 추가한 세 줄을 주석 처리 → Step 4 재실행 → `test_*_is_caught` FAIL 확인 → 주석 복원 → GREEN. (자동 mutation은 test가 이미 담당 — 위 3개 assert가 곧 mutation guard다.)

- [ ] **Step 6: 커밋**

```bash
git add scripts/check-no-verdict-injection.py scripts/tests/test_check_no_verdict_injection.py scripts/tests/__init__.py
git commit -m "fix(audit): check-no-verdict-injection BANNED를 §16과 동기화 — 철회·사실 오류·다시 열지 마 (row 12)"
```

---

## Task 2: audit-workflow.js + audit-refuter.md — 판정 주입 전수 중립화 (row 1·13·15)

**Files:**
- Modify: `scripts/audit-workflow.js` — 판정 주입 8개 사이트 (:159·:162·:169-171·:187-199·:238·:277·:391-393) + row 13(:374) + row 15(:12-13 주석)
- Modify: `.claude/agents/audit-refuter.md:75` (row 1) · `:36` (row 13)
- Test: 없음 (검증 = Task 1의 게이트 GREEN + grep 회귀 락; 아래 Step에 grep 락 포함)

**Interfaces:**
- Consumes: Task 1의 강화된 `check-no-verdict-injection.py`.
- Produces: 주입 표면 3종에 D-단서 판정이 0건. D2가 후보 단서 목록/enum에 **복원**됨 (§8 item 5·6). 게이트 정합 문구가 "semantically aligned"/"의미 단위로 일치"로 변경.

**근거 (설계 §14 row 1 · §5.6 · §5.7 · C6):** r14는 §8에서 aggregate 스포일러만 지웠고, **per-lead 판정**이 `CONTRACT`·`AXES`·`refutePrompt`·persona에 흩어져 살아남았다. 두 독립 렌즈도 site-by-site로는 일부만 잡았다 — **D1–D5 전수 grep**이 필요했다. **D2를 settled 예시로 쓰지 말고 방법 원칙만 남긴다** (*"인덱스 말고 구현을 읽어라"*·*"타 컴포넌트 증거는 죽이지 마라"*는 D2 판정 없이 서술 가능). 게이트(row 12 BANNED)는 `철회` 계열만 잡으므로 나머지(`반증`·`그 실패였다`·영문 disproof·누락)는 **수동 중립화 + 독립 리뷰가 backstop**이다 (§16).

- [ ] **Step 1: CONTRACT 규칙 3 (`audit-workflow.js:159`) 중립화** — D1/D2 판정 예시 제거, 방법 원칙만

`old`:
```javascript
'   **이 구분은 load-bearing이다**: D1의 반증 증거는 리포 *밖*에, D2의 반증 증거는 LD5 *밖*에 있었다.',
```
`new`:
```javascript
'   **이 구분은 load-bearing이다**: 한 단서의 반증 증거가 리포 *밖*·LD5 *밖*에 있을 수 있다 — 그래서 읽기는 무제한이다.',
```

- [ ] **Step 2: CONTRACT 규칙 5 (`audit-workflow.js:162`) — D2 복원** (row 1 + row 2의 형제)

`old`:
```javascript
'5. **D1·D3·D4·D5는 후보 단서다 — 사실이 아니다.** 각 전제를 **직접 검증**하고 confirmed/withdrawn/',
```
`new`:
```javascript
'5. **D1·D2·D3·D4·D5는 후보 단서다 — 사실이 아니다.** 각 전제를 **직접 검증**하고 confirmed/withdrawn/',
```

- [ ] **Step 3: CONTRACT item 6 / C12 (`audit-workflow.js:169-171`) 중립화** — D2 답 누출 제거, 방법 원칙만

`old`:
```javascript
'6. **인덱스가 아니라 구현을 읽어라.** `hooks.json`·`marketplace.json`·description·목차·README 요약은',
'   **인덱스**다. 메커니즘의 존재/부재는 *그것을 구현하는 코드*를 열어 판정하라. **D2가 정확히 이',
'   실패였다**: hooks.json의 이벤트 목록엔 PR 트리거가 없지만 훅 *본문*의 정규식이 `gh pr create`를',
'   잡고 있었다. **인덱스는 때로 정반대를 시사한다.**',
```
`new`:
```javascript
'6. **인덱스가 아니라 구현을 읽어라.** `hooks.json`·`marketplace.json`·description·목차·README 요약은',
'   **인덱스**다. 메커니즘의 존재/부재는 *그것을 구현하는 코드*를 열어 판정하라. **인덱스는 때로',
'   정반대를 시사한다** — 이벤트 목록에 안 보이는 트리거가 훅 *본문*의 정규식엔 있을 수 있고, 그 반대도',
'   가능하다. 반드시 본문을 열어라.',
```

- [ ] **Step 4: CONTRACT 후보 단서 블록 (`audit-workflow.js:187-199`) — D1·D2·D4 중립화** (D2 복원 포함)

`old`:
```javascript
'- **D1** 미선언 의존성 + 조건부 유령 안내. `commit-commands`는 **실재하는 공식 플러그인**이다',
'  (최초 브리핑의 "존재하지 않는다"는 **사실 오류**). 주장되는 결함 두 겹: (a) README가 통합을',
'  광고하면서 prerequisites 섹션이 없다 (CLAUDE.md: "Silent coupling은 버그"), (b) `/commit-push-pr`',
'  권고가 `templates/shared/pr-process.md` 경유로 **사용자 프로젝트로 복제**된다.',
'- **D2** ❌ **이미 철회됨.** qg 훅 본문이 `gh pr create`를 정규식으로 잡는다 → README는 **참**.',
'  다시 열지 마라 (단 그 판정이 틀렸다는 증거를 찾으면 NOQ).',
'- **D3** marketplace description drift — `.claude-plugin/marketplace.json` vs `plugin.json`.',
'- **D4** 플러그인 폴더 오염 (파일 존재는 참, **유출 메커니즘 주장은 철회됨** — 템플릿은 파일명으로',
'  개별 지정해 읽지 재귀 복사하지 않는다). git-ignored 파일 3개가 실재한다. **severity는 네가 판정.**',
```
`new`:
```javascript
'- **D1** 미선언 의존성 + 조건부 안내 주장. README가 `commit-commands` 통합을 광고한다 —',
'  `commit-commands`가 설치 레지스트리(`installed_plugins.json`)에 있는지 열어서 확인하라. 두 질문:',
'  (a) 통합을 광고하면서 prerequisites 섹션이 있는가 (CLAUDE.md: "Silent coupling은 버그")? (b)',
'  `/commit-push-pr` 권고가 `templates/shared/pr-process.md` 경유로 사용자 프로젝트에 복제되는가?',
'- **D2** qg의 README:79가 *"PR 생성 시 qg가 트리거된다"*를 주장한다. `hooks/hooks.json`의 이벤트',
'  목록엔 PR 트리거가 없다 — 훅 *본문*(`quality-gates/hooks/post-tool-use.py`)을 열어 실제 동작을',
'  확인하고 판정하라. **인덱스와 본문이 엇갈릴 수 있다** (계약 6항).',
'- **D3** marketplace description drift — `.claude-plugin/marketplace.json` vs `plugin.json`.',
'- **D4** 플러그인 폴더에 git-ignored 파일 3개가 실재한다 (직접 열어보라). `templates/**`가 이들을',
'  사용자 프로젝트로 복제하는가? **템플릿을 *사용하는* 코드**를 읽어 복제 메커니즘의 유무를 판정하라.',
'  **severity는 네가 판정.**',
```

- [ ] **Step 5: AXIS① question (`audit-workflow.js:238`) — D2 복원 + settled 문구 제거** (row 1 + row 2)

`old`:
```javascript
'- **D1·D3·D4를 검증하고 판정하라** (`d_verdicts`에 D1·D3·D4 필수). D2는 철회됐다.',
```
`new`:
```javascript
'- **D1·D2·D3·D4를 검증하고 판정하라** (`d_verdicts`에 D1·D2·D3·D4 필수).',
```

- [ ] **Step 6: AXIS③ question (`audit-workflow.js:277`) — D2 예시 제거**

`old`:
```javascript
'  hooks.json은 인덱스다 — **본문을 읽어라** (D2가 그 실패였다).',
```
`new`:
```javascript
'  hooks.json은 인덱스다 — **본문을 읽어라** (인덱스가 본문과 정반대를 시사할 수 있다).',
```

- [ ] **Step 7: refutePrompt Gate D (`audit-workflow.js:391-393`) — D2 반증 예시 중립화**

`old`:
```javascript
'  ⚠️ **그러나 다른 컴포넌트에서 *온* 증거는 죽이지 마라.** *"형제는 X를 하고 이 문서도 X를 한다고',
'  주장하는데 안 한다"*는 **기록된 거짓**이며 정합·정직성 축의 정당한 증거다 (D2의 반증이',
'  `quality-gates/hooks/post-tool-use.py` **본문**에 있었다).',
```
`new`:
```javascript
'  ⚠️ **그러나 다른 컴포넌트에서 *온* 증거는 죽이지 마라.** *"형제는 X를 하고 이 문서도 X를 한다고',
'  주장하는데 안 한다"*는 **기록된 거짓**이며 정합·정직성 축의 정당한 증거다 — 한 단서의 반증 증거가',
'  형제 플러그인 훅 *본문*에 있는 경우가 그렇다 (읽기는 무제한이므로 정당하다).',
```

- [ ] **Step 8: row 13 (byte→semantic) 두 곳** — `audit-workflow.js:374` + `audit-refuter.md:36`

`audit-workflow.js:374` `old`:
```javascript
'여섯 게이트 A–F는 네 시스템 프롬프트(persona)와 **바이트 단위로 일치**한다. `refutation.gate`에',
```
`new`:
```javascript
'여섯 게이트 A–F는 네 시스템 프롬프트(persona)와 **의미 단위로 일치**한다. `refutation.gate`에',
```

`audit-refuter.md:36` `old`:
```markdown
> `audit-workflow.js` **byte for byte** — the letter A–F means the same thing in all three, and
```
`new`:
```markdown
> `audit-workflow.js` **semantically aligned** — the letter A–F means the same thing in all three, and
```

- [ ] **Step 9: audit-refuter.md:75 (row 1) — D2 예시 중립화**

`old`:
```markdown
confuse this with *reading* scope, which is unlimited: the disproof of D2 lived in a sibling plugin.
```
`new`:
```markdown
confuse this with *reading* scope, which is unlimited: a candidate clue's disproof can live in a sibling plugin.
```

- [ ] **Step 10: row 15 (주석 문면 정리) — audit-workflow.js:12-13**

`old`:
```javascript
// The only two dispatch sites in this file. check-law2.py pins both lines byte-for-byte
// and asserts the identifier `agent` appears exactly twice in the whole script — an
```
`new`:
```javascript
// The only two dispatch sites in this file. check-law2.py pins both lines by content
// (whitespace-insensitive) and asserts the identifier `agent` appears exactly twice — an
```

- [ ] **Step 11: 전수 grep 회귀 락 — 주입 표면에 D-단서 판정이 남지 않았는지**

Run:
```bash
grep -nE "철회|사실 오류|다시 열지 마|D2가 그 실패|D2의 반증|disproof of D2|D2는 철회" scripts/audit-workflow.js .claude/agents/audit-refuter.md .claude/agents/plugin-auditor.md .claude/agents/smoke-probe.md
```
Expected: **출력 없음** (exit 1). 하나라도 남으면 그 사이트를 중립화.

- [ ] **Step 12: 게이트 GREEN 확인** — Task 1의 강화된 게이트로 실제 표면 검사

Run: `python3 scripts/check-no-verdict-injection.py`
Expected: `GREEN — 주입 표면 4개, 판정 주입 0건` (smoke-workflow.js는 아직 없어 skip; scanned=4). exit 0.

Run: `python3 -m unittest scripts.tests.test_check_no_verdict_injection.TestBannedSync.test_real_surfaces_are_green -v`
Expected: PASS (이제 Task 1의 회귀 락이 GREEN).

- [ ] **Step 13: 커밋**

```bash
git add scripts/audit-workflow.js .claude/agents/audit-refuter.md
git commit -m "fix(audit): 판정 주입 8개 사이트 전수 중립화 + D2 후보 단서 복원 (row 1·13·15)"
```

---

## Task 3: 공유 Node 하니스 + audit-workflow.js 스키마 갱신 (rows 2·3·6·7·14)

**Files:**
- Create: `scripts/tests/_wf_harness.mjs` (공유 하니스)
- Create: `scripts/tests/audit-workflow.test.mjs` (Node)
- Modify: `scripts/audit-workflow.js` — `AXIS_SCHEMA.d_verdicts.items.properties.id.enum`(:71) · AXIS① question(:238, Task 2에서 D2 추가 완료) · `findings.required`(:45-47) · `REFUTE_SCHEMA`(:113-132) · `new_open_questions.axis`(:103)

**Interfaces:**
- Consumes: `scripts/audit-workflow.js` (Task 2 완료본).
- Produces (`_wf_harness.mjs`):
  - `export async function runWorkflow(opts)` → `{result, captured}` where `captured[phase]` = 그 phase에서 `agent()`에 넘어간 `schema` 객체, `result` = workflow return.
  - `opts.stubAgent(prompt, opts)` (기본 제공), `opts.args` (기본 fixture).

**근거 (설계 §14 rows 2·3·6·7·14):** row 3 — `d_verdicts.id` enum이 `['D1','D3','D4','D5']`로 **D2 누락** (실측 확인). row 2 — AXIS① question이 `D1·D3·D4`만 요구 (Task 2 Step 5에서 `D1·D2·D3·D4`로 수정 완료 — 여기선 스키마 enum). row 6 — `findings.required`에 `reference_gap` 없음 (Goals 2·§9.2가 요구하는 차원). row 7 — `REFUTE_SCHEMA`가 `gate`를 무조건 필수로 (생존자는 kill 게이트가 없다). row 14 — `new_open_questions.axis`가 무제한 `integer` (§9.7의 *"axis는 항상 1–6"*이 코드로 강제 안 됨).

- [ ] **Step 1: 공유 하니스 작성** — `scripts/tests/_wf_harness.mjs`

```javascript
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const HERE = path.dirname(fileURLToPath(import.meta.url))
const REPO = path.resolve(HERE, '..', '..')
const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor

const DEFAULT_PACK = {
  plugin_version: '1.7.2', file_count: 51, total_lines: 4879,
  untracked_or_ignored: [], git_history_ld5: [],
}

// Run a Workflow script (top-level await + return) by wrapping it in an AsyncFunction and
// injecting the harness globals as parameters. `export const meta` is stripped (the only ESM
// token; there are no `import`s). The stubs let us capture the schema passed to each agent()
// and control returns to exercise the merge/deep branches.
export async function runWorkflow(scriptRel, opts = {}) {
  const src = fs.readFileSync(path.join(REPO, scriptRel), 'utf8')
    .replace(/^export const meta/m, 'const meta')
  const captured = {}
  const calls = []
  const stubAgent = opts.stubAgent || (async () => ({ findings: [], verdicts: [] }))
  const agent = async (prompt, o = {}) => {
    if (o.phase) captured[o.phase] = o.schema
    calls.push({ prompt, opts: o })
    return stubAgent(prompt, o)
  }
  const pipeline = async (items, ...stages) => {
    const out = []
    for (let idx = 0; idx < items.length; idx++) {
      let v = items[idx]
      for (const s of stages) v = await s(v, items[idx], idx)
      out.push(v)
    }
    return out
  }
  const parallel = async (thunks) => Promise.all(thunks.map((t) => t()))
  const phase = () => {}
  const log = () => {}
  const args = opts.args || { evidencePack: DEFAULT_PACK, codexFindings: [] }
  const run = new AsyncFunction('agent', 'pipeline', 'parallel', 'phase', 'log', 'args', src)
  const result = await run(agent, pipeline, parallel, phase, log, args)
  return { result, captured, calls }
}

// A stub that returns one finding of the given severity for the audit phase, an empty
// (non-killing) refuter verdict, and a non-refuting deep vote. Callers override per test.
export function stubOneFinding(severity = 'HIGH', extra = {}) {
  return async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity, fix_cost: 'S', fix_cost_rationale: 'x', ...extra,
        }],
        d_verdicts: [], oq_answers: [], new_open_questions: [],
      }
    }
    if (o.phase === '검증' || o.phase === '병합') return { verdicts: [] }
    if (o.phase === '심층검증') return { finding_id: 'A1-1', refuted: false, reason: 'ok' }
    return {}
  }
}
```

- [ ] **Step 2: 실패 테스트 작성** — `scripts/tests/audit-workflow.test.mjs`

```javascript
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { runWorkflow, stubOneFinding } from './_wf_harness.mjs'

test('row 3 — d_verdicts.id enum includes D2', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const enumIds = captured['감사'].properties.d_verdicts.items.properties.id.enum
  assert.deepEqual(enumIds, ['D1', 'D2', 'D3', 'D4', 'D5'])
})

test('row 6 — findings.required includes reference_gap', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const required = captured['감사'].properties.findings.items.required
  assert.ok(required.includes('reference_gap'), 'reference_gap must be required')
})

test('row 14 — new_open_questions.axis is bounded 1..6', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const axis = captured['감사'].properties.new_open_questions.items.properties.axis
  assert.equal(axis.type, 'integer')
  assert.equal(axis.minimum, 1)
  assert.equal(axis.maximum, 6)
})

test('row 7 — REFUTE_SCHEMA does not require gate unconditionally', async () => {
  const { captured } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const itemSchema = captured['검증'].properties.verdicts.items
  assert.ok(!itemSchema.required.includes('gate'),
    'gate must not be unconditionally required (survivors have no kill gate)')
  // 조건부 필수: verdict==refuted일 때만 gate 필수 (if/then)
  assert.ok(itemSchema.if && itemSchema.then,
    'gate should be conditionally required via if/then on verdict==refuted')
})

test('row 2 — AXIS① question requires D1·D2·D3·D4', async () => {
  const { calls } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const axis1 = calls.find((c) => c.opts.phase === '감사' && /축: 1/.test(c.prompt))
  assert.ok(/D1·D2·D3·D4/.test(axis1.prompt), 'AXIS① must ask for D1·D2·D3·D4')
})
```

- [ ] **Step 3: RED 확인**

Run: `node --test scripts/tests/audit-workflow.test.mjs`
Expected: rows 3·6·7·14 FAIL (현재 enum 누락·required 없음·gate 무조건·axis 무제한). row 2는 Task 2에서 이미 수정됐으면 PASS.

- [ ] **Step 4: 스키마 수정** — `scripts/audit-workflow.js`

row 3 (`:71`):
```javascript
          id: { type: 'string', enum: ['D1', 'D2', 'D3', 'D4', 'D5'] },
```

row 6 (`:45-47` required 배열에 `'reference_gap'` 추가):
```javascript
        required: ['id', 'axis', 'title', 'user_harm', 'recommendation',
                   'counter_argument', 'evidence', 'severity', 'fix_cost',
                   'fix_cost_rationale', 'reference_gap'],
```
> ⚠️ `reference_gap`은 이미 `properties`(:59)에 `{type:'string'}`으로 있다. 값이 없으면 `'none'`을 쓰도록 CONTRACT/스키마가 유도 — properties를 `{type:'string', enum-없음}`으로 두되 required에 추가한다 (agent가 항상 채우도록 강제; §9.2는 `string｜none`).

row 7 (`REFUTE_SCHEMA`의 items를 조건부 필수로, `:119-130`):
```javascript
      items: {
        type: 'object',
        required: ['finding_id', 'verdict', 'reason'],
        properties: {
          finding_id: { type: 'string' },
          verdict: { type: 'string', enum: ['refuted', 'survives'] },
          gate: { type: 'string', enum: ['A', 'B', 'C', 'D', 'E', 'F'] },
          reason: { type: 'string' },
          facts: { type: 'array', items: { type: 'string' } },
        },
        if: { properties: { verdict: { const: 'refuted' } } },
        then: { required: ['gate'] },
      },
```

row 14 (`new_open_questions.axis`, `:103`):
```javascript
          axis: { type: 'integer', minimum: 1, maximum: 6 },
```

- [ ] **Step 5: GREEN 확인**

Run: `node --test scripts/tests/audit-workflow.test.mjs`
Expected: 5 tests PASS.

- [ ] **Step 6: mutation 재확인** (수동) — 각 수정을 원복하면 해당 test가 RED인지 확인 (예: enum에서 `'D2'` 제거 → row 3 test FAIL) → 복원.

- [ ] **Step 7: 커밋**

```bash
git add scripts/audit-workflow.js scripts/tests/_wf_harness.mjs scripts/tests/audit-workflow.test.mjs
git commit -m "fix(audit): audit-workflow 스키마 갱신 — D2 enum·reference_gap 필수·gate 조건부·axis 1-6 (row 2·3·6·7·14)"
```

---

## Task 4: audit-workflow.js — CONTRACT가 evidence pack의 staleness/자체테스트/선례를 렌더 (row 4)

**Files:**
- Modify: `scripts/audit-workflow.js` — `CONTRACT` 배열의 Evidence Pack 섹션(:201-222)
- Modify: `scripts/tests/audit-workflow.test.mjs` (테스트 추가)

**Interfaces:**
- Consumes: `pack.staleness_facts[]` (각 `{class, quote, file, line}`) · `pack.own_tests` (`{ran, total, passed, failed, ...}`) · `pack.precedent_paths[]` · `pack.reference_paths[]` — orchestrator가 pre-1 step 3에서 채운다 (§6). 부재/빈 값 시 loud 라벨.
- Produces: `findPrompt(ax)`가 반환하는 프롬프트 문면에 staleness facts·자체 테스트 결과·선례 경로가 렌더된다.

**근거 (설계 §5.4a 🔴 line 270-279 · §14 row 4 · codex #8):** 커밋된 `CONTRACT`는 version·코퍼스 크기·git·오염 파일만 렌더하고 **staleness facts·자체 테스트 결과·선례 코퍼스 경로를 통째로 빠뜨렸다** — §5.4a가 막으려던 false-clean이 재발한다 (facts를 계산해서 버리면 계산 안 한 것과 같다). 생산(pre-1)만 있고 소비(프롬프트)가 없으면 죽은 채널이다.

- [ ] **Step 1: 실패 테스트 작성** — `audit-workflow.test.mjs`에 추가

```javascript
test('row 4 — CONTRACT renders staleness facts, own-test result, precedent paths', async () => {
  const args = {
    evidencePack: {
      plugin_version: '1.7.2', file_count: 51, total_lines: 4879,
      untracked_or_ignored: [], git_history_ld5: [],
      staleness_facts: [
        { class: 'dangling doc-claim', quote: 'scripts/foo.sh', file: 'README.md', line: 12 },
      ],
      own_tests: { ran: true, total: 95, passed: 95, failed: 0 },
      precedent_paths: ['~/Downloads/reference/gstack/careful/bin/check-careful.sh'],
      reference_paths: ['~/.claude/plugins/cache/claude-plugins-official/plugin-dev'],
    },
    codexFindings: [],
  }
  const { calls } = await runWorkflow('scripts/audit-workflow.js', { args, stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  assert.ok(/staleness|결정론.*사실|dangling doc-claim/.test(p), 'staleness facts must render')
  assert.ok(/README\.md:12|scripts\/foo\.sh/.test(p), 'staleness fact quote+file:line must render')
  assert.ok(/95.*95|자체 테스트|own_tests|테스트.*95/.test(p), 'own-test result must render')
  assert.ok(/check-careful\.sh|선례/.test(p), 'precedent path must render')
})

test('row 4 — CONTRACT degrades loudly when staleness/own-test absent', async () => {
  const { calls } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding() })
  const p = calls.find((c) => c.opts.phase === '감사').prompt
  // 기본 pack엔 staleness_facts/own_tests 없음 → "미실행/없음" 류 명시 (조용히 빠지지 않음)
  assert.ok(/staleness|자체 테스트|own_tests/.test(p), 'must mention the channels even when empty')
})
```

- [ ] **Step 2: RED 확인**

Run: `node --test scripts/tests/audit-workflow.test.mjs`
Expected: row 4 두 test FAIL (현재 CONTRACT가 이 필드를 렌더 안 함).

- [ ] **Step 3: CONTRACT Evidence Pack 섹션 확장** — `audit-workflow.js`의 `'## Evidence Pack (사실만)'` 블록(:201-222) 끝에 추가 (기존 항목 유지, 아래를 이어 붙임)

```javascript
  '',
  '## 결정론 staleness sweep — **사실만. 판정은 네가 한다** (§5.4a)',
  '아래는 파일시스템 전수 열거가 낸 *관측된 사실*이다. 각 사실이 갭인지는 **네가** 판정한다',
  '(코드 펜스·플레이스홀더·생성물 경로는 이미 제외됐다 — 그래도 원문을 직접 확인하라).',
  ...((pack.staleness_facts || []).length
    ? pack.staleness_facts.map((f) => '  - [' + f.class + '] `' + f.file + ':' + f.line + '` — ' + f.quote)
    : ['  - (staleness sweep 미실행 또는 사실 0건 — 없음을 사실로 받는다)']),
  '',
  '## 대상의 자체 테스트 결과 — **사실. "잘 테스트됐다"는 네 판정** (§5.4b)',
  pack.own_tests && pack.own_tests.ran
    ? '  - ' + pack.own_tests.framework + ': ' + pack.own_tests.passed + '/' + pack.own_tests.total
      + ' 통과, 실패 ' + pack.own_tests.failed + '건. **GREEN은 질문의 전제이지 품질의 증거가 아니다.**'
    : '  - ⚠ 자체 테스트 미실행 (' + ((pack.own_tests && pack.own_tests.why) || '사유 미상')
      + ') — 통과 여부를 모른다는 것이 사실이다.',
  '',
  '## 프로덕션 선례 코퍼스 (디스크에 있다 — 읽기 대상, 갭 대상 아님)',
  ...((pack.precedent_paths || []).length
    ? pack.precedent_paths.map((p) => '  - `' + p + '`')
    : ['  - (선례 코퍼스 부재 — OQ2·축⑥은 선례 없이 판정하거나 `unverified` §12)']),
```

> **판정 주입 금지**: staleness facts는 `[class] file:line — quote`만 렌더한다 (판정 없음). 자체 테스트는 숫자만. Task 1의 게이트가 이 블록도 스캔한다 (`audit-workflow.js`가 SURFACES에 있음) — `철회`·`사실 오류` 등이 들어가면 RED.

- [ ] **Step 4: GREEN 확인**

Run: `node --test scripts/tests/audit-workflow.test.mjs`
Expected: 전체 PASS (rows 2·3·4·6·7·14).

Run: `python3 scripts/check-no-verdict-injection.py`
Expected: GREEN (새 CONTRACT 블록에 판정 없음).

- [ ] **Step 5: mutation 재확인** (수동) — 새 staleness 렌더 줄을 삭제하면 row 4 test RED → 복원.

- [ ] **Step 6: 커밋**

```bash
git add scripts/audit-workflow.js scripts/tests/audit-workflow.test.mjs
git commit -m "fix(audit): CONTRACT가 staleness·자체테스트·선례를 감사 프롬프트에 렌더 (row 4)"
```

---

## Task 5: audit-workflow.js — deep_verified 3-상태 정합 (row 5)

**Files:**
- Modify: `scripts/audit-workflow.js` — 병합 else-분기(:483-485) + 심층검증 라벨링(:595-611)
- Modify: `scripts/tests/audit-workflow.test.mjs` (테스트 추가)

**Interfaces:**
- Consumes: `runWorkflow` 하니스 (Task 3).
- Produces: (a) deepPool 밖 생존 finding의 `deep_verified === null` (현재 `undefined`). (b) refuter-사망/누락으로 `unverified: true`인 finding은 심층 2렌즈 통과만으로 `deep_verified: true`를 받지 못한다 (null 유지).

**근거 (설계 §14 row 5 · §9.2 `deep_verified` · #11):** 현재 병합의 plain else(`:483-485`)는 `deep_verified`를 안 세워 MEDIUM/LOW 생존자가 `undefined`로 남는다 (렌더러가 3-상태를 기대). 그리고 refuter-사망 축의 HIGH가 deepPool에 들어가 심층 2렌즈만으로 `deep_verified: true`(거짓 확인 라벨)를 받는다 — *"두 모델이 독립 확인했다"*는 생존한(축 refute를 통과한) 발견을 뜻하지, 축 검증을 아예 못 받은 발견이 아니다.

- [ ] **Step 1: 실패 테스트 작성** — `audit-workflow.test.mjs`에 추가

```javascript
test('row 5a — MEDIUM survivor outside deepPool has deep_verified === null (not undefined)', async () => {
  const { result } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding('MEDIUM') })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.equal(f.status, 'reported')
  assert.strictEqual(f.deep_verified, null, 'must be explicit null, not undefined')
})

test('row 5b — refuter-dead-axis HIGH is not labeled deep_verified:true by lenses alone', async () => {
  // 축 refuter가 죽는다 (검증 phase에서 null 반환). HIGH finding은 unverified가 되고,
  // 심층 2렌즈가 refute하지 않아도 true 라벨을 받으면 안 된다.
  const stub = async (prompt, o) => {
    if (o.phase === '감사') {
      return {
        findings: [{
          id: 'A1-1', axis: 1, title: 't', user_harm: 'h', recommendation: 'r',
          counter_argument: 'c', evidence: [{ file: 'f', line: 1, quote: 'q' }],
          severity: 'HIGH', fix_cost: 'S', fix_cost_rationale: 'x', reference_gap: 'none',
        }],
        d_verdicts: [], oq_answers: [], new_open_questions: [],
      }
    }
    if (o.phase === '검증') return null           // ← refuter dies
    if (o.phase === '심층검증') return { finding_id: 'A1-1', refuted: false, reason: 'ok' }
    return { verdicts: [] }
  }
  const { result } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stub })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.equal(f.status, 'reported')
  assert.equal(f.unverified, true, 'refuter death → unverified')
  assert.notEqual(f.deep_verified, true, 'must NOT be labeled true from deep lenses alone')
})
```

- [ ] **Step 2: RED 확인**

Run: `node --test scripts/tests/audit-workflow.test.mjs`
Expected: row 5a FAIL (`undefined !== null`), row 5b FAIL (현재 `deep_verified: true` 부여).

- [ ] **Step 3: 병합 else-분기 수정** — `audit-workflow.js:483-485`

`old`:
```javascript
    } else {
      rec.status = 'reported'
    }
```
`new`:
```javascript
    } else {
      rec.status = 'reported'
      rec.deep_verified = null   // deepPool에 들면 심층검증이 덮는다; 안 들면 null 유지 (3-상태, §9.2)
    }
```

- [ ] **Step 4: 심층검증 라벨링 수정** — `audit-workflow.js:608-611` (unverified는 true 라벨 금지)

`old`:
```javascript
  } else {
    f.deep_verified = votes.length === LENSES.length ? true : null
    f.deep_votes = votes
  }
```
`new`:
```javascript
  } else {
    // refuter가 죽었거나(unverified) 판정을 누락한 finding은 축 검증을 못 받았다 —
    // 심층 2렌즈 통과만으로 "두 모델 독립 확인(true)"을 참칭할 수 없다. null 유지.
    f.deep_verified = (!f.unverified && votes.length === LENSES.length) ? true : null
    f.deep_votes = votes
  }
```

- [ ] **Step 5: GREEN 확인 + 회귀**

Run: `node --test scripts/tests/audit-workflow.test.mjs`
Expected: 전체 PASS. 특히 Task 3의 `stubOneFinding('HIGH')`(정상 생존 HIGH)는 여전히 `deep_verified: true`를 받아야 한다 (unverified 아님) — 회귀 없음 확인용으로 아래 추가:

```javascript
test('row 5 regression — normal surviving HIGH still gets deep_verified:true', async () => {
  const { result } = await runWorkflow('scripts/audit-workflow.js', { stubAgent: stubOneFinding('HIGH') })
  const f = result.findings.find((x) => x.id === 'A1-1')
  assert.equal(f.deep_verified, true)
})
```

- [ ] **Step 6: 커밋**

```bash
git add scripts/audit-workflow.js scripts/tests/audit-workflow.test.mjs
git commit -m "fix(audit): deep_verified 3-상태 정합 — null 명시 + unverified는 true 라벨 금지 (row 5)"
```

---

## Task 6: check-law2.py — `tools:`를 frontmatter로 한정 (row 11) + 주석 (row 15)

**Files:**
- Modify: `scripts/check-law2.py:170-188` (`check_agent_files`) + 주석 `:50·:67·:228·:243`
- Test: `scripts/tests/test_check_law2.py` (신규)

**Interfaces:**
- Consumes: agent `.md` 파일.
- Produces: `check_agent_files`가 `tools:`를 **frontmatter 블록(첫 두 `---` 사이)에서만** 찾는다. frontmatter에 `tools:`가 없으면 (본문에만 있어도) RED.

**근거 (설계 §14 row 11 · codex #5):** 현재 `re.search(r"^tools:\s*(.+)$", text, re.MULTILINE)`(:179)는 **파일 전체**에서 첫 `^tools:`를 찾는다. frontmatter에 `tools:`가 없고 본문에만 있는 파일이 게이트를 통과하는데, 런타임은 frontmatter만 보고 **기본(쓰기 가능) 도구**를 부여할 수 있다 — Law 2 구멍. row 15는 순수 주석 정리 (구현은 이미 `.strip()` 비교).

- [ ] **Step 1: 실패 테스트 작성** — `scripts/tests/test_check_law2.py`

```python
import subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "check-law2.py"

GOOD_WF = (
    "export const meta = { name: 'x', description: 'd', phases: [] }\n"
    "const auditor = (prompt, opts) => agent(prompt, {...opts, agentType: 'plugin-auditor'})\n"
    "const refuter = (prompt, opts) => agent(prompt, {...opts, agentType: 'audit-refuter'})\n"
    "return { findings: [] }\n"
)
FM_GOOD = "---\nname: plugin-auditor\ntools: Glob, Grep, Read, WebSearch, WebFetch\n---\nbody\n"
FM_GOOD_REFUTER = "---\nname: audit-refuter\ntools: Glob, Grep, Read, WebSearch, WebFetch\n---\nbody\n"
# frontmatter에 tools: 없음, 본문에만 있음 (런타임은 기본 쓰기 도구 부여 → Law 2 구멍)
FM_TOOLS_IN_BODY = "---\nname: plugin-auditor\nmodel: inherit\n---\ntools: Glob, Grep, Read\n"


def run_law2(script_path, agents_dir):
    r = subprocess.run(
        [sys.executable, str(SCRIPT), str(script_path), "--agents-dir", str(agents_dir)],
        capture_output=True, text=True, cwd=str(REPO),
    )
    return r.returncode, r.stderr


class TestFrontmatterScoped(unittest.TestCase):
    def test_tools_only_in_body_is_red(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "wf.js").write_text(GOOD_WF, encoding="utf-8")
            ag = d / "agents"; ag.mkdir()
            (ag / "plugin-auditor.md").write_text(FM_TOOLS_IN_BODY, encoding="utf-8")
            (ag / "audit-refuter.md").write_text(FM_GOOD_REFUTER, encoding="utf-8")
            rc, err = run_law2(d / "wf.js", ag)
            self.assertEqual(rc, 1, f"본문 tools:가 frontmatter로 오인돼 통과했다:\n{err}")

    def test_tools_in_frontmatter_is_green(self):
        with tempfile.TemporaryDirectory() as d:
            d = Path(d)
            (d / "wf.js").write_text(GOOD_WF, encoding="utf-8")
            ag = d / "agents"; ag.mkdir()
            (ag / "plugin-auditor.md").write_text(FM_GOOD, encoding="utf-8")
            (ag / "audit-refuter.md").write_text(FM_GOOD_REFUTER, encoding="utf-8")
            rc, err = run_law2(d / "wf.js", ag)
            self.assertEqual(rc, 0, f"정상 frontmatter tools:가 RED:\n{err}")

    def test_real_workflow_is_green(self):
        # 커밋된 실제 audit-workflow.js + 실제 agents 디렉토리 (회귀 락)
        rc, err = run_law2(REPO / "scripts" / "audit-workflow.js", REPO / ".claude" / "agents")
        self.assertEqual(rc, 0, f"실제 workflow가 Law2 게이트에서 RED:\n{err}")


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `python3 -m unittest scripts.tests.test_check_law2 -v`
Expected: `test_tools_only_in_body_is_red` FAIL (현재 본문 `tools:`를 찾아 GREEN). 나머지 PASS.

- [ ] **Step 3: `check_agent_files` 수정** — frontmatter 블록 추출 후 그 안에서만 `tools:` 검색

`old` (`:178-182`):
```python
        text = path.read_text(encoding="utf-8")
        m = re.search(r"^tools:\s*(.+)$", text, re.MULTILINE)
        if not m:
            errs.append(f"{path}: no `tools:` frontmatter — an agent with no allowlist "
                        f"inherits everything, including Bash")
            continue
```
`new`:
```python
        text = path.read_text(encoding="utf-8")
        # tools: MUST live in the frontmatter block (between the first two `---`). A body
        # `tools:` mention is not the allowlist the runtime reads — treating it as one lets a
        # frontmatter-less agent pass while the runtime grants default (write-capable) tools
        # (codex #5, Law 2 hole).
        fm = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
        block = fm.group(1) if fm else ""
        m = re.search(r"^tools:\s*(.+)$", block, re.MULTILINE)
        if not m:
            errs.append(f"{path}: no `tools:` in frontmatter — an agent with no allowlist "
                        f"inherits everything, including Bash")
            continue
```

- [ ] **Step 4: 주석 정리 (row 15)** — `check-law2.py`의 "byte-for-byte"/"byte-exact" 네 곳을 whitespace-insensitive 표현으로

`:50`:
```python
them. The fifth does not, so the two helper lines are pinned by content (whitespace-insensitive).
```
`:67`:
```python
# The audit workflow's only two dispatch sites. Pinned by line content (whitespace-insensitive).
```
`:228`:
```python
    # Each occurrence must sit on a pinned helper line, matched by content (whitespace-insensitive)
```
`:243`:
```python
            errs.append(f"pinned helper line missing (content match, whitespace-insensitive):\n    {want}")
```

- [ ] **Step 5: GREEN 확인**

Run: `python3 -m unittest scripts.tests.test_check_law2 -v`
Expected: 3 PASS.

- [ ] **Step 6: mutation 재확인** (수동) — `fm`/`block` 추출을 원복(전체 text에서 검색)하면 `test_tools_only_in_body_is_red` FAIL(=게이트가 못 잡음) 확인 → 복원.

- [ ] **Step 7: 커밋**

```bash
git add scripts/check-law2.py scripts/tests/test_check_law2.py
git commit -m "fix(audit): check-law2 tools:를 frontmatter로 한정 (row 11) + 주석 정리 (row 15)"
```

---

## Task 7: check-integrity.sh — global에서 marketplace.json 제외 (row 9) + 헤더 주석 (row 10)

**Files:**
- Modify: `scripts/check-integrity.sh:65-72` (`is_foreign_state`) + 헤더 주석 `:8·:10`
- Test: `scripts/tests/test_check_integrity.py` (신규 — tempdir git fixture + subprocess)

**Interfaces:**
- Consumes: git repo (fixture).
- Produces: `check-integrity.sh global` 매니페스트가 `.claude-plugin/marketplace.json`을 **제외**한다. `ld5`는 machine-generated(`.DS_Store`·`__pycache__`)를 제외하되 content-bearing ignored(`.claude/…`)는 유지. 결정론(2회 실행 바이트 동일).

**근거 (설계 §14 row 9·10 · §5.5 line 531-542 · E1=codex #3):** 현재 `is_foreign_state`(:65-72)는 `.claude/`·`.superpowers/`·`.understand-anything/`만 제외하고 `.claude-plugin/marketplace.json`은 빼지 않는다 — 실측: global 매니페스트에 present. 형제 플러그인의 marketplace 항목이 바뀌기만 해도 **AFTER#1 오탐 → 감사 무효**. 백스톱은 *"감사자가 썼는가"*를 묻고 감사자는 이 파일을 쓸 수 없다(Law 2) → 백스톱이 볼 필요 없다. D3은 §5.4a가 잡는다. row 10은 순수 헤더 주석(코드는 이미 3 스코프 지원, `:32-34`).

- [ ] **Step 1: 실패 테스트 작성** — `scripts/tests/test_check_integrity.py`

```python
import os, subprocess, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "check-integrity.sh"


def git(cwd, *a):
    subprocess.run(["git", *a], cwd=str(cwd), check=True,
                   capture_output=True, text=True)


def make_fixture(tmp):
    """격리된 임시 git repo. 실제 리포는 절대 건드리지 않는다."""
    tmp = Path(tmp)
    git(tmp, "init", "-q")
    git(tmp, "config", "user.email", "t@t")
    git(tmp, "config", "user.name", "t")
    # LD5 대상 구조
    pi = tmp / "plugins" / "project-init"; pi.mkdir(parents=True)
    (pi / "plugin.json").write_text('{"name":"project-init","version":"1.7.2"}\n', encoding="utf-8")
    (tmp / "docs" / "git-workflow").mkdir(parents=True)
    (tmp / "docs" / "git-workflow" / "g.md").write_text("x\n", encoding="utf-8")
    # 공유 marketplace 파일 (여러 플러그인 항목)
    cp = tmp / ".claude-plugin"; cp.mkdir()
    (cp / "marketplace.json").write_text('{"plugins":[{"name":"project-init"},{"name":"other"}]}\n', encoding="utf-8")
    (tmp / ".gitignore").write_text(".DS_Store\n__pycache__/\n*.pyc\n.claude/\n", encoding="utf-8")
    git(tmp, "add", "-A")
    git(tmp, "commit", "-qm", "init")
    return tmp


def run_integrity(cwd, mode, out):
    r = subprocess.run(["bash", str(SCRIPT), mode, str(out)],
                       cwd=str(cwd), capture_output=True, text=True)
    return r.returncode, r.stderr


class TestIntegrity(unittest.TestCase):
    def test_global_excludes_marketplace(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            out = fx / "m.txt"
            rc, err = run_integrity(fx, "global", out)
            self.assertEqual(rc, 0, err)
            manifest = out.read_text(encoding="utf-8")
            self.assertNotIn("marketplace.json", manifest,
                             "global 매니페스트가 공유 marketplace.json을 해싱한다 (형제 편집 오탐)")

    def test_global_stable_across_sibling_marketplace_edit(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"; b = fx / "b.txt"
            run_integrity(fx, "global", a)
            # 형제 플러그인 항목만 변경
            (fx / ".claude-plugin" / "marketplace.json").write_text(
                '{"plugins":[{"name":"project-init"},{"name":"other","desc":"changed"}]}\n', encoding="utf-8")
            run_integrity(fx, "global", b)
            self.assertEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"),
                             "형제 marketplace 편집이 global 매니페스트를 바꿨다 (감사 무효 위험)")

    def test_ld5_excludes_machine_generated(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"
            run_integrity(fx, "ld5", a)
            # macOS가 디렉토리 열기만 해도 쓰는 .DS_Store 시뮬레이션 (ignored)
            (fx / "plugins" / "project-init" / ".DS_Store").write_bytes(b"\x00junk")
            b = fx / "b.txt"
            run_integrity(fx, "ld5", b)
            self.assertEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"),
                             ".DS_Store가 LD5 매니페스트를 바꿨다 (정상 실행 사망)")

    def test_ld5_keeps_content_bearing_contamination(self):
        # D4 오염(내용 있는 ignored 파일)은 LD5가 잡아야 한다
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"
            run_integrity(fx, "ld5", a)
            contam = fx / "plugins" / "project-init" / ".claude" / "state.md"
            contam.parent.mkdir(parents=True)
            contam.write_text("secret runtime state\n", encoding="utf-8")
            b = fx / "b.txt"
            run_integrity(fx, "ld5", b)
            self.assertNotEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"),
                                "LD5가 D4 오염(내용 있는 ignored)을 놓쳤다 — 백스톱의 존재 이유")

    def test_deterministic(self):
        with tempfile.TemporaryDirectory() as d:
            fx = make_fixture(d)
            a = fx / "a.txt"; b = fx / "b.txt"
            run_integrity(fx, "ld5", a)
            run_integrity(fx, "ld5", b)
            self.assertEqual(a.read_text(encoding="utf-8"), b.read_text(encoding="utf-8"))


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `python3 -m unittest scripts.tests.test_check_integrity -v`
Expected: `test_global_excludes_marketplace`·`test_global_stable_across_sibling_marketplace_edit` FAIL (현재 marketplace.json 해싱). 나머지(machine-generated·content-bearing·deterministic)는 이미 PASS (프로토타입이 그 부분은 맞음).

- [ ] **Step 3: `is_foreign_state`에 marketplace.json 추가** — `check-integrity.sh:65-72`

`old`:
```bash
is_foreign_state() {
  case "$1" in
    .claude/*|*/.claude/*)                       return 0 ;;
    .superpowers/*|*/.superpowers/*)             return 0 ;;
    .understand-anything/*|*/.understand-anything/*) return 0 ;;
  esac
  return 1
}
```
`new`:
```bash
is_foreign_state() {
  case "$1" in
    .claude/*|*/.claude/*)                       return 0 ;;
    .superpowers/*|*/.superpowers/*)             return 0 ;;
    .understand-anything/*|*/.understand-anything/*) return 0 ;;
    # 공유 다중-플러그인 파일: global에서만 제외 (형제 항목 편집이 AFTER#1을 오탐시킨다).
    # 감사자는 이 파일을 쓸 수 없고(Law 2), D3 drift는 §5.4a staleness sweep이 잡는다.
    .claude-plugin/marketplace.json)             return 0 ;;
  esac
  return 1
}
```

- [ ] **Step 4: 헤더 주석 (row 10)** — `check-integrity.sh:8·10`

`:8`:
```bash
# Usage:  check-integrity.sh <ld5|harness|global> <out_path>
```
`:10`:
```bash
# Three scopes, and the difference between them is load-bearing (design §5.5):
```
그리고 `:10` 아래에 harness 스코프 한 줄 설명이 없으면 `global` 설명 앞에 추가 (기존 `ld5`/`global` 블록 사이):
```bash
#
#   harness LD5 밖이지만 Law 2가 의존하는 파일: .claude/agents/*.md persona 3개 + scripts/*.
#           감사 도중 tamper되면 그 게이트의 GREEN이 무의미하다. AFTER #2가 이걸 본다.
#
```

- [ ] **Step 5: GREEN 확인**

Run: `python3 -m unittest scripts.tests.test_check_integrity -v`
Expected: 5 PASS.

- [ ] **Step 6: mutation 재확인** (수동) — `is_foreign_state`의 marketplace 줄을 제거하면 `test_global_excludes_marketplace` FAIL 확인 → 복원.

- [ ] **Step 7: 커밋**

```bash
git add scripts/check-integrity.sh scripts/tests/test_check_integrity.py
git commit -m "fix(audit): check-integrity global에서 marketplace.json 제외 (row 9) + 3-스코프 주석 (row 10)"
```

---

## Task 8: check-staleness.py — 결정론 staleness sweep 신규 (§5.4a)

**Files:**
- Create: `scripts/check-staleness.py`
- Test: `scripts/tests/test_check_staleness.py`

**Interfaces:**
- Consumes: `<plugin-dir>` 인자 (범용 — `plugin-audit`으로 이관). 3-way lookup을 위해 optional `--repo-root`(git 이력 조회용, 기본 = plugin-dir 상위 git root).
- Produces: stdout에 `{"facts": [ {class, file, line, quote, ...} ]}` JSON. **verdict/점수/PASS-FAIL 없음** — 사실만 (§5.4a). exit 0 (facts 유무 무관), 크래시 시에만 non-zero.
- 8 사실 클래스: `dangling doc-claim` · `frontmatter silent-truncation` · `draft residue` · `dangling command/plugin ref` · `version incoherence` · `description drift` · `declared-vs-actual surface` · `category absence`.

**근거 (설계 §5.4a · §14 check-staleness 행 · §16 FP 저항):** 모델은 "flat한 부재"를 구조적으로 못 본다 (읽을 파일이 없어서). sweep이 전수 열거해 evidence pack에 넣고 감사자가 갭인지 판정한다. **sweep 자신도 검증 대상** — 거짓 dangling은 감사자를 없는 갭으로 보낸다. 알려진 FP 클래스(코드 펜스 내부·생성물 경로·플레이스홀더·URL)를 제외하고 mutation test로 이빨을 증명한다.

> **범위 결정 (proportionality):** 8 클래스를 전부 한 태스크로 구현하되, **각 클래스는 독립 함수 + 독립 test**로 나눈다. Step 순서: 먼저 프레임(JSON 출력 + FP 제외 유틸 + 결정론), 그다음 클래스별 함수를 하나씩 TDD. 아래는 대표 3클래스(dangling doc-claim·frontmatter truncation·version incoherence)의 완전한 코드; 나머지 5클래스는 같은 패턴(함수 + fixture test + mutation)으로 이어간다. **각 클래스마다 clean 픽스처에 0건(FP 저항) + 결함 픽스처에 정확히 그 사실(이빨)을 assert한다.**

- [ ] **Step 1: 프레임 + FP 제외 유틸 작성** — `scripts/check-staleness.py`

```python
#!/usr/bin/env python3
"""check-staleness.py — 결정론 staleness sweep (design §5.4a).

모델은 '있는 것'만 본다. 'README가 광고하는 scripts/foo.sh가 없다' 같은 flat한 부재는 전수 열거를
요구하며, 모델은 놓쳐도 놓친 줄을 모른다 (거짓 결과). 이 sweep은 사실을 열거하고, 갭인지는 감사자가
판정한다 — **verdict/점수/PASS-FAIL을 내지 않는다** (그게 원장 31이 실증한 함정).

대상 플러그인 디렉토리를 인자로 받는 범용 검사기 → plugin-audit으로 이관. 에이전트 0개, 순수 FS.

함정 (원장 17·32): 거짓 dangling은 감사자를 없는 갭으로 보낸다. 알려진 FP 클래스(코드 펜스 내부·
생성물 경로·플레이스홀더·URL)를 제외한다 — '언급(mention)'과 '주장(use)'을 구별한다.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

# 결정론: 파일 목록은 항상 정렬해서 순회한다 (매니페스트 비결정 = 감사자가 실행마다 다른 사실).
DOC_GLOBS = ("README.md", "CHANGELOG.md", "commands/**/*.md", "templates/**/*",
             "docs/git-workflow/**/*.md")

# 초안 잔재 마커 — 스크립트가 소유한다 (주입 표면에 넣지 않는다, 원장 36 자기매치 방지).
DRAFT_MARKERS = (r"\bTODO\b", r"\bTBD\b", r"\bFIXME\b", r"<!--\s*draft", r"XXX")
PLACEHOLDER_RE = re.compile(r"\{\{[^}]*\}\}|<[a-z][a-z0-9_-]*>|\.\.\.")
URL_RE = re.compile(r"https?://|`?~?/?\.?claude")  # URL·홈경로류는 주장이 아니다


def iter_lines_outside_fences(text: str):
    """(lineno, line)를 내되 코드 펜스(``` ... ```) 내부는 건너뛴다.

    게이트가 '언급 vs 사용'을 구별하는 핵심: 코드 펜스·인용문 안의 경로는 *주장*이 아니다
    (실측 FP, 원장 36 — placeholder 검사기가 자기 설명문에 걸렸다)."""
    in_fence = False
    for i, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        yield i, line


def is_fp_claim(quote: str) -> bool:
    """알려진 FP 클래스: 플레이스홀더·URL·생성물 경로. True면 사실로 emit하지 않는다."""
    return bool(PLACEHOLDER_RE.search(quote) or URL_RE.search(quote))


def emit(facts, cls, file, line, quote, **extra):
    facts.append({"class": cls, "file": file, "line": line, "quote": quote, **extra})
```

- [ ] **Step 2: dangling doc-claim (3-way lookup) — 함수 + 실패 테스트**

먼저 test (`scripts/tests/test_check_staleness.py` 신규):
```python
import json, subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "check-staleness.py"


def run_sweep(plugin_dir):
    r = subprocess.run([sys.executable, str(SCRIPT), str(plugin_dir)],
                       capture_output=True, text=True, cwd=str(REPO))
    assert r.returncode == 0, r.stderr
    return json.loads(r.stdout)["facts"]


def classes(facts):
    return sorted({f["class"] for f in facts})


class TestDanglingDocClaim(unittest.TestCase):
    def _plugin(self, tmp, readme):
        p = Path(tmp) / "myplugin"; p.mkdir()
        (p / "plugin.json").write_text('{"name":"myplugin","version":"1.0.0"}\n', encoding="utf-8")
        (p / "README.md").write_text(readme, encoding="utf-8")
        (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
        return p

    def test_dangling_backtick_path_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Run `scripts/nonexistent.sh` to start.\n")
            facts = run_sweep(p)
            self.assertIn("dangling doc-claim", classes(facts))
            self.assertTrue(any("nonexistent.sh" in f["quote"] for f in facts))

    def test_existing_path_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "See `plugin.json` for config.\n")
            facts = run_sweep(p)
            self.assertNotIn("dangling doc-claim", classes(facts),
                             "실재 경로를 dangling으로 오탐")

    def test_path_in_code_fence_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Example:\n```\ncat scripts/example.sh\n```\n")
            facts = run_sweep(p)
            self.assertFalse(any("example.sh" in f.get("quote", "") for f in facts),
                             "코드 펜스 내부 경로를 주장으로 오탐 (mention vs use)")

    def test_placeholder_not_flagged(self):
        with tempfile.TemporaryDirectory() as d:
            p = self._plugin(d, "Create `<your-plugin>/scripts/x.sh`.\n")
            facts = run_sweep(p)
            self.assertFalse(any("x.sh" in f.get("quote", "") for f in facts),
                             "플레이스홀더 경로를 주장으로 오탐")


if __name__ == "__main__":
    unittest.main()
```

RED 확인: `python3 -m unittest scripts.tests.test_check_staleness -v` → 크래시(스크립트 미완) 또는 FAIL.

그다음 구현 (`check-staleness.py`에 추가):
```python
# 백틱 인용 경로 후보: `path/like/this` 중 슬래시 또는 확장자를 포함하는 것.
BACKTICK_PATH_RE = re.compile(r"`([^`]+)`")
PATHISH_RE = re.compile(r"[/.]")


def scan_dangling_doc_claims(plugin_dir: Path, repo_root: Path, facts):
    """문서가 백틱으로 인용한 경로가 워킹트리→HEAD→upstream 어디에도 없으면 flag (3-way lookup).

    워킹트리엔 없지만 HEAD엔 있는 것과 애초에 없던 것은 다른 사실 (FP 회피)."""
    import subprocess
    for rel in _iter_docs(plugin_dir):
        text = (plugin_dir / rel).read_text(encoding="utf-8", errors="replace")
        for lineno, line in iter_lines_outside_fences(text):
            for m in BACKTICK_PATH_RE.finditer(line):
                cand = m.group(1).strip()
                if not PATHISH_RE.search(cand) or is_fp_claim(cand):
                    continue
                if not cand.endswith((".sh", ".py", ".js", ".mjs", ".md", ".json", ".ts")) and "/" not in cand:
                    continue
                target = (plugin_dir / cand)
                if target.exists():
                    continue
                # HEAD lookup (git-tracked였는지)
                head = subprocess.run(
                    ["git", "-C", str(repo_root), "cat-file", "-e",
                     f"HEAD:{_repo_rel(plugin_dir, cand, repo_root)}"],
                    capture_output=True)
                in_head = head.returncode == 0
                emit(facts, "dangling doc-claim", str(rel), lineno, cand,
                     in_worktree=False, in_head=in_head)


def _iter_docs(plugin_dir: Path):
    seen = []
    for pat in DOC_GLOBS:
        for p in sorted(plugin_dir.glob(pat)):
            if p.is_file():
                seen.append(p.relative_to(plugin_dir))
    return sorted(set(seen))


def _repo_rel(plugin_dir, cand, repo_root):
    try:
        return str((plugin_dir / cand).resolve().relative_to(repo_root.resolve()))
    except ValueError:
        return cand
```

- [ ] **Step 3: dangling doc-claim GREEN + mutation**

`main()` 골격을 추가하고 위 스캐너를 호출:
```python
def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("plugin_dir", type=Path)
    ap.add_argument("--repo-root", type=Path, default=None)
    args = ap.parse_args()
    plugin_dir = args.plugin_dir
    if not plugin_dir.is_dir():
        print(f"[check-staleness] plugin dir not found: {plugin_dir}", file=sys.stderr)
        return 1
    repo_root = args.repo_root or _find_git_root(plugin_dir)
    facts: list = []
    scan_dangling_doc_claims(plugin_dir, repo_root, facts)
    scan_frontmatter_truncation(plugin_dir, facts)      # Step 4
    scan_version_incoherence(plugin_dir, facts)         # Step 5
    scan_draft_residue(plugin_dir, facts)               # Step 6
    scan_dangling_refs(plugin_dir, facts)               # Step 6
    scan_description_drift(plugin_dir, repo_root, facts) # Step 6
    scan_declared_surface(plugin_dir, facts)            # Step 6
    scan_category_absence(plugin_dir, facts)            # Step 6
    facts.sort(key=lambda f: (f["class"], f["file"], f["line"]))  # 결정론
    print(json.dumps({"facts": facts}, ensure_ascii=False, indent=2))
    return 0


def _find_git_root(start: Path) -> Path:
    import subprocess
    r = subprocess.run(["git", "-C", str(start), "rev-parse", "--show-toplevel"],
                       capture_output=True, text=True)
    return Path(r.stdout.strip()) if r.returncode == 0 else start.parent


if __name__ == "__main__":
    sys.exit(main())
```
> Step 3에서는 Step 4-6의 스캐너가 아직 없으므로 `main()`의 그 호출들을 **일단 주석 처리**하고 dangling만 켠 채 GREEN 확인. 각 후속 Step에서 하나씩 주석 해제.

Run: `python3 -m unittest scripts.tests.test_check_staleness.TestDanglingDocClaim -v`
Expected: 4 PASS.

mutation: `is_fp_claim` 호출을 제거하면 `test_placeholder_not_flagged` FAIL (플레이스홀더가 새어 들어옴) → 복원. `iter_lines_outside_fences`를 평범한 `enumerate`로 바꾸면 `test_path_in_code_fence_not_flagged` FAIL → 복원.

- [ ] **Step 4: frontmatter silent-truncation — 함수 + test**

test 추가 (`test_check_staleness.py`):
```python
class TestFrontmatterTruncation(unittest.TestCase):
    def test_unquoted_hash_truncates_tools(self):
        # Law 2 위험: tools: 값이 ' #'로 조용히 잘린다
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; (p / ".claude" / "agents").mkdir(parents=True)
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / ".claude" / "agents" / "a.md").write_text(
                "---\nname: a\ntools: Read, Grep # comment\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("frontmatter silent-truncation", classes(facts))

    def test_clean_frontmatter_ok(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; (p / ".claude" / "agents").mkdir(parents=True)
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / ".claude" / "agents" / "a.md").write_text(
                "---\nname: a\ntools: Read, Grep\n---\nbody\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("frontmatter silent-truncation", classes(facts))
```
구현:
```python
# 모든 .md의 frontmatter top-level scalar에 unquoted ' #' (주석 잘림) 또는 값 안의 ': '
# (중첩 매핑 오인)이 있는가 — YAML이 파서 에러 없이 값을 조용히 잘라먹는다 (CE validate-frontmatter).
UNQUOTED_HASH_RE = re.compile(r"^\s*[\w-]+:\s*[^'\"#\n]*\s#")


def scan_frontmatter_truncation(plugin_dir: Path, facts):
    for md in sorted(plugin_dir.rglob("*.md")):
        if md.is_dir():
            continue
        text = md.read_text(encoding="utf-8", errors="replace")
        fm = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
        if not fm:
            continue
        for offset, line in enumerate(fm.group(1).splitlines(), 2):  # +1 for `---`, +1 to 1-index
            if UNQUOTED_HASH_RE.search(line):
                emit(facts, "frontmatter silent-truncation",
                     str(md.relative_to(plugin_dir)), offset, line.strip())
```
`main()`에서 `scan_frontmatter_truncation` 주석 해제 → RED→GREEN 확인 → mutation(`UNQUOTED_HASH_RE`를 `#` 없는 패턴으로) FAIL → 복원.

- [ ] **Step 5: version incoherence — 함수 + test**

test:
```python
class TestVersionIncoherence(unittest.TestCase):
    def test_changelog_ahead_of_plugin_json(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.2.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertIn("version incoherence", classes(facts))

    def test_matching_versions_ok(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.2.0"}\n', encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.2.0] — 2026-01-01\n", encoding="utf-8")
            facts = run_sweep(p)
            self.assertNotIn("version incoherence", classes(facts))
```
구현:
```python
def scan_version_incoherence(plugin_dir: Path, facts):
    pj = plugin_dir / "plugin.json"
    ch = plugin_dir / "CHANGELOG.md"
    if not pj.is_file():
        return
    try:
        pjv = json.loads(pj.read_text(encoding="utf-8")).get("version")
    except json.JSONDecodeError:
        return
    if ch.is_file() and pjv:
        m = re.search(r"^##\s*\[?(\d+\.\d+\.\d+)\]?", ch.read_text(encoding="utf-8"), re.MULTILINE)
        if m and m.group(1) != pjv:
            emit(facts, "version incoherence", "CHANGELOG.md", 1,
                 f"CHANGELOG 최신 [{m.group(1)}] ≠ plugin.json version {pjv}",
                 plugin_json=pjv, changelog=m.group(1))
```
`main()` 주석 해제 → RED→GREEN → mutation(`!=`를 `==`로) FAIL → 복원.

- [ ] **Step 6: 나머지 5클래스 — 같은 패턴으로 하나씩**

각 클래스마다 (a) 결함 픽스처 → 그 사실 emit 확인, (b) clean 픽스처 → 0건 (FP 저항), (c) mutation. 구현 요지:
- `scan_draft_residue`: `DRAFT_MARKERS`를 **출하 문서**(README·CHANGELOG·commands·templates)에서 찾되 `iter_lines_outside_fences` + `is_fp_claim`. class=`draft residue`.
- `scan_dangling_refs`: 문서가 참조하는 `/command`·`other-plugin:agent`를 정규식으로 뽑아 설치 레지스트리(`~/.claude/plugins/installed_plugins.json` — 부재 시 skip + 사실에 `registry: absent`)에 없으면 + prerequisites 미선언이면 flag. class=`dangling command/plugin ref`.
- `scan_description_drift`: `plugin.json` description ↔ `.claude-plugin/marketplace.json`의 같은 이름 항목 description 불일치 (D3 기계화). marketplace 부재 시 skip. class=`description drift`.
- `scan_declared_surface`: README의 *"Hooks Installed"*/*"N skills"* 류 선언 개수 ↔ 디스크 실제 파일 개수 불일치. class=`declared-vs-actual surface`.
- `scan_category_absence`: **조건부 게이팅** — `CHANGELOG.md` ← plugin.json version ≥ 1.0.0일 때만 · `cost_class` ← skill 있을 때만 · kill switch ← hook 있을 때만 · Principles Instantiated ← README 있을 때. **조건 안 걸리면 emit 안 함** (`"해당 없음"`도 안 냄 — 관측된 것만). class=`category absence`.

각 Step에서 `main()` 해당 호출 주석 해제 후 RED→GREEN→mutation.

> ⚠️ **`category absence`는 규범을 전제하는 유일한 클래스** (§5.4a). 조건 게이팅을 반드시 넣어라 — 안 하면 규범이 적용 안 되는 경우에도 "부재"를 사실로 위장 배달한다. test: version 0.9.0 플러그인엔 CHANGELOG 부재를 emit하지 **않는다** (1.0.0 미만).

- [ ] **Step 7: 결정론 + 경계 케이스 테스트**

```python
class TestSweepInvariants(unittest.TestCase):
    def test_deterministic_two_runs(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "myplugin"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"m","version":"1.0.0"}\n', encoding="utf-8")
            (p / "README.md").write_text("Run `scripts/a.sh` and `scripts/b.sh`.\n", encoding="utf-8")
            (p / "CHANGELOG.md").write_text("## [1.0.0] — 2026-01-01\n", encoding="utf-8")
            f1 = json.dumps(run_sweep(p), ensure_ascii=False)
            f2 = json.dumps(run_sweep(p), ensure_ascii=False)
            self.assertEqual(f1, f2, "sweep이 비결정론 (감사자가 실행마다 다른 사실을 받는다)")

    def test_empty_plugin_no_crash_zero_facts(self):
        with tempfile.TemporaryDirectory() as d:
            p = Path(d) / "empty"; p.mkdir()
            (p / "plugin.json").write_text('{"name":"empty","version":"0.1.0"}\n', encoding="utf-8")
            facts = run_sweep(p)  # 크래시 없이 exit 0
            self.assertIsInstance(facts, list)
```

Run: `python3 -m unittest scripts.tests.test_check_staleness -v`
Expected: 전체 PASS.

- [ ] **Step 8: 커밋**

```bash
git add scripts/check-staleness.py scripts/tests/test_check_staleness.py
git commit -m "feat(audit): check-staleness 결정론 sweep 8클래스 신규 (§5.4a) — 사실만, FP 저항 + mutation"
```

---

## Task 9: smoke-workflow.js — 1-에이전트 capability 스모크 (r14) + check-law2 smoke 모드

**Files:**
- Create: `scripts/smoke-workflow.js`
- Test: `scripts/tests/smoke-workflow.test.mjs`

**Interfaces:**
- Consumes: `args.sentinelPath` (orchestrator가 지정). `probe` 헬퍼 = `agent(prompt, {...opts, agentType: 'smoke-probe'})` (check-law2 `CANONICAL_SMOKE`와 바이트 정합).
- Produces: workflow return = probe가 반환한 `{self_identity, available_tools, bash_present}` (자기보고 채널). 외부 ground-truth(sentinel 파일 부재)는 orchestrator가 검사.

**근거 (설계 §16 capability 스모크 · §14 smoke-workflow.js 행):** 스모크는 Agent 도구가 아니라 **Workflow의 `agentType` 해석**을 실증해야 한다 (다른 코드 경로). 미니 workflow라야 그 경로를 탄다. check-law2 `--mode smoke`가 이 파일을 별도 화이트리스트(`agent` 1회 + `agentType: 'smoke-probe'`)로 검사한다 (이미 구현됨: `CANONICAL_SMOKE`, `:73-75`).

- [ ] **Step 1: 실패 테스트 작성** — `scripts/tests/smoke-workflow.test.mjs`

```javascript
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { runWorkflow } from './_wf_harness.mjs'

test('smoke-workflow dispatches exactly one smoke-probe and returns the three channels', async () => {
  const stub = async () => ({
    self_identity: 'You are **smoke-probe**, a capability probe.',
    available_tools: ['Glob', 'Grep', 'Read', 'WebSearch', 'WebFetch'],
    bash_present: false,
  })
  const args = { sentinelPath: '/tmp/does-not-matter-in-stub', evidencePack: {} }
  const { result, calls } = await runWorkflow('scripts/smoke-workflow.js', { args, stubAgent: stub })
  const agentCalls = calls.filter((c) => c.opts && c.opts.agentType === 'smoke-probe')
  assert.equal(agentCalls.length, 1, 'exactly one smoke-probe dispatch')
  assert.ok('self_identity' in result && 'available_tools' in result && 'bash_present' in result)
})
```

- [ ] **Step 2: RED 확인**

Run: `node --test scripts/tests/smoke-workflow.test.mjs`
Expected: FAIL (파일 없음 → 하니스 `readFileSync` throw).

- [ ] **Step 3: smoke-workflow.js 작성** — `scripts/smoke-workflow.js`

```javascript
export const meta = {
  name: 'project-init-audit-smoke',
  description: 'pre-0c capability 스모크 — smoke-probe 1개가 쓸 수 있는지 sentinel로 증명한다',
  phases: [{ title: '스모크', detail: 'smoke-probe 1회 dispatch (persona 비어 있음)' }],
}

// The single dispatch site. check-law2.py --mode smoke pins this line (CANONICAL_SMOKE) and
// asserts `agent` appears exactly once with agentType 'smoke-probe'. Spread first so agentType
// cannot be overridden.
const probe = (prompt, opts) => agent(prompt, {...opts, agentType: 'smoke-probe'})

const sentinel = args.sentinelPath

// The probe is told to WRITE to the sentinel path (proving capability from disk, not self-report)
// and to report its identity/tools. If agentType did not resolve, a write-capable default agent
// would run and the sentinel file WOULD appear — that is the only channel that catches a silent
// fallback (design §16). The orchestrator checks the file's absence after this returns.
const result = await probe([
  '두 가지를 하라. 설명하지 말고 그대로 하라.',
  '  1. Bash 도구로 실행: echo devbrew-smoke > ' + sentinel,
  '     Bash 도구가 네 도구 목록에 없으면 아무것도 하지 말고 넘어가라.',
  '  2. self_identity / available_tools / bash_present 를 스키마대로 반환하라.',
].join('\n'), {
  label: 'capability 스모크',
  phase: '스모크',
  schema: {
    type: 'object',
    required: ['self_identity', 'available_tools', 'bash_present'],
    properties: {
      self_identity: { type: 'string' },
      available_tools: { type: 'array', items: { type: 'string' } },
      bash_present: { type: 'boolean' },
    },
  },
})

return result
```

- [ ] **Step 4: GREEN 확인 + check-law2 smoke 모드**

Run: `node --test scripts/tests/smoke-workflow.test.mjs`
Expected: PASS.

Run: `python3 scripts/check-law2.py scripts/smoke-workflow.js --mode smoke`
Expected: `GREEN — scripts/smoke-workflow.js (smoke): agent x1, all via pinned helpers; agents ['smoke-probe'] ...` exit 0.

Run: `python3 scripts/check-no-verdict-injection.py`
Expected: `GREEN — 주입 표면 5개, 판정 주입 0건` (smoke-workflow.js가 이제 SURFACES에 존재 → scanned=5).

- [ ] **Step 5: check-law2 smoke-모드 회귀 test 추가** — `test_check_law2.py`에

```python
class TestSmokeMode(unittest.TestCase):
    def test_real_smoke_workflow_green(self):
        r = subprocess.run(
            [sys.executable, str(SCRIPT), str(REPO / "scripts" / "smoke-workflow.js"),
             "--mode", "smoke", "--agents-dir", str(REPO / ".claude" / "agents")],
            capture_output=True, text=True, cwd=str(REPO))
        self.assertEqual(r.returncode, 0, r.stderr)
```
Run: `python3 -m unittest scripts.tests.test_check_law2.TestSmokeMode -v` → PASS.

- [ ] **Step 6: 커밋**

```bash
git add scripts/smoke-workflow.js scripts/tests/smoke-workflow.test.mjs scripts/tests/test_check_law2.py
git commit -m "feat(audit): smoke-workflow 미니 workflow 신규 (r14) + check-law2 smoke 모드 회귀 락"
```

---

## Task 10: validate-audit-data.py — 데이터·산출물 검증 신규 (§16, rows 8·16의 이빨)

**Files:**
- Create: `scripts/validate-audit-data.py`
- Test: `scripts/tests/test_validate_audit_data.py`

**Interfaces:**
- Consumes: `audit-data.json` (§9.1 스키마). CLI: `validate-audit-data.py --data <json>` / `--artifacts <json> --repo-root <dir>`.
- Produces: `--data` → consent 3필드 대조 · `fanout_declared == 30` · **D1–D5/OQ1–OQ6 완결성**(row 16 이빨) · `steelman_condition: pending` 잔존 0 · codex 병합(B7) · cross-model 증발 검사 · NOQ 원소 스키마 · **gate-E→NOQ 회수**(row 8 이빨) · `oq_ref` enum. `--artifacts` → README 링크·CLAUDE.md 포인터·리포트 첫 20줄 배너. RED → exit 1.

**근거 (설계 §16 line 1640 · §9.1 · rows 8·16):** 파이프라인은 자기를 회계 못 하므로 검증을 밖에 둔다. **row 16 backfill의 이빨** = 완결성 검사(배정 D/OQ가 데이터에 없으면 RED → orchestrator가 backfill하도록 강제). **row 8 gate-E→NOQ의 이빨** = `count(refuted gate-E) <= count(scope-out NOQ)` (변환 안 하면 RED). codex 병합(B7)·cross-model은 LD4의 유일한 산출물이 조용히 증발하는 걸 막는다.

- [ ] **Step 1: 정본 fixture + 실패 테스트 작성** — `scripts/tests/test_validate_audit_data.py`

```python
import copy, json, subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "validate-audit-data.py"

# 최소 유효 audit-data.json (§9.1). Claude+codex가 D1–D5·OQ1–OQ6를 각각 판정.
def d(id_, src): return {"id": id_, "source": src, "verdict": "unverified", "reason": "r", "why_unverifiable": "w"}
def oq(id_, src): return {"id": id_, "source": src, "reason": "r", "answer": "a"}

VALID = {
    "meta": {"date": "2026-07-13", "fanout_declared": 30,
             "consent": {"approved": True, "at": "2026-07-13T00:00:00Z"},
             "codex": {"ran": True, "version": "0.142.5"}},
    "findings": [],
    "d_verdicts": [d(f"D{i}", s) for i in range(1, 6) for s in ("claude", "codex")],
    "oq_answers": [oq(f"OQ{i}", s) for i in range(1, 7) for s in ("claude", "codex")],
    "new_open_questions": [],
    "axis_failures": [],
    "degraded": [],
}


def run_validate(data, mode="--data"):
    with tempfile.TemporaryDirectory() as t:
        j = Path(t) / "audit-data.json"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), mode, str(j)],
                           capture_output=True, text=True, cwd=str(REPO))
        return r.returncode, r.stderr


class TestData(unittest.TestCase):
    def test_valid_is_green(self):
        rc, err = run_validate(VALID)
        self.assertEqual(rc, 0, err)

    def test_missing_assigned_d_is_red(self):  # row 16 이빨
        bad = copy.deepcopy(VALID)
        bad["d_verdicts"] = [x for x in bad["d_verdicts"] if x["id"] != "D2"]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "배정 D2 누락이 완결성 검사를 통과했다 (backfill 미강제)")

    def test_wrong_fanout_is_red(self):
        bad = copy.deepcopy(VALID); bad["meta"]["fanout_declared"] = 25
        rc, _ = run_validate(bad); self.assertEqual(rc, 1)

    def test_consent_mismatch_is_red(self):
        bad = copy.deepcopy(VALID); bad["meta"]["consent"]["approved"] = False
        rc, _ = run_validate(bad); self.assertEqual(rc, 1)

    def test_pending_steelman_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["findings"] = [{"id": "A2-1", "source": "claude", "axis": 2, "status": "reported",
                            "steelman_condition": "pending", "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "steelman_condition: pending 잔존이 통과했다")

    def test_codex_ran_but_no_codex_verdict_is_red(self):  # B7
        bad = copy.deepcopy(VALID)
        bad["d_verdicts"] = [x for x in bad["d_verdicts"] if x["source"] != "codex"]
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "codex.ran=true인데 codex 판정 없음이 통과 (LD4 참칭)")

    def test_gate_e_refuted_without_noq_is_red(self):  # row 8 이빨
        bad = copy.deepcopy(VALID)
        bad["findings"] = [{"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
                            "refutation": {"stage": "axis", "gate": "E", "reason": "범위 밖"},
                            "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        # scope-out NOQ 없음 → RED
        rc, err = run_validate(bad)
        self.assertEqual(rc, 1, "gate-E refuted가 NOQ로 회수되지 않았는데 통과 (조용한 증발)")

    def test_gate_e_refuted_with_noq_is_green(self):
        ok = copy.deepcopy(VALID)
        ok["findings"] = [{"id": "A1-1", "source": "claude", "axis": 1, "status": "refuted",
                           "refutation": {"stage": "axis", "gate": "E", "reason": "범위 밖"},
                           "evidence": [{"file": "f", "line": 1, "quote": "q"}]}]
        ok["new_open_questions"] = [{"id": "NOQ-1", "source": "claude", "axis": 1,
                                     "observation": "A1-1", "why_not_gap": "LD5 범위 밖", "evidence": []}]
        rc, err = run_validate(ok)
        self.assertEqual(rc, 0, err)

    def test_noq_missing_why_not_gap_is_red(self):
        bad = copy.deepcopy(VALID)
        bad["new_open_questions"] = [{"id": "NOQ-1", "source": "claude", "axis": 1,
                                      "observation": "x", "evidence": []}]  # why_not_gap 없음
        rc, _ = run_validate(bad); self.assertEqual(rc, 1)


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `python3 -m unittest scripts.tests.test_validate_audit_data -v`
Expected: 전부 FAIL/error (스크립트 미작성).

- [ ] **Step 3: validate-audit-data.py 작성**

```python
#!/usr/bin/env python3
"""validate-audit-data.py — 감사 데이터·산출물 검증 (design §16).

파이프라인은 자기를 회계할 수 없다 (§9.1) → 검증을 파이프라인 밖에 둔다. RED면 렌더링/커밋 금지.

--data: 렌더링 *전*. consent 3필드 · fanout==30 · D1–D5/OQ1–OQ6 완결성 · pending 잔존 0 ·
        codex 병합(B7) · cross-model 증발 · NOQ 원소 스키마 · gate-E→NOQ 회수.
--artifacts: 렌더링 *후*. 실제 파일을 본다 (골든 픽스처는 실물을 안 본다).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ASSIGNED_D = ["D1", "D2", "D3", "D4", "D5"]
ASSIGNED_OQ = ["OQ1", "OQ2", "OQ3", "OQ4", "OQ5", "OQ6"]
VALID_VERDICT = {"confirmed", "withdrawn", "reclassified", "unverified"}


def validate_data(data: dict) -> list:
    errs: list[str] = []
    meta = data.get("meta", {})

    # consent 3필드
    consent = meta.get("consent", {})
    if not consent.get("approved") is True:
        errs.append("meta.consent.approved != true")
    if not consent.get("at"):
        errs.append("meta.consent.at 없음")
    if meta.get("fanout_declared") != 30:
        errs.append(f"fanout_declared != 30 (got {meta.get('fanout_declared')})")

    # D/OQ 완결성 (row 16 이빨 — backfill 안 하면 여기서 RED)
    d_ids = {x.get("id") for x in data.get("d_verdicts", [])}
    for did in ASSIGNED_D:
        if did not in d_ids:
            errs.append(f"배정 D {did}이 d_verdicts에 없다 (backfill 필요 — §6 post-1 step 2)")
    oq_ids = {x.get("id") for x in data.get("oq_answers", [])}
    for oid in ASSIGNED_OQ:
        if oid not in oq_ids:
            errs.append(f"배정 OQ {oid}이 oq_answers에 없다 (backfill 필요)")
    for x in data.get("d_verdicts", []):
        if x.get("verdict") not in VALID_VERDICT:
            errs.append(f"{x.get('id')}/{x.get('source')} verdict 무효: {x.get('verdict')}")

    # codex 병합 (B7): codex.ran이면 codex source 판정이 D·OQ에 있어야
    if meta.get("codex", {}).get("ran") is True:
        for did in ASSIGNED_D:
            if not any(x.get("id") == did and x.get("source") == "codex" for x in data.get("d_verdicts", [])):
                errs.append(f"codex.ran=true인데 {did}의 codex 판정 없음 (B7 — LD4 참칭)")
        for oid in ASSIGNED_OQ:
            if not any(x.get("id") == oid and x.get("source") == "codex" for x in data.get("oq_answers", [])):
                errs.append(f"codex.ran=true인데 {oid}의 codex 답변 없음 (B7)")

    findings = data.get("findings", [])

    # steelman pending 잔존 0
    for f in findings:
        if f.get("steelman_condition") == "pending":
            errs.append(f"{f.get('id')}: steelman_condition=pending 잔존 (post-1 2b 미해소)")

    # NOQ 원소 스키마 (§9.7)
    for q in data.get("new_open_questions", []):
        if not q.get("why_not_gap"):
            errs.append(f"{q.get('id')}: why_not_gap 없음 (NOQ 필수)")
        if not q.get("source"):
            errs.append(f"{q.get('id')}: source 없음")
        ax = q.get("axis")
        if not (isinstance(ax, int) and 1 <= ax <= 6):
            errs.append(f"{q.get('id')}: axis 1–6 아님 ({ax})")

    # gate-E → NOQ 회수 (row 8 이빨)
    gate_e = [f for f in findings if f.get("status") == "refuted"
              and f.get("refutation", {}).get("gate") == "E"]
    scope_noq = [q for q in data.get("new_open_questions", [])
                 if "범위 밖" in (q.get("why_not_gap") or "")]
    if len(gate_e) > len(scope_noq):
        errs.append(f"gate-E refuted {len(gate_e)}건 > scope-out NOQ {len(scope_noq)}건 "
                    f"(gate-E → NOQ 회수 미배선 — §9.7 🔴, 조용한 증발)")

    # cross-model 증발: dedup은 같은 source 안에서만
    by_id = {f.get("id"): f for f in findings}
    for f in findings:
        r = f.get("refutation") or {}
        if r.get("stage") == "dedup":
            tid = r.get("target_id")
            if not tid or tid not in by_id:
                errs.append(f"{f.get('id')}: dedup target_id 부재/무효 (구조화 필드)")
            elif by_id[tid].get("source") != f.get("source"):
                errs.append(f"{f.get('id')}: cross-source dedup (배선 버그 — LD4 산출물 증발)")

    # oq_ref enum
    for f in findings:
        ref = f.get("oq_ref")
        if ref is not None and ref not in ASSIGNED_OQ:
            errs.append(f"{f.get('id')}: oq_ref enum 위반 ({ref})")

    return errs


def validate_artifacts(data: dict, repo_root: Path, report_path: Path) -> list:
    errs: list[str] = []
    readme = repo_root / "docs" / "audits" / "README.md"
    if not readme.is_file() or report_path.name not in readme.read_text(encoding="utf-8"):
        errs.append("docs/audits/README.md가 리포트를 링크하지 않음")
    claude_md = repo_root / "CLAUDE.md"
    if not claude_md.is_file() or "docs/audits/" not in claude_md.read_text(encoding="utf-8"):
        errs.append("CLAUDE.md에 docs/audits/ 포인터 없음")
    if data.get("degraded"):
        head = "\n".join(report_path.read_text(encoding="utf-8").splitlines()[:20])
        if "⚠" not in head and "degraded" not in head.lower():
            errs.append("degraded 비었지 않은데 리포트 첫 20줄에 배너 없음 (AC-3)")
    return errs


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["--data", "--artifacts"])
    ap.add_argument("json", type=Path)
    ap.add_argument("--repo-root", type=Path, default=Path("."))
    ap.add_argument("--report", type=Path, default=None)
    args = ap.parse_args()
    data = json.loads(args.json.read_text(encoding="utf-8"))
    if args.mode == "--data":
        errs = validate_data(data)
    else:
        errs = validate_artifacts(data, args.repo_root, args.report or args.json)
    if errs:
        print(f"[validate-audit-data] RED ({args.mode}) — {len(errs)}건", file=sys.stderr)
        for e in errs:
            print(f"  ✗ {e}", file=sys.stderr)
        return 1
    print(f"[validate-audit-data] GREEN ({args.mode})", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: GREEN 확인**

Run: `python3 -m unittest scripts.tests.test_validate_audit_data -v`
Expected: 전체 PASS.

- [ ] **Step 5: mutation 재확인** (수동) — 완결성 루프(`for did in ASSIGNED_D`)를 제거하면 `test_missing_assigned_d_is_red` FAIL(=검사가 못 잡음) → 복원. gate-E 블록 제거 → `test_gate_e_refuted_without_noq_is_red` FAIL → 복원.

- [ ] **Step 6: 커밋**

```bash
git add scripts/validate-audit-data.py scripts/tests/test_validate_audit_data.py
git commit -m "feat(audit): validate-audit-data 신규 — 완결성(row16)·gate-E회수(row8)·B7·cross-model·NOQ"
```

---

## Task 11: render-audit-report.py — JSON→마크다운 렌더러 + 골든 픽스처 (§16·§11)

**Files:**
- Create: `scripts/render-audit-report.py`
- Test: `scripts/tests/test_render_audit_report.py`

**Interfaces:**
- Consumes: `audit-data.json`. CLI: `render-audit-report.py <json> --out <md> --readme <docs/audits/README.md>`.
- Produces: 마크다운 리포트. 정렬(§11): severity desc → fix_cost asc(S<M<L) → reference_gap 유무 → id 사전순. 배너(§12): `codex.ran==false`·`degraded[]` 비지 않음. deep_verified 3-상태 라벨. NOQ 섹션·cross-model 배지·oq_ref 역참조. AC-4: `axis_failures.length==6` → 리포트 안 만들고 실패 보고; `>=1` → `N/6 축 완주` 배너; `findings==0` → 깨끗함/실패 구분 배너.

**근거 (설계 §11 · §16 골든 픽스처 · §9.2 필드×채널 삼각표 · AC-4):** 렌더러는 신규 load-bearing 코드다 — 정렬은 순회가 아니라 4단 비교자이고 두 키 모두 비-사전순 서수라 순진한 문자열 비교가 조용히 뒤집는다. `fix_cost`에 산문이 섞이면 비교자가 NaN을 낸다. 골든 픽스처가 깔끔한 값만 담으면 GREEN인 채 프로덕션만 뒤집힌다 — 픽스처에 **산문 섞인 fix_cost**를 넣어 파싱 의존을 태운다.

- [ ] **Step 1: 실패 테스트 작성** — `scripts/tests/test_render_audit_report.py`

```python
import json, subprocess, sys, tempfile, unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRIPT = REPO / "scripts" / "render-audit-report.py"


def render(data):
    with tempfile.TemporaryDirectory() as t:
        j = Path(t) / "d.json"; out = Path(t) / "r.md"; readme = Path(t) / "README.md"
        j.write_text(json.dumps(data, ensure_ascii=False), encoding="utf-8")
        r = subprocess.run([sys.executable, str(SCRIPT), str(j), "--out", str(out), "--readme", str(readme)],
                           capture_output=True, text=True, cwd=str(REPO))
        md = out.read_text(encoding="utf-8") if out.is_file() else ""
        return r.returncode, md, r.stderr


def f(id_, sev, cost, axis=1, **kw):
    base = {"id": id_, "source": "claude", "axis": axis, "title": id_, "severity": sev,
            "fix_cost": cost, "status": "reported", "user_harm": "h", "recommendation": "r",
            "counter_argument": "c", "reference_gap": "none", "deep_verified": None,
            "evidence": [{"file": "f", "line": 1, "quote": "q"}]}
    base.update(kw); return base


META_OK = {"date": "2026-07-13", "fanout_declared": 30,
           "consent": {"approved": True, "at": "t"}, "codex": {"ran": True}}


class TestRender(unittest.TestCase):
    def test_sort_severity_then_cost(self):
        data = {"meta": META_OK, "findings": [f("A1-2", "HIGH", "L"), f("A1-1", "HIGH", "S"),
                f("A1-3", "CRITICAL", "M")], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        # CRITICAL 먼저, 그 다음 HIGH 중 S(cost) 먼저
        order = [md.index("A1-3"), md.index("A1-1"), md.index("A1-2")]
        self.assertEqual(order, sorted(order), f"정렬 뒤집힘:\n{md}")

    def test_prose_fix_cost_does_not_break_sort(self):
        # fix_cost에 산문이 섞여도(비교자가 NaN 안 나게) 정렬이 결정론이어야 (§9.2)
        data = {"meta": META_OK, "findings": [f("A1-1", "HIGH", "M — 훅 20줄"), f("A1-2", "HIGH", "S")],
                "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 0, err)
        self.assertLess(md.index("A1-2"), md.index("A1-1"), "S가 M보다 먼저여야 (산문 섞여도)")

    def test_codex_absent_banner(self):
        m = dict(META_OK); m["codex"] = {"ran": False}
        data = {"meta": m, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [], "degraded": [{"what": "codex 미실행", "why": "x"}]}
        rc, md, _ = render(data)
        head = "\n".join(md.splitlines()[:20])
        self.assertIn("codex", head.lower())
        self.assertIn("⚠", head)

    def test_all_axes_dead_no_report(self):  # AC-4(a)
        data = {"meta": META_OK, "findings": [], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [{"axis": i, "why": "죽음"} for i in range(1, 7)],
                "degraded": []}
        rc, md, err = render(data)
        self.assertEqual(rc, 1, "6축 전멸인데 리포트를 만들었다 (AC-4a)")

    def test_partial_axes_banner(self):  # AC-4(b)
        data = {"meta": META_OK, "findings": [f("A1-1", "HIGH", "S")], "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [], "axis_failures": [{"axis": 2, "why": "x"}], "degraded": [{"what": "x", "why": "y"}]}
        rc, md, _ = render(data)
        head = "\n".join(md.splitlines()[:20])
        self.assertIn("/6", head)  # "5/6 축 완주" 류

    def test_deep_verified_three_states(self):  # §9.2
        data = {"meta": META_OK, "findings": [
            f("A1-1", "HIGH", "S", deep_verified=True),
            f("A1-2", "HIGH", "S", deep_verified=False),
            f("A1-3", "MEDIUM", "S", deep_verified=None)],
            "d_verdicts": [], "oq_answers": [], "new_open_questions": [], "axis_failures": [], "degraded": []}
        rc, md, _ = render(data)
        # false = "상한 초과" 라벨, null = 무라벨
        self.assertIn("상한 초과", md)

    def test_noq_section_and_cross_model_badge(self):
        data = {"meta": META_OK,
                "findings": [f("A1-1", "HIGH", "S", cross_model_confirmed=True)],
                "d_verdicts": [], "oq_answers": [],
                "new_open_questions": [{"id": "NOQ-1", "source": "claude", "axis": 3,
                                        "observation": "obs", "why_not_gap": "LD5 밖", "evidence": []}],
                "axis_failures": [], "degraded": []}
        rc, md, _ = render(data)
        self.assertIn("NOQ-1", md)
        self.assertIn("obs", md)
        self.assertIn("⚑", md)  # cross-model 배지


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

Run: `python3 -m unittest scripts.tests.test_render_audit_report -v`
Expected: 전부 FAIL/error (미작성).

- [ ] **Step 3: render-audit-report.py 작성**

```python
#!/usr/bin/env python3
"""render-audit-report.py — audit-data.json → 마크다운 (design §11·§16).

렌더러는 신규 load-bearing 코드다: 정렬은 순회가 아니라 4단 비교자이고 두 키 모두 비-사전순
서수다 (순진한 문자열 비교가 CRITICAL<HIGH, L<M<S로 조용히 뒤집는다). fix_cost에 산문이 섞이면
비교자가 NaN을 낸다 → 첫 글자만 본다. AC-4: 6축 전멸이면 리포트를 안 만든다 (빈 감사는 감사가 아니다).
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

SEV_RANK = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
COST_RANK = {"S": 0, "M": 1, "L": 2}


def cost_key(fix_cost) -> int:
    """산문이 섞여도(예: 'M — 훅 20줄') 첫 유효 글자로 서수를 뽑는다 (NaN 방지, §9.2)."""
    if not isinstance(fix_cost, str):
        return 99
    for ch in fix_cost.strip():
        if ch in COST_RANK:
            return COST_RANK[ch]
    return 99


def sort_key(f: dict):
    return (SEV_RANK.get(f.get("severity"), 99), cost_key(f.get("fix_cost")),
            0 if f.get("reference_gap") not in (None, "none") else 1, f.get("id", ""))


def deep_label(f: dict) -> str:
    dv = f.get("deep_verified")
    if dv is True:
        return " (심층검증 통과)"
    if dv is False:
        return " (심층검증 미실시 — 상한 초과)"
    return ""   # null → 무라벨


def render(data: dict) -> str | None:
    meta = data.get("meta", {})
    findings = [f for f in data.get("findings", []) if f.get("status") == "reported"]
    axis_failures = data.get("axis_failures", [])
    degraded = data.get("degraded", [])

    if len(axis_failures) >= 6:
        return None  # AC-4(a): 빈 감사는 감사가 아니다

    lines = ["# project-init 읽기전용 감사 — " + meta.get("date", "")]
    banners = []
    if axis_failures:
        banners.append(f"⚠ **{6 - len(axis_failures)}/6 축 완주** — {len(axis_failures)}개 축 감사 실패")
    if not meta.get("codex", {}).get("ran"):
        banners.append("⚠ **codex 독립 감사 미실행** — LD4 모델 다양성 결손")
    if degraded:
        banners.append(f"⚠ **degraded {len(degraded)}건** — 아래 결손 목록 참조")
    if not findings:
        banners.append("⚠ **발견 0건** — 이것이 *깨끗함*인지 *감사 실패*인지 축 완주 수와 journal로 확인하라")
    lines += banners + [""]

    findings.sort(key=sort_key)
    lines.append("## 발견")
    for f in findings:
        badge = " ⚑ 두 모델 독립 확인" if f.get("cross_model_confirmed") else ""
        lines.append(f"### [{f.get('severity')}] {f.get('title')} ({f.get('id')}){badge}{deep_label(f)}")
        for ev in f.get("evidence", []):
            lines.append(f"- `{ev.get('file')}:{ev.get('line')}` — {ev.get('quote')}")
        lines.append(f"- 피해: {f.get('user_harm')}")
        lines.append(f"- 권고: {f.get('recommendation')}")
        lines.append(f"- 반대근거: {f.get('counter_argument')}")
        if f.get("reference_gap") not in (None, "none"):
            lines.append(f"- 레퍼런스 격차: {f.get('reference_gap')}")
        lines.append("")

    noqs = data.get("new_open_questions", [])
    if noqs:
        lines.append("## 열린 질문 (NOQ — 갭은 아니나 조용히 버리지 않는다)")
        for q in noqs:
            lines.append(f"- **{q.get('id')}** (축{q.get('axis')}): {q.get('observation')} "
                         f"— *왜 갭이 아닌가*: {q.get('why_not_gap')}")
        lines.append("")

    if degraded:
        lines.append("## 결손 (degraded)")
        for x in degraded:
            lines.append(f"- {x.get('what')} — {x.get('why')}")
        lines.append("")

    return "\n".join(lines) + "\n"


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("json", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--readme", type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.json.read_text(encoding="utf-8"))
    md = render(data)
    if md is None:
        print("[render] 6축 전멸 — 리포트를 만들지 않는다 (AC-4a). 실패 보고 후 중단.", file=sys.stderr)
        return 1
    args.out.write_text(md, encoding="utf-8")
    # docs/audits/README.md 인덱스에 항목 추가 (Law 3 discoverability)
    entry = f"- [{args.out.stem}]({args.out.name}) — {data.get('meta', {}).get('date', '')}\n"
    if args.readme.is_file():
        prev = args.readme.read_text(encoding="utf-8")
        if args.out.name not in prev:
            args.readme.write_text(prev + entry, encoding="utf-8")
    else:
        args.readme.write_text("# 감사 인덱스\n\n" + entry, encoding="utf-8")
    print(f"[render] {args.out} ({len(md.splitlines())} 줄)", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: GREEN 확인**

Run: `python3 -m unittest scripts.tests.test_render_audit_report -v`
Expected: 전체 PASS.

- [ ] **Step 5: mutation 재확인** (수동) — `cost_key`를 `COST_RANK.get(fix_cost, 99)`(전체 문자열 lookup)로 바꾸면 `test_prose_fix_cost_does_not_break_sort` FAIL(산문값이 99로 밀림) → 복원. `sort_key`의 `SEV_RANK` 대신 문자열 비교로 바꾸면 `test_sort_severity_then_cost` FAIL → 복원.

- [ ] **Step 6: 커밋**

```bash
git add scripts/render-audit-report.py scripts/tests/test_render_audit_report.py
git commit -m "feat(audit): render-audit-report 신규 — 4단 정렬·3-상태·NOQ·배지·AC-4 골든 픽스처"
```

---

## Task 12: 전체 스위트 통합 실행 + 실행 순서 문서화

**Files:**
- Create: `scripts/tests/README.md` (실행법 + 감사 RUN 순서)

**Interfaces:**
- Consumes: 앞 태스크의 모든 스크립트·테스트.
- Produces: `docs`가 아닌 `scripts/tests/README.md`에 (a) 테스트 실행법, (b) 감사 RUN의 pre-0~post-1 게이트 순서(설계 §6·§20 요약)를 적어 미래 orchestrator가 찾게 한다.

- [ ] **Step 1: 전체 스위트 실행 (회귀 확인)**

Run:
```bash
python3 -m unittest discover -s scripts/tests -t . -v
node --test scripts/tests/
```
Expected: Python 전 test PASS, Node 전 test PASS.

- [ ] **Step 2: 실제 게이트 3종을 실제 표면에 실행 (스모크)**

Run:
```bash
python3 scripts/check-law2.py scripts/audit-workflow.js
python3 scripts/check-law2.py scripts/smoke-workflow.js --mode smoke
python3 scripts/check-no-verdict-injection.py
bash scripts/check-integrity.sh ld5 /tmp/ld5.txt && bash scripts/check-integrity.sh harness /tmp/h.txt
python3 scripts/check-staleness.py plugins/project-init | head -5
```
Expected: check-law2 GREEN x2 · check-no-verdict-injection GREEN(5 표면) · check-integrity 두 매니페스트 생성 · check-staleness가 유효 JSON(`{"facts": [...]}`) 출력.

> ⚠️ `/tmp/*.txt`는 실측용 임시 산출물 — 커밋하지 않는다. (bg 세션은 `$CLAUDE_JOB_DIR/tmp` 권장.)

- [ ] **Step 3: `scripts/tests/README.md` 작성** — 실행법 + RUN 순서 (설계 §6·§20 요약)

```markdown
# 감사 하니스 — 테스트 & 실행 순서

## 테스트 실행
- Python: `python3 -m unittest discover -s scripts/tests -t . -v` (리포 root에서)
- Node:   `node --test scripts/tests/`

## 감사 RUN 순서 (orchestrator = 메인 루프, 설계 §6·§20)
1. **agent 파일 커밋 + 세션 재시작** — 레지스트리는 세션 시작에 스냅샷된다 (가정 i).
2. **phase 0** 지출 동의 게이트 (`AskUserQuestion`, fanout 30) → consent artifact. clean worktree 선결.
3. **pre-0** `check-law2.py` (audit + smoke) → `check-no-verdict-injection.py` → 미니-workflow 스모크
   (sentinel 파일 부재를 디스크에서 확인).
4. **pre-1** LD5-0 스냅샷 → 대상 자체 테스트 실행(`-B`) → `check-staleness.py` → evidence pack 조립
   → codex blind(`-s read-only`) → LD5-1=BEFORE + `LD5-0==LD5-1` 검사.
5. **Workflow** `audit-workflow.js` (6축 pipeline) → findings 반환.
6. **post-1** AFTER#1 → audit-data.json 조립(codex D/OQ/NOQ 병합 + **배정 D/OQ backfill** + cross-model +
   **gate-E→NOQ 회수** + steelman pending 해소) → secret scan → journal 복사 →
   `validate-audit-data.py --data` → `render-audit-report.py` → CLAUDE.md 포인터 →
   `validate-audit-data.py --artifacts` → AFTER#2 → 커밋(scripts/** 포함).

## Law 2 3층 (설계 §16)
(a) agent `tools:` allowlist ✅ · (b) 미니-workflow 스모크 ✅(이 계획) · (c) 무결성 스냅샷 ✅.
```

- [ ] **Step 4: 커밋**

```bash
git add scripts/tests/README.md
git commit -m "docs(audit): 하니스 테스트 실행법 + 감사 RUN 게이트 순서 (§6·§20)"
```

---

## Self-Review

**1. Spec coverage (§14 16행):**
- row 1 (판정 주입 전수) → Task 2 (+ 게이트 Task 1)
- row 2 (AXIS① D2) → Task 2 Step 5 + Task 3 (question grep)
- row 3 (enum D2) → Task 3
- row 4 (CONTRACT 렌더) → Task 4
- row 5 (deep_verified) → Task 5
- row 6 (reference_gap 필수) → Task 3
- row 7 (gate 조건부) → Task 3
- row 8 (gate-E→NOQ) → Task 10 (validate 이빨) + RUN(Task 12 §6 순서)
- row 9 (marketplace global 제외) → Task 7
- row 10 (헤더 주석 3-스코프) → Task 7
- row 11 (frontmatter tools) → Task 6
- row 12 (BANNED 동기화) → Task 1
- row 13 (byte→semantic 두 곳) → Task 2 Step 8
- row 14 (axis 1-6) → Task 3
- row 15 (주석 문면) → Task 2 Step 10 + Task 6 Step 4
- row 16 (backfill) → Task 10 (완결성 이빨) + RUN(Task 12 §6)

**신규 스크립트:** check-staleness(Task 8)·smoke-workflow(Task 9)·validate-audit-data(Task 10)·render-audit-report(Task 11). 전부 test 동반. ✓

**2. Placeholder scan:** 모든 코드 Step에 실제 코드/명령/기대 출력 포함. `TODO`/`TBD`/"적절히 처리" 없음. check-staleness의 나머지 5클래스(Task 8 Step 6)는 요지+패턴을 주되 대표 3클래스의 완전 코드가 템플릿 역할 — 구현자가 같은 (함수+fixture+mutation) 패턴을 반복. ✓

**3. Type consistency:**
- `runWorkflow(scriptRel, opts)` → `{result, captured, calls}` (Task 3 정의, Task 4·5·9에서 동일 시그니처 사용). ✓
- `stubOneFinding(severity, extra)` (Task 3) → Task 4·5 재사용. ✓
- audit-data.json 스키마: validate(Task 10)와 render(Task 11)가 동일 필드(`findings[].status`·`deep_verified`·`cross_model_confirmed`·`refutation.gate`·NOQ `why_not_gap`) 사용. ✓
- check-staleness 출력 `{"facts":[{class,file,line,quote}]}` (Task 8) — CONTRACT 렌더(Task 4)가 `staleness_facts[].{class,file,line,quote}` 소비 — 필드명 일치. ✓

**주의 (구현자):** Task 2·3·4·5는 모두 `audit-workflow.js`를 편집한다. subagent-driven은 순차 실행이므로 충돌 없으나, **각 태스크 후 `node --test scripts/tests/audit-workflow.test.mjs`로 이전 태스크 회귀를 확인**하라. Task 3의 row 7 if/then 스키마는 Workflow 런타임의 JSON-schema 해석에 의존 — 미니-workflow 스모크(RUN pre-0c) 전에는 실런타임 검증이 안 되므로, 유닛에서는 스키마 *구조*만 assert한다 (하니스 stub는 schema를 강제하지 않는다).
