# 다음 세션 `@` 명령 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 의 세 proceed 게이트(request-framing · spec-interview · spec-review)가 ① `/new` · ② `/compact` 뒤에 ①·② 공통의 「다음 세션 줄」을 노출하고, 그 줄이 읽을 파일을 `@` 로 붙여 오게 한다.

**Architecture:** 공통 규칙은 정본 `plugins/spec-distill/references/proceed-gate.md` 의 새 절 `## 다음 세션 명령` 하나에 둔다. 각 채택자는 자기 표면에 단독 줄 `**다음 세션 줄 — ①/② 공통**` 과 그 아래 인용 줄 하나로 다음 세션 줄을 **한 번만** 정의하고, ①·② 서술은 그 블록을 가리킨다. 새 락 `test_next_session_command.sh` 가 채택자를 정본 포인터에서 도출해 줄의 개수 · 모양 · 받는 쪽 한도를 잰다.

**Tech Stack:** Markdown skill 문면 · bash 테스트(`shared/tests/assert.sh`) · python3 (락 안의 파서).

**Spec:** `docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md`

## Global Constraints

- 브랜치 `feature/next-session-at-handoff` (base `origin/main` 3a8d7d1d). 착수 전 `git fetch -q origin && git merge-base --is-ancestor origin/main HEAD` 로 base 이동을 확인한다 — 움직였으면 멈추고 보고한다.
- 커밋은 Conventional Commits, 설명은 한국어(`type`·`scope` 는 영어). 끝 줄 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- 커밋은 **pathspec** 으로만 한다(`git commit -m … -- <파일들>`). `git add -A` 금지.
- 셸 테스트는 리포 루트에서 `bash <경로>` 로 돌린다. 변이는 커밋한 **뒤** `PYTHONDONTWRITEBYTECODE=1` 로 돌리고, 복원은 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --quiet` 로 확인한다.
- skill 문면에 외부 slash 명령(`/superpowers:…`)을 쓰지 않는다(`shared/entry/check_invocation_surface.py` 축 G). 외부 skill 은 산문 `Skill superpowers:…` 로만 부른다.
- 산출물 문면(skill · reference)에 출처 · 이력 · 존재 정당화를 쓰지 않는다(CLAUDE.md Self-narrating artifact). 근거는 CHANGELOG 에 둔다.
- 플러그인 버전: `plugins/spec-distill/.claude-plugin/plugin.json` 5.1.1 → 5.2.0(가안). **번호는 머지 직전에 다시 정한다** — 먼저 머지되는 다른 PR 이 같은 번호를 쓰면 올린다.
- 옛 CHANGELOG 항목과 `docs/archive/**` · `docs/superpowers/interview/**` 는 고치지 않는다.
- devbrew 에서 fable 모델 금지 — SDD 리뷰어 포함 opus 이하를 쓴다.
- 테스트 헬퍼 · 변이 스크립트 · baseline 은 `~/.claude/sdd-mirror/next-session-at-handoff/` 에 둔다(job tmp 는 세션 재개에 사라지고, 리뷰 subagent 가 공유 tmp 를 glob 삭제한 전례가 있다).

### 설계 리뷰에서 넘어온 항목의 처리 (설계문서 `### Deferred to plan`)

| # | 처리 |
|---|---|
| d7c7778d#r2.1 · 7da1a12c#r1.1 (경로 기준) | **재결정(사용자 확인 필요).** 설계 규칙 5 는 「git 작업 트리 루트 기준 상대경로」였다. 실측(2026-10-11)에서 평문 `@` 의 상대경로는 세션 작업 디렉토리 기준으로 풀렸고(하위 디렉토리에서 루트의 `@a.md` → `NONE`), 절대경로는 어느 작업 디렉토리에서도 첨부됐다. 그래서 **평문 줄은 절대경로**, slash 줄(spec-interview 수신부)은 그 수신부의 `root=` 기준 상대경로로 쓴다. 비용: 체크아웃 경로에 공백이 있으면 평문 줄을 낼 수 없다 — 규칙 5 가 그때 노출하지 않고 advisory 를 낸다. Task 1 의 규칙 5 문면이 이것이다 |
| 62da0911#r1.1 · afa170e3#r2.1 (줄 찾기 기준 · request-framing 블록) | 세 채택자 모두 표지 줄 `**다음 세션 줄 — ①/② 공통**`(제목이 아닌 굵은 단독 줄 — 제목이면 기존 락의 `^##` 창 추출이 거기서 끊긴다)을 갖는다. 락은 패턴이 아니라 표지로 줄을 찾고, 표지 밖의 줄 모양 인용 줄은 개수 단언(정확히 1)이 잡는다. request-framing 은 줄의 글자는 그대로 두고 표지만 더한다(Task 2) |
| 0b618227#r1.1 (AC6 모호) | Task 6 의 변이 표가 변이마다 RED 를 내야 하는 락 이름을 적는다. 판정은 「각 변이에 그 표의 락이 RED」다 |
| 자리표 유일성 단언(G3 충돌) | `test_review_handoff_order.sh` · `test_plain_gate_templates.sh` 의 「꺾쇠 자리표 하나뿐」을 「꺾쇠 자리표는 줄 앞 `@<…>` 토큰에만 있다」로 바꾼다(Task 3 · 4). 원소가 늘어도 통과한다 — Task 6 변이 M12 가 그 양성 대조다 |

## Review Focus

1. **체크아웃 경로에 공백이 있다** — 평문 줄의 절대경로가 `@` 토큰을 깨므로, 사람은 깨진 줄 대신 「다음 세션 줄을 만들 수 없다」 advisory 를 기대한다. → Task 2 새 락이 두 평문 채택자의 표면에 그 advisory 문구 `[spec-distill] 다음 세션 줄을 만들 수 없다` 가 있는지 잰다.
2. **세션 작업 디렉토리가 git 루트가 아니다(하위 디렉토리 · 다른 터미널)** — 사람은 그래도 파일이 붙기를 기대한다. → 새 락이 두 평문 채택자의 표면에 「절대경로로 치환한 뒤 노출한다」가 있는지, 정본 규칙 5 가 「평문 줄의 경로는 **절대경로**로 쓴다」인지 잰다.
3. **사용자가 두 줄을 한 줄로 붙여 입력한다(`/new @…`)** — 그 텍스트는 세션 이름이 되어 버려진다. 사람은 「따로 입력하라」는 안내를 기대한다. → 새 락이 채택자마다 표면에 `따로 입력` 이 있는지 잰다.
4. **게이트 직전에 brief · 설계문서가 사라졌다** — 사람은 명령 대신 부재 advisory 를 기대한다. → Task 3 이 finishing B-2 의 「두 줄 명령을 노출하지 *않고*」 문구를 `test_conducting_interview_stage.sh` 에 단언으로 더한다.
5. **대화형 세션에서 평문 `@<절대경로>` 첨부** — 헤드리스로만 실측했다. 사람은 대화형에서도 첫 턴에 파일이 붙기를 기대한다. → Task 7 의 끝에서 끝 확인이 대화형으로 잰다(자동 락 없음 — 알려진 한계).

---

## File Structure

| 파일 | 책임 | Task |
|---|---|---|
| `plugins/spec-distill/references/proceed-gate.md` | 정본 — Step B ①·② 고정 · 두 가드에서 「바로 진행」 제거 · 새 절 `## 다음 세션 명령` · 검증 앵커 목록 | 1 |
| `plugins/spec-distill/tests/test_seed_at_path_handoff.sh` | 정본 Step B · 채우는 것 · 두 가드 · 검증 앵커 단언 | 1 |
| `plugins/spec-distill/tests/test_next_session_command.sh` (새) | 정본 `## 다음 세션 명령` 규칙 문구 · 채택자별 다음 세션 줄의 개수 · 모양 · 한도 | 2 |
| `plugins/spec-distill/skills/request-framing/SKILL.md` | 표지 블록 추가 · 두 문단을 정본 포인터로 | 2 |
| `plugins/spec-distill/skills/spec-interview/references/finishing.md` | B-2 라벨 · B-3 표지 블록과 ①·② · B-4 · `/compact` 전제 문장 | 3 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | B-2 라벨 · B-3 블록 · ①·② 창 정지 요건 | 3 |
| `plugins/spec-distill/tests/test_review_handoff_order.sh` | interview 다음 세션 줄 순서(3) · spec-review 표 · 줄 · 정지 요건(4) | 3 · 4 |
| `plugins/spec-distill/tests/test_plain_gate_templates.sh` | ⑥ 다음 세션 줄의 글 규칙 구절 · 자리표 | 3 · 4 |
| `plugins/spec-distill/skills/spec-review/SKILL.md` | 2단계 표 · 표지 블록 · ①/② 정지 요건 · polite stop | 4 |
| `plugins/spec-distill/README.md` · `CLAUDE.md` · `plugin.json` · `CHANGELOG.md` | 문서 · 버전 | 5 |
| `docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md` | 결정 기록에 경로 기준 재결정(D7) 한 줄 | 1 |

---

### Task 0: Baseline 캡처

**Files:** 없음(리포 밖 `~/.claude/sdd-mirror/next-session-at-handoff/baseline/` 에 쓴다)

**Interfaces:**
- Produces: `~/.claude/sdd-mirror/next-session-at-handoff/baseline/fails.txt` — 「테스트 경로<TAB>실패 이름」 줄들. Task 6 이 같은 형식으로 다시 떠서 비교한다.

- [ ] **Step 1: base 이동 확인**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git fetch -q origin && git merge-base --is-ancestor origin/main HEAD && echo BASE_OK
git status --short
```
Expected: `BASE_OK`, 작업 트리 깨끗함. 아니면 멈추고 보고한다.

- [ ] **Step 2: 수집 스크립트를 쓴다**

`~/.claude/sdd-mirror/next-session-at-handoff/collect_fails.sh`:

```bash
#!/usr/bin/env bash
# 사용: collect_fails.sh <출력 디렉토리>  — 리포 루트에서 돈다.
set -u
out="$1"; mkdir -p "$out"; : > "$out/fails.txt"; : > "$out/rc.txt"
for t in plugins/spec-distill/tests/test_*.sh shared/tests/test_*.sh; do
  log="$out/$(echo "$t" | tr '/' '_').log"
  bash "$t" > "$log" 2>&1; rc=$?
  printf '%s\t%s\n' "$rc" "$t" >> "$out/rc.txt"
  grep -E '^[[:space:]]*✗ ' "$log" | sed -E 's/^[[:space:]]*✗ //' | while IFS= read -r n; do
    printf '%s\t%s\n' "$t" "$n" >> "$out/fails.txt"
  done
  if [ "$rc" -ne 0 ] && ! grep -qE '^[[:space:]]*✗ ' "$log"; then
    printf '%s\t%s\n' "$t" "(rc=$rc, ✗ 줄 없음)" >> "$out/fails.txt"
  fi
done
for t in plugins/spec-distill/tests/*.py; do
  log="$out/$(echo "$t" | tr '/' '_').log"
  PYTHONDONTWRITEBYTECODE=1 python3 -m pytest -q -p no:cacheprovider "$t" > "$log" 2>&1; rc=$?
  printf '%s\t%s\n' "$rc" "$t" >> "$out/rc.txt"
  grep -E '^FAILED ' "$log" | sed -E 's/^FAILED ([^ ]+).*/\1/' | while IFS= read -r n; do
    printf '%s\t%s\n' "$t" "$n" >> "$out/fails.txt"
  done
done
sort -o "$out/fails.txt" "$out/fails.txt"
```

- [ ] **Step 3: baseline 을 뜬다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
bash ~/.claude/sdd-mirror/next-session-at-handoff/collect_fails.sh ~/.claude/sdd-mirror/next-session-at-handoff/baseline
wc -l < ~/.claude/sdd-mirror/next-session-at-handoff/baseline/fails.txt
cat ~/.claude/sdd-mirror/next-session-at-handoff/baseline/fails.txt
```
Expected: 실패 이름 목록(선재 RED). 수와 이름을 진행 기록에 적는다 — 비교는 rc 가 아니라 이 이름 집합으로 한다.

---

### Task 1: 정본 — Step B ①·② 고정 · 「바로 진행」 제거 · `## 다음 세션 명령`

**Files:**
- Modify: `plugins/spec-distill/tests/test_seed_at_path_handoff.sh:135-157`
- Modify: `plugins/spec-distill/references/proceed-gate.md`
- Modify: `docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md` (`## 결정 기록` 한 줄)

**Interfaces:**
- Produces: 정본 절 제목 `## 다음 세션 명령`(Step B 와 Step C 사이) · 그 안의 받는 쪽 한도 표 행 `` | `spec-distill:spec-interview` | `## 진입 단계` 2 | 1 | `` · 표지 줄 리터럴 `**다음 세션 줄 — ①/② 공통**`. Task 2 의 락이 이 셋을 읽는다.

- [ ] **Step 1: 락의 정본 단언을 새 문면으로 바꾼다**

`plugins/spec-distill/tests/test_seed_at_path_handoff.sh` 에서 아래 구간(135~157행, `# ── 공유 계약: 정본 자체에 대한 단언` 부터 `assert_contains "$ver" '「호출 모양」 절 옵션 표 ①·② 행' …` 까지)을 통째로 바꾼다.

old_string:
```bash
assert_not_contains "$c1" '/compact' "AC4: Step B ① 행이 /compact 를 못박지 않는다"
assert_contains "$c1" '권장 핸드오프 — skill 이 정한 명령을 노출하고 **턴 종료**' "AC4: ① = 권장 핸드오프, 명령은 skill 이 정한다"
assert_contains "$c2" '차선 핸드오프 — skill 이 정한다' "§2: ② = 차선 핸드오프"
assert_contains "$c2" '바로 진행' "§2: ② 에 바로 진행 선택지가 있다"
fill="$(awk '/^\*\*각 skill 이 채우는 것\*\*/{f=1} f && /^$/{exit} f' "$CANON" | flat)"
assert_contains "$fill" '①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령' "§2: 각 skill 이 채우는 것에 핸드오프 종류"
```
new_string:
```bash
assert_not_contains "$c1" '/compact' "AC4: Step B ① 행이 /compact 를 못박지 않는다"
assert_contains "$c1" '권장 핸드오프 — `/new` 와 다음 세션 줄을 노출하고 **턴 종료**' "AC1(next-session): ① = /new + 다음 세션 줄"
assert_contains "$c2" '차선 핸드오프 — `/compact` 와 같은 다음 세션 줄을 노출하고 **턴 종료**' "AC1(next-session): ② = /compact + 같은 다음 세션 줄"
assert_not_contains "$stepb" '바로 진행' "AC1(next-session): Step B 에 「바로 진행」이 없다 (양성 짝: 위 ①·② 행)"
fill="$(awk '/^\*\*각 skill 이 채우는 것\*\*/{f=1} f && /^$/{exit} f' "$CANON" | flat)"
[ -n "$fill" ] && ok "AC1(next-session)(양성): 「각 skill 이 채우는 것」 문단을 읽었다" || no "AC1(next-session)(양성): 「각 skill 이 채우는 것」 문단이 없다 — 아래 단언이 공허하다"
assert_contains "$fill" '**읽힐 경로 목록과 다음 세션 줄**(`## 다음 세션 명령`)' "AC1(next-session): 각 skill 이 채우는 것 = 경로 목록과 다음 세션 줄"
assert_not_contains "$fill" '바로 진행' "AC1(next-session): 채우는 것에 「바로 진행」이 없다"
```

이어서 같은 파일에서:

old_string:
```bash
g1="$(block '^### 가드 1' '^##' "$CANON" | flat)"
assert_contains "$g1" '완료 동작은 핸드오프 종류가 정한다' "§2: 가드 1 — 완료 동작은 핸드오프 종류가 정한다"
g2="$(block '^### 가드 2' '^##' "$CANON" | flat)"
assert_contains "$g2" 'cross-compact 조기 진행 금지 (AC19)' "§2: 가드 2 제목 유지 (기존 인용이 가리키는 이름)"
assert_contains "$g2" '**명령을 노출하면 그 턴은 거기서 종료(STOP)한다.**' "AC4: 가드 2 — 명령 노출 → 턴 종료"
assert_contains "$g2" '바로 진행 옵션은 이 정지 요건의 **명시적 예외**다' "AC4: 가드 2 — 바로 진행 → 예외"
ver="$(block '^## 검증' '^## ' "$CANON" | flat)"
assert_contains "$ver" '명령을 노출하는 각 옵션의 서술 *블록 안에서*' "§2: 검증 절 리뷰 레이어 = 명령 노출 옵션마다"
assert_contains "$ver" '「호출 모양」 절 옵션 표 ①·② 행' "§2: 앵커 절 — framing 앵커에 ② 행"
```
new_string:
```bash
g1="$(block '^### 가드 1' '^##' "$CANON" | flat)"
[ -n "$g1" ] && ok "AC1(next-session)(양성): 가드 1 블록을 읽었다" || no "AC1(next-session)(양성): 가드 1 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$g1" '①/② 의 완료 동작은 skill 고유 단계를 마친 뒤 두 줄 명령과 위치를 노출하고 턴을 끝내는 것이다' "AC4(next-session): 가드 1 — ①/② 의 완료 = 두 줄과 위치 노출 후 턴 종료"
assert_not_contains "$g1" '바로 진행' "AC1(next-session): 가드 1 에 「바로 진행」이 없다"
g2="$(block '^### 가드 2' '^##' "$CANON" | flat)"
[ -n "$g2" ] && ok "AC1(next-session)(양성): 가드 2 블록을 읽었다" || no "AC1(next-session)(양성): 가드 2 블록이 없다 — 아래 단언이 공허하다"
assert_contains "$g2" 'cross-compact 조기 진행 금지 (AC19)' "§2: 가드 2 제목 유지 (기존 인용이 가리키는 이름)"
assert_contains "$g2" '**명령을 노출하면 그 턴은 거기서 종료(STOP)한다.**' "AC4: 가드 2 — 명령 노출 → 턴 종료"
assert_contains "$g2" '①/②(`/new` · `/compact`)를 고르면' "AC1(next-session): 가드 2 — 대상은 ①/②"
assert_not_contains "$g2" '바로 진행' "AC1(next-session): 가드 2 에 「바로 진행」이 없다"
assert_not_contains "$g2" '명시적 예외' "AC1(next-session): 가드 2 의 정지 요건에 예외가 없다"
ver="$(block '^## 검증' '^## ' "$CANON" | flat)"
assert_contains "$ver" '명령을 노출하는 각 옵션의 서술 *블록 안에서*' "§2: 검증 절 리뷰 레이어 = 명령 노출 옵션마다"
assert_contains "$ver" '「호출 모양」 절 옵션 표 ①·② 행' "§2: 앵커 절 — framing 앵커에 ② 행"
assert_contains "$ver" '「①/② 의 정지 요건」 불릿' "AC1(next-session): 앵커 절 — spec-review 앵커가 ①/②"
assert_contains "$ver" '「다음 세션 줄 — ①/② 공통」 블록' "AC1(next-session): 앵커 절 — 세 skill 의 표지 블록"
```

- [ ] **Step 2: RED 를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh | grep -E '✗|^Total'`
Expected: `✗` 줄이 `AC1(next-session)` · `AC4(next-session)` 단언들에서 나온다(① 행 · ② 행 · Step B 바로 진행 · 채우는 것 둘 · 가드 1 둘 · 가드 2 의 「①/②(`/new`…」 · 바로 진행 · 명시적 예외 · 앵커 둘). 그 밖의 기존 단언은 `✓`.

- [ ] **Step 3: 정본을 고친다 — 「각 skill 이 채우는 것」**

`plugins/spec-distill/references/proceed-gate.md`

old_string:
```
**①/② 의 핸드오프 종류(`/compact` · `/new` · 바로 진행)와 노출할 명령** ·
```
new_string:
```
**읽힐 경로 목록과 다음 세션 줄**(`## 다음 세션 명령`) ·
```

- [ ] **Step 4: Step B 표 ①·② 행**

old_string:
```
| ① | 권장 핸드오프 — skill 이 정한 명령을 노출하고 **턴 종료** |
| ② | 차선 핸드오프 — skill 이 정한다: 명령을 노출하고 **턴 종료**, 또는 바로 진행 |
```
new_string:
```
| ① | 권장 핸드오프 — `/new` 와 다음 세션 줄을 노출하고 **턴 종료** |
| ② | 차선 핸드오프 — `/compact` 와 같은 다음 세션 줄을 노출하고 **턴 종료** |
```

- [ ] **Step 5: 새 절 `## 다음 세션 명령` 을 Step C 앞에 넣는다**

old_string:
```
## Step C — 두 가드
```
new_string:
```
## 다음 세션 명령

①/② 가 노출하는 명령의 공통 규칙이다.

1. **두 줄, 따로 입력.** 첫 줄은 `/new`(①) 또는 맨 `/compact`(②)다. 둘째 줄(「다음 세션 줄」)은 ①·② 가 같다.
   `/new` 뒤 같은 줄의 텍스트는 세션 이름이 되고 `/compact` 뒤 텍스트는 요약 지시로만 쓰인다. 그래서
   두 줄을 따로 입력하라는 안내를 명령과 함께 낸다.
2. **읽힐 경로 목록.** 각 skill 은 읽힐 경로 목록(1개 이상)을 정한다. 첫 원소가 주 산출물이다. 다음 세션 줄은
   원소마다 `@<경로>` 토큰을 하나씩, 공백으로 나눠 줄 맨 앞(slash 줄이면 skill 이름 바로 뒤)에 목록 순서대로 둔다.
   파일을 더할 때는 그 skill 의 목록에 원소를 더하고, 이 규칙은 고치지 않는다.
3. **줄의 모양은 받는 쪽이 정한다.**
   - 받는 쪽이 진입 단계에서 `@` 를 스스로 푸는 skill 이면 slash 줄 `/<plugin>:<skill> @<경로>…` 다. 목록 길이는
     아래 표의 그 받는 쪽 한도를 넘지 못한다.
   - 그 밖의 받는 쪽(외부 skill)이면 평문 줄이다. `@` 토큰들로 시작하고, 그 뒤에 부를 skill 과 그 skill 이 정한
     운반 문장을 잇는다. 토큰마다 하니스가 파일을 첨부하므로 경로 수 제한이 없다.
4. **받는 쪽 한도 표.**

   | 받는 쪽 | `@` 를 푸는 자리 | 받을 수 있는 경로 수 |
   |---|---|---|
   | `spec-distill:spec-interview` | `## 진입 단계` 2 | 1 |
   | 외부 skill (평문 줄) | 하니스 첨부 | 제한 없음 |

5. **경로 표기 · 치환 · 거부.**
   - 평문 줄의 경로는 **절대경로**로 쓴다. 하니스는 평문 `@` 의 상대경로를 세션 작업 디렉토리 기준으로 풀고, 그
     디렉토리는 git 작업 트리 루트와 다를 수 있다. 절대경로는 어느 작업 디렉토리에서도 첨부된다.
   - slash 줄의 경로는 받는 쪽이 푸는 기준으로 쓴다. spec-interview 는 감시줄 `root=`(git 작업 트리 루트)
     기준이므로 그 루트 기준 상대경로다.
   - 모든 자리표를 실제 경로로 치환한 뒤 노출한다. 치환하지 않은 자리표가 하나라도 남거나 경로에 공백이 있으면
     노출하지 않는다 — advisory 한 줄을 내고 멈춘다. 깨진 줄을 사용자가 실행하면 그것을 잡는 자리가 없다.
6. **Step A 를 모든 원소에.** 원소 하나라도 working-tree 에 없으면 명령을 노출하지 않는다. 없는 경로를 전부
   담아 Step A advisory 를 낸다. 존재 확인은 그 줄이 쓰는 기준(규칙 5)으로 한다.
7. **위치 공시.** 명령과 함께 git 작업 트리 루트의 절대경로를 낸다. 워크트리 안이면 그 워크트리 루트이고,
   작업 트리 밖이면 `pwd` 다. 다른 터미널에서 새 세션을 열 때 그 디렉토리에서 연다.

각 skill 은 다음 세션 줄을 자기 표면에 **한 번만** 정의한다 — 단독 줄 `**다음 세션 줄 — ①/② 공통**` 바로
아래의 인용 줄 하나다. ①·② 서술은 첫 줄과 그 블록을 가리킨다.

## Step C — 두 가드
```

- [ ] **Step 6: 가드 1 — 완료 동작**

old_string:
```
polite stop 이다. 완료 동작은 핸드오프 종류가 정한다 — 명령을 노출하는 옵션은 명령 노출(그 뒤
턴 종료), 바로 진행 옵션은 다음 단계 진입이다. 게이트를 **실제로 띄우는 것** 이 이 금지를 푸는
```
new_string:
```
polite stop 이다. ①/② 의 완료 동작은 skill 고유 단계를 마친 뒤 두 줄 명령과 위치를 노출하고 턴을 끝내는 것이다 —
명령을 노출하지 않고 설명만 하고 끝내면 polite stop 이다. 게이트를 **실제로 띄우는 것** 이 이 금지를 푸는
```

- [ ] **Step 7: 가드 2 — 대상과 예외 문단**

old_string:
```
명령을 노출하는 옵션(`/compact` · `/new` 등)을 고르면 그 명령을 노출한 **직후 같은 턴에서** 다음
```
new_string:
```
①/②(`/new` · `/compact`)를 고르면 그 명령을 노출한 **직후 같은 턴에서** 다음
```

old_string:
```
두 방향 모두 게이트의 사용자-주권(P17)을 우회한다.

바로 진행 옵션은 이 정지 요건의 **명시적 예외**다 (다음 단계로 즉시 진행).
```
new_string:
```
두 방향 모두 게이트의 사용자-주권(P17)을 우회한다.
```

- [ ] **Step 8: 「검증」 절 앵커 목록**

old_string:
```
기계적 레이어의 앵커는 **각 skill 의 명령 노출 옵션 서술 블록**에 산다 — `spec-review` 의
`## 게이트` 절 옵션 표 ① 행과 그 아래 「① 의 정지 요건」 불릿, `spec-interview` 의
`#### B-3` ①, `request-framing` 의 「호출 모양」 절 옵션 표 ①·② 행이다.
```
new_string:
```
기계적 레이어의 앵커는 **각 skill 의 명령 노출 옵션 서술 블록**에 산다 — `spec-review` 의
`## 게이트` 절 옵션 표 ①·② 행과 그 아래 「①/② 의 정지 요건」 불릿, `spec-interview` 의
`#### B-3` ①·②, `request-framing` 의 「호출 모양」 절 옵션 표 ①·② 행, 그리고 세 skill 의
「다음 세션 줄 — ①/② 공통」 블록이다.
```

- [ ] **Step 9: GREEN 을 확인한다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/spec-distill/tests/test_seed_at_path_handoff.sh | grep -E '✗|^Total'
bash plugins/spec-distill/tests/test_proceed_gate_adopters.sh | grep -E '✗|^Total'
bash plugins/spec-distill/tests/test_plain_gate_templates.sh | grep -E '✗|^Total'
grep -n '바로 진행' plugins/spec-distill/references/proceed-gate.md
```
Expected: 세 락 모두 `Fail: 0`. 마지막 grep 은 출력 없음.

- [ ] **Step 10: 설계문서에 재결정 기록을 남긴다**

계획 리뷰에서 사용자가 경로 기준 재결정(Global Constraints 의 표 첫 행)을 승인했을 때만 한다 — 승인하지 않았으면 멈추고 보고한다.
`docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md` 의 `## 결정 기록` 에서

old_string:
```
- D6. 읽힐 파일은 경로 목록이다. 받는 쪽 한도는 정본 표가 쥔다. (사용자, 2026-10-11)
```
new_string:
```
- D6. 읽힐 파일은 경로 목록이다. 받는 쪽 한도는 정본 표가 쥔다. (사용자, 2026-10-11)
- D7(재결정 · 규칙 5 경로 표기). 원래: 다음 세션 줄의 경로는 git 작업 트리 루트 기준 상대경로. 재결정: 평문 줄은 절대경로, slash 줄은 받는 쪽이 푸는 기준(spec-interview 는 `root=` 기준 상대경로). 근거: 헤드리스 실측(2026-10-11) — 평문 `@` 의 상대경로는 세션 작업 디렉토리 기준으로 풀렸고(하위 디렉토리에서 루트의 `@a.md` → `NONE`), 절대경로는 어느 작업 디렉토리에서도 첨부됐다. (사용자 승인, 계획 리뷰)
```

- [ ] **Step 11: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git commit -m "feat(spec-distill): proceed 게이트 정본에 다음 세션 명령 규칙을 둔다

①은 /new, ②는 /compact 로 고정하고 「바로 진행」 예외를 없앤다.
다음 세션 줄의 경로 목록 · 받는 쪽 한도 · 경로 표기 규칙을 새 절에 둔다.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/tests/test_seed_at_path_handoff.sh docs/superpowers/specs/2026-10-11-next-session-at-handoff-design.md
git show --stat HEAD | tail -3
```
Expected: 3 files changed.

---

### Task 2: 새 락 `test_next_session_command.sh` + request-framing 표지 블록

**Files:**
- Create: `plugins/spec-distill/tests/test_next_session_command.sh` (실행 비트)
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md` (「호출 모양」 절)

**Interfaces:**
- Consumes: Task 1 의 정본 절 `## 다음 세션 명령` · 한도 표 행 · 표지 줄 리터럴.
- Produces: 채택자마다 표지 줄 `**다음 세션 줄 — ①/② 공통**` 과 그 아래 인용 줄 `` > `…` `` 를 요구하는 락. Task 3 · 4 가 이 락의 spec-interview · spec-review 단언을 GREEN 으로 만든다. 평문 채택자에게는 표면 문구 `절대경로로 치환한 뒤 노출한다` · `[spec-distill] 다음 세션 줄을 만들 수 없다` 와, 모든 채택자에게 `따로 입력` 을 요구한다.

- [ ] **Step 1: 새 락을 쓴다**

`plugins/spec-distill/tests/test_next_session_command.sh`:

```bash
#!/usr/bin/env bash
# guards: plugins/spec-distill/**
#
# 다음 세션 명령 — 정본 `references/proceed-gate.md` 의 `## 다음 세션 명령` 절과 그 채택자.
#
# 채택자는 정본 포인터에서 도출한다(`shared/tests/adopter_derivation.sh`, 바닥 3). 채택자마다 자기 표면
# (SKILL.md + references/*.md)에서 잰다:
#   - 단독 줄 `**다음 세션 줄 — ①/② 공통**` 이 정확히 하나이고, 그 아래 첫 비지 않은 줄이 `> `…`` 인용 줄이다.
#   - 다음 세션 줄 모양의 인용 줄(`> `@<` · `> `/<plugin>:<skill> @`, 들여쓰기 포함)이 표면 전체에 정확히 하나다.
#     ①·② 가 줄을 따로 정의하거나 표지 밖에 줄을 두면 2 가 된다.
#   - slash 줄: skill 이름 바로 뒤 `@<…>` 토큰 수 ≤ 정본 한도 표의 그 받는 쪽 수. 락은 숫자를 들지 않는다.
#   - 평문 줄: `@<…>` 토큰으로 시작하고 토큰 뒤에 `Skill ` 호출이 온다. 절대경로 치환 · 거부 advisory 문구가 표면에 있다.
#   - 꺾쇠 자리표는 줄 앞 `@<…>` 토큰에만 있다. 원소(토큰)가 늘어도 통과한다.
#   - 표면에 `따로 입력` 이 있다.
# 정본 절 단언에는 그 절을 실제로 읽었다는 양성 짝이 붙는다.
set -u
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill"
CANON="$SD/references/proceed-gate.md"
CANON_REF='references/proceed-gate\.md'
. "$REPO_ROOT/shared/tests/assert.sh"
. "$REPO_ROOT/shared/tests/adopter_derivation.sh"

derive_reference_adopters "$SD" "$CANON_REF" "$REPO_ROOT" 0
if [ "${1:-}" = "--emit-scanned" ]; then
  { printf '%s' "$SCANNED"; printf '%s\n' "$CANON"; } | sed "s|^$REPO_ROOT/||"
  exit 0
fi

n_adopt=0
ADOPTER_ARGS=()
while IFS= read -r a; do
  [ -n "$a" ] || continue
  n_adopt=$((n_adopt + 1))
  ADOPTER_ARGS+=("$a")
done < <(printf '%s' "$ADOPTERS")
if [ "$n_adopt" -ge 3 ]; then
  ok "채택자 ${n_adopt}개 도출 (정본 포인터, 바닥 3)"
else
  no "채택자 ${n_adopt}개 — 바닥 3 미만이다. 포인터를 잃은 skill 이 측정 밖으로 나갔다"
fi
if [ ! -f "$CANON" ]; then
  no "정본 ${CANON} 부재"
  finish; exit $?
fi

tmp="$(mktemp)" || { no "mktemp 실패 — 측정하지 못했다"; finish; exit $?; }
trap 'rm -f "$tmp"' EXIT
PYTHONDONTWRITEBYTECODE=1 python3 - "$CANON" "${ADOPTER_ARGS[@]+"${ADOPTER_ARGS[@]}"}" >"$tmp" <<'PY'
import pathlib
import re
import sys

MARK = "**다음 세션 줄 — ①/② 공통**"
TOKEN = r"@<[^<>]+>"
LINE_SHAPE = re.compile(r"^\s*> `(@<|/[\w-]+:[\w-]+ @)")
out = []


def ok(m):
    out.append("OK\t" + m)


def no(m):
    out.append("NO\t" + m)


def flat(s):
    return " ".join(s.split())


canon = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
m = re.search(r"^## 다음 세션 명령\n(.*?)(?=^## |\Z)", canon, re.S | re.M)
sec = m.group(1) if m else ""
if sec.strip():
    ok("정본(양성): `## 다음 세션 명령` 절을 읽었다")
else:
    no("정본: `## 다음 세션 명령` 절이 없다 — 아래 정본 단언이 공허하다")
fsec = flat(sec)
for label, needle in [
    ("규칙 1 두 줄 따로", "두 줄을 따로 입력하라는 안내"),
    ("규칙 2 경로 목록", "각 skill 은 읽힐 경로 목록(1개 이상)을 정한다"),
    ("규칙 2 토큰 반복", "원소마다 `@<경로>` 토큰을 하나씩"),
    ("규칙 3 받는 쪽이 모양을 정한다", "줄의 모양은 받는 쪽이 정한다"),
    ("규칙 5 평문 줄은 절대경로", "평문 줄의 경로는 **절대경로**로 쓴다"),
    ("규칙 5 slash 줄은 받는 쪽 기준", "slash 줄의 경로는 받는 쪽이 푸는 기준으로 쓴다"),
    ("규칙 5 치환 · 공백 거부", "치환하지 않은 자리표가 하나라도 남거나 경로에 공백이 있으면 노출하지 않는다"),
    ("규칙 6 Step A 전 원소", "원소 하나라도 working-tree 에 없으면 명령을 노출하지 않는다"),
    ("규칙 7 위치 공시", "git 작업 트리 루트의 절대경로를 낸다"),
    ("표지 정의", MARK),
]:
    (ok if needle in fsec else no)(f"정본 {label}: {needle}")

limits = {}
for row in re.finditer(r"^\s*\|\s*`([^`]+)`\s*\|[^|\n]*\|\s*(\d+)\s*\|\s*$", sec, re.M):
    limits[row.group(1)] = int(row.group(2))
if "spec-distill:spec-interview" in limits:
    ok(f"정본 한도 표(양성): spec-distill:spec-interview 한도 {limits['spec-distill:spec-interview']} 를 읽었다")
else:
    no("정본 한도 표: spec-distill:spec-interview 행이 없다 — slash 줄 한도를 잴 수 없다")
if re.search(r"^\s*\|\s*외부 skill[^|\n]*\|[^|\n]*\|\s*제한 없음\s*\|\s*$", sec, re.M):
    ok("정본 한도 표: 외부 skill(평문 줄) = 제한 없음")
else:
    no("정본 한도 표: 외부 skill(평문 줄) 행이 없다")

for d in sys.argv[2:]:
    d = pathlib.Path(d)
    name = d.name
    files = [d / "SKILL.md"] + sorted((d / "references").glob("*.md"))
    files = [f for f in files if f.is_file()]
    texts = {f: f.read_text(encoding="utf-8").splitlines() for f in files}
    body = flat("\n".join("\n".join(t) for t in texts.values()))
    (ok if "따로 입력" in body else no)(f"{name}: 표면에 「따로 입력」 안내가 있다")
    marks = [(f, i) for f in files for i, l in enumerate(texts[f]) if l.strip() == MARK]
    if len(marks) != 1:
        no(f"{name}: 표지 줄이 {len(marks)}개 — 정확히 1개여야 한다")
        continue
    ok(f"{name}: 표지 줄 1개 ({marks[0][0].name}:{marks[0][1] + 1})")
    f, i = marks[0]
    rest = [l for l in texts[f][i + 1:] if l.strip()]
    nxt = rest[0] if rest else ""
    q = re.fullmatch(r"> `(.+)`", nxt)
    if not q:
        no(f"{name}: 표지 아래 첫 줄이 인용 줄 `> `…`` 이 아니다: {nxt[:80]}")
        continue
    line = q.group(1)
    shaped = [f"{g.name}:{j + 1}" for g in files for j, l in enumerate(texts[g]) if LINE_SHAPE.match(l)]
    if len(shaped) == 1:
        ok(f"{name}: 다음 세션 줄 모양의 인용 줄이 표면에 1개")
    else:
        no(f"{name}: 다음 세션 줄 모양의 인용 줄이 {len(shaped)}개 — ①·② 가 줄을 따로 정의했거나 표지 밖에 줄이 있다: {shaped}")
    if line.startswith("/"):
        s = re.match(rf"/([\w-]+:[\w-]+)((?: {TOKEN})+)(?= |$)", line)
        if not s:
            no(f"{name}: slash 줄인데 skill 이름 바로 뒤에 `@<…>` 토큰이 없다: {line[:80]}")
            continue
        recv = s.group(1)
        n = len(re.findall(TOKEN, s.group(2)))
        tail = line[s.end():]
        if recv not in limits:
            no(f"{name}: slash 줄의 받는 쪽 {recv} 이 정본 한도 표에 없다")
        elif n <= limits[recv]:
            ok(f"{name}: slash 줄 @ 토큰 {n}개 ≤ {recv} 한도 {limits[recv]}")
        else:
            no(f"{name}: slash 줄 @ 토큰 {n}개 > {recv} 한도 {limits[recv]}")
    else:
        p = re.match(rf"((?:{TOKEN} )+)", line)
        if not p:
            no(f"{name}: 평문 줄이 `@<…>` 토큰으로 시작하지 않는다: {line[:80]}")
            continue
        n = len(re.findall(TOKEN, p.group(1)))
        tail = line[p.end():]
        ok(f"{name}: 평문 줄이 @ 토큰 {n}개로 시작한다")
        (ok if "Skill " in tail else no)(f"{name}: 평문 줄이 토큰 뒤에 부를 skill(`Skill …`)을 잇는다")
        for needle in ("절대경로로 치환한 뒤 노출한다", "[spec-distill] 다음 세션 줄을 만들 수 없다"):
            (ok if needle in body else no)(f"{name}: 평문 줄 규칙 문구 — {needle}")
    left = re.findall(r"<[^<>]+>", tail)
    if left:
        no(f"{name}: 꺾쇠 자리표가 줄 앞 @ 토큰 밖에 있다: {left}")
    else:
        ok(f"{name}: 꺾쇠 자리표는 줄 앞 @ 토큰에만 있다")

print("\n".join(out))
print("END")
PY
prc=$?
if [ "$prc" -ne 0 ]; then
  no "파서 실패(rc=${prc}) — 측정하지 못했다"
  cat "$tmp"
fi
grep -qx 'END' "$tmp" || no "파서 출력이 끝까지 오지 않았다(END 없음) — 단언이 잘렸다"
while IFS=$'\t' read -r kind msg; do
  case "$kind" in
    OK) ok "$msg" ;;
    NO) no "$msg" ;;
  esac
done < "$tmp"
finish
```

그리고:
```bash
chmod +x /Users/jeonghokim/Downloads/devbrew/plugins/spec-distill/tests/test_next_session_command.sh
```

- [ ] **Step 2: RED 를 확인한다**

Run: `cd /Users/jeonghokim/Downloads/devbrew && bash plugins/spec-distill/tests/test_next_session_command.sh | grep -E '✗|^Total'`
Expected: `Fail: 6` — 채택자 셋 각각의 `표면에 「따로 입력」 안내가 있다` 와 `표지 줄이 0개 — 정확히 1개여야 한다`. 정본 단언(규칙 1~7 · 표지 정의 · 한도 표 둘)과 채택자 도출은 전부 `✓`.

- [ ] **Step 3: request-framing — 표지 블록을 더한다**

`plugins/spec-distill/skills/request-framing/SKILL.md`

old_string:
```
치환하지 않은 자리표가 나가면 사용자가 깨진 명령을 실행하고, 그것을 잡는 자리가 없습니다.
```
new_string:
```
치환하지 않은 자리표가 나가면 사용자가 깨진 명령을 실행하고, 그것을 잡는 자리가 없습니다.

**다음 세션 줄 — ①/② 공통**

> `/spec-distill:spec-interview @<seed 경로>`
```

- [ ] **Step 4: request-framing — 두 줄 안내 문단을 정본 포인터로**

old_string:
```
`/new` 뒤 같은 줄에 텍스트를 붙이면 그 텍스트는 세션 이름이 됩니다 — 두 줄을 **따로** 입력하라는 안내를
명령과 함께 냅니다. `/compact` 뒤 텍스트도 요약 지시로만 쓰이고 다음 프롬프트로 가지 않으므로 ② 도 같습니다.
```
new_string:
```
`/new` 뒤 같은 줄에 붙인 텍스트는 세션 이름이 되므로, 두 줄을 따로 입력하라는 안내를 명령과 함께 냅니다.
두 줄 명령의 공통 규칙(따로 입력 · 치환 · 위치 공시)은 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 `## 다음 세션 명령` 이 정본입니다.
```

- [ ] **Step 5: request-framing — 위치 공시 문장을 정본 포인터로**

old_string:
```
적습니다. ①/② 의 «다음 세션 첫 턴» 안내에는 **워크트리 절대경로**(`pwd`)를 함께 냅니다 —
다른 터미널에서 새 세션을 열 때 그 디렉토리에서 열어야 `@<seed 경로>` 가 풀리기 때문입니다.
```
new_string:
```
적습니다. ①/② 의 «다음 세션 첫 턴» 안내에는 위치(워크트리면 그 워크트리의 절대경로)를 함께 냅니다 —
정본 `## 다음 세션 명령` 규칙 7.
```

- [ ] **Step 6: request-framing 몫이 GREEN 인지 확인한다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
bash plugins/spec-distill/tests/test_next_session_command.sh | grep -E '✗|^Total'
for t in test_seed_at_path_handoff test_request_framing_entry test_proceed_gate_adopters test_plain_gate_templates; do
  echo "== $t"; bash plugins/spec-distill/tests/$t.sh | grep -E '✗|^Total'; done
```
Expected: 새 락 `Fail: 4` — 남은 `✗` 는 `spec-interview:` · `spec-review:` 의 「따로 입력」 · 「표지 줄이 0개」 넷뿐이다(Task 3 · 4 몫). `request-framing:` 단언은 전부 `✓`(따로 입력 · 표지 1 · 인용 줄 1 · slash 토큰 1 ≤ 한도 1 · 자리표). 나머지 네 락은 `Fail: 0`.

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git add plugins/spec-distill/tests/test_next_session_command.sh
git commit -m "test(spec-distill): 다음 세션 줄 락을 더하고 request-framing 에 표지를 둔다

채택자마다 다음 세션 줄이 하나인지, 모양과 받는 쪽 한도를 지키는지 잰다.
request-framing 은 줄의 글자를 그대로 두고 표지 블록만 더한다.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/tests/test_next_session_command.sh plugins/spec-distill/skills/request-framing/SKILL.md
git show --stat HEAD | tail -3
git ls-files -s plugins/spec-distill/tests/test_next_session_command.sh | cut -c1-6
```
Expected: 2 files changed. 모드 `100755`. (spec-interview · spec-review 단언 RED 는 Task 3 · 4 가 닫는다.)

---

### Task 3: spec-interview — B-2 라벨 · B-3 다음 세션 줄 · B-4

**Files:**
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh:119-132, 155-172`
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh:44-66`
- Modify: `plugins/spec-distill/tests/test_plain_gate_templates.sh:48-53`
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md`

**Interfaces:**
- Consumes: Task 2 락의 표지 · 평문 줄 · 문구 요구.
- Produces: finishing.md B-3 의 표지 블록과 그 아래 줄 `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. …`. B-2 라벨 `확정하고 /new 후 brainstorming (권장)` · `확정하고 /compact 후 brainstorming`.

- [ ] **Step 1: `test_conducting_interview_stage.sh` — B-2 라벨**

old_string:
```bash
grep -qF '확정하고 /compact 후 brainstorming' <<<"$b2_block" \
  && ok "AC2: 옵션 ① 라벨 (확정 + /compact, B-2 스코프)" \
  || no "AC2: 옵션 ① 라벨이 B-2 게이트에 없다"
grep -qF '확정하고 바로 brainstorming' <<<"$b2_block" \
  && ok "AC2: 옵션 ② 라벨 (확정 + 즉시, B-2 스코프)" \
  || no "AC2: 옵션 ② 라벨이 B-2 게이트에 없다"
```
new_string:
```bash
grep -qF '{label: "확정하고 /new 후 brainstorming (권장)"' <<<"$b2_block" \
  && ok "AC2: 옵션 ① 라벨 (확정 + /new, 권장, B-2 스코프)" \
  || no "AC2: 옵션 ① 라벨이 B-2 게이트에 없다"
grep -qF '{label: "확정하고 /compact 후 brainstorming"' <<<"$b2_block" \
  && ok "AC2: 옵션 ② 라벨 (확정 + /compact, B-2 스코프)" \
  || no "AC2: 옵션 ② 라벨이 B-2 게이트에 없다"
grep -F '{label:' <<<"$b2_block" | grep -qF '바로' \
  && no "AC4(next-session): B-2 옵션 라벨에 「바로」 진행이 남았다" \
  || ok "AC4(next-session): B-2 옵션 라벨에 「바로」 진행이 없다 (양성 짝: 위 라벨 둘)"
grep -qF '두 줄 명령을 노출하지 *않고*' <<<"$b2_block" \
  && ok "Review Focus 4: brief 부재면 두 줄 명령을 노출하지 않는다 (B-2 스코프)" \
  || no "Review Focus 4: B-2 의 brief 부재 경로가 두 줄 명령 비노출을 말하지 않는다"
```

- [ ] **Step 2: 같은 파일 — 옛 `/compact` 템플릿 단언**

old_string:
```bash
# 이건 전-파일로 둔다 — SKILL 전체에서 1회뿐이라 이미 이빨이 있다.
has '/compact interview brief at' "AC20: verbatim /compact 명령 노출"
```
new_string:
```bash
# 다음 세션 줄 — B-3 표지 블록의 한 줄. 줄의 개수 · 모양은 test_next_session_command.sh 가 잰다.
nsl_iv="$(awk -v m='**다음 세션 줄 — ①/② 공통**' '$0==m{f=1;next} f&&NF{print;exit}' "$FIN")"
[[ -n "$nsl_iv" ]] && ok "AC20: B-3 의 다음 세션 줄을 읽었다" || no "AC20: B-3 의 다음 세션 줄 표지 블록이 없다"
grep -qF '이 interview brief 로 Skill superpowers:brainstorming 을 시작하라' <<<"$nsl_iv" \
  && ok "AC20: 다음 세션 줄이 brainstorming 을 부른다" \
  || no "AC20: 다음 세션 줄이 brainstorming 을 부르지 않는다"
grep -qF '/compact interview brief at' "${CI_ALL[@]}" \
  && no "AC4(next-session): 옛 /compact 보존 템플릿이 남았다" \
  || ok "AC4(next-session): 옛 /compact 보존 템플릿이 없다 (양성 짝: 위 다음 세션 줄)"
```

- [ ] **Step 3: 같은 파일 — AC3 · C5 를 다음 세션 줄과 ①·② 창으로**

old_string:
```bash
b3_opt1="$(awk '/^- \*\*① /{f=1} /^- \*\*② /{f=0} f' <<<"$b3_block")"
b3_opt2="$(awk '/^- \*\*② /{f=1} /^- \*\*③ /{f=0} f' <<<"$b3_block")"
c4_1=$(grep -cF '보고 후 재결정' <<<"$b3_opt1")
c4_2=$(grep -cF '보고 후 재결정' <<<"$b3_opt2")
{ [[ "$c4_1" -ge 1 ]] && [[ "$c4_2" -ge 1 ]]; } \
  && ok "AC3: C4 프로토콜이 ①/② 각 경로에 실림 (①=$c4_1 ②=$c4_2)" \
  || no "AC3: C4 프로토콜이 양쪽 경로에 있지 않다 (①=$c4_1 ②=$c4_2)"
grep -qE '임의 변경.*금지' <<<"$b3_block" \
  && ok "AC3: 임의 변경 금지 절반이 명시됨" || no "AC3: 임의 변경 금지가 없다"

# C5: 규약은 brief가 아니라 호출 프롬프트에 산다
grep -qE '호출 프롬프트|invocation prompt' <<<"$b3_block" \
  && ok "C5: 규약의 거처가 호출 프롬프트로 명시됨" \
  || no "C5: 규약이 brief에 실리지 않는다는 명시가 없다"
```
new_string:
```bash
# ①·② 는 한 줄을 공유한다 — C4 는 그 줄에 실리고, ①·② 창은 그 줄을 가리키며 정지 요건 셋을 갖는다.
b3_opt1="$(awk '/^- \*\*① /{f=1} /^- \*\*② /{f=0} f' <<<"$b3_block")"
b3_opt2="$(awk '/^- \*\*② /{f=1} /^- \*\*③ /{f=0} f' <<<"$b3_block")"
nsl_b3="$(awk -v m='**다음 세션 줄 — ①/② 공통**' '$0==m{f=1;next} f&&NF{print;exit}' <<<"$b3_block")"
grep -qF '보고 후 재결정' <<<"$nsl_b3" \
  && ok "AC3: C4 프로토콜이 ①·② 공통 다음 세션 줄에 실림" \
  || no "AC3: B-3 의 다음 세션 줄에 C4 프로토콜이 없다"
grep -qE '임의 변경.*금지' <<<"$nsl_b3" \
  && ok "AC3: 임의 변경 금지 절반이 다음 세션 줄에 있다" || no "AC3: 다음 세션 줄에 임의 변경 금지가 없다"
for w in 1 2; do
  wv="b3_opt${w}"; win="${!wv}"
  if [[ -z "$win" ]]; then no "AC4(next-session): B-3 옵션 ${w} 창이 비었다 — 아래 단언이 공허하다"; continue; fi
  for n in '다음 세션 줄' '턴 종료(STOP)' '다음 턴' '사용자 트리거'; do
    grep -qF "$n" <<<"$win" && ok "AC4(next-session): B-3 옵션 ${w} 창에 ${n}" || no "AC4(next-session): B-3 옵션 ${w} 창에 ${n} 이 없다"
  done
  grep -qF '바로' <<<"$win" && no "AC4(next-session): B-3 옵션 ${w} 창에 「바로」 진행이 남았다" || ok "AC4(next-session): B-3 옵션 ${w} 창에 「바로」 진행이 없다"
done

# C5: 규약은 brief가 아니라 호출 프롬프트(= 다음 세션 줄)에 산다
c5_par="$(awk '/^\*\*규약의 거처 \(C5\)\.\*\*/{f=1} f&&/^$/{exit} f' <<<"$b3_block")"
grep -qE '호출 프롬프트|invocation prompt' <<<"$c5_par" \
  && ok "C5: 규약의 거처가 호출 프롬프트로 명시됨" \
  || no "C5: 규약이 brief에 실리지 않는다는 명시가 없다"
grep -qF '다음 세션 줄' <<<"$c5_par" \
  && ok "C5(next-session): 규약의 거처 = 다음 세션 줄" \
  || no "C5(next-session): 규약의 거처 문단이 다음 세션 줄을 말하지 않는다"
```

- [ ] **Step 4: `test_review_handoff_order.sh` — interview 다음 세션 줄로 대상을 옮긴다**

old_string(44~66행, `# ── ① /compact 템플릿` 부터 ② 블록의 `fi` 까지):
```bash
# ── ① /compact 템플릿 — 사용자가 그대로 붙여넣는 한 줄 ──────────────────────
ONE="$(grep -F '/compact interview brief at' "$FIN" || true)"
n1="$(printf '%s' "$ONE" | grep -c . || true)"
if [ "$n1" = "1" ]; then
  ok "① 템플릿 줄이 정확히 하나"
  order "① 템플릿" "$ONE" "Skill superpowers:brainstorming" "spec-distill:spec-review"
  order "① 템플릿" "$ONE" "spec-distill:spec-review" "writing-plans"
  # 치환되지 않은 placeholder 를 잡는 fail-closed 검사가 없다(finishing.md 가 스스로 적는다) —
  # 새 꺾쇠 자리를 들이지 않는다.
  ph="$(printf '%s' "$ONE" | grep -oE '<[^>]+>' | sort -u | tr '\n' ' ')"
  assert_eq "$ph" "<brief-path> " "① 템플릿의 꺾쇠 placeholder 는 <brief-path> 하나뿐"
else
  no "① 템플릿 줄이 ${n1}개 — 정확히 하나여야 한다"
fi

# ── ② 호출 프롬프트 ─────────────────────────────────────────────────────────
TWO="$(awk '/^- \*\*② 확정하고 바로 brainstorming\*\*/{f=1} /^- \*\*③/{f=0} f' "$FIN")"
if nonempty "②" "$TWO"; then
  order "② 호출 프롬프트" "$TWO" "Skill superpowers:brainstorming" "spec-distill:spec-review"
  order "② 호출 프롬프트" "$TWO" "spec-distill:spec-review" "writing-plans"
  assert_contains "$TWO" "보다 이 순서가 우선한다" "②: brainstorming 의 「다음은 writing-plans 뿐」보다 우선한다고 적는다"
  assert_contains "$TWO" "게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다" "②: 게이트 없는 종료의 복귀 분기를 싣는다 (AC16)"
fi
```
new_string:
```bash
# ── 다음 세션 줄 — 표지 블록의 한 줄 (①·② 공통) ────────────────────────────
NSL_MARK='**다음 세션 줄 — ①/② 공통**'
nsl() { awk -v m="$NSL_MARK" '$0==m{f=1;next} f&&NF{print;exit}' "$1" | sed -e 's/^> `//' -e 's/`$//'; }
# 줄 앞 `@<…>` 토큰들을 다루는 셋 — 목록 원소(토큰)가 늘어도 같은 판정이 나온다(설계 G3).
#   lead_only <줄>        꺾쇠 자리표가 줄 앞 토큰에만 있으면 ok
#   split_line <줄> first 첫 토큰(주 산출물)
#   split_line <줄> rest  토큰들을 뗀 나머지
lead_only() { LINE="$1" python3 -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
print("ok" if m and not re.search(r"<[^<>]+>", l[m.end():]) else "no")'; }
split_line() { LINE="$1" WHAT="$2" python3 -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
if not m:
    print("")
elif os.environ["WHAT"] == "first":
    print(re.findall(r"@<[^<>]+>", m.group(1))[0])
else:
    print(l[m.end():])'; }
ONE="$(nsl "$FIN")"
n1="$(grep -cE '^[[:space:]]*> `(@<[^<>]+> )+이 interview brief 로' "$FIN" || true)"
if nonempty "다음 세션 줄" "$ONE"; then
  assert_eq "$n1" "1" "다음 세션 줄 모양의 인용 줄이 finishing.md 에 정확히 하나 (①·② 가 따로 정의하지 않는다)"
  assert_eq "$(split_line "$ONE" first)" "@<brief-path>" "다음 세션 줄의 첫 토큰은 @<brief-path> (주 산출물)"
  case "$(split_line "$ONE" rest)" in
    "이 interview brief 로 Skill superpowers:brainstorming 을 시작하라."*) ok "다음 세션 줄이 토큰 뒤에 brainstorming 을 부른다" ;;
    *) no "다음 세션 줄의 토큰 뒤 머리가 다르다: $ONE" ;;
  esac
  order "다음 세션 줄" "$ONE" "Skill superpowers:brainstorming" "spec-distill:spec-review"
  order "다음 세션 줄" "$ONE" "spec-distill:spec-review" "writing-plans"
  assert_contains "$ONE" "보다 이 순서가 우선한다" "다음 세션 줄: brainstorming 의 「다음은 writing-plans 뿐」보다 우선한다고 적는다"
  assert_contains "$ONE" "게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다" "다음 세션 줄: 게이트 없는 종료의 복귀 분기를 싣는다 (AC16)"
  assert_eq "$(lead_only "$ONE")" "ok" "다음 세션 줄의 꺾쇠 자리표는 줄 앞 @<…> 토큰에만 있다"
fi
assert_file_absent "$FIN" '/compact interview brief at' "옛 /compact 보존 템플릿이 없다"
assert_file_absent "$FIN" '확정하고 바로 brainstorming' "옛 「바로 brainstorming」 옵션이 없다"
```

그리고 같은 파일 4~5행의 머리 주석:

old_string:
```bash
# AC8 · AC16 — 핸드오프 네 자리가 brainstorming → `spec-distill:spec-review` → writing-plans
# 순서를 싣고, `spec-review` 의 게이트 없는 두 종료 경로가 같은 복귀 지시로 끝나는가.
```
new_string:
```bash
# AC8 · AC16 — 핸드오프 자리(interview 의 다음 세션 줄 · brief 템플릿 §7 · spec-review description)가
# brainstorming → `spec-distill:spec-review` → writing-plans 순서를 싣고, `spec-review` 의 게이트 없는
# 두 종료 경로가 같은 복귀 지시로 끝나는가. spec-review 승인 게이트의 표 · 다음 세션 줄 · 정지 요건도 잰다.
```

- [ ] **Step 5: `test_plain_gate_templates.sh` ⑥ — FIN 을 다음 세션 줄로**

old_string:
```bash
# ⑥ 핸드오프 /compact 틀 둘이 규칙 유지 문장을 싣는다.
for f in "$FIN" "$RS"; do
  assert_eq "$(grep -c '/compact .*사람에게 쓰는 글 규칙' "$f" || true)" "1" "AC7: $(basename "$(dirname "$f")") 의 /compact 틀이 규칙 유지 문장을 싣는다"
done
```
new_string:
```bash
# ⑥ 다음 세션 줄이 규칙 유지 문장을 싣는다 — 표지 블록의 한 줄에서 재고, 그 구절은 파일에 한 곳뿐이다.
nsl() { awk -v m='**다음 세션 줄 — ①/② 공통**' '$0==m{f=1;next} f&&NF{print;exit}' "$1"; }
for f in "$FIN"; do
  l="$(nsl "$f")"; who="${f#"$REPO_ROOT"/}"
  [ -n "$l" ] && ok "AC7(양성): ${who} 의 다음 세션 줄을 읽었다" || no "AC7(양성): ${who} 에 다음 세션 줄 표지 블록이 없다 — 아래 단언이 공허하다"
  assert_eq "$(printf '%s' "$l" | grep -oF '사람에게 쓰는 글 규칙' | wc -l | tr -d ' ')" "1" "AC7: ${who} 의 다음 세션 줄이 규칙 유지 문장을 싣는다"
  assert_eq "$(grep -c '사람에게 쓰는 글 규칙(번호·해시는' "$f" || true)" "1" "AC7: ${who} 에서 그 구절은 다음 세션 줄 한 곳뿐이다"
done
assert_eq "$(grep -c '/compact .*사람에게 쓰는 글 규칙' "$RS" || true)" "1" "AC7: spec-review 의 /compact 틀이 규칙 유지 문장을 싣는다"
```

- [ ] **Step 6: RED 를 확인한다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_conducting_interview_stage test_review_handoff_order test_plain_gate_templates test_next_session_command; do
  echo "== $t"; bash plugins/spec-distill/tests/$t.sh | grep -E '✗|^Total'; done
```
Expected: 바꾼 단언들이 `✗`(새 라벨 둘 · 「바로」 라벨 · 두 줄 명령 비노출 · 다음 세션 줄 · 옛 템플릿 부재 · AC3 둘 · ①·② 창 단언 · C5(next-session) · review_handoff_order 의 다음 세션 줄 단언과 두 부재 · plain_gate 의 FIN 셋 · next_session_command 의 spec-interview 단언). 그 밖은 Task 2 끝 상태와 같다.

- [ ] **Step 7: finishing.md — Step B 머리의 `/compact` 전제**

`plugins/spec-distill/skills/spec-interview/references/finishing.md`

old_string:
```
`spec-review` 의 `/compact` proceed 게이트와 **같은 골격**이며, 두 벌을 독립 저술하던
```
new_string:
```
`spec-review` 의 proceed 게이트와 **같은 골격**이며, 두 벌을 독립 저술하던
```

old_string:
```
verbatim `/compact` 템플릿 · superpowers 가용성 분기)만 남습니다.
```
new_string:
```
다음 세션 줄 · superpowers 가용성 분기)만 남습니다.
```

- [ ] **Step 8: finishing.md — B-1 · B-2 경로 부재**

old_string:
```
게이트 없음(compact 후 넘길 대상 자체가 없음).
```
new_string:
```
게이트 없음(다음 세션에 넘길 대상 자체가 없음).
```

old_string:
```
`/compact`를 노출하지 *않고* loud advisory 후 STOP
```
new_string:
```
두 줄 명령을 노출하지 *않고* loud advisory 후 STOP
```

- [ ] **Step 9: finishing.md — B-2 라벨**

old_string:
```
      {label: "확정하고 /compact 후 brainstorming (권장)", description: "확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 /compact 명령을 보여 준다. 긴 인터뷰 기록이 정리된 뒤 brainstorming 을 시작한다."},
      {label: "확정하고 바로 brainstorming", description: "확정 후보를 확정으로 바꿔 저장하고, 이 대화 그대로 brainstorming 을 시작한다(기록 정리 없음)."},
```
new_string:
```
      {label: "확정하고 /new 후 brainstorming (권장)", description: "확정 후보를 확정으로 바꿔 저장하고, 붙여 넣을 두 줄(/new 와 다음 세션 줄)을 보여 준다. 새 세션이 brief 를 붙여 읽고 brainstorming 을 시작한다."},
      {label: "확정하고 /compact 후 brainstorming", description: "확정 후보를 확정으로 바꿔 저장하고, 같은 두 줄을 첫 줄만 /compact 로 보여 준다. 인터뷰 기록을 요약해 둔 채 brainstorming 을 시작한다."},
```

- [ ] **Step 10: finishing.md — B-3 규약의 거처**

old_string:
```
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이
아니라 **orchestrator의 호출 프롬프트**에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. 아래 ①과 ② **양쪽 모두** 같은 문장을 싣습니다.
```
new_string:
```
읽지 않습니다 — 전달은 순수 프로즈 경로입니다. 그래서 C4 재결정 프로토콜은 brief 파일이
아니라 **다음 세션 줄**(brainstorming 을 부르는 호출 프롬프트)에 싣습니다. brief는 순수 데이터(`source`/`status`/
`evidence`)만 나릅니다. ①과 ② 는 같은 줄을 씁니다.
```

- [ ] **Step 11: finishing.md — B-3 ①·② 를 표지 블록과 두 불릿으로**

old_string(`- **① 확정하고 /compact 후 brainstorming**:` 부터 `  이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.` 까지 — 지금 362~387행):
```
- **① 확정하고 /compact 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 →
  brief 재저장 → `check_brief.py gate` 재실행(통과 확인) → 아래 verbatim `/compact` 명령을
  *그대로 보이게* 노출 + "다음 턴에 직접 `Skill superpowers:brainstorming <실제 경로>` 를
  부르세요" 안내 (사람이 유일한 운반자다 — 자동으로 이어지지 않는다):

  > `/compact interview brief at <brief-path> 보존 — brief 본문(특히 §0 한눈에, §2 제약, §3 Open Questions, §6 사용자 원문 중 `S1`), audit 파일 경로 참조, **그리고 아래 '재결정 규약' 문장**과 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 유지하고, round-by-round 인터뷰 대화·web sweep 원문·steelman 중간 추론은 drop. 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 다음 단계: Skill superpowers:brainstorming <brief-path> → 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:spec-review → 그 승인 게이트에서 진행을 고른 뒤 superpowers:writing-plans.`

  **`<brief-path>` 두 자리를 Step A 가 방금 쓴 실제 경로로 치환한 뒤 노출한다.** 이 명령은
  사용자가 그대로 붙여넣는 것이므로, 치환하지 않고 내보내면 사용자가 깨진 명령을 실행한다 —
  그리고 그것을 잡는 자리가 없다(자리 ①의 `<file>` 과 달리 fail-closed 검사가 없다).

  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것**(compact 전
  brainstorming 진입 = 옵션 ① 무력화). `Skill superpowers:brainstorming <brief-path>` 진입은
  사용자가 `/compact`를 *실제 실행한 다음 턴*에 **사용자 트리거**(예: `/compact write design`처럼
  compact 뒤에 붙인 진행 인자, 또는 명시적 진행 요청)로만 일어난다 — 모델은 다음 턴에 자동
  진입하지 *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17).

- **② 확정하고 바로 brainstorming**: 확정 반영 → 재저장 → 게이트 재실행 → 즉시
  `Skill superpowers:brainstorming <brief-path>` 호출하되, **호출 프롬프트에 C4 문장과 순서
  문장을 함께 싣는다**:

  > `confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.`
  >
  > `설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:spec-review 를 부른다 — brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다.`

  이것은 아래 cross-compact 정지 요건의 *명시적 예외*다.
```
new_string:
```
**다음 세션 줄 — ①/② 공통**

> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. 설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:spec-review 를 부른다 — brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다. superpowers:writing-plans 는 spec-review 의 승인 게이트에서 진행이 선택된 뒤에만 부른다. spec-review 가 게이트 없이 끝나면 brainstorming 의 사용자 리뷰 게이트로 돌아간다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

`<brief-path>` 는 Step A.5 의 `PAYLOAD` 값, 곧 brief 의 절대경로로 치환한 뒤 노출한다. 치환하지 않은
자리표가 남거나 경로에 공백이 있으면 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. brief: <PAYLOAD 값>`
한 줄을 낸 뒤 멈춘다(정본 `## 다음 세션 명령` 규칙 5). 사람이 이 줄의 유일한 운반자다 — 자동으로 이어지지 않는다.

- **① 확정하고 /new 후 brainstorming**: 확정 후보를 `status: confirmed`로 반영 → brief 재저장 →
  `check_brief.py gate` 재실행(통과 확인) → 두 줄을 *그대로 보이게* 노출한다. 첫 줄은 `/new`, 둘째 줄은
  위 다음 세션 줄이다. 두 줄을 따로 입력하라는 안내와 git 작업 트리 루트의 절대경로를 함께 낸다(정본
  `## 다음 세션 명령` 규칙 1 · 7).
  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** brainstorming 진입은
  사용자가 두 줄을 실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다 — 모델은 자동 진입하지
  *않고* 신호를 기다리며, 사용자가 redirect하면 미진입(NG4·P17).

- **② 확정하고 /compact 후 brainstorming**: ① 과 같은 절차로 두 줄을 노출하되 첫 줄이 맨 `/compact` 다
  (뒤에 아무것도 붙이지 않는다 — 붙인 텍스트는 요약 지시로만 쓰인다). 둘째 줄은 위 다음 세션 줄이다.
  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** 진입은 사용자가 두 줄을
  실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다(NG4·P17).
```

- [ ] **Step 12: finishing.md — B-4**

old_string:
```
- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate 하고 게이트 제시/`Skill
  superpowers:brainstorming` 호출을 skip 하는 것은 **polite stop** — 금지. Step B 를 *종료*하는
```
new_string:
```
- **AP2 polite-stop 금지**: ①/② 선택 후 "brief 완결!"만 narrate 하고 두 줄 명령을 노출하지 않고
  끝내는 것은 **polite stop** — 금지(①/② 의 완료는 B-3 대로 두 줄과 위치를 노출하고 턴을 끝내는 것이다). Step B 를 *종료*하는
```

old_string:
```
- **cross-compact 조기진행 금지**: 옵션 ① 의 정지 요건과 다음 턴 진입 조건은 B-3 ① 에 인라인으로
  있습니다(그것이 이 skill 의 실행형이자 기계적 검증 앵커입니다). 옵션 ② 는 그 정지 요건의
  *명시적 예외*(compact 없이 즉시 brainstorming)이며, B-3 ② 가 그렇게 적고 있습니다.
```
new_string:
```
- **cross-compact 조기진행 금지**: ①·② 의 정지 요건과 다음 턴 진입 조건은 B-3 ①·② 에 인라인으로
  있습니다(그것이 이 skill 의 실행형이자 기계적 검증 앵커입니다). 예외는 없습니다.
```

- [ ] **Step 13: GREEN 을 확인한다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_conducting_interview_stage test_review_handoff_order test_plain_gate_templates test_next_session_command test_brief_review_entry test_proceed_gate_adopters test_seed_at_path_handoff; do
  echo "== $t"; bash plugins/spec-distill/tests/$t.sh | grep -E '✗|^Total'; done
grep -nE '바로 brainstorming|/compact interview brief|명시적 예외' plugins/spec-distill/skills/spec-interview/references/finishing.md
```
Expected: `test_next_session_command` 의 남은 `✗` 는 `spec-review:` 단언뿐(Task 4 몫). 나머지 여섯 락은 `Fail: 0`. 마지막 grep 은 출력 없음.

- [ ] **Step 14: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git commit -m "feat(spec-distill): interview 끝에 /new · /compact 뒤 다음 세션 줄을 낸다

①·② 가 같은 @<brief 절대경로> 줄을 쓰고 「바로 brainstorming」을 없앤다.
재결정 규약 · 순서 문장 · 글 규칙을 그 줄이 나른다.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_plain_gate_templates.sh
git show --stat HEAD | tail -3
```
Expected: 4 files changed.

---

### Task 4: spec-review — 2단계 표 · 다음 세션 줄 · ①/② 정지 요건

**Files:**
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh` (끝 `finish` 앞에 절 추가)
- Modify: `plugins/spec-distill/tests/test_plain_gate_templates.sh` (⑥)
- Modify: `plugins/spec-distill/skills/spec-review/SKILL.md` (`## 게이트`)

**Interfaces:**
- Consumes: Task 3 이 `test_review_handoff_order.sh` 에 둔 `nsl` · `lead_only` · `split_line` 함수와 기존 `nonempty`.
- Produces: spec-review 표지 블록과 줄 `@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. …`.

- [ ] **Step 1: `test_review_handoff_order.sh` — spec-review 승인 게이트 절을 더한다**

old_string(파일 끝):
```bash
FENCE="$(awk 'index($0,"<!-- review-entry:begin -->"){f=1;next} index($0,"<!-- review-entry:end -->"){f=0} f' "$SKILL")"
if nonempty "진입 펜스" "$FENCE"; then
  assert_contains "$FENCE" "$RETURN_TAIL" "진입 펜스가 복귀 지시 문장을 갖는다"
fi
finish
```
new_string:
```bash
FENCE="$(awk 'index($0,"<!-- review-entry:begin -->"){f=1;next} index($0,"<!-- review-entry:end -->"){f=0} f' "$SKILL")"
if nonempty "진입 펜스" "$FENCE"; then
  assert_contains "$FENCE" "$RETURN_TAIL" "진입 펜스가 복귀 지시 문장을 갖는다"
fi

# ── spec-review 승인 게이트 2단계 — 표 · 다음 세션 줄 · ①/② 정지 요건 ─────
GATE="$(awk '/^## 게이트$/{f=1;next} f&&/^## /{exit} f' "$SKILL")"
if nonempty "spec-review 게이트 절" "$GATE"; then
  rows="$(printf '%s\n' "$GATE" | grep -E '^\| [①②③④] \|' || true)"
  assert_eq "$(printf '%s\n' "$rows" | grep -c . || true)" "4" "spec-review 2단계 표(양성): 행 4개를 읽었다"
  r1="$(printf '%s\n' "$rows" | grep -E '^\| ① \|' || true)"
  r2="$(printf '%s\n' "$rows" | grep -E '^\| ② \|' || true)"
  for n in '`/new` 후 다음 세션 줄' '(권장)' '턴 종료'; do assert_contains "$r1" "$n" "spec-review ① 행에 $n"; done
  for n in '`/compact` 후 같은 다음 세션 줄' '턴 종료'; do assert_contains "$r2" "$n" "spec-review ② 행에 $n"; done
  assert_not_contains "$r2" '권장' "spec-review: 권장은 ① 하나"
  assert_not_contains "$rows" '바로' "spec-review 2단계 표에 「바로」 진행 행이 없다"
  RSL="$(nsl "$SKILL")"
  if nonempty "spec-review 다음 세션 줄" "$RSL"; then
    assert_eq "$(split_line "$RSL" first)" "@<spec_path>" "spec-review 다음 세션 줄의 첫 토큰은 @<spec_path> (주 산출물)"
    case "$(split_line "$RSL" rest)" in
      "이 설계문서로 Skill superpowers:writing-plans 를 시작하라."*) ok "spec-review 다음 세션 줄이 토큰 뒤에 writing-plans 를 부른다" ;;
      *) no "spec-review 다음 세션 줄의 토큰 뒤 머리가 다르다: $RSL" ;;
    esac
    assert_contains "$RSL" "보고 후 재결정" "spec-review 다음 세션 줄이 C4 문장을 싣는다"
  fi
  STOP="$(printf '%s\n' "$GATE" | awk '/^- \*\*①\/② 의 정지 요건\*\*/{f=1;print;next} f&&/^- /{f=0} f' | tr '\n' ' ' | tr -s ' ')"
  [ -n "$STOP" ] && ok "spec-review(양성): ①/② 의 정지 요건 불릿을 읽었다" || no "spec-review: ①/② 의 정지 요건 불릿이 없다 — 아래 단언이 공허하다"
  for n in '턴 종료(STOP)' '같은 턴에서 `writing-plans` 를' '**다음 턴**' '사용자 트리거로만'; do
    assert_contains "$STOP" "$n" "spec-review ①/② 정지 요건 불릿 안에 $n"
  done
fi
assert_file_absent "$SKILL" '/compact 설계문서' "spec-review: 옛 /compact 보존 틀이 없다"
assert_file_absent "$SKILL" '① 의 정지 요건' "spec-review: 옛 「① 의 정지 요건」 불릿 이름이 없다"
finish
```

- [ ] **Step 2: `test_plain_gate_templates.sh` ⑥ — RS 를 다음 세션 줄로**

old_string:
```bash
for f in "$FIN"; do
```
new_string:
```bash
for f in "$FIN" "$RS"; do
```

old_string:
```bash
assert_eq "$(grep -c '/compact .*사람에게 쓰는 글 규칙' "$RS" || true)" "1" "AC7: spec-review 의 /compact 틀이 규칙 유지 문장을 싣는다"
RSC="$(grep '/compact 설계문서' "$RS" || true)"
assert_eq "$(printf '%s' "$RSC" | grep -oE '<[^>]+>' | sort -u | tr '\n' ' ')" "<spec_path> " "Review Focus 4: spec-review /compact 틀의 꺾쇠 자리표가 <spec_path> 하나다"
```
new_string:
```bash
# 꺾쇠 자리표는 줄 앞 `@<…>` 토큰에만 있다 — 목록 원소가 늘어도 통과한다(설계 G3).
RSC="$(nsl "$RS" | sed -e 's/^> `//' -e 's/`$//')"
assert_eq "$(LINE="$RSC" python3 -c '
import os, re
l = os.environ["LINE"]
m = re.match(r"((?:@<[^<>]+> )+)", l)
print("ok" if m and not re.search(r"<[^<>]+>", l[m.end():]) else "no")')" "ok" "Review Focus 4: spec-review 다음 세션 줄의 꺾쇠 자리표는 줄 앞 @<…> 토큰에만 있다"
```

- [ ] **Step 3: RED 를 확인한다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_review_handoff_order test_plain_gate_templates test_next_session_command; do
  echo "== $t"; bash plugins/spec-distill/tests/$t.sh | grep -E '✗|^Total'; done
```
Expected: 새 spec-review 단언이 `✗`(① · ② 행 문구 · 다음 세션 줄 · 정지 요건 불릿 · 두 부재 · plain_gate 의 RS 셋과 자리표 · next_session_command 의 spec-review 단언). Task 3 끝에 GREEN 이던 단언은 그대로 `✓`.

- [ ] **Step 4: spec-review SKILL.md — 2단계 표 ①·② 행**

`plugins/spec-distill/skills/spec-review/SKILL.md`

old_string:
```
| ① | 미커밋 확인 → `/compact` 후 `superpowers:writing-plans` (권장) — verbatim `/compact` 명령을 노출하고 **턴 종료** |
| ② | 미커밋 확인 → 바로 `Skill superpowers:writing-plans <path>` |
```
new_string:
```
| ① | 미커밋 확인 → `/new` 후 다음 세션 줄 (권장) — 두 줄을 노출하고 **턴 종료** |
| ② | 미커밋 확인 → `/compact` 후 같은 다음 세션 줄 — 두 줄을 노출하고 **턴 종료** |
```

- [ ] **Step 5: spec-review SKILL.md — 노출 명령 · 정지 요건 · polite stop**

old_string:
```
① 에서 노출하는 명령(`<spec_path>` 를 실제 경로로 바꾼 뒤 그대로 보인다):

> `/compact 설계문서 <spec_path> 보존 — 문서 경로, 결정 기록, Deferred to plan 목록을 유지하고 리뷰 라운드별 대화·지적 원문·엔진 출력은 drop. 재결정 규약: confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 유지한다. 다음 단계: Skill superpowers:writing-plans <spec_path>.`

- **① 의 정지 요건** — verbatim `/compact` 명령을 노출한 자리에서 **턴 종료(STOP)** 한다. 같은 턴
  에서 `writing-plans` 를 호출하지 않는다(compact 전 진입은 옵션 ① 을 무력화한다). 진입은 사용자가
  `/compact` 를 실제로 실행한 **다음 턴**에 사용자 트리거로만 일어나고, 사용자가 redirect 하면
  미진입한다(P17).
- **polite stop 금지 (AP2)** — ①/② 를 골랐는데 narrate 만 하고 `### 미커밋 확인` 과 다음 단계
  진입을 skip 하면 polite stop 이다. 이 skill 을 종료하는 모든 경로는 이 게이트를 거치거나, 게이트를
```
new_string:
```
**다음 세션 줄 — ①/② 공통**

> `@<spec_path> 이 설계문서로 Skill superpowers:writing-plans 를 시작하라. confirmed 항목은 근거 있으면 보고 후 재결정 가능하고 임의 변경은 금지다. 사람에게 쓰는 글 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에, 첫 줄에 상태, 끝에 할 일 하나)을 지킨다.`

`<spec_path>` 는 `## 입력` 에서 바꾼 설계문서의 절대경로로 치환한 뒤 노출한다. 치환하지 않은 자리표가
남거나 경로에 공백이 있으면 노출하지 않고 `[spec-distill] 다음 세션 줄을 만들 수 없다 — <사유>. 설계문서: <spec_path 값>`
한 줄을 낸 뒤 멈춘다(정본 `## 다음 세션 명령` 규칙 5). ①/② 는 첫 줄(① `/new` · ② 맨 `/compact`)과 이 줄을
노출하고, 두 줄을 따로 입력하라는 안내와 git 작업 트리 루트의 절대경로를 함께 낸다(규칙 1 · 7).

- **①/② 의 정지 요건** — 두 줄을 노출한 자리에서 **턴 종료(STOP)** 한다. 같은 턴에서 `writing-plans` 를
  호출하지 않는다(명령 전 진입은 ①/② 를 무력화한다). 진입은 사용자가 두 줄을 실제로 입력한
  **다음 턴**에 사용자 트리거로만 일어나고, 사용자가 redirect 하면 미진입한다(P17).
- **polite stop 금지 (AP2)** — ①/② 를 골랐는데 narrate 만 하고 `### 미커밋 확인` 과 두 줄 명령 노출을
  skip 하면 polite stop 이다. ①/② 의 완료는 미커밋 확인 → 두 줄과 위치 노출 → 턴 종료다.
  이 skill 을 종료하는 모든 경로는 이 게이트를 거치거나, 게이트를
```

- [ ] **Step 6: GREEN 을 확인한다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in test_review_handoff_order test_plain_gate_templates test_next_session_command test_proceed_gate_adopters test_seed_at_path_handoff test_conducting_interview_stage; do
  echo "== $t"; bash plugins/spec-distill/tests/$t.sh | grep -E '✗|^Total'; done
python3 shared/entry/check_invocation_surface.py; echo "surface rc=$?"
grep -nE '바로 `Skill|/compact 설계문서|① 의 정지 요건' plugins/spec-distill/skills/spec-review/SKILL.md
```
Expected: 여섯 락 모두 `Fail: 0`. surface rc=0(`[invocation-surface] GREEN`). 마지막 grep 은 출력 없음.

- [ ] **Step 7: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git commit -m "feat(spec-distill): 설계문서 승인 게이트도 /new · /compact 뒤 다음 세션 줄을 낸다

①·② 가 같은 @<설계문서 절대경로> 줄을 쓰고 「바로 writing-plans」를 없앤다.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_plain_gate_templates.sh
git show --stat HEAD | tail -3
```
Expected: 3 files changed.

---

### Task 5: 문서 · 버전

**Files:**
- Modify: `plugins/spec-distill/README.md:53, 80, 144`
- Modify: `CLAUDE.md:88`
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json:4`
- Modify: `plugins/spec-distill/CHANGELOG.md` (맨 위 항목 추가)

**Interfaces:**
- Consumes: Task 1~4 의 문면(옵션 이름 · 정본 절 이름).

- [ ] **Step 1: README 흐름도(53행)**

old_string:
```
▼ [Step B proceed 게이트] ①/compact 후 brainstorming · ②바로 brainstorming · ③확정 목록 수정 · ④brief만 종료  (superpowers 있을 때만)
```
new_string:
```
▼ [Step B proceed 게이트] ①/new 후 다음 세션 줄 · ②/compact 후 다음 세션 줄 · ③확정 목록 수정 · ④brief만 종료  (superpowers 있을 때만)
```

- [ ] **Step 2: README 3.0.0 문단(80행)**

old_string:
```
인터뷰 핸드오프 문구(`finishing.md` ①·②, brief 템플릿 §7)
```
new_string:
```
인터뷰 핸드오프 문구(`finishing.md` 의 다음 세션 줄, brief 템플릿 §7)
```

- [ ] **Step 3: README AP2 단락(144행) — 세 군데**

old_string:
```
각 skill 은 자기 어휘(옵션 라벨 · verbatim `/compact` 템플릿 · 고유 스텝)만 인라인으로 갖는다.
```
new_string:
```
각 skill 은 자기 어휘(옵션 라벨 · 다음 세션 줄 · 고유 스텝)만 인라인으로 갖는다.
```

old_string:
```
cross-compact 조기 진행(옵션 ① 노출 후 같은 턴 writing-plans 직진)도
```
new_string:
```
cross-compact 조기 진행(①/② 의 두 줄 명령 노출 후 같은 턴에 다음 단계로 직진)도
```

old_string:
```
interview→brainstorming Step B의 **4옵션**: ①/compact 후 brainstorming / ②바로 brainstorming / ③확정 목록 수정 / ④brief만 종료 (③ 추가는 v0.23.0)
```
new_string:
```
interview→brainstorming Step B의 **4옵션**: ①/new 후 다음 세션 줄 / ②/compact 후 다음 세션 줄 / ③확정 목록 수정 / ④brief만 종료 (③ 추가는 v0.23.0). ①·② 의 다음 세션 줄은 `@<brief 절대경로>` 로 시작해 새 세션이 brief 를 붙여 읽는다(정본 `## 다음 세션 명령`)
```

- [ ] **Step 4: CLAUDE.md Polite handoff(88행)**

old_string:
```
대칭으로, 옵션 ①(/compact 후 writing-plans) 선택 시 /compact 노출 후 같은 턴에 writing-plans로 직진하는 cross-compact 조기 진행도 게이트 P17 우회의 대칭 실패로 금지 (AP2 variant, spec-distill v0.11.0 AC19).
```
new_string:
```
대칭으로, 옵션 ①·②(`/new`·`/compact` 뒤 다음 세션 줄) 선택 시 명령 노출 후 같은 턴에 다음 단계로 직진하는 cross-compact 조기 진행도 게이트 P17 우회의 대칭 실패로 금지 (AP2 variant, spec-distill v0.11.0 AC19).
```

- [ ] **Step 5: plugin.json**

old_string:
```
  "version": "5.1.1",
```
new_string:
```
  "version": "5.2.0",
```

- [ ] **Step 6: CHANGELOG 맨 위에 항목**

old_string:
```
# Changelog

## [5.1.1] — 2026-10-10
```
new_string:
```
# Changelog

## [5.2.0] — 2026-10-11

### Changed
- 세 proceed 게이트(request-framing 확정 · interview 다음 단계 · 설계문서 승인)의 ①·② 가 같은 모양이다 — ① `/new` · ② `/compact` 뒤에 ①·② 공통의 「다음 세션 줄」을 따로 입력한다. 규칙의 정본은 `references/proceed-gate.md` 의 새 절 `## 다음 세션 명령` 이다.
- interview 와 설계문서 승인의 다음 세션 줄은 `@<절대경로>` 로 시작하는 평문 프롬프트다. 새 세션의 첫 턴이 brief · 설계문서를 붙여 읽고 brainstorming · writing-plans 를 시작한다. 재결정 규약 · 순서 문장 · 사람에게 쓰는 글 규칙을 그 줄이 나른다. 평문 `@` 의 상대경로는 세션 작업 디렉토리 기준으로 풀려(헤드리스 실측) 절대경로를 쓴다 — 경로에 공백이 있으면 줄을 내지 않고 알린다.
- 읽힐 파일은 경로 목록이다 — 원소마다 `@` 토큰 하나. slash 줄은 받는 쪽 한도(spec-interview 1)를 정본 표가 쥔다.
- `tests/test_next_session_command.sh` 가 채택자마다 다음 세션 줄의 개수 · 모양 · 한도를 잰다. 기존 락의 「자리표 하나뿐」 단언은 「자리표는 줄 앞 `@` 토큰에만」으로 바뀌었다.

### Removed
- 「확정하고 바로 brainstorming」 · 「바로 writing-plans」 옵션과 긴 `/compact … 보존` 명령 틀. 사용자가 결정한 재건(2026-10-11)이라 deprecation 창을 두지 않는다.

## [5.1.1] — 2026-10-10
```

- [ ] **Step 7: 문서 락을 돌린다**

Run:
```bash
cd /Users/jeonghokim/Downloads/devbrew
for t in plugins/spec-distill/tests/test_readme_sync.sh plugins/spec-distill/tests/test_seed_at_path_handoff.sh; do echo "== $t"; bash $t | grep -E '✗|^Total'; done
for t in shared/tests/test_*.sh; do bash "$t" >/dev/null 2>&1 || echo "RED $t"; done
python3 -c 'import json;print(json.load(open("plugins/spec-distill/.claude-plugin/plugin.json"))["version"])'
```
Expected: 두 락 `Fail: 0` — 단 `test_readme_sync.sh` 는 base(3a8d7d1d)의 메인 체크아웃에서 이미 `✗ 파일 실재(양성 대조): 추출기가 고장났다 … (출력: COUNT	2 )` 1건이 있었다(깨끗한 복사본에서는 GREEN — 환경 의존). 그 1건이 Task 0 baseline 에 있으면 선재다. `RED` 줄은 Task 0 baseline 에서 이미 RED 였던 파일뿐이다(새 이름 없음 — Task 6 이 이름 단위로 다시 잰다). 버전 `5.2.0`.

- [ ] **Step 8: 커밋**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git commit -m "docs(spec-distill): 다음 세션 줄 게이트를 문서와 버전에 반영한다

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" -- plugins/spec-distill/README.md CLAUDE.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md
git show --stat HEAD | tail -3
```
Expected: 4 files changed.

---

### Task 6: 전체 검증 · 변이

**Files:** 없음(리포 밖 `~/.claude/sdd-mirror/next-session-at-handoff/` 에 스크립트와 결과)

**Interfaces:**
- Consumes: Task 0 의 `baseline/fails.txt` · `collect_fails.sh`.

- [ ] **Step 1: 스위트를 다시 떠서 baseline 과 이름으로 비교한다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
M=~/.claude/sdd-mirror/next-session-at-handoff
bash $M/collect_fails.sh $M/after
comm -13 $M/baseline/fails.txt $M/after/fails.txt > $M/new_fails.txt
comm -23 $M/baseline/fails.txt $M/after/fails.txt > $M/fixed_fails.txt
echo "새 FAIL: $(wc -l < $M/new_fails.txt)"; cat $M/new_fails.txt
echo "사라진 FAIL: $(wc -l < $M/fixed_fails.txt)"; cat $M/fixed_fails.txt
```
Expected: 새 FAIL 0. 사라진 FAIL 이 있으면 이 작업이 바꾼 단언 이름 변화인지 확인해 진행 기록에 적는다(이름이 바뀐 단언은 「사라짐 + 새로 생김」 쌍으로 나타나므로 새 FAIL 0 이면 문제없다).

- [ ] **Step 2: 표면 락 · guards 커버리지**

```bash
cd /Users/jeonghokim/Downloads/devbrew
python3 shared/entry/check_invocation_surface.py; echo "surface rc=$?"
bash plugins/quality-gates/tests/test_guards_coverage_bidirectional.sh | grep -E '✗|^Total|next_session'
bash plugins/quality-gates/tests/test_guards_declaration_mapping.sh | grep -E '✗|^Total'
bash plugins/spec-distill/tests/test_next_session_command.sh --emit-scanned
```
Expected: surface rc=0. 두 guards 락은 Task 0 baseline 대비 새 `✗` 없음(이미 RED 였으면 같은 이름만). emit 은 세 채택자 표면 파일과 `plugins/spec-distill/references/proceed-gate.md` 를 상대경로로 낸다.

- [ ] **Step 3: 변이 스크립트를 쓴다**

`~/.claude/sdd-mirror/next-session-at-handoff/mutate.py`:

```python
#!/usr/bin/env python3
"""사용: mutate.py <리포 루트> — 변이마다 적용 → 지정 락 실행 → 복원. 리포는 깨끗한 커밋 상태여야 한다."""
import os
import pathlib
import subprocess
import sys

R = pathlib.Path(sys.argv[1])
T = "plugins/spec-distill/tests/"
FIN = "plugins/spec-distill/skills/spec-interview/references/finishing.md"
RS = "plugins/spec-distill/skills/spec-review/SKILL.md"
RF = "plugins/spec-distill/skills/request-framing/SKILL.md"
PG = "plugins/spec-distill/references/proceed-gate.md"
MARK = "**다음 세션 줄 — ①/② 공통**"
IV_HEAD = "> `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라."
RS_HEAD = "> `@<spec_path> 이 설계문서로"
ORDER_A = "설계문서를 쓰고 커밋한 뒤, brainstorming 의 사용자 리뷰 게이트 자리에서 그 설계문서 경로로 Skill spec-distill:spec-review 를 부른다 — brainstorming 의 「다음은 writing-plans 뿐」 지시보다 이 순서가 우선한다."
IV_B = "Skill superpowers:brainstorming 을 시작하라."

# (이름, 파일, old, new, RED 를 내야 하는 락들, 기대: "red" | "green")
MUTS = [
    ("M1 ② 불릿에 줄 하나 더", FIN,
     "  실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다(NG4·P17).",
     "  실제로 입력한 **다음 턴**에 **사용자 트리거**로만 일어난다(NG4·P17).\n\n  > `@<brief-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라.`",
     ["test_next_session_command", "test_review_handoff_order"], "red"),
    ("M2 framing 줄에 토큰 추가(한도 초과)", RF,
     "> `/spec-distill:spec-interview @<seed 경로>`",
     "> `/spec-distill:spec-interview @<seed 경로> @<x>`",
     ["test_next_session_command"], "red"),
    ("M3 spec-review 줄의 첫 @ 삭제", RS, RS_HEAD, "> `<spec_path> 이 설계문서로",
     ["test_next_session_command"], "red"),
    ("M4 정본 경로 목록 문장 삭제", PG,
     "각 skill 은 읽힐 경로 목록(1개 이상)을 정한다. ", "",
     ["test_next_session_command"], "red"),
    ("M5 정본 ② 행에 바로 진행 부활", PG,
     "| ② | 차선 핸드오프 — `/compact` 와 같은 다음 세션 줄을 노출하고 **턴 종료** |",
     "| ② | 차선 핸드오프 — `/compact` 와 같은 다음 세션 줄을 노출하고 **턴 종료**, 또는 바로 진행 |",
     ["test_seed_at_path_handoff"], "red"),
    ("M6 정본 한도 1→0", PG,
     "| `spec-distill:spec-interview` | `## 진입 단계` 2 | 1 |",
     "| `spec-distill:spec-interview` | `## 진입 단계` 2 | 0 |",
     ["test_next_session_command"], "red"),
    ("M7 spec-review 표지 삭제", RS, MARK + "\n", "",
     ["test_next_session_command", "test_plain_gate_templates", "test_review_handoff_order"], "red"),
    ("M8 interview 줄 순서 뒤집기", FIN,
     IV_B + " confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. " + ORDER_A,
     ORDER_A + " confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지. " + IV_B,
     ["test_review_handoff_order"], "red"),
    ("M9 ② 불릿의 턴 종료 삭제", FIN,
     "  → **여기서 턴 종료(STOP). 같은 턴에서 `brainstorming`을 호출하지 말 것.** 진입은",
     "  → 진입은",
     ["test_conducting_interview_stage"], "red"),
    ("M10 spec-review ② 행을 바로 진행으로", RS,
     "| ② | 미커밋 확인 → `/compact` 후 같은 다음 세션 줄 — 두 줄을 노출하고 **턴 종료** |",
     "| ② | 미커밋 확인 → 바로 `Skill superpowers:writing-plans <path>` |",
     ["test_review_handoff_order"], "red"),
    ("M11 토큰 밖 꺾쇠 자리표", FIN, IV_HEAD,
     "> `@<brief-path> <x> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라.",
     ["test_next_session_command", "test_review_handoff_order"], "red"),
    ("M12 원소 추가(G3 양성 대조)", RS, RS_HEAD, "> `@<spec_path> @<extra> 이 설계문서로",
     ["test_next_session_command", "test_plain_gate_templates", "test_review_handoff_order"], "green"),
    ("M13 spec-interview 표지를 제목으로(모양 변경)", FIN, MARK + "\n", "#### 다음 세션 줄 — ①/② 공통\n",
     ["test_next_session_command", "test_conducting_interview_stage"], "red"),
    ("M14 interview 줄 원소 추가(G3 양성 대조)", FIN, IV_HEAD,
     "> `@<brief-path> @<audit-path> 이 interview brief 로 Skill superpowers:brainstorming 을 시작하라.",
     ["test_next_session_command", "test_review_handoff_order", "test_conducting_interview_stage", "test_plain_gate_templates"], "green"),
]

env = dict(os.environ, PYTHONDONTWRITEBYTECODE="1")


def run(lock):
    p = subprocess.run(["bash", T + lock + ".sh"], cwd=R, env=env, capture_output=True, text=True)
    return p.returncode, p.stdout.count("✗ ")


def clean():
    return subprocess.run(["git", "diff", "HEAD", "--quiet"], cwd=R).returncode == 0


assert clean(), "작업 트리가 HEAD 와 다르다 — 커밋 후 돌려라"
locks = sorted({l for m in MUTS for l in m[4]})
bad = 0
for l in locks:  # 양성 대조: 변이 전 전부 GREEN
    rc, n = run(l)
    print(f"[control] {l}: rc={rc} ✗={n}")
    bad += rc != 0
for name, f, old, new, ls, want in MUTS:
    p = R / f
    s = p.read_text(encoding="utf-8")
    c = s.count(old)
    if c != 1:
        print(f"[{name}] 변이 미적용 — old 가 {c}번 나온다(계측기 고장)")
        bad += 1
        continue
    p.write_text(s.replace(old, new), encoding="utf-8")
    for l in ls:
        rc, n = run(l)
        got = "green" if rc == 0 else "red"
        verdict = "OK" if got == want else "MISS"
        bad += verdict == "MISS"
        print(f"[{name}] {l}: {got} (✗={n}) 기대 {want} → {verdict}")
    subprocess.run(["git", "checkout", "HEAD", "--", f], cwd=R, check=True)
    if not clean():
        print(f"[{name}] 복원 실패 — 중단")
        sys.exit(2)
print(f"MISS·고장 {bad}건")
sys.exit(1 if bad else 0)
```

- [ ] **Step 4: 변이를 돌린다**

```bash
cd /Users/jeonghokim/Downloads/devbrew
git status --short   # 비어 있어야 한다
PYTHONDONTWRITEBYTECODE=1 python3 ~/.claude/sdd-mirror/next-session-at-handoff/mutate.py "$(pwd)"; echo "rc=$?"
git diff HEAD --quiet && echo CLEAN
```
Expected: `[control]` 줄 전부 `rc=0`. 변이 14개 각각의 지정 락이 기대대로(M12 · M14 는 green, 나머지 red) → 전부 `OK`. `MISS·고장 0건`, `rc=0`, `CLEAN`.

변이 → RED 를 내야 하는 락 (설계 AC6 의 판정 표):

| # | 변이 | RED 를 내야 하는 락 |
|---|---|---|
| M1 | interview ② 불릿에 다음 세션 줄 하나 더 | `test_next_session_command` · `test_review_handoff_order` |
| M2 | framing 줄에 `@<x>` (한도 초과) | `test_next_session_command` |
| M3 | spec-review 줄의 첫 `@` 삭제 | `test_next_session_command` |
| M4 | 정본 경로 목록 문장 삭제 | `test_next_session_command` |
| M5 | 정본 ② 행에 「바로 진행」 부활 | `test_seed_at_path_handoff` |
| M6 | 정본 한도 spec-interview 1→0 | `test_next_session_command` |
| M7 | spec-review 표지 삭제 | `test_next_session_command` · `test_plain_gate_templates` · `test_review_handoff_order` |
| M8 | interview 줄 순서 뒤집기 | `test_review_handoff_order` |
| M9 | interview ② 불릿의 턴 종료 삭제 | `test_conducting_interview_stage` |
| M10 | spec-review ② 행을 바로 진행으로 | `test_review_handoff_order` |
| M11 | 토큰 밖 꺾쇠 자리표 | `test_next_session_command` · `test_review_handoff_order` |
| M12 | 원소 추가(정상 확장) | 세 락 모두 **GREEN** (G3 양성 대조) |
| M13 | interview 표지를 제목으로 | `test_next_session_command` · `test_conducting_interview_stage` |
| M14 | interview 줄 원소 추가(정상 확장) | 네 락 모두 **GREEN** (G3 양성 대조) |

`MISS` 가 나오면 그 락의 단언을 고치고(락만 — 문면은 그대로) Task 6 을 처음부터 다시 돈다. 락을 고쳤으면 그 수정을 `test(spec-distill): …` 로 따로 커밋한다.

- [ ] **Step 5: 결과 기록**

`~/.claude/sdd-mirror/next-session-at-handoff/progress.md` 에 새 FAIL 0 · 사라진 FAIL 목록 · 변이 14건 결과를 적는다. 커밋할 리포 파일은 없다.

---

### Task 7: 대화형 끝에서 끝 확인 (사용자와 함께)

**Files:** 없음. 설치본으로 재기 위해 사용자가 이 브랜치의 spec-distill 을 설치한 세션에서 한다.

- [ ] **Step 1: 사용자에게 준비를 요청한다**

사용자에게 이 브랜치의 spec-distill 을 설치(또는 `--plugin-dir`)한 새 대화형 세션을 열어 달라고 요청한다. 어떤 리포에서 할지는 사용자가 정한다.

- [ ] **Step 2: spec-interview 끝 ① 확인**

짧은 주제로 spec-interview 를 끝까지 돌려 B-2 에서 ① 을 고른다. 확인할 것:
- 두 줄(`/new` 와 `@<brief 절대경로> 이 interview brief 로 …`)이 따로 보이고, 따로 입력하라는 안내와 git 작업 트리 루트 절대경로가 함께 나온다.
- 그 턴이 거기서 끝난다(brainstorming 미호출).
- 사용자가 `/new` 뒤 둘째 줄을 입력하면 첫 턴에 brief 가 첨부되고(대화형 `@<절대경로>` 첨부 — Review Focus 5) brainstorming 이 시작된다.

- [ ] **Step 3: spec-review ① 확인**

임의의 설계문서로 spec-review 를 돌려 승인 게이트 2단계에서 ① 을 고른다. 미커밋 확인 → 두 줄 노출 → 턴 종료, `/new` 뒤 둘째 줄 입력 → 설계문서 첨부와 writing-plans 시작을 확인한다.

- [ ] **Step 4: 결과를 진행 기록에 적는다**

첨부가 되지 않았으면 그 관측(어느 줄 · 어느 디렉토리 · 무엇이 보였나)을 적고 멈춰 사용자에게 보고한다 — 규칙 5 를 다시 정해야 한다.
