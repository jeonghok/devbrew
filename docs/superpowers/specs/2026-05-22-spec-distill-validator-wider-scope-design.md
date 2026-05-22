---
name: spec-distill-validator-wider-scope
version: 1.2.0
created_at: 2026-05-22
session_id: brainstorm-2026-05-22
status: locked
next_phase: writing-plans
source: superpowers/brainstorming + 사용자 결정 (docs/superpowers/specs/ 아래 모든 .md 게이트; content-aware mode via locked_decisions) + spec-review round 1 (6-issue 반영)
---

# spec-distill — spec-write-validator 범위 확대: 모든 .md 게이트 + content-aware mode (v0.8.0)

> **For agentic workers:** 이 문서는 `plugins/spec-distill/hooks/spec-write-validator.py`의 `resolve_mode()`를 확대하는 v0.8.0 변경 명세이다. 현재는 `docs/superpowers/specs/` 아래 `-spec.md`/`-design.md` **suffix**만 review 게이트에 들어오고 나머지 `.md`는 누락된다. 본 변경은 그 디렉토리의 **모든 `.md`**를 게이트에 넣되, mode는 suffix가 아니라 **frontmatter 블록 안의 `locked_decisions` 키 유무**로 판별한다 — spec(drafting-spec 산출물)은 `locked_decisions`를 갖고(template line 12) brainstorming design.md는 없다. 핵심 안전장치: content-peek은 **첫 `---`…`---` frontmatter 블록만** 파싱한다 (body에 `locked_decisions`를 언급하는 design 문서의 오분류 방지 — 이 spec 자신이 그런 문서다). reviewing-spec routing은 기존 spec/design 두 mode를 그대로 재사용하므로 변경하지 않는다. 강제력은 advisory가 아니라 Stop 훅 `decision:"block"`의 결정론적 강제다. 구현은 PR #65(v0.7.0) 머지 후 main을 merge로 흡수한 뒤 진행한다. 다음 단계는 superpowers `writing-plans`.

## 목차

- §1 [Goal](#goal)
- §2 [Context / Why](#context--why)
- §3 [Goals](#goals)
- §4 [Non-goals](#non-goals)
- §5 [Constraints](#constraints)
- §6 [Acceptance Criteria](#acceptance-criteria)
- §7 [Files to Modify](#files-to-modify)
- §8 [Verification Plan](#verification-plan)
- §9 [Rejected Alternatives](#rejected-alternatives)
- §10 [Metadata](#metadata)

## Goal

`resolve_mode()`가 `docs/superpowers/specs/` 아래 **모든 `.md`**에 대해 non-None mode를 반환하고, suffix 없는 `.md`의 mode를 **frontmatter 블록 안** `locked_decisions` 키 유무로 판별하도록 확대한다. 기존 검사 로직·reviewing-spec routing은 불변.

## Context / Why

현재 `resolve_mode()` (spec-write-validator.py:50–60):

```python
PATH_PREFIX = "docs/superpowers/specs/"
def resolve_mode(file_path):
    if PATH_PREFIX not in file_path: return None
    if file_path.endswith("-spec.md"):   return "spec"
    if file_path.endswith("-design.md"): return "design"   # DESIGN_MODE_DISABLE 존중
    return None   # ← 그 외 모든 .md 누락 (review 강제 구멍)
```

문제: `docs/superpowers/specs/`에 `-spec.md`/`-design.md` 네이밍을 따르지 않는 `.md`(예: 잘못 명명된 spec, `2026-05-22-foo.md`)를 쓰면 spec-write-validator가 침묵 → `pending_review` 미기록 → Stop 훅이 review를 강제하지 않음. review 강제(Law 2)가 파일명 컨벤션에 의존하는 취약점이다.

사용자 결정 (본 세션):
1. **그 디렉토리의 모든 `.md`가 게이트 대상** — `docs/superpowers/specs/`는 spec 전용 디렉토리이므로 어떤 `.md`든 review 강제가 맞다 (의도된 함의: stray note.md도 게이트).
2. **mode는 내용으로 가변(content-aware)** — suffix 없는 `.md`는 spec 구조 여부로 결정. 신호는 **frontmatter 블록 안** `locked_decisions` 키 유무: spec.md는 보유(template line 12), design.md는 미보유. 이로써 (a) suffix 없는 진짜 spec도 full 검증, (b) 느슨한 `.md`는 design mode 경량 검사로 과도 block 회피, (c) "spec은 locked_decisions를 갖는다"는 기존 plugin 의미와 일치.

이는 이번 세션의 연장선이다: interview-trigger 제거(PR #65)가 *advisory(모델이 무시 가능)* 훅을 걷어냈다면, 본 변경은 *deterministic(Stop block)* review 강제의 적용 범위를 넓힌다 — 같은 원칙("훅의 가치는 review 강제")의 양면.

## Goals

- `resolve_mode()` 확대:
  - `*-spec.md` → `spec` (불변)
  - `*-design.md` → `design` (불변, `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE` 존중)
  - **그 외 prefix 아래 `.md`** → frontmatter 블록에 `locked_decisions` 키 있으면 `spec`, 없으면 `design`
  - `.md` 아님 / prefix 밖 → `None` (불변)
- **content-peek 헬퍼 (inline, subprocess 아님):** 파일을 읽어 **첫 `---`…`---` frontmatter 블록만** 추출하고 그 블록 안에서 `locked_decisions` 키를 탐지. body의 `locked_decisions` 언급은 무시. frontmatter 블록 부재 → `design`. 읽기/디코드 실패(권한·바이너리/UnicodeDecodeError·레이스 부재) → `design` + stderr 1줄(`[spec-distill]` prefix + 파일 경로 + 오류). crash/block 금지.
- 모듈 docstring(filter 설명) + README "Hooks Installed" PostToolUse 행 + CHANGELOG v0.8.0 + plugin.json `0.8.0` 갱신.
- 신규 테스트가 content-aware 판별을 커버 (#65의 `test_hook_output_schema.py` 변경과 충돌 회피 위해 **별도 테스트 파일**).

## Non-goals

- **reviewing-spec skill / routing table 변경 안 함** — 신규 mode 없이 기존 `spec`/`design` 재사용. (검증: `reviewing-spec/SKILL.md` diff 0)
- **spec-mode / design-mode 검사 로직 자체 불변** — 11-section/frontmatter/locked_decisions/ambiguity(spec), ambiguity/placeholder(design) 그대로.
- **`PATH_PREFIX`(`docs/superpowers/specs/`) 값 변경 안 함** — 다른 디렉토리로 확장 안 함.
- **`PATH_PREFIX` 매칭 방식(substring `in`) 개선 안 함** — 기존 동작 유지(trailing slash가 `specs-archive/` 류 오탐을 자연 배제). prefix-anchored 매칭 강화는 별도 범위; content-peek은 기존 substring 매칭을 통과한 경로에서만 추가 실행됨.
- **`.md` 이외 확장자 안 봄** (`.markdown` 등 제외).
- **review 강제 체인의 다른 hook(review-dispatch / pending-review-reminder) 불변.**
- **state.local.md 스키마 불변** — `pending_review.mode`는 여전히 `spec`|`design` 두 값.

## Constraints

- **PR #65(v0.7.0) 선머지 의존.** 본 변경은 `0.7.0` → `0.8.0`. 구현 브랜치는 #65 머지 후 `main`을 **merge**(rebase 아님)로 흡수한 뒤 작업. spec-write-validator.py는 #65가 안 건드리므로 코드 충돌 없음; `plugin.json`/`CHANGELOG.md`는 머지 시 정렬.
- **content peek 비용 최소** — frontmatter 블록만 파싱하고, 임의 `.md`에만 적용(suffix 매칭 파일은 I/O 없이 즉시 분기). PostToolUse는 write 이후 fire하므로 통상 파일 존재.
- **graceful degradation** — 읽기/디코드 실패 시 `(OSError, UnicodeDecodeError)` catch → `design` fallback + `print(..., file=sys.stderr)`로 1줄(`[spec-distill]` prefix + 경로 + 오류). call-time stderr 출력이므로 테스트의 `redirect_stderr` 및 subprocess `2>` 캡처 양쪽에서 검증 가능(구현 의존성 없음). content-peek은 frontmatter 블록만 파싱(전체 본문 스캔 아님 → body 오탐 방지). (P14, devbrew "loud logging")
- `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` → `design`으로 분류된 모든 `.md`(임의 포함) 게이트 해제; `locked_decisions`로 `spec` 분류된 `.md`는 영향 없음.
- 0.x minor bump; Korean-primary; 기존 킬스위치 5종 불변(신규 env var 없음).

## Acceptance Criteria

- **AC1** — prefix 아래 `*-spec.md` → `resolve_mode` == `"spec"` (불변).
- **AC2** — prefix 아래 `*-design.md` → `"design"`; `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`이면 `None` (불변 — 회귀 테스트 필수).
- **AC3** — prefix 아래 임의 `.md`(suffix 미해당)의 **frontmatter 블록(첫 `---`…`---`) 안에** `locked_decisions:` 키 존재 → `"spec"`.
- **AC4** — prefix 아래 임의 `.md`의 frontmatter 블록에 `locked_decisions` 부재(또는 frontmatter 블록 없음, 또는 **닫는 `---`가 없는 unclosed frontmatter**, **또는 `locked_decisions`가 body에만 등장**) → `"design"`. 불완전/누락 frontmatter는 spec으로 분류하지 않는다(안전한 fallback — 닫는 `---` 누락은 사용자 책임).
- **AC5** — prefix 밖의 `.md` → `None`; prefix 아래 `.md` 아닌 파일(`.txt`/`.markdown`) → `None`.
- **AC6** — 임의 `.md` 읽기/디코드 실패(권한 거부, 바이너리/UnicodeDecodeError) → `"design"` 반환 + stderr 1줄(`[spec-distill]` prefix + 파일 경로 + 오류 메시지 포함). 헬퍼는 `(OSError, UnicodeDecodeError)`를 광범위 catch하므로 그 외 I/O 예외(`FileNotFoundError` 등)도 전파 없이 `design`으로 흡수. 예외 전파/하드 실패 없음.
- **AC7** — `DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1`일 때: `locked_decisions` 없는 임의 `.md` → `None`(design 게이트 해제); `locked_decisions` 있는 임의 `.md` → `"spec"` 유지.
- **AC8** — 모듈 docstring filter 설명 + README PostToolUse 행이 "prefix 아래 모든 `.md`, content-aware mode(frontmatter `locked_decisions`)"를 반영. `plugin.json` `version=="0.8.0"`. `CHANGELOG.md`에 `## [0.8.0] — YYYY-MM-DD`(구현일) Changed 항목.
- **AC9** — 신규 테스트 `tests/test_resolve_mode_scope.sh`(bash 래퍼가 python assertion 실행 — removal verification 스타일)가 AC2 회귀 + AC3 + AC4(body-only + unclosed frontmatter 케이스 포함) + AC5(.txt/.markdown) + AC6(binary + stderr 검증) + AC7을 커버하고, `plugins/spec-distill/tests/` 전체 suite green.
- **AC10** — `skills/reviewing-spec/SKILL.md` 및 routing 변경 0 (git diff로 확인) — content-aware 판별이 기존 두 mode만 산출함을 보증.

## Files to Modify

| 파일 | 변경 | AC |
|---|---|---|
| `plugins/spec-distill/hooks/spec-write-validator.py` | `resolve_mode()` 확대 + inline frontmatter-블록 content-peek 헬퍼 + 모듈 docstring filter 설명(line 5–6) | AC1–AC7, AC8 |
| `plugins/spec-distill/README.md` | "Hooks Installed" PostToolUse 행: "spec/design 파일" → "prefix 아래 모든 `.md`(content-aware: frontmatter `locked_decisions`로 spec/design)" | AC8 |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `version` `0.7.0` → `0.8.0` | AC8 |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.8.0] — YYYY-MM-DD`(구현일) Changed 항목 | AC8 |
| `plugins/spec-distill/tests/test_resolve_mode_scope.sh` (신규) | bash 래퍼 + python assertion으로 `resolve_mode` 단위 테스트: AC2 회귀 + AC3/AC4(body-only 포함)/AC5/AC6(binary+stderr)/AC7 (#65 test 파일과 분리) | AC9 |

## Verification Plan

```bash
# resolve_mode를 직접 import해 검증 (frontmatter-블록 content-peek 포함).
# 신규 test_resolve_mode_scope.sh가 아래 python을 heredoc으로 감싸 실행한다.
python3 - <<'PY'
import sys, tempfile, os, io, contextlib
from pathlib import Path
import importlib.util
spec = importlib.util.spec_from_file_location("v", "plugins/spec-distill/hooks/spec-write-validator.py")
v = importlib.util.module_from_spec(spec); spec.loader.exec_module(v)

base = Path(tempfile.mkdtemp()) / "docs" / "superpowers" / "specs"
base.mkdir(parents=True)
def mk(name, body=""):
    p = base / name; p.write_text(body, encoding="utf-8"); return str(p)

# AC1/AC2
assert v.resolve_mode(mk("x-spec.md")) == "spec"
assert v.resolve_mode(mk("x-design.md")) == "design"
# AC3 — 임의 .md, frontmatter에 locked_decisions → spec
assert v.resolve_mode(mk("foo.md", "---\nname: t\nlocked_decisions: []\n---\n")) == "spec"
# AC4 — frontmatter에 locked_decisions 없음 → design
assert v.resolve_mode(mk("bar.md", "---\nname: t\n---\n")) == "design"
# AC4 (body-only) — frontmatter 블록 밖 body에만 locked_decisions → design (오탐 방지)
assert v.resolve_mode(mk("bodyonly.md", "---\nname: t\n---\n\n## sec\nlocked_decisions: []\n")) == "design"
# AC4 (unclosed) — 닫는 --- 없는 frontmatter + locked_decisions → design (안전 fallback)
assert v.resolve_mode(mk("unclosed.md", "---\nname: t\nlocked_decisions: []\n")) == "design"
# AC5 — prefix 아래 .md 아님(.txt/.markdown) → None ; prefix 밖 → None
assert v.resolve_mode(mk("baz.txt")) is None
assert v.resolve_mode(mk("q.markdown")) is None
assert v.resolve_mode("/elsewhere/foo.md") is None
# AC6 — 디코드 실패(바이너리) → design + stderr loud 로그
binp = base / "bin.md"; binp.write_bytes(b"\xff\xfe\x00\x01 not utf8")
err = io.StringIO()
with contextlib.redirect_stderr(err):
    assert v.resolve_mode(str(binp)) == "design"
assert "[spec-distill]" in err.getvalue() and "bin.md" in err.getvalue()
# AC7 + AC2 회귀 — DESIGN_MODE_DISABLE
os.environ["DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"] = "1"
assert v.resolve_mode(mk("z-design.md")) is None                                  # AC2 회귀
assert v.resolve_mode(mk("nolocked.md", "---\nname: t\n---\n")) is None           # 임의 .md design → 해제
assert v.resolve_mode(mk("locked.md", "---\nlocked_decisions: []\n---\n")) == "spec"  # spec은 유지
del os.environ["DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE"]
print("resolve_mode AC1–AC7 ok")
PY

# AC8
test "$(jq -r .version plugins/spec-distill/.claude-plugin/plugin.json)" = "0.8.0" && echo "AC8 version ok"
grep -q "## \[0.8.0\]" plugins/spec-distill/CHANGELOG.md && echo "AC8 changelog ok"
grep -q "locked_decisions" plugins/spec-distill/README.md && echo "AC8 README ok"
grep -qi "locked_decisions\|content-aware" plugins/spec-distill/hooks/spec-write-validator.py && echo "AC8 docstring/code ok"
# AC9
for t in plugins/spec-distill/tests/*.sh; do bash "$t" >/dev/null || echo "FAIL $t"; done; echo "AC9 suite checked"
# AC10
git diff --quiet -- plugins/spec-distill/skills/reviewing-spec/SKILL.md && echo "AC10 reviewing-spec unchanged"
```

## Rejected Alternatives

- **임의 `.md` → 무조건 `design`** (초기 제안). 거절: suffix 없는 *진짜* spec(locked_decisions 보유)이 full 검증을 못 받음. content-aware가 더 정확. (사용자 피드백 "가변적")
- **임의 `.md` → 무조건 `spec`.** 거절: 느슨한 `.md`(note 등)가 11-section 미충족으로 과도 block.
- **신규 `doc` mode 신설.** 거절: reviewing-spec routing/SKILL.md 추가 변경 필요 → devbrew lightness 위반 + AC10 깨짐. 기존 두 mode 재사용이 최소 변경.
- **판별 신호 = frontmatter `name` 유무.** 거절: design.md도 `name`을 가지므로 spec/design 구분 불가.
- **content peek을 naive multiline regex(`^locked_decisions:` 전체 본문)로.** 거절: body에 `locked_decisions`를 *언급*하는 design 문서(이 spec 자신 포함)를 spec으로 오분류. → **frontmatter 블록(첫 `---`…`---`) 한정 파싱으로 확정** (issue b9e4f7a).
- **content peek을 `call_parser("frontmatter")` subprocess로.** 거절: (1) `resolve_mode`마다 python3 subprocess 비용, (2) frontmatter-only 스코프를 inline으로 보장하는 편이 단순. **inline frontmatter-블록 파싱으로 확정**; call_parser 재사용 안 함.
- **`PATH_PREFIX`를 prefix-anchored로 강화 / 다른 디렉토리로 확장.** 거절: 본 변경 scope 밖 (Non-goals).

## Metadata

- **Plugin:** `spec-distill` `0.7.0` → `0.8.0` (minor; review-gate scope 확대 — PR #65 선행 의존).
- **Principles instantiated:** Law 2(review 강제 L1 게이트를 파일명 컨벤션 의존에서 디렉토리-전체로 확대), Law 1(보안-민감 게이트 변경이라 spec 우선), devbrew "design lightness"(기존 mode 재사용, 신규 surface 0).
- **보안 검토:** review-enforcement 게이트의 *확대*다. 게이트를 넓히는 방향(약화 아님)이라 under-enforcement(누락 spec) 위험을 줄인다. over-enforcement(엉뚱한 .md 게이트) 위험은 design-mode 경량 검사 + `DESIGN_MODE_DISABLE` 킬스위치로 완화. persona/게이트 편집 수준의 신중함 적용.
- **Cross-plugin 의존:** 없음.
- **선행 의존:** PR #65 (`feature/spec-distill-remove-interview-trigger`, v0.7.0) 머지.
- **Review:** round 1 needs_revise 6-issue 반영 — a3f2c1d(AC6 정정), b9e4f7a(frontmatter-블록 한정 탐지 — body 오탐 방지, 핵심), c5d3e8b(PATH_PREFIX substring Non-goal), d1a6b2c(.sh 래퍼 형식 + AC2 회귀), e7f9c4d(stderr 형식+capture), f2b8e5a(call_parser 거절). round 2 needs_revise 5-issue 반영 — b9e4f7a 재등장(unclosed frontmatter → design 명시+테스트), NEW-1(stderr `print(file=sys.stderr)` call-time 명시 → 구현 비의존 검증), NEW-2(AC6 race 케이스 제거, `(OSError,UnicodeDecodeError)` 광범위 catch), NEW-3(.markdown 케이스 추가로 .md 게이트 명확화), NEW-4(AC8 README/docstring grep 추가). 양 round Stagnation_signal: false (추세: 설계→검증정밀도, diminishing returns).
- **다음 단계:** superpowers `writing-plans`.
