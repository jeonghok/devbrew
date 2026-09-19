---
name: remove-agent-transparency
type: design
created_at: 2026-09-20
source_interview: 없음 — /brainstorming 직접 진입. 사용자 결정은 「결정 기록」 절이 정본이다
next_phase: superpowers:writing-plans
---

# agent-transparency 플러그인 제거 — 애초에 없던 상태로 · Design

> 지우는 것은 플러그인 디렉토리 하나가 아니라, 그 플러그인 때문에 리포의 다른 곳에 생긴 줄 전부다.
> 이력은 이력으로 남기고, 흔적은 없앤다.

## Handoff Context

**TL;DR** — `plugins/agent-transparency/` 와 마켓플레이스 항목을 지운다. 그리고 이 플러그인 **때문에** 리포의
다른 곳에 생긴 줄 일곱 자리(T1–T7)를 이 플러그인이 없던 상태로 되돌린다. 이력 문서는 건드리지 않는다.
남는 플러그인의 파일은 하나도 편집하지 않으므로 버전 bump·CHANGELOG 는 없다.

**Implicit context** —
(1) 사용자 요청 원문: 「agent-transparency 플러그인을 제거하자」. 이유는 D1(안 쓴다 · 무게 감축).
(2) 판정 기준은 D3 의 사용자 원문 「어떤게 가장 없던 상태 디폴트로 원복하는거야?」다. 흔적은 "이 플러그인을
**이름으로 부르는** 줄"이 아니라 "이 플러그인 **때문에 생긴** 줄"이다. 이름이 박히지 않은 흔적(T3 정규식 갈래,
T7 하한 값)은 개념 별칭 grep 에 걸리지 않고 출생 커밋 추적(`git log -S`)으로만 드러났다.
(3) 작업 위치: 브랜치 `feature/remove-agent-transparency`, 워크트리
`/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/remove-agent-transparency`, base `84222ee1`(#157 머지).
메인 체크아웃(`feature/framing-intent-drift`, PR #158)은 동시 세션이 편집 중이라 **건드리지 않는다**. #158 은 이
설계가 고치는 파일과 겹치지 않고 T7 의 코퍼스 수도 바꾸지 않는다(실측).
(4) 영향 측정은 끝났다 — 버리는 워크트리에서 base 에 삭제만 적용하고 스위트 252개를 전후로 비교했다.
원자료는 job 임시 디렉토리 `/Users/jeonghokim/.claude/jobs/f7a2563a/tmp/`(`run_all.sh` · `analyze.py` ·
`baseline/` · `after/` · `diff-summary.txt` · `sweep-after.txt`)에 있고 job 이 지워지면 사라진다. 러너는
「Verification Plan」 2 로 재구성할 수 있다.
(5) 이 문서는 인터뷰 없이 쓰였다. design-doc 프로필의 층 1 정답 출처(브리프 §2)가 없으므로 「결정 기록」이
그 자리를 대신한다.
(6) plan 이 정할 것은 문서 끝 `### Deferred to plan` 에 모여 있다.

## Goal

리포의 살아 있는 표면을 agent-transparency 가 devbrew 에 존재한 적 없는 상태로 되돌린다.

## Context / Why

**쓰이지 않는다.** 로컬 `~/.claude/settings.json` 의 `enabledPlugins` 에 없고 `installed_plugins.json` 에도 기록이
없다. 캐시 `~/.claude/plugins/cache/devbrew/agent-transparency/`(0.3.2 · 0.4.0, 1.0M)만 고아로 남아 있고,
A/B 산출물 디렉토리 `~/.claude/agent-transparency-ab/` 는 존재하지 않는다.

**그런데 유지비는 든다.** 34 파일(output style · command · skill · agent · 준비 스크립트 각 1, 나머지는
테스트·A/B 하니스·픽스처·문서)이 `plugins/*` 글롭을 쓰는 공용 락들에 계속 잡힌다. agent 20 중 1, dispatch
자리 22 중 1이 이 플러그인 몫이다.

**이 플러그인이 유일한 실례인 구조가 둘 있다.** output style 컴포넌트와 frontmatter `agent:` dispatch 표기다.
저술 가이드와 dispatch 락이 그 실례에 맞춰 늘어나 있었다.

**측정한 영향 범위** (base `84222ee1` 에 삭제만 적용):

| 종류 | 자리 |
|---|---|
| 새로 RED | `shared/tests/test_plugin_root_no_cwd_fallback.sh:472` 코퍼스 하한 `≥30` — 31 → 29 |
| GREEN 인 채 거짓이 됨 | `docs/plugin-authoring.md:24` · `:49–55`, `shared/tests/test_dispatch_disposition.sh:143–145`, `tools/adjudication/check_slots.py:26` · `:46` |
| GREEN 인 채 아무것도 안 잼 | `shared/tests/test_dispatch_disposition.sh:85` 의 `agent:` 갈래 — 코퍼스 유일 실례가 `briefing-current-state/SKILL.md:6` |
| 측정 뒤 발견 | `tools/adjudication/check_names.py:19` docstring 이 위 정규식을 글자 그대로 인용 |
| 선재 RED (전후 동일) | 7 파일 — 실패 케이스 집합과 파일별 실패 줄 수가 같다. 목록은 「Verification Plan」 1 |
| 모델 호출 | claude/codex stub 호출 0 |

## Goals

- **G1.** 플러그인 디렉토리와 마켓플레이스 항목을 지운다.
- **G2.** 이 플러그인 때문에 생긴 줄 일곱 자리(T1–T7)를 없던 상태로 되돌린다.
- **G3.** 스위트에 새 실패가 0이다.
- **G4.** 제거 뒤 살아 있는 표면(LIVE)에 이 플러그인의 개념 별칭이 0건이다.

## Non-goals

- **이력 문서.** 각 플러그인 `CHANGELOG.md`, `docs/archive/**`, `docs/audits/**`,
  `docs/superpowers/{specs,plans,interview}/**` 는 과거에 참이었던 서술이다. 특히
  `docs/superpowers/specs/2026-08-05-agent-transparency-design.md` 는 **제자리에 그대로** 둔다 —
  `shared/tests/fixtures/seamprobe/MEASUREMENT.md:22` · `:178–184` 가 이 문서를 경로와 줄 번호로 인용한다.
  옮기면 경로가 깨지고, 상단에 "제거됨" 배너를 달면 줄 번호가 밀려 인용이 조용히 어긋난다.
- **락의 개발 이력 서술.** `test_dispatch_disposition.sh:6–8`(「5표기 중 1개만」, 「표기 ②④를 놓쳐 18 중 16」)과
  `:101`(「A①(17 != 18)」)은 그 락을 만들 때의 사실이다. 고쳐 쓰면 이력의 날조다.
- **리포 전역 스윕이 남긴 변경.** 이 플러그인을 함께 건드린 스윕 커밋(모델 키 제거 `eef761e0`, UTF-8 명시
  `8443b59b`, `tools:` 어순 통일 `e359c841` 등)이 다른 파일에 남긴 변경은 이 플러그인과 무관하다. 원복은 커밋
  revert 가 아니라 "이 플러그인 때문에 생긴 줄"의 삭제다.
- **도출값만 줄어드는 락.** agent 수 20→19, dispatch 22→21, 코퍼스·단언 수 등은 하드코딩이 아니라 도출이라
  고칠 것이 없다.
- **`plugins/quality-gates/tests/test_codex_runner_no_effort_pin.sh:69` 의 `≥4`.** 제거 뒤 플러그인 디렉토리가
  5 → 4 가 되어 여유가 0이지만 그대로 둔다. 하한이 현재 수와 같다는 것은 하나라도 더 사라지면 즉시 알린다는
  뜻이다. 이 값은 이 플러그인 때문에 생긴 것도 아니다.
- **루트 `README.md` 의 선재 stale 플러그인 표**(원래 quality-gates · project-init 만 있음).
- **리포 밖 정리.** 고아 캐시 삭제와 메모리 갱신은 머지 후 사용자에게 제안만 한다.

## Constraints

- **C1.** 메인 체크아웃을 건드리지 않는다. 모든 편집·실행은 위 워크트리의 절대경로로 한다.
- **C2.** 삭제와 흔적 정리는 **한 커밋**이다. 중간 상태가 RED 이기 때문이다 — T3 만 먼저 지우면 이 플러그인의
  처분 앵커가 짝을 잃어 축 A① 가 22 ≠ 21 로, 플러그인만 먼저 지우면 T7 하한이 RED 다.
- **C3.** 남는 `plugins/*` 파일을 편집하지 않는다. 편집 대상은 `.claude-plugin/` · `docs/` · `shared/` · `tools/`
  뿐이다. plan 이 `plugins/*` 편집이 필요하다고 판명하면 그 플러그인은 같은 커밋에서 bump 한다.
- **C4.** 이력은 고쳐 쓰지 않는다.
- **C5.** 흔적의 판정 근거는 **출생 원인**이다 — 출생 커밋(`git log -S`)이나 설계 문서의 전수 조사로 이 플러그인이
  원인임을 댈 수 있어야 한다. 이름이 박혀 있다는 것만으로는 흔적이 아니고(이력일 수 있다), 이름이 없다는 것만으로
  흔적이 아닌 것도 아니다(T3 · T7).

## 설계 (Architecture)

### 1. 삭제

- `plugins/agent-transparency/` 전체(34 파일).
- `.claude-plugin/marketplace.json` 의 `agent-transparency` 객체와, 앞 객체(`plugin-audit`) 뒤의 쉼표.

### 2. 흔적 일곱 자리 — 없던 상태로

| # | 자리 | 출생 | 지금 | 없던 상태 |
|---|---|---|---|---|
| T1 | `docs/plugin-authoring.md:49–56` output style 절(도입 줄 · bullet 셋 · 「output style 은 subagent 에 닿지 않는다」 단락과 사이 빈 줄) | `8303cc24` — 이 플러그인 PR 이 추가 | 삭제된 경로로 가는 링크 + 리포에 사례 없는 컴포넌트 설명 | 절 전체 삭제. 앞 단락(`plugin-dev` 문법·정책)과 뒤 `**Merge 전:**` 단락 사이에 빈 줄 하나 |
| T2 | `docs/plugin-authoring.md:24` model 재량 문단의 예시 목록 | `df47c49a` | `smoke-probe`, `transcript-reader`, `pr-understanding-builder` | `transcript-reader` 를 빼고 둘 |
| T3 | `shared/tests/test_dispatch_disposition.sh:85` `NOTATION` 의 `\|^\s*agent:\s` 갈래 | `8b07f9f3` — 설계 `2026-08-22-subagent-adjudication-contract-design.md:84` 의 표기 전수 조사 ④. 그 유일 실례가 이 플러그인 | 실례 0 — 아무것도 재지 않는다 | `re.compile(r'subagent_type:\|agentType:\|Agent\(')` |
| T4 | 같은 파일 `:142–145` 「아래」 방향의 근거 문단(앞의 빈 `#` 줄 포함) | `f835f31f` | 삭제된 파일을 근거로 인용 | 네 줄 삭제. 규칙 자체는 `:137–138` 에 그대로 남는다 |
| T5 | `tools/adjudication/check_names.py:19` docstring 의 표기 필터 인용 | T3 의 글자 그대로 사본 | `^\\s*agent:` 포함 | T3 와 같은 세 표기만 인용 |
| T6 | `tools/adjudication/check_slots.py:26` 「20 개 agent」, `:46` `transcript-reader.inventory` bullet | 전수 스윕이 이 플러그인의 agent 를 셈 | 없는 agent·스크립트를 분류 | 「19 개 agent」, bullet 삭제 |
| T7 | `shared/tests/test_plugin_root_no_cwd_fallback.sh:472` 코퍼스 하한 `-ge 30` | `aff6a8ee` — 코퍼스 31(이 플러그인의 `briefing-current-state/SKILL.md` · `commands/standup.md` 포함)에 여유 1 | 29 → RED | `-ge 28` — 29 에 원저자와 같은 여유 1 |

### 3. 불변인 것

- dispatch 락의 **위치 규칙**(앵커는 dispatch 줄 «아래» `WINDOW` 줄 안)은 그대로다. 근거 문단만 사라진다 — 규칙은
  축 A② 본문(`:137–138`)이 이미 선언한다.
- dispatch 락의 **∀ 도출**(`ZERO_AGENTS`)은 그대로다. T3 이후에도 frontmatter `agent:` 로만 불리는 새 agent 는
  dispatch 0건으로 RED 가 된다(「알려진 한계」 참고).

## Acceptance Criteria

- **AC1.** `git ls-files plugins/agent-transparency` 가 0줄이다.
- **AC2.** `.claude-plugin/marketplace.json` 이 JSON 으로 파싱되고, `plugins[].name` 이 정확히
  `quality-gates, project-init, spec-distill, plugin-audit`(이 순서)다.
- **AC3.** T1–T7 이 §2 표의 「없던 상태」 열과 일치한다.
  - T1: `docs/plugin-authoring.md` 에 `output style` · `output-styles` · `keep-coding-instructions` ·
    `force-for-plugin` 이 0건이고, `**Merge 전:**` 단락이 남아 있다.
  - T2: 24행 문단에 `transcript-reader` 가 없고 `smoke-probe` · `pr-understanding-builder` 는 있다.
  - T3: `NOTATION` 정규식 리터럴이 정확히 `subagent_type:|agentType:|Agent\(` 다.
  - T4: 파일에 `briefing-current-state` 가 0건이고, 축 A② 의 「바로 아래」 규칙 문장은 남아 있다.
  - T5: `check_names.py` 에 `agent:` 표기 인용이 0건이고, 나머지 세 표기 인용은 남아 있다.
  - T6: `check_slots.py` 에 `transcript-reader` · `prepare_standup` 이 0건이고 「19 개 agent」가 있다.
  - T7: 하한 리터럴이 `-ge 28` 이다.
- **AC4.** 개념 별칭 `git grep -n -I -i` 가 LIVE 에서 0건이다. LIVE 는 이력 분류(`**/CHANGELOG.md`,
  `docs/archive/**`, `docs/audits/**`, `docs/superpowers/{specs,plans,interview}/**`) 밖의 모든 추적 파일이다.
  별칭: `agent-transparency` · `agent_transparency` · `transcript-reader` · `briefing-current-state` ·
  `prepare_standup` · `standup` · `ab_gate` · `ab_judge` · `ab_seal` · `ab_driver` · `AT_ORACLE` ·
  `comprehension debt` · `comprehension-debt` · `이해부채` · `output-styles` · `output style` ·
  `force-for-plugin` · `keep-coding-instructions`.
- **AC5.** 전체 스위트 전후 대조에서 base 대비 **새 실패 케이스 집합이 공집합**이고, 파일별 실패 줄 수가
  같다(선재 RED 7 파일 포함). claude/codex stub 호출은 0이다.
- **AC6.** T7 하한의 양성 대조: 커밋 뒤, 락의 코퍼스 글롭 안 마크다운 2개를 임시로 지워 27개로 만들면 그
  단언이 ✗ 이고, 복원하면 ✓ 다. 복원은 `git checkout HEAD --` 로 하고 `git diff HEAD` 가 비었음을 확인한다.
- **AC7.** 제거 뒤 dispatch 락의 인쇄값이 `PRINT_2_dispatch 21` · `PRINT_3_anchors 21` 이고 `ZERO_AGENTS` 가
  빈 값이다 — T3 이 이 플러그인 밖의 dispatch 를 하나도 잃지 않았다는 증거다.

## Files to Modify

| 동작 | 파일 |
|---|---|
| 삭제 | `plugins/agent-transparency/**` (34) |
| 편집 | `.claude-plugin/marketplace.json` |
| 편집 | `docs/plugin-authoring.md` (T1 · T2) |
| 편집 | `shared/tests/test_dispatch_disposition.sh` (T3 · T4) |
| 편집 | `shared/tests/test_plugin_root_no_cwd_fallback.sh` (T7) |
| 편집 | `tools/adjudication/check_names.py` (T5) |
| 편집 | `tools/adjudication/check_slots.py` (T6) |
| 추가 | 이 문서, 그리고 writing-plans 의 plan |

## Verification Plan

1. **base 확인과 baseline.** 착수 시 `git rev-parse origin/main` 이 `84222ee1` 이면 측정 때의 baseline 을 쓴다.
   움직였으면 `git merge-tree` 로 충돌을 보고, 새 base 에서 baseline 과 T7 코퍼스 수를 다시 잰다(29 가 아니면
   하한 = 새 수 − 1). base `84222ee1` 의 선재 RED 7 파일:
   `plugins/quality-gates/tests/harness/test_skill_orchestration_behavior.sh` ·
   `plugins/quality-gates/tests/test_codex_backward_compat.sh` · `plugins/quality-gates/tests/test_runner_adapters.sh` ·
   `plugins/quality-gates/tests/test_findings_parser.sh` · `plugins/spec-distill/tests/test_no_write_matcher_hooks_repo.sh` ·
   `plugins/spec-distill/tests/test_hook_output_schema.py`(NG9) · `shared/tests/test_assert_behavior.sh`(rc 0, 의도된 ✗).
2. **러너(측정과 동일).** 모두 워크트리 루트에서 돈다.
   - `.sh` — `bash <file>`. 대상은 추적 파일 중 `^(shared/tests|plugins/[^/]+/tests)/(harness/)?test_[^/]*\.sh$`.
     실패 줄 패턴 `✗|^\s*FAIL\b|^\s*not ok\b`.
   - `.py` — 파일마다 `python3 -m unittest discover -v -s <tests dir> -t <tests dir> -p <file>`. 패턴
     `^(FAIL|ERROR): `.
   - `.mjs` — `node --test --test-reporter=tap <file>`. 패턴 `not ok N -`.
   - 환경 — `PATH` 맨 앞에 `claude` · `codex` stub(인자를 로그에 적고 `exit 97`), `PYTHONDONTWRITEBYTECODE=1`,
     UTF-8 locale, 스위트마다 별도 `TMPDIR`, stdin `/dev/null`.
   - 제외 — `plugins/quality-gates/tests/spike/test_codex_json_extraction.sh`(추적 픽스처를 바꾸는 수동 spike).
3. **정적·도출 확인** — AC1 · AC2 · AC3 · AC4 · AC7.
4. **양성 대조** — AC6.
5. **구현 리뷰** — `/qg review` 1회(D5, Law 2).
6. **이 문서** — `spec-distill:reviewing-spec` 으로 리뷰한다.

## Rejected Alternatives

- **마켓플레이스 항목만 삭제(비공개).** 코드가 `plugins/*` 에 남아 공용 락이 계속 세고 유지해야 한다 — D1 의
  무게 감축을 이루지 못한다.
- **deprecation 창 먼저.** CLAUDE.md 의 one-minor 창은 v1.0.0 이상의 CHANGELOG 규칙 아래 있다. 이 플러그인은
  0.4.0 이고 활성 사용자가 없다.
- **`agent:` 갈래 유지 + 「실례 0」 공시**(처음 추천). 이 플러그인이 없던 세계의 락에는 이 갈래가 없다(D3 · D4).
- **`agent:` 갈래에 합성 fixture.** 락에 fixture 모드를 새로 들여야 해 범위가 커지고, 없던 상태 기준과도 어긋난다.
- **output style 절 보존**(플랫폼 지식이라서). 이 플러그인 PR 이 추가한 절이다(D4). 그 지식은 이력 spec 과 git
  이력에 남는다.
- **이력 spec 을 `docs/archive/specs/` 로 이동, 또는 상단에 "제거됨" 배너.** 이동은 `MEASUREMENT.md` 의 경로
  인용을, 배너는 줄 번호 인용을 깬다. 얻는 것이 없다.
- **하한 `≥25`**(처음 안). 원저자의 규칙(현재 수 − 1)과 다르다. 없던 상태 기준이면 29 − 1 이다.

## 알려진 한계

- **T3 이후 frontmatter `agent:` dispatch 의 가시성.** 이 표기로만 불리는 새 agent 는 dispatch 0건이 되어
  `ZERO_AGENTS` 로 RED — 드러난다. 그러나 **다른 표기로도 불리는** agent 를 어떤 skill 이 frontmatter `agent:` 로
  추가 호출하면, 그 자리는 dispatch 로 세어지지 않아 처분 앵커 검사를 조용히 빠져나간다. 이 플러그인이 없던
  세계와 같은 상태다. 그 표기를 다시 들이는 PR 이 `NOTATION` 에 갈래를 더해야 한다 — 락 머리말 6–9행의
  「열거는 fail-open」 경고가 그 위험을 이미 말한다.
- **output style 지식이 저술 가이드에서 사라진다.** 필요해지면 이력 spec 과 `8303cc24` 에서 찾는다.
- **측정 원자료는 job 임시 디렉토리에 있다.** job 이 지워지면 사라지며, 러너는 「Verification Plan」 2 로
  재구성한다.
- **선재 RED `test_findings_parser.sh`** 는 측정 locale(`en_US.UTF-8`) 탓으로 추정된다(이전 baseline 의
  `C.UTF-8` 에서는 GREEN). 전후가 같아 판정에는 영향이 없다.

## Concrete Next Action

이 문서를 `spec-distill:reviewing-spec` 으로 리뷰하고 그 승인 게이트를 거친 뒤 `superpowers:writing-plans` 로
간다. 입력은 이 문서(`docs/superpowers/specs/2026-09-20-remove-agent-transparency-design.md`)다.

## 결정 기록

사용자 결정(2026-09-19~20, 이 세션):

| # | 질문 | 결정 |
|---|---|---|
| D1 | 제거 이유 | 안 쓴다 · 무게 감축 — 교훈 회수는 최소로 |
| D2 | 경로 분류 | architectural(선례 #153 · #154) — 사용자 이의 없음 |
| D3 | `agent:` 갈래를 어떻게 둘지 | 사용자 원문 「어떤게 가장 없던 상태 디폴트로 원복하는거야?」 — 판정 기준을 "이 플러그인 때문에 생긴 줄"로 확정 |
| D4 | 설계 §1 (D3 기준 개정판) | 없던 상태로 — output style 절 · `agent:` 갈래 · 「아래」 근거 문단 삭제, 하한 `≥28`, 이력 문서 무수정 |
| D5 | 설계 §2 | 승인 — 별도 워크트리, 삭제와 흔적 정리를 한 커밋으로, AC, `/qg review` 1회, bump 없음 |

오케스트레이터가 정하고 사용자에게 알린 것(되돌리려면 괄호 안의 한마디):

| 정한 것 | 근거 |
|---|---|
| T5 추가 — D4 승인 뒤 발견 (「check_names 인용은 두라」) | T3 정규식의 글자 그대로 사본이다. 두면 T3 이 반쪽이 된다 |
| 락 머리말의 개발 이력(`:6–8`, `:101`) 무수정 (「이력도 없던 상태로」) | 그때의 사실이다(C4) |
| 이력 spec 제자리 · 배너 없음 (「archive 로 옮겨라」) | 경로·줄 번호 인용(`MEASUREMENT.md`) |
| 「알려진 한계」의 `agent:` 서술을 채팅 때보다 좁힘 | 채팅에서는 "미래의 `agent:` dispatch 가 빠져나간다"고 했으나, ∀ 도출(`ZERO_AGENTS`) 때문에 그 표기로**만** 불리는 agent 는 드러난다. 빠져나가는 것은 다른 표기로도 불리는 agent 의 추가 호출뿐이다 |

### Deferred to plan

- 구현 커밋의 Conventional Commits type · scope, 그리고 설계 · plan · 구현 커밋의 순서.
- 측정 러너를 job 임시 디렉토리의 `run_all.sh` · `analyze.py` 로 재사용할지 재구성할지.
- T1 삭제 뒤 빈 줄 경계의 정확한 편집 문자열.
- AC6 에서 임시로 지울 마크다운 2개의 선택(T7 락의 코퍼스 글롭 안).
- PR 본문에 적을 사용자 측 영향 — 마켓플레이스를 갱신한 설치자에게서 플러그인이 사라지고, `force-for-plugin`
  output style 도 함께 사라진다.
