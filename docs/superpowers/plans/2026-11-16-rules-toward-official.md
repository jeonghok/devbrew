# 규칙 개정 (F6) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** CLAUDE.md · 철학 문서 · 저술 가이드의 규칙 여섯 자리를 Claude Code 공식 쪽으로 옮기고, 그 문장을 글자로 확인하는 테스트 · 감사 검사 · skill frontmatter 를 같은 PR 에서 함께 옮긴다.

**Architecture:** 새 장치를 짓지 않는다. 규칙 문장과 그 문장을 무는 락을 같은 커밋에서 바꾸고, skill 10개의 `cost_class` 를 frontmatter `metadata` 아래로 옮기면서 그것을 읽는 세 검사(plugin-audit 의 둘 · 호출 표면 검사)를 함께 옮긴다. 판 올림은 문장만 고친다(길 1).

**Tech Stack:** bash 3.2 셸 테스트(`shared/tests/assert.sh`) · Python 3.9 표준 라이브러리 · unittest.

**Spec:** `docs/superpowers/specs/2026-11-15-rules-toward-official-design.md`

## Global Constraints

- 공식 자료는 참고다. 옮기는 것은 사용자가 고른 여섯 자리와 agent 도구 필드 문장 하나뿐이다(설계 Constraints · D1.2).
- CLAUDE.md 에서 고치는 줄은 넷뿐이다 — `### 메타데이터 & 버전 관리` 첫 줄 · `### 컴포넌트 격리` 의 Scoped agents 줄 · `allowed-tools` 줄 · cost_class 줄. 철학 문서는 P21 · P22 의 두 문장뿐이다. `## The Three Laws` 절과 철학 P8 절은 한 글자도 바꾸지 않는다(AC15).
- 바이트 비교 락이 걸린 두 문장(CLAUDE.md cost 줄 · 철학 P22 첫 줄)은 문장과 락 고정값을 같은 커밋에서 바꾼다. 감사 검사 테스트의 `ANCHORS` 두 개도 CLAUDE.md 문장과 같은 커밋에서 바꾼다.
- 글자 제약(락이 거는 것): 「실제 키」 라는 글자를 쓰지 않는다(「실재 키」 로 쓴다 — `plugins/quality-gates/tests/test_law2_prose.sh`). CLAUDE.md 에서 `allowed-tools` 와 `disallowed-tools` 를 빗금으로 잇지 않는다. CLAUDE.md · 철학 문서의 백틱 토큰 중 `/` 를 품은 것은 실재 경로이거나 꺾쇠 자리표시(`plugins/<X>/`)나 글롭이어야 한다(`shared/tests/test_charter_citations.sh`) — 그래서 `plugins/X/` · `tests/` · `.claude-plugin/plugin.json` 은 백틱에 넣지 않는다.
- `shared/tests/test_invocation_surface.sh` 는 F5 의 예약 파일이다 — 이 PR 은 그 파일의 fixture 두 줄(40 · 47행의 `cost_class:`)만 고친다. 다른 줄은 건드리지 않는다.
- AC14 의 「diff 없음」 은 단언 단위다. `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` 는 cost 줄 · P22 고정값을 고치고 F6 단언 블록을 더하지만, 같은 파일의 model 규약 블록(`# --- AC8d:` 부터 `fi` 까지)은 건드리지 않는다.
- agent 파일 전부 · model 키 테스트 · `shared/tests/test_changelog_integrity.sh` · `shared/tests/test_plugin_description_parity.sh` · `plugins/project-init/templates/shared/commit-conventions.md` 는 고치지 않는다.
- 새 셸 테스트는 실행 비트를 붙여(`100755`) 커밋한다. `# guards:` 머리를 달면 `--emit-scanned` 에 답한다. 테스트 안의 인라인 python 은 `python3 -I` 로 부른다. Python 은 3.9 문법만 쓰고 `open(` 에는 `encoding` 을 단다.
- 판: plugin-audit minor · project-init · quality-gates · spec-distill patch. 플러그인마다 이 PR 에서 정확히 한 번 올린다. 지금 기본 브랜치(6691b73d) 위에서는 1.8.0 · 5.4.2 · 14.10.1 · 8.16.1 이다 — 머지 직전 기본 브랜치가 움직였으면 그 위에서 다시 정한다.
- 커밋은 pathspec 으로, 메시지는 한국어 Conventional Commits(`<type>(<scope>): <설명>`) 에 세션이 받은 `Co-Authored-By:` 줄을 단다.
- 전체 스위트는 공유 잠금으로만 돈다:
  `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner <이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'`
  못 잡으면 주인 · 잡은 시각을 보고한다. 과제 안의 좁은 테스트는 잠금 없이 돈다.

## Review Focus

1. **`metadata` 블록 밖의 들여쓴 `cost_class:`** (예: `hooks:` 아래) — 선언이 아니다. 감사 검사 둘이 「선언 없음」 으로 낸다 → Task 4 의 `test_indented_cost_class_outside_metadata_is_not_declared`.
2. **`metadata:` 와 `cost_class:` 사이에 빈 줄 · 다른 자식 키가 있는 블록** — 블록은 들여쓰지 않은 다음 줄에서만 끝난다. 그 사이의 자식 `cost_class` 는 선언이다 → Task 4 의 `test_metadata_cost_class_after_sibling_child_is_declared`.
3. **본문(frontmatter 닫힌 뒤)에 `metadata:` + `  cost_class:` 글자** — 선언이 아니다 → Task 4 의 `test_body_metadata_block_is_not_declared` · Task 2 의 계측기 대조 `s_body`.
4. **`name` 이 빈 문자열이거나 문자열이 아닌 plugin.json** — 이름이 없는 것과 같게 gap 이다 → Task 4 의 `test_empty_or_nonstring_name_is_gap`.
5. **맨 위와 `metadata` 아래에 둘 다 `cost_class` 가 있는 skill** — 감사 검사는 `metadata` 아래 값으로 선언으로 읽고, 맨 위 키는 호출 표면 검사가 모르는 키로 낸다 → Task 4 의 `test_both_places_counts_metadata`, Task 2 의 (나) 단언.

`metadata: {cost_class: high}` 같은 흐름 꼴은 받지 않는다(「선언 없음」) — 공식 문서와 이 레포가 쓰는 꼴은 블록 꼴이다.

## AC 대조

| AC | 과제 |
|---|---|
| AC1 | Task 2 |
| AC2 | Task 4 |
| AC3 | Task 2 |
| AC4 | Task 3(CLAUDE.md · P22) · Task 5(저술 가이드) |
| AC5 | Task 2(agent 쪽을 건드리지 않음) · Task 7(diff 확인) |
| AC6 | Task 3 |
| AC7 | Task 3(문장) · Task 2(쓰는 skill 0) |
| AC8 | Task 3(CLAUDE.md) · Task 5(저술 가이드) |
| AC9 | Task 4 |
| AC10 | Task 6 · Task 7 |
| AC11 | Task 3 |
| AC12 | Task 6 |
| AC13 | Task 5 |
| AC14 | Task 5 · Task 7 |
| AC15 | Task 3 · Task 7 |
| AC16 | Task 7 |
| AC17 | Task 5 |
| AC18 | Task 5 |

---

### Task 1: 설계가 근거로 든 자리 다시 확인

코드를 고치지 않는다. 설계문서가 「조사 보고」 로 표시한 자리가 지금 브랜치에서도 그런지 본다. 아래 기대와 다르면 **멈추고 지휘자에게 보고한다**(다른 자리 · 수 · 줄 번호 · 고치면 깨질 테스트가 새로 나온 것). 계획 작성 때(2026-11-16, 브랜치 끝 3ecc8d4f · 기본 브랜치 6691b73d) 한 번 확인했다 — 그때와 같으면 그대로 간다.

**Files:** 읽기만.

- [ ] **Step 1: 규칙 문장의 줄**

Run: `grep -n 'integrity\|cost_class\|disallowedTools\|이 계층은 제한이 아니다' CLAUDE.md` · `grep -n '^### P2[12]\|integrity-pin\|frontmatter에 선언' docs/philosophy/devbrew-harness-philosophy.md`
Expected: CLAUDE.md 42행(필수 키 · 「모든 PR마다」 · `integrity`) · 48행(Scoped agents — 「agent frontmatter의 실재 필드는 … 둘뿐이다」) · 49행(「이 계층은 제한이 아니다」) · 51행(「모든 skill에 `cost_class` 선언」). 철학 `### P21` 아래 59행에 「integrity-pin된 plugin-to-plugin trust」, `### P22` 아래 63행에 「frontmatter에 선언한다」.

- [ ] **Step 2: skill 10개의 머리 줄**

Run: `for f in plugins/*/skills/*/SKILL.md; do printf '%s ' "$f"; awk 'NR==1{next} /^---$/{exit} /^cost_class:/{print}' "$f"; done`
Expected: 정확히 10개, 값 — plugin-audit high · project-init low · artifact-critique variable · quality-pipeline variable · epic-conductor high · pm-interview variable · request-framing variable · reviewing-brief medium · roadmap-status low · spec-review medium. `metadata:` 키를 가진 skill 0. frontmatter 에 `disallowed-tools:` 를 가진 skill 0.

- [ ] **Step 3: 글자로 무는 테스트**

Run: `grep -rlF '모든 skill에 `cost_class` 선언' plugins/*/tests shared/tests` · `grep -rn '^cost_class\|cost_class: high\|cost_class: medium\|cost_class: variable' plugins/*/tests shared/tests --include='*.sh' --include='*.py' | grep -v fixtures/variant_of`
Expected: 첫 명령 — `test_governance_no_capability_caps.sh` · `test_cost_disclosure.sh` · `test_epic_conductor_skill.sh` · `test_check_shape_completeness.py` 넷. 둘째 — skill 쪽은 `test_epic_conductor_skill.sh:16` · `test_conducting_interview_stage.sh:73` · `test_pm_interview_entry.sh:33` · `test_reviewing_brief_skill.sh:70-72` · `test_skill_orchestration.py:13,58` · `test_check_staleness.py:541` · `test_invocation_surface.sh:40,47,125,127`. agent 쪽(`test_security_reviewer_persona.sh` · `test_brief_agents.sh` · `test_research_agents_frontmatter.sh`)과 `test_variant_of_contract.sh` 는 agent 를 보므로 고치지 않는다. Scoped agents 줄의 「실재 필드 … 둘뿐이다」 를 글자로 무는 테스트는 0 이다(`test_governance_no_capability_caps.sh:262-263` 은 같은 줄의 다른 구절만 문다).

- [ ] **Step 4: 감사 검사와 호출 표면 검사**

Run: `grep -n 'cost_class\|"name", "version", "description"' plugins/plugin-audit/scripts/check-shape-completeness.py plugins/plugin-audit/scripts/check-staleness.py shared/entry/check_invocation_surface.py`
Expected: `check-shape-completeness.py` 의 `_has_cost_class`(`^cost_class:`) 와 `all(k in pj for k in ("name", "version", "description"))` · `check-staleness.py` 564–566행의 「cost_class 선언 없음」 · `check_invocation_surface.py` 33행 주석 · 41행 `SKILL_KEYS` 의 `"cost_class"` · 179행 메시지 「공식 키 ∪ {cost_class} 밖이다」.

- [ ] **Step 5: 문서 셋 밖 두 자리와 저술 가이드**

Run: `grep -n 'release-please' docs/git-workflow/commit-conventions.md` · `grep -n '세 플러그인' shared/README.md` · `ls -l plugins/*/scripts/entry_preflight.py` · `grep -rl 'copy-of: shared/python' plugins` · `grep -n 'doc-recritic\|command-development\|/create-plugin\|hook에서 호출\|시작 버전' docs/plugin-authoring.md`
Expected: commit-conventions 61행 · shared/README 30행(entry — 실제 링크 넷) · 33행(python — 실제 사본은 project-init 하나) · 저술 가이드의 낡은 자리 일곱(설계 6 의 표).

- [ ] **Step 6: 손 시나리오**

Run: `sed -n 103,125p plugins/quality-gates/tests/e2e-scenarios.md`
Expected: 맨 위 `cost_class` 를 읽는 python 블록이 「제거된 표면 — 역사 기록으로 남긴다」 머리 아래에 있고, 없는 agent(`scout` 등)를 먼저 열어 지금도 돌지 않는다. → 고치지 않는다. PR 본문에 이유(역사 기록으로 표시된 죽은 블록)를 적는다(Task 7).

결과를 한 줄로 남긴다: 「다시 확인 — 설계와 같음」 또는 다른 자리 목록. 다르면 다음 과제로 가지 않는다.

---

### Task 2: skill 10개의 cost_class 를 metadata 아래로 · 호출 표면 검사

AC1 · AC3 · AC7(쓰는 skill 0) · AC5(agent 쪽은 건드리지 않는다).

**Files:**
- Create: `shared/tests/test_skill_cost_class_place.sh` (100755)
- Modify: skill 10개의 `SKILL.md` frontmatter — `plugins/plugin-audit/skills/plugin-audit/SKILL.md:8` · `plugins/project-init/skills/project-init/SKILL.md:6` · `plugins/quality-gates/skills/artifact-critique/SKILL.md:12` · `plugins/quality-gates/skills/quality-pipeline/SKILL.md:14` · `plugins/spec-distill/skills/epic-conductor/SKILL.md:7` · `plugins/spec-distill/skills/pm-interview/SKILL.md:11` · `plugins/spec-distill/skills/request-framing/SKILL.md:7` · `plugins/spec-distill/skills/reviewing-brief/SKILL.md:10` · `plugins/spec-distill/skills/roadmap-status/SKILL.md:7` · `plugins/spec-distill/skills/spec-review/SKILL.md:11`
- Modify: `shared/entry/check_invocation_surface.py:33,41,179`
- Modify: `shared/tests/test_invocation_surface.sh:40,47` (이 두 줄만)
- Modify: `plugins/spec-distill/tests/test_epic_conductor_skill.sh:16` · `plugins/spec-distill/tests/test_conducting_interview_stage.sh:73` · `plugins/spec-distill/tests/test_pm_interview_entry.sh:33-35` · `plugins/spec-distill/tests/test_reviewing_brief_skill.sh:70-74` · `plugins/plugin-audit/tests/test_skill_orchestration.py:56-58`

**Interfaces:**
- Produces: skill frontmatter 의 꼴 — `cost_class:` 한 줄이 있던 자리에 두 줄 `metadata:` / `  cost_class: <값>`(공백 둘). `cost_class` 는 `metadata` 의 첫 자식이다. Task 4 의 감사 검사와 Task 3 의 규칙 문장이 이 꼴을 전제한다.

- [ ] **Step 1: 실패하는 테스트를 쓴다 — `shared/tests/test_skill_cost_class_place.sh`**

```bash
#!/usr/bin/env bash
# guards: plugins/*/skills/*/SKILL.md shared/entry/check_invocation_surface.py
# skill 의 cost_class 는 frontmatter `metadata` 아래에 둔다(CLAUDE.md 컴포넌트 격리).
#  (가) 모든 SKILL.md — metadata 아래 값이 있고 맨 위 cost_class 줄이 없다. 이름 붙인 skill 은 값이 옮기기 전과 같다.
#  (나) 호출 표면 검사 — 맨 위 cost_class 는 모르는 키, metadata 는 받는다.
#  (다) frontmatter 에 disallowed-tools 를 쓰는 skill 은 0 이다.
set -u
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LOCK="$ROOT/shared/entry/check_invocation_surface.py"
if [ "${1:-}" = "--emit-scanned" ]; then
  git -C "$ROOT" ls-files -- 'plugins/*/skills/*/SKILL.md'
  printf '%s\n' shared/entry/check_invocation_surface.py
  exit 0
fi
. "$ROOT/shared/tests/assert.sh"
export PYTHONDONTWRITEBYTECODE=1
TMP="$(mktemp -d "${TMPDIR:-/tmp}/cc-place.XXXXXX")" || { no "mktemp 실패"; finish; exit 1; }
[ -n "$TMP" ] && [ -d "$TMP" ] || { no "임시 디렉토리가 없다"; finish; exit 1; }
trap 'rm -rf "$TMP"' EXIT

# place <파일> — 「top=<0|1> meta=<값|-> dis=<0|1>」. frontmatter 는 첫 줄 --- 부터 다음 --- 앞까지.
place() {
  python3 -I - "$1" <<'PY'
import re, sys
lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
fm = []
if lines and lines[0] == "---":
    for ln in lines[1:]:
        if ln == "---":
            break
        fm.append(ln)
top = any(re.match(r"cost_class:", ln) for ln in fm)
dis = any(re.match(r"disallowed-tools:", ln) for ln in fm)
meta, inside = "-", False
for ln in fm:
    if re.match(r"metadata:[ \t]*$", ln):
        inside = True
        continue
    if inside and ln.strip() and not ln[0].isspace():
        inside = False
    m = re.match(r"[ \t]+cost_class:[ \t]*(\S+)[ \t]*$", ln) if inside else None
    if m:
        meta = m.group(1)
print("top=%d meta=%s dis=%d" % (top, meta, dis))
PY
}

# ── 계측기 양성 대조 ──
printf -- '---\nname: x\ncost_class: high\n---\n' > "$TMP/s_top.md"
printf -- '---\nname: x\nmetadata:\n  cost_class: high\n---\n' > "$TMP/s_meta.md"
printf -- '---\nname: x\nhooks:\n  cost_class: high\n---\n' > "$TMP/s_other.md"
printf -- '---\nname: x\n---\nmetadata:\n  cost_class: high\n' > "$TMP/s_body.md"
printf -- '---\nname: x\nmetadata:\n  a: 1\nhooks:\n  cost_class: high\n---\n' > "$TMP/s_after.md"
assert_eq "$(place "$TMP/s_top.md")"   "top=1 meta=- dis=0"    "대조: 맨 위 cost_class 를 맨 위로 읽는다"
assert_eq "$(place "$TMP/s_meta.md")"  "top=0 meta=high dis=0" "대조: metadata 아래 값을 읽는다"
assert_eq "$(place "$TMP/s_other.md")" "top=0 meta=- dis=0"    "대조: 다른 키 아래 들여쓴 cost_class 는 선언이 아니다"
assert_eq "$(place "$TMP/s_body.md")"  "top=0 meta=- dis=0"    "대조: 본문의 같은 글자는 frontmatter 가 아니다"
assert_eq "$(place "$TMP/s_after.md")" "top=0 meta=- dis=0"    "대조: metadata 블록은 들여쓰지 않은 다음 키에서 닫힌다"

# ── (가) 실제 skill 전부 ──
n=0
while IFS= read -r f; do
  [ -n "$f" ] || continue
  n=$((n + 1))
  got="$(place "$ROOT/$f")"
  case "$got" in
    "top=0 meta=low dis=0"|"top=0 meta=medium dis=0"|"top=0 meta=high dis=0"|"top=0 meta=variable dis=0") ok "(가) $f: $got" ;;
    *) no "(가) $f: metadata 아래 cost_class(low|medium|high|variable)가 없거나 맨 위 줄이 남았다 — $got" ;;
  esac
done < <(git -C "$ROOT" ls-files -- 'plugins/*/skills/*/SKILL.md')
[ "$n" -ge 10 ] && ok "(가) 도출: SKILL.md ${n}개" || no "(가) 도출: SKILL.md 가 ${n}개뿐이다 — 도출이 무너졌다"
while read -r f v; do
  assert_eq "$(place "$ROOT/$f")" "top=0 meta=$v dis=0" "(가) 값 그대로: $f = $v"
done <<'EOF'
plugins/plugin-audit/skills/plugin-audit/SKILL.md high
plugins/project-init/skills/project-init/SKILL.md low
plugins/quality-gates/skills/artifact-critique/SKILL.md variable
plugins/quality-gates/skills/quality-pipeline/SKILL.md variable
plugins/spec-distill/skills/epic-conductor/SKILL.md high
plugins/spec-distill/skills/pm-interview/SKILL.md variable
plugins/spec-distill/skills/request-framing/SKILL.md variable
plugins/spec-distill/skills/reviewing-brief/SKILL.md medium
plugins/spec-distill/skills/roadmap-status/SKILL.md low
plugins/spec-distill/skills/spec-review/SKILL.md medium
EOF

# ── (나) 호출 표면 검사 ──
mk() {   # mk <dir> <frontmatter 가운데 줄들>
  mkdir -p "$1/plugins/zz/skills/zz-yy"
  printf -- '---\nname: zz-yy\ndescription: x\n%s---\n\nbody\n' "$2" > "$1/plugins/zz/skills/zz-yy/SKILL.md"
  git init -q "$1"
}
e_lines() { python3 "$LOCK" --root "$1" 2>&1 | grep '^RED E plugins/zz/skills/zz-yy/SKILL.md' || true; }
mk "$TMP/r-top" 'cost_class: high
'
mk "$TMP/r-meta" 'metadata:
  cost_class: high
'
E_TOP="$(e_lines "$TMP/r-top")"; E_META="$(e_lines "$TMP/r-meta")"
assert_contains "$E_TOP" "'cost_class'" "(나) 맨 위 cost_class 를 모르는 키로 낸다"
assert_not_contains "$E_TOP" '∪' "(나) 메시지에 「∪ {cost_class}」 가 없다"
assert_eq "$E_META" "" "(나) metadata 아래 cost_class 는 축 E 에 걸리지 않는다"
assert_not_contains "$(cat "$LOCK")" '∪ {cost_class}' "(나) 검사 파일의 주석 · 메시지에 「∪ {cost_class}」 가 없다"

finish
```

`chmod +x shared/tests/test_skill_cost_class_place.sh` 로 실행 비트를 붙인다.

- [ ] **Step 2: 실패를 본다**

Run: `bash shared/tests/test_skill_cost_class_place.sh`
Expected: 대조 넷은 ✓. (가) 열 줄 ✗(`top=1 meta=-`) · (나) 「모르는 키로 낸다」 ✗ · 「∪ 없음」 ✗ 두 개. `python3 "$LOCK"` 가 rc 2(내부 오류)로 끝나면 계측기 고장이다 — 멈추고 원인을 본다.

- [ ] **Step 3: skill 10개를 옮긴다**

각 SKILL.md 에서 `cost_class: <값>` 한 줄을 그 자리에서 두 줄로 바꾼다 — `metadata:` 와 `  cost_class: <값>`(공백 둘). 다른 줄 · 순서 · 본문은 그대로다. plugin-audit SKILL.md 83행 본문의 「(cost_class: high)」 는 본문이라 그대로 둔다.

- [ ] **Step 4: 호출 표면 검사를 고친다 — `shared/entry/check_invocation_surface.py`**

`SKILL_KEYS` 에서 `"cost_class"` 를 뺀다(`"metadata"` 는 이미 있다). 33행 주석을 `# 축 E — 공식 skill frontmatter 키 20개. devbrew 의 cost_class 는 공식 키 \`metadata\` 아래에 둔다(CLAUDE.md 컴포넌트 격리).` 로, 179행 메시지를 `"frontmatter 키 '%s' 는 공식 키 밖이다" % key` 로 바꾼다. 34–36행의 출처 · 확인 주석은 그대로다.

- [ ] **Step 5: 기존 테스트의 자리를 옮긴다**

- `shared/tests/test_invocation_surface.sh` 40행: `cost_class: low\n` → `metadata:\n  cost_class: low\n`. 47행: `cost_class: medium\n` → `metadata:\n  cost_class: medium\n`. 125 · 127행의 변이 앵커(`"cost_class: low"` 부분 문자열)는 들여쓴 줄에도 맞고 그 뒤에 0열 키를 심으므로 고치지 않는다.
- spec-distill 의 셸 테스트 넷은 맨 위 줄 단언을 「`metadata:` 바로 다음 줄이 `  cost_class: <값>`」 과 「맨 위 `cost_class:` 줄 0」 두 단언으로 바꾼다. 꼴(epic-conductor 예, `fm` 은 그 파일 17행에 이미 있는 함수 — 16행의 단언을 17행 뒤로 옮겨 쓴다):
  ```bash
  assert_eq "$(fm "$SK" | grep -A1 -xF 'metadata:' | grep -cxF '  cost_class: high')" "1" "cost_class: high (metadata 아래)"
  assert_eq "$(fm "$SK" | grep -c '^cost_class:')" "0" "맨 위 cost_class 줄이 없다"
  ```
  `test_conducting_interview_stage.sh` · `test_pm_interview_entry.sh` 는 그 파일의 `ok`/`no` 꼴과 `$SKILL` 로 같은 두 단언(값 `variable`)을 쓴다 — frontmatter 는 `awk 'NR==1&&$0=="---"{f=1;next} f&&$0=="---"{exit} f' "$SKILL"` 로 자른다. `test_reviewing_brief_skill.sh` 70–71행은 이미 있는 `$FM` 으로 같은 두 단언(값 `medium`)을 쓰고, 72–74행의 「`cost_class: high` 잔존 없음」 단언은 그대로 둔다.
- `plugins/plugin-audit/tests/test_skill_orchestration.py` 의 `test_cost_class_high_in_frontmatter`: `self.assertIn("metadata:\n  cost_class: high", fm)` 과 `self.assertNotRegex(fm, r"(?m)^cost_class:")`. `INVARIANTS` 의 `"cost_class: high"`(본문 83행이 맞춘다)는 그대로다.

- [ ] **Step 6: 통과를 본다**

Run: `bash shared/tests/test_skill_cost_class_place.sh; bash shared/tests/test_invocation_surface.sh; for t in plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_pm_interview_entry.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh; do bash "$t" | tail -1; done; python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_skill_orchestration.py'`
Expected: 모두 실패 0. `test_invocation_surface.sh` 의 2부(이 리포 무변이 GREEN)가 통과한다 — 맨 위 키가 남은 skill 이 없다는 뜻이다.

- [ ] **Step 7: 변이로 이빨을 본다(커밋 전 사본 대신 되돌릴 수 있게 하나씩)**

1. `SKILL_KEYS` 에 `"cost_class"` 를 되살린다 → `test_skill_cost_class_place.sh` (나) 「모르는 키로 낸다」 ✗. 되돌린다.
2. roadmap-status SKILL.md 를 맨 위 `cost_class: low` 로 되돌린다 → (가) 그 파일 ✗ 두 줄 · `test_invocation_surface.sh` 2부 ✗. 되돌린다.
3. pm-interview 의 값을 `  cost_class: medium` 으로 바꾼다 → (가) 「값 그대로」 ✗ · `test_pm_interview_entry.sh` ✗. 되돌린다.
4. 테스트 `place` 의 `inside = False` 줄을 지운다 → 대조 「metadata 블록은 들여쓰지 않은 다음 키에서 닫힌다」 ✗(계측기 자신의 이빨).
각 변이 뒤 `git diff --stat` 로 되돌림을 확인한다.

- [ ] **Step 8: 커밋**

```bash
git add shared/tests/test_skill_cost_class_place.sh shared/entry/check_invocation_surface.py shared/tests/test_invocation_surface.sh plugins/*/skills/*/SKILL.md plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_pm_interview_entry.sh plugins/spec-distill/tests/test_reviewing_brief_skill.sh plugins/plugin-audit/tests/test_skill_orchestration.py
git ls-files -s shared/tests/test_skill_cost_class_place.sh   # 100755 확인
git commit -m "refactor(skills): cost_class 를 frontmatter metadata 아래로 옮긴다 (F6)" -m "Co-Authored-By: ..."
```

---

### Task 3: CLAUDE.md 네 줄 · 철학 두 문장 · 그 문장을 무는 락

AC4(CLAUDE.md · P22) · AC6 · AC7(문장) · AC8(CLAUDE.md) · AC11 · AC15.

**Files:**
- Modify: `CLAUDE.md:42,48,49,51`
- Modify: `docs/philosophy/devbrew-harness-philosophy.md:59,63`
- Modify: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh:131,144,145` + F6 단언 블록(282행 `R14 넘김` 머리 바로 앞에 넣는다)
- Modify: `shared/tests/test_cost_disclosure.sh:113`
- Modify: `plugins/spec-distill/tests/test_epic_conductor_skill.sh:227`
- Modify: `plugins/plugin-audit/tests/test_check_shape_completeness.py:10,14,60-63`

**Interfaces:**
- Consumes: Task 2 의 frontmatter 꼴(규칙 문장이 그 자리를 말한다).
- Produces: CLAUDE.md 의 새 줄 머리 셋 — 아래 문장 그대로. Task 5 의 단언과 Task 4 의 감사 검사 앵커가 이 글자를 쓴다.

새 문장(최종 글자 — 이대로 넣는다):

- **CLAUDE.md 42행 전체**
  ```
  - **`plugin.json` — 필수 키와 판 올림.** `plugin.json` 의 필수 키는 `name` 하나다 — `version` · `description` · `author` 를 빼면 `claude plugin validate` 가 경고를 낸다. `version` 을 적은 플러그인은 설치본이 바뀌는 PR 에서 판을 올린다(major = breaking, minor = 새 surface, patch = fix) — 설치본은 판 문자열로 갱신을 알아채서, 올리지 않으면 사용자는 옛 사본에 머문다. 올림 단위는 기본 브랜치에 머지되는 PR 하나다 — PR 안에서 커밋마다 올리지 않는다. 플러그인 X 를 올리는 때는 그 PR 이 ① `plugins/<X>/` 아래 파일(그 폴더 바로 아래의 `plugins/<X>/tests/` 폴더 · `CHANGELOG.md` · `README.md` 는 제외)을 바꾸거나 ② X 가 심볼릭 링크로 싣는 `shared/` 파일을 바꿀 때다. 그 밖의 변경(`shared/tests/` · `tools/` · `docs/` 처럼 설치본에 실리지 않는 것)으로는 올리지 않는다. ① · ② 에 걸려도 동작에 닿지 않는 변경(주석 · 오탈자)만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다.
  ```
- **CLAUDE.md 48행** — 끝 문장 「**agent frontmatter의 실재 필드는 `tools`(allowlist)와 `disallowedTools`(denylist) 둘뿐이다** — 이와 헷갈려 command/skill 계층의 `allowed-tools`(kebab, 실재 키)를 agent에 camelCase로 옮겨 적으면 존재하지 않는 필드가 되어 조용히 무시된다.」 를 아래로 바꾼다. 그 앞은 한 글자도 바꾸지 않는다.
  ```
  **agent frontmatter 에서 도구를 다루는 실재 필드는 `tools`(allowlist)와 `disallowedTools`(denylist) 둘뿐이다** — 이와 헷갈려 command/skill 계층의 `allowed-tools`(kebab, 실재 키)를 agent에 camelCase로 옮겨 적거나 skill 의 `disallowed-tools`(kebab)를 agent에 그대로 적으면 존재하지 않는 필드가 되어 조용히 무시된다.
  ```
- **CLAUDE.md 49행** — 「**이 계층은 제한이 아니다.**」 → 「**이 키는 제한이 아니다.**」. 줄 끝(「…없는 것보다 나쁘다.」 뒤)에 공백 하나와 아래를 붙인다.
  ```
  skill 이 도는 동안 도구를 실제로 빼는 실재 키는 `disallowed-tools`(kebab)다 — 그 skill 을 부른 턴에만 걸리고 사용자의 다음 메시지에서 풀린다. denylist 라 빠뜨린 도구와 내일 생길 도구는 막지 못하므로 Law 2 의 집행 지점이 아니다 — Law 2 의 분리는 지금처럼 agent 의 `tools:` allowlist 로만 한다. agent 에서 도구를 빼는 키는 camelCase `disallowedTools` 다.
  ```
- **CLAUDE.md 51행** — 머리 「**모든 skill에 `cost_class` 선언**」 → 「**모든 skill 은 frontmatter `metadata` 아래에 `cost_class` 를 선언한다**」. 뒤(` (`low`|…) …버그다.`)는 한 글자도 바꾸지 않는다.
- **철학 59행(P21)** — 「state secret hygiene, integrity-pin된 plugin-to-plugin trust, description prompt-injection 리뷰가 floor」 → 「state secret hygiene, description prompt-injection 리뷰가 floor」.
- **철학 63행(P22 첫 줄)** — 「…`cost_class: low|medium|high|variable`를 frontmatter에 선언한다.」 → 「…`cost_class: low|medium|high|variable`를 frontmatter `metadata` 아래에 선언한다.」. 나머지는 그대로다.

- [ ] **Step 1: 락을 새 문장으로 먼저 바꾼다(실패하는 테스트)**

- `test_governance_no_capability_caps.sh`: 131행 grep 앵커와 144행 `FIXED_CLAUDE` 의 머리를 새 머리로, 145행 `FIXED_P22_1` 의 「frontmatter에 선언한다」 를 「frontmatter `metadata` 아래에 선언한다」 로. 147–149행 단언 이름의 「설계 §2 확정 문안」 은 그대로 둔다.
- `shared/tests/test_cost_disclosure.sh` 113행 · `plugins/spec-distill/tests/test_epic_conductor_skill.sh` 227행: grep 앵커를 `'**모든 skill 은 frontmatter `metadata` 아래에 `cost_class` 를 선언한다**'` 로.
- `test_check_shape_completeness.py` `ANCHORS`: `"plugin_json_fields": "`plugin.json` 의 필수 키는 `name` 하나다"` · `"skills_cost_class": "모든 skill 은 frontmatter `metadata` 아래에 `cost_class` 를 선언한다"`. `test_checklist_synced_with_claude_md` 에 앵커마다 `self.assertEqual(shape.count(anchor), 1, f"checklist '{req}' anchor is not unique in §Plugin Shape")` 를 더한다(지금 일곱 앵커 모두 한 번씩이다 — 계획 때 확인).
- `test_governance_no_capability_caps.sh` 에 F6 블록을 넣는다(282행 `# R14 넘김` 앞):

```bash
# --- F6 규칙 개정 — 공식 쪽으로 옮긴 규칙 문장(설계 2026-11-15-rules-toward-official) ---
META_C="$(cline '**`plugin.json` — 필수 키와 판 올림.**')"
assert_contains "$META_C" '`plugin.json` 의 필수 키는 `name` 하나다' "F6 AC8: 필수 키는 name 하나"
assert_contains "$META_C" '`version` · `description` · `author` 를 빼면 `claude plugin validate` 가 경고를 낸다' "F6 AC8: 빼면 경고하는 키 셋"
assert_contains "$META_C" '올림 단위는 기본 브랜치에 머지되는 PR 하나다 — PR 안에서 커밋마다 올리지 않는다.' "F6 AC11: 올림 단위"
assert_contains "$META_C" '① `plugins/<X>/` 아래 파일(그 폴더 바로 아래의 `plugins/<X>/tests/` 폴더 · `CHANGELOG.md` · `README.md` 는 제외)을 바꾸거나' "F6 AC11: 올리는 때 ①"
assert_contains "$META_C" '② X 가 심볼릭 링크로 싣는 `shared/` 파일을 바꿀 때다.' "F6 AC11: 올리는 때 ②"
assert_contains "$META_C" '그 밖의 변경(`shared/tests/` · `tools/` · `docs/` 처럼 설치본에 실리지 않는 것)으로는 올리지 않는다.' "F6 AC11: 올리지 않는 때"
assert_contains "$META_C" '동작에 닿지 않는 변경(주석 · 오탈자)만 있는 PR 은 이유를 PR 본문에 적고 올리지 않을 수 있다.' "F6 AC11: 판단 문장"
assert_not_contains "$(cat "$CLAUDE_MD")" '모든 PR마다' "F6 AC11: 「모든 PR마다」 가 없다"
assert_not_contains "$(cat "$CLAUDE_MD")" 'integrity' "F6 AC6: CLAUDE.md 에 integrity 필드 문장이 없다"
p21="$(awk '/^### P21/{f=1;next} /^(## |### )/{f=0} f' "$PHIL")"
assert_not_contains "$p21" 'integrity' "F6 AC6: P21 에 integrity 가 없다"
assert_contains "$p21" '— state secret hygiene, description prompt-injection 리뷰가 floor.' "F6 AC6: P21 의 남은 floor 둘(양)"
ALLOW_C="$(cline '**`allowed-tools` 는 제한이 아니다.**')"
assert_contains "$ALLOW_C" '**이 키는 제한이 아니다.**' "F6 AC7: 틀린 것은 키에 대한 믿음"
assert_not_contains "$ALLOW_C" '이 계층은 제한이 아니다' "F6 AC7: 「이 계층은」 이 없다"
assert_contains "$ALLOW_C" 'skill 이 도는 동안 도구를 실제로 빼는 실재 키는 `disallowed-tools`(kebab)다' "F6 AC7: skill 의 disallowed-tools 는 실재 키"
assert_contains "$ALLOW_C" '막지 못하므로 Law 2 의 집행 지점이 아니다' "F6 AC7: Law 2 집행 지점이 아니다"
assert_contains "$ALLOW_C" 'agent 에서 도구를 빼는 키는 camelCase `disallowedTools` 다.' "F6 AC7: agent 쪽은 camelCase"
SCOPED_C="$(cline '**Scoped agents')"
assert_contains "$SCOPED_C" '**agent frontmatter 에서 도구를 다루는 실재 필드는 `tools`(allowlist)와 `disallowedTools`(denylist) 둘뿐이다**' "F6 D1.2: agent 도구 필드 문장"
assert_contains "$SCOPED_C" 'skill 의 `disallowed-tools`(kebab)를 agent에 그대로 적으면' "F6 D1.2: 헷갈리는 짝에 skill 의 kebab 키"
```

- [ ] **Step 2: 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh | grep '✗'; bash shared/tests/test_cost_disclosure.sh | tail -1; bash plugins/spec-distill/tests/test_epic_conductor_skill.sh | tail -1; python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_check_shape_completeness.py'`
Expected: 바이트 비교 둘 · F6 단언들 · cost 줄 단언(빈 grep) · `test_checklist_synced_with_claude_md` 가 실패한다.

- [ ] **Step 3: CLAUDE.md 네 줄과 철학 두 문장을 위 글자대로 고친다**

- [ ] **Step 4: 통과를 본다**

Run: Step 2 와 같은 명령 + `bash plugins/quality-gates/tests/test_law2_prose.sh | tail -1; bash shared/tests/test_charter_citations.sh | tail -3; bash shared/tests/test_invocation_surface.sh | tail -1`
Expected: 모두 실패 0. `test_charter_citations.sh` 가 새 백틱 토큰(`plugins/<X>/` 는 템플릿, `shared/tests/` · `tools/` · `docs/` · `shared/` 는 실재)을 받아들인다.

- [ ] **Step 5: 변이로 이빨을 본다**

1. CLAUDE.md cost 줄 머리를 옛 「모든 skill에 `cost_class` 선언」 으로 되돌린다 → governance 바이트 비교 ✗ · cost_disclosure ✗ · shape 앵커 ✗.
2. cost 줄 뒷부분의 「한 줄로」 를 「한 번에」 로 바꾼다 → governance 바이트 비교 ✗(줄의 나머지를 잡는다).
3. P22 를 옛 「frontmatter에 선언한다」 로 되돌린다 → `FIXED_P22_1` ✗.
4. 42행 끝에 「보안-critical 의존성은 optional `integrity` field로 pin.」 를 되살린다 → F6 AC6 ✗. 「모든 PR마다」 를 아무 데나 넣는다 → F6 AC11 ✗.
5. 49행을 「이 계층은 제한이 아니다」 로 되돌린다 → F6 AC7 두 줄 ✗.
6. 판단 문장(마지막 문장)을 지운다 → F6 AC11 판단 문장 ✗.
각각 되돌린 뒤 `git diff --stat` 로 확인한다.

- [ ] **Step 6: 손대지 않은 절 확인**

Run: `git diff -U0 HEAD -- CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md | grep '^@@'`
Expected: CLAUDE.md 는 42 · 48 · 49 · 51행만, 철학은 59 · 63행만. `## The Three Laws`(20–34행) · P8(78–88행)에 걸린 hunk 0.

- [ ] **Step 7: 커밋**

```bash
git add CLAUDE.md docs/philosophy/devbrew-harness-philosophy.md plugins/quality-gates/tests/test_governance_no_capability_caps.sh shared/tests/test_cost_disclosure.sh plugins/spec-distill/tests/test_epic_conductor_skill.sh plugins/plugin-audit/tests/test_check_shape_completeness.py
git commit -m "docs(rules): 필수 키 · 판 올림 · integrity · disallowed-tools · cost_class 자리를 공식 쪽으로 (F6)" -m "Co-Authored-By: ..."
```

---

### Task 4: 감사 검사 둘 — metadata 아래 cost_class · name 만 필수

AC2 · AC9.

**Files:**
- Modify: `plugins/plugin-audit/scripts/check-shape-completeness.py` (`check` 의 `plugin_json_fields` 판정 · `_has_cost_class`)
- Modify: `plugins/plugin-audit/scripts/check-staleness.py:554-566`
- Test: `plugins/plugin-audit/tests/test_check_shape_completeness.py` · `plugins/plugin-audit/tests/test_check_staleness.py`

**Interfaces:**
- Consumes: Task 2 의 frontmatter 꼴 · Task 3 의 `ANCHORS`.
- Produces: 출력 칸은 그대로다 — shape 는 `{"requirement","present","source_doc"}`, staleness 는 `class "category absence"` · `norm "cost_class"`. 두 스크립트는 각자 자기 frontmatter 블록을 받아 `metadata` 아래 직속 자식 `cost_class` 를 찾는 작은 함수(이름 `_metadata_cost_class(fm_block: str) -> bool`)를 따로 갖는다 — 두 스크립트 모두 self-contained 로 두고(plugin-audit SKILL.md 의 「F 는 self-contained」), 20줄 미만이라 중복 락에 걸리지 않는다.

`_metadata_cost_class` 의 규칙: frontmatter 블록의 줄을 차례로 본다. `^metadata:[ \t]*$` 줄 뒤부터 블록이 열린다. 빈 줄은 블록을 닫지 않는다. 들여쓰지 않은 비지 않은 줄이 블록을 닫는다. 블록 안에서 첫 들여쓴 자식 줄의 들여쓰기 폭을 직속 폭으로 삼고, 그 폭의 `cost_class:` 뒤에 빈칸 아닌 값이 있는 줄이 있으면 참이다. 맨 위 `cost_class:` 는 보지 않는다(설계 1 — 옛 자리 갈래 없음). 값 허용 집합은 지금처럼 보지 않는다.

- [ ] **Step 1: 실패하는 테스트를 쓴다**

`test_check_shape_completeness.py` — `_mk_plugin` 에 `skill_fm: str = None` 인자를 더해 `skills/s/SKILL.md` 를 `"---\nname: s\ndescription: d\n" + skill_fm + "---\nbody\n"` 로 만들게 한다(None 이면 skill 없음). 테스트:

```python
def _gaps(self, d):
    r, obj = run(d)
    self.assertEqual(r.returncode, 0, r.stderr)
    return {g["requirement"]: g for g in obj["shape_gaps"]}

def test_metadata_cost_class_is_declared(self):            # AC2 새 자리
    # skill_fm="metadata:\n  cost_class: high\n" → skills_cost_class present True
def test_top_level_only_cost_class_is_not_declared(self):   # AC2 맨 위에만
    # skill_fm="cost_class: high\n" → present False
def test_no_cost_class_is_not_declared(self):               # AC2 없음 — 맨 위에만과 같은 결과
    # skill_fm="" → present False
def test_indented_cost_class_outside_metadata_is_not_declared(self):   # Review Focus 1
    # skill_fm="hooks:\n  cost_class: high\n" → False
    # skill_fm="metadata:\n  a: 1\nhooks:\n  cost_class: high\n" → False
def test_metadata_cost_class_after_sibling_child_is_declared(self):    # Review Focus 2
    # skill_fm="metadata:\n  author: x\n\n  cost_class: low\n" → True
def test_nested_deeper_cost_class_is_not_declared(self):
    # skill_fm="metadata:\n  inner:\n    cost_class: low\n" → False
def test_body_metadata_block_is_not_declared(self):         # Review Focus 3
    # SKILL.md = "---\nname: s\ndescription: d\n---\nmetadata:\n  cost_class: high\n" → False
def test_both_places_counts_metadata(self):                 # Review Focus 5
    # skill_fm="cost_class: high\nmetadata:\n  cost_class: high\n" → True
def test_name_only_plugin_json_is_not_gap(self):            # AC9 — 옛 test_version_missing_is_gap 를 뒤집어 대신한다
    # plugin.json {"name": "myplugin"} → plugin_json_fields present True
def test_name_missing_is_gap(self):                         # AC9
    # {"version": "0.1.0", "description": "x"} → False
def test_empty_or_nonstring_name_is_gap(self):              # Review Focus 4
    # {"name": ""} · {"name": 5} · {"name": None} → False
def test_nonstring_version_is_gap(self):                    # AC9
    # {"name": "x", "version": 1} → False  (기존 test_null_version_is_gap_not_crash 는 그대로 둔다)
```

`test_version_missing_is_gap` 은 지운다(위 `test_name_only_plugin_json_is_not_gap` 가 그 자리를 뒤집어 갖는다). `test_complete_plugin_no_json_gap` · `test_cost_class_body_mention_does_not_satisfy` 는 그대로 둔다.

`test_check_staleness.py` `TestCategoryAbsence`:
- `test_cost_class_present_not_flagged` 의 SKILL.md 를 `"---\nname: doing-thing\nmetadata:\n  cost_class: low\n---\nbody\n"` 로 바꾼다.
- `test_top_level_only_cost_class_flagged_same_as_absent`: `"---\nname: doing-thing\ncost_class: low\n---\nbody\n"` → hits 1건, 그 `quote` 가 `test_cost_class_absent_with_skill_flagged` 의 hit 의 `quote` 와 같고 `metadata` 를 품는다.
- `test_cost_class_absent_with_skill_flagged` 에 문장 단언을 더한다: `quote` 에 `metadata` 가 있다 · `norm == "cost_class"` · `class == "category absence"` · 사실 칸 이름 집합이 `{"class","file","line","quote","norm"}` 그대로다(출력 칸이 늘지 않는다).
- `test_indented_cost_class_outside_metadata_flagged`: `"---\nname: doing-thing\nhooks:\n  cost_class: low\n---\nbody\n"` → hits 1건.

- [ ] **Step 2: 실패를 본다**

Run: `python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_check_shape_completeness.py'; python3 -m unittest discover -s plugins/plugin-audit/tests -p 'test_check_staleness.py'`
Expected: 새 자리 · name 만 · name 없음류 · staleness 문장 단언이 실패한다.

- [ ] **Step 3: 고친다**

- `check-shape-completeness.py`: `plugin_json_fields` 는 `bool(pj_text) and isinstance(pj.get("name"), str) and pj.get("name") != "" and ("version" not in pj or isinstance(pj.get("version"), str))`. 위 주석 줄(「version이 non-string…」)은 그 뜻 그대로 두고 「필수는 name 하나(CLAUDE.md §메타데이터)」 를 한 줄 더한다. `_has_cost_class(text)` 는 지금처럼 frontmatter 를 잘라 `_metadata_cost_class(fm)` 를 돌려준다 — 그 함수 위 주석을 「frontmatter `metadata` 아래의 cost_class 만 인정한다 — 맨 위 키와 본문 언급은 선언이 아니다」 로 고친다.
- `check-staleness.py` (2) 갈래: `re.search(r"^cost_class:", …)` 를 `_metadata_cost_class(block)` 로, 사실 문장을 `f"skill '{skill_dir.name}'에 metadata 아래 cost_class 선언 없음"` 으로 바꾼다. `norm="cost_class"` · 줄 번호 1 · 경로는 그대로다.

- [ ] **Step 4: 통과를 본다**

Run: Step 2 와 같은 명령 + `for p in plugin-audit project-init quality-gates spec-distill; do python3 plugins/plugin-audit/scripts/check-shape-completeness.py plugins/$p --repo-root .; python3 plugins/plugin-audit/scripts/check-staleness.py plugins/$p | python3 -I -c "import json,sys; print(sum(1 for f in json.load(sys.stdin)['facts'] if f.get('norm') == 'cost_class'))"; done`
Expected: unittest 실패 0. 실제 네 플러그인에서 `skills_cost_class` · `plugin_json_fields` 가 `"present": true`, staleness 의 `norm` `cost_class` 사실 0건씩. (staleness 사실의 문장 칸은 `quote` 다 — Step 1 의 문장 단언도 그 키를 읽는다.)

- [ ] **Step 5: 변이로 이빨을 본다**

1. `plugin_json_fields` 판정을 옛 `all(k in pj for k in ("name","version","description"))` 로 되돌린다 → `test_name_only_plugin_json_is_not_gap` ✗(뒤집은 단언의 이빨).
2. `name` 의 빈 문자열 검사를 지운다 → `test_empty_or_nonstring_name_is_gap` ✗.
3. `_metadata_cost_class` 를 「블록 어디든 들여쓴 `cost_class:`」 로 넓힌다 → indented-outside · nested-deeper ✗.
4. 들여쓰지 않은 줄에서 블록을 닫지 않게 한다 → `metadata:\n  a: 1\nhooks:\n  cost_class: high` ✗.
5. staleness 갈래를 옛 `^cost_class:` 로 되돌린다 → `test_cost_class_present_not_flagged` ✗ · 맨 위에만 테스트 ✗.
각각 되돌리고 `git diff --stat` 로 확인한다. 같은 길이 변이는 `PYTHONDONTWRITEBYTECODE=1` 로 돈다.

- [ ] **Step 6: 커밋**

```bash
git add plugins/plugin-audit/scripts/check-shape-completeness.py plugins/plugin-audit/scripts/check-staleness.py plugins/plugin-audit/tests/test_check_shape_completeness.py plugins/plugin-audit/tests/test_check_staleness.py
git commit -m "feat(plugin-audit): metadata 아래 cost_class 를 읽고 plugin.json 은 name 만 필수로 본다 (F6)" -m "Co-Authored-By: ..."
```

---

### Task 5: 저술 가이드 · request-framing 한 문장 · 문서 셋 밖 두 자리

AC4(저술 가이드) · AC8(저술 가이드) · AC13 · AC14 · AC17 · AC18.

**Files:**
- Modify: `docs/plugin-authoring.md:10,14,17,23-25,47,50,58` + 트리에 두 줄
- Modify: `plugins/spec-distill/skills/request-framing/SKILL.md:322` (이 한 줄만)
- Modify: `docs/git-workflow/commit-conventions.md:61`
- Modify: `shared/README.md:3-4,30,33`
- Modify: `plugins/quality-gates/tests/test_governance_no_capability_caps.sh` (Task 3 의 F6 블록 끝에 이어 붙인다)

**Interfaces:**
- Consumes: Task 3 의 CLAUDE.md 판 올림 줄(문서 셋 밖 두 자리가 그것을 가리킨다).

새 글자(이대로 넣는다):

- **트리 plugin.json 주석(10행)**: `│   └── plugin.json           # 필수 키는 name 하나 — version · description · author 를 빼면 claude plugin validate 가 경고. version 을 적으면 0.1.0 에서 시작`
- **트리 README 줄 다음에 한 줄**: `├── dependencies.md           # 기대는 도구 · 다른 플러그인의 표(이름 · 최소 판 · 강도 · 없을 때) — 판 칸은 check_deps.py measure 가 잰다`
- **트리 SKILL.md 주석(14행)**: `│   └── SKILL.md              # frontmatter metadata 아래 cost_class 선언 · trigger. 진입 skill 의 꼴(allowed-tools 한 줄 · ! 사전 검사 줄 · ## 진입 단계)은 있는 진입 skill(plugins/spec-distill/skills/spec-review/SKILL.md)을 본보기로`
- **트리 agents 줄 다음에 한 줄**: `├── references/               # optional — skill · agent 가 필요할 때 읽는 긴 절차 · 계약`
- **트리 scripts 주석(17행)**: `├── scripts/                  # optional — 진입 skill 이 있으면 진입 사전 검사 스크립트(entry_preflight.py, shared/entry/ 정본의 심볼릭 링크)가 여기 있다. 그 밖에 hook · skill 이 부르는 shell/python 헬퍼`
- **model 문단 예시(23행)**: 「`quality-gates:doc-recritic`(Phase 1.5 재비판, 공유 정본의 copy-of 사본)」 → 「`spec-distill:doc-recritic`(문서 리뷰 엔진의 재비판, 공유 정본의 copy-of 사본)」. **24–25행**: 「이 플러그인의\n사본이」 → 「spec-distill 의\n사본이」. 이 문단의 다른 글자(규칙 문장 · 「재량이 없는 쪽의 예」 · `smoke-probe` · 정본 키 부재 문장)는 한 글자도 바꾸지 않는다.
- **구현 줄(47행)**: 「`plugin-dev:skill-development` / `command-development` / `agent-development` / …」 에서 「 / `command-development`」 를 뺀다.
- **50행**: 「`plugin-dev`의 `/create-plugin`은」 → 「`plugin-dev:create-plugin` 은」.
- **끝 줄(58행)**: `**Merge 전:** [Plugin Shape](../CLAUDE.md#plugin-shape)의 모든 bullet 만족. \`version\` 을 적는 새 플러그인은 \`0.1.0\` 에서 시작한다.`
- **request-framing 322행**: `(does not — cannot 이 아닙니다. \`allowed-tools\` 는 제한이 아니고, 이 skill 은 도구를 빼는 키를 쓰지 않습니다.` — 323행(「이 경계를 지키는 것은 …」)은 그대로다.
- **commit-conventions 61행**: `이 레포는 자동 릴리스 도구를 쓰지 않는다 — 판은 [CLAUDE.md](../../CLAUDE.md) 의 판 올림 규칙대로 PR 에 한 번 손으로 올린다.`
- **shared/README 4행 뒤(빈 줄 하나 두고) 새 문단**: `폴더가 들어가지 않을 뿐, 플러그인이 심볼릭 링크로 싣는 파일의 내용은 설치할 때 설치본에 들어간다(아래 표). 그래서 여기 파일이 바뀔 때 어느 플러그인의 판을 올리는지는 \`CLAUDE.md\` 의 판 올림 규칙을 따른다.`
- **shared/README 30행**: 「세 플러그인에 심볼릭 링크」 → 「네 플러그인에 심볼릭 링크」. **33행**: 「세 플러그인에 **물리 사본**으로 배포된다」 → 「`project-init` 에 **물리 사본**으로 배포된다」.

- [ ] **Step 1: 실패하는 단언을 쓴다 — Task 3 의 F6 블록 끝에 이어서**

```bash
AUTH6="$(cat "$AUTHORING")"
TREE6="$(awk '/^```$/{n++; next} n==1' "$AUTHORING")"
assert_contains "$TREE6" '# 필수 키는 name 하나 — version · description · author 를 빼면 claude plugin validate 가 경고' "F6 AC8: 가이드 plugin.json 주석"
assert_contains "$TREE6" '# frontmatter metadata 아래 cost_class 선언' "F6 AC4: 가이드 SKILL.md 주석"
assert_contains "$TREE6" '├── dependencies.md' "F6 AC13: 트리에 dependencies.md"
assert_contains "$TREE6" '├── references/' "F6 AC13: 트리에 references/"
assert_contains "$TREE6" '진입 사전 검사 스크립트(entry_preflight.py' "F6 AC13: scripts 주석"
assert_contains "$TREE6" '## 진입 단계' "F6 AC13: SKILL.md 주석이 진입 꼴을 가리킨다"
for gone in 'quality-gates:doc-recritic' 'Phase 1.5' 'command-development' '`/create-plugin`' 'hook에서 호출하는' '시작 버전 `0.1.0`' '이 플러그인의'; do
  assert_not_contains "$AUTH6" "$gone" "F6 AC13: 가이드에 「${gone}」 없음"
done
assert_contains "$AUTH6" '`spec-distill:doc-recritic`(문서 리뷰 엔진의 재비판, 공유 정본의 copy-of 사본)' "F6 AC13: 실재하는 예시 agent(양)"
assert_contains "$AUTH6" '`plugin-dev:create-plugin` 은' "F6 AC13: create-plugin 완전명(양)"
assert_contains "$AUTH6" '`version` 을 적는 새 플러그인은 `0.1.0` 에서 시작한다.' "F6 AC8: 끝 줄(양)"
# 가이드가 예시로 드는 이 리포의 agent · skill 이름은 실재한다
for p in plugins/spec-distill/agents/doc-recritic.md plugins/plugin-audit/agents/smoke-probe.md \
         plugins/spec-distill/skills/spec-review/SKILL.md plugins/spec-distill/skills/reviewing-brief/SKILL.md \
         plugins/plugin-audit/skills/plugin-audit/SKILL.md; do
  [ -f "$p" ] && ok "F6 AC13: 예시 이름 실재 — $p" || no "F6 AC13: 예시 이름이 없다 — $p"
done
RF="plugins/spec-distill/skills/request-framing/SKILL.md"
assert_not_contains "$(cat "$RF")" '도구를 막을 수단이 없' "F6 AC18: request-framing 에 옛 믿음 문장이 없다"
assert_contains "$(cat "$RF")" '(does not — cannot 이 아닙니다. `allowed-tools` 는 제한이 아니고, 이 skill 은 도구를 빼는 키를 쓰지 않습니다.' "F6 AC18: 그 자리에 새 문장(양)"
CC="docs/git-workflow/commit-conventions.md"
assert_not_contains "$(cat "$CC")" 'release-please' "F6 AC17: 자동 릴리스 도구가 판을 올린다는 문장이 없다"
assert_contains "$(cat "$CC")" '이 레포는 자동 릴리스 도구를 쓰지 않는다 — 판은 [CLAUDE.md](../../CLAUDE.md) 의 판 올림 규칙대로' "F6 AC17: CLAUDE.md 를 가리킨다(양)"
n_entry="$(find plugins/*/scripts -name entry_preflight.py -type l | grep -c .)"
case "$n_entry" in 3) w=세 ;; 4) w=네 ;; 5) w=다섯 ;; *) w="?" ;; esac
assert_contains "$(grep -F '`entry/`' shared/README.md)" "${w} 플러그인에 심볼릭 링크" "F6 AC17: shared/README entry 수가 실제 링크 수(${n_entry})와 같다"
assert_eq "$(grep -rl 'copy-of: shared/python/devbrew-python.sh' plugins | grep -c .)" "1" "F6 AC17: python 사본은 하나다(실측)"
assert_contains "$(grep -F '`python/`' shared/README.md)" '`project-init` 에 **물리 사본**으로 배포된다' "F6 AC17: shared/README python 줄"
assert_contains "$(cat shared/README.md)" '플러그인이 심볼릭 링크로 싣는 파일의 내용은 설치할 때 설치본에 들어간다' "F6 AC17: 폴더와 링크 내용의 구분"
assert_contains "$(cat shared/README.md)" '판을 올리는지는 `CLAUDE.md` 의 판 올림 규칙을 따른다' "F6 AC17: 판 올림 안내"
```

- [ ] **Step 2: 실패를 본다**

Run: `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh | grep '✗'`
Expected: 위 F6 단언 가운데 문서를 고쳐야 통과하는 것들이 ✗. 「예시 이름 실재」 다섯과 python 사본 수는 이미 ✓.

- [ ] **Step 3: 위 글자대로 네 파일을 고친다**

- [ ] **Step 4: 통과를 본다**

Run: `bash plugins/quality-gates/tests/test_governance_no_capability_caps.sh | tail -1; bash plugins/quality-gates/tests/test_law2_prose.sh | tail -1; bash shared/tests/test_invocation_surface.sh | tail -1; bash shared/tests/test_copy_of_contract.sh | tail -1; bash shared/tests/test_plain_language_block.sh | tail -1`
Expected: 모두 실패 0. 호출 표면 검사가 `docs/git-workflow/**` · `shared/**` · `docs/plugin-authoring.md` 의 새 문장을 받는다(`plugin-dev:create-plugin` 은 앞에 `/` 가 없어 축 G 대상이 아니다).

- [ ] **Step 5: AC14 · AC18 — 고친 자리만 바뀌었는지 본다**

Run: `git diff --word-diff HEAD -- docs/plugin-authoring.md | sed -n '/model. 키를 두지 않는다/,/test_copy_of_contract/p'` · `git diff -U0 HEAD -- plugins/spec-distill/skills/request-framing/SKILL.md | grep '^[-+][^-+]'`
Expected: model 문단에서 바뀐 낱말은 예시 구절(`quality-gates:doc-recritic` · 「Phase 1.5 재비판」 · 「이 플러그인의」)뿐이다. request-framing 은 322행 한 줄만 빠지고 한 줄만 더해진다(frontmatter 의 Task 2 변경은 이미 커밋돼 HEAD 에 있다).

- [ ] **Step 6: 변이로 이빨을 본다**

1. 가이드에 「`quality-gates:doc-recritic`」 를 되살린다 → F6 AC13 ✗. 1b. 가이드 SKILL.md 주석을 옛 「cost_class 선언, frontmatter trigger」 로, plugin.json 주석을 옛 「필수 — name, version (0.1.0로 시작), description」 으로 되돌린다 → F6 AC4 · AC8 가이드 단언 ✗. 2. request-framing 322행을 옛 문장으로 되돌린다 → AC18 두 줄 ✗. 3. shared/README 30행을 「세 플러그인」 으로 되돌린다 → AC17 entry ✗. 4. commit-conventions 를 옛 문장으로 되돌린다 → AC17 두 줄 ✗. 각각 되돌리고 `git diff --stat` 로 확인한다.

- [ ] **Step 7: 커밋**

```bash
git add docs/plugin-authoring.md plugins/spec-distill/skills/request-framing/SKILL.md docs/git-workflow/commit-conventions.md shared/README.md plugins/quality-gates/tests/test_governance_no_capability_caps.sh
git commit -m "docs(rules): 저술 가이드 낡은 자리 · request-framing 한 문장 · 릴리스와 shared 안내를 맞춘다 (F6)" -m "Co-Authored-By: ..."
```

---

### Task 6: 네 플러그인의 판을 한 번씩 올린다

AC10 · AC12. 설계 5 의 정의를 이 PR 자신에 적용한다 — skill frontmatter 가 바뀌어 네 플러그인 모두 ① 에 걸린다.

**Files:**
- Modify: `plugins/{plugin-audit,project-init,quality-gates,spec-distill}/.claude-plugin/plugin.json` (`version` 값만)
- Modify: 네 플러그인의 `CHANGELOG.md` (맨 위에 헤딩 하나씩)

- [ ] **Step 1: 판을 정한다**

Run: `git fetch origin main && git show origin/main:plugins/plugin-audit/.claude-plugin/plugin.json | grep version` (네 플러그인 모두)
Expected: 1.7.0 · 5.4.1 · 14.10.0 · 8.16.0 이면 새 판은 1.8.0 · 5.4.2 · 14.10.1 · 8.16.1. 기본 브랜치가 올라가 있으면 그 판 위에서 plugin-audit minor · 나머지 patch 로 정한다.

- [ ] **Step 2: plugin.json 의 `version` 값만 바꾸고 CHANGELOG 맨 위(기존 첫 `## [` 앞)에 헤딩 하나씩 넣는다**

헤딩 꼴은 그 파일의 기존 헤딩과 같다: `## [<판>] — 2026-11-16`(머지 날이 다르면 그날). 내용:
- plugin-audit(`### Changed`): 감사 검사가 skill 의 `cost_class` 를 frontmatter `metadata` 아래에서 읽는다 — 맨 위에만 있으면 「선언 없음」 이다. plugin.json 은 `name` 하나만 필수로 보고, `version` 이 있는데 문자열이 아니면 지금처럼 gap 이다. plugin-audit skill 의 `cost_class` 를 `metadata` 아래로 옮겼다. (옛 판의 plugin-audit 으로 새 레포를 감사하면 skill 들을 「선언 없음」 으로 센다 — 갱신하면 사라진다.)
- project-init · quality-gates(`### Changed`): skill 의 `cost_class` 를 frontmatter `metadata` 아래로 옮겼다(공식 skill frontmatter 에 없는 맨 위 키를 없앤다). 값은 그대로다.
- spec-distill(`### Changed`): skill 여섯의 `cost_class` 를 `metadata` 아래로 옮겼다. request-framing 본문의 「skill 계층에는 도구를 막을 수단이 없다」 를 「`allowed-tools` 는 제한이 아니고 이 skill 은 도구를 빼는 키를 쓰지 않는다」 로 고쳤다.

- [ ] **Step 3: 정합 락과 한 번 올림을 본다**

Run: `bash shared/tests/test_changelog_integrity.sh | tail -1; bash shared/tests/test_plugin_description_parity.sh | tail -1; git diff origin/main -- 'plugins/*/CHANGELOG.md' | grep -c '^+## \['; for p in plugin-audit project-init quality-gates spec-distill; do python3 -I -c "import json,sys; d=json.load(open(sys.argv[1], encoding='utf-8')); print(sys.argv[1], sorted(d), d['version'])" plugins/$p/.claude-plugin/plugin.json; done`
Expected: 두 락 실패 0 · 늘어난 헤딩 4(플러그인마다 1) · 키 넷(`author` · `description` · `name` · `version`) 그대로.

- [ ] **Step 4: 커밋**

```bash
git add plugins/plugin-audit/.claude-plugin/plugin.json plugins/project-init/.claude-plugin/plugin.json plugins/quality-gates/.claude-plugin/plugin.json plugins/spec-distill/.claude-plugin/plugin.json plugins/plugin-audit/CHANGELOG.md plugins/project-init/CHANGELOG.md plugins/quality-gates/CHANGELOG.md plugins/spec-distill/CHANGELOG.md
git commit -m "chore(release): 규칙 개정으로 네 플러그인의 판을 한 번씩 올린다 (F6)" -m "Co-Authored-By: ..."
```

---

### Task 7: 마무리 확인 · 전체 리뷰의 AC 보고 · 미룸 표

AC5 · AC10 · AC14 · AC15 · AC16 의 끝 확인과, 지휘 입력이 정한 마지막 절차.

**Files:**
- Modify: `docs/superpowers/specs/2026-11-15-rules-toward-official-design.md` 의 `## 미룸` 표(행 추가만 — 다른 글자는 고치지 않는다)
- Create(추적하지 않음): `.claude/tmp/f6/ac-report.md` — 먼저 `git check-ignore -q .claude/tmp/f6/ac-report.md` 로 무시되는 자리인지 본다

- [ ] **Step 1: 손대지 않은 것의 diff 가 0 인지 본다**

Run: `git diff --stat origin/main -- 'plugins/*/agents/' 'shared/docreview/agents/' shared/tests/test_changelog_integrity.sh shared/tests/test_plugin_description_parity.sh plugins/project-init/templates/shared/commit-conventions.md` · `git diff origin/main -- plugins/quality-gates/tests/test_governance_no_capability_caps.sh | sed -n '/AC8d/,/AC3 · AC4/p' | grep -c '^[-+][^-+]'` · `git diff -U0 origin/main -- CLAUDE.md | grep '^@@'` · `git diff -U0 origin/main -- docs/philosophy/devbrew-harness-philosophy.md | grep '^@@'`
Expected: 첫 명령 출력 없음(AC5 · AC10 · AC14 의 파일 쪽). model 규약 블록 안의 바뀐 줄 0(AC14 단언 단위). CLAUDE.md hunk 는 42 · 48 · 49 · 51행, 철학 hunk 는 59 · 63행뿐(AC15). model 키를 무는 다른 테스트(`grep -rl "model" plugins/*/tests shared/tests` 가운데 agent `model` 키 단언을 가진 파일)는 `git diff --stat origin/main` 에 나오지 않는다.

- [ ] **Step 2: 공식 검증 명령**

Run: `command -v claude && for p in plugin-audit project-init quality-gates spec-distill; do claude plugin validate plugins/$p; done`
Expected: 돌면 결과를 PR 본문에 적는다. `claude` 가 없거나 실패하면 「재지 못함」 과 이유를 적는다.

- [ ] **Step 3: 전체 스위트(AC16)**

Run: `python3 "/Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0"/scripts/suite_lock.py run --lock /Users/jeonghokim/Downloads/devbrew/.claude/spec-distill/conductor/2026-11-14-framing-interview-constraint-audit-brief/files/suite-lock --owner <이름> --wait 7200 -- bash -c 'bash tools/suite/run-all.sh'`
Expected: `FAILED` 줄 가운데 기본 브랜치에도 있는 것(worktree 에서만 나는 기존 실패 — 예: `TestCrossResolverAdvisory`)을 뺀 나머지 0. 기본 브랜치 쪽 실패 목록은 지휘자의 대조가 정본이다 — 이 브랜치에만 있어 보이는 실패가 있으면 이름을 적어 보고한다. 잠금을 못 잡으면 주인 · 잡은 시각을 보고한다.

- [ ] **Step 4: 마지막 전체 리뷰에 AC 목록을 싣는다**

고른 실행 방식의 마지막 전체 리뷰(브랜치 전체)에 설계문서 `## Acceptance Criteria` 의 AC1–AC18 원문을 그대로 싣고, 리뷰가 AC 마다 한 줄씩 `AC1: 구현됨 — <근거>` 꼴(판정은 구현됨 · 미룸 · 빠짐 중 하나)로 보고하게 한다. 리뷰에 함께 묻는다: 과제 사이 이음매(Task 2 의 frontmatter 꼴 ↔ Task 4 의 파서 ↔ Task 3 의 문장), 계획이 쓴 테스트 코드(Task 2 의 새 테스트 · Task 3 · 5 의 F6 블록 — plan-mandated 라벨을 붙인다)의 단언이 실제로 이빨이 있는지, e2e-scenarios 를 두는 이유가 맞는지. 그 보고를 `.claude/tmp/f6/ac-report.md` 에 적는다.

- [ ] **Step 5: 미룸 표에 올린다**

보고의 미룸 · 빠짐과 리뷰 후속으로 미룬 것을 설계문서 `## 미룸` 표에 행(항목 · 이유 · 받는 곳)으로 더한다. 더한 것이 있으면 pathspec 으로 커밋한다(`docs(spec): 규칙 개정 설계 — 구현 뒤 미룸 (F6)`).

- [ ] **Step 6: PR 전 대조**

Run: `python3 /Users/jeonghokim/.claude/plugins/cache/devbrew/spec-distill/8.14.0/scripts/check_bundle_coverage.py --impl <이 worktree 의 설계문서 절대경로> <.claude/tmp/f6/ac-report.md 절대경로>`
Expected: 첫 줄과 경고를 사용자에게 그대로 보인다(rc 1 은 경고다 — 막지 않는다).

- [ ] **Step 7: PR 본문 재료를 모은다**

PR 은 지휘자가 연다. 본문 재료: integrity 문장을 지운 근거(공식 plugin.json · 마켓플레이스 필드 표에 없음 · 레포에서 쓰는 곳 0) · Step 1 의 「diff 없음」 결과 · Step 2 의 검증 결과 또는 「재지 못함」 · e2e-scenarios 의 정적 배선 블록을 그대로 둔 이유(「제거된 표면 — 역사 기록」 머리 아래의 죽은 블록이고 없는 agent 를 먼저 열어 지금도 돌지 않는다) · request-framing 의 다른 본문은 diff 없음 · 판 넷과 CHANGELOG 헤딩 넷.
