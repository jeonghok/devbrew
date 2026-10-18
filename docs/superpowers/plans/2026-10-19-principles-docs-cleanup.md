# R11 원칙 문서 정리 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 사용자 원칙 여섯을 CLAUDE.md 한 줄 + 철학 문서 이유로 옮기고, CLAUDE.md · 철학 문서 · 플러그인 README 넷의 낡은 개념을 지워 문서를 줄인다.

**Architecture:** 문서만 고친다(플러그인 동작 변경 없음). 원칙 줄은 CLAUDE.md 의 기존 절 안에, 이유는 철학 문서의 기존 원칙(Law 3 · P8 · P23 · P5)에 흡수한다. 지우는 범위는 설계 §3 목록이 전부이고, 지울 줄마다 그 문구를 핀한 락을 grep 으로 찾는다. 원칙 2~6 이 플러그인 동작 자리에 실렸는지는 설계문서의 새 대조표로 남기고, 빈 곳은 그 파일을 잡은 에픽으로 넘긴다.

**Tech Stack:** Markdown · bash 셸 테스트 · python unittest · `tools/suite/run-all.sh`

**Spec:** `docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md`

## Global Constraints

- 정리 전 크기(바이트, `wc -c`): `CLAUDE.md` 15203 · `docs/philosophy/devbrew-harness-philosophy.md` 14876 · `plugins/spec-distill/README.md` 71133 · `plugins/quality-gates/README.md` 58388 · `plugins/project-init/README.md` 8236 · `plugins/plugin-audit/README.md` 9158.
- 크기 기준: CLAUDE.md 는 정리 전 크기 **이하**(≤ 15203). 나머지 다섯은 정리 전보다 **작다**(<). `docs/plugin-authoring.md` · CHANGELOG · 테스트 파일 · 설계문서는 대상이 아니다.
- CLAUDE.md 가 넘치면: 먼저 원칙 다섯 줄을 「무엇을 한다」 + `(철학 P#)` 만 남긴 짧은 꼴로 줄인다. §3 목록 밖의 줄과 §5 넘김 조항(R9 · R8 몫)은 줄이지 않는다.
- 철학 문서가 넘치면: 먼저 원칙마다 이유를 기존 P# 안 한 문장으로 줄인다. 그래도 정리 전보다 작지 않으면 §3 밖을 지우지 말고 멈춰서 전후 크기와 함께 지휘 세션에 보고한다(PR 본문에도 적는다).
- 범위: 설계 §3 목록이 이 에픽 범위의 전부다. 조사 표(레포 밖)는 참고용이고, 핀 락은 grep 으로 찾는다.
- 손대지 않는 줄: CLAUDE.md Law 1 필수 섹션 문면 · `cost_class` 지출 승인 조항(epic-conductor 예외 포함) · 「새 플러그인 — `plugin-dev:plugin-structure` 먼저」 · 「버그가 리뷰를 탈출하면」 · 「최소 버전이 선언된 의존성」(R9 · R8). 철학 P12 · P22(R9). spec-distill README 의 「사용자 리뷰 게이트」 용어(흐름도 57행 근처) · Prerequisites 의 superpowers · quality-gates · gh 줄 · 흐름도(R5 후속 · R8 · R10). qg README 의 리뷰어 구성표 · 상한 수치(P22 · P18 anti-corollary 줄) · 의도 출처(C66 줄 · `## 의도 출처`) · artifact-critique 줄(`Law 1/2/3 + P8/P18`) · persona 모델 고정(`### 재비판자(code-recritic) model`)(R2a). 은퇴한 kill switch 공시(spec-distill `### 은퇴한 스위치` 절 · plugin-audit 개명 표) · CLAUDE.md `integrity` 문장 · SessionStart 훅 규칙 · qg `baseline-cache/` 안내.
- 레포 문서 규칙: Korean-primary, 영어는 식별자 · 고유명사 · 원문 인용 · 대응어 없는 기술어만. 원문 인용에 풀이를 붙이지 않는다. Self-narrating 금지 — 출처 · 이력 · 정당화는 CHANGELOG · PR 로.
- 새 글은 `test_governance_no_capability_caps.sh` 의 금지(fan-out 을 숫자에 묶는 문장 · `≥5` · 「single-agent 를 default」 · `wall-clock`)와 `test_charter_citations.sh` 의 규칙(CLAUDE.md · 철학 문서의 백틱 경로 · 링크는 추적 파일로 실재 · 지워진 이름 금지)에 걸리지 않는다.
- 원칙 문면은 「언제나 X」 꼴로 쓰지 않는다. 레포 전용 값을 박지 않는다(devbrew 밖 레포에도 맞게).
- 외부 플러그인(superpowers) 파일 · 동작은 건드리지 않는다. 새 결정론 검사(원칙 준수 lint 등)를 더하지 않는다(AC10).
- README 를 고친 플러그인마다 `plugin.json` patch bump + CHANGELOG 항목 `## [x.y.z] — 2026-10-19`. 이 계획의 번호(spec-distill 7.3.1 · quality-gates 14.0.1 · project-init 5.0.4 · plugin-audit 1.1.4)는 잠정이고 머지 직전에 지휘 세션이 확정한다.
- 커밋은 pathspec 으로(`git commit -- <경로들>`), 메시지는 Conventional Commits(설명은 한국어). 매 커밋 뒤 커밋된 파일 수가 의도와 같은지 본다.
- 작업 기록 폴더: `.claude/spec-distill/principles-docs-cleanup/`(git 이 무시한다). 기준선 · 크기 · AC 보고 파일을 여기에 둔다.
- 셸 확인 명령은 `bash` 로 돌린다(Bash 도구 셸은 zsh 다). 스위트 둘을 같은 시각에 돌리지 않는다.
- 설계문서는 지휘 세션도 고칠 수 있다 — 고치기 전에 다시 읽고, 남이 고친 줄을 되돌리지 않는다.

## Review Focus

1. **지운 줄이 유일한 현재 동작 서술이었다** — README 에서 지운 줄이 지금 동작(스위치 효과 · 산출물 계약 · 저장 위치)을 말하는 유일한 자리면 독자가 그 사실을 잃는다. 기대: 사실은 남는 줄로 옮기고 지운다. 테스트: Task 5 · 6 · 7 의 「사실 보존」 단계(README-sync 키워드 · 아래 2).
2. **kill switch 이름이 README 에서 사라진다** — kill switch 는 보안 컨트롤이라 공시가 사라지면 꺼 둔 사용자가 길을 잃는다. 기대: 각 README 의 `DEVBREW_[A-Z0-9_]+` 토큰 집합이 정리 전과 같다. 테스트: Task 5 · 6 · 7 의 토큰 집합 대조 단계.
3. **새 글의 백틱 경로가 실재하지 않는다** — README 는 `test_charter_citations.sh` 코퍼스 밖이다. 기대: 새로 쓴 줄의 `/` 를 품은 백틱 경로는 추적 파일이다. 테스트: Task 5 · 6 · 7 의 경로 실재 단계.
4. **R2a 몫 줄을 건드린다** — qg README 는 R2a 가 동시에 고친다. 기대: Global Constraints 의 R2a 줄이 바이트 그대로다. 테스트: Task 6 의 예약 줄 보존 단계.
5. **원칙 줄이 고정 규칙으로 읽힌다** — 「언제나 · 항상 · 반드시」 꼴은 흐름 고정 금지 원칙을 스스로 어긴다. 기대: 새 원칙 줄 · 이유 문장에 그 낱말이 없다. 테스트: Task 2 · 3 의 확인 명령.

---

### Task 1: 기준선 · 설계문서 받는 곳 표기 · 플러그인 동작 자리 대조표

**AC:** AC1a · AC7

**Files:**
- Modify: `docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md`(§1 두 갈래 문단 · §5 표 · `## 상류 · 하류 연계` · 새 절 `## 플러그인 동작 자리 대조` · `## 미룸`)
- Create(추적 안 함): `.claude/spec-distill/principles-docs-cleanup/baseline-failures.txt` · `sizes-before.txt`

**Interfaces:**
- Produces: `baseline-failures.txt`(정리 전 HEAD 의 `FAILED …` 줄 전부, 정렬) — Task 8 이 대조한다. `sizes-before.txt`(여섯 파일 `wc -c`) — Task 8 이 PR 본문 표를 만든다. 설계문서 `## 플러그인 동작 자리 대조` 표 — Task 8 의 끝에서 끝 (나) 가 읽는다.

- [ ] **Step 1: 기준선을 잡는다(문서를 고치기 전)**

```bash
mkdir -p .claude/spec-distill/principles-docs-cleanup
bash tools/suite/run-all.sh > .claude/spec-distill/principles-docs-cleanup/suite-before.txt 2>&1
grep -E '^FAILED ' .claude/spec-distill/principles-docs-cleanup/suite-before.txt | LC_ALL=C sort > .claude/spec-distill/principles-docs-cleanup/baseline-failures.txt
wc -c CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md plugins/{spec-distill,quality-gates,project-init,plugin-audit}/README.md > .claude/spec-distill/principles-docs-cleanup/sizes-before.txt
```
Expected: `sizes-before.txt` 의 값이 Global Constraints 의 크기와 같다. 다르면 base 가 움직인 것이니 멈추고 보고한다.

- [ ] **Step 2: 확인 명령 — 지금은 실패**

```bash
d=docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md
grep -c 'R5 후속(R5 설계 `## 미룸`)' "$d"      # 기대(고친 뒤): 3 이상 (§1 문단 · §5 · 미룸)
grep -c '지휘자 수리 PR(R5 후속)' "$d"          # 기대(고친 뒤): 0
grep -c 'test_checklist_synced_with_claude_md' "$d"   # 기대(고친 뒤): 1 이상
awk '/^## 플러그인 동작 자리 대조/{a=NR} /^## 미룸/{b=NR} END{print (a && b && a<b) ? "OK" : "NO"}' "$d"
```
Expected 지금: 둘째 줄이 1 이상, 셋째가 0, 넷째가 `NO`.

- [ ] **Step 3: 받는 곳 표기와 shape 검사 사실을 고친다**

- §1 「두 갈래」 문단 · §5 셋째 행 · `## 미룸` 셋째 행의 받는 곳 「지휘자 수리 PR(R5 후속)」 을 「R5 후속(R5 설계 `## 미룸`)」 으로 바꾼다(그 행은 지휘 세션이 R5 설계 `## 미룸` 에 더한다 — 이 과제는 표기만). Non-goals 줄의 「지휘자 수리 PR(R5 후속)」 도 같은 표기로.
- `## 상류 · 하류 연계` 의 「`plugin-audit` 의 shape 검사(`check-shape-completeness.py` 가 CLAUDE.md 앵커를 읽음)」 를 「`plugin-audit` 의 shape 회귀 테스트(`plugins/plugin-audit/tests/test_check_shape_completeness.py` 의 `test_checklist_synced_with_claude_md` 가 CLAUDE.md §Plugin Shape 의 앵커를 읽는다 — 검사 스크립트는 고정 목록)」 로 바꾼다.

- [ ] **Step 4: `## 플러그인 동작 자리 대조` 절을 `## 미룸` 바로 앞에 만든다(AC1a)**

칸: `원칙 | 실린 자리(파일:줄) | 빈 곳 | 받는 곳`. 행은 원칙 2~6 다섯(원칙 1 은 개발 규칙이라 대상 아님 — 표 위 한 줄로). 각 원칙을 플러그인이 사람 · 하위 agent 에게 내는 글(skill · reference · 설계 틀 · 넘김 줄)에서 grep 으로 찾아 실제 줄 번호를 적는다. 먼저 볼 자리(실행 때 줄 번호를 다시 잰다):
- 원칙 2: `plugins/spec-distill/references/conducting.md`(걸음 3 「흐름과 설계」) · `plugins/spec-distill/references/epic-handoff.md`(넘김 줄 「그 흐름에 없는 단계는 모델이 판단해 …」)
- 원칙 3 · 4 · 6: `plugins/spec-distill/references/epic-handoff.md` 넘김 줄(「있는 것 검토」 · 「상류 · 하류 연계」 · 「레포 전용 값은 박지 말고」)
- 원칙 5: `plugins/spec-distill/references/roadmap-ontology.md`
- 에픽이 아닌 길(인터뷰 brief 하나 → brainstorming, `plugins/spec-distill/skills/spec-interview/references/finishing.md`)에 3 · 4 · 6 이 없으면 그것이 빈 곳이다 — 받는 곳은 그 파일을 예약한 에픽(R10).
빈 곳마다 §5 표에 행을 더하고(항목 · 받는 곳 · 이유) `## 미룸` 에도 행을 더한다. 받는 곳은 그 파일을 예약한 에픽이고, 예약이 없으면 「R5 후속(R5 설계 `## 미룸`)」.

- [ ] **Step 5: 확인 명령 — 이제 통과**

Step 2 의 명령을 다시 돌린다. Expected: 첫 줄 ≥ 3 · 둘째 0 · 셋째 ≥ 1 · 넷째 `OK`. 대조표 다섯 행이 모두 「실린 자리」 나 「받는 곳」 중 하나 이상을 채웠다.

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md
git commit -m "docs(spec): R11 받는 곳 표기 · 플러그인 동작 자리 대조표" -- docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md
```

---

### Task 2: CLAUDE.md — 원칙 여섯 줄 · §3 낡은 구절

**AC:** AC1 · AC3 · AC5 · AC8 · AC10

**Files:**
- Modify: `CLAUDE.md`(Law 3 문단 · `## Plugin Shape` 머리 · 컴포넌트 격리 두 줄 · 훅 공존 줄 · Forbidden Patterns 머리 · Subagent spray · Polite handoff · Korean-primary 줄)

**Interfaces:**
- Consumes: 없음
- Produces: 원칙 줄이 가리키는 철학 이름 — `철학 Law 3`(원칙 1 · 3) · `철학 P8`(원칙 2 · 6) · `철학 P23`(원칙 4) · `철학 P5`(원칙 5). Task 3 이 그 자리에 이유를 쓴다.

- [ ] **Step 1: 확인 명령 — 지금은 실패**

```bash
f=CLAUDE.md
for p in '메모리 없는 레포' '**기본값과 판단.**' '**레포 전용 값 금지.**' '**상류 · 하류 연계.**' '**진입점에서 따라 내려가기.**' '**있는 것 먼저.**' 'Anti-Pattern Anchors'; do grep -qF -- "$p" "$f" || echo "MISSING $p"; done
for a in '<{plugin}-signal>' 'case study' 'v0.11.0 AC19' '헤드리스 실측' '이름만 다른 셸' 'unless the user requested' '*.ko.md' '자동 편집' 'review-approved'; do grep -qF -- "$a" "$f" && echo "PRESENT $a"; done
grep -nE '언제나|항상|반드시' "$f" | grep -E '기본값과 판단|레포 전용 값 금지|상류 · 하류 연계|진입점에서 따라|있는 것 먼저' && echo "FIXED-RULE WORDING"
[ "$(wc -c < "$f")" -le 15203 ] || echo "SIZE $(wc -c < "$f")"
```
Expected 지금: `MISSING` 일곱 줄 · `PRESENT` 아홉 줄.

- [ ] **Step 2: 원칙 줄을 넣는다(새 절 없이)**

Law 3 문단의 「— discoverability가 위험하면 인덱스 (`AGENTS.md`/`CLAUDE.md`)를 자동 편집.」 을 다음으로 바꾼다:

> — 「다음 세션」은 메모리 없는 레포의 세션도 뜻한다: 교훈은 메모리가 아니라 그 동작을 내는 skill · reference · 스크립트 · 락을 고쳐 남긴다(철학 Law 3).

`## Plugin Shape` 머리 문장(「…아래를 모두 만족해야 합니다.」) 바로 뒤, `### 메타데이터 & 버전 관리` 앞에 다섯 줄을 둔다:

```markdown
- **기본값과 판단.** 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름의 의도는 지킨다. 결정론은 보안 · 정확성 게이트에만(철학 P8).
- **레포 전용 값 금지.** 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 접두 · 모델 · `gh` 같은 값은 도출하거나 레포마다 정하게 한다(철학 Law 3).
- **상류 · 하류 연계.** 설계마다 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 표면과 이음매 담당을 보인다(철학 P23).
- **진입점에서 따라 내려가기.** 산출물 · 상태가 얽히면 객체 · 링크 · 속성 · 주인을 적어 진입점에서 따라가게 한다. 작은 일엔 만들지 않는다(철학 P5).
- **있는 것 먼저.** 만들기 전에 레포 안 · 밖의 있는 것을 검토하고, 외부 것은 사용자 검토 뒤에만 쓴다(철학 P8).
```

- [ ] **Step 3: §3 의 CLAUDE.md 항목을 지우거나 고친다**

- 컴포넌트 격리 agent 줄: 「(`Monitor`가 이름만 다른 셸+네트워크 egress로 그 실증)」 괄호를 지운다. 「denylist는 시간에 대해 fail-open」 과 「`tools:` allowlist를 선언」 은 그대로(`test_law2_prose.sh` · shape 앵커).
- `allowed-tools` 줄: 「2026-08-22 헤드리스 실측 5변형(…)에서 … 막지 못했다 — **이 계층은 제한이 아니다.**」 를 「목록 밖 도구도 실행되고 스코프 표기(`Bash(<pattern>:*)`)도 범위 밖 명령을 막지 못한다 — **이 계층은 제한이 아니다.**」 로 줄인다(사실은 남기고 출처 · 날짜만 뺀다).
- 훅 공존 줄: 「Signal tag는 `<{plugin}-signal>` 네임스페이스.」 문장을 지운다.
- Forbidden Patterns 머리: 「Full 카탈로그와 case study: […]의 Structural Mechanisms 섹션 (각 원칙의 anti-corollary).」 를 「원칙과 그 anti-corollary: [`docs/philosophy/devbrew-harness-philosophy.md`](docs/philosophy/devbrew-harness-philosophy.md)의 Structural Mechanisms · Anti-Pattern Anchors 절.」 로.
- Subagent spray: 「(Opus 5 기본 시스템 프롬프트의 … 해제, 2026-08-22)」 괄호를 지운다. 상시 허용 규칙 · Workflow 와 deep-research 문장은 그대로.
- Polite handoff 줄 전체를 다음으로 바꾼다:

> - **Polite handoff** — 리뷰 승인 뒤 다음 단계를 narrate만 하고 proceed 게이트를 띄우지 않는 것, 그리고 다음 세션 줄을 보인 뒤 같은 턴에 다음 단계로 직진하는 것(사용자가 「여기서 계속」을 고른 경우는 제외). 둘 다 게이트(P17)를 건너뛴 polite stop 이다(AP2 variant). 게이트 계약의 정본은 `plugins/spec-distill/references/proceed-gate.md`.

- Korean-primary 줄: 「`*.ko.md` 동반 파일 모델은 폐기 (drift 비용 > 이중 노출 가치).」 를 지운다.

- [ ] **Step 4: 확인 명령 — 이제 통과**

Step 1 의 명령을 다시 돌린다. Expected: 출력 없음. 넘치면(`SIZE`) Global Constraints 의 CLAUDE.md 순서대로 줄인다.

- [ ] **Step 5: 헌장 락**

```bash
for t in shared/tests/test_charter_citations.sh plugins/quality-gates/tests/test_law2_prose.sh plugins/quality-gates/tests/test_governance_no_capability_caps.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh shared/tests/test_invocation_surface.sh plugins/quality-gates/tests/test_publish_surface_removed.sh; do bash "$t" > .claude/spec-distill/principles-docs-cleanup/t.out 2>&1; echo "$t rc=$? fail=$(grep -cE '^ *(✗|FAIL:)' .claude/spec-distill/principles-docs-cleanup/t.out)"; done
python3 -m unittest plugins/plugin-audit/tests/test_check_shape_completeness.py 2>&1 | tail -2
```
Expected: 기준선에서 이미 실패하던 이름 말고 새 실패 0(`baseline-failures.txt` 와 대조). unittest `OK`.

- [ ] **Step 6: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(claude-md): 원칙 여섯 줄 · 낡은 구절 정리" -- CLAUDE.md
```

---

### Task 3: 철학 문서 — 원칙 이유 · §3 낡은 글

**AC:** AC2 · AC3 · AC5 · AC8

**Files:**
- Modify: `docs/philosophy/devbrew-harness-philosophy.md`(The Three Laws · P8 · P11 · P13 · P14 · P23 · Load-bearing Meta-Rules · Anti-Pattern Anchors · P5 옮김)

**Interfaces:**
- Consumes: Task 2 의 가리킴 이름(Law 3 · P8 · P23 · P5)
- Produces: 같은 이름의 절에 원칙 여섯의 이유. 새 P# 없음.

- [ ] **Step 1: 확인 명령 — 지금은 실패**

```bash
f=docs/philosophy/devbrew-harness-philosophy.md
for p in '메모리 없는 레포' '기본은 X, 일의 모양이 다르면' '레포 안 · 밖에 이미 있는 것' '되돌아오는 길' '객체 · 링크 · 속성 · 주인' '재평가 대상이다' 'cost_class: high'; do grep -qF -- "$p" "$f" || echo "MISSING $p"; done
for a in '### AP18' '### AP19' 'redirect 제안' 'opt-in 게이트' '반복적으로 놓친' '<{plugin}-signal>' 'anchor target' 'Filesystem-as-Memory' '자동 편집' '필수 섹션(Context/Why'; do grep -qF -- "$a" "$f" && echo "PRESENT $a"; done
grep -nE '언제나|항상|반드시' "$f" | grep -E '기본은 X|있는 것|되돌아오는 길|진입점' && echo "FIXED-RULE WORDING"
awk '/^## Load-bearing Meta-Rules/{m=1} /^## Anti-Pattern Anchors/{m=0} m && /^### P5 /{print "P5-IN-META"}' "$f"
[ "$(wc -c < "$f")" -lt 14876 ] || echo "SIZE $(wc -c < "$f")"
```
Expected 지금: `MISSING` 다섯 줄 · `PRESENT` 여러 줄 · `P5-IN-META` 없음 · `SIZE …`.

- [ ] **Step 2: The Three Laws 에서 CLAUDE.md 와 겹치는 문장을 줄이고 원칙 1 · 3 의 이유를 넣는다**

남길 것: 명세 작성은 일급 단계 · 하드 규칙 · N+1 번째 작업이 더 쉬워야 · low-tech 메커니즘 · theater 문장. 세 문단을 다음으로 바꾼다:

> **Law 1 — Clarity Before Code.** 명세가 모호한 상태에서는 구현이 진행되지 않는다. 명세 작성은 자신의 스킬·게이트·거절 동작을 가진 일급(first-class) 단계이고, 코드를 shipping하는 플러그인은 "아직 이건 코딩 못 한다"고 말할 수 있는 실제 거절 메커니즘을 가져야 한다(최소 요건은 CLAUDE.md Law 1). 모델 신뢰만으로는 부족하다.
>
> **Law 2 — Writer and Reviewer Must Never Share a Pass.** 코드를 쓴 턴은 그 코드를 승인할 수 없다. 이것은 heuristic이 아니라 하드 규칙이고, 분리는 프롬프트가 아니라 도구 표면으로 한다(P3).
>
> **Law 3 — Every Cycle Must Leave the System Smarter.** N+1번째 작업이 N번째보다 엄밀히 더 쉬워야 한다. 메커니즘은 low-tech다 — 리포에 있는 파일을 미래 세션이 읽는 것. 그 미래 세션에는 메모리 없는 레포 · 새 clone · devbrew 를 설치한 다른 레포의 세션도 든다. auto-memory 는 한 기기 · 한 경로에만 붙으므로 교훈은 그 동작을 내는 skill · reference · 스크립트 · 락을 고쳐 남기고, 그 자리에는 이 레포 전용 값(경로 · 테스트 명령 · 기본 브랜치 · 브랜치 접두 · 모델 · `gh`)을 박지 않고 도출하거나 레포마다 정하게 한다. 아무 미래 agent도 읽지 않는 파일에 쓰는 것은 theater다.

- [ ] **Step 3: P8 · P23 에 원칙 2 · 6 · 4 의 이유를 넣고 P8 예시를 지금 floor 로 바꾼다**

P8 의 두 방향 목록 뒤에 두 줄을 더한다:

> - (흐름) 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓴다. 정석 흐름(brainstorming → 계획 → 구현)의 의도는 지키되 순서를 강제하는 결정론은 두지 않는다 — 고정한 흐름은 모델이 더 나은 길을 볼 때 그 길을 막는다.
> - (재사용) 최소주의는 새로 만들기 전에 레포 안 · 밖에 이미 있는 것을 먼저 검토하는 데서 시작한다. 외부 것(패키지 · 프레임워크 · 서비스)은 후보로만 적고 사용자가 검토한 뒤에 쓴다(P17).

P8 예시 문단(「예: qg v2.6.0의 self-honest verdict floor는 …」)을 다음으로 바꾼다:

> 예: qg 의 판정 floor 는 「검토하지 않은 범위를 clean 이라 부르지 않는다」는 정확성 한 점에만 결정론을 걸고(kill 불가, `not-certified (scope-empty)`), 무엇을 리뷰할지 고르는 일은 모델 신뢰로 둔다.

P23 의 「재발견 금지는 반증 금지가 아니다.」 뒤에 더한다:

> 그래서 설계마다 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면과 그 이음매를 고치는 쪽을 적는다 — 이음매가 보이지 않으면 하류가 본 오류를 돌려보낼 길도 보이지 않는다.

P23 의 `코드:` 줄 끝에 ` · `plugins/spec-distill/references/epic-handoff.md` (설계의 「상류 · 하류 연계」 절)` 을 더한다.

- [ ] **Step 4: P5 를 Load-bearing Meta-Rules 로 옮기고 원칙 5 의 이유를 넣는다**

`## Anti-Pattern Anchors` 의 `### P5 → CLAUDE.md / Filesystem-as-Memory` 절을 지우고, `## Load-bearing Meta-Rules` 의 P14 절 뒤에 둔다:

> ### P5 — Filesystem as Memory
> 상태는 context가 아니라 파일에 산다 — 최소 인덱스만 preload하고 나머지는 Glob/Read/Grep으로 just-in-time 로드한다. stale-index·vector store·RAG 없음. 여러 산출물 · 상태가 얽히면 객체 · 링크 · 속성 · 주인을 명시해 진입점 하나에서 따라 내려가게 한다 — 사실마다 주인이 하나라야 따라간 끝이 정본이다. 작은 일에는 이 구조를 만들지 않는다. state 자리 규칙은 CLAUDE.md §런타임 상태 & 훅.
> 코드: `plugins/spec-distill/references/roadmap-ontology.md`

Meta-Rules 머리 「…이 essence에서만 완전히 생존하는 두 규칙.」 의 「두 규칙」 을 「규칙」 으로.

- [ ] **Step 5: §3 의 나머지 철학 문서 항목**

- P11 의 Load-bearing 문장(「Claude-only 리뷰가 반복적으로 놓친 … 다중 모델은 opt-in 게이트.」)을 「Load-bearing: 단일 모델 리뷰는 같은 전제를 공유해 같은 자리를 놓친다 — codex(read-only)는 감지되면 늘 함께 돌고, 끄는 길은 각 플러그인의 kill switch 다.」 로.
- P13: 괄호의 「namespace·」 를 지우고, Load-bearing 문장을 「같은 event에 여러 플러그인 훅이 공존하려면 순서 무관성이 구조적으로 필요하다.」 로.
- P14 끝: 「…이 essence가 정본이고, 플러그인 README 3곳 인용의 anchor target이다.」 를 「…이 essence가 정본이다.」 로.
- `## Anti-Pattern Anchors` 머리: 「인용되는 anti-pattern/규칙의 stub 앵커 — 정본은 CLAUDE.md Forbidden Patterns / Filesystem-as-Memory이고, …」 를 「인용되는 anti-pattern의 stub 앵커 — 정본은 CLAUDE.md Forbidden Patterns이고, 여기서는 cross-ref resolve만 보장한다.」 로.
- `### AP18 …` · `### AP19 …` 절 둘을 지운다(인용 0).
- P4 · P12 · P22 · Structural Mechanisms 머리(「재평가 대상이다」)는 손대지 않는다(`test_e2e_docs.sh` · `test_governance_no_capability_caps.sh` · R9).

- [ ] **Step 6: 확인 명령 — 이제 통과**

Step 1 의 명령을 다시 돌린다. Expected: `P5-IN-META` 한 줄만. `SIZE` 가 남으면 Global Constraints 의 철학 문서 순서를 따른다.

- [ ] **Step 7: 헌장 락**

```bash
for t in shared/tests/test_charter_citations.sh plugins/quality-gates/tests/test_governance_no_capability_caps.sh plugins/quality-gates/tests/test_e2e_docs.sh plugins/spec-distill/tests/test_rereview_cap_consistency.sh shared/tests/test_invocation_surface.sh; do bash "$t" > .claude/spec-distill/principles-docs-cleanup/t.out 2>&1; echo "$t rc=$? fail=$(grep -cE '^ *(✗|FAIL:)' .claude/spec-distill/principles-docs-cleanup/t.out)"; done
```
Expected: 기준선 밖 새 실패 0.

- [ ] **Step 8: Commit**

```bash
git add docs/philosophy/devbrew-harness-philosophy.md
git commit -m "docs(philosophy): 원칙 이유 흡수 · 겹침과 낡은 앵커 정리" -- docs/philosophy/devbrew-harness-philosophy.md
```

---

### Task 4: `docs/plugin-authoring.md` — 개발 교훈 다섯 줄

**AC:** AC6

**Files:**
- Modify: `docs/plugin-authoring.md`(`**Merge 전:**` 문단 바로 앞)

**Interfaces:**
- Consumes · Produces: 없음

- [ ] **Step 1: 확인 명령 — 지금은 실패**

```bash
f=docs/plugin-authoring.md
for p in '진입 한 줄만' '양성 대조' '코퍼스로 삼는 락' '실행 비트' '내용으로 싣는다'; do grep -qF "$p" "$f" || echo "MISSING $p"; done
```
Expected 지금: `MISSING` 다섯 줄.

- [ ] **Step 2: 다섯 줄을 넣는다**

```markdown
**devbrew 를 고칠 때의 규칙:**

- 새 책임은 별도 모듈(스크립트 · skill · reference)로 두고, 기존 파일에는 진입 한 줄만 더한다.
- 락을 쓰거나 고치면 변이(삭제 · 추가 · 반전 · 형태 바꾸기)로 RED 를 보이고, 양성 대조로 계측기가 살아 있음을 확인한다. 부재 락에는 양성 짝을 둔다.
- 새 파일 · 문면을 쓰기 전에 그 경로를 코퍼스로 삼는 락(`# guards:` 글롭 · 부재 스캔)을 찾는다.
- 새 셸 테스트는 실행 비트를 붙여(`100755`) 커밋한다.
- 플러그인 파일을 subagent 에 넘길 때는 경로가 아니라 내용으로 싣는다 — 설치본 캐시는 작업 폴더 밖이라 subagent 가 못 읽을 수 있다.
```

- [ ] **Step 3: 확인 명령 — 이제 통과 · 락**

Step 1 을 다시 돌린다(출력 없음). 그리고 `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh` · `bash plugins/quality-gates/tests/test_law2_prose.sh` · `bash shared/tests/test_invocation_surface.sh` — 기준선 밖 새 실패 0.

- [ ] **Step 4: Commit**

```bash
git add docs/plugin-authoring.md
git commit -m "docs(authoring): devbrew 개발 규칙 다섯 줄" -- docs/plugin-authoring.md
```

---

### Task 5: spec-distill README · 이력 면제 락 · bump

**AC:** AC4 · AC5 · AC8 · AC9 · AC10

**Files:**
- Modify: `plugins/spec-distill/README.md` · `plugins/spec-distill/tests/test_readme_sync.sh` · `plugins/spec-distill/.claude-plugin/plugin.json`(7.3.0 → 7.3.1) · `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Consumes: 없음
- Produces: `test_readme_sync.sh` 의 「살아 있는 줄」 = README 전체(이력 면제 없음). 이력 문단이 다시 생기는지 재는 새 검사는 없다(AC10).

- [ ] **Step 1: 정리 전 사실 목록을 뽑는다**

```bash
w=.claude/spec-distill/principles-docs-cleanup
grep -oE 'DEVBREW_[A-Z0-9_]+' plugins/spec-distill/README.md | LC_ALL=C sort -u > $w/sd-switches-before.txt
```

- [ ] **Step 2: 락을 바꾼다(실패하는 쪽 먼저)**

`test_readme_sync.sh` 의 「살아 있는 줄」 블록(`LIVE_TMP` 를 만드는 `grep -vE '^\*\*v…'` 와 `n_hist` 단언, 그 위 주석 다섯 줄)을 바꾼다: `LIVE_TMP` 는 README 사본 전체(`cp "$README" "$LIVE_TMP"`), 단언은 `n_live -ge 100` 하나(「live: README 전체 ${n_live}줄을 살아 있는 줄로 본다」). 주석은 「살아 있는 줄 = README 전체. 지난 버전의 기록은 CHANGELOG 몫이라 README 에는 면제가 없다」 와 기존 「한계」 줄만 남긴다. 그 아래 (1)(2)(3) 은 그대로.

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh`
Expected: FAIL — 이력 문단 줄이 대는 지워진 이름(예: 「파일 실재(부재)」 · 「brief 자리/부재」)이 이제 살아 있는 줄에서 잡힌다. 실패 줄을 `$w/sync-red-before-edit.txt` 에 남긴다.

- [ ] **Step 3: README 의 §3 항목을 정리한다**

모든 지움에 앞서: 그 줄이 지금 동작을 말하는 유일한 자리면 그 사실을 남는 줄로 옮긴 뒤 지운다. 지우기 전에 그 줄의 고유 토큰을 `grep -rnF -- '<토큰>' plugins/*/tests shared/tests tools` 로 찾아 핀한 락을 확인한다(README 를 읽는 테스트: `test_readme_sync.sh` · `test_conducting_interview_stage.sh` · `test_handoff_kill_switch.sh` · `test_rereview_cap_consistency.sh` · `test_brief_review_meta.sh` · `test_review_hook_removed.py` · `test_reviewing_brief_skill.sh` · `test_distortion_devices.sh` · `test_no_wall_clock.sh` · `test_control_plane.sh` · `test_seed_at_path_handoff.sh` · `test_stale_terms.sh` · `shared/tests/test_python_floor.sh` · `shared/tests/test_dispatch_name_defined.sh`).
- 이력 문단: `## 흐름` 아래 줄머리 `**vX.Y.Z**` · `**X.Y.Z**` 문단 전부(지금 66~86행, `**v0.12.0**` ~ `**6.0.0**`). 옮길 사실 예: `user_statements`(README-sync 키워드 — 지금 72행에만 있다) → Principles 의 핸드오프 게이트 줄(104행 근처)로.
- 줄머리가 아닌 자리의 버전 이력 서사와 버전 꼬리표 괄호: Principles · Principles 흡수 · Anti-pattern 회피 · 스위치 목록 줄의 `(v0.24.0)` · `(3.0.0)` · `(6.0.0)` · `v0.24.0 → 3.1.0 엔진 전환` 류. 단 `### 은퇴한 스위치` 절은 그대로(은퇴 공시).
- 「Law 3 (Compounding) — 문서 리뷰 엔진 기반 (v0.56.0)」 줄: 「아직 쓰는 쪽 없이 먼저 심었다 · 자리별 전환은 후속 PR」 을 지우고 지금 사실(네 자리가 `shared/docreview/` 엔진을 쓴다)만, 다른 줄과 겹치면 지운다.
- 「엔진 결함 일곱 (v0.58.0)」 줄: 결함 이력 서사를 지우고 지금 규칙(판정기가 버리면 센다 · fail-closed)과 집행 자리만 남긴다.
- 중복: P14 네 줄(Principles 흡수 P14 · worktree-safe state path · Anti-pattern 회피 P14 · P14 문서 단위 원장)을 사실마다 한 번만 남게 합친다. AP2 두 줄(Principles 「AP2 approval-gate 구분」 · Anti-pattern 「AP2 (Polite stop)」)은 Anti-pattern 쪽 하나로 — 「미커밋이거나 git 이 확인에 실패하면 advisory 만 내고 아무것도 기록하지 않는다」 를 그쪽으로 옮긴다. Law 3 / P5: Principles 흡수의 「P5 (Spec as artifact)」 줄을 지운다(Three Laws 의 Law 3 줄이 같은 말에 `(P5)` 를 단다).
- 죽은 개념: 「P17 (User sovereignty)」 줄의 「`needs_interview` user confirm gate,」 를 지운다.
- 틀린 라벨: 「P11 (Cross-Model Adversarial) — … `steelman-builder` 의심 게이트」 의 머리를 「Law 1 (Clarity) — `steelman-builder` 의심 게이트」 로(교차 모델이 아니다). 「P3 — graceful degradation with loud logging」 의 머리를 「Graceful degradation with loud logging (CLAUDE.md 런타임 상태 & 훅)」 으로(P3 은 도구 범위다).
- `## External source absorption` 절을 통째로 지운다(출처 이력 — CHANGELOG · PR 몫).
- `## Hooks Installed`: 「설치되는 훅이 없다 — 원장 정리는 리뷰 진입(`scripts/ledger_sweep.py`)이 한다.」 만 남기고 5.x 이력 문장을 지운다.

- [ ] **Step 4: 사실 보존 · 토큰 집합 · 경로 실재 · 크기**

```bash
w=.claude/spec-distill/principles-docs-cleanup; R=plugins/spec-distill/README.md
grep -oE 'DEVBREW_[A-Z0-9_]+' $R | LC_ALL=C sort -u | diff $w/sd-switches-before.txt - && echo SWITCHES-SAME
for kw in 'user_statements' 'user_sourced_items' 'audit_file' 'bijection' 'model diversity' 'steelman-builder' 'coverage-mapper' 'blind-spot-prober' '덜어 낸 것' '2파일 쌍' '8섹션'; do grep -qF -- "$kw" $R || echo "LOST $kw"; done
[ "$(wc -c < $R)" -lt 71133 ] || echo "SIZE $(wc -c < $R)"
```
Expected: `SWITCHES-SAME` · `LOST` 없음 · `SIZE` 없음. 새로 쓴 줄의 `/` 를 품은 백틱 경로는 `git ls-files --error-unmatch <경로>` 로 실재를 확인한다(디렉토리면 `ls`).

- [ ] **Step 5: 락이 통과한다**

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh` 와 Step 3 의 README 를 읽는 테스트 전부.
Expected: 기준선 밖 새 실패 0.

- [ ] **Step 6: Commit(변이 전에)**

```bash
git add plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh
git commit -m "docs(spec-distill): README 낡은 이력 · 중복 정리 · 이력 면제 락 제거" -- plugins/spec-distill/README.md plugins/spec-distill/tests/test_readme_sync.sh
```

- [ ] **Step 7: 뜻을 바꾼 락은 변이로 RED 를 보인다(AC8)**

변이: README 끝에 `**v9.9.9**: 옛 \`scripts/gone_r11_probe.py\` 를 쓴다.` 한 줄을 더하고 `test_readme_sync.sh` 를 돌린다.
Expected: FAIL 「파일 실재(부재): … gone_r11_probe.py」.
양성 대조(옛 면제가 이 줄을 숨겼음): `grep -vE '^\*\*v[0-9]+\.[0-9]+\.[0-9]+\*\*' plugins/spec-distill/README.md | grep -c gone_r11_probe` → `0`.
복원: `git checkout HEAD -- plugins/spec-distill/README.md` 뒤 `git diff HEAD --stat -- plugins/spec-distill/README.md` 가 비었는지 확인. 변이 · 결과를 `$w/mutations.txt` 에 적는다.

- [ ] **Step 8: bump · CHANGELOG · Commit**

`plugin.json` `"version": "7.3.1"`. CHANGELOG 맨 위에:

```markdown
## [7.3.1] — 2026-10-19

### Changed
- README 에서 지난 버전 이력 문단 · 버전 꼬리표 · 출처 이력 절을 지우고, 겹친 원칙 줄을 합치고, 틀린 원칙 라벨을 고쳤다. 지금 동작 서술은 그대로다.
- `tests/test_readme_sync.sh` 가 README 전체를 살아 있는 줄로 읽는다(이력 면제 없음).
```

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git commit -m "chore(spec-distill): 7.3.1 — README 정리" -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
bash shared/tests/test_changelog_integrity.sh > .claude/spec-distill/principles-docs-cleanup/t.out 2>&1; echo "changelog_integrity rc=$?"
```

---

### Task 6: quality-gates README · bump

**AC:** AC4 · AC5 · AC9

**Files:**
- Modify: `plugins/quality-gates/README.md` · `plugins/quality-gates/.claude-plugin/plugin.json`(14.0.0 → 14.0.1) · `plugins/quality-gates/CHANGELOG.md`

**Interfaces:**
- Consumes · Produces: 없음

- [ ] **Step 1: 정리 전 사실 · 예약 줄을 뽑는다**

```bash
w=.claude/spec-distill/principles-docs-cleanup; R=plugins/quality-gates/README.md
grep -oE 'DEVBREW_[A-Z0-9_]+' $R | LC_ALL=C sort -u > $w/qg-switches-before.txt
grep -E 'P22 anti-corollary|P18 anti-corollary|^- \*\*C66|Law 1/2/3 \+ P8/P18' $R > $w/qg-reserved-before.txt
awk '/^## 리뷰어 구성/{f=1} /^## 파이프라인 흐름/{f=0} f' $R > $w/qg-composition-before.txt
awk '/^### 재비판자\(code-recritic\) model/{f=1;print;next} /^#/{f=0} f' $R > $w/qg-recritic-model-before.txt
awk '/^## 의도 출처/{f=1;print;next} /^## /{f=0} f' $R > $w/qg-intent-before.txt
```

- [ ] **Step 2: 확인 명령 — 지금은 실패**

```bash
R=plugins/quality-gates/README.md
for a in 'single dispatch builder' 'Optional `codex-reviewer` agent' 'The optional `codex-reviewer` agent' '문서 리뷰 엔진 기반 (v7.4.0)' '이 리포 실측' 'v10.0.0 에서 두 훅' 'scanner 훅은 v10.0.0' 'MAX_TOTAL_ITERATIONS' 'v7.4.0 bullet'; do grep -qF -- "$a" $R && echo "PRESENT $a"; done
```
Expected 지금: `PRESENT` 아홉 줄.

- [ ] **Step 3: §3 의 qg 항목을 정리한다(R2a 몫 줄은 그대로)**

- 「Law 3 (Compounding) — Phase 1 single dispatch builder (T2-2/T3-5) …」 줄을 지운다.
- 「Law 2 strengthening — model-family separation. Optional `codex-reviewer` agent …」 줄을 지우고, 바로 뒤 「Law 2 (codex 격리, v1.11.0/v1.12.0 → v2.11.0 정정)」 줄을 지금 사실만으로 줄인다: 머리 「Law 2 (codex 격리)」, 본문 「codex 리뷰(`scripts/run_codex_reviewer.sh`)의 격리는 `codex exec -s read-only` OS-level 샌드박스 + 별도 프로세스 · 모델 패밀리다. agent 파일이 아니라 스크립트라 frontmatter 가 없다(`tests/test_codex_reviewer_frontmatter.sh` 가 agent 파일 부재를 잰다).」
- 「Law 3 (Compounding — drift 재발 차단, v1.12.0)」 줄 끝의 「(SessionStart frontmatter scanner 훅은 v10.0.0 에서 지웠다 — drift 차단은 이 테스트가 진다.)」 를 지운다.
- LD3 줄의 「(이 리포 실측: `.sh` 130개 / `.py` 50개)」 괄호를 지운다.
- 「Law 3 (Compounding) — 문서 리뷰 엔진 기반 (v7.4.0)」 줄을 지금 사실로: 「Law 3 (Compounding) — 문서 리뷰 엔진 — `/quality-gates:artifact-critique` 의 non-code 리뷰 자리를 `generic` 프로필(`references/docreview-profiles/generic.md`)로 선언하고 공용 엔진 `shared/docreview/` 를 쓴다. 집행은 `shared/tests/test_docreview_*.sh` + 변이 매트릭스.」 (artifact-critique 동작 서술은 더하지 않는다 — R2a 몫.) 구조 트리의 「(§ 위 v7.4.0 bullet)」 을 「(§ 위 문서 리뷰 엔진 줄)」 로.
- `## 설치된 Hook`: 「없음. 파이프라인은 한 턴 안에서 끝나고, 세션 폴더는 …(이하 현재 동작 그대로)」 — 「v10.0.0 에서 두 훅(…)을 지웠다 —」 만 뺀다.
- `### Codex reviewer cost`: 「The optional `codex-reviewer` agent has `cost_class: variable`」 를 「codex 리뷰(`scripts/run_codex_reviewer.sh`)는 `cost_class: variable` 이다」 로(뒤 문장은 그대로). kill switch 표의 `DEVBREW_QUALITY_GATES_DISABLE_CODEX=1` 행 「optional `codex-reviewer` 완전 skip」 을 「codex 리뷰(`scripts/run_codex_reviewer.sh`) 완전 skip」 으로.
- 「(`MAX_TOTAL_ITERATIONS`와 cross-gate restart 루프는 v1.5.0에서 제거됨.)」 줄을 지운다.
- 손대지 않는다: `### 재비판자(code-recritic) model` · `## 리뷰어 구성` · P22 · P18 anti-corollary 줄 · C66 줄 · `## 의도 출처` · artifact-critique 줄 · v7.5.0 줄 · `branch <name>` 제거 안내 · 샌드박스 이전 안내 · `baseline-cache/` 안내.

- [ ] **Step 4: 확인 명령 — 이제 통과 · 예약 줄 · 토큰 · 경로 · 크기**

```bash
w=.claude/spec-distill/principles-docs-cleanup; R=plugins/quality-gates/README.md
# Step 2 명령을 다시 돌려 PRESENT 가 없는지 본다.
grep -oE 'DEVBREW_[A-Z0-9_]+' $R | LC_ALL=C sort -u | diff $w/qg-switches-before.txt - && echo SWITCHES-SAME
while IFS= read -r l; do grep -qxF -- "$l" $R || echo "RESERVED-CHANGED ${l:0:60}"; done < $w/qg-reserved-before.txt
awk '/^## 리뷰어 구성/{f=1} /^## 파이프라인 흐름/{f=0} f' $R | diff -q $w/qg-composition-before.txt - >/dev/null && echo COMPOSITION-SAME
awk '/^### 재비판자\(code-recritic\) model/{f=1;print;next} /^#/{f=0} f' $R | diff -q $w/qg-recritic-model-before.txt - >/dev/null && echo RECRITIC-MODEL-SAME
awk '/^## 의도 출처/{f=1;print;next} /^## /{f=0} f' $R | diff -q $w/qg-intent-before.txt - >/dev/null && echo INTENT-SAME
[ "$(wc -c < $R)" -lt 58388 ] || echo "SIZE $(wc -c < $R)"
```
Expected: `SWITCHES-SAME` · `COMPOSITION-SAME` · `RECRITIC-MODEL-SAME` · `INTENT-SAME`, `RESERVED-CHANGED` · `SIZE` 없음. 새로 쓴 줄의 `/` 를 품은 백틱 경로는 `git ls-files --error-unmatch` 로 실재 확인.

- [ ] **Step 5: README 를 읽는 qg 락**

Run: `plugins/quality-gates/tests/` 에서 `grep -l 'README' plugins/quality-gates/tests/*.sh plugins/quality-gates/tests/*.py` 로 뽑은 테스트 전부 + `shared/tests/test_python_floor.sh` · `shared/tests/test_dispatch_name_defined.sh` · `plugins/quality-gates/tests/test_law2_prose.sh`.
Expected: 기준선 밖 새 실패 0.

- [ ] **Step 6: bump · CHANGELOG · Commit**

`plugin.json` `"version": "14.0.1"`. CHANGELOG 맨 위 `## [14.0.1] — 2026-10-19` / `### Changed` / 「README 에서 없는 agent(`codex-reviewer`) 설명 · 지난 버전 이력 · 실측 이력 괄호를 지우고 지금 사실로 고쳤다. 동작은 같다.」

```bash
git add plugins/quality-gates/README.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git commit -m "docs(qg): README 의 없는 agent 설명 · 낡은 이력 정리" -- plugins/quality-gates/README.md plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
```

---

### Task 7: project-init · plugin-audit README · bump

**AC:** AC4 · AC5 · AC9

**Files:**
- Modify: `plugins/project-init/README.md` · `plugins/project-init/.claude-plugin/plugin.json`(5.0.3 → 5.0.4) · `plugins/project-init/CHANGELOG.md`
- Modify: `plugins/plugin-audit/README.md` · `plugins/plugin-audit/.claude-plugin/plugin.json`(1.1.3 → 1.1.4) · `plugins/plugin-audit/CHANGELOG.md`

**Interfaces:**
- Consumes · Produces: 없음

- [ ] **Step 1: 정리 전 토큰 · 확인 명령(지금은 실패)**

```bash
w=.claude/spec-distill/principles-docs-cleanup
for p in project-init plugin-audit; do grep -oE 'DEVBREW_[A-Z0-9_]+' plugins/$p/README.md | LC_ALL=C sort -u > $w/$p-switches-before.txt; done
P=plugins/project-init/README.md; A=plugins/plugin-audit/README.md
for a in '# v1.7.0 —' '# v1.7.3 —' '# v3.0.0 —' '# v1.6.0 —' '5. (v1.6.0)' 'quality-gates v7.0.0 에서 제거' 'fail-open, v1.7.0' '5.0.0 부터' '— v1.6.0**' 'CLAUDE.md는 짧은 anchor만' 'quality-gates 10.0.0 이 마지막 자리를'; do grep -qF -- "$a" $P && echo "PRESENT(pi) $a"; done
for a in '근거는 현재 제3자 설치가 없다는' '표의 마지막 줄은 0.11.0 에서 더했다' 'severity 어휘 통일 (0.6.0' '(0.6.0, devbrew-weight-reduction Task 25)'; do grep -qF -- "$a" $A && echo "PRESENT(pa) $a"; done
```
Expected 지금: `PRESENT` 줄들.

- [ ] **Step 2: project-init README**

- 구조 트리 주석의 버전 꼬리표(`# v1.7.0 — …` · `# v1.7.3 — …` · `# v3.0.0 — …` · `# v1.6.0 — …`)를 지운다(주석의 뜻은 남긴다).
- 동작 방식 5 의 「(v1.6.0)」 · 통합 줄의 「(PR 생성 자동 트리거는 quality-gates v7.0.0 에서 제거)」 · 훅 줄의 「, v1.7.0」 · 「5.0.0 부터」 · Principles 의 「— v1.6.0」 을 지운다.
- Prerequisites 의 「(quality-gates 10.0.0 이 마지막 자리를 지웠다)」 괄호를 지운다(「2026-10 이후에도 패치를 받는 버전 중 최빈」 · `Python 3.12+` · `EOL` 은 그대로 — `test_python_floor.sh`).
- Principles 「Plugin shape — minimal pointer pattern」 줄을 지금 생성물에 맞춘다: 「`CLAUDE.md` 는 `@AGENTS.md` 한 줄 thin pointer, 규칙 본문은 `AGENTS.md` 와 `docs/git-workflow/` 에 산다.」
- 첫 문단 · `## Principles Instantiated` 머리는 그대로(`test_plain_init_text.py`).

- [ ] **Step 3: plugin-audit README**

- 「**환경변수 어순 rename (0.6.0, devbrew-weight-reduction Task 25).**」 머리를 「**환경변수 개명.**」 으로. 개명 표는 그대로(은퇴한 kill switch 공시).
- 표 아래 두 문단(「옛 이름은 **fallback 없이 즉시 제거**됐다 — …」 · 「표의 마지막 줄은 0.11.0 에서 더했다 — …」)을 지금 동작 두 문장으로 바꾼다: 「표의 옛 이름은 마지막 줄을 빼고 더는 읽지 않는다. 마지막 줄의 옛 이름 `DEVBREW_QUALITY_GATES_DISABLE_RUNTIME_SANDBOX=1` 은 별칭으로 따른다 — 값이 정확히 `1` 이면 새 이름과 같이 `create-sandbox` 가 exit 3 으로 멈추고, stderr 한 줄이 개명을 알린다.」
- 「**severity 어휘 통일 (0.6.0, …).**」 문단을 지금 동작으로: 「리포트의 `[severity]` 배지는 `CRITICAL`/`IMPORTANT`/`SUGGESTION` 셋이다. 옛 4어휘(`HIGH` 등)로 쓰인 과거 리포트는 렌더되지만 정렬에서 맨 뒤로 간다.」
- 위 kill switch 문단 안의 「(0.11.1 부터)」 · 표의 「(0.11.0 에 더함 · 0.11.1 부터 별칭으로 따름)」 같은 버전 꼬리표는 지운다. 첫 문단 · 완료 보고 문장 · `.claude/plugin-audit/` 는 그대로(`test_plain_audit_text.py` · `test_skill_orchestration.py`). kill switch 정규식 관련 줄은 손대지 않는다(R2a).

- [ ] **Step 4: 확인 명령 — 이제 통과 · 토큰 · 크기 · 락**

```bash
w=.claude/spec-distill/principles-docs-cleanup
# Step 1 의 PRESENT 명령을 다시 돌려 출력이 없는지 본다.
for p in project-init plugin-audit; do grep -oE 'DEVBREW_[A-Z0-9_]+' plugins/$p/README.md | LC_ALL=C sort -u | diff $w/$p-switches-before.txt - && echo "$p SWITCHES-SAME"; done
[ "$(wc -c < plugins/project-init/README.md)" -lt 8236 ] || echo SIZE-pi
[ "$(wc -c < plugins/plugin-audit/README.md)" -lt 9158 ] || echo SIZE-pa
python3 -m unittest discover -s plugins/project-init/tests -p 'test_*.py' 2>&1 | tail -2
python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_*.py' 2>&1 | tail -2
bash shared/tests/test_python_floor.sh > .claude/spec-distill/principles-docs-cleanup/t.out 2>&1; echo "python_floor rc=$?"
bash shared/tests/test_dispatch_name_defined.sh > .claude/spec-distill/principles-docs-cleanup/t.out 2>&1; echo "dispatch_name rc=$?"
```
Expected: 둘 다 `SWITCHES-SAME`, `SIZE-*` 없음, unittest `OK`(기준선 밖 새 실패 0). 새로 쓴 줄의 `/` 를 품은 백틱 경로는 실재 확인.

- [ ] **Step 5: bump · CHANGELOG · Commit**

project-init `"version": "5.0.4"`, CHANGELOG `## [5.0.4] — 2026-10-19` / `### Changed` / 「README 에서 버전 꼬리표를 지우고, `CLAUDE.md` 생성물 설명을 지금 동작(`@AGENTS.md` 한 줄)에 맞췄다.」
plugin-audit `"version": "1.1.4"`, CHANGELOG `## [1.1.4] — 2026-10-19` / `### Changed` / 「README 의 개명 · severity 이력 서사를 지금 동작 서술로 줄였다. 개명 표와 별칭 동작은 그대로다.」

```bash
git add plugins/project-init/README.md plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md plugins/plugin-audit/README.md plugins/plugin-audit/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md
git commit -m "docs(plugins): project-init · plugin-audit README 이력 서사 정리" -- plugins/project-init/README.md plugins/project-init/.claude-plugin/plugin.json plugins/project-init/CHANGELOG.md plugins/plugin-audit/README.md plugins/plugin-audit/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md
```

---

### Task 8: CHANGELOG 이력 아닌 글(D1.1) · 전체 스위트 대조 · 크기표 · 끝에서 끝

**AC:** AC5 · AC8 · D1.1 대조

**Files:**
- Modify(필요할 때만): `plugins/{spec-distill,quality-gates,project-init,plugin-audit}/CHANGELOG.md` — 이력 아닌 낡은 글이 있을 때
- Create(추적 안 함): `.claude/spec-distill/principles-docs-cleanup/changelog-d11.txt` · `sizes-after.txt` · `suite-after.txt` · `e2e-read.txt`

**Interfaces:**
- Consumes: Task 1 의 `baseline-failures.txt` · `sizes-before.txt` · 대조표
- Produces: PR 본문에 넣을 셋 — 파일별 전후 크기 표 · CHANGELOG 넷의 D1.1 결과(정리 내용 또는 「없음」) · 스위트 대조 결과

- [ ] **Step 1: CHANGELOG 넷의 이력 아닌 글을 본다(D1.1)**

각 CHANGELOG 에서 첫 `## [` 헤딩 앞의 글과, 버전 번호가 없는 머리 항목(`Unreleased` 등)을 본다. 지난 버전 항목(`## [x.y.z]` 아래)은 이력이라 보지 않는다. 지금 동작을 설명하는 안내 문단이나 아직 내지 않은 머리 항목이 있으면 지우고, 없으면 그 파일을 「없음」으로 `changelog-d11.txt` 에 적는다. (계획 작성 때 본 바: 넷 모두 첫 헤딩 앞에는 제목과 Keep a Changelog · SemVer 형식 안내뿐이었다 — 실행 때 다시 본다.)

- [ ] **Step 2: 전체 스위트를 기준선과 실패 이름으로 대조**

```bash
w=.claude/spec-distill/principles-docs-cleanup
bash tools/suite/run-all.sh > $w/suite-after.txt 2>&1
grep -E '^FAILED ' $w/suite-after.txt | LC_ALL=C sort > $w/after-failures.txt
comm -13 $w/baseline-failures.txt $w/after-failures.txt
```
Expected: 출력 없음(새 실패 0). 있으면 고치고 다시 돈다. 사라진 실패(`comm -23`)는 PR 본문에 적는다.

- [ ] **Step 3: 크기표**

```bash
wc -c CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md plugins/{spec-distill,quality-gates,project-init,plugin-audit}/README.md > .claude/spec-distill/principles-docs-cleanup/sizes-after.txt
```
Expected: Global Constraints 의 크기 기준을 모두 만족. PR 본문에 파일 · 전 · 후 표.

- [ ] **Step 4: 끝에서 끝(설계 Verification Plan)**

(가) 메모리 없이 이 브랜치의 `CLAUDE.md` 와 철학 문서만 읽어 원칙 여섯을 각각 찾고, 각 CLAUDE.md 줄이 가리키는 철학 절에 그 이유가 있는지 확인한다(subagent 에게 맡길 때는 두 파일 내용을 인라인으로 싣고 메모리 · 이 계획을 주지 않는다). (나) 설계문서 `## 플러그인 동작 자리 대조` 의 「실린 자리」 마다 그 파일:줄을 열어 원칙이 실려 있는지, 「받는 곳」 마다 §5 · `## 미룸` 에 같은 행이 있는지 본다. 결과를 `e2e-read.txt` 에 원칙마다 한 줄로.

- [ ] **Step 5: (D1.1 로 CHANGELOG 를 고쳤을 때만) Commit**

```bash
git commit -m "docs(changelog): 이력 아닌 낡은 글 정리" -- <고친 CHANGELOG 경로들>
```

---

## 마지막 전체 리뷰 · 구현 대조

고른 실행 방식의 마지막 전체 리뷰(브랜치 전체)에 아래 목록을 싣고, 리뷰가 항목마다 한 줄씩 `AC1: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 한다. 보고는 `.claude/spec-distill/principles-docs-cleanup/ac-report.md`(git 이 추적하지 않는다)에 적는다.

- AC1 CLAUDE.md 에 §1 원칙 여섯이 각각 한 줄로 있고, 각 줄이 철학 문서의 해당 원칙을 가리킨다. 새 큰 절이 없다.
- AC1a 원칙 2~6 마다 플러그인 동작 자리 대조표(실린 파일:줄 또는 §5 넘김 행)가 이 설계문서 `## 미룸` 앞 절에 있다.
- AC2 철학 문서가 원칙 여섯의 이유 · 배경을 담고, 새 P# 가 있으면 기존 P# 에 흡수하지 못한 이유가 같은 절에 한 문장으로 있다.
- AC3 §3 의 CLAUDE.md · 철학 문서 항목이 지워지거나 고쳐졌다(목록 항목마다 대조).
- AC4 §3 의 플러그인 README 넷 항목이 지워지거나 고쳐졌고, R2a 몫 줄은 그대로다.
- AC5 정리 대상 문서(CLAUDE.md · 철학 문서 · 플러그인 README 넷)마다 정리 전보다 작고, CLAUDE.md 는 정리 전 크기 이하다 — PR 본문에 파일별 전후 크기.
- AC6 `docs/plugin-authoring.md` 에 §4 다섯 줄이 있다.
- AC7 §5 넘김이 이 설계 `## 미룸` 표에 받는 곳과 함께 있다.
- AC8 헌장 · README 를 읽는 락이 GREEN 이고, 뜻을 바꾼 락은 변이로 RED 를 보인다.
- AC9 README 를 고친 플러그인마다 `plugin.json` patch bump 와 CHANGELOG 항목이 있다.
- AC10 새 결정론 검사(원칙 준수 lint 등)를 더하지 않았다.
- D1.1 대조(AC 아님, 사용자 결정 D1.1): 플러그인 CHANGELOG 넷마다 이력이 아닌 낡은 글을 정리했거나, PR 본문에 그 CHANGELOG 는 「없음」이라고 적혀 있다.

미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다. PR 을 만들기 전에 다음을 돌려 경고를 사용자에게 보인다:

```bash
python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/7.3.0/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-19-principles-docs-cleanup-design.md .claude/spec-distill/principles-docs-cleanup/ac-report.md
```

사람에게 쓰는 글(PR 본문 · 보고)은 번호 · 해시를 내용 문장 뒤 괄호에, 첫 줄에 상태, 끝에 할 일 하나.
