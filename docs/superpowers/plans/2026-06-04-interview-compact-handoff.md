# interview → brainstorming `/compact` proceed 게이트 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill `conducting-interview` Step B의 자동 brainstorming invoke를, `reviewing-spec` Phase 5와 대칭인 3옵션 `/compact` proceed 게이트로 교체한다.

**Architecture:** 단일 컴포넌트 변경 — `conducting-interview/SKILL.md`의 "Step B" 산문 섹션 하나를 게이트 설계로 재작성하고, `test_conducting_interview_stage.sh`의 grep-assert가 게이트 문구를 mechanically 고정한다(Law 3 compounding). 새 스크립트·새 state 필드·새 hook 없음(lightness). 변경 위치는 워크트리 `feature/interview-compact-handoff`(main=`b5a20b5`, spec-distill 0.12.0 베이스).

**Tech Stack:** Markdown skill 파일 + bash grep-assert 테스트(`grep -qiE` / `grep -cE`). 실행: `bash plugins/spec-distill/tests/<test>.sh` (repo root 기준). 모델은 `/compact`를 스스로 실행할 수 없으므로 옵션 ① 경로는 본질적으로 멈춰서 사용자를 기다리는 게이트다.

---

## Reference: 승인된 설계 / 무변경 영역

- **설계 원문**: `docs/superpowers/specs/2026-06-04-interview-compact-handoff-design.md` (Law 2 분리 reviewer round-2 approved). §5.2가 Step B 게이트 설계, §6이 AC20–24, §8이 Files to Modify.
- **미러링 모델**: `plugins/spec-distill/skills/reviewing-spec/SKILL.md` Phase 5 Step B/C (어휘만 interview로 바꿔 독립 저술 — Approach A, 공유 추출 아님).
- **절대 건드리지 말 것** (설계 §3 Non-goals + §10 Handoff Context): 5 통과 의례(R1–R5) / web budget / steelman / hook(`spec-write-validator.py`·`session-end-cleanup.py`) / `reviewing-spec` Phase 5 / `approve_handoff.sh`. 두 가드(AP2 + cross-compact AC21)는 load-bearing — 약화 시 `/compact` 옵션이 무의미해지므로 문구를 희석하지 말 것.
- **`approve_handoff.sh` 미호출**(설계 §5.3): interview brief는 같은 턴에 막 작성+`check_brief.py` 검증되어 stale 위험이 없고, cleanup은 하류 또는 SessionEnd가 담당. 옵션 ① 노출 *전*에 `[[ -f <brief-path> ]]` 경량 존재 가드만 둔다(게이트 자체 아님).

## File Structure

| 파일 | 변경 책임 |
|---|---|
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | "Step B — optional handoff" 섹션 하나를 B-1~B-4 게이트 설계로 재작성. reviewing-spec Phase 5 cross-reference 한 줄. (Step A·5 의례·state contract 무변경.) |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | AC20/AC21(i)/AC22 grep assert 추가. 기존 23 assert 유지(특히 AC23 one-line·AC24 `optional|선택`). |
| `plugins/spec-distill/.claude-plugin/plugin.json` | `version` `0.12.0 → 0.13.0` (minor = 새 surface). |
| `plugins/spec-distill/CHANGELOG.md` | `## [0.13.0] — 2026-06-04` 엔트리. |
| `plugins/spec-distill/tests/test_readme_sync.sh` | 하드코딩 `0.12.0 → 0.13.0` (3곳) — 버전 bump의 기계적 귀결. 안 하면 red. |
| `plugins/spec-distill/README.md` | Flow 헤딩·다이어그램 게이트 표기 + "Principles Instantiated" AP2 한 줄. |

## Baseline (구현 전 확인됨)

- `test_conducting_interview_stage.sh`: **23/23 PASS** (green).
- AC20/21/22 신규 토큰(`AskUserQuestion`, `/compact 후 brainstorming`, `바로 brainstorming`, `brief만 종료`, `/compact interview brief at`, `턴 종료|다음 턴`, polite-stop 패턴) 현재 SKILL.md에 **0건** → 추가 assert는 진짜 red.
- `optional|선택`=7, `superpowers.*(부재|없).*advisory`=1 → AC23/AC24 현재 green, 재작성이 보존해야 함.
- 워크트리 pre-existing red(작업 무관, reference 메모): `test_session_id_resolution`류 NG9 cross-resolver 1개는 환경 의존 — 본 작업과 무관, baseline으로 간주.

---

## Task 1: Step B proceed 게이트 — test(red) → SKILL.md(green)

**Files:**
- Test: `plugins/spec-distill/tests/test_conducting_interview_stage.sh`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (lines 232–244, "### Step B — optional handoff" 섹션)

- [ ] **Step 1: AC20/AC21(i)/AC22 grep assert 추가 (failing test)**

`test_conducting_interview_stage.sh`에서 line 38 (`has 'superpowers.*(부재|없).*advisory|advisory.*superpowers' "AC13: ..."`) **다음 줄**에 아래 블록을 삽입. (line 37–38은 AC24/AC23 mechanical로 그대로 유지.)

```bash
# --- v0.13.0: Step B /compact proceed 게이트 (AC20/AC21/AC22) ---
has 'AskUserQuestion' "AC20: Step B proceed gate uses AskUserQuestion"
has '/compact 후 brainstorming' "AC20: option ① label (/compact 후 brainstorming)"
has '바로 brainstorming' "AC20: option ② label (바로 brainstorming)"
has 'brief만 종료' "AC20: option ③ label (brief만 종료)"
has '/compact interview brief at' "AC20: verbatim /compact command exposed"

# AC21(i) mechanical only — review layer (ii) coexistence judgment = spec-reviewer persona
cc=$(grep -cE "턴 종료|다음 턴" "$SKILL"); [[ "$cc" -ge 1 ]] \
  && note PASS "AC21(i): cross-compact stop wording present (lines=$cc)" \
  || note FAIL "AC21(i): cross-compact stop wording absent"

has 'polite[- ]?stop|narrate.*금지|silent 종료 금지' "AC22: AP2 polite-stop ban codified"
```

- [ ] **Step 2: 테스트 실행 → red 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh; echo "EXIT=$?"`
Expected: 기존 23 ✓ 유지 + 신규 7 assert가 ✗ FAIL (AskUserQuestion / 옵션 ①②③ 라벨 / verbatim /compact / AC21(i) / AC22). `EXIT=1`. (Total 30 | Pass 23 | Fail 7 근방.)

- [ ] **Step 3: SKILL.md Step B 재작성 (minimal green)**

`SKILL.md` line 232–244의 현행 "### Step B — optional handoff (superpowers 있을 때만)" 섹션 **전체**(`### Step B` 헤더부터 `이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).` 줄까지)를 아래로 교체. **그 위 `### Step A` 섹션과 그 아래 `## In-flight state migration` 섹션은 건드리지 말 것.**

> ⚠ **AC23 레이아웃 제약**: B-1 "superpowers 부재" bullet은 `superpowers`/`부재`/`advisory` 세 토큰이 **한 물리적 줄**에 있어야 grep이 통과한다. 아래 블록은 그 bullet을 일부러 한 줄로 둔다 — 재배치/줄바꿈 금지.

````markdown
### Step B — proceed 게이트 (handoff 방식 제안)

brief는 **단독 완결 terminal 산출물**입니다(NG7 — handoff는 강제가 아니라 사용자 선택).
Step B는 단일 책임 단위입니다: *brief가 완결되면 다음 stage(brainstorming 해답공간) 진입
방식을 사용자에게 제안한다.* 입력 = 완결·`check_brief.py` 검증된 brief 경로 + superpowers
가용성. 이 핸드오프는 `reviewing-spec` Phase 5의 `/compact` proceed 게이트와 **대칭**입니다 —
같은 두 가드(AP2 + cross-compact)를 interview 어휘로 독립 저술합니다(상세 모델:
`skills/reviewing-spec/SKILL.md` Phase 5).

#### B-1 — superpowers 가용성 분기 (AC13 보존)

- **superpowers 부재 시 (AC13)**: 현행 graceful degradation 그대로 — brief를 완료하고 **loud advisory**를 낸 뒤 **정지(STOP)**. 게이트 없음(compact 후 넘길 대상 자체가 없음). crash·spec-mode fallback **금지**(단독 완결, graceful degrade):

  > `[spec-distill] interview brief 완결: docs/superpowers/interview/<file>. superpowers 설치 시 brainstorming 해답공간 단계로 이어집니다. 미설치 시 이 brief를 직접 다음 작업의 입력으로 사용하세요.`

- **superpowers 가용 시**: B-2 proceed 게이트 제시.

#### B-2 — 단일 `AskUserQuestion` proceed 게이트 (3옵션, AC20)

게이트 *이전*에 brief 경로 존재를 확인합니다(`[[ -f <brief-path> ]]` — race 방어 경량 가드,
`AskUserQuestion` 게이트 자체는 아님). 부재 시 reviewing-spec Phase 5 Step A와 대칭으로
`/compact`를 노출하지 *않고* loud advisory 후 STOP(`approve_handoff.sh` 미호출 — 설계 §5.3):

> `[spec-distill] brief '<brief-path>' 부재 — 재작성/세션 리셋 필요`

(Step A의 작성 + `check_brief.py` 검증 직후라 정상 경로에선 발생하지 않습니다.)

brief 유효 시 **한 번의** `AskUserQuestion`으로 다음 단계를 제안합니다:

```javascript
AskUserQuestion({
  questions: [{
    question: "interview brief 완결: <brief-path> (5 통과 의례 통과). 다음 단계?",
    header: "Proceed",
    options: [
      {label: "/compact 후 brainstorming (권장)", description: "verbatim /compact 노출 → 사용자 실행 시 brainstorming. 긴 인터뷰 context(round 대화·web sweep·steelman 중간산출) 정리 이점. brief 보존."},
      {label: "바로 brainstorming", description: "즉시 Skill superpowers:brainstorming <brief-path> 호출 (compact 없이, 전체 context 유지)."},
      {label: "brief만 종료", description: "brief는 단독 완결 terminal (NG7). handoff 안 함, 종료."}
    ],
    multiSelect: false
  }]
})
```

#### B-3 — 응답 처리

- **① /compact 후 brainstorming**: 아래 verbatim `/compact` 명령을 *그대로 보이게* 노출
  (`<brief-path>`는 실제 brief 경로로 치환) + "compact 후 brainstorming 진입 준비됨" 안내:

  > `/compact interview brief at <brief-path> 보존 — brief 본문(특히 Reframe, Landscape, Locked Directions, Open Questions)과 경로 참조 유지하고, round-by-round 인터뷰 대화·web sweep 원문·steelman 중간 추론은 drop. 다음 단계: Skill superpowers:brainstorming <brief-path>.`

  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것**(compact 전
  brainstorming 진입 = 옵션 ① 무력화). `Skill superpowers:brainstorming <brief-path>` 진입은
  사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write design`처럼
  compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동
  진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17). compact된 fresh
  context에서 brainstorming이 brief를 다시 읽어 해답공간을 설계한다.

- **② 바로 brainstorming**: 즉시 `Skill superpowers:brainstorming <brief-path>` 호출(rich
  context 유지 — 현행 동작과 동일). 이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.

- **③ brief만 종료**: brief terminal advisory(B-1 부재 advisory와 동일 톤) 출력 후 종료.
  handoff 안 함. state는 SessionEnd hook이 cleanup(별도 cleanup 호출 없음).

#### B-4 — 두 가드 (load-bearing)

- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate하고 게이트 제시/Skill 호출을
  skip하는 것은 **polite stop** — 금지. Step B를 *종료*하는 모든 경로는 (a) 위 proceed 게이트를
  거치거나(①/②/③), (b) 게이트를 거치지 않는 예외(superpowers 부재)는 명시적 advisory 단락을
  동반해야 한다 — 게이트-less **silent 종료 금지**. (게이트는 사용자가 redirect 가능한 approval
  gate이므로 P17 주권에 기여, polite-stop 아님 — 철학 §AP2.)

- **cross-compact 조기진행 금지 (AC21, AC19 대칭)**: 옵션 ① 선택 시 `/compact`를 노출한 *직후*
  같은 턴에서 `brainstorming`으로 직진하는 것은 금지. compact가 무거운 작업 *뒤에* 오면 context
  위생 이점이 사라져 옵션 ①이 무의미해진다(reviewing-spec AC19에서 실측된 실패 패턴의 대칭).
  **다음 턴** 진입은 *사용자 트리거*(B-3 ①의 정규 문구: compact 뒤에 붙인 진행 인자 예 `/compact
  write design`, 또는 명시적 진행 요청)로만 일어나며 모델 자동 진입이 아니다(NG4·P17). polite
  stop이 "진행해야 할 때 멈춤"이라면 이것은 "멈춰야 할 때 진행" — 두 방향 모두 게이트의
  사용자-주권(P17)을 우회한다. 옵션 ②는 이 정지 요건의 *명시적 예외*(compact 없이 즉시
  brainstorming).

이 stage는 brief까지로 종료됩니다. handoff를 *강제하지 않습니다*(NG7).
````

- [ ] **Step 4: 테스트 실행 → green 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh; echo "EXIT=$?"`
Expected: **30/30 PASS** (기존 23 + 신규 7), `EXIT=0`. 특히 `AC23` (superpowers 부재 one-line) + `AC24` (`optional|선택`) 여전히 ✓ — 회귀 없음.

- [ ] **Step 5: hook-level 회귀 확인 (인과 독립)**

Run: `bash plugins/spec-distill/tests/test_brainstorming_entry.sh; echo "EXIT=$?"`
Expected: `PASSED: 3 cases sequential`, `EXIT=0`. (이 테스트는 PostToolUse hook + SessionEnd cleanup만 검사 — Step B 산문과 무관. 설계 §9 step 2 근거.)

- [ ] **Step 6: 커밋 (test + SKILL.md 함께 — green 경계)**

```bash
git add plugins/spec-distill/tests/test_conducting_interview_stage.sh \
        plugins/spec-distill/skills/conducting-interview/SKILL.md
git commit -m "$(cat <<'EOF'
feat(spec-distill): interview→brainstorming /compact proceed gate (Step B)

conducting-interview Step B의 자동 brainstorming invoke를 reviewing-spec
Phase 5와 대칭인 3옵션 AskUserQuestion proceed 게이트(①/compact 후 brainstorming
②바로 ③brief만 종료)로 교체. 두 가드 명문화: AP2 polite-stop 금지 +
cross-compact 조기진행 금지(AC21, AC19 대칭). superpowers 부재 graceful
degradation(AC13) + NG7 보존. AC20/21(i)/22 grep assert 추가.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 2: 버전 bump + CHANGELOG + README + readme-sync 테스트

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/tests/test_readme_sync.sh`
- Modify: `plugins/spec-distill/README.md`

- [ ] **Step 1: plugin.json 버전 bump**

`plugin.json`에서 한 줄 교체:

```json
  "version": "0.13.0",
```
(현재 `"version": "0.12.0",`를 교체. minor bump = 새 surface.)

- [ ] **Step 2: test_readme_sync.sh 기대 버전 갱신 (0.12.0 → 0.13.0, 3곳)**

`test_readme_sync.sh` line 13–18의 세 assert에서 `0.12.0` → `0.13.0`, `\[0\.12\.0\]` → `\[0\.13\.0\]`로 교체. 교체 후 블록:

```bash
grep -q '"version": "0.13.0"' "$PLUGIN_JSON" \
  && note PASS "AC11: plugin.json version 0.13.0" || note FAIL "AC11: plugin.json not 0.13.0"
grep -qE '^## \[0\.13\.0\] — 2026-[0-9]{2}-[0-9]{2}$' "$CHANGELOG" \
  && note PASS "AC11: CHANGELOG [0.13.0] entry with ISO date" || note FAIL "AC11: CHANGELOG [0.13.0] missing/!ISO"
grep -qE '^## \[0\.13\.0\].*XX' "$CHANGELOG" \
  && note FAIL "AC11: CHANGELOG date has XX placeholder" || note PASS "AC11: no XX placeholder in date"
```

(line 1 헤더 주석 `# AC12 — README synced with v0.12.0 interview flow.`도 `v0.13.0`으로 갱신.)

- [ ] **Step 3: CHANGELOG [0.13.0] 엔트리 추가**

`CHANGELOG.md`의 `# Changelog` (line 1) 다음, 기존 `## [0.12.0]` (line 3) **앞**에 삽입:

```markdown
## [0.13.0] — 2026-06-04

### Added
- `skills/conducting-interview/SKILL.md` Step B — interview→brainstorming 핸드오프를 단일 `AskUserQuestion` **proceed 게이트**(3옵션: ① `/compact` 후 brainstorming 권장 / ② 바로 brainstorming / ③ brief만 종료)로 재작성. `reviewing-spec` Phase 5의 `/compact` 게이트와 **대칭** — 긴 인터뷰 context(round 대화·web sweep·steelman 중간산출)를 해답공간 진입 *전에* 정리할 수 있게. 두 가드 명문화: AP2 polite-stop 금지 + cross-compact 조기진행 금지(옵션 ① 노출 후 같은 턴 brainstorming 직진 금지, AC19 대칭, AC21). superpowers 부재 시 graceful degradation(brief terminal + loud advisory + STOP, 게이트 없음)은 보존(AC13). NG7(handoff 비강제)은 옵션 ③으로 가시화.
- Tests: `tests/test_conducting_interview_stage.sh`에 AC20(3옵션 게이트 + verbatim /compact) / AC21(i)(cross-compact stop wording, mechanical layer) / AC22(AP2 polite-stop ban) grep assert 추가.

### Changed
- `tests/test_readme_sync.sh` — 버전 동기화 기대값 `0.12.0 → 0.13.0`.
- `README.md` — Flow 다이어그램에 interview→brainstorming proceed 게이트 표기 + "Principles Instantiated" AP2에 interview-side `/compact` 대칭 게이트 한 줄.

### Notes
- `approve_handoff.sh`는 interview 쪽에서 **호출하지 않음** — brief는 같은 턴에 막 작성 + `check_brief.py` 검증되어 stale 위험이 없고, 세션 cleanup은 하류(brainstorming→reviewing-spec→spec→writing-plans의 approve_handoff) 또는 SessionEnd가 담당. 옵션 ① 노출 전 `[[ -f <brief-path> ]]` 경량 존재 가드만 둠(게이트 아님).
- `reviewing-spec` Phase 5는 무변경 — 본 작업은 interview 쪽 비대칭만 해소.
```

- [ ] **Step 4: README Flow 헤딩 + 다이어그램 게이트 표기**

(a) `## Flow (v0.12.0)` (line 23) → `## Flow (v0.13.0)`.

(b) Flow 다이어그램(line 30–32) 교체 — 기존:
```
                                   interview brief → docs/superpowers/interview/   ← terminal 산출물
                                       ▼ (optional — superpowers 있을 때만)
                                   superpowers:brainstorming → -design.md
```
신규:
```
                                   interview brief → docs/superpowers/interview/   ← terminal 산출물
                                       ▼ [Step B proceed 게이트] ①/compact 후 brainstorming · ②바로 · ③brief만 종료  (superpowers 있을 때만)
                                   superpowers:brainstorming → -design.md
```

(c) line 41 `**v0.12.0**: ...` 단락 **다음 줄**에 추가:
```markdown
**v0.13.0**: interview→brainstorming Step B를 `/compact` proceed 게이트(reviewing-spec Phase 5 대칭)로 재작성.
```

- [ ] **Step 5: README "Principles Instantiated" AP2 한 줄**

`README.md` line 80 (Anti-pattern 회피 섹션의 `- **AP2 (Polite stop)** — ...` 줄) **끝**에 한 문장 추가:

```markdown
 interview→brainstorming Step B도 대칭 proceed 게이트(①/compact 후 brainstorming / ②바로 / ③brief만 종료) — 같은 두 가드(AP2 + cross-compact AC19/AC21) 적용, `approve_handoff.sh` 미호출(brief는 막 검증됨, 하류/SessionEnd가 cleanup) (v0.13.0).
```

- [ ] **Step 6: readme-sync 테스트 green 확인**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh; echo "EXIT=$?"`
Expected: 모든 assert ✓ (plugin.json 0.13.0 + CHANGELOG [0.13.0] ISO date + no-XX + README keyword 3개), `EXIT=0`.

- [ ] **Step 7: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json \
        plugins/spec-distill/CHANGELOG.md \
        plugins/spec-distill/tests/test_readme_sync.sh \
        plugins/spec-distill/README.md
git commit -m "$(cat <<'EOF'
docs(spec-distill): v0.13.0 bump + CHANGELOG + README gate annotation

plugin.json 0.12.0→0.13.0, CHANGELOG [0.13.0] entry, README Flow
다이어그램에 Step B proceed 게이트 표기 + Principles Instantiated AP2
interview-side 한 줄. test_readme_sync.sh 기대 버전 동기화.

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: 전체 회귀 sweep

**Files:** (없음 — 실행/검증만)

- [ ] **Step 1: spec-distill 핵심 .sh 테스트 sweep**

Run:
```bash
for t in test_conducting_interview_stage test_conducting_interview_internal \
         test_brainstorming_entry test_readme_sync test_reviewing_spec_design_only \
         test_handoff_compact_chain test_approve_handoff; do
  echo "=== $t ==="; bash "plugins/spec-distill/tests/$t.sh" >/dev/null 2>&1 && echo PASS || echo FAIL
done
```
Expected: 전부 `PASS`. (Step B 재작성은 reviewing-spec/approve_handoff 경로와 독립 — `test_handoff_compact_chain`/`test_approve_handoff`/`test_reviewing_spec_design_only`는 무변경 green.)

- [ ] **Step 2: python hook 테스트 회귀 (`-m unittest`)**

Run (reference: test runner 메모 — `-m unittest`로만, 직접 실행 금지):
```bash
cd plugins/spec-distill/tests && python3 -m unittest test_hook_output_schema -v 2>&1 | tail -5; cd - >/dev/null
```
Expected: `OK` (design-doc + interview/-exclusion 회귀 — hook 무변경이라 영향 없음). `test_session_end_cleanup`도 동일하게 무영향.

- [ ] **Step 3: drafting-spec / 잔존 참조 부재 확인**

Run: `grep -rn 'drafting-spec' plugins/spec-distill/skills/conducting-interview/SKILL.md; echo "rc=$?"`
Expected: 매칭 없음 (`rc=1`) — AC10 보존.

- [ ] **Step 4: 깨끗한 트리 확인 (worktree drift 방어)**

Run: `git -C /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+interview-compact-handoff status --porcelain && git log --oneline -3 && git branch --show-current`
Expected: clean(또는 의도된 변경만), 최근 2 커밋이 Task 1·2, branch가 워크트리 브랜치. (git-ignored symlink·`.git/info/exclude` 누출 없음 — reference 메모.)

---

## Self-Review (spec 대조)

- **AC20** — Task 1 Step 1이 `AskUserQuestion`·세 옵션 라벨·verbatim `/compact` grep assert 추가, Step 3이 B-2 게이트 + B-3 ① verbatim 명령으로 충족. ✓
- **AC21** — (i) mechanical: Task 1 Step 1 `grep -cE "턴 종료|다음 턴" ≥ 1`. (ii) 리뷰 레이어: B-3 ① 블록 안에 '턴 종료(STOP)' + '같은 턴에서 brainstorming 호출하지 말 것' + '다음 턴 = 사용자 트리거' 공존 — spec-reviewer persona가 판정(test로 불가, 설계 §6 명시). ✓
- **AC22** — Task 1 Step 1 polite-stop 패턴 assert + B-4 AP2 단락("polite stop", "silent 종료 금지"). ✓
- **AC23** — 기존 `superpowers.*(부재|없).*advisory` assert 유지 + B-1 부재 bullet을 one-line으로 보존(레이아웃 제약 명시). 리뷰 레이어: 게이트가 B-2(가용 분기)에만, B-1(부재)은 advisory+STOP뿐. ✓
- **AC24** — 기존 `optional|선택` 유지 + 옵션 ③ `brief만 종료` 라벨 grep(AC20 블록에 포함). 리뷰 레이어: ③이 B-2 게이트 옵션이며 handoff 비강제 종료 경로. ✓
- **§8 Files to Modify 5파일** — 전부 task에 매핑(SKILL.md/test_conducting/plugin.json/CHANGELOG/README) + 설계 §9가 예고한 `test_readme_sync.sh` 버전 동기화 추가. ✓
- **No placeholders** — 모든 step에 실제 grep 패턴·교체 markdown·명령·기대 출력 포함. `<brief-path>`/`<file>`은 SKILL.md 산문 안의 런타임 치환 토큰이지 plan placeholder가 아님. ✓
- **버전 일관성** — plugin.json/CHANGELOG/test_readme_sync 모두 `0.13.0`로 정합. ✓

## Execution Handoff

이 작업은 워크트리 `feature/interview-compact-handoff`에서 진행하며, 산출물이 markdown skill + bash 테스트로 작고 순차 의존(Task 1 → 2 → 3)이라 **Inline Execution**(superpowers:executing-plans)이 적합합니다 — 단, 사용자가 task별 리뷰를 원하면 Subagent-Driven도 가능합니다. (Subagent-Driven 선택 시: subagent에게 Edit 지시마다 워크트리 절대경로를 명시하고 매 커밋 후 branch/clean-tree를 verify할 것 — reference 메모 [[feedback_subagent_worktree_path_emphasis]].)
