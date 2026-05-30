# Spec: quality-gates v2.1.0 — spec을 단일 truth로 instantiate (plan은 구현-방식 hint로 강등)

## 1. Context / Why

`quality-gates`(v2.0.0)는 devbrew의 canonical cycle `spec → plan → implement →
review → verify → compound`에서 **review/verify** 단계를 담당한다. 그런데 코드를
실증 조사한 결과, qg는 **plan은 읽지만 spec은 한 번도 읽지 않는다.** 즉 cycle이
선언하는 위계(spec=truth ⊃ plan=구현 방식)를 qg가 instantiate하지 않고 평탄화했다.

세 가지 근거:

- **spec 발견 메커니즘 부재.** qg가 발견·소비하는 유일한 상류 artifact는 plan
  (`scripts/discover-plan.sh` → `docs/superpowers/plans/`)이다. spec
  (`docs/superpowers/specs/`)을 찾는 `discover-spec.sh` 같은 것이 없다. SKILL.md의
  "spec"은 전부 qg 자신의 설계-스펙 AC 앵커(AC6/AC8)일 뿐 사용자 프로젝트 spec이 아니다.
- **spec/plan 융합.** `agents/test-scope-validator.md:54`가 입력을 문자 그대로
  *"path to the **spec/plan** markdown"* 이라 적어 둘을 교환 가능한 한 덩어리로
  취급한다. 위계가 없다.
- **v2.0.0 이후 plan 연결마저 약화.** `plan-verifier`(구 Gate 1)가 제거되었고,
  codex reviewer의 `<plan_context>` 슬롯은 canonical하게 `/dev/null`(빈 컨텍스트)을
  받는다(`scripts/build_codex_prompt.py:74-77`). 남은 유일한 plan 연결은
  test-scope-validator가 테스트를 "plan items"와 대조하는 것뿐 — 그것도 spec/plan
  융합 상태로.

**핵심 비대칭 (이 작업의 정당화).** v2.0.0이 plan-verify를 제거한 논리는 "artifact는
그게 생산되는 곳(상류)에서 검증된다"였고, plan(파생 체크리스트)에 대해선 맞다. 그러나
spec에 대입하면 동사가 바뀐다: 상류 spec-distill의 `reviewing-spec`이 검증하는 것은
**"spec의 품질"**(명확한가·테스트 가능한가 — 코드 없이 가능, 상류 소관)이지,
**"코드가 spec을 충족하는가"**(코드가 *존재*해야만 가능)가 아니다. cycle에서
`implement` 다음·`merge` 이전 단계는 **review/verify = qg 하나뿐**이므로, qg가 안 하면
"약속(spec AC) ↔ 출하(code)" 루프를 닫는 곳이 한 군데도 없다. 따라서 **plan-verify는
상류와 중복이라 제거가 옳았지만(v2.0.0), spec-conformance는 qg만 닫을 수 있는 비중복
루프**다. 이 비대칭이 본 작업의 근거다.

요청자: 사용자 (2026-05-31, brainstorming 세션). 원하는 결과: 위계 재검토 후 spec을
qg의 truth로 instantiate.

## 2. Goals

- **`scripts/discover-spec.sh` 신설** — `discover-plan.sh`의 거울. best-effort,
  graceful no-op (spec 없으면 조용히 fail-soft). stdout JSON 계약:
  `{"spec_path":"<abs-or-empty>","source":"explicit|project-local|none","reason":"…"}`,
  exit 0(found)/1(not found)/2(invalid input).
- **`test-scope-validator`의 기준선을 plan items → spec Acceptance Criteria로 교체.**
  입력의 융합(`:54`)을 `spec_path`(AC truth, primary) + `plan_path`(보조 hint)로 분리.
  per-file verdict의 cherry-pick-suspicion 판정 기준을 "spec AC scope에 orthogonal"로
  재정의.
- **`ac_coverage` advisory 출력 블록 신설** — AC별 covered/uncovered + covered_by
  테스트 ref. **advisory only — Runtime gate를 block하지 않는다** (기존 validator
  posture 불변).
- **codex `<plan_context>` 슬롯을 `<spec_context>`로 부활** — 현재 `/dev/null`로 죽어
  있는 슬롯에 spec의 AC 섹션(추출)을 주입. Review gate reviewer가 spec-인지하게 됨.
- **plan을 구현-방식 hint로 강등(제거 아님).** `discover-plan.sh`는 byte-identical로
  유지(v2.0.0이 유지한 것과 일관). plan은 spec 없을 때의 fallback scope hint이자
  spec 있을 때의 보조 hint.
- **best-effort 안전 속성:** spec 부재 시 qg는 v2.0.0과 **byte-identical** 동작
  (회귀 위험 구조적 0). 신능력은 spec 존재 시에만 활성.
- **kill switch** `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1` — AC-coverage facet만 끄고
  validator는 plan-기반으로 계속.
- SemVer `v2.0.0 → v2.1.0` (새 surface = spec discovery + ac_coverage, 하위호환).

## 3. Non-goals / Out-of-Scope

- **plan-verify(구 Gate 1) 재도입 아님.** 제거된 plan-verify는 block형 정적
  체크박스 매칭이었다. 본 작업은 advisory gap-surfacing이며 절대 block하지 않는다.
  이건 v2.0.0 되돌리기가 아니라, v2.0.0이 건드리지 않은 직교적 버그(spec이 애초에
  truth였던 적이 없음)의 수정이다.
- **`discover-plan.sh` 제거/변경 아님** — byte-identical 유지. plan은 hint로 존속.
- **새 gate·새 agent 없음** — 기존 `test-scope-validator`(Runtime gate)를 재조준,
  기존 codex 경로(Review gate) 재활용. owner는 test-scope-validator 하나.
- **전용 spec-conformance reviewer 신설 아님 (Approach B 기각, §9).** "diff가 AC를
  충족하는가"의 정적 판정은 noisy + plan-verify 정적-매칭 재림 위험.
- **spec 품질 검증 아님** — "spec이 명확/완결한가"는 상류 spec-distill `reviewing-spec`
  소관. qg는 오직 *conformance*(코드/테스트가 AC를 충족하는가)만 다룬다.
- **새 P#/AP# 신설 없음, 철학 문서 편집 없음** — 본 작업은 철학이 이미 선언한 C66
  (Linked Artifact Flow) + Law 1의 instantiation이지 신규 원칙이 아니다
  (devbrew designs default to lightness). 인스턴스화 기록은 README "Principles
  Instantiated"가 담당(Law 3 discoverability).
- **Law 2 격리 약화 아님** — 모든 reviewer agent의 `disallowedTools` frontmatter
  유지. spec 읽기는 read-only.
- **hard gate(block) 아님** — spec 발견은 fragile(아무 브랜치에서나 수동 호출)하므로
  advisory만 정당. spec 없으면 no-op.
- canonical cycle 문구·discover-plan 인프라·Review/Runtime 2-gate 구조는 불변.

## 4. Constraints

- **devbrew Plugin Shape 준수.** `plugin.json` version bump을 같은 커밋에;
  `CHANGELOG.md` v2.1.0 항목; README "Principles Instantiated"에 C66 추가.
- **Korean-primary 문서 컨벤션.** 영어는 식별자/고유명사/원문 인용/번역 어색한
  기술 용어에만.
- **Law 2 격리 불변.** reviewer agent의 `disallowedTools: [Write, Edit, MultiEdit,
  NotebookEdit]` 유지. persona 약화가 아님 (오히려 기준선 강화).
- **best-effort / graceful degradation + loud logging.** spec 부재·AC 섹션 부재·
  파싱 실패는 capability를 downgrade하고 crash하지 않으며, 사용자가 출력에서 fallback이
  돌았음을 알 수 있어야 한다 (loud log).
- **advisory invariant.** ac_coverage·spec-conformance는 어떤 경우에도 Runtime gate
  verdict를 block하지 않는다.
- **discover-spec.sh는 repo root에서 호출.** project-local 소스를 `$PWD` 기준 해석
  (discover-plan.sh와 동일 계약·헤더 노트).

## 5. Acceptance Criteria

각 AC는 grep/파일 존재/테스트로 기계적으로 검증 가능하다. "plugin source"는
`plugins/quality-gates/` 하위에서 `tests/`·`CHANGELOG.md` 제외를 의미한다.

**discover-spec 신설**

1. `scripts/discover-spec.sh`가 존재하고 실행 가능하며, 단일 줄 JSON
   `{"spec_path":…,"source":…,"reason":…}`을 stdout에 emit한다. exit 0(found)/
   1(not found)/2(invalid input). 검증: 신규 `tests/test_discover_spec.sh` green.
2. 우선순위가 `--spec <path>`(explicit, 없으면 fallback 안 함) → `$PWD/docs/superpowers/specs/*.md`
   (project-local) → none 순이다. **선택 휴리스틱:** "Acceptance Criteria 섹션을
   가진 파일"만 적격(`grep -qE '^#+ .*Acceptance Criteria'`); 적격 파일 중 최신
   mtime. AC 섹션 없는 .md는 부적격(plan의 "체크박스 없으면 부적격"과 대칭).
   legacy-global 소스는 없다(spec은 프로젝트 artifact). 검증: test_discover_spec.sh의
   fixture 케이스(explicit/project-local/none/AC-eligibility/mtime-tiebreak).
3. `scripts/discover-plan.sh`가 **byte-identical**로 유지된다:
   `git diff --quiet HEAD -- plugins/quality-gates/scripts/discover-plan.sh` → exit 0.
   `tests/test_discover_plan.sh`가 **무수정**으로 green.

**test-scope-validator 재조준**

4. `agents/test-scope-validator.md`의 입력 선언에서 융합 문자열
   `spec/plan markdown`이 사라지고 `spec_path`·`plan_path`가 **별도 줄**로 분리된다.
   검증: `grep -c 'spec/plan markdown' agents/test-scope-validator.md` → `0`;
   `grep -c 'spec_path' agents/test-scope-validator.md` ≥ `1` AND
   `grep -c 'plan_path' agents/test-scope-validator.md` ≥ `1`.
5. spec_path가 주어지면 validator가 `ac_coverage:` 블록을 emit하고, 부재 시 생략하고
   plan-기반 per-file verdict로 fallback한다 (Semantic — behavior 테스트).
   `ac_coverage`의 각 항목은 `id`(AC#)·`status`(covered|uncovered)·`covered_by`(테스트
   ref 리스트)를 갖는다. note 줄에 "advisory only — does not block" 포함.
6. per-file verdict의 cherry-pick-suspicion 정의가 "spec AC scope에 orthogonal"을
   참조한다 (plan scope 단독 아님). 검증: persona에 spec AC 기준 문구 존재
   (`grep -ciE 'acceptance criteria|spec AC' agents/test-scope-validator.md` ≥ `1`).

**codex 슬롯 부활**

7. `scripts/build_codex_prompt.py`가 `<spec_context>`/`{{SPEC_AC}}`/arg
   `<spec_ac_file>`를 사용하고 `<plan_context>`/`{{PLAN_SUMMARY}}`/`<plan_summary_file>`가
   없다. 검증: `grep -c 'spec_context\|SPEC_AC' scripts/build_codex_prompt.py` ≥ `1`;
   `grep -c 'plan_context\|PLAN_SUMMARY' scripts/build_codex_prompt.py` → `0`.
   `:74-77`의 "/dev/null canonical(plan)" 주석이 "spec AC가 canonical context"로 갱신.
8. `scripts/run_codex_reviewer.sh`가 추출된 spec AC(또는 spec 부재 시 `/dev/null`)를
   build_codex_prompt.py에 전달한다. 검증: test_build_codex_prompt.sh 확장 케이스 green.

**SKILL 배선**

9. `SKILL.md` Arguments에 `spec_path`(default `auto` = discover-spec.sh)가 문서화되고,
   Runtime gate의 test-scope-validator dispatch 블록 내 10줄 안에 `spec_path:` 줄이
   있다 (test-scope-validator dispatch 계약). Review gate codex 경로가 spec AC를 주입한다.
   검증: `grep -cE 'spec_path' skills/quality-pipeline/SKILL.md` ≥ `2`.

**degradation & kill switch**

10. `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1`이면 spec이 존재해도 no-spec 경로를 강제
    (ac_coverage 생략, plan-기반 계속). 검증: kill-switch 테스트 green +
    `grep -rc 'DEVBREW_QG_DISABLE_SPEC_CONFORMANCE' plugins/quality-gates` ≥ `1`.
11. spec 부재 시 validator·codex가 loud log를 emit하고 v2.0.0 동작으로 fallback한다.
    검증: behavior 테스트에서 no-spec 경로의 log 라인 단언.

**메타 · 철학 · 격리**

12. `README.md`에 "Spec Discovery Sources" 절이 있고(Plan Discovery 거울),
    "Principles Instantiated"가 **C66**을 언급한다. 검증:
    `grep -c 'Spec Discovery' README.md` ≥ `1`; `grep -c 'C66' README.md` ≥ `1`.
13. 철학 문서가 **편집되지 않는다**(새 P#/AP# 없음):
    `git diff --quiet HEAD -- docs/philosophy/devbrew-harness-philosophy.md` → exit 0.
14. 모든 reviewer agent가 `disallowedTools` 격리를 유지한다:
    `grep -lE 'disallowedTools' agents/adversarial.md agents/runtime-verifier.md
    agents/security-reviewer.md agents/test-scope-validator.md` → 4개 전부 매칭.
15. `plugin.json` version = `2.1.0`.
16. `CHANGELOG.md`에 `## [2.1.0] — 2026-05-31` 항목이 Added/Changed/Fixed와 함께
    추가된다 (Fixed에 `test-scope-validator.md:54` 융합 해소 명시).

**테스트 (회귀 포함)**

17. 신규 `tests/test_discover_spec.sh` + 확장된 `test_test_scope_validator_behavior.py`·
    `test_build_codex_prompt.sh`가 green. 전체 스위트가 **문서화된 baseline reds 외에
    새 red를 추가하지 않는다** (main의 기존 stale red 8개는 작업 전 baseline 캡처로
    분리 — project 메모리 `project_qg_pre_existing_test_reds` 참조).

## 6. Files to Modify

**신설**
- `scripts/discover-spec.sh` — discover-plan.sh 거울. project-local 소스만(legacy 없음),
  AC-섹션 적격성 + mtime tiebreak. stdout JSON 계약, exit 0/1/2.
- `tests/test_discover_spec.sh` — discover-plan 테스트 거울 + AC-적격성·mtime·exit·JSON·
  no-root-miss 케이스.

**수정**
- `agents/test-scope-validator.md` — 입력 `spec_path`/`plan_path` 분리(`:54` 융합 해소),
  기준 축 spec AC 1차·plan 2차, `ac_coverage` 출력 블록 신설, no-spec fallback + loud log,
  kill switch 분기. `disallowedTools` 불변.
- `scripts/build_codex_prompt.py` — `<plan_context>`→`<spec_context>`,
  `{{PLAN_SUMMARY}}`→`{{SPEC_AC}}`, arg `<plan_summary_file>`→`<spec_ac_file>`,
  `:74-77` 주석 갱신.
- `scripts/run_codex_reviewer.sh` — 추출된 spec AC(또는 spec 부재 시 /dev/null)를 전달.
  **deferred to plan:** AC 섹션 추출 위치(run_codex_reviewer.sh awk vs build_codex_prompt.py
  내부) — AC 섹션만 추출(spec 전체는 prompt bloat).
- `skills/quality-pipeline/SKILL.md` — Arguments에 `spec_path`(default auto), Runtime
  gate dispatch에 `spec_path:` 줄, Review gate codex 경로에 spec AC 주입.
- `README.md` — "Spec Discovery Sources" 절, "Principles Instantiated"에 C66, gate 표.
- `tests/test_test_scope_validator_behavior.py` — ac_coverage 존재(spec)/fallback(no-spec)/
  cherry-pick 기준=spec AC/kill-switch.
- `tests/test_build_codex_prompt.sh` — `<spec_context>` 슬롯 + no-spec /dev/null 경로.
- `.claude-plugin/plugin.json` — version 2.1.0.
- `CHANGELOG.md` — v2.1.0 항목.

**불변(byte-identical)**
- `scripts/discover-plan.sh`, `tests/test_discover_plan.sh`.
- `docs/philosophy/devbrew-harness-philosophy.md` (C66 이미 선언).
- reviewer agent `disallowedTools` frontmatter.

## 7. Verification Plan

AC와 1:1 매핑. devbrew §4.5 세 양식.

- **Mechanical — AC1~AC4, AC6~AC10, AC12~AC16.** grep/파일 존재·부재/`git diff --quiet`
  (AC3·AC13 byte-identical) + 신규 식별자 positive grep + 버전·CHANGELOG.
- **Semantic — AC5, AC11, AC17.** test-scope-validator behavior 테스트(ac_coverage
  emit/fallback), no-spec loud-log 단언, 전체 스위트 green. **작업 전 baseline reds
  캡처 필수**(repo root에서 실행) — main의 기존 8개 stale red와 신규 red 구분
  (메모리 `project_qg_pre_existing_test_reds`).
- **Runtime (행위 검증, non-binding sanity).** (i) spec 있는 브랜치에서 `/qg runtime`
  → 출력에 `ac_coverage` 블록 ≥1회; (ii) spec 없는 브랜치 → fallback loud log
  + v2.0.0과 동일한 per-file verdict, ac_coverage 부재; (iii)
  `DEVBREW_QG_DISABLE_SPEC_CONFORMANCE=1 /qg runtime` → spec 있어도 ac_coverage 부재.
  grep 기반 ACs는 반드시 Mechanical로 판정(smoke가 grep 부재 단언을 대체하지 않음).

## 8. Rejected Alternatives

- **Approach B — Review gate에 전용 spec-conformance reviewer 신설.** diff+AC를
  정적 대조해 "AC 미충족" 판정. 기각: 새 agent(surface 증가) + 정적 "diff가 AC
  충족하는가"는 noisy + v2.0.0이 제거한 plan-verify의 정적-매칭 냄새 재림.
- **Approach C 단독 — spec을 모든 reviewer 공유 context로만.** 전용 verdict 없음.
  기각: "AC 커버리지" 단일 owner 부재 → gap이 새어나감. "한 가지 명확한 목적의 잘
  구획된 단위" 원칙 위반. (단, C의 *codex 슬롯 부활*만 A에 보완으로 흡수 — 죽은
  슬롯 재활용이라 비용 ≈ 0.)
- **plan을 truth로 유지(현상).** plan은 파생 구현-방식이지 진실이 아니다. spec과
  융합한 채 두면 cycle 위계가 계속 평탄화된 채로 남음.
- **hard gate(block) 도입.** spec 발견이 fragile(spec 없는 브랜치 다수)하므로
  block은 false-fail 양산. advisory가 유일하게 정당. (선택지 3 "인간 reviewer
  소관"의 지혜를 posture로 흡수: qg는 gap을 surface, 사람이 판단.)
- **상류(spec-distill/writing-plans)에 위임(선택지 4).** 범주 오류 — 상류는
  코드 부재 시점이라 conformance를 검증할 수 없다(§1 비대칭). 상류는 spec *품질*만,
  qg는 spec *충족도*만.
- **철학 문서 편집 / 새 P# 신설.** C66 + Law 1이 이미 위계를 선언하므로 instantiation
  만으로 충분. design-lightness 준수.
- **`discover-spec.sh`에 legacy-global(`~/.claude/specs`) 소스 추가.** spec은
  프로젝트 artifact(plan과 달리 글로벌 위치 관행 없음). project-local만으로 충분.

## 9. Risks / 의도적 일탈

- **R1 — spec staleness noise.** diff와 무관한 stale spec이 발견되면 ac_coverage가
  무관 AC를 uncovered로 표기. advisory라 block 안 하고 사용자가 판단하므로 수용.
  완화: validator가 diff와 scope 겹치는 AC에 우선 집중(persona 가이드, plan에서 정련).
- **R2 — AC 섹션 파싱 변동성.** brainstorming spec(`## N. Acceptance Criteria` +
  번호 리스트)과 spec-distill spec(`## Acceptance Criteria` + `- **AC1**:`)의 형식
  차이. 완화: 헤더 정규식 `^#+ .*Acceptance Criteria`로 양형 커버, AC 열거는 관대하게
  (파싱 실패 → 빈 acs + note, crash 아님).
- **R3 — codex prompt bloat.** spec 전체 주입 시 ~400줄. 완화: AC 섹션만 추출.
- **R4 — best-effort 오인.** spec 있는데 위치/형식이 비표준이라 미발견 시 사용자가
  "검사됐다"고 오인. 완화: loud log로 "no spec found"를 항상 noisy하게 출력.

## 10. Metadata

- **Author:** 사용자 + Claude (brainstorming 세션)
- **Created:** 2026-05-31 (ISO 8601)
- **Plugin:** `plugins/quality-gates/` v2.0.0 → v2.1.0
- **Parent:** brainstorming 세션 (인자: "Qg 가 spec을 하나의 truth로 plan을 그 구현
  방식으로 이해하고 있는지")
- **Spec version:** 1.0
- **관련 원칙:** C66 (Linked Artifact Flow — qg가 spec→test 커버리지를 역방향 walk),
  Law 1 (verify 시점에 spec=truth 존중), Law 2 (격리 불변), P22 (Cost Awareness — 불변),
  P17 (사용자 주권), devbrew design-lightness (새 P# 없음).

## Handoff Context

*(compact 후 fresh-context writing-plans가 대화 없이 복원할 핵심. /compact 시
이 섹션·Acceptance Criteria·Files to Modify는 보존, 인터뷰 대화·중간 추론은 drop.)*

- **TL;DR:** quality-gates v2.0.0 → **v2.1.0**. qg가 처음으로 **spec을 truth로 read**.
  `discover-spec.sh` 신설(discover-plan 거울, best-effort) + test-scope-validator
  기준선 plan→spec AC 교체 + `ac_coverage` advisory 블록 + codex 죽은 `<plan_context>`
  슬롯을 `<spec_context>`로 부활. plan은 구현-방식 hint로 강등(제거 아님,
  discover-plan.sh byte-identical). **spec 없으면 v2.0.0과 byte-identical fallback.**
- **Implicit context (사용자-locked 결정, 재논의 불필요):**
  - **비대칭이 정당화의 핵심:** plan-verify(상류 중복, 제거 옳음) vs spec-conformance
    (코드 존재해야 가능 → qg만 닫을 수 있는 비중복 루프). 본 작업 ≠ v2.0.0 되돌리기.
  - **advisory only, never blocks.** spec 발견 fragile → hard gate 부적절.
  - **새 gate·agent 없음.** test-scope-validator(owner) 재조준 + codex 슬롯 재활용.
  - **새 P#/AP# 없음, 철학 문서 unchanged.** C66 + Law 1 instantiation. README가
    compounding 기록.
  - **Approach 선택:** A(구조적 owner) + C보완(codex 슬롯 부활). B(전용 reviewer)·
    C단독(owner 없음) 기각.
- **Deferred to plan (writing-plans에서 확정):** ① AC 섹션 추출 위치(run_codex_reviewer.sh
  awk vs build_codex_prompt.py 내부); ② ac_coverage YAML 정확한 스키마/필드명; ③
  discover-spec.sh AC-적격성 정규식 + multi-spec mtime tiebreak 구현; ④ kill-switch
  분기를 SKILL vs agent persona 어디서 평가할지; ⑤ baseline reds 캡처 절차(repo root);
  ⑥ Phase 실행 순서.
