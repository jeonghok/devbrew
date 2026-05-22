# spec-write-validator 범위 확대 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** `resolve_mode()`가 `docs/superpowers/specs/` 아래 모든 `.md`를 review 게이트에 넣되, suffix 없는 `.md`는 frontmatter 블록의 `locked_decisions` 키 유무로 spec/design을 판별하도록 확대 (v0.8.0).

**Architecture:** `spec-write-validator.py`의 `resolve_mode()` 한 함수 + inline frontmatter-블록 content-peek 헬퍼 추가. 검사 로직·reviewing-spec routing 불변. TDD(테스트 먼저). 근거 spec: `docs/superpowers/specs/2026-05-22-spec-distill-validator-wider-scope-design.md`.

**Tech Stack:** python3 stdlib(`re`, `pathlib`), bash, jq, git.

**선행 의존:** PR #65(`feature/spec-distill-remove-interview-trigger`, v0.7.0)가 **먼저 머지**돼야 한다. 본 브랜치 `feature/spec-distill-validator-wider-scope`는 main에서 분기됐고 아직 #65의 0.7.0 bump가 없다 — Task 0에서 main을 흡수한다.

---

## File Structure

| 파일 | 작업 | 책임 |
|---|---|---|
| `plugins/spec-distill/hooks/spec-write-validator.py` | 수정 | `resolve_mode()` + `_frontmatter_has_locked_decisions()` + 모듈 docstring |
| `plugins/spec-distill/tests/test_resolve_mode_scope.sh` | 생성 | resolve_mode 단위 테스트(AC2 회귀 + AC3–AC7) |
| `plugins/spec-distill/README.md` | 수정 | Hooks Installed PostToolUse 행 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 수정 | version 0.7.0 → 0.8.0 |
| `plugins/spec-distill/CHANGELOG.md` | 수정 | v0.8.0 Changed |

---

## Task 0: main 흡수 (#65 머지 후 실행)

**Files:** 없음 (git 동기화)

- [ ] **Step 1: #65 머지 확인 후 main 흡수 (merge, rebase 아님)**

```bash
git checkout main && git pull
git checkout feature/spec-distill-validator-wider-scope
git merge main   # #65의 v0.7.0 흡수; spec-write-validator.py는 #65 미변경이라 충돌 없음
```

- [ ] **Step 2: 0.7.0 baseline 확인**

```bash
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.7.0" && echo "baseline 0.7.0 ok"
grep -q "## \[0.7.0\]" plugins/spec-distill/CHANGELOG.md && echo "changelog 0.7.0 present"
```

Expected: `baseline 0.7.0 ok` / `changelog 0.7.0 present`. 아니면 #65 미머지 — 중단하고 사용자에게 알림.

---

## Task 1: resolve_mode 확대 (TDD)

**Files:**
- Create: `plugins/spec-distill/tests/test_resolve_mode_scope.sh`
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py`

- [ ] **Step 1: 실패하는 테스트 작성**

`plugins/spec-distill/tests/test_resolve_mode_scope.sh` 생성:

```bash
#!/usr/bin/env bash
# resolve_mode() scope 확대 단위 테스트 (AC2 회귀 + AC3–AC7).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
python3 - <<'PY'
import sys, tempfile, os, io, contextlib
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location(
    "v", "plugins/spec-distill/hooks/spec-write-validator.py")
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)

base = Path(tempfile.mkdtemp()) / "docs" / "superpowers" / "specs"
base.mkdir(parents=True)
def mk(name, body=""):
    p = base / name; p.write_text(body, encoding="utf-8"); return str(p)

# AC1/AC2
assert v.resolve_mode(mk("x-spec.md")) == "spec"
assert v.resolve_mode(mk("x-design.md")) == "design"
# AC3 — frontmatter에 locked_decisions → spec
assert v.resolve_mode(mk("foo.md", "---\nname: t\nlocked_decisions: []\n---\n")) == "spec"
# AC4 — frontmatter에 locked_decisions 없음 → design
assert v.resolve_mode(mk("bar.md", "---\nname: t\n---\n")) == "design"
# AC4 (body-only) — body에만 → design
assert v.resolve_mode(mk("bodyonly.md", "---\nname: t\n---\n\n## s\nlocked_decisions: []\n")) == "design"
# AC4 (unclosed) — 닫는 --- 없음 → design (locked_decisions 있어도)
assert v.resolve_mode(mk("unclosed.md", "---\nname: t\nlocked_decisions: []\n")) == "design"
# AC5 — prefix 아래 .md 아님 → None ; prefix 밖 → None
assert v.resolve_mode(mk("baz.txt")) is None
assert v.resolve_mode(mk("q.markdown")) is None
assert v.resolve_mode("/elsewhere/foo.md") is None
# AC6 — 디코드 실패(바이너리) → design + stderr loud
binp = base / "bin.md"; binp.write_bytes(b"\xff\xfe\x00\x01 not utf8")
err = io.StringIO()
with contextlib.redirect_stderr(err):
    assert v.resolve_mode(str(binp)) == "design"
assert "[spec-distill]" in err.getvalue() and "bin.md" in err.getvalue()
# AC7 + AC2 회귀 — DESIGN_MODE_DISABLE
os.environ["DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"] = "1"
assert v.resolve_mode(mk("z-design.md")) is None
assert v.resolve_mode(mk("nolocked.md", "---\nname: t\n---\n")) is None
assert v.resolve_mode(mk("locked.md", "---\nlocked_decisions: []\n---\n")) == "spec"
del os.environ["DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"]
print("test_resolve_mode_scope: ALL PASS")
PY
```

- [ ] **Step 2: 테스트 실패 확인**

Run: `bash plugins/spec-distill/tests/test_resolve_mode_scope.sh`
Expected: FAIL — 현재 `resolve_mode`는 임의 `.md`(`foo.md`)에 `None`을 반환하므로 AC3 assert에서 `AssertionError`.

- [ ] **Step 3: resolve_mode + content-peek 헬퍼 구현**

`spec-write-validator.py`의 기존 `resolve_mode()`(약 line 50–60)를 다음으로 교체. `import re`/`from pathlib import Path`/`import sys`는 이미 존재(상단 확인).

```python
def _frontmatter_has_locked_decisions(file_path: str) -> bool:
    """첫 ---...--- frontmatter 블록 안에 locked_decisions 키가 있으면 True.

    body의 locked_decisions 언급은 무시. 닫는 ---가 없는 unclosed frontmatter는
    유효 블록이 아니므로 False. 읽기/디코드 실패는 False + loud stderr (caller가
    design으로 매핑)."""
    try:
        text = Path(file_path).read_text(encoding="utf-8")
    except (OSError, UnicodeDecodeError) as exc:
        print(
            f"[spec-distill] resolve_mode content-peek failed for {file_path}: {exc}",
            file=sys.stderr,
        )
        return False
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        return False  # frontmatter 블록 없음
    block: list[str] = []
    closed = False
    for line in lines[1:]:
        if line.strip() == "---":
            closed = True
            break
        block.append(line)
    if not closed:
        return False  # unclosed frontmatter → spec marker로 인정 안 함
    return any(re.match(r"\s*locked_decisions\s*:", b) for b in block)


def resolve_mode(file_path: str) -> Optional[str]:
    """Return 'spec', 'design', or None (not in scope)."""
    if PATH_PREFIX not in file_path:
        return None
    if not file_path.endswith(".md"):
        return None
    if file_path.endswith("-spec.md"):
        return "spec"
    design_disabled = (
        os.environ.get("DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE") == "1"
    )
    if file_path.endswith("-design.md"):
        return None if design_disabled else "design"
    # suffix 없는 임의 .md — content-aware
    if _frontmatter_has_locked_decisions(file_path):
        return "spec"
    return None if design_disabled else "design"
```

- [ ] **Step 4: 테스트 통과 확인**

Run: `bash plugins/spec-distill/tests/test_resolve_mode_scope.sh`
Expected: `test_resolve_mode_scope: ALL PASS`

- [ ] **Step 5: 커밋**

```bash
chmod +x plugins/spec-distill/tests/test_resolve_mode_scope.sh
git add plugins/spec-distill/hooks/spec-write-validator.py plugins/spec-distill/tests/test_resolve_mode_scope.sh
git commit -m "feat(spec-distill): widen resolve_mode to all .md under specs/ (content-aware)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 문서 + 모듈 docstring + 버전 + CHANGELOG

**Files:**
- Modify: `plugins/spec-distill/hooks/spec-write-validator.py` (docstring)
- Modify: `plugins/spec-distill/README.md`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`

- [ ] **Step 1: 모듈 docstring filter 설명 갱신**

`spec-write-validator.py` 상단 docstring의 Filters 줄(약 line 5–6)을 교체:

```python
- Filters: tool must be Write/Edit/MultiEdit on a `.md` under docs/superpowers/specs/.
  Mode: `-spec.md` → spec; `-design.md` → design; other `.md` → spec if its
  frontmatter block has a `locked_decisions` key, else design.
  Out-of-scope paths exit 0 silently.
```

- [ ] **Step 2: README Hooks Installed PostToolUse 행 갱신**

`README.md`의 PostToolUse 행에서 "spec/design 파일 write 시"를 다음으로 교체:

```
`docs/superpowers/specs/` 아래 **모든 `.md`** write 시 (content-aware: frontmatter `locked_decisions` 유무로 spec/design mode)
```

- [ ] **Step 3: plugin.json 버전 bump**

`.claude-plugin/plugin.json`의 `"version": "0.7.0"` → `"version": "0.8.0"`.

- [ ] **Step 4: CHANGELOG v0.8.0 항목 추가**

`CHANGELOG.md` line 1 `# Changelog` 다음, `## [0.7.0]` 직전에 삽입 (날짜는 구현일):

```markdown
## [0.8.0] — YYYY-MM-DD

### Changed
- `hooks/spec-write-validator.py`:`resolve_mode()` — review 게이트 범위를 `docs/superpowers/specs/` 아래 **모든 `.md`**로 확대(기존: `-spec.md`/`-design.md` suffix만). suffix 없는 `.md`는 신규 `_frontmatter_has_locked_decisions()` inline 헬퍼로 mode 판별: 첫 `---`…`---` frontmatter 블록에 `locked_decisions` 키 있으면 `spec`, 없으면 `design`. body 언급·unclosed frontmatter·디코드 실패는 `design`(안전 fallback) + loud stderr. reviewing-spec routing·검사 로직·state 스키마 불변. review 강제(Law 2)가 파일명 컨벤션에 의존하던 취약점 제거.
```

- [ ] **Step 5: 검증 (AC8)**

```bash
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.8.0" && echo "AC8 version ok"
grep -q "## \[0.8.0\]" plugins/spec-distill/CHANGELOG.md && echo "AC8 changelog ok"
grep -q "locked_decisions" plugins/spec-distill/README.md && echo "AC8 README ok"
grep -qi "locked_decisions" plugins/spec-distill/hooks/spec-write-validator.py && echo "AC8 docstring/code ok"
```

Expected: 4줄 모두 ok.

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/hooks/spec-write-validator.py plugins/spec-distill/README.md \
        plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "docs(spec-distill): v0.8.0 — resolve_mode wider scope (docstring/README/CHANGELOG)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 전체 검증

**Files:** 없음

- [ ] **Step 1: AC10 — reviewing-spec 불변 확인**

```bash
git diff --quiet main -- plugins/spec-distill/skills/reviewing-spec/SKILL.md && echo "AC10 reviewing-spec unchanged"
```

Expected: `AC10 reviewing-spec unchanged`.

- [ ] **Step 2: 전체 test suite 회귀 0**

```bash
for t in plugins/spec-distill/tests/*.sh; do echo "--- $t ---"; bash "$t" >/dev/null && echo PASS || echo "FAIL: $t"; done
for t in plugins/spec-distill/tests/*.py; do echo "--- $t ---"; python3 "$t" >/dev/null 2>&1 && echo PASS || echo "FAIL: $t"; done
```

Expected: `FAIL:` 라인 0.

- [ ] **Step 3: PR 생성 (사용자 승인 후)**

```bash
git push -u origin feature/spec-distill-validator-wider-scope
gh pr create --base main --title "feat(spec-distill): widen spec-write-validator to all .md under specs/ (v0.8.0)" \
  --body "$(cat <<'EOF'
## Summary
`resolve_mode()`를 확대해 `docs/superpowers/specs/` 아래 **모든 `.md`**가 review 게이트(Law 2)에 들어오게 함. suffix 없는 `.md`는 frontmatter `locked_decisions` 유무로 content-aware하게 spec/design 판별. review 강제가 파일명 컨벤션에 의존하던 취약점 제거.

Spec: `docs/superpowers/specs/2026-05-22-spec-distill-validator-wider-scope-design.md` (2 round adversarial spec-review). 선행: #65(v0.7.0).

## Verification
- resolve_mode 단위 테스트(AC2 회귀 + AC3–AC7, edge: body-only/unclosed/binary/.markdown)
- 전체 suite 회귀 0; reviewing-spec 불변(AC10)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

---

## Self-Review (작성자 체크리스트)

- **Spec coverage:** AC1/AC2(T1 test+impl)·AC3/AC4 incl body-only·unclosed(T1)·AC5 .txt/.markdown(T1)·AC6 binary+stderr(T1)·AC7 DESIGN_MODE_DISABLE(T1)·AC8 docs/version(T2)·AC9 신규 테스트(T1)·AC10 reviewing-spec 불변(T3) — 10개 AC 전부 매핑.
- **Placeholder scan:** CHANGELOG 날짜 `YYYY-MM-DD`(구현일)는 표준 포맷 placeholder. 그 외 TODO/TBD 없음. 모든 코드 step에 완전한 코드 제시.
- **Type/identifier consistency:** `resolve_mode`, `_frontmatter_has_locked_decisions`, `PATH_PREFIX`, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE`, `locked_decisions` 전 task 일관. `.md` 확장자 체크가 suffix 분기보다 먼저(.markdown 오매칭 방지). unclosed frontmatter 처리(닫는 --- 선탐색 후 블록 내 키 검사)가 AC4와 일치.
