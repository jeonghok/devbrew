# skill-only 호출 표면 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** qg 밖 기능 다섯을 «기능당 사용자 진입 skill 하나»로 옮기고, 본문 전달 전 `!` 사전 검사를 붙이고, 그 정합을 락으로 집행하고, CLAUDE.md 규칙을 개정한다.

**Architecture:** 공유 정본 `shared/entry/entry_preflight.py` 를 세 플러그인 `scripts/` 에 심볼릭 링크로 싣는다. 진입 skill 마다 사전 허용 한 항목과 `!` 한 줄을 두고, `## 진입 단계` 절이 그 감시줄을 판독한다. 그 위에 `@` 풀기와 trivia 판정이 오고, 그다음 기존 본문이 돈다. 표면 정합은 `shared/entry/check_invocation_surface.py`(축 A~I)가 `git ls-files` 에서 도출해 판정한다. qg 는 `plugins/quality-gates/commands/` 가 있는 동안 보고 모드로 돈다.

**Tech Stack:** Python 3(표준 라이브러리만, 3.8 문법 바닥) · bash 3.2(macOS 시스템 셸) · `shared/tests/assert.sh` · Claude Code 2.1.294 skill frontmatter.

**Spec:** `docs/superpowers/specs/2026-10-09-skill-only-surface-design.md` (커밋 54e6e42f). 입력 brief는 `docs/superpowers/interview/2026-10-08-skill-only-surface-interview.md` 이고 경로로만 참조한다.

## 목차

- [Global Constraints](#global-constraints)
- [계획 단계 결정 — Deferred to plan 10건의 흡수](#계획-단계-결정--deferred-to-plan-10건의-흡수)
- [계획 단계 예비 실측 (2026-10-09)](#계획-단계-예비-실측-2026-10-09)
- [Review Focus](#review-focus)
- [파일 구조](#파일-구조)
- [Task 0: 기준선 · 설계 동기화](#task-0-기준선--설계-동기화)
- [Task 1: 공유 사전 검사 `entry_preflight.py`](#task-1-공유-사전-검사-entry_preflightpy)
- [Task 2: 표면 정합 락 (축 A~I) — 합성 리포 이빨](#task-2-표면-정합-락-축-ai--합성-리포-이빨)
- [Task 3: 기계적 개명 넷 + qg B6](#task-3-기계적-개명-넷--qg-b6)
- [Task 4: `spec-review` 진입 머리](#task-4-spec-review-진입-머리)
- [Task 5: `spec-interview` — 명령 흡수 · 숨김 해제 · «풀린 입력»](#task-5-spec-interview--명령-흡수--숨김-해제--풀린-입력)
- [Task 6: `request-framing` — 명령 흡수 · 핸드오프 완전명](#task-6-request-framing--명령-흡수--핸드오프-완전명)
- [Task 7: spec-distill 마감 — README · 템플릿 · 버전](#task-7-spec-distill-마감--readme--템플릿--버전)
- [Task 8: plugin-audit — 명령 흡수 · 사용자 전용 · staleness 규칙](#task-8-plugin-audit--명령-흡수--사용자-전용--staleness-규칙)
- [Task 9: project-init — 새 진입 skill](#task-9-project-init--새-진입-skill)
- [Task 10: CLAUDE.md · 저술 문서 · 철학 문서](#task-10-claudemd--저술-문서--철학-문서)
- [Task 11: 락 GREEN · 실제 사본 변이 · manifest 단계](#task-11-락-green--실제-사본-변이--manifest-단계)
- [Task 12: qg 핸드오프 보고서](#task-12-qg-핸드오프-보고서)
- [Task 13: 실측 M1~M6 (격리 설치본)](#task-13-실측-m1m6-격리-설치본)
- [Task 14: 종료 — 기준선 대조 · 범위 확인 · 메모리](#task-14-종료--기준선-대조--범위-확인--메모리)

## Global Constraints

모든 Task 의 요구사항에 이 절이 암묵적으로 포함된다.

- **C3 · B6** — quality-gates 파일은 고치지 않는다. 예외는 정확히 넷이다: ① `plugins/quality-gates/tests/test_codex_gate_observation.sh` 의 라벨 `case` 줄 ② 그 줄의 주석 ③ qg `plugin.json` patch bump ④ qg `CHANGELOG.md` 한 항목.
- **C9 · D3** — 바꾸거나 없애는 호출 이름은 alias 없이 즉시 제거하고 major bump 한다. fallback 명령을 두지 않는다.
- **D5** — 사용자가 치는 이름은 짧은 kebab 두 단어 이상(일반어 단독 금지)이다. 기계가 내는 안내(skill · hook · script · template · reference · agent 본문)는 `/plugin:name` 완전명을 쓴다. README(사람용)는 짧은 이름을 쓴다.
- **B2** — 사용자 인자(`$ARGUMENTS` · `${ARGUMENTS}` · `$0`~`$9`)는 `!` 줄과 ```` ```! ```` 블록에 두지 않는다.
- **사전 검사 줄 모양(정확히 이 글자)** — `<plugin>` · `<skill>` 에는 자기 값을 넣는다:
  - frontmatter: `allowed-tools:` 아래 한 항목 `  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" <plugin> <skill>)`
  - 본문: 줄 시작에 `` !`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" <plugin> <skill>` ``. 그 바로 아래(빈 줄 하나 뒤) `## 진입 단계`.
  - 두 줄은 손으로 치지 않는다. `python3 shared/entry/check_invocation_surface.py --print-head <plugin> <skill>` 출력을 붙인다(Task 2).
- **진입 skill 본문 산문에 `` !` `` 두 글자를 연달아 쓰지 않는다.** 플랫폼은 줄 시작이나 공백 뒤의 `` !`…` `` 를 셸로 실행한다. 사전 검사 줄 하나만 그 모양이다. 산문에서는 «사전 검사 줄»이라고 부른다.
- **kill switch** — 진입 단계가 보는 것은 `DEVBREW_<PLUGIN>_DISABLE=1` 하나다(D1.1). `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다. kill switch 이름은 바꾸지 않는다.
- **`disable-model-invocation: true`** 인 진입 skill 집합은 정확히 {`plugin-audit`, `project-init`} 이다(B5).
- **버전** — 브랜치 안의 값: spec-distill `5.0.0`, project-init `5.0.0`, plugin-audit `1.0.0`, quality-gates `9.3.7`. 번호 문자열은 Task 14 에서 머지 직전 `origin/main` 을 보고 다시 확정한다.
- **커밋** — Conventional Commits. 매 커밋은 pathspec 으로 한다(`git commit -- <paths>`). 커밋 뒤 `git show --stat HEAD` 로 파일 수를 확인한다. 메시지 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- **테스트 실행** — 리포 루트에서 `bash <file>.sh` · `python3 -m unittest`. 변이를 다루는 실행은 `PYTHONDONTWRITEBYTECODE=1` 로 한다.
- **문서** — Korean-primary. 산출물(SKILL · reference · template)에는 출처 · 배경 · 정당화 문장을 넣지 않는다(Self-narrating artifact 금지). 이력은 CHANGELOG 에 둔다.
- **subagent 모델** — devbrew 에서 fable 은 쓰지 않는다. 리뷰어는 opus 로 한다.

## 계획 단계 결정 — Deferred to plan 10건의 흡수

설계 `### Deferred to plan` 10건과 계획 중 새로 확인한 사실의 처분이다. Task 0 이 이 표를 설계문서에 동기화한다.

| # | 항목 | 처분 | 집행 Task |
|---|---|---|---|
| P1 | «풀린 입력» 정의 (e290ddb1) | `## 진입 단계` 2 의 산출이다. 성공하면 Read 원문 전체(frontmatter 포함)이고, 발동하지 않으면 skill 이 받은 인자 그대로다. seed 인식 · trivia · S1 · 본 절차는 «풀린 입력»을 읽는다. `seed-input.md` · `finishing.md` · `trivia-escape.md` · SKILL 본문의 `$ARGUMENTS` 를 «풀린 입력»으로 바꾼다 | 5 |
| P2 | Step 2.5 조언 (f1a3bbc8) | **유지**한다. `spec-interview` 진입 단계 3.5 로 옮기고 완전명 `/spec-distill:request-framing` 으로 적는다. 근거: Phase 0 으로 가는 유일한 안내이고, `request-framing` 「호출 모양」 절이 이 조언을 전제로 쓰였다 | 5 |
| P3 | 보고서 3부 (ad8b5a7f) | 3부 «락 밖 qg 위반»을 둔다. RC4 · RC5 · RC6 · RC8 · RC10 · RC18 을 손으로 옮기고 `validate --strict` hooks 경고(아래 P11)를 더한다. 행마다 v10 칸을 붙인다 | 12 |
| P4 | project-init `cost_class` (98483a2a) | **`low`**. agent · codex · 웹 · Bash 를 쓰지 않고, 읽기 · `AskUserQuestion`(≤4) · 로컬 쓰기뿐이다. `high` 가 아니므로 `AskUserQuestion` 지출 게이트를 두지 않는다. 부작용(파일 쓰기)은 `disable-model-invocation`(B5)이 맡는다 | 9 |
| P5 | 축 G 코퍼스 (94e7636c) | 기계 코퍼스는 `plugins/*/{skills,hooks,scripts,templates,references,agents}/**` 이다. templates 셋의 bare 진입 이름은 완전명으로 바꾼다 | 2 · 6 · 9 |
| P6 | v10 대조 기준 (ce0db444) | v10 설계는 `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` 이다. 기준 커밋은 **`5eccf37c82ee6f000baefb0e8e972733ba07eb38`**(브랜치 `feature/qg-v10-cleanup`, 워크트리 디렉토리 이름은 `qg-review-e2e-publish`)이고, `git show 5eccf37c:<경로>` 로 읽는다 | 12 |
| P7 | 고아 copy-of 항목 (a231cc98 · 641c4e4c) | 만들지 않는다. 설계 Files to Modify 에서 지운다 | 0 |
| P8 | Handoff B1~B12 (e1b5b3be) | B1~B13 으로 고친다 | 0 |
| P9 | AC7 실현 가능성 (7b7d0951) | AC7 → «qg 밖 살아 있는 표면에서 옛 이름 0건. qg 안의 잔여는 락 `--report` 표를 거쳐 보고서 행으로 실린다» | 0 · 11 |
| P10 | 미실행 seed 판별 | 아래 규칙으로 판별한다. ① `docs/superpowers/interview/*.md` 중 `.audit.md` 가 아니고 첫 줄이 `---` 인 frontmatter 에 정확히 `type: interview-seed` 가 있는 파일 ② 그 파일의 `audit_file:` 값 줄(`audit_file: <x>`)을 담은 다른 파일이 `docs/` 아래에 없음(brief §6 S1 은 seed 전문을 frontmatter 째 담는다). 2026-10-09 실측은 넷(`2026-09-01-adjudication-topology` · `2026-09-01-seam-and-adjudication` · `2026-09-02-adjudication-topology` · `2026-09-05-spec-review-two-stage-redesign`)이고, 넷 모두 옛 호출 줄이 **0줄**이다. 따라서 AC7 후반은 갱신 0건으로 충족된다. 판별 결과를 보고서에 싣는다 | 12 |
| P11 | **새 사실** — `validate --strict` 선재 경고 | 2026-10-09 실측에서 spec-distill · project-init · quality-gates 의 `hooks/hooks.json` 이 「Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes」 경고로 `--strict` rc 1 이다. 락의 manifest 단계는 error 를 모두 RED 로 하고, warning 도 RED 로 하되 **이 한 종류만 면제**한다(경로 `hooks.` 접두 + 메시지 접두 일치). 면제 이유: 훅 명령 문자열을 바꾸면 이 설계 범위 밖의 훅 실행 경로를 건드린다. 면제는 보고서 3부 행으로 후속 과제가 된다. **사용자 확인 2026-10-09 — 권장안 채택** | 11 · 12 |
| P12 | **새 사실** — 락 I 의 제외 | 제외는 넷이다. `**/CHANGELOG.md`(설계), 락 자신의 두 파일(Deferred 권고), 그리고 **`*/tests/fixtures/**`**. fixture 를 빼는 이유: fixture 는 기록된 데이터다. 옛 brief 의 `source: spec-distill conducting-interview v0.23.0` 출처 줄 약 190개와 plugin-audit `ac6_*.json` 의 감사 증거 경로 126개가 여기 든다. 고쳐 쓰면 당시 사실을 위조하게 된다(Non-goals «지난 기록»과 같은 이유). fixture 밖에서 옛 리터럴을 꼭 담아야 하는 테스트 두 곳은 리터럴을 조각으로 잇는다. **사용자 확인 2026-10-09 — 권장안 채택** | 2 · 3 |
| P13 | **새 사실** — check-staleness 규칙 (a) | `commands/` 가 사라지면 plugin-audit 의 「자기 `/command` 자기-주장」 규칙이 `/project-init` · `/plugin-audit` 자기 언급을 전부 dangling 으로 잘못 낸다. 규칙이 `skills/<name>/SKILL.md` 도 받게 고친다(plugin-audit 은 이미 major) | 8 |
| P14 | 감시줄 없음 문구 | 정책 행과 다른 문구 «사전 검사 결과 없음 — 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다» | 0 · 4~9 |
| P15 | 축 E 판정 출처 (E0) | `validate --strict` 는 skill frontmatter 미지 키를 잡지 않는다(아래 실측). 설계 ③대로 공식 키 20개 ∪ {`cost_class`} 손 목록을 쓴다 | 2 |

## 계획 단계 예비 실측 (2026-10-09)

CLI `2.1.294`, `--plugin-dir` 로 탐침 플러그인을 띄워 쟀다(설치본이 아니다). 머지 게이트는 Task 13 의 격리 설치본 실측이다.

| # | 측정 | 결과 |
|---|---|---|
| E0 | 미지 키 `bogus_key: 1` 을 심은 SKILL.md 에 `claude plugin validate --strict --json <plugin>` | **못 잡는다** — `contents` 에 그 skill 이 없다. 양성 대조로 description 이 없는 skill 은 warning 이 나왔다. `cost_class` 도 잡지 않는다 |
| 예비 M1 | 모델이 Skill 도구로 `bangprobe:probe-entry` 를 부른다 | 주입 본문에 `!` 출력이 박혀 왔다. `${CLAUDE_SKILL_DIR}/../../scripts/x.py` 경로가 풀렸고, cwd 는 세션 cwd 였다 |
| 예비 slash | 사용자 `/bangprobe:probe-entry hello` | 같다(1턴) |
| 사전 허용 없음 | `allowed-tools` 를 뺀 같은 skill(auto 모드) | `!` 가 돌지 않은 것으로 보였다. 모델이 Bash 로 같은 명령을 **대신 실행**했다. 보장되지 않는 조용한 대체이므로 사전 허용 항목은 필수다 |
| 공식 문서 | code.claude.com/docs/en/skills | inline `!` 는 줄 시작이나 공백 뒤에서만 인식된다. `${CLAUDE_SKILL_DIR}` 는 본문과 `allowed-tools` Bash 규칙에서 치환된다. 정책이 끄면 `[shell command execution disabled by policy]` 로 바뀐다. frontmatter 키는 20개다(Task 2 `SKILL_KEYS`) |

## Review Focus

spec 이 함의하지만 어느 Task 의 정상 경로 테스트도 건드리지 않는 입력이다. 사람에게 물릴 가능성이 높은 순서로 적었다. 각 줄의 테스트는 해당 Task 에 들어 있다.

1. **비-UTF-8 로캘(`LC_ALL=C`) + 한글이 든 cwd** — 감시줄을 출력하다 `UnicodeEncodeError` 가 나면 rc≠0 이고, 그러면 호출 전체가 조용히 끊긴다. 기대 동작: rc 0 에 `ok` 줄. → Task 1 테스트 8.
2. **seed 는 워크트리에 있는데 세션은 main 체크아웃에서 열었다** — `@` 상대경로가 풀리지 않는다. 기대 동작: 시도한 절대경로를 모두 담은 문구를 내고, 인터뷰를 시작하지 않는다. → Task 5 Step 1 단언 `시도: `.
3. **`@` 경로에 공백이 있다**(`@docs/my seed.md`) — 「한 토큰」 규칙 때문에 발동하지 않고, 문장으로 오인돼 인터뷰가 엉뚱하게 시작된다. 기대 동작: 공백이 있다고 알리고 멈춘다. → Task 5 Step 1 단언 `공백 없는 경로 한 토큰으로 다시 불러라`.
4. **kill switch 값이 `1` 근방이다**(`true` · ` 1` · `0` · 빈 값) — 진입 판정과 훅 판정이 갈리면, 사용자는 껐다고 믿는데 진입은 돈다. 기대 동작: 정본 `kill_switch_active` 의 DISABLE 판정과 같다. `DEVBREW_SKIP_HOOKS` 는 진입에 걸리지 않는다. → Task 1 테스트 7.
5. **cwd 가 삭제됐거나 `.git` 안이거나 git 이 없다** — 예외가 새면 rc≠0 이 된다. 기대 동작: 삭제된 cwd 는 rc 0 에 `error` 줄, 나머지 둘은 rc 0 에 `ok … root_source=cwd`. → Task 1 테스트 3 · 4 · 5.

## 파일 구조

| 파일 | 책임 | 생성/수정 Task |
|---|---|---|
| `shared/entry/entry_preflight.py` | 감시줄 한 줄 출력(정본) | 1 |
| `plugins/{spec-distill,plugin-audit,project-init}/scripts/entry_preflight.py` | 정본을 가리키는 상대 심볼릭 링크 | 1 |
| `shared/tests/test_entry_preflight.sh` | 사전 검사 단위 테스트 · kill switch 도출 대조 | 1 |
| `shared/entry/check_invocation_surface.py` | 축 A~I 판정 · `--report` · `--print-head` · `--emit-scanned` | 2 |
| `shared/tests/test_invocation_surface.sh` | 합성 리포 이빨 · 이 리포 GREEN · 실제 사본 변이 · manifest 단계 | 2 · 11 |
| `plugins/spec-distill/skills/{request-framing,spec-interview,spec-review}/` | 개명된 진입 skill 셋 | 3~6 |
| `plugins/plugin-audit/skills/plugin-audit/` | 개명된 진입 skill | 3 · 8 |
| `plugins/project-init/skills/project-init/SKILL.md` | 명령 본문을 옮긴 새 진입 skill | 9 |
| `docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md` | qg 핸드오프 보고서(3부) | 12 |

---

### Task 0: 기준선 · 설계 동기화

**Files:**
- Create: `~/.claude/sdd-mirror/unify-command-surface/baseline.sh` (리포 밖 — 워크트리 · job tmp 소실에 대비)
- Create: `~/.claude/sdd-mirror/unify-command-surface/baseline-<HEAD 7자>.tsv`
- Modify: `docs/superpowers/specs/2026-10-09-skill-only-surface-design.md`

**Interfaces:**
- Produces: `baseline.sh <out.tsv>`. 출력 형식은 `<경로>\t<rc>\t<실패 줄 수>` 이다. Task 14 가 같은 스크립트로 다시 재고 비교한다.

- [ ] **Step 1: 기준선 스크립트를 쓴다**

```bash
#!/bin/bash
# baseline.sh <out.tsv> — 파일별 rc 와 실패 줄 수. rc 만 잡으면 이미 RED 인 파일 안의 새 실패가 숨는다.
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/unify-command-surface || exit 1
out="$1"; : > "$out" || exit 1
run_capped() { perl -e 'alarm shift; exec @ARGV' 900 "$@"; }
git ls-files -- ':(glob)plugins/*/tests/test_*.sh' ':(glob)shared/tests/test_*.sh' | while IFS= read -r t; do
  log="$(run_capped bash "$t" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '✗|^FAIL|^not ok' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out"
done
git ls-files -- ':(glob)plugins/*/tests/test_*.py' ':(glob)shared/tests/test_*.py' | while IFS= read -r t; do
  log="$(cd "$(dirname "$t")" && run_capped python3 -m unittest -q "$(basename "$t" .py)" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '^(FAIL|ERROR):' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out"
done
git ls-files -- ':(glob)plugins/*/tests/*.mjs' | while IFS= read -r t; do
  log="$(run_capped node --test --test-reporter=tap "$t" 2>&1)"; rc=$?
  nf="$(printf '%s\n' "$log" | grep -c -E '^not ok' || true)"
  printf '%s\t%s\t%s\n' "$t" "$rc" "$nf" >> "$out"
done
echo "baseline rows: $(wc -l < "$out")"
```

- [ ] **Step 2: 기준선을 잰다** (background 로 돌려도 된다. 수십 분 걸릴 수 있다)

Run: `mkdir -p ~/.claude/sdd-mirror/unify-command-surface && bash ~/.claude/sdd-mirror/unify-command-surface/baseline.sh ~/.claude/sdd-mirror/unify-command-surface/baseline-$(git rev-parse --short=7 HEAD).tsv`
Expected: `baseline rows: <N>`(`:(glob)` 이라 fixture 아래 파일은 들지 않는다). rc≠0 행은 선재 RED 다(qg 선재 RED 포함). 행 수와 rc≠0 행 수를 기록한다.

- [ ] **Step 3: 설계문서를 동기화한다** — 아래 열 자리를 고친다. 결정의 실체는 위 «계획 단계 결정» 표다.

1. Handoff Context: `` brainstorming 결정: 이 문서 `## 결정 기록` B1~B12 `` → `B1~B13`.
2. §2 표의 project-init 행: `` 명령 본문을 옮긴 진입 skill, `cost_class` 선언 `` → `` 명령 본문을 옮긴 진입 skill, `cost_class: low`(agent · codex · 웹 없음 — 지출 게이트 없음) ``.
3. §3 표 마지막 행: `| 감시줄 없음 · 그 밖 | 위와 같은 문구로 멈춘다 |` → `| 감시줄 없음 · 그 밖 | «사전 검사 결과 없음 — 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다»를 보고하고 멈춘다 |`.
4. §3-2 불릿 끝에 다섯 줄을 더한다. ① 「`@` 로 시작하는데 공백이 섞였으면 풀지 않고 공백을 알리고 멈춘다」 ② 「성공하면 Read 원문 전체(frontmatter 포함)가 «풀린 입력»이다. 발동하지 않으면 «풀린 입력» = skill 이 받은 인자 그대로」 ③ 「3단계 trivia · seed 인식 · S1 · 본 절차는 «풀린 입력»을 읽는다」 ④ 「`/interview` Step 2.5 조언은 `spec-interview` 진입 단계 3.5 로 잇는다(완전명 `/spec-distill:request-framing`)」 ⑤ 「`@` 단계는 `spec-interview` · `request-framing` 에 둔다. `spec-review` 는 경로 앞의 `@` 하나만 뗀다. plugin-audit · project-init 에는 없다」.
5. §4 «살아 있는 표면» 불릿: `` `**/CHANGELOG.md` 는 제외한다. `` → `` 제외는 `**/CHANGELOG.md` · `*/tests/fixtures/**`(기록된 데이터) · 락 자신의 두 파일(`shared/entry/check_invocation_surface.py` · `shared/tests/test_invocation_surface.sh`) 넷뿐이다. 그 밖에 옛 이름 리터럴을 담아야 하는 테스트는 리터럴을 조각으로 잇는다. ``
6. §4 축 G 행 대상: `` 기계 코퍼스(`plugins/*/skills/**` · `plugins/*/hooks/**` · `plugins/*/scripts/**`) `` → `` 기계 코퍼스(`plugins/*/{skills,hooks,scripts,templates,references,agents}/**`) ``.
7. §4 «축 E 와 `validate --strict`» 문단 끝에 더한다: 「E0 실측(2026-10-09, CLI 2.1.294): 잡지 않는다 → ③ 손 목록. manifest 단계는 error 를 모두 RED 로 한다. warning 은 hooks 의 `${CLAUDE_PLUGIN_ROOT}` 따옴표 경고 한 종류만 면제하고, 그 면제는 보고서 3부 행이 된다」.
8. §6 보고서 불릿을 셋으로 바꾼다. 3부 «락 밖 qg 위반»(RC4 · RC5 · RC6 · RC8 · RC10 · RC18 + manifest 면제 행)을 추가한다. 그리고 「대조 기준: v10 설계 `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` @ `5eccf37c82ee6f000baefb0e8e972733ba07eb38`(브랜치 `feature/qg-v10-cleanup`)」를 적는다.
9. AC7 → `` AC7 qg 밖 살아 있는 표면에서 옛 이름이 0건이다(락 I). qg 안의 잔여는 락 `--report` 표를 거쳐 §6 보고서에 행으로 실린다. 미실행 seed(판별 규칙은 plan P10)의 핸드오프 줄도 완전명이다 — 2026-10-09 실측 0줄. ``
10. Files to Modify: 「필요 시 `plugins/plugin-audit/scripts/kill_switch_active.py`(copy-of) · 」를 지운다. 수정 목록에 `conducting-interview/references/seed-input.md` · `finishing.md` 의 «풀린 입력» 치환, `plugins/plugin-audit/scripts/check-staleness.py` 규칙 (a), 템플릿 셋(`interview-seed-audit-template.md` · `project/charter.md` · `project/conventions.md`)을 더한다. `### Deferred to plan` 제목 바로 아래에 한 줄을 더한다: 「10건 전부 `docs/superpowers/plans/2026-10-09-skill-only-surface.md` 의 «계획 단계 결정» 표가 흡수했다」.

- [ ] **Step 4: 커밋**

```bash
git add docs/superpowers/specs/2026-10-09-skill-only-surface-design.md docs/superpowers/plans/2026-10-09-skill-only-surface.md
git commit -m "docs(spec): skill-only surface — absorb deferred-to-plan into design + plan" -- docs/superpowers/specs/2026-10-09-skill-only-surface-design.md docs/superpowers/plans/2026-10-09-skill-only-surface.md
git show --stat HEAD | tail -3   # 2 files
```

---

### Task 1: 공유 사전 검사 `entry_preflight.py`

**Files:**
- Create: `shared/entry/entry_preflight.py`
- Create: `plugins/spec-distill/scripts/entry_preflight.py` · `plugins/plugin-audit/scripts/entry_preflight.py` · `plugins/project-init/scripts/entry_preflight.py` (심볼릭 링크 `../../../shared/entry/entry_preflight.py`)
- Create: `shared/tests/test_entry_preflight.sh`
- Modify: `shared/README.md` (디렉토리 표)

**Interfaces:**
- Produces: `python3 <plugin>/scripts/entry_preflight.py <plugin> <skill>` 은 **항상 rc 0** 이고 stdout 에 정확히 한 줄을 낸다:
  - `[devbrew-entry] ok plugin=<p> skill=<s> root=<절대경로>` (git 밖이면 끝에 ` root_source=cwd`)
  - `[devbrew-entry] disabled plugin=<p> skill=<s> switch=DEVBREW_<P>_DISABLE=1`
  - `[devbrew-entry] error plugin=<p> skill=<s> reason=<한 줄>`

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `shared/tests/test_entry_preflight.sh`

```bash
#!/usr/bin/env bash
# guards: shared/entry/entry_preflight.py plugins/*/scripts/entry_preflight.py shared/killswitch/kill_switch_active.py
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
S="$ROOT/shared/entry/entry_preflight.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' shared/entry/entry_preflight.py shared/killswitch/kill_switch_active.py \
    plugins/spec-distill/scripts/entry_preflight.py plugins/plugin-audit/scripts/entry_preflight.py \
    plugins/project-init/scripts/entry_preflight.py
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
PY="$(command -v python3)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/entrypre.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT
CLEAN="env -u DEVBREW_SPEC_DISTILL_DISABLE -u DEVBREW_PLUGIN_AUDIT_DISABLE -u DEVBREW_PROJECT_INIT_DISABLE -u DEVBREW_SKIP_HOOKS"

# 1. 리포 안 — 세 배포 지점이 정본 링크이고 ok 줄의 root 가 리포 루트다
for p in spec-distill plugin-audit project-init; do
  link="$ROOT/plugins/$p/scripts/entry_preflight.py"
  tgt=""
  [ -L "$link" ] && tgt="$(cd "$(dirname "$link")" && cd "$(dirname "$(readlink "$link")")" && pwd -P)/$(basename "$(readlink "$link")")"
  assert_eq "$tgt" "$S" "$p: 배포 지점이 정본을 가리키는 심볼릭 링크다"
  out="$(cd "$ROOT" && $CLEAN "$PY" "$link" "$p" x-skill)"; rc=$?
  assert_eq "$rc" "0" "$p: rc 0"
  assert_eq "$out" "[devbrew-entry] ok plugin=$p skill=x-skill root=$ROOT" "$p: ok 감시줄 + 리포 루트"
done

# 2. 비-git 디렉토리 — cwd 로 떨어지되 ok
mkdir -p "$TMP/plain"
PLAIN="$(cd "$TMP/plain" && pwd -P)"
out="$(cd "$PLAIN" && $CLEAN "$PY" "$S" project-init project-init)"; rc=$?
assert_eq "$rc" "0" "비-git: rc 0"
assert_eq "$out" "[devbrew-entry] ok plugin=project-init skill=project-init root=$PLAIN root_source=cwd" "비-git: root_source=cwd"

# 3. .git 안 — 작업 트리 밖이라 cwd 로
git init -q "$TMP/repo"
out="$(cd "$TMP/repo/.git" && $CLEAN "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" ".git 안: rc 0"
assert_contains "$out" "root_source=cwd" ".git 안: root_source=cwd"

# 4. git 부재
out="$(cd "$PLAIN" && $CLEAN PATH=/nonexistent "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "git 부재: rc 0"
assert_contains "$out" "root_source=cwd" "git 부재: cwd 로"

# 5. 삭제된 cwd — error 줄, rc 0
mkdir -p "$TMP/gone"
out="$(cd "$TMP/gone" && rmdir "$TMP/gone" && $CLEAN "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "삭제된 cwd: rc 0"
assert_contains "$out" "[devbrew-entry] error plugin=spec-distill skill=s reason=" "삭제된 cwd: error 줄"

# 6. 사용법 — 인자 개수가 틀려도 rc 0 + error 줄
out="$($CLEAN "$PY" "$S")"; rc=$?
assert_eq "$rc" "0" "인자 없음: rc 0"
assert_contains "$out" "[devbrew-entry] error plugin=? skill=? reason=usage" "인자 없음: error 줄"

# 7. kill switch — 값이 정확히 "1" 일 때만. 도출은 정본 kill_switch_active 의 DISABLE 판정과 같다
for p in spec-distill plugin-audit project-init; do
  var="DEVBREW_$(printf '%s' "$p" | tr 'a-z-' 'A-Z_')_DISABLE"
  for v in 1 true " 1" 0 ""; do
    got="$(cd "$PLAIN" && $CLEAN "$var=$v" "$PY" "$S" "$p" s | awk '{print $2}')"
    want="$($CLEAN "$var=$v" "$PY" -c 'import sys; sys.path.insert(0, sys.argv[1]); from kill_switch_active import kill_switch_active as k; print("disabled" if k(sys.argv[2], "_") else "ok")' "$ROOT/shared/killswitch" "$p")"
    assert_eq "$got" "$want" "$p $var='$v': 진입 판정 = 정본 DISABLE 판정"
  done
done
out="$(cd "$PLAIN" && $CLEAN DEVBREW_PROJECT_INIT_DISABLE=1 "$PY" "$S" project-init project-init)"
assert_eq "$out" "[devbrew-entry] disabled plugin=project-init skill=project-init switch=DEVBREW_PROJECT_INIT_DISABLE=1" "disabled 줄 모양"
out="$(cd "$PLAIN" && $CLEAN DEVBREW_SKIP_HOOKS="spec-distill:spec-review,spec-distill:_" "$PY" "$S" spec-distill spec-review | awk '{print $2}')"
assert_eq "$out" "ok" "DEVBREW_SKIP_HOOKS 는 진입에 걸리지 않는다(D1.1)"

# 8. 비-UTF-8 로캘 + 한글 cwd — 출력 인코딩 실패가 rc≠0 으로 새지 않는다
mkdir -p "$TMP/한글 경로"
out="$(cd "$TMP/한글 경로" && $CLEAN -u PYTHONIOENCODING -u PYTHONUTF8 LC_ALL=C LANG=C "$PY" "$S" spec-distill s)"; rc=$?
assert_eq "$rc" "0" "LC_ALL=C + 한글 cwd: rc 0"
assert_contains "$out" "[devbrew-entry] ok plugin=spec-distill skill=s root=" "LC_ALL=C + 한글 cwd: ok 줄"

# 9. 3.8 문법 바닥 — macOS 시스템 python3 에서도 파싱된다
"$PY" -c 'import ast,sys; ast.parse(open(sys.argv[1],encoding="utf-8").read(), feature_version=(3,8))' "$S"
assert_eq "$?" "0" "3.8 문법으로 파싱된다"

# 10. 형제 import 없음 — 링크로 실행되면 sys.path[0] 이 정본 디렉토리다
bad="$(grep -nE '^[[:space:]]*(from|import)[[:space:]]' "$S" | grep -vE '^[0-9]+:(import (os|subprocess|sys)|from __future__ import annotations)$' || true)"
assert_eq "$bad" "" "import 는 os · subprocess · sys(+ __future__) 뿐이다"

finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash shared/tests/test_entry_preflight.sh`
Expected: FAIL — 링크와 정본이 없어 `✗ spec-distill: 배포 지점이 정본을 가리키는 심볼릭 링크다` 등이 나오고 rc≠0.

- [ ] **Step 3: 정본을 쓴다** — `shared/entry/entry_preflight.py`

```python
#!/usr/bin/env python3
"""devbrew 진입 skill 사전 검사 — 감시줄 한 줄을 낸다.

진입 skill 의 사전 검사 줄이 상수 인자 `<plugin> <skill>` 로 부른다. 사용자 입력은 받지 않는다.

rc 는 늘 0 이다. rc≠0 이면 플랫폼이 skill 호출 전체를 끊고, 헤드리스에서는 그것이 0턴 rc=0
조용한 실패가 된다. 그래서 어떤 실패도 `error` 감시줄로 바꾼다.

형제 모듈을 import 하지 않는다. 심볼릭 링크로 실행되면 sys.path[0] 이 정본 디렉토리
(`shared/entry/`)라서 형제가 풀리지 않는다. kill switch 변수명 도출은
`shared/killswitch/kill_switch_active.py` 와 같다(`-`→`_`, 대문자화, 값이 정확히 "1").
`shared/tests/test_entry_preflight.sh` 가 두 도출을 대조한다.
"""
from __future__ import annotations

import os
import subprocess
import sys

PREFIX = "[devbrew-entry]"


def _one_line(value):
    return " ".join(str(value).split())


def switch_name(plugin):
    return "DEVBREW_" + plugin.upper().replace("-", "_") + "_DISABLE"


def find_root(cwd):
    """(루트, 출처). git 작업 트리면 그 최상위, 아니면 cwd."""
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=cwd, capture_output=True, text=True, timeout=10,
        )
    except (OSError, subprocess.SubprocessError, ValueError):
        return cwd, "cwd"
    top = proc.stdout.strip()
    if proc.returncode != 0 or not top:
        return cwd, "cwd"
    return top, "git"


def sentinel(argv, environ, cwd):
    if len(argv) != 2 or not all(argv):
        return "{0} error plugin=? skill=? reason=usage: entry_preflight.py <plugin> <skill>".format(PREFIX)
    plugin, skill = argv
    head = "plugin={0} skill={1}".format(_one_line(plugin), _one_line(skill))
    name = switch_name(plugin)
    if environ.get(name) == "1":
        return "{0} disabled {1} switch={2}=1".format(PREFIX, head, name)
    root, source = find_root(cwd)
    line = "{0} ok {1} root={2}".format(PREFIX, head, _one_line(root))
    if source == "cwd":
        line += " root_source=cwd"
    return line


def main():
    argv = sys.argv[1:]
    try:
        try:
            sys.stdout.reconfigure(encoding="utf-8", errors="backslashreplace")
        except (AttributeError, ValueError):
            pass
        line = sentinel(argv, os.environ, os.getcwd())
    except Exception as exc:  # noqa: BLE001 — 어떤 실패도 rc≠0 으로 새지 않는다
        plugin = _one_line(argv[0]) if len(argv) > 0 and argv[0] else "?"
        skill = _one_line(argv[1]) if len(argv) > 1 and argv[1] else "?"
        line = "{0} error plugin={1} skill={2} reason={3}".format(
            PREFIX, plugin, skill, _one_line("{0}: {1}".format(type(exc).__name__, exc)))
    try:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except Exception:  # noqa: BLE001
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

그다음 링크 셋을 만들고 실행 비트를 준다:

```bash
chmod +x shared/entry/entry_preflight.py
ln -s ../../../shared/entry/entry_preflight.py plugins/spec-distill/scripts/entry_preflight.py
ln -s ../../../shared/entry/entry_preflight.py plugins/plugin-audit/scripts/entry_preflight.py
ln -s ../../../shared/entry/entry_preflight.py plugins/project-init/scripts/entry_preflight.py
```

`shared/README.md` 의 `## 디렉토리` 표에서 `killswitch/` 행 바로 아래에 한 행을 넣는다:

```
| `entry/` | 진입 skill 사전 검사(`entry_preflight.py`, 세 플러그인에 심볼릭 링크) · 호출 표면 정합 락(`check_invocation_surface.py`) |
```

- [ ] **Step 4: 통과를 확인한다**

Run: `bash shared/tests/test_entry_preflight.sh && git add shared/entry plugins/*/scripts/entry_preflight.py && bash shared/tests/test_copy_of_contract.sh | tail -3`
Expected: 첫 테스트 `Fail: 0`. copy-of 락 `Fail: 0`, 그리고 `symlink-∀: shared/entry/entry_preflight.py — 배포 지점 3건 도출·검사` 줄이 보인다. 이 시점에는 산문 도출이 0건이라 «산문 도출 0건 < 구조 도출 3건» 알림이 나오는데, 알림일 뿐 RED 가 아니다.

- [ ] **Step 5: 커밋**

```bash
git add shared/tests/test_entry_preflight.sh shared/README.md
git commit -m "feat(shared): entry_preflight — sentinel preflight for entry skills" -- shared/entry/entry_preflight.py shared/tests/test_entry_preflight.sh shared/README.md plugins/spec-distill/scripts/entry_preflight.py plugins/plugin-audit/scripts/entry_preflight.py plugins/project-init/scripts/entry_preflight.py
git show --stat HEAD | tail -3   # 6 files
```

(이 커밋은 세 플러그인 디렉토리를 건드린다. bump 는 각 플러그인 Task(7 · 8 · 9)가 같은 브랜치에서 한다. PR 단위 bump 규칙은 머지 시점에 성립한다.)

---

### Task 2: 표면 정합 락 (축 A~I) — 합성 리포 이빨

**Files:**
- Create: `shared/entry/check_invocation_surface.py`
- Create: `shared/tests/test_invocation_surface.sh` (1부 합성 리포 · 2부 이 리포. 3부 · 4부는 Task 11)

**Interfaces:**
- Consumes: `entry_preflight.py` 의 경로 관례 `plugins/<p>/scripts/entry_preflight.py` (Task 1).
- Produces:
  - `check_invocation_surface.py [--root DIR]` → rc 0(GREEN) / 1(RED) / 2(내부 오류). RED 줄 형식은 `RED <축> <경로>:<줄> <사유>` 이고, 끝에 범위 문장이 붙는다.
  - `--report` → qg 보고 표(마크다운, 열 `# · 축 · 위치 · 위반 · v10 설계`).
  - `--print-head <plugin> <skill>` → 사전 허용 항목 + `---` + 빈 줄 + 사전 검사 줄 + 빈 줄 + `## 진입 단계`. Task 4~9 가 이 출력을 붙인다.
  - `--emit-scanned` → 실제로 읽은 경로 목록.

- [ ] **Step 1: 실패하는 테스트를 쓴다** — `shared/tests/test_invocation_surface.sh`

```bash
#!/usr/bin/env bash
# guards: plugins/** shared/** CLAUDE.md README.md docs/philosophy/** docs/plugin-authoring.md
#
# 호출 표면 정합 락의 집행과 이빨.
#  1부 합성 리포 — 양성 대조 GREEN · 축 A~I 변이마다 RED + 그 축의 태그 · 음성 대조 GREEN
#  2부 이 리포 — 무변이 GREEN
#  3부 이 리포의 `git clone --no-local` 사본에 실제 변이 (Task 11)
#  4부 `claude plugin validate --strict` manifest 단계 (Task 11)
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/shared/entry/check_invocation_surface.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  python3 "$LOCK" --root "$ROOT" --emit-scanned
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/invsurf.XXXXXX")" || exit 1
[ -n "$TMP" ] && [ -d "$TMP" ] || exit 1
trap 'rm -rf "$TMP"' EXIT

mk_repo() {   # mk_repo <dir> — 축 A~I 를 모두 만족하는 최소 리포
  python3 - "$1" "$LOCK" <<'PY'
import os, subprocess, sys
d, lock = sys.argv[1], sys.argv[2]
def w(rel, text):
    p = os.path.join(d, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "w", encoding="utf-8") as fh:
        fh.write(text)
def head(plugin, skill):
    return subprocess.run([sys.executable, lock, "--print-head", plugin, skill],
                          capture_output=True, text=True, check=True).stdout
ENTRY = [("spec-distill", "request-framing", False), ("spec-distill", "spec-interview", False),
         ("spec-distill", "spec-review", False), ("plugin-audit", "plugin-audit", True),
         ("project-init", "project-init", True)]
for p, s, user_only in ENTRY:
    fm = "---\nname: %s\ndescription: x\ncost_class: low\n%s" % (s, "disable-model-invocation: true\n" if user_only else "")
    rows = ("\n| `[devbrew-entry] ok …` | 간다 |\n| `[devbrew-entry] disabled …` | 멈춘다 |\n"
            "| `[devbrew-entry] error …` | 멈춘다 |\n| `[shell command execution disabled by policy]` | 멈춘다 |\n")
    w("plugins/%s/skills/%s/SKILL.md" % (p, s), fm + head(p, s) + rows + "\n## 본문\n\n/%s:%s 로 부른다.\n" % (p, s))
    w("plugins/%s/scripts/entry_preflight.py" % p, "# stub\n")
w("plugins/spec-distill/skills/reviewing-brief/SKILL.md",
  "---\nname: reviewing-brief\ndescription: x\ncost_class: medium\nuser-invocable: false\n---\n\nbody\n")
w("plugins/quality-gates/commands/qg.md", "---\ndescription: qg\n---\n")
w("plugins/spec-distill/README.md", "# spec-distill\n\n`/spec-interview` 를 친다.\n")
w("README.md", "# r\n")
subprocess.run(["git", "init", "-q", d], check=True)
PY
}
run_lock() { python3 "$LOCK" --root "$1" 2>&1; }
expect_green() {   # expect_green <dir> <msg>
  local out rc
  out="$(run_lock "$1")"; rc=$?
  if [ "$rc" = "0" ]; then ok "$2"; else no "$2 (rc=$rc)"; printf '%s\n' "$out" | head -15; fi
}
expect_red() {     # expect_red <dir> <axis> <msg>
  local out rc
  out="$(run_lock "$1")"; rc=$?
  if [ "$rc" = "1" ] && printf '%s\n' "$out" | grep -q "^RED $2 "; then ok "$3"
  else no "$3 (rc=$rc, 축 $2 태그 없음)"; printf '%s\n' "$out" | head -10; fi
}
variant() {        # variant <name> — 좋은 리포의 사본
  rm -rf "$TMP/v-$1"; cp -R "$TMP/good" "$TMP/v-$1"
}
edit() {           # edit <file> <old> <new> — 첫 일치 하나를 바꾼다. 못 심으면 계측기 고장으로 센다
  python3 - "$1" "$2" "$3" <<'PY'
import sys
p, old, new = sys.argv[1:4]
t = open(p, encoding="utf-8").read()
if old not in t:
    sys.exit(1)
open(p, "w", encoding="utf-8").write(t.replace(old, new, 1))
PY
  [ "$?" = "0" ] || no "변이 심기 실패: $1 에 '$2' 가 없다"
}
put() { mkdir -p "$(dirname "$1")"; printf '%s\n' "$2" >> "$1"; }

# ── 1부: 합성 리포 ──────────────────────────────────────────────
mk_repo "$TMP/good"
SR="plugins/spec-distill/skills/spec-review/SKILL.md"
PA="plugins/plugin-audit/skills/plugin-audit/SKILL.md"
out="$(run_lock "$TMP/good")"; rc=$?
if [ "$rc" != "0" ]; then
  no "양성 대조: 좋은 리포가 GREEN 이 아니다 (rc=$rc) — 아래 변이 RED 는 증거가 아니다"
  printf '%s\n' "$out" | head -20
  finish; exit 1
fi
ok "양성 대조: 좋은 리포 GREEN"

variant a1; edit "$TMP/v-a1/$SR" "name: spec-review" "name: spec-reviewer"; expect_red "$TMP/v-a1" A "A 반전: name ≠ 디렉토리"
variant a2; mkdir -p "$TMP/v-a2/plugins/spec-distill/skills/reviewing-docs"
cp "$TMP/v-a2/$SR" "$TMP/v-a2/plugins/spec-distill/skills/reviewing-docs/SKILL.md"
edit "$TMP/v-a2/plugins/spec-distill/skills/reviewing-docs/SKILL.md" "name: spec-review" "name: reviewing-docs"
expect_red "$TMP/v-a2" A "A 추가: 동명사 진입 skill"
variant b1; edit "$TMP/v-b1/plugins/spec-distill/skills/reviewing-brief/SKILL.md" "name: reviewing-brief" "name: brief-review"
expect_red "$TMP/v-b1" B "B 반전: 내부 skill 이 동명사가 아니다"
BANG_SR="$(python3 "$LOCK" --print-head spec-distill spec-review | sed -n '5p')"
variant c1; edit "$TMP/v-c1/$SR" "$BANG_SR" ""; expect_red "$TMP/v-c1" C "C 삭제: 사전 검사 줄 없음"
variant c2; edit "$TMP/v-c2/$SR" "## 진입 단계" "$BANG_SR

## 진입 단계"; expect_red "$TMP/v-c2" C "C 추가: 사전 검사 줄 둘"
variant c3; edit "$TMP/v-c3/$SR" "spec-distill spec-review\`" "spec-distill spec-interview\`"; expect_red "$TMP/v-c3" C "C 표기: 인자 바꿔치기"
variant c4; edit "$TMP/v-c4/$SR" "allowed-tools:
" "allowed-tools:
  - Read
"; expect_red "$TMP/v-c4" C "C 추가: allowed-tools 에 다른 도구"
variant c5; edit "$TMP/v-c5/$SR" "[shell command execution disabled by policy]" "정책"; expect_red "$TMP/v-c5" C "C 삭제: 정책 판독 행"
variant c6; edit "$TMP/v-c6/$SR" "## 진입 단계" "## 진입"; expect_red "$TMP/v-c6" C "C 삭제: 진입 단계 절"
variant c7; edit "$TMP/v-c7/$SR" "## 본문" "## 본문

위 \`!\` 줄이 남긴 자리"; expect_red "$TMP/v-c7" C "C 추가: 산문의 느낌표-백틱"
variant d1; put "$TMP/v-d1/plugins/spec-distill/skills/spec-review/references/x.md" '!`echo $ARGUMENTS`'
expect_red "$TMP/v-d1" D "D 추가: 사전 검사 줄에 \$ARGUMENTS"
variant d2; put "$TMP/v-d2/plugins/spec-distill/references/y.md" '```!
echo ${ARGUMENTS}
```'
expect_red "$TMP/v-d2" D "D 표기: \`\`\`! 블록의 \${ARGUMENTS}"
variant d3; put "$TMP/v-d3/plugins/spec-distill/skills/spec-review/references/z.md" 'x !`echo $1`'
expect_red "$TMP/v-d3" D "D 표기: 공백 뒤 사전 검사 줄의 \$1"
variant e1; edit "$TMP/v-e1/$SR" "cost_class: low" "cost_class: low
bogus_key: 1"; expect_red "$TMP/v-e1" E "E 추가: 미지 키"
variant f1; edit "$TMP/v-f1/$SR" "cost_class: low" "cost_class: low
disable-model-invocation: true"; expect_red "$TMP/v-f1" F "F 추가: spec-review 를 사용자 전용으로"
variant f2; edit "$TMP/v-f2/$PA" "disable-model-invocation: true
" ""; expect_red "$TMP/v-f2" F "F 반전: plugin-audit 에서 제거"
variant g1; put "$TMP/v-g1/plugins/spec-distill/scripts/hint.py" "print('run /spec-review now')"; expect_red "$TMP/v-g1" G "G 추가: bare 진입 이름"
variant g2; put "$TMP/v-g2/plugins/spec-distill/skills/spec-review/references/h.md" '`/spec-distill:nonexistent` 로'; expect_red "$TMP/v-g2" G "G 표기: 풀리지 않는 완전명"
variant g3; put "$TMP/v-g3/plugins/project-init/templates/t.md" '`/project-init` step'; expect_red "$TMP/v-g3" G "G 추가: 템플릿의 bare 이름"
variant h1; put "$TMP/v-h1/plugins/spec-distill/commands/x.md" "---"; expect_red "$TMP/v-h1" H "H 추가: qg 밖 commands/"
variant i1; put "$TMP/v-i1/plugins/spec-distill/README.md" "conducting-interview 를 부른다"; expect_red "$TMP/v-i1" I "I 추가: 옛 skill 이름"
variant i2; put "$TMP/v-i2/plugins/spec-distill/README.md" '`/interview@x`'; expect_red "$TMP/v-i2" I "I 표기: 옛 호출 토큰"
variant i3; rm -rf "$TMP/v-i3/plugins/spec-distill/skills/spec-review"; expect_red "$TMP/v-i3" I "I 삭제: 새 skill 디렉토리(양성 짝)"

# qg 보고 모드와 그 수명
variant q1; put "$TMP/v-q1/plugins/quality-gates/README.md" "framing-requests"
expect_green "$TMP/v-q1" "qg 보고 모드: qg 안 옛 이름은 RED 가 아니다"
rep="$(python3 "$LOCK" --root "$TMP/v-q1" --report)"
assert_contains "$rep" "plugins/quality-gates/README.md" "qg 보고 모드: --report 표에 행으로 실린다"
rm -rf "$TMP/v-q1/plugins/quality-gates/commands"
expect_red "$TMP/v-q1" I "qg 수명: commands/ 가 사라지면 같은 위반이 RED"

# 음성 대조 — 경로 조각 · fixture · CHANGELOG · 락 자신 · README 의 짧은 이름은 GREEN
variant n1
put "$TMP/v-n1/plugins/spec-distill/scripts/n.py" "# docs/superpowers/interview/x.md · plugins/plugin-audit/README.md · skills/spec-review/SKILL.md"
put "$TMP/v-n1/plugins/spec-distill/tests/fixtures/f.md" "source: spec-distill conducting-interview v0.23.0"
put "$TMP/v-n1/plugins/spec-distill/CHANGELOG.md" '`/interview` 제거'
put "$TMP/v-n1/shared/entry/check_invocation_surface.py" "reviewing-spec"
expect_green "$TMP/v-n1" "음성 대조: 경로 조각 · fixture · CHANGELOG · 락 자신 · README 짧은 이름"

# ── 2부: 이 리포 ────────────────────────────────────────────────
out="$(run_lock "$ROOT")"; rc=$?
assert_eq "$rc" "0" "이 리포: 표면 정합 GREEN"
[ "$rc" = "0" ] || printf '%s\n' "$out" | head -40

finish
```

- [ ] **Step 2: 실패를 확인한다**

Run: `bash shared/tests/test_invocation_surface.sh`
Expected: FAIL — `check_invocation_surface.py` 가 없어 `mk_repo` 의 `--print-head` 가 실패하고 양성 대조 RED.

- [ ] **Step 3: 락을 쓴다** — `shared/entry/check_invocation_surface.py`

```python
#!/usr/bin/env python3
"""devbrew 호출 표면 정합 락 — 설계 docs/superpowers/specs/2026-10-09-skill-only-surface-design.md §4.

축 A~I 를 git 이 아는 파일(추적 + 미추적 비무시)에서 도출해 잰다. quality-gates 파일의 위반은
`plugins/quality-gates/commands/` 가 있는 동안 보고 모드다 — RED 대신 `--report` 표의 행이 된다.

  check_invocation_surface.py [--root DIR]                 위반이 있으면 rc 1
  check_invocation_surface.py --report [--root DIR]        qg 보고 표(마크다운)
  check_invocation_surface.py --emit-scanned [--root DIR]  실제로 읽은 경로
  check_invocation_surface.py --print-head <plugin> <skill>
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

QG = "plugins/quality-gates/"
QG_COMMANDS = "plugins/quality-gates/commands/"
SELF_FILES = frozenset({"shared/entry/check_invocation_surface.py", "shared/tests/test_invocation_surface.sh"})
SCOPE_ON = "qg 는 plugins/quality-gates/commands/ 가 있는 동안 보고만 된다(--report)"
SCOPE_OFF = "qg 보고 모드 종료 — plugins/quality-gates/commands/ 가 없어 qg 위반도 RED 다"

ENTRY_SKILLS = (
    ("spec-distill", "request-framing"),
    ("spec-distill", "spec-interview"),
    ("spec-distill", "spec-review"),
    ("plugin-audit", "plugin-audit"),
    ("project-init", "project-init"),
)
USER_ONLY = frozenset({("plugin-audit", "plugin-audit"), ("project-init", "project-init")})

# 축 E — 공식 skill frontmatter 키 20개 ∪ {cost_class}.
# 출처: https://code.claude.com/docs/en/skills frontmatter reference (확인 2026-10-09).
# `claude plugin validate --strict` 는 미지 키를 잡지 않는다(E0 실측 2026-10-09, CLI 2.1.294).
# 플랫폼이 키를 더하면 이 목록이 거짓 RED 를 낸다 — 출처를 다시 확인하고 갱신한다.
SKILL_KEYS = frozenset({
    "name", "description", "when_to_use", "argument-hint", "arguments",
    "disable-model-invocation", "user-invocable", "allowed-tools", "disallowed-tools",
    "model", "effort", "context", "agent", "background", "hooks", "paths", "shell",
    "metadata", "license", "compatibility", "cost_class",
})

_SCRIPT = '"${{CLAUDE_SKILL_DIR}}/../../scripts/entry_preflight.py" {plugin} {skill}'
BANG_TMPL = "!`python3 " + _SCRIPT + "`"
ALLOW_TMPL = "Bash(python3 " + _SCRIPT + ")"
ENTRY_HEADING = "## 진입 단계"
SENTINEL_ROWS = (
    "[devbrew-entry] ok",
    "[devbrew-entry] disabled",
    "[devbrew-entry] error",
    "[shell command execution disabled by policy]",
)

SKILL_PATH_RE = re.compile(r"^plugins/([^/]+)/skills/([^/]+)/SKILL\.md$")
COMMAND_PATH_RE = re.compile(r"^plugins/([^/]+)/commands/([^/]+)\.md$")
KEBAB_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)+$")
BANG_RE = re.compile(r"(?:^|(?<=\s))!`([^`\n]+)`")       # 플랫폼 규칙: 줄 시작 또는 공백 뒤
FENCE_BANG_RE = re.compile(r"^\s*```!\s*$")
USER_ARG_RE = re.compile(r"\$(?:ARGUMENTS|\{ARGUMENTS|[0-9]|\{[0-9]|\[[0-9])")
_LEAD = r"(?:^|(?<=[\s`'\"(「]))"
_TRAIL = r"(?=$|[\s`'\"@)」])"
FULL_CALL_RE = re.compile(_LEAD + r"/([a-z0-9][a-z0-9-]*):([a-z0-9][a-z0-9-]*)" + _TRAIL)
OLD_NAME_RE = re.compile(
    r"conducting-interview|framing-requests|reviewing-spec|auditing-plugins"
    r"|commands/(?:interview|request-framing|plugin-audit|project-init)\.md")
OLD_CALL_RE = re.compile(_LEAD + r"/interview" + _TRAIL)
MACHINE_DIRS = frozenset({"skills", "hooks", "scripts", "templates", "references", "agents"})
LIVE_TOP = frozenset({"CLAUDE.md", "README.md", "docs/plugin-authoring.md"})
LIVE_PREFIX = ("plugins/", "shared/", "docs/philosophy/")


class Ledger:
    def __init__(self, report_mode):
        self.report_mode = report_mode
        self.red = []
        self.rep = []

    def add(self, axis, path, line, msg):
        row = (axis, path, line, msg)
        if self.report_mode and path.startswith(QG):
            self.rep.append(row)
        else:
            self.red.append(row)


def git_files(root):
    proc = subprocess.run(
        ["git", "-C", root, "ls-files", "-z", "--cached", "--others", "--exclude-standard"],
        capture_output=True, check=True)
    names = set(p for p in proc.stdout.decode("utf-8", "surrogateescape").split("\0") if p)
    return sorted(p for p in names if os.path.lexists(os.path.join(root, p)))


def frontmatter(text):
    """(최상위 키 → 값 줄 목록, 본문 첫 줄의 0-기반 인덱스). 없거나 안 닫히면 ({}, 0)."""
    lines = text.split("\n")
    if not lines or lines[0].strip() != "---":
        return {}, 0
    keys, cur = {}, None
    for i in range(1, len(lines)):
        ln = lines[i]
        if ln.strip() == "---":
            return keys, i + 1
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_-]*):(.*)$", ln)
        if m:
            cur = m.group(1)
            val = m.group(2).strip()
            keys[cur] = [val] if val else []
        elif cur is not None and ln.strip():
            keys[cur].append(ln.strip())
    return {}, 0


def first(fm, key):
    vals = fm.get(key) or [""]
    return vals[0].strip().strip("\"'")


def list_items(vals):
    return [v[2:].strip() for v in vals if v.startswith("- ")]


def is_internal(fm):
    return first(fm, "user-invocable").lower() == "false"


class Scan:
    def __init__(self, root):
        self.root = root
        self.files = git_files(root)
        self.fset = frozenset(self.files)
        self.scanned = set()
        self.L = Ledger(any(f.startswith(QG_COMMANDS) for f in self.files))
        self.skills = {}
        for rel in self.files:
            m = SKILL_PATH_RE.match(rel)
            if not m:
                continue
            text = self.read(rel)
            if text is None:
                continue
            fm, body_at = frontmatter(text)
            self.skills[(m.group(1), m.group(2))] = (rel, text, fm, body_at)
        self.plugins = frozenset(f.split("/")[1] for f in self.files
                                 if f.startswith("plugins/") and f.count("/") >= 2)

    def read(self, rel):
        path = os.path.join(self.root, rel)
        if not os.path.isfile(path):
            return None
        try:
            with open(path, encoding="utf-8", errors="replace") as fh:
                text = fh.read()
        except OSError:
            return None
        self.scanned.add(rel)
        return text

    def run(self):
        self.axis_skills()
        self.axis_d()
        self.axis_g()
        self.axis_h()
        self.axis_i()
        return self.L

    # 축 A · B · C · E · F
    def axis_skills(self):
        L = self.L
        for (plugin, d), (rel, text, fm, body_at) in sorted(self.skills.items()):
            if not fm:
                L.add("A", rel, 1, "frontmatter 가 없거나 닫히지 않았다")
                continue
            for key in fm:
                if key not in SKILL_KEYS:
                    L.add("E", rel, 1, "frontmatter 키 '%s' 는 공식 키 ∪ {cost_class} 밖이다" % key)
            name = first(fm, "name")
            head_word = name.split("-")[0]
            if is_internal(fm):
                if not head_word.endswith("ing"):
                    L.add("B", rel, 1, "내부 skill(user-invocable: false) '%s' 의 첫 단어가 동명사가 아니다" % name)
                continue
            if name != d:
                L.add("A", rel, 1, "name '%s' 이 디렉토리 '%s' 와 다르다" % (name, d))
            if not KEBAB_RE.match(name):
                L.add("A", rel, 1, "진입 skill 이름 '%s' 이 kebab 두 단어 이상이 아니다" % name)
            elif head_word.endswith("ing"):
                L.add("A", rel, 1, "진입 skill 이름 '%s' 의 첫 단어가 동명사다 — 동명사는 내부 skill 의 몫" % name)
            self.check_head(plugin, d, rel, text, fm, body_at)
        dmi = set((p, d) for (p, d), (_r, _t, fm, _b) in self.skills.items()
                  if fm and not is_internal(fm) and first(fm, "disable-model-invocation").lower() == "true")
        for p, d in sorted(dmi - USER_ONLY):
            L.add("F", "plugins/%s/skills/%s/SKILL.md" % (p, d), 1,
                  "disable-model-invocation: true 는 {plugin-audit, project-init} 둘에만 둔다")
        for p, d in sorted(USER_ONLY - dmi):
            L.add("F", "plugins/%s/skills/%s/SKILL.md" % (p, d), 1,
                  "사용자 전용 진입 skill 에 disable-model-invocation: true 가 없다")

    def check_head(self, plugin, d, rel, text, fm, body_at):
        L = self.L
        lines = text.split("\n")
        body = lines[body_at:]
        want_bang = BANG_TMPL.format(plugin=plugin, skill=d)
        want_allow = ALLOW_TMPL.format(plugin=plugin, skill=d)
        raw = sum(ln.count("!`") for ln in body)
        bangs = [(body_at + i, m.group(0)) for i, ln in enumerate(body) for m in BANG_RE.finditer(ln)]
        if raw != 1 or len(bangs) != 1:
            L.add("C", rel, body_at + 1, "사전 검사 줄이 정확히 하나가 아니다(실행형 %d개 · 느낌표-백틱 %d개)" % (len(bangs), raw))
        elif bangs[0][1] != want_bang:
            L.add("C", rel, bangs[0][0] + 1, "사전 검사 줄이 기대 모양과 다르다 — 기대: %s" % want_bang)
        if list_items(fm.get("allowed-tools", [])) != [want_allow] or len(fm.get("allowed-tools", [])) != 1:
            L.add("C", rel, 1, "allowed-tools 가 사전 검사 한 항목만이 아니다 — 기대: [%s]" % want_allow)
        heading = next((body_at + i for i, ln in enumerate(body) if ln.strip() == ENTRY_HEADING), None)
        if heading is None:
            L.add("C", rel, 1, "`## 진입 단계` 절이 없다")
        else:
            if bangs and bangs[0][0] > heading:
                L.add("C", rel, bangs[0][0] + 1, "사전 검사 줄이 `## 진입 단계` 위에 있지 않다")
            end = next((j for j in range(heading + 1, len(lines)) if lines[j].startswith("## ")), len(lines))
            section = "\n".join(lines[heading + 1:end])
            for row in SENTINEL_ROWS:
                if row not in section:
                    L.add("C", rel, heading + 1, "진입 단계에 감시줄 판독 행 '%s' 이 없다" % row)
        script = "plugins/%s/scripts/entry_preflight.py" % plugin
        if script not in self.fset:
            L.add("C", rel, 1, "%s 가 없다 — 사전 검사 줄이 가리키는 스크립트" % script)

    # 축 D — skills · references 의 사전 검사 줄과 ```! 블록
    def axis_d(self):
        for rel in self.files:
            parts = rel.split("/")
            if len(parts) < 4 or parts[0] != "plugins" or parts[2] not in ("skills", "references"):
                continue
            if not rel.endswith(".md") or "/tests/" in rel:
                continue
            text = self.read(rel)
            if text is None:
                continue
            in_fence = False
            for n, ln in enumerate(text.split("\n"), 1):
                if in_fence:
                    if ln.strip().startswith("```"):
                        in_fence = False
                    elif USER_ARG_RE.search(ln):
                        self.L.add("D", rel, n, "```! 블록 안에 사용자 인자 토큰이 있다")
                    continue
                if FENCE_BANG_RE.match(ln):
                    in_fence = True
                    continue
                for m in BANG_RE.finditer(ln):
                    if USER_ARG_RE.search(m.group(1)):
                        self.L.add("D", rel, n, "사전 검사 줄에 사용자 인자 토큰이 있다")

    # 축 G — 기계 코퍼스의 안내
    def axis_g(self):
        invocable = set(k for k, (_r, _t, fm, _b) in self.skills.items() if fm and not is_internal(fm))
        commands = set()
        for rel in self.files:
            m = COMMAND_PATH_RE.match(rel)
            if m:
                commands.add((m.group(1), m.group(2)))
        short = sorted(set(s for _p, s in ENTRY_SKILLS))
        bare_re = re.compile(_LEAD + r"/(" + "|".join(re.escape(s) for s in short) + r")" + _TRAIL)
        for rel in self.files:
            parts = rel.split("/")
            if len(parts) < 4 or parts[0] != "plugins" or parts[2] not in MACHINE_DIRS:
                continue
            text = self.read(rel)
            if text is None:
                continue
            for n, ln in enumerate(text.split("\n"), 1):
                for m in FULL_CALL_RE.finditer(ln):
                    p, x = m.group(1), m.group(2)
                    if p in self.plugins and (p, x) not in invocable and (p, x) not in commands:
                        self.L.add("G", rel, n, "/%s:%s 는 사용자 호출 가능한 skill · 명령으로 풀리지 않는다" % (p, x))
                for m in bare_re.finditer(ln):
                    self.L.add("G", rel, n, "기계가 내는 안내의 bare /%s — 완전명 /<plugin>:%s 로" % (m.group(1), m.group(1)))

    # 축 H — 명령 층
    def axis_h(self):
        for rel in self.files:
            if COMMAND_PATH_RE.match(rel):
                self.L.add("H", rel, 1, "commands/ 층은 qg 밖에 두지 않는다 — 사전 단계는 진입 skill 의 사전 검사 줄로")

    # 축 I — 살아 있는 표면의 옛 이름 + 양성 짝
    def axis_i(self):
        for rel in self.files:
            if rel in SELF_FILES or rel.endswith("CHANGELOG.md") or "/tests/fixtures/" in rel:
                continue
            if not (rel in LIVE_TOP or rel.startswith(LIVE_PREFIX)):
                continue
            text = self.read(rel)
            if text is None:
                continue
            for n, ln in enumerate(text.split("\n"), 1):
                for m in OLD_NAME_RE.finditer(ln):
                    self.L.add("I", rel, n, "옛 이름 '%s'" % m.group(0))
                for _m in OLD_CALL_RE.finditer(ln):
                    self.L.add("I", rel, n, "옛 호출 토큰 '/interview'")
        for p, s in ENTRY_SKILLS:
            v = self.skills.get((p, s))
            if v is None or first(v[2], "name") != s:
                self.L.add("I", "plugins/%s/skills/%s/SKILL.md" % (p, s), 1,
                           "새 이름 진입 skill '%s' 가 자기 자리에 없다(양성 짝)" % s)


def print_head(plugin, skill):
    sys.stdout.write("allowed-tools:\n  - %s\n---\n\n%s\n\n%s\n" % (
        ALLOW_TMPL.format(plugin=plugin, skill=skill), BANG_TMPL.format(plugin=plugin, skill=skill), ENTRY_HEADING))


def render_report(L):
    out = ["<!-- check_invocation_surface.py --report -->"]
    if not L.report_mode:
        out.append("> 보고 모드가 아니다 — %s." % SCOPE_OFF)
    else:
        out.append("> 이 표는 `plugins/quality-gates/commands/` 가 있는 동안 유지되는 보고 모드의 산출이다. "
                   "그 디렉토리가 사라지면 같은 행이 RED 가 된다.")
    out += ["", "| # | 축 | 위치 | 위반 | v10 설계 |", "|---|---|---|---|---|"]
    for i, (axis, path, line, msg) in enumerate(sorted(L.rep), 1):
        out.append("| %d | %s | `%s:%d` | %s | |" % (i, axis, path, line, msg.replace("|", "\\|")))
    return "\n".join(out) + "\n"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--emit-scanned", action="store_true")
    ap.add_argument("--print-head", nargs=2, metavar=("PLUGIN", "SKILL"))
    a = ap.parse_args(argv)
    if a.print_head:
        print_head(*a.print_head)
        return 0
    try:
        scan = Scan(a.root)
        L = scan.run()
    except (OSError, subprocess.CalledProcessError) as exc:
        sys.stderr.write("[invocation-surface] 내부 오류: %s\n" % exc)
        return 2
    if a.emit_scanned:
        sys.stdout.write("".join(p + "\n" for p in sorted(scan.scanned)))
        return 0
    if a.report:
        sys.stdout.write(render_report(L))
        return 0
    for axis, path, line, msg in sorted(L.red):
        print("RED %s %s:%d %s" % (axis, path, line, msg))
    if L.red:
        print("[invocation-surface] RED %d건 — 축 A~I (설계 2026-10-09 §4). %s"
              % (len(L.red), SCOPE_ON if L.report_mode else SCOPE_OFF))
        return 1
    print("[invocation-surface] GREEN — qg 보고 행 %d건. %s" % (len(L.rep), SCOPE_ON if L.report_mode else SCOPE_OFF))
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 4: 1부 통과와 2부의 예상 RED 를 확인한다**

Run: `chmod +x shared/entry/check_invocation_surface.py && bash shared/tests/test_invocation_surface.sh 2>&1 | tail -45`
Expected: 1부의 `✓` 가 전부 통과한다(양성 대조 1 · 변이 23 · qg 3 · 음성 대조 1 = 28). 2부 `✗ 이 리포: 표면 정합 GREEN` 하나만 실패한다 — 이주 전이므로 **예상된 RED** 다. 1부에 `✗` 가 있으면 락이나 변이를 고친다. 변이 심기 실패는 계측기 고장이다.

그다음 이 리포의 RED 를 축별로 세어 Task 3~10 의 작업 목록으로 남긴다:

Run: `python3 shared/entry/check_invocation_surface.py | awk '{print $2}' | sort | uniq -c`
Expected: A · C · F · H · I 축 RED 가 있다. 수치를 기록한다(Task 11 에서 0 이 돼야 한다).

- [ ] **Step 5: 커밋** (2부 RED 는 Task 11 까지 예상된 상태다 — 커밋 메시지에 밝힌다)

```bash
git add shared/entry/check_invocation_surface.py shared/tests/test_invocation_surface.sh
git commit -m "test(shared): invocation-surface lock (axes A–I) with synthetic-repo teeth

Repo-wide section is expected RED until the migration tasks land." -- shared/entry/check_invocation_surface.py shared/tests/test_invocation_surface.sh
```

---

### Task 3: 기계적 개명 넷 + qg B6

디렉토리 넷을 `git mv` 하고 옛 skill 이름 리터럴을 기계적으로 바꾼다. 명령 파일은 아직 지우지 않는다. 그래서 이 Task 뒤에도 기존 스위트는 기준선과 같아야 한다.

**Files:**
- Rename: `plugins/spec-distill/skills/{framing-requests→request-framing, conducting-interview→spec-interview, reviewing-spec→spec-review}` · `plugins/plugin-audit/skills/auditing-plugins→plugin-audit`
- Modify (스크립트): `plugins/{spec-distill,plugin-audit,project-init}/**` · `shared/**` 에서 옛 이름을 담은 일반 파일. 제외는 아래 `EXCLUDE`
- Modify (손): `plugins/spec-distill/tests/test_review_hook_removed.py` · `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh`
- Modify (B6 ①②③④): `plugins/quality-gates/tests/test_codex_gate_observation.sh` · `plugins/quality-gates/.claude-plugin/plugin.json` · `plugins/quality-gates/CHANGELOG.md`

**Interfaces:**
- Produces: 새 디렉토리 경로와 `name:` 값 `request-framing` · `spec-interview` · `spec-review` · `plugin-audit`. 이 시점의 `spec-interview` 는 여전히 `user-invocable: false` 다(Task 5 가 푼다).

- [ ] **Step 1: 개명 스크립트를 job tmp 에 쓴다** — `$HOME/.claude/sdd-mirror/unify-command-surface/rename_sweep.py` (리포에 넣지 않는다)

```python
#!/usr/bin/env python3
"""Task 3 기계적 개명. `--apply` 없이 돌리면 바꿀 파일과 건수만 낸다."""
import os, subprocess, sys
ROOT = "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/unify-command-surface"
MAP = [("conducting-interview", "spec-interview"), ("framing-requests", "request-framing"),
       ("reviewing-spec", "spec-review"), ("auditing-plugins", "plugin-audit")]
SCOPE = ("plugins/spec-distill/", "plugins/plugin-audit/", "plugins/project-init/", "shared/")
HAND = {"plugins/spec-distill/tests/test_review_hook_removed.py",          # 역사 커밋 경로(BASE) 보존 — 손으로
        "plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh",  # 부재 단언 리터럴 — 손으로
        "shared/entry/check_invocation_surface.py", "shared/tests/test_invocation_surface.sh"}
def excluded(p):
    return p.endswith("CHANGELOG.md") or "/tests/fixtures/" in p or p in HAND
files = subprocess.run(["git", "-C", ROOT, "ls-files"], capture_output=True, text=True, check=True).stdout.split("\n")
apply = "--apply" in sys.argv
total = 0
for rel in files:
    if not rel.startswith(SCOPE) or excluded(rel):
        continue
    path = os.path.join(ROOT, rel)
    if os.path.islink(path) or not os.path.isfile(path):
        continue   # 링크는 정본(shared/)을 고치면 따라온다. 링크 경로에 쓰면 링크가 일반 파일로 바뀐다
    try:
        text = open(path, encoding="utf-8").read()
    except UnicodeDecodeError:
        continue
    new = text
    for old, rep in MAP:
        new = new.replace(old, rep)
    if new != text:
        n = sum(text.count(o) for o, _ in MAP)
        total += n
        print("%4d  %s" % (n, rel))
        if apply:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new)
print("total", total, "(applied)" if apply else "(dry-run)")
```

- [ ] **Step 2: 디렉토리를 옮기고 모의 실행한다**

```bash
git mv plugins/spec-distill/skills/framing-requests plugins/spec-distill/skills/request-framing
git mv plugins/spec-distill/skills/conducting-interview plugins/spec-distill/skills/spec-interview
git mv plugins/spec-distill/skills/reviewing-spec plugins/spec-distill/skills/spec-review
git mv plugins/plugin-audit/skills/auditing-plugins plugins/plugin-audit/skills/plugin-audit
python3 "$HOME/.claude/sdd-mirror/unify-command-surface/rename_sweep.py"
```

Expected: 파일 목록이 나온다. `/tests/fixtures/` · `CHANGELOG.md` · 링크 경로가 목록에 **없어야** 한다. quality-gates 경로도 없어야 한다(SCOPE 밖).

- [ ] **Step 3: 적용하고 손 편집 둘을 한다**

Run: `python3 "$HOME/.claude/sdd-mirror/unify-command-surface/rename_sweep.py" --apply`

`plugins/spec-distill/tests/test_review_hook_removed.py`:
- 90~91행 `EDITED` 의 두 경로는 역사 커밋 `BASE` 의 경로다. 옛 이름을 유지하되 리터럴을 조각으로 잇는다. `f"{SD}/skills/reviewing-spec/SKILL.md"` → `f"{SD}/skills/reviewing" "-spec/SKILL.md"`, `f"{SD}/skills/conducting-interview/references/finishing.md"` → `f"{SD}/skills/conducting" "-interview/references/finishing.md"`. 그 줄 위에 주석 한 줄을 단다: `# 역사 커밋 BASE 의 경로 — 옛 이름 그대로(락 I 를 피해 조각으로 잇는다)`.
- 388 · 402 · 424 행의 살아 있는 경로는 새 이름으로 바꾼다(`reviewing-spec`→`spec-review`, `conducting-interview`→`spec-interview`).

`plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` 77행: 부재 단언의 `'상한 2(conducting-interview'` → `'상한 2(conducting''-interview'` (bash 인접 문자열 연결 — 값은 그대로이고, 파일 글자에서는 끊긴다).

- [ ] **Step 4: qg B6 넷을 고친다**

`plugins/quality-gates/tests/test_codex_gate_observation.sh` 의 `case "$label" in` 아래 첫 패턴 줄(지금 315행):

```
        auditing-plugins|reviewing-spec|reviewing-brief|framing-requests)
```
→
```
        # 라벨 = skill 디렉토리 이름(위 label= 도출). spec-distill 5.0.0 · plugin-audit 1.0.0 개명을 따른다.
        plugin-audit|spec-review|reviewing-brief|request-framing)
```

`plugins/quality-gates/.claude-plugin/plugin.json`: `"version": "9.3.6"` → `"version": "9.3.7"`.

`plugins/quality-gates/CHANGELOG.md` 맨 위 항목 앞에 넣는다(기존 항목의 헤딩 형식을 따른다):

```
## [9.3.7] — 2026-10-09

### Fixed

- `tests/test_codex_gate_observation.sh` 의 라벨 열거를 spec-distill · plugin-audit 의 skill 디렉토리 개명(`spec-review` · `request-framing` · `plugin-audit`)에 맞췄다. 동작 변화 없음.
```

- [ ] **Step 5: 영향받는 스위트를 돌린다**

Run:
```bash
for t in $(git ls-files -- ':(glob)plugins/spec-distill/tests/test_*.sh' ':(glob)plugins/plugin-audit/tests/test_*.sh' ':(glob)shared/tests/test_*.sh') plugins/quality-gates/tests/test_codex_gate_observation.sh plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh; do
  bash "$t" >/dev/null 2>&1 || echo "RC≠0 $t"
done
(cd plugins/plugin-audit/tests && python3 -m unittest -q 2>&1 | tail -3)
(cd plugins/spec-distill/tests && for f in test_*.py; do python3 -m unittest -q "${f%.py}" >/dev/null 2>&1 || echo "RC≠0 $f"; done)
```
Expected: `RC≠0` 줄은 Task 0 기준선에서 이미 rc≠0 이던 파일과 `shared/tests/test_invocation_surface.sh`(예상 RED)뿐이다. 그 밖의 `RC≠0` 은 이 Task 의 회귀다 — 그 파일을 열어 옛 이름이 남았거나 바뀌지 말아야 할 리터럴이 바뀌었는지 고친다.

- [ ] **Step 6: 커밋**

```bash
git add -A plugins/spec-distill plugins/plugin-audit shared plugins/quality-gates/tests/test_codex_gate_observation.sh plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git status --short | grep -v '^[RMAD] ' || true   # 미스테이징 잔여 없음 확인
git commit -m "refactor: rename entry skill dirs (spec-review · spec-interview · request-framing · plugin-audit)" -- plugins/spec-distill plugins/plugin-audit shared plugins/quality-gates/tests/test_codex_gate_observation.sh plugins/quality-gates/.claude-plugin/plugin.json plugins/quality-gates/CHANGELOG.md
git diff HEAD~1 --stat -- plugins/quality-gates   # 정확히 3 files
```

---

### Task 4: `spec-review` 진입 머리

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (frontmatter · 사전 검사 줄 · `## 진입 단계` · `## 입력`)
- Test: `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh`(기존, 회귀) · `shared/tests/test_invocation_surface.sh`(축 C 의 spec-review 행)

**Interfaces:**
- Consumes: `--print-head spec-distill spec-review` (Task 2).
- Produces: `/spec-distill:spec-review <설계문서>` 의 진입 순서 — 1 감시줄 → 1.5 기존 `## 진입 검사` 펜스 → `## 입력`.

- [ ] **Step 1: 실패를 확인한다**

Run: `python3 shared/entry/check_invocation_surface.py | grep 'spec-review/SKILL.md'`
Expected: `RED C … 사전 검사 줄이 정확히 하나가 아니다` · `RED C … allowed-tools …` · `RED C … 진입 단계 절이 없다`.

- [ ] **Step 2: frontmatter 와 머리를 넣는다**

frontmatter 의 `cost_class: medium` 줄 아래에 `argument-hint: "<설계문서 경로>"` 를 넣는다. 그다음 `python3 shared/entry/check_invocation_surface.py --print-head spec-distill spec-review` 출력에서 첫 두 줄(`allowed-tools:` 와 그 항목)을 닫는 `---` 바로 앞에 넣는다. 닫는 `---` 뒤, 본문 제목 `# spec-review — …` 바로 아래에 사전 검사 줄과 아래 절을 넣는다(기존 `## 진입 검사` 바로 앞):

```markdown
!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill spec-review`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽는다.

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 아래 `## 진입 검사`(1.5)로 간다. 그 줄의 `root=` 값을 `## 입력` 에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 `[spec-distill] 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).` 를 덧붙여 멈춘다 |
| `[devbrew-entry] error …` | `[spec-distill] spec-review 사전 검사 실패 — <reason= 값>.` 과 위 복귀 문장을 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] spec-review 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다.` 와 위 복귀 문장을 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] spec-review 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다.` 와 위 복귀 문장을 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다. 이 skill 고유의 스위치(아래 셋)는 1.5 `## 진입 검사` 가 본다. `DEVBREW_SKIP_HOOKS` 의 플러그인 토큰은 이 표에 걸리지 않는다.
```

(위 블록의 첫 줄은 `--print-head` 출력의 다섯째 줄을 그대로 붙인 것이다. 손으로 치지 않는다.)

- [ ] **Step 3: `## 입력` 의 경로 규칙을 고친다**

`` `$spec_path` 는 **호출 인자**다 — `` 로 시작하는 문단에서 `` 상대 경로면 리포 루트 기준 절대 경로로 바꿔 쓴다. `` → `` 인자가 `@` 로 시작하면 그 `@` 하나를 뗀다. 상대 경로면 진입 단계 감시줄의 `root=` 기준 절대 경로로 바꿔 쓴다. ``

- [ ] **Step 4: 통과를 확인한다**

Run:
```bash
python3 shared/entry/check_invocation_surface.py | grep 'spec-review/SKILL.md' || echo "spec-review: 축 RED 없음"
for t in test_reviewing_spec_entry_fence test_reviewing_spec_design_only test_reviewing_spec_disclosure test_handoff_kill_switch test_review_handoff_order test_proceed_gate_adopters; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "RC≠0 $t"; done
bash shared/tests/test_skill_body_no_positional_tokens.sh | tail -1
bash shared/tests/test_no_new_duplication.sh | tail -1
```
Expected: `spec-review: 축 RED 없음`. `RC≠0` 이 없다(기준선에서 이미 RED 였던 것은 예외). 두 shared 락은 `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): spec-review entry head (preflight + 진입 단계)" -- plugins/spec-distill/skills/spec-review/SKILL.md
```

---

### Task 5: `spec-interview` — 명령 흡수 · 숨김 해제 · «풀린 입력»

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md`
- Modify: `plugins/spec-distill/skills/spec-interview/references/seed-input.md` · `finishing.md`
- Modify: `plugins/spec-distill/references/trivia-escape.md`
- Delete: `plugins/spec-distill/commands/interview.md`
- Modify (테스트): `plugins/spec-distill/tests/test_conducting_interview_internal.sh` → `git mv` 로 `test_spec_interview_entry.sh` · `test_conducting_interview_stage.sh` · `test_seed_at_path_handoff.sh` · `test_seed_input_provenance.sh` · `test_reviewing_spec_design_only.sh` · `test_stale_terms.sh`

**Interfaces:**
- Consumes: `--print-head spec-distill spec-interview`.
- Produces: «풀린 입력»(진입 단계 2 의 산출). `seed-input.md` · `finishing.md` · trivia 가 이 이름을 읽는다. 사용자 호출 모양은 `/spec-distill:spec-interview @<seed 경로>` 이다(Task 6 의 핸드오프가 이 모양을 낸다).

- [ ] **Step 1: 테스트를 새 자리로 옮긴다(실패하게)**

`plugins/spec-distill/tests/test_seed_at_path_handoff.sh`:
- `CMD=…/commands/interview.md` 를 지우고, 대신 `SK_IV="$SD/skills/spec-interview/SKILL.md"` 를 둔다. 블록 추출은 진입 단계 소절로 한다:
  ```bash
  sub() { awk -v h="$2" 'index($0,h)==1{f=1;next} f&&/^##+ /{exit} f' "$1"; }   # sub <file> <소절 제목 접두>
  s2="$(sub "$SK_IV" '### 2. ')"; s3="$(sub "$SK_IV" '### 3. ')"; s35="$(sub "$SK_IV" '### 3.5 ')"; s4="$(sub "$SK_IV" '### 4. ')"
  ```
- 37~45행의 `^## Step 1[.]5` 존재 · 순서 단언은 «`## 진입 단계` 아래 `### 2. ` 가 `### 3. ` 보다 앞» 단언으로 바꾼다.
- 46~52행 리터럴 넷은 그대로 두고 대상만 `$s2` 로 바꾼다. 그리고 단언 둘을 **더한다**(Review Focus 2 · 3):
  ```bash
  assert_contains "$s2" '시도: ' "@ 실패 문구가 시도한 절대경로를 싣는다"
  assert_contains "$s2" '공백 없는 경로 한 토큰으로 다시 불러라' "@ 경로의 공백을 알리고 멈춘다"
  ```
- 57행 `'「풀린 입력」을 대조'` 의 대상 → `$s3`. 58행 `'「풀린 입력」의 frontmatter 에 `type: interview-seed`'` 의 대상 → `$s35`.
- 59~61행(`Skill conducting-interview <풀린 입력>` 단언 · 비어 있지 않음 · `$ARGUMENTS` 부재)은 지운다. 대신 `assert_contains "$s4" '「풀린 입력」'` 을 넣는다. 62행 `## Arguments` 단언은 `assert_contains "$s4" '2 의 결과'` 로 바꾼다.
- 148~152행 코퍼스 목록에서 `"$CMD"` 를 뺀다(`$RF` 는 Task 6 이 뺀다).
- 160행 seed-input.md 단언 `'`/interview @<seed 경로>` 를 치게 하고'` → `'`/spec-distill:spec-interview @<seed 경로>` 를 치게 하고'`.

`plugins/spec-distill/tests/test_seed_input_provenance.sh`: `IV=…/commands/interview.md` → `IV="$SD/skills/spec-interview/SKILL.md"`. `# guards:` 줄과 `--emit-scanned` 목록의 경로도 같이 바꾼다. 리터럴 셋(`seed 원문 대조: seed=` · `` `.audit.md` `` · `「풀린 입력」에 넣지 않는다`)은 그대로 둔다.

`plugins/spec-distill/tests/test_conducting_interview_stage.sh`:
- 7행 `CMD=` → `CMD="$SD/skills/spec-interview/SKILL.md"`.
- 1261 · 1263 행의 `awk '/^## Step 2: /…'` · `awk '/^## Step 2\.5/…'` → `### 3. ` · `### 3.5 ` 소절 추출로 바꾼다(위 `sub` 함수와 같은 모양).
- 1288 행(`grep -qF 'Skill conducting-interview' "$CMD"`)은 지운다.
- 1291 행은 `grep -qF 'spec-distill:request-framing'` 으로 바꾼다.
- 1257 행 다섯 패턴 미중복 카운트는 대상 그대로 SKILL.md 에서 0 이어야 한다.
- 416 행 리터럴 `` 인자 없이 `/interview` 를 부른 경로의 R1 `` → `` 인자 없이 `/spec-distill:spec-interview` 를 부른 경로의 R1 ``.
- 1001 행 리터럴 → `` 「풀린 입력」(사용자가 `/spec-distill:spec-interview` 에 함께 넘긴 rough request ``.

`plugins/spec-distill/tests/test_conducting_interview_internal.sh` → `git mv` 로 `plugins/spec-distill/tests/test_spec_interview_entry.sh`. 내용:
- 20 행 `grep -q '^user-invocable: false$'` 단언을 **반전**한다: frontmatter 에 `user-invocable:` 줄이 없어야 한다.
- 9 · 36 행(`CMD` · `Skill conducting-interview` 단언)은 지우고, `[ ! -e "$SD/commands/interview.md" ]` 단언을 넣는다.
- 25 행 `'^name: spec-interview$'` 은 Task 3 의 결과 그대로 둔다.
- `# guards:` 와 `--emit-scanned` 의 `commands/interview.md` 를 지운다.

`plugins/spec-distill/tests/test_reviewing_spec_design_only.sh` 81~85 행: `F9D_ROOTS` 에서 `"$PLUGIN/commands"` 를 뺀다(Task 6 뒤 spec-distill 에 `commands/` 가 없다).

`plugins/spec-distill/tests/test_stale_terms.sh`: 제거된 파일 목록(`removed_files`)에 `'commands/interview.md'` 를 더한다.

Run: `for t in test_seed_at_path_handoff test_seed_input_provenance test_conducting_interview_stage test_spec_interview_entry; do bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done`
Expected: 넷 다 `Fail:` 이 0 이 아니다(진입 단계가 아직 없다).

- [ ] **Step 2: frontmatter 를 바꾸고 진입 단계를 넣는다**

`plugins/spec-distill/skills/spec-interview/SKILL.md` frontmatter: `user-invocable: false` 줄을 지운다. `cost_class: variable` 아래에 `argument-hint: "[@<seed 경로> | rough request]"` 를 넣는다. 닫는 `---` 앞에 `--print-head spec-distill spec-interview` 의 `allowed-tools:` 두 줄을 넣는다. description 의 첫 문장 앞에 `` 사용자가 `/spec-distill:spec-interview @<seed 경로>` 로 부른다. `` 를 넣는다.

본문 제목(`# Conducting Interview — 문제공간 Stage (Phase 1)`)을 `# spec-interview — 문제공간 Stage (Phase 1)` 로 바꾸고, 그 아래 첫 문단 앞에 다음을 넣는다. 첫 줄은 `--print-head` 다섯째 줄이다. `### 2.` 의 seed audit 문단은 `commands/interview.md` 의 `## Step 1.5` 끝 세 문단을 옮긴 것이다.

```markdown
!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill spec-interview`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 2 로 간다. 그 줄의 `root=` 값을 2 에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op). state 를 만들지 않는다 |
| `[devbrew-entry] error …` | `[spec-distill] spec-interview 사전 검사 실패 — <reason= 값>. 인터뷰를 시작하지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] spec-interview 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 인터뷰를 시작하지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] spec-interview 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다. 인터뷰를 시작하지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.

### 2. `@경로` 풀기

받은 인자의 앞뒤 공백을 걷은 값이 `@` 로 시작하는 **공백 없는 한 토큰**일 때만 이 단계가 발동한다. 문장 중간에 `@` 가 섞인 입력은 건드리지 않는다. `@` 로 시작하는데 공백이 섞였으면 풀지 않고, `[spec-distill] '@…' 에 공백이 있다 — 공백 없는 경로 한 토큰으로 다시 불러라. 인터뷰를 시작하지 않는다.` 를 내고 멈춘다.

발동하면 `@` 를 뗀 경로를 감시줄 `root=` 기준으로 풀어 **절대경로로** Read 도구에 넘긴다. 절대경로가 왔는데 Read 가 실패하면, 같은 문자열을 `root=` 기준 상대경로로 보고 한 번 더 시도한다. Read 출력에서 줄번호·탭 접두를 뗀 **파일 원문 전체(frontmatter 포함)** 가 「풀린 입력」이다. 대화형에서 같은 파일이 따로 첨부되더라도 「풀린 입력」의 출처는 이 Read 결과다.

Read 가 끝내 실패하면(파일 부재 · 경로가 디렉토리 · 권한 등), 시도한 절대경로를 모두 담아 아래 문구를 내고 멈춘다.

> `[spec-distill] '@<경로>' 를 읽지 못했다 — 시도: <절대경로들> (<관측한 사유>). seed 를 만든 워크트리 디렉토리에서 세션을 열었는지 확인하라. 인터뷰를 시작하지 않는다.`

**seed 면 원문 기록의 경로를 한 줄로 낸다.** 「풀린 입력」의 frontmatter 에 `type: interview-seed` 가 있으면, 읽은 파일의 절대경로에서 audit 경로를 도출한다 — 같은 디렉토리에서 파일명 끝의 `.md` 를 `.audit.md` 로 바꾼 파일이다. seed frontmatter 의 `audit_file:` 은 따라가지 않는다. 그 파일을 Read 로 확인하고, 인터뷰에 들어가기 전에 아래 한 줄을 그대로 낸다:

> `[spec-distill] seed 원문 대조: seed=<seed 절대경로> · audit=<audit 절대경로>`

읽지 못하면 `audit=없음(<관측한 사유>)` 로 낸다. 이 줄은 「풀린 입력」에 넣지 않는다 — 「풀린 입력」은 seed 전문 그대로여야 brief §6 의 `S1` 이 바뀌지 않는다. `references/seed-input.md` 의 seed 입력 규약이 이 줄의 두 경로로 문장마다 출처와 확인을 가른다.

발동하지 않았으면 「풀린 입력」은 이 skill 이 받은 인자 그대로다(비어 있을 수 있다).

### 3. trivia 판정

「풀린 입력」의 frontmatter 에 `type: interview-seed` 가 있으면 이 단계를 건너뛴다. 아니면 `${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 를 읽고 다섯 패턴과 대조한다. 해당하면 그 파일의 안내 문면을 `<command>` = `spec-distill:spec-interview` 로 채워 내고, 인터뷰를 시작하지 않습니다.

### 3.5 seed 아닌 입력에 대한 조언

「풀린 입력」의 frontmatter 에 `type: interview-seed` 가 없으면 한 줄 안내를 낸다. **막지 않는다.**

> 💡 `/spec-distill:request-framing` 을 먼저 거치면 첫 턴이 정리된 상태로 시작합니다. 지금 그대로 진행해도 됩니다.

### 4. 본 절차로

아래 절들을 진행한다. 이 skill 과 그 references(`seed-input.md` · `finishing.md`)가 말하는 「풀린 입력」은 2 의 결과다. 「풀린 입력」이 비어 있으면 «라운드 규약»의 인자 없는 경로로 시작한다.
```

본문의 다른 자리:
- `인자 없이 `/interview` 를 부른 경로의 R1` → `인자 없이 `/spec-distill:spec-interview` 를 부른 경로의 R1`.
- `## seed 를 입력으로 받았을 때` 첫 줄의 `` `$ARGUMENTS` 가 `type: interview-seed` frontmatter `` → `` 「풀린 입력」이 `type: interview-seed` frontmatter ``.
- kill switch 목록의 `` - `DEVBREW_SPEC_DISTILL_DISABLE=1`: 즉시 abort, state.local.md 보존 (실패 분석용). `` → `` - `DEVBREW_SPEC_DISTILL_DISABLE=1`: `## 진입 단계` 1 이 멈춘다(no-op). 진행 중이던 state.local.md 는 보존한다(실패 분석용). ``

- [ ] **Step 3: references 의 «풀린 입력» 치환**

`references/seed-input.md`:
- 3~7행 → «「풀린 입력」이 `type: interview-seed` frontmatter 를 가진 문서면, 그것은 **Phase 0 에서 사용자가 확정한 메시지**다. Phase 0 은 사용자에게 `/spec-distill:spec-interview @<seed 경로>` 를 치게 하고, 이 skill 의 `## 진입 단계` 2 가 그 파일을 전문(frontmatter 포함)으로 풀어 「풀린 입력」으로 삼는다(그 호출 모양의 정본은 `request-framing` 의 「호출 모양」 절이다).» 그 뒤 문장(«그 frontmatter 줄이 … 발동하지 않는다»)은 유지한다.
- 9행 `` §6 `S1` 은 `$ARGUMENTS` 원문 그대로다 `` → `` §6 `S1` 은 「풀린 입력」 원문 그대로다 ``.
- 28행 `` `/interview` 가 인터뷰 진입 전에 낸 한 줄 `` → `` `## 진입 단계` 2 가 인터뷰 진입 전에 낸 한 줄 ``.
- 44~45행 `` **seed 가 아닌 입력도 그대로 받는다.** `/interview` 는 호환을 유지한다 — 조언 한 줄을 내되 **차단하지 않는다**. `` → `` **seed 가 아닌 입력도 그대로 받는다.** `## 진입 단계` 3.5 가 조언 한 줄을 내되 **차단하지 않는다**. ``

`references/finishing.md` 41~49 행:
- `` `$ARGUMENTS`(사용자가 `/interview`에 함께 넘긴 rough `` → `` 「풀린 입력」(사용자가 `/spec-distill:spec-interview` 에 함께 넘긴 rough ``.
- `` `/interview` 가 `@경로` 를 풀어 넘겼든 `` → `` `## 진입 단계` 2 가 `@경로` 를 풀었든 ``.
- `` 그 `$ARGUMENTS` 가 `interview-seed` 파일 전문이고 `` → `` 그 「풀린 입력」이 `interview-seed` 파일 전문이고 ``.
- `` text: "<$ARGUMENTS 원문 그대로>" `` → `` text: "<「풀린 입력」 원문 그대로>" ``.

`plugins/spec-distill/references/trivia-escape.md`:
- 첫 문장 `` `$ARGUMENTS` 가 아래 다섯 중 하나에 해당하면 `` → `` 「풀린 입력」(진입 skill 의 `## 진입 단계` 2 의 결과)이 아래 다섯 중 하나에 해당하면 ``.
- `` `<command>` 는 그 명령의 slash-command 이름(예: `interview` · `request-framing`)이다 `` → `` `<command>` 는 호출한 진입 skill 의 완전명(`spec-distill:spec-interview` · `spec-distill:request-framing`)이다 ``. 그 앞의 `호출한 명령이 채운다` → `호출한 진입 skill 이 채운다`.

그다음 명령을 지운다: `git rm plugins/spec-distill/commands/interview.md`.

- [ ] **Step 4: 통과를 확인한다**

Run:
```bash
for t in test_seed_at_path_handoff test_seed_input_provenance test_conducting_interview_stage test_spec_interview_entry test_reviewing_spec_design_only test_stale_terms test_finishing_block_scope test_seed_provenance test_brief_review_entry; do
  f=plugins/spec-distill/tests/$t; [ -f "$f.sh" ] && { bash "$f.sh" >/dev/null 2>&1 || echo "RC≠0 $t"; }; [ -f "$f.py" ] && { (cd plugins/spec-distill/tests && python3 -m unittest -q "$t" >/dev/null 2>&1) || echo "RC≠0 $t"; }
done
python3 shared/entry/check_invocation_surface.py | grep 'spec-interview' || echo "spec-interview: 축 RED 없음"
bash shared/tests/test_skill_body_no_positional_tokens.sh | tail -1
bash shared/tests/test_no_new_duplication.sh | tail -1
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | tail -1
```
Expected: `RC≠0` 이 없다(기준선 RED 는 예외). `spec-interview: 축 RED 없음`. 남은 `G` 행은 `request-framing` 쪽(Task 6)이다. shared 락 셋은 `Fail: 0`.

- [ ] **Step 5: 커밋**

```bash
git add -A plugins/spec-distill/skills/spec-interview plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/tests
git commit -m "feat(spec-distill)!: spec-interview absorbs /interview (preflight · @ expansion · 풀린 입력)" -- plugins/spec-distill/skills/spec-interview plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/commands/interview.md plugins/spec-distill/tests
```

---

### Task 6: `request-framing` — 명령 흡수 · 핸드오프 완전명

**Files:**
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md`
- Delete: `plugins/spec-distill/commands/request-framing.md` (이로써 `plugins/spec-distill/commands/` 가 사라진다)
- Modify (테스트): `plugins/spec-distill/tests/test_request_framing_command.sh` → `git mv` 로 `test_request_framing_entry.sh` · `test_seed_at_path_handoff.sh` · `test_stale_terms.sh`

**Interfaces:**
- Consumes: `--print-head spec-distill request-framing`. 핸드오프 대상은 `/spec-distill:spec-interview`(Task 5)다.
- Produces: 「호출 모양」 정본 — 다음 세션 첫 턴 `/spec-distill:spec-interview @<seed 경로>`.

- [ ] **Step 1: 테스트를 새 자리로 옮긴다(실패하게)**

`git mv plugins/spec-distill/tests/test_request_framing_command.sh plugins/spec-distill/tests/test_request_framing_entry.sh` 를 한 뒤 고친다:
- `CMD=…/commands/request-framing.md` → `CMD="$SD/skills/request-framing/SKILL.md"`. `ENTRY="$(awk '/^## 진입 단계/{f=1;next} f&&/^## /{exit} f' "$CMD")"` 를 두고 아래 단언의 대상을 `$ENTRY` 로 바꾼다.
- 43 행 kill switch 단언 → `assert_contains "$ENTRY" '[devbrew-entry] disabled'` 와 `assert_contains "$ENTRY" 'DEVBREW_SPEC_DISTILL_DISABLE=1'`.
- 45 행 `references/trivia-escape\.md` → 대상 `$ENTRY`. 그리고 `assert_contains "$ENTRY" '`spec-distill:request-framing`'` 을 더한다(`<command>` 값).
- 48 행 dispatch 단언(`Skill .*framing-requests|…`)은 지운다. 대신 `[ ! -e "$SD/commands/request-framing.md" ]` 단언을 넣는다.
- 52 행 다섯 패턴 미중복 카운트는 SKILL 전체에서 0.
- 126 행 `## Arguments` 블록 → `$ENTRY`. `'무엇을 맡기려'` · `'워크트리 — 진입 직후'` 두 리터럴은 유지한다.
- 2 행 `# guards:` 와 `--emit-scanned` 목록에서 `commands/request-framing.md` 를 지운다.

`plugins/spec-distill/tests/test_seed_at_path_handoff.sh`:
- `RF=…/commands/request-framing.md` 와 그것을 쓰는 단언(165 행 `assert_file_absent "$RF" '붙여넣'` 포함)을 지운다. 148~152 행 코퍼스 목록에서 `"$RF"` 를 뺀다.
- 71~72 · 151 · 158 행의 리터럴 `` `/interview @<seed 경로>` `` → `` `/spec-distill:spec-interview @<seed 경로>` ``.

`plugins/spec-distill/tests/test_stale_terms.sh`: `removed_files` 에 `'commands/request-framing.md'` 를 더한다.

Run: `bash plugins/spec-distill/tests/test_request_framing_entry.sh | tail -1; bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh | tail -1`
Expected: 둘 다 `Fail:` 이 0 이 아니다.

- [ ] **Step 2: frontmatter · 진입 단계**

frontmatter description → 
```
description: >
  Phase 0 회의 skill. 사용자가 `/spec-distill:request-framing` 으로 부른다. 확산(원문 보존 → 레포
  읽기 → 질문 라운드) 후 압축해, 새 세션 첫 턴의 `/spec-distill:spec-interview @<seed 경로>` 가
  가리키는 `interview-seed` 파일을 만든다. 산출물은 문서가 아니라 다음 세션의 첫 턴이다.
```
`cost_class: variable` 아래에 `argument-hint: "[raw request / 생각 / 대화 / 자료]"` 를 넣는다. 닫는 `---` 앞에는 `--print-head spec-distill request-framing` 의 `allowed-tools:` 두 줄을 넣는다.

본문 제목 `# Framing Requests — Phase 0` → `# request-framing — Phase 0`. 첫 문단 안의 `` 턴 `/interview @<seed 경로>` 가 가리키는 파일 `` → `` 턴 `/spec-distill:spec-interview @<seed 경로>` 가 가리키는 파일 ``. 그다음 `**진입 선결조건** —` 문단(17행 부근)을 지우고 그 자리에 아래를 넣는다. 첫 줄은 `--print-head` 의 다섯째 줄이다.

```markdown
!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" spec-distill request-framing`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽고 아래 순서대로 간다.

### 1. 감시줄 판독

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 2 로 간다. 그 줄의 `root=` 값을 2 에서 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op). 상태를 만들지 않는다 |
| `[devbrew-entry] error …` | `[spec-distill] request-framing 사전 검사 실패 — <reason= 값>. 회의를 시작하지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[spec-distill] request-framing 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 회의를 시작하지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[spec-distill] request-framing 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다. 회의를 시작하지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_SPEC_DISTILL_DISABLE=1` 하나다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.

### 2. `@경로` 풀기

받은 인자가 `@` 로 시작하는 공백 없는 한 토큰이면, `@` 를 뗀 경로를 감시줄 `root=` 기준 절대경로로 풀어 Read 하고, 그 원문 전체를 「풀린 입력」으로 삼는다. 읽지 못하면 `[spec-distill] '@<경로>' 를 읽지 못했다 — 시도: <절대경로들> (<관측한 사유>). 회의를 시작하지 않는다.` 를 내고 멈춘다. 발동하지 않으면 「풀린 입력」은 받은 인자 그대로다.

### 3. trivia 판정

`${CLAUDE_PLUGIN_ROOT}/references/trivia-escape.md` 를 읽고 「풀린 입력」을 다섯 패턴과 대조한다. 해당하면 그 파일의 안내 문면을 `<command>` = `spec-distill:request-framing` 으로 채워 내고 진행하지 않는다.

### 4. 회의로

「풀린 입력」은 거친 프롬프트 · 생각 · 대화 로그 · 자료 무엇이든 된다. 비어 있으면 「무엇을 맡기려 하시나요」로 주제부터 정한다. 그 뒤의 순서는 `## 워크트리 — 진입 직후` 절이 정한다.
```

- [ ] **Step 3: 핸드오프를 완전명으로 바꾼다**

본문의 `/interview` 호출 토큰을 전부 `/spec-distill:spec-interview` 로 바꾼다. 대상은 지금 138 · 259 · 292 · 885 · 889 · 891 · 898 · 910 · 911 · 919 행 부근이고, `grep -n '/interview' plugins/spec-distill/skills/request-framing/SKILL.md` 로 전수 확인한다. `docs/superpowers/interview/` 같은 경로 조각은 바꾸지 않는다. 산문의 주어도 고친다:
- 889 행 `` **소비자 쪽 계약이 전부 `/interview` 가 넘기는 인자에 키잉돼 있습니다.** `` → `` **소비자 쪽 계약이 전부 `spec-interview` 의 「풀린 입력」에 키잉돼 있습니다.** ``
- 891 행 `` 어느 쪽이든 `/interview` 가 그 파일을 읽어 전문으로 풀어 넘깁니다. `` → `` 어느 쪽이든 `spec-interview` 의 `## 진입 단계` 2 가 그 파일을 읽어 전문으로 풉니다. ``
- 898 행 `` `/interview` 가 방금 Phase 0 을 거친 사용자에게 「`/request-framing` 을 먼저 거치면…」 `` → `` `spec-interview` 가 방금 Phase 0 을 거친 사용자에게 「`/spec-distill:request-framing` 을 먼저 거치면…」 ``
- 1084 행 kill switch 목록 `` - `DEVBREW_SPEC_DISTILL_DISABLE=1` — 즉시 abort, state 보존. `` → `` - `DEVBREW_SPEC_DISTILL_DISABLE=1` — `## 진입 단계` 1 이 멈춘다(no-op), state 보존. ``

그다음 명령을 지운다: `git rm plugins/spec-distill/commands/request-framing.md`.

- [ ] **Step 4: 통과를 확인한다**

Run:
```bash
for t in test_request_framing_entry test_seed_at_path_handoff test_stale_terms test_framing_review_contract test_seed_gate_wiring test_seed_codex_axes test_proceed_gate_adopters test_reviewing_spec_design_only; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "RC≠0 $t"; done
[ ! -d plugins/spec-distill/commands ] && echo "spec-distill commands/ 없음"
python3 shared/entry/check_invocation_surface.py | grep -E 'plugins/spec-distill/' || echo "spec-distill: 축 RED 없음(README·템플릿 제외 시)"
bash shared/tests/test_no_new_duplication.sh | tail -1
```
Expected: `RC≠0` 이 없다. `spec-distill commands/ 없음`. 남는 spec-distill RED 는 README · templates 의 축 I · G 뿐이다(Task 7 의 몫).

- [ ] **Step 5: 커밋**

```bash
git add -A plugins/spec-distill/skills/request-framing plugins/spec-distill/tests
git commit -m "feat(spec-distill)!: request-framing absorbs its command; handoffs use full names" -- plugins/spec-distill/skills/request-framing plugins/spec-distill/commands/request-framing.md plugins/spec-distill/tests
```

---

### Task 7: spec-distill 마감 — README · 템플릿 · 버전

**Files:**
- Modify: `plugins/spec-distill/README.md` · `plugins/spec-distill/templates/interview-seed-audit-template.md` · `plugins/spec-distill/templates/interview-brief-template.md` · `plugins/spec-distill/templates/interview-audit-template.md` · `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md`

**Interfaces:**
- Produces: spec-distill `5.0.0`.

- [ ] **Step 1: 남은 RED 를 본다**

Run: `python3 shared/entry/check_invocation_surface.py | grep 'plugins/spec-distill/'`
Expected: README 의 `/interview` (축 I), seed-audit 템플릿 11 행(축 I), 그 밖의 잔여.

- [ ] **Step 2: 템플릿**

- `templates/interview-seed-audit-template.md:11` 의 `` `/interview @<seed 경로>` `` → `` `/spec-distill:spec-interview @<seed 경로>` ``.
- `templates/interview-brief-template.md:6` 과 `interview-audit-template.md:6` 의 `source:` 줄은 Task 3 이 이미 skill 토큰을 `spec-interview` 로 바꿨다. 버전 문자열은 손대지 않는다. `git diff main -- plugins/spec-distill/templates` 로 확인한다.

- [ ] **Step 3: README**

- 사용자 호출 줄(사람용, 짧은 이름): `/interview` → `/spec-interview`. `/request-framing` 은 그대로 둔다. reviewing 쪽 안내는 `/spec-review` 로 한다. 각 호출 절에 완전명을 한 번 병기한다: «설치 환경에 같은 이름이 있으면 `/spec-distill:spec-interview` 처럼 완전명으로 부른다».
- 구성요소 목록의 `commands/` 줄을 지운다. skills 목록을 새 이름 넷(`request-framing` · `spec-interview` · `spec-review` · `reviewing-brief`(내부))으로 맞춘다.
- kill switch 절에 두 문장을 더한다: «진입 skill 셋(`request-framing` · `spec-interview` · `spec-review`)은 본문 전 사전 검사가 `DEVBREW_SPEC_DISTILL_DISABLE=1` 을 판정한다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.» · «사전 검사 스크립트(`scripts/entry_preflight.py`)나 `python3` 가 없으면 플랫폼이 skill 호출을 끊는다 — 헤드리스에서는 출력 없이 끝난다.»
- «Principles Instantiated» 에 한 줄을 더한다: «Law 1 — 진입 skill 의 본문 전 사전 검사(`!`)가 kill switch 를 모델 판단 밖에서 집행한다».

- [ ] **Step 4: 버전 · CHANGELOG**

`plugin.json` `"version": "4.5.3"` → `"5.0.0"`. `CHANGELOG.md` 맨 위 항목 앞:

```markdown
## [5.0.0] — 2026-10-09

major 인 이유 — 사용자 호출 이름 둘이 alias 없이 사라졌고, skill 디렉토리 셋이 개명됐다.

### Removed

| 옛 호출 · 이름 | 새 완전명 |
|---|---|
| `/interview` (`commands/interview.md`) | `/spec-distill:spec-interview` |
| `/request-framing` 명령 (`commands/request-framing.md`) | `/spec-distill:request-framing` (skill) |
| skill `framing-requests` | `request-framing` |
| skill `conducting-interview` (내부) | `spec-interview` (사용자 호출 가능) |
| skill `reviewing-spec` | `spec-review` |

### Added

- 진입 skill 셋에 본문 전 사전 검사(`scripts/entry_preflight.py`, `shared/entry/` 정본의 심볼릭 링크)와 `## 진입 단계` 절. `@경로` 풀기 · trivia 판정이 명령 파일에서 skill 로 옮겨 왔다.

### Changed

- 기계가 내는 안내(핸드오프 · trivia 문면)는 `/spec-distill:<skill>` 완전명을 쓴다.
- `DEVBREW_SPEC_DISTILL_DISABLE=1` 은 세 진입 skill 의 사전 검사가 판정한다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.
```

- [ ] **Step 5: 확인 · 커밋**

Run: `python3 shared/entry/check_invocation_surface.py | grep 'plugins/spec-distill/' || echo "spec-distill: 축 RED 0"; bash plugins/spec-distill/tests/test_brief_review_meta.sh | tail -1`
Expected: `spec-distill: 축 RED 0`. `test_brief_review_meta.sh` 는 92 행이 README 의 `DEVBREW_SPEC_DISTILL_DISABLE_CODEX=1` 줄에 skill 이름이 있는지 잰다 — `Fail: 0`.

```bash
git commit -m "chore(spec-distill): 5.0.0 — README · templates · CHANGELOG for skill-only surface" -- plugins/spec-distill/README.md plugins/spec-distill/templates plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
```

---

### Task 8: plugin-audit — 명령 흡수 · 사용자 전용 · staleness 규칙

**Files:**
- Modify: `plugins/plugin-audit/skills/plugin-audit/SKILL.md`
- Delete: `plugins/plugin-audit/commands/plugin-audit.md`
- Modify: `plugins/plugin-audit/scripts/check-staleness.py` (규칙 (a))
- Test: `plugins/plugin-audit/tests/test_check_staleness.py` (케이스 추가) · `test_skill_orchestration.py` · `test_skill_codex_gate.py`(회귀)
- Modify: `plugins/plugin-audit/README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: `--print-head plugin-audit plugin-audit`.
- Produces: `/plugin-audit:plugin-audit <target> [--seed <path>]`(사용자 전용). check-staleness 규칙 (a)는 `skills/<name>/SKILL.md` 로 뒷받침되는 `/name` 을 dangling 으로 내지 않는다.

- [ ] **Step 1: staleness 의 실패하는 테스트를 쓴다**

`plugins/plugin-audit/tests/test_check_staleness.py` 의 `TestDanglingRefs` 안, `test_existing_self_command_not_flagged`(283 행 부근) 바로 아래에 같은 메서드를 복사해 넣는다. 이름은 `test_existing_self_skill_not_flagged` 로 바꾸고, 그 메서드가 `commands/real-cmd.md` 를 만드는 한 줄만 `skills/real-cmd/SKILL.md` 를 만드는 줄로 바꾼다(`mkdir(parents=True, exist_ok=True)` 를 함께). 단언은 그대로 «dangling 사실 0건»이다.

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -q test_check_staleness.TestDanglingRefs.test_existing_self_skill_not_flagged; cd -`
Expected: FAIL — `dangling command/plugin ref` 사실이 하나 나온다.

- [ ] **Step 2: 규칙 (a)를 고친다** — `plugins/plugin-audit/scripts/check-staleness.py` `scan_dangling_refs`

```python
                if (commands_dir / f"{m.group(1)}.md").is_file():
                    continue
```
→
```python
                if (commands_dir / f"{m.group(1)}.md").is_file():
                    continue
                if (plugin_dir / "skills" / m.group(1) / "SKILL.md").is_file():
                    continue  # 진입 skill 이 뒷받침하는 `/name` — 명령 층이 없는 플러그인의 정상 형태
```
같은 함수의 docstring 에서 `` `commands/<name>.md`가 없고 `` → `` `commands/<name>.md` 도 `skills/<name>/SKILL.md` 도 없고 `` 로 바꾼다.

Run: `cd plugins/plugin-audit/tests && python3 -m unittest -q test_check_staleness; cd -`
Expected: OK.

- [ ] **Step 3: SKILL 머리와 진입 단계**

frontmatter:
```yaml
---
name: plugin-audit
description: >
  임의의 devbrew 플러그인을 읽기전용·증거기반·multi-agent로 감사한다. 사용자가
  `/plugin-audit:plugin-audit <target> [--seed <path>]` 로 부른다(모델은 부르지 않는다).
  6축 발견 → 적대적 반박 → blind codex co-audit → 우선순위 갭 리포트.
  지출 동의 게이트·정적 게이트·Workflow·결정론 post-1 조립을 소유한다.
cost_class: high
argument-hint: "<target> [--seed <path>]"
disable-model-invocation: true
allowed-tools:
  - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" plugin-audit plugin-audit)
---
```
(`allowed-tools` 항목은 `--print-head plugin-audit plugin-audit` 출력의 둘째 줄을 붙인다.)

본문 첫 제목 아래, `## phase 0 — consent (dispatch 전 필수)` 바로 앞에 넣는다. 첫 줄은 `--print-head` 의 다섯째 줄이다.

```markdown
!`python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" plugin-audit plugin-audit`

## 진입 단계

이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽는다.

| 그 자리의 내용 | 동작 |
|---|---|
| `[devbrew-entry] ok …` | 아래 인자 해석으로 간다. 그 줄의 `root=` 값을 `--seed` 상대경로에 쓴다 |
| `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op). 실행 디렉토리를 만들지 않는다 |
| `[devbrew-entry] error …` | `[plugin-audit] 사전 검사 실패 — <reason= 값>. 감사를 시작하지 않는다.` 를 내고 멈춘다 |
| `[shell command execution disabled by policy]` | `[plugin-audit] 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 감사를 시작하지 않는다.` 를 내고 멈춘다 |
| 감시줄 없음 · 그 밖 | `[plugin-audit] 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다. 감사를 시작하지 않는다.` 를 내고 멈춘다 |

이 표가 보는 kill switch 는 `DEVBREW_PLUGIN_AUDIT_DISABLE=1` 하나다.

**인자 해석** — 받은 인자의 첫 토큰이 `<target>`(플러그인 이름)이다. 그 뒤에 `--seed <path>` 가 올 수 있고, 상대경로면 `root=` 기준으로 푼다. `<target>` 이 비었으면 `감사할 플러그인 이름이 필요합니다 — /plugin-audit:plugin-audit <target> [--seed <path>]` 를 내고 멈춘다. 그 밖이면 `target` · `seedPath` 를 들고 `## phase 0` 으로 간다.
```

`## phase 0` 의 1번 항목 `` 1. **kill switch**: `DEVBREW_PLUGIN_AUDIT_DISABLE=1`이면 즉시 종료(no-op). `` → `` 1. **kill switch**: `DEVBREW_PLUGIN_AUDIT_DISABLE=1` 이면 `## 진입 단계` 가 이미 멈췄다(no-op). ``

그다음 명령을 지운다: `git rm plugins/plugin-audit/commands/plugin-audit.md`.

- [ ] **Step 4: README · 버전 · CHANGELOG**

README:
- 99 행 `` `commands/plugin-audit.md` — 얇은 진입점. `` 줄을 지운다. 100 행은 Task 3 이 이미 `skills/plugin-audit/SKILL.md` 로 바꿨다 — 그 줄 끝에 ` 진입 단계(사전 검사 · 인자 해석) 포함.` 을 붙인다.
- 사용법(10 행 펜스 안의 `/plugin-audit <target> [--seed <path>]`)은 사람용 짧은 이름이라 그대로 둔다. 아래에 한 줄을 더한다: «같은 이름이 설치 환경에 있으면 `/plugin-audit:plugin-audit` 로 부른다. 이 skill 은 사용자만 부른다(`disable-model-invocation: true`).»
- 18 행 kill switch 줄 뒤: «본문 전 사전 검사(`scripts/entry_preflight.py`)가 이 스위치를 판정한다. 그 스크립트나 `python3` 가 없으면 플랫폼이 호출을 끊는다(헤드리스에서는 출력 없이 끝난다).»

`plugin.json` `0.10.0` → `1.0.0`. CHANGELOG 맨 위:

```markdown
## [1.0.0] — 2026-10-09

major 인 이유 — 명령 층이 사라졌고, skill 이 개명돼 사용자 전용이 됐다.

### Removed

| 옛 호출 · 이름 | 새 완전명 |
|---|---|
| `/plugin-audit` 명령 (`commands/plugin-audit.md`) | `/plugin-audit:plugin-audit` (skill) |
| skill `auditing-plugins` | `plugin-audit` |

### Changed

- skill 이 `disable-model-invocation: true` 다 — 모델이 부르지 않는다.
- 본문 전 사전 검사(`scripts/entry_preflight.py`)와 `## 진입 단계` 가 kill switch 와 인자 해석을 맡는다.
- `check-staleness.py` 규칙 (a): `skills/<name>/SKILL.md` 가 뒷받침하는 `/name` 은 dangling 이 아니다.
```

- [ ] **Step 5: 확인 · 커밋**

Run:
```bash
(cd plugins/plugin-audit/tests && python3 -m unittest -q 2>&1 | tail -2)
python3 shared/entry/check_invocation_surface.py | grep 'plugins/plugin-audit/' || echo "plugin-audit: 축 RED 0"
```
Expected: unittest `OK`(기준선 실패는 예외). `plugin-audit: 축 RED 0` — 남으면 그 행(예: scripts 주석의 bare `/plugin-audit`)을 완전명이나 산문으로 바꾼다.

```bash
git add -A plugins/plugin-audit
git commit -m "feat(plugin-audit)!: 1.0.0 — skill-only entry, user-only, staleness rule (a) sees skills" -- plugins/plugin-audit
```

---

### Task 9: project-init — 새 진입 skill

**Files:**
- Create: `plugins/project-init/skills/project-init/SKILL.md`
- Delete: `plugins/project-init/commands/project-init.md`
- Modify: `plugins/project-init/tests/test_command_contract.py` · `templates/project/charter.md` · `templates/project/conventions.md` · `README.md` · `.claude-plugin/plugin.json` · `CHANGELOG.md`

**Interfaces:**
- Consumes: `--print-head project-init project-init`.
- Produces: `/project-init:project-init`(사용자 전용, `cost_class: low`).

- [ ] **Step 1: 테스트를 새 자리로 옮긴다(실패하게)**

`plugins/project-init/tests/test_command_contract.py`:
- 1 행 docstring `` Regression lock on `commands/project-init.md` prose contracts. `` → `` Regression lock on `skills/project-init/SKILL.md` prose contracts. ``
- 24 행 `COMMAND = PLUGIN / "commands" / "project-init.md"` → `COMMAND = PLUGIN / "skills" / "project-init" / "SKILL.md"`.
- `TestMigrationPromptStillGated` 의 정규식 `` 사용자 거절 시.*전체 `/project-init` 실행 abort `` → `` 사용자 거절 시.*전체 `/project-init:project-init` 실행 abort ``.

Run: `cd plugins/project-init/tests && python3 -m unittest -q test_command_contract; cd -`
Expected: FAIL — 파일이 없다.

- [ ] **Step 2: skill 을 만든다**

```bash
mkdir -p plugins/project-init/skills/project-init
python3 shared/entry/check_invocation_surface.py --print-head project-init project-init
```
`plugins/project-init/skills/project-init/SKILL.md` 를 다음 순서로 쓴다:

1. frontmatter
   ```yaml
   ---
   name: project-init
   description: >
     프로젝트의 git workflow 규칙(브랜치 전략 · 커밋 규약 · PR 절차)과 project charter 를 대화형으로
     초기화한다. 사용자가 `/project-init:project-init` 으로 부른다 — 파일을 쓰는 셋업이라 모델은 부르지 않는다.
   cost_class: low
   disable-model-invocation: true
   allowed-tools:
     - Bash(python3 "${CLAUDE_SKILL_DIR}/../../scripts/entry_preflight.py" project-init project-init)
   ---
   ```
2. 빈 줄, `--print-head` 다섯째 줄(사전 검사 줄), 빈 줄.
3. 진입 단계:
   ```markdown
   ## 진입 단계

   이 절이 다른 모든 절보다 먼저 돈다. 이 제목 바로 위, 사전 검사 줄이 남긴 자리를 읽는다.

   | 그 자리의 내용 | 동작 |
   |---|---|
   | `[devbrew-entry] ok …` | 아래 `# project-init` 의 지시사항으로 간다. 셋업 대상 디렉토리는 그 줄의 `root=` 다 — `root_source=cwd` 면 git 이 아직 없는 현재 디렉토리다 |
   | `[devbrew-entry] disabled …` | 그 줄을 그대로 보이고 멈춘다(no-op). 파일을 쓰지 않는다 |
   | `[devbrew-entry] error …` | `[project-init] 사전 검사 실패 — <reason= 값>. 셋업을 시작하지 않는다.` 를 내고 멈춘다 |
   | `[shell command execution disabled by policy]` | `[project-init] 사전 검사 불가(정책) — disableSkillShellExecution 이 사전 검사를 막았다. 셋업을 시작하지 않는다.` 를 내고 멈춘다 |
   | 감시줄 없음 · 그 밖 | `[project-init] 사전 검사 결과 없음 — 그 자리에 감시줄이 없다(치환 실패 · 출력 소실). 정책 설정과는 무관하다. 셋업을 시작하지 않는다.` 를 내고 멈춘다 |

   이 표가 보는 kill switch 는 `DEVBREW_PROJECT_INIT_DISABLE=1` 하나다. 이 스위치는 훅과 이 셋업을 함께 끈다.
   ```
4. `commands/project-init.md` 의 5 행(`# project-init`)부터 끝(230 행)까지를 그대로 옮긴다. 옮긴 뒤 그 범위의 bare `` `/project-init` `` 을 전부 `` `/project-init:project-init` `` 로 바꾼다(지금 28 · 162 · 164 행 — `grep -n '/project-init' <새 SKILL>` 로 전수 확인). `` `/commit` `` · `` `/commit-push-pr` `` (다른 플러그인)은 그대로 둔다.

그다음 명령을 지운다: `git rm plugins/project-init/commands/project-init.md`.

- [ ] **Step 3: 템플릿 · README · 버전 · CHANGELOG**

- `templates/project/charter.md:3` · `templates/project/conventions.md:3` 의 `` `/project-init` `` → `` `/project-init:project-init` `` (사용자 프로젝트에 복사되는 기계 산출물이다).
- README:
  - 12~13 행 트리의 `├── commands/` · `│   └── project-init.md …` 두 줄 → `├── skills/` · `│   └── project-init/SKILL.md      # /project-init — 인터랙티브 셋업(사용자 전용)`.
  - 20 행 `test_command_contract.py     # v1.7.2 — commands/ 산문 계약 회귀 락` → `test_command_contract.py     # skills/project-init 산문 계약 회귀 락`.
  - 61 행 `**`/project-init` command**` → `**`/project-init` skill**`.
  - 92 행 kill switch 줄 뒤에 둘을 더한다: «5.0.0 부터 `DEVBREW_PROJECT_INIT_DISABLE=1` 은 훅만이 아니라 `/project-init` 진입도 `disabled` no-op 으로 만든다. `DEVBREW_SKIP_HOOKS` 는 진입 skill 에 걸리지 않는다.» · «사전 검사 스크립트(`scripts/entry_preflight.py`)나 `python3` 가 없으면 플랫폼이 호출을 끊는다(헤드리스에서는 출력 없이 끝난다).»
  - 46 · 107 행의 `/project-init`(사람용 짧은 이름)은 그대로 둔다. 107 행 아래에 «같은 이름이 설치 환경에 있으면 `/project-init:project-init`» 한 줄을 더한다.
- `plugin.json` `4.0.2` → `5.0.0`.
- CHANGELOG 맨 위:
  ```markdown
  ## [5.0.0] — 2026-10-09

  ### Removed

  | 옛 호출 · 이름 | 새 완전명 |
  |---|---|
  | `/project-init` 명령 (`commands/project-init.md`) | `/project-init:project-init` (skill, 사용자 전용) |

  ### Changed

  - `DEVBREW_PROJECT_INIT_DISABLE=1` 의 의미가 넓어졌다 — 훅에 더해 `/project-init` 진입도 `disabled` no-op 으로 끝난다.
  - 셋업 본문이 `skills/project-init/SKILL.md` 로 옮겨 왔다(`cost_class: low`, `disable-model-invocation: true`). 본문 전 사전 검사(`scripts/entry_preflight.py`)가 kill switch 와 셋업 루트(`root=`)를 정한다.
  - 템플릿 `project/charter.md` · `project/conventions.md` 의 안내가 완전명 `/project-init:project-init` 을 쓴다.
  ```

- [ ] **Step 4: 확인 · 커밋**

Run:
```bash
(cd plugins/project-init/tests && python3 -m unittest -q 2>&1 | tail -2)
for t in $(git ls-files -- ':(glob)plugins/project-init/tests/test_*.sh'); do bash "$t" >/dev/null 2>&1 || echo "RC≠0 $t"; done
python3 shared/entry/check_invocation_surface.py | grep 'plugins/project-init/' || echo "project-init: 축 RED 0"
```
Expected: unittest `OK` — `TestS2aH1Retitle` · `TestCompletionReportPromisesOnlyWhatShips` 의 유일성 단언이 진입 단계와 겹치지 않는다. `RC≠0` 이 없다. `project-init: 축 RED 0`.

```bash
git add -A plugins/project-init
git commit -m "feat(project-init)!: 5.0.0 — /project-init becomes a user-only entry skill" -- plugins/project-init
```

---

### Task 10: CLAUDE.md · 저술 문서 · 철학 문서

**Files:**
- Modify: `CLAUDE.md` (36 · 42 · 70 · 87 행) · `docs/plugin-authoring.md` (13 · 14 · 31 행 부근) · `docs/philosophy/devbrew-harness-philosophy.md` (23 · 44 · 52 · 68 행)

**Interfaces:**
- Produces: §5 문면. 보고서 1부(Task 12)가 이 문면을 인용한다.

- [ ] **Step 1: 실패를 확인한다**

Run: `python3 shared/entry/check_invocation_surface.py | grep -E ' (CLAUDE\.md|docs/)'`
Expected: `CLAUDE.md:87` 과 철학 문서 넷의 축 I RED.

- [ ] **Step 2: CLAUDE.md 네 자리** (설계 §5 문면 그대로)

1. 36 행 끝 `제거 전 one-minor deprecation window.` → `제거 전 one-minor deprecation window. 예외 — 호출 이름(slash 명령 · skill 이름)의 변경·제거는 alias 없이 즉시 하고 major bump 한다. 이 예외는 제3자 설치가 확인되면(외부 이슈 · 설치 보고 · 마켓플레이스 공개 등록) 소멸한다. kill switch 이름은 이 예외에 들지 않는다 — 은퇴시키려면 CHANGELOG `Removed` 와 README 에 공시가 필수다.`
2. 42 행 첫 문장 `**Command frontmatter의 `allowed-tools`는 쓰지 않는다.**` → `**`allowed-tools` 는 제한이 아니다.** command 에서는 쓰지 않는다. skill 에서는 진입 사전 검사 한 줄의 사전 허용으로만 쓰고 다른 도구를 열거하지 않는다.` 그 뒤의 실측 기록 문장(2026-08-22 …)은 남긴다.
3. 70 행 전체 → `- **Progressive disclosure.** 사용자가 부르는 진입 skill 은 짧은 kebab 두 단어 이상(일반어 단독 금지 — `spec-review`, `plugin-audit`)이고 디렉토리 이름 = `name` 이다. 모델만 부르는 내부 skill(`user-invocable: false`)은 동명사(`reviewing-brief`). 기계가 내는 안내는 `/plugin:name` 완전명. 새 `commands/` 는 만들지 않는다 — 사전 단계는 진입 skill 의 `!` 로. 모호한 이름 (`helper`, `utils`, `"I can help you..."`) 없음. 집행: `shared/tests/test_invocation_surface.sh`.`
4. 87 행: `` `reviewing-spec` 의 `## 게이트` 절과 `conducting-interview` 종료 Step B `` → `` `spec-review` 의 `## 게이트` 절과 `spec-interview` 종료 Step B ``. 같은 줄의 다른 옛 이름도 같은 대응으로 바꾼다.

- [ ] **Step 3: 저술 문서 · 철학 문서**

`docs/plugin-authoring.md`:
- 13 행 `├── commands/                 # optional — 짧은 명령형: qg.md, review.md` 줄을 지운다.
- 14 행 `├── skills/<gerund-name>/     # optional — running-x, authoring-y (동명사)` → `├── skills/<name>/            # 진입 skill 은 짧은 kebab(spec-review), 내부 skill(user-invocable: false)은 동명사(reviewing-brief)`.
- `plugins/project-init/` reference 줄의 `` `commands/`, `hooks/`, `templates/`를 shipping. `agents/`나 `skills/` 없음 — hooks-and-templates 플러그인도 유효한 형태. `` → `` 사용자 전용 진입 skill 하나(`skills/project-init/`)와 `hooks/`, `templates/`를 shipping. `agents/` 없음 — skill 하나 + hooks-and-templates 도 유효한 형태. ``
- quality-gates reference 줄의 `` `agents/`, `commands/`, `hooks/`, `scripts/`, `skills/`를 shipping `` 은 사실이므로 그대로 둔다.

`docs/philosophy/devbrew-harness-philosophy.md`:
- 23 행 `plugins/spec-distill/skills/conducting-interview/SKILL.md` → `plugins/spec-distill/skills/spec-interview/SKILL.md`.
- 44 행 `` `plugins/spec-distill/commands/interview.md` (trivia escape) `` → `` `plugins/spec-distill/skills/spec-interview/SKILL.md` 의 `## 진입 단계` 3 (trivia escape) ``.
- 52 · 68 행 `skills/reviewing-spec/SKILL.md` → `skills/spec-review/SKILL.md`.

- [ ] **Step 4: 확인 · 커밋**

Run: `python3 shared/entry/check_invocation_surface.py | grep -E ' (CLAUDE\.md|docs/)' || echo "docs: 축 RED 0"`
Expected: `docs: 축 RED 0`.

```bash
git commit -m "docs: CLAUDE.md naming · allowed-tools · deprecation rules for skill-only surface" -- CLAUDE.md docs/plugin-authoring.md docs/philosophy/devbrew-harness-philosophy.md
```

---

### Task 11: 락 GREEN · 실제 사본 변이 · manifest 단계

**Files:**
- Modify: `shared/tests/test_invocation_surface.sh` (3부 · 4부 추가)
- Modify: 락이 남긴 잔여 RED 를 낸 파일들(아래 Step 1 의 목록으로 확정)

**Interfaces:**
- Consumes: Task 1~10 의 결과.
- Produces: `test_invocation_surface.sh` 전 구간 GREEN — AC6 의 증거.

- [ ] **Step 1: 잔여 RED 를 0 으로**

Run: `python3 shared/entry/check_invocation_surface.py`
Expected 이전 상태: 남은 RED 가 있으면 행마다 처분한다. 처분은 셋 중 하나다.
- 축 G bare 이름 → 완전명이나 산문으로 바꾼다.
- 축 I → 새 이름으로 바꾼다. 테스트 안의 부재 단언 리터럴이면 조각으로 잇는다.
- 축 D → 사용자 인자 토큰을 그 줄에서 뺀다.

처분 목록은 커밋 메시지에 남긴다. **제외를 새로 더하지 않는다** — 더하려면 설계 §4 를 고치고 사용자 확인을 받는다.
Expected 이후: `[invocation-surface] GREEN — qg 보고 행 N건. qg 는 … 보고만 된다(--report)`.

고친 파일을 **이 Step 에서 커밋한다** — 3부는 `git clone --no-local` 로 HEAD 를 복제하므로 커밋하지 않은 수정은 사본에 없다:

```bash
git commit -m "fix: clear residual invocation-surface REDs (<처분 요약>)" -- <고친 경로들>
```

- [ ] **Step 2: 3부 · 4부를 테스트에 더한다** — `shared/tests/test_invocation_surface.sh` 의 2부 뒤, `finish` 앞

```bash
# ── 3부: 이 리포의 사본에 실제 변이 ─────────────────────────────
CL="$TMP/clone"
git clone -q --no-local "$ROOT" "$CL"
if [ "$(git -C "$CL" rev-parse --is-shallow-repository)" != "false" ]; then no "사본이 얕다 — 변이 결과를 믿을 수 없다"; fi
expect_green "$CL" "실제 사본 양성 대조: HEAD GREEN"
real() {   # real <name> — 실제 사본의 변이용 복제
  rm -rf "$TMP/r-$1"; cp -R "$CL" "$TMP/r-$1"
}
RSR="plugins/spec-distill/skills/spec-review/SKILL.md"
RBANG="$(python3 "$LOCK" --print-head spec-distill spec-review | sed -n '5p')"
real c; edit "$TMP/r-c/$RSR" "$RBANG" "";                                    expect_red "$TMP/r-c" C "실제 C 삭제: spec-review 사전 검사 줄"
real d; edit "$TMP/r-d/$RSR" "spec-distill spec-review\`" "spec-distill spec-review \$ARGUMENTS\`"; expect_red "$TMP/r-d" D "실제 D 추가: 사전 검사 줄에 \$ARGUMENTS"
real f; edit "$TMP/r-f/plugins/project-init/skills/project-init/SKILL.md" "disable-model-invocation: true
" "";                                                                         expect_red "$TMP/r-f" F "실제 F 반전: project-init 사용자 전용 해제"
real g; put "$TMP/r-g/plugins/spec-distill/skills/request-framing/SKILL.md" "다음은 /spec-interview 다"; expect_red "$TMP/r-g" G "실제 G 추가: bare 진입 이름"
real h; put "$TMP/r-h/plugins/project-init/commands/project-init.md" "---";  expect_red "$TMP/r-h" H "실제 H 추가: 명령 층 부활"
real i; put "$TMP/r-i/CLAUDE.md" "reviewing-spec";                           expect_red "$TMP/r-i" I "실제 I 추가: 옛 이름 재삽입"
real n; put "$TMP/r-n/plugins/spec-distill/scripts/n.py" "# docs/superpowers/interview/x.md · plugins/plugin-audit/README.md"
expect_green "$TMP/r-n" "실제 음성 대조: 경로 조각은 GREEN"

# ── 4부: manifest — claude plugin validate --strict ─────────────
# 면제는 하나다: hooks 명령의 따옴표 없는 ${CLAUDE_PLUGIN_ROOT} 경고(선재, 2026-10-09 실측).
# 그 면제는 qg 핸드오프 보고서 3부의 행이다.
if command -v claude >/dev/null 2>&1; then
  for p in spec-distill plugin-audit project-init; do
    v="$(claude plugin validate --strict --json "$ROOT/plugins/$p" 2>/dev/null)"
    bad="$(printf '%s' "$v" | python3 -c '
import json, sys
d = json.load(sys.stdin)
items = [d.get("manifest") or {}] + list(d.get("contents") or [])
EXEMPT = "Shell command uses ${CLAUDE_PLUGIN_ROOT} without quotes"
for c in items:
    for e in c.get("errors") or []:
        print("error", c.get("file", "?"), e.get("path"), e.get("message"))
    for w in c.get("warnings") or []:
        if str(w.get("path", "")).startswith("hooks.") and str(w.get("message", "")).startswith(EXEMPT):
            continue
        print("warning", c.get("file", "?"), w.get("path"), w.get("message"))
' 2>&1)"
    assert_eq "$bad" "" "manifest: $p 가 validate --strict 를 통과한다(hooks 따옴표 경고 면제)"
  done
else
  note "  ⚠ SKIPPED manifest 단계 — claude CLI 가 PATH 에 없다. 이 단계는 재지 않았다."
fi
```

- [ ] **Step 3: 전 구간 GREEN 과 관련 shared 락**

Run:
```bash
bash shared/tests/test_invocation_surface.sh 2>&1 | tail -15
for t in test_copy_of_contract test_no_new_duplication test_skill_body_no_positional_tokens test_plugin_root_no_cwd_fallback test_skill_reference_pointers test_dispatch_disposition test_entry_preflight; do bash shared/tests/$t.sh >/dev/null 2>&1 || echo "RC≠0 $t"; done
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | tail -1
bash plugins/quality-gates/tests/test_codex_gate_observation.sh | tail -1
```
Expected: `test_invocation_surface.sh` 가 `Fail: 0` 이다(1부 28 · 2부 1 · 3부 8 · 4부 3 — `claude` 부재면 4부는 SKIPPED 공시). `RC≠0` 이 없다(기준선 RED 는 예외). guards · codex-gate 는 `Fail: 0` 이다. 3부의 실제 변이가 GREEN 으로 남으면 락이 그 축을 놓친 것이다 — 락을 고친다. 변이를 바꿔서 통과시키지 않는다.

- [ ] **Step 4: 커밋**

```bash
git commit -m "test(shared): invocation-surface lock GREEN on repo + clone mutations + manifest step" -- shared/tests/test_invocation_surface.sh
```

---

### Task 12: qg 핸드오프 보고서

**Files:**
- Create: `docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md`

**Interfaces:**
- Consumes: `check_invocation_surface.py --report`, Task 10 의 CLAUDE.md 문면, v10 설계 `git show 5eccf37c:docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md`.
- Produces: AC13 산출물. 사용자에게 경로를 넘긴다.

- [ ] **Step 1: 원천을 모은다**

```bash
python3 shared/entry/check_invocation_surface.py --report > "$HOME/.claude/sdd-mirror/unify-command-surface/qg-report.md"
git show 5eccf37c:docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md > "$HOME/.claude/sdd-mirror/unify-command-surface/v10.md"
wc -l "$HOME/.claude/sdd-mirror/unify-command-surface/qg-report.md" "$HOME/.claude/sdd-mirror/unify-command-surface/v10.md"
```
Expected: 보고 표 행이 있다 — 최소한 축 I(`quality-pipeline/SKILL.md:394` · `critiquing-artifacts/SKILL.md:154` · `run_codex_reviewer.sh:49` · `test_codex_gate_observation.sh:70` · `reconstruct-skill.sh:77-78`), 축 A(`critiquing-artifacts` · `publishing-pr-understanding`), 축 C(qg skill 셋), 축 H(qg 명령 셋). v10 은 743 줄.

- [ ] **Step 2: 보고서를 쓴다** — 아래 뼈대를 채운다. v10 칸은 행마다 v10 원문에서 그 파일 · 이름을 grep 해 채운다. 다루면 «다룸(L<n>: 삭제/수정)», 아니면 «언급 없음»이다.

```markdown
# skill-only 호출 표면 — qg 핸드오프

> v10 이 따를 규칙과, 이 작업이 고치지 않은(C3) qg 위반의 목록.

- 규칙 정본: `docs/superpowers/specs/2026-10-09-skill-only-surface-design.md` (B1 — 이 작업이 규칙을 소유하고 v10 이 따른다)
- 대조 기준: v10 설계 `docs/superpowers/specs/2026-10-08-qg-v10-rebuild-design.md` @ `5eccf37c82ee6f000baefb0e8e972733ba07eb38` (브랜치 `feature/qg-v10-cleanup`)
- 이 브랜치가 qg 에서 바꾼 것: B6 넷 — `tests/test_codex_gate_observation.sh` 라벨 `case` 줄과 그 주석, `plugin.json` 9.3.7, `CHANGELOG.md` 한 항목

## 1부 — v10 이 따를 변경

1. 진입은 `!` 사전 검사를 가진 skill 이다. 형태 — `allowed-tools` 한 항목 + 본문 사전 검사 줄 + `## 진입 단계`(감시줄 판독 표). 정본 스크립트 `shared/entry/entry_preflight.py` 를 `plugins/quality-gates/scripts/` 에 링크로 싣는다.
2. 새 `commands/` 는 만들지 않는다. `plugins/quality-gates/commands/` 가 사라지면 락 `shared/tests/test_invocation_surface.sh` 의 qg 보고 모드가 끝나고, 2부 행이 RED 가 된다.
3. CLAUDE.md 개정 문면(인용):
   > <Task 10 Step 2 의 1~3 문면을 그대로 인용>
4. B6 라벨 줄: `test_codex_gate_observation.sh` 의 `case "$label"` 는 skill 디렉토리 이름을 열거한다 — 디렉토리를 바꾸면 그 줄도 같은 커밋에서 바꾼다.

## 2부 — 락이 재는 축의 qg 위반

<qg-report.md 의 표를 붙이고 «v10 설계» 칸을 채운다>

## 3부 — 락이 재지 않는 qg 위반

| # | 출처 | 위반 | 위치 | v10 설계 |
|---|---|---|---|---|
| 1 | RC4 | `/qg --reset` 은 SID 가 비어 있지 않은지만 보고, 패턴 가드 · worktree 정리 · KEEP_WORKTREE 를 거치지 않는다 | `plugins/quality-gates/commands/qg.md` (Special argument `--reset`) | |
| 2 | RC5 | `/cancel-qg` 설명의 v1.32.0, quality-pipeline 제목의 v9.3.5 가 plugin.json 과 어긋난다 | `commands/cancel-qg.md:2` | |
| 3 | RC6 | `hide-from-slash-command-tool` 은 인식되지 않는 키라 오류 없이 무시된다 | `commands/cancel-qg.md:4` | |
| 4 | RC8 | README 사용법 절의 이름 · 위치가 플러그인마다 다르고, qg README 사용 블록에 `/qg-publish` 가 없다 | `plugins/quality-gates/README.md` | |
| 5 | RC10 | 명령 이름을 안내하는 곳에 hook 과 스크립트도 있다(bare `/qg` · `/cancel-qg`) | `hooks/session-start-advisor.py:183,191-192` · `scripts/setup-qg.sh:98,121,142-143,185,322` · `scripts/synthesize_findings.py:699` | |
| 6 | RC18 | 고칠 수 없는 qg SessionStart 훅이 `/cancel-qg` 를 bare 이름으로 안내한다 | `hooks/session-start-advisor.py:183` | |
| 7 | P11 | `claude plugin validate --strict` 경고 — hooks 명령의 따옴표 없는 `${CLAUDE_PLUGIN_ROOT}` (spec-distill · project-init 도 같은 경고, 락 4부가 면제) | `hooks/hooks.json` (SessionStart · SessionEnd) | |

## 부록 — 미실행 seed 판별

규칙: <plan P10 의 ①② 그대로>. 결과(2026-10-09): 네 파일, 옛 호출 줄 0줄 — 갱신 0건.
```

- [ ] **Step 3: 확인 · 커밋**

Run: `grep -c '^| [0-9]' docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md; grep -n '| |$' docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md | head`
Expected: 첫 수는 2부 행 + 3부 7행이다. 둘째 명령은 출력이 없다(빈 v10 칸 없음).

```bash
git add docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md
git commit -m "docs(spec): skill-only surface — qg handoff report (rules · lock report · out-of-lock rows)" -- docs/superpowers/specs/2026-10-09-skill-only-surface-qg-handoff.md
```

---

### Task 13: 실측 M1~M6 (격리 설치본)

**Files:**
- Create: `~/.claude/sdd-mirror/unify-command-surface/measure/run_m.sh` (리포 밖)
- Modify: `docs/superpowers/specs/2026-10-09-skill-only-surface-design.md` §7 (결과 기록)

**Interfaces:**
- Consumes: 브랜치 HEAD(`marketplace add <워크트리>` 는 워킹트리를 직접 가리킨다 — 실측 전 `git status` 가 깨끗해야 한다).
- Produces: §7 의 M1 · M2 · M3 · M5 · M6 통과 기록(머지 게이트)과 M4 사용자 절차.

판정은 rc 가 아니라 stream-json 출력의 내용으로 한다. **게이트 실측이 틀리면 패치로 덮지 않고 설계로 돌아간다** — 결과를 사용자에게 보고하고 멈춘다.

- [ ] **Step 1: 격리를 증명하고 설치한다**

```bash
ISO="$HOME/.claude/sdd-mirror/unify-command-surface/measure/iso"; rm -rf "$ISO"; mkdir -p "$ISO"
CLAUDE_CONFIG_DIR="$ISO" claude plugin marketplace list            # 0개여야 한다 — 아니면 멈춘다
CLAUDE_CONFIG_DIR="$ISO" claude plugin marketplace add /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/unify-command-surface
for p in spec-distill plugin-audit project-init; do CLAUDE_CONFIG_DIR="$ISO" claude plugin install "$p@devbrew" -s user -y; done
find "$ISO/plugins/cache" -name entry_preflight.py -exec ls -l {} \;   # 일반 파일 셋(링크 아님)
claude plugin marketplace list | wc -l                                # 실제 쪽 개수가 그대로인지
CLAUDE_CONFIG_DIR="$ISO" claude -p "say ok" --model haiku --output-format json | head -c 300
```
Expected: 격리 쪽 첫 목록은 0개다. 설치 뒤 캐시 안 `entry_preflight.py` 셋은 일반 파일이다. 마지막 줄이 `"result"` 를 담는다. 마지막 줄이 로그인 오류면 사용자에게 `! CLAUDE_CONFIG_DIR=<ISO 절대경로> claude /login` 을 한 번 실행해 달라고 요청하고 기다린다.

- [ ] **Step 2: 측정 스크립트** — `~/.claude/sdd-mirror/unify-command-surface/measure/run_m.sh`

```bash
#!/bin/bash
# run_m.sh <label> <prompt> [ENV=VAL ...] — 격리 설치본에서 headless 1회, 기본 권한 모드
M="$HOME/.claude/sdd-mirror/unify-command-surface/measure"; ISO="$M/iso"
label="$1"; prompt="$2"; shift 2
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/unify-command-surface || exit 1
env CLAUDE_CONFIG_DIR="$ISO" "$@" claude -p "$prompt" --model haiku --permission-mode default --max-turns 4 \
  --output-format stream-json --verbose > "$M/out-$label.jsonl" 2> "$M/err-$label.txt"
echo "rc=$?"
python3 - "$M/out-$label.jsonl" <<'PY'
import json, sys
for line in open(sys.argv[1], encoding="utf-8"):
    try:
        d = json.loads(line)
    except ValueError:
        continue
    s = json.dumps(d, ensure_ascii=False)
    if d.get("type") == "result":
        print("RESULT turns=%s | %s" % (d.get("num_turns"), (d.get("result") or "")[:400].replace("\n", " / ")))
    elif any(k in s for k in ("[devbrew-entry]", "by policy", "Unknown command", "사전 검사", "disable-model-invocation")):
        print(d.get("type"), s[:500])
PY
```

- [ ] **Step 3: 측정한다**

| # | 명령 | 통과 조건 |
|---|---|---|
| M1 | `bash run_m.sh m1 "Use the Skill tool to invoke spec-distill:spec-review with the argument docs/superpowers/specs/2026-10-09-skill-only-surface-design.md and follow it." DEVBREW_SPEC_DISTILL_DESIGN_MODE_DISABLE=1` | 주입 본문(user 메시지)에 `[devbrew-entry] ok plugin=spec-distill skill=spec-review` 가 있다. 1.5 가 `review-entry: DISABLED` 로 멈춘다(지출 없음) |
| M2 | 다섯 이름 × 두 모양: `bash run_m.sh m2-<s>-bare "/<s> x" DEVBREW_<P>_DISABLE=1` · `bash run_m.sh m2-<s>-full "/<p>:<s> x" DEVBREW_<P>_DISABLE=1` (p/s = spec-distill/request-framing · spec-distill/spec-interview · spec-distill/spec-review · plugin-audit/plugin-audit · project-init/project-init) | 열 번 모두 RESULT 에 `[devbrew-entry] disabled plugin=<p> skill=<s>` 가 있다. `Unknown command` 는 0이다 |
| M3 | 사람: M2 의 plugin-audit · project-init 행으로 갈음한다. 모델: `bash run_m.sh m3 "Use the Skill tool to invoke plugin-audit:plugin-audit with argument spec-distill." DEVBREW_PLUGIN_AUDIT_DISABLE=1` | 모델 쪽에서는 Skill 이 거부되거나 목록에 없고, 주입 본문 `[devbrew-entry] … skill=plugin-audit` 이 **없다** |
| M5 | `printf '{"disableSkillShellExecution": true}\n' > "$ISO/settings.json"` 뒤 `bash run_m.sh m5 "/spec-distill:spec-review x"`, 측정 뒤 `rm "$ISO/settings.json"` | RESULT 에 `사전 검사 불가(정책)` 이 있고, 리뷰가 시작되지 않았다 |
| M6 | `bash run_m.sh m6 "/spec-distill:spec-interview hello" DEVBREW_SPEC_DISTILL_DISABLE=1` | RESULT 에 `[devbrew-entry] disabled plugin=spec-distill skill=spec-interview switch=DEVBREW_SPEC_DISTILL_DISABLE=1` 이 있다. state 디렉토리가 새로 생기지 않았다 |

- [ ] **Step 4: M4 를 사용자에게 넘긴다** — 다음 절차를 그대로 보여 주고, 사용자의 결과 보고를 기다린다.

> M4 (대화형, 사용자 실행): ① 이 워크트리 디렉토리에서 새 Claude Code 세션을 열고 `/spec-distill:spec-interview @docs/superpowers/interview/2026-10-08-unify-command-surface-interview.md` 를 친다 → `[spec-distill] seed 원문 대조: seed=… · audit=…` 줄이 나오면 첫 질문 전에 멈춰도 된다. ② main 체크아웃(`/Users/jeonghokim/Downloads/devbrew`)에서 같은 명령을 친다 → `'@…' 를 읽지 못했다 — 시도: …` 문구가 나와야 한다. 두 결과(그대로 붙여넣기)를 알려 주세요.

- [ ] **Step 5: 기록 · 정리 · 커밋**

설계 §7 표 아래에 `#### 결과 (2026-10-09, Claude Code <claude --version>)` 소절을 만들고 M1~M6 · E0 의 결과를 행마다 «통과 / 실패 + 관측 한 줄»로 적는다. M4 결과가 오면 §3-2 최종 규칙을 그 아래에 한 줄로 확정한다. M4 가 오기 전에는 «대기»로 둔다.

```bash
rm -rf "$HOME/.claude/sdd-mirror/unify-command-surface/measure/iso"
git commit -m "docs(spec): skill-only surface — §7 measurements (M1–M6, E0)" -- docs/superpowers/specs/2026-10-09-skill-only-surface-design.md
```

---

### Task 14: 종료 — 기준선 대조 · 범위 확인 · 메모리

**Files:**
- Modify: 메모리 `/Users/jeonghokim/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/` 의 옛 호출 이름 줄 · `MEMORY.md`
- Modify (필요할 때만): 네 `plugin.json` · `CHANGELOG.md` 의 번호

**Interfaces:**
- Consumes: Task 0 의 `baseline.sh` · `baseline-<sha>.tsv`.

- [ ] **Step 1: 기준선을 대조한다**

```bash
B=~/.claude/sdd-mirror/unify-command-surface
bash $B/baseline.sh $B/after-$(git rev-parse --short=7 HEAD).tsv
python3 - $B/baseline-*.tsv $B/after-*.tsv <<'PY'
import sys
def load(p):
    return {r.split("\t")[0]: (int(r.split("\t")[1]), int(r.split("\t")[2])) for r in open(p) if r.strip()}
base, after = load(sys.argv[1]), load(sys.argv[2])
bad = []
for f, (rc, nf) in sorted(after.items()):
    b = base.get(f)
    if b is None:
        if rc != 0: bad.append("새 파일 RED: %s rc=%d" % (f, rc))
    elif (b[0] == 0 and rc != 0) or nf > b[1]:
        bad.append("회귀: %s rc %d→%d · 실패 줄 %d→%d" % (f, b[0], rc, b[1], nf))
for f in sorted(set(base) - set(after)):
    bad.append("사라진 테스트(개명 확인): %s" % f)
print("\n".join(bad) if bad else "AC12: 새 RED 0 · 실패 줄 증가 0")
PY
```
Expected: `AC12: 새 RED 0 · 실패 줄 증가 0`. 단, «사라진 테스트» 두 줄(`test_conducting_interview_internal.sh` · `test_request_framing_command.sh`)은 Task 5 · 6 의 `git mv` 이고, 그 새 이름이 after 에서 rc 0 이어야 한다.

- [ ] **Step 2: qg 범위(AC10)와 base 이동**

```bash
git fetch origin
git diff origin/main...HEAD --stat -- plugins/quality-gates     # 정확히 3 files
git log --oneline HEAD..origin/main | wc -l                     # base 이동량
git merge-tree --write-tree origin/main HEAD >/dev/null && echo "merge-tree: 충돌 없음"
for p in spec-distill plugin-audit project-init quality-gates; do printf '%s main=%s branch=%s\n' "$p" "$(git show origin/main:plugins/$p/.claude-plugin/plugin.json | python3 -c 'import json,sys;print(json.load(sys.stdin)["version"])')" "$(python3 -c 'import json;print(json.load(open("plugins/'$p'/.claude-plugin/plugin.json"))["version"])')"; done
```
Expected: qg diff 3 files. 각 플러그인의 branch 번호가 `origin/main` 번호보다 크다(spec-distill · project-init major, plugin-audit 1.0.0, qg patch). `origin/main` 이 그사이 같은 플러그인을 올렸으면 번호를 다시 정하고, CHANGELOG 헤딩과 함께 고쳐 커밋한다. qg v10 이 먼저 머지됐다면 qg 의 ③ · ④(B6)는 나중에 머지하는 이 브랜치가 해소한다.

- [ ] **Step 3: 메모리(AC14)**

```bash
grep -rn -E '/interview|conducting-interview|framing-requests|reviewing-spec|auditing-plugins' /Users/jeonghokim/.claude/projects/-Users-jeonghokim-Downloads-devbrew/memory/ | cut -c1-200
```
줄마다 판단한다.
- 사용자가 칠 호출 안내(`/interview @…`)는 `/spec-distill:spec-interview @…` 로 고친다.
- 과거 측정 사실(예: «커맨드 인자의 `@경로` 는 헤드리스에서 안 풀린다»)은 사실 문장을 그대로 두고, 끝에 «(2026-10-09 이후 `/interview` 는 `spec-interview` skill 의 진입 단계가 `@` 를 푼다)»를 붙인다.

`MEMORY.md` 의 해당 인덱스 줄도 같은 기준으로 고친다. 이 프로젝트 기억(`project_…`)이 없으면 하나를 새로 쓴다 — 이름은 `project_skill_only_surface.md`, 내용은 «브랜치 · 계획 경로 · 머지 게이트 M1~M6 상태 · qg 핸드오프 보고서 경로»다.

- [ ] **Step 4: 최종 리뷰를 dispatch 한다** (fresh reviewer, opus, 쓰기 권한 없음)

리뷰어에게 다섯 가지를 명시해 묻는다.
1. 끝에서 끝 흐름 — `/spec-distill:request-framing` → seed → `/spec-distill:spec-interview @seed` → «풀린 입력» → S1 → brief → `spec-review`.
2. 감시줄의 다섯 행이 각 skill 에서 실제로 멈추는가 — 특히 spec-review 의 복귀 문장.
3. `entry_preflight.py` 의 rc 가 어떤 경로에서도 0 인가.
4. 계획이 직접 쓴 테스트 코드(Task 1 · 2 · 11 — plan-mandated 라벨)의 단언이 공허하지 않은가.
5. 락 I 의 fixture 제외와 manifest 면제(P11 · P12)가 넓지 않은가.

리뷰어의 발견마다 적대적 검증을 거친 뒤 고친다.

- [ ] **Step 5: 커밋 · 보고**

```bash
git status --short     # 깨끗해야 한다
```
사용자에게 보고한다: 브랜치 · 커밋 수 · AC1~AC14 상태 · M4 대기 여부 · qg 핸드오프 보고서 경로 · P11 · P12 확인 요청. PR 생성과 머지는 사용자 요청이 있을 때만 한다(머지는 `! gh pr merge <n> --merge`).
