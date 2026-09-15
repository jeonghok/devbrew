# 플러그인 루트 cwd fallback 제거 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 어떤 cwd 에서 실행돼도 devbrew skill 이 자기 플러그인의 스크립트 · 프로필만 실행하고, 루트를 풀지 못하면 cwd 로 가지 않고 멈추게 한다.

**Architecture:** SKILL.md 펜스는 로드 시 치환되는 bare `${CLAUDE_PLUGIN_ROOT}` 를 변수에 받고, 같은 줄의 가드(빈 값 → stderr 복구 지시 + `exit 1`)를 지난다. `Read` 로 열리는 reference 파일은 치환이 오지 않으므로 같은 가드를 두고, 그 파일을 여는 SKILL.md 의 `Read` 줄을 치환되는 절대 형태로 바꾼 뒤 바로 아래에 안내 문장 한 줄을 둔다. 규칙은 새 공용 락 하나가 전 플러그인에 집행하고, 반증된 전제의 qg 락은 지운다.

**Tech Stack:** bash 3.2(macOS 시스템 bash) · python3 3.9 · `shared/tests/assert.sh` · `git ls-files`.

**Spec:** `docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md` — 「결정 기록」(D1–D12 · D1.1–D3.9)과 `### Deferred to plan` 이 정본이다. 실행자는 이 계획과 설계를 함께 읽는다.

## 목차

- [Global Constraints](#global-constraints)
- [AC 추적](#ac-추적)
- [Deferred to plan 의 처분](#deferred-to-plan-의-처분)
- [도출 스윕 결과 (D10)](#도출-스윕-결과-d10)
- [파일 지도](#파일-지도)
- [Task 1: 기준선 + 공용 락 신설 (RED)](#task-1-기준선--공용-락-신설-red)
- [Task 2: spec-distill](#task-2-spec-distill)
- [Task 3: quality-gates](#task-3-quality-gates)
- [Task 4: plugin-audit](#task-4-plugin-audit)
- [Task 5: 검증 — 변이 행렬 · 전체 스위트 대조](#task-5-검증--변이-행렬--전체-스위트-대조)
- [Task 6: AC9 헤드리스 프로브 (관찰 · 기록)](#task-6-ac9-헤드리스-프로브-관찰--기록)
- [머지 전](#머지-전)

## Global Constraints

설계의 제약(원문 그대로):

- C1 — 치환은 SKILL.md 본문 로드 시 글자 그대로의 `${CLAUDE_PLUGIN_ROOT}` 토큰에만 온다(실측). 그 토큰을 바꾼 어떤 형태도 SKILL.md 에서 치환을 잃는다.
- C2 — Bash 도구는 호출마다 새 셸이다. 루트 대입은 그 값을 쓰는 펜스 안에 있어야 한다.
- C3 — 가드 앞에 `set -u` 를 두지 않는다. unbound 오류가 복구 메시지를 가린다.
- C4 — 가드 메시지 안에 `${CLAUDE_PLUGIN_ROOT}` 토큰을 쓰지 않는다. SKILL.md 에서는 그것까지 치환된다.
- C5 — 락의 대상 집합은 파일 구조에서 도출한다(손 열거 금지). 파싱은 python 으로 한다.

이 계획이 확정하는 문안(설계가 plan 에 넘긴 것):

- **가드 줄** — 한 줄: `X="${CLAUDE_PLUGIN_ROOT}"; [ -n "$X" ] || { echo "<메시지>" >&2; exit 1; }`.
  `<메시지>` = `[<플러그인>] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라`.
  `reviewing-spec` 다섯 자리만 뒤에 ` — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트).` 를 붙인다 — 그 skill 은 리뷰 없이 끝나는 모든 출구의 `[spec-distill]` 줄이 이 복귀 지시로 끝난다는 계약을 이미 갖고 있고 `test_reviewing_spec_entry_fence.sh` 의 `ends_with_return` 이 그것을 잰다.
- **안내 문장** — `Read` 펜스 바로 아래 한 줄, 락이 **줄 전체 일치**로 잰다:
  ``그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.``
  (설계 §2 문안에 변수 이름을 괄호로 더했고, 문장이 펜스 밖 다음 줄이라 「이 줄」을 「위 `Read` 줄」로 좁혔다. 괄호 속 `CLAUDE_PLUGIN_ROOT` 는 `${}` 가 없어 치환되지 않는다.)
- **버전** — patch: spec-distill `3.1.0 → 3.1.1` · quality-gates `7.6.0 → 7.6.1` · plugin-audit `0.9.2 → 0.9.3`. 각 플러그인 task 의 커밋에서 올린다(cache key). 머지 직전에 origin/main 과 다시 대조한다(「머지 전」).

실행 규칙:

- 작업 위치는 워크트리 `.claude/worktrees/plugin-root-cwd-fallback`(브랜치 `fix/plugin-root-cwd-fallback`)이다. 모든 경로는 그 워크트리 루트 기준이고, **셸 테스트는 워크트리 루트에서** 돈다.
- 계획 전용 스크립트 · 산출물은 `$BASE_DIR` 에 두고 커밋하지 않는다. Bash 도구는 호출마다 새 셸이므로 **매 Bash 호출 첫 줄**에 `BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"` 를 둔다.
- spec-distill python 테스트는 `cd plugins/spec-distill/tests && python3 -m unittest <module>` 로만 돈다(직접 실행은 공허 통과). plugin-audit python 은 `python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests`.
- 변이는 **커밋 뒤에** 걸고, 끝나면 `git diff HEAD --quiet` 로 복원을 확인한다.
- 커밋은 Conventional Commits, 메시지 끝 두 줄:
  `Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>` ·
  `Claude-Session: https://claude.ai/code/session_018tuo6oUNrRDUVWRdKrkr6r`.
- 문서 · CHANGELOG 는 Korean-primary.

## AC 추적

설계의 Acceptance Criteria 마다 그것을 만들고 재는 자리.

| AC | 내용(요지) | 만드는 곳 | 재는 곳 |
|---|---|---|---|
| AC1 | 본문에 `CLAUDE_PLUGIN_ROOT:-` · cwd 상대 루트 0 | Task 2 · 3 · 4 의 편집 | 락 축 1 · 1b (Task 4 Step 4 에서 22/22) · Task 5 Step 5 의 코퍼스 밖 grep |
| AC2 | reference 루트 사용 펜스에 앞선 가드 | Task 2(finishing 둘) · Task 3(runtime-gate 스물) | 락 축 2 · 하한 22 |
| AC3 | reference 를 여는 `Read` 줄 절대 형태 + 안내 문장 | Task 2(conducting-interview) · Task 3(quality-pipeline) | 락 축 3 · 하한 2 |
| AC4 | 무치환 · 변수 없음 · cwd 미끼에서 대표 펜스가 비0 · 미끼 미실행 · 복구 지시 | Task 2 · 3 의 가드 | 락 「행동」 무치환 판정(qg SKILL.md 펜스 · runtime-gate 펜스) + `test_reviewing_spec_entry_fence.sh` 의 F1 · 무치환(spec-distill 진입 · `## 입력` 펜스) |
| AC5 | 치환 흉내에서 같은 펜스가 픽스처 스크립트를 실행 | 같음 | 락 「행동」 치환 흉내 판정 |
| AC6 | 은퇴 락 삭제 · 활성 참조 0 | Task 3 | Task 3 Step 4 의 `git grep` |
| AC7 | 새 락의 변이 전부 RED · 양성 대조 GREEN | Task 1 의 락 | Task 5 Step 1–2(`mutate.py` — M1–M11 이 AC7 의 열하나) |
| AC8 | 전체 스위트 새 실패 식별자 0 · 파일별 실패 줄 수 | Task 1 Step 4(기준선) | Task 5 Step 3–4 |
| AC9 | 헤드리스 프로브 (a) 절대 경로 도착 · (b) 미끼 미실행 | — | Task 6 |
| AC10 | 세 CHANGELOG · patch bump · 알려진 결과 둘 | Task 2 · 3 · 4 의 편집 스크립트 | `test_changelog_integrity.sh` (Task 2 Step 5 · Task 4 Step 4) |
| AC11 | Law 2 게이트가 실행 대상과 같은 루트 · `--agents-dir` 기본값 | Task 4 | `test_check_law2.py` 의 `TestDefaultAgentsDir` 두 케이스 (Task 4 Step 2 RED → Step 4 GREEN) |

## Deferred to plan 의 처분

설계 끝 `### Deferred to plan` 항목마다 이 계획이 정한 것. 근거는 계획 작성 중의 모의 실행이다 — 설계대로의 편집을 흉내 낸 사본과 base 사본에서 세 플러그인 + shared 스위트 전체(227 단위)를 돌려 대조했고, 새 락 초안을 두 사본에 돌리고 변이 16개를 걸었다.

| 항목 | 처분 |
|---|---|
| 펜스를 잘라 실행하는 기존 테스트 전수와 치환 흉내 방식 | 흉내 사본에서 새로 깨진 것은 `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` 의 5건뿐이다. 나머지(`test_codex_gate_observation.sh` 의 plugin-audit 블록 · reviewing-brief 계열 · seed 게이트 등)는 `CLAUDE_PLUGIN_ROOT=<루트>` 를 env 로 넣고 펜스를 돌린다 — bash 에서 bare 대입은 그 값을 받으므로 치환 흉내와 같은 값이 들어간다. 그대로 둔다. 무치환 기대 둘(F1 · 「무치환」)만 새 동작으로 바꾼다(Task 2). |
| `test_skill_reference_pointers.sh` 정합 | 새 `Read ${CLAUDE_PLUGIN_ROOT}/skills/<s>/references/<f>.md` 는 그 락의 ① 형태로 풀려 소유 쌍이 맞는다. `PROFILE=` 은 `${CLAUDE_PLUGIN_ROOT}/references/…` 형태를 유지한다(`$SD/references/…` 는 ④ 거부 — 3.0.0 선례). `state-file-format.md` 는 quality-pipeline 630행 포인터가 소유를 지탱해 850행 문단을 지워도 고아가 아니다. 모의 실행 GREEN. |
| 가드 메시지 확정 문안 | 위 Global Constraints. |
| 새 락의 하한 · `# guards:` | 코퍼스 ≥30(현재 31) · 축 2 펜스 ≥22(현재 22 — 들여쓴 `finishing.md` 펜스를 놓치면 걸린다) · 축 3 reference ≥2. `# guards: plugins/*/skills/*.md plugins/*/commands/*.md plugins/*/references/*.md` — guards 커버리지 락의 bash `case` 매칭에서 `*` 가 `/` 를 넘으므로 모든 깊이를 덮는다(`**/*.md` 는 직속 파일을 못 덮는다). 모의 실행에서 커버리지 락 GREEN. |
| 은퇴 락을 가리키는 활성 참조 | 0 — `git grep test_skill_plugin_root_fallback` 결과는 CHANGELOG(이력) · `docs/superpowers/plans/`(지난 plan) · 설계 문서뿐이다. `codex-blessed-red.txt` · 러너 목록에 없다. `# guards:` 선언도 없어 guards 커버리지 락에 영향이 없다. |
| baseline 실행 명령 | `$BASE_DIR/run-suite.sh`(Task 1). 기준선과 대조 실행을 **같은 부모 디렉토리의 detached 워크트리 둘**에서 돌린다 — 위치에 따라 결과가 갈리는 테스트가 있어 같은 자리에서 재야 비교가 성립한다. |
| 축 3 이 안내 문장을 인식하는 규칙 | 줄 전체 일치(앞뒤 공백만 무시). 「같은 절」= `Read` 줄 위의 가장 가까운 헤딩부터 다음 헤딩 전까지(펜스 안의 `#` 줄은 헤딩이 아니다). 문장 뒤에 부정을 붙이면 RED(변이 M14). |
| 전수 목록 도출 스윕 (D10) | 아래 절. |
| 심볼릭 링크 포함 | 락 코퍼스는 `git ls-files` 로 도출하고(mode 120000 포함) 읽기는 링크를 따라간다 — 링크로 배포된 `plugins/spec-distill/references/reviewing-document.md` 가 코퍼스 31개에 든다. |

## 도출 스윕 결과 (D10)

스윕은 세 방향으로 돌렸다. 대상은 세 플러그인의 skill · command · reference 본문이고 심볼릭 링크를 포함한다.

1. `CLAUDE_PLUGIN_ROOT:-` 와 `./plugins/` 리터럴.
2. 각 플러그인 `scripts/` 의 실제 파일 이름이 명령 자리(코드 스팬 첫 낱말 · bash 줄 · `Bash(...)`)에 루트 없이 오는 곳.
3. 「플러그인 루트 · 리포 root · devbrew 안 · cwd」 산문 진술.

| 부류 | 자리(base 줄) | 처분 |
|---|---|---|
| `:-` · `./plugins/` 대입 · 산문 | reviewing-brief 38 · 83 · 105 · 148 · 161 · 203 · 221 · 223 · 314 · 323 · 355 · 364 · 495 / framing-requests 218 · 408 · 633 / reviewing-spec 27 · 112 · 149 · 170 · 299 (`PROFILE="${CLAUDE_PLUGIN_ROOT:-$SD}…"` 150 · 173 · 303) / quality-pipeline 119 · 122 · 135 · 274 · 293 · 509 · 915 / runtime-gate 20곳 / critiquing-artifacts 40 / auditing-plugins 112 | Task 2–4 |
| 자기 하니스 cwd 인자 | auditing-plugins 43–45(`check-law2.py` 호출의 워크플로 · agents 인자 넷) | Task 4 |
| reference 의 루트 사용 펜스 | runtime-gate 20 · finishing 87–89(목록 안 들여쓴 펜스) · 174–178 | Task 2 · 3 |
| reference 를 여는 `Read` 줄 | quality-pipeline 845 · conducting-interview 315 | Task 2 · 3 |
| 산문 루트 진술 | quality-pipeline Step P0b(116–119) · critiquing-artifacts 38–40 · auditing-plugins 17–21 | Task 3 · 4. 이 진술 아래 이름만 적힌 스크립트 호출은 진술을 치환 루트로 바꾸는 것으로 함께 닫힌다. quality-pipeline 의 「plugin root per Step P0b」 7곳과 runtime-gate 655, critiquing-artifacts 펜스 속 이름 호출 11곳, auditing-plugins 이름 호출 약 20곳이 그렇다 |
| spec-distill 이름 언급 | `reviewing-document.md`(링크 배포 — 14행 「`<플러그인 루트>/scripts/…`」) · compression · conducting-interview · finishing · framing-requests 산문 | 변경 없음. 루트 진술이 cwd 가 아니다 — `<플러그인 루트>` 자리표시이고, 실행은 진입 skill 펜스의 `$SD` · `$PR` 가 한다 |
| command 이름 언급 | qg.md 108 · 119 · 161 · cancel-qg.md 39 · 43 | 변경 없음 — 설명문이다. 실행은 `!` 블록의 bare 토큰이 한다 |
| bare 만 쓰는 SKILL.md | publishing-pr-understanding · briefing-current-state · conducting-interview 70 · framing-requests 산문 넷 | 변경 없음(D6) |
| 스크립트 안의 cwd 리터럴 | `check-law2.py:201` · `check-integrity.sh:135` · `run-own-tests.sh:18` | 첫째는 Task 4(D1.3). 뒤의 둘은 범위 밖이다(D2.7 — CHANGELOG 에 공시) |

## 파일 지도

| 파일 | 책임 | Task |
|---|---|---|
| `shared/tests/test_plugin_root_no_cwd_fallback.sh` (신규) | 규칙 하나를 전 플러그인에 집행 — 축 1 · 1b · 2 · 3 · C3/C4 · 하한 · 대표 펜스 행동 | 1 |
| `plugins/spec-distill/skills/{reviewing-brief,framing-requests,reviewing-spec,conducting-interview}/SKILL.md` · `skills/conducting-interview/references/finishing.md` | bare + 가드 · `Read` 절대 형태 + 안내 문장 | 2 |
| `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` · `tests/test_finishing_block_scope.py` | 무치환 기대 교체 · 머리말 정정 | 2 |
| `plugins/quality-gates/skills/quality-pipeline/SKILL.md` · `references/runtime-gate.md` · `skills/critiquing-artifacts/SKILL.md` | bare + 가드 · `Read` 절대 형태 + 안내 문장 · 루트 진술 | 3 |
| `plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh` | 삭제 | 3 |
| `plugins/plugin-audit/skills/auditing-plugins/SKILL.md` · `scripts/check-law2.py` · `tests/test_check_law2.py` | 가드 · 루트 진술 · 자기 하니스 인자 · `--agents-dir` 기본값 | 4 |
| 세 플러그인 `CHANGELOG.md` · `.claude-plugin/plugin.json` | 항목 · patch bump | 2 · 3 · 4 |
| `$BASE_DIR/*` (커밋 안 함) | 스위트 러너 · 편집 스크립트 · 변이 행렬 · 프로브 | 1–6 |

---

### Task 1: 기준선 + 공용 락 신설 (RED)

**Files:**
- Create: `shared/tests/test_plugin_root_no_cwd_fallback.sh`
- Create (커밋 안 함): `$BASE_DIR/run-suite.sh` · `$BASE_DIR/redcheck.sh` · `$BASE_DIR/wt-base/` (detached 워크트리)

**Interfaces:**
- Consumes: 없음.
- Produces:
  - 락 파일 — `--emit-scanned` 는 코퍼스 경로를 한 줄씩 낸다. 판정 줄 라벨은 `축 1:` · `축 1b:` · `축 2:` · `축 3:` · `C3:` · `C4:` · `행동(skill|ref)` 이다. Task 2–4 가 이 라벨로 자기 플러그인 줄을 거른다.
  - 락 안의 안내 문장 상수 `SENT` 와 가드 정규식 `GUARD` — Task 2–4 의 편집이 맞춰야 할 모양.
  - `$BASE_DIR/base/summary.tsv`(`<id>\t<rc>\t<실패 줄 수>`)와 `$BASE_DIR/base/fail-ids.tsv`(`<id>\t<정규화된 실패 줄>`) — Task 2–5 가 대조에 쓴다.
  - `$BASE_DIR/redcheck.sh <테스트 파일>...` — 기준선 대비 `NEW-RED` · `MORE-RED` · `SAME-RED` 를 낸다.

- [ ] **Step 1: base 이동을 잰다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
git fetch -q origin && git rev-parse --short origin/main && git merge-base --is-ancestor origin/main HEAD && echo "origin/main ⊆ HEAD" ; git rev-list --count add4c9cd..origin/main
```

Expected: `add4c9cd` · `origin/main ⊆ HEAD` · `0`. 개수가 0 이 아니면 **멈추고 보고한다** — 줄 번호 · 버전 번호 · 기준선이 모두 다시 재야 하는 값이다.

- [ ] **Step 2: Write `$BASE_DIR/run-suite.sh`**

````bash
#!/usr/bin/env bash
# usage: run-suite.sh <repo-root> <out-dir>
# 세 플러그인(spec-distill · quality-gates · plugin-audit) + shared 의 테스트 전부를 리포 루트에서 돈다.
# 산출: summary.tsv (<id>\t<rc>\t<실패 줄 수>) · fail-ids.tsv (<id>\t<정규화된 실패 줄>, 파일별 sort -u)
set -u
ROOT="$(cd "$1" && pwd)"; OUT="$2"
mkdir -p "$OUT/logs"; : > "$OUT/summary.tsv"; : > "$OUT/fail-ids.tsv"
cd "$ROOT" || exit 2
export PYTHONDONTWRITEBYTECODE=1
PAT='^[[:space:]]*(✗|FAIL|not ok|ERROR)'
norm() {
  sed -e "s#$ROOT#<REPO>#g" \
      -e 's#/private/var/folders/[^ ]*#<TMP>#g' -e 's#/var/folders/[^ ]*#<TMP>#g' \
      -e 's#/private/tmp/[^ ]*#<TMP>#g' -e 's#/tmp/[^ ]*#<TMP>#g' \
      -e 's/[0-9][0-9]*/N/g' -e 's/[[:space:]]*$//'
}
run() {
  id="$1"; shift
  log="$OUT/logs/$(printf '%s' "$id" | tr '/ :' '___').log"
  "$@" </dev/null >"$log" 2>&1; rc=$?
  n="$(grep -cE "$PAT" "$log" || true)"
  printf '%s\t%s\t%s\n' "$id" "$rc" "$n" >> "$OUT/summary.tsv"
  grep -E "$PAT" "$log" | norm | LC_ALL=C sort -u | sed "s#^#$id	#" >> "$OUT/fail-ids.tsv"
}
find plugins/spec-distill plugins/quality-gates plugins/plugin-audit shared -path '*/tests/*' -name 'test_*.sh' -not -path '*/fixtures/*' \
  | LC_ALL=C sort > "$OUT/sh-list.txt"
while IFS= read -r t; do run "$t" bash "$t"; done < "$OUT/sh-list.txt"
for t in $(find plugins/spec-distill/tests -maxdepth 1 -name 'test_*.py' | LC_ALL=C sort); do
  m="$(basename "$t" .py)"; run "$t" bash -c "cd plugins/spec-distill/tests && python3 -m unittest -v $m"
done
for t in $(find plugins/quality-gates/tests -maxdepth 1 -name 'test_*.py' | LC_ALL=C sort); do run "$t" python3 "$t"; done
run plugin-audit::unittest python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -v
run plugin-audit::node bash -c 'node --test --test-reporter=tap plugins/plugin-audit/tests/*.test.mjs'
git checkout HEAD -- plugins/quality-gates/tests/spike/fixtures 2>/dev/null || true
git status --porcelain > "$OUT/status-after.txt"
echo "DONE $(wc -l < "$OUT/summary.tsv") units" > "$OUT/DONE"
````

- [ ] **Step 3: Write `$BASE_DIR/redcheck.sh`**

````bash
#!/usr/bin/env bash
# usage: redcheck.sh <test-file>...   (워크트리 루트에서)
# 각 셸 테스트를 돌려 RED 인 것만 기준선($BASE_DIR/base/summary.tsv)과 대조한다.
#   NEW-RED  — 기준선에서 GREEN 이었거나 없던 파일
#   MORE-RED — 기준선에서도 RED 인데 실패 줄이 늘었다(같은 파일 안의 새 실패 — rc 로는 안 보인다)
#   SAME-RED — 기준선에서도 RED 이고 실패 줄이 늘지 않았다
set -u
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
S="$BASE_DIR/base/summary.tsv"
[ -s "$S" ] || { echo "기준선 없음: $S" >&2; exit 2; }
PAT='^[[:space:]]*(✗|FAIL|not ok|ERROR)'
for t in "$@"; do
  out="$(bash "$t" </dev/null 2>&1)"; rc=$?
  [ "$rc" -eq 0 ] && continue
  n="$(printf '%s\n' "$out" | grep -cE "$PAT" || true)"
  brc="$(awk -F'\t' -v t="$t" '$1==t {print $2}' "$S")"
  bn="$(awk -F'\t' -v t="$t" '$1==t {print $3}' "$S")"
  if [ -z "$brc" ] || [ "$brc" = "0" ]; then echo "NEW-RED  $t ($n)"
  elif [ "$n" -gt "$bn" ]; then echo "MORE-RED $t (base $bn → $n)"
  else echo "SAME-RED $t ($n)"; fi
done
echo "redcheck done"
````

- [ ] **Step 4: 기준선을 뜬다 — 지금 HEAD 의 detached 워크트리에서, 백그라운드로**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
mkdir -p "$BASE_DIR" && git worktree add -q --detach "$BASE_DIR/wt-base" HEAD && git -C "$BASE_DIR/wt-base" log --oneline -1
bash "$BASE_DIR/run-suite.sh" "$BASE_DIR/wt-base" "$BASE_DIR/base"; cat "$BASE_DIR/base/DONE"
```

두 번째 줄은 `run_in_background` 로 돈다(20분 안팎). 끝나기를 기다리지 않고 Step 5 로 간다. 이 워크트리는 Task 5 까지 남긴다.

- [ ] **Step 5: Write `shared/tests/test_plugin_root_no_cwd_fallback.sh`**

````bash
#!/usr/bin/env bash
# guards: plugins/*/skills/*.md plugins/*/commands/*.md plugins/*/references/*.md
#
# skill · command · reference 마크다운이 모델에게 건네는 플러그인 루트는 cwd 로 풀리지 않는다.
#
# 치환은 SKILL.md 본문을 로드할 때 글자 그대로의 `${CLAUDE_PLUGIN_ROOT}` 토큰에만 온다. Bash 도구
# 환경에는 그 변수가 없고, `Read` 로 연 reference 파일은 글자 그대로 온다(2.1.270 실측 — 설계
# docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md 「실측」). 그래서 잰다:
#
#  축 1  — 본문 어디에도 `CLAUDE_PLUGIN_ROOT:-` 가 없다. 그 형태는 치환되지 않아 늘 끝자락으로 떨어진다.
#  축 1b — 본문 어디에도 cwd 상대 플러그인 루트가 없다: `./plugins/` 리터럴(대입 끝자락 · 산문 모두),
#          그리고 자기 플러그인 스크립트를 실행하는 코드 스팬 · bash 줄이 넘기는 cwd 상대
#          `plugins/<자기 플러그인>/…` 인자. 처분 앵커 · 문서 포인터처럼 명령이 아닌 자리와 감사 대상
#          `plugins/<target>` 은 명령의 첫 낱말이 자기 스크립트가 아니거나 자기 플러그인 이름이 아니라서
#          걸리지 않는다.
#  축 2  — reference 파일의 bash 펜스(들여쓴 펜스 포함) 중 루트를 쓰는 것은, 같은 펜스에서 그 사용보다
#          앞에 `X="${CLAUDE_PLUGIN_ROOT}"; [ -n "$X" ] || { echo "…" >&2; exit N; }` 한 줄이 있다.
#  축 3  — 루트 토큰을 담은 reference 마다 그것을 `Read` 하는 SKILL.md 줄이 있고, 그 줄은 전부
#          `${CLAUDE_PLUGIN_ROOT}/…` 절대 형태이며, 같은 절에 치환 안내 문장이 **줄 전체 그대로** 있다.
#          부분 문자열로 재면 문장 뒤에 부정을 붙여도 통과한다.
#  C3/C4 — 가드 줄의 메시지에 `${CLAUDE_PLUGIN_ROOT}` 가 없고(SKILL.md 에서는 그것까지 치환된다), 가드를
#          담은 펜스에서 가드 앞에 `set -u` 가 없다(unbound 오류가 복구 메시지를 가린다).
#  행동  — 대표 펜스 둘(SKILL.md 하나 · reference 하나)을 잘라, 무치환 · 변수 없음 · cwd 에
#          `./plugins/quality-gates/scripts/` 미끼가 있는 조건에서 미끼가 돌지 않고 비0 으로 끝나며
#          복구 지시가 나오는지, 토큰을 픽스처 루트로 바꾼 조건에서 픽스처 스크립트가 도는지 실행한다.
#
# 재지 못하는 것: 이름만 적힌 스크립트 호출과 「리포 root에서」 같은 산문 루트 진술(실행 지시인지
# 설명인지 가려야 한다), 치환이 없는 하니스에서 모델이 `Read` 경로를 어떻게 푸는지.
#
# 파싱은 python 으로 한다 — 셸 본문 추출기는 조용히 깨진다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT" || exit 1

# 대상은 열거가 아니라 도출이다. pathspec 의 `*` 는 `/` 를 넘으므로 세 글롭이 모든 깊이를 덮고,
# 심볼릭 링크로 배포된 파일(mode 120000)도 경로로 나온다 — 읽기는 링크를 따라간다.
# 추적 전인 새 파일도 대상이다(`--others --exclude-standard`).
CORPUS="$(git ls-files --cached --others --exclude-standard -- \
  'plugins/*/skills/*.md' 'plugins/*/commands/*.md' 'plugins/*/references/*.md' | LC_ALL=C sort -u)"
if [ "${1:-}" = "--emit-scanned" ]; then
  printf '%s\n' "$CORPUS"
  exit 0
fi

. "$ROOT/shared/tests/assert.sh"

TMP="$(mktemp -d "${TMPDIR:-/tmp}/plugin-root-lock.XXXXXX")" || { echo "mktemp 실패" >&2; exit 1; }
trap 'rm -rf "$TMP"' EXIT
printf '%s\n' "$CORPUS" > "$TMP/corpus.txt"

python3 - "$TMP" "$TMP/corpus.txt" > "$TMP/report.tsv" <<'PY'
import os
import re
import sys

out_dir, corpus_file = sys.argv[1], sys.argv[2]
files = [l for l in open(corpus_file, encoding="utf-8").read().split("\n") if l]
TOKEN = "${CLAUDE_PLUGIN_ROOT}"
SENT = ("그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 "
        "`${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 "
        "cwd 에서 찾지 말고 멈춰 보고한다.")
FM = re.compile(r"\A---\n.*?\n---\n", re.S)
FOPEN = re.compile(r"^(\s*)```(\S*)\s*$")
GUARD = re.compile(r'^\s*([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"; \[ -n "\$\1" \] \|\| '
                   r'\{ echo "([^"]*)" >&2; exit [1-9][0-9]*; \}(\s+#.*)?\s*$')
HEADING = re.compile(r"^#{1,6} ")
READ = re.compile(r"^\s*Read\s+(\S+\.md)\s*$")
SET_U = re.compile(r"^\s*set\s+(-[A-Za-z]*u|-o\s+nounset)")
INTERP = {"python3", "python", "bash", "sh", "node", "exec", "env"}
REP = {"skill": ("plugins/quality-gates/skills/quality-pipeline/SKILL.md", "/scripts/check-review-scope.sh"),
       "ref": ("plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md", "/scripts/resolve-baseline.sh")}


def emit(tag, path, line, text):
    print(f"{tag}\t{path}:{line}\t{' '.join(text.split())[:170]}")


def load(path):
    txt = open(path, encoding="utf-8").read()
    m = FM.match(txt)
    return txt.split("\n"), (txt[:m.end()].count("\n") if m else 0)


def fences(lines, start):
    """(여는 idx, 닫는 idx, 언어, 들여쓰기). 닫는 줄은 같은 들여쓰기의 ``` 이다 — 목록 안 펜스 포함."""
    out, i = [], start
    while i < len(lines):
        m = FOPEN.match(lines[i])
        if m:
            ind, lang = m.group(1), m.group(2)
            close = re.compile("^" + re.escape(ind) + r"```\s*$")
            j = i + 1
            while j < len(lines) and not close.match(lines[j]):
                j += 1
            out.append((i, j, lang, ind))
            i = j + 1
            continue
        i += 1
    return out


scripts_cache = {}


def own_scripts(p):
    if p not in scripts_cache:
        d = os.path.join("plugins", p, "scripts")
        names = os.listdir(d) if os.path.isdir(d) else []
        scripts_cache[p] = {n for n in names if re.search(r"\.(py|sh|js)$", n)}
    return scripts_cache[p]


def command_violations(unit, p, is_bash):
    """자기 스크립트를 실행하는 명령 단위라면 그 안의 cwd 상대 `plugins/<p>/…` 낱말들.

    산문 코드 스팬은 인자가 있을 때만 명령으로 본다 — 경로 하나만 담긴 스팬은 문서 포인터다."""
    toks = [t.strip("\"'`(") for t in unit.split()]
    i = 0
    while i < len(toks) and (re.match(r"^[A-Za-z_]\w*=", toks[i]) or toks[i] in INTERP):
        m = re.match(r'^[A-Za-z_]\w*="?\$\((.*)$', toks[i])
        if m and m.group(1):
            toks[i] = m.group(1).strip("\"'")
            break
        i += 1
    if i >= len(toks) or os.path.basename(toks[i]) not in own_scripts(p):
        return []
    if not is_bash and len(toks) - i == 1:
        return []
    bad = []
    for t in toks[i:]:
        if t.startswith("--") and "=" in t:
            t = t.split("=", 1)[1]
        if t.startswith(f"plugins/{p}/") or t == f"plugins/{p}":
            bad.append(t)
    return bad


n_a2 = 0
ref_with_var = []
skills = [f for f in files if f.endswith("/SKILL.md")]
for path in files:
    lines, start = load(path)
    p = path.split("/")[1]
    fz = fences(lines, start)
    infence = set()
    bash_units = []
    for (o, c, lang, ind) in fz:
        infence.update(range(o, c + 1))
        if lang != "bash":
            continue
        buf, first = "", None
        for k in range(o + 1, c):
            t = re.sub(r"(^|\s)#.*$", "", lines[k])
            first = k if first is None else first
            if t.rstrip().endswith("\\"):
                buf += t.rstrip()[:-1] + " "
                continue
            bash_units.append((first, buf + t))
            buf, first = "", None
    # 축 1 · 축 1b(리터럴)
    for k in range(start, len(lines)):
        if "CLAUDE_PLUGIN_ROOT:-" in lines[k]:
            emit("A1", path, k + 1, lines[k])
        if "./plugins/" in lines[k]:
            emit("A1B", path, k + 1, lines[k])
    # 축 1b(자기 하니스 인자) — 산문의 코드 스팬(여러 줄 허용, 빈 줄 불허) + bash 논리 줄
    prose = "\n".join("" if (k < start or k in infence) else lines[k] for k in range(len(lines)))
    spans = [(prose[:m.start()].count("\n"), m.group(1)) for m in re.finditer(r"`([^`]+)`", prose)
             if "\n\n" not in m.group(1)]
    for (k, unit, is_bash) in [u + (True,) for u in bash_units] + [s + (False,) for s in spans]:
        for t in command_violations(unit, p, is_bash):
            emit("A1B", path, k + 1, f"{t} ← {unit}")
    # C3 · C4 — 가드 줄
    for (o, c, lang, ind) in fz:
        if lang != "bash":
            continue
        seen_set_u = None
        for k in range(o + 1, c):
            if SET_U.match(lines[k]):
                seen_set_u = k
            g = GUARD.match(lines[k])
            if g:
                if "CLAUDE_PLUGIN_ROOT" in g.group(2):
                    emit("C4", path, k + 1, lines[k])
                if seen_set_u is not None:
                    emit("C3", path, seen_set_u + 1, lines[seen_set_u])
    # 축 2 — reference 의 루트 사용 펜스
    if "/references/" in path:
        body = "\n".join(lines[start:])
        if "CLAUDE_PLUGIN_ROOT" in body:
            ref_with_var.append(path)
        rootvars = set(re.findall(r'([A-Za-z_]\w*)="\$\{CLAUDE_PLUGIN_ROOT\}"', body))
        for (o, c, lang, ind) in fz:
            if lang != "bash":
                continue
            blk = [(k, lines[k]) for k in range(o + 1, c)]
            def uses(t):
                return "CLAUDE_PLUGIN_ROOT" in t or any(re.search(r"\$\{?" + v + r"\b", t) for v in rootvars)
            if not any(uses(t) for (k, t) in blk):
                continue
            n_a2 += 1
            guarded, bad = set(), None
            for (k, t) in blk:
                g = GUARD.match(t)
                if g:
                    guarded.add(g.group(1))
                    continue
                if "CLAUDE_PLUGIN_ROOT" in t and not guarded:
                    bad = (k, "가드 앞에서 루트 토큰을 쓴다: " + t)
                    break
                late = [v for v in rootvars if re.search(r"\$\{?" + v + r"\b", t) and v not in guarded]
                if late:
                    bad = (k, f"가드 앞에서 ${late[0]} 를 쓴다: " + t)
                    break
            if not guarded:
                emit("A2", path, o + 1, "루트를 쓰는 펜스에 가드가 없다")
            elif bad:
                emit("A2", path, bad[0] + 1, bad[1])
    # 행동 테스트용 대표 펜스
    for role, (rp, needle) in REP.items():
        if path != rp:
            continue
        hits = [(o, c, ind) for (o, c, lang, ind) in fz if lang == "bash"
                and any(needle in lines[k] for k in range(o + 1, c))]
        if len(hits) != 1:
            print(f"REP_BAD\t{role}\t{path}\t{len(hits)}")
            continue
        o, c, ind = hits[0]
        with open(os.path.join(out_dir, f"{role}_fence.sh"), "w", encoding="utf-8") as fh:
            fh.write("\n".join(l[len(ind):] if l.startswith(ind) else l for l in lines[o + 1:c]) + "\n")
        print(f"REP\t{role}\t{path}:{o + 1}")
# 축 3
for r in ref_with_var:
    hits = []
    for s in skills:
        lines, start = load(s)
        heads = [k for k in range(start, len(lines)) if HEADING.match(lines[k])]
        fz = fences(lines, start)
        infence = set()
        for (o, c, lang, ind) in fz:
            infence.update(range(o, c + 1))
        heads = [k for k in heads if k not in infence]
        for k in range(start, len(lines)):
            m = READ.match(lines[k])
            if not m:
                continue
            ptr = m.group(1)
            if ptr.startswith(TOKEN + "/"):
                tgt, form = os.path.normpath(os.path.join("plugins", s.split("/")[1], ptr[len(TOKEN) + 1:])), "abs"
            elif ptr.startswith("$"):
                continue
            else:
                tgt, form = os.path.normpath(os.path.join(os.path.dirname(s), ptr)), "rel"
            if tgt != os.path.normpath(r):
                continue
            lo = max([h for h in heads if h < k], default=start)
            hi = min([h for h in heads if h > k], default=len(lines))
            hits.append((s, k, form, any(lines[j].strip() == SENT for j in range(lo, hi))))
    if not hits:
        emit("A3", r, 0, "이 reference 를 Read 하는 SKILL.md 줄이 없다")
    for (s, k, form, has_sent) in hits:
        if form != "abs":
            emit("A3", s, k + 1, "상대 형태 Read — 설치본에서 모델이 cwd 로 풀 수 있다")
        if not has_sent:
            emit("A3", s, k + 1, "같은 절에 치환 안내 문장(줄 전체)이 없다")
print(f"N_CORPUS\t{len(files)}")
print(f"N_A2\t{n_a2}")
print(f"N_A3\t{len(ref_with_var)}")
PY
py_rc=$?

count() { awk -F'\t' -v t="$1" '$1==t' "$TMP/report.tsv" | wc -l | tr -d ' '; }
val()   { awk -F'\t' -v t="$1" '$1==t {print $2}' "$TMP/report.tsv"; }
show()  { awk -F'\t' -v t="$1" '$1==t {print "      " $2 "  " $3}' "$TMP/report.tsv"; }

assert_eq "$py_rc" "0" "파서가 끝까지 돌았다 (rc $py_rc)"
n_corpus="$(val N_CORPUS)"; n_a2="$(val N_A2)"; n_a3="$(val N_A3)"
[ "${n_corpus:-0}" -ge 30 ] && ok "대상 마크다운 ${n_corpus}개 — vacuous 아님" \
  || no "대상 마크다운이 ${n_corpus:-0}개뿐 — 도출이 무너졌다(글롭 · 경로 변경?)"
for ax in A1 A1B A2 A3 C3 C4; do
  n="$(count "$ax")"
  case "$ax" in
    A1)  what="축 1: 본문의 CLAUDE_PLUGIN_ROOT:- 형태" ;;
    A1B) what="축 1b: 본문의 cwd 상대 플러그인 루트(./plugins/ · 자기 하니스 cwd 인자)" ;;
    A2)  what="축 2: reference 펜스가 가드보다 먼저 루트를 쓴다 / 가드가 없다" ;;
    A3)  what="축 3: reference 를 여는 Read 줄이 절대 형태가 아니거나 안내 문장이 없다" ;;
    C3)  what="C3: 가드 앞의 set -u" ;;
    C4)  what="C4: 가드 메시지 안의 루트 토큰" ;;
  esac
  assert_eq "$n" "0" "$what — ${n}곳"
  [ "$n" -eq 0 ] || show "$ax"
done
# 하한 — 코퍼스가 무너지면(태그 · 들여쓰기 인식 · 경로) 축 2 · 3 이 공허하게 통과한다.
[ "${n_a2:-0}" -ge 22 ] && ok "축 2 대상 reference 펜스 ${n_a2}곳 (하한 22)" \
  || no "축 2 대상 reference 펜스가 ${n_a2:-0}곳 — 하한 22 미달(들여쓴 펜스 인식이 무너졌나?)"
[ "${n_a3:-0}" -ge 2 ] && ok "축 3 대상 reference ${n_a3}개 (하한 2)" \
  || no "축 3 대상 reference 가 ${n_a3:-0}개 — 하한 2 미달"

# ── 행동 — 대표 펜스 둘 ──────────────────────────────────────────────────────
USER_REPO="$TMP/user"; FX="$TMP/fx/quality-gates"
mkdir -p "$USER_REPO/plugins/quality-gates/scripts" "$FX/scripts"
for n in check-review-scope.sh resolve-baseline.sh; do
  printf '#!/bin/sh\ntouch "%s/BAIT.%s"\n' "$TMP" "$n" > "$USER_REPO/plugins/quality-gates/scripts/$n"
  printf '#!/bin/sh\ntouch "%s/FIX.%s"\n' "$TMP" "$n" > "$FX/scripts/$n"
  chmod +x "$USER_REPO/plugins/quality-gates/scripts/$n" "$FX/scripts/$n"
done
for role in skill ref; do
  case "$role" in skill) n=check-review-scope.sh ;; ref) n=resolve-baseline.sh ;; esac
  fence="$TMP/${role}_fence.sh"
  if ! grep -q "^REP	$role	" "$TMP/report.tsv" || [ ! -s "$fence" ]; then
    no "행동($role): 대표 펜스($n)를 정확히 하나 찾지 못했다 — 아래 판정은 무의미하다"
    continue
  fi
  rm -f "$TMP/BAIT.$n" "$TMP/FIX.$n"
  ( cd "$USER_REPO" && env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$fence" ) >"$fence.out" 2>"$fence.err"; rc=$?
  [ "$rc" -ne 0 ] && ok "행동($role) 무치환: 비0 종료 (rc $rc)" || no "행동($role) 무치환: rc 0 으로 끝났다"
  [ ! -e "$TMP/BAIT.$n" ] && ok "행동($role) 무치환: cwd 의 미끼 $n 가 돌지 않았다" \
    || no "행동($role) 무치환: cwd 의 미끼 $n 가 돌았다 — 사용자 저장소의 스크립트를 실행한다"
  err="$(cat "$fence.err")"
  assert_contains "$err" "플러그인 루트 미해석" "행동($role) 무치환: stderr 에 원인이 나온다"
  assert_contains "$err" "추측하지 말고(cwd 포함) 멈춰 보고하라" "행동($role) 무치환: stderr 에 복구 지시가 나온다"
  python3 -c '
import sys
src, dst, root = sys.argv[1:4]
t = open(src, encoding="utf-8").read()
open(dst, "w", encoding="utf-8").write(t.replace("${CLAUDE_PLUGIN_ROOT}", root))
' "$fence" "$fence.subst" "$FX"
  rm -f "$TMP/BAIT.$n" "$TMP/FIX.$n"
  ( cd "$USER_REPO" && env -i PATH="/usr/bin:/bin" HOME="$TMP" bash "$fence.subst" ) >/dev/null 2>&1; rc=$?
  [ "$rc" -eq 0 ] && [ -e "$TMP/FIX.$n" ] && ok "행동($role) 치환 흉내: 픽스처 플러그인의 $n 가 돌았다 (양성 짝)" \
    || no "행동($role) 치환 흉내: 픽스처 플러그인의 $n 가 돌지 않았다 (rc $rc)"
  [ ! -e "$TMP/BAIT.$n" ] && ok "행동($role) 치환 흉내: 미끼는 돌지 않았다" || no "행동($role) 치환 흉내: 미끼가 돌았다"
done

finish
````

- [ ] **Step 6: 락을 돌려 RED 를 확인한다**

```bash
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -E '^  [✓✗]|^Total'
```

Expected — 모의 실행과 같은 모양:

```
  ✓ 파서가 끝까지 돌았다 (rc 0)
  ✓ 대상 마크다운 31개 — vacuous 아님
  ✗ 축 1: 본문의 CLAUDE_PLUGIN_ROOT:- 형태 — 51곳
  ✗ 축 1b: 본문의 cwd 상대 플러그인 루트(./plugins/ · 자기 하니스 cwd 인자) — 54곳
  ✗ 축 2: reference 펜스가 가드보다 먼저 루트를 쓴다 / 가드가 없다 — 22곳
  ✗ 축 3: reference 를 여는 Read 줄이 절대 형태가 아니거나 안내 문장이 없다 — 4곳
  ✓ C3: 가드 앞의 set -u — 0곳
  ✓ C4: 가드 메시지 안의 루트 토큰 — 0곳
  ✓ 축 2 대상 reference 펜스 22곳 (하한 22)
  ✓ 축 3 대상 reference 2개 (하한 2)
  (행동 12줄 전부 ✗ — 무치환에서 미끼가 돌고 rc 0, 치환 흉내에서 픽스처가 안 돈다)
Total: 22 | Pass: 6 | Fail: 16
```

개수가 다르면 멈추고 보고한다 — Task 2–4 의 편집 대상 수가 설계 조사와 달라진 것이다.

- [ ] **Step 7: guards 커버리지 락이 새 선언을 받아들이는지 본다**

```bash
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh 2>&1 | grep -E 'plugin_root_no_cwd|^Total'
```

Expected: 새 락 줄 넷이 모두 ✓ 이다(「선언이 좁지 않다」 한 줄과 글롭 셋이 각각 15 · 8 · 14건을 덮는다는 줄). `Fail: 0`.

- [ ] **Step 8: Commit**

```bash
git add shared/tests/test_plugin_root_no_cwd_fallback.sh
git commit -q -F - <<'EOF'
test(shared): 플러그인 루트 cwd fallback 공용 락 — 지금은 RED

skill · command · reference 본문이 모델에게 주는 플러그인 루트가 cwd 로 풀리지 않는지를
전 플러그인에 잰다(축 1 · 1b · 2 · 3 · C3/C4 · 대표 펜스 행동). Task 2–4 가 GREEN 으로 만든다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_018tuo6oUNrRDUVWRdKrkr6r
EOF
git log --oneline -1
```

- [ ] **Step 9: 기준선이 끝났는지 확인한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
cat "$BASE_DIR/base/DONE"; awk -F'\t' '$2!=0' "$BASE_DIR/base/summary.tsv"; cat "$BASE_DIR/base/status-after.txt"
```

Expected: `DONE 227 units` 전후. RED 단위는 위치에 따라 다를 수 있다. 모의 실행에서는 일곱이었다: qg `harness/test_skill_orchestration_behavior.sh`(2) · `test_artifact_codex_reviewer.sh` · `test_codex_backward_compat.sh` · `test_findings_parser.sh` · `test_runner_adapters.sh`, spec-distill `test_no_write_matcher_hooks_repo.sh` · `test_hook_output_schema.py`(NG9). `status-after.txt` 는 비어 있다. 결과가 무엇이든 그것이 이 작업의 기준선이다.

---

### Task 2: spec-distill

**Files:**
- Modify: `plugins/spec-distill/skills/reviewing-brief/SKILL.md`(13곳) · `skills/framing-requests/SKILL.md`(218 · 408 · 633) · `skills/reviewing-spec/SKILL.md`(27 · 112 · 149–150 · 170 · 173 · 299 · 303) · `skills/conducting-interview/SKILL.md`(314–318) · `skills/conducting-interview/references/finishing.md`(87–89 · 174–175)
- Modify (tests): `plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh` · `tests/test_finishing_block_scope.py`(머리말 29–30)
- Modify: `plugins/spec-distill/CHANGELOG.md` · `.claude-plugin/plugin.json`
- Create (커밋 안 함): `$BASE_DIR/task2_tests.py` · `$BASE_DIR/task2_apply.py`

**Interfaces:**
- Consumes: Task 1 의 락(판정 줄에 `plugins/spec-distill/` 경로가 붙는다) · `$BASE_DIR/redcheck.sh`.
- Produces: 없음(다른 task 는 이 편집에 기대지 않는다).

- [ ] **Step 1: Write `$BASE_DIR/task2_tests.py` — 무치환 기대를 새 동작으로 바꾸는 편집**

````python
#!/usr/bin/env python3
"""task2_tests.py <repo-root> — reviewing-spec 진입 테스트의 무치환 기대 · finishing 락 머리말."""
import pathlib
import sys

R = pathlib.Path(sys.argv[1])


def edit(rel, pairs):
    f = R / rel
    t = f.read_text(encoding="utf-8")
    for old, new in pairs:
        assert t.count(old) == 1, (rel, old[:70], t.count(old))
        t = t.replace(old, new)
    f.write_text(t, encoding="utf-8")


HDR_OLD = "#     무치환이면 `## 입력` 이 상태 리졸버 부재를 원인으로 댄다.\n"
HDR_NEW = "#     무치환이면 진입 · `## 입력` 이 가드에서 멈추고 cwd 의 미끼(`./plugins/spec-distill/scripts/`)를 돌리지 않는다.\n"

F1_COMMENT_OLD = r"""# `SD="${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}"` 의 안쪽 bare 형태
# `${CLAUDE_PLUGIN_ROOT}` 는 skill 로드 시 하니스가 치환하고(2026-09-11 실측 —
# 이 대화에서 로드된 skill 본문의 bare 참조가 절대경로로 치환된 채 보였다),
# `:-` 를 낀 바깥 형태는 치환되지 않는다. 치환된 경우 SD 는 절대 플러그인
# 루트가 되고, 치환이 없으면 `[ -n "$SD" ] || SD="./plugins/spec-distill"` 가
# 오늘과 같은 fallback 을 낸다.
"""
F1_COMMENT_NEW = r"""# `SD="${CLAUDE_PLUGIN_ROOT}"` 는 skill 로드 시 하니스가 절대 경로로 치환한다(2.1.270 실측 — 설계
# docs/superpowers/specs/2026-09-14-plugin-root-cwd-fallback-design.md 「실측」). 치환이 없으면 빈 값이고,
# 같은 줄의 가드가 cwd 로 가지 않고 멈춘다 — cwd 에 `./plugins/spec-distill/` 미끼가 있어도 돌리지 않는다.
"""

F1_CASE_OLD = r"""out="$(run_fence_no_root "$ENTRY_FENCE" "$SCRATCH")"
expect_verdict "F1: 무치환·변수 없음·플러그인 루트 밖 cwd" "$F" "$out"
assert_contains "$out" "모듈 부재" "F1: 무치환·변수 없음 — 오늘과 같은 fail-closed fallback(모듈 부재)"
"""
F1_CASE_NEW = r"""# 무치환 — 변수도 치환도 없고, cwd 에 미끼 `./plugins/spec-distill/scripts/review_entry.py` 가 있다. 가드가
# 미끼에 닿기 전에 멈춘다: 판결 줄 없이 비0 이고, [spec-distill] 한 줄이 원인과 복귀 지시를 싣는다.
mkdir -p "$SCRATCH/plugins/spec-distill/scripts"
printf 'open("%s", "w").close()\n' "$SCRATCH/BAIT.review_entry" > "$SCRATCH/plugins/spec-distill/scripts/review_entry.py"
F1_ERR="$SCRATCH/f1_nosubst.err"
out="$( cd "$SCRATCH" && env -i PATH="/usr/bin:/bin:$PY_DIR" HOME="$SCRATCH" PYTHONDONTWRITEBYTECODE=1 \
    bash "$ENTRY_FENCE" 2>"$F1_ERR" )"; f1_rc=$?
[ "$f1_rc" -ne 0 ] && ok "F1: 무치환 — 비0 으로 멈춘다 (rc $f1_rc)" || no "F1: 무치환 — rc 0 으로 끝났다"
assert_not_grep "$out" '^review-entry: ' "F1: 무치환 — 판결 줄을 내지 않는다(PROCEED 로 읽힐 줄이 없다)"
[ ! -e "$SCRATCH/BAIT.review_entry" ] && ok "F1: 무치환 — cwd 의 미끼 review_entry.py 가 돌지 않았다" \
  || no "F1: 무치환 — cwd 의 미끼 review_entry.py 가 돌았다(사용자 저장소의 스크립트를 실행한다)"
assert_contains "$(cat "$F1_ERR")" "[spec-distill] 플러그인 루트 미해석" "F1: 무치환 — 원인을 댄다"
ends_with_return "F1: 무치환 — 그 줄이 복귀 지시로 끝난다" "$(cat "$F1_ERR")"
rm -rf "$SCRATCH/plugins" "$SCRATCH/BAIT.review_entry"
"""

INST_OLD = "#    플러그인으로 풀려야 리뷰가 돈다. 무치환이면 `## 입력` 은 진짜 원인(상태 리졸버 부재)을 댄다.\n"
INST_NEW = "#    플러그인으로 풀려야 리뷰가 돈다. 무치환이면 `## 입력` 은 가드에서 멈추고 cwd 의 미끼를 돌리지 않는다.\n"

NOSUB_OLD = r"""# 무치환 — 같은 설치본에서 하니스가 아무것도 치환하지 않으면 `## 입력` 은 원인을 대고 끝낸다.
out="$(run_inst "$SDIR_FENCE" 'printf "STATE_DIR=[%s]\n" "$STATE_DIR"')"
assert_contains "$out" "[spec-distill] 상태 리졸버 부재: ./plugins/spec-distill/scripts/state_path.py (플러그인 루트 미해석)" \
  "무치환: 「## 입력」 — 상태 리졸버 부재를 원인으로 댄다"
ends_with_return "무치환: 그 줄이 복귀 지시로 끝난다" "$out"
assert_not_contains "$out" "특정할 수 없다" "무치환: session id 줄로 원인을 가리지 않는다"
assert_eq "$(printf '%s\n' "$out" | tail -n 1)" "STATE_DIR=[]" "무치환: STATE_DIR 을 비운다"
"""
NOSUB_NEW = r"""# 무치환 — 같은 설치본에서 하니스가 아무것도 치환하지 않고, cwd(사용자 저장소)에 미끼
# `./plugins/spec-distill/scripts/state_path.py` 가 있다. `## 입력` 은 가드에서 멈춘다 — 미끼를 돌리지 않고,
# 원인과 복귀 지시를 한 줄로 댄다. 뒤의 프로브 줄(STATE_DIR 출력)까지 가지 않는다.
mkdir -p "$UREPO/plugins/spec-distill/scripts"
printf 'open("%s", "w").close()\nprint("baitsid01")\n' "$SCRATCH/BAIT.state_path" > "$UREPO/plugins/spec-distill/scripts/state_path.py"
out="$(run_inst "$SDIR_FENCE" 'printf "STATE_DIR=[%s]\n" "$STATE_DIR"')"
assert_contains "$out" "[spec-distill] 플러그인 루트 미해석" "무치환: 「## 입력」 — 가드가 원인을 댄다"
ends_with_return "무치환: 그 줄이 복귀 지시로 끝난다" "$out"
assert_not_contains "$out" "특정할 수 없다" "무치환: session id 줄로 원인을 가리지 않는다"
assert_not_contains "$out" "STATE_DIR=[" "무치환: 가드에서 멈춰 뒤의 프로브 줄까지 가지 않는다"
[ ! -e "$SCRATCH/BAIT.state_path" ] && ok "무치환: cwd 의 미끼 state_path.py 가 돌지 않았다" \
  || no "무치환: cwd 의 미끼 state_path.py 가 돌았다(사용자 저장소의 스크립트를 실행한다)"
rm -rf "$UREPO/plugins" "$SCRATCH/BAIT.state_path"
"""

edit("plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh", [
    (HDR_OLD, HDR_NEW),
    (F1_COMMENT_OLD, F1_COMMENT_NEW),
    (F1_CASE_OLD, F1_CASE_NEW),
    (INST_OLD, INST_NEW),
    (NOSUB_OLD, NOSUB_NEW),
])
edit("plugins/spec-distill/tests/test_finishing_block_scope.py", [
    ("# 하니스가 넣어 주는 값. `CLAUDE_PLUGIN_ROOT` 는 플러그인 실행 시 Claude Code 가 export 한다\n"
     "# (그래서 문서의 블록들도 `${CLAUDE_PLUGIN_ROOT:-...}` 로 fallback 을 단다).\n",
     "# 펜스 밖에서 오는 값. `CLAUDE_PLUGIN_ROOT` 는 Bash 도구 환경에 없다 — 모델이 SKILL.md 가 보여 준 절대 경로로\n"
     "# 바꿔 넣고, 빠뜨리면 펜스의 가드가 빈 값에서 멈춘다(`shared/tests/test_plugin_root_no_cwd_fallback.sh` 축 2).\n"),
])
print("task2 tests edited")
````

- [ ] **Step 2: 테스트 편집을 적용하고 RED 를 확인한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
python3 "$BASE_DIR/task2_tests.py" "$(pwd)" && bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh 2>&1 | grep -E '✗|^Total'
```

Expected: `task2 tests edited` 에 이어 ✗ 줄이 나온다.
- F1 쪽: `rc 0 으로 끝났다` · `판결 줄을 내지 않는다` · `미끼 review_entry.py 가 돌았다` · `원인을 댄다` · `그 줄이 복귀 지시로 끝난다 … 0개`.
- 무치환 쪽: `가드가 원인을 댄다` · `그 줄이 복귀 지시로 끝난다` · `프로브 줄까지 가지 않는다` · `미끼 state_path.py 가 돌았다`.
- 끝 줄은 `Total: 168 | Pass: 159 | Fail: 9` 다(모의 실행). 옛 SKILL.md 가 cwd 미끼를 실제로 돌리는 것이 이 RED 의 뜻이다. 다른 ✗ 는 없다.

- [ ] **Step 3: Write `$BASE_DIR/task2_apply.py` — SKILL · reference · CHANGELOG · plugin.json 편집**

````python
#!/usr/bin/env python3
"""task2_apply.py <repo-root> — spec-distill 의 cwd fallback 제거(개수 검사 포함)."""
import pathlib
import sys

R = pathlib.Path(sys.argv[1])
MSG = ("플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 "
       "바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라")
RS_TAIL = (" — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라"
           "(brainstorming 의 사용자 리뷰 게이트).")
SENT = ("그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 "
        "`${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 "
        "cwd 에서 찾지 말고 멈춰 보고한다.")


def guard(var, p, tail=""):
    return f'{var}="${{CLAUDE_PLUGIN_ROOT}}"; [ -n "${var}" ] || {{ echo "[{p}] {MSG}{tail}" >&2; exit 1; }}'


def edit(rel, pairs):
    f = R / rel
    t = f.read_text(encoding="utf-8")
    for old, new, cnt in pairs:
        c = t.count(old)
        assert c == cnt, (rel, old[:70], c, cnt)
        t = t.replace(old, new)
    f.write_text(t, encoding="utf-8")


P = "spec-distill"
edit("plugins/spec-distill/skills/reviewing-brief/SKILL.md", [
    ('PR="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"', guard("PR", P), 7),
    ('SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"', guard("SD", P), 1),
    ('```bash\nPROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/brief.md"\n```',
     '```bash\n' + guard("PR", P) + '\nPROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/brief.md"\n```', 1),
    ('PROFILE="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/docreview-profiles/brief.md"',
     'PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/brief.md"', 3),
    ('Read ${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/references/reviewing-document.md',
     'Read ${CLAUDE_PLUGIN_ROOT}/references/reviewing-document.md', 1),
])
edit("plugins/spec-distill/skills/framing-requests/SKILL.md", [
    ('SD="${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}"', guard("SD", P), 2),
    ('python3 "${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}/scripts/check_seed.py" \\',
     guard("SD", P) + '\npython3 "$SD/scripts/check_seed.py" \\', 1),
])
edit("plugins/spec-distill/skills/reviewing-spec/SKILL.md", [
    ('SD="${CLAUDE_PLUGIN_ROOT:-${CLAUDE_PLUGIN_ROOT}}"; [ -n "$SD" ] || SD="./plugins/spec-distill"',
     guard("SD", P, RS_TAIL), 5),
    ('PROFILE="${CLAUDE_PLUGIN_ROOT:-$SD}/references/docreview-profiles/design-doc.md"',
     'PROFILE="${CLAUDE_PLUGIN_ROOT}/references/docreview-profiles/design-doc.md"', 3),
])
edit("plugins/spec-distill/skills/conducting-interview/SKILL.md", [
    ("```\nRead references/finishing.md\n```\n\n경로는 이 SKILL.md 파일 기준 상대경로다 — 레포·설치본 두 레이아웃 모두 이 "
     "SKILL.md와 같은 위치에 `references/`가 있어, 위 seed 포인터·아래 migration 포인터를 포함한 이 세 참조 파일 전부 "
     "그대로 resolve 된다(세 포인터 공통 규칙 — 각자 따로 반복하지 않는다).\n",
     "```\nRead ${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/finishing.md\n```\n\n" + SENT + "\n\n"
     "위 seed 포인터와 아래 migration 포인터는 이 SKILL.md 파일 기준 상대경로다 — 레포·설치본 두 레이아웃 모두 이 "
     "SKILL.md와 같은 위치에 `references/`가 있어 그대로 resolve 된다(두 포인터 공통 규칙 — 각자 따로 반복하지 않는다).\n", 1),
])
edit("plugins/spec-distill/skills/conducting-interview/references/finishing.md", [
    ('   ```bash\n   python3 "${CLAUDE_PLUGIN_ROOT}/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"\n   ```',
     '   ```bash\n   ' + guard("SD", P) + '\n   python3 "$SD/scripts/check_brief.py" gate "docs/superpowers/interview/<file>"\n   ```', 1),
    ('```bash\nROOT="$(python3 "${CLAUDE_PLUGIN_ROOT}/scripts/state_path.py" state-root)"\n',
     '```bash\n' + guard("SD", P) + '\nROOT="$(python3 "$SD/scripts/state_path.py" state-root)"\n', 1),
])

CHANGELOG = """## [3.1.1] — 2026-09-15

patch 인 이유 — 새 surface 가 없다. 바뀌는 것은 skill · reference 펜스가 플러그인 루트를 얻는 방식뿐이다.

### Security

- **skill 이 사용자 저장소의 스크립트를 실행하던 cwd fallback 을 없앴다.** `reviewing-brief`(13줄) · `framing-requests`(3줄) · `reviewing-spec`(펜스 다섯 · `PROFILE=` 셋)의 `${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}` 과 끝자락 `|| SD="./plugins/spec-distill"` 는 Bash 도구 환경에 그 변수가 없어 언제나 cwd 상대로 풀렸다 — devbrew 밖에서는 사용자 저장소의 `plugins/spec-distill/scripts/*` 를, devbrew 의 옛 체크아웃 · 포크 안에서는 다른 버전의 스크립트를 조용히 실행했다. 이제 펜스는 SKILL.md 를 로드할 때 절대 경로로 치환되는 bare `${CLAUDE_PLUGIN_ROOT}` 에서 루트를 받고, 빈 값이면 `[spec-distill] 플러그인 루트 미해석 — …` 를 stderr 로 내고 비0 으로 멈춘다. `reviewing-spec` 의 가드 메시지는 그 skill 의 다른 비-리뷰 출구와 같은 복귀 지시로 끝난다.
- **reference `skills/conducting-interview/references/finishing.md` 의 펜스 둘이 같은 가드를 지난다.** `Read` 로 연 reference 에는 치환이 오지 않아 bare 토큰이 Bash 에서 빈 값이 되어 `/scripts/…` 로 깨졌다. 여는 쪽 `conducting-interview/SKILL.md` 의 `Read` 줄은 로드 시 치환되는 `${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/finishing.md` 가 되고, 바로 아래 한 줄이 그 파일의 루트 변수를 무엇으로 바꿔 넣을지와, 경로가 절대 경로로 보이지 않으면 cwd 에서 찾지 말고 멈춘다는 것을 알린다.
- 집행은 새 공용 락 `shared/tests/test_plugin_root_no_cwd_fallback.sh` 가 한다.

**알려진 결과 둘**

- **devbrew 안 dogfooding 이 바뀐다.** 설치본 skill 이 이제 워킹트리가 아니라 설치본 스크립트를 돈다. 워킹트리 코드를 돌리려면 `claude --plugin-dir ./plugins/spec-distill` 로 로드한다.
- **skill 본문 치환이 없는 하니스에서는 멈춘다.** 경로를 추측하지 않고 가드에서 복구 지시와 함께 멈춘다. 어느 하니스가 그런지는 모른다 — 2.1.270 에서는 치환된다.

### Fixed

- **`tests/test_finishing_block_scope.py` 머리말.** 「`CLAUDE_PLUGIN_ROOT` 는 Claude Code 가 export 한다」는 틀렸다 — Bash 도구 환경에는 그 변수가 없다. 모델이 SKILL.md 가 보여 준 경로로 바꿔 넣고, 빠뜨리면 가드가 멈춘다고 고쳤다.
- **`tests/test_reviewing_spec_entry_fence.sh` 의 무치환 기대.** 진입 · `## 입력` 펜스가 판결 없이 비0 으로 멈추고, cwd 의 미끼 스크립트(`./plugins/spec-distill/scripts/`)를 돌리지 않으며, 원인과 복귀 지시를 한 줄로 낸다.

"""
edit("plugins/spec-distill/CHANGELOG.md", [("\n## [3.1.0] — 2026-09-14\n", "\n" + CHANGELOG + "## [3.1.0] — 2026-09-14\n", 1)])
edit("plugins/spec-distill/.claude-plugin/plugin.json", [('"version": "3.1.0"', '"version": "3.1.1"', 1)])
print("task2 applied")
````

- [ ] **Step 4: 편집을 적용한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
python3 "$BASE_DIR/task2_apply.py" "$(pwd)" && git diff --stat
```

Expected: `task2 applied`, 그리고 9개 파일이 바뀐다 — SKILL 넷 · finishing · 테스트 둘 · CHANGELOG · plugin.json. 스크립트가 `AssertionError` 로 멈추면 그 튜플(파일 · 옛 문자열 · 실제 개수 · 기대 개수)을 보고하고 멈춘다.

- [ ] **Step 5: GREEN 을 확인한다**

```bash
bash plugins/spec-distill/tests/test_reviewing_spec_entry_fence.sh 2>&1 | tail -1
(cd plugins/spec-distill/tests && python3 -m unittest test_finishing_block_scope 2>&1 | tail -1)
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -c 'plugins/spec-distill/'
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -1
bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1
```

Expected, 줄 순서대로: `Total: … | Fail: 0` · `OK` · `0`(락 판정에 spec-distill 경로가 하나도 없다) · `… | Fail: 0` · `… | Fail: 0`.

- [ ] **Step 6: 기준선 대비 새 RED 가 없는지 본다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
bash "$BASE_DIR/redcheck.sh" plugins/spec-distill/tests/test_*.sh shared/tests/test_*.sh
```

Expected: `NEW-RED` 는 `shared/tests/test_plugin_root_no_cwd_fallback.sh` 한 줄뿐이다. quality-gates · plugin-audit 쪽 판정이 아직 남았기 때문이다. `MORE-RED` 는 0 이고, 나머지는 `SAME-RED`(기준선 RED) 다. 그 밖의 줄이 나오면 멈추고 보고한다.

- [ ] **Step 7: Commit**

```bash
git add plugins/spec-distill
git commit -q -F - <<'EOF'
fix(spec-distill): skill · reference 펜스가 cwd 로 플러그인 루트를 풀지 않는다 (3.1.1)

reviewing-brief · framing-requests · reviewing-spec 의 `${CLAUDE_PLUGIN_ROOT:-./plugins/spec-distill}`
과 끝자락 `|| SD="./plugins/spec-distill"` 를 bare 토큰 + 가드로 바꾼다. conducting-interview 의
finishing.md 펜스 둘에 가드를 두고, 여는 Read 줄을 절대 형태 + 안내 문장으로 바꾼다.
reviewing-spec 진입 테스트의 무치환 기대는 가드 정지 · 미끼 미실행으로 바꾼다.

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_018tuo6oUNrRDUVWRdKrkr6r
EOF
git log --oneline -1
```

---

### Task 3: quality-gates

**Files:**
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md`(P0b 116–123 · 135 · 274 · 293 · 509 · 844–850 · 915) · `skills/quality-pipeline/references/runtime-gate.md`(`QG=` 20곳) · `skills/critiquing-artifacts/SKILL.md`(38–40)
- Delete: `plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh`
- Modify: `plugins/quality-gates/CHANGELOG.md` · `.claude-plugin/plugin.json`
- Create (커밋 안 함): `$BASE_DIR/task3_apply.py`

**Interfaces:**
- Consumes: Task 1 의 락과 `redcheck.sh`. 락의 행동 테스트는 이 task 가 바꾸는 두 펜스를 대표로 자른다 — quality-pipeline 의 `check-review-scope.sh` 펜스와 runtime-gate 의 `resolve-baseline.sh` 펜스다. 이 둘은 각 파일에 **하나씩만** 있어야 한다.
- Produces: 없음.

- [ ] **Step 1: 락의 quality-gates 판정이 지금 RED 인지 본다**

```bash
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -c 'plugins/quality-gates/'; bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -c '✗ 행동'
```

Expected: 첫 줄 `1` 이상(모의 실행 기준 76) · 둘째 줄 `12`(행동 판정 전부 ✗).

- [ ] **Step 2: Write `$BASE_DIR/task3_apply.py`**

````python
#!/usr/bin/env python3
"""task3_apply.py <repo-root> — quality-gates 의 cwd fallback 제거(개수 검사 포함) · 은퇴 락 삭제."""
import pathlib
import sys

R = pathlib.Path(sys.argv[1])
MSG = ("플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 "
       "바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라")
SENT = ("그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 "
        "`${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 "
        "cwd 에서 찾지 말고 멈춰 보고한다.")


def guard(var, p):
    return f'{var}="${{CLAUDE_PLUGIN_ROOT}}"; [ -n "${var}" ] || {{ echo "[{p}] {MSG}" >&2; exit 1; }}'


def edit(rel, pairs):
    f = R / rel
    t = f.read_text(encoding="utf-8")
    for old, new, cnt in pairs:
        c = t.count(old)
        assert c == cnt, (rel, old[:70], c, cnt)
        t = t.replace(old, new)
    f.write_text(t, encoding="utf-8")


P = "quality-gates"
edit("plugins/quality-gates/skills/quality-pipeline/SKILL.md", [
    ('QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"', guard("QG", P), 5),
    ('(`${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}/scripts/`)', '(`${CLAUDE_PLUGIN_ROOT}/scripts/`)', 1),
    ("**Step P0b — Resolve the plugin root.** `CLAUDE_PLUGIN_ROOT` is **not set in the\nBash tool environment**. "
     "Run every script path below with the installed\nplugin-root substituted; when dogfooding inside the devbrew repo "
     "that is\n`./plugins/quality-gates`. Self-contained fences derive it in-line:",
     "**Step P0b — Resolve the plugin root.** Every script named below lives under\n`${CLAUDE_PLUGIN_ROOT}/scripts/`. "
     "If that path does not read as absolute, do not guess one\n(the cwd included) — stop and report. Self-contained "
     "fences take the root from the token\nand stop when it is empty:", 1),
    ("```\nRead references/runtime-gate.md\n```\n\n경로는 이 SKILL.md 파일 기준 상대경로다 — 레포·설치본 두 레이아웃 모두 이\n"
     "SKILL.md와 같은 위치에 `references/runtime-gate.md`가 있으므로 그대로 resolve\n"
     "된다([state-file-format](references/state-file-format.md#history)와 같은 관례).\n",
     "```\nRead ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/runtime-gate.md\n```\n\n" + SENT + "\n", 1),
])
edit("plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md", [
    ('QG="${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}"', guard("QG", P), 20),
])
edit("plugins/quality-gates/skills/critiquing-artifacts/SKILL.md", [
    ("모든 스크립트는 플러그인 루트의 `scripts/` 하위. `CLAUDE_PLUGIN_ROOT` 는 Bash 도구\n환경에 없으므로, 실행할 때 설치된 "
     "플러그인 루트로 치환한다 — devbrew 안에서는\n`./plugins/quality-gates`. 아래 단계를 **순서대로** 실행한다.",
     "모든 스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/` 하위다 — 아래에 이름만 적힌 스크립트는 이 경로의 것을\n실행한다. "
     "이 경로가 절대 경로로 보이지 않으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고한다. 아래 단계를\n"
     "**순서대로** 실행한다.", 1),
])

CHANGELOG = """## [7.6.1] — 2026-09-15

### Security

- **`/qg` 가 사용자 저장소의 스크립트를 실행하던 cwd fallback 을 없앴다.** `skills/quality-pipeline/SKILL.md` 의 펜스 다섯 · 산문 한 줄과 `skills/quality-pipeline/references/runtime-gate.md` 의 펜스 스물이 쓰던 `${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}` 는 Bash 도구 환경에 그 변수가 없어 언제나 cwd 의 `./plugins/quality-gates` 로 풀렸다 — devbrew 밖에서는 사용자 저장소의 `plugins/quality-gates/scripts/*` 를 실행했다. SKILL.md 펜스는 로드 시 치환되는 bare `${CLAUDE_PLUGIN_ROOT}` 에서, reference 펜스는 SKILL.md 가 건네는 절대 경로를 모델이 바꿔 넣어 루트를 받고, 둘 다 빈 값이면 `[quality-gates] 플러그인 루트 미해석 — …` 로 멈춘다.
- **reference 를 여는 줄이 절대 경로를 건넨다.** `Read references/runtime-gate.md` 는 `Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/runtime-gate.md` 가 되고, 「SKILL.md 기준 상대경로」 문단 자리에 그 파일의 루트 변수를 바꿔 넣으라는 한 줄이 선다.
- **루트 진술 둘.** Step P0b 와 `skills/critiquing-artifacts/SKILL.md` 의 「devbrew 안에서는 `./plugins/quality-gates`」를, 스크립트가 `${CLAUDE_PLUGIN_ROOT}/scripts/`(로드 시 치환)에 있고 절대 경로로 보이지 않으면 추측하지 말고 멈추라는 진술로 바꿨다 — 그 아래 이름만 적힌 스크립트 호출이 이 진술로 루트를 받는다.

**알려진 결과 둘**

- **devbrew 안 dogfooding 이 바뀐다.** 설치본 skill 이 이제 워킹트리가 아니라 설치본 스크립트를 돈다. 워킹트리 코드를 돌리려면 `claude --plugin-dir ./plugins/quality-gates` 로 로드한다.
- **skill 본문 치환이 없는 하니스에서는 멈춘다.** 경로를 추측하지 않고 가드에서 복구 지시와 함께 멈춘다. 어느 하니스가 그런지는 모른다 — 2.1.270 에서는 치환된다.

### Removed

- **`tests/test_skill_plugin_root_fallback.sh`.** 머리말의 「skill 의 지시에는 치환이 없다」는 2.1.239 의 Bash 환경 실측에서 이어진 추론이었고 2.1.270 에서 틀렸다 — skill 본문의 bare 토큰은 로드 시 치환된다. 그 락의 두 축(펜스 안 `:-` 강제 · 본문 bare 금지)은 새 규칙과 반대 방향이다. 전 플러그인을 재는 공용 락 `shared/tests/test_plugin_root_no_cwd_fallback.sh` 가 대체한다.

"""
edit("plugins/quality-gates/CHANGELOG.md", [("\n## [7.6.0] — 2026-09-14\n", "\n" + CHANGELOG + "## [7.6.0] — 2026-09-14\n", 1)])
edit("plugins/quality-gates/.claude-plugin/plugin.json", [('"version": "7.6.0"', '"version": "7.6.1"', 1)])
(R / "plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh").unlink()
print("task3 applied")
````

- [ ] **Step 3: 편집을 적용한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
python3 "$BASE_DIR/task3_apply.py" "$(pwd)" && git status --short
```

Expected: `task3 applied`. 수정 ` M` 다섯(SKILL 둘 · runtime-gate · CHANGELOG · plugin.json)과 삭제 ` D` 하나(`tests/test_skill_plugin_root_fallback.sh`).

- [ ] **Step 4: GREEN 을 확인한다**

```bash
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -c 'plugins/quality-gates/'
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | grep -E '✓ 행동' | wc -l
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -1
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh 2>&1 | tail -1
git grep -n 'test_skill_plugin_root_fallback' -- . ':!*/CHANGELOG.md' ':!docs/archive' ':!docs/superpowers/plans' ':!docs/superpowers/specs' ; echo "active refs rc=$?"
```

Expected, 순서대로: `0` · `12`(행동 판정 전부 ✓) · `… | Fail: 0` · `… | Fail: 0` · 출력 없이 `active refs rc=1`(AC6 — 활성 참조 0).

- [ ] **Step 5: 기준선 대비 새 RED 가 없는지 본다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
bash "$BASE_DIR/redcheck.sh" $(find plugins/quality-gates/tests -name 'test_*.sh' -not -path '*/fixtures/*' | LC_ALL=C sort) shared/tests/test_*.sh
for t in plugins/quality-gates/tests/test_*.py; do python3 "$t" >/dev/null 2>&1 || echo "PY-RED $t"; done
git checkout HEAD -- plugins/quality-gates/tests/spike/fixtures && git status --short
```

Expected: `NEW-RED` 는 `shared/tests/test_plugin_root_no_cwd_fallback.sh` 한 줄뿐이다(plugin-audit 쪽 판정이 남았다). `MORE-RED` 는 0 이다. `PY-RED` 는 `$BASE_DIR/base/summary.tsv` 에서 이미 RED 인 파일만 나와야 한다. 그 밖이면 멈추고 보고한다.

마지막 두 명령이 중요하다. `tests/spike/test_codex_json_extraction.sh` 는 추적 fixture 를 부작용으로 고치므로 여기서 되돌린다 — 되돌리지 않으면 다음 Step 의 `git add -A` 가 그것까지 커밋한다. `git status --short` 에는 Step 3 의 여섯 줄만 남아야 한다.

- [ ] **Step 6: Commit**

```bash
git add -A plugins/quality-gates
git commit -q -F - <<'EOF'
fix(quality-gates): skill · reference 펜스가 cwd 로 플러그인 루트를 풀지 않는다 (7.6.1)

quality-pipeline 펜스 다섯 · 산문 한 줄 · runtime-gate 펜스 스물의
`${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}` 를 bare 토큰 + 가드로 바꾸고, runtime-gate 를 여는
Read 줄을 절대 형태 + 안내 문장으로 바꾼다. Step P0b · critiquing-artifacts 의 cwd 루트 진술을 치환
루트로 다시 쓴다. 전제가 반증된 test_skill_plugin_root_fallback.sh 를 은퇴시킨다(공용 락이 대체).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_018tuo6oUNrRDUVWRdKrkr6r
EOF
git log --oneline -1
```

---

### Task 4: plugin-audit

**Files:**
- Modify: `plugins/plugin-audit/skills/auditing-plugins/SKILL.md`(17–21 · 43–45 · 112) · `scripts/check-law2.py`(201)
- Modify (tests): `plugins/plugin-audit/tests/test_check_law2.py`
- Modify: `plugins/plugin-audit/CHANGELOG.md` · `.claude-plugin/plugin.json`
- Create (커밋 안 함): `$BASE_DIR/task4_tests.py` · `$BASE_DIR/task4_apply.py`

**Interfaces:**
- Consumes: Task 1 의 락과 `redcheck.sh`.
- Produces: 없음. 이 task 가 끝나면 락이 전부 GREEN 이다.

- [ ] **Step 1: Write `$BASE_DIR/task4_tests.py` — AC11 두 케이스**

````python
#!/usr/bin/env python3
"""task4_tests.py <repo-root> — check-law2.py 의 --agents-dir 기본값이 cwd 가 아니라 스크립트 옆임을 잰다(AC11)."""
import pathlib
import sys

R = pathlib.Path(sys.argv[1])
f = R / "plugins/plugin-audit/tests/test_check_law2.py"
t = f.read_text(encoding="utf-8")
NEW = '''class TestDefaultAgentsDir(unittest.TestCase):
    """`--agents-dir` 를 안 주면 스크립트 옆 `agents/` 를 본다 — cwd 가 아니다(설계 AC11)."""

    def run_default(self, cwd):
        return subprocess.run(
            [sys.executable, str(SCRIPT), str(REPO / "scripts" / "audit-workflow.js")],
            capture_output=True, text=True, cwd=str(cwd))

    def test_default_resolves_without_repo_cwd(self):
        # cwd 에 plugins/plugin-audit/ 이 없어도 설치본(스크립트 옆) agents 로 돈다.
        with tempfile.TemporaryDirectory() as d:
            r = self.run_default(d)
            self.assertEqual(r.returncode, 0, f"cwd 밖에서 기본 agents 를 못 찾았다:\\n{r.stderr}")

    def test_default_ignores_cwd_copy(self):
        # cwd 에 쓰기 도구를 가진 가짜 agents 사본이 있어도 기본값은 그것을 보지 않는다.
        with tempfile.TemporaryDirectory() as d:
            ag = Path(d) / "plugins" / "plugin-audit" / "agents"
            ag.mkdir(parents=True)
            (ag / "plugin-auditor.md").write_text(
                "---\\nname: plugin-auditor\\ntools: Read, Write, Bash\\n---\\nbody\\n", encoding="utf-8")
            (ag / "audit-refuter.md").write_text(FM_GOOD_REFUTER, encoding="utf-8")
            r = self.run_default(d)
            self.assertEqual(r.returncode, 0, f"기본값이 cwd 의 agents 사본을 읽었다:\\n{r.stderr}")


'''
anchor = 'if __name__ == "__main__":\n'
assert t.count(anchor) == 1
f.write_text(t.replace(anchor, NEW + anchor), encoding="utf-8")
print("task4 tests edited")
````

- [ ] **Step 2: RED 를 확인한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
python3 "$BASE_DIR/task4_tests.py" "$(pwd)" && python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests -p 'test_check_law2.py' 2>&1 | grep -E '^(FAIL|ERROR|OK|FAILED|Ran)'
```

Expected: `FAIL: test_default_ignores_cwd_copy` · `FAIL: test_default_resolves_without_repo_cwd` · `Ran 6 tests` · `FAILED (failures=2)`. 기본값이 cwd 의 `plugins/plugin-audit/agents` 를 보기 때문이다 — 하나는 파일 부재로, 하나는 가짜 사본의 쓰기 도구로 RED.

- [ ] **Step 3: Write `$BASE_DIR/task4_apply.py`**

````python
#!/usr/bin/env python3
"""task4_apply.py <repo-root> — plugin-audit 의 cwd fallback · 자기 하니스 cwd 인자 · --agents-dir 기본값."""
import pathlib
import sys

R = pathlib.Path(sys.argv[1])
MSG = ("플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 "
       "바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라")


def guard(var, p):
    return f'{var}="${{CLAUDE_PLUGIN_ROOT}}"; [ -n "${var}" ] || {{ echo "[{p}] {MSG}" >&2; exit 1; }}'


def edit(rel, pairs):
    f = R / rel
    t = f.read_text(encoding="utf-8")
    for old, new, cnt in pairs:
        c = t.count(old)
        assert c == cnt, (rel, old[:70], c, cnt)
        t = t.replace(old, new)
    f.write_text(t, encoding="utf-8")


edit("plugins/plugin-audit/skills/auditing-plugins/SKILL.md", [
    ('PA="${CLAUDE_PLUGIN_ROOT:-./plugins/plugin-audit}"', guard("PA", "plugin-audit"), 1),
    ("**모든 스크립트 호출은 리포 root에서** 실행한다. `check-law2.py`의 `--agents-dir` 기본값\n"
     "(`plugins/plugin-audit/agents`)이 cwd-relative고, pre-check 스크립트들(`check-shape-completeness.py\n"
     "<plugin_dir>`, `check-integrity.sh --target`)도 cwd-relative positional/path 인자를 받는다 — 다른\n"
     "cwd에서 부르면 조용히 엉뚱한(또는 부재하는) 경로를 본다. (`check-shape-completeness.py --repo-root`는\n"
     "parse만 되고 `check()`엔 전달되지 않는 dead flag — cwd 민감성의 원인이 아니다.)\n",
     "**스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/` 에 있다** — 아래에 이름만 적힌 스크립트는 모두 이 경로의 것을\n"
     "실행하고, 이 경로가 절대 경로로 보이지 않으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고한다. **감사 대상 인자는\n"
     "리포 root 기준이다** — 호출은 리포 root 에서 한다. pre-check 스크립트들(`check-shape-completeness.py\n"
     "<plugin_dir>`, `check-integrity.sh --target`)이 cwd-relative positional/path 인자를 받기 때문이다 — 다른\n"
     "cwd에서 부르면 조용히 엉뚱한(또는 부재하는) 경로를 본다. (`check-shape-completeness.py --repo-root`는\n"
     "parse만 되고 `check()`엔 전달되지 않는 dead flag — cwd 민감성의 원인이 아니다.) `check-law2.py` 의\n"
     "`--agents-dir` 기본값은 스크립트 위치 기준(`<플러그인 루트>/agents`)이다.\n", 1),
    ("- `check-law2.py plugins/plugin-audit/scripts/audit-workflow.js --agents-dir plugins/plugin-audit/agents`\n"
     "  + 별도 호출로 `check-law2.py plugins/plugin-audit/scripts/smoke-workflow.js --mode smoke\n"
     "  --agents-dir plugins/plugin-audit/agents`",
     "- `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check-law2.py ${CLAUDE_PLUGIN_ROOT}/scripts/audit-workflow.js "
     "--agents-dir ${CLAUDE_PLUGIN_ROOT}/agents`\n"
     "  + 별도 호출로 `python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check-law2.py ${CLAUDE_PLUGIN_ROOT}/scripts/smoke-workflow.js "
     "--mode smoke\n  --agents-dir ${CLAUDE_PLUGIN_ROOT}/agents`", 1),
])
edit("plugins/plugin-audit/scripts/check-law2.py", [
    ('ap.add_argument("--agents-dir", type=Path, default=Path("plugins/plugin-audit/agents"))',
     'ap.add_argument("--agents-dir", type=Path, default=Path(__file__).resolve().parent.parent / "agents")', 1),
])

CHANGELOG = """## [0.9.3] — 2026-09-15

### Security

- **codex 감지 펜스가 cwd 의 `./plugins/plugin-audit` 로 떨어지던 fallback 을 없앴다.** `skills/auditing-plugins/SKILL.md` 의 `PA="${CLAUDE_PLUGIN_ROOT:-./plugins/plugin-audit}"` 는 Bash 도구 환경에 그 변수가 없어 언제나 cwd 상대로 풀렸다. 이제 로드 시 치환되는 bare `${CLAUDE_PLUGIN_ROOT}` 에서 받고, 빈 값이면 `[plugin-audit] 플러그인 루트 미해석 — …` 로 멈춘다.
- **Law 2 정적 게이트가 실행 대상과 같은 플러그인 루트를 본다.** pre-0 의 `check-law2.py` 호출이 자기 워크플로 · agents 를 cwd 상대 `plugins/plugin-audit/…` 로 받아, Workflow 가 실행하는 설치본과 게이트가 검사하는 사본이 갈라질 수 있었다. 호출과 인자를 `${CLAUDE_PLUGIN_ROOT}/…` 로 바꾸고, 「모든 스크립트 호출은 리포 root에서」 진술을 「스크립트는 `${CLAUDE_PLUGIN_ROOT}/scripts/`, 감사 대상 인자는 리포 root 기준」으로 다시 썼다.

### Fixed

- **`scripts/check-law2.py` 의 `--agents-dir` 기본값이 cwd 상대(`plugins/plugin-audit/agents`)였다.** 스크립트 위치 기준(`<플러그인 루트>/agents`)으로 바꿨다 — cwd 에 `plugins/plugin-audit/` 이 없거나 다른 사본이 있어도 설치본 agents 를 검사한다. `tests/test_check_law2.py` 에 두 케이스를 더했다.

**알려진 결과 둘**

- **devbrew 안 dogfooding 이 바뀐다.** 설치본 skill 이 이제 워킹트리가 아니라 설치본 스크립트를 돈다. 워킹트리 코드를 돌리려면 `claude --plugin-dir ./plugins/plugin-audit` 로 로드한다.
- **skill 본문 치환이 없는 하니스에서는 멈춘다.** 경로를 추측하지 않고 가드에서 복구 지시와 함께 멈춘다. 어느 하니스가 그런지는 모른다 — 2.1.270 에서는 치환된다.

**범위 밖으로 남긴 것** — `scripts/check-integrity.sh` 의 harness 변조 감시는 체크아웃 사본을 해시하고, `scripts/run-own-tests.sh` 는 quality-gates 스크립트를 cwd 에서 찾는다. 이 릴리스 이전부터의 불일치이며 후속으로 넘긴다.

"""
edit("plugins/plugin-audit/CHANGELOG.md", [("\n## [0.9.2] — 2026-09-11\n", "\n" + CHANGELOG + "## [0.9.2] — 2026-09-11\n", 1)])
edit("plugins/plugin-audit/.claude-plugin/plugin.json", [('"version": "0.9.2"', '"version": "0.9.3"', 1)])
print("task4 applied")
````

- [ ] **Step 4: 편집을 적용하고 GREEN 을 확인한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
python3 "$BASE_DIR/task4_apply.py" "$(pwd)"
python3 -m unittest discover -s plugins/plugin-audit/tests -t plugins/plugin-audit/tests 2>&1 | tail -1
node --test --test-reporter=tap plugins/plugin-audit/tests/*.test.mjs 2>&1 | grep -E '^# (pass|fail)'
bash shared/tests/test_plugin_root_no_cwd_fallback.sh 2>&1 | tail -1
bash shared/tests/test_changelog_integrity.sh 2>&1 | tail -1
```

Expected, 순서대로:
- `task4 applied`
- `OK`(plugin-audit unittest 전부 — 새 두 케이스 포함)
- `# pass N` · `# fail 0`
- `Total: 22 | Pass: 22 | Fail: 0` — 락 전부 GREEN(AC1–AC5)
- `… | Fail: 0`

- [ ] **Step 5: 기준선 대비 새 RED 가 없는지 본다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
bash "$BASE_DIR/redcheck.sh" plugins/plugin-audit/tests/test_*.sh shared/tests/test_*.sh plugins/quality-gates/tests/test_codex_gate_observation.sh
```

Expected: `NEW-RED` · `MORE-RED` 가 0 이다. `test_codex_gate_observation.sh` 는 auditing-plugins 의 codex 게이트 펜스를 잘라 실행하므로 여기서 함께 돈다.

- [ ] **Step 6: Commit**

```bash
git add plugins/plugin-audit
git commit -q -F - <<'EOF'
fix(plugin-audit): codex 감지 펜스 · Law 2 게이트가 cwd 로 플러그인 루트를 풀지 않는다 (0.9.3)

auditing-plugins 의 `PA="${CLAUDE_PLUGIN_ROOT:-./plugins/plugin-audit}"` 를 bare 토큰 + 가드로,
Law 2 정적 게이트의 자기 워크플로 · agents 인자를 `${CLAUDE_PLUGIN_ROOT}/…` 로 바꾸고, 「리포 root에서」
루트 진술을 다시 쓴다. check-law2.py 의 --agents-dir 기본값을 스크립트 위치 기준으로 바꾼다(AC11).

Co-Authored-By: Claude Opus 5 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_018tuo6oUNrRDUVWRdKrkr6r
EOF
git log --oneline -1
```

---

### Task 5: 검증 — 변이 행렬 · 전체 스위트 대조

**Files:**
- Create (커밋 안 함): `$BASE_DIR/mutate.py` · `$BASE_DIR/wt-head/`(detached 워크트리) · `$BASE_DIR/head/`
- 이 task 는 커밋하지 않는다. 결함이 나오면 해당 플러그인 task 로 돌아가 고치고 그 task 의 커밋을 새로 만든다.

**Interfaces:**
- Consumes: Task 1 의 기준선(`$BASE_DIR/base/`) · `run-suite.sh` · 락 · Task 2–4 의 커밋.
- Produces: PR 본문에 옮길 숫자. 변이 행렬 결과, 전체 스위트 대조 결과(새 실패 식별자 0 · 파일별 실패 줄 수), AC6 확인 결과다.

- [ ] **Step 1: Write `$BASE_DIR/mutate.py`**

````python
#!/usr/bin/env python3
"""mutate.py <repo-root> — 새 공용 락의 변이 행렬. 변이마다 파일 하나를 바꾸고, 락을 돌리고, 되돌린다.

판정: 변이 전 GREEN(양성 대조) · 변이마다 rc≠0 이고 기대한 축의 ✗ 줄이 나온다 · 끝나고 다시 GREEN.
되돌리기는 메모리의 원본으로 한다 — 끝난 뒤 `git diff HEAD --quiet` 로 한 번 더 확인한다.
"""
import pathlib
import subprocess
import sys

R = pathlib.Path(sys.argv[1]).resolve()
LOCK = "shared/tests/test_plugin_root_no_cwd_fallback.sh"
QP = "plugins/quality-gates/skills/quality-pipeline/SKILL.md"
RG = "plugins/quality-gates/skills/quality-pipeline/references/runtime-gate.md"
CA = "plugins/quality-gates/skills/critiquing-artifacts/SKILL.md"
QGCMD = "plugins/quality-gates/commands/qg.md"
RS = "plugins/spec-distill/skills/reviewing-spec/SKILL.md"
CI = "plugins/spec-distill/skills/conducting-interview/SKILL.md"
FIN = "plugins/spec-distill/skills/conducting-interview/references/finishing.md"
AP = "plugins/plugin-audit/skills/auditing-plugins/SKILL.md"
QG_GUARD = 'QG="${CLAUDE_PLUGIN_ROOT}"; [ -n "$QG" ] || {'
SD_GUARD_HEAD = 'SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || {'
SENT_HEAD = "그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는"


def line_of(text, needle, nth=0):
    lines = text.split("\n")
    hits = [i for i, l in enumerate(lines) if needle in l]
    assert len(hits) > nth, (needle, len(hits))
    return lines, hits[nth]


def m_replace_first(old, new):
    def f(t):
        assert old in t, old[:60]
        return t.replace(old, new, 1)
    return f


def m_append(extra):
    return lambda t: t.rstrip("\n") + "\n\n" + extra + "\n"


def m_line(needle, fn, nth=0):
    def f(t):
        lines, i = line_of(t, needle, nth)
        lines[i:i + 1] = fn(lines[i])
        return "\n".join(lines)
    return f


def m_swap_resolve_baseline(t):
    lines, i = line_of(t, '"$QG/scripts/resolve-baseline.sh"')
    assert QG_GUARD in lines[i - 1]
    lines[i - 1], lines[i] = lines[i], lines[i - 1]
    return "\n".join(lines)


def m_drop_fin_state_root_fence(t):
    lines, i = line_of(t, 'ROOT="$(python3 "$SD/scripts/state_path.py" state-root)"')
    assert SD_GUARD_HEAD in lines[i - 1]
    del lines[i - 1:i + 1]
    return "\n".join(lines)


def guard_only(line):
    return [line.split(";", 1)[0]]


def drop_line(_line):
    return []


M = [
    ("M1 SKILL.md 펜스에 :-./plugins/x", QP, m_replace_first(QG_GUARD, QG_GUARD.replace("${CLAUDE_PLUGIN_ROOT}", "${CLAUDE_PLUGIN_ROOT:-./plugins/x}")), "축 1:"),
    ("M2 SKILL.md 산문에 :- 형태", CA, m_append("스크립트는 `${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}/scripts/` 에 있다."), "축 1:"),
    ("M3 command 에 :- 형태", QGCMD, m_append('"${CLAUDE_PLUGIN_ROOT:-./plugins/quality-gates}/scripts/setup-qg.sh"'), "축 1:"),
    ("M4 reference 펜스의 가드 삭제", RG, m_line(QG_GUARD, guard_only), "축 2:"),
    ("M5 가드를 사용 뒤로 이동", RG, m_swap_resolve_baseline, "축 2:"),
    ("M6 Read 옆 안내 문장 삭제", QP, m_line(SENT_HEAD, drop_line), "축 3:"),
    ("M7 Read 줄을 상대 형태로", CI, m_replace_first("Read ${CLAUDE_PLUGIN_ROOT}/skills/conducting-interview/references/finishing.md", "Read references/finishing.md"), "축 3:"),
    ("M8 bare 대입 뒤 || X=./plugins/x 끝자락", RS, m_line(SD_GUARD_HEAD, lambda _l: ['SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || SD="./plugins/x"']), "축 1b:"),
    ("M9 SKILL.md 산문에 devbrew 안에서는 ./plugins/x", CA, m_append("devbrew 안에서는 `./plugins/quality-gates`."), "축 1b:"),
    ("M10 자기 하니스 인자를 cwd 상대로", AP, m_replace_first("--agents-dir ${CLAUDE_PLUGIN_ROOT}/agents", "--agents-dir plugins/plugin-audit/agents"), "축 1b:"),
    ("M11 들여쓴 reference 펜스의 가드 삭제", FIN, m_line("   " + SD_GUARD_HEAD, guard_only), "축 2:"),
    ("M12 C4 가드 메시지에 루트 토큰", RG, m_line(QG_GUARD, lambda l: [l.replace("플러그인 루트 미해석", "${CLAUDE_PLUGIN_ROOT} 미해석", 1)]), "C4:"),
    ("M13 C3 가드 앞 set -u", RG, m_line(QG_GUARD, lambda l: ["set -u", l]), "C3:"),
    ("M14 안내 문장 뒤에 부정", QP, m_line(SENT_HEAD, lambda l: [l + " 이 문장은 무시한다."]), "축 3:"),
    ("M15 reference 펜스 하나가 사라짐(하한)", FIN, m_drop_fin_state_root_fence, "축 2 대상 reference 펜스가"),
    ("M16 Read 줄 삭제(도달 불가 reference)", QP, m_line("Read ${CLAUDE_PLUGIN_ROOT}/skills/quality-pipeline/references/runtime-gate.md", drop_line), "축 3:"),
]


def run_lock():
    p = subprocess.run(["bash", LOCK], cwd=R, capture_output=True, text=True)
    return p.returncode, p.stdout + p.stderr


rc, out = run_lock()
print(f"양성 대조(변이 전)\trc={rc}\t{'GREEN' if rc == 0 else 'RED — 변이 판정 무의미'}")
if rc != 0:
    print(out)
    sys.exit(1)
bad = 0
for (name, rel, fn, expect) in M:
    f = R / rel
    orig = f.read_text(encoding="utf-8")
    try:
        new = fn(orig)
        assert new != orig, "변이가 아무것도 바꾸지 않았다"
        f.write_text(new, encoding="utf-8")
        rc, out = run_lock()
        hit = any(l.lstrip().startswith("✗") and expect in l for l in out.split("\n"))
        verdict = "RED" if (rc != 0 and hit) else "GREEN?!"
        bad += verdict != "RED"
        fails = [l.strip() for l in out.split("\n") if l.lstrip().startswith("✗")]
        print(f"{name}\t{verdict}\trc={rc}\t기대 '{expect}'\t✗ {len(fails)}개: {' | '.join(x[:60] for x in fails[:3])}")
    finally:
        f.write_text(orig, encoding="utf-8")
rc, out = run_lock()
print(f"복원 뒤\trc={rc}\t{'GREEN' if rc == 0 else 'RED — 복원 실패'}")
sys.exit(1 if (bad or rc) else 0)
````

- [ ] **Step 2: 변이 행렬을 돌린다 (AC7)**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
git diff HEAD --quiet && echo "clean before" && python3 "$BASE_DIR/mutate.py" "$(pwd)"; echo "mutate rc=$?"; git diff HEAD --quiet && echo "clean after"
```

Expected: `clean before` · `양성 대조(변이 전) … GREEN` · M1–M16 **전부 `RED`** · `복원 뒤 … GREEN` · `mutate rc=0` · `clean after`. 설계 AC7 의 열한 변이는 M1–M11 이다. M12–M16 은 이 계획이 더한 축(C3 · C4 · 줄 전체 일치 · 하한 · `Read` 부재)의 이빨이다. 하나라도 `GREEN?!` 이면 멈추고 보고한다.

- [ ] **Step 3: 전체 스위트를 HEAD 의 detached 워크트리에서 돌린다 (AC8)**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
git worktree add -q --detach "$BASE_DIR/wt-head" HEAD && git -C "$BASE_DIR/wt-head" log --oneline -1
bash "$BASE_DIR/run-suite.sh" "$BASE_DIR/wt-head" "$BASE_DIR/head"; cat "$BASE_DIR/head/DONE"
```

두 번째 줄은 `run_in_background` 로 돈다. 끝나면 Step 4.

- [ ] **Step 4: 기준선과 대조한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"; cd "$BASE_DIR"
echo "== rc/실패 줄 수가 달라진 단위 (id  base-rc base-n  head-rc head-n)"
join -t "$(printf '\t')" -a1 -a2 -e MISSING -o 0,1.2,1.3,2.2,2.3 <(LC_ALL=C sort base/summary.tsv) <(LC_ALL=C sort head/summary.tsv) | awk -F'\t' '$2!=$4 || $3!=$5'
echo "== 새 실패 식별자 (head - base)"; LC_ALL=C comm -13 <(LC_ALL=C sort -u base/fail-ids.tsv) <(LC_ALL=C sort -u head/fail-ids.tsv)
echo "== 사라진 실패 식별자 (base - head)"; LC_ALL=C comm -23 <(LC_ALL=C sort -u base/fail-ids.tsv) <(LC_ALL=C sort -u head/fail-ids.tsv)
echo "== head RED 단위와 실패 줄 수"; awk -F'\t' '$2!=0' head/summary.tsv
echo "== status-after"; cat head/status-after.txt
```

Expected:
- 달라진 단위는 둘뿐이다 — 새 락 `shared/tests/test_plugin_root_no_cwd_fallback.sh`(base `MISSING` → head `0 0`)와 은퇴 락 `plugins/quality-gates/tests/test_skill_plugin_root_fallback.sh`(base `0 0` → head `MISSING`).
- **새 실패 식별자 0**(AC8).
- 사라진 실패 식별자 0.
- head RED 단위와 파일별 실패 줄 수는 기준선과 같다.
- status-after 는 비어 있다.

「새 실패 식별자」에 무엇이든 나오면 멈추고 보고한다. 기준선에서 이미 RED 인 파일 안의 새 실패도 여기서 보인다.

예외 하나는 판정해서 넘긴다. `plugins/quality-gates/tests/test_codex_backward_compat.sh` 는 qg 테스트 전부를 자기 안에서 다시 돌리고, 등재되지 않은 실패를 `FAIL: 예상 밖 실패 → a.sh(미등재) b.sh(미등재) …` **한 줄**로 모은다. 그 줄의 구성원이 하나만 달라져도 줄 전체가 새 식별자로 잡힌다.

- head 쪽 구성원이 base 쪽 구성원의 부분집합이면 새 실패가 아니다.
- head 에만 있는 구성원은 워크트리 루트에서 단독으로 3회 돌린다. 3회 모두 GREEN 이면 흔들리는 테스트로 적고 넘어간다. 한 번이라도 RED 면 멈추고 보고한다.

계획 작성 중 모의 실행에서 흔들린 것은 둘이다. `test_codex_runner_degrade_contract.sh` 는 이 집계 안에서만 한 번 실패하고 단독으로는 6/6 GREEN 이었다. `test_findings_parser.sh` 는 한 실행에서만 RED 였다.

- [ ] **Step 5: 락 코퍼스 밖까지 한 번 더 훑는다**

```bash
git grep -n -e 'CLAUDE_PLUGIN_ROOT:-' -e '\./plugins/' -- 'plugins/*.md' ':!*/CHANGELOG.md' ':!*/README.md' ':!*/tests/*'; echo "rc=$?"
```

Expected: 출력 없이 `rc=1`. agents · templates 본문도 모델이 읽으므로 락 코퍼스(skills · commands · references) 밖까지 본다. README 는 사람이 읽는 개발 안내라 뺀다. 무엇이든 나오면 보고한다 — 락의 코퍼스를 넓힐지는 사용자가 정한다.

- [ ] **Step 6: 워크트리를 정리한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"
git worktree remove --force "$BASE_DIR/wt-base" && git worktree remove --force "$BASE_DIR/wt-head" && git worktree list
git status --short; git rev-parse --abbrev-ref HEAD
```

Expected: 목록에 `wt-base` · `wt-head` 가 없다 · 작업 트리가 깨끗하다 · 브랜치 `fix/plugin-root-cwd-fallback`.

---

### Task 6: AC9 헤드리스 프로브 (관찰 · 기록)

통과 조건은 설계 AC9 그대로 둘이다. (a) 수정된 SKILL.md 펜스가 절대 경로로 도착한다(하니스 기록). (b) reference 펜스 실행에서 미끼가 한 번도 실행되지 않는다. 모델이 루트를 바꿔 넣었는지, 가드에서 멈췄는지는 **결과로 적을 뿐** 통과 조건이 아니다. haiku 호출 3회다.

**Files:**
- Create (커밋 안 함): `$BASE_DIR/ac9_analyze.py` · `$BASE_DIR/ac9/`

**Interfaces:**
- Consumes: Task 3 까지의 브랜치 코드(`--plugin-dir` 로 로드한다).
- Produces: PR 본문에 옮길 세 줄(실행별 (a) · resolve-baseline 호출 형태 · 가드 관측)과 (b) 한 줄.

- [ ] **Step 1: Write `$BASE_DIR/ac9_analyze.py`**

````python
#!/usr/bin/env python3
"""ac9_analyze.py <plugin-dir> <probe-dir> <run.jsonl>... — AC9 프로브 기록을 읽는다(관찰)."""
import json
import pathlib
import sys

plugin_dir, probe = sys.argv[1], pathlib.Path(sys.argv[2])
body_mark = f'QG="{plugin_dir}"; [ -n "$QG" ] ||'
read_mark = f"Read {plugin_dir}/skills/quality-pipeline/references/runtime-gate.md"


def strings(o):
    if isinstance(o, str):
        yield o
    elif isinstance(o, dict):
        for v in o.values():
            yield from strings(v)
    elif isinstance(o, list):
        for v in o:
            yield from strings(v)


for f in sys.argv[3:]:
    a = r = guard_stop = False
    cmds, bash_ids = [], set()
    for line in open(f, encoding="utf-8"):
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        for s in strings(ev):
            a = a or body_mark in s
            r = r or read_mark in s
        msg = ev.get("message") if isinstance(ev, dict) else None
        content = msg.get("content") if isinstance(msg, dict) else None
        for c in content if isinstance(content, list) else []:
            if not isinstance(c, dict):
                continue
            if c.get("type") == "tool_use" and c.get("name") == "Bash":
                bash_ids.add(c.get("id"))
                cmds.append(" ".join(str(c.get("input", {}).get("command", "")).split()))
            if c.get("type") == "tool_result" and c.get("tool_use_id") in bash_ids:
                if any("플러그인 루트 미해석" in s for s in strings(c.get("content"))):
                    guard_stop = True
    rb = [c for c in cmds if "resolve-baseline.sh" in c]
    print(f"{pathlib.Path(f).name}\t(a) SKILL.md 펜스 절대 경로 도착={'yes' if a else 'NO'}\t"
          f"Read 줄 절대 경로={'yes' if r else 'NO'}\t가드 정지 관측={'yes' if guard_stop else 'no'}\t"
          f"resolve-baseline 호출 {len(rb)}회")
    for c in rb:
        print("    $ " + c[:220])
baits = sorted(p.name for p in probe.glob("BAIT.*"))
print("(b) 미끼 실행: " + ("없음" if not baits else ", ".join(baits)))
sys.exit(1 if baits else 0)
````

- [ ] **Step 2: 미끼를 둔 버림 저장소와 프롬프트를 만든다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"; WT="$(git rev-parse --show-toplevel)"; PROBE="$BASE_DIR/ac9"
rm -rf "$PROBE" && mkdir -p "$PROBE/userrepo/plugins/quality-gates/scripts"
git -C "$PROBE/userrepo" init -q && git -C "$PROBE/userrepo" -c user.email=p@p -c user.name=p commit -q --allow-empty -m init
for s in $(git -C "$WT" ls-files plugins/quality-gates/scripts | sed 's#.*/##'); do
  case "$s" in
    *.py) printf 'open("%s/BAIT.%s", "w").close()\n' "$PROBE" "$s" ;;
    *)    printf '#!/bin/sh\ntouch "%s/BAIT.%s"\n' "$PROBE" "$s" ;;
  esac > "$PROBE/userrepo/plugins/quality-gates/scripts/$s"
  chmod +x "$PROBE/userrepo/plugins/quality-gates/scripts/$s"
done
cat > "$PROBE/prompt.txt" <<'EOF'
Use the Skill tool to load quality-gates:quality-pipeline. Do NOT run the pipeline and do NOT run any of its other steps.

Follow the skill's "## Runtime gate" section: Read the runtime-gate reference exactly as that section says. Then run, with the Bash tool, the reference's Step R-init fence that runs resolve-baseline.sh — exactly as the reference and the skill instruct. Report the command you ran and its output, then stop.
EOF
ls "$PROBE/userrepo/plugins/quality-gates/scripts" | wc -l
```

Expected: 미끼 개수 = `git ls-files plugins/quality-gates/scripts` 의 개수(계획 작성 시점 60).

- [ ] **Step 3: 헤드리스 3회를 돌린다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"; WT="$(git rev-parse --show-toplevel)"; PROBE="$BASE_DIR/ac9"
for i in 1 2 3; do
  ( cd "$PROBE/userrepo" && claude -p --model haiku --plugin-dir "$WT/plugins/quality-gates" \
      --allowedTools 'Skill' 'Read' 'Bash' --output-format stream-json --verbose < "$PROBE/prompt.txt" ) \
    > "$PROBE/run$i.jsonl" 2> "$PROBE/run$i.err"
  echo "run$i rc=$? lines=$(wc -l < "$PROBE/run$i.jsonl")"
done
python3 "$BASE_DIR/ac9_analyze.py" "$WT/plugins/quality-gates" "$PROBE" "$PROBE"/run*.jsonl; echo "analyze rc=$?"
```

프롬프트는 stdin 으로 넣는다. `--allowedTools` 는 인자를 여러 개 받는 플래그라 뒤따르는 프롬프트 인자를 삼킨다. 쓰기 도구는 주지 않는다. 버림 저장소 밖에 쓰는 일은 없다.

Expected:
- 세 실행 모두 `(a) … =yes` 다.
- `(b) 미끼 실행: 없음` 이고 `analyze rc=0` 이다.
- resolve-baseline 호출 형태는 기록만 한다 — 절대 경로로 바꿔 넣었는지, `${CLAUDE_PLUGIN_ROOT}` 를 그대로 실행해 가드에서 멈췄는지.

`(a)=NO` 면 먼저 `run*.jsonl` 에 skill 본문이 실렸는지 본다. 모델이 skill 을 로드하지 않았으면 그 실행은 판정 불가로 적고 1회 더 돌린다. 로드했는데 NO 면 멈추고 보고한다. 미끼가 하나라도 돌았으면 멈추고 보고한다 — 이 설계의 핵심 결함이 남은 것이다.

- [ ] **Step 4: 결과를 PR 본문 초안에 옮길 수 있게 남기고 정리한다**

```bash
BASE_DIR="${TMPDIR:-/tmp}/plugin-root-cwd-fallback"; WT="$(git rev-parse --show-toplevel)"
python3 "$BASE_DIR/ac9_analyze.py" "$WT/plugins/quality-gates" "$BASE_DIR/ac9" "$BASE_DIR"/ac9/run*.jsonl > "$BASE_DIR/ac9-summary.txt"; cat "$BASE_DIR/ac9-summary.txt"
claude --version
```

`ac9-summary.txt` 와 `claude --version` 을 PR 본문 「AC9 헤드리스 프로브」 절에 그대로 옮긴다. 대화형 세션은 재지 않았다는 사실도 함께 적는다(설계 「알려진 한계」).

---

## 머지 전

- **`/qg` Review gate** — 설계 검증 계획 6. 사용자가 부른다.
- **버전 재확인** — `git fetch origin && git show origin/main:plugins/<p>/.claude-plugin/plugin.json` 로 세 플러그인의 main 버전을 본다. main 이 그사이 같은 플러그인을 올렸으면 이 브랜치 번호를 그 위의 patch 로 다시 매기고 CHANGELOG 헤딩도 함께 고친다. 같은 버전 문자열은 충돌 없이 병합되므로 눈으로 대조한다.
- **PR 본문** — Task 5 의 숫자(변이 16/16 RED · 새 실패 식별자 0 · 파일별 실패 줄 수)와 Task 6 의 `ac9-summary.txt` 를 싣는다. 범위 밖 둘(D2.7)과 PR #155 후속 코멘트의 남은 항목 1–6 도 적는다.
- **메모리** — `project_plugin_root_cwd_fallback.md` 의 상태를 갱신한다.
