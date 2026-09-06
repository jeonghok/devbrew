# steelman 목표 적합 (R3 재설계) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-distill 인터뷰의 R3 steelman 게이트를 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로 다시 세운다 — builder 가 양쪽 케이스를 같은 기준으로 쓰고, 전제 충돌만이 재검토를 열고, 판정은 kept/refined/switched/deferred 넷으로 원장에 남는다.

**Architecture:** 세 파일이 바뀐다 — `agents/steelman-builder.md`(페르소나·5 슬롯·새 출력 스키마), `skills/conducting-interview/SKILL.md` R3 절(헤딩+trigger+포인터만 남기고 절차 전문은 새 `references/steelman.md` 로), `scripts/check_brief.py`(§5 skepticism 검사를 새 `scripts/skepticism.py` 로 위임). 토큰 이관(`defended→kept`, `refined` 추가)은 검증기 어휘와 데이터를 **한 커밋**에 움직인다. 결합된 락 3·픽스처·템플릿·`tools/adjudication/check_slots.py` 면제가 따라간다.

**Tech Stack:** Python 3(표준 라이브러리만) · bash 3.2 호환 테스트(`shared/tests/assert.sh` 의 `ok`/`no`/`finish`) · markdown skill/agent 파일.

**Spec:** `docs/superpowers/specs/2026-09-06-steelman-goal-fit-design.md` (이 plan 의 모든 「설계 §」 인용은 그 파일이다. executor 는 둘을 함께 읽는다.)

## Global Constraints

- 모든 경로는 워크트리 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+steelman-goal-fit` 기준이다. 브랜치 `feature/steelman-goal-fit`. **main 체크아웃에 쓰지 않는다.**
- `plugins/spec-distill/` 을 건드리는 PR 이므로 마지막 태스크에서 `.claude-plugin/plugin.json` 을 `0.53.1 → 0.54.0`, `CHANGELOG.md` 에 `## [0.54.0] — 2026-09-06`.
- builder 의 `tools: Read, Grep, Glob, WebSearch, WebFetch` 와 `model: inherit` · `cost_class: variable` 은 바꾸지 않는다(Law 2 · 락).
- 생성 파일(페르소나·steelman.md·템플릿)에는 지시만 쓴다 — 「왜 바뀌었는가」는 CHANGELOG 와 설계 문서에만(Self-narrating artifact 금지).
- 옛 토큰 별칭 없음(O1). `switched`·`deferred` 는 토큰 그대로.
- `references/steelman.md` 는 첫 줄 헤딩 `### R3 — Steelman 의심 게이트 (P17)` 뒤로 **`##`/`###` 헤딩을 두지 않는다**(Step 은 `####`). 락의 awk 가 다음 헤딩에서 블록을 끊는다.
- 임시 스크립트는 `/Users/jeonghokim/.claude/jobs/b499da5f/tmp/` 에 두고 리포에 남기지 않는다. `Bash` 도구는 호출마다 새 셸이라 변수는 넘어가지 않는다 — 스크립트 파일로.
- 테스트 실행은 파일마다 `bash plugins/spec-distill/tests/<name>.sh` 이고 마지막 줄 `Total: N | Pass: P | Fail: F` 를 읽는다. **rc 만 보지 말고 Fail 수를 baseline 과 비교한다.**
- 변이(mutation) 검사는 **커밋 뒤에** 하고 `git checkout -- <file>` 로 복원한다.
- 커밋 메시지 끝에 두 줄:
  ```
  Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
  ```

---

## 파일 구조

| 파일 | 책임 | 태스크 |
|---|---|---|
| `plugins/spec-distill/scripts/skepticism.py` (신설) | payload §5 의 skepticism 검사 전부: verdict 어휘 · 검토 항목 · 폐쇄 판정 · bijection A. check_brief 를 import 하지 않는다 | T2 |
| `plugins/spec-distill/scripts/check_brief.py` | 절 자르기·불릿 관례·gate 조립. skepticism 은 위 모듈 호출만 | T1(토큰 한 줄) · T2 |
| `plugins/spec-distill/agents/steelman-builder.md` | builder 페르소나·슬롯·출력 스키마 | T3 |
| `plugins/spec-distill/skills/conducting-interview/references/steelman.md` (신설) | R3 절차 전문 | T4 |
| `plugins/spec-distill/skills/conducting-interview/SKILL.md` | R3 절을 포인터로 | T4 |
| `plugins/spec-distill/tests/test_skepticism_module.sh` (신설) | 모듈 함수 단위 락 | T2 |
| `plugins/spec-distill/tests/test_check_brief.sh` | 게이트 락(T12 갱신 · 새 픽스처 6쌍) | T1(sed 패턴) · T2 |
| `plugins/spec-distill/tests/test_steelman_builder_scope.sh` | 페르소나 락 | T3 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | R3 블록 락(추출 대상 이동·neglect 반전) | T4 |
| `plugins/spec-distill/tests/fixtures/interview-brief-*` | 픽스처 141 이관 + 2 갱신 + 6쌍 신설 | T1 · T2 |
| `tools/adjudication/check_slots.py` | premises 슬롯 면제 · baseline 5 | T5 |
| `plugins/spec-distill/templates/interview-brief-template.md` · `interview-audit-template.md` | §5 예시 · ST 블록 골격 | T1(예시 토큰) · T6 |
| `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` | 문서·버전 | T6 |
| `docs/superpowers/interview/2026-08-16-…` · `2026-08-22-…` · `2026-09-05-steelman-goal-fit-interview.*` | 과거·현재 brief 의 기계 토큰 이관 | T1 |

---

### Task 0: baseline 캡처

**Files:**
- Create (리포 밖): `/Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.sh`, 출력 `/Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.txt`

**Interfaces:**
- Produces: `baseline.txt` — 스위트 파일마다 `<file>\t<Fail 수>` 한 줄. 이후 모든 태스크의 「새 RED 0」 판정 기준.

- [ ] **Step 1: baseline 스크립트 작성**

```bash
#!/bin/bash
# /Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.sh  — 인자: 출력 파일
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+steelman-goal-fit || exit 9
OUT="${1:?output file}"
: > "$OUT"
for t in plugins/spec-distill/tests/test_*.sh shared/tests/test_agent_input_slots.sh shared/tests/test_dispatch_disposition.sh; do
  last="$(bash "$t" 2>/dev/null | grep -E '^Total:' | tail -1)"
  fail="$(printf '%s' "$last" | sed -n 's/.*Fail: \([0-9]*\).*/\1/p')"
  printf '%s\t%s\n' "$t" "${fail:-NA}" >> "$OUT"
done
awk -F'\t' '$2!="0"{print}' "$OUT"
echo "files=$(wc -l < "$OUT")"
```

- [ ] **Step 2: 실행**

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.sh /Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.txt`
Expected: 파일 수 64 안팎, 0 이 아닌 줄만 출력된다(선재 RED 가 있으면 여기 보인다 — 그 파일 이름과 수를 기록해 둔다. 이후 「새 RED」는 이 수를 넘는 것만이다).

- [ ] **Step 3: 비교 스크립트 작성**

```bash
#!/bin/bash
# /Users/jeonghokim/.claude/jobs/b499da5f/tmp/compare.sh — baseline 대비 Fail 수 증감
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+steelman-goal-fit || exit 9
BASE=/Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.txt
NOW=/Users/jeonghokim/.claude/jobs/b499da5f/tmp/now.txt
bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/baseline.sh "$NOW" >/dev/null
join -t"$(printf '\t')" <(sort "$BASE") <(sort "$NOW") | awk -F'\t' '$2!=$3{print "CHANGED\t"$0}'
echo "compare done"
```

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/compare.sh`
Expected: `compare done` 만(변화 없음).

---

### Task 1: 토큰 이관 커밋 — `VALID_VERDICTS` + 픽스처 + 템플릿 + 과거 brief

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py` (`VALID_VERDICTS = ("defended", "switched", "deferred")` 한 줄)
- Modify: `plugins/spec-distill/tests/fixtures/interview-brief-*.md` 중 payload 70 · audit 71
- Modify: `plugins/spec-distill/templates/interview-brief-template.md` §5 예시 줄
- Modify: `plugins/spec-distill/tests/test_check_brief.sh` sed 패턴 한 줄
- Modify: `docs/superpowers/interview/2026-08-16-devbrew-weight-reduction-interview.md` (§5 ST1 줄) + `.audit.md` (§5 로그 append)
- Modify: `docs/superpowers/interview/2026-08-22-request-framing-phase0-interview.md` (§5 ST1 줄) + `.audit.md` (§5 로그 append)
- Modify: `docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md` (§5 ST1 줄 → refined) + `.audit.md` (§5 로그 append)

**Interfaces:**
- Produces: 검증기 어휘 `("kept", "refined", "switched", "deferred")` — T2 가 이 튜플을 모듈로 옮긴다. 리포 어디에도 기계 형태 `— verdict: defended —` 가 없다(AC14).

- [ ] **Step 1: 이관 스크립트 작성**

```python
# /Users/jeonghokim/.claude/jobs/b499da5f/tmp/migrate_tokens.py
import io, glob, re, sys
WT = "/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+steelman-goal-fit"
def rw(path, fn):
    t = io.open(path, encoding="utf-8").read(); n = fn(t)
    if n != t: io.open(path, "w", encoding="utf-8").write(n); return 1
    return 0
changed = {"fixture_payload": 0, "fixture_audit": 0, "other": 0}
# 1. 검증기 어휘 — 데이터와 같은 커밋에 움직인다(설계 §6.4)
changed["other"] += rw(f"{WT}/plugins/spec-distill/scripts/check_brief.py",
    lambda t: t.replace('VALID_VERDICTS = ("defended", "switched", "deferred")',
                        'VALID_VERDICTS = ("kept", "refined", "switched", "deferred")'))
# 2. 픽스처 — 역사가 아니다, 전부 기계 치환
for p in glob.glob(f"{WT}/plugins/spec-distill/tests/fixtures/interview-brief-*.md"):
    if p.endswith(".audit.md"):
        changed["fixture_audit"] += rw(p, lambda t: t.replace("steelman defended", "steelman kept"))
    else:
        changed["fixture_payload"] += rw(p, lambda t: t.replace("verdict: defended", "verdict: kept"))
# 3. 템플릿 §5 예시 + 게이트 테스트 sed 패턴
changed["other"] += rw(f"{WT}/plugins/spec-distill/templates/interview-brief-template.md",
    lambda t: t.replace("verdict: defended — ST1", "verdict: kept — ST1"))
changed["other"] += rw(f"{WT}/plugins/spec-distill/tests/test_check_brief.sh",
    lambda t: t.replace("s| → verdict: defended — ST1| → ST1|", "s| → verdict: kept — ST1| → ST1|"))
# 4. 과거 brief 기계 토큰 2줄 — 산문을 읽고 정한 값(D5). 줄 끝에 이관 표기.
#    08-16 ST1: 원안(통일) 유지 + ST1 이 든 위험 4건을 설계 제약으로 이월 → 경계를 다듬었다 = refined
#    08-22 ST1: steelman 의 핵심 사실 주장이 반증돼 원안 유지 = kept
past = {
    "2026-08-16-devbrew-weight-reduction-interview": ("refined", "ST1 verdict: defended → refined (이관 2026-09-06 — 원안 유지 + 위험 4건을 설계 제약으로 이월한 것은 보완이다)"),
    "2026-08-22-request-framing-phase0-interview":  ("kept",    "ST1 verdict: defended → kept (이관 2026-09-06 — 대안의 핵심 주장이 반증돼 원안 유지)"),
    "2026-09-05-steelman-goal-fit-interview":        ("refined", "ST1 verdict: defended → refined (이관 2026-09-06 — 사용자 판정은 「보완」이었고 어휘 부재로 defended 로 적혔다, S18)"),
}
for name, (tok, note) in past.items():
    pay = f"{WT}/docs/superpowers/interview/{name}.md"
    aud = f"{WT}/docs/superpowers/interview/{name}.audit.md"
    def fix_pay(t, tok=tok):
        assert t.count("verdict: defended — ST1") == 1, name
        return t.replace("verdict: defended — ST1", f"verdict: {tok} — ST1 (이관 2026-09-06)")
    changed["other"] += rw(pay, fix_pay)
    def fix_aud(t, note=note):
        m = re.search(r"^## 5\. 프로세스 로그\s*$", t, re.M); assert m, name
        nxt = re.search(r"^## \d+\.", t[m.end():], re.M)
        ins = m.end() + (nxt.start() if nxt else len(t) - m.end())
        return t[:ins].rstrip("\n") + f"\n- 이관 (2026-09-06): {note}\n\n" + t[ins:].lstrip("\n")
    changed["other"] += rw(aud, fix_aud)
print(changed)
```

- [ ] **Step 2: 실행**

Run: `python3 /Users/jeonghokim/.claude/jobs/b499da5f/tmp/migrate_tokens.py`
Expected: `{'fixture_payload': 70, 'fixture_audit': 71, 'other': 9}` (check_brief 1 · 템플릿 1 · 테스트 1 · brief 3 · audit 3).

- [ ] **Step 3: AC14 기계 형태 grep**

Run: `grep -rn -- "— verdict: defended —" plugins/spec-distill docs/superpowers/interview | grep -v CHANGELOG | wc -l`
Expected: `0`. (산문 `defended` 는 이 형태가 아니라 안 잡힌다 — 그것이 의도다.)

- [ ] **Step 4: 스위트 비교**

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/compare.sh`
Expected: `compare done` 만. `interview-brief-verdict-no-token` 같은 RED 기대 픽스처는 여전히 RED(실패 문자열만 no-verdict), GREEN 기대 픽스처는 GREEN. 변화가 있으면 이관이 어휘와 데이터를 갈라놓은 것이다 — 멈추고 원인을 본다.

- [ ] **Step 5: 이 브랜치 brief 게이트(AC18 선행)**

Run: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/0.53.1/scripts/check_brief.py gate docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md`
Expected: **`"pass": false`** 에 `malformed §5 verdict entries: 1` — 설치 캐시(0.53.1)의 검증기는 옛 어휘라 `refined` 를 모른다. 이것이 정상이다. 워크트리 검증기로 다시:
Run: `python3 plugins/spec-distill/scripts/check_brief.py gate docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md`
Expected: `{"pass": true, ...}`.

- [ ] **Step 6: 커밋**

```bash
git add -A plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/fixtures plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/tests/test_check_brief.sh docs/superpowers/interview
git status --short | grep -v '^M ' ; # 예상: 출력 없음(전부 M)
git commit -q -F - <<'MSG'
refactor(spec-distill): steelman verdict 토큰 이관 defended→kept, refined 추가

VALID_VERDICTS 와 그 어휘를 쓰는 데이터(픽스처 141 · 템플릿 §5 예시 · 게이트 테스트
sed 패턴 · brief §5 기계 토큰 3줄)를 한 커밋에 움직인다 — 갈라 놓으면 어느 순서든
GREEN 기대 픽스처 ~60개가 no-verdict RED 다. 산문·verbatim 원문은 시점 기록이라
건드리지 않는다. 과거 두 줄과 이 브랜치 ST1 은 산문을 읽고 kept/refined 를 골랐다
(설계 D5). 별칭 없음 — spec-distill 은 v0.x 라 one-minor window 면제.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
MSG
```

---

### Task 2: `scripts/skepticism.py` 모듈 + check_brief 배선 + 픽스처 + 락

**Files:**
- Create: `plugins/spec-distill/scripts/skepticism.py`
- Modify: `plugins/spec-distill/scripts/check_brief.py` (상수·함수 제거, import, gate 배선, `skepticism` 서브커맨드)
- Modify: `plugins/spec-distill/tests/fixtures/interview-brief-steelman-empty.md`, `interview-brief-na-tried.md` (검토 항목 1줄)
- Create: 픽스처 6쌍 — `interview-brief-steelman-empty-norecord`, `interview-brief-verdict-refined`, `interview-brief-verdict-defended`, `interview-brief-review-record-malformed`, `interview-brief-verdict-deferred-hold`, `interview-brief-review-only-no-reject` (각 `.md` + `.audit.md`)
- Create: `plugins/spec-distill/tests/test_skepticism_module.sh`
- Modify: `plugins/spec-distill/tests/test_check_brief.sh` (T12 갱신 + 새 단언)

**Interfaces:**
- Produces (모듈 공개 이름 — T4 의 문서와 T6 의 CHANGELOG 가 인용한다):
  ```python
  VALID_VERDICTS: tuple[str, ...]            # ("kept","refined","switched","deferred")
  URL_RE: re.Pattern; strip_bullet(ln: str) -> str
  verdict_entries(entries: list[str]) -> list[str]
  review_record_entries(entries: list[str]) -> list[str]
  skepticism_malformed(entries: list[str]) -> list[str]
  review_record_malformed(entries: list[str]) -> list[str]
  skepticism_closure_ok(entries: list[str]) -> bool
  bijection_a_errors(entries: list[str], audit_sec3_text: str) -> list[str]
  ```
- Consumes: check_brief 의 `section5_entries(text)`(§5 entry 줄) · `_section_text(audit_text, "3", "Steelman 원문")`.
- gate 실패 문자열(테스트가 grep 한다): `§5 skepticism 기록 0건 (verdict 항목도 검토 항목도 없음)` · `malformed §5 검토 entries: <n>` · 기존 `malformed §5 verdict entries: <n>` · `§5 기각 항목 0건 (N/A sentinel 없음)`.
- §5 검토 항목 형식(픽스처·템플릿·steelman.md 가 같은 모양): `- 검토 — steelman 0건: 검토한 방향 <N>개 · 전제 <…> · trigger 후보 <…> → 기각 이유 <…>`
- §5 보류 항목 형식: `- 보류 — <대안> → §3 OQ<k> — verdict: deferred — ST<N> — 부착 M/N`

- [ ] **Step 1: 모듈 단위 테스트(RED) 작성**

```bash
#!/usr/bin/env bash
# plugins/spec-distill/tests/test_skepticism_module.sh
# scripts/skepticism.py — §5 skepticism 검사 모듈의 함수 단위 락 (설계 §6.3 · L6).
# check_brief.py 를 import 하지 않는 방향(check_brief → skepticism 하나)을 AC21 로 잠근다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
SD="$REPO_ROOT/plugins/spec-distill/scripts"
. "$REPO_ROOT/shared/tests/assert.sh"

test -f "$SD/skepticism.py" && ok "skepticism.py 실재" || { no "skepticism.py 부재"; finish; }

# AC21 — 의존 방향
grep -qE '^(import|from) check_brief' "$SD/skepticism.py" \
  && no "AC21: skepticism.py 가 check_brief 를 import 한다 (순환)" \
  || ok "AC21: skepticism.py 는 check_brief 를 import 하지 않는다"
grep -qE '^from skepticism import' "$SD/check_brief.py" \
  && ok "AC21: check_brief.py 가 skepticism 을 들여온다" \
  || no "AC21: check_brief.py 에 from skepticism import 부재"
grep -qE '^VALID_VERDICTS' "$SD/check_brief.py" \
  && no "AC8: VALID_VERDICTS 정의가 check_brief.py 에 남아 있다" \
  || ok "AC8: VALID_VERDICTS 정의는 skepticism.py 에만"

# 함수 단위 — 파이썬으로 판정을 내고 한 줄씩 받는다
report="$(PYTHONDONTWRITEBYTECODE=1 python3 - "$SD" <<'PY'
import sys; sys.path.insert(0, sys.argv[1])
import skepticism as S
def line(name, cond): print(("OK\t" if cond else "NO\t") + name)
line("AC8: VALID_VERDICTS == kept/refined/switched/deferred",
     S.VALID_VERDICTS == ("kept", "refined", "switched", "deferred"))
V = ["- 기각 — islands architecture 우선 도입 — verdict: kept — ST1",
     "- 위험 — 숨은 가정 | x: y — z"]
R = ["- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 · trigger 후보 islands 벤치마크 → 기각 이유 전제 충돌 없음"]
RB = ["- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 · trigger 후보 islands 벤치마크"]  # 기각 이유 없음
D = ["- 보류 — islands architecture 우선 도입 → §3 OQ1 — verdict: deferred — ST1 — 부착 0/1"]
OLD = ["- 기각 — islands architecture 우선 도입 — verdict: defended — ST1"]
line("verdict_entries 가 verdict: 줄만 고른다", S.verdict_entries(V) == [V[0]])
line("review_record_entries 가 검토 접두만 고른다", S.review_record_entries(R + V) == R)
line("review_record_entries 는 '검토함' 같은 변형을 안 고른다",
     S.review_record_entries(["- 검토함 — steelman 0건: 검토한 방향 1개 · 전제 P1 · trigger 후보 a → 기각 이유 b"]) == [])
line("skepticism_malformed: kept 는 정상", S.skepticism_malformed(V) == [])
line("skepticism_malformed: refined 는 정상",
     S.skepticism_malformed(["- 기각 — 버린 절반 → 이유 — verdict: refined — ST1 — 부착 1/2"]) == [])
line("skepticism_malformed: deferred(보류 접두)는 정상", S.skepticism_malformed(D) == [])
line("skepticism_malformed: 옛 토큰 defended 는 no-verdict",
     any("no-verdict" in m for m in S.skepticism_malformed(OLD)))
line("skepticism_malformed: ST 참조 없으면 no-ST-ref",
     any("no-ST-ref" in m for m in S.skepticism_malformed(["- 기각 — islands architecture 우선 도입 — verdict: kept"])))
line("review_record_malformed: 네 토큰 다 있으면 통과", S.review_record_malformed(R) == [])
line("review_record_malformed: 기각 이유 없으면 지목", len(S.review_record_malformed(RB)) == 1 and "기각 이유" in S.review_record_malformed(RB)[0])
line("closure: verdict 1 → ok", S.skepticism_closure_ok(V))
line("closure: 검토 1(정상) → ok", S.skepticism_closure_ok(R))
line("closure: 검토 1(형식 미달) → not ok", not S.skepticism_closure_ok(RB))
line("closure: 둘 다 0 → not ok", not S.skepticism_closure_ok(["- 기각 — a → b", "- 위험 — c"]))
line("closure: 빈 §5 → not ok", not S.skepticism_closure_ok([]))
aud = "#### ST1 — 요지\n\n> verbatim\n"
line("bijection A: 일치", S.bijection_a_errors(V, aud) == [])
line("bijection A: payload 만 ST9", any(m.startswith("ST9") and "audit §3에 없음" in m
     for m in S.bijection_a_errors(["- 기각 — x y z w q — verdict: kept — ST9"], aud)))
line("bijection A: audit 만 ST1", any("판정 없는 steelman" in m for m in S.bijection_a_errors([], aud)))
line("bijection A: URL 안 /ST9/ 는 참조가 아니다",
     S.bijection_a_errors(["- 기각 — https://x.test/ST9/ 인용 문장 — verdict: kept — ST1"], aud) == [])
line("bijection A: 보류 항목도 ST 를 참조한다", S.bijection_a_errors(D, aud) == [])
line("strip_bullet 은 - 와 * 를 뗀다", S.strip_bullet("* 기각 — a") == "기각 — a" and S.strip_bullet("- 기각 — a") == "기각 — a")
PY
)"
while IFS="$(printf '\t')" read -r st msg; do
  [[ -n "${st:-}" ]] || continue
  [[ "$st" == OK ]] && ok "$msg" || no "$msg"
done <<< "$report"
[[ "$(printf '%s\n' "$report" | grep -c .)" -ge 20 ]] \
  && ok "함수 단위 판정 ≥20 줄 (vacuous 아님)" || no "함수 단위 판정이 20 줄 미만 — 파이썬 블록이 죽었다"
finish
```

- [ ] **Step 2: RED 확인**

Run: `bash plugins/spec-distill/tests/test_skepticism_module.sh | tail -3`
Expected: `✗ skepticism.py 부재` 뒤 `Fail: 1` 로 끝난다.

- [ ] **Step 3: 모듈 작성**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""skepticism.py — brief payload `## 5. 기각 · Blind Spots` 의 skepticism 검사. **이 리포에서 한 곳.**

입력은 이미 잘린 것만 받는다 — payload §5 의 entry 줄 목록(`entries`, check_brief 의
`section5_entries()` 가 자른 것)과 audit §3 텍스트(`audit_sec3_text`, check_brief 의
`_section_text(audit, "3", "Steelman 원문")` 이 자른 것). 절 자르기·불릿 관례는 check_brief 에
남는다. 이 모듈은 check_brief 를 import 하지 않는다 — 의존 방향은 check_brief → skepticism 하나다.

검사 넷:
- verdict 항목 형식(`skepticism_malformed`) — PN4 containment: 유효 토큰 · statement ≥10자 · ST<N> 참조.
- 검토 항목(`review_record_*`) — steelman 0건으로 skepticism 을 닫는 기록. 네 토큰 containment.
- 폐쇄(`skepticism_closure_ok`) — verdict ≥1 또는 형식 통과 검토 ≥1. 둘 다 0 이면 False.
- bijection A(`bijection_a_errors`) — payload §5 의 ST<N> 참조 집합 == audit §3 의 `#### ST<N>` 집합.
"""
from __future__ import annotations

import re

URL_RE = re.compile(r"https?://\S+")
# 불릿을 떼는 곳은 여기 하나다 — `-` 와 `*` 를 둘 다 받는다(check_brief 의 `_entry_lines` 와 같은 관례).
BULLET_PREFIX_RE = re.compile(r"^\s*[-*]\s+")


def strip_bullet(ln: str) -> str:
    """항목 줄에서 선행 불릿(`-` 또는 `*`) **하나**와 뒤따르는 공백을 뗀다."""
    return BULLET_PREFIX_RE.sub("", ln, count=1)


VALID_VERDICTS = ("kept", "refined", "switched", "deferred")
# statement<10c 측정에서 판정 어구 자체를 제외한다 — 남겨두면 그 어구(>=14자)가 항상 통과시켜
# 검사가 도달 불가능해진다.
VERDICT_CLAUSE_RE = re.compile(r"verdict:\s*\S+", re.IGNORECASE)
ST_HEADING_RE = re.compile(r"^####\s+(ST\d+)\b", re.MULTILINE)
ST_REF_RE = re.compile(r"\b(ST\d+)\b")

# 검토 항목 — steelman 0건 폐쇄 기록. `steelman 0건` 리터럴까지 요구해 미래의 다른 `검토 —` 와 겹치지 않게 좁힌다.
REVIEW_RECORD_RE = re.compile(r"^\s*[-*]\s*검토\s*—\s*steelman\s*0건", re.IGNORECASE)
REVIEW_RECORD_TOKENS = ("검토한 방향", "전제", "trigger 후보", "기각 이유")


def verdict_entries(entries: list[str]) -> list[str]:
    return [ln for ln in entries if "verdict:" in ln]


def review_record_entries(entries: list[str]) -> list[str]:
    return [ln for ln in entries if REVIEW_RECORD_RE.match(ln)]


def review_record_malformed(entries: list[str]) -> list[str]:
    """검토 항목 형식 검사 — 네 토큰 containment(정확 일치 아님)."""
    bad: list[str] = []
    for ln in review_record_entries(entries):
        miss = [tok for tok in REVIEW_RECORD_TOKENS if tok not in ln]
        if miss:
            bad.append(f"{ln[:60]} :: missing {','.join(miss)}")
    return bad


def skepticism_closure_ok(entries: list[str]) -> bool:
    """skepticism 을 닫을 기록이 있는가 — verdict 항목 ≥1 **또는** 형식 통과 검토 항목 ≥1 (C26).

    둘 다 0 이면 False. 원장 행(`floor:skepticism — closed`)은 형식만 보므로 검토 흔적은 여기서만 요구된다.
    """
    if verdict_entries(entries):
        return True
    records = review_record_entries(entries)
    if not records:
        return False
    return len(review_record_malformed(entries)) < len(records)


def skepticism_malformed(entries: list[str]) -> list[str]:
    """§5 `verdict:` 항목 형식 검사. PN4: containment. URL 요구는 없다(N1a 가 별도로 금지)."""
    bad: list[str] = []
    for ln in entries:
        if "verdict:" not in ln:
            continue
        has_verdict = bool(re.search(r"verdict:\s*(?:%s)\b" % "|".join(VALID_VERDICTS),
                                     ln, re.IGNORECASE))
        # URL 을 먼저 벗겨낸 뒤 ST<N> 을 찾는다 — URL 경로 조각의 word-bounded ST<N>(예: `/ST9/`) 방어.
        ln_no_url = URL_RE.sub("", ln)
        has_st = bool(ST_REF_RE.search(ln_no_url))
        stripped = strip_bullet(VERDICT_CLAUSE_RE.sub("", ST_REF_RE.sub("", ln_no_url))).strip()
        has_stmt = len(stripped) >= 10
        if not (has_verdict and has_stmt and has_st):
            miss = []
            if not has_stmt:
                miss.append("statement<10c")
            if not has_verdict:
                miss.append("no-verdict")
            if not has_st:
                miss.append("no-ST-ref")
            bad.append(f"{ln[:60]} :: {','.join(miss)}")
    return bad


def bijection_a_errors(entries: list[str], audit_sec3_text: str) -> list[str]:
    """bijection A — payload §5 ↔ audit §3. 개수 비교가 아니라 **id 집합 비교**다.

    양쪽 공집합(steelman 0건)은 정합이다 — 0건 폐쇄의 기록은 `skepticism_closure_ok` 가 따로 요구한다.
    """
    refs = set()
    for ln in verdict_entries(entries):
        refs |= set(ST_REF_RE.findall(URL_RE.sub("", ln)))
    declared = set(ST_HEADING_RE.findall(audit_sec3_text))
    errs = []
    for st in sorted(refs - declared):
        errs.append(f"{st}: payload §5가 참조하지만 audit §3에 없음 (원문 없는 판정)")
    for st in sorted(declared - refs):
        errs.append(f"{st}: audit §3에 있지만 payload §5가 참조하지 않음 (판정 없는 steelman)")
    return errs
```

- [ ] **Step 4: check_brief.py 배선**

`plugins/spec-distill/scripts/check_brief.py` 에서:

(a) `import section6  # noqa: E402` 바로 아래에 추가:
```python
from skepticism import (  # noqa: E402
    URL_RE, strip_bullet as _strip_bullet, bijection_a_errors as _bijection_a,
    skepticism_malformed as _skepticism_malformed, review_record_malformed,
    review_record_entries, skepticism_closure_ok,
)
```

(b) 삭제: `URL_RE = re.compile(r"https?://\S+")` 줄, `VALID_VERDICTS = (...)` 줄, `BULLET_PREFIX_RE = ...` 와 `def _strip_bullet` 정의(그 위 주석 블록은 남겨도 된다), `ST_HEADING_RE`·`ST_REF_RE`·`VERDICT_CLAUSE_RE` 정의와 그 주석, `def verdict_entries`, `def bijection_a_errors`, `def skepticism_malformed` 함수 전체. `ATTRIBUTION_MARKERS` 와 `attribution_block_missing` 은 **남긴다**(§6 검사다).

(c) `gate()` 의 bijection A 호출을 바꾼다:
```python
            if not sec5_absent and not any(m.startswith("3.") for m in amiss):
                ae = _bijection_a(section5_entries(text),
                                  _section_text(audit_text, "3", "Steelman 원문"))
                if ae:
                    failures.append(f"bijection A (payload §5↔audit §3): {ae}")
```

(d) `gate()` 의 `mal = skepticism_malformed(text)` 블록을 바꾼다:
```python
    entries5 = section5_entries(text) if not sec5_absent else []
    mal = _skepticism_malformed(entries5)
    if mal:
        failures.append(f"malformed §5 verdict entries: {len(mal)}")
    rmal = review_record_malformed(entries5)
    if rmal:
        failures.append(f"malformed §5 검토 entries: {len(rmal)}")
    if not sec5_absent and not skepticism_closure_ok(entries5):
        failures.append("§5 skepticism 기록 0건 (verdict 항목도 검토 항목도 없음)")
```

(e) `main()` 의 `skepticism` 서브커맨드:
```python
    if sub == "skepticism":
        e5 = section5_entries(text)
        print(json.dumps({"malformed": _skepticism_malformed(e5),
                          "review_records": review_record_entries(e5),
                          "review_malformed": review_record_malformed(e5)}, ensure_ascii=False))
        return 0
```

(f) 모듈 docstring 상단 근처의 `VALID_VERDICTS`/`skepticism` 언급 주석(§"§5 기각 `verdict:` entry must contain…" 문단)은 그대로 둔다 — 계약 서술이다. 단 `skepticism <payload>` 사용법 줄에 `→ {"malformed": [...], "review_records": [...], "review_malformed": [...]}` 로 갱신.

- [ ] **Step 5: 모듈 테스트 GREEN + 게이트 테스트 회귀 확인**

Run: `bash plugins/spec-distill/tests/test_skepticism_module.sh | tail -1 && bash plugins/spec-distill/tests/test_check_brief.sh | tail -1`
Expected: 모듈 `Fail: 0`. 게이트 테스트는 **T12 와 T19(na-tried) 두 줄이 RED** — 새 폐쇄 규칙이 verdict 없는 두 GREEN 기대 픽스처를 잡는다(설계 L4 도출 결과와 같다). 그 외 변화 없음.

- [ ] **Step 6: 픽스처 두 개에 검토 항목 추가**

`plugins/spec-distill/tests/fixtures/interview-brief-steelman-empty.md` 와 `interview-brief-na-tried.md` 의 `## 5. 기각 · Blind Spots` 첫 항목 **앞**에 한 줄:
```
- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 SSR 우선 · trigger 후보 islands 벤치마크 → 기각 이유 전제와 충돌하지 않고 경계만 다듬는 근거
```
두 audit 의 `floor:skepticism` evidence 는 `§5 검토 항목(steelman 0건)` 으로 바꾼다(T1 이 `steelman kept` 로 바꿔 둔 문구가 0건 픽스처에 맞지 않는다):

```bash
cd plugins/spec-distill/tests/fixtures && for f in interview-brief-steelman-empty interview-brief-na-tried; do
  python3 - "$f.md" <<'PY'
import sys, io
p = sys.argv[1]; t = io.open(p, encoding="utf-8").read()
hdr = "## 5. 기각 · Blind Spots\n\n"
assert t.count(hdr) == 1, p
t = t.replace(hdr, hdr + "- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 SSR 우선 · trigger 후보 islands 벤치마크 → 기각 이유 전제와 충돌하지 않고 경계만 다듬는 근거\n")
io.open(p, "w", encoding="utf-8").write(t)
PY
  sed -i.bak 's|floor:skepticism — closed — §5 islands steelman kept|floor:skepticism — closed — §5 검토 항목(steelman 0건)|' "$f.audit.md"; rm -f "$f.audit.md.bak"
done; cd - >/dev/null
```

(픽스처 §5 헤딩 뒤 빈 줄 형태가 다르면 `assert` 가 멈춘다 — 그때는 실제 형태를 보고 `hdr` 를 맞춘다.)

Run: `bash plugins/spec-distill/tests/test_check_brief.sh | tail -1`
Expected: baseline 과 같은 Fail 수(T12·T19 복귀).

- [ ] **Step 7: 새 픽스처 6쌍 생성 스크립트**

```bash
#!/bin/bash
# /Users/jeonghokim/.claude/jobs/b499da5f/tmp/make_fixtures.sh
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+steelman-goal-fit/plugins/spec-distill/tests/fixtures || exit 9
clone() { # clone <src-base> <dst-base>
  cp "$1.md" "$2.md"; cp "$1.audit.md" "$2.audit.md"
  sed -i.bak "s|^audit_file:.*|audit_file: $2.audit.md|" "$2.md"
  sed -i.bak "s|^payload:.*|payload: $2.md|" "$2.audit.md"
  rm -f "$2.md.bak" "$2.audit.md.bak"
}
REC='- 검토 — steelman 0건: 검토한 방향 2개 · 전제 P1 SSR 우선 · trigger 후보 islands 벤치마크 → 기각 이유 전제와 충돌하지 않고 경계만 다듬는 근거'
# 1) verdict 0 + 검토 0 → RED 「skepticism 기록 0건」
clone interview-brief-steelman-empty interview-brief-steelman-empty-norecord
grep -v '^- 검토 — steelman 0건' interview-brief-steelman-empty-norecord.md > t && mv t interview-brief-steelman-empty-norecord.md
# 2) refined 토큰 → GREEN
clone interview-brief-valid interview-brief-verdict-refined
sed -i.bak 's|verdict: kept — ST1|verdict: refined — ST1 — 부착 1/2|' interview-brief-verdict-refined.md; rm -f *.bak
# 3) 옛 토큰 → RED no-verdict (AC14 제외 집합 ⑴ — 파일명에 verdict-defended)
clone interview-brief-valid interview-brief-verdict-defended
sed -i.bak 's|verdict: kept — ST1|verdict: defended — ST1|' interview-brief-verdict-defended.md; rm -f *.bak
# 4) 검토 항목에 「기각 이유」 없음 → RED malformed 검토
clone interview-brief-steelman-empty interview-brief-review-record-malformed
sed -i.bak 's| → 기각 이유 전제와 충돌하지 않고 경계만 다듬는 근거||' interview-brief-review-record-malformed.md; rm -f *.bak
# 5) 보류 1 + 기각 0 + sentinel 없음 → RED 「§5 기각 항목 0건」 (AC19: 보류는 R4 로 안 센다)
clone interview-brief-valid interview-brief-verdict-deferred-hold
python3 - interview-brief-verdict-deferred-hold.md <<'PY'
import sys, io
p = sys.argv[1]; t = io.open(p, encoding="utf-8").read()
t = t.replace("- 기각 — 전체 클라이언트 SPA → cold load에서 TTFP 회귀\n", "")
t = t.replace("- 기각 — islands architecture 우선 도입 — verdict: kept — ST1",
              "- 보류 — islands architecture 우선 도입 → §3 OQ1 — verdict: deferred — ST1 — 부착 0/1")
io.open(p, "w", encoding="utf-8").write(t)
PY
# 6) 검토 1 + 기각 0 + sentinel 없음 → RED 「§5 기각 항목 0건」 (AC12: 검토는 기각을 대신 못 한다)
clone interview-brief-steelman-empty interview-brief-review-only-no-reject
grep -v '^- 기각 — ' interview-brief-review-only-no-reject.md > t && mv t interview-brief-review-only-no-reject.md
ls interview-brief-steelman-empty-norecord.* interview-brief-verdict-refined.* interview-brief-verdict-defended.* interview-brief-review-record-malformed.* interview-brief-verdict-deferred-hold.* interview-brief-review-only-no-reject.* | wc -l
```

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/make_fixtures.sh`
Expected: `12`.

기대 판정을 손으로 확인:
Run: `cd plugins/spec-distill && for f in steelman-empty-norecord verdict-refined verdict-defended review-record-malformed verdict-deferred-hold review-only-no-reject; do printf '%s: ' $f; python3 scripts/check_brief.py gate tests/fixtures/interview-brief-$f.md 2>/dev/null | cut -c1-160; echo; done`
Expected: norecord → `"pass": false` + `skepticism 기록 0건` · refined → `"pass": true` · defended → false + `malformed §5 verdict entries: 1` · review-record-malformed → false + `malformed §5 검토 entries: 1` **과** `skepticism 기록 0건`(형식 미달 검토 항목은 폐쇄로 안 세므로 둘이 함께 나오는 것이 정상) · deferred-hold → false + `§5 기각 항목 0건` 만 · review-only-no-reject → false + `§5 기각 항목 0건` 만. 여기 적힌 것 밖의 실패 문자열(예: bijection A · missing sections · audit pairing)이 섞이면 픽스처가 잘못 잘린 것이다 — 고친다.

- [ ] **Step 8: 게이트 테스트에 단언 추가**

`plugins/spec-distill/tests/test_check_brief.sh` 의 T12 블록을 아래로 **교체**한다:

```bash
# T12 (v0.54.0 — C26): steelman 0건은 `검토 —` 기록 항목이 있어야 green. 기록이 없으면 red.
python3 "$SCRIPT" gate "$FX/interview-brief-steelman-empty.md" >/dev/null 2>&1 \
  && ok "T12: steelman 0건 + 검토 항목 1 → green" \
  || no "T12: 검토 항목이 있는 0건 payload 가 막힌다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-steelman-empty-norecord.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'skepticism 기록 0건'; } \
  && ok "T12(음성): verdict 0 + 검토 0 → red 「skepticism 기록 0건」 (AC9)" \
  || no "T12(음성): 기록 없는 0건이 통과했다 — 폐쇄 요구가 없다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-review-record-malformed.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'malformed §5 검토 entries'; } \
  && ok "T12(형식): 검토 항목에 기각 이유 없음 → red (AC11)" \
  || no "T12(형식): 네 토큰 미달 검토 항목이 통과했다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-review-only-no-reject.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '§5 기각 항목 0건'; } \
  && ok "T12(R4): 검토 1 + 기각 0 → red 「§5 기각 항목 0건」 — 검토는 기각을 대신 못 한다 (AC12)" \
  || no "T12(R4): 검토 항목이 R4 기각으로 세어졌다"

# T20 (v0.54.0 — C10/C15): 새 어휘. refined green · 옛 defended red · 보류 deferred 는 R4 로 안 센다.
python3 "$SCRIPT" gate "$FX/interview-brief-verdict-refined.md" >/dev/null 2>&1 \
  && ok "T20: verdict: refined → green (AC13)" || no "T20: refined 가 막힌다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-verdict-defended.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q 'malformed §5 verdict entries'; } \
  && ok "T20: 옛 토큰 defended → red no-verdict (AC13, 별칭 없음)" \
  || no "T20: defended 가 여전히 유효 토큰이다 — 별칭이 살아 있다"
out="$(python3 "$SCRIPT" gate "$FX/interview-brief-verdict-deferred-hold.md" 2>/dev/null)"; rc=$?
{ [[ $rc -ne 0 ]] && printf '%s' "$out" | grep -q '§5 기각 항목 0건' \
    && ! printf '%s' "$out" | grep -q 'malformed §5 verdict\|bijection A'; } \
  && ok "T20: 보류 — deferred 1 + 기각 0 → red 는 R4 만 (verdict 항목·bijection A 는 정상) (AC19)" \
  || no "T20: 보류 항목이 R4 기각으로 세어졌거나 verdict 항목으로 안 읽힌다"
```

Run: `bash plugins/spec-distill/tests/test_check_brief.sh | tail -1`
Expected: baseline Fail 수 그대로, Total 이 +7.

- [ ] **Step 9: 스위트 비교 + 커밋**

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/compare.sh`
Expected: `compare done` 만.

```bash
git add plugins/spec-distill/scripts/skepticism.py plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/tests/test_skepticism_module.sh plugins/spec-distill/tests/test_check_brief.sh plugins/spec-distill/tests/fixtures
git commit -q -F - <<'MSG'
feat(spec-distill): §5 skepticism 검사를 scripts/skepticism.py 로, 0건 폐쇄 기록 요구

VALID_VERDICTS · verdict 형식 · bijection A 가 새 모듈로 가고 check_brief 는 절을 잘라
넘기기만 한다(의존 방향 check_brief → skepticism 하나). 새 규칙: verdict 항목 0건이면
`검토 — steelman 0건: 검토한 방향 N개 · 전제 … · trigger 후보 … → 기각 이유 …` 항목이
있어야 gate 를 통과한다(C26) — 원장 행은 형식만 보므로 검토 흔적은 여기서만 남는다.
`보류 —` 접두의 deferred 항목은 verdict 로 세되 R4 기각으로는 안 센다. 픽스처 6쌍 신설.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
MSG
```

- [ ] **Step 10: 변이 검사(커밋 뒤)**

각 변이 후 `bash plugins/spec-distill/tests/test_skepticism_module.sh plugins/spec-distill/tests/test_check_brief.sh 2>/dev/null | grep -c '✗'` 로 RED 수를 보고, `git checkout -- plugins/spec-distill/scripts/skepticism.py` 로 복원한다. 복원 뒤 `git status --short` 가 비어 있어야 한다.

| 변이 | 명령 | 기대 |
|---|---|---|
| 토큰 삭제 | `sed -i.bak 's/("kept", "refined", "switched", "deferred")/("refined", "switched", "deferred")/' plugins/spec-distill/scripts/skepticism.py` | ✗ ≥ 3 (T15 valid · T20 refined 는 통과, kept 픽스처 다수 RED) |
| 토큰 재추가 | `sed -i.bak 's/("kept", "refined", "switched", "deferred")/("kept", "refined", "switched", "deferred", "defended")/' …` | ✗ ≥ 2 (모듈 AC8 등식 · T20 defended 음성) |
| 반전 | `sed -i.bak 's/return len(review_record_malformed(entries)) < len(records)/return len(review_record_malformed(entries)) >= len(records)/' …` | ✗ ≥ 2 (closure 검토 1 정상 · T12 형식) |
| 형태 | `sed -i.bak 's/검토\\s\*—/검토함\\s*—/' plugins/spec-distill/scripts/skepticism.py` (REVIEW_RECORD_RE 의 `검토` 를 `검토함` 으로 — 실행 뒤 `grep -n 'REVIEW_RECORD_RE = ' …/skepticism.py` 로 `검토함` 이 들어갔는지 눈으로 확인한다) | ✗ ≥ 3 (검토 항목 인식 전부) |

각 행에서 기대 미달이면 그 락은 이빨이 없다 — 단언을 고친 뒤 다시 잰다. 마지막에 `rm -f plugins/spec-distill/scripts/*.bak`.

---

### Task 3: steelman-builder 페르소나

**Files:**
- Modify: `plugins/spec-distill/agents/steelman-builder.md` (전문 교체)
- Modify: `plugins/spec-distill/tests/test_steelman_builder_scope.sh` (단언 추가)

**Interfaces:**
- Produces: 슬롯 태그 `direction`/`SUSPECT_DIRECTION` · `trigger`/`TRIGGER` · `goal`/`GOAL` · `premises`/`PREMISES` · `constraints`/`CONSTRAINTS`. T4 의 dispatch 프롬프트가 정확히 이 다섯을 `<tag>${VAR}</tag>` 로 전달해야 `shared/tests/test_agent_input_slots.sh` 가 GREEN 이다. `kind: orchestrator_framing` 은 premises 에만 — T5 가 면제 등재하기 전까지 그 스위트는 RED 다(예상된 중간 상태, T5 에서 닫힌다).
- 출력 스키마 키(T4 의 4-block 이 읽는다): `case_for_alternative.statement/strongest` · `case_for_current.strongest` · `premise_refutation.hits/why` · `premise_list_challenge` · `recommendation` · `refined_takes` · `refined_drops` · `evidence[].url/supports/claim/touches` · `repo_claims[].path/anchor/line/claim/touches`.

- [ ] **Step 1: 락 단언 추가(RED)**

`plugins/spec-distill/tests/test_steelman_builder_scope.sh` 의 `finish` 앞에:

```bash
# v0.54.0 — 목표 적합 재설계 (설계 §6.1). 부재 락에는 양성 짝을 둔다.
grep -qE '^input_slots:' <<<"$fm" && ok "input_slots 선언" || no "input_slots 부재"
for tag in direction trigger goal premises constraints; do
  grep -qE "^  - tag: ${tag}$" <<<"$fm" && ok "슬롯 태그 $tag" || no "슬롯 태그 $tag 부재 (AC2)"
done
[[ "$(grep -c '^    kind: orchestrator_framing$' <<<"$fm")" -eq 1 ]] \
  && ok "orchestrator_framing 은 슬롯 하나(premises)에만" || no "orchestrator_framing 슬롯 수가 1 이 아니다 (AC2)"
awk '/tag: premises/{f=1} f&&/kind:/{print; exit}' <<<"$fm" | grep -q 'orchestrator_framing' \
  && ok "premises 의 kind 가 orchestrator_framing" || no "premises 의 kind 가 다르다"
grep -q 'confidence' "$AGENT" \
  && no "AC1: confidence 필드/규칙 잔존 (폐지, 설계 O3)" || ok "AC1: confidence 부재"
for tok in recommendation premise_refutation premise_list_challenge touches repo_claims anchor refined_takes refined_drops case_for_alternative case_for_current; do
  grep -q "$tok" "$AGENT" && ok "AC1: 스키마 키 $tok 존재" || no "AC1: 스키마 키 $tok 부재"
done
grep -q '원안의 옹호자' "$AGENT" \
  && no "AC3: 「원안의 옹호자」 문구 잔존 — 한 편 배정 역할" || ok "AC3: 「원안의 옹호자」 부재"
grep -q '어느 한 편의 옹호자' "$AGENT" \
  && ok "AC3: 「어느 한 편의 옹호자」 존재 (양성 짝)" || no "AC3: 「어느 한 편의 옹호자」 부재"
grep -q 'coverage-mapper neglect\|neglect' "$AGENT" \
  && no "C18: neglect trigger 문구 잔존" || ok "C18: neglect 부재"
grep -qE 'kept.*refined.*switched' "$AGENT" && ok "추천 어휘 kept/refined/switched" || no "추천 어휘 부재"
grep -qE 'defended|방어' "$AGENT" && no "옛 어휘 defended/방어 잔존" || ok "옛 어휘 부재"
```

Run: `bash plugins/spec-distill/tests/test_steelman_builder_scope.sh | tail -1`
Expected: Fail ≥ 15 (새 단언 대부분 RED).

- [ ] **Step 2: 페르소나 전문 교체**

`plugins/spec-distill/agents/steelman-builder.md` 를 아래 내용으로 **덮어쓴다**:

````markdown
---
name: steelman-builder
model: inherit
cost_class: variable
color: red
tools: Read, Grep, Glob, WebSearch, WebFetch
input_slots:
  - tag: direction
    var: SUSPECT_DIRECTION
    kind: task
  - tag: trigger
    var: TRIGGER
    kind: task
  - tag: goal
    var: GOAL
    kind: artifact
  - tag: premises
    var: PREMISES
    kind: orchestrator_framing
  - tag: constraints
    var: CONSTRAINTS
    kind: artifact
description: >
  Use this agent during a spec-distill interview when a direction is suspect
  (landscape contradiction / known anti-pattern / conflict with a stated user
  constraint) to build the strongest case for BOTH the alternative and the
  current direction against the same criterion — the user's goal — judge whether
  any evidence refutes a stated core premise, and recommend kept / refined /
  switched. Independent analyst, read-only by design (Law 2 frontmatter scoping).
  Output is consumed verbatim by conducting-interview.

  <example>Context: User wants a custom auth system; landscape shows mature OSS.
  user: "이 방향 의심돼 — 양쪽 케이스 세워줘"
  assistant: "I'll dispatch the steelman-builder agent to write both cases against
  the user's goal and judge whether the evidence hits a core premise."</example>
---

# Steelman-Builder Agent (R3 의심 게이트)

You are the steelman-builder. You are responsible for writing the strongest case for
the alternative *and* for the current direction against the same criterion (the
user's goal), judging whether any evidence refutes a stated core premise, and
recommending kept / refined / switched. You are NOT responsible for deciding
direction, for writing files, or for advocating one side.

당신은 방향을 *결정*하지 않습니다 — 사용자가 결정합니다(P17). 당신이 하는 일은 같은 기준
위에 두 케이스를 나란히 세우고, 근거가 전제에 닿는지 판정하고, 추천 하나를 내는 것입니다.

## You are / are not

- You ARE: 양쪽 케이스를 같은 기준으로 쓰는 독립 분석자. 전제 반증 판정자. 전제 목록 반박자.
  prior-art 발굴자.
- You are NOT: 파일 작성자(Write/Edit 물리 차단), 방향 결정자, **어느 한 편의 옹호자**.

## Input

- `<direction>` 의심 방향 한 문장.
- `<trigger>` 게이트를 발동시킨 이유 — landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의
  충돌 중 하나.
- `<goal>` 사용자 goal 의 원문. 두 케이스를 재는 **유일한 기준**이다.
- `<premises>` 확정 방향의 핵심 전제 P1..Pn. 근거가 이 문장들과 직접 충돌할 때만 재검토 사유다.
  목록 자체가 틀렸다고 판단하면 그렇게 말한다.
- `<constraints>` 사용자가 지금까지 말한 제약의 원문 전량. 이미 닫힌 경로를 대안으로 내지 않기
  위해 읽는다.

## Required research (출력 전)

1. 대안과 원안 **양쪽**의 근거를 web 검색(WebSearch/WebFetch)으로 수집 — prior-art, 벤치마크,
   실패 사례. 필요한 만큼 찾는다.
2. 리포 주장을 하려면 Read/Grep 으로 그 자리를 확인하고 경로와 앵커를 적는다.

## Output 형식 (이 형식을 정확히 준수 — conducting-interview 가 verbatim 사용)

순서가 계약이다: 대안 → 원안 → 전제 반증 판정 → 추천 → 근거.

```yaml
case_for_alternative:
  statement: "<대안 한 문장>"
  strongest: "<goal 기준으로 대안이 이기는 케이스, 2-4줄>"
case_for_current:
  strongest: "<같은 기준으로 원안이 이기는 케이스, 2-4줄>"
premise_refutation:
  hits: [P2]                 # 빈 배열 허용 = 반증 없음
  why: "<hit 마다: 어느 근거(url 또는 path+anchor)가 어느 전제 문장과 어떻게 충돌하는가>"
premise_list_challenge: "<전제 목록의 결함·빠진 전제 — 없으면 「없음」과 그 이유>"
recommendation: kept | refined | switched
refined_takes: "<refined 일 때 원안에서 취하는 것>"     # refined 가 아니면 생략
refined_drops: "<refined 일 때 버리는 것>"               # refined 가 아니면 생략
evidence:
  - url: "https://..."
    supports: current | alternative | both
    claim: "<이 출처가 뒷받침하는 것>"
    touches: [P1]            # 빈 배열 = 어느 전제에도 닿지 않음
repo_claims:
  - path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 123                # 선택 — 보조 정보
    claim: "<주장>"
    touches: []
```

## 동작 규칙

1. **read-only**: 어떤 파일도 Write/Edit/MultiEdit/NotebookEdit 하지 않습니다(frontmatter 강제).
2. **인용 필수**: 모든 외부 주장은 `evidence[].url` 을 가져야 합니다. URL 없는 주장은 출력하지
   마십시오.
3. **verbatim 계약**: 출력 전체를 conducting-interview 가 **그대로**(약화·편집 없이) audit 에
   기록합니다. 스스로 hedge 하지 말고 두 케이스 모두 가장 강한 형태로 쓰십시오.
4. `premise_refutation.hits` 가 비어 있지 않으면 `why` 는 hit 마다 근거 → 전제 문장 지목을 갖습니다.
   지목할 수 없는 hit 은 내지 않습니다.
5. 모든 `evidence[]` 와 `repo_claims[]` 는 `touches` 를 갖습니다. 빈 배열은 허용이고 거짓 부착보다
   낫습니다 — 부착은 orchestrator 가 게이트 전에 확인합니다.
6. `repo_claims[]` 는 `path` 와 `anchor` 없이 내지 않습니다. 줄번호는 보조입니다.
7. **한 방향당 1회**: 같은 방향에 대한 재호출은 새 근거가 있을 때만.
8. `recommendation: refined` 면 `refined_takes` 와 `refined_drops` 를 둘 다 채웁니다.
9. `<constraints>` 가 이미 닫은 경로는 대안으로 내지 않습니다. 그 경로가 최선이라 판단하면
   `premise_list_challenge` 에 그 이유를 적습니다.

## 사용하지 않는 경우

- 의심 trigger 가 없는 방향(R3 대상 아님).
- trivia 요청(P12).
````

- [ ] **Step 3: 락 GREEN 확인**

Run: `bash plugins/spec-distill/tests/test_steelman_builder_scope.sh | tail -1`
Expected: `Fail: 0`.

Run: `bash shared/tests/test_agent_input_slots.sh 2>/dev/null | grep -E '✗|forbidden|undelivered' | head`
Expected: `forbidden_kind` 1건(premises — T5 가 면제한다)과 `undelivered` 3건(goal·premises·constraints — T4 가 전달한다). 다른 ✗ 가 있으면 여기서 고친다.

- [ ] **Step 4: 커밋**

```bash
git add plugins/spec-distill/agents/steelman-builder.md plugins/spec-distill/tests/test_steelman_builder_scope.sh
git commit -q -F - <<'MSG'
feat(spec-distill): steelman-builder 를 양쪽 케이스·전제 반증·추천 분석자로

역할 「대안의 옹호자 · 원안의 옹호자 아님」→「어느 한 편의 옹호자 아님」. 슬롯 5개
(goal·constraints 는 사용자 원문 artifact, premises 는 orchestrator_framing). 출력 순서
대안 → 원안 → 전제 반증 판정 → 추천(kept/refined/switched) → evidence(touches) →
repo_claims(path+anchor+touches). confidence 폐지. neglect trigger 제거.
shared/tests/test_agent_input_slots.sh 는 다음 두 커밋(dispatch 전달 · 면제 등재)까지
의도된 RED.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
MSG
```

---

### Task 4: R3 절차 `references/steelman.md` + SKILL.md 포인터 + 락 이동

**Files:**
- Create: `plugins/spec-distill/skills/conducting-interview/references/steelman.md`
- Modify: `plugins/spec-distill/skills/conducting-interview/SKILL.md` (`### R3 — Steelman 의심 게이트 (P17)` 절 본문 교체; 그 다음 `## seed 를 입력으로 받았을 때` 전까지)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (r3_block 추출 대상·neglect 반전·양성 짝)

**Interfaces:**
- Consumes: T3 의 슬롯 5개 태그/변수명, T2 의 §5 항목 형식(검토·보류·기각 verdict 줄).
- Produces: `r3_block`(락이 읽는 텍스트) = `references/steelman.md` 전체.

- [ ] **Step 1: 락 갱신(RED)**

`plugins/spec-distill/tests/test_conducting_interview_stage.sh` 에서 `r3_block="$(awk '/^### R3 — Steelman/{f=1;print;next} /^### /{f=0} /^## /{f=0} f' "$SKILL")"` 줄과 그 아래 neglect 단언 세 줄을 아래로 **교체**한다:

```bash
# v0.54.0: R3 절차 전문이 references/steelman.md 로 분리됐다(설계 §6.2). r3_block 은 그 파일에서
# 뜬다. 파일 첫 헤딩이 `### R3 — Steelman` 이고 그 뒤로 `##`/`###` 헤딩이 없어야 블록이 파일
# 끝까지 간다(AC23) — 중간 헤딩 하나가 아래 부재 락 셋을 공허하게 만든다.
STEELMAN="$FIN_DIR/steelman.md"
[[ -f "$STEELMAN" ]] && ok "코퍼스: references/steelman.md 실재 (AC4)" || no "코퍼스: references/steelman.md 부재 (AC4)"
r3_block="$(awk '/^### R3 — Steelman/{f=1;print;next} /^### /{f=0} /^## /{f=0} f' "$STEELMAN")"
[[ "$(printf '%s\n' "$r3_block" | grep -c .)" -ge 40 ]] \
  && ok "R3: r3_block 이 40줄 이상 (공허 아님)" || no "R3: r3_block 이 비었거나 잘렸다 — 첫 헤딩 또는 중간 ##/### 헤딩을 보라 (AC23)"
[[ "$(awk 'NR>1 && /^##(#)? /' "$STEELMAN" | grep -c .)" -eq 0 ]] \
  && ok "AC23: steelman.md 에 첫 줄 뒤 ##/### 헤딩 없음" || no "AC23: steelman.md 중간에 ##/### 헤딩 — r3_block 이 거기서 끊긴다"
grep -q '^### R3 — Steelman' "$SKILL" && ok "R3: SKILL.md 에 R3 헤딩 유지" || no "R3: SKILL.md 의 R3 헤딩 소실"
grep -q 'references/steelman.md' "$SKILL" && ok "AC4: SKILL.md 가 steelman.md 를 가리킨다" || no "AC4: SKILL.md 포인터 부재"
# C18 — neglect trigger 부재(반전) + 양성 짝(trigger 3값 · 검토 · 보류 · 새 어휘)
grep -q 'coverage-mapper neglect' <<<"$r3_block" \
  && no "C18: R3 trigger 에 coverage-mapper neglect 잔존" || ok "C18: R3 trigger 에 neglect 없음 (AC5)"
for t in 'landscape 모순' 'anti-pattern' '제약'; do
  grep -q "$t" <<<"$r3_block" && ok "R3 trigger 문구 존재: $t" || no "R3 trigger 문구 부재: $t (AC5)"
done
grep -q '검토 — steelman 0건' <<<"$r3_block" && ok "R3: 0건 검토 항목 형식 존재 (C8)" || no "R3: 검토 항목 형식 부재"
grep -q '보류 —' <<<"$r3_block" && ok "R3: 보류 항목 형식 존재 (AC19)" || no "R3: 보류 항목 형식 부재"
for w in 유지 보완 전환 보류 kept refined switched deferred; do
  grep -q "$w" <<<"$r3_block" && ok "R3 어휘: $w" || no "R3 어휘 부재: $w (AC6)"
done
grep -qE 'defended|방어' <<<"$r3_block" && no "AC6: 옛 어휘 defended/방어 잔존" || ok "AC6: 옛 어휘 부재"
for w in '재검토 열림' '재검토 사유 없음' '사용자 override'; do
  grep -q "$w" <<<"$r3_block" && ok "AC22: $w" || no "AC22: $w 부재"
done
grep -q 'touches' <<<"$r3_block" && ok "AC20: touches 확인 문구" || no "AC20: touches 부재"
grep -q '부착 M/N\|부착 M' <<<"$r3_block" && ok "AC20: 부착 M/N 정의" || no "AC20: 부착 계수 정의 부재"
```

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh | tail -1`
Expected: Fail ≥ 20 (steelman.md 부재).

- [ ] **Step 2: `references/steelman.md` 작성**

파일 전문(첫 줄이 헤딩, 이후 `####` 만):

````markdown
### R3 — Steelman 의심 게이트 (P17)

의심된 방향에 대해 steelman-builder 가 **원안과 대안 양쪽**의 최강 케이스를 사용자 goal 기준으로 쓰고,
근거가 핵심 전제에 닿는지 판정한 뒤 추천을 낸다. 재검토를 여는 열쇠는 하나 — 새 근거가 핵심 전제와
직접 충돌할 때. 그 외의 근거는 원안을 강화하거나 경계를 다듬는 데 쓴다. 판정은 유지 / 보완 / 전환 /
보류 넷이고 선택은 사용자가 한다.

**trigger** = landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 커버리지 공백은 R3
대상이 아니다 — probe 질문으로 간다(coverage-mapper 블록).

#### Step 1 — dispatch 재료 도출 (orchestrator)

- **핵심 전제 P1..Pn** — R1 문제정의·goal 과 그때까지의 `user_statements` 에서 도출한다. 각 전제 뒤에
  근거 S<N> 을 적고, 적을 수 없으면 「orchestrator 도출」로 표기한다. 개수 상한은 없다.
- **goal** — goal 내용을 담은 사용자 발화 중 **가장 최근 것**의 원문(S<N> 인용). seed S1 의 goal 문장은
  후보 중 하나이고 더 늦은 발화가 goal 을 고쳤으면 그쪽이 이긴다. 후보가 없거나(확인 발화가 「맞아」류
  동의문뿐) 후보 둘이 충돌하면 dispatch **전에** 한 probe 로 goal 한 문장을 사용자에게 받아 그 답 원문을
  쓴다. orchestrator 가 쓴 재구성 문장은 어떤 경우에도 goal 에 넣지 않는다.
- **constraints** — state `user_statements` 전량 원문.
- 어느 S<N> 을 goal 로 골랐는지, 전제 목록, 제약 S-id 범위를 audit §3 `#### ST<N>` 블록의 「dispatch 입력」
  소절에 적는다.

Web kill switch 는 dispatch 직전에 확인한다:

```bash
if [[ "${DEVBREW_SPEC_DISTILL_DISABLE_WEB:-0}" == "1" ]]; then
  echo "[spec-distill] web 비활성 — steelman 자동 생략, 사용자에게 의심 방향 수동 확인 요청" >&2
fi
```

```
Agent({ description: "Steelman both cases", subagent_type: "spec-distill:steelman-builder",
        prompt: "의심 방향: <direction>${SUSPECT_DIRECTION}</direction>. trigger: <trigger>${TRIGGER}</trigger>. 사용자 goal(원문): <goal>${GOAL}</goal>. 핵심 전제: <premises>${PREMISES}</premises>. 사용자가 지금까지 말한 제약(원문 전량): <constraints>${CONSTRAINTS}</constraints>. 양쪽 최강 케이스를 같은 기준으로, 전제 반증 판정과 추천을." })
// **처분** — consumer=orchestrator · fail-open · disclosure=loud advisory
```

한 방향당 steelman 1회 — 새 근거 없으면 재steelman 금지(AP16).

#### Step 2 — 게이트-전 확인 (orchestrator, Read/Grep)

- `repo_claims` 전 항목: 경로 실재 → 앵커 실재 → 주장이 그 자리와 맞는가. 결과 ∈ {확인, 반증, 미확인}.
- **양성 부착 주장 전부**(C4): `evidence[]`·`repo_claims[]` 중 `touches` 가 비어 있지 않은 항목마다 `claim` 을
  지목된 전제 문장과 대조한다(repo_claims 는 경로·앵커 확인을 먼저 통과한 것만). 결과 ∈ {확인, 반증}.
  `premise_refutation.hits` 는 그 부분집합(부착 중 「충돌」을 주장하는 것)이라 같은 대조 안에서 「충돌인가」까지
  본다. 음성(`touches` 빈 배열)은 확인하지 않는다.
- 「근거 N 중 부착 M」의 M 은 **확인을 통과한 부착**만 센다. 반증된 부착은 `[부착 주장 반증]` 라벨로 노출되고
  M 에 들지 않는다(N 에는 든다). 리포 주장은 「리포 주장 K 중 확인 J」로 따로 센다.
- 결과는 audit §3 `#### ST<N>` 블록의 「게이트-전 확인」 소절에 주장별 한 줄로 남는다.
- 반증된 항목은 4-block 에서 빼지 않고 「반증됨」 라벨을 단다. orchestrator 는 verdict 를 대신 내지 않는다.

#### Step 2.5 — 재검토 자격 판정

확인을 통과한 `hits`(전제 충돌) 개수로 둘 중 하나를 4-block 「막힌 결정」 첫 줄에 적는다:

- 충돌 ≥1 → `재검토 열림 — 전제 P<n> 충돌 확인 <k>건`. 4-block 은 Step 3 그대로.
- 충돌 0(hits 가 비었거나 전부 반증) → `재검토 사유 없음 — 확인된 전제 충돌 0건`. 게이트는 그대로 띄운다 —
  선택은 언제나 사용자다. 단 「추천 답안」의 orchestrator 줄은 유지 또는 보완 중 하나이고, builder 추천이
  switched 면 그 옆에 `[전제 충돌 없음]` 라벨을 붙인다. 이 상태에서 사용자가 전환을 고르면 그것은 근거-발동
  재검토가 아니라 **사용자 override** 다 — §5 항목 끝에 `— 사용자 override(전제 충돌 0)` 를 붙이고 audit §3 에도
  같은 문구를 남긴다. 봉쇄는 추천·라벨 층에 있고 선택지를 제한하지 않는다.
- `premise_list_challenge` 가 빠진 전제나 틀린 전제를 지목하면 「막힌 결정」에 그대로 보이고, 사용자가 받아들이면
  전제 목록을 고쳐 audit §3 에 적는다. 목록 수정 자체는 재검토를 열지 않는다 — 고친 전제에 닿는 확인된 충돌이
  있어야 연다. 같은 ST 안에서 재dispatch 는 하지 않는다.

#### Step 3 — 4-block 제시

- **현재 이해**: 의심 방향 + trigger.
- **막힌 결정**: Step 2.5 의 자격 판정 한 줄 → 전제 목록 P1..Pn **그대로**(C2) → builder 의 `premise_list_challenge`
  원문.
- **추천 답안**: 두 줄 나란히 — 「builder: <recommendation>」 / 「orchestrator: <의견>」. 아래에 `case_for_alternative`
  와 `case_for_current` 를 verbatim 으로. evidence 는 항목마다 `[부착 P<n>]` 또는 `[비부착]` 라벨, 반증된 것은
  `[반증됨]` 추가. 마지막 줄 「근거 N 중 부착 M · 리포 주장 K 중 확인 J」.
- **질문**: `AskUserQuestion` 선택지 **고정 순서** 유지 / 보완 / 전환 / 보류. `(Recommended)` 라벨은 붙이지 않는다.

conducting-interview 는 builder 출력을 **약화·편집하지 않는다** — verbatim 계약이다.

#### Step 4 — 기록

payload §5 항목은 **사용자가 고른 verdict 별로** 형식이 정해지고 builder 추천과 무관하다:

- 유지(kept): `- 기각 — <대안 statement> → <이유> — verdict: kept — ST<N> — 부착 M/N`
- 전환(switched): `- 기각 — <원안> → <이유> — verdict: switched — ST<N> — 부착 M/N`
- 보완(refined): `- 기각 — <버림> → <이유> — verdict: refined — ST<N> — 부착 M/N`. 「버림」은 builder 추천이 refined
  였으면 `refined_drops` 에서 오고, 아니면(builder 는 kept/switched 를 냈는데 사용자가 보완을 고름) 게이트 **직후**
  `AskUserQuestion` 1회(자유 텍스트)로 취함/버림을 받아 그 원문을 S<N> 으로 기록하고 그 「버림」을 쓴다.
- 보류(deferred): `- 보류 — <대안 statement> → §3 OQ<k> — verdict: deferred — ST<N> — 부착 M/N`. 접두가 `보류` 인 이유:
  아무것도 버리지 않았으므로 R4 기각 계수에 들면 안 된다. `verdict:` 를 가지므로 skepticism verdict 항목으로 계수되고
  bijection A 에 든다. 같은 내용을 §3 OQ 에도 박제한다.

audit §3 `#### ST<N> — <요지>` 블록 순서: dispatch 입력(goal S-id · 전제 목록 · 제약 S-id 범위) → builder 출력 verbatim
→ 게이트-전 확인 → 사용자 선택 S<N>. payload §5 와 audit §3 은 `ST<N>` id 로 맞물린다(bijection A). frontmatter 에는
별도 필드를 두지 않는다.

#### Step 5 — steelman 0건으로 skepticism 을 닫을 때

의심 trigger 가 한 번도 발화하지 않은 인터뷰는 payload §5 에 `검토 —` 접두 항목 하나로 skepticism 을 닫는다:

`- 검토 — steelman 0건: 검토한 방향 <N>개 · 전제 <P1..Pn> · trigger 후보 <무엇을 봤는가> → 기각 이유 <왜 trigger 가 아닌가>`

접두가 `기각` 이 아닌 이유: R4 기각 계수에 섞이면 안 된다. coverage 원장 `floor:skepticism` evidence 는 이 항목을
가리킨다. `check_brief.py` 는 verdict 항목이 0건이면 이 항목을 **요구**하고, 네 토큰(검토한 방향 · 전제 · trigger 후보 ·
기각 이유)이 다 있어야 통과시킨다.

#### Web 부재 시 graceful degradation (R2 대칭)

`steelman-builder` 는 WebSearch/WebFetch 를 요구한다. kill switch `DEVBREW_SPEC_DISTILL_DISABLE_WEB=1` 또는 web 도구
부재로 steelman 을 돌릴 수 없으면 — R2 landscape 와 대칭으로 — opaque 한 게이트 실패로 떨어뜨리지 말고 **loud
advisory**(`[spec-distill] web 비활성 — steelman 자동 생략, 사용자에게 의심 방향 수동 확인 요청`)를 내고 **수동
의심 게이트**로 전환한다. 이 경우 §5 항목은 사용자 판단(유지/보완/전환/보류)을 근거로 기록하되 URL 부재 사유를
명시한다. 보류는 §3 OQ 에도 박제한다.

#### Law 2 경계

steelman 게이트는 Law 2 분리 메커니즘이 *아니다* — Law 2 분리 reviewer 는 오직 design doc(brainstorming `-design.md`)에만
적용된다. steelman 은 문제공간 품질을 끌어올리는 Law 1급 skepticism 의례다(verbatim pass-through 로 무력화 방지).
````

- [ ] **Step 3: SKILL.md R3 절을 포인터로**

`plugins/spec-distill/skills/conducting-interview/SKILL.md` 의 `### R3 — Steelman 의심 게이트 (P17)` 헤딩부터 `## seed 를 입력으로 받았을 때` 직전까지를 아래로 **교체**한다:

```markdown
### R3 — Steelman 의심 게이트 (P17)

의심 trigger = landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 절차 전문(전제 도출 ·
`steelman-builder` dispatch · 게이트-전 확인 · 4-block · 유지/보완/전환/보류 게이트 · 기록 · steelman 0건의
`검토 —` 항목 · web 비활성 시 steelman 자동 생략)은 `references/steelman.md` 다 — R3 에 들어갈 때 그 파일을 Read 한다.
builder 출력은 verbatim 으로 다룬다(약화·편집 금지). 보류는 §3 OQ 에도 박제한다.

```

(마지막 빈 줄 유지. `## seed 를 입력으로 받았을 때` 는 그대로.)

- [ ] **Step 4: 락 GREEN + 슬롯 전달 확인**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh | tail -1`
Expected: baseline 의 Fail 수(새 RED 0). 실패가 남으면 그 줄의 문구를 steelman.md 나 SKILL.md 에서 찾는다 — 특히 `has 'steelman.*생략|web 비활성.*steelman'`(F8)·`§3 OQ` ×2·E10 병렬금지 부재는 새 파일에서 만족되어야 한다.

Run: `bash shared/tests/test_agent_input_slots.sh 2>/dev/null | grep -E '✗' | head`
Expected: `forbidden_kind` 관련 1건만(premises). `undelivered` 는 사라졌다. `bash shared/tests/test_dispatch_disposition.sh | tail -1` 은 baseline 과 같다.

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/skills/conducting-interview/references/steelman.md plugins/spec-distill/skills/conducting-interview/SKILL.md plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -q -F - <<'MSG'
feat(spec-distill): R3 절차를 references/steelman.md 로 — 전제 도출·게이트-전 확인·4값 게이트

SKILL.md R3 절은 trigger 3값(neglect 제거, C18)과 포인터만. 새 파일: goal/전제/제약 원문
dispatch, repo_claims·양성 touches 게이트-전 확인, 재검토 자격 판정(충돌 0 이면 사용자
override 로 기록), 4-block 나란히 추천·고정 순서 선택지, verdict 별 기록 형식(보류 접두),
steelman 0건의 검토 항목. 락은 r3_block 을 새 파일에서 뜨고 neglect 존재→부재로 반전.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
MSG
```

- [ ] **Step 6: 변이 검사(커밋 뒤)**

| 변이 | 명령 | 기대 ✗ |
|---|---|---|
| neglect 재삽입 | `sed -i.bak 's|기존 사용자 제약과의 충돌\. 커버리지|기존 사용자 제약과의 충돌 / coverage-mapper neglect. 커버리지|' plugins/spec-distill/skills/conducting-interview/references/steelman.md` | ≥1 (C18) |
| 중간 헤딩 삽입 | `sed -i.bak 's|^#### Step 3 — 4-block 제시|### Step 3 — 4-block 제시|' …/steelman.md` | ≥3 (AC23 + r3_block 잘림으로 Step 4·5 문구 부재) |

각 변이 뒤 `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh | grep -c '✗'`, 그리고 `git checkout -- plugins/spec-distill/skills/conducting-interview/references/steelman.md && rm -f plugins/spec-distill/skills/conducting-interview/references/*.bak`.

---

### Task 5: `check_slots.py` 면제 등재 + baseline 5

**Files:**
- Modify: `tools/adjudication/check_slots.py` (`EXEMPT_SLOTS` 항목 1 · `EXEMPT_SLOTS_BASELINE` · 축 스윕 주석)

**Interfaces:**
- Consumes: T3 의 `("spec-distill:steelman-builder", "premises")`.
- Produces: `shared/tests/test_agent_input_slots.sh` GREEN(`exempt_total=5` · `exempt_baseline=5` · `exempt_uncited=0`).

- [ ] **Step 1: RED 확인**

Run: `bash shared/tests/test_agent_input_slots.sh | grep '✗'`
Expected: `forbidden_kind` 1건(steelman-builder premises).

- [ ] **Step 2: 면제 등재**

`tools/adjudication/check_slots.py` 의 `EXEMPT_SLOTS` 딕셔너리, `("spec-distill:blind-spot-prober", "framing")` 항목 **뒤**에 추가:

```python
    ("spec-distill:steelman-builder", "premises"):
        "C6(1) 이 agent 의 과업은 «그 전제 목록에 대한» 반증 판정과 목록 자체의 반박이다 — "
        "대상이 정의상 orchestrator 가 R1 에서 도출한 그 목록이라 대응물이 없다. 다른 값(사용자 "
        "원문)을 넣으면 builder 가 자기 전제를 세우고 그것을 치게 되어 C16 의 목적(전제 목록이 "
        "원안 저자의 상상력 경계를 물려받지 않게 한다)을 잃는다. 잔여 위험은 남는다 — 도출이 이미 "
        "잃은 전제는 builder 도 못 본다(brief OQ2). 면제 범위는 이 슬롯 하나로 좁혔다: goal 과 "
        "constraints 는 사용자 원문(artifact)으로 넘긴다. 설계 "
        "docs/superpowers/specs/2026-09-06-steelman-goal-fit-design.md §6.7.",
```

`EXEMPT_SLOTS_BASELINE = 4` 를 `EXEMPT_SLOTS_BASELINE = 5` 로 바꾸고 그 위 주석 끝에 한 줄:
```python
# 2026-09-06 4→5: steelman-builder.premises (위 항목의 사유). 전제 목록은 정의상 orchestrator 종합이다.
```

축 전수 스윕 주석의 `#   · \`steelman-builder.direction\`/\`trigger\` — 지목됐으나 ⓔ 가 아니다.` 블록에서 「네 값 중 하나를 대는 enum 이다 (landscape 모순 / anti-pattern / 제약 충돌 / neglect)」를 「세 값 중 하나를 대는 enum 이다 (landscape 모순 / anti-pattern / 제약 충돌)」로 고치고, 그 항목 뒤에:
```python
#     2026-09-06 재설계로 슬롯 셋이 늘었다: `goal`·`constraints` 는 사용자 발화 원문 → ⓑ.
#     `premises` 는 orchestrator 가 도출한 전제 목록 → ⓔ, 면제 등재(위 EXEMPT_SLOTS).
```

- [ ] **Step 3: GREEN 확인 + 커밋**

Run: `bash shared/tests/test_agent_input_slots.sh | tail -1 && bash shared/tests/test_dispatch_disposition.sh | tail -1`
Expected: 둘 다 baseline 의 Fail 수.

```bash
git add tools/adjudication/check_slots.py
git commit -q -F - <<'MSG'
chore(adjudication): steelman-builder.premises 를 orchestrator_framing 면제로 (baseline 4→5)

전제 목록은 정의상 orchestrator 종합이고 builder 의 과업(반증 판정·목록 반박)이 그 목록을
대상으로 한다 — C6(1) 대응물 없음. goal·constraints 는 사용자 원문 artifact 로 넘겨 면제
범위를 이 슬롯 하나로 좁혔다. 스윕 주석의 trigger enum 을 3값으로 정정.

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
MSG
```

---

### Task 6: 템플릿 · README · CHANGELOG · 버전

**Files:**
- Modify: `plugins/spec-distill/templates/interview-brief-template.md` (§5 주석·예시)
- Modify: `plugins/spec-distill/templates/interview-audit-template.md` (§3 골격)
- Modify: `plugins/spec-distill/README.md` (P11 줄)
- Modify: `plugins/spec-distill/CHANGELOG.md` (0.54.0 항목)
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json` (`0.53.1` → `0.54.0`)

- [ ] **Step 1: 브리프 템플릿 §5**

`plugins/spec-distill/templates/interview-brief-template.md` 의 `## 5. 기각 · Blind Spots` 블록을 아래로 교체:

```markdown
## 5. 기각 · Blind Spots

(`기각` 항목이 0건이면 `- 기각 — N/A — 전부 first-time defend+lock` 한 줄 명시(빈 섹션 금지).
 `verdict:`를 가진 항목은 audit §3의 `ST<N>` 참조가 필수다. verdict 항목이 0건이면 `검토 —` 항목이
 필수다 — 검토한 방향 · 전제 · trigger 후보 · 기각 이유 네 토큰을 담는다.)

- 기각 — <시도한 방향> → <버린 이유>
- 기각 — <버린 것> → <버린 이유> — verdict: kept — ST1 — 부착 M/N
- 보류 — <대안 statement> → §3 OQ1 — verdict: deferred — ST2 — 부착 M/N
- 검토 — steelman 0건: 검토한 방향 <N>개 · 전제 <P1..Pn> · trigger 후보 <무엇을 봤는가> → 기각 이유 <왜 trigger 가 아닌가>
- 위험 — <숨은 가정 | 실패 양식>: <내용> — <근거>
```

(템플릿에 `검토 —` 와 `verdict:` 예시가 함께 있어도 게이트 대상은 실제 brief 이므로 무관하다. `first-time defend+lock` 은 R4 sentinel 어휘라 그대로 둔다.)

- [ ] **Step 2: audit 템플릿 §3**

`plugins/spec-distill/templates/interview-audit-template.md` 의 `## 3. Steelman 원문` 블록을 아래로 교체:

```markdown
## 3. Steelman 원문

(steelman-builder 출력 verbatim. payload §5의 `verdict:` 항목이 여기의 `ST<N>`을 참조한다 —
 양방향 일치가 게이트 대상이다. steelman 0건이면 이 절은 비어 있어도 되고 sentinel도 필요 없다 —
 그때 skepticism 폐쇄 기록은 payload §5 의 `검토 —` 항목이다.)

#### ST1 — <한 줄 요지>

**dispatch 입력** — goal: S<N> · 전제: P1 <…>(S<N>) · P2 <…> · 제약: S1–S<N> 원문 전량 · trigger: <…>

> <builder 출력 verbatim — 다단락 가능>

**게이트-전 확인** — repo_claims: <path+anchor> 확인|반증|미확인 … · 부착 주장: <evidence #> → P<n> 확인|반증 … · 재검토 자격: 열림 <k>건 | 사유 없음

**사용자 선택** — <유지|보완|전환|보류> (S<N>) <— 사용자 override(전제 충돌 0), 해당 시>
```

- [ ] **Step 3: README P11 줄**

`plugins/spec-distill/README.md` 의 `- **P11 (Cross-Model Adversarial)** — …` 줄을 아래로 교체:

```markdown
- **P11 (Cross-Model Adversarial)** — sub-agent reviewer adversarial review + **`steelman-builder` 의심 게이트(v0.12.0, v0.54.0 재설계)**: 의심 방향에 대해 builder 가 원안·대안 **양쪽**의 최강 케이스를 사용자 goal 기준으로 쓰고 근거가 핵심 전제에 닿는지 판정한다. 재검토를 여는 열쇠는 전제 충돌 하나 — 그 외 근거는 원안 강화·경계 다듬기에 쓴다. 판정 어휘 유지/보완/전환/보류(kept/refined/switched/deferred), 선택은 사용자.
```

Run: `bash plugins/spec-distill/tests/test_readme_sync.sh | tail -1`
Expected: baseline 과 같다(`steelman-builder` 키워드 유지).

- [ ] **Step 4: CHANGELOG + 버전**

`plugins/spec-distill/CHANGELOG.md` 의 `# Changelog` 바로 아래에 삽입:

```markdown
## [0.54.0] — 2026-09-06

### Added

- `skills/conducting-interview/references/steelman.md` — R3 절차 전문. 전제 P1..Pn·goal 원문·제약 원문 전량을
  dispatch 에 싣고, 게이트 전에 repo_claims(경로+앵커)와 양성 `touches` 부착 주장을 orchestrator 가 확인하며,
  확인된 전제 충돌 0 이면 「재검토 사유 없음」 라벨(사용자가 그래도 전환하면 `사용자 override` 로 기록).
  4-block 은 builder 추천과 orchestrator 의견을 나란히, 선택지는 유지/보완/전환/보류 고정 순서.
- `scripts/skepticism.py` — payload §5 skepticism 검사(`VALID_VERDICTS` · verdict 형식 · `검토 —` 항목 · 폐쇄 판정 ·
  bijection A). `check_brief.py` 는 절을 잘라 넘기기만 한다. 의존 방향은 check_brief → skepticism 하나.
- 폐쇄 요구: verdict 항목 0건이면 `- 검토 — steelman 0건: 검토한 방향 N개 · 전제 … · trigger 후보 … → 기각 이유 …`
  항목이 없으면 gate RED(브리프 C26). `보류 —` 접두의 deferred 항목은 verdict 로 세되 R4 기각으로 세지 않는다.
- steelman-builder 슬롯 셋: `goal`(artifact) · `premises`(orchestrator_framing, `tools/adjudication/check_slots.py`
  면제 5번째) · `constraints`(artifact). 출력 스키마: `case_for_alternative` → `case_for_current` →
  `premise_refutation` → `premise_list_challenge` → `recommendation` → `refined_takes/drops` → `evidence[].touches` →
  `repo_claims[].path/anchor/touches`.
- 픽스처 6쌍(`steelman-empty-norecord` · `verdict-refined` · `verdict-defended` · `review-record-malformed` ·
  `verdict-deferred-hold` · `review-only-no-reject`) + `tests/test_skepticism_module.sh`.

### Changed

- steelman 의 목적이 「원안 뒤집기」에서 「사용자 goal 에 가장 적합한 방향 찾기」로. 페르소나 역할은 「대안의 옹호자 ·
  원안의 옹호자 아님」에서 「양쪽 케이스를 같은 기준으로 쓰는 분석자 · 어느 한 편의 옹호자 아님」으로.
- verdict 토큰 `defended` → `kept`, `refined` 신설(`switched` · `deferred` 그대로). 픽스처 141 과 템플릿을 기계 치환,
  과거 brief 의 기계 토큰 2줄(08-16 → refined · 08-22 → kept)과 이 브랜치 brief ST1(→ refined, 사용자 판정이
  「보완」이었다)은 산문을 읽고 값을 골라 `(이관 2026-09-06)` 표기. 산문·verbatim 원문은 시점 기록이라 건드리지 않았다.
  **별칭 없음** — spec-distill 은 v0.x 라 one-minor deprecation window 면제.
- `tests/test_conducting_interview_stage.sh` 의 R3 블록은 `references/steelman.md` 에서 뜬다. `coverage-mapper neglect`
  존재 락을 부재 락으로 반전(양성 짝: trigger 3값·검토·보류·새 어휘).

### Removed

- R3 trigger 「coverage-mapper neglect」 — 커버리지 공백은 probe 질문으로 간다(브리프 C18).
- steelman-builder 의 `confidence` 필드와 「confidence < 0.4 면 원안 defend 합리적」 규칙 — `recommendation: kept` 와
  `case_for_alternative.strongest` 가 같은 정보를 이산값으로 준다.
```

`plugins/spec-distill/.claude-plugin/plugin.json` 의 `"version": "0.53.1"` → `"version": "0.54.0"`.

- [ ] **Step 5: 전 스위트 + 커밋**

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/compare.sh`
Expected: `compare done` 만.

```bash
git add plugins/spec-distill/templates plugins/spec-distill/README.md plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json
git commit -q -F - <<'MSG'
docs(spec-distill): 템플릿 §5/§3 · README P11 · CHANGELOG 0.54.0 · 버전 bump

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_012ryFYHs4CUc7MtZYTd8hjy
MSG
```

---

### Task 7: 최종 검증 (AC 전수)

**Files:** 없음(읽기만). 결과는 `/Users/jeonghokim/.claude/jobs/b499da5f/tmp/final_ac.txt` 에.

- [ ] **Step 1: AC 검증 스크립트**

```bash
#!/bin/bash
# /Users/jeonghokim/.claude/jobs/b499da5f/tmp/final_ac.sh
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/feature+steelman-goal-fit || exit 9
P=plugins/spec-distill
chk() { if eval "$2" >/dev/null 2>&1; then echo "PASS $1"; else echo "FAIL $1"; fi; }
chk AC1  "! grep -q confidence $P/agents/steelman-builder.md && grep -q recommendation $P/agents/steelman-builder.md"
chk AC2  "[ \$(grep -c '^  - tag: ' $P/agents/steelman-builder.md) -eq 5 ] && [ \$(grep -c 'kind: orchestrator_framing' $P/agents/steelman-builder.md) -eq 1 ]"
chk AC3  "! grep -q '원안의 옹호자' $P/agents/steelman-builder.md && grep -q '어느 한 편의 옹호자' $P/agents/steelman-builder.md && grep -qiE 'verbatim|약화.*금지|편집.*금지' $P/agents/steelman-builder.md"
chk AC4  "test -f $P/skills/conducting-interview/references/steelman.md && grep -q 'references/steelman.md' $P/skills/conducting-interview/SKILL.md"
chk AC5  "! grep -q 'coverage-mapper neglect' $P/skills/conducting-interview/references/steelman.md && grep -q 'landscape 모순' $P/skills/conducting-interview/references/steelman.md"
chk AC6  "grep -q kept $P/skills/conducting-interview/references/steelman.md && grep -q refined $P/skills/conducting-interview/references/steelman.md && ! grep -qE 'defended|방어' $P/skills/conducting-interview/references/steelman.md"
chk AC7  "grep -q '<goal>\${GOAL}</goal>' $P/skills/conducting-interview/references/steelman.md && grep -q '<premises>\${PREMISES}</premises>' $P/skills/conducting-interview/references/steelman.md && grep -q '<constraints>\${CONSTRAINTS}</constraints>' $P/skills/conducting-interview/references/steelman.md && grep -q '\*\*처분\*\*' $P/skills/conducting-interview/references/steelman.md"
chk AC8  "grep -q 'VALID_VERDICTS = (\"kept\", \"refined\", \"switched\", \"deferred\")' $P/scripts/skepticism.py && ! grep -q '^VALID_VERDICTS' $P/scripts/check_brief.py"
chk AC9  "python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-steelman-empty-norecord.md 2>/dev/null | grep -q 'skepticism 기록 0건'"
chk AC10 "python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-steelman-empty.md"
chk AC11 "python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-review-record-malformed.md 2>/dev/null | grep -q 'malformed §5 검토'"
chk AC12 "python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-review-only-no-reject.md 2>/dev/null | grep -q '§5 기각 항목 0건'"
chk AC13 "python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-verdict-refined.md && python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-verdict-defended.md 2>/dev/null | grep -q 'malformed §5 verdict'"
chk AC14 "[ \$(grep -rn -- '— verdict: defended —' $P docs/superpowers/interview | grep -v 'verdict-defended' | grep -v CHANGELOG | wc -l) -eq 0 ]"
chk AC15 "grep -q 'spec-distill:steelman-builder\", \"premises\"' tools/adjudication/check_slots.py && grep -q 'EXEMPT_SLOTS_BASELINE = 5' tools/adjudication/check_slots.py"
chk AC16 "grep -q 'verdict: kept — ST1' $P/templates/interview-brief-template.md && grep -q '검토 — steelman 0건' $P/templates/interview-brief-template.md && ! grep -q 'verdict: defended' $P/templates/interview-brief-template.md"
chk AC17 "grep -q '\"version\": \"0.54.0\"' $P/.claude-plugin/plugin.json && grep -q '^## \[0.54.0\]' $P/CHANGELOG.md"
chk AC18 "python3 $P/scripts/check_brief.py gate docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md"
chk AC19 "python3 $P/scripts/check_brief.py gate $P/tests/fixtures/interview-brief-verdict-deferred-hold.md 2>/dev/null | grep -q '§5 기각 항목 0건'"
chk AC20 "grep -q 'touches' $P/skills/conducting-interview/references/steelman.md && grep -q '부착 M' $P/skills/conducting-interview/references/steelman.md"
chk AC21 "! grep -qE '^(import|from) check_brief' $P/scripts/skepticism.py && grep -q '^from skepticism import' $P/scripts/check_brief.py"
chk AC22 "grep -q '재검토 열림' $P/skills/conducting-interview/references/steelman.md && grep -q '재검토 사유 없음' $P/skills/conducting-interview/references/steelman.md && grep -q '사용자 override' $P/skills/conducting-interview/references/steelman.md"
chk AC23 "[ \$(awk 'NR>1 && /^##(#)? /' $P/skills/conducting-interview/references/steelman.md | wc -l) -eq 0 ]"
```

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/final_ac.sh | tee /Users/jeonghokim/.claude/jobs/b499da5f/tmp/final_ac.txt | grep -c PASS`
Expected: `23`. FAIL 이 있으면 그 AC 의 태스크로 돌아간다.

- [ ] **Step 2: 완전성 재실행(이 브랜치 brief)**

Run: `python3 plugins/spec-distill/scripts/check_verbatim_coverage.py docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.md /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/1f5a8290-7b4b-454d-b493-438037a5123f/state.local.md docs/superpowers/interview/2026-09-05-steelman-goal-fit-interview.audit.md; echo rc=$?`
Expected: `missing_ids: []`, `not_contained: []`, `rc=0`.

- [ ] **Step 3: 전 스위트 최종 비교 + 트리 clean**

Run: `bash /Users/jeonghokim/.claude/jobs/b499da5f/tmp/compare.sh && git status --short | wc -l && git log --oneline main..HEAD | wc -l`
Expected: `compare done`, `0`, 커밋 7(문서 1 + 이관 1 + 모듈 1 + 페르소나 1 + R3 1 + 면제 1 + 문서/버전 1).

- [ ] **Step 4: 보고**

사용자에게: 커밋 목록, baseline 대비 스위트 변화(0), 변이 검사 표(T2 네 축 · T4 두 축)의 실제 ✗ 수, AC 23/23, 남은 것(U3 수동 e2e — 다음 인터뷰에서 R3 가 새 절차로 한 번 도는지; PR 생성은 사용자 요청 시).

---

## 설계 커버리지 점검 (plan 자기검토)

| 설계 항목 | 태스크 |
|---|---|
| §6.1 T1 페르소나(슬롯 5·스키마·규칙·confidence 삭제) | Task 3 |
| §6.2 T2 R3 절차(Step 1~5 · 2.5 · web 강등 · Law 2) + SKILL 포인터 | Task 4 |
| §6.3 T3 skepticism.py 경계·시그니처·gate 배선·서브커맨드 | Task 2 |
| §6.4 T4 이관(토큰 한 커밋·과거 2줄·ST1 refined·AC14 기계 형태·과거 0건 brief 범위 밖) | Task 1 (+ Task 7 AC14) |
| §6.5 L1~L8 락·픽스처 6쌍·변이 | Task 2 (L4~L6) · Task 3 (L3) · Task 4 (L1·L2·L8) · Task 5 (L7) |
| §6.6 템플릿·README·CHANGELOG·버전 | Task 6 |
| §6.7 면제 등재·baseline·주석 | Task 5 |
| §7 AC1–AC23 | Task 7 |
| §9 검증(baseline·커밋별 비교·변이·AC18·슬롯 짝) | Task 0 · 각 태스크 · Task 7 |
| §13 U2(픽스처 최소 본문) | Task 2 Step 7 — `valid`/`steelman-empty` 쌍을 복사해 한 줄만 바꾼다 |
| §13 U3(수동 e2e) | 이 PR 밖 — Task 7 Step 4 보고에 남긴다 |
| §13 U4(커밋 분할) | 7커밋 — 문서 1 · 이관 1 · 모듈+픽스처+락 1 · 페르소나+락 1 · R3+락 1 · 면제 1 · 문서/버전 1. 브랜치명은 이미 `feature/steelman-goal-fit` |
