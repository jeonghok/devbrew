# R10 계획 2 — 끝 게이트 · 분해 · 결함 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 인터뷰 끝 게이트의 선택지 이름이 실제 다음 줄과 맞고(분해된 일 · 둘째 질문), 하나짜리 brief 의 다음 단계가 「기본」이 되며, 분해 판단이 조사 에픽 · §4 레포 주장 · 위험 번호를 생성기와 어긋나지 않게 다루고, 넘겨받은 결함(같은 날 같은 주제 · §4 강조 «»)을 고친다.

**Architecture:** 게이트 모양은 정본 `references/proceed-gate.md` Step B 의 「둘째 질문(선택)」 문단 하나에 두고, 인터뷰 끝(`finishing.md` B-2 · B-3)은 ①② 이름 표와 다른 다음 단계의 줄만 더한다. 분해 쪽은 `roadmap_model.py` 에 위험 줄 판독 함수 하나(`brief_risk_numbers`)와 §4 RC 색인 한 줄, `roadmap_render.py` 에 색인 · 알림 표지, `roadmap_write.py` 에 알림 한 줄을 더한다 — 생성기는 이미 선택 칸 여섯(흐름 · 산출물 포함)을 쓰므로 분해 표 문면만 연다. `state_path.py` 는 끝난 인터뷰 자리를 피하는 갈래 하나, `check_brief.py` 는 실패 메시지 한 줄만 바꾼다.

**Tech Stack:** Markdown skill · reference · agent 정의, Python 3.9(표준 라이브러리), bash 3.2 호환 셸 테스트(`shared/tests/assert.sh`), `python3 -m unittest`.

**Spec:** `docs/superpowers/specs/2026-10-19-interview-open-research-design.md` (§5 의 next_phase · trivia · steelman 행 · §6 · §7 · §8 의 «» · AC17 의 게이트 정본 쪽 · AC18~AC29 · AC32)

## Global Constraints

- **시작 시점.** R2a 계획 2(#231)가 머지된 기본 브랜치 위에서 시작한다(이 브랜치의 밑이 그것이다). 줄 번호는 `e160ebc8` 기준이다 — Task 0 이 다시 읽고 맞춘다.
- 브랜치 `feature/interview-end-gates`. 기본 브랜치를 merge 한다(rebase 금지). HEAD 를 뒤로 옮기지 않는다. 커밋은 pathspec(`git commit -- <경로…>`), `git stash` 금지.
- 커밋 메시지: `type(scope)` 영어 · 설명 한국어. 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 와 세션이 주는 `Claude-Session` 줄.
- 버전: spec-distill minor bump. **번호는 머지 직전에 정한다** — 계획 안에서는 `<머지 때>`. CHANGELOG 머리는 바로 다음 버전만, plugin.json 과 같게(`shared/tests/test_changelog_integrity.sh`).
- 새 셸 테스트는 `chmod +x` 후 `git ls-files -s` 로 `100755` 확인. 파일 읽기는 `encoding="utf-8"` 명시. 플러그인 `.py` 에 `"python3"` 리터럴 금지. 인라인 python 은 `python3 -I`. `scripts/*.py` 의 `re.compile` 리터럴이 `"## 6. 사용자 원문"` 앞 3글자 이상과 맞으면 안 된다. 긴 한글 줄은 인접 문자열로 나눈다(CPython 토크나이저).
- bash 3.2: `$var` 바로 뒤에 한글이 오면 `${var}`. `$( )` 안 heredoc 금지. 변이 실행은 `PYTHONDONTWRITEBYTECODE=1`, 변이 전에 커밋하고 `git checkout HEAD -- <파일>` 뒤 `git diff HEAD --stat` 이 비었는지 본다.
- 레포 전용 값(경로 · 테스트 명령 · 브랜치 · 모델 · `gh`)을 박지 않는다.
- **persona 편집은 보안 리뷰 대상이다** — `agents/steelman-builder.md`(Task 3). 그 과제의 리뷰어 요청 · 커밋 본문 · PR 본문에 「persona 편집 — 보안 리뷰 대상(레포 규칙 「Persona 파일은 보안-민감 코드」)」.
- 모델이 읽는 새 문면에는 출처 · 배경 · 정당화를 쓰지 않는다(Self-narrating artifact). 사람에게 보이는 새 문면(실패 메시지 · 알림 줄 · README · CHANGELOG)은 `shared/style/plain-language.md`.
- 지휘자 수리 #227 이 brief 다음 세션 줄에 넣은 문장(「사용자 선호: …」 · 「brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.」 · 「설계문서 점검(builder check)과 그 질문을 마치고 문서를 승인받는 자리에서」 · 「메시지 모양(…)은 brainstorming 을 따른다.」)은 지우지 않는다.
- **계획 1 과 같은 파일.** `check_brief.py` · `tests/test_check_brief.sh` · `templates/interview-brief-template.md` · `skills/spec-interview/SKILL.md` · `skills/request-framing/SKILL.md` · `references/proceed-gate.md` · README · CHANGELOG · plugin.json 을 계획 1(`feature/interview-open-research`)도 고친다. 이 계획의 자리는 계획 1 의 자리와 겹치지 않게 골랐다(각 과제의 `Modify:` 줄). 뒤에 머지하는 쪽이 기본 브랜치를 merge 하고 두 쪽 변경을 모두 남긴다.

## 설계와 다른 점 · 설계에 없던 결정

1. **게이트 정본의 둘째 질문 문단은 계획 1 계획(Task 7 Step 3)과 글자 그대로 같은 문단을 쓴다**(아래 Task 1 Step 3 의 인용). 이 계획이 먼저 머지하면 이 계획이 싣고 계획 1 은 읽기만 한다. 계획 1 구현이 먼저 머지했으면 이 계획은 정본을 고치지 않고, 들어간 문단의 머리글 · 선택지 문구를 인터뷰 끝 문장에 맞춘다(Task 0 Step 3 · Task 1 Step 3).
2. **조사 에픽은 새 종류 없이 「묶음」 + `흐름` · `산출물` 칸으로 쓴다**(설계 `## 미룸` 의 계획 2 행). R5 모델(`roadmap_model.py`)의 `REQUIRED` · `FORBIDDEN` 은 선택 칸을 막지 않고, 생성기(`roadmap_render.py`)는 이미 열일곱 칸 표(선택 칸 여섯)를 읽어 블록에 쓰며, `roadmap_status.py` 는 묶음 에픽의 `산출물:` 을 이미 읽는다. 새 종류는 `REQUIRED` · `FORBIDDEN` · 상태 계산 · 화면을 함께 넓혀야 한다. 그래서 고칠 것은 분해 판단 표의 문면(열일곱 칸을 쓰는 때 · 두 칸의 뜻)이다.
3. **§4 강조 «» 는 실패 메시지로 고친다 — 키 자리만 읽게 좁히지 않는다**(설계 `## 미룸` 의 계획 2 행). §4 의 «» 를 출처키로 읽는 곳이 넷이다(`check_brief.py` 의 #13 · N2, `roadmap_model.KEY_RE`, `roadmap_render._section4_index`, `check_bundle_coverage.py` 의 brief 모드). 하나만 좁히면 게이트를 통과한 강조어가 생성기에서 배정할 번호가 된다. 넷을 함께 좁히면 지금 있는 모든 brief 의 §4 문법이 바뀐다. 메시지가 「강조라면 「」로」를 먼저 말하면 사람이 강조어를 걷어 내 네 곳이 함께 맞는다.
4. **위험 번호 꼴은 `- 위험 K<n> — <숨은 가정 | 실패 양식 | 리뷰 참고> …`** 다. 줄 끝은 결정 연결 자리라 번호를 앞에 둔다. Step A 는 분해 표가 미리 매긴 순서(숨은 가정 · 실패 양식 · 리뷰 참고, K1 부터)로 박는다. 위험 줄은 모두 박혔거나 모두 안 박혔어야 한다 — 섞이면 생성기가 「가장 큰 K 다음 수」를 말하며 멈춘다. 뒤에 더하는 줄(B-A 의 리뷰 참고)은 가장 큰 K 다음 수를 받고, 지운 번호는 다시 쓰지 않는다. 표가 지운 번호를 배정하고 있으면 검사기의 `unknown_ids` 로 나오므로 B-R 의 표 고치기 갈래에 `unknown_ids` 를 더한다.
5. **옛 brief(번호 없는 위험 줄) 알림은 `roadmap_write.py` 의 create · update 가 낸다** — `[spec-distill]` 한 줄. 판독 함수 `brief_universe` 의 반환 꼴(셋)은 그대로 둔다(호출자 다섯).
6. **「끝난 인터뷰」의 판정은 brief 자리(`<줄기>.md`)에 `type: interview-brief` 파일이 있는 것**이다 — `interview_state.py` 가 이어 가기를 거절하는 규칙과 같다. 시험을 위해 `--time HHMM` 선택 인자를 둔다. 새 자리(`<주제>-<HHMM>`)도 끝난 인터뷰거나 남의 파일이면 rc 2 로 멈춘다.
7. **steelman 의 「셋 중 하나」는 builder persona 와 함께 인터뷰 쪽 정의(`references/steelman.md` 의 trigger 줄)도 예시로 낮춘다.** builder 만 낮추면 builder 는 다른 이유를 받는데 인터뷰가 셋일 때만 부른다.
8. **하나짜리 brief 의 `next_phase` 값은 기본 `superpowers:brainstorming` 그대로 두고**, 템플릿 주석 · 정의 문장이 「기본 다음 단계」를 말한다. 둘째 질문에서 제안을 고르면 확정 반영 write 에서 그 값을 고른 skill 의 완전명으로 바꾼다. 게이트는 이 값을 판정하지 않는다(`test_check_brief_frontmatter.py` B4).
9. **brief 다음 세션 줄의 원칙 3 · 4 · 6 문장은 에픽 넘김 줄(`epic-handoff.md`)의 문장을 글자 그대로 옮기고, 원칙 2 문장은 새로 쓴다** — 에픽 넘김 줄은 원칙 2 를 `흐름:` 칸 문장으로 싣고 있어 같은 뜻 문장이 없다. 원칙 5 는 싣지 않는다(설계 §6 지휘자 판정).
10. **분해된 일의 끝 게이트에는 둘째 질문을 두지 않는다** — 에픽마다의 흐름은 지휘자가 로드맵 `흐름:` 칸으로 정한다.
11. **AC29 는 Task 0 의 확인 단계 하나다**(과제 없음 — 기존 T18 · T24b 를 돌려 ✓ 만 본다).

## Review Focus

1. **옛 brief(위험 줄에 번호 없음)로 로드맵을 다시 만든다.** 사람은 지금처럼 만들어지되 「줄 순서로 매겼다」는 알림을 한 줄 보기를 기대한다. Task 4 의 `old_order_notice` 사례가 잠근다.
2. **Step A 가 번호를 박은 뒤 B-A 가 번호 없는 리뷰 참고 위험 줄을 더한다.** 생성기는 조용히 줄 순서로 섞어 매기지 않고, 어느 줄에 어떤 번호(가장 큰 K 다음 수)를 박을지 말하며 멈춰야 한다. Task 4 의 `test_mixed_is_an_error` 가 잠근다.
3. **위험 하나를 지운 뒤 다시 만드는데 분해 표가 지운 번호를 아직 배정한다.** 남은 위험이 다른 에픽에 붙지 않고, 생성기가 그 번호를 사유로 멈추며 B-R 이 표 고치기로 간다. Task 4 의 `deleted_k` 사례와 finishing B-R 문장 락이 잠근다.
4. **같은 분에 같은 주제로 두 번 끝난 인터뷰 · 끝나지 않은 상태 파일.** 둘째 충돌은 rc 2 로 멈추고, 끝나지 않은 상태 파일은 지금처럼 같은 자리(이어 가기 판단은 진입 단계 몫)다. Task 7 의 사례 넷이 잠근다.
5. **§4 의 강조 «» 가 첫 줄이 아니라 들여 쓴 본문 줄에 있다.** 본문 줄의 «» 도 출처키로 읽히므로 같은 안내(강조라면 「」)가 나와야 한다. Task 8 의 `emph_body` 사례가 잠근다.

---

### Task 0: 시작 · 기준선 · 계획 1 이음매 · AC29 확인

**Files:**
- Create: `$HOME/.claude/sdd-mirror/r10-plan2/baseline.sh` (레포 밖)
- Modify: 이 계획 파일(줄 번호 · 함수 자리 고침이 있으면)

- [ ] **Step 1: 기본 브랜치를 merge 한다** — 기본 브랜치 이름은 `git symbolic-ref refs/remotes/origin/HEAD` 로 도출. `git fetch origin && git merge --no-edit origin/<기본 브랜치>`. 충돌 없음이 기대값(설계문서 · 계획 · 계획 1 계획만 이 브랜치에 있다).

- [ ] **Step 2: 계획 1 구현의 머지 여부와 정본 문단을 확인한다**

Run: `git log --oneline origin/<기본 브랜치> -- plugins/spec-distill/agents/open-researcher.md | head -1; grep -nF '**둘째 질문(선택) — 다음 단계 갈래.**' plugins/spec-distill/references/proceed-gate.md`
Expected: 둘 다 없으면 계획 1 미머지 — Task 1 Step 3 에서 정본을 쓴다. 문단이 있으면 Task 1 Step 3 을 건너뛰고 그 문단의 머리글 · 선택지 문구를 이 계획의 인터뷰 끝 문장(Task 1 Step 4)에 맞춘다. 계획 1 이 먼저 머지했으면 `test_check_brief.sh` 끝 블록 · 템플릿 §4 설명이 바뀌어 있으니 Task 4 · Task 8 의 `Modify:` 자리를 다시 잡는다.

- [ ] **Step 3: 고칠 자리를 다시 읽고 계획을 맞춘다** — `skills/spec-interview/references/finishing.md` 의 `### 분해 판단`(`:24-62`) · Step A 4(`:112-133`) · B-A 의 §5 줄(`:393`) · B-2(`:413-474`) · B-3(`:476-515`) · B-R(`:601-615`), `scripts/roadmap_model.py` 의 `RISK_PREFIXES`(`:139`) · `brief_universe`(`:438-471`), `scripts/roadmap_render.py` 의 `BriefIndex`(`:207-212`) · `_section4_index`(`:250-262`) · `index_brief`(`:265-290`), `scripts/roadmap_write.py` 의 `cmd_create` · `cmd_update` 끝 print, `scripts/state_path.py` 의 `interview_state_path`(`:170-203`), `scripts/check_brief.py:1696`. 줄 번호가 다르면 이 계획의 `Modify:` 를 고쳐 쓴다.

- [ ] **Step 4: AC29 확인(이미 충족 — 과제 없음)**

Run: `bash plugins/spec-distill/tests/test_brief_bundle.sh 2>&1 | grep -E 'T18'; bash plugins/spec-distill/tests/test_brief_inline_blob.sh 2>&1 | grep -E 'T24b'`
Expected: `✓ T18: payload 에 자기 audit_file basename 이 있으면 rc 3` · `✓ T24b: 다른 인터뷰의 audit 인용만 있으면 exit 0`. ✗ 면 멈추고 지휘 세션에 보고한다(설계 §8 의 「이미 고쳐짐」이 틀렸다).

- [ ] **Step 5: 기준 스위트 스크립트를 쓴다** — R2a 계획 1(`docs/superpowers/plans/2026-10-18-r2a-plan1-defects-test-selection-qg-entry.md` Task 0 Step 1)의 `baseline.sh` 를 그대로 `$HOME/.claude/sdd-mirror/r10-plan2/baseline.sh` 에 쓴다(셸 테스트 · unittest 둘 다, 실패 줄 «이름» 집합을 남김).

- [ ] **Step 6: 기준을 잰다** (버릴 clone — `git clone --no-local` 로 이 브랜치 HEAD 를 받아 그 루트에서; 다른 스위트와 동시에 돌리지 않는다)

Run: `bash "$HOME/.claude/sdd-mirror/r10-plan2/baseline.sh" "$HOME/.claude/sdd-mirror/r10-plan2/before"`
Expected: `before.tsv` · `before.names` 생성.

- [ ] **Step 7: 계획 고침을 커밋한다**(고친 것이 있을 때만)

```bash
git commit -m 'docs(plan): R10 계획 2 — 머지 뒤 줄 번호 · 함수 자리 맞춤' -- docs/superpowers/plans/2026-10-19-r10-plan2-end-gates.md
```

---

### Task 1: 게이트 정본의 둘째 질문 · 인터뷰 끝 ①② 이름 · 다른 다음 단계 (AC17 정본 쪽 · AC21 · AC23)

**Files:**
- Modify: `plugins/spec-distill/references/proceed-gate.md` Step B — 「기타 칸」 문단 앞(`:54`, Task 0 Step 2 가 「없음」일 때만)
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` — B-2 의 `AskUserQuestion` 펜스 뒤(`:474`) · B-3 의 다음 세션 줄 규칙 문단 뒤(`:496`) · ① 불릿 앞
- Create: `plugins/spec-distill/tests/test_end_gates.sh`

**Interfaces:**
- Produces(정본): `proceed-gate.md` Step B 의 `**둘째 질문(선택) — 다음 단계 갈래.**` 문단 — 계획 1 의 request-framing 과 이 과제의 인터뷰 끝이 함께 읽는다.
- Produces: `finishing.md` B-2 의 ①② 이름 표(행 셋) — Task 2 가 「기본 다음 단계」 문장에서 가리킨다.
- Produces: `tests/test_end_gates.sh` 와 그 헬퍼 `flat <파일>` · `win <파일> <머리 정규식> <끝 정규식>` — Task 2 · 3 이 같은 파일에 단언을 더한다.

- [ ] **Step 1: 실패하는 락을 쓴다** — `tests/test_end_gates.sh`. 머리는 `test_epic_handoff.sh` 꼴(`ROOT` · `SD` · `--emit-scanned` 은 `# guards:` 경로를 그대로 낸다 · `assert.sh`). `# guards: plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/spec-interview/references/finishing.md`(Task 2 · 3 이 경로를 더할 때 `--emit-scanned` 출력에도 함께 더한다).

```bash
flat() { tr '\n' ' ' < "$1" | tr -s ' '; }
win() { awk -v a="$2" -v b="$3" '$0 ~ a {f=1; print; next} f && $0 ~ b {f=0} f' "$1" | tr '\n' ' ' | tr -s ' '; }
PG="$SD/references/proceed-gate.md"; FIN="$SD/skills/spec-interview/references/finishing.md"
# AC17(정본) — Step B 안에 있다(다음 세션 명령 절 앞)
STEPB="$(win "$PG" '^## Step B' '^## ')"
[ -n "$STEPB" ] && ok "AC17(양성 대조): 정본 Step B 를 떴다" || no "AC17: 정본 Step B 부재"
for lit in '**둘째 질문(선택) — 다음 단계 갈래.**' '머리글은 「다음 단계 갈래」' \
           '첫 질문의 네 선택지 · 순서 · `(권장)` 은 그대로다' '①/② 의 이름과 설명은 특정 단계를 가리키지 않는다' \
           '제안이 없으면 둘째 질문도 없다' '`## 다음 세션 명령` 규칙 3 대로'; do
  assert_contains "$STEPB" "$lit" "AC17(정본): «$lit»"
done
B2="$(win "$FIN" '^#### B-2' '^#### ')"; B3="$(win "$FIN" '^#### B-3' '^#### ')"
[ -n "$B2" ] && [ -n "$B3" ] && ok "양성 대조: B-2 · B-3 를 떴다" || no "B-2 · B-3 부재"
# AC21 — 분해된 일의 이름 · 하나짜리 이름 그대로 · /compact 가 ①(권장)
assert_contains "$B2" '| 하나짜리 brief · 둘째 질문 없음 | 확정하고 /compact 후 brainstorming (권장) | 확정하고 /new 후 brainstorming |' "AC21: 하나짜리 brief 이름 그대로"
assert_contains "$B2" '| 분해된 일 | 확정하고 /compact 후 지휘자로 (권장) | 확정하고 /new 후 지휘자로 |' "AC21: 분해된 일은 지휘자로"
assert_contains "$B2" '이 세션에서 로드맵의 에픽들을 끝까지 이끈다' "AC21: 분해된 일의 설명이 지휘자를 말한다"
# AC23 — 둘째 질문이 있으면 단계 안 가리키는 이름 · 정본을 가리킴 · 제안 없으면 없음 · 분해된 일엔 없음
assert_contains "$B2" '| 하나짜리 brief · 둘째 질문 있음 | 확정하고 /compact 후 다음 단계로 (권장) | 확정하고 /new 후 다음 단계로 |' "AC23: 둘째 질문이 있으면 단계를 가리키지 않는 이름"
for lit in '선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로' \
           '`${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「둘째 질문(선택)」 대로' \
           '「brainstorming (권장)」 · 「<모델의 제안>」' '제안 이유는 게이트 앞 글' \
           '제안이 없으면 둘째 질문도 없다' '분해된 일에는 둘째 질문을 두지 않는다'; do
  assert_contains "$B2" "$lit" "AC23: B-2 «$lit»"
done
for lit in '**이름이 바뀌어도 절차는 같다.**' '**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.**' \
           '`@<brief-path>` 를 원소로' 'confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.' \
           '§3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다' \
           'brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.' \
           '사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.' \
           '`next_phase:` 를 고른 skill 의 완전명으로 바꾼다' '인용 줄로 두지 않는다'; do
  assert_contains "$B3" "$lit" "AC23: B-3 «$lit»"
done
```

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_end_gates.sh`
Expected: 양성 대조 둘은 ✓, 나머지 ✗(정본 문단 · 표 · 갈래 부재).

- [ ] **Step 3: 정본 문단을 쓴다**(Task 0 Step 2 가 「없음」일 때만) — `proceed-gate.md` Step B 의 「기타 칸」 문단 앞에 아래 문단 하나(계획 1 계획 Task 7 Step 3 과 같은 글자):

> **둘째 질문(선택) — 다음 단계 갈래.** 일의 모양이 기본 다음 단계와 다르면(예: 조사만 하는 일 · 이미 설계문서를 쓸 만큼 분명한 일) 모델이 다른 다음 단계를 이유와 함께 제안할 수 있다. 제안 이유는 게이트 앞 글에 쓰고, 같은 질문 호출에 둘째 질문을 더한다 — 머리글은 「다음 단계 갈래」, 선택지는 그 skill 의 기본 다음 단계 `(권장)` 과 모델의 제안 둘이다. 첫 질문의 네 선택지 · 순서 · `(권장)` 은 그대로다. 둘째 질문이 뜰 때는 ①/② 의 이름과 설명은 특정 단계를 가리키지 않는다(예: 「/compact 후 다음 단계로 (권장)」 · 「/new 후 다음 단계로」) — 두 질문이 한 호출에 함께 나가 이름이 둘째 답에 따라 바뀔 수 없다. 제안이 없으면 둘째 질문도 없다. 제안을 고르면 다음 세션 줄은 `## 다음 세션 명령` 규칙 3 대로 그 skill 의 모양으로 짓고, 운반 문장은 그 skill 이 정한다.

  문단이 이미 있으면(계획 1 이 먼저 머지) 쓰지 않는다 — 들어간 문단이 위와 글자가 다르면 Step 1 의 정본 단언을 들어간 글자에 맞추고 그 차이를 이 과제 보고에 적는다.

- [ ] **Step 4: 인터뷰 끝을 고친다**
  - B-2 의 `AskUserQuestion` 펜스 바로 뒤(B-3 머리 앞)에 두 문단:

    「**①② 이름 — 일의 모양에 따라.** 위 호출은 하나짜리 brief 에 둘째 질문이 없을 때의 모양이다. 선택지 넷의 개수 · 순서 · `(권장)` 은 어느 경우든 그대로이고 ①② 의 이름과 설명만 다음 단계에 맞춘다:」 + 표

    | 일 | ① | ② | 설명이 말하는 다음 단계 |
    |---|---|---|---|
    | 하나짜리 brief · 둘째 질문 없음 | 확정하고 /compact 후 brainstorming (권장) | 확정하고 /new 후 brainstorming | brainstorming |
    | 하나짜리 brief · 둘째 질문 있음 | 확정하고 /compact 후 다음 단계로 (권장) | 확정하고 /new 후 다음 단계로 | 둘째 질문에서 고른 단계 |
    | 분해된 일 | 확정하고 /compact 후 지휘자로 (권장) | 확정하고 /new 후 지휘자로 | 지휘자 — 이 세션에서 로드맵의 에픽들을 끝까지 이끈다 |

    「**둘째 질문 — 다른 다음 단계.** 하나짜리 brief 의 일이 brainstorming 보다 다른 다음 단계에 맞으면(예: 조사만 하는 일) 그 제안을 `${CLAUDE_PLUGIN_ROOT}/references/proceed-gate.md` 의 「둘째 질문(선택)」 대로 같은 호출에 더한다 — 선택지는 「brainstorming (권장)」 · 「<모델의 제안>」이고, 제안 이유는 게이트 앞 글(위 목록 끝)에 한 줄로 쓴다. 제안이 없으면 둘째 질문도 없다. 분해된 일에는 둘째 질문을 두지 않는다 — 에픽마다의 흐름은 지휘자가 로드맵 `흐름:` 칸으로 정한다.」
  - B-3 의 다음 세션 줄 규칙 문단(「로드맵 에픽의 설계를 여는 줄은 …」) 뒤에:

    「**다른 다음 단계의 줄 — 둘째 질문에서 제안을 골랐을 때.** ①/② 의 둘째 줄은 위 brief 줄 대신 정본 `## 다음 세션 명령` 규칙 3 대로 고른 skill 의 모양으로 짓고 `@<brief-path>` 를 원소로 삼는다. 줄에는 위 brief 줄의 공통 지시를 이 글자로 싣는다 — 「confirmed 항목은 근거 있으면 보고 후 재결정 가능, 임의 변경은 금지.」 · 「brief 의 §2 확정 항목뿐 아니라 §3 열린 질문 · §4 조사 · §5 위험을 번호째 입력으로 읽는다 — /compact 요약에 기대지 말고 첨부한 brief 를 다시 읽는다.」 · 「brief 의 확정 항목은 다시 묻지 않고 되비춤으로 확인한다.」 · 「사람에게 쓰는 글의 낱말 규칙(번호·해시는 내용을 문장으로 먼저 쓰고 괄호 안에)을 지킨다.」 자리표 치환 · 거부 · 위치 공시는 위 brief 줄과 같다. 이 줄은 표지 블록 밖이라 인용 줄로 두지 않는다. 확정 반영 write 에서 brief frontmatter `next_phase:` 를 고른 skill 의 완전명으로 바꾼다.」
  - B-3 의 ① 불릿 바로 앞에: 「**이름이 바뀌어도 절차는 같다.** 아래 ①② 는 B-2 이름 표의 어느 이름으로 골랐든 같은 절차이고 둘째 줄만 다르다 — 분해된 일이면 아래 「다음 세션 줄 — 분해된 일 ①/② 공통」, 둘째 질문에서 제안을 골랐으면 위 「다른 다음 단계의 줄」, 그 밖에는 위 brief 줄이다. 「같은 턴에서 호출하지 말 것」은 그 줄이 부르는 skill(지휘자 · 고른 skill) 모두에 선다.」
  - ①② 불릿 제목 · `AskUserQuestion` 펜스의 라벨 · 「같은 턴에서 `brainstorming`을 호출하지 말 것」 문장은 그대로 둔다(기존 락 `test_conducting_interview_stage.sh:119-134,217`).

- [ ] **Step 5: 락을 돌린다**

Run: `for t in test_end_gates test_conducting_interview_stage test_next_session_command test_proceed_gate_adopters test_review_handoff_order test_entry_guidance test_plain_gate_templates; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done`
Expected: 출력 없음. `test_next_session_command` 의 「다음 세션 줄 모양의 인용 줄이 표면에 1개」가 그대로 ✓ 여야 한다(새 줄 설명은 인용 줄이 아니다).

- [ ] **Step 6: 변이(AC32)** — 커밋 뒤 하나씩: B-2 표의 분해된 일 행 지우기 · 그 행의 「지휘자로」를 「brainstorming」으로 · 「분해된 일에는 둘째 질문을 두지 않는다」 지우기 · 정본 문단의 「첫 질문의 네 선택지 · 순서 · `(권장)` 은 그대로다」 지우기(정본을 이 과제가 썼을 때만) · B-3 의 「`next_phase:` 를 고른 skill 의 완전명으로 바꾼다」 지우기 — 각각 `test_end_gates.sh` RED 를 보고 `git checkout HEAD -- <파일>`.

- [ ] **Step 7: 커밋**

```bash
chmod +x plugins/spec-distill/tests/test_end_gates.sh
git add plugins/spec-distill/tests/test_end_gates.sh
git commit -m 'feat(spec-distill): 인터뷰 끝 게이트 이름이 다음 줄과 맞고 둘째 질문으로 다른 다음 단계를 고른다' -- plugins/spec-distill/references/proceed-gate.md plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/tests/test_end_gates.sh
```

---

### Task 2: brief 의 기본 다음 단계 · 다음 세션 줄 (AC18 · AC22)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` — Step A 2 의 frontmatter 줄(`:73`) · B-3 다음 세션 줄(`:491`)
- Modify: `plugins/spec-distill/templates/interview-brief-template.md` — `:7` · `:33-34` · `:120-122`
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md:107-109`
- Modify: `plugins/spec-distill/tests/test_review_handoff_order.sh` — brief 다음 세션 줄 단언 블록(`:84-104`)
- Modify: `plugins/spec-distill/tests/test_end_gates.sh` (guards 에 템플릿 · 인터뷰 SKILL · `references/epic-handoff.md` 를 더하고 단언 추가)

**Interfaces:**
- Consumes: Task 1 의 `flat` · `win` · B-2 이름 표.

- [ ] **Step 1: 실패하는 락을 쓴다**
  - `test_review_handoff_order.sh` 의 brief 다음 세션 줄 블록에:

```bash
  for n in '고른 실행 방식의 마지막 전체 리뷰' \
           '설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계 → 계획 → 구현)의 의도는 지킨다.' \
           '## 있는 것 검토 절' '사용자가 승인한 뒤에만' '## 상류 · 하류 연계 절' '레포 전용 값은 박지 말고'; do
    assert_contains "$ONE" "$n" "AC22: brief 다음 세션 줄에 「${n}」"
  done
  assert_not_contains "$ONE" 'SDD 의 마지막 전체 리뷰' "AC22: 실행 방식을 SDD 로 고정하지 않는다(양성 짝: 고른 실행 방식)"
  assert_not_contains "$ONE" '계층 · 온톨로지' "AC22: 원칙 5 는 싣지 않는다(설계 §6)"
```

  - `test_end_gates.sh` 에(AC22 의 「맞춘다」 · AC18):

```bash
EH="$SD/references/epic-handoff.md"; TPL="$SD/templates/interview-brief-template.md"; SKI="$SD/skills/spec-interview/SKILL.md"
nsl() { awk -v m="$2" '$0==m{f=1;next} f&&NF{print;exit}' "$1"; }
BL="$(nsl "$FIN" '**다음 세션 줄 — ①/② 공통**')"; EL="$(nsl "$EH" '**에픽 넘김 줄**')"
SHARED='설계문서에 ## 있는 것 검토 절(레포 안에 이미 있는 것을 먼저 찾아 쓰고, 레포 밖 패키지 · 프레임워크 · 서비스는 후보로만 적어 사용자가 승인한 뒤에만 쓴다)과 ## 상류 · 하류 연계 절(이 일이 받는 곳 · 넘기는 곳 · 되돌아오는 길 · 같은 상태를 읽는 다른 표면)을 두고, 경로 · 테스트 명령 · 기본 브랜치 · 브랜치 이름 · 모델 같은 레포 전용 값은 박지 말고 도출하거나 레포 설정에서 읽게 설계한다.'
assert_contains "$EL" "$SHARED" "AC22(양성 대조): 에픽 넘김 줄에 원칙 문장"
assert_contains "$BL" "$SHARED" "AC22: brief 줄의 원칙 문장이 에픽 넘김 줄과 글자가 같다"
# AC18
grep -qxF 'next_phase: superpowers:brainstorming   # 기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 그 skill 의 완전명' "$TPL" \
  && ok "AC18: 템플릿 next_phase 가 기본 다음 단계라고 말한다" || no "AC18: 템플릿 next_phase 주석 부재"
assert_contains "$(flat "$TPL")" '§7 대로 기본 다음 단계(brainstorming 해답공간)로' "AC18: 템플릿 정의 문장"
assert_contains "$(win "$TPL" '^## 7[.]' '^## ')" '(기본 다음 단계 — superpowers 있으면:' "AC18: §7 이 기본 다음 단계를 말한다"
assert_contains "$(flat "$FIN")" '`next_phase: superpowers:brainstorming`(기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 B-3 이 그 skill 의 완전명으로 바꾼다)' "AC18: Step A 의 next_phase"
assert_contains "$(flat "$SKI")" 'interview brief**(기본 다음 단계가 brainstorming 인 meta-prompt)' "AC18: SKILL 정의 문장"
grep -qF 'brainstorming용 meta-prompt' "$SKI" && no "AC18: 옛 「brainstorming용」 정의 잔존" || ok "AC18: 옛 정의 없음(양성 짝: 위 단언)"
```

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_review_handoff_order.sh 2>&1 | grep -E 'AC22'; bash plugins/spec-distill/tests/test_end_gates.sh 2>&1 | grep -E 'AC18|AC22'`
Expected: 양성 대조(에픽 넘김 줄)만 ✓, 나머지 ✗.

- [ ] **Step 3: brief 다음 세션 줄을 고친다**(`finishing.md` B-3 인용 줄 한 줄 안에서만)
  - 「SDD 의 마지막 전체 리뷰」 → 「고른 실행 방식의 마지막 전체 리뷰」.
  - 「… AC1 · AC2 … 처럼 번호를 단다.」 바로 뒤, 「사용자 선호:」 앞에: 「 설계의 규칙은 「기본은 X, 일의 모양이 다르면 모델이 판단하고 이유를 적는다」로 쓰고 정석 흐름(설계 → 계획 → 구현)의 의도는 지킨다. 」 + 위 `SHARED` 문장 그대로.
  - #227 문장 넷과 나머지 글자는 그대로다. 줄 안에 꺾쇠 자리표를 새로 넣지 않는다(`lead_only` 락).

- [ ] **Step 4: 「기본 다음 단계」 문면을 고친다**
  - 템플릿 `:7` 을 Step 1 의 줄 그대로. `:33-34` 를 「> 이 brief는 단독 완결 산출물이다. superpowers가 있으면 §7 대로 기본 다음 단계(brainstorming 해답공간)로 넘어가고, 없으면 이 brief 자체가 다음 단계의 입력이다. 텔레메트리는 `audit_file`에 있다.」 `:120` 괄호 머리를 「(기본 다음 단계 — superpowers 있으면: …」 로(나머지 글자 · 순서 그대로 — `test_review_handoff_order.sh` §7 순서 락).
  - `finishing.md:73` 의 `next_phase: superpowers:brainstorming` 뒤에 「(기본 다음 단계 — 끝 게이트의 둘째 질문에서 다른 단계를 고르면 B-3 이 그 skill 의 완전명으로 바꾼다)」.
  - SKILL `:107-109` 를 「산출물은 `spec.md`가 아니라 **interview brief**(기본 다음 단계가 brainstorming 인 meta-prompt)이며, 이 brief는 **단독 완결 terminal 산출물**입니다 — superpowers가 있으면 기본으로 brainstorming으로 넘기고(optional — 일의 모양이 다르면 끝 게이트의 둘째 질문으로 다른 다음 단계를 고른다), 없으면 brief 자체로 완료합니다.」

- [ ] **Step 5: 락을 돌린다**

Run: `for t in test_end_gates test_review_handoff_order test_epic_handoff test_next_session_command test_plain_gate_templates test_brief_no_statement_cap test_seed_at_path_handoff test_conducting_interview_stage; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done; python3 -m unittest plugins/spec-distill/tests/test_check_brief_frontmatter.py 2>&1 | tail -1`
Expected: 출력은 `OK` 한 줄뿐.

- [ ] **Step 6: 변이(AC32)** — 커밋 뒤 하나씩: brief 줄의 「고른 실행 방식」을 「SDD 의」로 되돌리기 · `SHARED` 문장의 「사용자가 승인한 뒤에만」을 「사용자가 보고」로(글자 같음 단언 RED) · 템플릿 `:7` 주석 지우기 — 각각 RED 확인 뒤 `git checkout HEAD -- <파일>`.

- [ ] **Step 7: 커밋**

```bash
git commit -m 'feat(spec-distill): brief 의 다음 단계를 기본값으로 · 다음 세션 줄에 고른 실행 방식과 원칙 넷' -- plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/tests/test_review_handoff_order.sh plugins/spec-distill/tests/test_end_gates.sh
```

---

### Task 3: trivia · steelman 을 예시로 (AC19 · AC20)

**Files:**
- Modify: `plugins/spec-distill/references/trivia-escape.md:1-11,14,20,31`
- Modify: `plugins/spec-distill/skills/spec-interview/SKILL.md:71` · `plugins/spec-distill/skills/request-framing/SKILL.md:57` (「다섯 패턴」 문장)
- Modify: `plugins/spec-distill/agents/steelman-builder.md:63-64,88,90` (persona — 보안 리뷰 대상)
- Modify: `plugins/spec-distill/skills/spec-interview/references/steelman.md:8`
- Modify: `plugins/spec-distill/README.md:109,129`
- Modify: `plugins/spec-distill/tests/test_conducting_interview_stage.sh:1335,1343` · `tests/test_request_framing_entry.sh:53` · `tests/test_distortion_devices.sh:55` · `tests/test_end_gates.sh`

- [ ] **Step 1: 실패하는 락을 쓴다** — `test_end_gates.sh` 에(guards 에 trivia-escape · steelman-builder · steelman.md · request-framing SKILL 을 더한다):

```bash
TE="$SD/references/trivia-escape.md"; SB="$SD/agents/steelman-builder.md"; SM="$SD/skills/spec-interview/references/steelman.md"
TEF="$(flat "$TE")"
grep -qxF '# Trivia Escape — 한 문장 기준' "$TE" && ok "AC19: 머리가 한 문장 기준" || no "AC19: 머리가 다르다"
for lit in '한 문장으로 설명 가능한 사소한 변경이면' '아래 다섯은 그 기준에 드는 흔한 예시다' \
           '목록에 없어도 한 문장으로 설명되는 변경이면 trivia 로 보고' '목록에 들어도 의미가 바뀌는 변경이면 trivia 가 아니다' \
           '**짧은 요청 + 명백히 안전한 syntactic action 동사**' '(보기: 10 토큰 안팎)' '판정 근거: <판정 근거>'; do
  assert_contains "$TEF" "$lit" "AC19: «$lit»"
done
for old in '<10 토큰' '다섯 중 하나에 해당하면' '맞은 패턴'; do
  grep -qF "$old" "$TE" && no "AC19: 옛 문구 «$old» 잔존" || ok "AC19: 옛 문구 «$old» 없음(양성 짝: 위 단언)"
done
for f in "$SD/skills/spec-interview/SKILL.md" "$SD/skills/request-framing/SKILL.md"; do
  assert_contains "$(flat "$f")" '그 파일의 기준과 예시로 판정한다' "AC19: ${f##*/skills/} 진입이 기준으로 판정"
  grep -qF '다섯 패턴' "$f" && no "AC19: ${f##*/skills/} 에 「다섯 패턴」 잔존" || ok "AC19: ${f##*/skills/} 「다섯 패턴」 없음"
done
SBF="$(flat "$SB")"
for lit in '보기: landscape 모순 · 알려진 anti-pattern · 기존 사용자 제약과의 충돌. 이 셋에 한정하지 않는다.' \
           '<goal 기준으로 대안이 이기는 케이스 — 길이는 근거가 정한다(보기: 2-4줄)>' \
           '<같은 기준으로 원안이 이기는 케이스 — 길이는 근거가 정한다(보기: 2-4줄)>'; do
  assert_contains "$SBF" "$lit" "AC20: steelman-builder «$lit»"
done
for old in '충돌 중 하나.' ', 2-4줄>'; do
  grep -qF "$old" "$SB" && no "AC20: steelman-builder 옛 «$old» 잔존" || ok "AC20: 옛 «$old» 없음(양성 짝: 위 단언)"
done
assert_contains "$(flat "$SM")" '**trigger** — 기본은 셋이다: landscape 모순 / 알려진 anti-pattern / 기존 사용자 제약과의 충돌. 다른 이유로 방향이 의심되면 모델이 판단해 띄우고 그 이유를 trigger 로 적는다.' "AC20: 인터뷰 쪽 trigger 도 예시"
```

  기존 락 셋을 새 문면으로: `test_conducting_interview_stage.sh:1343` 의 양성 짝을 `'# Trivia Escape — 한 문장 기준'` 으로, `:1335` 와 `test_request_framing_entry.sh:53` 의 복제 감지 정규식을 `(Typo|주석-only|formatting|단일 식별자|짧은 요청)` 으로, `test_distortion_devices.sh:55` 를 `'판정 근거: <판정 근거>'`(라벨 「AC16a: 질문에 판정 근거가 보인다」)로.

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_end_gates.sh 2>&1 | grep -E 'AC19|AC20'; bash plugins/spec-distill/tests/test_distortion_devices.sh 2>&1 | grep AC16a`
Expected: ✗ (옛 문구 「없음」 단언 몇은 처음부터 ✓ 가 아니다 — 지금 옛 문구가 있다).

- [ ] **Step 3: trivia-escape.md 를 고친다**
  - `:1` 을 `# Trivia Escape — 한 문장 기준`, `:3` 을 「「풀린 입력」(진입 skill 의 `## 진입 단계` 2 의 결과)이 한 문장으로 설명 가능한 사소한 변경이면(philosophy P12 — 파일 수는 기준이 아니다) 이 게이트를 우회한다. 아래 다섯은 그 기준에 드는 흔한 예시다 — 목록에 없어도 한 문장으로 설명되는 변경이면 trivia 로 보고, 목록에 들어도 의미가 바뀌는 변경이면 trivia 가 아니다. 판정은 모델이 하고 근거를 질문에 적는다.」
  - 5 번을 「**짧은 요청 + 명백히 안전한 syntactic action 동사** — 예: "fix typo", "add semicolon", "remove blank line"(보기: 10 토큰 안팎). *다음 경우는 trivia 아님: …(그대로)*」. 1~4 번과 force 문단은 그대로.
  - `<해당 패턴 이름>` 세 곳을 `<판정 근거>` 로, 질문의 「맞은 패턴: …」 을 「판정 근거: <판정 근거>.」(한 문장 설명 — 맞은 예시가 있으면 그 이름을 앞에), 안내의 「trivia 패턴(<해당 패턴 이름>)」을 「trivia(<판정 근거>)」로.
  - 두 SKILL 의 「다섯 패턴과 대조한다」 · 「그 다섯 패턴에 「풀린 입력」을 대조한다」를 「그 파일의 기준과 예시로 판정한다」로.
  - README `:109` 를 「(판정 기준은 한 문장으로 설명 가능한가 — typo / 주석-only / formatting / rename / 짧은 안전 동사는 예시). 파일 수는 자격 기준이 아니다.」, `:129` 의 「5 패턴」을 「한 문장 기준 · 예시 다섯」으로.

- [ ] **Step 4: steelman 을 고친다**
  - `steelman-builder.md:63-64` 의 `<trigger>` 줄 끝을 「게이트를 발동시킨 이유 — 보기: landscape 모순 · 알려진 anti-pattern · 기존 사용자 제약과의 충돌. 이 셋에 한정하지 않는다.」로. `:88` · `:90` 의 「, 2-4줄>」을 「 — 길이는 근거가 정한다(보기: 2-4줄)>」로. Output 형식의 키 · 순서 · `evidence` 블록은 그대로다(`test_research_claims_contract.sh` 축 D).
  - `steelman.md:8` 을 Step 1 의 문장으로 바꾸고 「커버리지 공백은 R3 대상이 아니다 — …」 문장은 그대로 잇는다.

- [ ] **Step 5: 락을 돌린다**

Run: `for t in test_end_gates test_conducting_interview_stage test_request_framing_entry test_distortion_devices test_seed_at_path_handoff test_research_claims_contract test_research_agents_frontmatter test_readme_sync; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done; bash shared/tests/test_agent_input_slots.sh >/dev/null 2>&1 || echo "FAIL agent_input_slots"`
Expected: 출력 없음.

- [ ] **Step 6: 변이(AC32)** — 커밋 뒤 하나씩: trivia-escape 5 번 이름을 「<10 토큰 + …」으로 되돌리기 · 「아래 다섯은 그 기준에 드는 흔한 예시다」 지우기 · steelman-builder 의 「이 셋에 한정하지 않는다.」 지우기 · steelman.md 의 「다른 이유로 방향이 의심되면」 문장 지우기 — 각각 RED 뒤 `git checkout HEAD -- <파일>`.

- [ ] **Step 7: 커밋** (메시지 본문에 「persona 편집 — 보안 리뷰 대상」)

```bash
git commit -m 'feat(spec-distill): trivia 는 한 문장 기준 · steelman 의 셋과 줄 수는 예시로' -m 'persona 편집 — 보안 리뷰 대상(agents/steelman-builder.md).' -- plugins/spec-distill/references/trivia-escape.md plugins/spec-distill/skills/spec-interview/SKILL.md plugins/spec-distill/skills/request-framing/SKILL.md plugins/spec-distill/agents/steelman-builder.md plugins/spec-distill/skills/spec-interview/references/steelman.md plugins/spec-distill/README.md plugins/spec-distill/tests/test_conducting_interview_stage.sh plugins/spec-distill/tests/test_request_framing_entry.sh plugins/spec-distill/tests/test_distortion_devices.sh plugins/spec-distill/tests/test_end_gates.sh
```

---

### Task 4: 위험 번호를 글에 박는다 (AC25)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py` — `RISK_PREFIXES`(`:139`) 옆에 `RISK_LINE_RE` · `brief_risk_numbers`, `brief_universe`(`:451-454`)
- Modify: `plugins/spec-distill/scripts/roadmap_render.py` — `BriefIndex`(`:207-212`) · `index_brief`(`:289`)
- Modify: `plugins/spec-distill/scripts/roadmap_write.py` — `cmd_create` · `cmd_update` 의 끝 print 뒤
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` — 분해 표 배정 번호 불릿(`:57`) · Step A 4 끝 · B-A 의 §5 줄 꼴(`:393`) · B-R 첫 불릿(`:605`)
- Modify: `plugins/spec-distill/templates/interview-brief-template.md:102-103`
- Modify: `plugins/spec-distill/tests/test_roadmap_model.py` (새 클래스) · `tests/test_roadmap_write.sh` (끝에 블록) · `tests/test_check_brief.sh` (끝에 사례 하나) · `tests/test_end_gates.sh` (finishing 문장)

**Interfaces:**
- Produces: `roadmap_model.RISK_LINE_RE` — `re.compile(r"- 위험(?: (K\d+))? — (?=숨은 가정|실패 양식|리뷰 참고)")`(`.match` 로 줄 머리만).
- Produces: `roadmap_model.brief_risk_numbers(s5: str) -> tuple[list[tuple[str, str]], bool]` — `([(K<n>, "위험 — <종류> …")], 줄 순서로 매겼나)`. 글은 번호를 뗀 꼴(옛 꼴과 같은 글)이다. 모두 박혔으면 K 수 순서, 하나도 안 박혔으면 지금 규칙(숨은 가정 · 실패 양식 · 리뷰 참고 묶음마다 줄 순서, K1 부터)이고 두 번째 값은 위험 줄이 하나 이상일 때만 참. 섞이면 `FormatError("brief §5 위험 줄 가운데 K 번호가 없는 줄이 있다 — 그 줄에 K<가장 큰 수 + 1> 부터 박는다: <줄 앞 60자>")`, 같은 번호가 둘이면 `FormatError("brief §5 위험 줄의 K 번호가 겹친다: K<n>")`.
- Produces: `roadmap_render.BriefIndex.k_by_order: bool = False`(마지막 필드).
- Produces: `roadmap_write.RISK_ORDER_NOTICE` — 아래 Step 3 의 문장.

- [ ] **Step 1: 실패하는 테스트를 쓴다**
  - `test_roadmap_model.py` 새 클래스 `RiskRows`:

```python
class BriefRiskNumbers(unittest.TestCase):
    """AC25 — 위험 번호는 줄에 박힌 것을 읽는다. 옛 brief 는 줄 순서 + 알림 표지."""

    def test_stamped_numbers_are_read(self):
        s5 = ("- 위험 K2 — 실패 양식: 둘 — 근거\n- 기각 — x → y\n"
              "- 위험 K1 — 숨은 가정 | 하나 — RC3 [RC3 → OQ1]\n- 위험 K5 — 리뷰 참고 | 다섯\n")
        rows, by_order = M.brief_risk_numbers(s5)
        self.assertEqual(rows, [("K1", "위험 — 숨은 가정 | 하나 — RC3 [RC3 → OQ1]"),
                                ("K2", "위험 — 실패 양식: 둘 — 근거"), ("K5", "위험 — 리뷰 참고 | 다섯")])
        self.assertFalse(by_order)

    def test_unstamped_keeps_old_order(self):
        s5 = "- 위험 — 실패 양식: 둘\n- 위험 — 숨은 가정: 하나\n"
        self.assertEqual(M.brief_risk_numbers(s5), ([("K1", "위험 — 숨은 가정: 하나"), ("K2", "위험 — 실패 양식: 둘")], True))

    def test_no_risk_lines_is_not_by_order(self):
        self.assertEqual(M.brief_risk_numbers("- 기각 — x → y\n"), ([], False))

    def test_mixed_is_an_error(self):
        with self.assertRaisesRegex(M.FormatError, "K3 부터 박는다"):
            M.brief_risk_numbers("- 위험 K2 — 숨은 가정: a\n- 위험 — 리뷰 참고 | b\n")

    def test_duplicate_is_an_error(self):
        with self.assertRaisesRegex(M.FormatError, "겹친다: K1"):
            M.brief_risk_numbers("- 위험 K1 — 숨은 가정: a\n- 위험 K1 — 실패 양식: b\n")

    def test_other_kinds_are_not_risks(self):
        self.assertEqual(M.brief_risk_numbers("- 위험 — 사실 | 사실 하나 — RC1 (a/b.py) [RC1 → OQ1]\n"), ([], False))
```

  - `test_roadmap_write.sh` 끝(`finish` 앞)에 블록 — 같은 픽스처 brief · audit 를 `$W/docs/iv2/` 에 복사하고(작업 트리면 된다 — `--roadmap-file` 검사는 작업 트리를 읽는다) §5 의 위험 둘을 `- 위험 K1 — 숨은 가정: 가정 — 근거 약함` · `- 위험 K2 — 실패 양식: 실패 — 근거 약함` 으로 바꾸고 `- 위험 K3 — 리뷰 참고 | 셋째 — 근거` 를 더한다. `create` 옆에 brief 경로를 받는 `create_b <brief 레포 상대> <표> <폴더>`(audit 는 brief 의 `.md` → `.audit.md`)를 더한다. 표는 기존 `P1_ROW` · `E1_ROW` 와, `E2_ROW` 의 배정 칸 `K2` 를 `K2 · K3` 로 바꾼 행이다. 사례:
    - `stamped`: 폴더 `docs/rm2` → rc 0 · `four_empty` ok · 알림 줄 없음(`! grep -qF '줄 순서로 매겼다' "$T/out.txt"`).
    - `deleted_k`: brief 에서 K2 줄을 지우고 같은 표로 다시 `create_b` → rc ≠ 0 · 출력에 `unknown_ids: K2`. K2 를 뺀 표로 다시 → rc 0 · `docs/rm2/E2.md` 에 `- K3 — 위험 — 리뷰 참고 | 셋째 — 근거` 가 있고 `- K2 —` 줄은 없다.
    - `old_order_notice`: 위의 기존 `create` 성공 사례(번호 없는 brief)의 `$T/out.txt` 에 `줄 순서로 매겼다` 가 있다(알림) — 그리고 `stamped` 의 출력에는 없다(양의 짝).
  - `test_end_gates.sh` 에 finishing 문장 단언: Step A 의 「`- 위험 K<n> — <숨은 가정 | 실패 양식 | 리뷰 참고> …`」 · 「새로 더하는 위험 줄은 이 brief 의 가장 큰 K 다음 수를 받는다」, 분해 표 불릿의 「Step A 가 brief §5 위험 줄에 박을 번호다」, B-A 의 「`- 위험 K<n> — 리뷰 참고 |`」, B-R 의 「사유가 `unassigned` · `orphans` · `unknown_ids` 면」 · 「`unknown_ids` 는 표가 brief 에 없는 번호(지운 위험의 K 등)를 배정한 것이다」.

- [ ] **Step 2: 돌려 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_roadmap_write.sh 2>&1 | grep -E 'stamped|deleted_k|old_order'`
Expected: `AttributeError: … brief_risk_numbers` 와 새 셸 사례 ✗.

- [ ] **Step 3: 판독 · 생성기를 고친다**
  - `roadmap_model.brief_risk_numbers` 는 위 Interfaces 대로. 줄은 `brief_body.split_lines(s5)` 에서 `RISK_LINE_RE.match` 인 것만. 번호 없는 꼴의 순서는 지금 `brief_universe` 의 `RISK_PREFIXES` 루프 그대로(그 루프를 이 함수로 옮긴다). `brief_universe` 는 `k_expected = brief_risk_numbers(s5)[0]` — 반환 꼴(셋)은 그대로다.
  - `index_brief` 는 `BriefIndex(…, k_by_order=brief_risk_numbers(_body(brief, "## 5."))[1])`.
  - `roadmap_write.RISK_ORDER_NOTICE = ("[spec-distill] brief §5 위험 줄에 K 번호가 없어 줄 순서로 매겼다 — 위험 줄을 지우거나 옮긴 뒤 다시 만들면 " "번호가 다른 위험에 붙는다. 위험 줄을 `- 위험 K<n> — …` 꼴로 박고 다시 만들면 번호가 그 줄에 붙어 다닌다.")`. `cmd_create` · `cmd_update` 는 성공 print 뒤 `if idx.k_by_order: print(RISK_ORDER_NOTICE)`.

- [ ] **Step 4: finishing · 템플릿을 고친다**
  - 분해 표 불릿(`:57`) 끝 문장을 「위험 K 는 Step A 가 brief §5 위험 줄에 박을 번호다 — 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 K1 부터 매긴다.」로.
  - Step A 4 의 끝 문단으로: 「**위험 번호.** payload §5 의 위험 줄마다 `위험` 바로 뒤에 번호를 박는다 — `- 위험 K<n> — <숨은 가정 | 실패 양식 | 리뷰 참고> …`. 숨은 가정 · 실패 양식 · 리뷰 참고 순으로 K1 부터 매긴다(분해 판단 표가 이 순서로 미리 배정했다). 박은 번호는 그 위험의 정체다 — 뒤에 위험 줄을 지우거나 옮겨도 다른 줄의 번호를 고치지 않고, 새로 더하는 위험 줄은 이 brief 의 가장 큰 K 다음 수를 받는다.」
  - B-A(`:393`) 의 꼴을 `- 위험 K<n> — 리뷰 참고 | [<category>] <anchor> — <summary> (리뷰 <id>)`(`<n>` 은 이 brief 의 가장 큰 K 다음 수)로.
  - B-R 첫 불릿 머리를 「사유가 `unassigned` · `orphans` · `unknown_ids` 면 — 보통 B-A 가 brief 에 `OQ<n>` 줄이나 `위험 — 리뷰 참고` 줄을 더해 새 번호가 생긴 것이다. `unknown_ids` 는 표가 brief 에 없는 번호(지운 위험의 K 등)를 배정한 것이다 — 표에서 그 번호를 뺀다.」로 시작하고 뒤 글은 그대로.
  - 템플릿 `:102-103` 을 `- 위험 K1 — <숨은 가정 | 실패 양식>: <내용> — <근거>` · `- 위험 K2 — 숨은 가정 | <내용> — RC3 (plugins/x/y.py#sym) [RC3 → OQ1]` 로.

- [ ] **Step 5: 락을 돌린다**

Run: `(PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_render.py plugins/spec-distill/tests/test_brief_body.py 2>&1 | tail -1); for t in test_roadmap_write test_roadmap_status test_bundle_coverage test_check_brief test_end_gates test_spec_review_bundle test_conductor_e2e; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done`
Expected: `OK` 한 줄뿐. 게이트가 번호 박힌 §5 줄을 받는지는 아직 아무도 재지 않으므로, `test_check_brief.sh` 끝(계획 1 의 끝 블록이 먼저 들어왔으면 그 뒤, `finish` 앞)에 `ac3_pair k_stamped` 로 만든 쌍의 `- 위험 — 숨은 가정 |` 줄을 `- 위험 K1 — 숨은 가정 |` 로 바꾼 사례 하나(rc 0, 라벨 「AC25: 번호 박힌 위험 줄도 게이트를 지난다」)를 더해 함께 돌린다.

- [ ] **Step 6: 변이(AC32)** — 커밋 뒤 하나씩: `brief_risk_numbers` 가 박힌 번호를 무시하고 늘 줄 순서로 매기게(`deleted_k` 의 K3 단언 · `test_stamped_numbers_are_read` RED) · 섞임 검사 줄 지우기(`test_mixed_is_an_error` RED) · `cmd_create` 의 알림 print 지우기(`old_order_notice` RED) · `RISK_LINE_RE` 의 `(?: (K\d+))?` 를 빼기(박힌 줄이 위험에서 빠져 RED). `PYTHONDONTWRITEBYTECODE=1`, 매번 `git checkout HEAD -- <파일>`.

- [ ] **Step 7: 커밋**

```bash
git commit -m 'fix(spec-distill): 위험 번호를 brief 줄에 박아 다시 만들어도 다른 에픽에 붙지 않게' -- plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/scripts/roadmap_write.py plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_write.sh plugins/spec-distill/tests/test_check_brief.sh plugins/spec-distill/tests/test_end_gates.sh
```

---

### Task 5: §4 레포 주장을 배정할 수 있다 (AC26)

**Files:**
- Modify: `plugins/spec-distill/scripts/roadmap_model.py:450` (`brief_universe` 의 §4 줄)
- Modify: `plugins/spec-distill/scripts/roadmap_render.py` — `_section4_index`(`:250-262`)
- Modify: `plugins/spec-distill/tests/test_roadmap_model.py` (`BriefUniverseSection4` 에 사례 둘) · `tests/test_roadmap_write.sh` (블록 하나)

**Interfaces:**
- Consumes: `roadmap_model.RC_RE` · `brief_body.section4_items`.
- Produces: `brief_universe` 의 번호 집합에 §4 항목 **첫 줄**의 `RC<n>` 이 든다. `index_brief().lines["RC<n>"]` 은 그 §4 항목(첫 줄 + 들여 쓴 본문 줄) — 같은 RC 가 §5 에도 있으면 §5 줄이 이긴다(지금 순서 그대로).

- [ ] **Step 1: 실패하는 테스트를 쓴다**
  - `BriefUniverseSection4` 에:

```python
    def test_head_rc_counted(self):
        extra = self.universe("- 레포 주장 «repo-k» — [중립] — 이유 [RC7 → 없음]\n")
        self.assertIn("RC7", extra)

    def test_body_line_rc_not_counted(self):
        extra = self.universe("- 둘째 «body-k» — [중립] — 이유 [→ 없음]\n  본문 줄 RC8 (a/b.py)\n")
        self.assertNotIn("RC8", extra)
```

  - `test_roadmap_write.sh`: `$W/docs/iv3/` 에 픽스처 brief · audit 를 복사해 §4 에 `- 레포 주장 «ext-a» — [중립] — 이유 [RC7 → OQ1]` 을 더한다(이미 있는 키를 다시 써 새 번호는 `RC7` 하나뿐이다). E1 배정에 `RC7` 을 더한 표로 `create_b docs/iv3/brief.md <표> docs/rm3` → rc 0 · `four_empty` ok · `docs/rm3/E1.md` 에 `[RC7 → OQ1]` 줄이 실림. 양의 짝: 같은 표에서 `RC7` 을 빼면 rc ≠ 0 · 출력에 `unassigned: RC7`.

- [ ] **Step 2: 돌려 실패를 본다**

Run: `python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py 2>&1 | tail -3; bash plugins/spec-distill/tests/test_roadmap_write.sh 2>&1 | grep -E 'RC7'`
Expected: `test_head_rc_counted` FAIL(`RC7` 없음), 셸 사례는 rc ≠ 0(`unknown_ids: RC7`).

- [ ] **Step 3: 고친다** — `brief_universe` 의 §4 집합에 `{rc for head, _body in section4_items(s4) for rc in RC_RE.findall(head)}` 를 더한다. `_section4_index` 의 머리 줄 루프에서 `KEY_RE` 와 함께 `RC_RE.findall(head)` 도 같은 항목 글로 매핑한다(`RC_RE` 를 `roadmap_model` 에서 들여온다). 본문 줄 RC 는 매핑하지 않는다(게이트가 첫 줄에 없는 본문 RC 를 이미 막는다).

- [ ] **Step 4: 락을 돌린다**

Run: `(PYTHONDONTWRITEBYTECODE=1 python3 -m unittest plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_render.py 2>&1 | tail -1); for t in test_roadmap_write test_roadmap_status test_bundle_coverage test_spec_review_bundle; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done`
Expected: `OK` 한 줄뿐. `test_bundle_coverage.sh` 가 §4 RC 를 가진 픽스처에서 새로 「빠진 번호」를 내면 그 픽스처의 번호 대조 표에 RC 를 더한다(새 정의가 맞다 — 설계 §7).

- [ ] **Step 5: 변이(AC32)** — 커밋 뒤: `brief_universe` 의 새 줄을 지우기(`test_head_rc_counted` · 셸 사례 RED) · `findall(head)` 를 `findall("\n".join([head] + body))` 로(`test_body_line_rc_not_counted` RED). 매번 `git checkout HEAD -- <파일>`.

- [ ] **Step 6: 커밋**

```bash
git commit -m 'fix(spec-distill): brief §4 첫 줄의 레포 주장 번호도 로드맵에 배정한다' -- plugins/spec-distill/scripts/roadmap_model.py plugins/spec-distill/scripts/roadmap_render.py plugins/spec-distill/tests/test_roadmap_model.py plugins/spec-distill/tests/test_roadmap_write.sh
```

---

### Task 6: 분해 표의 흐름 · 산출물 칸 · 조사 에픽 (AC24)

**Files:**
- Modify: `plugins/spec-distill/skills/spec-interview/references/finishing.md` — 분해 판단 3 의 칸 문장(`:49-58`)
- Modify: `plugins/spec-distill/tests/test_roadmap_write.sh` (블록 하나) · `tests/test_end_gates.sh`

**Interfaces:**
- Consumes: `roadmap_render.COLUMNS` · `EXTRA_COLUMNS`(= `roadmap_model.EXTRA_FIELDS` — 크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물), `render_block` 의 선택 칸 줄. 코드는 고치지 않는다.

- [ ] **Step 1: 실패하는 락을 쓴다**
  - `test_end_gates.sh` 에 분해 판단 3 창(`win "$FIN" '^3[.] [*][*]분해안 표' '^4[.] [*][*]'` — awk `-v` 는 역슬래시를 풀므로 괄호식으로 쓴다)의 단언: 「선택 칸 여섯(크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물)을 더한 열일곱 칸」 · 「쓰지 않는 칸은 「없음」」 · 「`${CLAUDE_PLUGIN_ROOT}/references/roadmap-ontology.md` 의 에픽 · 산출물 행」 · 「조사 에픽은 종류 「묶음」에 `흐름` 「조사 — <단계 한 줄>」, `산출물` 에 결과 파일의 레포 상대경로」 · 「「결정」은 산출물 없이 로드맵 결정 기록으로 끝나는 일이다」 · 「칸은 기본 열하나다:」. 음의 짝: 그 창에 옛 문장 「칸은 열하나다:」 가 없다(`assert_not_contains`).
  - `test_roadmap_write.sh`: 열일곱 칸 머리(`HEAD17` = 열하나 + `| 크기 | 병렬 | 순서 이유 | 근거 | 흐름 | 산출물 |`)로 표를 쓰는 `table17` 헬퍼, 행 셋(P1 · E1 은 선택 칸 모두 「없음」, E2 는 `흐름` 「조사 — 질문 정리 → 조사 → 결과 문서」 · `산출물` `docs/research/e2.md`)으로 `create` → rc 0 · `four_empty` ok · 로드맵 E2 블록에 `- 흐름: 조사 — 질문 정리 → 조사 → 결과 문서` · `- 산출물: docs/research/e2.md`, E1 블록에는 `- 흐름:` 줄이 없다.

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_end_gates.sh 2>&1 | grep AC24; bash plugins/spec-distill/tests/test_roadmap_write.sh 2>&1 | grep -E '흐름|산출물'`
Expected: 문면 단언 ✗. 생성기 사례는 처음부터 ✓(코드가 이미 쓴다) — 이빨은 Step 5 변이로 본다.

- [ ] **Step 3: 분해 판단 3 을 고친다** — 「칸은 열하나다:」 를 「칸은 기본 열하나다:」 로 바꾸고 표 아래 불릿 끝에 둘을 더한다:
  - 「설계 흐름이 아닌 에픽(조사 · 측정 · 결정처럼 설계문서 대신 다른 산출물을 내는 일)이 하나라도 있으면 뒤에 선택 칸 여섯(크기 · 병렬 · 순서 이유 · 근거 · 흐름 · 산출물)을 더한 열일곱 칸으로 쓰고, 쓰지 않는 칸은 「없음」이다. 생성기는 「없음」이 아닌 선택 칸을 에픽 블록에 `- <칸>: <값>` 줄로 쓴다.」
  - 「흐름 · 산출물 칸의 뜻은 `${CLAUDE_PLUGIN_ROOT}/references/roadmap-ontology.md` 의 에픽 · 산출물 행이다. 조사 에픽은 종류 「묶음」에 `흐름` 「조사 — <단계 한 줄>」, `산출물` 에 결과 파일의 레포 상대경로를 쓴다 — 지휘자가 그 칸을 읽어 설계문서 대신 산출물을 내는 흐름으로 간다. 「결정」은 산출물 없이 로드맵 결정 기록으로 끝나는 일이다.」

- [ ] **Step 4: 락을 돌린다**

Run: `for t in test_end_gates test_roadmap_write test_decompose_surface test_roadmap_status test_conducting_interview_stage; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done`
Expected: 출력 없음.

- [ ] **Step 5: 변이(AC32)** — 커밋 뒤: `roadmap_render.render_block` 의 선택 칸 줄(`lines += [...EXTRA_COLUMNS...]`)을 지우기(흐름 · 산출물 단언 RED) · `roadmap_model.EXTRA_FIELDS` 에서 「산출물」 빼기(열일곱 칸 표 거부로 rc ≠ 0 — RED) · finishing 의 「조사 에픽은 종류 「묶음」에」 문장 지우기(RED). 매번 `git checkout HEAD -- <파일>`.

- [ ] **Step 6: 커밋**

```bash
git commit -m 'feat(spec-distill): 분해 표에 흐름 · 산출물 칸 — 조사 에픽을 로드맵 모델 꼴로' -- plugins/spec-distill/skills/spec-interview/references/finishing.md plugins/spec-distill/tests/test_roadmap_write.sh plugins/spec-distill/tests/test_end_gates.sh
```

---

### Task 7: 끝난 인터뷰 자리에 새 인터뷰가 내려앉지 않는다 (AC27)

**Files:**
- Modify: `plugins/spec-distill/scripts/state_path.py` — `interview_state_path`(`:170-203`) · `main` 의 `interview-state` 갈래(`:228-240`) · 모듈 docstring CLI 줄(`:11`)
- Modify: `plugins/spec-distill/skills/spec-interview/references/state-file.md:38-46`
- Modify: `plugins/spec-distill/tests/test_state_path.sh:75-80` (양성 대조를 새 동작으로) · 사례 추가

**Interfaces:**
- Produces: `interview_state_path(topic: str, date: str | None = None, cwd: str | None = None, hhmm: str | None = None) -> tuple[Path | None, list[str]]`. CLI `interview-state --topic <kebab> [--date YYYY-MM-DD] [--time HHMM] [--cwd <dir>]` — `--time` 은 `^([01]\d|2[0-3])[0-5]\d$` 가 아니면 exit 2.

- [ ] **Step 1: 실패하는 사례를 쓴다** — `test_state_path.sh` 의 「양성 대조 — 세 자리에 제 종류가 있으면 통과」(`:75-80`)를 바꿔:

```bash
# AC27 — 같은 날 같은 주제의 끝난 인터뷰(brief 자리에 interview-brief) → <주제>-<HHMM> 자리 + 알림, 끝난 파일은 그대로
put_type "$D/2026-10-15-t-interview.state.md" interview-state
put_type "$D/2026-10-15-t-interview.md" interview-brief
put_type "$D/2026-10-15-t-interview.audit.md" interview-audit
sum_before="$(cat "$D"/2026-10-15-t-interview* | cksum)"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>"$WORK/err"); rc=$?
assert_eq "$rc:$out" "0:$D/2026-10-15-t-0930-interview.state.md" "AC27: 끝난 인터뷰 자리면 <주제>-<HHMM> 자리를 낸다"
assert_contains "$(cat "$WORK/err")" "같은 날 같은 주제의 인터뷰가 이미 끝났다" "AC27: 그 사실을 한 줄 알린다"
assert_eq "$(cat "$D"/2026-10-15-t-interview* | cksum)" "$sum_before" "AC27: 끝난 인터뷰의 파일은 바뀌지 않는다"
# 양의 짝 — 끝나지 않은 상태 파일만 있으면 같은 자리(이어 가기 판단은 진입 단계 몫)
rm -f "$D/2026-10-15-t-interview.md" "$D/2026-10-15-t-interview.audit.md"
out=$(python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" 2>/dev/null); rc=$?
assert_eq "$rc:$out" "0:$D/2026-10-15-t-interview.state.md" "AC27 양의 짝: 끝나지 않은 상태 파일이면 같은 자리"
# 같은 분에 또 끝난 인터뷰 → 멈춘다
put_type "$D/2026-10-15-t-interview.md" interview-brief
put_type "$D/2026-10-15-t-0930-interview.md" interview-brief
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 0930 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC27: 새 자리도 끝난 인터뷰면 exit 2"
python3 "$HELPER" interview-state --topic t --date 2026-10-15 --time 2460 --cwd "$IV" >/dev/null 2>&1; rc=$?
assert_eq "$rc" "2" "AC27: --time 꼴이 아니면 exit 2"
rm -f "$D"/2026-10-15-t-*interview*
```

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_state_path.sh 2>&1 | grep AC27`
Expected: ✗(지금은 같은 자리를 rc 0 으로 낸다 · `--time` 을 모른다).

- [ ] **Step 3: 고친다** — 지금 자리 검사(세 자리의 `type:`)를 `_slot_problem(d: Path, stem: str) -> str | None` 로 떼어 두 번 쓴다. 검사를 지난 뒤 brief 자리(`<stem>.md`)가 있으면(그 `type:` 은 이미 `interview-brief` 로 확인됐다) 끝난 인터뷰다: `hhmm = hhmm or datetime.datetime.now().strftime("%H%M")`, 새 topic `"{0}-{1}".format(topic, hhmm)` 의 stem 으로 경로 검사 · 자리 검사를 다시 하고, 거기서도 남의 파일이거나 끝난 인터뷰면 `None` 과 사유 「[spec-distill] 새 자리 <경로> 에도 끝난 인터뷰가 있다 — 잠시 뒤 다시 부르거나 다른 주제 이름을 쓴다」. 지나면 알림 「[spec-distill] 같은 날 같은 주제의 인터뷰가 이미 끝났다(<끝난 brief 경로>) — 새 인터뷰는 <새 상태 파일 경로> 에서 시작한다. 끝난 인터뷰의 파일은 건드리지 않는다.」 를 msgs 에 더하고 새 경로를 낸다. `main` 은 `--time` 을 읽어 꼴 검사 후 넘긴다.

- [ ] **Step 4: state-file.md 를 고친다** — 펜스 앞 문장 「rc 가 0 이 아니면 그 stderr 를 보이고 멈춘다(…)」 뒤에 「rc 0 이어도 stderr 에 `[spec-distill]` 줄이 있으면 그대로 보인다.」, 펜스 뒤 문장(`:46`)을 「같은 자리에 끝난 인터뷰(brief 가 있는 자리)가 있으면 스크립트가 `<주제>-<HHMM>` 자리를 내고 한 줄 알린다 — 나온 경로를 그대로 쓴다. 끝나지 않은 `type: interview-state` 파일이 있으면 새로 쓰지 않는다 — topic 을 `<주제>-<HHMM>` 으로 바꿔 다시 낸다.」로.

- [ ] **Step 5: 락을 돌린다**

Run: `for t in test_state_path test_interview_state_flow test_state_storage_e2e test_control_plane; do bash plugins/spec-distill/tests/$t.sh >/dev/null 2>&1 || echo "FAIL $t"; done`
Expected: 출력 없음. 다른 테스트가 「brief 가 있는 자리에서 같은 경로」를 기대하면 그 기대가 옛 결함이다 — 새 동작으로 고치고 이 과제 보고에 적는다.

- [ ] **Step 6: 변이(AC32)** — 커밋 뒤: 끝난 인터뷰 갈래를 지우기(AC27 첫 단언 RED) · 새 자리의 두 번째 자리 검사를 지우기(「새 자리도 끝난 인터뷰」 RED) · 알림 append 지우기(RED). `PYTHONDONTWRITEBYTECODE=1`, 매번 `git checkout HEAD -- <파일>`.

- [ ] **Step 7: 커밋**

```bash
git commit -m 'fix(spec-distill): 같은 날 같은 주제의 끝난 인터뷰 자리에 새 인터뷰를 시작하지 않는다' -- plugins/spec-distill/scripts/state_path.py plugins/spec-distill/skills/spec-interview/references/state-file.md plugins/spec-distill/tests/test_state_path.sh
```

---

### Task 8: §4 강조 «» 가 「키를 선언하라」로 이끌지 않는다 (AC28)

**Files:**
- Modify: `plugins/spec-distill/scripts/check_brief.py:1696` (N2 실패 메시지)
- Modify: `plugins/spec-distill/templates/interview-brief-template.md` — §4 예시 줄 둘 뒤의 빈 줄과 `## 5.` 사이(`:89-90`, 계획 1 이 고치는 §4 설명 괄호 · 예시 줄과 떨어진 자리)
- Modify: `plugins/spec-distill/tests/test_check_brief.sh` (끝 블록 — 계획 1 의 끝 블록이 있으면 그 뒤, `finish` 앞)

**Interfaces:**
- Produces: N2 실패 줄 `landscape keys not declared in audit §7: [<키>] — §4 의 «» 는 모두 출처키로 읽힌다. 강조로 쓴 것이면 「」 로 바꾸고, 출처키면 audit §7 에 그 키와 원자료 URL 을 선언한다` (앞머리 영어는 기존 락 `test_check_brief.sh:781` 이 잡는다).

- [ ] **Step 1: 실패하는 사례를 쓴다** — 쌍은 기존 `ac3_pair <stem>`(정상 쌍 `interview-brief-valid` 복제)로 만들고 `python3 -I` 로 §4 첫 항목 줄(`- Next.js app-router SSR «nextjs-docs» — [취함] — 데이터 형태와 부합`)만 바꾼다(`str.replace(…, 1)` 뒤 바뀌지 않았으면 `sys.exit`):
  - `emph_head`: 그 줄의 「데이터 형태와 부합」 → 「데이터 형태와 «중요» 부합」 → rc ≠ 0, 출력에 「강조로 쓴 것이면 「」 로 바꾸고」 가 「audit §7 에 그 키와」 보다 앞에 있다.
  - `emph_body`: 그 줄 바로 뒤에 들여 쓴 본문 줄 `  «중요» 한 점` 을 더한다 → 같은 단언.
  - `emph_fixed`(양의 짝): `emph_head` 의 `«중요»` 를 `「중요」` 로 → rc 0.

```bash
before() { OUT="$1" python3 -I -c 'import os; o = os.environ["OUT"]; a = o.find("강조로 쓴 것이면 「」 로 바꾸고"); b = o.find("audit §7 에 그 키와"); print("ok" if 0 <= a < b else "no")'; }
for c in emph_head emph_body; do
  out="$(python3 "$SCRIPT" gate "$TMPD/$c.md" 2>&1)"; rc=$?
  { [[ $rc -ne 0 ]] && [[ "$(before "$out")" == ok ]]; } \
    && ok "AC28: $c → 「」 안내가 키 선언 안내보다 먼저" || { no "AC28: $c 안내 순서 · 부재"; printf '    %s\n' "$out" | head -c 400; }
done
python3 "$SCRIPT" gate "$TMPD/emph_fixed.md" >/dev/null 2>&1 && ok "AC28 양의 짝: 「」 로 바꾸면 통과" || no "AC28: 「」 로 바꿔도 막힌다"
```

- [ ] **Step 2: 돌려 실패를 본다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh 2>&1 | grep AC28`
Expected: `emph_head` · `emph_body` ✗(안내 없음), `emph_fixed` ✓(이빨은 Step 5).

- [ ] **Step 3: 메시지 · 템플릿을 고친다** — `:1696` 을 Interfaces 의 문장으로(한 줄이 길면 인접 문자열로 나눈다). 템플릿 §4 예시 줄 뒤 빈 줄 다음에 한 줄: 「(«» 는 출처키 자리에만 쓴다 — 강조는 「」. §4 의 «» 는 본문 줄까지 모두 출처키로 읽혀 audit §7 선언을 요구받는다.)」

- [ ] **Step 4: 락을 돌린다**

Run: `bash plugins/spec-distill/tests/test_check_brief.sh >/dev/null 2>&1 || echo FAIL; bash plugins/spec-distill/tests/test_review_handoff_order.sh >/dev/null 2>&1 || echo FAIL2`
Expected: 출력 없음.

- [ ] **Step 5: 변이(AC32)** — 커밋 뒤: 안내 두 문장의 순서를 바꾸기(순서 단언 RED) · 「강조로 쓴 것이면 …」 문장 지우기(RED) · `emph_fixed` 의 기대를 rc ≠ 0 으로 바꿔 RED 를 본 뒤 되돌리기(양의 짝이 살아 있음). 매번 `git checkout HEAD -- <파일>`.

- [ ] **Step 6: 커밋**

```bash
git commit -m 'fix(spec-distill): brief §4 의 강조 «» 는 「」 로 — 키 선언으로 이끌지 않는다' -- plugins/spec-distill/scripts/check_brief.py plugins/spec-distill/templates/interview-brief-template.md plugins/spec-distill/tests/test_check_brief.sh
```

---

### Task 9: 문서 · 버전 · 스위트 대조 · 끝에서 끝 (AC32 마감)

**Files:**
- Modify: `plugins/spec-distill/CHANGELOG.md` · `plugins/spec-distill/.claude-plugin/plugin.json` · `plugins/spec-distill/README.md`(Principles Instantiated) · 루트 `.claude-plugin/marketplace.json`(설명이 바뀔 때만)

- [ ] **Step 1: README · CHANGELOG · 버전** — README `Principles Instantiated` 의 「Law 1 · P17 — 흐름을 고정하지 않는다」 줄 끝에 한 구절(인터뷰 끝 게이트는 하나짜리 brief 에 둘째 질문으로 다른 다음 단계를 고를 수 있고 이름이 그 단계를 따른다 · trivia 는 한 문장 기준이고 패턴은 예시 · 문면은 `tests/test_end_gates.sh` 가 잠근다). CHANGELOG `## [<머지 때>] — <머지 날짜>`: Added(게이트 정본 둘째 질문 — 이 계획이 실었을 때만 · 분해 표 흐름 · 산출물 칸 안내 · `state_path.py interview-state --time`) / Changed(끝 게이트 ①② 이름 표 · brief 다음 세션 줄의 고른 실행 방식 · 원칙 넷 · 기본 다음 단계 · trivia 한 문장 기준 · steelman 예시) / Fixed(위험 번호 박기 · §4 RC 배정 · 같은 날 같은 주제 · §4 강조 «» 안내) / Security(persona 편집 — steelman-builder). plugin.json minor.

- [ ] **Step 2: 버전 · 문서 락**

Run: `bash shared/tests/test_changelog_integrity.sh && bash plugins/spec-distill/tests/test_readme_sync.sh && bash plugins/spec-distill/tests/test_stale_terms.sh && bash shared/tests/test_invocation_surface.sh`
Expected: PASS.

- [ ] **Step 3: 스위트를 기준선과 대조한다** (버릴 clone, 다른 스위트와 동시에 돌리지 않는다)

Run: `bash "$HOME/.claude/sdd-mirror/r10-plan2/baseline.sh" "$HOME/.claude/sdd-mirror/r10-plan2/after" && comm -13 <(sort -u "$HOME/.claude/sdd-mirror/r10-plan2/before.names") <(sort -u "$HOME/.claude/sdd-mirror/r10-plan2/after.names")`
Expected: 새 실패 이름 0. 있으면 그 과제로 돌아간다.

- [ ] **Step 4: 변이 기록을 모은다** — Task 1~8 의 변이(무엇을 바꿨고 어느 단언이 RED 였나)를 PR 본문 「변이 확인」 표로. 생존한 변이가 있으면 그 락을 고친 뒤에만 PR 을 연다.

- [ ] **Step 5: 끝에서 끝(사람 · 모델이 필요한 자리는 지휘 세션이 걷는다)** — 버릴 레포에서: (가) 하나짜리 brief 로 끝 게이트를 띄워 ①② 이름(둘째 질문 없음 · 있음)과 둘째 질문을 보고, 제안을 골라 다음 세션 줄의 공통 지시 넷과 `next_phase` 변경을 본다. (나) 분해된 일로 끝 게이트의 「…후 지휘자로」 이름과 지휘자 줄을 본다. (다) 위험 줄 하나를 지운 뒤 B-R 이 `unknown_ids` 로 표 고치기에 가는지 본다. (라) 같은 날 같은 주제로 인터뷰를 다시 시작해 `<주제>-<HHMM>` 자리와 알림을 본다. 걷기 기록은 PR 본문에.

- [ ] **Step 6: 커밋 · push**

```bash
git commit -m 'chore(spec-distill): <머지 때> — 끝 게이트 · 분해 · 결함 README · CHANGELOG' -- plugins/spec-distill/CHANGELOG.md plugins/spec-distill/.claude-plugin/plugin.json plugins/spec-distill/README.md
git push
```
