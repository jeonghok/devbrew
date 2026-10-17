# R5 지휘자 — 계획 2: 이음매 · 흐름 풀기 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 지휘자를 가리키지 않는 상류 · 하류 이음매를 고치고 흐름 고정을 푼다 — 에픽 넘김 줄 · 재분해 신호 · spec-review 게이트 ③ 과 기각 번호(N18) · 진행 게이트의 기타 칸 · 승인 게이트 다음 세션 줄의 「고른 실행 방식」, 그리고 손으로 따르는 지휘 절차(`references/conducting.md`)를 먼저 만든다.

**Architecture:** 바뀌는 것은 대부분 모델이 읽는 글(reference · SKILL)이고, 기계 부분은 기각 번호를 세는 `spec_review_bundle.py rejected` 하위 명령 하나다 — 기존 번호 대조 표 해석기(`check_bundle_coverage.table_rows`)를 그대로 쓰고 읽기 전용 성질을 지킨다. 손 절차는 이 로드맵의 `## 지휘 절차` 1~9 를 레포 전용 값 없이 옮기고 설계가 정한 뜻(계획 검토는 새 결정이 있을 때만 · 머지 메뉴 3번)을 싣는다. 지휘자 skill 을 가리키는 안내는 하나도 넣지 않는다(계획 3 몫 — 설계 §11).

**Tech Stack:** Python 3.9 표준 라이브러리, bash 3.2 셸 테스트(`shared/tests/assert.sh`), git.

**Spec:** `docs/superpowers/specs/2026-10-17-epic-conductor-design.md` — 이 계획은 §11 의 계획 2(이음매 · 흐름 풀기)다. 이 계획의 AC: AC31(지휘자를 가리키지 않는 변경) · AC32 · AC33 · AC34 · AC35 · AC38 · AC42(로드맵 아닌 갈래). 나머지 AC 는 계획 1 · 3 몫이다. 브랜치는 `feature/epic-conductor-seams`(계획 1 브랜치 `feature/epic-conductor` 위)이다.

## Global Constraints

- `python3` 는 3.9.6 이다 — `match` 문, 런타임 `X | Y` 타입 금지. 표준 라이브러리만 쓴다(설계 §8). `plugins/**/*.py` 에 `"python3"` 문자열을 쓰지 않는다(`shared/tests/test_python_floor.sh`). 모든 `open(` 에 `encoding="utf-8"` 를 준다.
- `spec_review_bundle.py` 는 `tests/test_roadmap_status.sh` 의 정적 읽기 전용 락(여섯 파일)에 들어 있다 — 새 import · 쓰기 호출 · subprocess 를 더하지 않는다. 이미 import 한 `check_bundle_coverage` · `roadmap_model` 만 쓴다.
- 레포 전용 값을 박지 않는다(사용자 원칙 · 설계 §9). 새 글에는 `origin/main` · 브랜치 접두 · 모델 이름 · 레포 구조 경로를 쓰지 않는다 — 기본 브랜치는 `origin/HEAD`, 브랜치 이름은 로드맵 블록, 폴더 · 테스트 명령 · 리뷰 모델은 로드맵 frontmatter 에서 읽는다고 쓴다.
- `references/conducting.md` 에는 `${CLAUDE_PLUGIN_ROOT}` 를 쓰지 않는다 — 그 토큰을 담은 reference 는 그것을 `Read` 하는 SKILL.md 줄과 치환 안내 문장을 요구한다(`shared/tests/test_plugin_root_no_cwd_fallback.sh` 축 3). 이 파일을 읽는 SKILL.md 는 계획 3 이 만든다. 같은 이유로 다른 reference 는 `references/<이름>.md` 꼴로 적지 않고 파일 이름만 적는다 — 포인터 락(`shared/tests/test_skill_reference_pointers.sh`)이 그 꼴을 이 파일의 폴더 기준으로 풀어 없는 파일로 판정한다. 셸 코드 스팬에 cwd 상대 `plugins/spec-distill/…` 인자를 쓰지 않는다(같은 락의 축 1b).
- 에픽 넘김 줄 · spec-review 다음 세션 줄에 새 꺾쇠 자리표(`<…>`)를 만들지 않는다 — 치환되지 않은 자리표가 남으면 그 줄은 노출되지 않는다(`proceed-gate.md` `## 다음 세션 명령` 규칙 5, `tests/test_epic_handoff.sh` 의 `names_ok` · `tests/test_review_handoff_order.sh` 의 `lead_only`).
- 에픽 넘김 줄에서 spec-review 를 부르는 문장보다 앞에 `spec-distill:spec-review` · `writing-plans` 글자를 쓰지 않는다 — 순서 락이 첫 출현 위치로 잰다(`tests/test_epic_handoff.sh`).
- 플러그인 문서 어디에도 「바로 진행」을 쓰지 않는다(옛 선택지 부재 락 — `tests/test_seed_at_path_handoff.sh` 코퍼스는 이 플러그인의 `.md` 전부). `proceed-gate.md` 의 가드 2 블록은 고치지 않는다(「명시적 예외」 부재 락).
- spec-review `## 게이트` 의 치환 안내 문장(「그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — …」 줄)은 한 글자도 바꾸지 않고 `Read ${CLAUDE_PLUGIN_ROOT}/references/redecompose.md` 줄과 같은 절에 둔다(축 3 은 줄 전체 일치로 잰다). `Read` 줄은 들여쓰지 않는다.
- 새 bash 펜스의 가드 줄은 기존 `roadmap-position` 펜스의 가드 줄을 글자 그대로 복사한다(같은 락의 C5 — 정본 문안 통째 일치).
- 같은 20줄(200자 이상) 블록을 두 파일에 두지 않는다(`shared/tests/test_no_new_duplication.sh`).
- 셸 테스트에서 변수 바로 뒤에 한글 · 「」 같은 비ASCII 글자가 오면 중괄호로 쓴다(`「${lit}」`) — bash 3.2 가 `$lit」` 의 바이트를 이름으로 먹어 `set -u` 에서 죽는다.
- 새 셸 테스트 파일은 `chmod +x` 뒤 `git ls-files -s <파일>` 이 `100755` 인지 확인한다. 셸 테스트는 리포 루트에서 `bash <파일>` 로 돈다. 스위트 둘을 같은 시각에 돌리지 않는다.
- 사람에게 보이는 출력(스크립트 줄)은 한국어 쉬운 말이다(`shared/style/plain-language.md`) — 내용을 먼저, 내부 용어는 괄호에.
- 고치지 않는 것: superpowers 파일, `plugins/quality-gates/`, `shared/docreview/`(R2a 예약), `skills/spec-interview/`(R10 예약), `templates/roadmap-template.md` · 이 로드맵 `roadmap.md` 의 `## 지휘 절차`(계획 3 — AC37), 지휘자 skill 을 가리키는 어떤 안내(계획 3 — §11).
- 커밋은 Conventional Commits, 설명은 한국어, `type`·`scope` 영어. 구현 커밋마다 `Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md` 트레일러를 단다. 커밋은 pathspec 으로 한다(`git commit -m … -- <경로…>`) — 같은 worktree 의 다른 staged 변경을 쓸어 담지 않는다. 커밋 뒤 `git show --stat HEAD` 의 파일 수가 그 Task 의 파일 수와 같은지 본다.
- HEAD 를 뒤로 옮기지 않는다(reset · rebase · force 금지). 계획 1 브랜치(`feature/epic-conductor`)에 새 커밋이 생겨 가져와야 하면 merge 한다.
- 버전: 이 PR 은 `plugins/spec-distill/.claude-plugin/plugin.json` 의 minor 를 하나 올린다(새 표면 — `rejected` 하위 명령 · 게이트 ③ 갈래 · 기타 칸 규칙 · `conducting.md`). 번호는 머지 직전에 origin 기본 브랜치의 값을 보고 정한다(Task 7).
- 실행 방식의 마지막 전체 리뷰에는 설계문서 `## Acceptance Criteria` 중 이 계획의 AC(위 **Spec:** 줄의 목록)를 싣고, 리뷰가 AC 마다 한 줄씩 `AC31: 구현됨 — 근거` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일(SDD 작업 폴더의 `ac-report.md`)에 적는다(Task 7).

## Review Focus

1. 번호 대조 표가 깨졌거나 `## 번호 대조` 절이 둘인 설계문서 — 승인 게이트의 기각 줄이 「없음」이 아니라 「셀 수 없음」이어야 하고, 표 절이 아예 없는 설계문서(묶음 없이 쓴 설계)면 아무 줄도 내지 않아야 한다(Task 5 테스트).
2. 로드맵 에픽이 아닌 설계문서(frontmatter 에 `roadmap:` 없음)에서 ③ 의 후속 질문은 세 갈래 그대로이고 「이 에픽 다시 설계」를 내지 않는다. 기각 번호 되돌리기(기타 칸)는 어느 문서에서나 된다(Task 4 테스트).
3. 사용자가 기타 칸에 「여기서 계속」을 적었는데 설계문서가 커밋되지 않았다 — ①/② 의 고유 단계(spec-review 의 미커밋 확인)가 먼저 돌아야 한다(Task 6 테스트가 그 문장을 잠근다).
4. 두 다음 세션 줄(에픽 넘김 줄 · spec-review 줄)에 새 문장을 더하다 꺾쇠 자리표가 생기면 그 줄은 노출되지 않고 멈춘다 — 자리표 집합이 그대로인지(Task 2 테스트).
5. 새 reference(`conducting.md`)가 부재 코퍼스 · 포인터 락 · 플러그인 루트 락에 자동으로 들어간다 — 표기 하나로 무관한 락이 빨개지거나, 아무도 가리키지 않는 고아 reference 가 된다(Task 1 테스트 + Task 7 스위트 대조).

## 계획 단계 판정

설계가 정하지 않은 것을 이 계획이 정한 자리다. 실행 중 반증되면 원장에 `Ruling:` 으로 적고 바꾼다.

- **N18 되돌리기 길은 ③ 후속 질문의 기타 칸이다.** 승인 게이트 2단계 앞 글에 기각 번호의 수와 목록을 싣고, 되돌리려면 ③ 수정 필요를 고른 뒤 이어지는 질문의 기타 칸에 번호를 적게 한다. 새 질문 · 새 선택지를 만들지 않는다 — 설계 §10 「승인 자리를 늘리지 않는다」, 그리고 로드맵 에픽의 ③ 후속 질문은 이 계획으로 선택지가 넷이 되어 질문 도구 한도에 닿는다. 되돌림은 설계문서 `## 결정 기록` 에 한 줄로 남긴다.
- **기각 번호는 스크립트가 센다** — `spec_review_bundle.py rejected` 하위 명령(설계 Files to Modify 의 계획 2 목록에 이 파일은 없다. R5 경로 예약 안이고 계획 1 이 이미 고친 파일이다). 모델이 표를 세면 개수 줄이 흔들린다. 이 수는 「경고 N개」에 더하지 않는다 — 경고가 아니라 사용자가 되돌릴 수 있는 결정이다.
- **게이트 ③ 의 로드맵 갈래.** 「인터뷰 다시 열기」 라벨은 그대로 두고(로드맵 에픽이면 재분해로 간다 — 기존 락 · 재분해 절차가 이 라벨을 쓴다) 「이 에픽 다시 설계」를 넷째 갈래로 더한다. 두 갈래 중 지적의 범위에 맞는 쪽에 모델이 「(권장)」과 이유 한 줄을 붙이고, 고르는 것은 사용자다(흐름 고정 금지). 「이 에픽 다시 설계」는 같은 세션에서 brainstorming 을 다시 돌아 **같은 경로**의 설계문서를 고친다 — 새 경로면 번호 대조가 같은 묶음의 설계문서 둘(「여러 spec」)로 경고한다.
- **진행 게이트 「여기서 계속」.** 기타 칸의 그 말은 ①/② 고유 단계(미커밋 확인 등)를 마친 뒤, 명령 두 줄 대신 다음 세션 줄의 지시를 이 세션에서 따르는 것으로 정한다. 줄 맨 앞 `@` 경로는 이 세션에서 그 파일을 읽는 것으로 갈음한다. 규칙은 정본 `proceed-gate.md` Step B 에만 두고 채택 skill 셋은 고치지 않는다 — 셋 다 게이트 진입 때 정본을 읽는다.
- **넘김 줄의 `흐름:`.** 줄의 첫 문장(brainstorming 시작)은 그대로 두고 — 기본값이자 기존 락의 머리다 — 둘째 문장에 「블록에 `흐름:` 칸이 있으면 brainstorming 대신 그 흐름 · 설계문서 대신 `산출물:`」 조건을 단다.
- **손 절차의 내용.** 로드맵 `## 지휘 절차` 1~9 를 옮기되 레포 전용 값을 빼고(`origin/main` → `origin/HEAD`, 리뷰 모델 opus → frontmatter `review_model`, 「건드린 플러그인과 `shared/`」 → 그 레포의 전체 스위트 · `test_command`), 다음은 옛 문면 대신 설계가 정한 뜻으로 쓴다:
  - 4 — 실행 방식은 writing-plans 가 권하는 방식, 계획 검토는 설계에 없던 결정이 있을 때만 기다림, 백그라운드 agent 의 머지 메뉴는 「브랜치 그대로 두기」(Push · PR 은 지휘 세션이 구현 대조 뒤). 이 로드맵 · 템플릿의 지휘 절차 4 는 계획 3(AC37)이 맞출 때까지 옛 문면이라 그동안 손 절차와 다르다.
  - 3 — 설계는 지휘 세션이 직접 하고 사용자에게 다른 세션을 열라고 하지 않는다(사용자 결정 「세션을 연다고? 너가 진행해야지 지휘자로서」). 에픽 넘김 줄은 사용자가 에픽을 따로 진행하겠다고 할 때 준다.
  - 5 — 판정이 설계를 뒤집거나 구현이 막히면 그 에픽만 멈춘다(사용자 결정 「그 에픽만 멈추고 묻기 (권장)」). 계획을 여럿으로 나눈 에픽은 `--plan` · `--impl` 에 `--acs` 를 준다(§11). `## 판정` 이 이미 있으면 그 절 아래 `### <계획 경로>` 로 잇는다 — 같은 머리가 둘이면 읽기가 형식 오류다.
  - 2 — `브랜치:` 가 여럿이면 적힌 순서가 계획 순서이고, 다음 계획의 브랜치는 앞 계획이 머지됐으면 기본 브랜치에서, 아직이면 앞 계획의 브랜치에서 만든다(설계 Deferred 9e1747a6#r3.1 의 물음에 대한 손 절차의 기본값).
- **손 절차는 「`## 손으로 따르는 절차`」 절 하나로 시작한다.** 계획 3 이 지휘 순환 걸음 절들을 그 앞에 넣어 손 절차가 끝 절이 된다(AC16). 가리킴은 `redecompose.md` 6 한 곳이다(고아 방지).
- **`redecompose.md` 2 의 `origin/main` · `feature/roadmap-<요지>` 는 고치지 않는다** — 설계 §9 가 「다른 파일에 박힌 값은 R8」로 넘겼고, 그 문구는 기존 락(`tests/test_decompose_surface.sh`)이 잠근다.
- 새 테스트 파일 `tests/test_conducting_reference.sh` 는 `# guards:` 를 선언하지 않는다(`tests/test_control_plane.sh` 와 같다) — 선언하면 qg 의 guards 양방향 락이 `--emit-scanned` 를 요구한다.

## 경로 예약 겹침(정보)

이 계획이 고치는 파일은 모두 R5 블록의 경로 예약 안이다. 겹침은 막지 않는다 — 통합 리뷰에서 맞춘다.

- `references/proceed-gate.md` — R10 의 「인터뷰 끝 게이트 둘」이 이 계약을 쓰는 `skills/spec-interview/references/finishing.md`(R10 예약)를 고친다. 기타 칸 규칙이 그 게이트에도 걸린다.
- `skills/spec-review/SKILL.md` 의 승인 게이트 — 게이트 렌더 · 라운드 규칙은 R2a 예약인 `shared/docreview/` 엔진에서 온다. R2a 가 렌더 첫 줄 · 참고 목록을 바꾸면 기각 줄의 자리(2단계 앞 글)와 맞춰 본다.
- `tests/test_review_handoff_order.sh` 는 R10 예약 파일(`finishing.md`)도 읽는다 — 이 계획은 spec-review 창만 고친다.
- `plugins/spec-distill/.claude-plugin/plugin.json` · `CHANGELOG.md` · `README.md` — R10 · R2a 도 spec-distill 을 고치면 같은 파일을 bump 한다. 번호는 머지 직전에 정한다.

---

### Task 0: 스위트 기준선

**Files:**
- Create: `.superpowers/sdd/2026-10-17-epic-conductor-2-seams/suite-names.sh` (git 이 추적하지 않는다)
- Create: `.superpowers/sdd/2026-10-17-epic-conductor-2-seams/baseline.txt`

**Interfaces:**
- Produces: `suite-names.sh` — 리포 루트에서 돌면 실패 «이름» 을 한 줄씩(`<파일>: <이름>`) 정렬해 낸다. Task 7 이 같은 스크립트로 대조한다.

- [ ] **Step 1: 스크립트를 쓴다**

```bash
#!/usr/bin/env bash
# 실패 이름 집합 — 셸 테스트의 「  ✗ 」 줄과 unittest 의 FAIL: · ERROR: 줄. ✗ 줄 없이 rc≠0 이면 그 사실을 한 줄로.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2
{
  for f in plugins/spec-distill/tests/*.sh shared/tests/*.sh; do
    out="$(bash "$f" 2>&1)"; rc=$?
    name="${f##*/}"
    printf '%s\n' "$out" | sed -n 's/^  ✗ //p' | sed "s|^|$name: |"
    if [ "$rc" -ne 0 ] && ! printf '%s\n' "$out" | grep -q '^  ✗ '; then
      echo "$name: rc $rc (✗ 줄 없음)"
    fi
  done
  for d in plugins/spec-distill/tests shared/tests; do
    python3 -m unittest discover -s "$d" -p 'test_*.py' 2>&1 | grep -E '^(FAIL|ERROR): ' | sed "s|^|$d: |"
  done
} | LC_ALL=C sort
```

- [ ] **Step 2: 기준선을 잰다(이 브랜치의 지금 HEAD)**

Run: `mkdir -p .superpowers/sdd/2026-10-17-epic-conductor-2-seams && bash .superpowers/sdd/2026-10-17-epic-conductor-2-seams/suite-names.sh > .superpowers/sdd/2026-10-17-epic-conductor-2-seams/baseline.txt; wc -l .superpowers/sdd/2026-10-17-epic-conductor-2-seams/baseline.txt`
Expected: 파일이 생기고 줄 수가 찍힌다(0 일 수도 있다). 이미 빨간 이름은 이 계획의 회귀가 아니다 — Task 7 이 이름 집합으로 대조한다.

커밋하지 않는다.

---

### Task 1: 손으로 따르는 지휘 절차 `references/conducting.md` (§11 — AC31 · AC37 의 바탕)

**Files:**
- Create: `plugins/spec-distill/references/conducting.md`
- Create: `plugins/spec-distill/tests/test_conducting_reference.sh`
- Modify: `plugins/spec-distill/references/redecompose.md` (`## 6. 올리기` 한 줄 — 가리킴)

**Interfaces:**
- Produces: `references/conducting.md` 의 절 머리 `## 손으로 따르는 절차` 와 그 아래 번호 걸음 `1.` ~ `9.`. 계획 3 은 이 절 앞에 지휘 순환 절을 더하고 이 절을 끝 절로 둔다. `redecompose.md` 6 은 「손 절차 6」을 가리킨다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_conducting_reference.sh`:

```bash
#!/usr/bin/env bash
# R5 계획 2 — 손으로 따르는 지휘 절차(`references/conducting.md`)의 걸음 · 레포 전용 값 없음 · 가리킴.
# 정적 락이다 — 지휘 세션이 이 절차를 실제로 따르는지는 재지 못한다.
# Run (리포 루트에서): bash plugins/spec-distill/tests/test_conducting_reference.sh
set -u
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$ROOT/shared/tests/assert.sh"
SD="$ROOT/plugins/spec-distill"
CD="$SD/references/conducting.md"
RED="$SD/references/redecompose.md"
T="$(mktemp -d)" || exit 1
[ -n "$T" ] && [ -d "$T" ] || exit 1
trap 'rm -rf "$T"' EXIT

[ -f "$CD" ] && ok "conducting.md 가 있다" || { no "conducting.md 가 없다"; finish; exit $?; }
assert_eq "$(grep -cxF '## 손으로 따르는 절차' "$CD" || true)" "1" "손 절차 절 머리가 정확히 하나"
MAN="$(awk '$0=="## 손으로 따르는 절차"{f=1;next} f&&/^## /{exit} f' "$CD")"
[ -n "$MAN" ] && ok "손 절차 절을 읽었다" || no "손 절차 절이 비었다 — 아래 단언이 공허하다"
assert_eq "$(printf '%s\n' "$MAN" | grep -oE '^[1-9]\. ' | tr -d '. ' | tr '\n' ' ')" "1 2 3 4 5 6 7 8 9 " "걸음 1~9 가 차례로 있다"
step() {  # step <n> — 손 절차 걸음 n 의 글(다음 번호 걸음 앞까지)
  printf '%s\n' "$MAN" | awk -v n="$1" 'index($0, n ". ")==1{f=1; print; next} f && /^[1-9]\. /{exit} f'
}
for n in 1 2 3 4 5 6 7 8 9; do
  [ -n "$(step "$n")" ] && ok "걸음 $n 을 읽었다" || no "걸음 $n 이 비었다"
done
for lit in 'control_plane.py show --tasks <로드맵>' '종료 코드 4' 'roadmap_status.py --roadmap-file <로드맵>' '기억에 기대지 않는다'; do
  assert_contains "$(step 1)" "$lit" "걸음 1(맞추기): $lit"
done
for lit in '`브랜치:` 가 여럿이면' '앞 계획이 머지됐으면 기본 브랜치에서' '한 번에 한 에픽씩'; do
  assert_contains "$(step 2)" "$lit" "걸음 2(에픽과 브랜치): $lit"
done
for lit in 'AskUserQuestion' '거절되면 설계 흐름으로 간다' '`epic-handoff.md` 의 에픽 넘김 줄' '다른 세션을 열라고 하지 않는다' '`--bundle <묶음>`'; do
  assert_contains "$(step 3)" "$lit" "걸음 3(흐름과 설계): $lit"
done
for lit in 'writing-plans 가 권하는 방식' '설계에 없던 결정' '답 전에는 그 에픽의 구현을 보내지 않으며' '「브랜치 그대로 두기」'; do
  assert_contains "$(step 4)" "$lit" "걸음 4(설계가 정한 뜻): $lit"
done
assert_not_contains "$(step 4)" 'Push 후 PR' "걸음 4: 옛 미리 받은 답(Push 후 PR)이 없다(양성 짝: 「브랜치 그대로 두기」)"
assert_not_contains "$(step 4)" '기다리지 않고' "걸음 4: 계획 검토를 늘 안 기다리는 옛 문면이 없다(양성 짝: 설계에 없던 결정)"
for lit in 'check_bundle_coverage.py --plan' '--acs' '그 에픽만 멈추고' 'check_bundle_coverage.py --impl' '`### <계획 경로>`'; do
  assert_contains "$(step 5)" "$lit" "걸음 5(계획 · 구현): $lit"
done
assert_contains "$(step 6)" '`redecompose.md`' "걸음 6(머지 뒤): 재분해 절차를 가리킨다"
assert_contains "$(step 7)" 'Spec: <에픽 설계문서 레포 상대경로>' "걸음 7: Spec 트레일러"
for lit in '실패 «이름»' '`test_command`' '`review_model`' '같은 시각에 돌리지 않는다' '`## 통합 리뷰 인계`' '**리뷰 뒤 반영.**' '머지 직전' '스위트 대조 없음'; do
  assert_contains "$(step 8)" "$lit" "걸음 8(머지 전 확인): $lit"
done
for lit in '끝에서 끝' '브랜치는 지우지 않는다'; do
  assert_contains "$(step 9)" "$lit" "걸음 9(끝): $lit"
done

# 레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴 — 줄마다 낸다.
banned() {
  python3 -I - "$1" <<'PY'
import re, sys
text = open(sys.argv[1], encoding="utf-8").read()
pats = [r"origin/main", r"(?<![A-Za-z])main(?![A-Za-z])", r"(?<![A-Za-z])opus(?![A-Za-z])",
        r"(?<![A-Za-z])fable(?![A-Za-z])", r"plugins/spec-distill", r"docs/superpowers", r"feature/",
        r"\.superpowers/", r"DEVBREW_", r"\$\{CLAUDE_PLUGIN_ROOT\}", r"references/[A-Za-z0-9_.-]+\.md"]
for i, line in enumerate(text.splitlines(), 1):
    for p in pats:
        if re.search(p, line):
            print("%d: %s — %s" % (i, p, line.strip()[:80]))
PY
}
assert_eq "$(banned "$CD")" "" "레포 전용 값 · 루트 토큰 · references/ 꼴 가리킴이 없다"
for lit in 'origin/main' 'review_model: opus' 'python3 plugins/spec-distill/scripts/x.py' '${CLAUDE_PLUGIN_ROOT}/scripts' \
           'references/epic-handoff.md' 'feature/roadmap-x' 'main 에서 만든다' '.superpowers/sdd/x'; do
  { cat "$CD"; printf '%s\n' "$lit"; } > "$T/mut.md"
  [ -n "$(banned "$T/mut.md")" ] && ok "양성 대조: 「${lit}」 를 넣으면 잡는다" || no "양성 대조: 「${lit}」 를 못 잡는다"
done

# 가리키는 skill 은 실재한다(아직 없는 skill 을 가리키는 릴리스 금지 — 설계 §11).
n=0
for s in $(grep -ohE 'spec-distill:[a-z][a-z-]*' "$CD" "$SD/references/epic-handoff.md" "$RED" "$SD/references/proceed-gate.md" | sed 's/^spec-distill://' | LC_ALL=C sort -u); do
  n=$((n+1))
  [ -f "$SD/skills/$s/SKILL.md" ] && ok "가리키는 skill 이 있다: $s" || no "없는 skill 을 가리킨다: $s"
done
[ "$n" -ge 1 ] && ok "skill 이름을 ${n}개 읽었다" || no "skill 이름을 하나도 못 읽었다 — 위 검사가 공허하다"

# 고아 방지 — 재분해 6 이 손 절차를 가리킨다.
assert_file_grep "$RED" '\$\{CLAUDE_PLUGIN_ROOT\}/references/conducting\.md' "재분해 6 이 손 절차를 가리킨다"
finish
```

Run: `chmod +x plugins/spec-distill/tests/test_conducting_reference.sh`

- [ ] **Step 2: 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_conducting_reference.sh`
Expected: `✗ conducting.md 가 없다` 로 끝나고 종료 코드가 0 이 아니다.

- [ ] **Step 3: `references/conducting.md` 를 쓴다**

````markdown
# 지휘 — 로드맵의 에픽을 끝까지 이끄는 절차

## 손으로 따르는 절차

로드맵 하나를 따라 에픽들을 지휘하는 세션의 절차다. 걸음마다 기본값이다 — 일의 모양이 다르면 다르게 하고, 무엇을 왜 다르게 했는지 그 에픽 설계문서에(에픽에 매이지 않은 판단은 다음 로드맵 수정 PR 본문에) 적는다. 정석 흐름(brainstorming → 계획 → 구현)의 뜻은 지킨다.

- `<SD>` 는 spec-distill 플러그인 폴더의 절대경로, `<로드맵>` 은 로드맵 파일의 레포 루트 기준 경로다. `<SD>` 를 모르면 추측하지 말고(cwd 포함) 멈춰 사용자에게 묻는다.
- 레포마다 다른 값은 박지 않고 읽는다 — 기본 브랜치는 `origin/HEAD`, 브랜치 이름은 로드맵 블록의 `브랜치:`, 설계문서 · 계획 폴더 · 테스트 명령 · 리뷰 모델은 로드맵 frontmatter 의 `specs_dir` · `plans_dir` · `test_command` · `review_model` 이다. 없으면 각각 superpowers 기본 폴더 · 레포 파일에서 찾은 러너 · 세션 모델을 쓰고, 한 번 물어 정한 값은 다음 로드맵 수정 PR 에 frontmatter 로 올린다.
- 각 칸의 주인과 갱신 길은 같은 폴더의 `roadmap-ontology.md` 에 있다.

1. **맞추기.** `git fetch origin` 뒤 `python3 <SD>/scripts/control_plane.py show --tasks <로드맵>` 을 돌려 작업 목록을 결과에 맞춘다. 줄마다 `<제목><탭><작업 상태>` 이고 에픽 하나에 작업 하나다 — 제목은 그대로 쓰고, 상태가 `keep`(알 수 없음)이면 작업 상태는 두고 제목만 바꾼다. 종료 코드 3 이면 작업 목록을 바꾸지 않고 표준 오류의 「검사 불가」 사유를 사용자에게 그대로 보인다 — 일부 단계가 보여도 믿지 않는다. 종료 코드 4(로드맵이 아직 기본 브랜치에 없다 — 방금 나눠 머지 전)면 `python3 <SD>/scripts/roadmap_status.py --roadmap-file <로드맵>` 으로 대신 계산하고, 대기 · 준비는 시작 전, 설계 중 · 계획 · 구현 중 · 구현 끝 · PR · 일부 머지는 진행 중, 머지됨 · 끝남은 완료로 맞춘다. 살아 있는 agent 를 확인한다 — 끝났는데 보고하지 않은 것은 거두고 놀고 있는 것은 내린다. 압축 · 새 세션 뒤에도 여기서 시작한다 — 무엇이 끝났는지 기억에 기대지 않는다.
2. **에픽과 브랜치.** 준비 단계 에픽을 고른다. 블록의 `브랜치:` 이름으로 기본 브랜치에서 브랜치와 worktree 를 먼저 만들고(`superpowers:using-git-worktrees`), 그 에픽의 설계문서 · 계획은 모두 그 브랜치에 커밋한다. `브랜치:` 가 여럿이면 적힌 순서가 그 에픽 설계문서가 나눈 계획의 순서다 — 다음 계획의 브랜치는 앞 계획이 머지됐으면 기본 브랜치에서, 아직이면 앞 계획의 브랜치에서 만든다. 사람에게 묻는 단계(brainstorming 의 질문 · 절별 승인 · spec 승인)는 사람이 보는 세션에서 한 번에 한 에픽씩, 의존 사슬의 앞쪽부터 한다 — 백그라운드 agent 에는 질문 도구가 없다. spec 승인은 사용자가 에픽마다 한다.
3. **흐름과 설계.** 에픽의 흐름은 기본이 설계 흐름(brainstorming → spec-review → 계획 → 구현)이다. 조사 · 측정 · 결정처럼 맞지 않는 에픽은 맞는 흐름을 고르되, 시작하기 전에 고른 흐름 · 이유 · 산출물을 보이고 `AskUserQuestion` 으로 승인받는다 — 설계 흐름의 spec 승인을 대신하는 자리이고, 거절되면 설계 흐름으로 간다. 승인된 흐름 · 산출물은 로드맵 블록의 `흐름:` · `산출물:` 칸에 같은 폴더 `redecompose.md` 의 재분해 절차로 적는다. 설계는 지휘 세션이 직접 한다 — brainstorming 의 입력과 지시는 같은 폴더 `epic-handoff.md` 의 에픽 넘김 줄이 싣는 것(묶음 첨부 · 번호째 읽기 · 번호 대조 표 · frontmatter · AC 번호 · 있는 것 검토 · 상류 · 하류 연계 · 레포 전용 값)과 같다. 설계문서를 에픽 브랜치에 커밋한 뒤 그 경로 뒤에 `--bundle <묶음>`(설계문서 frontmatter `source_interview` 와 같은 레포 상대경로)을 붙여 `/spec-distill:spec-review` 를 부른다 — 그 값이 다르거나 읽을 수 없으면 리뷰하지 않고 끝나고, 같으면 진입에서 번호 대조를 보인 뒤 계속한다(빠진 번호 · 얕은 답 · 받드는 에픽 없는 발화 · 검사 불가는 막지 않고 승인 게이트의 「경고 N개」에 더해진다). 사용자에게 다른 세션을 열라고 하지 않는다 — 사용자가 에픽을 자기 세션에서 따로 진행하겠다고 하면 그 세션의 첫 줄로 에픽 넘김 줄(자리표를 채우고, 줄 안의 플러그인 루트 변수는 그 에픽 worktree 의 spec-distill 플러그인 폴더로)을 준다. spec 이 승인되면 지휘 세션은 계획 · 구현으로 들어가지 않고 그 에픽 worktree 의 백그라운드 agent 에 계획을 보낸 뒤 다음 에픽의 설계로 간다.
4. **superpowers 가 묻는 자리.** 사람이 보는 세션에서 만난 자리는 사용자가 그 자리에서 답한다. 백그라운드 agent 가 만나는 자리는 보낼 때 적어 준 답으로 간다. 실행 방식은 writing-plans 가 권하는 방식이다. 계획 검토는 지휘 세션이 계획을 읽고 설계에 없던 결정(범위 · 인터페이스 · 파일 배치 등)이 있는지 가린다 — 있으면 그 결정들을 배경과 함께 사용자에게 묻고 답 전에는 그 에픽의 구현을 보내지 않으며, 없으면 계획 경로만 보이고 구현을 보낸다. 가른 결과와 이유는 그 에픽 설계문서에 적는다. 머지 메뉴는 「브랜치 그대로 두기」다 — Push 와 PR 은 지휘 세션이 구현 대조(5) 뒤에 한다. 보낼 때 기준 브랜치도 적어 준다. 사용자가 그 자리에서 다르게 말하면 그 말을 따른다.
5. **계획 · 구현.** 계획 agent 는 writing-plans 로 계획을 쓰고 커밋한 뒤 `python3 <SD>/scripts/check_bundle_coverage.py --plan <설계문서> <계획>` 을 돌려 계획에 없는 AC 를 계획에 더한다 — 설계가 계획을 여럿으로 나눴으면 `--acs` 뒤에 그 계획이 맡은 AC 목록을 준다. 구현은 에픽마다 그 worktree 의 백그라운드 agent 가 하고, 그동안 다음 에픽의 설계를 진행한다. 의존 · 같은 파일 겹침이 없는 에픽은 동시에 보내되 띄우기 전에 규모를 알린다. 고른 실행 방식의 마지막 전체 리뷰가 AC 마다 한 줄(`AC1: 구현됨 — 근거` 꼴, 판정은 구현됨 · 미룸 · 빠짐)로 보고하게 하고, agent 의 마지막 보고에 판정 목록 전체와 그 AC 보고 내용 전체를 싣게 한다 — 실행 방식이 작업 폴더를 지울 수 있다. 판정 목록은 멈추지 않고 그대로 사용자에게 보인다. 다만 판정이 승인된 설계의 수용 기준 · 의도를 바꾸거나 구현이 막히면 그 에픽만 멈추고 배경과 함께 묻는다 — 다른 에픽은 계속한다. 돌아오면 AC 보고를 git 이 추적하지 않는 파일에 두고, 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린 뒤 `python3 <SD>/scripts/check_bundle_coverage.py --impl <설계문서> <그 보고 파일>`(계획이 여럿이면 같은 `--acs`)을 돌려 경고를 사용자에게 보인다. 그다음 설계문서에 `## 판정` 절(판정 목록 그대로 — 절이 이미 있으면 그 아래 `### <계획 경로>` 로 잇는다)과 `## 구현 대조 — <계획 경로>` 절(대조 첫 줄 · AC 판정 수)을 에픽 브랜치에 커밋하고 Push · PR 을 연다. `gh` 가 없으면 PR 을 열 명령을 사용자에게 준다.
6. **머지 뒤.** 에픽이 머지될 때마다 남은 에픽을 재평가하고, 바뀔 때만 같은 폴더 `redecompose.md` 의 재분해 절차로 사용자 승인 뒤 로드맵 수정 PR 을 올린다. 열린 에픽 브랜치에는 기본 브랜치를 merge 하고 대조(8)를 다시 돈다 — 그 브랜치에서 agent 가 일하는 중이면 직접 merge 하지 않고 돌아올 때까지 기다린다. merge 가 충돌하면 그 에픽만 멈추고 알린다. 받는 에픽이 머지되면 넘긴 항목이 처리됐는지 그 설계문서의 번호 대조 · AC 보고로 확인한다. 머지는 사용자가 한다.
7. **`Spec:` 트레일러.** 구현 커밋에는 `Spec: <에픽 설계문서 레포 상대경로>` 트레일러를 단다 — 보내는 글에 적어 준다.
8. **머지 전 확인.** PR 마다 아래 셋을 한다(문서만 고친 PR 도 — 모델이 읽는 skill · reference · 템플릿 · 리뷰어 프로필은 문서로 치지 않는다). 하나라도 건너뛰면 무엇을 왜 건너뛰었는지 적는다.
   - **스위트 대조.** 그 시점 기본 브랜치에 이 브랜치를 merge 한 별도 worktree(합친 사본)와 기본 브랜치 사본에서 그 레포의 스위트를 돌려 실패 «이름» 을 양방향으로 대조한다 — 이 브랜치에만 있는 실패와 기본 브랜치에만 있는 실패. 무엇을 돌리나: 로드맵 frontmatter `test_command` 가 있으면 그것, 없으면 레포 파일에서 찾은 러너(pytest · unittest · 셸 · node 등)의 전체 스위트다. 스위트가 너무 오래 걸리는 레포에서만 범위를 좁히고 이유를 적는다. 이름은 러너 출력에서 뽑는다(pytest `-rf` 의 `FAILED` 줄 · unittest 의 `FAIL:` · `ERROR:` 줄 · node `--test-reporter=tap` 의 `not ok` 줄 · 셸 테스트의 실패 표시 줄) — 뽑을 수 없으면 「이름 대조 불가 — 파일 단위만」 이라고 적는다. 사본을 만들기 전에 남은 merge 를 abort 하고, `git fetch` 뒤 대조할 브랜치의 SHA 를 한 줄로 남긴다. 스위트 둘을 같은 시각에 돌리지 않는다(잠금 — 예: `mkdir` 잠금과 종료 시 해제) — 공유 임시 자원 경합이 거짓 실패를 낸다. 실행 중인 스크립트 파일은 고치지 않는다. 기본 브랜치가 움직이면 다시 돈다. 테스트가 없는 레포면 「스위트 대조 없음」을 적고 통합 리뷰만 한다.
   - **통합 리뷰.** 쓰기 도구가 없는 리뷰어를 로드맵 frontmatter `review_model`(없으면 세션 모델)로 부른다(`superpowers:requesting-code-review`) — 하나로 충분하면 하나, 이음매가 여럿이면 여럿을 동시에. 합친 사본 · 이 PR 의 diff · 아직 열린 다른 에픽의 기본 브랜치 대비 diff · 앞선 통합 리뷰가 이 PR 에 넘긴 항목을 주고 에픽 사이 이음매를 묻는다: 옮겨진 이름의 import, 같은 파일을 고친 에픽들의 순서와 문구, 상태 · 경로 규약, 줄 상한 · 버전 같은 합계 제약, 테스트가 못 잡는 되살아난 옛 문구, 리뷰어 프로필의 규칙 제거 · 기준 완화(사용자 결정이 있는지). 충돌은 실제 merge 없이 `git merge-tree` 로 미리 본다. 지적은 「이 PR 이 머지 전 고침」과 「뒤에 머지되는 에픽이 고침」으로 나눠 이 PR 본문의 `## 통합 리뷰 인계` 절에 담당 에픽과 함께 적는다. 뒤 에픽의 통합 리뷰에는 앞서 머지된 PR 과 아직 열린 PR 의 그 절을 모아 주고(블록의 `브랜치:` 마다 `gh pr list --state all --head <브랜치>`) 실제로 고쳐졌는지 확인시킨다. `gh` 가 없거나 GitHub 레포가 아니면 PR 본문 대신 설계문서 `## 미룸` 표와 `## 지휘 기록` 절에 적고 그 사실을 알린다.
   - **리뷰 뒤 반영.** 리뷰 지적을 고친 수정은 같은 리뷰어로 좁게 한 번 다시 본다(`superpowers:receiving-code-review`). 그 뒤 동작을 바꾸지 않는 수정(문구 · 주석 · 번호 — 단 모델이 읽는 파일의 문구 수정은 동작을 바꾸는 수정이다)은 다시 돌지 않고 PR 본문에 「리뷰 뒤 반영(리뷰 라운드를 거치지 않았다)」으로 적는다. 동작을 바꾸는 수정, 그리고 락 · 보안 경계 · 리뷰어 프로필을 바꾼 수정은 매번 좁은 재리뷰를 한 번 받는다. 좁은 재리뷰는 첫 리뷰 뒤부터 세어 PR 하나에 두 번까지다 — 첫 재리뷰를 보내기 전에 멈출 조건(그 뒤에도 남는 지적을 잔여로 공시하고 넘길 곳)을 정해 PR 본문에 적는다. 두 번째 재리뷰 뒤 남는 지적은 고치지 않고 멈출 조건대로 넘기거나, 고치려면 사용자에게 묻는다.
   끝으로 `superpowers:verification-before-completion` 을 따른다. 릴리스 번호는 머지 직전에 정한다 — 먼저 머지되는 쪽이 낮은 번호다. 머지 명령 줄만 준비하고 머지는 사용자가 한다.
9. **끝.** 로드맵의 에픽이 모두 머지되면 처음부터 끝까지 실제 명령으로 걸어 본다(끝에서 끝 확인) — 기본 경로(인터뷰 → 분해 → 에픽 설계 → spec-review → 계획 · 구현 대조 → 작업 목록 · 상태줄)와, 설계 흐름이 아닌 에픽(조사 · 측정 · 결정)이 있으면 그 경로도 한 흐름으로 이어지는지 본다. 넘긴 항목이 모두 처리됐는지 확인하고, 지휘 세션과 agent 가 만든 worktree · 사본 · 잠금 · 임시 폴더를 정리한다 — 브랜치는 지우지 않는다. 지우기 전에 수정 · 추적 안 된 파일이 있으면 보이고 묻는다. 끊긴 곳은 사용자에게 보이고 로드맵 수정이나 다음 일로 넘긴다.

**/compact.** 에픽 하나를 넘긴 직후처럼 끊기 좋은 자리에서 맥락이 무거우면, 기록을 커밋한 뒤 `/compact` 를 권한다. 압축은 사용자가 하고, 압축 뒤에는 1 부터 다시 한다.
````

(바깥 네 백틱 펜스는 이 계획 안의 구분이다 — 파일에는 `# 지휘 — …` 줄부터 마지막 `**/compact.** …` 줄까지만 쓴다.)

- [ ] **Step 4: `redecompose.md` 6 을 손 절차로 가리킨다**

`plugins/spec-distill/references/redecompose.md` 에서 이 줄을

```
로드맵 수정은 2 에서 만든 `feature/roadmap-<요지>` 브랜치에서 PR 로 올린다(지휘 절차 6). 머지는 사용자가 한다.
```

이 줄로 바꾼다:

```
로드맵 수정은 2 에서 만든 `feature/roadmap-<요지>` 브랜치에서 PR 로 올린다(`${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 의 손 절차 6). 머지는 사용자가 한다.
```

- [ ] **Step 5: 통과하는지 본다**

Run: `bash plugins/spec-distill/tests/test_conducting_reference.sh`
Expected: 마지막 줄이 실패 0 이고 종료 코드 0.

Run: `bash shared/tests/test_skill_reference_pointers.sh; bash shared/tests/test_plugin_root_no_cwd_fallback.sh; bash plugins/spec-distill/tests/test_no_wall_clock.sh; bash plugins/spec-distill/tests/test_decompose_surface.sh`
Expected: 넷 다 종료 코드 0(Task 0 기준선에서 이미 빨갛던 이름만 남는다). 포인터 락이 `conducting.md` 를 고아로 내면 Step 4 의 줄 꼴을 확인한다.

- [ ] **Step 6: 실행 비트를 확인하고 커밋한다**

```bash
git add plugins/spec-distill/references/conducting.md plugins/spec-distill/tests/test_conducting_reference.sh
git ls-files -s plugins/spec-distill/tests/test_conducting_reference.sh   # 100755 여야 한다
git commit -m "docs(spec-distill): 손으로 따르는 지휘 절차를 reference 로

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/references/conducting.md plugins/spec-distill/tests/test_conducting_reference.sh plugins/spec-distill/references/redecompose.md
git show --stat HEAD   # 파일 셋
```

---

### Task 2: 에픽 넘김 줄 · 승인 게이트 다음 세션 줄의 흐름 풀기 (AC31 · AC42)

**Files:**
- Modify: `plugins/spec-distill/references/epic-handoff.md:7` (넘김 줄)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (`**다음 세션 줄 — ①/② 공통**` 아래 인용 줄)
- Test: `plugins/spec-distill/tests/test_epic_handoff.sh` · `plugins/spec-distill/tests/test_review_handoff_order.sh`

**Interfaces:**
- Consumes: 없음(글만).
- Produces: 넘김 줄의 새 문구 「고른 실행 방식의 마지막 전체 리뷰」 · 「묶음을 다시 나눌 근거가 보이면」 — Task 3 의 재분해 신호 목록이 「에픽 설계 세션」 항목으로 이 문구를 받는다. 자리표 집합은 그대로 넷(`bundle-abs` · `bundle-rel` · `roadmap-rel` · `epic-id`).

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_epic_handoff.sh` 의 마지막 `finish` 줄 바로 앞에 더한다:

```bash
# R5 계획 2 AC31 — 흐름을 고정하지 않는다 · 재분해 보고 · 고른 실행 방식 · 있는 것 검토 · 연계 · 레포 전용 값
for n in '흐름: 칸이 있으면 brainstorming 대신 그 칸의 흐름' '설계문서 대신 산출물: 칸의 파일을 낸다' \
         '묶음을 다시 나눌 근거가 보이면' '${CLAUDE_PLUGIN_ROOT}/references/redecompose.md' \
         '고른 실행 방식의 마지막 전체 리뷰(조사 에픽은 산출물의 AC 대조)' \
         '## 있는 것 검토 절' '사용자가 승인한 뒤에만' '## 상류 · 하류 연계 절' '레포 전용 값은 박지 말고'; do
  assert_contains "$ONE" "$n" "AC31: 에픽 넘김 줄에 「${n}」"
done
assert_not_contains "$ONE" 'SDD 의 마지막 전체 리뷰' "AC31: 실행 방식을 SDD 로 고정하지 않는다(양성 짝: 고른 실행 방식)"
assert_not_contains "$ONE" '묶음을 다시 나누지 않는다' "AC31: 나누지 말라는 금지 대신 재분해 보고(양성 짝: 근거가 보이면)"
```

`plugins/spec-distill/tests/test_review_handoff_order.sh` 에서 `assert_eq "$(lead_only "$RSL")" "ok" …` 줄 바로 앞에 더한다:

```bash
    assert_contains "$RSL" '고른 실행 방식의 마지막 전체 리뷰' "AC42: 승인 게이트 다음 세션 줄이 고른 실행 방식의 마지막 전체 리뷰를 말한다"
    assert_not_contains "$RSL" 'SDD 의 마지막 전체 리뷰' "AC42: 다음 세션 줄이 SDD 로 고정하지 않는다(양성 짝: 위 줄)"
```

- [ ] **Step 2: 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_epic_handoff.sh; bash plugins/spec-distill/tests/test_review_handoff_order.sh`
Expected: 첫 파일에 `✗ AC31: …` 줄들, 둘째 파일에 `✗ AC42: …` 두 줄. 다른 실패는 없다.

- [ ] **Step 3: 넘김 줄을 고친다**

`plugins/spec-distill/references/epic-handoff.md` 7 줄 전체를 이 한 줄로 바꾼다:

```
> `@<bundle-abs> 이 에픽 묶음으로 Skill superpowers:brainstorming 을 시작하라. 이 묶음은 승인된 로드맵 <roadmap-rel> 의 에픽 <epic-id> 다 — 로드맵의 이 에픽 블록에 흐름: 칸이 있으면 brainstorming 대신 그 칸의 흐름(승인받은 그대로)을 따르고 설계문서 대신 산출물: 칸의 파일을 낸다(아래 설계문서 지시는 그 파일에 적용하고, 그 흐름에 없는 단계는 그 흐름이 정한 대로 한다). 이 에픽의 몫만 설계한다 — 묶음을 다시 나눌 근거가 보이면 스스로 나누지 말고 그 근거를 재분해 신호로 사용자에게 보고한다(${CLAUDE_PLUGIN_ROOT}/references/redecompose.md). confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 묶음의 모든 번호(확정 · 열린 질문 · 조사 · 위험 · 발화)를 번호째 설계의 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 묶음을 다시 읽는다. 설계문서에 ## 번호 대조 표(칸: 번호 · 반영/기각 · 자리 또는 이유)를 두어 묶음 ids 의 모든 번호를 싣고, 다른 에픽으로 넘기는 번호는 기각 칸에 그 에픽 번호를 적는다. 설계문서 frontmatter source_interview 에 <bundle-rel> 을, roadmap 에 <roadmap-rel> 을 적는다. 설계문서의 수용 기준은 ## Acceptance Criteria 아래 AC1 · AC2 … 처럼 번호를 단다. 설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로 뒤에 --bundle <bundle-rel> 를 붙여 Skill spec-distill:spec-review 를 부른다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. writing-plans 가 계획을 쓴 뒤 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --plan 에 설계문서와 계획 경로를 넘겨 돌리고, 계획에 없는 AC 는 계획에 더한다. 고른 실행 방식의 마지막 전체 리뷰(조사 에픽은 산출물의 AC 대조)에 설계문서 ## Acceptance Criteria 의 AC 목록을 싣고, 리뷰가 AC 마다 한 줄씩 AC1: 구현됨 — 근거 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 해 그 보고를 git 이 추적하지 않는 파일에 적는다. 미룸 · 빠짐과 리뷰 후속으로 미룬 것은 설계문서 ## 미룸 표(항목 · 이유 · 받는 곳)에 올리고, PR 을 만들기 전에 python3 ${CLAUDE_PLUGIN_ROOT}/scripts/check_bundle_coverage.py --impl 에 설계문서와 보고 파일 경로를 넘겨 돌려 경고를 사용자에게 보인다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`
```

- [ ] **Step 4: 승인 게이트 다음 세션 줄을 고친다**

`plugins/spec-distill/skills/spec-review/SKILL.md` 의 `**다음 세션 줄 — ①/② 공통**` 아래 인용 줄에서 `SDD 의 마지막 전체 리뷰에 이 설계문서` 를 `고른 실행 방식의 마지막 전체 리뷰에 이 설계문서` 로 바꾼다(그 줄의 다른 글자는 그대로). 로드맵 에픽이면 지휘자로 돌아가라는 갈래는 계획 3 몫이라 넣지 않는다.

- [ ] **Step 5: 통과하는지 본다**

Run: `bash plugins/spec-distill/tests/test_epic_handoff.sh; bash plugins/spec-distill/tests/test_review_handoff_order.sh; bash plugins/spec-distill/tests/test_decompose_surface.sh; bash plugins/spec-distill/tests/test_next_session_command.sh`
Expected: 넷 다 종료 코드 0. `test_epic_handoff.sh` 의 「자리표는 넷」 · 「순서: brainstorming → spec-review → writing-plans」 가 통과해야 한다 — 실패하면 둘째 문장에 `spec-distill:spec-review` · `writing-plans` 글자나 새 꺾쇠가 들어갔는지 본다.

- [ ] **Step 6: 커밋**

```bash
git commit -m "feat(spec-distill): 에픽 넘김 줄과 승인 게이트 줄이 흐름 · 실행 방식을 고정하지 않는다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/tests/test_epic_handoff.sh plugins/spec-distill/tests/test_review_handoff_order.sh
git show --stat HEAD   # 파일 넷
```

---

### Task 3: 재분해 신호는 열린 목록 · 이력 설명은 새 꼴 (AC32)

**Files:**
- Modify: `plugins/spec-distill/references/redecompose.md` (`## 1. 신호` 절 · `## 5. 적용` 의 펜스 자리표와 첫 불릿)
- Test: `plugins/spec-distill/tests/test_decompose_surface.sh`

**Interfaces:**
- Consumes: Task 2 의 넘김 줄 문구(「묶음을 다시 나눌 근거가 보이면 … 재분해 신호로 사용자에게 보고한다」), 계획 1 의 `roadmap_render.history_entry` 가 쓰는 꼴(`### <날짜> · <사유>` · `- 바뀜: … 「승인」` · `- 원문:` + `  - 「…」`, `--change` 가 사유, `--approval` 이 사용자 말 하나씩).
- Produces: 신호 목록의 「spec-review 게이트 ③」 항목 문구 — Task 4 의 게이트 ③ 갈래와 같은 이름(「이 에픽 다시 설계」)을 쓴다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_decompose_surface.sh` 에서 `# ── AC11 — 재결정 규약 한 줄` 줄 바로 앞에 더한다:

```bash
# ── R5 계획 2 AC32 — 재분해 신호는 열린 목록 · 이력 설명은 새 꼴 ──────────────────
SIG="$(win "$RED" '## 1. 신호' '## ')"
for lit in '목록은 닫혀 있지 않다' '에픽 설계 세션' '계획 · 구현 세션' '경계를 스스로 고치지 않고 보고한다' \
           '「이 에픽 다시 설계」 로 가고 이 절차로 오지 않는다'; do
  has "$SIG" "$lit" "AC32: 재분해 신호 — $lit"
done
case "$SIG" in *'신호는 셋이다'*) no "AC32: 닫힌 「셋」 목록 문장이 남았다" ;; *) ok "AC32: 닫힌 「셋」 목록 문장이 없다(양성 짝: 열린 목록)" ;; esac
APPLY="$(win "$RED" '## 5. 적용' '## ')"
for lit in '`### <날짜> · <사유>`' '`- 바뀜:`' '`- 원문:`' '원문 칸에는 사용자 말만 둔다' \
           '--change "<사유 한 줄>"' '--approval "<사용자 말 그대로>"' '사용자 말이 여럿이면 `--approval` 을 말마다 하나씩'; do
  has "$APPLY" "$lit" "재분해 이력 새 꼴: $lit"
done
case "$APPLY" in *'재분해 이력에 한 줄('*) no "재분해 이력: 옛 한 줄 꼴 설명이 남았다" ;; *) ok "재분해 이력: 옛 한 줄 꼴 설명이 없다(양성 짝: 새 꼴)" ;; esac
UP="$(win "$RED" '## 6. 올리기' '## ')"
has "$UP" '`${CLAUDE_PLUGIN_ROOT}/references/conducting.md` 의 손 절차 6' "재분해 6: 손 절차를 가리킨다"
case "$UP" in *'(지휘 절차 6)'*) no "재분해 6: 로드맵의 지휘 절차를 가리키는 옛 꼬리가 남았다" ;; *) ok "재분해 6: 옛 꼬리가 없다" ;; esac
```

- [ ] **Step 2: 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_decompose_surface.sh`
Expected: `✗ AC32: …` 줄들과 `✗ 재분해 이력 새 꼴: …` 줄들. 재분해 6 두 줄은 Task 1 에서 이미 통과한다.

- [ ] **Step 3: `## 1. 신호` 절을 고친다**

`plugins/spec-distill/references/redecompose.md` 에서 이 덩어리를

```
이 절차로 오는 신호는 셋이다. 신호를 잡는 일은 이 절차의 몫이 아니다.

- 번호 대조 경고 — 빠짐 · 축소 · 여러 spec(`roadmap_status.py` · 번호 대조 검사가 낸다).
- spec-review 게이트 ③ — 로드맵 에픽의 설계문서에서 「인터뷰 다시 열기」 갈래를 골랐을 때.
- 지휘 세션 — 에픽이 머지될 때 남은 에픽을 재평가하다 경계를 바꿔야 한다고 볼 때.
```

이 덩어리로 바꾼다:

```
에픽 경계가 틀렸다는 근거면 어디서 왔든 이 절차로 온다. 아래는 지금 알려진 자리이고, 목록은 닫혀 있지 않다 — 다른 자리에서 같은 근거가 보이면 그 근거와 출처를 적어 이 절차로 온다. 신호를 잡는 일은 이 절차의 몫이 아니다. 신호를 낸 자리는 경계를 스스로 고치지 않고 보고한다.

- 번호 대조 경고 — 빠짐 · 축소 · 여러 spec(`roadmap_status.py` · 번호 대조 검사가 낸다).
- spec-review 게이트 ③ — 로드맵 에픽의 설계문서에서 「인터뷰 다시 열기」 갈래를 골랐을 때. 지적이 그 에픽 안에서 끝나면 「이 에픽 다시 설계」 로 가고 이 절차로 오지 않는다.
- 에픽 설계 세션 — 묶음을 다시 나눌 근거를 봤을 때(에픽 넘김 줄이 나누지 말고 보고하라고 한다).
- 계획 · 구현 세션 — 계획이나 실행 방식이 이 에픽의 몫이 다른 에픽과 겹치거나 빠졌다는 근거를 찾았을 때. 예: 다른 에픽이 예약한 파일을 고쳐야만 AC 를 채운다, 이 에픽의 AC 가 아직 머지되지 않은 앞 에픽의 변경에 기댄다.
- 지휘 세션 — 에픽이 머지될 때 남은 에픽을 재평가하다 경계를 바꿔야 한다고 볼 때.
```

- [ ] **Step 4: `## 5. 적용` 의 펜스 자리표와 이력 설명을 고친다**

같은 파일 `## 5. 적용` 펜스에서 이 줄을

```
  --date "<YYYY-MM-DD>" --change "<바뀐 것 한 줄>" --approval "<승인 원문>" || u_rc=$?
```

이 줄로 바꾼다:

```
  --date "<YYYY-MM-DD>" --change "<사유 한 줄>" --approval "<사용자 말 그대로>" || u_rc=$?
```

펜스 바로 아래 첫 불릿을

```
- 바뀐 블록과 그 묶음만 다시 쓰고, 재분해 이력에 한 줄(날짜 · 바뀐 것 · 바뀜/새/사라짐 번호 · 승인 원문)을 더한다.
```

이 불릿으로 바꾼다:

```
- 바뀐 블록과 그 묶음만 다시 쓰고, 재분해 이력에 항목 하나를 더한다 — 머리 `### <날짜> · <사유>`(사유는 `--change`), 그 아래 `- 바뀜:`(생성기가 바뀐 에픽 · 새 에픽 · 사라진 에픽 번호를 적고 끝에 승인 인용 「…」 을 단다)과 `- 원문:`(하위 항목 한 줄에 사용자 말 하나, 「…」 그대로). 원문 칸에는 사용자 말만 둔다. 사용자 말이 여럿이면 `--approval` 을 말마다 하나씩 준다.
```

- [ ] **Step 5: 통과하는지 본다**

Run: `bash plugins/spec-distill/tests/test_decompose_surface.sh; bash plugins/spec-distill/tests/test_finish_commit_roadmap.sh; bash plugins/spec-distill/tests/test_conducting_reference.sh`
Expected: 셋 다 종료 코드 0. `test_finish_commit_roadmap.sh` 7 은 적용 펜스를 뽑아 실제로 돌린다 — 자리표만 바꿨으므로 그대로 통과해야 한다.

- [ ] **Step 6: 커밋**

```bash
git commit -m "docs(spec-distill): 재분해 신호를 열린 목록으로 · 이력 설명을 새 꼴로

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/references/redecompose.md plugins/spec-distill/tests/test_decompose_surface.sh
git show --stat HEAD   # 파일 둘
```

---

### Task 4: spec-review 게이트 ③ 의 「이 에픽 다시 설계」 갈래와 기각 번호 되돌리기 길 (AC33 · AC34 의 되돌리기)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (`## 게이트` 의 2단계 표 ③ 행 · `**③ 의 세 갈래와 로드맵 에픽.**` 문단)
- Modify: `plugins/spec-distill/references/redecompose.md` (`## 7. 끝내기` 의 「그만둔다」 불릿)
- Modify: `plugins/spec-distill/references/epic-handoff.md` (`## 자리표` 의 `<roadmap-rel>` 불릿)
- Test: `plugins/spec-distill/tests/test_review_handoff_order.sh` · `plugins/spec-distill/tests/test_decompose_surface.sh`

**Interfaces:**
- Consumes: Task 3 의 신호 문구(「이 에픽 다시 설계」 로 가고 이 절차로 오지 않는다).
- Produces: 갈래 이름 「이 에픽 다시 설계」, 문단 머리 `**③ 의 갈래와 로드맵 에픽.**`, 기타 칸 문단 머리 `**기타 칸 — 기각 번호 되돌리기.**`. Task 5 의 기각 줄이 「③ 수정 필요를 고르고 이어지는 질문의 기타 칸에 그 번호를 적는다」 로 이 문단을 가리킨다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_review_handoff_order.sh` 에서

```bash
  assert_contains "$r3" '`spec-interview` 재진입' "spec-review ③ 행: 인터뷰 재진입 갈래는 그대로 있다"
  BR="$(printf '%s\n' "$GATE" | awk '/^\*\*③ 의 세 갈래와 로드맵 에픽\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f')"
```

를 이것으로 바꾼다:

```bash
  assert_contains "$r3" '`spec-interview` 재진입' "spec-review ③ 행: 인터뷰 재진입 갈래는 그대로 있다"
  assert_contains "$r3" '로드맵 에픽이면 이 에픽 다시 설계도' "AC33: spec-review ③ 행이 로드맵 에픽의 넷째 갈래를 말한다"
  BR="$(printf '%s\n' "$GATE" | awk '/^\*\*③ 의 갈래와 로드맵 에픽\.\*\*/{f=1} f&&/^- \*\*①\/② 의 정지 요건\*\*/{exit} f')"
```

그리고 바로 아래 `for n in '「지적대로 고치기」' …; do … done` 블록 뒤에 더한다:

```bash
  for n in '「이 에픽 다시 설계」' '이 에픽의 묶음 안에서 끝날 때' 'Skill superpowers:brainstorming 을 다시 시작한다' \
           '같은 경로에 고쳐 쓰고 커밋한 뒤' '묶음 · 로드맵은 고치지 않는다' '지적이 다른 에픽의 경계에 닿을 때' \
           '「(권장)」 과 이유 한 줄' '고르는 것은 사용자다' '`roadmap:` 줄이 없는 문서의 세 갈래는 지금 그대로다'; do
    assert_contains "$BR" "$n" "AC33: spec-review ③ 로드맵 갈래 — $n"
  done
  for n in '**기타 칸 — 기각 번호 되돌리기.**' '「반영」으로 되돌린다' '`## 번호 대조` 표의 그 행' \
           '- 결정 · <YYYY-MM-DD> · 기각 되돌림' '「지적대로 고치기」 와 같은 길' '로드맵 에픽이 아니어도 같다'; do
    assert_contains "$BR" "$n" "AC34: ③ 기타 칸의 기각 번호 되돌리기 — $n"
  done
  BR_RD="$(printf '%s\n' "$BR" | grep -n '^Read \${CLAUDE_PLUGIN_ROOT}/references/redecompose\.md$' | cut -d: -f1)"
  [ -n "$BR_RD" ] && ok "AC33: 재분해 Read 줄이 ③ 문단 안에 들여쓰기 없이 있다" || no "AC33: 재분해 Read 줄이 ③ 문단 안에 없다(들여썼거나 꼬리가 붙었다)"
```

`plugins/spec-distill/tests/test_decompose_surface.sh` 에서 Task 3 이 더한 `UP=…` 줄 바로 앞에 더한다:

```bash
FIN7="$(win "$RED" '## 7. 끝내기' '## ')"
has "$FIN7" '(「지적대로 고치기」 · 「이 에픽 다시 설계」 · 「인터뷰 다시 열기」 · 「직접 편집」 네 갈래)' "AC33: 재분해 7 이 게이트 ③ 의 네 갈래로 돌아간다"
case "$FIN7" in *'세 갈래)'*) no "AC33: 재분해 7 에 옛 「세 갈래」가 남았다" ;; *) ok "AC33: 재분해 7 에 옛 「세 갈래」가 없다(양성 짝: 네 갈래)" ;; esac
assert_file_has "$SD/references/epic-handoff.md" '게이트 ③ 에서 「이 에픽 다시 설계」 와 재분해 갈래를 연다' "AC33: 넘김 줄 자리표 설명이 게이트 ③ 의 두 갈래를 말한다"
```

- [ ] **Step 2: 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_review_handoff_order.sh; bash plugins/spec-distill/tests/test_decompose_surface.sh`
Expected: 첫 파일에 `✗ spec-review: ③ 로드맵 분기 문단이 없다` 와 `✗ AC33: …` · `✗ AC34: …` 줄들, 둘째 파일에 `✗ AC33: …` 줄들.

- [ ] **Step 3: 2단계 표 ③ 행을 고친다**

`plugins/spec-distill/skills/spec-review/SKILL.md` 에서 ③ 행의 `사용자 직접 편집 분기. 수정 ·` 를 `사용자 직접 편집 분기(로드맵 에픽이면 이 에픽 다시 설계도). 수정 ·` 로 바꾼다(행의 다른 글자는 그대로).

- [ ] **Step 4: ③ 문단을 고친다**

같은 파일에서 `**③ 의 세 갈래와 로드맵 에픽.**` 으로 시작하는 줄부터 `「지적대로 고치기」 · 「직접 편집」 갈래와, \`roadmap:\` 줄이 없는 문서의 세 갈래는 지금 그대로다.` 줄까지(그 사이의 `Read` 펜스와 치환 안내 줄 포함)를 아래로 바꾼다. 치환 안내 줄(`그 파일의 플러그인 루트 변수(…)는 치환되지 않은 채로 온다 — …`)은 지금 파일에 있는 줄을 **글자 그대로 복사**해 아래 자리에 둔다 — 아래 블록의 그 줄도 지금 파일의 글자와 같다.

````markdown
**③ 의 갈래와 로드맵 에픽.** ③ 을 고르면 후속 질문 하나로 갈래를 묻는다 — 「지적대로 고치기」(revise per findings) · 「인터뷰 다시 열기」(`spec-interview` 재진입) · 「직접 편집」(사용자 직접 편집). 설계문서 frontmatter 에 `roadmap:` 줄이 있으면 그 문서는 로드맵 에픽이고, 갈래가 넷이다:

- 「이 에픽 다시 설계」 를 더한다 — 지적이 이 에픽의 묶음 안에서 끝날 때(다른 에픽의 범위 · 의존 · 경로 예약을 바꾸지 않을 때)의 길이다. 이 skill 을 여기서 끝내고, 같은 세션에서 같은 묶음(`--bundle` 값) · 지금 설계문서 · 이번 라운드의 지적을 입력으로 Skill superpowers:brainstorming 을 다시 시작한다. 설계문서는 같은 경로에 고쳐 쓰고 커밋한 뒤 그 경로 뒤에 `--bundle <묶음>` 을 붙여 이 skill 을 다시 부른다 — 새 경로에 쓰면 번호 대조가 같은 묶음의 설계문서 둘(「여러 spec」)로 경고한다. 묶음 · 로드맵은 고치지 않는다.
- 「인터뷰 다시 열기」 갈래는 인터뷰를 다시 열지 않고 같은 로드맵 위의 재분해 절차로 간다 — 지적이 다른 에픽의 경계에 닿을 때(범위가 다른 에픽으로 옮겨 가거나 새 에픽이 필요할 때)의 길이다.

두 갈래 중 이번 지적에 맞는 쪽 라벨에 「(권장)」 과 이유 한 줄을 붙인다 — 고르는 것은 사용자다. 재분해 절차는 아래 파일이다:

```
Read ${CLAUDE_PLUGIN_ROOT}/references/redecompose.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

**기타 칸 — 기각 번호 되돌리기.** 후속 질문의 기타 칸에 사용자가 게이트 앞 글의 기각 번호(N18)를 적으면 그 번호를 「반영」으로 되돌린다 — `## 번호 대조` 표의 그 행을 「반영」 과 설계문서의 자리로 고치고(자리가 없으면 그 내용을 설계에 더한다), `## 결정 기록` 에 `- 결정 · <YYYY-MM-DD> · 기각 되돌림 <번호> — 「<사용자가 적은 글 그대로>」` 한 줄을 남긴 뒤 「지적대로 고치기」 와 같은 길(원장 열기부터)로 다음 라운드를 돈다. 로드맵 에픽이 아니어도 같다.

「지적대로 고치기」 · 「직접 편집」 갈래와, `roadmap:` 줄이 없는 문서의 세 갈래는 지금 그대로다.
````

(바깥 네 백틱 펜스는 이 계획 안의 구분이다 — 파일에는 `**③ 의 갈래와 로드맵 에픽.**` 줄부터 마지막 줄까지 쓰고, 안쪽 세 백틱 펜스는 그대로 쓴다.)

- [ ] **Step 5: 재분해 7 과 넘김 줄 자리표 설명을 고친다**

`plugins/spec-distill/references/redecompose.md` `## 7. 끝내기` 의 둘째 불릿을

```
- 「그만둔다」 — 아무것도 쓰지 않고 spec-review 게이트 ③ 의 후속 질문(「지적대로 고치기」 · 「인터뷰 다시 열기」 · 「직접 편집」 세 갈래)으로 돌아간다. 게이트 ③ 에서 온 길이 아니면(신호 1 · 3) 어느 에픽 설계문서로 spec-review 를 다시 부를지 한 줄로 말하고 끝낸다.
```

이 불릿으로 바꾼다:

```
- 「그만둔다」 — 아무것도 쓰지 않고 spec-review 게이트 ③ 의 후속 질문(「지적대로 고치기」 · 「이 에픽 다시 설계」 · 「인터뷰 다시 열기」 · 「직접 편집」 네 갈래)으로 돌아간다. 게이트 ③ 에서 온 길이 아니면(1 의 다른 신호) 어느 에픽 설계문서로 spec-review 를 다시 부를지 한 줄로 말하고 끝낸다.
```

`plugins/spec-distill/references/epic-handoff.md` `## 자리표` 의 셋째 불릿에서 `spec-review 게이트 ③ 은 이 줄이 있는 설계문서를 로드맵 에픽으로 보고 재분해 절차로 보낸다.` 를 `spec-review 는 이 줄이 있는 설계문서를 로드맵 에픽으로 보고 게이트 ③ 에서 「이 에픽 다시 설계」 와 재분해 갈래를 연다.` 로 바꾼다.

- [ ] **Step 6: 통과하는지 본다**

Run: `bash plugins/spec-distill/tests/test_review_handoff_order.sh; bash plugins/spec-distill/tests/test_decompose_surface.sh; bash shared/tests/test_plugin_root_no_cwd_fallback.sh; bash shared/tests/test_skill_reference_pointers.sh; bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh`
Expected: 다섯 다 종료 코드 0(기준선의 이미 빨간 이름 제외). 루트 락의 「축 3: … 안내 문장이 없다」가 나오면 치환 안내 줄이 글자 그대로인지, `Read` 줄과 같은 절(`## 게이트`)에 있는지 본다.

- [ ] **Step 7: 커밋**

```bash
git commit -m "feat(spec-distill): 게이트 ③ 이 로드맵 에픽에서 「이 에픽 다시 설계」 를 고르게 한다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/references/redecompose.md plugins/spec-distill/references/epic-handoff.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_decompose_surface.sh
git show --stat HEAD   # 파일 다섯
```

---

### Task 5: 승인 게이트에 기각 번호의 수와 목록 (AC34 · N18)

**Files:**
- Modify: `plugins/spec-distill/scripts/spec_review_bundle.py` (`rejected` 하위 명령)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (`## 게이트` — `**로드맵 속 위치와 이웃 결정 — 2단계 질문 바로 앞.**` 문단 바로 앞에 새 문단 · 펜스)
- Test: `plugins/spec-distill/tests/test_spec_review_bundle.sh`

**Interfaces:**
- Consumes: `check_bundle_coverage.TABLE_HEADING: str` · `check_bundle_coverage.table_rows(spec_text: str) -> list[tuple[list[str], str, str]]`(번호 목록 · 처리 · 셋째 칸, 깨지면 `FormatError`), `roadmap_model.section_body(text, heading) -> str | None`(같은 절이 둘이면 `FormatError`), 이 파일의 `_resolve(value, root) -> str` · `_read(path) -> str | None`. Task 4 의 기타 칸 문단.
- Produces: `spec_review_bundle.REJECTED_HEAD: str = "이 설계가 받지 않기로 한 번호(번호 대조의 기각)"`, `spec_review_bundle.rejected(spec: str, root: str) -> list[str]`, 명령줄 `spec_review_bundle.py rejected --spec <설계문서> --root <레포 루트>`(종료 코드 0, 사용법 오류만 2), SKILL 펜스 표지 `<!-- rejected-numbers:begin -->` · `<!-- rejected-numbers:end -->`.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_spec_review_bundle.sh` 의 마지막 `finish` 줄 바로 앞에 더한다:

```bash
# ── R5 계획 2 AC34(N18) — 승인 게이트의 기각 번호 ──────────────────────────────
RJ="$T/rj"; mkdir -p "$RJ"
rj_spec() {  # rj_spec <파일 이름> <번호 대조 절 본문(%b)>
  printf '%b' "---\nsource_interview: docs/rm/R3.md\n---\n\n# 설계\n\n### §1 절\n\n본문\n\n$2" > "$RJ/$1"
}
rj() { (cd "$T" && python3 "$SRB" rejected --spec "$1" --root "$RJ"); }
RJ_TBL='## 번호 대조\n\n| 번호 | 처리 | 자리 · 이유 |\n|---|---|---|\n'
RJ_HEAD='이 설계가 받지 않기로 한 번호(번호 대조의 기각)'
rj_spec two.md "${RJ_TBL}| C1 | 반영 | §1 |\n| S1 · S2 | 기각 | R4 로 넘김 |\n| OQ1 | 기각 | 범위 밖 |\n"
out="$(rj two.md)"; rc=$?
assert_eq "$rc" "0" "AC34: rejected 는 종료 코드 0"
assert_eq "$(printf '%s\n' "$out" | head -n 1)" "$RJ_HEAD 3개 — 반영으로 되돌릴 번호가 있으면 ③ 수정 필요를 고르고 이어지는 질문의 기타 칸에 그 번호를 적는다." "AC34: 기각 수는 행이 아니라 번호로 센다"
assert_contains "$out" "- S1 · S2 — R4 로 넘김" "AC34: 기각 목록에 번호와 이유"
assert_contains "$out" "- OQ1 — 범위 밖" "AC34: 기각 목록 둘째 행"
assert_not_contains "$out" "C1" "AC34: 반영 행은 싣지 않는다"
rj_spec none.md "${RJ_TBL}| C1 | 반영 | §1 |\n"
assert_eq "$(rj none.md)" "$RJ_HEAD 없음" "AC34: 기각이 없으면 「없음」 한 줄 — 침묵과 다르다"
rj_spec notable.md ""
assert_eq "$(rj notable.md)" "" "AC34: 번호 대조 절이 없는 설계문서면 아무것도 내지 않는다"
rj_spec broken.md "## 번호 대조\n\n| 번호 | 처리 |\n|---|---|\n| C1 | 기각 |\n"
assert_contains "$(rj broken.md)" "$RJ_HEAD — 셀 수 없음:" "Review Focus 1: 깨진 표는 「없음」이 아니라 「셀 수 없음」"
rj_spec dup.md "${RJ_TBL}| C1 | 기각 | 범위 밖 |\n\n${RJ_TBL}| S1 | 기각 | 범위 밖 |\n"
assert_contains "$(rj dup.md)" "$RJ_HEAD — 셀 수 없음:" "Review Focus 1: 번호 대조 절이 둘이면 「셀 수 없음」"
assert_eq "$(rj absent.md)" "$RJ_HEAD — 셀 수 없음: 설계문서를 읽지 못했다(absent.md)" "AC34: 없는 설계문서는 「셀 수 없음」"
(cd "$T" && python3 "$SRB" rejected --spec two.md >/dev/null 2>&1); rc=$?
assert_eq "$rc" "2" "AC34: --root 없음 → 사용법 오류 2"
# SKILL 배선 — 펜스를 실제로 돌리고 자리를 잰다
RF="$(fence rejected-numbers)"
[ -n "$RF" ] && ok "기각 펜스(rejected-numbers)가 있다" || no "기각 펜스(rejected-numbers)가 없다"
out="$(run_fence "$RF" "$SDROOT" "spec_path='$RJ/two.md' repo_root='$RJ'")"
assert_contains "$out" "$RJ_HEAD 3개" "AC34: 펜스가 기각 번호를 낸다"
out="$(run_fence "$RF" "$T/emptyroot" "spec_path='$RJ/two.md' repo_root='$RJ'")"
assert_contains "$out" "[spec-distill] 이 설계가 받지 않기로 한 번호를 셀 수 없다 — 스크립트가 실패했다." "AC34: 스크립트가 없으면 셀 수 없다고 말한다"
pos_of() { awk -v m="$1" 'index($0,m){print NR; exit}' "$SKILL"; }
pa="$(pos_of '<!-- advice-display:begin -->')"; pb="$(pos_of '<!-- rejected-numbers:begin -->')"; pc="$(pos_of '<!-- roadmap-position:begin -->')"
{ [ -n "$pa" ] && [ -n "$pb" ] && [ -n "$pc" ] && [ "$pa" -lt "$pb" ] && [ "$pb" -lt "$pc" ]; } \
  && ok "AC34: 기각 펜스는 참고 목록 뒤 · 로드맵 위치 앞" || no "AC34: 펜스 순서가 다르다(${pa} · ${pb} · ${pc})"
GATE_RJ="$(awk '/^## 게이트$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
assert_contains "$GATE_RJ" "이 수는 「경고 N개」에 더하지 않는다" "AC34: 기각 수는 경고가 아니다"
assert_contains "$GATE_RJ" "**기각한 번호 — 2단계 질문 앞(N18).**" "AC34: 게이트 절에 기각 문단 머리"
```

- [ ] **Step 2: 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_spec_review_bundle.sh`
Expected: `✗ AC34: rejected 는 종료 코드 0`(argparse 가 모르는 하위 명령으로 2 를 낸다)을 비롯한 `✗ AC34: …` · `✗ Review Focus 1: …` · `✗ 기각 펜스(rejected-numbers)가 없다` 줄들. 앞 절의 단언은 그대로 통과한다.

- [ ] **Step 3: `rejected` 를 쓴다**

`plugins/spec-distill/scripts/spec_review_bundle.py`:

docstring 의 명령줄 두 줄 아래에 한 줄, 끝 문단 앞에 한 문단을 더한다:

```python
"""spec_review_bundle.py — spec-review 의 `--bundle`: 정답 출처 확인 · 진입 번호 대조 · 승인 때 로드맵 위치와 이웃 결정.

명령줄:
  spec_review_bundle.py entry --spec <설계문서> [--bundle <묶음|brief>] --root <레포 루트>
  spec_review_bundle.py neighbors --bundle <묶음> --root <레포 루트>
  spec_review_bundle.py rejected --spec <설계문서> --root <레포 루트>

entry 의 마지막 줄은 `bundle-entry: PROCEED <정답 출처 절대경로 또는 ->` 이거나 `bundle-entry: REFUSE` 다.
`--bundle` 이 있으면 PROCEED 바로 앞 줄이 `번호 대조 경고 <N>개` 다. `--bundle` 은 리뷰어에게 가지 않는다 —
그 값이 설계문서 frontmatter `source_interview` 와 같은 파일인지 확인하고 진입 대조 · 로드맵 위치의 입력이 된다.
neighbors 는 정답 출처가 에픽 묶음이 아니거나 그 에픽이 로드맵에 없으면 아무것도 내지 않는다.
rejected 는 설계문서 `## 번호 대조` 표의 「기각」 행을 번호 수와 목록으로 낸다(승인 게이트 2단계 앞 글 — N18).
표 절이 없으면 아무것도 내지 않고, 표를 못 읽으면 「셀 수 없음」 줄이다 — 「없음」과 다르다.
종료 코드는 0 이다(사용법 오류만 2) — 판정은 줄이 말한다. 읽기만 한다(roadmap_status 의 읽기 전용 git 만 부른다).
"""
```

`DECISION_LINE_RE = …` 줄 바로 아래에 더한다:

```python
REJECTED_HEAD = "이 설계가 받지 않기로 한 번호(번호 대조의 기각)"
```

`neighbors` 함수 뒤, `main` 앞에 더한다:

```python
def rejected(spec: str, root: str) -> list:
    """설계문서 `## 번호 대조` 표의 「기각」 행 — 번호 수와 줄마다 번호 · 이유. 표 절이 없으면 빈 목록."""
    text = _read(_resolve(spec, root))
    if text is None:
        return ["%s — 셀 수 없음: 설계문서를 읽지 못했다(%s)" % (REJECTED_HEAD, spec)]
    try:
        if section_body(text, cbc.TABLE_HEADING) is None:
            return []
        rows = [(ids, cell) for ids, verb, cell in cbc.table_rows(text) if verb.startswith("기각")]
    except FormatError as exc:
        return ["%s — 셀 수 없음: %s" % (REJECTED_HEAD, exc)]
    n = sum(len(ids) for ids, _cell in rows)
    if not n:
        return ["%s 없음" % REJECTED_HEAD]
    head = ("%s %d개 — 반영으로 되돌릴 번호가 있으면 ③ 수정 필요를 고르고 이어지는 질문의 기타 칸에 그 번호를 적는다."
            % (REJECTED_HEAD, n))
    return [head] + ["- %s — %s" % (" · ".join(ids), cell) for ids, cell in rows]
```

`main` 의 하위 명령 정의와 호출을 이렇게 바꾼다(`n.add_argument("--root", required=True)` 줄부터 `print("\n".join(lines))` 앞까지):

```python
    n = sub.add_parser("neighbors")
    n.add_argument("--bundle", required=True)
    n.add_argument("--root", required=True)
    r = sub.add_parser("rejected")
    r.add_argument("--spec", required=True)
    r.add_argument("--root", required=True)
    args = ap.parse_args(argv)
    try:
        if args.cmd == "entry":
            lines = entry(args.spec, args.bundle, args.root)
        elif args.cmd == "rejected":
            lines = rejected(args.spec, args.root)
        else:
            lines = neighbors(args.bundle, args.root)
    except Exception as exc:  # 확인이 죽어도 조용히 통과로 내지 않는다 — 사유를 줄로 낸다
        if args.cmd == "entry":
            lines = ["[spec-distill] 번호 대조 진입 검사 내부 오류 — %s: %s. --bundle 확인과 번호 대조 없이 리뷰한다."
                     % (type(exc).__name__, exc), "번호 대조 경고 1개", "bundle-entry: PROCEED -"]
        elif args.cmd == "rejected":
            lines = ["%s — 셀 수 없음: 내부 오류 %s: %s" % (REJECTED_HEAD, type(exc).__name__, exc)]
        else:
            lines = ["[spec-distill] 로드맵 속 위치를 보일 수 없다 — 내부 오류 %s: %s" % (type(exc).__name__, exc)]
```

`main` 의 `ArgumentParser` description 을 `"spec-review --bundle: 정답 출처 확인 · 진입 대조 · 로드맵 위치와 이웃 결정 · 기각 번호."` 로 바꾼다.

- [ ] **Step 4: SKILL 에 문단과 펜스를 더한다**

`plugins/spec-distill/skills/spec-review/SKILL.md` 에서 `**로드맵 속 위치와 이웃 결정 — 2단계 질문 바로 앞.**` 으로 시작하는 줄 바로 앞에 아래를 더한다. 펜스 첫 줄(가드 줄)은 바로 아래 `roadmap-position` 펜스의 첫 줄을 **글자 그대로 복사**한 것이다 — 아래 블록의 그 줄도 지금 파일의 글자와 같다.

````markdown
**기각한 번호 — 2단계 질문 앞(N18).** 2단계 질문 앞 글에, 이 설계가 받지 않기로 한 번호(`## 번호 대조` 표의 「기각」 행)의 수와 목록을 아래 펜스 출력 그대로 싣는다 — 로드맵 속 위치 줄들 바로 앞에. 출력이 없으면(번호 대조 표가 없는 설계문서) 아무것도 싣지 않는다. 이 수는 「경고 N개」에 더하지 않는다 — 경고가 아니라 사용자가 되돌릴 수 있는 결정이다. 되돌리는 길은 아래 `**기타 칸 — 기각 번호 되돌리기.**` 문단이다. 펜스 앞에 `spec_path='<「## 입력」에서 절대 경로로 바꾼 설계문서 경로>' repo_root='<감시줄 root= 값>'` 한 줄을 붙여 같은 Bash 호출로 돌린다.

<!-- rejected-numbers:begin -->
```bash
SD="${CLAUDE_PLUGIN_ROOT}"; [ -n "$SD" ] || { echo "[spec-distill] 플러그인 루트 미해석 — SKILL.md 가 플러그인 절대 경로를 보여 줬다면 이 펜스의 루트 변수를 그 값으로 바꿔 다시 실행하고, 보여 준 적이 없으면 경로를 추측하지 말고(cwd 포함) 멈춰 보고하라 — 리뷰 없이 끝났다 — writing-plans 로 가기 전에 설계문서 경로를 보이고 사용자에게 검토를 요청하라(brainstorming 의 사용자 리뷰 게이트)." >&2; exit 1; }
python3 "$SD/scripts/spec_review_bundle.py" rejected --spec "${spec_path:-}" --root "${repo_root:-}" \
  || echo "[spec-distill] 이 설계가 받지 않기로 한 번호를 셀 수 없다 — 스크립트가 실패했다."
```
<!-- rejected-numbers:end -->

````

(바깥 네 백틱 펜스는 이 계획 안의 구분이다 — 파일에는 `**기각한 번호 — …**` 줄부터 `<!-- rejected-numbers:end -->` 줄과 그 뒤 빈 줄까지 쓴다.)

- [ ] **Step 5: 통과하는지 본다**

Run: `bash plugins/spec-distill/tests/test_spec_review_bundle.sh; bash plugins/spec-distill/tests/test_roadmap_status.sh; bash shared/tests/test_plugin_root_no_cwd_fallback.sh; bash plugins/spec-distill/tests/test_review_handoff_order.sh; bash plugins/spec-distill/tests/test_ledger_wiring.sh`
Expected: 다섯 다 종료 코드 0(기준선 제외). `test_roadmap_status.sh` 의 「정적: 여섯 스크립트에 쓰기 · 네트워크 · … 가 없다」 · `CHECKED 6` 이 통과해야 한다.

Run: `python3 plugins/spec-distill/scripts/spec_review_bundle.py rejected --spec docs/superpowers/specs/2026-10-17-epic-conductor-design.md --root "$(git rev-parse --show-toplevel)"`
Expected(실데이터 — 이 설계문서의 기각 행은 RC85 하나):

```
이 설계가 받지 않기로 한 번호(번호 대조의 기각) 1개 — 반영으로 되돌릴 번호가 있으면 ③ 수정 필요를 고르고 이어지는 질문의 기타 칸에 그 번호를 적는다.
- RC85 — P3 결정의 적용은 R2a 범위 — 지휘자는 그 이름을 부르기만
```

- [ ] **Step 6: 커밋**

```bash
git commit -m "feat(spec-distill): 승인 게이트가 기각한 번호의 수와 목록을 보인다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/scripts/spec_review_bundle.py plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/tests/test_spec_review_bundle.sh
git show --stat HEAD   # 파일 셋
```

---

### Task 6: 진행 게이트의 기타 칸 「여기서 계속」 (AC35)

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md` (`## Step B` 끝)
- Test: `plugins/spec-distill/tests/test_seed_at_path_handoff.sh`

**Interfaces:**
- Consumes: 없음.
- Produces: 정본 Step B 의 문단 머리 `**기타 칸 — 「여기서 계속」.**`. 채택 skill(spec-review · spec-interview · request-framing)은 게이트 진입 때 정본을 읽으므로 고치지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`plugins/spec-distill/tests/test_seed_at_path_handoff.sh` 에서 `assert_not_contains "$stepb" '바로 진행' …` 줄 바로 아래에 더한다:

```bash
assert_eq "$(printf '%s\n' "$stepb" | grep -cE '^\| [①②③④] \|')" "4" "AC35: 진행 게이트 선택지는 넷 그대로"
STEPB_F="$(printf '%s\n' "$stepb" | flat)"
for n in '**기타 칸 — 「여기서 계속」.**' '①/② 고유 단계(예: `spec-review` 의 미커밋 확인)를 마친 뒤' \
         '압축 없이 이 세션에서 다음 세션 줄의 지시를 그대로 따른다' '게이트를 건너뛴 것이 아니다' \
         '가드 2 가 다루는 자리도 아니다' '불분명하면 다시 묻는다'; do
  assert_contains "$STEPB_F" "$n" "AC35: 정본 Step B — $n"
done
```

그리고 `assert_not_contains "$g2" '명시적 예외' …` 줄 바로 아래에 더한다:

```bash
assert_not_contains "$g2" '여기서 계속' "AC35: 기타 칸 규칙은 가드 2 블록이 아니라 Step B 에 있다(양성 짝: Step B 단언)"
```

- [ ] **Step 2: 실패하는지 본다**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh`
Expected: `✗ AC35: 정본 Step B — …` 줄들. 「선택지는 넷 그대로」 와 가드 2 단언은 지금도 통과한다.

- [ ] **Step 3: 정본에 문단을 더한다**

`plugins/spec-distill/references/proceed-gate.md` 의 `## Step B` 절 마지막 문단(`채널을 명시하지 않은 skill 은 …` 으로 시작해 `… 두 문서의 불일치보다 나쁘다.` 로 끝나는 문단) 바로 뒤, `## 다음 세션 명령` 앞에 빈 줄 하나와 함께 더한다:

```markdown
**기타 칸 — 「여기서 계속」.** 질문 도구는 선택지 넷 뒤에 기타 칸을 붙인다. 사용자가 거기에 「여기서 계속」(같은 뜻의 말 포함)을 적으면, 그 skill 의 ①/② 고유 단계(예: `spec-review` 의 미커밋 확인)를 마친 뒤 명령 두 줄을 노출하지 않고 압축 없이 이 세션에서 다음 세션 줄의 지시를 그대로 따른다 — 줄 맨 앞의 `@` 경로는 이 세션에서 그 파일을 읽는 것으로 갈음한다. 사용자가 고른 진행이라 게이트를 건너뛴 것이 아니다. 명령을 노출하지 않으므로 가드 2 가 다루는 자리도 아니다. 선택지는 넷 그대로다. 기타 칸의 다른 글은 그 뜻대로 따르되, 어느 선택지인지 불분명하면 다시 묻는다.
```

- [ ] **Step 4: 통과하는지 본다**

Run: `bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh; bash plugins/spec-distill/tests/test_plain_gate_templates.sh; bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh; bash plugins/spec-distill/tests/test_next_session_command.sh; bash plugins/spec-distill/tests/test_conducting_interview_stage.sh`
Expected: 다섯 다 종료 코드 0(기준선 제외). 새 문단에 「바로 진행」 · 「명시적 예외」 가 없어야 한다.

- [ ] **Step 5: 커밋**

```bash
git commit -m "feat(spec-distill): 진행 게이트가 기타 칸의 「여기서 계속」 을 받는다

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/tests/test_seed_at_path_handoff.sh
git show --stat HEAD   # 파일 둘
```

---

### Task 7: 릴리스 · 문서 · 스위트 대조 · 구현 대조 (AC38)

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/README.md`
- Modify: `docs/superpowers/specs/2026-10-17-epic-conductor-design.md` (`## 미룸` · `## 판정` · `## 구현 대조 — <이 계획 경로>`)

**Interfaces:**
- Consumes: Task 0 의 `suite-names.sh` · `baseline.txt`, `check_bundle_coverage.py --plan · --impl --acs`(계획 1), `roadmap_model.IMPL_PREFIX = "## 구현 대조 — "` · `RULINGS_HEADING = "## 판정"`(계획 1 — 같은 머리가 둘이면 `section_lines` 가 `FormatError`).

- [ ] **Step 1: 버전을 올린다**

Run: `git fetch origin && git show origin/HEAD:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'; grep '"version"' plugins/spec-distill/.claude-plugin/plugin.json`
둘 중 큰 값의 minor 를 하나 올린 번호(지금 이 브랜치는 `7.1.0` → `7.2.0`)를 `plugin.json` 의 `version` 에 쓴다. 머지 직전에 origin 기본 브랜치의 값이 바뀌었으면 다시 정한다.

- [ ] **Step 2: CHANGELOG 를 쓴다**

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 아래, 맨 위 버전 블록 앞에 더한다(번호는 Step 1 의 것, 날짜는 커밋하는 날):

```markdown
## [7.2.0] — 2026-10-18

### Added
- `references/conducting.md` — 로드맵의 에픽을 한 세션이 지휘하는 손 절차(맞추기 · 에픽과 브랜치 · 흐름과 설계 · superpowers 가 묻는 자리 · 계획 · 구현 · 머지 뒤 · `Spec:` 트레일러 · 머지 전 확인 · 끝). 레포마다 다른 값(기본 브랜치 · 브랜치 이름 · 폴더 · 테스트 명령 · 리뷰 모델)은 박지 않고 `origin/HEAD` 와 로드맵 frontmatter 에서 읽는다. 계획 검토는 계획에 설계에 없던 결정이 있을 때만 기다린다.
- `spec_review_bundle.py rejected --spec <설계문서> --root <레포 루트>` — spec-review 승인 게이트 2단계 앞 글에 설계가 받지 않기로 한 번호(번호 대조의 기각)의 수와 목록을 낸다. 표가 깨졌으면 「셀 수 없음」, 표 절이 없으면 아무것도 내지 않는다. 이 수는 「경고 N개」에 더하지 않는다(N18).
- spec-review 게이트 ③: 로드맵 에픽의 설계문서면 「이 에픽 다시 설계」 갈래(같은 묶음으로 brainstorming 을 다시 돌아 같은 경로의 설계문서를 고친다)를 더한다. 후속 질문의 기타 칸에 기각 번호를 적으면 그 번호를 「반영」으로 되돌리고 결정 기록에 남긴 뒤 다음 라운드를 돈다.
- 진행 게이트 공통 계약(`references/proceed-gate.md`): 질문의 기타 칸에 「여기서 계속」 을 적으면 ①/② 의 고유 단계를 마친 뒤 압축 없이 이 세션에서 다음 단계를 잇는다. 선택지는 넷 그대로다.

### Changed
- 에픽 넘김 줄: brainstorming 은 기본값이고 블록에 `흐름:` 이 있으면 그 흐름 · `산출물:` 을 따른다. 묶음을 다시 나눌 근거가 보이면 나누지 않고 재분해 신호로 보고한다. 마지막 전체 리뷰는 고른 실행 방식의 것이다(조사 에픽은 산출물의 AC 대조). 설계문서에 「있는 것 검토」 · 「상류 · 하류 연계」 절을 두고 레포 전용 값을 박지 않는다.
- spec-review 승인 게이트의 다음 세션 줄: 「SDD 의 마지막 전체 리뷰」 → 「고른 실행 방식의 마지막 전체 리뷰」.
- 재분해 신호(`references/redecompose.md` 1)가 열린 목록이다 — 에픽 설계 세션 · 계획 · 구현 세션이 찾은 경계 오류를 예로 더했다. 5 의 이력 설명이 새 꼴(`### <날짜> · <사유>` · `- 바뀜:` 끝의 승인 인용 · `- 원문:` 에 사용자 말만)을 말한다. 6 은 손 절차를 가리키고, 7 은 게이트 ③ 의 네 갈래로 돌아간다.
```

- [ ] **Step 3: README 를 고친다**

`plugins/spec-distill/README.md` `## 로드맵 · 에픽 묶음`:
- `` - `scripts/spec_review_bundle.py` — … 이웃 결정.`` 줄 끝에 「`rejected` 는 승인 게이트 2단계 앞 글에 설계가 받지 않기로 한 번호(번호 대조의 기각)의 수와 목록을 냅니다 — 되돌리려면 게이트 ③ 의 후속 질문 기타 칸에 번호를 적습니다.」 를 더한다.
- `` - `references/epic-handoff.md` — 로드맵 에픽의 설계를 여는 넘김 줄. 지휘 세션이 자리표를 채워 씁니다.`` 줄을 「`` - `references/epic-handoff.md` — 로드맵 에픽의 설계를 여는 넘김 줄. 지휘 세션이 자리표를 채워 씁니다. brainstorming 이 기본이고 블록에 `흐름:` 이 있으면 그 흐름을 따르며, 나눌 근거가 보이면 재분해로 보고하고, 설계문서에 「있는 것 검토」 · 「상류 · 하류 연계」 절을 둡니다. ``」 로 바꾼다.
- 그 줄 바로 아래에 두 줄을 더한다:

```markdown
- `references/conducting.md` — 로드맵의 에픽을 한 세션이 끝까지 지휘하는 손 절차입니다. 레포마다 다른 값은 로드맵 frontmatter 와 `origin/HEAD` 에서 읽습니다.
- spec-review 게이트 ③ — 로드맵 에픽의 설계문서면 「이 에픽 다시 설계」(같은 묶음으로 brainstorming 을 다시) 와 재분해(「인터뷰 다시 열기」) 를 고를 수 있습니다. 재분해 신호는 열린 목록입니다(`references/redecompose.md` 1).
```

`## Principles Instantiated` 의 `- **AP2 (Polite stop)** — …` 줄 끝에 한 문장을 더한다:

```markdown
 질문의 기타 칸에 「여기서 계속」 을 적으면 ①/② 의 고유 단계를 마친 뒤 압축 없이 이 세션에서 다음 단계를 잇는다 — 사용자가 고른 진행이라 게이트를 건너뛴 것이 아니다(7.2.0).
```

`### Three Laws` 목록의 `- **Law 3 (Compounding) — 로드맵 온톨로지 · 사실마다 주인 하나 (7.1.0)** — …` 줄 바로 아래에 더한다:

```markdown
- **Law 1 · P17 — 흐름을 고정하지 않는다 (7.2.0)** — 정석 흐름은 기본값이고 일의 모양이 다르면 모델이 고르되 사용자가 정한다: 에픽 넘김 줄은 블록의 `흐름:` 을 따르고, 재분해 신호는 열린 목록이며, 게이트 ③ 은 로드맵 에픽에서 「이 에픽 다시 설계」 를 고를 수 있고, 진행 게이트는 기타 칸의 「여기서 계속」 을 받는다. 승인 게이트는 설계가 받지 않기로 한 번호를 보여 사용자가 「반영」 으로 되돌릴 수 있다(N18). 문면은 `tests/test_epic_handoff.sh` · `test_decompose_surface.sh` · `test_review_handoff_order.sh` · `test_seed_at_path_handoff.sh` · `test_conducting_reference.sh` 가 잠근다.
```

- [ ] **Step 4: 스위트를 기준선과 대조한다**

Run: `bash .superpowers/sdd/2026-10-17-epic-conductor-2-seams/suite-names.sh > .superpowers/sdd/2026-10-17-epic-conductor-2-seams/after.txt; comm -13 .superpowers/sdd/2026-10-17-epic-conductor-2-seams/baseline.txt .superpowers/sdd/2026-10-17-epic-conductor-2-seams/after.txt`
Expected: 빈 출력(이 브랜치에만 있는 실패 이름 없음). 나오면 그 실패를 고치고 다시 돈다. `comm -23` 으로 고쳐진 이름도 본다. `shared/tests/test_changelog_integrity.sh` · `test_no_new_duplication.sh` · `test_invocation_surface.sh` · `test_skill_reference_pointers.sh` · `test_plugin_root_no_cwd_fallback.sh` 가 모두 기준선과 같은지 이 대조가 함께 잰다.

- [ ] **Step 5: 계획 대조를 돌린다**

Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --plan docs/superpowers/specs/2026-10-17-epic-conductor-design.md docs/superpowers/plans/2026-10-17-epic-conductor-2-seams.md --acs "AC31~AC35 · AC38 · AC42"`
Expected: `계획 대조: 계획에 없는 AC 없음 (AC 7개 · --acs 로 고른 것 · 뺀 AC 38개)`.

- [ ] **Step 6: 커밋**

```bash
git commit -m "chore(spec-distill): 이음매 · 흐름 풀기 릴리스 기록

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md
git show --stat HEAD   # 파일 셋
```

- [ ] **Step 7: 마지막 전체 리뷰 뒤 — 구현 대조를 설계문서에 남긴다**

이 걸음은 구현 대조를 거두는 쪽이 한 번만 한다 — 지휘 세션이 이 계획의 구현을 보냈으면 지휘 세션이, 단일 세션이면 그 세션이다. 설계문서에 `## 구현 대조 — docs/superpowers/plans/2026-10-17-epic-conductor-2-seams.md` 절이 이미 있으면 건너뛴다.

실행 방식의 마지막 전체 리뷰가 `ac-report.md`(SDD 작업 폴더)에 AC 마다 한 줄을 적은 뒤:

1. 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표(항목 · 이유 · 받는 곳)에 올린다. 받는 곳은 로드맵의 에픽 번호나 `#<n>` 이다.
2. Run: `python3 plugins/spec-distill/scripts/check_bundle_coverage.py --impl docs/superpowers/specs/2026-10-17-epic-conductor-design.md .superpowers/sdd/2026-10-17-epic-conductor-2-seams/ac-report.md --acs "AC31~AC35 · AC38 · AC42"` — 출력을 고치지 않고 사용자에게 보인다.
3. 설계문서에 두 절을 쓴다. `## 판정` 절이 이미 있으면(계획 1) 새로 만들지 않고 그 절 끝에 `### docs/superpowers/plans/2026-10-17-epic-conductor-2-seams.md` 하위 머리와 줄들을 잇는다 — 같은 `## 판정` 머리가 둘이면 상태 계산이 형식 오류로 읽는다. 없으면 설계문서 끝에 절을 만든다.

```markdown
## 판정

### docs/superpowers/plans/2026-10-17-epic-conductor-2-seams.md

- <실행 방식의 마지막 목록 「Rulings I made」 의 줄을 그대로, 줄마다 `- ` 를 붙여>

## 구현 대조 — docs/superpowers/plans/2026-10-17-epic-conductor-2-seams.md

- 구현 대조: <위 2 의 첫 줄 그대로>
- 보고: AC 7개 중 구현됨 <n> · 미룸 <n> · 빠짐 <n>
```

4. 커밋한다:

```bash
git commit -m "docs(spec-distill): R5 계획 2 의 판정과 구현 대조

Spec: docs/superpowers/specs/2026-10-17-epic-conductor-design.md" -- docs/superpowers/specs/2026-10-17-epic-conductor-design.md
git show --stat HEAD   # 파일 하나
```
