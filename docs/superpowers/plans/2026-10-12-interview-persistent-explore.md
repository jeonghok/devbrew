# R1 인터뷰 탐색 개편 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** spec-interview 가 조사 장치의 자격 · 예산 · 리듬 강제 없이 결정에 닿을 때마다 조사하고, 쓰기 권한 없는 판정자의 「포화」 또는 사용자의 종료로만 끝나게 한다.

**Architecture:** 조사 subagent 넷(coverage-mapper · blind-spot-prober · steelman-builder · 새 repo-researcher)은 하나의 조사 호출 상한(기본 20, 사용자 연장)에만 묶인다. floor 다섯이 닫히면 새 읽기 전용 `saturation-judge` 가 조사 원문에서 직접 새로움을 매겨 포화를 판정하고, 판정 고리에도 상한(기본 5)을 둔다. 상한 · 판정 절차는 조건부 reference `references/saturation.md` 에 두고, `check_brief.py gate` 의 새 검사 `saturation_failures` 가 audit §2 의 마지막 포화 판정 줄로 종료를 거절한다.

**Tech Stack:** Markdown skill/agent 정의, Python 3 (`check_brief.py`), bash 락 테스트(`shared/tests/assert.sh`), python unittest.

**Spec:** `docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md` (리포 상대경로). 실행자는 계획과 설계문서를 함께 읽는다.

## Global Constraints

- 모든 경로는 worktree 절대경로 `/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-persistent-explore` 아래다. main 레포(`/Users/jeonghokim/Downloads/devbrew/plugins/...`)의 같은 이름 파일을 고치지 않는다.
- 구현 커밋 메시지 끝에 트레일러 `Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md` 를 단다(로드맵 지휘 절차 7). 커밋 설명은 한국어, `type(scope)` 는 영어 — 예 `feat(spec-distill): …`. 마지막 줄 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- 커밋은 pathspec 으로 한다(`git commit -- <파일들>` 또는 `git add <파일들>` 뒤 커밋) — `git add -A` · `git add .` 금지.
- 새 agent 둘의 `tools:` 는 정확히 `tools: Read, Grep, Glob` 한 줄(쓰기 · Bash · 웹 없음, Law 2). `model:` 키를 두지 않는다. `cost_class: low`.
- 모든 dispatch 자리는 `// **처분** — consumer=orchestrator · fail-closed · disclosure=<리터럴>` 한 줄을 dispatch 줄 아래 40줄 안에 갖고, 그 `<리터럴>` 이 같은 파일의 처분 줄 밖 본문에 글자 그대로 있어야 한다(`shared/tests/test_dispatch_disposition.sh` 축 C).
- 금지 토큰 — 새로 쓰는 문면(SKILL · references · agents · README · templates · scripts)에 다음을 쓰지 않는다: `최대 <숫자>회` · `<숫자>회까지` · `최대 2회` · `round 1–2` · `판정자 조건` · `판정자 투입` · `다시 묻지 않는다` · `직전 답에서` · `깊이 측정` · `되비추` · `되비춘` · `4-block`·`막힌 결정`(steelman.md 밖) · `general-purpose` · `interview_round` · `probe_count` · `probe_cap` · `effective_cap` · `PROBE_CAP` · `web_budget` · `web_sweep_count` · `web_search_count` · `SWEEP_CAP` · `SESSION_CAP` · `병렬 … 금지` · `fan-out 1` · `인터뷰당 1회` · `once per` · `bounded to two` · `재dispatch 금지` · 뒤에 `.`·숫자가 오지 않는 `§8`/`§9`. 판정자 출력의 `confidence` 같은 칸을 만들지 않는다(steelman-builder 락).
- 새 셸 테스트 파일은 `chmod +x` 하고 커밋 뒤 `git ls-files -s <파일>` 이 `100755` 인지 본다(qg shell 어댑터 규칙).
- 새 파이썬 · 셸 코드에서 파일을 읽을 때 `encoding="utf-8"` 를 명시한다. 셸 안 인라인 python 은 `python3 -I`, 스크립트 호출에는 `-I` 를 쓰지 않는다.
- 변이 검증과 테스트 실행에는 `PYTHONDONTWRITEBYTECODE=1` 을 건다.
- `SKILL.md` 자기 줄 수(`skill_own_lines`)는 `SKILL_LINE_CAP=504` 미만을 Task 마다 유지한다. 현재 503 — 여유 1줄. 그래서 걷어내는 Task 2 가 더하는 Task 3 · 4 보다 먼저다.
- `plugin.json` 버전과 CHANGELOG 머리는 Task 9 에서 함께 올린다(main 이 이미 5.4.0 이다 — 머지 직전에 `git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json` 으로 다시 재고 그 minor + 1 로 정한다).
- 셸 테스트는 리포 루트에서 `bash plugins/spec-distill/tests/<이름>.sh` 로 돌린다. 실패 줄은 `  ✗ ` 로 시작한다.
- 이 worktree 세션의 Bash 가드는 git 이 섞인 복합 명령(`cd … && git …`, `$(git …)` 안의 경로 조합)을 거부한다. git 명령은 한 줄에 하나씩 worktree 루트에서 돌리고, 여러 단계 스크립트는 `~/.claude/sdd-mirror/r1-impl/` 에 써서 `bash <스크립트>` 로 돌린다(job tmp 는 세션 재개에 사라진다).

## Review Focus

1. **재개된 세션에 조사 원문 블록이 없다** — 옛 세션이나 원문을 남기지 않은 세션에서 판정자 입력을 만들 때, 본체 요약(`research_log.summary`)으로 메우지 않고 판정 불가 경로로 가야 한다. → Task 4 의 `saturation.md` 락이 「요약으로 대신하지 않는다」 문구를 문다.
2. **상한 환경 변수가 이상한 값**(`abc` · `0` · `-3` · 빈 값) — 기본값(20 · 5)으로 두고 한 줄로 알려야 한다. 조용히 0 으로 읽으면 첫 dispatch 전에 곧장 멈춘다. → Task 4 락이 두 기본값 문구를 문다.
3. **포화 판정 줄이 여럿이고 순서가 섞였다** — 앞에 `포화`, 뒤에 `아직` 이 오면 실패해야 한다(마지막 줄이 이긴다). → Task 1 의 `sat_order` 케이스.
4. **조사 상한이 하한 자리(blind-spot-prober 첫 전이) 직전에 찬다** — 하한도 상한 앞에서 멈추고, 사용자가 「지금 포화 판정으로」를 고르면 inline premortem 강등으로 blind_spot 을 닫는다. → Task 4 락이 그 문장을 문다.
5. **`*` 불릿으로 쓴 §2 데이터 줄** — 형제 검사(`MAPPER_RE`)와 같은 `[-*]` 어휘로 읽혀야 한다. → Task 1 의 `sat_star` 케이스.

## 설계와 다르게 · 더 정한 것 (사용자에게 보고)

설계문서의 `### Deferred to plan` 11건과 미결 4줄을 이 계획이 이렇게 닫는다. 설계 본문의 결정(confirmed)을 바꾸는 것은 없고, 문서 안의 어긋남은 Task 10 이 본문 쪽으로 맞춘다.

| 항목 | 이 계획의 처리 |
|---|---|
| AC6 이 §5 와 어긋남(fixture 다섯 · 「판정 불가 — 사용자 선택」 advisory 통과) | §5 를 따른다 — 통과 셋 · 실패 넷 + 앵커 · 순서 · `*` 불릿. `판정 불가 → 조사 계속` 은 실패(D1.1). Task 10 이 AC6 문장을 §5 로 고친다 |
| 판정자 입력 원문의 저장 자리(f8f1ca38) | state 본문 `### 조사 <n> — <장치> · R<round>` 아래 verbatim. 판정자 `<research_outputs>` 는 그 블록을 번호 순으로 이어 붙인다. 블록이 빠졌으면 요약으로 대신하지 않고 판정 불가 |
| `check_slots.py` 면제 사유가 지운 R1 단계를 인용 | 사유 문장만 고친다(면제 수 4 그대로) — Task 5 |
| repo-researcher 입력 칸 종류(037a02d1) | `question` task · `claims_contract` repo_context · `open_decisions` task. 면제 목록을 늘리지 않는다 |
| `opened` 모양 차이(dacada0a) | 비교 규칙: 같은 `n` 에서 `changed` 집합이 같고, `research_log.opened` 가 `[]` 인 것과 판정자 `opened: 없음` 이 같은 값이다. 다르면 «지금 이해»에 한 줄 |
| §8 의 없는 「상한 연장」 줄(d8cac288) | 실제 형식 `상한 도달 … — 사용자 선택 S<m>: 연장` 이 그 줄이고 연장 뒤 한도는 state `research_limit` 에서 읽는다 — Task 10 이 §8 을 고친다 |
| README 「사슬 전체의 바깥 조사 상한 = research_limit」 공시가 사실과 다름(fa43c3f4) | README 는 「조사 subagent 호출 상한은 research_limit, 본체 직접 웹 검색은 라운드 규약(질문 하나 · 답 하나)이 묶는다」로 공시한다 — Task 9 |
| 재결정 문단의 「판정자의 반복 감지」(cf8808d8) | Task 10 이 「인터뷰 본체의 반복 감지」로 고친다 |
| G9 · 판정 상한에 AC 없음(r3 recritic 추가 지적) | Task 4 가 락을 둔다(G9 문구 존재 · 승인 미요청 · 판정 상한 도달 문구). Task 10 이 AC5 에 두 줄을 더한다 |
| «context-engineering» · «chroma-context-rot» 행이 본문과 충돌(17563e51) | 본문(원문 전량)을 따른다 — Task 10 이 두 행을 「판정자는 조사 원문 전량을 받는다 — 본체 요약을 거치지 않기 위해서이고 긴 입력 위험은 감수한다」로 고친다 |
| AC2 코퍼스와 이월 문서 충돌(fccf272b) | 옛 키 부재 락은 `state-migration.md` 를 뺀 production 표면에서 재고, 그 파일에는 「옛 키를 지운다」 양성 짝을 둔다 |
| yagni `changed`/`opened`(5576bd0c) | 설계대로 둔다(표시 · 대조용). 천장 조건은 그 advisory 의 문장 그대로 CHANGELOG 에 남기지 않고 이 표에만 둔다 |
| AC1 열거가 agent 의 한국어 규칙 · 「사용하지 않는 경우」를 못 덮음(0b618227) | 부재 락이 agent 두 파일 전체에서 `자격 + 예산` · `재개방 합` · `예산 고갈` 을 함께 잰다 |
| `SKILL.md` 줄 예산 | 걷는 줄 약 −39, 더하는 줄 약 +29 → 약 493. 상한 504 그대로 두고 Task 9 에서 「실측 + 8」로 조인다(503 을 넘지 않는다) |
| 커밋된 brief 를 게이트에 태우는 테스트 | 없다(실측). 실제 brief 는 다시 게이트를 타지 않는다. fixture 는 audit 80개에 통과 줄 하나를 더하는 한 번의 스윕으로 맞춘다 |
| `research_log` 채우는 시점 | 조사 산출을 «지금 이해»에 실은 직후(V1 확인을 거친 뒤) 그 라운드 안에서 |

---

## 파일 지도

| 파일 | 책임 | Task |
|---|---|---|
| `plugins/spec-distill/scripts/check_brief.py` | `saturation_failures` — audit §2 마지막 포화 판정 줄 검사 | 1 |
| `plugins/spec-distill/templates/interview-audit-template.md` | §2 줄 형식(자리표) | 1 |
| `plugins/spec-distill/tests/fixtures/interview-brief-*.audit.md` (80개) | 통과 포화 줄 한 줄 추가 | 1 |
| `plugins/spec-distill/tests/test_check_brief.sh` · `test_audit_template_gate_shape.py` · `test_brief_no_statement_cap.sh`(읽기만 확인) | 게이트 케이스 | 1 |
| `plugins/spec-distill/skills/spec-interview/SKILL.md` | 스키마 · 장치 걷기 · repo-researcher dispatch · 조사 상한 절 · 재구성 제거 · 되묻기 · R2 시점 | 2 · 3 · 4 · 5 · 6 |
| `plugins/spec-distill/skills/spec-interview/references/state-migration.md` | 이월 규칙 | 2 |
| `plugins/spec-distill/skills/spec-interview/references/saturation.md` (새) | 상한 도달 · 포화 판정 · 반복 감지 · 판정 불가 · 판정 상한 · audit 줄 | 4 |
| `plugins/spec-distill/skills/spec-interview/references/finishing.md` | 종료 driver · root_problem 규약 · audit §2 줄 | 2 · 4 · 5 |
| `plugins/spec-distill/skills/spec-interview/references/steelman.md` | 횟수 → 반복 감지 · Step 1 사용자 원문 | 5 · 6 |
| `plugins/spec-distill/agents/coverage-mapper.md` · `blind-spot-prober.md` · `steelman-builder.md` | 자격 · 예산 · 재구성 · 비사용 · confidence · 횟수 | 2 · 5 · 6 |
| `plugins/spec-distill/agents/repo-researcher.md` (새) | 레포 조사자 | 3 |
| `plugins/spec-distill/agents/saturation-judge.md` (새) | 포화 판정자 | 4 |
| `plugins/spec-distill/tests/test_research_agents_frontmatter.sh` (새) | 새 agent 둘의 도구 · 슬롯 · 역할 · 출력 락 | 3 · 4 |
| `plugins/spec-distill/tests/test_saturation_reference.sh` (새) | `saturation.md` 와 SKILL 조사 상한 절의 존재 · 부재 락 | 4 |
| `plugins/spec-distill/tests/test_conducting_interview_stage.sh` | 장치별 락 뒤집기 | 2 · 3 · 5 · 6 · 9 |
| `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh` · `test_blind_spot_prober_frontmatter.sh` · `test_stale_terms.sh` · `test_research_claims_contract.sh` · `test_readme_sync.sh`(읽기만) | 락 갱신 | 2 · 3 · 6 |
| `tools/adjudication/check_slots.py` | 면제 사유 문장 두 개 | 5 |
| `plugins/spec-distill/README.md` · `CHANGELOG.md` · `.claude-plugin/plugin.json` | 공시 · 버전 | 2 · 3 · 4 · 5 · 9 |
| `docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md` | 문서 안 어긋남 정정 | 10 |

---

### Task 0: 준비 — main 최신화 · baseline

**Files:** 없음(브랜치 · 기록만)

**Interfaces:**
- Produces: `~/.claude/sdd-mirror/r1-impl/baseline-before.txt` (실패 이름 집합), `~/.claude/sdd-mirror/r1-impl/run_suite.sh`

- [ ] **Step 1: main 을 merge 로 들인다** (rebase 금지)

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-persistent-explore
git fetch origin
git merge --no-edit origin/main
git log --oneline -1
```
Expected: 충돌 없이 merge 커밋(브랜치는 문서만 바꿨다). `plugins/spec-distill/.claude-plugin/plugin.json` 이 `5.4.0` 이다.

- [ ] **Step 2: 실패 이름 집합을 재는 스크립트를 만든다**

```bash
mkdir -p ~/.claude/sdd-mirror/r1-impl
cat > ~/.claude/sdd-mirror/r1-impl/run_suite.sh <<'SH'
#!/usr/bin/env bash
# 사용: run_suite.sh <출력 파일>. 리포 루트에서 돈다. 실패 «이름» 줄을 정렬해 남긴다.
set -u
OUT="$1"
ROOT=/Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-persistent-explore
cd "$ROOT" || exit 1
export PYTHONDONTWRITEBYTECODE=1
: > "$OUT.raw"
for t in plugins/spec-distill/tests/*.sh shared/tests/*.sh; do
  bash "$t" 2>&1 | grep -E '^  ✗ ' | sed "s|^|$t: |" >> "$OUT.raw"
done
for t in plugins/spec-distill/tests/test_*.py; do
  python3 -m unittest "$t" 2>&1 | grep -E '^(FAIL|ERROR): ' | sed "s|^|$t: |" >> "$OUT.raw"
done
sort -u "$OUT.raw" > "$OUT"
wc -l < "$OUT"
SH
chmod +x ~/.claude/sdd-mirror/r1-impl/run_suite.sh
```

- [ ] **Step 3: baseline 을 잰다**

Run: `bash ~/.claude/sdd-mirror/r1-impl/run_suite.sh ~/.claude/sdd-mirror/r1-impl/baseline-before.txt`
Expected: 숫자 한 줄(선재 실패 줄 수). 0 이 아니어도 된다 — 이 집합이 비교 기준이다. 숫자와 파일을 진행 보고에 남긴다.

---

### Task 1: 종료 게이트 `saturation_failures`

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py` (`budget_mapper_failures` 바로 아래 · `gate()` 의 mapper 호출 바로 아래)
- Modify: `plugins/spec-distill/templates/interview-audit-template.md` (§2)
- Modify: `plugins/spec-distill/tests/fixtures/interview-brief-*.audit.md` (80개, 스윕)
- Modify: `plugins/spec-distill/tests/test_check_brief.sh` (T-TPL sed · 새 케이스 블록)
- Modify: `plugins/spec-distill/tests/test_audit_template_gate_shape.py` (새 테스트 셋)

**Interfaces:**
- Produces: `check_brief.saturation_failures(audit_text: str, anchors: set) -> tuple[list[str], list[str]]` — `(failures, advisories)`. 실패 문자열은 `coverage-mapper` 를 담지 않는다. `gate()` 는 실패를 `f"saturation: {x}"` 로 싣는다.
- Produces: audit §2 줄 형식(설계 §4) — `- 포화 판정 <k>: 포화 — …` · `- 포화 판정 <k>: 아직 — 빈 곳 <g>개` · `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — …` · `- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)` · `- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)` · `- 사용자 종료(@S<m>) — 포화 판정 전` · `- 사용자 종료(@S<m>) — 마지막 판정 아직`.

- [ ] **Step 1: 실패하는 게이트 케이스를 쓴다** — `test_check_brief.sh` 의 마지막 `finish` 바로 위에 붙인다(`ac3_pair` · `ac3_gate` 는 위에서 정의돼 있다).

```bash
# --- R1(2026-10-12) 설계 §5: audit §2 의 «마지막» 포화 판정 줄 (saturation_failures) ---
# 정상 쌍에서 포화 줄을 전부 지우고, 둘째 인자의 줄(들)을 mapper 데이터 줄 바로 뒤에 넣는다.
sat_case() {  # $1 = stem, $2 = 넣을 줄(개행으로 여럿 · 빈 값이면 넣지 않는다)
  ac3_pair "$1"
  python3 -I - "$TMPD/$1.audit.md" "$2" <<'PY'
import re, sys
p, ins = sys.argv[1], sys.argv[2]
t = open(p, encoding="utf-8").read()
t = re.sub(r"^[-*] (포화 판정 \d+:|사용자 종료\(@S\d+\)).*\n", "", t, flags=re.M)
if ins:
    t = re.sub(r"^([-*] agent dispatch: coverage-mapper .*\n)",
               lambda m: m.group(1) + ins + "\n", t, count=1, flags=re.M)
open(p, "w", encoding="utf-8").write(t)
PY
}
sat_pass_case() {  # $1 stem, $2 줄, $3 라벨
  sat_case "$1" "$2"; out="$(ac3_gate "$1")"; rc=$?
  { [[ $rc -eq 0 ]] && ! grep -q 'saturation:' <<<"$out"; } \
    && ok "R1/§5: $3 → 통과" || { no "R1/§5: $3 가 red"; printf '    %s\n' "$out"; }
}
sat_fail_case() {  # $1 stem, $2 줄, $3 기대 사유 리터럴, $4 라벨
  sat_case "$1" "$2"; out="$(ac3_gate "$1")"; rc=$?
  { [[ $rc -ne 0 ]] && grep -qF "$3" <<<"$out"; } \
    && ok "R1/§5: $4 → red «$3»" || { no "R1/§5: $4 가 통과했거나 사유가 다르다"; printf '    %s\n' "$out"; }
}
# 양성 대조 — 스윕이 정상 쌍에 통과 줄을 넣었고, sat_case 가 그것을 지운다.
grep -qE '^- 포화 판정 1: 포화 — ' "$FX/interview-brief-valid.audit.md" \
  && ok "R1/§5(양성대조): 정상 fixture 에 포화 통과 줄이 있다" || no "R1/§5(양성대조): 정상 fixture 에 포화 줄이 없다 — 스윕 누락"
sat_case s_ctl ""
grep -qE '포화 판정|사용자 종료\(@S' "$TMPD/s_ctl.audit.md" \
  && no "R1/§5(양성대조): sat_case 가 포화 줄을 못 지웠다 — 아래 «줄 없음» 단언이 공허하다" \
  || ok "R1/§5(양성대조): sat_case 가 포화 줄을 지운다"
# 통과 셋
sat_pass_case s_pass '- 포화 판정 2: 포화 — 최근 두 조사 모두 결정을 바꾸지도 열지도 않았다' '판정자 포화'
sat_case s_user '- 포화 판정 2: 사용자 판단 포화(@S2) — 반복 빈 곳'
out="$(ac3_gate s_user)"; rc=$?
{ [[ $rc -eq 0 ]] && grep -q '"advisories": \[.*사용자 판단 포화' <<<"$out"; } \
  && ok "R1/§5: 사용자 판단 포화(@S2) → advisory 통과, advisories 채널에 실림" \
  || { no "R1/§5: 사용자 판단 포화가 red 이거나 advisory 가 비었다"; printf '    %s\n' "$out"; }
sat_pass_case s_stop '- 사용자 종료(@S2) — 포화 판정 전' '사용자 종료 — 포화 판정 전'
sat_pass_case s_stop2 $'- 포화 판정 1: 아직 — 빈 곳 2개\n- 사용자 종료(@S2) — 마지막 판정 아직' '아직 뒤 사용자 종료'
# 실패 넷
sat_fail_case s_none '' '포화 판정 줄 없음' '포화 판정 줄 없음'
sat_fail_case s_notyet '- 포화 판정 1: 아직 — 빈 곳 2개' '마지막 포화 판정이 «아직»' '마지막이 아직'
sat_fail_case s_cont '- 포화 판정 1: 판정 불가(Agent 도구 부재) — 조사 계속(@S2)' '조사 계속' '판정 불가 뒤 조사 계속'
sat_fail_case s_bad '- 포화 판정 1: 대충 끝났다' '형식 밖' '형식 밖'
# 순서 · 앵커 · 반복 재조사 · 불릿 어휘
sat_fail_case s_order $'- 포화 판정 1: 포화 — 최근 두 조사 새로움 없음\n- 포화 판정 2: 아직 — 빈 곳 1개' '마지막 포화 판정이 «아직»' '포화 뒤 아직(마지막이 이긴다)'
sat_pass_case s_order2 $'- 포화 판정 1: 아직 — 빈 곳 1개\n- 포화 판정 2: 포화 — 최근 두 조사 새로움 없음' '아직 뒤 포화'
sat_pass_case s_contok $'- 포화 판정 1: 판정 불가(출력 깨짐) — 조사 계속(@S2)\n- 포화 판정 2: 포화 — 최근 두 조사 새로움 없음' '조사 계속 뒤 포화'
sat_fail_case s_redo '- 포화 판정 3: 아직 — 반복 빈 곳 재조사(@S2)' '마지막 포화 판정이 «아직»' '반복 빈 곳 재조사가 마지막'
sat_fail_case s_anchor '- 사용자 종료(@S99) — 포화 판정 전' 'S99' '사용자 종료의 S 앵커 부재'
sat_fail_case s_uanchor '- 포화 판정 2: 사용자 판단 포화(@S98) — 판정 불가(출력 깨짐)' 'S98' '사용자 판단 포화의 S 앵커 부재'
sat_pass_case s_star '* 포화 판정 2: 포화 — 최근 두 조사 새로움 없음' '«*» 불릿 포화 줄'
# 실패 문구가 mapper 단언(m_star 의 «출력에 coverage-mapper 없음»)을 오염하지 않는다.
sat_case s_noise ''
out="$(ac3_gate s_noise)"
grep -q 'coverage-mapper' <<<"$out" \
  && no "R1/§5: 포화 실패 문구에 coverage-mapper 가 섞였다" || ok "R1/§5: 포화 실패 문구에 coverage-mapper 없음"
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep -E '✗ R1/§5' | head -20`
Expected: `R1/§5(양성대조): 정상 fixture 에 포화 줄이 없다` 와 실패 케이스들(`s_none` 등이 «통과했거나 사유가 다르다»).

- [ ] **Step 3: `check_brief.py` 에 검사를 더한다** — `budget_mapper_failures` 함수 끝(`return ["§2 Budget: coverage-mapper 0 without unavailable reason"], []`) 바로 아래에 붙인다.

```python


# 설계 2026-10-12-interview-persistent-explore §4·§5 — audit §2 의 포화 판정 줄. 판정은 «마지막» 줄로
# 한다: 판정과 사용자 선택이 시간 순으로 쌓이고, 그 끝이 인터뷰가 어떻게 끝났는지다. 불릿 어휘는
# 형제(`MAPPER_RE` · `ENTRY_BULLET_RE`)와 같은 `[-*]` 다 — `_entry_lines` 가 이미 그 어휘로 거른다.
SAT_LINE_RE = re.compile(r"^(?:포화 판정 \d+:|사용자 종료\(@S\d+\))")
SAT_PASS_RE = re.compile(r"^포화 판정 \d+: 포화 — \S")
SAT_USER_RE = re.compile(r"^포화 판정 \d+: 사용자 판단 포화\(@(S\d+)\) — \S")
SAT_STOP_RE = re.compile(r"^사용자 종료\(@(S\d+)\) — (?:포화 판정 전|마지막 판정 아직)$")
SAT_NOT_YET_RE = re.compile(r"^포화 판정 \d+: 아직 — \S")
SAT_CONTINUE_RE = re.compile(r"^포화 판정 \d+: 판정 불가\([^)]*\) — 조사 계속\(@S\d+\)$")


def saturation_failures(audit_text: str, anchors: set) -> tuple[list[str], list[str]]:
    """audit §2 의 마지막 포화 판정 줄 (설계 §5).

    통과: 판정자 `포화` · 사용자 종료(S 앵커 실재) · 사용자 판단 포화(S 앵커 실재, advisory).
    실패: 줄 없음 · 마지막이 `아직`(반복 빈 곳 재조사 포함) · 마지막이 `판정 불가 — 조사 계속` ·
    형식 밖. **이 검사가 못 잡는 것**: 줄은 본체가 쓴다 — 판정자를 부르지 않은 턴이 `포화` 줄을
    지어 적으면 구별하지 못한다. 그 축은 판정자 dispatch 의 처분 줄과 Step B 의 사람 확인이 진다."""
    sec = _section_text(audit_text, "2", "Budget")
    hits = [b for b in (_strip_bullet(ln).strip() for ln in _entry_lines(sec))
            if SAT_LINE_RE.match(b)]
    if not hits:
        return ["§2 Budget: 포화 판정 줄 없음 — floor 다섯이 닫힌 뒤 포화 판정자를 부르지 않았거나 "
                "사용자 종료를 적지 않았다"], []
    last = hits[-1]
    if SAT_PASS_RE.match(last):
        return [], []
    for rx, kind in ((SAT_USER_RE, "user"), (SAT_STOP_RE, "stop")):
        m = rx.match(last)
        if m:
            s = m.group(1)
            if s not in anchors:
                return [f"§2 Budget: 마지막 포화 판정 줄의 앵커 {s} 가 §6 에 없다"], []
            if kind == "user":
                return [], [f"사용자 판단 포화(@{s}) — 판정자의 «포화» 없이 사용자가 끝냈다 (사람이 확인할 것)"]
            return [], []
    if SAT_NOT_YET_RE.match(last):
        return ["§2 Budget: 마지막 포화 판정이 «아직» — 빈 곳을 조사한 뒤 다시 판정하거나 사용자가 끝내야 한다"], []
    if SAT_CONTINUE_RE.match(last):
        return ["§2 Budget: 판정 불가 뒤 사용자가 조사 계속을 골랐는데 그 뒤 포화 판정이나 사용자 종료 줄이 없다"], []
    return [f"§2 Budget: 포화 판정 줄이 형식 밖이다: {last[:80]}"], []
```

- [ ] **Step 4: `gate()` 에 배선한다** — `advisories += ba` (mapper 호출 바로 아래) 다음 줄에, 같은 `if not any(m.startswith("2.") for m in amiss):` 블록 안으로 넣는다.

```python
                sf, sa = saturation_failures(
                    audit_text, payload_verbatim_anchors(text) | verbatim_anchors(audit_text))
                failures += [f"saturation: {x}" for x in sf]
                advisories += sa
```
들여쓰기는 바로 위 `bf, ba = budget_mapper_failures(audit_text)` 와 같다. 이 코드는 `if contract_v2(text):` 블록 밖이다(`c5static` AST 락 대상 아님).

- [ ] **Step 5: fixture 80개에 통과 줄을 넣는다** (한 번만 · 멱등)

```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-persistent-explore
python3 -I - <<'PY'
import re, pathlib
fx = pathlib.Path("plugins/spec-distill/tests/fixtures")
line = "- 포화 판정 1: 포화 — 최근 두 조사 모두 결정을 바꾸지도 열지도 않았다\n"
n = 0
for p in sorted(fx.glob("interview-brief-*.audit.md")):
    t = p.read_text(encoding="utf-8")
    if "포화 판정 1: 포화" in t:
        continue
    # §2 Budget 안에서만 mapper 데이터 줄을 찾는다 — 다른 절의 같은 글자에 넣지 않는다.
    s = re.search(r"^## 2\. Budget\b.*$", t, flags=re.M)
    e = re.search(r"^## 3\.", t[s.end():], flags=re.M) if s else None
    if not s:
        print("§2 없음:", p.name); continue
    end = s.end() + (e.start() if e else len(t) - s.end())
    sec = t[s.end():end]
    sec2, k = re.subn(r"^([-*] .*coverage-mapper \d.*\n)", lambda m: m.group(1) + line, sec, count=1, flags=re.M)
    if k:
        p.write_text(t[:s.end()] + sec2 + t[end:], encoding="utf-8"); n += 1
    else:
        print("mapper 줄 없음:", p.name)
print("스윕", n)
PY
```
Expected: `스윕 80` 이고 「§2 없음」 · 「mapper 줄 없음」 0줄. 숫자가 다르면 멈추고 보고한다.

- [ ] **Step 6: 출하 템플릿 §2 에 자리표 줄을 더한다** — `interview-audit-template.md` 의 `- 질문 라운드: <n> · agent dispatch: <n> · coverage-mapper <k> · codex 실호출: <n> (성공 <n>)` 줄 바로 아래 두 줄과, 설명 산문 끝(`침묵보다 red 가 낫다.)`) 바로 뒤 문단 하나:

설명 산문 `… 침묵보다 red 가 낫다.)` 다음 빈 줄 뒤에 넣는다:
```markdown
(포화 판정 줄 — 게이트는 아래 불릿 중 `포화 판정 <k>:` 또는 `사용자 종료(@S<n>)` 로 시작하는 **마지막** 줄을 본다.
판정자 `포화` · 사용자 종료 · 사용자 판단 포화(advisory)면 통과, 줄이 없거나 마지막이 `아직` · `판정 불가 — 조사 계속` 이면
red 다. 판정마다 한 줄, 사용자 선택마다 한 줄을 시간 순으로 덧붙인다 — 형식의 정본은 spec-interview 의 포화 판정 reference 다.
`<k>` 는 실제 차례로 치환한다 — 채우지 않은 자리표는 게이트 red 다.)
```
데이터 줄(기존 mapper 줄 바로 아래):
```markdown
- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 본체 직접 <e>)
- 포화 판정 <k>: <포화 — <basis 요지> | 아직 — 빈 곳 <g>개 | …>
```
템플릿 산문에 아직 없는 파일의 경로를 쓰지 않는다(포인터 락 `test_skill_reference_pointers.sh` 가 끊긴 경로를 잡는다 — 그 파일은 Task 4 에서 생긴다).

`test_check_brief.sh` T-TPL 의 sed 줄 `sed -i.bak 's|coverage-mapper <k>|coverage-mapper 2|' "$TMPD/tpl.audit.md"` 바로 다음 줄에 Step 7 의 sed 를 넣는다(그 다음 줄 `rm -f "$TMPD/tpl.md.bak" "$TMPD/tpl.audit.md.bak"` 가 `.bak` 을 치운다).

- [ ] **Step 7: T-TPL 과 템플릿 형태 테스트를 맞춘다**

`test_check_brief.sh` 의 T-TPL(출하 템플릿 사본 `$TMPD/tpl.audit.md`, mapper sed 바로 다음 줄)에 한 줄:
```bash
sed -i.bak 's|^- 포화 판정 <k>: .*$|- 포화 판정 1: 포화 — 최근 두 조사 새로움 없음|' "$TMPD/tpl.audit.md"
```

`test_audit_template_gate_shape.py` 의 클래스 끝에 셋:
```python
    def test_saturation_placeholder_is_red(self):
        """출하 템플릿의 포화 줄은 자리표다 — 채우지 않으면 red (침묵보다 red)."""
        self.assertIn("포화 판정 <k>:", self.text, "§2 에 포화 판정 자리표 줄이 없다")
        fails, _ = check_brief.saturation_failures(self.text, set())
        self.assertTrue(fails, "자리표를 안 채운 템플릿이 포화 검사를 통과했다")

    def test_saturation_filled_copy_passes(self):
        filled = self.text.replace(
            next(ln for ln in self.text.splitlines() if ln.startswith("- 포화 판정 <k>:")),
            "- 포화 판정 1: 포화 — 최근 두 조사 새로움 없음")
        fails, adv = check_brief.saturation_failures(filled, set())
        self.assertEqual((fails, adv), ([], []))

    def test_saturation_prose_alone_does_not_satisfy(self):
        """설명 산문은 판정에 참여하지 않는다 — 데이터 불릿을 지운 사본은 red."""
        stripped = "\n".join(ln for ln in self.text.splitlines()
                             if not ln.startswith("- 포화 판정"))
        fails, _ = check_brief.saturation_failures(stripped, set())
        self.assertTrue(fails, "데이터 줄 없이 산문만으로 포화 검사가 통과했다")
```

- [ ] **Step 8: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | tail -3
python3 -m unittest plugins/spec-distill/tests/test_audit_template_gate_shape.py 2>&1 | tail -3
bash plugins/spec-distill/tests/test_brief_no_statement_cap.sh 2>&1 | tail -2
bash plugins/spec-distill/tests/test_brief_no_length_cap.sh 2>&1 | tail -2
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -3
```
Expected: 모두 `Fail: 0`(또는 baseline 의 선재 실패와 같은 이름만), unittest `OK`. `R1/§5` 단언 전부 ✓.

- [ ] **Step 9: 커밋**

```bash
git add plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/templates/interview-audit-template.md \
  plugins/spec-distill/tests/test_check_brief.sh plugins/spec-distill/tests/test_audit_template_gate_shape.py \
  plugins/spec-distill/tests/fixtures/interview-brief-*.audit.md
git commit -m "$(cat <<'MSG'
feat(spec-distill): 종료 게이트가 audit §2 의 마지막 포화 판정 줄로 거절한다

판정자 포화 · 사용자 종료 · 사용자 판단 포화(advisory)만 통과한다. 줄 없음 · 아직 ·
판정 불가 뒤 조사 계속 · 형식 밖은 red 다. fixture 80개에 통과 줄을 한 번 스윕했다.

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
git show --stat HEAD | tail -3
```
Expected: 파일 수 = 4 + 80.

---

### Task 2: 자격 · 예산 · 리듬 강제를 걷는다 (스키마 · 이월 포함)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md` (state 스키마 · `open_decisions[]` 생명주기 · State body · C43 행 (a) 꼬리 · `## C44` 절 삭제 · `## coverage-mapper dispatch` 절 · `## blind-spot-prober dispatch` 첫 문단 · 닫힘 절 재개방 문장 · In-flight 포인터 · kill switch)
- Modify: `plugins/spec-distill/skills/spec-interview/references/state-migration.md` (전면)
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` (Step A ④ 카운터 이름)
- Modify: `plugins/spec-distill/agents/coverage-mapper.md` · `blind-spot-prober.md` (description · 제목 · 규칙 4 · 비사용 항목)
- Modify: `plugins/spec-distill/README.md` (C44 줄 · rhythm 스위치 줄 · AP16 「rhythm guard 3」 · P17 자격+예산 문단 · C4 줄 · AP9 줄의 자격+예산 꼬리)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` · `test_coverage_mapper_frontmatter.sh` · `test_blind_spot_prober_frontmatter.sh`

**Interfaces:**
- Produces (state 키, 이후 Task · R6 가 읽는다): `orchestration.research_dispatches.{coverage_mapper,blind_spot_prober,steelman_builder,repo_researcher}` · `orchestration.research_limit` · `orchestration.saturation_limit` · `orchestration.research_log[]` · `orchestration.saturation_log[]`.
- Produces: SKILL 절 머리 `## coverage-mapper dispatch` (괄호 꼬리 없음).

- [ ] **Step 1: 락을 먼저 뒤집는다 (TCIS)** — 아래 바꿈을 `test_conducting_interview_stage.sh` 에 한다. 줄 번호는 지금 값이고, 각 바꿈은 인용한 리터럴로 찾는다.

(a) 스키마 블록의 `blind_spot_dispatches` 존재 단언(`grep -qE '^ +blind_spot_dispatches: 0' <<<"$state_block"` 세 줄)을 다음으로 바꾼다:
```bash
grep -qE '^ +research_dispatches: \{coverage_mapper: 0, blind_spot_prober: 0, steelman_builder: 0, repo_researcher: 0\}' <<<"$state_block" \
  && ok "R1/state: orchestration.research_dispatches (장치별 넷) in schema" \
  || no "R1/state: orchestration.research_dispatches 부재 또는 장치 칸이 넷이 아니다"
for k in research_limit saturation_limit research_log saturation_log; do
  grep -qE "^ +${k}:" <<<"$state_block" && ok "R1/state: orchestration.${k} in schema" || no "R1/state: orchestration.${k} 부재"
done
for k in blind_spot_dispatches coverage_mapper_dispatches; do
  grep -qE "^ +${k}:" <<<"$state_block" && no "R1/state: 옛 카운터 ${k} 가 스키마에 잔존" || ok "R1/state: 옛 카운터 ${k} 없음"
done
```

(b) `for fld in 'id: OQ' 'dimension:' 'status: open' 'resolved_by:' 'touched: false'; do` 에서 `'touched: false'` 를 지운다.

(c) `has 'coverage_mapper_dispatches' "C4: orchestration.coverage_mapper_dispatches in schema"` 한 줄을 지운다(아래 (g) 의 부재 락이 대신한다).

(d) `has 'non_user_streak' "AC1: non_user_streak retained"` 와 그 위 주석 `# AC1: 기존 필드 보존` 을 지운다.

(e) 이월 advisory 두 `has` 를 바꾼다:
```bash
has 'coverage_mapper_dispatches/blind_spot_dispatches -> research_dispatches' "R1/state: advisory 가 이월을 이름으로 댄다"
has 'research_limit · saturation_limit · research_log · saturation_log added' "R1/state: advisory 가 신설 키를 이름으로 댄다"
```
(옛 줄은 `has 'blind_spot_dispatched -> blind_spot_dispatches' …` 와 `has 'open_decisions added' …`.)

(f) migration 열거 · 이월 규칙 단언(정확 일치 열거 한 덩어리 + `mig_flat` 의 이월 세 단언)을 다음으로 바꾼다. `mig_flat="$(tr '\n' ' ' <<<"$mig_block" | tr -s ' ')"` 정의 줄은 남긴다.
```bash
{ grep -qF '`orchestration`: `{focused_dimension: null, research_dispatches: {coverage_mapper: 0, blind_spot_prober: 0, steelman_builder: 0, repo_researcher: 0}, research_limit: <시작값>, saturation_limit: <시작값>, research_log: [], saturation_log: [], open_decisions: []}`' <<<"$mig_block"; } \
  && ok "R1/state: migration 절의 orchestration 열거가 새 키와 정확히 일치" \
  || no "R1/state: migration 절의 orchestration 열거가 새 키와 다르다"
grep -qF '`coverage_mapper_dispatches: <k>` 는 `research_dispatches.coverage_mapper: <k>` 로' <<<"$mig_flat" \
  && ok "R1/state: 이월 — coverage_mapper_dispatches 값 보존" || no "R1/state: coverage_mapper_dispatches 이월 규칙 부재 — 상한 계수가 0 으로 되돌아간다"
grep -qF '`blind_spot_dispatches: <k>` 는 `research_dispatches.blind_spot_prober: <k>` 로' <<<"$mig_flat" \
  && ok "R1/state: 이월 — blind_spot_dispatches 값 보존" || no "R1/state: blind_spot_dispatches 이월 규칙 부재"
grep -qF '`blind_spot_dispatched: true` 가 있으면 `research_dispatches.blind_spot_prober: 1`' <<<"$mig_flat" \
  && ok "R1/state: 이월 — 더 옛 키 true → 1" || no "R1/state: blind_spot_dispatched 이월 규칙 부재"
grep -qE '옛 키 [^.]*`non_user_streak`[^.]*`touched`[^.]*를 \*\*지운다\*\*' <<<"$mig_flat" \
  && ok "R1/state(양의 짝): 이월 뒤 옛 키 · non_user_streak · touched 를 지운다" || no "R1/state: 옛 키 삭제 규칙 부재 — 두 이름이 공존한다"
grep -qF '`open_decisions` 는 부재 시 `[]`' <<<"$mig_flat" \
  && ok "AC13: open_decisions 기본값 []" || no "AC13: open_decisions 기본값 규칙 부재"
```

(g) A — coverage-mapper 절. `grep -qF '닿는 열린 결정이 아직 있는가' <<<"$covmap_flat"` 단언부터 `X4: 예산 식 + 카운터` 단언까지(자격 · 자격 우선 · 예산 식 · 예산 식+카운터 넷, 사이의 `인자 없이 부른 경로…` 단언은 남긴다)를 지우고 그 자리에:
```bash
# R1(2026-10-12): 자격 · 예산을 걷었다 — 부재 + 양의 짝(재호출 기준 · 새 카운터).
for tok in '닿는 열린 결정이 아직 있는가' '열린 결정이 0이면 자격이 없다' '1 + Σ' 'coverage_mapper_dispatches' '(자격 + 예산)'; do
  grep -qF -- "$tok" <<<"$covmap_block" \
    && no "R1/A: coverage-mapper 절에 옛 자격·예산 «${tok}» 잔존" || ok "R1/A: coverage-mapper 절에 «${tok}» 없음"
done
grep -qF '그 뒤는 결정에 닿을 수 있을 때마다' <<<"$covmap_flat" \
  && ok "R1/A(양의 짝): 재호출 기준 = 결정에 닿을 수 있을 때마다" || no "R1/A(양의 짝): coverage-mapper 재호출 기준 문구 부재"
grep -qF 'research_dispatches.coverage_mapper' <<<"$covmap_block" \
  && ok "R1/A(양의 짝): 카운터 research_dispatches.coverage_mapper" || no "R1/A(양의 짝): coverage-mapper 새 카운터 부재"
```

(h) B — blind-spot 절. `grep -qF '닿는 열린 결정이 아직 있는가' <<<"$blindspot_block"` 단언(C12 prober 호출 자격)과, `1회 필수로 dispatch 한다 — 첫 dispatch 는 자격을 보지 않는다` · `재호출부터는 자격이 예산보다 앞선다` · `열린 결정이 0이면 자격이 없다 — 예산이 남아도 부르지 않는다`(bs_flat_nb) · `blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened` 단언 넷을 지우고 그 자리에(`bs_flat_nb` 정의 줄은 남긴다):
```bash
for tok in '닿는 열린 결정이 아직 있는가' '자격이 예산보다 앞선다' '자격을 보지 않는다' '열린 결정이 0이면 자격이 없다' 'blind_spot_dispatches'; do
  grep -qF -- "$tok" <<<"$blindspot_block" \
    && no "R1/B: blind-spot-prober 절에 옛 자격·예산 «${tok}» 잔존" || ok "R1/B: blind-spot-prober 절에 «${tok}» 없음"
done
grep -qF '1회 필수로 dispatch 한다(하한)' <<<"$bs_flat_nb" \
  && ok "R1/B(양의 짝): prober 첫 전이 필수 1회(하한)" || no "R1/B(양의 짝): prober 첫 dispatch 필수 문구 부재"
grep -qF 'research_dispatches.blind_spot_prober' <<<"$blindspot_block" \
  && ok "R1/B(양의 짝): 카운터 research_dispatches.blind_spot_prober" || no "R1/B(양의 짝): prober 새 카운터 부재"
```

(i) C — 리듬 강제. `# rhythm-guard 재프레임 (AC9, scoped)` 줄부터 `grep -qF 'open_decisions' <<<"$rhythm_block"` 단언의 `|| no "AC14: 거처 참조 부재"` 줄까지(사이 주석 포함) 전부를 지우고 그 자리에:
```bash
# R1(2026-10-12): C44 리듬 강제를 걷었다 — 절 · 카운터 · 면제 필드 · 임계 환경 변수 · 옛 카운터의 부재.
# 이월 문서는 옛 키 이름을 알아야 지운다 — state-migration.md 만 코퍼스에서 뺀다(양의 짝은 그 파일의 삭제 규칙, 위 R1/state).
grep -q '^## C44' "$SKILL" && no "R1/C: C44 절 머리 잔존" || ok "R1/C: C44 절 머리 없음"
c_corpus=()
for _f in "${CI_ALL[@]}"; do [[ "$_f" == "$MIG_REF" ]] || c_corpus+=("$_f"); done
c_corpus+=("$REPO_ROOT/plugins/spec-distill/README.md" "$REPO_ROOT/plugins/spec-distill/agents/"*.md \
           "$REPO_ROOT/plugins/spec-distill/templates/"*.md "$REPO_ROOT/plugins/spec-distill/scripts/"*.py)
[[ "${#c_corpus[@]}" -ge 10 ]] && ok "R1/C(양성대조): 부재 코퍼스 ${#c_corpus[@]}개 파일" || no "R1/C(양성대조): 부재 코퍼스가 너무 작다 (${#c_corpus[@]})"
for tok in non_user_streak DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD 'Dialectic Rhythm Guard' coverage_mapper_dispatches blind_spot_dispatches; do
  grep -qF -- "$tok" "${c_corpus[@]}" && no "R1/C: «${tok}» 잔존 (production, 이월 문서 제외)" || ok "R1/C: «${tok}» 없음 (production)"
done
grep -qw 'touched' "${c_corpus[@]}" && no "R1/C: touched 필드 잔존 (production, 이월 문서 제외)" || ok "R1/C: touched 필드 없음 (production)"
```
`README.md` 의 `**vX.Y.Z**` 연혁 줄에 이 토큰이 있으면 그 줄은 사실 기록이다 — Step 6 에서 grep 으로 확인하고, 있으면 그 줄을 지우지 말고 이 단언의 README 입력을 `grep -vE '^\*\*v[0-9]'` 로 거른 임시 파일로 바꾼다.

(j) 라인 캡 단언 위 주석에 한 줄 덧붙인다(값은 Task 9 에서 조인다):
```bash
# 2026-10-12 R1: C44 · 자격/예산 문단을 걷고 조사 상한 절 · repo-researcher dispatch 를 더한다. 순감이라 값을 올리지 않는다.
```

- [ ] **Step 2: frontmatter 락을 뒤집는다**

`test_coverage_mapper_frontmatter.sh` 의 마지막 두 양의 짝(`dispatch eligibility is whether an open decision still` · `1 plus the total reopen count`)을 지우고 `finish` 위에:
```bash
# R1(2026-10-12): 자격 · 예산을 걷었다. 부재(영어 · 한국어 · 비사용 항목) + 양의 짝(새 부르기 서술).
for tok in 'eligibility' 'reopen count' '자격 + 예산' '재개방 합' '예산 고갈'; do
  grep -qiF -- "$tok" <<<"$AGENT_FLAT" && no "R1/A: 옛 자격·예산 «${tok}» 잔존" || ok "R1/A: «${tok}» 없음"
done
grep -qF -- 'whenever it could change an open decision or open a new one' <<<"$AGENT_FLAT" \
  && ok "R1/A(양의 짝): description 이 새 부르기 기준을 말한다" || no "R1/A(양의 짝): 새 부르기 서술 부재 — 부재 락이 공허해진다"
grep -qF -- 'R1 첫 질문 전 1회는 필수다' <<<"$AGENT_FLAT" \
  && ok "R1/A(양의 짝): 첫 호출 필수(하한) 문구" || no "R1/A(양의 짝): 첫 호출 필수 문구 부재"
```
`test_blind_spot_prober_frontmatter.sh` 의 세 양의 짝(`eligibility is` · `whether an open decision still touches that dimension` · `1 plus that dimension's reopen count`)을 지우고 같은 자리에:
```bash
for tok in 'eligibility' 'reopen count' '자격 + 예산' '자격 없음' '예산 고갈'; do
  grep -qiF -- "$tok" <<<"$AGENT_FLAT" && no "R1/B: 옛 자격·예산 «${tok}» 잔존" || ok "R1/B: «${tok}» 없음"
done
grep -qF -- 'whenever new framing, a reopen or a saturation gap could change an open decision' <<<"$AGENT_FLAT" \
  && ok "R1/B(양의 짝): description 이 새 부르기 기준을 말한다" || no "R1/B(양의 짝): 새 부르기 서술 부재"
grep -qF -- 'blind_spot 첫 전이 때 1회는 필수다' <<<"$AGENT_FLAT" \
  && ok "R1/B(양의 짝): 첫 전이 필수(하한) 문구" || no "R1/B(양의 짝): 첫 전이 필수 문구 부재"
```

- [ ] **Step 3: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep -cE '✗ R1/'` 와 두 frontmatter 테스트
Expected: R1/ 실패가 여럿(옛 문구 잔존 · 새 문구 부재).

- [ ] **Step 4: SKILL.md 를 고친다** — 각 블록을 Edit 의 old→new 로.

(1) state 스키마 `orchestration:` 부분. old:
```yaml
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  blind_spot_dispatches: 0           # 예산 = 1 + 그 차원의 reopened (자격은 아래 절)
  coverage_mapper_dispatches: 0      # 예산 = 1 + 모든 차원의 reopened 합 (자격은 아래 절)
```
new:
```yaml
  focused_dimension: null            # 현재 probe 대상 차원 이름 또는 null
  research_dispatches: {coverage_mapper: 0, blind_spot_prober: 0, steelman_builder: 0, repo_researcher: 0}  # 조사 subagent 호출 수
  research_limit: <int>              # 조사 호출 상한 — 시작값 DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT(기본 20), 연장마다 더한다
  saturation_limit: <int>            # 포화 판정 상한 — 시작값 DEVBREW_SPEC_DISTILL_SATURATION_LIMIT(기본 5), 연장마다 더한다
  research_log: []                   # 조사마다 {n, device, round, changed: [OQ…], opened: [OQ…], summary}
  saturation_log: []                 # 판정마다 {k, round, verdict, gaps: […], user_choice: S<n> | null}
```
같은 블록에서 old `  #     dimension: <차원 이름>        # 어느 커버리지 차원에 속하는가 (호출 자격의 입력)` → new `  #     dimension: <차원 이름>        # 어느 커버리지 차원에 속하는가`. old 두 줄
```yaml
  #     touched: false               # 조사가 닿았는가 (C44 면제의 입력)
non_user_streak: <int>
```
→ 지운다.

(2) State body 줄. old `State body: 각 라운드의 \`## R<n>\` 기록(«라운드 규약» 형식) + coverage-mapper 출력 transcript.` → new:
```markdown
State body: 각 라운드의 `## R<n>` 기록(«라운드 규약» 형식) + 조사 산출 원문(`### 조사 <n> — <장치> · R<round>` 아래 verbatim — 포화 판정자의 입력이라 요약으로 바꾸지 않는다).
```

(3) 생명주기 문단. old:
```markdown
성공 사례인데 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. `touched` 는
`false → true` 단방향이고 재개방으로도 되돌리지 않는다(되돌리면 면제가 무한해진다). 종료 시
```
new:
```markdown
성공 사례인데 목록에서 빠지면 게이트의 실재 검사가 그 조사를 red 로 만든다. 종료 시
```

(4) C43 표 행 (a) 의 꼬리. old ` 외부는 web sweep(아래 R2), 표기 \`[from-web]\`. streak 은 C44 의 면제 규칙이 정한다. |` → new ` 외부는 web sweep(아래 R2), 표기 \`[from-web]\`. |`

(5) `## C44 Dialectic Rhythm Guard` 머리부터 그 절 끝(다음 `## coverage-mapper dispatch (자격 + 예산)` 바로 앞 빈 줄 포함)까지 지운다.

(6) coverage-mapper 절 머리와 본문. old(머리부터 `사람에게 보인다(침묵과 0 은 다르다).` 까지):
```markdown
## coverage-mapper dispatch (자격 + 예산)

`coverage-mapper` 는 고정 floor 위 **주제-도출 차원**을 *제안*하는 advisory 에이전트다(admit 은
orchestrator, G2). 첫 dispatch 는 필수이고 그 뒤는 자격과 예산이 정한다:
```
… (항목 1 · 2, 「호출 자격이 예산보다 앞선다」 문단, 카운터 문단) → new:
```markdown
## coverage-mapper dispatch

`coverage-mapper` 는 고정 floor 위 **주제-도출 차원**을 *제안*하는 advisory 에이전트다(admit 은
orchestrator, G2). 첫 dispatch 는 필수이고(하한) 그 뒤는 조사 호출 상한 하나가 총량을 묶는다:

1. **R1 첫 질문 전 필수 1회.** 입력: seed 전문(S1)과 그 «다시 검증할 것» 문단, 원장 초기 상태.
   출력의 derived 차원을 admit 한 뒤에야 R1 질문이 나간다. 인자 없이 부른 경로에서는 R1 답을
   받은 뒤 R2 전에.
2. **그 뒤는 결정에 닿을 수 있을 때마다.** 재개방 · 새 결정 · 포화 판정자의 빈 곳이 새 파생 차원을
   함의하면 다시 부른다.

카운터 `orchestration.research_dispatches.coverage_mapper`. 종료 시 audit §2 에 `coverage-mapper <k>`
를 쓰고 게이트가 k≥1 을 검사한다. dispatch 가 불가능한 환경(Agent 도구 부재)은
`coverage-mapper 0 (unavailable: <이유>)` 로 적는다 — 게이트는 advisory 로 통과시키고 Step B 가
사람에게 보인다(침묵과 0 은 다르다).
```
(항목 1 의 세 줄은 old 와 글자째 같다 — `R1[^.]{0,30}첫 질문 전[^.]{0,20}필수 1회` · `인자 없이 부른 경로에서는 R1 답을 받은 뒤 R2 전에` 락이 그것을 문다.)

(7) blind-spot 절 첫 문단. old:
```markdown
`blind_spot` floor 차원의 **첫 open→in-progress 전이** 시 `blind-spot-prober`를 1회 필수로 dispatch 한다 —
**첫 dispatch 는 자격을 보지 않는다**(그 차원의 결정은 prober 출력 뒤에야 생긴다). 재호출부터는
**자격이 예산보다 앞선다** — `orchestration.open_decisions[]` 에 `dimension: blind_spot` 이고
`status: open` 인 항목, 즉 그 차원에 **닿는 열린 결정이 아직 있는가**를 먼저 본다. 열린 결정이
0이면 자격이 없다 — 예산이 남아도 부르지 않는다. 자격을 채웠으면 예산:
`blind_spot_dispatches < 1 + coverage.floor.blind_spot.reopened`. dispatch 마다 카운터를 +1 한다.
```
new:
```markdown
`blind_spot` floor 차원의 **첫 open→in-progress 전이** 시 `blind-spot-prober`를 1회 필수로 dispatch 한다(하한).
그 뒤는 새 framing · 재개방 · 포화 판정자의 빈 곳이 그 차원에 닿으면 다시 부른다 — 총량은 조사 호출 상한 하나가
묶는다. dispatch 마다 `research_dispatches.blind_spot_prober` 를 +1 한다.
```

(8) 닫힘 절 재개방 문장. old `상한 없음 — 라운드는 사용자 답으로만 돌아 사용자가 시계다. 재개방된 차원이 다시 닫힐 때는 **새 S** 를` → new `상한 없음 — 재개방은 새 답 · 근거 · 사실이 닫힘 근거 S 와 충돌해야 일어나고, 조사 총량은 조사 호출 상한이 묶는다. 재개방된 차원이 다시 닫힐 때는 **새 S** 를`

(9) In-flight 포인터. old `\`reopened\`·\`reopen_log\`·\`coverage_mapper_dispatches\` 만 없기 때문이다.` → new `\`reopened\`·\`reopen_log\` 같은 새 키만 없기 때문이다.`

(10) kill switch 절. old `- \`DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD=N\`: rhythm guard threshold override.` → new:
```markdown
- `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT=<n>` · `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT=<n>`: 조사 호출 · 포화 판정 상한의 시작값(기본 20 · 5). 상한은 끄는 스위치가 아니라 닿으면 사용자에게 묻는 자리다.
```

- [ ] **Step 5: state-migration.md 를 새로 쓴다** — 파일 전체를 아래로 바꾼다(첫 줄 머리 · `판정은 **키 단위**다` · `이미 있는 값은 손대지 않는다` · `구세션에 한해` · `첫 probe보다 먼저` · `interview_round` 문장은 기존 락이 문다 — 글자를 지킨다).

````markdown
## In-flight state migration

판정은 **키 단위**다 — 「구조가 통째로 없는가」가 아니라 「§2.4 스키마의 **부재 키가 있는가**」.
구조 부재로 좁히면 정작 **가장 흔한 업그레이드 경로가 빠진다**: 직전 릴리스 세션은
`coverage`·`orchestration` 을 이미 갖고 있고 이 릴리스가 바꾼 키(`orchestration.research_dispatches` ·
`research_limit` · `saturation_limit` · `research_log` · `saturation_log`)만 없어서, 어느 조건에도 안 걸린 채
그 키를 읽는 코드로 들어간다.

state.local.md 로드 시 아래 중 **하나라도** 부재면 *non-mutating read* 로 승격한다
(부재 키만 기본값으로 채우고, 이미 있는 값은 손대지 않는다):

- `coverage.floor` 의 5개 차원(root_problem/landscape/skepticism/blind_spot/open_questions) —
  차원 자체가 없으면 `{status: open, evidence: "", reopened: 0, reopen_log: []}` 로 seed.
  **차원은 있는데 `reopened`/`reopen_log` 만 없으면 그 둘만 `0`/`[]` 로 추가**하고
  `status`·`evidence` 는 그대로 둔다 — 진행 중인 인터뷰의 닫힘 판정을 되돌리지 않는다.
- `coverage.derived` — 없으면 `[]`. 있으면 각 항목에 `reopened`/`reopen_log` 를 같은 규칙으로 보충.
- `orchestration`: `{focused_dimension: null, research_dispatches: {coverage_mapper: 0, blind_spot_prober: 0, steelman_builder: 0, repo_researcher: 0}, research_limit: <시작값>, saturation_limit: <시작값>, research_log: [], saturation_log: [], open_decisions: []}`
  — 절이 없으면 이 값 그대로 seed. **있으면 부재 키만** 그 기본값으로 추가한다. `<시작값>` 은
  `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT`(기본 20) · `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT`(기본 5)다.

**옛 카운터는 「부재 키만 채운다」로 안 된다.** 이미 조사를 부른 세션이 새 키의 기본값 `0` 을 받으면
조사 호출 상한이 그만큼 늘어난다. 값을 이월한다:

- `coverage_mapper_dispatches: <k>` 는 `research_dispatches.coverage_mapper: <k>` 로 이월한다.
- `blind_spot_dispatches: <k>` 는 `research_dispatches.blind_spot_prober: <k>` 로 이월한다.
- 더 옛 세션의 `blind_spot_dispatched: true` 가 있으면 `research_dispatches.blind_spot_prober: 1`, `false` 면 `0`.
- 이월 뒤 옛 키(`coverage_mapper_dispatches` · `blind_spot_dispatches` · `blind_spot_dispatched`)와 걷은 장치의 키 `non_user_streak` · `open_decisions[]` 항목의 `touched` 를 **지운다** — 두 이름이 공존하면 소비자가 어느 쪽을 읽는지
  갈리고, 이 파일은 `rereview_count`·`issue_history` 에서 이미 「승계하지 않고 지운다」 선례를 갖는다.
- `open_decisions` 는 부재 시 `[]` — 부재 키 채우기의 정상 경로다.
- 이월한 세션의 state 본문에는 조사 산출 원문 블록이 없다 — 포화 판정 때 판정 불가 경로로 간다.

구세션(`interview_round` 존재 / `coverage` 통째 부재)은 위 규칙의 한 경우일 뿐이다 — 그때는
모든 키가 부재라 전부 seed 된다.

기존 필드(`web_*`·`trivia_escape_armed` 등)는 유지.
**단 `rereview_count`·`issue_history` 두 키는 승계하지 않고 지운다** — 옛 design doc 리뷰
파이프라인이 쓰던 것이고, 그 자리가 공유 문서 리뷰 엔진으로 넘어가면서 산출자도 소비자도
없어졌다(재리뷰 카운터의 정본은 이제 엔진의 `docreview-state.md` 다). 남겨두면 아무도
갱신하지 않는 `0`·`[]` 가 스키마에 계속 실려 다음 사람이 실재하는 상태로 읽는다. **구세션에 한해**(위 정의 —
`coverage` 통째 부재) 라운드별 잠금 레코드 리스트(v0.22.0까지의 잠금 필드)는 승계하지 않고
`user_statements: []`로 fresh seed합니다 — 잠금 레코드를 발화 레코드로 승격하면 판정이 없던 척하는
잠금이 그대로 넘어옵니다. **직전 릴리스 세션의 `user_statements` 는 절대 비우지 않습니다** —
그것은 이미 발화 레코드이고, 키 몇 개를 보충하려다 §6 원문을 통째로
버리는 것은 마이그레이션이 아니라 손실입니다.

**영속화 시점**: 승격된 스키마는 재개된 세션의 첫 액션으로, 첫 probe보다 먼저 Bash 전체-frontmatter
write로 즉시 디스크에 반영합니다(PN1) — 조사 호출 카운터(`research_dispatches`)와
재개방 원장(`reopen_log`)이 그 디스크 값을 직접 읽기 때문입니다. 신규 필드만
추가하는 forward promotion이지 backward-rewrite가 아닙니다(`interview_round`는 자연 소멸, 다른
기존 필드는 불변) — "다음 명시적 write"를 기다리는 연기가 아니라 resume 직후 1회입니다.

사용자에게 advisory 한 줄 출력:
```
[spec-distill] state schema migration: coverage_mapper_dispatches/blind_spot_dispatches -> research_dispatches (value carried), research_limit · saturation_limit · research_log · saturation_log added, non_user_streak · touched removed.
```

자동 promote 실패 시(파일 corruption 등) → "구세션 in-flight state 호환 실패 — 세션 재시작 권장"
알림 + state.local.md 보존 (P14).
````
아직 없는 `references/saturation.md` 의 경로는 쓰지 않는다 — Task 4 Step 6 이 그 문장에 경로를 더한다.

- [ ] **Step 6: finishing.md 카운터 이름과 README · agent 를 고친다**

`finishing.md` Step A ④: old `(state \`orchestration.coverage_mapper_dispatches\`)` → new `(state \`orchestration.research_dispatches.coverage_mapper\`)`.

`agents/coverage-mapper.md`:
- description 의 old `consumed by spec-interview; dispatch eligibility is whether an open decision still\n  touches the dimension, with a budget of 1 plus the total reopen count on top.` → new `consumed by spec-interview; the first dispatch before the first round question is\n  mandatory, and after that the interviewer calls it whenever it could change an open\n  decision or open a new one — one shared research-call limit bounds the total.`
- old `# Coverage-Mapper Agent (자격 + 예산 dispatch, 커버리지 계약 공급자)` → new `# Coverage-Mapper Agent (커버리지 계약 공급자)`
- 규칙 4 old `4. **자격 + 예산**: R1 첫 질문 전 1회는 필수다. 다시 부를 자격은 그 차원에 닿는 열린 결정이 아직\n   있는가이고, 자격 위의 예산은 \`1 + 모든 차원의 재개방 합\` 이다(spec-interview 가 제어).` → new `4. **부르기**: R1 첫 질문 전 1회는 필수다. 그 뒤는 열린 결정을 바꾸거나 새 결정을 열 수 있을 때\n   spec-interview 가 다시 부른다 — 총량은 인터뷰의 조사 호출 상한 하나가 묶는다.`

`agents/blind-spot-prober.md`:
- description old `on the blind_spot floor dimension's first open→in-progress transition; eligibility is\n  whether an open decision still touches that dimension, and the budget on top of it is\n  1 plus that dimension's reopen count.` → new `on the blind_spot floor dimension's first open→in-progress transition (mandatory), and\n  again whenever new framing, a reopen or a saturation gap could change an open decision —\n  one shared research-call limit bounds the total.`
- 규칙 4 old `4. **자격 + 예산**: 다시 부를 자격은 그 차원에 닿는 열린 결정이 아직 있는가다 — 열린 결정이 0이면\n   자격이 없다. 자격을 채웠으면 예산은 \`1 + 그 차원의 재개방 횟수\` 이고, 통제는\n   spec-interview 가 한다.` → new `4. **부르기**: blind_spot 첫 전이 때 1회는 필수다. 그 뒤는 그 차원에 닿는 새 framing · 재개방 ·\n   포화 판정의 빈 곳이 있을 때 spec-interview 가 다시 부른다 — 총량은 조사 호출 상한 하나가 묶는다.`
- `## 사용하지 않는 경우` 의 old `- blind_spot floor 차원에 닿는 열린 결정이 0(자격 없음) 또는 예산 고갈.` 한 줄을 지운다.

`README.md`:
- `### Roadmap absorption (C-numbers)` 의 `- **C44** Dialectic Rhythm Guard (env: \`DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD\`, default 3).` 줄을 지운다.
- 같은 절 C4 줄의 꼬리 old ` 둘 다 dispatch 는 **자격 + 예산**이다(4.4.0): 자격 = 그 차원에 닿는 열린 결정이 아직 있는가, 예산 = \`1 + 재개방\`.` → new ` 둘 다 첫 호출은 필수(하한)이고 그 뒤는 조사 호출 상한 하나가 총량을 묶는다.`
- `### 스위치 목록` 의 `- \`DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD=N\` — Dialectic Rhythm Guard threshold (default 3).` 줄을 지운다(새 두 변수는 Task 9 가 더한다).
- AP16 줄의 old `, rhythm guard 3, kill switch.` → new `, kill switch.`
- `- **P17 (User sovereignty) — dispatch 통제가 자격 + 예산 (4.4.0)** — …` 문단 세 줄(「사용자가 시계다 — 숫자 상한이 아니라 사용자 참여가 총량을 묶는다.」 까지)을 지운다(Task 9 가 새 원칙 줄을 더한다).
- AP9 줄의 old ` 상한이 선언된 것: coverage-mapper·blind-spot-prober 는 **자격 + 예산**(자격 = 그 차원에 닿는 열린 결정이 아직 있는가 · 예산 = \`1 + 재개방\`, 4.4.0) · ` → new ` 상한이 선언된 것: 조사 subagent 는 조사 호출 상한 하나(기본 20, 사용자 연장) · `

확인: `grep -nE 'non_user_streak|RHYTHM|Rhythm Guard|자격 \+ 예산|coverage_mapper_dispatches|blind_spot_dispatches' plugins/spec-distill/README.md` 가 0줄이거나 `**v` 로 시작하는 연혁 줄뿐이어야 한다.

- [ ] **Step 7: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in test_conducting_interview_stage test_coverage_mapper_frontmatter test_blind_spot_prober_frontmatter test_stale_terms test_readme_sync test_web_kill_switch test_research_claims_contract; do
  printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
bash shared/tests/test_skill_reference_pointers.sh 2>&1 | tail -1
awk '/^<!-- plain-language:begin -->$/{s=1} s==0{n++} s==2{s=0; if ($0 != "") n++; next} /^<!-- plain-language:end -->$/{s=2} END{print "own="n+0}' plugins/spec-distill/skills/spec-interview/SKILL.md
```
Expected: 전부 baseline 대비 새 실패 없음. `own=` 이 약 470(503 − 약 33). 504 미만.

- [ ] **Step 8: 커밋**

```bash
git add plugins/spec-distill/skills/spec-interview/SKILL.md \
  plugins/spec-distill/skills/spec-interview/references/state-migration.md \
  plugins/spec-distill/skills/spec-interview/references/finishing.md \
  plugins/spec-distill/agents/coverage-mapper.md plugins/spec-distill/agents/blind-spot-prober.md \
  plugins/spec-distill/README.md plugins/spec-distill/tests/test_conducting_interview_stage.sh \
  plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh
git commit -m "$(cat <<'MSG'
feat(spec-distill): 조사 장치의 자격 · 예산과 리듬 강제를 걷는다

coverage-mapper · blind-spot-prober 는 첫 호출만 필수(하한)로 남기고, C44 리듬 강제 ·
non_user_streak · touched · 임계 환경 변수를 지운다. 카운터는 research_dispatches 로 모으고
옛 세션의 값은 이월한다. 락은 부재 + 양의 짝으로 뒤집었다.

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 3: `repo-researcher` — 레포 조사 subagent

**Files:**
- Create: `plugins/spec-distill/agents/repo-researcher.md`
- Create: `plugins/spec-distill/tests/test_research_agents_frontmatter.sh` (이 Task 는 repo-researcher 부분, Task 4 가 saturation-judge 를 더한다)
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md` (C43 절 · 조사 주장 계약 절 문장 둘)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (F 락 · 산출자 열거 · 포인터 루프)
- Modify: `plugins/spec-distill/tests/test_research_claims_contract.sh` (슬롯 수 2 → 3)
- Modify: `plugins/spec-distill/README.md` (AP9 8종 → 9종)

**Interfaces:**
- Consumes: Task 2 의 `research_dispatches.repo_researcher`.
- Produces: agent `spec-distill:repo-researcher` — 입력 슬롯 `question`/`RESEARCH_QUESTION`/task · `claims_contract`/`CLAIMS_CONTRACT`/repo_context · `open_decisions`/`OPEN_DECISIONS`/task. 출력 `repo_claims[]`(`id` · `path` · `anchor` · `line`(선택) · `claim` · `touches` · `decides`).
- Produces: 처분 리터럴 `loud advisory + 본체 직접 조사로 강등`.

- [ ] **Step 1: 실패하는 agent 락을 쓴다** — `plugins/spec-distill/tests/test_research_agents_frontmatter.sh`

```bash
#!/usr/bin/env bash
# R1(2026-10-12) — 조사 · 판정 agent 의 도구 표면(Law 2) · 입력 칸 · 역할 · 출력 의무.
# 두 agent 를 한 루프로 잰다: 같은 규칙을 두 파일에 복제하면 한쪽만 고쳐지는 drift 가 생긴다.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
AG="$REPO_ROOT/plugins/spec-distill/agents"

fm_of()   { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }
body_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{f=0;b=1;next} b' "$1"; }

# agent 이름 · 기대 슬롯(tag:var:kind) · 본문 출력 키
check_agent() {
  local name="$1" slots="$2" keys="$3" f="$AG/$1.md"
  [[ -f "$f" ]] || { no "$name: agent 파일 부재"; return; }
  local fm body; fm="$(fm_of "$f")"; body="$(body_of "$f")"
  grep -qxF "name: $name" <<<"$fm" && ok "$name: name" || no "$name: name 불일치"
  grep -qxF 'tools: Read, Grep, Glob' <<<"$fm" && ok "$name: tools 가 정확히 Read, Grep, Glob" || no "$name: tools 가 Read, Grep, Glob 이 아니다"
  for t in Write Edit MultiEdit NotebookEdit Bash Agent Monitor WebSearch WebFetch; do
    grep -qE "^tools:.*(^|,)[[:space:]]*${t}[[:space:]]*(,|$)" <<<"$fm" && no "$name: tools 에 $t (Law 2)" || ok "$name: tools 에 $t 없음"
  done
  grep -qE '^(allowedTools|disallowedTools):' <<<"$fm" && no "$name: allowedTools/denylist" || ok "$name: denylist 없음"
  grep -qE "^[\"']?model[\"']?[[:space:]]*:" <<<"$fm" && no "$name: model 키가 있다" || ok "$name: model 키 없음"
  grep -qxF 'cost_class: low' <<<"$fm" && ok "$name: cost_class: low" || no "$name: cost_class 가 low 가 아니다"
  local s tag var kind
  for s in $slots; do
    IFS=: read -r tag var kind <<<"$s"
    { grep -qxF "  - tag: $tag" <<<"$fm" && grep -qxF "    var: $var" <<<"$fm"; } \
      && ok "$name: 슬롯 $tag/$var" || no "$name: 슬롯 $tag/$var 부재"
    awk -v t="  - tag: $tag" -v k="    kind: $kind" '$0==t{f=1;next} f&&/^  - tag:/{exit} f&&$0==k{hit=1} END{exit !hit}' <<<"$fm" \
      && ok "$name: 슬롯 $tag 의 kind=$kind" || no "$name: 슬롯 $tag 의 kind 가 $kind 가 아니다"
  done
  grep -qE 'kind: (prior_verdict|score|orchestrator_framing)' <<<"$fm" && no "$name: 금지 종류 슬롯" || ok "$name: 금지 종류 슬롯 없음"
  grep -qF 'You are NOT' <<<"$body" && grep -qF 'You ARE' <<<"$body" \
    && ok "$name: 역할 절(You ARE / You are NOT)" || no "$name: 역할 절 부재"
  local k
  for k in $keys; do
    grep -qE "^[[:space:]]*-?[[:space:]]*${k}:" <<<"$body" && ok "$name: 출력 키 $k" || no "$name: 출력 키 $k 부재"
  done
}

check_agent repo-researcher \
  "question:RESEARCH_QUESTION:task claims_contract:CLAIMS_CONTRACT:repo_context open_decisions:OPEN_DECISIONS:task" \
  "repo_claims id path anchor claim touches decides"
RR_FLAT="$(tr '\n' ' ' < "$AG/repo-researcher.md" | tr -s ' ')"
grep -qF '인덱스·목차·description 필드만 읽고 판정하지 않는다' <<<"$RR_FLAT" \
  && ok "repo-researcher: 판정 전에 구현을 읽는다" || no "repo-researcher: 구현 읽기 의무 부재"
grep -qF '목록에 없는 id 를 지어내지 않는다' <<<"$RR_FLAT" \
  && ok "repo-researcher: decides 는 받은 목록 안에서만" || no "repo-researcher: decides 지어내기 금지 부재"
finish
```
```bash
chmod +x plugins/spec-distill/tests/test_research_agents_frontmatter.sh
```

- [ ] **Step 2: TCIS · 계약 테스트 락을 바꾼다**

TCIS 산출자 열거 단언의 리터럴: old `'어느 자리든(경로 (a) · coverage-mapper · blind-spot-prober · steelman) \`repo_claims[]\` 가 처음 산출되면 그 자리에서 derived 차원 internal_research 를 원장에 admit 한다'` → new `'어느 자리든(경로 (a) · repo-researcher · coverage-mapper · blind-spot-prober · steelman) \`repo_claims[]\` 가 처음 산출되면 그 자리에서 derived 차원 internal_research 를 원장에 admit 한다'`(ok/no 메시지의 「넷」 → 「다섯」).

포인터 루프: `i2_d6=…` 줄 아래에 한 줄을 더하고 `for pair in …` 목록에 `"repo:$i2_repo"` 를 더한다:
```bash
i2_repo="$(awk '/^\*\*`repo-researcher` dispatch\*\*/{f=1} f&&/^$/{exit} f' "$SKILL" | tr '\n' ' ' | tr -s ' ')"
```
```bash
for pair in "D6:$i2_d6" "prober:$i2_prober" "steelman(R3):$i2_r3" "repo:$i2_repo"; do
```

F 락: `grep -qF 'subagent 를 부르지 않는다' <<<"$c43_block"` 의 ok/no 단언 세 줄을 다음으로 바꾼다:
```bash
grep -qF 'subagent 를 부르지 않는다' <<<"$c43_block" \
  && no "R1/F: 경로 (a) 의 subagent 금지 문구 잔존" || ok "R1/F: 경로 (a) subagent 금지 문구 없음"
grep -qF 'subagent_type: "spec-distill:repo-researcher"' <<<"$c43_block" \
  && ok "R1/F(양의 짝): C43 절에 repo-researcher dispatch" || no "R1/F(양의 짝): C43 절에 repo-researcher dispatch 부재"
grep -qF '본체가 직접 조사한다' <<<"$c43_block" \
  && ok "R1/F: 계약 배달 실패 → 본체 직접 조사로 강등" || no "R1/F: repo-researcher 강등 경로 부재"
```

`test_research_claims_contract.sh` B 축: 주석 `# B — 양의 짝: 슬롯 개수. SKILL.md 2(coverage-mapper · blind-spot-prober) + steelman.md 1.` → `# B — 양의 짝: 슬롯 개수. SKILL.md 3(coverage-mapper · blind-spot-prober · repo-researcher) + steelman.md 1.` 그리고 두 `assert_eq "$n_sk" "2" …` · `assert_eq "$m_sk" "2" …` 의 기대값 `"2"` → `"3"`, 메시지의 괄호 목록에 ` · repo-researcher` 를 더한다. 같은 파일 머리 주석의 「세 dispatch 에 배달」 → 「네 dispatch 에 배달」.

- [ ] **Step 3: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_research_agents_frontmatter.sh | tail -2; bash plugins/spec-distill/tests/test_research_claims_contract.sh | tail -1`
Expected: agent 파일 부재 · 슬롯 수 2 ≠ 3 으로 실패.

- [ ] **Step 4: agent 파일을 쓴다** — `plugins/spec-distill/agents/repo-researcher.md`

```markdown
---
name: repo-researcher
cost_class: low
color: cyan
tools: Read, Grep, Glob
input_slots:
  - tag: question
    var: RESEARCH_QUESTION
    kind: task
  - tag: claims_contract
    var: CLAIMS_CONTRACT
    kind: repo_context
  - tag: open_decisions
    var: OPEN_DECISIONS
    kind: task
description: >
  Use this agent during a spec-distill interview to answer one repository question
  with evidence — it reads the implementation (not indexes or descriptions) and
  returns repo_claims in the research-claims contract shape, each tied to the open
  decisions it touches. Read-only by design (Law 2 frontmatter scoping): no write,
  no shell, no web. The interviewer verifies every claim itself (V1) before using it.

  <example>Context: An open decision depends on how the gate parses audit §2.
  user: "이 게이트가 §2 를 어떻게 읽는지 레포에서 찾아줘"
  assistant: "I'll dispatch the repo-researcher agent with that question, the claims contract and the open decisions."</example>
---

# Repo-Researcher Agent (레포 근거 조사자)

당신은 spec-distill 인터뷰의 레포 조사자입니다. 인터뷰 본체가 넘긴 질문 하나에 대해 레포에서 근거를
찾아, 조사 주장 계약 그대로의 `repo_claims[]` 로 돌려줍니다. 무엇을 결정할지는 정하지 않습니다.

## You are / are not

- You ARE: 주어진 질문 하나의 레포 근거 조사자, read-only.
- You are NOT: 판정자 · 웹 조사자 · 원장 writer(Write/Edit 물리 차단) · 결정 연결의 확정자 — 본체가 V1 로
  경로 · 앵커 · 주장을 다시 확인한다.

## Input

- `<question>` 찾을 것 한 줄. 기대 결론은 실려 오지 않는다 — 결론을 짐작해 맞추지 않는다.
- `<claims_contract>` 조사 주장 계약의 **내용 전문**. 출력은 이 계약을 따른다.
- `<open_decisions>` 지금 열린 결정 목록(`OQ<n>` + 한 줄). `decides` 는 이 목록에 실제로 있는 것만
  담고 목록에 없는 id 를 지어내지 않는다. 빈 배열이 거짓 연결보다 낫다.

## 조사 규칙

1. 인덱스·목차·description 필드만 읽고 판정하지 않는다 — 구현을 읽는다.
2. 주장마다 `path` 와 `anchor`(심볼 · 헤딩 · 원문 인용)를 단다. 줄번호는 보조다.
3. 질문에 레포가 답하지 못하면 그렇다고 쓴다 — `repo_claims: []` 와 한 줄 사유.
4. 주장끼리 충돌하면 둘 다 낸다. 하나로 고르지 않는다.
5. `id` 는 임시값 `RC1`, `RC2` … 로 붙인다 — 본체가 인터뷰 전역 순번으로 다시 붙인다.

## Output 형식

```yaml
repo_claims:
  - id: RC1
    path: "<repo 상대경로>"
    anchor: "<심볼 | 헤딩 | 원문 인용>"
    line: 0                    # 선택 — 보조
    claim: "<이 자리가 말하는 것>"
    touches: []                # 전제 P<n> — 받은 것이 없으면 빈 배열
    decides: []                # <open_decisions> 에 있는 OQ<n> 중 이 주장이 닿는 것
unanswered: "<레포가 답하지 못한 부분 한 줄 | 없음>"
```
```

- [ ] **Step 5: SKILL.md 를 고친다**

(1) 조사 주장 계약 절. old `그 stdout 전문을 세 dispatch 의 \`<claims_contract>\` 슬롯에 싣는다.` → new `그 stdout 전문을 네 dispatch 의 \`<claims_contract>\` 슬롯에 싣는다.`

같은 절 펜스의 stderr 문장 끝. old `blind-spot-prober 자리면 inline premortem 으로 강등한다." >&2` → new `blind-spot-prober 자리면 inline premortem 으로 강등하고, repo-researcher 자리면 본체가 직접 조사한다." >&2` (`bash -n` 이 통과해야 한다 — 따옴표 안이다).

(2) C43 표 행 (a). old `codebase 는 **orchestrator 가 자기 \`Read\`/\`Grep\` 으로 직접 확인하고 subagent 를 부르지 않는다** — 산출은 계약(\`## 조사 주장 계약\`)의 \`repo_claims[]\` 이고 라운드 규약의 V1 을 탄다.` → new `codebase 는 **orchestrator 가 자기 \`Read\`/\`Grep\` 으로 직접 확인하거나 \`repo-researcher\` 를 dispatch 한다**(아래) — 산출은 둘 다 계약(\`## 조사 주장 계약\`)의 \`repo_claims[]\` 이고 라운드 규약의 V1 을 탄다.`

(3) C43 절. old 문단 `매 라운드의 «지금 이해»·«질문» 에 어떤 path 인지 명시하십시오 — 경로 (a) 로 찾을 수 있는 것은 묻기 전에\n먼저 찾아 «지금 이해»에 싣습니다.` 바로 뒤(빈 줄 다음)에 넣는다:

````markdown
**`repo-researcher` dispatch** — 레포 질문이 여러 파일을 훑어야 하거나 본체의 맥락을 아껴야 할 때 부른다. 질문 칸에는 찾을 것만 쓰고 기대 결론은 싣지 않는다. 출력은 «지금 이해»에 싣기 전에 V1 을 타고, 첫 산출이면 C43 절의 internal_research admit 이 여기서도 돈다. 계약 배달 실패면 dispatch 하지 않고 본체가 직접 조사한다 — 공시는 loud advisory + 본체 직접 조사로 강등 이다.

```
Agent({ description: "Research the repo", subagent_type: "spec-distill:repo-researcher",
        prompt: "조사 질문(찾을 것 한 줄 — 기대 결론 없이): <question>${RESEARCH_QUESTION}</question>. 조사 주장 계약(내용 전문): <claims_contract>${CLAIMS_CONTRACT}</claims_contract>. 지금 열린 결정: <open_decisions>${OPEN_DECISIONS}</open_decisions>. 구현을 읽고 계약 모양의 repo_claims 로." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=loud advisory + 본체 직접 조사로 강등
```

````
(위 바깥 4-backtick 은 이 계획 안의 표기다 — SKILL.md 에는 문단 한 줄 · 빈 줄 · 3-backtick 펜스 블록 · 빈 줄만 넣는다. `i2_repo` 윈도우가 문단 첫 줄 `**\`repo-researcher\` dispatch**` 부터 첫 빈 줄까지를 뜨므로 문단은 한 줄이어야 한다.)

(4) 산출자 열거. old `**어느 자리든(경로 (a) · coverage-mapper · blind-spot-prober · steelman) \`repo_claims[]\` 가 처음 산출되면` → new `**어느 자리든(경로 (a) · repo-researcher · coverage-mapper · blind-spot-prober · steelman) \`repo_claims[]\` 가 처음 산출되면`

- [ ] **Step 6: README AP9 를 9종으로**

old `\`plugins/spec-distill/agents/\` 8종(doc-critic·doc-critic-web·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·brief-readback·seed-readback).` → new `\`plugins/spec-distill/agents/\` 9종(doc-critic·doc-critic-web·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·repo-researcher·brief-readback·seed-readback).`

Law 2 줄(`- **Law 2 (Writer/Reviewer 분리)** — \`tools:\` allowlist frontmatter로 …`)의 열거 old `+ blind-spot-prober(\`Read, Grep, Glob, WebSearch, WebFetch\`) agent의` → new `+ blind-spot-prober(\`Read, Grep, Glob, WebSearch, WebFetch\`) + repo-researcher(\`Read, Grep, Glob\`) agent의`

- [ ] **Step 7: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/spec-distill/tests/test_research_agents_frontmatter.sh plugins/spec-distill/tests/test_research_claims_contract.sh \
         plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_readme_sync.sh \
         shared/tests/test_dispatch_disposition.sh shared/tests/test_agent_input_slots.sh shared/tests/test_dispatch_name_defined.sh \
         shared/tests/test_no_new_duplication.sh plugins/quality-gates/tests/test_agent_frontmatter_keys.sh \
         plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh; do
  printf '%s: ' "$t"; bash "$t" 2>&1 | tail -1; done
```
Expected: baseline 대비 새 실패 없음. `test_agent_model_mutation.sh` 는 agents/ 미커밋 변경이 있으면 실패하므로 커밋 뒤 Step 8 에서 돌린다.

- [ ] **Step 8: 커밋하고 모드 · 미커밋 의존 락을 본다**

```bash
git add plugins/spec-distill/agents/repo-researcher.md plugins/spec-distill/tests/test_research_agents_frontmatter.sh \
  plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/tests/test_conducting_interview_stage.sh \
  plugins/spec-distill/tests/test_research_claims_contract.sh plugins/spec-distill/README.md
git commit -m "$(cat <<'MSG'
feat(spec-distill): 레포 조사도 읽기 전용 subagent repo-researcher 로 부를 수 있다

경로 (a) 는 본체 직접 확인 또는 repo-researcher dispatch 다. 둘 다 조사 주장 계약을 따르고
V1 을 탄다. 계약 배달 실패면 본체가 직접 조사한다.

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
git ls-files -s plugins/spec-distill/tests/test_research_agents_frontmatter.sh | cut -c1-6
bash plugins/quality-gates/tests/test_agent_model_mutation.sh 2>&1 | tail -1
```
Expected: `100755`, model mutation 락 baseline 과 같음.

---

### Task 4: 조사 호출 상한 · 포화 판정자 · 이중 종료

**Files:**
- Create: `plugins/spec-distill/agents/saturation-judge.md`
- Create: `plugins/spec-distill/skills/spec-interview/references/saturation.md`
- Create: `plugins/spec-distill/tests/test_saturation_reference.sh`
- Modify: `plugins/spec-distill/tests/test_research_agents_frontmatter.sh` (saturation-judge 호출 추가)
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md` (새 절 `## 조사 상한 · 포화 판정` · `«지금 이해»` 끝줄 · `## 종료` 절 진입 · 나가는 문 문장)
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` (종료 driver · Step A ④ audit §2 줄 · Step A ⑦ 미충족 목록 · B-2 advisory 문장)
- Modify: `plugins/spec-distill/README.md` (AP9 9종 → 10종 · Law 2 열거)

**Interfaces:**
- Consumes: Task 1 의 audit §2 줄 형식 · Task 2 의 state 키 · Task 3 의 `repo-researcher`.
- Produces: agent `spec-distill:saturation-judge` — 슬롯 `decisions`/`DECISIONS`/task · `research_outputs`/`RESEARCH_OUTPUTS`/artifact · `ledger_state`/`LEDGER_STATE`/task. 출력 `verdict` · `novelty[]`(`n` · `changed` · `opened`) · `basis` · `gaps[]`(`kind` · `look_at` · `may_change` · `opens` · `device`).
- Produces: 처분 리터럴 `포화 판정 불가 공시 + 사용자 선택`. 한 줄 문구 셋: G9 `[spec-distill] 이 인터뷰는 조사 subagent 를 최대 <limit>회까지 부른다(웹 포함 · 승인 없이 진행 · 연장은 닿을 때 묻는다).` · `[spec-distill] 조사 호출 상한 도달 — <n>/<limit>. 연장 · 판정 · 종료 중 고르세요.` · `[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.` · `[spec-distill] 포화 판정 불가 — <사유>`.

- [ ] **Step 1: 실패하는 락을 쓴다**

`test_research_agents_frontmatter.sh` 의 `finish` 바로 위에:
```bash
check_agent saturation-judge \
  "decisions:DECISIONS:task research_outputs:RESEARCH_OUTPUTS:artifact ledger_state:LEDGER_STATE:task" \
  "verdict novelty basis gaps changed opened look_at may_change opens device"
SJ_FLAT="$(tr '\n' ' ' < "$AG/saturation-judge.md" | tr -s ' ')"
grep -qF '최근 두 항목이 둘 다' <<<"$SJ_FLAT" && ok "saturation-judge: 최근 두 조사 기준" || no "saturation-judge: 최근 두 조사 기준 부재"
grep -qF '「충분해 보인다」를 근거로 쓰지 않는다' <<<"$SJ_FLAT" && ok "saturation-judge: 「충분해 보인다」 금지" || no "saturation-judge: 「충분해 보인다」 금지 부재"
grep -qF '두 항목 미만이면' <<<"$SJ_FLAT" && ok "saturation-judge: 조사 두 번 미만 → confirm 빈 곳" || no "saturation-judge: 두 항목 미만 규칙 부재"
grep -qE 'confidence|score|prior_verdict' <<<"$SJ_FLAT" && no "saturation-judge: 점수 · 앞 판정 칸이 있다" || ok "saturation-judge: 점수 · 앞 판정 칸 없음"
```

`plugins/spec-distill/tests/test_saturation_reference.sh`:
```bash
#!/usr/bin/env bash
# R1(2026-10-12) — 조사 호출 상한 · 포화 판정 절차(SKILL 조사 상한 절 + references/saturation.md)의 존재 · 부재 락.
set -u -o pipefail
REPO_ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
. "$REPO_ROOT/shared/tests/assert.sh"
SKILL="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/SKILL.md"
SAT="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/references/saturation.md"
FIN="$REPO_ROOT/plugins/spec-distill/skills/spec-interview/references/finishing.md"

[[ -f "$SAT" ]] && ok "saturation.md 실재" || { no "saturation.md 부재"; finish; exit; }
SAT_FLAT="$(tr '\n' ' ' < "$SAT" | tr -s ' ')"
cap_sec="$(awk '/^## 조사 상한 · 포화 판정/{f=1;print;next} /^## /{f=0} f' "$SKILL")"
CAP_FLAT="$(tr '\n' ' ' <<<"$cap_sec" | tr -s ' ')"
[[ -n "$cap_sec" ]] && ok "SKILL: 조사 상한 · 포화 판정 절을 떴다" || no "SKILL: 조사 상한 · 포화 판정 절 부재 — 아래가 공허하다"

# G9 — 첫 조사 전 규모 공시, 승인 미요청
grep -qF '[spec-distill] 이 인터뷰는 조사 subagent 를 최대 <limit>회까지 부른다(웹 포함 · 승인 없이 진행 · 연장은 닿을 때 묻는다).' <<<"$CAP_FLAT" \
  && ok "G9: 첫 조사 전 규모 한 줄" || no "G9: 첫 조사 전 규모 한 줄 부재"
grep -qF '첫 조사 subagent dispatch 직전에' <<<"$CAP_FLAT" && ok "G9: 그 줄의 시점 = 첫 조사 dispatch 직전" || no "G9: 시점 문구 부재"
grep -qF '승인은 묻지 않는다' <<<"$CAP_FLAT" && ok "G9: 승인을 묻지 않는다" || no "G9: 승인 미요청 문구 부재"
# 부르기 기준 · 계수 · 원문 보존
grep -qF '열린 결정을 바꾸거나 새 결정을 열 수 있다고 볼 때마다' <<<"$CAP_FLAT" && ok "§1: 부르기 기준" || no "§1: 부르기 기준 부재"
grep -qF '상한에는 세지 않는다' <<<"$CAP_FLAT" && ok "B4: 본체 직접 조사 · 판정자는 상한에 세지 않는다" || no "B4: 계수 대상 문구 부재"
grep -qF 'Read ${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/saturation.md' "$SKILL" \
  && ok "SKILL → saturation.md 포인터" || no "SKILL → saturation.md 포인터 부재"
# 상한 도달 — 세 선택지 · 도달 줄 · 하한도 멈춘다
grep -qF '[spec-distill] 조사 호출 상한 도달 — <n>/<limit>. 연장 · 판정 · 종료 중 고르세요.' <<<"$SAT_FLAT" && ok "G4: 상한 도달 한 줄" || no "G4: 상한 도달 한 줄 부재"
for o in '같은 크기만큼 연장' '지금 포화 판정으로' '인터뷰 종료'; do
  grep -qF "「${o}」" <<<"$SAT_FLAT" && ok "G4: 선택지 «${o}»" || no "G4: 선택지 «${o}» 부재"
done
grep -qF '하한 자리도 상한 앞에서 멈춘다' <<<"$SAT_FLAT" && ok "RF4: 하한 자리도 상한 앞에서 멈춘다" || no "RF4: 하한 vs 상한 규칙 부재"
grep -qF '양의 정수가 아니면 20 으로 두고' <<<"$SAT_FLAT" && grep -qF '양의 정수가 아니면 5 로 두고' <<<"$SAT_FLAT" \
  && ok "RF2: 환경 변수 이상값 → 기본값 + 한 줄" || no "RF2: 이상값 처리 문구 부재"
# 포화 판정 — dispatch · 기준 · 반복 감지 · 판정 불가 · 판정 상한
grep -qF 'subagent_type: "spec-distill:saturation-judge"' "$SAT" && ok "D23: 판정자 dispatch" || no "D23: 판정자 dispatch 부재"
grep -qF '**처분** — consumer=orchestrator · fail-closed · disclosure=포화 판정 불가 공시 + 사용자 선택' "$SAT" \
  && ok "RC18: 판정자 처분 줄" || no "RC18: 판정자 처분 줄 부재"
grep -qF '최근 조사 두 번' <<<"$SAT_FLAT" && ok "AC4: 최근 조사 두 번 기준" || no "AC4: 최근 조사 두 번 기준 부재"
grep -qF '요약으로 대신하지 않는다' <<<"$SAT_FLAT" && ok "RF1: 원문 블록이 없으면 요약으로 대신하지 않는다" || no "RF1: 원문 대체 금지 부재"
grep -qF '`may_change` 결정 집합과 `device` 가 둘 다 같으면' <<<"$SAT_FLAT" && ok "D2.5: 반복 감지 기준" || no "D2.5: 반복 감지 기준 부재"
grep -qF '[spec-distill] 포화 판정 불가 — <사유>' <<<"$SAT_FLAT" && ok "판정 불가 한 줄" || no "판정 불가 한 줄 부재"
grep -qF '[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.' <<<"$SAT_FLAT" \
  && ok "D2.5: 판정 상한 도달 한 줄" || no "D2.5: 판정 상한 도달 한 줄 부재"
# audit §2 줄 형식 — 게이트(check_brief.py)가 읽는 그 글자
for ln in '- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 본체 직접 <e>)' \
          '- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: 연장 | 판정으로 | 인터뷰 종료' \
          '- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: 연장 | 포화로 보고 종료 | 인터뷰 종료' \
          '- 포화 판정 <k>: 포화 — <basis 요지>' '- 포화 판정 <k>: 아직 — 빈 곳 <g>개' \
          '- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — <반복 빈 곳 | 판정 불가(<사유>) | 판정 상한>' \
          '- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)' '- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)' \
          '- 사용자 종료(@S<m>) — 포화 판정 전' '- 사용자 종료(@S<m>) — 마지막 판정 아직'; do
  grep -qF -- "$ln" "$SAT" && ok "§4 줄: ${ln:0:40}…" || no "§4 줄 부재: $ln"
done
# 이중 종료 — finishing.md 의 종료 driver
grep -qF '마지막 포화 판정이 «포화»' "$FIN" && ok "B5: finishing 종료 driver 가 포화 판정을 요구" || no "B5: finishing 종료 driver 에 포화 판정 부재"
# 부재 — 금지 토큰이 새 표면에 없다
for tok in '판정자 조건' '판정자 투입' '다시 묻지 않는다' 'probe_count' 'web_budget' 'interview_round'; do
  grep -qF -- "$tok" "$SAT" && no "부재: saturation.md 에 «${tok}»" || ok "부재: saturation.md 에 «${tok}» 없음"
done
grep -qE '최대 [0-9]+회|[0-9]+회까지' "$SAT" && no "부재: saturation.md 에 숫자 횟수 상한 표현" || ok "부재: 숫자 횟수 상한 표현 없음"
finish
```
```bash
chmod +x plugins/spec-distill/tests/test_saturation_reference.sh
```

- [ ] **Step 2: 돌려서 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_saturation_reference.sh | tail -2; bash plugins/spec-distill/tests/test_research_agents_frontmatter.sh | tail -1`
Expected: `saturation.md 부재` · `saturation-judge: agent 파일 부재`.

- [ ] **Step 3: agent 파일을 쓴다** — `plugins/spec-distill/agents/saturation-judge.md`

````markdown
---
name: saturation-judge
cost_class: low
color: green
tools: Read, Grep, Glob
input_slots:
  - tag: decisions
    var: DECISIONS
    kind: task
  - tag: research_outputs
    var: RESEARCH_OUTPUTS
    kind: artifact
  - tag: ledger_state
    var: LEDGER_STATE
    kind: task
description: >
  Use this agent at the end of a spec-distill interview, once all five floor
  dimensions are closed, to judge whether more research could still change an open
  decision or open a new one. It reads the raw research outputs itself, marks the
  novelty of each, and returns saturated or not_saturated with the gaps to look at
  next. Independent judge, read-only by design (Law 2 frontmatter scoping) — it never
  receives the interviewer's own summary, the user's words or its previous verdicts.

  <example>Context: All five floor dimensions just closed.
  user: "포화 판정 돌려줘"
  assistant: "I'll dispatch the saturation-judge agent with the decisions, the raw research outputs and the ledger."</example>
---

# Saturation-Judge Agent (포화 판정자)

당신은 spec-distill 인터뷰의 포화 판정자입니다. 「조사를 더 해도 열린 결정을 바꾸거나 새 결정을 여는 사실이
없는가」 하나를 판정하고, 아니라면 다음에 볼 빈 곳을 냅니다. 인터뷰를 끝낼지 이어갈지는 이 판정과
사용자가 정합니다.

## You are / are not

- You ARE: 포화 판정자, 빈 곳 목록의 작성자, read-only.
- You are NOT: 조사 수행자(검색하지 않는다) · 원장 writer(Write/Edit 물리 차단) · 사용자에게 묻는 자 ·
  방향 결정자.

## Input

- `<decisions>` 열린 결정과 해결된 결정 전량, 한 줄에 하나 `OQ<n>: <한 줄> [열림|해결]`.
- `<research_outputs>` 조사 산출 **원문**, 시간 순 번호 `### 조사 <n> — <장치> · R<round>` 아래 verbatim.
  본체가 매긴 요약은 실려 오지 않는다 — 새로움은 당신이 원문에서 직접 매긴다.
- `<ledger_state>` floor 다섯과 derived 차원의 원장 행 그대로.

앞 판정과 사용자 원문은 받지 않는다. 판정은 사용자 말에 맞추는 쪽이 아니라 조사 원문과 결정 목록을 본다.

## 판정 기준

1. 원문마다 `novelty` 를 매긴다 — 그 산출이 바꾼 결정(`changed`)과 연 새 결정(`opened`). 최근 두 항목은 필수다.
2. `saturated` 는 당신이 매긴 `novelty` 에서 최근 두 항목이 둘 다 `changed: []` 이고 `opened: 없음` 이며,
   더 볼 빈 곳이 없을 때만 낸다.
3. 최근 두 항목 중 하나라도 결정을 바꿨거나 열었으면 `not_saturated` 다. 더 볼 곳이 떠오르지 않아도 출력
   오류가 아니다 — `kind: confirm` 빈 곳(그 바뀐 결정을 한 번 더 확인할 대상과 장치)을 낸다.
4. `<research_outputs>` 가 두 항목 미만이면 `not_saturated` 와 `kind: confirm` 빈 곳 하나(「조사가 두 번 미만 —
   열린 결정에 닿는 조사를 하나 더」)를 낸다.
5. 「충분해 보인다」를 근거로 쓰지 않는다. `basis` 에는 최근 두 항목의 novelty 요지와 그 근거 줄을 쓴다.
6. 빈 곳마다 무엇을 보면(`look_at`) · 어느 결정이 바뀔 수 있나(`may_change`, 없으면 `opens`) · 어느 장치로
   (`device`)를 쓴다. 같은 질문을 되풀이하지 않고 다른 접근을 먼저 고른다.

## Output 형식

```yaml
verdict: saturated | not_saturated
novelty:
  - n: <research_outputs 번호>
    changed: [OQ3]             # 이 산출이 바꾼 결정 — 없으면 []
    opened: "<이 산출이 연 새 결정 한 줄 | 없음>"
basis: "<최근 두 항목의 novelty 요지 · 근거 줄>"
gaps:                          # not_saturated 면 1개 이상
  - kind: explore | confirm    # explore = 아직 안 본 곳 · confirm = 최근 바뀐 결정의 확인
    look_at: "<무엇을 보면>"
    may_change: [OQ3]          # 바뀔 수 있는 결정 — 없으면 []
    opens: "<새로 열릴 수 있는 결정 한 줄 | 없음>"
    device: coverage-mapper | blind-spot-prober | steelman-builder | repo-researcher | orchestrator
```
````

- [ ] **Step 4: `references/saturation.md` 를 쓴다**

````markdown
## 조사 호출 상한 · 포화 판정

이 파일은 두 때에 읽는다: 조사 호출 합이 `research_limit` 에 닿을 때, 그리고 floor 다섯이 사용자 답으로 모두
`closed` 가 될 때. 줄 형식은 끝의 `## audit §2 줄` 이 정본이고 `check_brief.py gate` 가 그 글자를 읽는다.

### 상한 값

`research_limit` 의 시작값은 `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT` 다 — 양의 정수가 아니면 20 으로 두고 그 사실을
한 줄로 알린다. `saturation_limit` 의 시작값은 `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT` 다 — 양의 정수가 아니면 5 로 두고
그 사실을 한 줄로 알린다. 둘 다 state 에 적고 연장마다 시작값만큼 더한다.

```bash
lim="${DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT:-20}"
case "$lim" in ''|*[!0-9]*|0) echo "[spec-distill] DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT='${DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT:-}' 가 양의 정수가 아니다 — 20 으로 둔다." >&2; lim=20 ;; esac
sat="${DEVBREW_SPEC_DISTILL_SATURATION_LIMIT:-5}"
case "$sat" in ''|*[!0-9]*|0) echo "[spec-distill] DEVBREW_SPEC_DISTILL_SATURATION_LIMIT='${DEVBREW_SPEC_DISTILL_SATURATION_LIMIT:-}' 가 양의 정수가 아니다 — 5 로 둔다." >&2; sat=5 ;; esac
echo "research_limit=$lim saturation_limit=$sat"
```

### 상한 도달

`research_dispatches` 합이 `research_limit` 에 닿으면 다음 조사 dispatch **전에** 멈춘다. 하한 자리도 상한 앞에서 멈춘다 —
coverage-mapper · blind-spot-prober 의 첫 호출도 예외가 아니다. 그 순간 한 줄을 그대로 낸다:

> `[spec-distill] 조사 호출 상한 도달 — <n>/<limit>. 연장 · 판정 · 종료 중 고르세요.`

그리고 `AskUserQuestion` 1회로 셋 중 하나를 받는다(첫 선택지가 추천):

- 「같은 크기만큼 연장」 — `research_limit` 에 시작값을 더하고 멈췄던 dispatch 를 한다.
- 「지금 포화 판정으로」 — floor 가 다 닫혔으면 아래 `### 포화 판정` 으로 간다. 아직 열린 floor 는 사용자 질문으로 닫는다
  — blind_spot 첫 호출이 남았으면 web 비활성 때와 같은 inline premortem 강등으로 닫는다.
- 「인터뷰 종료」 — SKILL 의 「나가는 문」(사용자-승인 박제)으로 간다.

답은 사용자 발화 `S<m>` 으로 기록하고 audit §2 에 `- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: …` 을 남긴다.

### 포화 판정

floor 다섯이 사용자 답으로 모두 `closed` 가 되면 brief 작성(`finishing.md`)으로 가기 **전에** 판정자를 부른다.
판정자 호출 수가 `saturation_limit` 에 닿았으면 부르기 전에 `### 판정 상한` 으로 간다.

입력을 만든다:

- `${DECISIONS}` — `open_decisions[]` 전량, 한 줄에 하나 `OQ<n>: <한 줄> [열림|해결]`.
- `${RESEARCH_OUTPUTS}` — state 본문의 `### 조사 <n> — <장치> · R<round>` 블록을 번호 순으로 그대로 이어 붙인다.
  `research_log` 의 `changed` · `opened` · `summary` 는 싣지 않는다. 블록이 하나라도 빠졌으면(이월한 세션 · 원문을
  남기지 않은 조사) 요약으로 대신하지 않는다 — `### 판정 불가` 로 간다(사유 `조사 원문 블록 누락: <n…>`).
- `${LEDGER_STATE}` — floor + derived 원장 행 그대로.

```
Agent({ description: "Judge research saturation", subagent_type: "spec-distill:saturation-judge",
        prompt: "열린 결정과 해결된 결정 전량: <decisions>${DECISIONS}</decisions>. 조사 산출 원문(시간 순 번호 · verbatim): <research_outputs>${RESEARCH_OUTPUTS}</research_outputs>. 원장 상태(floor + derived 행 그대로): <ledger_state>${LEDGER_STATE}</ledger_state>. 판정 기준대로 verdict · novelty · basis · gaps 를." })
// **처분** — consumer=orchestrator · fail-closed · disclosure=포화 판정 불가 공시 + 사용자 선택
```

판정자는 최근 조사 두 번이 모두 결정을 바꾸지도 열지도 않았을 때만 「포화」를 낸다 — 「충분해 보인다」는 근거가 아니다.
판정자 호출은 조사 호출 상한에 세지 않는다. 판정마다 `saturation_log` 에 `{k, round, verdict, gaps, user_choice: null}` 을 더한다.

- `saturated` — audit §2 에 `- 포화 판정 <k>: 포화 — <basis 요지>` 를 남기고 `finishing.md` 로 간다.
- `not_saturated` — audit §2 에 `- 포화 판정 <k>: 아직 — 빈 곳 <g>개` 를 남긴다. `### 반복 감지` 를 먼저 보고,
  반복이 아니면 빈 곳을 조사한다(같은 질문을 되풀이하지 않고 다른 접근 먼저). 조사가 결정을 바꾸거나 열면 라운드가
  사용자에게 돌아가고 floor 가 재개방될 수 있다. floor 가 다시 모두 닫히면 판정자를 다시 부른다.

판정자의 `novelty` 와 본체의 `research_log` 표시가 다르면 그 라운드의 «지금 이해»에 한 줄로 보인다 — 같은 `n` 에서
`changed` 집합이 다르거나, `research_log.opened` 가 `[]` 인데 판정자 `opened` 가 `없음` 이 아니거나 그 반대일 때다.
멈춤은 판정자의 것을 따른다.

### 반복 감지

반복 감지는 판정자가 아니라 본체가 한다(판정자는 앞 판정을 받지 않는다). `not_saturated` 의 빈 곳마다 `saturation_log`
의 이전 빈 곳과 비교해, `may_change` 결정 집합과 `device` 가 둘 다 같으면 같은 빈 곳이다(`look_at` 문장은 비교하지
않는다 — 판정자는 같은 빈 곳을 매번 다른 문장으로 쓸 수 있다). `may_change` 가 빈 빈 곳은 `opens` 문장의 공백 정규화
일치를 함께 본다. 같은 빈 곳이 하나라도 있으면 혼자 다시 돌리지 않고 그 빈 곳을 사용자에게 보인 뒤 `AskUserQuestion` 1회로
「한 번 더 조사」 · 「포화로 보고 종료」 · 「인터뷰 종료」 중 하나를 받는다. 같은 입력의 steelman 재호출도 하지 않는다.

- 「한 번 더 조사」 → `- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)`
- 「포화로 보고 종료」 → `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 반복 빈 곳` 뒤 `finishing.md`
- 「인터뷰 종료」 → `- 사용자 종료(@S<m>) — 마지막 판정 아직` 뒤 나가는 문

### 판정 불가

Agent 도구가 없거나, dispatch 가 실패하거나, 출력이 깨졌거나(`not_saturated` 인데 `gaps` 가 빔 · 필드 누락), 조사 원문
블록이 빠졌으면 모델이 혼자 끝내지 않는다. 한 줄을 낸다:

> `[spec-distill] 포화 판정 불가 — <사유>`

그리고 `AskUserQuestion` 1회로 「포화로 보고 종료」 · 「조사 계속」 중 하나를 받는다. 공시는 포화 판정 불가 공시 + 사용자 선택 이다.

- 「포화로 보고 종료」 → `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 판정 불가(<사유>)` 뒤 `finishing.md`
- 「조사 계속」 → `- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)`. 뒤에 포화 판정이나 사용자 종료 줄이 와야
  게이트가 통과한다.

### 판정 상한

floor 다섯이 닫힌 뒤에는 「판정자 → 빈 곳 조사 → 판정자」 고리가 사용자 턴 없이 돌 수 있다. 판정자 호출 수가
`saturation_limit` 에 닿으면 다음 판정자 dispatch **전에** 멈추고 한 줄을 낸다:

> `[spec-distill] 포화 판정 상한 도달 — <k>/<limit>. 연장 · 포화로 보고 종료 · 인터뷰 종료 중 고르세요.`

`AskUserQuestion` 1회로 「같은 크기만큼 연장」 · 「포화로 보고 종료」 · 「인터뷰 종료」 중 하나를 받고 audit §2 에
`- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: …` 을 남긴다. 「포화로 보고 종료」는
`- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — 판정 상한`, 「인터뷰 종료」는 `- 사용자 종료(@S<m>) — 마지막 판정 아직` 으로 잇는다.

### audit §2 줄

`finishing.md` Step A ④ 가 mapper 줄 아래에 시간 순으로 옮겨 쓴다. 판정 줄은 같은 차례 `<k>` 에 사용자 선택 줄이 이어진다.

- `- 조사 호출 <n>/<limit> (장치별: 커버리지 <a> · 맹점 <b> · 반론 <c> · 레포 조사 <d> · 본체 직접 <e>)` — `<e>` 는 상한 밖이고 보이기만 한다.
- `- 상한 도달 <n>/<limit> — 사용자 선택 S<m>: 연장 | 판정으로 | 인터뷰 종료`
- `- 판정 상한 도달 <k>/<limit> — 사용자 선택 S<m>: 연장 | 포화로 보고 종료 | 인터뷰 종료`
- `- 포화 판정 <k>: 포화 — <basis 요지>`
- `- 포화 판정 <k>: 아직 — 빈 곳 <g>개`
- `- 포화 판정 <k>: 사용자 판단 포화(@S<m>) — <반복 빈 곳 | 판정 불가(<사유>) | 판정 상한>`
- `- 포화 판정 <k>: 판정 불가(<사유>) — 조사 계속(@S<m>)`
- `- 포화 판정 <k>: 아직 — 반복 빈 곳 재조사(@S<m>)`
- `- 사용자 종료(@S<m>) — 포화 판정 전`
- `- 사용자 종료(@S<m>) — 마지막 판정 아직`

장치 이름(`coverage-mapper`)은 mapper 줄 밖에 쓰지 않는다 — 게이트의 하한 검사가 그 글자의 첫 매치를 읽는다.
````

- [ ] **Step 5: SKILL.md 에 조사 상한 절을 넣는다** — `## 사용자 발화 기록 (G1, AC1)` 절 끝(`승격시키지 않습니다 — 그 승격이 라운드마다 결정을 박제하던 경로였습니다.` 다음 빈 줄)과 `## coverage-mapper dispatch` 사이:

````markdown
## 조사 상한 · 포화 판정

조사 subagent 넷(`coverage-mapper` · `blind-spot-prober` · `steelman-builder` · `repo-researcher`)은 자격 · 예산 없이,
그 호출이 열린 결정을 바꾸거나 새 결정을 열 수 있다고 볼 때마다 부른다. 첫 호출 필수 자리 둘은 하한으로 남는다.
인터뷰의 첫 조사 subagent dispatch 직전에 아래 한 줄을 그대로 내고, 승인은 묻지 않는다:

> `[spec-distill] 이 인터뷰는 조사 subagent 를 최대 <limit>회까지 부른다(웹 포함 · 승인 없이 진행 · 연장은 닿을 때 묻는다).`

dispatch 마다 `research_dispatches` 의 그 장치 칸을 +1 하고, 산출 원문을 state 본문 `### 조사 <n> — <장치> · R<round>`
아래 verbatim 으로 남기고, «지금 이해»에 실은 뒤(V1 확인 뒤) `research_log` 에 한 항목을 더한다. 본체의 직접 조사(경로 (a)
확인 · web sweep)도 «지금 이해»에 실을 때 같은 두 자리에 `device: orchestrator` 로 남기되 상한에는 세지 않는다 — 판정자 호출도
세지 않는다. 본체 직접 조사는 라운드 규약(라운드마다 질문 하나 · 답 하나)이 묶는다. 합이 `research_limit` 에 닿을 때와
floor 다섯이 모두 `closed` 가 될 때 아래 파일을 Read 로 읽어 그대로 따른다.

```
Read ${CLAUDE_PLUGIN_ROOT}/skills/spec-interview/references/saturation.md
```

그 파일의 플러그인 루트 변수(`CLAUDE_PLUGIN_ROOT`)는 치환되지 않은 채로 온다 — 읽거나 실행할 때 `${CLAUDE_PLUGIN_ROOT}` 로 바꿔 넣는다. 위 `Read` 줄의 경로가 절대 경로로 보이지 않으면 reference 를 cwd 에서 찾지 말고 멈춰 보고한다.

````
(바깥 4-backtick 은 계획 표기다.)

라운드 규약 «지금 이해» 템플릿 둘째 줄. old ` 외부 근거(landscape·premortem)가 있으면 여기 싣는다. 재개방이면 «→ <차원> 재개방: <사유>»>` → new ` 외부 근거(landscape·premortem)가 있으면 여기 싣는다. 재개방이면 «→ <차원> 재개방: <사유>». 끝줄 «조사 호출 <n>/<limit> · 이 라운드 본체 직접 <e>»>`

`## 종료` 절. old `**종료 절차 전문은 \`references/finishing.md\` 에 있다.** floor 5차원이 전부 \`closed\` 가 되어\nbrief 작성으로 넘어갈 때` → new `**종료 절차 전문은 \`references/finishing.md\` 에 있다.** floor 5차원이 전부 \`closed\` 가 되고 포화 판정이\n끝나(\`## 조사 상한 · 포화 판정\`) brief 작성으로 넘어갈 때`

나가는 문 둘째 문단 끝. old `없애는 것은 사용자 질문의 상한이지 나가는 문이\n아니다.` → new `없애는 것은 사용자 질문의 상한이지 나가는 문이\n아니다. 포화 판정 전에 끝내면 audit §2 에 \`- 사용자 종료(@S<n>) — 포화 판정 전\` 을, 마지막 판정이 «아직» 일 때 끝내면 \`- 사용자 종료(@S<n>) — 마지막 판정 아직\` 을 남긴다.`

읽는 조건 줄. old `읽어야 하는 조건: \`coverage.floor\` 의 다섯 차원이 모두 \`status: closed\`.` → new `읽어야 하는 조건: \`coverage.floor\` 의 다섯 차원이 모두 \`status: closed\` 이고, 마지막 포화 판정이 «포화» 이거나 사용자가 종료를 골랐다.`

- [ ] **Step 6: finishing.md 를 고친다**

종료 driver. old `종료 driver는 **커버리지 원장의 floor 5차원이 전부 \`closed\`** 인 것이다(고정 라운드 수 아님, G1).` → new `종료 driver는 **커버리지 원장의 floor 5차원이 전부 \`closed\`** 이고 마지막 포화 판정이 «포화» 이거나 사용자가 종료를 고른 것이다(고정 라운드 수 아님, G1 · 이중 종료).`

Step A ④ mapper 문단 끝(`사람에게 보입니다.` 다음 줄)에 이어 쓴다:
```markdown
   그 아래에 `skills/spec-interview/references/saturation.md` 의 `## audit §2 줄` 형식으로 조사 호출 줄 한 줄과,
   상한 도달 · 판정 상한 도달 · 포화 판정 · 사용자 종료 줄을 시간 순으로 옮겨 씁니다(state `research_dispatches` ·
   `research_limit` · `saturation_log`). 게이트는 `포화 판정 <k>:` · `사용자 종료(@S<n>)` 줄의 **마지막**을 봅니다.
```
Step A ⑦ 미충족 목록. old `0건 sentinel 누락**).` → new `0건 sentinel 누락**·포화 판정 줄 없음 · 마지막 판정 «아직»).`

B-2 advisory 문장. old `\`check_brief.py gate\` 의 \`advisories\` 도 게이트 앞 글(목록 4)에 씁니다 — \`coverage-mapper 0\n(unavailable: …)\` 은` 앞 문장은 그대로 두고, 그 문단의 `조사 축의 advisory 둘도 같은 자리로 옵니다:` 앞에 한 문장을 넣는다: `사용자 판단 포화(판정자의 «포화» 없이 사용자가 끝냈다)도 같은 자리로 옵니다.`

`state-migration.md`. old `포화 판정 때 판정 불가 경로로 간다.` → new `포화 판정 때 \`references/saturation.md\` 의 \`### 판정 불가\` 경로로 간다.`

- [ ] **Step 7: README AP9 를 10종으로**

old `9종(doc-critic·doc-critic-web·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·repo-researcher·brief-readback·seed-readback).` → new `10종(doc-critic·doc-critic-web·doc-recritic·steelman-builder·coverage-mapper·blind-spot-prober·repo-researcher·saturation-judge·brief-readback·seed-readback).` Law 2 열거 old `+ repo-researcher(\`Read, Grep, Glob\`) agent의` → new `+ repo-researcher(\`Read, Grep, Glob\`) + saturation-judge(\`Read, Grep, Glob\`) agent의`

- [ ] **Step 8: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/spec-distill/tests/test_saturation_reference.sh plugins/spec-distill/tests/test_research_agents_frontmatter.sh \
         plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_readme_sync.sh \
         plugins/spec-distill/tests/test_stale_terms.sh plugins/spec-distill/tests/test_web_kill_switch.sh \
         plugins/spec-distill/tests/test_probe_sweep_residue.sh plugins/spec-distill/tests/test_brief_review_entry.sh \
         shared/tests/test_dispatch_disposition.sh shared/tests/test_agent_input_slots.sh shared/tests/test_dispatch_name_defined.sh \
         shared/tests/test_skill_reference_pointers.sh shared/tests/test_no_new_duplication.sh \
         plugins/quality-gates/tests/test_agent_frontmatter_keys.sh; do
  printf '%s: ' "$t"; bash "$t" 2>&1 | tail -1; done
bash -n <(awk '/^```bash$/{f=1;next} f&&/^```$/{f=0} f' plugins/spec-distill/skills/spec-interview/references/saturation.md) && echo "bash -n ok"
```
Expected: 새 실패 없음 · `bash -n ok`. `skill_own_lines` 가 504 미만.

- [ ] **Step 9: 커밋**

```bash
git add plugins/spec-distill/agents/saturation-judge.md plugins/spec-distill/skills/spec-interview/references/saturation.md \
  plugins/spec-distill/tests/test_saturation_reference.sh plugins/spec-distill/tests/test_research_agents_frontmatter.sh \
  plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/skills/spec-interview/references/finishing.md \
  plugins/spec-distill/skills/spec-interview/references/state-migration.md plugins/spec-distill/README.md
git commit -m "$(cat <<'MSG'
feat(spec-distill): 조사 호출 상한과 독립 포화 판정자로 인터뷰를 멈춘다

조사 subagent 호출은 상한(기본 20)에 닿으면 사용자에게 연장 · 판정 · 종료를 묻는다.
floor 다섯이 닫히면 읽기 전용 saturation-judge 가 조사 원문에서 새로움을 직접 매겨
포화를 판정하고, 판정 고리에도 상한(기본 5)을 둔다. 첫 조사 전에 규모를 한 줄로 알린다.

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
git ls-files -s plugins/spec-distill/tests/test_saturation_reference.sh | cut -c1-6
bash plugins/quality-gates/tests/test_agent_model_mutation.sh 2>&1 | tail -1
```

---

### Task 5: 문제 재구성 단계를 걷는다

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md` (의례 표 R1 행 · «지금 이해» 정의 · 닫힘 발화 · prober prompt)
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` (driver 체크리스트 · Step A ④ 규약)
- Modify: `plugins/spec-distill/skills/spec-interview/references/steelman.md` (Step 1)
- Modify: `plugins/spec-distill/agents/blind-spot-prober.md` (Input)
- Modify: `plugins/spec-distill/README.md` (흐름도 R1 · Law 2 input_slots 문장)
- Modify: `tools/adjudication/check_slots.py` (면제 사유 문장 둘)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (I 락)

**Interfaces:**
- Produces: 의례 표 R1 행 라벨 `**사용자 말 그대로**` · 닫힘 발화 `root_problem = 사용자 원문 인용 S`.

- [ ] **Step 1: I 락을 뒤집는다 (TCIS)**

`has 'R1.*Reframe' "R1 Reframe ritual"` → `has 'R1.*사용자 말 그대로' "R1 사용자 말 그대로 ritual"`

`r1_row="$(grep -E '^\|[[:space:]]*R1[[:space:]]*\|' "$SKILL")"` 부터 그 단언의 `|| no "R1(v0.41.0): R1 행에 라벨과 R&R 이동 실체가 함께 있지 않다"` 까지를 다음으로 바꾼다:
```bash
r1_row="$(grep -E '^\|[[:space:]]*R1[[:space:]]*\|' "$SKILL")"
{ [[ -n "$r1_row" ]] && grep -qF '사용자 말 그대로' <<<"$r1_row" && grep -qF '원문 그대로 인용' <<<"$r1_row"; } \
  && ok "R1/I: R1 행 = 사용자 말 그대로 · root_problem 원문 인용" \
  || no "R1/I: R1 행에 「사용자 말 그대로」와 원문 인용이 함께 있지 않다"
reframe_corpus=("${CI_ALL[@]}" "$REPO_ROOT/plugins/spec-distill/agents/"*.md)
for tok in 'Problem Reframe' 'Reframed Problem' '되풀이하는 것은 통과가 아니다' '재구성 동의 S' '문제의 현재 재구성' '재구성된 문제정의' 'R1 문제정의' '한 문장으로 재구성'; do
  grep -qF -- "$tok" "${reframe_corpus[@]}" && no "R1/I: 옛 재구성 문구 «${tok}» 잔존" || ok "R1/I: «${tok}» 없음"
done
# README 는 live 줄만 — `**vX.Y.Z**` 로 시작하는 연혁 줄은 그 시점의 사실이다.
grep -vE '^\*\*v[0-9]' "$REPO_ROOT/plugins/spec-distill/README.md" | grep -qF 'Problem Reframe' \
  && no "R1/I: README live 줄에 Problem Reframe 잔존" || ok "R1/I: README live 줄에 Problem Reframe 없음"
grep -qF 'root_problem = 사용자 원문 인용 S' <<<"$close_flat" \
  && ok "R1/I(양의 짝): 닫힘 발화 root_problem = 사용자 원문 인용 S" || no "R1/I(양의 짝): root_problem 닫힘 발화 문구 부재"
grep -qF '사용자 문제 서술은 다시 쓰지 않는다' <<<"$round_block" \
  && ok "R1/I(양의 짝): «지금 이해» 정의가 재구성을 요구하지 않는다" || no "R1/I(양의 짝): «지금 이해» 새 정의 부재"
```
(`close_flat` 은 위 `## 닫힘 · 재개방` 단언에서 정의돼 있다. `round_block` 은 라운드 규약 단언에서 정의돼 있다.)

- [ ] **Step 2: 돌려서 실패를 본다** — `bash plugins/spec-distill/tests/test_conducting_interview_stage.sh 2>&1 | grep '✗ R1/I'` 가 여러 줄.

- [ ] **Step 3: 고친다**

SKILL.md:
- R1 행. old `| R1 | **Problem Reframe** | seed 가 가리키는 **작업 뒤의 진짜 문제**를 재구성한 한 문장 문제정의 + 진짜 goal. seed 의 문장을 되풀이하는 것은 통과가 아니다. | (d) ontological → payload §0 · §1 |` → new `| R1 | **사용자 말 그대로** | root_problem 은 S1 과 문제를 서술한 이후 사용자 발화를 **원문 그대로 인용**해 닫는다. 다시 쓴 문장 · 확인 질문 없음. | (d) ontological → payload §0 · §1 |`
- «지금 이해» 템플릿 첫 줄. old `<문제의 현재 재구성 — 바뀐 부분만 한두 문장. 코드·문서에서 확인한 사실(경로 a)과` → new `<확인한 사실과 그 라운드에 바뀐 것 — 한두 문장(사용자 문제 서술은 다시 쓰지 않는다). 코드·문서에서 확인한 사실(경로 a)과`
- 닫힘 발화. old `다섯 floor 의 닫힘 발화: root_problem = 재구성 동의 S · landscape = 외부 근거 처분 S ·` → new `다섯 floor 의 닫힘 발화: root_problem = 사용자 원문 인용 S(S1 과 문제를 서술한 발화) · landscape = 외부 근거 처분 S ·`
- prober prompt. old `prompt: "지금까지의 framing(재구성된 문제정의 + 사용자 제약 요지): <framing>${FRAMING}</framing>.` → new `prompt: "지금까지의 framing(사용자 원문 — S1 과 문제를 서술한 발화 — 과 확인한 사실 · 사용자 제약 요지): <framing>${FRAMING}</framing>.`

finishing.md:
- old `- floor \`root_problem\` closed — 진짜 problem이 한 문장으로 재구성(R1 계열).` → new `- floor \`root_problem\` closed — root_problem 이 사용자 원문 인용으로 닫힘(R1 계열).`
- old `어느 S 인지의 규약: root_problem = 재구성 동의 S ·` → new `어느 S 인지의 규약: root_problem = 사용자 원문 인용 S ·`

steelman.md Step 1. old `- **핵심 전제 P1..Pn** — R1 문제정의·goal 과 그때까지의 \`user_statements\` 에서 도출한다.` → new `- **핵심 전제 P1..Pn** — 사용자 원문·goal 과 그때까지의 \`user_statements\` 에서 도출한다.`

blind-spot-prober.md Input. old `- 현재 재구성된 문제정의(Reframed Problem) + 지금까지 사용자가 말한 제약의 요지.` → new `- 사용자 원문(S1 과 문제를 서술한 발화) + 확인한 사실 + 지금까지 사용자가 말한 제약의 요지.`

README:
- 흐름도. old `· R1 Problem Reframe / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ` → new `· R1 사용자 말 그대로 / R2 Landscape / R3 Steelman / R4 Tried&Discarded / R5 OQ`
- Law 1 문제공간 게이트 줄의 old `(R1–R5: 문제 다시 보기 · 사례 조사 · 반대 입장 시험 · 해보고 버린 것 · 열린 질문)` → new `(R1–R5: 사용자 말 그대로 · 사례 조사 · 반대 입장 시험 · 해보고 버린 것 · 열린 질문)`
- Law 2 input_slots 줄의 old `(맡은 일이 오케스트레이터의 재구성 그 자체를 따지는 것이라서)` → new `(맡은 일이 오케스트레이터가 모은 framing — 사용자 원문과 확인한 사실 — 을 따지는 것이라서)`

`tools/adjudication/check_slots.py` — 사유 문장만(키 · 수 · 구조는 그대로):
- old `"이다 — 프로브의 대상이 정의상 오케스트레이터가 재구성한 그 framing "` → new `"이다 — 프로브의 대상이 정의상 오케스트레이터가 모은 그 framing(사용자 원문과 확인한 사실) "`
- old `"위험은 남는다 — 재구성이 이미 잃은 것은 프로버도 못 본다. 그 "` → new `"위험은 남는다 — 모으는 동안 잃은 것은 프로버도 못 본다. 그 "`
- old `"대상이 정의상 orchestrator 가 R1 에서 도출한 그 목록이라 대응물이 없다. 다른 값(사용자 "` → new `"대상이 정의상 orchestrator 가 사용자 원문·goal 에서 도출한 그 목록이라 대응물이 없다. 다른 값(사용자 "`

- [ ] **Step 4: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh \
         plugins/spec-distill/tests/test_readme_sync.sh plugins/spec-distill/tests/test_research_claims_contract.sh \
         shared/tests/test_agent_input_slots.sh; do printf '%s: ' "$t"; bash "$t" 2>&1 | tail -1; done
grep -rnF -e 'Problem Reframe' -e '재구성 동의' -e '재구성된 문제정의' -e 'R1 문제정의' plugins/spec-distill --include='*.md' | grep -v '/tests/' | grep -v CHANGELOG | grep -vE ':\*\*v[0-9]'
```
Expected: 새 실패 없음, 마지막 grep 0줄(README 연혁 줄은 걸러졌다).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/skills/spec-interview/references/finishing.md \
  plugins/spec-distill/skills/spec-interview/references/steelman.md plugins/spec-distill/agents/blind-spot-prober.md \
  plugins/spec-distill/README.md tools/adjudication/check_slots.py plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "$(cat <<'MSG'
feat(spec-distill): 문제 재구성 단계를 걷고 root_problem 을 사용자 원문 인용으로 닫는다

의례 R1 은 「사용자 말 그대로」다. «지금 이해» · blind-spot framing · steelman 전제 도출 ·
종료 체크리스트가 다시 쓴 문제정의를 전제하지 않는다.

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 6: 횟수 강제를 반복 감지 · 사용자 선택지로 바꾼다 (steelman · 되묻기 · landscape · coverage-mapper)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/steelman.md` (줄 「한 방향당 steelman 1회 …」 · Step 2.5 마지막 문장)
- Modify: `plugins/spec-distill/agents/steelman-builder.md` (규칙 7)
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md` (되묻기 · R2 시점)
- Modify: `plugins/spec-distill/agents/coverage-mapper.md` (규칙 5 · 비사용 항목)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (G · D · E 락) · `test_stale_terms.sh` (V13 양성 짝) · `test_coverage_mapper_frontmatter.sh` (S2 락)

**Interfaces:**
- Produces: 문구 `다음 질문의 선택지에 「이 주제를 더 파기」를 둔다` · `토픽이 잡히면, 그리고 결정에 닿을 때마다` · `새 근거 또는 바뀐 전제가 있으면 같은 방향도 다시 부르고, 입력이 같으면 부르지 않는다`.

- [ ] **Step 1: 락을 뒤집는다**

TCIS G: `grep -qF '같은 주제의 연속 되묻기는 최대 2회' <<<"$round_flat"` 단언 두 줄을 다음으로:
```bash
grep -qF '최대 2회' <<<"$round_flat" && no "R1/G: 되묻기 «최대 2회» 상한 잔존" || ok "R1/G: 되묻기 상한 문구 없음"
grep -qF '다음 질문의 선택지에 「이 주제를 더 파기」를 둔다' <<<"$round_flat" \
  && ok "R1/G(양의 짝): 두 번 되물은 뒤 「이 주제를 더 파기」 선택지 — 사용자가 연다" || no "R1/G(양의 짝): 「이 주제를 더 파기」 선택지 부재"
```
TCIS D · E — `r2_block` 단언(탐색 경계) 바로 아래에:
```bash
grep -qF 'round 1–2' <<<"$r2_block" && no "R1/D: landscape 시점 강제 «round 1–2» 잔존" || ok "R1/D: landscape 시점 강제 없음"
grep -qF '토픽이 잡히면, 그리고 결정에 닿을 때마다' <<<"$r2_flat" \
  && ok "R1/D(양의 짝): landscape 는 결정에 닿을 때마다" || no "R1/D(양의 짝): landscape 새 시점 문구 부재"
grep -qF 'web sweep ≥1회' "$SKILL" && ok "R1/D: «≥1회» 하한은 남는다" || no "R1/D: landscape 하한 «≥1회» 가 사라졌다"
STEEL_ALL="$(cat "$FIN_DIR/steelman.md" "$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md" | tr '\n' ' ' | tr -s ' ')"
for tok in '한 방향당' '같은 ST 안에서 재dispatch 는 하지 않는다' '재steelman 금지'; do
  grep -qF -- "$tok" <<<"$STEEL_ALL" && no "R1/E: steelman 횟수 문구 «${tok}» 잔존" || ok "R1/E: «${tok}» 없음"
done
grep -qF '새 근거 또는 바뀐 전제가 있으면 같은 방향도 다시 부르고, 입력이 같으면 부르지 않는다' "$FIN_DIR/steelman.md" \
  && ok "R1/E(양의 짝): steelman 반복 감지 문구(steelman.md)" || no "R1/E(양의 짝): steelman.md 반복 감지 문구 부재"
grep -qF '새 근거 또는 바뀐 전제가 있으면 같은 방향도 다시 부르고, 입력이 같으면 부르지 않는다' "$REPO_ROOT/plugins/spec-distill/agents/steelman-builder.md" \
  && ok "R1/E(양의 짝): steelman 반복 감지 문구(builder)" || no "R1/E(양의 짝): steelman-builder 반복 감지 문구 부재"
```
`test_stale_terms.sh` 의 V13 양성 짝 `grep -qF '같은 주제의 연속 되묻기는 최대 2회' <<<"$v13_flat"` 세 줄을:
```bash
grep -qF '다음 질문의 선택지에 「이 주제를 더 파기」를 둔다' <<<"$v13_flat" \
  && ok "V13 양성 짝: 라운드 규약에 되묻기 뒤 선택지 문구" \
  || no "V13 양성 짝: 라운드 규약에 되묻기 뒤 선택지 문구가 없다 — 새 형식이 사라졌다"
```
`test_coverage_mapper_frontmatter.sh` `finish` 위에:
```bash
# R1(2026-10-12) S2 · C10: floor 가 닫혀도 부를 수 있고(판정자의 빈 곳), 낮은 confidence 가 신호를 끄지 않는다.
grep -qF '원장 floor가 이미 전부 closed' <<<"$AGENT_FLAT" && no "R1/S2: 「floor 전부 closed」 비사용 항목 잔존" || ok "R1/S2: floor-closed 비사용 항목 없음"
grep -qF -- '면 `neglect_flag: false`' <<<"$AGENT_FLAT" && no "R1/C10: 낮은 confidence 가 neglect 신호를 끈다" || ok "R1/C10: confidence 가 신호를 끄지 않는다"
grep -qF -- '`neglect_flag` 를 끄지 않는다' <<<"$AGENT_FLAT" && ok "R1/C10(양의 짝): confidence 를 붙여 보인다" || no "R1/C10(양의 짝): 새 confidence 규칙 부재"
```

- [ ] **Step 2: 돌려서 실패를 본다** — 세 테스트에서 `R1/G` · `R1/D` · `R1/E` · `R1/S2` · `R1/C10` · `V13 양성 짝` 실패.

- [ ] **Step 3: 고친다**

SKILL.md 되묻기. old:
```markdown
  같은 주제의 연속 되묻기는 최대 2회다 — 그 뒤에도 약한 답이면 답을 그대로 기록하고(보류는 «사용자 발화
  기록» 표대로 §3 Open Questions 로도 이월) 다음 질문으로 넘어간다. 그 차원을 자동으로 닫지 않는다.
```
new:
```markdown
  같은 주제를 연속 두 번 되물은 뒤에도 약한 답이면 답을 그대로 기록하고(보류는 «사용자 발화
  기록» 표대로 §3 Open Questions 로도 이월) 다음 질문의 선택지에 「이 주제를 더 파기」를 둔다 — 더 팔지는 사용자가 연다. 그 차원을 자동으로 닫지 않는다.
```
SKILL.md R2 시점. old `토픽이 잡히면(round 1–2) landscape sweep을 수행합니다.` → new `토픽이 잡히면, 그리고 결정에 닿을 때마다 landscape sweep을 수행합니다(의례 R2 의 «≥1회» 는 하한이다).`

steelman.md. old `한 방향당 steelman 1회 — 새 근거 없으면 재steelman 금지(AP16).` → new `새 근거 또는 바뀐 전제(사용자가 받아들인 \`premise_list_challenge\` 포함)가 있으면 같은 방향도 다시 부르고, 입력이 같으면 부르지 않는다 — 횟수가 아니라 입력의 반복으로 멈춘다(AP16).`
steelman.md Step 2.5. old `있어야 연다. 같은 ST 안에서 재dispatch 는 하지 않는다.` → new `있어야 연다. 고친 전제로 다시 부르는 것은 새 ST 다.`

steelman-builder.md 규칙 7. old `7. **한 방향당 1회**: 같은 방향에 대한 재호출은 새 근거가 있을 때만.` → new `7. **반복 감지**: 새 근거 또는 바뀐 전제가 있으면 같은 방향도 다시 부르고, 입력이 같으면 부르지 않는다 — 같은 입력을 받았다고 느끼면 \`premise_list_challenge\` 에 그 사실을 적는다.`

coverage-mapper.md. 규칙 5 old `5. **confidence < 0.5** 면 \`neglect_flag: false\` — 약한 신호로 산만하게 하지 않음.` → new `5. **confidence < 0.5** 여도 \`neglect_flag\` 를 끄지 않는다 — 신호와 함께 \`confidence\` 를 그대로 내고 판단은 orchestrator 가 한다.` 그리고 `## 사용하지 않는 경우` 의 `- 원장 floor가 이미 전부 closed(종료 임박 — 새 derived 제안이 종료를 무의미하게 늘림).` 줄을 지운다.

- [ ] **Step 4: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in test_conducting_interview_stage test_stale_terms test_coverage_mapper_frontmatter test_steelman_builder_scope test_research_claims_contract test_web_kill_switch; do
  printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
```
Expected: 새 실패 없음(`test_steelman_builder_scope.sh` 의 `최대 N회` · `confidence` 락이 builder 에 걸리지 않는다 — 규칙 7 새 문장에 그 글자가 없다).

- [ ] **Step 5: 커밋**

```bash
git add plugins/spec-distill/skills/spec-interview/references/steelman.md plugins/spec-distill/agents/steelman-builder.md \
  plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/agents/coverage-mapper.md \
  plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_stale_terms.sh \
  plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh
git commit -m "$(cat <<'MSG'
feat(spec-distill): 횟수 강제를 반복 감지와 사용자 선택지로 바꾼다

steelman 은 새 근거나 바뀐 전제가 있으면 같은 방향도 다시 부른다. 되묻기 상한 대신
「이 주제를 더 파기」 선택지를 둔다. landscape 는 결정에 닿을 때마다(하한 ≥1회 유지).
coverage-mapper 는 floor 가 닫혀도 부를 수 있고 낮은 confidence 가 신호를 끄지 않는다.

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 7: (예비) 스위트 전체 중간 대조

Task 1~6 뒤 한 번, 리뷰 전에 baseline 과 같은 집합을 잰다. 고칠 것이 나오면 해당 Task 의 커밋에 이어 새 커밋으로 고친다(앞 커밋을 고쳐 쓰지 않는다).

- [ ] **Step 1:** `bash ~/.claude/sdd-mirror/r1-impl/run_suite.sh ~/.claude/sdd-mirror/r1-impl/after-t6.txt`
- [ ] **Step 2:** `comm -13 ~/.claude/sdd-mirror/r1-impl/baseline-before.txt ~/.claude/sdd-mirror/r1-impl/after-t6.txt`
Expected: 빈 출력(새 실패 이름 0). 나오면 그 이름 하나씩 원인 Task 를 찾아 고친다.

---

### Task 8: 변이 검증 (AC14)

**Files:** 없음(복사본에서만)

변이는 커밋된 HEAD 의 **클론**에서 한다. 각 변이는 한 번에 하나, 되돌리고 다음으로 간다. 양성 대조(변이 없는 클론이 대상 테스트를 통과)를 먼저 잰다.

- [ ] **Step 1: 클론 · 양성 대조**

```bash
MUT=~/.claude/sdd-mirror/r1-impl/mut
rm -rf "$MUT"
git clone -q --no-local /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-persistent-explore "$MUT"
cd "$MUT" && git log --oneline -1
export PYTHONDONTWRITEBYTECODE=1
for t in test_conducting_interview_stage test_check_brief test_saturation_reference test_research_agents_frontmatter test_stale_terms test_coverage_mapper_frontmatter; do
  printf '%s: ' "$t"; bash plugins/spec-distill/tests/$t.sh 2>&1 | tail -1; done
bash shared/tests/test_dispatch_disposition.sh 2>&1 | tail -1
```
Expected: 클론의 HEAD 가 worktree HEAD 와 같고, 대상 테스트가 baseline 과 같은 실패 집합(대개 `Fail: 0`).

- [ ] **Step 2: 변이 표를 하나씩 돈다** — 각 줄: 변이 → 대상 테스트 실행 → `Fail: 0` 이 아니어야(RED) 한다 → `git checkout HEAD -- .` 로 되돌리고 `git diff HEAD --quiet && echo clean` 확인.

| # | 변이(클론 안에서) | 대상 테스트 | 기대 |
|---|---|---|---|
| M1 | SKILL `## coverage-mapper dispatch` 절 끝에 `열린 결정이 0이면 자격이 없다 — 예산이 남아도 부르지 않는다.` 한 줄 추가 | test_conducting_interview_stage | RED (R1/A) |
| M2 | SKILL 스키마의 `research_dispatches:` 줄 삭제 | test_conducting_interview_stage | RED (R1/state) |
| M3 | SKILL 에 `## C44 Dialectic Rhythm Guard` 머리 한 줄 추가 | test_conducting_interview_stage | RED (R1/C) |
| M4 | README 끝에 `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD` 한 줄 추가 | test_conducting_interview_stage | RED (R1/C, README 코퍼스) |
| M5 | SKILL 의 repo-researcher `Agent({…})` 두 줄과 처분 줄 삭제 | test_conducting_interview_stage · shared test_dispatch_disposition | RED (R1/F · 축 per-agent) |
| M6 | C43 행 (a) 에 `subagent 를 부르지 않는다` 를 되살림 | test_conducting_interview_stage | RED (R1/F) |
| M7 | `check_brief.py` 의 `if SAT_NOT_YET_RE.match(last):` 분기가 `return [], []` | test_check_brief | RED (s_notyet · s_order · s_redo) |
| M8 | `SAT_CONTINUE_RE` 분기가 `return [], []` | test_check_brief | RED (s_cont) |
| M9 | 앵커 검사 `if s not in anchors:` 를 `if False:` | test_check_brief | RED (s_anchor · s_uanchor) |
| M10 | `hits[-1]` → `hits[0]` | test_check_brief | RED (s_order) |
| M11 | SKILL 라운드 규약에 `같은 주제의 연속 되묻기는 최대 2회다.` 추가 | test_conducting_interview_stage · test_stale_terms | RED (R1/G) |
| M12 | SKILL 에서 `「이 주제를 더 파기」` 를 지움 | test_conducting_interview_stage · test_stale_terms | RED (양의 짝) |
| M13 | SKILL R1 행을 옛 `| R1 | **Problem Reframe** | …` 로 되돌림 | test_conducting_interview_stage | RED (R1/I) |
| M14 | steelman.md 에 `한 방향당 steelman 1회` 한 줄 추가 | test_conducting_interview_stage | RED (R1/E) |
| M15 | SKILL 조사 상한 절의 G9 한 줄 삭제 | test_saturation_reference | RED (G9) |
| M16 | saturation.md 의 `최근 조사 두 번` 삭제 | test_saturation_reference | RED (AC4) |
| M17 | saturation-judge.md `tools:` 에 `, Write` 추가 | test_research_agents_frontmatter | RED (Law 2) |
| M18 | SKILL R2 에 `(round 1–2)` 되살림 | test_conducting_interview_stage | RED (R1/D) |
| M19 | saturation-judge.md 의 `research_outputs` 슬롯 kind 를 `orchestrator_framing` 으로 | test_research_agents_frontmatter · shared test_agent_input_slots | RED |
| M20 | coverage-mapper.md 규칙 5 를 옛 `면 \`neglect_flag: false\`` 로 | test_coverage_mapper_frontmatter | RED (R1/C10) |

변이를 손으로 할 때는 `python3 -I - <<'PY'` 로 파일을 읽어 `str.replace` 한 뒤 `assert` 로 **바뀌었는지**를 확인한다(바뀐 곳 0 이면 계측기 고장이다 — 그 행은 「측정 못 함」으로 적고 RED 로 세지 않는다).

- [ ] **Step 3: 결과 표를 남긴다** — `~/.claude/sdd-mirror/r1-impl/mutation.md` 에 `#` · 변이 · 대상 · 결과(RED/GREEN/측정 못 함) · 실패 줄 하나. GREEN 이 하나라도 있으면 그 락을 고치고(새 커밋) 그 변이를 다시 잰다. 클론은 끝나면 지운다(`rm -rf "$MUT"` — 경로를 echo 로 먼저 확인).

---

### Task 9: 릴리스 표면 — 버전 · CHANGELOG · README · 줄 상한

**Files:**
- Modify: `plugins/spec-distill/.claude-plugin/plugin.json`
- Modify: `plugins/spec-distill/CHANGELOG.md`
- Modify: `plugins/spec-distill/README.md` (스위치 목록 · Principles · RC19 공시)
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh` (`SKILL_LINE_CAP`)

- [ ] **Step 1: 버전을 정한다**

```bash
git fetch origin
git show origin/main:plugins/spec-distill/.claude-plugin/plugin.json | grep '"version"'
```
그 값의 minor + 1, patch 0 을 `V` 로 쓴다(지금이면 `5.5.0`). main 이 그사이 움직였으면 먼저 `git merge --no-edit origin/main` 하고 Task 7 Step 1 을 다시 돈다.

- [ ] **Step 2: plugin.json · CHANGELOG**

`plugin.json` 의 `"version"` 을 `V` 로. CHANGELOG 맨 위(`# Changelog` 다음 빈 줄 뒤)에:
```markdown
## [V] — 2026-10-12

### Added
- `agents/saturation-judge.md` — floor 다섯이 닫힌 뒤 조사 원문에서 새로움을 직접 매겨 포화를 판정하는 읽기 전용 판정자(`tools: Read, Grep, Glob`). 최근 조사 두 번이 결정을 바꾸지도 열지도 않았을 때만 「포화」다.
- `agents/repo-researcher.md` — 레포 질문 하나를 조사 주장 계약 모양으로 답하는 읽기 전용 조사자. C43 경로 (a) 에서 본체 직접 확인 대신 부를 수 있다.
- 조사 호출 상한 `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT`(기본 20) · 포화 판정 상한 `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT`(기본 5). 닿으면 사용자에게 연장 · 판정 · 종료를 묻는다. 첫 조사 전에 규모를 한 줄로 알린다(승인은 묻지 않는다).
- `check_brief.py gate` 의 `saturation_failures` — audit §2 의 마지막 포화 판정 줄이 판정자 「포화」 · 사용자 종료 · 사용자 판단 포화(advisory)일 때만 통과한다.
- `skills/spec-interview/references/saturation.md` — 상한 도달 · 포화 판정 · 반복 감지 · 판정 불가 · 판정 상한 · audit §2 줄.

### Changed
- 조사 subagent 넷은 자격 · 예산 없이 결정에 닿을 수 있을 때마다 부른다. 첫 호출 필수 자리(coverage-mapper R1 전 · blind-spot-prober 첫 전이)는 하한으로 남는다.
- 인터뷰 종료는 이중이다 — floor 다섯이 닫히고 포화 판정이 「포화」이거나 사용자가 끝낸다.
- 의례 R1 은 「사용자 말 그대로」다 — root_problem 을 사용자 원문 인용으로 닫는다.
- steelman 재호출은 횟수가 아니라 입력의 반복으로 멈춘다. 되묻기 상한 대신 「이 주제를 더 파기」 선택지를 둔다. landscape 시점 강제를 뺐다(≥1회 하한 유지). coverage-mapper 는 floor 가 닫혀도 부를 수 있고 낮은 confidence 가 neglect 신호를 끄지 않는다.
- state `orchestration` — `research_dispatches` · `research_limit` · `saturation_limit` · `research_log` · `saturation_log`. 옛 카운터 값은 이월한다.

### Removed
- C44 Dialectic Rhythm Guard · `non_user_streak` · `open_decisions[].touched` · `DEVBREW_SPEC_DISTILL_RHYTHM_GUARD_THRESHOLD`(kill switch 가 아니라 임계 조정이다). coverage-mapper · blind-spot-prober 의 재호출 자격 · 예산과 그 카운터 `coverage_mapper_dispatches` · `blind_spot_dispatches`. 의례 R1 「Problem Reframe」과 닫힘 발화 「재구성 동의 S」. 사용자가 결정한 재건(2026-10-12)이라 deprecation 창을 두지 않는다.
```

- [ ] **Step 3: README**

`### 스위치 목록` 의 `DEVBREW_SPEC_DISTILL_DISABLE_RECRITIC` 줄 바로 아래에:
```markdown
- `DEVBREW_SPEC_DISTILL_RESEARCH_LIMIT=<n>` (V) — interview 조사 subagent 호출 상한의 시작값(기본 20, 양의 정수가 아니면 20 과 한 줄 공시). 닿으면 연장 · 판정 · 종료를 묻는다. 끄는 스위치가 아니다. 이 상한이 사슬 전체의 바깥 조사 중 subagent 몫을 묶고(Phase 0 은 웹을 보지 않는다), 본체 직접 웹 검색은 라운드 규약(질문 하나 · 답 하나)이 묶는다.
- `DEVBREW_SPEC_DISTILL_SATURATION_LIMIT=<n>` (V) — 포화 판정자 호출 상한의 시작값(기본 5). floor 가 닫힌 뒤 판정 고리가 사용자 턴 없이 도는 것을 묶는다.
```
(`(V)` 는 Step 1 의 버전 문자열로 바꾼다.)

`## Principles Instantiated` 의 `### Three Laws` 끝(`- **Law 1 (Clarity) — 조사가 방향에 닿는가 (4.4.0)** …` 문단 다음)에:
```markdown
- **Law 1 · Law 2 — 멈춤의 주인은 독립 판정자 (V)** — 인터뷰가 한 번에 닫지 않고 결정에 닿는 새 사실이 없을 때까지 조사한다. 그 «없음» 을 조사하는 모델이 아니라 쓰기 권한 없는 `saturation-judge` 가 조사 원문에서 직접 판정하고, 「충분해 보인다」는 근거가 아니다. 구조 게이트(`check_brief.py` `saturation_failures`)가 판정 없는 종료를 거절한다.
```
`### Anti-pattern 회피` 의 AP16 줄 old `- **AP16 (Unbounded autonomy)** — 재리뷰 상한 2 (…), kill switch.` 의 `, kill switch.` → `, 조사 호출 상한(기본 20) · 포화 판정 상한(기본 5) · 본체의 반복 감지(같은 빈 곳이면 사용자에게), kill switch.`

- [ ] **Step 4: SKILL 줄 상한을 조인다**

```bash
own=$(awk '/^<!-- plain-language:begin -->$/{s=1} s==0{n++} s==2{s=0; if ($0 != "") n++; next} /^<!-- plain-language:end -->$/{s=2} END{print n+0}' plugins/spec-distill/skills/spec-interview/SKILL.md)
echo "own=$own new_cap=$((own + 8))"
```
`new_cap` 이 504 보다 작으면 TCIS 의 `SKILL_LINE_CAP=504` 를 그 값으로 바꾸고, 그 위 주석 끝에 `# 2026-10-12 R1: 실측 <own> + 8 로 조였다.` 한 줄을 더한다. 504 이상이면 값은 그대로 두고 커밋 메시지에 이유를 적는다.

- [ ] **Step 5: 돌려서 통과를 본다**

```bash
export PYTHONDONTWRITEBYTECODE=1
for t in shared/tests/test_changelog_integrity.sh plugins/spec-distill/tests/test_readme_sync.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh \
         plugins/spec-distill/tests/test_stale_terms.sh plugins/spec-distill/tests/test_rereview_cap_consistency.sh plugins/spec-distill/tests/test_brief_review_meta.sh; do
  printf '%s: ' "$t"; bash "$t" 2>&1 | tail -1; done
```

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/CHANGELOG.md plugins/spec-distill/README.md \
  plugins/spec-distill/tests/test_conducting_interview_stage.sh
git commit -m "$(cat <<'MSG'
chore(spec-distill): R1 릴리스 표면 — 버전 · CHANGELOG · README 공시 · 줄 상한

Spec: docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 10: 설계문서의 어긋남을 본문 쪽으로 맞춘다 (문서만)

**Files:**
- Modify: `docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md`

결정(confirmed)은 바꾸지 않는다. 같은 문서 안에서 본문 결정과 어긋난 문장만 본문 쪽으로 고친다. 사용자에게 diff 를 보이고 리뷰 skip 여부를 묻는 자리는 지휘 세션이 맡는다(이 Task 는 편집 · 커밋까지).

- [ ] **Step 1: 고친다**

- AC6 → `- **AC6** \`check_brief.py gate\` 가 audit §2 의 마지막 포화 판정 줄로 거절한다: \`포화\` 통과 · \`사용자 판단 포화(@S<n>)\` advisory 통과(S 실재) · \`사용자 종료(@S<n>)\` 통과(S 실재) · 줄 없음 실패 · \`아직\` 실패(반복 빈 곳 재조사 포함) · \`판정 불가(…) — 조사 계속(@S<n>)\` 실패 · 형식 밖 실패. 케이스마다 그 결과를 낸다(§5).`
- AC5 끝에 덧붙인다: ` 첫 조사 subagent dispatch 직전의 규모 한 줄(G9)이 SKILL 조사 상한 절에 있고 승인을 묻지 않는다. 포화 판정 상한 도달 한 줄과 세 선택지가 \`references/saturation.md\` 에 있다.`
- §8 의 `\`상한 연장\`` → `\`상한 도달 … — 사용자 선택 S<m>: 연장\`(연장 뒤 한도는 state \`research_limit\`)`
- `### 재결정` 의 `판정자의 반복 감지` → `인터뷰 본체의 반복 감지(판정자가 낸 빈 곳을 이전 빈 곳과 비교)`. **이 소절은 엔진 결정 줄이 붙는 자리다** — 편집 뒤 결정 줄(D…)은 건드리지 않는다.
- 번호 대조 «chroma-context-rot» 행 → `| «chroma-context-rot» | 반영 | §3 — 판정자는 조사 원문 전량을 받는다(본체 요약을 거치지 않기 위해서이고 긴 입력 위험은 감수한다), 중립 근거 |`. «context-engineering» 행 → `| «context-engineering» | 반영 | §4 — 조사 산출 원문은 state 본문에 두고 판정자에 그대로 넘긴다 |`
- §2 사실 항목 RC19 줄의 `그 상한이 이제 \`research_limit\`(기본 20, 연장 가능)이라는 사실을 README 에 공시한다.` → `조사 subagent 몫의 상한이 이제 \`research_limit\`(기본 20, 연장 가능)이고 본체 직접 웹 검색은 라운드 규약이 묶는다는 사실을 README 에 공시한다.`

- [ ] **Step 2: 번호 대조가 깨지지 않았는지 본다**

```bash
python3 plugins/spec-distill/scripts/check_bundle_coverage.py docs/superpowers/roadmaps/2026-10-11-persistent-explore-pm-decompose/R1.md docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md; echo rc=$?
```
Expected: `rc=0`.

- [ ] **Step 3: 커밋** (트레일러 없음 — 설계문서 자신이다)

```bash
git add docs/superpowers/specs/2026-10-12-interview-persistent-explore-design.md
git commit -m "$(cat <<'MSG'
docs(spec-distill): R1 설계문서 안의 어긋남을 본문 결정 쪽으로 맞춘다

AC6 을 §5 로, §8 · 재결정 문단 · 번호 대조 두 행 · RC19 공시를 본문으로 고치고 AC5 에
G9 · 판정 상한을 더했다. 결정은 바꾸지 않았다.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
)"
```

---

### Task 11: 마무리 검증

- [ ] **Step 1: 전체 스위트를 baseline 과 비교한다 (AC15)**

```bash
bash ~/.claude/sdd-mirror/r1-impl/run_suite.sh ~/.claude/sdd-mirror/r1-impl/baseline-after.txt
comm -13 ~/.claude/sdd-mirror/r1-impl/baseline-before.txt ~/.claude/sdd-mirror/r1-impl/baseline-after.txt
comm -23 ~/.claude/sdd-mirror/r1-impl/baseline-before.txt ~/.claude/sdd-mirror/r1-impl/baseline-after.txt
```
Expected: 첫 `comm` 빈 출력(새 실패 0). 둘째는 이 작업이 고친 선재 실패(있으면 보고).

- [ ] **Step 2: 새 agent 둘을 장난감 입력으로 한 번씩 부른다 (Verification 6)**

설치본(`~/.claude/plugins/cache/devbrew/spec-distill/5.3.0`)에는 새 agent 가 없다. 리포 플러그인을 직접 싣는 헤드리스 세션으로 시도한다:
```bash
cd /Users/jeonghokim/Downloads/devbrew/.claude/worktrees/interview-persistent-explore
claude -p --plugin-dir plugins/spec-distill "Agent 도구로 subagent_type \"spec-distill:saturation-judge\" 를 한 번 불러라. prompt: \"<decisions>OQ1: 캐시 범위 [열림]</decisions> <research_outputs>### 조사 1 — coverage-mapper · R1
derived_dimensions: []</research_outputs> <ledger_state>root_problem closed</ledger_state> 판정 기준대로.\" 그 agent 의 출력 원문만 그대로 내라." 2>&1 | head -40
```
Expected: `verdict: not_saturated`(두 항목 미만) · `kind: confirm` 빈 곳 하나가 있는 YAML. `repo-researcher` 도 같은 방식으로 질문 「`check_brief.py` 의 `saturation_failures` 는 어느 줄을 보나」로 한 번 — `repo_claims` 에 `scripts/check_brief.py` 경로가 있어야 한다. 헤드리스가 agent 를 못 찾거나 Agent 도구를 거부하면 지어내지 말고 「확인 못 함 — <원 출력 첫 줄>」로 보고한다.

- [ ] **Step 3: 깨끗한 트리와 브랜치를 확인한다**

```bash
git status --short
git log --oneline origin/main..HEAD
git log origin/main..HEAD --format='%H %s' | while read -r h s; do git log -1 --format=%B "$h" | grep -q '^Spec: ' || echo "트레일러 없음: $s"; done
```
Expected: 미커밋 없음. 「트레일러 없음」은 merge 커밋 · Task 10 문서 커밋 · 설계 단계 커밋만.
