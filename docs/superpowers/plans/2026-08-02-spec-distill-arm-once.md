# spec-distill arm-once Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** design doc auto-review(Layer 2)를 문서가 처음 생길 때 한 번만 발동시키고, 그 재발동을 막으려 존재하던 방어 하니스 4층(`suppress_state.py`·`review_lock.py`·`cancel_review.py`·`approve_handoff.sh`)을 삭제한다.

**Architecture:** arm 판정을 `scripts/arm_ledger.py` 한 파일로 모으고(`should_arm = not is_armed and not is_born`), PostToolUse validator가 arm 직전 그 게이트를 통과해야만 `pending_review`를 쓴다. 원장(`armed_paths`)은 **verdict가 나온 리뷰가 자기 완료를 기록**하며, verdict 없이 끝난 재시도는 `dispatch_attempts`로 세션당·문서당 3회에서 멈춘다. 리뷰 진행 중 오발은 락이 아니라 `reviewing-spec` 진입 시 pending strip(연료 제거)으로 닫는다.

**Tech Stack:** Python 3 (표준 라이브러리만, hook + CLI), bash (테스트 하니스), git plumbing(`git ls-files --error-unmatch`), Claude Code hooks(PostToolUse/Stop/UserPromptSubmit).

**Spec:** `docs/superpowers/specs/2026-08-01-spec-distill-arm-once-design.md` (§ 참조는 전부 이 문서)

## Global Constraints

- **작업 위치**: `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+spec-distill-arm-once` (브랜치 `worktree-feature+spec-distill-arm-once`, base `e45619b`). 모든 편집·명령을 이 절대경로 아래에서 수행한다. 원본 리포 루트로 `cd` 하지 않는다.
- **버전**: `plugins/spec-distill/.claude-plugin/plugin.json` 0.24.4 → **0.25.0** (Task 10). devbrew 규약상 플러그인을 건드리는 PR은 반드시 bump.
- **문서 언어**: Korean-primary. 영어는 식별자·고유명사·원문 인용·번역어색 기술어에만.
- **Python 테스트 실행**: `python3 -m unittest` 로만 (`pytest` 금지).
- **베이스라인 red 2건** (회귀로 오인 금지):
  - `tests/test_stale_terms.sh` — Task 1이 고치는 F0.
  - `tests/test_hook_output_schema.py::TestCrossResolverAdvisory::test_python_and_bash_resolvers_agree` — 워크트리 환경 의존(python은 main repo `.claude/`, bash는 워크트리 `.claude/`로 해석). 이 계획은 건드리지 않는다. (초안은 클래스명을 `TestSessionIdResolution`으로 잘못 적었다 — 실제 정의는 `tests/test_hook_output_schema.py:503`. 잘못된 이름으로 grep하면 "알려진 red가 존재하지 않는다"는 오판이 나오고, 진짜 red를 회귀로 오인하게 된다.)
- **다중-dispatch 테스트 픽스처는 반드시 `DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0`** (§10 lock — 계획 재량 아님). `review-dispatch.py`의 30초 redispatch TTL 가드가 원장 게이트 없이도 두 번째 emit을 막아버려, 이걸 빼면 "원장 게이트 제거 → RED" mutation 주장이 성립하지 않고 락이 이빨을 잃는다.
- **모든 신규 회귀 락은 mutation으로 이빨을 증명**하고 결과를 커밋 메시지에 남긴다. 통과가 정답인 assert는 모양만으로 판별할 수 없다.
- **커밋 메시지**는 Conventional Commits + 아래 trailer로 끝난다:
  ```
  Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
  ```
- **git stash 금지**: stash 스택은 워크트리 간 공유다. 작업을 치워야 하면 임시 WIP 커밋을 쓴다.
- **`git ls-files --error-unmatch` exit code 실측**(이 리포, git 2.50.1): tracked=0, untracked(존재하든 안 하든)=1, 리포 밖=128.

### 설계와의 명시적 편차 2건 (silent drift 아님)

1. **python 스위트 개수**: §10 종료 조건은 "삭제 2를 반영해 8종"이라 적었으나, §12 구현 순서 2번이 `arm_ledger.py`의 **단위 테스트를 TDD로 먼저** 쓸 것을 요구한다. 그 테스트의 자연스러운 집은 `tests/test_arm_ledger.py`(신규)이므로 python 스위트는 **9종**이 된다. §10이 못 박은 진짜 종료 조건은 개수가 아니라 **red 0건**이다.
2. **README stale-term 제거 시점**: §12 순서는 "6. 삭제 스윕(→T4·T5) → 7. 문서 동기화"지만, T4의 스윕 스코프는 `README.md`를 포함하는 production 전수다. 순서를 문자 그대로 따르면 Task 9 끝에 T4가 README 때문에 RED가 되고 Task 10에서야 초록이 된다 — 태스크마다 green으로 끝난다는 규약 위반. 그래서 **README·SKILL의 죽은 참조 제거를 Task 9(삭제 스윕)에 포함**하고, T4·T5 락과 버전/CHANGELOG 서사를 Task 10에 둔다. §12의 lock된 의존(2→3, 3·4→6)은 그대로 지킨다.

## File Structure

### 신규

| 파일 | 책임 |
|---|---|
| `plugins/spec-distill/scripts/arm_ledger.py` | arm 판정의 단일 지점(§5.1·G4). 정규화·원장 읽기/쓰기·git 조회·G6 상태기계 |
| `plugins/spec-distill/tests/test_arm_ledger.py` | `arm_ledger` 단위 테스트 (python) |
| `plugins/spec-distill/tests/arm_test_helpers.sh` | 두 신규 스위트가 `source` 하는 공유 하니스 (**source 전용** — `test_` 접두어 없음). pre-flight ruling |
| `plugins/spec-distill/tests/test_arm_once.sh` | T1·T2·T3 — arm 게이트 통합 락 |
| `plugins/spec-distill/tests/test_arm_ledger_timing.sh` | T6–T12 — 기록 시점·자기치유·G6 상한·훅 통합·check-born·fail-safe 배제 |

### 수정

| 파일 | 변경 |
|---|---|
| `hooks/spec-write-validator.py` | suppression 게이트 → arm 게이트, advisory 3사유 |
| `hooks/review-dispatch.py` | suppress·lock 블록 삭제, `dispatch_attempts` 증가, G6 상한 도달 시에만 `armed_paths` |
| `hooks/pending-review-reminder.py` | lock 블록 삭제 |
| `skills/reviewing-spec/SKILL.md` | 락 절 → `strip-pending`, Step 3 → `mark-reviewed`(both-dead 배제), handoff 절 → `check-born`, 매핑표 삭제 |
| `skills/conducting-interview/SKILL.md` | `:469` `approve_handoff.sh` 참조 제거 |
| `tests/test_spec_write_validator.sh` | Case 12–14를 `armed_paths` 기준으로 |
| `tests/test_review_dispatch.sh` | Case 16–20(suppress·lock) 제거, `dispatch_attempts` 케이스 추가 |
| `tests/test_reminder_hook.sh` | AC5a/AC5b(lock) 제거 |
| `tests/test_hook_output_schema.py` | suppress fail-open 테스트 → validator arm-gate fail-open |
| `tests/test_stale_terms.sh` | F0(find 앵커) + T4·T5 |
| `tests/test_readme_sync.sh` | 죽은 키워드 3종 제거, 0.25.x |
| `README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` | 0.25.0 동기화 |

### 삭제 (Task 9)

```
scripts/review_lock.py            scripts/cancel_review.py
scripts/approve_handoff.sh        scripts/suppress_state.py
commands/cancel-review.md
tests/test_review_lock.py         tests/test_review_lock_session_id.sh
tests/test_reviewing_spec_lock.sh tests/test_cancel_review.py
tests/test_approve_handoff.sh     tests/test_handoff_compact_chain.sh
tests/test_handoff_spec_path_validation.sh
```

스위트 규모: bash `test_*.sh` 51 − 5 + 2 = **48**, python 10 − 2 + 1 = **9**. `arm_test_helpers.sh` 는 실행 대상이 아니므로 이 셈에 들어가지 않는다 — **스위트를 도는 루프는 반드시 `tests/test_*.sh` 로 글롭한다**(`tests/*.sh` 로 돌면 헬퍼를 테스트로 실행하고 개수가 어긋난다).

---

### Task 1: F0 — `test_stale_terms.sh` find 앵커 수정

다른 모든 검증의 전제다. `-not -path '*/.claude/*'`에 앵커가 없어서, 하니스 워크트리(`<repo>/.claude/worktrees/<name>/`) 안에서는 production 파일 47개가 전부 걸러진다. 락은 empty-guard 덕분에 조용히 통과하지 않고 FAIL하지만, **워크트리에서는 실행 자체가 불가능**하다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_stale_terms.sh:18-21` (주석), `:45-50` (find)

**Interfaces:**
- Consumes: 없음
- Produces: 워크트리에서 실행 가능한 `prod_files` 배열 — Task 10의 T4·T5가 이 집합 위에 얹힌다

- [ ] **Step 1: 현재 RED 확인 (베이스라인)**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+spec-distill-arm-once/plugins/spec-distill
bash tests/test_stale_terms.sh; echo "rc=$?"
```

Expected: `✗ V7: no production files found — find filter broken` / `Total: 1 | Pass: 0 | Fail: 1` / `rc=1`

- [ ] **Step 2: 필터가 실제로 0개를 만드는지 실측**

```bash
SD="$PWD"
echo "현재: $(find "$SD" -type f -not -path '*/tests/*' -not -name 'CHANGELOG.md' -not -path '*/.claude/*' -not -path '*/.pytest_cache/*' -not -path '*/__pycache__/*' -not -path '*/.git/*' | wc -l)"
echo "앵커: $(find "$SD" -type f -not -path '*/tests/*' -not -name 'CHANGELOG.md' -not -path "$SD/.claude/*" -not -path '*/.pytest_cache/*' -not -path '*/__pycache__/*' -not -path '*/.git/*' | wc -l)"
```

Expected: `현재: 0` / `앵커: 47`

- [ ] **Step 3: 앵커 수정**

`tests/test_stale_terms.sh` 의 find 블록에서 이 한 줄을

```bash
    -not -path '*/.claude/*' \
```

아래로 바꾼다 (작은따옴표 → 큰따옴표. `$SD` 가 확장돼야 앵커가 걸린다):

```bash
    -not -path "$SD/.claude/*" \
```

같은 커밋에서 헤더 주석 (4)번 항목의 마지막 문장도 고친다 — 주석이 코드보다 오래된 주장을 하면 안 된다:

```
#           .claude-plugin/은 production이라 제외되지 않는다 — 패턴이 '*/.claude/*'라 안 걸린다.
```

→

```
#           패턴은 **$SD 기준으로 앵커**한다('*/.claude/*'는 앵커가 없어, 하니스 워크트리가
#           <repo>/.claude/worktrees/<name>/ 아래 사는 순간 production 전량을 삼켰다 — 락이
#           워크트리에서 실행 불가였다). .claude-plugin/은 이름이 달라 여전히 제외되지 않는다.
```

- [ ] **Step 4: GREEN 확인**

```bash
bash tests/test_stale_terms.sh; echo "rc=$?"
```

Expected: `Total: 9 | Pass: 9 | Fail: 0` / `rc=0` (V7a·V7b×2 + V8 6개 리터럴)

- [ ] **Step 5: mutation — 앵커를 되돌리면 RED**

```bash
sed -i.bak 's|-not -path "$SD/\.claude/\*"|-not -path '"'"'*/.claude/*'"'"'|' tests/test_stale_terms.sh
bash tests/test_stale_terms.sh; echo "mutated rc=$?"   # 기대: rc=1, "find filter broken"
mv tests/test_stale_terms.sh.bak tests/test_stale_terms.sh
bash tests/test_stale_terms.sh; echo "restored rc=$?"  # 기대: rc=0
```

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/tests/test_stale_terms.sh
git commit -m "$(cat <<'EOF'
fix(spec-distill): F0 — stale-term 락의 find 필터를 $SD 기준으로 앵커

'*/.claude/*'는 앵커가 없어 하니스 워크트리(<repo>/.claude/worktrees/)
안에서 production 파일 47개를 전부 삼켰다. 락은 empty-guard로 FAIL하지만
워크트리에서 실행 자체가 불가능했다.

mutation: 앵커 제거 → "find filter broken" RED 확인.
실측: 워크트리 0개 → 47개.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: `arm_ledger.py` + 단위 테스트 (TDD)

§5.1의 판정과 §5.2의 기록 시점을 한 파일에 담는다. 훅·skill 이 부르는 유일한 진입점이므로 이 태스크가 뒤 태스크 전부의 인터페이스를 확정한다.

**Files:**
- Create: `plugins/spec-distill/scripts/arm_ledger.py`
- Create: `plugins/spec-distill/tests/test_arm_ledger.py`

**Interfaces:**
- Consumes: `hooks/state_path.py` 의 `state_root()`, `SESSION_PATTERN`
- Produces (뒤 태스크가 이 이름·시그니처에 의존한다):
  - `canonical_key(raw_path: str) -> str | None`
  - `state_file_for(sid: str) -> Path`
  - `pending_path(body: str) -> str | None`
  - `strip_pending(body: str) -> str`
  - `armed_keys(body: str) -> list[str]`
  - `attempts(body: str) -> dict[str, int]`
  - `is_armed(state_file: Path, raw_path: str) -> bool`
  - `is_born(raw_path: str) -> bool`
  - `should_arm(state_file: Path, raw_path: str) -> bool`  ← 훅의 유일한 판정 진입점
  - `skip_reason(state_file: Path, raw_path: str) -> str`  ← `"reviewed"|"capped"|"born"|"out-of-scope"`
  - `mark_armed(body: str, raw_path: str) -> str`  ← 파일 write 안 함
  - `next_attempt(body: str, raw_path: str) -> int`
  - `record_attempt(body: str, raw_path: str, n: int) -> str`
  - `mark_reviewed(state_file: Path, raw_path: str) -> bool`
  - `strip_pending_file(state_file: Path, raw_path: str) -> bool`
  - `DISPATCH_ATTEMPT_CAP = 3`
  - CLI: `strip-pending <sid> <raw>` / `mark-reviewed <sid> <raw>` / `check-born <raw>` (exit 0=born, 1=미커밋+advisory, 2=usage/out-of-scope)

> §6 표가 lock한 공개 API 위에 `attempts`/`next_attempt`/`record_attempt`/`skip_reason`/`mark_reviewed`/`strip_pending_file` 을 더한다. 전부 §5.2가 요구하는 동작(`dispatch_attempts` 증가·verdict 시 삭제·3사유 advisory)의 구현 수단이며, 판정 논리식과 `should_arm` 단일 진입점 규칙은 그대로다.

- [ ] **Step 1: 실패하는 단위 테스트를 먼저 쓴다**

`plugins/spec-distill/tests/test_arm_ledger.py`:

```python
#!/usr/bin/env python3
"""arm_ledger 단위 테스트 (v0.25.0) — §5.1 판정 · §5.2 기록 시점 · G6 상한."""
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

PLUGIN_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PLUGIN_ROOT / "hooks"))
sys.path.insert(0, str(PLUGIN_ROOT / "scripts"))
import arm_ledger  # noqa: E402

SPEC = "docs/superpowers/specs/2026-08-01-x-design.md"
OTHER = "docs/superpowers/specs/2026-08-01-y-design.md"
HEAD = "---\nsession_id: test-sid\n---\n\n"


def _make_repo() -> Path:
    repo = Path(tempfile.mkdtemp(prefix="armledger-")).resolve()
    subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.email", "t@t.t"], cwd=repo, check=True)
    subprocess.run(["git", "config", "user.name", "t"], cwd=repo, check=True)
    return repo


class TestCanonicalKey(unittest.TestCase):
    def test_absolute_worktree_and_relative_map_to_same_key(self):
        self.assertEqual(arm_ledger.canonical_key(f"/a/b/{SPEC}"), SPEC)
        self.assertEqual(arm_ledger.canonical_key(SPEC), SPEC)
        self.assertEqual(
            arm_ledger.canonical_key(f"/r/.claude/worktrees/wt/{SPEC}"), SPEC)

    def test_out_of_scope_is_none(self):
        self.assertIsNone(arm_ledger.canonical_key("/tmp/x-design.md"))
        self.assertIsNone(arm_ledger.canonical_key(""))


class TestLedgerBody(unittest.TestCase):
    def test_mark_armed_is_idempotent(self):
        body = arm_ledger.mark_armed(HEAD, f"/w/{SPEC}")
        body2 = arm_ledger.mark_armed(body, SPEC)
        self.assertEqual(arm_ledger.armed_keys(body2), [SPEC])

    def test_mark_armed_out_of_scope_is_noop(self):
        self.assertEqual(arm_ledger.mark_armed(HEAD, "/tmp/z.md"), HEAD)

    def test_attempts_roundtrip(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, 2)
        self.assertEqual(arm_ledger.attempts(body), {SPEC: 2})

    def test_record_attempt_below_cap_does_not_arm(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, 1)
        body = arm_ledger.record_attempt(body, SPEC, 2)
        self.assertEqual(arm_ledger.armed_keys(body), [])
        self.assertEqual(arm_ledger.attempts(body), {SPEC: 2})

    def test_record_attempt_at_cap_arms(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, arm_ledger.DISPATCH_ATTEMPT_CAP)
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertEqual(arm_ledger.attempts(body)[SPEC],
                         arm_ledger.DISPATCH_ATTEMPT_CAP)

    def test_next_attempt_counts_from_zero_and_ignores_out_of_scope(self):
        self.assertEqual(arm_ledger.next_attempt(HEAD, SPEC), 1)
        body = arm_ledger.record_attempt(HEAD, SPEC, 2)
        self.assertEqual(arm_ledger.next_attempt(body, SPEC), 3)
        self.assertEqual(arm_ledger.next_attempt(body, "/tmp/z.md"), 0)

    def test_other_document_entries_survive(self):
        body = arm_ledger.record_attempt(HEAD, OTHER, 1)
        body = arm_ledger.mark_armed(body, SPEC)
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertEqual(arm_ledger.attempts(body), {OTHER: 1})

    def test_strip_pending_preserves_ledger_blocks(self):
        body = arm_ledger.mark_armed(HEAD, SPEC)
        body = body.rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        stripped = arm_ledger.strip_pending(body)
        self.assertNotIn("pending_review:", stripped)
        self.assertEqual(arm_ledger.armed_keys(stripped), [SPEC])


class TestIsBorn(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        (self.repo / "docs/superpowers/specs").mkdir(parents=True)

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_tracked_document_is_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))

    def test_staged_only_document_is_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        self.assertTrue(arm_ledger.is_born(SPEC))

    def test_untracked_document_is_not_born(self):
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        self.assertFalse(arm_ledger.is_born(SPEC))

    def test_dangling_path_is_not_born_and_does_not_raise(self):
        self.assertFalse(arm_ledger.is_born(SPEC))

    def test_outside_repo_falls_open_to_not_born(self):
        outside = Path(tempfile.mkdtemp(prefix="armledger-norepo-")).resolve()
        try:
            os.chdir(outside)
            self.assertFalse(arm_ledger.is_born(str(outside / SPEC)))
        finally:
            os.chdir(self.repo)
            shutil.rmtree(outside, ignore_errors=True)


class TestShouldArmAndSkipReason(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        (self.repo / "docs/superpowers/specs").mkdir(parents=True)
        (self.repo / SPEC).write_text("x\n", encoding="utf-8")
        self.state = self.repo / "state.local.md"
        self.state.write_text(HEAD, encoding="utf-8")

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def _commit(self):
        subprocess.run(["git", "add", SPEC], cwd=self.repo, check=True)
        subprocess.run(["git", "commit", "-qm", "b"], cwd=self.repo, check=True)

    def test_fresh_untracked_document_arms(self):
        self.assertTrue(arm_ledger.should_arm(self.state, SPEC))

    def test_ledger_entry_blocks_arm(self):
        self.state.write_text(arm_ledger.mark_armed(HEAD, SPEC), encoding="utf-8")
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "reviewed")

    def test_git_tracked_blocks_arm_even_with_empty_ledger(self):
        self._commit()
        self.assertEqual(arm_ledger.armed_keys(self.state.read_text()), [])
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "born")

    def test_cap_reached_reports_capped_not_reviewed(self):
        body = arm_ledger.record_attempt(HEAD, SPEC, arm_ledger.DISPATCH_ATTEMPT_CAP)
        self.state.write_text(body, encoding="utf-8")
        self.assertFalse(arm_ledger.should_arm(self.state, SPEC))
        self.assertEqual(arm_ledger.skip_reason(self.state, SPEC), "capped")

    def test_missing_state_file_falls_open_to_arm(self):
        self.state.unlink()
        self.assertTrue(arm_ledger.should_arm(self.state, SPEC))


class TestFileLevelWrites(unittest.TestCase):
    def setUp(self):
        self.repo = _make_repo()
        self.cwd = os.getcwd()
        os.chdir(self.repo)
        self.state = self.repo / "state.local.md"

    def tearDown(self):
        os.chdir(self.cwd)
        shutil.rmtree(self.repo, ignore_errors=True)

    def test_mark_reviewed_arms_and_clears_attempts(self):
        self.state.write_text(
            arm_ledger.record_attempt(HEAD, SPEC, 2), encoding="utf-8")
        self.assertTrue(arm_ledger.mark_reviewed(self.state, SPEC))
        body = self.state.read_text(encoding="utf-8")
        self.assertEqual(arm_ledger.armed_keys(body), [SPEC])
        self.assertNotIn(SPEC, arm_ledger.attempts(body))

    def test_mark_reviewed_out_of_scope_returns_false(self):
        self.state.write_text(HEAD, encoding="utf-8")
        self.assertFalse(arm_ledger.mark_reviewed(self.state, "/tmp/z.md"))

    def test_strip_pending_file_only_touches_same_key(self):
        body = HEAD + (
            f"pending_review:\n  path: {OTHER}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        self.assertFalse(arm_ledger.strip_pending_file(self.state, SPEC))
        self.assertIn("pending_review:", self.state.read_text(encoding="utf-8"))
        self.assertTrue(arm_ledger.strip_pending_file(self.state, OTHER))
        self.assertNotIn("pending_review:", self.state.read_text(encoding="utf-8"))

    def test_strip_pending_file_does_not_touch_ledger(self):
        body = arm_ledger.mark_armed(HEAD, OTHER).rstrip() + (
            f"\n\npending_review:\n  path: {SPEC}\n  mode: design\n"
            "  triggered_at: 2026-08-01T00:00:00Z\n")
        self.state.write_text(body, encoding="utf-8")
        arm_ledger.strip_pending_file(self.state, SPEC)
        self.assertEqual(
            arm_ledger.armed_keys(self.state.read_text(encoding="utf-8")), [OTHER])


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: RED 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+spec-distill-arm-once/plugins/spec-distill
python3 -m unittest tests.test_arm_ledger -v 2>&1 | tail -5
```

Expected: `ModuleNotFoundError: No module named 'arm_ledger'`

- [ ] **Step 3: `scripts/arm_ledger.py` 구현**

```python
#!/usr/bin/env python3
"""spec-distill arm ledger — arm 판정의 단일 지점 (v0.25.0).

design doc auto-review(Layer 2)를 문서 생애 한 번만 발동시킨다.

    should_arm(state_file, path) =
          not is_armed(state_file, path)   # 세션 원장 — 세션 안쪽 시간축
      and not is_born(path)                # git 추적 여부 — 세션 바깥 시간축

`armed_paths`의 의미는 하나다: "더 이상 dispatch 안 함". 기록자는 둘이지만
(verdict = 완료, G6 상한 = 포기) 결론이 같다.

이 파일이 v0.14.0 `suppress_state.py`를 대체한다. 억제는 리뷰가 끝난 뒤 *제3자*가
사후 기록해야 해서 기록자가 셋 필요했고 빠뜨림을 막는 층이 그 위에 쌓였다. arm 원장은
리뷰 자신이 자기 완료를 기록하므로 그 층이 필요 없다.

CLI:
  arm_ledger.py strip-pending <sid> <raw_path>   # reviewing-spec Step 1 진입
  arm_ledger.py mark-reviewed <sid> <raw_path>   # reviewing-spec Step 3 (verdict)
  arm_ledger.py check-born    <raw_path>         # reviewing-spec approve(①/②)
                                                 #   0=git-tracked, 1=미커밋+advisory, 2=usage

Kill switch (CLI defense-in-depth): DEVBREW_DISABLE_SPEC_DISTILL=1 → no-op.
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
HOOKS_DIR = SCRIPT_DIR.parent / "hooks"
sys.path.insert(0, str(HOOKS_DIR))
from state_path import state_root, SESSION_PATTERN  # noqa: E402 # pyright: ignore[reportMissingImports]

PREFIX = "docs/superpowers/specs/"

#: G6 — verdict 없이 끝난 dispatch의 세션당·문서당 재시도 상한 (§5.2 상태기계).
DISPATCH_ATTEMPT_CAP = 3

#: PostToolUse 훅 전체 timeout이 10초라 git 호출은 그 절반으로 묶는다 (§8).
GIT_TIMEOUT_SEC = 5

PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)
ARMED_RE = re.compile(r"^armed_paths:\n((?:  - [^\n]+\n)*)", re.MULTILINE)
ATTEMPTS_RE = re.compile(r"^dispatch_attempts:\n((?:  [^\n]+\n)*)", re.MULTILINE)


def canonical_key(raw_path: str) -> str | None:
    """경로에서 PREFIX 이후 substring. 스코프 밖이면 None.

    워크트리·절대·상대 경로가 같은 문서를 같은 키로 매핑한다. 정규화는 이 함수에만 존재.
    """
    if not raw_path:
        return None
    idx = raw_path.find(PREFIX)
    if idx < 0:
        return None
    return raw_path[idx:]


def state_file_for(sid: str) -> Path:
    """sid → state.local.md 경로 단일 해석 (저장소 위치 변경 시 이 한 곳만 갱신)."""
    return state_root() / sid / "state.local.md"


def pending_path(body: str) -> str | None:
    m = PENDING_RE.search(body)
    if not m:
        return None
    for line in m.group(0).splitlines():
        ls = line.strip()
        if ls.startswith("path:"):
            return ls[len("path:"):].strip()
    return None


def strip_pending(body: str) -> str:
    """pending_review 블록 제거. 0-indent 원장 블록은 보존."""
    return PENDING_RE.sub("", body)


def armed_keys(body: str) -> list[str]:
    m = ARMED_RE.search(body)
    if not m:
        return []
    keys: list[str] = []
    for line in m.group(1).splitlines():
        ls = line.strip()
        if ls.startswith("- "):
            keys.append(ls[2:].strip())
    return keys


def attempts(body: str) -> dict[str, int]:
    m = ATTEMPTS_RE.search(body)
    if not m:
        return {}
    out: dict[str, int] = {}
    for line in m.group(1).splitlines():
        ls = line.strip()
        key, sep, val = ls.rpartition(": ")
        if not sep:
            continue
        try:
            out[key.strip()] = int(val.strip())
        except ValueError:
            continue
    return out


def _read_body(state_file: Path) -> str:
    """원장 read. 실패는 빈 body로 degrade — 판정은 arm 쪽으로 fail-open (§8)."""
    if not state_file.exists():
        return ""
    try:
        return state_file.read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] arm_ledger: 원장 read 실패 — 미기록으로 간주(arm): {exc}",
            file=sys.stderr,
        )
        return ""


def _compose(body: str, keys: list[str], att: dict[str, int]) -> str:
    """원장 두 블록을 재조립. 나머지 본문(frontmatter·pending·타임스탬프)은 보존."""
    rest = ATTEMPTS_RE.sub("", ARMED_RE.sub("", body)).rstrip()
    parts = [rest] if rest else []
    if keys:
        parts.append(
            "armed_paths:\n" + "".join(f"  - {k}\n" for k in keys).rstrip())
    if att:
        parts.append(
            "dispatch_attempts:\n"
            + "".join(f"  {k}: {n}\n" for k, n in sorted(att.items())).rstrip())
    return "\n\n".join(parts) + "\n"


def is_armed(state_file: Path, raw_path: str) -> bool:
    key = canonical_key(raw_path)
    if key is None:
        return False
    return key in armed_keys(_read_body(state_file))


def is_born(raw_path: str) -> bool:
    """git이 아는 문서면 True. 판정 실패는 전부 False(=arm 쪽)로 fail-open (§8).

    `git add`만 된 문서도 태어난 것으로 본다 — 저자가 리포에 넣기로 이미 결정했다는 뜻.
    """
    if not raw_path:
        return False
    try:
        cp = subprocess.run(
            ["git", "ls-files", "--error-unmatch", "--", raw_path],
            capture_output=True, text=True, check=False, timeout=GIT_TIMEOUT_SEC,
        )
    except (OSError, subprocess.TimeoutExpired) as exc:
        print(
            f"[spec-distill] arm_ledger: git ls-files 실행 실패 — "
            f"미커밋으로 간주(arm): {exc}",
            file=sys.stderr,
        )
        return False
    if cp.returncode == 0:
        return True
    if cp.returncode != 1:
        # 1 = 리포 안의 untracked(정상). 그 외(128=리포 밖 등)는 판정 불능이므로 loud.
        print(
            f"[spec-distill] arm_ledger: git ls-files exit={cp.returncode} "
            f"('{raw_path}') — 미커밋으로 간주(arm): {cp.stderr.strip()}",
            file=sys.stderr,
        )
    return False


def should_arm(state_file: Path, raw_path: str) -> bool:
    """훅이 부르는 유일한 arm 판정 진입점 (§5.1 · G4)."""
    return not is_armed(state_file, raw_path) and not is_born(raw_path)


def skip_reason(state_file: Path, raw_path: str) -> str:
    """should_arm이 False인 사유. 'reviewed'|'capped'|'born'|'out-of-scope'.

    git을 다시 부르지 않는다 — should_arm이 False인데 원장에 없다면 born이 유일하게
    남은 사유이기 때문이다. should_arm이 True일 때 부르면 의미가 없다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return "out-of-scope"
    body = _read_body(state_file)
    if key in armed_keys(body):
        # mark-reviewed는 완료 시 attempts 항목을 지운다 → 남아 있으면 G6 상한 도달.
        return "capped" if key in attempts(body) else "reviewed"
    return "born"


def mark_armed(body: str, raw_path: str) -> str:
    """키를 armed_paths에 멱등 추가해 **문자열로 반환** (파일 write 안 함 — §6 원자성).

    Stop 훅은 G6 상한에 닿는 그 순간에만 pending strip·attempts·armed·타임스탬프를
    하나의 write로 커밋해야 한다. 여기서 파일을 따로 쓰면 write가 둘로 갈라진다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return body
    keys = armed_keys(body)
    if key not in keys:
        keys.append(key)
    return _compose(body, keys, attempts(body))


def next_attempt(body: str, raw_path: str) -> int:
    """이번 dispatch가 몇 번째 시도인지 (순수 함수). 스코프 밖이면 0 = 추적 안 함."""
    key = canonical_key(raw_path)
    if key is None:
        return 0
    return attempts(body).get(key, 0) + 1


def record_attempt(body: str, raw_path: str, n: int) -> str:
    """§5.2 상태기계의 유일한 구현.

    | dispatch 1·2회차 | attempts 증가 | armed 불변 |
    | dispatch 3회차   | attempts=3    | armed 키 추가 |

    3회차가 마지막 자동 dispatch이고 그 emit이 상한을 알리는 vehicle이다.
    이후 편집은 validator의 should_arm이 false라 pending 자체가 생기지 않는다.
    """
    key = canonical_key(raw_path)
    if key is None or n <= 0:
        return body
    att = attempts(body)
    att[key] = n
    keys = armed_keys(body)
    if n >= DISPATCH_ATTEMPT_CAP and key not in keys:
        keys.append(key)
    return _compose(body, keys, att)


def mark_reviewed(state_file: Path, raw_path: str) -> bool:
    """verdict 시점 기록: armed_paths 추가 + dispatch_attempts 항목 삭제 (§5.2).

    완료된 리뷰는 시도 이력을 남길 이유가 없고, 남기면 다음 계산과 skip_reason에 섞인다.
    """
    key = canonical_key(raw_path)
    if key is None:
        return False
    body = _read_body(state_file)
    if not body:
        body = f"---\nsession_id: {state_file.parent.name}\n---\n\n"
    keys = armed_keys(body)
    if key not in keys:
        keys.append(key)
    att = attempts(body)
    att.pop(key, None)
    try:
        state_file.parent.mkdir(parents=True, exist_ok=True)
        state_file.write_text(_compose(body, keys, att), encoding="utf-8")
    except OSError as exc:
        print(
            f"[spec-distill] arm_ledger: 원장 write 실패 — 리뷰 완료 미기록"
            f"(같은 문서가 다시 dispatch될 수 있다): {exc}",
            file=sys.stderr,
        )
        return False
    return True


def strip_pending_file(state_file: Path, raw_path: str) -> bool:
    """같은 키의 pending만 제거 (다른 문서 pending 보존). 원장은 건드리지 않는다 (§5.4).

    dispatch의 연료는 pending이다. 리뷰 진입 시 연료를 없애면 v0.18.0 락이 상태로
    표현하던 불변식("이 문서 리뷰 진행 중")을 한 줄로 얻는다. 진입은 리뷰의 시작일
    뿐 완료가 아니므로 여기서 armed_paths를 쓰면 안 된다.
    """
    key = canonical_key(raw_path)
    if key is None or not state_file.exists():
        return False
    body = _read_body(state_file)
    pend = pending_path(body)
    if pend is None or canonical_key(pend) != key:
        return False
    try:
        state_file.write_text(strip_pending(body).rstrip() + "\n", encoding="utf-8")
    except OSError as exc:
        print(
            f"[spec-distill] arm_ledger: pending strip write 실패 "
            f"(리뷰 중 재dispatch 가능): {exc}",
            file=sys.stderr,
        )
        return False
    return True


def _usage() -> int:
    print(
        "usage: arm_ledger.py {strip-pending|mark-reviewed} <sid> <raw_path>\n"
        "       arm_ledger.py check-born <raw_path>",
        file=sys.stderr,
    )
    return 2


def main(argv: list[str]) -> int:
    if os.environ.get("DEVBREW_DISABLE_SPEC_DISTILL") == "1":
        print(
            "[spec-distill] arm_ledger: DEVBREW_DISABLE_SPEC_DISTILL=1 — no-op",
            file=sys.stderr,
        )
        return 0
    if len(argv) < 2:
        return _usage()
    cmd = argv[1]

    if cmd == "check-born":
        if len(argv) < 3:
            return _usage()
        raw_path = argv[2]
        if canonical_key(raw_path) is None:
            print(
                f"[spec-distill] arm_ledger: '{raw_path}' out of scope "
                f"(no {PREFIX}) — no-op",
                file=sys.stderr,
            )
            return 2
        if is_born(raw_path):
            return 0
        print(
            f"[spec-distill] '{raw_path}'가 아직 git에 없다 — 지금 커밋하지 않으면 "
            "다음 세션에서 이 문서의 리뷰가 한 번 더 발동한다.",
            file=sys.stderr,
        )
        return 1

    if len(argv) < 4:
        return _usage()
    sid, raw_path = argv[2], argv[3]
    if not SESSION_PATTERN.match(sid):
        trunc = sid[:32] + ("..." if len(sid) > 32 else "")
        print(
            f"[spec-distill] arm_ledger: session_id rejected: '{trunc}'",
            file=sys.stderr,
        )
        return 2
    sf = state_file_for(sid)

    if cmd == "strip-pending":
        strip_pending_file(sf, raw_path)
        return 0
    if cmd == "mark-reviewed":
        if not mark_reviewed(sf, raw_path):
            print(
                f"[spec-distill] arm_ledger: '{raw_path}' 리뷰 완료 미기록 "
                "— 같은 문서가 다시 dispatch될 수 있다.",
                file=sys.stderr,
            )
            return 1
        return 0
    print(f"[spec-distill] arm_ledger: unknown subcommand '{cmd}'", file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
```

- [ ] **Step 4: GREEN 확인**

```bash
python3 -m unittest tests.test_arm_ledger -v 2>&1 | tail -5
```

Expected: `Ran 24 tests` / `OK`

- [ ] **Step 5: CLI smoke (세 verb + kill switch)**

```bash
T=$(mktemp -d) && ( cd "$T" && git init -q && mkdir -p docs/superpowers/specs \
  && echo x > docs/superpowers/specs/a-design.md \
  && python3 "$OLDPWD/scripts/arm_ledger.py" check-born "docs/superpowers/specs/a-design.md"; \
  echo "untracked rc=$?"; \
  git add -A && git -c user.email=t@t.t -c user.name=t commit -qm x \
  && python3 "$OLDPWD/scripts/arm_ledger.py" check-born "docs/superpowers/specs/a-design.md"; \
  echo "tracked rc=$?"; \
  python3 "$OLDPWD/scripts/arm_ledger.py" mark-reviewed "smoke-sid" "docs/superpowers/specs/a-design.md"; \
  echo "mark rc=$?"; cat .claude/spec-distill/smoke-sid/state.local.md ) ; rm -rf "$T"
```

Expected: `untracked rc=1` + 미커밋 advisory / `tracked rc=0` / `mark rc=0` / state 파일에 `armed_paths:` 와 그 키.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/scripts/arm_ledger.py plugins/spec-distill/tests/test_arm_ledger.py
git commit -m "$(cat <<'EOF'
feat(spec-distill): arm_ledger.py — arm 판정의 단일 지점 (§5.1·§5.2)

should_arm = not is_armed and not is_born. 두 조건이 서로 다른 시간축을
덮는다(세션 안쪽 / 세션 바깥). 원장 기록은 verdict 시점에만 일어나고,
verdict 없이 끝난 재시도는 dispatch_attempts로 세션당·문서당 3회에서 멈춘다.

TDD: 단위 테스트 24개 선작성 → RED → 구현 → GREEN.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: validator arm 게이트 (`hooks/spec-write-validator.py`)

Layer 1(구조 검증)은 위치·동작 모두 불변이다(G2). 바뀌는 것은 Layer 2 진입 앞의 게이트뿐 — suppression 조회를 arm 판정으로 교체하고, skip 사유를 **세 가지로 구분해** 표시한다.

**Files:**
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py:185-186, 199-220, 274-289`
- Modify: `plugins/spec-distill/tests/test_spec_write_validator.sh:144-202`
- Modify: `plugins/spec-distill/tests/test_hook_output_schema.py:184-234`

**Interfaces:**
- Consumes: `arm_ledger.should_arm`, `.skip_reason`, `.canonical_key`, `.state_file_for`, `.strip_pending`
- Produces: `emit_arm_skip_advisory(mode, key, reason)` — stdout `hookSpecificOutput.additionalContext` 에 `"arm skipped"` 문자열, `systemMessage` 에 `"arm skipped (<reason>)"`

- [ ] **Step 1: 실패하는 테스트를 먼저 — Case 12·13·14를 `armed_paths` 기준으로 교체**

`tests/test_spec_write_validator.sh` 의 Case 12–14 (144–202행) 전체를 아래로 바꾼다:

```bash
# Case 12: arm-once — 원장에 있는 문서 → arm skip + skip advisory가 normal advisory를 교체
mkdir -p "$WORK/docs/superpowers/specs" "$WORK/.claude/spec-distill/test-armed"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-armed-spec.md"
cat > "$WORK/.claude/spec-distill/test-armed/state.local.md" <<EOF
---
session_id: test-armed
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-armed-spec.md
EOF
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-armed-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-armed")
rc=$?
sf="$WORK/.claude/spec-distill/test-armed/state.local.md"
if [[ $rc -eq 0 ]] \
  && ! grep -qE '^pending_review:' "$sf" \
  && echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("arm skipped")' >/dev/null \
  && ! echo "$out" | jq -e '.hookSpecificOutput.additionalContext | contains("Reviewer will be dispatched")' >/dev/null; then
  note PASS "arm-once: armed doc → arm skip + skip advisory (no normal advisory)"
else
  note FAIL "arm-once armed-doc case failed (rc=$rc out=$out)"
fi

# Case 12b: skip 사유 3종 구분 — 원장에 있고 attempts가 남아 있으면 'capped'(G6 상한),
# 없으면 'reviewed'. 둘 다 armed_paths에 있지만 사용자가 취해야 할 행동이 다르다.
mkdir -p "$WORK/.claude/spec-distill/test-capped"
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-capped-spec.md"
cat > "$WORK/.claude/spec-distill/test-capped/state.local.md" <<EOF
---
session_id: test-capped
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-capped-spec.md

dispatch_attempts:
  docs/superpowers/specs/2026-05-16-capped-spec.md: 3
EOF
out=$(run_hook_stdout "$WORK/docs/superpowers/specs/2026-05-16-capped-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-capped")
echo "$out" | jq -e '.systemMessage | contains("capped")' >/dev/null \
  && note PASS "arm-once: G6 상한 도달은 'capped'로 구분 표시" \
  || note FAIL "capped advisory 구분 실패 (out=$out)"

# Case 13: 원장에 있는 문서도 Layer 1은 그대로 실행 (구조 실패 → exit 2) — G2
cp "$FIX/spec-missing-goals.md" "$WORK/docs/superpowers/specs/2026-05-16-armed2-spec.md"
mkdir -p "$WORK/.claude/spec-distill/test-armed2"
cat > "$WORK/.claude/spec-distill/test-armed2/state.local.md" <<EOF
---
session_id: test-armed2
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-armed2-spec.md
EOF
out=$(run_hook "$WORK/docs/superpowers/specs/2026-05-16-armed2-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-armed2")
rc=$?
[[ $rc -eq 2 ]] && echo "$out" | grep -qE "missing sections:" \
  && note PASS "G2: armed doc still subject to Layer 1 (exit 2)" \
  || note FAIL "G2 failed (rc=$rc out=$out)"

# Case 14: 다른 비-armed 문서의 write_state가 armed_paths를 보존 (multi-key)
mkdir -p "$WORK/.claude/spec-distill/test-pres"
cat > "$WORK/.claude/spec-distill/test-pres/state.local.md" <<EOF
---
session_id: test-pres
---

armed_paths:
  - docs/superpowers/specs/2026-05-16-docA-design.md
EOF
cp "$FIX/spec-valid.md" "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md"
run_hook "$WORK/docs/superpowers/specs/2026-05-16-docB-spec.md" "DEVBREW_SPEC_DISTILL_SESSION_ID=test-pres" >/dev/null
sf="$WORK/.claude/spec-distill/test-pres/state.local.md"
if grep -q "  - docs/superpowers/specs/2026-05-16-docA-design.md" "$sf" \
   && grep -qE '^pending_review:' "$sf"; then
  note PASS "multi-key: armed_paths preserved across other-doc write_state"
else
  note FAIL "multi-key preservation failed ($(cat "$sf"))"
fi
```

- [ ] **Step 2: `test_hook_output_schema.py` 의 fail-open 락을 새 집으로 옮긴다**

`test_suppress_import_failure_falls_open_to_dispatch` (184–234행) 를 통째로 아래로 교체한다. 잠그는 불변식은 같다 — **판정 모듈을 못 불러도 리뷰가 일어나는 쪽으로 fail-open**. 대상만 Stop 훅의 suppress 조회에서 validator 의 arm 게이트로 옮겨간다(그쪽이 이제 판정을 소유하므로).

```python
    def test_arm_gate_import_failure_falls_open_to_arm(self):
        """`import arm_ledger`가 실패하면(예: 모킹) validator는 게이트를 건너뛰고
        정상 arm한다 (fail-safe = 리뷰가 일어나는 쪽, Law 1)."""
        import importlib.util
        import io
        import contextlib
        spec_module = importlib.util.spec_from_file_location(
            "spec_write_validator_failopen", HOOKS_DIR / "spec-write-validator.py",
        )
        mod = importlib.util.module_from_spec(spec_module)
        spec_module.loader.exec_module(mod)

        repo = _make_temp_repo()
        try:
            session_id = "test-armgate-failopen"
            rel = "docs/superpowers/specs/2026-01-01-x-design.md"
            doc = repo / rel
            doc.parent.mkdir(parents=True, exist_ok=True)
            doc.write_text(
                "# Doc\n\n## Goal\n\n한 줄.\n", encoding="utf-8")
            # 게이트가 살아 있었다면 arm을 막았을 진짜 원장 상태.
            state_dir = repo / ".claude" / "spec-distill" / session_id
            state_dir.mkdir(parents=True, exist_ok=True)
            (state_dir / "state.local.md").write_text(
                f"---\nsession_id: {session_id}\n---\n\narmed_paths:\n  - {rel}\n",
                encoding="utf-8",
            )
            payload = json.dumps({
                "tool_name": "Write",
                "tool_input": {"file_path": str(doc)},
            })
            out, err = io.StringIO(), io.StringIO()
            # sys.modules['arm_ledger'] = None → `import arm_ledger` ImportError.
            with mock.patch.dict(sys.modules, {"arm_ledger": None}), \
                 mock.patch.dict(os.environ, {
                     "DEVBREW_SPEC_DISTILL_SESSION_ID": session_id,
                 }), \
                 mock.patch("sys.stdin", new=io.StringIO(payload)), \
                 contextlib.redirect_stdout(out), \
                 contextlib.redirect_stderr(err):
                cwd_before = os.getcwd()
                try:
                    os.chdir(repo)
                    rc = mod.main()
                finally:
                    os.chdir(cwd_before)
            self.assertEqual(rc, 0)
            self.assertIn("arm gate failed", err.getvalue())
            state_body = (state_dir / "state.local.md").read_text(encoding="utf-8")
            self.assertIn(
                "pending_review:", state_body,
                msg="fail-open 시에도 arm(pending_review 기록)해야 함",
            )
        finally:
            shutil.rmtree(repo, ignore_errors=True)
```

> **초안 각주 폐기 (Task 3 리뷰 ruling — 사용자 확정).** 초안은 여기서 "`write_state` 의 import 를 `try/except` 로 감싸 `body` 를 그대로 쓰는 degrade" 를 지시했다. 리뷰어가 그 형태의 결함을 **실증**했다: import 실패로 strip 이 생략되면 `pending_review` 블록이 둘 생기고, Stop 은 `PENDING_RE.search`(첫 매치)로 **다른 문서**의 stale 블록을 집어 dispatch 하며, `rewrite_state` 의 전역 `re.sub`(`count=1` 없음)이 방금 arm 된 문서의 트리거까지 함께 지운다. 그 문서는 오류 한 줄 없이 영영 리뷰되지 않는다 — Law 1 이 금지하는 silent under-review 다. 해소는 Step 5 로 옮겼다: **`write_state` 는 fallible import 에 의존하지 않는다.** 따라서 이 픽스처에 degrade 를 넣을 이유 자체가 없다.

- [ ] **Step 3: RED 확인**

```bash
bash tests/test_spec_write_validator.sh 2>&1 | tail -8
python3 -m unittest tests.test_hook_output_schema -v 2>&1 | grep -E "arm_gate|FAIL|ERROR" | head
```

Expected: Case 12/12b가 `arm skipped` 부재로 FAIL, `test_arm_gate_import_failure_falls_open_to_arm` 이 ERROR/FAIL.

- [ ] **Step 4: validator 구현 — advisory 교체**

`hooks/spec-write-validator.py` 의 `emit_suppress_advisory` (199–220행) 를 아래로 교체한다:

```python
ARM_SKIP_REASONS = {
    "reviewed": "이 세션에서 리뷰가 이미 완료됨 (arm-once)",
    "capped": (
        "리뷰가 3회 시도됐으나 verdict 없이 끝나 자동 dispatch를 중단함 (G6 상한) "
        "— 리뷰가 필요하면 reviewing-spec을 직접 호출하라"
    ),
    "born": "git이 아는 문서 — 커밋 이후에는 자동 리뷰가 붙지 않는다",
    "out-of-scope": "스코프 밖 경로",
}


def emit_arm_skip_advisory(mode: str, key: str, reason: str) -> None:
    """v0.25.0 — arm-once 게이트가 arm을 건너뛸 때의 advisory.

    기존 'Reviewer will be dispatched' 출력을 *교체*한다(이중 방출 금지). 사유를
    구분해 표시하는 것이 요건이다 — 'reviewed'와 'capped'는 둘 다 armed_paths에
    있지만 사용자가 취해야 할 행동이 다르다(전자는 정상, 후자는 수동 호출 필요).
    """
    why = ARM_SKIP_REASONS.get(reason, reason)
    text = f"[spec-distill] {key} arm skipped — {why}."
    print(
        json.dumps({
            "hookSpecificOutput": {
                "hookEventName": "PostToolUse",
                "additionalContext": text,
            },
            "systemMessage": f"[spec-distill] {mode} arm skipped ({reason}) for {key}",
        }),
        flush=True,
    )
    print(text, file=sys.stderr)
```

- [ ] **Step 5: validator 구현 — 게이트 교체**

274–289행의 suppression 블록을 아래로 교체한다:

```python
            # v0.25.0 arm-once 게이트 (Layer 2). Layer 1 구조 검증은 위에서 이미
            # 실행됐다(G2) — arm이 skip돼도 구조 실패는 exit 2로 차단된다.
            # 판정 실패(모듈 부재·원장 read 실패·git 불능)는 전부 arm 쪽으로
            # fail-open한다 (Law 1: 과리뷰 > under-review). 원장이 1회로 제한하므로
            # storm이 되지 않는다.
            try:
                import arm_ledger  # pyright: ignore[reportMissingImports]
                sfile = arm_ledger.state_file_for(session_id)
                if not arm_ledger.should_arm(sfile, file_path):
                    key = arm_ledger.canonical_key(file_path) or file_path
                    emit_arm_skip_advisory(
                        mode, key, arm_ledger.skip_reason(sfile, file_path))
                    return 0  # arm skip — 기존 advisory 미방출
            except Exception as exc:  # noqa: BLE001 — graceful degradation
                print(
                    f"[spec-distill] arm gate failed "
                    f"(non-fatal, arming normally): {exc}",
                    file=sys.stderr,
                )
```

같은 파일 185–186행의 `write_state` 안 sibling import 는 **제거한다** (Task 3 리뷰 ruling — 사용자 확정). 모듈 상단에 로컬 정규식을 두고 무조건 strip 한다:

```python
# 모듈 상단 — arm_ledger 와 같은 패턴이지만 의도적으로 로컬이다.
# 이 플러그인은 이미 review-dispatch.py·pending-review-reminder.py·arm_ledger.py·
# suppress_state.py 네 곳에서 이 정규식을 각자 정의한다 — 새 중복이 아니라 기존 관례.
PENDING_RE = re.compile(r"^pending_review:\n(?:  [^\n]*\n)*", re.MULTILINE)
```

```python
    # write_state 안 (기존 import 두 줄을 대체)
    # "pending_review 블록은 정확히 하나" 는 모듈 가용성과 무관하게 성립해야 한다.
    # 두 블록이 생기면 Stop 이 첫 블록(다른 문서)을 소비하고 rewrite_state 의 전역
    # re.sub 가 방금 arm 된 문서의 트리거까지 지운다 — 오류 없는 under-review.
    body = PENDING_RE.sub("", body)
```

arm 게이트(Step 5 아래)의 `try/except` 는 그대로 둔다 — 그쪽은 판정이라 fail-open 이 옳다. 멱등성은 판정이 아니다.

- [ ] **Step 6: GREEN 확인**

```bash
bash tests/test_spec_write_validator.sh 2>&1 | tail -4
python3 -m unittest tests.test_hook_output_schema 2>&1 | tail -3
```

Expected: validator 스위트 `0 failed`; python 스위트는 알려진 cross-resolver 1건만 fail(베이스라인).

- [ ] **Step 7: mutation — 게이트를 빼면 RED**

```bash
# should_arm 판정을 무력화(항상 arm)했을 때 Case 12가 RED가 되는지
python3 - <<'PY'
import pathlib
p = pathlib.Path("hooks/spec-write-validator.py")
t = p.read_text(encoding="utf-8")
p.with_suffix(".py.bak").write_text(t, encoding="utf-8")
p.write_text(t.replace("if not arm_ledger.should_arm(sfile, file_path):",
                       "if False:"), encoding="utf-8")
PY
bash tests/test_spec_write_validator.sh 2>&1 | tail -3   # 기대: arm-once armed-doc case FAIL
mv hooks/spec-write-validator.py.bak hooks/spec-write-validator.py
bash tests/test_spec_write_validator.sh 2>&1 | tail -3   # 기대: 0 failed
```

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/hooks/spec-write-validator.py \
        plugins/spec-distill/tests/test_spec_write_validator.sh \
        plugins/spec-distill/tests/test_hook_output_schema.py
git commit -m "$(cat <<'EOF'
feat(spec-distill): validator의 suppression 게이트를 arm 게이트로 교체

should_arm이 false면 pending_review를 쓰지 않고 사유를 구분한 advisory만 낸다
(reviewed / capped / born). Layer 1은 위치·동작 모두 불변(G2).

fail-open 락(판정 모듈 부재 → 정상 arm)을 Stop 훅의 suppress 조회에서
validator의 arm 게이트로 이관 — 판정 소유자가 옮겨갔으므로.

mutation: 게이트를 `if False`로 무력화 → armed-doc 케이스 RED 확인.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: Stop 훅 — suppress·lock 삭제 + `dispatch_attempts` + G6 상한

`review-dispatch.py` 에서 방어 블록 둘(~35줄)을 걷어내고, §5.2 상태기계의 훅 측 절반을 넣는다. **정상 dispatch 에서 `armed_paths` 를 쓰지 않는다** — 완료 기록은 verdict 시점 `mark-reviewed` 의 몫이고, Stop 이 원장을 건드리는 경우는 상한에 닿는 그 순간뿐이다.

**Files:**
- Modify: `plugins/spec-distill/hooks/review-dispatch.py:21, 77-91, 132-173, 185-212`
- Modify: `plugins/spec-distill/tests/test_review_dispatch.sh:127-245`

**Interfaces:**
- Consumes: `arm_ledger.next_attempt(body, spec_path) -> int`, `arm_ledger.record_attempt(body, spec_path, n) -> str`, `arm_ledger.DISPATCH_ATTEMPT_CAP`
- Produces: `rewrite_state(path, body, now, spec_path, attempt_n) -> None` (bare 호출 유지 — AC7.3.1 AST 락)

- [ ] **Step 1: 실패하는 테스트 먼저 — Case 16–20 교체**

`tests/test_review_dispatch.sh` 의 Case 16–20 (127–245행) 을 아래로 바꾼다:

```bash
# Case 16: dispatch 1회차 — attempts=1 기록, armed_paths는 **안 씀** (T10 계열).
# 완료 기록은 verdict 시점 mark-reviewed의 몫이다(§5.2).
setup_state "test-016" "---
session_id: test-016
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-x-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-016")
rc=$?
sf16="$WORK/.claude/spec-distill/test-016/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^armed_paths:' "$sf16" \
  && grep -q '^  docs/superpowers/specs/2026-01-01-x-design.md: 1$' "$sf16" \
  && note PASS "§5.2: dispatch 1회차 → attempts=1, armed_paths 미기록" \
  || note FAIL "dispatch 1회차 실패 (rc=$rc out='$out' state=$(cat "$sf16"))"

# Case 17: G6 상한 — attempts가 이미 2면 이번 dispatch가 3회차. emit에 상한 advisory가
# 붙고 armed_paths에 키가 생긴다. "4회차가 억제된다"가 아니라 3회차가 마지막 자동
# dispatch이고 그 emit이 상한을 알리는 vehicle이다(§5.2 상태기계).
setup_state "test-017" "---
session_id: test-017
---

pending_review:
  path: docs/superpowers/specs/2026-01-01-cap-design.md
  mode: design
  triggered_at: 2026-05-16T10:00:00Z

dispatch_attempts:
  docs/superpowers/specs/2026-01-01-cap-design.md: 2
"
out=$(run_hook "test-017")
rc=$?
sf17="$WORK/.claude/spec-distill/test-017/state.local.md"
[[ $rc -eq 0 ]] \
  && echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && echo "$out" | jq -e '.reason | contains("3회 시도")' >/dev/null \
  && grep -q '^  - docs/superpowers/specs/2026-01-01-cap-design.md$' "$sf17" \
  && grep -q '^  docs/superpowers/specs/2026-01-01-cap-design.md: 3$' "$sf17" \
  && note PASS "G6: 3회차 emit에 상한 advisory + armed_paths 기록" \
  || note FAIL "G6 상한 실패 (rc=$rc out='$out' state=$(cat "$sf17"))"

# Case 18: 스코프 밖 pending(정규화 키 없음)은 attempts를 추적하지 않고도 정상 dispatch.
setup_state "test-018" "---
session_id: test-018
---

pending_review:
  path: /tmp/out-of-scope-spec.md
  mode: spec
  triggered_at: 2026-05-16T10:00:00Z
"
out=$(run_hook "test-018")
sf18="$WORK/.claude/spec-distill/test-018/state.local.md"
echo "$out" | jq -e '.decision == "block"' >/dev/null \
  && ! grep -q '^dispatch_attempts:' "$sf18" \
  && note PASS "스코프 밖 pending → 정상 dispatch, attempts 미추적" \
  || note FAIL "out-of-scope dispatch 실패 (out='$out')"
```

- [ ] **Step 2: RED 확인**

```bash
bash tests/test_review_dispatch.sh 2>&1 | tail -6
```

Expected: Case 16(`attempts` 미기록)·17(상한 advisory 없음) FAIL.

- [ ] **Step 3: 방어 블록 둘을 삭제**

`hooks/review-dispatch.py` 에서 132–173행(주석 포함 `# A2 (v0.15.0): honor suppressed_paths…` 부터 `review-lock check failed` 블록 끝까지)을 통째로 지운다. 그 자리에 남는 것은 없다 — 억제할 대상이 소멸했고(arm-once), 락의 불변식은 `reviewing-spec` 진입 시 pending strip 이 승계한다(§5.4).

같은 커밋에서 모듈 docstring 21행의 락 TTL 줄도 지운다:

```
- DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC=<int>  (default 1800; document-keyed review-lock freshness)
```

- [ ] **Step 4: `rewrite_state` 에 attempts 를 합류시킨다**

77–91행의 `rewrite_state` 를 아래로 교체한다:

```python
def rewrite_state(
    path: Path, body: str, now: datetime, spec_path: str, attempt_n: int,
) -> None:
    body = re.sub(
        r"^pending_review:\n(?:  [^\n]*\n)*", "", body, flags=re.MULTILINE
    )
    new_ts = now.strftime("%Y-%m-%dT%H:%M:%SZ")
    if LAST_DISPATCHED_RE.search(body):
        body = LAST_DISPATCHED_RE.sub(f"last_dispatched_at: {new_ts}", body)
    else:
        body = body.rstrip() + f"\nlast_dispatched_at: {new_ts}\n"
    # §5.2 — dispatch_attempts 증가는 pending strip·타임스탬프와 **한 write**로
    # 커밋된다. armed_paths는 G6 상한에 닿는 그 순간에만 record_attempt가 함께 찍고,
    # 정상 dispatch에서는 원장을 건드리지 않는다(완료 기록 = verdict 시점 mark-reviewed).
    if attempt_n > 0:
        try:
            import arm_ledger  # pyright: ignore[reportMissingImports]
            body = arm_ledger.record_attempt(body, spec_path, attempt_n)
        except Exception as exc:  # noqa: BLE001 — loud degradation
            print(
                f"[spec-distill] dispatch_attempts 기록 실패 "
                f"(non-fatal, 이번 dispatch에 G6 상한 미적용): {exc}",
                file=sys.stderr,
            )
    # AC7.1: explicit flush + fsync for OS-level durability before any emit.
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
        f.flush()
        os.fsync(f.fileno())
```

- [ ] **Step 5: `main` 에서 시도 번호를 rewrite *이전에* 계산**

185행 이후 (`spec_path = m.group("path").strip()` 부터 `msg = " ".join(msg_lines)` 까지) 를 아래로 교체한다:

```python
    spec_path = m.group("path").strip()
    mode = m.group("mode").strip()
    wt = (m.group("wt") or "").strip()
    # §5.2 — 이번 dispatch의 시도 번호는 rewrite *이전에* 순수 함수로 계산한다.
    # rewrite_state를 bare 표현식 호출로 유지해야 AC7.3.1 AST 락(rewrite 먼저,
    # print 나중)이 그대로 성립한다 — 반환값 대입으로 바꾸면 그 락이 호출을 못 본다.
    attempt_n = 0
    cap = 0
    try:
        import arm_ledger  # pyright: ignore[reportMissingImports]
        attempt_n = arm_ledger.next_attempt(body, spec_path)
        cap = arm_ledger.DISPATCH_ATTEMPT_CAP
    except Exception as exc:  # noqa: BLE001 — loud degradation
        print(
            f"[spec-distill] dispatch 시도 카운트 실패 "
            f"(non-fatal, G6 상한 미적용): {exc}",
            file=sys.stderr,
        )
    msg_lines = [
        "MANDATORY: 다음 turn 첫 액션으로 reviewing-spec skill 호출.",
        f"spec path: {spec_path}.",
        f"mode: {mode}.",
    ]
    if wt:
        msg_lines.append(f"worktree_path: {wt}.")
    msg_lines.append(
        "호출 skill의 terminal handoff(writing-plans 등)는 review pass 이후로 보류."
    )
    if cap and attempt_n >= cap:
        msg_lines.append(
            f"[spec-distill] '{spec_path}' 리뷰가 {cap}회 시도됐으나 verdict 없이 "
            "끝났다 — 자동 dispatch를 중단한다. 리뷰가 필요하면 reviewing-spec을 "
            "직접 호출하라."
        )
    msg = " ".join(msg_lines)
```

그리고 `rewrite_state` 호출을 새 시그니처로 바꾼다 (**bare 표현식 유지**):

```python
        rewrite_state(state_path, body, now, spec_path, attempt_n)
```

- [ ] **Step 6: GREEN 확인 + AST 락 생존 확인**

```bash
bash tests/test_review_dispatch.sh 2>&1 | tail -4
python3 -m unittest tests.test_hook_output_schema 2>&1 | tail -3
bash tests/test_review_dispatch_design_mandate.sh 2>&1 | tail -3
```

Expected: 전부 `0 failed` / 알려진 cross-resolver 1건 외 OK. 특히 `test_ast_rewrite_before_print` 와 `test_mock_trace_rewrite_before_print` 가 통과해야 한다 — 통과하지 않으면 `rewrite_state` 를 대입문으로 바꾼 것이다.

- [ ] **Step 7: mutation 2종**

```bash
cp hooks/review-dispatch.py /tmp/rd.bak
# (a) 상한 검사 제거 → Case 17 RED
python3 - <<'PY'
import pathlib
p = pathlib.Path("hooks/review-dispatch.py"); t = p.read_text(encoding="utf-8")
p.write_text(t.replace("if cap and attempt_n >= cap:", "if False:"), encoding="utf-8")
PY
bash tests/test_review_dispatch.sh 2>&1 | tail -3   # 기대: G6 상한 FAIL
cp /tmp/rd.bak hooks/review-dispatch.py
# (b) Stop이 매 dispatch마다 armed를 찍게 → Case 16 RED (T10의 예고편)
python3 - <<'PY'
import pathlib
p = pathlib.Path("hooks/review-dispatch.py"); t = p.read_text(encoding="utf-8")
p.write_text(t.replace(
    "body = arm_ledger.record_attempt(body, spec_path, attempt_n)",
    "body = arm_ledger.mark_armed(\n"
    "                arm_ledger.record_attempt(body, spec_path, attempt_n), spec_path)"),
    encoding="utf-8")
PY
bash tests/test_review_dispatch.sh 2>&1 | tail -3   # 기대: dispatch 1회차 FAIL
cp /tmp/rd.bak hooks/review-dispatch.py && rm /tmp/rd.bak
bash tests/test_review_dispatch.sh 2>&1 | tail -3   # 기대: 0 failed
```

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/hooks/review-dispatch.py plugins/spec-distill/tests/test_review_dispatch.sh
git commit -m "$(cat <<'EOF'
feat(spec-distill): Stop 훅에서 suppress·lock 블록 제거 + G6 상한

정상 dispatch는 dispatch_attempts만 올린다 — armed_paths는 상한(3)에 닿는
그 순간에만 함께 찍힌다. 완료 기록은 verdict 시점 mark-reviewed의 몫이다.

시도 번호는 rewrite 이전에 순수 함수로 계산해 인자로 넘긴다 — rewrite_state를
bare 표현식 호출로 유지해야 AC7.3.1 AST 락이 그 호출을 본다.

mutation: (a) 상한 검사 제거 → G6 케이스 RED, (b) 매 dispatch마다 mark_armed
→ 1회차 케이스 RED.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: reminder 훅 — lock 블록 삭제

훅 자체는 유지한다(D5). arm 기회가 문서당 한 번뿐이라 **놓친 dispatch 의 복구가 이전보다 더 중요해진다**. 지우는 것은 락 조회뿐이다.

**Files:**
- Modify: `plugins/spec-distill/hooks/pending-review-reminder.py:100-118`
- Modify: `plugins/spec-distill/tests/test_reminder_hook.sh:72-108`

**Interfaces:**
- Consumes: 없음 (삭제만)
- Produces: 없음

- [ ] **Step 1: 테스트에서 락 케이스 제거**

`tests/test_reminder_hook.sh` 의 72–108행(`write_state_with_lock` 헬퍼 + AC5a + AC5b) 을 통째로 지운다. 그 자리에 아래를 넣어 **reminder 가 원장을 건드리지 않는다**는 §5.2 의 계약을 잠근다:

```bash
# v0.25.0: reminder는 재-nag일 뿐 리뷰의 완료가 아니다 — 원장(armed_paths)을 쓰지 않는다.
OLD6=$(python3 -c 'from datetime import datetime,timezone,timedelta; print((datetime.now(timezone.utc)-timedelta(seconds=60)).strftime("%Y-%m-%dT%H:%M:%SZ"))')
write_state "$OLD6"
run_hook >/dev/null
! grep -q '^armed_paths:' "$SDIR/state.local.md" \
  && note PASS "reminder는 armed_paths를 기록하지 않는다 (재-nag ≠ 리뷰 완료)" \
  || note FAIL "reminder가 원장을 기록했다: $(cat "$SDIR/state.local.md")"
```

- [ ] **Step 2: RED 확인**

```bash
bash tests/test_reminder_hook.sh 2>&1 | tail -4
```

Expected: 새 케이스는 통과하지만 AC5a/AC5b 제거 전이면 `review_lock` 참조가 남아 있다. (락 블록이 아직 살아 있으므로 이 단계의 RED 는 없을 수 있다 — 그렇다면 Step 3 을 진행하고 Step 4 에서 회귀 없음을 확인한다.)

- [ ] **Step 3: 락 블록 삭제**

`hooks/pending-review-reminder.py` 100–118행 (`# Document-keyed review lock (v0.18.0) — Stop 훅과 동일 게이트(AC5)…` 부터 `review-lock check failed … reminding` 블록 끝까지) 을 지운다.

- [ ] **Step 4: GREEN 확인**

```bash
bash tests/test_reminder_hook.sh 2>&1 | tail -4
grep -c "review_lock" hooks/pending-review-reminder.py   # 기대: 0
```

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/hooks/pending-review-reminder.py plugins/spec-distill/tests/test_reminder_hook.sh
git commit -m "$(cat <<'EOF'
refactor(spec-distill): reminder 훅의 review_lock 게이트 제거

훅 자체는 유지(D5) — arm 기회가 문서당 한 번뿐이라 놓친 dispatch의 복구가
이전보다 더 중요해진다. reminder가 원장을 쓰지 않는다는 계약을 락으로 고정.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: `reviewing-spec` SKILL.md 재배선

skill 은 이제 세 지점에서 원장과 이야기한다: 진입 시 pending strip(§5.4), verdict 시 완료 기록(§5.2), approve 시 미커밋 advisory(§6). Phase 5 의 네 옵션은 모두 verdict **이후**이므로 pending 에 대해 할 일이 없다 — 매핑표가 통째로 사라진다.

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md:26, 28, 32-40, 84-86, 141-142, 160, 162-178, 188-202`

**Interfaces:**
- Consumes: `arm_ledger.py` CLI 세 verb
- Produces: T12b 가 잠그는 "리뷰 완료 기록" 블록 — `mark-reviewed` · `claude_verdict_unrecoverable` · `codex_degraded` 가 **같은 섹션 윈도우 안에** 있어야 한다

- [ ] **Step 1: Step 1 의 락 refresh 절을 pending strip 으로 교체**

32–40행 (`**리뷰 락 refresh (v0.18.0; v0.19.0: harness sid keying)**` 부터 `stale(TTL 1800s 초과) 시 강제가 재개된다(fail-safe = 강제).` 까지) 을 아래로 바꾼다:

```markdown
**pending strip (v0.25.0)** — state 로드 직후, `spec-reviewer` dispatch *전에* 이 문서의 pending 을 제거한다 (매 진입 — 최초 + revise 재진입):

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" strip-pending "$harness_sid" "$spec_path"
```

   `$harness_sid` 가 빈 값(env unset → `state_path.py session-id` exit 1)이면 **strip skip** — 조용히 넘어가지 말고 advisory 를 남긴다. pending 이 남아도 Law 1 fail-safe 방향(리뷰 강제)이라 안전하다.

dispatch 의 연료는 `pending_review` 다. 진입 시점에 연료를 없애면 subagent(async) 경계에서 발생하는 메인 `Stop` 이 진행 중인 리뷰를 재강제(중복/절단)할 수 없다 — v0.18.0 이 상태로 표현하던 불변식을 한 줄이 대체한다. 다른 문서의 pending 은 건드리지 않는다(같은-키만 strip). **여기서 원장(`armed_paths`)은 쓰지 않는다** — 진입은 리뷰의 *시작*일 뿐 완료가 아니다(§5.2).
```

- [ ] **Step 2: Step 1 서술의 불변식 문장 둘을 새 이름으로**

26행의 괄호를 바꾼다:

```
**read==write 디렉토리 불변식**(스킬의 pending/spec READ 와 락·suppress·approve WRITE 가 같은 `$STATE` 를 가리킴)
```
→
```
**read==write 디렉토리 불변식**(스킬의 pending/spec READ 와 `strip-pending`·`mark-reviewed` WRITE 가 같은 `$STATE` 를 가리킴)
```

28행:

```
**불변식 (hook-facing trio vs continuity):** hook-facing trio(`pending_review`·lock·suppress)의 read/write 는 harness sid(`$STATE`);
```
→
```
**불변식 (hook-facing 상태 vs continuity):** hook-facing 상태(`pending_review`·`armed_paths`·`dispatch_attempts`)의 read/write 는 harness sid(`$STATE`);
```

- [ ] **Step 3: Step 3 에 리뷰 완료 기록을 추가 (T12b 가 잠그는 블록)**

86행 (`**codex 귀속 표시 (v0.20.1 …)**` 문단) 바로 뒤, `4. **Apply routing table**` 앞에 아래를 넣는다:

```markdown
   **리뷰 완료 기록 (v0.25.0)** — verdict 파싱 직후 원장에 이 문서를 기록한다. arm-once 의 종결 사건이며, 이 기록 이후의 같은-세션 편집은 재arm 되지 않는다:

   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" mark-reviewed "$harness_sid" "$spec_path"
   ```

   **예외 — 실질 리뷰가 0인 라운드에서는 호출하지 않는다.** merge_review 가 `claude_verdict_unrecoverable: true` **이면서** `codex_degraded: true` 인 both-dead fail-safe 분기는 아무도 리뷰하지 않았는데도 `combined_verdict: needs_revise` 를 낸다. 그 값을 원장에 기록하면 "리뷰가 실제로 일어났을 때만 표시된다"는 기록 시점의 근거가 그대로 무너진다. 배제된 라운드는 원장이 비어 다음 편집이 재시도하며, `dispatch_attempts` 는 계속 올라 G6 상한(3)이 결국 멈춘다. merge_review 자신도 이 분기에서 `issue_history` 원장을 갱신하지 않는다 — 같은 규칙의 두 적용이다.

   `$harness_sid` 가 빈 값이면 이 기록을 남길 수 없다. 조용히 넘어가지 말고 advisory 를 낸다:

   > `[spec-distill] harness_sid 미해석 — 이 세션의 상태 파일을 특정할 수 없어 리뷰 완료 기록(mark-reviewed)을 남기지 못했다. 같은 문서가 다시 dispatch될 수 있다. 해소: DEVBREW_SPEC_DISTILL_SESSION_ID로 sid를 명시하거나, 이 세션 동안 DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1로 arm을 끈다.`
```

> 이 advisory 문구는 `SKILL.md:176` 의 `/spec-distill:cancel-review` 안내를 **이동해 대체**한 것이다(§9). 원래 문장은 ④ 멈춤의 `review_lock.py pause` 블록 안에 있었고 그 블록은 통째로 사라지므로 제자리 교체가 불가능하다. `harness_sid` 미해석이 실제로 문제가 되는 유일한 지점이 여기다.

- [ ] **Step 4: Phase 5 게이트 옵션 문면·④·매핑표 정리**

141–142행의 옵션 설명에서 `approve_handoff` 를 뺀다:

```javascript
      {label: "/compact 후 writing-plans (권장)", description: "미커밋 advisory(check-born) 후 verbatim /compact 명령 노출 → 사용자 /compact 실행 시 writing-plans. 긴 인터뷰 context 정리 이점."},
      {label: "바로 writing-plans", description: "미커밋 advisory(check-born) 후 즉시 Skill superpowers:writing-plans <path> 호출 (compact 없이)."},
```

160행의 ④:

```markdown
- **④ 멈춤**: state 보존하고 종료. **상태 조작 없음** — 이 문서의 pending 은 Step 1 에서 이미 제거됐고, 원장에는 verdict 시점에 이미 기록됐다(§5.2). 그 세션에서 자동 재발동은 없다. 재개는 사용자 요청 시 skill 수동 호출로 한다(D2·NG1).
```

162–178행 (`### Phase 5 옵션 ↔ 리뷰 락 매핑 (v0.18.0)` 헤더부터 `모든 동작은 **그 문서 엔트리에만** 작용하고 다른 문서 엔트리는 불변(multi-key, [ad4e6c3f]).` 까지) 을 **통째로 삭제**한다. 네 옵션 모두 pending·원장에 대해 할 일이 없으므로 매핑할 것이 없다.

- [ ] **Step 5: "Approve handoff sequence" 절을 `check-born` 으로 교체**

188–202행 (`## Approve handoff sequence (①/② 공통)` 부터 `### 실패 시 state 보존 (P14)` 문단 끝까지) 을 아래로 바꾼다:

```markdown
## Approve handoff sequence (①/② 공통)

approve(①/②) 시 상태 조작은 없다. 이 시점에 남은 유일한 할 일은 **문서가 아직 git 에 없으면 알리는 것**이다:

```bash
python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/arm_ledger.py" check-born "$spec_path"
```

exit 0 = git-tracked (할 말 없음). exit 1 = 미커밋 — 스크립트가 stderr 로 낸 advisory 를 **그대로 사용자에게 노출**한다:

> `[spec-distill] '<path>'가 아직 git에 없다 — 지금 커밋하지 않으면 다음 세션에서 이 문서의 리뷰가 한 번 더 발동한다.`

arm-once 의 세션-바깥 조건은 `is_born`(git 추적 여부)이다. 커밋하지 않은 채 세션을 넘기면 이 문서의 리뷰가 한 번 더 발동한다 — 이 advisory 가 그 사실을 사용자에게 미리 알리는 유일한 신호이며, 비용을 0으로 만드는 행위(문서를 커밋하는 것)를 촉구한다. 동시에 approve 가 **관측 가능한 부수효과**를 남기게 해 AP2 검증 앵커도 겸한다.

**polite stop 금지** (AP2): approve 인데 이 호출/게이트를 skip 하고 narrate 만 하지 말 것.

### 실패 시 state 보존 (P14)

`check-born` 은 판정만 하고 상태를 쓰지 않는다 — 실패해도 잃을 상태가 없다. out-of-scope 경로면 exit 2 + advisory(비-fatal). in-scope 이지만 working-tree 에 없는 dangling 경로는 abort 를 유발하지 않고 "미커밋" 판정 + advisory 로 끝난다. 세션 dir 정리는 SessionEnd hook / TTL-GC 가 담당한다. git commit 실패 경로는 존재하지 않는다(스크립트가 commit 을 시도하지 않는다).
```

- [ ] **Step 6: skill 관련 기존 락이 살아 있는지 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+spec-distill-arm-once/plugins/spec-distill
for t in test_reviewing_spec_design_only.sh test_reviewing_spec_design_routing.sh \
         test_reviewing_spec_codex_merge.sh test_rereview_cap_consistency.sh \
         test_handoff_design_mode.sh test_handoff_kill_switch.sh \
         test_handoff_context_section_required.sh; do
  printf '%-46s ' "$t"; bash "tests/$t" >/dev/null 2>&1 && echo OK || echo FAIL
done
```

Expected: 전부 `OK`. `FAIL` 이 나오면 그 테스트가 무엇을 잠그고 있었는지 읽고, 계약이 바뀐 것인지(테스트 수정) 내가 깬 것인지(SKILL 수정) 판정한다 — 둘 다 아니면 진행하지 않는다.

- [ ] **Step 7: AC19 cross-compact 가드가 살아 있는지 육안 + grep 확인**

```bash
grep -cE "턴 종료|다음 턴" skills/reviewing-spec/SKILL.md    # 기대: ≥ 1
```

옵션 ① 서술 블록 안에 'turn-ending(STOP)' + 'writing-plans 같은 턴 호출 금지' + '다음 턴 = 사용자 트리거' 가 **함께** 남아 있는지 눈으로 확인한다(153–157행). 이 태스크는 그 블록을 건드리지 않으므로 변화가 없어야 한다.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "$(cat <<'EOF'
feat(spec-distill): reviewing-spec을 arm_ledger 세 verb로 재배선

Step 1 진입 → strip-pending(연료 제거가 락을 대체), Step 3 verdict →
mark-reviewed(both-dead fail-safe 라운드 배제), approve → check-born.

Phase 5 옵션↔락 매핑표 삭제 — 네 옵션 모두 verdict 이후라 pending·원장에
대해 할 일이 없다. :176의 cancel-review 안내는 Step 3 옆으로 이동해 대체.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: T1·T2·T3 — `tests/test_arm_once.sh`

arm 게이트의 통합 락. **재는 것은 pending 파일 쓰기 횟수가 아니라 dispatch emit 횟수**다 — §5.2 가 명시한 대로 두 번째 편집이 pending 을 덮어쓰는 것은 의도된 동작이므로 "기록 1회"를 assert 하면 설계와 모순되는 것을 재게 된다.

**Files:**
- Create: `plugins/spec-distill/tests/arm_test_helpers.sh` (공유 하니스 — 아래 ruling)
- Create: `plugins/spec-distill/tests/test_arm_once.sh`

**Interfaces:**
- Consumes: `hooks/spec-write-validator.py`, `hooks/review-dispatch.py`, `scripts/arm_ledger.py`, `tests/fixtures/2026-05-17-test-design.md`
- Produces: `arm_test_helpers.sh` — Task 8 이 `source` 로 재사용한다. 노출 이름: 변수 `REPO_ROOT`·`SD`·`VALIDATOR`·`DISPATCH`·`LEDGER`·`MERGE`·`SKILL`·`FIX`·`WORK`·`pass`·`fail`, 함수 `note`·`arm_work_init`·`new_doc`·`edit_doc`·`run_validator`·`run_validator_all`·`run_stop`·`run_ledger`·`run_ledger_rc`·`state_of`·`arm_summary`

> **Ruling (pre-flight, 사용자 확정)** — 초안은 Task 8 이 이 하니스를 verbatim 복제하도록 적혀 있었다. 리뷰 루브릭이 "로직 블록의 verbatim 중복"을 결함으로 보므로 사용자에게 물었고 **공유 헬퍼 추출**로 확정됐다. 파일은 `tests/lib/` 가 아니라 `tests/` 직하에 둔다 — 리포 루트 `.gitignore` 의 `lib/` 규칙이 `tests/lib/` 하위를 조용히 untracked 로 만들기 때문이다(`plugins/quality-gates/tests/lib/` 만 negation 으로 구제돼 있다).

- [ ] **Step 1: 공유 하니스 작성 — `tests/arm_test_helpers.sh`**

```bash
#!/usr/bin/env bash
# arm-once 테스트 공유 하니스 (v0.25.0).
# test_arm_once.sh(T1–T3)와 test_arm_ledger_timing.sh(T6–T12)가 source한다.
# **source 전용** — 이 파일 자체는 테스트가 아니다(이름에 test_ 접두어가 없는 이유).
#
# 계약: source하는 쪽이 `set -u -o pipefail`을 먼저 켜고, arm_work_init로 작업 리포를
# 만들고, 마지막에 arm_summary로 집계·종료 코드를 받는다.
#
# 모든 다중-dispatch 헬퍼는 DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0을 건다(lock —
# 계획 재량 아님). review-dispatch.py의 30초 redispatch TTL 가드가 원장 게이트 없이도
# 두 번째 emit을 막아버리면 "원장 게이트 제거 → RED"라는 mutation 주장이 성립하지 않고
# 락이 이빨을 잃는다.
#
# 위치가 tests/lib/이 아닌 이유: 리포 루트 .gitignore의 `lib/` 규칙이 tests/lib/ 하위를
# 조용히 untracked로 만든다(quality-gates만 negation으로 구제됨).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
VALIDATOR="$SD/hooks/spec-write-validator.py"
DISPATCH="$SD/hooks/review-dispatch.py"
LEDGER="$SD/scripts/arm_ledger.py"
MERGE="$SD/scripts/merge_review.py"
SKILL="$SD/skills/reviewing-spec/SKILL.md"
FIX="$SD/tests/fixtures"

pass=0; fail=0
note() {
  if [[ "$1" == "PASS" ]]; then pass=$((pass+1)); echo "  ✓ $2"
  else fail=$((fail+1)); echo "  ✗ $2"; fi
}

arm_work_init() {  # $1 = mktemp prefix
  # 두 대입 모두 || exit 1 — 빈 WORK가 trap rm -rf로 흘러들어가는 laundering을 막는다.
  # (macOS bash의 `cd ""`는 exit 0 + cwd 불변이라 빈 값이 조용히 통과한다.)
  WORK=$(mktemp -d -t "$1-XXXXXX") || exit 1
  WORK=$(cd "$WORK" && pwd -P) || exit 1   # /var → /private/var symlink 해소
  trap 'rm -rf "$WORK"' EXIT
  ( cd "$WORK" && git init -q && git config user.email t@t.t && git config user.name t \
    && git commit -q --allow-empty -m seed ) || exit 1
}

new_doc() {  # $1 = WORK 기준 상대 경로
  mkdir -p "$WORK/$(dirname "$1")"
  cp "$FIX/2026-05-17-test-design.md" "$WORK/$1"
}
edit_doc() { printf '\n<!-- edit %s -->\n' "$2" >> "$WORK/$1"; }

# stdout만 (advisory JSON 검사용)
run_validator() {  # $1=rel $2=sid [$3=extra env]
  local payload; payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WORK/$1")
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$2" ${3:-} \
      bash -c "echo '$payload' | python3 '$VALIDATOR'" 2>/dev/null )
}
# stdout+stderr 합본 (loud degradation 검사용)
run_validator_all() {  # $1=rel $2=sid [$3=extra env]
  local payload; payload=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"}}' "$WORK/$1")
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$2" ${3:-} \
      bash -c "echo '$payload' | python3 '$VALIDATOR'" 2>&1 )
}
run_stop() {  # $1=sid
  ( cd "$WORK" && env DEVBREW_SPEC_DISTILL_SESSION_ID="$1" \
      DEVBREW_SPEC_DISTILL_REDISPATCH_TTL_SEC=0 \
      bash -c "echo '{}' | python3 '$DISPATCH'" 2>/dev/null )
}
run_ledger() {  # arm_ledger CLI — cwd가 WORK여야 state_root·git이 이 리포를 본다
  ( cd "$WORK" && python3 "$LEDGER" "$@" )
}
run_ledger_rc() {  # rc를 살려서 부르는 변형(T11). stdout+stderr 합본.
  ( cd "$WORK" && python3 "$LEDGER" "$@" ) 2>&1
}
state_of() { echo "$WORK/.claude/spec-distill/$1/state.local.md"; }

arm_summary() {
  echo
  echo "Total: $((pass+fail)) | Pass: $pass | Fail: $fail"
  [[ $fail -eq 0 ]]
}
```

- [ ] **Step 1b: 테스트 파일 작성 — `tests/test_arm_once.sh`**

```bash
#!/usr/bin/env bash
# T1·T2·T3 — arm-once 게이트 (v0.25.0 §5.1).
#
# 재는 것은 **pending 파일 쓰기 횟수가 아니라 dispatch emit 횟수**다(§10 T1). 두 번째
# 편집이 pending을 덮어쓰는 것은 §5.2가 명시한 의도된 동작이므로 "기록 1회"를 assert하면
# 설계와 모순되는 것을 재게 된다.
set -u -o pipefail
source "$(dirname "$0")/arm_test_helpers.sh"
arm_work_init specdistill-armonce

# --- T1: 리뷰가 완료된 뒤의 편집은 재arm 하지 않는다 (dispatch emit 1회) ---
# mark-reviewed가 시퀀스에 반드시 포함된다 — 그것이 T1(verdict 이후 재arm 없음)과
# T8(verdict 이전 재시도 있음)을 가르는 유일한 사건이다. 빼면 두 락이 같은 상태에
# 반대 결과를 요구해 하나는 반드시 실패한다.
SID1=t1-armonce
REL1="docs/superpowers/specs/2026-08-01-t1-design.md"
new_doc "$REL1"
run_validator "$REL1" "$SID1" >/dev/null
emit1=$(run_stop "$SID1")
run_ledger mark-reviewed "$SID1" "$WORK/$REL1" >/dev/null 2>&1
edit_doc "$REL1" 2
run_validator "$REL1" "$SID1" >/dev/null
emit2=$(run_stop "$SID1")
if echo "$emit1" | jq -e '.decision == "block"' >/dev/null 2>&1 && [[ -z "$emit2" ]]; then
  note PASS "T1: verdict 이후 편집은 재arm 없음 (dispatch emit 1회)"
else
  note FAIL "T1 실패: emit1='$emit1' emit2='$emit2' state=$(cat "$(state_of "$SID1")")"
fi

# --- T2: git이 아는 문서는 armed_paths가 비어 있어도 arm 하지 않는다 ---
SID2=t2-born
REL2="docs/superpowers/specs/2026-08-01-t2-design.md"
new_doc "$REL2"
( cd "$WORK" && git add "$REL2" && git commit -q -m born ) || exit 1
out2=$(run_validator "$REL2" "$SID2")
sf2="$(state_of "$SID2")"
armed_empty=1
[[ -f "$sf2" ]] && grep -q '^armed_paths:' "$sf2" && armed_empty=0
if [[ $armed_empty -eq 1 ]] \
  && { [[ ! -f "$sf2" ]] || ! grep -q '^pending_review:' "$sf2"; } \
  && echo "$out2" | jq -e '.hookSpecificOutput.additionalContext | contains("git이 아는 문서")' >/dev/null 2>&1; then
  note PASS "T2: git-tracked 문서 → 원장이 비어도 arm 없음 + git 사유 advisory"
else
  note FAIL "T2 실패: out='$out2' state=$( [[ -f "$sf2" ]] && cat "$sf2" || echo '(없음)')"
fi

# --- T3: git 판정 실패는 arm 쪽으로 fail-open **하고** loud 하다 (양방향 락) ---
# 한 방향(arm 발생)만 잠그면 advisory 없이 조용히 arm해도 통과한다.
SID3=t3-nogit
REL3="docs/superpowers/specs/2026-08-01-t3-design.md"
new_doc "$REL3"
mkdir -p "$WORK/fakebin"
printf '#!/bin/sh\nexit 42\n' > "$WORK/fakebin/git"
chmod +x "$WORK/fakebin/git"
all3=$(run_validator_all "$REL3" "$SID3" "PATH=$WORK/fakebin:$PATH")
sf3="$(state_of "$SID3")"
if [[ -f "$sf3" ]] && grep -q '^pending_review:' "$sf3" \
  && grep -q 'exit=42' <<<"$all3"; then
  note PASS "T3: git 불능 → arm 발생(fail-open) + exit code 포함 loud advisory"
else
  note FAIL "T3 실패: out='$all3' state=$( [[ -f "$sf3" ]] && cat "$sf3" || echo '(없음)')"
fi

arm_summary
```

- [ ] **Step 2: 실행 — GREEN 확인**

```bash
chmod +x tests/test_arm_once.sh
bash tests/test_arm_once.sh
```

Expected: `Total: 3 | Pass: 3 | Fail: 0`

> T3 이 `exit=42` 를 못 찾으면 fake git 이 `state_path.state_root()` 의 `git rev-parse` 도 42 로 죽여 state root 가 cwd fallback 으로 가는 것을 확인한다 — fallback 위치도 `$WORK/.claude/spec-distill` 이라 결과는 같아야 한다. 다르면 픽스처의 cwd 가 `$WORK` 가 아니다.

- [ ] **Step 3: mutation 3종 — 각 락의 이빨 증명**

```bash
cp hooks/spec-write-validator.py /tmp/v.bak
cp scripts/arm_ledger.py /tmp/al.bak

# T1 mutation: 원장 게이트 제거(is_armed를 항상 False로) → T1 RED
python3 - <<'PY'
import pathlib
p = pathlib.Path("scripts/arm_ledger.py"); t = p.read_text(encoding="utf-8")
p.write_text(t.replace("    return key in armed_keys(_read_body(state_file))",
                       "    return False"), encoding="utf-8")
PY
bash tests/test_arm_once.sh 2>&1 | grep -E '^\s+[✓✗] T1'   # 기대: ✗ T1
cp /tmp/al.bak scripts/arm_ledger.py

# T2 mutation: git 조건 제거 → T2 RED
python3 - <<'PY'
import pathlib
p = pathlib.Path("scripts/arm_ledger.py"); t = p.read_text(encoding="utf-8")
p.write_text(t.replace(
    "    return not is_armed(state_file, raw_path) and not is_born(raw_path)",
    "    return not is_armed(state_file, raw_path)"), encoding="utf-8")
PY
bash tests/test_arm_once.sh 2>&1 | grep -E '^\s+[✓✗] T2'   # 기대: ✗ T2
cp /tmp/al.bak scripts/arm_ledger.py

# T3 mutation: fail 방향을 arm-skip으로 뒤집기 → T3 RED
python3 - <<'PY'
import pathlib
p = pathlib.Path("scripts/arm_ledger.py"); t = p.read_text(encoding="utf-8")
t = t.replace("""    if cp.returncode == 0:
        return True
    if cp.returncode != 1:""", """    if cp.returncode != 1:
        return True
    if False:""")
p.write_text(t, encoding="utf-8")
PY
bash tests/test_arm_once.sh 2>&1 | grep -E '^\s+[✓✗] T3'   # 기대: ✗ T3
cp /tmp/al.bak scripts/arm_ledger.py && rm -f /tmp/al.bak /tmp/v.bak

bash tests/test_arm_once.sh 2>&1 | tail -2                 # 기대: Fail: 0
```

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/tests/arm_test_helpers.sh plugins/spec-distill/tests/test_arm_once.sh
git status --short plugins/spec-distill/tests/   # 두 파일 모두 staged인지 눈으로 확인
git commit -m "$(cat <<'EOF'
test(spec-distill): T1·T2·T3 — arm 게이트 회귀 락 + 공유 하니스

T1은 emit 횟수를 잰다(파일 쓰기 횟수 아님 — §5.2의 덮어쓰기는 의도된 동작).
시퀀스에 mark-reviewed가 포함돼야 T8과 갈린다. TTL=0 고정.
T3은 양방향 — arm 발생 + exit code 포함 stderr advisory 둘 다 assert.

mutation: is_armed 무력화 → T1 RED / is_born 조건 제거 → T2 RED /
git 실패 방향 반전 → T3 RED. 셋 다 확인.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 8: T6–T12 — `tests/test_arm_ledger_timing.sh`

기록 **시점**의 락들이다. T6 은 진입 시 strip, T7 은 verdict 시 원장 기록, T8 은 **기록이 일어나지 않았을 때의 자기치유**. 셋을 합치면 일부만 구현해도 통과하는 락이 된다. **T7 과 T8 은 서로 반대 방향이라 함께 있어야 이빨이 생긴다** — T7 만 있으면 "항상 기록"하는 구현이 통과하고(영구-표시 문제), T8 만 있으면 "절대 기록 안 함"이 통과한다(매-라운드 재발동). 두 mutation 이 서로의 반례다.

**Files:**
- Create: `plugins/spec-distill/tests/test_arm_ledger_timing.sh`

**Interfaces:**
- Consumes: `tests/arm_test_helpers.sh` (Task 7 이 만든 공유 하니스 — `MERGE`·`SKILL`·`run_ledger_rc` 포함), `scripts/merge_review.py`, `skills/reviewing-spec/SKILL.md`
- Produces: 없음 (최종 락)

- [ ] **Step 1: 테스트 파일 헤더 — 하니스를 `source` 한다**

**복제하지 않는다** (pre-flight ruling — Task 7 참조). 헤더는 이 다섯 줄이 전부다:

```bash
#!/usr/bin/env bash
# T6–T12 — 기록 시점·자기치유·G6 상한·훅 통합·check-born·fail-safe 배제 (v0.25.0).
set -u -o pipefail
source "$(dirname "$0")/arm_test_helpers.sh"
arm_work_init specdistill-armtiming
```

- [ ] **Step 2: T6·T7·T8 본문**

```bash
# --- T6: 진입 시 strip-pending 이 §5.4 5단계(지연 재소비)를 불가능하게 만든다 ---
# rewrite_state 실패를 주입할 필요가 없다 — pending이 남아 있는 상태를 픽스처로 만들고
# strip 전후의 Stop 동작 차이를 잰다.
SID6=t6-strip
REL6="docs/superpowers/specs/2026-08-01-t6-design.md"
new_doc "$REL6"
run_validator "$REL6" "$SID6" >/dev/null
sf6="$(state_of "$SID6")"
grep -q '^pending_review:' "$sf6" || note FAIL "T6 준비 실패: pending 미생성"
run_ledger strip-pending "$SID6" "$WORK/$REL6" >/dev/null 2>&1
emit6=$(run_stop "$SID6")
if [[ -z "$emit6" ]] && ! grep -q '^pending_review:' "$sf6"; then
  note PASS "T6: 진입 strip 이후 Stop 재발화 → 무-emit (지연 재소비 봉쇄)"
else
  note FAIL "T6 실패: emit='$emit6' state=$(cat "$sf6")"
fi

# --- T7: verdict 시 원장 기록 → 키 존재 + 이어지는 편집이 재arm 하지 않는다 ---
SID7=t7-verdict
REL7="docs/superpowers/specs/2026-08-01-t7-design.md"
new_doc "$REL7"
run_validator "$REL7" "$SID7" >/dev/null
run_stop "$SID7" >/dev/null
run_ledger mark-reviewed "$SID7" "$WORK/$REL7" >/dev/null 2>&1
sf7="$(state_of "$SID7")"
edit_doc "$REL7" 2
run_validator "$REL7" "$SID7" >/dev/null
emit7=$(run_stop "$SID7")
if grep -q "^  - $REL7\$" "$sf7" \
  && ! grep -q '^pending_review:' "$sf7" \
  && [[ -z "$emit7" ]]; then
  note PASS "T7: mark-reviewed → armed_paths 기록 + 이후 편집 재arm 없음"
else
  note FAIL "T7 실패: emit='$emit7' state=$(cat "$sf7")"
fi

# --- T8: verdict 없이 중단된 리뷰는 다음 편집에서 자기치유한다 (T7의 반례) ---
# 리뷰가 끝나지 않으면 재시도되는 것이 의도된 동작이다 — 재시도가 없으면 그 문서는
# 유일한 자동 리뷰 기회를 조용히 잃는다.
SID8=t8-selfheal
REL8="docs/superpowers/specs/2026-08-01-t8-design.md"
new_doc "$REL8"
run_validator "$REL8" "$SID8" >/dev/null
emit8a=$(run_stop "$SID8")
# verdict 없이 중단 — mark-reviewed를 부르지 않는다.
edit_doc "$REL8" 2
run_validator "$REL8" "$SID8" >/dev/null
emit8b=$(run_stop "$SID8")
sf8="$(state_of "$SID8")"
if echo "$emit8a" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && echo "$emit8b" | jq -e '.decision == "block"' >/dev/null 2>&1 \
  && ! grep -q '^armed_paths:' "$sf8"; then
  note PASS "T8: verdict 없는 중단 → 다음 편집이 재arm + 재dispatch (자기치유)"
else
  note FAIL "T8 실패: emit1='$emit8a' emit2='$emit8b' state=$(cat "$sf8")"
fi
```

- [ ] **Step 3: T9·T10 본문**

```bash
# --- T9: G6 상한 (§5.2 상태기계) ---
# 3회차가 마지막 자동 dispatch이고 그 emit이 상한을 알리는 vehicle이다.
# "4회차가 억제된다"가 아니다 — 이후 편집은 validator 층에서 pending 자체가 안 생긴다.
SID9=t9-cap
REL9="docs/superpowers/specs/2026-08-01-t9-design.md"
new_doc "$REL9"
e1=""; e2=""; e3=""
for i in 1 2 3; do
  edit_doc "$REL9" "$i"
  run_validator "$REL9" "$SID9" >/dev/null
  case $i in
    1) e1=$(run_stop "$SID9") ;;
    2) e2=$(run_stop "$SID9") ;;
    3) e3=$(run_stop "$SID9") ;;
  esac
done
sf9="$(state_of "$SID9")"
cap_ok=1
echo "$e1" | jq -e '.decision == "block"' >/dev/null 2>&1 || cap_ok=0
echo "$e2" | jq -e '.decision == "block"' >/dev/null 2>&1 || cap_ok=0
echo "$e1" | jq -e '.reason | contains("3회 시도")' >/dev/null 2>&1 && cap_ok=0
echo "$e3" | jq -e '.decision == "block"' >/dev/null 2>&1 || cap_ok=0
echo "$e3" | jq -e '.reason | contains("3회 시도")' >/dev/null 2>&1 || cap_ok=0
grep -q "^  - $REL9\$" "$sf9" || cap_ok=0
grep -q "^  $REL9: 3\$" "$sf9" || cap_ok=0
# 상한 도달 이후의 편집: pending 자체가 생기지 않고 Stop이 볼 것이 없다.
edit_doc "$REL9" 4
out9=$(run_validator "$REL9" "$SID9")
grep -q '^pending_review:' "$sf9" && cap_ok=0
echo "$out9" | jq -e '.systemMessage | contains("capped")' >/dev/null 2>&1 || cap_ok=0
[[ -z "$(run_stop "$SID9")" ]] || cap_ok=0
if [[ $cap_ok -eq 1 ]]; then
  note PASS "T9: 3회차 emit에 상한 advisory + armed 기록, 이후 편집은 pending 미생성"
else
  note FAIL "T9 실패: e1='$e1' e3='$e3' out4='$out9' state=$(cat "$sf9")"
fi

# --- T10: Stop의 dispatch 단독으로는 원장을 쓰지 않는다 (훅 통합 지점) ---
# T7·T8은 arm_ledger CLI 의미만 재므로 mark_armed를 Stop과 skill 양쪽에서 부르는
# 잘못된 구현도 둘 다 통과한다. T10만이 그 구현을 RED로 만든다 — 산문이 아니라
# 실행으로 소유권을 고정한다.
SID10=t10-noarm
REL10="docs/superpowers/specs/2026-08-01-t10-design.md"
new_doc "$REL10"
run_validator "$REL10" "$SID10" >/dev/null
run_stop "$SID10" >/dev/null
sf10="$(state_of "$SID10")"
if ! grep -q '^armed_paths:' "$sf10" && grep -q "^  $REL10: 1\$" "$sf10"; then
  note PASS "T10: dispatch 단독(상한 미달) → armed_paths 비어 있음, attempts=1"
else
  note FAIL "T10 실패: state=$(cat "$sf10")"
fi
```

- [ ] **Step 4: T11·T12 본문**

```bash
# --- T11: check-born 은 dangling in-scope 경로에서 crash 하지 않는다 ---
# 삭제되는 test_handoff_spec_path_validation.sh 가 잠그던 불변식의 승계처(§9).
DANGLE="docs/superpowers/specs/2026-08-01-does-not-exist-design.md"
out11=$(run_ledger_rc check-born "$WORK/$DANGLE"); rc11=$?
if [[ $rc11 -eq 1 ]] && grep -q '아직 git에 없다' <<<"$out11" \
  && ! grep -q 'Traceback' <<<"$out11"; then
  note PASS "T11: check-born dangling in-scope → rc=1 + 미커밋 advisory, 무-crash"
else
  note FAIL "T11 실패: rc=$rc11 out='$out11'"
fi

# --- T12: both-dead fail-safe 라운드는 원장에 기록하지 않는다 ---
# 두 층으로 잠근다. (a) skill이 keying하는 신호가 merge_review 출력에 실제로 존재하고,
# (b) SKILL.md의 mark-reviewed 지시가 그 배제 조건과 **같은 섹션 윈도우 안에** 있다.
# (a)만으로는 지시가 사라져도 통과하고, (b)만으로는 신호가 사라져 지시가 따를 수 없게
# 돼도 통과한다.
printf 'no status line here\n' > "$WORK/claude.txt"
printf '{"issue_history": []}\n' > "$WORK/hist.json"
mout=$(python3 "$MERGE" --claude-output "$WORK/claude.txt" \
         --codex-yaml /nonexistent --history "$WORK/hist.json" 2>/dev/null)
if grep -q '^claude_verdict_unrecoverable: true$' <<<"$mout" \
  && grep -q '^codex_degraded: true$' <<<"$mout" \
  && grep -q '^combined_verdict: needs_revise$' <<<"$mout"; then
  note PASS "T12a: both-dead가 combined_verdict를 내면서 두 degrade flag를 함께 emit"
else
  note FAIL "T12a 실패: merge_review out='$mout'"
fi

# 섹션 윈도우 — 헤더-satisfiable 회피를 위해 blockquote/헤더가 아닌 **본문 고유** 토큰을
# 윈도우 안에서 찾는다. 빈 윈도우는 앵커가 깨진 것이므로 FAIL(조용한 통과 금지).
win="$(awk '/리뷰 완료 기록/{f=1} /^## /{f=0} f' "$SKILL")"
if [[ -n "$win" ]] \
  && grep -q 'mark-reviewed' <<<"$win" \
  && grep -q 'claude_verdict_unrecoverable' <<<"$win" \
  && grep -q 'codex_degraded' <<<"$win"; then
  note PASS "T12b: SKILL Step 3의 mark-reviewed 지시가 both-dead 배제 조건과 같은 블록"
else
  note FAIL "T12b 실패: window=$(wc -l <<<"$win")줄"
fi

arm_summary
```

- [ ] **Step 5: 실행 — GREEN 확인**

```bash
chmod +x tests/test_arm_ledger_timing.sh
bash tests/test_arm_ledger_timing.sh
```

Expected: `Total: 8 | Pass: 8 | Fail: 0` (T6·T7·T8·T9·T10·T11·T12a·T12b)

- [ ] **Step 6: mutation 6종**

```bash
cp scripts/arm_ledger.py /tmp/al.bak
cp hooks/review-dispatch.py /tmp/rd.bak
cp skills/reviewing-spec/SKILL.md /tmp/sk.bak
m() { python3 - "$@" <<'PY'
import pathlib, sys
p = pathlib.Path(sys.argv[1]); t = p.read_text(encoding="utf-8")
old, new = sys.argv[2], sys.argv[3]
assert old in t, f"MISS: {old[:60]}"
p.write_text(t.replace(old, new, 1), encoding="utf-8")
PY
}

# T6: strip_pending 을 no-op 으로 → T6 RED
m scripts/arm_ledger.py 'return PENDING_RE.sub("", body)' 'return body'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T6'
cp /tmp/al.bak scripts/arm_ledger.py

# T7: mark_reviewed 가 armed 를 안 쓰게 → T7 RED (T8은 여전히 GREEN이어야 한다)
m scripts/arm_ledger.py '    keys = armed_keys(body)
    if key not in keys:
        keys.append(key)
    att = attempts(body)
    att.pop(key, None)' '    keys = armed_keys(body)
    att = attempts(body)
    att.pop(key, None)'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T[78]'
cp /tmp/al.bak scripts/arm_ledger.py

# T8: 기록을 진입 시점으로 되돌리기(strip 이 armed 도 찍게) → T8 RED (T7은 GREEN)
m scripts/arm_ledger.py '        state_file.write_text(strip_pending(body).rstrip() + "\n", encoding="utf-8")' \
  '        state_file.write_text(mark_armed(strip_pending(body), raw_path), encoding="utf-8")'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T[678]'
cp /tmp/al.bak scripts/arm_ledger.py

# T9: 상한 검사 제거 → T9 RED
m scripts/arm_ledger.py 'if n >= DISPATCH_ATTEMPT_CAP and key not in keys:' 'if False:'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T9'
cp /tmp/al.bak scripts/arm_ledger.py

# T10: Stop 이 매번 armed 를 찍게 → T10 RED
m hooks/review-dispatch.py 'body = arm_ledger.record_attempt(body, spec_path, attempt_n)' \
  'body = arm_ledger.mark_armed(arm_ledger.record_attempt(body, spec_path, attempt_n), spec_path)'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T10'
cp /tmp/rd.bak hooks/review-dispatch.py

# T11: dangling 에서 예외를 던지게 → T11 RED
m scripts/arm_ledger.py '        if is_born(raw_path):' \
  '        open(raw_path, "r").close()
        if is_born(raw_path):'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T11'
cp /tmp/al.bak scripts/arm_ledger.py

# T12b: 배제 문장을 지우기 → T12b RED (T12a 는 GREEN 유지 — 두 층이 독립임을 보인다)
m skills/reviewing-spec/SKILL.md 'claude_verdict_unrecoverable' 'CLAUDE_VERDICT_PLACEHOLDER_REMOVED'
bash tests/test_arm_ledger_timing.sh 2>&1 | grep -E '^\s+[✓✗] T12'
cp /tmp/sk.bak skills/reviewing-spec/SKILL.md

rm -f /tmp/al.bak /tmp/rd.bak /tmp/sk.bak
bash tests/test_arm_ledger_timing.sh 2>&1 | tail -2   # 기대: Fail: 0
```

> T12b mutation 이 T12a 를 죽이지 않는지 반드시 확인한다. 둘이 함께 죽으면 두 층이 사실 하나라는 뜻이고, 그러면 `mark-reviewed` 지시가 사라져도 잡히지 않는 구멍이 남는다.

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/tests/test_arm_ledger_timing.sh
git commit -m "$(cat <<'EOF'
test(spec-distill): T6–T12 — 기록 시점·자기치유·G6 상한·훅 통합 락

T7과 T8은 서로 반대 방향이라 함께 있어야 이빨이 생긴다(한쪽만 두면 "항상
기록"/"절대 기록 안 함" 구현이 조용히 통과). T10은 arm_ledger CLI 의미가
아니라 Stop 훅의 원장 무-기록을 잰다 — 산문이 아니라 실행으로 소유권 고정.
T12는 두 층(merge_review 신호 존재 + SKILL 섹션 윈도우)으로 잠근다.

mutation 6종 전부 확인: strip no-op→T6 / mark_reviewed 원장 제거→T7(T8 green) /
진입 시점 기록→T8(T7 green) / 상한 제거→T9 / Stop mark_armed→T10 /
dangling 예외→T11 / 배제 문장 삭제→T12b(T12a green).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: 삭제 스윕 — 파일 12종 + 죽은 참조 정리

원인이 사라졌으므로 원인을 막던 층도 사라진다(G3 — 축소가 아니라 삭제). 이 태스크가 끝나면 production 어디에도 옛 식별자가 남지 않는다. **Task 10 의 T4 는 그 사실을 잠그는 락**이므로 순서가 뒤집히면 안 된다.

> §12 구현 순서의 "6. 삭제 스윕 → 7. 문서 동기화" 를 따르되, README·SKILL 의 **죽은 참조 제거**를 이 태스크에 포함한다. T4 의 스윕 스코프가 `README.md` 를 포함하는 production 전수라, 참조 제거를 Task 10 으로 미루면 T4 가 태스크 경계에서 RED 가 된다(Global Constraints 편차 2번).

**Files:**
- Delete: 12개 (아래 목록)
- Modify: `README.md`, `skills/conducting-interview/SKILL.md:469`, `tests/test_readme_sync.sh:52`

**Interfaces:**
- Consumes: 없음
- Produces: `git grep` 으로 옛 식별자 production 0건 — Task 10 의 T4·T5 가 이것을 잠근다

- [ ] **Step 1: 삭제 전 확인 — 참조가 정말 남지 않았는지**

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+spec-distill-arm-once/plugins/spec-distill
grep -rn "suppress_state\|review_lock\|approve_handoff\|cancel_review" \
  hooks/ scripts/ skills/ commands/ 2>/dev/null \
  | grep -v "scripts/review_lock.py\|scripts/cancel_review.py\|scripts/approve_handoff.sh\|scripts/suppress_state.py\|commands/cancel-review.md"
```

Expected: `skills/conducting-interview/SKILL.md:469` 한 건만 (Step 3 에서 처리). 그 외가 나오면 Task 3–6 이 덜 끝난 것이므로 **여기서 멈추고** 해당 태스크로 돌아간다.

- [ ] **Step 2: 파일 삭제**

```bash
git rm -q \
  scripts/review_lock.py \
  scripts/cancel_review.py \
  scripts/approve_handoff.sh \
  scripts/suppress_state.py \
  commands/cancel-review.md \
  tests/test_review_lock.py \
  tests/test_review_lock_session_id.sh \
  tests/test_reviewing_spec_lock.sh \
  tests/test_cancel_review.py \
  tests/test_approve_handoff.sh \
  tests/test_handoff_compact_chain.sh \
  tests/test_handoff_spec_path_validation.sh
ls tests/test_*.sh | wc -l    # 기대: 48  (arm_test_helpers.sh 는 테스트가 아니라 제외)
ls tests/test_*.py | wc -l    # 기대: 9
```

> 두 handoff 테스트는 실측 결과 **전적으로 `approve_handoff.sh` 만** 검증한다(`compact_chain`: exit 0 · marker dir 부재 · 억제 기록 · 세션 dir 보존 / `spec_path_validation`: in-scope dangling 경로여도 abort 안 함). 대상 스크립트가 사라지므로 수정이 아니라 삭제다. 잔여 커버리지: 세션 dir 보존은 `test_gc.py`·`test_session_end_cleanup.py` 가 이미 잠그고 있고, dangling 경로 불변식은 **T11** 이 승계했다(Task 8).

- [ ] **Step 3: `conducting-interview/SKILL.md:469` 의 죽은 참조 제거**

```
`/compact`를 노출하지 *않고* loud advisory 후 STOP(`approve_handoff.sh` 미호출 — 설계 §5.3):
```
→
```
`/compact`를 노출하지 *않고* loud advisory 후 STOP(brief 는 막 검증됐고 하류·SessionEnd 가 cleanup 을 맡는다 — 설계 §5.3):
```

- [ ] **Step 4: README 의 죽은 참조 제거**

아래 12곳을 고친다. 옛 식별자를 **한 글자도 남기지 않는다** — Task 10 의 T4 가 고정 문자열로 스윕한다. 역사 서술이 필요하면 개념어로 쓰고 상세는 CHANGELOG 로 넘긴다(CHANGELOG 는 append-only 기록이라 스윕에서 제외돼 있다).

| 위치 | 조치 |
|---|---|
| `:54`·`:56`·`:58` (v0.14.0 / v0.15.0 / v0.18.0 세 줄) | 아래 한 줄로 **합쳐 교체** |
| `:80` (AP2 approval-gate) | finalizer 문장을 `arm_ledger.py check-born` 미커밋 advisory 로 교체 |
| `:81` (Law 1 fail-safe + Law 2 v0.18.0) | v0.25.0 서술로 교체 (아래) |
| `:99` (P17) | per-doc 취소 게이트 언급 삭제, 나머지 유지 |
| `:116` (AP2) | `approve_handoff.sh` 미호출 문구를 개념어로 |
| `:122` (Law 2 load-bearing) | 항목 삭제 — 대상 스크립트가 사라졌다 |
| `:123` (P3) | `(approve_handoff)` → `(check-born)` |
| `:138`·`:139`·`:140` (Hooks Installed 표) | v0.25.0 동작으로 갱신 |
| `:154` (락 TTL env) | **줄 삭제** |
| `:157` (SessionEnd kill switch) | `approve_handoff.sh` + TTL-GC → TTL-GC |
| `:165` (`/spec-distill:cancel-review`) | **줄 삭제** |

`:54`–`:58` 교체 문안:

```markdown
**v0.14.0–v0.18.0**: 리뷰 재발동을 막는 방어층 3종이 순차로 쌓였다 — 문서별 억제 집합, approve 시 기록 순서 교정, 문서-키 진행중 락. 셋 다 훅이 자기가 만든 재발동을 자기가 막는 내부 하니스였고 **v0.25.0 에서 원인과 함께 삭제**됐다(상세는 CHANGELOG).
```

`:81` 교체 문안:

```markdown
- **Law 1 fail-safe + Law 2 (v0.25.0)** — arm 판정(`scripts/arm_ledger.py`)의 어떤 실패(원장 read 불능, git 불능·리포 밖, 모듈 부재)도 **arm 쪽으로 fail-open** 한다(over-review > under-review). 예외는 `session_id` 미해석 하나 — 그것은 판정 신호가 아니라 상태를 어디에 쓸지 정하는 주소라, 미해석 상태의 arm 은 원장 없는 pending 을 만들어 fail-open 의 취지와 반대 결과가 된다. 원장 기록은 **verdict 가 나온 리뷰 자신**이 하고 훅은 판정만 한다 — writer 가 자기 리뷰를 억제할 물리적 경로가 없다.
```

`:138`–`:140` 표 셀 교체 문안:

- PostToolUse 책임 셀 끝: `**v0.25.0: arm 직전 `should_arm`(세션 원장 ∧ git 추적 여부) 게이트 — 이미 리뷰됐거나 커밋된 문서는 arm skip(Layer 1 은 불변). skip 사유를 세 가지로 구분해 표시한다.**`
- Stop 책임 셀 끝: `**v0.25.0: `dispatch_attempts` 증가 + G6 상한(3회) 도달 시에만 원장 기록 — 정상 dispatch 는 원장을 건드리지 않는다.**`
- UserPromptSubmit 책임 셀 끝: `**v0.25.0: 원장을 기록하지 않는다 — 재-nag 는 리뷰의 완료가 아니다.**`

- [ ] **Step 5: `test_readme_sync.sh` 키워드 목록 갱신**

52행의 `for kw in ...` 목록에서 `'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC'`, `'review_in_progress'`, `'cancel-review'` 세 개를 빼고 `'armed_paths'`, `'arm-once'` 두 개를 넣는다. 죽은 키워드를 남기면 README 가 삭제된 surface 를 계속 광고해야 하고, 새 키워드를 안 넣으면 새 surface 가 무검증으로 남는다.

- [ ] **Step 6: 전 스위트 실행 — red 0건 확인**

```bash
red=0
for t in tests/test_*.sh; do
  bash "$t" >/dev/null 2>&1 || { echo "RED: $t"; red=$((red+1)); }
done
python3 -m unittest discover -s tests -p 'test_*.py' 2>&1 | tail -3
echo "bash red=$red"
```

Expected: `bash red=1` — `test_stale_terms.sh` 는 Task 10 에서 T4·T5 를 얹을 때까지 초록이고, 여기서 red 가 나오면 안 된다. 즉 **기대는 `bash red=0`**. python 은 알려진 cross-resolver 1건만 fail.

- [ ] **Step 7: 커밋**

```bash
git add -A plugins/spec-distill
git commit -m "$(cat <<'EOF'
refactor(spec-distill)!: 재발동 방어 하니스 4층 삭제 (파일 12종)

review_lock.py(240) · cancel_review.py(99) · approve_handoff.sh(98) ·
suppress_state.py(242) + /cancel-review 커맨드 + 전용 테스트 7종.
원인(편집마다 재arm)이 사라졌으므로 원인을 막던 층도 근거를 잃는다.

두 handoff 테스트는 실측 결과 전적으로 approve_handoff.sh만 검증한다 —
잔여 커버리지는 test_gc/test_session_end_cleanup(세션 dir 보존)과
T11(dangling 경로 무-abort)이 승계.

README·conducting-interview의 죽은 참조 제거 + readme-sync 키워드 목록을
armed_paths·arm-once로 교체.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: T4·T5 스윕 락 + 0.25.0 문서 동기화

삭제가 **완결**됐음을 기계가 증명하게 만들고, 버전·CHANGELOG·README 를 0.25.0 으로 맞춘다. T4 의 스윕 대상은 식별자만이 아니라 **같은 것을 다른 이름으로 부른 참조**까지다.

**Files:**
- Modify: `plugins/spec-distill/tests/test_stale_terms.sh` (T4·T5 추가)
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (버전 assert + CHANGELOG append-only 누산)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`, `CHANGELOG.md`, `README.md`

**Interfaces:**
- Consumes: Task 1 의 앵커된 `prod_files` 배열
- Produces: 없음 (최종)

- [ ] **Step 1: T4·T5 를 `test_stale_terms.sh` 에 추가**

V8 블록 뒤, 최종 summary 앞에 넣는다:

```bash
# --- V9 (v0.25.0 / T4): arm-once 삭제 스윕 완결 락 ---
# 스코프 = prod_files 그대로(README.md 포함, tests/·CHANGELOG.md 제외).
# 식별자만이 아니라 **같은 것을 다른 이름으로 부른 참조**까지 열거한다 — 식별자만
# grep하면 개념 별칭으로 살아남은 참조를 놓친다.
# CHANGELOG.md 제외는 released 기록이라 유효하다(이 삭제를 서술하는 [0.25.0] 엔트리가
# 이 리터럴들을 인용해야 한다). tests/ 제외는 이 파일 자신이 토큰을 *집행*하는 층이기
# 때문이다 — 배열 리터럴이 매치를 자기 자신에게서 찾으면 락이 영구 RED가 된다.
removed_terms=(
  'review_lock'
  'review_in_progress'
  'suppress_state'
  'suppressed_paths'
  'cancel_review'
  'cancel-review'
  'approve_handoff'
  'DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC'
)
for term in "${removed_terms[@]}"; do
  scan -InIF -- "$term" "${prod_files[@]}"
  if [[ $SCAN_RC -ge 2 ]]; then
    note FAIL "V9/T4: '$term' 검사가 실행되지 않았다 — grep 자체 실패(exit=$SCAN_RC):"
    printf '%s\n' "$SCAN_OUT"
  elif [[ $SCAN_RC -eq 0 ]]; then
    note FAIL "V9/T4: '$term' 가 production에 잔존:"; printf '%s\n' "$SCAN_OUT"
  else
    note PASS "V9/T4: '$term' 잔존 0건 (production)"
  fi
done

# --- V10 (v0.25.0 / T5): 삭제 대상 파일 부재 ---
# 파일이 되살아나면 무참조 상태로 조용히 눌러앉는다 — 참조 스윕(V9)만으로는 못 잡는다.
removed_files=(
  'scripts/review_lock.py'
  'scripts/cancel_review.py'
  'scripts/approve_handoff.sh'
  'scripts/suppress_state.py'
  'commands/cancel-review.md'
  'tests/test_review_lock.py'
  'tests/test_review_lock_session_id.sh'
  'tests/test_reviewing_spec_lock.sh'
  'tests/test_cancel_review.py'
  'tests/test_approve_handoff.sh'
  'tests/test_handoff_compact_chain.sh'
  'tests/test_handoff_spec_path_validation.sh'
)
for rf in "${removed_files[@]}"; do
  [[ ! -e "$SD/$rf" ]] \
    && note PASS "V10/T5: '$rf' 부재" \
    || note FAIL "V10/T5: '$rf' 가 되살아났다"
done

# --- V11 (v0.25.0): 대체 surface 가 실재한다 (음의 락만 두면 전부 지워도 통과) ---
[[ -f "$SD/scripts/arm_ledger.py" ]] \
  && note PASS "V11: arm_ledger.py 실재" || note FAIL "V11: arm_ledger.py 부재"
scan -InIF -- 'should_arm' "$SD/hooks/spec-write-validator.py"
[[ $SCAN_RC -eq 0 ]] \
  && note PASS "V11: validator 가 should_arm 게이트를 부른다" \
  || note FAIL "V11: validator 에 should_arm 호출이 없다 (게이트 증발)"
```

> **V11 이 없으면 V9·V10 은 "전부 지우면 통과"하는 음의 락**이다. 삭제 락에는 반드시 대체물의 존재 락을 짝지어야 한다.

- [ ] **Step 2: GREEN 확인 + mutation 3종**

```bash
bash tests/test_stale_terms.sh 2>&1 | tail -3     # 기대: Fail: 0 (총 30개 근처)

# T4 mutation: 옛 용어 하나를 production 에 되살리기 → RED
printf '\n<!-- suppressed_paths -->\n' >> README.md
bash tests/test_stale_terms.sh 2>&1 | grep "V9/T4: 'suppressed_paths'"   # 기대: ✗
git checkout -- README.md

# T5 mutation: 삭제 파일 하나를 되살리기 → RED
touch scripts/review_lock.py
bash tests/test_stale_terms.sh 2>&1 | grep "V10/T5: 'scripts/review_lock.py'"  # 기대: ✗
rm scripts/review_lock.py

# V11 mutation: 게이트 호출 제거 → RED
python3 - <<'PY'
import pathlib
p = pathlib.Path("hooks/spec-write-validator.py"); t = p.read_text(encoding="utf-8")
p.with_suffix(".py.bak").write_text(t, encoding="utf-8")
p.write_text(t.replace("arm_ledger.should_arm", "arm_ledger.is_armed"), encoding="utf-8")
PY
bash tests/test_stale_terms.sh 2>&1 | grep "V11: validator"   # 기대: ✗
mv hooks/spec-write-validator.py.bak hooks/spec-write-validator.py

bash tests/test_stale_terms.sh 2>&1 | tail -2     # 기대: Fail: 0
```

- [ ] **Step 3: `plugin.json` 0.25.0**

```json
  "version": "0.25.0",
```

- [ ] **Step 4: CHANGELOG `[0.25.0]` 엔트리 (맨 위에 추가)**

```markdown
## [0.25.0] — 2026-08-02

design doc auto-review 를 **문서가 처음 생길 때 한 번만** 발동시키고, 그 재발동을 막으려
v0.14.0–v0.18.0 에 쌓인 방어층 4개를 원인과 함께 걷어냈다. 교훈 한 줄: **원인을 지우면
그 원인을 막던 방어층도 같이 지워진다** — 셋 다 사용자 기능이 아니라 훅이 자기가 만든
문제를 자기가 막는 내부 하니스였다.

### Changed
- **arm 조건이 `(세션 원장에 없음) AND (git 이 모르는 문서)` 로 바뀌었다.** 판정은
  `scripts/arm_ledger.py` 의 `should_arm()` 한 곳에만 존재하고 훅은 그것만 부른다.
  두 조건이 서로 다른 시간축을 덮는다 — 원장 단독이면 세션마다 한 번씩 다시 리뷰되고,
  git 단독이면 커밋 전 fix 루프에서 계속 재arm 된다.
- **원장 기록의 주체가 "완료된 리뷰" 로 확정됐다.** validator·Stop·skill 진입은 쓰지
  않는다. 그 셋 중 어디에 써도 "리뷰를 받지 않았는데 표시된" 창이 생기고, 삭제된
  락이 TTL 로 얻던 자기치유를 잃는다. verdict 시점 기록은 TTL 을 새로 만들지 않고
  같은 자기치유를 얻는다 — **표시되지 않은 문서는 다음 arming 편집에서 다시 dispatch 되기 때문**.
- **리뷰 진행 중 오발 방지가 락에서 pending strip 으로 바뀌었다.** dispatch 의 연료는
  `pending_review` 이므로 `reviewing-spec` 진입 시 연료를 없애면 락이 필요 없다.
  하나의 불변식에 두 표현을 두면 두 표현이 어긋나는 순간이 곧 버그다.
- **PostToolUse arm-skip advisory 가 사유를 세 가지로 구분**한다 — 세션 내 리뷰 완료 /
  git 이 아는 문서 / G6 상한 도달. 앞의 둘과 셋째는 사용자가 취해야 할 행동이 다르다.

### Added
- **G6 재시도 상한 (세션당·문서당 3회).** verdict 없이 끝난 dispatch 의 재시도는
  의도된 동작이지만 무한하면 Forbidden Pattern(*Unbounded autonomy*)이다.
  `dispatch_attempts` 가 3 에 닿는 dispatch 가 마지막이고, 그 emit 이 상한을 알린다.
  경계가 세션당인 이유: 그 상태는 세션 스코프이고, 문서 생애 상한으로 만들려면
  세션 밖에 살아남는 저장소가 필요한데 그것은 NG4 가 배제한다. 세션을 넘겨도 멈추게
  하는 진짜 수단은 문서를 커밋하는 것이고 approve 시점 `check-born` advisory 가 그것을 촉구한다.
- 회귀 락 T1–T12 (`tests/test_arm_once.sh`, `tests/test_arm_ledger_timing.sh`) —
  전부 mutation 으로 이빨을 증명했다. T7·T8 은 서로 반대 방향이라 함께 있어야 이빨이
  생기고, T10 은 `arm_ledger` CLI 의미가 아니라 **Stop 훅의 원장 무-기록**을 잰다.

### Removed
- `scripts/review_lock.py`(240) · `scripts/cancel_review.py`(99) ·
  `scripts/approve_handoff.sh`(98) · `scripts/suppress_state.py`(242) — 합계 679 줄이
  사라지고 `scripts/arm_ledger.py` 한 파일이 그 자리를 대신한다. **커밋 시점의 실제
  줄 수를 세어 이 문장을 채운다** — 어림수를 적지 말 것.
- `/spec-distill:cancel-review` 커맨드. 네 용도 중 (a) approve 후 재arm 억제와
  (b) 고착 pending 정리는 **대상이 소멸**했고, (c) 미리 옵트아웃은 **인정된 손실**이며
  (남는 비용은 미커밋인 채 넘긴 세션당 dispatch 1회, `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`
  로 0 이 된다), (d) `harness_sid` 미해석 시 수동 억제는 대체 안내로 지정했다
  (그 지시는 원래도 부정확했다 — sid 가 없으면 그 커맨드도 상태를 못 썼다).
- 환경변수 `DEVBREW_SPEC_DISTILL_REVIEW_LOCK_TTL_SEC` (락 소멸).
- 전용 테스트 7종. 두 handoff 테스트가 잠그던 dangling-경로 무-abort 불변식은 T11 이 승계.

### Fixed
- `tests/test_stale_terms.sh` 의 production 파일 필터가 앵커 없는 `*/.claude/*` 라,
  하니스 워크트리(`<repo>/.claude/worktrees/`) 안에서 production 47 개를 전부 삼켰다.
  락은 empty-guard 로 FAIL 했지만(fail-closed 설계가 제 역할을 했다) **워크트리에서는
  실행 자체가 불가능**했다. `$SD` 기준으로 앵커했다.
```

- [ ] **Step 5: README 에 v0.25.0 서술 추가**

버전 히스토리 블록 끝(v0.24.0 다음)에:

```markdown
**v0.25.0**: design doc auto-review 를 **arm-once** 로 — 문서가 처음 생길 때 한 번만 발동한다. arm 조건은 `(세션 원장에 없음) AND (git 이 모르는 문서)` 이고 판정은 `scripts/arm_ledger.py` 한 곳에만 있다. 원장(`armed_paths`)에 쓰는 주체는 **verdict 가 나온 리뷰 자신**이며, verdict 없이 끝난 재시도는 세션당·문서당 3회에서 멈춘다(G6). 재발동을 막으려 쌓였던 방어층 4개는 원인과 함께 삭제됐다.
```

`## Kill switches` 절에 상한 안내를 한 줄 추가한다(신규 env 아님 — 기존 스위치의 재안내):

```markdown
- 자동 dispatch 가 G6 상한(3회)에 닿으면 그 문서는 이 세션에서 더 이상 자동으로 리뷰되지 않는다. 리뷰가 필요하면 `reviewing-spec` skill 을 직접 호출한다. 초안을 오래 다듬는 동안 dispatch 를 0 으로 두고 싶으면 `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1`.
```

`### Anti-pattern 회피` 절의 AP16 항목에 상한을 추가한다:

```markdown
- **AP16 (Unbounded autonomy)** — re-review max 5 (hybrid policy, v0.3.0: hard cap + stagnation early-exit), rhythm guard 3, **자동 dispatch 재시도 상한 3 (v0.25.0, 세션당·문서당)**, kill switch.
```

- [ ] **Step 6: `test_readme_sync.sh` 버전·CHANGELOG assert 갱신**

```bash
grep -qE '"version": "0\.25\.[0-9]+"' "$PLUGIN_JSON" \
  && note PASS "T20: plugin.json version 0.25.x" \
  || note FAIL "T20: plugin.json이 0.25.x가 아님"
```

그리고 append-only 누산에 한 줄 **추가**한다(기존 pin 은 절대 빼지 않는다 — 빼는 순간 그 히스토리 엔트리가 삭제돼도 스위트가 조용히 통과한다):

```bash
grep -qE '^## \[0\.25\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "CHANGELOG append-only: [0.25.0] 엔트리 보존" \
  || note FAIL "CHANGELOG append-only: [0.25.0] 엔트리가 없다"
```

- [ ] **Step 7: 전 스위트 최종 실행 — 종료 조건 확인**

```bash
red=0
for t in tests/test_*.sh; do
  bash "$t" >/dev/null 2>&1 || { echo "RED: $t"; red=$((red+1)); }
done
echo "bash: $(ls tests/test_*.sh | wc -l)종, red=$red"
python3 -m unittest discover -s tests -p 'test_*.py' 2>&1 | tail -4
git grep -nIF -e review_lock -e suppress_state -e approve_handoff -e cancel_review \
  -- 'plugins/spec-distill' ':!plugins/spec-distill/CHANGELOG.md' ':!plugins/spec-distill/tests' | wc -l
```

Expected:
- `bash: 48종, red=0`
- python: 9 파일, 알려진 cross-resolver 1건 외 OK (베이스라인과 동일)
- `git grep` 카운트 `0`

- [ ] **Step 8: 커밋**

```bash
git add -A plugins/spec-distill
git commit -m "$(cat <<'EOF'
chore(spec-distill): v0.25.0 — arm-once 스윕 락 + 문서 동기화

T4(개념 별칭 8종 production 잔존 0) · T5(삭제 파일 12종 부재) ·
V11(대체 surface 실재 — 음의 락만 두면 전부 지워도 통과하므로 짝을 지었다).

mutation: 옛 용어 되살리기 → T4 RED / 삭제 파일 touch → T5 RED /
should_arm 호출 제거 → V11 RED. 셋 다 확인.

plugin.json 0.25.0, CHANGELOG [0.25.0], README arm-once 서술,
readme-sync 버전 assert + append-only pin 누산.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 수동 검증 (자동화 밖 — 구현 완료 후 실행)

전 태스크가 끝난 뒤 **실제 세션에서** 확인한다. 자동 락은 훅과 CLI 를 직접 부르지만, 아래는 Claude Code 런타임이 실제로 훅 payload 를 어떻게 넘기는지에 의존한다.

- [ ] **V1**. 새 design doc 을 Write → 리뷰가 **1회** 발동한다.
- [ ] **V2**. 그 리뷰의 fix 루프에서 문서를 수정 → **재발동 없음**. 재리뷰는 `reviewing-spec` 의 결정론 라우팅 표가 돌린다(훅이 강제하지 않는다 — D3 의 대가).
- [ ] **V3**. 문서를 커밋한 뒤 편집 → 리뷰 없음. **Layer 1 은 여전히 동작**(placeholder 를 넣으면 `exit 2` 로 차단되는지 확인 — G2 가 깨지면 이 설계 전체가 무효다).
- [ ] **V4**. 새 세션에서 **커밋된** 문서 편집 → 리뷰 없음.
- [ ] **V5**. V4 의 대칭 — approve 했지만 **커밋하지 않은** 문서를 새 세션에서 편집 → 리뷰가 **한 번 더** 발동한다(G1 의 조건부성이 실제로 그렇게 동작함을 확인). 아울러 approve 시점에 `check-born` advisory 가 실제로 떴는지 확인 — 그 advisory 가 V5 상황을 사용자에게 미리 알리는 유일한 신호다.

## Self-Review

**1. Spec coverage** — §별로 담당 태스크를 짚었다.

| spec | 담당 |
|---|---|
| G1 (완료된 리뷰 = dispatch 0회) | Task 3·4·6, T1·T7 |
| G2 (Layer 1 불변) | Task 3 Case 13, V3 |
| G3 (삭제) | Task 9, T5 |
| G4 (판정 한 파일) | Task 2, V11 |
| G5 (신규 env·커맨드·훅 없음) | Task 9·10 (순감소만) |
| G6 (재시도 상한) | Task 4, T9 |
| NG1·NG2 (재리뷰 경로·휴리스틱 없음) | 어떤 태스크도 만들지 않음 |
| NG3 (brief 파이프라인 무접촉) | 어떤 태스크도 `reviewing-brief`·`check_brief.py`·brief 리뷰어를 건드리지 않는다 |
| NG4 (마이그레이션 없음) | 옛 키는 읽는 사람이 없어져 무시된다 |
| NG5-(d) (대체 안내) | Task 6 Step 3 |
| §5.1 판정 | Task 2 |
| §5.2 기록 시점 + 상태기계 | Task 2·4, T7·T8·T9·T10 |
| §5.3 스키마 | Task 2 `_compose` |
| §5.4 진입 strip | Task 2·6, T6 |
| §6 컴포넌트 3종 CLI | Task 2·6, T11·T12 |
| §7 제거 목록 | Task 9 |
| §8 degradation | Task 2 (`is_born`·`_read_body`), T3 |
| §9 Files to Modify | Task 1·3·4·5·6·9·10 |
| §10 F0 + T1–T12 | Task 1·7·8·10 |
| §12 구현 순서 | Task 1→10 (편차 2건 명시) |

**2. Placeholder scan** — 각 스텝에 실행 가능한 명령·완전한 코드가 들어 있다. "적절히 처리"·"비슷하게"·"TBD" 없음. 유일하게 열린 판단은 Task 3 Step 2 의 각주(`write_state` 의 import 가 모킹 아래 실패할 경우의 degrade)이며, 그 경우 무엇을 해야 하는지까지 적었다.

**3. Type consistency** — Task 2 가 선언한 이름이 뒤 태스크에서 그대로 쓰이는지 대조했다: `should_arm`/`skip_reason`/`canonical_key`/`state_file_for`(Task 3), `next_attempt`/`record_attempt`/`mark_armed`/`DISPATCH_ATTEMPT_CAP`(Task 4), CLI `strip-pending`/`mark-reviewed`/`check-born`(Task 6·7·8), `strip_pending`(Task 3 `write_state`). `rewrite_state` 는 Task 4 에서 시그니처가 5-인자로 바뀌고 호출부도 같은 스텝에서 갱신된다.

**남은 위험 2건 (구현 중 확인할 것)**

- **`skip_reason` 의 `capped` 판정은 `mark-reviewed` 가 `dispatch_attempts` 항목을 지운다는 데 전적으로 의존한다.** 그 삭제가 빠지면 정상 완료가 `capped` 로 잘못 표시된다 — Task 2 의 `test_mark_reviewed_arms_and_clears_attempts` 와 Task 3 의 Case 12b 가 양쪽에서 잠근다.
- **`test_spec_write_validator.sh` 의 `WORK` 는 git 리포가 아니다.** `is_born` 이 exit 128 로 loud stderr 를 뿜으므로 stderr 를 grep 하는 기존 케이스(Case 2 등)가 영향을 받는지 Task 3 Step 6 에서 확인한다. 영향이 있으면 그 케이스의 grep 을 더 좁히되(`missing sections:` 는 이미 충분히 좁다) **loud 를 끄지는 않는다** — §8 이 요구하는 관측성이다.
