# agent `model:` 핀 해제 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** devbrew agent 20개의 frontmatter 에서 `model: inherit` 를 제거해 사용자의 `CLAUDE_CODE_SUBAGENT_MODEL` 설정이 통과되게 하고, 그 사실을 락·규약·문서가 일관되게 말하게 한다.

**Architecture:** 락을 먼저 반전(「`inherit` 실재」→「`model` 키 부재」)해 RED 를 만든 뒤 agent 를 고쳐 GREEN 으로 돌린다(TDD 양성 대조). 문서·skill 본문의 `inherit` 서술은 새 어휘 「tier-unpinned / 티어 비고정」으로 통일한다. plugin-audit 의 구조 검사 필터는 「`model` 누락 단독 = 규약 준수」로 분기한다. 변이 스크립트 한 개가 반전된 락 전부의 이빨을 증명한다.

**Tech Stack:** bash 3.2(macOS) 셸 락 + `shared/tests/assert.sh` 헬퍼, python `unittest`, `claude -p` 헤드리스 프로브.

**Spec:** `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md`

## Global Constraints

- 브랜치 `feature/agent-model-unpin` (이미 존재, spec 커밋 82319b6 위). 커밋은 Conventional Commits, 본문 끝에 `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` + `Claude-Session: https://claude.ai/code/session_012WCfjnRDSyNnxmW2nQMMgq`.
- 플러그인 4개 **minor** bump: `agent-transparency 0.3.2→0.4.0`, `plugin-audit 0.8.2→0.9.0`, `quality-gates 7.2.1→7.3.0`, `spec-distill 0.53.1→0.54.0`. CHANGELOG 날짜 `2026-09-06`.
- 락은 반전이지 삭제가 아니다 (spec C2). `model` 키 검출 regex 는 모든 락에서 **같은 문자열**: `MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"` (grep -E).
- 새 어휘: 영문 `tier-unpinned`, 국문 「티어 비고정」. `inherit` 를 현재 사실로 서술하는 문장은 남기지 않는다 (spec AC11). CHANGELOG·`docs/archive/**` 는 이력이라 건드리지 않는다.
- agent 파일에 이 변경의 출처·정당화를 적지 않는다 (AP18).
- `~/.claude/settings.json` 은 편집하지 않는다. 리포 `.claude/settings.json` 에 환경변수를 넣지 않는다.
- 셸 테스트 실행은 리포 루트에서 `bash <path>`; rc 0 = GREEN. python 은 `python3 -m unittest <module-path>` (spec-distill/plugin-audit 은 `-m unittest` 만 — pytest 금지).
- 스크래치는 `/private/tmp/claude-501/-Users-jeonghokim-Downloads-devbrew/3a0f644e-9b82-4f4b-b90c-248dae95e21d/scratchpad` (아래 `$SCR`).

---

## File Structure

| 파일 | 책임 |
|---|---|
| `plugins/*/agents/*.md` (20) | frontmatter 에서 `model` 키 삭제. `artifact-critic.md`·`artifact-adversarial.md` 는 본문 `inherit` 서술도 |
| `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh` (rename) | 리포 전수 스윕 — `model` 키 존재 = RED, 하한 ≥10 |
| quality-gates per-agent 락 8 · spec-distill 락 6 | 각 agent 의 `model` 키 부재 단언 |
| `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` | 규약 문장 앵커 교체 |
| `plugins/quality-gates/tests/test_agent_model_mutation.sh` (신규) | C2 변이 (a)~(e) + 하한 (f) 로 스윕·per-agent 락의 이빨 증명 |
| `plugins/plugin-audit/scripts/check-plugin-structure.sh` + `tests/test_check_plugin_structure.py` | `model` 누락 단독 = 규약 준수 분기 + 테스트 2건 |
| `docs/plugin-authoring.md`, `plugins/quality-gates/README.md`, skills/scripts 본문 | `inherit` 서술 → 새 사실 |
| `plugin.json` ×4, `CHANGELOG.md` ×4 | 버전·이력 |

---

### Task 0: baseline — 실패 단언 집합 기록

**Files:**
- Create: `$SCR/baseline_fail_set.txt`

**Interfaces:**
- Produces: `$SCR/run_all_locks.sh` — 리포 셸 락 전수를 돌려 `파일\t✗메시지` 줄 집합을 낸다. Task 11 이 같은 스크립트로 사후 집합을 만들어 비교한다.

- [ ] **Step 1: 러너 작성**

```bash
SCR=/private/tmp/claude-501/-Users-jeonghokim-Downloads-devbrew/3a0f644e-9b82-4f4b-b90c-248dae95e21d/scratchpad
cat > "$SCR/run_all_locks.sh" <<'EOF'
#!/usr/bin/env bash
# 리포 루트에서 실행. 셸 락 전수 → "파일<TAB>✗ 메시지" 를 stdout 에 정렬해 낸다.
cd "$(git rev-parse --show-toplevel)" || exit 1
for t in plugins/*/tests/test_*.sh shared/tests/test_*.sh; do
  bash "$t" 2>/dev/null | grep -E '^[[:space:]]*✗' | sed "s|^|$t	|"
done | sort
EOF
chmod +x "$SCR/run_all_locks.sh"
```

- [ ] **Step 2: baseline 캡처**

Run: `bash $SCR/run_all_locks.sh > $SCR/baseline_fail_set.txt; wc -l $SCR/baseline_fail_set.txt`
Expected: 줄 수가 찍힌다 (0 이어도 됨). 이 파일이 AC9 의 비교 대상이다.

- [ ] **Step 3: 커밋 없음** — 스크래치 파일이다.

---

### Task 1: 스윕 락 rename + 반전

**Files:**
- Rename: `plugins/quality-gates/tests/test_agent_model_inherit_sweep.sh` → `plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh`
- Modify: `docs/superpowers/plans/2026-09-03-adjudication-topology-baseline.md:35` (이름 인용 1건 — plans 는 이력이 아니라 살아 있는 목록이므로 갱신)

**Interfaces:**
- Produces: 락 하나. 규칙 0(하한 ≥10) · 규칙 1(`MODEL_KEY` 매치 0). Task 8 의 변이 스크립트가 이 파일명을 부른다.

- [ ] **Step 1: rename**

```bash
git mv plugins/quality-gates/tests/test_agent_model_inherit_sweep.sh plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh
```

- [ ] **Step 2: 본문 전체를 아래로 교체**

```bash
#!/usr/bin/env bash
# 구조적 보증 — `plugins/*/agents/*.md` **전부**가 frontmatter 에 `model` 키를 두지 않는다.
#
# 왜 별도 스윕인가 (2026-08-04 /qg 라운드 1, pr-test-analyzer 적발):
# 모델 티어는 플러그인마다 손으로 열거한 per-agent 테스트로만 지켜지고 있었다.
# 열거는 공간에도 시간에도 fail-open이다: 내일 추가될 플러그인의 agent를 오늘
# 열거할 수 없다. 이 리포가 `tools:`를 denylist가 아니라 allowlist로 쓰는 것과 같은 논리다.
#
# 왜 «키 부재»인가 (CLI 2.1.261 실측, 2026-09-06): 리터럴 티어는 세션 모델 선택을
# 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을
# 덮어쓴다. 키가 없어야 하니스가 「사용자 설정 → 세션 모델」 순으로 위임한다.
# 어느 값이든 하니스가 티어를 정하는 것이므로 키 자체를 두지 않는다.
#
# 범위 밖: 외부(비-devbrew) 플러그인의 하드코딩 핀은 존중한다 — 이 스윕은
# 이 리포가 소유한 `plugins/` 아래만 본다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

# 따옴표 키(`"model":`)·콜론 앞 공백(`model :`)·공백 없음(`model:inherit`)을 전부 잡는다 —
# YAML 이 유효하다고 보는 표기는 전부 하니스에도 유효하다.
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"

shopt -s nullglob
agents=(plugins/*/agents/*.md)
shopt -u nullglob

# ── 스캔이 실제로 무언가를 봤는가 (vacuous-pass 방지) ────────────────────────
# glob이 아무것도 매치하지 않으면 아래 루프가 0회 돌고 전부 통과한다 — "키가 하나도
# 없다"와 "아무것도 스캔하지 않았다"가 구별되지 않는 fail-open이다.
if [ "${#agents[@]}" -ge 10 ]; then
  ok "0 — 스윕이 agent ${#agents[@]}개를 실제로 열었다 (vacuous pass 아님)"
else
  no "0 — 스윕이 본 agent가 ${#agents[@]}개뿐 — glob이 깨졌거나 리포 구조가 바뀌었다"
  finish; exit
fi

fm_of() { awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$1"; }

keyed=()
for f in "${agents[@]}"; do
  if fm_of "$f" | grep -qE "$MODEL_KEY"; then
    keyed+=("$f: $(fm_of "$f" | grep -m1 -E "$MODEL_KEY")")
  fi
done

[ "${#keyed[@]}" -eq 0 ] && ok "1 — frontmatter 에 model 키를 둔 agent 0개" || {
  no "1 — frontmatter 에 model 키를 둔 agent ${#keyed[@]}개 (리터럴이든 inherit 이든 하니스가 티어를 정한다)"
  printf '      %s\n' "${keyed[@]}"; }
finish
```

- [ ] **Step 3: 인용 갱신**

`docs/superpowers/plans/2026-09-03-adjudication-topology-baseline.md:35` 의 `test_agent_model_inherit_sweep.sh` → `test_agent_model_unpinned_sweep.sh`.

- [ ] **Step 4: RED 확인 (agent 에 아직 inherit 가 있으므로)**

Run: `bash plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh; echo rc=$?`
Expected: `✗ 1 — frontmatter 에 model 키를 둔 agent 20개`, rc=1.

- [ ] **Step 5: 커밋**

```bash
git add -A plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh docs/superpowers/plans/2026-09-03-adjudication-topology-baseline.md
git commit -m "test(quality-gates): agent model 스윕 락을 «키 부재» 단언으로 반전 (RED 의도)"
```

---

### Task 2: quality-gates per-agent 락 8개 반전

**Files:**
- Modify: `plugins/quality-gates/tests/test_adversarial_persona.sh:30-31`
- Modify: `plugins/quality-gates/tests/test_security_reviewer_persona.sh:27`
- Modify: `plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh:2,8-9`
- Modify: `plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh:2,8-9`
- Modify: `plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh:24-25`
- Modify: `plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh:17-22`
- Modify: `plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh:3,13`
- Modify: `plugins/quality-gates/tests/test_adversarial_model_consistency.sh:1-16,33-35,59-63`

**Interfaces:**
- Consumes: `MODEL_KEY` 문자열 (Global Constraints).
- Produces: 8 파일 각각 ≥1 RED 상태. README 앵커 두 개의 새 리터럴 — `(Phase 1.5, tier-unpinned)`, `` `adversarial` agent declares no `model` key `` — Task 6 이 README 에 그대로 써야 한다.

- [ ] **Step 1: `test_adversarial_persona.sh`** — 30–31행 두 줄을 아래로 교체 (헤더 3행의 `model: inherit /` 는 `model 키 부재 /` 로)

```bash
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$PERSONA" "$MODEL_KEY" "frontmatter 에 model 키 없음 (하니스가 티어를 정하지 않는다 — 사용자 설정 → 세션 모델)"
```

- [ ] **Step 2: `test_security_reviewer_persona.sh`** — 27행을 아래로 교체

```bash
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$PERSONA" "$MODEL_KEY" "frontmatter 에 model 키 없음 (하니스가 티어를 정하지 않는다)"
```

- [ ] **Step 3: `test_artifact_critic_frontmatter.sh`** — 2행 주석을 `# T8/AC4/AC13a-b — artifact-critic: tier-unpinned (frontmatter 에 model 키 없음) + read-only.` 로, 8–9행을 아래로 교체

```bash
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$A" "$MODEL_KEY" "frontmatter 에 model 키 없음 (tier-unpinned — 사용자 설정 → 세션 모델)"
```

- [ ] **Step 4: `test_artifact_adversarial_frontmatter.sh`** — 2행을 `# T9/AC4/AC13a-b — artifact-adversarial: tier-unpinned + read-only + verdict schema.` 로, 8–9행을 Step 3 과 같은 두 줄로 교체.

- [ ] **Step 5: `test_test_scope_validator_frontmatter.sh`** — 24–25행을 아래로 교체

```bash
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_not_grep "$FM" "$MODEL_KEY" "frontmatter 에 model 키 없음 (tier-unpinned)"
```

- [ ] **Step 6: `test_pr_understanding_builder_frontmatter.sh`** — 17–22행(두 grep 블록)을 아래로 교체. 3–4행 주석의 `or the model line` 은 `or adding a model key` 로.

```bash
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$FM" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (사용자 설정 → 세션 모델)"
```

- [ ] **Step 7: `test_runtime_verifier_frontmatter.sh`** — 3행 `model inherit,` → `frontmatter 에 model 키 없음,`. 13행을 아래로 교체

```bash
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$FILE" "$MODEL_KEY" "frontmatter 에 model 키 없음 (tier-unpinned)"
```

- [ ] **Step 8: `test_adversarial_model_consistency.sh`** — 헤더(1–16행)를 아래로 교체

```bash
#!/usr/bin/env bash
# Drift guard — adversarial 리뷰어의 모델 선언이 세 곳에서 일관되게 «키 부재»인지
# 확인한다. adversarial은 Gate 2의 단일 model-based 판정 병목이다(synthesizer는
# 결정론 스크립트). 하니스가 여기서 티어를 정하면 안 된다 — 리터럴 핀은 세션 선택을
# 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을
# 덮어쓴다(CLI 2.1.261 실측, 2026-09-06). 키가 없어야 「사용자 설정 → 세션 모델」로 위임된다.
#
# 이전 버전들은 이 자리에서 `opus` 핀을, 그 다음엔 `inherit` 를 옹호했다. 둘 다
# 하니스가 티어를 정하는 값이었다.
#
# 세 곳: frontmatter(키 부재) · SKILL dispatch(model= override 부재) · README(같은 사실 서술).
#
# Single source of truth: agents/adversarial.md frontmatter (`model` 키 없음).
# SKILL dispatch는 model override를 pin하지 않는다 — frontmatter에 의존한다.
```

33–35행을 아래로 교체:

```bash
# 1. Frontmatter is the single source of truth — model 키 부재.
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
assert_file_absent "$AGENT" "$MODEL_KEY" "adversarial.md frontmatter 에 model 키 없음"
```

59–63행을 아래로 교체:

```bash
# 3. README must describe adversarial as tier-unpinned, consistently in both the
#    model note and the Gate 2 phase diagram.
assert_file_grep "$README" 'quality-gates:adversarial[[:space:]]+\(Phase 1\.5, tier-unpinned\)' "README phase diagram tags Adversarial as tier-unpinned"
assert_file_grep "$README" '`adversarial` agent declares no `model` key' "README model note states no model key"
assert_file_absent "$README" '`adversarial` agent uses `model: (inherit|opus|sonnet|haiku)`' "README model note names no tier"
```

- [ ] **Step 9: 8 파일 각각 RED 확인**

Run:
```bash
for t in test_adversarial_persona test_security_reviewer_persona test_artifact_critic_frontmatter test_artifact_adversarial_frontmatter test_test_scope_validator_frontmatter test_pr_understanding_builder_frontmatter test_runtime_verifier_frontmatter test_adversarial_model_consistency; do printf '%s: ' $t; bash plugins/quality-gates/tests/$t.sh | grep -c '✗'; done
```
Expected: 8줄 전부 ≥1 (adversarial_model_consistency 는 README 앵커 2개까지 ≥3).

- [ ] **Step 10: 커밋**

```bash
git add plugins/quality-gates/tests/
git commit -m "test(quality-gates): per-agent 모델 락 8개를 «model 키 부재» 단언으로 반전 (RED 의도)"
```

---

### Task 3: spec-distill 락 6개 반전

**Files:**
- Modify: `plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh:11-15`
- Modify: `plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh:13-17`
- Modify: `plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh:16-27`
- Modify: `plugins/spec-distill/tests/test_steelman_builder_scope.sh:15-19`
- Modify: `plugins/spec-distill/tests/test_brief_agents.sh:3,21-23`
- Modify: `plugins/spec-distill/tests/test_seed_agents.sh:144-148`

- [ ] **Step 1: blind_spot_prober · coverage_mapper · steelman_builder_scope** — 각 파일의 「모델 티어 양방향 락」 주석 + 두 grep 블록(4~5줄)을 아래로 교체 (steelman 은 변수명이 `$fm` 소문자)

```bash
# 모델 티어 락 — frontmatter 에 model 키를 두지 않는다. 리터럴 핀은 세션 선택을,
# `inherit` 는 사용자의 subagent 기본 티어 설정을 덮어쓴다(CLI 2.1.261 실측).
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$FM" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (tier-unpinned)"
```

- [ ] **Step 2: `test_spec_reviewer_frontmatter.sh`** — 16–27행(주석 6줄 + grep 두 블록)을 아래로 교체

```bash
# 모델 티어 락 — frontmatter 에 model 키를 두지 않는다.
# 이 리뷰어는 devbrew에서 가장 많이 dispatch되는 리뷰어인데 한때 `model: sonnet`으로
# 핀돼 있었다(opus-5 세션이 sonnet-5 리뷰어를 받았다). 그 뒤 `inherit` 로 바꿨으나
# `inherit` 도 사용자의 subagent 기본 티어 설정을 덮어쓴다(CLI 2.1.261 실측).
MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
grep -qE "$MODEL_KEY" <<<"$FM" \
  && no "frontmatter 에 model 키가 있다 — 하니스가 티어를 정한다" \
  || ok "frontmatter 에 model 키 없음 (tier-unpinned)"
```

- [ ] **Step 3: `test_brief_agents.sh`** — 3행 `AC5(model: inherit)` → `AC5(model 키 부재)`. 21–23행을 아래로 교체

```bash
  # AC5 — model 키 부재 (리터럴 핀도 inherit 도 하니스가 티어를 정하는 값)
  MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
  grep -qE "$MODEL_KEY" <<<"$FM" \
    && no "$a: frontmatter 에 model 키가 있다" || ok "$a: model 키 없음"
```

- [ ] **Step 4: `test_seed_agents.sh`** — 144–148행을 아래로 교체

```bash
  # model 키 부재 — 형제 zero-tool 둘(brief-critic·brief-readback)의 정본과 같다.
  MODEL_KEY="^[\"']?model[\"']?[[:space:]]*:"
  printf '%s\n' "$fm" | grep -qE "$MODEL_KEY" \
    && no "$a: frontmatter 에 model 키가 있다 — 형제 정본은 키 부재다" \
    || ok "$a: model 키 없음"
```

- [ ] **Step 5: 6 파일 각각 RED 확인**

Run:
```bash
for t in test_blind_spot_prober_frontmatter test_coverage_mapper_frontmatter test_spec_reviewer_frontmatter test_steelman_builder_scope test_brief_agents test_seed_agents; do printf '%s: ' $t; bash plugins/spec-distill/tests/$t.sh | grep -c '✗'; done
```
Expected: 6줄 전부 ≥1 (brief_agents 3, seed_agents 2 — agent 수만큼).

- [ ] **Step 6: 커밋**

```bash
git add plugins/spec-distill/tests/
git commit -m "test(spec-distill): 모델 락 6개를 «model 키 부재» 단언으로 반전 (RED 의도)"
```

---

### Task 4: 규약 문장 락 교체 (governance AC8d)

**Files:**
- Modify: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh:171-184`

**Interfaces:**
- Produces: 새 처방 리터럴 `**agent frontmatter 에 `model` 키를 두지 않는다.**` — Task 6 이 `docs/plugin-authoring.md` 에 그대로 써야 한다.

- [ ] **Step 1: 171–184행(AC8d 블록 전체, `finish` 직전까지)을 아래로 교체**

```bash
# --- AC8d: docs/plugin-authoring.md 의 agent model 규약 — «키 부재» ---
# 2026-09-06 (CLI 2.1.261 실측): `inherit` 도 사용자의 subagent 기본 티어 설정을
# 덮어쓴다. 규약은 「키를 두지 않는다」로 뒤집혔다. 옛 처방(`inherit`)과 옛 음성
# 어법 regex(inherit 줄의 금지 어법 → RED)는 이 방향에서 반대로 운다 — 제거하고
# 리터럴 두 개로 방향을 못 박는다.
NEW_RULE='**agent frontmatter 에 `model` 키를 두지 않는다.**'
OLD_RULE='**agent `model:`은 `inherit`.**'
if grep -qF "$NEW_RULE" "$AUTHORING"; then
  ok "AC8d: plugin-authoring.md 에 «model 키 부재» 처방 존재"
else
  no "AC8d: «model 키 부재» 처방 문장이 없다 — 신규 플러그인이 티어를 핀할 수 있다"
fi
if grep -qF "$OLD_RULE" "$AUTHORING"; then
  no "AC8d: 옛 처방(`inherit`)이 되살아났다 — 규약이 뒤집혔다"
else
  ok "AC8d: 옛 inherit 처방 없음"
fi
if grep -qE '^model: inherit' "$AUTHORING"; then
  no "AC8d: authoring 문서에 model: inherit 코드 예시가 있다"
else
  ok "AC8d: model: inherit 코드 예시 없음"
fi
finish
```

- [ ] **Step 2: RED 확인** — Run: `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh | grep AC8d`
Expected: 첫 줄 ✗(새 문장 없음), 둘째 줄 ✗(옛 문장 있음), 셋째 ✓.

- [ ] **Step 3: 커밋**

```bash
git add plugins/quality-gates/tests/test_governance_no_capability_caps.sh
git commit -m "test(quality-gates): 규약 문장 락을 «model 키 부재» 처방 앵커로 교체 (RED 의도)"
```

---

### Task 5: agent 20개 — `model` 키 삭제 + 본문 3곳

**Files:**
- Modify: `plugins/*/agents/*.md` 20개 (spec Files to Modify 목록 그대로)

**Interfaces:**
- Produces: Task 1–3 의 락 15 파일 GREEN.

- [ ] **Step 1: frontmatter 한 줄 삭제 (20개 일괄)**

```bash
for f in plugins/*/agents/*.md; do
  python3 - "$f" <<'PY'
import sys,re
p=sys.argv[1]; t=open(p,encoding='utf-8').read()
m=re.match(r'^---\n(.*?)\n---\n',t,re.S); fm=m.group(1)
fm2='\n'.join(l for l in fm.split('\n') if not re.match(r'''^["']?model["']?\s*:''',l))
assert fm2!=fm, p
open(p,'w',encoding='utf-8').write(t[:m.start(1)]+fm2+t[m.end(1):])
PY
done
git diff --stat | tail -1
```
Expected: `20 files changed, 0 insertions(+), 20 deletions(-)`.

- [ ] **Step 2: `artifact-critic.md` 본문 두 곳**

3행 description: `inherit-tier critic` → `tier-unpinned critic`.
18행: `You run at the session tier (inherit) because critiquing prose` → `You run tier-unpinned — the user's subagent setting, else the session tier — because critiquing prose`.

- [ ] **Step 3: `artifact-adversarial.md` 3행** — `inherit-tier adversary` → `tier-unpinned adversary`.

- [ ] **Step 4: GREEN 확인 (Task 1–3 락 15 파일)**

Run:
```bash
for t in plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh plugins/quality-gates/tests/test_{adversarial_persona,security_reviewer_persona,artifact_critic_frontmatter,artifact_adversarial_frontmatter,test_scope_validator_frontmatter,pr_understanding_builder_frontmatter,runtime_verifier_frontmatter}.sh plugins/spec-distill/tests/test_{blind_spot_prober_frontmatter,coverage_mapper_frontmatter,spec_reviewer_frontmatter,steelman_builder_scope,brief_agents,seed_agents}.sh; do bash "$t" >/dev/null; echo "rc=$? $t"; done
```
Expected: 14줄 전부 rc=0. (`test_adversarial_model_consistency.sh` 는 README 앵커 때문에 Task 6 까지 RED — 정상.)

- [ ] **Step 5: AC1·AC10 확인**

Run: `git ls-files 'plugins/*/agents/*.md' | xargs grep -lE "^[\"']?model[\"']?[[:space:]]*:" | wc -l; git diff --numstat -- plugins/*/agents/ | awk '$1+$2>1'`
Expected: `0`, 그리고 두 번째 명령은 `artifact-critic.md`·`artifact-adversarial.md` 두 줄만.

- [ ] **Step 6: 커밋**

```bash
git add plugins/*/agents/
git commit -m "feat(agents): frontmatter model 키 제거 20개 — 사용자 subagent 설정 → 세션 모델로 위임"
```

---

### Task 6: 규약·README·skill·스크립트 본문의 `inherit` 서술 갱신

**Files:**
- Modify: `docs/plugin-authoring.md:23`
- Modify: `plugins/quality-gates/README.md:52,91,95,96,97,172,176,209`
- Modify: `plugins/quality-gates/skills/critiquing-artifacts/SKILL.md:6,156,157,175,289`
- Modify: `plugins/quality-gates/skills/publishing-pr-understanding/SKILL.md:124`
- Modify: `plugins/quality-gates/skills/quality-pipeline/SKILL.md:243`
- Modify: `plugins/quality-gates/scripts/run_artifact_codex_reviewer.sh:9-10`
- Modify: `plugins/quality-gates/scripts/experiment-model-override.md:16-17`
- Modify: `plugins/quality-gates/tests/e2e-scenarios.md:83,135`

- [ ] **Step 1: `docs/plugin-authoring.md:23`** — 그 bullet 한 줄을 아래로 교체 (24행 하위 bullet 은 그대로)

```markdown
- **agent frontmatter 에 `model` 키를 두지 않는다.** 리터럴 티어(`opus`/`sonnet`/`haiku`)는 세션의 모델 선택을 덮어쓰고, `inherit` 는 사용자의 subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 덮어쓴다 — CLI 2.1.261 실측(2026-09-06, `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md` §A). 키가 없으면 하니스는 「사용자 설정 → 세션 모델」 순으로 위임한다. 어느 값이든 하니스가 티어를 정하는 것이라 P8(Determinism Economy) 위반이다. reference: `plugins/plugin-audit/agents/*.md`.
```

- [ ] **Step 2: `plugins/quality-gates/README.md`**

| 행 | 바꾸기 |
|---|---|
| 52 | `inherit-tier` → `tier-unpinned` |
| 91 | `(sandbox executor — model inherit)` → `(sandbox executor — tier-unpinned)` |
| 95, 96 | `inherit-tier` → `tier-unpinned` |
| 97 | `model: inherit, tools: Read 1개` → `model 키 없음(tier-unpinned), tools: Read 1개` |
| 172 | `` `pr-understanding-builder`는 `model: inherit` — 세션이 쓰는 티어를 그대로 받는다(하니스가 티어를 덮어쓰지 않는다) `` → `` `pr-understanding-builder`는 frontmatter 에 `model` 키가 없다 — 사용자의 subagent 설정, 없으면 세션 티어를 받는다(하니스가 티어를 정하지 않는다) `` |
| 209 | `(Phase 1.5, inherit)` → `(Phase 1.5, tier-unpinned)` |

176행 문단 전체를 아래로 교체:

```markdown
`adversarial` agent declares no `model` key. It is the **single model-based judgment gate** in the Review gate: the Phase 1/2 reviewers emit findings and the synthesizer after it is a deterministic script, so every finding the user sees passed through its verdict. Its persona runs a per-finding 3-gate verification (real? / introduced-by-this-diff? / handled-elsewhere?) plus a severity realist check. The harness does not choose its tier: with no `model` key the subagent resolves to the user's `CLAUDE_CODE_SUBAGENT_MODEL` setting if one is set, else to the session's own model (CLI 2.1.261, measured 2026-09-06). A literal tier would overwrite the session choice; `inherit` would overwrite the user's subagent setting — both directions are the harness deciding. Locked by `tests/test_adversarial_model_consistency.sh` (no `model` key AND no dispatch-time override). Runs ~once per Review gate fix-loop iteration (≤5×).

**Choosing a cheaper tier for devbrew subagents is the user's call, not the plugin's.** Put it in your own settings — for example in `~/.claude/settings.json`:

```json
{ "env": { "CLAUDE_CODE_SUBAGENT_MODEL": "opus" } }
```

Remove the entry to return to the session tier. (`CLAUDE_CODE_SUBAGENT_MODEL_FORCE=1` also exists and overrides even frontmatter pins; devbrew does not recommend it — it flattens dispatch-time discretion and other plugins' pins too.) Note the trade-off you are choosing: on a session stronger than the tier you set, reviewers run one tier below the writer.
```

- [ ] **Step 3: `critiquing-artifacts/SKILL.md`** — 6·156·157·175·289행의 `inherit-tier` → `tier-unpinned` (5곳, 단어 치환).

- [ ] **Step 4: `publishing-pr-understanding/SKILL.md:124`** — `` `model: inherit`이 빌더 frontmatter에 선언돼 있다(여기서 override하지 않음). `` → `` 빌더 frontmatter 에는 `model` 키가 없다(여기서 override 하지 않음 — 사용자 설정 → 세션 티어). ``

- [ ] **Step 5: `quality-pipeline/SKILL.md:243`** — `on the inherited model` → `on the subagent's resolved tier`, 그리고 같은 줄 끝 `(heavier; inherited model)` → `(heavier; subagent's resolved tier)`.

- [ ] **Step 6: `run_artifact_codex_reviewer.sh:9-10`** — `inherit-tier critic 단독` → `tier-unpinned critic 단독`, `"degraded, inherit-tier 단독"` → `"degraded, tier-unpinned 단독"`.

- [ ] **Step 7: `experiment-model-override.md:16-17`** — 「현재 규약」 문장을 아래로 교체

```markdown
> **현재 규약 (2026-09-06)**: 리포 내 모든 agent frontmatter 는 `model` 키를 두지 않는다 — `inherit` 도 사용자의
> subagent 기본 티어 설정(`CLAUDE_CODE_SUBAGENT_MODEL`)을 덮어쓰기 때문이다(CLI 2.1.261 실측). dispatch 시점의 `model` 인자는
```
(그 뒤 「오케스트레이터의 재량이되 …」 문장은 그대로 이어진다.)

- [ ] **Step 8: `e2e-scenarios.md`** — 83행 `` while `inherit` agents show `model: sonnet` `` → `` while devbrew agents (no `model` key) show `model: sonnet` ``; 135행 `runtime-verifier: model=inherit,` → `runtime-verifier: model=(none — user setting/session),`.

- [ ] **Step 9: GREEN 확인**

Run: `bash plugins/quality-gates/tests/test_adversarial_model_consistency.sh; echo rc=$?; bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh | grep -E 'AC8d|Fail'`
Expected: rc=0; AC8d 세 줄 ✓, `Fail: 0`.

- [ ] **Step 10: 잔여 어휘 스윕 (AC11 1차)**

Run: `grep -rniE 'inherit' plugins docs/plugin-authoring.md --include='*.md' --include='*.sh' --include='*.py' --include='*.js' | grep -v -E 'CHANGELOG|docs/archive|/fixtures/' | grep -v -iE 'inherit(s|ed)? (everything|the env|it)|inherited devbrew|only PATH inherited|cannot inherit|can.t inherit'`
Expected: 남는 줄이 전부 (i) 새 락의 주석·음성 단언 (ii) `experiment-model-override.md` 의 실측 기록 문장(29·47·49·51행 — 외부 플러그인 frontmatter 서술이라 사실) (iii) `check-law2.py:188` 의 "inherits everything" 뿐. 그 외가 있으면 이 Task 에서 고친다.

- [ ] **Step 11: 커밋**

```bash
git add docs/plugin-authoring.md plugins/quality-gates/
git commit -m "docs(quality-gates,authoring): agent 모델 규약을 «model 키 부재»로 재기술 + inherit 서술 전수 갱신"
```

---

### Task 7: plugin-audit 구조 검사 필터 — `model` 누락 단독은 규약 준수

**Files:**
- Modify: `plugins/plugin-audit/scripts/check-plugin-structure.sh:55-67`
- Test: `plugins/plugin-audit/tests/test_check_plugin_structure.py`

**Interfaces:**
- Consumes: plugin-dev `validate-agent.sh` 출력 형식 `❌ Missing required field: model` / `❌ Missing required field: color` (실측: 2026-09-06 캐시본 121-135행).
- Produces: `degraded` 배열에 `validate-agent.sh(...)` 항목이 `color` 누락일 때만 생긴다.

- [ ] **Step 1: 실패 테스트 2건 추가** — `test_check_plugin_structure.py` 의 `TestPluginStructure` 클래스 끝에 추가. 파일 상단 `_stub_plugin_dev` 는 그대로 두고 아래 헬퍼를 클래스 밖(`run` 정의 아래)에 추가한다.

```python
def _stub_validate_agent_missing(root, field):
    """plugin-dev stub whose validate-agent.sh fails ONLY on the given missing field."""
    base = Path(root) / "skills" / "hook-development" / "scripts"
    base.mkdir(parents=True, exist_ok=True)
    ad = Path(root) / "skills" / "agent-development" / "scripts"
    ad.mkdir(parents=True, exist_ok=True)
    _exe(ad / "validate-agent.sh",
         "#!/usr/bin/env bash\necho '❌ Missing required field: %s'\nexit 1\n" % field)
    _exe(base / "hook-linter.sh", "#!/usr/bin/env bash\necho '✅ clean'\nexit 0\n")
    _exe(base / "validate-hook-schema.sh", "#!/usr/bin/env bash\necho '✅ ok'\nexit 0\n")
```

클래스 안:

```python
    def test_model_missing_alone_is_convention_not_degrade(self):   # spec AC12
        # devbrew 규약: frontmatter 에 model 키를 두지 않는다. plugin-dev 검증기의
        # "model required" 는 이 리포 불변식이 아니므로 degrade 로 기록하지 않는다.
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_validate_agent_missing(pd, "model")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertFalse([x for x in obj["degraded"] if "validate-agent.sh" in x],
                             obj["degraded"])

    def test_color_missing_alone_still_degrades(self):   # 양성 짝 — 필터가 통째로 죽지 않았다
        with tempfile.TemporaryDirectory() as t, tempfile.TemporaryDirectory() as pd:
            _stub_validate_agent_missing(pd, "color")
            r, obj = run(_mk_target(t), pd)
            self.assertEqual(r.returncode, 0)
            self.assertTrue([x for x in obj["degraded"] if "validate-agent.sh" in x],
                            obj["degraded"])
```

- [ ] **Step 2: RED 확인**

Run: `(cd plugins/plugin-audit/tests && python3 -m unittest test_check_plugin_structure -v 2>&1 | grep -E 'model_missing|color_missing|^(OK|FAILED)')`
Expected: `test_model_missing_alone_is_convention_not_degrade ... FAIL`, `test_color_missing_alone_still_degrades ... ok`.

- [ ] **Step 3: 필터 분기** — `check-plugin-structure.sh` 55–67행을 아래로 교체

```bash
# validate-agent.sh — color/model required 필터 (거짓 증거 주입 금지)
#   · `model` 누락 «단독»은 devbrew 규약 준수다 (docs/plugin-authoring.md: frontmatter 에
#     model 키를 두지 않는다) — 기록하지 않는다. degrade 로 적으면 리포트가 거짓을 말한다.
#   · `color` 누락 단독은 plugin-dev-ism — 기존대로 degrade 로 남긴다 (사실 아님, 생략 공시).
if [ -n "$VA" ]; then
  for a in "$TARGET"/agents/*.md; do
    [ -f "$a" ] || continue
    out=$(bash "$VA" "$a" 2>&1); rc=$?
    errs=$(echo "$out" | grep -E '❌|error' || true)
    real=$(echo "$errs" | grep -viE 'color|model' || true)
    color_only=$(echo "$errs" | grep -iE 'color' || true)
    if [ $rc -ne 0 ] && [ -z "$real" ]; then
      if [ -n "$color_only" ]; then
        add_degr "validate-agent.sh($(basename "$a")): color required는 plugin-dev-ism — 필터(devbrew 불변식 아님)"
      fi
      # model 누락 단독: 규약 준수 — 아무것도 남기지 않는다
    elif [ -n "$real" ]; then
      add_fact "$(python3 -c "import json,sys; print(json.dumps({'validator':'validate-agent.sh','target':sys.argv[1],'fact':sys.argv[2][:400],'verifier_ok':True}))" "$a" "$real")"
    fi
  done
fi
```

- [ ] **Step 4: GREEN 확인** — 같은 명령. Expected: 두 테스트 `ok`, 파일 전체 `OK`.

- [ ] **Step 5: 실물 확인 (AC12)**

Run: `bash plugins/plugin-audit/scripts/check-plugin-structure.sh plugins/quality-gates | python3 -c "import json,sys; d=json.load(sys.stdin); print([x for x in d['degraded'] if 'validate-agent' in x])"`
Expected: `[]`.

- [ ] **Step 6: 커밋**

```bash
git add plugins/plugin-audit/scripts/check-plugin-structure.sh plugins/plugin-audit/tests/test_check_plugin_structure.py
git commit -m "fix(plugin-audit): 구조 검사에서 model 키 부재는 규약 준수 — degrade 로 세지 않는다"
```

---

### Task 8: 변이 락 — 반전된 락의 이빨 증명

**Files:**
- Create: `plugins/quality-gates/tests/test_agent_model_mutation.sh`

**Interfaces:**
- Consumes: Task 1 스윕 락 파일명, Task 2–3 의 per-agent 락 파일명(아래 표).
- Produces: 상시 락 하나 — 변이를 임시 복사본이 아니라 **실제 agent 파일에 넣고 되돌린다**(락은 리포 경로를 고정 참조하므로 복사본으로는 잴 수 없다). `trap` 으로 복원. **변이 전 clean tree 필수** — 아니면 abort.

- [ ] **Step 1: 락 작성**

```bash
#!/usr/bin/env bash
# 변이 락 — 반전된 모델 락(스윕 1 + per-agent 14)이 실제로 문다.
#
# 통과가 정답인 부재 단언은 모양만으로 이빨을 판별할 수 없다. 여기서 agent 파일에
# model 키를 다섯 표기로 넣고 해당 락이 RED 가 되는지, 되돌리면 GREEN 인지 잰다.
# 다섯 표기 (spec C2): (a) `model: inherit` (b) `model: opus` (c) `model:inherit`
# (d) `"model": inherit` (e) `model : inherit`. (f) 스윕 하한은 glob 을 빈 dir 로 돌려 잰다.
#
# 실제 파일을 건드리므로 clean tree 를 요구하고 trap 으로 복원한다. 변이 중 실패해도
# `git checkout -- <file>` 이 되돌린다 — 그래서 이 락은 «커밋된» 파일만 변이한다.
set -u -o pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$ROOT" || exit 1
. "$ROOT/shared/tests/assert.sh"

SWEEP="plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh"

# agent → 그 agent 를 보는 per-agent 락 (spec §설계 2 표)
pairs=(
  "plugins/quality-gates/agents/adversarial.md|plugins/quality-gates/tests/test_adversarial_persona.sh"
  "plugins/quality-gates/agents/adversarial.md|plugins/quality-gates/tests/test_adversarial_model_consistency.sh"
  "plugins/quality-gates/agents/security-reviewer.md|plugins/quality-gates/tests/test_security_reviewer_persona.sh"
  "plugins/quality-gates/agents/artifact-critic.md|plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh"
  "plugins/quality-gates/agents/artifact-adversarial.md|plugins/quality-gates/tests/test_artifact_adversarial_frontmatter.sh"
  "plugins/quality-gates/agents/test-scope-validator.md|plugins/quality-gates/tests/test_test_scope_validator_frontmatter.sh"
  "plugins/quality-gates/agents/pr-understanding-builder.md|plugins/quality-gates/tests/test_pr_understanding_builder_frontmatter.sh"
  "plugins/quality-gates/agents/runtime-verifier.md|plugins/quality-gates/tests/test_runtime_verifier_frontmatter.sh"
  "plugins/spec-distill/agents/blind-spot-prober.md|plugins/spec-distill/tests/test_blind_spot_prober_frontmatter.sh"
  "plugins/spec-distill/agents/coverage-mapper.md|plugins/spec-distill/tests/test_coverage_mapper_frontmatter.sh"
  "plugins/spec-distill/agents/spec-reviewer.md|plugins/spec-distill/tests/test_spec_reviewer_frontmatter.sh"
  "plugins/spec-distill/agents/steelman-builder.md|plugins/spec-distill/tests/test_steelman_builder_scope.sh"
  "plugins/spec-distill/agents/brief-critic.md|plugins/spec-distill/tests/test_brief_agents.sh"
  "plugins/spec-distill/agents/seed-critic.md|plugins/spec-distill/tests/test_seed_agents.sh"
)
variants=("model: inherit" "model: opus" "model:inherit" "\"model\": inherit" "model : inherit")

if [ -n "$(git status --porcelain -- plugins/*/agents/)" ]; then
  no "0 — agents/ 에 미커밋 변경이 있다. 변이 락은 clean tree 에서만 돈다 (복원이 HEAD 로 간다)"
  finish; exit
fi
ok "0 — agents/ clean"

touched=()
restore() { for f in "${touched[@]:-}"; do [ -n "$f" ] && git checkout -q -- "$f"; done; }
trap restore EXIT

inject() {  # inject <file> <line>  — name: 줄 바로 뒤에 넣는다
  awk -v L="$2" 'BEGIN{d=0} {print} !d && /^name:/{print L; d=1}' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
  touched+=("$1")
}

# 양성 대조 — 변이 전 전부 GREEN 이어야 변이 RED 가 의미를 갖는다
bash "$SWEEP" >/dev/null && ok "양성 — 스윕 GREEN (변이 전)" || no "양성 — 스윕이 변이 전에 이미 RED"

for v in "${variants[@]}"; do
  # (1) 스윕: agent 하나에 넣으면 RED
  f="plugins/plugin-audit/agents/smoke-probe.md"
  inject "$f" "$v"
  bash "$SWEEP" >/dev/null && no "스윕: «$v» 를 넣어도 GREEN — 이빨 없음" || ok "스윕: «$v» → RED"
  git checkout -q -- "$f"
done

# (2) per-agent 락: (a)·(d) 두 표기로 각 락이 RED
for p in "${pairs[@]}"; do
  agent="${p%%|*}"; lock="${p##*|}"
  bash "$lock" >/dev/null && ok "양성 — ${lock##*/} GREEN (변이 전)" || no "양성 — ${lock##*/} 변이 전 RED"
  for v in "model: inherit" "\"model\": inherit"; do
    inject "$agent" "$v"
    bash "$lock" >/dev/null && no "${lock##*/}: «$v» 를 넣어도 GREEN" || ok "${lock##*/}: «$v» → RED"
    git checkout -q -- "$agent"
  done
done

# (f) 스윕 하한 — glob 이 비면 RED
EMPTY="$(mktemp -d)" || { no "mktemp 실패"; finish; exit; }
mkdir -p "$EMPTY/plugins/x/agents" "$EMPTY/shared/tests"
cp shared/tests/assert.sh "$EMPTY/shared/tests/"
mkdir -p "$EMPTY/plugins/quality-gates/tests"; cp "$SWEEP" "$EMPTY/plugins/quality-gates/tests/"
( cd "$EMPTY" && bash plugins/quality-gates/tests/test_agent_model_unpinned_sweep.sh >/dev/null ) \
  && no "스윕 하한: agent 0개인데 GREEN (vacuous pass)" || ok "스윕 하한: agent 0개 → RED"
rm -rf "$EMPTY"
finish
```

- [ ] **Step 2: 실행**

Run: `bash plugins/quality-gates/tests/test_agent_model_mutation.sh; echo rc=$?; git status --short plugins/*/agents/`
Expected: `Fail: 0`, rc=0, 그리고 `git status` 출력 없음(복원 확인).

- [ ] **Step 3: 계측기 자체의 양성 대조** — 락 하나를 일시적으로 무력화해 변이 락이 잡는지 본다.

```bash
sed -i.bak 's/assert_file_absent "\$A" "\$MODEL_KEY"/true # &/' plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh
bash plugins/quality-gates/tests/test_agent_model_mutation.sh | grep artifact_critic
mv plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh.bak plugins/quality-gates/tests/test_artifact_critic_frontmatter.sh
```
Expected: 가운데 명령이 `✗ test_artifact_critic_frontmatter.sh: «model: inherit» 를 넣어도 GREEN` 을 낸다. 복원 후 `git status --short plugins/quality-gates/tests` 가 새 파일(변이 락)만 보인다.

- [ ] **Step 4: 커밋**

```bash
git add plugins/quality-gates/tests/test_agent_model_mutation.sh
git commit -m "test(quality-gates): 모델 락 변이 락 — 다섯 표기 + 하한으로 반전 락의 이빨 증명"
```

---

### Task 9: 버전 bump + CHANGELOG ×4

**Files:**
- Modify: `plugins/{agent-transparency,plugin-audit,quality-gates,spec-distill}/.claude-plugin/plugin.json` (`version`)
- Modify: 같은 4개의 `CHANGELOG.md` (맨 위 항목 추가)

- [ ] **Step 1: 버전**

```bash
python3 - <<'PY'
import json,re
for p,v in [("agent-transparency","0.4.0"),("plugin-audit","0.9.0"),("quality-gates","7.3.0"),("spec-distill","0.54.0")]:
    f=f"plugins/{p}/.claude-plugin/plugin.json"; t=open(f,encoding='utf-8').read()
    t2=re.sub(r'"version": "[^"]+"', f'"version": "{v}"', t, count=1); assert t2!=t; open(f,'w',encoding='utf-8').write(t2)
PY
```

- [ ] **Step 2: CHANGELOG 항목** — 각 파일의 첫 `## [` 줄 바로 위에 삽입. 헤더 줄은 `## [<version>] — 2026-09-06`.

agent-transparency (`0.4.0`) / plugin-audit (`0.9.0`, 아래 Fixed 추가) / spec-distill (`0.54.0`) 공통 본문:

```markdown
### Changed

- **agent frontmatter 의 `model: inherit` 를 제거했다 — `inherit` 는 사용자의 subagent
  기본 티어 설정을 덮어쓴다 (CLI 2.1.261 실측, 2026-09-06).** frontmatter 에 `model` 키가
  없으면 하니스가 「`CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델」 순으로 위임하고, `inherit` 는
  그 첫 단계를 건너뛴다(헤드리스 probe 6회, 설계 §A). 설정이 없는 환경은 동작이 같다.
  규약·락은 「키 부재」 단언으로 반전 — 정본은
  `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md`.
```

plugin-audit 에 추가:

```markdown
### Fixed

- **구조 검사가 `model` 키 부재를 degrade 로 세던 것.** plugin-dev `validate-agent.sh` 는
  `model` 을 필수로 요구하는데 그것은 devbrew 규약이 아니다 — 핀을 빼면 agent 마다 degrade
  한 줄이 생겼을 것이다. `check-plugin-structure.sh` 가 `model` 누락 단독은 기록하지 않고
  `color` 누락 단독만 기존대로 degrade 로 남긴다. 테스트 2건(양성 짝 포함).
```

quality-gates (`7.3.0`) 본문:

```markdown
### Changed

- **agent 7개의 frontmatter `model: inherit` 를 제거하고 규약을 «키 부재»로 뒤집었다 —
  `inherit` 는 사용자의 subagent 기본 티어 설정을 덮어쓴다 (CLI 2.1.261 실측, 2026-09-06).**
  `model` 키가 없으면 하니스가 「`CLAUDE_CODE_SUBAGENT_MODEL` → 세션 모델」 순으로 위임하고,
  `inherit` 는 그 첫 단계를 건너뛴다(헤드리스 probe 6회, 설계 §A). 설정이 없는 환경은 동작이
  같다. #139(2026-09-04) 의 「inherit = 사용자 선택 존중」 전제를 반증한 재결정.
  정본: `docs/superpowers/specs/2026-09-06-agent-model-unpin-design.md`.
- 락 반전: 스윕 `test_agent_model_inherit_sweep.sh` → `test_agent_model_unpinned_sweep.sh`
  (키 존재 = RED, 하한 ≥10 유지), per-agent 락 8개, 규약 문장 락(AC8d) — 옛 음성 어법
  regex 는 새 문장에 반대로 울어 제거하고 리터럴 두 개로 대체.
- 새 변이 락 `test_agent_model_mutation.sh` — 다섯 표기(`model: inherit`·`model: opus`·
  `model:inherit`·`"model": inherit`·`model : inherit`) + 빈 glob 하한으로 이빨 증명.
- README·skill 본문·스크립트 주석의 `inherit`/`inherit-tier` 서술을 `tier-unpinned` 로.
  README 에 사용자 설정 예시 한 줄과 트레이드오프(강한 세션에서 리뷰어 한 티어 하향) 명시.
- `docs/plugin-authoring.md` 조항 재기술.
```

(`### Verified` 절은 Task 10 이 실측값과 함께 추가한다 — 여기서는 쓰지 않는다.)

- [ ] **Step 3: 커밋**

```bash
git add plugins/*/.claude-plugin/plugin.json plugins/*/CHANGELOG.md
git commit -m "chore(release): agent-transparency 0.4.0 · plugin-audit 0.9.0 · quality-gates 7.3.0 · spec-distill 0.54.0"
```

---

### Task 10: 사후 헤드리스 실측 (AC6)

**Files:**
- Modify: `plugins/quality-gates/CHANGELOG.md` (Task 9 의 `### Verified` 자리)

**Interfaces:**
- Consumes: 설계 부록의 프로브 절차. agent 는 devbrew 실물 `plugin-audit:smoke-probe`(페르소나가 임의 지시를 그대로 수행).

- [ ] **Step 1: 프롬프트 파일**

```bash
SCR=/private/tmp/claude-501/-Users-jeonghokim-Downloads-devbrew/3a0f644e-9b82-4f4b-b90c-248dae95e21d/scratchpad
cat > "$SCR/ac6_prompt.txt" <<'EOF'
Use the Agent tool exactly once: subagent_type "plugin-audit:smoke-probe", prompt "Report the model name stated in your system prompt, verbatim, one line. Do nothing else." Do NOT pass a model parameter. Then output exactly one line: PROBE: <the agent's reply>
EOF
```

- [ ] **Step 2: 실행 두 번 (환경변수 있음/없음). `--plugin-dir` 로 브랜치의 plugin-audit 을 로드한다 (설치 캐시가 아니라).**

```bash
cd "$SCR"
CLAUDE_CODE_SUBAGENT_MODEL=haiku claude -p --model opus --plugin-dir /Users/jeonghokim/Downloads/devbrew/plugins/plugin-audit --permission-mode acceptEdits --output-format stream-json --verbose < ac6_prompt.txt > ac6_env.jsonl 2>ac6_env.err
claude -p --model opus --plugin-dir /Users/jeonghokim/Downloads/devbrew/plugins/plugin-audit --permission-mode acceptEdits --output-format stream-json --verbose < ac6_prompt.txt > ac6_noenv.jsonl 2>ac6_noenv.err
for r in ac6_env ac6_noenv; do python3 - "$r.jsonl" <<'PY'
import json,sys
for l in open(sys.argv[1],encoding='utf-8'):
    try: e=json.loads(l)
    except: continue
    if e.get('type')=='assistant':
        for c in e.get('message',{}).get('content',[]):
            if c.get('type')=='tool_use' and c.get('name')=='Agent': print('Agent model arg:',c['input'].get('model','<absent>'))
    if e.get('type')=='result': print('num_turns',e.get('num_turns'),'|',e.get('result'))
PY
done
cd - >/dev/null
```
Expected: `ac6_env` → `Agent model arg: <absent>`, `num_turns 3`, `PROBE: Haiku 4.5`. `ac6_noenv` → `PROBE: Opus 5`. (`num_turns 0` 이면 조용한 실패 — `.err` 와 `--plugin-dir` 경로를 확인.)

- [ ] **Step 3: quality-gates CHANGELOG 의 7.3.0 항목 끝에 `### Verified` 절 추가**

```markdown
### Verified

- 사후 실측 (AC6, CLI 2.1.261, 2026-09-06): `plugin-audit:smoke-probe` 를 `--plugin-dir` 로 로드해
  부모 opus 세션에서 dispatch — `CLAUDE_CODE_SUBAGENT_MODEL=haiku` 이면 Haiku 4.5, 없으면 Opus 5 보고.
  Agent 호출에 `model` 인자 부재 확인.
```

- [ ] **Step 4: 커밋**

```bash
git add plugins/quality-gates/CHANGELOG.md
git commit -m "docs(quality-gates): AC6 사후 실측 결과 기록"
```

---

### Task 11: 최종 검증 — AC5·AC9·AC11 + 스위트

**Files:**
- Create: `$SCR/pr_body_tables.md` (PR 본문에 붙일 분류표 둘)

- [ ] **Step 1: AC9 — 실패 단언 집합 비교**

Run: `bash $SCR/run_all_locks.sh > $SCR/after_fail_set.txt; comm -13 $SCR/baseline_fail_set.txt $SCR/after_fail_set.txt`
Expected: 출력 없음 (새 실패 원소 0). 있으면 그 줄이 회귀다 — 고치고 다시.

- [ ] **Step 2: python 스위트** —
Run: `cd plugins/plugin-audit/tests && python3 -m unittest discover -s . -t . 2>&1 | tail -3; cd -; cd plugins/spec-distill/tests && python3 -m unittest discover -s . -t . 2>&1 | tail -3; cd -`
Expected: plugin-audit `OK`; spec-distill 은 baseline 과 같은 실패 수(선재 RED 가 있으면 그 수 그대로 — 기억: NG9 선재 RED 1건).

- [ ] **Step 3: AC5 분류표**

Run: `grep -rnE 'model:[[:space:]]*inherit|"inherit"' plugins/*/tests shared/tests`
각 hit 을 `fixture` / `주석` / `음성 단언` 으로 분류해 `$SCR/pr_body_tables.md` 에 표로. GREEN 조건으로 `inherit` 를 요구하는 줄이 하나라도 있으면 그 락을 Task 2/3 방식으로 반전.

- [ ] **Step 4: AC11 분류표** — Task 6 Step 10 의 grep 을 다시 돌려 잔여를 (i)이력 (ii)fixture (iii)음성 단언·주석 (iv)무관 어휘 로 분류해 같은 파일에 표로.

- [ ] **Step 5: 워킹트리 clean 확인** — `git status --short` 출력 없음. `git log --oneline main..HEAD` 로 커밋 11개 안팎 확인.

---

### Task 12: 리뷰 게이트 + PR

- [ ] **Step 1: `/qg`** — 리뷰 게이트. 락·persona 파일 편집이 있으므로 보안-민감 편집으로 취급된다. findings 는 반영 후 재실행.
- [ ] **Step 2: PR** — `feature/agent-model-unpin` → `main`, merge commit. 본문에 설계 링크, 실측 표(§A), Task 11 의 분류표 둘, 사용자 안내 한 줄. 끝에 `🤖 Generated with [Claude Code](https://claude.com/claude-code)` + 세션 링크.
- [ ] **Step 3: 머지 후** — 메모리 `project_agent_model_unpin.md` 를 MERGED 로 갱신, `project_agent_model_dispatch_discretion.md` 에 「frontmatter inherit 규약은 2026-09-06 «키 부재»로 대체」 한 줄.
