# 인터뷰 월클락 완전 제거 Implementation Plan — spec-distill v0.17.0

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 플러그인에서 인터뷰 월클락 메커니즘(`wall_clock_started_at` state 필드 + reviewing-spec wall-clock 체크 + `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env var + 모든 문서 참조)을 완전히 제거하고, 재도입 방지 회귀 락을 추가한다.

**Architecture:** 월클락은 cross-skill 메커니즘이다 — conducting-interview가 state에 timestamp를 심고 reviewing-spec가 검사한다. 제거는 순수 *삭제* 작업이다: state 필드 reader/writer, Step 2 체크(구 AC14), 양쪽 SKILL + README의 kill-switch 문서를 지운다. AP16(unbounded autonomy) 커버리지는 같은 re-review 루프에 이미 결정론적으로 걸린 두 바운드(hard cap 5 + stagnation early-exit)가 load-bearing 가드로 *불변* 유지한다. 구 세션 state의 잔여 `wall_clock_started_at` 키는 reader 부재로 무해하게 무시되므로 migration 코드는 불필요(forward-compatible).

**Tech Stack:** Markdown SKILL/README 문서, JSON plugin manifest, Bash 회귀-락 테스트(`grep`/`awk` 기반), 기존 python `unittest` + shell 테스트 스위트.

## Global Constraints

- **버전 bump (필수):** `plugins/spec-distill/.claude-plugin/plugin.json` version `0.16.0` → `0.17.0` (minor — pre-1.0.0 breaking = env-var 제거). 플러그인을 건드리는 모든 PR은 같은 커밋에서 version bump 필수.
- **CHANGELOG:** `## [0.17.0] — 2026-06-17` 엔트리 with `### Removed` (+ `### Added`/`### Changed`). spec-distill은 v0.x라 one-minor deprecation window 면제 → hard remove.
- **Korean-primary 문서.** 영어는 식별자(P#/AP#/Law N/플러그인명)/고유명사/원문 인용/번역 어색한 기술 용어(frontmatter, kill switch, env var 등)에만.
- **regression-lock grep 스코프:** 라이브 surface 3파일만 스캔 — ① `plugins/spec-distill/skills/conducting-interview/SKILL.md`, ② `plugins/spec-distill/skills/reviewing-spec/SKILL.md`, ③ `plugins/spec-distill/README.md`. **CHANGELOG.md는 스캔 제외**(history 보존 — 미래 Removed 엔트리가 정당하게 "wall-clock" 언급).
- **AC14 *번호* 불가침:** reviewing-spec의 wall-clock 체크가 우연히 "AC14"로 라벨됐을 뿐, `tests/test_cancel_review.py` / `tests/test_review_dispatch.sh` / `hooks/spec-write-validator.py`의 동명 "AC14"는 월클락과 **무관** — 건드리지 말 것.
- **AP16 가드 로직 불변:** re-review hard cap(`rereview_count >= 5`) + round-level stagnation early-exit + rhythm-guard(3) + web-budget의 *로직*은 변경 금지. 이 작업은 월클락(중복 4번째 바운드)만 제거한다.
- **README AP16 라인에 web-budget 추가 금지:** web-budget(≤4/≤8)는 conducting-interview의 *interview loop* 바운드이지 re-review loop 가드가 아님. 잔여 커버는 count-cap(5)+stagnation.
- **행 번호는 편집-전 스냅샷(참고용):** 각 Edit *직전* `grep -n`으로 대상 substring/라인을 재locate. 행 번호 맹신 금지.
- **Branch:** `feature/spec-distill-remove-interview-wall-clock` (이미 checkout됨; design은 `5579dc4`에 커밋됨).
- **테스트 실행 위치:** shell 테스트는 repo root에서, python 테스트는 `python3 -m unittest`로만(직접 실행 = vacuous). 본 작업은 main 작업 디렉토리(워크트리 아님)에서 진행 — NG9 cross-resolver pre-existing red는 워크트리 한정이라 여기선 해당 없음.

---

## File Structure

| 파일 | 책임 | 변경 종류 |
|---|---|---|
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | interview state schema + kill-switch 문서 | 라인 삭제 ×2 (Task 1) |
| `plugins/spec-distill/skills/reviewing-spec/SKILL.md` | review phase Steps + frontmatter + kill-switch | substring/라인/블록 삭제 ×4 + Steps 재번호 (Task 2) |
| `plugins/spec-distill/README.md` | AP16 가드 enumeration + kill-switch 문서 | substring/라인 삭제 ×2 (Task 3) |
| `plugins/spec-distill/.claude-plugin/plugin.json` | 플러그인 manifest version | version bump (Task 4) |
| `plugins/spec-distill/CHANGELOG.md` | 변경 이력 | `[0.17.0]` 엔트리 추가 (Task 4) |
| `plugins/spec-distill/tests/test_readme_sync.sh` | 버전 sync 회귀 테스트 (기존) | 버전 기대값 0.16.0→0.17.0 (Task 4) |
| `plugins/spec-distill/tests/test_no_wall_clock.sh` | 월클락 재도입 방지 회귀 락 (신규) | 신규 파일 (Task 5) |

**Task 의존성:** Task 1·2·3 은 서로 독립(다른 파일). Task 4 는 1–3 이후(CHANGELOG가 제거 내용을 서술). Task 5(회귀 락)는 마지막 — 모든 제거가 끝나야 green이 되는 capstone이자 AC7 deliverable.

---

## Task 1: conducting-interview에서 월클락 state 필드 + kill-switch 제거

**Files:**
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (편집-전 기준 라인 42, 335)

**Interfaces:**
- Consumes: 없음 (순수 삭제).
- Produces: `wall_clock_started_at`가 더 이상 state schema에 *쓰이지* 않음 → Task 2의 reader 제거(reviewing-spec)와 짝을 이뤄 dead write/read를 동시에 없앤다. Task 5 회귀 락이 이 파일을 스캔한다.

**ACs covered:** AC1 (schema 필드 제거), AC4 (conducting-interview kill-switch env var 제거), AC9 (no migration — 필드를 더 이상 쓰지 않으니 구 세션 잔여 키는 무해하게 무시됨).

- [ ] **Step 1: 편집 직전 대상 재locate (grep)**

Run:
```bash
grep -nE "wall_clock_started_at|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN" plugins/spec-distill/skills/conducting-interview/SKILL.md
```
Expected (2 hits):
```
42:wall_clock_started_at: <ISO8601>
335:- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget (default 30) — 초과 시 advisory metric에 기록.
```

- [ ] **Step 2: state schema 필드 삭제 (Edit 1a)**

state schema block(YAML frontmatter 형태의 illustrative 블록)에서 `wall_clock_started_at` 라인을 제거. 앞뒤 라인으로 anchor:

old_string:
```
rereview_count: 0
wall_clock_started_at: <ISO8601>
trivia_escape_armed: false
```
new_string:
```
rereview_count: 0
trivia_escape_armed: false
```

- [ ] **Step 3: kill-switch 라인 삭제 (Edit 1b)**

`## kill switch` 섹션에서 `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` 라인을 통째로 제거. 앞뒤 라인으로 anchor:

old_string:
```
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget (default 30) — 초과 시 advisory metric에 기록.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용 (AC8).
```
new_string:
```
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N`: rhythm guard threshold override.
- `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1`: web landscape(R2) 비활성 — loud advisory 후 codebase 근거만 사용 (AC8).
```

- [ ] **Step 4: grep-absence 단언 (이 파일에 월클락 토큰 0)**

Run:
```bash
grep -nEi "wall_clock_started_at|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN|wall-clock" plugins/spec-distill/skills/conducting-interview/SKILL.md; echo "exit=$?"
```
Expected: 출력 없음 + `exit=1` (grep no-match). `exit=0` 이면 토큰 잔존 → 실패.

- [ ] **Step 5: web-budget 가드가 *남아있음* 확인 (인접 토큰 오삭제 방지)**

Run:
```bash
grep -nE "web_sweep_count|web_search_count|DEVBREW_SPEC_DISTILL_DISABLE_WEB|rhythm guard|RHYTHM_GUARD" plugins/spec-distill/skills/conducting-interview/SKILL.md
```
Expected: web-budget(`web_sweep_count`/`web_search_count`) + rhythm-guard 라인이 여전히 존재(non-empty). 월클락만 지웠고 인접 interview-loop 가드는 무사함을 확인.

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -m "refactor(spec-distill): drop wall_clock_started_at from interview state + kill-switch

인터뷰 월클락 제거 (v0.17.0): state schema 필드 + DEVBREW_SPEC_DISTILL_TIMEOUT_MIN
kill-switch 라인 삭제. 필드를 더 이상 쓰지 않으므로 구 세션 잔여 키는 무해하게 무시됨
(no migration). AP16 가드는 re-review cap+stagnation으로 불변.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: reviewing-spec에서 월클락 체크 + reader + frontmatter + kill-switch 제거 및 Steps 재번호

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` (편집-전 기준 라인 7, 18, 19, 138)

**Interfaces:**
- Consumes: Task 1의 결과(state에 `wall_clock_started_at`가 더 이상 쓰이지 않음) — 이 Task가 그 필드의 *reader*(Step 1 로드 목록)와 *체크*(Step 2)를 제거해 dead read를 없앤다.
- Produces: `## Steps` ordered list가 1–5로 연속. routing table / Re-review cap / Stagnation 등 별도 `###`·`##` 섹션은 불변. Task 5 회귀 락이 이 파일을 스캔.

**ACs covered:** AC2 (Steps item 2 삭제 + 재번호 + item 1 reader 제거), AC3 (frontmatter substring), AC4 (reviewing-spec kill-switch env var), AC6 (escalate 경로 *생존* 확인 — grep), AC9 (C10 미참조 재확인).

- [ ] **Step 1: 편집 직전 대상 재locate (grep)**

Run:
```bash
grep -nE "wall_clock_started_at|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN|wall-clock" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```
Expected (4 hits): 라인 7(frontmatter desc), 18(Step 1 reader), 19(Step 2 체크), 138(kill-switch).

- [ ] **Step 2: frontmatter `description` substring 제거 (Edit 2a)**

YAML parse 보존을 위해 **라인 전체가 아니라 substring `wall-clock budget, ` 만** 제거.

old_string:
```
  hard cap → forced escalate), stagnation detection, wall-clock budget, and the Phase 5 proceed gate +
```
new_string:
```
  hard cap → forced escalate), stagnation detection, and the Phase 5 proceed gate +
```

- [ ] **Step 3: Step 1 로드 목록에서 `wall_clock_started_at` reader 제거 (Edit 2b)**

Step 1의 state 로드 목록에서 backtick-token + 후행 `, ` 제거. unique anchor:

old_string:
```
1. **Load state.local.md** — `session_id`, `rereview_count`, `wall_clock_started_at`, `issue_history` 읽기 + `pending_review:` block 확인.
```
new_string:
```
1. **Load state.local.md** — `session_id`, `rereview_count`, `issue_history` 읽기 + `pending_review:` block 확인.
```
> 주의: 라인 18은 위 문장 뒤에 긴 설명이 이어진다. Edit old_string은 위 첫 문장까지만 매칭하면 unique하므로 뒷부분은 그대로 보존된다.

- [ ] **Step 4: Step 2(wall-clock 체크) 삭제 + 후속 item 재번호 (Edit 2c)**

item 2(`Wall-clock check`)를 삭제하고 item 3–6 을 2–5 로 재번호. `## Steps` 의 item 2 시작부터 item 6 끝까지 블록 전체를 치환. (아래 4-backtick 펜스 안의 ``` 는 SKILL.md 본문의 실제 코드펜스다.)

old_string:
````
2. **Wall-clock check (AC14)**: `now - wall_clock_started_at > DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` (default 30) 이면 advisory metric 표기 + Phase 5 forced escalate.
3. **Dispatch spec-reviewer agent**:
   ```
   Agent({
     description: "Spec adversarial review",
     subagent_type: "spec-reviewer",
     prompt: "Review spec.md at <path>. Previous issue history: <list>"
   })
   ```
4. **Parse output** — Status, Issues, Recommendations, Stagnation_signal.
5. **Apply routing table** (다음 섹션).
6. **Update state.local.md** — `rereview_count += 1`, `issue_history`에 새 issues 추가/raised_count 증가.
````
new_string:
````
2. **Dispatch spec-reviewer agent**:
   ```
   Agent({
     description: "Spec adversarial review",
     subagent_type: "spec-reviewer",
     prompt: "Review spec.md at <path>. Previous issue history: <list>"
   })
   ```
3. **Parse output** — Status, Issues, Recommendations, Stagnation_signal.
4. **Apply routing table** (다음 섹션).
5. **Update state.local.md** — `rereview_count += 1`, `issue_history`에 새 issues 추가/raised_count 증가.
````

- [ ] **Step 5: kill-switch 라인 삭제 (Edit 2d)**

`## kill switch` 섹션 마지막의 `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` 라인 제거. 앞 라인으로 anchor:

old_string:
```
- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N`: wall-clock budget override (default 30).
```
new_string:
```
- `DEVBREW_DISABLE_SPEC_DISTILL=1`: 즉시 abort, state.local.md 보존.
```

- [ ] **Step 6: grep-absence 단언 (이 파일에 월클락 토큰 0)**

Run:
```bash
grep -nEi "wall_clock_started_at|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN|wall-clock" plugins/spec-distill/skills/reviewing-spec/SKILL.md; echo "exit=$?"
```
Expected: 출력 없음 + `exit=1`.

- [ ] **Step 7: AC2 재번호 기계 단언 (`## Steps` ordered list = 1.–5. 연속)**

Run:
```bash
awk '/^## Steps/{f=1; next} /^## /{f=0} f' plugins/spec-distill/skills/reviewing-spec/SKILL.md | grep -oE "^[0-9]+\." | tr '\n' ' '
```
Expected output (정확히):
```
1. 2. 3. 4. 5.
```
gap/중복/잔여 `6.` 가 있으면 실패. (awk: `## Steps` 다음 줄부터 f=1, 다음 `## ` 헤딩에서 f=0 — Steps 블록만 추출.)

- [ ] **Step 8: AC6 escalate-path 생존 단언 (월클락 제거가 가드를 안 건드림)**

Run:
```bash
grep -nE "rereview_count >= 5|Round-level stagnation early-exit|Stagnation_signal" plugins/spec-distill/skills/reviewing-spec/SKILL.md
```
Expected: hard cap + stagnation 라인이 여전히 반환됨(non-empty, 3+ hits). forced-escalate 경로(Re-review cap 섹션)가 무손상임을 확인.

- [ ] **Step 9: AC9 — C10 In-flight migration 섹션이 월클락 미참조 재확인**

Run:
```bash
awk '/^## In-flight state migration/{f=1} /^## kill switch/{f=0} f' plugins/spec-distill/skills/reviewing-spec/SKILL.md | grep -ci "wall_clock\|wall-clock\|TIMEOUT_MIN"
```
Expected: `0`. C10은 `issue_history[].dismissed_by_user`만 다루고 월클락을 참조하지 않으므로 migration 코드 변경 불필요(Step 6의 파일-전역 grep-absence가 이미 보장하지만 섹션-국소 재확인).

- [ ] **Step 10: Commit**

```bash
git add plugins/spec-distill/skills/reviewing-spec/SKILL.md
git commit -m "refactor(spec-distill): remove wall-clock check from reviewing-spec + renumber Steps

Step 2 wall-clock 체크(구 AC14) 삭제 + Step 1 reader 제거 + frontmatter desc
substring + kill-switch 라인 제거. ## Steps 를 1-5 로 재번호(routing table 불변).
AP16 forced-escalate는 re-review cap(5)+stagnation으로 무손상.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: README에서 AP16 월클락 토큰 + kill-switch 문서 제거

**Files:**
- Modify: `plugins/spec-distill/README.md` (편집-전 기준 라인 90, 120)

**Interfaces:**
- Consumes: 없음 (문서 동기화).
- Produces: AP16 enumeration이 plugin 전역 가드(re-review cap, rhythm guard, kill switch)만 나열. Task 5 회귀 락이 이 파일을 스캔.

**ACs covered:** AC5 (AP16 라인 substring, web-budget 추가 안 함), AC4 (README kill-switch env var 제거).

- [ ] **Step 1: 편집 직전 대상 재locate (grep)**

Run:
```bash
grep -nEi "wall-clock|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN" plugins/spec-distill/README.md
```
Expected (2 hits): 라인 90(AP16), 120(kill-switch).

- [ ] **Step 2: AP16 라인 substring 제거 (Edit 3a)**

`wall-clock 30min, ` substring만 제거. **web-budget 추가 금지.**

old_string:
```
- **AP16 (Unbounded autonomy)** — re-review max 5 (hybrid policy, v0.3.0: hard cap + stagnation early-exit), rhythm guard 3, wall-clock 30min, kill switch.
```
new_string:
```
- **AP16 (Unbounded autonomy)** — re-review max 5 (hybrid policy, v0.3.0: hard cap + stagnation early-exit), rhythm guard 3, kill switch.
```

- [ ] **Step 3: kill-switch 문서 라인 삭제 (Edit 3b)**

`## Kill switches` 에서 `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` 라인 제거. 앞뒤 라인으로 anchor:

old_string:
```
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN=N` — wall-clock budget (default 30 min).
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.3.0) — PostToolUse Layer 1 (structural check) 정상 동작, Layer 2 (`pending_review:` ledger 기록) skip. 비상시 reviewer dispatch cost 회피용.
```
new_string:
```
- `DEVBREW_RHYTHM_GUARD_THRESHOLD=N` — Dialectic Rhythm Guard threshold (default 3).
- `DEVBREW_SPEC_DISTILL_SKIP_AUTOREVIEW=1` (v0.3.0) — PostToolUse Layer 1 (structural check) 정상 동작, Layer 2 (`pending_review:` ledger 기록) skip. 비상시 reviewer dispatch cost 회피용.
```

- [ ] **Step 4: grep-absence + AP16 verbatim 단언**

Run:
```bash
grep -nEi "wall_clock_started_at|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN|wall-clock" plugins/spec-distill/README.md; echo "absence_exit=$?"
grep -nF '- **AP16 (Unbounded autonomy)** — re-review max 5 (hybrid policy, v0.3.0: hard cap + stagnation early-exit), rhythm guard 3, kill switch.' plugins/spec-distill/README.md; echo "ap16_exit=$?"
```
Expected: 첫 grep 출력 없음 + `absence_exit=1`; 둘째 grep 정확히 매칭 + `ap16_exit=0`.

- [ ] **Step 5: Commit**

```bash
git add plugins/spec-distill/README.md
git commit -m "docs(spec-distill): drop wall-clock from README AP16 + kill-switch

AP16 enumeration의 'wall-clock 30min' 토큰 제거(web-budget는 interview-loop
소속이라 추가 안 함) + Kill switches의 DEVBREW_SPEC_DISTILL_TIMEOUT_MIN 라인 삭제.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 버전 bump + CHANGELOG + readme-sync 테스트 동기화

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (version)
- Modify: `plugins/spec-distill/CHANGELOG.md` (신규 `[0.17.0]` 엔트리, 파일 최상단 `# Changelog` 다음에 prepend)
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh` (버전 기대값 0.16.0 → 0.17.0; design Files 표에 없던 *spec-implied* 파일 — AC8 sync를 강제하는 기존 테스트라 미수정 시 회귀)

**Interfaces:**
- Consumes: Task 1–3의 제거 결과 (CHANGELOG 서술이 제거 항목을 기술).
- Produces: `test_readme_sync.sh`가 0.17.0 manifest + CHANGELOG와 정합 → 기존 스위트 green 유지.

**ACs covered:** AC8 (plugin.json 0.17.0 + CHANGELOG Removed 엔트리).

- [ ] **Step 1: plugin.json version bump (Edit)**

old_string:
```
  "version": "0.16.0",
```
new_string:
```
  "version": "0.17.0",
```

- [ ] **Step 2: CHANGELOG 엔트리 추가 (Edit — `# Changelog` 다음에 prepend)**

old_string:
```
# Changelog

## [0.16.0] — 2026-06-16
```
new_string:
```
# Changelog

## [0.17.0] — 2026-06-17

### Removed
- 인터뷰 월클락 메커니즘 **완전 제거**: `wall_clock_started_at` state 필드(conducting-interview schema) + reviewing-spec `## Steps` item 2의 wall-clock 체크(구 AC14) + Step 1 reader + `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` env var(양쪽 SKILL kill-switch + README) + README AP16 라인의 `wall-clock 30min` 토큰. 시계가 인터뷰 시작 시 켜지고 re-review 루프에서 트립해 *agent 자율성이 아니라 사람의 숙고 시간*을 오측정하던 footgun이었다 — AP16의 load-bearing 가드는 같은 루프의 re-review hard cap(5) + round-level stagnation early-exit이므로 월클락은 중복(redundant) 4번째 바운드였다. 구 세션 state의 잔여 `wall_clock_started_at` 키는 reader 부재로 무해하게 무시됨(migration 코드 불필요 — forward-compatible). harness-lightness(결정론은 load-bearing 게이트에만) + qg v2.0.0 월클락 budget 제거 선례에 정합. spec-distill은 v0.x라 one-minor deprecation window 면제 → 즉시 제거.

### Added
- `tests/test_no_wall_clock.sh` — 월클락 토큰(`wall_clock_started_at` / `DEVBREW_SPEC_DISTILL_TIMEOUT_MIN` / `wall-clock`) 재도입 방지 회귀 락. 라이브 surface 3파일(conducting-interview SKILL, reviewing-spec SKILL, README) 스캔, CHANGELOG는 history 보존이라 제외. v0.16.0 `test_hooks.sh` regression-lock 선례 패턴(repurpose 아닌 신규 파일).

### Changed
- `tests/test_readme_sync.sh` — 버전 기대값 0.16.0 → 0.17.0.

## [0.16.0] — 2026-06-16
```

- [ ] **Step 3: test_readme_sync.sh 버전 기대값 갱신 (Edit ×6, 또는 sed)**

6개 `0.16.0` 참조(plain 3 + regex-escaped 2 + 헤더 주석 1)를 `0.17.0`로. 정확한 before/after:

| 라인 | old | new |
|---|---|---|
| 2 | `# AC16 — README/plugin.json/CHANGELOG synced with v0.16.0 (SessionStart anchor removal).` | `# AC16 — README/plugin.json/CHANGELOG synced with v0.17.0 (interview wall-clock removal).` |
| 13 | `grep -q '"version": "0.16.0"' "$PLUGIN_JSON" \` | `grep -q '"version": "0.17.0"' "$PLUGIN_JSON" \` |
| 14 | `  && note PASS "AC16: plugin.json version 0.16.0" \|\| note FAIL "AC16: plugin.json not 0.16.0"` | `  && note PASS "AC16: plugin.json version 0.17.0" \|\| note FAIL "AC16: plugin.json not 0.17.0"` |
| 15 | `grep -qE '^## \[0\.16\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \` | `grep -qE '^## \[0\.17\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \` |
| 16 | `  && note PASS "AC16: CHANGELOG [0.16.0] entry with ISO date" \|\| note FAIL "AC16: CHANGELOG [0.16.0] missing/!ISO"` | `  && note PASS "AC16: CHANGELOG [0.17.0] entry with ISO date" \|\| note FAIL "AC16: CHANGELOG [0.17.0] missing/!ISO"` |
| 17 | `grep -qE '^## \[0\.16\.0\].*XX' "$CHANGELOG" \` | `grep -qE '^## \[0\.17\.0\].*XX' "$CHANGELOG" \` |

대안 (한 번에): `sed -i '' -e 's/0\.16\.0/0.17.0/g' plugins/spec-distill/tests/test_readme_sync.sh` 후 헤더 주석의 `(SessionStart anchor removal)` → `(interview wall-clock removal)` 만 별도 Edit. (`sed`의 `s/0\.16\.0/0.17.0/g` 는 plain `0.16.0` 과 regex-escaped `0\.16\.0` 양쪽 모두 — escaped 형태는 리터럴로 `0`,`\`,`.`... 이므로 `0.16.0` 부분문자열을 포함 → `0\.16\.0` 의 `16` 을 포함하는 `.16.` 가 매칭되어 `0\.17\.0` 가 됨. 검증은 Step 4가 한다.)

- [ ] **Step 4: readme-sync 테스트 green 확인**

Run (repo root):
```bash
bash plugins/spec-distill/tests/test_readme_sync.sh; echo "exit=$?"
```
Expected: 모든 체크 PASS (plugin.json 0.17.0 매칭, CHANGELOG `[0.17.0]` ISO date 매칭, XX placeholder 없음, README 키워드 DEVBREW_SPEC_DISTILL_DISABLE_WEB/interview-brief/steelman-builder/cancel-review 여전히 존재) + `exit=0`.

- [ ] **Step 5: 잔여 0.16.0 기대값이 없음 확인**

Run:
```bash
grep -n "0\.16\.0" plugins/spec-distill/tests/test_readme_sync.sh; echo "exit=$?"
```
Expected: 출력 없음 + `exit=1` (모든 버전 기대값이 0.17.0로 갱신됨).

- [ ] **Step 6: Commit**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "chore(spec-distill): bump to 0.17.0 (interview wall-clock removal)

plugin.json 0.16.0->0.17.0 + CHANGELOG [0.17.0] Removed 엔트리 + test_readme_sync.sh
버전 기대값 동기화.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 월클락 재도입 방지 회귀 락 (신규) + 전체 검증

**Files:**
- Create: `plugins/spec-distill/tests/test_no_wall_clock.sh`

**Interfaces:**
- Consumes: Task 1–3의 제거 결과 (3 라이브 surface가 월클락-free).
- Produces: AC7 deliverable — 월클락 토큰이 라이브 surface로 되살아나면 red가 되는 결정론적 락.

**ACs covered:** AC7 (regression-lock 테스트), AC6 (전체 escalate 가드 테스트 green 재확인).

- [ ] **Step 1: 회귀-락 테스트 작성 (`test_hooks.sh` 선례 패턴)**

Create `plugins/spec-distill/tests/test_no_wall_clock.sh`:
```bash
#!/usr/bin/env bash
# spec-distill — 인터뷰 월클락 제거 회귀 락 (v0.17.0).
# Run: bash plugins/spec-distill/tests/test_no_wall_clock.sh
# 월클락 토큰이 라이브 surface(2 SKILL + README)로 되살아나지 않음을 보장.
# CHANGELOG는 history 보존이라 스캔 제외(과거 Removed 엔트리가 정당하게 "wall-clock" 언급).
# Exits 0 on pass, 1 on fail.

set -u
set -o pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
PLUGIN_ROOT="$REPO_ROOT/plugins/spec-distill"

# 라이브 surface — 월클락 토큰이 0이어야 하는 파일 (CHANGELOG 제외).
SURFACES=(
  "$PLUGIN_ROOT/skills/conducting-interview/SKILL.md"
  "$PLUGIN_ROOT/skills/reviewing-spec/SKILL.md"
  "$PLUGIN_ROOT/README.md"
)

# 금지 토큰 (재도입 방지).
TOKENS=(
  "wall_clock_started_at"
  "DEVBREW_SPEC_DISTILL_TIMEOUT_MIN"
  "wall-clock"
)

pass=0
fail=0

note() {
  if [[ "$1" == "PASS" ]]; then
    pass=$((pass+1))
    echo "  ✓ $2"
  else
    fail=$((fail+1))
    echo "  ✗ $2"
  fi
}

echo "=== interview wall-clock removal regression lock ==="

for surface in "${SURFACES[@]}"; do
  rel="${surface#"$REPO_ROOT"/}"
  if [[ ! -f "$surface" ]]; then
    note FAIL "surface missing: $rel"
    continue
  fi
  for tok in "${TOKENS[@]}"; do
    if grep -qiF -- "$tok" "$surface"; then
      note FAIL "$rel still contains token '$tok'"
    else
      note PASS "$rel free of '$tok'"
    fi
  done
done

echo ""
echo "Results: $pass passed, $fail failed"
[[ $fail -eq 0 ]] && exit 0 || exit 1
```

- [ ] **Step 2: 락이 "이빨"이 있는지 demonstrate (vacuous-green 아님 — Law 3 theater 회피)**

회귀 락은 토큰이 *있을 때* fire 해야 의미가 있다. 같은 grep을 CHANGELOG(정당하게 "wall-clock" 포함)에 돌려 detector가 fire 함을 증명:

Run:
```bash
grep -qiF -- "wall-clock" plugins/spec-distill/CHANGELOG.md && echo "OK: detector fires on CHANGELOG (expected — lock has teeth)" || echo "BUG: detector did not fire"
```
Expected: `OK: detector fires on CHANGELOG (expected — lock has teeth)`. (이로써 grep 로직이 vacuous하지 않음을 확인 — CHANGELOG는 의도적으로 스캔 스코프에서 제외했기에 이 fire가 테스트를 깨지 않는다.)

- [ ] **Step 3: 회귀 락 실행 → green**

Run (repo root):
```bash
bash plugins/spec-distill/tests/test_no_wall_clock.sh; echo "exit=$?"
```
Expected: `9 passed, 0 failed` (3 surfaces × 3 tokens) + `exit=0`.

- [ ] **Step 4: AC6 escalate 가드 테스트 green (월클락 제거 회귀 0)**

Run (repo root):
```bash
bash plugins/spec-distill/tests/test_rereview_cap_consistency.sh; echo "exit=$?"
bash plugins/spec-distill/tests/test_reviewing_spec_design_routing.sh; echo "exit=$?"
bash plugins/spec-distill/tests/test_reviewing_spec_design_only.sh; echo "exit=$?"
bash plugins/spec-distill/tests/test_hooks.sh; echo "exit=$?"
```
Expected: 전부 PASS + `exit=0`. (cap consistency = hard cap 5 무손상; routing/design-only = routing table·mode 분기 무손상이라 Steps 재번호 영향 없음; hooks = SessionStart 락 무관 무손상.)

- [ ] **Step 5: 전체 shell 스위트 + python 스위트 회귀 0**

Run (repo root):
```bash
echo "=== shell suite ==="
for t in plugins/spec-distill/tests/*.sh; do
  echo "--- $t ---"
  bash "$t" || echo "!!! FAILED: $t"
done
echo "=== python suite ==="
python3 -m unittest discover -s plugins/spec-distill/tests
```
Expected: 모든 shell 테스트 exit 0(`!!! FAILED` 라인 없음); python `OK`. (본 작업은 main 작업 디렉토리라 NG9 cross-resolver red는 해당 없음. 만약 발생하면 환경-의존 pre-existing red인지 git stash로 baseline 대조 후 무관 확인.)

- [ ] **Step 6: 최종 grep sweep (라이브 surface 0 참조 + CHANGELOG history 보존)**

Run (repo root):
```bash
echo "=== live surfaces (expect ZERO) ==="
grep -rnEi "wall_clock_started_at|DEVBREW_SPEC_DISTILL_TIMEOUT_MIN|wall-clock" \
  plugins/spec-distill/skills/conducting-interview/SKILL.md \
  plugins/spec-distill/skills/reviewing-spec/SKILL.md \
  plugins/spec-distill/README.md; echo "live_exit=$?"
echo "=== CHANGELOG history (expect non-zero — preserved) ==="
grep -cqi "wall-clock" plugins/spec-distill/CHANGELOG.md && echo "OK: CHANGELOG history preserved"
echo "=== AC14 number untouched in unrelated files (expect present) ==="
grep -rn "AC14" plugins/spec-distill/tests/test_cancel_review.py plugins/spec-distill/tests/test_review_dispatch.sh
```
Expected: live surfaces 출력 없음 + `live_exit=1`; `OK: CHANGELOG history preserved`; test 파일의 무관 AC14 여전히 존재(미손상).

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill/tests/test_no_wall_clock.sh
git commit -m "test(spec-distill): add wall-clock removal regression lock

라이브 surface 3파일(2 SKILL + README)에 월클락 토큰 재도입 방지 grep-absence 락.
CHANGELOG는 history라 스캔 제외. v0.16.0 test_hooks.sh 회귀-락 선례 패턴.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review (작성 후 spec 대조)

**1. Spec coverage (AC1–AC9 → task 매핑):**
- AC1 (conducting-interview schema 필드) → Task 1 Step 2 ✓
- AC2 (reviewing-spec Steps item 2 삭제 + 재번호 + item 1 reader) → Task 2 Steps 3·4 + Step 7 awk 단언 ✓
- AC3 (frontmatter substring) → Task 2 Step 2 ✓
- AC4 (env var: 양쪽 SKILL + README) → Task 1 Step 3 + Task 2 Step 5 + Task 3 Step 3 ✓
- AC5 (README AP16 substring, web-budget 미추가) → Task 3 Step 2 + verbatim 단언 Step 4 ✓
- AC6 (forced-escalate 생존) → Task 2 Step 8 grep + Task 5 Step 4 cap/routing 테스트 ✓
- AC7 (regression-lock 테스트) → Task 5 ✓
- AC8 (plugin.json 0.17.0 + CHANGELOG) → Task 4 ✓
- AC9 (구 세션 잔여 필드 무해 — no migration) → Task 1 (필드 미사용화) + Task 2 Step 9 (C10 미참조 재확인); 코드 변경 없음 ✓
- Files to Modify 6파일 전부 + spec-implied 7번째(`test_readme_sync.sh`) 커버 ✓

**2. Placeholder scan:** 모든 Edit이 verbatim old/new 제공. "TBD"/"적절히 처리"/코드 없는 "구현하라" 없음. 회귀-락 테스트 전문 포함. ✓

**3. Type/식별자 consistency:** 토큰 3종(`wall_clock_started_at`/`DEVBREW_SPEC_DISTILL_TIMEOUT_MIN`/`wall-clock`)이 grep·테스트·verbatim 전반에 일관. 버전 `0.16.0→0.17.0` 일관. 회귀-락 파일명 `test_no_wall_clock.sh` 가 Task 5·CHANGELOG·File Structure 표에서 동일. ✓

**Discovered-during-planning addition:** design Files 표에 없던 `tests/test_readme_sync.sh` 버전 sync(Task 4 Step 3) — AC8의 sync를 강제하는 기존 테스트라 미수정 시 "회귀 0" 위반. spec-implied로 추가됨.
